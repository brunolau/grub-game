class_name CoopSearch
extends RefCounted
## The solo-impossibility search of co-op gates (docs/expansion/DESIGN.md D.8 #3-#4, LEVEL_DESIGN.md 15.7.6,
## PLAN.md 8 V3.c). Owner: world-B (PLAN.md P1.7, v1). Called by tests/test_coop_gates.gd for every
## `objects/x2_tablet gate=<name> far=c,r` of every co-op file and by `tools/validate_levels.gd -- --coop`.
##
## [method search_gate] proves (as far as a bounded search can) that ONE hero cannot get from the gate's tablet (and
## from the last checkpoint before it) to the tablet's `far` cell:
##  1. Static rules first (LevelValidator, the content rules of co-op files): nothing to climb on within reach of a
##     ledge gate (enemies, springs, geysers, vines, bark boards, gliders, platforms, mounts, pogo ladders), no bark
##     board near any gate, keeper and Guard halls 4 rows high, plates 8+ tiles from their doors. A broken static rule
##     counts as "reached" (detail: the rule).
##  2. The search: the REAL hero (scenes/player/player.tscn, the physics the route proofs replay) on a bare level
##     holding the file's grid at rest (doors closed, plates up, keepers alive, Expert-only static blocks for
##     Expert), driven by a set of input macros (walks, standing / running / short jumps with and without air control,
##     jumps that drift back over a ledge, crawls, drops) from every resting point it reaches, breadth first, inside the
##     gate's area (its tablet and far cell grown by one view), within VersusTuning-free bounds: BOUND_TICKS of game
##     time per path and MAX_NODES resting points. The far cell is reached when the hero's feet point is in it on any
##     tick (mid-air too).
##  3. Windows (D.8 #4): every twin window and daze near the gate with the solo minimum the search measures -
##     drum bonds and enemy bonds (the ticks one hero needs from striking one member to the other: running between
##     their strike spots, or 0 when a thrown special from beside one crosses the other), `daze` records (the real
##     hero's ticks from a head bounce to his first damaging box on a still target), timed plates (the ticks from the
##     plate to its door against the time the door stays open). test_coop_gates demands window <= solo_min - 4.
## v1 limits (noted for the G1 review): club only for movement (specials only through the static rules and the throw
## lines of the windows), no Chomper (pens near ledges are a static error), enemies are not simulated (their
## bounces are the static rule), macros start from rest (momentum carried between macros is not modelled except
## inside a macro), the bound is per resting point, not a full input-space search.

## Game ticks a single hero is allowed per path (LEVEL_DESIGN.md 15.7.6: 1 457 ticks *(tune)*).
const BOUND_TICKS: int = 1457
## Resting points explored at most per search (a compute bound).
const MAX_NODES: int = 220
## After a macro's inputs end the hero has this long to come to rest (else the macro is dropped).
const SETTLE_TICKS: int = 48
## Resting points closer than this (px, on the same y) are one node.
const KEY_PX: int = 8
## A ledge gate's area and the windows' reach: the tablet and far cell grown by one view (LEVEL_DESIGN.md 15.7.7).
const AREA_COLS: int = Tuning.VIEW_COLS
const AREA_ROWS: int = Tuning.VIEW_ROWS
## Error fragments of the validator that make a gate solvable alone (the static rules of LEVEL_DESIGN.md 15.7.6).
const STATIC_FRAGMENTS: Array[String] = [" hall of ", " tiles from its door", "pogo ladder"]
const PLAYER_ID: StringName = &"player/player"
const STRIKE_FRAMES: int = 9    ## a strike connects within one swing


## The level of a search: the grid at rest, a view as large as the map (nothing dies "off screen").
class SearchLevel:
	extends LevelBase

	func get_view_rect() -> Rect2i:
		return Rect2i(0, 0, maxi(grid.width_px(), Tuning.VIEW_W), maxi(grid.height_px(), Tuning.VIEW_H))


