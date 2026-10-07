extends Node
## Autoload `Settings`: user preferences in `user://settings.cfg` (versioned ConfigFile).
##
## CONTRACT FILE (docs/ARCHITECTURE.md 3.6). Owner: core. Keys listed in DEFAULTS are frozen; core appends new ones.
##
## Keys are "section/name" strings. Values are applied immediately by [method set_value] (audio bus volumes,
## window mode, input bindings) and written to disk by [method save] (call it when a menu closes, not per change).
##
## Bindings. The game actions (Defs.GAME_ACTIONS) can be rebound; `ui_*` actions keep Godot's defaults. Only
## keyboard keys (by physical position), gamepad buttons and gamepad axis directions can be bound. An options
## screen works like this:
##   1. show `get_bindings(action, Defs.Device.KEYBOARD)` / `(action, Defs.Device.GAMEPAD)` with `event_label()`;
##   2. wait for an input event for which `is_bindable(event)` is true;
##   3. call `set_binding(action, event, slot)`: an event that another action used is swapped, never duplicated;
##   4. offer `reset_binding(action)` / `reset_bindings()`; call `save()` when the screen closes.
## Changed actions are stored in the `[bindings]` section as text tokens ("key:90", "joy_button:0",
## "joy_axis:1:-1"); actions that were never changed follow the project defaults, also in later versions.
##
## Party bindings (2.0, docs/expansion/PLAN.md P0.5, DESIGN.md D.11): every player slot has its own binding profile
## for its generated actions `p1_*`..`p4_*` (GameInput.slot_action). The profile of slot n defaults to a keyboard
## half of the layout "controls/party_keyboard" (InputSlot: P1 the left cluster, P2 the right one) plus the solo
## pad layout; changed actions are stored in `[bindings_p1]`..`[bindings_p4]` with the same tokens. The
## single-player profile (`[bindings]`, the unprefixed actions) is untouched by them. The `*_slot_*` methods work
## like their single-player twins; `changed` reports a slot's binding as BINDINGS_KEY with the generated action
## name ("p2_jump") as value.

## A value changed (also emitted for every key after [method load_settings] and [method reset]). Bindings
## report the pseudo key BINDINGS_KEY with the action name as value ("" = all actions).
signal changed(key: String, value: Variant)

const FILE_NAME: String = "settings.cfg"
## Bump when a key changes meaning; add a step to _migrate().
const VERSION: int = 1
## Key reported by [signal changed] when the bindings of an action change.
const BINDINGS_KEY: String = "controls/bindings"
## Section of the settings file that holds the changed bindings.
const BINDINGS_SECTION: String = "bindings"
## Sections of the party binding profiles: SLOT_BINDINGS_SECTION + "1".."4" (see [method slot_bindings_section]).
const SLOT_BINDINGS_SECTION: String = "bindings_p"
## Key of the shared-keyboard layout of a party (InputSlot.KEYBOARD_LAYOUT_NAMES).
const PARTY_KEYBOARD_KEY: String = "controls/party_keyboard"
## A stick or trigger must be pushed at least this far to be captured as a binding.
const AXIS_CAPTURE_THRESHOLD: float = 0.5

const _TOKEN_KEY: String = "key"
const _TOKEN_JOY_BUTTON: String = "joy_button"
const _TOKEN_JOY_AXIS: String = "joy_axis"
const _JOY_BUTTON_LABELS: Dictionary = {
	JOY_BUTTON_A: "Pad A", JOY_BUTTON_B: "Pad B", JOY_BUTTON_X: "Pad X", JOY_BUTTON_Y: "Pad Y",
	JOY_BUTTON_BACK: "Pad Back", JOY_BUTTON_GUIDE: "Pad Guide", JOY_BUTTON_START: "Pad Start",
	JOY_BUTTON_LEFT_STICK: "Pad L3", JOY_BUTTON_RIGHT_STICK: "Pad R3",
	JOY_BUTTON_LEFT_SHOULDER: "Pad LB", JOY_BUTTON_RIGHT_SHOULDER: "Pad RB",
	JOY_BUTTON_DPAD_UP: "D-Pad Up", JOY_BUTTON_DPAD_DOWN: "D-Pad Down",
	JOY_BUTTON_DPAD_LEFT: "D-Pad Left", JOY_BUTTON_DPAD_RIGHT: "D-Pad Right",
}
const _JOY_AXIS_LABELS: Dictionary = {
	JOY_AXIS_LEFT_X: ["Left Stick Left", "Left Stick Right"],
	JOY_AXIS_LEFT_Y: ["Left Stick Up", "Left Stick Down"],
	JOY_AXIS_RIGHT_X: ["Right Stick Left", "Right Stick Right"],
	JOY_AXIS_RIGHT_Y: ["Right Stick Up", "Right Stick Down"],
	JOY_AXIS_TRIGGER_LEFT: ["Pad LT", "Pad LT"],
	JOY_AXIS_TRIGGER_RIGHT: ["Pad RT", "Pad RT"],
}

