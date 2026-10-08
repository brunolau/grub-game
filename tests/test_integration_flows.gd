extends TestCase
## The flow scripts of tools/autoplay (owner: integration; docs/ARCHITECTURE.md 9.2, docs/expansion/PLAN.md P1.3).
##
## A flow script plays the game the way a player does (scripts/core/dev/autoplay_flow.gd), in a window
## (`gd.sh play --flow=...`) or headless (`gd.sh script res://scripts/core/dev/headless_flow.gd -- --flow=... --fast`);
## the suite does not run them (each is a whole game session), so it checks them statically (the runner's lint): every
## command, action, key, pad
## control, weapon, player number and expression root is known and every `play` input is readable. Every route a flow
## plays and every level it starts must exist - except in a skeleton flow (a `# skeleton:` line), whose stops are
## filled in as the content lands (campaign_b2.flow, campaign_coop.flow; PLAN.md 6.2). The campaign flows play the
## frozen Book I routes untouched, through the title path of 2.0.

const FLOW_DIR: String = "res://tools/autoplay/"
const FLOW_RUNNER: String = "res://scripts/core/dev/autoplay_flow.gd"
const HEADLESS: String = "res://scripts/core/dev/headless_flow.gd"
const ROUTE_PREFIX: String = "tools/autoplay/routes/"
const SKELETON_MARK: String = "# skeleton:"
## Where the in-process runs of the runner's own tests write their trace.
const RUNNER_OUT: String = "res://build/test_integration_flows"
## The flows the 2.0 plan names (PLAN.md P1.3).
const PLAN_FLOWS: PackedStringArray = [
	"campaign.flow", "campaign_beginner.flow", "campaign_b2.flow", "campaign_coop.flow",
]


func _flows() -> PackedStringArray:
	var flows: PackedStringArray = PackedStringArray()
	for file: String in DirAccess.get_files_at(FLOW_DIR):
		if file.get_extension() == "flow":
			flows.append(file)
	flows.sort()
	return flows


func _lint(file: String) -> Dictionary:
	return (load(FLOW_RUNNER) as GDScript).call("lint", FileAccess.get_file_as_string(FLOW_DIR + file))


func test_every_flow_script_is_well_formed() -> void:
	assert_not_null(load(HEADLESS) as GDScript, "the headless flow launcher compiles")
	var flows: PackedStringArray = _flows()
	for file: String in PLAN_FLOWS:
		assert_true(flows.has(file), "%s exists" % file)
	for file: String in flows:
		var text: String = FileAccess.get_file_as_string(FLOW_DIR + file)
		var report: Dictionary = _lint(file)
		assert_eq(report["errors"], PackedStringArray(), "%s: well formed" % file)
		if text.contains(SKELETON_MARK):
			for line: String in report["missing"]:
				print("    %s (skeleton): not there yet: %s" % [file, line])
		else:
			assert_eq(report["missing"], PackedStringArray(), "%s: every route and level exists" % file)
	print("    %d flow script(s)" % flows.size())


## The lint itself: it finds what would stop a flow in the window.
func test_the_lint_reports_broken_lines() -> void:
	var report: Dictionary = (load(FLOW_RUNNER) as GDScript).call("lint", "\n".join([
		"# a comment", "", "wait 10", "wiat 10", "wait ten", "press ui_nowhere", "key Enter NoSuchKey", "pad zz",
		"input device 9", "weapon sword", "play 8:R|L,4:XQ", "play_file tools/autoplay/routes/zz_none.inputs",
		"expect nobody.score == 1", "expect game.score >< 1", "start_level zz_nowhere players=2", "start_level w1_l1 hard",
		"focus sideways", "quit now", "expect hero2.sim_pos:x > 3", "wait_until flow.busy == false 600",
	]))
	var errors: PackedStringArray = report["errors"]
	var expected: PackedStringArray = [
		"line 4:", "line 5:", "line 6:", "line 7:", "line 8:", "line 9:", "line 10:", "line 11:", "line 13:",
		"line 14:", "line 16:", "line 17:", "line 18:",
	]
	assert_eq(errors.size(), expected.size(), "\n".join(errors))
	for i: int in mini(errors.size(), expected.size()):
		assert_true(errors[i].begins_with(expected[i]), "%s: %s" % [expected[i], errors[i]])
	assert_eq(report["missing"], PackedStringArray([
		"line 12: route tools/autoplay/routes/zz_none.inputs", "line 15: level zz_nowhere"]))


