extends TestCase
## Save version 2 and Settings against REAL Club & Grub 1.0.0 profiles (docs/expansion/PLAN.md P4.6).
##
## tests/data/saves_1_0/<profile>/ holds the user folder (save.json, save.json.bak, settings.cfg) that the 1.0.0
## release (git tag v1.0.0) wrote when it was played by its own flow runner from an empty folder; the flow of each
## profile is tests/data/saves_1_0/flows/<profile>.flow and tests/data/saves_1_0/README.md says how to make them
## again. Nothing in these folders was edited by hand.
##
## What 2.0 must do with them: load every one without losing a thing (levels, results, completion, code stones, the
## high score, options, key bindings, the last difficulty; every level code opens the stage it opened), and never
## write a 2.0 save over the 1.0 file before the migration has succeeded and an untouched copy of the 1.0 file
## exists (save.v1.json).

const DIR: String = "res://tests/data/saves_1_0/"
## Every profile; FRESH is the one without a save file.
const PROFILES: PackedStringArray = ["fresh", "expert_start", "mid_beginner", "mid_expert", "finished"]
const FRESH: String = "fresh"
const USER_FILES: PackedStringArray = ["save.json", "save.json.bak", "save.json.tmp", "settings.cfg"]
const DIFFICULTIES: Array[int] = [Defs.Difficulty.BEGINNER, Defs.Difficulty.EXPERT]
## The keys 1.0.0 knew (its Settings.DEFAULTS): a 1.0 file can hold these and no others.
const KEYS_1_0: PackedStringArray = [
	"audio/master", "audio/music", "audio/sfx", "video/fullscreen", "video/vsync", "video/screen_shake",
	"video/flash", "controls/up_jumps", "controls/touch_always", "controls/touch_opacity", "controls/touch_scale",
	"controls/touch_layout", "controls/vibration", "camera/smooth_follow", "game/locale", "game/last_difficulty",
]
## The game actions of 1.0.0, in its order (2.0 appended `swap`).
const ACTIONS_1_0: Array[StringName] = [
	&"move_left", &"move_right", &"move_up", &"move_down", &"jump", &"attack", &"look", &"pause",
]


func before_each() -> void:
	Save.report_damage = false
	_clear_user_folder()
	Save.load_game()
	Settings.reset()


func after_each() -> void:
	_clear_user_folder()
	Save.load_game()
	Settings.reset()
	Save.report_damage = true


# --- Helpers -----------------------------------------------------------------------------------------------------

func _user_path(file: String) -> String:
	return Save.storage_dir + file


func _clear_user_folder() -> void:
	var dir: DirAccess = DirAccess.open(Save.storage_dir)
	if dir == null:
		return
	for file: String in dir.get_files():
		# Also what a save or a settings file that could not be read was set aside as (tests/test_core_save_damage.gd).
		var set_aside: bool = file.begins_with("save.bad") or file.begins_with("settings.bad")
		if USER_FILES.has(file) or file.begins_with("save.v") or set_aside:
			dir.remove(file)
	# A folder a test put in the way of the copy.
	if dir.dir_exists(Save.legacy_backup_name(1)):
		dir.remove(Save.legacy_backup_name(1))


func _bytes(path: String) -> PackedByteArray:
	return FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else PackedByteArray()


func _write(path: String, bytes: PackedByteArray) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()


## Put a 1.0 profile into the user folder of this test run, exactly as its files are.
func _install(profile: String) -> void:
	_clear_user_folder()
	for file: String in USER_FILES:
		if FileAccess.file_exists(DIR + profile + "/" + file):
			_write(_user_path(file), _bytes(DIR + profile + "/" + file))


func _has_save(profile: String) -> bool:
	return FileAccess.file_exists(DIR + profile + "/save.json")


## The save.json of a profile as 1.0.0 wrote it.
func _original(profile: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DIR + profile + "/save.json"))
	return parsed if parsed is Dictionary else {}


func _stored_version(file: String) -> int:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(_user_path(file)))
	return int(parsed["version"]) if parsed is Dictionary and parsed.has("version") else -1


func _settings_file(profile: String) -> ConfigFile:
	var file: ConfigFile = ConfigFile.new()
	assert_eq(file.load(DIR + profile + "/settings.cfg"), OK, "%s: settings.cfg is readable" % profile)
	return file


