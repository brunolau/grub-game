extends TestCase
## ui module, versus screens (ui-A, DESIGN.md E.8 / E.9, PLAN.md P1.11 for the G1 slice): the lobby (press Jump to
## join, CPU seats and their levels, colours, hold Strike = ready, mode and arena, START through Flow.start_versus),
## the scoreboard between rounds and the results with their awards and Rematch / Lobby / Title.

## A developer arena every build of the tests has (world-B's flat test arena: 4 players, Grub Stack and more).
const ARENA: StringName = &"test_world_arena_flat"

var _manual: bool = false


func before_each() -> void:
	_manual = Sim.manual
	Sim.manual = true
	Settings.reset()
	GameInput.reset_slots()
	GameInput.set_menu_clusters(false)
	Game.versus_match = null
	Flow.play_mode = Defs.GameMode.VERSUS
	# Idle bots: these tests check the screens, not HeroBot.
	VersusMatch.bot_factory = func(_slot: int, _level: int, _seed: int) -> Callable: return _idle


func after_each() -> void:
	Sim.stop()
	Sim.manual = _manual
	get_tree().paused = false
	VersusMatch.bot_factory = Callable()
	Flow.args = {}
	Flow.play_mode = Defs.GameMode.SINGLE
	GameInput.set_menu_clusters(false)
	GameInput.reset_slots()
	Game.versus_match = null
	Game.new_game(Defs.Difficulty.BEGINNER)
	for run: PlayerRun in Game.runs:
		run.palette = &""
		run.pattern = -1
	Settings.reset()


## Press Jump to take a seat (keyboard halves of the classic layout, pads); confirm on a free seat card adds a CPU
## (Hunter), confirm on a CPU steps it Hunter -> Chief -> Rookie -> free, "back" on a CPU removes it; every seat gets
## a colour nobody else wears and Left / Right skips the others' colours.
func test_lobby_seats_players_and_cpus() -> void:
	var node: VersusLobbyScreen = await _open_lobby()
	var versus_match: VersusMatch = Game.versus_match
	assert_true(GameInput.has_menu_clusters(), "both players drive the lobby from their own keys")
	assert_eq(node.get_status_text(), tr("UI_VS_NEED_TWO"))
	assert_true(node.get_start_button().disabled)
	_key(KEY_SPACE)
	_key(KEY_KP_0)
	_pad_button(2, JOY_BUTTON_A)
	assert_eq(versus_match.human_count(), 3, "three humans: the two keyboard halves and a pad")
	assert_eq(versus_match.get_seat(1).input.kind, Defs.InputSlotKind.KEYBOARD_RIGHT)
	assert_eq(node.get_card(2).device_text, tr("UI_JOIN_PAD").format({"number": 3}))
	assert_eq(node.get_card(3).state, JoinScreen.SeatCard.State.FREE)
	node._on_card_pressed(3)
	assert_true(versus_match.is_bot(3), "confirm on a free seat: Add CPU")
	assert_eq(versus_match.get_seat(3).bot_level, Defs.BotLevel.HUNTER, "a Hunter")
	assert_eq(node.get_card(3).state, JoinScreen.SeatCard.State.BOT)
	var colours: Array[StringName] = []
	for slot: int in 4:
		colours.append(versus_match.get_seat(slot).palette)
	assert_eq(colours, [&"yellow", &"blue", &"pink", &"green"] as Array[StringName], "the slot colours")
	_key(KEY_D)
	assert_eq(versus_match.get_seat(0).palette, &"yellow", "every colour is worn: P1 keeps his")
	node.remove_cpu(3)
	_key(KEY_D)
	assert_eq(versus_match.get_seat(0).palette, &"green", "Right skips blue and pink, worn by P2 and P3")
	node._on_card_pressed(3)
	node._on_card_pressed(3)
	assert_eq(versus_match.get_seat(3).bot_level, Defs.BotLevel.CHIEF, "confirm again: Chief")
	node._on_card_pressed(3)
	assert_eq(versus_match.get_seat(3).bot_level, Defs.BotLevel.ROOKIE, "then Rookie")
	node._on_card_pressed(3)
	assert_false(versus_match.is_seated(3), "then the seat is free again")
	node._on_card_pressed(3)
	assert_true(versus_match.is_bot(3))
	node.get_card(3).grab_focus()
	_press(&"ui_cancel")
	assert_false(versus_match.is_seated(3), "back on a CPU seat removes the CPU")
	assert_false(node.leaving, "... and stays in the lobby")
	_key(KEY_Q)
	assert_false(versus_match.is_seated(0), "Look: P1 leaves his seat")
	assert_eq(versus_match.get_seat(1).input.kind, Defs.InputSlotKind.KEYBOARD_RIGHT, "the others keep theirs")
	await _cleanup()


## One tablet player against CPUs (DESIGN.md E.9): a tap on a free seat joins a touch player, ready at once.
func test_lobby_touch_player_takes_a_seat() -> void:
	var node: VersusLobbyScreen = await _open_lobby()
	var finger: InputEventScreenTouch = InputEventScreenTouch.new()
	finger.position = node.get_card(2).get_global_rect().get_center()
	finger.pressed = true
	get_tree().root.push_input(finger)
	var versus_match: VersusMatch = Game.versus_match
	assert_eq(versus_match.human_count(), 1)
	var slot: int = versus_match.seated_slots()[0]
	assert_eq(versus_match.get_seat(slot).input.kind, Defs.InputSlotKind.TOUCH)
	assert_true(versus_match.get_seat(slot).ready, "ready at once")
	await _cleanup()


