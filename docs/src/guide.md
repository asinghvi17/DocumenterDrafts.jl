# User Guide

## Configuration

### `DraftConfig` Parameters

#### `always_include::Vector{String}` (default: `[]`)

Pages that should ALWAYS be fully built, regardless of modification status.

```julia
DraftConfig(always_include = ["index.md", "getting-started.md", "api/core.md"])
```

Use this for:
- Critical pages (homepage, getting started)
- Pages that must always be complete
- Navigation-critical documentation

#### `devbranch::String` (default: `"master"`)

The main development branch that PRs are made against.

```julia
DraftConfig(devbranch = "main")
```

#### `deploy_config::Union{NamedTuple, Nothing}` (default: `nothing`)

**Recommended approach**: Share configuration with `deploydocs`.

```julia
deploy_config = (
    repo = "github.com/MyOrg/MyPackage.jl",
    devbranch = "main",
    push_preview = true,
)

DraftConfig(deploy_config = deploy_config)
deploydocs(;deploy_config...)
```

When provided, `devbranch` and `repo` are extracted from this config, overriding individual parameters.

#### `repo::Union{String, Nothing}` (default: `nothing`)

Repository slug for validation (optional). Format: `"owner/repo"`.

**Auto-detection priority**:
1. `deploy_config.repo` (if present)
2. Explicit `config.repo` (if set)
3. `makedocs(repo = "...")` (auto-detected from Document)

The plugin automatically handles various repo URL formats:
- `"github.com/owner/repo"` → `"owner/repo"`
- `"https://github.com/owner/repo"` → `"owner/repo"`
- `"owner/repo.git"` → `"owner/repo"`

#### `use_ci_env::Bool` (default: `true`)

Whether to check CI environment variables for PR detection.

**Checked variables**:
- Travis CI: `TRAVIS_PULL_REQUEST`
- GitHub Actions: `GITHUB_EVENT_NAME`
- GitLab CI: `CI_MERGE_REQUEST_ID`

Set to `false` to rely solely on git branch comparison.

#### `enabled::Bool` (default: `true`)

Master enable/disable switch.

```julia
# Only enable in CI
DraftConfig(enabled = get(ENV, "CI", "false") == "true")

# Disable for local builds
DraftConfig(enabled = !isinteractive())
```

---

## Usage Patterns

### Pattern 1: Shared `deploy_config` (Recommended)

```julia
deploy_config = (
    repo = "github.com/MyOrg/MyPackage.jl",
    devbranch = "main",
    push_preview = true,
)

makedocs(
    sitename = "MyPackage",
    repo = "https://github.com/MyOrg/MyPackage.jl",
    plugins = [
        DraftConfig(
            always_include = ["index.md"],
            deploy_config = deploy_config,
        )
    ]
)

deploydocs(;deploy_config...)
```

**Pros**:
- ✅ Single source of truth for `devbranch` and `repo`
- ✅ No duplication
- ✅ Easy to maintain

**Cons**:
- None!

### Pattern 2: Auto-detection from `makedocs`

```julia
makedocs(
    sitename = "MyPackage",
    repo = "https://github.com/MyOrg/MyPackage.jl",
    plugins = [
        DraftConfig(
            always_include = ["index.md"],
            devbranch = "main",
        )
    ]
)

deploydocs(
    repo = "github.com/MyOrg/MyPackage.jl",
    devbranch = "main",
)
```

**Pros**:
- ✅ Simple and straightforward
- ✅ Repo auto-detected from `makedocs`

**Cons**:
- ⚠️ Must specify `devbranch` in both places

### Pattern 3: Explicit Configuration

```julia
makedocs(
    sitename = "MyPackage",
    plugins = [
        DraftConfig(
            always_include = ["index.md"],
            devbranch = "main",
            repo = "MyOrg/MyPackage.jl",
        )
    ]
)
```

**Pros**:
- ✅ Explicit and clear

**Cons**:
- ⚠️ More verbose
- ⚠️ Manual repo specification

