extends RouteTestCase
## The route harness of 2.0 (owner: integration; docs/expansion/PLAN.md P0.9, TECH_AUDIT.md 4.11, LEVEL_DESIGN.md
## 15.9): several input streams in one script (Autoplay.parse_inputs_multi, TestCase.run_party_inputs), route
## headers (Autoplay.parse_route_header), writing scripts back (Autoplay.format_inputs), the recorder of `--record`,
## header routes replayed through the bench (sim_bench_runner replay / header_routes), the belt-invariance runner and
## the determinism checks of party routes. The fixture routes in tests/fixtures/routes/ play the bare two-hero level
## levels/test_core_party.lvl.

const FIXTURE_DIR: String = "res://tests/fixtures/routes/"
const PARTY_ROUTE: String = "test_core_party.inputs"
const SOLO_ROUTE: String = "test_core_party.solo.inputs"
const OUT_DIR: String = "res://build/test_integration_harness/"
const PARTY_LEVEL: StringName = &"test_core_party"


func _fixtures() -> Dictionary:
	return header_table(FIXTURE_DIR, func(_file: String, _spec: Dictionary) -> bool: return true)


func _write(path: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path).get_base_dir())
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


# =================================================================================================================
# Several streams in one script
# =================================================================================================================

func test_a_script_with_bars_has_one_stream_per_player() -> void:
	var streams: Array[PackedInt32Array] = Autoplay.parse_inputs_multi("8:R|R,10:RU|,4:DF|DF")
	assert_eq(streams.size(), 2)
	var r: int = Defs.IN_RIGHT
	var ru: int = Defs.IN_RIGHT | Defs.IN_UP
	var df: int = Defs.IN_DOWN | Defs.IN_FIRE
	var p1: PackedInt32Array = GameInput.expand_runs([[8, "R"], [10, "RU"], [4, "DF"]])
	var p2: PackedInt32Array = GameInput.expand_runs([[8, "R"], [10, ""], [4, "DF"]])
	assert_eq(streams[0], p1, "P1: the first part of every entry")
	assert_eq(streams[1], p2, "P2: the second part; an empty part is idle")
	assert_eq([streams[0][8], streams[1][8], streams[0][20], streams[1][21]], [ru, 0, df, df])
	assert_eq(r, streams[1][0])
	# A missing part is idle too, spaces and new lines separate entries, `#` lines are comments, S is swap.
	var more: Array[PackedInt32Array] = Autoplay.parse_inputs_multi("# two players\n3:|L ,\n2:S\n1: K | DS ")
	assert_eq(more.size(), 2)
	assert_eq(more[0], PackedInt32Array([0, 0, 0, Defs.IN_SWAP, Defs.IN_SWAP, Defs.IN_LOOK]))
	assert_eq(more[1], PackedInt32Array([Defs.IN_LEFT, Defs.IN_LEFT, Defs.IN_LEFT, 0, 0,
		Defs.IN_DOWN | Defs.IN_SWAP]))
	assert_eq(Autoplay.parse_inputs_multi("5:|")[1].size(), 5, "an idle entry for both")


func test_the_players_header_names_the_streams() -> void:
	var header: String = "# route: level=test_core_party difficulty=beginner players=3 ends=none\n"
	var three: Array[PackedInt32Array] = Autoplay.parse_inputs_multi(header + "4:R|L")
	assert_eq(three.size(), 3, "players=3: three streams")
	assert_eq(three[2], PackedInt32Array([0, 0, 0, 0]), "P3 idles through the whole script")
	assert_eq(Autoplay.parse_inputs_multi(header + "2:R").size(), 3, "even without a bar")
	assert_eq(Autoplay.input_players("# players: 2   weapon: club\n6:R"), 2, "the TECH_AUDIT 4.11 comment form")
	assert_eq(Autoplay.input_players("6:R,2:L|U|D"), 3, "else the most parts of an entry")
	assert_eq(Autoplay.input_players("6:R,2:L"), 1)
	expect_errors(1)
	var bad: Array[PackedInt32Array] = Autoplay.parse_inputs_multi(
			"# route: level=test_core_party difficulty=beginner players=2 ends=none\n2:R|L|U,3:R|L")
	assert_eq(bad[0].size(), 3, "an entry with more parts than players is reported and skipped")


