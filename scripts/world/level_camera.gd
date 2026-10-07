class_name LevelCamera
extends RefCounted
## The camera of PHYSICS.md 12 as integer logic in logical px. Owner: world.
##
## It knows nothing about nodes: the level calls [method tick] once per simulation tick (phase CAMERA) and draws
## the view between [member prev] and [member pos]. Horizontally the authentic camera pages in whole tiles
## (12.1); vertically it follows a row window with one of two speed curves (12.2); look-around (12.3), locks
## (12.4), the spawn placement (12.5) and the optional smooth follow (12.6) are all here.
##
## Variable view (PHYSICS.md 15.3, ARCHITECTURE.md 8.5): every threshold is relative to the visible tile counts
## `cols = ceil(view_w / 16)` and `rows = floor(view_h / 16)`; with the original 20 x 11 the numbers are exactly
## those of the specification. When the level (or a lock rectangle) is smaller than the view in an axis the
## camera is centred on it in that axis and does not move.

const DIR_IDLE: int = 0
const DIR_RIGHT: int = 1
const DIR_LEFT: int = 2
## Upper bound of the settle loop of [method snap] (a 256 x 192 map needs far fewer steps).
const SNAP_GUARD: int = 1024

## Top-left corner of the view in logical px at the end of this tick.
var pos: Vector2i = Vector2i.ZERO
## Top-left corner at the end of the previous tick (render interpolation).
var prev: Vector2i = Vector2i.ZERO
## Size of the view in logical px.
var view: Vector2i = Vector2i(Tuning.VIEW_W, Tuning.VIEW_H)
## Visible tile columns (20 in the original).
var cols: int = Tuning.VIEW_COLS
## Visible tile rows (11 in the original).
var rows: int = Tuning.VIEW_ROWS
## The level rectangle in logical px.
var bounds: Rect2i = Rect2i(0, 0, Tuning.VIEW_W, Tuning.VIEW_H)
## Defs.SCROLL_* bits of the level.
var scroll_flags: int = 0
## Auto-scrolling levels: true while the descent waits for the player's first input (Level, after the level start
## and after a respawn). The view stays where it is meanwhile.
var autoscroll_held: bool = false
## Camera home row of PHYSICS.md 12.2 #6 (-1 = none).
var home_row: int = -1
## True = the second (fast) vertical speed curve: a backdrop shows through the tile layer.
var fast: bool = true
## True = the comfort camera of PHYSICS.md 12.6 instead of the paging one.
var smooth: bool = false
## Paging state: DIR_IDLE, DIR_RIGHT or DIR_LEFT.
var h_dir: int = DIR_IDLE
## The `active` counter of the vertical follow.
var v_active: int = 0
## The stored target row of the vertical follow.
var v_target: int = 0

## 2.0 tribe camera (PHYSICS.md C.13, [method tick_group]): the heroes of H this tick (scratch, reused), the group
## step counter and, per player slot, the last group step on which that hero had ground, a platform or a partner
## under his feet (the vertical anchor), and the slot of the anchor of the last step (-1 = none).
var _tribe: Array[PlayerBase] = []
var _group_ticks: int = 0
var _ground_step: PackedInt32Array = PackedInt32Array([0, 0, 0, 0])
var anchor_slot: int = -1

var _locked: bool = false
var _lock_rect: Rect2i = Rect2i()
var _min: Vector2i = Vector2i.ZERO
var _max: Vector2i = Vector2i.ZERO
var _look_hold: bool = false
# Vertical thresholds and targets for the current number of rows (PHYSICS.md 12.2 #3 scaled by rows / 11).
var _air_low_sr: int = Tuning.CAM_V_AIR_LOW_SR
var _air_low_target: int = Tuning.CAM_V_AIR_LOW_TARGET
var _air_high_sr: int = Tuning.CAM_V_AIR_HIGH_SR
var _air_high_target: int = Tuning.CAM_V_AIR_HIGH_TARGET
var _ground_low_sr: int = Tuning.CAM_V_GROUND_LOW_SR
var _ground_low_target: int = Tuning.CAM_V_GROUND_LOW_TARGET
var _ground_high_sr: int = Tuning.CAM_V_GROUND_HIGH_SR
var _ground_high_target: int = Tuning.CAM_V_GROUND_HIGH_TARGET
var _alt_low_sr: int = Tuning.CAM_V_ALT_LOW_SR
var _alt_low_target: int = Tuning.CAM_V_ALT_LOW_TARGET
var _alt_high_sr: int = Tuning.CAM_V_ALT_HIGH_SR
var _alt_high_target: int = Tuning.CAM_V_ALT_HIGH_TARGET


