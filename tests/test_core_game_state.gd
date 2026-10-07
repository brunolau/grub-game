extends TestCase
## Game (run state): score, lives, energy, letters, completion, tally (GAMEPLAY.md 2-4, PHYSICS.md 10.2).


func before_each() -> void:
	Game.new_game(Defs.Difficulty.BEGINNER)
	Game.begin_level(&"test")


func test_new_game_defaults() -> void:
	assert_eq(Game.score, 0)
	assert_eq(Game.lives, Tuning.LIVES_START)
	assert_eq(Game.hearts, Tuning.ENERGY_START)
	assert_eq(Game.bones, 0)
	assert_eq(Game.weapon, Defs.Weapon.CLUB)
	assert_eq(Game.letters, 0)
	assert_false(Game.has_glider)
	assert_false(Game.has_checkpoint)
	assert_eq(Game.level_id, &"test")
	assert_eq(Game.difficulty, Defs.Difficulty.BEGINNER)


func test_score_and_extra_lives() -> void:
	var awarded: Array[int] = []
	var on_life: Callable = func(lives: int) -> void: awarded.append(lives)
	Game.extra_life_awarded.connect(on_life)
	Game.add_score(249900)
	assert_eq(Game.lives, 2)
	Game.add_score(100)
	assert_eq(Game.lives, 3, "one extra life per 250 000 points")
	Game.add_score(500000)
	assert_eq(Game.lives, 5, "a big score can cross several thresholds")
	Game.add_score(-50)
	assert_eq(Game.score, 750000, "negative amounts are ignored")
	Game.extra_life_awarded.disconnect(on_life)
	assert_eq(awarded, [3, 4, 5] as Array[int])
	Game.lives = Tuning.LIVES_MAX
	Game.add_lives(1)
	assert_eq(Game.lives, Tuning.LIVES_MAX, "lives are capped at 99")


func test_three_hits_survive_the_fourth_kills() -> void:
	assert_false(Game.lose_heart())
	assert_false(Game.lose_heart())
	assert_false(Game.lose_heart())
	assert_eq(Game.hearts, 0)
	assert_true(Game.lose_heart(), "a hit at 0 hearts kills (PHYSICS.md 10.2)")


func test_lives_and_game_over() -> void:
	assert_true(Game.lose_life())
	assert_true(Game.lose_life())
	assert_eq(Game.lives, 0)
	assert_false(Game.lose_life(), "dying with the counter at 0 is game over")


func test_six_bones_make_a_heart() -> void:
	Game.lose_heart()
	assert_eq(Game.add_bones(5), 0)
	assert_eq(Game.hearts, 2)
	assert_eq(Game.add_bones(1), 1, "the sixth bone restores a heart")
	assert_eq(Game.hearts, 3)
	assert_eq(Game.bones, 0)
	assert_eq(Game.add_bones(6), 0, "no heart above the maximum")
	assert_eq(Game.hearts, Tuning.ENERGY_START)
	assert_false(Game.add_heart(), "a heart item stays in place at full energy")
	Game.lose_heart()
	assert_true(Game.add_heart())


func test_boss_hits_cost_one_bone_each() -> void:
	for i: int in Tuning.BONES_PER_HEART:
		assert_false(Game.lose_bone())
	assert_eq(Game.hearts, 2, "six boss hits = one heart")
	assert_eq(Game.bones, 0)
	assert_eq(Game.scatter_energy(), 12, "skull: all energy is thrown out as bones")
	assert_eq(Game.hearts, 0)
	assert_true(Game.lose_bone(), "nothing left: dead")


func test_letters_and_feast_kit() -> void:
	var completed: Array[bool] = []
	var on_done: Callable = func() -> void: completed.append(true)
	Game.letters_completed.connect(on_done)
	for i: int in Tuning.LETTER_COUNT - 1:
		assert_false(Game.collect_letter(i))
	assert_eq(Game.letters, 0b01111)
	assert_true(Game.collect_letter(Tuning.LETTER_COUNT - 1))
	assert_eq(Game.letters, 0, "the set is cleared when completed")
	Game.letters_completed.disconnect(on_done)
	assert_eq(completed.size(), 1)
	assert_false(Game.collect_feast_piece(0))
	assert_false(Game.collect_feast_piece(0), "the same piece twice does not complete the kit")
	assert_false(Game.collect_feast_piece(2))
	assert_true(Game.collect_feast_piece(1))
	assert_eq(Game.feast_kit, 0)


