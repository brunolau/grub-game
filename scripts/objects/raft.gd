class_name Raft
extends PlatformBase
## `objects/raft` (`width=3|4` [3], `skin=log|wafer`, `rails`): a sprite platform floating on `~` (DESIGN.md C.5,
## PHYSICS.md C.7, GAMEPLAY.md 13.3). Placed on the top `~` row; it is `16 * width` x Tuning.RAFT_HEIGHT_PX px and
## floats with its bottom Tuning.RAFT_FLOAT_DEPTH_PX below the top of that cell. Riding uses the platform rules
## (PHYSICS.md 11.4, PlatformBase). State: its own speed `rx` (v16, within +/- Tuning.RAFT_SPEED_CAP) and the drift
## `cd` (px/tick) of the current it is in. Per tick in PLATFORMS, before the ride test:
##   0. paddling: a rider who finished a forward strike on the previous tick pushes it backward by
##      Tuning.RAFT_PADDLE_V16 (rx -= 16 * facing, clamped);
##   1. current: while its anchor (bottom centre) is inside a `zones/current` with dir l|r, cd = +/-speed; on the tick
##      it leaves every current, rx = clamp(rx + 16 * cd) and cd = 0 (it keeps its momentum);
##   2. drag: every Tuning.RAFT_DRAG_PERIOD-th tick of its own move counter, |rx| -= 16 towards 0;
##   3. move: dx = floor16(rx) + cd; a leading edge entering a SIDE-1 cell, or a floor cell that is not `~`, in its
##      surface row (a bank) stops it (dx = 0, rx = 0).
## A geyser spout ([method launch]) throws it up with its riders: it flies (gravity 16, cap 192) and settles on the
## first `~` surface (floating again) or floor cell (beached: rx = 0, currents ignored) under its anchor. `rails` (The
## Long Raft Home): a hero whose last floor contact was this raft has his x commit fenced to the raft
## (PlayerBase.fence_x, airborne too): nobody leaves it. Each rider dips the picture 2 px (drawing only).
##
## Owner: objects-B (docs/expansion/PLAN.md 4.1). Currents are world-A's zones; the raft finds them by their spawn
## parameters (a Kind.ZONE entity with `dir` l|r|u|d, its rectangle ZoneBase.rect, its speed the zone's `speed`
## (CurrentZone: the parameter, clamped, default 1) or the `speed` parameter) and applies C.7 itself. It looks again
## whenever the level's zones change, so a current spawned during play (Inkjaw's whirlpool) carries rafts that were
## already afloat. A level reset (death, team wipe) puts it back where the level placed it.

const DEFAULT_SKIN: String = "log"
## Picture: sprites/objects/raft.png (ASSET_MANIFEST 17.3): 1 x 4 cells of 128 x 24 art px (rows log w3, log w4,
## wafer w3, wafer w4), pivot (64, 0) = the top-centre = the ride surface; each rider dips it RAFT_DIP_PX.
const SHEET: Texture2D = preload("res://assets/sprites/objects/raft.png")
const CELL_ART: Vector2 = Vector2(128, 24)

## Cells (3 or 4).
var width: int = 3
## log (wood) or wafer (Feast Land).
var skin: String = DEFAULT_SKIN
## True: riders cannot leave it (C.7 `rails`).
var rails: bool = false
## Own speed, v16 (paddling, momentum out of a current), within +/- Tuning.RAFT_SPEED_CAP.
var rx: int = 0
## Drift of the current it is in, px per tick (signed; 0 outside every current).
var cd: int = 0
## True while it flies after a geyser launch.
var flying: bool = false
## True once it settled on a floor instead of `~`: it stays there (rx = 0, currents ignored).
var beached: bool = false
## The `~` row it floats in (its surface row for the bank test).
var surface_row: int = 0
## Paddle pushes it took (statistics, tests).
var paddles: int = 0

