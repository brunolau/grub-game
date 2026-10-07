extends TestCase
## The bots' navigation (PLAN.md P1.2, DESIGN.md E.7): the nav-graph format, path search, the baker (nodes from the
## grid, links found and verified by simulating the real hero), its re-verification, and a HeroBot walking an arena
## through GameInput's BOT slot.

const LEVEL_SCENE: String = "res://scenes/world/level.tscn"
const FLAT_ARENA: String = "res://levels/test_world_arena_flat.lvl"
const RING_ARENA: String = "res://levels/test_world_arena_ring.lvl"
## A walled 20 x 12 arena with a one-way bridge 4 rows over the floor on the left and a solid ledge 3 rows up on the
## right (4 cells wide, wall-backed): the bake must find jumps up and drops down in both directions. (A jump whose feet
## get into a one-way floor's own row lands on its top - the 1.0 rule - so the light hero reaches the 4-row bridge
## with his 60 px rise and a 20+ stack's 38 px rise does not.)
const TIER_ARENA: String = """[meta]
format = 2
id = test_core_bots_tiers
kind = arena
players = 2
modes = grub_stack
biome = jungle
[legend]
[tiles]
|..................|
|..................|
|..................|
|..................|
|..................|
|..................|
|...-----..........|
|..............####|
|..................|
|.@................|
####################
####################
[entities]
"""

## A walled arena whose high ledge (6 rows up: out of every jump) only a geyser reaches: the geyser link.
const GEYSER_ARENA: String = """[meta]
format = 2
id = test_core_bots_geyser
kind = arena
players = 2
modes = last_caveman
biome = jungle
[legend]
G = objects/geyser period=88
[tiles]
|..................|
|..................|
|..................|
|..................|
|......------......|
|..................|
|..................|
|..................|
|..................|
|.@...G............|
####################
####################
[entities]
"""

## A walled arena whose two ledges (5 rows over the floor: out of every jump) only a moving platform joins: it
## starts at the left ledge's edge and travels right (objects/platform dir=2, ping-pong) close to the right ledge. The
## bot starts on the left ledge (spawn 2, slot 1); slot 0 waits on the floor.
const LIFT_ARENA: String = """[meta]
format = 2
id = test_core_bots_lift
kind = arena
players = 2
modes = last_caveman
biome = jungle
[legend]
M = objects/platform dir=2 speed=4 travel=18
B = objects/spawn_point index=2
[tiles]
|..................|
|..................|
|..................|
|..................|
|.B................|
|####M.......######|
|..................|
|..................|
|..................|
|.@................|
####################
####################
[entities]
"""

## The tier arena's graph as JSON text, baked once for the whole file (a bake simulates thousands of hero runs; text,
## not the graph itself, so that nothing is left over at exit).
static var _tier_json: String = ""
static var _geyser_json: String = ""
static var _lift_json: String = ""


func before_each() -> void:
	Game.new_game(Defs.Difficulty.BEGINNER)
	NavGraph.clear_cache()


func after_each() -> void:
	GameInput.clear_scripted()
	GameInput.reset_slots()
	NavGraph.clear_cache()
	BotBrain.clear_cache()
	Sim.stop()
	Game.new_game(Defs.Difficulty.BEGINNER)


## The tier arena's graph, baked once for the whole file (a bake simulates thousands of hero runs).
func _tier() -> NavGraph:
	if _tier_json.is_empty():
		var baked: NavGraph = NavBaker.new().bake_text(self, &"test_core_bots_tiers", TIER_ARENA,
				Defs.Difficulty.BEGINNER, PackedInt32Array([NavGraph.WEIGHT_LIGHT, NavGraph.WEIGHT_HEAVIER]))
		_tier_json = baked.to_json()
	var json: JSON = JSON.new()
	json.parse(_tier_json)
	return NavGraph.from_dict(json.data)


# =================================================================================================================
# Format
# =================================================================================================================

func test_keys_expand_and_compress_round_trip() -> void:
	var flags: PackedInt32Array = NavGraph.expand_keys("3:R,2:RU,1:,2:L")
	assert_ints_eq(flags, [Defs.IN_RIGHT, Defs.IN_RIGHT, Defs.IN_RIGHT, Defs.IN_RIGHT | Defs.IN_UP,
			Defs.IN_RIGHT | Defs.IN_UP, 0, Defs.IN_LEFT, Defs.IN_LEFT])
	assert_eq(NavGraph.compress_flags(flags), "3:R,2:RU,1:,2:L")
	assert_eq(NavGraph.keys_to_flags("LRUDFKS"), GameInput.keys_to_flags("LRUDFKS"), "the same keys as the routes")
	assert_eq(NavGraph.flags_to_keys(Defs.IN_DOWN | Defs.IN_FIRE), "DF")
	assert_eq(NavGraph.expand_keys("").size(), 0)


func test_graph_json_round_trip() -> void:
	var graph: NavGraph = _small_graph()
	var text: String = graph.to_json()
	var json: JSON = JSON.new()
	assert_eq(json.parse(text), OK, "the file is JSON")
	var back: NavGraph = NavGraph.from_dict(json.data)
	assert_not_null(back)
	assert_eq(back.to_json(), text, "save -> load -> save is stable")
	assert_eq(back.nodes.size(), 2)
	assert_eq(back.links.size(), 2)
	assert_eq(back.links[1].kind, NavGraph.KIND_DROP)
	assert_ints_eq(back.links[0].flags, NavGraph.expand_keys("3:RU,8:R"))
	assert_eq(back.links_from(0), PackedInt32Array([0]))
	assert_null(NavGraph.from_dict({"format": 99}), "an unknown format is refused")


