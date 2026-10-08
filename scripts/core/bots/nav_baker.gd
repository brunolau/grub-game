class_name NavBaker
extends RefCounted
## Bakes a level's [NavGraph] (PLAN.md P1.2 / P2.5, DESIGN.md E.7): nodes are the standable spans of the collision
## grid (and the tops of the movers), links are moves found and verified by simulating the real hero ([NavSim]).
##
## Owner: core-B. Used by tools/bots/bake_nav.gd (offline, writes res://resources/bots/<level_id>.json) and by the
## tests. Steps:
##  1. Nodes: every run of columns of one row whose floor the hero can stand on (a floor tile - solid, one-way, ice,
##     hatch - with the cell above free of floors and walls and nothing deadly at body height). The walkable x range
##     honours the wall probe (9 px) and the level bounds. Each node is checked by standing the hero on it. Then the
##     movers ([NavMovers]: platforms, pulley lifts, see-saw ends, drop platforms) at their level-start places.
##  2. Candidates, per weight class (NavGraph.weight_classes_for: the classes the arena's modes need; the sim hero gets
##     that class's walk cap and jump impulses): from every node, from rest at take-off points every SAMPLE_STEP px
##     (and both ends), every script of [method scripts_for] (walk-offs, running and standing jumps with UP held
##     1..14 ticks, air control) is simulated until the landing. A landing on another node, alive and settled, is a
##     candidate. Geysers: from rest in the vent, the geyser spouting on the first tick, the air scripts of
##     [method geyser_scripts]. Movers: see [NavMovers].
##  3. Windows: per (source, target) pair the fastest candidates are widened 1 px at a time while the start still
##     lands on the target; EVERY integer x of the final window was simulated. A link needs a window of at least
##     MIN_WINDOW px; the fastest one is kept, plus the widest when it is much wider.
## The bake is deterministic (no RNG; fixed iteration order), so a re-bake of an unchanged level gives the same file.
##
## Frames (core-B wf10, wf10_content_to_core-B.txt #3): the bake is a list of jobs (one class start, one source node,
## one mover phase, one pulley state at a time) run in a fixed order. [method bake_text] runs them all in one go;
## [method bake_text_in_frames] (await it) lets the engine finish a frame every FRAME_CANDIDATES candidate runs, and
## gives the same graph. A long bake NEEDS the frames: every sim run frees and spawns the movers and effects of the
## level, each canvas node that enters the tree queues one redraw callback, and the engine empties that queue (32 MB,
## about 1.4 million callbacks) only between frames - a bake of some 130 000 runs in one go overflows it and the
## engine crashes. A level with pulley lifts is such a bake (its lifts get links at every pulley state); the tool
## (tools/bots/bake_nav.gd) always bakes in frames.

const VERSION: int = 3
## Take-off points are sampled this far apart along a node.
const SAMPLE_STEP: int = 8
## Narrowest take-off window kept (px) and the widest one searched.
const MIN_WINDOW: int = 4
const MAX_WINDOW: int = 24
## Window seeds tried per (source, target) pair, fastest first.
const MAX_SEEDS_PER_PAIR: int = 8
## Simulation limit of one candidate (ticks).
const MAX_TICKS: int = 90
## A link's landings keep this far inside an open end of the target node ([method _lands_clear]).
const EDGE_MARGIN_PX: int = 6
## Length of the open-ended scripts (ticks; the landing ends them).
const SCRIPT_TICKS: int = 72
## Take-off points in a geyser vent are sampled this far apart.
const GEYSER_SAMPLE_STEP: int = 4
## [method bake_text_in_frames]: candidate runs between two frames (a job is never split, so a slice may run longer).
const FRAME_CANDIDATES: int = 2000

var sim: NavSim = NavSim.new()
var graph: NavGraph = null
## Human-readable report lines (the tool prints them).
var report: PackedStringArray = PackedStringArray()
## Statistics.
var candidates: int = 0
var verified_starts: int = 0
var rejected: int = 0
## Print progress every this many candidates (0 = quiet; the tool's --verbose).
var progress_every: int = 0
## The mover part of the bake (null until [method begin_bake] runs).
var movers: NavMovers = null
var _started_msec: int = 0
# The bake as jobs in their order ([method begin_bake]) and the next one to run ([method step_bake]).
var _jobs: Array[Callable] = []
var _next_job: int = 0

var _grid: TileGrid = null
var _clip: Rect2i = Rect2i()
var _weight: int = NavGraph.WEIGHT_LIGHT
# Cache of simulated starts: "geyser:node:script:x" -> landing node id (-1 = no landing on a node); per weight class.
var _memo: Dictionary = {}
var _memo_ticks: Dictionary = {}
var _memo_land: Dictionary = {}
var _memo_sprung: Dictionary = {}
var _memo_walked: Dictionary = {}
# The pulley-lift part the run rode on the way (-1 = none) and that part's state at the take-off.
var _memo_touch: Dictionary = {}
var _memo_state: Dictionary = {}
var _scripts: Array[PackedInt32Array] = []
var _script_keys: PackedStringArray = PackedStringArray()
var _script_dirs: PackedInt32Array = PackedInt32Array()
# Script ids of the ground moves and of the geyser flights.
var _ground_scripts: PackedInt32Array = PackedInt32Array()
var _air_scripts: PackedInt32Array = PackedInt32Array()