## A 1.0 route has no bar and no players header: it is parsed exactly as in 1.0, for every frozen route.
func test_every_1_0_route_parses_as_one_stream_exactly_as_before() -> void:
	var dir: String = ROUTE_DIR
	var count: int = 0
	for file: String in DirAccess.get_files_at(dir):
		if file.get_extension() != "inputs":
			continue
		var text: String = FileAccess.get_file_as_string(dir + file)
		if not Autoplay.parse_route_header(text).is_empty():
			continue
		count += 1
		var multi: Array[PackedInt32Array] = Autoplay.parse_inputs_multi(text)
		assert_eq(multi.size(), 1, "%s: one stream" % file)
		assert_true(multi[0] == Autoplay.parse_inputs(text), "%s: the 1.0 parse" % file)
		assert_eq(Autoplay.input_players(text), 1, "%s: one player" % file)
	assert_eq(count, 72, "the 72 frozen Book I routes")


func test_written_scripts_read_back_unchanged() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7
	for players: int in [1, 2, 4]:
		var streams: Array[PackedInt32Array] = []
		for slot: int in players:
			var stream: PackedInt32Array = PackedInt32Array()
			var value: int = 0
			for tick: int in 400:
				if rng.randi_range(0, 9) == 0:
					value = rng.randi_range(0, 127)
				stream.append(value)
			streams.append(stream)
		var text: String = Autoplay.format_inputs(streams, PackedStringArray(["# a note"]))
		assert_true(text.begins_with("# a note\n"))
		assert_eq(text.contains("|"), players > 1, "%d player(s): bars only for a party" % players)
		var back: Array[PackedInt32Array] = Autoplay.parse_inputs_multi(text)
		assert_eq(back.size(), players)
		for slot: int in players:
			assert_true(back[slot] == streams[slot], "%d player(s): slot %d reads back" % [players, slot])
	# A 1.0 route written again is the same input.
	var route: String = FileAccess.get_file_as_string(ROUTE_DIR + "w1_l1.inputs")
	var flags: PackedInt32Array = Autoplay.parse_inputs(route)
	assert_true(Autoplay.parse_inputs(Autoplay.format_inputs([flags] as Array[PackedInt32Array])) == flags)
	assert_eq(Autoplay.flags_to_keys(Defs.IN_RIGHT | Defs.IN_UP | Defs.IN_SWAP), "RUS")
	assert_eq(GameInput.keys_to_flags(Autoplay.flags_to_keys(127)), 127)


# =================================================================================================================
# Route headers
# =================================================================================================================

func test_a_route_header_is_read_into_a_route_entry() -> void:
	var spec: Dictionary = Autoplay.parse_route_header("\n# route: level=w5_l1 difficulty=beginner players=1 " +
			"ends=exit after=tally expect=hurts:0,min_checkpoints:2,painting:0\n12:R\n")
	assert_eq(spec["errors"], PackedStringArray(), "the example of LEVEL_DESIGN.md 15.9")
	assert_eq(spec["level"], "w5_l1")
	assert_eq(spec["modes"], ["beginner"])
	assert_eq(spec["players"], 1)
	assert_eq(spec["leaves"], "exit")
	assert_eq(spec["after"], "tally")
	assert_eq(spec["belt"], PlayerRun.BELT_EMPTY)
	assert_eq(spec["expect"], {"hurts": 0, "min_checkpoints": 2, "painting": 0})
	assert_true(spec["header"])
	var full: Dictionary = Autoplay.parse_route_header("# route: level=w9_l3 difficulty=both players=2 ends=none " +
			"after=the_end belt=spear then=w9_l3b.inputs source=w9_l2 prefix=w9_l3.inputs@#side " +
			"expect=letters:1+3,ticks:1092..2185,glider:true,weapon_end:axe,embers:4+1,x2_gates:2,fight_ticks:300")
	assert_eq(full["errors"], PackedStringArray())
	assert_eq(full["modes"], ["beginner", "expert"])
	assert_eq(full["players"], 2)
	assert_eq(full["leaves"], "")
	assert_eq(full["after"], "tally")
	assert_eq(full["tally_to"], {"beginner": "the_end", "expert": "the_end"})
	assert_eq(full["belt"], Defs.Weapon.SPEAR)
	assert_eq(full["then"], "w9_l3b.inputs")
	assert_eq(full["source"], "w9_l2")
	assert_eq(full["prefix"], ["w9_l3.inputs", "#side"])
	var expect: Dictionary = full["expect"]
	assert_eq(expect["letters"], [1, 3])
	assert_eq(expect["ticks"], [1092, 2185])
	assert_eq(expect["glider"], true)
	assert_eq(expect["weapon_end"], Defs.Weapon.AXE)
	assert_eq(expect["embers"], [4, 1])
	assert_eq(expect["x2_gates"], 2)
	assert_eq(expect["fight_ticks"], [300, 300], "a single number is the range n..n")
	assert_eq(Autoplay.parse_route_header("# route: level=a difficulty=expert ends=warp after=level:bonus_d " +
			"expect=letters:2")["expect"]["letters"], [2], "a list of one")


