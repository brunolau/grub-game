extends TestCase
## The integration levels (owner: core, as the integrator of the modules).
##
## levels/test_integration.lvl and levels/test_integration_boss.lvl use every system of the game. They were the
## stand-in campaign of debug builds until the level designers' campaign arrived; now they are a linked pair of
## `kind = test` levels (the first one's `next` leads to the second). The two input scripts in tools/autoplay are
## replayed here through Flow and the real level scene, tick for tick as the autoplay flow
## `tools/autoplay/full_loop.flow` plays them in a window, so a change in any module that breaks the playthrough
## fails the suite.

const LEVEL_ONE: StringName = &"test_integration"
const LEVEL_TWO: StringName = &"test_integration_boss"
const INPUTS_ONE: String = "res://tools/autoplay/integration_level.inputs"
const INPUTS_TWO: String = "res://tools/autoplay/integration_boss.inputs"
## Logical view of the autoplay window (1280 x 720 at integer scale 2): enemies wake by the view.
const VIEW: Vector2i = Vector2i(Tuning.VIEW_W, Tuning.VIEW_H)

## Counts the warnings the engine logs (the runner only fails a test on errors).
class WarningCounter:
	extends Logger

	var count: int = 0

	func _log_error(
			_function: String, _file: String, _line: int, _code: String, _rationale: String, _editor_notify: bool,
			error_type: int, _script_backtraces: Array[ScriptBacktrace]
	) -> void:
		if error_type == Logger.ERROR_TYPE_WARNING:
			count += 1

	func _log_message(_message: String, _error: bool) -> void:
		pass


var _counts: Dictionary = {}
var _connections: Array[Array] = []


func after_each() -> void:
	for connection: Array in _connections:
		var signal_ref: Signal = connection[0]
		if signal_ref.is_connected(connection[1]):
			signal_ref.disconnect(connection[1])
	_connections.clear()
	_counts.clear()
	GameInput.clear_scripted()
	Sim.manual = false
	Sim.stop()
	if get_tree().current_scene != null:
		get_tree().current_scene.free()
		get_tree().current_scene = null
	Flow.current_screen = Flow.SCREEN_BOOT


func test_both_levels_are_valid() -> void:
	var validator: LevelValidator = LevelValidator.new()
	assert_true(validator.add_folder(Levels.LEVEL_DIR) > 0)
	validator.run()
	for level_id: StringName in [LEVEL_ONE, LEVEL_TWO]:
		var problems: Array[Dictionary] = validator.problems_of(Levels.get_level_path(level_id))
		var lines: PackedStringArray = PackedStringArray()
		for problem: Dictionary in problems:
			lines.append(LevelValidator.format_problem(problem))
		assert_eq(problems.size(), 0, "%s: no error and no warning\n%s" % [level_id, "\n".join(lines)])
	assert_eq(validator.error_count(), 0, "every level file of the folder is valid")


func test_they_are_a_linked_development_pair_outside_the_campaign() -> void:
	for level_id: StringName in [LEVEL_ONE, LEVEL_TWO]:
		assert_eq(str(Levels.get_value(level_id, "kind", "")), Levels.KIND_TEST, "%s is a developer level" % level_id)
		for difficulty: int in [Defs.Difficulty.BEGINNER, Defs.Difficulty.EXPERT]:
			assert_false(Levels.get_campaign(difficulty).has(level_id), "%s is not on the world map" % level_id)
	assert_eq(Levels.next_level(LEVEL_ONE, Defs.Difficulty.BEGINNER), LEVEL_TWO, "the pair stays linked")
	assert_eq(Levels.next_level(LEVEL_TWO, Defs.Difficulty.BEGINNER), &"", "the boss level ends the pair")
	assert_false(Levels.has_locked_successor(LEVEL_TWO, Defs.Difficulty.BEGINNER))
	assert_eq(Levels.find_by_password("brut"), {"level_id": LEVEL_TWO, "difficulty": Defs.Difficulty.BEGINNER})
	assert_eq(Levels.find_by_password("W1LD"), {"level_id": LEVEL_ONE, "difficulty": Defs.Difficulty.EXPERT})


