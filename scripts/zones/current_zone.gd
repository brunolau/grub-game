class_name CurrentZone
extends ZoneBase
## `zones/current rect=c,r,w,h dir=l|r|u|d speed=1..3` (docs/spec/PHYSICS.md C.7, DESIGN.md C.5): water that flows.
## Owner: world-A.
##
## The zone itself moves nothing and never ticks: what floats asks it. A raft (objects-B) whose anchor is inside a
## current with `dir = l|r` drifts `speed` px per tick that way (C.7 step 1; the raft finds every Kind.ZONE entity
## with `dir` and `speed` in its spawn parameters, or calls [method find_at]); `dir = u|d` currents move only floating
## dropped items ([method drift_at]). Heroes are not moved (water is deadly). Parameters: `rect` (tiles, required),
## `dir` [r], `speed` px per tick [1], clamped to Tuning.CURRENT_SPEED_MIN_PX .. CURRENT_SPEED_MAX_PX, `name`.
##
## Presentation (G1 follow-up): pale STREAKS drift over the liquid cells (`~`) of the rectangle in the flow direction at
## the current's speed, so a player sees where the water runs and how fast before he steps on a raft. Drawn in front
## of the liquid, only for the cells inside the view, from a clock of its own (never read by the simulation).

## Streaks per liquid cell, their length (logical px, by speed 1 / 2 / 3), thickness and colour.
const STREAKS_PER_CELL: int = 2
const STREAK_LENGTH_PX: Array[int] = [5, 7, 9]
const STREAK_COLOR: Color = Color(1.0, 1.0, 1.0, 0.35)
## Rows of a cell's art the streaks may use: below the surface strip (4 art px of air, LevelTiles) and above its foot.
const STREAK_TOP_ART: int = 8
const STREAK_BOTTOM_ART: int = 28
## In front of the liquid, which is painted on the front tile layer.
const Z_STREAKS: int = Defs.Z_FRONT_TILES + 1

## The flow direction: &"l", &"r", &"u" or &"d".
var dir: StringName = &"r"
## px per tick.
var speed: int = Tuning.CURRENT_SPEED_MIN_PX

## The liquid cells of the rectangle (found once, the first time they are drawn) and the streak clock in seconds.
var _water: Array[Vector2i] = []
var _water_found: bool = false
var _clock: float = 0.0


func _apply_params(params: Dictionary) -> void:
	super._apply_params(params)
	var value: String = param_str("dir", "r").to_lower()
	if not ["l", "r", "u", "d"].has(value):
		push_warning("%s: dir must be l, r, u or d (got '%s'); using r" % [name, value])
		value = "r"
	dir = StringName(value)
	speed = clampi(param_int("speed", Tuning.CURRENT_SPEED_MIN_PX), Tuning.CURRENT_SPEED_MIN_PX,
			Tuning.CURRENT_SPEED_MAX_PX)
	z_index = Z_STREAKS


## A current tests nobody: it never ticks (and so never dozes or wakes).
func _sim_phases() -> PackedInt32Array:
	return PackedInt32Array()


## The drift of this current in px per tick: (+/-speed, 0) for l / r, (0, +/-speed) for u / d.
func drift() -> Vector2i:
	match dir:
		&"l":
			return Vector2i(-speed, 0)
		&"u":
			return Vector2i(0, -speed)
		&"d":
			return Vector2i(0, speed)
	return Vector2i(speed, 0)


## The first current (spawn order) of `level` whose rectangle holds the point `pos` (logical px), null when none.
static func find_at(level: LevelBase, pos: Vector2i) -> CurrentZone:
	if level == null:
		return null
	var zones: Array[SimEntity] = level.get_kind(Defs.Kind.ZONE)
	for i: int in zones.size():
		var current: CurrentZone = zones[i] as CurrentZone
		if current != null and current.rect.has_point(pos):
			return current
	return null