## Set the level rectangle (logical px).
func set_bounds(level_rect: Rect2i) -> void:
	bounds = level_rect
	_update_limits()


## Set the view from the size of the root viewport in art px. Returns true when the size changed.
func set_view_art(size_art: Vector2i) -> bool:
	var scale: int = Tuning.ART_SCALE
	var new_view: Vector2i = Vector2i(
		maxi((size_art.x + scale - 1) / scale, Tuning.TILE), maxi((size_art.y + scale - 1) / scale, Tuning.TILE)
	)
	if new_view == view:
		return false
	view = new_view
	var tile_art: int = Tuning.TILE_ART
	cols = maxi((size_art.x + tile_art - 1) / tile_art, 1)
	rows = maxi(size_art.y / tile_art, 1)
	_scale_rows()
	_update_limits()
	# A resized window never scrolls into place: the view is clamped at once.
	pos = pos.clamp(_min, _max)
	prev = pos
	return true


## The view rectangle in logical px.
func get_rect() -> Rect2i:
	return Rect2i(pos, view)


## Camera cell of PHYSICS.md 12: the tile that contains the top-left corner of the view.
func get_cell() -> Vector2i:
	return Vector2i(Tuning.to_cell(pos.x), Tuning.to_cell(pos.y))


## Restrict the camera to `view_px` (PHYSICS.md 12.4). A rectangle no larger than the view fixes the camera
## (single-screen rooms, boss rooms); a larger one keeps the follow rules inside it. A camera that is outside
## glides in at one tile per tick; call [method snap] instead after a teleport.
func lock(view_px: Rect2i) -> void:
	_locked = true
	_lock_rect = view_px
	_update_limits()


## Release the lock: the level rectangle limits the camera again.
func unlock() -> void:
	if not _locked:
		return
	_locked = false
	_update_limits()


## Smallest allowed top-left corner (equal to [method get_max] in an axis the camera cannot move in).
func get_min() -> Vector2i:
	return _min


## Largest allowed top-left corner.
func get_max() -> Vector2i:
	return _max


## One camera step (phase CAMERA). `hero` may be null; the view does not follow a dead hero.
func tick(hero: PlayerBase) -> void:
	prev = pos
	if hero == null or hero.dead:
		return
	var step: int = Tuning.CAM_STEP_PX
	if pos.x < _min.x:
		pos.x = mini(pos.x + step, _min.x)
	elif pos.x > _max.x:
		pos.x = maxi(pos.x - step, _max.x)
	elif _follows_x():
		if smooth:
			_follow_x_smooth(hero)
		else:
			_follow_x(hero)
	if pos.y < _min.y:
		pos.y = mini(pos.y + step, _min.y)
	elif pos.y > _max.y:
		pos.y = maxi(pos.y - step, _max.y)
	elif _min.y < _max.y:
		_follow_y(hero, 0)


