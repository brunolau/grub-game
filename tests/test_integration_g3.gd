extends RouteTestCase
## Gate G3 bookkeeping (owner: integration; docs/expansion/PLAN.md 6.2 "Gate G3": 20 Book II files + 35 co-op files +
## 10 arenas; 31 solo club routes, about 6 featured routes, 57 two-stream co-op routes, belt invariance on all, every x2
## gate refused by the search, every (arena, mode) bot test green).
##
## The content half of the G3 table, read from the tree: which files of the design exist, which (stage, difficulty)
## cells have their route, the featured routes, the paintings with a route (V2.c), the x2 gates of every co-op file
## (at least two per main stage, PLAN.md 9 "never cut"), the arenas and their bot graphs. It prints one `G3 |` line per
## row (tools/g3.sh puts them beside the verdicts of the slow modules it runs) and passes while phase 3 is under way;
## with the environment variable G3_REQUIRE=1 every row must be complete (tools/g3.sh --require, at the gate).
## The proofs themselves are the slow modules: test_book2_routes (V2.a-c), test_coop_routes (V3.a-b), test_coop_gates
## (V3.c), test_versus_bots (V4.b), test_campaign_routes (Book I) - tools/g3.sh runs them all.

## The arenas of DESIGN.md E.5 in table order: the first eight ship at launch, Mesa Rodeo and Cloud Top are the
## painting unlocks (cut 3 of PLAN.md 9: built only after the eight are green).
const ARENAS: Array[StringName] = [&"arena_totem_ring", &"arena_echo_hollow", &"arena_floe_rink", &"arena_cinder_pit",
	&"arena_tar_pulleys", &"arena_coconut_cove", &"arena_sky_picnic", &"arena_colossus_hall", &"arena_mesa_rodeo",
	&"arena_cloud_top"]
const LAUNCH_ARENAS: int = 8
const BOT_GRAPH_DIR: String = "res://resources/bots/"
## About six featured routes at G3 (PLAN.md 6.2): routes of Book II stages that are not club routes.
const FEATURED_WANTED: int = 6
## Book II's paintings (DESIGN.md C.9: one per Book II level, indices 0..19).
const BOOK2_PAINTINGS: int = 20
## A co-op file of a main stage has at least this many x2 gates per difficulty (PLAN.md 9, never cut).
const MIN_GATES_MAIN: int = 2


func test_g3_inventory() -> void:
	var require: bool = OS.get_environment("G3_REQUIRE") == "1"
	var rows: Array[Array] = []
	var table: Dictionary = header_table(ROUTE_DIR, func(_file: String, spec: Dictionary) -> bool:
		return (spec["errors"] as PackedStringArray).is_empty())
	rows.append(_files_row("book2_files", DESIGN_FILES[2], ""))
	var coop_wanted: Array = (DESIGN_FILES[1] as Array) + (DESIGN_FILES[2] as Array)
	rows.append(_files_row("coop_files", coop_wanted, "_coop"))
	rows.append(_cells_row("solo_cells", table, DESIGN_FILES[2], "", 1))
	rows.append(_cells_row("coop_cells", table, coop_wanted, "_coop", 2))
	rows.append(_featured_row(table))
	rows.append(_paintings_row(table))
	rows.append(_gates_row())
	rows.append(_arenas_row())
	rows.append(_versus_cells_row())
	print("    G3 | row | have | want | state | detail")
	for row: Array in rows:
		print("    G3 | %s | %d | %d | %s | %s" % [row[0], row[1], row[2], "complete" if row[3] else "open", row[4]])
		if require:
			assert_true(row[3], "G3 %s: %d of %d - %s" % [row[0], row[1], row[2], row[4]])
	assert_eq(rows.size(), 9, "every G3 content row was counted")


## Files of the design that exist (`suffix` "_coop": their co-op files).
func _files_row(row: String, wanted: Array, suffix: String) -> Array:
	var missing: PackedStringArray = PackedStringArray()
	for level_id: StringName in wanted:
		if not Levels.has_level(StringName(String(level_id) + suffix)):
			missing.append(String(level_id) + suffix)
	var have: int = wanted.size() - missing.size()
	return [row, have, wanted.size(), missing.is_empty(), "missing: " + ", ".join(missing) if not missing.is_empty() else "all"]