---

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
      - uses: actions/checkout@v4
      - uses: julia-actions/setup-julia@v2
      - name: Build documentation
        run: julia --project=docs/ docs/make.jl
        env:
          GITHUB_TOKEN: \${{ secrets.GITHUB_TOKEN }}
          DOCUMENTER_KEY: \${{ secrets.DOCUMENTER_KEY }}
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

### GitLab CI

```yaml
docs:
  script:
    - julia --project=docs/ docs/make.jl
  only:
    - merge_requests
    - main
```

The plugin automatically detects `CI_MERGE_REQUEST_ID`.

---

## How Draft Status Works

### Setting Draft Status

The plugin sets `page.globals.meta[:Draft] = true` for pages that should be drafted.

### Checking Draft Status in Writers

Writers and custom post-processors can check if a page is marked as a draft:

```julia
function process_page(page::Documenter.Documents.Page)
    is_draft = get(page.globals.meta, :Draft, false)

    if is_draft
        # Add "DRAFT" watermark
        # Skip expensive rendering (plots, diagrams)
        # Add <meta name="robots" content="noindex">
        # Use simplified rendering
    else
        # Full rendering with all features
    end
end
```

### Example: Custom HTML Writer

```julia
function add_draft_banner(html_content::String, page::Documenter.Documents.Page)
    is_draft = get(page.globals.meta, :Draft, false)

    if is_draft
        banner = """
        <div class="draft-banner">
            ⚠️ DRAFT: This page may not be complete.
        </div>
        """
        return banner * html_content
    end

    return html_content
end
```

---

## Troubleshooting

### Plugin Not Activating

**Check debug logs**:
```julia
ENV["JULIA_DEBUG"] = "DocumenterDrafts"
```

**Common causes**:
1. Not on a PR branch (check git branch vs `devbranch`)
2. CI environment variables not set
3. `enabled = false`
4. Repo validation mismatch

### All Pages Marked as Drafts

**Verify `always_include`**:
```julia
DraftConfig(always_include = ["index.md", "critical-page.md"])
```

**Check file paths**: Ensure paths are relative to `docs/src/`:
- ✅ `"index.md"`
- ✅ `"guide/quickstart.md"`
- ❌ `"docs/src/index.md"` (too long)
- ❌ `"/index.md"` (absolute path)

### No Pages Marked as Drafts

**Possible causes**:
1. On `devbranch` (not a PR)
2. Plugin disabled (`enabled = false`)
3. Repo validation failed
4. Git diff failed

**Check CI detection**:
```julia
# Force CI detection off to test git branch detection
DraftConfig(use_ci_env = false)
```

### Git Diff Not Detecting Changes

**Verify git setup**:
```bash
git status
git log --oneline
git diff main...HEAD -- docs/
```

**Common issues**:
- Not in a git repository
- Branch not diverged from `devbranch`
- Modified files not in `docs/` directory
- Files not committed

---

## Best Practices

### 1. Always Include Critical Pages

```julia
always_include = [
    "index.md",           # Homepage
    "getting-started.md", # Onboarding
    "api/core.md",       # Core API reference
]
```

### 2. Use `deploy_config` for DRY

```julia
deploy_config = (repo = "...", devbranch = "...")
# Use in both DraftConfig and deploydocs
```

### 3. Enable Only in CI

```julia
DraftConfig(enabled = get(ENV, "CI", "false") == "true")
```

### 4. Test Locally

```julia
# On a feature branch, run:
julia --project=docs/ docs/make.jl

# Check docs/build/ for drafted pages
```

### 5. Monitor Logs

Look for:
```
DocumenterDrafts: Found 2 modified docs
DocumenterDrafts: Marked 3/10 pages as drafts
```

---

## Advanced Usage

### Custom Pipeline Integration

You can check draft status in custom pipeline steps:

```julia
abstract type MyCustomStep <: Documenter.Builder.DocumentPipeline end

function Documenter.Selectors.runner(::Type{MyCustomStep}, doc::Documenter.Document)
    for (filename, page) in doc.blueprint.pages
        if get(page.globals.meta, :Draft, false)
            # Skip expensive processing for drafts
            continue
        end
        # Full processing for non-drafts
    end
end
```

### Conditional Rendering

```julia
function should_render_expensive_content(page)
    return !get(page.globals.meta, :Draft, false)
end
```
