class_name Coconut
extends SimEntity
## `objects/coconut` (arenas only, no parameters): the Clubball ball (DESIGN.md E.4, GAMEPLAY.md 13.10.6) and its drop
## point, the feet point of its cell (the Coconut Cove sketch: column 9 on the floor row's top). Box 16 x 16, x_offset
## 8; [member SimEntity.sim_pos] is the FEET point (bottom centre of the box), [method center] its centre.
##
## Per tick (Defs.Phase):
##  - WEAPONS (before the heroes' own weapon pass and the referee's gather: level entities tick before the heroes):
##    every hero's club box of the previous tick that is a **front** frame of a melee weapon (forward front = drive
##    +/-144, -128; high front = lob +/-32, -240; low front = grounder +/-96, 0) and overlaps the ball (weapon test)
##    is a shot; a charged box (club_power over the weapon's power) smashes x3/2. The box is consumed (one target per
##    box: no rival is hit by it). **One shot per swing**: a strike's front frame lasts 3 ticks with a new box on
##    each, so a hero whose front boxes came on every tick since his shot (the same swing) does not shoot again - those
##    boxes stay for other targets (a bare PlayerBase without strike scripts has no swing: each box is a strike).
##    A shot within VersusTuning.RALLY_WINDOW_TICKS of the previous shot (anyone's)
##    raises the rally by one, and |xvel| grows by RALLY_STEP per rally step up to BALL_MAX_SPEED (a faster shot,
##    a smash, keeps its own speed); a later shot restarts the rally. Two or more boxes on the same tick add up
##    (nobody wins by slot order: opposite drives cancel sideways). Every component stays within +/-AXIS_CAP.
##  - ITEMS: the move, [method physics_step] - the one pure function the bots predict with ([method predict]).
##  - CONTACT_ITEMS (after every hero moved), heroes in LevelBase.contact_order(), at most one contact per tick:
##    a batted hero flying as a ball (curl == CURL_BALL) that touches it passes his velocity on (the "missile", once
##    per flight); a ball faster than VersusTuning.BALL_KNOCKDOWN_SPEED_EXCL on either axis knocks the hero down (the
##    versus hurt, Defs.HurtKind.RIVAL: 12 stunned ticks, **no immunity** after them, no currency) and bounces back at
##    half speed; otherwise a ball coming down on a head (the stomp flag of the body test) bounces up at 3/4, at least
##    HEAD_BOUNCE_MIN_YVEL. A slow ball passes through bodies. The strikers of the last shot (and a missile with its
##    batter) are not knocked down by it for SHOOTER_GRACE_TICKS.
##
## The physics ([method physics_step], GAMEPLAY.md 13.10.6): x step first - the box's leading edge entering a SIDE-1
## cell (or the level edge) stops it flush against the wall and reflects xvel at 3/4; then the y step - rising, a
## CEILING-1 cell over the box's top stops it under the cell and reflects yvel at 3/4; falling, a floor at the feet
## cell (ground, or floor spikes) lands it on the surface: yvel >= BOUNCE_MIN_YVEL bounces with
## `yvel = -(yvel * 3) >> 2`, slower rests (yvel 0); then, airborne (a bounce included: it leaves the floor on its own
## tick), gravity 16 (cap Tuning.TERMINAL). A ball resting on a floor (yvel 0) rolls: |xvel| loses
## VersusTuning.BALL_ROLL_LOSS per tick (before its x step). A ball in `~` or below the map is lost: it comes back at
## the drop point VersusTuning.BALL_RESET_TICKS later. No wrap edges (the Clubball arena has walls).
##
## In a mode other than Clubball (the referee's `mode`; Coconut Cove hosts the other modes too) the coconut sits the
## round out: hidden, it takes no box and touches nothing ([method is_active]).
##
## For the referee (world-B: goals, kick-offs, the golden coconut) and the bots (core-B), all public:
## [method find], [method center], [method ball_rect], [method in_play], [method goal_team], [method reset_after],
## [member golden], [member last_touch_slot], [member rally], the static [method predict] (and [method predict_ahead]
## / [method predict_landing] from the ball's current state), and the signals [signal shot_made],
## [signal knocked_down], [signal shot_landed], [signal lost].
##
## Owner: objects-B (docs/expansion/PLAN.md 4.1, P2.7). Picture: art-A's sprites/objects/coconut.png (ASSET_MANIFEST
## 17.11: 32 x 32 art cells, 4 x 2; row 0 the coconut, row 1 the golden coconut; columns = clockwise quarter turns,
## stepped forwards while it rolls right; pivot (16, 16) = the centre). Should the sheet be missing (an export filter),
## the coconut bomb of sprites/items/pickups.png (the grenade cell, ASSET_MANIFEST 7) stands in, turned and tinted
## gold. Marks: [G 13.10.6] GAMEPLAY.md, [own] this module.

