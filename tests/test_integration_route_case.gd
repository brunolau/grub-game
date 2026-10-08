class_name RouteTestCase
extends TestCase
## Shared machinery of the 2.0 route proofs (owner: integration; docs/expansion/PLAN.md P0.9 and 8 V2 / V3). No
## tests of its own: tests/test_book2_routes.gd, tests/test_coop_routes.gd and tests/test_integration_harness.gd
## build on it.
##
## New routes describe themselves with a `# route:` header (docs/LEVEL_DESIGN.md 15.9, Autoplay.parse_route_header)
## instead of a ROUTES entry. A header route is replayed through Flow by the bench runner
## (scripts/core/dev/sim_bench_runner.gd, replay(): the very code that proves single-player identity,
## tools/sp_identity.sh): a fresh run of its difficulty (a party of its `players`, the book of its level), the level
## entered without a transition, the 1280 x 720 view, one input stream per player, its `belt` on every hero. Then the
## header is checked: how the stage ends (`ends`), what follows (`after`), every `expect` key, no engine warning or
## error. The belt-invariance proof (PLAN 8 V2.b) and the determinism checks of co-op routes (V3.b) replay a route
## several times and compare the per-tick digests.

const ROUTE_DIR: String = "res://tools/autoplay/routes/"
const BENCH_RUNNER: String = "res://scripts/core/dev/sim_bench_runner.gd"
const BEGINNER: String = "beginner"
const EXPERT: String = "expert"
const TABLET_ID: StringName = &"objects/x2_tablet"


## Counts engine warnings and errors while a route plays (any of them fails the route, PLAN.md 8 V2.a).
class ProblemCounter:
	extends Logger

	var count: int = 0
	var first: String = ""

	func _log_error(
			function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool,
			_error_type: int, _script_backtraces: Array[ScriptBacktrace]
	) -> void:
		if count == 0:
			first = "%s (%s:%d in %s)" % [rationale if not rationale.is_empty() else code, file, line, function]
		count += 1

	func _log_message(_message: String, _error: bool) -> void:
		pass


var _runner: Node = null
var _counts: Dictionary = {}
## True until the watched stage's first tick stores the lives baseline (_counts["_lives"]).
var _lives_pending: bool = false
## PLAN.md 8 V3.e on a party route: the first entity found dozing inside a view or within reach of a hero ("" = none).
var _doze_problem: String = ""
## docs/LEVEL_DESIGN.md 15.7.9 on a party route: the first hero found IDLE in the middle of the stage - a hatched hero
## whose own slot gave no input for PlayerBase.IDLE_TICKS ticks ("" = none; [method _check_party_idle]).
var _idle_problem: String = ""
var _letters: Dictionary = {}
var _paintings: Dictionary = {}
var _jackpots: int = 0
var _words: int = 0
var _boss_hits: int = 0
var _boss_up: int = -1
var _boss_down: int = -1
var _glider_carried: bool = false
var _glider_flown: bool = false
var _exit_kinds: Array[StringName] = []
var _max_wind: int = 0
var _start_view_y: int = -1
var _deepest_view_y: int = 0
var _embers_seen: Dictionary = {}
var _embers_close: Dictionary = {}
## x2 tablets of the level being played: [gate name, far cell] (docs/LEVEL_DESIGN.md 15.7.4), and the ones whose far
## cell a hero reached.
var _tablets: Array[Array] = []
var _gates_reached: Dictionary = {}
var _connections: Array[Array] = []
var _problems: ProblemCounter = null
var _counting: bool = false
## G35 (DESIGN.md G-resolutions, wf9_lead_design_to_integration.txt #1.2 / #2): the first tick of a boss fight on which
## a weak point that can be struck lies outside the view or less than the clearance under the fight HUD
## (Hud.weak_point_problem); "" = none. Checked on every tick of every route that fights a boss. G35 speaks of the
## LOCKED view: once the camera is locked and has settled into its lock (LevelBase.is_camera_locked, the view inside
## the lock rectangle - or around it where the lock is the smaller), only those ticks count (the walk in before the
## lock and the glide into it are not the fight's framing); a fight the camera never locks is checked on every tick.
var _weak_problem: String = ""
## The first problem on a tick without a camera lock, and how many fight ticks were seen in a settled locked view.
var _weak_problem_free: String = ""
var _weak_locked_ticks: int = 0
## Fight ticks the G35 check ran on (2.0 content only).
var _weak_fight_ticks: int = 0
## The HUD script (its static weak-point helpers), loaded at run time: a HUD mid-edit cannot break the route tests.
var _hud: GDScript = null
const HUD_SCRIPT: String = "res://scripts/ui/hud.gd"


## The validator's run over the levels folder, shared by every test of the process ([method folder_validator]), and
## the state of the folder it was made for.
static var _folder_validator: LevelValidator = null
static var _folder_stamp: String = ""


func after_each() -> void:
	clean_up_route()


## The level validator after its run over the whole levels folder (LevelValidator.add_folder + run; read its
## `problems` / problems_of). One run serves every test of the process: validating the 80 files takes a second or two,
## and four tests of the default suite asked for the same answer. Run again when a level file was added, removed or
## written since (the file names and their modification times), so a test that writes a level never reads a stale
## verdict.
static func folder_validator() -> LevelValidator:
	var stamp: PackedStringArray = PackedStringArray()
	for file: String in DirAccess.get_files_at(Levels.LEVEL_DIR):
		stamp.append("%s:%d" % [file, FileAccess.get_modified_time(Levels.LEVEL_DIR + "/" + file)])
	var key: String = ",".join(stamp)
	if _folder_validator == null or key != _folder_stamp:
		_folder_validator = LevelValidator.new()
		_folder_validator.add_folder(Levels.LEVEL_DIR)
		_folder_validator.run()
		_folder_stamp = key
	return _folder_validator


# =================================================================================================================
# Tables
# =================================================================================================================

## Every header route of `dir` whose spec passes `accept` (Callable(file: String, spec: Dictionary) -> bool), by
## file name (sim_bench_runner.header_routes: the parsed header, its "errors", "dir", "chained").
func header_table(dir: String, accept: Callable) -> Dictionary:
	var table: Dictionary = {}
	var found: Dictionary = (load(BENCH_RUNNER) as GDScript).call("header_routes", dir)
	for file: String in found:
		if accept.call(file, found[file]):
			table[file] = found[file]
	return table