## Every known key with its default value.
const DEFAULTS: Dictionary = {
	"audio/master": 1.0,            # linear 0..1
	"audio/music": 0.8,             # linear 0..1
	"audio/sfx": 1.0,               # linear 0..1
	"video/fullscreen": false,
	"video/vsync": true,
	"video/screen_shake": true,     # accessibility: false = no view offset (the hero nudge stays, it is gameplay)
	"video/flash": true,            # accessibility: false = no full-screen flashes
	"controls/up_jumps": true,      # true = authentic: Up also jumps; false = only the jump button jumps
	"controls/touch_always": false, # show the touch overlay even without a touch screen
	"controls/touch_opacity": 0.7,
	"controls/touch_scale": 1.0,
	"controls/touch_layout": "standard", # "standard" | "swapped" (mirrored, left-handed touch layout)
	"controls/vibration": true,
	"camera/smooth_follow": false,  # non-original comfort camera (PHYSICS.md 12.6)
	"game/locale": "",              # "" = system locale
	"game/last_difficulty": 0,      # Defs.Difficulty
	"controls/party_keyboard": "classic", # 2.0: "classic" | "two_hands" | "one_hand" (DESIGN.md D.11, InputSlot)
	"versus/last_rules": {},        # 2.0: the rules of the last versus match (VersusMatch.rules_to_dict, DESIGN.md E.8)
}

## Directory of the settings file. Tests point it at `res://build/...` so they never touch real user data.
var storage_dir: String = "user://"

var _values: Dictionary = {}
var _bindings: Dictionary = {}  # action (String) -> Array of InputEvent
var _slot_bindings: Array[Dictionary] = _empty_slot_profiles()  # per slot: action (String) -> Array of InputEvent


func _ready() -> void:
	# The fullscreen shortcut works everywhere, the pause menu included.
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_settings()


## Desktop shortcut (ARCHITECTURE.md 2): Alt+Enter and F11 toggle fullscreen on every screen, like Options >
## Fullscreen, and the choice is saved at once. The key press goes no further (Alt+Enter is no menu "accept").
func _input(event: InputEvent) -> void:
	if is_fullscreen_shortcut(event) and has_fullscreen_switch():
		get_viewport().set_input_as_handled()
		toggle_fullscreen()


## True for a fresh press of F11 or Alt+Enter (either Enter key).
static func is_fullscreen_shortcut(event: InputEvent) -> bool:
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return false
	if key.keycode == KEY_F11:
		return true
	return key.alt_pressed and (key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER)


## True where the game window can switch to fullscreen (desktop platforms; phones are always fullscreen).
func has_fullscreen_switch() -> bool:
	return OS.has_feature("pc") and not OS.has_feature("mobile") and not OS.has_feature("web")


## Flip the fullscreen setting, apply it and write the settings file (the Options row follows the change).
func toggle_fullscreen() -> void:
	set_value("video/fullscreen", not get_bool("video/fullscreen"))
	save()


## Use another directory (created if missing) and reload from it.
func set_storage_dir(dir_path: String) -> void:
	storage_dir = dir_path if dir_path.ends_with("/") else dir_path + "/"
	DirAccess.make_dir_recursive_absolute(storage_dir)
	load_settings()


## Value of a key; falls back to DEFAULTS, then to `default`.
func get_value(key: String, default: Variant = null) -> Variant:
	if _values.has(key):
		return _values[key]
	if DEFAULTS.has(key):
		return DEFAULTS[key]
	return default


## Typed convenience getters.
func get_bool(key: String) -> bool:
	return bool(get_value(key, false))


func get_float(key: String) -> float:
	return float(get_value(key, 0.0))


