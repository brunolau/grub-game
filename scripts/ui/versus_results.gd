class_name VersusResultsScreen
extends UiScreen
## The results of a versus match (DESIGN.md E.8 step 7, GAMEPLAY.md 13.10.11; PLAN.md P1.11 / P2.8).
##
## Args (Flow._show_versus_results): {"winners": PackedInt32Array, "awards": {slot: Array[StringName] of
## PlayerRun.VERSUS_AWARDS ids, 1-3 each}}. On art-A's torch-lit cave wall (`ui/cave_wall.png`) the heroes are
## **painted in victory poses** in their colours (the match winner - both of a team - cheering under the crown), and
## under each painting his portrait stands behind his plate of round wins as golden drumsticks ([PlayerColumn]). Then
## the tally companion, at the wall's right end, **hands out the awards**: one every AWARD_SECONDS, a medal (art-A's
## disc on a ribbon in the player's colour) flies from him to its player's column and the award's name and reason
## appear under the plate (a tap shows the rest at once). **Rematch** is the default button
## (Flow.rematch); Lobby (Flow.leave_versus) and Quit to title (Flow.leave_versus(true)); "back" = the lobby. Every
## player drives the buttons from his own key cluster. Music: the match-win jingle, then the results loop; an applause
## bed at the start.

## Seconds before a confirm counts (a Strike still held from the last round must not start the rematch).
const ACCEPT_GRACE: float = 0.8
const COLUMN_SIZE: Vector2 = Vector2(144.0, 134.0)
## art-A's cave wall behind the results (640 x 360, centred; the cave backdrop fills wider views).
const TEX_WALL: String = "res://assets/ui/cave_wall.png"
## Seconds between two awards handed out, and before the first.
const AWARD_SECONDS: float = 0.45
const AWARD_DELAY: float = 0.9
## The awards' texts: UI_AWARD_<ID> (name) and UI_AWARD_<ID>_INFO (what it was for), by PlayerRun.VERSUS_AWARDS id.
const AWARD_KEYS: Dictionary = {
	&"leaning_tower": ["UI_AWARD_LEANING_TOWER", "UI_AWARD_LEANING_TOWER_INFO"],
	&"pickpocket": ["UI_AWARD_PICKPOCKET", "UI_AWARD_PICKPOCKET_INFO"],
	&"glutton": ["UI_AWARD_GLUTTON", "UI_AWARD_GLUTTON_INFO"],
	&"butterfingers": ["UI_AWARD_BUTTERFINGERS", "UI_AWARD_BUTTERFINGERS_INFO"],
	&"chain_gang": ["UI_AWARD_CHAIN_GANG", "UI_AWARD_CHAIN_GANG_INFO"],
	&"clang_master": ["UI_AWARD_CLANG_MASTER", "UI_AWARD_CLANG_MASTER_INFO"],
	&"slugger": ["UI_AWARD_SLUGGER", "UI_AWARD_SLUGGER_INFO"],
	&"home_run": ["UI_AWARD_HOME_RUN", "UI_AWARD_HOME_RUN_INFO"],
	&"hot_potato": ["UI_AWARD_HOT_POTATO", "UI_AWARD_HOT_POTATO_INFO"],
	&"lava_lover": ["UI_AWARD_LAVA_LOVER", "UI_AWARD_LAVA_LOVER_INFO"],
	&"head_case": ["UI_AWARD_HEAD_CASE", "UI_AWARD_HEAD_CASE_INFO"],
	&"comeback_caveman": ["UI_AWARD_COMEBACK_CAVEMAN", "UI_AWARD_COMEBACK_CAVEMAN_INFO"],
	&"pacifist": ["UI_AWARD_PACIFIST", "UI_AWARD_PACIFIST_INFO"],
}
static var _plain_small: Font = null

## Awards handed out so far (entries of [method get_award_rows] in hand-out order).
var awards_shown: int = 0

var _age: float = 0.0
var _columns: Array[PlayerColumn] = []
var _buttons: Array[UiButton] = []
var _headline: Label = null
## The award rows in hand-out order (round robin over the players: everyone's first award, then the seconds ...).
var _award_rows: Array[Control] = []
var _award_timer: float = AWARD_DELAY
var _companion: UiActor = null
var _players: HBoxContainer = null


