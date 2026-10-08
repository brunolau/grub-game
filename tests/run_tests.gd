extends SceneTree
## Headless test runner (docs/ARCHITECTURE.md 9.1). Owner: core.
##
## Usage (from the project root; run `--import` once after a fresh checkout so global classes are known):
##   godot --headless --path . -s res://tests/run_tests.gd
##   godot --headless --path . -s res://tests/run_tests.gd -- --filter=player     (file names containing "player")
##   godot --headless --path . -s res://tests/run_tests.gd -- --verbose           (list every passing test)
##   godot --headless --path . -s res://tests/run_tests.gd -- --filter=campaign --only=world_2   (only the test
##       methods whose name contains "world_2"; with gd.sh: bash .tools/gd.sh test campaign --only=world_2)
##   godot --headless --path . -s res://tests/run_tests.gd -- --user-dir=res://build/test_user_2   (parallel runs)
##   godot --headless --path . -s res://tests/run_tests.gd -- --slow   (also the slow modules; with gd.sh:
##       GD_TIMEOUT=4000 bash .tools/gd.sh test --slow - or each by name, in parallel:
##       bash .tools/gd.sh test campaign_routes / book2_routes / coop_routes, GD_TIMEOUT=3600 ... test coop_gates
##       (COOP_GATES_SHARD=<i>/<n> splits it), GD_TIMEOUT=1800 ... test versus_bots)
##   godot --headless --path . -s res://tests/run_tests.gd -- --slow-tests   (ONLY the slow tests of SLOW_TESTS; with
##       gd.sh: GD_TIMEOUT=1200 bash .tools/gd.sh test --slow-tests - tools/g3.sh runs it at every gate)
##
## Slow modules (docs/expansion/PLAN.md 8 V7: the default run stays under about 5 minutes; a slow module runs at every
## gate and before every merge that touches its area): SLOW_FILES are left out of a run - a `skip` line names each one
## - unless the run has --slow or a filter that names the module: the filter holds its whole name after "test_"
## (bash .tools/gd.sh test coop_gates, --filter=test_coop_gates.gd). A filter that only touches it (`coop`, `gates`)
## runs the other files it matches and skips the slow one, so a module's quick check never pays for the slow search.
## The summary ends with a SKIPPED line when slow modules were left out ([method discover_files] is the rule; the
## test tests/test_core_runner.gd keeps it).
## Slow tests (the same budget, since the G3 follow-up round): SLOW_TESTS names single test methods of files that stay
## in the default run - some fifteen searches, fairness sweeps and whole-table loops that took most of the time of
## their seven files, whose other 200 tests stay where they were. They follow the rule of the slow modules: left out
## - a `skip` line each, one SKIPPED line in the summary - unless the run has --slow or a filter that names their
## file's module (bash .tools/gd.sh test core_bots runs every test of test_core_bots.gd); --slow-tests runs them and
## nothing else ([method skips_slow_tests] is the rule; tests/test_integration_g3.gd keeps it and the list). A test
## that is on no list and takes more than LONG_TEST_SECONDS gets a `note:` line and a NOTE line in the summary.
##
## Discovers `res://tests/test_*.gd`, runs every `test_*` method of each file (see TestCase) and exits with
## code 0 when everything passed, 1 otherwise. Any engine error logged while a test runs fails that test.
## User data (save, settings) is redirected to res://build/test_user so tests never touch real saves.
## Files are isolated from each other: a frozen Sim, a Sim.time_scale other than 1 or a paused tree that a file left
## behind is reset before the next file, with a `note:` line naming the file ([method reset_leaks]).
##
## NOTE: this script is compiled before the autoloads exist, so it must not mention autoload names or project
## classes directly; it reaches them through the scene tree.

