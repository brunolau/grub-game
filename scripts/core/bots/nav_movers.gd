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
##  - rider: a platform that moves under weight (drop platform, see-saw end, mode=ride): boarding links start with it
##    at rest (its level-start state); links off it start after the hero stood on it STAND_TICKS ticks (the platform
##    sinking, falling or tilting under him), each with the state reached as its `cond`.
##  - a pulley lift (a rider; core-B wf10, wf9_da_to_core_b.txt #1): a pulley never returns to its level-start state
##    (equal weights do not move it), so its two lifts get links at EVERY still pulley offset p (NavSim.pulley_preset,
##    PULLEY_SPEED_PX apart up to the pulley's limit): board links with the pulley still at p and nobody on the lifts,
##    off links with the hero standing on the lift at p and the pulley held there (NavSim.pulley_frozen: an equal
##    weight on the other lift; at the lift's bottom his own weight holds it), to static nodes only and without
##    touching a lift after take-off (the other lift moves once he has left). `cond` = [mover, 0, side * p, 0, 0].
##    Search cost: every pulley state of a COARSE_PX grid is searched in full; a state between two grid states looks
##    only at the sources and targets its two grid neighbours have links with, and tries their scripts first, then the
##    scripts kept for that pair at any grid state (no full search there: a link that needs yet another script in the
##    few px between two grid states is left out; a lift without any off link gets the full search all the same).
##    Every kept window is simulated at every x in every state. An off search widens a take-off only when it can
##    beat the fastest window found for its target (the same links as without that shortcut).
##  - links past a lift's column (wf9_da_to_core_b.txt #1, "the failing spring / jump links that pass a displaced
##    lift"): a link between two other nodes was verified with the lifts at their level start; when its flight comes
##    within CLEAR_REACH_PX of a lift's column, every start of its window is run again at every still pulley state
##    and the link gets the ranges of pulley offsets it lands in (NavLink.clear_at) - a lift risen or sunk into its
##    way makes the bot take another link instead of bumping into it.
## Links: **board** (a static node -> a mover node: a jump or walk-off that ends with him riding the part, already on
## the tick the bot takes over) and **off** (a mover node -> any other node, from the middle OFF_MIDDLE_PX of the part
## only, the rider standing RIDE_SINK_PX into its top as a real rider does). Every start x of a window was simulated;
## windows on a mover node are kept in the node's level-start frame (the live take-off x is the window plus the
## mover's offset). The bot waits in the window until the live mover matches `cond` (NavMoversLive.matches), so the
## move starts from the verified state. Part boxes are taken where the movers were spawned (NavSim.part_homes).

## Phases of a periodic mover are sampled this far apart (ticks).
const PHASE_STEP: int = 12
## A period is looked for up to this many ticks; longer movers keep only their level-start phase.
const PERIOD_MAX: int = 720
## Rider movers: stand this long on the part before the take-off of an off link (0 = at once).
const STAND_TICKS: Array[int] = [0, 8, 16, 32, 64]
## Board links come from static nodes at most this far beside the part (px), at most BOARD_RISE_PX below its top (the
## light hero's jump rise is 60 px) and at most BOARD_REACH_Y above it.
const BOARD_REACH_X: int = 96
const BOARD_REACH_Y: int = 112
const BOARD_RISE_PX: int = 60
## A boarding window this wide ends the search of slower scripts for that source node and phase.
const BOARD_GOOD_WINDOW: int = 8
## Take-off points on a part are sampled this far apart, within OFF_MIDDLE_PX of its middle.
const PART_SAMPLE_STEP: int = 8
const OFF_MIDDLE_PX: int = 10
## A rider stands this far into the platform's top (PlayerBase.ride_platform: feet at top + 1, yvel 1): the take-offs
## from a mover node start there, as a bot riding it does.
const RIDE_SINK_PX: int = 1
## No pulley preset (a run from the level-start state of the movers).
const PULLEY_NONE: int = 1 << 24
## Pulley states searched in full lie this far apart (px of pulley offset); the ones between are seeded from them.
const COARSE_PX: int = 8
## A link between two other nodes is swept over the pulley states when his feet come this near (px) a lift's column
## on the way (half his body and a margin).
const CLEAR_REACH_PX: int = 14

