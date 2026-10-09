extends TestCase
## The solo search's own mechanics after the G3b round (owner: world-B; the orchestrator's R7, DESIGN.md G71-G79,
## LEVEL_DESIGN.md 15.7.6): the EXACT RESET of the search world (the deep state, the in-place respawn, the clocks),
## the wards in the search world, the long climb (a hero at rest on a vine is a node), the wind's phases, the new
## probe families (ride, lure, strike-on-spring, the second throw), the slot rule read from the engine, and the tools
## of tools/coop_explore (route files, kept results, the row's verdict). The gate table itself is
## tests/test_coop_gates.gd; the search's older mechanics are in tests/test_world_validator.gd.

const HARNESS: String = "res://tools/coop_explore/harness.gd"
const EXACT: String = "res://tools/coop_explore/exact.gd"
const GATES_TEST: String = "res://tests/test_coop_gates.gd"


## A co-op map of `cols` x `rows` cells with a two-row floor, '@' at 1 and the exit at the right end of the row over
## it; `paint` = [[row, from col, to col, char], ...]; `meta` extra meta lines.
func _level(id: String, entities: String, paint: Array = [], cols: int = 40, rows: int = 16,
		meta: String = "") -> LevelData:
	var lines: PackedStringArray = PackedStringArray()
	for row: int in rows:
		lines.append((TileGrid.CH_SOLID_A if row >= rows - 2 else TileGrid.CH_AIR).repeat(cols))
	lines[rows - 3] = ".@" + ".".repeat(cols - 4) + "E."
	for item: Array in paint:
		var line: String = lines[int(item[0])]
		for col: int in range(int(item[1]), int(item[2]) + 1):
			line = line.substr(0, col) + str(item[3]) + line.substr(col + 1)
		lines[int(item[0])] = line
	var text: String = "[meta]\nformat = 2\nid = %s\nkind = coop\nbook = 2\nterrain_a = jungle/terrain_grass\n" % id \
			+ "music = level_jungle\ncoop_of = solo_bonus\ncoop_base_hash = %s\n%s\n" % ["ab".repeat(32), meta] \
			+ "[legend]\nE = objects/exit\n[tiles]\n%s\n[entities]\n%s\n" % ["\n".join(lines), entities]
	return LevelData.parse(StringName(id), text, "%s.lvl" % id)


func _world(data: LevelData, difficulty: int = Defs.Difficulty.BEGINNER) -> CoopSearch.Searcher:
	var searcher: CoopSearch.Searcher = CoopSearch.Searcher.new()
	assert_true(searcher.build_world(data, difficulty, CoopSearch.grid_at_rest(data, difficulty),
			Vector2i(0, data.cols)), "the search world builds")
	return searcher


## A level with what a reset has to bring back: followers, a keeper pair in a bond, a spring, a pot, a boulder, a
## plate and its door, a drum pair, a vine, a hidden spot, a geyser, a lift, a weapon.
func _busy_level(id: String) -> LevelData:
	return _level(id, "\n".join(PackedStringArray([
		"objects/x2_tablet 4 13 gate=g far=36,13",
		"enemies/hopper 9 13",
		"enemies/harrier 14 6 range=6",
		"enemies/walker 30 13 coop=bond bond=pair keeper=k",
		"enemies/walker 34 13 coop=bond bond=pair keeper=k",
		"objects/column 35 13 size=1,3 trigger=keepers:k",
		"objects/spring 7 13",
		"objects/flower_pot 11 13",
		"objects/boulder_heavy 16 13",
		"objects/plate 19 13 name=p mode=hold",
		"objects/column 22 13 size=1,2 rise=2 rise_while=p",
		"objects/drum 24 13 bond=d",
		"objects/drum 27 12 bond=d",
		"objects/vine 12 4 length=8",
		"objects/hidden_spot 6 13",
		"objects/geyser 17 13",
		"objects/platform 25 9 mode=patrol",
		"items/weapon 3 13",
	])))


# =================================================================================================================
# The deep state
# =================================================================================================================

class Owned:
	extends RefCounted
	var count: int = 0
	var names: PackedStringArray = PackedStringArray()


class Lister:
	extends RefCounted
	var listed: Array = []


class Holder:
	extends RefCounted
	var number: int = 3
	var text: String = "a"
	var cells: Array[Vector2i] = []
	var packed: PackedInt32Array = PackedInt32Array([1, 2])
	var table: Dictionary = {}
	var owned: Owned = Owned.new()
	var nothing: Owned = null
	var sim_prev: Vector2i = Vector2i.ZERO   # (a name of DEEP_SKIP)


