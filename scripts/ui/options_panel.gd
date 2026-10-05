class_name OptionsPanel
extends VBoxContainer
## The settings menu, shared by the options screen and the pause menu (docs/ARCHITECTURE.md 8.6).
##
## Owner: ui. Every change is applied at once through `Settings.set_value` / `Settings.set_binding` and written to
## disk when the panel closes. Pages: the main list (audio, video, gameplay, touch where a touch screen can be used,
## language, reset), the
## button bindings (keyboard and gamepad) and a yes / no confirmation. The host forwards "back" to
## [method go_back] and listens to [signal closed].

## The player left the panel (settings are saved).
signal closed

## Settings key of the touch layout (`standard` | `swapped`, Settings.DEFAULTS).
const KEY_TOUCH_LAYOUT: String = "controls/touch_layout"
const TOUCH_LAYOUTS: PackedStringArray = ["standard", "swapped"]
const TOUCH_SCALES: Array[float] = [1.0, 1.25, 1.5]
const LISTEN_SECONDS: float = 5.0
const VOLUME_STEPS: int = 10
## Smallest room the lists get (art px); they always show a whole number of rows (see [method list_height]).
const LIST_HEIGHT: float = 210.0
## Space a host needs around the lists (title row, panel padding, prompts, margins): fit_height(view - this).
const CHROME_HEIGHT: float = 150.0

## Action -> caption key of the bindings page.
const ACTION_KEYS: Dictionary = {
	&"move_left": "UI_ACTION_LEFT", &"move_right": "UI_ACTION_RIGHT", &"move_up": "UI_ACTION_UP",
	&"move_down": "UI_ACTION_DOWN", &"jump": "UI_ACTION_JUMP", &"attack": "UI_ACTION_ATTACK",
	&"look": "UI_ACTION_LOOK", &"pause": "UI_ACTION_PAUSE",
}

## Action being rebound (empty when not listening).
var listening_action: StringName = &""

var _title: Label = null
var _main_page: ScrollContainer = null
var _bind_page: ScrollContainer = null
var _confirm_page: VBoxContainer = null
var _confirm_text: Label = null
var _confirm_yes: UiButton = null
var _confirm_action: Callable = Callable()
var _confirm_return: Control = null
var _rows: Dictionary = {}           # settings key -> UiOptionRow
var _bind_rows: Dictionary = {}      # action -> UiOptionRow
var _locales: PackedStringArray = PackedStringArray()
var _listen_row: UiOptionRow = null
var _listen_left: float = 0.0
var _bindings_entry: UiOptionRow = null


func _init() -> void:
	UiKit.ensure_locale()
	add_theme_constant_override(&"separation", 6)
	custom_minimum_size = Vector2(400.0, 0.0)
	_title = UiKit.label("UI_OPTIONS_HEADING", UiKit.Style.HUD, HORIZONTAL_ALIGNMENT_CENTER)
	_title.add_theme_color_override(&"font_color", UiKit.COL_FOCUS)
	add_child(_title)
	_main_page = _make_page()
	_build_main(_main_page.get_child(0) as VBoxContainer)
	_bind_page = _make_page()
	_build_bindings(_bind_page.get_child(0) as VBoxContainer)
	_bind_page.visible = false
	_confirm_page = _build_confirm()
	_confirm_page.visible = false
	add_child(_confirm_page)


func _ready() -> void:
	Settings.changed.connect(_on_setting_changed)
	set_process(false)


func _process(delta: float) -> void:
	_listen_left -= delta
	if _listen_left <= 0.0:
		stop_listening()
	elif _listen_row != null:
		_listen_row.value_text = tr("UI_BIND_PRESS").format({"seconds": ceili(_listen_left)})
		_listen_row.queue_redraw()


