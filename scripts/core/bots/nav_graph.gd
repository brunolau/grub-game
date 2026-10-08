class_name NavGraph
extends RefCounted
## The navigation graph of one level for the bots (docs/expansion/DESIGN.md E.7, GAMEPLAY.md 13.10.10, PLAN.md P1.2 /
## P2.5).
##
## Owner: core-B (scripts/core/bots/**). Baked offline by tools/bots/bake_nav.gd (NavBaker) into
## `res://resources/bots/<level_id>.json` and read by [HeroBot]. Every link in a baked graph was verified by
## simulating the real hero (scenes/player/player.tscn) on the level's collision grid: from rest at EVERY integer x of
## its take-off window the hero, fed the link's input script, lands on the link's target node (NavBaker).
##
## Nodes are standable spans: one floor row, a run of columns whose surface the hero can stand on with room for his
## body; a hero stands on node n when his feet point is in row `row` (feet y >> 4) and x0 <= x <= x1. A **mover node**
## (`mover` >= 0) is the top of a platform (objects/platform, a pulley lift, a see-saw end, a drop platform) at the
## place it has when the level starts; while the platform is elsewhere the node moves with it ([method node_at] with
## the live offsets of [method set_mover_offsets]).
## Links are moves from one node to another, executed from rest (NavSim.is_settled): the bot stops anywhere inside the
## take-off window [x0, x1] of the link's source node, then plays `keys` (run-length "ticks:KEYS" entries, the keys of
## GameInput.keys_to_flags) until he lands (first grounded tick after being airborne) or the script ends.
##
## **Weight classes** (PHYSICS.md C.14): a Grub Stack hero with 10+ units walks at most 64 v16, with 20+ at 48 and
## jumps 3/4 as high; the Hot Rock holder walks 96. Every link is verified for one class (`weight`), and the bots of a
## class only use the links of their class ([method links_from]). A graph holds the classes its arena's modes need
## ([method weight_classes_for]); a class that was not baked falls back to the light links.
## **Timed links** (`cycle` = [period, delay, at]): a geyser link starts on a tick t with posmod(t - delay, period) ==
## at (the geyser's first spout tick, objects-B's Geyser.cycle_at); the bot waits in the window until then.
## **Mover links** (`cond` = [mover, dx, dy, mx, my]): the take-off is verified with the mover `dx, dy` px away from
## its level-start place and moving by `mx, my` px per tick; the bot waits in the window until the live mover is there.
## **Pulley lifts** (core-B wf10; a mover with "pulley", "side", "limit"): the two lifts of one objects/pulley share
## one state, the pulley's offset p (the `a` lift, side +1, is p px below its start, `b`, side -1, p px above; |p| <=
## limit). Their links are verified at every still p (PartyTuning.PULLEY_SPEED_PX apart): links onto a lift with the
## pulley still at p and nobody on it; links off a lift with the hero standing on it at p, the pulley held still (an
## equal weight on the other side; at the lift's bottom his own weight holds it there); a link between two other nodes
## that touched a lift on the way (a hop off its top) carries the state it was verified in. `cond` = [mover, 0, side * p,
## 0, 0]. A bot plans only with the pulley links of the state the pulley will rest in (BotNavigator, [method
## pulley_rest]).
##
## JSON format (FORMAT 2; FORMAT 1 = the G1 graphs: no weights, timing or movers, still read):
##   {"format": 2, "level": id, "source_sha256": sha256 of the level text (CRLF read as LF), "difficulty": name,
##    "cols": int, "rows": int, "wrap": "none" | "lr" | "tb", "weights": [classes baked], "clip": [c, r, w, h] or [],
##    "movers": [{"key", "id", "col", "row", "kind", "x", "y", "part", "top"[, "period"][, "pulley", "side",
##               "limit"]}],
##    "baker": {"version", "candidates", "simulated_ticks", "verified_starts", "rejected"},
##    "nodes": [{"id", "row", "y", "x0", "x1", "ice"[, "mover"]}],
##    "links": [{"id", "from", "to", "kind", "x0", "x1", "dir", "keys", "ticks", "land_x0", "land_x1", "weight"
##               [, "cycle"][, "cond"]}]}
## `kind`: walk, drop, jump, spring (launched by an objects/spring on the way), geyser (launched by a geyser), wrap,
## ride (onto, off or with a mover); `ticks` = the slowest start of the window until landing; `land_x0` / `land_x1` =
## where the starts of the window landed. Mover `kind`: periodic (moves by itself), rider (moves by the weight on it).

