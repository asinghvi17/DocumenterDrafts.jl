# DocumenterDrafts.jl

*A Documenter.jl plugin for intelligent draft page marking in Pull Request builds.*

## Overview

DocumenterDrafts.jl helps optimize documentation builds for Pull Requests by marking only unmodified pages as drafts. This allows you to:

- ⚡ Speed up PR documentation builds by skipping expensive rendering for unchanged pages
- 🎯 Focus review on modified documentation
- 🔄 Seamlessly integrate with Documenter's `deploydocs` workflow
- 🤖 Auto-detect PR context from CI environment variables

## Installation

```julia
using Pkg
Pkg.add("DocumenterDrafts")
```

## Quick Start

### Method 1: Using `deploy_config` (Recommended)

Share configuration between `DraftConfig` and `deploydocs`:

```julia
using Documenter
using DocumenterDrafts

deploy_config = (
    repo = "github.com/MyOrg/MyPackage.jl",
    devbranch = "main",
)

makedocs(
    sitename = "MyPackage.jl",
    repo = "https://github.com/MyOrg/MyPackage.jl",
    pages = [
        "Home" => "index.md",
        "Guide" => "guide.md",
        "API" => "api.md",
    ],
    plugins = [
        DraftConfig(
            always_include = ["index.md", "api.md"],
            deploy_config = deploy_config,
        )
    ]
)

deploydocs(;deploy_config...)
```

### Method 2: Auto-detection from `makedocs`

Let the plugin auto-detect the repository from `makedocs`:

```julia
makedocs(
    sitename = "MyPackage.jl",
    repo = "https://github.com/MyOrg/MyPackage.jl",  # Auto-detected
    plugins = [
        DraftConfig(
            always_include = ["index.md"],
            devbranch = "main",
        )
    ]
)
```

## How It Works

1. **PR Detection**: Checks CI environment variables (Travis, GitHub Actions, GitLab) or compares git branch to `devbranch`
2. **Git Diff**: Runs `git diff devbranch...HEAD -- docs/` to find modified files
3. **Draft Marking**: Sets `page.globals.meta[:Draft] = true` for unmodified pages (except `always_include`)
4. **Writer Integration**: Writers can check draft status to adjust rendering

## Features

- ✅ **CI-aware**: Detects PRs via Travis, GitHub Actions, and GitLab environment variables
- ✅ **Git-integrated**: Uses `git diff` to identify modified documentation files
- ✅ **Flexible**: Supports `always_include` list for critical pages
- ✅ **deploydocs integration**: Shares `devbranch` and `repo` parameters
- ✅ **Safe defaults**: Builds everything fully when uncertain
- ✅ **Directory-agnostic**: Runs git commands in correct directory using `doc.user.root`

## Next Steps

- **[User Guide](guide.md)**: Detailed usage patterns, CI/CD integration, and troubleshooting
- **[API Reference](api.md)**: Complete API documentation for all functions and types

## Related Links

- **GitHub**: [asinghvi17/DocumenterDrafts.jl](https://github.com/asinghvi17/DocumenterDrafts.jl)
- **Documenter.jl**: [JuliaDocs/Documenter.jl](https://github.com/JuliaDocs/Documenter.jl)
