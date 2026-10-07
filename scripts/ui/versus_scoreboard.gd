class_name VersusScoreboardScreen
extends UiScreen
## The scoreboard between two versus rounds (DESIGN.md E.8 step 6; PLAN.md P1.11 / P2.8): about five seconds
## (VersusTuning.SCOREBOARD_TICKS) of "ROUND n", who took it and what was played ("Grub Stack on Totem Ring"), every
## player's round wins as golden drumsticks on his plate - the round's winner gets his new drumstick **thrown** onto it
## - with his team pennant in a 2 v 2 match, the wins that win the match, and what comes next ("Next: Hot Rock on
## Echo Hollow" with Party Mix or a random arena). Then the next round starts by itself (Flow.next_round); a confirm
## skips the wait. Args: {"round_index": int, "winners": PackedInt32Array}.

## Seconds the scoreboard shows before the next round (about 5 s).
const SHOW_SECONDS: float = float(VersusTuning.SCOREBOARD_TICKS) * Tuning.TICK_DT
## Seconds before a confirm counts (the round's last button presses must not skip it).
const ACCEPT_GRACE: float = 0.6

## Seconds left before the next round starts by itself.
var countdown: float = SHOW_SECONDS

var _age: float = 0.0
var _columns: Array[VersusResultsScreen.PlayerColumn] = []
var _headline: Label = null
var _played: Label = null
var _next: Label = null


func _build_screen() -> void:
	add_child(UiBackdrop.new("cave", 12.0))
	var shade: ColorRect = ColorRect.new()
	shade.color = Color(UiKit.COL_INK, 0.35)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	var column: VBoxContainer = VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override(&"separation", 3)
	safe.add_child(column)
	var heading: Label = UiKit.label(
		TranslationServer.translate("UI_VS_ROUND").format({"number": int(Flow.args.get("round_index", 0)) + 1}),
		UiKit.Style.TITLE, HORIZONTAL_ALIGNMENT_CENTER
	)
	heading.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	column.add_child(heading)
	var winners: PackedInt32Array = VersusResultsScreen.get_winners()
	_headline = UiKit.label(round_text(winners), UiKit.Style.HUD, HORIZONTAL_ALIGNMENT_CENTER)
	_headline.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	if not winners.is_empty():
		_headline.add_theme_color_override(&"font_color",
				JoinScreen.text_colour(VersusResultsScreen.look_of(winners[0])[0]))
	column.add_child(_headline)
	var versus_match: VersusMatch = Game.versus_match
	_played = UiKit.label(played_text(versus_match), UiKit.Style.SMALL, HORIZONTAL_ALIGNMENT_CENTER)
	_played.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_played.add_theme_color_override(&"font_color", UiKit.COL_CREAM)
	column.add_child(_played)

	var middle: CenterContainer = CenterContainer.new()
	middle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(middle)
	var players: HBoxContainer = HBoxContainer.new()
	players.mouse_filter = Control.MOUSE_FILTER_IGNORE
	players.add_theme_constant_override(&"separation", 8)
	middle.add_child(players)
	for slot: int in VersusResultsScreen.seated_slots():
		var bot: bool = versus_match != null and versus_match.is_bot(slot)
		var player: VersusResultsScreen.PlayerColumn = VersusResultsScreen.PlayerColumn.new(slot,
				VersusResultsScreen.look_of(slot), bot, winners.has(slot))
		if versus_match != null:
			player.wins = versus_match.round_wins[slot]
			player.needed = versus_match.round_wins_needed()
			player.team = versus_match.get_seat(slot).team if versus_match.is_team_match() else 0
		player.fresh = 1 if winners.has(slot) else 0
		players.add_child(player)
		_columns.append(player)
	if versus_match != null:
		var goal: Label = UiKit.label(
			TranslationServer.translate("UI_VS_FIRST_TO").format({"wins": versus_match.round_wins_needed()}),
			UiKit.Style.HUD, HORIZONTAL_ALIGNMENT_CENTER
		)
		goal.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		goal.add_theme_color_override(&"font_color", UiKit.COL_CREAM)
		column.add_child(goal)
	_next = UiKit.label(next_text(versus_match), UiKit.Style.SMALL, HORIZONTAL_ALIGNMENT_CENTER)
	_next.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_next.add_theme_color_override(&"font_color", UiKit.COL_FOCUS)
	column.add_child(_next)

	var prompts: UiPrompts = UiPrompts.new()
	prompts.add_hint(&"ui_accept", "UI_HINT_NEXT", _on_accept)
	column.add_child(prompts)


func _screen_ready() -> void:
	Audio.play_jingle(Sfx.MUSIC_ROUND_WIN)
	GameInput.set_menu_clusters(true)
	for player: VersusResultsScreen.PlayerColumn in _columns:
		if player.fresh > 0:
			player.drop_in(0.6)


func _process(delta: float) -> void:
	_age += delta
	if not is_accepting_input():
		return
	countdown -= delta
	if countdown <= 0.0:
		next_round()


## "P2 wins the round!", "P1 + P3 win the round!" or "Draw!" (the HUD's round texts).
static func round_text(winners: PackedInt32Array) -> String:
	if winners.is_empty():
		return TranslationServer.translate("UI_VS_DRAW")
	if winners.size() == 1:
		return TranslationServer.translate("UI_VS_ROUND_WIN").format({"player": UiPlayers.tag(winners[0])})
	var tags: PackedStringArray = PackedStringArray()
	for slot: int in winners:
		tags.append(UiPlayers.tag(slot))
	return TranslationServer.translate("UI_VS_ROUND_SHARED").format({"players": " + ".join(tags)})


## "Grub Stack on Totem Ring": the mode and the arena of the round just played ("" without a history).
static func played_text(versus_match: VersusMatch) -> String:
	if versus_match == null or versus_match.history.is_empty():
		return ""
	var last: Dictionary = versus_match.history[-1]
	return mode_on_arena(int(last.get("mode", versus_match.mode)), StringName(str(last.get("arena", ""))))


## "Next: Hot Rock on Echo Hollow" for the next round, "" when the match is over or no arena fits.
static func next_text(versus_match: VersusMatch) -> String:
	if versus_match == null or versus_match.is_over():
		return ""
	var arena_id: StringName = versus_match.arena_for_round(versus_match.round_index)
	if arena_id == &"" or not Levels.has_level(arena_id):
		return ""
	var mode: int = versus_match.mode_for_round(versus_match.round_index, arena_id)
	return TranslationServer.translate("UI_VS_NEXT_ROUND").format({"arena": mode_on_arena(mode, arena_id)})


## "{mode} on {arena}".
static func mode_on_arena(mode: int, arena_id: StringName) -> String:
	var mode_key: String = str(VersusLobbyScreen.MODE_KEYS.get(mode, [""])[0])
	return TranslationServer.translate("UI_VS_MODE_ON_ARENA").format({
		"mode": TranslationServer.translate(mode_key), "arena": UiKit.level_name(arena_id)})


## The player columns (tests).
func get_columns() -> Array[VersusResultsScreen.PlayerColumn]:
	return _columns


## The line of what was played, and of what comes next (tests).
func get_played_text() -> String:
	return _played.text


func get_next_text() -> String:
	return _next.text


## On to the next round (Flow.next_round).
func next_round() -> void:
	if begin_leave():
		Flow.next_round()


func _on_accept() -> void:
	if _age >= ACCEPT_GRACE:
		next_round()


func _on_tap() -> void:
	_on_accept()