var baker: NavBaker = null
## Mover nodes found.
var node_count: int = 0
## Mover links added.
var link_count: int = 0
## Links past the lifts that got `clear_at` ranges (statistics).
var clear_count: int = 0
# Per mover node id: the part index in NavSim.mover_parts; per part: the period (0 = not periodic / none found).
var _node_part: Dictionary = {}
var _periods: PackedInt32Array = PackedInt32Array()
var _memo: Dictionary = {}
# The movers' states after `phase` ticks alone (phase -> Array[PackedInt32Array]) and the probes of off links
# ("part:phase:stand" -> Outcome): the same world state every time, so simulated once.
var _phase_states: Dictionary = {}
var _probes: Dictionary = {}
# Pulley sweep of the class being baked: "board:<to>:<p>" -> {from node id: script id} and "off:<from>:<p>" -> {to
# node id: script id} of the links kept (the seeds of the states between the grid states), and per lift node every
# script kept at any of its grid states: "board:<to>" -> {from node id: script ids}, "off:<from>" -> {to node id:
# script ids}.
var _sweep: Dictionary = {}
var _grid_scripts: Dictionary = {}


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
		# Its box where it was spawned (NavSim.part_homes; the entity of the last run has moved since).
		var box: Rect2i = Rect2i(sim.part_homes[i], entity.get_box().size)
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
		# Stand him on it (fresh world: every run spawns the movers anew, so the part is matched by its index): he must
		# ride it, alive.
		var outcome: NavSim.Outcome = sim.run(Vector2i(node.center_x(), node.y), PackedInt32Array([0, 0, 0]), 8)
		if outcome.died or outcome.platform == null or sim.part_index(outcome.platform) != i:
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
		if i < sim.part_pulley.size() and sim.part_pulley[i] >= 0:
			graph.movers[mover]["pulley"] = sim.part_pulley[i]
			graph.movers[mover]["side"] = sim.part_side[i]
			graph.movers[mover]["limit"] = sim.pulley_limits[sim.part_pulley[i]]
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


## The mover graph index of mover part `part` (-1 when the part has no node).
func mover_of_part(part: int) -> int:
	if _node_part.is_empty():
		_rebuild_parts()
	for node_id: int in _node_part:
		if int(_node_part[node_id]) == part:
			return baker.graph.nodes[node_id].mover
	return -1


## Find and verify the links to, from and between mover nodes for one weight class, in one go (the jobs of
## [method add_jobs] one after the other).
func find_links(_weight_class: int) -> void:
	begin_class()
	var jobs: Array[Callable] = []
	add_jobs(jobs)
	for job: Callable in jobs:
		job.call()


## A weight class starts: forget the runs and the pulley sweep of the last one.
func begin_class() -> void:
	_memo.clear()
	_sweep.clear()
	_grid_scripts.clear()


## Append the mover work of one weight class to `jobs`, in the order it must run (NavBaker runs the jobs; a bake in
## frames lets the engine finish a frame between them): per mover node the board links of every phase, then its off
## links; then, per pulley lift, one job per pulley state - the COARSE_PX grid states first, then the states between
## them (they are seeded from the grid states).
func add_jobs(jobs: Array[Callable]) -> void:
	var graph: NavGraph = baker.graph
	var sim: NavSim = baker.sim
	var lifts: Array[int] = []
	for node_id: int in _node_part.keys():
		var part: int = int(_node_part[node_id])
		var mover: int = graph.nodes[node_id].mover
		if part < sim.part_pulley.size() and sim.part_pulley[part] >= 0:
			lifts.append(node_id)
			continue
		var periodic: bool = StringName(str(graph.movers[mover]["kind"])) == NavGraph.MOVER_PERIODIC
		var phases: PackedInt32Array = PackedInt32Array([0])
		if periodic and _periods[part] > 0:
			phases.clear()
			var phase: int = 0
			while phase < _periods[part]:
				phases.append(phase)
				phase += PHASE_STEP
		for phase: int in phases:
			jobs.append(_board_links.bind(node_id, part, mover, phase, PULLEY_NONE))
		if periodic:
			for phase: int in phases:
				jobs.append(_off_links.bind(node_id, part, mover, phase, 0, PULLEY_NONE))
		else:
			jobs.append(_rider_off_links.bind(node_id, part, mover))
	for node_id: int in lifts:
		var limit: int = sim.pulley_limits[sim.part_pulley[int(_node_part[node_id])]]
		var offsets: PackedInt32Array = pulley_offsets(limit)
		for p: int in offsets:
			if is_grid_offset(p, limit):
				jobs.append(_pulley_state_links.bind(node_id, p))
		for p: int in offsets:
			if not is_grid_offset(p, limit):
				jobs.append(_pulley_state_links.bind(node_id, p))
	# The links between other nodes that pass a lift's column: one job per source node (they exist by then).
	if not lifts.is_empty():
		for node: NavGraph.NavNode in graph.nodes:
			if node.mover < 0:
				jobs.append(_clear_links_from.bind(node.id))