## Hold Strike 1 s = ready; a ready player's keys drive the menu from his own cluster (his Look takes the ready back);
## START needs two players and everybody ready, and opens the rules for the player who pressed it.
func test_lobby_ready_and_start() -> void:
	var node: VersusLobbyScreen = await _open_lobby()
	var versus_match: VersusMatch = Game.versus_match
	_key(KEY_SPACE)
	node.add_cpu(1, Defs.BotLevel.ROOKIE)
	assert_eq(node.get_status_text(), tr("UI_VS_NOT_READY"))
	assert_false(node.can_start())
	assert_true(node.get_start_button().has_focus(), "START has the focus")
	_key(KEY_A)
	assert_ne(versus_match.get_seat(0).palette, &"yellow", "before he is ready, P1's keys work his seat")
	_key(_p1_strike(), true)
	node._process(VersusLobbyScreen.READY_SECONDS + 0.05)
	_key(_p1_strike(), false)
	assert_true(versus_match.get_seat(0).ready, "held Strike for a second: ready")
	assert_eq(node.get_status_text(), "", "nothing is missing")
	assert_false(node.get_start_button().disabled)
	assert_true(node.can_start())
	var focus: Control = get_viewport().gui_get_focus_owner()
	_key(KEY_S)
	assert_ne(get_viewport().gui_get_focus_owner(), focus, "ready: P1's S moves the menu focus")
	_key(KEY_Q)
	assert_false(versus_match.get_seat(0).ready, "his Look takes the ready back")
	node.set_ready(0, true)
	node.get_start_button().grab_focus()
	_key(KEY_SPACE)
	if Flow.busy:
		await Flow.transition_finished
	assert_true(node.leaving, "P1's Space pressed START")
	assert_eq(Flow.current_screen, Flow.SCREEN_VERSUS_RULES, "START opens the rules")
	assert_eq(int(Flow.args.get("owner", -1)), 0, "... controlled by P1, who pressed it")
	assert_eq(versus_match.rules_owner, 0)
	await _cleanup()


## The arena choices follow the mode: Random first, the arenas of the mode for this many players, Party Mix last.
func test_arena_choices_follow_the_mode() -> void:
	for mode: int in VersusMatch.LAUNCH_MODES:
		var choices: Array[Array] = VersusArenaScreen.choices(2, mode)
		assert_eq(choices[0][0], VersusMatch.ARENA_RANDOM, "Random first")
		assert_eq(choices[-1][0], VersusMatch.ARENA_PARTY_MIX, "Party Mix last")
		for entry: Array in choices.slice(1, choices.size() - 1):
			var id: StringName = entry[0]
			assert_true(LevelText.to_list(Levels.get_value(id, "modes", "")).has(String(Defs.versus_mode_name(mode))),
					"%s plays %s" % [id, mode])
	assert_eq(VersusLobbyScreen.arena_text(VersusMatch.ARENA_RANDOM), "UI_VS_ARENA_RANDOM")
	assert_eq(VersusLobbyScreen.arena_text(ARENA), UiKit.level_name(ARENA))


## Between rounds: the scoreboard shows every player's round wins and moves on to the next round by itself.
func test_scoreboard_moves_on_to_the_next_round() -> void:
	var versus_match: VersusMatch = _match()
	versus_match.begin_round(ARENA)
	versus_match.record_round(PackedInt32Array([1]))
	Flow.args = {"round_index": 0, "winners": PackedInt32Array([1])}
	var node: VersusScoreboardScreen = await _open(&"versus_scoreboard") as VersusScoreboardScreen
	assert_eq(node.get_columns().size(), 2)
	assert_eq(node.get_columns()[1].wins, 1, "P2's drumstick")
	assert_true(node.get_columns()[1].winner)
	assert_eq(node.get_columns()[0].needed, versus_match.round_wins_needed())
	assert_true(VersusScoreboardScreen.round_text(PackedInt32Array([1])).contains("P2"))
	node.countdown = 0.01
	node._process(0.02)
	if Flow.busy:
		await Flow.transition_finished
	assert_true(node.leaving)
	assert_eq(versus_match.round_index, 1)
	assert_true(versus_match.round_open, "round 2 plays")
	assert_eq(Flow.current_screen, Flow.SCREEN_LEVEL)
	await _cleanup()


## The results: the headline names the winner, every player stands there with his round wins and 1-3 awards, Rematch
## has the focus (but ignores a confirm in the first moment), Lobby leaves for the lobby with the seats kept.
func test_results_show_winner_awards_and_lead_on() -> void:
	var versus_match: VersusMatch = _match()
	for winner: int in [1, 0, 1, 1]:
		versus_match.begin_round(ARENA)
		versus_match.record_round(PackedInt32Array([winner]))
	assert_true(versus_match.is_over())
	Game.runs[0].best_stack = 12
	Game.runs[1].stolen = 4
	versus_match.finish(Game.runs)
	var awards: Dictionary = versus_match.hand_out_awards(Game.runs)
	Flow.args = {"winners": versus_match.leaders(), "awards": awards}
	var node: VersusResultsScreen = await _open(&"versus_results") as VersusResultsScreen
	assert_eq(node.get_headline(), tr("UI_VS_MATCH_WIN").format({"player": "P2"}))
	var columns: Array[VersusResultsScreen.PlayerColumn] = node.get_columns()
	assert_eq(columns.size(), 2)
	assert_false(columns[0].winner)
	assert_true(columns[1].winner, "the winner stands on the high stone with the crown")
	assert_eq(columns[1].wins, 3)
	assert_eq(columns[0].wins, 1)
	for slot: int in 2:
		var list: Array = awards.get(slot, [])
		assert_true(list.size() >= VersusTuning.AWARDS_MIN and list.size() <= VersusTuning.AWARDS_MAX,
				"P%d gets 1-3 awards" % (slot + 1))
		for award: Variant in list:
			assert_true(VersusResultsScreen.AWARD_KEYS.has(StringName(str(award))), "%s has its texts" % award)
	for award: Dictionary in PlayerRun.VERSUS_AWARDS:
		assert_true(VersusResultsScreen.AWARD_KEYS.has(award["id"]), "every award has texts: %s" % award["id"])
	assert_true(node.get_buttons()[0].has_focus(), "Rematch is the default")
	assert_true(GameInput.has_menu_clusters())
	_press(&"ui_accept")
	assert_false(node.leaving, "a confirm in the first moment is ignored")
	node._process(VersusResultsScreen.ACCEPT_GRACE)
	node.to_lobby()
	if Flow.busy:
		await Flow.transition_finished
	assert_eq(Flow.current_screen, Flow.SCREEN_VERSUS_LOBBY, "Lobby: the seats and rules stay")
	assert_eq(Game.versus_match, versus_match)
	assert_eq(versus_match.player_count(), 2)
	await _cleanup()


