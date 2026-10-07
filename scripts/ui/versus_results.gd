class_name VersusResultsScreen
extends UiScreen
## The results of a versus match (DESIGN.md E.8 step 7; PLAN.md P1.11 for the G1 slice, the full cave-wall mural and
## award animations are P2.8).
##
## Args (Flow._show_versus_results): {"winners": PackedInt32Array, "awards": {slot: Array[StringName] of
## PlayerRun.VERSUS_AWARDS ids, 1-3 each}}. The heroes stand on a cave ledge in their colours - the match winner (both
## of a team) in his victory pose on a higher stone with the crown - each with his round wins as golden drumsticks and
## the awards the tally companion hands out. **Rematch** is the default button (Flow.rematch); Lobby
## (Flow.leave_versus) and Quit to title (Flow.leave_versus(true)); "back" = the lobby. Every player drives the buttons
## from his own key cluster. Music: the match-win jingle, then the results loop.

## Seconds before a confirm counts (a Strike still held from the last round must not start the rematch).
const ACCEPT_GRACE: float = 0.8
const COLUMN_SIZE: Vector2 = Vector2(144.0, 140.0)
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

var _age: float = 0.0
var _columns: Array[PlayerColumn] = []
var _buttons: Array[UiButton] = []
var _headline: Label = null


## One player of the match: his hero on a ledge (raised and crowned for a winner), his tag, his round wins as golden
## drumsticks out of the wins needed. Also the scoreboard's column (versus_scoreboard.gd).
class PlayerColumn:
	extends Control

	const TEX_FOOD: String = "res://assets/ui/stack_food.png"
	const TEX_CROWN: String = "res://assets/ui/crown.png"
	const FOOD_CELL: Vector2i = Vector2i(32, 28)
	const DRUMSTICK: int = 5
	const CROWN_CELL: Vector2i = Vector2i(32, 24)
	const LEDGE_RAISE: float = 10.0
	const FEET_Y: float = 100.0

	## Player slot, his colour and pattern, a bot or not, winner or not.
	var slot: int = 0
	var colour: StringName = &"yellow"
	var pattern: int = 0
	var bot: bool = false
	var winner: bool = false
	## Round wins and the wins that win the match; `fresh` wins at the end were won just now (they drop in).
	var wins: int = 0
	var needed: int = 3
	var fresh: int = 0

	var _actor: UiActor = null
	# Textures drawn by _draw, held for the whole screen (UiKit.tex keeps no cache).
	var _food: Texture2D = UiKit.tex(TEX_FOOD)
	var _crown: Texture2D = UiKit.tex(TEX_CROWN)
	var _hud: Font = UiKit.font(UiKit.Style.HUD)
	var _small: Font = UiKit.font(UiKit.Style.SMALL)
	var _drop: float = 1.0
	var _time: float = 0.0

	func _init(p_slot: int, look: Array, p_bot: bool, p_winner: bool) -> void:
		slot = p_slot
		colour = look[0]
		pattern = int(look[1])
		bot = p_bot
		winner = p_winner
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = VersusResultsScreen.COLUMN_SIZE
		_actor = UiActor.new(&"hero", &"victory" if winner else &"idle")
		_actor.material = HeroPalette.material_for(colour, pattern)
		add_child(_actor)
		resized.connect(_place)

	func _ready() -> void:
		_place()

	func _process(delta: float) -> void:
		_time += delta
		queue_redraw()

	## Let the `fresh` newest drumsticks fall onto the plate over `seconds`.
	func drop_in(seconds: float) -> void:
		_drop = 0.0
		var tween: Tween = create_tween()
		tween.tween_interval(0.3)
		tween.tween_property(self, "_drop", 1.0, seconds).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

	func _place() -> void:
		_actor.position = Vector2(roundf(size.x * 0.5), FEET_Y - (LEDGE_RAISE if winner else 0.0))

	func _draw() -> void:
		var centre: float = roundf(size.x * 0.5)
		var feet: float = FEET_Y - (LEDGE_RAISE if winner else 0.0)
		# The ledge he stands on.
		var ledge: Rect2 = Rect2(centre - 34.0, feet, 68.0, FEET_Y + 6.0 - feet)
		draw_rect(ledge.grow(2.0), UiKit.COL_INK)
		draw_rect(ledge, Color("6f6a7d") if not winner else Color("9a8f73"))
		draw_rect(Rect2(ledge.position, Vector2(ledge.size.x, 2.0)), Color(1.0, 1.0, 1.0, 0.25))
		if winner and _crown != null:
			var bob: float = roundf(sin(_time * 3.0) * 1.5)
			draw_texture_rect_region(_crown, Rect2(centre - 16.0, feet - 92.0 + bob, 32.0, 24.0),
					Rect2(Vector2.ZERO, Vector2(CROWN_CELL)))
		# Tag (and "CPU") at the left of the hero's head.
		var tag: String = UiPlayers.tag(slot)
		var tag_colour: Color = JoinScreen.text_colour(colour)
		draw_string_outline(_hud, Vector2(4.0, 18.0), tag, HORIZONTAL_ALIGNMENT_LEFT, -1.0, UiKit.SIZE_HUD, 4,
				UiKit.COL_INK)
		draw_string(_hud, Vector2(4.0, 18.0), tag, HORIZONTAL_ALIGNMENT_LEFT, -1.0, UiKit.SIZE_HUD, tag_colour)
		if bot:
			var cpu: String = tr("UI_VS_CPU")
			draw_string_outline(_small, Vector2(4.0, 31.0), cpu, HORIZONTAL_ALIGNMENT_LEFT, -1.0, UiKit.SIZE_SMALL, 4,
					UiKit.COL_INK)
			draw_string(_small, Vector2(4.0, 31.0), cpu, HORIZONTAL_ALIGNMENT_LEFT, -1.0, UiKit.SIZE_SMALL,
					UiKit.COL_CREAM)
		_draw_wins(centre, FEET_Y + 10.0)

	## The plate of drumsticks: one per win needed, the won ones golden, the newest falling in.
	func _draw_wins(centre: float, top: float) -> void:
		if _food == null or needed <= 0:
			return
		var shown: int = mini(maxi(needed, wins), 8)
		var step: float = minf(16.0, (size.x - 32.0) / float(maxi(shown - 1, 1)))
		var width: float = step * float(shown - 1) + 32.0
		var left: float = roundf(centre - width * 0.5)
		var plate: Rect2 = Rect2(left - 4.0, top + 20.0, width + 8.0, 5.0)
		draw_rect(plate.grow(1.0), UiKit.COL_INK)
		draw_rect(plate, UiKit.COL_CREAM.darkened(0.15))
		for i: int in shown:
			var won: bool = i < wins
			var falling: bool = won and i >= wins - fresh
			var y: float = top
			if falling:
				y = lerpf(top - 70.0, top, _drop)
			var modulate_colour: Color = Color.WHITE if won else Color(0.2, 0.16, 0.12, 0.45)
			draw_texture_rect_region(_food, Rect2(left + step * float(i), y, 32.0, 28.0),
					Rect2(Vector2(float(DRUMSTICK * FOOD_CELL.x), 0.0), Vector2(FOOD_CELL)), modulate_colour)


