class_name JoinScreen
extends UiScreen
## The co-op join panel "the Tribe Gathering" (DESIGN.md D.11, GAMEPLAY.md 13.9.1, PLAN.md P1.11).
##
## Two seat cards. **Press Jump on any device** to take the first free seat (Flow.join_player with
## GameInput.join_input_for_event: Jump of a keyboard half of the shared layout, or a pad's Jump); on a touch screen a
## tap on a free seat takes it with the touch overlay (touch_input_at: the whole screen, or in table mode the half of the
## tablet that was tapped) and is ready at once (touch has no Strike to hold on a menu). A seated player works
## his own card with his own keys: Left / Right = colour (PlayerRun.palette; a colour the partner wears is skipped),
## Up / Down = loincloth pattern, **hold Strike 1 s = ready** (PartyTuning.JOIN_READY_HOLD_TICKS), Look = not ready /
## leave the seat (Flow.leave_player), Swap = the keyboard test. When both players are ready the panel moves on to the
## book select (Flow.finish_join).
##
## Under the cards the shared keyboard: the three layouts of D.11 as presets (classic WASD + numpad first; Settings
## "controls/party_keyboard" through GameInput.set_keyboard_layout), a picture of the keyboard with each player's keys
## in his colour (the keys of a free half in grey), the key list of both halves, and ui-B's two-player ghosting test
## (UiKeyTest) as an overlay (Tab, or a seated player's Swap): it names "Num Lock" when a numpad key does not arrive.
##
## Who drives what: the menu clusters are on (GameInput.set_menu_clusters, both players navigate the next screens from
## their own keys). On this panel a seated player's keys belong to his card (once he is ready only his Look counts:
## it takes the ready back), and the keys of a free half do nothing but join (its Jump) and go back (its Look), so
## nobody changes the layout by reaching for his keys; the layout row is worked with the arrows, Enter, the mouse or
## a pad. "Back" leaves for the title (Flow.goto_title frees the seats).
##
## Shared parts for the versus lobby (versus_lobby.gd): [JoinScreen.SeatCard], [JoinScreen.KeyboardPicture], the
## colour / pattern lists and the key texts of a slot.

## Seats of a co-op party.
const SEATS: int = PartyTuning.COOP_PLAYERS
## Seconds a player holds Strike to be ready (1 s, PartyTuning.JOIN_READY_HOLD_TICKS).
const READY_SECONDS: float = float(PartyTuning.JOIN_READY_HOLD_TICKS) * Tuning.TICK_DT
## Seconds between "everybody is ready" and the book select (a Look in between takes it back).
const FINISH_DELAY: float = 0.6
## Colours a player can wear, in the order Left / Right steps through them (hero_palettes.json; white is only the
## jungle-arena swap of green). Gold comes with the Spear Party reward (Save.UNLOCK_SPEAR_PARTY).
const COLOURS: Array[StringName] = [&"yellow", &"blue", &"pink", &"green"]
const COLOUR_GOLD: StringName = &"gold"
const COLOUR_KEYS: Dictionary = {
	&"yellow": "UI_COLOUR_YELLOW", &"blue": "UI_COLOUR_BLUE", &"pink": "UI_COLOUR_PINK", &"green": "UI_COLOUR_GREEN",
	&"white": "UI_COLOUR_WHITE", &"gold": "UI_COLOUR_GOLD",
}
## The texts of the layout presets (InputSlot.KeyboardLayout order, ui-B's option texts).
const LAYOUT_KEYS: Array[String] = ["UI_OPT_KEYS_CLASSIC", "UI_OPT_KEYS_TWO_HANDS", "UI_OPT_KEYS_ONE_HAND"]
## The action rows of the key list beside the keyboard picture (DESIGN.md D.11), the move keys first.
const LEGEND_ACTIONS: Array[StringName] = [&"move", Defs.ACT_JUMP, Defs.ACT_ATTACK, Defs.ACT_SWAP, Defs.ACT_LOOK]
const LEGEND_KEYS: Dictionary = {
	&"move": "UI_ACTION_MOVE", Defs.ACT_JUMP: "UI_ACTION_JUMP", Defs.ACT_ATTACK: "UI_ACTION_ATTACK",
	Defs.ACT_SWAP: "UI_ACTION_SWAP", Defs.ACT_LOOK: "UI_ACTION_LOOK",
}
const MOVE_ACTIONS: Array[StringName] = [Defs.ACT_UP, Defs.ACT_LEFT, Defs.ACT_DOWN, Defs.ACT_RIGHT]
const CARD_SIZE: Vector2 = Vector2(236.0, 142.0)
## A seat card's "Hold <key> when ready" keeps this much of the card's width free (its frame and outline); a longer
## text takes the short form (UI_JOIN_HOLD_SHORT).
const HOLD_TEXT_MARGIN: float = 14.0
## Feet of the hero on a seat card (art px from the card's top).
const FEET_Y: float = 84.0
## Texts of the bot levels (Defs.BotLevel order).
const BOT_KEYS: Array[String] = ["UI_VS_BOT_ROOKIE", "UI_VS_BOT_HUNTER", "UI_VS_BOT_CHIEF"]
## Versus 2v2: the colours of the teams' pennants (index 1 Sun, 2 Moon; 0 unused) and their names.
const TEAM_COLOURS: Array[Color] = [Color("8a8f99"), Color("e8862a"), Color("4a4ab8")]
const TEAM_KEYS: Array[String] = ["UI_VS_TEAMS_FREE", "UI_VS_TEAM_1", "UI_VS_TEAM_2"]
const LEGEND_WIDTH: float = 138.0
## The menu action that opens the keyboard test (Tab; a seated player's Swap opens it too).
const KEY_TEST_ACTION: StringName = &"ui_focus_next"

## The book select is being opened (everybody was ready).
var finishing: bool = false

var _cards: Array[SeatCard] = []
var _ready_flags: Array[bool] = [false, false]
var _held: Array[bool] = [false, false]
var _hold: PackedFloat32Array = PackedFloat32Array([0.0, 0.0])
var _finish_wait: float = 0.0
var _layout_row: UiOptionRow = null
var _picture: KeyboardPicture = null
var _legends: Array[GridContainer] = []
var _legend_heads: Array[Label] = []
var _key_test_layer: Control = null
var _key_test: PartyKeyTest = null


# =================================================================================================================
# Shared parts (also used by the versus lobby)
# =================================================================================================================

