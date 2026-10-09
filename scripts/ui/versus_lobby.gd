class_name VersusLobbyScreen
extends UiScreen
## The versus lobby (DESIGN.md E.8 step 1, E.9; PLAN.md P1.11 / P2.8).
##
## Four seats (Game.versus_match, made by Flow.open_versus_lobby). **Press Jump on any device** to take the first free
## seat (Flow.join_player seats the player in the match). A seated player works his own card with his own keys as on
## the co-op join panel (JoinScreen): Left / Right colour (a colour another seat wears is skipped), Up / Down loincloth,
## **Swap = his handicap card** (Last Caveman Standing hearts 3 -> 4 -> 5 -> 1 -> 2, Grub Stack stack guard x1 ->
## x1.5 -> x0.5, then Auto - a leaf shield when two rounds behind - in every mode), **Jump = his team** in a 2 v 2
## match, **hold Strike 1 s = ready** (VersusTuning.READY_HOLD_TICKS), Look = not ready / leave the seat. Once ready,
## his keys drive the menu like any menu key (GameInput menu clusters: W / S / Space / Q, Num 8 / Num 5 / Num 0 /
## Num .), except his Strike and a held key's repeats. On a touch screen a tap on a free seat joins a touch player (the
## whole screen, or his half of a tablet in table mode), ready at once.
##
## The menu: the seat cards (confirm on a free seat adds a CPU, Hunter; confirm on a CPU seat steps it Hunter -> Chief
## -> Rookie -> free; "back" on a CPU seat removes it), Teams (free-for-all / 2 v 2: the first two seats are the Sun,
## the others the Moon; a player switches with his Jump and a CPU of a full team moves over), the rules summary,
## START (focused first), and under it two small entries: Cave Paintings (scenes/ui/unlocks) and the key test (also
## Tab), which shows the seated keyboard players in join order; on the right the shared keyboard preset with the
## keyboard picture. START opens the
## rules (scenes/ui/versus_rules) for the player who pressed it once VersusMatch.can_start() - the status line says
## what is missing; the rules lead to the arena select, which starts the match. "Back" leaves for the title (the
## match keeps its rules for next time).

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
## The handicap card's steps (DESIGN.md E.4): Last Caveman Standing hearts (0 = the mode's 3), Grub Stack stack
## guard (index of VersusTuning.STACK_GUARD_PERCENT, 1 = x1); after the last step comes Auto, then the first again.
const HEART_STEPS: Array[int] = [0, 4, 5, 1, 2]
const GUARD_STEPS: Array[int] = [1, 2, 0]
## The menu action that opens the keyboard test.
const KEY_TEST_ACTION: StringName = &"ui_focus_next"

## The rules or arena screen sends the players back: their ready flags stay (keep_ready_on_return).
static var _keep_ready: bool = false

var _cards: Array[JoinScreen.SeatCard] = []
var _held: Array[bool] = [false, false, false, false]
var _hold: PackedFloat32Array = PackedFloat32Array([0.0, 0.0, 0.0, 0.0])
var _teams_row: ChoiceRow = null
var _layout_row: ChoiceRow = null
var _start: UiButton = null
var _paintings: UiButton = null
var _key_button: UiButton = null
var _status: Label = null
## G50: why the last "Add CPU" was refused (the chosen arena is for humans only in this mode); "" otherwise.
var _cpu_note: String = ""
## The status note of a seat the device does not have (VersusMatch.seat_limit(), DESIGN.md G94): a phone or tablet
## seats VersusTuning.PLAYERS_MAX_MOBILE heroes. Shown until the next seat action.
var _seat_note: String = ""
var _summary: Label = null
var _picture: JoinScreen.KeyboardPicture = null
var _key_test_layer: Control = null
var _key_test: JoinScreen.PartyKeyTest = null
## The player slot of the last key or button pressed on this screen (-1: mouse, touch or a key of nobody's).
var _last_slot: int = -1


