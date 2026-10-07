extends RouteTestCase
## Players: the permanent single-player guard of 2.0 and the bare two-hero level of the phase-0 exit. Owner: core.
##
## The guard (docs/expansion/PLAN.md 8 V1.c, TECH_AUDIT.md 4.12 #5): on a single-player level the PlayerSet is the 1.0
## hero - heroes == [player], one hero in slot 0 with the run of slot 0 - GameInput.get_flags(0) == GameInput.flags
## and the free slots read nothing on every tick, and Game.hearts / bones / weapon / has_glider are runs[0]'s; and
## three representative routes - w1_l1.inputs (Beginner), w2_l2b.inputs (the Brute, from a fresh run) and
## w4_l1.boomerang.inputs (Expert, auto-scroll) - replay to exactly the per-tick digests committed from the 1.0
## baseline (tests/fixtures/sp_digest/, written by `sim_bench.gd --digest --tight` on the unmodified 1.0.0 tree).
## The replay is the bench's own (scripts/core/dev/sim_bench_runner.gd replay(), the code tools/sp_identity.sh runs),
## so a change that moves single-player by one tick fails here, in the default suite, without build/.
##
## Drift check (PLAN.md P0.9: the guard must fail on a deliberately drifted copy and pass on the tree):
##   CORE_PLAYERS_FIXTURES=<dir>  compare with the fixture files of another folder (same names);
##   CORE_PLAYERS_SNAPSHOT=<dir>  replay the levels (<dir>/levels/*.lvl) and route files (<dir>/routes/*.inputs) of a
##                                copy instead of the tree's, as `sim_bench.gd --snapshot` does;
## e.g. `CORE_PLAYERS_SNAPSHOT=res://build/guard_drift/players bash .tools/gd.sh test core_players` must FAIL.
##
## The exit level (PLAN.md P0.10, TECH_AUDIT.md 6.1): levels/test_core_party.lvl with the two-stream route
## tests/fixtures/routes/test_core_party.inputs - the two heroes move independently: each hero's trajectory is the
## same whatever the other stream does (and P1's is the single-player hero's), both trajectories are asserted, and
## the party route replays identically twice, without dozing and on other devices.

const FIXTURE_DIR: String = "res://tests/fixtures/sp_digest/"
const ROUTES_TEST: String = "res://tests/test_campaign_routes.gd"
## The representative routes of TECH_AUDIT.md 4.12 #5: [route file, mode].
const SP_ROUTES: Array[Array] = [
	["w1_l1.inputs", "beginner"], ["w2_l2b.inputs", "beginner"], ["w4_l1.boomerang.inputs", "expert"],
]
const PARTY_DIR: String = "res://tests/fixtures/routes/"
const PARTY_ROUTE: String = "test_core_party.inputs"
const PARTY_LEVEL: StringName = &"test_core_party"
const OUT_DIR: String = "res://build/test_core_players/"

## Per tick of a replay: the ticks where a single-player invariant did not hold, and the first such.
var _violations: int = 0
var _first_violation: String = ""
var _snapshot: String = ""


func after_each() -> void:
	super.after_each()
	if _snapshot != "":
		Levels.rescan()
		_snapshot = ""


# =================================================================================================================
# The single-player guard (V1.c)
# =================================================================================================================

func test_the_run_of_p1_is_the_1_0_game_state() -> void:
	Game.new_game(Defs.Difficulty.BEGINNER)
	assert_eq(Game.mode, Defs.GameMode.SINGLE)
	assert_eq(Game.party, 1)
	assert_eq(Game.book, 1)
	Game.hearts = 1
	Game.bones = 4
	Game.weapon = Defs.Weapon.AXE
	Game.has_glider = true
	var run: PlayerRun = Game.runs[0]
	assert_eq([run.hearts, run.bones, run.weapon, run.has_glider], [1, 4, Defs.Weapon.AXE, true],
			"Game writes are runs[0] writes")
	run.hearts = 2
	run.weapon = Defs.Weapon.HAMMER
	assert_eq([Game.hearts, Game.weapon], [2, Defs.Weapon.HAMMER], "runs[0] writes are Game reads")
	assert_eq(run.belt, PlayerRun.BELT_EMPTY, "Book I solo carries nothing on the belt")
	Game.new_game(Defs.Difficulty.BEGINNER)
	assert_eq([Game.hearts, Game.weapon, Game.has_glider], [Tuning.ENERGY_START, Defs.Weapon.CLUB, false])