## One player seat: the hero in the player's colour, his device, his colour choice and his ready state, or the call to
## join. Drawn on the menu panel; focusable only where it is a menu entry (the versus lobby's CPU seats).
class SeatCard:
	extends Button

	enum State { FREE, HUMAN, BOT }

	## Player slot (0..3).
	var slot: int = 0
	## State.
	var state: int = State.FREE
	## HUMAN / BOT: colour and loincloth pattern.
	var colour: StringName = &"yellow"
	var pattern: int = 0
	## HUMAN: device text ("Numpad", "Pad 1"); BOT: "CPU".
	var device_text: String = ""
	## HUMAN: ready, and how far the Strike hold got (0..1).
	var player_ready: bool = false
	var hold: float = 0.0
	## HUMAN: the key texts of his Left / Right (colour), Strike (ready) and Look (leave).
	var left_key: String = ""
	var right_key: String = ""
	var hold_key: String = ""
	var leave_key: String = ""
	## FREE: the Jump keys of the free halves and whether a pad is connected (its A joins).
	var join_keys: PackedStringArray = PackedStringArray()
	var pad_join: bool = false
	## BOT: Defs.BotLevel.
	var bot_level: int = Defs.BotLevel.HUNTER
	## FREE with focus (versus lobby): the text of what confirm does ("Add CPU").
	var free_action: String = ""
	## A line under the state ("First to 3"), or "".
	var note: String = ""
	## Versus lobby (DESIGN.md E.8): the team pennant on the left (0 = free-for-all: none; 1 Sun, 2 Moon) and the key
	## that switches it ("" = not shown); the handicap badge on the right (&"" = none; &"hearts", &"guard" or &"auto"
	## with its value text, "3" / "x1.5") and the key that changes it.
	var team: int = 0
	var team_key: String = ""
	var handicap_kind: StringName = &""
	var handicap_value: String = ""
	var handicap_key: String = ""

	var _actor: UiActor = null
	var _overlay: Control = null
	var _time: float = 0.0
	var _hud: Font = UiKit.font(UiKit.Style.HUD)
	var _body: Font = UiKit.font(UiKit.Style.BODY)
	var _small: Font = UiKit.font(UiKit.Style.SMALL)
	var _mono: Font = UiKit.font(UiKit.Style.MONO)

	func _init(p_slot: int, card_size: Vector2) -> void:
		slot = p_slot
		flat = true
		focus_mode = Control.FOCUS_NONE
		custom_minimum_size = card_size
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var back: NinePatchRect = UiKit.panel()
		back.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(back)
		_actor = UiActor.new(&"hero", &"idle")
		add_child(_actor)
		_overlay = Control.new()
		_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
		_overlay.draw.connect(_draw_overlay)
		add_child(_overlay)
		resized.connect(_place_actor)
		focus_entered.connect(_on_focus_changed)
		focus_exited.connect(_on_focus_changed)
		gui_input.connect(_on_gui_input)

	func _ready() -> void:
		_place_actor()
		refresh()

	func _process(delta: float) -> void:
		_time += delta
		if state == State.FREE or has_focus():
			_overlay.queue_redraw()

	## Make the card a menu entry (versus lobby) or a plain picture (join panel).
	func set_focusable(on: bool) -> void:
		focus_mode = Control.FOCUS_ALL if on else Control.FOCUS_NONE
		mouse_filter = Control.MOUSE_FILTER_STOP if on else Control.MOUSE_FILTER_IGNORE
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if on else Control.CURSOR_ARROW

	## Redraw the texts (the hold bar moves every frame).
	func redraw() -> void:
		_overlay.queue_redraw()

	## Show the current fields.
	func refresh() -> void:
		if _actor == null:
			return
		if state == State.FREE:
			_actor.material = null
			_actor.self_modulate = Color(UiKit.COL_INK, 0.55)
			_actor.play(&"idle")
		else:
			_actor.material = HeroPalette.material_for(colour, pattern)
			_actor.self_modulate = Color.WHITE
			_actor.play(&"victory" if player_ready else &"idle")
		_overlay.queue_redraw()

	## The text colour of this card's player (his colour, lifted for the dark cloths).
	func tag_colour() -> Color:
		if state == State.FREE:
			return UiKit.COL_DIM
		return JoinScreen.text_colour(colour)

	func _place_actor() -> void:
		if _actor != null:
			_actor.position = Vector2(roundf(size.x * 0.5), JoinScreen.FEET_Y)

	func _on_focus_changed() -> void:
		if has_focus():
			UiKit.play_focus_sound()
		_overlay.queue_redraw()

	func _on_gui_input(event: InputEvent) -> void:
		if event is InputEventMouseMotion and focus_mode != Control.FOCUS_NONE and not has_focus():
			grab_focus()

	func _draw_overlay() -> void:
		var width: float = size.x
		var focused: bool = has_focus()
		if focused:
			_overlay.draw_rect(Rect2(Vector2(5.0, 5.0), size - Vector2(10.0, 10.0)), Color(UiKit.COL_FOCUS, 0.9), false,
					2.0)
		# Header: the player tag on the left, the device on the right.
		var tag: String = UiPlayers.tag(slot)
		_text(_hud, UiKit.SIZE_HUD, tag, Vector2(12.0, 22.0), tag_colour(), true)
		if device_text != "" and state != State.FREE:
			var device_w: float = _small.get_string_size(device_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0,
					UiKit.SIZE_SMALL).x
			_text(_small, UiKit.SIZE_SMALL, device_text, Vector2(roundf(width - 12.0 - device_w), 20.0),
					UiKit.COL_CREAM, true)
		var y: float = JoinScreen.FEET_Y + 4.0
		match state:
			State.FREE:
				var call: String = free_action if focused and free_action != "" else tr("UI_JOIN_PRESS")
				var blink: bool = focused or fmod(_time, 1.2) < 0.85
				if blink:
					var colour: Color = UiKit.COL_FOCUS if focused else UiKit.COL_CREAM
					if _body.get_string_size(call, HORIZONTAL_ALIGNMENT_LEFT, -1.0, UiKit.SIZE_BODY).x <= size.x - 16.0:
						_centred(_body, UiKit.SIZE_BODY, call, y + 14.0, colour)
					else:
						_centred(_small, UiKit.SIZE_SMALL, call, y + 12.0, colour)
				_draw_caps(join_keys, pad_join, y + 22.0)
			State.HUMAN:
				var colour_name: String = tr(str(JoinScreen.COLOUR_KEYS.get(colour, String(colour))))
				_centred(_hud, UiKit.SIZE_HUD, colour_name, y + 12.0, tag_colour())
				if not player_ready:
					var name_w: float = _hud.get_string_size(colour_name, HORIZONTAL_ALIGNMENT_LEFT, -1.0,
							UiKit.SIZE_HUD).x
					var left_text: String = left_key
					var right_text: String = right_key
					var caps_w: float = JoinScreen.cap_width(_mono, left_text) + JoinScreen.cap_width(_mono, right_text)
					if name_w + caps_w + 16.0 > width - 16.0:
						# A narrow card (versus lobby): arrows instead of the key names.
						left_text = "<"
						right_text = ">"
					_arrow_cap(left_text, Vector2(roundf((width - name_w) * 0.5) - 8.0, y + 1.0), true)
					_arrow_cap(right_text, Vector2(roundf((width + name_w) * 0.5) + 8.0, y + 1.0), false)
					var hold_text: String = tr("UI_JOIN_HOLD").format({"key": hold_key})
					var hold_w: float = _small.get_string_size(hold_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0,
							UiKit.SIZE_SMALL).x
					if hold_w > width - JoinScreen.HOLD_TEXT_MARGIN:
						# A narrow card (four seats of the versus lobby) with a long key name: the short form.
						hold_text = tr("UI_JOIN_HOLD_SHORT").format({"key": hold_key})
					_centred(_small, UiKit.SIZE_SMALL, hold_text, y + 25.0, UiKit.COL_CREAM)
					var bar: Rect2 = Rect2(roundf(width * 0.5 - 40.0), y + 28.0, 80.0, 3.0)
					_overlay.draw_rect(bar.grow(1.0), UiKit.COL_INK)
					_overlay.draw_rect(Rect2(bar.position, Vector2(roundf(bar.size.x * clampf(hold, 0.0, 1.0)),
							bar.size.y)), tag_colour())
				else:
					_centred(_hud, UiKit.SIZE_HUD, tr("UI_JOIN_READY"), y + 29.0, UiKit.COL_GOOD)
				if leave_key != "":
					_hint_cap(leave_key, tr("UI_HINT_BACK") if player_ready else tr("UI_HINT_LEAVE"), size.y - 20.0)
			State.BOT:
				var level_key: String = JoinScreen.BOT_KEYS[clampi(bot_level, 0, JoinScreen.BOT_KEYS.size() - 1)]
				_centred(_hud, UiKit.SIZE_HUD, tr(level_key), y + 12.0, tag_colour())
				if focused:
					var accept: String = UiGlyphs.action_text(&"ui_accept", GameInput.get_glyph_set())
					if accept != "":
						_hint_cap(accept, tr("UI_HINT_CHANGE"), size.y - 20.0)
		if note != "":
			_centred(_small, UiKit.SIZE_SMALL, note, size.y - 10.0, UiKit.COL_CREAM)
		if state != State.FREE:
			if team > 0:
				_draw_team(Vector2(8.0, 30.0))
			if handicap_kind != &"":
				_draw_handicap(Vector2(size.x - 32.0, 30.0))

	## The team pennant: a cloth in the team's colour with a sun or a moon, the switch key under it.
	func _draw_team(pos: Vector2) -> void:
		var colour: Color = JoinScreen.TEAM_COLOURS[clampi(team, 1, 2)]
		var cloth: PackedVector2Array = [pos, pos + Vector2(24.0, 0.0), pos + Vector2(24.0, 22.0),
				pos + Vector2(12.0, 17.0), pos + Vector2(0.0, 22.0)]
		var border: PackedVector2Array = [pos + Vector2(-1.0, -1.0), pos + Vector2(25.0, -1.0), pos + Vector2(25.0, 24.0),
				pos + Vector2(12.0, 19.0), pos + Vector2(-1.0, 24.0)]
		_overlay.draw_colored_polygon(border, UiKit.COL_INK)
		_overlay.draw_colored_polygon(cloth, colour)
		var centre: Vector2 = pos + Vector2(12.0, 9.0)
		if team == 1:
			for i: int in 8:
				var angle: float = float(i) * PI / 4.0
				_overlay.draw_line(centre + Vector2(cos(angle), sin(angle)) * 4.0,
						centre + Vector2(cos(angle), sin(angle)) * 7.0, UiKit.COL_CREAM, 1.0)
			_overlay.draw_circle(centre, 4.0, UiKit.COL_CREAM)
		else:
			_overlay.draw_circle(centre, 6.0, UiKit.COL_CREAM)
			_overlay.draw_circle(centre + Vector2(3.0, -2.0), 5.0, colour)
		if team_key != "":
			var cap_w: float = JoinScreen.cap_width(_mono, team_key)
			JoinScreen.draw_cap(_overlay, _mono, Vector2(roundf(pos.x + 12.0 - cap_w * 0.5), pos.y + 27.0), team_key,
					UiKit.COL_CREAM)

	## The handicap badge: a heart with the hearts of Last Caveman Standing, a shield with the stack guard of Grub
	## Stack, or a leaf for Auto; the key that changes it under it.
	func _draw_handicap(pos: Vector2) -> void:
		var centre: Vector2 = pos + Vector2(12.0, 8.0)
		match handicap_kind:
			&"hearts":
				_overlay.draw_circle(centre + Vector2(-3.0, -2.0), 5.0, UiKit.COL_INK)
				_overlay.draw_circle(centre + Vector2(3.0, -2.0), 5.0, UiKit.COL_INK)
				_overlay.draw_colored_polygon(PackedVector2Array([centre + Vector2(-8.0, -1.0), centre + Vector2(8.0, -1.0),
						centre + Vector2(0.0, 9.0)]), UiKit.COL_INK)
				_overlay.draw_circle(centre + Vector2(-3.0, -2.0), 4.0, Color("e8384a"))
				_overlay.draw_circle(centre + Vector2(3.0, -2.0), 4.0, Color("e8384a"))
				_overlay.draw_colored_polygon(PackedVector2Array([centre + Vector2(-7.0, -1.0), centre + Vector2(7.0, -1.0),
						centre + Vector2(0.0, 7.0)]), Color("e8384a"))
			&"guard":
				var shield: PackedVector2Array = [centre + Vector2(-7.0, -7.0), centre + Vector2(7.0, -7.0),
						centre + Vector2(7.0, 1.0), centre + Vector2(0.0, 9.0), centre + Vector2(-7.0, 1.0)]
				var rim: PackedVector2Array = [centre + Vector2(-8.0, -8.0), centre + Vector2(8.0, -8.0),
						centre + Vector2(8.0, 2.0), centre + Vector2(0.0, 11.0), centre + Vector2(-8.0, 2.0)]
				_overlay.draw_colored_polygon(rim, UiKit.COL_INK)
				_overlay.draw_colored_polygon(shield, Color("8fa6c9"))
			&"auto":
				var leaf: PackedVector2Array = [centre + Vector2(0.0, -8.0), centre + Vector2(7.0, 0.0),
						centre + Vector2(0.0, 9.0), centre + Vector2(-7.0, 0.0)]
				_overlay.draw_colored_polygon(leaf, UiKit.COL_INK)
				_overlay.draw_colored_polygon(PackedVector2Array([centre + Vector2(0.0, -6.0), centre + Vector2(5.0, 0.0),
						centre + Vector2(0.0, 7.0), centre + Vector2(-5.0, 0.0)]), Color("5fbf3a"))
		if handicap_value != "":
			var value_w: float = _mono.get_string_size(handicap_value, HORIZONTAL_ALIGNMENT_LEFT, -1.0, UiKit.SIZE_MONO).x
			var at: Vector2 = Vector2(roundf(centre.x - value_w * 0.5), centre.y + 3.0)
			_overlay.draw_string_outline(_mono, at, handicap_value, HORIZONTAL_ALIGNMENT_LEFT, -1.0, UiKit.SIZE_MONO, 3,
					UiKit.COL_INK)
			_overlay.draw_string(_mono, at, handicap_value, HORIZONTAL_ALIGNMENT_LEFT, -1.0, UiKit.SIZE_MONO,
					UiKit.COL_CREAM)
		if handicap_key != "":
			var cap_w: float = JoinScreen.cap_width(_mono, handicap_key)
			JoinScreen.draw_cap(_overlay, _mono, Vector2(roundf(centre.x - cap_w * 0.5), pos.y + 27.0), handicap_key,
					UiKit.COL_CREAM)

	func _text(font: Font, font_size: int, text: String, pos: Vector2, colour: Color, outline: bool) -> void:
		if outline:
			_overlay.draw_string_outline(font, pos.round(), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size,
					6 if font == _body else 4, UiKit.COL_INK)
		_overlay.draw_string(font, pos.round(), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, colour)

	func _centred(font: Font, font_size: int, text: String, baseline: float, colour: Color) -> void:
		var text_w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
		_text(font, font_size, text, Vector2(roundf((size.x - text_w) * 0.5), baseline), colour, true)

	## A key cap and what it does, centred, the cap's top at `top`.
	func _hint_cap(key: String, text: String, top: float) -> void:
		var cap_w: float = JoinScreen.cap_width(_mono, key)
		var text_w: float = _small.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, UiKit.SIZE_SMALL).x
		var x: float = roundf((size.x - cap_w - 4.0 - text_w) * 0.5)
		JoinScreen.draw_cap(_overlay, _mono, Vector2(x, top), key, UiKit.COL_CREAM)
		_text(_small, UiKit.SIZE_SMALL, text, Vector2(x + cap_w + 4.0, top + 11.0), UiKit.COL_CREAM, true)

	## A small key cap with `text` whose outer edge is at `pos` (left of it for `left_side`).
	func _arrow_cap(text: String, pos: Vector2, left_side: bool) -> void:
		if text == "":
			return
		var cap_w: float = JoinScreen.cap_width(_mono, text)
		var x: float = pos.x - cap_w if left_side else pos.x
		JoinScreen.draw_cap(_overlay, _mono, Vector2(x, pos.y), text, UiKit.COL_CREAM)

	## The join glyphs of a free seat, centred: the free halves' Jump keys and a pad's A.
	func _draw_caps(keys: PackedStringArray, pad: bool, top: float) -> void:
		var widths: PackedFloat32Array = PackedFloat32Array()
		var total: float = 0.0
		for key: String in keys:
			widths.append(JoinScreen.cap_width(_mono, key))
			total += widths[-1] + 6.0
		if pad:
			total += 16.0 + 6.0
		var x: float = roundf((size.x - total + 6.0) * 0.5)
		for i: int in keys.size():
			JoinScreen.draw_cap(_overlay, _mono, Vector2(x, top), keys[i], UiKit.COL_CREAM)
			x += widths[i] + 6.0
		if pad:
			var centre: Vector2 = Vector2(x + 8.0, top + 7.0)
			_overlay.draw_circle(centre, 8.0, UiKit.COL_INK)
			_overlay.draw_circle(centre, 6.0, UiGlyphs.PAD_BUTTON_COLORS[JOY_BUTTON_A])
			var a_w: float = _mono.get_string_size("A", HORIZONTAL_ALIGNMENT_LEFT, -1.0, UiKit.SIZE_MONO).x
			_overlay.draw_string(_mono, Vector2(roundf(centre.x - a_w * 0.5), centre.y + 4.0), "A",
					HORIZONTAL_ALIGNMENT_LEFT, -1.0, UiKit.SIZE_MONO, UiKit.COL_INK)