## Rematch: the same players and rules from round 0 with a new seed.
func test_results_rematch() -> void:
	var versus_match: VersusMatch = _match()
	versus_match.begin_round(ARENA)
	versus_match.record_round(PackedInt32Array([0]))
	Flow.args = {"winners": PackedInt32Array([0]), "awards": {}}
	var node: VersusResultsScreen = await _open(&"versus_results") as VersusResultsScreen
	var seed_before: int = versus_match.match_seed
	node._process(VersusResultsScreen.ACCEPT_GRACE)
	_press(&"ui_accept")
	if Flow.busy:
		await Flow.transition_finished
	assert_true(node.leaving)
	assert_eq(versus_match.round_index, 0, "from round 0")
	assert_eq(versus_match.match_seed, seed_before + 1, "a new seed")
	assert_eq(Flow.current_screen, Flow.SCREEN_LEVEL)
	await _cleanup()


# =================================================================================================================
# Phase 2 (PLAN.md P2.8): teams, handicap card, rules, arena select, the paintings, scoreboard and results dressing
# =================================================================================================================

## 2 v 2: the first two seats are the Sun, the others the Moon; a player switches with his Jump and a CPU of the full
## team moves over; START waits for two players on each team.
func test_lobby_teams() -> void:
	var node: VersusLobbyScreen = await _open_lobby()
	var versus_match: VersusMatch = Game.versus_match
	_key(KEY_SPACE)
	_key(KEY_KP_0)
	node.add_cpu(2)
	node.get_teams_row().step(1)
	assert_true(node.has_teams())
	assert_eq(_teams(versus_match), [1, 1, 2, 0], "seat order: Sun, Sun, Moon")
	assert_eq(node.get_status_text(), tr("UI_VS_TEAMS_UNEVEN"), "three players cannot make two teams of two")
	node.add_cpu(3)
	assert_eq(_teams(versus_match), [1, 1, 2, 2], "the new CPU joins the smaller team")
	assert_eq(node.get_card(0).team, 1, "the card shows the pennant")
	_key(KEY_SPACE)
	assert_eq(versus_match.get_seat(0).team, 2, "P1's Jump: the Moon")
	assert_eq(_teams(versus_match).count(1), 2, "a CPU of the Moon moved to the Sun")
	assert_eq(_teams(versus_match).count(2), 2)
	versus_match.ready_all()
	node.refresh()
	assert_true(node.can_start(), "two teams of two, everybody ready")
	assert_true(versus_match.is_team_match())
	node.get_teams_row().step(1)
	assert_eq(_teams(versus_match), [0, 0, 0, 0], "free-for-all again")
	await _cleanup()


## The handicap card: Swap turns it - Grub Stack guard x1 -> x1.5 -> x0.5 -> Auto -> x1; Last Caveman Standing hearts
## 3 -> 4 -> 5 -> 1 -> 2 -> Auto.
func test_lobby_handicap_card() -> void:
	var node: VersusLobbyScreen = await _open_lobby()
	var versus_match: VersusMatch = Game.versus_match
	versus_match.mode = Defs.VersusMode.GRUB_STACK
	_key(KEY_SPACE)
	var seat: VersusMatch.Seat = versus_match.get_seat(0)
	assert_eq(node.get_card(0).handicap_kind, &"guard")
	assert_eq(node.get_card(0).handicap_key, JoinScreen.slot_key_text(0, Defs.ACT_SWAP), "the card names his Swap key")
	var guards: Array[int] = []
	for i: int in 3:
		_key(KEY_E)
		guards.append(seat.stack_guard)
	assert_eq(guards, [2, 0, 1] as Array[int], "x1.5, x0.5 ...")
	assert_true(seat.auto_handicap, "... then Auto")
	assert_eq(node.get_card(0).handicap_kind, &"auto")
	assert_eq(VersusLobbyScreen.handicap_text(seat, versus_match.mode), tr("UI_VS_HANDICAP_AUTO"))
	_key(KEY_E)
	assert_false(seat.auto_handicap)
	assert_eq(seat.stack_guard, 1, "back to x1")
	versus_match.mode = Defs.VersusMode.LAST_CAVEMAN
	var hearts: Array[int] = []
	for i: int in 4:
		_key(KEY_E)
		hearts.append(seat.hearts)
	assert_eq(hearts, [4, 5, 1, 2] as Array[int])
	assert_eq(VersusLobbyScreen.handicap_text(seat, versus_match.mode),
			tr("UI_VS_HANDICAP_HEARTS").format({"count": 2}))
	await _cleanup()


