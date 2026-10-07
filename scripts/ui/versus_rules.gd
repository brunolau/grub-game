class_name VersusRulesScreen
extends UiScreen
## The rules of a versus match (DESIGN.md E.8 step 2, E.4, GAMEPLAY.md 13.10.8; PLAN.md P2.8; Flow.SCREEN_VERSUS_RULES).
##
## Opened by the lobby's START with args {"owner": slot}: **whoever pressed Start controls it** - while an owner is
## set, the keys and the pad of every other seated player do nothing here (the mouse and touch still work: one device
## on a table). Every change goes straight into Game.versus_match; Flow.start_versus remembers the rules for the next
## lobby (VersusMatch.remember_rules).
##
## Rows (left, right): Mode (the launch modes) and Preset (Classic / Feast / Mayhem); Rounds to win (the mode's
## default or 1..10) and Round time (default, 30..180 s); Crates (off with the Classic preset) and Weapons (specials
## from crates / club only); Sudden death (always at 60 s in Last Caveman Standing) and Stock lives (Last Caveman
## Standing only). Under them the nine variants as chips; Big Bounce, Lights Out and Giant Rain need 15 Cave Paintings,
## Spear Party 25 (Save.is_unlocked) - a locked chip shows the count. The line under the chips explains the focused
## entry. "Choose the arena" opens the arena select; "back" returns to the lobby (seats and ready flags kept).

## Rounds-to-win choices (0 = the mode's default, VersusMatch.round_wins_needed) and round times in seconds (0 =
## the mode's default, VersusMatch.round_ticks).
const ROUND_CHOICES: Array[int] = [0, 1, 2, 3, 4, 5, 7, 10]
const TIME_CHOICES: Array[int] = [0, 30, 45, 60, 90, 120, 180]
## The presets' texts (VersusMatch.Preset order): [name, info].
const PRESET_KEYS: Array[Array] = [
	["UI_VS_PRESET_CLASSIC", "UI_VS_PRESET_CLASSIC_INFO"],
	["UI_VS_PRESET_FEAST", "UI_VS_PRESET_FEAST_INFO"],
	["UI_VS_PRESET_MAYHEM", "UI_VS_PRESET_MAYHEM_INFO"],
]
## The variants' texts (DESIGN.md E.4) in VersusMatch.VARIANT_NAMES order: [name, text key, info key]. Which reward
## opens a variant is core-A's UnlockTable (reward_of_variant).
const VARIANTS: Array[Array] = [
	[&"hammer_time", "UI_VS_VAR_HAMMER_TIME", "UI_VS_VAR_HAMMER_TIME_INFO"],
	[&"axe_rain", "UI_VS_VAR_AXE_RAIN", "UI_VS_VAR_AXE_RAIN_INFO"],
	[&"big_bounce", "UI_VS_VAR_BIG_BOUNCE", "UI_VS_VAR_BIG_BOUNCE_INFO"],
	[&"one_bonk", "UI_VS_VAR_ONE_BONK", "UI_VS_VAR_ONE_BONK_INFO"],
	[&"slippery", "UI_VS_VAR_SLIPPERY", "UI_VS_VAR_SLIPPERY_INFO"],
	[&"lights_out", "UI_VS_VAR_LIGHTS_OUT", "UI_VS_VAR_LIGHTS_OUT_INFO"],
	[&"gusty", "UI_VS_VAR_GUSTY", "UI_VS_VAR_GUSTY_INFO"],
	[&"giant_rain", "UI_VS_VAR_GIANT_RAIN", "UI_VS_VAR_GIANT_RAIN_INFO"],
	[&"spear_party", "UI_VS_VAR_SPEAR_PARTY", "UI_VS_VAR_SPEAR_PARTY_INFO"],
]
const CHIP_SIZE: Vector2 = Vector2(150.0, 24.0)

## The player slot whose Start opened the screen (-1 = anybody drives it).
var owner_slot: int = -1