## (file, difficulty) cells of the design with exactly one stage-ending route of `players` (Book II solo: the club
## route of V2.a; co-op: the two-stream route of V3.a). A file that does not exist yet counts its design cells as open.
func _cells_row(row: String, table: Dictionary, wanted: Array, suffix: String, players: int) -> Array:
	var cells: int = 0
	var have: int = 0
	var open: PackedStringArray = PackedStringArray()
	for base: StringName in wanted:
		var level_id: StringName = StringName(String(base) + suffix)
		for mode: String in [BEGINNER, EXPERT] if not DESIGN_EXPERT_ONLY.has(base) else [EXPERT]:
			cells += 1
			var file: String = campaign_route(table, level_id, mode, {})
			if file != "" and int(table[file].get("players", 1)) == players:
				have += 1
			else:
				open.append("%s%s" % [level_id, "" if mode == BEGINNER or DESIGN_EXPERT_ONLY.has(base) else " (E)"])
	return [row, have, cells, open.is_empty(), "open: " + ", ".join(open) if not open.is_empty() else "all"]


## Featured routes (PLAN.md 6.2 recipe step 3): header routes of Book II solo stages that are not their club routes.
func _featured_row(table: Dictionary) -> Array:
	var featured: PackedStringArray = PackedStringArray()
	for file: String in table:
		var level_id: StringName = StringName(str(table[file]["level"]))
		if Levels.get_book(level_id) != Levels.BOOK_2 or not Levels.is_solo_level(level_id) \
				or Levels.get_level_kind(level_id) == Levels.KIND_TEST:
			continue
		if file != "%s.inputs" % level_id and file != "%s.expert.inputs" % level_id:
			featured.append(file)
	return ["featured", featured.size(), FEATURED_WANTED, featured.size() >= FEATURED_WANTED, ", ".join(featured)]


## Book II's paintings 0..19: each collected by some Book II solo route (`expect=painting:<n>`, V2.c).
func _paintings_row(table: Dictionary) -> Array:
	var named: Dictionary = {}
	for file: String in table:
		var expect: Dictionary = table[file].get("expect", {})
		var level_id: StringName = StringName(str(table[file]["level"]))
		if expect.has("painting") and Levels.get_book(level_id) == Levels.BOOK_2 and Levels.is_solo_level(level_id):
			named[int(expect["painting"])] = file
	var open: PackedStringArray = PackedStringArray()
	for index: int in BOOK2_PAINTINGS:
		if not named.has(index):
			open.append(str(index))
	return ["paintings", BOOK2_PAINTINGS - open.size(), BOOK2_PAINTINGS, open.is_empty(),
		"without a route: " + ", ".join(open) if not open.is_empty() else "all"]


## The x2 gates of every co-op file per difficulty (the table test_coop_gates searches) and the main stages' co-op files
## with fewer than MIN_GATES_MAIN of them on a difficulty. Complete when every co-op file of the design exists and no
## main stage is short.
func _gates_row() -> Array:
	var gates: int = 0
	var short: PackedStringArray = PackedStringArray()
	var files: int = 0
	# G49: a boss stage's co-op form is its gate (the visor Colossus's chain plates need no tablet).
	var boss_forms: PackedStringArray = PackedStringArray()
	for level_id: StringName in Levels.all_ids():
		if not Levels.is_coop_level(level_id) or Levels.get_level_kind(Levels.get_coop_base(level_id)) == Levels.KIND_TEST:
			continue
		files += 1
		var data: LevelData = LevelData.load_file(Levels.get_level_path(level_id))
		if data == null:
			continue
		if data.entity_records().any(func(record: Dictionary) -> bool:
				return str(record["id"]).begins_with("bosses/")):
			boss_forms.append(String(level_id))
		for difficulty: int in [Defs.Difficulty.BEGINNER, Defs.Difficulty.EXPERT]:
			if not Levels.is_available(level_id, difficulty):
				continue
			var count: int = 0
			for record: Dictionary in data.entity_records():
				var params: Dictionary = record["params"]
				if StringName(str(record["id"])) == TABLET_ID and params.has("gate") \
						and LevelText.applies_to(params, difficulty):
					count += 1
			gates += count
			var main: bool = Levels.get_level_kind(Levels.get_coop_base(level_id)) == Levels.KIND_MAIN
			if main and count < MIN_GATES_MAIN:
				short.append("%s (%s): %d" % [level_id, Defs.difficulty_name(difficulty), count])
	var complete: bool = short.is_empty() and design_complete(Levels.BOOK_1, true) and design_complete(Levels.BOOK_2, true)
	var detail: String = "%d co-op file(s); main stages under %d gates: %s" % [files, MIN_GATES_MAIN,
		", ".join(short) if not short.is_empty() else "none"]
	detail += "; boss stages gated by their co-op form (G49): %s" % (", ".join(boss_forms) if not boss_forms.is_empty()
		else "none")
	return ["x2_gates", gates, gates, complete, detail]


