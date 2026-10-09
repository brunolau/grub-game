extends TestCase
## The phase-4 performance pass of the bots (docs/ARCHITECTURE.md 11.5, PLAN.md 7 P4.2): the fast paths give exactly
## what the plain ones give.
##  - NavGraph: a search that expands a landing once, a reach on the distinct steps of a settled graph and a search on
##    a mask with the open links of every node return the routes, costs and landings of the search that looks at
##    every link of every landing (kept here as the reference, as it was written before the pass);
##  - BotNavigator: the mask it plans with on a graph with pulley lifts names exactly the links of search_blocked(),
##    in every pulley state, with blocked links, and after a link failed;
##  - HeroBot: bots that share one look at the heroes per tick, plan on masks and search fast play the same rounds
##    as bots that do none of it (the soak's own round loop, every hero's score and the tick the round ended on).
## The graph is Tar Pulleys' (2 668 links, 2 581 of them baked once per pulley state): the level the pass was made for.

const ARENA: StringName = &"arena_tar_pulleys"
const SOAK_RUNNER: String = "res://tools/bots/soak_runner.gd"


## NavMoversLive with a plan and states given by the test.
class _FixedPulleys:
	extends NavMoversLive

	var plan: Dictionary = {}
	var states: Dictionary = {}

	func has_pulleys() -> bool:
		return true

	func pulley_plan(_hero: PlayerBase) -> Dictionary:
		return plan

	func pulley_states() -> Dictionary:
		return states


func before_each() -> void:
	NavGraph.clear_cache()
	NavGraph.fast = true
	BotNavigator.use_mask = true
	HeroBot.share_seen = true


func after_each() -> void:
	NavGraph.fast = true
	BotNavigator.use_mask = true
	HeroBot.share_seen = true
	NavGraph.clear_cache()


# The search of NavGraph as it was before the pass: every usable link of every landing.
func _plain_search(graph: NavGraph, from_node: int, from_x: int, to_node: int, to_x: int, blocked: Dictionary,
		weight_class: int) -> Dictionary:
	var none: Dictionary = {"path": PackedInt32Array(), "cost": NavGraph.UNREACHABLE}
	if from_node < 0 or from_node >= graph.nodes.size() or to_node < 0 or to_node >= graph.nodes.size():
		return none
	var best_cost: int = NavGraph.UNREACHABLE
	var best_last: int = -1
	if from_node == to_node:
		best_cost = NavGraph.walk_ticks(to_x - from_x)
	var count: int = graph.links.size()
	var dist: PackedInt32Array = PackedInt32Array()
	dist.resize(count)
	dist.fill(NavGraph.UNREACHABLE)
	var prev: PackedInt32Array = PackedInt32Array()
	prev.resize(count)
	prev.fill(-1)
	var done: PackedByteArray = PackedByteArray()
	done.resize(count)
	done.fill(0)
	var heap: PackedInt64Array = PackedInt64Array()
	for id: int in graph.links_from(from_node, weight_class):
		if blocked.has(id):
			continue
		dist[id] = graph.link_cost_from(graph.links[id], from_x)
		NavGraph.heap_push(heap, dist[id], id)
	while not heap.is_empty():
		var key: int = NavGraph.heap_pop(heap)
		var current: int = key & NavGraph.ID_MASK
		var current_cost: int = key >> NavGraph.ID_BITS
		if done[current] == 1 or current_cost != dist[current]:
			continue
		if current_cost >= best_cost:
			break
		done[current] = 1
		var link: NavGraph.NavLink = graph.links[current]
		var land_x: int = link.land_center()
		if link.to == to_node:
			var total: int = current_cost + NavGraph.walk_ticks(to_x - land_x)
			if total < best_cost:
				best_cost = total
				best_last = current
		for next: int in graph.links_from(link.to, weight_class):
			if done[next] == 1 or blocked.has(next):
				continue
			var cost: int = current_cost + graph.link_cost_from(graph.links[next], land_x)
			if cost < dist[next]:
				dist[next] = cost
				prev[next] = current
				NavGraph.heap_push(heap, cost, next)
	if best_cost >= NavGraph.UNREACHABLE:
		return none
	var path: PackedInt32Array = PackedInt32Array()
	var step: int = best_last
	while step >= 0:
		path.insert(0, step)
		step = prev[step]
	return {"path": path, "cost": best_cost}


