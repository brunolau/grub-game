extends TestCase
## ui module: options are applied at once and persist; bindings can be changed; glyphs follow the device;
## every text key has an English translation. 2.0 (ui-B, PLAN.md P1.12): the binding profiles of P1..P4, the
## shared-keyboard presets of DESIGN.md D.11, the Swap row, the two-player keyboard test with its NumLock check, and a
## two-player match driven only by the physical keys of the classic layout (NumLock on and off).

const ARENA: StringName = &"test_world_arena_flat"
const LEVEL_SCENE: String = "res://scenes/world/level.tscn"
## The keycode Windows reports for a numpad key while NumLock is off (the physical keycode stays the numpad key).
const NUMLOCK_OFF: Dictionary = {
	KEY_KP_8: KEY_UP, KEY_KP_4: KEY_LEFT, KEY_KP_5: KEY_CLEAR, KEY_KP_6: KEY_RIGHT, KEY_KP_0: KEY_INSERT,
	KEY_KP_PERIOD: KEY_DELETE, KEY_KP_2: KEY_DOWN,
}

var _held: Dictionary = {}  # physical key -> true


## A screen an earlier test file left behind as the current scene (a Flow scene change after a failed test, e.g. a
## GameOver over the whole view) would take the taps and keys of these tests: remove it and Flow's overlays, as
## tests/test_ui_screens.gd does after its own screens.
func before_each() -> void:
	if Flow.busy:
		return
	get_tree().paused = false
	var scene: Node = get_tree().current_scene
	if scene != null and is_instance_valid(scene):
		get_tree().current_scene = null
		scene.free()
		for layer: int in [Defs.LAYER_HUD, Defs.LAYER_TOUCH, Defs.LAYER_MENU]:
			for child: Node in Flow.get_overlay(layer).get_children():
				child.free()
		Flow.current_screen = Flow.SCREEN_BOOT
		Flow.args = {}


func after_each() -> void:
	_release_keys()
	GameInput.reset_slots()
	Sim.manual = false
	Sim.stop()
	Flow.pending_level_id = &""
	Flow.play_mode = Defs.GameMode.SINGLE
	Game.versus_match = null
	Game.new_game(Defs.Difficulty.BEGINNER)
	Game.begin_level(&"")
	Settings.reset()
	Settings.set_value(OptionsPanel.KEY_TOUCH_LAYOUT, "standard")
	Settings.save()
	_use_keyboard()


func test_options_apply_and_persist() -> void:
	# The touch section shows where touch buttons can be used (here: switched on).
	Settings.set_value("controls/touch_always", true)
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


## ui-A's join panel / lobby: the key test shows the seated keyboard players in join order (the numpad player who
## joined first is P1), each lit by his own keys, then the half nobody sits at as "Free" with the layout's keys.
func test_key_test_shows_seated_players_in_join_order() -> void:
	var panel: OptionsPanel = await _panel()
	panel.open_key_test()
	await get_tree().process_frame
	var test: UiKeyTest = panel.get_key_test()
	assert_eq(test.columns, [Vector2i(0, Defs.InputSlotKind.NONE), Vector2i(1, Defs.InputSlotKind.NONE)] \
			as Array[Vector2i], "the options page: the P1 / P2 profiles as before")
	GameInput.assign_slot(0, InputSlot.keyboard(Defs.InputSlotKind.KEYBOARD_RIGHT))
	test.set_players(PackedInt32Array([0]))
	assert_eq(test.columns, [Vector2i(0, Defs.InputSlotKind.KEYBOARD_RIGHT),
			Vector2i(-1, Defs.InputSlotKind.KEYBOARD_LEFT)] as Array[Vector2i], "P1 on the numpad, then the free half")
	assert_eq(test.get_column_tag(0), "P1")
	assert_eq(test.get_column_tag(1), tr("UI_JOIN_FREE"))
	_key(KEY_KP_ENTER, true)
	assert_true(test.is_lit(0, &"attack"), "Num Enter lights P1's Strike")
	_key(KEY_KP_ENTER, false)
	_key(KEY_SPACE, true)
	assert_true(test.is_lit(-1, &"jump"), "Space lights the free half's Jump")
	assert_false(test.is_lit(0, &"jump"))
	_key(KEY_SPACE, false)
	GameInput.assign_slot(1, InputSlot.keyboard(Defs.InputSlotKind.KEYBOARD_LEFT))
	test.set_players(PackedInt32Array([0, 1]))
	assert_eq(test.get_column_tag(1), "P2", "then the W A S D player")
	_key(KEY_SPACE, true)
	assert_true(test.is_lit(1, &"jump"), "Space lights P2's Jump")
	assert_false(test.is_lit(0, &"jump"), "... not P1's")
	_key(KEY_SPACE, false)
	_release_keys()


