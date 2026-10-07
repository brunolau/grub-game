class_name NavBaker
extends RefCounted
## Bakes a level's [NavGraph] (PLAN.md P1.2, DESIGN.md E.7): nodes are the standable spans of the collision grid,
## links are moves found and verified by simulating the real hero ([NavSim]).
##
## Owner: core-B. Used by tools/bots/bake_nav.gd (offline, writes res://resources/bots/<level_id>.json) and by the
## tests. Steps:
##  1. Nodes: every run of columns of one row whose floor the hero can stand on (a floor tile - solid, one-way, ice,
##     hatch - with the cell above free of floors and walls and nothing deadly at body height). The walkable x range
##     honours the wall probe (9 px) and the level bounds. Each node is checked by standing the hero on it.
##  2. Candidates: from every node, from rest at take-off points every SAMPLE_STEP px (and both ends), every script of
##     [method scripts_for] (walk-offs, running and standing jumps with UP held 1..14 ticks, air control) is simulated
##     until the landing. A landing on another node, alive and settled, is a candidate.
##  3. Windows: per (source, target) pair the fastest candidates are widened 1 px at a time while the start still
##     lands on the target; EVERY integer x of the final window was simulated. A link needs a window of at least
##     MIN_WINDOW px; the fastest one is kept, plus the widest when it is much wider.
## The bake is deterministic (no RNG; fixed iteration order), so a re-bake of an unchanged level gives the same file.

const VERSION: int = 1
## Take-off points are sampled this far apart along a node.
const SAMPLE_STEP: int = 8
## Narrowest take-off window kept (px) and the widest one searched.
const MIN_WINDOW: int = 4
const MAX_WINDOW: int = 24
## Window seeds tried per (source, target) pair, fastest first.
const MAX_SEEDS_PER_PAIR: int = 8
## Simulation limit of one candidate (ticks).
const MAX_TICKS: int = 90
## Length of the open-ended scripts (ticks; the landing ends them).
const SCRIPT_TICKS: int = 72

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
var _started_msec: int = 0

var _grid: TileGrid = null
# Cache of simulated starts: "node:script:x" -> landing node id (-1 = no landing on a node).
var _memo: Dictionary = {}
var _memo_ticks: Dictionary = {}
var _memo_land: Dictionary = {}
var _memo_sprung: Dictionary = {}
var _memo_walked: Dictionary = {}
var _scripts: Array[PackedInt32Array] = []
var _script_keys: PackedStringArray = PackedStringArray()
var _script_dirs: PackedInt32Array = PackedInt32Array()


## Bake the graph of the level file at `path` (res:// path) for `difficulty`; `parent` hosts the sim world while it
## runs. Null (and an error) when the file cannot be read.
func bake_file(parent: Node, path: String, difficulty: int = Defs.Difficulty.BEGINNER) -> NavGraph:
	if not FileAccess.file_exists(path):
		push_error("NavBaker: %s does not exist" % path)
		return null
	var text: String = FileAccess.get_file_as_string(path)
	return bake_text(parent, StringName(path.get_file().get_basename()), text, difficulty)


## Bake the graph of a level given as file text.
func bake_text(parent: Node, level_id: StringName, text: String, difficulty: int = Defs.Difficulty.BEGINNER) -> NavGraph:
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
	if not sim.setup(parent, level_id, grid, meta, data.entity_records()):
		return null
	_grid = grid
	var started: int = Time.get_ticks_msec()
	_started_msec = started
	_build_scripts()
	_find_nodes()
	_find_links()
	sim.teardown()
	graph.baker = {
		"version": VERSION, "candidates": candidates, "simulated_ticks": sim.ticks_simulated,
		"verified_starts": verified_starts, "rejected": rejected,
	}
	report.append("%s: %d nodes, %d links, %d candidates, %d ticks simulated, %d ms" % [
		level_id, graph.nodes.size(), graph.links.size(), candidates, sim.ticks_simulated,
		Time.get_ticks_msec() - started,
	])
	if graph.wrap != "none" and not sim.wrap_step.is_valid():
		report.append("%s: wrap = %s: no wrap step available, links across the seam are left out" % [
			level_id, graph.wrap,
		])
	return graph


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