func get_int(key: String) -> int:
	return int(get_value(key, 0))


## Change a value, apply it and emit [signal changed]. Does not write to disk.
func set_value(key: String, value: Variant) -> void:
	if _values.get(key) == value:
		return
	_values[key] = value
	_apply(key)
	changed.emit(key, value)


## Replace the events of a game action (Defs.GAME_ACTIONS) for the current session and remember them.
## Events are stored in their normal form (see [method normalize_event]); events that cannot be bound are
## reported and left out.
func rebind(action: StringName, events: Array[InputEvent]) -> void:
	if not Defs.GAME_ACTIONS.has(action):
		push_error("Settings.rebind: '%s' is not a game action" % action)
		return
	var accepted: Array[InputEvent] = []
	for event: InputEvent in events:
		var normal: InputEvent = normalize_event(event)
		if normal == null:
			push_error("Settings.rebind: %s cannot be bound to '%s'" % [str(event), action])
		elif _find_token(accepted, encode_event(normal)) < 0:
			accepted.append(normal)
	_apply_binding(action, accepted)
	changed.emit(BINDINGS_KEY, String(action))


## Restore the project's default bindings for every game action.
func reset_bindings() -> void:
	InputMap.load_from_project_settings()
	_bindings.clear()
	changed.emit(BINDINGS_KEY, "")


## Events of an action in slot order: the keys for Defs.Device.KEYBOARD, the pad buttons and axis directions
## for Defs.Device.GAMEPAD, everything for -1.
func get_bindings(action: StringName, device: int = -1) -> Array[InputEvent]:
	var result: Array[InputEvent] = []
	if not InputMap.has_action(action):
		return result
	for event: InputEvent in InputMap.action_get_events(action):
		if device < 0 or event_device(event) == device:
			result.append(event)
	return result


## The project's default events of an action (what [method reset_binding] restores).
func get_default_bindings(action: StringName) -> Array[InputEvent]:
	var result: Array[InputEvent] = []
	var entry: Variant = ProjectSettings.get_setting("input/" + String(action), {})
	if entry is Dictionary:
		for item: Variant in entry.get("events", []):
			if item is InputEvent:
				result.append(item)
	return result


## Bind one captured event to a game action: it replaces slot `slot` among the action's events of the same
## device (keys or gamepad), or is added when the action has fewer events. No event is ever on two game
## actions: when another action held it, that action receives the replaced event in exchange (or loses the
## event when nothing was replaced). Returns that other action, or &"" when none was touched.
func set_binding(action: StringName, event: InputEvent, slot: int = 0) -> StringName:
	if not Defs.GAME_ACTIONS.has(action):
		push_error("Settings.set_binding: '%s' is not a game action" % action)
		return &""
	var normal: InputEvent = normalize_event(event)
	if normal == null:
		push_error("Settings.set_binding: %s cannot be bound to '%s'" % [str(event), action])
		return &""
	var device: int = event_device(normal)
	var token: String = encode_event(normal)
	var mine: Array[InputEvent] = get_bindings(action, device)
	var index: int = clampi(slot, 0, mine.size())
	var held_at: int = _find_token(mine, token)
	var other: StringName = &""
	if held_at >= 0:
		# Already on this action: move it to the wanted slot.
		index = mini(index, mine.size() - 1)
		var swapped: InputEvent = mine[index]
		mine[index] = mine[held_at]
		mine[held_at] = swapped
	else:
		var replaced: InputEvent = null
		if index < mine.size():
			replaced = mine[index]
			mine[index] = normal
		else:
			mine.append(normal)
		other = _take_from_others(action, device, token, replaced)
	_apply_binding(action, _with_device_events(action, device, mine))
	changed.emit(BINDINGS_KEY, String(action))
	return other


## Restore the default events of one game action. Defaults that another action holds meanwhile are taken away
## from that action ([method reset_bindings] restores everything at once).
func reset_binding(action: StringName) -> void:
	if not Defs.GAME_ACTIONS.has(action):
		push_error("Settings.reset_binding: '%s' is not a game action" % action)
		return
	var defaults: Array[InputEvent] = get_default_bindings(action)
	for event: InputEvent in defaults:
		_take_from_others(action, event_device(event), encode_event(event), null)
	InputMap.action_erase_events(action)
	for event: InputEvent in defaults:
		InputMap.action_add_event(action, event)
	_bindings.erase(String(action))
	changed.emit(BINDINGS_KEY, String(action))