func _tokens(events: Array[InputEvent]) -> PackedStringArray:
	var tokens: PackedStringArray = PackedStringArray()
	for event: InputEvent in events:
		tokens.append(Settings.encode_event(event))
	return tokens


## Everything the 1.0 file `original` holds is what Save answers now; returns how many facts were compared.
func _assert_nothing_lost(profile: String, original: Dictionary) -> int:
	var facts: int = 0
	for difficulty: int in DIFFICULTIES:
		var mode: String = Defs.difficulty_name(difficulty)
		var space: String = Save.space(Defs.GameMode.SINGLE, 1, difficulty)
		var unlocked: Array = original["unlocked"][mode]
		var now: Array[StringName] = Save.get_unlocked_levels(difficulty)
		assert_eq(now.size(), unlocked.size(), "%s %s: as many unlocked levels" % [profile, mode])
		for i: int in mini(unlocked.size(), now.size()):
			assert_eq(String(now[i]), str(unlocked[i]), "%s %s: unlocked level %d, in the same order" % [profile, mode, i])
			assert_true(Save.is_level_unlocked_in(space, StringName(str(unlocked[i]))))
			facts += 1
		var results: Dictionary = original["results"][mode]
		for id: Variant in results:
			var kept: Dictionary = Save.get_level_result(StringName(str(id)), difficulty)
			for field: String in ["percent", "score", "clears"]:
				assert_eq(int(kept[field]), int(results[id][field]), "%s %s: %s of %s" % [profile, mode, field, id])
				facts += 1
		assert_eq(Save.is_game_completed(difficulty), bool(original["completed"][mode]),
			"%s %s: the completion flag" % [profile, mode])
		assert_eq(Save.get_high_score_in(space), 0, "%s %s: 1.0 kept no high score per difficulty" % [profile, mode])
		facts += 1
	var stones: Array = original["code_stones"]
	for stone: Variant in stones:
		assert_true(Save.has_code_stone(str(stone)), "%s: code stone %s" % [profile, stone])
		facts += 1
	var stats: Dictionary = original["stats"]
	for stat: Variant in stats:
		assert_eq(Save.get_stat(str(stat)), int(stats[stat]), "%s: statistic %s" % [profile, stat])
		facts += 1
	assert_eq(Save.get_high_score(), int(original["high_score"]), "%s: the high score" % profile)
	# Nothing was invented either: the 2.0 namespaces a 1.0 player never saw are empty.
	for key: String in Save.get_spaces():
		if key.begins_with("single/book1/"):
			continue
		assert_eq(Save.get_unlocked_levels_in(key), [] as Array[StringName], "%s: %s starts empty" % [profile, key])
		assert_false(Save.is_game_completed_in(key), "%s: %s is not completed" % [profile, key])
	assert_eq(Save.painting_count(), 0, "%s: no Cave Painting was found in 1.0" % profile)
	assert_false(Save.is_unlock_everything())
	return facts + 1


# --- The fixtures --------------------------------------------------------------------------------------------------

