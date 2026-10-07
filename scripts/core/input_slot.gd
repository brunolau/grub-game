class_name InputSlot
extends RefCounted
## Where the input of one player slot comes from (docs/expansion/TECH_AUDIT.md 4.3, DESIGN.md D.11 / E.9,
## PLAN.md P0.5), and the default bindings of the party keyboard layouts.
##
## CONTRACT FILE. Owner: core. `GameInput.slots` holds one per player slot (Defs.MAX_PLAYERS). Single-player is
## slot 0 with kind ALL_DEVICES: the unprefixed actions of project.godot, every device, exactly 1.0; no action is
## generated. A slot of kind KEYBOARD_LEFT / KEYBOARD_RIGHT / KEYBOARD_FULL / PAD reads its own generated actions
## `p1_*`..`p4_*` (GameInput.slot_action), built from the slot's binding profile (Settings `[bindings_p1]`..
## `[bindings_p4]`, defaults below): keys bound by physical position, pad events bound to `device_id` only. TOUCH is
## fed by its overlay (GameInput.set_touch_slot), BOT by `source`, SCRIPT (and any slot, as an override) by
## GameInput.set_scripted_slot. In a party slot 0 also uses its own `p1_*` actions, so the keyboard halves never
## feed two heroes (DESIGN.md D.11).

## The three shared-keyboard layouts of DESIGN.md D.11 (Settings "controls/party_keyboard").
enum KeyboardLayout {
	CLASSIC = 0,    ## WASD + numpad: the default for versus on one keyboard, offered first in co-op
	TWO_HANDS = 1,  ## keyboards without a numpad (laptops)
	ONE_HAND = 2,   ## the original's Up-jumps scheme
}
## Setting values of the layouts, by KeyboardLayout value.
const KEYBOARD_LAYOUT_NAMES: Array[String] = ["classic", "two_hands", "one_hand"]

# Physical keys per action and layout [CLASSIC, TWO_HANDS, ONE_HAND] (DESIGN.md D.11). "Left + Right together is
# Look in every layout" is the hero's rule; Up jumps as the setting "controls/up_jumps" says, except ONE_HAND, the
# Up-jumps scheme, where the up key is the jump key. Bindings keep no key side (the Settings token "key:<code>"):
# KEY_SHIFT / KEY_CTRL are either Shift / Ctrl, which is safe because no layout gives both sides of one to two
# players (CLASSIC: P1 Left Shift; ONE_HAND: P2 Right Ctrl and Right Shift). The numpad is bound by physical key,
# so NumLock does not change it.
const _LEFT_KEYS: Dictionary = {
	&"move_left": [[KEY_A], [KEY_A], [KEY_A]],
	&"move_right": [[KEY_D], [KEY_D], [KEY_D]],
	&"move_up": [[KEY_W], [KEY_W], []],
	&"move_down": [[KEY_S], [KEY_S], [KEY_S]],
	&"jump": [[KEY_SPACE], [KEY_G], [KEY_W]],
	&"attack": [[KEY_SHIFT], [KEY_F], [KEY_SPACE]],
	&"look": [[KEY_Q], [KEY_R], [KEY_Q]],
	&"swap": [[KEY_E], [KEY_T], [KEY_E]],
	&"pause": [[], [], []],
}
const _RIGHT_KEYS: Dictionary = {
	&"move_left": [[KEY_KP_4], [KEY_LEFT], [KEY_LEFT]],
	&"move_right": [[KEY_KP_6], [KEY_RIGHT], [KEY_RIGHT]],
	&"move_up": [[KEY_KP_8], [KEY_UP], []],
	&"move_down": [[KEY_KP_5], [KEY_DOWN], [KEY_DOWN]],
	&"jump": [[KEY_KP_0], [KEY_SLASH], [KEY_UP]],
	&"attack": [[KEY_KP_ENTER], [KEY_PERIOD], [KEY_CTRL]],
	&"look": [[KEY_KP_PERIOD], [KEY_COMMA], [KEY_KP_0]],
	&"swap": [[KEY_KP_ADD], [KEY_SEMICOLON], [KEY_SHIFT]],
	&"pause": [[], [], []],
}

## Kind of input (Defs.InputSlotKind).
var kind: int = Defs.InputSlotKind.NONE
## PAD: the joypad device id (Input.get_connected_joypads()); -1 otherwise.
var device_id: int = -1
## TOUCH: the screen region of this player's overlay (fractions of the view, 0..1); empty = the whole screen.
var region: Rect2 = Rect2()
## BOT: the flags source, called once per tick as `source.call(tick: int) -> int` (deterministic: it reads only
## the state at the end of the previous tick and never draws from Sim.rng, TECH_AUDIT.md 2 rule 3).
var source: Callable = Callable()


## A slot of `p_kind` (Defs.InputSlotKind).
func _init(p_kind: int = Defs.InputSlotKind.NONE) -> void:
	kind = p_kind


## Single-player slot 0: every device through the unprefixed actions (the 1.0 path).
static func all_devices() -> InputSlot:
	return InputSlot.new(Defs.InputSlotKind.ALL_DEVICES)


## A keyboard half (KEYBOARD_LEFT / KEYBOARD_RIGHT: its default keys come from the party layout, Settings
## "controls/party_keyboard") or the whole keyboard (KEYBOARD_FULL: the single-player keys).
static func keyboard(p_kind: int) -> InputSlot:
	return InputSlot.new(p_kind)


## One gamepad by its device id.
static func pad(p_device_id: int) -> InputSlot:
	var slot: InputSlot = InputSlot.new(Defs.InputSlotKind.PAD)
	slot.device_id = p_device_id
	return slot


