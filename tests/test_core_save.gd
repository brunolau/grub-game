extends TestCase
## Save + Settings: versioned persistence. The runner redirects both to res://build/test_user.


func before_each() -> void:
	Save.report_damage = false
	Save.reset()
	Settings.reset()


func after_each() -> void:
	for action: StringName in [Defs.ACT_UP, Defs.ACT_ATTACK, Defs.ACT_JUMP]:
		Input.action_release(action)
	Settings.reset()
	Save.report_damage = true
	# What the save after a test's damaged files set aside (tests/test_core_save_damage.gd is the test of that).
	for file: String in DirAccess.get_files_at(Save.storage_dir):
		if file.begins_with("save.bad"):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(Save.storage_dir + file))


func test_storage_is_redirected_for_tests() -> void:
	assert_true(Save.storage_dir.begins_with("res://build/"), "tests must never touch real user data")
	assert_true(Settings.storage_dir.begins_with("res://build/"))


func test_fresh_save() -> void:
	assert_false(Save.has_progress())
	assert_eq(Save.get_high_score(), 0)
	assert_false(Save.is_level_unlocked(&"w1_l2", Defs.Difficulty.BEGINNER))
	assert_eq(Save.get_level_result(&"w1_l1", Defs.Difficulty.EXPERT)["percent"], 0)
	assert_false(Save.is_game_completed(Defs.Difficulty.EXPERT))


func test_progress_round_trip() -> void:
	Save.unlock_level(&"w1_l2", Defs.Difficulty.BEGINNER)
	Save.unlock_level(&"w1_l2", Defs.Difficulty.BEGINNER)
	assert_true(Save.record_level_result(&"w1_l1", Defs.Difficulty.BEGINNER, 12500, 80))
	assert_false(Save.record_level_result(&"w1_l1", Defs.Difficulty.BEGINNER, 9000, 60), "worse run: no record")
	assert_true(Save.submit_score(12500))
	assert_false(Save.submit_score(100))
	Save.add_code_stone("w1_l1:0")
	Save.add_stat("enemies_killed", 3)
	Save.set_game_completed(Defs.Difficulty.BEGINNER)
	assert_eq(Save.save_game(), OK)
	Save.load_game()
	assert_true(Save.has_progress())
	assert_true(Save.is_level_unlocked(&"w1_l2", Defs.Difficulty.BEGINNER))
	assert_false(Save.is_level_unlocked(&"w1_l2", Defs.Difficulty.EXPERT), "progress is per difficulty")
	assert_eq(Save.get_unlocked_levels(Defs.Difficulty.BEGINNER), [&"w1_l2"] as Array[StringName])
	var result: Dictionary = Save.get_level_result(&"w1_l1", Defs.Difficulty.BEGINNER)
	assert_eq(int(result["percent"]), 80)
	assert_eq(int(result["score"]), 12500)
	assert_eq(int(result["clears"]), 2)
	assert_eq(Save.get_high_score(), 12500)
	assert_true(Save.has_code_stone("w1_l1:0"))
	assert_eq(Save.get_stat("enemies_killed"), 3)
	assert_true(Save.is_game_completed(Defs.Difficulty.BEGINNER))


func test_damaged_file_falls_back_to_backup_then_fresh() -> void:
	Save.unlock_level(&"w2_l1", Defs.Difficulty.EXPERT)
	Save.save_game()
	Save.save_game()  # the first file is now the backup
	var file: FileAccess = FileAccess.open(Save.storage_dir + Save.FILE_NAME, FileAccess.WRITE)
	file.store_string("{ this is not json")
	file.close()
	Save.load_game()
	assert_true(Save.is_level_unlocked(&"w2_l1", Defs.Difficulty.EXPERT), "restored from the backup")
	file = FileAccess.open(Save.storage_dir + Save.BACKUP_NAME, FileAccess.WRITE)
	file.store_string("also broken")
	file.close()
	file = FileAccess.open(Save.storage_dir + Save.FILE_NAME, FileAccess.WRITE)
	file.store_string("[1, 2, 3]")
	file.close()
	Save.load_game()
	assert_false(Save.has_progress(), "a damaged save never blocks the game: fresh data")