## The rules screen: whoever pressed START controls it - the other player's keys do nothing; the rows write the match;
## Crates lock with Classic, Stock is Last Caveman Standing's, Sudden death is fixed there; locked variants need
## paintings; "Choose the arena" goes on.
func test_rules_screen() -> void:
	Save.reset()
	var versus_match: VersusMatch = _two_humans()
	versus_match.mode = Defs.VersusMode.GRUB_STACK
	Flow.args = {"owner": 0}
	var node: VersusRulesScreen = await _open(&"versus_rules") as VersusRulesScreen
	assert_eq(node.owner_slot, 0)
	assert_true(GameInput.has_menu_clusters())
	var rows: Array[VersusRulesScreen.RuleRow] = node.get_rows()
	assert_true(rows[0].has_focus(), "the mode row has the focus")
	_key(KEY_KP_6)
	assert_eq(versus_match.mode, Defs.VersusMode.GRUB_STACK, "P2's Num 6 does nothing: P1 owns the rules")
	_key(KEY_D)
	assert_eq(versus_match.mode, Defs.VersusMode.LAST_CAVEMAN, "P1's D steps the mode")
	assert_false(rows[7].locked, "Stock is a Last Caveman Standing option")
	assert_true(rows[6].locked, "Sudden death is always on in Last Caveman Standing")
	rows[0].step(1)
	assert_eq(versus_match.mode, Defs.VersusMode.HOT_ROCK)
	assert_true(rows[7].locked)
	rows[1].set_index(VersusMatch.Preset.CLASSIC, true)
	assert_eq(versus_match.preset, VersusMatch.Preset.CLASSIC)
	assert_true(rows[4].locked, "Classic: no crates")
	rows[1].set_index(VersusMatch.Preset.MAYHEM, true)
	assert_false(rows[4].locked)
	rows[2].set_index(3, true)
	assert_eq(versus_match.rounds_to_win, VersusRulesScreen.ROUND_CHOICES[3])
	rows[3].set_index(2, true)
	assert_eq(versus_match.round_seconds, VersusRulesScreen.TIME_CHOICES[2])
	rows[5].step(1)
	assert_eq(versus_match.weapons, &"club")
	var chips: Array[VersusRulesScreen.VariantChip] = node.get_chips()
	var names: Array[StringName] = []
	for entry: Array in VersusRulesScreen.VARIANTS:
		names.append(entry[0])
	assert_eq(names, VersusMatch.VARIANT_NAMES, "the variants of the match, in its order")
	assert_false(chips[0].is_locked(), "Hammer Time is open from the start")
	chips[0].emit_signal(&"pressed")
	assert_true(versus_match.has_variant(&"hammer_time"))
	assert_true(chips[2].is_locked(), "Big Bounce needs 15 paintings")
	chips[2].emit_signal(&"pressed")
	assert_false(versus_match.has_variant(&"big_bounce"), "a locked chip does not switch")
	node.choose_arena()
	if Flow.busy:
		await Flow.transition_finished
	assert_eq(Flow.current_screen, Flow.SCREEN_VERSUS_ARENA)
	assert_eq(int(Flow.args.get("owner", -1)), 0, "the owner keeps the arena select")
	await _cleanup()
	Save.reset()


## The arena select: thumbnails (a mini map of the arena file), a locked arena shows the paintings it needs and cannot
## be chosen, the focused card is the match's arena, confirm starts the match.
func test_arena_screen() -> void:
	Save.reset()
	_inject_locked_arena()
	var versus_match: VersusMatch = _two_humans()
	versus_match.mode = Defs.VersusMode.GRUB_STACK
	versus_match.ready_all()
	Flow.args = {"owner": 0}
	var node: VersusArenaScreen = await _open(&"versus_arena") as VersusArenaScreen
	var cards: Array[VersusArenaScreen.ArenaCard] = node.get_cards()
	assert_eq(cards[0].arena, VersusMatch.ARENA_RANDOM)
	assert_eq(cards[-1].arena, VersusMatch.ARENA_PARTY_MIX)
	var locked: VersusArenaScreen.ArenaCard = node.get_card(LOCKED_ARENA)
	assert_not_null(locked, "a closed arena is shown")
	assert_true(locked.locked)
	assert_eq(locked.needs, Tuning.PAINTING_UNLOCK_MESA_RODEO, "with the paintings its reward needs")
	locked.grab_focus()
	assert_ne(versus_match.arena, LOCKED_ARENA, "a locked card never becomes the arena")
	assert_true(node.get_info_text().contains(str(Tuning.PAINTING_UNLOCK_MESA_RODEO)))
	node.choose(LOCKED_ARENA)
	assert_false(node.leaving, "a locked arena cannot be chosen")
	var image: Image = VersusArenaScreen.mini_map(ARENA)
	assert_not_null(image, "a mini map of the arena")
	if image != null:
		assert_eq(image.get_size(), VersusArenaScreen.THUMB_SIZE)
		var sky: Color = image.get_pixel(VersusArenaScreen.THUMB_SIZE.x / 2, 1)
		var floor_pixel: Color = image.get_pixel(VersusArenaScreen.THUMB_SIZE.x / 2,
				VersusTuning.ARENA_FLOOR_ROW * VersusArenaScreen.THUMB_CELL + 3)
		assert_ne(sky, floor_pixel, "the floor row is drawn as ground")
	node.get_card(ARENA).grab_focus()
	assert_eq(versus_match.arena, ARENA, "the focused card is the arena")
	node.choose(ARENA)
	if Flow.busy:
		await Flow.transition_finished
	assert_true(node.leaving)
	assert_eq(Flow.current_screen, Flow.SCREEN_LEVEL, "the match starts")
	assert_eq(Game.level_id, ARENA)
	await _cleanup()
	_remove_injected()
	Save.reset()


