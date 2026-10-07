extends TestCase
## The shared-keyboard presets of DESIGN.md D.11 as data (InputSlot / GameInput / Settings), the classic WASD + numpad
## layout in both NumLock states, the menu clusters, and the input of a player who presses Jump to join
## (docs/expansion/PLAN.md P1.1 / P1.12).

var _held: Array[InputEvent] = []


func before_each() -> void:
	Settings.reset()
	GameInput.reset_slots()
	GameInput.clear_scripted()


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
	GameInput.set_menu_clusters(false)
	GameInput.reset_slots()
	GameInput.clear_scripted()
	Settings.reset()
	Sim.step(1)


## A key event as Windows delivers it: `physical` from the scancode, `logical` from the virtual key (with NumLock off
## the numpad's virtual keys are the navigation keys: Num 8 = Up, Num 5 = Clear, Num 0 = Insert ...).
func _key(physical: Key, logical: Key = KEY_NONE, pressed: bool = true) -> InputEventKey:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = physical
	event.keycode = logical if logical != KEY_NONE else physical
	event.pressed = pressed
	return event


func _send(event: InputEvent) -> void:
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	if event.is_pressed():
		_held.append(event)


func _classic_party() -> void:
	GameInput.set_keyboard_layout(InputSlot.KeyboardLayout.CLASSIC)
	GameInput.assign_slot(0, InputSlot.keyboard(Defs.InputSlotKind.KEYBOARD_LEFT))
	GameInput.assign_slot(1, InputSlot.keyboard(Defs.InputSlotKind.KEYBOARD_RIGHT))


func test_classic_is_the_default_and_the_presets_are_data() -> void:
	assert_eq(Settings.get_value(Settings.PARTY_KEYBOARD_KEY), "classic", "classic WASD + numpad is the default")
	assert_eq(GameInput.keyboard_layout(), InputSlot.KeyboardLayout.CLASSIC)
	var presets: Array[Dictionary] = GameInput.keyboard_presets()
	assert_eq(presets.size(), 3)
	assert_eq(presets[0]["id"], "classic", "classic is offered first")
	assert_eq(presets[1]["id"], "two_hands")
	assert_eq(presets[2]["id"], "one_hand")
	var classic: Dictionary = presets[0]
	assert_true(classic["numpad"])
	assert_false(presets[1]["numpad"], "the laptop layout has no numpad")
	var left: Dictionary = classic["left"]
	var right: Dictionary = classic["right"]
	assert_eq(left[Defs.ACT_JUMP], [KEY_SPACE] as Array[Key])
	assert_eq(left[Defs.ACT_ATTACK], [KEY_SHIFT] as Array[Key], "strike Left Shift")
	assert_eq(left[Defs.ACT_SWAP], [KEY_E] as Array[Key])
	assert_eq(left[Defs.ACT_LOOK], [KEY_Q] as Array[Key])
	assert_eq([right[Defs.ACT_UP], right[Defs.ACT_LEFT], right[Defs.ACT_DOWN], right[Defs.ACT_RIGHT]],
			[[KEY_KP_8], [KEY_KP_4], [KEY_KP_5], [KEY_KP_6]], "P2 moves on Num 8 4 5 6")
	assert_eq(right[Defs.ACT_JUMP], [KEY_KP_0] as Array[Key])
	assert_eq(right[Defs.ACT_ATTACK], [KEY_KP_ENTER] as Array[Key])
	assert_eq(right[Defs.ACT_SWAP], [KEY_KP_ADD] as Array[Key])
	assert_eq(right[Defs.ACT_LOOK], [KEY_KP_PERIOD] as Array[Key])
	assert_eq((classic["menu_left"] as Dictionary)[&"ui_accept"], [KEY_SPACE] as Array[Key])
	assert_eq((classic["menu_right"] as Dictionary)[&"ui_up"], [KEY_KP_8] as Array[Key])
	assert_eq((classic["menu_right"] as Dictionary)[&"ui_down"], [KEY_KP_5] as Array[Key])
	assert_eq((classic["menu_right"] as Dictionary)[&"ui_accept"], [KEY_KP_0] as Array[Key])
	assert_eq((classic["menu_right"] as Dictionary)[&"ui_cancel"], [KEY_KP_PERIOD] as Array[Key])
	assert_eq((classic["menu_left"] as Dictionary)[&"ui_cancel"], [KEY_Q] as Array[Key])
	var one_hand: Dictionary = presets[2]
	assert_eq((one_hand["menu_left"] as Dictionary)[&"ui_up"], [KEY_W] as Array[Key], "Up jumps: W is the menu's up")
	assert_eq((one_hand["menu_left"] as Dictionary)[&"ui_accept"], [KEY_SPACE] as Array[Key], "... and Strike accepts")
	GameInput.set_keyboard_layout(InputSlot.KeyboardLayout.TWO_HANDS)
	assert_eq(Settings.get_value(Settings.PARTY_KEYBOARD_KEY), "two_hands")
	GameInput.set_keyboard_layout(99)
	assert_eq(Settings.get_value(Settings.PARTY_KEYBOARD_KEY), "one_hand", "clamped to a known layout")