func _input(event: InputEvent) -> void:
	if listening_action == &"" or not is_visible_in_tree():
		return
	if event.is_echo() or not event.is_pressed():
		return
	if event is InputEventKey and event.is_action_pressed(&"ui_cancel"):
		# The prompts show this key as "back": it cancels the wait instead of becoming a binding (taking Escape
		# would also move the pause action onto the replaced key). Pad buttons stay bindable.
		get_viewport().set_input_as_handled()
		stop_listening()
	elif Settings.is_bindable(event):
		get_viewport().set_input_as_handled()
		bind_event(listening_action, event)
	elif event is InputEventMouseButton or event is InputEventScreenTouch:
		get_viewport().set_input_as_handled()
		stop_listening()
	else:
		# Small stick motion must not move the focus away from the row that waits for an input.
		get_viewport().set_input_as_handled()


## Give the focus to the first row of the visible page.
func focus_first() -> void:
	var page: Control = _visible_page()
	if page == _confirm_page:
		UiKit.focus_silently(_confirm_yes)
		return
	var list: VBoxContainer = page.get_child(0) as VBoxContainer
	for child: Node in list.get_children():
		var control: Control = child as Control
		if control != null and control.focus_mode == Control.FOCUS_ALL and control.visible:
			UiKit.focus_silently(control)
			return


## "Back": cancel listening, leave the confirmation or the bindings page, or close the panel.
func go_back() -> void:
	if listening_action != &"":
		stop_listening()
		return
	Audio.play_sfx(Sfx.MENU_BACK)
	if _confirm_page.visible:
		_close_confirm()
	elif _bind_page.visible:
		_show_page(_main_page)
		UiKit.focus_silently(_bindings_entry)
	else:
		close()


## Save and announce that the panel is done.
func close() -> void:
	stop_listening()
	Settings.save()
	closed.emit()


## Let the lists use up to `height` art px (taller views show more rows); never less than LIST_HEIGHT.
func fit_height(height: float) -> void:
	var fitted: float = list_height(height)
	for page: Control in [_main_page, _bind_page, _confirm_page]:
		page.custom_minimum_size.y = fitted


## Height of a list in `room` art px: a whole number of rows (every heading and row is one row tall and the
## lists scroll row by row), so no row is ever cut in half at the top or bottom edge.
static func list_height(room: float) -> float:
	var row: int = UiKit.row_height()
	var rows: int = maxi(floori(LIST_HEIGHT / float(row)), floori(room / float(row)))
	return float(rows * row)


## The settings row of a key (null when the key has no row, e.g. fullscreen on phones).
func get_row(key: String) -> UiOptionRow:
	return _rows.get(key) as UiOptionRow


## The row of an action on the bindings page.
func get_binding_row(action: StringName) -> UiOptionRow:
	return _bind_rows.get(action) as UiOptionRow


## Wait for the next key or gamepad button and bind it to `action`.
func start_listening(action: StringName) -> void:
	listening_action = action
	_listen_row = get_binding_row(action)
	_listen_left = LISTEN_SECONDS
	set_process(true)
	_process(0.0)


## Stop waiting for a binding.
func stop_listening() -> void:
	listening_action = &""
	_listen_row = null
	set_process(false)
	_refresh_bindings()


## Bind `event` (key, gamepad button or stick direction) to `action`, replacing the action's first binding of the
## same device family (Settings.set_binding): another game action that used the same input gets the replaced input
## instead (swap), so no input is ever on two actions and no action is left without a binding.
func bind_event(action: StringName, event: InputEvent) -> void:
	if Settings.normalize_event(event) == null:
		return
	Settings.set_binding(action, event, 0)
	Audio.play_sfx(Sfx.CODE_ACCEPT)
	stop_listening()


func _make_page() -> ScrollContainer:
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	scroll.custom_minimum_size = Vector2(0.0, list_height(LIST_HEIGHT))
	scroll.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var list: VBoxContainer = VBoxContainer.new()
	list.add_theme_constant_override(&"separation", 0)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	add_child(scroll)
	var bar: VScrollBar = scroll.get_v_scroll_bar()
	bar.value_changed.connect(_snap_scroll.bind(bar))
	return scroll


