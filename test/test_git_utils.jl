@testset "Git utilities" begin
    using DocumenterDrafts: is_pull_request, get_modified_docs

    # Helper to create minimal mock document with specified root
    function create_test_doc(root_path::String)
        user = Documenter.User(
            root_path, "src", "build", :build,
            [Documenter.HTML()], true, false, false, [],
            :all, Regex[], false, [], [],
            "", "Test", "Test", "v1.0", true
        )
        internal = Documenter.Internal(
            tempdir(),
            "",
            [],
            [],
            Documenter.Anchors.AnchorMap(),
            Documenter.Anchors.AnchorMap(),
            IdDict{Any,Any}(),
            IdDict{Any,Any}(),
            [],
            [],
            Dict{Markdown.Link, String}(),
            Set{Symbol}()
        )
        blueprint = Documenter.DocumentBlueprint(Dict{String, Documenter.Page}(), Set{Module}())
        Documenter.Document(user, internal, Dict{DataType, Documenter.Plugin}(), blueprint)
    end

    @testset "is_pull_request - CI detection" begin
        mktempdir() do tmpdir
            cd(tmpdir) do
                # Initialize git repo for testing
                run(`git init`)
                run(`git config user.email "test@test.com"`)
                run(`git config user.name "Test"`)
                run(`git branch -M main`)

                doc = create_test_doc(tmpdir)

                # Test Travis CI detection
                withenv("TRAVIS_PULL_REQUEST" => "123",
                        "GITHUB_EVENT_NAME" => nothing,
                        "CI_MERGE_REQUEST_ID" => nothing) do
                    @test is_pull_request(doc, "main", true) == true
                end

                # Test GitHub Actions detection
                withenv("TRAVIS_PULL_REQUEST" => nothing,
                        "GITHUB_EVENT_NAME" => "pull_request",
                        "CI_MERGE_REQUEST_ID" => nothing) do
                    @test is_pull_request(doc, "main", true) == true
                end

                # Test GitLab CI detection
                withenv("TRAVIS_PULL_REQUEST" => nothing,
                        "GITHUB_EVENT_NAME" => nothing,
                        "CI_MERGE_REQUEST_ID" => "42") do
                    @test is_pull_request(doc, "main", true) == true
                end

                # Test no CI vars set, on devbranch → not a PR
                withenv("TRAVIS_PULL_REQUEST" => nothing,
                        "GITHUB_EVENT_NAME" => nothing,
                        "CI_MERGE_REQUEST_ID" => nothing) do
                    @test is_pull_request(doc, "main", true) == false
                end
            end
        end
    end

    @testset "is_pull_request - git branch detection" begin
        mktempdir() do tmpdir
            cd(tmpdir) do
                # Initialize git repo
                run(`git init`)
                run(`git config user.email "test@test.com"`)
                run(`git config user.name "Test"`)
                write("file.txt", "content")
                run(`git add -A`)
                run(`git commit -m "Initial"`)
                run(`git branch -M main`)

                doc = create_test_doc(tmpdir)

                # On main branch → not a PR
                withenv("TRAVIS_PULL_REQUEST" => nothing,
                        "GITHUB_EVENT_NAME" => nothing,
                        "CI_MERGE_REQUEST_ID" => nothing) do
                    @test is_pull_request(doc, "main", false) == false
                end

                # Create and checkout feature branch → is a PR
                run(`git checkout -b feature-branch`)
                @test is_pull_request(doc, "main", false) == true

                # use_ci_env=false should use git branch only
                withenv("GITHUB_EVENT_NAME" => "push") do  # Even if CI says push
                    @test is_pull_request(doc, "main", false) == true
                end
            end
        end
    end

    @testset "get_modified_docs" begin
        mktempdir() do tmpdir
            docs_dir = joinpath(tmpdir, "docs")
            src_dir = joinpath(docs_dir, "src")
            mkpath(src_dir)

            cd(tmpdir) do
                # Initialize git repo
                run(`git init`)
                run(`git config user.email "test@test.com"`)
                run(`git config user.name "Test"`)

                # Create initial docs on main branch
                write(joinpath(src_dir, "index.md"), "# Home\n")
                write(joinpath(src_dir, "guide.md"), "# Guide\n")
                write(joinpath(src_dir, "api.md"), "# API\n")
                run(`git add -A`)
                run(`git commit -m "Initial docs"`)
                run(`git branch -M main`)

                # Create feature branch and modify some files
                run(`git checkout -b feature`)
                write(joinpath(src_dir, "guide.md"), "# Guide\n\nUpdated!")
                write(joinpath(src_dir, "tutorial.md"), "# Tutorial\n")  # New file
                run(`git add -A`)
                run(`git commit -m "Update docs"`)

                doc = create_test_doc(tmpdir)
                modified = get_modified_docs(doc, "main")

                # Should detect modified and new files
                @test "guide.md" in modified
                @test "tutorial.md" in modified
                @test "index.md" ∉ modified  # Not modified
                @test "api.md" ∉ modified    # Not modified
                @test length(modified) == 2
            end
        end
    end

    @testset "get_modified_docs - empty diff" begin
        mktempdir() do tmpdir
            docs_dir = joinpath(tmpdir, "docs")
            src_dir = joinpath(docs_dir, "src")
            mkpath(src_dir)

            cd(tmpdir) do
                run(`git init`)
                run(`git config user.email "test@test.com"`)
                run(`git config user.name "Test"`)

                write(joinpath(src_dir, "index.md"), "# Home\n")
                run(`git add -A`)
                run(`git commit -m "Initial"`)
                run(`git branch -M main`)

                # Create branch but don't modify anything in docs/
                run(`git checkout -b no-doc-changes`)
                write("README.md", "# Readme\n")  # Non-docs file
                run(`git add -A`)
                run(`git commit -m "Update README"`)

                doc = create_test_doc(tmpdir)
                modified = get_modified_docs(doc, "main")

                # Should be empty since no .md files in docs/ were modified
                @test isempty(modified)
            end
        end
    end
end
