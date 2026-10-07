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



# --- 2.0: party binding profiles [bindings_p1]..[bindings_p4] (docs/expansion/PLAN.md P0.5, DESIGN.md D.11) -----

func _slot_tokens(slot: int, action: StringName, device: int = -1, half: int = -1) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for event: InputEvent in Settings.get_slot_bindings(slot, action, device, half):
		result.append(Settings.encode_event(event))
	return result


func _keys(codes: Array[Key]) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for code: Key in codes:
		result.append("key:%d" % code)
	return result


func test_the_swap_action_has_its_defaults() -> void:
	assert_eq(_tokens(Defs.ACT_SWAP), PackedStringArray(["key:%d" % KEY_V, "key:%d" % KEY_SEMICOLON,
		"joy_button:%d" % JOY_BUTTON_LEFT_SHOULDER]), "V, ; and pad LB (DESIGN.md C.1)")
	assert_eq(Settings.set_binding(Defs.ACT_SWAP, _key(KEY_X), 0), Defs.ACT_ATTACK, "swap takes part in the exchange")
	assert_eq(_tokens(Defs.ACT_ATTACK, Defs.Device.KEYBOARD), PackedStringArray(["key:32", "key:%d" % KEY_V, "key:74"]))


func test_party_profiles_default_to_the_keyboard_layouts() -> void:
	assert_eq(Settings.slot_bindings_section(0), "bindings_p1")
	assert_eq(Settings.slot_bindings_section(3), "bindings_p4")
	assert_eq(Settings.party_keyboard_layout(), InputSlot.KeyboardLayout.CLASSIC, "classic is the default")
	var kb: int = Defs.Device.KEYBOARD
	# Classic: P1 on W A S D + Space / Left Shift, P2 on the numpad.
	assert_eq(_slot_tokens(0, Defs.ACT_JUMP, kb), _keys([KEY_SPACE]))
	assert_eq(_slot_tokens(0, Defs.ACT_ATTACK, kb), _keys([KEY_SHIFT]))
	assert_eq(_slot_tokens(0, Defs.ACT_SWAP, kb), _keys([KEY_E]))
	assert_eq(_slot_tokens(0, Defs.ACT_LOOK, kb), _keys([KEY_Q]))
	assert_eq(_slot_tokens(1, Defs.ACT_UP, kb), _keys([KEY_KP_8]))
	assert_eq(_slot_tokens(1, Defs.ACT_DOWN, kb), _keys([KEY_KP_5]))
	assert_eq(_slot_tokens(1, Defs.ACT_ATTACK, kb), _keys([KEY_KP_ENTER]))
	assert_eq(_slot_tokens(1, Defs.ACT_SWAP, kb), _keys([KEY_KP_ADD]))
	assert_eq(_slot_tokens(1, Defs.ACT_LOOK, kb), _keys([KEY_KP_PERIOD]))
	assert_eq(_slot_tokens(1, Defs.ACT_PAUSE, kb), PackedStringArray(), "Escape and P keep pausing for everyone")
	assert_eq(_slot_tokens(2, Defs.ACT_JUMP, kb), PackedStringArray(), "a keyboard serves two players at most")
	assert_eq(_slot_tokens(2, Defs.ACT_JUMP, kb, Defs.InputSlotKind.KEYBOARD_RIGHT), _keys([KEY_KP_0]),
		"a slot can use another half")
	assert_eq(_slot_tokens(0, Defs.ACT_JUMP, kb, Defs.InputSlotKind.KEYBOARD_FULL), _keys([KEY_Z, KEY_K]),
		"the whole keyboard: the single-player keys")
	for slot: int in Defs.MAX_PLAYERS:
		assert_eq(_slot_tokens(slot, Defs.ACT_SWAP, Defs.Device.GAMEPAD), PackedStringArray(["joy_button:9"]),
			"every slot: the solo pad layout, LB swaps")
		assert_eq(_slot_tokens(slot, Defs.ACT_JUMP, Defs.Device.GAMEPAD), PackedStringArray(["joy_button:0"]))
	Settings.set_value(Settings.PARTY_KEYBOARD_KEY, "two_hands")
	assert_eq(_slot_tokens(0, Defs.ACT_JUMP, kb), _keys([KEY_G]))
	assert_eq(_slot_tokens(0, Defs.ACT_SWAP, kb), _keys([KEY_T]))
	assert_eq(_slot_tokens(1, Defs.ACT_ATTACK, kb), _keys([KEY_PERIOD]))
	assert_eq(_slot_tokens(1, Defs.ACT_JUMP, kb), _keys([KEY_SLASH]))
	assert_eq(_slot_tokens(1, Defs.ACT_SWAP, kb), _keys([KEY_SEMICOLON]))
	Settings.set_value(Settings.PARTY_KEYBOARD_KEY, "one_hand")
	assert_eq(_slot_tokens(0, Defs.ACT_JUMP, kb), _keys([KEY_W]), "the Up-jumps scheme: W jumps")
	assert_eq(_slot_tokens(0, Defs.ACT_UP, kb), PackedStringArray())
	assert_eq(_slot_tokens(1, Defs.ACT_JUMP, kb), _keys([KEY_UP]))
	assert_eq(_slot_tokens(1, Defs.ACT_ATTACK, kb), _keys([KEY_CTRL]))
	assert_eq(_slot_tokens(1, Defs.ACT_LOOK, kb), _keys([KEY_KP_0]))
	Settings.set_value(Settings.PARTY_KEYBOARD_KEY, "no_such_layout")
	assert_eq(Settings.party_keyboard_layout(), InputSlot.KeyboardLayout.CLASSIC)