# The reach of NavGraph as it was before the pass.
func _plain_reach(graph: NavGraph, from_node: int, from_x: int, blocked: Dictionary, weight_class: int) -> Dictionary:
	var cost: PackedInt32Array = PackedInt32Array()
	cost.resize(graph.nodes.size())
	cost.fill(NavGraph.UNREACHABLE)
	var at: PackedInt32Array = PackedInt32Array()
	at.resize(graph.nodes.size())
	at.fill(0)
	var result: Dictionary = {"cost": cost, "x": at}
	if from_node < 0 or from_node >= graph.nodes.size():
		return result
	cost[from_node] = 0
	at[from_node] = from_x
	var count: int = graph.links.size()
	var dist: PackedInt32Array = PackedInt32Array()
	dist.resize(count)
	dist.fill(NavGraph.UNREACHABLE)
	var done: PackedByteArray = PackedByteArray()
	done.resize(count)
	done.fill(0)
	var heap: PackedInt64Array = PackedInt64Array()
	for id: int in graph.links_from(from_node, weight_class):
		if not blocked.has(id):
			dist[id] = graph.link_cost_from(graph.links[id], from_x)
			NavGraph.heap_push(heap, dist[id], id)
	while not heap.is_empty():
		var key: int = NavGraph.heap_pop(heap)
		var current: int = key & NavGraph.ID_MASK
		var current_cost: int = key >> NavGraph.ID_BITS
		if done[current] == 1 or current_cost != dist[current]:
			continue
		done[current] = 1
		var link: NavGraph.NavLink = graph.links[current]
		var land_x: int = link.land_center()
		if current_cost < cost[link.to]:
			cost[link.to] = current_cost
			at[link.to] = land_x
		for next: int in graph.links_from(link.to, weight_class):
			if done[next] == 1 or blocked.has(next):
				continue
			var next_cost: int = current_cost + graph.link_cost_from(graph.links[next], land_x)
			if next_cost < dist[next]:
				dist[next] = next_cost
				NavGraph.heap_push(heap, next_cost, next)
	return result


# A feet x on node `id` of `graph` drawn from `rng`.
func _x_on(graph: NavGraph, id: int, rng: SimRng) -> int:
	return rng.range_int(graph.nodes[id].x0, graph.nodes[id].x1)


# The pulley offsets the pulley links of `graph` were baked at, in ascending order.
func _offsets(graph: NavGraph) -> PackedInt32Array:
	var found: Dictionary = {}
	for link: NavGraph.NavLink in graph.links:
		if link.cond.size() >= 5 and graph.is_pulley_lift(link.cond[0]):
			found[graph.link_pulley_offset(link)] = true
	var offsets: PackedInt32Array = PackedInt32Array(found.keys())
	offsets.sort()
	return offsets


