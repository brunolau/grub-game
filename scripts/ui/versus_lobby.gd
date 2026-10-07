class_name VersusLobbyScreen
extends UiScreen
## The versus lobby (DESIGN.md E.8 steps 1-3, E.9; PLAN.md P1.11 for the G1 slice - the rules and arena screens with
## thumbnails, teams and the handicap card are P2.8).
##
## Four seats (Game.versus_match, made by Flow.open_versus_lobby). **Press Jump on any device** to take the first free
## seat (Flow.join_player seats the player in the match). A seated player works his own card with his own keys as on
## the co-op join panel (JoinScreen): Left / Right colour (a colour another seat wears is skipped), Up / Down loincloth,
## **hold Strike 1 s = ready** (VersusTuning.READY_HOLD_TICKS), Look = not ready / leave the seat. Once ready, his keys
## drive the menu like any menu key (GameInput menu clusters: W / S / Space / Q, Num 8 / Num 5 / Num 0 / Num .), except
## his Strike and a held key's repeats. On a touch screen a tap on a free seat joins a touch player (the whole screen,
## or his half of a tablet in table mode), ready at once.
##
## The menu: the seat cards (confirm on a free seat adds a CPU, Hunter; confirm on a CPU seat steps it Hunter -> Chief
## -> Rookie -> free; "back" on a CPU seat removes it), the mode (the launch modes), the arena (Random, the arenas of
## the mode for this many players, Party Mix; developer arenas too in debug builds), the shared keyboard preset with
## the keyboard picture, and START (Flow.start_versus) once VersusMatch.can_start() and an arena fits. The status line
## says what is missing. "Back" leaves for the title (the match keeps its rules for next time).

const SEATS: int = Defs.MAX_PLAYERS
const CARD_SIZE: Vector2 = Vector2(146.0, 140.0)
## Seconds a player holds Strike to be ready (1 s, VersusTuning.READY_HOLD_TICKS).
const READY_SECONDS: float = float(VersusTuning.READY_HOLD_TICKS) * Tuning.TICK_DT
## The bot levels a CPU seat steps through on confirm (the default first), then the seat is free again.
const BOT_STEPS: Array[int] = [Defs.BotLevel.HUNTER, Defs.BotLevel.CHIEF, Defs.BotLevel.ROOKIE]
const MODE_KEYS: Dictionary = {
	Defs.VersusMode.GRUB_STACK: ["UI_VS_MODE_GRUB_STACK", "UI_VS_MODE_GRUB_STACK_INFO"],
	Defs.VersusMode.LAST_CAVEMAN: ["UI_VS_MODE_LAST_CAVEMAN", "UI_VS_MODE_LAST_CAVEMAN_INFO"],
	Defs.VersusMode.HOT_ROCK: ["UI_VS_MODE_HOT_ROCK", "UI_VS_MODE_HOT_ROCK_INFO"],
	Defs.VersusMode.CLUBBALL: ["UI_VS_MODE_CLUBBALL", "UI_VS_MODE_CLUBBALL_INFO"],
}