## Place the camera for a hero who just appeared (level start, respawn, gate): PHYSICS.md 12.5. Starts at the
## top-left limit, runs the follow rules with a fixed 16 px vertical step until both axes are idle, then shifts
## right by half a view when the hero would otherwise stand in its right part. Nothing is interpolated.
func snap(hero: PlayerBase) -> void:
	_update_limits()
	h_dir = DIR_IDLE
	v_active = 0
	v_target = 0
	_look_hold = false
	pos = _min
	if hero != null:
		if smooth and _follows_x():
			pos.x = clampi(hero.sim_pos.x - view.x / 2, _min.x, _max.x) & ~1
		for i: int in SNAP_GUARD:
			if _follows_x() and not smooth:
				_follow_x(hero)
			if _min.y < _max.y:
				_follow_y(hero, Tuning.CAM_SPAWN_V_STEP)
			if h_dir == DIR_IDLE and v_active == 0:
				break
		if _follows_x() and not smooth:
			var sc: int = Tuning.to_cell(hero.sim_pos.x) - Tuning.to_cell(pos.x)
			if sc >= cols * Tuning.CAM_SPAWN_SHIFT_MIN_SC / Tuning.VIEW_COLS:
				for i: int in cols * Tuning.CAM_SPAWN_SHIFT_MAX_COLS / Tuning.VIEW_COLS:
					_step_right()
	h_dir = DIR_IDLE
	v_active = 0
	prev = pos


# =================================================================================================================
# 2.0: the tribe camera of a party (PHYSICS.md C.13, DESIGN.md D.2; TECH_AUDIT.md 4.5 option B)
# =================================================================================================================

## One step of the tribe camera (phase CAMERA, co-op), for `heroes` = the heroes of the party in slot order. It works
## on H, the heroes that are alive and hatched (not dead, not in a death toss, not an egg):
##  - |H| = 0: the view holds still; |H| = 1: PHYSICS.md 12.1-12.3 exactly on that hero (always the paging camera);
##  - |H| >= 2, horizontally (replaces 12.1): standing still never moves the view; it pages right when a hero moving
##    right reaches the start column (16 of 20) while the rear hero is at column 2 or more, left at column 4 while the
##    rear (right-most) hero is at 17 or less; it stops when the front hero is back at the stop column (5 / 15) or the
##    rear hero reaches the margin (1 / 18) or the limit. A hero in the look pose claims the camera: its look-around
##    steps (12.3) are refused when they would put another hero of H at column < 1 or > 18;
##  - vertically 12.2 runs on the anchor ([member anchor_slot]): the hero of H who most recently had ground, a
##    platform or a partner under his feet (ties: the lower slot), or the hero in the look pose. A jumping or falling
##    hero never drags the view while his partner stands.
## Column thresholds are relative to this camera's columns, as in 12.1 (the party plays on the authentic 20 x 11 view).
func tick_group(heroes: Array[PlayerBase]) -> void:
	prev = pos
	_group_ticks += 1
	_collect_tribe(heroes)
	if _tribe.is_empty():
		anchor_slot = -1
		return
	var looker: PlayerBase = _group_looker()
	var anchor: PlayerBase = looker if looker != null else _group_anchor()
	anchor_slot = anchor.slot
	var step: int = Tuning.CAM_STEP_PX
	if pos.x < _min.x:
		pos.x = mini(pos.x + step, _min.x)
	elif pos.x > _max.x:
		pos.x = maxi(pos.x - step, _max.x)
	elif _follows_x():
		if _tribe.size() == 1:
			_follow_x(_tribe[0])
		elif looker != null:
			_look_group(looker)
		else:
			_follow_x_group()
	if pos.y < _min.y:
		pos.y = mini(pos.y + step, _min.y)
	elif pos.y > _max.y:
		pos.y = maxi(pos.y - step, _max.y)
	elif _min.y < _max.y:
		_follow_y(anchor, 0)


## Place the tribe camera for a party that just appeared (level start, team-wipe respawn, gate): PHYSICS.md 12.5 on
## the first hero of H in slot order (P1 when he is hatched; the first hero of `heroes` when none is), then the
## tribe rules (C.12: "the camera of 12.5 on P1 and the tribe rules"). The anchor history starts afresh.
func snap_group(heroes: Array[PlayerBase]) -> void:
	_collect_tribe(heroes)
	var first: PlayerBase = null
	if not _tribe.is_empty():
		first = _tribe[0]
	else:
		for hero: PlayerBase in heroes:
			if hero != null:
				first = hero
				break
	_group_ticks = 0
	_ground_step.fill(0)
	anchor_slot = first.slot if first != null else -1
	snap(first)


