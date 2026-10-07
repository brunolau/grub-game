extends Node
## Autoload `GameInput`: turns keyboard, gamepad and touch into the six level-triggered flags of PHYSICS.md 4.1.
##
## CONTRACT FILE (docs/ARCHITECTURE.md 3.7). Owner: core. Public members are frozen.
##
## Rules (PHYSICS.md 15.4):
##  - Gameplay reads ONLY `GameInput.flags` (bit mask of Defs.IN_*), sampled once per tick by Sim. Gameplay code
##    never calls Input.* and never handles InputEvents.
##  - Presses are latched: a button pressed and released between two ticks still counts as held for one tick.
##  - Everything is "held", nothing is edge-triggered (holding jump re-jumps, holding attack re-swings).
##  - UP flag = `jump` action, or `move_up` (always when Settings "controls/up_jumps" is true, otherwise only
##    together with `attack`, so that Up + attack still gives the high strike).
##  - Touch buttons call [method set_touch]; they feed the same actions as keys and pads. Touch state and
##    latches are dropped when the application loses focus or goes to the background.
##  - Tests and the autoplay harness replace the device input with [method set_scripted].
##
## Player slots (2.0, docs/expansion/TECH_AUDIT.md 4.3, PLAN.md P0.5). Every one of the Defs.MAX_PLAYERS slots has
## its flags (`slot_flags`, read with [method get_flags]), latches, touch buttons and an optional script; `flags`
## IS slot 0 (P1). Where a slot's input comes from is its [InputSlot] (`slots`, [method assign_slot]):
##  - single-player: slot 0 has kind ALL_DEVICES and is sampled exactly as in 1.0 (the unprefixed actions of every
##    device), the other slots are NONE and read 0; no action is generated;
##  - a party: each keyboard half or pad slot (slot 0 included) reads its own generated actions `p1_*`..`p4_*`
##    ([method slot_action]), built from Settings' binding profile of the slot; a touch slot reads its overlay
##    ([method set_touch_slot]); a bot slot calls its source; any slot can be scripted ([method set_scripted_slot]).
## [method sample] builds slot 0 first, then slots 1..3. The Swap action (`swap`) is sampled into Defs.IN_SWAP like
## any other action (route key `S`); a Book I solo hero ignores it (DESIGN.md C.1 rule 7).

## The player switched between keyboard, gamepad and touch: update button glyphs, show / hide the touch overlay.
signal device_changed(device: int)
## The device family (Defs.Device) of player slot `slot` changed (slot 0 in single-player follows `device`).
signal slot_device_changed(slot: int, device: int)

## InputMap action -> flag bit for the simple one-to-one actions.
const _ACTION_BITS: Dictionary = {
	&"move_left": Defs.IN_LEFT,
	&"move_right": Defs.IN_RIGHT,
	&"move_down": Defs.IN_DOWN,
	&"attack": Defs.IN_FIRE,
	&"look": Defs.IN_LOOK,
	&"swap": Defs.IN_SWAP,
}
## Dead zone of the generated per-slot actions (the project's actions use 0.5, PHYSICS.md 15.4).
const SLOT_ACTION_DEADZONE: float = 0.5

## Flags of the current tick (bit mask of Defs.IN_FIRE, IN_DOWN, IN_UP, IN_LEFT, IN_RIGHT, IN_LOOK, IN_SWAP).
## Slot 0 (P1): the same value as get_flags(0), always.
var flags: int:
	get:
		return slot_flags[0]
	set(value):
		slot_flags[0] = value
## Flags of the previous tick (for cosmetic edge detection only, e.g. a jump sound). Slot 0.
var prev_flags: int:
	get:
		return prev_slot_flags[0]
	set(value):
		prev_slot_flags[0] = value
## Last used device family (Defs.Device).
var device: int = Defs.Device.KEYBOARD
## When false every flag reads as released (cutscenes, transitions). Latches are discarded.
var enabled: bool = true