## A choice row for a narrow column: its caption in the small face on the left, the value centred in the rest between
## its arrows, in the HUD face or - when that is too wide (Last Caveman Standing) - the body face. Works like ui-B's
## UiOptionRow CHOICE (Left / Right, confirm, taps).
class ChoiceRow:
	extends UiOptionRow

	var _small_font: Font = UiKit.font(UiKit.Style.SMALL)
	var _body_font: Font = UiKit.font(UiKit.Style.BODY)
	var _hud_font: Font = UiKit.font(UiKit.Style.HUD)

	func _init(p_caption: String, p_options: PackedStringArray, p_index: int) -> void:
		super(UiOptionRow.Kind.CHOICE, p_caption)
		options = p_options
		index = clampi(p_index, 0, maxi(0, p_options.size() - 1))
		custom_minimum_size = Vector2(160.0, float(UiKit.row_height()))

	func _draw() -> void:
		var focused: bool = has_focus()
		if focused:
			draw_rect(Rect2(Vector2.ZERO, size), Color(UiKit.COL_INK, 0.35))
		var colour: Color = UiKit.COL_FOCUS if focused else UiKit.COL_TEXT
		var left: float = float(UiOptionRow.PAD)
		if caption != "":
			var caption_text: String = atr(caption)
			var baseline: float = roundf((size.y - float(UiKit.SIZE_SMALL)) * 0.5) \
					+ _small_font.get_ascent(UiKit.SIZE_SMALL)
			draw_string_outline(_small_font, Vector2(left, baseline), caption_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0,
					UiKit.SIZE_SMALL, 4, UiKit.COL_INK)
			draw_string(_small_font, Vector2(left, baseline), caption_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0,
					UiKit.SIZE_SMALL, UiKit.COL_CREAM)
			left += maxf(_small_font.get_string_size(caption_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0,
					UiKit.SIZE_SMALL).x, 40.0) + 6.0
		var right: float = size.x - float(UiOptionRow.PAD)
		var text: String = atr(options[index]) if index < options.size() else ""
		var room: float = right - left - 2.0 * float(UiOptionRow.ARROW_W)
		var font: Font = _hud_font
		var font_size: int = UiKit.SIZE_HUD
		if _hud_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x > room:
			font = _body_font
			font_size = UiKit.SIZE_BODY
		var text_w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
		var centre: float = roundf((left + right) * 0.5)
		var baseline_value: float = roundf((size.y - float(font_size)) * 0.5) + font.get_ascent(font_size)
		var x: float = roundf(centre - text_w * 0.5)
		if font == _body_font:
			draw_string_outline(font, Vector2(x, baseline_value), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, 6,
					UiKit.COL_INK)
		draw_string(font, Vector2(x, baseline_value), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, colour)
		var arrow_colour: Color = colour if focused else UiKit.COL_DIM
		var arrow_base: float = roundf((size.y - float(UiKit.SIZE_HUD)) * 0.5) + _hud_font.get_ascent(UiKit.SIZE_HUD)
		var arrow_w: float = _hud_font.get_string_size("<", HORIZONTAL_ALIGNMENT_LEFT, -1.0, UiKit.SIZE_HUD).x
		draw_string(_hud_font, Vector2(x - 6.0 - arrow_w, arrow_base), "<", HORIZONTAL_ALIGNMENT_LEFT, -1.0,
				UiKit.SIZE_HUD, arrow_colour)
		draw_string(_hud_font, Vector2(x + text_w + 6.0, arrow_base), ">", HORIZONTAL_ALIGNMENT_LEFT, -1.0,
				UiKit.SIZE_HUD, arrow_colour)


var _cards: Array[JoinScreen.SeatCard] = []
var _held: Array[bool] = [false, false, false, false]
var _hold: PackedFloat32Array = PackedFloat32Array([0.0, 0.0, 0.0, 0.0])
var _modes: Array[int] = []
var _arenas: Array[StringName] = []
var _mode_row: ChoiceRow = null
var _arena_row: ChoiceRow = null
var _layout_row: ChoiceRow = null
var _start: UiButton = null
var _status: Label = null
var _info: Label = null
var _picture: JoinScreen.KeyboardPicture = null