## The camera cell rectangle in logical px: the view's columns and rows (whole tiles) at the camera cell. For the
## tribe camera this is the authentic 20 x 11-cell view of PHYSICS.md C.13 (edge walls, leash, egg clamp).
func cell_rect() -> Rect2i:
	return Rect2i(get_cell() * Tuning.TILE, Vector2i(cols, rows) * Tuning.TILE)


## The visible camera of a party follows the tribe camera (2.0): the view `frame` (logical px, the tribe camera's
## get_rect()) centred in this camera's view and kept inside its limits. With the authentic view size both are the
## same rectangle. `jump` = no interpolation from the previous position (a snap).
func follow_frame(frame: Rect2i, jump: bool = false) -> void:
	prev = pos
	h_dir = DIR_IDLE
	v_active = 0
	pos = (frame.position - (view - frame.size) / 2).clamp(_min, _max)
	if jump:
		prev = pos


## 2.0 `scroll = rising` (PHYSICS.md C.8), after this tick's follow step: the top of the view becomes
## min(follow, band_top + 16 - rows * 16, the previous top) - it never sinks, rises at least with the band (whose top
## row is then the view's bottom row) and faster when a hero climbs ahead. Never above the level's top limit.
func apply_rising(band_top: int) -> void:
	var limit: int = band_top + Tuning.TILE - rows * Tuning.TILE
	pos.y = maxi(mini(pos.y, mini(limit, prev.y)), _min.y)


func _collect_tribe(heroes: Array[PlayerBase]) -> void:
	_tribe.clear()
	for hero: PlayerBase in heroes:
		if hero == null or hero.dead or hero.is_down():
			continue
		_tribe.append(hero)
		if hero.is_grounded():
			_ground_step[clampi(hero.slot, 0, _ground_step.size() - 1)] = _group_ticks


## The first hero of H (slot order) standing in the look pose (12.3: on the ground, not on a platform, no motion).
func _group_looker() -> PlayerBase:
	for hero: PlayerBase in _tribe:
		if hero.looking and hero.xvel == 0 and not hero.on_platform:
			return hero
	return null


## The hero of H with the latest group step on which he had ground under his feet (ties: the lower slot).
func _group_anchor() -> PlayerBase:
	var best: PlayerBase = _tribe[0]
	var best_step: int = _ground_step[clampi(best.slot, 0, _ground_step.size() - 1)]
	for i: int in range(1, _tribe.size()):
		var hero: PlayerBase = _tribe[i]
		var step: int = _ground_step[clampi(hero.slot, 0, _ground_step.size() - 1)]
		if step > best_step:
			best = hero
			best_step = step
	return best


## Group paging of C.13 (see [method tick_group]).
func _follow_x_group() -> void:
	var cam_col: int = Tuning.to_cell(pos.x)
	var rear: int = 1 << 30   # L: the left-most screen column of H
	var front: int = -(1 << 30)   # Rr: the right-most
	var moving: bool = false
	for hero: PlayerBase in _tribe:
		var sc: int = Tuning.to_cell(hero.sim_pos.x) - cam_col
		rear = mini(rear, sc)
		front = maxi(front, sc)
		if hero.xvel != 0 or hero.on_platform:
			moving = true
	if not moving:
		h_dir = DIR_IDLE
		return
	var margin_left: int = PartyTuning.CAM_REAR_MARGIN_COL
	var margin_right: int = cols - (Tuning.VIEW_COLS - PartyTuning.CAM_REAR_MARGIN_COL_LEFT)
	match h_dir:
		DIR_IDLE:
			var start_right: int = cols - (Tuning.VIEW_COLS - PartyTuning.CAM_FRONT_START_COL)
			var start_left: int = PartyTuning.CAM_FRONT_START_COL_LEFT
			if rear > margin_left:
				for hero: PlayerBase in _tribe:
					var sc: int = Tuning.to_cell(hero.sim_pos.x) - cam_col
					if _group_dir(hero, sc) > 0 and sc >= start_right:
						h_dir = DIR_RIGHT
						return
			if front < margin_right:
				for hero: PlayerBase in _tribe:
					var sc: int = Tuning.to_cell(hero.sim_pos.x) - cam_col
					if _group_dir(hero, sc) < 0 and sc <= start_left:
						h_dir = DIR_LEFT
						return
		DIR_RIGHT:
			if front <= PartyTuning.CAM_FRONT_STOP_COL or rear <= margin_left or pos.x >= _max.x:
				h_dir = DIR_IDLE
			else:
				_step_right()
		DIR_LEFT:
			var stop_left: int = cols - (Tuning.VIEW_COLS - PartyTuning.CAM_FRONT_STOP_COL_LEFT)
			if rear >= stop_left or front >= margin_right or pos.x <= _min.x:
				h_dir = DIR_IDLE
			else:
				_step_left()