## A shot hit the ball: `slot` struck it (the lowest slot when several did on the same tick), `kind` a SHOT_* value.
signal shot_made(slot: int, kind: int, charged: bool)
## The ball knocked `hero` down (fast ball, 12 stunned ticks).
signal knocked_down(hero: PlayerBase)
## The first floor touch after a shot of `slot`: the ball travelled `distance` px across (Home Run; the striker's
## PlayerRun.note_shot is fed with it here).
signal shot_landed(slot: int, distance: int)
## The ball fell into a liquid or out of the level; it comes back at the drop point after BALL_RESET_TICKS.
signal lost()

## Shot kinds of [signal shot_made].
const SHOT_DRIVE: int = 0
const SHOT_LOB: int = 1
const SHOT_GROUNDER: int = 2
const SHOT_MISSILE: int = 3

# --- GAMEPLAY.md 13.10.6: VersusTuning's values (core-A), under the names the referee and the tests use -------------
const DRIVE_XVEL: int = VersusTuning.BALL_DRIVE_XVEL                ## forward front box: drive
const DRIVE_YVEL: int = VersusTuning.BALL_DRIVE_YVEL
const LOB_XVEL: int = VersusTuning.BALL_LOB_XVEL                    ## high front box: lob
const LOB_YVEL: int = VersusTuning.BALL_LOB_YVEL
const GROUNDER_XVEL: int = VersusTuning.BALL_GROUNDER_XVEL          ## low front box: grounder along the floor
const BOUNCE_MIN_YVEL: int = VersusTuning.BALL_BOUNCE_MIN_YVEL      ## a floor bounces it while yvel >= 32, else rests
const HEAD_BOUNCE_MIN_YVEL: int = VersusTuning.BALL_HEAD_BOUNCE_MIN_YVEL  ## a head bounces it up at 3/4, at least this
## Every velocity component stays within +/-288 (the doze reach, PHYSICS.md C.15: "the Clubball coconut at most 18").
const AXIS_CAP: int = PartyTuning.LAUNCH_AXIS_CAP
const BOX: Vector3i = Vector3i(16, 16, 8)
## After a reset the ball drops in from this high over its drop point (less under a ceiling). [own]
const DROP_IN_PX: int = 48
## The striker of the last shot is not knocked down by it this long. [own]
const SHOOTER_GRACE_TICKS: int = 8

# Events of physics_step (bit mask).
const EV_FLOOR: int = 1     ## touched a floor (landed, rests or bounced)
const EV_WALL: int = 2
const EV_CEILING: int = 4
const EV_LOST: int = 8      ## fell into `~` or out of the level
const EV_BOUNCE: int = 16   ## bounced off a floor (yvel >= BOUNCE_MIN_YVEL)

# --- Picture -------------------------------------------------------------------------------------------------------
const OWN_SHEET_PATH: String = "res://assets/sprites/objects/coconut.png"
const OWN_SHEET_COLUMNS: int = 4
const FALLBACK_SHEET: Texture2D = preload("res://assets/sprites/items/pickups.png")
const FALLBACK_CELL_ART: Vector2 = Vector2(48, 40)
const GOLD_TINT: Color = Color(1.0, 0.82, 0.3)
## Roll picture: one sheet column per this many px rolled. Cosmetic.
const ROLL_STEP_PX: int = 6

## The drop point (feet): its spawn point.
var drop_point: Vector2i = Vector2i.ZERO
## The golden coconut of a tie ("next goal wins"): the referee sets it; only the picture changes.
var golden: bool = false:
	set(value):
		golden = value
		_refresh_look()
## The slot that touched the ball last (a shot, a missile's batter, a header); -1 = nobody since the last reset.
var last_touch_slot: int = -1
## Rally steps of the running exchange (0 = the first shot of a rally).
var rally: int = 0
## Sim.tick of the last shot (-1 = none since the last reset).
var last_shot_tick: int = -1
## Shots and knock-downs since the level started (statistics, tests).
var shots: int = 0
var knockdowns: int = 0

## Ticks left until the ball drops in again (> 0 while out of play after a goal or a loss).
var _reset_left: int = 0
## The slot and x of the shot whose first landing is still to come (Home Run), -1 = none.
var _flight_slot: int = -1
var _flight_from_x: int = 0
## Bit per slot of a batted hero who passed his speed on during his current flight.
var _missile_mask: int = 0
## Per slot: the hit_timer a knock-down left, followed until the stun is over to cut the immunity (-1 = none).
var _knock_mark: PackedInt32Array = PackedInt32Array()
## Bit per slot that struck the last shot (its grace against its own ball).
var _shooter_mask: int = 0
## Per slot: the Sim.tick of his last front box (his swing goes on while one comes on every tick), and 1 when that
## swing already shot the ball (one shot per swing).
var _swing_tick: PackedInt32Array = PackedInt32Array()
var _swing_shot: PackedInt32Array = PackedInt32Array()
var _sprite: Sprite2D = null
var _own_sheet: bool = false
var _roll_px: int = 0


