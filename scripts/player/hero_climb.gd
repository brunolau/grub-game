class_name HeroClimb
extends RefCounted
## The terrain that takes over the hero's own update: vines and the CLIMB state (docs/spec/PHYSICS.md C.4;
## DESIGN.md C.3) - grab, climb, top step, leap and drop - and the tar floor `:` (C.5; DESIGN.md C.4) - wading, the
## tar hop and its air control.
##
## Owner: player-B (docs/expansion/PLAN.md 4.1). A component of [Player], created with him; the calls below are the
## hooks of PLAN.md P0.8 and are made only while [member active] is true: a level with a vine (objects-B's
## `objects/vine`) or a tar floor cell. No Book I level has either, so a single-player hero of Book I never runs any
## of it.
##
## Hook order inside Player._hero_update: [method update] runs after the state table and its overrides (8c) and before
## the handler (8d). Returning true means it ran the rest of the PLAYER phase itself:
##  - the CLIMB handler (C.4) replaces handler, integration and the airborne step (no gravity, no WIND); it still
##    runs the hero's 8i timers (`hero._tick_timers(level)`) and sets his box;
##  - on tar (C.5) it runs the hero's own 8d-8i (his handlers, x and y steps, tile collision, glider tilt, timers, box)
##    with the three tar rules applied around them: the walk handler's ACCEL limit TAR_WALK_CAP, jump thrust only on
##    the first TAR_JUMP_IMPULSE_TICKS jump ticks, the airborne step's ACCEL limit TAR_AIR_CAP (the "tar hop").
##
## Vines are found by duck typing (objects-B's class Vine is not referenced, so this file never depends on theirs): an
## entity of the level's HITTABLE (or OTHER) list with a method `is_climbable() -> bool` and the members `vine_x`,
## `top`, `bottom` (logical px: the vine hangs at x = vine_x from the top edge of its cell, `top`, to `bottom`).

## Climb frames of the hero sheet (ASSET_MANIFEST 3): 44-47, one per HeroClimb.CLIMB_FRAME_PX px climbed.
const CLIMB_FRAME_FIRST: int = 44
const CLIMB_FRAME_COUNT: int = 4
const CLIMB_FRAME_PX: int = 4

## The hero this component belongs to.
var hero: Player = null
## True while the hooks run (the level holds a vine or a tar floor). Default false.
var active: bool = false
## True while he hangs on a vine (state Defs.HeroState.CLIMB).
var climbing: bool = false
## The vine he climbs (null when not climbing).
var vine: Object = null
## Px climbed up and down on vines since the level started (drives the climb frames).
var climb_px: int = 0
## The vine under the re-grab lock and the ticks left on it (Tuning.VINE_REGRAB_LOCK_TICKS after a leap or a drop).
var regrab_vine: Object = null
var regrab_lock: int = 0
## True from a grounded tick whose feet tile is tar until his next landing anywhere (PHYSICS.md C.5): the tar rules
## apply to his handlers, also during a hop taken from tar.
var on_tar: bool = false

## The vines of the level (cached by [method setup] / [method refresh]).
var _vines: Array[Object] = []
## True when the level's grid has a tar floor cell.
var _has_tar: bool = false
## y he hangs at (a shake nudge cannot move a climbing hero: PHYSICS.md C.4 "no shake nudge").
var _climb_y: int = 0


func _init(p_hero: Player) -> void:
	hero = p_hero


## The hero entered a level (Player._ready): switch on when it holds vines or a tar floor.
func setup(level: LevelBase) -> void:
	climbing = false
	vine = null
	regrab_vine = null
	regrab_lock = 0
	on_tar = false
	refresh(level)


