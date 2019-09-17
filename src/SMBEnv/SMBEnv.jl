using .NESInterface, Cairo

include("actions.jl")
include("decode_target.jl")

mutable struct SMBEnv

    target_world
    target_area
    target_stage

    time_last
    x_position_last
    nesenv::NESInterface.NESEnv

    action_map::Dict{Int, UInt8}
    action_meanings::Dict{Int, String}

    output_mode::Symbol
end

const SMB_reward_range = (-15, 15)

function SMBEnv(rom_path::AbstractString, action_type::Symbol, output_mode::Symbol=:color, lost_levels=false, target=nothing)
    @assert output_mode ∈ (:color, :tiles)

    target_world, target_stage, target_area = decode_target(target, lost_levels)

    actions = action_types_dict[action_type]
    time_last = 0
    x_position_last = 0

    nesenv = NESInterface.NESEnv(rom_path)

    action_map = Dict{Int, UInt8}()
    action_meanings = Dict{Int, String}()

    for (action, button_list) ∈ enumerate(actions)
        byte_action = 0
        for  button ∈ button_list
            byte_action |= button_map[button]
        end
        action_map[action] = byte_action
        action_meanings[action] = join(button_list, ' ')
    end

    SMBEnv(target_world, target_area, target_stage, time_last, x_position_last,
            nesenv, action_map, action_meanings, output_mode)
end


"""Read a range of bytes where each byte is a 10's place figure.
Note:
    this method is specific to Mario where three GUI values are stored
    in independent memory slots to save processing time
    - score has 6 10's places
    - coins has 2 10's places
    - time has 3 10's places
"""
function read_mem_range(smb::SMBEnv, address, length)
    accum = 0
    for i=address:address+length-1
        accum *= 10
        accum += smb.nesenv.ram[i]
    end
    return accum
end


function Base.getproperty(smb::SMBEnv, sym::Symbol)
    if sym == :is_single_stage_env
        return !isnothing(smb.target_world) && !isnothing(smb.target_area)

    elseif sym == :level
        return smb.nesenv.ram[0x7560] * 4 + smb.nesenv.ram[0x075d]

    elseif sym == :world
        return smb.nesenv.ram[0x0760] + 1

    elseif sym == :stage
        return smb.nesenv.ram[0x075d] + 1

    elseif sym == :area
        return smb.nesenv.ram[0x0761] + 1

    elseif sym == :score
        return read_mem_range(smb, 0x07dd, 6)

    elseif sym == :time
        return read_mem_range(smb, 0x07f9, 3)

    elseif sym == :coins
        return read_mem_range(smb, 0x07ee, 2)

    elseif sym == :life
        return smb.nesenv.ram[0x075b]

    elseif sym == :x_position
        # current page  = 0x6e
        # current x  = 0x87
        return Int(smb.nesenv.ram[0x6e] * 0x100 + smb.nesenv.ram[0x87])

    elseif sym == :left_x_position
        return Int(smb.nesenv.ram[0x87] - smb.nesenv.ram[0x071d]) % 256

    elseif sym == :y_position
        return smb.nesenv.ram[0x03b9]

    elseif sym == :y_viewport
        return smb.nesenv.ram[0x00b6]

    elseif sym == :player_status
        status = smb.nesenv.ram[0x0757]

        if status == 0
            return :small
        elseif status == 1
            return :tall
        elseif status == 2
            return :fireball
        end

    elseif sym == :player_state
        return smb.nesenv.ram[0x000f]

    elseif sym == :is_dying
        return smb.player_state == 0x0b || smb.y_viewport > 1

    elseif sym == :is_dead
        return smb.player_state == 0x06

    elseif sym == :is_game_over
        return smb.life == 0xff

    elseif sym == :is_busy
        return smb.player_state ∈ (0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x07)

    elseif sym == :is_world_over
        return smb.nesenv.ram[0x0771] == 2

    elseif sym == :is_stage_over
        for address ∈ (0x0017, 0x0018, 0x0019, 0x001a, 0x001b)
            if smb.nesenv.ram[address] ∈ (0x2d, 0x31)
                return smb.nesenv.ram[0x001e] == 3
            end
        end
        return false

    elseif sym == :flag_get
        return smb.is_world_over || smb.is_stage_over

    elseif sym == :death_penalty
        return smb.is_dying || smb.is_dead ? -25 : 0

    elseif sym == :x_reward
        _reward = smb.x_position - smb.x_position_last
        smb.x_position_last = smb.x_position

        return -5 ≤ _reward ≤ 5 ? _reward : 0

    elseif sym == :time_penalty
        _reward = smb.time - smb.time_last
        smb.time_last = smb.time
        # time can only decrease, a positive reward results from a reset an
        # should default to 0 reward
        return min(0, _reward)

    elseif sym == :addr_enemy_page
        return 0x6f

    elseif sym == :addr_enemy_x
        return 0x88

    elseif sym == :addr_enemy_y
        return 0xd0

    elseif sym == :addr_tiles
        return 0x501

    elseif sym == :framecount
        return nes.nesenv.ram[0x000a]
        
    else
        return Base.getfield(smb, sym)
    end
