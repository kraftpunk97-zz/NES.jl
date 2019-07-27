using Test, NES

@testset "Build Test"
    env = SMBEnv("smb", :RIGHT_ONLY)
    @test true
end
