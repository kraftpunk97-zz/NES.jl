action_types_dict = Dict(
:RIGHT_ONLY => [
    (:NOOP,),
    (:right,),
    (:right, :A),
    (:right, :B),
    (:right, :A, :B)
],

:SIMPLE_MOVEMENT => [
    (:NOOP,),
    (:right,),
    (:right, :A),
    (:right, :B),
    (:right, :A, :B),
    (:A,),
    (:left,)
],

:COMPLEX_MOVEMENT => [
    (:NOOP,),
    (:right,),
    (:right, :A),
    (:right, :B),
    (:right, :A, :B),
    (:A,),
    (:left, :A),
    (:left, :B),
    (:left, :A, :B),
    (:down,),
    (:up,)
])
button_map = Dict{Symbol, UInt8}(
    :right  => 0b10000000,
    :left   => 0b01000000,
    :down   => 0b00100000,
    :up     => 0b00010000,
    :start  => 0b00001000,
    :select => 0b00000100,
    :B      => 0b00000010,
    :A      => 0b00000001,
    :NOOP   => 0b00000000,
)
