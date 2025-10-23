# Example usage of DocumenterDrafts
#
# This file demonstrates how to use DocumenterDrafts in your docs/make.jl file.
# Copy the relevant parts to your project's docs/make.jl.

using Documenter
using DocumenterDrafts

# ============================================================================
# METHOD 1: Using deploy_config (RECOMMENDED)
# ============================================================================
# This approach shares configuration between DraftConfig and deploydocs,
# reducing duplication and ensuring consistency.

# Define deploy configuration once
deploy_config = (
    repo = "github.com/MyOrg/MyPackage.jl",
    devbranch = "main",
    push_preview = true,
)

# Build documentation with draft marking for PRs
makedocs(
    sitename = "MyPackage.jl",

    # Set the repo in makedocs - DraftConfig will auto-detect from this
    repo = "https://github.com/MyOrg/MyPackage.jl",

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

    # DocumenterDrafts plugin - uses deploy_config
    plugins = [
        DraftConfig(
            # Pages that should ALWAYS be built fully, even on PRs
            always_include = [
                "index.md",           # Homepage
                "getting-started.md", # Critical onboarding page
                "api.md",            # API reference
            ],

            # Pass the entire deploy configuration
            # This will extract devbranch, repo, etc. automatically
            deploy_config = deploy_config,

            # Enable CI environment variable detection
            use_ci_env = true,

            # Master enable/disable switch
            enabled = true,
        )
    ]
)

# Deploy documentation - reuse the same deploy_config
deploydocs(;deploy_config...)


# ============================================================================
# METHOD 2: Using individual parameters (alternative)
# ============================================================================
# If you prefer not to use deploy_config, you can specify parameters directly.
# The repo will be auto-detected from makedocs' repo parameter.

# makedocs(
#     sitename = "MyPackage.jl",
#     repo = "https://github.com/MyOrg/MyPackage.jl",  # Auto-detected by DraftConfig
#     plugins = [
#         DraftConfig(
#             always_include = ["index.md", "api.md"],
#             devbranch = "main",  # Specify explicitly
#             # repo is auto-detected from makedocs' repo parameter
#         )
#     ]
# )
#
# deploydocs(
#     repo = "github.com/MyOrg/MyPackage.jl",
#     devbranch = "main",
# )


# ============================================================================
# METHOD 3: Explicit repo override
# ============================================================================
# You can override the repo detection if needed

# makedocs(
#     sitename = "MyPackage.jl",
#     plugins = [
#         DraftConfig(
#             always_include = ["index.md"],
#             devbranch = "main",
#             repo = "MyOrg/MyPackage.jl",  # Explicit override
#         )
#     ]
# )

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