## Bake the graph of the level file at `path` (res:// path) for `difficulty`; `parent` hosts the sim world while it
## runs. Null (and an error) when the file cannot be read. `classes`: the weight classes (empty = the arena's).
func bake_file(parent: Node, path: String, difficulty: int = Defs.Difficulty.BEGINNER,
		classes: PackedInt32Array = PackedInt32Array(), clip: Rect2i = Rect2i()) -> NavGraph:
	if not FileAccess.file_exists(path):
		push_error("NavBaker: %s does not exist" % path)
		return null
	var text: String = FileAccess.get_file_as_string(path)
	return bake_text(parent, StringName(path.get_file().get_basename()), text, difficulty, classes, clip)


## [method bake_file] in frames (await it; see [method bake_text_in_frames]).
func bake_file_in_frames(parent: Node, path: String, difficulty: int = Defs.Difficulty.BEGINNER,
		classes: PackedInt32Array = PackedInt32Array(), clip: Rect2i = Rect2i()) -> NavGraph:
	if not FileAccess.file_exists(path):
		push_error("NavBaker: %s does not exist" % path)
		return null
	var text: String = FileAccess.get_file_as_string(path)
	return await bake_text_in_frames(parent, StringName(path.get_file().get_basename()), text, difficulty, classes,
			clip)


## Bake the graph of a level given as file text, in one go. `classes`: weight classes to bake (NavGraph.WEIGHT_*; empty
## = those of the arena's modes); `clip`: cells to bake (empty = the whole grid; a boss arena inside a bigger level).
## A long bake (a level with pulley lifts) must run in frames instead: [method bake_text_in_frames].
func bake_text(parent: Node, level_id: StringName, text: String, difficulty: int = Defs.Difficulty.BEGINNER,
		classes: PackedInt32Array = PackedInt32Array(), clip: Rect2i = Rect2i()) -> NavGraph:
	if not begin_bake(parent, level_id, text, difficulty, classes, clip):
		return null
	step_bake(0)
	return end_bake()


## [method bake_text] with a frame of the engine after every FRAME_CANDIDATES candidate runs (await it; `parent` must be
## in the tree): the same graph, and the engine's callback queue is emptied on the way (see the header). The sim world
## stays set up between the slices (NavSim owns the simulation: Sim.manual), so nothing else may run a level meanwhile.
func bake_text_in_frames(parent: Node, level_id: StringName, text: String,
		difficulty: int = Defs.Difficulty.BEGINNER, classes: PackedInt32Array = PackedInt32Array(),
		clip: Rect2i = Rect2i()) -> NavGraph:
	if not begin_bake(parent, level_id, text, difficulty, classes, clip):
		return null
	while step_bake(FRAME_CANDIDATES):
		await parent.get_tree().process_frame
	return end_bake()


## Set up a bake (the sim world under `parent`, the nodes, the jobs of every weight class); false when the sim cannot
## be set up. Then call [method step_bake] until it returns false, then [method end_bake].
func begin_bake(parent: Node, level_id: StringName, text: String, difficulty: int = Defs.Difficulty.BEGINNER,
		classes: PackedInt32Array = PackedInt32Array(), clip: Rect2i = Rect2i()) -> bool:
	var data: LevelData = LevelData.parse(level_id, text, "%s.lvl" % level_id)
	var grid: TileGrid = data.build_grid(difficulty)
	var meta: Dictionary = data.resolved_meta(difficulty)
	graph = NavGraph.new()
	graph.level_id = level_id
	graph.source_sha256 = NavGraph.text_sha256(text)
	graph.difficulty = Defs.difficulty_name(difficulty)
	graph.cols = grid.cols
	graph.rows = grid.rows
	graph.wrap = str(meta.get("wrap", "none"))
	graph.weights = classes.duplicate() if not classes.is_empty() else NavGraph.weight_classes_for(meta)
	graph.weights.sort()
	_clip = clip
	if clip.size.x > 0 and clip.size.y > 0:
		graph.clip = PackedInt32Array([clip.position.x, clip.position.y, clip.size.x, clip.size.y])
	_jobs.clear()
	_next_job = 0
	if not sim.setup(parent, level_id, grid, meta, data.entity_records()):
		return false
	_grid = grid
	_started_msec = Time.get_ticks_msec()
	_build_scripts()
	movers = NavMovers.new(self)
	_weight = NavGraph.WEIGHT_LIGHT
	sim.weight_class = _weight
	_find_nodes()
	movers.find_nodes()
	for weight_class: int in graph.weights:
		_jobs.append(_begin_class.bind(weight_class))
		for from: int in graph.nodes.size():
			if graph.nodes[from].mover < 0:  # the mover nodes belong to NavMovers
				_jobs.append(_links_from_node.bind(from))
		_jobs.append(_find_geyser_links)
		movers.add_jobs(_jobs)
	return true


