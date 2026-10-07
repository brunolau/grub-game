extends TestCase
## GameInput player slots (docs/expansion/PLAN.md P0.5, TECH_AUDIT.md 4.3): slot 0 is the 1.0 input (`flags`), the
## Swap action is sampled into Defs.IN_SWAP, and every slot has its own flags, script, latches, touch buttons and
## generated `p1_*`..`p4_*` actions.

var _held: Array[InputEvent] = []


func before_each() -> void:
	Settings.reset()
	GameInput.reset_slots()
	GameInput.clear_scripted()
	GameInput.clear_touch()


func after_each() -> void:
	for event: InputEvent in _held:
		var release: InputEvent = event.duplicate() as InputEvent
		if release is InputEventKey:
			(release as InputEventKey).pressed = false
		elif release is InputEventJoypadButton:
			(release as InputEventJoypadButton).pressed = false
		Input.parse_input_event(release)
	Input.flush_buffered_events()
	_held.clear()
	for action: StringName in Defs.GAME_ACTIONS:
		Input.action_release(action)
	GameInput.enabled = true
	GameInput.reset_slots()
	GameInput.clear_scripted()
	GameInput.clear_touch()
	Settings.reset()
	Sim.step(1)


func _key(physical: Key, pressed: bool = true) -> InputEventKey:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = physical
	event.pressed = pressed
	return event


func _pad(device_id: int, button: JoyButton, pressed: bool = true) -> InputEventJoypadButton:
	var event: InputEventJoypadButton = InputEventJoypadButton.new()
	event.device = device_id
	event.button_index = button
	event.pressed = pressed
	return event


## Send an event through Input (action states and GameInput's latches); presses are released after the test.
func _send(event: InputEvent) -> void:
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	if event.is_pressed():
		_held.append(event)


func _key_tokens(action: StringName) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventKey:
			result.append(Settings.encode_event(event))
	return result


func test_single_player_is_slot_0_on_every_device() -> void:
	assert_eq(GameInput.slots.size(), Defs.MAX_PLAYERS)
	assert_eq(GameInput.slots[0].kind, Defs.InputSlotKind.ALL_DEVICES, "slot 0 reads every device, as 1.0")
	for slot: int in range(1, Defs.MAX_PLAYERS):
		assert_eq(GameInput.get_slot(slot).kind, Defs.InputSlotKind.NONE)
	assert_false(GameInput.is_party_input())
	for slot: int in Defs.MAX_PLAYERS:
		for action: StringName in Defs.GAME_ACTIONS:
			assert_false(InputMap.has_action(GameInput.slot_action(slot, action)),
				"single-player never generates actions (%s)" % GameInput.slot_action(slot, action))
	assert_eq(GameInput.slot_action(1, Defs.ACT_JUMP), &"p2_jump")
	assert_eq(GameInput.slot_action(3, Defs.ACT_SWAP), &"p4_swap")
	assert_eq(GameInput.event_slot(_key(KEY_Z)), 0, "every event is P1's")


func test_flags_is_slot_0_every_tick_and_free_slots_read_nothing() -> void:
	var values: PackedInt32Array = GameInput.expand_runs([[2, "R"], [1, "RU"], [1, "FS"], [1, "KS"], [2, ""]])
	var first: int = Sim.tick + 1
	GameInput.set_scripted(func(tick: int) -> int: return values[tick - first])
	var previous: int = GameInput.flags
	for i: int in values.size():
		Sim.step(1)
		assert_eq(GameInput.flags, values[i], "tick %d: the scripted flags" % i)
		assert_eq(GameInput.get_flags(0), GameInput.flags, "tick %d: flags == get_flags(0)" % i)
		assert_eq(GameInput.slot_flags[0], GameInput.flags)
		assert_eq(GameInput.get_prev_flags(0), previous)
		assert_eq(GameInput.prev_flags, previous)
		for slot: int in range(1, Defs.MAX_PLAYERS):
			assert_eq(GameInput.get_flags(slot), 0, "tick %d: slot %d is free" % [i, slot])
		previous = values[i]
	assert_eq(GameInput.get_flags(-1), 0)
	assert_eq(GameInput.get_flags(Defs.MAX_PLAYERS), 0)
	assert_true(GameInput.is_slot_held(0, 0))