## The drift (px per tick) at the point `pos`: that of [method find_at], Vector2i.ZERO outside every current.
static func drift_at(level: LevelBase, pos: Vector2i) -> Vector2i:
	var current: CurrentZone = find_at(level, pos)
	return current.drift() if current != null else Vector2i.ZERO


# =================================================================================================================
# Presentation: the streaks
# =================================================================================================================

## The liquid cells (`~`) of the rectangle, in reading order (the cells the streaks are drawn on).
func water_cells() -> Array[Vector2i]:
	if _water_found:
		return _water
	var level: LevelBase = Game.level
	if level == null or level.grid == null:
		return _water
	_water_found = true
	var first: Vector2i = rect.position / Tuning.TILE
	var last: Vector2i = (rect.end - Vector2i.ONE) / Tuning.TILE
	for row: int in range(first.y, last.y + 1):
		for col: int in range(first.x, last.x + 1):
			if level.grid.in_bounds(col, row) and level.grid.get_char(col, row) == TileGrid.CH_LIQUID:
				_water.append(Vector2i(col, row))
	return _water


## Streak `index` of the liquid cell `cell` after `seconds`: its rectangle in logical px. The streak runs along the flow
## through a band of cells (the whole row for l / r, the whole column for u / d, wrapping at the rectangle's edges),
## so streaks pass from one cell to the next; each starts at a fixed hash of its cell.
func streak_rect(cell: Vector2i, index: int, seconds: float) -> Rect2:
	var length: float = float(STREAK_LENGTH_PX[clampi(speed - 1, 0, STREAK_LENGTH_PX.size() - 1)])
	var h: int = LevelTiles.cell_hash(cell.x * 3 + index, cell.y * 7 + index)
	var travel: float = seconds * float(speed * Tuning.ANIM_TICKS_PER_SECOND)
	var horizontal: bool = dir == &"l" or dir == &"r"
	var sign_dir: float = -1.0 if dir == &"l" or dir == &"u" else 1.0
	var cross: float = float(STREAK_TOP_ART + h % (STREAK_BOTTOM_ART - STREAK_TOP_ART)) / float(Tuning.ART_SCALE)
	if horizontal:
		var span: float = float(rect.size.x)
		var along: float = fposmod(float(cell.x * Tuning.TILE - rect.position.x) + float(h % 97) / 97.0 * Tuning.TILE
				+ sign_dir * travel, span)
		return Rect2(float(rect.position.x) + along, float(cell.y * Tuning.TILE) + cross, length, 1.0)
	var span_v: float = float(rect.size.y)
	var along_v: float = fposmod(float(cell.y * Tuning.TILE - rect.position.y) + float(h % 97) / 97.0 * Tuning.TILE
			+ sign_dir * travel, span_v)
	var x: float = float(cell.x * Tuning.TILE) + float(h % (Tuning.TILE - 2)) + 1.0
	return Rect2(x, float(rect.position.y) + along_v, 1.0, length)


func _process(delta: float) -> void:
	_clock += delta
	if not water_cells().is_empty():
		queue_redraw()


func _draw() -> void:
	var level: LevelBase = Game.level
	if level == null or _water.is_empty():
		return
	var view: Rect2 = Rect2(level.get_view_rect()).grow(float(Tuning.TILE))
	var origin: Vector2 = position
	for cell: Vector2i in _water:
		if not view.has_point(Vector2(cell * Tuning.TILE)):
			continue
		for i: int in STREAKS_PER_CELL:
			var streak: Rect2 = streak_rect(cell, i, _clock)
			# Only over liquid: a streak that ran onto a cell that is not '~' (a bank inside the rectangle) is hidden.
			var head: Vector2i = Vector2i(streak.position) / Tuning.TILE
			if not level.grid.in_bounds(head.x, head.y) or level.grid.get_char(head.x, head.y) != TileGrid.CH_LIQUID:
				continue
			draw_rect(Rect2(Tuning.to_art(streak.position) - origin, Tuning.to_art(streak.size)), STREAK_COLOR)
