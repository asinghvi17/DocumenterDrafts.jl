# Example usage of DocumenterDrafts
#
# This file demonstrates how to use DocumenterDrafts in your docs/make.jl file.
# Copy the relevant parts to your project's docs/make.jl.

using Documenter
using DocumenterDrafts

# Define common configuration (shared between makedocs and deploydocs)
devbranch = "main"  # or "master" depending on your repository
repo_slug = "MyOrg/MyPackage.jl"

# Build documentation with draft marking for PRs
makedocs(
    sitename = "MyPackage.jl",

    # Standard Documenter configuration
    format = Documenter.HTML(
        prettyurls = get(ENV, "CI", "false") == "true",
        canonical = "https://myorg.github.io/MyPackage.jl",
        assets = String[],
    ),

    # Documentation pages
    pages = [
        "Home" => "index.md",
        "Getting Started" => "getting-started.md",
        "User Guide" => [
            "guide/basics.md",
            "guide/advanced.md",
        ],
        "API Reference" => "api.md",
        "Developer Guide" => "dev/contributing.md",
    ],

    # DocumenterDrafts plugin configuration
    plugins = [
        DraftConfig(
            # Pages that should ALWAYS be built fully, even on PRs
            always_include = [
                "index.md",           # Homepage
                "getting-started.md", # Critical onboarding page
                "api.md",            # API reference
            ],

            # Development branch (same as deploydocs)
            devbranch = devbranch,

            # Repository validation (optional but recommended)
            repo = repo_slug,

            # Enable CI environment variable detection
            # (Travis, GitHub Actions, GitLab)
            use_ci_env = true,

            # Master enable/disable switch
            # You can disable for local builds:
            # enabled = get(ENV, "CI", "false") == "true"
            enabled = true,
        )
    ]
)

# Deploy documentation (only from devbranch, not from PRs)
deploydocs(
    repo = "github.com/$repo_slug",
    devbranch = devbranch,
    push_preview = true,  # Enable preview deployments for PRs if desired
)

# How this works:
#
# 1. On the main/master branch:
#    - is_pull_request() returns false
#    - All pages are built fully (no drafts)
#    - deploydocs() deploys to gh-pages
#
# 2. On a PR branch:
#    - is_pull_request() returns true
#    - Modified pages + always_include pages are built fully
#    - Other pages are marked with page.globals.meta[:Draft] = true
#    - deploydocs() skips deployment (unless push_preview = true)
#
# 3. Writers can check draft status:
#    if get(page.globals.meta, :Draft, false)
#        # Add "DRAFT" watermark
#        # Skip expensive rendering
#        # etc.
#    end