## What is wrong with the headers of `table` (empty = nothing): unreadable keys, an unknown level, a `then` or a
## `prefix` route that does not exist, a party route without party starts, a weapon suffix on a club route.
func header_problems(table: Dictionary) -> PackedStringArray:
	var problems: PackedStringArray = PackedStringArray()
	for file: String in table:
		var spec: Dictionary = table[file]
		for error: String in spec.get("errors", PackedStringArray()):
			problems.append("%s: %s" % [file, error])
		var level_id: StringName = StringName(str(spec.get("level", "")))
		if not Levels.has_level(level_id):
			problems.append("%s: level %s does not exist" % [file, level_id])
		var dir: String = str(spec.get("dir", ROUTE_DIR))
		if spec.has("then") and not table.has(str(spec["then"])):
			problems.append("%s: the route that follows (%s) is not a header route of the table" % [file, spec["then"]])
		if spec.has("prefix") and str(spec["prefix"][0]) != "@route" \
				and not FileAccess.file_exists(dir + str(spec["prefix"][0])):
			problems.append("%s: the prefix route %s does not exist" % [file, spec["prefix"][0]])
		if spec.has("source") and not Levels.has_level(StringName(str(spec["source"]))):
			problems.append("%s: the source level %s does not exist" % [file, spec["source"]])
		for weapon: int in Defs.Weapon.values():
			if file.ends_with(".%s.inputs" % Defs.weapon_name(weapon)):
				problems.append("%s: a 2.0 route carries no weapon suffix (club routes, LEVEL_DESIGN.md 15.9)" % file)
	return problems


## The bench runner node (created once per test, freed by clean_up_route()).
func runner() -> Node:
	if _runner == null or not is_instance_valid(_runner):
		_runner = (load(BENCH_RUNNER) as GDScript).new() as Node
		_runner.name = "RouteRunner"
		add_child(_runner)
	return _runner


# =================================================================================================================
# Playing a header route and checking it
# =================================================================================================================

## Play header route `file` of `table` on `mode` (and the route its `then` names, in the stage that follows) and
## check its header: ends, after, tally_to, expect, no engine warning or error. Returns the replay result of the
## first stage (sim_bench_runner.replay: "lines", "screen", ...).
func play_header_route(file: String, mode: String, table: Dictionary) -> Dictionary:
	var spec: Dictionary = table[file]
	var label: String = "%s (%s)" % [file, mode]
	_watch_events()
	_reset_watch(StringName(str(spec["level"])), mode)
	_start_counting_problems()
	var result: Dictionary = await runner().replay(file, mode, {"routes": table, "on_tick": _on_tick,
			"keep": true, "chain": false})
	_stop_counting_problems()
	var played: int = stage_ticks(result.get("lines", PackedStringArray()))
	assert_true(played > 0, "%s played" % label)
	_print_outcome(label, played)
	check_expectations(label, spec, played, 0)
	_check_after(label, spec, mode)
	var chained: String = str(spec.get("then", ""))
	var last_label: String = label
	var last_spec: Dictionary = spec
	if chained != "" and table.has(chained) and Flow.current_screen == Flow.SCREEN_LEVEL:
		last_label = "%s (%s)" % [chained, mode]
		last_spec = table[chained]
		_reset_watch(StringName(str(last_spec["level"])), mode)
		_start_counting_problems()
		var next: Dictionary = await runner().replay_stage(chained, mode, {"routes": table, "on_tick": _on_tick,
				"keep": true})
		_stop_counting_problems()
		var next_played: int = stage_ticks(next.get("lines", PackedStringArray()))
		assert_true(next_played > 0, "%s played" % last_label)
		_print_outcome(last_label, next_played)
		check_expectations(last_label, last_spec, next_played, played)
		_check_after(last_label, last_spec, mode)
	await _check_tally(last_label, last_spec, mode)
	clean_up_route()
	return result


## The ticks of the stage a replay played: the `ticks` of its first "end" line (-1 when there is none).
func stage_ticks(lines: PackedStringArray) -> int:
	for line: String in lines:
		if line.begins_with("end "):
			return line.get_slice(" ", 3).to_int()
	return -1