## One search: a bare level with the real hero, scripted from macros.
class Searcher:
	extends RefCounted

	var level: SearchLevel = null
	var hero: PlayerBase = null
	var macros: Array[Dictionary] = []
	var simulated: int = 0
	var _saved_level: LevelBase = null
	var _flags: PackedInt32Array = PackedInt32Array()
	var _first_tick: int = 0

	## Build the level from `grid`. False when the hero scene does not exist.
	func build(level_id: StringName, meta: Dictionary, grid: TileGrid) -> bool:
		if not Spawner.exists(PLAYER_ID):
			return false
		_saved_level = Game.level
		level = SearchLevel.new()
		level.name = "CoopSearchLevel"
		level.level_id = level_id
		level.meta = meta
		level.grid = grid
		(Engine.get_main_loop() as SceneTree).root.add_child(level)
		hero = Spawner.instantiate(PLAYER_ID) as PlayerBase
		if hero == null:
			close()
			return false
		hero.spawn_setup(Vector2i(Tuning.TILE * 2, Tuning.TILE * 2), {})
		level.add_child(hero)
		GameInput.set_scripted(_flag_at)
		macros = CoopSearch.make_macros()
		return true

	func close() -> void:
		GameInput.clear_scripted()
		if level != null and is_instance_valid(level):
			level.get_parent().remove_child(level)
			level.free()
		level = null
		hero = null
		Game.level = _saved_level if is_instance_valid(_saved_level) else null

	func _flag_at(tick: int) -> int:
		var index: int = tick - _first_tick
		return _flags[index] if index >= 0 and index < _flags.size() else 0

	## Play `flags` from rest at `start`. {"goal": true, "ticks"} when the feet point entered a cell of `goals`;
	## {"pos", "ticks"} when he came to rest; {} when he died or did not come to rest.
	func run(start: Vector2i, facing: int, flags: PackedInt32Array, goals: Dictionary) -> Dictionary:
		hero.run.reset_energy()
		hero.respawn_at(start)
		hero.facing = facing
		_flags = flags
		_first_tick = Sim.tick + 1
		var still: int = 0
		var t: int = 0
		while t < flags.size() + SETTLE_TICKS:
			Sim.step(1)
			t += 1
			simulated += 1
			if hero.dead:
				return {}
			var cell: Vector2i = Vector2i(Tuning.to_cell(hero.sim_pos.x), Tuning.to_cell(hero.sim_pos.y - 1))
			if goals.has(cell):
				return {"goal": true, "ticks": t, "cell": cell}
			if t >= flags.size():
				if hero.is_grounded() and hero.yvel == 0 and hero.xvel == 0:
					still += 1
					if still >= 2:
						return {"pos": hero.sim_pos, "ticks": t}
				else:
					still = 0
		return {}

	## Breadth-first over resting points from `starts` (feet points) inside `area` (cells) until a cell of `goals` is
	## entered. Returns {"reached", "ticks", "detail", "nodes", "rest": {key Vector2i -> ticks}}.
	func explore(starts: Array[Vector2i], goals: Dictionary, area: Rect2i, bound: int, max_nodes: int) -> Dictionary:
		var queue: Array[Dictionary] = []
		var seen: Dictionary = {}
		for start: Vector2i in starts:
			var key: Vector2i = CoopSearch.node_key(start)
			if not seen.has(key):
				seen[key] = 0
				queue.append({"pos": start, "ticks": 0, "path": "start %d,%d" % [start.x, start.y]})
		var head: int = 0
		while head < queue.size() and head < max_nodes:
			var node: Dictionary = queue[head]
			head += 1
			var start_cell: Vector2i = Vector2i(Tuning.to_cell(node["pos"].x), Tuning.to_cell(node["pos"].y - 1))
			if goals.has(start_cell):
				return {"reached": true, "ticks": node["ticks"], "detail": node["path"], "nodes": head, "rest": seen}
			for macro: Dictionary in macros:
				var outcome: Dictionary = run(node["pos"], int(macro["facing"]), macro["flags"], goals)
				if outcome.is_empty():
					continue
				var ticks: int = int(node["ticks"]) + int(outcome["ticks"])
				if ticks > bound:
					continue
				var path: String = "%s > %s" % [node["path"], macro["name"]]
				if outcome.has("goal"):
					return {"reached": true, "ticks": ticks, "detail": path, "nodes": head, "rest": seen}
				var pos: Vector2i = outcome["pos"]
				var key: Vector2i = CoopSearch.node_key(pos)
				if seen.has(key) and int(seen[key]) <= ticks:
					continue
				var fresh: bool = not seen.has(key)
				seen[key] = ticks
				var cell: Vector2i = Vector2i(Tuning.to_cell(pos.x), Tuning.to_cell(pos.y - 1))
				if fresh and area.has_point(cell):
					queue.append({"pos": pos, "ticks": ticks, "path": path})
		return {"reached": false, "ticks": -1, "detail": "", "nodes": head, "rest": seen}


## Solo-impossibility search of gate `gate` of the co-op level `level_id` in `difficulty` (the contract of
## tests/test_coop_gates.gd): {"reached": bool (true = one hero got to the far cell, or a static rule is broken, or
## the gate cannot be searched), "bound": BOUND_TICKS, "windows": [{"what", "window", "solo_min"}], "detail": String,
## "starts": Array of start cells, "explored": resting points searched}.
static func search_gate(level_id: StringName, difficulty: int, gate: String) -> Dictionary:
	var data: LevelData = LevelData.load_file(level_path(level_id))
	if data == null:
		return _unproven(_fresh_result(), "cannot read the level %s" % level_id)
	return search_data(data, difficulty, gate)


