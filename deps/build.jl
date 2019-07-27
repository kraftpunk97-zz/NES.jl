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
    builddir = joinpath(nesdir, "build")
    mapperdir = joinpath(builddir, "mappers")
    rm(joinpath(srcdir, "nes-py"), recursive=true, force=true)
    rm(joinpath(srcdir, "nes"), recursive=true, force=true)
    provides(BuildProcess,
        (@build_steps begin
            CreateDirectory(srcdir)
            CreateDirectory(libdir)
            @build_steps begin
                ChangeDirectory(srcdir)
                `git clone https://github.com/Kautenja/nes-py.git`
                `pwd`
                `mv -f nes-py/nes_py/nes .`
                `rm -rf nes-py`
                FileRule(joinpath(libdir, "lib_nes_env.so"),
                @build_steps begin
                        ChangeDirectory(nesdir)
                        `mkdir build`
                        `mkdir build/mappers`
                        `g++ -o build/cartridge.os -c -std=c++1y -O2 -march=native -pipe -fPIC -Wno-unused-value -Iinclude src/cartridge.cpp`
                        `g++ -o build/controller.os -c -std=c++1y -O2 -march=native -pipe -fPIC -Wno-unused-value -Iinclude src/controller.cpp`
                        `g++ -o build/cpu.os -c -std=c++1y -O2 -march=native -pipe -fPIC -Wno-unused-value -Iinclude src/cpu.cpp`
                        `g++ -o build/emulator.os -c -std=c++1y -O2 -march=native -pipe -fPIC -Wno-unused-value -Iinclude src/emulator.cpp`
                        `g++ -o build/lib_nes_env.os -c -std=c++1y -O2 -march=native -pipe -fPIC -Wno-unused-value -Iinclude src/lib_nes_env.cpp`
                        `g++ -o build/main_bus.os -c -std=c++1y -O2 -march=native -pipe -fPIC -Wno-unused-value -Iinclude src/main_bus.cpp`
                        `g++ -o build/mappers/mapper_CNROM.os -c -std=c++1y -O2 -march=native -pipe -fPIC -Wno-unused-value -Iinclude src/mappers/mapper_CNROM.cpp`
                        `g++ -o build/mappers/mapper_NROM.os -c -std=c++1y -O2 -march=native -pipe -fPIC -Wno-unused-value -Iinclude src/mappers/mapper_NROM.cpp`
                        `g++ -o build/mappers/mapper_SxROM.os -c -std=c++1y -O2 -march=native -pipe -fPIC -Wno-unused-value -Iinclude src/mappers/mapper_SxROM.cpp`
                        `g++ -o build/mappers/mapper_UxROM.os -c -std=c++1y -O2 -march=native -pipe -fPIC -Wno-unused-value -Iinclude src/mappers/mapper_UxROM.cpp`
                        `g++ -o build/picture_bus.os -c -std=c++1y -O2 -march=native -pipe -fPIC -Wno-unused-value -Iinclude src/picture_bus.cpp`
                        `g++ -o build/ppu.os -c -std=c++1y -O2 -march=native -pipe -fPIC -Wno-unused-value -Iinclude src/ppu.cpp`
                        `g++ -o lib_nes_env.so -std=c++1y -O2 -march=native -pipe -dynamiclib build/cartridge.os build/controller.os build/cpu.os build/emulator.os build/lib_nes_env.os build/main_bus.os build/picture_bus.os build/ppu.os build/mappers/mapper_CNROM.os build/mappers/mapper_NROM.os build/mappers/mapper_SxROM.os build/mappers/mapper_UxROM.os`
                        `cp lib_nes_env.so $libdir`
                end)
            end
        end), lib_nes_env)
    @BinDeps.install Dict(:lib_nes_env => :lib_nes_env)
end