func test_bad_route_headers_say_what_is_wrong() -> void:
	assert_eq(Autoplay.parse_route_header("12:R\n"), {}, "no header: a 1.0 route")
	assert_eq(Autoplay.parse_route_header("# w1_l1 route\n# route: level=w1_l1 difficulty=beginner ends=exit\n"), {},
			"the header is the first line")
	var bad: Dictionary = Autoplay.parse_route_header("# route: level=w5_l1 difficulty=easy players=7 ends=door " +
			"after=map belt=club colour=red prefix=w5_l1.inputs expect=hurts:x,smiles:3,glider:yes,ticks:5..")
	var errors: PackedStringArray = bad["errors"]
	assert_eq(errors.size(), 13, "\n".join(errors))
	for word: String in ["difficulty=easy", "players=7", "ends=door", "after=map", "belt=club", "colour=red",
			"prefix=w5_l1.inputs", "hurts:x", "smiles:3", "glider:yes", "ticks:5..", "no difficulty=", "no ends="]:
		var found: bool = false
		for error: String in errors:
			found = found or error.contains(word)
		assert_true(found, "%s is reported" % word)
	var empty: Dictionary = Autoplay.parse_route_header("# route:")
	assert_eq(empty["errors"], PackedStringArray(["no level=", "no difficulty=", "no ends="]))
	# Every key the reader accepts is a key the route tests check.
	for key: String in Autoplay.ROUTE_EXPECT_KEYS:
		var one: Dictionary = Autoplay.parse_route_header("# route: level=a difficulty=beginner ends=none expect=%s:%s" % [
			key, "true" if Autoplay.ROUTE_BOOL_KEYS.has(key) else "1"])
		assert_eq(one["errors"], PackedStringArray(), key)


func test_header_routes_are_found_in_a_folder() -> void:
	var table: Dictionary = _fixtures()
	assert_eq(table.keys(), [PARTY_ROUTE, SOLO_ROUTE])
	assert_eq(header_problems(table), PackedStringArray())
	assert_eq(table[PARTY_ROUTE]["players"], 2)
	assert_eq(table[PARTY_ROUTE]["dir"], FIXTURE_DIR)
	assert_eq(table[SOLO_ROUTE]["players"], 1)
	var live: Dictionary = (load(BENCH_RUNNER) as GDScript).call("live_routes", FIXTURE_DIR)
	assert_true(live.has("w1_l1.inputs") and live.has(PARTY_ROUTE), "the bench plays the 1.0 table and the headers")
	assert_false(live["w1_l1.inputs"].has("header"))
	# A route another header route names in `then` is chained (played after it, not alone).
	_write(OUT_DIR + "chain/a.inputs", "# route: level=test_core_party difficulty=beginner ends=exit then=b.inputs\n4:R\n")
	_write(OUT_DIR + "chain/b.inputs", "# route: level=test_core_party difficulty=beginner ends=none\n4:L\n")
	_write(OUT_DIR + "chain/c.inputs", "4:R\n")
	var chain: Dictionary = (load(BENCH_RUNNER) as GDScript).call("header_routes", OUT_DIR + "chain/")
	assert_eq(chain.keys(), ["a.inputs", "b.inputs"], "a file without a header is no header route")
	assert_true(bool(chain["b.inputs"].get("chained", false)))
	assert_false(bool(chain["a.inputs"].get("chained", false)))
	_write(OUT_DIR + "bad/w5_l1.axe.inputs", "# route: level=nowhere difficulty=beginner ends=none then=x.inputs\n4:R\n")
	var problems: PackedStringArray = header_problems(header_table(OUT_DIR + "bad/",
			func(_f: String, _s: Dictionary) -> bool: return true))
	assert_eq(problems.size(), 3, "\n".join(problems))


# =================================================================================================================
# Driving several heroes
# =================================================================================================================