## Options > Co-op (DESIGN.md D.3 / D.11): "Rival score" and "Helper mode", both off by default, applied at once and
## kept in settings.cfg.
func test_coop_options_rival_score_and_helper_mode() -> void:
	var panel: OptionsPanel = await _panel()
	for key: String in [OptionsPanel.KEY_RIVAL_SCORE, OptionsPanel.KEY_HELPER_MODE]:
		var row: UiOptionRow = panel.get_row(key)
		assert_not_null(row, "a row for %s" % key)
		if row == null:
			continue
		assert_eq(row.kind, UiOptionRow.Kind.TOGGLE)
		assert_eq(row.index, 0, "off by default")
		assert_false(Settings.get_bool(key))
		row.activate()
		assert_true(Settings.get_bool(key), "switched on at once")
	assert_eq(panel.get_row(OptionsPanel.KEY_RIVAL_SCORE).caption, "UI_OPT_RIVAL_SCORE")
	assert_eq(panel.get_row(OptionsPanel.KEY_HELPER_MODE).caption, "UI_OPT_HELPER_MODE")
	panel.close()
	Settings.load_settings()
	assert_true(Settings.get_bool(OptionsPanel.KEY_RIVAL_SCORE), "kept after a reload")
	assert_true(Settings.get_bool(OptionsPanel.KEY_HELPER_MODE), "kept after a reload")
	panel = await _panel()
	assert_eq(panel.get_row(OptionsPanel.KEY_HELPER_MODE).index, 1, "a new panel shows the stored value")
	Settings.reset()
	panel._sync_rows()
	assert_eq(panel.get_row(OptionsPanel.KEY_RIVAL_SCORE).index, 0, "reset: off again")
	assert_false(Settings.get_bool(OptionsPanel.KEY_HELPER_MODE))


## On a desktop without a touch screen (and touch buttons not switched on) the touch section is left out.
func test_touch_options_only_where_touch_can_be_used() -> void:
	Settings.set_value("controls/touch_always", false)
	var panel: OptionsPanel = await _panel()
	var wanted: bool = OptionsPanel.touch_options_wanted()
	assert_eq(panel.get_row(OptionsPanel.KEY_TOUCH_LAYOUT) != null, wanted, "touch rows exactly when wanted")
	if not DisplayServer.is_touchscreen_available() and not OS.has_feature("mobile"):
		assert_null(panel.get_row("controls/touch_opacity"), "no touch rows on a desktop without a touch screen")


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


