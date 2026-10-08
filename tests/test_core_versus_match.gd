extends TestCase
## VersusMatch (docs/expansion/PLAN.md P1.1, DESIGN.md E.3-E.8, TECH_AUDIT.md 4.9): seats, rules, the round record, the
## arena picks of its own random sequence, spawn rotation, and the awards of the results screen.

const ARENA_A: StringName = &"zz_arena_a"
const ARENA_B: StringName = &"zz_arena_b"
## A third arena. Until cut 3 (DESIGN.md G60) an arena of this id waited for 20 paintings; no arena is locked in 2.0.
const ARENA_C: StringName = &"arena_cloud_top"

var _added: Array[StringName] = []


func before_each() -> void:
	Settings.reset()
	Save.reset()


func after_each() -> void:
	if not _added.is_empty():
		_added.clear()
		Levels.rescan()
	Settings.reset()
	VersusMatch.bot_factory = Callable()


func _add_arena(id: StringName, players: int, modes: String) -> void:
	Levels._meta[id] = {"id": String(id), "kind": "arena", "players": players, "modes": modes}
	Levels._paths[id] = "res://levels/test_core_party.lvl"
	_added.append(id)
	Levels._index_campaign()


func _two_humans() -> VersusMatch:
	var versus_match: VersusMatch = VersusMatch.new()
	versus_match.seat_human(InputSlot.keyboard(Defs.InputSlotKind.KEYBOARD_LEFT))
	versus_match.seat_human(InputSlot.keyboard(Defs.InputSlotKind.KEYBOARD_RIGHT))
	return versus_match


func test_seats_humans_bots_and_compaction() -> void:
	var versus_match: VersusMatch = VersusMatch.new()
	var changes: Array[int] = [0]
	versus_match.seats_changed.connect(func() -> void: changes[0] += 1)
	assert_eq(versus_match.player_count(), 0)
	assert_eq(versus_match.seat_human(InputSlot.pad(3)), 0, "the first free seat")
	assert_eq(versus_match.seat_human(InputSlot.pad(4), 2), 2, "a chosen seat")
	assert_eq(versus_match.seat_human(InputSlot.pad(5), 2), -1, "a taken seat")
	assert_eq(versus_match.seat_bot(Defs.BotLevel.ROOKIE), 1, "Add CPU takes the first free seat")
	assert_true(versus_match.is_bot(1))
	assert_eq(versus_match.get_seat(1).bot_level, Defs.BotLevel.ROOKIE)
	assert_eq(versus_match.player_count(), 3)
	assert_eq(versus_match.human_count(), 2)
	assert_eq(versus_match.seated_slots(), PackedInt32Array([0, 1, 2]))
	versus_match.unseat(1)
	assert_eq(versus_match.seated_slots(), PackedInt32Array([0, 2]))
	versus_match.get_seat(2).palette = &"pink"
	assert_true(versus_match.compact_seats(), "a gap closes")
	assert_eq(versus_match.seated_slots(), PackedInt32Array([0, 1]))
	assert_eq(versus_match.get_seat(1).input.device_id, 4, "the seat moved with its input")
	assert_eq(versus_match.get_seat(1).palette, &"pink", "... and its look")
	assert_false(versus_match.compact_seats(), "nothing to close")
	assert_eq(versus_match.seat_bot(), 2)
	assert_eq(versus_match.seat_bot(), 3)
	assert_eq(versus_match.seat_bot(), -1, "four seats at most")
	assert_true(changes[0] >= 6, "every change is announced")


func test_a_match_starts_with_two_ready_players() -> void:
	var versus_match: VersusMatch = VersusMatch.new()
	versus_match.seat_human(InputSlot.pad(0))
	assert_false(versus_match.can_start(), "one player is no match")
	versus_match.seat_bot()
	assert_false(versus_match.can_start(), "a human must hold Strike first")
	versus_match.get_seat(0).ready = true
	assert_true(versus_match.can_start(), "a human against a bot")
	versus_match.seat_bot()
	versus_match.get_seat(0).team = 1
	versus_match.get_seat(1).team = 1
	versus_match.get_seat(2).team = 2
	assert_true(versus_match.is_team_match())
	assert_false(versus_match.can_start(), "2v1 is no 2v2")
	versus_match.seat_bot()
	versus_match.get_seat(3).team = 2
	assert_true(versus_match.can_start())
	assert_eq(versus_match.teammates(2), PackedInt32Array([2, 3]))
	versus_match.get_seat(3).team = 0
	assert_false(versus_match.is_team_match(), "one free-for-all seat: no teams")
	assert_eq(versus_match.teammates(2), PackedInt32Array([2]))


