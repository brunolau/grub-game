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
