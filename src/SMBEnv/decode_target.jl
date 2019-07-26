decode_target(target::Nothing, lost_levels::Bool) = nothing, nothing, nothing
decode_target(target::AbstractArray{Int, 1}, lost_levels::Bool) = decode_target(target..., lost_levels)
function decode_target(target_world::Int, target_stage::Int, lost_levels::Bool)
    if lost_levels
        !(1 ≤ target_world ≤ 12) && error("target_world must be in {1, ..., 12}")
    elseif !(1 ≤ target_world ≤ 12)
        error("target_world must be in {1, ..., 8}")
    end

    !(1 ≤ target_stage ≤ 4) && error("target_stage must be in {1, ..., 4}")

    target_area = target_stage

    if lost_levels
        if target_world ∈ (1, 3)
            if target_stage ≥ 2
                target_area = target_area + 1
            end
        elseif target_world ≥ 5
            worlds = (5, 6, 7, 8, 9, 10, 11, 12)
            error("Lost levels [$worlds] not supported")
        end
    else
        target_world ∈ (1, 2, 4, 7) && target_stage ≥ 2 && (target_area += 1)
    end

    target_world, target_stage, target_area
end