## The standable spans of a grid as nodes (no simulation): one per run of standable columns in a row.
static func span_nodes(grid: TileGrid) -> Array[NavGraph.NavNode]:
	var result: Array[NavGraph.NavNode] = []
	var x_min: int = Tuning.X_MIN
	var x_max: int = grid.x_max_excl() - 1
	for row: int in range(1, grid.rows):
		var col: int = 0
		while col < grid.cols:
			if not is_standable(grid, col, row):
				col += 1
				continue
			var first: int = col
			while col < grid.cols and is_standable(grid, col, row):
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
	for node: NavGraph.NavNode in span_nodes(_grid):
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


func _build_scripts() -> void:
	_scripts.clear()
	_script_keys.clear()
	_script_dirs.clear()
	var seen: Dictionary = {}
	# Straight up, no direction (one-way floors above).
	for script: String in ["14:U", "8:U"]:
		_add_script(script, 0, seen)
	for d: int in [1, -1]:
		for script: String in scripts_for(d):
			_add_script(script, d, seen)


func _add_script(script: String, d: int, seen: Dictionary) -> void:
	if seen.has(script):
		return
	seen[script] = true
	_scripts.append(NavGraph.expand_keys(script))
	_script_keys.append(script)
	_script_dirs.append(d)


## Take-off points sampled on a node.
func _samples(node: NavGraph.NavNode) -> PackedInt32Array:
	var xs: PackedInt32Array = PackedInt32Array()
	var x: int = node.x0
	while x < node.x1:
		xs.append(x)
		x += SAMPLE_STEP
	xs.append(node.x1)
	return xs


## Simulate script `s` from rest at x on node `from` (cached): the node he settles on, or -1.
func _land_node(from: int, s: int, x: int) -> int:
	var key: String = "%d:%d:%d" % [from, s, x]
	if _memo.has(key):
		return int(_memo[key])
	var node: NavGraph.NavNode = graph.nodes[from]
	var outcome: NavSim.Outcome = sim.run(Vector2i(x, node.y), _scripts[s], MAX_TICKS)
	candidates += 1
	if progress_every > 0 and candidates % progress_every == 0:
		print("NavBaker: %d candidates, %d ticks, %d ms (node %d, x %d, script %s)" % [
			candidates, sim.ticks_simulated, Time.get_ticks_msec() - _started_msec, from, x, _script_keys[s],
		])
	var landed: int = settled_node(graph, outcome)
	_memo[key] = landed
	_memo_ticks[key] = outcome.landing_tick
	_memo_land[key] = outcome.pos.x
	_memo_sprung[key] = outcome.sprung
	_memo_walked[key] = outcome.walked
	return landed


## The node a run ended on: he settled alive, and on the same node as on the tick the bot got control back (what
## HeroBot checks); -1 otherwise.
static func settled_node(p_graph: NavGraph, outcome: NavSim.Outcome) -> int:
	if outcome.died or not (outcome.landed or outcome.walked):
		return -1
	var node: int = p_graph.node_at(outcome.pos)
	return node if node == p_graph.node_at(outcome.handback_pos) else -1


func _find_links() -> void:
	for from: int in graph.nodes.size():
		var node: NavGraph.NavNode = graph.nodes[from]
		# (to, script) -> sample xs that landed on `to`, in x order.
		var hits: Dictionary = {}
		var order: Array[Vector2i] = []
		for x: int in _samples(node):
			for s: int in _scripts.size():
				var to: int = _land_node(from, s, x)
				if to < 0 or to == from:
					continue
				var pair: Vector2i = Vector2i(to, s)
				if not hits.has(pair):
					hits[pair] = PackedInt32Array()
					order.append(pair)
				var xs: PackedInt32Array = hits[pair]
				xs.append(x)
				hits[pair] = xs
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
				var xs: PackedInt32Array = hits[pair]
				var i: int = 0
				while i < xs.size():
					var j: int = i
					while j + 1 < xs.size() and xs[j + 1] - xs[j] <= SAMPLE_STEP:
						j += 1
					var seed_x: int = xs[(i + j) / 2]
					var key: String = "%d:%d:%d" % [from, pair.y, seed_x]
					seeds.append(Vector3i(int(_memo_ticks[key]), pair.y, seed_x))
					i = j + 1
			seeds.sort_custom(func(a: Vector3i, b: Vector3i) -> bool:
				if a.x != b.x:
					return a.x < b.x
				if a.y != b.y:
					return a.y < b.y
				return a.z < b.z
			)
			_keep_links(from, to, seeds)