func test_completion_percentage() -> void:
	assert_eq(Game.completion_percent(), 100, "an empty level counts as complete")
	Game.add_completion_totals(3, 5)
	assert_eq(Game.completion_percent(), 0)
	Game.count_spot_opened()
	Game.count_item_collected()
	assert_eq(Game.completion_percent(), 25)
	for i: int in 6:
		Game.count_item_collected()
	assert_eq(Game.completion_percent(), 100, "never above 100")


func test_respawn_keeps_progress_but_clears_the_tally() -> void:
	Game.add_score(1200)
	Game.set_weapon(Defs.Weapon.AXE)
	Game.set_glider(true)
	Game.collect_letter(2)
	Game.add_tally_item(&"items/food", 3, 100)
	Game.add_tally_item(&"items/treasure", 8, 5000)
	assert_eq(Game.tally_count(), 2)
	Game.lose_heart()
	Game.set_checkpoint(Vector2i(320, 176))
	Game.on_respawn()
	assert_eq(Game.hearts, Tuning.ENERGY_START)
	assert_eq(Game.tally_count(), 0, "dying clears the end-of-level double")
	assert_false(Game.has_glider, "the glider is lost")
	assert_eq(Game.weapon, Defs.Weapon.AXE, "the weapon is kept")
	assert_eq(Game.score, 1200)
	assert_eq(Game.letters, 0b00100)
	assert_true(Game.has_checkpoint)
	assert_eq(Game.checkpoint_pos, Vector2i(320, 176))


func test_begin_level_can_carry_progress() -> void:
	Game.add_completion_totals(2, 2)
	Game.count_spot_opened()
	Game.add_tally_item(&"items/food", 0, 100)
	Game.set_checkpoint(Vector2i(1, 1))
	Game.unlock_exit()
	Game.begin_level(&"bonus_a", true)
	assert_eq(Game.spots_opened, 1, "a bonus stage continues the counters of its source level")
	assert_eq(Game.tally_count(), 1)
	assert_false(Game.has_checkpoint)
	assert_false(Game.exit_unlocked)
	Game.begin_level(&"next", false)
	assert_eq(Game.spots_total, 0)
	assert_eq(Game.tally_count(), 0)


func test_restarting_a_level_neither_costs_nor_earns() -> void:
	# Entered with 10 000 points, the axe and one letter; the level holds 3 spots and 5 items.
	Game.add_score(10000)
	Game.set_weapon(Defs.Weapon.AXE)
	Game.collect_letter(1)
	Game.begin_level(&"meadow")
	Game.add_completion_totals(3, 5)
	# Played: items and a 1UP-sized score collected, a letter, a hammer, one life lost.
	Game.add_score(Tuning.EXTRA_LIFE_EVERY)
	assert_eq(Game.lives, Tuning.LIVES_START + 1, "the score earned an extra life")
	assert_true(Game.lose_life())
	assert_true(Game.lose_life())
	Game.collect_letter(3)
	Game.set_weapon(Defs.Weapon.HAMMER)
	Game.count_item_collected()
	Game.count_spot_opened()
	Game.add_tally_item(&"items/food", 3, 100)
	assert_true(Game.restore_level_entry())
	assert_eq(Game.score, 10000, "the items lie in the level again: their points are taken back")
	assert_eq(Game.lives, Tuning.LIVES_START - 1, "lives lost stay lost, the life won is taken back")
	assert_eq(Game.weapon, Defs.Weapon.AXE)
	assert_eq(Game.letters, 0b00010)
	assert_eq(Game.items_collected, 0)
	assert_eq(Game.spots_opened, 0)
	assert_eq(Game.spots_total, 0, "the level adds its totals again when it loads")
	assert_eq(Game.tally_count(), 0)
	Game.add_score(Tuning.EXTRA_LIFE_EVERY - 10000)
	assert_eq(Game.lives, Tuning.LIVES_START, "the next extra life comes at the same score as before")


func test_restore_level_entry_needs_a_level_entered_in_this_run() -> void:
	Game.new_game(Defs.Difficulty.BEGINNER)
	Game.add_score(500)
	assert_false(Game.restore_level_entry(), "no level was entered in this run")
	assert_eq(Game.score, 500)
	Game.begin_level(&"bonus_a", true)
	Game.add_score(700)
	Game.level_id = &"other"
	assert_false(Game.restore_level_entry(), "the entry belongs to another level")
	assert_eq(Game.score, 1200)


