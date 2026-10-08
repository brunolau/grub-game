extends TestCase
## ui module: every screen of Flow instantiates cleanly and can be left by input (ARCHITECTURE.md 8.7 #3).
## 2.0 (ui-A, PLAN.md P1.11): the title's Play choice, the book select, the difficulty of the prepared run, the co-op
## join panel (press Jump to join, colour, hold Strike = ready, the keyboard presets, picture and key test), the map of
## a co-op party. The versus screens: tests/test_ui_versus.gd.

const SCREENS: Array[StringName] = [
	&"title", &"mode_select", &"code_entry", &"options", &"world_map", &"tally", &"game_over", &"expert_wall",
	&"the_end", &"credits", &"book_select", &"join", &"unlocks",
]


func before_each() -> void:
	Settings.reset()
	GameInput.reset_slots()
	GameInput.set_menu_clusters(false)
	Flow.play_mode = Defs.GameMode.SINGLE
	Flow.play_book = 1


func after_each() -> void:
	Flow.args = {}
	Flow.play_mode = Defs.GameMode.SINGLE
	Flow.play_book = 1
	GameInput.set_menu_clusters(false)
	GameInput.reset_slots()
	Game.versus_match = null
	for run: PlayerRun in Game.runs:
		run.palette = &""
		run.pattern = -1
	Settings.reset()


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


## Title > Play turns the menu into Solo / Co-op / Versus (Solo focused); "back" returns to the main entries; Solo
## opens the book select (DESIGN.md A.1). The 1.0 path to the difficulty is Play, Solo, Book I.
func test_title_play_opens_the_mode_choice() -> void:
	var node: TitleScreen = await _open(&"title") as TitleScreen
	_press(&"ui_accept")
	assert_true(node.is_play_menu_open(), "the focused 'Play' entry shows Solo / Co-op / Versus")
	assert_false(node.leaving)
	assert_eq(Flow.current_screen, Flow.SCREEN_BOOT, "nothing else happens yet")
	_press(&"ui_cancel")
	assert_false(node.is_play_menu_open(), "back returns to the main entries")
	assert_false(node.leaving)
	_press(&"ui_accept")
	_press(&"ui_accept")
	assert_true(node.leaving, "Solo leaves the title")
	assert_eq(Flow.play_mode, Defs.GameMode.SINGLE)
	assert_eq(Flow.current_screen, Flow.SCREEN_BOOK_SELECT, "Solo opens the book select")
	await _cleanup()


func test_title_play_choices_open_coop_and_versus() -> void:
	var expected: Dictionary = {
		Defs.GameMode.COOP: Flow.SCREEN_JOIN, Defs.GameMode.VERSUS: Flow.SCREEN_VERSUS_LOBBY,
	}
	for mode: int in expected:
		var node: TitleScreen = await _open(&"title") as TitleScreen
		node.open_play_menu()
		node.choose_play(mode)
		if Flow.busy:
			await Flow.transition_finished
		assert_eq(Flow.play_mode, mode)
		assert_eq(Flow.current_screen, expected[mode], "%s opens %s" % [mode, expected[mode]])
		assert_true(GameInput.has_menu_clusters(), "both players drive %s from their own keys" % expected[mode])
		await _cleanup()
		node.queue_free()
		GameInput.set_menu_clusters(false)
		GameInput.reset_slots()
		Game.versus_match = null
		await get_tree().process_frame


func test_title_attract_loop_starts_and_any_key_stops_it() -> void:
	var node: TitleScreen = await _open(&"title") as TitleScreen
	node.start_attract()
	assert_true(node.attract_running)
	_press(&"ui_accept")
	assert_false(node.attract_running, "a key ends the attract loop")
	assert_false(node.leaving, "...and does not also select a menu entry")
	assert_eq(Flow.current_screen, Flow.SCREEN_BOOT)


func test_mode_select_back_returns_to_the_book_select() -> void:
	var node: UiScreen = await _open(&"mode_select")
	_press(&"ui_cancel")
	assert_eq(Flow.current_screen, Flow.SCREEN_BOOK_SELECT)
	assert_true(node.leaving)
	await _cleanup()


## The difficulty starts the run the front end prepared (Flow.start_selected_game): a solo Book I run is the 1.0 game,
## a co-op run takes the joined party.
func test_mode_select_starts_the_prepared_run() -> void:
	var node: ModeSelectScreen = await _open(&"mode_select") as ModeSelectScreen
	assert_true(ModeSelectScreen.subtitle_text().contains(tr("UI_BOOK_1_NAME")), "the line names the book")
	node.choose(Defs.Difficulty.EXPERT)
	assert_eq(Game.mode, Defs.GameMode.SINGLE)
	assert_eq(Game.book, 1)
	assert_eq(Game.difficulty, Defs.Difficulty.EXPERT)
	assert_eq(Flow.current_screen, Flow.SCREEN_WORLD_MAP)
	assert_eq(Flow.args.get("level_id"), Levels.first_level(), "the 1.0 game: Book I's first stop")
	assert_eq(GameInput.get_slot(0).kind, Defs.InputSlotKind.ALL_DEVICES, "single-player input")
	await _cleanup()
	Flow.play_mode = Defs.GameMode.COOP
	GameInput.assign_slot(0, InputSlot.keyboard(Defs.InputSlotKind.KEYBOARD_LEFT))
	GameInput.assign_slot(1, InputSlot.keyboard(Defs.InputSlotKind.KEYBOARD_RIGHT))
	node = await _open(&"mode_select") as ModeSelectScreen
	assert_true(GameInput.has_menu_clusters(), "co-op: both players drive the cards from their own keys")
	assert_true(ModeSelectScreen.subtitle_text().begins_with(tr("UI_PLAY_COOP")))
	node.choose(Defs.Difficulty.BEGINNER)
	assert_eq(Game.mode, Defs.GameMode.COOP)
	assert_eq(Game.party, 2)
	assert_eq(Flow.current_screen, Flow.SCREEN_WORLD_MAP)
	await _cleanup()


## The book select: two slabs (Book I focused first), confirm chooses the book (-> the difficulty), "back" returns
## to the title in Solo and to the join panel (the party kept) in Co-op.
func test_book_select_chooses_a_book_and_goes_back() -> void:
	var node: BookSelectScreen = await _open(&"book_select") as BookSelectScreen
	assert_not_null(node.get_card(1))
	assert_not_null(node.get_card(2))
	assert_true(node.get_card(1).has_focus(), "Book I has the focus")
	assert_true(BookSelectScreen.is_available(1))
	assert_eq(BookSelectScreen.party_looks().size(), 1, "Solo: one hero on the pictures")
	_press(&"ui_right")
	assert_true(node.get_card(2).has_focus(), "Right: Book II")
	_press(&"ui_left")
	_press(&"ui_accept")
	assert_true(node.leaving)
	assert_eq(Flow.play_book, 1)
	assert_eq(Flow.current_screen, Flow.SCREEN_MODE_SELECT, "on to Beginner / Expert")
	await _cleanup()
	if BookSelectScreen.is_available(2):
		node = await _open(&"book_select") as BookSelectScreen
		node.choose(2)
		assert_eq(Flow.play_book, 2, "Book II is open from the start")
		assert_eq(Flow.current_screen, Flow.SCREEN_MODE_SELECT)
		await _cleanup()
	node = await _open(&"book_select") as BookSelectScreen
	_press(&"ui_cancel")
	assert_eq(Flow.current_screen, Flow.SCREEN_TITLE, "Solo: back to the title")
	await _cleanup()
	Flow.play_mode = Defs.GameMode.COOP
	GameInput.assign_slot(0, InputSlot.keyboard(Defs.InputSlotKind.KEYBOARD_LEFT))
	GameInput.assign_slot(1, InputSlot.pad(3))
	Game.runs[1].palette = &"green"
	node = await _open(&"book_select") as BookSelectScreen
	var looks: Array[Array] = BookSelectScreen.party_looks()
	assert_eq(looks.size(), 2, "Co-op: both heroes on the pictures")
	assert_eq(looks[1][0], &"green", "in their colours")
	_press(&"ui_cancel")
	assert_eq(Flow.current_screen, Flow.SCREEN_JOIN, "Co-op: back to the join panel")
	assert_eq(GameInput.get_slot(1).kind, Defs.InputSlotKind.PAD, "the party stays")
	await _cleanup()


# =================================================================================================================
# The co-op join panel (DESIGN.md D.11)
# =================================================================================================================

## "Press Jump on any device": the Jump key of each keyboard half of the classic layout and a pad's Jump take the free
## seats in order; an input that plays already, a third player and every other key of a free half take nothing.
func test_join_panel_seats_players_by_their_jump() -> void:
	var node: JoinScreen = await _open_join()
	assert_true(GameInput.has_menu_clusters(), "the menu clusters are on")
	assert_eq(node.get_card(0).state, JoinScreen.SeatCard.State.FREE)
	assert_eq(node.get_card(0).join_keys, PackedStringArray(["SPACE", "NUM 0"]), "the free halves' Jump keys")
	_key(KEY_A)
	_key(KEY_W)
	assert_eq(Flow.party_size(), 0, "another key of a free half does nothing")
	assert_eq(GameInput.keyboard_layout(), InputSlot.KeyboardLayout.CLASSIC, "... and does not change the layout")
	_key(KEY_KP_0)
	assert_eq(GameInput.get_slot(0).kind, Defs.InputSlotKind.KEYBOARD_RIGHT, "the numpad player came first: P1")
	assert_eq(node.get_card(0).state, JoinScreen.SeatCard.State.HUMAN)
	assert_eq(node.get_card(0).device_text, tr("UI_JOIN_NUMPAD"))
	assert_eq(node.get_card(0).hold_key, "NUM ENTER", "his card names his own Strike key")
	_key(KEY_KP_0)
	assert_eq(Flow.party_size(), 1, "one input, one seat")
	_pad_button(4, JOY_BUTTON_A)
	assert_eq(GameInput.get_slot(1).kind, Defs.InputSlotKind.PAD, "a pad's Jump takes the second seat")
	assert_eq(GameInput.get_slot(1).device_id, 4)
	assert_eq(node.get_card(1).device_text, tr("UI_JOIN_PAD").format({"number": 5}))
	_key(KEY_SPACE)
	assert_eq(Flow.party_size(), 2, "co-op is two players")
	assert_ne(Game.runs[0].palette, Game.runs[1].palette, "two colours")
	await _cleanup()