func _build_screen() -> void:
	add_child(UiBackdrop.new("jungle", 24.0))
	var shade: ColorRect = ColorRect.new()
	shade.color = Color(UiKit.COL_INK, 0.3)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	if Game.versus_match == null:
		# Opened without Flow.open_versus_lobby (previews, tests).
		Game.versus_match = VersusMatch.from_settings()

	var column: VBoxContainer = VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override(&"separation", 4)
	safe.add_child(column)
	column.add_child(UiKit.label("UI_VS_HEADING", UiKit.Style.TITLE, HORIZONTAL_ALIGNMENT_CENTER))

	var seats: HBoxContainer = HBoxContainer.new()
	seats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	seats.alignment = BoxContainer.ALIGNMENT_CENTER
	seats.add_theme_constant_override(&"separation", 6)
	column.add_child(seats)
	for slot: int in SEATS:
		var card: JoinScreen.SeatCard = JoinScreen.SeatCard.new(slot, CARD_SIZE)
		card.set_focusable(true)
		card.free_action = tr("UI_VS_ADD_CPU")
		card.pressed.connect(_on_card_pressed.bind(slot))
		card.gui_input.connect(_on_card_input.bind(slot))
		seats.add_child(card)
		_cards.append(card)

	var panel_row: HBoxContainer = HBoxContainer.new()
	panel_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel_row.add_theme_constant_override(&"separation", 12)
	var rules: VBoxContainer = VBoxContainer.new()
	rules.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rules.add_theme_constant_override(&"separation", 0)
	rules.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel_row.add_child(rules)
	_modes = VersusMatch.LAUNCH_MODES.duplicate()
	var mode_texts: PackedStringArray = PackedStringArray()
	for mode: int in _modes:
		mode_texts.append(str(MODE_KEYS[mode][0]))
	_mode_row = ChoiceRow.new("UI_MODE", mode_texts, maxi(_modes.find(Game.versus_match.mode), 0))
	_mode_row.changed.connect(_on_mode_changed)
	rules.add_child(_mode_row)
	_arena_row = ChoiceRow.new("UI_VS_ARENA", PackedStringArray(["UI_VS_ARENA_RANDOM"]), 0)
	_arena_row.changed.connect(_on_arena_changed)
	rules.add_child(_arena_row)
	_info = UiKit.label("", UiKit.Style.SMALL, HORIZONTAL_ALIGNMENT_CENTER)
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.custom_minimum_size = Vector2(200.0, 14.0)
	rules.add_child(_info)
	_start = UiButton.new("UI_VS_START")
	_start.pressed.connect(start_match)
	rules.add_child(_start)
	_status = UiKit.label("", UiKit.Style.SMALL, HORIZONTAL_ALIGNMENT_CENTER)
	_status.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	rules.add_child(_status)

	var keys: VBoxContainer = VBoxContainer.new()
	keys.mouse_filter = Control.MOUSE_FILTER_IGNORE
	keys.add_theme_constant_override(&"separation", 0)
	keys.custom_minimum_size = Vector2(240.0, 0.0)
	panel_row.add_child(keys)
	var keys_head: Label = UiKit.label("UI_OPT_PARTY_KEYS", UiKit.Style.SMALL, HORIZONTAL_ALIGNMENT_CENTER)
	keys.add_child(keys_head)
	_picture = JoinScreen.KeyboardPicture.new()
	_picture.size_flags_vertical = Control.SIZE_EXPAND_FILL
	keys.add_child(_picture)
	_layout_row = ChoiceRow.new("", PackedStringArray(JoinScreen.LAYOUT_KEYS), GameInput.keyboard_layout())
	_layout_row.changed.connect(_on_layout_changed)
	keys.add_child(_layout_row)
	column.add_child(UiKit.panel_box(panel_row, 8))

	var prompts: UiPrompts = UiPrompts.new()
	prompts.add_hint(&"ui_accept", "UI_HINT_SELECT")
	prompts.add_hint(&"ui_cancel", "UI_HINT_BACK", _on_cancel)
	column.add_child(prompts)
	_link_focus()