const TEST_DIR: String = "res://tests"
const TEST_PREFIX: String = "test_"
const TEST_USER_DIR: String = "res://build/test_user"
## The slow modules (see the header): the solo-impossibility search of every co-op gate (about 1.5 min per gate and
## difficulty since world-B's search v2; 25 min for the 18 gates of G2, growing with every co-op file of phase 3) and
## the versus bot matches on every (arena, mode) (PLAN.md 8 V4.b, core-B; about 12 min at G2, growing with every
## arena) - and, since the G2 integration (PLAN.md V7 names them: `campaign_routes`, `book2`, `coop`), the route
## replays through Flow: every Book I route (test_campaign_routes, about 1-1.5 min), every Book II solo route
## (test_book2_routes, about 1 min and growing to 31 + featured routes) and every two-stream co-op route
## (test_coop_routes, about 1.5 min and growing to 57 routes). The default run keeps the Book I identity guards
## (test_core_players, test_core_book1_frozen; tools/sp_identity.sh replays every Book I route's digest).
## Since the G3 follow-up round (V7: the default run had grown to 410 s) also: the Totem Ring match of classic-keyboard
## humans and rookie bots (one test, a whole match), the layout fairness checks of world 4 (frozen Book I levels,
## hundreds of staircase climbs) - both integration's - and the nav-graph tests of the bots (test_core_bots, core-B:
## every test bakes a test level's graph or needs one baked - the first test that asks pays for it, so leaving only
## the bake tests out just moved their seconds to the next test; about 80 s with the committed graphs baked again.
## The bots in their modes, test_core_bots_modes, stay in the default run).
const SLOW_FILES: PackedStringArray = ["test_book2_routes.gd", "test_campaign_routes.gd", "test_coop_gates.gd",
	"test_coop_routes.gd", "test_core_bots.gd", "test_integration_totem_ring.gd", "test_levels_w4.gd",
	"test_versus_bots.gd"]
## The slow tests (see the header): file -> test methods. Each one is a proof that walks a whole table - every
## campaign code through a level start, a solo search with its probes, a sweep of every jump timing - beside quick
## tests of the same file that stay in the default run, and none shares a costly fixture with them (leaving such a
## test out only moves its seconds to the next test that needs the fixture: a file like that is a slow module). A
## name the file no longer has fails the run (a renamed test must not drift back unnoticed).
const SLOW_TESTS: Dictionary = {
	# The single-hero searches of the co-op boss forms that take seconds (V3.d; the Chieftains' with the idle partner
	# placed everywhere) and the Colossus's rock fairness sweep (enemies-B / enemies-C). The quick ones stay.
	"test_enemies_chieftain.gd": [
		"test_the_single_hero_search_with_an_idle_partner_cannot_beat_the_coop_chieftains"],
	"test_enemies_colossus.gd": ["test_colossus_rocks_can_be_jumped",
		"test_coop_the_single_hero_search_cannot_hurt_the_visor_colossus"],
	"test_enemies_idols.gd": ["test_the_single_hero_search_cannot_crack_the_twin_idols"],
	"test_enemies_roc.gd": ["test_the_single_hero_search_cannot_beat_the_coop_roc"],
	# A stage played in real time, tick by tick (integration).
	"test_integration_flows.gd": ["test_a_real_time_play_starts_on_the_stages_first_tick"],
	# Every campaign code of both books typed in and its level started (ui-A).
	"test_ui_screens.gd": ["test_code_entry_accepts_every_campaign_code"],
	# Real solo searches on test levels (world-B).
	"test_world_validator.gd": ["test_search_measures_the_windows_near_the_gate",
		"test_search_partner_is_idle_and_parked_anywhere_counts_for_nothing",
		"test_search_probes_and_carried_wounds_kill_what_one_move_cannot",
		"test_search_refuses_a_high_ledge_and_finds_a_low_one",
		"test_search_rides_on_an_idle_partner_only_as_the_engine_allows",
		"test_search_settles_the_world_and_shares_changed_worlds",
		"test_search_small_gate_is_exhaustive_and_probed",
		"test_search_world_runs_the_real_doors_and_carries_a_latched_plate"],
}
## A test of the default run that takes longer than this is named in a `note:` line and in the summary (never
## failed): the budget of V7 is spent test by test - at G3 and again in the round after it, searches and bakes added
## to quick files took the default run from under 5 minutes to 6 and 7 - so whoever adds one sees it the same day.
const LONG_TEST_SECONDS: float = 10.0