var _home: Vector2i = Vector2i.ZERO
var _home_row: int = 0
var _moves: int = 0
## Bit per slot: the hero's last floor contact was this raft (rails).
var _railed_mask: int = 0
## Bit per slot: the end of a forward strike was already counted (edge detection of the paddle).
var _paddle_seen_mask: int = 0
var _currents: Array[SimEntity] = []
var _currents_found: bool = false
## The number of the level's zones when [member _currents] was collected: another number means a zone came or went.
var _zone_count: int = -1
var _drawn_riders: int = 0
var _sprite: Sprite2D = null


func _init() -> void:
	super()
	z_index = Defs.Z_PLATFORMS
	_set_width(width)


func _set_width(cells: int) -> void:
	width = cells if Tuning.RAFT_WIDTHS.has(cells) else Tuning.RAFT_WIDTHS[0]
	box_w = Tuning.TILE * width
	box_xo = box_w / 2
	box_h = Tuning.RAFT_HEIGHT_PX


func _apply_params(params: Dictionary) -> void:
	_set_width(int(params.get("width", width)))
	skin = str(params.get("skin", skin))
	if skin != "log" and skin != "wafer":
		skin = DEFAULT_SKIN
	rails = param_bool("rails", false)
	# Placed in the top `~` cell: the loader's feet point is that cell's bottom; it floats 4 px into the cell.
	_home_row = (sim_pos.y - 1) >> 4
	_home = Vector2i(sim_pos.x, _home_row * Tuning.TILE + Tuning.RAFT_FLOAT_DEPTH_PX)
	teleport(_home)
	_reset_state()


func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.texture = SHEET
	_sprite.centered = false
	_sprite.offset = Vector2(-CELL_ART.x / 2.0, 0.0)
	_sprite.vframes = maxi(int(SHEET.get_height() / CELL_ART.y), 1)
	_sprite.frame = mini((2 if skin == "wafer" else 0) + (1 if width == 4 else 0), _sprite.vframes - 1)
	add_child(_sprite)
	_refresh_look()


func _reset_state() -> void:
	surface_row = _home_row
	rx = 0
	cd = 0
	yvel = 0
	flying = false
	beached = false
	_moves = 0
	_railed_mask = 0
	_paddle_seen_mask = 0
	_refresh_look()


func _on_level_reset() -> void:
	teleport(_home)
	ridden = false
	rider_mask = 0
	_reset_state()


# --- Calls ------------------------------------------------------------------------------------------------------------

## A geyser spout (PHYSICS.md C.6): it flies with `power` (v16, up) and so does every hero riding it (same tick).
func launch(power: int) -> void:
	_doze_wake_now()
	var level: LevelBase = Game.level
	if level != null:
		for hero: PlayerBase in level.contact_order():
			if (rider_mask & (1 << hero.slot)) != 0 and not hero.dead and not hero.is_down():
				hero.launch(PlayerBase.LAUNCH_KEEP, power)
	rx = clampi(rx + Tuning.V16_PER_PX * cd, -Tuning.RAFT_SPEED_CAP, Tuning.RAFT_SPEED_CAP)
	cd = 0
	yvel = power
	flying = true
	beached = false


## Push it by one paddle stroke of a hero facing `facing` (the forward strike pushes backward).
func paddle(facing: int) -> void:
	rx = clampi(rx - Tuning.RAFT_PADDLE_V16 * signi(facing), -Tuning.RAFT_SPEED_CAP, Tuning.RAFT_SPEED_CAP)
	paddles += 1
	if on_screen:
		Audio.play_sfx(Sfx.RAFT_SPLASH if AudioTable.SFX.has(Sfx.RAFT_SPLASH) else Sfx.SPLASH)


## Left and right end (exclusive) of the x a railed hero may have (C.7: raft.x - 8 * width + 8 ..
## raft.x + 8 * width - 8).
func rail_left() -> int:
	return sim_pos.x - Tuning.TILE / 2 * width + Tuning.TILE / 2


func rail_right_excl() -> int:
	return sim_pos.x + Tuning.TILE / 2 * width - Tuning.TILE / 2 + 1


# --- Simulation -------------------------------------------------------------------------------------------------------