## Flags of the current tick per player slot (Defs.MAX_PLAYERS entries; slot 0 = `flags`).
var slot_flags: PackedInt32Array = _zeros()
## Flags of the previous tick per player slot (cosmetic edge detection).
var prev_slot_flags: PackedInt32Array = _zeros()
## Last used device family per player slot (Defs.Device; -1 = none yet).
var slot_devices: PackedInt32Array = _filled(-1)
## Where each slot's input comes from (Defs.MAX_PLAYERS entries, never null): change it with [method assign_slot].
var slots: Array[InputSlot] = _single_player_slots()

var _slot_latched: PackedInt32Array = _zeros()
var _slot_touch: PackedInt32Array = _zeros()
var _slot_scripted: Array[Callable] = _no_sources()
var _slot_scripted_active: PackedByteArray = _flags_off()
# Generated action names per slot: [slot][game action] -> &"pN_<action>".
var _slot_action_names: Array[Dictionary] = _action_names()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.has_feature("mobile") and DisplayServer.is_touchscreen_available():
		device = Defs.Device.TOUCH
	slot_devices[0] = device
	# Reloading or resetting bindings rebuilds the InputMap from the project: the generated actions follow.
	Settings.changed.connect(_on_setting_changed)


func _notification(what: int) -> void:
	# A finger or key that was down when the app lost the foreground never reports its release.
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		clear_touch()
		for slot: int in Defs.MAX_PLAYERS:
			_slot_latched[slot] = 0


func _input(event: InputEvent) -> void:
	_track_device(event)
	if event.is_echo():
		return
	if slots[0].kind == Defs.InputSlotKind.ALL_DEVICES:
		# Latch presses so that taps shorter than one tick (41 ms) are not lost.
		for action: StringName in _ACTION_BITS:
			if event.is_action_pressed(action):
				_slot_latched[0] |= int(_ACTION_BITS[action])
		if event.is_action_pressed(Defs.ACT_JUMP):
			_slot_latched[0] |= Defs.IN_UP
		if event.is_action_pressed(Defs.ACT_UP) and _up_jumps():
			_slot_latched[0] |= Defs.IN_UP
	for slot: int in Defs.MAX_PLAYERS:
		if slots[slot].uses_generated_actions():
			_latch_slot(slot, event)


## Sample the flags for the tick that is about to run. Called by Sim only. Slot 0 first (the 1.0 value), then the
## other slots; returns slot 0's flags.
func sample() -> int:
	for slot: int in Defs.MAX_PLAYERS:
		prev_slot_flags[slot] = slot_flags[slot]
		slot_flags[slot] = _sample_slot(slot)
		_slot_latched[slot] = 0
	return slot_flags[0]


## True when every bit of `mask` is set this tick.
func is_held(mask: int) -> bool:
	return (flags & mask) == mask


## True when any bit of `mask` went from released to held this tick (cosmetic use only).
func just_pressed(mask: int) -> bool:
	return (flags & mask) != 0 and (prev_flags & mask) == 0


## Touch overlay entry point: press or release one of the game actions (Defs.ACT_*). Also latches the press.
## (Slot 0; see [method set_touch_slot].)
func set_touch(action: StringName, pressed: bool) -> void:
	set_touch_slot(0, action, pressed)


## Release every touch button (overlay hidden, app lost focus), of every slot.
func clear_touch() -> void:
	for slot: int in Defs.MAX_PLAYERS:
		_slot_touch[slot] = 0


## Replace device input by a script: `source` is called once per tick as `source.call(tick: int) -> int` and
## returns the flags for that tick. Used by tests, golden traces and the autoplay harness. (Slot 0; see
## [method set_scripted_slot].)
func set_scripted(source: Callable) -> void:
	set_scripted_slot(0, source)


## Return to device input (every slot; see [method clear_scripted_slot]).
func clear_scripted() -> void:
	for slot: int in Defs.MAX_PLAYERS:
		clear_scripted_slot(slot)