## A choice row for a narrow column: its caption in the small face on the left, the value centred in the rest between
## its arrows, in the HUD face or - when that is too wide - the body face, or the small face where even that does not
## fit ("Default (No clock)" beside a caption). Works like ui-B's
## UiOptionRow CHOICE (Left / Right, confirm, taps). Also the rows of the rules screen (VersusRulesScreen.RuleRow).
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
			if _body_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x > room:
				font = _small_font
				font_size = UiKit.SIZE_SMALL
		var text_w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
		var centre: float = roundf((left + right) * 0.5)
		var baseline_value: float = roundf((size.y - float(font_size)) * 0.5) + font.get_ascent(font_size)
		var x: float = roundf(centre - text_w * 0.5)
		if font != _hud_font:
			draw_string_outline(font, Vector2(x, baseline_value), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size,
					6 if font == _body_font else 4, UiKit.COL_INK)
		draw_string(font, Vector2(x, baseline_value), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, colour)
		var arrow_colour: Color = colour if focused else UiKit.COL_DIM
		var arrow_base: float = roundf((size.y - float(UiKit.SIZE_HUD)) * 0.5) + _hud_font.get_ascent(UiKit.SIZE_HUD)
		var arrow_w: float = _hud_font.get_string_size("<", HORIZONTAL_ALIGNMENT_LEFT, -1.0, UiKit.SIZE_HUD).x
		draw_string(_hud_font, Vector2(x - 6.0 - arrow_w, arrow_base), "<", HORIZONTAL_ALIGNMENT_LEFT, -1.0,
				UiKit.SIZE_HUD, arrow_colour)
		draw_string(_hud_font, Vector2(x + text_w + 6.0, arrow_base), ">", HORIZONTAL_ALIGNMENT_LEFT, -1.0,
				UiKit.SIZE_HUD, arrow_colour)


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
	_teams_row = ChoiceRow.new("UI_VS_TEAMS", PackedStringArray(["UI_VS_TEAMS_FREE", "UI_VS_TEAMS_2V2"]),
			1 if Game.versus_match.is_team_match() or _has_teams() else 0)
	_teams_row.changed.connect(_on_teams_changed)
	rules.add_child(_teams_row)
	_summary = UiKit.label("", UiKit.Style.SMALL, HORIZONTAL_ALIGNMENT_CENTER)
	_summary.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_summary.custom_minimum_size = Vector2(200.0, 14.0)
	rules.add_child(_summary)
	_start = UiButton.new("UI_VS_START")
	_start.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_start.pressed.connect(open_rules)
	rules.add_child(_start)
	# Cave Paintings and the key test as two small entries under START (START keeps the big face; the four seat cards
	# and the keyboard picture leave no room for three big entries at 640 px).
	var extras: HBoxContainer = HBoxContainer.new()
	extras.mouse_filter = Control.MOUSE_FILTER_IGNORE
	extras.alignment = BoxContainer.ALIGNMENT_CENTER
	extras.add_theme_constant_override(&"separation", 14)
	rules.add_child(extras)
	_paintings = small_button("UI_PAINTINGS", open_paintings)
	extras.add_child(_paintings)
	_key_button = small_button("UI_JOIN_KEY_TEST", open_key_test)
	extras.add_child(_key_button)
	_status = UiKit.label("", UiKit.Style.SMALL, HORIZONTAL_ALIGNMENT_CENTER)
	_status.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	rules.add_child(_status)

	var keys: VBoxContainer = VBoxContainer.new()
	keys.mouse_filter = Control.MOUSE_FILTER_IGNORE
	keys.add_theme_constant_override(&"separation", 0)
	keys.custom_minimum_size = Vector2(264.0, 0.0)
	panel_row.add_child(keys)
	_picture = JoinScreen.KeyboardPicture.new()
	_picture.size_flags_vertical = Control.SIZE_EXPAND_FILL
	keys.add_child(_picture)
	_layout_row = ChoiceRow.new("", PackedStringArray(JoinScreen.LAYOUT_KEYS), GameInput.keyboard_layout())
	_layout_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_layout_row.changed.connect(_on_layout_changed)
	keys.add_child(_layout_row)
	column.add_child(UiKit.panel_box(panel_row, 8))

	var prompts: UiPrompts = UiPrompts.new()
	prompts.add_hint(&"ui_accept", "UI_HINT_SELECT")
	prompts.add_hint(KEY_TEST_ACTION, "UI_JOIN_KEY_TEST", open_key_test)
	prompts.add_hint(&"ui_cancel", "UI_HINT_BACK", _on_cancel)
	column.add_child(prompts)
	_link_focus()
	_key_test_layer = JoinScreen.key_test_layer(close_key_test)
	_key_test = _key_test_layer.get_meta(&"key_test") as JoinScreen.PartyKeyTest


