class_name NavGraph
extends RefCounted
## The navigation graph of one level for the bots (docs/expansion/DESIGN.md E.7, GAMEPLAY.md 13.10.10, PLAN.md P1.2).
##
## Owner: core-B (scripts/core/bots/**). Baked offline by tools/bots/bake_nav.gd (NavBaker) into
## `res://resources/bots/<level_id>.json` and read by [HeroBot]. Every link in a baked graph was verified by
## simulating the real hero (scenes/player/player.tscn) on the level's collision grid: from rest at EVERY integer x of
## its take-off window the hero, fed the link's input script, lands on the link's target node (NavBaker).
##
## Nodes are standable spans: one floor row, a run of columns whose surface the hero can stand on with room for his
## body; a hero stands on node n when his feet point is in row `row` (feet y >> 4) and x0 <= x <= x1.
## Links are moves from one node to another, executed from rest (NavSim.is_settled): the bot stops anywhere inside the
## take-off window [x0, x1] of the link's source node, then plays `keys` (run-length "ticks:KEYS" entries, the keys of
## GameInput.keys_to_flags) until he lands (first grounded tick after being airborne) or the script ends.
##
## JSON format (FORMAT 1):
##   {"format": 1, "level": id, "source_sha256": sha256 of the level text (CRLF read as LF), "difficulty": name,
##    "cols": int, "rows": int, "wrap": "none" | "lr" | "tb", "weight": 0,
##    "nodes": [{"id", "row", "y", "x0", "x1", "ice"}],
##    "links": [{"id", "from", "to", "kind", "x0", "x1", "dir", "keys", "ticks", "land_x0", "land_x1"}],
##    "baker": {"version", "candidates", "simulated_ticks", "verified_starts", "rejected"}}
## `kind`: walk, drop, jump, spring (launched by an objects/spring on the way), wrap; `ticks` = the slowest start of the
## window until landing; `land_x0` / `land_x1` = where the starts of the window landed. `weight` = the Grub Stack weight
## class the links were verified for (0 = an empty head).

const FORMAT: int = 1
const DIR: String = "res://resources/bots"
const KIND_WALK: StringName = &"walk"
const KIND_DROP: StringName = &"drop"
const KIND_JUMP: StringName = &"jump"
const KIND_SPRING: StringName = &"spring"
const KIND_WRAP: StringName = &"wrap"
const KINDS: Array[StringName] = [KIND_WALK, KIND_DROP, KIND_JUMP, KIND_SPRING, KIND_WRAP]
## Path costs (ticks): walking speed (Tuning.WALK_CAP = 5 px/tick) and the time to stop and settle before a link.
const WALK_PX_PER_TICK: int = 5
const SETTLE_TICKS: int = 8
const UNREACHABLE: int = 1 << 30


## A standable span.
class NavNode:
	extends RefCounted
	var id: int = 0
	## Floor row (the feet point's row: feet y >> 4).
	var row: int = 0
	## Feet y of a hero standing on it (logical px).
	var y: int = 0
	## Feet x range a hero can stand at (inclusive).
	var x0: int = 0
	var x1: int = 0
	## Ice level of its floor (0..3).
	var ice: int = 0

	func contains_x(x: int) -> bool:
		return x >= x0 and x <= x1

	func center_x() -> int:
		return (x0 + x1) / 2

	func clamp_x(x: int) -> int:
		return clampi(x, x0, x1)

	func to_dict() -> Dictionary:
		return {"id": id, "row": row, "y": y, "x0": x0, "x1": x1, "ice": ice}


## A verified move from one node to another.
class NavLink:
	extends RefCounted
	var id: int = 0
	var from: int = 0
	var to: int = 0
	var kind: StringName = KIND_JUMP
	## Take-off window on the source node: every integer x in it was verified from rest.
	var x0: int = 0
	var x1: int = 0
	## Main direction of the move (-1 left, 0 none, +1 right).
	var dir: int = 0
	## Input script, run-length "ticks:KEYS" entries ("6:R,12:RU").
	var keys: String = ""
	## The script expanded to one flags value per tick.
	var flags: PackedInt32Array = PackedInt32Array()
	## Slowest verified start: ticks from the first input to the landing.
	var ticks: int = 0
	## Where the verified starts landed (feet x).
	var land_x0: int = 0
	var land_x1: int = 0

	func window_center() -> int:
		return (x0 + x1) / 2

	func land_center() -> int:
		return (land_x0 + land_x1) / 2

	func to_dict() -> Dictionary:
		return {
			"id": id, "from": from, "to": to, "kind": String(kind), "x0": x0, "x1": x1, "dir": dir, "keys": keys,
			"ticks": ticks, "land_x0": land_x0, "land_x1": land_x1,
		}