func test_deep_state_reads_every_script_variable_and_owned_objects() -> void:
	var a: Holder = Holder.new()
	var b: Holder = Holder.new()
	assert_eq(CoopSearch.deep_state(a), CoopSearch.deep_state(b), "two fresh objects: the same deep state")
	assert_false(CoopSearch.deep_names(a).has(&"sim_prev"), "Sim's own bookkeeping is left out")
	for change: Callable in [func(h: Holder) -> void: h.number = 4,
			func(h: Holder) -> void: h.cells.append(Vector2i(1, 2)), func(h: Holder) -> void: h.packed.append(3),
			func(h: Holder) -> void: h.table["k"] = 1, func(h: Holder) -> void: h.owned.count = 1,
			func(h: Holder) -> void: h.owned.names.append("x"), func(h: Holder) -> void: h.nothing = Owned.new()]:
		b = Holder.new()
		change.call(b)
		assert_ne(CoopSearch.deep_state(a), CoopSearch.deep_state(b), "a changed variable changes the deep state")
	b = Holder.new()
	b.sim_prev = Vector2i(5, 5)
	assert_eq(CoopSearch.deep_state(a), CoopSearch.deep_state(b), "... but a skipped one does not")


func test_deep_snapshot_puts_every_variable_back_and_says_when_it_cannot() -> void:
	var a: Holder = Holder.new()
	a.cells.append(Vector2i(1, 1))
	a.table["k"] = [1, 2]
	var base: String = CoopSearch.deep_state(a)
	var snap: Dictionary = CoopSearch.deep_snapshot(a)
	assert_eq(CoopSearch.deep_restore(a, snap), 0, "nothing changed: nothing written")
	a.number = 9
	a.text = "z"
	a.cells.append(Vector2i(2, 2))
	a.packed.append(7)                # (a packed array is shared by reference: the snapshot holds its own copy)
	a.table["k"] = [3]
	a.owned.count = 5
	a.owned.names.append("n")
	a.nothing = Owned.new()
	var own: Owned = a.owned
	assert_ne(CoopSearch.deep_state(a), base)
	assert_eq(CoopSearch.deep_restore(a, snap), 1, "variables were put back")
	assert_eq(CoopSearch.deep_state(a), base, "the object is in its snapshot's state again")
	assert_true(is_same(a.owned, own), "its own component is the same object, with its variables put back")
	assert_eq(a.packed, PackedInt32Array([1, 2]))
	a.packed.append(8)
	assert_eq(CoopSearch.deep_restore(a, snap), 1, "... and a second time: the snapshot's copy was not handed out")
	assert_eq(a.packed, PackedInt32Array([1, 2]))
	# An object the snapshot held is gone: nothing to put back.
	var node: Node = Node.new()
	var keeper: RefCounted = (load(HARNESS) as GDScript).new()
	keeper.set(&"data", null)
	var holder_snap: Dictionary = {&"number": [node]}
	node.free()
	assert_eq(CoopSearch.deep_restore(a, holder_snap), -1, "a freed object cannot be put back: the caller respawns")
	assert_eq(CoopSearch.snapshot(a, [&"number", &"text"]), {&"number": 3, &"text": "a"}, "the plain snapshot")
	# A container that names objects is never put back blindly (its copy would hand back objects a reset has freed):
	# it is held to the names of what it holds, and whoever names something else cannot be put back.
	var lister: Lister = Lister.new()
	var first: Node = Node.new()
	var second: Node = Node.new()
	lister.listed = [first]
	var list_snap: Dictionary = CoopSearch.deep_snapshot(lister)
	assert_eq(CoopSearch.deep_restore(lister, list_snap), 0, "the same list: nothing to do")
	lister.listed = [second]
	assert_eq(CoopSearch.deep_restore(lister, list_snap), 0,
			"another node of the same name in the search world (a respawned neighbour): the list stands as it is")
	assert_true(is_same(lister.listed[0], second), "... and is NOT written back to the old object")
	lister.listed = [first, second]
	assert_eq(CoopSearch.deep_restore(lister, list_snap), -1, "it names more than it did: built anew by the caller")
	lister.listed = []
	assert_eq(CoopSearch.deep_restore(lister, list_snap), -1)
	first.free()
	second.free()


# =================================================================================================================
# The exact reset
# =================================================================================================================

func test_the_search_world_starts_every_run_on_the_same_clocks_and_gives_them_back() -> void:
	Sim.step(7)
	var tick: int = Sim.tick
	var total: int = Sim.total_ticks
	var searcher: CoopSearch.Searcher = _world(_busy_level("clock_coop"))
	assert_eq(Sim.tick, CoopSearch.TICK_BASE, "a search world is built with the level's clock at its base")
	assert_eq(Sim.total_ticks, CoopSearch.TOTAL_TICK_BASE,
			"... and the total clock at its base (every 'until' an enemy keeps, the bond window, a strike's key)")
	var start: Vector2i = Vector2i(5 * 16, 14 * 16)
	searcher.run(searcher._config(start, 1, -1, CoopSearch.PARTNER_EGG, CoopSearch.NOWHERE),
			CoopSearch._repeat(Defs.IN_RIGHT, 30), {})
	assert_true(Sim.tick > CoopSearch.TICK_BASE + 30, "a run plays on from there")
	searcher._begin(searcher._config(start, 1, -1, CoopSearch.PARTNER_EGG, CoopSearch.NOWHERE))
	assert_eq(Sim.tick, CoopSearch.TICK_BASE, "the next run starts on the same tick again")
	assert_eq(Sim.total_ticks, CoopSearch.TOTAL_TICK_BASE)
	assert_eq(GameInput.get_flags(0), 0, "no key of the run before is held")
	var played: int = searcher._elapsed
	searcher.close()
	assert_eq(Sim.tick, tick, "close() gives the process its tick back")
	assert_true(Sim.total_ticks >= total + played, "... and its total clock, moved on by what was played (never back)")


