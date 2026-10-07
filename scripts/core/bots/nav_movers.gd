class_name NavMovers
extends RefCounted
## The moving geometry of a nav-graph bake (PLAN.md P2.5 "moving geometry in graphs: lifts, see-saws, geysers,
## floes"; DESIGN.md E.7 "moving geometry (lifts, floes) is a moving node"). Owner: core-B. Used by [NavBaker].
##
## Every platform part of the level's movers ([NavSim]: objects/platform, objects/drop_platform, the two ends of an
## objects/seesaw, the lifts of an objects/pulley) becomes a **mover node** at its level-start place; the bots match it
## live through [NavMoversLive]. Two kinds (NavGraph.MOVER_*):
##  - periodic: a platform that moves by itself (objects/platform mode=always, not on a pulley): its motion repeats
##    with a period found by simulating it alone. Its links are verified at PHASE_STEP-spaced phases of that period
##    (the movers rolled forward without the hero), each with the mover's state at take-off as the link's `cond`.
##  - rider: a platform that moves under weight (drop platform, see-saw end, pulley lift, mode=ride): boarding links
##    start with it at rest (its level-start state); links off it start after the hero stood on it STAND_TICKS ticks
##    (the platform sinking, falling or tilting under him), each with the state reached as its `cond`.
## Links: **board** (a static node -> a mover node: a jump or walk-off that ends with him riding the part) and **off**
## (a mover node -> any other node). Every start x of a window was simulated; windows on a mover node are kept in the
## node's level-start frame (the live take-off x is the window plus the mover's offset). The bot waits in the window
## until the live mover matches `cond` (NavMoversLive.matches), so the move starts from the verified state.

## Phases of a periodic mover are sampled this far apart (ticks).
const PHASE_STEP: int = 12
## A period is looked for up to this many ticks; longer movers keep only their level-start phase.
const PERIOD_MAX: int = 720
## Rider movers: stand this long on the part before the take-off of an off link (0 = at once).
const STAND_TICKS: Array[int] = [0, 8, 16, 32, 64]
## Board links come from static nodes at most this far from the part (px, by axis).
const BOARD_REACH_X: int = 96
const BOARD_REACH_Y: int = 112
## Take-off points on a part are sampled this far apart.
const PART_SAMPLE_STEP: int = 8

var baker: NavBaker = null
## Mover nodes found.
var node_count: int = 0
## Mover links added.
var link_count: int = 0
# Per mover node id: the part index in NavSim.mover_parts; per part: the period (0 = not periodic / none found).
var _node_part: Dictionary = {}
var _periods: PackedInt32Array = PackedInt32Array()
var _memo: Dictionary = {}


func _init(p_baker: NavBaker) -> void:
	baker = p_baker