func test_lists_show_whole_rows_only() -> void:
	var panel: OptionsPanel = await _panel()
	var row_h: float = float(UiKit.row_height())
	for room: float in [360.0 - OptionsPanel.CHROME_HEIGHT, 199.0, 263.0, 512.0 - OptionsPanel.CHROME_HEIGHT]:
		var fitted: float = OptionsPanel.list_height(room)
		assert_eq(fmod(fitted, row_h), 0.0, "room %d: a whole number of rows" % room)
		assert_true(fitted <= maxf(room, OptionsPanel.LIST_HEIGHT), "room %d: fits" % room)
	panel.fit_height(360.0 - OptionsPanel.CHROME_HEIGHT)
	await get_tree().process_frame
	var scrolls: Array[Node] = panel.find_children("*", "ScrollContainer", false, false)
	assert_eq(scrolls.size(), 2, "the main list and the bindings list")
	var main: ScrollContainer = scrolls[0] as ScrollContainer
	assert_eq(fmod(main.size.y, row_h), 0.0, "the visible list is a whole number of rows: %s" % main.size.y)
	var list: VBoxContainer = main.get_child(0) as VBoxContainer
	for child: Node in list.get_children():
		var control: Control = child as Control
		if control.visible:
			assert_eq(control.size.y, row_h, "every heading and row is one row tall: %s" % control.name)
	# Scrolling of any kind (focus, wheel, drag) ends on a row boundary.
	var bar: VScrollBar = main.get_v_scroll_bar()
	assert_true(bar.max_value - bar.page > row_h, "the list scrolls at 640 x 360")
	bar.value = row_h * 1.4
	assert_eq(bar.value, row_h, "snapped down")
	bar.value = row_h * 2.6
	assert_eq(bar.value, row_h * 3.0, "snapped up")
	panel.get_row("game/locale").grab_focus()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(fmod(bar.value, row_h), 0.0, "following the focus keeps whole rows")
	assert_true(bar.value > 0.0)


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


## The bindings page edits one profile at a time: "One player" (the 1.0 profile) or P1..P4 of a party; Swap is a row
## like the others (DESIGN.md C.1: V / LB alone, Num + for P2 of the classic layout).
func test_bindings_page_has_swap_and_the_player_profiles() -> void:
	var panel: OptionsPanel = await _panel()
	assert_eq(OptionsPanel.ACTION_KEYS.get(&"swap"), "UI_ACTION_SWAP")
	assert_eq(panel.bind_profile, OptionsPanel.PROFILE_SOLO, "outside a party: the single-player buttons")
	var swap: UiOptionRow = panel.get_binding_row(&"swap")
	assert_not_null(swap, "a Swap row")
	assert_eq(panel.binding_text(&"swap", Defs.Device.KEYBOARD), "V")
	assert_eq(panel.binding_text(&"swap", Defs.Device.GAMEPAD), "LB")
	assert_false(panel.get_row(OptionsPanel.ROW_LAYOUT).visible, "no shared-keyboard preset for one player")
	panel.set_bind_profile(1)
	assert_eq(panel.get_row(OptionsPanel.ROW_PROFILE).index, 2, "the row shows P2")
	assert_true(panel.get_row(OptionsPanel.ROW_LAYOUT).visible, "P1 / P2 share a keyboard")
	assert_eq(panel.binding_text(&"swap", Defs.Device.KEYBOARD), "NUM +", "classic: P2 swaps with Num +")
	assert_eq(panel.binding_text(&"attack", Defs.Device.KEYBOARD), "NUM ENTER")
	assert_eq(panel.binding_text(&"move_up", Defs.Device.KEYBOARD), "NUM 8")
	assert_eq(panel.binding_text(&"jump", Defs.Device.GAMEPAD), "A", "the solo pad layout on every slot")
	assert_true(swap.value_text.begins_with("NUM +"), "the row shows it: %s" % swap.value_text)
	panel.set_bind_profile(0)
	assert_eq(panel.binding_text(&"attack", Defs.Device.KEYBOARD), UiGlyphs.event_text(_key_event(_p1_strike())),
			"classic: P1 strikes with the preset's key (Left Ctrl)")
	assert_ne(_p1_strike(), KEY_SHIFT, "never Shift: Windows lifts Shift while NumLock-on numpad keys are pressed")
	assert_eq(panel.binding_text(&"jump", Defs.Device.KEYBOARD), "SPACE")
	panel.set_bind_profile(2)
	assert_false(panel.get_row(OptionsPanel.ROW_LAYOUT).visible)
	assert_eq(panel.binding_text(&"jump", Defs.Device.KEYBOARD), "", "P3 has no keys: a keyboard serves two")
	assert_eq(panel.binding_text(&"jump", Defs.Device.GAMEPAD), "A")
	panel.get_row(OptionsPanel.ROW_PROFILE).step(-1)
	assert_eq(panel.bind_profile, 1, "Left on the player row goes back to P2")


