class_name OptionsPanel
extends VBoxContainer
## The settings menu, shared by the options screen and the pause menu (docs/ARCHITECTURE.md 8.6).
##
## Owner: ui-B. Every change is applied at once through `Settings.set_value` / `Settings.set_binding` and written to
## disk when the panel closes. Pages: the main list (audio, video, gameplay, touch where a touch screen can be used,
## language, reset), the button bindings (keyboard and gamepad), the two-player keyboard test and a yes / no
## confirmation. The host forwards "back" to [method go_back] and listens to [signal closed].
##
## Bindings of 2.0 (DESIGN.md D.11, PLAN.md P1.12): the page edits one binding profile at a time - "One player" (the
## single-player profile `[bindings]`) or P1..P4 (the party profiles `[bindings_p1]`..`[bindings_p4]`,
## Settings.set_slot_binding). For P1 / P2 it offers the three shared-keyboard presets of D.11 ("controls/
## party_keyboard": classic WASD + numpad - the versus default -, two hands, one hand); choosing one puts both halves
## back on the preset's keys (their pad buttons are kept). Swap is a row like the others. The keyboard test checks
## that a keyboard reports both players' keys at once ([UiKeyTest]).
##
## Co-op options of 2.0 (DESIGN.md D.3 / D.11, GAMEPLAY.md 13.9): "Rival score" - the HUD (and the tally) shows each
## player's own score instead of the tribe score - and "Helper mode" - P2 cannot be hurt by enemies (pits and liquids
## still egg him; gates are unchanged). Both are settings ([constant KEY_RIVAL_SCORE], [constant KEY_HELPER_MODE]);
## the rule of Helper mode is the hero's (player-A), read at the start of a co-op run (core-A).

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
	&"look": "UI_ACTION_LOOK", &"pause": "UI_ACTION_PAUSE", &"swap": "UI_ACTION_SWAP",
}
## The binding profile of the single-player game ([member bind_profile]); 0..3 are the party profiles P1..P4.
const PROFILE_SOLO: int = -1
## Caption keys of the shared-keyboard presets, by InputSlot.KeyboardLayout.
const LAYOUT_KEYS: PackedStringArray = ["UI_OPT_KEYS_CLASSIC", "UI_OPT_KEYS_TWO_HANDS", "UI_OPT_KEYS_ONE_HAND"]
## Pseudo settings keys of the rows of the bindings page (get_row()).
const ROW_PROFILE: String = "bindings/profile"
const ROW_LAYOUT: String = "controls/party_keyboard"
## Settings keys of the co-op options (off by default; Settings.get_bool answers false while a key is unset).
const KEY_RIVAL_SCORE: String = "coop/rival_score"
const KEY_HELPER_MODE: String = "coop/helper_mode"

## Action being rebound (empty when not listening).
var listening_action: StringName = &""
## Binding profile shown on the bindings page: PROFILE_SOLO or a player slot 0..3.
var bind_profile: int = PROFILE_SOLO

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
var _profile_row: UiOptionRow = null
var _layout_row: UiOptionRow = null
var _key_test_entry: UiOptionRow = null
var _key_page: VBoxContainer = null
var _key_test: UiKeyTest = null


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
	_key_page = _build_key_page()
	_key_page.visible = false
	add_child(_key_page)
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
	if page == _key_page:
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
	elif _key_page.visible:
		_show_page(_bind_page)
		UiKit.focus_silently(_key_test_entry)
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
	for page: Control in [_main_page, _bind_page, _key_page, _confirm_page]:
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


## Bind `event` (key, gamepad button or stick direction) to `action` of the profile shown ([member bind_profile]),
## replacing the action's first binding of the same device family (Settings.set_binding / set_slot_binding): another
## game action of the profile that used the same input gets the replaced input instead (swap), so no input is ever
## on two actions and no action is left without a binding.
func bind_event(action: StringName, event: InputEvent) -> void:
	if Settings.normalize_event(event) == null:
		return
	if bind_profile == PROFILE_SOLO:
		Settings.set_binding(action, event, 0)
	else:
		Settings.set_slot_binding(bind_profile, action, event, 0)
	Audio.play_sfx(Sfx.CODE_ACCEPT)
	stop_listening()


## Show the bindings of `profile` (PROFILE_SOLO or a player slot 0..3).
func set_bind_profile(profile: int) -> void:
	bind_profile = clampi(profile, PROFILE_SOLO, Defs.MAX_PLAYERS - 1)
	if _profile_row != null:
		_profile_row.set_index(bind_profile + 1)
	_layout_row.visible = bind_profile == 0 or bind_profile == 1
	_refresh_bindings()


## Open the bindings page on `profile` (the pause menu of a party: the profile of the player who paused).
func open_bindings(profile: int) -> void:
	set_bind_profile(profile)
	_open_bindings()


## Open the two-player keyboard test.
func open_key_test() -> void:
	stop_listening()
	_show_page(_key_page)


## The keyboard test of the panel.
func get_key_test() -> UiKeyTest:
	return _key_test


## Put both halves of a shared keyboard on the keys of a preset of DESIGN.md D.11 (InputSlot.KeyboardLayout): the
## setting "controls/party_keyboard" changes, and the keys of P1's and P2's profiles return to the preset's (a pad
## button they were given is kept).
static func apply_keyboard_preset(layout: int) -> void:
	var names: Array[String] = InputSlot.KEYBOARD_LAYOUT_NAMES
	Settings.set_value(Settings.PARTY_KEYBOARD_KEY, names[clampi(layout, 0, names.size() - 1)])
	var chosen: int = Settings.party_keyboard_layout()
	for slot: int in 2:
		for action: StringName in Defs.GAME_ACTIONS:
			var pads: Array[InputEvent] = Settings.get_slot_bindings(slot, action, Defs.Device.GAMEPAD)
			if _tokens(pads) == _tokens(InputSlot.default_pad_events(action)):
				Settings.reset_slot_binding(slot, action)
				continue
			var events: Array[InputEvent] = []
			for code: Key in InputSlot.default_keys(chosen, InputSlot.default_half(slot), action):
				var key: InputEventKey = InputEventKey.new()
				key.physical_keycode = code
				events.append(key)
			events.append_array(pads)
			Settings.rebind_slot(slot, action, events)