func test_the_fixtures_are_what_1_0_0_wrote() -> void:
	for profile: String in PROFILES:
		assert_true(FileAccess.file_exists(DIR + "flows/" + profile + ".flow"), "%s: the flow that played it" % profile)
		var settings: ConfigFile = _settings_file(profile)
		assert_eq(int(settings.get_value("meta", "version", 0)), 1, "%s: settings version 1" % profile)
		for section: String in settings.get_sections():
			if section == "meta" or section == "bindings":
				continue
			for key: String in settings.get_section_keys(section):
				assert_true(KEYS_1_0.has("%s/%s" % [section, key]), "%s: %s/%s is a 1.0 key" % [profile, section, key])
		if profile == FRESH:
			assert_false(_has_save(profile), "a player who cleared no stage has no save file")
			continue
		var original: Dictionary = _original(profile)
		assert_eq(int(original.get("version", 0)), 1, "%s: a version 1 save" % profile)
		for key: String in ["unlocked", "results", "completed", "code_stones", "stats", "high_score"]:
			assert_true(original.has(key), "%s: the 1.0 key %s" % [profile, key])
		assert_false(original.has("spaces"), "%s: no 2.0 key" % profile)
	# What each profile is, so that an emptied fixture cannot pass the comparisons below.
	var beginner: Dictionary = _original("mid_beginner")
	assert_eq(beginner["unlocked"]["beginner"], ["w1_l2", "w2_l1", "w3_l1"], "two stages cleared, 3-1 opened by its code")
	assert_eq((beginner["results"]["beginner"] as Dictionary).size(), 2)
	assert_eq((beginner["unlocked"]["expert"] as Array).size(), 0)
	var both: Dictionary = _original("mid_expert")
	assert_eq(both["unlocked"]["expert"], ["w1_l2", "w2_l1", "w2_l2"])
	assert_eq(both["unlocked"]["beginner"], ["w1_l2"], "progress in both difficulties")
	assert_true((both["code_stones"] as Array).size() >= 6)
	var finished: Dictionary = _original("finished")
	assert_true(bool(finished["completed"]["expert"]), "the Expert campaign was finished")
	assert_false(bool(finished["completed"]["beginner"]), "a Beginner run ends at the expert wall")
	assert_eq((finished["results"]["expert"] as Dictionary).size(), 9, "the eight map stops of Book I and the ending")
	assert_true(int(finished["high_score"]) > 1000000)
	assert_true((finished["results"]["beginner"] as Dictionary).has("w3_l2"))
	assert_eq(int(_settings_file("expert_start").get_value("game", "last_difficulty", -1)), 1)
	assert_true(_settings_file("mid_beginner").has_section("bindings"))
	assert_true(_settings_file("mid_expert").has_section("bindings"))
	assert_false(_settings_file("finished").has_section("bindings"))


# --- Progress --------------------------------------------------------------------------------------------------------

func test_every_1_0_profile_loads_without_losing_progress() -> void:
	var facts: int = 0
	for profile: String in PROFILES:
		if not _has_save(profile):
			continue
		_install(profile)
		Save.load_game()
		assert_true(Save.was_migrated(), "%s: a file of version 1 was read" % profile)
		assert_eq(Save.migration_losses(), PackedStringArray(), "%s: the migration lost nothing" % profile)
		assert_true(Save.has_progress(), "%s: the title offers Continue" % profile)
		facts += _assert_nothing_lost(profile, _original(profile))
	assert_true(facts > 100, "the four profiles hold more than 100 facts (compared %d)" % facts)
	print("    1.0 profiles: %d facts (unlocks, results, completion, code stones, high scores) compared, none lost" % facts)


## The check that stands between the migration and the first write (Save.migration_losses) is no formality: handed a
## migration that carried nothing over, it names every unlocked stage, result, flag, code stone and the high score.
func test_the_migration_check_names_what_a_bad_migration_would_lose() -> void:
	var original: Dictionary = _original("finished")
	var carried_nothing: Dictionary = {"spaces": {}, "code_stones": [], "stats": {}, "high_score": 0}
	var losses: PackedStringArray = Save._v1_losses(original, carried_nothing)
	var expected: int = 2  # the completion flag of Expert and the high score
	for mode: String in ["beginner", "expert"]:
		expected += (original["unlocked"][mode] as Array).size() + 3 * (original["results"][mode] as Dictionary).size()
	expected += (original["code_stones"] as Array).size()
	assert_eq(losses.size(), expected, "every fact of the file is named once: %s" % str(losses).left(300))
	for loss: String in ["completed expert", "high score", "unlocked expert w1_l2", "result expert w4_l2 score",
			"result beginner w3_l2 clears", "code stone w1_l1:3"]:
		assert_true(losses.has(loss), "'%s' is reported" % loss)
	# One stage short is one loss; the real migration of the same file has none.
	_install("finished")
	Save.load_game()
	assert_eq(Save.migration_losses(), PackedStringArray())
	var migrated: Dictionary = JSON.parse_string(JSON.stringify({"spaces": {
		"single/book1/expert": {"unlocked": original["unlocked"]["expert"].slice(1), "results": original["results"]["expert"],
			"completed": true},
		"single/book1/beginner": {"unlocked": original["unlocked"]["beginner"], "results": original["results"]["beginner"],
			"completed": false}},
		"code_stones": original["code_stones"], "stats": original["stats"], "high_score": original["high_score"]}))
	assert_eq(Save._v1_losses(original, migrated), PackedStringArray(["unlocked expert %s" % original["unlocked"]["expert"][0]]))