var level_id: StringName = &""
var source_sha256: String = ""
var difficulty: String = "beginner"
var cols: int = 0
var rows: int = 0
var wrap: String = "none"
var weight: int = 0
var nodes: Array[NavNode] = []
var links: Array[NavLink] = []
## Baker statistics (informative).
var baker: Dictionary = {}
# Outgoing link ids per node.
var _out: Array[PackedInt32Array] = []

static var _cache: Dictionary = {}


# =================================================================================================================
# Loading and saving
# =================================================================================================================

## Resource path of the baked graph of a level.
static func path_for(p_level_id: StringName) -> String:
	return "%s/%s.json" % [DIR, p_level_id]


## The baked graph of a level (cached); null when there is none or it cannot be read.
static func load_for_level(p_level_id: StringName) -> NavGraph:
	if _cache.has(p_level_id):
		return _cache[p_level_id]
	var graph: NavGraph = load_file(path_for(p_level_id))
	if graph != null:
		_cache[p_level_id] = graph
	return graph


## Forget the cached graphs (tests, after a re-bake).
static func clear_cache() -> void:
	_cache.clear()


## Put a graph into the cache under its level id (tests; a graph baked at run time).
static func cache(graph: NavGraph) -> void:
	_cache[graph.level_id] = graph


## Read a graph file; null (no error) when the file does not exist, null with an error when it is malformed.
static func load_file(path: String) -> NavGraph:
	if not FileAccess.file_exists(path):
		return null
	var json: JSON = JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK or not (json.data is Dictionary):
		push_error("NavGraph: cannot parse %s" % path)
		return null
	var graph: NavGraph = from_dict(json.data)
	if graph == null:
		push_error("NavGraph: %s is not a format-%d graph" % [path, FORMAT])
	return graph


## A graph from its JSON dictionary; null when the format is unknown.
static func from_dict(data: Dictionary) -> NavGraph:
	if int(data.get("format", 0)) != FORMAT:
		return null
	var graph: NavGraph = NavGraph.new()
	graph.level_id = StringName(str(data.get("level", "")))
	graph.source_sha256 = str(data.get("source_sha256", ""))
	graph.difficulty = str(data.get("difficulty", "beginner"))
	graph.cols = int(data.get("cols", 0))
	graph.rows = int(data.get("rows", 0))
	graph.wrap = str(data.get("wrap", "none"))
	graph.weight = int(data.get("weight", 0))
	var stats: Variant = data.get("baker", {})
	if stats is Dictionary:
		for key: Variant in stats:
			var value: Variant = (stats as Dictionary)[key]
			# JSON numbers are floats: the statistics are counts.
			graph.baker[str(key)] = int(value) if value is float else value
	for item: Variant in data.get("nodes", []):
		var entry: Dictionary = item
		var node: NavNode = NavNode.new()
		node.id = int(entry["id"])
		node.row = int(entry["row"])
		node.y = int(entry["y"])
		node.x0 = int(entry["x0"])
		node.x1 = int(entry["x1"])
		node.ice = int(entry.get("ice", 0))
		graph.nodes.append(node)
	for item: Variant in data.get("links", []):
		var entry: Dictionary = item
		var link: NavLink = NavLink.new()
		link.from = int(entry["from"])
		link.to = int(entry["to"])
		link.kind = StringName(str(entry.get("kind", "jump")))
		link.x0 = int(entry["x0"])
		link.x1 = int(entry["x1"])
		link.dir = int(entry.get("dir", 0))
		link.keys = str(entry.get("keys", ""))
		link.ticks = int(entry.get("ticks", 0))
		link.land_x0 = int(entry.get("land_x0", 0))
		link.land_x1 = int(entry.get("land_x1", 0))
		graph.add_link(link)
	graph.rebuild()
	return graph