func _init() -> void:
	z_index = Defs.Z_ITEMS
	set_box(BOX)
	_knock_mark.resize(Defs.MAX_PLAYERS)
	_knock_mark.fill(-1)
	_swing_tick.resize(Defs.MAX_PLAYERS)
	_swing_tick.fill(-1)
	_swing_shot.resize(Defs.MAX_PLAYERS)
	_swing_shot.fill(0)


func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.name = "Sprite"
	if ResourceLoader.exists(OWN_SHEET_PATH):
		_own_sheet = true
		_sprite.texture = load(OWN_SHEET_PATH) as Texture2D
		_sprite.hframes = OWN_SHEET_COLUMNS
		_sprite.vframes = 2
		_sprite.centered = true
	else:
		_sprite.texture = FALLBACK_SHEET
		_sprite.hframes = 8
		_sprite.vframes = 2
		_sprite.frame = ItemTable.CELL_GRENADE
		_sprite.centered = false
		# The 32 x 32 art icon sits at the bottom centre of its 48 x 40 cell: put its centre on the node's origin.
		_sprite.offset = Vector2(-FALLBACK_CELL_ART.x / 2.0, -FALLBACK_CELL_ART.y + float(BOX.y))
	# The node's origin is the feet point; the picture turns about the ball's centre.
	_sprite.position = Vector2(0.0, -float(BOX.y))
	add_child(_sprite)
	_refresh_look()


func _sim_phases() -> PackedInt32Array:
	return PackedInt32Array([Defs.Phase.WEAPONS, Defs.Phase.ITEMS, Defs.Phase.CONTACT_ITEMS])


func _apply_params(_params: Dictionary) -> void:
	drop_point = sim_pos


# =================================================================================================================
# Queries (referee, bots, HUD)
# =================================================================================================================

## The first coconut of `level` in spawn order (null when none).
static func find(level: LevelBase) -> Coconut:
	if level == null:
		return null
	for entity: SimEntity in level.get_kind(Defs.Kind.OTHER):
		var ball: Coconut = entity as Coconut
		if ball != null and not ball.is_queued_for_deletion():
			return ball
	return null


## The centre of the ball (logical px): what a goal tests.
func center() -> Vector2i:
	return Vector2i(sim_pos.x, sim_pos.y - (BOX.y >> 1))


## The ball's box (logical px).
func ball_rect() -> Rect2i:
	return Rect2i(sim_pos.x - BOX.z, sim_pos.y - BOX.y, BOX.x, BOX.y)


## False while the ball waits to drop in again (after a goal or a loss), and in a mode other than Clubball: it
## touches nothing and is not drawn.
func in_play() -> bool:
	return _reset_left == 0 and is_active()


## True unless the level's referee plays another mode than Clubball (its `mode`): Coconut Cove hosts the other modes
## too (its goal mouths are ring-outs then), and there the coconut sits the round out - hidden, touching nothing.
## Without a referee (tests, previews) it always plays.
func is_active() -> bool:
	var level: LevelBase = Game.level
	var referee: SimEntity = level.party_driver if level != null else null
	return referee == null or not (&"mode" in referee) or int(referee.get(&"mode")) == Defs.VersusMode.CLUBBALL


## Ticks until the ball drops in again (0 = in play).
func reset_ticks_left() -> int:
	return _reset_left


## The team (`team` parameter, 1 or 2) of the goal zone whose rectangle holds the ball's centre: every Defs.Kind.ZONE
## entity with a `team` spawn parameter and a ZoneBase rect (`zones/goal team=1|2`, world-B / world-A). 0 = none
## (or out of play). Which team scores is the referee's rule (the centre in the OTHER team's goal).
func goal_team() -> int:
	var level: LevelBase = Game.level
	if level == null or not in_play():
		return 0
	var c: Vector2i = center()
	for entity: SimEntity in level.get_kind(Defs.Kind.ZONE):
		var zone: ZoneBase = entity as ZoneBase
		if zone == null or not zone.spawn_params.has("team"):
			continue
		if Overlap.point_in(zone.rect, c.x, c.y):
			return int(zone.spawn_params["team"])
	return 0


