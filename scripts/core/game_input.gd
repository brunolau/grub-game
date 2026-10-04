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

## The player switched between keyboard, gamepad and touch: update button glyphs, show / hide the touch overlay.
signal device_changed(device: int)

## Flags of the current tick (bit mask of Defs.IN_FIRE, IN_DOWN, IN_UP, IN_LEFT, IN_RIGHT, IN_LOOK).
var flags: int = 0
## Flags of the previous tick (for cosmetic edge detection only, e.g. a jump sound).
var prev_flags: int = 0
## Last used device family (Defs.Device).
var device: int = Defs.Device.KEYBOARD
## When false every flag reads as released (cutscenes, transitions). Latches are discarded.
var enabled: bool = true

var _latched: int = 0
var _touch: int = 0
var _scripted: Callable = Callable()
var _scripted_active: bool = false

## InputMap action -> flag bit for the simple one-to-one actions.
const _ACTION_BITS: Dictionary = {
	&"move_left": Defs.IN_LEFT,
	&"move_right": Defs.IN_RIGHT,
	&"move_down": Defs.IN_DOWN,
	&"attack": Defs.IN_FIRE,
	&"look": Defs.IN_LOOK,
}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.has_feature("mobile") and DisplayServer.is_touchscreen_available():
		device = Defs.Device.TOUCH


func _notification(what: int) -> void:
	# A finger or key that was down when the app lost the foreground never reports its release.
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		clear_touch()
		_latched = 0


func _input(event: InputEvent) -> void:
	_track_device(event)
	if event.is_echo():
		return
	# Latch presses so that taps shorter than one tick (41 ms) are not lost.
	for action: StringName in _ACTION_BITS:
		if event.is_action_pressed(action):
			_latched |= int(_ACTION_BITS[action])
	if event.is_action_pressed(Defs.ACT_JUMP):
		_latched |= Defs.IN_UP
	if event.is_action_pressed(Defs.ACT_UP) and _up_jumps():
		_latched |= Defs.IN_UP


## Sample the flags for the tick that is about to run. Called by Sim only.
func sample() -> int:
	prev_flags = flags
	if _scripted_active:
		flags = int(_scripted.call(Sim.tick)) if _scripted.is_valid() else 0
	elif not enabled:
		flags = 0
	else:
		flags = _poll() | _latched | _touch
	_latched = 0
	return flags


## True when every bit of `mask` is set this tick.
func is_held(mask: int) -> bool:
	return (flags & mask) == mask


## True when any bit of `mask` went from released to held this tick (cosmetic use only).
func just_pressed(mask: int) -> bool:
	return (flags & mask) != 0 and (prev_flags & mask) == 0


## Touch overlay entry point: press or release one of the game actions (Defs.ACT_*). Also latches the press.
func set_touch(action: StringName, pressed: bool) -> void:
	var bit: int = 0
	if _ACTION_BITS.has(action):
		bit = int(_ACTION_BITS[action])
	elif action == Defs.ACT_JUMP or action == Defs.ACT_UP:
		bit = Defs.IN_UP
	else:
		push_error("GameInput.set_touch: '%s' is not a game action" % action)
		return
	if pressed:
		_touch |= bit
		_latched |= bit
		_set_device(Defs.Device.TOUCH)
	else:
		_touch &= ~bit


## Release every touch button (overlay hidden, app lost focus).
func clear_touch() -> void:
	_touch = 0


## Replace device input by a script: `source` is called once per tick as `source.call(tick: int) -> int` and
## returns the flags for that tick. Used by tests, golden traces and the autoplay harness.
func set_scripted(source: Callable) -> void:
	_scripted = source
	_scripted_active = true
	_latched = 0


## Return to device input.
func clear_scripted() -> void:
	_scripted = Callable()
	_scripted_active = false
	_latched = 0
	flags = 0
	prev_flags = 0


## True while a script drives the input.
func is_scripted() -> bool:
	return _scripted_active


## Convert a key string of the reference traces ("L", "R", "U", "D", "F", plus "K" for look) to flags.
## Example: keys_to_flags("RU") == Defs.IN_RIGHT | Defs.IN_UP.
static func keys_to_flags(keys: String) -> int:
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
	return result


## Expand a run-length input script ([[ticks, "KEYS"], ...], the format of PHYSICS_REFERENCE.json traces) into
## one flags value per tick.
static func expand_runs(runs: Array) -> PackedInt32Array:
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


func _up_jumps() -> bool:
	return Settings.get_bool("controls/up_jumps")


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