const FORMAT: int = 2
## Formats this class reads.
const FORMATS: Array[int] = [1, 2]
const DIR: String = "res://resources/bots"
const KIND_WALK: StringName = &"walk"
const KIND_DROP: StringName = &"drop"
const KIND_JUMP: StringName = &"jump"
const KIND_SPRING: StringName = &"spring"
const KIND_WRAP: StringName = &"wrap"
const KIND_GEYSER: StringName = &"geyser"
const KIND_RIDE: StringName = &"ride"
const KINDS: Array[StringName] = [KIND_WALK, KIND_DROP, KIND_JUMP, KIND_SPRING, KIND_WRAP, KIND_GEYSER, KIND_RIDE]
## Weight classes (PHYSICS.md C.14).
const WEIGHT_LIGHT: int = 0     ## an empty or light head: the 1.0 hero
const WEIGHT_HEAVY: int = 1     ## 10+ units: walk and air cap 64
const WEIGHT_HEAVIER: int = 2   ## 20+ units: cap 48, jump impulses x3/4
const WEIGHT_HOLDER: int = 3    ## the Hot Rock holder: cap 96
const WEIGHT_CLASSES: int = 4
## Mover kinds.
const MOVER_PERIODIC: StringName = &"periodic"
const MOVER_RIDER: StringName = &"rider"
## Path costs (ticks): walking speed (Tuning.WALK_CAP = 5 px/tick) and the time to stop and settle before a link.
const WALK_PX_PER_TICK: int = 5
const SETTLE_TICKS: int = 8
## Expected wait for a mover to come to the take-off state (cost only).
const MOVER_WAIT_TICKS: int = 24
const UNREACHABLE: int = 1 << 30
# Heap keys: cost << ID_BITS | link id (ties go to the lower link id, as a linear scan would).
const ID_BITS: int = 20
const ID_MASK: int = (1 << ID_BITS) - 1


## A standable span.
class NavNode:
	extends RefCounted
	var id: int = 0
	## Floor row (the feet point's row: feet y >> 4) at the level start.
	var row: int = 0
	## Feet y of a hero standing on it (logical px) at the level start.
	var y: int = 0
	## Feet x range a hero can stand at (inclusive) at the level start.
	var x0: int = 0
	var x1: int = 0
	## Ice level of its floor (0..3).
	var ice: int = 0
	## Index into NavGraph.movers (-1 = a floor of the grid that never moves).
	var mover: int = -1

	func contains_x(x: int) -> bool:
		return x >= x0 and x <= x1

	func center_x() -> int:
		return (x0 + x1) / 2

	func clamp_x(x: int) -> int:
		return clampi(x, x0, x1)

	func to_dict() -> Dictionary:
		var data: Dictionary = {"id": id, "row": row, "y": y, "x0": x0, "x1": x1, "ice": ice}
		if mover >= 0:
			data["mover"] = mover
		return data


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
	## Weight class it was verified for (WEIGHT_*).
	var weight: int = WEIGHT_LIGHT
	## Timed link: [period, delay, at] (empty = any tick).
	var cycle: PackedInt32Array = PackedInt32Array()
	## Mover condition: [mover, dx, dy, mx, my] (empty = none).
	var cond: PackedInt32Array = PackedInt32Array()

	func window_center() -> int:
		return (x0 + x1) / 2

	func land_center() -> int:
		return (land_x0 + land_x1) / 2

	## True when the script may start on tick `tick` (timed links; others always).
	func starts_on(tick: int) -> bool:
		if cycle.size() < 3:
			return true
		return posmod(tick - cycle[1], maxi(cycle[0], 1)) == cycle[2]

	func to_dict() -> Dictionary:
		var data: Dictionary = {
			"id": id, "from": from, "to": to, "kind": String(kind), "x0": x0, "x1": x1, "dir": dir, "keys": keys,
			"ticks": ticks, "land_x0": land_x0, "land_x1": land_x1, "weight": weight,
		}
		if not cycle.is_empty():
			data["cycle"] = Array(cycle)
		if not cond.is_empty():
			data["cond"] = Array(cond)
		return data