var _mode_row: RuleRow = null
var _preset_row: RuleRow = null
var _rounds_row: RuleRow = null
var _time_row: RuleRow = null
var _crates_row: RuleRow = null
var _weapons_row: RuleRow = null
var _sudden_row: RuleRow = null
var _stock_row: RuleRow = null
var _chips: Array[VariantChip] = []
var _next: UiButton = null
var _info: Label = null
var _modes: Array[int] = []


## A rule row: VersusLobbyScreen's narrow choice row that can be locked (shows `locked_text`, dimmed, and does not
## step) and tells the screen when it gets the focus.
class RuleRow:
	extends VersusLobbyScreen.ChoiceRow

	var locked: bool = false
	var locked_text: String = ""

	func _init(p_caption: String, p_options: PackedStringArray, p_index: int) -> void:
		super(p_caption, p_options, p_index)
		custom_minimum_size = Vector2(300.0, 26.0)

	func step(direction: int) -> void:
		if locked:
			return
		super.step(direction)

	## Lock the row with `text` in place of its value (or unlock it with "").
	func set_locked(text: String) -> void:
		locked = text != ""
		locked_text = text
		modulate.a = 0.55 if locked else 1.0
		queue_redraw()

	func _draw() -> void:
		if not locked:
			super._draw()
			return
		var saved: PackedStringArray = options
		var saved_index: int = index
		options = PackedStringArray([locked_text])
		index = 0
		super._draw()
		options = saved
		index = saved_index


## One variant: its name on a chip, gold while on; a locked chip shows the paintings it needs and does not switch.
class VariantChip:
	extends Button

	signal toggled_on(on: bool)

	var variant: StringName = &""
	var on: bool = false
	var reward: StringName = &""
	var _font: Font = UiKit.font(UiKit.Style.SMALL)

	func _init(p_variant: StringName, p_text: String, p_reward: StringName, p_on: bool) -> void:
		variant = p_variant
		reward = p_reward
		on = p_on and not is_locked()
		text = ""
		set_meta(&"caption", p_text)
		flat = true
		focus_mode = Control.FOCUS_ALL
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		custom_minimum_size = VersusRulesScreen.CHIP_SIZE
		pressed.connect(_on_pressed)
		focus_entered.connect(_on_focus)
		focus_exited.connect(queue_redraw)
		gui_input.connect(_on_gui_input)

	## True while the reward this variant needs is closed (UnlockTable.is_variant_open).
	func is_locked() -> bool:
		return not UnlockTable.is_variant_open(variant)

	func _on_pressed() -> void:
		if is_locked():
			Audio.play_sfx(Sfx.MENU_BACK)
			return
		on = not on
		Audio.play_sfx(Sfx.MENU_SELECT if on else Sfx.MENU_BACK)
		toggled_on.emit(on)
		queue_redraw()

	func _on_focus() -> void:
		UiKit.play_focus_sound()
		queue_redraw()

	func _on_gui_input(event: InputEvent) -> void:
		if event is InputEventMouseMotion and not has_focus():
			grab_focus()

	func _draw() -> void:
		var rect: Rect2 = Rect2(Vector2.ZERO, size)
		draw_rect(rect, UiKit.COL_INK)
		var face: Rect2 = rect.grow(-1.0)
		var fill: Color = Color("c98a2a") if on else Color(UiKit.COL_INK.lightened(0.18))
		if is_locked():
			fill = Color(UiKit.COL_INK.lightened(0.08))
		draw_rect(face, fill)
		if on:
			draw_rect(Rect2(face.position, Vector2(face.size.x, 2.0)), Color("ffd75e"))
		if has_focus():
			draw_rect(rect, UiKit.COL_FOCUS, false, 2.0)
		var caption: String = tr(str(get_meta(&"caption", "")))
		var colour: Color = UiKit.COL_INK if on else UiKit.COL_CREAM
		if is_locked():
			caption = "%s  %s" % [caption, tr("UI_VS_LOCKED").format({"count": UnlocksScreen.reward_needs(reward)})]
			colour = UiKit.COL_DIM
		var box: float = 10.0
		var box_rect: Rect2 = Rect2(6.0, roundf((size.y - box) * 0.5), box, box)
		draw_rect(box_rect, UiKit.COL_INK)
		draw_rect(box_rect.grow(-2.0), Color("fff1cf") if on else Color(UiKit.COL_INK.lightened(0.3)))
		if on:
			draw_rect(box_rect.grow(-3.0), UiKit.COL_INK)
		var baseline: float = roundf((size.y - float(UiKit.SIZE_SMALL)) * 0.5) + _font.get_ascent(UiKit.SIZE_SMALL)
		var shown: String = caption
		while shown.length() > 3 and _font.get_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, -1.0, UiKit.SIZE_SMALL).x \
				> size.x - 26.0:
			shown = shown.left(shown.length() - 2) + "."
		draw_string(_font, Vector2(22.0, baseline), shown, HORIZONTAL_ALIGNMENT_LEFT, -1.0, UiKit.SIZE_SMALL, colour)


