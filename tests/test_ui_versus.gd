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
## START needs two players, everybody ready and an arena, and starts the match (Flow.start_versus).
func test_lobby_ready_and_start() -> void:
	var node: VersusLobbyScreen = await _open_lobby()
	var versus_match: VersusMatch = Game.versus_match
	_key(KEY_SPACE)
	node.add_cpu(1, Defs.BotLevel.ROOKIE)
	node.set_arena(ARENA)
	assert_eq(versus_match.arena, ARENA, "the developer arena is offered in debug builds")
	assert_eq(node.get_status_text(), tr("UI_VS_NOT_READY"))
	assert_false(node.can_start())
	_key(KEY_A)
	assert_ne(versus_match.get_seat(0).palette, &"yellow", "before he is ready, P1's keys work his seat")
	_key(KEY_SHIFT, true)
	node._process(VersusLobbyScreen.READY_SECONDS + 0.05)
	_key(KEY_SHIFT, false)
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
	node.start_match()
	if Flow.busy:
		await Flow.transition_finished
	assert_true(node.leaving)
	assert_eq(Game.mode, Defs.GameMode.VERSUS)
	assert_eq(Game.party, 2)
	assert_eq(Flow.current_screen, Flow.SCREEN_LEVEL, "the first round plays")
	assert_eq(Game.level_id, ARENA)
	assert_eq(GameInput.get_slot(1).kind, Defs.InputSlotKind.BOT, "the CPU drives P2")
	await _cleanup()


## The mode row offers the launch modes; the arena row Random, the arenas of the mode for this many players and Party
## Mix.
func test_lobby_mode_and_arena_choices() -> void:
	var node: VersusLobbyScreen = await _open_lobby()
	_key(KEY_SPACE)
	node.add_cpu(1)
	for mode: int in VersusMatch.LAUNCH_MODES:
		node.set_mode(mode)
		assert_eq(Game.versus_match.mode, mode)
		var choices: Array[StringName] = node.get_arena_choices()
		assert_eq(choices[0], VersusMatch.ARENA_RANDOM, "Random first")
		assert_eq(choices[-1], VersusMatch.ARENA_PARTY_MIX, "Party Mix last")
		for id: StringName in choices.slice(1, choices.size() - 1):
			assert_true(VersusMatch.arena_modes(id).has(mode) or LevelText.to_list(Levels.get_value(id, "modes", "")) \
					.has(String(Defs.versus_mode_name(mode))), "%s plays %s" % [id, mode])
	assert_eq(VersusLobbyScreen.arena_text(VersusMatch.ARENA_RANDOM), "UI_VS_ARENA_RANDOM")
	assert_eq(VersusLobbyScreen.arena_text(ARENA), UiKit.level_name(ARENA))
	await _cleanup()


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
# Helpers
# =================================================================================================================

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
