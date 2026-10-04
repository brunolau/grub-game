class_name TouchControls
extends Control
## On-screen controls for touch screens (docs/ARCHITECTURE.md 8.6): a d-pad (left, down, right, up) and the
## jump, attack and look stones from `ui/touch_buttons.png`, plus the pause stone (`ui/touch_pause.png`).
##
## Owner: ui. Multi-touch: every finger is tracked on its own and may slide from one button to its neighbour.
## Buttons feed the game through `GameInput.set_touch(Defs.ACT_*, pressed)`; the pause stone calls
## `Flow.toggle_pause()`. Shown while `GameInput.wants_touch_controls()` and the game is not paused; size,
## opacity and a mirrored (left-handed) layout come from the settings. Everything stays inside the safe area.

## One on-screen button.
class Pad:
	extends RefCounted
	## Game action (Defs.ACT_*), or Defs.ACT_PAUSE for the pause stone.
	var action: StringName = &""
	## Cell of touch_buttons.png (the pressed look is cell + 8); -1 = the pause stone.
	var cell: int = 0
	## Screen rectangle (art px).
	var rect: Rect2 = Rect2()
	## Group of buttons a finger may slide across (0 = d-pad, 1 = action stones, 2 = pause).
	var cluster: int = 0
	## Fingers currently on the button.
	var fingers: PackedInt32Array = PackedInt32Array()

	func _init(p_action: StringName, p_cell: int, p_cluster: int) -> void:
		action = p_action
		cell = p_cell
		cluster = p_cluster

	func is_held() -> bool:
		return not fingers.is_empty()


const BUTTON_SIZE: float = 56.0
const GAP: float = 4.0
const HIT_GROW: float = 6.0
const PAUSE_TOP: float = 52.0        ## below the bonus letters of the HUD
const PRESSED_OFFSET: int = 8
const SHEET: String = "res://assets/ui/touch_buttons.png"
const PAUSE_TEXTURE: String = "res://assets/ui/touch_pause.png"
const CELL: Vector2i = Vector2i(56, 56)
const KEY_LAYOUT: String = "controls/touch_layout"

var _pads: Array[Pad] = []
var _finger_pad: Dictionary = {}     # finger index -> Pad
var _sheet: Texture2D = null
var _pause_texture: Texture2D = null
var _paused: bool = false


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_sheet = UiKit.tex(SHEET)
	_pause_texture = UiKit.tex(PAUSE_TEXTURE)
	_pads.append(Pad.new(Defs.ACT_LEFT, 0, 0))
	_pads.append(Pad.new(Defs.ACT_DOWN, 3, 0))
	_pads.append(Pad.new(Defs.ACT_RIGHT, 1, 0))
	_pads.append(Pad.new(Defs.ACT_UP, 2, 0))
	_pads.append(Pad.new(Defs.ACT_ATTACK, 5, 1))
	_pads.append(Pad.new(Defs.ACT_JUMP, 4, 1))
	_pads.append(Pad.new(Defs.ACT_LOOK, 6, 1))
	_pads.append(Pad.new(Defs.ACT_PAUSE, -1, 2))


func _ready() -> void:
	add_to_group(Defs.GROUP_TOUCH)
	GameInput.device_changed.connect(_on_device_changed)
	Settings.changed.connect(_on_setting_changed)
	Events.pause_changed.connect(_on_pause_changed)
	resized.connect(layout)
	get_viewport().size_changed.connect(layout)
	_paused = get_tree().paused
	layout()
	_update_visibility()


func _exit_tree() -> void:
	release_all()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	var touch: InputEventScreenTouch = event as InputEventScreenTouch
	if touch != null:
		if touch.pressed:
			var pad: Pad = _pad_at(touch.position, -1)
			if pad != null:
				_assign(touch.index, pad)
				get_viewport().set_input_as_handled()
		elif _finger_pad.has(touch.index):
			_assign(touch.index, null)
			get_viewport().set_input_as_handled()
		return
	var drag: InputEventScreenDrag = event as InputEventScreenDrag
	if drag != null and _finger_pad.has(drag.index):
		var current: Pad = _finger_pad[drag.index]
		if current.cluster == 2:
			return
		var target: Pad = _pad_at(drag.position, current.cluster)
		if target != current:
			_assign(drag.index, target)
		get_viewport().set_input_as_handled()


func _draw() -> void:
	var scale_factor: float = _scale()
	for pad: Pad in _pads:
		if pad.cell < 0:
			if _pause_texture != null:
				draw_texture_rect(_pause_texture, pad.rect, false,
						Color(0.8, 0.8, 0.8) if pad.is_held() else Color.WHITE)
			_draw_pause_bars(pad.rect, scale_factor)
			continue
		if _sheet == null:
			continue
		var index: int = pad.cell + (PRESSED_OFFSET if pad.is_held() else 0)
		var source: Rect2 = Rect2(float((index % 8) * CELL.x), float((index / 8) * CELL.y), float(CELL.x),
				float(CELL.y))
		var target: Rect2 = pad.rect
		if pad.is_held():
			target.position.y += roundf(2.0 * scale_factor)
		draw_texture_rect_region(_sheet, target, source)