## Run the next jobs of the bake: all that are left (`budget` 0), or jobs until `budget` candidate runs were simulated
## in this call. True while jobs are left.
func step_bake(budget: int = 0) -> bool:
	var until: int = candidates + budget
	while _next_job < _jobs.size():
		_jobs[_next_job].call()
		_next_job += 1
		if budget > 0 and candidates >= until:
			break
	return _next_job < _jobs.size()


## Finish the bake: the sim world is removed, the statistics and the report line are written; the graph.
func end_bake() -> NavGraph:
	_jobs.clear()
	_next_job = 0
	sim.teardown()
	graph.baker = {
		"version": VERSION, "candidates": candidates, "simulated_ticks": sim.ticks_simulated,
		"verified_starts": verified_starts, "rejected": rejected,
	}
	report.append("%s: %d nodes (%d on movers), %d links (classes %s), %d candidates, %d ticks simulated, %d ms" % [
		graph.level_id, graph.nodes.size(), movers.node_count, graph.links.size(), Array(graph.weights), candidates,
		sim.ticks_simulated, Time.get_ticks_msec() - _started_msec,
	])
	if movers.clear_count > 0:
		report.append("%s: %d links past a pulley lift's column hold in some pulley states only (`clear`)" % [
			graph.level_id, movers.clear_count,
		])
	if graph.wrap != "none" and not sim.wrap_step.is_valid():
		report.append("%s: wrap = %s: no wrap step available, links across the seam are left out" % [
			graph.level_id, graph.wrap,
		])
	return graph


## Job: the links of weight class `weight_class` start here (the sim hero gets its limits, the run caches are emptied).
func _begin_class(weight_class: int) -> void:
	_weight = weight_class
	sim.weight_class = weight_class
	_clear_memo()
	movers.begin_class()


func _clear_memo() -> void:
	_memo.clear()
	_memo_ticks.clear()
	_memo_land.clear()
	_memo_sprung.clear()
	_memo_walked.clear()
	_memo_touch.clear()
	_memo_state.clear()


# =================================================================================================================
# 1. Nodes
# =================================================================================================================

## True when a hero can stand on the floor tile (col, row): a floor he lands on, no floor or wall in the cell above,
## nothing deadly in the cells of his body.
static func is_standable(grid: TileGrid, col: int, row: int) -> bool:
	if not grid.in_bounds(col, row) or row < 1:
		return false
	var floor_value: int = grid.floor_at(col, row)
	if floor_value == TileGrid.FLOOR_EMPTY or floor_value == TileGrid.FLOOR_DEADLY \
			or floor_value == TileGrid.FLOOR_NOTHING:
		return false
	if grid.floor_at(col, row - 1) != TileGrid.FLOOR_EMPTY or grid.side_at(col, row - 1) != TileGrid.SIDE_OPEN:
		return false
	for up: int in range(2, 4):
		if row - up >= 0 and grid.side_at(col, row - up) == TileGrid.SIDE_DEADLY:
			return false
	if row - 2 >= 0 and grid.ceiling_at(col, row - 2) == TileGrid.CEILING_DEADLY:
		return false
	return true


## The standable spans of a grid as nodes (no simulation): one per run of standable columns in a row; only cells
## inside `clip` when it is not empty.
static func span_nodes(grid: TileGrid, clip: Rect2i = Rect2i()) -> Array[NavGraph.NavNode]:
	var result: Array[NavGraph.NavNode] = []
	var x_min: int = Tuning.X_MIN
	var x_max: int = grid.x_max_excl() - 1
	var clipped: bool = clip.size.x > 0 and clip.size.y > 0
	for row: int in range(1, grid.rows):
		if clipped and (row < clip.position.y or row >= clip.end.y):
			continue
		var col: int = 0
		while col < grid.cols:
			if not is_standable(grid, col, row) or (clipped and (col < clip.position.x or col >= clip.end.x)):
				col += 1
				continue
			var first: int = col
			while col < grid.cols and is_standable(grid, col, row) \
					and (not clipped or (col >= clip.position.x and col < clip.end.x)):
				col += 1
			var last: int = col - 1
			var node: NavGraph.NavNode = NavGraph.NavNode.new()
			node.row = row
			node.y = row * Tuning.TILE
			node.x0 = first * Tuning.TILE
			node.x1 = last * Tuning.TILE + Tuning.TILE - 1
			# The wall probe stops a walking hero 9 px before a wall in the row above his feet.
			if grid.side_at(first - 1, row - 1) == TileGrid.SIDE_WALL:
				node.x0 = first * Tuning.TILE + Tuning.WALL_PROBE
			if grid.side_at(last + 1, row - 1) == TileGrid.SIDE_WALL:
				node.x1 = (last + 1) * Tuning.TILE - Tuning.WALL_PROBE - 1
			node.x0 = maxi(node.x0, x_min)
			node.x1 = mini(node.x1, x_max)
			node.ice = TileGrid.floor_ice(grid.floor_at(first, row))
			if node.x0 <= node.x1:
				result.append(node)
	return result


