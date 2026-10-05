extends TestCase
## Feast Land bonus stages A / B / C and the Way Home ending (level designer "feast").
##
## Every route script in tools/autoplay/routes is replayed through Flow and the real level scene, tick for tick as
## the windowed autoplay harness plays it (`gd.sh play --autoplay=<id> --inputs-file=...`). A route must leave its
## level the intended way - the spiral staff (items/warp) of a bonus stage, the exit totem of the ending - without
## losing a life, without engine errors or warnings; the secret routes must find their level's secret area.
## The links are checked against the real source levels: each bonus stage's tally ends the level whose warp led in
## (never The End), and the trophy of 4-2's last stage starts the epilogue.

const ROUTES: String = "res://tools/autoplay/routes/"
const BONUS_STAGES: Array[StringName] = [&"bonus_a", &"bonus_b", &"bonus_c"]
const ENDING: StringName = &"ending"
## The main level whose warp leads into each bonus stage (its meta `bonus`), and the map stop before the ending:
## 4-2 itself or its linked sub-stage (the Wall Colossus hall), whose trophy leads here through its meta `next`.
const SOURCES: Dictionary = {&"bonus_a": &"w1_l2", &"bonus_b": &"w2_l1", &"bonus_c": &"w3_l2"}
const ENDING_SOURCE: StringName = &"w4_l2"
## Logical view of the autoplay window (1280 x 720 at integer scale 2): enemies wake by the view.
const VIEW: Vector2i = Vector2i(Tuning.VIEW_W, Tuning.VIEW_H)
## Bonus stages last 45-90 s (at 24.275 ticks per second).
const BONUS_MIN_TICKS: int = 1092
const BONUS_MAX_TICKS: int = 2185
const EVENTS: Array[StringName] = [
	&"player_died", &"player_hurt", &"checkpoint_activated", &"hidden_spot_opened", &"secret_found",
	&"item_collected", &"gate_used",
]

## Counts the warnings the engine logs (the runner only fails a test on errors).
class WarningCounter:
	extends Logger

	var count: int = 0
	var lines: PackedStringArray = PackedStringArray()

	func _log_error(
			function: String, _file: String, _line: int, code: String, rationale: String, _editor_notify: bool,
			error_type: int, _script_backtraces: Array[ScriptBacktrace]
	) -> void:
		if error_type == Logger.ERROR_TYPE_WARNING:
			count += 1
			lines.append("%s (%s)" % [rationale if not rationale.is_empty() else code, function])

	func _log_message(_message: String, _error: bool) -> void:
		pass


var _counts: Dictionary = {}
var _exit_kinds: Array[StringName] = []
var _connections: Array[Array] = []
var _warnings: WarningCounter = null


func after_each() -> void:
	if _warnings != null:
		OS.remove_logger(_warnings)
		_warnings = null
	for connection: Array in _connections:
		var signal_ref: Signal = connection[0]
		if signal_ref.is_connected(connection[1]):
			signal_ref.disconnect(connection[1])
	_connections.clear()
	_counts.clear()
	_exit_kinds.clear()
	GameInput.clear_scripted()
	Sim.manual = false
	Sim.stop()
	if get_tree().current_scene != null:
		get_tree().current_scene.free()
		get_tree().current_scene = null
	Flow.current_screen = Flow.SCREEN_BOOT
	Flow.args = {}


func test_levels_are_valid() -> void:
	var validator: LevelValidator = LevelValidator.new()
	assert_true(validator.add_folder(Levels.LEVEL_DIR) > 0)
	validator.run()
	for level_id: StringName in _all_levels():
		assert_true(Levels.has_level(level_id), "%s exists" % level_id)
		var problems: Array[Dictionary] = validator.problems_of(Levels.get_level_path(level_id))
		var lines: PackedStringArray = PackedStringArray()
		for problem: Dictionary in problems:
			lines.append(LevelValidator.format_problem(problem))
		assert_eq(problems.size(), 0, "%s: no error and no warning\n%s" % [level_id, "\n".join(lines)])