func _screen_ready() -> void:
	Audio.play_music(Sfx.MUSIC_VERSUS_LOBBY)
	GameInput.set_menu_clusters(true)
	Flow.play_mode = Defs.GameMode.VERSUS
	if GameInput.get_slot(0).kind == Defs.InputSlotKind.ALL_DEVICES:
		Flow.begin_party_setup()
	# Everybody confirms again (a match left for the lobby keeps its seats and their looks).
	for slot: int in SEATS:
		var seat: VersusMatch.Seat = Game.versus_match.get_seat(slot)
		if seat.kind == VersusMatch.SeatKind.HUMAN:
			seat.ready = false
		if seat.is_taken():
			_dress(slot)
	Game.versus_match.seats_changed.connect(refresh)
	Flow.party_changed.connect(_on_party_changed)
	Settings.changed.connect(_on_setting_changed)
	_fill_arenas()
	refresh()
	UiKit.focus_silently(_mode_row)


func _process(delta: float) -> void:
	if not is_accepting_input():
		return
	for slot: int in SEATS:
		var seat: VersusMatch.Seat = Game.versus_match.get_seat(slot)
		if seat.kind != VersusMatch.SeatKind.HUMAN or seat.ready:
			_hold[slot] = 0.0
			continue
		if _held[slot]:
			_hold[slot] += delta
			if _hold[slot] >= READY_SECONDS:
				set_ready(slot, true)
				continue
		else:
			_hold[slot] = 0.0
		_cards[slot].hold = _hold[slot] / READY_SECONDS
		_cards[slot].redraw()


func _input(event: InputEvent) -> void:
	if not is_accepting_input() or event is InputEventMouse or event is InputEventScreenDrag:
		return
	var touch: InputEventScreenTouch = event as InputEventScreenTouch
	if touch != null:
		var input: InputSlot = JoinScreen.touch_input_at(touch.position, get_viewport_rect().size)
		if touch.pressed and _free_card_at(touch.position) >= 0 and GameInput.find_input(input) < 0:
			get_viewport().set_input_as_handled()
			var joined: int = join(input)
			if joined >= 0:
				set_ready(joined, true)
		return
	var slot: int = player_of(event)
	if slot >= 0:
		var seat_ready: bool = Game.versus_match.get_seat(slot).ready
		if seat_ready and not _is_action(slot, event, Defs.ACT_LOOK):
			# A ready player drives the menu - but not with the Strike he just held (Num Enter is also Godot's
			# ui_accept) and not with a held key's repeats.
			if event.is_echo() or _is_action(slot, event, Defs.ACT_ATTACK):
				get_viewport().set_input_as_handled()
			return
		get_viewport().set_input_as_handled()
		_player_input(slot, event)
		return
	var input: InputSlot = GameInput.join_input_for_event(event)
	if input != null:
		get_viewport().set_input_as_handled()
		join(input)
		return
	if GameInput.event_half(event) != Defs.InputSlotKind.NONE and not UiKit.is_cancel(event):
		get_viewport().set_input_as_handled()


## The seated human whose own keys / pad `event` comes from, or -1.
func player_of(event: InputEvent) -> int:
	if GameInput.get_slot(0).kind == Defs.InputSlotKind.ALL_DEVICES:
		return -1
	var slot: int = GameInput.event_slot(event)
	if slot < 0 or Game.versus_match.get_seat(slot) == null:
		return -1
	return slot if Game.versus_match.get_seat(slot).kind == VersusMatch.SeatKind.HUMAN else -1


## A player takes the first free seat with `input`. Returns the seat or -1.
func join(input: InputSlot) -> int:
	var slot: int = Flow.join_player(input)
	if slot < 0:
		return -1
	_held[slot] = false
	_hold[slot] = 0.0
	_dress(slot)
	_fill_arenas()
	refresh()
	return slot


## The human of seat `slot` leaves it.
func leave(slot: int) -> bool:
	if not Flow.leave_player(slot):
		return false
	Audio.play_sfx(Sfx.MENU_BACK)
	_held[slot] = false
	_hold[slot] = 0.0
	_fill_arenas()
	refresh()
	return true


