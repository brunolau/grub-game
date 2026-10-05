extends TestCase
## ui module: the three gameplay overlays (HUD, touch controls, pause menu) react to Game / Events / input.


func before_each() -> void:
	Game.new_game(Defs.Difficulty.BEGINNER)
	Game.begin_level(&"test_example")


func after_each() -> void:
	Settings.set_value("controls/touch_always", false)
	GameInput.clear_touch()
	GameInput.sample()
	GameInput.sample()


func test_hud_reflects_game_signals() -> void:
	var hud: Hud = await _overlay(Flow.HUD_SCENE) as Hud
	assert_true(hud.is_in_group(Defs.GROUP_HUD))
	assert_eq(hud.get_score_text(), "0000000")
	assert_eq(hud.get_lives_text(), "x%d" % Tuning.LIVES_START)
	Game.add_score(12340)
	assert_eq(hud.get_score_text(), "0012340")
	Game.add_lives(3)
	assert_eq(hud.get_lives_text(), "x%d" % (Tuning.LIVES_START + 3))
	assert_eq(hud.shown_hearts, Tuning.ENERGY_START)
	Game.lose_heart()
	assert_eq(hud.shown_hearts, Tuning.ENERGY_START - 1, "a lost heart is shown empty")
	Game.add_bones(2)
	assert_eq(hud.shown_bones, 2, "the bone fraction is shown")
	Game.collect_letter(0)
	Game.collect_letter(3)
	assert_eq(hud.shown_letters, 0b01001, "collected letters are lit")


func test_hud_shows_the_time_limit() -> void:
	var hud: Hud = await _overlay(Flow.HUD_SCENE) as Hud
	assert_false(hud.is_time_visible(), "no counter without a level time limit")
	Events.time_left_changed.emit(42)
	assert_true(hud.is_time_visible())
	assert_eq(hud.shown_time, 42)
	assert_eq(hud.get_time_text(), tr("UI_HUD_TIME").format({"seconds": 42}))
	assert_true(hud.get_time_text().contains("42"))
	Events.time_left_changed.emit(-1)
	assert_false(hud.is_time_visible(), "a level without a limit hides it")


func test_hud_blinks_the_completed_word() -> void:
	var hud: Hud = await _overlay(Flow.HUD_SCENE) as Hud
	for i: int in Tuning.LETTER_COUNT - 1:
		Game.collect_letter(i)
	Game.collect_letter(Tuning.LETTER_COUNT - 1)
	assert_eq(Game.letters, 0, "the word was completed and cleared")
	assert_eq(hud.shown_letters, 0b11111, "the HUD shows the whole word while it blinks")
	await get_tree().create_timer(Tuning.ticks_to_seconds(Tuning.LETTERS_BLINK_TICKS) + 0.2).timeout
	assert_eq(hud.shown_letters, 0, "after the blink the empty word is shown")


func test_hud_boss_bar_follows_the_boss() -> void:
	var hud: Hud = await _overlay(Flow.HUD_SCENE) as Hud
	assert_false(hud.is_boss_bar_visible(), "no boss bar outside boss fights")
	Events.boss_started.emit(null)
	assert_true(hud.is_boss_bar_visible())
	assert_eq(hud.boss_max_pips, Tuning.BOSS_BAR_MAX_PIPS)
	Events.boss_energy_changed.emit(null, 3, 6)
	assert_eq(hud.boss_pips, 3)
	assert_eq(hud.boss_max_pips, 6)
	Events.boss_defeated.emit(null)
	assert_false(hud.is_boss_bar_visible())
	Events.boss_energy_changed.emit(null, 2, 8)
	assert_true(hud.is_boss_bar_visible(), "an energy update shows the bar again")
	Events.level_respawned.emit()
	assert_false(hud.is_boss_bar_visible(), "a respawn resets the fight")