func test_a_respawned_entity_keeps_its_place_in_the_tick_order() -> void:
	var searcher: CoopSearch.Searcher = _world(_busy_level("order_coop"))
	var order: Array = []
	for entity: SimEntity in searcher._entities:
		order.append(entity._sim_serial)
	var index: int = -1
	for i: int in searcher._records.size():
		if String(searcher._records[i]["id"]) == "enemies/harrier":
			index = i
	assert_true(index > 0 and index < searcher._entities.size() - 1, "an entity in the middle of the order")
	var enemies_before: Array = []
	for entity: SimEntity in searcher.level.get_kind(Defs.Kind.ENEMY):
		enemies_before.append(searcher._index_of.get(entity.get_instance_id(), -1))
	var old: SimEntity = searcher._entities[index]
	var respawns: int = searcher.respawns
	searcher._respawn_in_place(index)
	var fresh: SimEntity = searcher._entities[index]
	assert_false(is_instance_valid(old), "the old entity is gone")
	assert_eq(searcher.respawns, respawns + 1)
	assert_eq(fresh._sim_serial, int(order[index]), "the new one has the old one's registration serial")
	var enemies_after: Array = []
	for entity: SimEntity in searcher.level.get_kind(Defs.Kind.ENEMY):
		enemies_after.append(searcher._index_of.get(entity.get_instance_id(), -1))
	assert_eq(enemies_after, enemies_before, "the level lists its kind in the same order")
	for phase: int in fresh._sim_phase_list:
		var list: Array = Sim._phase_lists[phase]
		for k: int in range(1, list.size()):
			assert_true((list[k - 1] as SimEntity)._sim_serial < (list[k] as SimEntity)._sim_serial,
					"Sim's phase list stays sorted by serial")
	assert_eq(CoopSearch.deep_state(fresh), searcher._deep_base[index], "... and it is in the level-file state")
	# The bond's registry keeps its order too.
	var walker: int = -1
	for i: int in searcher._records.size():
		if String(searcher._records[i]["id"]) == "enemies/walker" and walker < 0:
			walker = i
	var first: SimEntity = searcher.level.get_tagged(&"bond", &"pair")[0]
	assert_eq(int(searcher._index_of[first.get_instance_id()]), walker)
	searcher._respawn_in_place(walker)
	assert_eq(int(searcher._index_of[searcher.level.get_tagged(&"bond", &"pair")[0].get_instance_id()]), walker,
			"the first member of the bond is still the first")
	# A hero keeps a list of the level's vines: after a vine was spawned again the next run's hero names the NEW one
	# (wf11: the old list came back from his snapshot with the freed vine in it - he never climbed that vine again).
	var vine: int = -1
	for i: int in searcher._records.size():
		if String(searcher._records[i]["id"]) == "objects/vine":
			vine = i
	searcher._respawn_in_place(vine)
	searcher._begin(searcher._config(Vector2i(5 * 16, 14 * 16), 1, -1, CoopSearch.PARTNER_EGG, CoopSearch.NOWHERE))
	assert_false(CoopSearch.deep_state(searcher.hero).contains("freed"), "the hero names no freed entity")
	assert_true(CoopSearch.deep_state(searcher.hero).contains("#%d" % vine), "... but the vine that stands there now")
	assert_eq(searcher.drift, 0)
	searcher.close()


func test_the_exact_reset_replays_every_route_identically_whatever_was_played_before() -> void:
	var exact: GDScript = load(EXACT) as GDScript
	var digests: PackedStringArray = PackedStringArray()
	for order: int in [1, 2]:
		var lib: RefCounted = (load(HARNESS) as GDScript).new()
		assert_true(lib.build_data(_busy_level("exact_coop"), "g", Defs.Difficulty.BEGINNER, true))
		var result: Dictionary = exact.call(&"check_lib", lib, 6, 2, 260, 5, order, true, false)
		assert_true(bool(result["exact"]), "\n".join(result["lines"] as PackedStringArray))
		assert_eq(int(result["off"]), 0, "no play leaves its route's first trajectory")
		assert_eq(int(result["drift"]), 0, "no entity is left out of the level-file state")
		assert_eq(int(result["audit_drift"]), 0, "nothing that did not tick was changed (the audit compares EVERY entity)")
		digests.append(str(result["digest"]))
		await Engine.get_main_loop().process_frame
	assert_eq(digests[0], digests[1], "the same routes in another order: the same trajectories (the first route of each order starts from the built world)")


