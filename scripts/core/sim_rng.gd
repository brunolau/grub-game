class_name SimRng
extends RefCounted
## Deterministic integer random number generator for the simulation (PHYSICS.md 15.1 #7).
##
## The ONLY source of randomness allowed inside a tick is `Sim.rng`. Never call randf / randi / RandomNumberGenerator
## from gameplay code: replays, golden-trace tests and the autoplay harness depend on identical sequences.
## Algorithm: xorshift32 (state never zero), results are plain non-negative ints.

var _state: int = 0x1234ABCD


func _init(seed_value: int = 1) -> void:
	reseed(seed_value)


## Restart the sequence. Any seed is accepted; 0 is mapped to a fixed non-zero value.
func reseed(seed_value: int) -> void:
	_state = seed_value & 0xFFFFFFFF
	if _state == 0:
		_state = 0x1234ABCD


## Current internal state (save it to resume a sequence exactly).
func get_state() -> int:
	return _state


## Restore a state returned by [method get_state].
func set_state(state: int) -> void:
	_state = state & 0xFFFFFFFF
	if _state == 0:
		_state = 0x1234ABCD


## Next raw value in 0 .. 0xFFFFFFFF.
func next_u32() -> int:
	var x: int = _state
	x = (x ^ (x << 13)) & 0xFFFFFFFF
	x = x ^ (x >> 17)
	x = (x ^ (x << 5)) & 0xFFFFFFFF
	_state = x
	return x


## Uniform integer in 0 .. count - 1 (returns 0 when count <= 1).
func next_int(count: int) -> int:
	if count <= 1:
		return 0
	return next_u32() % count


## Uniform integer in from .. to (inclusive).
func range_int(from: int, to: int) -> int:
	if to <= from:
		return from
	return from + next_int(to - from + 1)


## True with probability numerator / denominator.
func chance(numerator: int, denominator: int) -> bool:
	return next_int(denominator) < numerator


## Random element index for an array size; -1 for an empty array.
func pick_index(size: int) -> int:
	if size <= 0:
		return -1
	return next_int(size)