## One player of the match, in art-A's versus pieces (ASSET_MANIFEST.md 17.13): his portrait (`ui/portraits.png`:
## cheering for a winner, a bump for the others), the plate in his colour (`ui/versus_plate.png`) with his round wins as
## golden drumsticks out of the wins needed, his tag (and "CPU"), his team band in a 2 v 2 match and the crown for a
## winner. On the results (`painted`) his hero is also painted on the cave wall above (`ui/cave_paint_heroes.png`:
## the victory loop for the winners, standing for the others). Also the scoreboard's column (versus_scoreboard.gd),
## where the newest drumstick is thrown onto the plate.
class PlayerColumn:
	extends Control

	const TEX_FOOD: String = "res://assets/ui/stack_food.png"
	const TEX_CROWN: String = "res://assets/ui/crown.png"
	const TEX_PORTRAITS: String = "res://assets/ui/portraits.png"
	const TEX_PAINTED: String = "res://assets/ui/cave_paint_heroes.png"
	const TEX_PLATE: String = "res://assets/ui/versus_plate.png"
	## The colour rows of art-A's sheets (UiPlayers.PALETTE_COLOURS order).
	const COLOUR_ROWS: Array[StringName] = [&"yellow", &"blue", &"pink", &"green", &"white", &"gold"]
	const FOOD_CELL: Vector2i = Vector2i(32, 28)
	const DRUMSTICK: int = 5
	const CROWN_CELL: Vector2i = Vector2i(32, 24)
	const PORTRAIT: float = 80.0
	const PAINTED_CELL: Vector2 = Vector2(176.0, 112.0)
	const PLATE: Vector2 = Vector2(96.0, 16.0)
	## Where the painted hero's cell starts above the column (its hero stands at y 26..96 of the cell).
	const PAINTED_TOP: float = -18.0

	## Player slot, his colour and pattern, a bot or not, winner or not.
	var slot: int = 0
	var colour: StringName = &"yellow"
	var pattern: int = 0
	var bot: bool = false
	var winner: bool = false
	## Round wins and the wins that win the match; `fresh` wins at the end were won just now (they are thrown in).
	var wins: int = 0
	var needed: int = 3
	var fresh: int = 0
	## 2 v 2: the team (1 / 2; 0 = free-for-all).
	var team: int = 0
	## True on the results: the hero painted on the cave wall above the portrait.
	var painted: bool = false

	# Textures drawn by _draw, held for the whole screen (UiKit.tex keeps no cache).
	var _food: Texture2D = UiKit.tex(TEX_FOOD)
	var _crown: Texture2D = UiKit.tex(TEX_CROWN)
	var _portraits: Texture2D = UiKit.tex(TEX_PORTRAITS)
	var _painted_sheet: Texture2D = null
	var _plate: Texture2D = UiKit.tex(TEX_PLATE)
	var _hud: Font = UiKit.font(UiKit.Style.HUD)
	var _small: Font = UiKit.font(UiKit.Style.SMALL)
	var _drop: float = 1.0
	var _time: float = 0.0

	func _init(p_slot: int, look: Array, p_bot: bool, p_winner: bool, p_painted: bool = false) -> void:
		slot = p_slot
		colour = look[0]
		pattern = int(look[1])
		bot = p_bot
		winner = p_winner
		painted = p_painted
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		if painted:
			_painted_sheet = UiKit.tex(TEX_PAINTED)
		custom_minimum_size = Vector2(VersusResultsScreen.COLUMN_SIZE.x, plate_line() + 14.0)

	func _process(delta: float) -> void:
		_time += delta
		queue_redraw()

	## Throw the `fresh` newest drumsticks onto the plate over `seconds`.
	func drop_in(seconds: float) -> void:
		_drop = 0.0
		var tween: Tween = create_tween()
		tween.tween_interval(0.3)
		tween.tween_property(self, "_drop", 1.0, seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	## True once the thrown drumsticks lie on the plate.
	func is_settled() -> bool:
		return _drop >= 1.0

	## The row of this player's colour in art-A's sheets.
	func colour_row() -> int:
		return maxi(COLOUR_ROWS.find(colour), 0)

	## Top of the portrait in the column.
	func portrait_top() -> float:
		return (PAINTED_TOP + 100.0) if painted else 22.0

	## The plate's top line (the drumsticks stand on it).
	func plate_line() -> float:
		return portrait_top() + PORTRAIT - 6.0

	func _draw() -> void:
		var centre: float = roundf(size.x * 0.5)
		var row: int = colour_row()
		if painted and _painted_sheet != null:
			var frame: int = (int(_time * 4.0) % 2) if winner else 2
			draw_texture_rect_region(_painted_sheet, Rect2(Vector2(centre - PAINTED_CELL.x * 0.5, PAINTED_TOP), PAINTED_CELL),
					Rect2(Vector2(float(frame) * PAINTED_CELL.x, float(row) * PAINTED_CELL.y), PAINTED_CELL))
		var top: float = portrait_top()
		if _portraits != null:
			var mood: int = 2 if winner else (1 if painted and wins == 0 else 0)
			draw_texture_rect_region(_portraits, Rect2(Vector2(centre - PORTRAIT * 0.5, top), Vector2(PORTRAIT, PORTRAIT)),
					Rect2(Vector2(float(mood) * PORTRAIT, float(row) * PORTRAIT), Vector2(PORTRAIT, PORTRAIT)))
		if winner and _crown != null:
			var bob: float = roundf(sin(_time * 3.0) * 1.5)
			var crown_y: float = (PAINTED_TOP + 4.0 + bob) if painted else (top - 18.0 + bob)
			draw_texture_rect_region(_crown, Rect2(centre - 16.0, crown_y, 32.0, 24.0),
					Rect2(Vector2.ZERO, Vector2(CROWN_CELL)))
		# Tag (and "CPU") at the left of the portrait; the team band under it.
		var tag: String = UiPlayers.tag(slot)
		var tag_colour: Color = JoinScreen.text_colour(colour)
		var tag_at: Vector2 = Vector2(4.0, top + 16.0)
		draw_string_outline(_hud, tag_at, tag, HORIZONTAL_ALIGNMENT_LEFT, -1.0, UiKit.SIZE_HUD, 4, UiKit.COL_INK)
		draw_string(_hud, tag_at, tag, HORIZONTAL_ALIGNMENT_LEFT, -1.0, UiKit.SIZE_HUD, tag_colour)
		var line: float = tag_at.y + 13.0
		if bot:
			var cpu: String = tr("UI_VS_CPU")
			draw_string_outline(_small, Vector2(4.0, line), cpu, HORIZONTAL_ALIGNMENT_LEFT, -1.0, UiKit.SIZE_SMALL, 4,
					UiKit.COL_INK)
			draw_string(_small, Vector2(4.0, line), cpu, HORIZONTAL_ALIGNMENT_LEFT, -1.0, UiKit.SIZE_SMALL,
					UiKit.COL_CREAM)
			line += 12.0
		if team > 0:
			var band: Rect2 = Rect2(4.0, line - 7.0, 18.0, 10.0)
			draw_rect(band.grow(1.0), UiKit.COL_INK)
			draw_rect(band, JoinScreen.TEAM_COLOURS[clampi(team, 1, 2)])
		_draw_wins(centre, plate_line(), row)

	## The plate in his colour with one drumstick per win needed, the won ones golden, the newest thrown in from the left.
	func _draw_wins(centre: float, line: float, row: int) -> void:
		if _plate != null:
			draw_texture_rect_region(_plate, Rect2(Vector2(centre - PLATE.x * 0.5, line - 6.0), PLATE),
					Rect2(Vector2(0.0, float(row) * PLATE.y), PLATE))
		else:
			draw_rect(Rect2(centre - 48.0, line, 96.0, 5.0), UiKit.COL_CREAM.darkened(0.15))
		if _food == null or needed <= 0:
			return
		var shown: int = mini(maxi(needed, wins), 10)
		var step: float = minf(16.0, (PLATE.x - 24.0) / float(maxi(shown - 1, 1)))
		var width: float = step * float(shown - 1) + 32.0
		var left: float = roundf(centre - width * 0.5)
		for i: int in shown:
			var won: bool = i < wins
			var thrown: bool = won and i >= wins - fresh
			var at: Vector2 = Vector2(left + step * float(i), line - 24.0)
			if thrown and _drop < 1.0:
				var start: Vector2 = Vector2(-60.0, at.y - 40.0)
				at = start.lerp(at, _drop) + Vector2(0.0, -sin(_drop * PI) * 50.0)
			var modulate_colour: Color = Color.WHITE if won else Color(0.2, 0.16, 0.12, 0.45)
			draw_texture_rect_region(_food, Rect2(at.round(), Vector2(32.0, 28.0)),
					Rect2(Vector2(float(DRUMSTICK * FOOD_CELL.x), 0.0), Vector2(FOOD_CELL)), modulate_colour)


func _build_screen() -> void:
	var backdrop: UiBackdrop = UiBackdrop.new("cave", 0.0)
	backdrop.modulate = Color(0.5, 0.45, 0.42)
	add_child(backdrop)
	var wall_texture: Texture2D = UiKit.tex(TEX_WALL)
	if wall_texture != null:
		var wall: TextureRect = TextureRect.new()
		wall.texture = wall_texture
		wall.mouse_filter = Control.MOUSE_FILTER_IGNORE
		wall.set_anchors_preset(Control.PRESET_CENTER)
		wall.offset_left = -wall_texture.get_width() * 0.5
		wall.offset_right = wall_texture.get_width() * 0.5
		wall.offset_top = -wall_texture.get_height() * 0.5
		wall.offset_bottom = wall_texture.get_height() * 0.5
		add_child(wall)

	var column: VBoxContainer = VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override(&"separation", 2)
	safe.add_child(column)
	var winners: PackedInt32Array = get_winners()
	_headline = UiKit.label(headline_text(winners), UiKit.Style.HUD, HORIZONTAL_ALIGNMENT_CENTER)
	_headline.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	if not winners.is_empty():
		_headline.add_theme_color_override(&"font_color", JoinScreen.text_colour(look_of(winners[0])[0]))
	column.add_child(_headline)
	var gap: Control = Control.new()
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gap.custom_minimum_size = Vector2(0.0, 18.0)
	column.add_child(gap)

	var players: HBoxContainer = HBoxContainer.new()
	players.mouse_filter = Control.MOUSE_FILTER_IGNORE
	players.alignment = BoxContainer.ALIGNMENT_CENTER
	players.add_theme_constant_override(&"separation", 6)
	players.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(players)
	_players = players
	var versus_match: VersusMatch = Game.versus_match
	var awards: Dictionary = Flow.args.get("awards", {}) as Dictionary
	var lists: Array[Array] = []
	for slot: int in seated_slots():
		var box: VBoxContainer = VBoxContainer.new()
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_theme_constant_override(&"separation", 0)
		var bot: bool = versus_match != null and versus_match.is_bot(slot)
		var player: PlayerColumn = PlayerColumn.new(slot, look_of(slot), bot, winners.has(slot), true)
		if versus_match != null:
			player.wins = versus_match.round_wins[slot]
			player.needed = versus_match.round_wins_needed()
			player.team = versus_match.get_seat(slot).team if versus_match.is_team_match() else 0
		box.add_child(player)
		_columns.append(player)
		var rows: Array = []
		for award: Variant in awards.get(slot, []):
			var row: Control = _award_label(StringName(str(award)), slot)
			row.modulate.a = 0.0
			box.add_child(row)
			rows.append(row)
		lists.append(rows)
		players.add_child(box)
	# Hand-out order: everybody's first award, then everybody's second ...
	var depth: int = 0
	for rows: Array in lists:
		depth = maxi(depth, rows.size())
	for n: int in depth:
		for rows: Array in lists:
			if n < rows.size():
				_award_rows.append(rows[n])

	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override(&"separation", 12)
	column.add_child(UiKit.panel_box(row, 6))
	(column.get_child(column.get_child_count() - 1) as Control).size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_add_button(row, "UI_VS_REMATCH", rematch)
	_add_button(row, "UI_VS_LOBBY", to_lobby)
	_add_button(row, "UI_PAUSE_QUIT", to_title)
	for i: int in _buttons.size():
		_buttons[i].focus_neighbor_left = _buttons[i].get_path_to(_buttons[posmod(i - 1, _buttons.size())])
		_buttons[i].focus_neighbor_right = _buttons[i].get_path_to(_buttons[(i + 1) % _buttons.size()])
	_companion = UiActor.new(&"companion", &"idle")
	_companion.face(-1)


func _screen_ready() -> void:
	add_child(_companion)
	Audio.play_jingle(Sfx.MUSIC_MATCH_WIN, Sfx.MUSIC_VERSUS_RESULTS)
	Audio.play_sfx(Sfx.CROWD_APPLAUSE)
	GameInput.set_menu_clusters(true)
	UiKit.focus_silently(_buttons[0])
	_place_companion()
	resized.connect(_place_companion)


func _process(delta: float) -> void:
	_age += delta
	if awards_shown >= _award_rows.size():
		return
	_award_timer -= delta
	if _award_timer <= 0.0:
		_award_timer = AWARD_SECONDS
		hand_out(awards_shown, true)


## Show award row `index` (hand-out order): a medal flies from the companion to it (`animate`) and it fades in.
func hand_out(index: int, animate: bool) -> void:
	if index < awards_shown or index >= _award_rows.size():
		return
	awards_shown = index + 1
	var row: Control = _award_rows[index]
	if not animate:
		row.modulate.a = 1.0
		return
	row.create_tween().tween_property(row, "modulate:a", 1.0, 0.25).set_delay(0.25)
	var medal: TallyScreen.MedalIcon = TallyScreen.MedalIcon.new(StringName(str(row.get_meta(&"award", ""))),
			JoinScreen.text_colour(look_of(int(row.get_meta(&"slot", 0)))[0]), 16.0, true)
	add_child(medal)
	medal.position = _companion.position + Vector2(-10.0, -60.0)
	var target: Vector2 = row.global_position - global_position + Vector2(2.0, 2.0)
	var flight: Tween = medal.create_tween()
	flight.tween_property(medal, "position", target, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	flight.tween_callback(medal.queue_free)
	_companion.play(&"catch", false)
	Audio.play_sfx(Sfx.TALLY_TICK)


## Every award at once (a tap, tests); the ones still fading in show fully.
func show_all_awards() -> void:
	for index: int in range(awards_shown, _award_rows.size()):
		hand_out(index, false)
	for row: Control in _award_rows:
		row.modulate.a = 1.0


## The match winners of the args (both of a team; empty when nobody won a round).
static func get_winners() -> PackedInt32Array:
	var value: Variant = Flow.args.get("winners", PackedInt32Array())
	var result: PackedInt32Array = PackedInt32Array()
	if value is PackedInt32Array or value is Array:
		for slot: Variant in value:
			result.append(int(slot))
	return result


## The headline: "P2 wins the match!", "P1 + P3 win the match!" or "Draw!".
static func headline_text(winners: PackedInt32Array) -> String:
	if winners.is_empty():
		return TranslationServer.translate("UI_VS_DRAW")
	if winners.size() == 1:
		return TranslationServer.translate("UI_VS_MATCH_WIN").format({"player": UiPlayers.tag(winners[0])})
	var tags: PackedStringArray = PackedStringArray()
	for slot: int in winners:
		tags.append(UiPlayers.tag(slot))
	return TranslationServer.translate("UI_VS_MATCH_SHARED").format({"players": " + ".join(tags)})


## The slots that played the match (the match's seats, else the run's party).
static func seated_slots() -> PackedInt32Array:
	if Game.versus_match != null and Game.versus_match.player_count() > 0:
		return Game.versus_match.seated_slots()
	var result: PackedInt32Array = PackedInt32Array()
	for slot: int in maxi(Game.party, 1):
		result.append(slot)
	return result


## [colour, pattern] of the hero of `slot` in this match (his seat's look, as the run wore it).
static func look_of(slot: int) -> Array:
	var run: PlayerRun = Game.get_run(slot)
	var seat: VersusMatch.Seat = Game.versus_match.get_seat(slot) if Game.versus_match != null else null
	if seat != null and seat.palette != &"" and (run == null or run.palette == &""):
		return [seat.palette, seat.pattern if seat.pattern >= 0 else HeroPalette.slot_default_pattern(slot)]
	return HeroPalette.resolve(slot, run)


## The player columns (tests).
func get_columns() -> Array[PlayerColumn]:
	return _columns


## The award rows in hand-out order (tests): each has the metas "award" and "slot".
func get_award_rows() -> Array[Control]:
	return _award_rows


## The buttons, Rematch first (tests).
func get_buttons() -> Array[UiButton]:
	return _buttons


## The headline text.
func get_headline() -> String:
	return _headline.text


## Rematch: the same players, rules and arena choice again (Flow.rematch).
func rematch() -> void:
	if _age < ACCEPT_GRACE or not begin_leave():
		return
	Flow.rematch()


## Back to the lobby, seats and rules kept (Flow.leave_versus).
func to_lobby() -> void:
	if _age < ACCEPT_GRACE or not begin_leave():
		return
	Flow.leave_versus()


## Quit to the title (Flow.leave_versus(true)).
func to_title() -> void:
	if _age < ACCEPT_GRACE or not begin_leave():
		return
	Flow.leave_versus(true)


func _on_cancel() -> void:
	if is_accepting_input():
		Audio.play_sfx(Sfx.MENU_BACK)
		to_lobby()


func _on_tap() -> void:
	show_all_awards()


func _add_button(row: HBoxContainer, key: String, callback: Callable) -> void:
	var button: UiButton = UiButton.new(key)
	button.pressed.connect(callback)
	row.add_child(button)
	_buttons.append(button)


## The companion stands right of the players, on the line of their plates.
func _place_companion() -> void:
	if _companion == null or _players == null or _columns.is_empty():
		return
	var last: Rect2 = _columns[-1].get_global_rect()
	var x: float = minf(last.end.x + 40.0, size.x - 34.0)
	var y: float = last.position.y + _columns[-1].plate_line() + 10.0
	_companion.position = Vector2(roundf(x - global_position.x), roundf(y - global_position.y))


## One award: its medal, its name in gold and what it was for.
func _award_label(award: StringName, slot: int) -> Control:
	var keys: Array = AWARD_KEYS.get(award, [String(award), ""])
	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override(&"separation", 3)
	row.set_meta(&"award", award)
	row.set_meta(&"slot", slot)
	var icon: TallyScreen.MedalIcon = TallyScreen.MedalIcon.new(award, JoinScreen.text_colour(look_of(slot)[0]), 16.0,
			true)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)
	var box: VBoxContainer = VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override(&"separation", -3)
	var title: Label = UiKit.label(str(keys[0]), UiKit.Style.SMALL)
	title.add_theme_color_override(&"font_color", UiKit.COL_FOCUS)
	title.add_theme_font_override(&"font", plain_small_font())
	box.add_child(title)
	if str(keys[1]) != "":
		var info: Label = UiKit.label(str(keys[1]), UiKit.Style.SMALL)
		info.add_theme_color_override(&"font_color", UiKit.COL_CREAM)
		info.add_theme_font_override(&"font", plain_small_font())
		box.add_child(info)
	row.add_child(box)
	return row


## The small face without ligatures: at 11 px the body face's "fi" ligature reads as an "A" ("ButterAngers").
static func plain_small_font() -> Font:
	if _plain_small == null:
		var variation: FontVariation = FontVariation.new()
		variation.base_font = UiKit.font(UiKit.Style.SMALL)
		variation.opentype_features = {TextServerManager.get_primary_interface().name_to_tag("liga"): 0}
		_plain_small = variation
	return _plain_small