func test_level_one_plays_from_start_to_exit() -> void:
	Game.new_game(Defs.Difficulty.BEGINNER)
	await _start(LEVEL_ONE)
	var level: LevelBase = Game.level
	assert_eq(level.get_view_rect().size, VIEW, "the view of the autoplay window")
	assert_eq(Game.items_total, 11, "placed items with points")
	assert_eq(Game.spots_total, 7, "hidden spots, breakable blocks and containers")
	var played: int = _replay(INPUTS_ONE)
	assert_eq(_count(&"exit_reached"), 1, "the exit was reached after %d ticks" % played)
	assert_eq(_count(&"player_died"), 1, "one death on the spikes")
	assert_eq(_count(&"level_respawned"), 1)
	assert_true(_count(&"checkpoint_activated") >= 1)
	assert_true(_count(&"enemy_killed") >= 8, "every enemy on the way was beaten: %d" % _count(&"enemy_killed"))
	assert_true(_count(&"hidden_spot_opened") >= 6, "spots: %d" % _count(&"hidden_spot_opened"))
	assert_true(_count(&"secret_found") == 0, "the canopy secret is off the scripted route")
	assert_eq(Game.lives, Tuning.LIVES_START - 1)
	assert_eq(Game.weapon, Defs.Weapon.AXE, "the axe was picked up")
	assert_true(Game.score >= 40000, "score %d" % Game.score)
	assert_true(Game.completion_percent() >= 80, "completion %d %%" % Game.completion_percent())
	await _settle()
	assert_eq(Flow.current_screen, Flow.SCREEN_TALLY, "the exit leads to the tally")


func test_level_two_boss_is_beaten_and_the_exit_opens() -> void:
	Game.new_game(Defs.Difficulty.BEGINNER)
	await _start(LEVEL_TWO)
	var boss: BossBase = Game.level.get_kind(Defs.Kind.BOSS)[0] as BossBase
	assert_not_null(boss)
	assert_eq(boss.get_max_pips(), 6, "48 hit points at 8 per pip")
	var played: int = _replay(INPUTS_TWO)
	assert_eq(_count(&"boss_started"), 1)
	assert_true(_count(&"enemy_hit") >= 2, "the boss took several hits")
	assert_eq(_count(&"boss_defeated"), 1)
	assert_true(boss.dead)
	assert_eq(_count(&"exit_unlocked"), 1, "the fire-starter it dropped opened the exit")
	assert_eq(_count(&"exit_reached"), 1, "the exit was reached after %d ticks" % played)
	assert_true(_count(&"player_hurt") >= 1, "the hero took damage on the way")
	await _settle()
	assert_eq(Flow.current_screen, Flow.SCREEN_TALLY)


func test_the_boss_arena_shows_its_floor() -> void:
	Game.new_game(Defs.Difficulty.BEGINNER)
	await _start(LEVEL_TWO)
	var level: LevelBase = Game.level
	var boss: BossBase = level.get_kind(Defs.Kind.BOSS)[0] as BossBase
	var arena: ArenaZone = null
	for zone: SimEntity in level.get_kind(Defs.Kind.ZONE):
		if zone is ArenaZone and (zone as ArenaZone).zone_name == boss.arena:
			arena = zone
	assert_not_null(arena, "the boss has its arena")
	if arena == null:
		return
	level.lock_camera(arena.rect)
	level.snap_camera()
	var view: Rect2i = level.get_view_rect()
	assert_eq(view.size, VIEW)
	assert_true(view.has_point(boss.sim_pos), "the boss stands inside the locked view")
	assert_true(boss.sim_pos.y + Tuning.TILE <= view.end.y,
			"the whole floor tile under the fight is on screen (feet at %d, view bottom %d)" % [
				boss.sim_pos.y, view.end.y])


func test_restarting_the_level_cannot_farm_points() -> void:
	Game.new_game(Defs.Difficulty.BEGINNER)
	await _start(LEVEL_ONE)
	# The opening of the level script: the inset spot and the food on the platform above it.
	var opening: String = "20:R,10:,10:DF,4:,10:DF,4:,10:DF,6:,10:RU,6:R,10:,12:R,10:"
	_play(Autoplay.parse_inputs(opening))
	var first_score: int = Game.score
	assert_true(first_score > 0, "items were collected")
	assert_true(Game.items_collected > 0)
	Flow.restart_level()
	await _settle()
	assert_eq(Flow.current_screen, Flow.SCREEN_LEVEL)
	assert_eq(Game.score, 0, "back to the score the level was entered with")
	assert_eq(Game.lives, Tuning.LIVES_START, "a restart costs no life")
	assert_eq(Game.items_collected, 0)
	assert_eq(Game.items_total, 11, "the totals are counted once")
	assert_eq(Game.spots_total, 7)
	var level: Level = Game.level as Level
	if level != null:
		level.set_view_size(VIEW * Tuning.ART_SCALE)
	_play(Autoplay.parse_inputs(opening))
	assert_eq(Game.score, first_score, "the same items pay the same points once")