func test_settings_defaults_and_round_trip() -> void:
	assert_almost_eq(Settings.get_float("audio/music"), 0.8)
	assert_true(Settings.get_bool("controls/up_jumps"))
	assert_eq(Settings.get_value("no/such_key", "fallback"), "fallback")
	var seen: Array[String] = []
	var on_changed: Callable = func(key: String, _value: Variant) -> void: seen.append(key)
	Settings.changed.connect(on_changed)
	Settings.set_value("audio/music", 0.25)
	Settings.set_value("audio/music", 0.25)
	Settings.set_value("controls/up_jumps", false)
	Settings.changed.disconnect(on_changed)
	assert_eq(seen, ["audio/music", "controls/up_jumps"] as Array[String], "one signal per real change")
	assert_almost_eq(Audio.get_bus_volume(&"Music"), 0.25, 0.001, "volume settings are applied to the bus")
	assert_eq(Settings.save(), OK)
	Settings.load_settings()
	assert_almost_eq(Settings.get_float("audio/music"), 0.25)
	assert_false(Settings.get_bool("controls/up_jumps"))
	Settings.reset()
	assert_almost_eq(Settings.get_float("audio/music"), 0.8)
	assert_almost_eq(Audio.get_bus_volume(&"Music"), 0.8, 0.001)
	Settings.save()


func test_up_jumps_setting_changes_the_up_flag_rule() -> void:
	# With the authentic default, move_up alone raises the UP flag; with it off only jump (or up + attack) does.
	Input.action_press(Defs.ACT_UP)
	Sim.step(1)
	assert_true(GameInput.is_held(Defs.IN_UP))
	Settings.set_value("controls/up_jumps", false)
	Sim.step(1)
	assert_false(GameInput.is_held(Defs.IN_UP))
	Input.action_press(Defs.ACT_ATTACK)
	Sim.step(1)
	assert_true(GameInput.is_held(Defs.IN_UP | Defs.IN_FIRE), "up + attack still gives the high strike")
	Input.action_release(Defs.ACT_UP)
	Input.action_release(Defs.ACT_ATTACK)
	Input.action_press(Defs.ACT_JUMP)
	Sim.step(1)
	assert_true(GameInput.is_held(Defs.IN_UP))
	Input.action_release(Defs.ACT_JUMP)
	Sim.step(1)
	assert_eq(GameInput.flags, 0)



# --- 2.0: Save version 2 (docs/expansion/PLAN.md P0.4) -------------------------------------------------------------

## Real 1.0 save files, written by the 1.0.0 code path (Flow + Save as in commit 53ab7d2) before Save version 2
## existed, each from a fresh user folder: `campaign_beginner.json` by tools/autoplay/campaign_beginner.flow (code
## GR0T, Crystal Grotto played by its route, tally, expert wall), `campaign_expert.json` by
## tools/autoplay/campaign.flow (the whole Expert campaign to The End).
const V1_DIR: String = "res://tests/fixtures/save_v1/"


func _single(difficulty: int) -> String:
	return Save.space(Defs.GameMode.SINGLE, 1, difficulty)


func _install(fixture: String) -> Dictionary:
	var text: String = FileAccess.get_file_as_string(V1_DIR + fixture)
	var file: FileAccess = FileAccess.open(Save.storage_dir + Save.FILE_NAME, FileAccess.WRITE)
	file.store_string(text)
	file.close()
	if FileAccess.file_exists(Save.storage_dir + Save.BACKUP_NAME):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Save.storage_dir + Save.BACKUP_NAME))
	return JSON.parse_string(text)


func _stored() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(Save.storage_dir + Save.FILE_NAME))


func test_version_2_namespaces() -> void:
	assert_eq(Save.VERSION, 2)
	assert_eq(Save.space(Defs.GameMode.SINGLE, 1, Defs.Difficulty.BEGINNER), "single/book1/beginner")
	assert_eq(Save.space(Defs.GameMode.COOP, 2, Defs.Difficulty.EXPERT), "coop/book2/expert")
	var spaces: PackedStringArray = Save.get_spaces()
	assert_eq(spaces.size(), 8, "single and co-op, two books, two difficulties: %s" % str(spaces))
	assert_eq(Save.get_unlocked_levels_in("coop/book2/expert"), [] as Array[StringName])
	assert_eq(Save.get_high_score_in("single/book2/beginner"), 0)
	# The 1.0 methods are (single, Book I) of their difficulty.
	Save.unlock_level(&"w1_l2", Defs.Difficulty.EXPERT)
	assert_true(Save.is_level_unlocked_in(_single(Defs.Difficulty.EXPERT), &"w1_l2"))
	assert_false(Save.is_level_unlocked_in(Save.space(Defs.GameMode.COOP, 1, Defs.Difficulty.EXPERT), &"w1_l2"))
	Save.record_level_result_in(Save.space(Defs.GameMode.COOP, 1, Defs.Difficulty.EXPERT), &"w1_l1", 900, 40)
	assert_eq(int(Save.get_level_result(&"w1_l1", Defs.Difficulty.EXPERT)["clears"]), 0,
		"a co-op result is not a solo result")