## [method search_gate] on a parsed level (tests, tools).
static func search_data(data: LevelData, difficulty: int, gate: String) -> Dictionary:
	var result: Dictionary = _fresh_result()
	var tablet: Dictionary = find_tablet(data, difficulty, gate)
	if tablet.is_empty():
		return _unproven(result, "no objects/x2_tablet gate=%s in %s" % [gate, Defs.difficulty_name(difficulty)])
	var far: Vector2i = tablet["far"]
	if far == Vector2i(-1, -1):
		return _unproven(result, "the tablet of gate %s names no far cell" % gate)
	# 1. Static rules.
	var broken: String = static_problem(data, gate)
	if broken != "":
		result["reached"] = true
		result["detail"] = "static rule: " + broken
		return result
	# 2. The search with the real hero.
	var grid: TileGrid = grid_at_rest(data, difficulty)
	var area: Rect2i = gate_area(tablet, grid)
	# The daze measurements build a search level of their own: before this one (they never nest).
	for record: Dictionary in data.entity_records():
		var id: String = String(record["id"])
		var daze: bool = str(record["params"].get("coop", "")) == "daze" or id == "enemies/raptor"
		if daze and Spawner.category(StringName(id)) == "enemies" and LevelText.applies_to(record["params"], difficulty):
			measure_daze_solo_min(id)
	var searcher: Searcher = Searcher.new()
	if not searcher.build(data.id, data.resolved_meta(difficulty), grid):
		return _unproven(result, "the hero scene %s does not exist" % PLAYER_ID)
	var starts: Array[Vector2i] = start_points(data, difficulty, tablet, grid)
	for start: Vector2i in starts:
		(result["starts"] as Array).append(Vector2i(Tuning.to_cell(start.x), Tuning.to_cell(start.y - 1)))
	var found: Dictionary = {}
	if prefilter and not flood_reaches(grid, starts, far, search_columns(area, starts, grid)):
		# 2a. No cell path at all: the far cell lies beyond closed doors / walls (the search could not get there).
		found = {"reached": false, "ticks": -1, "detail": "", "nodes": 0}
		result["prefilter"] = true
	else:
		# 2b. The same grid at rest, starts, area and meta give the same search (Beginner and Expert often do).
		var key: String = _explore_key(grid, data.resolved_meta(difficulty), starts, far, area)
		if prefilter and _explore_cache.has(key):
			found = _explore_cache[key]
		else:
			found = searcher.explore(starts, {far: true}, area, BOUND_TICKS, MAX_NODES)
			found.erase("rest")
			_explore_cache[key] = found
	result["reached"] = bool(found["reached"])
	result["explored"] = int(found["nodes"])
	if result["reached"]:
		result["detail"] = "one hero reached %d,%d in %d ticks: %s" % [far.x, far.y, int(found["ticks"]),
			found["detail"]]
	# 3. Windows near the gate.
	result["windows"] = measure_windows(data, difficulty, area, searcher)
	searcher.close()
	return result


## Explore results of [method search_data] by grid at rest, meta, starts, far cell and area (see [method _explore_key]).
static var _explore_cache: Dictionary = {}
## False: [method search_data] always runs the full search (no static prefilter, no cached explore) - for tests that
## prove the search itself.
static var prefilter: bool = true


## Rows a feet cell may rise above the cell it last stood in, for [method flood_reaches]: the hero's highest jump
## (UP released after 5-9 ticks, PHYSICS.md 6.4) peaks 64 px over the take-off, which moves the feet cell up exactly 4
## rows from a floor, and at most 4 from feet inside a slope or tar cell. The search level holds no spring, enemy or
## carrier that could lift him higher.
const FLOOD_RISE_ROWS: int = 4