## Add the mover nodes to the graph.
func find_nodes() -> void:
	var sim: NavSim = baker.sim
	var graph: NavGraph = baker.graph
	var clip: Rect2i = baker.clip_rect()
	var pulley_names: Dictionary = {}
	for record: Dictionary in sim.mover_records:
		if record["id"] == &"objects/pulley":
			var params: Dictionary = record["params"]
			for key: String in ["a", "b"]:
				if params.has(key):
					pulley_names[str(params[key])] = true
	_periods.resize(sim.mover_parts.size())
	_periods.fill(0)
	for i: int in sim.mover_parts.size():
		var part: Dictionary = sim.mover_parts[i]
		var record: Dictionary = sim.mover_records[int(part["mover"])]
		var entity: SimEntity = part["entity"]
		var box: Rect2i = entity.get_box()
		if clip.size.x > 0 and not Rect2i(clip.position * Tuning.TILE, clip.size * Tuning.TILE).has_point(box.position):
			continue
		var params: Dictionary = record["params"]
		var rider: bool = record["id"] != &"objects/platform" or str(params.get("mode", "always")) == "ride" \
				or pulley_names.has(str(params.get("name", "")))
		var kind: StringName = NavGraph.MOVER_RIDER if rider else NavGraph.MOVER_PERIODIC
		var key: String = NavGraph.mover_key(record["id"], int(record["col"]), int(record["row"]))
		if int(part["part"]) >= 0:
			key += "#%d" % int(part["part"])
		var node: NavGraph.NavNode = NavGraph.NavNode.new()
		node.y = box.position.y
		node.row = node.y >> 4
		node.x0 = box.position.x + 4
		node.x1 = box.end.x - 5
		if node.x0 > node.x1:
			continue
		# Stand him on it (fresh world): he must ride it, alive.
		var outcome: NavSim.Outcome = sim.run(Vector2i(node.center_x(), node.y), PackedInt32Array([0, 0, 0]), 8)
		if outcome.died or outcome.platform != entity:
			baker.rejected += 1
			baker.report.append("mover node rejected: %s (he does not ride it at %s)" % [key,
					Vector2i(node.center_x(), node.y)])
			continue
		var mover: int = graph.add_mover(key, String(record["id"]), int(record["col"]), int(record["row"]), kind)
		var spawned: SimEntity = sim.movers[int(part["mover"])]
		graph.movers[mover]["x"] = spawned.spawn_pos.x
		graph.movers[mover]["y"] = spawned.spawn_pos.y
		graph.movers[mover]["part"] = int(part["part"])
		graph.movers[mover]["top"] = [box.position.x, box.position.y]
		node.mover = mover
		graph.add_node(node)
		_node_part[node.id] = i
		node_count += 1
		if not rider:
			_periods[i] = _find_period(i)


## The period (ticks) of mover part `index` moving alone from the level start; 0 when none within PERIOD_MAX.
func _find_period(index: int) -> int:
	var sim: NavSim = baker.sim
	sim.run(NavSim.PARK, PackedInt32Array(), 0)
	sim.roll_movers(0)
	var states: Array[PackedInt32Array] = []
	sim.hero.respawn_at(NavSim.PARK)
	Sim.suspend(sim.hero)
	for t: int in PERIOD_MAX + 24:
		states.append(sim.mover_states()[index])
		Sim.step(1)
		sim.ticks_simulated += 1
	Sim.resume(sim.hero)
	for period: int in range(2, PERIOD_MAX):
		var same: bool = true
		for k: int in 24:
			if states[period + k] != states[k]:
				same = false
				break
		if same:
			return period
	return 0


## Find and verify the links to, from and between mover nodes for one weight class.
func find_links(_weight_class: int) -> void:
	_memo.clear()
	var graph: NavGraph = baker.graph
	for node_id: int in _node_part.keys():
		var part: int = int(_node_part[node_id])
		var mover: int = graph.nodes[node_id].mover
		var periodic: bool = StringName(str(graph.movers[mover]["kind"])) == NavGraph.MOVER_PERIODIC
		var phases: PackedInt32Array = PackedInt32Array([0])
		if periodic and _periods[part] > 0:
			phases.clear()
			var phase: int = 0
			while phase < _periods[part]:
				phases.append(phase)
				phase += PHASE_STEP
		for phase: int in phases:
			_board_links(node_id, part, mover, phase)
		if periodic:
			for phase: int in phases:
				_off_links(node_id, part, mover, phase, 0)
		else:
			for stand: int in STAND_TICKS:
				_off_links(node_id, part, mover, 0, stand)