## Seat a CPU of `level` (Defs.BotLevel) at `slot` ("Add CPU" on a free seat card). Returns false when it is taken.
func add_cpu(slot: int, level: int = Defs.BotLevel.HUNTER) -> bool:
	if Game.versus_match.seat_bot(level, slot) < 0:
		return false
	_dress(slot)
	Audio.play_sfx(Sfx.MENU_SELECT)
	_fill_arenas()
	refresh()
	return true


## The CPU of `slot` steps to its next level (BOT_STEPS), or leaves the seat after the last one.
func step_cpu(slot: int) -> void:
	var seat: VersusMatch.Seat = Game.versus_match.get_seat(slot)
	if seat == null or seat.kind != VersusMatch.SeatKind.BOT:
		return
	var at: int = BOT_STEPS.find(seat.bot_level)
	if at < 0 or at + 1 >= BOT_STEPS.size():
		remove_cpu(slot)
		return
	seat.bot_level = BOT_STEPS[at + 1]
	Audio.play_sfx(Sfx.MENU_MOVE)
	refresh()


## Free the seat of the CPU at `slot`.
func remove_cpu(slot: int) -> void:
	if not Game.versus_match.is_bot(slot):
		return
	Flow.leave_player(slot)
	Audio.play_sfx(Sfx.MENU_BACK)
	_fill_arenas()
	refresh()


## Mark the human of `slot` ready (or not).
func set_ready(slot: int, on: bool) -> void:
	var seat: VersusMatch.Seat = Game.versus_match.get_seat(slot)
	if seat == null or seat.kind != VersusMatch.SeatKind.HUMAN or seat.ready == on:
		return
	seat.ready = on
	_hold[slot] = 0.0
	_held[slot] = false
	Audio.play_sfx(Sfx.MENU_SELECT if on else Sfx.MENU_BACK)
	refresh()


## How far the human of `slot` held Strike towards ready (0..1).
func hold_progress(slot: int) -> float:
	return clampf(_hold[slot] / READY_SECONDS, 0.0, 1.0) if slot >= 0 and slot < SEATS else 0.0


## Step the colour of seat `slot` by `step`, skipping the colours the other seats wear.
func cycle_colour(slot: int, step: int) -> void:
	var seat: VersusMatch.Seat = Game.versus_match.get_seat(slot)
	if seat == null or not seat.is_taken():
		return
	var next: StringName = JoinScreen.step_colour(_colour_of(slot), step, _taken_colours(slot))
	if next != seat.palette:
		seat.palette = next
		Audio.play_sfx(Sfx.MENU_MOVE)
		refresh()


## Step the loincloth pattern of seat `slot` by `step`.
func cycle_pattern(slot: int, step: int) -> void:
	var seat: VersusMatch.Seat = Game.versus_match.get_seat(slot)
	if seat == null or not seat.is_taken():
		return
	seat.pattern = JoinScreen.step_pattern(_pattern_of(slot), step)
	Audio.play_sfx(Sfx.MENU_MOVE)
	refresh()


## Choose the mode (Defs.VersusMode, one of VersusMatch.LAUNCH_MODES).
func set_mode(mode: int) -> void:
	var at: int = _modes.find(mode)
	if at < 0:
		return
	_mode_row.set_index(at)
	_on_mode_changed(at)


## Choose the arena (an id of the arena row's list, VersusMatch.ARENA_RANDOM or ARENA_PARTY_MIX).
func set_arena(arena_id: StringName) -> void:
	var at: int = _arenas.find(arena_id)
	if at < 0:
		return
	_arena_row.set_index(at)
	_on_arena_changed(at)


## The arenas the arena row offers now (Random first, Party Mix last).
func get_arena_choices() -> Array[StringName]:
	return _arenas.duplicate()


## The seat card of `slot` (tests).
func get_card(slot: int) -> JoinScreen.SeatCard:
	return _cards[slot] if slot >= 0 and slot < _cards.size() else null