## Counts engine errors (push_error, script errors, failed engine checks) while a test runs.
class ErrorCounter:
	extends Logger

	var errors: int = 0
	var lines: PackedStringArray = PackedStringArray()

	func _log_error(
			function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool,
			error_type: int, _script_backtraces: Array[ScriptBacktrace]
	) -> void:
		if error_type == Logger.ERROR_TYPE_WARNING:
			return
		errors += 1
		var text: String = rationale if not rationale.is_empty() else code
		lines.append("%s (%s:%d in %s)" % [text, file, line, function])

	func _log_message(_message: String, _error: bool) -> void:
		pass

	func reset() -> void:
		errors = 0
		lines = PackedStringArray()


var _counter: ErrorCounter = ErrorCounter.new()


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	# Let the autoloads finish their _ready.
	await process_frame
	var options: Dictionary = _parse_args(OS.get_cmdline_user_args())
	var filter: String = str(options.get("filter", ""))
	var verbose: bool = options.has("verbose")
	var only: String = str(options.get("only", ""))
	var slow_run: bool = options.has("slow")
	var slow_only: bool = options.has("slow-tests")
	_redirect_user_data(str(options.get("user-dir", TEST_USER_DIR)))
	OS.add_logger(_counter)
	var skipped: PackedStringArray = PackedStringArray()
	var files: PackedStringArray = _discover(filter, slow_run, skipped)
	if slow_only:
		# Only the slow tests: the files that have some (a slow module is not one of them).
		var with_slow_tests: PackedStringArray = PackedStringArray()
		for file: String in files:
			if SLOW_TESTS.has(file):
				with_slow_tests.append(file)
		files = with_slow_tests
		skipped.clear()
	var slow_skipped: PackedStringArray = skipped.duplicate()
	var slow_tests_skipped: PackedStringArray = PackedStringArray()
	var long_tests: PackedStringArray = PackedStringArray()
	var passed: int = 0
	var failed: int = 0
	var failures: PackedStringArray = PackedStringArray()
	var started: int = Time.get_ticks_msec()
	print("Running %d test file(s) from %s" % [files.size(), TEST_DIR])
	for file: String in skipped:
		print("  skip %s (slow module, PLAN.md 8 V7: run with --slow or a filter naming it, e.g. %s)" % [file,
				file.get_basename().trim_prefix(TEST_PREFIX)])
	for file: String in files:
		var path: String = TEST_DIR + "/" + file
		var script: GDScript = load(path) as GDScript
		if script == null or not script.can_instantiate():
			failed += 1
			failures.append("%s: script does not compile" % file)
			print("  FAIL %s (does not compile)" % file)
			continue
		var test: Node = script.new() as Node
		if test == null or not test.has_method("_begin_test"):
			failed += 1
			failures.append("%s: does not extend TestCase" % file)
			print("  FAIL %s (does not extend TestCase)" % file)
			continue
		test.name = file.get_basename()
		root.add_child(test)
		var file_started: int = Time.get_ticks_msec()
		var file_passed: int = 0
		var file_failed: int = 0
		var slow_names: Array = SLOW_TESTS.get(file, [])
		var slow_found: int = 0
		for method: Dictionary in script.get_script_method_list():
			var method_name: String = method["name"]
			if not method_name.begins_with(TEST_PREFIX):
				continue
			var slow_test: bool = slow_names.has(method_name)
			if slow_test:
				slow_found += 1
			if not only.is_empty() and not method_name.contains(only):
				continue
			if slow_only and not slow_test:
				continue
			if slow_test and not slow_only and skips_slow_tests(file, filter, slow_run):
				slow_tests_skipped.append("%s.%s" % [file, method_name])
				print("    skip %s.%s (slow test, PLAN.md 8 V7: run with --slow-tests, --slow or a filter naming %s)" % [
						file, method_name, file.get_basename().trim_prefix(TEST_PREFIX)])
				continue
			_counter.reset()
			var test_started: int = Time.get_ticks_msec()
			test.call("_begin_test")
			test.call("before_each")
			await test.call(method_name)
			test.call("after_each")
			var problems: PackedStringArray = test.call("_end_test", _counter.errors)
			var test_seconds: float = float(Time.get_ticks_msec() - test_started) / 1000.0
			if test_seconds > LONG_TEST_SECONDS and not slow_test and not SLOW_FILES.has(file):
				long_tests.append("%s.%s %.1f s" % [file, method_name, test_seconds])
				print("       note: %s.%s took %.1f s (PLAN.md 8 V7: over %d s - a test for SLOW_TESTS, or a faster fixture)" % [
						file, method_name, test_seconds, int(LONG_TEST_SECONDS)])
			if problems.is_empty():
				file_passed += 1
				if verbose:
					print("    ok   %s.%s" % [file, method_name])
			else:
				file_failed += 1
				for problem: String in problems:
					failures.append("%s.%s: %s" % [file, method_name, problem])
				for line: String in _counter.lines:
					failures.append("%s.%s: engine error: %s" % [file, method_name, line])
		test.free()
		if slow_found != slow_names.size():
			# A slow test that was renamed or removed: the list must follow, or nobody knows which run holds it.
			file_failed += 1
			failures.append("%s: SLOW_TESTS of tests/run_tests.gd names %d test(s), the file has %d of them (%s)" % [
					file, slow_names.size(), slow_found, ", ".join(PackedStringArray(slow_names))])
		passed += file_passed
		failed += file_failed
		var verdict: String = "ok  " if file_failed == 0 else "FAIL"
		print("  %s %s (%d passed, %d failed, %.1f s)" % [verdict, file, file_passed, file_failed,
				float(Time.get_ticks_msec() - file_started) / 1000.0])
		var sim: Node = root.get_node_or_null("Sim")
		if sim != null:
			var leaks: PackedStringArray = reset_leaks(sim, self)
			if not leaks.is_empty():
				print("       note: %s left %s - reset for the next file" % [file, ", ".join(leaks)])
	OS.remove_logger(_counter)
	var seconds: float = float(Time.get_ticks_msec() - started) / 1000.0
	if files.is_empty():
		failed += 1
		failures.append("no test files found (filter '%s')" % filter)
	if not failures.is_empty():
		print("")
		print("Failures:")
		for failure: String in failures:
			print("  - " + failure)
	print("")
	print("TESTS: %d passed, %d failed, %d file(s), %.2f s" % [passed, failed, files.size(), seconds])
	if not slow_skipped.is_empty():
		print("SKIPPED: %s (slow modules)" % ", ".join(slow_skipped))
	if not slow_tests_skipped.is_empty():
		print("SKIPPED: %d slow test(s) (run them with --slow-tests): %s" % [slow_tests_skipped.size(),
				", ".join(slow_tests_skipped)])
	if not long_tests.is_empty():
		print("NOTE: %d test(s) on no slow list took more than %d s each (PLAN.md 8 V7): %s" % [long_tests.size(),
				int(LONG_TEST_SECONDS), ", ".join(long_tests)])
	print("RESULT: %s" % ("PASS" if failed == 0 else "FAIL"))
	# Let the audio server release its playbacks before the engine shuts down (no leak reports).
	var audio: Node = root.get_node_or_null("Audio")
	if audio != null and audio.has_method("shutdown"):
		audio.call("shutdown")
	await create_timer(0.25).timeout
	quit(0 if failed == 0 else 1)