## Look for the level's vines and tar cells again (a vine placed after the hero, e.g. by a test) and switch on when
## there are any. Never switches off a component that is on.
func refresh(level: LevelBase) -> void:
	_vines.clear()
	_has_tar = false
	if level == null:
		return
	for kind: int in [Defs.Kind.HITTABLE, Defs.Kind.OTHER, Defs.Kind.PLATFORM]:
		for entity: SimEntity in level.get_kind(kind):
			if is_vine(entity) and not _vines.has(entity):
				_vines.append(entity)
	_has_tar = grid_has_tar(level.grid)
	if not _vines.is_empty() or _has_tar:
		active = true


## True when `entity` is a vine (duck typing: a method `is_climbable` and a member `vine_x`).
static func is_vine(entity: Object) -> bool:
	return entity != null and entity.has_method(&"is_climbable") and entity.get(&"vine_x") != null


## True when `grid` has at least one tar floor cell.
static func grid_has_tar(grid: TileGrid) -> bool:
	if grid == null:
		return false
	for row: int in grid.rows:
		for col: int in grid.cols:
			if grid.is_tar(col, row):
				return true
	return false


## PLAYER phase, after 8c: the grab test and, while climbing, the CLIMB handler (C.4); on tar the tar update (C.5).
## True = it ran the rest of the hero's PLAYER phase this tick.
func update(level: LevelBase) -> bool:
	if climbing:
		if _still_on_vine():
			_climb_tick(level)
			return true
		leave_vine()
	if not _vines.is_empty() and (hero._raw_flags & Defs.IN_UP) != 0 and can_grab(level):
		var found: Object = find_vine(hero.sim_pos.x, hero.sim_pos.y)
		if found != null:
			_grab(found)
			_finish_climb_tick(level)
			return true
	if _has_tar:
		_update_tar_flag(level)
		if on_tar:
			_tar_tick(level)
			return true
	return false


## Step 8i (run by the hero's timer step): the re-grab lock.
func tick_timers() -> void:
	if regrab_lock > 0:
		regrab_lock -= 1
		if regrab_lock == 0:
			regrab_vine = null


## The hero was hurt; a hurt ends CLIMB (the normal knock-back follows). Never takes the hit (false).
func on_hurt(_source: SimEntity, _kind: int) -> bool:
	if climbing:
		leave_vine()
	return false


## The hero respawned: off every vine and off the tar.
func on_respawn() -> void:
	if climbing:
		leave_vine()
	regrab_vine = null
	regrab_lock = 0
	on_tar = false


## Sheet frame of the climb animation (44-47, one per CLIMB_FRAME_PX px climbed), for HeroAnim (player-A).
func climb_frame() -> int:
	return CLIMB_FRAME_FIRST + (climb_px / CLIMB_FRAME_PX) % CLIMB_FRAME_COUNT


# =================================================================================================================
# Vines (PHYSICS.md C.4)
# =================================================================================================================

## Everything of the grab test but UP and the vine geometry: not hurt-stunned, no strike running, not carrying the
## glider, curled, a ball, riding a partner, mounted, an egg or dead.
func can_grab(level: LevelBase) -> bool:
	if hero.dead or hero.down or hero.attack_gate or hero.run.has_glider or hero.curl != PlayerBase.CURL_NONE:
		return false
	if hero.is_mounted() or hero.hit_timer >= HeroBelt.hero_stun_min(hero):
		return false
	return not _rides_partner(level)


## The first vine (in spawn order) a hero with his feet at (x, y) can grab: climbable (unrolled), not under this hero's
## re-grab lock, |x - vine_x| <= Tuning.VINE_GRAB_DX, y > top and y - Tuning.VINE_HAND_REACH_PX <= bottom (his hands
## reach it). Null when none.
func find_vine(x: int, y: int) -> Object:
	for candidate: Object in _vines:
		if not is_instance_valid(candidate) or (candidate == regrab_vine and regrab_lock > 0):
			continue
		if not bool(candidate.call(&"is_climbable")):
			continue
		var vine_x: int = int(candidate.get(&"vine_x"))
		var top: int = int(candidate.get(&"top"))
		var bottom: int = int(candidate.get(&"bottom"))
		if absi(x - vine_x) <= Tuning.VINE_GRAB_DX and y > top and y - Tuning.VINE_HAND_REACH_PX <= bottom:
			return candidate
	return null


