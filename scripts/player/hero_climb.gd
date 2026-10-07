class_name HeroClimb
extends RefCounted
## The hero's Book II terrain: vines and the CLIMB state (docs/spec/PHYSICS.md C.4; DESIGN.md C.3) - grab, climb, top
## step, leap and drop - and the tar floor `:` (C.5; DESIGN.md C.4) - wading, the tar hop and its air control.
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
##  - tar (C.5) never takes the update over (false): while he is on tar this component writes the hero's movement
##    limits (PlayerBase.walk_cap, air_cap, jump_impulse_ticks - player-A's hooks, read by his own walk handler, jump
##    handler and airborne step) to the tar values TAR_WALK_CAP, TAR_AIR_CAP and TAR_JUMP_IMPULSE_TICKS (never above
##    what versus weight already set) and restores them when the tar ends; the hero's own 8d-8i then run unchanged,
##    so nothing of his update is duplicated here.
##
## The tar ends at his next landing anywhere (a platform, a mount's saddle and a vine count), and also when something
## else throws him up before that (a launch - geyser, see-saw, dismount, Batter Up -, a bounce off an enemy, a head or a
## spring, a hurt): only a hop taken from tar stays a tar hop (player-B's resolution for worlds 6-9, P2.12: a geyser in
## a tar pit is an escape with full air control). Noticed as "yvel changed between his last 8i and this update".
##
## A climber is held by his vine: no sprite platform catches him while he hangs or climbs up (rafts, spear steps, drop
## clouds and lifts beside a vine), climbing down into one lands on it like climbing down onto a floor. UP grabs a vine,
## DOWN + UP never does (the drop / dismount / Totem-drop chord).
##
## Vines are found by duck typing (objects-B's class Vine is not referenced, so this file never depends on theirs): an
## entity of the level's HITTABLE (or OTHER) list with a method `is_climbable() -> bool` and the members `vine_x`,
## `top`, `bottom` (logical px: the vine hangs at x = vine_x from the top edge of its cell, `top`, to `bottom`).

## Climb frames of the hero sheet (ASSET_MANIFEST 3): 44-47, one per HeroClimb.CLIMB_FRAME_PX px climbed.
const CLIMB_FRAME_FIRST: int = 44
const CLIMB_FRAME_COUNT: int = 4
const CLIMB_FRAME_PX: int = 4
## Object metadata of the running level: [grid, has tar] (see [method level_has_tar]).
const TAR_META: StringName = &"_hero_climb_tar"

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
## Their geometry, three ints per vine in [member _vines] order: vine_x, top, bottom (fixed once a vine is spawned:
## objects-B's Vine sets them in _apply_params). The grab test reads these instead of three dynamic gets per vine.
var _vine_geo: PackedInt32Array = PackedInt32Array()
## True when the level's grid has a tar floor cell.
var _has_tar: bool = false
## y he hangs at (a shake nudge cannot move a climbing hero: PHYSICS.md C.4 "no shake nudge").
var _climb_y: int = 0
## The geometry of [member vine] while climbing.
var _vine_x: int = 0
var _vine_top: int = 0
var _vine_bottom: int = 0
## True while the hero's movement limits hold the tar values written by this component.
var _tar_limits: bool = false
## The hero's yvel at the end of his last update (step 8i): a different yvel at the start of this one means something
## else threw him up meanwhile (the end of a tar hop's tar rules).
var _yvel_at_8i: int = 0


func _init(p_hero: Player) -> void:
	hero = p_hero


## The hero entered a level (Player._ready): switch on when it holds vines or a tar floor.
func setup(level: LevelBase) -> void:
	climbing = false
	vine = null
	regrab_vine = null
	regrab_lock = 0
	end_tar()
	refresh(level)


## Look for the level's vines and tar cells again (a vine placed after the hero, e.g. by a test) and switch on when
## there are any. Never switches off a component that is on.
func refresh(level: LevelBase) -> void:
	_vines.clear()
	_vine_geo.clear()
	_has_tar = false
	if level == null:
		return
	for kind: int in [Defs.Kind.HITTABLE, Defs.Kind.OTHER, Defs.Kind.PLATFORM]:
		for entity: SimEntity in level.get_kind(kind):
			if is_vine(entity) and not _vines.has(entity):
				_vines.append(entity)
				_vine_geo.append(int(entity.get(&"vine_x")))
				_vine_geo.append(int(entity.get(&"top")))
				_vine_geo.append(int(entity.get(&"bottom")))
	_has_tar = level_has_tar(level)
	if not _vines.is_empty() or _has_tar:
		active = true


