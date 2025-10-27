@testset "Type utilities and helpers" begin
    @testset "extract_repo_slug" begin
        using DocumenterDrafts: extract_repo_slug

        # GitHub URL formats
        @test extract_repo_slug("github.com/owner/repo") == "owner/repo"
        @test extract_repo_slug("https://github.com/owner/repo") == "owner/repo"
        @test extract_repo_slug("http://github.com/owner/repo") == "owner/repo"
        @test extract_repo_slug("github.com/owner/repo.git") == "owner/repo"
        @test extract_repo_slug("https://github.com/owner/repo.git") == "owner/repo"
        @test extract_repo_slug("github.com/owner/repo/") == "owner/repo"

        # GitLab URL formats
        @test extract_repo_slug("gitlab.com/group/subgroup/project") == "group/subgroup/project"
        @test extract_repo_slug("https://gitlab.com/owner/repo.git") == "owner/repo"

        # Plain slug
        @test extract_repo_slug("owner/repo") == "owner/repo"
        @test extract_repo_slug("owner/repo.git") == "owner/repo"
        @test extract_repo_slug("owner/repo/") == "owner/repo"
    end

    @testset "get_effective_devbranch" begin
        using DocumenterDrafts: get_effective_devbranch

        # Test with deploy_config present
        config = DraftConfig(
            devbranch = "master",
            deploy_config = (devbranch = "main", repo = "test/test")
        )
        @test get_effective_devbranch(config) == "main"

        # Test without deploy_config (fallback)
        config = DraftConfig(devbranch = "develop")
        @test get_effective_devbranch(config) == "develop"

        # Test default value
        config = DraftConfig()
        @test get_effective_devbranch(config) == "master"
    end

    # NOTE: get_effective_repo is tested in integration tests with real Document objects
    # Unit testing with mock documents is too fragile due to Documenter's internal structure

    @testset "should_build_full" begin
        using DocumenterDrafts: should_build_full

        always_include = ["index.md", "api.md"]
        modified_files = Set(["guide.md", "tutorial.md"])

        # File in always_include → true
        @test should_build_full("index.md", modified_files, always_include) == true
        @test should_build_full("api.md", modified_files, always_include) == true

        # File in modified_files → true
        @test should_build_full("guide.md", modified_files, always_include) == true
        @test should_build_full("tutorial.md", modified_files, always_include) == true

        # File in both → true (always_include takes precedence logically)
        @test should_build_full("guide.md", modified_files, ["guide.md"]) == true

        # File in neither → false (should be draft)
        @test should_build_full("other.md", modified_files, always_include) == false
        @test should_build_full("random.md", Set{String}(), String[]) == false
    end
end