## Job: the off links of rider mover node `node_id` after every standing time of STAND_TICKS.
func _rider_off_links(node_id: int, part: int, mover: int) -> void:
	# A rider mover may look the same after different standing times (a drop platform waits its `delay` at rest): only
	# the first standing time of each look is baked - the one a verification finds again ([method _recipe_for]); a bot
	# that stood longer and sees the same look may still miss, and its navigator blocks that link after two misses.
	var looks: Array[PackedInt32Array] = []
	for stand: int in STAND_TICKS:
		var probe: NavSim.Outcome = _probe(part, 0, stand, baker.graph.nodes[node_id], PULLEY_NONE)
		if probe == null or probe.mover_states.size() <= part or looks.has(probe.mover_states[part]):
			continue
		looks.append(probe.mover_states[part])
		_off_links(node_id, part, mover, 0, stand, PULLEY_NONE)


## The still offsets of a pulley whose lifts travel `limit` px: every PartyTuning.PULLEY_SPEED_PX step from the
## level start (0) and both limits, ascending.
static func pulley_offsets(limit: int) -> PackedInt32Array:
	var step: int = maxi(PartyTuning.PULLEY_SPEED_PX, 1)
	var result: PackedInt32Array = PackedInt32Array([-limit])
	var p: int = -((limit - 1) / step) * step
	while p < limit:
		if p > -limit:
			result.append(p)
		p += step
	result.append(limit)
	return result


## True when pulley offset `p` is searched in full (a COARSE_PX grid state or a limit); the others are seeded.
static func is_grid_offset(p: int, limit: int) -> bool:
	return p == -limit or p == limit or posmod(p, COARSE_PX) == 0


## Job: the links onto and off pulley lift node `node_id` with its pulley still at offset `p` - a grid state in full, a
## state between two grid states seeded from them (their jobs ran before).
func _pulley_state_links(node_id: int, p: int) -> void:
	var part: int = int(_node_part[node_id])
	var mover: int = baker.graph.nodes[node_id].mover
	var pulley: int = baker.sim.part_pulley[part]
	var limit: int = baker.sim.pulley_limits[pulley]
	var preset: int = encode_preset(pulley, p)
	if is_grid_offset(p, limit):
		for kind: String in ["board", "off"]:
			var kept: Dictionary = _board_links(node_id, part, mover, 0, preset) if kind == "board" \
					else _off_links(node_id, part, mover, 0, 0, preset)
			_sweep["%s:%d:%d" % [kind, node_id, p]] = kept
			_grid_scripts["%s:%d" % [kind, node_id]] = _merge_seeds(_grid_scripts.get("%s:%d" % [kind, node_id], {}),
					kept)
		return
	var below: int = p - posmod(p, COARSE_PX)
	var above: int = mini(below + COARSE_PX, limit)
	below = maxi(below, -limit)
	var board_seed: Dictionary = _seeds_between("board", node_id, below, above)
	var off_seed: Dictionary = _seeds_between("off", node_id, below, above)
	_sweep["board:%d:%d" % [node_id, p]] = _board_links(node_id, part, mover, 0, preset, board_seed)
	_sweep["off:%d:%d" % [node_id, p]] = _off_links(node_id, part, mover, 0, 0, preset, off_seed)


