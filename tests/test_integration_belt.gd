extends RouteTestCase
## The belt-invariance runner, live, and the header-route harness on a Book II file and its co-op file (owner:
## integration; docs/expansion/PLAN.md P1.3 and 8 V2.b, PHYSICS.md C.2 rule 5, LEVEL_DESIGN.md 15.6, 15.7.1, 15.9).
##
## Nothing in the simulation reads the belt except Swap, so a club route that never presses `S` replays to the same
## per-tick digests whatever special rides on the belt, and the digest leaves the belt out. Proven here on the Book II
## test bed levels/test_integration_book2.lvl (`book = 2`: the fresh-club belt rule) and its co-op file
## levels/test_integration_book2_coop.lvl with their header routes in tests/fixtures/book2_routes/ - a solo club route
## through Flow to its tally, and a two-stream co-op route into the exit and the tally (the harness end to end for the
## G1 slice's files: w5_l1, w5_l1_coop, w1_l1_coop) - and from the command line by the bench:
##   bash .tools/gd.sh script res://scripts/core/dev/sim_bench.gd -- --belt-invariance \
##       --route-dir=res://tests/fixtures/book2_routes/
## tests/test_book2_routes.gd and tests/test_coop_routes.gd run the same proof on every Book II and co-op route.

const BOOK2_DIR: String = "res://tests/fixtures/book2_routes/"
const SOLO: String = "test_integration_book2.inputs"
const COOP: String = "test_integration_book2_coop.inputs"
const LEVEL: StringName = &"test_integration_book2"
const COOP_LEVEL: StringName = &"test_integration_book2_coop"
const SCRATCH: String = "res://build/test_integration_belt/"


func _routes() -> Dictionary:
	return header_table(BOOK2_DIR, func(_file: String, _spec: Dictionary) -> bool: return true)


func test_the_test_bed_is_a_book2_file_outside_every_campaign() -> void:
	assert_true(Levels.has_level(LEVEL))
	assert_eq(Levels.get_book(LEVEL), Levels.BOOK_2)
	assert_eq(Levels.get_level_kind(LEVEL), Levels.KIND_TEST)
	assert_eq(Levels.get_belt_rule(LEVEL), LevelText.BELT_FRESH, "Book II: the fresh-club rule")
	assert_true(Levels.is_solo_level(LEVEL))
	for difficulty: int in [Defs.Difficulty.BEGINNER, Defs.Difficulty.EXPERT]:
		assert_false(Levels.get_campaign(difficulty, Levels.BOOK_2).has(LEVEL), "no map stop")
	assert_eq(_validator_problems(LEVEL), PackedStringArray(), "no error and no warning")
	var table: Dictionary = _routes()
	assert_eq(table.keys(), [SOLO, COOP])
	assert_eq(header_problems(table), PackedStringArray())
	assert_eq([table[SOLO]["players"], table[COOP]["players"]], [1, 2])


## The test bed's co-op file (LEVEL_DESIGN.md 15.7.1): the co-op version of the solo file, in its book, without codes,
## never in a campaign; Flow plays it for the solo level in a co-op run.
func test_the_test_bed_has_a_coop_file() -> void:
	assert_true(Levels.is_coop_level(COOP_LEVEL))
	assert_eq(Levels.get_coop_base(COOP_LEVEL), LEVEL)
	assert_eq(Levels.get_coop_level(LEVEL), COOP_LEVEL)
	assert_eq(Levels.get_book(COOP_LEVEL), Levels.BOOK_2)
	assert_eq(Levels.get_belt_rule(COOP_LEVEL), LevelText.BELT_FRESH)
	assert_eq(Levels.level_for_mode(LEVEL, Defs.GameMode.COOP), COOP_LEVEL)
	assert_eq(Levels.level_for_mode(COOP_LEVEL, Defs.GameMode.SINGLE), LEVEL)
	for difficulty: int in [Defs.Difficulty.BEGINNER, Defs.Difficulty.EXPERT]:
		assert_eq(Levels.get_password(COOP_LEVEL, difficulty), "")
		assert_false(Levels.get_coop_campaign(difficulty, Levels.BOOK_2).has(COOP_LEVEL), "no co-op map stop")
	var text: String = FileAccess.get_file_as_string(Levels.get_level_path(LEVEL)).replace("\r\n", "\n")
	assert_eq(str(Levels.get_value(COOP_LEVEL, "coop_base_hash", "")), text.sha256_text(),
			"coop_base_hash is the sha256 of the solo file (LF line ends): update it with the solo file")
	assert_eq(_validator_problems(COOP_LEVEL), PackedStringArray(), "no error and no warning")