## Rebinding on a party profile changes that profile only; the presets of D.11 put both halves back on their keys
## (a pad button given meanwhile stays); everything persists.
func test_party_profiles_rebind_and_take_the_shared_keyboard_presets() -> void:
	var panel: OptionsPanel = await _panel()
	var solo_jump: String = UiGlyphs.action_text(&"jump", UiGlyphs.SET_KEYBOARD)
	panel.set_bind_profile(1)
	panel.start_listening(&"jump")
	var key: InputEventKey = InputEventKey.new()
	key.physical_keycode = KEY_KP_7
	key.keycode = KEY_HOME
	key.pressed = true
	get_tree().root.push_input(key)
	assert_eq(panel.listening_action, &"")
	assert_eq(panel.binding_text(&"jump", Defs.Device.KEYBOARD), "NUM 7", "P2 jumps with Num 7 now")
	assert_eq(UiGlyphs.action_text(&"jump", UiGlyphs.SET_KEYBOARD), solo_jump, "the single-player jump is untouched")
	assert_true(Settings.has_custom_slot_bindings(1))
	assert_false(Settings.has_custom_slot_bindings(0))
	var pad: InputEventJoypadButton = InputEventJoypadButton.new()
	pad.button_index = JOY_BUTTON_RIGHT_STICK
	panel.bind_event(&"look", pad)
	assert_eq(panel.binding_text(&"look", Defs.Device.GAMEPAD), "R3", "P2 looks with R3")
	OptionsPanel.apply_keyboard_preset(InputSlot.KeyboardLayout.TWO_HANDS)
	assert_eq(str(Settings.get_value(Settings.PARTY_KEYBOARD_KEY, "")), "two_hands")
	assert_eq(panel.get_row(OptionsPanel.ROW_LAYOUT).index, InputSlot.KeyboardLayout.TWO_HANDS, "the row follows")
	assert_eq(panel.binding_text(&"jump", Defs.Device.KEYBOARD), "/", "two hands: P2 jumps with /")
	assert_eq(panel.binding_text(&"look", Defs.Device.GAMEPAD), "R3", "P2's own pad button is kept")
	panel.set_bind_profile(0)
	assert_eq(panel.binding_text(&"attack", Defs.Device.KEYBOARD), "F", "two hands: P1 strikes with F")
	assert_eq(panel.binding_text(&"jump", Defs.Device.KEYBOARD), "G")
	OptionsPanel.apply_keyboard_preset(InputSlot.KeyboardLayout.ONE_HAND)
	assert_eq(panel.binding_text(&"jump", Defs.Device.KEYBOARD), "W", "one hand: Up jumps")
	panel.get_row(OptionsPanel.ROW_LAYOUT).set_index(InputSlot.KeyboardLayout.CLASSIC, true)
	assert_eq(str(Settings.get_value(Settings.PARTY_KEYBOARD_KEY, "")), "classic", "the row applies the preset")
	panel.set_bind_profile(1)
	assert_eq(panel.binding_text(&"jump", Defs.Device.KEYBOARD), "NUM 0", "classic again: Num 0")
	panel.close()
	Settings.load_settings()
	assert_eq(str(Settings.get_value(Settings.PARTY_KEYBOARD_KEY, "")), "classic", "the preset persisted")
	var looks: Array[InputEvent] = Settings.get_slot_bindings(1, &"look", Defs.Device.GAMEPAD)
	assert_true(not looks.is_empty() and (looks[0] as InputEventJoypadButton).button_index == JOY_BUTTON_RIGHT_STICK,
			"P2's pad look persisted")
	Settings.reset_slot_bindings()