## Keep a list scrolled by whole rows (wheel, drag, focus changes, scroll bar alike).
func _snap_scroll(value: float, bar: VScrollBar) -> void:
	var row: float = float(UiKit.row_height())
	var on_row: float = clampf(roundf(value / row) * row, 0.0, maxf(bar.max_value - bar.page, 0.0))
	if not is_equal_approx(on_row, value):
		bar.value = on_row  # emits value_changed once more, with a value that needs no snapping


func _build_main(list: VBoxContainer) -> void:
	_heading(list, "UI_OPT_AUDIO")
	_volume(list, "audio/master", "UI_OPT_MASTER")
	_volume(list, "audio/music", "UI_OPT_MUSIC")
	_volume(list, "audio/sfx", "UI_OPT_SFX")
	_heading(list, "UI_OPT_VIDEO")
	if not OS.has_feature("mobile") and not OS.has_feature("web"):
		_toggle(list, "video/fullscreen", "UI_OPT_FULLSCREEN")
		_toggle(list, "video/vsync", "UI_OPT_VSYNC")
	_toggle(list, "video/screen_shake", "UI_OPT_SHAKE")
	_toggle(list, "video/flash", "UI_OPT_FLASH")
	_toggle(list, "camera/smooth_follow", "UI_OPT_CAMERA")
	_heading(list, "UI_OPT_CONTROLS")
	_bindings_entry = UiOptionRow.action("UI_OPT_BINDINGS")
	_bindings_entry.value_text = ">"
	_bindings_entry.activated.connect(_open_bindings)
	list.add_child(_bindings_entry)
	_toggle(list, "controls/up_jumps", "UI_OPT_UP_JUMPS")
	_toggle(list, "controls/vibration", "UI_OPT_VIBRATION")
	# The touch section only where touch buttons can show: a touch screen, a phone, or buttons switched on.
	if touch_options_wanted():
		_heading(list, "UI_OPT_TOUCH")
		var show_row: UiOptionRow = UiOptionRow.choice("UI_OPT_TOUCH_SHOW",
				PackedStringArray(["UI_OPT_TOUCH_AUTO", "UI_OPT_TOUCH_ALWAYS"]),
				1 if Settings.get_bool("controls/touch_always") else 0)
		show_row.changed.connect(func(index: int) -> void: Settings.set_value("controls/touch_always", index == 1))
		_add_row(list, "controls/touch_always", show_row)
		var opacity: UiOptionRow = UiOptionRow.slider("UI_OPT_TOUCH_OPACITY", VOLUME_STEPS,
				roundi(Settings.get_float("controls/touch_opacity") * float(VOLUME_STEPS)))
		opacity.min_index = 2
		opacity.changed.connect(func(index: int) -> void:
			Settings.set_value("controls/touch_opacity", float(index) / float(VOLUME_STEPS)))
		_add_row(list, "controls/touch_opacity", opacity)
		var scale_row: UiOptionRow = UiOptionRow.choice("UI_OPT_TOUCH_SIZE",
				PackedStringArray(["100%", "125%", "150%"]), _scale_index(Settings.get_float("controls/touch_scale")))
		scale_row.changed.connect(func(index: int) -> void:
			Settings.set_value("controls/touch_scale", TOUCH_SCALES[index]))
		_add_row(list, "controls/touch_scale", scale_row)
		var layout_row: UiOptionRow = UiOptionRow.choice("UI_OPT_TOUCH_LAYOUT",
				PackedStringArray(["UI_OPT_TOUCH_STANDARD", "UI_OPT_TOUCH_SWAPPED"]),
				maxi(0, TOUCH_LAYOUTS.find(str(Settings.get_value(KEY_TOUCH_LAYOUT, TOUCH_LAYOUTS[0])))))
		layout_row.changed.connect(func(index: int) -> void: Settings.set_value(KEY_TOUCH_LAYOUT, TOUCH_LAYOUTS[index]))
		_add_row(list, KEY_TOUCH_LAYOUT, layout_row)
	_heading(list, "UI_OPT_GAME")
	_locales = PackedStringArray([""])
	_locales.append_array(UiKit.available_locales())
	var names: PackedStringArray = PackedStringArray(["UI_OPT_LANGUAGE_AUTO"])
	for i: int in range(1, _locales.size()):
		names.append(TranslationServer.get_locale_name(_locales[i]))
	var language: UiOptionRow = UiOptionRow.choice("UI_OPT_LANGUAGE", names,
			maxi(0, _locales.find(str(Settings.get_value("game/locale", "")))))
	language.changed.connect(func(index: int) -> void: Settings.set_value("game/locale", _locales[index]))
	_add_row(list, "game/locale", language)
	var reset: UiOptionRow = UiOptionRow.action("UI_OPT_RESET")
	reset.activated.connect(_ask.bind("UI_CONFIRM_RESET", _reset_settings, reset))
	list.add_child(reset)
	var erase: UiOptionRow = UiOptionRow.action("UI_OPT_ERASE")
	erase.activated.connect(_ask.bind("UI_CONFIRM_ERASE", _erase_progress, erase))
	list.add_child(erase)
	var back: UiOptionRow = UiOptionRow.action("UI_OPT_BACK")
	back.activated.connect(close)
	list.add_child(back)