func test_namespaces_round_trip() -> void:
	var coop2: String = Save.space(Defs.GameMode.COOP, 2, Defs.Difficulty.EXPERT)
	var solo2: String = Save.space(Defs.GameMode.SINGLE, 2, Defs.Difficulty.BEGINNER)
	assert_false(Save.has_progress())
	Save.unlock_level_in(coop2, &"w5_l2")
	Save.unlock_level_in(coop2, &"w5_l2")
	assert_true(Save.has_progress(), "progress in any namespace shows Continue")
	assert_true(Save.record_level_result_in(coop2, &"w5_l1", 52000, 71))
	assert_false(Save.record_level_result_in(coop2, &"w5_l1", 100, 10))
	assert_true(Save.submit_score_in(coop2, 52000))
	assert_false(Save.submit_score_in(coop2, 400))
	assert_true(Save.submit_score_in(solo2, 30000), "every namespace has its own table")
	Save.set_game_completed_in(solo2)
	Save.set_belt_in(coop2, 1, Defs.Weapon.SPEAR, Defs.Weapon.CLUB)
	Save.set_belt_in("versus/book1/beginner", 0, Defs.Weapon.AXE, PlayerRun.BELT_EMPTY)
	assert_eq(Save.save_game(), OK)
	assert_eq(int(_stored()["version"]), 2)
	assert_false(_stored().has("unlocked"), "no 1.0 keys at the top level")
	Save.load_game()
	assert_eq(Save.get_unlocked_levels_in(coop2), [&"w5_l2"] as Array[StringName])
	var result: Dictionary = Save.get_level_result_in(coop2, &"w5_l1")
	assert_eq([int(result["percent"]), int(result["score"]), int(result["clears"])], [71, 52000, 2])
	assert_eq(Save.get_high_score_in(coop2), 52000)
	assert_eq(Save.get_high_score_in(solo2), 30000)
	assert_eq(Save.get_high_score(), 52000, "the profile record is the best of every run")
	assert_true(Save.is_game_completed_in(solo2))
	assert_false(Save.is_game_completed(Defs.Difficulty.BEGINNER), "Book II is not Book I")
	assert_eq(Save.get_belt_in(coop2, 1), {"hand": Defs.Weapon.SPEAR, "belt": Defs.Weapon.CLUB})
	assert_eq(Save.get_belt_in(coop2, 0), {"hand": Defs.Weapon.CLUB, "belt": PlayerRun.BELT_EMPTY},
		"nothing stored: the club and an empty belt")
	assert_eq(Save.get_belt_in("versus/book1/beginner", 0)["hand"], Defs.Weapon.AXE, "a written namespace is kept")
	expect_errors(1)
	Save.set_belt_in(coop2, Defs.MAX_PLAYERS, 0, 0)


