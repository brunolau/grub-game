class_name PlatformBase
extends SimEntity
## Sprite platform the hero can ride (PHYSICS.md 11.4, GAMEPLAY.md 7.3): movers and droppers.
##
## CONTRACT FILE (docs/ARCHITECTURE.md 3.15). Owner: objects (bodies may be replaced; public signatures frozen).
## `sim_pos` is the bottom-centre of the platform sprite; the standing surface is `sim_pos.y - box_h`.
## Platforms are processed in the PLATFORMS phase, BEFORE the hero update: they move, then run the ride test,
## and at most one platform per tick may carry the hero.

## Movement of this tick in px (set by `_move_tick`, used by the ride test).
var dx: int = 0
var dy: int = 0
## True when the hero rode this platform on the previous tick (movers flagged "ride" start, droppers count down).
var ridden: bool = false

## Tick on which some platform already carried the hero (only one per tick).
static var _carried_on_tick: int = -1


func get_kind() -> int:
	return Defs.Kind.PLATFORM


func _init() -> void:
	z_index = Defs.Z_PLATFORMS
	box_w = 48
	box_h = 8
	box_xo = 24


func _sim_phases() -> PackedInt32Array:
	return PackedInt32Array([Defs.Phase.PLATFORMS])


func _sim_tick(phase: int) -> void:
	if phase != Defs.Phase.PLATFORMS:
		return
	dx = 0
	dy = 0
	_move_tick()
	sim_pos.x += dx
	sim_pos.y += dy
	ridden = _ride_test()


## Decide this tick's movement by setting `dx` / `dy` (px). Override.
func _move_tick() -> void:
	pass


## The ride test of PHYSICS.md 11.4. Returns true when the hero is now riding this platform.
func _ride_test() -> bool:
	var level: LevelBase = Game.level
	if level == null or level.player == null or not on_screen:
		return false
	var hero: PlayerBase = level.player
	if hero.dead or hero.yvel <= Tuning.PLATFORM_RIDE_MIN_YVEL_EXCL or _carried_on_tick == Sim.total_ticks:
		return false
	if sim_pos.y <= hero.sim_pos.y:
		return false
	var ride: Vector3i = Tuning.HERO_BOX_RIDE
	var hero_bottom: int = hero.sim_pos.y + (dy if dy > 0 else 0)
	if not Overlap.test(
		hero.sim_pos.x, hero_bottom, ride.x, ride.y, ride.z,
		sim_pos.x, sim_pos.y, box_w, box_h, box_xo,
		false, hero.yvel, 1
	):
		return false
	_carried_on_tick = Sim.total_ticks
	hero.ride_platform(self, dx, dy)
	return true
