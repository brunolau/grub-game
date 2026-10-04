class_name UiCard
extends Button
## A big choice card: picture, caption and a short description on the menu panel (mode select).
##
## Owner: ui. Behaves like a button for keyboard, gamepad, mouse and touch; the focused card is lifted and lit,
## the others are dimmed.

const LIFT_PX: float = 6.0
const DIM: Color = Color(0.72, 0.72, 0.72, 1.0)

var _body: Control = null
var _caption: Label = null
var _lift: Tween = null


func _init(picture: Texture2D = null, caption_key: String = "", description_key: String = "") -> void:
	flat = true
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	custom_minimum_size = Vector2(250.0, 190.0)
	_body = Control.new()
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.set_anchors_preset(Control.PRESET_FULL_RECT)
	_body.modulate = DIM
	add_child(_body)
	var back: NinePatchRect = UiKit.panel()
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	_body.add_child(back)
	var margin: MarginContainer = MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side: StringName in [&"margin_left", &"margin_top", &"margin_right", &"margin_bottom"]:
		margin.add_theme_constant_override(side, 12)
	_body.add_child(margin)
	var column: VBoxContainer = VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override(&"separation", 2)
	margin.add_child(column)
	var image: TextureRect = UiKit.picture(picture)
	image.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(image)
	_caption = UiKit.label(caption_key, UiKit.Style.HUD, HORIZONTAL_ALIGNMENT_CENTER)
	column.add_child(_caption)
	var description: Label = UiKit.label(description_key, UiKit.Style.BODY, HORIZONTAL_ALIGNMENT_CENTER)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.size_flags_vertical = Control.SIZE_EXPAND_FILL
	description.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	column.add_child(description)
	focus_entered.connect(_on_focus_changed.bind(true))
	focus_exited.connect(_on_focus_changed.bind(false))
	mouse_entered.connect(_on_mouse_entered)
	pressed.connect(_on_pressed)


func _on_focus_changed(focused: bool) -> void:
	if focused:
		UiKit.play_focus_sound()
	_caption.add_theme_color_override(&"font_color", UiKit.COL_FOCUS if focused else UiKit.COL_TEXT)
	if _lift != null and _lift.is_valid():
		_lift.kill()
	_lift = create_tween().set_parallel(true)
	_lift.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_lift.tween_property(_body, "position:y", -LIFT_PX if focused else 0.0, 0.18)
	_lift.tween_property(_body, "modulate", Color.WHITE if focused else DIM, 0.18)


func _on_mouse_entered() -> void:
	if not has_focus():
		grab_focus()


func _on_pressed() -> void:
	Audio.play_sfx(Sfx.MENU_SELECT)