func _build_screen() -> void:
	add_child(UiBackdrop.new("jungle", 24.0))
	var shade: ColorRect = ColorRect.new()
	shade.color = Color(UiKit.COL_INK, 0.4)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	if Game.versus_match == null:
		# Opened without the lobby (previews, tests).
		Game.versus_match = VersusMatch.from_settings()
	var versus_match: VersusMatch = Game.versus_match
	owner_slot = int(Flow.args.get("owner", versus_match.rules_owner))
	versus_match.rules_owner = owner_slot

	var column: VBoxContainer = VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override(&"separation", 3)
	safe.add_child(column)
	column.add_child(UiKit.label("UI_VS_RULES_HEADING", UiKit.Style.TITLE, HORIZONTAL_ALIGNMENT_CENTER))
	var owner_line: Label = UiKit.label(owner_text(owner_slot), UiKit.Style.SMALL, HORIZONTAL_ALIGNMENT_CENTER)
	owner_line.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	if owner_slot >= 0:
		owner_line.add_theme_color_override(&"font_color", UiPlayers.text_colour(owner_slot))
	column.add_child(owner_line)

	var inner: VBoxContainer = VBoxContainer.new()
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_theme_constant_override(&"separation", 2)
	var grid: GridContainer = GridContainer.new()
	grid.columns = 2
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid.add_theme_constant_override(&"h_separation", 12)
	grid.add_theme_constant_override(&"v_separation", 0)
	inner.add_child(grid)
	_modes = VersusMatch.LAUNCH_MODES.duplicate()
	var mode_texts: PackedStringArray = PackedStringArray()
	for mode: int in _modes:
		mode_texts.append(str(VersusLobbyScreen.MODE_KEYS[mode][0]))
	_mode_row = _row(grid, "UI_MODE", mode_texts, maxi(_modes.find(versus_match.mode), 0), _on_mode_changed)
	var presets: PackedStringArray = PackedStringArray()
	for entry: Array in PRESET_KEYS:
		presets.append(str(entry[0]))
	_preset_row = _row(grid, "UI_VS_PRESET", presets, versus_match.preset, _on_preset_changed)
	_rounds_row = _row(grid, "UI_VS_ROUNDS", PackedStringArray(), 0, _on_rounds_changed)
	_time_row = _row(grid, "UI_VS_ROUND_TIME", PackedStringArray(), 0, _on_time_changed)
	_crates_row = _row(grid, "UI_VS_CRATES", PackedStringArray(["UI_OFF", "UI_ON"]), 1 if versus_match.crates else 0,
			_on_crates_changed)
	_weapons_row = _row(grid, "UI_VS_WEAPONS", PackedStringArray(["UI_VS_WEAPONS_ALL", "UI_VS_WEAPONS_CLUB"]),
			1 if versus_match.weapons == &"club" else 0, _on_weapons_changed)
	_sudden_row = _row(grid, "UI_VS_SUDDEN", PackedStringArray(["UI_OFF", "UI_ON"]),
			1 if versus_match.sudden_death else 0, _on_sudden_changed)
	_stock_row = _row(grid, "UI_VS_STOCK", PackedStringArray(["UI_OFF", "UI_ON"]), 1 if versus_match.stock else 0,
			_on_stock_changed)

	var variants_head: Label = UiKit.label("UI_VS_VARIANTS", UiKit.Style.SMALL)
	variants_head.add_theme_color_override(&"font_color", UiKit.COL_FOCUS)
	inner.add_child(variants_head)
	var chips: GridContainer = GridContainer.new()
	chips.columns = 3
	chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chips.add_theme_constant_override(&"h_separation", 6)
	chips.add_theme_constant_override(&"v_separation", 3)
	for entry: Array in VARIANTS:
		var chip: VariantChip = VariantChip.new(entry[0], str(entry[1]), UnlockTable.reward_of_variant(entry[0]),
				versus_match.has_variant(entry[0]))
		chip.toggled_on.connect(_on_variant_toggled.bind(entry[0]))
		chip.focus_entered.connect(_show_info.bind(_variant_info(entry)))
		chips.add_child(chip)
		_chips.append(chip)
	var chips_holder: CenterContainer = CenterContainer.new()
	chips_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chips_holder.add_child(chips)
	inner.add_child(chips_holder)
	var panel: PanelContainer = UiKit.panel_box(inner, 8)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(panel)

	_info = UiKit.label("", UiKit.Style.SMALL, HORIZONTAL_ALIGNMENT_CENTER)
	_info.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_info.custom_minimum_size = Vector2(0.0, 14.0)
	column.add_child(_info)
	_next = UiButton.new("UI_VS_CHOOSE_ARENA")
	_next.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_next.pressed.connect(choose_arena)
	column.add_child(_next)
	var spacer: Control = Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(spacer)
	var prompts: UiPrompts = UiPrompts.new()
	prompts.alignment = BoxContainer.ALIGNMENT_END
	prompts.add_hint(&"ui_accept", "UI_HINT_CHANGE")
	prompts.add_hint(&"ui_cancel", "UI_HINT_BACK", _on_cancel)
	column.add_child(prompts)
	_refresh()
	_link_focus()