## The checks of a header's `expect` (docs/LEVEL_DESIGN.md 15.9; every key of Autoplay.ROUTE_EXPECT_KEYS) for the
## stage just played: `played` ticks, `before` = ticks of the stage that led here (pair_ticks). A party route counts
## every hero (the hero_* events); a solo route the 1.0 events.
func check_expectations(label: String, spec: Dictionary, played: int, before: int) -> void:
	var expect: Dictionary = spec.get("expect", {})
	var party: bool = int(spec.get("players", 1)) > 1
	var died: int = _count(&"hero_died" if party else &"player_died")
	var hurt: int = _count(&"hero_hurt" if party else &"player_hurt")
	assert_eq(died, int(expect.get("deaths", 0)), "%s: deaths" % label)
	if expect.has("hurts"):
		assert_eq(hurt, int(expect["hurts"]), "%s: hits taken" % label)
	if expect.has("max_hurts"):
		assert_true(hurt <= int(expect["max_hurts"]), "%s: hits taken %d" % [label, hurt])
	if expect.has("respawns"):
		assert_eq(_count(&"level_respawned"), int(expect["respawns"]), "%s: respawns" % label)
	assert_true(Game.lives >= int(_counts.get(&"_lives", Game.lives)) + int(expect.get("lives_gained", 0)),
			"%s: lives %d" % [label, Game.lives])
	if expect.has("weapon_end"):
		assert_eq(Game.weapon, int(expect["weapon_end"]), "%s: P1's weapon at the end" % label)
	if expect.has("secrets"):
		assert_eq(_count(&"secret_found"), int(expect["secrets"]), "%s: secrets" % label)
	if expect.has("min_secrets"):
		assert_true(_count(&"secret_found") >= int(expect["min_secrets"]), "%s: secrets %d" % [
			label, _count(&"secret_found")])
	if expect.has("gates"):
		assert_eq(_count(&"gate_used"), int(expect["gates"]), "%s: gate uses" % label)
	if expect.has("checkpoints"):
		assert_eq(_count(&"checkpoint_activated"), int(expect["checkpoints"]), "%s: checkpoints" % label)
	if expect.has("min_checkpoints"):
		assert_true(_count(&"checkpoint_activated") >= int(expect["min_checkpoints"]), "%s: checkpoints %d" % [
			label, _count(&"checkpoint_activated")])
	if expect.has("min_spots"):
		assert_true(_count(&"hidden_spot_opened") >= int(expect["min_spots"]), "%s: spots opened %d" % [
			label, _count(&"hidden_spot_opened")])
	if expect.has("min_kills"):
		assert_true(_count(&"enemy_killed") >= int(expect["min_kills"]), "%s: kills %d" % [
			label, _count(&"enemy_killed")])
	if expect.has("letters"):
		for index: int in expect["letters"]:
			assert_true(_letters.has(index), "%s: letter %d collected (%s)" % [label, index, str(_letters.keys())])
	if expect.has("words"):
		assert_eq(_words, int(expect["words"]), "%s: completed letter words" % label)
	if expect.has("ticks"):
		assert_true(played >= int(expect["ticks"][0]) and played <= int(expect["ticks"][1]), "%s: %d ticks" % [
			label, played])
	if expect.has("pair_ticks") and before > 0:
		assert_true(before + played >= int(expect["pair_ticks"][0]) and before + played <= int(expect["pair_ticks"][1]),
				"%s: both halves take %d ticks" % [label, before + played])
	if expect.has("jackpots"):
		assert_true(_jackpots >= int(expect["jackpots"]), "%s: jackpot chests %d" % [label, _jackpots])
	if expect.has("min_hearts"):
		assert_true(Game.hearts >= int(expect["min_hearts"]), "%s: %d hearts left" % [label, Game.hearts])
	if expect.has("fight_ticks"):
		var fight: int = _boss_down - _boss_up if _boss_up >= 0 and _boss_down >= 0 else -1
		assert_true(fight >= int(expect["fight_ticks"][0]) and fight <= int(expect["fight_ticks"][1]),
				"%s: the boss fight takes %d ticks" % [label, fight])
	if expect.has("min_completion"):
		assert_true(Game.completion_percent() >= int(expect["min_completion"]), "%s: completion %d %%" % [
			label, Game.completion_percent()])
	if expect.has("min_score"):
		assert_true(Game.score >= int(expect["min_score"]), "%s: score %d" % [label, Game.score])
	if expect.has("boss_hits"):
		assert_eq(_count(&"boss_started"), 1, "%s: the boss fight started" % label)
		assert_eq(_count(&"boss_defeated"), 1, "%s: the boss was beaten" % label)
		assert_true(_boss_hits >= int(expect["boss_hits"]), "%s: boss hits %d" % [label, _boss_hits])
	if bool(expect.get("unlocked", false)):
		assert_eq(_count(&"exit_unlocked"), 1, "%s: the fire-starter unlocked the exit" % label)
	if bool(expect.get("glider", false)):
		assert_true(_glider_carried and _glider_flown, "%s: the hang-glider was taken and flown" % label)
	if expect.has("min_wind"):
		assert_true(_max_wind >= int(expect["min_wind"]), "%s: strongest wind %d" % [label, _max_wind])
	if expect.has("view_sank"):
		assert_true(_deepest_view_y - _start_view_y >= int(expect["view_sank"]), "%s: the view sank %d px" % [
			label, _deepest_view_y - _start_view_y])
	if expect.has("embers"):
		assert_true(_embers_seen.size() >= int(expect["embers"][0]), "%s: embers fell: %d" % [
			label, _embers_seen.size()])
		if (expect["embers"] as Array).size() > 1:
			assert_true(_embers_close.size() >= int(expect["embers"][1]), "%s: embers beside a hero: %d" % [
				label, _embers_close.size()])
	if bool(expect.get("no_enemies", false)):
		assert_eq(_count(&"enemy_killed") + hurt, 0, "%s: nothing to fight" % label)
	if expect.has("hero_min_x") or expect.has("hero_y"):
		var hero: PlayerBase = Game.level.player if Game.level != null else null
		assert_not_null(hero, "%s: P1 is there at the end" % label)
		if hero != null:
			assert_true(hero.sim_pos.x >= int(expect.get("hero_min_x", 0)), "%s: P1 got to x %d" % [
				label, hero.sim_pos.x])
			if expect.has("hero_y"):
				assert_eq(hero.sim_pos.y, int(expect["hero_y"]), "%s: P1 stands on the far side" % label)
	if expect.has("painting"):
		assert_true(_paintings.has(int(expect["painting"])), "%s: Cave Painting %d found (%s)" % [label,
			int(expect["painting"]), str(_paintings.keys())])
	if expect.has("wipes"):
		assert_true(_count(&"party_wiped") <= int(expect["wipes"]), "%s: team wipes %d" % [
			label, _count(&"party_wiped")])
	if expect.has("eggs"):
		assert_true(_count(&"hero_down") <= int(expect["eggs"]), "%s: eggs %d" % [label, _count(&"hero_down")])
	if expect.has("hatches"):
		assert_true(_count(&"hero_revived") >= int(expect["hatches"]), "%s: hatches %d" % [
			label, _count(&"hero_revived")])
	if party:
		assert_eq(_doze_problem, "", "%s: no entity dozes inside a view or within reach of a hero (V3.e)" % label)
		assert_eq(_idle_problem, "", "%s: no hero stands idle (LEVEL_DESIGN 15.7.9)" % label)
	assert_eq(weak_point_verdict(), "", "%s: every boss weak point stays in the view and clear of the fight HUD (G35)" % label)
	if expect.has("x2_gates"):
		assert_true(_gates_reached.size() >= int(expect["x2_gates"]), "%s: x2 gates crossed %d of %d (%s)" % [
			label, _gates_reached.size(), _tablets.size(), str(_gates_reached.keys())])
	if _problems != null:
		assert_eq(_problems.count, 0, "%s: no engine warning or error (first: %s)" % [label, _problems.first])


## Free the stage a replay left running and put Flow and the input back (every test calls it through after_each).
func clean_up_route() -> void:
	_stop_counting_problems()
	for connection: Array in _connections:
		var signal_ref: Signal = connection[0]
		if signal_ref.is_connected(connection[1]):
			signal_ref.disconnect(connection[1])
	_connections.clear()
	GameInput.clear_scripted()
	GameInput.reset_slots()
	LevelBase.doze_enabled = true
	Sim.manual = false
	Sim.stop()
	if get_tree().current_scene != null:
		get_tree().current_scene.free()
		get_tree().current_scene = null
	Flow.current_screen = Flow.SCREEN_BOOT
	Flow.args = {}
	Flow.play_mode = Defs.GameMode.SINGLE
	Flow.play_book = 1
	if _runner != null and is_instance_valid(_runner):
		_runner.free()
	_runner = null