## The whole front end by keys only (the path of tools/autoplay/g1_versus.flow): join on the classic keys, a CPU, both
## ready, START (P1's Space) -> rules (Up from the mode row = "Choose the arena", confirm) -> arena (Right from Random =
## the first arena, confirm) -> the first round.
func test_versus_front_end_by_keys() -> void:
	var node: VersusLobbyScreen = await _open_lobby()
	var versus_match: VersusMatch = Game.versus_match
	_key(KEY_SPACE)
	_key(KEY_KP_0)
	_key(_p1_strike(), true)
	_key(KEY_KP_ENTER, true)
	node._process(VersusLobbyScreen.READY_SECONDS + 0.05)
	_key(_p1_strike(), false)
	_key(KEY_KP_ENTER, false)
	assert_true(node.can_start(), "two humans, both ready")
	_press(&"ui_accept")
	if Flow.busy:
		await Flow.transition_finished
	assert_eq(Flow.current_screen, Flow.SCREEN_VERSUS_RULES, "START had the focus")
	var rules: VersusRulesScreen = get_tree().current_scene as VersusRulesScreen
	assert_not_null(rules)
	_press(&"ui_up")
	assert_true(rules.get_next_button().has_focus(), "Up from the mode row: Choose the arena")
	_press(&"ui_accept")
	if Flow.busy:
		await Flow.transition_finished
	assert_eq(Flow.current_screen, Flow.SCREEN_VERSUS_ARENA)
	var arenas: VersusArenaScreen = get_tree().current_scene as VersusArenaScreen
	assert_eq(versus_match.arena, VersusMatch.ARENA_RANDOM, "Random has the focus first")
	_press(&"ui_right")
	var first: StringName = arenas.get_cards()[1].arena
	assert_eq(versus_match.arena, first, "Right: the first arena")
	_press(&"ui_accept")
	if Flow.busy:
		await Flow.transition_finished
	assert_eq(Flow.current_screen, Flow.SCREEN_LEVEL, "the match starts")
	assert_eq(Game.level_id, first)
	await _cleanup()


## Back from the rules and from the paintings keeps the seats and their ready flags.
func test_lobby_round_trips_keep_the_seats() -> void:
	var node: VersusLobbyScreen = await _open_lobby()
	var versus_match: VersusMatch = Game.versus_match
	_key(KEY_SPACE)
	node.add_cpu(1)
	node.set_ready(0, true)
	node.open_paintings()
	if Flow.busy:
		await Flow.transition_finished
	assert_eq(Flow.current_screen, Flow.SCREEN_UNLOCKS)
	assert_eq(Flow.args.get("back"), Flow.SCREEN_VERSUS_LOBBY)
	assert_true(GameInput.has_menu_clusters(), "the versus front end keeps the menu clusters")
	_press(&"ui_cancel")
	if Flow.busy:
		await Flow.transition_finished
	assert_eq(Flow.current_screen, Flow.SCREEN_VERSUS_LOBBY, "back to the lobby")
	assert_eq(versus_match.player_count(), 2, "the seats stay")
	assert_true(versus_match.get_seat(0).ready, "... and P1 stays ready")
	var lobby: VersusLobbyScreen = get_tree().current_scene as VersusLobbyScreen
	lobby.open_rules()
	if Flow.busy:
		await Flow.transition_finished
	assert_eq(Flow.current_screen, Flow.SCREEN_VERSUS_RULES)
	_press(&"ui_cancel")
	if Flow.busy:
		await Flow.transition_finished
	assert_eq(Flow.current_screen, Flow.SCREEN_VERSUS_LOBBY)
	assert_true(versus_match.get_seat(0).ready, "back from the rules: still ready")
	assert_eq(GameInput.get_slot(0).kind, Defs.InputSlotKind.KEYBOARD_LEFT, "P1 keeps his keys")
	await _cleanup()


## The key test of the lobby shows the seated keyboard players in join order, also when a pad sits in front of them.
func test_lobby_key_test_order() -> void:
	var node: VersusLobbyScreen = await _open_lobby()
	_pad_button(1, JOY_BUTTON_A)
	_key(KEY_KP_0)
	_key(KEY_SPACE)
	node.open_key_test()
	var test: JoinScreen.PartyKeyTest = node.get_key_test()
	assert_eq(test.columns_shown, [Vector2i(1, Defs.InputSlotKind.KEYBOARD_RIGHT),
			Vector2i(2, Defs.InputSlotKind.KEYBOARD_LEFT)] as Array[Vector2i], "P2 on the numpad, P3 on W A S D")
	assert_eq(test.column_tag(0), "P2")
	assert_eq(test.column_tag(1), "P3")
	_key(KEY_KP_ENTER, true)
	assert_true(test.is_lit(1, &"attack"), "the numpad's Strike lights P2's")
	_key(KEY_KP_ENTER, false)
	_press(&"ui_cancel")
	assert_false(node.is_key_test_open())
	assert_false(node.leaving, "back closes the test and stays")
	await _cleanup()