## True when at least one action differs from the project defaults.
func has_custom_bindings() -> bool:
	return not _bindings.is_empty()


# --- 2.0: party binding profiles (one per player slot) -----------------------------------------------------------

## Section of the settings file with the changed bindings of player slot `slot` (0..3): "bindings_p1".."bindings_p4".
static func slot_bindings_section(slot: int) -> String:
	return "%s%d" % [SLOT_BINDINGS_SECTION, slot + 1]


## The shared-keyboard layout of a party (InputSlot.KeyboardLayout), from "controls/party_keyboard".
func party_keyboard_layout() -> int:
	return InputSlot.layout_from_name(str(get_value(PARTY_KEYBOARD_KEY, InputSlot.KEYBOARD_LAYOUT_NAMES[0])))


## Events of a game action (Defs.GAME_ACTIONS) in the binding profile of player slot `slot`, in slot order, for one
## device family (Defs.Device.KEYBOARD / GAMEPAD; -1 = keys, then pad): the changed events of the profile, or its
## defaults - the keys of keyboard half `half` (Defs.InputSlotKind.KEYBOARD_LEFT / KEYBOARD_RIGHT; -1 = the slot's
## default half, InputSlot.default_half) in the layout of [method party_keyboard_layout], then the solo pad layout.
## Every event has device -1 (GameInput binds the pad events to the slot's pad).
func get_slot_bindings(slot: int, action: StringName, device: int = -1, half: int = -1) -> Array[InputEvent]:
	var result: Array[InputEvent] = []
	if not _is_slot_action(slot, action, "get_slot_bindings"):
		return result
	for event: InputEvent in _slot_events(slot, action, half):
		if device < 0 or event_device(event) == device:
			result.append(event)
	return result


## Replace the events of a game action in the profile of player slot `slot` (normal form, each event once; events
## that cannot be bound are reported and left out). An empty list restores the action's defaults.
func rebind_slot(slot: int, action: StringName, events: Array[InputEvent]) -> void:
	if not _is_slot_action(slot, action, "rebind_slot"):
		return
	var accepted: Array[InputEvent] = []
	for event: InputEvent in events:
		var normal: InputEvent = normalize_event(event)
		if normal == null:
			push_error("Settings.rebind_slot: %s cannot be bound to '%s'" % [str(event), action])
		elif _find_token(accepted, encode_event(normal)) < 0:
			accepted.append(normal)
	if accepted.is_empty():
		_slot_bindings[slot].erase(String(action))
	else:
		_slot_bindings[slot][String(action)] = accepted
	changed.emit(BINDINGS_KEY, String(InputSlot.action_name(slot, action)))


## Bind one captured event to a game action of player slot `slot`'s profile, as [method set_binding] does for the
## single-player profile: it replaces position `index` among the action's events of the same device family (or is
## added); no event is on two actions of one profile - the action that held it receives the replaced event in
## exchange (or loses it). Returns that other action, or &"". `half` as in [method get_slot_bindings]. Two profiles
## may hold the same event (each slot reads only its own device); the join screen's key test reports a key that
## two keyboard halves share.
func set_slot_binding(slot: int, action: StringName, event: InputEvent, index: int = 0,
		half: int = -1) -> StringName:
	if not _is_slot_action(slot, action, "set_slot_binding"):
		return &""
	var normal: InputEvent = normalize_event(event)
	if normal == null:
		push_error("Settings.set_slot_binding: %s cannot be bound to '%s'" % [str(event), action])
		return &""
	var device: int = event_device(normal)
	var token: String = encode_event(normal)
	var mine: Array[InputEvent] = get_slot_bindings(slot, action, device, half)
	var at: int = clampi(index, 0, mine.size())
	var held_at: int = _find_token(mine, token)
	var other: StringName = &""
	if held_at >= 0:
		at = mini(at, mine.size() - 1)
		var swapped: InputEvent = mine[at]
		mine[at] = mine[held_at]
		mine[held_at] = swapped
	else:
		var replaced: InputEvent = null
		if at < mine.size():
			replaced = mine[at]
			mine[at] = normal
		else:
			mine.append(normal)
		other = _take_from_other_slot_actions(slot, action, device, token, replaced, half)
	_slot_bindings[slot][String(action)] = _slot_with_device_events(slot, action, device, mine, half)
	changed.emit(BINDINGS_KEY, String(InputSlot.action_name(slot, action)))
	return other