## Each player changes his own colour (the partner's is skipped) and loincloth with his own keys; holding Strike for a
## second makes him ready (then only his Look counts), Look takes it back, Look again leaves the seat. When both are
## ready the panel moves on to the book select.
func test_join_panel_colour_ready_and_leave() -> void:
	var node: JoinScreen = await _open_join()
	_key(KEY_SPACE)
	_key(KEY_KP_0)
	assert_eq(Game.runs[0].palette, &"yellow", "P1's default colour")
	assert_eq(Game.runs[1].palette, &"blue", "P2's default colour")
	_key(KEY_A)
	assert_ne(Game.runs[0].palette, &"blue", "Left skips the partner's colour")
	assert_ne(Game.runs[0].palette, &"yellow", "and changes his")
	assert_eq(node.get_card(0).colour, Game.runs[0].palette, "his card shows it")
	var pattern: int = Game.runs[1].pattern
	_key(KEY_KP_5)
	assert_ne(Game.runs[1].pattern, pattern, "Down: P2's loincloth")
	_key(_p1_strike(), true)
	node._process(JoinScreen.READY_SECONDS * 0.5)
	assert_almost_eq(node.hold_progress(0), 0.5, 0.05, "the hold fills")
	assert_false(node.is_ready(0))
	node._process(JoinScreen.READY_SECONDS * 0.6)
	assert_true(node.is_ready(0), "held for a second: ready")
	_key(_p1_strike(), false)
	var colour: StringName = Game.runs[0].palette
	_key(KEY_D)
	assert_eq(Game.runs[0].palette, colour, "a ready player's colour stays")
	assert_eq(GameInput.keyboard_layout(), InputSlot.KeyboardLayout.CLASSIC, "... and his keys change no menu row")
	_key(KEY_Q)
	assert_false(node.is_ready(0), "Look: not ready")
	_key(KEY_Q)
	assert_eq(Flow.party_size(), 1, "Look again: P1 leaves")
	assert_eq(GameInput.get_slot(0).kind, Defs.InputSlotKind.KEYBOARD_RIGHT, "P2 moved up")
	_key(KEY_SPACE)
	assert_eq(Flow.party_size(), 2)
	node.set_ready(0, true)
	node.set_ready(1, true)
	assert_true(node.everybody_ready())
	node._process(JoinScreen.FINISH_DELAY + 0.05)
	assert_true(node.leaving, "both ready: on to the book select")
	assert_eq(Flow.current_screen, Flow.SCREEN_BOOK_SELECT)
	assert_eq(Flow.play_mode, Defs.GameMode.COOP)
	await _cleanup()


## The shared keyboard: the classic WASD + numpad layout first; the picture lights each player's keys in his colour and
## the free half in grey; the key list beside it names the keys; another preset changes them at once; the seated
## player's Swap (or Tab) opens the two-player key test and "back" closes it.
func test_join_panel_keyboard_presets_picture_and_key_test() -> void:
	var node: JoinScreen = await _open_join()
	assert_eq(node.get_layout_row().index, InputSlot.KeyboardLayout.CLASSIC, "classic first")
	_key(KEY_SPACE)
	var picture: JoinScreen.KeyboardPicture = node.get_picture()
	var left: Dictionary = picture.halves[Defs.InputSlotKind.KEYBOARD_LEFT]
	var right: Dictionary = picture.halves[Defs.InputSlotKind.KEYBOARD_RIGHT]
	assert_true(bool(left["taken"]), "P1 sits at the left half")
	assert_false(bool(right["taken"]), "the numpad is free")
	assert_eq(left["colour"], UiPlayers.PALETTE_COLOURS[&"yellow"][UiPlayers.FILL], "in P1's colour")
	for code: Key in [KEY_W, KEY_A, KEY_S, KEY_D, KEY_SPACE, _p1_strike(), KEY_E, KEY_Q]:
		assert_true((left["keys"] as Array).has(code), "the left half has %s" % OS.get_keycode_string(code))
	for code: Key in [KEY_KP_8, KEY_KP_4, KEY_KP_5, KEY_KP_6, KEY_KP_0, KEY_KP_ENTER, KEY_KP_ADD, KEY_KP_PERIOD]:
		assert_true((right["keys"] as Array).has(code), "the right half has %s" % OS.get_keycode_string(code))
	assert_eq(picture.half_of(_p1_strike(), 1), Defs.InputSlotKind.KEYBOARD_LEFT, "the left one is P1's strike")
	assert_eq(picture.half_of(_p1_strike(), 2), Defs.InputSlotKind.NONE, "the right one is nobody's")
	assert_eq(node.get_legend_text(Defs.InputSlotKind.KEYBOARD_LEFT, &"move"), "W A S D")
	assert_eq(node.get_legend_text(Defs.InputSlotKind.KEYBOARD_RIGHT, &"move"), "NUM 8 4 5 6")
	assert_eq(node.get_legend_text(Defs.InputSlotKind.KEYBOARD_RIGHT, Defs.ACT_ATTACK), "NUM ENTER")
	node.get_layout_row().step(1)
	assert_eq(GameInput.keyboard_layout(), InputSlot.KeyboardLayout.TWO_HANDS, "the preset row sets the layout")
	right = picture.halves[Defs.InputSlotKind.KEYBOARD_RIGHT]
	assert_true((right["keys"] as Array).has(KEY_SLASH), "two hands: P2 jumps with /")
	assert_eq(node.get_legend_text(Defs.InputSlotKind.KEYBOARD_RIGHT, &"move"), "ARROWS")
	assert_eq(node.get_legend_text(Defs.InputSlotKind.KEYBOARD_LEFT, Defs.ACT_JUMP), "G", "P1's keys follow the preset")
	node.get_layout_row().set_index(InputSlot.KeyboardLayout.CLASSIC, true)
	assert_eq(GameInput.keyboard_layout(), InputSlot.KeyboardLayout.CLASSIC)
	assert_false(node.is_key_test_open())
	_key(KEY_E)
	assert_true(node.is_key_test_open(), "P1's Swap opens the key test")
	assert_not_null(node.get_key_test())
	_press(&"ui_cancel")
	assert_false(node.is_key_test_open(), "back closes it")
	assert_false(node.leaving, "... and stays on the panel")
	_press(&"ui_focus_next")
	assert_true(node.is_key_test_open(), "Tab opens it too")
	_press(&"ui_cancel")
	_press(&"ui_cancel")
	assert_true(node.leaving, "back: the title")
	assert_eq(Flow.current_screen, Flow.SCREEN_TITLE)
	assert_eq(GameInput.get_slot(0).kind, Defs.InputSlotKind.ALL_DEVICES, "the seats are free again")
	assert_false(GameInput.has_menu_clusters())
	await _cleanup()


## A phone's player has no Jump to press on a menu: a tap on a free seat takes it with the touch overlay, ready at once
## (DESIGN.md D.11: one touch player, P2 on a pad).
func test_join_panel_touch_takes_a_seat() -> void:
	var node: JoinScreen = await _open_join()
	var finger: InputEventScreenTouch = InputEventScreenTouch.new()
	finger.position = node.get_card(0).get_global_rect().get_center()
	finger.pressed = true
	get_tree().root.push_input(finger)
	assert_eq(GameInput.get_slot(0).kind, Defs.InputSlotKind.TOUCH, "the tap took P1's seat")
	assert_true(node.is_ready(0), "ready at once")
	get_tree().root.push_input(finger)
	assert_eq(Flow.party_size(), 1, "a tap on a taken seat takes nothing")
	_pad_button(1, JOY_BUTTON_A)
	assert_eq(GameInput.get_slot(1).kind, Defs.InputSlotKind.PAD, "the partner on a pad")
	await _cleanup()


## The classic one-keyboard path of the flows (tools/autoplay/campaign_coop.flow): Space and Num 0 join, P1's Strike
## (the classic layout's: Left Ctrl since the orchestrator's G1 resolution, Left Shift before) and Num Enter held
## together make both ready, and the panel moves on by itself.
func test_join_panel_two_players_on_the_classic_keys() -> void:
	var node: JoinScreen = await _open_join()
	_key(KEY_SPACE)
	_key(KEY_KP_0)
	_key(_p1_strike(), true)
	_key(KEY_KP_ENTER, true)
	var waited: float = 0.0
	while not node.leaving and waited < 4.0:
		await get_tree().create_timer(0.1).timeout
		waited += 0.1
	_key(_p1_strike(), false)
	_key(KEY_KP_ENTER, false)
	assert_true(node.leaving, "both held Strike: ready, and the panel moved on (%.1f s)" % waited)
	assert_true(waited < JoinScreen.READY_SECONDS + JoinScreen.FINISH_DELAY + 1.0, "in about 1.6 s")
	assert_eq(Flow.current_screen, Flow.SCREEN_BOOK_SELECT)
	assert_eq(Flow.party_size(), 2)
	await _cleanup()