func test_a_fresh_1_0_profile_starts_2_0_clean() -> void:
	_install(FRESH)
	Save.load_game()
	Settings.load_settings()
	assert_false(Save.was_migrated(), "no save file: nothing to migrate")
	assert_false(Save.has_progress())
	assert_eq(Save.get_high_score(), 0)
	assert_eq(Settings.get_int("game/last_difficulty"), 0)
	assert_false(Settings.has_custom_bindings())
	assert_eq(Save.save_game(), OK)
	assert_eq(Save.legacy_backup_path(), "", "no copy of a file that never was")
	assert_false(FileAccess.file_exists(_user_path(Save.legacy_backup_name(1))))
	assert_eq(_stored_version("save.json"), 2)


func test_loading_a_1_0_profile_writes_nothing() -> void:
	for profile: String in PROFILES:
		_install(profile)
		var before: Dictionary = {}
		for file: String in DirAccess.get_files_at(Save.storage_dir):
			before[file] = _bytes(_user_path(file))
		Save.load_game()
		Settings.load_settings()
		var after: PackedStringArray = DirAccess.get_files_at(Save.storage_dir)
		assert_eq(after.size(), before.size(), "%s: no file appeared or vanished: %s" % [profile, str(after)])
		for file: String in after:
			assert_true(before.has(file) and before[file] == _bytes(_user_path(file)), "%s: %s is untouched" % [profile, file])


# --- The 1.0 file is never written over before it is safe -----------------------------------------------------------

func test_the_1_0_file_is_copied_before_the_first_2_0_write() -> void:
	for profile: String in PROFILES:
		if not _has_save(profile):
			continue
		_install(profile)
		var original_bytes: PackedByteArray = _bytes(DIR + profile + "/save.json")
		var copy_path: String = _user_path(Save.legacy_backup_name(1))
		assert_eq(Save.legacy_backup_name(1), "save.v1.json")
		Save.load_game()
		assert_eq(Save.legacy_backup_path(), "", "%s: nothing is written by reading" % profile)
		assert_eq(_bytes(_user_path("save.json")), original_bytes, "%s: the 1.0 file is still the save" % profile)
		# The first write of 2.0.
		assert_eq(Save.save_game(), OK, profile)
		assert_eq(Save.legacy_backup_path(), copy_path, "%s: the copy is announced" % profile)
		assert_eq(_bytes(copy_path), original_bytes, "%s: save.v1.json is the 1.0 file, byte for byte" % profile)
		assert_eq(_stored_version("save.json"), 2, "%s: the save is version 2 now" % profile)
		assert_eq(_stored_version("save.v1.json"), 1)
		# Later writes rotate save.json.bak (after two of them no version 1 file is left there) and never touch the copy.
		Save.unlock_level_in(Save.space(Defs.GameMode.COOP, 2, Defs.Difficulty.BEGINNER), &"w5_l1")
		assert_eq(Save.save_game(), OK)
		assert_eq(Save.save_game(), OK)
		assert_eq(_stored_version("save.json.bak"), 2, "%s: the ordinary backup has moved on" % profile)
		assert_eq(_bytes(copy_path), original_bytes, "%s: the copy of the 1.0 file stays as it was" % profile)
		assert_false(FileAccess.file_exists(copy_path + ".tmp"))
		assert_false(FileAccess.file_exists(_user_path(Save.legacy_backup_name(1, 2))), "one 1.0 file, one copy")
		# Read back as version 2: still everything, and 2.0's own progress beside it.
		Save.load_game()
		assert_false(Save.was_migrated(), "%s: a version 2 file needs no migration" % profile)
		_assert_nothing_lost_except_coop_step(profile)


## After the round trip of the test above: the 1.0 progress, plus the one co-op unlock 2.0 added.
func _assert_nothing_lost_except_coop_step(profile: String) -> void:
	var original: Dictionary = _original(profile)
	for difficulty: int in DIFFICULTIES:
		var mode: String = Defs.difficulty_name(difficulty)
		var unlocked: Array = original["unlocked"][mode]
		var now: Array[StringName] = Save.get_unlocked_levels(difficulty)
		assert_eq(now.size(), unlocked.size(), "%s %s: unlocked levels after the round trip" % [profile, mode])
		var results: Dictionary = original["results"][mode]
		for id: Variant in results:
			var kept: Dictionary = Save.get_level_result(StringName(str(id)), difficulty)
			for field: String in ["percent", "score", "clears"]:
				assert_eq(int(kept[field]), int(results[id][field]), "%s %s: %s of %s" % [profile, mode, field, id])
		assert_eq(Save.is_game_completed(difficulty), bool(original["completed"][mode]))
	for stone: Variant in original["code_stones"]:
		assert_true(Save.has_code_stone(str(stone)))
	assert_eq(Save.get_high_score(), int(original["high_score"]))
	assert_true(Save.is_level_unlocked_in(Save.space(Defs.GameMode.COOP, 2, Defs.Difficulty.BEGINNER), &"w5_l1"))