func _screen_ready() -> void:
	Audio.play_music(Sfx.MUSIC_VERSUS_LOBBY)
	GameInput.set_menu_clusters(true)
	Flow.play_mode = Defs.GameMode.VERSUS
	UiKit.focus_silently(_mode_row)
	_on_row_focused(_mode_row)


## Only the owner's devices drive the screen: a key or button of another seated player is swallowed.
func _input(event: InputEvent) -> void:
	if not is_accepting_input() or not is_foreign(event):
		return
	get_viewport().set_input_as_handled()


## True when `event` comes from the keys or the pad of a seated player who is not the owner.
func is_foreign(event: InputEvent) -> bool:
	if owner_slot < 0 or event is InputEventMouse or event is InputEventScreenTouch or event is InputEventScreenDrag:
		return false
	if not (event is InputEventKey or event is InputEventJoypadButton or event is InputEventJoypadMotion):
		return false
	var slot: int = GameInput.event_slot(event)
	return slot >= 0 and slot != owner_slot


## "P1 sets the rules" (an empty line without an owner).
static func owner_text(slot: int) -> String:
	if slot < 0:
		return ""
	return TranslationServer.translate("UI_VS_RULES_OWNER").format({"player": UiPlayers.tag(slot)})


## The rows (tests): mode, preset, rounds, time, crates, weapons, sudden death, stock.
func get_rows() -> Array[RuleRow]:
	return [_mode_row, _preset_row, _rounds_row, _time_row, _crates_row, _weapons_row, _sudden_row, _stock_row]


