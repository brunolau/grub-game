extends TestCase
## Flow + Autoplay + debug level: the project can load the example level end to end with nothing but core.


func test_autoplay_argument_parsing() -> void:
	var options: Dictionary = Autoplay.parse_args(PackedStringArray([
		"--autoplay=test_example", "--inputs=10:R,5:RU", "--fast", "ignored", "--shots=6",
	]))
	assert_eq(options["autoplay"], "test_example")
	assert_eq(options["shots"], "6")
	assert_true(options.has("fast"))
	assert_false(options.has("ignored"))
	assert_false(Autoplay.active, "the harness is inactive without --autoplay")


func test_autoplay_input_script() -> void:
	var flags: PackedInt32Array = Autoplay.parse_inputs("2:R, 1:ru\n3:\n1:LF")
	assert_eq(flags, PackedInt32Array([
		Defs.IN_RIGHT, Defs.IN_RIGHT, Defs.IN_RIGHT | Defs.IN_UP, 0, 0, 0, Defs.IN_LEFT | Defs.IN_FIRE,
	]))
	var commented: PackedInt32Array = Autoplay.parse_inputs("# walk, then jump: 2 ticks, 1 tick\n2:R\n  # x, y\n1:U")
	assert_eq(commented, PackedInt32Array([Defs.IN_RIGHT, Defs.IN_RIGHT, Defs.IN_UP]),
			"comment lines are skipped whole, commas included")
	assert_eq(GameInput.expand_runs([[2, "D"], [1, "DK"]]), PackedInt32Array([
		Defs.IN_DOWN, Defs.IN_DOWN, Defs.IN_DOWN | Defs.IN_LOOK,
	]))


func test_screens_follow_the_naming_convention() -> void:
	assert_false(Flow.has_screen(&"no_such_screen"))
	assert_eq(Flow.LEVEL_SCENE, "res://scenes/world/level.tscn")
	assert_true(ResourceLoader.exists(Flow.DEBUG_LEVEL_SCENE), "the debug level is always available")
	assert_true(Flow.has_gameplay(), "a development build can always show gameplay")
	assert_true(ResourceLoader.exists(Flow.MAIN_SCENE))
	assert_eq(Flow.get_overlay(Defs.LAYER_HUD).layer, Defs.LAYER_HUD)
	assert_eq(Flow.get_overlay(Defs.LAYER_TOUCH).layer, Defs.LAYER_TOUCH)
	assert_eq(Flow.get_overlay(Defs.LAYER_MENU).layer, Defs.LAYER_MENU)
	assert_true(Flow.instant_transitions, "transitions are instant in headless runs")


func test_example_level_loads_and_runs() -> void:
	Game.new_game(Defs.Difficulty.EXPERT)
	Flow.start_level(&"test_example", Defs.Transition.NONE)
	await Flow.transition_finished
	var level: LevelBase = Game.level
	assert_not_null(level, "a level is active")
	if level == null:
		return
	assert_eq(Flow.current_screen, Flow.SCREEN_LEVEL)
	assert_eq(level.level_id, &"test_example")
	assert_eq(Game.level_id, &"test_example")
	assert_eq(level.grid.cols, 36)
	assert_eq(level.grid.rows, 14)
	assert_eq(level.start_pos, Vector2i(24, 176), "'@' at column 1, row 10: bottom-centre of the cell")
	assert_eq(str(level.meta["biome"]), "jungle")
	assert_true(Sim.running, "the level started the simulation")
	var before: int = Sim.tick
	Sim.step(10)
	assert_eq(Sim.tick, before + 10)
	assert_false(Flow.is_paused())
	Flow.set_paused(true)
	assert_true(get_tree().paused)
	Flow.set_paused(false)
	assert_false(get_tree().paused)
	# Leave gameplay again so later tests start clean.
	Sim.stop()
	get_tree().current_scene.queue_free()
	get_tree().current_scene = null
	Flow.current_screen = Flow.SCREEN_BOOT
	await get_tree().process_frame
	assert_null(Game.level, "the level unregisters itself when it leaves the tree")
