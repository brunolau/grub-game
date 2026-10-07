extends TestCase
## The deciding moment of a versus round (docs/expansion/PLAN.md P2.6, DESIGN.md E.8 step 5, GAMEPLAY.md 13.10.1):
## VersusReplay's input log, start snapshot and window, and Flow's replay - the arena loaded again with the round seed,
## every hero fed from the log, tick for tick the round that was played - between the gong and the scoreboard;
## skippable, and the match and the runs as the round left them afterwards.

## A developer arena with a referee (world-B; kind = arena, chosen by id).
const ARENA: StringName = &"test_world_arena_flat"
const ROUND_TICKS: int = 220

var _digests: Dictionary = {}
var _recording: bool = false
var _started: Array = []
var _finished: Array = []


func before_each() -> void:
	Sim.manual = true
	Save.reset()
	Settings.reset()
	GameInput.reset_slots()
	GameInput.clear_scripted()
	Game.versus_match = null
	_digests.clear()
	_started.clear()
	_finished.clear()
	Flow.replay_started.connect(_on_started)
	Flow.replay_finished.connect(_on_finished)
	Sim.tick_finished.connect(_on_tick)


func after_each() -> void:
	for pair: Array in [[Flow.replay_started, _on_started], [Flow.replay_finished, _on_finished],
			[Sim.tick_finished, _on_tick]]:
		if (pair[0] as Signal).is_connected(pair[1]):
			(pair[0] as Signal).disconnect(pair[1])
	Flow._cancel_replay()
	Flow.deciding_moment = false
	Sim.stop()
	Sim.time_scale = 1.0
	get_tree().paused = false
	VersusMatch.bot_factory = Callable()
	GameInput.reset_slots()
	GameInput.clear_scripted()
	Game.versus_match = null
	Game.new_game(Defs.Difficulty.BEGINNER)
	Flow.play_mode = Defs.GameMode.SINGLE
	Settings.reset()
	Sim.manual = false


func _finish() -> void:
	if Flow.busy:
		await Flow.transition_finished
	Sim.stop()
	get_tree().paused = false
	if get_tree().current_scene != null:
		get_tree().current_scene.queue_free()
		get_tree().current_scene = null
	Flow.current_screen = Flow.SCREEN_BOOT
	Flow.args = {}
	await get_tree().process_frame


func _on_started(round_index: int, first: int, last: int, steal: bool) -> void:
	_started.append([round_index, first, last, steal])


func _on_finished(skipped: bool) -> void:
	_finished.append(skipped)


## Every hero's state after a tick (and the referee's stacks): the round's fingerprint.
func _on_tick(tick: int) -> void:
	var level: LevelBase = Game.level
	if not _recording or level == null:
		return
	var parts: Array = []
	for slot: int in level.hero_count():
		var hero: PlayerBase = level.get_hero(slot)
		if hero != null:
			parts.append([slot, hero.sim_pos, hero.xvel, hero.yvel, hero.state, hero.facing, hero.dead])
	var referee: VersusReferee = VersusReferee.find(level)
	if referee != null:
		parts.append([referee.phase, referee.round_ticks, referee.stack_of(0), referee.stack_of(1)])
	parts.append(Sim.rng.get_state())
	_digests[tick] = str(parts)


## A busy, deterministic input pattern per slot (moves, jumps, strikes, crouches) - a "bot" that never reads the state.
static func _pattern(tick: int, slot: int) -> int:
	var phase: int = (tick / 9 + slot * 5) % 12
	var flags: int = Defs.IN_RIGHT if phase < 5 else (Defs.IN_LEFT if phase < 10 else 0)
	if (tick + slot * 3) % 17 < 3:
		flags |= Defs.IN_UP
	if (tick * (slot + 2)) % 23 < 4:
		flags |= Defs.IN_FIRE
	if phase == 11:
		flags |= Defs.IN_DOWN
	return flags


func _bot_factory(slot: int, _level: int, _seed: int) -> Callable:
	return func(tick: int) -> int: return _pattern(tick, slot)


func _two_bot_match() -> VersusMatch:
	VersusMatch.bot_factory = _bot_factory
	var versus_match: VersusMatch = VersusMatch.new()
	versus_match.arena = ARENA
	versus_match.mode = Defs.VersusMode.GRUB_STACK
	versus_match.rounds_to_win = 3
	versus_match.seat_bot(Defs.BotLevel.ROOKIE)
	versus_match.seat_bot(Defs.BotLevel.ROOKIE)
	return versus_match


# =================================================================================================================
# VersusReplay
# =================================================================================================================

