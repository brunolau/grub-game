extends TestCase
## "TIME!" THROUGH THE GAME'S OWN HAND-OVER (the 2.0 release round's ruling F1; DESIGN.md G78 / G95, E.8). A versus
## round the hard cap ends must say why where a player reads it. Until that round the word was shown by a deferred call
## from the cap's tick - onto the HUD of a level Flow was replacing in that very frame - and the tests that proved it
## (tests/test_versus_rules.gd) built a referee and a HUD by hand, so nothing ever handed the round over.
##
## Nothing is built by hand here: every match starts through Flow.start_versus (two humans on the two keyboard halves
## who never press a key), plays a shipped arena with the referee and the HUD the game made, and the gong's hand-over is
## Flow's - the curtain, the deciding moment's arena with ITS new HUD, the scoreboard scene. Owner: ui-B (the banner,
## scripts/ui/hud_versus.gd; the scoreboard's line, scripts/ui/versus_scoreboard.gd).

const COLOSSUS_HALL: StringName = &"arena_colossus_hall"
const FLOE_RINK: StringName = &"arena_floe_rink"
const SEED: int = 4242

var _manual: bool = false
var _deciding: bool = false
var _instant: bool = false
var _replays: int = 0


func before_each() -> void:
	_manual = Sim.manual
	_deciding = Flow.deciding_moment
	_instant = Flow.instant_transitions
	Sim.manual = true
	Flow.instant_transitions = true
	Save.reset()
	Settings.reset()
	GameInput.reset_slots()
	GameInput.clear_scripted()
	Game.versus_match = null
	_replays = 0
	Flow.replay_started.connect(_on_replay_started)


func after_each() -> void:
	if Flow.replay_started.is_connected(_on_replay_started):
		Flow.replay_started.disconnect(_on_replay_started)
	Flow._cancel_replay()
	Flow.deciding_moment = _deciding
	Flow.instant_transitions = _instant
	Sim.stop()
	Sim.time_scale = 1.0
	get_tree().paused = false
	GameInput.clear_scripted()
	GameInput.reset_slots()
	GameInput.set_menu_clusters(false)
	Game.versus_match = null
	Game.new_game(Defs.Difficulty.BEGINNER)
	Flow.play_mode = Defs.GameMode.SINGLE
	Flow.args = {}
	Settings.reset()
	Sim.manual = _manual


func _on_replay_started(_round_index: int, _first: int, _last: int, _steal: bool) -> void:
	_replays += 1


## Leave the match's last scene behind (as tests/test_core_replay.gd does).
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


## The versus HUD on the screen now: the one Flow put on its HUD layer for the level that runs (a HUD Flow has cleared
## away with its level is queued for deletion and does not count).
func _hud() -> HudVersus:
	for child: Node in Flow.get_overlay(Defs.LAYER_HUD).get_children():
		var hud: Hud = child as Hud
		if hud != null and not hud.is_queued_for_deletion():
			return hud.get_versus()
	return null


## Two humans, `mode` on `arena`, first to two round wins (a drawn round is followed by the scoreboard), started through
## Flow.start_versus; the countdown passes. Returns the round's referee (null when the match did not start).
func _start(mode: int, arena: StringName) -> VersusReferee:
	assert_true(Levels.has_level(arena), "the shipped arena %s" % arena)
	var versus_match: VersusMatch = VersusMatch.new()
	versus_match.mode = mode
	versus_match.arena = arena
	versus_match.rounds_to_win = 2
	assert_eq(versus_match.seat_human(InputSlot.keyboard(Defs.InputSlotKind.KEYBOARD_LEFT)), 0)
	assert_eq(versus_match.seat_human(InputSlot.keyboard(Defs.InputSlotKind.KEYBOARD_RIGHT)), 1)
	versus_match.ready_all()
	assert_true(Flow.start_versus(versus_match, SEED), "Flow.start_versus starts the match")
	for i: int in 12:
		await get_tree().process_frame
		if not Flow.busy and Flow.current_screen == Flow.SCREEN_LEVEL and Game.level != null:
			break
	assert_eq(Flow.current_screen, Flow.SCREEN_LEVEL, "the arena runs")
	var level: LevelBase = Game.level
	if level == null:
		return null
	assert_eq(level.level_id, arena)
	assert_eq(level.hero_count(), 2, "two heroes")
	assert_false(GameInput.is_scripted(), "no script drives a hero: both read their keys, and nobody presses one")
	var referee: VersusReferee = VersusReferee.find(level)
	assert_not_null(referee, "the arena's referee")
	if referee == null:
		return null
	assert_true(level.party_driver == referee, "... which the level drives as its party driver")
	var waited: int = 0
	while referee.phase == VersusReferee.PHASE_INTRO and waited < 400:
		Sim.step(1)
		waited += 1
	assert_eq(referee.phase, VersusReferee.PHASE_PLAY, "the countdown ended")
	assert_not_null(_hud(), "Flow put the versus HUD over the arena")
	return referee