func test_rules_defaults_and_overrides() -> void:
	var versus_match: VersusMatch = _two_humans()
	assert_eq(versus_match.mode, Defs.VersusMode.GRUB_STACK, "Grub Stack is the flagship")
	assert_eq(versus_match.preset, VersusMatch.Preset.FEAST, "Feast is the default preset")
	assert_eq(versus_match.round_wins_needed(), VersusTuning.STACK_ROUND_WINS)
	assert_eq(versus_match.round_wins_needed(Defs.VersusMode.LAST_CAVEMAN), VersusTuning.LCS_ROUND_WINS)
	assert_eq(versus_match.round_wins_needed(Defs.VersusMode.HOT_ROCK), VersusTuning.HOT_ROCK_ROUND_WINS)
	assert_eq(versus_match.round_wins_needed(Defs.VersusMode.CLUBBALL), 1, "one Clubball game to 5 goals")
	assert_eq(versus_match.round_ticks(Defs.VersusMode.GRUB_STACK), VersusTuning.STACK_ROUND_TICKS_2P, "60 s with two")
	versus_match.seat_bot()
	assert_eq(versus_match.round_ticks(Defs.VersusMode.GRUB_STACK), VersusTuning.STACK_ROUND_TICKS, "90 s with three")
	assert_eq(versus_match.round_ticks(Defs.VersusMode.CLUBBALL), VersusTuning.CLUBBALL_MATCH_TICKS)
	assert_eq(versus_match.round_ticks(Defs.VersusMode.LAST_CAVEMAN), 0, "the last one standing ends it")
	versus_match.round_seconds = 30
	versus_match.rounds_to_win = 2
	assert_eq(versus_match.round_ticks(), Tuning.seconds_to_ticks(30.0))
	assert_eq(versus_match.round_wins_needed(), 2)
	assert_eq(versus_match.crate_period_ticks(), VersusTuning.CRATE_PERIOD_TICKS)
	versus_match.preset = VersusMatch.Preset.MAYHEM
	assert_eq(versus_match.crate_period_ticks(), VersusTuning.MAYHEM_CRATE_PERIOD_TICKS)
	versus_match.preset = VersusMatch.Preset.CLASSIC
	assert_eq(versus_match.crate_period_ticks(), 0, "Classic: club only, no crates")
	versus_match.preset = VersusMatch.Preset.FEAST
	versus_match.crates = false
	assert_eq(versus_match.crate_period_ticks(), 0)
	versus_match.variants = PackedStringArray(["big_bounce"])
	assert_true(versus_match.has_variant(&"big_bounce"))
	assert_false(versus_match.has_variant(&"slippery"))


func test_the_last_rules_are_remembered() -> void:
	var versus_match: VersusMatch = _two_humans()
	versus_match.mode = Defs.VersusMode.HOT_ROCK
	versus_match.preset = VersusMatch.Preset.MAYHEM
	versus_match.rounds_to_win = 4
	versus_match.round_seconds = 75
	versus_match.crates = false
	versus_match.weapons = &"club"
	versus_match.variants = PackedStringArray(["gusty", "slippery"])
	versus_match.sudden_death = true
	versus_match.stock = true
	versus_match.arena = VersusMatch.ARENA_PARTY_MIX
	versus_match.remember_rules()
	var again: VersusMatch = VersusMatch.from_settings()
	assert_eq(again.rules_to_dict(), versus_match.rules_to_dict(), "the rules come back as they were")
	assert_eq(again.player_count(), 0, "seats are not remembered")
	var damaged: VersusMatch = VersusMatch.new()
	damaged.rules_from_dict({"mode": "egg_heist", "preset": 7, "rounds_to_win": "x", "crates": "yes",
			"weapons": "lasers", "variants": 3, "arena": "no_such_arena"})
	assert_eq(damaged.mode, Defs.VersusMode.GRUB_STACK, "a second-wave or unknown mode keeps the default")
	assert_eq(damaged.preset, VersusMatch.Preset.FEAST)
	assert_eq(damaged.rounds_to_win, 0)
	assert_true(damaged.crates)
	assert_eq(damaged.weapons, &"all")
	assert_eq(damaged.variants.size(), 0)
	assert_eq(damaged.arena, VersusMatch.ARENA_RANDOM, "an unknown arena: random")