func test_meta_kinds_music_and_passwords() -> void:
	for level_id: StringName in BONUS_STAGES:
		assert_eq(str(Levels.get_value(level_id, "kind")), Levels.KIND_BONUS, "%s is a bonus stage" % level_id)
		assert_eq(str(Levels.get_value(level_id, "biome")), "feast")
		assert_eq(str(Levels.get_value(level_id, "music")), "bonus")
		assert_eq(str(Levels.get_value(level_id, "background")), "feast")
		assert_false(Levels.get_campaign().has(level_id), "%s is no map stop" % level_id)
	assert_eq(str(Levels.get_value(ENDING, "kind")), Levels.KIND_ENDING)
	assert_eq(str(Levels.get_value(ENDING, "biome")), "village")
	assert_eq(str(Levels.get_value(ENDING, "music")), "ending")
	assert_false(Levels.is_available(ENDING, Defs.Difficulty.BEGINNER), "the ending follows 4-2, an Expert level")
	assert_false(Levels.get_campaign().has(ENDING))
	# Bonus stages have no codes: only their source level's warp leads in (a stage started by code has no source
	# level, so its tally would end the game). The Expert-only ending has an Expert code and no Beginner code.
	for level_id: StringName in BONUS_STAGES:
		for difficulty: int in [Defs.Difficulty.BEGINNER, Defs.Difficulty.EXPERT]:
			assert_eq(Levels.get_password(level_id, difficulty), "", "%s has no %s code" % [
					level_id, Defs.difficulty_name(difficulty)])
	assert_eq(Levels.get_password(ENDING, Defs.Difficulty.BEGINNER), "", "no Beginner code for an Expert level")
	var code: String = Levels.get_password(ENDING, Defs.Difficulty.EXPERT)
	assert_eq(code.length(), 4, "the ending has an Expert code")
	assert_eq(Levels.find_by_password(code), {"level_id": ENDING, "difficulty": Defs.Difficulty.EXPERT},
			"code %s is unique" % code)


func test_only_the_planned_levels_lead_here() -> void:
	# The source levels belong to other designers: a link that exists must be the planned one; missing links are
	# reported (the levels may still be in the making).
	var wrong: PackedStringArray = PackedStringArray()
	for level_id: StringName in Levels.all_ids():
		for difficulty: int in [Defs.Difficulty.BEGINNER, Defs.Difficulty.EXPERT]:
			var bonus: StringName = StringName(str(Levels.get_value(level_id, "bonus", "", difficulty)))
			if BONUS_STAGES.has(bonus) and SOURCES[bonus] != level_id:
				wrong.append("%s -> %s" % [level_id, bonus])
			var next: StringName = StringName(str(Levels.get_value(level_id, "next", "", difficulty)))
			if next == ENDING and Levels.parent_level(level_id, difficulty) != ENDING_SOURCE:
				wrong.append("%s -> %s" % [level_id, ENDING])
	assert_eq(wrong, PackedStringArray(), "only the planned levels lead into the feast stages and the ending")
	# A source level that exists must carry the link (part of its brief); one still missing is only reported.
	for bonus: StringName in BONUS_STAGES:
		var source: StringName = SOURCES[bonus]
		if not Levels.has_level(source):
			print("  feast: %s does not exist yet (its meta bonus must be %s)" % [source, bonus])
			continue
		for difficulty: int in [Defs.Difficulty.BEGINNER, Defs.Difficulty.EXPERT]:
			assert_eq(str(Levels.get_value(source, "bonus", "", difficulty)), String(bonus),
					"%s leads to %s (meta bonus, %s)" % [source, bonus, Defs.difficulty_name(difficulty)])
	if not Levels.has_level(ENDING_SOURCE):
		print("  feast: %s does not exist yet (it or its sub-stage must lead to %s)" % [ENDING_SOURCE, ENDING])
	else:
		# Follow 4-2's chain of linked stages (Expert): its last stage, the one with the trophy, leads here.
		var chain: Array[StringName] = [ENDING_SOURCE]
		while chain.size() < 4 and chain[-1] != ENDING:
			var step: StringName = Levels.next_level(chain[-1], Defs.Difficulty.EXPERT)
			if step == &"" or chain.has(step):
				break
			chain.append(step)
		assert_eq(chain[-1], ENDING, "4-2 leads to the epilogue: %s" % " -> ".join(PackedStringArray(chain)))


func test_the_trophy_of_4_2_leads_into_the_ending() -> void:
	# The Wall Colossus drops the trophy in the last stage of 4-2's chain; collecting it starts the epilogue.
	var stage: StringName = ENDING_SOURCE
	if not Levels.has_level(stage):
		print("  feast: %s does not exist yet (trophy -> ending not checked)" % stage)
		return
	while Levels.next_level(stage, Defs.Difficulty.EXPERT) != ENDING:
		var step: StringName = Levels.next_level(stage, Defs.Difficulty.EXPERT)
		assert_ne(step, &"", "4-2's chain leads to the ending")
		if step == &"" or Levels.parent_level(step, Defs.Difficulty.EXPERT) != ENDING_SOURCE:
			return
		stage = step
	Game.new_game(Defs.Difficulty.EXPERT)
	Game.begin_level(stage, stage != ENDING_SOURCE)
	Sim.manual = true
	Flow.complete_level(&"trophy")
	await _settle()
	assert_eq(Flow.current_screen, Flow.SCREEN_LEVEL, "the trophy of %s starts a level, no tally" % stage)
	assert_eq(Game.level_id, ENDING, "the trophy of %s starts the epilogue" % stage)