func test_graph_files_load_and_cache() -> void:
	var graph: NavGraph = _small_graph()
	var path: String = "user://bots_test/%s.json" % graph.level_id
	assert_eq(graph.save(path), OK)
	var loaded: NavGraph = NavGraph.load_file(path)
	assert_not_null(loaded)
	assert_eq(loaded.to_json(), graph.to_json())
	assert_null(NavGraph.load_file("user://bots_test/none.json"), "no file, no graph, no error")
	assert_null(NavGraph.load_for_level(&"no_such_level"))
	NavGraph.cache(graph)
	assert_true(NavGraph.load_for_level(graph.level_id) == graph, "a cached graph is returned as it is")
	DirAccess.remove_absolute(path)


func test_node_queries() -> void:
	var graph: NavGraph = _small_graph()
	assert_eq(graph.node_at(Vector2i(50, 160)), 0)
	assert_eq(graph.node_at(Vector2i(50, 165)), 0, "the feet row is what counts")
	assert_eq(graph.node_at(Vector2i(50, 112)), 1)
	assert_eq(graph.node_at(Vector2i(300, 112)), -1, "beside the ledge")
	assert_eq(graph.node_at(Vector2i(50, 140)), -1, "in the air")
	assert_eq(graph.node_below(Vector2i(70, 100)), 1, "the ledge is the first floor under him")
	assert_eq(graph.node_below(Vector2i(250, 100)), 0)
	assert_eq(graph.nearest_node(Vector2i(250, 150)), 0)


func test_path_search_takes_the_cheapest_route() -> void:
	var graph: NavGraph = _small_graph()
	var path: PackedInt32Array = graph.find_path(0, 20, 1, 80)
	assert_eq(path, PackedInt32Array([0]), "floor -> ledge by the jump")
	assert_eq(graph.find_path(1, 80, 0, 200), PackedInt32Array([1]))
	assert_eq(graph.find_path(0, 20, 0, 200).size(), 0, "same node: no link")
	assert_eq(graph.path_cost(0, 20, 0, 200), NavGraph.walk_ticks(180))
	var cost: int = graph.path_cost(0, 20, 1, 80)
	assert_eq(cost, NavGraph.walk_ticks(30 - 20) + NavGraph.SETTLE_TICKS + 11 + NavGraph.walk_ticks(80 - 60))
	assert_eq(graph.path_cost(0, 20, 1, 80, {0: true}), NavGraph.UNREACHABLE, "a blocked link is not used")
	var reach: Dictionary = graph.reach_from(0, 20)
	assert_eq(graph.reach_cost(reach, Vector2i(80, 112)), cost, "one search answers the same")
	assert_eq(graph.reach_cost(reach, Vector2i(200, 160)), NavGraph.walk_ticks(180))


func test_walk_to_brakes_onto_the_target() -> void:
	assert_eq(BotNavigator.stop_distance(0, 0), 0)
	# From full speed (80) the friction 12 leaves 68, 56, 44, 32, 20, 8, 0: 4 + 3 + 2 + 2 + 1 + 0 px.
	assert_eq(BotNavigator.stop_distance(80, 0), 12)
	assert_eq(BotNavigator.stop_distance(-80, 0), -17, "floor16 rounds leftward slides down: 5 + 4 + 3 + 2 + 2 + 1")
	assert_eq(BotNavigator.stop_distance(80, 3), 160, "ice 3 brakes 1 v16 per tick: a long slide")
	var hero: PlayerBase = PlayerBase.new()
	hero.sim_pos = Vector2i(100, 160)
	assert_eq(BotNavigator.walk_to(hero, 140, 2), Defs.IN_RIGHT)
	assert_eq(BotNavigator.walk_to(hero, 60, 2), Defs.IN_LEFT)
	assert_eq(BotNavigator.walk_to(hero, 101, 2), 0, "close enough")
	hero.xvel = 80
	assert_eq(BotNavigator.walk_to(hero, 110, 2), 0, "brakes: the slide reaches the target")
	assert_eq(BotNavigator.walk_to(hero, 150, 2), Defs.IN_RIGHT)
	hero.free()


# =================================================================================================================
# Baker
# =================================================================================================================

func test_span_nodes_follow_the_grid() -> void:
	var data: LevelData = LevelData.parse(&"test_core_bots_tiers", TIER_ARENA)
	var nodes: Array[NavGraph.NavNode] = NavBaker.span_nodes(data.build_grid(0))
	assert_eq(nodes.size(), 3, "bridge, ledge, floor")
	assert_eq(nodes[0].to_dict(), {"id": 0, "row": 6, "y": 96, "x0": 64, "x1": 143, "ice": 0}, "the bridge")
	# The ledge runs into the invisible wall of column 19: the wall probe stops a walker 9 px before it.
	assert_eq(nodes[1].to_dict(), {"id": 0, "row": 7, "y": 112, "x0": 240, "x1": 294, "ice": 0}, "the ledge")
	assert_eq(nodes[2].to_dict(), {"id": 0, "row": 10, "y": 160, "x0": 25, "x1": 294, "ice": 0}, "the floor")
	var grid: TileGrid = TileGrid.from_rows(PackedStringArray(["....", "#~^#", "####"]))
	assert_false(NavBaker.is_standable(grid, 1, 1), "liquid is no floor")
	assert_false(NavBaker.is_standable(grid, 2, 1), "spikes are no floor")
	assert_false(NavBaker.is_standable(grid, 0, 2), "a floor under a floor is inside the ground")
	assert_true(NavBaker.is_standable(grid, 0, 1))


