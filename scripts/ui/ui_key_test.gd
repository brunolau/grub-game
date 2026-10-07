class_name UiKeyTest
extends VBoxContainer
## The two-player keyboard test (DESIGN.md D.11, PLAN.md P1.12 / P4.3): many keyboards cannot report every
## combination of held keys ("ghosting"), so both players hold Left + Jump + Strike + Swap at once and all eight
## lights must stay lit. Every other key of both halves lights too, so a player can check his whole cluster.
##
## Owner: ui-B. Part of the options bindings page; ui-A's join panel / versus lobby embed it as well. On the options
## page the keys are the two keyboard halves of the binding profiles of P1 and P2 (Settings.get_slot_bindings, the
## layout of "controls/party_keyboard"). A host with seated players calls [method set_players]: the columns are then
## those players in join order (the first to join is P1 whatever half he took), each lit by his own keys, and a half
## nobody sits at follows as a "Free" column with the layout's keys for it, so the ghosting check works before the
## second player joins. Keys are read by physical position, so the numpad works whatever the NumLock state.
## Windows quirk it detects: with NumLock ON, a numpad key pressed while Shift is held makes Windows lift Shift (and
## press it again afterwards) - that drops the action of a player who bound Shift (the classic preset keeps Shift free:
## P1 strikes with Left Ctrl); the test then says "switch Num Lock off".
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

	## Player slot of the column (its colour), -1 = a free keyboard half (cream).
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
		var lit_colour: Color = UiPlayers.colour(slot) if slot >= 0 else UiKit.COL_CREAM
		draw_rect(face, lit_colour if lit else Color(UiKit.COL_INK.lightened(0.18)))
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

## The columns shown: [player slot (-1 = a free half), keyboard half (Defs.InputSlotKind; NONE = the slot's profile
## as the options page reads it)] each.
var columns: Array[Vector2i] = []

var _lights: Array[KeyLight] = []
var _keys: Dictionary = {}           # KeyLight -> PackedInt32Array of physical keycodes
var _columns_box: HBoxContainer = null
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
	_columns_box = HBoxContainer.new()
	_columns_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_columns_box.add_theme_constant_override(&"separation", 20)
	_columns_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_columns_box)
	var profiles: Array[Vector2i] = []
	for slot: int in PLAYERS:
		profiles.append(Vector2i(slot, Defs.InputSlotKind.NONE))
	_build_columns(profiles)
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


## Read the keys of the columns again and clear the lights.
func start() -> void:
	held.clear()
	has_passed = false
	numlock_warning = false
	_shift_up_frame = -100
	for c: int in columns.size():
		for light: KeyLight in _column_lights(c):
			var codes: PackedInt32Array = PackedInt32Array()
			var names: PackedStringArray = PackedStringArray()
			for bound: InputEventKey in _column_keys(columns[c], light.action):
				codes.append(int(bound.physical_keycode if bound.physical_keycode != KEY_NONE else bound.keycode))
				names.append(UiGlyphs.key_text(bound))
			_keys[light] = codes
			light.key_text = names[0] if not names.is_empty() else ""
			light.queue_redraw()
	_hint.visible = _uses_numpad()
	_update_lights()


## Show the seated keyboard players `slots`, in this order (the hosts pass them in join = slot order): one column per
## player whose input slot is a keyboard half, tagged and coloured for his slot and lit by his own keys (his generated
## actions); then each keyboard half nobody sits at as a "Free" column with the layout's keys of that half. PLAYERS
## columns at most. A player on a pad or touch gets no column.
func set_players(slots: PackedInt32Array) -> void:
	var wanted: Array[Vector2i] = []
	var taken: Array[int] = []
	for slot: int in slots:
		if slot < 0 or slot >= Defs.MAX_PLAYERS:
			continue
		var half: int = GameInput.get_slot(slot).keyboard_half()
		if (half == Defs.InputSlotKind.KEYBOARD_LEFT or half == Defs.InputSlotKind.KEYBOARD_RIGHT) \
				and not taken.has(half):
			wanted.append(Vector2i(slot, half))
			taken.append(half)
	for half: int in [Defs.InputSlotKind.KEYBOARD_LEFT, Defs.InputSlotKind.KEYBOARD_RIGHT]:
		if not taken.has(half):
			wanted.append(Vector2i(-1, half))
	_build_columns(wanted.slice(0, PLAYERS))
	start()


## The tag shown on top of column `column` ("P1", "Free"; "" past the last column).
func get_column_tag(column: int) -> String:
	if column < 0 or column >= _columns_box.get_child_count():
		return ""
	var tag: Label = _columns_box.get_child(column).get_child(0) as Label
	return tag.text if tag != null else ""


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


## Replace the columns by `wanted` ([slot, half] each, see [member columns]).
func _build_columns(wanted: Array[Vector2i]) -> void:
	for child: Node in _columns_box.get_children():
		_columns_box.remove_child(child)
		child.queue_free()
	_lights.clear()
	_keys.clear()
	columns = wanted.duplicate()
	for column: Vector2i in columns:
		_columns_box.add_child(_player_column(column.x))


## The lights of column `c` (COMBO first, then OTHERS).
func _column_lights(c: int) -> Array[KeyLight]:
	var per_column: int = COMBO.size() + OTHERS.size()
	var result: Array[KeyLight] = []
	for i: int in per_column:
		if c * per_column + i < _lights.size():
			result.append(_lights[c * per_column + i])
	return result


## The keys of `action` for a column: the options page reads the slot's binding profile as before; a seated player
## his generated action (else his profile on his half); a free half the layout's keys of that half.
func _column_keys(column: Vector2i, action: StringName) -> Array[InputEventKey]:
	var result: Array[InputEventKey] = []
	var slot: int = column.x
	var half: int = column.y
	if slot >= 0:
		var generated: StringName = GameInput.slot_action(slot, action)
		if half != Defs.InputSlotKind.NONE and InputMap.has_action(generated):
			for event: InputEvent in InputMap.action_get_events(generated):
				if event is InputEventKey:
					result.append(event as InputEventKey)
		if result.is_empty():
			var bound: Array[InputEvent] = Settings.get_slot_bindings(slot, action, Defs.Device.KEYBOARD) \
					if half == Defs.InputSlotKind.NONE else Settings.get_slot_bindings(slot, action, Defs.Device.KEYBOARD, half)
			for event: InputEvent in bound:
				if event is InputEventKey:
					result.append(event as InputEventKey)
		return result
	for code: Key in InputSlot.default_keys(GameInput.keyboard_layout(), half, action):
		var key: InputEventKey = InputEventKey.new()
		key.physical_keycode = code
		result.append(key)
	return result


func _player_column(slot: int) -> VBoxContainer:
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 3)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tag: Label = UiPlayers.tag_label(slot) if slot >= 0 else UiKit.label(tr("UI_JOIN_FREE"), UiKit.Style.HUD)
	if slot < 0:
		tag.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		tag.add_theme_color_override(&"font_color", UiKit.COL_CREAM)
		tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
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


## True when a column of the test has Shift on a key (a player who bound it himself: the classic layout keeps Shift
## free since P1 strikes with Left Ctrl).
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