## The static prefilter of [method search_data] (a cheap, sound bound asked for by D5 and DB1): false when no chain of
## cells a hero's feet point can occupy joins a start to the `far` cell. Feet cells are the cells of the grid at rest
## that are not side walls (slopes, one-way floors, hatches, liquids and spikes included; a tar floor too, whose
## surface lies inside its cell), plus one open row above the map, joined 8-connected. A chain may rise at most
## FLOOD_RISE_ROWS rows above the last cell with ground under it and may not rise again once it went down, except
## for one row into a cell with ground under it (an airborne hero whose feet enter a one-cell wall lands on top of
## it: the side probe tests the row above an airborne feet cell). The search level holds no entity, so the search can
## only move the hero along such chains: when none joins, the search cannot reach the far cell either. `columns`
## ([first, end)) keeps the chains to the columns the search can touch ([method search_columns]).
static func flood_reaches(grid: TileGrid, starts: Array[Vector2i], far: Vector2i,
		columns: Vector2i = Vector2i(0, 1 << 30)) -> bool:
	if far.x < 0 or far.x >= grid.cols or far.y < -1 or far.y >= grid.rows:
		return false
	var cols: int = grid.cols
	var cells: int = cols * (grid.rows + 1)    # row -1 is index row 0
	var passable: PackedByteArray = PackedByteArray()
	var grounded: PackedByteArray = PackedByteArray()
	passable.resize(cells)
	grounded.resize(cells)
	for row: int in range(-1, grid.rows):
		for col: int in cols:
			var i: int = (row + 1) * cols + col
			if row < 0:
				passable[i] = 1
				continue
			var inside: bool = grid.has_profile(col, row) or grid.is_tar(col, row)
			passable[i] = 1 if grid.side_at(col, row) != TileGrid.SIDE_WALL or inside else 0
			grounded[i] = 1 if inside or TileGrid.is_ground(grid.floor_at(col, row + 1)) else 0
	if passable[(far.y + 1) * cols + far.x] == 0:
		return false
	# State: cell index * STATES + rise * 2 + descended.
	var states: int = (FLOOD_RISE_ROWS + 1) * 2
	var seen: PackedByteArray = PackedByteArray()
	seen.resize(cells * states)
	var stack: PackedInt32Array = PackedInt32Array()
	for start: Vector2i in starts:
		var cell: Vector2i = Vector2i(Tuning.to_cell(start.x), Tuning.to_cell(start.y - 1))
		if cell.x < 0 or cell.x >= cols or cell.y < -1 or cell.y >= grid.rows:
			continue
		var state: int = ((cell.y + 1) * cols + cell.x) * states
		if seen[state] == 0:
			seen[state] = 1
			stack.append(state)
	var far_index: int = (far.y + 1) * cols + far.x
	while not stack.is_empty():
		var state: int = stack[stack.size() - 1]
		stack.resize(stack.size() - 1)
		var index: int = state / states
		if index == far_index:
			return true
		var rise: int = (state % states) >> 1
		var descended: int = state & 1
		var col: int = index % cols
		var row: int = index / cols - 1
		for dy: int in [-1, 0, 1]:
			var next_row: int = row + dy
			if next_row < -1 or next_row >= grid.rows:
				continue
			for dx: int in [-1, 0, 1]:
				var next_col: int = col + dx
				if (dx == 0 and dy == 0) or next_col < maxi(columns.x, 0) or next_col >= mini(columns.y, cols):
					continue
				var next: int = (next_row + 1) * cols + next_col
				if passable[next] == 0:
					continue
				var next_state: int = -1
				if grounded[next] == 1:
					# Ground under the feet (a landing, a walk, or the one-row catch onto a wall top): rise resets.
					next_state = next * states
				elif dy < 0:
					if descended == 0 and rise + 1 <= FLOOD_RISE_ROWS:
						next_state = next * states + ((rise + 1) << 1)
				elif dy > 0:
					next_state = next * states + (rise << 1) + 1
				else:
					next_state = next * states + (rise << 1) + descended
				if next_state >= 0 and seen[next_state] == 0:
					seen[next_state] = 1
					stack.append(next_state)
	return false


## The columns the search can touch, [first, end): its area and its starts, each widened by CACHE_MARGIN_COLS (the
## search expands only resting points inside the area or at a start, and one macro run moves the hero at most 30
## columns). [method flood_reaches] keeps to them, so its refusal speaks for the search.
static func search_columns(area: Rect2i, starts: Array[Vector2i], grid: TileGrid) -> Vector2i:
	var first: int = area.position.x
	var end: int = area.end.x
	for start: Vector2i in starts:
		first = mini(first, Tuning.to_cell(start.x))
		end = maxi(end, Tuning.to_cell(start.x) + 1)
	return Vector2i(maxi(first - CACHE_MARGIN_COLS, 0), mini(end + CACHE_MARGIN_COLS, grid.cols))


## Columns beyond the gate's area that one macro run can still touch: a run lasts at most 48 + SETTLE_TICKS ticks at
## no more than 5 px per tick (30 columns); 40 leaves room for a slide.
const CACHE_MARGIN_COLS: int = 40


## The cache key of an explore: everything the search's outcome depends on - the grid's cells in every row of the
## columns a run from a node of `area` can reach, the meta (ice, liquids ...), the starts, the far cell and the area.
static func _explore_key(grid: TileGrid, meta: Dictionary, starts: Array[Vector2i], far: Vector2i,
		area: Rect2i) -> String:
	var first: int = maxi(area.position.x - CACHE_MARGIN_COLS, 0)
	var last: int = mini(area.end.x + CACHE_MARGIN_COLS, grid.cols)
	var rows: PackedStringArray = PackedStringArray()
	for row: int in grid.rows:
		var line: String = ""
		for col: int in range(first, last):
			line += grid.get_char(col, row)
		rows.append(line)
	return "%d|%d|%d|%d|%s|%s|%s" % [first, grid.rows, "\n".join(rows).hash(), str(meta).hash(), str(starts),
		str(far), str(area)]