func test_bake_finds_jumps_and_drops_both_ways() -> void:
	var graph: NavGraph = _tier()
	assert_not_null(graph)
	assert_eq(graph.nodes.size(), 3)
	var floor_node: int = graph.node_at(Vector2i(100, 160))
	var bridge: int = graph.node_at(Vector2i(100, 96))
	var ledge: int = graph.node_at(Vector2i(260, 112))
	for pair: Vector2i in [Vector2i(floor_node, bridge), Vector2i(bridge, floor_node), Vector2i(floor_node, ledge),
			Vector2i(ledge, floor_node), Vector2i(bridge, ledge), Vector2i(ledge, bridge)]:
		var found: bool = false
		for id: int in graph.links_from(pair.x):
			if graph.links[id].to == pair.y:
				found = true
		assert_true(found, "a link %d -> %d" % [pair.x, pair.y])
	for link: NavGraph.NavLink in graph.links:
		assert_true(link.x1 - link.x0 + 1 >= NavBaker.MIN_WINDOW, "link %d has a usable window" % link.id)
		assert_true(link.flags.size() > 0 and link.flags.size() <= link.ticks,
				"link %d: its script ends by the landing (a short one is followed by nothing)" % link.id)
		assert_true(NavGraph.KINDS.has(link.kind))
	assert_true(int(graph.baker["verified_starts"]) > 0)
	assert_eq(graph.source_sha256, NavGraph.text_sha256(TIER_ARENA))


func test_every_baked_link_lands_from_every_x_of_its_window() -> void:
	var graph: NavGraph = _tier()
	var baker: NavBaker = NavBaker.new()
	var data: LevelData = LevelData.parse(graph.level_id, TIER_ARENA)
	assert_true(baker.sim.setup(self, graph.level_id, data.build_grid(0), data.resolved_meta(0), data.entity_records()))
	var problems: PackedStringArray = baker.verify_graph(graph)
	assert_eq(problems.size(), 0, "\n".join(problems))
	# A link that is wrong is caught: point the floor -> bridge jump at the ledge.
	var broken: NavGraph = NavGraph.from_dict(graph.to_dict())
	var bridge: int = graph.node_at(Vector2i(100, 96))
	var ledge: int = graph.node_at(Vector2i(260, 112))
	for link: NavGraph.NavLink in broken.links:
		if link.to == bridge:
			link.to = ledge
	assert_true(baker.verify_graph(broken).size() > 0, "the verifier refuses a link that lands elsewhere")
	baker.sim.teardown()
	assert_null(Game.level, "the sim gave the level back")


func test_bake_is_deterministic() -> void:
	var graph: NavGraph = _tier()
	var again: NavGraph = NavBaker.new().bake_text(self, &"test_core_bots_tiers", TIER_ARENA,
			Defs.Difficulty.BEGINNER, PackedInt32Array([NavGraph.WEIGHT_LIGHT, NavGraph.WEIGHT_HEAVIER]))
	assert_eq(again.to_json(), graph.to_json())


func test_sim_restores_the_game_state() -> void:
	Game.mode = Defs.GameMode.VERSUS
	Game.party = 3
	var manual: bool = Sim.manual
	var sim: NavSim = NavSim.new()
	var data: LevelData = LevelData.parse(&"t", TIER_ARENA)
	assert_true(sim.setup(self, &"t", data.build_grid(0), data.resolved_meta(0), data.entity_records()))
	assert_eq(Game.mode, Defs.GameMode.SINGLE, "the sim hero is a 1.0 hero")
	var outcome: NavSim.Outcome = sim.run(Vector2i(200, 160), NavGraph.expand_keys("14:U"), 60)
	assert_true(outcome.landed)
	assert_eq(outcome.pos, Vector2i(200, 160), "a straight jump lands where it started")
	assert_eq(outcome.landing_tick, int(load_reference()["variable_jump"]["up_held_14_ticks"]["landing_tick"]),
			"the landing tick of the reference jump")
	sim.teardown()
	assert_eq(Game.mode, Defs.GameMode.VERSUS)
	assert_eq(Game.party, 3)
	assert_eq(Sim.manual, manual)
	assert_false(GameInput.is_slot_scripted(0))
	Game.mode = Defs.GameMode.SINGLE
	Game.party = 1


func test_format_1_graphs_still_load() -> void:
	var data: Dictionary = _small_graph().to_dict()
	data["format"] = 1
	data.erase("weights")
	data.erase("movers")
	data.erase("clip")
	for link: Dictionary in data["links"]:
		link.erase("weight")
	var graph: NavGraph = NavGraph.from_dict(data)
	assert_not_null(graph)
	assert_eq(graph.format, 1)
	assert_eq(graph.weights, PackedInt32Array([NavGraph.WEIGHT_LIGHT]))
	assert_eq(graph.links_from(0, NavGraph.WEIGHT_HEAVIER), PackedInt32Array([0]),
			"an unbaked class falls back to the light links")
	assert_eq(graph.usable_class(NavGraph.WEIGHT_HOLDER), NavGraph.WEIGHT_LIGHT)


func test_format_2_round_trips_weights_cycles_and_movers() -> void:
	var graph: NavGraph = _small_graph()
	graph.weights = PackedInt32Array([0, 1, 2])
	var key: String = NavGraph.mover_key(&"objects/platform", 3, 6)
	var mover: int = graph.add_mover(key, "objects/platform", 3, 6, NavGraph.MOVER_PERIODIC)
	assert_eq(graph.add_mover(key, "objects/platform", 3, 6, NavGraph.MOVER_PERIODIC), mover, "one mover per key")
	var heavy: NavGraph.NavLink = NavGraph.NavLink.new()
	heavy.from = 0
	heavy.to = 1
	heavy.x0 = 30
	heavy.x1 = 36
	heavy.keys = "3:RU,9:R"
	heavy.ticks = 12
	heavy.weight = NavGraph.WEIGHT_HEAVY
	heavy.cycle = PackedInt32Array([88, 0, 76])
	heavy.cond = PackedInt32Array([mover, 0, -16, 0, 2])
	graph.add_link(heavy)
	var json: JSON = JSON.new()
	assert_eq(json.parse(graph.to_json()), OK)
	var back: NavGraph = NavGraph.from_dict(json.data)
	assert_eq(back.to_json(), graph.to_json(), "save -> load -> save is stable")
	assert_eq(back.links[2].weight, NavGraph.WEIGHT_HEAVY)
	assert_eq(back.links[2].cycle, PackedInt32Array([88, 0, 76]))
	assert_eq(back.links[2].cond, PackedInt32Array([mover, 0, -16, 0, 2]))
	assert_eq(back.links_from(0, NavGraph.WEIGHT_LIGHT), PackedInt32Array([0]), "the light class has its own links")
	assert_eq(back.links_from(0, NavGraph.WEIGHT_HEAVY), PackedInt32Array([2]), "the heavy class its own")
	assert_true(back.links[2].starts_on(76) and back.links[2].starts_on(164) and not back.links[2].starts_on(77))
	assert_eq(back.link_cost_from(back.links[2], 30), NavGraph.SETTLE_TICKS + 44 + 12, "a timed link costs half a period")