func test_no_2_0_save_is_written_while_the_copy_cannot_be_made() -> void:
	_install("mid_expert")
	var original_bytes: PackedByteArray = _bytes(DIR + "mid_expert/save.json")
	var backup_bytes: PackedByteArray = _bytes(_user_path("save.json.bak"))
	# Something sits where the copy belongs (here: a folder of that name), so the copy cannot be made.
	assert_eq(DirAccess.make_dir_absolute(_user_path(Save.legacy_backup_name(1))), OK)
	Save.load_game()
	assert_true(Save.is_level_unlocked(&"w2_l2", Defs.Difficulty.EXPERT), "the game still plays with the progress")
	Save.unlock_level(&"w3_l1", Defs.Difficulty.EXPERT)
	expect_errors(1)
	assert_eq(Save.save_game(), ERR_FILE_CANT_WRITE, "no write without the copy")
	assert_eq(_bytes(_user_path("save.json")), original_bytes, "the 1.0 file is untouched")
	assert_eq(_bytes(_user_path("save.json.bak")), backup_bytes, "and so is its backup")
	assert_false(FileAccess.file_exists(_user_path("save.json.tmp")), "no half-written save")
	assert_false(FileAccess.file_exists(_user_path(Save.legacy_backup_name(1) + ".tmp")), "no half-written copy")
	assert_eq(Save.legacy_backup_path(), "")
	# The obstacle goes away: the next save makes the copy first, then writes, and nothing played meanwhile is lost.
	assert_eq(DirAccess.remove_absolute(ProjectSettings.globalize_path(_user_path(Save.legacy_backup_name(1)))), OK)
	assert_eq(Save.save_game(), OK)
	assert_eq(_bytes(_user_path(Save.legacy_backup_name(1))), original_bytes)
	assert_eq(_stored_version("save.json"), 2)
	Save.load_game()
	assert_true(Save.is_level_unlocked(&"w3_l1", Defs.Difficulty.EXPERT))
	assert_true(Save.is_level_unlocked(&"w2_l2", Defs.Difficulty.EXPERT))


## A player goes back to 1.0.0 and returns: the second 1.0 file is another file, so it gets its own copy and the
## first copy keeps its content. The same file read again adds nothing.
func test_a_later_1_0_file_never_replaces_the_first_copy() -> void:
	_install("mid_beginner")
	var first: PackedByteArray = _bytes(DIR + "mid_beginner/save.json")
	var second: PackedByteArray = _bytes(DIR + "mid_expert/save.json")
	Save.load_game()
	assert_eq(Save.save_game(), OK)
	assert_eq(_bytes(_user_path("save.v1.json")), first)
	_write(_user_path("save.json"), second)
	Save.load_game()
	assert_true(Save.was_migrated())
	assert_eq(Save.save_game(), OK)
	assert_eq(Save.legacy_backup_name(1, 2), "save.v1.2.json")
	assert_eq(Save.legacy_backup_path(), _user_path("save.v1.2.json"))
	assert_eq(_bytes(_user_path("save.v1.json")), first, "the first copy is never written again")
	assert_eq(_bytes(_user_path("save.v1.2.json")), second)
	_write(_user_path("save.json"), first)
	Save.load_game()
	assert_eq(Save.save_game(), OK)
	assert_eq(Save.legacy_backup_path(), _user_path("save.v1.json"), "a file that is already kept needs no new copy")
	assert_false(FileAccess.file_exists(_user_path(Save.legacy_backup_name(1, 3))))


