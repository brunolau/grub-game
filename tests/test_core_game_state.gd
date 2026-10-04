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