static func _fresh_result() -> Dictionary:
	return {"reached": false, "bound": BOUND_TICKS, "windows": [], "detail": "", "starts": [], "explored": 0}


static func _unproven(result: Dictionary, why: String) -> Dictionary:
	result["reached"] = true
	result["detail"] = "unproven: " + why
	return result


## The file of a level id (the registry's path when the Levels autoload knows it, else res://levels/<id>.lvl).
static func level_path(level_id: StringName) -> String:
	var registry: Object = (Engine.get_main_loop() as SceneTree).root.get_node_or_null(^"Levels") \
			if Engine.get_main_loop() is SceneTree else null
	if registry != null and registry.has_method(&"get_level_path"):
		var path: String = str(registry.call(&"get_level_path", level_id))
		if path != "":
			return path
	return "res://levels/%s.lvl" % level_id


## The tablet of `gate` in `difficulty` (LevelValidator.parse_tablet), {} when there is none.
static func find_tablet(data: LevelData, difficulty: int, gate: String) -> Dictionary:
	for record: Dictionary in data.entity_records():
		if String(record["id"]) != "objects/x2_tablet" or not LevelText.applies_to(record["params"], difficulty):
			continue
		var tablet: Dictionary = LevelValidator.parse_tablet(record)
		if tablet["gate"] == gate:
			return tablet
	return {}


## The first static rule of the validator this file breaks for `gate` ("" when none).
static func static_problem(data: LevelData, gate: String) -> String:
	var validator: LevelValidator = LevelValidator.new()
	validator.add_data(data)
	validator.run()
	for problem: Dictionary in validator.problems:
		if int(problem["severity"]) != LevelValidator.ERROR:
			continue
		var message: String = str(problem["message"])
		if message.contains("gate '%s'" % gate):
			return message
		for fragment: String in STATIC_FRAGMENTS:
			if message.contains(fragment):
				return message
	return ""


## The grid of `data` in `difficulty` at rest, with the static blocks (`objects/column rise=0`, e.g. the Expert row
## of a boost ledge [R18]) filled in.
static func grid_at_rest(data: LevelData, difficulty: int) -> TileGrid:
	var grid: TileGrid = data.build_grid(difficulty)
	for record: Dictionary in data.entity_records():
		var params: Dictionary = record["params"]
		if String(record["id"]) != "objects/column" or not LevelText.applies_to(params, difficulty):
			continue
		if int(params.get("rise", 2)) != 0 or params.has("rise_while") or params.has("sink_while") \
				or params.has("trigger"):
			continue
		var size: PackedInt32Array = LevelText.to_int_list(params.get("size", "1,1"))
		var w: int = maxi(size[0], 1) if size.size() >= 1 else 1
		var h: int = maxi(size[1], 1) if size.size() >= 2 else 1
		var col: int = int(record["col"])
		var row: int = int(record["row"])
		for r: int in range(row - h + 1, row + 1):
			for c: int in range(col, col + w):
				if grid.in_bounds(c, r) and grid.get_char(c, r) == TileGrid.CH_AIR:
					grid.set_char(c, r, TileGrid.CH_SOLID_A)
	return grid


## The gate's area in cells: its tablet and far cell grown by one view, inside the map.
static func gate_area(tablet: Dictionary, grid: TileGrid) -> Rect2i:
	var area: Rect2i = Rect2i(tablet["cell"], Vector2i.ONE).merge(Rect2i(tablet["far"], Vector2i.ONE))
	area = area.grow_individual(AREA_COLS, AREA_ROWS, AREA_COLS, AREA_ROWS)
	return area.intersection(Rect2i(0, 0, grid.cols, grid.rows))


## Where the search starts: the tablet's cell and the last checkpoint before it (by column; '@' when there is none),
## each as a feet point on the floor below.
static func start_points(data: LevelData, difficulty: int, tablet: Dictionary, grid: TileGrid) -> Array[Vector2i]:
	var cell: Vector2i = tablet["cell"]
	var points: Array[Vector2i] = [_ground_below(grid, cell)]
	var best: Vector2i = Vector2i(-1, -1)
	for record: Dictionary in data.entity_records():
		if String(record["id"]) != "objects/checkpoint" or not LevelText.applies_to(record["params"], difficulty):
			continue
		var at: Vector2i = Vector2i(int(record["col"]), int(record["row"]))
		if at.x <= cell.x and at.x > best.x:
			best = at
	if best == Vector2i(-1, -1):
		var starts: Array[Vector2i] = data.find_starts()
		if not starts.is_empty() and starts[0].x <= cell.x:
			best = starts[0]
	if best != Vector2i(-1, -1):
		var point: Vector2i = _ground_below(grid, best)
		if not points.has(point):
			points.append(point)
	return points