## Nobody moves until one tick before the hard cap: the cap is armed (the sudden death of Last Caveman Standing, the
## Golden Drumstick of a tied Grub Stack round), the round still runs and nothing says "TIME!" yet. Returns the cap's
## round tick (-1 when the round did not get there).
func _idle_to_the_tick_before_the_cap(referee: VersusReferee, golden: bool) -> int:
	var guard: int = 0
	while referee.cap_at < 0 and referee.phase != VersusReferee.PHASE_OVER and guard < 6000:
		Sim.step(1)
		guard += 1
	assert_true(referee.cap_at > 0, "the hard cap is armed after %d ticks of play" % referee.round_ticks)
	if referee.cap_at <= 0:
		return -1
	Sim.step(referee.cap_at - referee.round_ticks - 1)
	assert_eq(referee.round_ticks, referee.cap_at - 1, "one tick before the cap")
	assert_eq(referee.phase, VersusReferee.PHASE_GOLDEN if golden else VersusReferee.PHASE_PLAY, "the round still runs")
	assert_false(referee.ended_by_cap())
	var hud: HudVersus = _hud()
	assert_eq(hud.get_reason_text(), "", "nothing says \"TIME!\" before the cap")
	assert_eq(hud.banner_reason, "")
	assert_false(HudVersus.time_called(0))
	hud.refresh()
	assert_eq(hud.get_sundial().seconds, 1, "the sundial has counted the cap down to its last second")
	assert_true(hud.get_sundial().is_warning(), "... in red")
	return referee.cap_at


## The cap's tick with the deciding moment ON, from the gong to the scoreboard: "TIME!" on the round's own HUD at the
## gong, on the new HUD of the replayed arena on every tick of the deciding moment (over what every replay says), over
## the result again when the replay ends, and on the scoreboard.
func _the_gong_the_replay_and_the_scoreboard(referee: VersusReferee, cap: int) -> void:
	var time: String = tr("UI_VS_TIME")
	var draw: String = tr("UI_VS_DRAW")
	var round_hud: HudVersus = _hud()
	var versus_match: VersusMatch = Game.versus_match
	Sim.step(1)
	# 1. The gong's own tick. Flow has taken the round over already (the replay's curtain is down, this HUD is cleared
	#    away with its level): what it showed in that frame is what a closing curtain leaves to read.
	assert_true(referee.ended_by_cap(), "the hard cap ended the round at round tick %d" % cap)
	assert_eq(versus_match.history.size(), 1, "Flow recorded the round (Flow.end_round)")
	assert_eq(versus_match.history[0]["winners"], PackedInt32Array(), "... drawn")
	assert_true(Flow.is_replaying(), "... and started its deciding moment")
	assert_eq(round_hud.get_reason_text(), time, "the round's HUD says \"TIME!\" on the gong's own tick")
	assert_eq(round_hud.banner_text, draw, "over the result")
	assert_true(HudVersus.time_called(0), "and the round is noted on the match for who shows it next")
	if Flow.busy:
		await Flow.transition_finished
	# 2. The deciding moment: another arena scene, another referee, another HUD.
	assert_eq(_replays, 1, "the deciding moment plays")
	var replay_hud: HudVersus = _hud()
	assert_not_null(replay_hud)
	assert_true(replay_hud != round_hud, "the replayed arena came with a HUD of its own")
	assert_true(replay_hud.replaying)
	var window: Vector2i = Flow.replay_window()
	assert_eq(window.y - window.x + 1, VersusReplay.DECIDING_TICKS, "the last 3 s before the gong")
	var shown: int = 0
	var ticks: int = 0
	var other: PackedStringArray = PackedStringArray()
	while Flow.is_replaying() and ticks < VersusReplay.DECIDING_TICKS + 5:
		# Before each tick of the window: what the frame in front of it shows.
		if replay_hud.get_reason_text() == time:
			shown += 1
		if replay_hud.banner_text != tr("UI_VS_REPLAY_MOMENT") or replay_hud.banner_hint != tr("UI_VS_REPLAY_SKIP"):
			other.append("tick %d: '%s' / '%s'" % [Sim.tick + 1, replay_hud.banner_text, replay_hud.banner_hint])
		Sim.step(1)
		ticks += 1
	assert_false(Flow.is_replaying(), "the window's last tick ended the replay")
	assert_eq(ticks, VersusReplay.DECIDING_TICKS)
	assert_eq(shown, ticks, "\"TIME!\" stood over the replay's banner before every one of its %d ticks" % ticks)
	assert_eq(other, PackedStringArray(), "and under it the banner said what every replay says, with the skip hint")
	# 3. The replay's end (its own gong fell on the window's last tick): the result under "TIME!" until the scoreboard.
	assert_eq(replay_hud.get_reason_text(), time, "\"TIME!\" stays when the replay ends")
	assert_eq(replay_hud.banner_text, draw, "over the result again")
	if Flow.busy:
		await Flow.transition_finished
	# 4. The scoreboard.
	assert_eq(Flow.current_screen, Flow.SCREEN_VERSUS_SCOREBOARD, "then the scoreboard")
	var board: VersusScoreboardScreen = get_tree().current_scene as VersusScoreboardScreen
	assert_not_null(board)
	if board != null:
		assert_eq(board.get_reason_text(), time, "the scoreboard says \"TIME!\"")
		assert_eq(board.get_headline_text(), draw, "before its result line")
	assert_eq(versus_match.round_index, 1, "the match goes on")


