extends TestCase
## The test runner's slow-module rule (tests/run_tests.gd, docs/expansion/PLAN.md 8 V7): which files a run executes
## and which slow modules it skips, for every way the runner is called.

const RUNNER: String = "res://tests/run_tests.gd"
const NAMES: PackedStringArray = [
	"test_world_tribe.gd", "test_case.gd", "test_coop_gates.gd", "test_coop_routes.gd", "test_core_flow.gd",
	"test_core_flow.gd.uid", "run_tests.gd", "fixtures", "test_versus_bots.gd", "test_campaign_routes.gd",
]
const SLOW: PackedStringArray = ["test_coop_gates.gd", "test_versus_bots.gd"]


func _discover(filter: String, slow: bool, skipped: PackedStringArray) -> PackedStringArray:
	var runner: GDScript = load(RUNNER) as GDScript
	if runner == null:
		return PackedStringArray()
	return runner.call("discover_files", NAMES, filter, slow, skipped, SLOW)


func test_a_plain_run_skips_the_slow_modules_and_names_them() -> void:
	var skipped: PackedStringArray = PackedStringArray()
	assert_eq(_discover("", false, skipped), PackedStringArray(["test_campaign_routes.gd", "test_coop_routes.gd",
			"test_core_flow.gd", "test_world_tribe.gd"]), "sorted; never test_case.gd, a .uid or another file")
	assert_eq(skipped, PackedStringArray(["test_coop_gates.gd", "test_versus_bots.gd"]), "each skip is reported")


func test_slow_runs_everything() -> void:
	var skipped: PackedStringArray = PackedStringArray()
	assert_eq(_discover("", true, skipped).size(), 6)
	assert_true(skipped.is_empty())
	skipped = PackedStringArray()
	assert_eq(_discover("coop", true, skipped), PackedStringArray(["test_coop_gates.gd", "test_coop_routes.gd"]))


func test_a_filter_runs_a_slow_module_only_when_it_names_it() -> void:
	var skipped: PackedStringArray = PackedStringArray()
	assert_eq(_discover("coop_gates", false, skipped), PackedStringArray(["test_coop_gates.gd"]),
			"bash .tools/gd.sh test coop_gates")
	assert_true(skipped.is_empty())
	assert_eq(_discover("test_coop_gates.gd", false, skipped), PackedStringArray(["test_coop_gates.gd"]))
	assert_eq(_discover("coop", false, skipped), PackedStringArray(["test_coop_routes.gd"]),
			"a module's quick check never pays for its slow search")
	assert_eq(skipped, PackedStringArray(["test_coop_gates.gd"]), "... and says so")
	skipped = PackedStringArray()
	assert_eq(_discover("core", false, skipped), PackedStringArray(["test_core_flow.gd"]))
	assert_true(skipped.is_empty(), "a filter that does not touch a slow module reports nothing")
	assert_eq(_discover("versus_bots", false, skipped), PackedStringArray(["test_versus_bots.gd"]))
	assert_eq(_discover("no_such_module", false, skipped).size(), 0)


func test_the_runner_lists_the_slow_modules_of_the_plan() -> void:
	var runner: GDScript = load(RUNNER) as GDScript
	assert_not_null(runner)
	if runner == null:
		return
	var slow: Variant = runner.get_script_constant_map().get("SLOW_FILES")
	assert_true(slow is PackedStringArray)
	if not slow is PackedStringArray:
		return
	assert_true((slow as PackedStringArray).has("test_coop_gates.gd"), "the solo-impossibility search is slow")
	for file: String in slow as PackedStringArray:
		assert_true(FileAccess.file_exists("res://tests/" + file), "%s exists" % file)
		assert_true(file.begins_with("test_") and file.ends_with(".gd"))