## Take the ball out of play now and drop it in at its drop point `ticks` later (a goal: the referee calls it with
## VersusTuning.BALL_RESET_TICKS; 0 = at once). The rally, the last touch and the flight end.
func reset_after(ticks: int) -> void:
	_doze_wake_now()
	xvel = 0
	yvel = 0
	_flight_slot = -1
	if ticks <= 0:
		_reset_left = 0
		_drop_in()
		return
	_reset_left = ticks
	visible = false


## The feet points of the next `ticks` ticks of the ball as it is now, by [method physics_step] alone (no heroes,
## no goals): the bots' prediction ([method predict] from its current state). Empty while it is out of play.
func predict_ahead(ticks: int) -> PackedVector2Array:
	if not in_play() or Game.level == null:
		return PackedVector2Array()
	return Coconut.predict(Game.level.grid, sim_pos, xvel, yvel, ticks)


## Where the ball as it is now first touches a floor within `max_ticks` (its feet point there), or Vector2i(-1, -1).
func predict_landing(max_ticks: int = 120) -> Vector2i:
	if not in_play() or Game.level == null:
		return Vector2i(-1, -1)
	var state: PackedInt32Array = PackedInt32Array([sim_pos.x, sim_pos.y, xvel, yvel])
	for t: int in max_ticks:
		var events: int = Coconut.physics_step(Game.level.grid, state)
		if (events & EV_LOST) != 0:
			return Vector2i(-1, -1)
		if (events & EV_FLOOR) != 0:
			return Vector2i(state[0], state[1])
	return Vector2i(-1, -1)


## The bots' prediction for any start (core-B: wf8_core-B_to_objects-B.txt): the feet points after each of the next
## `ticks` ticks of a ball at `pos` (feet point) with (`p_xvel`, `p_yvel`) v16 on `grid`, by [method physics_step]
## (tile collision only: no heads, heroes or goals). Stops early when the ball would be lost.
static func predict(grid: TileGrid, pos: Vector2i, p_xvel: int, p_yvel: int, ticks: int) -> PackedVector2Array:
	var path: PackedVector2Array = PackedVector2Array()
	var state: PackedInt32Array = PackedInt32Array([pos.x, pos.y, p_xvel, p_yvel])
	for t: int in ticks:
		var events: int = physics_step(grid, state)
		if (events & EV_LOST) != 0:
			break
		path.append(Vector2(state[0], state[1]))
	return path


# =================================================================================================================
# The physics (pure: the entity and the bots run exactly this)
# =================================================================================================================

## One tick of ball physics on `grid` for `state` = [x, y, xvel, yvel] (feet point px, v16), changed in place.
## Returns the EV_* events of the tick. See the class description for the rules. A step longer than a cell (a
## smash or a missile, up to 18 px) tests every column / row it crosses, so the ball never tunnels through a wall,
## a ceiling or a one-way floor.
static func physics_step(grid: TileGrid, state: PackedInt32Array) -> int:
	var x: int = state[0]
	var y: int = state[1]
	var xv: int = state[2]
	var yv: int = state[3]
	var events: int = 0
	# Rolling: resting on a floor, it loses BALL_ROLL_LOSS per tick.
	if yv == 0 and xv != 0 and _rests_on_floor(grid, x, y):
		var speed: int = maxi(absi(xv) - VersusTuning.BALL_ROLL_LOSS, 0)
		xv = speed if xv > 0 else -speed
	# x step: the leading edge of the box against walls and the level edges.
	if xv != 0:
		var next_x: int = x + Tuning.floor16(xv)
		var stop_x: int = _wall_stop(grid, x, next_x, y)
		if stop_x != next_x:
			events |= EV_WALL
			xv = _reflect34(xv)
		x = stop_x
	# y step.
	var old_y: int = y
	y += Tuning.floor16(yv)
	var landed: bool = false
	if yv < 0:
		var old_top_row: int = (old_y - BOX.y) >> 4
		var new_top_row: int = (y - BOX.y) >> 4
		var first: int = old_top_row - 1 if new_top_row < old_top_row else new_top_row
		for row: int in range(first, new_top_row - 1, -1):
			if _ceiling_over(grid, x, row):
				y = (row + 1) * Tuning.TILE + BOX.y
				yv = _reflect34(yv)
				events |= EV_CEILING
				break
	else:
		var col: int = x >> 4
		var to_row: int = y >> 4
		for row: int in range(mini(old_y >> 4, to_row), to_row + 1):
			if _is_ball_floor(grid, col, row, grid.floor_at(col, row)):
				var surface: int = row * Tuning.TILE + grid.surface_offset(col, row, x)
				# The feet cell (the 1.0 rule: feet inside a floor cell land on it), or a floor crossed from above.
				if y >= surface and (row == to_row or old_y <= surface):
					y = surface
					landed = true
					events |= EV_FLOOR
					if yv >= BOUNCE_MIN_YVEL:
						yv = (-(yv * VersusTuning.BALL_BOUNCE_NUM)) >> 2
						events |= EV_BOUNCE
					else:
						yv = 0
					break
			elif grid.get_char(col, row) == TileGrid.CH_LIQUID:
				events |= EV_LOST
				break
		if not landed and y > grid.height_px() + Tuning.PIT_DEPTH_PX:
			events |= EV_LOST
	if not landed or yv < 0:
		# Airborne - a floor bounce leaves the floor on its own tick, so gravity runs on it too. (Without it the
		# integration of section 2 - move, then gravity - hands every bounce back about 12 v16 more than it took off
		# with, and from about 55 v16 down the 3/4 rebound never falls under BOUNCE_MIN_YVEL: the ball would hop
		# 3 px forever. With it the bounces die down within six.)
		yv = mini(yv + VersusTuning.BALL_GRAVITY, Tuning.TERMINAL)
	state[0] = x
	state[1] = y
	state[2] = clampi(xv, -AXIS_CAP, AXIS_CAP)
	state[3] = clampi(yv, -AXIS_CAP, AXIS_CAP)
	return events


