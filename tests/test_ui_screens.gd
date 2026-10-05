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


## A screen that appears under a resting mouse pointer keeps its keyboard focus: only a pointer that MOVES over an
## entry takes the focus (the title menu used to open with "Credits" or "Quit" focused wherever the pointer rested).
func test_menu_entries_take_the_focus_only_from_a_moving_pointer() -> void:
	var holder: VBoxContainer = VBoxContainer.new()
	add_node(holder)
	var first: UiButton = UiButton.new("UI_TITLE_START")
	var second: UiButton = UiButton.new("UI_TITLE_QUIT")
	var row: UiOptionRow = UiOptionRow.action("UI_TITLE_OPTIONS")
	for control: Control in [first, second, row]:
		holder.add_child(control)
	first.grab_focus()
	second.mouse_entered.emit()
	row.mouse_entered.emit()
	assert_true(first.has_focus(), "a pointer resting where an entry appears does not take the focus")
	second.gui_input.emit(InputEventMouseMotion.new())
	assert_true(second.has_focus(), "a pointer moving over an entry does")
	row._gui_input(InputEventMouseMotion.new())
	assert_true(row.has_focus(), "the same for option rows")


## Every level code of the campaign is accepted by the code screen and starts its level in its mode; a code of an
## Expert-only stage has no Beginner twin, and the look-alike letters O and I are read as 0 and 1.
func test_code_entry_accepts_every_campaign_code() -> void:
	var codes: Array[Array] = []
	for level_id: StringName in Levels.all_ids():
		if str(Levels.get_value(level_id, "kind", Levels.KIND_MAIN)) == Levels.KIND_TEST:
			continue
		for difficulty: int in [Defs.Difficulty.BEGINNER, Defs.Difficulty.EXPERT]:
			var code: String = Levels.get_password(level_id, difficulty)
			if code != "":
				codes.append([code, level_id, difficulty])
	assert_true(codes.size() >= 20, "the campaign has its codes: %d" % codes.size())
	for entry: Array in codes:
		var node: CodeEntryScreen = await _open(&"code_entry") as CodeEntryScreen
		node.set_code(str(entry[0]).replace("0", "O"))
		assert_true(node.submit_code(), "code %s is accepted (typed with O for 0)" % entry[0])
		await get_tree().create_timer(CodeEntryScreen.START_DELAY + 0.05).timeout
		assert_eq(Flow.args.get("level_id"), entry[1], "code %s leads to %s" % [entry[0], entry[1]])
		assert_eq(Game.difficulty, entry[2], "code %s plays in its mode" % entry[0])
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


## Every marker of both campaigns keeps its number plate clear of the other markers and plates (2-2 sat on the
## 3-1 marker of the grey rocks), and the hero standing on a stop covers no other marker or plate.
func test_world_map_markers_and_plates_keep_their_distance() -> void:
	const GAP: float = 6.0
	const HERO: Rect2 = Rect2(-24.0, -52.0, 48.0, 52.0)  ## the hero's body around his feet on the map, art px
	for difficulty: int in [Defs.Difficulty.BEGINNER, Defs.Difficulty.EXPERT]:
		Game.new_game(difficulty)
		var campaign: Array[StringName] = Levels.get_campaign(difficulty)
		Flow.args = {"level_id": campaign[0]}
		var node: WorldMapScreen = await _open(&"world_map") as WorldMapScreen
		var markers: Array[Vector2] = node.get_markers()
		var ids: Array[StringName] = node.get_marker_ids()
		assert_eq(markers.size(), campaign.size(), "one marker per stop")
		var dots: Array[Rect2] = []
		var plates: Array[Rect2] = []
		for i: int in markers.size():
			var radius: float = WorldMapScreen.MARKER_RADIUS + 2.0
			dots.append(Rect2(markers[i] - Vector2(radius, radius), Vector2(radius, radius) * 2.0))
			plates.append(node.number_plate(markers[i], UiKit.level_number(ids[i])))
		var map_size: Vector2 = node.get_map_rect().size
		for i: int in markers.size():
			assert_true(Rect2(Vector2.ZERO, map_size).encloses(plates[i]), "%s: plate on the map" % ids[i])
			for j: int in markers.size():
				if i == j:
					continue
				var pair: String = "%s / %s" % [ids[i], ids[j]]
				assert_false(plates[i].grow(GAP).intersects(dots[j]), "%s: plate clear of the marker" % pair)
				assert_false(plates[i].grow(GAP).intersects(plates[j]), "%s: plates clear of each other" % pair)
				var hero: Rect2 = Rect2(markers[i] + HERO.position, HERO.size)
				assert_false(hero.intersects(dots[j]), "%s: the hero on the stop leaves the marker free" % pair)
				assert_false(hero.intersects(plates[j]), "%s: the hero on the stop leaves the plate free" % pair)
		node.queue_free()
		await get_tree().process_frame


## Pictures drawn by a screen's own draw code are held by the screen: a texture drawn from a local variable is
## freed right after the draw call (UiKit.tex() keeps no cache) and shows up white (the title and the map did).
func test_screens_hold_the_pictures_they_draw() -> void:
	Game.new_game(Defs.Difficulty.BEGINNER)
	Game.begin_level(&"test_example")
	var cases: Dictionary = {
		&"title": "res://assets/ui/title_background.png",
		&"world_map": WorldMapScreen.MAP_TEXTURE,
		&"expert_wall": ExpertWallScreen.PROP_DIR + "palisade.png",
		&"the_end": TheEndScreen.PROP_DIR + "fence.png",
	}
	for screen: StringName in cases:
		Flow.args = {"level_id": &"test_example"}
		var node: UiScreen = await _open(screen)
		await get_tree().process_frame
		await get_tree().process_frame
		assert_true(ResourceLoader.has_cached(cases[screen]), "%s still holds %s" % [screen, cases[screen]])
		node.queue_free()
		await get_tree().process_frame


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


## The licence texts that ship with the game can be read in the credits (on a phone there is no other place):
## the look button opens them, Left / Right change the text, "back" returns to the roll and then to the title.
func test_credits_show_the_licence_texts() -> void:
	var node: CreditsScreen = await _open(&"credits") as CreditsScreen
	assert_false(node.is_licence_open())
	_press(Defs.ACT_LOOK)
	assert_true(node.is_licence_open(), "the look button opens the licences")
	assert_true(node.get_licence_text().contains("Permission is hereby granted"), "the engine's MIT notice")
	assert_true(node.get_licence_text().contains("FreeType"), "the FreeType credit")
	_press(&"ui_right")
	assert_true(node.get_licence_text().contains("SIL OPEN FONT LICENSE"), "the font licence")
	_press(&"ui_left")
	_press(&"ui_left")
	assert_eq(node.licence_page, CreditsScreen.LICENCES.size() - 1, "Left wraps to the last text")
	assert_true(node.get_licence_text().contains("Component: The FreeType Project"), "the engine's third-party components")
	_press(&"ui_cancel")
	assert_false(node.is_licence_open(), "back closes the licences")
	assert_eq(Flow.current_screen, Flow.SCREEN_BOOT, "...and stays in the credits")
	for entry: Array in CreditsScreen.LICENCES:
		assert_true(FileAccess.file_exists(str(entry[1])), "%s ships" % entry[1])
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