func test_a_reset_brings_back_what_a_run_changed() -> void:
	var searcher: CoopSearch.Searcher = _world(_busy_level("back_coop"))
	var start: Vector2i = Vector2i(5 * 16, 14 * 16)
	var config: Dictionary = searcher._config(start, 1, -1, CoopSearch.PARTNER_EGG, CoopSearch.NOWHERE)
	searcher._begin(config)
	var base: PackedStringArray = PackedStringArray()
	for entity: SimEntity in searcher._entities:
		base.append(CoopSearch.deep_state(entity))
	var hero_base: String = CoopSearch.deep_state(searcher.hero)
	# A run that strikes the spot, springs, wakes the followers, collects, pushes: 400 ticks of everything.
	var flags: PackedInt32Array = PackedInt32Array()
	for i: int in 400:
		flags.append([Defs.IN_RIGHT, Defs.IN_RIGHT | Defs.IN_UP, Defs.IN_FIRE, Defs.IN_DOWN | Defs.IN_FIRE,
			Defs.IN_RIGHT, Defs.IN_UP][(i / 9) % 6])
	searcher._flags = flags
	Sim.step(400)
	var changed: int = 0
	for i: int in searcher._entities.size():
		var entity: SimEntity = searcher.entity_at(i)
		changed += 1 if entity == null or CoopSearch.deep_state(entity) != base[i] else 0
	assert_true(changed >= 3, "the run changed entities (%d)" % changed)
	searcher._begin(config)
	for i: int in searcher._entities.size():
		assert_eq(CoopSearch.deep_state(searcher.entity_at(i)), base[i], "%s is in its level-file state again"
				% str(searcher._records[i]["id"]))
	assert_eq(CoopSearch.deep_state(searcher.hero), hero_base, "... and so is the hero")
	assert_eq(searcher.drift, 0)
	assert_true(searcher.respawns + searcher.restores > 0, "by a respawn in place or by its variables put back")
	searcher.close()


# =================================================================================================================
# The wards (G73), the wind's phases (G79), the slot rule (G72)
# =================================================================================================================

func test_the_search_world_declares_the_wards_of_the_files_tablets() -> void:
	var data: LevelData = _level("ward_coop", "objects/x2_tablet 10 13 gate=g far=20,13 ward=3,5\n"
			+ "objects/x2_tablet 30 13 gate=h far=33,13")
	var searcher: CoopSearch.Searcher = _world(data)
	var wards: Array[Vector2i] = searcher.level.get_wards()
	assert_true(wards.has(Vector2i(7, 25)), "ward=3,5: 10 - 3 .. 20 + 5 (%s)" % str(wards))
	assert_true(wards.has(Vector2i(30 - PartyTuning.WARD_MARGIN_CELLS, 39)), "the default margin, clipped to the map")
	assert_true(searcher.level.in_ward(8 * 16))
	assert_false(searcher.level.in_ward(6 * 16 + 15))
	searcher.close()
	# The validator's own rule (it cannot name the tablet's class) is the tablet's.
	for tablet: Array in [[10, 20, ""], [20, 10, "3,5"], [5, 9, "0,0"], [12, -1, ""], [8, 30, "22,12"], [8, 30, "x"]]:
		var record: Dictionary = {"col": tablet[0], "row": 13, "line": 1, "params": {"gate": "g"}}
		if int(tablet[1]) >= 0:
			record["params"]["far"] = "%d,13" % int(tablet[1])
		if str(tablet[2]) != "":
			record["params"]["ward"] = tablet[2]
		var engine: Vector2i = X2Tablet.ward_columns(int(tablet[0]), int(tablet[1]), tablet[2])
		assert_eq(LevelValidator.ward_columns(LevelValidator.parse_tablet(record), 1000),
				Vector2i(maxi(engine.x, 0), engine.y), "tablet %s" % str(tablet))


func test_the_wind_script_is_played_in_every_phase() -> void:
	var data: LevelData = _level("wind_coop", "objects/x2_tablet 4 13 gate=g far=36,13", [], 40, 16,
			"wind = 0:0,110:112,176:0,286:-112\nwind_loop = 352")
	var searcher: CoopSearch.Searcher = _world(data)
	assert_eq(searcher._wind_phases, PackedInt32Array([0, 109, 175, 285]), "the play ticks at which the wind changes")
	var start: Vector2i = Vector2i(5 * 16, 14 * 16)
	var config: Dictionary = searcher._config(start, 1, -1, CoopSearch.PARTNER_EGG, CoopSearch.NOWHERE)
	searcher._begin(config)
	assert_eq(searcher.level.wind, 0, "a move starts in calm air by default")
	config["wind_at"] = 285
	searcher._begin(config)
	assert_eq(searcher.level.wind, -112, "... or with the tailwind that begins 286 ticks into the loop (G79)")
	config["wind_at"] = 109
	searcher._begin(config)
	assert_eq(searcher.level.wind, 112)
	Sim.step(70)
	assert_eq(searcher.level.wind, 0, "and the script runs on from there (176: calm)")
	var names: PackedStringArray = PackedStringArray()
	for macro: Dictionary in searcher.macros:
		names.append(str(macro["name"]))
	assert_true(names.has("gust-jump 30"), "the gust jump: no direction held, then Up")
	searcher.close()
	var calm: CoopSearch.Searcher = _world(_level("calm_coop", "objects/x2_tablet 4 13 gate=g far=36,13"))
	assert_eq(calm._wind_phases, PackedInt32Array([0]), "no wind script: one phase")
	calm.close()