## The keyboard test (D.11): both players hold Left + Jump + Strike + Swap; every light must stay lit. Keys are read by
## physical position (the numpad with NumLock off arrives with navigation keycodes and still lights), and while the
## test shows no key presses a menu entry.
func test_key_test_lights_both_players_and_passes() -> void:
	var panel: OptionsPanel = await _panel()
	panel.open_bindings(OptionsPanel.PROFILE_SOLO)
	panel.open_key_test()
	await get_tree().process_frame
	var test: UiKeyTest = panel.get_key_test()
	assert_true(test.is_visible_in_tree(), "the test page shows")
	assert_false(test.all_lit())
	var combo: Array[Key] = [KEY_A, KEY_SPACE, _p1_strike(), KEY_E, KEY_KP_4, KEY_KP_0, KEY_KP_ENTER, KEY_KP_ADD]
	for code: Key in combo:
		# Num 4 and Num 0 arrive as NumLock off sends them (keycodes Left / Insert, physical keys of the numpad).
		_key(code, true, code != KEY_KP_4 and code != KEY_KP_0)
	assert_true(test.is_lit(0, &"move_left") and test.is_lit(0, &"attack"), "P1's lights")
	assert_true(test.is_lit(1, &"move_left"), "Num 4 lights with NumLock off too (keycode Left)")
	assert_true(test.is_lit(1, &"jump") and test.is_lit(1, &"swap"))
	assert_true(test.all_lit(), "all eight at once")
	assert_true(test.has_passed)
	assert_eq(test.get_status_text(), tr("UI_KEYTEST_PASSED"))
	assert_true(test.is_visible_in_tree(), "Num Enter and Space pressed no menu entry")
	_key(_p1_strike(), false)
	assert_false(test.is_lit(0, &"attack"))
	assert_true(test.has_passed, "a pass is kept")
	for i: int in 3:
		await get_tree().process_frame
	_key(KEY_KP_8, true, false)
	assert_true(test.is_lit(1, &"move_up"), "the small lights: Num 8 is P2's up")
	_release_keys()
	assert_false(test.numlock_warning, "no Windows Shift quirk seen")
	panel.go_back()
	assert_false(test.is_visible_in_tree(), "back leaves the test")


## Windows with NumLock ON lifts Shift while a numpad key is pressed with Shift held (and presses it again after):
## that drops the action of a player who bound Shift (the classic preset no longer does: P1 strikes with Left Ctrl).
## The test spots the pattern and asks for NumLock off.
func test_key_test_spots_the_numlock_shift_quirk() -> void:
	var shift: InputEventKey = InputEventKey.new()
	shift.physical_keycode = KEY_SHIFT
	Settings.set_slot_binding(0, &"attack", shift, 0)
	var panel: OptionsPanel = await _panel()
	panel.open_key_test()
	await get_tree().process_frame
	var test: UiKeyTest = panel.get_key_test()
	test.start()
	_key(KEY_SHIFT, true)
	await get_tree().process_frame
	assert_true(test.is_lit(0, &"attack"))
	# What Windows sends when P2 presses Num 8 while P1 holds Shift and NumLock is on: Shift up, Num 8 (as Up), ...
	_key(KEY_SHIFT, false)
	_key(KEY_KP_8, true, false)
	assert_true(test.numlock_warning)
	assert_eq(test.get_status_text(), tr("UI_KEYTEST_NUMLOCK"))
	assert_false(test.is_lit(0, &"attack"), "P1's strike dropped, as on the real keyboard")
	_key(KEY_KP_8, false, false)
	_key(KEY_SHIFT, true)
	_key(KEY_SHIFT, false)
	test.start()
	assert_false(test.numlock_warning, "a new test starts clean")
	_key(KEY_KP_8, true, false)
	_key(KEY_KP_8, false, false)
	await get_tree().process_frame
	_key(KEY_SHIFT, false)
	for i: int in 3:
		await get_tree().process_frame
	_key(KEY_KP_5, true)
	_key(KEY_KP_5, false)
	assert_false(test.numlock_warning, "an ordinary Shift release some frames earlier is no quirk")
	Settings.reset_slot_bindings(0)
	test.start()
	_key(KEY_SHIFT, true)
	_key(KEY_SHIFT, false)
	_key(KEY_KP_8, true, false)
	_key(KEY_KP_8, false, false)
	assert_false(test.numlock_warning, "nobody has Shift on a key: nothing to warn about")