## The three representative routes, tick for tick against the 1.0 digests, with the PlayerSet and input-slot
## invariants checked on every tick.
func test_three_routes_replay_to_the_1_0_digests() -> void:
	var routes: Dictionary = (load(ROUTES_TEST) as GDScript).get_script_constant_map()["ROUTES"]
	var route_dir: String = ROUTE_DIR
	var fixtures: String = OS.get_environment("CORE_PLAYERS_FIXTURES")
	fixtures = FIXTURE_DIR if fixtures.is_empty() else fixtures.trim_suffix("/") + "/"
	var snapshot: String = OS.get_environment("CORE_PLAYERS_SNAPSHOT")
	if not snapshot.is_empty():
		route_dir = _use_snapshot(snapshot.trim_suffix("/"))
		print("    core_players: replaying the copy %s" % snapshot)
	for entry: Array in SP_ROUTES:
		var file: String = entry[0]
		var mode: String = entry[1]
		var fixture: String = "%s%s.%s.txt" % [fixtures, file, mode]
		assert_true(FileAccess.file_exists(fixture), "fixture %s" % fixture)
		var expected: PackedStringArray = _lines_of(fixture)
		_violations = 0
		_first_violation = ""
		var result: Dictionary = await runner().replay(file, mode, {"routes": routes, "route_dir": route_dir,
				"on_tick": _check_single_player})
		var lines: PackedStringArray = result.get("lines", PackedStringArray())
		assert_true(lines.size() > 500, "%s (%s) played (%d digest lines)" % [file, mode, lines.size()])
		var difference: String = runner().call("first_difference", expected, lines)
		assert_eq(difference, "", "%s (%s): the 1.0 digest, tick for tick (fixture vs replay)" % [file, mode])
		assert_eq(_violations, 0, "%s (%s): single-player invariants on every tick (first: %s)" % [file, mode,
				_first_violation])
		assert_eq(int(result.get("input_mismatches", -1)), 0, "%s (%s): slot 0 read the route, slots 1..3 nothing" % [
				file, mode])
		print("    %s (%s): %d digest lines, first difference: %s" % [file, mode, lines.size(),
				difference if difference != "" else "none"])


## On every tick of a single-player replay: the PlayerSet is the 1.0 hero and the input slots are P1's.
func _check_single_player(level: LevelBase, stage_tick: int) -> void:
	var problems: PackedStringArray = PackedStringArray()
	if level.hero_count() != 1 or level.heroes.size() != 1 or level.heroes[0] != level.player:
		problems.append("heroes %s" % str(level.heroes))
	elif level.player.slot != 0 or level.player.run != Game.runs[0] or level.contact_order() != level.heroes:
		problems.append("P1 is not slot 0 with runs[0]")
	if GameInput.get_flags(0) != GameInput.flags:
		problems.append("get_flags(0) %d != flags %d" % [GameInput.get_flags(0), GameInput.flags])
	for slot: int in range(1, Defs.MAX_PLAYERS):
		if GameInput.get_flags(slot) != 0:
			problems.append("slot %d reads %d" % [slot, GameInput.get_flags(slot)])
	var run: PlayerRun = Game.runs[0]
	if Game.hearts != run.hearts or Game.bones != run.bones or Game.weapon != run.weapon \
			or Game.has_glider != run.has_glider or Game.party != 1 or Game.mode != Defs.GameMode.SINGLE:
		problems.append("Game is not runs[0] of a single-player run")
	if not problems.is_empty():
		_violations += 1
		if _first_violation.is_empty():
			_first_violation = "%s tick %d: %s" % [level.level_id, stage_tick, "; ".join(problems)]