## True while a script drives the input (of any slot; in single-player: slot 0).
func is_scripted() -> bool:
	return _slot_scripted_active.has(1)


## Convert a key string of the reference traces ("L", "R", "U", "D", "F", plus "K" for look and "S" for swap) to
## flags. Example: keys_to_flags("RU") == Defs.IN_RIGHT | Defs.IN_UP.
func keys_to_flags(keys: String) -> int:
	var result: int = 0
	for i: int in keys.length():
		match keys[i]:
			"L":
				result |= Defs.IN_LEFT
			"R":
				result |= Defs.IN_RIGHT
			"U":
				result |= Defs.IN_UP
			"D":
				result |= Defs.IN_DOWN
			"F":
				result |= Defs.IN_FIRE
			"K":
				result |= Defs.IN_LOOK
			"S":
				result |= Defs.IN_SWAP
	return result


## Expand a run-length input script ([[ticks, "KEYS"], ...], the format of PHYSICS_REFERENCE.json traces) into
## one flags value per tick.
func expand_runs(runs: Array) -> PackedInt32Array:
	var result: PackedInt32Array = PackedInt32Array()
	for run: Variant in runs:
		var count: int = int(run[0])
		var value: int = keys_to_flags(str(run[1]))
		for i: int in count:
			result.append(value)
	return result


## Name of the glyph set for the current device: "keyboard", "gamepad" or "touch".
func get_glyph_set() -> String:
	match device:
		Defs.Device.GAMEPAD:
			return "gamepad"
		Defs.Device.TOUCH:
			return "touch"
		_:
			return "keyboard"


## True when the touch overlay should be visible.
func wants_touch_controls() -> bool:
	return device == Defs.Device.TOUCH or Settings.get_bool("controls/touch_always")


## Short rumble on the active gamepad / phone, if enabled in the settings.
func vibrate(duration_ms: int, strength: float = 0.5) -> void:
	if not Settings.get_bool("controls/vibration"):
		return
	if device == Defs.Device.GAMEPAD:
		for pad: int in Input.get_connected_joypads():
			Input.start_joy_vibration(pad, strength, strength, float(duration_ms) / 1000.0)
	elif device == Defs.Device.TOUCH:
		Input.vibrate_handheld(duration_ms)


# =================================================================================================================
# 2.0: player slots
# =================================================================================================================

## Flags of player slot `slot` this tick (get_flags(0) == flags); 0 for a slot that does not exist.
func get_flags(slot: int) -> int:
	if slot < 0 or slot >= Defs.MAX_PLAYERS:
		return 0
	return slot_flags[slot]


## Flags of player slot `slot` in the previous tick (cosmetic edge detection).
func get_prev_flags(slot: int) -> int:
	if slot < 0 or slot >= Defs.MAX_PLAYERS:
		return 0
	return prev_slot_flags[slot]


## True when every bit of `mask` is set for slot `slot` this tick.
func is_slot_held(slot: int, mask: int) -> bool:
	return (get_flags(slot) & mask) == mask


## True when any bit of `mask` went from released to held for slot `slot` this tick (cosmetic use only).
func slot_just_pressed(slot: int, mask: int) -> bool:
	return (get_flags(slot) & mask) != 0 and (get_prev_flags(slot) & mask) == 0


## The input of player slot `slot` (never null).
func get_slot(slot: int) -> InputSlot:
	if slot < 0 or slot >= Defs.MAX_PLAYERS:
		push_error("GameInput.get_slot: no player slot %d" % slot)
		return InputSlot.new()
	return slots[slot]


## Give player slot `slot` its input (a copy of `input_slot` is kept; null = NONE, the slot reads 0). Builds or
## removes the slot's generated actions and drops its latches, touch buttons and flags. A script set with
## [method set_scripted_slot] stays in force.
func assign_slot(slot: int, input_slot: InputSlot) -> void:
	if slot < 0 or slot >= Defs.MAX_PLAYERS:
		push_error("GameInput.assign_slot: no player slot %d" % slot)
		return
	slots[slot] = input_slot.duplicate_slot() if input_slot != null else InputSlot.new()
	_slot_latched[slot] = 0
	_slot_touch[slot] = 0
	slot_flags[slot] = 0
	prev_slot_flags[slot] = 0
	slot_devices[slot] = slots[slot].device_family()
	_build_slot_actions(slot)