func _sim_tick(phase: int) -> void:
	super._sim_tick(phase)
	if phase == Defs.Phase.PLATFORMS:
		_update_rails()
		var riders: int = rider_count()
		if riders != _drawn_riders:
			_drawn_riders = riders
			_refresh_look()


func _move_tick() -> void:
	var level: LevelBase = Game.level
	if level == null:
		return
	_paddle_pass(level)
	if flying:
		_fly(level)
		return
	if beached:
		rx = 0
		cd = 0
		return
	# 1. Current.
	var drift: int = _current_drift(level)
	if drift != 0:
		cd = drift
	elif cd != 0:
		rx = clampi(rx + Tuning.V16_PER_PX * cd, -Tuning.RAFT_SPEED_CAP, Tuning.RAFT_SPEED_CAP)
		cd = 0
	# 2. Drag.
	_moves += 1
	if _moves % Tuning.RAFT_DRAG_PERIOD == 0 and rx != 0:
		rx = maxi(rx - Tuning.V16_PER_PX, 0) if rx > 0 else mini(rx + Tuning.V16_PER_PX, 0)
	# 3. Move, unless a bank stops it.
	var step: int = Tuning.floor16(rx) + cd
	if step != 0 and _bank_ahead(level.grid, step):
		step = 0
		rx = 0
	dx = step


## A rider who finished a forward strike on the previous tick paddles (edge-triggered per hero).
func _paddle_pass(level: LevelBase) -> void:
	for hero: PlayerBase in level.contact_order():
		var bit: int = 1 << hero.slot
		var done: bool = (rider_mask & bit) != 0 and _finished_forward_strike(hero)
		if done and (_paddle_seen_mask & bit) == 0:
			paddle(hero.facing)
		if done:
			_paddle_seen_mask |= bit
		else:
			_paddle_seen_mask &= ~bit


## True when `hero`'s last PLAYER phase was the last tick of a forward strike (Player.handler / strike_tick).
static func _finished_forward_strike(hero: PlayerBase) -> bool:
	if hero.dead or hero.is_down():
		return false
	var handler: Variant = hero.get(&"handler")
	var strike_tick: Variant = hero.get(&"strike_tick")
	if handler == null or strike_tick == null:
		return false
	return int(handler) == Defs.HeroState.STRIKE and int(strike_tick) == Tuning.STRIKE_SCRIPT_FORWARD.size()


## The px/tick drift of the l|r current its anchor is in (0 = none).
func _current_drift(level: LevelBase) -> int:
	var zones: Array[SimEntity] = level.get_kind(Defs.Kind.ZONE)
	if not _currents_found or zones.size() != _zone_count:
		_find_currents(zones)
	for zone: SimEntity in _currents:
		if not is_instance_valid(zone) or zone.is_queued_for_deletion():
			continue
		var rect: Variant = zone.get(&"rect")
		if rect is Rect2i and Overlap.point_in(rect, sim_pos.x, sim_pos.y):
			var dir: String = str(zone.spawn_params.get("dir", ""))
			var speed: int = int(zone.get(&"speed")) if &"speed" in zone else int(zone.spawn_params.get("speed", 1))
			speed = clampi(speed, Tuning.CURRENT_SPEED_MIN_PX, Tuning.CURRENT_SPEED_MAX_PX)
			if dir.begins_with("r"):
				return speed
			if dir.begins_with("l"):
				return -speed
	return 0


## Every current among the level's `zones` (a CurrentZone, or any Kind.ZONE with `dir` and `speed` parameters),
## collected during a tick and again whenever the number of zones changes.
func _find_currents(zones: Array[SimEntity]) -> void:
	_currents_found = Sim.is_in_tick()
	_zone_count = zones.size()
	_currents.clear()
	for zone: SimEntity in zones:
		if zone is CurrentZone or (zone.spawn_params.has("dir") and zone.spawn_params.has("speed")):
			_currents.append(zone)