## Let go of the vine (a hurt, a respawn, a leap, a drop, being moved off it). He falls from the next tick.
func leave_vine() -> void:
	climbing = false
	vine = null


func _grab(target: Object) -> void:
	climbing = true
	vine = target
	on_tar = false
	hero.sim_pos.x = int(target.get(&"vine_x"))
	hero.xvel = 0
	hero.yvel = 0
	hero.jump_ticks = 0
	hero.fall_ticks = 0
	hero.on_platform = false
	hero.grounded = false
	hero.looking = false
	_climb_y = hero.sim_pos.y
	HeroBelt._play_cue(Sfx.VINE_CLIMB)


## While climbing: still on the vine where the last tick left him? A launch (a geyser), a carry or a pull moved him
## off it; a shake nudge (y only) is undone.
func _still_on_vine() -> bool:
	if vine == null or not is_instance_valid(vine) or hero.dead or hero.down or hero.is_mounted():
		return false
	if hero.curl != PlayerBase.CURL_NONE or hero.on_platform or hero.xvel != 0 or hero.yvel != 0:
		return false
	if hero.sim_pos.x != int(vine.get(&"vine_x")):
		return false
	hero.sim_pos.y = _climb_y
	return true


## One tick of the CLIMB handler (C.4 table, first match), then the 8i timers and the box.
func _climb_tick(level: LevelBase) -> void:
	var flags: int = hero._raw_flags
	var up: bool = (flags & Defs.IN_UP) != 0
	var down: bool = (flags & Defs.IN_DOWN) != 0
	var sideways: bool = (flags & (Defs.IN_LEFT | Defs.IN_RIGHT)) != 0
	if sideways and up:
		_leap()
	elif down and up:
		_drop()
	elif up:
		_climb_up(level)
	elif down:
		_climb_down(level)
	# LEFT or RIGHT alone turns him (8b already did); nothing, FIRE or LOOK: he hangs (no strikes on a vine).
	_finish_climb_tick(level)


## (LEFT or RIGHT) + UP: leap off towards his facing, launch(+/-32, -128); the re-grab lock on this vine.
func _leap() -> void:
	_lock_vine()
	leave_vine()
	hero.launch(Tuning.VINE_JUMP_XVEL * hero.facing, Tuning.VINE_JUMP_YVEL)
	hero.state = Defs.HeroState.JUMP
	hero.handler = Defs.HeroState.JUMP


## DOWN + UP: let go (yvel 0, he falls from the next tick); the re-grab lock on this vine.
func _drop() -> void:
	_lock_vine()
	leave_vine()
	_let_go()


## Off the vine into a fall: yvel 0 and the jump lock-out armed (as by a fall or a launch), so UP still held cannot
## start a jump in mid-air on the next tick.
func _let_go() -> void:
	hero.yvel = 0
	hero.no_jump = Tuning.NO_JUMP_TICKS
	hero.jump_ticks = 0
	hero.state = Defs.HeroState.IDLE
	hero.handler = Defs.HeroState.IDLE


func _lock_vine() -> void:
	regrab_vine = vine
	regrab_lock = Tuning.VINE_REGRAB_LOCK_TICKS


## UP: y - 2, refused under a ceiling (head probe of the new y at (col, row - 2)); at y - 2 <= top the top step.
func _climb_up(level: LevelBase) -> void:
	var grid: TileGrid = level.grid
	var new_y: int = hero.sim_pos.y - Tuning.VINE_CLIMB_UP_PX
	var col: int = Tuning.to_cell(hero.sim_pos.x)
	if grid.ceiling_at(col, Tuning.to_cell(new_y) - Tuning.HEAD_PROBE_ROWS) != TileGrid.CEILING_NONE:
		return
	var top: int = int(vine.get(&"top"))
	if new_y <= top:
		_top_step(grid, top)
		return
	hero.sim_pos.y = new_y
	_add_climb_px(Tuning.VINE_CLIMB_UP_PX)
	_climb_y = new_y