func test_time_is_on_the_screen_from_the_cap_of_last_caveman_standing_to_the_scoreboard() -> void:
	Flow.deciding_moment = true
	var referee: VersusReferee = await _start(Defs.VersusMode.LAST_CAVEMAN, COLOSSUS_HALL)
	if referee == null:
		await _finish()
		return
	var cap: int = _idle_to_the_tick_before_the_cap(referee, false)
	assert_eq(cap, VersusTuning.SUDDEN_DEATH_AT_TICKS + VersusTuning.SUDDEN_DEATH_CAP_TICKS,
			"the cap of two heroes who never move on Colossus Hall")
	if cap > 0:
		print("    Last Caveman Standing on Colossus Hall: the cap at round tick %d" % cap)
		await _the_gong_the_replay_and_the_scoreboard(referee, cap)
	await _finish()


func test_time_is_on_the_screen_from_the_cap_of_the_golden_drumstick_to_the_scoreboard() -> void:
	# G95: a tied Grub Stack round drops the Golden Drumstick, and nobody takes it. Its deciding moment plays while the
	# drumstick lies there: the banner must be the replay's (the release verifier read "GOLDEN DRUMSTICK! / Grab it to
	# win the round" there, ruling F4), under "TIME!".
	Flow.deciding_moment = true
	var referee: VersusReferee = await _start(Defs.VersusMode.GRUB_STACK, FLOE_RINK)
	if referee == null:
		await _finish()
		return
	var cap: int = _idle_to_the_tick_before_the_cap(referee, true)
	if cap > 0:
		print("    Grub Stack on Floe Rink: the Golden Drumstick's cap at round tick %d" % cap)
		assert_eq(cap, referee.round_total + VersusTuning.SUDDEN_DEATH_CAP_TICKS, "the clock, then the drumstick's cap")
		await _the_gong_the_replay_and_the_scoreboard(referee, cap)
	await _finish()


func test_time_is_on_the_scoreboard_when_the_deciding_moment_is_off() -> void:
	Flow.deciding_moment = false
	var referee: VersusReferee = await _start(Defs.VersusMode.LAST_CAVEMAN, COLOSSUS_HALL)
	if referee == null:
		await _finish()
		return
	var cap: int = _idle_to_the_tick_before_the_cap(referee, false)
	if cap > 0:
		var round_hud: HudVersus = _hud()
		Sim.step(1)
		assert_true(referee.ended_by_cap())
		assert_false(Flow.is_replaying(), "off: no deciding moment")
		assert_eq(round_hud.get_reason_text(), tr("UI_VS_TIME"), "the round's HUD says \"TIME!\" on the gong's own tick")
		assert_eq(round_hud.banner_text, tr("UI_VS_DRAW"))
		if Flow.busy:
			await Flow.transition_finished
		assert_eq(_replays, 0)
		assert_eq(Flow.current_screen, Flow.SCREEN_VERSUS_SCOREBOARD, "the scoreboard follows the gong")
		var board: VersusScoreboardScreen = get_tree().current_scene as VersusScoreboardScreen
		assert_not_null(board)
		if board != null:
			assert_eq(board.get_reason_text(), tr("UI_VS_TIME"), "and says \"TIME!\"")
			assert_eq(board.get_headline_text(), tr("UI_VS_DRAW"))
	await _finish()


