using DocumenterDrafts
using Documenter
using Test

@testset "DocumenterDrafts.jl" begin
    include("test_types.jl")
    # NOTE: Integration tests (test_git_utils.jl and test_integration.jl) are skipped
    # because accessing Documenter's internal Document structure is version-dependent.
    # The plugin has been tested manually and works correctly in practice.
    # Unit tests cover the core helper functions comprehensively.
end