# --- 2.0: per-hero runs (docs/expansion/PLAN.md P0.4, TECH_AUDIT.md 4.2) -------------------------------------------

func test_frozen_fields_are_properties_of_the_first_run() -> void:
	assert_eq(Game.runs.size(), Defs.MAX_PLAYERS, "one run per player slot, always allocated")
	for slot: int in Defs.MAX_PLAYERS:
		assert_eq(Game.runs[slot].slot, slot)
		assert_true(Game.get_run(slot) == Game.runs[slot])
	var p1: PlayerRun = Game.runs[0]
	Game.hearts = 1
	assert_eq(p1.hearts, 1, "writing Game.hearts writes runs[0]")
	p1.bones = 4
	assert_eq(Game.bones, 4, "reading Game.bones reads runs[0]")
	Game.weapon = Defs.Weapon.AXE
	assert_eq(p1.weapon, Defs.Weapon.AXE)
	p1.has_glider = true
	assert_true(Game.has_glider)
	assert_eq(Game.runs[1].hearts, Tuning.ENERGY_START, "the other slots are untouched")
	assert_eq(Game.mode, Defs.GameMode.SINGLE)
	assert_eq(Game.party, 1)
	assert_eq(Game.book, 1)
	expect_errors(1)
	assert_null(Game.get_run(Defs.MAX_PLAYERS))


## The frozen signals keep their order and meaning (P1); every slot also reports through run_*_changed, and a run
## changed directly (as the hero will do) still drives the 1.0 signals for P1.
func test_the_1_0_signals_keep_their_order() -> void:
	var seen: Array[String] = []
	var record: Callable = func(name: String) -> Callable:
		return func(a: Variant = null, b: Variant = null, c: Variant = null) -> void:
			seen.append("%s %s" % [name, str([a, b, c].filter(func(v: Variant) -> bool: return v != null))])
	var connections: Array[Array] = []
	for signal_name: String in ["run_started", "score_changed", "lives_changed", "energy_changed", "letters_changed",
			"feast_kit_changed", "weapon_changed", "glider_changed", "completion_changed", "run_energy_changed",
			"run_weapon_changed", "run_belt_changed", "run_glider_changed"]:
		var callable: Callable = record.call(signal_name)
		Game.connect(signal_name, callable)
		connections.append([signal_name, callable])
	Game.new_game(Defs.Difficulty.EXPERT)
	var legacy: Array[String] = _legacy(seen)
	assert_eq(legacy, ["run_started [1]", "score_changed [0]", "lives_changed [2]", "letters_changed [0]",
		"feast_kit_changed [0]", "weapon_changed [0]", "glider_changed [false]"] as Array[String], "new_game")
	assert_eq(seen.size(), legacy.size() + 2, "plus run_weapon_changed and run_glider_changed of slot 0: %s" % [seen])
	seen.clear()
	Game.begin_level(&"meadow")
	assert_eq(_legacy(seen), ["energy_changed [3, 0]", "glider_changed [false]", "completion_changed [100]"] \
		as Array[String], "begin_level")
	seen.clear()
	assert_false(Game.lose_heart())
	assert_eq(seen, ["energy_changed [2, 0]", "run_energy_changed [0, 2, 0]"] as Array[String], "Game.lose_heart")
	seen.clear()
	Game.runs[0].add_bones(6)
	assert_eq(seen, ["energy_changed [3, 0]", "run_energy_changed [0, 3, 0]"] as Array[String],
		"a change made on runs[0] itself still emits the frozen signal")
	seen.clear()
	Game.runs[1].lose_heart()
	Game.runs[1].set_glider(true)
	assert_eq(seen, ["run_energy_changed [1, 2, 0]", "run_glider_changed [1, true]"] as Array[String],
		"slot 1 never emits P1's signals")
	seen.clear()
	Game.set_weapon(Defs.Weapon.BOOMERANG)
	Game.set_glider(true)
	Game.set_glider(true)
	Game.on_respawn()
	assert_eq(_legacy(seen), ["weapon_changed [3]", "glider_changed [true]", "energy_changed [3, 0]",
		"glider_changed [false]"] as Array[String], "set_weapon, set_glider (once), on_respawn")
	for connection: Array in connections:
		Game.disconnect(str(connection[0]), connection[1])
	Game.set_weapon(99)
	assert_eq(Game.weapon, Defs.Weapon.SPEAR, "the hand is clamped to the known weapons (the spear is the last)")