func _find_nodes() -> void:
	for node: NavGraph.NavNode in span_nodes(_grid, _clip):
		# Stand him on it: he must stay put (no slip off a corner, no fall); where his feet settle is the node's y (a
		# tar floor is lower than the tile top).
		var at: Vector2i = Vector2i(node.center_x(), node.y)
		var outcome: NavSim.Outcome = sim.run(at, _neutral(3), 12)
		if outcome.died or not (outcome.walked or outcome.landed) or outcome.pos.x != at.x \
				or (outcome.pos.y >> 4) != node.row:
			rejected += 1
			report.append("node rejected: row %d x %d..%d (he does not stand at %s)" % [node.row, node.x0, node.x1, at])
			continue
		node.y = outcome.pos.y
		graph.add_node(node)


# =================================================================================================================
# 2. Candidates and 3. windows
# =================================================================================================================

## The scripts tried from every take-off point, for direction `d` (+1 right, -1 left): walk-offs with and without
## braking, standing and running jumps with UP held 3, 8 or 14 ticks and three kinds of air control, and straight
## jumps. Run-length strings ("6:R,8:RU,58:R").
static func scripts_for(d: int) -> PackedStringArray:
	var go: String = "R" if d > 0 else "L"
	var back: String = "L" if d > 0 else "R"
	var result: PackedStringArray = PackedStringArray()
	# Short walks (across a wrap seam, off an edge close by).
	for walk: int in [4, 8, 14]:
		result.append("%d:%s" % [walk, go])
	# Walk-offs: walk, then keep walking / let go / brake.
	result.append("%d:%s" % [SCRIPT_TICKS, go])
	for walk: int in [6, 12, 24]:
		result.append("%d:%s,%d:" % [walk, go, SCRIPT_TICKS - walk])
		result.append("%d:%s,%d:%s" % [walk, go, SCRIPT_TICKS - walk, back])
	# Jumps: run-up, UP held k ticks with the direction, then air control.
	for run_up: int in [0, 5, 10]:
		for hold: int in [3, 8, 14]:
			var head: String = ("%d:%s," % [run_up, go] if run_up > 0 else "") + "%d:U%s" % [hold, go]
			var rest: int = SCRIPT_TICKS - run_up - hold
			result.append("%s,%d:%s" % [head, rest, go])
			result.append("%s,%d:" % [head, rest])
			result.append("%s,%d:%s" % [head, rest, back])
	# A straight jump, then drift.
	for hold: int in [8, 14]:
		result.append("%d:U,%d:%s" % [hold, SCRIPT_TICKS - hold, go])
	return result


## The air control tried after a geyser launch (the first tick is the spout), for direction `d` (0 = straight).
static func geyser_scripts(d: int) -> PackedStringArray:
	if d == 0:
		return PackedStringArray(["%d:" % SCRIPT_TICKS])
	var go: String = "R" if d > 0 else "L"
	var result: PackedStringArray = PackedStringArray(["%d:%s" % [SCRIPT_TICKS, go]])
	for wait: int in [6, 14, 22]:
		result.append("%d:,%d:%s" % [wait, SCRIPT_TICKS - wait, go])
	for push: int in [4, 10]:
		result.append("%d:%s,%d:" % [push, go, SCRIPT_TICKS - push])
	return result


func _build_scripts() -> void:
	_scripts.clear()
	_script_keys.clear()
	_script_dirs.clear()
	_ground_scripts.clear()
	_air_scripts.clear()
	var seen: Dictionary = {}
	# Straight up, no direction (one-way floors above).
	for script: String in ["14:U", "8:U"]:
		_ground_scripts.append(add_script(script, 0, seen))
	for d: int in [1, -1]:
		for script: String in scripts_for(d):
			_ground_scripts.append(add_script(script, d, seen))
	for d: int in [0, 1, -1]:
		for script: String in geyser_scripts(d):
			_air_scripts.append(add_script(script, d, seen))


## Register a script (once; its id is returned).
func add_script(script: String, d: int, seen: Dictionary) -> int:
	if seen.has(script):
		return int(seen[script])
	seen[script] = _scripts.size()
	_scripts.append(NavGraph.expand_keys(script))
	_script_keys.append(script)
	_script_dirs.append(d)
	return _scripts.size() - 1


## The flags of script `s`.
func script_flags(s: int) -> PackedInt32Array:
	return _scripts[s]