## Back to single-player: slot 0 reads every device (ALL_DEVICES), the other slots are free, every generated
## action is removed. Scripts stay in force (see [method clear_scripted]).
func reset_slots() -> void:
	assign_slot(0, InputSlot.all_devices())
	for slot: int in range(1, Defs.MAX_PLAYERS):
		assign_slot(slot, null)


## True while the slots are set up for a party (slot 0 no longer reads every device).
func is_party_input() -> bool:
	return slots[0].kind != Defs.InputSlotKind.ALL_DEVICES


## Name of the generated InputMap action of game action `action` (Defs.GAME_ACTIONS) for player slot `slot`:
## slot_action(1, &"jump") == &"p2_jump".
static func slot_action(slot: int, action: StringName) -> StringName:
	return InputSlot.action_name(slot, action)


## Touch overlay of player slot `slot`: press or release one of the game actions (Defs.ACT_*, Defs.ACT_SWAP). Also
## latches the press.
func set_touch_slot(slot: int, action: StringName, pressed: bool) -> void:
	var bit: int = 0
	if _ACTION_BITS.has(action):
		bit = int(_ACTION_BITS[action])
	elif action == Defs.ACT_JUMP or action == Defs.ACT_UP:
		bit = Defs.IN_UP
	else:
		push_error("GameInput.set_touch: '%s' is not a game action" % action)
		return
	if slot < 0 or slot >= Defs.MAX_PLAYERS:
		push_error("GameInput.set_touch_slot: no player slot %d" % slot)
		return
	if pressed:
		_slot_touch[slot] |= bit
		_slot_latched[slot] |= bit
		_set_device(Defs.Device.TOUCH)
		_set_slot_device(slot, Defs.Device.TOUCH)
	else:
		_slot_touch[slot] &= ~bit


## Replace the input of player slot `slot` by a script: `source.call(tick: int) -> int` once per tick (any slot
## kind, also NONE). Used by tests, co-op routes, the autoplay harness.
func set_scripted_slot(slot: int, source: Callable) -> void:
	if slot < 0 or slot >= Defs.MAX_PLAYERS:
		push_error("GameInput.set_scripted_slot: no player slot %d" % slot)
		return
	_slot_scripted[slot] = source
	_slot_scripted_active[slot] = 1
	_slot_latched[slot] = 0


## Return player slot `slot` to its device input; its flags read 0 until the next sample.
func clear_scripted_slot(slot: int) -> void:
	if slot < 0 or slot >= Defs.MAX_PLAYERS:
		return
	_slot_scripted[slot] = Callable()
	_slot_scripted_active[slot] = 0
	_slot_latched[slot] = 0
	slot_flags[slot] = 0
	prev_slot_flags[slot] = 0


## True while a script drives player slot `slot`.
func is_slot_scripted(slot: int) -> bool:
	return slot >= 0 and slot < Defs.MAX_PLAYERS and _slot_scripted_active[slot] == 1


## The player slot an input event belongs to: 0 for every event while slot 0 reads every device
## (single-player); otherwise the first slot whose generated actions hold the event (a pad event only for the slot
## of its pad); -1 when no slot reads it. For the pause owner and the join screen.
func event_slot(event: InputEvent) -> int:
	if slots[0].kind == Defs.InputSlotKind.ALL_DEVICES:
		return 0
	for slot: int in Defs.MAX_PLAYERS:
		if not slots[slot].uses_generated_actions():
			continue
		var names: Dictionary = _slot_action_names[slot]
		for action: StringName in Defs.GAME_ACTIONS:
			var generated: StringName = names[action]
			if InputMap.has_action(generated) and event.is_action(generated):
				return slot
	return -1