## True when a ball with its feet at (x, y) rests on a floor surface.
static func _rests_on_floor(grid: TileGrid, x: int, y: int) -> bool:
	var col: int = x >> 4
	var row: int = y >> 4
	if not _is_ball_floor(grid, col, row, grid.floor_at(col, row)):
		return false
	return y == row * Tuning.TILE + grid.surface_offset(col, row, x)


## A floor for the ball: walkable ground, and floor spikes (it bounces off them); never `~` or a kill cell.
static func _is_ball_floor(grid: TileGrid, col: int, row: int, floor_value: int) -> bool:
	if TileGrid.is_ground(floor_value):
		return true
	return floor_value == TileGrid.FLOOR_DEADLY and grid.get_char(col, row) == TileGrid.CH_SPIKES_FLOOR


## The x the ball reaches when its box moves from `x` to `next_x` (feet y = `y`): `next_x` when the leading edge
## crosses no SIDE-1 cell (every column on the way is tested) and stays inside the level, else flush against the
## first wall.
static func _wall_stop(grid: TileGrid, x: int, next_x: int, y: int) -> int:
	var half: int = BOX.z
	var top_row: int = (y - BOX.y) >> 4
	var bottom_row: int = (y - 1) >> 4
	if next_x > x:
		var edge: int = next_x + half - 1
		var last_col: int = mini(edge, grid.width_px() - 1) >> 4
		for col: int in range(((x + half - 1) >> 4) + 1, last_col + 1):
			if _wall_in(grid, col, top_row, bottom_row):
				return col * Tuning.TILE - half
		if edge >= grid.width_px():
			return grid.width_px() - half
	else:
		var edge: int = next_x - half
		var last_col: int = maxi(edge, 0) >> 4
		for col: int in range(((x - half) >> 4) - 1, last_col - 1, -1):
			if _wall_in(grid, col, top_row, bottom_row):
				return (col + 1) * Tuning.TILE + half
		if edge < 0:
			return half
	return next_x


static func _wall_in(grid: TileGrid, col: int, top_row: int, bottom_row: int) -> bool:
	for row: int in range(top_row, bottom_row + 1):
		if grid.side_at(col, row) == TileGrid.SIDE_WALL:
			return true
	return false


## True when a solid ceiling is in `row` over any column the box at feet x spans.
static func _ceiling_over(grid: TileGrid, x: int, row: int) -> bool:
	var left_col: int = (x - BOX.z) >> 4
	var right_col: int = (x + BOX.z - 1) >> 4
	for col: int in range(left_col, right_col + 1):
		if grid.ceiling_at(col, row) == TileGrid.CEILING_SOLID:
			return true
	return false


## A wall or a ceiling reflects a velocity component at 3/4 (GAMEPLAY.md 13.10.6), floored like the floor bounce.
static func _reflect34(v: int) -> int:
	return (-(v * VersusTuning.BALL_BOUNCE_NUM)) >> 2


## Half a velocity component, rounded towards zero (the knock-down rebound).
static func _half(v: int) -> int:
	return v / 2


static func _clamp_axis(v: int) -> int:
	return clampi(v, -AXIS_CAP, AXIS_CAP)


# =================================================================================================================
# Simulation
# =================================================================================================================

func _sim_tick(phase: int) -> void:
	var level: LevelBase = Game.level
	if level == null:
		return
	if not is_active():
		if visible:
			visible = false
		return
	if _reset_left == 0 and not visible:
		visible = true
	match phase:
		Defs.Phase.WEAPONS:
			if in_play():
				_shots(level)
		Defs.Phase.ITEMS:
			_move(level)
		Defs.Phase.CONTACT_ITEMS:
			_follow_knocks(level)
			if in_play():
				_contacts(level)


