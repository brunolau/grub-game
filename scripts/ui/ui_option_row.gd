class_name UiOptionRow
extends Control
## One row of a settings list: a caption on the left, a value on the right.
##
## Owner: ui. Four kinds: ACTION (a plain entry), TOGGLE (on / off), CHOICE (one of several texts) and SLIDER
## (0..steps pips). Keyboard / gamepad: focus the row, Left / Right change the value, the confirm button
## activates an ACTION, flips a TOGGLE and advances a CHOICE. Mouse / touch: tap an ACTION or TOGGLE row; tap the
## left or right half of the value of a CHOICE; tap a pip of a SLIDER (or beside the pips to step).

## The value changed (TOGGLE: 0 / 1, CHOICE: option index, SLIDER: 0..steps).
signal changed(index: int)
## An ACTION row was activated.
signal activated

enum Kind { ACTION, TOGGLE, CHOICE, SLIDER }

const PAD: int = 10
const PIP_W: int = 7
const PIP_H: int = 14
const PIP_GAP: int = 2
const ARROW_W: int = 16
## A press that moved further than this (art px) before its release was a scroll gesture, not a tap.
const TAP_SLOP: float = 8.0

## Row kind (Kind).
var kind: int = Kind.ACTION
## Translation key of the caption.
var caption: String = ""
## Current value, see [signal changed].
var index: int = 0
## Texts (translation keys or final texts) of a CHOICE.
var options: PackedStringArray = PackedStringArray()
## Number of pips of a SLIDER.
var steps: int = 10
## Smallest value a SLIDER can be set to.
var min_index: int = 0
## Extra text shown instead of the value of an ACTION row (final text, e.g. a key name).
var value_text: String = ""
## Draw `value_text` in the 8 px bitmap face at 16 px (key names: the HUD font's Z looks like a 2).
var value_mono: bool = false

var _font: Font = UiKit.font(UiKit.Style.HUD)
var _mono: Font = UiKit.font(UiKit.Style.MONO)
var _press_pos: Vector2 = Vector2.INF


func _init(p_kind: int = Kind.ACTION, p_caption: String = "") -> void:
	kind = p_kind
	caption = p_caption
	focus_mode = Control.FOCUS_ALL
	# PASS: a drag that starts on a row still scrolls the list it is in.
	mouse_filter = Control.MOUSE_FILTER_PASS
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	custom_minimum_size = Vector2(300.0, float(UiKit.row_height()))
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	focus_entered.connect(_on_focus_entered)
	focus_exited.connect(queue_redraw)


## A plain entry.
static func action(p_caption: String) -> UiOptionRow:
	return UiOptionRow.new(Kind.ACTION, p_caption)


## An on / off switch.
static func toggle(p_caption: String, on: bool) -> UiOptionRow:
	var row: UiOptionRow = UiOptionRow.new(Kind.TOGGLE, p_caption)
	row.index = 1 if on else 0
	return row


## One of several texts.
static func choice(p_caption: String, p_options: PackedStringArray, p_index: int) -> UiOptionRow:
	var row: UiOptionRow = UiOptionRow.new(Kind.CHOICE, p_caption)
	row.options = p_options
	row.index = clampi(p_index, 0, maxi(0, p_options.size() - 1))
	return row


## A stepped value 0..p_steps.
static func slider(p_caption: String, p_steps: int, p_value: int) -> UiOptionRow:
	var row: UiOptionRow = UiOptionRow.new(Kind.SLIDER, p_caption)
	row.steps = maxi(1, p_steps)
	row.index = clampi(p_value, 0, row.steps)
	return row


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	# The pointer takes the focus when it moves over the row (not when the row appears under a resting pointer).
	if event is InputEventMouseMotion:
		if not has_focus():
			grab_focus()
		return
	# ACTION rows leave Left / Right to the focus navigation.
	if kind != Kind.ACTION and event.is_action_pressed(&"ui_left", true):
		accept_event()
		step(-1)
	elif kind != Kind.ACTION and event.is_action_pressed(&"ui_right", true):
		accept_event()
		step(1)
	elif event.is_action_pressed(&"ui_accept") and not event.is_echo():
		accept_event()
		activate()
	else:
		var click: InputEventMouseButton = event as InputEventMouseButton
		if click == null or click.button_index != MOUSE_BUTTON_LEFT:
			return
		if click.pressed:
			_press_pos = click.position
		elif _press_pos.distance_to(click.position) <= TAP_SLOP:
			accept_event()
			_press_pos = Vector2.INF
			_on_tap(click.position.x)


