"""
    is_pull_request(devbranch::String, use_ci_env::Bool) -> Bool

Checks if currently building for a PR (inspired by deploydocs logic).

First checks CI environment variables if enabled (most reliable in CI/CD):
- Travis CI: `TRAVIS_PULL_REQUEST` != "false"
- GitHub Actions: `GITHUB_EVENT_NAME` == "pull_request"
- GitLab CI: `CI_MERGE_REQUEST_ID` is non-empty

Falls back to git branch comparison for local development.
Returns false on errors (safe default: build everything fully).
"""
function is_pull_request(devbranch::String, use_ci_env::Bool)
    # First, check CI environment variables if enabled (most reliable in CI/CD)
    if use_ci_env
        # Travis CI detection
        travis_pr = get(ENV, "TRAVIS_PULL_REQUEST", "")
        if !isempty(travis_pr) && travis_pr != "false"
            @debug "DocumenterDrafts: Detected Travis PR" travis_pr
            return true
        end

        # GitHub Actions detection
        github_event = get(ENV, "GITHUB_EVENT_NAME", "")
        if github_event == "pull_request"
            @debug "DocumenterDrafts: Detected GitHub Actions PR"
            return true
        end

        # GitLab CI detection
        gitlab_mr = get(ENV, "CI_MERGE_REQUEST_ID", "")
        if !isempty(gitlab_mr)
            @debug "DocumenterDrafts: Detected GitLab MR" gitlab_mr
            return true
        end
    end

    # Fallback: Check git branch name (useful for local development)
    try
        current_branch = readchomp(`git branch --show-current`)

        # If current branch is different from devbranch, assume it's a PR branch
        is_pr = current_branch != devbranch

        if is_pr
            @debug "DocumenterDrafts: On non-dev branch" current_branch devbranch
        end

        return is_pr
    catch e
        @warn "DocumenterDrafts: Failed to determine git branch" exception=e
        return false  # Safe default: build everything fully
    end
end


"""
    get_modified_docs(devbranch::String) -> Set{String}

Gets list of modified .md files in docs/ directory.

Uses `git diff --name-only devbranch...HEAD -- docs/*.md` to get changes
since the branch diverged from devbranch (three dots).

Returns a Set of relative paths (with "docs/" prefix stripped) to match
page filenames in Documenter.

Returns empty set on errors (safe default: build everything fully).
"""
function get_modified_docs(devbranch::String)
    try
        # Get diff of .md files in docs/ between base branch and current HEAD
        # Using three dots (...) to get changes since divergence
        cmd = `git diff --name-only $(devbranch)...HEAD -- docs/`
        output = readchomp(cmd)

        if isempty(output)
            @debug "DocumenterDrafts: No modified files detected"
            return Set{String}()
        end

        # Parse output into set of relative paths
        files = split(output, '\n')
        # Strip "docs/" prefix to match page filenames and filter for .md files
        modified = Set{String}()
        for f in files
            if startswith(f, "docs/") && endswith(f, ".md")
                # Remove "docs/" prefix (length 5) to get relative path
                relative_path = f[6:end]
                push!(modified, relative_path)
            end
        end

        return modified
    catch e
        @warn "DocumenterDrafts: Failed to get git diff, building all pages fully" exception=e
        return Set{String}()  # Safe fallback: build everything
    end
end


"""
    should_build_full(filename::String, modified_files::Set{String}, always_include::Vector{String}) -> Bool

Determines if a page should be built fully (not marked as draft).

Returns true if:
- The page is in the `always_include` list, OR
- The page was modified (in `modified_files`)

Returns false otherwise (page will be marked as draft).
"""
function should_build_full(filename::String, modified_files::Set{String}, always_include::Vector{String})
    # Check if in always_include list
    if filename in always_include
        return true
    end

    # Check if file was modified
    if filename in modified_files
        return true
    end

    return false
end