func test_fast_searches_find_what_the_plain_search_finds() -> void:
	# The graph as the game loads it (settled: the repeats of a step are left out of a reach that blocks nothing) and
	# a copy that is not; both search with the landing skip (2 668 links). Blocked links in a third of the trials.
	var settled: NavGraph = NavGraph.load_for_level(ARENA)
	assert_not_null(settled, "Tar Pulleys has its baked graph")
	if settled == null:
		return
	assert_true(settled.links.size() >= NavGraph.LANDING_MIN_LINKS, "the landing skip is on for it (%d links)" %
			settled.links.size())
	var copy: NavGraph = NavGraph.from_dict(settled.to_dict())
	var rng: SimRng = SimRng.new(20261009)
	var reached: int = 0
	var routes: int = 0
	for trial: int in 90:
		var from: int = rng.range_int(0, settled.nodes.size() - 1)
		var to: int = rng.range_int(0, settled.nodes.size() - 1)
		var from_x: int = _x_on(settled, from, rng)
		var to_x: int = _x_on(settled, to, rng)
		var weight_class: int = trial % NavGraph.WEIGHT_CLASSES
		var blocked: Dictionary = {}
		if trial % 3 == 1:
			for k: int in rng.range_int(1, 40):
				blocked[rng.range_int(0, settled.links.size() - 1)] = true
		var plain: Dictionary = _plain_search(settled, from, from_x, to, to_x, blocked, weight_class)
		var plain_reach: Dictionary = _plain_reach(settled, from, from_x, blocked, weight_class)
		for graph: NavGraph in [settled, copy]:
			var what: String = "trial %d (%d,%d -> %d,%d, class %d, %d blocked, %s)" % [trial, from, from_x, to, to_x,
					weight_class, blocked.size(), "settled" if graph == settled else "a copy"]
			assert_eq(graph.find_path(from, from_x, to, to_x, blocked, weight_class), plain["path"], what)
			assert_eq(graph.path_cost(from, from_x, to, to_x, blocked, weight_class), int(plain["cost"]), what)
			var reach: Dictionary = graph.reach_from(from, from_x, blocked, weight_class)
			assert_eq(reach["cost"], plain_reach["cost"], what)
			assert_eq(reach["x"], plain_reach["x"], what)
		routes += 1 if int(plain["cost"]) < NavGraph.UNREACHABLE else 0
		for node_cost: int in plain_reach["cost"]:
			reached += 1 if node_cost < NavGraph.UNREACHABLE else 0
	assert_true(routes >= 60 and reached >= 400, "the trials are real searches (%d routes, %d nodes reached)" %
			[routes, reached])
	# The switch gives the plain search itself.
	NavGraph.fast = false
	var off: Dictionary = settled.reach_from(0, settled.nodes[0].x0 + 5, {}, NavGraph.WEIGHT_LIGHT)
	NavGraph.fast = true
	var on: Dictionary = settled.reach_from(0, settled.nodes[0].x0 + 5, {}, NavGraph.WEIGHT_LIGHT)
	assert_eq(on["cost"], off["cost"])
	assert_eq(on["x"], off["x"])


func test_a_settled_graph_leaves_out_only_the_repeats_of_a_step() -> void:
	var graph: NavGraph = NavGraph.load_for_level(ARENA)
	assert_not_null(graph)
	if graph == null:
		return
	assert_true(graph._settled, "a graph read from its file is settled")
	var fewer: int = 0
	for weight_class: int in NavGraph.WEIGHT_CLASSES:
		for node: NavGraph.NavNode in graph.nodes:
			var all: PackedInt32Array = graph.links_from(node.id, weight_class)
			var kept: PackedInt32Array = graph._distinct_links(node.id, weight_class)
			fewer += all.size() - kept.size()
			# Every link left out repeats a kept link with a lower id: window, cost, target node and landing.
			var steps: Dictionary = {}
			for id: int in kept:
				var link: NavGraph.NavLink = graph.links[id]
				steps[[link.x0, link.x1, graph.link_cost_from(link, link.x0), link.to, link.land_center()]] = id
			assert_eq(steps.size(), kept.size(), "no kept link repeats another (node %d class %d)" % [node.id,
					weight_class])
			var at: int = 0
			for id: int in all:
				if at < kept.size() and kept[at] == id:
					at += 1
					continue
				var link: NavGraph.NavLink = graph.links[id]
				var step: Array = [link.x0, link.x1, graph.link_cost_from(link, link.x0), link.to, link.land_center()]
				assert_true(steps.has(step) and int(steps[step]) < id, "link %d repeats an earlier kept one" % id)
			assert_eq(at, kept.size(), "the kept links are in the order of links_from")
	assert_true(fewer >= 500, "%d repeats are left out of Tar Pulleys' lists" % fewer)
	# Editing a graph ends it: the lists are made again from what is there.
	var copy: NavGraph = NavGraph.from_dict(graph.to_dict())
	assert_false(copy._settled, "a graph made from a dictionary is not settled")
	var extra: NavGraph.NavLink = NavGraph.NavLink.new()
	extra.from = 0
	extra.to = 1
	extra.keys = "4:R"
	extra.ticks = 4
	graph.add_link(extra)
	assert_false(graph._settled, "a link was added: no longer settled")
	assert_true(graph._distinct.is_empty())
	NavGraph.clear_cache()


