import Compat: @info, @error, mv, GC
using Compat.Libdl
import Compat.LibGit2: clone

lib_nes_env_detected = false

if haskey(ENV, "LIB_NES_ENV")
        @info "LIB_NES_ENV environment detected : $(ENV["LIB_NES_ENV"])"
        @info "Trying to load existing lib_nes_env..."
        lib = Libdl.findlibrary(["lib_nes_env.so", "lib_nes_env.dll"],
                        [ENV["LIB_NES_ENV"]])
        if isempty(lib) == false
                @info "Existing  lib_nes_env detected at $lib, skip building..."
                lib_nes_env_detected = true
        else
                @info "Failed to load library, trying  to build library from source..."
        end
end

using BinDeps
@BinDeps.setup
if lib_nes_env_detected == false
    lib_nes_env = library_dependency("lib_nes_env",
        aliases=["lib_nes_env.so", "lib_nes_env.dll"])

    prefix = joinpath(BinDeps.depsdir(lib_nes_env), "usr")
    srcdir = joinpath(BinDeps.depsdir(lib_nes_env), "src")
    nesdir = joinpath(srcdir, "nes")
    libdir = joinpath(prefix, "lib")
    rm(joinpath(srcdir, "nes-py"), recursive=true, force=true)
    rm(joinpath(srcdir, "nes"), recursive=true, force=true)
    provides(BuildProcess,
        (@build_steps begin
            CreateDirectory(srcdir)
            CreateDirectory(libdir)
            @build_steps begin
                ChangeDirectory(srcdir)
                `git clone https://github.com/Kautenja/nes-py.git`
                `mv -f nes-py/nes_py/nes .`
                `rm -rf nes-py`
                FileRule(joinpath(libdir, "lib_nes_env.so"),
                @build_steps begin
                        ChangeDirectory(nesdir)
                        `scons`
                        `cp lib_nes_env.so $libdir`
                end)
            end
        end), lib_nes_env)
    @BinDeps.install Dict(:lib_nes_env => :lib_nes_env)
end