func test_bonus_a_route_reaches_the_warp() -> void:
	await _bonus_route(&"bonus_a", 150000, Defs.Difficulty.BEGINNER)


func test_bonus_b_route_reaches_the_warp() -> void:
	await _bonus_route(&"bonus_b", 100000, Defs.Difficulty.BEGINNER)


func test_bonus_c_route_reaches_the_warp() -> void:
	await _bonus_route(&"bonus_c", 200000, Defs.Difficulty.BEGINNER)


func test_bonus_routes_on_expert() -> void:
	# The source levels are played on Expert too; the stages have the same spawn set there.
	for level_id: StringName in BONUS_STAGES:
		await _bonus_route(level_id, 100000, Defs.Difficulty.EXPERT)
		after_each()


func test_bonus_a_secret_route_finds_the_cloud_pantry() -> void:
	await _secret_route(&"bonus_a")


func test_bonus_b_secret_route_finds_the_wall_pantry() -> void:
	await _secret_route(&"bonus_b")


func test_bonus_c_secret_route_finds_the_sugar_room() -> void:
	await _secret_route(&"bonus_c")
	assert_eq(_count(&"gate_used"), 1, "the gate in the cellar leads there")


func test_ending_route_reaches_home_and_the_end() -> void:
	Game.new_game(Defs.Difficulty.BEGINNER)
	await _start(ENDING)
	var lives: int = Game.lives
	var played: int = _replay(ROUTES + "ending.inputs")
	assert_eq(_exit_kinds, [&"exit"] as Array[StringName], "the exit totem was reached after %d ticks" % played)
	_assert_clean_run(lives)
	assert_eq(_count(&"checkpoint_activated"), 4, "every campfire on the way home was lit")
	assert_eq(_count(&"player_hurt"), 0, "nothing hurts on the way home")
	assert_true(Game.score >= 100000, "score %d" % Game.score)
	_log(ENDING, played)
	await _settle()
	assert_eq(Flow.current_screen, Flow.SCREEN_TALLY, "the exit leads to the tally")
	Flow.finish_tally()
	await _settle()
	assert_eq(Flow.current_screen, Flow.SCREEN_THE_END, "after the ending's tally comes The End")


func test_ending_route_on_expert() -> void:
	# The ending follows the Expert-only 4-2: the same route works there (no enemies, the same spawn set).
	Game.new_game(Defs.Difficulty.EXPERT)
	await _start(ENDING)
	var lives: int = Game.lives
	var played: int = _replay(ROUTES + "ending.inputs")
	assert_eq(_exit_kinds, [&"exit"] as Array[StringName], "the exit totem was reached after %d ticks" % played)
	_assert_clean_run(lives)


## Play a bonus stage's route: it must end on the spiral staff, which leads to the tally of the source level.
## When the source level exists the stage is entered as its warp enters it (Game.warp_return_level): the tally
## then ends the SOURCE level and the campaign continues on the world map (never The End).
func _bonus_route(level_id: StringName, min_score: int, difficulty: int) -> void:
	Game.new_game(difficulty)
	var source: StringName = SOURCES[level_id]
	var has_source: bool = Levels.has_level(source)
	var clears: int = 0
	if has_source:
		Game.warp_return_level = source
		clears = int(Save.get_level_result(source, difficulty)["clears"])
	await _start(level_id)
	assert_eq(Game.level.get_kind(Defs.Kind.ENEMY).size(), 0, "no enemies in a bonus stage")
	var lives: int = Game.lives
	var played: int = _replay(ROUTES + String(level_id) + ".inputs")
	assert_eq(_exit_kinds, [&"warp"] as Array[StringName], "the spiral staff was reached after %d ticks" % played)
	_assert_clean_run(lives)
	assert_true(played >= BONUS_MIN_TICKS and played <= BONUS_MAX_TICKS,
			"the route takes %d ticks (45-90 s = %d-%d)" % [played, BONUS_MIN_TICKS, BONUS_MAX_TICKS])
	assert_true(Game.score >= min_score, "score %d (at least %d)" % [Game.score, min_score])
	assert_true(_count(&"hidden_spot_opened") >= 8, "hidden spots opened: %d" % _count(&"hidden_spot_opened"))
	_log(level_id, played)
	await _settle()
	assert_eq(Flow.current_screen, Flow.SCREEN_TALLY, "the warp out of a bonus stage leads to the tally")
	if not has_source:
		print("  feast: %s not checked against its source level (%s does not exist yet)" % [level_id, source])
		return
	Flow.finish_tally()
	await _settle()
	assert_eq(int(Save.get_level_result(source, difficulty)["clears"]), clears + 1,
			"the tally of %s ends its source level %s" % [level_id, source])
	assert_eq(int(Save.get_level_result(level_id, difficulty)["clears"]), 0, "nothing is recorded for the stage")
	assert_ne(Flow.current_screen, Flow.SCREEN_THE_END, "a bonus stage never ends the game")
	var next: StringName = Levels.next_level(source, difficulty)
	if next != &"":
		assert_eq(Flow.args.get("level_id", &""), next, "the world map shows the level after %s" % source)
	else:
		# 3-2 is the last Beginner level: Beginner meets the expert wall after it.
		assert_true(Levels.has_locked_successor(source, difficulty), "%s is followed by Expert levels" % source)
		assert_eq(Flow.current_screen, Flow.SCREEN_EXPERT_WALL, "after %s Beginner meets the expert wall" % source)