## Replay the levels and routes of a copy (CORE_PLAYERS_SNAPSHOT): the registry points every level of `dir`/levels
## at its copy (as sim_bench.gd --snapshot does; after_each rescans). Returns the route folder of the copy.
func _use_snapshot(dir: String) -> String:
	_snapshot = dir
	for file: String in DirAccess.get_files_at(dir + "/levels"):
		if file.get_extension() != Levels.LEVEL_EXT:
			continue
		var path: String = dir + "/levels/" + file
		var id: StringName = StringName(file.get_basename())
		Levels._meta[id] = Levels.parse_meta(FileAccess.get_file_as_string(path))
		Levels._paths[id] = path
	Levels._index_campaign()
	return dir + "/routes/"


func _lines_of(path: String) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	for line: String in FileAccess.get_file_as_string(path).split("\n"):
		var text: String = line.strip_edges()
		if not text.is_empty():
			lines.append(text)
	return lines


# =================================================================================================================
# The bare two-hero level (P0.10)
# =================================================================================================================

## Two scripted streams, two heroes: each one's trajectory depends on his own stream only. Replayed four ways - both
## streams, P1's alone in the party, P2's alone in the party, P1's in single-player - with every hero's feet point
## and velocity recorded per tick.
func test_two_heroes_move_independently_from_two_streams() -> void:
	var table: Dictionary = header_table(PARTY_DIR, func(file: String, _s: Dictionary) -> bool:
		return file == PARTY_ROUTE)
	assert_eq(table.size(), 1, "the fixture route %s%s" % [PARTY_DIR, PARTY_ROUTE])
	if table.is_empty():
		return
	var streams: Array[PackedInt32Array] = Autoplay.parse_inputs_multi(
			FileAccess.get_file_as_string(PARTY_DIR + PARTY_ROUTE))
	assert_eq(streams.size(), 2)
	var idle: PackedInt32Array = PackedInt32Array()
	idle.resize(streams[0].size())
	var party_header: String = "# route: level=test_core_party difficulty=beginner players=2 ends=none"
	_write(OUT_DIR + "p1_only.inputs", Autoplay.format_inputs([streams[0], idle] as Array[PackedInt32Array],
			PackedStringArray([party_header])))
	_write(OUT_DIR + "p2_only.inputs", Autoplay.format_inputs([idle, streams[1]] as Array[PackedInt32Array],
			PackedStringArray([party_header])))
	_write(OUT_DIR + "p1_solo.inputs", Autoplay.format_inputs([streams[0]] as Array[PackedInt32Array],
			PackedStringArray(["# route: level=test_core_party difficulty=beginner ends=none"])))
	var variants: Dictionary = header_table(OUT_DIR, func(_f: String, _s: Dictionary) -> bool: return true)
	var both: Dictionary = await _trajectories(PARTY_ROUTE, table)
	var only1: Dictionary = await _trajectories("p1_only.inputs", variants)
	var only2: Dictionary = await _trajectories("p2_only.inputs", variants)
	var solo: Dictionary = await _trajectories("p1_solo.inputs", variants)
	var ticks: int = streams[0].size()
	for run: Dictionary in [both, only1, only2]:
		assert_eq((run["p1"] as Array).size(), ticks, "every tick played with two heroes")
		assert_eq((run["p2"] as Array).size(), ticks)
	assert_eq((solo["p2"] as Array).size(), 0, "single-player: one hero, the P2 start is ignored")
	assert_eq(both["p1"], only1["p1"], "P1 moves the same whatever P2 does")
	assert_eq(both["p1"], solo["p1"], "and exactly as the single-player hero of the same stream")
	assert_eq(both["p2"], only2["p2"], "P2 moves the same whatever P1 does")
	var start1: Vector2i = both["start1"]
	var start2: Vector2i = both["start2"]
	assert_eq(start1, LevelText.cell_to_feet(9.0, 9.0), "P1 starts at '@'")
	assert_eq(start2, LevelText.cell_to_feet(5.0, 9.0), "P2 starts at his objects/hero_start slot=2")
	for row: Array in only1["p2"]:
		assert_eq([row[0], row[1], row[2]], [start2.x, start2.y, 0], "an idle P2 stays where he started")
		break
	assert_eq((only1["p2"] as Array).back().slice(0, 2), [start2.x, start2.y], "... to the end")
	assert_eq((only2["p1"] as Array).back().slice(0, 2), [start1.x, start1.y], "and so does an idle P1")
	# Both trajectories: P1 right onto his step and down onto his food, P2 left onto his step, back and left again.
	var p1: Array = both["p1"]
	var p2: Array = both["p2"]
	assert_eq(p1.back().slice(0, 2), [268, 160], "P1 ends beside the exit, on the floor")
	assert_eq(p2.back().slice(0, 2), [57, 160], "P2 ends at the foot of his step")
	assert_true(_stood_on_step(p1, 208, 240), "P1 stood on his step (cells 13-14, top y 144)")
	assert_true(_stood_on_step(p2, 16, 48), "P2 stood on his step (cells 1-2, top y 144)")
	assert_true(_lowest_y(p1) <= 104 and _lowest_y(p2) <= 104, "both jumped")
	var airborne: int = 0
	var apart: int = 0
	for i: int in ticks:
		if p1[i][3] != 0 and p2[i][3] != 0:
			airborne += 1
			if p1[i][2] > 0 and p2[i][2] < 0:
				apart += 1
	assert_true(airborne >= 10 and apart >= 1, "both in the air on %d ticks, flying apart on %d" % [airborne, apart])
	assert_eq(both["score"], 400, "each hero ate his own food (100 + 300)")
	assert_eq(only1["score"], 100)
	assert_eq(only2["score"], 300)