## A picture of a full keyboard with the keys of each half of the shared layout in the colour of the player who uses
## them (the keys of a free half in grey with their names, every other key dark). A key that is held now is drawn
## pressed. Sized by its width: one key unit is at most MAX_UNIT art px.
class KeyboardPicture:
	extends Control

	const MAX_UNIT: int = 16
	const COLUMNS: float = 23.0
	const ROWS: int = 5
	## [physical key, x, row, width, height (rows), side] in key units; side: 0 any, 1 left, 2 right (Shift / Ctrl /
	## Alt / Meta: a binding names the key without its side, the half that uses it tells which one is meant).
	const KEYS: Array[Array] = [
		[KEY_QUOTELEFT, 0.0, 0, 1.0, 1, 0], [KEY_1, 1.0, 0, 1.0, 1, 0], [KEY_2, 2.0, 0, 1.0, 1, 0],
		[KEY_3, 3.0, 0, 1.0, 1, 0], [KEY_4, 4.0, 0, 1.0, 1, 0], [KEY_5, 5.0, 0, 1.0, 1, 0], [KEY_6, 6.0, 0, 1.0, 1, 0],
		[KEY_7, 7.0, 0, 1.0, 1, 0], [KEY_8, 8.0, 0, 1.0, 1, 0], [KEY_9, 9.0, 0, 1.0, 1, 0], [KEY_0, 10.0, 0, 1.0, 1, 0],
		[KEY_MINUS, 11.0, 0, 1.0, 1, 0], [KEY_EQUAL, 12.0, 0, 1.0, 1, 0], [KEY_BACKSPACE, 13.0, 0, 2.0, 1, 0],
		[KEY_TAB, 0.0, 1, 1.5, 1, 0], [KEY_Q, 1.5, 1, 1.0, 1, 0], [KEY_W, 2.5, 1, 1.0, 1, 0],
		[KEY_E, 3.5, 1, 1.0, 1, 0],
		[KEY_R, 4.5, 1, 1.0, 1, 0], [KEY_T, 5.5, 1, 1.0, 1, 0], [KEY_Y, 6.5, 1, 1.0, 1, 0], [KEY_U, 7.5, 1, 1.0, 1, 0],
		[KEY_I, 8.5, 1, 1.0, 1, 0], [KEY_O, 9.5, 1, 1.0, 1, 0], [KEY_P, 10.5, 1, 1.0, 1, 0],
		[KEY_BRACKETLEFT, 11.5, 1, 1.0, 1, 0], [KEY_BRACKETRIGHT, 12.5, 1, 1.0, 1, 0],
		[KEY_BACKSLASH, 13.5, 1, 1.5, 1, 0],
		[KEY_CAPSLOCK, 0.0, 2, 1.75, 1, 0], [KEY_A, 1.75, 2, 1.0, 1, 0], [KEY_S, 2.75, 2, 1.0, 1, 0],
		[KEY_D, 3.75, 2, 1.0, 1, 0], [KEY_F, 4.75, 2, 1.0, 1, 0], [KEY_G, 5.75, 2, 1.0, 1, 0],
		[KEY_H, 6.75, 2, 1.0, 1, 0], [KEY_J, 7.75, 2, 1.0, 1, 0], [KEY_K, 8.75, 2, 1.0, 1, 0],
		[KEY_L, 9.75, 2, 1.0, 1, 0], [KEY_SEMICOLON, 10.75, 2, 1.0, 1, 0], [KEY_APOSTROPHE, 11.75, 2, 1.0, 1, 0],
		[KEY_ENTER, 12.75, 2, 2.25, 1, 0],
		[KEY_SHIFT, 0.0, 3, 2.25, 1, 1], [KEY_Z, 2.25, 3, 1.0, 1, 0], [KEY_X, 3.25, 3, 1.0, 1, 0],
		[KEY_C, 4.25, 3, 1.0, 1, 0], [KEY_V, 5.25, 3, 1.0, 1, 0], [KEY_B, 6.25, 3, 1.0, 1, 0],
		[KEY_N, 7.25, 3, 1.0, 1, 0], [KEY_M, 8.25, 3, 1.0, 1, 0], [KEY_COMMA, 9.25, 3, 1.0, 1, 0],
		[KEY_PERIOD, 10.25, 3, 1.0, 1, 0], [KEY_SLASH, 11.25, 3, 1.0, 1, 0], [KEY_SHIFT, 12.25, 3, 2.75, 1, 2],
		[KEY_CTRL, 0.0, 4, 1.25, 1, 1], [KEY_META, 1.25, 4, 1.25, 1, 1], [KEY_ALT, 2.5, 4, 1.25, 1, 1],
		[KEY_SPACE, 3.75, 4, 6.25, 1, 0], [KEY_ALT, 10.0, 4, 1.25, 1, 2], [KEY_META, 11.25, 4, 1.25, 1, 2],
		[KEY_MENU, 12.5, 4, 1.25, 1, 0], [KEY_CTRL, 13.75, 4, 1.25, 1, 2],
		[KEY_INSERT, 15.5, 0, 1.0, 1, 0], [KEY_HOME, 16.5, 0, 1.0, 1, 0], [KEY_PAGEUP, 17.5, 0, 1.0, 1, 0],
		[KEY_DELETE, 15.5, 1, 1.0, 1, 0], [KEY_END, 16.5, 1, 1.0, 1, 0], [KEY_PAGEDOWN, 17.5, 1, 1.0, 1, 0],
		[KEY_UP, 16.5, 3, 1.0, 1, 0], [KEY_LEFT, 15.5, 4, 1.0, 1, 0], [KEY_DOWN, 16.5, 4, 1.0, 1, 0],
		[KEY_RIGHT, 17.5, 4, 1.0, 1, 0],
		[KEY_NUMLOCK, 19.0, 0, 1.0, 1, 0], [KEY_KP_DIVIDE, 20.0, 0, 1.0, 1, 0], [KEY_KP_MULTIPLY, 21.0, 0, 1.0, 1, 0],
		[KEY_KP_SUBTRACT, 22.0, 0, 1.0, 1, 0], [KEY_KP_7, 19.0, 1, 1.0, 1, 0], [KEY_KP_8, 20.0, 1, 1.0, 1, 0],
		[KEY_KP_9, 21.0, 1, 1.0, 1, 0], [KEY_KP_ADD, 22.0, 1, 1.0, 2, 0], [KEY_KP_4, 19.0, 2, 1.0, 1, 0],
		[KEY_KP_5, 20.0, 2, 1.0, 1, 0], [KEY_KP_6, 21.0, 2, 1.0, 1, 0], [KEY_KP_1, 19.0, 3, 1.0, 1, 0],
		[KEY_KP_2, 20.0, 3, 1.0, 1, 0], [KEY_KP_3, 21.0, 3, 1.0, 1, 0], [KEY_KP_ENTER, 22.0, 3, 1.0, 2, 0],
		[KEY_KP_0, 19.0, 4, 2.0, 1, 0], [KEY_KP_PERIOD, 21.0, 4, 1.0, 1, 0],
	]
	## Short names for the key caps of the picture (a cap is one to six units wide).
	const SHORT: Dictionary = {
		KEY_SPACE: "SPACE", KEY_SHIFT: "SHIFT", KEY_CTRL: "CTRL", KEY_ALT: "ALT", KEY_ENTER: "ENTER",
		KEY_KP_ENTER: "ENT", KEY_KP_ADD: "+", KEY_KP_PERIOD: ".", KEY_KP_0: "0", KEY_KP_1: "1", KEY_KP_2: "2",
		KEY_KP_3: "3", KEY_KP_4: "4", KEY_KP_5: "5", KEY_KP_6: "6", KEY_KP_7: "7", KEY_KP_8: "8", KEY_KP_9: "9",
		KEY_KP_DIVIDE: "/", KEY_KP_MULTIPLY: "*", KEY_KP_SUBTRACT: "-", KEY_UP: "^", KEY_LEFT: "<", KEY_DOWN: "v",
		KEY_RIGHT: ">", KEY_SEMICOLON: ";", KEY_COMMA: ",", KEY_PERIOD: ".", KEY_SLASH: "/", KEY_TAB: "TAB",
		KEY_BACKSPACE: "BKSP", KEY_CAPSLOCK: "CAPS", KEY_QUOTELEFT: "`", KEY_MINUS: "-", KEY_EQUAL: "=",
		KEY_BRACKETLEFT: "[", KEY_BRACKETRIGHT: "]", KEY_BACKSLASH: "\\", KEY_APOSTROPHE: "'",
	}
	## Shorter cap texts for keys whose name does not fit their cap.
	const ABBREVIATIONS: Dictionary = {"SHIFT": "SHF", "ENTER": "ENT", "SPACE": "SPC", "CTRL": "CTL", "BKSP": "BK"}

	## Per keyboard half (Defs.InputSlotKind.KEYBOARD_LEFT / KEYBOARD_RIGHT): {"keys": Array of physical keys,
	## "colour": Color, "taken": bool}. Set by the screen ([method set_halves]).
	var halves: Dictionary = {}

	var _mono: Font = UiKit.font(UiKit.Style.MONO)
	var _held: Dictionary = {}

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(COLUMNS * 12.0, float(ROWS) * 12.0)

	func _process(_delta: float) -> void:
		# Keys held now are drawn pressed (a live check of the cluster while the players read the picture).
		var changed: bool = false
		for half: Variant in halves:
			for code: Variant in (halves[half] as Dictionary).get("keys", []):
				var down: bool = Input.is_physical_key_pressed(code as Key)
				if down != bool(_held.get(code, false)):
					_held[code] = down
					changed = true
		if changed:
			queue_redraw()

	## The keys of both halves: `data` maps a half to {"keys": Array, "colour": Color, "taken": bool}.
	func set_halves(data: Dictionary) -> void:
		halves = data
		queue_redraw()

	## Art px per key unit at the current width.
	func unit() -> int:
		return clampi(floori(size.x / COLUMNS), 8, MAX_UNIT)

	## The half that lights `code` on the key of `side` (0 any, 1 left, 2 right), or NONE.
	func half_of(code: Key, side: int) -> int:
		for half: Variant in halves:
			if not ((halves[half] as Dictionary).get("keys", []) as Array).has(code):
				continue
			if side == 0 or (side == 1) == (int(half) == Defs.InputSlotKind.KEYBOARD_LEFT):
				return int(half)
		return Defs.InputSlotKind.NONE

	func _draw() -> void:
		var u: float = float(unit())
		var origin: Vector2 = Vector2(roundf((size.x - COLUMNS * u) * 0.5), roundf((size.y - float(ROWS) * u) * 0.5))
		for entry: Array in KEYS:
			var code: Key = entry[0] as Key
			var rect: Rect2 = Rect2(origin + Vector2(float(entry[1]) * u, float(entry[2]) * u),
					Vector2(float(entry[3]) * u, float(entry[4]) * u))
			var cap: Rect2 = Rect2(rect.position.round(), (rect.size - Vector2(1.0, 1.0)).round())
			var half: int = half_of(code, int(entry[5]))
			var face_colour: Color = Color(UiKit.COL_INK.lightened(0.16))
			var label_colour: Color = Color(0.0, 0.0, 0.0, 0.0)
			if half != Defs.InputSlotKind.NONE:
				var data: Dictionary = halves[half]
				if bool(data.get("taken", false)):
					face_colour = data["colour"]
					label_colour = UiKit.COL_INK
				else:
					face_colour = Color(UiKit.COL_CREAM.darkened(0.45))
					label_colour = UiKit.COL_CREAM
			var pressed: bool = half != Defs.InputSlotKind.NONE and bool(_held.get(code, false))
			draw_rect(cap, UiKit.COL_INK)
			var face: Rect2 = cap.grow(-1.0)
			if pressed:
				face.position.y += 1.0
				face_colour = face_colour.lightened(0.35)
			face.size.y -= 1.0
			draw_rect(face, face_colour)
			if label_colour.a > 0.0:
				_label(face, _cap_text(code), label_colour)

	func _cap_text(code: Key) -> String:
		if SHORT.has(code):
			return str(SHORT[code])
		return OS.get_keycode_string(code).to_upper().left(4)

	func _label(face: Rect2, text: String, colour: Color) -> void:
		var font_size: int = UiKit.SIZE_MONO
		var shown: String = text
		if ABBREVIATIONS.has(text) and _mono.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x \
				> face.size.x - 1.0:
			shown = str(ABBREVIATIONS[text])
		while shown.length() > 1 and _mono.get_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x \
				> face.size.x - 1.0:
			shown = shown.left(shown.length() - 1)
		var text_w: float = _mono.get_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
		var pos: Vector2 = Vector2(roundf(face.position.x + (face.size.x - text_w) * 0.5),
				roundf(face.position.y + (face.size.y - float(font_size)) * 0.5) + _mono.get_ascent(font_size))
		draw_string(_mono, pos, shown, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, colour)


