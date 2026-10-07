extends TestCase
## PlayerRun statistics for the co-op tally medals and the versus awards (DESIGN.md D.11, E.8; PLAN.md P1.1), and the
## Game members of a party that changes during a run (Game.set_party, party_runs, per-stage co-op statistics).


func after_each() -> void:
	Game.new_game(Defs.Difficulty.BEGINNER)


func test_every_statistic_has_a_counter_and_resets() -> void:
	var run: PlayerRun = PlayerRun.new(1)
	for stat: StringName in PlayerRun.STATS:
		assert_true(run.get(stat) is int, "%s is an int counter" % stat)
		run.set(stat, 5)
		assert_eq(run.get_stat(stat), 5, stat)
	run.palette = &"blue"
	run.reset_stats()
	for stat: StringName in PlayerRun.STATS:
		assert_eq(run.get_stat(stat), 0, "%s is zeroed" % stat)
	assert_eq(run.palette, &"blue", "the look is not a statistic")
	assert_eq(run.get_stat(&"hearts"), 0, "only statistics are read by name")
	for table: Array[Dictionary] in [PlayerRun.COOP_MEDALS, PlayerRun.VERSUS_AWARDS]:
		for award: Dictionary in table:
			for stat: Variant in award["stats"]:
				assert_true(PlayerRun.STATS.has(stat), "%s counts %s" % [award["id"], stat])


func test_the_longest_values_keep_their_best() -> void:
	var run: PlayerRun = PlayerRun.new(0)
	run.note_chain(3)
	run.note_chain(2)
	run.note_stack(14)
	run.note_stack(9)
	run.note_shot(-120)
	run.note_shot(40)
	assert_eq(run.best_chain, 3)
	assert_eq(run.best_stack, 14)
	assert_eq(run.best_shot, 120, "a shot to the left is as long")


func test_coop_medals_go_to_the_most_and_ties_share() -> void:
	var p1: PlayerRun = PlayerRun.new(0)
	var p2: PlayerRun = PlayerRun.new(1)
	var runs: Array[PlayerRun] = [p1, p2]
	assert_eq(PlayerRun.medals(runs), {}, "nobody earns a medal with nothing done")
	p1.food = 12
	p2.food = 7
	p1.best_chain = 3
	p2.best_chain = 3
	p2.revives = 2
	p1.plates = 1
	p2.pushes = 1
	p2.deaths = 1
	p1.hurts = 3
	var medals: Dictionary = PlayerRun.medals(runs)
	assert_eq(medals[&"most_food"], PackedInt32Array([0]))
	assert_eq(medals[&"best_bounce_chain"], PackedInt32Array([0, 1]), "a tie shares the medal")
	assert_eq(medals[&"hatchling"], PackedInt32Array([1]))
	assert_eq(medals[&"strongman"], PackedInt32Array([0, 1]), "plates and pushes count together")
	assert_eq(medals[&"clumsiest"], PackedInt32Array([0]), "downs and hits taken")
	assert_false(medals.has(&"slugger"))


func test_a_fewest_award_needs_a_difference() -> void:
	var pacifist: Dictionary = PlayerRun.VERSUS_AWARDS[-1]
	assert_eq(pacifist["id"], &"pacifist")
	var a: PlayerRun = PlayerRun.new(0)
	var b: PlayerRun = PlayerRun.new(2)
	var runs: Array[PlayerRun] = [a, b]
	assert_eq(PlayerRun.award_winners(runs, pacifist).size(), 0, "nobody hit anybody: no pacifist")
	b.hits = 4
	assert_eq(PlayerRun.award_winners(runs, pacifist), PackedInt32Array([0]))
	var none: Array[PlayerRun] = []
	assert_eq(PlayerRun.award_winners(none, pacifist).size(), 0)


func test_coop_statistics_count_one_stage() -> void:
	Game.start_run(Defs.Difficulty.BEGINNER, Defs.GameMode.COOP, 2)
	Game.runs[0].food = 4
	Game.runs[1].revives = 1
	Game.begin_level(&"test_example", true)
	assert_eq(Game.runs[0].food, 4, "a linked sub-stage carries them on")
	Game.begin_level(&"test_example")
	assert_eq(Game.runs[0].food, 0, "a new stage counts afresh")
	assert_eq(Game.runs[1].revives, 0)
	Game.new_game(Defs.Difficulty.BEGINNER)
	Game.runs[0].kills = 3
	Game.begin_level(&"test_example")
	assert_eq(Game.runs[0].kills, 3, "single-player never resets them in begin_level")


func test_a_player_joins_and_leaves_a_run() -> void:
	Game.new_game(Defs.Difficulty.EXPERT)
	Game.add_score(1500)
	Game.runs[1].hearts = 1
	Game.runs[1].set_weapon(Defs.Weapon.AXE)
	Game.runs[1].palette = &"green"
	var energy: Array = []
	var on_energy: Callable = func(slot: int, hearts: int, _bones: int) -> void: energy.append([slot, hearts])
	Game.run_energy_changed.connect(on_energy)
	Game.set_party(Defs.GameMode.COOP, 2)
	Game.run_energy_changed.disconnect(on_energy)
	assert_eq(Game.mode, Defs.GameMode.COOP)
	assert_eq(Game.party, 2)
	assert_eq(Game.score, 1500, "the score is kept")
	assert_eq(Game.runs[1].hearts, Tuning.ENERGY_START, "the new hero starts fresh")
	assert_eq(Game.runs[1].weapon, Defs.Weapon.CLUB)
	assert_eq(Game.runs[1].palette, &"green", "his colour is kept")
	assert_eq(energy, [[1, Tuning.ENERGY_START]], "P2's panel hears about it")
	assert_eq(Game.party_runs().size(), 2)
	assert_eq(Game.party_runs()[1], Game.runs[1], "the shared runs, not copies")
	Game.runs[1].hearts = 2
	Game.set_party(Defs.GameMode.SINGLE, 1)
	assert_eq(Game.party, 1)
	assert_eq(Game.mode, Defs.GameMode.SINGLE)
	assert_eq(Game.runs[1].hearts, 2, "a leaving hero's run is left alone")
	assert_eq(Game.party_runs(), [Game.runs[0]] as Array[PlayerRun])


## A stand-in hero for Defs.hitter_slot (duck-typed like the real PlayerBase: get_kind, slot, curl, ball_batter).
class FakeHero:
	extends RefCounted
	var slot: int = 0
	var curl: int = 0
	var ball_batter: Object = null

	func get_kind() -> int:
		return Defs.Kind.PLAYER


func test_a_batted_ball_credits_its_batter() -> void:
	var ball: FakeHero = FakeHero.new()
	ball.slot = 1
	var batter: FakeHero = FakeHero.new()
	batter.slot = 0
	assert_eq(Defs.hitter_slot(ball), 1, "a hero hits for himself")
	ball.curl = Defs.CURL_BALL_STATE
	assert_eq(Defs.hitter_slot(ball), 1, "a ball without a batter is his own")
	ball.ball_batter = batter
	assert_eq(Defs.hitter_slot(ball), 0, "a batted ball (PHYSICS.md C.11) credits the batter")
	ball.curl = 1
	assert_eq(Defs.hitter_slot(ball), 1, "curled but not flying: his own")
	assert_eq(Defs.CURL_BALL_STATE, PlayerBase.CURL_BALL, "the mirror of PlayerBase.CURL_BALL")