func test_swap_is_sampled_into_its_own_bit() -> void:
	assert_true(Defs.GAME_ACTIONS.has(Defs.ACT_SWAP))
	assert_eq(GameInput.keys_to_flags("S"), Defs.IN_SWAP, "route key S")
	assert_eq(GameInput.keys_to_flags("RUS"), Defs.IN_RIGHT | Defs.IN_UP | Defs.IN_SWAP)
	assert_eq(Autoplay.parse_inputs("2:s,1:"), PackedInt32Array([Defs.IN_SWAP, Defs.IN_SWAP, 0]))
	assert_eq(Defs.IN_SWAP & Defs.IN_STATE_MASK, 0, "the state table never sees it")
	Input.action_press(Defs.ACT_SWAP)
	Sim.step(1)
	assert_eq(GameInput.flags, Defs.IN_SWAP, "the swap action")
	Input.action_release(Defs.ACT_SWAP)
	Sim.step(1)
	assert_eq(GameInput.flags, 0)
	_send(_key(KEY_V))
	_send(_key(KEY_V, false))
	Sim.step(1)
	assert_true(GameInput.is_held(Defs.IN_SWAP), "V, tapped between two ticks, is latched")
	Sim.step(1)
	assert_false(GameInput.is_held(Defs.IN_SWAP))
	_send(_key(KEY_SEMICOLON))
	Sim.step(1)
	assert_true(GameInput.is_held(Defs.IN_SWAP), "; swaps too")
	_send(_key(KEY_SEMICOLON, false))
	GameInput.set_touch(Defs.ACT_SWAP, true)
	Sim.step(1)
	assert_true(GameInput.is_held(Defs.IN_SWAP), "the touch Y stone feeds the swap action")
	GameInput.set_touch(Defs.ACT_SWAP, false)
	Sim.step(1)
	assert_eq(GameInput.flags, 0)


func test_scripted_slots_are_independent() -> void:
	GameInput.set_scripted_slot(1, func(_tick: int) -> int: return Defs.IN_LEFT)
	assert_true(GameInput.is_scripted())
	assert_false(GameInput.is_slot_scripted(0))
	assert_true(GameInput.is_slot_scripted(1))
	Sim.step(1)
	assert_eq(GameInput.get_flags(1), Defs.IN_LEFT)
	assert_eq(GameInput.flags, 0, "slot 0 still reads the devices (nothing held)")
	GameInput.set_scripted(func(_tick: int) -> int: return Defs.IN_FIRE)
	Sim.step(1)
	assert_eq(GameInput.flags, Defs.IN_FIRE)
	assert_eq(GameInput.get_flags(1), Defs.IN_LEFT)
	assert_true(GameInput.slot_just_pressed(0, Defs.IN_FIRE))
	assert_false(GameInput.slot_just_pressed(1, Defs.IN_LEFT))
	GameInput.clear_scripted_slot(1)
	Sim.step(1)
	assert_eq(GameInput.get_flags(1), 0)
	assert_eq(GameInput.flags, Defs.IN_FIRE)
	GameInput.clear_scripted()
	assert_false(GameInput.is_scripted(), "clear_scripted clears every slot")
	assert_eq(GameInput.flags, 0)
	expect_errors(1)
	GameInput.set_scripted_slot(Defs.MAX_PLAYERS, Callable())


func test_keyboard_halves_feed_their_own_slot() -> void:
	GameInput.assign_slot(0, InputSlot.keyboard(Defs.InputSlotKind.KEYBOARD_LEFT))
	GameInput.assign_slot(1, InputSlot.keyboard(Defs.InputSlotKind.KEYBOARD_RIGHT))
	assert_true(GameInput.is_party_input())
	assert_eq(_key_tokens(&"p1_jump"), PackedStringArray(["key:%d" % KEY_SPACE]), "classic: P1 jumps with Space")
	assert_eq(_key_tokens(&"p2_jump"), PackedStringArray(["key:%d" % KEY_KP_0]), "P2 with Num 0")
	assert_eq(_key_tokens(&"p2_swap"), PackedStringArray(["key:%d" % KEY_KP_ADD]))
	assert_eq(_key_tokens(&"p1_swap"), PackedStringArray(["key:%d" % KEY_E]))
	_send(_key(KEY_D))
	_send(_key(KEY_KP_4))
	Sim.step(1)
	assert_eq(GameInput.get_flags(0), Defs.IN_RIGHT, "D moves P1")
	assert_eq(GameInput.get_flags(1), Defs.IN_LEFT, "Num 4 moves P2")
	_send(_key(KEY_D, false))
	_send(_key(KEY_KP_4, false))
	_send(_key(KEY_LEFT))
	Sim.step(1)
	assert_eq(GameInput.flags, 0, "in a party the single-player arrows do not reach P1")
	assert_eq(GameInput.get_flags(1), 0)
	_send(_key(KEY_LEFT, false))
	_send(_key(KEY_KP_0))
	_send(_key(KEY_KP_0, false))
	_send(_key(KEY_E))
	Sim.step(1)
	assert_eq(GameInput.get_flags(1), Defs.IN_UP, "P2's jump tap is latched")
	assert_eq(GameInput.get_flags(0), Defs.IN_SWAP, "E is P1's swap")
	_send(_key(KEY_E, false))
	assert_eq(GameInput.slot_devices[1], Defs.Device.KEYBOARD)
	assert_eq(GameInput.event_slot(_key(KEY_W)), 0)
	assert_eq(GameInput.event_slot(_key(KEY_KP_8)), 1)
	assert_eq(GameInput.event_slot(_key(KEY_F12)), -1, "a key of no half")
	GameInput.reset_slots()
	assert_false(InputMap.has_action(&"p1_jump"), "back to single-player: the generated actions are gone")
	assert_false(GameInput.is_party_input())