## A touch overlay in a screen region.
static func touch(p_region: Rect2 = Rect2()) -> InputSlot:
	var slot: InputSlot = InputSlot.new(Defs.InputSlotKind.TOUCH)
	slot.region = p_region
	return slot


## A bot fed by `p_source` (see [member source]).
static func bot(p_source: Callable) -> InputSlot:
	var slot: InputSlot = InputSlot.new(Defs.InputSlotKind.BOT)
	slot.source = p_source
	return slot


## True when the slot reads generated `pN_*` actions (keyboard kinds and PAD).
func uses_generated_actions() -> bool:
	return kind == Defs.InputSlotKind.KEYBOARD_LEFT or kind == Defs.InputSlotKind.KEYBOARD_RIGHT \
			or kind == Defs.InputSlotKind.KEYBOARD_FULL or kind == Defs.InputSlotKind.PAD


## The device family this slot reads for its generated actions: Defs.Device.KEYBOARD, GAMEPAD, TOUCH, or -1.
func device_family() -> int:
	match kind:
		Defs.InputSlotKind.KEYBOARD_LEFT, Defs.InputSlotKind.KEYBOARD_RIGHT, Defs.InputSlotKind.KEYBOARD_FULL:
			return Defs.Device.KEYBOARD
		Defs.InputSlotKind.PAD:
			return Defs.Device.GAMEPAD
		Defs.InputSlotKind.TOUCH:
			return Defs.Device.TOUCH
	return -1


## The keyboard half whose default keys this slot uses: Defs.InputSlotKind.KEYBOARD_LEFT / KEYBOARD_RIGHT /
## KEYBOARD_FULL, or NONE for a slot without keys.
func keyboard_half() -> int:
	match kind:
		Defs.InputSlotKind.KEYBOARD_LEFT, Defs.InputSlotKind.KEYBOARD_RIGHT, Defs.InputSlotKind.KEYBOARD_FULL:
			return kind
	return Defs.InputSlotKind.NONE


## Copy of this slot.
func duplicate_slot() -> InputSlot:
	var copy: InputSlot = InputSlot.new(kind)
	copy.device_id = device_id
	copy.region = region
	copy.source = source
	return copy


## Name of the generated InputMap action of game action `action` for player slot `slot`: "p<slot + 1>_<action>",
## e.g. action_name(1, &"jump") == &"p2_jump" (GameInput.slot_action).
static func action_name(slot: int, action: StringName) -> StringName:
	return StringName("p%d_%s" % [slot + 1, action])


## The KeyboardLayout of a setting value ("classic" ...); CLASSIC for an unknown value.
static func layout_from_name(layout_name: String) -> int:
	return maxi(KEYBOARD_LAYOUT_NAMES.find(layout_name), KeyboardLayout.CLASSIC)


## The keyboard half a player slot uses by default in a party (DESIGN.md D.11: P1 on the left cluster, P2 on the
## right; keyboards serve two players at most, so P3 and P4 have no keys by default).
static func default_half(slot: int) -> int:
	match slot:
		0:
			return Defs.InputSlotKind.KEYBOARD_LEFT
		1:
			return Defs.InputSlotKind.KEYBOARD_RIGHT
	return Defs.InputSlotKind.NONE


## Default physical keys of a game action (Defs.GAME_ACTIONS) for a keyboard half of a layout (DESIGN.md D.11).
## KEYBOARD_FULL: the single-player keys of project.godot (read from the project settings). Empty for an action
## the half leaves unbound (P2 has no pause key: Escape and P keep pausing for everyone).
static func default_keys(p_layout: int, half: int, action: StringName) -> Array[Key]:
	var result: Array[Key] = []
	if half == Defs.InputSlotKind.KEYBOARD_FULL:
		for event: InputEvent in project_events(action):
			var key: InputEventKey = event as InputEventKey
			if key != null:
				result.append(key.physical_keycode)
		return result
	var table: Dictionary = _LEFT_KEYS if half == Defs.InputSlotKind.KEYBOARD_LEFT else _RIGHT_KEYS
	if half != Defs.InputSlotKind.KEYBOARD_LEFT and half != Defs.InputSlotKind.KEYBOARD_RIGHT:
		return result
	var per_layout: Array = table.get(action, [])
	if p_layout >= 0 and p_layout < per_layout.size():
		for code: Variant in per_layout[p_layout]:
			result.append(code as Key)
	return result


## Default gamepad events of a game action, the solo pad layout for every slot (DESIGN.md D.11: A jump, X / B
## strike, Y / RB look, LB swap, Start pause, d-pad and left stick move), device -1 (GameInput binds them to the
## slot's pad).
static func default_pad_events(action: StringName) -> Array[InputEvent]:
	var result: Array[InputEvent] = []
	for event: InputEvent in project_events(action):
		if event is InputEventJoypadButton or event is InputEventJoypadMotion:
			result.append(event)
	return result


## Default events (keys of the half, then the pad events) of a game action for a binding profile.
static func default_events(p_layout: int, half: int, action: StringName) -> Array[InputEvent]:
	var result: Array[InputEvent] = []
	for code: Key in default_keys(p_layout, half, action):
		var key: InputEventKey = InputEventKey.new()
		key.device = -1
		key.physical_keycode = code
		result.append(key)
	result.append_array(default_pad_events(action))
	return result


## The events project.godot gives a game action (what Settings.reset_binding restores).
static func project_events(action: StringName) -> Array[InputEvent]:
	var result: Array[InputEvent] = []
	var entry: Variant = ProjectSettings.get_setting("input/" + String(action), {})
	if entry is Dictionary:
		for item: Variant in (entry as Dictionary).get("events", []):
			if item is InputEvent:
				result.append(item)
	return result