func _screen_ready() -> void:
	add_child(_key_test_layer)
	Audio.play_music(Sfx.MUSIC_VERSUS_LOBBY)
	GameInput.set_menu_clusters(true)
	Flow.play_mode = Defs.GameMode.VERSUS
	if GameInput.get_slot(0).kind == Defs.InputSlotKind.ALL_DEVICES:
		Flow.begin_party_setup()
	# Everybody confirms again after a match (a match left for the lobby keeps its seats and their looks); coming
	# back from the rules or the arena keeps the ready flags.
	var keep: bool = _keep_ready
	_keep_ready = false
	for slot: int in SEATS:
		var seat: VersusMatch.Seat = Game.versus_match.get_seat(slot)
		if seat.kind == VersusMatch.SeatKind.HUMAN and not keep:
			seat.ready = false
		if seat.is_taken():
			_dress(slot)
	Game.versus_match.seats_changed.connect(refresh)
	Flow.party_changed.connect(_on_party_changed)
	Settings.changed.connect(_on_setting_changed)
	refresh()
	UiKit.focus_silently(_start)


## The rules or arena screen sends the players back to the lobby: their ready flags stay this once.
static func keep_ready_on_return() -> void:
	_keep_ready = true


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
	if event.is_pressed() and not event.is_echo():
		_last_slot = GameInput.event_slot(event)
	var touch: InputEventScreenTouch = event as InputEventScreenTouch
	if touch != null:
		_last_slot = -1
		if is_key_test_open():
			return
		var input: InputSlot = JoinScreen.touch_input_at(touch.position, get_viewport_rect().size)
		if touch.pressed and _free_card_at(touch.position) >= 0 and GameInput.find_input(input) < 0:
			get_viewport().set_input_as_handled()
			var joined: int = join(input)
			if joined >= 0:
				set_ready(joined, true)
		return
	if is_key_test_open():
		if UiKit.is_cancel(event):
			get_viewport().set_input_as_handled()
			close_key_test()
		return
	if event.is_action_pressed(KEY_TEST_ACTION) and not event.is_echo():
		get_viewport().set_input_as_handled()
		open_key_test()
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
	_seat_note = ""
	var slot: int = Flow.join_player(input)
	if slot < 0:
		if _lobby_full_by_the_cap():
			# G94: the device seats fewer heroes than the lobby has cards - say so instead of doing nothing.
			Audio.play_sfx(Sfx.MENU_BACK)
			_seat_note = seats_cap_text()
			refresh()
		return -1
	_held[slot] = false
	_hold[slot] = 0.0
	_dress(slot)
	_place_in_team(slot)
	refresh()
	return slot


## The human of seat `slot` leaves it.
func leave(slot: int) -> bool:
	_seat_note = ""
	if not Flow.leave_player(slot):
		return false
	Audio.play_sfx(Sfx.MENU_BACK)
	_held[slot] = false
	_hold[slot] = 0.0
	refresh()
	return true


## Seat a CPU of `level` (Defs.BotLevel) at `slot` ("Add CPU" on a free seat card). Returns false when it is taken, or
## when the match's chosen arena is for humans only in its mode (G50: its meta `bots` leaves the mode out; the status
## line says so - Random and Party Mix take CPUs).
func add_cpu(slot: int, level: int = Defs.BotLevel.HUNTER) -> bool:
	var versus_match: VersusMatch = Game.versus_match
	_seat_note = ""
	if slot >= VersusMatch.seat_limit() or (slot < 0 and _lobby_full_by_the_cap()):
		# G94: a seat card beyond the device's cap (a phone or tablet seats two heroes) refuses a CPU and says why.
		Audio.play_sfx(Sfx.MENU_BACK)
		_seat_note = seats_cap_text()
		refresh()
		return false
	if not VersusArenaScreen.bots_play(versus_match.arena, versus_match.mode):
		Audio.play_sfx(Sfx.MENU_BACK)
		_cpu_note = cpu_refused_text(versus_match.arena, versus_match.mode)
		refresh()
		return false
	_cpu_note = ""
	if versus_match.seat_bot(level, slot) < 0:
		return false
	_dress(slot)
	_place_in_team(slot)
	Audio.play_sfx(Sfx.MENU_SELECT)
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


