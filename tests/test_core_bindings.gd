extends TestCase
## Settings: key / pad bindings - the rebind API of the options screen, persistence, robustness.


func before_each() -> void:
	Settings.reset()


func after_each() -> void:
	Settings.reset()
	Settings.save()


func _key(physical: Key, pressed: bool = true) -> InputEventKey:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = physical
	event.pressed = pressed
	return event


func _pad_button(index: JoyButton) -> InputEventJoypadButton:
	var event: InputEventJoypadButton = InputEventJoypadButton.new()
	event.button_index = index
	event.pressed = true
	return event


func _pad_axis(axis: JoyAxis, value: float) -> InputEventJoypadMotion:
	var event: InputEventJoypadMotion = InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = value
	return event


func _tokens(action: StringName, device: int = -1) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for event: InputEvent in Settings.get_bindings(action, device):
		result.append(Settings.encode_event(event))
	return result


func test_tokens_round_trip_and_reject_garbage() -> void:
	var samples: Array[InputEvent] = [_key(KEY_Z), _pad_button(JOY_BUTTON_START), _pad_axis(JOY_AXIS_LEFT_Y, -0.8)]
	var expected: PackedStringArray = ["key:90", "joy_button:6", "joy_axis:1:-1"]
	for i: int in samples.size():
		var token: String = Settings.encode_event(samples[i])
		assert_eq(token, expected[i])
		assert_eq(Settings.encode_event(Settings.decode_event(token)), token, "token %s survives a round trip" % token)
	for bad: String in ["", "key", "key:", "key:0", "key:abc", "joy_button:-1", "joy_button:999", "joy_axis:1:0",
			"joy_axis:1", "joy_axis:99:1", "mouse:1", "key:90:1"]:
		assert_null(Settings.decode_event(bad), "'%s' is not a binding" % bad)
	var mouse: InputEventMouseButton = InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	assert_eq(Settings.encode_event(mouse), "")
	assert_null(Settings.normalize_event(mouse))


func test_normal_form_drops_modifiers_device_and_state() -> void:
	var key: InputEventKey = _key(KEY_X)
	key.ctrl_pressed = true
	key.device = 3
	key.keycode = KEY_Y
	var normal: InputEventKey = Settings.normalize_event(key)
	assert_eq(normal.physical_keycode, KEY_X, "keys are bound by physical position")
	assert_false(normal.ctrl_pressed)
	assert_false(normal.pressed)
	assert_eq(normal.device, -1, "a binding works on every device")
	var logical_only: InputEventKey = InputEventKey.new()
	logical_only.keycode = KEY_Q
	assert_eq(Settings.encode_event(logical_only), "key:%d" % KEY_Q)
	var axis: InputEventJoypadMotion = Settings.normalize_event(_pad_axis(JOY_AXIS_RIGHT_X, 0.62))
	assert_eq(axis.axis_value, 1.0, "axes are stored as a direction")


func test_what_can_be_captured() -> void:
	assert_true(Settings.is_bindable(_key(KEY_A)))
	assert_false(Settings.is_bindable(_key(KEY_A, false)), "releases are not captured")
	var echo: InputEventKey = _key(KEY_A)
	echo.echo = true
	assert_false(Settings.is_bindable(echo), "key repeats are not captured")
	assert_true(Settings.is_bindable(_pad_button(JOY_BUTTON_A)))
	assert_false(Settings.is_bindable(_pad_axis(JOY_AXIS_LEFT_X, 0.3)), "a resting stick is not captured")
	assert_true(Settings.is_bindable(_pad_axis(JOY_AXIS_TRIGGER_RIGHT, 0.9)))
	var touch: InputEventScreenTouch = InputEventScreenTouch.new()
	touch.pressed = true
	assert_false(Settings.is_bindable(touch))
	assert_eq(Settings.event_device(_key(KEY_A)), Defs.Device.KEYBOARD)
	assert_eq(Settings.event_device(_pad_axis(JOY_AXIS_LEFT_X, 1.0)), Defs.Device.GAMEPAD)
	assert_eq(Settings.event_device(touch), -1)


func test_labels_for_menus() -> void:
	assert_ne(Settings.event_label(_key(KEY_Z)), "")
	assert_eq(Settings.event_label(_pad_button(JOY_BUTTON_A)), "Pad A")
	assert_eq(Settings.event_label(_pad_axis(JOY_AXIS_LEFT_Y, -1.0)), "Left Stick Up")
	assert_eq(Settings.event_label(_pad_axis(JOY_AXIS_LEFT_X, 1.0)), "Left Stick Right")
	assert_eq(Settings.event_label(InputEventMouseMotion.new()), "")


