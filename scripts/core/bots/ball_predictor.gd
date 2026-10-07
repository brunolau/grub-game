class_name BallPredictor
extends RefCounted
## Predicts the Clubball coconut's flight with the deterministic ball physics (DESIGN.md E.7: "Clubball bots predict
## its landing with the deterministic ball physics and stand goal-side of it"; GAMEPLAY.md 13.10.6). Owner: core-B.
##
## When objects-B's Coconut (scripts/objects/coconut.gd) offers `static func predict(grid, pos, xvel, yvel, ticks)`,
## that function is used, so the bots see exactly the ball's own code. Otherwise this class integrates GAMEPLAY 13.10.6
## itself on the level's TileGrid (tiles only - no heads, heroes or goals):
##  - gravity VersusTuning.BALL_GRAVITY (16) per tick while airborne, capped at Tuning.TERMINAL_YVEL (192);
##  - x: `x += floor16(xvel)`; a step whose box would enter a wall cell (SIDE 1) or leave the level is refused and
##    reflects: `xvel = -(xvel * 3) >> 2` (3/4 back);
##  - y: falling onto a floor (any floor tile but deadly ones): the feet snap onto its top and it bounces with
##    `yvel = -(yvel * 3) >> 2` while `yvel >= 32`, else it lies on the floor; rising into a ceiling reflects at 3/4;
##  - on the floor it rolls, losing VersusTuning.BALL_ROLL_LOSS v16 of |xvel| per tick.
## Positions are the ball's `sim_pos` (feet point: bottom centre of its 16 x 16 box, box_xo 8 - SimEntity's rule).

const SCRIPT_PATH: String = "res://scripts/objects/coconut.gd"
const BOX: int = 16
const BOUNCE_MIN_YVEL: int = 32
const TERMINAL: int = 192
const SPEED_CAP: int = 288

## One ball state (feet point and velocity in v16).
class State:
	extends RefCounted
	var pos: Vector2i = Vector2i.ZERO
	var xvel: int = 0
	var yvel: int = 0
	var grounded: bool = false

	func copy() -> State:
		var s: State = State.new()
		s.pos = pos
		s.xvel = xvel
		s.yvel = yvel
		s.grounded = grounded
		return s