## Turn the handicap card of seat `slot` one step (DESIGN.md E.4): the mode's own handicap (Last Caveman Standing
## hearts, Grub Stack stack guard), then Auto, then back to none.
func cycle_handicap(slot: int) -> void:
	var seat: VersusMatch.Seat = Game.versus_match.get_seat(slot)
	if seat == null or not seat.is_taken():
		return
	var steps: Array[int] = _handicap_steps()
	if seat.auto_handicap:
		seat.auto_handicap = false
		seat.hearts = HEART_STEPS[0]
		seat.stack_guard = GUARD_STEPS[0]
	else:
		var at: int = steps.find(_handicap_value(seat))
		if steps.is_empty() or at + 1 >= steps.size():
			seat.hearts = HEART_STEPS[0]
			seat.stack_guard = GUARD_STEPS[0]
			seat.auto_handicap = true
		else:
			_set_handicap_value(seat, steps[at + 1])
	Audio.play_sfx(Sfx.MENU_MOVE)
	refresh()


## Teams on (2 v 2: the first two taken seats are the Sun, the others the Moon) or off (free-for-all).
func set_teams(on: bool) -> void:
	var versus_match: VersusMatch = Game.versus_match
	var count: int = 0
	for slot: int in SEATS:
		var seat: VersusMatch.Seat = versus_match.get_seat(slot)
		if not seat.is_taken():
			seat.team = 0
			continue
		seat.team = (1 if count < 2 else 2) if on else 0
		count += 1
	_teams_row.set_index(1 if on else 0)
	refresh()


## The human of seat `slot` switches to the other team (2 v 2 only); a CPU of the team he joins moves the other way
## when that team is full.
func switch_team(slot: int) -> void:
	var versus_match: VersusMatch = Game.versus_match
	var seat: VersusMatch.Seat = versus_match.get_seat(slot)
	if seat == null or not seat.is_taken() or seat.team <= 0:
		return
	var target: int = 2 if seat.team == 1 else 1
	seat.team = target
	if _team_size(target) > 2:
		for other: int in SEATS:
			var mate: VersusMatch.Seat = versus_match.get_seat(other)
			if other != slot and mate.kind == VersusMatch.SeatKind.BOT and mate.team == target:
				mate.team = 1 if target == 2 else 2
				break
	Audio.play_sfx(Sfx.MENU_MOVE)
	refresh()


## True while teams are on.
func has_teams() -> bool:
	return _teams_row != null and _teams_row.index == 1


## The seat card of `slot` (tests).
func get_card(slot: int) -> JoinScreen.SeatCard:
	return _cards[slot] if slot >= 0 and slot < _cards.size() else null


## The START button (tests).
func get_start_button() -> UiButton:
	return _start


## The Cave Paintings button (tests).
func get_paintings_button() -> UiButton:
	return _paintings


## The Teams row (tests).
func get_teams_row() -> ChoiceRow:
	return _teams_row


## The status line under START.
func get_status_text() -> String:
	return _status.text


## The rules summary line ("Grub Stack - First to 3 - Random").
func get_summary_text() -> String:
	return _summary.text


## The keyboard test (tests).
func get_key_test() -> JoinScreen.PartyKeyTest:
	return _key_test


## True when START would open the rules now: two players or more, every human ready, teams of two.
func can_start() -> bool:
	if Game.versus_match == null or not Game.versus_match.can_start():
		return false
	return not has_teams() or _teams_even()


## START: the rules screen, controlled by the player who pressed it (args {"owner": slot}).
func open_rules() -> void:
	if not is_accepting_input():
		return
	if not can_start():
		Audio.play_sfx(Sfx.MENU_BACK)
		refresh()
		return
	if not begin_leave():
		return
	Audio.play_sfx(Sfx.MENU_SELECT)
	var owner: int = _last_slot if Game.versus_match.get_seat(_last_slot) != null \
			and Game.versus_match.get_seat(_last_slot).kind == VersusMatch.SeatKind.HUMAN else -1
	Game.versus_match.rules_owner = owner
	if Flow.has_screen(Flow.SCREEN_VERSUS_RULES):
		Flow.goto_screen(Flow.SCREEN_VERSUS_RULES, Defs.Transition.FADE, {"owner": owner})
	elif not Flow.start_versus():
		leaving = false
		refresh()