func _move(level: LevelBase) -> void:
	if _reset_left > 0:
		_reset_left -= 1
		if _reset_left == 0:
			_drop_in()
		return
	var state: PackedInt32Array = PackedInt32Array([sim_pos.x, sim_pos.y, xvel, yvel])
	var events: int = physics_step(level.grid, state)
	sim_pos = Vector2i(state[0], state[1])
	xvel = state[2]
	yvel = state[3]
	if xvel != 0:
		facing = 1 if xvel > 0 else -1
	_roll_px += sim_pos.x - sim_prev.x
	if (events & EV_LOST) != 0:
		_lose(level)
		return
	if (events & EV_FLOOR) != 0 and _flight_slot >= 0:
		var distance: int = absi(sim_pos.x - _flight_from_x)
		var striker: PlayerBase = level.get_hero(_flight_slot)
		if striker != null:
			striker.run.note_shot(distance)
		var slot: int = _flight_slot
		_flight_slot = -1
		shot_landed.emit(slot, distance)
	if (events & EV_BOUNCE) != 0 or ((events & (EV_WALL | EV_CEILING)) != 0
			and (absi(xvel) >= BOUNCE_MIN_YVEL or absi(yvel) >= BOUNCE_MIN_YVEL)):
		ObjTuning.play_cue(Sfx.BOUNCE)


## WEAPONS: the front boxes of the previous tick that touch the ball, summed (see the class description).
func _shots(level: LevelBase) -> void:
	var sum_x: int = 0
	var sum_y: int = 0
	var count: int = 0
	var first_slot: int = -1
	var first_kind: int = SHOT_DRIVE
	var any_charged: bool = false
	var strikers: int = 0
	for hero: PlayerBase in level.contact_order():
		if hero.dead or hero.is_down() or not hero.club_box_active:
			continue
		var weapon: int = hero.run.weapon
		if weapon < 0 or weapon >= Tuning.WEAPON_THROWN.size() or Tuning.WEAPON_THROWN[weapon]:
			continue
		var kind: int = _shot_kind(hero)
		if kind < 0:
			continue
		var slot: int = hero.slot
		if _has_strike_scripts(hero):
			var same_swing: bool = _swing_tick[slot] == Sim.tick - 1
			_swing_tick[slot] = Sim.tick
			if not same_swing:
				_swing_shot[slot] = 0
			elif _swing_shot[slot] != 0:
				continue  # this swing shot the ball already: the box stays for other targets
		if not Overlap.weapon(hero.club_box, hero.club_box_xo, self):
			continue
		_swing_shot[slot] = 1
		hero.club_box_active = false
		strikers |= 1 << hero.slot
		var charged: bool = hero.club_power > Tuning.WEAPON_POWER[weapon]
		var shot: Vector2i = shot_velocity(kind, hero.facing, charged)
		sum_x += shot.x
		sum_y += shot.y
		count += 1
		any_charged = any_charged or charged
		if first_slot < 0 or hero.slot < first_slot:
			first_slot = hero.slot  # the lowest slot is named (versus rotates the contact order)
			first_kind = kind
	if count == 0:
		return
	_rally_step()
	var speed: int = absi(sum_x)
	if speed > 0 and speed < VersusTuning.BALL_MAX_SPEED:
		speed = mini(speed + VersusTuning.RALLY_STEP * rally, VersusTuning.BALL_MAX_SPEED)
	sum_x = speed if sum_x >= 0 else -speed
	_launch(sum_x, sum_y, first_slot, strikers)
	ObjTuning.play_cue(Sfx.CLUB_HIT_HEAVY if any_charged else Sfx.CLUB_HIT)
	level.spawn_fx(&"fx/hit_stars", center())
	shot_made.emit(first_slot, first_kind, any_charged)


## True for a hero with strike scripts (Player.club_frame): his front frames come on consecutive ticks of one swing.
## A bare PlayerBase (tests, stand-ins) has none: each box it is given is a strike of its own.
static func _has_strike_scripts(hero: PlayerBase) -> bool:
	return hero.get(&"club_frame") != null


## The shot kind of a hero's club box: a front frame of a melee weapon (Player.club_frame; a bare PlayerBase counts as
## the forward front frame, as for the referee), else -1.
static func _shot_kind(hero: PlayerBase) -> int:
	var frame: Variant = hero.get(&"club_frame")
	var club_frame: int = Tuning.ClubFrame.FWD_FRONT if frame == null else int(frame)
	match club_frame:
		Tuning.ClubFrame.FWD_FRONT:
			return SHOT_DRIVE
		Tuning.ClubFrame.HIGH_FRONT:
			return SHOT_LOB
		Tuning.ClubFrame.LOW_FRONT:
			return SHOT_GROUNDER
	return -1