func test_a_1_0_backup_is_migrated_when_the_save_is_damaged() -> void:
	_install("mid_expert")
	var backup_bytes: PackedByteArray = _bytes(DIR + "mid_expert/save.json.bak")
	assert_true(backup_bytes.size() > 0, "1.0.0 left a save.json.bak beside the save")
	_write(_user_path("save.json"), "{ cut off".to_utf8_buffer())
	Save.load_game()
	assert_true(Save.was_migrated())
	var backup: Dictionary = JSON.parse_string(backup_bytes.get_string_from_utf8())
	assert_eq(Save.get_unlocked_levels(Defs.Difficulty.EXPERT).size(), (backup["unlocked"]["expert"] as Array).size())
	assert_true(Save.get_unlocked_levels(Defs.Difficulty.EXPERT).size() > 0, "the progress of the 1.0 backup")
	assert_eq(Save.save_game(), OK)
	assert_eq(_bytes(_user_path("save.v1.json")), backup_bytes, "the file the progress came from is the one kept")
	assert_eq(_stored_version("save.json"), 2)


## The profile `downgraded` is a 2.0 profile (the migrated `mid_expert` with a Cave Painting, a co-op unlock and a
## Book II result) that the REAL 1.0.0 then played: 1.0.0 showed no progress, cleared 1-1 on Expert and wrote a
## version 1 file that still carries the 2.0 keys. Back in 2.0 nothing of either is lost.
func test_a_2_0_profile_played_by_1_0_0_comes_back_whole() -> void:
	_install("downgraded")
	_write(_user_path("save.v1.json"), _bytes(DIR + "downgraded/save.v1.json"))
	var written_by_1_0: PackedByteArray = _bytes(DIR + "downgraded/save.json")
	var first_copy: PackedByteArray = _bytes(DIR + "downgraded/save.v1.json")
	var original: Dictionary = JSON.parse_string(written_by_1_0.get_string_from_utf8())
	assert_eq(int(original["version"]), 1, "1.0.0 wrote its own version")
	assert_true(original.has("spaces") and original.has("unlocked"), "with the 2.0 keys beside its own")
	Save.load_game()
	assert_true(Save.was_migrated())
	assert_eq(Save.migration_losses(), PackedStringArray())
	var expert: String = Save.space(Defs.GameMode.SINGLE, 1, Defs.Difficulty.EXPERT)
	# What 2.0 had before the detour ...
	assert_eq(Save.get_unlocked_levels_in(expert), [&"w1_l2", &"w2_l1", &"w2_l2"] as Array[StringName])
	assert_eq(int(Save.get_level_result_in(expert, &"w2_l1")["score"]), 1018800)
	assert_true(Save.is_level_unlocked(&"w1_l2", Defs.Difficulty.BEGINNER))
	assert_true(Save.is_level_unlocked_in(Save.space(Defs.GameMode.COOP, 2, Defs.Difficulty.EXPERT), &"w5_l2"), "co-op progress")
	assert_eq(int(Save.get_level_result_in(Save.space(Defs.GameMode.SINGLE, 2, Defs.Difficulty.BEGINNER), &"w5_l1")["score"]),
		77000, "a Book II result")
	assert_true(Save.has_painting(3), "the Cave Painting")
	assert_eq(Save.painting_count(), 1)
	# ... and what 1.0.0 added (the same stage again: the best of both, not a second copy).
	var again: Dictionary = Save.get_level_result_in(expert, &"w1_l1")
	assert_eq([int(again["percent"]), int(again["score"]), int(again["clears"])], [54, 124400, 1])
	for stone: Variant in original["code_stones"]:
		assert_true(Save.has_code_stone(str(stone)))
	# The first copy of the 1.0 file stays; the file of the detour gets its own.
	assert_eq(Save.save_game(), OK)
	assert_eq(_bytes(_user_path("save.v1.json")), first_copy)
	assert_eq(_bytes(_user_path("save.v1.2.json")), written_by_1_0)
	assert_eq(_stored_version("save.json"), 2)
	var stored: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(_user_path("save.json")))
	for key_1_0: String in ["unlocked", "results", "completed"]:
		assert_false(stored.has(key_1_0), "the 1.0 key %s is inside the namespaces again" % key_1_0)