func test_weight_classes_follow_the_modes() -> void:
	assert_eq(NavGraph.weight_classes_for({"kind": "arena", "modes": "grub_stack"}), PackedInt32Array([0, 1, 2]))
	assert_eq(NavGraph.weight_classes_for({"kind": "arena", "modes": "hot_rock,last_caveman"}),
			PackedInt32Array([0, 3]))
	assert_eq(NavGraph.weight_classes_for({"kind": "arena", "modes": "clubball"}), PackedInt32Array([0]))
	assert_eq(NavGraph.weight_classes_for({"modes": "grub_stack"}), PackedInt32Array([0]), "not an arena: light only")
	assert_eq(NavGraph.class_walk_cap(NavGraph.WEIGHT_LIGHT), 0)
	assert_eq(NavGraph.class_walk_cap(NavGraph.WEIGHT_HEAVY), VersusTuning.STACK_HEAVY_WALK_CAP)
	assert_eq(NavGraph.class_walk_cap(NavGraph.WEIGHT_HEAVIER), VersusTuning.STACK_HEAVIER_WALK_CAP)
	assert_eq(NavGraph.class_walk_cap(NavGraph.WEIGHT_HOLDER), VersusTuning.HOT_ROCK_HOLDER_WALK_CAP)
	assert_true(NavGraph.class_jumps_short(NavGraph.WEIGHT_HEAVIER))
	assert_false(NavGraph.class_jumps_short(NavGraph.WEIGHT_HEAVY))


func test_heavier_class_cannot_jump_four_rows() -> void:
	# 20+ units: impulses x3/4, a 38 px rise - the 4-row bridge (feet into its row: 49+ px) is out of reach; the light
	# hero (60 px) lands on it.
	var graph: NavGraph = _tier()
	assert_eq(graph.weights, PackedInt32Array([NavGraph.WEIGHT_LIGHT, NavGraph.WEIGHT_HEAVIER]))
	var floor_node: int = graph.node_at(Vector2i(100, 160))
	var bridge: int = graph.node_at(Vector2i(100, 96))
	var up_light: bool = false
	var up_heavy: bool = false
	var down_heavy: bool = false
	for link: NavGraph.NavLink in graph.links:
		if link.from == floor_node and link.to == bridge:
			up_light = up_light or link.weight == NavGraph.WEIGHT_LIGHT
			up_heavy = up_heavy or link.weight == NavGraph.WEIGHT_HEAVIER
		if link.from == bridge and link.to == floor_node and link.weight == NavGraph.WEIGHT_HEAVIER:
			down_heavy = true
	assert_true(up_light, "the light hero jumps onto the bridge")
	assert_false(up_heavy, "the heavier one cannot")
	assert_true(down_heavy, "but he drops down from it")
	assert_eq(graph.path_cost(floor_node, 100, bridge, 100, {}, NavGraph.WEIGHT_HEAVIER), NavGraph.UNREACHABLE)
	assert_true(graph.path_cost(floor_node, 100, bridge, 100, {}, NavGraph.WEIGHT_LIGHT) < NavGraph.UNREACHABLE)


func test_heap_search_equals_a_brute_force_search() -> void:
	# A random graph of 30 nodes and 120 links: every cheapest cost equals a Bellman-Ford relaxation of the same
	# edge model, and the heap pops in (cost, id) order.
	var rng: SimRng = SimRng.new(1234)
	var graph: NavGraph = NavGraph.new()
	for i: int in 30:
		var node: NavGraph.NavNode = NavGraph.NavNode.new()
		node.row = i
		node.y = i * 16
		node.x0 = 0
		node.x1 = 300
		graph.add_node(node)
	for i: int in 120:
		var link: NavGraph.NavLink = NavGraph.NavLink.new()
		link.from = rng.next_int(30)
		link.to = rng.next_int(30)
		link.x0 = rng.range_int(0, 280)
		link.x1 = link.x0 + rng.range_int(0, 20)
		link.land_x0 = rng.range_int(0, 280)
		link.land_x1 = link.land_x0 + rng.range_int(0, 20)
		link.ticks = rng.range_int(5, 60)
		link.keys = "1:"
		graph.add_link(link)
	for trial: int in 40:
		var from: int = rng.next_int(30)
		var to: int = rng.next_int(30)
		var fx: int = rng.range_int(0, 300)
		var tx: int = rng.range_int(0, 300)
		assert_eq(graph.path_cost(from, fx, to, tx), _brute_cost(graph, from, fx, to, tx), "trial %d" % trial)
	var heap: PackedInt64Array = PackedInt64Array()
	for value: Vector2i in [Vector2i(9, 3), Vector2i(2, 7), Vector2i(9, 1), Vector2i(0, 5), Vector2i(2, 2)]:
		NavGraph.heap_push(heap, value.x, value.y)
	var popped: Array[Vector2i] = []
	while not heap.is_empty():
		var key: int = NavGraph.heap_pop(heap)
		popped.append(Vector2i(key >> NavGraph.ID_BITS, key & NavGraph.ID_MASK))
	assert_eq(popped, [Vector2i(0, 5), Vector2i(2, 2), Vector2i(2, 7), Vector2i(9, 1), Vector2i(9, 3)])