## The arenas of DESIGN.md E.5 that exist, each with its bot graph (resources/bots/<id>.json); complete with the eight
## launch arenas (the two unlockables follow only after them, cut 3).
func _arenas_row() -> Array:
	var have: int = 0
	var notes: PackedStringArray = PackedStringArray()
	var launch_ok: bool = true
	for i: int in ARENAS.size():
		var arena: StringName = ARENAS[i]
		var exists: bool = Levels.is_arena(arena)
		var graph: bool = FileAccess.file_exists(BOT_GRAPH_DIR + String(arena) + ".json")
		if exists:
			have += 1
		if not exists or not graph:
			notes.append("%s%s" % [arena, " (no bot graph)" if exists else (" (unlockable)" if i >= LAUNCH_ARENAS else "")])
			launch_ok = launch_ok and i >= LAUNCH_ARENAS
	return ["arenas", have, ARENAS.size(), launch_ok, "launch %d; missing: %s" % [LAUNCH_ARENAS,
		", ".join(notes) if not notes.is_empty() else "none"]]


## The (arena, mode) cells of the arenas in levels/ (meta `modes`), and the human-only ones of cut 4 (G50: meta
## `bots = <mode list> | none`, default every mode of `modes`; a mode left out has no CPU seat and no bot test). The
## G3 table lists a human-only cell as "human-only (cut 4)", neither green nor red (tools/g3.sh reads the detail). The
## row is a count, complete by itself: the bot proof of every other cell is test_versus_bots (V4.b).
func _versus_cells_row() -> Array:
	var cells: int = 0
	var bot_cells: int = 0
	var human: PackedStringArray = PackedStringArray()
	for arena: StringName in Levels.get_arenas():
		var modes: PackedStringArray = arena_modes(arena)
		var bots: PackedStringArray = arena_bot_modes(arena)
		for mode: String in modes:
			cells += 1
			if bots.has(mode):
				bot_cells += 1
			else:
				human.append("%s/%s" % [arena, mode])
	return ["versus_cells", bot_cells, cells, true, "human-only (cut 4): %s" % (", ".join(human) if not human.is_empty()
		else "none")]


## The versus modes arena `arena` offers (meta `modes`).
static func arena_modes(arena: StringName) -> PackedStringArray:
	return _mode_list(str(Levels.get_value(arena, "modes", "")))


## The modes of `arena` the bots play (G50: meta `bots`, a mode list or `none`; default every mode of `modes`).
static func arena_bot_modes(arena: StringName) -> PackedStringArray:
	var modes: PackedStringArray = arena_modes(arena)
	var bots: Variant = Levels.get_value(arena, "bots", null)
	if bots == null or str(bots).strip_edges() == "":
		return modes
	var listed: PackedStringArray = _mode_list(str(bots))
	var result: PackedStringArray = PackedStringArray()
	for mode: String in modes:
		if listed.has(mode):
			result.append(mode)
	return result


static func _mode_list(text: String) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for item: String in text.replace(" ", "").split(",", false):
		if item != "none":
			result.append(item)
	return result


## G50's switch as the inventory reads it: no key = bots in every mode; a list keeps those modes; `none` keeps none.
func test_the_human_only_switch_reads_the_arena_meta() -> void:
	assert_eq(_mode_list("grub_stack, last_caveman"), PackedStringArray(["grub_stack", "last_caveman"]))
	assert_eq(_mode_list("none"), PackedStringArray())
	for arena: StringName in Levels.get_arenas():
		var modes: PackedStringArray = arena_modes(arena)
		assert_false(modes.is_empty(), "%s lists its modes" % arena)
		for mode: String in arena_bot_modes(arena):
			assert_true(modes.has(mode), "%s: a bot mode is one of its modes" % arena)
		if Levels.get_value(arena, "bots", null) == null:
			assert_eq(arena_bot_modes(arena), modes, "%s: no `bots` key - bots in every mode" % arena)