## A co-op run's map: the party walks the route in its colours (P2 behind P1), the markers come from the run's book;
## the menu clusters are off (a stray Look must not end the run).
func test_world_map_of_a_coop_party() -> void:
	Game.start_run(Defs.Difficulty.BEGINNER, Defs.GameMode.COOP, 2, 1)
	Game.runs[1].palette = &"pink"
	Flow.args = {"level_id": Levels.first_level(), "book": 1, "mode": Defs.GameMode.COOP}
	var node: WorldMapScreen = await _open(&"world_map") as WorldMapScreen
	assert_eq(node.get_partners().size(), 1, "P2 is on the map")
	assert_not_null(node.get_partners()[0].material, "in his colour")
	assert_false(GameInput.has_menu_clusters())
	assert_eq(node.get_marker_ids(), Levels.get_campaign(Defs.Difficulty.BEGINNER, 1), "Book I's stops")
	await _cleanup()
	Game.new_game(Defs.Difficulty.BEGINNER)


## A screen that appears under a resting mouse pointer keeps its keyboard focus: only a pointer that MOVES over an
## entry takes the focus (the title menu used to open with "Credits" or "Quit" focused wherever the pointer rested).
func test_menu_entries_take_the_focus_only_from_a_moving_pointer() -> void:
	var holder: VBoxContainer = VBoxContainer.new()
	add_node(holder)
	var first: UiButton = UiButton.new("UI_TITLE_PLAY")
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
		# The solo codes of both books (2.0: Book II codes start a Book II run, Flow.continue_game, PLAN.md P2.6 / P2.8;
		# co-op files have none).
		if str(Levels.get_value(level_id, "kind", Levels.KIND_MAIN)) == Levels.KIND_TEST \
				or not Levels.get_book(level_id) in [Levels.BOOK_1, Levels.BOOK_2] or not Levels.is_solo_level(level_id):
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
		assert_eq(Game.book, maxi(Levels.get_book(entry[1]), 1), "code %s plays in its book" % entry[0])
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
	assert_true(Save.is_level_unlocked(&"test_example", Defs.Difficulty.BEGINNER),
			"a level started by its code is listed as reached in the level select")
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


## The roll opens with the logo on screen, and a confirm pressed right away (still meant for The End) does not
## skip it; after the grace time confirm leaves as before.
func test_credits_ignore_an_early_confirm() -> void:
	var node: CreditsScreen = await _open(&"credits") as CreditsScreen
	await get_tree().process_frame
	var logo: Control = node.get("_roll").get_child(0) as Control
	assert_true(logo.get_global_rect().position.y < node.get_viewport_rect().size.y * 0.5, "the logo shows at once")
	_press(&"ui_accept")
	assert_eq(Flow.current_screen, Flow.SCREEN_BOOT, "an early confirm is ignored (the roll stays)")
	node.set("_age", CreditsScreen.ACCEPT_GRACE)
	_press(&"ui_accept")
	assert_eq(Flow.current_screen, Flow.SCREEN_TITLE, "later, confirm leaves")
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


# =================================================================================================================
# 2.0 phase 2 (ui-A, PLAN.md P2.8): key test order, the Far Shore map, the Book II wall, co-op medals, paintings
# =================================================================================================================

## "The key test must show players in join order": the numpad player who joins first is P1, so the test's first column
## is P1 on the numpad in his colour, lit by his own keys; the second column is P2 on W A S D. Before the partner joins
## his half is a "free" column with the layout's keys.
func test_key_test_shows_players_in_join_order() -> void:
	var node: JoinScreen = await _open_join()
	_key(KEY_KP_0)
	node.open_key_test()
	var test: JoinScreen.PartyKeyTest = node.get_key_test()
	assert_eq(test.columns_shown, [Vector2i(0, Defs.InputSlotKind.KEYBOARD_RIGHT),
			Vector2i(-1, Defs.InputSlotKind.KEYBOARD_LEFT)] as Array[Vector2i], "P1 on the numpad, then the free half")
	assert_eq(test.column_tag(0), "P1")
	assert_eq(test.column_tag(1), tr("UI_JOIN_FREE"))
	node.close_key_test()
	_key(KEY_SPACE)
	node.open_key_test()
	assert_eq(test.column_tag(0), "P1", "join order: the numpad player first")
	assert_eq(test.column_tag(1), "P2", "then the W A S D player")
	_key(KEY_KP_ENTER, true)
	assert_true(test.is_lit(0, &"attack"), "P1's Num Enter lights P1's Strike")
	assert_false(test.is_lit(1, &"attack"))
	_key(KEY_KP_ENTER, false)
	_key(KEY_SPACE, true)
	assert_true(test.is_lit(1, &"jump"), "Space lights P2's Jump")
	assert_false(test.is_lit(0, &"jump"), "... not P1's")
	_key(KEY_SPACE, false)
	await _cleanup()


## Book II plays on the Far Shore page: its own markers (MARKERS_B2) and the painting slab; Book I has neither.
func test_world_map_far_shore_page_and_slab() -> void:
	Save.reset()
	Game.start_run(Defs.Difficulty.BEGINNER, Defs.GameMode.SINGLE, 1, Levels.BOOK_2)
	var first: StringName = Levels.first_level(Levels.BOOK_2)
	assert_ne(first, &"", "Book II has a first stop")
	Flow.args = {"level_id": first, "book": Levels.BOOK_2, "mode": Defs.GameMode.SINGLE}
	var node: WorldMapScreen = await _open(&"world_map") as WorldMapScreen
	assert_eq(node.get_book(), Levels.BOOK_2)
	assert_eq(node.get_marker_ids(), Levels.get_campaign(Defs.Difficulty.BEGINNER, Levels.BOOK_2), "Book II's stops")
	var key: Vector2i = Vector2i(int(Levels.get_value(first, "world", 0)), int(Levels.get_value(first, "stage", 0)))
	assert_eq(node.get_markers()[0], WorldMapScreen.MARKERS_B2[key], "5-1 stands on the red mesa")
	assert_not_null(node.get_slab(), "the painting slab")
	assert_true(ResourceLoader.has_cached(WorldMapScreen.MAP_TEXTURE_B2), "the Far Shore page shows")
	assert_eq(node.get_map_rect().size, Vector2(1280.0, 360.0), "a 1280 x 360 page")
	var slab: Rect2 = node.get_slab().get_global_rect()
	var map_top: float = node.get_map_rect().position.y
	if node.size.y >= float(Tuning.VIEW_H) * Tuning.ART_SCALE:
		# On the game's 360-row view (or a taller one; an earlier test may leave the root viewport smaller).
		for marker: Vector2 in WorldMapScreen.MARKERS_B2.values():
			var plate_bottom: float = map_top + marker.y + WorldMapScreen.PLATE_GAP + WorldMapScreen.PLATE_HEIGHT
			assert_true(plate_bottom <= slab.position.y, "the slab stays under every stop and its plate (%s)" % marker)
	node.queue_free()
	await get_tree().process_frame
	Game.new_game(Defs.Difficulty.BEGINNER)
	Flow.args = {"level_id": Levels.first_level()}
	node = await _open(&"world_map") as WorldMapScreen
	assert_eq(node.get_book(), 1)
	assert_null(node.get_slab(), "Book I's page has no slab")
	await _cleanup()


## Every stop of the Far Shore page (MARKERS_B2, art-A's points) keeps its number plate clear of the other markers and
## plates, and the hero on a stop covers no other marker or plate (the Book I rule, test above). The eleven stops are
## injected as fake Book II levels: the build has only some of them yet.
func test_world_map_far_shore_markers_keep_their_distance() -> void:
	const GAP: float = 6.0
	const HERO: Rect2 = Rect2(-24.0, -52.0, 48.0, 52.0)
	var ids: Array[StringName] = []
	var order: int = 900
	for key: Vector2i in WorldMapScreen.MARKERS_B2:
		var id: StringName = StringName("zz_far_shore_%d_%d" % [key.x, key.y])
		var text: String = "[meta]\nformat = 2\nid = %s\nname = \"%s\"\nkind = main\nbook = 2\nworld = %d\nstage = %d\norder = %d\n" \
				% [id, id, key.x, key.y, order]
		Levels._meta[id] = Levels.parse_meta(text)
		Levels._paths[id] = Levels.get_level_path(&"test_example")
		ids.append(id)
		order += 1
	Levels._index_campaign()
	Game.start_run(Defs.Difficulty.EXPERT, Defs.GameMode.SINGLE, 1, Levels.BOOK_2)
	Flow.args = {"level_id": ids[0], "book": Levels.BOOK_2, "campaign": ids}
	var node: WorldMapScreen = await _open(&"world_map") as WorldMapScreen
	var markers: Array[Vector2] = node.get_markers()
	assert_eq(markers.size(), ids.size())
	var dots: Array[Rect2] = []
	var plates: Array[Rect2] = []
	for i: int in markers.size():
		var radius: float = WorldMapScreen.MARKER_RADIUS + 2.0
		dots.append(Rect2(markers[i] - Vector2(radius, radius), Vector2(radius, radius) * 2.0))
		plates.append(node.number_plate(markers[i], UiKit.level_number(ids[i])))
	for i: int in markers.size():
		assert_true(Rect2(Vector2.ZERO, node.get_map_rect().size).encloses(plates[i]), "%s: plate on the map" % ids[i])
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
	Levels.rescan()
	Game.new_game(Defs.Difficulty.BEGINNER)


## THE END of Book II with every painting found shows the cave mural; confirm leads to the credits.
func test_the_end_shows_the_mural() -> void:
	Flow.args = {"book": Levels.BOOK_2, "mode": Defs.GameMode.SINGLE, "mural": true}
	var node: TheEndScreen = await _open(&"the_end") as TheEndScreen
	assert_true(node.is_mural())
	assert_true(ResourceLoader.has_cached(UnlocksScreen.TEX_MURAL), "the mural picture shows")
	_press(&"ui_accept")
	assert_eq(Flow.current_screen, Flow.SCREEN_CREDITS)
	await _cleanup()


