# NES.jl [WIP]

![](https://media.giphy.com/media/gjCGZwYAAYoDdMOfdM/giphy.gif)

This is a simple NES emulator for the Julia programming language, based on the [nes-py](https://github.com/Kautenja/nes-py) emulator. The emulator has been augmented to serve as a training environment for reinforcement learning experimentation and projects.

## Installation

Open Julia REPL and enter the following commands

```julia
julia> using Pkg

julia> Pkg.add("https://github.com/kraftpunk97/NES.jl")
```

## Demo

NES.jl can currently render only in the plot pane of [Juno IDE](https://junolab.org). Other methods will be added later.

```julia
using NES

enviroment_type = "smb"
action_type = :RIGHT_ONLY
env = SMBEnv(environment_type, action_type)
current_state = reset!(env)
done = false
actions = [env.action_map |> keys |> rand for _=1:400]

for action ∈ actions
	global done, current_state
	current_state, reward, done, info = step!(env, action)
	render(env) |> display
	sleep(0.001)
	done && break
end
```

## Environments
| Environment                     | Screenshot |
|:--------------------------------|:-----------|
| `smb`             |  ![](https://i.imgur.com/ubwQbux.png)    |
| `smbdownsample`             |  ![](https://i.imgur.com/AC5xWrF.png)    |
| `smbpixel`             |  ![](https://i.imgur.com/Wj2ZLEF.png)    |
| `smbrectangle`             |  ![](https://i.imgur.com/kBQY8Rz.png)    |
| `smb2`            |  ![](https://i.imgur.com/vQPDUN2.png)  |
| `smb2downsample`            |  ![](https://i.imgur.com/7YlNDKH.png)  

## Action Spaces

* `:RIGHT_ONLY` (5 distinct actions)
	* NOOP
	* Right
	* Right, A
	* Right, B
	* Right, A, B
* `:SIMPLE_MOVEMENT` (7 distinct actions)
	* NOOP
	* Right
	* Right, A
	* Right, B
	* Right, A, B
	* A
	* Left
* `:COMPLEX_MOVEMENT` (12 distinct actions)
	* NOOP
	* Right
	* Right, A
	* Right, B
	* Right, A, B
	* A
	* Left
	* Left, A
	* Left, B
	* Left, A, B
	* Down
	* Up

## RoadMap

* [x] NES Emulator
* [x] Super Mario Bros and Super Mario Bros 2 environments
* [ ] Tetris environment
* [ ] Integrate with [Gym.jl](https://github.com/FluxML/Gym.jl)