## Board links onto mover node `to` (part `part`) at phase `phase` from every static node near the part.
func _board_links(to: int, part: int, mover: int, phase: int) -> void:
	var graph: NavGraph = baker.graph
	var sim: NavSim = baker.sim
	var home: Vector2i = sim.part_homes[part]
	var probe: NavSim.Outcome = sim.run(NavSim.PARK, PackedInt32Array(), 0, -1, phase)
	var state: PackedInt32Array = probe.mover_states[part] if part < probe.mover_states.size() else PackedInt32Array()
	if state.size() < 4:
		return
	var at: Vector2i = home + Vector2i(state[0], state[1])
	for from: int in graph.nodes.size():
		var node: NavGraph.NavNode = graph.nodes[from]
		if node.mover >= 0 or absi(node.y - at.y) > BOARD_REACH_Y:
			continue
		var near: int = clampi(at.x, node.x0, node.x1)
		if absi(near - at.x) > BOARD_REACH_X and absi(near - (at.x + graph.nodes[to].x1 - graph.nodes[to].x0)) > BOARD_REACH_X:
			continue
		var xs: PackedInt32Array = PackedInt32Array()
		var x: int = node.x0
		while x <= node.x1:
			if absi(x - at.x) <= BOARD_REACH_X + 48:
				xs.append(x)
			x += NavBaker.SAMPLE_STEP
		if xs.is_empty():
			continue
		var best: Dictionary = {}
		for s: int in baker.ground_scripts():
			for seed_x: int in xs:
				if _land(from, s, seed_x, phase, 0, node.y) != to:
					continue
				var window: Dictionary = _widen(from, to, s, seed_x, phase, 0, node.y, Vector2i(node.x0, node.x1))
				var width: int = int(window["x1"]) - int(window["x0"]) + 1
				if width >= NavBaker.MIN_WINDOW and (best.is_empty() or int(window["ticks"]) < int(best["ticks"])):
					best = window
				break
		if not best.is_empty():
			_add(from, to, best, PackedInt32Array([mover, state[0], state[1], state[2], state[3]]), phase, 0)


## Off links from mover node `from` (part `part`) at phase `phase` after standing `stand` ticks on it.
func _off_links(from: int, part: int, mover: int, phase: int, stand: int) -> void:
	var graph: NavGraph = baker.graph
	var node: NavGraph.NavNode = graph.nodes[from]
	# Where the part is at the take-off (after the preroll and the standing): one probe from its middle.
	var probe: NavSim.Outcome = _probe(part, phase, stand, node)
	if probe == null or probe.mover_states.size() <= part:
		return
	var state: PackedInt32Array = probe.mover_states[part]
	var by_target: Dictionary = {}
	var x: int = node.x0
	var xs: PackedInt32Array = PackedInt32Array()
	while x < node.x1:
		xs.append(x)
		x += PART_SAMPLE_STEP
	xs.append(node.x1)
	for s: int in baker.ground_scripts():
		for seed_x: int in xs:
			var to: int = _land(from, s, seed_x, phase, stand, -1)
			if to < 0 or to == from:
				continue
			var window: Dictionary = _widen(from, to, s, seed_x, phase, stand, -1, Vector2i(node.x0, node.x1))
			var width: int = int(window["x1"]) - int(window["x0"]) + 1
			if width < NavBaker.MIN_WINDOW:
				continue
			# The same take-off state as the probe's (the part may move differently with him elsewhere on it).
			if not _same_state(window, state):
				continue
			if not by_target.has(to) or int(window["ticks"]) < int(by_target[to]["ticks"]):
				by_target[to] = window
	var targets: Array = by_target.keys()
	targets.sort()
	for to: Variant in targets:
		_add(from, int(to), by_target[to], PackedInt32Array([mover, state[0], state[1], state[2], state[3]]), phase,
				stand)


func _probe(part: int, phase: int, stand: int, node: NavGraph.NavNode) -> NavSim.Outcome:
	var sim: NavSim = baker.sim
	var start_state: NavSim.Outcome = sim.run(NavSim.PARK, PackedInt32Array(), 0, -1, phase)
	if start_state.mover_states.size() <= part:
		return null
	var s: PackedInt32Array = start_state.mover_states[part]
	var start: Vector2i = Vector2i(node.center_x() + s[0], node.y + s[1])
	return sim.run(start, PackedInt32Array([0]), 1, -1, phase, stand)


func _same_state(window: Dictionary, state: PackedInt32Array) -> bool:
	return window.has("state") and window["state"] == state