## Direction a hero of H moves in for the paging decision: by xvel; on a platform with xvel == 0 right from the
## middle column on (12.1); 0 = standing (he starts nothing).
func _group_dir(hero: PlayerBase, sc: int) -> int:
	if hero.xvel > 0:
		return 1
	if hero.xvel < 0:
		return -1
	if hero.on_platform:
		return 1 if sc >= cols * Tuning.CAM_IDLE_SPLIT / Tuning.VIEW_COLS else -1
	return 0


## Look-around (12.3) by `looker` with the other heroes of H kept on the view (C.13).
func _look_group(looker: PlayerBase) -> void:
	var cam_col: int = Tuning.to_cell(pos.x)
	var sc: int = Tuning.to_cell(looker.sim_pos.x) - cam_col
	if looker.facing > 0:
		if sc > Tuning.CAM_LOOK_MIN_SC and _others_stay(looker, cam_col + 1):
			_step_right()
	elif sc < cols - (Tuning.VIEW_COLS - Tuning.CAM_LOOK_MAX_SC) and _others_stay(looker, cam_col - 1):
		_step_left()
	h_dir = DIR_IDLE


## True when every hero of H but `looker` would stay within the margin columns with the camera at `new_col`.
func _others_stay(looker: PlayerBase, new_col: int) -> bool:
	var margin_right: int = cols - (Tuning.VIEW_COLS - PartyTuning.CAM_REAR_MARGIN_COL_LEFT)
	for hero: PlayerBase in _tribe:
		if hero == looker:
			continue
		var sc: int = Tuning.to_cell(hero.sim_pos.x) - new_col
		if sc < PartyTuning.CAM_REAR_MARGIN_COL or sc > margin_right:
			return false
	return true


## Vertical step in px for a distance (px) between the hero and the target row line (PHYSICS.md 12.2 #5) on the
## current view: the distance is mapped onto the 11-row curve (first or second by [member fast]) and the speed
## grows by the same factor. Outside the curve no step is taken, as in the original.
func vertical_step(distance: int) -> int:
	var base: int = Tuning.VIEW_ROWS
	var scaled: int = distance * base / rows
	var speed: int = Tuning.cam_v_speed(scaled, fast)
	if speed <= 0:
		return 0
	return (speed * rows + base - 1) / base


func _follows_x() -> bool:
	return (scroll_flags & Defs.SCROLL_NO_HORIZONTAL) == 0 and _min.x < _max.x


## Camera limits from the level (or lock) rectangle. An area narrower than the view is centred; an area lower
## than the view is centred too, but with the margin above it rounded down to whole tiles, so the camera row never
## lies more than the rows of the area above its bottom (the hero's "too far below the camera row" rule,
## PHYSICS.md 10.3, counts rows from the camera cell). A lock never shows what lies outside the level in an axis
## in which the level is larger than the view: the view slides inwards instead.
func _update_limits() -> void:
	var limits: Array[Vector2i] = _area_limits(bounds)
	if _locked:
		var level_min: Vector2i = limits[0]
		var level_max: Vector2i = limits[1]
		limits = _area_limits(_lock_rect)
		if level_max.x > level_min.x:
			limits[0].x = clampi(limits[0].x, level_min.x, level_max.x)
			limits[1].x = clampi(limits[1].x, level_min.x, level_max.x)
		if level_max.y > level_min.y:
			limits[0].y = clampi(limits[0].y, level_min.y, level_max.y)
			limits[1].y = clampi(limits[1].y, level_min.y, level_max.y)
	_min = limits[0]
	_max = limits[1]