## DESIGN.md D.11 / E.9: a two-player Grub Stack match on world-B's flat arena, driven only by the physical keys of the
## classic preset as the options set it up - P1 W A S D + Space + Left Ctrl, P2 the numpad with NumLock on and off -
## while the versus HUD shows the referee's numbers and the round result.
func test_a_two_player_match_from_the_classic_keys() -> void:
	OptionsPanel.apply_keyboard_preset(InputSlot.KeyboardLayout.TWO_HANDS)
	OptionsPanel.apply_keyboard_preset(InputSlot.KeyboardLayout.CLASSIC)
	if not Levels.has_level(ARENA) or not ResourceLoader.exists(LEVEL_SCENE):
		fail("the flat arena of world-B and the level scene are needed")
		return
	Game.versus_match = null
	Game.start_run(Defs.Difficulty.BEGINNER, Defs.GameMode.VERSUS, 2)
	GameInput.assign_slot(0, InputSlot.keyboard(Defs.InputSlotKind.KEYBOARD_LEFT))
	GameInput.assign_slot(1, InputSlot.keyboard(Defs.InputSlotKind.KEYBOARD_RIGHT))
	# Input keeps the pressed state of an action by name: a key another test held while these actions were removed
	# and built again would read as held here. Start from released actions, as a fresh game does.
	for slot: int in 2:
		for action: StringName in Defs.GAME_ACTIONS:
			if InputMap.has_action(GameInput.slot_action(slot, action)):
				Input.action_release(GameInput.slot_action(slot, action))
	Sim.manual = true
	Flow.pending_level_id = ARENA
	var level: LevelBase = (load(LEVEL_SCENE) as PackedScene).instantiate() as LevelBase
	add_node(level)
	await get_tree().process_frame
	# The authentic view, whatever size the root viewport was left at by earlier tests.
	if level.has_method(&"set_view_size"):
		level.call(&"set_view_size", Vector2i(Tuning.VIEW_W, Tuning.VIEW_H) * Tuning.ART_SCALE)
	var referee: Object = level.party_driver if level.party_driver != null else VersusArena.setup(level)
	assert_not_null(referee, "the arena has its referee")
	assert_eq(level.hero_count(), 2, "two heroes")
	if referee == null or level.hero_count() != 2:
		return
	var hud: Hud = (load(Flow.HUD_SCENE) as PackedScene).instantiate() as Hud
	add_node(hud)
	await get_tree().process_frame
	var versus: HudVersus = hud.get_versus()
	assert_not_null(versus, "the versus HUD")
	referee.call(&"start_round_now")
	var p1: PlayerBase = level.get_hero(0)
	var p2: PlayerBase = level.get_hero(1)
	_drive({}, VersusTuning.SPAWN_SHIELD_TICKS + 2)
	for numlock: bool in [true, false]:
		var state: String = "NumLock %s" % ("on" if numlock else "off")
		var x1: int = p1.sim_pos.x
		var x2: int = p2.sim_pos.x
		_drive({KEY_D: true}, 8, numlock)
		assert_true(p1.sim_pos.x > x1, "%s: D walks P1 right" % state)
		assert_eq(p2.sim_pos.x, x2, "%s: ... and not P2" % state)
		_drive({}, 24, numlock)
		x1 = p1.sim_pos.x
		_drive({KEY_KP_4: true}, 8, numlock)
		assert_true(p2.sim_pos.x < x2, "%s: Num 4 walks P2 left" % state)
		assert_eq(p1.sim_pos.x, x1, "%s: ... and not P1" % state)
		var y2: int = p2.sim_pos.y
		_drive({KEY_KP_0: true}, 3, numlock)
		assert_true(p2.sim_pos.y < y2, "%s: Num 0 jumps P2" % state)
		_drive({}, 40, numlock)
		_drive({KEY_KP_ENTER: true}, 1, numlock)
		assert_eq(GameInput.get_flags(1) & Defs.IN_FIRE, Defs.IN_FIRE, "%s: Num Enter strikes" % state)
		assert_eq(GameInput.get_flags(0), 0, "%s: P1 reads nothing of it" % state)
		_drive({}, 16, numlock)
		_drive({KEY_KP_ADD: true, KEY_KP_PERIOD: true}, 1, numlock)
		assert_eq(GameInput.get_flags(1) & (Defs.IN_SWAP | Defs.IN_LOOK), Defs.IN_SWAP | Defs.IN_LOOK,
				"%s: Num + swaps, Num . looks" % state)
		_drive({}, 16, numlock)
	# P1 walks up behind P2 and clubs the food off his head; the HUD shows the referee's numbers.
	p2.teleport(Vector2i(p1.sim_pos.x + 36, p1.sim_pos.y))
	p2.facing = 1
	referee.call(&"add_food", p2, 10)
	_drive({}, 2)
	versus.refresh()
	assert_eq(versus.get_panel(1).get_stack_text(), "10", "P2's panel shows his stack")
	_drive({KEY_D: true}, 2)
	_drive({_p1_strike(): true}, 9)
	_drive({}, 30)
	var left: int = int(referee.call(&"stack_of", 1))
	assert_true(left < 10, "P1's strike key: his club knocked food off P2's head (%d left)" % left)
	versus.refresh()
	assert_eq(versus.get_panel(1).get_stack_text(), str(left), "the HUD follows the stack")
	referee.call(&"add_food", p1, 20)
	referee.call(&"end_round", false)
	_drive({}, 2)
	assert_true(versus.banner_text.contains("P1"), "the gong: P1 wins the round (%s)" % versus.banner_text)
	_release_keys()
	assert_false(GameInput.is_scripted(), "no script drove a hero")