func test_the_numpad_works_whatever_the_numlock_state() -> void:
	# Godot 4.7.2 on Windows (verified with scenes/core/dev/key_probe.tscn): with NumLock off Num 8 arrives as
	# keycode Up but physical KP_8, so the physical bindings of the classic layout need no alias.
	_classic_party()
	assert_true(InputSlot.uses_numpad(InputSlot.KeyboardLayout.CLASSIC, Defs.InputSlotKind.KEYBOARD_RIGHT))
	assert_false(InputSlot.uses_numpad(InputSlot.KeyboardLayout.CLASSIC, Defs.InputSlotKind.KEYBOARD_LEFT))
	var numlock_off: Dictionary = {
		KEY_KP_8: KEY_UP, KEY_KP_4: KEY_LEFT, KEY_KP_5: KEY_CLEAR, KEY_KP_6: KEY_RIGHT, KEY_KP_0: KEY_INSERT,
		KEY_KP_PERIOD: KEY_DELETE, KEY_KP_ENTER: KEY_KP_ENTER, KEY_KP_ADD: KEY_KP_ADD,
	}
	var actions: Dictionary = {
		KEY_KP_8: Defs.ACT_UP, KEY_KP_4: Defs.ACT_LEFT, KEY_KP_5: Defs.ACT_DOWN, KEY_KP_6: Defs.ACT_RIGHT,
		KEY_KP_0: Defs.ACT_JUMP, KEY_KP_PERIOD: Defs.ACT_LOOK, KEY_KP_ENTER: Defs.ACT_ATTACK, KEY_KP_ADD: Defs.ACT_SWAP,
	}
	for physical: Key in numlock_off:
		var p2_action: StringName = GameInput.slot_action(1, actions[physical])
		assert_true(InputSlot.is_numpad_key(physical))
		assert_true(_key(physical, physical).is_action(p2_action, true), "NumLock on: %s" % OS.get_keycode_string(physical))
		assert_true(_key(physical, numlock_off[physical]).is_action(p2_action, true),
				"NumLock off: %s" % OS.get_keycode_string(physical))
		for action: StringName in Defs.GAME_ACTIONS:
			assert_false(_key(physical, numlock_off[physical]).is_action(GameInput.slot_action(0, action), true),
					"%s never reaches P1" % OS.get_keycode_string(physical))
	assert_false(_key(KEY_UP).is_action(GameInput.slot_action(1, Defs.ACT_UP), true),
			"the arrow keys are not P2's in the classic layout")