## Widen the best seeds of one (from, to) pair into verified windows and keep the fastest usable link, plus the
## widest when it is at least twice as wide.
func _keep_links(from: int, to: int, seeds: Array[Vector3i]) -> void:
	var fastest: Dictionary = {}
	var widest: Dictionary = {}
	for i: int in mini(seeds.size(), MAX_SEEDS_PER_PAIR):
		var window: Dictionary = _widen(from, to, seeds[i].y, seeds[i].z)
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
	_add_link(from, to, fastest)
	var fast_width: int = int(fastest["x1"]) - int(fastest["x0"]) + 1
	var wide_width: int = int(widest["x1"]) - int(widest["x0"]) + 1
	if widest != fastest and wide_width >= 2 * fast_width:
		_add_link(from, to, widest)


## Grow a take-off window around `seed_x` 1 px at a time while script `s` still lands on `to`; every x in the
## result was simulated.
func _widen(from: int, to: int, s: int, seed_x: int) -> Dictionary:
	var node: NavGraph.NavNode = graph.nodes[from]
	var x0: int = seed_x
	var x1: int = seed_x
	while x1 - x0 + 1 < MAX_WINDOW and x0 - 1 >= node.x0 and _land_node(from, s, x0 - 1) == to:
		x0 -= 1
	while x1 - x0 + 1 < MAX_WINDOW and x1 + 1 <= node.x1 and _land_node(from, s, x1 + 1) == to:
		x1 += 1
	var ticks: int = 0
	var land0: int = 1 << 30
	var land1: int = -(1 << 30)
	var sprung: bool = false
	var walked: bool = true
	for x: int in range(x0, x1 + 1):
		var key: String = "%d:%d:%d" % [from, s, x]
		_land_node(from, s, x)
		ticks = maxi(ticks, int(_memo_ticks[key]))
		land0 = mini(land0, int(_memo_land[key]))
		land1 = maxi(land1, int(_memo_land[key]))
		sprung = sprung or bool(_memo_sprung[key])
		walked = walked and bool(_memo_walked[key])
	return {
		"script": s, "x0": x0, "x1": x1, "ticks": ticks, "land_x0": land0, "land_x1": land1, "sprung": sprung,
		"walked": walked,
	}


func _add_link(from: int, to: int, window: Dictionary) -> void:
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
	# Only the ticks up to the slowest landing are needed (the landing ends the script).
	var flags: PackedInt32Array = _scripts[s].slice(0, link.ticks)
	link.keys = NavGraph.compress_flags(flags)
	var jumps: bool = false
	for value: int in flags:
		if (value & Defs.IN_UP) != 0:
			jumps = true
	if bool(window["sprung"]):
		link.kind = NavGraph.KIND_SPRING
	elif bool(window["walked"]) and absi(link.land_center() - link.window_center()) > _grid.cols * Tuning.TILE / 2:
		link.kind = NavGraph.KIND_WRAP
	elif jumps:
		link.kind = NavGraph.KIND_JUMP
	elif graph.nodes[to].y > graph.nodes[from].y:
		link.kind = NavGraph.KIND_DROP
	else:
		link.kind = NavGraph.KIND_WALK
	verified_starts += link.x1 - link.x0 + 1
	graph.add_link(link)


## Re-simulate every link of `p_graph` from every x of its window (the check of tests and of `bake_nav --verify`);
## the problems found, empty when all hold. `sim` must be set up on the graph's level.
func verify_graph(p_graph: NavGraph) -> PackedStringArray:
	var problems: PackedStringArray = PackedStringArray()
	for link: NavGraph.NavLink in p_graph.links:
		var node: NavGraph.NavNode = p_graph.nodes[link.from]
		for x: int in range(link.x0, link.x1 + 1):
			var outcome: NavSim.Outcome = sim.run(Vector2i(x, node.y), link.flags, MAX_TICKS)
			var landed: int = settled_node(p_graph, outcome)
			if landed != link.to:
				problems.append("link %d (%d -> %d, %s) from x %d lands on node %d at %s" % [
					link.id, link.from, link.to, link.keys, x, landed, outcome.pos,
				])
				break
	return problems


func _neutral(count: int) -> PackedInt32Array:
	var flags: PackedInt32Array = PackedInt32Array()
	flags.resize(count)
	flags.fill(0)
	return flags