func test_a_pad_slot_reads_only_its_own_pad() -> void:
	GameInput.assign_slot(0, InputSlot.keyboard(Defs.InputSlotKind.KEYBOARD_LEFT))
	GameInput.assign_slot(1, InputSlot.pad(3))
	for event: InputEvent in InputMap.action_get_events(&"p2_jump"):
		assert_eq(event.device, 3, "bound to its pad only")
		assert_false(event is InputEventKey, "a pad slot has no keys")
	var swap_buttons: Array[int] = []
	for event: InputEvent in InputMap.action_get_events(&"p2_swap"):
		swap_buttons.append((event as InputEventJoypadButton).button_index)
	assert_eq(swap_buttons, [JOY_BUTTON_LEFT_SHOULDER] as Array[int], "LB swaps")
	_send(_pad(2, JOY_BUTTON_A))
	Sim.step(1)
	assert_eq(GameInput.get_flags(1), 0, "another pad does nothing")
	_send(_pad(2, JOY_BUTTON_A, false))
	_send(_pad(3, JOY_BUTTON_A))
	Sim.step(1)
	assert_eq(GameInput.get_flags(1), Defs.IN_UP, "its own pad's A jumps")
	assert_eq(GameInput.flags, 0, "P1 on the keyboard is not fed by the pad")
	assert_eq(GameInput.slot_devices[1], Defs.Device.GAMEPAD)
	_send(_pad(3, JOY_BUTTON_A, false))
	assert_eq(GameInput.event_slot(_pad(3, JOY_BUTTON_X)), 1)
	assert_eq(GameInput.event_slot(_pad(2, JOY_BUTTON_X)), -1)
	GameInput.vibrate_slot(1, 10)
	GameInput.vibrate_slot(0, 10)
	GameInput.vibrate_slot(Defs.MAX_PLAYERS, 10)


func test_touch_and_bot_slots() -> void:
	GameInput.assign_slot(1, InputSlot.touch(Rect2(0.5, 0.0, 0.5, 1.0)))
	GameInput.set_touch_slot(1, Defs.ACT_RIGHT, true)
	Sim.step(1)
	assert_eq(GameInput.get_flags(1), Defs.IN_RIGHT)
	assert_eq(GameInput.flags, 0, "slot 0 keeps its own touch buttons")
	GameInput.set_touch_slot(1, Defs.ACT_RIGHT, false)
	GameInput.set_touch_slot(1, Defs.ACT_JUMP, true)
	GameInput.set_touch_slot(1, Defs.ACT_JUMP, false)
	Sim.step(1)
	assert_eq(GameInput.get_flags(1), Defs.IN_UP, "a tap between two ticks is latched")
	GameInput.set_touch_slot(1, Defs.ACT_LOOK, true)
	GameInput.clear_touch()
	Sim.step(1)
	Sim.step(1)
	assert_eq(GameInput.get_flags(1), 0, "clear_touch releases every slot")
	var asked: Array[int] = []
	GameInput.assign_slot(2, InputSlot.bot(func(tick: int) -> int:
		asked.append(tick)
		return Defs.IN_FIRE))
	Sim.step(2)
	assert_eq(GameInput.get_flags(2), Defs.IN_FIRE)
	assert_eq(asked.size(), 2, "a bot is asked once per tick")
	GameInput.enabled = false
	Sim.step(1)
	assert_eq(GameInput.get_flags(2), 0, "disabled input silences every slot")
	assert_eq(asked.size(), 2)
	GameInput.enabled = true
	expect_errors(3)
	GameInput.set_touch_slot(1, &"ui_accept", true)
	GameInput.set_touch_slot(Defs.MAX_PLAYERS, Defs.ACT_JUMP, true)
	GameInput.assign_slot(-1, null)


func test_generated_actions_follow_the_settings() -> void:
	GameInput.assign_slot(1, InputSlot.keyboard(Defs.InputSlotKind.KEYBOARD_RIGHT))
	Settings.set_slot_binding(1, Defs.ACT_JUMP, _key(KEY_M))
	assert_eq(_key_tokens(&"p2_jump"), PackedStringArray(["key:%d" % KEY_M]), "a rebind reaches the slot at once")
	Settings.load_settings()
	assert_true(InputMap.has_action(&"p2_jump"), "reloading the bindings rebuilds the generated actions")
	assert_eq(_key_tokens(&"p2_jump"), PackedStringArray(["key:%d" % KEY_KP_0]), "the unsaved rebind is gone")
	Settings.set_value(Settings.PARTY_KEYBOARD_KEY, "two_hands")
	assert_eq(_key_tokens(&"p2_jump"), PackedStringArray(["key:%d" % KEY_SLASH]), "another layout")
	GameInput.assign_slot(0, InputSlot.keyboard(Defs.InputSlotKind.KEYBOARD_FULL))
	assert_eq(_key_tokens(&"p1_jump"), PackedStringArray(["key:%d" % KEY_Z, "key:%d" % KEY_K]),
		"the whole keyboard uses the single-player keys")
	Settings.reset()
	assert_true(InputMap.has_action(&"p1_jump"))
	assert_eq(_key_tokens(&"p2_jump"), PackedStringArray(["key:%d" % KEY_KP_0]))