func test_hud_shows_level_hints_on_a_panel() -> void:
	var hud: Hud = await _overlay(Flow.HUD_SCENE) as Hud
	assert_false(hud.is_hint_visible(), "no hint panel without a hint")
	var first: Node = Node.new()
	var second: Node = Node.new()
	add_node(first)
	add_node(second)
	Events.message_requested.emit(first, "ZONE_DEMO")
	assert_eq(hud.get_hint_text(), tr("ZONE_DEMO"), "the hint is a translation key")
	await get_tree().create_timer(Hud.HINT_FADE_SECONDS + 0.1).timeout
	assert_true(hud.is_hint_visible())
	assert_eq(hud.get_hint_shown_text(), tr("ZONE_DEMO"))
	Events.message_requested.emit(second, "Plain text works too")
	assert_eq(hud.get_hint_text(), "Plain text works too", "the newest hint wins")
	Events.message_requested.emit(first, "")
	assert_eq(hud.get_hint_text(), "Plain text works too", "withdrawing an older hint keeps the newer one")
	Events.message_requested.emit(first, "ZONE_DEMO")
	Events.message_requested.emit(first, "")
	assert_eq(hud.get_hint_text(), "Plain text works too", "back to the hint still asked for")
	second.free()
	assert_eq(hud.get_hint_text(), "", "the hint of a freed source is forgotten")
	await get_tree().create_timer(Hud.HINT_FADE_SECONDS + 0.1).timeout
	assert_false(hud.is_hint_visible(), "faded out")
	# The panel stays inside the view at the narrowest supported width and wraps long text.
	Events.message_requested.emit(first, "Club the ground - bonuses hide everywhere! Every single one of them.")
	await get_tree().create_timer(Hud.HINT_FADE_SECONDS + 0.1).timeout
	var label_rect: Rect2 = _hint_label_rect(hud)
	var view: Rect2 = hud.get_viewport_rect()
	assert_true(view.encloses(label_rect), "the hint text is inside the view: %s in %s" % [label_rect, view])
	assert_true(label_rect.size.x <= Hud.HINT_MAX_TEXT_W + 0.5, "long hints wrap")
	assert_true(label_rect.position.y >= Hud.HINT_TOP, "the hint sits under the HUD row")
	first.free()


func _hint_label_rect(hud: Hud) -> Rect2:
	var found: Array[Label] = []
	for node: Node in hud.find_children("*", "Label", true, false):
		var label: Label = node as Label
		if label.text == hud.get_hint_shown_text():
			found.append(label)
	assert_eq(found.size(), 1, "one hint label")
	return found[0].get_global_rect() if not found.is_empty() else Rect2()


func test_touch_controls_feed_game_input_with_multi_touch() -> void:
	var touch: TouchControls = await _overlay(Flow.TOUCH_SCENE) as TouchControls
	assert_true(touch.is_in_group(Defs.GROUP_TOUCH))
	Settings.set_value("controls/touch_always", true)
	assert_true(touch.visible, "the setting shows the overlay without a touch screen")
	var left: Vector2 = touch.get_button_rect(Defs.ACT_LEFT).get_center()
	var jump: Vector2 = touch.get_button_rect(Defs.ACT_JUMP).get_center()
	_touch(0, left, true)
	_touch(1, jump, true)
	assert_true(touch.is_button_held(Defs.ACT_LEFT))
	assert_true(touch.is_button_held(Defs.ACT_JUMP), "two fingers at once")
	var flags: int = GameInput.sample()
	assert_eq(flags & (Defs.IN_LEFT | Defs.IN_UP), Defs.IN_LEFT | Defs.IN_UP)
	_drag(0, touch.get_button_rect(Defs.ACT_RIGHT).get_center())
	assert_false(touch.is_button_held(Defs.ACT_LEFT), "sliding a finger releases the old button")
	assert_true(touch.is_button_held(Defs.ACT_RIGHT), "...and presses its neighbour")
	flags = GameInput.sample()
	assert_eq(flags & (Defs.IN_LEFT | Defs.IN_RIGHT), Defs.IN_RIGHT)
	_touch(0, touch.get_button_rect(Defs.ACT_RIGHT).get_center(), false)
	_touch(1, jump, false)
	assert_false(touch.is_button_held(Defs.ACT_RIGHT))
	assert_false(touch.is_button_held(Defs.ACT_JUMP))
	GameInput.sample()
	assert_eq(GameInput.sample() & (Defs.IN_RIGHT | Defs.IN_UP), 0, "released buttons stop feeding the game")


func test_touch_controls_follow_layout_and_pause() -> void:
	var touch: TouchControls = await _overlay(Flow.TOUCH_SCENE) as TouchControls
	Settings.set_value("controls/touch_always", true)
	var view: Vector2 = touch.size
	assert_true(touch.get_button_rect(Defs.ACT_LEFT).position.x < view.x * 0.5, "d-pad on the left")
	assert_true(touch.get_button_rect(Defs.ACT_JUMP).position.x > view.x * 0.5, "jump on the right")
	for action: StringName in [Defs.ACT_LEFT, Defs.ACT_JUMP, Defs.ACT_PAUSE]:
		assert_true(Rect2(Vector2.ZERO, view).encloses(touch.get_button_rect(action)), "inside the view")
		assert_true(touch.get_button_rect(action).size.x >= float(UiKit.TOUCH_TARGET), "touch target size")
	Settings.set_value(OptionsPanel.KEY_TOUCH_LAYOUT, "swapped")
	assert_true(touch.get_button_rect(Defs.ACT_LEFT).position.x > view.x * 0.5, "mirrored layout")
	Settings.set_value(OptionsPanel.KEY_TOUCH_LAYOUT, "standard")
	Settings.set_value("controls/touch_opacity", 0.4)
	assert_almost_eq(touch.modulate.a, 0.4, 0.001)
	Settings.set_value("controls/touch_opacity", Settings.DEFAULTS["controls/touch_opacity"])
	_touch(0, touch.get_button_rect(Defs.ACT_LEFT).get_center(), true)
	Events.pause_changed.emit(true)
	assert_false(touch.visible, "hidden while the pause menu is open")
	assert_false(touch.is_button_held(Defs.ACT_LEFT), "pausing lifts every finger")
	Events.pause_changed.emit(false)
	assert_true(touch.visible)