## Restore the defaults of one game action in player slot `slot`'s profile. Defaults that another action of the
## profile holds meanwhile are taken away from that action (as [method reset_binding]). `half` as in
## [method get_slot_bindings].
func reset_slot_binding(slot: int, action: StringName, half: int = -1) -> void:
	if not _is_slot_action(slot, action, "reset_slot_binding"):
		return
	_slot_bindings[slot].erase(String(action))
	for event: InputEvent in get_slot_bindings(slot, action, -1, half):
		_take_from_other_slot_actions(slot, action, event_device(event), encode_event(event), null, half)
	changed.emit(BINDINGS_KEY, String(InputSlot.action_name(slot, action)))


## Restore the defaults of every action of player slot `slot`'s profile (-1: of every slot).
func reset_slot_bindings(slot: int = -1) -> void:
	for each: int in Defs.MAX_PLAYERS:
		if slot < 0 or slot == each:
			_slot_bindings[each] = {}
	changed.emit(BINDINGS_KEY, "")


## True when player slot `slot`'s profile differs from its defaults.
func has_custom_slot_bindings(slot: int) -> bool:
	return slot >= 0 and slot < Defs.MAX_PLAYERS and not _slot_bindings[slot].is_empty()


## True when a captured input event can become a binding: a key press (no echo), a gamepad button press, or a
## stick / trigger pushed at least AXIS_CAPTURE_THRESHOLD. Releases, mouse and touch events cannot.
func is_bindable(event: InputEvent) -> bool:
	if normalize_event(event) == null:
		return false
	if event is InputEventKey:
		var key: InputEventKey = event
		return key.pressed and not key.echo
	if event is InputEventJoypadMotion:
		var motion: InputEventJoypadMotion = event
		return absf(motion.axis_value) >= AXIS_CAPTURE_THRESHOLD
	return event.is_pressed()


## Device family of a binding: Defs.Device.KEYBOARD for a key, Defs.Device.GAMEPAD for a pad button or axis,
## -1 for everything else.
func event_device(event: InputEvent) -> int:
	if event is InputEventKey:
		return Defs.Device.KEYBOARD
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		return Defs.Device.GAMEPAD
	return -1


## The form in which a binding is kept: valid for every device, keys by physical position without modifiers,
## axes as a direction (-1 or +1). Returns null when the event cannot be a binding.
func normalize_event(event: InputEvent) -> InputEvent:
	if event is InputEventKey:
		var source_key: InputEventKey = event
		var code: Key = source_key.physical_keycode if source_key.physical_keycode != KEY_NONE \
				else source_key.keycode
		if code == KEY_NONE:
			return null
		var key: InputEventKey = InputEventKey.new()
		key.device = -1
		key.physical_keycode = code
		return key
	if event is InputEventJoypadButton:
		var source_button: InputEventJoypadButton = event
		if source_button.button_index < 0 or source_button.button_index >= JOY_BUTTON_MAX:
			return null
		var button: InputEventJoypadButton = InputEventJoypadButton.new()
		button.device = -1
		button.button_index = source_button.button_index
		return button
	if event is InputEventJoypadMotion:
		var source_motion: InputEventJoypadMotion = event
		if source_motion.axis < 0 or source_motion.axis >= JOY_AXIS_MAX or is_zero_approx(source_motion.axis_value):
			return null
		var motion: InputEventJoypadMotion = InputEventJoypadMotion.new()
		motion.device = -1
		motion.axis = source_motion.axis
		motion.axis_value = signf(source_motion.axis_value)
		return motion
	return null


## Text token of a binding as stored in the settings file: "key:<physical keycode>", "joy_button:<index>",
## "joy_axis:<axis>:<-1|1>". "" when the event cannot be a binding.
func encode_event(event: InputEvent) -> String:
	var normal: InputEvent = normalize_event(event)
	if normal is InputEventKey:
		var key: InputEventKey = normal
		return "%s:%d" % [_TOKEN_KEY, key.physical_keycode]
	if normal is InputEventJoypadButton:
		var button: InputEventJoypadButton = normal
		return "%s:%d" % [_TOKEN_JOY_BUTTON, button.button_index]
	if normal is InputEventJoypadMotion:
		var motion: InputEventJoypadMotion = normal
		return "%s:%d:%d" % [_TOKEN_JOY_AXIS, motion.axis, int(signf(motion.axis_value))]
	return ""


