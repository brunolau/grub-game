class_name UiPrompts
extends HBoxContainer
## The hint row of a screen: "[ENTER] SELECT   [ESC] BACK", with the glyphs of the device in use.
##
## Owner: ui (docs/ARCHITECTURE.md 8.6: input-glyph switching). The row rebuilds itself on
## `GameInput.device_changed` and when bindings change. A hint with a callback is also a button: a mouse click or
## a tap on it performs the action. With touch as the active device the key caps disappear, legends without a
## callback are hidden and the remaining hints are drawn as framed buttons with a comfortable touch height.

const TOUCH_HEIGHT: int = 32

var _actions: Array[StringName] = []
var _texts: PackedStringArray = PackedStringArray()
var _callbacks: Array[Callable] = []


func _init() -> void:
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override(&"separation", 18)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	GameInput.device_changed.connect(_on_device_changed)
	Settings.changed.connect(_on_setting_changed)
	_rebuild()


## Add a hint: the glyph of `action`, the text `key` (a translation key) and what a click / tap on it does.
## Without a valid `callback` the hint is a plain legend.
func add_hint(action: StringName, key: String, callback: Callable = Callable()) -> void:
	_actions.append(action)
	_texts.append(key)
	_callbacks.append(callback)
	if is_inside_tree():
		_rebuild()


## The glyph text currently shown for hint `index` ("" with touch).
func get_glyph_text(index: int) -> String:
	if index < 0 or index >= _actions.size():
		return ""
	return UiGlyphs.action_text(_actions[index], GameInput.get_glyph_set())


func _on_device_changed(_device: int) -> void:
	_rebuild()


func _on_setting_changed(key: String, _value: Variant) -> void:
	if key == "controls/bindings":
		_rebuild()


func _rebuild() -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	var glyph_set: String = GameInput.get_glyph_set()
	var touch: bool = glyph_set == UiGlyphs.SET_TOUCH
	for i: int in _actions.size():
		var callback: Callable = _callbacks[i]
		if touch and not callback.is_valid():
			continue
		add_child(_make_hint(_actions[i], _texts[i], callback, glyph_set))


func _make_hint(action: StringName, key: String, callback: Callable, glyph_set: String) -> Control:
	var touch: bool = glyph_set == UiGlyphs.SET_TOUCH
	var hint: PanelContainer = PanelContainer.new()
	var style: StyleBox = StyleBoxEmpty.new()
	if touch:
		var plate: StyleBoxFlat = UiKit.plate(UiKit.COL_SHADE, 0)
		plate.content_margin_left = 12.0
		plate.content_margin_right = 12.0
		plate.set_border_width_all(2)
		plate.border_color = UiKit.COL_CREAM
		style = plate
		hint.custom_minimum_size = Vector2(float(UiKit.TOUCH_TARGET), float(TOUCH_HEIGHT))
	hint.add_theme_stylebox_override(&"panel", style)
	if callback.is_valid():
		hint.mouse_filter = Control.MOUSE_FILTER_STOP
		hint.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		hint.gui_input.connect(_on_hint_input.bind(callback))
	else:
		hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 5)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var event: InputEvent = null if touch else UiGlyphs.action_event(action, glyph_set)
	if event != null:
		row.add_child(_make_badge(event))
	var text: Label = UiKit.label(key, UiKit.Style.SMALL)
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(text)
	hint.add_child(row)
	return hint


func _make_badge(event: InputEvent) -> Control:
	var badge: PanelContainer = PanelContainer.new()
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBoxFlat = UiKit.plate(UiGlyphs.event_color(event), 0)
	style.content_margin_left = 4.0
	style.content_margin_right = 3.0
	style.content_margin_top = 3.0
	style.content_margin_bottom = 2.0
	style.set_border_width_all(1)
	style.border_width_bottom = 2
	style.border_color = UiKit.COL_INK
	badge.add_theme_stylebox_override(&"panel", style)
	var text: Label = UiKit.label(UiGlyphs.event_text(event), UiKit.Style.MONO)
	text.add_theme_color_override(&"font_color", UiKit.COL_INK)
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	badge.add_child(text)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return badge


func _on_hint_input(event: InputEvent, callback: Callable) -> void:
	if UiKit.is_tap(event) and callback.is_valid():
		accept_event()
		callback.call()