func test_the_log_the_window_and_the_biggest_steal() -> void:
	var versus_match: VersusMatch = VersusMatch.new()
	versus_match.seat_human(InputSlot.keyboard(Defs.InputSlotKind.KEYBOARD_LEFT))
	versus_match.seat_bot()
	versus_match.begin_match(5)
	versus_match.round_wins[1] = 1
	versus_match.begin_round(&"some_arena")
	var runs: Array[PlayerRun] = [PlayerRun.new(0), PlayerRun.new(1)]
	runs[0].weapon = Defs.Weapon.AXE
	var replay: VersusReplay = VersusReplay.begin(versus_match, &"some_arena", 99, runs)
	assert_eq(replay.players, 2)
	assert_eq(replay.round_wins, PackedInt32Array([0, 1, 0, 0]), "the wins the round started with")
	assert_eq(int(replay.start_runs[0]["weapon"]), Defs.Weapon.AXE, "the runs the round started with")
	assert_false(replay.can_replay())
	for tick: int in range(1, 201):
		replay.log_tick(tick, PackedInt32Array([tick, tick * 2]))
		if tick == 60:
			runs[1].stolen += 3
		if tick == 90:
			runs[0].stolen += 2
		if tick == 120:
			runs[0].stolen += 3
		replay.note_tick(tick, runs)
	replay.log_tick(205, PackedInt32Array([1, 1]))
	assert_eq(replay.ticks, 200, "the log has no holes")
	assert_eq(replay.flags_at(37, 0), 37)
	assert_eq(replay.flags_at(37, 1), 74)
	assert_eq(replay.flags_at(0, 0), 0)
	assert_eq(replay.flags_at(201, 0), 0)
	assert_eq(replay.flags_at(5, 2), 0, "a slot that does not play")
	assert_eq(replay.steal_tick, 120, "the biggest steal (3 units), the later of two")
	assert_eq(replay.steal_units, 3)
	runs[0].food = 9
	replay.finish(200, runs)
	replay.log_tick(201, PackedInt32Array([1, 1]))
	assert_eq(replay.ticks, 200, "nothing is logged after the gong")
	assert_true(replay.can_replay())
	assert_eq(int(replay.end_runs[0]["food"]), 9)
	assert_eq(replay.window(), Vector2i(120 + VersusReplay.STEAL_LEAD_OUT_TICKS - VersusReplay.DECIDING_TICKS + 1,
			120 + VersusReplay.STEAL_LEAD_OUT_TICKS), "Grub Stack: 3 s around the biggest steal")
	assert_true(replay.shows_steal())
	replay.round_mode = Defs.VersusMode.LAST_CAVEMAN
	assert_eq(replay.window(), Vector2i(200 - VersusReplay.DECIDING_TICKS + 1, 200), "the other modes: the last 3 s")
	assert_false(replay.shows_steal())
	var short: VersusReplay = VersusReplay.begin(versus_match, &"some_arena", 99, runs)
	for tick: int in range(1, 31):
		short.log_tick(tick, PackedInt32Array([0, 0]))
	short.finish(30, runs)
	assert_eq(short.window(), Vector2i(1, 30), "a round shorter than 3 s shows all of it")
	versus_match.record_round(PackedInt32Array([1]))
	replay.apply_start_state(versus_match)
	assert_eq(versus_match.round_index, 0, "the match reads the round's start again")
	assert_eq(versus_match.round_wins, PackedInt32Array([0, 1, 0, 0]))


func test_a_run_snapshot_round_trips() -> void:
	var run: PlayerRun = PlayerRun.new(2)
	run.hearts = 1
	run.bones = 4
	run.weapon = Defs.Weapon.SPEAR
	run.belt = Defs.Weapon.CLUB
	run.has_glider = true
	run.palette = &"pink"
	run.pattern = 5
	run.stolen = 7
	run.best_stack = 12
	var copy: PlayerRun = PlayerRun.new(2)
	copy.from_dict(run.to_dict())
	assert_eq(copy.to_dict(), run.to_dict(), "every field comes back")
	copy.from_dict({"hearts": 3})
	assert_eq(copy.hearts, 3)
	assert_eq(copy.stolen, 7, "fields a state does not hold keep their value")


# =================================================================================================================
# Flow: the replay between the gong and the scoreboard
# =================================================================================================================