## The binding a token stands for; null when the token is not valid.
func decode_event(token: String) -> InputEvent:
	var parts: PackedStringArray = token.split(":")
	for i: int in range(1, parts.size()):
		if not parts[i].is_valid_int():
			return null
	if parts[0] == _TOKEN_KEY and parts.size() == 2 and parts[1].to_int() > 0:
		var key: InputEventKey = InputEventKey.new()
		key.device = -1
		key.physical_keycode = parts[1].to_int() as Key
		return key
	if parts[0] == _TOKEN_JOY_BUTTON and parts.size() == 2:
		var index: int = parts[1].to_int()
		if index < 0 or index >= JOY_BUTTON_MAX:
			return null
		var button: InputEventJoypadButton = InputEventJoypadButton.new()
		button.device = -1
		button.button_index = index as JoyButton
		return button
	if parts[0] == _TOKEN_JOY_AXIS and parts.size() == 3:
		var axis: int = parts[1].to_int()
		var direction: int = parts[2].to_int()
		if axis < 0 or axis >= JOY_AXIS_MAX or absi(direction) != 1:
			return null
		var motion: InputEventJoypadMotion = InputEventJoypadMotion.new()
		motion.device = -1
		motion.axis = axis as JoyAxis
		motion.axis_value = float(direction)
		return motion
	return null


## Short English name of a binding for menus ("Z", "Space", "Pad A", "Left Stick Up"); "" when the event is not
## a binding. On desktops keys are named after the player's keyboard layout, elsewhere after the US layout. The
## ui module may translate it or show a glyph instead.
func event_label(event: InputEvent) -> String:
	var normal: InputEvent = normalize_event(event)
	if normal is InputEventKey:
		var key: InputEventKey = normal
		var code: Key = key.physical_keycode
		# Only the desktop display servers know the keyboard layout (the others log an error when asked).
		if OS.has_feature("pc") and DisplayServer.get_name() != "headless":
			code = DisplayServer.keyboard_get_keycode_from_physical(code)
		return OS.get_keycode_string(code)
	if normal is InputEventJoypadButton:
		var button: InputEventJoypadButton = normal
		return str(_JOY_BUTTON_LABELS.get(button.button_index, "Pad %d" % button.button_index))
	if normal is InputEventJoypadMotion:
		var motion: InputEventJoypadMotion = normal
		var names: Array = _JOY_AXIS_LABELS.get(motion.axis, [])
		if names.is_empty():
			return "Axis %d%s" % [motion.axis, "-" if motion.axis_value < 0.0 else "+"]
		return str(names[0 if motion.axis_value < 0.0 else 1])
	return ""


## Restore every value to its default (does not touch save data). The party binding profiles too.
func reset() -> void:
	_values.clear()
	_slot_bindings = _empty_slot_profiles()
	reset_bindings()
	for key: String in DEFAULTS:
		_apply(key)
		changed.emit(key, DEFAULTS[key])


## Read the file (missing or damaged files yield the defaults) and apply everything.
func load_settings() -> void:
	_values.clear()
	_bindings.clear()
	_slot_bindings = _empty_slot_profiles()
	InputMap.load_from_project_settings()
	var file: ConfigFile = ConfigFile.new()
	var err: Error = file.load(storage_dir + FILE_NAME)
	if err == OK:
		var version: int = int(file.get_value("meta", "version", 0))
		for section: String in file.get_sections():
			if section == "meta" or section == BINDINGS_SECTION or _slot_of_section(section) >= 0:
				continue
			for key_name: String in file.get_section_keys(section):
				_values["%s/%s" % [section, key_name]] = file.get_value(section, key_name)
		if file.has_section(BINDINGS_SECTION):
			for action: String in file.get_section_keys(BINDINGS_SECTION):
				_load_binding(action, file.get_value(BINDINGS_SECTION, action))
		for slot: int in Defs.MAX_PLAYERS:
			var slot_section: String = slot_bindings_section(slot)
			if file.has_section(slot_section):
				for action: String in file.get_section_keys(slot_section):
					_load_slot_binding(slot, action, file.get_value(slot_section, action))
		if version != VERSION:
			_migrate(version)
	elif err != ERR_FILE_NOT_FOUND:
		push_warning("Settings: could not read %s (error %d), using defaults" % [storage_dir + FILE_NAME, err])
	for key: String in DEFAULTS:
		_apply(key)
		changed.emit(key, get_value(key))
	changed.emit(BINDINGS_KEY, "")


