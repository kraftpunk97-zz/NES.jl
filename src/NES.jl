module NES

if isfile(joinpath(dirname(dirname(@__FILE__)), "deps", "deps.jl"))
    include("../deps/deps.jl")
else
    ext = Sys.iswindows() ? ".dll" : ".so"
    error("lib_nes_env" * ext *  " not properly installed. Please run Pkg.build(\"ArcadeLearningEnvironment\")")
end

end # module