## The slab and the Cave Painting screen read the same state: found paintings, the next reward and its distance.
func test_painting_texts_follow_the_save() -> void:
	Save.reset()
	assert_eq(UnlocksScreen.next_text(), tr("UI_PAINTINGS_NEXT").format({"count": 5, "reward": tr("UI_REWARD_PATTERNS")}))
	for index: int in [0, 1, 2, 20, 21]:
		Save.add_painting(index)
	assert_eq(UnlocksScreen.next_text(), tr("UI_PAINTINGS_NEXT").format({"count": 5, "reward": tr("UI_REWARD_LOINCLOTHS")}),
			"5 found: the first four loincloths open, 5 more for the next four (G60)")
	assert_eq(UnlocksScreen.mural_region(7), Rect2(24.0, 16.0, 24.0, 16.0), "painting 7 is the mural's piece (1, 1)")
	assert_eq(UnlocksScreen.mural_region(29), Rect2(120.0, 64.0, 24.0, 16.0), "29 its last piece")
	assert_eq(UnlocksScreen.reward_icon_region(2, true), Rect2(48.0, 24.0, 24.0, 24.0), "row 1: the lit icon")
	assert_true(UnlocksScreen.painting_where(20).begins_with(tr("UI_PAINTINGS_COOP").get_slice("{", 0)),
			"20-29 hide in Book I co-op files")
	assert_true(UnlocksScreen.painting_where(0).contains(UiKit.level_name(&"w5_l1")), "0 is in 5-1")
	for index: int in Tuning.PAINTING_COUNT:
		Save.add_painting(index)
	assert_eq(UnlocksScreen.next_text(), tr("UI_PAINTINGS_ALL"))
	Save.reset()


## Book II's wall: "Only an expert eater may climb to the Roc!" over the Sky Spire; confirm returns to the title.
func test_expert_wall_of_book_two() -> void:
	Flow.args = {"book": Levels.BOOK_2, "mode": Defs.GameMode.SINGLE}
	var node: ExpertWallScreen = await _open(&"expert_wall") as ExpertWallScreen
	assert_eq(node.get_book(), Levels.BOOK_2)
	assert_eq(ExpertWallScreen.wall_text_key(Levels.BOOK_2), "UI_WALL_B2_TEXT")
	assert_eq(ExpertWallScreen.wall_text_key(1), "UI_WALL_TEXT", "Book I keeps its castle text")
	var texts: PackedStringArray = PackedStringArray()
	for label: Node in node.find_children("*", "Label", true, false):
		texts.append((label as Label).text)
	assert_true(texts.has("UI_WALL_B2_TEXT"), "the Roc text shows")
	var panel: PanelContainer = null
	for label: Node in node.find_children("*", "Label", true, false):
		if (label as Label).text == "UI_WALL_B2_TEXT":
			var up: Node = label.get_parent()
			while up != null and not up is PanelContainer:
				up = up.get_parent()
			panel = up as PanelContainer
	assert_not_null(panel, "the text panel")
	if panel != null and node.size.x >= float(Tuning.VIEW_W) * Tuning.ART_SCALE:
		await get_tree().process_frame
		var spire_x: float = node.global_position.x + roundf(node.size.x * ExpertWallScreen.SPIRE_AT)
		assert_true(panel.get_global_rect().end.x <= spire_x - ExpertWallScreen.ROC_ORBIT.x * 0.5,
				"the panel stands left of the spire, so the picture shows beside the words")
	_press(&"ui_accept")
	assert_eq(Flow.current_screen, Flow.SCREEN_TITLE)
	await _cleanup()


## The co-op tally (DESIGN.md D.11): both heroes walk in, the companion hands out the medals of the stage to their
## winners (ties share one), a skip hands out the rest; the tribe score is paid as before.
func test_tally_coop_medals_for_both_heroes() -> void:
	Game.start_run(Defs.Difficulty.BEGINNER, Defs.GameMode.COOP, 2, 1)
	Game.begin_level(&"test_example")
	Game.runs[0].food = 6
	Game.runs[1].food = 2
	Game.runs[1].revives = 1
	Game.runs[0].hurts = 1
	Game.runs[1].hurts = 1
	Game.add_tally_item(&"items/food", 3, 100)
	Flow.args = {"level_id": &"test_example", "percent": 50}
	var node: TallyScreen = await _open(&"tally") as TallyScreen
	assert_eq(node.get_actor_feet().size(), 3, "P1, the companion and P2")
	var medals: Array[Array] = node.get_medals()
	assert_eq(medals, [[&"most_food", 0], [&"hatchling", 1], [&"clumsiest", 0], [&"clumsiest", 1]] as Array[Array],
			"Most Food to P1, Hatchling to P2, a shared Clumsiest")
	assert_eq(node.get_board_texts(0).size(), 0, "nothing handed out yet")
	_press(&"ui_accept")
	assert_eq(node.medals_shown, medals.size(), "a skip hands out every medal")
	assert_eq(node.get_board_texts(0), PackedStringArray(["most_food", "clumsiest"]))
	assert_eq(node.get_board_texts(1), PackedStringArray(["hatchling", "clumsiest"]))
	assert_eq(Game.score, 100, "the tribe score: the item paid once")
	_press(&"ui_accept")
	assert_true(node.leaving)
	await _cleanup()
	Game.new_game(Defs.Difficulty.BEGINNER)


## The co-op tally runs through its medals by itself.
func test_tally_coop_hands_out_medals_by_itself() -> void:
	Game.start_run(Defs.Difficulty.BEGINNER, Defs.GameMode.COOP, 2, 1)
	Game.begin_level(&"test_example")
	Game.runs[1].food = 3
	Flow.args = {"level_id": &"test_example", "percent": 100}
	var node: TallyScreen = await _open(&"tally") as TallyScreen
	var waited: float = 0.0
	while not node.leaving and waited < 12.0:
		await get_tree().create_timer(0.25).timeout
		waited += 0.25
	assert_true(node.leaving, "the tally finishes without input")
	assert_eq(node.medals_shown, 1)
	assert_eq(node.get_board_texts(1), PackedStringArray(["most_food"]))
	await _cleanup()
	Game.new_game(Defs.Difficulty.BEGINNER)


## Co-op tally with the "Rival score" option: the board shows each hero's own points, an item paid again counts again
## for the hero who picked it (and the tribe), each hero's items fall on his side of the companion, and the medals
## over a hero's head hang nearer to him than to his partner.
func test_tally_coop_rival_score_and_own_piles() -> void:
	Settings.set_value(OptionsPanel.KEY_RIVAL_SCORE, true)
	Game.start_run(Defs.Difficulty.BEGINNER, Defs.GameMode.COOP, 2, 1)
	Game.begin_level(&"test_example")
	Game.runs[0].score = 1000
	Game.runs[1].score = 500
	Game.runs[0].food = 4
	Game.runs[0].plates = 2
	Game.runs[0].hurts = 3
	Game.runs[1].revives = 1
	Game.add_tally_item(&"items/food", 1, 100, 0)
	Game.add_tally_item(&"items/food", 2, 200, 1)
	Game.add_tally_item(&"items/food", 3, 300, 1)
	Flow.args = {"level_id": &"test_example", "percent": 50}
	var node: TallyScreen = await _open(&"tally") as TallyScreen
	var texts: PackedStringArray = PackedStringArray()
	for label: Node in node.find_children("*", "Label", true, false):
		texts.append((label as Label).text)
	assert_true(texts.has(UiKit.score_text(1000)) and texts.has(UiKit.score_text(500)), "the board shows both own scores")
	assert_true(node._catch_x(0) < node._catch_x(1), "P1's items fall on his side of the companion, P2's on the other")
	assert_eq(node._catch_x(1), node._catch_x(2), "P2's items make one pile")
	_press(&"ui_accept")
	assert_eq(Game.score, 600, "the tribe score: every item paid again")
	assert_eq(Game.runs[0].score, 1100, "P1's own score: his item again")
	assert_eq(Game.runs[1].score, 1000, "P2's own score: his two items again")
	texts.clear()
	for label: Node in node.find_children("*", "Label", true, false):
		texts.append((label as Label).text)
	assert_true(texts.has(UiKit.score_text(1100)) and texts.has(UiKit.score_text(1000)), "the board follows")
	var feet: PackedVector2Array = node.get_actor_feet()
	var heads: Dictionary = node._head_medals
	assert_eq((heads.get(0, []) as Array).size(), 3, "P1: Most Food, Strongman, Clumsiest")
	for slot: Variant in heads:
		var own: float = feet[0].x if int(slot) == 0 else feet[2].x
		var other: float = feet[2].x if int(slot) == 0 else feet[0].x
		for icon: Variant in heads[slot]:
			var centre: float = (icon as Control).position.x + 8.0
			assert_true(absf(centre - own) < absf(centre - other), "P%d's medal hangs over P%d" % [int(slot) + 1,
					int(slot) + 1])
	_press(&"ui_accept")
	await _cleanup()
	Settings.set_value(OptionsPanel.KEY_RIVAL_SCORE, false)
	Game.new_game(Defs.Difficulty.BEGINNER)