func _draw() -> void:
	var focused: bool = has_focus()
	if focused:
		draw_rect(Rect2(Vector2.ZERO, size), Color(UiKit.COL_INK, 0.35))
	var color: Color = UiKit.COL_FOCUS if focused else UiKit.COL_TEXT
	var baseline: float = roundf((size.y - float(UiKit.SIZE_HUD)) * 0.5) + _font.get_ascent(UiKit.SIZE_HUD)
	var right: float = size.x - float(PAD)
	var caption_room: float = right - float(PAD) - _value_width() - 12.0
	draw_string(_font, Vector2(float(PAD), baseline), _fit(atr(caption), caption_room), HORIZONTAL_ALIGNMENT_LEFT,
			-1.0, UiKit.SIZE_HUD, color)
	match kind:
		Kind.ACTION:
			if value_text != "" and value_mono:
				var mono_size: int = UiKit.SIZE_MONO * 2
				var mono_width: float = _mono_width()
				var mono_base: float = roundf((size.y - float(mono_size)) * 0.5) + _mono.get_ascent(mono_size)
				var mono_pos: Vector2 = Vector2(roundf(right - mono_width), mono_base)
				draw_string_outline(_mono, mono_pos, value_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, mono_size, 4,
						UiKit.COL_INK)
				draw_string(_mono, mono_pos, value_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, mono_size, color)
			elif value_text != "":
				_draw_right(value_text, right, baseline, color)
		Kind.TOGGLE:
			var on: bool = index != 0
			_draw_right(atr("UI_ON") if on else atr("UI_OFF"), right, baseline,
					UiKit.COL_GOOD if on else UiKit.COL_BAD)
		Kind.CHOICE:
			var text: String = atr(options[index]) if index < options.size() else ""
			var arrow_color: Color = color if focused else UiKit.COL_DIM
			_draw_right(">", right, baseline, arrow_color)
			var width: float = _draw_right(text, right - float(ARROW_W), baseline, color)
			_draw_right("<", right - float(ARROW_W) - width - 2.0, baseline, arrow_color)
		Kind.SLIDER:
			var area: Rect2 = _pips_rect()
			for i: int in steps:
				var pip: Rect2 = Rect2(
					area.position.x + float(i * (PIP_W + PIP_GAP)), area.position.y, float(PIP_W), float(PIP_H)
				)
				draw_rect(pip.grow(2.0), UiKit.COL_INK)
				draw_rect(pip, (UiKit.COL_FOCUS if focused else UiKit.COL_CREAM) if i < index
						else Color(UiKit.COL_INK.lightened(0.25)))


## Change the value by `direction` steps (-1 / +1). ACTION rows ignore it.
func step(direction: int) -> void:
	match kind:
		Kind.TOGGLE:
			set_index(1 - index, true)
		Kind.CHOICE:
			if options.size() > 1:
				set_index(posmod(index + direction, options.size()), true)
		Kind.SLIDER:
			set_index(clampi(index + direction, min_index, steps), true)


## The confirm button on this row.
func activate() -> void:
	match kind:
		Kind.ACTION:
			Audio.play_sfx(Sfx.MENU_SELECT)
			activated.emit()
		Kind.TOGGLE, Kind.CHOICE:
			step(1)


## Set the value; with `notify` the change is announced (signal + sound) when it differs.
func set_index(value: int, notify: bool = false) -> void:
	if value == index:
		return
	index = value
	queue_redraw()
	if notify:
		changed.emit(index)
		Audio.play_sfx(Sfx.MENU_SELECT)


func _draw_right(text: String, right: float, baseline: float, color: Color) -> float:
	var width: float = _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, UiKit.SIZE_HUD).x
	draw_string(_font, Vector2(roundf(right - width), baseline), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0,
			UiKit.SIZE_HUD, color)
	return width


## Width the value part of the row needs.
func _value_width() -> float:
	match kind:
		Kind.ACTION:
			if value_text == "":
				return 0.0
			return _mono_width() if value_mono else _text_width(value_text)
		Kind.TOGGLE:
			return maxf(_text_width(atr("UI_ON")), _text_width(atr("UI_OFF")))
		Kind.CHOICE:
			var widest: float = 0.0
			for option: String in options:
				widest = maxf(widest, _text_width(atr(option)))
			return widest + float(ARROW_W) * 2.0
		_:
			return _pips_rect().size.x + 4.0


func _mono_width() -> float:
	return _mono.get_string_size(value_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, UiKit.SIZE_MONO * 2).x


func _text_width(text: String) -> float:

	return _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, UiKit.SIZE_HUD).x


## `text`, shortened with ".." when it is wider than `room`.
func _fit(text: String, room: float) -> String:
	if _text_width(text) <= room:
		return text
	var shortened: String = text
	while shortened.length() > 1 and _text_width(shortened + "..") > room:
		shortened = shortened.left(shortened.length() - 1)
	return shortened.strip_edges() + ".."


func _pips_rect() -> Rect2:
	var width: float = float(steps * (PIP_W + PIP_GAP) - PIP_GAP)
	return Rect2(size.x - float(PAD) - 2.0 - width, roundf((size.y - float(PIP_H)) * 0.5), width, float(PIP_H))


func _on_tap(x: float) -> void:
	if not has_focus():
		grab_focus()
	match kind:
		Kind.ACTION, Kind.TOGGLE:
			activate()
		Kind.CHOICE:
			step(-1 if x < size.x * 0.75 and x > size.x * 0.5 else 1)
		Kind.SLIDER:
			var area: Rect2 = _pips_rect()
			if x < area.position.x:
				step(-1)
			elif x > area.end.x:
				step(1)
			else:
				set_index(clampi(ceili((x - area.position.x) / float(PIP_W + PIP_GAP)), min_index, steps), true)


func _on_focus_entered() -> void:
	UiKit.play_focus_sound()
	queue_redraw()