## True when `entity` is a vine (duck typing: a method `is_climbable` and a member `vine_x`).
static func is_vine(entity: Object) -> bool:
	return entity != null and entity.has_method(&"is_climbable") and entity.get(&"vine_x") != null


## True when the grid of `level` has a tar floor cell. Scanned once per grid and kept on the level (Object metadata
## TAR_META = [grid, answer]): every hero of a party asks at his setup, and a 230 x 40 stage is 9 200 cells.
static func level_has_tar(level: LevelBase) -> bool:
	if level == null or level.grid == null:
		return false
	if level.has_meta(TAR_META):
		var cached: Array = level.get_meta(TAR_META)
		if cached.size() == 2 and cached[0] == level.grid:
			return bool(cached[1])
	var answer: bool = grid_has_tar(level.grid)
	level.set_meta(TAR_META, [level.grid, answer])
	return answer


## True when `grid` has at least one tar floor cell (a full scan; [method level_has_tar] keeps the answer).
static func grid_has_tar(grid: TileGrid) -> bool:
	if grid == null:
		return false
	for row: int in grid.rows:
		for col: int in grid.cols:
			if grid.is_tar(col, row):
				return true
	return false


## PLAYER phase, after 8c: the grab test and, while climbing, the CLIMB handler (C.4); on a tar level the tar flag and
## the hero's movement limits for this tick (C.5). True = it ran the rest of the hero's PLAYER phase this tick (CLIMB
## only: on tar the hero's own 8d-8i run with the tar limits).
func update(level: LevelBase) -> bool:
	if climbing:
		if _still_on_vine():
			_climb_tick(level)
			return true
		leave_vine()
	# UP grabs; DOWN + UP never does - it is the "let go / get off" chord (the vine drop, the mount's dismount, the
	# Totem drop), so a dismount beside a vine flies off instead of grabbing it for one tick.
	if not _vines.is_empty() and (hero._raw_flags & (Defs.IN_UP | Defs.IN_DOWN)) == Defs.IN_UP:
		var found: Object = find_vine(hero.sim_pos.x, hero.sim_pos.y)
		if found != null and can_grab(level):
			_grab(found)
			_finish_climb_tick(level)
			return true
	if _has_tar:
		_update_tar_flag(level)
		_apply_tar_limits()
	return false


## Step 8i (run by the hero's timer step): the re-grab lock; the yvel the tar rule compares with on the next tick.
func tick_timers() -> void:
	if regrab_lock > 0:
		regrab_lock -= 1
		if regrab_lock == 0:
			regrab_vine = null
	_yvel_at_8i = hero.yvel


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
	end_tar()
	_yvel_at_8i = hero.yvel


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


## The first vine (in spawn order) a hero with his feet at (x, y) can grab: |x - vine_x| <= Tuning.VINE_GRAB_DX,
## y > top and y - Tuning.VINE_HAND_REACH_PX <= bottom (his hands reach it), not under this hero's re-grab lock,
## climbable (unrolled). Null when none. The geometry comes from the cache, so a vine out of reach costs a few integer
## compares; only a vine in reach is asked `is_climbable()`.
func find_vine(x: int, y: int) -> Object:
	var count: int = _vines.size()
	for i: int in count:
		var base: int = i * 3
		if absi(x - _vine_geo[base]) > Tuning.VINE_GRAB_DX or y <= _vine_geo[base + 1] \
				or y - Tuning.VINE_HAND_REACH_PX > _vine_geo[base + 2]:
			continue
		var candidate: Object = _vines[i]
		if not is_instance_valid(candidate) or (candidate == regrab_vine and regrab_lock > 0):
			continue
		if bool(candidate.call(&"is_climbable")):
			return candidate
	return null


## Let go of the vine (a hurt, a respawn, a leap, a drop, being moved off it). He falls from the next tick; platforms
## may catch him again from the next PLATFORMS phase on.
func leave_vine() -> void:
	climbing = false
	vine = null
	if hero.carried_on_tick > Sim.total_ticks:
		hero.carried_on_tick = -1


