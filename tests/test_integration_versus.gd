extends TestCase
## Versus on one keyboard, end to end (owner: integration; docs/expansion/PLAN.md P1.3, DESIGN.md D.11 / E.9: "must be
## proven by a scripted two-player versus match driven only by those keys").
##
## Two humans share one keyboard in the classic layout - P1 W A S D + Space (jump) + Left Shift (strike) + E (swap) +
## Q (look), P2 Num 8 4 5 6 + Num 0 + Num Enter + Num + + Num . - and play a Grub Stack match that Flow starts
## (Flow.start_versus with two human seats on the keyboard halves). Nothing is scripted: the test presses and releases
## physical keys through Input, tick by tick, and the heroes, the referee, the gong and the match result follow from
## them. The numpad is bound by physical key, so it must work whatever the NumLock state: with NumLock off Windows
## reports the numpad keys with the navigation keycodes (Num 4 = Left, Num 0 = Insert, ...) and the same physical
## keycodes; both are driven here. The bindings and the key test of the options are ui-B's (tests/test_ui_options.gd).

## Classic layout: per player, flag -> physical key.
const CLASSIC: Array[Dictionary] = [
	{Defs.IN_LEFT: KEY_A, Defs.IN_RIGHT: KEY_D, Defs.IN_UP: KEY_SPACE, Defs.IN_DOWN: KEY_S, Defs.IN_FIRE: KEY_SHIFT,
		Defs.IN_LOOK: KEY_Q, Defs.IN_SWAP: KEY_E},
	{Defs.IN_LEFT: KEY_KP_4, Defs.IN_RIGHT: KEY_KP_6, Defs.IN_UP: KEY_KP_0, Defs.IN_DOWN: KEY_KP_5,
		Defs.IN_FIRE: KEY_KP_ENTER, Defs.IN_LOOK: KEY_KP_PERIOD, Defs.IN_SWAP: KEY_KP_ADD},
]
## The keycode Windows reports for a numpad key while NumLock is off (the physical keycode stays the numpad key).
const NUMLOCK_OFF: Dictionary = {
	KEY_KP_8: KEY_UP, KEY_KP_4: KEY_LEFT, KEY_KP_5: KEY_CLEAR, KEY_KP_6: KEY_RIGHT, KEY_KP_0: KEY_INSERT,
	KEY_KP_PERIOD: KEY_DELETE,
}
## Arenas the match may use, the G1 slice's first (PLAN.md 4.2: Totem Ring), then world-B's developer arena.
const ARENAS: Array[StringName] = [&"arena_totem_ring", &"test_world_arena_flat"]
const REFEREE: String = "res://scripts/world/versus/referee.gd"

var _held: Dictionary = {}  # physical key -> the press event
var _numlock_on: bool = true
var _rounds: Array[Array] = []


func before_each() -> void:
	Settings.reset()
	Settings.set_value("controls/party_keyboard", "classic")
	GameInput.reset_slots()
	_numlock_on = true
	_rounds.clear()


func after_each() -> void:
	_release_all()
	if Events.round_ended.is_connected(_on_round_ended):
		Events.round_ended.disconnect(_on_round_ended)
	GameInput.clear_scripted()
	GameInput.reset_slots()
	Game.versus_match = null
	Sim.manual = false
	Sim.stop()
	if get_tree().current_scene != null:
		get_tree().current_scene.free()
		get_tree().current_scene = null
	Flow.current_screen = Flow.SCREEN_BOOT
	Flow.args = {}
	Flow.play_mode = Defs.GameMode.SINGLE
	Game.new_game(Defs.Difficulty.BEGINNER)
	Settings.reset()


# =================================================================================================================
# Arenas
# =================================================================================================================

