extends RouteTestCase
## The recorder of `--record` on real device input (owner: integration; docs/expansion/PLAN.md P1.3 "recorder proven
## (two pads -> tick-exact replay)", LEVEL_DESIGN.md 15.9 "two people play the stage with pads ... and the file is a
## tick-exact proof").
##
## No script drives the heroes here: every player slot reads its own device (two pads, or the two halves of one
## keyboard in the classic layout), and the test presses and releases the buttons through Input, tick by tick, as two
## players would. The recorder (scripts/core/dev/input_recorder.gd) writes the stage; its file must hold exactly the
## flags each slot sampled, and replayed through the bench (the route tests' replay) it must give the same per-tick
## digests as the live run. Real pads on real hardware stay a human check (PLAN.md P4.3).

const BOOK2_DIR: String = "res://tests/fixtures/book2_routes/"
## The keys of the two players come from this two-stream route (both heroes club, jump and walk), its first
## DRIVE_TICKS ticks (the stage still runs: the recording is written by flush()).
const DRIVE: String = "test_integration_book2_coop.inputs"
const DRIVE_TICKS: int = 180
## The co-op file of the Book II test bed (a co-op run plays it).
const LEVEL: StringName = &"test_integration_book2_coop"
const OUT_DIR: String = "res://build/test_integration_recorder/"
## Pad buttons per flag (the solo pad layout of project.godot: d-pad moves, A jumps, X strikes, Y looks, LB swaps).
const PAD_BUTTONS: Array[Array] = [
	[Defs.IN_LEFT, JOY_BUTTON_DPAD_LEFT], [Defs.IN_RIGHT, JOY_BUTTON_DPAD_RIGHT], [Defs.IN_UP, JOY_BUTTON_A],
	[Defs.IN_DOWN, JOY_BUTTON_DPAD_DOWN], [Defs.IN_FIRE, JOY_BUTTON_X], [Defs.IN_LOOK, JOY_BUTTON_Y],
	[Defs.IN_SWAP, JOY_BUTTON_LEFT_SHOULDER],
]
## Physical keys per flag of the classic layout (DESIGN.md D.11): P1 W A S D + Space + Left Ctrl + E + Q, P2 the
## numpad 8 4 5 6 + Num 0 + Num Enter + Num + + Num . (jump is the jump key, so Up never needs Settings' up_jumps).
const CLASSIC_KEYS: Array[Array] = [
	[[Defs.IN_LEFT, KEY_A], [Defs.IN_RIGHT, KEY_D], [Defs.IN_UP, KEY_SPACE], [Defs.IN_DOWN, KEY_S],
		[Defs.IN_FIRE, KEY_CTRL], [Defs.IN_LOOK, KEY_Q], [Defs.IN_SWAP, KEY_E]],
	[[Defs.IN_LEFT, KEY_KP_4], [Defs.IN_RIGHT, KEY_KP_6], [Defs.IN_UP, KEY_KP_0], [Defs.IN_DOWN, KEY_KP_5],
		[Defs.IN_FIRE, KEY_KP_ENTER], [Defs.IN_LOOK, KEY_KP_PERIOD], [Defs.IN_SWAP, KEY_KP_ADD]],
]

var _held: Array[InputEvent] = []


func after_each() -> void:
	_release_all()
	super.after_each()
	GameInput.reset_slots()
	Settings.reset()


func test_two_pads_record_a_tick_exact_route() -> void:
	await _record_and_replay("pads", [InputSlot.pad(0), InputSlot.pad(1)])


func test_the_classic_keyboard_halves_record_a_tick_exact_route() -> void:
	await _record_and_replay("classic", [InputSlot.keyboard(Defs.InputSlotKind.KEYBOARD_LEFT),
		InputSlot.keyboard(Defs.InputSlotKind.KEYBOARD_RIGHT)])