## The Far Shore slab's line: always the whole "5 more: Big Bounce, Lights Out, Giant Rain"; a line longer than the slab
## scrolls through it as a ticker, clipped inside the slab; the next reward's icon is framed.
func test_world_map_slab_line_scrolls_when_long() -> void:
	Save.reset()
	for index: int in 10:
		Save.add_painting(index)
	assert_eq(WorldMapScreen.PaintingSlab.next_reward_id(), &"variants")
	var slab: WorldMapScreen.PaintingSlab = WorldMapScreen.PaintingSlab.new()
	add_node(slab)
	slab.size = slab.custom_minimum_size
	await get_tree().process_frame
	assert_eq(slab.line_text, UnlocksScreen.next_text(), "the whole line, never cut")
	assert_true(slab.is_ticker(), "the variants' line is longer than the slab")
	assert_true(Rect2(Vector2.ZERO, slab.size).encloses(Rect2(slab.line.position, slab.line.size)),
			"the ticker is clipped inside the slab")
	assert_true(slab.line.clip_contents)
	var before: float = slab.ticker_offset
	slab._process(0.5)
	assert_true(slab.ticker_offset > before, "it scrolls")
	slab.queue_free()
	for index: int in Tuning.PAINTING_COUNT:
		Save.add_painting(index)
	assert_eq(WorldMapScreen.PaintingSlab.next_reward_id(), &"", "every reward open")
	Save.reset()


## Every phase-2 screen of this file fits the game's 640 x 360 view in a full state (its content needs no more room
## than that, whatever the test viewport): the Far Shore map, the Book II wall, THE END's mural, the Cave Paintings,
## the co-op tally with the Rival score and six medals.
func test_phase_two_screens_fit_the_view() -> void:
	Save.reset()
	for index: int in Tuning.PAINTING_COUNT:
		Save.add_painting(index)
	var states: Array[Dictionary] = [
		{"screen": &"world_map", "args": {"level_id": Levels.first_level(Levels.BOOK_2), "book": Levels.BOOK_2}},
		{"screen": &"expert_wall", "args": {"book": Levels.BOOK_2, "mode": Defs.GameMode.SINGLE}},
		{"screen": &"the_end", "args": {"book": Levels.BOOK_2, "mode": Defs.GameMode.SINGLE, "mural": true}},
		{"screen": &"unlocks", "args": {"back": Flow.SCREEN_TITLE}},
		{"screen": &"tally", "args": {"level_id": &"test_example", "percent": 100}, "coop": true},
	]
	Settings.set_value(OptionsPanel.KEY_RIVAL_SCORE, true)
	var base: Vector2 = Vector2(Tuning.VIEW_W, Tuning.VIEW_H) * float(Tuning.ART_SCALE)
	for state: Dictionary in states:
		if state.get("coop", false):
			Game.start_run(Defs.Difficulty.BEGINNER, Defs.GameMode.COOP, 2, 1)
			Game.begin_level(&"test_example")
			for run: PlayerRun in Game.runs:
				run.food = 3
				run.best_chain = 2
				run.revives = 1
				run.bats = 1
				run.plates = 1
				run.deaths = 1
		else:
			Game.start_run(Defs.Difficulty.BEGINNER, Defs.GameMode.SINGLE, 1, Levels.BOOK_2)
		Flow.args = state["args"]
		var node: UiScreen = await _open(state["screen"])
		if node is TallyScreen:
			_press(&"ui_accept")
			assert_eq((node as TallyScreen).medals_shown, 12, "six medals, each shared by both heroes")
		await get_tree().process_frame
		var need: Vector2 = node.safe.get_combined_minimum_size()
		assert_true(need.x <= base.x and need.y <= base.y, "%s fits the 640 x 360 view (needs %s)" % [state["screen"], need])
		node.queue_free()
		await get_tree().process_frame
	Settings.set_value(OptionsPanel.KEY_RIVAL_SCORE, false)
	await _cleanup()
	Game.new_game(Defs.Difficulty.BEGINNER)
	Save.reset()


## A single-player tally has no medals (the 1.0 tally).
func test_tally_single_player_has_no_medals() -> void:
	Game.new_game(Defs.Difficulty.BEGINNER)
	Game.begin_level(&"test_example")
	Game.runs[0].food = 9
	Flow.args = {"level_id": &"test_example", "percent": 100}
	var node: TallyScreen = await _open(&"tally") as TallyScreen
	assert_eq(node.get_medals().size(), 0)
	assert_eq(node.get_actor_feet().size(), 2)
	await _cleanup()


## The Cave Painting screen: 30 slots (found ones show their picture), the focus on the first painting still missing,
## the reward ladder; "back" returns to where it was opened.
func test_unlocks_screen_shows_paintings_and_rewards() -> void:
	Save.reset()
	for index: int in [0, 1, 2, 3, 4]:
		Save.add_painting(index)
	Flow.args = {"back": Flow.SCREEN_TITLE}
	var node: UnlocksScreen = await _open(&"unlocks") as UnlocksScreen
	assert_true(node.get_slot(0).found)
	assert_false(node.get_slot(5).found)
	assert_eq(node.focused_index, 5, "the hunt goes on at the first painting not found")
	assert_true(node.get_slot(5).has_focus())
	assert_true(node.get_info_text().contains(tr("UI_PAINTINGS_MISSING")))
	assert_eq(node.get_picture().index, 5, "the focused painting's picture")
	assert_false(node.get_picture().found, "... a carved question mark while it is missing")
	node.get_slot(2).grab_focus()
	assert_eq(node.get_picture().index, 2)
	assert_true(node.get_picture().found, "a found painting shows art-A's picture")
	assert_true(ResourceLoader.has_cached(UnlocksScreen.TEX_PAINTINGS), "ui/paintings.png")
	node.get_slot(5).grab_focus()
	_press(&"ui_down")
	assert_eq(node.focused_index, 5 + UnlocksScreen.MURAL_COLUMNS, "Down: the socket under it")
	_press(&"ui_right")
	assert_eq(node.focused_index, UnlocksScreen.MURAL_COLUMNS, "Right from the row's end wraps to its start")
	var status: PackedStringArray = node.get_reward_status()
	assert_eq(status.size(), UnlockTable.REWARDS.size())
	assert_eq(status[0], tr("UI_PAINTINGS_OPEN"), "5 paintings: Mesa Rodeo is open")
	assert_eq(status[1], tr("UI_PAINTINGS_NEEDS").format({"count": 10}))
	_press(&"ui_cancel")
	assert_eq(Flow.current_screen, Flow.SCREEN_TITLE)
	await _cleanup()
	Save.reset()


# =================================================================================================================
# Phase 3 (PLAN.md 6; wf9): the co-op tally of every Book II stage, Munch, THE END and the expert wall per book and mode
# =================================================================================================================

## Every backdrop a level file may name (LevelData.BACKGROUNDS, also the Book II stages still to come) has a tally
## backdrop with all its layers, and every terrain atlas a Book II biome falls back to exists.
func test_every_level_backdrop_has_a_tally_picture() -> void:
	for background: String in LevelData.BACKGROUNDS:
		if background == "none":
			continue
		assert_true(UiBackdrop.has_set(background), "the tally can show '%s'" % background)
		var entry: Dictionary = UiBackdrop.entry_of(background)
		assert_true((entry.get("layers", []) as Array).size() >= 3, "%s has its layers" % background)
		for layer: Array in entry.get("layers", []):
			assert_true(ResourceLoader.exists(str(layer[0])), "%s: %s exists" % [background, layer[0]])
	for biome: Variant in LevelData.BIOME_TERRAIN:
		assert_true(ResourceLoader.exists(UiGround.TERRAIN_DIR + str(LevelData.BIOME_TERRAIN[biome]) + ".png"),
				"the %s ground exists" % biome)
	for biome: Variant in LevelData.BIOME_BACKGROUND:
		assert_true(UiBackdrop.has_set(str(LevelData.BIOME_BACKGROUND[biome])), "%s falls back to a backdrop" % biome)