## The JSON dictionary of this graph.
func to_dict() -> Dictionary:
	var node_list: Array = []
	for node: NavNode in nodes:
		node_list.append(node.to_dict())
	var link_list: Array = []
	for link: NavLink in links:
		link_list.append(link.to_dict())
	return {
		"format": FORMAT, "level": String(level_id), "source_sha256": source_sha256, "difficulty": difficulty,
		"cols": cols, "rows": rows, "wrap": wrap, "weight": weight, "baker": baker, "nodes": node_list,
		"links": link_list,
	}


## The graph as stable, readable JSON text (one node or link per line).
func to_json() -> String:
	var lines: PackedStringArray = PackedStringArray()
	var data: Dictionary = to_dict()
	lines.append("{")
	for key: String in ["format", "level", "source_sha256", "difficulty", "cols", "rows", "wrap", "weight", "baker"]:
		lines.append("  %s: %s," % [JSON.stringify(key), JSON.stringify(data[key], "", true)])
	lines.append("  \"nodes\": [")
	for i: int in nodes.size():
		lines.append("    %s%s" % [JSON.stringify(nodes[i].to_dict(), "", false), "," if i < nodes.size() - 1 else ""])
	lines.append("  ],")
	lines.append("  \"links\": [")
	for i: int in links.size():
		lines.append("    %s%s" % [JSON.stringify(links[i].to_dict(), "", false), "," if i < links.size() - 1 else ""])
	lines.append("  ]")
	lines.append("}")
	return "\n".join(lines) + "\n"


## Write the graph to `path` (a res:// or user:// path); returns the error code.
func save(path: String) -> int:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(to_json())
	file.close()
	return OK


# =================================================================================================================
# Building
# =================================================================================================================

## Append a node (its id becomes its index).
func add_node(node: NavNode) -> NavNode:
	node.id = nodes.size()
	nodes.append(node)
	_out.append(PackedInt32Array())
	return node


## Append a link (its id becomes its index); its `flags` are expanded from `keys`.
func add_link(link: NavLink) -> NavLink:
	link.id = links.size()
	link.flags = expand_keys(link.keys)
	links.append(link)
	if link.from >= 0 and link.from < _out.size():
		_out[link.from].append(link.id)
	return link


## Recompute the outgoing link lists (after loading or editing).
func rebuild() -> void:
	_out.clear()
	for node: NavNode in nodes:
		_out.append(PackedInt32Array())
	for link: NavLink in links:
		link.flags = expand_keys(link.keys)
		if link.from >= 0 and link.from < _out.size():
			_out[link.from].append(link.id)


# =================================================================================================================
# Queries
# =================================================================================================================

## The node a hero whose feet point is `pos` stands on; -1 when none (in the air, or not on a known span).
func node_at(pos: Vector2i) -> int:
	var row: int = pos.y >> 4
	for node: NavNode in nodes:
		if node.row == row and node.contains_x(pos.x):
			return node.id
	return -1


## The node nearest to `pos` (feet point; distance in px, vertical distance weighted double so that the floor under
## a jumping hero wins); -1 for an empty graph.
func nearest_node(pos: Vector2i) -> int:
	var best: int = -1
	var best_cost: int = UNREACHABLE
	for node: NavNode in nodes:
		var cost: int = absi(node.clamp_x(pos.x) - pos.x) + 2 * absi(node.y - pos.y)
		if node.y < pos.y:
			cost += 64  # a node above the point is reached only by climbing
		if cost < best_cost:
			best_cost = cost
			best = node.id
	return best


## The node under a point in the air: the first node below `pos` whose x range holds pos.x; -1 when none.
func node_below(pos: Vector2i) -> int:
	var best: int = -1
	for node: NavNode in nodes:
		if node.y >= pos.y and node.contains_x(pos.x) and (best < 0 or node.y < nodes[best].y):
			best = node.id
	return best


func get_node_at(id: int) -> NavNode:
	return nodes[id] if id >= 0 and id < nodes.size() else null


func get_link(id: int) -> NavLink:
	return links[id] if id >= 0 and id < links.size() else null


