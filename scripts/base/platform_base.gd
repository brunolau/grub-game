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
## 2.0 (PLAN.md P0.8): bit `slot` set for every hero this platform carried in its last ride test ([member ridden] =
## any bit set). For weight rules (pulleys, drop platforms that count riders; DESIGN.md D.5): [method rider_count],
## [method rider_weight]. Bookkeeping only: nothing in the 1.0 game reads it.
var rider_mask: int = 0

# The "one platform per hero per tick" guard is the hero's own PlayerBase.carried_on_tick (2.0: it was one static
# value here for the one hero; per hero it is the same for a party of one, TECH_AUDIT.md 3.12).


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


## The ride test of PHYSICS.md 11.4. Returns true when the hero is now riding this platform. A party (2.0,
## TECH_AUDIT.md 3.12): every hero in LevelBase.contact_order() (slot order) is tested, each carried by at most one
## platform per tick (PlayerBase.carried_on_tick); true when any hero rides it.
func _ride_test() -> bool:
	rider_mask = 0
	var level: LevelBase = Game.level
	if level == null or not on_screen:
		return false
	var riding: bool = false
	for hero: PlayerBase in level.contact_order():
		if _ride_test_hero(hero):
			riding = true
			rider_mask |= 1 << hero.slot
	return riding


## 2.0: number of heroes riding it since its last ride test ([member rider_mask]).
func rider_count() -> int:
	var count: int = 0
	var mask: int = rider_mask
	while mask != 0:
		count += mask & 1
		mask >>= 1
	return count


## 2.0: weight on it since its last ride test (DESIGN.md D.5: PartyTuning.PLATE_WEIGHT_HERO per hero, plus
## [method _extra_weight]). The heavier side of a pulley sinks.
func rider_weight() -> int:
	return rider_count() * PartyTuning.PLATE_WEIGHT_HERO + _extra_weight()


## 2.0 hook: weight on it that is no riding hero (a boulder resting on it ...). Override; 0 by default.
func _extra_weight() -> int:
	return 0


## The ride test of PHYSICS.md 11.4 for one hero: true when `hero` is now riding this platform.
func _ride_test_hero(hero: PlayerBase) -> bool:
	if hero.dead or hero.yvel <= Tuning.PLATFORM_RIDE_MIN_YVEL_EXCL or hero.carried_on_tick == Sim.total_ticks:
		return false
	# The hero's feet must be inside the platform's contact band below its surface. The band is the platform's own
	# height (8 px), but a hero falling at PLATFORM_CATCH_YVEL or faster can step across 8 px in one tick: for him
	# it reaches PLATFORM_CATCH_DEPTH below the surface, so a landing at any fall speed up to the terminal one is
	# caught (ride_platform puts him back on the surface).
	var depth: int = box_h
	if hero.yvel >= Tuning.PLATFORM_CATCH_YVEL:
		depth = maxi(box_h, Tuning.PLATFORM_CATCH_DEPTH)
	var band_bottom: int = sim_pos.y - box_h + depth
	if band_bottom <= hero.sim_pos.y:
		return false
	var ride: Vector3i = Tuning.HERO_BOX_RIDE
	var hero_bottom: int = hero.sim_pos.y + (dy if dy > 0 else 0)
	if not Overlap.test(
		hero.sim_pos.x, hero_bottom, ride.x, ride.y, ride.z,
		sim_pos.x, band_bottom, box_w, depth, box_xo,
		false, hero.yvel, 1
	):
		return false
	hero.carried_on_tick = Sim.total_ticks
	hero.ride_platform(self, dx, dy)
	return true