## Isolation between test files (P2.6): the global clock state a file left behind - a frozen Sim (a Flow transition a
## failing test never awaited), a Sim.time_scale other than 1 (a deciding-moment replay), a paused tree - is put back,
## so one file's failure cannot fail the next file's timing tests. Returns what was reset (the runner prints a note
## naming the file); empty when the file cleaned up after itself.
static func reset_leaks(sim: Node, tree: SceneTree) -> PackedStringArray:
	var leaks: PackedStringArray = PackedStringArray()
	if bool(sim.get("frozen")):
		leaks.append("Sim.frozen")
		sim.set("frozen", false)
	var scale: float = float(sim.get("time_scale"))
	if not is_equal_approx(scale, 1.0):
		leaks.append("Sim.time_scale %.2f" % scale)
		sim.set("time_scale", 1.0)
	if tree.paused:
		leaks.append("the tree paused")
		tree.paused = false
	return leaks


func _discover(filter: String, slow: bool, skipped: PackedStringArray) -> PackedStringArray:
	var dir: DirAccess = DirAccess.open(TEST_DIR)
	if dir == null:
		return PackedStringArray()
	return discover_files(dir.get_files(), filter, slow, skipped, SLOW_FILES)


## The test files a run executes, sorted, from the file names of the test folder: every `test_*.gd` except
## test_case.gd whose name contains `filter` (all for ""). A file of `slow_files` runs only with `slow` or when the
## filter names its module - holds its whole name after "test_" (coop_gates, test_coop_gates.gd); otherwise it is
## appended to `skipped` (when the filter matched it, or without a filter).
static func discover_files(names: PackedStringArray, filter: String, slow: bool, skipped: PackedStringArray,
		slow_files: PackedStringArray) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	var sorted: PackedStringArray = names.duplicate()
	sorted.sort()
	for file: String in sorted:
		if not file.begins_with(TEST_PREFIX) or file.get_extension() != "gd" or file == "test_case.gd":
			continue
		if not filter.is_empty() and not file.contains(filter):
			continue
		if slow_files.has(file) and not slow and not filter.contains(file.get_basename().trim_prefix(TEST_PREFIX)):
			skipped.append(file)
			continue
		result.append(file)
	return result