## Job: the pulley states in which the links of the class being baked from static node `from` to another static node
## hold (NavLink.clear_at). A link whose feet stay CLEAR_REACH_PX clear of every lift's column needs none. The others
## are run from every x of their window at every still state of that lift's pulley (nobody on the lifts); a link that
## lands everywhere keeps no ranges either.
func _clear_links_from(from: int) -> void:
	var graph: NavGraph = baker.graph
	var sim: NavSim = baker.sim
	var node: NavGraph.NavNode = graph.nodes[from]
	for link: NavGraph.NavLink in graph.links:
		if link.from != from or link.weight != baker.weight_class() or not link.cond.is_empty() \
				or graph.nodes[link.to].mover >= 0 or link.kind == NavGraph.KIND_GEYSER:
			continue
		# Where his feet go at the level start: the pulley whose lift's column they come near.
		var reach: Vector2i = Vector2i(1 << 30, -(1 << 30))
		for x: int in [link.x0, link.window_center(), link.x1]:
			var outcome: NavSim.Outcome = sim.run(Vector2i(x, node.y), link.flags, NavBaker.MAX_TICKS)
			baker.count_candidate()
			reach = Vector2i(mini(reach.x, outcome.min_x), maxi(reach.y, outcome.max_x))
		var pulley: int = -1
		for lift_id: int in _node_part:
			var part: int = int(_node_part[lift_id])
			if part >= sim.part_pulley.size() or sim.part_pulley[part] < 0:
				continue
			var lift: NavGraph.NavNode = graph.nodes[lift_id]
			if reach.y >= lift.x0 - 4 - CLEAR_REACH_PX and reach.x <= lift.x1 + 5 + CLEAR_REACH_PX:
				pulley = sim.part_pulley[part]
				break
		if pulley < 0:
			continue
		var ranges: PackedInt32Array = PackedInt32Array([pulley])
		var open: bool = false
		var last: int = 0
		var everywhere: bool = true
		for p: int in pulley_offsets(sim.pulley_limits[pulley]):
			var lands: bool = true
			for x: int in range(link.x0, link.x1 + 1):
				if run_past_lifts(link, x, encode_preset(pulley, p)) != link.to:
					lands = false
					break
			if lands and not open:
				ranges.append(p)
				open = true
			elif not lands and open:
				ranges.append(last)
				open = false
			everywhere = everywhere and lands
			last = p
		if open:
			ranges.append(last)
		if not everywhere:
			link.clear_at = ranges
			clear_count += 1


## Run link `link` (between two static nodes) from x with the pulley of `preset` still at its offset and nobody on the
## lifts: the node he settles on, -1 when he does not, or rode a lift on the way.
func run_past_lifts(link: NavGraph.NavLink, x: int, preset: int) -> int:
	var sim: NavSim = baker.sim
	var graph: NavGraph = baker.graph
	_set_preset(preset, false)
	var outcome: NavSim.Outcome = sim.run(Vector2i(x, graph.nodes[link.from].y), link.flags, NavBaker.MAX_TICKS)
	_set_preset(PULLEY_NONE, false)
	baker.count_candidate()
	if outcome.platform != null or outcome.handback_platform != null:
		return -1
	for part: int in outcome.rode:
		if part < sim.part_pulley.size() and sim.part_pulley[part] >= 0:
			return -1
	var landed: int = NavBaker.settled_node(graph, outcome)
	return landed if landed >= 0 and graph.nodes[landed].mover < 0 else -1


## The seeds of a pulley state between the grid states `below` and `above` of lift node `node_id` (`kind` "board" or
## "off"): per source / target node of those two states' links its scripts - theirs first, then the ones kept for
## that node at any other grid state.
func _seeds_between(kind: String, node_id: int, below: int, above: int) -> Dictionary:
	var seeds: Dictionary = _merge_seeds(_sweep.get("%s:%d:%d" % [kind, node_id, below], {}),
			_sweep.get("%s:%d:%d" % [kind, node_id, above], {}))
	var all: Dictionary = _grid_scripts.get("%s:%d" % [kind, node_id], {})
	for other: Variant in seeds:
		var scripts: PackedInt32Array = seeds[other]
		for s: int in all.get(other, PackedInt32Array()):
			if not scripts.has(s):
				scripts.append(s)
		seeds[other] = scripts
	return seeds


