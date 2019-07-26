# /Users/kartikeygupta/Workspace/Julia/Gym/NES/deps/roms/smb.nes
import Base: parse
MAGIC = (0x4e, 0x45, 0x53, 0x1a)

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
    !all(MAGIC .== header[1:4]) && error("ROM missing magic number in the header.")
    sum(header[12:end]) != 0 && error("ROM Header zero fill bytes are not zero.")

    ROM(raw_data, header)
end

parse(chr::Char) = Base.parse(UInt8, chr)
parse(str::AbstractString) = Base.parse(UInt8, str)

function Base.getproperty(rom::ROM, sym::Symbol)

    """Return the header of the ROM file as bytes."""
    if sym == :header
        return rom.raw_data[1:16]

    """Return the size of the PRG ROM in KB"""
    elseif sym == :prg_rom_size
        return 16 * rom.header[5]

    """Return the size of the CHR ROM in KB"""
    elseif sym == :chr_rom_size
        return 8 * rom.header[6]

    """Return the flags at the 6th byte of the header."""
    elseif sym == :flags_6
        return string(rom.header[7], base=2, pad=8)

    """Return the flags at the 7th byte of the header."""
    elseif sym == :flags_7
        return string(rom.header[8], base=2, pad=8)

    """Return the size of the PRG RAM in KB."""
    elseif sym == :prg_ram_size
        return 8 * (rom.header[9] == 0 ? 1 : rom.header[9])

    """Return the flags at the 9th byte of the header."""
    elseif sym == :flags_9
        return string(rom.header[10], base=2, pad=8)

    """
    Return the flags at the 10th byte of the header.

    Notes:
        - these flags are not part of official specification.
        - ignored in this emulator

    """
    elseif sym == :flags_10
        return string(rom.header[11], base=2, pad=8)


#-------------------------HEADER FLAGS-----------------------------------------#

    """Return the mapper number this ROM uses."""
    elseif sym == :mapper
        return parse(rom.flags_7[1:4] * rom.flags_6[1:4])

    """Return a boolean determining if the ROM ignores mirroring."""
    elseif sym == :is_ignore_mirroring
        return rom.flags_6[5] |> parse |> Bool

    """Return a boolean determining if the ROM has a trainer block."""
    elseif sym == :has_trainer
        return rom.flags_6[6] |> parse |> Bool

    """Return a boolean determining if the ROM has a battery-backed RAM."""
    elseif sym == :has_battery_backed_ram
        return rom.flags_6[7] |> parse |> Bool

    """Return the mirroring mode this ROM uses."""
    elseif sym == :is_vertical_mirroring
        return rom.flags_6[8] |> parse |> Bool

    """
    Return whether this cartridge uses PlayChoice-10.

    Note:
        - Play-Choice 10 uses different color palettes for a different PPU
        - ignored in this emulator

    """
    elseif sym == :has_play_choice_10
        return rom.flags_7[7] |> parse |> Bool

    """
    Return whether this cartridge has VS Uni-system.

    Note:
        VS Uni-system is for ROMs that have a coin slot (Arcades).
        - ignored in this emulator

    """
    elseif sym == :has_vs_unisystem
        return rom.flags_7[8] |> parse |> Bool

    """Returns the TV System this ROM supports"""
    elseif sym == :is_pal
        return rom.flags_9[8] |> parse |> Bool


#----------------------------------ROM------------------------------------------

    """The inclusive starting index of the trainer ROM."""
    elseif sym == :trainer_rom_start
        return 17

    """The inclusive stopping index of the trainer ROM."""
    elseif sym == :trainer_rom_stop
        return rom.has_trainer ? rom.trainer_rom_start + 512 : rom.trainer_rom_start - 1

    """Return the trainer ROM of the ROM file"""
    elseif sym == :trainer_rom
        return rom.raw_data[rom.trainer_rom_start:rom.trainer_rom_stop]

    """The inclusive starting index of the PRG ROM."""
    elseif sym == :prg_rom_start
        return rom.trainer_rom_stop + 1

    """The inclusive stopping index of the PRG ROM."""
    elseif sym == :prg_rom_stop
        return rom.prg_rom_start + rom.prg_rom_size * 2^10 - 1

    """Return the PRG ROM of the ROM file."""
    elseif sym == :prg_rom
        try
            return rom.raw_data[rom.prg_rom_start : rom.prg_rom_stop]
        catch BoundsError
            error("Failed to read PRG-ROM on ROM")
        end

    """The inclusive starting index of the CHR ROM."""
    elseif sym == :chr_rom_start
        return rom.prg_rom_stop + 1

    """The inclusive stopping index of the CHR ROM."""
    elseif sym == :chr_rom_stop
        return rom.chr_rom_start + rom.chr_rom_size * 2^10 - 1

    """Return the CHR ROM of the ROM file."""
    elseif sym == :chr_rom
        try
            return rom.raw_data[rom.chr_rom_start:rom.chr_rom_stop]
        catch BoundsError
            error("Failed to read CHR-ROM on ROM")
        end
    else
        return getfield(rom, sym)
    end
end