func test_geyser_links_are_timed_and_verified() -> void:
	var graph: NavGraph = _geyser_graph()
	var ledge: int = graph.node_at(Vector2i(130, 64))
	var floor_node: int = graph.node_at(Vector2i(130, 160))
	assert_true(ledge >= 0 and floor_node >= 0, "both floors are nodes")
	var found: NavGraph.NavLink = null
	for link: NavGraph.NavLink in graph.links:
		if link.to == ledge:
			assert_eq(link.kind, NavGraph.KIND_GEYSER, "only the geyser reaches the 6-row ledge (link %d)" % link.id)
			found = link
	assert_not_null(found, "a geyser link floor -> ledge")
	if found == null:
		return
	assert_eq(found.from, floor_node)
	assert_eq(found.cycle, PackedInt32Array([88, 0, 88 - Tuning.GEYSER_SPOUT_TICKS]),
			"it starts on the first spout tick of the level's cycle")
	var vent_x: int = 6 * Tuning.TILE + Tuning.TILE / 2
	assert_true(found.x0 >= vent_x - Tuning.GEYSER_VENT_W / 2 and found.x1 < vent_x + Tuning.GEYSER_VENT_W / 2,
			"its window lies in the vent (%d..%d)" % [found.x0, found.x1])
	var baker: NavBaker = NavBaker.new()
	var data: LevelData = LevelData.parse(graph.level_id, GEYSER_ARENA)
	assert_true(baker.sim.setup(self, graph.level_id, data.build_grid(0), data.resolved_meta(0), data.entity_records()))
	var problems: PackedStringArray = baker.verify_graph(graph)
	baker.sim.teardown()
	assert_eq(problems.size(), 0, "; ".join(problems))


func test_bot_rides_the_geyser_to_the_ledge() -> void:
	var graph: NavGraph = _geyser_graph()
	NavGraph.cache(graph)
	var level: Level = _load_arena_text(2, &"test_core_bots_geyser", GEYSER_ARENA)
	if level == null:
		return
	var bot: HeroBot = HeroBot.new(1, Defs.BotLevel.HUNTER, 5, Defs.VersusMode.LAST_CAVEMAN)
	var steering: _Steer = _Steer.new()
	steering.bot = bot
	bot.brain = steering
	bot.install()
	GameInput.set_scripted_slot(0, func(_tick: int) -> int: return 0)
	var hero: PlayerBase = level.get_hero(1)
	steering.target = Vector2i(140, 64)
	var reached: bool = false
	for t: int in 400:
		Sim.step(1)
		if bot.nav.arrived(hero) and not bot.nav.is_busy():
			reached = true
			break
	assert_true(reached, "the bot rode the geyser up (stands at %s)" % hero.sim_pos)
	assert_true(bot.nav.links_landed >= 1)
	assert_eq(bot.nav.links_failed, 0, "; ".join(bot.nav.failure_log))
	bot.uninstall()


func test_moving_platform_is_a_mover_node_with_verified_links() -> void:
	var graph: NavGraph = _lift_graph()
	assert_eq(graph.format, NavGraph.FORMAT)
	assert_eq(graph.movers.size(), 1, "the platform is a mover")
	if graph.movers.is_empty():
		return
	assert_eq(StringName(str(graph.movers[0]["kind"])), NavGraph.MOVER_PERIODIC, "it moves by itself")
	var left: int = graph.node_at(Vector2i(40, 80))
	var right: int = graph.node_at(Vector2i(260, 80))
	var platform: int = -1
	for node: NavGraph.NavNode in graph.nodes:
		if node.mover >= 0:
			platform = node.id
	assert_true(left >= 0 and right >= 0 and platform >= 0, "both ledges and the platform are nodes")
	var board: int = 0
	var off: int = 0
	for link: NavGraph.NavLink in graph.links:
		assert_true(link.kind != NavGraph.KIND_JUMP or link.from != left or link.to != right,
				"no jump crosses the gap (link %d)" % link.id)
		if link.to == platform and link.from == left:
			board += 1
			assert_eq(link.kind, NavGraph.KIND_RIDE)
			assert_eq(link.cond.size(), 5, "a boarding waits for the platform's state")
		if link.from == platform and link.to == right:
			off += 1
	assert_true(board >= 1, "left ledge -> platform")
	assert_true(off >= 1, "platform -> right ledge")
	assert_true(graph.path_cost(left, 40, right, 260) < NavGraph.UNREACHABLE, "a route across by the platform")
	var baker: NavBaker = NavBaker.new()
	var data: LevelData = LevelData.parse(graph.level_id, LIFT_ARENA)
	assert_true(baker.sim.setup(self, graph.level_id, data.build_grid(0), data.resolved_meta(0), data.entity_records()))
	var problems: PackedStringArray = baker.verify_graph(graph)
	baker.sim.teardown()
	assert_eq(problems.size(), 0, "; ".join(problems))