## Every arena file is valid (no validator error; world-B's arena rules, LEVEL_DESIGN.md 15.8) and never part of a
## solo or co-op campaign.
func test_every_arena_is_valid() -> void:
	var validator: LevelValidator = LevelValidator.new()
	validator.add_folder(Levels.LEVEL_DIR)
	validator.run()
	var errors: PackedStringArray = PackedStringArray()
	var arenas: int = 0
	for level_id: StringName in Levels.all_ids():
		if not Levels.is_arena(level_id):
			continue
		arenas += 1
		for problem: Dictionary in validator.problems_of(Levels.get_level_path(level_id)):
			if int(problem["severity"]) == LevelValidator.ERROR:
				errors.append(LevelValidator.format_problem(problem))
		for book: int in [Levels.BOOK_1, Levels.BOOK_2]:
			for difficulty: int in [Defs.Difficulty.BEGINNER, Defs.Difficulty.EXPERT]:
				assert_false(Levels.get_campaign(difficulty, book).has(level_id), "%s is no map stop" % level_id)
				assert_false(Levels.get_coop_campaign(difficulty, book).has(level_id))
		assert_eq(Levels.level_for_mode(level_id, Defs.GameMode.SINGLE), &"", "%s is never played solo" % level_id)
	print("    arenas: %d" % arenas)
	assert_eq(errors, PackedStringArray(), "arena files: no error")


# =================================================================================================================
# The match
# =================================================================================================================

## The classic keys move exactly their own hero in a versus round, NumLock on and off.
func test_the_classic_keys_drive_exactly_their_own_hero() -> void:
	if not await _start_match(_match(60)):
		return
	var level: LevelBase = Game.level
	var p1: PlayerBase = level.get_hero(0)
	var p2: PlayerBase = level.get_hero(1)
	for numlock: bool in [true, false]:
		_numlock_on = numlock
		var state: String = "NumLock %s" % ("on" if numlock else "off")
		var x1: int = p1.sim_pos.x
		var x2: int = p2.sim_pos.x
		_drive(["R", ""], 8)
		assert_true(p1.sim_pos.x > x1, "%s: D walks P1 right" % state)
		assert_eq(p2.sim_pos.x, x2, "%s: P2 stands" % state)
		_drive(["", ""], 6)
		x1 = p1.sim_pos.x
		_drive(["", "L"], 8)
		assert_true(p2.sim_pos.x < x2, "%s: Num 4 walks P2 left" % state)
		assert_eq(p1.sim_pos.x, x1, "%s: P1 stands" % state)
		_drive(["", ""], 6)
		var y1: int = p1.sim_pos.y
		var y2: int = p2.sim_pos.y
		var flags: Array[PackedInt32Array] = _drive(["U", ""], 3)
		assert_true(p1.sim_pos.y < y1, "%s: Space jumps P1" % state)
		assert_eq(flags[1], PackedInt32Array([0, 0, 0]), "%s: P2 reads nothing" % state)
		_drive(["", ""], 40)
		flags = _drive(["", "U"], 3)
		assert_true(p2.sim_pos.y < y2, "%s: Num 0 jumps P2" % state)
		assert_eq(flags[0], PackedInt32Array([0, 0, 0]), "%s: P1 reads nothing" % state)
		_drive(["", ""], 40)
		for bit: int in [Defs.IN_FIRE, Defs.IN_DOWN, Defs.IN_LOOK, Defs.IN_SWAP]:
			var keys: String = Autoplay.flags_to_keys(bit)
			assert_eq(_drive([keys, ""], 1)[0][0], bit, "%s: P1's %s key" % [state, keys])
			_drive(["", ""], 14)
			assert_eq(_drive(["", keys], 1)[1][0], bit, "%s: P2's %s key" % [state, keys])
			_drive(["", ""], 14)
	assert_false(GameInput.is_scripted(), "no script drove a hero")