## Ground script ids (walks, walk-offs, jumps).
func ground_scripts() -> PackedInt32Array:
	return _ground_scripts


## The main direction of script `s` (+1 right, -1 left, 0 straight up).
func script_dir(s: int) -> int:
	return _script_dirs[s]


## Take-off points sampled on a node.
func _samples(node: NavGraph.NavNode) -> PackedInt32Array:
	var xs: PackedInt32Array = PackedInt32Array()
	var x: int = node.x0
	while x < node.x1:
		xs.append(x)
		x += SAMPLE_STEP
	xs.append(node.x1)
	return xs


## Simulate script `s` from rest at x on node `from` (cached; `geyser` >= 0: that geyser spouts on the first tick and
## must launch him): the node he settles on, or -1.
func _land_node(from: int, s: int, x: int, geyser: int = -1) -> int:
	var key: String = "%d:%d:%d:%d" % [geyser, from, s, x]
	if _memo.has(key):
		return int(_memo[key])
	var node: NavGraph.NavNode = graph.nodes[from]
	var outcome: NavSim.Outcome = sim.run(Vector2i(x, node.y), _scripts[s], MAX_TICKS, geyser)
	count_candidate()
	var landed: int = settled_node(graph, outcome)
	if geyser >= 0 and not outcome.geysered:
		landed = -1
	# Landings on a platform are the mover pass's (NavMovers: they need the platform's state).
	if outcome.platform != null or (landed >= 0 and graph.nodes[landed].mover >= 0):
		landed = -1
	# A move that rode a pulley lift on the way (a hop off its top: wf9_da_to_core_b.txt #1) holds only while the
	# pulley is where it was (its level-start state): the link gets that lift's state as its cond ([method _add_link]);
	# a lift without a node cannot carry one, so the move is not kept.
	var touch: int = -1
	if landed >= 0:
		for part: int in outcome.rode:
			if part < sim.part_pulley.size() and sim.part_pulley[part] >= 0:
				touch = part
				break
		if touch >= 0 and (movers == null or movers.mover_of_part(touch) < 0):
			landed = -1
			touch = -1
	_memo[key] = landed
	_memo_ticks[key] = outcome.landing_tick
	_memo_land[key] = outcome.pos.x
	_memo_sprung[key] = outcome.sprung
	_memo_walked[key] = outcome.walked
	_memo_touch[key] = touch
	_memo_state[key] = outcome.mover_states[touch] if touch >= 0 and touch < outcome.mover_states.size() \
			else PackedInt32Array()
	return landed


## True when the run of script `s` from x (cached by [method _land_node]) settled on node `to` at least
## EDGE_MARGIN_PX inside every open end of it (an end with a wall at body height beyond it stops an overshoot by
## itself): a landing on the very lip of a ledge works in the bake and misses in a match at the smallest difference
## (a link that lands from the lip is fragile; the bake keeps the starts that land clear of it).
func _lands_clear(from: int, s: int, x: int, geyser: int, to: int) -> bool:
	var land: int = int(_memo_land.get("%d:%d:%d:%d" % [geyser, from, s, x], 0))
	var node: NavGraph.NavNode = graph.nodes[to]
	var lo: int = node.x0 + (0 if _walled(node.x0 >> 4, node.row, -1) else EDGE_MARGIN_PX)
	var hi: int = node.x1 - (0 if _walled(node.x1 >> 4, node.row, 1) else EDGE_MARGIN_PX)
	return land >= mini(lo, node.center_x()) and land <= maxi(hi, node.center_x())


## True when the cell beside column `col` (`side` -1 left, +1 right) at body height over floor row `row` is a wall (or
## the level's edge).
func _walled(col: int, row: int, side: int) -> bool:
	var c: int = col + side
	if not _grid.in_bounds(c, row - 1):
		return true
	return _grid.side_at(c, row - 1) == TileGrid.SIDE_WALL


## The node a run ended on: he settled alive, and on the same node as on the tick the bot got control back (what
## HeroBot checks); -1 otherwise.
static func settled_node(p_graph: NavGraph, outcome: NavSim.Outcome) -> int:
	if outcome.died or not (outcome.landed or outcome.walked):
		return -1
	var node: int = p_graph.node_at(outcome.pos)
	return node if node == p_graph.node_at(outcome.handback_pos) else -1


## Job: the links from static node `from` (the ground scripts from its take-off points).
func _links_from_node(from: int) -> void:
	var node: NavGraph.NavNode = graph.nodes[from]
	_links_from(from, _samples(node), _ground_scripts, -1, Vector2i(node.x0, node.x1))