func test_bonds_and_drum_pairs_are_slot_bound_by_the_engine() -> void:
	var probe: Dictionary = CoopSearch.probe_bond()
	assert_true(bool(probe["bond"]), "G72: one hero's second hit does not meet a bond, another slot's does (%s)" % str(probe))
	assert_true(bool(probe["drums"]), "G72: the hero who lit one drum cannot light the last (%s)" % str(probe))
	var data: LevelData = _level("slot_coop", "\n".join(PackedStringArray([
		"objects/x2_tablet 4 13 gate=g far=36,13",
		"objects/drum 10 13 bond=d",
		"objects/drum 13 13 bond=d",
		"enemies/walker 20 13 coop=bond bond=e",
		"enemies/walker 23 13 coop=bond bond=e",
	])))
	var grid: TileGrid = CoopSearch.grid_at_rest(data, Defs.Difficulty.BEGINNER)
	var area: Rect2i = Rect2i(0, 0, 40, 16)
	assert_eq(CoopSearch.pair_solo_min(Vector2i(10, 13), Vector2i(13, 13), grid, area, null, "drums"),
			CoopSearch.PAIR_NEVER, "the solo minimum of a slot-bound pair is 'never' - from the rule, not from a run")
	assert_eq(CoopSearch.pair_solo_min(Vector2i(20, 13), Vector2i(23, 13), grid, area, null, "bond"),
			CoopSearch.PAIR_NEVER)
	assert_eq(CoopSearch.pair_solo_min(Vector2i(10, 13), Vector2i(13, 13), grid, area, null), 0,
			"the geometry alone: one throw line through both")
	assert_true(CoopSearch.two_throws_reach(grid, Vector2i(10, 13), Vector2i(13, 13)), "a spot to throw at both from")
	var bare: CoopSearch.Searcher = CoopSearch.Searcher.new()
	assert_true(bare.build(data.id, data.resolved_meta(Defs.Difficulty.BEGINNER), grid))
	var windows: Array = CoopSearch.measure_windows(data, Defs.Difficulty.BEGINNER, area, bare)
	bare.close()
	assert_eq(windows.size(), 2, str(windows))
	for window: Dictionary in windows:
		assert_true(bool(window.get("slot_bound", false)), "%s is slot-bound: exempt from the window cap" % str(window))
		assert_eq(int(window["solo_min"]), CoopSearch.PAIR_NEVER)


# =================================================================================================================
# The long climb, the new moves and probes
# =================================================================================================================

func test_a_hero_at_rest_on_a_vine_is_a_node_so_a_long_climb_is_searched() -> void:
	# A ledge 38 rows over the floor and a vine of 37 at its edge: 608 px of climb. The longest climb move is 240
	# ticks of Up (480 px), so the ledge is reached only when the hero hanging on the vine after it is a resting
	# point the search goes on from (G74 / R7: the warp stack of 7-1 fell to a 15-row vine the search never climbed).
	var data: LevelData = _level("climb_coop", "objects/x2_tablet 2 57 gate=g far=14,19\nobjects/vine 11 20 length=37",
			[[20, 12, 23, "#"]], 24, 60)
	var start: Vector2i = Vector2i(11 * 16 + 8, 58 * 16)
	var far: Vector2i = Vector2i(14, 19)
	var area: Rect2i = Rect2i(9, 0, 7, 60)   # (the vine's foot and the ledge's edge: the floor beyond is not searched)
	# The engine probes the search asks for build a world of their own: before this one, as search_data does.
	CoopSearch.idle_partner_carries()
	CoopSearch.idle_partner_weighs()
	var reached: Array = []
	for rests: bool in [true, false]:
		CoopSearch.climb_rests = rests
		var searcher: CoopSearch.Searcher = _world(data)
		var found: Dictionary = searcher.explore([start] as Array[Vector2i], {far: true}, area, CoopSearch.BOUND_TICKS, 60)
		reached.append(bool(found["reached"]))
		if rests:
			assert_true(str(found["detail"]).contains("climb"), "by a climb (%s)" % str(found["detail"]))
		searcher.close()
		await Engine.get_main_loop().process_frame
	CoopSearch.climb_rests = true
	assert_eq(reached, [true, false], "with a rest on the vine as a node the ledge is reached; without (the search before wf11) the climb is dropped")


