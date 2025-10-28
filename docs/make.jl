using Documenter
using DocumenterDrafts

# Dogfooding - use DraftConfig on itself!
deploy_config = (;
    devbranch = "main",
    push_preview = true,
)

makedocs(
    sitename = "DocumenterDrafts.jl",
    modules = [DocumenterDrafts],
    repo = "https://github.com/asinghvi17/DocumenterDrafts.jl",
    format = Documenter.HTML(
        canonical = "https://asinghvi17.github.io/DocumenterDrafts.jl",
        assets = String[],
        prettyurls = get(ENV, "CI", "false") == "true",
    ),
    pages = [
        "Home" => "index.md",
        "User Guide" => "guide.md",
        "API Reference" => "api.md",
        "This should be draft" => "tryme.md",
    ],
    plugins = [
        DraftConfig(
            always_include = ["index.md"],
            deploy_config = deploy_config,
        )
    ],
    warnonly = [:missing_docs],
    doctest = false,
)

deploydocs(; repo = "github.com/asinghvi17/DocumenterDrafts.jl", deploy_config...)