func test_run_party_inputs_drives_every_slot() -> void:
	Game.start_run(Defs.Difficulty.BEGINNER, Defs.GameMode.COOP, 2)
	Sim.manual = true
	Game.begin_level(PARTY_LEVEL)
	var level: Level = (load(Flow.LEVEL_SCENE) as PackedScene).instantiate() as Level
	level.setup_from_text(PARTY_LEVEL, FileAccess.get_file_as_string(Levels.get_level_path(PARTY_LEVEL)))
	add_node(level)
	level.set_view_size(Vector2i(Tuning.VIEW_W, Tuning.VIEW_H) * Tuning.ART_SCALE)
	var p1: PlayerBase = level.player
	var p2: PlayerBase = level.get_hero(1)
	assert_not_null(p2, "the loader spawned P2 at his start")
	var x1: int = p1.sim_pos.x
	var x2: int = p2.sim_pos.x
	var streams: Array[PackedInt32Array] = run_party_inputs([[10, "R|L"], [4, "|"]])
	assert_eq(streams.size(), 2)
	assert_eq(streams[0].size(), 14)
	assert_true(p1.sim_pos.x > x1, "P1 walked right")
	assert_true(p2.sim_pos.x < x2, "P2 walked left")
	assert_false(GameInput.is_scripted(), "device input is back on every slot")
	var y2: int = p2.sim_pos.y
	run_party_inputs([[6, "|U"]])
	assert_true(p2.sim_pos.y < y2, "a stream for P2 alone: P2 jumps")
	Game.new_game(Defs.Difficulty.BEGINNER)


func test_the_recorder_writes_every_slot_tick_for_tick() -> void:
	var recorder: Node = (load(Autoplay.RECORDER) as GDScript).new() as Node
	add_node(recorder)
	var path: String = OUT_DIR + "recorded.inputs"
	for file: String in [path, OUT_DIR + "recorded.2.inputs"]:
		if FileAccess.file_exists(file):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(file))
	recorder.call("begin", path)
	var table: Dictionary = _fixtures()
	# Two stages: the party route, then the solo route (its own file).
	await runner().replay(PARTY_ROUTE, BEGINNER, {"routes": table})
	await runner().replay(SOLO_ROUTE, EXPERT, {"routes": table, "keep": true})
	assert_eq(recorder.call("flush"), "", "the solo stage was written when the tally came")
	var files: PackedStringArray = recorder.get("files_written")
	assert_eq(files, PackedStringArray([path, OUT_DIR + "recorded.2.inputs"]))
	var party_text: String = FileAccess.get_file_as_string(path)
	var played: Array[PackedInt32Array] = Autoplay.parse_inputs_multi(
			FileAccess.get_file_as_string(FIXTURE_DIR + PARTY_ROUTE))
	var recorded: Array[PackedInt32Array] = Autoplay.parse_inputs_multi(party_text)
	assert_eq(recorded.size(), 2, "both players")
	assert_true(recorded[0] == played[0] and recorded[1] == played[1], "the party route, tick for tick")
	var header: Dictionary = Autoplay.parse_route_header(party_text)
	assert_eq(header["errors"], PackedStringArray())
	assert_eq([header["level"], header["modes"], header["players"], header["leaves"]],
			["test_core_party", ["beginner"], 2, ""])
	var solo_text: String = FileAccess.get_file_as_string(files[1])
	var solo: Dictionary = Autoplay.parse_route_header(solo_text)
	assert_eq([solo["modes"], solo["players"], solo["leaves"]], [["expert"], 1, "exit"])
	assert_false(solo_text.substr(solo_text.find("\n")).contains("|"), "one hero: a 1.0 route body")
	var solo_played: PackedInt32Array = Autoplay.parse_inputs(FileAccess.get_file_as_string(FIXTURE_DIR + SOLO_ROUTE))
	var solo_recorded: PackedInt32Array = Autoplay.parse_inputs(solo_text)
	assert_true(solo_recorded.size() < solo_played.size(), "the stage ended at the exit")
	assert_true(solo_recorded == solo_played.slice(0, solo_recorded.size()), "every tick until the exit")
	recorder.free()
	# The recording replays to the same digests as the route it recorded.
	var again: Dictionary = (load(BENCH_RUNNER) as GDScript).call("header_routes", OUT_DIR)
	assert_true(again.has("recorded.inputs"))
	var original: Dictionary = await runner().replay(PARTY_ROUTE, BEGINNER, {"routes": table})
	var replayed: Dictionary = await runner().replay("recorded.inputs", BEGINNER, {"routes": again})
	assert_eq(runner().call("first_difference", original["lines"], replayed["lines"]), "")


