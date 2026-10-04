class_name UiCodeSlot
extends Control
## One character of the four-character level code (GAMEPLAY.md 1.4) in carved-stone letters.
##
## Owner: ui. Keyboard / gamepad: Up / Down cycle through 0-9 and A-Z while the slot has the focus; typing a
## letter or digit sets it directly (the screen then moves the focus on). Mouse / touch: tap the upper half to
## step up, the lower half to step down.

## The character changed by the player.
signal character_changed
## A letter or digit was typed on the keyboard (the screen moves the focus to the next slot).
signal typed
## Backspace was pressed on an empty slot (the screen moves the focus back).
signal erased

const CHARSET: String = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"
const SLOT_SIZE: Vector2 = Vector2(44.0, 104.0)
const BOX_TOP: float = 26.0
const BOX_HEIGHT: float = 52.0

## Index into CHARSET, or -1 while the slot is empty.
var char_index: int = -1

var _font: Font = UiKit.font(UiKit.Style.TITLE)
var _up: Texture2D = UiKit.icon(UiKit.ICON_UP)
var _down: Texture2D = UiKit.icon(UiKit.ICON_DOWN)
var _time: float = 0.0


func _init() -> void:
	custom_minimum_size = SLOT_SIZE
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	focus_entered.connect(_on_focus_entered)
	focus_exited.connect(queue_redraw)
	set_process(false)


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_up", true):
		accept_event()
		cycle(1)
	elif event.is_action_pressed(&"ui_down", true):
		accept_event()
		cycle(-1)
	elif UiKit.is_tap(event):
		accept_event()
		grab_focus()
		var click: InputEventMouseButton = event as InputEventMouseButton
		cycle(1 if click.position.y < BOX_TOP + BOX_HEIGHT * 0.5 else -1)
	else:
		var key: InputEventKey = event as InputEventKey
		if key == null or not key.pressed or key.echo:
			return
		if key.keycode == KEY_BACKSPACE or key.keycode == KEY_DELETE:
			accept_event()
			if char_index < 0:
				erased.emit()
			else:
				set_character("")
				character_changed.emit()
			return
		var typed_char: String = String.chr(key.unicode).to_upper() if key.unicode > 0 else ""
		if typed_char != "" and CHARSET.contains(typed_char):
			accept_event()
			set_character(typed_char)
			Audio.play_sfx(Sfx.MENU_MOVE)
			character_changed.emit()
			typed.emit()


func _draw() -> void:
	var focused: bool = has_focus()
	var box: Rect2 = Rect2(0.0, BOX_TOP, size.x, BOX_HEIGHT)
	draw_rect(box, UiKit.COL_INK)
	draw_rect(box.grow(-2.0), Color(UiKit.COL_INK.lightened(0.18)))
	if focused:
		draw_rect(box, UiKit.COL_FOCUS, false, 2.0)
		var bob: float = roundf(absf(sin(_time * 6.0)) * 2.0)
		draw_texture(_up, Vector2(roundf((size.x - _up.get_width()) * 0.5), -bob - 4.0))
		draw_texture(_down, Vector2(roundf((size.x - _down.get_width()) * 0.5), BOX_TOP + BOX_HEIGHT - 4.0 + bob))
	var text: String = get_character()
	if text == "":
		draw_rect(Rect2(10.0, BOX_TOP + BOX_HEIGHT - 14.0, size.x - 20.0, 4.0), UiKit.COL_DIM)
		return
	var width: float = _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, UiKit.SIZE_TITLE).x
	var pos: Vector2 = Vector2(roundf((size.x - width) * 0.5), BOX_TOP + 8.0 + _font.get_ascent(UiKit.SIZE_TITLE))
	draw_string(_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, UiKit.SIZE_TITLE)


## The character shown ("" when empty).
func get_character() -> String:
	return CHARSET[char_index] if char_index >= 0 else ""


## Show `text` (one character of CHARSET, or "" to clear).
func set_character(text: String) -> void:
	char_index = CHARSET.find(text.to_upper()) if text.length() == 1 else -1
	queue_redraw()


## Step through CHARSET (+1 = next character); an empty slot starts at "0" going up and at "Z" going down.
func cycle(direction: int) -> void:
	if char_index < 0:
		char_index = 0 if direction > 0 else CHARSET.length() - 1
	else:
		char_index = posmod(char_index + direction, CHARSET.length())
	Audio.play_sfx(Sfx.MENU_MOVE)
	queue_redraw()
	character_changed.emit()


func _on_focus_entered() -> void:
	_time = 0.0
	set_process(true)
	UiKit.play_focus_sound()
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_FOCUS_EXIT:
		set_process(false)