## The commands of phase 3 in the lint: `need` lists what is missing (a level id or a route path), `section`,
## `wait_ms` and `expect_errors` are known.
func test_the_lint_knows_need_and_section() -> void:
	var report: Dictionary = (load(FLOW_RUNNER) as GDScript).call("lint", "\n".join([
		"need w1_l1 tools/autoplay/routes/w1_l1.inputs", "need zz_nowhere tools/autoplay/routes/zz_none.inputs",
		"section expert", "wait_ms 250", "wait_ms soon", "expect_errors 1", "section",
	]))
	assert_eq(report["missing"], PackedStringArray([
		"line 2: level zz_nowhere", "line 2: route tools/autoplay/routes/zz_none.inputs"]))
	var errors: PackedStringArray = report["errors"]
	assert_eq(errors.size(), 2, "\n".join(errors))
	if errors.size() == 2:
		assert_true(errors[0].begins_with("line 5:"), errors[0])
		assert_true(errors[1].begins_with("line 7:"), errors[1])


## wf8_g2_verify #3: a `play` in a real-time flow starts on the stage's first tick, however long the commands before
## it took - the runner holds the new stage's clock until the `play` - so a route replays tick for tick as with
## --fast. 400 ms on a fresh stage would be about ten ticks of its own clock without the hold.
func test_a_real_time_play_starts_on_the_stages_first_tick() -> void:
	var script: String = "\n".join([
		"start_level test_integration", "wait_ms 400", "expect sim.tick == 0", "play 30:R,8:RU,24:R,6:,10:L", "quit",
	])
	var fast: Dictionary = await _run_flow(script, true)
	var real_time: Dictionary = await _run_flow(script, false)
	for run: Dictionary in [fast, real_time]:
		assert_eq(int(run["exit_code"]), 0, "the flow passes: %s" % str(run["failures"]))
		assert_eq(int(run["checks"]), 2, "the stage's clock stood still until the play")
	var rows_fast: Array = fast["trace"]
	var rows_real: Array = real_time["trace"]
	# Real time may run one more (idle) tick in the frame that ends the play: the play's ticks are compared.
	assert_eq(rows_fast.size(), 78, "--fast played every entry of the play")
	assert_true(rows_real.size() >= rows_fast.size(), "real time played every entry (%d ticks)" % rows_real.size())
	if rows_real.is_empty() or rows_fast.is_empty():
		return
	assert_eq(int(rows_real[0][2]), 1, "the play's first entry is the stage's tick 1")
	var differences: int = 0
	for i: int in mini(rows_fast.size(), rows_real.size()):
		# [frame, level, tick, x, y, xvel, yvel, state, dead]: everything but the frame must agree.
		if (rows_fast[i] as Array).slice(1) != (rows_real[i] as Array).slice(1):
			differences += 1
			if differences == 1:
				fail("real time differs from --fast at row %d: %s / %s" % [i, str(rows_real[i]), str(rows_fast[i])])
	assert_eq(differences, 0, "the real-time trace is the --fast trace")