## Short rumble on the pad of player slot `slot` only (a PAD slot), on the phone (a TOUCH slot), or as
## [method vibrate] for the single-player slot; if enabled in the settings.
func vibrate_slot(slot: int, duration_ms: int, strength: float = 0.5) -> void:
	if not Settings.get_bool("controls/vibration") or slot < 0 or slot >= Defs.MAX_PLAYERS:
		return
	var input_slot: InputSlot = slots[slot]
	match input_slot.kind:
		Defs.InputSlotKind.ALL_DEVICES:
			vibrate(duration_ms, strength)
		Defs.InputSlotKind.PAD:
			if input_slot.device_id >= 0:
				Input.start_joy_vibration(input_slot.device_id, strength, strength, float(duration_ms) / 1000.0)
		Defs.InputSlotKind.TOUCH:
			Input.vibrate_handheld(duration_ms)


func _up_jumps() -> bool:
	return Settings.get_bool("controls/up_jumps")


func _sample_slot(slot: int) -> int:
	if _slot_scripted_active[slot] == 1:
		var source: Callable = _slot_scripted[slot]
		return int(source.call(Sim.tick)) if source.is_valid() else 0
	if not enabled:
		return 0
	var input_slot: InputSlot = slots[slot]
	match input_slot.kind:
		Defs.InputSlotKind.ALL_DEVICES:
			return _poll() | _slot_latched[slot] | _slot_touch[slot]
		Defs.InputSlotKind.KEYBOARD_LEFT, Defs.InputSlotKind.KEYBOARD_RIGHT, Defs.InputSlotKind.KEYBOARD_FULL, \
				Defs.InputSlotKind.PAD:
			return _poll_slot(slot) | _slot_latched[slot] | _slot_touch[slot]
		Defs.InputSlotKind.TOUCH:
			return _slot_latched[slot] | _slot_touch[slot]
		Defs.InputSlotKind.BOT:
			return int(input_slot.source.call(Sim.tick)) if input_slot.source.is_valid() else 0
	return 0


func _poll() -> int:
	var result: int = 0
	for action: StringName in _ACTION_BITS:
		if Input.is_action_pressed(action):
			result |= int(_ACTION_BITS[action])
	if Input.is_action_pressed(Defs.ACT_JUMP):
		result |= Defs.IN_UP
	if Input.is_action_pressed(Defs.ACT_UP) and (_up_jumps() or (result & Defs.IN_FIRE) != 0):
		result |= Defs.IN_UP
	return result


# The 1.0 poll on the generated actions of one slot.
func _poll_slot(slot: int) -> int:
	var names: Dictionary = _slot_action_names[slot]
	if not InputMap.has_action(names[Defs.ACT_JUMP]):
		return 0
	var result: int = 0
	for action: StringName in _ACTION_BITS:
		if Input.is_action_pressed(names[action]):
			result |= int(_ACTION_BITS[action])
	if Input.is_action_pressed(names[Defs.ACT_JUMP]):
		result |= Defs.IN_UP
	if Input.is_action_pressed(names[Defs.ACT_UP]) and (_up_jumps() or (result & Defs.IN_FIRE) != 0):
		result |= Defs.IN_UP
	return result


# The 1.0 latch on the generated actions of one slot; a press also marks the slot's device family.
func _latch_slot(slot: int, event: InputEvent) -> void:
	var names: Dictionary = _slot_action_names[slot]
	if not InputMap.has_action(names[Defs.ACT_JUMP]):
		return
	var latched: int = 0
	var hit: bool = false
	for action: StringName in _ACTION_BITS:
		if event.is_action_pressed(names[action]):
			latched |= int(_ACTION_BITS[action])
			hit = true
	if event.is_action_pressed(names[Defs.ACT_JUMP]):
		latched |= Defs.IN_UP
		hit = true
	if event.is_action_pressed(names[Defs.ACT_UP]):
		hit = true
		if _up_jumps():
			latched |= Defs.IN_UP
	_slot_latched[slot] |= latched
	if hit or event.is_action_pressed(names[Defs.ACT_PAUSE]):
		_set_slot_device(slot, slots[slot].device_family())