func _area_limits(area: Rect2i) -> Array[Vector2i]:
	var low: Vector2i = area.position
	var high: Vector2i = area.end - view
	if high.x < low.x:
		low.x = area.position.x + floori(float(area.size.x - view.x) / 2.0)
		high.x = low.x
	if high.y < low.y:
		var margin: int = (view.y - area.size.y) / 2
		low.y = area.position.y - (margin & ~(Tuning.TILE - 1))
		high.y = low.y
	return [low, high]


func _scale_rows() -> void:
	_air_low_sr = _scaled_row(Tuning.CAM_V_AIR_LOW_SR)
	_air_low_target = _scaled_row(Tuning.CAM_V_AIR_LOW_TARGET)
	_air_high_sr = _scaled_row(Tuning.CAM_V_AIR_HIGH_SR)
	_air_high_target = _scaled_row(Tuning.CAM_V_AIR_HIGH_TARGET)
	_ground_low_sr = _scaled_row(Tuning.CAM_V_GROUND_LOW_SR)
	_ground_low_target = _scaled_row(Tuning.CAM_V_GROUND_LOW_TARGET)
	_ground_high_sr = _scaled_row(Tuning.CAM_V_GROUND_HIGH_SR)
	_ground_high_target = _scaled_row(Tuning.CAM_V_GROUND_HIGH_TARGET)
	_alt_low_sr = _scaled_row(Tuning.CAM_V_ALT_LOW_SR)
	_alt_low_target = _scaled_row(Tuning.CAM_V_ALT_LOW_TARGET)
	_alt_high_sr = _scaled_row(Tuning.CAM_V_ALT_HIGH_SR)
	_alt_high_target = _scaled_row(Tuning.CAM_V_ALT_HIGH_TARGET)


## A row number of the original 11-row view on the current view, rounded to the nearest row.
func _scaled_row(row: int) -> int:
	var base: int = Tuning.VIEW_ROWS
	return clampi((row * rows * 2 + base) / (base * 2), 0, maxi(rows - 1, 0))


func _step_right() -> void:
	pos.x = mini(Tuning.tile_top(pos.x) + Tuning.CAM_STEP_PX, _max.x)


func _step_left() -> void:
	pos.x = maxi(Tuning.tile_top(pos.x + Tuning.CAM_STEP_PX - 1) - Tuning.CAM_STEP_PX, _min.x)


## PHYSICS.md 12.1 and 12.3: look-around, then paging on tile cells.
func _follow_x(hero: PlayerBase) -> void:
	var sc: int = Tuning.to_cell(hero.sim_pos.x) - Tuning.to_cell(pos.x)
	var standing: bool = hero.xvel == 0 and not hero.on_platform
	if hero.looking and standing:
		if hero.facing > 0:
			if sc > Tuning.CAM_LOOK_MIN_SC:
				_step_right()
		elif sc < cols - (Tuning.VIEW_COLS - Tuning.CAM_LOOK_MAX_SC):
			_step_left()
		h_dir = DIR_IDLE
		return
	if sc < cols and standing:
		h_dir = DIR_IDLE
		return
	match h_dir:
		DIR_IDLE:
			var right: bool = sc >= cols * Tuning.CAM_IDLE_SPLIT / Tuning.VIEW_COLS
			if hero.xvel != 0:
				right = hero.xvel > 0
			if right:
				if sc >= cols - (Tuning.VIEW_COLS - Tuning.CAM_RIGHT_START):
					h_dir = DIR_RIGHT
			elif sc <= Tuning.CAM_LEFT_START:
				h_dir = DIR_LEFT
		DIR_RIGHT:
			if sc <= Tuning.CAM_RIGHT_STOP or pos.x >= _max.x:
				h_dir = DIR_IDLE
			else:
				_step_right()
		DIR_LEFT:
			if sc >= cols - (Tuning.VIEW_COLS - Tuning.CAM_LEFT_STOP) or pos.x <= _min.x:
				h_dir = DIR_IDLE
			else:
				_step_left()


