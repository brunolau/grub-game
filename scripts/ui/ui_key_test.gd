class_name UiKeyTest
extends VBoxContainer
## The two-player keyboard test (DESIGN.md D.11, PLAN.md P1.12 / P4.3): many keyboards cannot report every
## combination of held keys ("ghosting"), so both players hold Left + Jump + Strike + Swap at once and all eight
## lights must stay lit. Every other key of both halves lights too, so a player can check his whole cluster.
##
## Owner: ui-B. Part of the options bindings page; ui-A's join panel / versus lobby may embed it as well. The keys are
## the two keyboard halves of the binding profiles of P1 and P2 (Settings.get_slot_bindings, the layout of
## "controls/party_keyboard"). Keys are read by physical position, so the numpad works whatever the NumLock state.
## Windows quirk it detects: with NumLock ON, a numpad key pressed while Shift is held makes Windows lift Shift (and
## press it again afterwards) - in the classic layout that drops P1's strike; the test then says "switch Num Lock off".
## While the test shows it swallows every key (Num Enter, Space ... must not press menu entries); "back" (Escape, a
## pad's B) still reaches the host.

## The test passed: all lights of the ghosting combination were lit at the same moment.
signal passed

## The four actions both players hold at once (DESIGN.md D.11).
const COMBO: Array[StringName] = [&"move_left", &"jump", &"attack", &"swap"]
## The other actions shown as small lights.
const OTHERS: Array[StringName] = [&"move_up", &"move_down", &"move_right", &"look"]
## Players tested: the two keyboard halves.
const PLAYERS: int = 2
const CAP_W: float = 84.0
const CAP_H: float = 34.0
const SMALL_W: float = 46.0
const SMALL_H: float = 18.0


## One key light: a key cap that lights in the player's colour while its key is held.
class KeyLight:
	extends Control

	var slot: int = 0
	var action: StringName = &""
	var key_text: String = ""
	var caption: String = ""
	var lit: bool = false
	var small: bool = false

	func _init(p_slot: int, p_action: StringName, p_small: bool) -> void:
		slot = p_slot
		action = p_action
		small = p_small
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(UiKeyTest.SMALL_W, UiKeyTest.SMALL_H) if small \
				else Vector2(UiKeyTest.CAP_W, UiKeyTest.CAP_H)

	func set_lit(on: bool) -> void:
		if on != lit:
			lit = on
			queue_redraw()

	func _draw() -> void:
		var cap: Rect2 = Rect2(Vector2.ZERO, size)
		draw_rect(cap, UiKit.COL_INK)
		var face: Rect2 = cap.grow(-2.0)
		face.size.y -= 2.0
		draw_rect(face, UiPlayers.colour(slot) if lit else Color(UiKit.COL_INK.lightened(0.18)))
		var mono: Font = UiKit.font(UiKit.Style.MONO)
		var font_size: int = UiKit.SIZE_MONO if small else UiKit.SIZE_MONO * 2
		var text: String = key_text if key_text != "" else "-"
		var colour: Color = UiKit.COL_INK if lit else UiKit.COL_CREAM
		var width: float = mono.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
		if width > face.size.x - 4.0 and not small:
			font_size = UiKit.SIZE_MONO
			width = mono.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
		var top: float = 4.0 if not small else roundf((face.size.y - float(font_size)) * 0.5) + 2.0
		draw_string(mono, Vector2(roundf((size.x - width) * 0.5), top + mono.get_ascent(font_size)), text,
				HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, colour)
		if not small and caption != "":
			var body: Font = UiKit.font(UiKit.Style.SMALL)
			var caption_w: float = body.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1.0, UiKit.SIZE_SMALL).x
			draw_string(body, Vector2(roundf((size.x - caption_w) * 0.5), size.y - 6.0), caption,
					HORIZONTAL_ALIGNMENT_LEFT, -1.0, UiKit.SIZE_SMALL, colour)


## True once every light of the combination was lit at the same moment (reset by [method start]).
var has_passed: bool = false
## True after the NumLock quirk was seen (a Shift release right before a numpad press).
var numlock_warning: bool = false
## Physical keys held now, as the test saw them.
var held: Dictionary = {}

var _lights: Array[KeyLight] = []
var _keys: Dictionary = {}           # KeyLight -> PackedInt32Array of physical keycodes
var _status: Label = null
var _hint: Label = null
var _shift_up_frame: int = -100


func _init() -> void:
	UiKit.ensure_locale()
	add_theme_constant_override(&"separation", 4)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var intro: Label = UiKit.label("UI_KEYTEST_INTRO", UiKit.Style.SMALL, HORIZONTAL_ALIGNMENT_CENTER)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.custom_minimum_size = Vector2(380.0, 0.0)
	add_child(intro)
	var columns: HBoxContainer = HBoxContainer.new()
	columns.alignment = BoxContainer.ALIGNMENT_CENTER
	columns.add_theme_constant_override(&"separation", 20)
	columns.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(columns)
	for slot: int in PLAYERS:
		columns.add_child(_player_column(slot))
	_status = UiKit.label("", UiKit.Style.SMALL, HORIZONTAL_ALIGNMENT_CENTER)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(380.0, 0.0)
	add_child(_status)
	_hint = UiKit.label("UI_KEYTEST_NUMLOCK_HINT", UiKit.Style.SMALL, HORIZONTAL_ALIGNMENT_CENTER)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.custom_minimum_size = Vector2(380.0, 0.0)
	_hint.add_theme_color_override(&"font_color", UiKit.COL_DIM)
	add_child(_hint)


