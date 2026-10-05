class_name UiButton
extends Button
## A menu entry: outlined capitals, a bobbing arrow while focused, cursor and confirm sounds.
##
## Owner: ui. Works with keyboard and gamepad (focus + ui_accept), mouse (moving over it takes the focus) and touch (tap).
## The entry is at least as wide as its text plus room for the arrow on both sides, so a menu panel always has room
## for the arrow of its longest entry (it used to stick out of the pause panel at "Back to checkpoint").

const ARROW_GAP: int = 6
const BOB_SPEED: float = 7.0
const BOB_PX: float = 2.0

## Sound played when the entry is pressed ("" = none).
var press_sound: StringName = Sfx.MENU_SELECT

var _arrow: Texture2D = UiKit.icon(UiKit.ICON_RIGHT)
var _time: float = 0.0


func _init(key: String = "") -> void:
	text = key
	flat = true
	focus_mode = Control.FOCUS_ALL
	custom_minimum_size = Vector2(0.0, float(UiKit.row_height()))
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	set_process(false)
	gui_input.connect(_on_gui_input)
	focus_entered.connect(_on_focus_entered)
	focus_exited.connect(_on_focus_exited)
	pressed.connect(_on_pressed)


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_READY, NOTIFICATION_THEME_CHANGED, NOTIFICATION_TRANSLATION_CHANGED:
			_reserve_arrow_room()


## Minimum width: the text and the arrow with its gap on both sides (the text stays centred).
func _reserve_arrow_room() -> void:
	var font: Font = get_theme_font(&"font")
	if font == null or _arrow == null:
		return
	var text_width: float = font.get_string_size(atr(text), HORIZONTAL_ALIGNMENT_LEFT, -1.0,
			get_theme_font_size(&"font_size")).x
	custom_minimum_size.x = ceilf(text_width + 2.0 * (_arrow.get_size().x + float(ARROW_GAP) + BOB_PX))


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	if not has_focus() or _arrow == null:
		return
	var text_width: float = get_theme_font(&"font").get_string_size(
		atr(text), HORIZONTAL_ALIGNMENT_LEFT, -1.0, get_theme_font_size(&"font_size")
	).x
	var bob: float = roundf(sin(_time * BOB_SPEED) * BOB_PX)
	var arrow_size: Vector2 = _arrow.get_size()
	var left: float = (size.x - text_width) * 0.5
	if alignment == HORIZONTAL_ALIGNMENT_LEFT:
		left = 0.0
	elif alignment == HORIZONTAL_ALIGNMENT_RIGHT:
		left = size.x - text_width
	var pos: Vector2 = Vector2(
		roundf(left - arrow_size.x - float(ARROW_GAP) + bob), roundf((size.y - arrow_size.y) * 0.5)
	)
	draw_texture(_arrow, pos)


## The pointer takes the focus when it MOVES over the button. (Not on mouse_entered: that also fires when a screen
## appears under a resting pointer, and the keyboard focus would jump to whatever entry lies there - Quit included.)
func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and not disabled and not has_focus():
		grab_focus()


func _on_focus_entered() -> void:
	_time = 0.0
	set_process(true)
	UiKit.play_focus_sound()
	queue_redraw()


func _on_focus_exited() -> void:
	set_process(false)
	queue_redraw()


func _on_pressed() -> void:
	if press_sound != &"":
		Audio.play_sfx(press_sound)