func test_rounds_wins_history_and_the_end_of_a_match() -> void:
	var versus_match: VersusMatch = _two_humans()
	versus_match.seat_bot()
	versus_match.begin_match(77)
	assert_eq(versus_match.round_seed(), VersusTuning.round_seed(77, 0))
	assert_false(versus_match.record_round(PackedInt32Array([0])), "no round was open")
	versus_match.begin_round(&"some_arena")
	assert_eq(versus_match.round_mode, Defs.VersusMode.GRUB_STACK)
	assert_true(versus_match.record_round(PackedInt32Array([2, 2, 3])), "unseated and repeated winners are dropped")
	assert_eq(versus_match.history[0]["winners"], PackedInt32Array([2]))
	assert_eq(versus_match.round_index, 1)
	assert_eq(versus_match.round_seed(), VersusTuning.round_seed(77, 1), "every round its own seed")
	for round_winner: int in [2, 0, 0, 0]:
		assert_false(versus_match.is_over())
		versus_match.begin_round(&"some_arena")
		versus_match.record_round(PackedInt32Array([round_winner]))
	assert_true(versus_match.is_over(), "slot 0 won three rounds")
	assert_eq(versus_match.leaders(), PackedInt32Array([0]))
	assert_eq(versus_match.round_wins[0], 3)
	assert_eq(versus_match.round_wins[2], 2)
	var runs: Array[PlayerRun] = [PlayerRun.new(0), PlayerRun.new(1), PlayerRun.new(2)]
	versus_match.finish(runs)
	assert_eq(runs[0].comeback, 2, "slot 0 trailed slot 2 by two rounds and won")
	assert_eq(runs[2].comeback, 0, "only a winner comes back")
	versus_match.rematch()
	assert_eq(versus_match.match_seed, 78, "a rematch plays a new seed")
	assert_eq(versus_match.round_index, 0)
	assert_eq(versus_match.round_wins[0], 0)
	assert_eq(versus_match.history.size(), 0)
	assert_eq(versus_match.player_count(), 3, "same players")


func test_a_draw_and_team_wins() -> void:
	var versus_match: VersusMatch = _two_humans()
	versus_match.begin_match(1)
	versus_match.begin_round(&"a")
	versus_match.record_round(PackedInt32Array())
	assert_eq(versus_match.round_wins, PackedInt32Array([0, 0, 0, 0]), "a draw gives nobody a round")
	assert_eq(versus_match.leaders().size(), 0)
	versus_match.seat_bot()
	versus_match.seat_bot()
	for slot: int in 4:
		versus_match.get_seat(slot).team = 1 if slot < 2 else 2
	versus_match.rounds_to_win = 1
	versus_match.begin_round(&"a")
	versus_match.record_round(PackedInt32Array([2, 3]))
	assert_true(versus_match.is_over())
	assert_eq(versus_match.leaders(), PackedInt32Array([2, 3]), "both of a team win")


func test_spawns_rotate_and_bots_have_their_own_seeds() -> void:
	var versus_match: VersusMatch = _two_humans()
	versus_match.seat_bot()
	versus_match.begin_match(5)
	assert_eq([versus_match.spawn_index(0), versus_match.spawn_index(1), versus_match.spawn_index(2)], [1, 2, 3])
	versus_match.begin_round(&"a")
	versus_match.record_round(PackedInt32Array())
	assert_eq([versus_match.spawn_index(0), versus_match.spawn_index(1), versus_match.spawn_index(2)], [2, 3, 1],
			"the spawns rotate every round")
	assert_ne(versus_match.bot_seed(1), versus_match.bot_seed(2), "every bot its own seed")
	var before: int = versus_match.bot_seed(2)
	versus_match.begin_round(&"a")
	versus_match.record_round(PackedInt32Array())
	assert_ne(versus_match.bot_seed(2), before, "... per round, from the match seed")


