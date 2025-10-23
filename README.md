# DocumenterDrafts.jl

A [Documenter.jl](https://github.com/JuliaDocs/Documenter.jl) plugin that intelligently marks documentation pages as drafts based on Git PR branch status and file changes.

## Overview

When building documentation for Pull Requests, you often don't need to fully render all pages—only the ones that have been modified. This plugin helps optimize PR documentation builds by:

1. Detecting when building for a PR (via CI environment variables or git branch)
2. Using `git diff` to identify modified `.md` files in `docs/`
3. Marking unmodified pages with `page.globals.meta[:Draft] = true`
4. Allowing you to specify critical pages that should always be built fully

This works seamlessly with Documenter's `deploydocs` workflow:
- `deploydocs` prevents deployment when on a PR branch
- `DocumenterDrafts` marks pages as drafts when on a PR branch
- Both use the same `devbranch` and `repo` parameters for consistency

## Installation

```julia
using Pkg
Pkg.add("DocumenterDrafts")
```

## Quick Start

In your `docs/make.jl`:

### Method 1: Using `deploy_config` (Recommended)

This approach shares configuration between `DraftConfig` and `deploydocs`, reducing duplication:

```julia
using Documenter
using DocumenterDrafts

# Define deploy configuration once
deploy_config = (
    repo = "github.com/MyOrg/MyPackage.jl",
    devbranch = "main",
    push_preview = true,
)

# Build docs with draft marking for PRs
makedocs(
    sitename = "MyPackage.jl",
    repo = "https://github.com/MyOrg/MyPackage.jl",  # Auto-detected by DraftConfig
    pages = [
        "Home" => "index.md",
        "Guide" => "guide.md",
        "API" => "api.md",
    ],
    plugins = [
        DraftConfig(
            always_include = ["index.md", "api.md"],
            deploy_config = deploy_config,  # Reuse deploy config
        )
    ]
)

# Deploy docs - reuse the same config
deploydocs(;deploy_config...)
```

### Method 2: Auto-detection from `makedocs`

The simplest approach - just specify `devbranch` and let `repo` be auto-detected:

```julia
makedocs(
    sitename = "MyPackage.jl",
    repo = "https://github.com/MyOrg/MyPackage.jl",  # DraftConfig reads this
    plugins = [
        DraftConfig(
            always_include = ["index.md", "api.md"],
            devbranch = "main",  # Only parameter you need to specify
        )
    ]
)

deploydocs(
    repo = "github.com/MyOrg/MyPackage.jl",
    devbranch = "main",
)
```

## Configuration

The `DraftConfig` struct accepts the following parameters:

### `always_include::Vector{String}` (default: `[]`)

List of page paths (relative to `docs/`) that should ALWAYS be fully built, regardless of whether they were modified.

```julia
always_include = ["index.md", "getting-started.md", "api/core.md"]
```

### `devbranch::String` (default: `"master"`)

The development branch to compare against (similar to `deploydocs`' `devbranch`). This is the main branch that PRs are typically made against.

```julia
devbranch = "main"
```

### `deploy_config::Union{NamedTuple, Nothing}` (default: `nothing`)

**Recommended approach**: Pass a NamedTuple containing deploydocs configuration. This allows sharing configuration between `DraftConfig` and `deploydocs`, reducing duplication.

When provided, `devbranch` and `repo` will be extracted from this config, overriding individual parameters.

```julia
deploy_config = (
    repo = "github.com/MyOrg/MyPackage.jl",
    devbranch = "main",
    push_preview = true,
)

DraftConfig(deploy_config = deploy_config)
```

Then reuse it:
```julia
deploydocs(;deploy_config...)
```

### `repo::Union{String, Nothing}` (default: `nothing`)

Repository slug for validation (optional). Format: `"owner/repo"` (e.g., `"JuliaDocs/Documenter.jl"`).

**Auto-detection priority**:
1. If `deploy_config` is provided, extracts repo from there
2. If explicitly set, uses the provided value
3. Otherwise, auto-detects from `makedocs(repo = "...")`

Handles various formats automatically:
- `"github.com/owner/repo"` → `"owner/repo"`
- `"https://github.com/owner/repo"` → `"owner/repo"`
- `"owner/repo.git"` → `"owner/repo"`

```julia
repo = "MyOrg/MyPackage.jl"  # Explicit
# or
repo = nothing  # Auto-detect from makedocs
```

### `use_ci_env::Bool` (default: `true`)

Whether to use CI environment variables to detect PR status. When `true`, checks:
- Travis CI: `TRAVIS_PULL_REQUEST`
- GitHub Actions: `GITHUB_EVENT_NAME`
- GitLab CI: `CI_MERGE_REQUEST_ID`

When `false`, relies solely on git branch comparison.

```julia
use_ci_env = true  # Recommended for CI/CD environments
```

### `enabled::Bool` (default: `true`)

Master enable/disable switch. Can be used to disable the plugin in production builds.

```julia
enabled = true

# Or dynamically:
enabled = !isinteractive()  # Only enable in CI
```

## How It Works

1. **PR Detection**: Checks CI environment variables (Travis, GitHub Actions, GitLab) or compares git branch to `devbranch`
2. **Git Diff**: Runs `git diff devbranch...HEAD -- docs/` to find modified files
3. **Draft Marking**: Sets `page.globals.meta[:Draft] = true` for unmodified pages
4. **Safe Defaults**: If any check fails, builds all pages fully (conservative approach)

## Using Draft Status in Writers

Writers (HTML, LaTeX, Markdown) can check if a page is marked as a draft:

```julia
is_draft = get(page.globals.meta, :Draft, false)

if is_draft
    # Add "DRAFT" watermark
    # Skip expensive rendering (plots, diagrams)
    # Add <meta name="robots" content="noindex"> tag
    # Reduce doctest strictness
end
```

## CI/CD Integration

### GitHub Actions

```yaml
name: Documentation

on:
  pull_request:
  push:
    branches:
      - main

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - uses: julia-actions/setup-julia@v1
      - name: Build docs
        run: julia --project=docs/ docs/make.jl
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

The plugin automatically detects `GITHUB_EVENT_NAME=pull_request`.

### Travis CI

```yaml
language: julia
julia:
  - 1.6
jobs:
  include:
    - stage: "Documentation"
      julia: 1.6
      script:
        - julia --project=docs/ docs/make.jl
```

The plugin automatically detects `TRAVIS_PULL_REQUEST` != "false".

## Parameter Alignment with deploydocs

| deploydocs | DraftConfig | Purpose |
|-----------|-------------|---------|
| `devbranch` | `devbranch` | Main development branch |
| `repo` | `repo` | Repository slug for validation |
| N/A | `always_include` | Pages to always build fully |
| N/A | `use_ci_env` | Whether to check CI env vars |
| N/A | `enabled` | Master enable/disable switch |

## Example: Local Development

For local development, you might want to disable the plugin:

```julia
makedocs(
    sitename = "MyPackage.jl",
    plugins = [
        DraftConfig(
            enabled = get(ENV, "CI", "false") == "true",  # Only enable in CI
            devbranch = "main",
        )
    ]
)
```

## Troubleshooting

### Plugin not activating

Check debug logs:
```julia
ENV["JULIA_DEBUG"] = "DocumenterDrafts"
```

### All pages marked as drafts

- Ensure `always_include` contains critical pages
- Check that `devbranch` matches your main branch name
- Verify git diff is detecting changes correctly

### No pages marked as drafts

- Check that you're on a PR branch (not `devbranch`)
- Verify CI environment variables are set correctly
- Ensure `enabled = true`

## License

MIT License - see LICENSE file for details.