end

"""Force the prelevel timer to 0 to skip frams during a death"""
runout_prelevel_timer!(smb::SMBEnv) = (smb.nesenv.ram[0x07a1] = 0)


# ------------------------ Reset level and its utilites ------------------------
"""Write the stage data to RAM to overwrite loading the next stage."""
function write_stage!(smb::SMBEnv)
    smb.nesenv.ram[0x0760] = smb.target_world - 1
    smb.nesenv.ram[0x075d] = smb.target_stage - 1
    smb.nesenv.ram[0x0761] = smb.target_area - 1
end

"""Press and release start to skip the start screen"""
function skip_start_screen!(smb::SMBEnv)
    # Press and release the start button
    NESInterface.frame_advance!(smb.nesenv, 8)
    NESInterface.frame_advance!(smb.nesenv, 0)

    # Press start until the game starts
    while smb.time == 0
        # Press and release the start button
        NESInterface.frame_advance!(smb.nesenv, 8)
        # if we're in the single stage environment, write the stage data
        if smb.is_single_stage_env
            write_stage!(smb)
        end
        NESInterface.frame_advance!(smb.nesenv, 0)
        # run-out the prelevel times to skip the animation
        runout_prelevel_timer!(smb)
    end

    # set the last time to now
    smb.time_last = smb.time
    # after the start screen idle to skip some extra frames
    while smb.time >= smb.time_last
        smb.time_last = smb.time
        NESInterface.frame_advance!(smb.nesenv, 8)
        NESInterface.frame_advance!(smb.nesenv, 0)
    end
end

function reset!(smb::SMBEnv)
    smb.time_last = 0
    smb.x_position_last = 0
    NESInterface.reset!(smb.nesenv)
    skip_start_screen!(smb)
    smb.time_last = smb.time
    smb.x_position_last = smb.x_position
    smb.output_mode == :color ? smb.nesenv.screen : get_tiles(smb)
end


# --------------------- Step Function and its utils ----------------------------

get_reward(smb::SMBEnv) = smb.x_reward + smb.time_penalty + smb.death_penalty
get_done(smb::SMBEnv) = smb.is_single_stage_env ? smb.is_dying || smb.is_dead || smb.flag_get :
                            smb.is_game_over
function get_info(smb::SMBEnv)
    return Dict(
        :coins    => smb.coins,
        :flag_get => smb.flag_get,
        :life     => Int(smb.life),
        :score    => smb.score,
        :stage    => smb.stage,
        :status   => smb.player_status,
        :time     => smb.time,
        :world    => smb.world,
        :x_pos    => Int(smb.x_position)
    )
end

"""If Mario dies, then skip the death animation..."""
function kill_mario!(smb::SMBEnv)
    smb.nesenv.ram[0x00f] = 0x06
    NESInterface.frame_advance!(smb.nesenv, 0)
end

"""Skip the cutscene that plays at the end of a world"""
function skip_end_of_world!(smb::SMBEnv)
    if smb.is_world_over
        # Get the current game time to reference.
        time = smb.time
        # Loop until the time is different
        while smb.time == time
            NESInterface.frame_advance!(smb.nesenv, 0)
        end
    end
end

"""Skip change area animations by running down timers"""
function skip_area_change!(smb::SMBEnv)
    change_area_timer = smb.nesenv.ram[0x006df]
    1 < change_area_timer < 255 && (smb.nesenv.ram[0x06df] = 1)
end

"""Skip occupied states by running out a timer and skipping frames."""
function skip_occupied_states!(smb::SMBEnv)
    while smb.is_busy || smb.is_world_over
        runout_prelevel_timer!(smb)
        NESInterface.frame_advance!(smb.nesenv, 0)
    end
end