## The velocity a shot of `kind` gives (before the rally): drive, lob or grounder by facing; charged x3/2.
static func shot_velocity(kind: int, dir: int, charged: bool) -> Vector2i:
	var v: Vector2i = Vector2i(DRIVE_XVEL, DRIVE_YVEL)
	if kind == SHOT_LOB:
		v = Vector2i(LOB_XVEL, LOB_YVEL)
	elif kind == SHOT_GROUNDER:
		v = Vector2i(GROUNDER_XVEL, 0)
	if charged:
		v = Vector2i(v.x * VersusTuning.BALL_SMASH_NUM / VersusTuning.BALL_SMASH_DEN,
				v.y * VersusTuning.BALL_SMASH_NUM / VersusTuning.BALL_SMASH_DEN)
	return Vector2i(_clamp_axis(v.x * (1 if dir >= 0 else -1)), _clamp_axis(v.y))


## A shot (or a missile) now: the rally counts on when the previous shot is at most RALLY_WINDOW_TICKS old.
func _rally_step() -> void:
	if last_shot_tick >= 0 and Sim.tick - last_shot_tick <= VersusTuning.RALLY_WINDOW_TICKS:
		rally += 1
	else:
		rally = 0
	last_shot_tick = Sim.tick


func _launch(p_xvel: int, p_yvel: int, slot: int, strikers: int) -> void:
	_doze_wake_now()
	xvel = _clamp_axis(p_xvel)
	yvel = _clamp_axis(p_yvel)
	if xvel != 0:
		facing = 1 if xvel > 0 else -1
	shots += 1
	last_touch_slot = slot
	_shooter_mask = strikers
	_flight_slot = slot
	_flight_from_x = sim_pos.x


## CONTACT_ITEMS: missiles, knock-downs and head bounces (one contact per tick).
func _contacts(level: LevelBase) -> void:
	var heroes: Array[PlayerBase] = level.contact_order()
	for hero: PlayerBase in heroes:
		if hero.curl != PlayerBase.CURL_BALL:
			_missile_mask &= ~(1 << hero.slot)  # his flight is over: the next one may pass its speed on again
	for hero: PlayerBase in heroes:
		var bit: int = 1 << hero.slot
		if hero.dead or hero.is_down():
			continue
		if hero.curl == PlayerBase.CURL_BALL:
			if (_missile_mask & bit) == 0 and Overlap.body(hero, self):
				_missile_mask |= bit
				_missile(hero)
				return
			continue
		if hero.is_curled() or not Overlap.body(self, hero):
			continue
		var head: bool = Overlap.stomp and yvel >= 0 and sim_pos.y < hero.sim_pos.y
		if is_fast() and not _in_grace(hero):
			if _knock_down(hero):
				xvel = _clamp_axis(-_half(xvel))
				yvel = _clamp_axis(-_half(yvel))
				return
		if head:
			sim_pos.y = hero.sim_pos.y - hero.box_h
			yvel = mini((-(yvel * VersusTuning.BALL_BOUNCE_NUM)) >> 2, HEAD_BOUNCE_MIN_YVEL)
			last_touch_slot = hero.slot
			_flight_slot = -1
			ObjTuning.play_cue(Sfx.BOUNCE)
			return


## True while the ball is faster than BALL_KNOCKDOWN_SPEED_EXCL on either axis.
func is_fast() -> bool:
	return absi(xvel) > VersusTuning.BALL_KNOCKDOWN_SPEED_EXCL or absi(yvel) > VersusTuning.BALL_KNOCKDOWN_SPEED_EXCL


func _in_grace(hero: PlayerBase) -> bool:
	if (_shooter_mask & (1 << hero.slot)) == 0 or last_shot_tick < 0:
		return false
	return Sim.tick - last_shot_tick <= SHOOTER_GRACE_TICKS


## A batted hero (the missile) passes his velocity on; it counts as a shot of his batter for the rally.
func _missile(hero: PlayerBase) -> void:
	var batter: PlayerBase = hero.ball_batter
	var slot: int = batter.slot if batter != null else hero.slot
	_rally_step()
	_launch(hero.xvel, hero.yvel, slot, (1 << slot) | (1 << hero.slot))
	ObjTuning.play_cue(Sfx.BAT_HIT, Sfx.CLUB_HIT)
	shot_made.emit(slot, SHOT_MISSILE, false)