## The co-op tally of every Book II stage that exists (solo files in a co-op run's tally fall back to them; every
## co-op file of Book II; new files are picked up as the designers add them): the stage's own night backdrop and
## ground, both heroes in their colours on that ground, the medals handed out, and the board, the heroes and the
## companion inside the view at 640 x 360 and 800 x 360 with the board clear of the heroes.
func test_tally_coop_of_every_book_two_stage() -> void:
	var ids: Array[StringName] = []
	for level_id: StringName in Levels.all_ids():
		var kind: String = Levels.get_level_kind(level_id)
		if Levels.get_book(level_id) == Levels.BOOK_2 and kind in ["main", "sub", "bonus", "ending", "coop"]:
			ids.append(level_id)
	ids.sort()
	assert_true(ids.size() >= 10, "the Book II files of worlds 5-6 at least (%d)" % ids.size())
	var shown: PackedStringArray = PackedStringArray()
	for level_id: StringName in ids:
		Game.start_run(Defs.Difficulty.EXPERT, Defs.GameMode.COOP, 2, Levels.BOOK_2)
		Game.runs[1].palette = &"blue"
		Game.begin_level(level_id)
		Game.runs[0].food = 5
		Game.runs[1].revives = 1
		Game.runs[1].best_chain = 4
		Game.runs[0].hurts = 1
		Game.add_tally_item(&"items/food", 2, 100)
		Game.add_tally_item(&"items/painting", 3, 0)
		Flow.args = {"level_id": level_id, "percent": 90}
		var node: TallyScreen = await _open(&"tally") as TallyScreen
		var expected: String = TallyScreen.backdrop_for(level_id)
		var own: String = str(Levels.get_value(level_id, "background", ""))
		if UiBackdrop.has_set(own):
			assert_eq(expected, own, "%s: its own backdrop" % level_id)
		assert_eq(node.get_backdrop().backdrop_id, expected, "%s: the backdrop shows" % level_id)
		assert_true(node.get_backdrop().get_layer_count() >= 3, "%s: with its layers" % level_id)
		var terrain: String = str(Levels.get_value(level_id, "terrain_a", ""))
		if ResourceLoader.exists(UiGround.TERRAIN_DIR + terrain + ".png"):
			assert_eq(TallyScreen.ground_for(level_id), terrain, "%s: the stage's own ground" % level_id)
		else:
			# A terrain art-B has not drawn yet: the tally stands on the biome's set, as the level itself does.
			var biome: String = str(Levels.get_value(level_id, "biome", "jungle"))
			assert_eq(TallyScreen.ground_for(level_id), str(LevelData.BIOME_TERRAIN.get(biome, "jungle/terrain_grass")),
					"%s: the biome's ground while '%s' is not drawn" % [level_id, terrain])
			print("    note: %s names terrain '%s', not drawn yet: the tally uses its biome's" % [level_id, terrain])
		assert_true((node.get("_ground") as UiGround).has_atlas(), "%s: its ground atlas" % level_id)
		assert_null(node.get_munch(), "%s: no Munch in co-op (P2 is Munch)" % level_id)
		shown.append("%s=%s" % [level_id, expected])
		_press(&"ui_accept")
		assert_eq(node.medals_shown, node.get_medals().size(), "%s: every medal handed out" % level_id)
		assert_true(node.get_medals().size() >= 3, "%s: the medals of the stage" % level_id)
		for width: float in [640.0, 800.0]:
			node.size = Vector2(width, 360.0)
			await get_tree().process_frame
			await get_tree().process_frame
			var view: Rect2 = Rect2(Vector2.ZERO, node.size)
			var feet: PackedVector2Array = node.get_actor_feet()
			assert_eq(feet.size(), 3, "%s: P1, the companion, P2" % level_id)
			for foot: Vector2 in feet:
				assert_eq(foot.y, node.get_ground_y(), "%s: on the ground at %d px" % [level_id, width])
				assert_true(foot.x > 0.0 and foot.x < width, "%s: inside the view at %d px" % [level_id, width])
			var board: Rect2 = node.get_board_rect()
			assert_true(view.grow(0.5).encloses(board), "%s: the board inside the view at %d px (%s)" % [level_id, width,
					board])
			for i: int in [0, 2]:
				var hero: Rect2 = Rect2(feet[i] - Vector2(24.0, 120.0), Vector2(48.0, 120.0))
				assert_false(board.intersects(hero), "%s: the board clear of a hero at %d px" % [level_id, width])
		node.queue_free()
		await get_tree().process_frame
		await _cleanup()
	print("    tally backdrops: %s" % ", ".join(shown))
	Game.new_game(Defs.Difficulty.BEGINNER)


## Book II solo: Munch waves from the companion's side (DESIGN.md A.1) - he walks in with him, waves while they stand
## and stays inside the view; Book I solo has no Munch.
func test_tally_book_two_solo_munch_waves() -> void:
	Game.start_run(Defs.Difficulty.BEGINNER, Defs.GameMode.SINGLE, 1, Levels.BOOK_2)
	Game.begin_level(&"w5_l1")
	Game.add_tally_item(&"items/food", 3, 100)
	Flow.args = {"level_id": &"w5_l1", "percent": 75}
	var node: TallyScreen = await _open(&"tally") as TallyScreen
	var munch: UiActor = node.get_munch()
	assert_not_null(munch, "Munch is there")
	assert_eq(node.get_backdrop().backdrop_id, "canyon", "the stage's own backdrop")
	_press(&"ui_accept")
	await get_tree().process_frame
	var feet: PackedVector2Array = node.get_actor_feet()
	assert_eq(munch.position, feet[1] + Vector2(TallyScreen.MUNCH_GAP, 0.0), "beside the companion")
	assert_eq(munch.animation, &"victory", "waving")
	assert_not_null(munch.material, "in his blue")
	for width: float in [640.0, 800.0]:
		node.size = Vector2(width, 360.0)
		await get_tree().process_frame
		node._process(0.0)
		assert_true(munch.position.x + 30.0 < width, "inside the view at %d px" % width)
	await _cleanup()
	Game.start_run(Defs.Difficulty.BEGINNER, Defs.GameMode.SINGLE, 1, 1)
	Game.begin_level(&"w1_l1")
	Flow.args = {"level_id": &"w1_l1", "percent": 75}
	var book_one: TallyScreen = await _open(&"tally") as TallyScreen
	assert_null(book_one.get_munch(), "Book I: no Munch")
	assert_eq(book_one.get_backdrop().backdrop_id, "jungle")
	await _cleanup()
	Game.new_game(Defs.Difficulty.BEGINNER)


## THE END per book and mode: Book I solo keeps the 1.0 village and cast; Book I co-op puts the party in the hero's
## place in their colours; Book II shows the home beach (raft, the Great Roast, palms, the home hut) with Grub and Munch
## in solo and the party in co-op. Every actor stands on the ground inside the view at 640 and 800 px, apart from the
## others; the mural still replaces the picture when every painting is found.
func test_the_end_pictures_per_book_and_mode() -> void:
	var cases: Array[Array] = [
		[1, Defs.GameMode.SINGLE, 1, TheEndScreen.Picture.VILLAGE, PackedInt32Array([0])],
		[1, Defs.GameMode.COOP, 2, TheEndScreen.Picture.VILLAGE, PackedInt32Array([0, 1])],
		[2, Defs.GameMode.SINGLE, 1, TheEndScreen.Picture.BEACH, PackedInt32Array([0, -1])],
		[2, Defs.GameMode.COOP, 2, TheEndScreen.Picture.BEACH, PackedInt32Array([0, 1])],
	]
	for case: Array in cases:
		var label: String = "Book %d %s" % [case[0], "co-op" if case[1] == Defs.GameMode.COOP else "solo"]
		Game.start_run(Defs.Difficulty.EXPERT, int(case[1]), int(case[2]), int(case[0]))
		if int(case[2]) > 1:
			Game.runs[1].palette = &"pink"
		Flow.args = {"book": case[0], "mode": case[1], "mural": false}
		var node: TheEndScreen = await _open(&"the_end") as TheEndScreen
		assert_eq(node.get_picture(), int(case[3]), "%s: its picture" % label)
		var heroes: Array[UiActor] = node.get_heroes()
		var slots: PackedInt32Array = PackedInt32Array()
		for hero: UiActor in heroes:
			slots.append(int(hero.get_meta(&"slot")))
			assert_eq(hero.animation, &"victory", "%s: the heroes cheer" % label)
		assert_eq(slots, case[4] as PackedInt32Array, "%s: who cheers" % label)
		if case[0] == 1 and case[1] == Defs.GameMode.SINGLE:
			var offsets: Array = []
			for entry: Array in node.get_cast():
				offsets.append(entry[2])
			assert_eq(offsets, [-150.0, -86.0, 0.0, 70.0, 140.0], "Book I solo: the 1.0 cast")
			assert_null(heroes[0].material, "Book I solo: the 1.0 hero")
		if heroes.size() > 1:
			assert_not_null(heroes[1].material, "%s: the second hero in his own colours" % label)
		if case[1] == Defs.GameMode.COOP:
			var look: Array = HeroPalette.resolve(0, Game.get_run(0))
			assert_eq(heroes[0].material == null, HeroPalette.is_identity(look[0], int(look[1])),
					"%s: P1 in his colours (none needed for the 1.0 yellow)" % label)
		for width: float in [640.0, 800.0]:
			node.size = Vector2(width, 360.0)
			await get_tree().process_frame
			await get_tree().process_frame
			var xs: Array[float] = []
			for actor: Node in node.get_children():
				if actor is UiActor:
					var feet: Vector2 = (actor as UiActor).position
					assert_true(feet.x - 20.0 > 0.0 and feet.x + 20.0 < width, "%s: inside the view at %d px" % [label, width])
					assert_true(feet.y > 300.0 and feet.y < 360.0, "%s: on the ground" % label)
					xs.append(feet.x)
			xs.sort()
			for i: int in xs.size() - 1:
				assert_true(xs[i + 1] - xs[i] >= 50.0, "%s: the cast stands apart at %d px (%s)" % [label, width, xs])
		_press(&"ui_accept")
		assert_eq(Flow.current_screen, Flow.SCREEN_CREDITS, "%s: on to the credits" % label)
		await _cleanup()
	Flow.args = {"book": 2, "mode": Defs.GameMode.COOP, "mural": true}
	var mural: TheEndScreen = await _open(&"the_end") as TheEndScreen
	assert_true(mural.is_mural(), "all 30 paintings: the mural, in co-op too")
	await _cleanup()
	Game.new_game(Defs.Difficulty.BEGINNER)