func test_bindings_per_device_in_slot_order() -> void:
	assert_eq(_tokens(Defs.ACT_ATTACK, Defs.Device.KEYBOARD), PackedStringArray(["key:32", "key:88", "key:74"]))
	assert_eq(_tokens(Defs.ACT_ATTACK, Defs.Device.GAMEPAD), PackedStringArray(["joy_button:2", "joy_button:1"]))
	assert_eq(_tokens(Defs.ACT_LEFT, Defs.Device.GAMEPAD), PackedStringArray(["joy_button:13", "joy_axis:0:-1"]))
	assert_eq(Settings.get_default_bindings(Defs.ACT_JUMP).size(), 3)
	assert_false(Settings.has_custom_bindings())


func test_set_binding_swaps_with_the_action_that_had_the_key() -> void:
	var reported: Array[String] = []
	var on_changed: Callable = func(key: String, value: Variant) -> void:
		if key == Settings.BINDINGS_KEY:
			reported.append(str(value))
	Settings.changed.connect(on_changed)
	var other: StringName = Settings.set_binding(Defs.ACT_JUMP, _key(KEY_X), 0)
	Settings.changed.disconnect(on_changed)
	assert_eq(other, Defs.ACT_ATTACK, "X belonged to attack")
	assert_eq(_tokens(Defs.ACT_JUMP, Defs.Device.KEYBOARD), PackedStringArray(["key:88", "key:75"]))
	assert_eq(_tokens(Defs.ACT_ATTACK, Defs.Device.KEYBOARD), PackedStringArray(["key:32", "key:90", "key:74"]),
		"attack got Z in exchange, in the same slot")
	assert_eq(_tokens(Defs.ACT_JUMP, Defs.Device.GAMEPAD), PackedStringArray(["joy_button:0"]),
		"the gamepad bindings are untouched")
	assert_true(reported.has("jump") and reported.has("attack"), "both actions were reported: %s" % str(reported))
	assert_true(Settings.has_custom_bindings())


func test_set_binding_adds_moves_and_takes_without_exchange() -> void:
	assert_eq(Settings.set_binding(Defs.ACT_LOOK, _key(KEY_Q), 9), &"", "Q was free")
	assert_eq(_tokens(Defs.ACT_LOOK, Defs.Device.KEYBOARD),
		PackedStringArray(["key:67", "key:76", "key:%d" % KEY_KP_5, "key:81"]), "added after the last key")
	Settings.set_binding(Defs.ACT_LOOK, _key(KEY_Q), 0)
	assert_eq(_tokens(Defs.ACT_LOOK, Defs.Device.KEYBOARD),
		PackedStringArray(["key:81", "key:76", "key:%d" % KEY_KP_5, "key:67"]), "already bound: moved to the slot")
	assert_eq(Settings.set_binding(Defs.ACT_PAUSE, _pad_button(JOY_BUTTON_A), 5), Defs.ACT_JUMP)
	assert_eq(_tokens(Defs.ACT_JUMP, Defs.Device.GAMEPAD), PackedStringArray(),
		"nothing was replaced, so jump simply lost pad A")
	assert_eq(_tokens(Defs.ACT_PAUSE, Defs.Device.GAMEPAD), PackedStringArray(["joy_button:6", "joy_button:0"]))
	Settings.set_binding(Defs.ACT_DOWN, _pad_axis(JOY_AXIS_TRIGGER_LEFT, 0.7), 1)
	assert_eq(_tokens(Defs.ACT_DOWN, Defs.Device.GAMEPAD), PackedStringArray(["joy_button:12", "joy_axis:4:1"]))


func test_invalid_requests_are_refused() -> void:
	expect_errors(4)
	assert_eq(Settings.set_binding(&"ui_accept", _key(KEY_Q)), &"", "ui actions keep Godot's defaults")
	assert_eq(Settings.set_binding(Defs.ACT_JUMP, InputEventMouseButton.new()), &"")
	Settings.rebind(&"no_such_action", [_key(KEY_Q)] as Array[InputEvent])
	Settings.reset_binding(&"ui_cancel")
	assert_false(Settings.has_custom_bindings(), "nothing changed")


func test_rebind_stores_the_normal_form_once() -> void:
	var with_ctrl: InputEventKey = _key(KEY_M)
	with_ctrl.ctrl_pressed = true
	Settings.rebind(Defs.ACT_ATTACK, [with_ctrl, _key(KEY_M), _pad_button(JOY_BUTTON_Y)] as Array[InputEvent])
	assert_eq(_tokens(Defs.ACT_ATTACK), PackedStringArray(["key:77", "joy_button:3"]))