## ui-B's two-player keyboard test showing the keyboard players **in join order** (PLAN.md P2.8): column 1 is the
## first seated player who plays on a keyboard half (P1 when he joined first, whatever half he took), column 2 the next
## one, each tagged and lit in his colour by his own keys; a half nobody sits at fills the remaining column as "Free"
## with the layout's keys, so the ghosting check works before the second player joins (UiKeyTest.set_players, which
## ui-B added for this; build/engine_requests/wf8_ui_a_to_ui_b.txt #2).
class PartyKeyTest:
	extends UiKeyTest

	## The columns' players as shown: [slot, half] each (slot -1 = a free half).
	var columns_shown: Array[Vector2i] = []

	## Show the players of `slots` (in this order; empty = every player slot in slot order = join order).
	func show_party(slots: PackedInt32Array = PackedInt32Array()) -> void:
		var order: PackedInt32Array = slots.duplicate()
		if order.is_empty():
			for slot: int in Defs.MAX_PLAYERS:
				order.append(slot)
		set_players(order)
		columns_shown = columns.duplicate()

	## The tag of column `column` as the player reads it ("P1", "Free").
	func column_tag(column: int) -> String:
		return tr(get_column_tag(column))


## Width of a key cap with `text` in the mono face.
static func cap_width(mono: Font, text: String) -> float:
	return mono.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, UiKit.SIZE_MONO).x + 6.0