## Simulate script `s` from x (in the source node's level-start frame) with the movers at `phase` and `stand` ticks
## of standing first; the node he settles on (mover nodes count while he rides their part), or -1. Cached.
func _land(from: int, s: int, x: int, phase: int, stand: int, static_y: int) -> int:
	var key: String = "%d:%d:%d:%d:%d" % [from, s, x, phase, stand]
	if _memo.has(key):
		return int((_memo[key] as Dictionary)["to"])
	var result: Dictionary = _simulate(from, baker.script_flags(s), x, phase, stand, static_y)
	_memo[key] = result
	return int(result["to"])


## One run: {"to", "ticks", "land", "state"}.
func _simulate(from: int, flags: PackedInt32Array, x: int, phase: int, stand: int, static_y: int) -> Dictionary:
	var sim: NavSim = baker.sim
	var graph: NavGraph = baker.graph
	var node: NavGraph.NavNode = graph.nodes[from]
	var start: Vector2i = Vector2i(x, static_y if static_y >= 0 else node.y)
	if node.mover >= 0:
		# On a part: his x and y move with the part's place at the preroll's end.
		var part: int = int(_node_part.get(from, -1))
		if part < 0:
			return {"to": -1, "ticks": 0, "land": 0, "state": PackedInt32Array()}
		var at: NavSim.Outcome = sim.run(NavSim.PARK, PackedInt32Array(), 0, -1, phase)
		var s: PackedInt32Array = at.mover_states[part]
		start = Vector2i(x + s[0], node.y + s[1])
	var outcome: NavSim.Outcome = sim.run(start, flags, NavBaker.MAX_TICKS, -1, phase, stand)
	baker.candidates += 1
	var to: int = -1
	if not outcome.died and (outcome.landed or outcome.walked):
		if outcome.platform != null:
			var index: int = sim.part_index(outcome.platform)
			for node_id: int in _node_part:
				if int(_node_part[node_id]) == index:
					to = node_id
		else:
			to = graph.node_at(outcome.pos)
			if to >= 0 and graph.nodes[to].mover >= 0:
				to = -1
	var state: PackedInt32Array = PackedInt32Array()
	if node.mover >= 0:
		state = outcome.mover_states[int(_node_part[from])]
	return {"to": to, "ticks": outcome.landing_tick, "land": outcome.pos.x, "state": state}


func _widen(from: int, to: int, s: int, seed_x: int, phase: int, stand: int, static_y: int, limits: Vector2i) -> Dictionary:
	var x0: int = seed_x
	var x1: int = seed_x
	while x1 - x0 + 1 < NavBaker.MAX_WINDOW and x0 - 1 >= limits.x and _land(from, s, x0 - 1, phase, stand, static_y) == to:
		x0 -= 1
	while x1 - x0 + 1 < NavBaker.MAX_WINDOW and x1 + 1 <= limits.y and _land(from, s, x1 + 1, phase, stand, static_y) == to:
		x1 += 1
	var ticks: int = 0
	var land0: int = 1 << 30
	var land1: int = -(1 << 30)
	var state: PackedInt32Array = PackedInt32Array()
	var same: bool = true
	for x: int in range(x0, x1 + 1):
		_land(from, s, x, phase, stand, static_y)
		var result: Dictionary = _memo["%d:%d:%d:%d:%d" % [from, s, x, phase, stand]]
		ticks = maxi(ticks, int(result["ticks"]))
		land0 = mini(land0, int(result["land"]))
		land1 = maxi(land1, int(result["land"]))
		if x == x0:
			state = result["state"]
		elif result["state"] != state:
			same = false
	var window: Dictionary = {
		"script": s, "x0": x0, "x1": x1, "ticks": ticks, "land_x0": land0, "land_x1": land1, "phase": phase,
		"stand": stand,
	}
	if same:
		window["state"] = state
	return window