## DESIGN.md E.9: a whole Grub Stack match of one round on one keyboard, from Flow.start_versus to the result, every
## input a physical key of the classic layout. P1 works the floor spot nearest to his spawn with his club for two
## thirds of the round, then waits in the middle; P2 only waits. P1 wins the round on his stack (or, if the arena gave
## nobody food, by grabbing the Golden Drumstick that the tie drops in the middle), and the match records it.
func test_a_two_player_match_on_the_classic_keys() -> void:
	var versus_match: VersusMatch = _match(10)
	if not await _start_match(versus_match):
		return
	var level: LevelBase = Game.level
	var p1: PlayerBase = level.get_hero(0)
	var referee: VersusReferee = VersusReferee.find(level)
	var middle: int = VersusArena.view_rect().get_center().x
	var ticks: int = 0
	var limit: int = versus_match.round_ticks() + 1200
	var golden: bool = false
	var score: int = 0
	var mismatches: int = 0
	# The floor spot nearest to P1's spawn: he works it for most of the round, then waits in the middle.
	var spot_x: int = middle
	var nearest: int = 1 << 20
	for entity: SimEntity in level.get_kind(Defs.Kind.HITTABLE):
		if absi(entity.sim_pos.x - p1.sim_pos.x) < nearest:
			nearest = absi(entity.sim_pos.x - p1.sim_pos.x)
			spot_x = entity.sim_pos.x - 14
	var work_until: int = versus_match.round_ticks() * 2 / 3
	while _rounds.is_empty() and ticks < limit and Game.level == level:
		var target: int = spot_x if ticks < work_until else middle
		var keys: String = ""
		if absi(p1.sim_pos.x - target) > 4:
			keys = "R" if p1.sim_pos.x < target else "L"
		elif ticks % 12 < 3:
			keys = "F" if ticks % 24 < 12 else "DF"
		var sampled: Array[PackedInt32Array] = _drive([keys, ""], 1)
		# (The gong's tick hands the inputs back to the front end: from then on the slots read nothing.)
		if _rounds.is_empty() and not sampled[0].is_empty() \
				and (sampled[0][0] != GameInput.keys_to_flags(keys) or sampled[1][0] != 0):
			mismatches += 1
			print("    tick %d: keys '%s', P1 read %d, P2 read %d" % [ticks, keys, sampled[0][0], sampled[1][0]])
		if referee != null and is_instance_valid(referee):
			golden = golden or referee.phase == VersusReferee.PHASE_GOLDEN
			score = maxi(score, referee.score_of(0))
		ticks += 1
	_release_all()
	print("    match: %d ticks, rounds %s, wins %s, P1's best score %d, golden drumstick %s" % [ticks, str(_rounds),
			str(versus_match.round_wins), score, golden])
	assert_eq(mismatches, 0, "every tick P1 read exactly his keys and P2 nothing")
	assert_eq(_rounds.size(), 1, "the gong ended the round after %d ticks (Events.round_ended once)" % ticks)
	if _rounds.is_empty():
		return
	assert_eq(_rounds[0][1], PackedInt32Array([0]), "P1 won the round")
	assert_eq(versus_match.history.size(), 1, "the match recorded the round (Flow.end_round)")
	assert_true(versus_match.is_over(), "one round win ends this match")
	assert_eq(versus_match.leaders(), PackedInt32Array([0]), "P1 leads the match")
	assert_false(GameInput.is_scripted(), "no script drove a hero")


# =================================================================================================================
# Helpers
# =================================================================================================================

## A Grub Stack match of one round of `seconds` for two humans on the classic keyboard halves, on the first arena of
## ARENAS that exists (null when none does yet).
func _match(seconds: int) -> VersusMatch:
	var versus_match: VersusMatch = VersusMatch.new()
	versus_match.mode = Defs.VersusMode.GRUB_STACK
	versus_match.rounds_to_win = 1
	versus_match.round_seconds = seconds
	versus_match.crates = false
	versus_match.preset = VersusMatch.Preset.CLASSIC
	for arena: StringName in ARENAS:
		if Levels.has_level(arena):
			versus_match.arena = arena
			break
	assert_eq(versus_match.seat_human(InputSlot.keyboard(Defs.InputSlotKind.KEYBOARD_LEFT)), 0, "P1 on the left half")
	assert_eq(versus_match.seat_human(InputSlot.keyboard(Defs.InputSlotKind.KEYBOARD_RIGHT)), 1, "P2 on the numpad")
	versus_match.ready_all()
	return versus_match