func test_bot_rides_the_moving_platform_across() -> void:
	var graph: NavGraph = _lift_graph()
	NavGraph.cache(graph)
	var level: Level = _load_arena_text(2, &"test_core_bots_lift", LIFT_ARENA)
	if level == null:
		return
	var bot: HeroBot = HeroBot.new(1, Defs.BotLevel.HUNTER, 5, Defs.VersusMode.LAST_CAVEMAN)
	var steering: _Steer = _Steer.new()
	steering.bot = bot
	bot.brain = steering
	bot.install()
	GameInput.set_scripted_slot(0, func(_tick: int) -> int: return 0)
	var hero: PlayerBase = level.get_hero(1)
	assert_eq(graph.node_at(hero.sim_pos), graph.node_at(Vector2i(40, 80)), "the bot starts on the left ledge")
	var rode: bool = false
	for target: Vector2i in [Vector2i(260, 80), Vector2i(40, 80)]:
		steering.target = target
		var reached: bool = false
		for t: int in 900:
			Sim.step(1)
			rode = rode or hero.on_platform
			if bot.nav.arrived(hero) and not bot.nav.is_busy():
				reached = true
				break
		assert_true(reached, "the bot reached %s (stands at %s)" % [target, hero.sim_pos])
	assert_true(rode, "on the platform")
	assert_eq(bot.nav.links_failed, 0, "; ".join(bot.nav.failure_log))
	bot.uninstall()


# =================================================================================================================
# HeroBot on the flat test arena
# =================================================================================================================

func test_hero_bot_is_a_deterministic_input_producer() -> void:
	var a: HeroBot = HeroBot.new(2, Defs.BotLevel.ROOKIE, 77)
	var b: HeroBot = HeroBot.new(2, Defs.BotLevel.ROOKIE, 77)
	var c: HeroBot = HeroBot.new(3, Defs.BotLevel.ROOKIE, 77)
	assert_eq(a.reaction, 10)
	assert_eq(HeroBot.new(0, Defs.BotLevel.HUNTER).reaction, 6)
	assert_eq(HeroBot.new(0, Defs.BotLevel.CHIEF).reaction, 3)
	var sa: PackedInt32Array = PackedInt32Array()
	var sb: PackedInt32Array = PackedInt32Array()
	var sc: PackedInt32Array = PackedInt32Array()
	for i: int in 8:
		sa.append(a.rng.next_u32())
		sb.append(b.rng.next_u32())
		sc.append(c.rng.next_u32())
	assert_eq(sa, sb, "same seed and slot, same stream")
	assert_ne(sa, sc, "another slot, another stream")
	var state: int = Sim.rng.get_state()
	a.install()
	assert_eq(GameInput.get_slot(2).kind, Defs.InputSlotKind.BOT)
	assert_eq(a.produce(1), 0, "no level, no input")
	a.uninstall()
	assert_eq(GameInput.get_slot(2).kind, Defs.InputSlotKind.NONE)
	assert_eq(Sim.rng.get_state(), state, "a bot never draws from Sim.rng")
	assert_true(HeroBot.make_brain(Defs.VersusMode.GRUB_STACK) is GrubStackBrain)


func test_bot_walks_the_flat_arena() -> void:
	if not _has_flat_arena():
		return
	var graph: NavGraph = _flat_graph()
	var level: Level = _load_arena(2)
	var bot: HeroBot = HeroBot.new(1, Defs.BotLevel.HUNTER, 5)
	var steering: _Steer = _Steer.new()
	steering.bot = bot
	bot.brain = steering
	bot.install()
	var hero: PlayerBase = level.get_hero(1)
	assert_not_null(hero)
	# The floor end to end, up onto both ledges and back down: goals given by hand.
	var targets: Array[Vector2i] = [Vector2i(40, 160), Vector2i(280, 160), Vector2i(90, 112), Vector2i(230, 112),
			Vector2i(150, 160)]
	for target: Vector2i in targets:
		steering.target = target
		var reached: int = -1
		for t: int in 360:
			Sim.step(1)
			if bot.nav.arrived(hero) and not bot.nav.is_busy():
				reached = t
				break
		assert_true(reached >= 0, "the bot reached %s (stands at %s)" % [target, hero.sim_pos])
		assert_eq(graph.node_at(hero.sim_pos), graph.node_at(target), "on the target's floor")
	assert_eq(bot.nav.links_failed, 0, "every link landed where it should: %s" % "; ".join(bot.nav.failure_log))
	assert_true(bot.nav.links_landed >= 3, "it jumped up, crossed and dropped (%d links)" % bot.nav.links_landed)
	bot.uninstall()


func test_bot_climbs_the_totem_and_crosses_the_wrap_seam() -> void:
	# The Totem Ring copy of world-B: floor -> totem top (the cookpot) by bridge jumps or a spring, a wrap ledge, and
	# a walk across the left-right seam.
	if not FileAccess.file_exists(RING_ARENA):
		assert_true(true, "levels/test_world_arena_ring.lvl does not exist yet")
		return
	var graph: NavGraph = _arena_graph(RING_ARENA)
	var level: Level = _load_arena(2, RING_ARENA)
	var bot: HeroBot = HeroBot.new(1, Defs.BotLevel.HUNTER, 5)
	var steering: _Steer = _Steer.new()
	steering.bot = bot
	bot.brain = steering
	bot.install()
	var hero: PlayerBase = level.get_hero(1)
	var wrap_links: int = 0
	for link: NavGraph.NavLink in graph.links:
		if link.kind == NavGraph.KIND_WRAP:
			wrap_links += 1
	if graph.wrap == "lr" and NavSim.find_wrap_step().is_valid():
		assert_true(wrap_links > 0, "the seam is in the graph")
	# The totem top, the right wrap ledge, the left floor end, then the right floor end (across the seam).
	var targets: Array[Vector2i] = [Vector2i(152, 64), Vector2i(290, 80), Vector2i(30, 160), Vector2i(300, 160)]
	for target: Vector2i in targets:
		steering.target = target
		var reached: bool = false
		for t: int in 480:
			Sim.step(1)
			if bot.nav.arrived(hero) and not bot.nav.is_busy():
				reached = true
				break
		assert_true(reached, "the bot reached %s (stands at %s)" % [target, hero.sim_pos])
	assert_eq(bot.nav.links_failed, 0, "every link landed where it should: %s" % "; ".join(bot.nav.failure_log))
	bot.uninstall()