## The variant chips in VARIANTS order (tests).
func get_chips() -> Array[VariantChip]:
	return _chips


## The "Choose the arena" button.
func get_next_button() -> UiButton:
	return _next


## The info line.
func get_info_text() -> String:
	return _info.text


## On to the arena select (the owner keeps the screen).
func choose_arena() -> void:
	if not begin_leave():
		return
	Audio.play_sfx(Sfx.MENU_SELECT)
	Flow.goto_screen(Flow.SCREEN_VERSUS_ARENA, Defs.Transition.FADE, {"owner": owner_slot})


func _on_cancel() -> void:
	if not begin_leave():
		return
	Audio.play_sfx(Sfx.MENU_BACK)
	VersusLobbyScreen.keep_ready_on_return()
	Flow.open_versus_lobby()


func _on_tap() -> void:
	pass


func _row(parent: Control, caption: String, options: PackedStringArray, index: int, callback: Callable) -> RuleRow:
	var row: RuleRow = RuleRow.new(caption, options, index)
	row.changed.connect(callback)
	row.focus_entered.connect(_on_row_focused.bind(row))
	parent.add_child(row)
	return row


## Show the current rules: the default texts of rounds and time follow the mode; Crates, Sudden death and Stock lock
## where the preset or the mode decides them.
func _refresh() -> void:
	var versus_match: VersusMatch = Game.versus_match
	var saved_rounds: int = versus_match.rounds_to_win
	versus_match.rounds_to_win = 0
	var default_rounds: int = versus_match.round_wins_needed(versus_match.mode)
	versus_match.rounds_to_win = saved_rounds
	var rounds: PackedStringArray = PackedStringArray()
	for choice: int in ROUND_CHOICES:
		rounds.append(tr("UI_VS_DEFAULT").format({"value": default_rounds}) if choice == 0 else str(choice))
	_rounds_row.options = rounds
	_rounds_row.set_index(maxi(ROUND_CHOICES.find(versus_match.rounds_to_win), 0))
	var saved_seconds: int = versus_match.round_seconds
	versus_match.round_seconds = 0
	var default_ticks: int = versus_match.round_ticks(versus_match.mode)
	versus_match.round_seconds = saved_seconds
	var default_time: String = tr("UI_VS_NO_CLOCK") if default_ticks <= 0 else tr("UI_VS_SECONDS").format(
			{"seconds": roundi(Tuning.ticks_to_seconds(default_ticks))})
	var times: PackedStringArray = PackedStringArray()
	for choice: int in TIME_CHOICES:
		times.append(tr("UI_VS_DEFAULT").format({"value": default_time}) if choice == 0 \
				else tr("UI_VS_SECONDS").format({"seconds": choice}))
	_time_row.options = times
	_time_row.set_index(maxi(TIME_CHOICES.find(versus_match.round_seconds), 0))
	_crates_row.set_locked(tr("UI_OFF") if versus_match.preset == VersusMatch.Preset.CLASSIC else "")
	var lcs: bool = versus_match.mode == Defs.VersusMode.LAST_CAVEMAN
	_sudden_row.set_locked(tr("UI_VS_SUDDEN_ALWAYS") if lcs else "")
	_stock_row.set_locked("" if lcs else tr("UI_VS_ONLY_LCS"))
	for row: RuleRow in get_rows():
		row.queue_redraw()


func _on_row_focused(row: RuleRow) -> void:
	var versus_match: VersusMatch = Game.versus_match
	if row == _mode_row:
		_show_info(str(VersusLobbyScreen.MODE_KEYS.get(versus_match.mode, ["", ""])[1]))
	elif row == _preset_row:
		_show_info(str(PRESET_KEYS[clampi(versus_match.preset, 0, PRESET_KEYS.size() - 1)][1]))
	else:
		_show_info("")


func _show_info(key: String) -> void:
	_info.text = tr(key) if key != "" else ""


func _variant_info(entry: Array) -> String:
	return str(entry[2])