## Outgoing link ids of a node.
func links_from(node_id: int) -> PackedInt32Array:
	return _out[node_id] if node_id >= 0 and node_id < _out.size() else PackedInt32Array()


## Ticks to walk `dx` px.
static func walk_ticks(dx: int) -> int:
	return (absi(dx) + WALK_PX_PER_TICK - 1) / WALK_PX_PER_TICK


## Cost (ticks) of taking link `link` for a hero standing at `x` on its source node.
func link_cost_from(link: NavLink, x: int) -> int:
	var takeoff: int = clampi(x, link.x0, link.x1)
	return walk_ticks(takeoff - x) + SETTLE_TICKS + link.ticks


## The cheapest route from (from_node, from_x) to (to_node, to_x): the link ids in order (empty when already on
## to_node, or when no route exists - see [method path_cost]). Deterministic: ties go to the lower link id.
## `blocked` = link ids not to use (links a bot saw fail).
func find_path(from_node: int, from_x: int, to_node: int, to_x: int, blocked: Dictionary = {}) -> PackedInt32Array:
	return _search(from_node, from_x, to_node, to_x, blocked)["path"]


## Estimated ticks from (from_node, from_x) to (to_node, to_x); UNREACHABLE when there is no route.
func path_cost(from_node: int, from_x: int, to_node: int, to_x: int, blocked: Dictionary = {}) -> int:
	return int(_search(from_node, from_x, to_node, to_x, blocked)["cost"])


## One search from (from_node, from_x) to every node: {"cost": PackedInt32Array, "x": PackedInt32Array} per node id -
## the cheapest ticks to stand on it and the x he arrives at (UNREACHABLE / 0 when it cannot be reached). For
## comparing many goals at once ([method reach_cost]).
func reach_from(from_node: int, from_x: int, blocked: Dictionary = {}) -> Dictionary:
	var cost: PackedInt32Array = PackedInt32Array()
	cost.resize(nodes.size())
	cost.fill(UNREACHABLE)
	var at: PackedInt32Array = PackedInt32Array()
	at.resize(nodes.size())
	at.fill(0)
	var result: Dictionary = {"cost": cost, "x": at}
	if from_node < 0 or from_node >= nodes.size():
		return result
	cost[from_node] = 0
	at[from_node] = from_x
	var count: int = links.size()
	var dist: PackedInt32Array = PackedInt32Array()
	dist.resize(count)
	dist.fill(UNREACHABLE)
	var done: PackedByteArray = PackedByteArray()
	done.resize(count)
	done.fill(0)
	for id: int in links_from(from_node):
		if not blocked.has(id):
			dist[id] = link_cost_from(links[id], from_x)
	while true:
		var current: int = -1
		var current_cost: int = UNREACHABLE
		for id: int in count:
			if done[id] == 0 and dist[id] < current_cost:
				current_cost = dist[id]
				current = id
		if current < 0:
			break
		done[current] = 1
		var link: NavLink = links[current]
		var land_x: int = link.land_center()
		if current_cost < cost[link.to]:
			cost[link.to] = current_cost
			at[link.to] = land_x
		for next: int in links_from(link.to):
			if done[next] == 1 or blocked.has(next):
				continue
			var next_cost: int = current_cost + link_cost_from(links[next], land_x)
			if next_cost < dist[next]:
				dist[next] = next_cost
	return result


## Ticks to reach the feet point `pos` from the search of [method reach_from] (UNREACHABLE when its node is).
func reach_cost(reach: Dictionary, pos: Vector2i) -> int:
	var node: int = node_at(pos)
	if node < 0:
		node = node_below(pos)
	if node < 0:
		return UNREACHABLE
	var cost: PackedInt32Array = reach["cost"]
	if cost[node] >= UNREACHABLE:
		return UNREACHABLE
	var at: PackedInt32Array = reach["x"]
	return cost[node] + walk_ticks(pos.x - at[node])