## PHYSICS.md 12.6: the hero is kept between `margin` and `view width - margin`; even pixel positions only. The
## view moves at most one tile per tick so that leaving a look-around is a pan, not a jump.
func _follow_x_smooth(hero: PlayerBase) -> void:
	var margin: int = mini(Tuning.CAM_SMOOTH_MARGIN, view.x * 2 / 5)
	var sx: int = hero.sim_pos.x - pos.x
	var target: int = pos.x
	var standing: bool = hero.xvel == 0 and not hero.on_platform
	var look_px: int = (Tuning.CAM_LOOK_MIN_SC + 1) * Tuning.TILE
	if hero.looking and standing:
		_look_hold = true
		if hero.facing > 0:
			if sx > look_px:
				target = pos.x + Tuning.CAM_STEP_PX
		elif sx < view.x - look_px:
			target = pos.x - Tuning.CAM_STEP_PX
	else:
		if _look_hold and standing:
			return
		_look_hold = false
		if sx > view.x - margin:
			target = pos.x + sx - (view.x - margin)
		elif sx < margin:
			target = pos.x + sx - margin
	target = clampi(target, pos.x - Tuning.CAM_STEP_PX, pos.x + Tuning.CAM_STEP_PX)
	pos.x = clampi(target, _min.x, _max.x) & ~1


## PHYSICS.md 12.2. `fixed_step` > 0 replaces the speed curve (spawn placement, 12.5) and ignores auto-scroll.
func _follow_y(hero: PlayerBase, fixed_step: int) -> void:
	if fixed_step == 0 and (scroll_flags & Defs.SCROLL_AUTO_DOWN) != 0:
		if not autoscroll_held:
			pos.y = mini(pos.y + Tuning.CAM_AUTOSCROLL_PX, _max.y)
		return
	if hero.yvel == 0:
		v_active = 0
	var cam_row: int = Tuning.to_cell(pos.y)
	var sr: int = Tuning.to_cell(hero.sim_pos.y) - cam_row
	if hero.yvel != 0:
		if sr >= _air_low_sr:
			v_target = _air_low_target
			v_active += 1
		elif sr <= _air_high_sr:
			v_target = _air_high_target
			v_active += 1
	elif (scroll_flags & Defs.SCROLL_LOW_BAND) != 0:
		if sr >= _alt_low_sr:
			v_target = _alt_low_target
			v_active += 1
		elif sr <= _alt_high_sr:
			v_target = _alt_high_target
			v_active += 1
	elif sr >= _ground_low_sr:
		v_target = _ground_low_target
		v_active += 1
	elif sr <= _ground_high_sr:
		v_target = _ground_high_target
		v_active += 1
	if v_active == 0:
		return
	var y_in_view: int = hero.sim_pos.y - pos.y
	# Home row (12.2 #6): while the hero is on the main floor the camera may not sink below it and is pulled up
	# when it is more than one row below.
	var on_main_floor: bool = home_row >= 0 and hero.sim_pos.y <= (home_row + rows) * Tuning.TILE
	if not on_main_floor or home_row >= cam_row - 1:
		if v_target == sr:
			v_active = 0
			return
		if v_target < sr:
			if on_main_floor and cam_row > home_row:
				v_active = 0
				return
			_move_y(1, y_in_view - v_target * Tuning.TILE, fixed_step)
			return
	_move_y(-1, v_target * Tuning.TILE - y_in_view, fixed_step)


func _move_y(direction: int, distance: int, fixed_step: int) -> void:
	var step: int = fixed_step if fixed_step > 0 else vertical_step(distance)
	if step <= 0:
		return
	if direction > 0:
		if pos.y >= _max.y:
			v_active = 0
		else:
			pos.y = mini(pos.y + step, _max.y)
	elif pos.y <= _min.y:
		v_active = 0
	else:
		pos.y = maxi(pos.y - step, _min.y)
