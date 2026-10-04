class_name UiGlyphs
extends RefCounted
## Names of the physical inputs behind an action, per device family (docs/ARCHITECTURE.md 8.6: input-glyph
## switching). Owner: ui.
##
## Prompts ask for the glyph of an action in the current glyph set (`GameInput.get_glyph_set()`): the key cap text
## for the keyboard, the button name for a gamepad. Touch has no glyphs: prompts become tappable buttons instead.

const SET_KEYBOARD: String = "keyboard"
const SET_GAMEPAD: String = "gamepad"
const SET_TOUCH: String = "touch"

## Short key cap texts for keys whose engine name is long.
const KEY_NAMES: Dictionary = {
	KEY_ESCAPE: "ESC",
	KEY_ENTER: "ENTER",
	KEY_KP_ENTER: "ENTER",
	KEY_SPACE: "SPACE",
	KEY_BACKSPACE: "BKSP",
	KEY_TAB: "TAB",
	KEY_SHIFT: "SHIFT",
	KEY_CTRL: "CTRL",
	KEY_ALT: "ALT",
	KEY_UP: "UP",
	KEY_DOWN: "DOWN",
	KEY_LEFT: "LEFT",
	KEY_RIGHT: "RIGHT",
	KEY_DELETE: "DEL",
	KEY_INSERT: "INS",
	KEY_PAGEUP: "PGUP",
	KEY_PAGEDOWN: "PGDN",
	KEY_KP_5: "KP 5",
}

## Gamepad button names in the Xbox layout (the engine's own button order).
const PAD_BUTTON_NAMES: Dictionary = {
	JOY_BUTTON_A: "A",
	JOY_BUTTON_B: "B",
	JOY_BUTTON_X: "X",
	JOY_BUTTON_Y: "Y",
	JOY_BUTTON_BACK: "BACK",
	JOY_BUTTON_GUIDE: "HOME",
	JOY_BUTTON_START: "START",
	JOY_BUTTON_LEFT_STICK: "L3",
	JOY_BUTTON_RIGHT_STICK: "R3",
	JOY_BUTTON_LEFT_SHOULDER: "LB",
	JOY_BUTTON_RIGHT_SHOULDER: "RB",
	JOY_BUTTON_DPAD_UP: "D-UP",
	JOY_BUTTON_DPAD_DOWN: "D-DOWN",
	JOY_BUTTON_DPAD_LEFT: "D-LEFT",
	JOY_BUTTON_DPAD_RIGHT: "D-RIGHT",
}

## Face-button colours of the Xbox layout.
const PAD_BUTTON_COLORS: Dictionary = {
	JOY_BUTTON_A: Color("7bd148"),
	JOY_BUTTON_B: Color("ff6b5a"),
	JOY_BUTTON_X: Color("5fb4f0"),
	JOY_BUTTON_Y: Color("ffd75e"),
}


## True when `event` belongs to the device family of `glyph_set`.
static func event_in_set(event: InputEvent, glyph_set: String) -> bool:
	if glyph_set == SET_GAMEPAD:
		return event is InputEventJoypadButton or event is InputEventJoypadMotion
	return event is InputEventKey


## First event of `action` for a device family (null when the action has none, e.g. after a rebind).
static func action_event(action: StringName, glyph_set: String) -> InputEvent:
	if not InputMap.has_action(action):
		return null
	for event: InputEvent in InputMap.action_get_events(action):
		if event_in_set(event, glyph_set):
			return event
	return null


## Glyph text of an action in a glyph set ("ENTER", "A", ...); "" for touch and for unbound actions.
static func action_text(action: StringName, glyph_set: String) -> String:
	if glyph_set == SET_TOUCH:
		return ""
	var event: InputEvent = action_event(action, glyph_set)
	return event_text(event) if event != null else ""


## Glyph text of one input event.
static func event_text(event: InputEvent) -> String:
	var key: InputEventKey = event as InputEventKey
	if key != null:
		return key_text(key)
	var button: InputEventJoypadButton = event as InputEventJoypadButton
	if button != null:
		return str(PAD_BUTTON_NAMES.get(button.button_index, "B%d" % button.button_index))
	var motion: InputEventJoypadMotion = event as InputEventJoypadMotion
	if motion != null:
		return axis_text(motion)
	return ""


## Colour of the badge behind a glyph (face buttons are coloured, everything else is ink).
static func event_color(event: InputEvent) -> Color:
	var button: InputEventJoypadButton = event as InputEventJoypadButton
	if button != null and PAD_BUTTON_COLORS.has(button.button_index):
		return PAD_BUTTON_COLORS[button.button_index]
	return UiKit.COL_CREAM


## Key cap text of a key event (the label printed on the user's keyboard layout where it is known).
static func key_text(key: InputEventKey) -> String:
	var code: Key = key.keycode
	if code == KEY_NONE and key.physical_keycode != KEY_NONE:
		code = key.physical_keycode
		# The user's layout is only known to real display servers (not to headless runs).
		if DisplayServer.get_name() != "headless":
			var mapped: Key = DisplayServer.keyboard_get_keycode_from_physical(key.physical_keycode)
			if mapped != KEY_NONE:
				code = mapped
	if KEY_NAMES.has(code):
		return str(KEY_NAMES[code])
	return OS.get_keycode_string(code).to_upper()


## Text of a stick direction.
static func axis_text(motion: InputEventJoypadMotion) -> String:
	var positive: bool = motion.axis_value >= 0.0
	match motion.axis:
		JOY_AXIS_LEFT_X:
			return "LS-RIGHT" if positive else "LS-LEFT"
		JOY_AXIS_LEFT_Y:
			return "LS-DOWN" if positive else "LS-UP"
		JOY_AXIS_RIGHT_X:
			return "RS-RIGHT" if positive else "RS-LEFT"
		JOY_AXIS_RIGHT_Y:
			return "RS-DOWN" if positive else "RS-UP"
		JOY_AXIS_TRIGGER_LEFT:
			return "LT"
		JOY_AXIS_TRIGGER_RIGHT:
			return "RT"
		_:
			return "AXIS %d" % motion.axis
