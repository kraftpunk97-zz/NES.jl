# /Users/kartikeygupta/Workspace/Julia/Gym/NES/deps/roms/smb.nes
struct ROM
    raw_data::Array{UInt8, 1}
    header::Array{UInt8, 1}
end

function ROM(rom_path::AbstractString)
    io = open(rom_path, "r")
    buffer_size = 10
    buffer = zeros(UInt8, buffer_size)
    raw_data = UInt8[]
    while !eof(io)
        readbytes!(io, buffer)
        push!(raw_data, buffer...)
    end
    header = raw_data[1:16]
    !all(MAGIC .== header[1:4]) && (@error "ROM missing magic number in the header.")
    sum(header[12:end]) != 0 && (@error "ROM Header zero fill bytes are not zero.")

    ROM(raw_data, header)
end

"""Return the header of the ROM file as bytes."""
@inline header(rom::ROM) = rom.raw_data[1:16]

"""Return the size of the PRG ROM in KB"""
@inline prg_rom_size(rom::ROM) = 16 * header(rom)[5]

"""Return the size of the CHR ROM in KB"""
@inline chr_rom_size(rom::ROM) = 8 * header(rom)[6]

"""Return the flags at the 6th byte of the header."""
flags_6(rom::ROM) = string(header(rom)[7], base=2, pad=8)

"""Return the flags at the 7th byte of the header."""
flags_7(rom::ROM) = string(header(rom)[8], base=2, pad=8)

"""Return the size of the PRG RAM in KB."""
@inline prg_ram_size(rom::ROM) = 8 * (header(rom)[9] == 0 ? 1 : header(rom)[9])

"""Return the flags at the 9th byte of the header."""
flags_9(rom::ROM) = string(header(rom)[10], base=2, pad=8)

"""
Return the flags at the 10th byte of the header.

Notes:
    - these flags are not part of official specification.
    - ignored in this emulator

"""
flags_10(rom::ROM) = string(header(rom)[11], base=2, pad=8)


#-------------------------HEADER FLAGS-----------------------------------------#

Base.parse(chr::Char) = parse(UInt8, chr)

"""Return the mapper number this ROM uses."""
mapper(rom::ROM) = parse(flags_7(rom)[1:4] * flags_6(rom)[1:4])

"""Return a boolean determining if the ROM ignores mirroring."""
is_ignore_mirroring(rom::ROM) = flags_6(rom)[5] |> parse |> Bool

"""Return a boolean determining if the ROM has a trainer block."""
has_trainer(rom::ROM) = flags_6(rom)[6] |> parse |> Bool

"""Return a boolean determining if the ROM has a battery-backed RAM."""
has_battery_backed_ram(rom::ROM) = flags_6(rom)[7] |> parse |> Bool

"""Return the mirroring mode this ROM uses."""
is_vertical_mirroring(rom::ROM) = flags_6(rom)[8] |> parse |> Bool

"""
Return whether this cartridge uses PlayChoice-10.

Note:
    - Play-Choice 10 uses different color palettes for a different PPU
    - ignored in this emulator

"""
has_play_choice_10(rom::ROM) = flags_7(rom)[7] |> parse |> Bool

"""
Return whether this cartridge has VS Uni-system.

Note:
    VS Uni-system is for ROMs that have a coin slot (Arcades).
    - ignored in this emulator

"""
has_vs_unisystem(rom::ROM) = flags_7(rom)[8] |> parse |> Bool

"""Returns the TV System this ROM supports"""
is_pal(rom::ROM) = flags_9(rom)[8] |> parse |> Bool


#----------------------------------ROM------------------------------------------

"""The inclusive starting index of the trainer ROM."""
@inline trainer_rom_start(rom::ROM) = 17

"""The inclusive stopping index of the trainer ROM."""
@inline trainer_rom_stop(rom::ROM) = has_trainer(rom) ? trainer_rom_start(rom) + 512 : trainer_rom_start(rom) - 1

"""Return the trainer ROM of the ROM file"""
@inline trainer_rom(rom) = rom.raw_data[trainer_rom_start(rom):trainer_rom_stop(rom)]

"""The inclusive starting index of the PRG ROM."""
@inline prg_rom_start(rom::ROM) = trainer_rom_stop(rom) + 1

"""The inclusive stopping index of the PRG ROM."""
@inline prg_rom_stop(rom::ROM) = prg_rom_start(rom) + prg_rom_size(rom) * 2^10 - 1

"""Return the PRG ROM of the ROM file."""
prg_rom(rom::ROM) = begin
    try
        return rom.raw_data[prg_rom_start(rom):prg_rom_stop(rom)]
    catch BoundsError
        @error "Failed to read PRG-ROM on ROM"
    end
end

"""The inclusive starting index of the CHR ROM."""
@inline chr_rom_start(rom::ROM) = prg_rom_stop(rom) + 1

"""The inclusive stopping index of the CHR ROM."""
@inline chr_rom_stop(rom::ROM)  = chr_rom_start(rom) + chr_rom_size(rom) * 2^10 - 1

"""Return the CHR ROM of the ROM file."""
chr_rom(rom::ROM) = begin
    try
        return rom.raw_data[chr_rom_start(rom):chr_rom_stop(rom)]
    catch BoundsError
        @error "Failed to read CHR-ROM on ROM"
    end
end