## The START button (tests).
func get_start_button() -> UiButton:
	return _start


## The status line under START.
func get_status_text() -> String:
	return _status.text


## True when START would start a match now.
func can_start() -> bool:
	var versus_match: VersusMatch = Game.versus_match
	if versus_match == null or not versus_match.can_start():
		return false
	return versus_match.arena_for_round(0) != &""


## START: the match begins (Flow.start_versus) with the chosen rules.
func start_match() -> void:
	if not is_accepting_input():
		return
	if not can_start():
		Audio.play_sfx(Sfx.MENU_BACK)
		refresh()
		return
	if not begin_leave():
		return
	if not Flow.start_versus():
		leaving = false
		refresh()


## Show the seats, the rules and what is missing as they are now.
func refresh() -> void:
	var versus_match: VersusMatch = Game.versus_match
	if versus_match == null or _cards.is_empty():
		return
	var join_keys: PackedStringArray = JoinScreen.free_join_keys()
	var pads: bool = not Input.get_connected_joypads().is_empty()
	for slot: int in SEATS:
		var card: JoinScreen.SeatCard = _cards[slot]
		var seat: VersusMatch.Seat = versus_match.get_seat(slot)
		card.note = ""
		match seat.kind:
			VersusMatch.SeatKind.HUMAN:
				card.state = JoinScreen.SeatCard.State.HUMAN
				card.device_text = JoinScreen.device_text(seat.input)
				card.player_ready = seat.ready
				card.hold = hold_progress(slot)
				card.left_key = JoinScreen.slot_key_text(slot, Defs.ACT_LEFT)
				card.right_key = JoinScreen.slot_key_text(slot, Defs.ACT_RIGHT)
				card.hold_key = JoinScreen.slot_key_text(slot, Defs.ACT_ATTACK)
				card.leave_key = JoinScreen.slot_key_text(slot, Defs.ACT_LOOK)
			VersusMatch.SeatKind.BOT:
				card.state = JoinScreen.SeatCard.State.BOT
				card.device_text = tr("UI_VS_CPU")
				card.bot_level = seat.bot_level
				card.player_ready = true
			_:
				card.state = JoinScreen.SeatCard.State.FREE
				card.join_keys = join_keys
				card.pad_join = pads
		card.colour = _colour_of(slot)
		card.pattern = _pattern_of(slot)
		card.refresh()
	_layout_row.set_index(GameInput.keyboard_layout())
	_refresh_keyboard()
	_refresh_rules()


func _refresh_rules() -> void:
	var versus_match: VersusMatch = Game.versus_match
	var info: Array = MODE_KEYS.get(versus_match.mode, ["", ""])
	_info.text = "%s  %s" % [tr(str(info[1])),
			tr("UI_VS_FIRST_TO").format({"wins": versus_match.round_wins_needed()})]
	var status: String = ""
	if versus_match.player_count() < VersusTuning.PLAYERS_MIN:
		status = tr("UI_VS_NEED_TWO")
	elif not versus_match.can_start():
		status = tr("UI_VS_NOT_READY")
	elif versus_match.arena_for_round(0) == &"":
		status = tr("UI_VS_NO_ARENA")
	_status.text = status
	_status.add_theme_color_override(&"font_color", UiKit.COL_BAD if status != "" else UiKit.COL_GOOD)
	_start.disabled = status != ""


func _refresh_keyboard() -> void:
	var data: Dictionary = {}
	for half: int in [Defs.InputSlotKind.KEYBOARD_LEFT, Defs.InputSlotKind.KEYBOARD_RIGHT]:
		var info: Dictionary = JoinScreen.half_keys(half)
		var slot: int = int(info["slot"])
		var colour: Color = UiKit.COL_CREAM
		if slot >= 0:
			colour = Color(UiPlayers.PALETTE_COLOURS.get(_colour_of(slot),
					UiPlayers.PALETTE_COLOURS[&"yellow"])[UiPlayers.FILL])
		data[half] = {"keys": info["keys"], "colour": colour, "taken": slot >= 0}
	_picture.set_halves(data)