## The scoreboard names what was played and what comes next.
func test_scoreboard_names_the_rounds() -> void:
	var versus_match: VersusMatch = _match()
	versus_match.begin_round(ARENA)
	versus_match.record_round(PackedInt32Array([0]))
	Flow.args = {"round_index": 0, "winners": PackedInt32Array([0])}
	var node: VersusScoreboardScreen = await _open(&"versus_scoreboard") as VersusScoreboardScreen
	assert_true(node.get_played_text().contains(UiKit.level_name(ARENA)), "what was played")
	assert_true(node.get_next_text().contains(UiKit.level_name(ARENA)), "what comes next")
	assert_almost_eq(VersusScoreboardScreen.SHOW_SECONDS, 5.0, 0.2, "about five seconds")
	assert_eq(node.get_columns()[0].fresh, 1, "P1's new drumstick is thrown in")
	await _cleanup()


## The results: the heroes are painted on the cave wall; the companion hands the awards out one by one (round robin
## over the players), a tap shows the rest.
func test_results_hand_out_awards() -> void:
	var versus_match: VersusMatch = _match()
	for winner: int in [0, 0, 0]:
		versus_match.begin_round(ARENA)
		versus_match.record_round(PackedInt32Array([winner]))
	Flow.args = {"winners": versus_match.leaders(), "awards": {0: [&"glutton", &"chain_gang"], 1: [&"pacifist"]}}
	var node: VersusResultsScreen = await _open(&"versus_results") as VersusResultsScreen
	assert_true(node.get_columns()[0].painted, "painted on the wall")
	var rows: Array[Control] = node.get_award_rows()
	assert_eq(rows.size(), 3)
	assert_eq(rows[0].get_meta(&"award"), &"glutton")
	assert_eq(rows[1].get_meta(&"award"), &"pacifist", "round robin: P2's first before P1's second")
	assert_eq(node.awards_shown, 0, "the companion waits a moment")
	node._process(VersusResultsScreen.AWARD_DELAY + 0.01)
	assert_eq(node.awards_shown, 1, "the first award")
	node.show_all_awards()
	assert_eq(node.awards_shown, 3)
	for row: Control in rows:
		assert_eq(row.modulate.a, 1.0, "every award shows")
	await _cleanup()


## The full lobby fits the game's 640 x 360 view: four seat cards, Teams, START, the two small entries (Cave Paintings,
## Key test) and the keyboard preset all lie inside it, side by side without overlapping; the Key test entry opens the
## test.
func test_lobby_fits_the_view() -> void:
	var node: VersusLobbyScreen = await _open_lobby()
	_key(KEY_SPACE)
	_key(KEY_KP_0)
	node.add_cpu(2, Defs.BotLevel.CHIEF)
	node.add_cpu(3, Defs.BotLevel.ROOKIE)
	node.set_teams(true)
	await get_tree().process_frame
	var parts: Array[Control] = []
	for slot: int in Defs.MAX_PLAYERS:
		parts.append(node.get_card(slot))
	parts.append_array([node.get_teams_row(), node.get_start_button(), node.get_paintings_button(),
			node.get_key_test_button()] as Array[Control])
	_assert_fits_base_view(node)
	var view: Rect2 = node.get_global_rect()
	if view.size.x >= float(Tuning.VIEW_W) * Tuning.ART_SCALE and view.size.y >= float(Tuning.VIEW_H) * Tuning.ART_SCALE:
		for part: Control in parts:
			assert_true(view.encloses(part.get_global_rect()), "%s inside the view" % part)
		for i: int in Defs.MAX_PLAYERS - 1:
			assert_true(parts[i].get_global_rect().end.x <= parts[i + 1].get_global_rect().position.x,
					"seat cards %d and %d side by side" % [i + 1, i + 2])
		assert_false(node.get_paintings_button().get_global_rect().intersects(node.get_key_test_button().get_global_rect()))
	node.get_key_test_button().emit_signal(&"pressed")
	assert_true(node.is_key_test_open(), "the Key test entry opens the test")
	node.close_key_test()
	assert_true(node.get_key_test_button().has_focus(), "closing it gives the focus back to the entry")
	await _cleanup()


## The rules screen fits the view: Mode and Preset span the panel (a long mode name keeps the big face), every row, chip
## and "Choose the arena" lie inside; a locked variant's info line names the paintings it needs.
func test_rules_screen_fits_the_view() -> void:
	Save.reset()
	var versus_match: VersusMatch = _two_humans()
	versus_match.mode = Defs.VersusMode.LAST_CAVEMAN
	Flow.args = {"owner": 0}
	var node: VersusRulesScreen = await _open(&"versus_rules") as VersusRulesScreen
	await get_tree().process_frame
	var rows: Array[VersusRulesScreen.RuleRow] = node.get_rows()
	assert_true(rows[0].size.x >= VersusRulesScreen.ROW_SIZE.x * 2.0, "the mode row spans both columns")
	var mode_text: String = tr(str(VersusLobbyScreen.MODE_KEYS[Defs.VersusMode.LAST_CAVEMAN][0]))
	var room: float = rows[0].size.x - 2.0 * float(UiOptionRow.PAD + UiOptionRow.ARROW_W) - 52.0
	assert_true(UiKit.font(UiKit.Style.HUD).get_string_size(mode_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0,
			UiKit.SIZE_HUD).x <= room, "Last Caveman Standing fits the mode row in the big face")
	_assert_fits_base_view(node)
	var view: Rect2 = node.get_global_rect()
	if view.size.x >= float(Tuning.VIEW_W) * Tuning.ART_SCALE and view.size.y >= float(Tuning.VIEW_H) * Tuning.ART_SCALE:
		var parts: Array[Control] = []
		parts.append_array(rows)
		parts.append_array(node.get_chips())
		parts.append(node.get_next_button())
		for part: Control in parts:
			assert_true(view.encloses(part.get_global_rect()), "%s inside the view" % part)
	_press(&"ui_down")
	assert_true(rows[1].has_focus(), "Down from Mode: Preset")
	_press(&"ui_down")
	_press(&"ui_down")
	assert_true(rows[3].has_focus(), "then the pairs left before right: Rounds, Round time")
	var locked: VersusRulesScreen.VariantChip = node.get_chips()[2]
	assert_true(locked.is_locked())
	locked.grab_focus()
	assert_true(node.get_info_text().contains(tr("UI_VS_LOCKED").format({"count": Tuning.PAINTING_UNLOCK_VARIANTS})),
			"a locked variant's info names the paintings it needs")
	await _cleanup()
	Save.reset()