func _build_screen() -> void:
	add_child(UiBackdrop.new("cave", 12.0))
	var shade: ColorRect = ColorRect.new()
	shade.color = Color(UiKit.COL_INK, 0.35)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	var column: VBoxContainer = VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override(&"separation", 2)
	safe.add_child(column)
	column.add_child(UiKit.label("UI_VS_RESULTS_HEADING", UiKit.Style.TITLE, HORIZONTAL_ALIGNMENT_CENTER))
	var winners: PackedInt32Array = get_winners()
	_headline = UiKit.label(headline_text(winners), UiKit.Style.HUD, HORIZONTAL_ALIGNMENT_CENTER)
	_headline.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	if not winners.is_empty():
		_headline.add_theme_color_override(&"font_color", JoinScreen.text_colour(look_of(winners[0])[0]))
	column.add_child(_headline)

	var players: HBoxContainer = HBoxContainer.new()
	players.mouse_filter = Control.MOUSE_FILTER_IGNORE
	players.alignment = BoxContainer.ALIGNMENT_CENTER
	players.add_theme_constant_override(&"separation", 6)
	players.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(players)
	var versus_match: VersusMatch = Game.versus_match
	var awards: Dictionary = Flow.args.get("awards", {}) as Dictionary
	for slot: int in seated_slots():
		var box: VBoxContainer = VBoxContainer.new()
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_theme_constant_override(&"separation", 0)
		var bot: bool = versus_match != null and versus_match.is_bot(slot)
		var player: PlayerColumn = PlayerColumn.new(slot, look_of(slot), bot, winners.has(slot))
		if versus_match != null:
			player.wins = versus_match.round_wins[slot]
			player.needed = versus_match.round_wins_needed()
		box.add_child(player)
		_columns.append(player)
		for award: Variant in awards.get(slot, []):
			box.add_child(_award_label(StringName(str(award))))
		players.add_child(box)

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


func _screen_ready() -> void:
	Audio.play_jingle(Sfx.MUSIC_MATCH_WIN, Sfx.MUSIC_VERSUS_RESULTS)
	GameInput.set_menu_clusters(true)
	UiKit.focus_silently(_buttons[0])


func _process(delta: float) -> void:
	_age += delta


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
	pass


func _add_button(row: HBoxContainer, key: String, callback: Callable) -> void:
	var button: UiButton = UiButton.new(key)
	button.pressed.connect(callback)
	row.add_child(button)
	_buttons.append(button)


## One award: its name in gold and what it was for.
func _award_label(award: StringName) -> Control:
	var keys: Array = AWARD_KEYS.get(award, [String(award), ""])
	var box: VBoxContainer = VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override(&"separation", -2)
	var title: Label = UiKit.label(str(keys[0]), UiKit.Style.SMALL, HORIZONTAL_ALIGNMENT_CENTER)
	title.add_theme_color_override(&"font_color", UiKit.COL_FOCUS)
	title.add_theme_font_override(&"font", plain_small_font())
	box.add_child(title)
	if str(keys[1]) != "":
		var info: Label = UiKit.label(str(keys[1]), UiKit.Style.SMALL, HORIZONTAL_ALIGNMENT_CENTER)
		info.add_theme_color_override(&"font_color", UiKit.COL_DIM)
		info.add_theme_font_override(&"font", plain_small_font())
		box.add_child(info)
	return box


## The small face without ligatures: at 11 px the body face's "fi" ligature reads as an "A" ("ButterAngers").
static func plain_small_font() -> Font:
	if _plain_small == null:
		var variation: FontVariation = FontVariation.new()
		variation.base_font = UiKit.font(UiKit.Style.SMALL)
		variation.opentype_features = {TextServerManager.get_primary_interface().name_to_tag("liga"): 0}
		_plain_small = variation
	return _plain_small