static func _tokens(events: Array[InputEvent]) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for event: InputEvent in events:
		result.append(Settings.encode_event(event))
	return result


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
	_heading(list, "UI_OPT_COOP")
	_toggle(list, KEY_RIVAL_SCORE, "UI_OPT_RIVAL_SCORE")
	_toggle(list, KEY_HELPER_MODE, "UI_OPT_HELPER_MODE")
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
	var profiles: PackedStringArray = PackedStringArray(["UI_OPT_PROFILE_SOLO"])
	for slot: int in Defs.MAX_PLAYERS:
		profiles.append(UiPlayers.tag(slot))
	_profile_row = UiOptionRow.choice("UI_OPT_PROFILE", profiles, bind_profile + 1)
	_profile_row.changed.connect(func(index: int) -> void: set_bind_profile(index - 1))
	list.add_child(_profile_row)
	_rows[ROW_PROFILE] = _profile_row
	_layout_row = UiOptionRow.choice("UI_OPT_PARTY_KEYS", LAYOUT_KEYS, Settings.party_keyboard_layout())
	_layout_row.changed.connect(func(index: int) -> void: apply_keyboard_preset(index))
	_layout_row.visible = false
	list.add_child(_layout_row)
	_rows[ROW_LAYOUT] = _layout_row
	for action: StringName in Defs.GAME_ACTIONS:
		var row: UiOptionRow = UiOptionRow.action(str(ACTION_KEYS.get(action, String(action))))
		row.value_mono = true
		row.activated.connect(start_listening.bind(action))
		list.add_child(row)
		_bind_rows[action] = row
	_key_test_entry = UiOptionRow.action("UI_OPT_KEY_TEST")
	_key_test_entry.value_text = ">"
	_key_test_entry.activated.connect(open_key_test)
	list.add_child(_key_test_entry)
	var reset: UiOptionRow = UiOptionRow.action("UI_OPT_RESET_BINDINGS")
	reset.activated.connect(_reset_bindings)
	list.add_child(reset)
	var back: UiOptionRow = UiOptionRow.action("UI_OPT_BACK")
	back.activated.connect(go_back)
	list.add_child(back)
	_refresh_bindings()


## The keyboard test page: [UiKeyTest] and a "back" row for pointers.
func _build_key_page() -> VBoxContainer:
	var page: VBoxContainer = VBoxContainer.new()
	page.custom_minimum_size = Vector2(0.0, list_height(LIST_HEIGHT))
	page.alignment = BoxContainer.ALIGNMENT_CENTER
	page.add_theme_constant_override(&"separation", 4)
	_key_test = UiKeyTest.new()
	page.add_child(_key_test)
	return page


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
			ROW_PROFILE:
				row.set_index(bind_profile + 1)
			ROW_LAYOUT:
				row.set_index(Settings.party_keyboard_layout())
			_:
				row.set_index(1 if Settings.get_bool(key) else 0)


func _refresh_bindings() -> void:
	for action: StringName in _bind_rows:
		var row: UiOptionRow = _bind_rows[action]
		var key: String = binding_text(action, Defs.Device.KEYBOARD)
		var pad: String = binding_text(action, Defs.Device.GAMEPAD)
		row.value_text = "%s / %s" % [key if key != "" else "-", pad if pad != "" else "-"]
		row.queue_redraw()
	if _layout_row != null:
		_layout_row.set_index(Settings.party_keyboard_layout())


## Glyph text of the first binding of `action` for a device family (Defs.Device) in the profile shown; "" = none.
func binding_text(action: StringName, device: int) -> String:
	if bind_profile == PROFILE_SOLO:
		return UiGlyphs.action_text(action, UiGlyphs.SET_GAMEPAD if device == Defs.Device.GAMEPAD
				else UiGlyphs.SET_KEYBOARD)
	var events: Array[InputEvent] = Settings.get_slot_bindings(bind_profile, action, device)
	return UiGlyphs.event_text(events[0]) if not events.is_empty() else ""


func _visible_page() -> Control:
	if _confirm_page.visible:
		return _confirm_page
	if _key_page.visible:
		return _key_page
	return _bind_page if _bind_page.visible else _main_page


func _show_page(page: Control) -> void:
	_main_page.visible = page == _main_page
	_bind_page.visible = page == _bind_page
	_key_page.visible = page == _key_page
	_confirm_page.visible = page == _confirm_page
	_title.text = "UI_OPT_BINDINGS" if page == _bind_page else "UI_OPT_KEY_TEST" if page == _key_page \
			else "UI_OPTIONS_HEADING"
	if page == _key_page:
		var focus: Control = get_viewport().gui_get_focus_owner() if is_inside_tree() else null
		if focus != null and is_ancestor_of(focus):
			focus.release_focus()


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
	if bind_profile == PROFILE_SOLO:
		Settings.reset_bindings()
	else:
		Settings.reset_slot_bindings(bind_profile)
	_refresh_bindings()


func _on_setting_changed(key: String, _value: Variant) -> void:
	if key == Settings.BINDINGS_KEY or key == Settings.PARTY_KEYBOARD_KEY:
		_refresh_bindings()
	elif key == "video/fullscreen" and _rows.has(key):
		get_row(key).set_index(1 if Settings.get_bool(key) else 0)