## The arena select, the scoreboard and the results of a four-player 2 v 2 match fit the 640 x 360 view.
func test_match_screens_fit_the_view() -> void:
	var versus_match: VersusMatch = VersusMatch.new()
	versus_match.arena = ARENA
	versus_match.rounds_to_win = 3
	versus_match.seat_human(InputSlot.keyboard(Defs.InputSlotKind.KEYBOARD_LEFT))
	versus_match.seat_human(InputSlot.keyboard(Defs.InputSlotKind.KEYBOARD_RIGHT))
	versus_match.seat_bot(Defs.BotLevel.HUNTER)
	versus_match.seat_bot(Defs.BotLevel.CHIEF)
	for slot: int in 4:
		versus_match.get_seat(slot).team = 1 if slot % 2 == 0 else 2
	versus_match.ready_all()
	versus_match.begin_match(3)
	Game.versus_match = versus_match
	Game.start_run(Defs.Difficulty.BEGINNER, Defs.GameMode.VERSUS, 4, 1)
	for winners: Array in [[0, 2], [1, 3], [0, 2]]:
		versus_match.begin_round(ARENA)
		versus_match.record_round(PackedInt32Array(winners))
	var awards: Dictionary = {0: [&"leaning_tower", &"glutton", &"chain_gang"], 1: [&"pickpocket", &"butterfingers",
			&"comeback_caveman"], 2: [&"pacifist"], 3: [&"head_case", &"lava_lover"]}
	for state: Array in [[&"versus_arena", {"owner": 0}],
			[&"versus_scoreboard", {"round_index": 2, "winners": PackedInt32Array([0, 2])}],
			[&"versus_results", {"winners": PackedInt32Array([0, 2]), "awards": awards}]]:
		Flow.args = state[1]
		var node: UiScreen = await _open(state[0])
		if node is VersusResultsScreen:
			(node as VersusResultsScreen).show_all_awards()
		await get_tree().process_frame
		_assert_fits_base_view(node)
		node.queue_free()
		await get_tree().process_frame
	await _cleanup()


## The results of four players: the companion stands inside the view and clear of every player's portrait and plate
## (with a full wall in the top-right corner beside the headline), also after the layout settled.
func test_results_companion_keeps_clear_of_the_players() -> void:
	var versus_match: VersusMatch = VersusMatch.new()
	versus_match.arena = ARENA
	versus_match.rounds_to_win = 2
	versus_match.seat_human(InputSlot.keyboard(Defs.InputSlotKind.KEYBOARD_LEFT))
	versus_match.seat_human(InputSlot.keyboard(Defs.InputSlotKind.KEYBOARD_RIGHT))
	versus_match.seat_bot(Defs.BotLevel.HUNTER)
	versus_match.seat_bot(Defs.BotLevel.CHIEF)
	versus_match.ready_all()
	versus_match.begin_match(5)
	Game.versus_match = versus_match
	Game.start_run(Defs.Difficulty.BEGINNER, Defs.GameMode.VERSUS, 4, 1)
	for winner: int in [2, 2]:
		versus_match.begin_round(ARENA)
		versus_match.record_round(PackedInt32Array([winner]))
	Flow.args = {"winners": versus_match.leaders(), "awards": {2: [&"glutton"]}}
	var node: VersusResultsScreen = await _open(&"versus_results") as VersusResultsScreen
	node._process(0.01)
	await get_tree().process_frame
	node._process(0.01)
	var feet: Vector2 = node.companion_place()
	var body: Rect2 = Rect2(feet - Vector2(VersusResultsScreen.COMPANION_HALF_WIDTH, VersusResultsScreen.COMPANION_HEIGHT),
			Vector2(VersusResultsScreen.COMPANION_HALF_WIDTH * 2.0, VersusResultsScreen.COMPANION_HEIGHT))
	assert_true(Rect2(Vector2.ZERO, node.size).encloses(body), "the companion stands inside the view")
	assert_eq(node.get_columns().size(), 4)
	for column: VersusResultsScreen.PlayerColumn in node.get_columns():
		var origin: Vector2 = column.global_position - node.global_position
		var portrait: Rect2 = Rect2(origin + Vector2(column.size.x * 0.5 - 40.0, column.portrait_top()),
				Vector2(80.0, column.plate_line() + 10.0 - column.portrait_top()))
		assert_false(body.intersects(portrait), "clear of P%d's portrait and plate" % (column.slot + 1))
	await _cleanup()


# =================================================================================================================
# Helpers
# =================================================================================================================

## An arena behind a painting reward (UnlockTable: the Mesa Rodeo), injected into the registry for one test.
const LOCKED_ARENA: StringName = &"arena_mesa_rodeo"