## Draw a key cap (ink plate, cream text) with its top-left corner at `pos`; returns its width.
static func draw_cap(canvas: CanvasItem, mono: Font, pos: Vector2, text: String, colour: Color) -> float:
	var width: float = cap_width(mono, text)
	var rect: Rect2 = Rect2(pos.round(), Vector2(width, 14.0))
	canvas.draw_rect(rect, UiKit.COL_INK)
	canvas.draw_rect(Rect2(rect.position + Vector2(1.0, 1.0), rect.size - Vector2(2.0, 3.0)),
			Color(UiKit.COL_INK.lightened(0.2)))
	canvas.draw_string(mono, rect.position + Vector2(3.0, 3.0 + mono.get_ascent(UiKit.SIZE_MONO)), text,
			HORIZONTAL_ALIGNMENT_LEFT, -1.0, UiKit.SIZE_MONO, colour)
	return width


## The text colour of a palette on the dark menu plates: its fill, lifted towards its light colour for the dark
## cloths (pink, green) - UiPlayers.text_colour for a colour instead of a slot.
static func text_colour(colour: StringName) -> Color:
	var entry: Array = UiPlayers.PALETTE_COLOURS.get(colour, UiPlayers.PALETTE_COLOURS[&"yellow"])
	var fill: Color = entry[UiPlayers.FILL]
	if fill.get_luminance() < 0.45:
		return fill.lerp(entry[UiPlayers.LIGHT], 0.55)
	return fill


## The colours a player can choose now (COLOURS, plus gold once its reward is open: UnlockTable.is_palette_open).
static func colour_choices() -> Array[StringName]:
	var result: Array[StringName] = COLOURS.duplicate()
	if UnlockTable.is_palette_open(COLOUR_GOLD) and HeroPalette.has_colour(COLOUR_GOLD):
		result.append(COLOUR_GOLD)
	return result


## The loincloth patterns a player can choose now (hero_palettes.json `patterns` whose `unlock` tag is open:
## UnlockTable.is_pattern_open - the default ones, the eight more once the loincloth reward is open).
static func pattern_choices() -> PackedInt32Array:
	var result: PackedInt32Array = PackedInt32Array()
	for entry: Variant in HeroPalette.meta().get("patterns", []):
		if entry is Dictionary and UnlockTable.is_pattern_open(str(entry.get("unlock", UnlockTable.PATTERN_DEFAULT))):
			result.append(int(entry.get("index", 0)))
	if result.is_empty():
		result.append(0)
	return result


