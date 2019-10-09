if isfile(joinpath(dirname(dirname(@__FILE__)), "..", "deps", "deps.jl"))
    include("../../deps/deps.jl")
else
    ext = Sys.iswindows() ? ".dll" : ".so"
    println(joinpath(dirname(dirname(@__FILE__)), "deps", "deps.jl"))
    error("lib_nes_env" * ext *  " not properly installed. Please run Pkg.build(\"NES\")")
end

include("ROMInterface.jl")

NESEnvPtr = Ptr{Cvoid}
ControllerVectorPtr = Ptr{UInt8}
ScreenTensorPtr = Ptr{UInt8}
RAMVectorPtr = Ptr{UInt8}


#--------------------------- lib_nes_env Interface -----------------------------

# Returns screen width and height.
Width()::Int  = ccall((:Width, lib_nes_env), Cuint, ())
Height()::Int = ccall((:Height, lib_nes_env), Cuint, ())

# Returns the address of the controller for `nesenvptr` at port number `port`.
Controller(nesenvptr::NESEnvPtr, port::Integer) = ccall((:Controller, lib_nes_env),
                                                ControllerVectorPtr, (NESEnvPtr, Cuint), nesenvptr, Cuint(port))

# Returns the pointer to the 1D array that contains the RGB screen picture.
Screen(nesenvptr::NESEnvPtr) = ccall((:Screen, lib_nes_env), ScreenTensorPtr, (NESEnvPtr,), nesenvptr)

# Returns the address of the RAM
Memory(nesenvptr::NESEnvPtr) = ccall((:Memory, lib_nes_env), RAMVectorPtr, (NESEnvPtr,), nesenvptr)

# Resets the game
Reset(nesenvptr::NESEnvPtr) = ccall((:Reset, lib_nes_env), Cvoid, (NESEnvPtr,), nesenvptr)

# Performs a step on the emulator
Step(nesenvptr::NESEnvPtr) = ccall((:Step, lib_nes_env), Cvoid, (NESEnvPtr,), nesenvptr)

# Backup of the emulator state
Backup(nesenvptr::NESEnvPtr) = ccall((:Backup, lib_nes_env), Cvoid, (NESEnvPtr,), nesenvptr)

# Restore the backed up state into the NES emulator
Restore(nesenvptr::NESEnvPtr) = ccall((:Restore, lib_nes_env), Cvoid, (NESEnvPtr,), nesenvptr)

# Close the environment
Close(nesenvptr::NESEnvPtr) = ccall((:Close, lib_nes_env), Cvoid, (NESEnvPtr,), nesenvptr)


#---------------------------------Utilites--------------------------------------

const h = Height()
const w = Width()
const SCREEN_SHAPE_32_BIT = (h, w, 4)
const SCREEN_SHAPE_24_BIT = (h, w, 3)

"""
    Initialize(rom_path::String)

Creates a new NES emulator instance and loads the game at `rom_path`
"""
function Initialize(rom_path::AbstractString)
    edited_rom = push!(Cwchar_t[char for char in rom_path], Cwchar_t(0))
    ccall((:Initialize, lib_nes_env), NESEnvPtr, (Ptr{Cwchar_t},), edited_rom)
end

"""
    screen_buffer(nesenvptr::NESEnvPtr)

Setup the screen buffer from the C++ code
"""
function screen_buffer(nesenvptr::NESEnvPtr)
    address = Screen(nesenvptr)
    buffer = unsafe_wrap(Array, address, prod(SCREEN_SHAPE_32_BIT))
    # create a screen tensor by reshaping the contents of the buffer and flipping
    # the final set of bytes for little endian machines, which it likely is

    # Just in case, if the machine is big endian, reverse what we did...
    #Base.ENDIAN_BOM == 0x01020304 && (screen_tensor = screen_tensor[:, :, end:-1:1])

    return buffer
end

"""
    ram_vector(nesenvptr::NESEnvPtr)

Setup the RAM buffer from the C++ code
"""
function ram_buffer(nesenvptr::NESEnvPtr)
    # get the address of the RAM
    address = Memory(nesenvptr)
    # create a buffer from the contents of the address location
    buffer = unsafe_wrap(Array, address, 0x800)
    return buffer
end

"""
    controller_buffer(nesenvptr::NESEnvPtr, port)

Find the pointer to a controller and setup a buffer. Accepts `port` which is the
port of the controller and returns the buffer with the controller's binary data.
"""
function controller_buffer(nesenvptr::NESEnvPtr, port)
    # Get address of the controller
    address = Controller(nesenvptr, port)
    # Create a memory buffer using the address pointer.
    buffer = unsafe_wrap(Array, address, 1)
    return buffer
end

#-----------------------NESEnv functions----------------------------------------