## The expert wall of a co-op run (both books): the party stands before the warrior in their own colours, facing him,
## on the ground and inside the view at 640 and 800 px, clear of the text panel; the warrior turns to them. Solo keeps
## the picture without heroes.
func test_expert_wall_of_a_coop_party() -> void:
	for book: int in [1, 2]:
		Game.start_run(Defs.Difficulty.BEGINNER, Defs.GameMode.COOP, 2, book)
		Game.runs[1].palette = &"blue"
		Flow.args = {"book": book, "mode": Defs.GameMode.COOP}
		var node: ExpertWallScreen = await _open(&"expert_wall") as ExpertWallScreen
		var party: Array[UiActor] = node.get_party()
		assert_eq(party.size(), 2, "Book %d co-op: both heroes" % book)
		for width: float in [640.0, 800.0]:
			node.size = Vector2(width, 360.0)
			await get_tree().process_frame
			await get_tree().process_frame
			var guard: UiActor = node.get_guard()
			var panel: Rect2 = Rect2()
			for label: Node in node.find_children("*", "Label", true, false):
				if (label as Label).text == ExpertWallScreen.wall_text_key(book):
					var up: Node = label.get_parent()
					while up != null and not up is PanelContainer:
						up = up.get_parent()
					panel = (up as Control).get_global_rect()
			assert_not_null(party[1].material, "Book %d: P2 in his colours" % book)
			for hero: UiActor in party:
				assert_true(hero.position.x < guard.position.x, "Book %d: before the warrior" % book)
				assert_eq(hero.position.y, guard.position.y, "Book %d: on the ground" % book)
				assert_true(hero.position.x - 24.0 > 0.0, "Book %d: inside the view at %d px" % [book, width])
				var body: Rect2 = Rect2(hero.position - Vector2(24.0, 70.0), Vector2(48.0, 70.0))
				assert_false(panel.intersects(body), "Book %d: clear of the text panel at %d px" % [book, width])
			assert_true(guard.position.x - party[0].position.x >= 50.0, "Book %d: P1 a step from the warrior" % book)
		await _cleanup()
	Game.start_run(Defs.Difficulty.BEGINNER, Defs.GameMode.SINGLE, 1, 2)
	Flow.args = {"book": 2, "mode": Defs.GameMode.SINGLE}
	var solo: ExpertWallScreen = await _open(&"expert_wall") as ExpertWallScreen
	assert_eq(solo.get_party().size(), 0, "solo: the picture without heroes")
	await _cleanup()
	Game.new_game(Defs.Difficulty.BEGINNER)


# =================================================================================================================
# The UI pass (wf9 / PLAN.md 6): every 2.0 screen laid out at 640 x 360 and 800 x 360
# =================================================================================================================

## The views of the UI pass (art px): the game's base view and the widest one the stretch gives (a 20:9 phone).
const PASS_VIEWS: Array[Vector2] = [Vector2(640.0, 360.0), Vector2(800.0, 360.0)]
## Two texts are "over each other" when their glyph boxes share more than this many px in both directions (the line
## boxes of a pixel face reach past its glyphs; stacked lines may touch).
const PASS_OVERLAP: float = 3.0
## Texts and entries the last [method layout_problems] looked at (x: texts, y: buttons and focusable entries).
static var pass_checked: Vector2i = Vector2i.ZERO


## The UI check itself finds what it is for: a text past the view's edge, two texts over each other, a clipped text
## that cuts its words, an entry past the edge; a transparent text, a text scrolled out of its clipping list and a
## clean layout pass.
func test_ui_check_finds_cut_and_overlapping_texts() -> void:
	var root: Control = Control.new()
	root.size = Vector2(640.0, 360.0)
	add_node(root)
	var clean: Label = UiKit.label("Most Food", UiKit.Style.SMALL)
	clean.position = Vector2(10.0, 10.0)
	root.add_child(clean)
	var hidden: Label = UiKit.label("Not handed out yet", UiKit.Style.SMALL)
	hidden.position = Vector2(12.0, 12.0)
	hidden.modulate.a = 0.0
	root.add_child(hidden)
	var list: Control = Control.new()
	list.clip_contents = true
	list.position = Vector2(10.0, 200.0)
	list.size = Vector2(200.0, 40.0)
	root.add_child(list)
	var scrolled: Label = UiKit.label("Scrolled away", UiKit.Style.SMALL)
	scrolled.position = Vector2(0.0, 80.0)
	list.add_child(scrolled)
	await get_tree().process_frame
	assert_eq(layout_problems(root), PackedStringArray(), "a clean layout passes")
	assert_eq(pass_checked, Vector2i(1, 0), "one text looked at; the transparent and the scrolled-away ones do not count")
	var past: Label = UiKit.label("Leaning Tower", UiKit.Style.SMALL)
	past.position = Vector2(600.0, 100.0)
	root.add_child(past)
	var over: Label = UiKit.label("Butterfingers", UiKit.Style.SMALL)
	over.position = Vector2(14.0, 12.0)
	root.add_child(over)
	var cut: Label = UiKit.label("Longest head-bounce chain", UiKit.Style.SMALL)
	cut.clip_text = true
	cut.position = Vector2(10.0, 300.0)
	root.add_child(cut)
	cut.size = Vector2(40.0, cut.size.y)
	var entry: UiButton = UiButton.new("UI_VS_REMATCH")
	entry.position = Vector2(-30.0, 330.0)
	root.add_child(entry)
	await get_tree().process_frame
	var problems: String = "; ".join(layout_problems(root))
	assert_true(problems.contains("Leaning Tower") and problems.contains("reaches past"), "past the edge: %s" % problems)
	assert_true(problems.contains("over each other"), "two texts over each other: %s" % problems)
	assert_true(problems.contains("is cut"), "a cut text: %s" % problems)
	assert_true(problems.contains("entry"), "an entry past the edge: %s" % problems)
	root.queue_free()


## The UI pass of the new screens of this file (the versus screens: tests/test_ui_versus.gd): each in a full state, at
## 640 x 360 and at 800 x 360, has no text or entry past the view's edge, no two texts over each other and no clipped
## text that cuts its words ([method layout_problems]).
func test_new_screens_pass_the_ui_check_at_640_and_800() -> void:
	Save.reset()
	for index: int in 17:
		Save.add_painting(index)
	Settings.set_value(OptionsPanel.KEY_RIVAL_SCORE, true)
	var states: Array[Dictionary] = [
		{"name": "mode_select solo B2", "screen": &"mode_select", "book": 2},
		{"name": "mode_select co-op", "screen": &"mode_select", "coop_slots": true},
		{"name": "book_select solo", "screen": &"book_select"},
		{"name": "book_select co-op", "screen": &"book_select", "play_mode": Defs.GameMode.COOP},
		{"name": "join (two keyboards, a pad)", "screen": &"join", "join": true},
		{"name": "world_map B2", "screen": &"world_map", "run": [Defs.GameMode.SINGLE, 1, 2],
			"args": {"level_id": Levels.first_level(Levels.BOOK_2), "book": Levels.BOOK_2}},
		{"name": "world_map B1 co-op", "screen": &"world_map", "run": [Defs.GameMode.COOP, 2, 1],
			"args": {"level_id": Levels.first_level(), "book": 1, "mode": Defs.GameMode.COOP}},
		{"name": "tally co-op w6_l2b", "screen": &"tally", "run": [Defs.GameMode.COOP, 2, 2], "medals": true,
			"args": {"level_id": &"w6_l2b", "percent": 87}, "settle": 1.2},
		{"name": "tally solo B2 w5_l1", "screen": &"tally", "run": [Defs.GameMode.SINGLE, 1, 2],
			"args": {"level_id": &"w5_l1", "percent": 75}, "settle": 1.2},
		{"name": "expert_wall B2", "screen": &"expert_wall", "run": [Defs.GameMode.SINGLE, 1, 2],
			"args": {"book": 2, "mode": Defs.GameMode.SINGLE}},
		{"name": "expert_wall B1 co-op", "screen": &"expert_wall", "run": [Defs.GameMode.COOP, 2, 1],
			"args": {"book": 1, "mode": Defs.GameMode.COOP}},
		{"name": "expert_wall B2 co-op", "screen": &"expert_wall", "run": [Defs.GameMode.COOP, 2, 2],
			"args": {"book": 2, "mode": Defs.GameMode.COOP}},
		{"name": "the_end B2", "screen": &"the_end", "run": [Defs.GameMode.SINGLE, 1, 2],
			"args": {"book": 2, "mode": Defs.GameMode.SINGLE, "mural": false}},
		{"name": "the_end B1 co-op", "screen": &"the_end", "run": [Defs.GameMode.COOP, 2, 1],
			"args": {"book": 1, "mode": Defs.GameMode.COOP, "mural": false}},
		{"name": "the_end B2 co-op", "screen": &"the_end", "run": [Defs.GameMode.COOP, 2, 2],
			"args": {"book": 2, "mode": Defs.GameMode.COOP, "mural": false}},
		{"name": "the_end mural", "screen": &"the_end", "run": [Defs.GameMode.COOP, 2, 2],
			"args": {"book": 2, "mode": Defs.GameMode.COOP, "mural": true}},
		{"name": "unlocks", "screen": &"unlocks", "args": {"back": Flow.SCREEN_TITLE}},
		{"name": "options", "screen": &"options", "args": {}},
		{"name": "options: P2's keys", "screen": &"options", "args": {}, "options": "bindings"},
		{"name": "options: key test", "screen": &"options", "args": {}, "options": "key_test"},
	]
	var report: PackedStringArray = PackedStringArray()
	for state: Dictionary in states:
		for view: Vector2 in PASS_VIEWS:
			var node: UiScreen = await _open_pass_state(state)
			node.size = view
			if state.has("settle"):
				# The tally reveals its heading and score lines one after the other.
				await get_tree().create_timer(float(state["settle"])).timeout
			if node is TallyScreen:
				(node as TallyScreen).skip()
			for frame: int in 3:
				await get_tree().process_frame
			if node.has_method(&"_process"):
				node.call(&"_process", 0.0)
			await get_tree().process_frame
			var problems: PackedStringArray = layout_problems(node)
			assert_true(problems.is_empty(), "%s at %d x %d: %s" % [state["name"], view.x, view.y, "; ".join(problems)])
			assert_true(pass_checked.x >= 2, "%s: the check saw its texts (%d)" % [state["name"], pass_checked.x])
			report.append("%s %d: %d texts %d entries%s" % [state["name"], view.x, pass_checked.x, pass_checked.y,
					"" if problems.is_empty() else " FAIL"])
			node.queue_free()
			await get_tree().process_frame
			await _cleanup()
			Flow.play_mode = Defs.GameMode.SINGLE
			Flow.play_book = 1
			GameInput.set_menu_clusters(false)
			GameInput.reset_slots()
	print("    ui pass: %d screen states x %d views: %s" % [states.size(), PASS_VIEWS.size(), ", ".join(report)])
	Settings.set_value(OptionsPanel.KEY_RIVAL_SCORE, false)
	Game.new_game(Defs.Difficulty.BEGINNER)
	Save.reset()


