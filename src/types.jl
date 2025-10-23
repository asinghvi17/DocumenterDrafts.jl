"""
    DraftConfig <: Documenter.Plugin

Configuration for the DocumenterDrafts plugin that marks pages as drafts
based on PR status and git changes.

# Fields

- `always_include::Vector{String}`: List of page paths (relative to docs/) that should
  ALWAYS be fully built, regardless of whether they were modified.
  Example: `["index.md", "guides/quickstart.md"]`

- `enabled::Bool`: Whether to enable the draft plugin. Can be used to disable in production
  builds. Automatically disables when not on a PR (checked via CI environment variables).
  Default: `true`

- `devbranch::String`: The development branch to compare against (similar to deploydocs'
  devbranch). This is the main branch that PRs are typically made against.
  Default: `"master"` (to match Documenter's default)

- `deploy_config::Union{NamedTuple, Nothing}`: Deploy configuration that matches deploydocs
  parameters. If provided, `devbranch` and other parameters will be extracted from this.
  Expected fields: `(devbranch = "...", repo = "...", ...)`
  Default: `nothing`

- `repo::Union{String, Nothing}`: Repository slug for validation (optional).
  Format: "owner/repo" (e.g., "JuliaDocs/Documenter.jl").
  If `nothing`, will be extracted from `doc.user.repo` during pipeline execution.
  If provided explicitly, overrides the document's repo.
  Default: `nothing` (auto-detect from Document)

- `use_ci_env::Bool`: Whether to use CI environment variables to detect PR status.
  When true, checks TRAVIS_PULL_REQUEST, GITHUB_EVENT_NAME, etc.
  When false, relies solely on git branch comparison.
  Default: `true` (recommended for CI/CD environments)

# Examples

## Using deploy_config (recommended)

```julia
using Documenter
using DocumenterDrafts

deploy_conf = (
    repo = "github.com/MyOrg/MyPackage.jl",
    devbranch = "main",
)

makedocs(
    sitename = "MyPackage.jl",
    repo = "https://github.com/MyOrg/MyPackage.jl",  # Sets doc.user.repo
    plugins = [
        DraftConfig(
            always_include = ["index.md", "api/core.md"],
            deploy_config = deploy_conf
        )
    ]
)

deploydocs(;deploy_conf...)
```

## Using individual parameters

```julia
makedocs(
    sitename = "MyPackage.jl",
    repo = "https://github.com/MyOrg/MyPackage.jl",
    plugins = [
        DraftConfig(
            always_include = ["index.md", "api/core.md"],
            devbranch = "main"
            # repo will be auto-detected from makedocs' repo parameter
        )
    ]
)
```

## Explicit repo override

```julia
makedocs(
    plugins = [
        DraftConfig(
            devbranch = "main",
            repo = "MyOrg/MyPackage.jl"  # Explicit repo slug
        )
    ]
)
```
"""
Base.@kwdef struct DraftConfig <: Documenter.Plugin
    always_include::Vector{String} = String[]
    enabled::Bool = true
    devbranch::String = "master"
    deploy_config::Union{NamedTuple, Nothing} = nothing
    repo::Union{String, Nothing} = nothing
    use_ci_env::Bool = true
end


"""
    get_effective_devbranch(config::DraftConfig) -> String

Returns the effective devbranch, preferring deploy_config if available.
"""
function get_effective_devbranch(config::DraftConfig)
    if config.deploy_config !== nothing && haskey(config.deploy_config, :devbranch)
        return config.deploy_config.devbranch
    end
    return config.devbranch
end


"""
    get_effective_repo(config::DraftConfig, doc) -> Union{String, Nothing}

Returns the effective repository slug, with priority:
1. deploy_config.repo (if present)
2. config.repo (if explicitly set)
3. doc.user.repo (auto-detected from makedocs)

The repo from deploydocs may include "github.com/" prefix which we extract.

The `doc` parameter should be a `Documenter.Documents.Document` instance.
"""
function get_effective_repo(config::DraftConfig, doc)
    # Priority 1: deploy_config
    if config.deploy_config !== nothing && haskey(config.deploy_config, :repo)
        repo_str = config.deploy_config.repo
        # Extract owner/repo from "github.com/owner/repo" or similar
        return extract_repo_slug(repo_str)
    end

    # Priority 2: Explicit config.repo
    if config.repo !== nothing
        return config.repo
    end

    # Priority 3: doc.user.repo (from makedocs)
    if !isempty(doc.user.repo)
        return extract_repo_slug(doc.user.repo)
    end

    return nothing
end


"""
    extract_repo_slug(repo_url::String) -> String

Extracts the owner/repo slug from various repo URL formats:
- "github.com/owner/repo" -> "owner/repo"
- "https://github.com/owner/repo" -> "owner/repo"
- "owner/repo" -> "owner/repo"
- "owner/repo.git" -> "owner/repo"
"""
function extract_repo_slug(repo_url::String)
    # Remove protocol if present
    repo = replace(repo_url, r"^https?://" => "")

    # Remove github.com/ if present
    repo = replace(repo, r"^github\.com/" => "")

    # Remove gitlab.com/ if present
    repo = replace(repo, r"^gitlab\.com/" => "")

    # Remove .git suffix if present
    repo = replace(repo, r"\.git$" => "")

    # Remove trailing slashes
    repo = rstrip(repo, '/')

    return repo
end