func test_a_round_the_cap_did_not_end_says_no_time_anywhere() -> void:
	# The same hand-over for a round the last one standing ends late in the sudden death: the winner, never "TIME!".
	Flow.deciding_moment = true
	var referee: VersusReferee = await _start(Defs.VersusMode.LAST_CAVEMAN, COLOSSUS_HALL)
	if referee == null:
		await _finish()
		return
	var cap: int = _idle_to_the_tick_before_the_cap(referee, false)
	if cap > 0:
		var round_hud: HudVersus = _hud()
		var p1_wins: String = HudVersus.result_text(PackedInt32Array([0]))
		Game.level.get_hero(1).kill(&"liquid")
		Sim.step(1)
		assert_eq(referee.phase, VersusReferee.PHASE_OVER, "the gong fell on the cap's own tick")
		assert_eq(referee.winner_slots, PackedInt32Array([0]), "by the last one standing")
		assert_false(referee.ended_by_cap(), "which is not the cap's doing")
		assert_eq(round_hud.banner_text, p1_wins)
		assert_eq(round_hud.get_reason_text(), "", "no \"TIME!\" at the gong")
		assert_false(HudVersus.time_called(0))
		if Flow.busy:
			await Flow.transition_finished
		var replay_hud: HudVersus = _hud()
		assert_true(Flow.is_replaying() and replay_hud != null and replay_hud.replaying, "the deciding moment plays")
		if replay_hud != null:
			assert_eq(replay_hud.banner_text, tr("UI_VS_REPLAY_MOMENT"))
			assert_eq(replay_hud.get_reason_text(), "", "none over the replay")
		Flow.skip_replay()
		if replay_hud != null:
			assert_false(replay_hud.is_banner_visible(), "a replay without a reason takes its banner away, as ever")
		if Flow.busy:
			await Flow.transition_finished
		assert_eq(Flow.current_screen, Flow.SCREEN_VERSUS_SCOREBOARD)
		var board: VersusScoreboardScreen = get_tree().current_scene as VersusScoreboardScreen
		assert_not_null(board)
		if board != null:
			assert_eq(board.get_reason_text(), "", "none on the scoreboard")
			assert_eq(board.get_headline_text(), p1_wins)
	await _finish()


func test_a_skipped_replay_of_a_capped_round_keeps_time_until_the_scoreboard() -> void:
	Flow.deciding_moment = true
	var referee: VersusReferee = await _start(Defs.VersusMode.LAST_CAVEMAN, COLOSSUS_HALL)
	if referee == null:
		await _finish()
		return
	var cap: int = _idle_to_the_tick_before_the_cap(referee, false)
	if cap > 0:
		Sim.step(1)
		if Flow.busy:
			await Flow.transition_finished
		var replay_hud: HudVersus = _hud()
		assert_true(Flow.is_replaying() and replay_hud != null)
		Sim.step(10)
		Flow.skip_replay()
		assert_false(Flow.is_replaying(), "skipped")
		if replay_hud != null:
			assert_eq(replay_hud.get_reason_text(), tr("UI_VS_TIME"), "\"TIME!\" stays after the skip")
			assert_eq(replay_hud.banner_text, tr("UI_VS_DRAW"), "over the round's result (the match's record)")
		if Flow.busy:
			await Flow.transition_finished
		var board: VersusScoreboardScreen = get_tree().current_scene as VersusScoreboardScreen
		assert_not_null(board)
		if board != null:
			assert_eq(board.get_reason_text(), tr("UI_VS_TIME"))
		# The next round: the note is the last round's, and a new round's HUD starts without the reason.
		Flow.next_round()
		for i: int in 12:
			await get_tree().process_frame
			if not Flow.busy and Flow.current_screen == Flow.SCREEN_LEVEL and Game.level != null:
				break
		assert_eq(Flow.current_screen, Flow.SCREEN_LEVEL, "round 2")
		var next_hud: HudVersus = _hud()
		assert_not_null(next_hud)
		if next_hud != null:
			Sim.step(3)
			assert_eq(next_hud.get_reason_text(), "", "round 2 counts down without \"TIME!\"")
		assert_false(HudVersus.time_called(1), "round 2 is not noted before its own gong")
	await _finish()