func test_committed_graphs_hold() -> void:
	# Every graph under resources/bots: its level exists, it was baked from that level text (an arena_* graph must
	# be re-baked when its arena changes; a stale test_* graph is only skipped), and every link still lands from
	# every x of its window.
	var files: PackedStringArray = PackedStringArray()
	if DirAccess.dir_exists_absolute(NavGraph.DIR):
		for file: String in DirAccess.get_files_at(NavGraph.DIR):
			if file.get_extension() == "json":
				files.append(file)
	files.sort()
	assert_true(true, "%d graph(s)" % files.size())
	for file: String in files:
		var graph: NavGraph = NavGraph.load_file("%s/%s" % [NavGraph.DIR, file])
		assert_not_null(graph, file)
		if graph == null:
			continue
		var level_path: String = "res://levels/%s.lvl" % graph.level_id
		assert_true(FileAccess.file_exists(level_path), "%s: its level %s exists" % [file, level_path])
		if not FileAccess.file_exists(level_path):
			continue
		var text: String = FileAccess.get_file_as_string(level_path)
		var fresh: bool = NavGraph.text_sha256(text) == graph.source_sha256
		if not String(graph.level_id).begins_with("test_"):
			assert_true(fresh, "%s is stale: bash .tools/gd.sh script res://tools/bots/bake_nav.gd -- %s" % [
				file, graph.level_id,
			])
		if not fresh:
			continue
		var data: LevelData = LevelData.parse(graph.level_id, text, level_path)
		var baker: NavBaker = NavBaker.new()
		assert_true(baker.sim.setup(self, graph.level_id, data.build_grid(0), data.resolved_meta(0),
				data.entity_records()))
		var problems: PackedStringArray = baker.verify_graph(graph)
		baker.sim.teardown()
		assert_eq(problems.size(), 0, "%s: %s" % [file, "; ".join(problems)])


func test_bake_tool_lists_arenas_and_verifies() -> void:
	var runner_script: GDScript = load("res://tools/bots/bake_nav_runner.gd") as GDScript
	assert_not_null(runner_script)
	var levels: PackedStringArray = runner_script.call(&"default_levels")
	for path: String in levels:
		var file: String = path.get_file()
		assert_true(file.begins_with("arena_") or file.begins_with("test_world_arena"), path)
	if not _has_flat_arena():
		return
	assert_true(levels.has(FLAT_ARENA))
	var runner: Node = add_node(runner_script.new() as Node)
	assert_eq(int(runner.call(&"run", PackedStringArray(["--bogus"]))), 2, "an unknown option")
	assert_eq(int(runner.call(&"run", PackedStringArray(["--classes=7"]))), 2, "an unknown weight class")
	assert_eq(int(runner.call(&"run", PackedStringArray(["--clip=1,2"]))), 2, "a clip needs four numbers")
	assert_eq(int(runner.call(&"run", PackedStringArray(["--verify", "test_world_arena_flat"]))), 0,
			"the committed flat-arena graph verifies")
	assert_eq(int(runner.call(&"run", PackedStringArray(["--verify", "test_core_bots_no_such_level"]))), 1)


func test_bot_match_replays_tick_for_tick() -> void:
	var first: PackedInt32Array = _bot_match_trace(9)
	var second: PackedInt32Array = _bot_match_trace(9)
	if first.is_empty():
		return
	assert_eq(first, second, "the same seed plays the same match")
	var moved: int = 0
	for value: int in first:
		if value != 0:
			moved += 1
	assert_true(moved > 100, "the bots pressed keys")


# =================================================================================================================
# Helpers
# =================================================================================================================

## Cheapest cost by relaxing every link until nothing changes (the reference for the heap search).
func _brute_cost(graph: NavGraph, from: int, fx: int, to: int, tx: int) -> int:
	var best: int = NavGraph.walk_ticks(tx - fx) if from == to else NavGraph.UNREACHABLE
	var dist: PackedInt32Array = PackedInt32Array()
	dist.resize(graph.links.size())
	dist.fill(NavGraph.UNREACHABLE)
	for id: int in graph.links_from(from):
		dist[id] = graph.link_cost_from(graph.links[id], fx)
	var changed: bool = true
	while changed:
		changed = false
		for link: NavGraph.NavLink in graph.links:
			if dist[link.id] >= NavGraph.UNREACHABLE:
				continue
			for next: int in graph.links_from(link.to):
				var cost: int = dist[link.id] + graph.link_cost_from(graph.links[next], link.land_center())
				if cost < dist[next]:
					dist[next] = cost
					changed = true
	for link: NavGraph.NavLink in graph.links:
		if link.to == to and dist[link.id] < NavGraph.UNREACHABLE:
			best = mini(best, dist[link.id] + NavGraph.walk_ticks(tx - link.land_center()))
	return best


## The geyser arena's graph, baked once for the whole file.
func _geyser_graph() -> NavGraph:
	if _geyser_json.is_empty():
		var baked: NavGraph = NavBaker.new().bake_text(self, &"test_core_bots_geyser", GEYSER_ARENA)
		_geyser_json = baked.to_json()
	var json: JSON = JSON.new()
	json.parse(_geyser_json)
	return NavGraph.from_dict(json.data)


## The lift arena's graph, baked once for the whole file.
func _lift_graph() -> NavGraph:
	if _lift_json.is_empty():
		var baked: NavGraph = NavBaker.new().bake_text(self, &"test_core_bots_lift", LIFT_ARENA)
		_lift_json = baked.to_json()
	var json: JSON = JSON.new()
	json.parse(_lift_json)
	return NavGraph.from_dict(json.data)