## The old name of START (P1.11 tests and tools): the rules screen.
func start_match() -> void:
	open_rules()


## The Cave Paintings and their rewards (back here afterwards, seats and ready flags kept).
func open_paintings() -> void:
	if not begin_leave():
		return
	Audio.play_sfx(Sfx.MENU_SELECT)
	Flow.goto_screen(Flow.SCREEN_UNLOCKS, Defs.Transition.FADE, {"back": Flow.SCREEN_VERSUS_LOBBY})


## Show the two-player keyboard test over the lobby (the seated keyboard players in join order).
func open_key_test() -> void:
	if is_key_test_open():
		return
	_key_test_layer.visible = true
	_key_test.show_party()
	Audio.play_sfx(Sfx.MENU_SELECT)


## Close the keyboard test.
func close_key_test() -> void:
	if not is_key_test_open():
		return
	_key_test_layer.visible = false
	Audio.play_sfx(Sfx.MENU_BACK)
	UiKit.focus_silently(_key_button)


## True while the keyboard test shows.
func is_key_test_open() -> bool:
	return _key_test_layer != null and _key_test_layer.visible and _key_test_layer.is_inside_tree()


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
		card.team = seat.team if seat.is_taken() and has_teams() else 0
		card.team_key = ""
		card.handicap_kind = &""
		card.handicap_value = ""
		card.handicap_key = ""
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
				if not seat.ready:
					card.team_key = JoinScreen.slot_key_text(slot, Defs.ACT_JUMP) if card.team > 0 else ""
					card.handicap_key = JoinScreen.slot_key_text(slot, Defs.ACT_SWAP)
				_fill_handicap(card, seat)
			VersusMatch.SeatKind.BOT:
				card.state = JoinScreen.SeatCard.State.BOT
				card.device_text = tr("UI_VS_CPU")
				card.bot_level = seat.bot_level
				card.player_ready = true
				_fill_handicap(card, seat)
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
	if is_key_test_open():
		_key_test.show_party()


## The text of a seat's handicap for the match's mode: "3 hearts", "Guard x1.5", "Auto", or "None".
static func handicap_text(seat: VersusMatch.Seat, mode: int) -> String:
	if seat == null:
		return ""
	if seat.auto_handicap:
		return TranslationServer.translate("UI_VS_HANDICAP_AUTO")
	match mode:
		Defs.VersusMode.LAST_CAVEMAN:
			if seat.hearts > 0 and seat.hearts != VersusTuning.LCS_HEARTS:
				return TranslationServer.translate("UI_VS_HANDICAP_HEARTS").format({"count": seat.hearts})
		Defs.VersusMode.GRUB_STACK:
			if seat.stack_guard != 1:
				return TranslationServer.translate("UI_VS_HANDICAP_GUARD").format({"factor": _guard_factor(seat.stack_guard)})
	return TranslationServer.translate("UI_VS_HANDICAP_OFF")


func _refresh_rules() -> void:
	var versus_match: VersusMatch = Game.versus_match
	var mode_key: String = str(MODE_KEYS.get(versus_match.mode, [""])[0])
	_summary.text = "%s  -  %s  -  %s" % [tr(mode_key), tr("UI_VS_FIRST_TO").format(
			{"wins": versus_match.round_wins_needed()}), tr(arena_text(versus_match.arena))]
	var status: String = ""
	if versus_match.player_count() < VersusTuning.PLAYERS_MIN:
		status = tr("UI_VS_NEED_TWO")
	elif has_teams() and not _teams_even():
		status = tr("UI_VS_TEAMS_UNEVEN")
	elif not versus_match.can_start():
		status = tr("UI_VS_NOT_READY")
	# G50: a refused "Add CPU" says why (it does not hold START back) until the arena or the mode takes CPUs again.
	if _cpu_note != "" and VersusArenaScreen.bots_play(versus_match.arena, versus_match.mode):
		_cpu_note = ""
	_status.text = _seat_note if _seat_note != "" else (_cpu_note if _cpu_note != "" else status)
	_status.add_theme_color_override(&"font_color", UiKit.COL_BAD if _status.text != "" else UiKit.COL_GOOD)
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


