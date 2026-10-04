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