# =================================================================================================================
# Header routes through the bench
# =================================================================================================================

func test_a_solo_header_route_plays_to_its_tally() -> void:
	var table: Dictionary = _fixtures()
	for mode: String in table[SOLO_ROUTE]["modes"]:
		var result: Dictionary = await play_header_route(SOLO_ROUTE, mode, table)
		assert_eq(int(result.get("input_mismatches", -1)), 0, "%s: every slot read its stream" % mode)


func test_a_party_header_route_plays_both_streams() -> void:
	var table: Dictionary = _fixtures()
	var result: Dictionary = await play_header_route(PARTY_ROUTE, BEGINNER, table)
	assert_eq(int(result["input_mismatches"]), 0, "slot k read stream k on every tick, slots 3 and 4 nothing")
	assert_eq(int(result["input_ticks"]), 120)
	assert_eq(stage_ticks(result["lines"]), 120, "the whole route ran (it never leaves)")


## A linked pair of the 1.0 campaign written as header routes (copies under build/): the chain (`then`), `after`,
## `pair_ticks` and the 1.0 expect keys are checked stage by stage, and the header pair replays to exactly the
## digests of the 1.0 ROUTES pair - a header route is played as a ROUTES entry is.
func test_a_1_0_route_pair_as_header_routes() -> void:
	var dir: String = OUT_DIR + "pair/"
	_write(dir + "w2_l2.inputs", "# route: level=w2_l2 difficulty=beginner ends=exit after=level:w2_l2b " +
			"then=w2_l2b.inputs expect=glider:true,letters:0+1+2+4,min_secrets:1,gates:2\n" +
			FileAccess.get_file_as_string(ROUTE_DIR + "w2_l2.inputs"))
	_write(dir + "w2_l2b.inputs", "# route: level=w2_l2b difficulty=beginner ends=exit after=tally " +
			"expect=boss_hits:2,unlocked:true,pair_ticks:2200..4400\n" +
			FileAccess.get_file_as_string(ROUTE_DIR + "w2_l2b.inputs"))
	var table: Dictionary = header_table(dir, func(_f: String, _s: Dictionary) -> bool: return true)
	assert_eq(header_problems(table), PackedStringArray())
	assert_true(bool(table["w2_l2b.inputs"].get("chained", false)), "the Brute's den follows Bone Gorge")
	await play_header_route("w2_l2.inputs", BEGINNER, table)
	var routes: Dictionary = (load("res://tests/test_campaign_routes.gd") as GDScript).get_script_constant_map()["ROUTES"]
	var as_1_0: Dictionary = await runner().replay("w2_l2.inputs", BEGINNER, {"routes": routes})
	var as_header: Dictionary = await runner().replay("w2_l2.inputs", BEGINNER, {"routes": table})
	var lines: PackedStringArray = as_1_0["lines"]
	assert_true(lines.size() > 2000, "both stages played (%d digest lines)" % lines.size())
	assert_eq(runner().call("first_difference", lines, as_header["lines"]), "",
			"the header pair is the ROUTES pair, tick for tick")


func test_the_belt_invariance_runner() -> void:
	var table: Dictionary = _fixtures()
	for file: String in [SOLO_ROUTE, PARTY_ROUTE]:
		var problems: PackedStringArray = await belt_invariance_problems(file, BEGINNER, table)
		assert_eq(problems, PackedStringArray(), "%s: the same digests whatever the belt holds" % file)
	# The proof sees a belt that reaches the simulation: here a hook that nudges P2 when he carries the axe.
	var nudge: Callable = func(level: LevelBase, stage_tick: int) -> void:
		var hero: PlayerBase = level.get_hero(1)
		if stage_tick == 30 and hero != null and hero.run.belt == Defs.Weapon.AXE:
			hero.sim_pos.x += 1
	var caught: Dictionary = await runner().belt_invariance(PARTY_ROUTE, BEGINNER, table, {"on_tick": nudge})
	clean_up_route()
	assert_false(caught["ok"])
	assert_eq((caught["differences"] as PackedStringArray).size(), 1, str(caught["differences"]))
	assert_true(str(caught["differences"][0]).begins_with("axe: line 31:"), str(caught["differences"]))


func test_a_party_route_replays_the_same_every_way() -> void:
	var problems: PackedStringArray = await determinism_problems(PARTY_ROUTE, EXPERT, _fixtures())
	assert_eq(problems, PackedStringArray(), "twice, without dozing, on other devices")