## Open a screen of the UI pass in its state (see the states of the test above).
func _open_pass_state(state: Dictionary) -> UiScreen:
	if state.has("run"):
		var run: Array = state["run"]
		Game.start_run(Defs.Difficulty.BEGINNER, int(run[0]), int(run[1]), int(run[2]))
		if int(run[1]) > 1:
			Game.runs[1].palette = &"blue"
		var args: Dictionary = state.get("args", {})
		if args.has("level_id"):
			Game.begin_level(StringName(str(args["level_id"])))
	else:
		Game.new_game(Defs.Difficulty.BEGINNER)
	if state.get("medals", false):
		for run: PlayerRun in Game.party_runs():
			run.food = 3
			run.best_chain = 2
			run.revives = 1
			run.bats = 1
			run.plates = 1
			run.deaths = 1
		Game.runs[0].score = 123450
		Game.runs[1].score = 98760
		Game.add_tally_item(&"items/food", 2, 100, 0)
		Game.add_tally_item(&"items/painting", 5, 0, 1)
	elif str(state.get("screen", "")) == "tally":
		Game.add_tally_item(&"items/food", 2, 100)
	Flow.play_book = int(state.get("book", 1))
	Flow.play_mode = int(state.get("play_mode", Defs.GameMode.SINGLE))
	if state.get("coop_slots", false):
		Flow.play_mode = Defs.GameMode.COOP
		GameInput.assign_slot(0, InputSlot.keyboard(Defs.InputSlotKind.KEYBOARD_LEFT))
		GameInput.assign_slot(1, InputSlot.keyboard(Defs.InputSlotKind.KEYBOARD_RIGHT))
	Flow.args = (state.get("args", {}) as Dictionary).duplicate()
	var node: UiScreen = null
	if state.get("join", false):
		node = await _open_join()
		_key(KEY_SPACE)
		_key(KEY_KP_0)
		_pad_button(2, JOY_BUTTON_A)
		await get_tree().process_frame
	else:
		node = await _open(state["screen"])
	if state.has("options"):
		var panel: OptionsPanel = node.get("_panel") as OptionsPanel
		if str(state["options"]) == "bindings":
			panel.open_bindings(1)
		else:
			panel.open_key_test()
		await get_tree().process_frame
	return node


## What is wrong with the layout of `node` (a screen, or any control) at its present size; empty when nothing. Checked:
## every text (its glyph box: the label's text width and line height where its alignment puts them) and every button
## or focusable entry lies inside the view; no two texts lie over each other (more than PASS_OVERLAP px both ways); a
## text that clips (clip_text or an overrun rule) has room for all of it. A hidden or transparent control (a row whose
## award is not handed out yet) does not count; inside a clipping container (a scroll list, a ticker) only the part the
## container shows counts.
static func layout_problems(node: Control) -> PackedStringArray:
	var problems: PackedStringArray = PackedStringArray()
	pass_checked = Vector2i.ZERO
	var view: Rect2 = Rect2(Vector2.ZERO, node.size).grow(1.0)
	var origin: Vector2 = node.global_position
	var texts: Array[Array] = []
	for found: Node in node.find_children("*", "Control", true, false):
		var control: Control = found as Control
		if not control.is_visible_in_tree() or _pass_alpha(control, node) < 0.05:
			continue
		var rect: Rect2 = Rect2()
		var what: String = ""
		if control is Label:
			var label: Label = control as Label
			var text: String = label.atr(label.text).strip_edges()
			if text == "":
				continue
			var cut: String = _pass_cut_text(label, text)
			if cut != "":
				problems.append(cut)
			rect = _pass_text_rect(label)
			what = "text '%s'" % text.left(24)
		elif control is BaseButton or control.focus_mode != Control.FOCUS_NONE:
			rect = control.get_global_rect()
			what = "entry %s" % control.name
		else:
			continue
		rect = Rect2(rect.position - origin, rect.size)
		var shown: Variant = _pass_clip(control, node, rect, origin)
		if shown == null:
			continue
		var visible: Rect2 = shown as Rect2
		if not view.encloses(visible):
			problems.append("%s at %s reaches past the view %s" % [what, visible, Rect2(Vector2.ZERO, node.size)])
		if control is Label:
			texts.append([control, visible, what])
			pass_checked.x += 1
		else:
			pass_checked.y += 1
	for i: int in texts.size():
		for j: int in range(i + 1, texts.size()):
			var a: Control = texts[i][0]
			var b: Control = texts[j][0]
			if a.is_ancestor_of(b) or b.is_ancestor_of(a):
				continue
			var both: Rect2 = (texts[i][1] as Rect2).intersection(texts[j][1] as Rect2)
			if both.size.x > PASS_OVERLAP and both.size.y > PASS_OVERLAP:
				problems.append("%s %s and %s %s lie over each other" % [texts[i][2], texts[i][1], texts[j][2], texts[j][1]])
	return problems


## The opacity `control` is drawn with under `top` (its own and every ancestor's modulate, its self_modulate).
static func _pass_alpha(control: Control, top: Node) -> float:
	var alpha: float = control.self_modulate.a
	var walk: Node = control
	while walk != null:
		if walk is CanvasItem:
			alpha *= (walk as CanvasItem).modulate.a
		if walk == top:
			break
		walk = walk.get_parent()
	return alpha


## The glyph box of `label` on the screen: its text's width (the whole label for wrapped text) and its line height,
## placed by its alignment.
static func _pass_text_rect(label: Label) -> Rect2:
	var rect: Rect2 = label.get_global_rect()
	if label.autowrap_mode != TextServer.AUTOWRAP_OFF:
		return rect
	var need: Vector2 = label.get_minimum_size()
	if label.clip_text or label.text_overrun_behavior != TextServer.OVERRUN_NO_TRIMMING:
		need.x = minf(_pass_text_width(label, label.atr(label.text)), rect.size.x)
	var x: float = rect.position.x
	match label.horizontal_alignment:
		HORIZONTAL_ALIGNMENT_CENTER:
			x += (rect.size.x - need.x) * 0.5
		HORIZONTAL_ALIGNMENT_RIGHT:
			x += rect.size.x - need.x
		HORIZONTAL_ALIGNMENT_FILL:
			need.x = rect.size.x
	var y: float = rect.position.y
	match label.vertical_alignment:
		VERTICAL_ALIGNMENT_CENTER:
			y += (rect.size.y - need.y) * 0.5
		VERTICAL_ALIGNMENT_BOTTOM:
			y += rect.size.y - need.y
		VERTICAL_ALIGNMENT_FILL:
			need.y = rect.size.y
	return Rect2(Vector2(x, y), need)


## The width of `text` in `label`'s face (its settings or theme font, upper-cased where the label is).
static func _pass_text_width(label: Label, text: String) -> float:
	var font: Font = label.get_theme_font(&"font")
	var font_size: int = label.get_theme_font_size(&"font_size")
	if label.label_settings != null:
		if label.label_settings.font != null:
			font = label.label_settings.font
		font_size = label.label_settings.font_size
	var shown: String = text.to_upper() if label.uppercase else text
	return font.get_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x if font != null else 0.0


## A clipping text with less room than its words need ("" when it has the room or does not clip).
static func _pass_cut_text(label: Label, text: String) -> String:
	if label.autowrap_mode != TextServer.AUTOWRAP_OFF:
		return ""
	if not label.clip_text and label.text_overrun_behavior == TextServer.OVERRUN_NO_TRIMMING:
		return ""
	var need: float = _pass_text_width(label, text)
	if need > label.size.x + 1.0:
		return "text '%s' is cut (%d px wide for %d px)" % [text.left(24), int(label.size.x), int(ceilf(need))]
	return ""


## The part of `rect` (screen px) that the clipping ancestors of `control` up to `top` show: null when none of it.
static func _pass_clip(control: Control, top: Control, rect: Rect2, origin: Vector2) -> Variant:
	var shown: Rect2 = rect
	var walk: Node = control.get_parent()
	while walk != null and walk != top.get_parent():
		if walk is Control and (walk as Control).clip_contents:
			var clip: Rect2 = (walk as Control).get_global_rect()
			clip.position -= origin
			if not shown.intersects(clip):
				return null
			shown = shown.intersection(clip)
		walk = walk.get_parent()
	return shown


## The classic layout's Strike key of P1 (Left Ctrl since the orchestrator's G1 resolution; the tests follow the
## layout table, InputSlot, instead of naming the key).
func _p1_strike() -> Key:
	return InputSlot.default_keys(InputSlot.KeyboardLayout.CLASSIC, Defs.InputSlotKind.KEYBOARD_LEFT, Defs.ACT_ATTACK)[0]


## The join panel of a co-op front end with every seat free.
func _open_join() -> JoinScreen:
	Flow.play_mode = Defs.GameMode.COOP
	Flow.begin_party_setup()
	return await _open(&"join") as JoinScreen


## Press (and release) a physical key as the keyboard sends it; `pressed` true / false sends only that edge.
func _key(code: Key, pressed: Variant = null) -> void:
	var states: Array = [true, false] if pressed == null else [bool(pressed)]
	for state: Variant in states:
		var event: InputEventKey = InputEventKey.new()
		event.physical_keycode = code
		event.keycode = code
		event.pressed = bool(state)
		get_tree().root.push_input(event)


func _pad_button(device: int, button: JoyButton) -> void:
	for state: bool in [true, false]:
		var event: InputEventJoypadButton = InputEventJoypadButton.new()
		event.device = device
		event.button_index = button
		event.pressed = state
		get_tree().root.push_input(event)


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
