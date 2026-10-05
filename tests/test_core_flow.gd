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


func test_a_linked_sub_stage_continues_after_its_main_level() -> void:
	# A (main, no tally, next = B) and its sub-stage B (no `next`) between the development campaign and C, a
	# level for experts only. The metas are added in memory; the registry is rescanned at the end.
	var a: StringName = &"zz_linked_a"
	var b: StringName = &"zz_linked_b"
	var b2: StringName = &"zz_linked_b2"
	var c: StringName = &"zz_linked_c"
	var last: StringName = Levels.get_campaign()[-1]
	var order: int = int(Levels.get_value(last, "order", 0))
	Levels._meta[a] = {"id": String(a), "kind": "main", "order": order + 10, "tally": false, "next": String(b)}
	Levels._meta[b] = {"id": String(b), "kind": "sub"}
	Levels._meta[c] = {"id": String(c), "kind": "main", "order": order + 20, "min_difficulty": "expert"}
	Levels._index_campaign()
	var beginner: int = Defs.Difficulty.BEGINNER
	var expert: int = Defs.Difficulty.EXPERT
	assert_eq(Levels.parent_level(b, beginner), a, "the sub-stage belongs to the level whose next leads to it")
	assert_eq(Levels.parent_level(a, beginner), a, "a campaign level is its own map stop")
	assert_eq(Levels.parent_level(&"test_example", beginner), &"", "a test level belongs to none")
	assert_eq(Levels.next_level(a, expert), b, "the main level leads into its sub-stage")
	assert_eq(Levels.next_level(b, expert), c, "the sub-stage continues after its main level")
	assert_eq(Levels.next_level(b, beginner), &"")
	assert_true(Levels.has_locked_successor(b, beginner), "Beginner meets the expert wall after the sub-stage")
	assert_false(Levels.get_campaign().has(b), "no map stop of its own")
	# A chain of two sub-stages, with the link only in Expert.
	Levels._meta[b] = {"id": String(b), "kind": "sub", "next.expert": String(b2)}
	Levels._meta[b2] = {"id": String(b2), "kind": "sub"}
	assert_eq(Levels.parent_level(b2, expert), a)
	assert_eq(Levels.next_level(b2, expert), c)
	assert_eq(Levels.parent_level(b2, beginner), &"", "no link in Beginner")
	# Flow: the tally of the sub-stage records the result under the main level and moves on to C.
	Levels._meta[b] = {"id": String(b), "kind": "sub"}
	Game.new_game(expert)
	Game.begin_level(b, true)
	Game.add_score(4321)
	Flow.finish_tally()
	var result: Dictionary = Save.get_level_result(a, expert)
	assert_eq(int(result["score"]), 4321, "the result is the main level's")
	assert_eq(int(result["clears"]), 1)
	assert_eq(int(Save.get_level_result(b, expert)["clears"]), 0, "nothing is recorded for the sub-stage")
	assert_true(Save.is_level_unlocked(c, expert), "the next map stop is unlocked")
	assert_eq(Flow.args.get("level_id", &""), c, "the world map shows the next main level")
	if Flow.busy:
		await Flow.transition_finished
	Levels.rescan()
	if get_tree().current_scene != null:
		get_tree().current_scene.queue_free()
		get_tree().current_scene = null
	Flow.current_screen = Flow.SCREEN_BOOT
	Flow.args = {}
	await get_tree().process_frame


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