## Play a bonus stage's secret route: it must enter the level's secret area without losing a life.
func _secret_route(level_id: StringName) -> void:
	Game.new_game(Defs.Difficulty.BEGINNER)
	await _start(level_id)
	var lives: int = Game.lives
	var played: int = _replay(ROUTES + String(level_id) + ".secret.inputs")
	assert_eq(_count(&"secret_found"), 1, "%s: the secret area was found within %d ticks" % [level_id, played])
	_assert_clean_run(lives)
	print("  feast: %s secret route: %d ticks, score %d" % [level_id, played, Game.score])


func _assert_clean_run(lives: int) -> void:
	assert_eq(_count(&"player_died"), 0, "no life lost")
	assert_eq(Game.lives, lives, "the lives are untouched")
	assert_eq(_warnings.count, 0, "no engine warning\n%s" % "\n".join(_warnings.lines))


func _log(level_id: StringName, played: int) -> void:
	print("  feast: %s route: %d ticks (%.1f s), score %d, completion %d %%, spots %d/%d, items %d/%d" % [
		level_id, played, played / 24.275, Game.score, Game.completion_percent(), Game.spots_opened,
		Game.spots_total, Game.items_collected, Game.items_total])


func _all_levels() -> Array[StringName]:
	var ids: Array[StringName] = BONUS_STAGES.duplicate()
	ids.append(ENDING)
	return ids


## Enter `level_id` through Flow like the game does, with the clock under the test's control.
func _start(level_id: StringName) -> void:
	for signal_name: StringName in EVENTS:
		var counter: Callable = _on_event.bind(signal_name)
		var arguments: int = 0
		for info: Dictionary in Events.get_signal_list():
			if StringName(str(info["name"])) == signal_name:
				arguments = (info["args"] as Array).size()
		var callable: Callable = counter.unbind(arguments) if arguments > 0 else counter
		var signal_ref: Signal = Signal(Events, signal_name)
		signal_ref.connect(callable)
		_connections.append([signal_ref, callable])
	var exit_ref: Signal = Signal(Events, &"exit_reached")
	var on_exit: Callable = _on_exit
	exit_ref.connect(on_exit)
	_connections.append([exit_ref, on_exit])
	_warnings = WarningCounter.new()
	OS.add_logger(_warnings)
	Sim.manual = true
	Flow.start_level(level_id, Defs.Transition.NONE)
	await _settle()
	assert_eq(Flow.current_screen, Flow.SCREEN_LEVEL)
	assert_eq(Game.level.level_id, level_id)
	# Headless runs have no window: give the level the view of the autoplay window before the first tick.
	var level: Level = Game.level as Level
	assert_not_null(level, "the world module's level scene")
	if level != null:
		level.set_view_size(VIEW * Tuning.ART_SCALE)


## Play an input file one tick at a time until it ends or gameplay stops (level left); returns the ticks played.
func _replay(path: String) -> int:
	var flags: PackedInt32Array = Autoplay.parse_inputs(FileAccess.get_file_as_string(path))
	assert_true(flags.size() > 100, "%s has an input script" % path)
	var index: Array[int] = [0]
	GameInput.set_scripted(func(_tick: int) -> int:
		var value: int = flags[index[0]] if index[0] < flags.size() else 0
		index[0] += 1
		return value
	)
	var played: int = 0
	while played < flags.size() and Sim.running and _exit_kinds.is_empty():
		Sim.step(1)
		played += 1
	GameInput.clear_scripted()
	return played


func _settle() -> void:
	for i: int in 3:
		await get_tree().process_frame
	while Flow.busy:
		await get_tree().process_frame


func _count(signal_name: StringName) -> int:
	return int(_counts.get(signal_name, 0))


func _on_event(signal_name: StringName) -> void:
	_counts[signal_name] = _count(signal_name) + 1


func _on_exit(exit_kind: StringName) -> void:
	_exit_kinds.append(exit_kind)