func test_the_search_has_the_moves_of_the_explorer() -> void:
	var names: PackedStringArray = PackedStringArray()
	for macro: Dictionary in CoopSearch.make_macros(true):
		names.append(str(macro["name"]))
	for wanted: String in ["climb-long", "wait-up", "wait-long", "vine-leap R", "vine-leap L", "long-jump R",
			"long-jump L", "gust-jump 12", "low-hop-jump R"]:
		assert_true(names.has(wanted), "the macro '%s'" % wanted)
	for family: String in [CoopSearch.PROBE_RIDE, CoopSearch.PROBE_LURE, CoopSearch.PROBE_SPRING]:
		assert_true(CoopSearch.PROBE_FAMILIES.has(family), "the probe family '%s'" % family)
	# A follower far outside the gate's columns is in the search world (the lure), a walker out there is not.
	var data: LevelData = _level("lure_coop", "\n".join(PackedStringArray([
		"objects/x2_tablet 180 13 gate=g far=190,13",
		"objects/checkpoint 176 13",
		"enemies/hopper 10 13",
		"enemies/walker 12 13",
		"enemies/hopper 14 13 keeper=k",
		"objects/spring 184 13",
		"enemies/walker 186 13",
	])), [], 220, 16)
	var tablet: Dictionary = CoopSearch.find_tablet(data, Defs.Difficulty.BEGINNER, "g")
	var grid: TileGrid = CoopSearch.grid_at_rest(data, Defs.Difficulty.BEGINNER)
	var area: Rect2i = CoopSearch.gate_area(tablet, grid)
	var starts: Array[Vector2i] = CoopSearch.start_points(data, Defs.Difficulty.BEGINNER, tablet, grid)
	var columns: Vector2i = CoopSearch.world_columns_of(area, starts, grid)
	assert_true(columns.x > 20, "the gate's columns do not hold column 10 (%s)" % str(columns))
	var ids: PackedStringArray = PackedStringArray()
	for record: Dictionary in CoopSearch.world_record_list(data, Defs.Difficulty.BEGINNER, columns):
		ids.append("%s@%d" % [record["id"], int(record["col"])])
	assert_true(ids.has("enemies/hopper@10"), "the follower of the whole level is in the world (%s)" % str(ids))
	assert_false(ids.has("enemies/walker@12"), "a walker far away is not")
	assert_false(ids.has("enemies/hopper@14"), "nor a keeper (it is pinned: G66)")
	var searcher: CoopSearch.Searcher = CoopSearch.Searcher.new()
	assert_true(searcher.build_world(data, Defs.Difficulty.BEGINNER, grid, columns))
	var far: Vector2i = tablet["far"]
	assert_eq(searcher.lure_targets(far).size(), 0, "180 columns away: beyond the lure's reach (%d)" % CoopSearch.LURE_MAX_COLS)
	var targets: PackedStringArray = searcher.probe_targets(area, far)
	var kinds: Dictionary = {}
	for target: String in targets:
		kinds[target.substr(0, 1)] = true
	assert_true(kinds.has("s"), "the spring is a probe target (%s)" % str(targets))
	assert_true(kinds.has("b"), "every enemy of the area is a ride target, a plain walker too")
	var needs: Dictionary = searcher.probe_requirements(area, far)
	assert_eq((needs["required"][CoopSearch.PROBE_SPRING] as Array).size(), 1, "a bounded refusal needs the strike begun on it")
	assert_eq((needs["required"][CoopSearch.PROBE_RIDE] as Array).size(), 1)
	# The batteries: a strike begun on the spring, the ride.
	var pos: Vector2i = starts[0]
	for target: String in targets:
		var families: Dictionary = {}
		for item: Array in searcher.probe_battery(target, pos, far):
			families[(item[1] as CoopSearch.ProbePolicy).family] = true
		if target.begins_with("s"):
			assert_eq(families.keys(), [CoopSearch.PROBE_SPRING])
		elif target.begins_with("b"):
			assert_eq(families.keys(), [CoopSearch.PROBE_RIDE])
	searcher.close()
	# Within reach the lure is asked for, and it is a probe of the far cell's sites.
	var near: LevelData = _level("lure_near_coop", "objects/x2_tablet 60 13 gate=g far=70,13\nenemies/hopper 20 13", [],
			100, 16)
	var near_tablet: Dictionary = CoopSearch.find_tablet(near, Defs.Difficulty.BEGINNER, "g")
	var near_grid: TileGrid = CoopSearch.grid_at_rest(near, Defs.Difficulty.BEGINNER)
	var near_area: Rect2i = CoopSearch.gate_area(near_tablet, near_grid)
	var near_starts: Array[Vector2i] = CoopSearch.start_points(near, Defs.Difficulty.BEGINNER, near_tablet, near_grid)
	var world: CoopSearch.Searcher = CoopSearch.Searcher.new()
	assert_true(world.build_world(near, Defs.Difficulty.BEGINNER, near_grid, CoopSearch.world_columns_of(near_area,
			near_starts, near_grid)))
	assert_eq(world.lure_targets(near_tablet["far"]).size(), 1, "the hopper 50 columns from the far cell")
	assert_eq((world.probe_requirements(near_area, near_tablet["far"])["required"][CoopSearch.PROBE_LURE] as Array),
			["f"])
	var lured: int = 0
	for item: Array in world.probe_battery("f", near_starts[0], near_tablet["far"]):
		var policy: CoopSearch.ProbePolicy = item[1]
		if policy.family == CoopSearch.PROBE_LURE:
			lured += 1
			assert_eq(policy.ticks, CoopSearch.PROBE_LURE_TICKS, "a lure plays longer than a probe")
	assert_eq(lured, 2, "toward the far cell and straight up")
	# The lure itself: the hopper is fetched and comes along.
	var lure: CoopSearch.LurePolicy = null
	for item: Array in world.probe_battery("f", near_starts[0], near_tablet["far"]):
		if (item[1] as CoopSearch.ProbePolicy).family == CoopSearch.PROBE_LURE and lure == null:
			lure = item[1]
	var hopper: EnemyBase = world.entity_at(world.lure_targets(near_tablet["far"])[0]) as EnemyBase
	var home: int = hopper.sim_pos.x
	world.probe_run(world._config(near_starts[0], 1, -1, CoopSearch.PARTNER_EGG, CoopSearch.NOWHERE), lure,
			{near_tablet["far"]: true})
	assert_true(hopper.awake and hopper.sim_pos.x > home + 160, "the lure woke the hopper and led it %d px toward the gate"
			% (hopper.sim_pos.x - home))
	world.close()