## The next colour from `current` in direction `step` (+1 / -1) that none of `taken` wears (`current` itself when
## every other colour is taken).
static func step_colour(current: StringName, step: int, taken: Array[StringName]) -> StringName:
	var choices: Array[StringName] = colour_choices()
	var at: int = maxi(choices.find(current), 0)
	for i: int in range(1, choices.size()):
		var candidate: StringName = choices[posmod(at + step * i, choices.size())]
		if not taken.has(candidate):
			return candidate
	return current


## A colour for a player who just took seat `slot`: his own (`wanted`) or the seat's default when nobody else wears
## it, else the first free one.
static func free_colour(slot: int, wanted: StringName, taken: Array[StringName]) -> StringName:
	var choices: Array[StringName] = colour_choices()
	if wanted != &"" and choices.has(wanted) and not taken.has(wanted):
		return wanted
	var default: StringName = HeroPalette.slot_default_colour(slot)
	if not taken.has(default):
		return default
	for colour: StringName in choices:
		if not taken.has(colour):
			return colour
	return default


## The next pattern from `current` in direction `step`.
static func step_pattern(current: int, step: int) -> int:
	var choices: PackedInt32Array = pattern_choices()
	var at: int = maxi(choices.find(current), 0)
	return choices[posmod(at + step, choices.size())]


## What a seat card calls the device of `input` ("Left keys", "Numpad", "Pad 2", "Touch").
static func device_text(input: InputSlot) -> String:
	if input == null:
		return ""
	match input.kind:
		Defs.InputSlotKind.KEYBOARD_LEFT:
			return TranslationServer.translate("UI_JOIN_KEYS_LEFT")
		Defs.InputSlotKind.KEYBOARD_RIGHT:
			if InputSlot.uses_numpad(GameInput.keyboard_layout(), Defs.InputSlotKind.KEYBOARD_RIGHT):
				return TranslationServer.translate("UI_JOIN_NUMPAD")
			return TranslationServer.translate("UI_JOIN_KEYS_RIGHT")
		Defs.InputSlotKind.KEYBOARD_FULL:
			return TranslationServer.translate("UI_OPT_PARTY_KEYS")
		Defs.InputSlotKind.PAD:
			return TranslationServer.translate("UI_JOIN_PAD").format({"number": input.device_id + 1})
		Defs.InputSlotKind.TOUCH:
			return TranslationServer.translate("UI_JOIN_TOUCH")
		Defs.InputSlotKind.BOT:
			return TranslationServer.translate("UI_VS_CPU")
	return ""


## The key / button text of game action `action` for the player of slot `slot` (his generated action's first event of
## his device family), "" when he has none.
static func slot_key_text(slot: int, action: StringName) -> String:
	var generated: StringName = GameInput.slot_action(slot, action)
	if not InputMap.has_action(generated):
		return ""
	var family: int = GameInput.get_slot(slot).device_family()
	var glyph_set: String = UiGlyphs.SET_GAMEPAD if family == Defs.Device.GAMEPAD else UiGlyphs.SET_KEYBOARD
	for event: InputEvent in InputMap.action_get_events(generated):
		if UiGlyphs.event_in_set(event, glyph_set):
			return UiGlyphs.event_text(event)
	return ""


## The Jump keys of the keyboard halves nobody sits at (the join glyphs of a free seat).
static func free_join_keys() -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	var layout: int = GameInput.keyboard_layout()
	for half: int in [Defs.InputSlotKind.KEYBOARD_LEFT, Defs.InputSlotKind.KEYBOARD_RIGHT]:
		if GameInput.find_input(InputSlot.keyboard(half)) >= 0:
			continue
		for code: Key in InputSlot.default_keys(layout, half, Defs.ACT_JUMP):
			result.append(_key_name(code))
			break
	return result


## The physical keys of keyboard half `half` and who uses them: {"keys": Array[Key], "slot": the player slot at that
## half or -1}. A seated player's own bindings (his generated actions) count; a free half shows the layout's keys.
static func half_keys(half: int) -> Dictionary:
	var slot: int = GameInput.find_input(InputSlot.keyboard(half))
	var keys: Array = []
	for action: StringName in Defs.GAME_ACTIONS:
		for code: Key in action_keys(half, slot, action):
			if not keys.has(code):
				keys.append(code)
	return {"keys": keys, "slot": slot}


## The physical keys of `action` for keyboard half `half` (its player `slot`'s bindings, or the layout's keys).
static func action_keys(half: int, slot: int, action: StringName) -> Array[Key]:
	var result: Array[Key] = []
	if slot >= 0 and InputMap.has_action(GameInput.slot_action(slot, action)):
		for event: InputEvent in InputMap.action_get_events(GameInput.slot_action(slot, action)):
			var key: InputEventKey = event as InputEventKey
			if key != null:
				result.append(key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode)
		return result
	return InputSlot.default_keys(GameInput.keyboard_layout(), half, action)


## The text of a legend row of keyboard half `half` ("W A S D", "NUM 8 4 5 6", "ARROWS", "SPACE").
static func legend_text(half: int, slot: int, row: StringName) -> String:
	if row != &"move":
		var keys: Array[Key] = action_keys(half, slot, row)
		return _key_name(keys[0]) if not keys.is_empty() else "-"
	var names: PackedStringArray = PackedStringArray()
	var codes: Array[Key] = []
	for action: StringName in MOVE_ACTIONS:
		var keys: Array[Key] = action_keys(half, slot, action)
		if not keys.is_empty():
			codes.append(keys[0])
			names.append(_key_name(keys[0]))
	if codes.size() == 4 and codes.has(KEY_UP) and codes.has(KEY_DOWN) and codes.has(KEY_LEFT) and codes.has(KEY_RIGHT):
		return "ARROWS"
	var numpad: bool = not names.is_empty()
	var digits: PackedStringArray = PackedStringArray()
	for text: String in names:
		numpad = numpad and text.begins_with("NUM ")
		digits.append(text.trim_prefix("NUM "))
	if numpad:
		return "NUM " + " ".join(digits)
	if codes.size() == 3 and not codes.has(KEY_UP) and codes.has(KEY_LEFT) and codes.has(KEY_RIGHT):
		return "ARROWS"
	return " ".join(names)


static func _key_name(code: Key) -> String:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = code
	return UiGlyphs.key_text(event)


# =================================================================================================================
# The join panel
# =================================================================================================================

func _build_screen() -> void:
	add_child(UiBackdrop.new("jungle", 24.0))
	var shade: ColorRect = ColorRect.new()
	shade.color = Color(UiKit.COL_INK, 0.3)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	var column: VBoxContainer = VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override(&"separation", 4)
	safe.add_child(column)
	column.add_child(UiKit.label("UI_JOIN_HEADING", UiKit.Style.TITLE, HORIZONTAL_ALIGNMENT_CENTER))

	var seats: HBoxContainer = HBoxContainer.new()
	seats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	seats.alignment = BoxContainer.ALIGNMENT_CENTER
	seats.add_theme_constant_override(&"separation", 16)
	seats.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(seats)
	for slot: int in SEATS:
		var card: SeatCard = SeatCard.new(slot, CARD_SIZE)
		card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		seats.add_child(card)
		_cards.append(card)

	column.add_child(_keyboard_panel())

	var prompts: UiPrompts = UiPrompts.new()
	prompts.add_hint(&"ui_left", "UI_HINT_CHANGE")
	prompts.add_hint(KEY_TEST_ACTION, "UI_JOIN_KEY_TEST", open_key_test)
	prompts.add_hint(&"ui_cancel", "UI_HINT_BACK", _on_cancel)
	column.add_child(prompts)

	# Added in _screen_ready: above the safe-area content, which UiScreen adds after _build_screen.
	_key_test_layer = _key_test_overlay()


func _screen_ready() -> void:
	add_child(_key_test_layer)
	Audio.play_music(Sfx.MUSIC_COOP_MENU)
	GameInput.set_menu_clusters(true)
	if GameInput.get_slot(0).kind == Defs.InputSlotKind.ALL_DEVICES:
		# Opened without Flow.open_play (previews, tests): nobody sits at a seat yet.
		Flow.begin_party_setup()
	for slot: int in SEATS:
		if is_joined(slot):
			_dress(slot)
	Flow.party_changed.connect(_on_party_changed)
	Settings.changed.connect(_on_setting_changed)
	UiKit.focus_silently(_layout_row)
	refresh()