## Geyser links: from rest in the vent of every launching geyser, the geyser spouting on the first tick.
func _find_geyser_links() -> void:
	for g: int in sim.geysers.size():
		var geyser: SimEntity = sim.geysers[g]
		if not is_instance_valid(geyser) or bool(geyser.get(&"deadly")):
			continue
		var vent: Rect2i = geyser.call(&"vent_rect")
		for from: int in graph.nodes.size():
			var node: NavGraph.NavNode = graph.nodes[from]
			if node.mover >= 0 or node.y != geyser.sim_pos.y:
				continue
			var lo: int = maxi(node.x0, vent.position.x)
			var hi: int = mini(node.x1, vent.end.x - 1)
			if lo > hi:
				continue
			var xs: PackedInt32Array = PackedInt32Array()
			var x: int = lo
			while x < hi:
				xs.append(x)
				x += GEYSER_SAMPLE_STEP
			xs.append(hi)
			_links_from(from, xs, _air_scripts, g, Vector2i(lo, hi))


## Candidates from node `from` at take-off points `xs` with scripts `script_ids` (`geyser` as in [method _land_node]);
## windows grow within `limits` (x0, x1).
func _links_from(from: int, xs: PackedInt32Array, script_ids: PackedInt32Array, geyser: int, limits: Vector2i) -> void:
	# (to, script) -> sample xs that landed on `to`, in x order.
	var hits: Dictionary = {}
	var order: Array[Vector2i] = []
	for x: int in xs:
		for s: int in script_ids:
			var to: int = _land_node(from, s, x, geyser)
			if to < 0 or to == from or not _lands_clear(from, s, x, geyser, to):
				continue
			var pair: Vector2i = Vector2i(to, s)
			if not hits.has(pair):
				hits[pair] = PackedInt32Array()
				order.append(pair)
			var found: PackedInt32Array = hits[pair]
			found.append(x)
			hits[pair] = found
	var step: int = SAMPLE_STEP if geyser < 0 else GEYSER_SAMPLE_STEP
	# Per target node: seeds = the middle sample of every run of neighbouring samples, fastest first.
	var targets: PackedInt32Array = PackedInt32Array()
	for pair: Vector2i in order:
		if not targets.has(pair.x):
			targets.append(pair.x)
	targets.sort()
	for to: int in targets:
		var seeds: Array[Vector3i] = []  # (ticks, script, seed x)
		for pair: Vector2i in order:
			if pair.x != to:
				continue
			var found: PackedInt32Array = hits[pair]
			var i: int = 0
			while i < found.size():
				var j: int = i
				while j + 1 < found.size() and found[j + 1] - found[j] <= step:
					j += 1
				var seed_x: int = found[(i + j) / 2]
				var key: String = "%d:%d:%d:%d" % [geyser, from, pair.y, seed_x]
				seeds.append(Vector3i(int(_memo_ticks[key]), pair.y, seed_x))
				i = j + 1
		seeds.sort_custom(func(a: Vector3i, b: Vector3i) -> bool:
			if a.x != b.x:
				return a.x < b.x
			if a.y != b.y:
				return a.y < b.y
			return a.z < b.z
		)
		_keep_links(from, to, seeds, geyser, limits)


## Widen the best seeds of one (from, to) pair into verified windows and keep the fastest usable link, plus the
## widest when it is at least twice as wide.
func _keep_links(from: int, to: int, seeds: Array[Vector3i], geyser: int, limits: Vector2i) -> void:
	var fastest: Dictionary = {}
	var widest: Dictionary = {}
	for i: int in mini(seeds.size(), MAX_SEEDS_PER_PAIR):
		var window: Dictionary = _widen(from, to, seeds[i].y, seeds[i].z, geyser, limits)
		var width: int = int(window["x1"]) - int(window["x0"]) + 1
		if width < MIN_WINDOW:
			continue
		if fastest.is_empty():
			fastest = window
		var widest_width: int = int(widest["x1"]) - int(widest["x0"]) + 1 if not widest.is_empty() else 0
		if width > widest_width:
			widest = window
	if fastest.is_empty():
		return
	_add_link(from, to, fastest, geyser)
	var fast_width: int = int(fastest["x1"]) - int(fastest["x0"]) + 1
	var wide_width: int = int(widest["x1"]) - int(widest["x0"]) + 1
	if widest != fastest and wide_width >= 2 * fast_width:
		_add_link(from, to, widest, geyser)