# Edge-based Dijkstra: dist[link] = cheapest ticks until that link has landed (at its land centre).
func _search(from_node: int, from_x: int, to_node: int, to_x: int, blocked: Dictionary) -> Dictionary:
	var none: Dictionary = {"path": PackedInt32Array(), "cost": UNREACHABLE}
	if from_node < 0 or from_node >= nodes.size() or to_node < 0 or to_node >= nodes.size():
		return none
	var best_cost: int = UNREACHABLE
	var best_last: int = -1
	if from_node == to_node:
		best_cost = walk_ticks(to_x - from_x)
	var count: int = links.size()
	var dist: PackedInt32Array = PackedInt32Array()
	dist.resize(count)
	dist.fill(UNREACHABLE)
	var prev: PackedInt32Array = PackedInt32Array()
	prev.resize(count)
	prev.fill(-1)
	var done: PackedByteArray = PackedByteArray()
	done.resize(count)
	done.fill(0)
	for id: int in links_from(from_node):
		if blocked.has(id):
			continue
		dist[id] = link_cost_from(links[id], from_x)
	while true:
		var current: int = -1
		var current_cost: int = UNREACHABLE
		for id: int in count:
			if done[id] == 0 and dist[id] < current_cost:
				current_cost = dist[id]
				current = id
		if current < 0 or current_cost >= best_cost:
			break
		done[current] = 1
		var link: NavLink = links[current]
		var land_x: int = link.land_center()
		if link.to == to_node:
			var total: int = current_cost + walk_ticks(to_x - land_x)
			if total < best_cost:
				best_cost = total
				best_last = current
		for next: int in links_from(link.to):
			if done[next] == 1 or blocked.has(next):
				continue
			var cost: int = current_cost + link_cost_from(links[next], land_x)
			if cost < dist[next]:
				dist[next] = cost
				prev[next] = current
	if best_cost >= UNREACHABLE:
		return none
	var path: PackedInt32Array = PackedInt32Array()
	var step: int = best_last
	while step >= 0:
		path.insert(0, step)
		step = prev[step]
	return {"path": path, "cost": best_cost}


## Expand a link script ("6:R,12:RU", "" = nothing) into flags per tick (GameInput.keys_to_flags).
static func expand_keys(script: String) -> PackedInt32Array:
	var result: PackedInt32Array = PackedInt32Array()
	for entry: String in script.split(",", false):
		var parts: PackedStringArray = entry.strip_edges().split(":", true, 1)
		var count: int = int(parts[0])
		var value: int = keys_to_flags(parts[1] if parts.size() > 1 else "")
		for i: int in count:
			result.append(value)
	return result


## Run-length script of flags per tick (the inverse of [method expand_keys]).
static func compress_flags(flags: PackedInt32Array) -> String:
	var entries: PackedStringArray = PackedStringArray()
	var i: int = 0
	while i < flags.size():
		var j: int = i
		while j < flags.size() and flags[j] == flags[i]:
			j += 1
		entries.append("%d:%s" % [j - i, flags_to_keys(flags[i])])
		i = j
	return ",".join(entries)


## GameInput.keys_to_flags without the autoload (the baker's tool script compiles before the autoloads exist).
static func keys_to_flags(keys: String) -> int:
	var result: int = 0
	for i: int in keys.length():
		match keys[i]:
			"L":
				result |= Defs.IN_LEFT
			"R":
				result |= Defs.IN_RIGHT
			"U":
				result |= Defs.IN_UP
			"D":
				result |= Defs.IN_DOWN
			"F":
				result |= Defs.IN_FIRE
			"K":
				result |= Defs.IN_LOOK
			"S":
				result |= Defs.IN_SWAP
	return result


## The keys of a flags value in the order L R U D F K S.
static func flags_to_keys(flags: int) -> String:
	var keys: String = ""
	for pair: Array in [[Defs.IN_LEFT, "L"], [Defs.IN_RIGHT, "R"], [Defs.IN_UP, "U"], [Defs.IN_DOWN, "D"],
			[Defs.IN_FIRE, "F"], [Defs.IN_LOOK, "K"], [Defs.IN_SWAP, "S"]]:
		if (flags & int(pair[0])) != 0:
			keys += str(pair[1])
	return keys


## sha256 (hex) of a level text with CRLF read as LF (the hash the graph records as `source_sha256`).
static func text_sha256(text: String) -> String:
	return text.replace("\r\n", "\n").sha256_text()