## True when moving `step` px would put its leading edge into a bank in its surface row.
func _bank_ahead(grid: TileGrid, step: int) -> bool:
	var half: int = Tuning.TILE / 2 * width
	var edge: int = sim_pos.x + half - 1 + step if step > 0 else sim_pos.x - half + step
	var col: int = edge >> 4
	if grid.side_at(col, surface_row) == TileGrid.SIDE_WALL:
		return true
	return grid.floor_at(col, surface_row) != TileGrid.FLOOR_EMPTY \
			and grid.get_char(col, surface_row) != TileGrid.CH_LIQUID


## Flight after a geyser launch: gravity until it settles on `~` (floating) or a floor (beached) under its anchor.
func _fly(level: LevelBase) -> void:
	var grid: TileGrid = level.grid
	dx = Tuning.floor16(rx)
	dy = Tuning.floor16(yvel)
	yvel = mini(yvel + Tuning.GRAVITY, Tuning.TERMINAL)
	if dy <= 0:
		return
	var col: int = sim_pos.x >> 4
	var new_y: int = sim_pos.y + dy
	var row: int = sim_pos.y >> 4
	while row <= (new_y >> 4) + 1:
		if grid.get_char(col, row) == TileGrid.CH_LIQUID:
			var float_y: int = row * Tuning.TILE + Tuning.RAFT_FLOAT_DEPTH_PX
			if new_y >= float_y and sim_pos.y <= float_y:
				_settle(float_y - sim_pos.y, row, false)
				return
		elif TileGrid.is_ground(grid.floor_at(col, row)):
			var floor_y: int = row * Tuning.TILE
			if new_y >= floor_y and sim_pos.y <= floor_y:
				_settle(floor_y - sim_pos.y, row, true)
				return
		row += 1
	if sim_pos.y > grid.height_px() + Tuning.PIT_DEPTH_PX:
		flying = false
		beached = true
		dy = 0


func _settle(fall: int, row: int, on_floor: bool) -> void:
	dy = fall
	yvel = 0
	flying = false
	surface_row = row
	beached = on_floor
	if on_floor:
		rx = 0
	if on_screen:
		Audio.play_sfx(Sfx.RAFT_SPLASH if AudioTable.SFX.has(Sfx.RAFT_SPLASH) else Sfx.SPLASH)


## Rails: fence every hero whose last floor contact was this raft (after the ride test, before PLAYER).
func _update_rails() -> void:
	if not rails:
		return
	var level: LevelBase = Game.level
	if level == null:
		return
	for hero: PlayerBase in level.contact_order():
		var bit: int = 1 << hero.slot
		if (rider_mask & bit) != 0:
			_railed_mask |= bit
		elif hero.dead or hero.is_down() or hero.carried_on_tick == Sim.total_ticks or _stands_on_floor(level, hero):
			# Another platform carried him, or his feet stand on a floor tile: his last floor contact is not this raft.
			_railed_mask &= ~bit
		if (_railed_mask & bit) != 0:
			hero.fence_x(rail_left(), rail_right_excl())


static func _stands_on_floor(level: LevelBase, hero: PlayerBase) -> bool:
	return hero.grounded and hero.yvel == 0 \
			and TileGrid.is_ground(level.grid.floor_at(hero.sim_pos.x >> 4, hero.sim_pos.y >> 4))


## Dozing: a raft at rest outside every current changes nothing per tick.
func _doze_area() -> Rect2i:
	return _doze_box()


func _can_doze() -> bool:
	return rx == 0 and cd == 0 and not flying and not rails and (beached or _current_drift_cached() == 0)


func _current_drift_cached() -> int:
	return _current_drift(Game.level) if Game.level != null else 0


# --- Picture ----------------------------------------------------------------------------------------------------------

## The deck on the ride surface, dipped 2 px per rider (drawing only).
func _refresh_look() -> void:
	if _sprite == null:
		return
	var surface_art: float = float(-box_h * Tuning.ART_SCALE)
	_sprite.position = Vector2(0.0, surface_art + float(Tuning.RAFT_DIP_PX * rider_count() * Tuning.ART_SCALE))