## True when the device's seat cap (below the lobby's four cards) is reached: every seat it has is taken.
func _lobby_full_by_the_cap() -> bool:
	var limit: int = VersusMatch.seat_limit()
	return limit < SEATS and Game.versus_match != null and Game.versus_match.player_count() >= limit


## G94: "This device seats 2 players." (the lobby's status when a seat beyond the device's cap is asked for).
static func seats_cap_text() -> String:
	return TranslationServer.translate("UI_VS_SEATS_CAP").format({"count": VersusMatch.seat_limit()})


## G50: "No CPU plays Grub Stack on Floe Rink." (the lobby's status when "Add CPU" is refused).
static func cpu_refused_text(arena_id: StringName, mode: int) -> String:
	return TranslationServer.translate("UI_VS_NO_CPU_HERE").format({
		"mode": TranslationServer.translate(str(MODE_KEYS.get(mode, [""])[0])),
		"arena": TranslationServer.translate(arena_text(arena_id)),
	})


## The name the lobby and the arena screen show for `arena_id`.
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
	elif _is_action(slot, event, Defs.ACT_JUMP):
		switch_team(slot)
	elif _is_action(slot, event, Defs.ACT_UP):
		cycle_pattern(slot, -1)
	elif _is_action(slot, event, Defs.ACT_DOWN):
		cycle_pattern(slot, 1)
	elif _is_action(slot, event, Defs.ACT_SWAP):
		cycle_handicap(slot)


func _is_action(slot: int, event: InputEvent, action: StringName) -> bool:
	var generated: StringName = GameInput.slot_action(slot, action)
	return InputMap.has_action(generated) and event.is_action(generated, true)


## A newly taken seat's look: its colour unless another seat wears it, its pattern or the seat's default.
func _dress(slot: int) -> void:
	var seat: VersusMatch.Seat = Game.versus_match.get_seat(slot)
	seat.palette = JoinScreen.free_colour(slot, seat.palette, _taken_colours(slot))
	if seat.pattern < 0 or not JoinScreen.pattern_choices().has(seat.pattern):
		seat.pattern = HeroPalette.slot_default_pattern(slot)


## A newly taken seat in a 2 v 2 match joins the smaller team (the Moon on a tie); free-for-all: no team.
func _place_in_team(slot: int) -> void:
	var seat: VersusMatch.Seat = Game.versus_match.get_seat(slot)
	if seat == null:
		return
	seat.team = 0
	if has_teams():
		seat.team = 1 if _team_size(1) < _team_size(2) else 2


func _team_size(team: int) -> int:
	var count: int = 0
	for slot: int in SEATS:
		var seat: VersusMatch.Seat = Game.versus_match.get_seat(slot)
		if seat.is_taken() and seat.team == team:
			count += 1
	return count


func _teams_even() -> bool:
	return _team_size(1) == 2 and _team_size(2) == 2


## True when the match's taken seats already carry teams (a lobby opened again after a 2 v 2 match).
func _has_teams() -> bool:
	for slot: int in SEATS:
		var seat: VersusMatch.Seat = Game.versus_match.get_seat(slot)
		if seat.is_taken() and seat.team > 0:
			return true
	return false


func _handicap_steps() -> Array[int]:
	match Game.versus_match.mode:
		Defs.VersusMode.LAST_CAVEMAN:
			return HEART_STEPS
		Defs.VersusMode.GRUB_STACK:
			return GUARD_STEPS
	var none: Array[int] = []
	return none


func _handicap_value(seat: VersusMatch.Seat) -> int:
	match Game.versus_match.mode:
		Defs.VersusMode.LAST_CAVEMAN:
			return seat.hearts
		Defs.VersusMode.GRUB_STACK:
			return seat.stack_guard
	return 0


func _set_handicap_value(seat: VersusMatch.Seat, value: int) -> void:
	match Game.versus_match.mode:
		Defs.VersusMode.LAST_CAVEMAN:
			seat.hearts = value
		Defs.VersusMode.GRUB_STACK:
			seat.stack_guard = value