func test_two_players_on_one_keyboard_with_numlock_off() -> void:
	_classic_party()
	Sim.step(1)
	_send(_key(KEY_D))
	_send(_key(KEY_SHIFT))
	_send(_key(KEY_KP_4, KEY_LEFT))
	_send(_key(KEY_KP_0, KEY_INSERT))
	_send(_key(KEY_KP_ADD))
	Sim.step(1)
	assert_eq(GameInput.get_flags(0), Defs.IN_RIGHT | Defs.IN_FIRE, "P1: right + strike")
	assert_eq(GameInput.get_flags(1), Defs.IN_LEFT | Defs.IN_UP | Defs.IN_SWAP, "P2: left + jump + swap")
	_send(_key(KEY_KP_4, KEY_LEFT, false))
	_send(_key(KEY_KP_8, KEY_UP))
	_send(_key(KEY_KP_ENTER))
	Sim.step(1)
	assert_eq(GameInput.get_flags(1), Defs.IN_UP | Defs.IN_FIRE | Defs.IN_SWAP, "Up + Strike: the high strike")


func test_menu_clusters_come_and_go() -> void:
	_classic_party()
	var w: InputEventKey = _key(KEY_W)
	var num_5: InputEventKey = _key(KEY_KP_5, KEY_CLEAR)
	var num_dot: InputEventKey = _key(KEY_KP_PERIOD, KEY_DELETE)
	assert_false(w.is_action(&"ui_up", true), "W is no menu key by default (the code entry types it)")
	GameInput.set_menu_clusters(true)
	assert_true(GameInput.has_menu_clusters())
	assert_true(w.is_action(&"ui_up", true), "P1 drives the menus with W ...")
	assert_true(_key(KEY_Q).is_action(&"ui_cancel", true))
	assert_true(num_5.is_action(&"ui_down", true), "... P2 with the numpad, NumLock off too")
	assert_true(_key(KEY_KP_0, KEY_INSERT).is_action(&"ui_accept", true))
	assert_true(num_dot.is_action(&"ui_cancel", true))
	assert_eq(GameInput.event_half(w), Defs.InputSlotKind.KEYBOARD_LEFT)
	assert_eq(GameInput.event_half(num_dot), Defs.InputSlotKind.KEYBOARD_RIGHT)
	assert_eq(GameInput.event_half(_key(KEY_F1)), Defs.InputSlotKind.NONE)
	Settings.reset_bindings()
	assert_true(w.is_action(&"ui_up", true), "a reload of the InputMap keeps the clusters")
	GameInput.set_keyboard_layout(InputSlot.KeyboardLayout.TWO_HANDS)
	assert_false(num_5.is_action(&"ui_down", true), "another layout, other keys")
	assert_true(_key(KEY_G).is_action(&"ui_accept", true), "two hands: P1's jump G accepts")
	GameInput.set_menu_clusters(false)
	assert_false(GameInput.has_menu_clusters())
	assert_false(w.is_action(&"ui_up", true), "off removes exactly what was added")
	assert_false(_key(KEY_G).is_action(&"ui_accept", true))
	assert_true(_key(KEY_SPACE).is_action(&"ui_accept", true), "Godot's own menu keys stay")
	assert_true(_key(KEY_UP).is_action(&"ui_up", true))


func test_press_jump_to_join() -> void:
	var space: InputSlot = GameInput.join_input_for_event(_key(KEY_SPACE))
	assert_not_null(space)
	if space != null:
		assert_eq(space.kind, Defs.InputSlotKind.KEYBOARD_LEFT, "Space joins the left half")
	var num_0: InputSlot = GameInput.join_input_for_event(_key(KEY_KP_0, KEY_INSERT))
	assert_not_null(num_0)
	if num_0 != null:
		assert_eq(num_0.kind, Defs.InputSlotKind.KEYBOARD_RIGHT, "Num 0 joins the right half, NumLock off too")
	assert_null(GameInput.join_input_for_event(_key(KEY_W)), "only Jump joins")
	assert_null(GameInput.join_input_for_event(_key(KEY_SPACE, KEY_NONE, false)), "a release joins nobody")
	var pad_jump: InputEventJoypadButton = InputEventJoypadButton.new()
	pad_jump.device = 3
	pad_jump.button_index = JOY_BUTTON_A
	pad_jump.pressed = true
	var pad: InputSlot = GameInput.join_input_for_event(pad_jump)
	assert_not_null(pad)
	if pad != null:
		assert_eq(pad.kind, Defs.InputSlotKind.PAD)
		assert_eq(pad.device_id, 3)
	pad_jump.button_index = JOY_BUTTON_START
	assert_null(GameInput.join_input_for_event(pad_jump), "Start is no join")
	GameInput.set_keyboard_layout(InputSlot.KeyboardLayout.TWO_HANDS)
	var slash: InputSlot = GameInput.join_input_for_event(_key(KEY_SLASH))
	assert_true(slash != null and slash.kind == Defs.InputSlotKind.KEYBOARD_RIGHT, "the layout's own Jump keys")