var level_id: StringName = &""
var source_sha256: String = ""
var difficulty: String = "beginner"
var cols: int = 0
var rows: int = 0
var wrap: String = "none"
## Weight classes baked (WEIGHT_*; a format-1 graph: [0]).
var weights: PackedInt32Array = PackedInt32Array([WEIGHT_LIGHT])
## Cells the bake was limited to ([col, row, cols, rows]; empty = the whole grid).
var clip: PackedInt32Array = PackedInt32Array()
## The movers of the level: {"key": "<id>@<col>,<row>", "id", "col", "row", "kind"} (see the header).
var movers: Array[Dictionary] = []
var nodes: Array[NavNode] = []
var links: Array[NavLink] = []
## Baker statistics (informative).
var baker: Dictionary = {}
## Format the graph was read from (FORMAT for a new one).
var format: int = FORMAT
# Outgoing link ids per weight class and node.
var _out: Array = []
# Live offsets and last motions of the movers (Vector2i per mover; ZERO = at the level-start place / still).
var _mover_offsets: Array[Vector2i] = []
var _mover_motions: Array[Vector2i] = []

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
		push_error("NavGraph: %s is not a graph of format %s" % [path, FORMATS])
	return graph


## A graph from its JSON dictionary; null when the format is unknown.
static func from_dict(data: Dictionary) -> NavGraph:
	var data_format: int = int(data.get("format", 0))
	if not FORMATS.has(data_format):
		return null
	var graph: NavGraph = NavGraph.new()
	graph.format = data_format
	graph.level_id = StringName(str(data.get("level", "")))
	graph.source_sha256 = str(data.get("source_sha256", ""))
	graph.difficulty = str(data.get("difficulty", "beginner"))
	graph.cols = int(data.get("cols", 0))
	graph.rows = int(data.get("rows", 0))
	graph.wrap = str(data.get("wrap", "none"))
	graph.weights = _ints(data.get("weights", [WEIGHT_LIGHT]))
	if graph.weights.is_empty():
		graph.weights = PackedInt32Array([WEIGHT_LIGHT])
	graph.clip = _ints(data.get("clip", []))
	for item: Variant in data.get("movers", []):
		if item is Dictionary:
			var entry: Dictionary = item
			var mover: Dictionary = {
				"key": str(entry.get("key", "")), "id": str(entry.get("id", "")), "col": int(entry.get("col", 0)),
				"row": int(entry.get("row", 0)), "kind": str(entry.get("kind", MOVER_PERIODIC)),
			}
			# Where the baker found it (NavMoversLive matches the live entity by them): spawn feet point, part index,
			# the part's box top-left at the level start.
			for key: String in ["x", "y", "part", "period", "pulley", "side", "limit"]:
				if entry.has(key):
					mover[key] = int(entry[key])
			if entry.get("top") is Array and (entry["top"] as Array).size() >= 2:
				mover["top"] = [int(entry["top"][0]), int(entry["top"][1])]
			graph.movers.append(mover)
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
		node.mover = int(entry.get("mover", -1))
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
		link.weight = clampi(int(entry.get("weight", WEIGHT_LIGHT)), 0, WEIGHT_CLASSES - 1)
		link.cycle = _ints(entry.get("cycle", []))
		link.cond = _ints(entry.get("cond", []))
		graph.links.append(link)
	graph.rebuild()
	return graph


static func _ints(value: Variant) -> PackedInt32Array:
	var result: PackedInt32Array = PackedInt32Array()
	if value is Array:
		for item: Variant in value:
			result.append(int(item))
	elif value is PackedInt32Array:
		result = (value as PackedInt32Array).duplicate()
	return result


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
		"cols": cols, "rows": rows, "wrap": wrap, "weights": Array(weights), "clip": Array(clip), "movers": movers,
		"baker": baker, "nodes": node_list, "links": link_list,
	}