func _build_bindings(list: VBoxContainer) -> void:
	for action: StringName in Defs.GAME_ACTIONS:
		var row: UiOptionRow = UiOptionRow.action(str(ACTION_KEYS.get(action, String(action))))
		row.value_mono = true
		row.activated.connect(start_listening.bind(action))
		list.add_child(row)
		_bind_rows[action] = row
	var reset: UiOptionRow = UiOptionRow.action("UI_OPT_RESET_BINDINGS")
	reset.activated.connect(_reset_bindings)
	list.add_child(reset)
	var back: UiOptionRow = UiOptionRow.action("UI_OPT_BACK")
	back.activated.connect(go_back)
	list.add_child(back)
	_refresh_bindings()


func _build_confirm() -> VBoxContainer:
	var page: VBoxContainer = VBoxContainer.new()
	page.custom_minimum_size = Vector2(0.0, list_height(LIST_HEIGHT))
	page.alignment = BoxContainer.ALIGNMENT_CENTER
	page.add_theme_constant_override(&"separation", 8)
	_confirm_text = UiKit.label("", UiKit.Style.BODY, HORIZONTAL_ALIGNMENT_CENTER)
	_confirm_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page.add_child(_confirm_text)
	_confirm_yes = UiButton.new("UI_YES")
	_confirm_yes.pressed.connect(_on_confirm_yes)
	page.add_child(_confirm_yes)
	var no: UiButton = UiButton.new("UI_NO")
	no.press_sound = Sfx.MENU_BACK
	no.pressed.connect(_close_confirm)
	page.add_child(no)
	return page


## True when the touch section belongs in the list: a touch screen exists, it is a mobile build, the touch buttons
## are switched on, or the last input was a touch. On a desktop without a touch screen it would be four rows of
## settings for buttons that never show.
static func touch_options_wanted() -> bool:
	if DisplayServer.is_touchscreen_available() or OS.has_feature("mobile"):
		return true
	return Settings.get_bool("controls/touch_always") or GameInput.device == Defs.Device.TOUCH


func _heading(list: VBoxContainer, key: String) -> void:
	var label: Label = UiKit.label(key, UiKit.Style.BODY)
	label.add_theme_color_override(&"font_color", UiKit.COL_FOCUS)
	# Exactly one row tall, so the list scrolls (and is cut) on row boundaries only.
	label.custom_minimum_size = Vector2(0.0, float(UiKit.row_height()))
	label.clip_text = true
	label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	list.add_child(label)