func test_which_slot_reads_an_input() -> void:
	GameInput.assign_slot(0, InputSlot.keyboard(Defs.InputSlotKind.KEYBOARD_LEFT))
	GameInput.assign_slot(1, InputSlot.pad(2))
	assert_eq(GameInput.find_input(InputSlot.keyboard(Defs.InputSlotKind.KEYBOARD_LEFT)), 0)
	assert_eq(GameInput.find_input(InputSlot.keyboard(Defs.InputSlotKind.KEYBOARD_RIGHT)), -1)
	assert_eq(GameInput.find_input(InputSlot.keyboard(Defs.InputSlotKind.KEYBOARD_FULL)), 0, "the whole keyboard")
	assert_eq(GameInput.find_input(InputSlot.pad(2)), 1)
	assert_eq(GameInput.find_input(InputSlot.pad(5)), -1)
	assert_eq(GameInput.find_input(null), -1)


func test_the_single_player_keeps_his_device_when_a_partner_joins() -> void:
	_send(_key(KEY_A))
	var keys: InputSlot = GameInput.current_device_input()
	assert_eq(keys.kind, Defs.InputSlotKind.KEYBOARD_LEFT, "a keyboard player keeps the left half")
	keys = GameInput.current_device_input(InputSlot.keyboard(Defs.InputSlotKind.KEYBOARD_LEFT))
	assert_eq(keys.kind, Defs.InputSlotKind.KEYBOARD_RIGHT, "... or takes the right one when the partner joined left")
	var button: InputEventJoypadButton = InputEventJoypadButton.new()
	button.device = 6
	button.button_index = JOY_BUTTON_X
	button.pressed = true
	_send(button)
	var pad: InputSlot = GameInput.current_device_input(InputSlot.keyboard(Defs.InputSlotKind.KEYBOARD_RIGHT))
	assert_eq(pad.kind, Defs.InputSlotKind.PAD, "a pad player keeps his pad")
	assert_eq(pad.device_id, 6)
	pad = GameInput.current_device_input(InputSlot.pad(6))
	assert_eq(pad.kind, Defs.InputSlotKind.KEYBOARD_LEFT, "a partner on the same pad: the player takes the keys")


func test_a_rebuilt_slot_never_keeps_a_stale_key() -> void:
	# Godot's Input keeps an action's pressed state by name: P2 holds Num 4, leaves (his actions are erased), lets go
	# while they do not exist, and joins again - his rebuilt action must not read the old key as held.
	_classic_party()
	var left: StringName = GameInput.slot_action(1, Defs.ACT_LEFT)
	_send(_key(KEY_KP_4, KEY_LEFT))
	assert_true(Input.is_action_pressed(left))
	GameInput.assign_slot(1, null)
	_send(_key(KEY_KP_4, KEY_LEFT, false))
	GameInput.assign_slot(1, InputSlot.keyboard(Defs.InputSlotKind.KEYBOARD_RIGHT))
	assert_false(Input.is_action_pressed(left), "the rebuilt action starts released")
	Sim.step(1)
	assert_eq(GameInput.get_flags(1), 0, "P2 stands still")
	_send(_key(KEY_KP_4, KEY_LEFT))
	GameInput.set_keyboard_layout(InputSlot.KeyboardLayout.CLASSIC)
	Settings.reset_slot_bindings(1)
	assert_false(Input.is_action_pressed(left), "a rebuild for a settings change releases too (press again to walk)")