func test_cave_paintings_and_unlocks() -> void:
	assert_eq(Save.painting_count(), 0)
	assert_false(Save.is_unlocked(Save.UNLOCK_PATTERNS))
	for index: int in [4, 0, 19, 27]:
		assert_true(Save.add_painting(index))
	assert_false(Save.add_painting(19), "found once")
	assert_eq(Save.get_paintings(), PackedInt32Array([0, 4, 19, 27]))
	assert_false(Save.is_unlocked(Save.UNLOCK_PATTERNS), "4 of 5")
	Save.add_painting(29)
	assert_true(Save.is_unlocked(Save.UNLOCK_PATTERNS), "5 paintings open the first four loincloth patterns (G60)")
	assert_false(Save.is_unlocked(&"mesa_rodeo"), "a reward id of before cut 3 is no reward: never open")
	assert_false(Save.is_unlocked(Save.UNLOCK_LOINCLOTHS))
	Save.set_unlock_everything(true)
	for reward: StringName in Save.UNLOCK_EVERYTHING_REWARDS:
		assert_true(Save.is_unlocked(reward), "%s by Unlock everything" % reward)
	assert_false(Save.is_unlocked(Save.UNLOCK_MURAL), "the mural stays the reward of the campaign")
	Save.unlock(Save.UNLOCK_MURAL)
	assert_true(Save.is_unlocked(Save.UNLOCK_MURAL))
	assert_false(Save.is_unlocked(&"no_such_reward"))
	for reward: StringName in Save.UNLOCK_PAINTINGS:
		assert_true(int(Save.UNLOCK_PAINTINGS[reward]) <= Tuning.PAINTING_COUNT, "%s is reachable" % reward)
	assert_eq(Save.save_game(), OK)
	Save.load_game()
	assert_eq(Save.painting_count(), 5)
	assert_true(Save.has_painting(27))
	assert_true(Save.is_unlock_everything())
	assert_true(Save.is_unlocked(Save.UNLOCK_MURAL))
	expect_errors(3)
	assert_false(Save.add_painting(Tuning.PAINTING_COUNT))
	assert_false(Save.add_painting(-1))
	Save.unlock(&"no_such_reward")


func test_a_real_1_0_beginner_save_migrates_into_single_book_1() -> void:
	var original: Dictionary = _install("campaign_beginner.json")
	assert_eq(int(original["version"]), 1, "the fixture is a version 1 file")
	Save.load_game()
	var beginner: String = _single(Defs.Difficulty.BEGINNER)
	assert_true(Save.has_progress())
	assert_true(Save.is_level_unlocked(&"w3_l2", Defs.Difficulty.BEGINNER))
	assert_eq(Save.get_unlocked_levels_in(beginner), [&"w3_l2"] as Array[StringName])
	var result: Dictionary = Save.get_level_result(&"w3_l2", Defs.Difficulty.BEGINNER)
	var expected: Dictionary = original["results"]["beginner"]["w3_l2"]
	for field: String in ["percent", "score", "clears"]:
		assert_eq(int(result[field]), int(expected[field]), "result field %s" % field)
	assert_eq(Save.get_high_score(), int(original["high_score"]), "the high score is the profile record")
	assert_eq(Save.get_high_score_in(beginner), 0, "1.0 did not record which difficulty it belongs to")
	var stones: Array = original["code_stones"]
	assert_true(stones.size() > 0, "the fixture holds code stones")
	for stone: Variant in stones:
		assert_true(Save.has_code_stone(str(stone)), "code stone %s" % stone)
	assert_false(Save.is_game_completed(Defs.Difficulty.BEGINNER))
	assert_eq(Save.get_unlocked_levels(Defs.Difficulty.EXPERT), [] as Array[StringName])
	for key: String in Save.get_spaces():
		if key != beginner:
			assert_eq(Save.get_unlocked_levels_in(key), [] as Array[StringName], "%s starts empty" % key)
	assert_eq(Save.get_belt_in(beginner, 0), {"hand": Defs.Weapon.CLUB, "belt": PlayerRun.BELT_EMPTY})
	assert_eq(Save.painting_count(), 0)
	assert_false(Save.is_unlock_everything())
	# Written back as version 2, it reads the same.
	assert_eq(Save.save_game(), OK)
	var stored: Dictionary = _stored()
	assert_eq(int(stored["version"]), 2)
	for v1_key: String in ["unlocked", "results", "completed"]:
		assert_false(stored.has(v1_key), "the 1.0 key %s moved into the namespaces" % v1_key)
	Save.load_game()
	assert_eq(int(Save.get_level_result(&"w3_l2", Defs.Difficulty.BEGINNER)["score"]), int(expected["score"]))
	assert_true(Save.has_code_stone(str(stones[0])))