# =================================================================================================================
# Belt invariance and determinism
# =================================================================================================================

## PLAN.md 8 V2.b: replay `file` of `table` on `mode` with an empty belt and with each special on every hero's
## belt; returns the differences (empty = the per-tick digests are identical whatever the belt holds).
func belt_invariance_problems(file: String, mode: String, table: Dictionary) -> PackedStringArray:
	var result: Dictionary = await runner().belt_invariance(file, mode, table)
	clean_up_route()
	var problems: PackedStringArray = PackedStringArray()
	for difference: String in result["differences"]:
		problems.append("%s (%s): %s" % [file, mode, difference])
	return problems


## PLAN.md 8 V3.b (co-op routes): the route replayed twice gives identical digests, with and without dozing, and
## with the player slots assigned to other devices (devices never reach the simulation). Returns the differences.
func determinism_problems(file: String, mode: String, table: Dictionary) -> PackedStringArray:
	var problems: PackedStringArray = PackedStringArray()
	var first: Dictionary = await runner().replay(file, mode, {"routes": table})
	var reference: PackedStringArray = first.get("lines", PackedStringArray())
	if reference.is_empty():
		problems.append("%s (%s) did not play" % [file, mode])
		return problems
	var runs: Array[Array] = [["again", {"routes": table}], ["without dozing", {"routes": table, "doze": false}]]
	for run: Array in runs:
		var other: Dictionary = await runner().replay(file, mode, run[1])
		var difference: String = runner().call("first_difference", reference, other.get("lines", PackedStringArray()))
		if difference != "":
			problems.append("%s (%s) %s: %s" % [file, mode, run[0], difference])
	# Other devices: P1 on the right keyboard half, P2 on pad 1, P3 / P4 on pads 2 and 3.
	GameInput.assign_slot(0, InputSlot.keyboard(Defs.InputSlotKind.KEYBOARD_RIGHT))
	GameInput.assign_slot(1, InputSlot.pad(1))
	GameInput.assign_slot(2, InputSlot.pad(2))
	GameInput.assign_slot(3, InputSlot.pad(3))
	var moved: Dictionary = await runner().replay(file, mode, {"routes": table})
	GameInput.reset_slots()
	var device_difference: String = runner().call("first_difference", reference,
			moved.get("lines", PackedStringArray()))
	if device_difference != "":
		problems.append("%s (%s) with other devices: %s" % [file, mode, device_difference])
	clean_up_route()
	return problems


# =================================================================================================================
# The campaign in one run (PLAN.md 6.2 and 8 V2.c: the headless twins of campaign_b2.flow and campaign_coop.flow)
# =================================================================================================================

## The files of the finished design per book (DESIGN.md A.2; Book I: the 15 files of 1.0). A campaign run is held to
## its whole shape - every stop, the expert wall after a Beginner run, The End after an Expert run - once every file
## of its book exists (solo) or every one of them has its co-op file `<id>_coop` (DESIGN.md D.9 / D.10); until then it
## plays the stops that have landed and reports where it waits.
const DESIGN_FILES: Dictionary = {
	1: [&"w1_l1", &"w1_l2", &"bonus_a", &"w2_l1", &"bonus_b", &"w2_l2", &"w2_l2b", &"w3_l1", &"w3_l1b", &"bonus_c",
		&"w3_l2", &"w4_l1", &"w4_l2", &"w4_l2b", &"ending"],
	2: [&"w5_l1", &"w5_l2", &"w5_l2b", &"bonus_d", &"w6_l1", &"w6_l2", &"w6_l2b", &"w7_l1", &"bonus_e", &"w7_l2",
		&"w7_l2b", &"w8_l1", &"w8_l2", &"w8_l2b", &"w9_l1", &"w9_l1b", &"w9_l2", &"w9_l2b", &"w9_l3", &"ending_b"],
}
## The Expert-only files of the design (DESIGN.md A.2 mode E; Book I's world 4 and ending, Book II's worlds 8-9 and
## ending): a Beginner run never meets them.
const DESIGN_EXPERT_ONLY: Array[StringName] = [&"w4_l1", &"w4_l2", &"w4_l2b", &"ending", &"w8_l1", &"w8_l2",
	&"w8_l2b", &"w9_l1", &"w9_l1b", &"w9_l2", &"w9_l2b", &"w9_l3", &"ending_b"]
## Screens a campaign run may end on.
const CAMPAIGN_ENDS: Array[StringName] = [&"expert_wall", &"the_end"]


## A content gate of the route modules (REQUIRE_EXPERT_ROUTES, REQUIRE_COMPLETE_CAMPAIGN): its constant, or the gate
## run itself - the environment variable G3_REQUIRE=1 (tools/g3.sh --require) switches every one on.
static func g3_required(switch: bool) -> bool:
	return switch or OS.get_environment("G3_REQUIRE") == "1"


## True when every file of `book`'s design exists (with `coop`: every one as its co-op file).
static func design_complete(book: int, coop: bool) -> bool:
	for level_id: StringName in DESIGN_FILES.get(book, []):
		if not Levels.has_level(StringName(String(level_id) + "_coop") if coop else level_id):
			return false
	return true


## The stages of `book`'s design a campaign run on `difficulty` should play but cannot, because their file (with
## `coop`: their co-op file) is not there yet: the registry's campaign - and Flow, which passes over a stop without
## its file, as it does over a stop without a co-op file in co-op - simply leaves them out. Feast Lands are side trips
## (a warp), not stops, and are not listed.
static func design_missing(book: int, coop: bool, difficulty: int) -> PackedStringArray:
	var missing: PackedStringArray = PackedStringArray()
	for level_id: StringName in DESIGN_FILES.get(book, []):
		if String(level_id).begins_with("bonus_") \
				or (difficulty == Defs.Difficulty.BEGINNER and DESIGN_EXPERT_ONLY.has(level_id)):
			continue
		var file: StringName = StringName(String(level_id) + "_coop") if coop else level_id
		if not Levels.has_level(file):
			missing.append(String(file))
	return missing