## The routes play as their headers say - the solo one and the co-op one through Flow into the exit and the tally -
## every slot reading its stream.
func test_the_test_bed_routes_play_as_their_headers_say() -> void:
	var table: Dictionary = _routes()
	for file: String in [SOLO, COOP]:
		for mode: String in table[file]["modes"]:
			var result: Dictionary = await play_header_route(file, mode, table)
			assert_eq(int(result.get("input_mismatches", -1)), 0, "%s (%s): every slot read its stream" % [file, mode])
			assert_true(int(result.get("input_ticks", 0)) > 150, "%s (%s) played" % [file, mode])
			assert_eq(StringName(result.get("level_id", &"")), StringName(str(table[file]["level"])),
					"%s (%s): the stage of its header" % [file, mode])


## The digest of a tick leaves every hero's belt out and keeps the hand (PHYSICS.md C.2 rule 5): one hero and a party
## of two (the first 120 ticks of each route, the stage still running).
func test_the_digest_leaves_the_belt_out() -> void:
	var table: Dictionary = _routes()
	table.merge(_partial_routes(table, 120))
	for file: String in ["part_" + SOLO, "part_" + COOP]:
		var result: Dictionary = await runner().replay(file, BEGINNER, {"routes": table, "keep": true, "chain": false})
		assert_eq(Flow.current_screen, Flow.SCREEN_LEVEL, "%s: the stage still runs" % file)
		var level: LevelBase = Game.level
		assert_not_null(level, "%s: a stage to digest" % file)
		if level == null:
			continue
		assert_eq(level.hero_count(), int(table[file]["players"]))
		var base: String = runner().digest_line(level)
		for slot: int in Game.party:
			for special: int in [Defs.Weapon.HAMMER, Defs.Weapon.AXE, Defs.Weapon.BOOMERANG, Defs.Weapon.SPEAR,
					Defs.Weapon.CLUB, PlayerRun.BELT_EMPTY]:
				Game.runs[slot].set_belt(special)
				assert_eq(runner().digest_line(level), base, "%s: P%d's belt %d is not digested" % [file, slot + 1,
						special])
			Game.runs[slot].set_belt(PlayerRun.BELT_EMPTY)
		for slot: int in Game.party:
			var hand: int = Game.runs[slot].weapon
			Game.runs[slot].set_weapon(Defs.Weapon.SPEAR)
			assert_ne(runner().digest_line(level), base, "%s: P%d's hand is digested" % [file, slot + 1])
			Game.runs[slot].set_weapon(hand)
		assert_eq(runner().digest_line(level), base)
		assert_true(result.has("lines"))
		clean_up_route()


## The runner replays each route with an empty belt and then each special on every hero's belt (the belt really
## rides along on every tick), and the digests are identical.
func test_the_test_bed_routes_are_belt_invariant() -> void:
	var table: Dictionary = _routes()
	for file: String in [SOLO, COOP]:
		for mode: String in table[file]["modes"]:
			var seen: Array[int] = []
			var watch: Callable = func(_level: LevelBase, _tick: int) -> void:
				var belt: int = Game.runs[0].belt
				for slot: int in range(1, Game.party):
					if Game.runs[slot].belt != belt:
						belt = -99
				if seen.is_empty() or seen[seen.size() - 1] != belt:
					seen.append(belt)
			var result: Dictionary = await runner().belt_invariance(file, mode, table, {"on_tick": watch})
			clean_up_route()
			assert_true(bool(result["ok"]), "%s (%s): %s" % [file, mode, str(result["differences"])])
			assert_true(int(result["ticks"]) > 150, "%s (%s): %d digest lines" % [file, mode, result["ticks"]])
			assert_eq(seen, [PlayerRun.BELT_EMPTY, Defs.Weapon.HAMMER, Defs.Weapon.AXE, Defs.Weapon.BOOMERANG,
					Defs.Weapon.SPEAR] as Array[int], "%s (%s): every hero carried each belt through every tick" % [
					file, mode])


## The proof fails when the belt reaches the simulation: a hook that moves the hero by one pixel while he carries
## the spear (the spear only) is caught at that tick, for that special.
func test_a_belt_that_reaches_the_simulation_is_caught() -> void:
	var table: Dictionary = _routes()
	var nudge: Callable = func(level: LevelBase, stage_tick: int) -> void:
		if stage_tick == 100 and level.player != null and Game.runs[0].belt == Defs.Weapon.SPEAR:
			level.player.sim_pos.y -= 1
	var caught: Dictionary = await runner().belt_invariance(SOLO, EXPERT, table, {"on_tick": nudge})
	clean_up_route()
	assert_false(caught["ok"])
	var differences: PackedStringArray = caught["differences"]
	assert_eq(differences.size(), 1, str(differences))
	assert_true(differences.size() == 1 and differences[0].begins_with("spear: line 101:"), str(differences))