## Write the current values to disk. Returns OK or the error.
func save() -> Error:
	var file: ConfigFile = ConfigFile.new()
	file.set_value("meta", "version", VERSION)
	for key: String in _values:
		var parts: PackedStringArray = key.split("/", true, 1)
		if parts.size() == 2:
			file.set_value(parts[0], parts[1], _values[key])
	for action: String in _bindings:
		var tokens: PackedStringArray = PackedStringArray()
		for event: InputEvent in _bindings[action]:
			tokens.append(encode_event(event))
		file.set_value(BINDINGS_SECTION, action, tokens)
	for slot: int in Defs.MAX_PLAYERS:
		for action: String in _slot_bindings[slot]:
			var slot_tokens: PackedStringArray = PackedStringArray()
			for event: InputEvent in _slot_bindings[slot][action]:
				slot_tokens.append(encode_event(event))
			file.set_value(slot_bindings_section(slot), action, slot_tokens)
	var err: Error = file.save(storage_dir + FILE_NAME)
	if err != OK:
		push_error("Settings: could not write %s (error %d)" % [storage_dir + FILE_NAME, err])
	return err


func _migrate(_from_version: int) -> void:
	# Version 1 is the first format: nothing to convert. Unknown keys are kept, missing keys use DEFAULTS.
	pass


## One entry of the [bindings] section. Anything that is not a list of valid tokens for a game action is
## ignored, so a damaged or hand-edited file can never leave an action without input.
func _load_binding(action: String, stored: Variant) -> void:
	if not Defs.GAME_ACTIONS.has(StringName(action)):
		return
	if not (stored is PackedStringArray or stored is Array):
		return
	var events: Array[InputEvent] = []
	for item: Variant in stored:
		if item is String:
			var event: InputEvent = decode_event(item)
			if event != null and _find_token(events, encode_event(event)) < 0:
				events.append(event)
	if not events.is_empty():
		_apply_binding(StringName(action), events)


## Make `events` the events of `action` in the InputMap and remember them for save().
func _apply_binding(action: StringName, events: Array[InputEvent]) -> void:
	InputMap.action_erase_events(action)
	for event: InputEvent in events:
		InputMap.action_add_event(action, event)
	_bindings[String(action)] = events


## All events of `action` with those of one device family replaced by `device_events` (keys first, then pad).
func _with_device_events(action: StringName, device: int, device_events: Array[InputEvent]) -> Array[InputEvent]:
	var result: Array[InputEvent] = []
	for family: int in [Defs.Device.KEYBOARD, Defs.Device.GAMEPAD]:
		result.append_array(device_events if family == device else get_bindings(action, family))
	return result


## Remove the event `token` from every game action except `action`; an action that held it gets `replacement`
## in the same slot (when given and not already there). Returns the last action that was changed.
func _take_from_others(action: StringName, device: int, token: String, replacement: InputEvent) -> StringName:
	var changed_action: StringName = &""
	for other: StringName in Defs.GAME_ACTIONS:
		if other == action:
			continue
		var theirs: Array[InputEvent] = get_bindings(other, device)
		var at: int = _find_token(theirs, token)
		if at < 0:
			continue
		if replacement != null and _find_token(theirs, encode_event(replacement)) < 0:
			theirs[at] = replacement
		else:
			theirs.remove_at(at)
		_apply_binding(other, _with_device_events(other, device, theirs))
		changed.emit(BINDINGS_KEY, String(other))
		changed_action = other
	return changed_action


## One entry of a `[bindings_pN]` section, read like [method _load_binding].
func _load_slot_binding(slot: int, action: String, stored: Variant) -> void:
	if not Defs.GAME_ACTIONS.has(StringName(action)):
		return
	if not (stored is PackedStringArray or stored is Array):
		return
	var events: Array[InputEvent] = []
	for item: Variant in stored:
		if item is String:
			var event: InputEvent = decode_event(item)
			if event != null and _find_token(events, encode_event(event)) < 0:
				events.append(event)
	if not events.is_empty():
		_slot_bindings[slot][action] = events


