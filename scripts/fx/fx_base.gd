class_name FxBase
extends SimEntity
## Base of every cosmetic effect `fx/*` (ARCHITECTURE.md 6.2): puffs, bursts, debris, pop-ups. An effect is a
## SimEntity of kind FX so that it advances with the simulation clock (it freezes with the pause and runs in step
## with `Sim.step` in tests and autoplay), but nothing in the game ever reads its state. It frees itself after
## `lifetime` ticks.
##
## Effects draw their randomness from a private generator seeded by their spawn point and tick, never from
## Sim.rng, so that cosmetics cannot change the gameplay random sequence.

## Ticks since the effect started ticking.
var age: int = 0
## Ticks the effect lives (at least 1).
var lifetime: int = 1

var _sprite: Sprite2D = null


func get_kind() -> int:
	return Defs.Kind.FX


func _init() -> void:
	z_index = Defs.Z_FX
	set_box(Vector3i(16, 16, 8))


func _sim_phases() -> PackedInt32Array:
	return PackedInt32Array([Defs.Phase.FX])


func _sim_tick(_phase: int) -> void:
	age += 1
	_fx_tick()
	if age >= lifetime:
		sim_active = false
		queue_free()


## One tick of the effect. Override.
func _fx_tick() -> void:
	pass


## The child Sprite2D named "Sprite", or null.
func get_sprite() -> Sprite2D:
	if _sprite == null:
		_sprite = get_node_or_null(^"Sprite") as Sprite2D
	return _sprite


## A private random generator for this effect (deterministic, independent of Sim.rng).
func make_rng() -> SimRng:
	return SimRng.new((sim_pos.x * 73856093) ^ (sim_pos.y * 19349663) ^ (Sim.total_ticks * 83492791))
