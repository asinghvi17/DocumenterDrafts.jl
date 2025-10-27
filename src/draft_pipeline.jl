"""
    DraftMarking <: Documenter.Builder.DocumentPipeline

Pipeline step that marks documentation pages as drafts based on PR status and git changes.

This step:
1. Checks if the plugin is enabled
2. Validates the repository (if configured)
3. Detects if building for a PR (via CI env vars or git)
4. Gets list of modified .md files via git diff
5. Marks unmodified pages as drafts (except those in always_include)

The draft status is set via `page.globals.meta[:Draft] = true`, which can be
checked by writers (HTML, LaTeX) to adjust rendering.

Runs at priority 0.9, before SetupBuildDirectory (1.0), to ensure pages are
marked before any rendering occurs.
"""
abstract type DraftMarking <: Documenter.Builder.DocumentPipeline end

Documenter.Selectors.order(::Type{DraftMarking}) = 0.9  # Before SetupBuildDirectory


"""
    Documenter.Selectors.runner(::Type{DraftMarking}, doc::Documenter.Document)

Main runner function for the DraftMarking pipeline step.

Retrieves the DraftConfig plugin from the document, performs all checks,
and marks appropriate pages as drafts.
"""
function Documenter.Selectors.runner(::Type{DraftMarking}, doc::Documenter.Document)
    settings = Documenter.getplugin(doc, DraftConfig)

    # Step 1: Check if plugin is enabled
    if !settings.enabled
        @debug "DocumenterDrafts: Plugin disabled via config"
        return
    end

    # Step 2: Get effective configuration (respecting deploy_config, explicit config, and doc.user)
    devbranch = get_effective_devbranch(settings)
    repo_slug = get_effective_repo(settings, doc)

    @debug "DocumenterDrafts: Effective configuration" devbranch repo_slug

    # Step 3: Validate repo if specified
    if repo_slug !== nothing && settings.use_ci_env
        travis_repo_slug = get(ENV, "TRAVIS_REPO_SLUG", "")
        github_repository = get(ENV, "GITHUB_REPOSITORY", "")
        repo_match = occursin(repo_slug, travis_repo_slug) ||
                     occursin(repo_slug, github_repository)
        if !repo_match
            @debug "DocumenterDrafts: Repo mismatch, skipping" repo_slug travis_repo_slug github_repository
            return
        end
    end

    # Step 4: Check if on a PR branch
    is_pr = is_pull_request(doc, devbranch, settings.use_ci_env)
    if !is_pr
        @debug "DocumenterDrafts: Not on a PR, building all pages fully"
        return  # Not on PR, build everything normally
    end

    # Step 5: Get list of modified .md files
    modified_files = get_modified_docs(doc, devbranch)
    @info "DocumenterDrafts: Found $(length(modified_files)) modified docs" modified_files

    # Step 6: Iterate over pages and mark drafts
    draft_count = 0
    for (filename, page) in doc.blueprint.pages
        should_be_draft = !should_build_full(
            filename,
            modified_files,
            settings.always_include
        )

        if should_be_draft
            page.globals.meta[:Draft] = true
            draft_count += 1
            @debug "DocumenterDrafts: Marked as draft" filename
        else
            @debug "DocumenterDrafts: Building fully" filename
        end
    end

    @info "DocumenterDrafts: Marked $draft_count/$(length(doc.blueprint.pages)) pages as drafts"
end