## Place the buttons for the current view, safe area, size setting and layout.
func layout() -> void:
	var margins: Vector4i = UiKit.safe_margins(get_viewport())
	var unit: float = roundf(BUTTON_SIZE * _scale())
	var gap: float = roundf(GAP * _scale())
	var view: Vector2 = size
	var left: float = float(margins.x)
	var right: float = view.x - float(margins.z)
	var bottom: float = view.y - float(margins.w)
	var swapped: bool = str(Settings.get_value(KEY_LAYOUT, "standard")) == "swapped"
	# D-pad: an inverted T on one side; the action stones on the other (mirrored for left-handed play).
	var pad_left: float = right - unit * 3.0 - gap * 2.0 if swapped else left
	var jump_x: float = left if swapped else right - unit
	var attack_x: float = left + unit + gap if swapped else jump_x - unit - gap
	var row: float = bottom - unit
	_place(Defs.ACT_LEFT, Vector2(pad_left, row), unit)
	_place(Defs.ACT_DOWN, Vector2(pad_left + unit + gap, row), unit)
	_place(Defs.ACT_RIGHT, Vector2(pad_left + (unit + gap) * 2.0, row), unit)
	_place(Defs.ACT_UP, Vector2(pad_left + unit + gap, row - unit - gap), unit)
	_place(Defs.ACT_JUMP, Vector2(jump_x, row - roundf(unit * 0.4)), unit)
	_place(Defs.ACT_ATTACK, Vector2(attack_x, row), unit)
	_place(Defs.ACT_LOOK, Vector2(attack_x, row - unit - gap), unit)
	var pause_x: float = left if swapped else right - unit
	_place(Defs.ACT_PAUSE, Vector2(pause_x, float(margins.y) + roundf(PAUSE_TOP * _scale())), unit)
	modulate.a = clampf(Settings.get_float("controls/touch_opacity"), 0.1, 1.0)
	queue_redraw()


## Screen rectangle of the button of `action` (empty when there is none).
func get_button_rect(action: StringName) -> Rect2:
	var pad: Pad = _find(action)
	return pad.rect if pad != null else Rect2()


## True while at least one finger holds the button of `action`.
func is_button_held(action: StringName) -> bool:
	var pad: Pad = _find(action)
	return pad != null and pad.is_held()


## Lift every finger (overlay hidden, game paused, scene left).
func release_all() -> void:
	for finger: int in _finger_pad.keys():
		_assign(finger, null)
	_finger_pad.clear()
	GameInput.clear_touch()


func _place(action: StringName, pos: Vector2, unit: float) -> void:
	var pad: Pad = _find(action)
	if pad != null:
		pad.rect = Rect2(pos.round(), Vector2(unit, unit))


func _find(action: StringName) -> Pad:
	for pad: Pad in _pads:
		if pad.action == action:
			return pad
	return null


## Button under `pos` (grown hit boxes); with `cluster` >= 0 only buttons of that cluster count.
func _pad_at(pos: Vector2, cluster: int) -> Pad:
	var best: Pad = null
	var best_distance: float = INF
	for pad: Pad in _pads:
		if cluster >= 0 and pad.cluster != cluster:
			continue
		if not pad.rect.grow(HIT_GROW * _scale()).has_point(pos):
			continue
		var distance: float = pad.rect.get_center().distance_squared_to(pos)
		if distance < best_distance:
			best = pad
			best_distance = distance
	return best


func _assign(finger: int, pad: Pad) -> void:
	var previous: Pad = _finger_pad.get(finger) as Pad
	if previous == pad:
		return
	if previous != null:
		var at: int = previous.fingers.find(finger)
		if at >= 0:
			previous.fingers.remove_at(at)
		if not previous.is_held() and previous.cell >= 0:
			GameInput.set_touch(previous.action, false)
		_finger_pad.erase(finger)
	if pad != null:
		var was_held: bool = pad.is_held()
		pad.fingers.append(finger)
		_finger_pad[finger] = pad
		if not was_held:
			if pad.cell < 0:
				Flow.toggle_pause()
			else:
				GameInput.set_touch(pad.action, true)
				GameInput.vibrate(12, 0.3)
	queue_redraw()


func _scale() -> float:
	return clampf(Settings.get_float("controls/touch_scale"), 0.75, 2.0)


func _update_visibility() -> void:
	var wanted: bool = GameInput.wants_touch_controls() and not _paused
	if not wanted:
		release_all()
	visible = wanted


func _on_device_changed(_device: int) -> void:
	_update_visibility()


func _on_pause_changed(paused: bool) -> void:
	_paused = paused
	_update_visibility()


func _on_setting_changed(key: String, _value: Variant) -> void:
	if key == "controls/touch_always":
		_update_visibility()
	elif key.begins_with("controls/touch_"):
		layout()


## Two bars on the pause stone, so that it reads as "pause" and not as the look button.
func _draw_pause_bars(rect: Rect2, scale_factor: float) -> void:
	var bar: Vector2 = Vector2(roundf(6.0 * scale_factor), roundf(20.0 * scale_factor))
	var gap: float = roundf(6.0 * scale_factor)
	var top: float = roundf(rect.get_center().y - bar.y * 0.5)
	var left: float = roundf(rect.get_center().x - bar.x - gap * 0.5)
	for x: float in [left, left + bar.x + gap]:
		draw_rect(Rect2(Vector2(x, top), bar).grow(2.0), UiKit.COL_INK)
		draw_rect(Rect2(Vector2(x, top), bar), UiKit.COL_CREAM)