## The exit level's route replays identically: twice, without dozing, and with the slots on other devices.
func test_the_two_hero_route_replays_the_same_every_way() -> void:
	var table: Dictionary = header_table(PARTY_DIR, func(file: String, _s: Dictionary) -> bool:
		return file == PARTY_ROUTE)
	for mode: String in [BEGINNER, EXPERT]:
		var problems: PackedStringArray = await determinism_problems(PARTY_ROUTE, mode, table)
		assert_eq(problems, PackedStringArray(), "%s: the same digests every way" % mode)


## Replay `file` of `table` (Beginner) and record per tick [x, y, xvel, yvel] of P1 and P2 (an empty list for P2 in
## single-player), the start points and the score at the end.
func _trajectories(file: String, table: Dictionary) -> Dictionary:
	var out: Dictionary = {"p1": [], "p2": [], "start1": Vector2i(-1, -1), "start2": Vector2i(-1, -1)}
	var record: Callable = func(level: LevelBase, stage_tick: int) -> void:
		if stage_tick == 1:
			out["start1"] = level.get_start_pos_for(0)
			out["start2"] = level.get_start_pos_for(1) if level.hero_count() > 1 else Vector2i(-1, -1)
		for slot: int in level.hero_count():
			var hero: PlayerBase = level.get_hero(slot)
			(out["p%d" % (slot + 1)] as Array).append([hero.sim_pos.x, hero.sim_pos.y, hero.xvel, hero.yvel])
	var result: Dictionary = await runner().replay(file, BEGINNER, {"routes": table, "on_tick": record})
	assert_eq(int(result.get("input_mismatches", -1)), 0, "%s: every slot read its stream" % file)
	out["score"] = Game.score
	return out


func _stood_on_step(trajectory: Array, left: int, right: int) -> bool:
	for row: Array in trajectory:
		if int(row[1]) == 144 and int(row[3]) == 0 and int(row[0]) >= left and int(row[0]) <= right:
			return true
	return false


func _lowest_y(trajectory: Array) -> int:
	var best: int = 1 << 30
	for row: Array in trajectory:
		best = mini(best, int(row[1]))
	return best


func _write(path: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path).get_base_dir())
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()