## The graph as stable, readable JSON text (one node, link or mover per line).
func to_json() -> String:
	var lines: PackedStringArray = PackedStringArray()
	var data: Dictionary = to_dict()
	lines.append("{")
	for key: String in ["format", "level", "source_sha256", "difficulty", "cols", "rows", "wrap", "weights", "clip",
			"baker"]:
		lines.append("  %s: %s," % [JSON.stringify(key), JSON.stringify(data[key], "", true)])
	lines.append("  \"movers\": [")
	for i: int in movers.size():
		lines.append("    %s%s" % [JSON.stringify(movers[i], "", true), "," if i < movers.size() - 1 else ""])
	lines.append("  ],")
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
# Weight classes
# =================================================================================================================

## The weight classes an arena's modes need (`modes` of its [meta]): light always; Grub Stack the heavy ones (10+,
## 20+ units); Hot Rock the holder.
static func weight_classes_for(meta: Dictionary) -> PackedInt32Array:
	var result: PackedInt32Array = PackedInt32Array([WEIGHT_LIGHT])
	var modes: String = str(meta.get("modes", ""))
	if str(meta.get("kind", "")) != "arena":
		return result
	for name: String in modes.split(",", false):
		match name.strip_edges():
			"grub_stack":
				for value: int in [WEIGHT_HEAVY, WEIGHT_HEAVIER]:
					if not result.has(value):
						result.append(value)
			"hot_rock":
				if not result.has(WEIGHT_HOLDER):
					result.append(WEIGHT_HOLDER)
	result.sort()
	return result


## The walk / air cap (v16) of a weight class (C.14; 0 = the 1.0 Tuning.WALK_CAP).
static func class_walk_cap(weight_class: int) -> int:
	match weight_class:
		WEIGHT_HEAVY:
			return VersusTuning.STACK_HEAVY_WALK_CAP
		WEIGHT_HEAVIER:
			return VersusTuning.STACK_HEAVIER_WALK_CAP
		WEIGHT_HOLDER:
			return VersusTuning.HOT_ROCK_HOLDER_WALK_CAP
	return 0


## True when a weight class jumps with the 3/4 impulses (a 20+ stack).
static func class_jumps_short(weight_class: int) -> bool:
	return weight_class == WEIGHT_HEAVIER


## True when the graph has links verified for `weight_class`.
func has_class(weight_class: int) -> bool:
	return weights.has(weight_class)


## The class whose links a hero of `weight_class` uses: itself when baked, else the light class.
func usable_class(weight_class: int) -> int:
	return weight_class if has_class(weight_class) else WEIGHT_LIGHT


# =================================================================================================================
# Building
# =================================================================================================================

## Append a node (its id becomes its index).
func add_node(node: NavNode) -> NavNode:
	node.id = nodes.size()
	nodes.append(node)
	for list: Variant in _out:
		(list as Array).append(PackedInt32Array())
	if _out.is_empty():
		rebuild()
	return node


## Append a link (its id becomes its index); its `flags` are expanded from `keys`.
func add_link(link: NavLink) -> NavLink:
	link.id = links.size()
	link.flags = expand_keys(link.keys)
	links.append(link)
	if _out.size() != WEIGHT_CLASSES:
		rebuild()
	elif link.from >= 0 and link.from < nodes.size():
		var list: Array = _out[link.weight]
		var ids: PackedInt32Array = list[link.from]
		ids.append(link.id)
		list[link.from] = ids
	return link


## Recompute the outgoing link lists and the link ids (after loading or editing).
func rebuild() -> void:
	_out.clear()
	for c: int in WEIGHT_CLASSES:
		var per_node: Array = []
		for node: NavNode in nodes:
			per_node.append(PackedInt32Array())
		_out.append(per_node)
	for i: int in links.size():
		var link: NavLink = links[i]
		link.id = i
		link.flags = expand_keys(link.keys)
		if link.from >= 0 and link.from < nodes.size():
			var list: Array = _out[link.weight]
			var ids: PackedInt32Array = list[link.from]
			ids.append(link.id)
			list[link.from] = ids
	_mover_offsets.clear()
	_mover_motions.clear()
	for m: int in movers.size():
		_mover_offsets.append(Vector2i.ZERO)
		_mover_motions.append(Vector2i.ZERO)