func test_the_mask_names_the_links_the_navigator_leaves_out() -> void:
	var graph: NavGraph = NavGraph.load_for_level(ARENA)
	assert_not_null(graph)
	if graph == null:
		return
	var offsets: PackedInt32Array = _offsets(graph)
	assert_true(offsets.size() >= 3, "the lifts were baked at several pulley offsets (%s)" % [offsets])
	var lifts: PackedInt32Array = PackedInt32Array()
	for index: int in graph.movers.size():
		if graph.is_pulley_lift(index):
			lifts.append(index)
	assert_eq(lifts.size(), 2, "two pulley lifts")
	var nav: BotNavigator = BotNavigator.new(graph)
	var live: _FixedPulleys = _FixedPulleys.new()
	var rng: SimRng = SimRng.new(4711)
	var open_sizes: Dictionary = {}
	for trial: int in 40:
		# A plan as NavMoversLive makes it (an offset to board at, one to leave at, per lift), also with offsets no
		# link was baked at; the pulley's state for the links past a lift's column; some blocked links.
		var plan: Dictionary = {}
		for lift: int in lifts:
			var board: int = offsets[rng.range_int(0, offsets.size() - 1)] + (1 if trial % 7 == 3 else 0)
			var leave: int = offsets[rng.range_int(0, offsets.size() - 1)]
			plan[lift] = Vector2i(board, leave)
		if trial % 9 == 5:
			plan.erase(lifts[1])  # a plan that does not know every lift
		live.plan = plan
		var now: int = offsets[rng.range_int(0, offsets.size() - 1)]
		live.states = {int(graph.movers[lifts[0]]["pulley"]): Vector2i(now, offsets[rng.range_int(0, offsets.size() - 1)])}
		nav.set_weight_class(trial % NavGraph.WEIGHT_CLASSES)
		if trial % 4 == 2:
			nav.blocked[rng.range_int(0, graph.links.size() - 1)] = true
		nav.update_movers(null, live)
		assert_true(nav._masked(), "trial %d: the navigator plans on its mask" % trial)
		var avoid: Dictionary = nav.search_blocked()
		var wrong: int = 0
		var left_out: int = 0
		for id: int in graph.links.size():
			left_out += nav._mask[id]
			if (nav._mask[id] == 1) != avoid.has(id):
				wrong += 1
		assert_eq(wrong, 0, "trial %d: the mask and the set agree on every link (plan %s)" % [trial, plan])
		assert_eq(left_out, avoid.size(), "trial %d" % trial)
		open_sizes[graph.links.size() - left_out] = true
		# The searches on the mask are the searches with the set.
		var from: int = rng.range_int(0, graph.nodes.size() - 1)
		var to: int = rng.range_int(0, graph.nodes.size() - 1)
		var from_x: int = _x_on(graph, from, rng)
		var to_x: int = _x_on(graph, to, rng)
		var search: int = nav.search_class()
		var plain: Dictionary = _plain_search(graph, from, from_x, to, to_x, avoid, search)
		assert_eq(graph.find_path(from, from_x, to, to_x, nav.blocked, search, nav._mask, nav._open), plain["path"],
				"trial %d: the route" % trial)
		assert_eq(graph.path_cost(from, from_x, to, to_x, nav.blocked, search, nav._mask, nav._open),
				int(plain["cost"]), "trial %d: its cost" % trial)
		var plain_reach: Dictionary = _plain_reach(graph, from, from_x, avoid, search)
		var reach: Dictionary = graph.reach_from(from, from_x, nav.blocked, search, nav._mask, nav._open)
		assert_eq(reach["cost"], plain_reach["cost"], "trial %d: the reach" % trial)
		assert_eq(reach["x"], plain_reach["x"], "trial %d: where it lands" % trial)
	assert_true(open_sizes.size() >= 5, "the plans opened different sets of links (%s open)" % [open_sizes.keys()])
	# A link that fails twice is blocked at once, in the mask and in the set, before the next update.
	var live_plan: Dictionary = {lifts[0]: Vector2i(offsets[0], offsets[0]), lifts[1]: Vector2i(offsets[0], offsets[0])}
	live.plan = live_plan
	nav.update_movers(null, live)
	var open_link: int = -1
	for id: int in graph.links.size():
		if nav._mask[id] == 0:
			open_link = id
			break
	assert_true(open_link >= 0)
	for miss: int in BotNavigator.LINK_FAILURES_TO_BLOCK:
		nav._fail(graph.links[open_link], null, "test")
	assert_eq(nav._mask[open_link], 1, "blocked in the mask")
	assert_true(nav.search_blocked().has(open_link) and nav.blocked.has(open_link), "and in the set")
	# No pulleys: no mask, the blocked links alone.
	nav.update_movers(null, NavMoversLive.new())
	assert_false(nav._masked())
	assert_true(nav.search_blocked() == nav.blocked)
	# The switch: the set is read again, the same set.
	nav.update_movers(null, live)
	BotNavigator.use_mask = false
	assert_false(nav._masked())
	assert_true(nav.search_blocked().has(open_link))
	BotNavigator.use_mask = true


