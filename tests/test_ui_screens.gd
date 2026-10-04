extends TestCase
## ui module: every screen of Flow instantiates cleanly and can be left by input (ARCHITECTURE.md 8.7 #3).

const SCREENS: Array[StringName] = [
	&"title", &"mode_select", &"code_entry", &"options", &"world_map", &"tally", &"game_over", &"expert_wall",
	&"the_end", &"credits",
]


func after_each() -> void:
	Flow.args = {}


func test_every_screen_exists_and_instantiates() -> void:
	Game.new_game(Defs.Difficulty.BEGINNER)
	Game.begin_level(&"test_example")
	for screen: StringName in SCREENS:
		assert_true(Flow.has_screen(screen), "scene of screen '%s'" % screen)
		Flow.args = {"level_id": &"test_example", "percent": 50}
		var node: UiScreen = await _open(screen)
		assert_not_null(node, "screen '%s' instantiates as a UiScreen" % screen)
		if node == null:
			continue
		assert_not_null(node.safe, "'%s' has a safe-area root" % screen)
		assert_true(node.is_accepting_input(), "'%s' accepts input" % screen)
		node.queue_free()
		await get_tree().process_frame


func test_title_start_opens_mode_select() -> void:
	var node: TitleScreen = await _open(&"title") as TitleScreen
	_press(&"ui_accept")
	assert_eq(Flow.current_screen, Flow.SCREEN_MODE_SELECT, "the focused 'start' entry opens the mode select")
	assert_true(node.leaving)
	await _cleanup()


func test_title_attract_loop_starts_and_any_key_stops_it() -> void:
	var node: TitleScreen = await _open(&"title") as TitleScreen
	node.start_attract()
	assert_true(node.attract_running)
	_press(&"ui_accept")
	assert_false(node.attract_running, "a key ends the attract loop")
	assert_false(node.leaving, "...and does not also select a menu entry")
	assert_eq(Flow.current_screen, Flow.SCREEN_BOOT)


func test_mode_select_back_returns_to_title() -> void:
	var node: UiScreen = await _open(&"mode_select")
	_press(&"ui_cancel")
	assert_eq(Flow.current_screen, Flow.SCREEN_TITLE)
	assert_true(node.leaving)
	await _cleanup()


func test_code_entry_accepts_a_level_code() -> void:
	var node: CodeEntryScreen = await _open(&"code_entry") as CodeEntryScreen
	node.set_code("XXXX")
	assert_false(node.submit_code(), "an unknown code is rejected")
	assert_false(node.leaving)
	_type("c1ub")
	assert_eq(node.get_code(), "C1UB", "typing fills the slots")
	assert_true(node.leaving, "the fourth character submits a known code")
	await get_tree().create_timer(CodeEntryScreen.START_DELAY + 0.1).timeout
	assert_eq(Flow.current_screen, Flow.SCREEN_WORLD_MAP)
	assert_eq(Flow.args.get("level_id"), &"test_example")
	assert_eq(Game.difficulty, Defs.Difficulty.BEGINNER)
	await _cleanup()


func test_code_entry_takes_a_new_code_after_a_wrong_one() -> void:
	var node: CodeEntryScreen = await _open(&"code_entry") as CodeEntryScreen
	_type("xyzq")
	assert_eq(node.get_code(), "XYZQ")
	assert_false(node.leaving, "an unknown code is rejected")
	_type("c1ub")
	assert_eq(node.get_code(), "C1UB", "the next code is typed from the first slot again")
	assert_true(node.leaving, "and it is accepted")
	_type("zz")
	assert_eq(node.get_code(), "C1UB", "an accepted code stays as it is while the level starts")
	await get_tree().create_timer(CodeEntryScreen.START_DELAY + 0.1).timeout
	assert_eq(Flow.args.get("level_id"), &"test_example")
	await _cleanup()


func test_code_entry_back_returns_to_title() -> void:
	await _open(&"code_entry")
	_press(&"ui_cancel")
	assert_eq(Flow.current_screen, Flow.SCREEN_TITLE)
	await _cleanup()


