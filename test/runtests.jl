using Test, NES

@testset "Build Test" begin
    env = SMBEnv("smb", :RIGHT_ONLY)
    @test true
end