## The design lists the counts and the campaign runs use (RouteTestCase.DESIGN_FILES / DESIGN_EXPERT_ONLY) agree with
## every file that has landed: its book, and Expert-only exactly when the registry offers it on Expert alone. A
## campaign run that passes over a stop whose file is missing reports it (design_missing) instead of passing quietly.
func test_the_design_lists_match_the_landed_files() -> void:
	var checked: int = 0
	for book: int in DESIGN_FILES:
		for level_id: StringName in DESIGN_FILES[book]:
			if not Levels.has_level(level_id):
				continue
			checked += 1
			assert_eq(Levels.get_book(level_id), book, "%s is a Book %d file" % [level_id, book])
			assert_true(Levels.is_available(level_id, Defs.Difficulty.EXPERT), "%s is played on Expert" % level_id)
			assert_eq(DESIGN_EXPERT_ONLY.has(level_id), not Levels.is_available(level_id, Defs.Difficulty.BEGINNER),
					"%s: Expert-only in the design list exactly when the file says so" % level_id)
	assert_true(checked >= 15, "the 15 Book I files at least (%d)" % checked)
	# Book I solo is complete: no Book I stop is ever passed over; Feast Lands are side trips, never listed.
	assert_eq(design_missing(Levels.BOOK_1, false, Defs.Difficulty.EXPERT), PackedStringArray(), "Book I solo")
	for book: int in DESIGN_FILES:
		for coop: bool in [false, true]:
			for difficulty: int in [Defs.Difficulty.BEGINNER, Defs.Difficulty.EXPERT]:
				for missing: String in design_missing(book, coop, difficulty):
					assert_false(missing.begins_with("bonus_"), "%s is a side trip, not a stop" % missing)
					assert_false(Levels.has_level(StringName(missing)), "%s is really missing" % missing)
					if difficulty == Defs.Difficulty.BEGINNER:
						assert_false(DESIGN_EXPERT_ONLY.has(StringName(missing.trim_suffix("_coop"))),
								"%s is no Beginner stop" % missing)


## tools/g3.sh is the gate's one command: it runs every slow module of tests/run_tests.gd SLOW_FILES (coop_gates
## sharded), the default suite, sp_identity, the inventory and every campaign flow - a slow module added to the runner
## and forgotten here would leave the G3 table silently short.
func test_the_g3_command_runs_every_slow_module() -> void:
	var text: String = FileAccess.get_file_as_string("res://tools/g3.sh")
	assert_false(text.is_empty(), "tools/g3.sh exists")
	var slow: PackedStringArray = (load("res://tests/run_tests.gd") as GDScript).get_script_constant_map()["SLOW_FILES"]
	assert_true(slow.size() >= 5, "the runner's slow modules")
	for file: String in slow:
		var module: String = file.get_basename().trim_prefix("test_")
		assert_true(text.contains("test %s\"" % module) or text.contains("test %s " % module) \
				or text.contains("test %s\n" % module), "tools/g3.sh runs the slow module %s" % module)
	assert_true(text.contains("COOP_GATES_SHARD=$i/$SHARDS"), "coop_gates runs sharded")
	# A co-op file landing mid-run shifts the shard partition (seen 03:42-04:10: shards on 28 and 29 gates, 26 searched,
	# yet 29 "refused" lines): gates are counted once by name, and shards on different tables are no proof.
	assert_true(text.contains("the gate table changed during the run"), "a shifted gate table is reported")
	assert_true(text.contains("sort -u | wc -l"), "gates are counted once by name")
	# G50: human-only (arena, mode) cells are neither green nor red.
	assert_true(text.contains("human-only (cut 4)"), "the G3 table lists human-only cells")
	assert_true(text.contains("tools/sp_identity.sh"), "the single-player identity check (V1)")
	assert_true(text.contains("test integration_g3"), "the content inventory")
	for flow: String in ["campaign", "campaign_beginner", "campaign_b2", "campaign_coop"]:
		assert_true(FileAccess.file_exists("res://tools/autoplay/%s.flow" % flow), "%s.flow exists" % flow)
		assert_true(text.contains(flow), "tools/g3.sh plays %s.flow headless" % flow)