func _add(from: int, to: int, window: Dictionary, cond: PackedInt32Array, _phase: int, _stand: int) -> void:
	var link: NavGraph.NavLink = NavGraph.NavLink.new()
	link.from = from
	link.to = to
	link.x0 = int(window["x0"])
	link.x1 = int(window["x1"])
	var s: int = int(window["script"])
	var flags: PackedInt32Array = baker.script_flags(s).slice(0, maxi(int(window["ticks"]), 1))
	link.keys = NavGraph.compress_flags(flags)
	link.ticks = int(window["ticks"])
	link.land_x0 = int(window["land_x0"])
	link.land_x1 = int(window["land_x1"])
	link.dir = signi(link.land_center() - link.window_center())
	link.kind = NavGraph.KIND_RIDE
	link.cond = cond
	baker.add_verified_link(link)
	link_count += 1


## Re-run a mover link from take-off x `x` with the state its `cond` was verified in (the phase or standing that
## leads there is found again by the same search): {"node", "pos"}. Used by NavBaker.verify_graph.
func run_link(link: NavGraph.NavLink, x: int) -> Dictionary:
	var graph: NavGraph = baker.graph
	if _node_part.is_empty():
		_rebuild_parts()
	var recipe: Vector2i = _recipe_for(link)
	if recipe.x < 0:
		return {"node": -1, "pos": Vector2i.ZERO}
	var from: NavGraph.NavNode = graph.nodes[link.from]
	var result: Dictionary = _simulate(link.from, link.flags, x, recipe.x, recipe.y, -1 if from.mover >= 0 else from.y)
	return {"node": int(result["to"]), "pos": Vector2i(int(result["land"]), 0)}


## Map the graph's mover nodes to the sim's parts (a verify without a bake).
func _rebuild_parts() -> void:
	var graph: NavGraph = baker.graph
	var sim: NavSim = baker.sim
	_periods.resize(sim.mover_parts.size())
	_periods.fill(0)
	for node: NavGraph.NavNode in graph.nodes:
		if node.mover < 0:
			continue
		var mover: Dictionary = graph.movers[node.mover]
		for i: int in sim.mover_parts.size():
			var part: Dictionary = sim.mover_parts[i]
			var spawned: SimEntity = sim.movers[int(part["mover"])]
			if spawned.spawn_pos == Vector2i(int(mover.get("x", 0)), int(mover.get("y", 0))) \
					and int(part["part"]) == int(mover.get("part", -1)):
				_node_part[node.id] = i
				if StringName(str(mover["kind"])) == NavGraph.MOVER_PERIODIC:
					_periods[i] = _find_period(i)


## (phase, stand) that bring the link's mover into its `cond` state; (-1, -1) when none.
func _recipe_for(link: NavGraph.NavLink) -> Vector2i:
	var graph: NavGraph = baker.graph
	var mover: int = link.cond[0]
	var part: int = -1
	for node_id: int in _node_part:
		if graph.nodes[node_id].mover == mover:
			part = int(_node_part[node_id])
	if part < 0:
		return Vector2i(-1, -1)
	var want: PackedInt32Array = link.cond.slice(1, 5)
	var periodic: bool = StringName(str(graph.movers[mover]["kind"])) == NavGraph.MOVER_PERIODIC
	var phases: PackedInt32Array = PackedInt32Array([0])
	if periodic and _periods[part] > 0:
		phases.clear()
		var phase: int = 0
		while phase < _periods[part]:
			phases.append(phase)
			phase += PHASE_STEP
	var stands: Array[int] = [0] if periodic or graph.nodes[link.from].mover < 0 else STAND_TICKS
	for phase: int in phases:
		for stand: int in stands:
			var probe: NavSim.Outcome = null
			if graph.nodes[link.from].mover >= 0:
				probe = _probe(part, phase, stand, graph.nodes[link.from])
			else:
				probe = baker.sim.run(NavSim.PARK, PackedInt32Array(), 0, -1, phase)
			if probe != null and probe.mover_states.size() > part and probe.mover_states[part] == want:
				return Vector2i(phase, stand)
	return Vector2i(-1, -1)