## P1's strike key of the classic shared-keyboard preset (InputSlot's table, owned by core-A).
func _p1_strike() -> Key:
	var keys: Array = InputSlot.default_keys(InputSlot.KeyboardLayout.CLASSIC, InputSlot.default_half(0), &"attack")
	return keys[0] if not keys.is_empty() else KEY_NONE


func _key_event(physical: Key) -> InputEventKey:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = physical
	return event


## An options panel on a canvas layer of its own above everything else: a screen an earlier test file left in the root
## (a Flow scene change after a failed test, e.g. a GameOver screen over the whole view) never takes its taps.
func _panel() -> OptionsPanel:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 120
	add_node(layer)
	var panel: OptionsPanel = OptionsPanel.new()
	layer.add_child(panel)
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


## Press or release a physical key through Input, as the OS would deliver it; `numlock_on` false gives a numpad key
## the navigation keycode Windows reports with NumLock off.
func _key(physical: Key, pressed: bool, numlock_on: bool = true) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = physical
	event.keycode = physical if numlock_on else NUMLOCK_OFF.get(physical, physical)
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	if pressed:
		_held[physical] = numlock_on
	else:
		_held.erase(physical)


## Hold exactly the keys of `keys` (physical key -> true) for `ticks` ticks of the simulation.
func _drive(keys: Dictionary, ticks: int, numlock_on: bool = true) -> void:
	for physical: Key in _held.keys():
		if not keys.has(physical):
			_key(physical, false, numlock_on)
	for physical: Key in keys:
		if not _held.has(physical):
			_key(physical, true, numlock_on)
	for i: int in ticks:
		Sim.step(1)


func _release_keys() -> void:
	for physical: Key in _held.keys():
		_key(physical, false, bool(_held[physical]))