## The idle check of the route proofs (RouteTestCase._check_party_idle; docs/LEVEL_DESIGN.md 15.7.9, the 'since first
## input' form): a hero of a two-stream route whose own slot gives no input for PlayerBase.IDLE_TICKS ticks is reported
## - the one who played and then stood still, and the one who never touched a key - with the tick it happens on; a hero
## who holds Down (a held key is input on every tick, G58) or taps a key in time is not. P1 walks into the left wall
## all the while; the stage keeps running.
func test_a_hero_who_stands_idle_on_a_coop_route_is_caught() -> void:
	var limit: int = PlayerBase.IDLE_TICKS
	assert_eq(limit, PartyTuning.IDLE_TICKS, "the rule's 243 ticks")
	var quiet: String = "P2 is idle on tick %d: %d ticks without input of his own "
	var cases: Array[Array] = [
		["idle_after_input", "1:L|L,%d:L|" % (limit + 40), quiet % [limit + 1, limit] + "since his last one"],
		["idle_from_the_start", "%d:L|" % (limit + 40), quiet % [limit, limit] + "since the stage began"],
		["crouching", "1:L|L,%d:L|D" % (limit + 40), ""],
		["tapping", "1:L|L,%d:L|,1:L|D,%d:L|" % [limit - 1, limit - 1], ""],
	]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SCRATCH))
	for case: Array in cases:
		var out: FileAccess = FileAccess.open(SCRATCH + "%s.inputs" % case[0], FileAccess.WRITE)
		out.store_string("# route: level=%s difficulty=beginner players=2 ends=none\n%s\n" % [COOP_LEVEL, case[1]])
		out.close()
	var table: Dictionary = header_table(SCRATCH, func(file: String, _spec: Dictionary) -> bool:
		return cases.any(func(case: Array) -> bool: return file == "%s.inputs" % case[0]))
	assert_eq(table.size(), cases.size())
	assert_eq(header_problems(table), PackedStringArray())
	for case: Array in cases:
		var file: String = "%s.inputs" % case[0]
		_watch_events()
		_reset_watch(COOP_LEVEL, BEGINNER)
		var result: Dictionary = await runner().replay(file, BEGINNER, {"routes": table, "on_tick": _on_tick,
				"keep": true, "chain": false})
		assert_true(stage_ticks(result.get("lines", PackedStringArray())) >= limit, "%s played" % file)
		assert_eq(Flow.current_screen, Flow.SCREEN_LEVEL, "%s: the stage still runs" % file)
		assert_eq(_count(&"hero_hurt") + _count(&"hero_down"), 0, "%s: nobody is hurt meanwhile" % file)
		if str(case[2]) == "":
			assert_eq(idle_verdict(), "", "%s: nobody is idle" % file)
		else:
			assert_true(idle_verdict().begins_with(str(case[2])), "%s: %s" % [file, idle_verdict()])
		clean_up_route()


# The first `ticks` ticks of every route of `table` as header routes that end nowhere (`part_<file>`, written under
# SCRATCH): the stage still runs after them.
func _partial_routes(table: Dictionary, ticks: int) -> Dictionary:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SCRATCH))
	for file: String in table:
		var spec: Dictionary = table[file]
		var streams: Array[PackedInt32Array] = Autoplay.parse_inputs_multi(FileAccess.get_file_as_string(BOOK2_DIR + file))
		for slot: int in streams.size():
			streams[slot] = streams[slot].slice(0, ticks)
		var out: FileAccess = FileAccess.open(SCRATCH + "part_" + file, FileAccess.WRITE)
		out.store_string(Autoplay.format_inputs(streams, PackedStringArray([
			"# route: level=%s difficulty=beginner players=%d ends=none" % [spec["level"], spec["players"]]])))
		out.close()
	return header_table(SCRATCH, func(file: String, _spec: Dictionary) -> bool: return file.begins_with("part_"))


# The validator's problems (errors and warnings) of one level, checked with the whole folder.
func _validator_problems(level_id: StringName) -> PackedStringArray:
	var validator: LevelValidator = folder_validator()
	var lines: PackedStringArray = PackedStringArray()
	for problem: Dictionary in validator.problems_of(Levels.get_level_path(level_id)):
		lines.append(LevelValidator.format_problem(problem))
	return lines