## Start the match through Flow and let the referee's countdown pass (keys pressed meanwhile do nothing). False when the
## arena or the referee is not there yet.
func _start_match(versus_match: VersusMatch) -> bool:
	assert_true(Levels.has_level(versus_match.arena), "an arena to play on (%s)" % ", ".join(ARENAS))
	assert_true(ResourceLoader.exists(REFEREE), "the referee (world-B, PLAN.md P1.7)")
	if not Levels.has_level(versus_match.arena) or not ResourceLoader.exists(REFEREE):
		return false
	Events.round_ended.connect(_on_round_ended)
	Flow.instant_transitions = true
	Sim.manual = true
	await _frames(1)
	assert_true(Flow.start_versus(versus_match, 7), "the match starts")
	for i: int in 12:
		await _frames(1)
		if not Flow.busy and Flow.current_screen == Flow.SCREEN_LEVEL and Game.level != null:
			break
	assert_eq(Flow.current_screen, Flow.SCREEN_LEVEL, "the arena runs")
	var level: Level = Game.level as Level
	if level == null:
		return false
	level.set_view_size(Vector2i(Tuning.VIEW_W, Tuning.VIEW_H) * Tuning.ART_SCALE)
	assert_eq(Game.mode, Defs.GameMode.VERSUS)
	assert_eq(level.hero_count(), 2, "two heroes")
	assert_eq(GameInput.get_slot(0).kind, Defs.InputSlotKind.KEYBOARD_LEFT, "P1 reads the left half")
	assert_eq(GameInput.get_slot(1).kind, Defs.InputSlotKind.KEYBOARD_RIGHT, "P2 reads the numpad")
	var referee: VersusReferee = VersusReferee.find(level)
	assert_not_null(referee, "the arena has its referee")
	if referee == null:
		return false
	var waited: int = 0
	while referee.phase == VersusReferee.PHASE_INTRO and waited < 400:
		_drive(["", ""], 1)
		waited += 1
	assert_eq(referee.phase, VersusReferee.PHASE_PLAY, "the countdown ended after %d ticks" % waited)
	return referee.phase == VersusReferee.PHASE_PLAY


## Hold the keys of `keys` (one key string per player, letters L R U D F K S) for `ticks` ticks; returns the flags
## each slot sampled, per tick.
func _drive(keys: Array, ticks: int) -> Array[PackedInt32Array]:
	var sampled: Array[PackedInt32Array] = [PackedInt32Array(), PackedInt32Array()]
	for slot: int in 2:
		var wanted: int = GameInput.keys_to_flags(str(keys[slot]))
		var layout: Dictionary = CLASSIC[slot]
		for bit: int in layout:
			_set_key(layout[bit], (wanted & bit) != 0)
	Input.flush_buffered_events()
	for i: int in ticks:
		if Game.level == null or not Sim.running:
			break
		Sim.step(1)
		for slot: int in 2:
			sampled[slot].append(GameInput.get_flags(slot))
	return sampled


func _set_key(physical: Key, down: bool) -> void:
	if down == _held.has(physical):
		return
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = physical
	event.keycode = physical if _numlock_on else NUMLOCK_OFF.get(physical, physical)
	event.pressed = down
	Input.parse_input_event(event)
	if down:
		_held[physical] = event
	else:
		_held.erase(physical)


func _release_all() -> void:
	for physical: Key in _held.keys():
		_set_key(physical, false)
	Input.flush_buffered_events()


func _on_round_ended(round_index: int, winners: PackedInt32Array) -> void:
	_rounds.append([round_index, winners])


func _frames(count: int) -> void:
	for i: int in count:
		await get_tree().process_frame
