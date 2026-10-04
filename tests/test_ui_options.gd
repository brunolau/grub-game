extends TestCase
## ui module: options are applied at once and persist; bindings can be changed; glyphs follow the device;
## every text key has an English translation.


func after_each() -> void:
	Settings.reset()
	Settings.set_value(OptionsPanel.KEY_TOUCH_LAYOUT, "standard")
	Settings.save()
	_use_keyboard()


func test_options_apply_and_persist() -> void:
	var panel: OptionsPanel = await _panel()
	var music: UiOptionRow = panel.get_row("audio/music")
	assert_not_null(music, "music volume row")
	var before: float = Settings.get_float("audio/music")
	music.grab_focus()
	_press(&"ui_left")
	assert_almost_eq(Settings.get_float("audio/music"), before - 0.1, 0.001, "Left lowers the volume at once")
	var shake: UiOptionRow = panel.get_row("video/screen_shake")
	shake.grab_focus()
	_press(&"ui_accept")
	assert_false(Settings.get_bool("video/screen_shake"), "the confirm button flips a switch")
	var layout: UiOptionRow = panel.get_row(OptionsPanel.KEY_TOUCH_LAYOUT)
	layout.step(1)
	assert_eq(str(Settings.get_value(OptionsPanel.KEY_TOUCH_LAYOUT, "")), "swapped")
	panel.close()
	assert_true(FileAccess.file_exists(Settings.storage_dir + Settings.FILE_NAME), "closing writes settings.cfg")
	Settings.load_settings()
	assert_almost_eq(Settings.get_float("audio/music"), before - 0.1, 0.001, "the volume survived a reload")
	assert_false(Settings.get_bool("video/screen_shake"), "the switch survived a reload")
	assert_eq(str(Settings.get_value(OptionsPanel.KEY_TOUCH_LAYOUT, "")), "swapped")


func test_rows_work_by_tap() -> void:
	var panel: OptionsPanel = await _panel()
	var vsync: UiOptionRow = panel.get_row("video/vsync")
	var before: bool = Settings.get_bool("video/vsync")
	var center: Vector2 = vsync.get_global_rect().get_center()
	_tap(center)
	assert_eq(Settings.get_bool("video/vsync"), not before, "a tap flips a switch")
	_click(center, true)
	_click(center + Vector2(0.0, 40.0), false)
	assert_eq(Settings.get_bool("video/vsync"), not before, "a drag (scroll gesture) is not a tap")


func test_rebinding_swaps_and_persists() -> void:
	var panel: OptionsPanel = await _panel()
	var x_key: InputEventKey = InputEventKey.new()
	x_key.physical_keycode = KEY_X
	x_key.pressed = true
	var old_jump: String = UiGlyphs.action_text(&"jump", UiGlyphs.SET_KEYBOARD)
	panel.start_listening(&"jump")
	assert_eq(panel.listening_action, &"jump")
	get_tree().root.push_input(x_key)
	assert_eq(panel.listening_action, &"", "the next key was taken")
	assert_eq(UiGlyphs.action_text(&"jump", UiGlyphs.SET_KEYBOARD), "X", "jump is now on X")
	var attack_texts: PackedStringArray = PackedStringArray()
	for event: InputEvent in InputMap.action_get_events(&"attack"):
		if event is InputEventKey:
			attack_texts.append(UiGlyphs.event_text(event))
	assert_false(attack_texts.has("X"), "attack lost X")
	assert_true(attack_texts.has(old_jump), "...and got jump's old key instead")
	var pad: InputEventJoypadButton = InputEventJoypadButton.new()
	pad.button_index = JOY_BUTTON_Y
	panel.bind_event(&"jump", pad)
	assert_eq(UiGlyphs.action_text(&"jump", UiGlyphs.SET_GAMEPAD), "Y")
	assert_eq(UiGlyphs.action_text(&"jump", UiGlyphs.SET_KEYBOARD), "X", "the keyboard binding stays")
	panel.close()
	Settings.reset_bindings()
	assert_ne(UiGlyphs.action_text(&"jump", UiGlyphs.SET_KEYBOARD), "X")
	Settings.load_settings()
	assert_eq(UiGlyphs.action_text(&"jump", UiGlyphs.SET_KEYBOARD), "X", "bindings survive a reload")
	assert_eq(UiGlyphs.action_text(&"jump", UiGlyphs.SET_GAMEPAD), "Y")


