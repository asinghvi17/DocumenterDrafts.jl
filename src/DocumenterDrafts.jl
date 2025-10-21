"""
# DocumenterDrafts

A Documenter.jl plugin that intelligently marks documentation pages as drafts
based on Git PR branch status and file changes.

This plugin helps optimize documentation builds by only building complete versions
of modified or critical pages when building documentation for Pull Requests.

## Features

- **PR Detection**: Automatically detects PR context via CI environment variables
  (Travis, GitHub Actions, GitLab) or git branch comparison
- **Selective Drafting**: Marks only unmodified pages as drafts
- **Always Include List**: Specify critical pages that should always be built fully
- **deploydocs Integration**: Uses same `devbranch` and `repo` parameters as deploydocs
- **Safe Defaults**: Builds everything fully when uncertain

## Quick Start

```julia
using Documenter
using DocumenterDrafts

makedocs(
    sitename = "MyPackage.jl",
    plugins = [
        DraftConfig(
            always_include = ["index.md", "api/core.md"],
            devbranch = "main",
            repo = "MyOrg/MyPackage.jl"
        )
    ]
)
```

## How It Works

1. Detects if building for a PR (via CI env vars or git branch)
2. If on a PR, uses `git diff` to find modified .md files in docs/
3. Marks unmodified pages with `page.globals.meta[:Draft] = true`
4. Pages in `always_include` are always built fully
5. Writers can check draft status to adjust rendering

## Exports

- [`DraftConfig`](@ref): Plugin configuration struct
- [`DraftMarking`](@ref): Pipeline step (automatically registered)
"""
module DocumenterDrafts

using Documenter

# Include submodules
include("types.jl")
include("git_utils.jl")
include("draft_pipeline.jl")

# Export main configuration
export DraftConfig

# Export pipeline step (for documentation purposes)
export DraftMarking

end # module DocumenterDrafts