func test_bots_on_the_fast_paths_play_the_rounds_of_plain_bots() -> void:
	# Two seeded rounds through the soak's own loop (the real heroes, the real referee, a CPU on every seat): Hot Rock on
	# Tar Pulleys - lifts that move, masks, runners that plan against a chaser on every link - and Last Caveman
	# Standing on Cinder Pit. Once with the pass switched off, once with it on.
	var runner: Node = (load(SOAK_RUNNER) as GDScript).new() as Node
	add_node(runner)
	var specs: Array[Dictionary] = [
		{"mode": Defs.VersusMode.HOT_ROCK, "arena": ARENA, "players": 4, "seed": 9104, "round": 1},
		{"mode": Defs.VersusMode.LAST_CAVEMAN, "arena": &"arena_cinder_pit", "players": 3, "seed": 9105, "round": 2},
	]
	for spec: Dictionary in specs:
		var results: Array[Dictionary] = []
		for pass_on: bool in [false, true]:
			NavGraph.clear_cache()
			NavGraph.fast = pass_on
			BotNavigator.use_mask = pass_on
			HeroBot.share_seen = pass_on
			runner.call(&"_begin")
			var result: Dictionary = runner.call(&"play", spec)
			await get_tree().process_frame
			runner.call(&"_end")
			assert_eq((result["anomalies"] as PackedStringArray).size(), 0, "%s: %s" % [result.get("tag", ""),
					" || ".join(result["anomalies"] as PackedStringArray)])
			results.append(result)
		var plain: Dictionary = results[0]
		var fast: Dictionary = results[1]
		var tag: String = str(plain.get("tag", ""))
		assert_true(bool(plain["ended"]) and int(plain["round_ticks"]) > 100, "%s was played (%d ticks)" % [tag,
				int(plain["round_ticks"])])
		for field: String in ["ticks", "round_ticks", "ended", "end", "winners", "scores", "worst_idle", "golden_ticks"]:
			assert_eq(fast[field], plain[field], "%s: %s" % [tag, field])
