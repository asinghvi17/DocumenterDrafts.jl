@testset "Full document integration" begin
    @testset "PR with modified files - draft marking works" begin
        mktempdir() do tmpdir
            repo_path = joinpath(tmpdir, "TestPackage")
            docs_path = joinpath(repo_path, "docs")
            src_path = joinpath(docs_path, "src")
            mkpath(src_path)

            cd(repo_path) do
                # Initialize git repo
                @test success(`git init`)
                @test success(`git config user.email "test@example.com"`)
                @test success(`git config user.name "Test User"`)
                @test success(`git remote add origin https://github.com/Test/TestPackage.jl`)

                # Create initial docs structure on main branch
                write(joinpath(src_path, "index.md"), "# Home\n\nWelcome!")
                write(joinpath(src_path, "guide.md"), "# Guide\n\nOriginal content")
                write(joinpath(src_path, "api.md"), "# API\n\nAPI docs")
                write(joinpath(src_path, "tutorial.md"), "# Tutorial\n\nTutorial content")

                @test success(`git add -A`)
                @test success(`git commit -m "Initial docs"`)
                @test success(`git branch -M main`)

                # Create PR branch and modify specific files
                @test success(`git checkout -b feature-update-docs`)
                write(joinpath(src_path, "guide.md"), "# Guide\n\nUpdated content!")
                write(joinpath(src_path, "tutorial.md"), "# Tutorial\n\nEnhanced tutorial!")
                @test success(`git add -A`)
                @test success(`git commit -m "Update guide and tutorial"`)

                # Build docs with DraftConfig
                deploy_config = (
                    repo = "github.com/Test/TestPackage.jl",
                    devbranch = "main",
                )

                doc = makedocs(;
                    root = repo_path,
                    source = "docs/src",
                    build = "docs/build",
                    sitename = "TestPackage",
                    pages = [
                        "index.md",
                        "guide.md",
                        "api.md",
                        "tutorial.md",
                    ],
                    plugins = [
                        DraftConfig(
                            always_include = ["index.md"],
                            deploy_config = deploy_config,
                        )
                    ],
                    doctest = false,
                    draft = true,
                    draft = true,
                )

                # Verify document was built
                @test doc isa Documenter.Document
                @test length(doc.blueprint.pages) == 4

                # Verify draft status for each page
                # index.md: in always_include → NOT draft
                @test get(doc.blueprint.pages["index.md"].globals.meta, :Draft, false) == false

                # guide.md: modified → NOT draft
                @test get(doc.blueprint.pages["guide.md"].globals.meta, :Draft, false) == false

                # tutorial.md: modified → NOT draft
                @test get(doc.blueprint.pages["tutorial.md"].globals.meta, :Draft, false) == false

                # api.md: NOT modified, NOT in always_include → IS draft
                @test get(doc.blueprint.pages["api.md"].globals.meta, :Draft, false) == true
            end
        end
    end

    @testset "Main branch - no drafts" begin
        mktempdir() do tmpdir
            repo_path = joinpath(tmpdir, "TestPackage")
            docs_path = joinpath(repo_path, "docs")
            src_path = joinpath(docs_path, "src")
            mkpath(src_path)

            cd(repo_path) do
                # Initialize git repo
                @test success(`git init`)
                @test success(`git config user.email "test@example.com"`)
                @test success(`git config user.name "Test User"`)

                # Create docs on main branch
                write(joinpath(src_path, "index.md"), "# Home")
                write(joinpath(src_path, "guide.md"), "# Guide")

                @test success(`git add -A`)
                @test success(`git commit -m "Initial docs"`)
                @test success(`git branch -M main`)

                # Stay on main branch - should NOT draft anything
                deploy_config = (
                    repo = "github.com/Test/TestPackage.jl",
                    devbranch = "main",
                )

                doc = makedocs(;
                    root = repo_path,
                    source = "docs/src",
                    build = "docs/build",
                    sitename = "TestPackage",
                    pages = ["index.md", "guide.md"],
                    plugins = [
                        DraftConfig(deploy_config = deploy_config)
                    ],
                    doctest = false,
                    draft = true,
                )

                @test doc isa Documenter.Document
                @test length(doc.blueprint.pages) == 2

                # Both pages should be non-draft (we're on main branch)
                @test get(doc.blueprint.pages["index.md"].globals.meta, :Draft, false) == false
                @test get(doc.blueprint.pages["guide.md"].globals.meta, :Draft, false) == false
            end
        end
    end

    @testset "GitHub Actions PR context" begin
        mktempdir() do tmpdir
            repo_path = joinpath(tmpdir, "TestPackage")
            docs_path = joinpath(repo_path, "docs")
            src_path = joinpath(docs_path, "src")
            mkpath(src_path)

            cd(repo_path) do
                @test success(`git init`)
                @test success(`git config user.email "test@example.com"`)
                @test success(`git config user.name "Test User"`)

                write(joinpath(src_path, "index.md"), "# Home")
                write(joinpath(src_path, "guide.md"), "# Guide")
                write(joinpath(src_path, "api.md"), "# API")

                @test success(`git add -A`)
                @test success(`git commit -m "Initial"`)
                @test success(`git branch -M main`)

                # Create feature branch and modify one file
                @test success(`git checkout -b feature`)
                write(joinpath(src_path, "guide.md"), "# Guide\nUpdated!")
                @test success(`git add -A`)
                @test success(`git commit -m "Update guide"`)

                # Simulate GitHub Actions PR environment
                withenv("GITHUB_EVENT_NAME" => "pull_request",
                        "GITHUB_REPOSITORY" => "Test/TestPackage.jl") do

                    deploy_config = (
                        repo = "github.com/Test/TestPackage.jl",
                        devbranch = "main",
                    )

                    doc = makedocs(;
                        root = repo_path,
                        source = "docs/src",
                        build = "docs/build",
                        sitename = "TestPackage",
                        pages = ["index.md", "guide.md", "api.md"],
                        plugins = [
                            DraftConfig(
                                always_include = ["index.md"],
                                deploy_config = deploy_config,
                            )
                        ],
                        doctest = false,
                    draft = true,
                    )

                    # CI detected PR, so drafting should occur
                    @test get(doc.blueprint.pages["index.md"].globals.meta, :Draft, false) == false  # always_include
                    @test get(doc.blueprint.pages["guide.md"].globals.meta, :Draft, false) == false  # modified
                    @test get(doc.blueprint.pages["api.md"].globals.meta, :Draft, false) == true     # not modified
                end
            end
        end
    end

    @testset "Repo validation - mismatched repo" begin
        mktempdir() do tmpdir
            repo_path = joinpath(tmpdir, "TestPackage")
            docs_path = joinpath(repo_path, "docs")
            src_path = joinpath(docs_path, "src")
            mkpath(src_path)

            cd(repo_path) do
                @test success(`git init`)
                @test success(`git config user.email "test@example.com"`)
                @test success(`git config user.name "Test User"`)

                write(joinpath(src_path, "index.md"), "# Home")
                write(joinpath(src_path, "guide.md"), "# Guide")

                @test success(`git add -A`)
                @test success(`git commit -m "Initial"`)
                @test success(`git branch -M main`)
                @test success(`git checkout -b feature`)

                # Simulate wrong repo in CI
                withenv("GITHUB_EVENT_NAME" => "pull_request",
                        "GITHUB_REPOSITORY" => "Wrong/Repo.jl") do

                    deploy_config = (
                        repo = "github.com/Test/TestPackage.jl",  # Different repo
                        devbranch = "main",
                    )

                    doc = makedocs(;
                        root = repo_path,
                        source = "docs/src",
                        build = "docs/build",
                        sitename = "TestPackage",
                        pages = ["index.md", "guide.md"],
                        plugins = [
                            DraftConfig(deploy_config = deploy_config)
                        ],
                        doctest = false,
                    draft = true,
                    )

                    # Plugin should skip due to repo mismatch
                    # All pages should be non-draft
                    @test get(doc.blueprint.pages["index.md"].globals.meta, :Draft, false) == false
                    @test get(doc.blueprint.pages["guide.md"].globals.meta, :Draft, false) == false
                end
            end
        end
    end

    @testset "deploy_config priority over individual params" begin
        mktempdir() do tmpdir
            repo_path = joinpath(tmpdir, "TestPackage")
            docs_path = joinpath(repo_path, "docs")
            src_path = joinpath(docs_path, "src")
            mkpath(src_path)

            cd(repo_path) do
                @test success(`git init`)
                @test success(`git config user.email "test@example.com"`)
                @test success(`git config user.name "Test User"`)

                write(joinpath(src_path, "index.md"), "# Home")
                write(joinpath(src_path, "guide.md"), "# Guide")

                @test success(`git add -A`)
                @test success(`git commit -m "Initial"`)
                @test success(`git branch -M main`)

                # Create branch with different name
                @test success(`git checkout -b feature-branch`)
                write(joinpath(src_path, "guide.md"), "# Guide\nUpdated!")
                @test success(`git add -A`)
                @test success(`git commit -m "Update"`)

                # deploy_config.devbranch should override config.devbranch
                deploy_config = (
                    repo = "github.com/Test/TestPackage.jl",
                    devbranch = "main",  # Correct devbranch
                )

                doc = makedocs(;
                    root = repo_path,
                    source = "docs/src",
                    build = "docs/build",
                    sitename = "TestPackage",
                    pages = ["index.md", "guide.md"],
                    plugins = [
                        DraftConfig(
                            devbranch = "wrong-branch",  # This should be overridden
                            deploy_config = deploy_config,
                        )
                    ],
                    doctest = false,
                    draft = true,
                )

                # Should detect PR correctly using deploy_config.devbranch = "main"
                @test get(doc.blueprint.pages["guide.md"].globals.meta, :Draft, false) == false  # modified
                @test get(doc.blueprint.pages["index.md"].globals.meta, :Draft, false) == true   # not modified
            end
        end
    end

    @testset "Auto-detection from makedocs repo parameter" begin
        mktempdir() do tmpdir
            repo_path = joinpath(tmpdir, "TestPackage")
            docs_path = joinpath(repo_path, "docs")
            src_path = joinpath(docs_path, "src")
            mkpath(src_path)

            cd(repo_path) do
                @test success(`git init`)
                @test success(`git config user.email "test@example.com"`)
                @test success(`git config user.name "Test User"`)

                write(joinpath(src_path, "index.md"), "# Home")
                write(joinpath(src_path, "guide.md"), "# Guide")

                @test success(`git add -A`)
                @test success(`git commit -m "Initial"`)
                @test success(`git branch -M main`)
                @test success(`git checkout -b feature`)

                # Simulate GitHub Actions with matching repo
                withenv("GITHUB_EVENT_NAME" => "pull_request",
                        "GITHUB_REPOSITORY" => "Test/TestPackage.jl") do

                    # No explicit repo in DraftConfig, should auto-detect from makedocs
                    doc = makedocs(;
                        root = repo_path,
                        source = "docs/src",
                        build = "docs/build",
                        sitename = "TestPackage",
                        repo = "https://github.com/Test/TestPackage.jl",  # Auto-detected
                        pages = ["index.md", "guide.md"],
                        plugins = [
                            DraftConfig(devbranch = "main")  # No explicit repo
                        ],
                        doctest = false,
                    draft = true,
                    )

                    # Should work with auto-detected repo
                    @test doc isa Documenter.Document
                    # Both pages should have draft status checked
                    # (specific values depend on whether files were modified)
                end
            end
        end
    end

    @testset "Plugin disabled - no drafts" begin
        mktempdir() do tmpdir
            repo_path = joinpath(tmpdir, "TestPackage")
            docs_path = joinpath(repo_path, "docs")
            src_path = joinpath(docs_path, "src")
            mkpath(src_path)

            cd(repo_path) do
                @test success(`git init`)
                @test success(`git config user.email "test@example.com"`)
                @test success(`git config user.name "Test User"`)

                write(joinpath(src_path, "index.md"), "# Home")
                write(joinpath(src_path, "guide.md"), "# Guide")

                @test success(`git add -A`)
                @test success(`git commit -m "Initial"`)
                @test success(`git branch -M main`)
                @test success(`git checkout -b feature`)

                # Plugin explicitly disabled
                doc = makedocs(;
                    root = repo_path,
                    source = "docs/src",
                    build = "docs/build",
                    sitename = "TestPackage",
                    pages = ["index.md", "guide.md"],
                    plugins = [
                        DraftConfig(
                            enabled = false,  # Disabled
                            devbranch = "main",
                        )
                    ],
                    doctest = false,
                    draft = true,
                )

                # Plugin disabled, no pages should be draft
                @test get(doc.blueprint.pages["index.md"].globals.meta, :Draft, false) == false
                @test get(doc.blueprint.pages["guide.md"].globals.meta, :Draft, false) == false
            end
        end
    end
end