func _volume(list: VBoxContainer, key: String, caption: String) -> void:
	var row: UiOptionRow = UiOptionRow.slider(caption, VOLUME_STEPS, roundi(Settings.get_float(key) * VOLUME_STEPS))
	row.changed.connect(func(index: int) -> void: Settings.set_value(key, float(index) / float(VOLUME_STEPS)))
	_add_row(list, key, row)


func _toggle(list: VBoxContainer, key: String, caption: String) -> void:
	var row: UiOptionRow = UiOptionRow.toggle(caption, Settings.get_bool(key))
	row.changed.connect(func(index: int) -> void: Settings.set_value(key, index == 1))
	_add_row(list, key, row)


func _add_row(list: VBoxContainer, key: String, row: UiOptionRow) -> void:
	list.add_child(row)
	_rows[key] = row


func _scale_index(value: float) -> int:
	var best: int = 0
	for i: int in TOUCH_SCALES.size():
		if absf(TOUCH_SCALES[i] - value) < absf(TOUCH_SCALES[best] - value):
			best = i
	return best


## Show the row values of the current settings again (after a reset or a change made elsewhere).
func _sync_rows() -> void:
	for key: String in _rows:
		var row: UiOptionRow = _rows[key]
		match key:
			"audio/master", "audio/music", "audio/sfx":
				row.set_index(roundi(Settings.get_float(key) * VOLUME_STEPS))
			"controls/touch_opacity":
				row.set_index(roundi(Settings.get_float(key) * VOLUME_STEPS))
			"controls/touch_always":
				row.set_index(1 if Settings.get_bool(key) else 0)
			"controls/touch_scale":
				row.set_index(_scale_index(Settings.get_float(key)))
			KEY_TOUCH_LAYOUT:
				row.set_index(maxi(0, TOUCH_LAYOUTS.find(str(Settings.get_value(key, TOUCH_LAYOUTS[0])))))
			"game/locale":
				row.set_index(maxi(0, _locales.find(str(Settings.get_value(key, "")))))
			_:
				row.set_index(1 if Settings.get_bool(key) else 0)


func _refresh_bindings() -> void:
	for action: StringName in _bind_rows:
		var row: UiOptionRow = _bind_rows[action]
		var key: String = UiGlyphs.action_text(action, UiGlyphs.SET_KEYBOARD)
		var pad: String = UiGlyphs.action_text(action, UiGlyphs.SET_GAMEPAD)
		row.value_text = "%s / %s" % [key if key != "" else "-", pad if pad != "" else "-"]
		row.queue_redraw()


func _visible_page() -> Control:
	if _confirm_page.visible:
		return _confirm_page
	return _bind_page if _bind_page.visible else _main_page


func _show_page(page: Control) -> void:
	_main_page.visible = page == _main_page
	_bind_page.visible = page == _bind_page
	_confirm_page.visible = page == _confirm_page
	_title.text = "UI_OPT_BINDINGS" if page == _bind_page else "UI_OPTIONS_HEADING"


func _open_bindings() -> void:
	_show_page(_bind_page)
	focus_first()


func _ask(question: String, action: Callable, origin: Control) -> void:
	_confirm_text.text = question
	_confirm_action = action
	_confirm_return = origin
	_show_page(_confirm_page)
	UiKit.focus_silently(_confirm_yes)


func _close_confirm() -> void:
	_show_page(_main_page)
	if _confirm_return != null:
		UiKit.focus_silently(_confirm_return)


func _on_confirm_yes() -> void:
	if _confirm_action.is_valid():
		_confirm_action.call()
	_close_confirm()


func _reset_settings() -> void:
	Settings.reset()
	_sync_rows()
	_refresh_bindings()


func _erase_progress() -> void:
	Save.reset()


func _reset_bindings() -> void:
	Settings.reset_bindings()
	_refresh_bindings()


func _on_setting_changed(key: String, _value: Variant) -> void:
	if key == "controls/bindings":
		_refresh_bindings()
	elif key == "video/fullscreen" and _rows.has(key):
		get_row(key).set_index(1 if Settings.get_bool(key) else 0)