## Feet point on the first floor at or below `cell` (the cell's own bottom when there is none).
static func _ground_below(grid: TileGrid, cell: Vector2i) -> Vector2i:
	var row: int = cell.y
	while row < grid.rows - 1 and not TileGrid.is_ground(grid.floor_at(cell.x, row + 1)):
		row += 1
	return LevelText.cell_to_feet(float(cell.x), float(row))


static func node_key(pos: Vector2i) -> Vector2i:
	return Vector2i(pos.x / KEY_PX, pos.y)


## The input macros of the search (one hero, from rest): `name`, `facing`, `flags` (one Defs.IN_* mask per tick).
static func make_macros() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var up: int = Defs.IN_UP
	for dir: int in [Defs.IN_RIGHT, Defs.IN_LEFT]:
		var facing: int = 1 if dir == Defs.IN_RIGHT else -1
		var side: String = "R" if dir == Defs.IN_RIGHT else "L"
		var back: int = Defs.IN_LEFT if dir == Defs.IN_RIGHT else Defs.IN_RIGHT
		for steps: int in [4, 10, 24, 48]:
			result.append({"name": "walk %s%d" % [side, steps], "facing": facing, "flags": _repeat(dir, steps)})
		result.append({"name": "jump %s" % side, "facing": facing,
			"flags": _repeat(up | dir, 9) + _repeat(dir, 16)})
		result.append({"name": "hop %s" % side, "facing": facing, "flags": _repeat(up | dir, 4) + _repeat(dir, 10)})
		result.append({"name": "run-jump %s" % side, "facing": facing,
			"flags": _repeat(dir, 6) + _repeat(up | dir, 9) + _repeat(dir, 18)})
		result.append({"name": "jump-back %s" % side, "facing": facing,
			"flags": _repeat(up | dir, 9) + _repeat(back, 12)})
		result.append({"name": "rise-then-%s" % side, "facing": facing,
			"flags": _repeat(up, 6) + _repeat(up | dir, 4) + _repeat(dir, 14)})
		result.append({"name": "crawl %s" % side, "facing": facing, "flags": _repeat(Defs.IN_DOWN | dir, 24)})
	result.append({"name": "jump up", "facing": 1, "flags": _repeat(up, 12)})
	result.append({"name": "drop", "facing": 1, "flags": _repeat(Defs.IN_DOWN, 10)})
	return result


static func _repeat(flags: int, count: int) -> PackedInt32Array:
	var result: PackedInt32Array = PackedInt32Array()
	result.resize(count)
	result.fill(flags)
	return result


# =================================================================================================================
# Windows (DESIGN.md D.8 #4)
# =================================================================================================================

## Every twin window and daze record inside `area` with the solo minimum measured: drum bonds, enemy bonds, `daze`
## enemies, timed plates.
static func measure_windows(data: LevelData, difficulty: int, area: Rect2i, searcher: Searcher) -> Array:
	var windows: Array = []
	var groups: Dictionary = {}   # "drums:<bond>" / "bond:<bond>" -> Array of cells
	var plates: Dictionary = {}
	var columns: Array[Dictionary] = []
	var grid: TileGrid = searcher.level.grid
	for record: Dictionary in data.entity_records():
		var params: Dictionary = record["params"]
		if not LevelText.applies_to(params, difficulty):
			continue
		var id: String = String(record["id"])
		var cell: Vector2i = Vector2i(int(record["col"]), int(record["row"]))
		if id == "objects/drum" and params.has("bond"):
			_append_cell(groups, "drums:" + str(params["bond"]), cell)
		elif Spawner.category(StringName(id)) == "enemies" and str(params.get("coop", "")) == "bond" \
				and params.has("bond"):
			_append_cell(groups, "bond:" + str(params["bond"]), cell)
		if Spawner.category(StringName(id)) == "enemies" and area.has_point(cell) \
				and (str(params.get("coop", "")) == "daze" or id == "enemies/raptor"):
			windows.append({"what": "daze %s at %d,%d" % [id, cell.x, cell.y],
				"window": PartyTuning.daze_ticks(difficulty), "solo_min": measure_daze_solo_min(id)})
		if id == "objects/plate" and params.has("name") and str(params.get("mode", "")).begins_with("timed:"):
			plates[str(params["name"])] = record
		if id == "objects/column" and (params.has("rise_while") or params.has("sink_while")):
			columns.append(record)
	for key: String in groups:
		var cells: Array = groups[key]
		var inside: bool = false
		for cell: Vector2i in cells:
			inside = inside or area.has_point(cell)
		if not inside or cells.size() < 2:
			continue
		var solo_min: int = 0
		for i: int in cells.size():
			for j: int in range(i + 1, cells.size()):
				solo_min = maxi(solo_min, pair_solo_min(cells[i], cells[j], grid, area, searcher))
		windows.append({"what": key.replace(":", " "), "window": PartyTuning.window_ticks(difficulty),
			"solo_min": solo_min})
	for plate_name: String in plates:
		var plate: Dictionary = plates[plate_name]
		var plate_cell: Vector2i = Vector2i(int(plate["col"]), int(plate["row"]))
		if not area.has_point(plate_cell):
			continue
		var timer: int = str(plate["params"]["mode"]).substr(6).to_int()
		for column: Dictionary in columns:
			var names: String = str(column["params"].get("rise_while", column["params"].get("sink_while", "")))
			if not LevelText.to_list(names).has(plate_name):
				continue
			var rise: int = int(column["params"].get("rise", 2))
			var door: Vector2i = Vector2i(int(column["col"]), int(column["row"]))
			var travel: int = travel_ticks([_ground_below(grid, plate_cell)], _door_spots(grid, door), area, searcher)
			windows.append({"what": "timed plate %s" % plate_name,
				"window": timer + rise * PartyTuning.PLATE_COLUMN_PERIOD, "solo_min": travel})
	return windows