func test_arena_picks_follow_the_match_seed_and_the_unlocks() -> void:
	_add_arena(ARENA_A, 4, "grub_stack,hot_rock")
	_add_arena(ARENA_B, 2, "clubball")
	_add_arena(ARENA_C, 4, "grub_stack")
	_add_arena(&"test_zz_dev_arena", 4, "grub_stack")
	var versus_match: VersusMatch = _two_humans()
	for id: StringName in VersusMatch.available_arenas(2):
		assert_false(String(id).begins_with("test_"), "a developer arena is never offered: %s" % id)
	versus_match.arena = &"test_zz_dev_arena"
	assert_eq(versus_match.arena_for_round(0), &"test_zz_dev_arena", "... but plays when chosen by id")
	versus_match.arena = VersusMatch.ARENA_RANDOM
	var grub: Array[StringName] = VersusMatch.available_arenas(2, Defs.VersusMode.GRUB_STACK)
	assert_true(grub.has(ARENA_A))
	assert_false(grub.has(ARENA_B), "it does not list Grub Stack")
	assert_true(grub.has(ARENA_C), "no arena waits for paintings (G60: cut 3 left no painting arena)")
	assert_false(VersusMatch.available_arenas(3, Defs.VersusMode.CLUBBALL).has(ARENA_B), "built for two")
	assert_true(VersusMatch.LOCKED_ARENAS.is_empty(), "G60")
	for id: StringName in VersusMatch.LOCKED_ARENAS:
		assert_true(Save.UNLOCK_PAINTINGS.has(VersusMatch.LOCKED_ARENAS[id]), "%s waits for a Save reward" % id)
	versus_match.arena = ARENA_B
	assert_eq(versus_match.arena_for_round(3), ARENA_B, "a chosen arena every round")
	versus_match.arena = &"no_such_arena"
	assert_eq(versus_match.arena_for_round(0), &"")
	versus_match.arena = VersusMatch.ARENA_RANDOM
	versus_match.begin_match(11)
	var picks: Array[StringName] = []
	for round_index: int in 6:
		var pick: StringName = versus_match.arena_for_round(round_index)
		assert_true(VersusMatch.available_arenas(2, Defs.VersusMode.GRUB_STACK).has(pick), "%s fits" % pick)
		picks.append(pick)
	var again: Array[StringName] = []
	for round_index: int in 6:
		again.append(versus_match.arena_for_round(round_index))
	assert_eq(again, picks, "the same seed picks the same arenas")
	var state: int = Sim.rng.get_state()
	versus_match.arena = VersusMatch.ARENA_PARTY_MIX
	for round_index: int in 8:
		var arena_id: StringName = versus_match.arena_for_round(round_index)
		var round_mode: int = versus_match.mode_for_round(round_index, arena_id)
		assert_true(VersusMatch.arena_modes(arena_id).has(round_mode), "Party Mix plays a mode %s supports" % arena_id)
	assert_eq(Sim.rng.get_state(), state, "picks never draw from Sim.rng")
	assert_eq(VersusMatch.arena_modes(ARENA_A), [Defs.VersusMode.GRUB_STACK, Defs.VersusMode.HOT_ROCK] as Array[int])


func test_awards_one_to_three_each() -> void:
	var versus_match: VersusMatch = _two_humans()
	versus_match.seat_bot()
	versus_match.seat_bot()
	var runs: Array[PlayerRun] = []
	for slot: int in Defs.MAX_PLAYERS:
		runs.append(PlayerRun.new(slot))
	runs[0].best_stack = 30
	runs[0].stolen = 9
	runs[0].food = 40
	runs[0].dropped = 12
	runs[0].hits = 9
	runs[1].clangs = 4
	runs[1].hits = 3
	runs[2].hits = 5
	runs[2].bonks = 1
	runs[3].hits = 7
	var awards: Dictionary = versus_match.hand_out_awards(runs)
	assert_eq(awards.size(), 4, "every player gets the companion's visit")
	for slot: int in 4:
		var list: Array[StringName] = awards[slot]
		assert_true(list.size() >= VersusTuning.AWARDS_MIN and list.size() <= VersusTuning.AWARDS_MAX,
				"slot %d gets 1-3 awards (%s)" % [slot, list])
	assert_eq(awards[0], [&"leaning_tower", &"pickpocket", &"glutton"] as Array[StringName], "three at most, in order")
	assert_true((awards[1] as Array).has(&"clang_master"))
	assert_true((awards[1] as Array).has(&"pacifist"), "the fewest hits")
	assert_true((awards[2] as Array).has(&"head_case"))
	assert_eq(awards[3], [&"pacifist"] as Array[StringName], "nobody leaves empty-handed: the closest award")