## The ball's feet points for the next `ticks` ticks (index 0 = after the next tick).
static func predict(level: LevelBase, ball: SimEntity, ticks: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if level == null or ball == null or level.grid == null:
		return result
	var native: Script = _native_script()
	if native != null:
		var value: Variant = native.call(&"predict", level.grid, ball.sim_pos, ball.xvel, ball.yvel, ticks)
		if value is PackedVector2Array:
			for point: Vector2 in value:
				result.append(Vector2i(point))
			return result
		if value is Array:
			for point: Variant in value:
				if point is Vector2i:
					result.append(point)
				elif point is Vector2:
					result.append(Vector2i(point))
			return result
	var state: State = State.new()
	state.pos = ball.sim_pos
	state.xvel = ball.xvel
	state.yvel = ball.yvel
	state.grounded = on_floor(level.grid, state.pos)
	for t: int in ticks:
		step(level.grid, state)
		result.append(state.pos)
	return result


## objects-B's Coconut script when it has the static predict(); null otherwise.
static func _native_script() -> Script:
	if not ResourceLoader.exists(SCRIPT_PATH):
		return null
	var script: Script = load(SCRIPT_PATH) as Script
	if script != null and script.has_script_method(&"predict"):
		return script
	return null


## One tick of the ball (see the header).
static func step(grid: TileGrid, s: State) -> void:
	# Gravity while airborne.
	if s.grounded and s.yvel >= 0 and on_floor(grid, s.pos):
		s.yvel = 0
	else:
		s.grounded = false
		s.yvel = mini(s.yvel + VersusTuning.BALL_GRAVITY, TERMINAL)
	# Horizontal.
	var dx: int = Tuning.floor16(s.xvel)
	if dx != 0:
		var nx: int = s.pos.x + dx
		if _blocked(grid, nx, s.pos.y):
			s.xvel = reflect(s.xvel)
		else:
			s.pos.x = nx
	# Vertical.
	var dy: int = Tuning.floor16(s.yvel)
	if dy > 0:
		var landing: int = _floor_between(grid, s.pos.x, s.pos.y, s.pos.y + dy)
		if landing >= 0:
			s.pos.y = landing
			if s.yvel >= BOUNCE_MIN_YVEL:
				s.yvel = reflect(s.yvel)
				s.grounded = false
			else:
				s.yvel = 0
				s.grounded = true
		else:
			s.pos.y += dy
	elif dy < 0:
		var ceiling: int = _ceiling_between(grid, s.pos.x, s.pos.y - BOX, s.pos.y - BOX + dy)
		if ceiling >= 0:
			s.pos.y = ceiling + BOX
			s.yvel = reflect(s.yvel)
		else:
			s.pos.y += dy
	# Rolling.
	if s.grounded and s.yvel == 0 and s.xvel != 0:
		var magnitude: int = maxi(absi(s.xvel) - VersusTuning.BALL_ROLL_LOSS, 0)
		s.xvel = magnitude if s.xvel > 0 else -magnitude
	s.xvel = clampi(s.xvel, -SPEED_CAP, SPEED_CAP)
	s.yvel = clampi(s.yvel, -SPEED_CAP, SPEED_CAP)


## 3/4 back: -(v * 3) >> 2.
static func reflect(v: int) -> int:
	return -((v * 3) >> 2)


## True when a floor tile lies right under the feet point `pos` (its top at pos.y).
static func on_floor(grid: TileGrid, pos: Vector2i) -> bool:
	if pos.y % Tuning.TILE != 0:
		return false
	return _floor_under(grid, pos.x, pos.y >> 4)


## The first landing tile top crossed when the feet fall from `y0` to `y1` (> y0), -1 when none.
static func _floor_between(grid: TileGrid, x: int, y0: int, y1: int) -> int:
	var row: int = ((y0 - 1) >> 4) + 1
	while row * Tuning.TILE <= y1:
		if row * Tuning.TILE > y0 - 1 and row * Tuning.TILE <= y1 and _floor_under(grid, x, row):
			return row * Tuning.TILE
		row += 1
	return -1


## True when a landing floor fills row `row` under the box spanning `x` (the 16 px box, any of its columns).
static func _floor_under(grid: TileGrid, x: int, row: int) -> bool:
	for col: int in [(x - BOX / 2) >> 4, (x + BOX / 2 - 1) >> 4]:
		if not grid.in_bounds(col, row):
			continue
		var value: int = grid.floor_at(col, row)
		if value != TileGrid.FLOOR_EMPTY and value != TileGrid.FLOOR_DEADLY and value != TileGrid.FLOOR_NOTHING:
			return true
	return false


## The bottom y of the first ceiling the box top crosses rising from `top0` to `top1` (< top0); -1 when none.
static func _ceiling_between(grid: TileGrid, x: int, top0: int, top1: int) -> int:
	var row: int = (top0 >> 4) - 1
	while (row + 1) * Tuning.TILE > top1 and row >= -1:
		for col: int in [(x - BOX / 2) >> 4, (x + BOX / 2 - 1) >> 4]:
			if grid.in_bounds(col, row) and (grid.ceiling_at(col, row) != TileGrid.CEILING_NONE
					or grid.side_at(col, row) == TileGrid.SIDE_WALL):
				return (row + 1) * Tuning.TILE
		row -= 1
	return -1


## True when the box with its feet at (x, y) overlaps a wall cell or leaves the level sideways.
static func _blocked(grid: TileGrid, x: int, y: int) -> bool:
	var left: int = x - BOX / 2
	var right: int = x + BOX / 2 - 1
	if left < 0 or right >= grid.cols * Tuning.TILE:
		return true
	for row: int in [(y - BOX) >> 4, (y - 1) >> 4]:
		for col: int in [left >> 4, right >> 4]:
			if grid.in_bounds(col, row) and grid.side_at(col, row) == TileGrid.SIDE_WALL:
				return true
	return false


## The first predicted point (and its index) where the ball is on or near the floor of `graph` within `reach_px`
## above a node: {"t": index, "pos": feet point, "node": node id}; empty when none.
static func first_reachable(graph: NavGraph, path: Array[Vector2i], reach_px: int) -> Dictionary:
	if graph == null:
		return {}
	for t: int in path.size():
		var p: Vector2i = path[t]
		var node: int = graph.node_below(p)
		if node < 0:
			continue
		if graph.node_y(graph.nodes[node]) - p.y <= reach_px:
			return {"t": t, "pos": p, "node": node}
	return {}