func _ready() -> void:
	Settings.changed.connect(_on_setting_changed)
	visibility_changed.connect(_on_visibility_changed)
	start()


func _input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key == null or not is_visible_in_tree():
		return
	var code: Key = key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
	if key.echo:
		get_viewport().set_input_as_handled()
		return
	if key.pressed:
		held[code] = true
		if UiGlyphs.is_numpad(code) and Engine.get_process_frames() - _shift_up_frame <= 1 and _shift_bound():
			numlock_warning = true
	else:
		held.erase(code)
		if code == KEY_SHIFT:
			_shift_up_frame = Engine.get_process_frames()
	_update_lights()
	# "Back" (Escape) leaves the test; every other key belongs to the test.
	if not (key.pressed and key.is_action_pressed(&"ui_cancel")):
		get_viewport().set_input_as_handled()


## Read the two halves of the current layout and clear the lights.
func start() -> void:
	held.clear()
	has_passed = false
	numlock_warning = false
	_shift_up_frame = -100
	for light: KeyLight in _lights:
		var codes: PackedInt32Array = PackedInt32Array()
		var names: PackedStringArray = PackedStringArray()
		for event: InputEvent in Settings.get_slot_bindings(light.slot, light.action, Defs.Device.KEYBOARD):
			var bound: InputEventKey = event as InputEventKey
			if bound == null:
				continue
			codes.append(int(bound.physical_keycode if bound.physical_keycode != KEY_NONE else bound.keycode))
			names.append(UiGlyphs.key_text(bound))
		_keys[light] = codes
		light.key_text = names[0] if not names.is_empty() else ""
		light.queue_redraw()
	_hint.visible = _uses_numpad()
	_update_lights()


## True while the key of `action` of player `slot` (0 = P1, 1 = P2) is held.
func is_lit(slot: int, action: StringName) -> bool:
	for light: KeyLight in _lights:
		if light.slot == slot and light.action == action:
			return light.lit
	return false


## True while every light of the combination of both players is lit.
func all_lit() -> bool:
	for light: KeyLight in _lights:
		if not light.small and not light.lit:
			return false
	return true


## Text of the status line.
func get_status_text() -> String:
	return _status.text


func _player_column(slot: int) -> VBoxContainer:
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 3)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tag: Label = UiPlayers.tag_label(slot)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(tag)
	var grid: GridContainer = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override(&"h_separation", 4)
	grid.add_theme_constant_override(&"v_separation", 4)
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for action: StringName in COMBO:
		var light: KeyLight = KeyLight.new(slot, action, false)
		light.caption = tr(str(OptionsPanel.ACTION_KEYS.get(action, String(action))))
		grid.add_child(light)
		_lights.append(light)
	column.add_child(grid)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 4)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for action: StringName in OTHERS:
		var small: KeyLight = KeyLight.new(slot, action, true)
		row.add_child(small)
		_lights.append(small)
	column.add_child(row)
	return column


func _update_lights() -> void:
	for light: KeyLight in _lights:
		var on: bool = false
		for code: int in _keys.get(light, PackedInt32Array()):
			if held.has(code) or Input.is_physical_key_pressed(code as Key):
				on = true
				break
		light.set_lit(on)
	if all_lit() and not has_passed:
		has_passed = true
		Audio.play_sfx(Sfx.CODE_ACCEPT)
		passed.emit()
	if numlock_warning:
		_status.text = tr("UI_KEYTEST_NUMLOCK")
		_status.add_theme_color_override(&"font_color", UiKit.COL_BAD)
	elif has_passed:
		_status.text = tr("UI_KEYTEST_PASSED")
		_status.add_theme_color_override(&"font_color", UiKit.COL_GOOD)
	else:
		_status.text = tr("UI_KEYTEST_HOLD")
		_status.add_theme_color_override(&"font_color", UiKit.COL_CREAM)


## True when a half of the test has Shift on a key (the classic layout: P1's strike).
func _shift_bound() -> bool:
	for light: KeyLight in _lights:
		if (_keys.get(light, PackedInt32Array()) as PackedInt32Array).has(KEY_SHIFT):
			return true
	return false


## True when a key of the test lies on the numeric keypad (the classic layout's P2).
func _uses_numpad() -> bool:
	for light: KeyLight in _lights:
		for code: int in _keys.get(light, PackedInt32Array()):
			if UiGlyphs.is_numpad(code as Key):
				return true
	return false


func _on_setting_changed(key: String, _value: Variant) -> void:
	if key == Settings.PARTY_KEYBOARD_KEY or key == Settings.BINDINGS_KEY:
		start()


func _on_visibility_changed() -> void:
	if is_visible_in_tree():
		start()