func _process(delta: float) -> void:
	if not is_accepting_input():
		return
	for slot: int in SEATS:
		if not is_joined(slot) or _ready_flags[slot]:
			_hold[slot] = 0.0
			continue
		if _held[slot]:
			_hold[slot] += delta
			if _hold[slot] >= READY_SECONDS:
				set_ready(slot, true)
		else:
			_hold[slot] = 0.0
		_cards[slot].hold = _hold[slot] / READY_SECONDS
		_cards[slot].redraw()
	if everybody_ready():
		_finish_wait += delta
		if _finish_wait >= FINISH_DELAY:
			_finish()
	else:
		_finish_wait = 0.0


func _input(event: InputEvent) -> void:
	if not is_accepting_input() or event is InputEventMouse or event is InputEventScreenDrag:
		return
	var touch: InputEventScreenTouch = event as InputEventScreenTouch
	if touch != null:
		if touch.pressed and not is_key_test_open() and _free_card_at(touch.position) >= 0:
			get_viewport().set_input_as_handled()
			var joined: int = join(touch_input_at(touch.position, get_viewport_rect().size))
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
		get_viewport().set_input_as_handled()
		_player_input(slot, event)
		return
	var input: InputSlot = GameInput.join_input_for_event(event)
	if input != null:
		get_viewport().set_input_as_handled()
		join(input)
		return
	# The other keys of a free half: only its Look (back) counts.
	if GameInput.event_half(event) != Defs.InputSlotKind.NONE and not UiKit.is_cancel(event):
		get_viewport().set_input_as_handled()


## The touch input of a tap at `pos` on a view of `view_size`: the whole screen, or in table mode (a tablet of 9
## inches or more, TouchControls.table_mode_available) the half of it the tapping player sits at.
static func touch_input_at(pos: Vector2, view_size: Vector2) -> InputSlot:
	if not TouchControls.table_mode_available() or view_size.y <= 0.0:
		return InputSlot.touch()
	var regions: Array[Rect2] = TouchControls.table_regions()
	var point: Vector2 = Vector2(pos.x / maxf(view_size.x, 1.0), pos.y / view_size.y)
	for region: Rect2 in regions:
		if region.has_point(point):
			return InputSlot.touch(region)
	return InputSlot.touch(regions[0])


## The seated player whose own keys / pad `event` comes from, or -1.
func player_of(event: InputEvent) -> int:
	if GameInput.get_slot(0).kind == Defs.InputSlotKind.ALL_DEVICES:
		return -1
	var slot: int = GameInput.event_slot(event)
	return slot if slot >= 0 and slot < SEATS and is_joined(slot) else -1


## A player takes the first free seat with `input` (Flow.join_player). Returns the seat or -1.
func join(input: InputSlot) -> int:
	if input == null or finishing:
		return -1
	var slot: int = Flow.join_player(input)
	if slot < 0:
		return -1
	_ready_flags[slot] = false
	_held[slot] = false
	_hold[slot] = 0.0
	_dress(slot)
	refresh()
	return slot


## The player of seat `slot` leaves it (the player after him moves up, with his look).
func leave(slot: int) -> bool:
	if not is_joined(slot):
		return false
	if not Flow.leave_player(slot):
		return false
	Audio.play_sfx(Sfx.MENU_BACK)
	for at: int in range(slot, SEATS - 1):
		_ready_flags[at] = _ready_flags[at + 1]
		_held[at] = false
		_hold[at] = 0.0
	_ready_flags[SEATS - 1] = false
	_held[SEATS - 1] = false
	_hold[SEATS - 1] = 0.0
	refresh()
	return true


## True when somebody sits at seat `slot`.
func is_joined(slot: int) -> bool:
	if slot < 0 or slot >= SEATS:
		return false
	var kind: int = GameInput.get_slot(slot).kind
	return kind != Defs.InputSlotKind.NONE and kind != Defs.InputSlotKind.ALL_DEVICES


## True when the player of seat `slot` is ready.
func is_ready(slot: int) -> bool:
	return slot >= 0 and slot < SEATS and is_joined(slot) and _ready_flags[slot]


## How far the player of seat `slot` held Strike towards ready (0..1).
func hold_progress(slot: int) -> float:
	return clampf(_hold[slot] / READY_SECONDS, 0.0, 1.0) if slot >= 0 and slot < SEATS else 0.0


## Mark the player of seat `slot` ready (or not).
func set_ready(slot: int, on: bool) -> void:
	if not is_joined(slot) or _ready_flags[slot] == on:
		return
	_ready_flags[slot] = on
	_hold[slot] = 0.0
	_held[slot] = false
	Audio.play_sfx(Sfx.MENU_SELECT if on else Sfx.MENU_BACK)
	refresh()


## True when the party is complete and everybody in it is ready.
func everybody_ready() -> bool:
	if Flow.party_size() < SEATS:
		return false
	for slot: int in SEATS:
		if not is_ready(slot):
			return false
	return true


## Step the colour of seat `slot` by `step` (+1 / -1), skipping the partner's colour.
func cycle_colour(slot: int, step: int) -> void:
	if not is_joined(slot):
		return
	var run: PlayerRun = Game.get_run(slot)
	var current: StringName = HeroPalette.resolve(slot, run)[0]
	var next: StringName = step_colour(current, step, _taken_colours(slot))
	if next != current:
		run.palette = next
		Audio.play_sfx(Sfx.MENU_MOVE)
		refresh()


## Step the loincloth pattern of seat `slot` by `step`.
func cycle_pattern(slot: int, step: int) -> void:
	if not is_joined(slot):
		return
	var run: PlayerRun = Game.get_run(slot)
	run.pattern = step_pattern(int(HeroPalette.resolve(slot, run)[1]), step)
	Audio.play_sfx(Sfx.MENU_MOVE)
	refresh()


## The seat card of `slot` (tests, previews).
func get_card(slot: int) -> SeatCard:
	return _cards[slot] if slot >= 0 and slot < _cards.size() else null


## The keyboard picture.
func get_picture() -> KeyboardPicture:
	return _picture


## The legend text of `row` (&"move" or a game action) for keyboard half `half` as the panel shows it.
func get_legend_text(half: int, row: StringName) -> String:
	var at: int = 0 if half == Defs.InputSlotKind.KEYBOARD_LEFT else 1
	if at >= _legends.size():
		return ""
	var index: int = LEGEND_ACTIONS.find(row)
	var grid: GridContainer = _legends[at]
	if index < 0 or index * 2 + 1 >= grid.get_child_count():
		return ""
	return (grid.get_child(index * 2 + 1) as Label).text


## The layout row (tests).
func get_layout_row() -> UiOptionRow:
	return _layout_row


## Show ui-B's two-player keyboard test over the panel, the seated players in join order (PartyKeyTest).
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
	UiKit.focus_silently(_layout_row)


## True while the keyboard test shows.
func is_key_test_open() -> bool:
	return _key_test_layer != null and _key_test_layer.visible


## The keyboard test (tests).
func get_key_test() -> PartyKeyTest:
	return _key_test


## Show the seats, the picture and the key list as they are now.
func refresh() -> void:
	var taken_halves: Array[int] = []
	for slot: int in SEATS:
		var card: SeatCard = _cards[slot]
		if not is_joined(slot):
			card.state = SeatCard.State.FREE
			card.join_keys = free_join_keys()
			card.pad_join = not Input.get_connected_joypads().is_empty()
			card.device_text = ""
		else:
			var input: InputSlot = GameInput.get_slot(slot)
			var look: Array = HeroPalette.resolve(slot, Game.get_run(slot))
			card.state = SeatCard.State.HUMAN
			card.colour = look[0]
			card.pattern = int(look[1])
			card.device_text = device_text(input)
			card.player_ready = _ready_flags[slot]
			card.hold = hold_progress(slot)
			card.left_key = slot_key_text(slot, Defs.ACT_LEFT)
			card.right_key = slot_key_text(slot, Defs.ACT_RIGHT)
			card.hold_key = slot_key_text(slot, Defs.ACT_ATTACK)
			card.leave_key = slot_key_text(slot, Defs.ACT_LOOK)
			if input.keyboard_half() != Defs.InputSlotKind.NONE:
				taken_halves.append(input.keyboard_half())
		card.refresh()
	if _layout_row != null:
		_layout_row.set_index(GameInput.keyboard_layout())
	_refresh_keyboard()


