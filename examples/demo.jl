using NES

env = SMBEnv("smb", :RIGHT_ONLY)
current_state = reset!(env)
done = false
actions = [env.action_map |> keys |> rand for _=1:400]

for action ∈ actions
    global current_state, done
    current_state, reward, done, info = step!(env, action)
    sleep(0.001)
    render(env) |> display
    done && break
end