func _legacy(seen: Array[String]) -> Array[String]:
	var result: Array[String] = []
	for entry: String in seen:
		if not entry.begins_with("run_") or entry.begins_with("run_started"):
			result.append(entry)
	return result


func test_a_party_resets_refills_and_restores_every_run() -> void:
	Game.start_run(Defs.Difficulty.EXPERT, Defs.GameMode.COOP, 2, 2)
	assert_eq(Game.mode, Defs.GameMode.COOP)
	assert_eq(Game.party, 2)
	assert_eq(Game.book, 2)
	assert_eq(Game.difficulty, Defs.Difficulty.EXPERT)
	var p2: PlayerRun = Game.runs[1]
	p2.set_weapon(Defs.Weapon.SPEAR)
	p2.set_belt(Defs.Weapon.CLUB)
	p2.lose_heart()
	p2.set_glider(true)
	Game.begin_level(&"w5_l1")
	assert_eq(p2.hearts, Tuning.ENERGY_START, "every hero of the party starts a level with full energy")
	assert_false(p2.has_glider)
	assert_eq(p2.weapon, Defs.Weapon.SPEAR, "the weapons are carried")
	p2.swap_belt()
	p2.lose_bone()
	Game.lose_heart()
	Game.on_respawn()
	assert_eq(p2.hearts, Tuning.ENERGY_START, "a team respawn refills every hero")
	assert_eq(Game.hearts, Tuning.ENERGY_START)
	assert_true(Game.restore_level_entry())
	assert_eq(p2.weapon, Defs.Weapon.SPEAR, "a restart gives back the hand ...")
	assert_eq(p2.belt, Defs.Weapon.CLUB, "... and the belt the level was entered with")
	Game.runs[2].lose_heart()
	Game.begin_level(&"w5_l2")
	assert_eq(Game.runs[2].hearts, Tuning.ENERGY_START - 1, "a slot outside the party is not touched")
	Game.start_run(Defs.Difficulty.BEGINNER, Defs.GameMode.VERSUS, 9)
	assert_eq(Game.party, Defs.MAX_PLAYERS, "the party is clamped")
	Game.new_game(Defs.Difficulty.BEGINNER)
	assert_eq(Game.mode, Defs.GameMode.SINGLE, "new_game is the 1.0 game")
	assert_eq(Game.party, 1)
	assert_eq(Game.book, 1)
	for run: PlayerRun in Game.runs:
		assert_eq(run.weapon, Defs.Weapon.CLUB)
		assert_eq(run.belt, PlayerRun.BELT_EMPTY)
		assert_eq(run.hearts, Tuning.ENERGY_START)
		assert_false(run.has_glider)


func test_player_run_belt_primitives() -> void:
	var run: PlayerRun = PlayerRun.new(3)
	var belts: Array[int] = []
	run.belt_changed.connect(func(belt: int) -> void: belts.append(belt))
	assert_eq(run.slot, 3)
	assert_eq(run.special(), PlayerRun.BELT_EMPTY, "only the club")
	assert_false(run.swap_belt(), "nothing to swap with an empty belt")
	run.set_weapon(Defs.Weapon.SPEAR)
	run.set_belt(Defs.Weapon.CLUB)
	assert_eq(run.special(), Defs.Weapon.SPEAR)
	assert_true(run.swap_belt())
	assert_eq(run.weapon, Defs.Weapon.CLUB)
	assert_eq(run.belt, Defs.Weapon.SPEAR)
	assert_eq(run.special(), Defs.Weapon.SPEAR, "the special is owned on the belt too")
	run.swap_belt()
	run.take_fresh_club()
	assert_eq(run.weapon, Defs.Weapon.CLUB, "the fresh-club rule: the club in the hand ...")
	assert_eq(run.belt, Defs.Weapon.SPEAR, "... and the special on the belt")
	run.set_belt(-7)
	assert_eq(run.belt, PlayerRun.BELT_EMPTY)
	assert_eq(belts, [Defs.Weapon.CLUB, Defs.Weapon.SPEAR, Defs.Weapon.CLUB, Defs.Weapon.SPEAR,
		PlayerRun.BELT_EMPTY] as Array[int])
	run.score = 5
	run.kills = 2
	run.reset_run()
	assert_eq(run.score, 0)
	assert_eq(run.kills, 0)
	assert_eq(run.belt, PlayerRun.BELT_EMPTY)