func test_reset_binding_restores_one_action() -> void:
	Settings.set_binding(Defs.ACT_JUMP, _key(KEY_X), 0)
	Settings.reset_binding(Defs.ACT_JUMP)
	assert_eq(_tokens(Defs.ACT_JUMP), PackedStringArray(["key:90", "key:75", "joy_button:0"]))
	assert_eq(_tokens(Defs.ACT_ATTACK, Defs.Device.KEYBOARD), PackedStringArray(["key:32", "key:74"]),
		"a default that attack held meanwhile is taken back")
	Settings.reset_bindings()
	assert_eq(_tokens(Defs.ACT_ATTACK, Defs.Device.KEYBOARD), PackedStringArray(["key:32", "key:88", "key:74"]))
	assert_false(Settings.has_custom_bindings())


func test_bindings_survive_a_restart() -> void:
	Settings.set_binding(Defs.ACT_JUMP, _key(KEY_X), 0)
	Settings.set_binding(Defs.ACT_RIGHT, _pad_axis(JOY_AXIS_RIGHT_X, 1.0), 0)
	assert_eq(Settings.save(), OK)
	var file: ConfigFile = ConfigFile.new()
	assert_eq(file.load(Settings.storage_dir + Settings.FILE_NAME), OK)
	var tokens: PackedStringArray = PackedStringArray(["key:88", "key:75", "joy_button:0"])
	assert_eq(file.get_value(Settings.BINDINGS_SECTION, "jump"), tokens, "bindings are stored as readable tokens")
	assert_false(file.has_section_key(Settings.BINDINGS_SECTION, "look"), "unchanged actions are not stored")
	InputMap.load_from_project_settings()
	Settings.load_settings()
	assert_eq(_tokens(Defs.ACT_JUMP, Defs.Device.KEYBOARD), PackedStringArray(["key:88", "key:75"]))
	assert_eq(_tokens(Defs.ACT_ATTACK, Defs.Device.KEYBOARD), PackedStringArray(["key:32", "key:90", "key:74"]))
	assert_eq(_tokens(Defs.ACT_RIGHT, Defs.Device.GAMEPAD), PackedStringArray(["joy_axis:2:1", "joy_axis:0:1"]))
	assert_almost_eq(InputMap.action_get_deadzone(Defs.ACT_RIGHT), 0.5, 0.001, "the dead zone is kept")
	Settings.reset_bindings()
	Settings.save()
	Settings.load_settings()
	assert_eq(_tokens(Defs.ACT_JUMP, Defs.Device.KEYBOARD), PackedStringArray(["key:90", "key:75"]))


func test_damaged_binding_entries_are_ignored() -> void:
	var file: ConfigFile = ConfigFile.new()
	file.set_value("meta", "version", Settings.VERSION)
	file.set_value(Settings.BINDINGS_SECTION, "jump", ["garbage", "key:81", 5, "key:81"])
	file.set_value(Settings.BINDINGS_SECTION, "attack", "key:90")
	file.set_value(Settings.BINDINGS_SECTION, "look", ["nothing:1", "key:0"])
	file.set_value(Settings.BINDINGS_SECTION, "ui_accept", ["key:81"])
	file.set_value(Settings.BINDINGS_SECTION, "no_such_action", ["key:81"])
	assert_eq(file.save(Settings.storage_dir + Settings.FILE_NAME), OK)
	Settings.load_settings()
	assert_eq(_tokens(Defs.ACT_JUMP), PackedStringArray(["key:81"]), "valid tokens are used once")
	assert_eq(_tokens(Defs.ACT_ATTACK, Defs.Device.KEYBOARD), PackedStringArray(["key:32", "key:88", "key:74"]),
		"a malformed entry keeps the defaults")
	assert_eq(_tokens(Defs.ACT_LOOK).size(), 5, "an entry without one valid token never leaves an action unbound")
	assert_false(_tokens(&"ui_accept").has("key:81"), "ui actions are never rebound from the file")


func test_game_input_follows_a_new_binding() -> void:
	Settings.set_value("controls/up_jumps", false)
	Settings.set_binding(Defs.ACT_JUMP, _key(KEY_Q), 0)
	Input.parse_input_event(_key(KEY_Q))
	Input.flush_buffered_events()
	Sim.step(1)
	assert_true(GameInput.is_held(Defs.IN_UP), "the rebound key raises the UP flag")
	Input.parse_input_event(_key(KEY_Q, false))
	Input.parse_input_event(_key(KEY_Z))
	Input.flush_buffered_events()
	Sim.step(1)
	assert_false(GameInput.is_held(Defs.IN_UP), "the replaced key does nothing any more")
	Input.parse_input_event(_key(KEY_Z, false))
	Input.flush_buffered_events()
	Sim.step(1)
	assert_eq(GameInput.flags, 0)
