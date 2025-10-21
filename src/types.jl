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

- `repo::Union{String, Nothing}`: Repository slug for validation (optional).
  Format: "owner/repo" (e.g., "JuliaDocs/Documenter.jl").
  If provided, plugin only activates when building docs for this repo.
  Default: `nothing`

- `use_ci_env::Bool`: Whether to use CI environment variables to detect PR status.
  When true, checks TRAVIS_PULL_REQUEST, GITHUB_EVENT_NAME, etc.
  When false, relies solely on git branch comparison.
  Default: `true` (recommended for CI/CD environments)

# Example

```julia
using Documenter
using DocumenterDrafts

makedocs(
    sitename = "MyPackage.jl",
    plugins = [
        DraftConfig(
            always_include = ["index.md", "api/core.md"],
            devbranch = "main",
            repo = "MyOrg/MyPackage.jl",
            use_ci_env = true,
            enabled = true
        )
    ]
)
```
"""
Base.@kwdef struct DraftConfig <: Documenter.Plugin
    always_include::Vector{String} = String[]
    enabled::Bool = true
    devbranch::String = "master"
    repo::Union{String, Nothing} = nothing
    use_ci_env::Bool = true
end