## The top step: with d = facing, then -facing, a floor at (col + d, top >> 4) takes him onto that ledge (x + 12 * d,
## y = top, grounded idle); with no ledge on either side he hangs at top + 1.
func _top_step(grid: TileGrid, top: int) -> void:
	var col: int = Tuning.to_cell(hero.sim_pos.x)
	var row: int = Tuning.to_cell(top)
	for d: int in [hero.facing, -hero.facing]:
		var floor_value: int = grid.floor_at(col + d, row)
		if TileGrid.is_ground(floor_value):
			leave_vine()
			hero.sim_pos.x += Tuning.VINE_TOP_STEP_PX * d
			hero.sim_pos.y = top
			_stand(TileGrid.floor_ice(floor_value))
			# A climbed ledge is a landing: the jump lock-out is armed, so UP still held keeps him standing (the
			# 1.0 rule after every landing) instead of jumping off the ledge on the next tick.
			hero.no_jump = Tuning.NO_JUMP_TICKS
			return
	hero.sim_pos.y = top + 1
	_climb_y = hero.sim_pos.y


## DOWN: y + 3; a floor (FLOOR 1-5) at the new feet tile: he lands on it (soft landing, idle); below bottom + 16 he
## lets go and falls.
func _climb_down(level: LevelBase) -> void:
	var grid: TileGrid = level.grid
	var new_y: int = hero.sim_pos.y + Tuning.VINE_CLIMB_DOWN_PX
	var col: int = Tuning.to_cell(hero.sim_pos.x)
	var row: int = Tuning.to_cell(new_y)
	var floor_value: int = grid.floor_at(col, row)
	_add_climb_px(Tuning.VINE_CLIMB_DOWN_PX)
	if TileGrid.is_ground(floor_value):
		var y: int = row * Tuning.TILE
		if grid.has_profile(col, row):
			y += grid.surface_offset(col, row, hero.sim_pos.x)
		leave_vine()
		hero.sim_pos.y = maxi(y, hero.sim_pos.y)
		_stand(TileGrid.floor_ice(floor_value))
		return
	hero.sim_pos.y = new_y
	_climb_y = new_y
	if new_y > int(vine.get(&"bottom")) + Tuning.TILE:
		leave_vine()
		_let_go()


## Count px climbed (the climb frames): here and in the hero's own `climb_px`, which HeroAnim (player-A) reads.
func _add_climb_px(px: int) -> void:
	climb_px += px
	hero.set(&"climb_px", climb_px)


## Grounded idle after the top step or a climb down onto a floor (the soft-landing bookkeeping of PHYSICS.md 11.2).
func _stand(ice: int) -> void:
	hero.xvel = 0
	hero.yvel = 0
	hero.grounded = true
	hero.on_platform = false
	hero.jump_ticks = 0
	hero.fall_ticks = 0
	hero.no_jump = maxi(hero.no_jump - 1, 0)
	hero.last_ground_y = hero.sim_pos.y
	hero.ice = ice
	hero.state = Defs.HeroState.IDLE
	hero.handler = Defs.HeroState.IDLE


## The end of a tick on the vine (or the tick that left it): state, the 8i timers, the box.
func _finish_climb_tick(level: LevelBase) -> void:
	if climbing:
		hero.state = Defs.HeroState.CLIMB
		hero.handler = Defs.HeroState.CLIMB
		hero.xvel = 0
		hero.yvel = 0
	hero._tick_timers(level)
	if climbing or hero.grounded:
		hero.set_box(Tuning.HERO_BOX_STAND)
	else:
		hero._update_box()