func test_a_pair_gets_the_second_throw() -> void:
	# A wall with a drum door in it; the drums stand 8 cells apart on the floor before it.
	var wall: Array = []
	for row: int in range(2, 14):
		wall.append([row, 30, 30, "#"])
	var data: LevelData = _level("pair_coop", "\n".join(PackedStringArray([
		"objects/x2_tablet 4 13 gate=g far=36,13",
		"objects/drum 14 13 bond=d",
		"objects/drum 22 13 bond=d",
		"objects/column 30 13 size=1,4 rise=4 trigger=drums:d",
	])), wall)
	var searcher: CoopSearch.Searcher = _world(data)
	var far: Vector2i = Vector2i(36, 13)
	var drum: String = ""
	for target: String in searcher.probe_targets(Rect2i(0, 0, 40, 16), far):
		if target.begins_with("d") and drum == "":
			drum = target
	assert_ne(drum, "", "a drum is a probe target")
	var seconds: int = 0
	for item: Array in searcher.probe_battery(drum, Vector2i(8 * 16, 14 * 16), far):
		if item[1] is CoopSearch.PairPolicy:
			seconds += 1
			assert_eq((item[1] as CoopSearch.ProbePolicy).family, CoopSearch.PROBE_THROWN)
	assert_eq(seconds, CoopSearch.THROW_WEAPONS.size() * CoopSearch.PROBE_PAIR_DELAYS.size() * 3 * 2,
			"every special x every delay x (two throws, both in one jump, a throw and the club) x two spots")
	# One hero's two hits in flight no longer meet the drums (G72): every second-throw probe leaves the door shut.
	var opened: int = 0
	for item: Array in searcher.probe_battery(drum, Vector2i(8 * 16, 14 * 16), far):
		if not item[1] is CoopSearch.PairPolicy:
			continue
		var outcome: Dictionary = searcher.probe_run(item[0], item[1], {far: true})
		opened += 1 if outcome.has("goal") else 0
	assert_eq(opened, 0, "no second throw of one hero opens the drum door")
	searcher.close()


# =================================================================================================================
# tools/coop_explore: route files, kept results, the row's verdict
# =================================================================================================================