## A file of a NEWER build is kept the same way before this build writes its own version over it.
func test_a_file_of_a_newer_version_is_copied_before_it_is_written_over() -> void:
	Save.unlock_level(&"w1_l2", Defs.Difficulty.BEGINNER)
	assert_eq(Save.save_game(), OK)
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(_user_path("save.json")))
	data["version"] = 3
	data["of_the_future"] = {"x": 1}
	_write(_user_path("save.json"), JSON.stringify(data).to_utf8_buffer())
	var newer: PackedByteArray = _bytes(_user_path("save.json"))
	Save.load_game()
	assert_true(Save.was_migrated())
	assert_eq(Save.migration_losses(), PackedStringArray())
	assert_true(Save.is_level_unlocked(&"w1_l2", Defs.Difficulty.BEGINNER), "kept as far as it is understood")
	assert_eq(Save.save_game(), OK)
	assert_eq(_bytes(_user_path(Save.legacy_backup_name(3))), newer)


# --- Options, key bindings, difficulty ------------------------------------------------------------------------------

func test_1_0_options_load_unchanged() -> void:
	var compared: int = 0
	for profile: String in PROFILES:
		_install(profile)
		Settings.load_settings()
		var stored: ConfigFile = _settings_file(profile)
		for key: String in KEYS_1_0:
			var parts: PackedStringArray = key.split("/")
			if stored.has_section_key(parts[0], parts[1]):
				assert_eq(Settings.get_value(key), stored.get_value(parts[0], parts[1]), "%s: %s as stored" % [profile, key])
				compared += 1
			else:
				assert_eq(Settings.get_value(key), Settings.DEFAULTS[key], "%s: %s keeps its default" % [profile, key])
		for key: String in Settings.DEFAULTS:
			if not KEYS_1_0.has(key):
				assert_eq(Settings.get_value(key), Settings.DEFAULTS[key], "%s: the 2.0 option %s starts at its default" % [
					profile, key])
	assert_true(compared >= 12, "the profiles hold changed options (compared %d)" % compared)
	# The values the flows set, pinned.
	_install("mid_beginner")
	Settings.load_settings()
	assert_almost_eq(Settings.get_float("audio/music"), 0.5)
	assert_almost_eq(Settings.get_float("audio/sfx"), 0.9)
	assert_false(Settings.get_bool("video/screen_shake"))
	assert_false(Settings.get_bool("video/flash"))
	assert_false(Settings.get_bool("controls/up_jumps"))
	assert_almost_eq(Audio.get_bus_volume(&"Music"), 0.5, 0.001, "and they are applied")
	_install("mid_expert")
	Settings.load_settings()
	assert_almost_eq(Settings.get_float("audio/master"), 0.8)
	assert_true(Settings.get_bool("camera/smooth_follow"))
	assert_false(Settings.get_bool("controls/vibration"))


func test_the_last_difficulty_of_1_0_is_kept() -> void:
	_install("expert_start")
	Settings.load_settings()
	Save.load_game()
	assert_eq(Settings.get_int("game/last_difficulty"), Defs.Difficulty.EXPERT, "an Expert player stays one")
	assert_eq(Save.get_unlocked_levels(Defs.Difficulty.EXPERT), [&"w1_l2"] as Array[StringName])
	assert_eq(Save.get_unlocked_levels(Defs.Difficulty.BEGINNER), [] as Array[StringName], "progress is per difficulty")
	_install("mid_expert")
	Settings.load_settings()
	assert_eq(Settings.get_int("game/last_difficulty"), Defs.Difficulty.BEGINNER, "the run played last")


func test_1_0_key_bindings_load_unchanged() -> void:
	var rebound: int = 0
	for profile: String in PROFILES:
		_install(profile)
		Settings.load_settings()
		var stored: ConfigFile = _settings_file(profile)
		for action: StringName in ACTIONS_1_0:
			var now: PackedStringArray = _tokens(Settings.get_bindings(action))
			if stored.has_section_key("bindings", String(action)):
				assert_eq(now, stored.get_value("bindings", String(action)) as PackedStringArray,
					"%s: %s as the player bound it, in the same order" % [profile, action])
				rebound += 1
			else:
				assert_eq(now, _tokens(Settings.get_default_bindings(action)), "%s: %s on its defaults" % [profile, action])
		assert_eq(Settings.has_custom_bindings(), stored.has_section("bindings"), profile)
	assert_eq(rebound, 4, "two profiles with two rebound actions each")
	# The inputs the flows bound, pinned: jump on V and look on pad LB; strike on H and jump on Space.
	_install("mid_beginner")
	Settings.load_settings()
	assert_eq(_tokens(Settings.get_bindings(&"jump", Defs.Device.KEYBOARD))[0], "key:%d" % KEY_V)
	assert_eq(_tokens(Settings.get_bindings(&"look", Defs.Device.GAMEPAD))[0], "joy_button:%d" % JOY_BUTTON_LEFT_SHOULDER)
	_install("mid_expert")
	Settings.load_settings()
	assert_eq(_tokens(Settings.get_bindings(&"attack", Defs.Device.KEYBOARD))[0], "key:%d" % KEY_H)
	assert_eq(_tokens(Settings.get_bindings(&"jump", Defs.Device.KEYBOARD))[0], "key:%d" % KEY_SPACE)
	assert_false(_tokens(Settings.get_bindings(&"attack")).has("key:%d" % KEY_SPACE), "Space left the strike in 1.0")