func test_a_real_1_0_expert_save_migrates_into_single_book_1() -> void:
	if not FileAccess.file_exists(V1_DIR + "campaign_expert.json"):
		fail("tests/fixtures/save_v1/campaign_expert.json is missing")
		return
	var original: Dictionary = _install("campaign_expert.json")
	assert_eq(int(original["version"]), 1)
	Save.load_game()
	var expert: String = _single(Defs.Difficulty.EXPERT)
	assert_true(Save.is_game_completed(Defs.Difficulty.EXPERT), "the Expert campaign was finished in 1.0")
	assert_true(Save.is_game_completed_in(expert))
	assert_false(Save.is_game_completed(Defs.Difficulty.BEGINNER))
	var unlocked: Array = original["unlocked"]["expert"]
	assert_true(unlocked.size() > 5, "the fixture reached many levels")
	assert_eq(Save.get_unlocked_levels(Defs.Difficulty.EXPERT).size(), unlocked.size())
	for id: Variant in unlocked:
		assert_true(Save.is_level_unlocked(StringName(str(id)), Defs.Difficulty.EXPERT), "unlocked %s" % id)
	var results: Dictionary = original["results"]["expert"]
	assert_true(results.size() > 5, "the fixture holds many results")
	for id: Variant in results:
		var migrated: Dictionary = Save.get_level_result_in(expert, StringName(str(id)))
		for field: String in ["percent", "score", "clears"]:
			assert_eq(int(migrated[field]), int(results[id][field]), "%s %s" % [id, field])
	assert_eq(Save.get_high_score(), int(original["high_score"]))
	for key: String in Save.get_spaces():
		if key != expert:
			assert_false(Save.is_game_completed_in(key), "%s is not completed" % key)


## A 2.0 file written again by 1.0.0 (version 1 with its own top-level keys, the namespaces kept as unknown keys):
## nothing is lost, the two are merged.
func test_a_downgraded_file_is_merged_not_overwritten() -> void:
	var beginner: String = _single(Defs.Difficulty.BEGINNER)
	Save.unlock_level(&"w1_l2", Defs.Difficulty.BEGINNER)
	Save.record_level_result(&"w1_l1", Defs.Difficulty.BEGINNER, 5000, 90)
	Save.add_painting(3)
	assert_eq(Save.save_game(), OK)
	var data: Dictionary = _stored()
	data["version"] = 1
	data["unlocked"] = {"beginner": ["w2_l1"], "expert": ["w1_l2"]}
	data["results"] = {"beginner": {"w1_l1": {"percent": 50, "score": 8000, "clears": 1}}, "expert": {}}
	data["completed"] = {"beginner": false, "expert": true}
	var file: FileAccess = FileAccess.open(Save.storage_dir + Save.FILE_NAME, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()
	Save.load_game()
	assert_eq(Save.get_unlocked_levels_in(beginner), [&"w1_l2", &"w2_l1"] as Array[StringName], "united")
	var result: Dictionary = Save.get_level_result(&"w1_l1", Defs.Difficulty.BEGINNER)
	assert_eq([int(result["percent"]), int(result["score"])], [90, 8000], "the best of both")
	assert_true(Save.is_game_completed(Defs.Difficulty.EXPERT))
	assert_true(Save.is_level_unlocked(&"w1_l2", Defs.Difficulty.EXPERT))
	assert_true(Save.has_painting(3), "2.0 data survives")


func test_damaged_version_2_parts_fall_back_to_defaults() -> void:
	var file: FileAccess = FileAccess.open(Save.storage_dir + Save.FILE_NAME, FileAccess.WRITE)
	file.store_string(JSON.stringify({"version": 2, "spaces": {"single/book1/beginner": {"unlocked": "w1_l2",
		"results": [], "belt": [{"hand": "axe"}, 7]}, "coop/book1/expert": 5}, "paintings": [2, 2, 99, -1, "x", 5.0],
		"unlocks": [], "high_score": "lots"}))
	file.close()
	Save.load_game()
	assert_false(Save.has_progress())
	assert_eq(Save.get_belt_in(_single(Defs.Difficulty.BEGINNER), 0)["hand"], Defs.Weapon.CLUB)
	assert_eq(Save.get_belt_in(_single(Defs.Difficulty.BEGINNER), 1)["belt"], PlayerRun.BELT_EMPTY)
	assert_eq(Save.get_paintings(), PackedInt32Array([2, 5]), "valid indices only, once each")
	assert_false(Save.is_unlock_everything())
	assert_eq(Save.get_high_score(), 0)
	assert_eq(Save.get_spaces().size(), 8)