func test_the_deciding_moment_replays_the_round_tick_for_tick() -> void:
	if not Levels.has_level(ARENA):
		assert_true(true, "world-B's developer arena is not in this tree")
		return
	Flow.deciding_moment = true
	var versus_match: VersusMatch = _two_bot_match()
	assert_true(Flow.start_versus(versus_match, 4242))
	if Flow.busy:
		await Flow.transition_finished
	assert_eq(Flow.current_screen, Flow.SCREEN_LEVEL)
	assert_not_null(versus_match.replay, "the round is recorded")
	_recording = true
	Sim.step(ROUND_TICKS)
	var original: Dictionary = _digests.duplicate()
	_digests.clear()
	assert_eq(original.size(), ROUND_TICKS)
	var end_runs: Array[Dictionary] = VersusReplay.snapshot_runs(Game.runs, 2)
	assert_eq(versus_match.replay.ticks, ROUND_TICKS, "every tick logged")
	assert_eq(versus_match.replay.flags_at(100, 1), _pattern(100, 1), "the bots' flags are in the log")
	Flow.end_round(PackedInt32Array([1]))
	assert_true(Flow.is_replaying(), "the gong starts the deciding moment")
	if Flow.busy:
		await Flow.transition_finished
	var window: Vector2i = Flow.replay_window()
	assert_eq(window, versus_match.replay.window())
	assert_eq(_started.size(), 1)
	if _started.size() == 1:
		assert_eq(_started[0], [0, window.x, window.y, versus_match.replay.shows_steal()])
	assert_eq(Sim.tick, window.x - 1, "the ticks before the window ran behind the curtain")
	assert_eq(Sim.time_scale, VersusReplay.REPLAY_SPEED, "half speed")
	assert_eq(versus_match.round_index, 0, "the referee reads round 0 again")
	assert_eq(versus_match.round_wins[1], 0, "with the wins of its start")
	assert_false(Audio.are_effects_muted())
	while Flow.is_replaying() and Sim.tick < window.y + 5:
		Sim.step(1)
	assert_false(Flow.is_replaying(), "the window's last tick ends it")
	assert_eq(Sim.tick, window.y)
	var same: int = 0
	for tick: int in range(1, window.y + 1):
		if _digests.get(tick, "") == original.get(tick, "-"):
			same += 1
		elif same == tick - 1:
			assert_eq(_digests.get(tick, ""), original.get(tick, ""), "tick %d of the replay" % tick)
	assert_eq(same, window.y, "the replay is the round, tick for tick")
	assert_eq(_finished, [false])
	if Flow.busy:
		await Flow.transition_finished
	assert_eq(Sim.time_scale, 1.0)
	assert_eq(versus_match.round_index, 1, "the match goes on after the round")
	assert_eq(versus_match.round_wins[1], 1)
	assert_eq(VersusReplay.snapshot_runs(Game.runs, 2), end_runs, "the statistics of the real round, not twice")
	assert_false(GameInput.is_slot_scripted(0), "the replay's scripts are gone")
	if Flow.has_screen(Flow.SCREEN_VERSUS_SCOREBOARD):
		assert_eq(Flow.current_screen, Flow.SCREEN_VERSUS_SCOREBOARD, "then the scoreboard")
		assert_eq(Flow.args.get("round_index"), 0)
		assert_eq(Flow.args.get("winners"), PackedInt32Array([1]))
	await _finish()


func test_the_deciding_moment_is_skippable_and_off_without_a_window() -> void:
	if not Levels.has_level(ARENA):
		assert_true(true, "world-B's developer arena is not in this tree")
		return
	var versus_match: VersusMatch = _two_bot_match()
	GameInput.set_scripted_slot(0, func(_tick: int) -> int: return 0)
	Flow.deciding_moment = false
	assert_true(Flow.start_versus(versus_match, 7))
	if Flow.busy:
		await Flow.transition_finished
	Sim.step(90)
	Flow.end_round(PackedInt32Array([0]))
	assert_false(Flow.is_replaying(), "off: the scoreboard follows the gong at once")
	if Flow.busy:
		await Flow.transition_finished
	assert_true(_started.is_empty())
	if Flow.current_screen == Flow.SCREEN_VERSUS_SCOREBOARD:
		Flow.next_round()
		if Flow.busy:
			await Flow.transition_finished
	Flow.deciding_moment = true
	assert_eq(Flow.current_screen, Flow.SCREEN_LEVEL, "round 1")
	Sim.step(150)
	var end_runs: Array[Dictionary] = VersusReplay.snapshot_runs(Game.runs, 2)
	Flow.end_round(PackedInt32Array([1]))
	if Flow.busy:
		await Flow.transition_finished
	assert_true(Flow.is_replaying())
	assert_eq(_started.size(), 1)
	if _started.size() == 1:
		assert_eq(_started[0][0], 1, "round 1's deciding moment")
	var accept: InputEventAction = InputEventAction.new()
	accept.action = &"ui_accept"
	accept.pressed = true
	assert_true(Flow._skips_replay(accept), "accept skips")
	var key_w: InputEventKey = InputEventKey.new()
	key_w.physical_keycode = KEY_W
	key_w.pressed = true
	assert_false(Flow._skips_replay(key_w), "walking does not")
	Flow.skip_replay()
	assert_false(Flow.is_replaying())
	assert_eq(_finished, [true], "skipped")
	if Flow.busy:
		await Flow.transition_finished
	assert_eq(Sim.time_scale, 1.0)
	assert_eq(versus_match.round_index, 2)
	assert_eq(VersusReplay.snapshot_runs(Game.runs, 2), end_runs, "a skip restores the round's end too")
	assert_true(GameInput.is_slot_scripted(0), "a script that drove a slot before the replay drives it again")
	Flow.skip_replay()
	assert_eq(_finished.size(), 1, "nothing to skip any more")
	versus_match.round_open = true
	assert_false(Flow.play_deciding_moment(), "never while a round is open")
	versus_match.round_open = false
	await _finish()