func test_pause_menu_shows_and_resumes() -> void:
	var menu: PauseMenu = await _overlay(Flow.PAUSE_SCENE) as PauseMenu
	assert_false(menu.visible, "hidden until the game pauses")
	Events.pause_changed.emit(true)
	assert_true(menu.visible)
	assert_eq(menu.page, PauseMenu.Page.MAIN)
	menu.open_options()
	assert_eq(menu.page, PauseMenu.Page.OPTIONS)
	_press(&"ui_cancel")
	assert_eq(menu.page, PauseMenu.Page.MAIN, "back leaves the options page")
	assert_true(menu.visible)
	_press(&"ui_cancel")
	assert_false(menu.visible, "back on the main page resumes")


func test_pause_menu_resume_unpauses_the_level() -> void:
	var menu: PauseMenu = await _overlay(Flow.PAUSE_SCENE) as PauseMenu
	Flow.current_screen = Flow.SCREEN_LEVEL
	Flow.set_paused(true)
	assert_true(menu.visible, "Flow's pause opens the menu")
	_press(&"ui_accept")
	assert_false(Flow.is_paused(), "the focused 'resume' entry unpauses")
	assert_false(menu.visible)
	Flow.current_screen = Flow.SCREEN_BOOT


func test_pause_menu_gamepad_start_confirms_the_focused_entry() -> void:
	var menu: PauseMenu = await _overlay(Flow.PAUSE_SCENE) as PauseMenu
	Flow.current_screen = Flow.SCREEN_LEVEL
	Flow.set_paused(true)
	assert_true(menu.visible)
	menu._options_button.grab_focus()
	_pad(JOY_BUTTON_START)
	assert_eq(menu.page, PauseMenu.Page.OPTIONS, "Start confirmed 'options' instead of resuming")
	assert_true(Flow.is_paused(), "the game stays paused")
	_press(&"ui_cancel")
	assert_eq(menu.page, PauseMenu.Page.MAIN)
	menu._resume.grab_focus()
	_pad(JOY_BUTTON_START)
	assert_false(Flow.is_paused(), "Start on 'resume' resumes")
	assert_false(menu.visible)
	_pad(JOY_BUTTON_START)
	assert_true(Flow.is_paused(), "in play Start pauses")
	Flow.set_paused(false)
	Flow.current_screen = Flow.SCREEN_BOOT


func test_pause_menu_give_up_needs_a_hero() -> void:
	var menu: PauseMenu = await _overlay(Flow.PAUSE_SCENE) as PauseMenu
	Events.pause_changed.emit(true)
	menu.restart_from_checkpoint()
	assert_true(menu.visible, "without a running level nothing happens")
	Events.pause_changed.emit(false)
	assert_false(menu.visible)


func _overlay(path: String) -> Control:
	var node: Control = (load(path) as PackedScene).instantiate() as Control
	add_node(node)
	await get_tree().process_frame
	return node


func _press(action: StringName) -> void:
	for pressed: bool in [true, false]:
		var event: InputEventAction = InputEventAction.new()
		event.action = action
		event.pressed = pressed
		get_tree().root.push_input(event)


func _pad(button: JoyButton) -> void:
	for pressed: bool in [true, false]:
		var event: InputEventJoypadButton = InputEventJoypadButton.new()
		event.button_index = button
		event.pressed = pressed
		get_tree().root.push_input(event)


func _touch(finger: int, pos: Vector2, pressed: bool) -> void:
	var event: InputEventScreenTouch = InputEventScreenTouch.new()
	event.index = finger
	event.position = pos
	event.pressed = pressed
	get_tree().root.push_input(event)


func _drag(finger: int, pos: Vector2) -> void:
	var event: InputEventScreenDrag = InputEventScreenDrag.new()
	event.index = finger
	event.position = pos
	get_tree().root.push_input(event)