## Add a mover (its index is returned; the same key twice gives the same index).
func add_mover(key: String, id: String, col: int, row: int, kind: StringName) -> int:
	for i: int in movers.size():
		if str(movers[i]["key"]) == key:
			return i
	movers.append({"key": key, "id": id, "col": col, "row": row, "kind": String(kind)})
	_mover_offsets.append(Vector2i.ZERO)
	_mover_motions.append(Vector2i.ZERO)
	return movers.size() - 1


## The mover key of a level entity: "<id>@<col>,<row>" (its spawn cell).
static func mover_key(id: StringName, col: int, row: int) -> String:
	return "%s@%d,%d" % [id, col, row]


## True when mover `index` is a pulley lift (its links are keyed by the pulley's offset).
func is_pulley_lift(index: int) -> bool:
	return index >= 0 and index < movers.size() and movers[index].has("pulley")


## Where a pulley at offset `p` comes to rest (objects-B's Pulley): the heavier side sinks to its limit, equal weights
## stay. `weight_a` / `weight_b`: the weights on its `a` / `b` lift.
static func pulley_rest(p: int, weight_a: int, weight_b: int, limit: int) -> int:
	if weight_a > weight_b:
		return limit
	if weight_b > weight_a:
		return -limit
	return p


## The pulley offset a pulley-lift link `link` was verified at (its cond's dy times the lift's side).
func link_pulley_offset(link: NavLink) -> int:
	if link.cond.size() < 5 or not is_pulley_lift(link.cond[0]):
		return 0
	return link.cond[2] * int(movers[link.cond[0]].get("side", 1))


# =================================================================================================================
# Queries
# =================================================================================================================

## Set where the movers are now (px from their level-start place, one Vector2i per mover; the bots call it every
## tick from the live platforms). Nodes on a mover move with it in [method node_at] and friends.
func set_mover_offsets(offsets: Array[Vector2i]) -> void:
	for i: int in mini(offsets.size(), _mover_offsets.size()):
		_mover_offsets[i] = offsets[i]


## Set one mover's live offset (px from its level-start place) and its motion of the last tick (px).
func set_mover_state(index: int, offset: Vector2i, motion: Vector2i) -> void:
	if index >= 0 and index < _mover_offsets.size():
		_mover_offsets[index] = offset
		_mover_motions[index] = motion


## The motion of mover `index` on the last tick (ZERO when unknown or still).
func mover_motion(index: int) -> Vector2i:
	return _mover_motions[index] if index >= 0 and index < _mover_motions.size() else Vector2i.ZERO


## The live offset of mover `index` (ZERO when unknown).
func mover_offset(index: int) -> Vector2i:
	return _mover_offsets[index] if index >= 0 and index < _mover_offsets.size() else Vector2i.ZERO


## The live offset of a node (its mover's, ZERO for a static node).
func node_offset(node: NavNode) -> Vector2i:
	return mover_offset(node.mover) if node.mover >= 0 else Vector2i.ZERO


## Live feet y of a node.
func node_y(node: NavNode) -> int:
	return node.y + node_offset(node).y


## Live x range of a node.
func node_x0(node: NavNode) -> int:
	return node.x0 + node_offset(node).x


func node_x1(node: NavNode) -> int:
	return node.x1 + node_offset(node).x


## The node a hero whose feet point is `pos` stands on; -1 when none (in the air, or not on a known span). Mover
## nodes are matched at their live place (any feet y within 2 px of the platform top). `riding`: the hero rides a
## platform now (PlayerBase.on_platform) - a mover node under him wins over a floor it overlaps.
func node_at(pos: Vector2i, riding: bool = false) -> int:
	var row: int = pos.y >> 4
	var found: int = -1
	for node: NavNode in nodes:
		if node.mover < 0:
			if found < 0 and node.row == row and node.contains_x(pos.x):
				if not riding:
					return node.id
				found = node.id
		else:
			var offset: Vector2i = mover_offset(node.mover)
			if absi(pos.y - (node.y + offset.y)) <= 2 and pos.x >= node.x0 + offset.x and pos.x <= node.x1 + offset.x:
				if riding or found < 0:
					return node.id
	return found