## The route a campaign run plays in stage `level_id` on `mode`: the side route `sides` names for it (a warp into a
## Feast Land), else the stage's club route (`<id>.inputs` / `<id>.expert.inputs` with a header of that mode that ends
## the stage and carries nothing on the belt); "" when it has none yet.
static func campaign_route(table: Dictionary, level_id: StringName, mode: String, sides: Dictionary) -> String:
	var side: String = str(sides.get(String(level_id), ""))
	if side != "":
		return side if table.has(side) else ""
	for file: String in ["%s.expert.inputs" % level_id, "%s.inputs" % level_id] if mode == EXPERT \
			else ["%s.inputs" % level_id]:
		if not table.has(file):
			continue
		var spec: Dictionary = table[file]
		if str(spec["level"]) == String(level_id) and (spec["modes"] as Array).has(mode) \
				and str(spec.get("leaves", "")) != "" and int(spec.get("belt", -1)) < 0:
			return file
	return ""


## Play book `book` on `mode` in ONE run through Flow, as the map leads (DESIGN.md A.1: score, lives, letters, hand
## and belt carried from stage to stage; a co-op run of `party` heroes plays the co-op files, Flow passing over a stop
## that has none yet): every stage with its campaign route (campaign_route; `sides` names side routes such as a warp),
## linked stages and bonus stages as Flow starts them, every tally, every map stop. Each stage must end the way its
## header says without a death (solo) or a team wipe and a death (co-op), without a lost life and without an engine
## warning or error; each map stop is recorded once in the run's save space. The run stops - PENDING, not failed - at
## the first stage without its route; `strict` (G3) fails that, and a run of a complete design must end at the expert
## wall (Beginner, when the book has Expert stops) or at The End with the book completed (Expert). Returns {"files":
## the routes played, "stops": map stops entered, "pending": "" or why it stopped, "passed_over": the design's stops
## the run could not meet because their file (co-op file) is not there yet (design_missing), "screen": the last screen,
## "ticks": ticks played}.
func play_campaign(book: int, mode: String, party: int, sides: Dictionary = {}, strict: bool = false) -> Dictionary:
	var coop: bool = party > 1
	var difficulty: int = Defs.Difficulty.EXPERT if mode == EXPERT else Defs.Difficulty.BEGINNER
	var game_mode: int = Defs.GameMode.COOP if coop else Defs.GameMode.SINGLE
	var run_name: String = "campaign %s book %d %s" % ["co-op" if coop else "solo", book, mode]
	var table: Dictionary = header_table(ROUTE_DIR, func(_file: String, spec: Dictionary) -> bool:
		return (spec["errors"] as PackedStringArray).is_empty() and (int(spec.get("players", 1)) == party))
	var outcome: Dictionary = {"files": [], "stops": [], "pending": "",
		"screen": &"", "ticks": 0}
	Save.reset()
	_watch_events()
	Flow.play_mode = game_mode
	Flow.play_book = book
	Game.start_run(difficulty, game_mode, party, book)
	Game.helper_mode = false
	var space_key: String = Flow.save_space()
	var campaign: Array[StringName] = Levels.get_coop_campaign(difficulty, book) if coop \
			else Levels.get_campaign(difficulty, book)
	if campaign.is_empty():
		outcome["pending"] = "book %d has no %s stop yet" % [book, "co-op" if coop else "solo"]
	else:
		await _enter_stop(Levels.get_coop_base(campaign[0]) if coop else campaign[0], outcome)
	var steps: int = 0
	while outcome["pending"] == "" and steps < 128:
		steps += 1
		if Flow.current_screen == Flow.SCREEN_LEVEL and Game.level != null:
			var level_id: StringName = Game.level_id
			var file: String = campaign_route(table, level_id, mode, sides)
			if file == "":
				outcome["pending"] = "%s has no %s route for this run yet" % [level_id, mode]
				break
			if not await _play_campaign_stage(run_name, file, mode, table, outcome):
				return outcome
		elif Flow.current_screen == Flow.SCREEN_TALLY:
			Flow.finish_tally()
			await _settle_flow()
		elif Flow.current_screen == Flow.SCREEN_WORLD_MAP:
			var stop: StringName = StringName(str(Flow.args.get("level_id", "")))
			assert_true(Save.is_level_unlocked_in(space_key, stop), "%s: the map's stop %s is unlocked" % [run_name, stop])
			await _enter_stop(stop, outcome)
		else:
			break
	outcome["screen"] = Flow.current_screen
	# A run that reached its end screen may still have passed over stops whose file has not landed (the registry and
	# Flow leave them out): that is PENDING too, never a whole book.
	var missing: PackedStringArray = design_missing(book, coop, difficulty)
	outcome["passed_over"] = missing
	print("    %s: %d stage(s), %d ticks (%.1f min), score %d, lives %d, screen %s%s%s\n      routes: %s" % [run_name,
		(outcome["files"] as Array).size(), outcome["ticks"], int(outcome["ticks"]) / Tuning.TICK_HZ / 60.0,
		Game.score, Game.lives, Flow.current_screen,
		"" if outcome["pending"] == "" else " - PENDING: %s" % outcome["pending"],
		"" if missing.is_empty() else " - PENDING, passed over (file not there yet): %s" % ", ".join(missing),
		", ".join(PackedStringArray(outcome["files"]))])
	if strict and not missing.is_empty() and outcome["pending"] == "":
		fail("%s passes over stops whose file is not there: %s" % [run_name, ", ".join(missing)])
	for stop: StringName in outcome["stops"]:
		var cleared: int = int(Save.get_level_result_in(space_key, stop).get("clears", 0))
		var waiting: bool = outcome["pending"] != "" and stop == (outcome["stops"] as Array).back()
		if not waiting:
			assert_eq(cleared, 1, "%s: map stop %s recorded once" % [run_name, stop])
	if outcome["pending"] != "":
		if strict:
			fail("%s stops at: %s" % [run_name, outcome["pending"]])
		return outcome
	assert_true(CAMPAIGN_ENDS.has(Flow.current_screen), "%s ends at the expert wall or The End, not %s" % [run_name,
			Flow.current_screen])
	if design_complete(book, coop):
		var wall: bool = mode != EXPERT and not Levels.get_campaign(Defs.Difficulty.EXPERT, book).all(
				func(id: StringName) -> bool: return Levels.is_available(id, Defs.Difficulty.BEGINNER))
		assert_eq(Flow.current_screen, Flow.SCREEN_EXPERT_WALL if wall else Flow.SCREEN_THE_END, "%s: how it ends" % run_name)
		assert_eq(Save.is_game_completed_in(space_key), not wall, "%s: the book is completed only by The End" % run_name)
	return outcome