## Grow a take-off window around `seed_x` 1 px at a time while script `s` still lands on `to`; every x in the
## result was simulated.
func _widen(from: int, to: int, s: int, seed_x: int, geyser: int, limits: Vector2i) -> Dictionary:
	var x0: int = seed_x
	var x1: int = seed_x
	while x1 - x0 + 1 < MAX_WINDOW and x0 - 1 >= limits.x and _land_node(from, s, x0 - 1, geyser) == to 			and _lands_clear(from, s, x0 - 1, geyser, to):
		x0 -= 1
	while x1 - x0 + 1 < MAX_WINDOW and x1 + 1 <= limits.y and _land_node(from, s, x1 + 1, geyser) == to 			and _lands_clear(from, s, x1 + 1, geyser, to):
		x1 += 1
	var ticks: int = 0
	var land0: int = 1 << 30
	var land1: int = -(1 << 30)
	var sprung: bool = false
	var walked: bool = true
	var touch: int = -1
	var touch_state: PackedInt32Array = PackedInt32Array()
	for x: int in range(x0, x1 + 1):
		var key: String = "%d:%d:%d:%d" % [geyser, from, s, x]
		_land_node(from, s, x, geyser)
		ticks = maxi(ticks, int(_memo_ticks[key]))
		land0 = mini(land0, int(_memo_land[key]))
		land1 = maxi(land1, int(_memo_land[key]))
		sprung = sprung or bool(_memo_sprung[key])
		walked = walked and bool(_memo_walked[key])
		if touch < 0 and int(_memo_touch.get(key, -1)) >= 0:
			touch = int(_memo_touch[key])
			touch_state = _memo_state[key]
	var window: Dictionary = {
		"script": s, "x0": x0, "x1": x1, "ticks": ticks, "land_x0": land0, "land_x1": land1, "sprung": sprung,
		"walked": walked,
	}
	if touch >= 0:
		window["touch"] = touch
		window["touch_state"] = touch_state
	return window


func _add_link(from: int, to: int, window: Dictionary, geyser: int) -> void:
	var s: int = int(window["script"])
	var link: NavGraph.NavLink = NavGraph.NavLink.new()
	link.from = from
	link.to = to
	link.x0 = int(window["x0"])
	link.x1 = int(window["x1"])
	link.dir = _script_dirs[s]
	link.ticks = int(window["ticks"])
	link.land_x0 = int(window["land_x0"])
	link.land_x1 = int(window["land_x1"])
	link.weight = _weight
	# Only the ticks up to the slowest landing are needed (the landing ends the script).
	var flags: PackedInt32Array = _scripts[s].slice(0, link.ticks)
	link.keys = NavGraph.compress_flags(flags)
	var jumps: bool = false
	for value: int in flags:
		if (value & Defs.IN_UP) != 0:
			jumps = true
	if geyser >= 0:
		link.kind = NavGraph.KIND_GEYSER
		link.cycle = sim.geyser_cycle(geyser)
	elif bool(window["sprung"]):
		link.kind = NavGraph.KIND_SPRING
	elif bool(window["walked"]) and absi(link.land_center() - link.window_center()) > _grid.cols * Tuning.TILE / 2:
		link.kind = NavGraph.KIND_WRAP
	elif jumps:
		link.kind = NavGraph.KIND_JUMP
	elif graph.nodes[to].y > graph.nodes[from].y:
		link.kind = NavGraph.KIND_DROP
	else:
		link.kind = NavGraph.KIND_WALK
	if window.has("touch"):
		var state: PackedInt32Array = window["touch_state"]
		var mover: int = movers.mover_of_part(int(window["touch"])) if movers != null else -1
		if mover < 0 or state.size() < 4:
			return
		link.cond = PackedInt32Array([mover, state[0], state[1], state[2], state[3]])
	verified_starts += link.x1 - link.x0 + 1
	graph.add_link(link)


## Count one candidate run (and print the progress line of `--verbose` every [member progress_every] runs).
func count_candidate() -> void:
	candidates += 1
	if progress_every > 0 and candidates % progress_every == 0:
		print("NavBaker: %d candidates, %d ticks, %d ms (class %d, job %d of %d)" % [
			candidates, sim.ticks_simulated, Time.get_ticks_msec() - _started_msec, _weight, _next_job + 1,
			_jobs.size(),
		])


## Add a verified link made elsewhere (NavMovers); counts its starts.
func add_verified_link(link: NavGraph.NavLink) -> void:
	link.weight = _weight
	verified_starts += link.x1 - link.x0 + 1
	graph.add_link(link)


## Re-simulate every link of `p_graph` from every x of its window, with its weight class, geyser timing and mover
## state (the check of tests and of `bake_nav --verify`); the problems found, empty when all hold. `sim` must be set
## up on the graph's level. `pulley_every` > 1: of the links of a pulley sweep (their `cond` names a pulley lift) only
## every `pulley_every`-th is checked (a quick check of a graph with thousands of them; all the other links always).
## A graph with pulley lifts is a long check: [method verify_graph_in_frames].
func verify_graph(p_graph: NavGraph, pulley_every: int = 1) -> PackedStringArray:
	var problems: PackedStringArray = PackedStringArray()
	var mover_check: NavMovers = NavMovers.new(self)
	graph = p_graph
	for link: NavGraph.NavLink in _links_to_verify(p_graph, pulley_every):
		_verify_link(link, mover_check, problems, pulley_every > 1)
	sim.weight_class = NavGraph.WEIGHT_LIGHT
	return problems