## The arena row's choices for the mode and the players now: Random, the arenas, Party Mix (the chosen one kept).
func _fill_arenas() -> void:
	var versus_match: VersusMatch = Game.versus_match
	var players: int = maxi(versus_match.player_count(), VersusTuning.PLAYERS_MIN)
	var choices: Array[StringName] = [VersusMatch.ARENA_RANDOM]
	choices.append_array(VersusMatch.available_arenas(players, versus_match.mode))
	if OS.is_debug_build():
		# Developer arenas (levels/test_*_arena_*.lvl) play only when chosen by id: offered in debug builds.
		for id: StringName in Levels.get_arenas(players, Defs.versus_mode_name(versus_match.mode)):
			if String(id).begins_with(VersusMatch.DEVELOPER_ARENA_PREFIX) and not choices.has(id):
				choices.append(id)
	choices.append(VersusMatch.ARENA_PARTY_MIX)
	if not choices.has(versus_match.arena) and Levels.is_arena(versus_match.arena):
		versus_match.arena = VersusMatch.ARENA_RANDOM
	_arenas = choices
	var texts: PackedStringArray = PackedStringArray()
	for id: StringName in choices:
		texts.append(arena_text(id))
	_arena_row.options = texts
	_arena_row.set_index(maxi(choices.find(versus_match.arena), 0))
	_arena_row.queue_redraw()


## The name the arena row shows for `arena_id`.
static func arena_text(arena_id: StringName) -> String:
	match arena_id:
		VersusMatch.ARENA_RANDOM:
			return "UI_VS_ARENA_RANDOM"
		VersusMatch.ARENA_PARTY_MIX:
			return "UI_VS_ARENA_PARTY_MIX"
	return UiKit.level_name(arena_id)


func _player_input(slot: int, event: InputEvent) -> void:
	if _is_action(slot, event, Defs.ACT_ATTACK):
		_held[slot] = event.is_pressed()
		return
	if not event.is_pressed() or event.is_echo():
		return
	var seat_ready: bool = Game.versus_match.get_seat(slot).ready
	if _is_action(slot, event, Defs.ACT_LOOK):
		if seat_ready:
			set_ready(slot, false)
		else:
			leave(slot)
	elif seat_ready:
		return
	elif _is_action(slot, event, Defs.ACT_LEFT):
		cycle_colour(slot, -1)
	elif _is_action(slot, event, Defs.ACT_RIGHT):
		cycle_colour(slot, 1)
	elif _is_action(slot, event, Defs.ACT_UP):
		cycle_pattern(slot, -1)
	elif _is_action(slot, event, Defs.ACT_DOWN):
		cycle_pattern(slot, 1)


func _is_action(slot: int, event: InputEvent, action: StringName) -> bool:
	var generated: StringName = GameInput.slot_action(slot, action)
	return InputMap.has_action(generated) and event.is_action(generated, true)


## A newly taken seat's look: its colour unless another seat wears it, its pattern or the seat's default.
func _dress(slot: int) -> void:
	var seat: VersusMatch.Seat = Game.versus_match.get_seat(slot)
	seat.palette = JoinScreen.free_colour(slot, seat.palette, _taken_colours(slot))
	if seat.pattern < 0 or not JoinScreen.pattern_choices().has(seat.pattern):
		seat.pattern = HeroPalette.slot_default_pattern(slot)


## The free seat whose card lies under `pos` (view px), or -1.
func _free_card_at(pos: Vector2) -> int:
	for slot: int in _cards.size():
		if not Game.versus_match.is_seated(slot) and _cards[slot].get_global_rect().has_point(pos):
			return slot
	return -1