func test_options_back_returns_to_title() -> void:
	await _open(&"options")
	_press(&"ui_cancel")
	assert_eq(Flow.current_screen, Flow.SCREEN_TITLE)
	await _cleanup()


func test_world_map_starts_its_level() -> void:
	Game.new_game(Defs.Difficulty.BEGINNER)
	Flow.args = {"level_id": &"test_example"}
	var node: WorldMapScreen = await _open(&"world_map") as WorldMapScreen
	_press(&"ui_accept")
	assert_true(node.leaving)
	assert_eq(Flow.current_screen, Flow.SCREEN_LEVEL)
	assert_eq(Flow.pending_level_id, &"test_example")
	await _cleanup()


func test_world_map_never_scrolls_past_the_map() -> void:
	Game.new_game(Defs.Difficulty.BEGINNER)
	Flow.args = {"level_id": Levels.first_level()}
	var node: WorldMapScreen = await _open(&"world_map") as WorldMapScreen
	var start: Rect2 = node.get_map_rect()
	assert_true(start.size.x > node.size.x, "the map is wider than the view")
	var moved: bool = false
	var bad: PackedStringArray = PackedStringArray()
	var waited: float = 0.0
	while waited < 1.0:
		var rect: Rect2 = node.get_map_rect()
		if rect.position.x > 0.0 or rect.end.x < node.size.x:
			bad.append(str(rect))
		moved = moved or not is_equal_approx(rect.position.x, start.position.x)
		await get_tree().create_timer(0.05).timeout
		waited += 0.05
	assert_true(moved, "the map scrolls in")
	assert_eq(bad.size(), 0, "the view never shows anything beside the map: %s" % ", ".join(bad))
	await _cleanup()


func test_tally_actors_stay_on_the_ground_when_the_view_changes() -> void:
	Game.new_game(Defs.Difficulty.BEGINNER)
	Game.begin_level(&"test_example")
	Game.add_tally_item(&"items/food", 3, 100)
	Flow.args = {"level_id": &"test_example", "percent": 50}
	var node: TallyScreen = await _open(&"tally") as TallyScreen
	_press(&"ui_accept")
	assert_eq(node.phase, TallyScreen.Phase.SETTLE, "skipped to the end: both stand at their marks")
	var ground: float = node.get_ground_y()
	node.size = Vector2(node.size.x + 160.0, node.size.y + 120.0)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(node.get_ground_y(), ground + 120.0, "the ground stays at the bottom edge")
	for feet: Vector2 in node.get_actor_feet():
		assert_eq(feet.y, node.get_ground_y(), "an actor stands on the ground after the resize")
	await _cleanup()


func test_tally_pays_every_item_once_and_finishes() -> void:
	Game.new_game(Defs.Difficulty.BEGINNER)
	Game.begin_level(&"test_example")
	Game.add_score(1000)
	Game.add_tally_item(&"items/food", 3, 100)
	Game.add_tally_item(&"items/treasure", 8, 5000)
	Game.add_tally_item(&"items/letter", 1, 0)
	Flow.args = {"level_id": &"test_example", "percent": 75}
	var node: TallyScreen = await _open(&"tally") as TallyScreen
	assert_eq(node.get_item_count(), 3)
	_press(&"ui_accept")
	assert_eq(node.paid, 3, "skipping pays the remaining items")
	assert_eq(Game.score, 6100, "each item is paid again, exactly once")
	assert_false(node.leaving)
	_press(&"ui_accept")
	assert_true(node.leaving, "a second press leaves the tally")
	assert_eq(Game.score, 6100)
	assert_eq(Game.tally_count(), 0, "Flow.finish_tally cleared the list")
	assert_eq(Flow.current_screen, Flow.SCREEN_THE_END, "a level without a successor ends the game")
	await _cleanup()


func test_tally_runs_by_itself() -> void:
	Game.new_game(Defs.Difficulty.BEGINNER)
	Game.begin_level(&"test_example")
	Game.add_tally_item(&"items/food", 0, 100)
	Flow.args = {"level_id": &"test_example", "percent": 100}
	var node: TallyScreen = await _open(&"tally") as TallyScreen
	var waited: float = 0.0
	while not node.leaving and waited < 10.0:
		await get_tree().create_timer(0.25).timeout
		waited += 0.25
	assert_true(node.leaving, "the tally finishes without input")
	assert_eq(Game.score, 100)
	await _cleanup()