func _on_mode_changed(index: int) -> void:
	Game.versus_match.mode = _modes[clampi(index, 0, _modes.size() - 1)]
	_refresh()
	_on_row_focused(_mode_row)


func _on_preset_changed(index: int) -> void:
	Game.versus_match.preset = clampi(index, 0, PRESET_KEYS.size() - 1)
	_refresh()
	_on_row_focused(_preset_row)


func _on_rounds_changed(index: int) -> void:
	Game.versus_match.rounds_to_win = ROUND_CHOICES[clampi(index, 0, ROUND_CHOICES.size() - 1)]


func _on_time_changed(index: int) -> void:
	Game.versus_match.round_seconds = TIME_CHOICES[clampi(index, 0, TIME_CHOICES.size() - 1)]


func _on_crates_changed(index: int) -> void:
	Game.versus_match.crates = index == 1


func _on_weapons_changed(index: int) -> void:
	Game.versus_match.weapons = &"club" if index == 1 else &"all"


func _on_sudden_changed(index: int) -> void:
	Game.versus_match.sudden_death = index == 1


func _on_stock_changed(index: int) -> void:
	Game.versus_match.stock = index == 1


func _on_variant_toggled(on: bool, variant: StringName) -> void:
	var variants: PackedStringArray = Game.versus_match.variants
	var at: int = variants.find(String(variant))
	if on and at < 0:
		variants.append(String(variant))
	elif not on and at >= 0:
		variants.remove_at(at)
	Game.versus_match.variants = variants


## Focus: the rows in two columns (Left / Right change a value, so Up / Down move; the end of a column leads into the
## other one), the chips in a 3 x 3 grid, then "Choose the arena"; the last wraps to the mode row.
func _link_focus() -> void:
	var left: Array[Control] = [_mode_row, _rounds_row, _crates_row, _sudden_row]
	var right: Array[Control] = [_preset_row, _time_row, _weapons_row, _stock_row]
	var order: Array[Control] = []
	order.append_array(left)
	order.append_array(right)
	for chip: VariantChip in _chips:
		order.append(chip)
	order.append(_next)
	# Rows: down the left column, then down the right one.
	for i: int in left.size():
		var row: Control = left[i]
		row.focus_neighbor_top = row.get_path_to(left[i - 1] if i > 0 else _next)
		row.focus_neighbor_bottom = row.get_path_to(left[i + 1] if i + 1 < left.size() else right[0])
	for i: int in right.size():
		var row: Control = right[i]
		row.focus_neighbor_top = row.get_path_to(right[i - 1] if i > 0 else left[left.size() - 1])
		row.focus_neighbor_bottom = row.get_path_to(right[i + 1] if i + 1 < right.size() else _chips[0])
	for i: int in _chips.size():
		var chip: VariantChip = _chips[i]
		var col: int = i % 3
		var up: int = i - 3
		var down: int = i + 3
		chip.focus_neighbor_left = chip.get_path_to(_chips[i - 1] if col > 0 else _chips[mini(i + 2, _chips.size() - 1)])
		chip.focus_neighbor_right = chip.get_path_to(_chips[i + 1] if col < 2 and i + 1 < _chips.size() else _chips[i - col])
		chip.focus_neighbor_top = chip.get_path_to(_chips[up] if up >= 0 else right[right.size() - 1])
		chip.focus_neighbor_bottom = chip.get_path_to(_chips[down] if down < _chips.size() else _next)
	_next.focus_neighbor_top = _next.get_path_to(_chips[_chips.size() - 1])
	_next.focus_neighbor_bottom = _next.get_path_to(_mode_row)
	_next.focus_neighbor_left = _next.get_path_to(_next)
	_next.focus_neighbor_right = _next.get_path_to(_next)
	for i: int in order.size():
		order[i].focus_next = order[i].get_path_to(order[(i + 1) % order.size()])
		order[i].focus_previous = order[i].get_path_to(order[posmod(i - 1, order.size())])