## Enter map stop `stop` the way the map does (Flow.start_level; in co-op Flow plays its co-op file), with the clock
## under the test's control; a map that started the level by itself is left as it is.
func _enter_stop(stop: StringName, outcome: Dictionary) -> void:
	Sim.manual = true
	await _settle_flow()
	if Flow.current_screen != Flow.SCREEN_LEVEL:
		Flow.start_level(stop, Defs.Transition.NONE)
		await _settle_flow()
	(outcome["stops"] as Array).append(stop)
	if Flow.current_screen != Flow.SCREEN_LEVEL or Game.level == null:
		outcome["pending"] = "map stop %s did not start (screen %s)" % [stop, Flow.current_screen]
		return
	var level: Level = Game.level as Level
	if level != null:
		level.set_view_size(Vector2i(Tuning.VIEW_W, Tuning.VIEW_H) * Tuning.ART_SCALE)


## One stage of a campaign run: route `file` in the stage that runs now, with what the run carries; false ends the run
## (the stage did not play).
func _play_campaign_stage(run_name: String, file: String, mode: String, table: Dictionary, outcome: Dictionary) -> bool:
	var spec: Dictionary = table[file]
	var label: String = "%s: %s" % [run_name, file]
	var party: bool = int(spec.get("players", 1)) > 1
	var lives: int = Game.lives
	_reset_watch(Game.level_id, mode)
	_start_counting_problems()
	var result: Dictionary = await runner().replay_stage(file, mode, {"routes": table, "on_tick": _on_tick,
			"keep": true})
	_stop_counting_problems()
	var played: int = stage_ticks(result.get("lines", PackedStringArray()))
	(outcome["files"] as Array).append(file)
	outcome["ticks"] = int(outcome["ticks"]) + maxi(played, 0)
	print("    %s: %d ticks, score %d, lives %d, hurt %d, deaths %d, eggs %d, weapon %s / belt %s, screen %s" % [
		label, played, Game.score, Game.lives, _count(&"hero_hurt" if party else &"player_hurt"),
		_count(&"hero_died" if party else &"player_died"), _count(&"hero_down"), Defs.weapon_name(Game.runs[0].weapon),
		Defs.weapon_name(Game.runs[0].belt) if Game.runs[0].belt >= 0 else "-", Flow.current_screen])
	assert_true(played > 0, "%s played" % label)
	if played <= 0:
		outcome["pending"] = "%s did not play" % file
		return false
	var expect: Dictionary = spec.get("expect", {})
	assert_eq(_count(&"hero_died" if party else &"player_died"), int(expect.get("deaths", 0)), "%s: deaths" % label)
	if party:
		assert_eq(_count(&"party_wiped"), 0, "%s: no team wipe" % label)
		assert_eq(_doze_problem, "", "%s: no entity dozes inside a view or within reach of a hero (V3.e)" % label)
		assert_eq(_idle_problem, "", "%s: no hero stands idle (LEVEL_DESIGN 15.7.9)" % label)
	assert_eq(weak_point_verdict(), "", "%s: every boss weak point stays in the view and clear of the fight HUD (G35)" % label)
	assert_true(Game.lives >= lives, "%s: no life lost (%d -> %d)" % [label, lives, Game.lives])
	assert_eq(_problems.count, 0, "%s: no engine warning or error (first: %s)" % [label, _problems.first])
	assert_eq(int(result.get("input_mismatches", 0)), 0, "%s: every slot read its stream" % label)
	_check_after(label, spec, mode)
	var ends: Array[StringName] = [StringName(str(spec.get("leaves", "")))]
	if _exit_kinds != ends:
		outcome["pending"] = "%s did not end the stage" % file
		return false
	return true


func _settle_flow() -> void:
	for i: int in 3:
		await get_tree().process_frame
	while Flow.busy:
		await get_tree().process_frame


# =================================================================================================================
# Watching a stage
# =================================================================================================================

func _reset_watch(level_id: StringName, mode: String) -> void:
	_counts.clear()
	# The lives baseline is taken on the stage's first tick (_on_tick), after the replay started the run: a value
	# an earlier test file left in Game.lives must not become the baseline (a co-op run starts with 2 tribe lives).
	_lives_pending = true
	_doze_problem = ""
	_idle_problem = ""
	_letters.clear()
	_paintings.clear()
	_jackpots = 0
	_words = 0
	_boss_hits = 0
	_boss_up = -1
	_boss_down = -1
	_glider_carried = false
	_glider_flown = false
	_exit_kinds.clear()
	_max_wind = 0
	_start_view_y = -1
	_deepest_view_y = 0
	_embers_seen.clear()
	_embers_close.clear()
	_gates_reached.clear()
	_weak_problem = ""
	_weak_problem_free = ""
	_weak_locked_ticks = 0
	_weak_fight_ticks = 0
	_tablets = _x2_tablets(level_id, BEGINNER if mode != EXPERT else EXPERT)


## The x2 tablets of a level on a difficulty: [gate name (or "secret@c,r"), far cell].
func _x2_tablets(level_id: StringName, mode: String) -> Array[Array]:
	var tablets: Array[Array] = []
	if not Levels.has_level(level_id):
		return tablets
	var data: LevelData = LevelData.load_file(Levels.get_level_path(level_id))
	if data == null:
		return tablets
	var difficulty: int = Defs.Difficulty.EXPERT if mode == EXPERT else Defs.Difficulty.BEGINNER
	for record: Dictionary in data.entity_records():
		if StringName(str(record["id"])) != TABLET_ID:
			continue
		var params: Dictionary = record["params"]
		if not LevelText.applies_to(params, difficulty):
			continue
		var far: PackedStringArray = str(params.get("far", "")).replace(" ", "").split(",")
		if far.size() != 2 or not far[0].is_valid_int() or not far[1].is_valid_int():
			continue
		var gate: String = str(params.get("gate", "secret@%d,%d" % [int(record["col"]), int(record["row"])]))
		tablets.append([gate, Vector2i(far[0].to_int(), far[1].to_int())])
	return tablets