func test_route_files_seeds_and_keys_of_the_explore_tools() -> void:
	var harness: GDScript = load(HARNESS) as GDScript
	var flags: PackedInt32Array = PackedInt32Array([Defs.IN_RIGHT, Defs.IN_RIGHT, Defs.IN_RIGHT | Defs.IN_UP, 0, 0,
		Defs.IN_DOWN | Defs.IN_FIRE])
	assert_eq(harness.call(&"flags_text", flags), "2:R,1:RU,2:,1:DF")
	var text: String = harness.call(&"route_file_text", &"w1_l1_coop", "hop", 1, true, 1, [[2, "hand", 3]],
			harness.call(&"flags_text", flags))
	var path: String = "user://test_world_search_route.txt"
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()
	var route: Dictionary = harness.call(&"read_route", path)
	assert_eq(route["level"], &"w1_l1_coop")
	assert_eq(str(route["gate"]), "hop")
	assert_eq(int(route["difficulty"]), 1)
	assert_true(bool(route["whole"]))
	assert_false(bool(route["real"]))
	assert_eq(int(route["start"]), 1)
	assert_eq(route["events"], [[2, "hand", 3]])
	assert_eq(route["flags"], flags, "a route file round-trips")
	assert_eq(int(route["tick0"]), 0, "the clock base it was recorded on (the default of the text: 0)")
	# The G3b verifier's files say `tick0=-`: his world began on the fresh process's tick, 0. An explorer's find names
	# the base of its world, and the harness builds the world on it.
	for base: Array in [["-", 0], ["17952", 17952]]:
		file = FileAccess.open(path, FileAccess.WRITE)
		file.store_string(text.replace("tick0=0", "tick0=%s" % str(base[0])))
		file.close()
		assert_eq(int((harness.call(&"read_route", path) as Dictionary)["tick0"]), int(base[1]))
	var old_clock: RefCounted = harness.new()
	assert_true(old_clock.build_data(_busy_level("tick0_coop"), "g", Defs.Difficulty.BEGINNER, true, 0))
	old_clock.begin(old_clock.starts[0])
	assert_eq(Sim.tick, 0, "a route recorded on base 0 is replayed on base 0")
	old_clock.close()
	var own_clock: RefCounted = harness.new()
	assert_true(own_clock.build_data(_busy_level("tick1_coop"), "g", Defs.Difficulty.BEGINNER, true))
	own_clock.begin(own_clock.starts[0])
	assert_eq(Sim.tick, CoopSearch.TICK_BASE, "the search world's own base otherwise")
	# No level-start transient on that base: a geyser with a delay is in its cycle, not "idle before its delay", and
	# every cycle length the levels use stands where tick 0 would have it.
	assert_eq(Geyser.cycle_at(CoopSearch.TICK_BASE, 34, 17), Geyser.cycle_at(34 * 4, 34, 17))
	assert_ne(Geyser.cycle_at(CoopSearch.TICK_BASE, 34, 17), Geyser.cycle_at(0, 34, 17),
			"on tick 0 the second vent of 6-2b's 'vent' gate is idle: a window no hero at the gate ever has")
	for period: int in [34, 66, 88, 352]:
		assert_eq(CoopSearch.TICK_BASE % period, 0, "a multiple of the cycle length %d" % period)
	own_clock.close()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	assert_true((harness.call(&"read_route", "res://no/such/route.txt") as Dictionary).is_empty())
	# The evidence set: the verifier's 21 routes and the lead designer's two (G77 (b)); it only grows.
	var evidence: PackedStringArray = harness.call(&"evidence_files")
	assert_true(evidence.size() >= 23, "%d evidence routes" % evidence.size())
	for file_path: String in evidence:
		assert_false((harness.call(&"read_route", file_path) as Dictionary).is_empty(), "%s is a route file" % file_path)
	assert_eq((harness.call(&"evidence_files", &"w7_l1_coop", "dune", 1) as PackedStringArray).size(), 3,
			"the routes of one gate row (the real-game one among them)")
	# The two passes of a row have their own seeds, the same whatever the gate table looks like.
	var first: int = harness.call(&"row_seed", &"w7_l1_coop", 1, "dune", 0)
	var second: int = harness.call(&"row_seed", &"w7_l1_coop", 1, "dune", 1)
	assert_ne(first, second)
	assert_eq(first, int(harness.call(&"row_seed", &"w7_l1_coop", 1, "dune", 0)))
	assert_ne(first, int(harness.call(&"row_seed", &"w7_l1_coop", 0, "dune", 0)), "another row, another seed")
	# A kept result depends on the row, the seed and the seconds.
	var key: String = harness.call(&"explore_key", &"w7_l1_coop", 1, "dune", first, 300)
	assert_eq(key, str(harness.call(&"explore_key", &"w7_l1_coop", 1, "dune", first, 300)))
	assert_ne(key, str(harness.call(&"explore_key", &"w7_l1_coop", 1, "dune", second, 300)))
	assert_ne(key, str(harness.call(&"explore_key", &"w7_l1_coop", 1, "dune", first, 120)))
	assert_ne(key, str(harness.call(&"explore_key", &"w7_l1_coop", 0, "dune", first, 300)))


func test_a_gate_row_is_green_only_with_all_three_proofs() -> void:
	var gates: GDScript = load(GATES_TEST) as GDScript
	var refused: Dictionary = {"verdict": "refused (exhaustive)", "evidence": "exhaustive, 100 resting points"}
	var quiet: Dictionary = {"red": false, "open": false, "text": "2 of 2 evidence route(s) not reached"}
	var silent: Dictionary = {"red": false, "open": false, "text": "explorer pass 1 not reached, pass 2 not reached"}
	var green: Dictionary = gates.call(&"row_verdict", refused, quiet, silent)
	assert_eq(str(green["row"]), "GREEN")
	assert_eq(str(green["verdict"]), "refused (exhaustive)", "the search's verdict stands when the other two agree")
	# A replayable route is red whatever the search says.
	var route: Dictionary = {"red": true, "open": false, "text": "1 of 2; REACHED: x.txt"}
	var red: Dictionary = gates.call(&"row_verdict", refused, route, silent)
	assert_eq(str(red["verdict"]), "open")
	assert_eq(str(red["row"]), "RED")
	assert_true(str(red["evidence"]).contains("x.txt"), "the row names the route file")
	var found: Dictionary = {"red": true, "open": false, "text": "explorer pass 2 REACHED the far cell in 386 ticks"}
	assert_eq(str(gates.call(&"row_verdict", refused, quiet, found)["verdict"]), "open")
	assert_eq(str(gates.call(&"row_verdict", {"verdict": "open", "evidence": "a probe"}, quiet, silent)["verdict"]),
			"open")
	# A proof that did not run is open work, never green - and never hides a red one.
	var not_run: Dictionary = {"red": false, "open": true, "text": "explorer pass 1 NOT RUN, pass 2 NOT RUN"}
	var work: Dictionary = gates.call(&"row_verdict", refused, quiet, not_run)
	assert_eq(str(work["verdict"]), "unproven")
	assert_eq(str(work["row"]), "OPEN WORK")
	assert_eq(str(gates.call(&"row_verdict", refused, route, not_run)["verdict"]), "open")
	assert_eq(str(gates.call(&"row_verdict", {"verdict": "unproven", "evidence": "bounded"}, quiet, silent)["verdict"]),
			"unproven")