func _colour_of(slot: int) -> StringName:
	var seat: VersusMatch.Seat = Game.versus_match.get_seat(slot)
	if seat != null and seat.palette != &"" and HeroPalette.has_colour(seat.palette):
		return seat.palette
	return HeroPalette.slot_default_colour(slot)


func _pattern_of(slot: int) -> int:
	var seat: VersusMatch.Seat = Game.versus_match.get_seat(slot)
	if seat != null and seat.pattern >= 0:
		return seat.pattern
	return HeroPalette.slot_default_pattern(slot)


func _taken_colours(slot: int) -> Array[StringName]:
	var result: Array[StringName] = []
	for other: int in SEATS:
		if other != slot and Game.versus_match.is_seated(other):
			result.append(_colour_of(other))
	return result


## Confirm on a seat card: a free seat takes a CPU, a CPU seat steps its level.
func _on_card_pressed(slot: int) -> void:
	if not is_accepting_input():
		return
	var seat: VersusMatch.Seat = Game.versus_match.get_seat(slot)
	if seat.kind == VersusMatch.SeatKind.EMPTY:
		add_cpu(slot, BOT_STEPS[0])
	elif seat.kind == VersusMatch.SeatKind.BOT:
		step_cpu(slot)


## "Back" on a CPU seat card removes the CPU (and stays on the lobby).
func _on_card_input(event: InputEvent, slot: int) -> void:
	if UiKit.is_cancel(event) and Game.versus_match.is_bot(slot):
		_cards[slot].accept_event()
		remove_cpu(slot)


func _on_mode_changed(index: int) -> void:
	Game.versus_match.mode = _modes[clampi(index, 0, _modes.size() - 1)]
	_fill_arenas()
	refresh()


func _on_arena_changed(index: int) -> void:
	Game.versus_match.arena = _arenas[clampi(index, 0, _arenas.size() - 1)]
	refresh()


func _on_layout_changed(index: int) -> void:
	GameInput.set_keyboard_layout(index)


func _on_party_changed(_size: int) -> void:
	refresh()


func _on_setting_changed(key: String, _value: Variant) -> void:
	if key == Settings.PARTY_KEYBOARD_KEY or key == Settings.BINDINGS_KEY:
		refresh()


func _on_cancel() -> void:
	if not is_accepting_input():
		return
	Audio.play_sfx(Sfx.MENU_BACK)
	if begin_leave():
		Flow.goto_title()


func _on_tap() -> void:
	pass


## Focus: the seat cards in a row above the mode row; mode, arena and START down the left; the keyboard preset on
## the right.
func _link_focus() -> void:
	for slot: int in SEATS:
		var card: JoinScreen.SeatCard = _cards[slot]
		card.focus_neighbor_left = card.get_path_to(_cards[posmod(slot - 1, SEATS)])
		card.focus_neighbor_right = card.get_path_to(_cards[(slot + 1) % SEATS])
		card.focus_neighbor_bottom = card.get_path_to(_mode_row if slot < SEATS / 2 else _layout_row)
		card.focus_neighbor_top = card.get_path_to(_start)
	_mode_row.focus_neighbor_top = _mode_row.get_path_to(_cards[0])
	_mode_row.focus_neighbor_bottom = _mode_row.get_path_to(_arena_row)
	_arena_row.focus_neighbor_top = _arena_row.get_path_to(_mode_row)
	_arena_row.focus_neighbor_bottom = _arena_row.get_path_to(_start)
	_start.focus_neighbor_top = _start.get_path_to(_arena_row)
	_start.focus_neighbor_bottom = _start.get_path_to(_cards[0])
	_start.focus_neighbor_right = _start.get_path_to(_layout_row)
	_layout_row.focus_neighbor_top = _layout_row.get_path_to(_cards[SEATS - 1])
	_layout_row.focus_neighbor_bottom = _layout_row.get_path_to(_start)
	_layout_row.focus_neighbor_left = _layout_row.get_path_to(_start)