func _grab(target: Object) -> void:
	climbing = true
	vine = target
	_vine_x = int(target.get(&"vine_x"))
	_vine_top = int(target.get(&"top"))
	_vine_bottom = int(target.get(&"bottom"))
	end_tar()
	hero.sim_pos.x = _vine_x
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
	if hero.sim_pos.x != _vine_x:
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
		# Climbing down into a sprite platform lands on it, as onto a floor: its next ride test may take him.
		_finish_climb_tick(level, false)
		return
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
	if new_y <= _vine_top:
		_top_step(grid, _vine_top)
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
	if new_y > _vine_bottom + Tuning.TILE:
		leave_vine()
		_let_go()


## Count px climbed (the climb frames; HeroAnim, player-A, reads [member climb_px]).
func _add_climb_px(px: int) -> void:
	climb_px += px


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


## The end of a tick on the vine (or the tick that left it): state, the 8i timers, the box. Still on the vine and
## `held`: the vine holds him through the next tick's PLATFORMS phase - no sprite platform (raft, spear step, drop
## cloud, lift, see-saw) catches him there, so a hero can grab a vine from a platform and climb on, and a platform
## passing a climber goes by (PlatformBase's "one platform per hero per tick" guard, PlayerBase.carried_on_tick, is
## set to that tick: the vine is his carrier then).
func _finish_climb_tick(level: LevelBase, held: bool = true) -> void:
	if climbing:
		hero.state = Defs.HeroState.CLIMB
		hero.handler = Defs.HeroState.CLIMB
		hero.xvel = 0
		hero.yvel = 0
		if held:
			hero.carried_on_tick = Sim.total_ticks + 1
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

## Off the tar now (a respawn, a stage start, a vine or a mount's saddle: a landing elsewhere); the hero's movement
## limits go back to what they are without tar at once.
func end_tar() -> void:
	on_tar = false
	if _tar_limits:
		_restore_limits()


## On tar from a grounded tick whose feet tile is tar until the next landing anywhere: decided at the start of his
## update from where the last tick left him (a platform under his feet is a landing elsewhere). In the air the tar
## rules last only while nothing else threw him up since his last update: his yvel is still the one his own update
## left (8i), so a geyser, a see-saw, a dismount, Batter Up, a bounce off an enemy, a head or a spring, a pogo or a hurt
## ends them - only a hop taken from tar (or a fall off a tar ledge) stays under them.
func _update_tar_flag(level: LevelBase) -> void:
	var was: bool = on_tar
	if hero.on_platform:
		on_tar = false
	elif hero.grounded:
		on_tar = level.grid.is_tar(Tuning.to_cell(hero.sim_pos.x), Tuning.to_cell(hero.sim_pos.y))
	elif on_tar and hero.yvel != _yvel_at_8i:
		on_tar = false
	if on_tar and not was:
		HeroBelt._play_cue(Sfx.TAR_GLUG)


## The hero's movement limits of this tick (PHYSICS.md C.5): on tar the walk handler's ACCEL limit TAR_WALK_CAP, the
## airborne step's TAR_AIR_CAP (never above a versus weight cap already in force) and jump thrust only on the first
## TAR_JUMP_IMPULSE_TICKS jump ticks; off tar what they were.
func _apply_tar_limits() -> void:
	if on_tar:
		var base: int = _base_walk_cap()
		hero.walk_cap = mini(base, Tuning.TAR_WALK_CAP)
		hero.air_cap = mini(base, Tuning.TAR_AIR_CAP)
		hero.jump_impulse_ticks = mini(Tuning.JUMP_IMPULSE_TICKS, Tuning.TAR_JUMP_IMPULSE_TICKS)
		_tar_limits = true
	elif _tar_limits:
		_restore_limits()


## The limits without tar: the versus weight / ember cap when world-B's referee set one (PlayerBase.walk_cap_override,
## for the walk handler and the airborne step alike), else the 1.0 values.
func _restore_limits() -> void:
	var base: int = _base_walk_cap()
	hero.walk_cap = base
	hero.air_cap = base
	hero.jump_impulse_ticks = Tuning.JUMP_IMPULSE_TICKS
	_tar_limits = false


func _base_walk_cap() -> int:
	return hero.walk_cap_override if hero.walk_cap_override > 0 else Tuning.WALK_CAP