## The hold is anchored to EVERY stage start, not only the flow's first: a second stage started in the same run (as
## the campaign flows meet stage after stage) waits for its own `play` too, and both plays replay as with --fast.
func test_a_real_time_play_anchors_every_stage_of_a_run() -> void:
	var stage: PackedStringArray = ["start_level test_integration", "wait_ms 300", "expect sim.tick == 0"]
	var script: String = "\n".join(stage + PackedStringArray(["play 20:R,8:RU,10:R"]) + stage
			+ PackedStringArray(["play 12:L,8:LU,16:R", "quit"]))
	var fast: Dictionary = await _run_flow(script, true)
	var real_time: Dictionary = await _run_flow(script, false)
	for run: Dictionary in [fast, real_time]:
		assert_eq(int(run["exit_code"]), 0, "the flow passes: %s" % str(run["failures"]))
		assert_eq(int(run["checks"]), 4, "each stage's clock stood still until its play")
	var parts_fast: Array[Array] = _stage_parts(fast["trace"])
	var parts_real: Array[Array] = _stage_parts(real_time["trace"])
	assert_eq(parts_fast.size(), 2, "--fast: two stages")
	assert_eq(parts_real.size(), 2, "real time: two stages")
	# The old stage may run on (idle) while the next start_level covers it: each play's own ticks are compared.
	var lengths: Array[int] = [38, 36]
	for part: int in mini(parts_fast.size(), parts_real.size()):
		var rows_fast: Array = parts_fast[part]
		var rows_real: Array = parts_real[part]
		assert_true(rows_fast.size() >= lengths[part], "--fast played every entry of play %d" % (part + 1))
		assert_true(rows_real.size() >= lengths[part], "real time played every entry of play %d" % (part + 1))
		if rows_real.is_empty() or rows_fast.is_empty():
			continue
		assert_eq(int(rows_fast[0][2]), 1, "--fast: play %d starts on its stage's tick 1" % (part + 1))
		assert_eq(int(rows_real[0][2]), 1, "real time: play %d starts on its stage's tick 1" % (part + 1))
		for i: int in mini(lengths[part], mini(rows_fast.size(), rows_real.size())):
			if (rows_fast[i] as Array).slice(1) != (rows_real[i] as Array).slice(1):
				fail("stage %d: real time differs from --fast at row %d: %s / %s" % [part + 1, i, str(rows_real[i]),
						str(rows_fast[i])])
				break


## Trace rows split where a stage's clock starts again (its tick falls back).
func _stage_parts(rows: Array) -> Array[Array]:
	var parts: Array[Array] = []
	var last_tick: int = 0
	for row: Array in rows:
		if parts.is_empty() or int(row[2]) < last_tick:
			parts.append([])
		last_tick = int(row[2])
		parts[parts.size() - 1].append(row)
	return parts


## wf8_g2_verify #1: an engine error logged while a flow runs fails it, as in the test runner, unless the flow
## announced it with `expect_errors`.
func test_an_engine_error_fails_a_flow() -> void:
	expect_errors(2)
	var failed: Dictionary = await _run_flow("log nobody.score\nquit", true)
	assert_eq(int(failed["exit_code"]), 4, "a script error fails the flow")
	assert_eq((failed["engine_errors"] as PackedStringArray).size(), 1)
	assert_true(" ".join(failed["failures"]).contains("engine error: Autoplay flow: unknown root 'nobody'"),
			str(failed["failures"]))
	var announced: Dictionary = await _run_flow("expect_errors 1\nlog nobody.score\nquit", true)
	assert_eq(int(announced["exit_code"]), 0, "an announced error does not: %s" % str(announced["failures"]))


## `need` in a skeleton flow: a part without its content is skipped up to the next `section` and reported as
## pending (the run passes); in any other flow a missing `need` fails the run.
func test_need_skips_a_part_of_a_skeleton_flow() -> void:
	var part: String = "\n".join([
		"need zz_nowhere", "expect game.score == 123456789", "section next", "expect sim.running == false", "quit",
	])
	var skeleton: Dictionary = await _run_flow("# skeleton: test\n" + part, true)
	assert_eq(int(skeleton["exit_code"]), 0, "a skeleton flow passes: %s" % str(skeleton["failures"]))
	assert_eq((skeleton["pending"] as PackedStringArray).size(), 1, "one part pending")
	assert_eq(int(skeleton["checks"]), 1, "only the next section's check ran")
	var whole: Dictionary = await _run_flow(part, true)
	assert_eq(int(whole["exit_code"]), 4, "a flow without the skeleton mark fails")
	assert_true(" ".join(whole["failures"]).contains("need: zz_nowhere"), str(whole["failures"]))