## Node id -> scripts (PackedInt32Array) of two sweeps ({node id: script id, or script ids}).
static func _merge_seeds(a: Dictionary, b: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for source: Dictionary in [a, b]:
		for node_id: Variant in source:
			var scripts: PackedInt32Array = result.get(node_id, PackedInt32Array())
			var more: PackedInt32Array = source[node_id] if source[node_id] is PackedInt32Array \
					else PackedInt32Array([int(source[node_id])])
			for s: int in more:
				if not scripts.has(s):
					scripts.append(s)
			result[node_id] = scripts
	return result


## A pulley preset as one int (memo keys): pulley index and offset; PULLEY_NONE = none.
static func encode_preset(pulley: int, p: int) -> int:
	return pulley * 65536 + (p + 32768)


static func preset_pulley(preset: int) -> int:
	return preset / 65536


static func preset_offset(preset: int) -> int:
	return posmod(preset, 65536) - 32768


## Board links onto mover node `to` (part `part`) at phase `phase` (and pulley preset `preset`) from every static
## node near the part. `seeds` (a pulley state between the grid states): only the source nodes it names, with their
## scripts. Returns {source node id: script id} of the links added.
func _board_links(to: int, part: int, mover: int, phase: int, preset: int, seeds: Dictionary = {}) -> Dictionary:
	var added: Dictionary = {}
	var graph: NavGraph = baker.graph
	var sim: NavSim = baker.sim
	var home: Vector2i = sim.part_homes[part]
	var states: Array[PackedInt32Array] = phase_states(phase, preset)
	var state: PackedInt32Array = states[part] if part < states.size() else PackedInt32Array()
	if state.size() < 4:
		return added
	var at: Vector2i = home + Vector2i(state[0], state[1])
	var top_x0: int = at.x
	var top_x1: int = at.x + graph.nodes[to].x1 - graph.nodes[to].x0 + 8
	var seeded: bool = preset != PULLEY_NONE and not seeds.is_empty()
	if preset != PULLEY_NONE and seeds.is_empty() and _is_seeded_state(preset):
		return added
	for from: int in graph.nodes.size():
		var node: NavGraph.NavNode = graph.nodes[from]
		# Out of reach: a jump lifts the feet BOARD_RISE_PX at most; nothing farther than BOARD_REACH_X aside.
		if node.mover >= 0 or node.y - at.y > BOARD_RISE_PX or at.y - node.y > BOARD_REACH_Y:
			continue
		if node.x1 < top_x0 - BOARD_REACH_X or node.x0 > top_x1 + BOARD_REACH_X:
			continue
		if seeded and not seeds.has(from):
			continue
		var xs: PackedInt32Array = PackedInt32Array()
		var x: int = node.x0
		while x <= node.x1:
			if x >= top_x0 - BOARD_REACH_X and x <= top_x1 + BOARD_REACH_X:
				xs.append(x)
			x += NavBaker.SAMPLE_STEP
		if xs.is_empty():
			continue
		var best: Dictionary = _board_search(from, to, xs, seeds[from] if seeded else baker.ground_scripts(), top_x0,
				top_x1, phase, preset, node)
		if not best.is_empty():
			_add(from, to, best, PackedInt32Array([mover, state[0], state[1], state[2], state[3]]), phase, 0)
			added[from] = int(best["script"])
	return added


## True when a pulley state lies between the COARSE_PX grid states (searched only from seeds).
func _is_seeded_state(preset: int) -> bool:
	var p: int = preset_offset(preset)
	var pulley: int = preset_pulley(preset)
	var limit: int = baker.sim.pulley_limits[pulley] if pulley < baker.sim.pulley_limits.size() else 0
	return not is_grid_offset(p, limit)


## The best boarding window from node `from` onto `to` with the scripts `scripts` (in that order) at take-off points
## `xs`: the fastest of at least MIN_WINDOW px; the search ends at a window of BOARD_GOOD_WINDOW px. {} when none.
func _board_search(from: int, to: int, xs: PackedInt32Array, scripts: PackedInt32Array, top_x0: int, top_x1: int,
		phase: int, preset: int, node: NavGraph.NavNode) -> Dictionary:
	var best: Dictionary = {}
	for s: int in scripts:
		# Only the moves toward the part (or straight up under it).
		var d: int = baker.script_dir(s)
		for seed_x: int in xs:
			var toward: int = 0 if seed_x >= top_x0 and seed_x <= top_x1 else (1 if seed_x < top_x0 else -1)
			if d != 0 and toward != 0 and d != toward:
				continue
			if _land(from, s, seed_x, phase, 0, node.y, preset) != to:
				continue
			var window: Dictionary = _widen(from, to, s, seed_x, phase, 0, node.y, Vector2i(node.x0, node.x1), preset)
			var width: int = int(window["x1"]) - int(window["x0"]) + 1
			if width >= NavBaker.MIN_WINDOW and (best.is_empty() or int(window["ticks"]) < int(best["ticks"])):
				best = window
			break
		if not best.is_empty() and int(best["x1"]) - int(best["x0"]) + 1 >= BOARD_GOOD_WINDOW:
			break
	return best


## Off links from mover node `from` (part `part`) at phase `phase` after standing `stand` ticks on it (and pulley
## preset `preset`, the pulley held still). `seeds` (a pulley state between the grid states): their scripts only -
## all scripts when those find no way off at all. Returns {target node id: script id} of the links added.
func _off_links(from: int, part: int, mover: int, phase: int, stand: int, preset: int,
		seeds: Dictionary = {}) -> Dictionary:
	var graph: NavGraph = baker.graph
	var node: NavGraph.NavNode = graph.nodes[from]
	var added: Dictionary = {}
	if preset != PULLEY_NONE and seeds.is_empty() and _is_seeded_state(preset):
		return added
	# Where the part is at the take-off (after the preroll and the standing): one probe from its middle.
	var probe: NavSim.Outcome = _probe(part, phase, stand, node, preset)
	if probe == null or probe.mover_states.size() <= part:
		return added
	var state: PackedInt32Array = probe.mover_states[part]
	# Take-offs from the middle of the part only: a rider waits there for the take-off state (near an end of a
	# platform that brakes or turns, the ride rule can let him slip off; PHYSICS.md 11.4).
	var middle: Vector2i = Vector2i(maxi(node.x0, node.center_x() - OFF_MIDDLE_PX),
			mini(node.x1, node.center_x() + OFF_MIDDLE_PX))
	var x: int = middle.x
	var xs: PackedInt32Array = PackedInt32Array()
	while x < middle.y:
		xs.append(x)
		x += PART_SAMPLE_STEP
	xs.append(middle.y)
	var by_target: Dictionary = {}
	if preset != PULLEY_NONE and not seeds.is_empty():
		var hinted: PackedInt32Array = PackedInt32Array()
		for target: Variant in seeds:
			for s: int in seeds[target]:
				if not hinted.has(s):
					hinted.append(s)
		_off_search(from, xs, hinted, middle, phase, stand, preset, state, by_target)
		if by_target.is_empty():
			_off_search(from, xs, baker.ground_scripts(), middle, phase, stand, preset, state, by_target)
	else:
		_off_search(from, xs, baker.ground_scripts(), middle, phase, stand, preset, state, by_target)
	var targets: Array = by_target.keys()
	targets.sort()
	for to: Variant in targets:
		_add(from, int(to), by_target[to], PackedInt32Array([mover, state[0], state[1], state[2], state[3]]), phase,
				stand)
		added[int(to)] = int((by_target[to] as Dictionary)["script"])
	return added


## The fastest off window per target node (into `by_target`) with scripts `scripts` from the take-off points `xs`.
## In a pulley sweep a take-off that is not faster than the window kept for its target is not widened (its window
## could not replace that one: a window is as slow as its slowest start).
func _off_search(from: int, xs: PackedInt32Array, scripts: PackedInt32Array, middle: Vector2i, phase: int, stand: int,
		preset: int, state: PackedInt32Array, by_target: Dictionary) -> void:
	for s: int in scripts:
		for seed_x: int in xs:
			var to: int = _land(from, s, seed_x, phase, stand, -1, preset)
			if to < 0 or to == from:
				continue
			if preset != PULLEY_NONE and by_target.has(to) and int((_memo["%d:%d:%d:%d:%d:%d" % [from, s, seed_x, phase,
					stand, preset]] as Dictionary)["ticks"]) >= int(by_target[to]["ticks"]):
				continue
			var window: Dictionary = _widen(from, to, s, seed_x, phase, stand, -1, middle, preset)
			var width: int = int(window["x1"]) - int(window["x0"]) + 1
			if width < NavBaker.MIN_WINDOW:
				continue
			# The same take-off state as the probe's (the part may move differently with him elsewhere on it).
			if not _same_state(window, state):
				continue
			if not by_target.has(to) or int(window["ticks"]) < int(by_target[to]["ticks"]):
				by_target[to] = window


func _probe(part: int, phase: int, stand: int, node: NavGraph.NavNode, preset: int) -> NavSim.Outcome:
	var key: String = "%d:%d:%d:%d:%d" % [part, phase, stand, node.id, preset]
	if _probes.has(key):
		return _probes[key]
	var sim: NavSim = baker.sim
	var states: Array[PackedInt32Array] = phase_states(phase, preset)
	if states.size() <= part:
		return null
	var s: PackedInt32Array = states[part]
	var start: Vector2i = Vector2i(node.center_x() + s[0], node.y + s[1] + RIDE_SINK_PX)
	_set_preset(preset, true)
	var outcome: NavSim.Outcome = sim.run(start, PackedInt32Array([0]), 1, -1, phase, stand)
	_set_preset(PULLEY_NONE, false)
	_probes[key] = outcome
	return outcome


## The state of every mover part after the movers ran `phase` ticks alone from the level start (or from pulley preset
## `preset`; cached).
func phase_states(phase: int, preset: int = PULLEY_NONE) -> Array[PackedInt32Array]:
	var key: String = "%d:%d" % [phase, preset]
	if not _phase_states.has(key):
		_set_preset(preset, false)
		_phase_states[key] = baker.sim.run(NavSim.PARK, PackedInt32Array(), 0, -1, phase).mover_states
		_set_preset(PULLEY_NONE, false)
	return _phase_states[key]


## Put pulley preset `preset` on the sim for the next runs (frozen: the pulley held still).
func _set_preset(preset: int, frozen: bool) -> void:
	var sim: NavSim = baker.sim
	if preset == PULLEY_NONE:
		sim.pulley_preset = {}
		sim.pulley_frozen = false
		return
	sim.pulley_preset = {preset_pulley(preset): preset_offset(preset)}
	sim.pulley_frozen = frozen


func _same_state(window: Dictionary, state: PackedInt32Array) -> bool:
	return window.has("state") and window["state"] == state


## Simulate script `s` from x (in the source node's level-start frame) with the movers at `phase` and `stand` ticks
## of standing first (or at pulley preset `preset`); the node he settles on (mover nodes count while he rides their
## part), or -1. Cached.
func _land(from: int, s: int, x: int, phase: int, stand: int, static_y: int, preset: int = PULLEY_NONE) -> int:
	var key: String = "%d:%d:%d:%d:%d:%d" % [from, s, x, phase, stand, preset]
	if _memo.has(key):
		return int((_memo[key] as Dictionary)["to"])
	var result: Dictionary = _simulate(from, baker.script_flags(s), x, phase, stand, static_y, preset)
	_memo[key] = result
	return int(result["to"])


## One run: {"to", "ticks", "land", "state"}. With a pulley preset, a run from a lift (an off link) holds the pulley
## still and counts only when it ends on a static node without riding a lift after the take-off.
func _simulate(from: int, flags: PackedInt32Array, x: int, phase: int, stand: int, static_y: int,
		preset: int = PULLEY_NONE) -> Dictionary:
	var sim: NavSim = baker.sim
	var graph: NavGraph = baker.graph
	var node: NavGraph.NavNode = graph.nodes[from]
	var start: Vector2i = Vector2i(x, static_y if static_y >= 0 else node.y)
	if node.mover >= 0:
		# On a part: his x and y move with the part's place at the preroll's end.
		var part: int = int(_node_part.get(from, -1))
		if part < 0:
			return {"to": -1, "ticks": 0, "land": 0, "state": PackedInt32Array()}
		var s: PackedInt32Array = phase_states(phase, preset)[part]
		start = Vector2i(x + s[0], node.y + s[1] + RIDE_SINK_PX)
	_set_preset(preset, node.mover >= 0)
	var outcome: NavSim.Outcome = sim.run(start, flags, NavBaker.MAX_TICKS, -1, phase, stand)
	_set_preset(PULLEY_NONE, false)
	baker.count_candidate()
	var to: int = -1
	if not outcome.died and (outcome.landed or outcome.walked):
		# Where the bot takes over (the handback) and where he settles must be the same node (NavBaker.settled_node).
		if outcome.platform != null:
			var index: int = sim.part_index(outcome.platform)
			if outcome.handback_platform != null and sim.part_index(outcome.handback_platform) == index:
				for node_id: int in _node_part:
					if int(_node_part[node_id]) == index:
						to = node_id
		elif outcome.handback_platform == null:
			to = graph.node_at(outcome.pos)
			if to >= 0 and (graph.nodes[to].mover >= 0 or graph.node_at(outcome.handback_pos) != to):
				to = -1
	if preset != PULLEY_NONE and node.mover >= 0 and to >= 0 \
			and (graph.nodes[to].mover >= 0 or not outcome.rode_after_air.is_empty()):
		to = -1
	var state: PackedInt32Array = PackedInt32Array()
	if node.mover >= 0:
		state = outcome.mover_states[int(_node_part[from])]
	return {"to": to, "ticks": outcome.landing_tick, "land": outcome.pos.x, "state": state}


func _widen(from: int, to: int, s: int, seed_x: int, phase: int, stand: int, static_y: int, limits: Vector2i,
		preset: int = PULLEY_NONE) -> Dictionary:
	var x0: int = seed_x
	var x1: int = seed_x
	while x1 - x0 + 1 < NavBaker.MAX_WINDOW and x0 - 1 >= limits.x \
			and _land(from, s, x0 - 1, phase, stand, static_y, preset) == to:
		x0 -= 1
	while x1 - x0 + 1 < NavBaker.MAX_WINDOW and x1 + 1 <= limits.y \
			and _land(from, s, x1 + 1, phase, stand, static_y, preset) == to:
		x1 += 1
	var ticks: int = 0
	var land0: int = 1 << 30
	var land1: int = -(1 << 30)
	var state: PackedInt32Array = PackedInt32Array()
	var same: bool = true
	for x: int in range(x0, x1 + 1):
		_land(from, s, x, phase, stand, static_y, preset)
		var result: Dictionary = _memo["%d:%d:%d:%d:%d:%d" % [from, s, x, phase, stand, preset]]
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
## leads there is found again by the same search; a pulley lift's state is preset): {"node", "pos"}. Used by
## NavBaker.verify_graph.
func run_link(link: NavGraph.NavLink, x: int) -> Dictionary:
	var graph: NavGraph = baker.graph
	if _node_part.is_empty():
		_rebuild_parts()
	var recipe: Vector3i = _recipe_for(link)
	if recipe.x < 0:
		return {"node": -1, "pos": Vector2i.ZERO}
	var from: NavGraph.NavNode = graph.nodes[link.from]
	var result: Dictionary = _simulate(link.from, link.flags, x, recipe.x, recipe.y, -1 if from.mover >= 0 else from.y,
			recipe.z)
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


## (phase, stand, pulley preset) that bring the link's mover into its `cond` state; x = -1 when none. A pulley lift's
## state is its pulley's offset, preset directly.
func _recipe_for(link: NavGraph.NavLink) -> Vector3i:
	var graph: NavGraph = baker.graph
	var mover: int = link.cond[0]
	var part: int = -1
	for node_id: int in _node_part:
		if graph.nodes[node_id].mover == mover:
			part = int(_node_part[node_id])
	if part < 0:
		return Vector3i(-1, -1, PULLEY_NONE)
	var want: PackedInt32Array = link.cond.slice(1, 5)
	if graph.is_pulley_lift(mover) and part < baker.sim.part_pulley.size() and baker.sim.part_pulley[part] >= 0:
		var preset: int = encode_preset(baker.sim.part_pulley[part], graph.link_pulley_offset(link))
		var states: Array[PackedInt32Array] = phase_states(0, preset)
		if states.size() > part and states[part] == want:
			return Vector3i(0, 0, preset)
		return Vector3i(-1, -1, PULLEY_NONE)
	var periodic: bool = StringName(str(graph.movers[mover]["kind"])) == NavGraph.MOVER_PERIODIC
	var phases: PackedInt32Array = PackedInt32Array([0])
	if periodic and _periods[part] > 0:
		phases.clear()
		var phase: int = 0
		while phase < _periods[part]:
			phases.append(phase)
			phase += PHASE_STEP
	var stands: Array[int] = [0]
	if not periodic and graph.nodes[link.from].mover >= 0:
		stands = STAND_TICKS
	for phase: int in phases:
		for stand: int in stands:
			var states: Array[PackedInt32Array] = []
			if graph.nodes[link.from].mover >= 0:
				var probe: NavSim.Outcome = _probe(part, phase, stand, graph.nodes[link.from], PULLEY_NONE)
				if probe != null:
					states = probe.mover_states
			else:
				states = phase_states(phase)
			if states.size() > part and states[part] == want:
				return Vector3i(phase, stand, PULLEY_NONE)
	return Vector3i(-1, -1, PULLEY_NONE)