## Per tick of the replay (sim_bench_runner on_tick): the watchers of the expect keys that are not events.
func _on_tick(level: LevelBase, stage_tick: int) -> void:
	if _lives_pending:
		_lives_pending = false
		_counts[&"_lives"] = Game.lives
	if level.hero_count() > 1 and _doze_problem == "":
		_check_party_doze(level, stage_tick)
	if level.hero_count() > 1 and _idle_problem == "":
		_check_party_idle(level, stage_tick)
	_max_wind = maxi(_max_wind, level.wind)
	var view_y: int = level.get_view_rect().position.y
	if _start_view_y < 0:
		_start_view_y = view_y
	_deepest_view_y = maxi(_deepest_view_y, view_y)
	if _boss_up < 0 and _count(&"boss_started") > 0:
		_boss_up = stage_tick
	if _boss_down < 0 and _count(&"boss_defeated") > 0:
		_boss_down = stage_tick
	if _boss_up >= 0 and _boss_down < 0 and _weak_points_apply(level.level_id):
		_weak_fight_ticks += 1
		_check_weak_points(level, stage_tick)
	for hero: PlayerBase in level.contact_order():
		if hero.dead:
			continue
		var cell: Vector2i = Vector2i(hero.sim_pos.x >> 4, (hero.sim_pos.y - 1) >> 4)
		for tablet: Array in _tablets:
			if cell == tablet[1]:
				_gates_reached[tablet[0]] = true
	for entity: SimEntity in level.get_kind(Defs.Kind.ENEMY_PROJECTILE):
		if not entity is EnemyEmber:
			continue
		var id: int = entity.get_instance_id()
		_embers_seen[id] = true
		for hero: PlayerBase in level.contact_order():
			var rel: Vector2i = entity.sim_pos - hero.sim_pos
			if absi(rel.x) < 24 and rel.y > -56 and rel.y < 8:
				_embers_close[id] = true


## G35 is a rule of the 2.0 content: Book II stages and every co-op file (the co-op Brute and visor Colossus of Book I
## included). Book I's solo stages are frozen 1.0 (the Brute of w2_l2b walks out of its unlocked view, as in 1.0).
static func _weak_points_apply(level_id: StringName) -> bool:
	return Levels.is_coop_level(level_id) or Levels.get_book(level_id) == Levels.BOOK_2


## G35: every weak point of every living boss that can be struck this tick (Hud.weak_point_rects: logical px, world
## coordinates; an empty rect is one that cannot be struck now) lies wholly inside the view and the clearance under the
## fight HUD band (Hud.weak_point_problem, art px in view coordinates, the touch margin: every device). Keeps the first
## problem of a settled locked view in _weak_problem and the first of an unlocked view in _weak_problem_free (see
## [method weak_point_verdict]); ticks while the camera glides into its lock are not checked.
func _check_weak_points(level: LevelBase, stage_tick: int) -> void:
	if _hud == null:
		_hud = load(HUD_SCRIPT) as GDScript if ResourceLoader.exists(HUD_SCRIPT) else null
		if _hud == null or not _hud.can_instantiate():
			_weak_problem = "the HUD script %s does not load (its weak-point check cannot run)" % HUD_SCRIPT
			_weak_locked_ticks = maxi(_weak_locked_ticks, 1)
			return
	var view: Rect2i = level.get_view_rect()
	var locked: bool = level.is_camera_locked()
	if locked:
		if not view_settled_in_lock(view, level.get_camera_lock()):
			return
		_weak_locked_ticks += 1
		if _weak_problem != "":
			return
	elif _weak_problem_free != "":
		return
	var view_art: Vector2 = Vector2(view.size * Tuning.ART_SCALE)
	for entity: SimEntity in level.get_kind(Defs.Kind.BOSS):
		var boss: EnemyBase = entity as EnemyBase
		if boss == null or boss.dead:
			continue
		for rect: Rect2i in _hud.call("weak_point_rects", boss):
			var art: Rect2 = Rect2(Vector2((rect.position - view.position) * Tuning.ART_SCALE),
					Vector2(rect.size * Tuning.ART_SCALE))
			var problem: String = str(_hud.call("weak_point_problem", art, view_art))
			if problem != "":
				var text: String = "%s on tick %d: weak rect %s (world) in %s view %s: %s" % [boss.name, stage_tick,
						str(rect), "the locked" if locked else "an unlocked", str(view), problem]
				if locked:
					_weak_problem = text
				else:
					_weak_problem_free = text
				return


## True when `view` has settled into camera lock `lock` (both logical px): on each axis the view lies inside the
## lock, or - where the lock is the smaller - the lock lies inside the view. A camera outside its lock glides in.
static func view_settled_in_lock(view: Rect2i, lock: Rect2i) -> bool:
	for axis: int in 2:
		var v0: int = view.position[axis]
		var v1: int = view.end[axis]
		var l0: int = lock.position[axis]
		var l1: int = lock.end[axis]
		var inside: bool = (v0 >= l0 and v1 <= l1) if lock.size[axis] >= view.size[axis] else (l0 >= v0 and l1 <= v1)
		if not inside:
			return false
	return true


## G35's verdict for the route just played: "" or the first problem - of the settled locked view when the fight had
## one, else of the unlocked view (a boss fought without a camera lock is checked on every tick).
func weak_point_verdict() -> String:
	return _weak_problem if _weak_locked_ticks > 0 else _weak_problem_free


## PLAN.md 8 V3.e: on a party route no entity dozes while its doze area overlaps a view grown by
## Tuning.DOZE_VIEW_REACH_PX or a hatched hero's box and feet point grown by Tuning.DOZE_HERO_REACH_PX (the doze
## manager snaps its rectangles outwards, so an overlap with these is an overlap with its own). Keeps the first problem.
func _check_party_doze(level: LevelBase, stage_tick: int) -> void:
	var near: Array[Rect2i] = []
	for i: int in level.get_view_count():
		near.append(level.get_view_rect_at(i).grow(Tuning.DOZE_VIEW_REACH_PX))
	for hero: PlayerBase in level.heroes:
		if hero == null or hero.dead or hero.is_down():
			continue
		var box: Rect2i = Rect2i(hero.sim_pos.x - hero.box_xo, hero.sim_pos.y - hero.box_h, maxi(hero.box_w, 1),
				maxi(hero.box_h, 1)).merge(Rect2i(hero.sim_pos, Vector2i.ONE))
		near.append(box.grow(Tuning.DOZE_HERO_REACH_PX))
	for kind: int in Defs.Kind.values():
		for entity: SimEntity in level.get_kind(kind):
			if entity == null or not entity.is_dozing():
				continue
			var area: Rect2i = entity.call(&"_doze_area")
			for rect: Rect2i in near:
				if area.intersects(rect):
					_doze_problem = "%s at %s dozes on tick %d (area %s, near %s)" % [entity.name, str(entity.sim_pos),
						stage_tick, str(area), str(rect)]
					return