## A part that stops (here a wait that times out) is cut short like a pending one: the next `section` still runs, so a
## campaign flow reports every part (Book II Beginner and Expert), and the run fails.
func test_a_stopped_part_does_not_stop_the_next_section() -> void:
	var stopped: Dictionary = await _run_flow("\n".join([
		"section first", "wait_until game.score == 123456789 3", "expect game.score == 123456789",
		"section second", "expect sim.running == false", "quit",
	]), true)
	assert_eq(int(stopped["exit_code"]), 4, "the run fails")
	# The timed-out wait is one check, the second part's expect the other; the first part's expect never ran.
	assert_eq(int(stopped["checks"]), 2, "the rest of the first part was skipped, the second part's check ran")
	var failures: String = " ".join(stopped["failures"])
	assert_true(failures.contains("stopped at: wait_until game.score == 123456789 3"), failures)
	assert_false(failures.contains("expect game.score"), "the first part's expect was skipped: %s" % failures)
	assert_false(failures.contains("sim.running"), "the second part passed: %s" % failures)
	assert_eq((stopped["pending"] as PackedStringArray).size(), 0, "a stopped part is a failure, not pending")


## Run flow `text` in-process (the runner of `gd.sh play --flow`, without ending the application) and return its
## result(); the stage it left is freed.
func _run_flow(text: String, fast: bool) -> Dictionary:
	var runner: Node = (load(FLOW_RUNNER) as GDScript).new() as Node
	runner.set("quit_when_done", false)
	runner.name = "FlowRunner"
	add_child(runner)
	var out: String = ProjectSettings.globalize_path(RUNNER_OUT)
	DirAccess.make_dir_recursive_absolute(out)
	runner.call("begin", text, out, fast, false)
	await runner.done
	# The runner is still inside its emission: let its coroutines end before it is freed.
	for i: int in 2:
		await get_tree().process_frame
	var result: Dictionary = runner.call("result")
	runner.free()
	GameInput.clear_scripted()
	GameInput.reset_slots()
	Sim.manual = false
	Sim.stop()
	if get_tree().current_scene != null:
		get_tree().current_scene.free()
		get_tree().current_scene = null
	Flow.current_screen = Flow.SCREEN_BOOT
	Flow.args = {}
	for i: int in 2:
		await get_tree().process_frame
	return result


## campaign.flow (Expert) and campaign_beginner.flow play the frozen Book I routes: every route they play is a 1.0
## route file (no header) that tests/test_campaign_routes.gd ROUTES describes, and they go through the title.
func test_the_book1_campaign_flows_play_the_frozen_routes() -> void:
	var routes: Dictionary = (load("res://tests/test_campaign_routes.gd") as GDScript).get_script_constant_map()["ROUTES"]
	for file: String in ["campaign.flow", "campaign_beginner.flow"]:
		var text: String = FileAccess.get_file_as_string(FLOW_DIR + file)
		assert_false(text.contains(SKELETON_MARK), "%s is a whole flow" % file)
		assert_false(text.contains("start_level"), "%s starts from the title like a player" % file)
		var played: int = 0
		for line: String in text.split("\n"):
			var command: PackedStringArray = line.strip_edges().split(" ", false)
			if command.size() < 2 or command[0] != "play_file":
				continue
			played += 1
			assert_true(command[1].begins_with(ROUTE_PREFIX), "%s: %s is a campaign route" % [file, command[1]])
			var route: String = command[1].trim_prefix(ROUTE_PREFIX)
			assert_true(routes.has(route), "%s: %s is a frozen 1.0 route" % [file, route])
			assert_true(Autoplay.parse_route_header(FileAccess.get_file_as_string("res://" + command[1])).is_empty(),
					"%s: %s has no 2.0 header" % [file, route])
		assert_true(played > 0, "%s plays routes" % file)