## [method verify_graph] with a frame of the engine after every FRAME_CANDIDATES runs (await it; `parent` is in the
## tree): the same problems, and the engine's callback queue is emptied on the way (see the header).
func verify_graph_in_frames(p_graph: NavGraph, parent: Node, pulley_every: int = 1) -> PackedStringArray:
	var problems: PackedStringArray = PackedStringArray()
	var mover_check: NavMovers = NavMovers.new(self)
	graph = p_graph
	var runs: int = 0
	for link: NavGraph.NavLink in _links_to_verify(p_graph, pulley_every):
		var before: int = candidates
		_verify_link(link, mover_check, problems, pulley_every > 1)
		runs += link.x1 - link.x0 + 1 + candidates - before
		if runs >= FRAME_CANDIDATES:
			runs = 0
			await parent.get_tree().process_frame
	sim.weight_class = NavGraph.WEIGHT_LIGHT
	return problems


## The links a verification checks: all of them, but of a pulley sweep's only every `pulley_every`-th.
func _links_to_verify(p_graph: NavGraph, pulley_every: int) -> Array[NavGraph.NavLink]:
	var result: Array[NavGraph.NavLink] = []
	var swept: int = 0
	for link: NavGraph.NavLink in p_graph.links:
		if pulley_every > 1 and link.cond.size() >= 5 and p_graph.is_pulley_lift(link.cond[0]):
			swept += 1
			if (swept - 1) % pulley_every != 0:
				continue
		result.append(link)
	return result


## Re-simulate one link of [member graph] from every x of its window; a problem line is added when a start does not
## land on the link's target. A link past a lift's column (NavLink.clear_at) is also run at the pulley states of its
## ranges - every one, or with `sample` the two ends and the middle of each range.
func _verify_link(link: NavGraph.NavLink, mover_check: NavMovers, problems: PackedStringArray,
		sample: bool = false) -> void:
	sim.weight_class = link.weight
	var node: NavGraph.NavNode = graph.nodes[link.from]
	var geyser: int = -1
	if link.kind == NavGraph.KIND_GEYSER:
		geyser = _geyser_at(Vector2i(link.window_center(), node.y))
		if geyser < 0:
			problems.append("link %d (%d -> %d, geyser): no geyser under its window" % [link.id, link.from, link.to])
			return
	for x: int in range(link.x0, link.x1 + 1):
		var landed: int = -1
		var pos: Vector2i = Vector2i.ZERO
		if node.mover >= 0 or not link.cond.is_empty():
			var result: Dictionary = mover_check.run_link(link, x)
			landed = int(result["node"])
			pos = result["pos"]
		else:
			var outcome: NavSim.Outcome = sim.run(Vector2i(x, node.y), link.flags, MAX_TICKS, geyser)
			landed = settled_node(graph, outcome)
			if geyser >= 0 and not outcome.geysered:
				landed = -1
			pos = outcome.pos
		if landed != link.to:
			problems.append("link %d (%d -> %d, %s, class %d) from x %d lands on node %d at %s" % [
				link.id, link.from, link.to, link.keys, link.weight, x, landed, pos,
			])
			return
	if link.clear_at.size() < 3 or node.mover >= 0:
		return
	var step: int = maxi(PartyTuning.PULLEY_SPEED_PX, 1)
	for i: int in range(1, link.clear_at.size() - 1, 2):
		var lo: int = link.clear_at[i]
		var hi: int = link.clear_at[i + 1]
		var states: PackedInt32Array = PackedInt32Array()
		if sample:
			for p: int in [lo, lo + ((hi - lo) / 2 / step) * step, hi]:
				if not states.has(p):
					states.append(p)
		else:
			for p: int in range(lo, hi + 1, step):
				states.append(p)
		for p: int in states:
			for x: int in range(link.x0, link.x1 + 1):
				var landed: int = mover_check.run_past_lifts(link, x, NavMovers.encode_preset(link.clear_at[0], p))
				if landed != link.to:
					problems.append("link %d (%d -> %d, %s, class %d) from x %d with pulley %d at %d lands on node %d" % [
						link.id, link.from, link.to, link.keys, link.weight, x, link.clear_at[0], p, landed,
					])
					return


## The geyser whose vent holds the feet point `pos`; -1 when none.
func _geyser_at(pos: Vector2i) -> int:
	for g: int in sim.geysers.size():
		var geyser: SimEntity = sim.geysers[g]
		if not is_instance_valid(geyser):
			continue
		var vent: Rect2i = geyser.call(&"vent_rect")
		if pos.y == geyser.sim_pos.y and pos.x >= vent.position.x and pos.x < vent.end.x:
			return g
	return -1


## The weight class being baked.
func weight_class() -> int:
	return _weight


## The grid being baked.
func grid() -> TileGrid:
	return _grid


## The clip of the bake (empty = none).
func clip_rect() -> Rect2i:
	return _clip


func _neutral(count: int) -> PackedInt32Array:
	var flags: PackedInt32Array = PackedInt32Array()
	flags.resize(count)
	flags.fill(0)
	return flags