## docs/LEVEL_DESIGN.md 15.7.9 ("no role waits 243+ ticks without input"; D9b's finding, wf9_d9b_to_integration.txt
## #3): on a party route no hero is IDLE in the middle of the stage. PlayerBase.is_idle() itself cannot be the check:
## every hero is idle by definition from the level's first tick until his own first input. So it takes the 'since
## first input' form - a hero's quiet ticks (PlayerBase.input_idle_ticks: counted from his entry into the level and
## again from each input of his own slot; a held key is input on every tick it is held, G58) never reach
## PlayerBase.IDLE_TICKS. That is the hero who played and then stood still for 243 ticks (the engine draws him dozing
## and counts him for no plate, hop, brace or tablet - the replay only still works by luck), and also the one who never
## touched a key in the stage's first 243 ticks. A dead hero and an egg are not asked (nobody plays them; the count
## goes on, so a hero who hatches after a long silence is idle - and reported - until his player presses a key). Keeps
## the first problem ([method idle_verdict]).
func _check_party_idle(level: LevelBase, stage_tick: int) -> void:
	for hero: PlayerBase in level.heroes:
		if hero == null or hero.dead or hero.is_down():
			continue
		if hero.input_idle_ticks >= PlayerBase.IDLE_TICKS:
			_idle_problem = "P%d is idle on tick %d: %d ticks without input of his own %s (at %s) - %s" % [
				hero.slot + 1, stage_tick, hero.input_idle_ticks,
				"since his last one" if hero.gave_input else "since the stage began", str(hero.sim_pos),
				"hold Down or tap a key on such a stretch"]
			return


## The idle check's verdict for the stage just played: "" or the first hero found idle (tests).
func idle_verdict() -> String:
	return _idle_problem


func _watch_events() -> void:
	if not _connections.is_empty():
		return
	for info: Dictionary in Events.get_signal_list():
		var signal_name: StringName = StringName(str(info["name"]))
		var callable: Callable = _on_event.bind(signal_name)
		var arguments: int = (info["args"] as Array).size()
		_connect(Signal(Events, signal_name), callable.unbind(arguments) if arguments > 0 else callable)
	_connect(Events.item_collected, _on_item)
	_connect(Events.enemy_hit, _on_enemy_hit)
	_connect(Events.glider_state_changed, _on_glider)
	_connect(Events.exit_reached, _on_exit)
	_connect(Events.painting_found, _on_painting)
	_connect(Game.letters_completed, _on_word)


func _connect(signal_ref: Signal, callable: Callable) -> void:
	signal_ref.connect(callable)
	_connections.append([signal_ref, callable])


func _start_counting_problems() -> void:
	_stop_counting_problems()
	_problems = ProblemCounter.new()
	OS.add_logger(_problems)
	_counting = true


## Stop counting; the counts stay readable in _problems.
func _stop_counting_problems() -> void:
	if _counting:
		OS.remove_logger(_problems)
		_counting = false


func _count(signal_name: StringName) -> int:
	return int(_counts.get(signal_name, 0))


func _on_event(signal_name: StringName) -> void:
	_counts[signal_name] = _count(signal_name) + 1


func _on_item(item_id: StringName, index: int, _points: int, _pos: Vector2i) -> void:
	if item_id == &"items/letter":
		_letters[index] = true
	elif item_id == &"items/jackpot":
		_jackpots += 1


func _on_enemy_hit(enemy: EnemyBase, _power: int) -> void:
	if enemy is BossBase:
		_boss_hits += 1


func _on_glider(carrying: bool, gliding: bool) -> void:
	_glider_carried = _glider_carried or carrying
	_glider_flown = _glider_flown or gliding


func _on_exit(exit_kind: StringName) -> void:
	_exit_kinds.append(exit_kind)


func _on_painting(index: int) -> void:
	_paintings[index] = true


func _on_word() -> void:
	_words += 1


# How the stage ended and what followed (`ends`, `after`).
func _check_after(label: String, spec: Dictionary, _mode: String) -> void:
	var leaves: String = str(spec.get("leaves", ""))
	if leaves == "":
		return
	assert_eq(_exit_kinds, [StringName(leaves)] as Array[StringName], "%s leaves through its %s" % [label, leaves])
	var after: String = str(spec.get("after", ""))
	if after == "tally":
		assert_eq(Flow.current_screen, Flow.SCREEN_TALLY, "%s: the tally follows" % label)
	elif after.begins_with("level:"):
		assert_eq(Flow.current_screen, Flow.SCREEN_LEVEL, "%s: a stage follows without a tally" % label)
		assert_eq(Game.level_id, StringName(after.get_slice(":", 1)), "%s leads into %s" % [label, after])


# A tally that leads to the expert wall or The End (`after=expert_wall` / `after=the_end`).
func _check_tally(label: String, spec: Dictionary, mode: String) -> void:
	var targets: Dictionary = spec.get("tally_to", {})
	if not targets.has(mode) or Flow.current_screen != Flow.SCREEN_TALLY:
		return
	Flow.finish_tally()
	for i: int in 3:
		await get_tree().process_frame
	while Flow.busy:
		await get_tree().process_frame
	match str(targets[mode]):
		"expert_wall":
			assert_eq(Flow.current_screen, Flow.SCREEN_EXPERT_WALL, "%s: the expert wall follows" % label)
		"the_end":
			assert_eq(Flow.current_screen, Flow.SCREEN_THE_END, "%s: The End follows" % label)


func _print_outcome(label: String, played: int) -> void:
	print("    %s: %d ticks, score %d, lives %d, hurt %d, deaths %d, eggs %d, wipes %d, paintings %s, x2 gates %d" % [
		label, played, Game.score, Game.lives, _count(&"hero_hurt"), _count(&"hero_died"), _count(&"hero_down"),
		_count(&"party_wiped"), str(_paintings.keys()), _gates_reached.size()])
	if _weak_fight_ticks > 0:
		print("      G35: %d fight tick(s), %s" % [_weak_fight_ticks, "%d in the settled locked view" % _weak_locked_ticks
				if _weak_locked_ticks > 0 else "no camera lock - every one checked"])