func _inject_locked_arena() -> void:
	if Levels.has_level(LOCKED_ARENA):
		return
	var text: String = "[meta]\nformat = 2\nid = arena_mesa_rodeo\nname = \"Mesa Rodeo\"\nkind = arena\nbiome = canyon\n" \
			+ "players = 4\nmodes = grub_stack,last_caveman\nwrap = none\n"
	Levels._meta[LOCKED_ARENA] = Levels.parse_meta(text)
	Levels._paths[LOCKED_ARENA] = Levels.get_level_path(ARENA)
	Levels._index_campaign()


func _remove_injected() -> void:
	Levels.rescan()


## The teams of the four seats.
func _teams(versus_match: VersusMatch) -> Array[int]:
	var result: Array[int] = []
	for slot: int in Defs.MAX_PLAYERS:
		result.append(versus_match.get_seat(slot).team)
	return result


## A lobby match of two humans on the classic halves (P1 left, P2 numpad), their inputs assigned (the rules and arena
## screens' state after the lobby).
func _two_humans() -> VersusMatch:
	var versus_match: VersusMatch = VersusMatch.new()
	Game.versus_match = versus_match
	Flow.play_mode = Defs.GameMode.VERSUS
	Flow.begin_party_setup()
	GameInput.set_menu_clusters(true)
	Flow.join_player(InputSlot.keyboard(Defs.InputSlotKind.KEYBOARD_LEFT))
	Flow.join_player(InputSlot.keyboard(Defs.InputSlotKind.KEYBOARD_RIGHT))
	return versus_match


## The classic layout's Strike key of P1 (read from InputSlot: Left Ctrl since the orchestrator's G1 resolution).
func _p1_strike() -> Key:
	return InputSlot.default_keys(InputSlot.KeyboardLayout.CLASSIC, Defs.InputSlotKind.KEYBOARD_LEFT, Defs.ACT_ATTACK)[0]

## The lobby of a fresh match with every seat free.
func _open_lobby() -> VersusLobbyScreen:
	Game.versus_match = VersusMatch.new()
	Flow.play_mode = Defs.GameMode.VERSUS
	Flow.begin_party_setup()
	return await _open(&"versus_lobby") as VersusLobbyScreen


## A started match of P1 (left keys, yellow) against a Hunter CPU (pink) on ARENA, first to 3.
func _match() -> VersusMatch:
	var versus_match: VersusMatch = VersusMatch.new()
	versus_match.arena = ARENA
	versus_match.rounds_to_win = 3
	versus_match.seat_human(InputSlot.keyboard(Defs.InputSlotKind.KEYBOARD_LEFT))
	versus_match.seat_bot(Defs.BotLevel.HUNTER)
	versus_match.get_seat(1).palette = &"pink"
	versus_match.ready_all()
	versus_match.begin_match(11)
	Game.versus_match = versus_match
	Game.start_run(Defs.Difficulty.BEGINNER, Defs.GameMode.VERSUS, 2, 1)
	Game.runs[1].palette = &"pink"
	GameInput.assign_slot(0, InputSlot.keyboard(Defs.InputSlotKind.KEYBOARD_LEFT))
	return versus_match


func _idle(_tick: int) -> int:
	return 0


## The screen's content (its safe-area container with the margins) needs no more than the game's base 640 x 360 view,
## whatever size the test's viewport has.
func _assert_fits_base_view(node: UiScreen) -> void:
	var need: Vector2 = node.safe.get_combined_minimum_size()
	var base: Vector2 = Vector2(Tuning.VIEW_W, Tuning.VIEW_H) * float(Tuning.ART_SCALE)
	assert_true(need.x <= base.x and need.y <= base.y, "%s fits the 640 x 360 view (needs %s)" % [node.name, need])


## Instantiate a screen under the test node (not as the current scene) and let it build.
func _open(screen: StringName) -> UiScreen:
	var scene: PackedScene = load(Flow.SCREEN_DIR + String(screen) + ".tscn") as PackedScene
	var node: UiScreen = scene.instantiate() as UiScreen
	add_node(node)
	await get_tree().process_frame
	await get_tree().process_frame
	return node


func _press(action: StringName) -> void:
	for pressed: bool in [true, false]:
		var event: InputEventAction = InputEventAction.new()
		event.action = action
		event.pressed = pressed
		get_tree().root.push_input(event)


## Press (and release) a physical key as the keyboard sends it; `pressed` true / false sends only that edge.
func _key(code: Key, pressed: Variant = null) -> void:
	var states: Array = [true, false] if pressed == null else [bool(pressed)]
	for state: Variant in states:
		var event: InputEventKey = InputEventKey.new()
		event.physical_keycode = code
		event.keycode = code
		event.pressed = bool(state)
		get_tree().root.push_input(event)


func _pad_button(device: int, button: JoyButton) -> void:
	for state: bool in [true, false]:
		var event: InputEventJoypadButton = InputEventJoypadButton.new()
		event.device = device
		event.button_index = button
		event.pressed = state
		get_tree().root.push_input(event)


## Undo what Flow did when a screen was left: wait for the transition, then remove the new scene and overlays.
func _cleanup() -> void:
	if Flow.busy:
		await Flow.transition_finished
	Sim.stop()
	get_tree().paused = false
	var scene: Node = get_tree().current_scene
	if scene != null:
		scene.queue_free()
		get_tree().current_scene = null
	for layer: int in [Defs.LAYER_HUD, Defs.LAYER_TOUCH, Defs.LAYER_MENU]:
		for child: Node in Flow.get_overlay(layer).get_children():
			child.queue_free()
	Flow.current_screen = Flow.SCREEN_BOOT
	Flow.args = {}
	Audio.stop_music(0.0)
	await get_tree().process_frame