## Play the DRIVE streams on the devices of `slots` (no script), record them, check the file, replay it.
func _record_and_replay(label: String, slots: Array[InputSlot]) -> void:
	Settings.set_value("controls/party_keyboard", "classic")
	var streams: Array[PackedInt32Array] = Autoplay.parse_inputs_multi(FileAccess.get_file_as_string(BOOK2_DIR + DRIVE))
	assert_eq(streams.size(), 2)
	for slot: int in streams.size():
		streams[slot] = streams[slot].slice(0, DRIVE_TICKS)
	var path: String = OUT_DIR + label + ".inputs"
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var recorder: Node = (load(Autoplay.RECORDER) as GDScript).new() as Node
	add_node(recorder)
	recorder.call("begin", path)
	# The run a two-stream header route starts in (sim_bench_runner._start_header_run / _enter), on the devices.
	Game.start_run(Defs.Difficulty.BEGINNER, Defs.GameMode.COOP, 2, Levels.get_book(LEVEL))
	for slot: int in slots.size():
		GameInput.assign_slot(slot, slots[slot])
	assert_true(GameInput.is_party_input())
	assert_false(GameInput.is_scripted(), "%s: no script drives any slot" % label)
	Sim.manual = true
	await _frames(1)
	Flow.start_level(LEVEL, Defs.Transition.NONE)
	await _frames(3)
	while Flow.busy:
		await _frames(1)
	var level: Level = Game.level as Level
	assert_not_null(level, "%s: the stage runs" % label)
	if level == null:
		return
	assert_eq(level.level_id, LEVEL)
	assert_eq(level.hero_count(), 2, "%s: two heroes" % label)
	level.set_view_size(Vector2i(Tuning.VIEW_W, Tuning.VIEW_H) * Tuning.ART_SCALE)
	for slot: int in Game.party:
		Game.runs[slot].set_belt(PlayerRun.BELT_EMPTY)
	var live: PackedStringArray = PackedStringArray()
	var sampled: Array[PackedInt32Array] = [PackedInt32Array(), PackedInt32Array()]
	var held: PackedInt32Array = PackedInt32Array([0, 0])
	for tick: int in streams[0].size():
		for slot: int in 2:
			_set_held(slots[slot], slot, held[slot], streams[slot][tick])
			held[slot] = streams[slot][tick]
		Input.flush_buffered_events()
		Sim.step(1)
		for slot: int in 2:
			sampled[slot].append(GameInput.get_flags(slot))
		if Game.level != level:
			break
		live.append(runner().digest_line(level))
	_release_all()
	for slot: int in 2:
		assert_true(sampled[slot] == streams[slot], "%s: P%d's device gave exactly the keys pressed, tick by tick" % [
			label, slot + 1])
	assert_eq(String(recorder.call("flush")), path, "%s: the stage was written" % label)
	recorder.free()  # the replay below is not recorded
	var text: String = FileAccess.get_file_as_string(path)
	var header: Dictionary = Autoplay.parse_route_header(text)
	assert_eq(header.get("errors", ["no header"]), PackedStringArray(), "%s: a valid header skeleton" % label)
	assert_eq([header.get("level"), header.get("modes"), header.get("players")], [String(LEVEL), [BEGINNER], 2])
	var recorded: Array[PackedInt32Array] = Autoplay.parse_inputs_multi(text)
	assert_eq(recorded.size(), 2, "%s: both slots" % label)
	assert_true(recorded.size() == 2 and recorded[0] == sampled[0] and recorded[1] == sampled[1],
			"%s: the file holds every slot's sampled flags, tick for tick" % label)
	clean_up_route()
	GameInput.reset_slots()
	# The recording replays through the bench to the live run's digests.
	var table: Dictionary = header_table(OUT_DIR, func(file: String, _spec: Dictionary) -> bool:
		return file == label + ".inputs")
	var replay: Dictionary = await runner().replay(label + ".inputs", BEGINNER, {"routes": table})
	var lines: PackedStringArray = PackedStringArray()
	for line: String in replay.get("lines", PackedStringArray()):
		if not line.begins_with("end "):
			lines.append(line)
	assert_eq(live.size(), streams[0].size(), "%s: the whole drive was played live" % label)
	assert_eq(runner().call("first_difference", live, lines), "", "%s: the recording replays tick-exact" % label)


## Press and release the device controls of `slot` that differ between `before` and `after` (flags).
func _set_held(input: InputSlot, slot: int, before: int, after: int) -> void:
	var controls: Array = PAD_BUTTONS if input.kind == Defs.InputSlotKind.PAD else CLASSIC_KEYS[slot]
	for pair: Array in controls:
		var bit: int = int(pair[0])
		if (before & bit) == (after & bit):
			continue
		var pressed: bool = (after & bit) != 0
		var event: InputEvent = null
		if input.kind == Defs.InputSlotKind.PAD:
			var button: InputEventJoypadButton = InputEventJoypadButton.new()
			button.device = input.device_id
			button.button_index = int(pair[1]) as JoyButton
			button.pressed = pressed
			button.pressure = 1.0 if pressed else 0.0
			event = button
		else:
			var key: InputEventKey = InputEventKey.new()
			key.physical_keycode = int(pair[1]) as Key
			key.keycode = int(pair[1]) as Key
			key.pressed = pressed
			event = key
		Input.parse_input_event(event)
		if pressed:
			_held.append(event)
		else:
			for i: int in range(_held.size() - 1, -1, -1):
				if _same_control(_held[i], event):
					_held.remove_at(i)


func _same_control(a: InputEvent, b: InputEvent) -> bool:
	if a is InputEventKey and b is InputEventKey:
		return (a as InputEventKey).physical_keycode == (b as InputEventKey).physical_keycode
	if a is InputEventJoypadButton and b is InputEventJoypadButton:
		return a.device == b.device and (a as InputEventJoypadButton).button_index == (b as InputEventJoypadButton).button_index
	return false


func _release_all() -> void:
	for event: InputEvent in _held:
		var release: InputEvent = event.duplicate() as InputEvent
		if release is InputEventKey:
			(release as InputEventKey).pressed = false
		elif release is InputEventJoypadButton:
			(release as InputEventJoypadButton).pressed = false
		Input.parse_input_event(release)
	Input.flush_buffered_events()
	_held.clear()


func _frames(count: int) -> void:
	for i: int in count:
		await get_tree().process_frame