## The knock-down: the versus hurt (12 stunned ticks; the run's energy is never touched), then [method _follow_knocks]
## ends the immunity as soon as the stun is over. False when the hero ignored it (immune, shielded, dead).
func _knock_down(hero: PlayerBase) -> bool:
	if hero.is_immune() or hero.shield > 0:
		return false
	var run: PlayerRun = hero.run
	var hearts: int = run.hearts
	var bones: int = run.bones
	var glider: bool = run.has_glider
	if run.hearts < 2:
		run.hearts = 2  # the 1.0 hurt path must never kill: the coconut costs nothing
	var applied: bool = hero.hurt(self, Defs.HurtKind.RIVAL)
	run.hearts = hearts
	run.bones = bones
	if run.has_glider != glider:
		run.set_glider(glider)
	run.emit_energy()
	if not applied or hero.dead:
		return false
	_knock_mark[hero.slot] = hero.hit_timer
	knockdowns += 1
	knocked_down.emit(hero)
	return true


## "12 stunned ticks, no immunity": once the hit_timer a knock-down left falls under the stun threshold
## (VersusTuning.STUN_HIT_TIMER_MIN) it is cleared; a new hit in between (the timer rose again) keeps its own timing.
func _follow_knocks(level: LevelBase) -> void:
	for slot: int in Defs.MAX_PLAYERS:
		var mark: int = _knock_mark[slot]
		if mark < 0:
			continue
		var hero: PlayerBase = level.get_hero(slot)
		if hero == null or hero.dead or hero.hit_timer <= 0 or hero.hit_timer > mark:
			_knock_mark[slot] = -1
			continue
		if hero.hit_timer < VersusTuning.STUN_HIT_TIMER_MIN:
			hero.hit_timer = 0
			_knock_mark[slot] = -1
		else:
			_knock_mark[slot] = hero.hit_timer


func _lose(level: LevelBase) -> void:
	var at: Vector2i = sim_pos
	if level.grid.get_char(at.x >> 4, at.y >> 4) == TileGrid.CH_LIQUID:
		level.spawn_fx(&"fx/splash", Vector2i(at.x, Tuning.tile_top(at.y) + 2), {"kind": "water"})
		ObjTuning.play_cue(Sfx.SPLASH)
	reset_after(VersusTuning.BALL_RESET_TICKS)
	lost.emit()


## Back in play: DROP_IN_PX over the drop point (lower under a solid cell), at rest, falling in.
func _drop_in() -> void:
	var grid: TileGrid = Game.level.grid if Game.level != null else null
	var y: int = drop_point.y
	var rise: int = 0
	while grid != null and rise < DROP_IN_PX:
		var top_row: int = (y - rise - Tuning.TILE - BOX.y) >> 4
		if grid.side_at(drop_point.x >> 4, top_row) == TileGrid.SIDE_WALL \
				or grid.ceiling_at(drop_point.x >> 4, top_row) == TileGrid.CEILING_SOLID:
			break
		rise += Tuning.TILE
	teleport(Vector2i(drop_point.x, y - rise))
	xvel = 0
	yvel = 0
	rally = 0
	last_shot_tick = -1
	last_touch_slot = -1
	_shooter_mask = 0
	_flight_slot = -1
	visible = true
	_refresh_look()


func _on_level_reset() -> void:
	_reset_left = 0
	_missile_mask = 0
	_knock_mark.fill(-1)
	_swing_tick.fill(-1)
	_swing_shot.fill(0)
	teleport(drop_point)
	xvel = 0
	yvel = 0
	rally = 0
	last_shot_tick = -1
	last_touch_slot = -1
	_shooter_mask = 0
	_flight_slot = -1
	visible = true


## Dozing: never while it moves or waits to drop in (an arena is one screen, so it never dozes there anyway).
func _doze_area() -> Rect2i:
	return _doze_box()


func _can_doze() -> bool:
	return in_play() and xvel == 0 and yvel == 0 and _rests_on_floor_now()


func _rests_on_floor_now() -> bool:
	return Game.level != null and _rests_on_floor(Game.level.grid, sim_pos.x, sim_pos.y)


# =================================================================================================================
# Picture
# =================================================================================================================

func _process(_delta: float) -> void:
	if _sprite != null and visible:
		_refresh_look()


## The roll picture (sheet column by the px rolled, or a turn of the fallback icon) and the golden look. Cosmetic.
func _refresh_look() -> void:
	if _sprite == null:
		return
	if _own_sheet:
		# Clockwise quarter turns: forwards while it rolls right, backwards while it rolls left (art-A's sheet).
		var column: int = posmod(floori(float(_roll_px) / float(ROLL_STEP_PX)), OWN_SHEET_COLUMNS)
		_sprite.frame = (OWN_SHEET_COLUMNS if golden else 0) + column
		_sprite.modulate = Color.WHITE
	else:
		_sprite.rotation = float(_roll_px) / float(BOX.x >> 1)
		_sprite.modulate = GOLD_TINT if golden else Color.WHITE