# (Re)build the generated actions of a slot from its binding profile; remove them when the slot reads none.
func _build_slot_actions(slot: int) -> void:
	var names: Dictionary = _slot_action_names[slot]
	for action: StringName in Defs.GAME_ACTIONS:
		if InputMap.has_action(names[action]):
			InputMap.erase_action(names[action])
	var input_slot: InputSlot = slots[slot]
	if not input_slot.uses_generated_actions():
		return
	var family: int = input_slot.device_family()
	for action: StringName in Defs.GAME_ACTIONS:
		var generated: StringName = names[action]
		InputMap.add_action(generated, SLOT_ACTION_DEADZONE)
		var events: Array[InputEvent] = []
		if input_slot.kind == Defs.InputSlotKind.KEYBOARD_FULL:
			events = Settings.get_bindings(action, Defs.Device.KEYBOARD)
		else:
			events = Settings.get_slot_bindings(slot, action, family, input_slot.keyboard_half())
		for event: InputEvent in events:
			var bound: InputEvent = event.duplicate() as InputEvent
			bound.device = input_slot.device_id if input_slot.kind == Defs.InputSlotKind.PAD else -1
			InputMap.action_add_event(generated, bound)


func _on_setting_changed(key: String, _value: Variant) -> void:
	if key != Settings.BINDINGS_KEY and key != Settings.PARTY_KEYBOARD_KEY:
		return
	for slot: int in Defs.MAX_PLAYERS:
		if slots[slot].uses_generated_actions():
			_build_slot_actions(slot)


func _track_device(event: InputEvent) -> void:
	if event is InputEventKey:
		_set_device(Defs.Device.KEYBOARD)
	elif event is InputEventJoypadButton:
		_set_device(Defs.Device.GAMEPAD)
	elif event is InputEventJoypadMotion:
		var motion: InputEventJoypadMotion = event
		if absf(motion.axis_value) > 0.5:
			_set_device(Defs.Device.GAMEPAD)
	elif event is InputEventScreenTouch or event is InputEventScreenDrag:
		_set_device(Defs.Device.TOUCH)


func _set_device(new_device: int) -> void:
	if device == new_device:
		return
	device = new_device
	device_changed.emit(device)
	if slots[0].kind == Defs.InputSlotKind.ALL_DEVICES:
		_set_slot_device(0, new_device)


func _set_slot_device(slot: int, new_device: int) -> void:
	if new_device < 0 or slot_devices[slot] == new_device:
		return
	slot_devices[slot] = new_device
	slot_device_changed.emit(slot, new_device)


static func _zeros() -> PackedInt32Array:
	return _filled(0)


static func _filled(value: int) -> PackedInt32Array:
	var result: PackedInt32Array = PackedInt32Array()
	result.resize(Defs.MAX_PLAYERS)
	result.fill(value)
	return result


static func _flags_off() -> PackedByteArray:
	var result: PackedByteArray = PackedByteArray()
	result.resize(Defs.MAX_PLAYERS)
	result.fill(0)
	return result


static func _no_sources() -> Array[Callable]:
	var result: Array[Callable] = []
	for slot: int in Defs.MAX_PLAYERS:
		result.append(Callable())
	return result


static func _single_player_slots() -> Array[InputSlot]:
	var result: Array[InputSlot] = [InputSlot.all_devices()]
	for slot: int in range(1, Defs.MAX_PLAYERS):
		result.append(InputSlot.new())
	return result


static func _action_names() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for slot: int in Defs.MAX_PLAYERS:
		var names: Dictionary = {}
		for action: StringName in Defs.GAME_ACTIONS:
			names[action] = slot_action(slot, action)
		result.append(names)
	return result