func test_every_layout_has_two_disjoint_complete_halves() -> void:
	for layout: int in InputSlot.KEYBOARD_LAYOUT_NAMES.size():
		var left: Array[Key] = []
		var right: Array[Key] = []
		for action: StringName in Defs.GAME_ACTIONS:
			var left_keys: Array[Key] = InputSlot.default_keys(layout, Defs.InputSlotKind.KEYBOARD_LEFT, action)
			var right_keys: Array[Key] = InputSlot.default_keys(layout, Defs.InputSlotKind.KEYBOARD_RIGHT, action)
			left.append_array(left_keys)
			right.append_array(right_keys)
			if action != Defs.ACT_PAUSE and action != Defs.ACT_UP:
				assert_false(left_keys.is_empty(), "layout %d: P1 has a key for %s" % [layout, action])
				assert_false(right_keys.is_empty(), "layout %d: P2 has a key for %s" % [layout, action])
		for code: Key in left:
			assert_false(right.has(code), "layout %d: key %d is on both halves" % [layout, code])
			assert_eq(left.count(code), 1, "layout %d: key %d is on one action of P1" % [layout, code])
		for code: Key in right:
			assert_eq(right.count(code), 1, "layout %d: key %d is on one action of P2" % [layout, code])


func test_slot_bindings_swap_inside_one_profile() -> void:
	var reported: Array[String] = []
	var on_changed: Callable = func(key: String, value: Variant) -> void:
		if key == Settings.BINDINGS_KEY:
			reported.append(str(value))
	Settings.changed.connect(on_changed)
	var other: StringName = Settings.set_slot_binding(1, Defs.ACT_JUMP, _key(KEY_KP_ENTER), 0)
	Settings.changed.disconnect(on_changed)
	assert_eq(other, Defs.ACT_ATTACK, "Num Enter was P2's strike")
	assert_eq(_slot_tokens(1, Defs.ACT_JUMP, Defs.Device.KEYBOARD), _keys([KEY_KP_ENTER]))
	assert_eq(_slot_tokens(1, Defs.ACT_ATTACK, Defs.Device.KEYBOARD), _keys([KEY_KP_0]), "strike got Num 0 instead")
	assert_eq(_slot_tokens(1, Defs.ACT_JUMP, Defs.Device.GAMEPAD), PackedStringArray(["joy_button:0"]),
		"the pad part is untouched")
	assert_true(reported.has("p2_jump") and reported.has("p2_attack"), "reported as generated actions: %s" % [reported])
	assert_eq(_slot_tokens(0, Defs.ACT_JUMP, Defs.Device.KEYBOARD), _keys([KEY_SPACE]), "P1's profile is untouched")
	assert_eq(_tokens(Defs.ACT_JUMP), PackedStringArray(["key:90", "key:75", "joy_button:0"]),
		"the single-player bindings are untouched")
	assert_false(Settings.has_custom_bindings())
	assert_true(Settings.has_custom_slot_bindings(1))
	assert_false(Settings.has_custom_slot_bindings(0))
	Settings.reset_slot_binding(1, Defs.ACT_JUMP)
	assert_eq(_slot_tokens(1, Defs.ACT_JUMP, Defs.Device.KEYBOARD), _keys([KEY_KP_0]))
	assert_eq(_slot_tokens(1, Defs.ACT_ATTACK, Defs.Device.KEYBOARD), PackedStringArray(),
		"a default that strike held meanwhile is taken back")
	Settings.reset_slot_bindings(1)
	assert_eq(_slot_tokens(1, Defs.ACT_ATTACK, Defs.Device.KEYBOARD), _keys([KEY_KP_ENTER]))
	assert_false(Settings.has_custom_slot_bindings(1))


