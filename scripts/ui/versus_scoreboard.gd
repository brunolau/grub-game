class_name VersusScoreboardScreen
extends UiScreen
## The scoreboard between two versus rounds (DESIGN.md E.8 step 6; a minimal version for the G1 slice, PLAN.md P2.8
## dresses it): about four seconds of "ROUND n", who took it, and every player's round wins as golden drumsticks on
## his plate - the round's winner gets his new drumstick thrown on. Then the next round starts by itself
## (Flow.next_round); a confirm skips the wait. Args: {"round_index": int, "winners": PackedInt32Array}.

## Seconds the scoreboard shows before the next round.
const SHOW_SECONDS: float = 4.0
## Seconds before a confirm counts (the round's last button presses must not skip it).
const ACCEPT_GRACE: float = 0.6

## Seconds left before the next round starts by itself.
var countdown: float = SHOW_SECONDS

var _age: float = 0.0
var _columns: Array[VersusResultsScreen.PlayerColumn] = []
var _headline: Label = null


func _build_screen() -> void:
	add_child(UiBackdrop.new("cave", 12.0))
	var shade: ColorRect = ColorRect.new()
	shade.color = Color(UiKit.COL_INK, 0.35)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	var column: VBoxContainer = VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override(&"separation", 4)
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

	var middle: CenterContainer = CenterContainer.new()
	middle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(middle)
	var players: HBoxContainer = HBoxContainer.new()
	players.mouse_filter = Control.MOUSE_FILTER_IGNORE
	players.add_theme_constant_override(&"separation", 8)
	middle.add_child(players)
	var versus_match: VersusMatch = Game.versus_match
	for slot: int in VersusResultsScreen.seated_slots():
		var bot: bool = versus_match != null and versus_match.is_bot(slot)
		var player: VersusResultsScreen.PlayerColumn = VersusResultsScreen.PlayerColumn.new(slot,
				VersusResultsScreen.look_of(slot), bot, winners.has(slot))
		if versus_match != null:
			player.wins = versus_match.round_wins[slot]
			player.needed = versus_match.round_wins_needed()
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

	var prompts: UiPrompts = UiPrompts.new()
	prompts.add_hint(&"ui_accept", "UI_HINT_NEXT", _on_accept)
	column.add_child(prompts)


func _screen_ready() -> void:
	Audio.play_jingle(Sfx.MUSIC_ROUND_WIN)
	GameInput.set_menu_clusters(true)
	for player: VersusResultsScreen.PlayerColumn in _columns:
		if player.fresh > 0:
			player.drop_in(0.5)


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


## The player columns (tests).
func get_columns() -> Array[VersusResultsScreen.PlayerColumn]:
	return _columns


## On to the next round (Flow.next_round).
func next_round() -> void:
	if begin_leave():
		Flow.next_round()


func _on_accept() -> void:
	if _age >= ACCEPT_GRACE:
		next_round()


func _on_tap() -> void:
	_on_accept()