func _refresh_keyboard() -> void:
	var data: Dictionary = {}
	var halves: Array[int] = [Defs.InputSlotKind.KEYBOARD_LEFT, Defs.InputSlotKind.KEYBOARD_RIGHT]
	for i: int in halves.size():
		var half: int = halves[i]
		var info: Dictionary = half_keys(half)
		var slot: int = int(info["slot"])
		var colour: Color = UiKit.COL_CREAM
		if slot >= 0:
			colour = Color(UiPlayers.PALETTE_COLOURS.get(HeroPalette.resolve(slot, Game.get_run(slot))[0],
					UiPlayers.PALETTE_COLOURS[&"yellow"])[UiPlayers.FILL])
		data[half] = {"keys": info["keys"], "colour": colour, "taken": slot >= 0}
		if i < _legends.size():
			var head: Label = _legend_heads[i]
			if slot >= 0:
				head.text = UiPlayers.tag(slot)
				var look: Array = HeroPalette.resolve(slot, Game.get_run(slot))
				head.add_theme_color_override(&"font_color", text_colour(look[0]))
			else:
				head.text = TranslationServer.translate("UI_JOIN_FREE")
				head.add_theme_color_override(&"font_color", UiKit.COL_DIM)
			var grid: GridContainer = _legends[i]
			for row: int in LEGEND_ACTIONS.size():
				(grid.get_child(row * 2 + 1) as Label).text = legend_text(half, slot, LEGEND_ACTIONS[row])
	if _picture != null:
		_picture.set_halves(data)


func _player_input(slot: int, event: InputEvent) -> void:
	if _is_action(slot, event, Defs.ACT_ATTACK):
		_held[slot] = event.is_pressed()
		return
	if not event.is_pressed() or event.is_echo():
		return
	if _is_action(slot, event, Defs.ACT_LOOK):
		if _ready_flags[slot]:
			set_ready(slot, false)
		else:
			leave(slot)
	elif _ready_flags[slot]:
		return
	elif _is_action(slot, event, Defs.ACT_LEFT):
		cycle_colour(slot, -1)
	elif _is_action(slot, event, Defs.ACT_RIGHT):
		cycle_colour(slot, 1)
	elif _is_action(slot, event, Defs.ACT_UP):
		cycle_pattern(slot, -1)
	elif _is_action(slot, event, Defs.ACT_DOWN):
		cycle_pattern(slot, 1)
	elif _is_action(slot, event, Defs.ACT_SWAP):
		open_key_test()


func _is_action(slot: int, event: InputEvent, action: StringName) -> bool:
	var generated: StringName = GameInput.slot_action(slot, action)
	return InputMap.has_action(generated) and event.is_action(generated, true)


## A newly seated player's look: his colour unless the partner wears it, his pattern or the seat's default.
func _dress(slot: int) -> void:
	var run: PlayerRun = Game.get_run(slot)
	run.palette = free_colour(slot, run.palette, _taken_colours(slot))
	if run.pattern < 0 or not pattern_choices().has(run.pattern):
		run.pattern = HeroPalette.slot_default_pattern(slot)


## The free seat whose card lies under `pos` (view px), or -1.
func _free_card_at(pos: Vector2) -> int:
	for slot: int in _cards.size():
		if not is_joined(slot) and _cards[slot].get_global_rect().has_point(pos):
			return slot
	return -1


## The colours the other seated players wear.
func _taken_colours(slot: int) -> Array[StringName]:
	var result: Array[StringName] = []
	for other: int in SEATS:
		if other != slot and is_joined(other):
			result.append(HeroPalette.resolve(other, Game.get_run(other))[0])
	return result


func _finish() -> void:
	if finishing or not begin_leave():
		return
	finishing = true
	Audio.play_sfx(Sfx.MENU_SELECT)
	if not Flow.finish_join():
		finishing = false
		leaving = false


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


func _on_party_changed(_size: int) -> void:
	for slot: int in SEATS:
		if is_joined(slot) and Game.get_run(slot).palette == &"":
			_dress(slot)
	refresh()


func _on_setting_changed(key: String, _value: Variant) -> void:
	if key == Settings.PARTY_KEYBOARD_KEY or key == Settings.BINDINGS_KEY:
		refresh()


func _on_layout_changed(index: int) -> void:
	GameInput.set_keyboard_layout(index)


## The shared-keyboard panel: the preset row, then the key list of the left half, the picture and
## the key list of the right half.
func _keyboard_panel() -> Control:
	var inner: VBoxContainer = VBoxContainer.new()
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_theme_constant_override(&"separation", 2)
	var options: PackedStringArray = PackedStringArray(LAYOUT_KEYS)
	_layout_row = UiOptionRow.choice("UI_OPT_PARTY_KEYS", options, GameInput.keyboard_layout())
	_layout_row.changed.connect(_on_layout_changed)
	_layout_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_child(_layout_row)

	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override(&"separation", 6)
	inner.add_child(row)
	row.add_child(_legend(HORIZONTAL_ALIGNMENT_LEFT))
	var middle: VBoxContainer = VBoxContainer.new()
	middle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	middle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	middle.add_theme_constant_override(&"separation", 0)
	row.add_child(middle)
	_picture = KeyboardPicture.new()
	_picture.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_picture.size_flags_vertical = Control.SIZE_EXPAND_FILL
	middle.add_child(_picture)
	row.add_child(_legend(HORIZONTAL_ALIGNMENT_RIGHT))
	return UiKit.panel_box(inner, 8)


## The key list of one half: a heading (the player's tag or "free") and one row per action.
func _legend(align: int) -> Control:
	var box: VBoxContainer = VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.custom_minimum_size = Vector2(LEGEND_WIDTH, 0.0)
	box.add_theme_constant_override(&"separation", 0)
	var head: Label = UiKit.label("", UiKit.Style.HUD, align)
	head.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	box.add_child(head)
	_legend_heads.append(head)
	var grid: GridContainer = GridContainer.new()
	grid.columns = 2
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid.add_theme_constant_override(&"h_separation", 6)
	grid.add_theme_constant_override(&"v_separation", 0)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_END if align == HORIZONTAL_ALIGNMENT_RIGHT \
			else Control.SIZE_SHRINK_BEGIN
	for action: StringName in LEGEND_ACTIONS:
		var caption: Label = UiKit.label(str(LEGEND_KEYS[action]), UiKit.Style.SMALL)
		grid.add_child(caption)
		var keys: Label = UiKit.label("", UiKit.Style.MONO)
		keys.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		keys.custom_minimum_size = Vector2(0.0, 12.0)
		keys.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		grid.add_child(keys)
	box.add_child(grid)
	_legends.append(grid)
	return box


## ui-B's keyboard test on a panel over the screen (hidden until opened); the versus lobby uses it too.
func _key_test_overlay() -> Control:
	var layer: Control = JoinScreen.key_test_layer(close_key_test)
	_key_test = layer.get_meta(&"key_test") as PartyKeyTest
	return layer


## A hidden layer over a screen with the keyboard test on a panel ([PartyKeyTest], its node in the meta "key_test")
## and a "back" hint that calls `close`.
static func key_test_layer(close: Callable) -> Control:
	var layer: Control = Control.new()
	layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.visible = false
	var dim: ColorRect = ColorRect.new()
	dim.color = UiKit.COL_SHADE
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(dim)
	var centre: CenterContainer = CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(centre)
	var column: VBoxContainer = VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override(&"separation", 4)
	column.add_child(UiKit.label("UI_OPT_KEY_TEST", UiKit.Style.HUD, HORIZONTAL_ALIGNMENT_CENTER))
	var key_test: PartyKeyTest = PartyKeyTest.new()
	column.add_child(key_test)
	layer.set_meta(&"key_test", key_test)
	var prompts: UiPrompts = UiPrompts.new()
	prompts.add_hint(&"ui_cancel", "UI_HINT_BACK", close)
	column.add_child(prompts)
	centre.add_child(UiKit.panel_box(column, 14))
	return layer