func test_escape_cancels_listening_instead_of_binding() -> void:
	var panel: OptionsPanel = await _panel()
	var left_before: String = UiGlyphs.action_text(&"move_left", UiGlyphs.SET_KEYBOARD)
	var pause_before: String = UiGlyphs.action_text(&"pause", UiGlyphs.SET_KEYBOARD)
	panel.start_listening(&"move_left")
	var escape: InputEventKey = InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.physical_keycode = KEY_ESCAPE
	escape.pressed = true
	get_tree().root.push_input(escape)
	assert_eq(panel.listening_action, &"", "Escape, shown as 'back', ends the wait")
	assert_eq(UiGlyphs.action_text(&"move_left", UiGlyphs.SET_KEYBOARD), left_before, "left keeps its key")
	assert_eq(UiGlyphs.action_text(&"pause", UiGlyphs.SET_KEYBOARD), pause_before, "pause keeps Escape")
	assert_false(Settings.has_custom_bindings(), "nothing was rebound")


func test_listening_times_out() -> void:
	var panel: OptionsPanel = await _panel()
	panel.start_listening(&"look")
	await get_tree().create_timer(OptionsPanel.LISTEN_SECONDS + 0.3).timeout
	assert_eq(panel.listening_action, &"", "listening ends by itself")


func test_glyphs_follow_the_device() -> void:
	assert_eq(UiGlyphs.action_text(&"ui_accept", UiGlyphs.SET_KEYBOARD), "ENTER")
	assert_eq(UiGlyphs.action_text(&"ui_accept", UiGlyphs.SET_GAMEPAD), "A")
	assert_eq(UiGlyphs.action_text(&"ui_accept", UiGlyphs.SET_TOUCH), "")
	var prompts: UiPrompts = UiPrompts.new()
	prompts.add_hint(&"ui_accept", "UI_HINT_SELECT")
	prompts.add_hint(&"ui_cancel", "UI_HINT_BACK", func() -> void: pass)
	add_node(prompts)
	await get_tree().process_frame
	_use_keyboard()
	assert_eq(prompts.get_glyph_text(0), "ENTER")
	var button: InputEventJoypadButton = InputEventJoypadButton.new()
	button.button_index = JOY_BUTTON_LEFT_STICK
	button.pressed = true
	get_tree().root.push_input(button)
	assert_eq(GameInput.device, Defs.Device.GAMEPAD)
	assert_eq(prompts.get_glyph_text(0), "A", "a gamepad press switches the glyphs")
	assert_eq(prompts.get_glyph_text(1), "B")
	var finger: InputEventScreenTouch = InputEventScreenTouch.new()
	finger.position = Vector2(-50.0, -50.0)
	finger.pressed = true
	get_tree().root.push_input(finger)
	assert_eq(GameInput.device, Defs.Device.TOUCH)
	await get_tree().process_frame
	assert_eq(prompts.get_child_count(), 1, "touch keeps only the tappable hints")


func test_every_text_key_has_an_english_text() -> void:
	UiKit.ensure_locale()
	assert_true(UiKit.available_locales().has("en"), "the English catalogue is loaded")
	var keys: Dictionary = {}
	var pattern: RegEx = RegEx.create_from_string("\"(UI_[A-Z0-9_]*[A-Z0-9])\"")
	var dir: DirAccess = DirAccess.open("res://scripts/ui")
	for file_name: String in dir.get_files():
		if file_name.get_extension() != "gd":
			continue
		for found: RegExMatch in pattern.search_all(FileAccess.get_file_as_string("res://scripts/ui/" + file_name)):
			keys[found.get_string(1)] = file_name
	for heading: String in ["UI_CREDITS_ART", "UI_CREDITS_MUSIC", "UI_CREDITS_SOUND"]:
		keys[heading] = "credits.gd"
	assert_true(keys.size() > 50, "keys found in the ui scripts")
	var previous: String = TranslationServer.get_locale()
	TranslationServer.set_locale("en")
	for key: String in keys:
		assert_ne(TranslationServer.translate(key), StringName(key), "%s (%s) is translated" % [key, keys[key]])
	TranslationServer.set_locale(previous)


func _panel() -> OptionsPanel:
	var panel: OptionsPanel = OptionsPanel.new()
	add_node(panel)
	await get_tree().process_frame
	return panel


func _press(action: StringName) -> void:
	for pressed: bool in [true, false]:
		var event: InputEventAction = InputEventAction.new()
		event.action = action
		event.pressed = pressed
		get_tree().root.push_input(event)


func _tap(pos: Vector2) -> void:
	_click(pos, true)
	_click(pos, false)


func _click(pos: Vector2, pressed: bool) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = pos
	event.global_position = pos
	event.pressed = pressed
	get_tree().root.push_input(event)


func _use_keyboard() -> void:
	var key: InputEventKey = InputEventKey.new()
	key.keycode = KEY_SHIFT
	key.pressed = false
	get_tree().root.push_input(key)