## The node nearest to `pos` (feet point; distance in px, vertical distance weighted double so that the floor under
## a jumping hero wins); -1 for an empty graph.
func nearest_node(pos: Vector2i) -> int:
	var best: int = -1
	var best_cost: int = UNREACHABLE
	for node: NavNode in nodes:
		var y: int = node_y(node)
		var cost: int = absi(clampi(pos.x, node_x0(node), node_x1(node)) - pos.x) + 2 * absi(y - pos.y)
		if y < pos.y:
			cost += 64  # a node above the point is reached only by climbing
		if cost < best_cost:
			best_cost = cost
			best = node.id
	return best


## The node under a point in the air: the first node below `pos` whose x range holds pos.x; -1 when none.
func node_below(pos: Vector2i) -> int:
	var best: int = -1
	var best_y: int = 0
	for node: NavNode in nodes:
		var y: int = node_y(node)
		if y >= pos.y and pos.x >= node_x0(node) and pos.x <= node_x1(node) and (best < 0 or y < best_y):
			best = node.id
			best_y = y
	return best


## The node of a feet point for planning: the node it stands on, else the one below it, else the nearest.
func node_for(pos: Vector2i) -> int:
	var node: int = node_at(pos)
	if node < 0:
		node = node_below(pos)
	if node < 0:
		node = nearest_node(pos)
	return node


func get_node_at(id: int) -> NavNode:
	return nodes[id] if id >= 0 and id < nodes.size() else null


func get_link(id: int) -> NavLink:
	return links[id] if id >= 0 and id < links.size() else null


## Outgoing link ids of a node for a weight class (an unbaked class uses the light links).
func links_from(node_id: int, weight_class: int = WEIGHT_LIGHT) -> PackedInt32Array:
	if _out.size() != WEIGHT_CLASSES or node_id < 0 or node_id >= nodes.size():
		return PackedInt32Array()
	var list: Array = _out[usable_class(clampi(weight_class, 0, WEIGHT_CLASSES - 1))]
	return list[node_id]


## Ticks to walk `dx` px.
static func walk_ticks(dx: int) -> int:
	return (absi(dx) + WALK_PX_PER_TICK - 1) / WALK_PX_PER_TICK


## Cost (ticks) of taking link `link` for a hero standing at `x` on its source node: walking into the window,
## settling, the expected wait of a timed or mover link, the move.
func link_cost_from(link: NavLink, x: int) -> int:
	var takeoff: int = clampi(x, link.x0, link.x1)
	var wait: int = 0
	if link.cycle.size() >= 3:
		wait = link.cycle[0] / 2
	elif not link.cond.is_empty():
		wait = MOVER_WAIT_TICKS
	return walk_ticks(takeoff - x) + SETTLE_TICKS + wait + link.ticks


## The cheapest route from (from_node, from_x) to (to_node, to_x): the link ids in order (empty when already on
## to_node, or when no route exists - see [method path_cost]). Deterministic: ties go to the lower link id.
## `blocked` = link ids not to use (links a bot saw fail); `weight_class` = whose links (WEIGHT_*).
func find_path(from_node: int, from_x: int, to_node: int, to_x: int, blocked: Dictionary = {},
		weight_class: int = WEIGHT_LIGHT) -> PackedInt32Array:
	return _search(from_node, from_x, to_node, to_x, blocked, weight_class)["path"]


## Estimated ticks from (from_node, from_x) to (to_node, to_x); UNREACHABLE when there is no route.
func path_cost(from_node: int, from_x: int, to_node: int, to_x: int, blocked: Dictionary = {},
		weight_class: int = WEIGHT_LIGHT) -> int:
	return int(_search(from_node, from_x, to_node, to_x, blocked, weight_class)["cost"])