## An arena given as text through the real level loader as a versus round of `party` heroes; null (the test passes
## with a note) while the referee does not compile.
func _load_arena_text(party: int, level_id: StringName, text: String) -> Level:
	var referee_script: Script = load("res://scripts/world/versus/referee.gd") as Script
	if referee_script == null or not referee_script.can_instantiate():
		assert_true(true, "the referee does not compile right now (world-B)")
		return null
	Sim.manual = true
	Game.start_run(Defs.Difficulty.BEGINNER, Defs.GameMode.VERSUS, party, 1)
	Game.begin_level(level_id)
	var level: Level = (load(LEVEL_SCENE) as PackedScene).instantiate() as Level
	level.setup_from_text(level_id, text)
	add_node(level)
	level.set_view_size(Vector2i(640, 360))
	Sim.start(1)
	var referee: Object = BotSenses.referee(level)
	if referee != null and referee.has_method(&"start_round_now"):
		referee.call(&"start_round_now")
	return level


## A brain that only walks to `target` (the walk test gives the goals by hand).
class _Steer:
	extends BotBrain

	var target: Vector2i = Vector2i.ZERO

	func think(_hero: PlayerBase, _level: LevelBase, _tick: int) -> void:
		pass

	func act(hero: PlayerBase, _level: LevelBase, tick: int) -> int:
		bot.nav.set_target(target, 4)
		return bot.nav.step(hero, tick)


## Floor (row 10, x 8..311), a ledge (row 7, x 48..127) and two links between them.
func _small_graph() -> NavGraph:
	var graph: NavGraph = NavGraph.new()
	graph.level_id = &"test_core_bots_small"
	graph.cols = 20
	graph.rows = 12
	for entry: Array in [[10, 8, 311], [7, 48, 127]]:
		var node: NavGraph.NavNode = NavGraph.NavNode.new()
		node.row = int(entry[0])
		node.y = node.row * 16
		node.x0 = int(entry[1])
		node.x1 = int(entry[2])
		graph.add_node(node)
	var up: NavGraph.NavLink = NavGraph.NavLink.new()
	up.from = 0
	up.to = 1
	up.kind = NavGraph.KIND_JUMP
	up.x0 = 30
	up.x1 = 40
	up.dir = 1
	up.keys = "3:RU,8:R"
	up.ticks = 11
	up.land_x0 = 55
	up.land_x1 = 65
	graph.add_link(up)
	var down: NavGraph.NavLink = NavGraph.NavLink.new()
	down.from = 1
	down.to = 0
	down.kind = NavGraph.KIND_DROP
	down.x0 = 120
	down.x1 = 127
	down.dir = 1
	down.keys = "12:R"
	down.ticks = 12
	down.land_x0 = 140
	down.land_x1 = 150
	graph.add_link(down)
	graph.rebuild()
	return graph


func _has_flat_arena() -> bool:
	if FileAccess.file_exists(FLAT_ARENA):
		return true
	assert_true(true, "levels/test_world_arena_flat.lvl does not exist yet")
	return false


## The flat test arena (world-B's levels/test_world_arena_flat.lvl) through the real level loader as a versus round
## of `party` heroes (the loader hands an arena to world-B's referee; the intro countdown is skipped when it can be).
func _load_arena(party: int, path: String = FLAT_ARENA) -> Level:
	var level_id: StringName = StringName(path.get_file().get_basename())
	Sim.manual = true
	Game.start_run(Defs.Difficulty.BEGINNER, Defs.GameMode.VERSUS, party, 1)
	Game.begin_level(level_id)
	var level: Level = (load(LEVEL_SCENE) as PackedScene).instantiate() as Level
	level.setup_from_text(level_id, FileAccess.get_file_as_string(path))
	add_node(level)
	level.set_view_size(Vector2i(640, 360))
	Sim.start(1)
	var referee: Object = BotSenses.referee(level)
	if referee != null and referee.has_method(&"start_round_now"):
		referee.call(&"start_round_now")
	return level


## The flat arena's graph: the committed one when its source matches the file, else a fresh bake (cached). Call it
## before loading a level: a bake runs its own sim world.
func _flat_graph() -> NavGraph:
	return _arena_graph(FLAT_ARENA)


## An arena graph: the committed one when its source matches the file, else a fresh bake (cached).
func _arena_graph(path: String) -> NavGraph:
	var level_id: StringName = StringName(path.get_file().get_basename())
	var text: String = FileAccess.get_file_as_string(path)
	var graph: NavGraph = NavGraph.load_file(NavGraph.path_for(level_id))
	if graph == null or graph.source_sha256 != NavGraph.text_sha256(text):
		graph = NavBaker.new().bake_text(self, level_id, text)
	NavGraph.cache(graph)
	return graph


## Two Hunter bots play 300 ticks of the flat arena; the trace is both slots' flags per tick.
func _bot_match_trace(seed_value: int) -> PackedInt32Array:
	if not _has_flat_arena():
		return PackedInt32Array()
	_flat_graph()
	var level: Level = _load_arena(2)
	var bots: Array[HeroBot] = [HeroBot.new(0, Defs.BotLevel.HUNTER, seed_value),
			HeroBot.new(1, Defs.BotLevel.HUNTER, seed_value)]
	for bot: HeroBot in bots:
		bot.install()
	var trace: PackedInt32Array = PackedInt32Array()
	for t: int in 300:
		Sim.step(1)
		trace.append(GameInput.get_flags(0))
		trace.append(GameInput.get_flags(1))
	trace.append(level.get_hero(0).sim_pos.x)
	trace.append(level.get_hero(1).sim_pos.x)
	for bot: HeroBot in bots:
		bot.uninstall()
	level.free()
	return trace