func test_slot_bindings_survive_a_restart() -> void:
	var with_ctrl: InputEventKey = _key(KEY_Y)
	with_ctrl.ctrl_pressed = true
	Settings.rebind_slot(0, Defs.ACT_SWAP, [with_ctrl, _key(KEY_Y), _pad_button(JOY_BUTTON_RIGHT_SHOULDER)] \
		as Array[InputEvent])
	assert_eq(_slot_tokens(0, Defs.ACT_SWAP), PackedStringArray(["key:%d" % KEY_Y, "joy_button:10"]))
	Settings.set_slot_binding(3, Defs.ACT_LOOK, _pad_button(JOY_BUTTON_X), 0)
	assert_eq(Settings.save(), OK)
	var file: ConfigFile = ConfigFile.new()
	assert_eq(file.load(Settings.storage_dir + Settings.FILE_NAME), OK)
	assert_eq(file.get_value("bindings_p1", "swap"), PackedStringArray(["key:%d" % KEY_Y, "joy_button:10"]))
	assert_true(file.has_section_key("bindings_p4", "look"))
	assert_false(file.has_section("bindings_p2"), "unchanged profiles are not stored")
	file.set_value("bindings_p2", "jump", ["garbage", 5])
	file.set_value("bindings_p2", "no_such_action", ["key:81"])
	assert_eq(file.save(Settings.storage_dir + Settings.FILE_NAME), OK)
	Settings.load_settings()
	assert_eq(_slot_tokens(0, Defs.ACT_SWAP), PackedStringArray(["key:%d" % KEY_Y, "joy_button:10"]))
	assert_eq(_slot_tokens(3, Defs.ACT_LOOK, Defs.Device.GAMEPAD)[0], "joy_button:2")
	assert_eq(_slot_tokens(1, Defs.ACT_JUMP, Defs.Device.KEYBOARD), _keys([KEY_KP_0]), "a damaged entry: defaults")
	assert_null(Settings.get_value("bindings_p1/swap"), "a profile is no setting value")
	assert_eq(_tokens(Defs.ACT_SWAP, Defs.Device.KEYBOARD), PackedStringArray(["key:%d" % KEY_V, "key:59"]),
		"the single-player swap is untouched")
	Settings.rebind_slot(0, Defs.ACT_SWAP, [] as Array[InputEvent])
	assert_eq(_slot_tokens(0, Defs.ACT_SWAP, Defs.Device.KEYBOARD), _keys([KEY_E]), "an empty list: the defaults")
	Settings.reset()
	assert_false(Settings.has_custom_slot_bindings(3), "reset() clears the profiles")


func test_invalid_slot_requests_are_refused() -> void:
	expect_errors(5)
	assert_eq(Settings.get_slot_bindings(Defs.MAX_PLAYERS, Defs.ACT_JUMP), [] as Array[InputEvent])
	assert_eq(Settings.set_slot_binding(0, &"ui_accept", _key(KEY_Q)), &"")
	assert_eq(Settings.set_slot_binding(0, Defs.ACT_JUMP, InputEventMouseButton.new()), &"")
	Settings.rebind_slot(-1, Defs.ACT_JUMP, [] as Array[InputEvent])
	Settings.reset_slot_binding(0, &"no_such_action")
	assert_false(Settings.has_custom_slot_bindings(0))
	assert_false(Settings.has_custom_slot_bindings(9))