## One search from (from_node, from_x) to every node: {"cost": PackedInt32Array, "x": PackedInt32Array} per node id -
## the cheapest ticks to stand on it and the x he arrives at (UNREACHABLE / 0 when it cannot be reached). For
## comparing many goals at once ([method reach_cost]).
func reach_from(from_node: int, from_x: int, blocked: Dictionary = {}, weight_class: int = WEIGHT_LIGHT) -> Dictionary:
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
	var heap: PackedInt64Array = PackedInt64Array()
	for id: int in links_from(from_node, weight_class):
		if not blocked.has(id):
			dist[id] = link_cost_from(links[id], from_x)
			heap_push(heap, dist[id], id)
	while not heap.is_empty():
		var key: int = heap_pop(heap)
		var current: int = key & ID_MASK
		var current_cost: int = key >> ID_BITS
		if done[current] == 1 or current_cost != dist[current]:
			continue
		done[current] = 1
		var link: NavLink = links[current]
		var land_x: int = link.land_center()
		if current_cost < cost[link.to]:
			cost[link.to] = current_cost
			at[link.to] = land_x
		for next: int in links_from(link.to, weight_class):
			if done[next] == 1 or blocked.has(next):
				continue
			var next_cost: int = current_cost + link_cost_from(links[next], land_x)
			if next_cost < dist[next]:
				dist[next] = next_cost
				heap_push(heap, next_cost, next)
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


# Edge-based Dijkstra on a binary heap: dist[link] = cheapest ticks until that link has landed (at its land centre).
func _search(from_node: int, from_x: int, to_node: int, to_x: int, blocked: Dictionary, weight_class: int) -> Dictionary:
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
	var heap: PackedInt64Array = PackedInt64Array()
	for id: int in links_from(from_node, weight_class):
		if blocked.has(id):
			continue
		dist[id] = link_cost_from(links[id], from_x)
		heap_push(heap, dist[id], id)
	while not heap.is_empty():
		var key: int = heap_pop(heap)
		var current: int = key & ID_MASK
		var current_cost: int = key >> ID_BITS
		if done[current] == 1 or current_cost != dist[current]:
			continue
		if current_cost >= best_cost:
			break
		done[current] = 1
		var link: NavLink = links[current]
		var land_x: int = link.land_center()
		if link.to == to_node:
			var total: int = current_cost + walk_ticks(to_x - land_x)
			if total < best_cost:
				best_cost = total
				best_last = current
		for next: int in links_from(link.to, weight_class):
			if done[next] == 1 or blocked.has(next):
				continue
			var cost: int = current_cost + link_cost_from(links[next], land_x)
			if cost < dist[next]:
				dist[next] = cost
				prev[next] = current
				heap_push(heap, cost, next)
	if best_cost >= UNREACHABLE:
		return none
	var path: PackedInt32Array = PackedInt32Array()
	var step: int = best_last
	while step >= 0:
		path.insert(0, step)
		step = prev[step]
	return {"path": path, "cost": best_cost}


# --- The binary heap of the searches (keys: cost << ID_BITS | link id) -------------------------------------------------

## Push (cost, id) onto a min-heap kept in `heap`.
static func heap_push(heap: PackedInt64Array, cost: int, id: int) -> void:
	var key: int = (cost << ID_BITS) | (id & ID_MASK)
	heap.append(key)
	var i: int = heap.size() - 1
	while i > 0:
		var parent: int = (i - 1) >> 1
		if heap[parent] <= key:
			break
		heap[i] = heap[parent]
		i = parent
	heap[i] = key


## Pop the smallest key of the min-heap `heap` (cost = key >> ID_BITS, id = key & ID_MASK); the heap must not be
## empty.
static func heap_pop(heap: PackedInt64Array) -> int:
	var top: int = heap[0]
	var last: int = heap[heap.size() - 1]
	heap.resize(heap.size() - 1)
	var size: int = heap.size()
	if size == 0:
		return top
	var i: int = 0
	while true:
		var child: int = 2 * i + 1
		if child >= size:
			break
		if child + 1 < size and heap[child + 1] < heap[child]:
			child += 1
		if heap[child] >= last:
			break
		heap[i] = heap[child]
		i = child
	heap[i] = last
	return top


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