## The least ticks one hero needs between striking the member at `a` and the member at `b` (either order): 0 when a
## thrown special from a strike spot of one crosses the other, else the run between their strike spots (BOUND_TICKS
## when he cannot get there).
static func pair_solo_min(a: Vector2i, b: Vector2i, grid: TileGrid, area: Rect2i, searcher: Searcher) -> int:
	var spots_a: Array[Vector2i] = strike_spots(grid, a)
	var spots_b: Array[Vector2i] = strike_spots(grid, b)
	if throw_crosses(spots_a, b) or throw_crosses(spots_b, a):
		return 0
	var goals: Dictionary = {}
	for spot: Vector2i in spots_b:
		goals[Vector2i(Tuning.to_cell(spot.x), Tuning.to_cell(spot.y - 1))] = true
	return travel_ticks(spots_a, goals, area, searcher)


## Ticks of the shortest search path from `starts` into a cell of `goals` (BOUND_TICKS when none within the bound).
static func travel_ticks(starts: Array[Vector2i], goals: Dictionary, area: Rect2i, searcher: Searcher) -> int:
	if starts.is_empty() or goals.is_empty():
		return BOUND_TICKS
	var found: Dictionary = searcher.explore(starts, goals, area, BOUND_TICKS, MAX_NODES)
	return int(found["ticks"]) if found["reached"] else BOUND_TICKS


## Feet points from which a strike reaches the cell `target`: standing cells one or two columns beside it, with the
## target up to two rows above the feet row (forward, high and low boxes, PHYSICS.md 8.2).
static func strike_spots(grid: TileGrid, target: Vector2i) -> Array[Vector2i]:
	var spots: Array[Vector2i] = []
	for dc: int in [-2, -1, 1, 2]:
		for dr: int in [0, 1, 2]:
			var cell: Vector2i = Vector2i(target.x + dc, target.y + dr)
			if not grid.in_bounds(cell.x, cell.y + 1) or grid.side_at(cell.x, cell.y) == TileGrid.SIDE_WALL:
				continue
			if TileGrid.is_ground(grid.floor_at(cell.x, cell.y + 1)):
				spots.append(LevelText.cell_to_feet(float(cell.x), float(cell.y)))
	return spots


## Standing spots beside a door block (one or two columns either side of its anchor).
static func _door_spots(grid: TileGrid, door: Vector2i) -> Dictionary:
	var goals: Dictionary = {}
	for spot: Vector2i in strike_spots(grid, door):
		goals[Vector2i(Tuning.to_cell(spot.x), Tuning.to_cell(spot.y - 1))] = true
	return goals


## True when an axe, a swirling axe or a spear thrown either way from one of `spots` (no tile collision: they pass
## walls, PHYSICS.md 8.4 / C.3) crosses the cell `target` within 40 ticks.
static func throw_crosses(spots: Array[Vector2i], target: Vector2i) -> bool:
	var box: Rect2i = Rect2i(target.x * Tuning.TILE, target.y * Tuning.TILE, Tuning.TILE, Tuning.TILE)
	for spot: Vector2i in spots:
		for facing: int in [1, -1]:
			for kind: int in [Defs.Weapon.AXE, Defs.Weapon.BOOMERANG, Defs.Weapon.SPEAR]:
				var pos: Vector2i = spot + Vector2i(facing * 20, -16)
				var xvel: int = (Tuning.SPEAR_XVEL if kind == Defs.Weapon.SPEAR else Tuning.THROW_XVEL) * facing
				var yvel: int = Tuning.AXE_YVEL if kind == Defs.Weapon.AXE else (Tuning.BOOMERANG_YVEL
						if kind == Defs.Weapon.BOOMERANG else 0)
				for t: int in 40:
					pos += Vector2i(Tuning.floor16(xvel), Tuning.floor16(yvel))
					match kind:
						Defs.Weapon.AXE:
							yvel += Tuning.AXE_YACC
						Defs.Weapon.BOOMERANG:
							yvel += Tuning.BOOMERANG_YACC
						_:
							if t >= Tuning.SPEAR_FLAT_TICKS:
								yvel = mini(yvel + 16, Tuning.SPEAR_FALL_MAX)
					if Overlap.rects(Rect2i(pos.x - 8, pos.y - 16, 16, 16), box):
						return true
	return false