## True when a run leaves the slow tests of `file` (SLOW_TESTS) out: it has no --slow and its filter does not name the
## file's module - hold its whole name after "test_" (core_bots, test_core_bots.gd) - the rule of the slow modules
## ([method discover_files]). A --slow-tests run never asks: it runs the slow tests and nothing else.
static func skips_slow_tests(file: String, filter: String, slow: bool) -> bool:
	return not slow and not filter.contains(file.get_basename().trim_prefix(TEST_PREFIX))


func _parse_args(arguments: PackedStringArray) -> Dictionary:
	var options: Dictionary = {}
	for argument: String in arguments:
		if not argument.begins_with("--"):
			continue
		var body: String = argument.substr(2)
		var eq: int = body.find("=")
		if eq < 0:
			options[body] = ""
		else:
			options[body.substr(0, eq)] = body.substr(eq + 1)
	return options


func _redirect_user_data(user_dir: String) -> void:
	var absolute: String = ProjectSettings.globalize_path(user_dir)
	DirAccess.make_dir_recursive_absolute(absolute)
	for file: String in ["save.json", "save.json.bak", "save.json.tmp", "settings.cfg"]:
		if FileAccess.file_exists(absolute + "/" + file):
			DirAccess.remove_absolute(absolute + "/" + file)
	for autoload: String in ["Save", "Settings"]:
		var node: Node = root.get_node_or_null(autoload)
		if node != null and node.has_method("set_storage_dir"):
			node.call("set_storage_dir", user_dir)