function step!(smb::SMBEnv, action)
    smb.nesenv.done && error("Cannot step in a completed environment! Call `reset!`")
    if action ∉ keys(smb.action_map)
        error("Invalid action entered.")
    end

    # Perform step
    NESInterface.frame_advance!(smb.nesenv, smb.action_map[action])

    # Calculate reward, done and step info
    reward = get_reward(smb)
    smb.nesenv.done = get_done(smb)
    info = get_info(smb)

    # Post step hacking
    if !smb.nesenv.done
        smb.is_dying && kill_mario!(smb)
        smb.is_single_stage_env || skip_end_of_world!(smb)

        # skip area change (i.e. enter pipe, flag get, etc.)
        skip_area_change!(smb)
        # skip occupied states like the black screen between lives that shows how
        # many lives the player has left
        skip_occupied_states!(smb)
    end

    reward = clamp(reward, SMB_reward_range[1], SMB_reward_range[2])
    return smb.output_mode == :color ? smb.nesenv.screen : get_tiles(smb),
            reward, smb.nesenv.done, info
end

function render(smb::SMBEnv)
    screen = smb.nesenv.screen
    uint32_arr = screen[:, :, 1] .+ screen[:, :, 2] * 0x00000100 .+ screen[:, :, 3] * 0x00010000
    uint32_arr = uint32_arr |> transpose |> Array
    CairoRGBSurface(uint32_arr)
end

function get_enemies(smb::SMBEnv)
    enemies = []
    for slot=0:4
        enemy = smb.nesenv.ram[0x10 + slot]
        if enemy != 0
            ex = smb.nesenv.ram[env.addr_enemy_page + slot] * 0x100 + smb.nesenv.ram[env.addr_enemy_x + slot]
            ey = smb.nesenv.ram[env.addr_enemy_y + slot]
            push!(enemies, ex=>ey)
        end
    end
    return enemies
end

function get_tiles(smb::SMBEnv)
    enemies = get_enemies(smb)
    left_x = smb.left_x_position
    y_viewport = smb.y_viewport
    curr_x_pos = smb.x_position
    curr_y_pos = smb.y_position
    tiles = zeros(Int, 13, 16)

    for tiles_y=1:13, tiles_x=1:16
        box_x = 16 * (tiles_x - 8)
        box_y = 16 * (tiles_y - 5)

        # Empty space
        tile_value = 0

        # Non-empty space (e.g. hard surface, object)
        curr_tile_type = get_tile_type(smb, box_x, box_y)
        curr_tile_type == 1 && curr_y_pos + box_y < 0x180 && (tile_value = 1)

        # Enemies
        for enemy ∈ enemies
            local dist_x, dist_y
            dist_x = abs(enemy.first - (curr_x_pos + box_x - left_x + 108));
            dist_y = abs(enemy.second - (90 + box_y))
            if dist_x ≤ 9 && dist_y ≤ 9
                tile_value = 2
            end
        end

        # Mario
        dist_x::Int = abs(curr_x_pos - (curr_x_pos + box_x - left_x + 108))
        dist_y::Int = abs(curr_y_pos - (80 + box_y))

        ## For debugging  purposes
        #=
        if tiles_y == 11 && tiles_x == 9
            println("x = $tiles_x | curr_x = $curr_x_pos | box_x = $box_x | left_x = $left_x | dist_x = $dist_x")
            println("y = $tiles_y | curr_y = $curr_y_pos | box_y = $box_y | dist_y = $dist_y")
            #return curr_x_pos, box_x, left_x, curr_y_pos, box_y
        end
        =#

        if y_viewport == 1 && dist_x ≤ 9 && dist_y ≤ 9
            #println("x = $tiles_x | curr_x = $curr_x_pos | box_x = $box_x | left_x = $left_x")
            #println("y = $tiles_y | curr_y = $curr_y_pos | box_y = $box_y")
            tile_value = 3
        end


        tiles[tiles_y, tiles_x] = tile_value
    end
    return tiles
end


function get_tile_type(smb::SMBEnv, box_x, box_y)
    left_x = smb.left_x_position
    x = smb.x_position - left_x + box_x + 112
    y = box_y + 96
    page = floor(Int, x / 256) % 2
    sub_x = floor(Int, (x % 256) / 16)
    sub_y = floor(Int, (y - 32) / 16)

    curr_tile_add::UInt16 = smb.addr_tiles + page * 13 * 16 + sub_y * 16 + sub_x

    if sub_y ≥ 13 || sub_y < 0
        return 0
    end

    # 0 = empty space, 1 = non-empty space (e.g. hard surface or object)
    return Int(smb.nesenv.ram[curr_tile_add] != 0)
end