## True while a party's Totem Ride carries him (world-A's PartyDriver; never in single-player).
func _rides_partner(level: LevelBase) -> bool:
	if level == null or level.party_driver == null or not level.party_driver.has_method(&"carrier_of"):
		return false
	return level.party_driver.call(&"carrier_of", hero) != null


# =================================================================================================================
# Tar floor (PHYSICS.md C.5)
# =================================================================================================================

## On tar from a grounded tick whose feet tile is tar until the next landing anywhere: decided at the start of his
## update from where the last tick left him (a platform under his feet is a landing elsewhere).
func _update_tar_flag(level: LevelBase) -> void:
	var was: bool = on_tar
	if hero.on_platform:
		on_tar = false
	elif hero.grounded:
		on_tar = level.grid.is_tar(Tuning.to_cell(hero.sim_pos.x), Tuning.to_cell(hero.sim_pos.y))
	if on_tar and not was:
		HeroBelt._play_cue(Sfx.TAR_GLUG)


## The hero's 8d-8i on tar: his own handler, re-done where the tar rules differ; the x and y steps; tile collision;
## the airborne step's ACCEL limit; the glider tilt; timers; box.
func _tar_tick(level: LevelBase) -> void:
	var selected: int = hero.state
	var xvel_before: int = hero.xvel
	var yvel_before: int = hero.yvel
	var jump_ticks_before: int = hero.jump_ticks
	# 8d: the hero's own handler.
	if hero.run.has_glider:
		hero._run_glider(selected)
	else:
		hero._run_handler(selected)
	if hero.handler == Defs.HeroState.WALK:
		# The walk handler with ACCEL(TAR_WALK_CAP) instead of ACCEL(WALK_CAP) (its WIND after it, as in 1.0).
		hero.xvel = xvel_before
		hero._accel(Tuning.TAR_WALK_CAP)
		hero._wind()
	elif hero.handler == Defs.HeroState.JUMP and hero.jump_ticks == jump_ticks_before + 1 \
			and jump_ticks_before >= Tuning.TAR_JUMP_IMPULSE_TICKS \
			and jump_ticks_before < Tuning.JUMP_IMPULSE_TICKS:
		# The jump body ran with n >= 2: on tar its impulse is 0 (it only added the impulse to yvel on this tick).
		hero.yvel = yvel_before
	# 8e: x step (commit rule, this tick's fence); 8f: y step.
	var next_x: int = hero.sim_pos.x + Tuning.floor16(hero.xvel)
	if next_x >= Tuning.X_MIN and next_x < level.grid.x_max_excl() and hero.fence_allows(next_x):
		hero.sim_pos.x = next_x
	hero.clear_fence()
	hero.sim_pos.y += Tuning.floor16(hero.yvel)
	# 8g: tile collision.
	var low: bool = selected == Defs.HeroState.CRAWL or selected == Defs.HeroState.CROUCH
	hero._collide(level, Tuning.HERO_PROBE_H_CROUCH if low else Tuning.HERO_PROBE_H_STAND)
	if hero.dead:
		return
	if not hero.grounded:
		# The airborne step ran ACCEL(WALK_CAP); clamped again it is ACCEL(TAR_AIR_CAP) (the clamp is the last step).
		hero.xvel = clampi(hero.xvel, -Tuning.TAR_AIR_CAP, Tuning.TAR_AIR_CAP)
	# 8h: the glider nose returns to neutral; 8i: timers.
	var steering: bool = (hero._raw_flags & (Defs.IN_UP | Defs.IN_DOWN)) != 0
	if hero.run.has_glider and not steering and hero.glider_tilt != Tuning.GLIDER_TILT_NEUTRAL:
		hero.glider_tilt += 1 if hero.glider_tilt < Tuning.GLIDER_TILT_NEUTRAL else -1
	hero._tick_timers(level)
	hero._update_box()