## The handicap badge of a card for the match's mode (nothing while it is the default).
func _fill_handicap(card: JoinScreen.SeatCard, seat: VersusMatch.Seat) -> void:
	if seat.auto_handicap:
		card.handicap_kind = &"auto"
		card.handicap_value = ""
		return
	match Game.versus_match.mode:
		Defs.VersusMode.LAST_CAVEMAN:
			card.handicap_kind = &"hearts"
			card.handicap_value = str(seat.hearts if seat.hearts > 0 else VersusTuning.LCS_HEARTS)
		Defs.VersusMode.GRUB_STACK:
			card.handicap_kind = &"guard"
			card.handicap_value = "x" + _guard_factor(seat.stack_guard)
	if seat.kind == VersusMatch.SeatKind.BOT and handicap_text(seat, Game.versus_match.mode) \
			== TranslationServer.translate("UI_VS_HANDICAP_OFF"):
		card.handicap_kind = &""
		card.handicap_value = ""


static func _guard_factor(index: int) -> String:
	var percent: int = VersusTuning.STACK_GUARD_PERCENT[clampi(index, 0, VersusTuning.STACK_GUARD_PERCENT.size() - 1)]
	var text: String = "%.1f" % (float(percent) / 100.0)
	return text.trim_suffix(".0")


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


func _on_teams_changed(index: int) -> void:
	set_teams(index == 1)


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
	if is_key_test_open():
		close_key_test()
		return
	Audio.play_sfx(Sfx.MENU_BACK)
	if begin_leave():
		Flow.goto_title()


func _on_tap() -> void:
	pass


## A small menu entry (the fine-print face): Cave Paintings and the key test under START.
static func small_button(key: String, callback: Callable) -> UiButton:
	var button: UiButton = UiButton.new(key)
	button.add_theme_font_override(&"font", UiKit.font(UiKit.Style.SMALL))
	button.add_theme_font_size_override(&"font_size", UiKit.SIZE_SMALL)
	button.custom_minimum_size.y = 18.0
	button.pressed.connect(callback)
	return button


## The key test entry (tests).
func get_key_test_button() -> UiButton:
	return _key_button


## Focus: the seat cards in a row; under them on the left Teams, START, then Cave Paintings and the key test side by
## side; the keyboard preset on the right. Up from START reaches Teams, Up again the first card; Up from a card is
## START.
func _link_focus() -> void:
	for slot: int in SEATS:
		var card: JoinScreen.SeatCard = _cards[slot]
		card.focus_neighbor_left = card.get_path_to(_cards[posmod(slot - 1, SEATS)])
		card.focus_neighbor_right = card.get_path_to(_cards[(slot + 1) % SEATS])
		card.focus_neighbor_bottom = card.get_path_to(_teams_row if slot < SEATS / 2 else _layout_row)
		card.focus_neighbor_top = card.get_path_to(_start)
	_teams_row.focus_neighbor_top = _teams_row.get_path_to(_cards[0])
	_teams_row.focus_neighbor_bottom = _teams_row.get_path_to(_start)
	_teams_row.focus_neighbor_right = _teams_row.get_path_to(_layout_row)
	_start.focus_neighbor_top = _start.get_path_to(_teams_row)
	_start.focus_neighbor_bottom = _start.get_path_to(_paintings)
	_start.focus_neighbor_left = _start.get_path_to(_start)
	_start.focus_neighbor_right = _start.get_path_to(_layout_row)
	for button: UiButton in [_paintings, _key_button]:
		button.focus_neighbor_top = button.get_path_to(_start)
		button.focus_neighbor_bottom = button.get_path_to(_cards[0] if button == _paintings else _cards[1])
	_paintings.focus_neighbor_left = _paintings.get_path_to(_key_button)
	_paintings.focus_neighbor_right = _paintings.get_path_to(_key_button)
	_key_button.focus_neighbor_left = _key_button.get_path_to(_paintings)
	_key_button.focus_neighbor_right = _key_button.get_path_to(_layout_row)
	_layout_row.focus_neighbor_top = _layout_row.get_path_to(_cards[SEATS - 1])
	_layout_row.focus_neighbor_bottom = _layout_row.get_path_to(_start)