func test_pausing_in_the_death_toss_after_giving_up_is_clean() -> void:
	Game.new_game(Defs.Difficulty.BEGINNER)
	await _start(LEVEL_ONE)
	var menu: PauseMenu = null
	for child: Node in Flow.get_overlay(Defs.LAYER_MENU).get_children():
		if child is PauseMenu and not child.is_queued_for_deletion():
			menu = child
	assert_not_null(menu, "Flow put the pause menu into its overlay")
	if menu == null:
		return
	var warnings: WarningCounter = WarningCounter.new()
	OS.add_logger(warnings)
	Flow.set_paused(true)
	# The menu lays its entries out on the next frame; keyboard navigation needs that layout.
	await get_tree().process_frame
	_press(&"ui_down")
	_press(&"ui_accept")
	assert_eq(menu.page, PauseMenu.Page.CONFIRM, "'back to checkpoint' asks first")
	_press(&"ui_accept")
	assert_false(Flow.is_paused(), "giving up resumes the game")
	assert_true(Game.level.player.dead, "the hero gave up this life")
	# Pause again while the death toss plays: 'back to checkpoint' is disabled now.
	Flow.set_paused(true)
	OS.remove_logger(warnings)
	assert_true(menu.visible)
	var focused: UiButton = menu.get_viewport().gui_get_focus_owner() as UiButton
	assert_true(focused != null and focused.text == "UI_PAUSE_RESUME", "the focus goes to 'resume'")
	assert_eq(warnings.count, 0, "no focus warning for the disabled entry")
	Flow.set_paused(false)


func test_restarting_during_the_death_toss_still_costs_the_life() -> void:
	Game.new_game(Defs.Difficulty.BEGINNER)
	await _start(LEVEL_ONE)
	Game.level.player.kill(&"spikes")
	Flow.restart_level()
	await _settle()
	assert_eq(Flow.current_screen, Flow.SCREEN_LEVEL)
	assert_eq(Game.lives, Tuning.LIVES_START - 1, "the dying life is lost even though the level restarts")
	assert_false(Game.level.player.dead, "the new attempt starts alive")
	# On the last life the restart ends the run instead.
	Game.lives = 0
	Game.level.player.kill(&"spikes")
	Flow.restart_level()
	await _settle()
	assert_eq(Flow.current_screen, Flow.SCREEN_GAME_OVER, "no life left: game over")
	assert_eq(_count(&"game_over"), 1)


## Enter `level_id` through Flow like the game does, with the clock under the test's control.
func _start(level_id: StringName) -> void:
	for signal_name: StringName in [&"exit_reached", &"player_died", &"level_respawned", &"checkpoint_activated",
			&"enemy_killed", &"hidden_spot_opened", &"secret_found", &"boss_started", &"enemy_hit",
			&"boss_defeated", &"exit_unlocked", &"player_hurt", &"game_over"]:
		var counter: Callable = _on_event.bind(signal_name)
		var arguments: int = 0
		for info: Dictionary in Events.get_signal_list():
			if StringName(str(info["name"])) == signal_name:
				arguments = (info["args"] as Array).size()
		var callable: Callable = counter.unbind(arguments) if arguments > 0 else counter
		var signal_ref: Signal = Signal(Events, signal_name)
		signal_ref.connect(callable)
		_connections.append([signal_ref, callable])
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


## Play an input file one tick at a time until it ends or gameplay stops (exit reached); returns the ticks played.
func _replay(path: String) -> int:
	var flags: PackedInt32Array = Autoplay.parse_inputs(FileAccess.get_file_as_string(path))
	assert_true(flags.size() > 100, "%s has an input script" % path)
	return _play(flags)


## Play input flags one tick at a time until they end or gameplay stops; returns the ticks played.
func _play(flags: PackedInt32Array) -> int:
	var index: Array[int] = [0]
	GameInput.set_scripted(func(_tick: int) -> int:
		var value: int = flags[index[0]] if index[0] < flags.size() else 0
		index[0] += 1
		return value
	)
	var played: int = 0
	while played < flags.size() and Sim.running:
		Sim.step(1)
		played += 1
	GameInput.clear_scripted()
	return played


func _settle() -> void:
	for i: int in 3:
		await get_tree().process_frame
	while Flow.busy:
		await get_tree().process_frame


## One press and release of an input action, delivered to the focused control like a key or pad button.
func _press(action: StringName) -> void:
	for pressed: bool in [true, false]:
		var event: InputEventAction = InputEventAction.new()
		event.action = action
		event.pressed = pressed
		get_tree().root.push_input(event)


func _count(signal_name: StringName) -> int:
	return int(_counts.get(signal_name, 0))


func _on_event(signal_name: StringName) -> void:
	_counts[signal_name] = _count(signal_name) + 1