static func _append_cell(groups: Dictionary, key: String, cell: Vector2i) -> void:
	if not groups.has(key):
		groups[key] = []
	(groups[key] as Array).append(cell)


# --- The daze: ticks from a head bounce to the first damaging box -------------------------------------------------------

static var _daze_cache: Dictionary = {}


## The solo minimum of a `daze` record (DESIGN.md D.6, R12): the least ticks the real hero needs from his head bounce
## on a still target the size of `enemy_id` (its scene's box; 32 x 32 without one) to the first strike that hits it,
## over approaches from both sides with forward, low and high strikes started 0-12 ticks after the bounce. Measured
## once per box.
static func measure_daze_solo_min(enemy_id: String) -> int:
	var box: Vector3i = Vector3i(32, 32, 16)
	if Spawner.exists(StringName(enemy_id)):
		var probe: SimEntity = Spawner.instantiate(StringName(enemy_id)) as SimEntity
		if probe != null:
			box = Vector3i(probe.box_w, probe.box_h, probe.box_xo)
			probe.free()
	if _daze_cache.has(box):
		return int(_daze_cache[box])
	var rows: PackedStringArray = PackedStringArray()
	for row: int in 16:
		rows.append((TileGrid.CH_SOLID_A if row >= 14 else TileGrid.CH_AIR).repeat(30))
	var searcher: Searcher = Searcher.new()
	if not searcher.build(&"coop_search_daze", {}, TileGrid.from_rows(rows)):
		return BOUND_TICKS
	var target: EnemyBase = EnemyBase.new()
	target.set_box(box)
	target.spawn_setup(Vector2i(240, 224), {})
	searcher.level.add_child(target)
	target.max_hp = 99999
	target.hp = 99999
	var best: int = BOUND_TICKS
	var strikes: Array[int] = [Defs.IN_FIRE, Defs.IN_DOWN | Defs.IN_FIRE, Defs.IN_UP | Defs.IN_FIRE]
	for side: int in [-1, 1]:
		var dir: int = Defs.IN_RIGHT if side < 0 else Defs.IN_LEFT
		for distance: int in [36, 52, 68]:
			for hold: int in [5, 9]:
				for strike: int in strikes:
					for delay: int in 13:
						var ticks: int = _daze_run(searcher, target, Vector2i(240 + side * distance, 224), -side, dir,
								hold, strike, delay)
						if ticks >= 0:
							best = mini(best, ticks)
	target.free()
	searcher.close()
	_daze_cache[box] = best
	return best


## One approach of [method measure_daze_solo_min]: jump at the target, then strike `delay` ticks after the bounce.
## Ticks from the bounce to the first hit, -1 when there was none.
static func _daze_run(searcher: Searcher, target: EnemyBase, start: Vector2i, facing: int, dir: int, hold: int,
		strike: int, delay: int) -> int:
	var hero: PlayerBase = searcher.hero
	target.teleport(Vector2i(240, 224))
	target.wake()
	target.bounce_count = 0
	target.last_hit_tick = -1
	hero.run.reset_energy()
	hero.respawn_at(start)
	hero.facing = facing
	var flags: PackedInt32Array = _repeat(Defs.IN_UP | dir, hold) + _repeat(dir, 30)
	searcher._flags = flags
	searcher._first_tick = Sim.tick + 1
	var bounce_tick: int = -1
	for t: int in 60:
		Sim.step(1)
		if hero.dead:
			return -1
		if bounce_tick < 0 and target.bounce_count > 0:
			bounce_tick = Sim.total_ticks
			# From the bounce on: nothing for `delay` ticks, then the strike held for a swing.
			var index: int = Sim.tick + 1 - searcher._first_tick
			var rest: PackedInt32Array = _repeat(0, delay) + _repeat(strike, STRIKE_FRAMES + 4)
			searcher._flags = flags.slice(0, index) + rest
		if bounce_tick >= 0 and target.last_hit_tick >= bounce_tick:
			return target.last_hit_tick - bounce_tick
	return -1