## The events of a slot profile's action: the changed ones, or the defaults of the keyboard half.
func _slot_events(slot: int, action: StringName, half: int) -> Array[InputEvent]:
	var stored: Variant = _slot_bindings[slot].get(String(action))
	if stored is Array:
		var copy: Array[InputEvent] = []
		copy.assign(stored)
		return copy
	var used_half: int = half if half >= 0 else InputSlot.default_half(slot)
	return InputSlot.default_events(party_keyboard_layout(), used_half, action)


## A slot profile's events of `action` with those of one device family replaced (keys first, then pad).
func _slot_with_device_events(slot: int, action: StringName, device: int, device_events: Array[InputEvent],
		half: int) -> Array[InputEvent]:
	var result: Array[InputEvent] = []
	for family: int in [Defs.Device.KEYBOARD, Defs.Device.GAMEPAD]:
		result.append_array(device_events if family == device else get_slot_bindings(slot, action, family, half))
	return result


## [method _take_from_others] inside one slot profile.
func _take_from_other_slot_actions(slot: int, action: StringName, device: int, token: String,
		replacement: InputEvent, half: int) -> StringName:
	var changed_action: StringName = &""
	for other: StringName in Defs.GAME_ACTIONS:
		if other == action:
			continue
		var theirs: Array[InputEvent] = get_slot_bindings(slot, other, device, half)
		var at: int = _find_token(theirs, token)
		if at < 0:
			continue
		if replacement != null and _find_token(theirs, encode_event(replacement)) < 0:
			theirs[at] = replacement
		else:
			theirs.remove_at(at)
		_slot_bindings[slot][String(other)] = _slot_with_device_events(slot, other, device, theirs, half)
		changed.emit(BINDINGS_KEY, String(InputSlot.action_name(slot, other)))
		changed_action = other
	return changed_action


func _is_slot_action(slot: int, action: StringName, caller: String) -> bool:
	if slot < 0 or slot >= Defs.MAX_PLAYERS:
		push_error("Settings.%s: no player slot %d" % [caller, slot])
		return false
	if not Defs.GAME_ACTIONS.has(action):
		push_error("Settings.%s: '%s' is not a game action" % [caller, action])
		return false
	return true


## The player slot of a `[bindings_pN]` section name, or -1.
static func _slot_of_section(section: String) -> int:
	for slot: int in Defs.MAX_PLAYERS:
		if section == slot_bindings_section(slot):
			return slot
	return -1


static func _empty_slot_profiles() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for slot: int in Defs.MAX_PLAYERS:
		result.append({})
	return result


## Index of the event with this token in `events`, or -1.
func _find_token(events: Array[InputEvent], token: String) -> int:
	for i: int in events.size():
		if encode_event(events[i]) == token:
			return i
	return -1


func _apply(key: String) -> void:
	match key:
		"audio/master":
			_set_bus("Master", get_float(key))
		"audio/music":
			_set_bus("Music", get_float(key))
		"audio/sfx":
			_set_bus("SFX", get_float(key))
		"video/fullscreen":
			if DisplayServer.get_name() != "headless" and not OS.has_feature("mobile"):
				var mode: int = DisplayServer.WINDOW_MODE_FULLSCREEN if get_bool(key) \
						else DisplayServer.WINDOW_MODE_WINDOWED
				if DisplayServer.window_get_mode() != mode:
					DisplayServer.window_set_mode(mode)
		"video/vsync":
			if DisplayServer.get_name() != "headless":
				DisplayServer.window_set_vsync_mode(
					DisplayServer.VSYNC_ENABLED if get_bool(key) else DisplayServer.VSYNC_DISABLED
				)
		"game/locale":
			var locale: String = str(get_value(key, ""))
			TranslationServer.set_locale(locale if locale != "" else OS.get_locale())


func _set_bus(bus_name: String, linear: float) -> void:
	var index: int = AudioServer.get_bus_index(bus_name)
	if index < 0:
		return
	var value: float = clampf(linear, 0.0, 1.0)
	AudioServer.set_bus_mute(index, value <= 0.0001)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(value, 0.0001)))