mutable struct NESEnv
    envptr::Union{NESEnvPtr, Nothing}
    rom_path::String
    has_backup::Union{Nothing, Bool}
    done::Bool
    controllers::Array{Array{UInt8, N}, 1} where N
    screen_buf::Array{UInt8, 1}
    ram::Array{UInt8, 1}
end

function NESEnv(rom_path::AbstractString)
    if isfile(rom_path)
        rom_path = rom_path
    elseif isfile(joinpath(@__DIR__, "..", "..", "deps", "roms", rom_path * ".nes"))
        rom_path = joinpath(@__DIR__, "..", "..", "deps", "roms", rom_path * ".nes")
    else
        error("File at path $rom_path not found.")
    end

    rom = ROM(rom_path)
    # Ensure that PRG-ROM is present and no trainers are present
    rom.prg_rom_size == 0 &&
        error("ROM has no PRG-ROM banks. No can do.")
    rom.has_trainer &&
        error("ROM has trainer. Trainer isn't supported.")

    # Try to read the PRG ROM and raises an error if it fails
    _ = rom.prg_rom
    # Try to read the CHR ROM and raise an error if it fails
    _ = rom.chr_rom

    # check the TV system and/or if mapper is implemented
    if rom.is_pal
        error("ROM is PAL. PAL is not supported")
    elseif rom.mapper ∉ (0, 1, 2, 3)
        error("ROM has unsupported mapper number $(mapper(rom))")
    end

    # Initialize the C++ object for running the environment
    envptr = Initialize(rom_path)
    Reset(envptr)
    has_backup = false
    done = true
    controllers = [controller_buffer(envptr, port) for port in 0:1]
    screen_buf = screen_buffer(envptr)
    ram = ram_buffer(envptr)

    NESEnv(envptr, rom_path, has_backup, done, controllers, screen_buf, ram)
end

function get_obs(nesenv::NESEnv)
    r_array = reshape(nesenv.screen_buf[1:4:end], w, h)
    g_array = reshape(nesenv.screen_buf[2:4:end], w, h)
    b_array = reshape(nesenv.screen_buf[3:4:end], w, h)

    rgb_array = cat(r_array, g_array, b_array; dims=3)
end

function Base.getproperty(obj::NESEnv, sym::Symbol)
    if sym == :screen
        return get_obs(obj)
    else
        return Base.getfield(obj, sym)
    end
end

"""
    frame_advance!(nesenv::NESEnv, action)

Advance a fram in the emulator with an action.
"""
function frame_advance!(nesenv::NESEnv, action)
    nesenv.controllers[1][:] .= action
    Step(nesenv.envptr)
end

"""
    backup(nesenv::NESEnv)

Backup the NES state in the emulator
"""
function backup!(nesenv::NESEnv)
    Backup(nesenv.envptr)
    nesenv.has_backup = true
end


"""
    restore(nesenv::NESEnv)

Restore the backup state into the NES emulator.
"""
restore!(nesenv::NESEnv) = Restore(nesenv.envptr)

"""
    reset(nesenv::NESEnv)

Reset the state of the environment and returns an initial observation
"""
function reset!(nesenv::NESEnv)
    nesenv.has_backup ? restore(nesenv) : Reset(nesenv.envptr)
    nesenv.done = false
end

"""
    step!(nesenv::NESEnv, action)

Run one frame of the NES and return the relevant observation data.
"""
function step!(nesenv::NESEnv, action)
    # Raise an error if the environment is done.
    nesenv.done &&
        error("Cannot step in a done environment! Call `reset!`")

    # Set the action on the controller.
    self.controllers[1][:] = action
    # pass the action to the emulator as an unsigned byte
    Step(nesenv.envptr)

    reward = get_reward(nesenv)
    nesenv.done = get_done(nesenv)
    info = get_info(nesenv)
    did_step(nesenv)

    reward = clamp(reward, nesenv.reward_range[1], nesenv.reward_range[2])

    return nesenv.screen, reward, nesenv.done, info
end

"""
    close(nesenv::NESEnv)

Close the environment.
"""
function close(nesenv::NESEnv)
    isnothing(nesenv.envptr) && error("env has already been closed.")
    Close(nesenv.envptr)
    nesenv.envptr = nothing
end

"""
    get_keys_to_action(nesenv::NESEnv)

Return the dictionary of keyboard keys to actions.
"""
function get_keys_to_action(nesenv::NESEnv)
    buttons = Int[
        'd', # right
        'a', # left
        's', # down
        'w', # up
       '\r', # start
        ' ', # stop
        'p', # B
        'o'  # A
    ]
    keys_to_action = Dict()


    for i=0:255
        byte = string(i, base=2, pad=8)
        pressed = sort(buttons[Bool[parse(Int, num) for num in byte]])
        keys_to_action[pressed] = byte
    end
    return keys_to_action
end

#println(NESEnv("/Users/kartikeygupta/Workspace/Julia/Gym/NES/deps/roms/smb.nes"))