## 2.0 writes the settings file in the same format and version: what 1.0 stored is still there, value for value, so
## the file also reads in 1.0.0 again.
func test_settings_written_by_2_0_still_hold_what_1_0_stored() -> void:
	for profile: String in PROFILES:
		_install(profile)
		Settings.load_settings()
		assert_eq(Settings.save(), OK)
		var stored: ConfigFile = _settings_file(profile)
		var written: ConfigFile = ConfigFile.new()
		assert_eq(written.load(_user_path("settings.cfg")), OK)
		assert_eq(int(written.get_value("meta", "version", 0)), 1, "%s: the settings version did not change" % profile)
		for section: String in stored.get_sections():
			for key: String in stored.get_section_keys(section):
				if section == "bindings" and Settings.get_bindings(StringName(key)).is_empty():
					continue
				assert_true(written.has_section_key(section, key), "%s: [%s] %s is written back" % [profile, section, key])
				if section != "bindings":
					assert_eq(written.get_value(section, key), stored.get_value(section, key), "%s: [%s] %s" % [
						profile, section, key])
		Settings.load_settings()
		for key: String in KEYS_1_0:
			var parts: PackedStringArray = key.split("/")
			if stored.has_section_key(parts[0], parts[1]):
				assert_eq(Settings.get_value(key), stored.get_value(parts[0], parts[1]), "%s: %s after a 2.0 save" % [
					profile, key])


## 2.0 added the action `swap` (V, `;`, pad LB by default). A 1.0 player who had bound one of those inputs must not
## end up with one input on two actions: the player's binding wins, `swap` keeps its other defaults.
func test_a_1_0_binding_is_never_shared_with_a_new_2_0_action() -> void:
	_install("mid_beginner")
	Settings.load_settings()
	var owners: Dictionary = {}
	for action: StringName in Defs.GAME_ACTIONS:
		for token: String in _tokens(Settings.get_bindings(action)):
			assert_false(owners.has(token), "%s is on '%s' and on '%s'" % [token, owners.get(token, ""), action])
			owners[token] = action
	assert_eq(owners.get("key:%d" % KEY_V), &"jump", "V jumps, as the 1.0 player set it")
	assert_eq(owners.get("joy_button:%d" % JOY_BUTTON_LEFT_SHOULDER), &"look", "pad LB looks, as the 1.0 player set it")
	assert_true(Settings.get_bindings(Defs.ACT_SWAP, Defs.Device.KEYBOARD).size() >= 1, "swap keeps a key")


# --- Level codes ---------------------------------------------------------------------------------------------------

func test_every_level_code_of_1_0_opens_the_same_stage() -> void:
	var codes: int = 0
	for line: String in FileAccess.get_file_as_string(DIR + "level_codes.txt").split("\n"):
		var parts: PackedStringArray = line.strip_edges().split(" ", false)
		if parts.size() != 3 or line.begins_with("#"):
			continue
		for typed: String in [parts[0], parts[0].to_lower(), parts[0].replace("0", "O").replace("1", "I")]:
			var found: Dictionary = Levels.find_by_password(typed)
			assert_eq(String(found.get("level_id", &"")), parts[1], "the code %s (typed %s)" % [parts[0], typed])
			assert_eq(int(found.get("difficulty", -1)), parts[2].to_int(), "the difficulty of %s" % parts[0])
		codes += 1
	assert_eq(codes, 20, "the 20 codes of the 15 stages of 1.0.0")