func test_game_over_returns_to_title() -> void:
	await _open(&"game_over")
	_press(&"ui_accept")
	assert_eq(Flow.current_screen, Flow.SCREEN_TITLE)
	await _cleanup()


func test_expert_wall_returns_to_title() -> void:
	await _open(&"expert_wall")
	_press(&"ui_accept")
	assert_eq(Flow.current_screen, Flow.SCREEN_TITLE)
	await _cleanup()


func test_the_end_leads_to_the_credits() -> void:
	await _open(&"the_end")
	_press(&"ui_accept")
	assert_eq(Flow.current_screen, Flow.SCREEN_CREDITS)
	await _cleanup()


func test_credits_back_returns_to_title() -> void:
	await _open(&"credits")
	_press(&"ui_cancel")
	assert_eq(Flow.current_screen, Flow.SCREEN_TITLE)
	await _cleanup()


func test_credits_are_generated_from_credits_md() -> void:
	var sections: Array[Array] = CreditsScreen.parse_credits(FileAccess.get_file_as_string(CreditsScreen.CREDITS_PATH))
	var by_heading: Dictionary = {}
	for section: Array in sections:
		by_heading[str(section[0])] = section[1]
	for heading: String in ["UI_CREDITS_ART", "UI_CREDITS_MUSIC", "UI_CREDITS_SOUND", "UI_CREDITS_FONTS",
			"UI_CREDITS_PACKS", "UI_CREDITS_ENGINE"]:
		assert_true(by_heading.has(heading), "credits section %s" % heading)
	if by_heading.has("UI_CREDITS_ART"):
		assert_true((by_heading["UI_CREDITS_ART"] as Array).has("Pixel-boy / Sparklin Labs (Superpowers Asset Packs)"))
	if by_heading.has("UI_CREDITS_FONTS"):
		var fonts: Array = by_heading["UI_CREDITS_FONTS"]
		assert_eq(fonts.size(), 2, "both SIL OFL attributions")
	if by_heading.has("UI_CREDITS_PACKS"):
		assert_true((by_heading["UI_CREDITS_PACKS"] as Array).size() >= 20, "every source pack")


## Instantiate a screen under the test node (not as the current scene) and let it build.
func _open(screen: StringName) -> UiScreen:
	var scene: PackedScene = load(Flow.SCREEN_DIR + String(screen) + ".tscn") as PackedScene
	var node: UiScreen = scene.instantiate() as UiScreen
	add_node(node)
	await get_tree().process_frame
	await get_tree().process_frame
	return node


func _press(action: StringName) -> void:
	for pressed: bool in [true, false]:
		var event: InputEventAction = InputEventAction.new()
		event.action = action
		event.pressed = pressed
		get_tree().root.push_input(event)


func _type(text: String) -> void:
	for i: int in text.length():
		var code: Key = OS.find_keycode_from_string(text[i].to_upper())
		for pressed: bool in [true, false]:
			var event: InputEventKey = InputEventKey.new()
			event.keycode = code
			event.unicode = text.unicode_at(i)
			event.pressed = pressed
			get_tree().root.push_input(event)


## Undo what Flow did when a screen was left: wait for the transition, then remove the new scene and overlays.
func _cleanup() -> void:
	if Flow.busy:
		await Flow.transition_finished
	Sim.stop()
	get_tree().paused = false
	var scene: Node = get_tree().current_scene
	if scene != null:
		scene.queue_free()
		get_tree().current_scene = null
	for layer: int in [Defs.LAYER_HUD, Defs.LAYER_TOUCH, Defs.LAYER_MENU]:
		for child: Node in Flow.get_overlay(layer).get_children():
			child.queue_free()
	Flow.current_screen = Flow.SCREEN_BOOT
	Flow.args = {}
	Audio.stop_music(0.0)
	await get_tree().process_frame
