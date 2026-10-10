extends TestCase
## A good backup is never thrown away for a bad file (Save), and an unreadable settings file is kept before the
## defaults replace it (Settings). The runner redirects both to res://build/....
##
## The release verifier's finding (build/engine_requests/wf12_p4_verify_to_orchestrator.txt, 3b and 3e): with an
## unreadable save.json beside a good save.json.bak, the first save removed the good backup and made the unreadable
## file the backup; an unreadable settings.cfg was replaced by the defaults with no copy kept. The five kinds of an
## unreadable file below are his.

const DIR_1_0: String = "res://tests/data/saves_1_0/"
## The real 1.0.0 profiles that hold a save.json.bak beside their save.json (tests/test_core_save_1_0.gd).
const PROFILES_1_0: PackedStringArray = ["mid_beginner", "mid_expert", "finished"]
const KINDS: PackedStringArray = ["garbage", "half_written", "empty", "wrong_json_type", "zero_filled"]
const DIFFICULTIES: Array[int] = [Defs.Difficulty.BEGINNER, Defs.Difficulty.EXPERT]
## The files of a user folder this test may make (and removes); a name that begins with one of the prefixes too.
const USER_FILES: PackedStringArray = ["save.json", "save.json.bak", "save.json.tmp", "settings.cfg"]
const USER_PREFIXES: PackedStringArray = ["save.v", "save.bad", "settings.bad"]


func before_each() -> void:
	Save.report_damage = false
	_clear_user_folder()
	Save.load_game()
	Settings.load_settings()
	Settings.reset()


func after_each() -> void:
	_clear_user_folder()
	Save.load_game()
	Settings.load_settings()
	Settings.reset()
	Save.report_damage = true


# --- Helpers -----------------------------------------------------------------------------------------------------

func _user_path(file: String) -> String:
	return Save.storage_dir + file


func _is_user_file(file: String) -> bool:
	if USER_FILES.has(file):
		return true
	for prefix: String in USER_PREFIXES:
		if file.begins_with(prefix):
			return true
	return false


func _clear_user_folder() -> void:
	var dir: DirAccess = DirAccess.open(Save.storage_dir)
	if dir == null:
		return
	for file: String in dir.get_files():
		if _is_user_file(file):
			dir.remove(file)
	# A folder a test put in the way of a copy.
	for folder: String in dir.get_directories():
		if _is_user_file(folder):
			dir.remove(folder)


func _bytes(path: String) -> PackedByteArray:
	return FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else PackedByteArray()


func _write(path: String, bytes: PackedByteArray) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()


## Every file of the user folder that belongs to the game, with its bytes.
func _snapshot() -> Dictionary:
	var files: Dictionary = {}
	for file: String in DirAccess.get_files_at(Save.storage_dir):
		if _is_user_file(file):
			files[file] = _bytes(_user_path(file))
	return files


func _names(snapshot: Dictionary) -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray(snapshot.keys())
	names.sort()
	return names


func _parsed(bytes: PackedByteArray) -> Dictionary:
	var parsed: Variant = JSON.parse_string(bytes.get_string_from_utf8())
	return parsed if parsed is Dictionary else {}


## One of the five kinds of an unreadable file, made from a readable one.
func _damaged(kind: String, good: PackedByteArray) -> PackedByteArray:
	var bytes: PackedByteArray = PackedByteArray()
	match kind:
		"garbage":
			# Every byte value, four times over (1 024 bytes of no text at all).
			for i: int in 1024:
				bytes.append(i % 256)
		"half_written":
			bytes = good.slice(0, good.size() / 2)
		"empty":
			pass
		"wrong_json_type":
			bytes = "[1, 2, 3]".to_utf8_buffer()
		"zero_filled":
			bytes.resize(good.size())
	return bytes


## Every value of a parsed save file as "path = value" lines (an item per leaf; a list's items by position).
func _items(value: Variant, path: String = "") -> PackedStringArray:
	var items: PackedStringArray = PackedStringArray()
	if value is Dictionary:
		for key: Variant in value:
			items.append_array(_items(value[key], "%s/%s" % [path, str(key)]))
	elif value is Array:
		for i: int in (value as Array).size():
			items.append_array(_items(value[i], "%s[%d]" % [path, i]))
	else:
		items.append("%s = %s" % [path, str(value)])
	return items


## A 2.0 profile with progress in several namespaces, written twice: {"older": the bytes of the first save (what
## save.json.bak holds after the second), "newer": the bytes of the second}. Both are files the game wrote and read
## again, so a save of what was loaded from them writes the same values.
func _make_2_0_profile() -> Dictionary:
	var coop2: String = Save.space(Defs.GameMode.COOP, 2, Defs.Difficulty.EXPERT)
	var solo2: String = Save.space(Defs.GameMode.SINGLE, 2, Defs.Difficulty.BEGINNER)
	Save.unlock_level(&"w1_l2", Defs.Difficulty.BEGINNER)
	Save.unlock_level(&"w2_l1", Defs.Difficulty.BEGINNER)
	Save.record_level_result(&"w1_l1", Defs.Difficulty.BEGINNER, 12500, 80)
	Save.unlock_level(&"w1_l2", Defs.Difficulty.EXPERT)
	Save.record_level_result(&"w1_l1", Defs.Difficulty.EXPERT, 22000, 64)
	Save.set_game_completed(Defs.Difficulty.BEGINNER)
	Save.unlock_level_in(coop2, &"w5_l2")
	Save.record_level_result_in(coop2, &"w5_l1", 52000, 71)
	Save.submit_score_in(coop2, 52000)
	Save.set_belt_in(coop2, 0, Defs.Weapon.AXE, Defs.Weapon.CLUB)
	Save.set_belt_in(coop2, 1, Defs.Weapon.SPEAR, PlayerRun.BELT_EMPTY)
	Save.submit_score_in(solo2, 30000)
	Save.unlock_level_in(solo2, &"w5_l2")
	for index: int in [0, 4, 19]:
		Save.add_painting(index)
	Save.unlock(Save.UNLOCK_MURAL)
	Save.add_code_stone("w1_l1:0")
	Save.add_code_stone("w2_l1:3")
	Save.add_stat("enemies_killed", 41)
	assert_eq(Save.save_game(), OK)
	Save.load_game()
	assert_eq(Save.save_game(), OK)
	var older: PackedByteArray = _bytes(_user_path("save.json"))
	Save.load_game()
	Save.unlock_level_in(coop2, &"w6_l1")
	Save.add_painting(27)
	Save.add_stat("enemies_killed", 9)
	assert_eq(Save.save_game(), OK)
	assert_eq(_bytes(_user_path("save.json.bak")), older, "the first save is the backup of the second")
	return {"older": older, "newer": _bytes(_user_path("save.json"))}


## Put an unreadable save.json beside a readable save.json.bak into an otherwise empty user folder.
func _install_damaged(damaged: PackedByteArray, good_backup: PackedByteArray) -> void:
	_clear_user_folder()
	_write(_user_path("save.json"), damaged)
	_write(_user_path("save.json.bak"), good_backup)


## What Save answers must be what the 1.0 file `original` holds; returns how many facts were compared.
func _assert_1_0_progress(label: String, original: Dictionary) -> int:
	var facts: int = 0
	for difficulty: int in DIFFICULTIES:
		var mode: String = Defs.difficulty_name(difficulty)
		var unlocked: Array = original["unlocked"][mode]
		var now: Array[StringName] = Save.get_unlocked_levels(difficulty)
		assert_eq(now.size(), unlocked.size(), "%s %s: as many unlocked levels" % [label, mode])
		for i: int in mini(unlocked.size(), now.size()):
			assert_eq(String(now[i]), str(unlocked[i]), "%s %s: unlocked level %d" % [label, mode, i])
			facts += 1
		var results: Dictionary = original["results"][mode]
		for id: Variant in results:
			var kept: Dictionary = Save.get_level_result(StringName(str(id)), difficulty)
			for field: String in ["percent", "score", "clears"]:
				assert_eq(int(kept[field]), int(results[id][field]), "%s %s: %s of %s" % [label, mode, field, id])
				facts += 1
		assert_eq(Save.is_game_completed(difficulty), bool(original["completed"][mode]), "%s %s: completed" % [label, mode])
		facts += 1
	for stone: Variant in original["code_stones"]:
		assert_true(Save.has_code_stone(str(stone)), "%s: code stone %s" % [label, stone])
		facts += 1
	for stat: Variant in original["stats"]:
		assert_eq(Save.get_stat(str(stat)), int(original["stats"][stat]), "%s: statistic %s" % [label, stat])
		facts += 1
	assert_eq(Save.get_high_score(), int(original["high_score"]), "%s: the high score" % label)
	return facts + 1


# --- Save: a version 2 folder ---------------------------------------------------------------------------------------

func test_a_damaged_2_0_save_never_costs_the_good_backup() -> void:
	var profile: Dictionary = _make_2_0_profile()
	var good: PackedByteArray = profile["older"]
	var good_items: PackedStringArray = _items(_parsed(good))
	assert_true(good_items.size() > 40, "the backup holds a profile worth keeping (%d items)" % good_items.size())
	var compared: int = 0
	for kind: String in KINDS:
		var damaged: PackedByteArray = _damaged(kind, profile["newer"])
		_install_damaged(damaged, good)
		var before: Dictionary = _snapshot()
		Save.load_game()
		assert_eq(_snapshot(), before, "%s: loading writes nothing" % kind)
		assert_eq(Save.unreadable_files(), PackedStringArray(["save.json"]), "%s: the file is known to be unreadable" % kind)
		assert_false(Save.was_migrated(), kind)
		assert_true(Save.has_progress(), "%s: the game plays on with the backup's progress" % kind)
		# The first save: everything of the backup is in the new file, the backup stays, the bad file is set aside.
		assert_eq(Save.save_game(), OK, kind)
		assert_eq(_names(_snapshot()), PackedStringArray(["save.bad.json", "save.json", "save.json.bak"]),
			"%s: the new save, the good backup and the file set aside - nothing else" % kind)
		assert_eq(_bytes(_user_path("save.json.bak")), good, "%s: the good backup is still there, byte for byte" % kind)
		assert_eq(_bytes(_user_path("save.bad.json")), damaged, "%s: the unreadable file is set aside, byte for byte" % kind)
		var written: Dictionary = _parsed(_bytes(_user_path("save.json")))
		assert_eq(written, _parsed(good), "%s: the new save.json holds what the backup held" % kind)
		var written_items: PackedStringArray = _items(written)
		for item: String in good_items:
			assert_true(written_items.has(item), "%s: '%s' of the backup is in the new save" % [kind, item])
			compared += 1
		assert_eq(Save.unreadable_files(), PackedStringArray(), "%s: nothing waits to be set aside any more" % kind)
		# Read again from the disk: the same state, from a readable save.json.
		Save.load_game()
		assert_eq(Save.unreadable_files(), PackedStringArray(), kind)
		assert_true(Save.is_level_unlocked_in(Save.space(Defs.GameMode.COOP, 2, Defs.Difficulty.EXPERT), &"w5_l2"), kind)
		assert_false(Save.is_level_unlocked_in(Save.space(Defs.GameMode.COOP, 2, Defs.Difficulty.EXPERT), &"w6_l1"),
			"%s: what only the unreadable file held is gone - the backup is the older save" % kind)
		assert_eq(Save.get_paintings(), PackedInt32Array([0, 4, 19]), kind)
		assert_eq(Save.get_stat("enemies_killed"), 41, kind)
		assert_eq(Save.get_belt_in(Save.space(Defs.GameMode.COOP, 2, Defs.Difficulty.EXPERT), 1),
			{"hand": Defs.Weapon.SPEAR, "belt": PlayerRun.BELT_EMPTY}, kind)
		# The second save: the new save.json was written and read back, so it may take the backup's place now.
		var first_save: PackedByteArray = _bytes(_user_path("save.json"))
		Save.add_painting(29)
		assert_eq(Save.save_game(), OK, kind)
		assert_eq(_names(_snapshot()), PackedStringArray(["save.bad.json", "save.json", "save.json.bak"]), kind)
		assert_eq(_bytes(_user_path("save.json.bak")), first_save, "%s: the ordinary rotation goes on" % kind)
		assert_eq(_bytes(_user_path("save.bad.json")), damaged, "%s: the file set aside is never touched again" % kind)
	print("    damaged 2.0 saves: %d kinds, %d items of the backup compared in the first new save, none lost" % [
		KINDS.size(), compared])


func test_a_readable_save_rotates_as_it_always_did() -> void:
	var profile: Dictionary = _make_2_0_profile()
	Save.load_game()
	assert_eq(Save.unreadable_files(), PackedStringArray())
	assert_eq(Save.save_game(), OK)
	assert_eq(_names(_snapshot()), PackedStringArray(["save.json", "save.json.bak"]), "no file is set aside")
	assert_eq(_bytes(_user_path("save.json.bak")), profile["newer"] as PackedByteArray, "the last save is the backup")
	assert_eq(_parsed(_bytes(_user_path("save.json"))), _parsed(profile["newer"]))


func test_a_second_bad_file_gets_a_number_and_the_same_one_is_kept_once() -> void:
	var profile: Dictionary = _make_2_0_profile()
	var first_bad: PackedByteArray = _damaged("garbage", profile["newer"])
	var second_bad: PackedByteArray = _damaged("wrong_json_type", profile["newer"])
	assert_eq(Save.bad_file_name(), "save.bad.json")
	assert_eq(Save.bad_file_name(2), "save.bad.2.json")
	_install_damaged(first_bad, profile["older"])
	Save.load_game()
	assert_eq(Save.save_game(), OK)
	# The save file is damaged again, in another way.
	_write(_user_path("save.json"), second_bad)
	Save.load_game()
	assert_true(Save.has_progress(), "the backup carries the game once more")
	assert_eq(Save.save_game(), OK)
	assert_eq(_bytes(_user_path("save.bad.json")), first_bad, "the first file set aside keeps its name and bytes")
	assert_eq(_bytes(_user_path("save.bad.2.json")), second_bad, "the second gets a number")
	assert_eq(_bytes(_user_path("save.json.bak")), profile["older"] as PackedByteArray, "and the good backup is still the one")
	# The first damage once more: its bytes are kept already, so no third copy.
	_write(_user_path("save.json"), first_bad)
	Save.load_game()
	assert_eq(Save.save_game(), OK)
	assert_eq(_names(_snapshot()), PackedStringArray(["save.bad.2.json", "save.bad.json", "save.json", "save.json.bak"]))
	assert_eq(int(_parsed(_bytes(_user_path("save.json")))["version"]), 2)


func test_two_unreadable_files_are_both_set_aside_and_none_becomes_the_backup() -> void:
	var profile: Dictionary = _make_2_0_profile()
	var bad_save: PackedByteArray = _damaged("half_written", profile["newer"])
	var bad_backup: PackedByteArray = _damaged("garbage", profile["older"])
	_install_damaged(bad_save, bad_backup)
	var before: Dictionary = _snapshot()
	Save.load_game()
	assert_eq(_snapshot(), before, "loading writes nothing")
	assert_false(Save.has_progress(), "no readable file: a fresh save, the game is never blocked")
	assert_eq(Save.unreadable_files(), PackedStringArray(["save.json", "save.json.bak"]))
	Save.unlock_level(&"w1_l2", Defs.Difficulty.BEGINNER)
	assert_eq(Save.save_game(), OK)
	assert_eq(_names(_snapshot()), PackedStringArray(["save.bad.2.json", "save.bad.json", "save.json"]),
		"an unreadable file is no backup")
	assert_eq(_bytes(_user_path("save.bad.json")), bad_save)
	assert_eq(_bytes(_user_path("save.bad.2.json")), bad_backup)
	Save.load_game()
	assert_true(Save.is_level_unlocked(&"w1_l2", Defs.Difficulty.BEGINNER))
	# A missing save.json beside an unreadable backup: the same care.
	_clear_user_folder()
	_write(_user_path("save.json.bak"), bad_backup)
	Save.load_game()
	assert_eq(Save.unreadable_files(), PackedStringArray(["save.json.bak"]))
	assert_eq(Save.save_game(), OK)
	assert_eq(_names(_snapshot()), PackedStringArray(["save.bad.json", "save.json"]))
	assert_eq(_bytes(_user_path("save.bad.json")), bad_backup)


func test_nothing_is_replaced_while_the_unreadable_file_cannot_be_set_aside() -> void:
	var profile: Dictionary = _make_2_0_profile()
	var damaged: PackedByteArray = _damaged("half_written", profile["newer"])
	_install_damaged(damaged, profile["older"])
	# Something sits where the file belongs (a folder of that name): it cannot be set aside.
	assert_eq(DirAccess.make_dir_absolute(_user_path(Save.bad_file_name())), OK)
	Save.load_game()
	Save.unlock_level(&"w3_l1", Defs.Difficulty.EXPERT)
	expect_errors(1)
	assert_eq(Save.save_game(), ERR_FILE_CANT_WRITE, "no save over a file that is not kept")
	assert_eq(_bytes(_user_path("save.json")), damaged, "the unreadable file is where it was")
	assert_eq(_bytes(_user_path("save.json.bak")), profile["older"] as PackedByteArray, "and so is the good backup")
	assert_eq(Save.unreadable_files(), PackedStringArray(["save.json"]), "it still waits")
	# The obstacle goes away: the next save sets it aside and loses nothing played meanwhile.
	assert_eq(DirAccess.remove_absolute(ProjectSettings.globalize_path(_user_path(Save.bad_file_name()))), OK)
	assert_eq(Save.save_game(), OK)
	assert_eq(_bytes(_user_path("save.bad.json")), damaged)
	assert_eq(_bytes(_user_path("save.json.bak")), profile["older"] as PackedByteArray)
	Save.load_game()
	assert_true(Save.is_level_unlocked(&"w3_l1", Defs.Difficulty.EXPERT))
	assert_true(Save.is_level_unlocked(&"w1_l2", Defs.Difficulty.EXPERT), "the backup's progress")


# --- Save: the real 1.0.0 profiles ---------------------------------------------------------------------------------

func test_a_damaged_save_beside_a_1_0_backup_keeps_the_copy_the_backup_and_the_bad_file() -> void:
	var facts: int = 0
	for profile: String in PROFILES_1_0:
		var good: PackedByteArray = _bytes(DIR_1_0 + profile + "/save.json.bak")
		var original: Dictionary = _parsed(good)
		assert_eq(int(original.get("version", 0)), 1, "%s: save.json.bak is a file 1.0.0 wrote" % profile)
		for kind: String in KINDS:
			var label: String = "%s, %s" % [profile, kind]
			var damaged: PackedByteArray = _damaged(kind, _bytes(DIR_1_0 + profile + "/save.json"))
			_install_damaged(damaged, good)
			var before: Dictionary = _snapshot()
			Save.load_game()
			assert_eq(_snapshot(), before, "%s: loading writes nothing" % label)
			assert_true(Save.was_migrated(), "%s: the 1.0 backup was read" % label)
			assert_eq(Save.migration_losses(), PackedStringArray(), "%s: the migration lost nothing" % label)
			assert_eq(Save.legacy_backup_path(), "", "%s: no copy is made by reading" % label)
			facts += _assert_1_0_progress(label, original)
			# The first 2.0 save.
			assert_eq(Save.save_game(), OK, label)
			assert_eq(_names(_snapshot()), PackedStringArray(["save.bad.json", "save.json", "save.json.bak", "save.v1.json"]),
				"%s: the new save, the good 1.0 backup, its untouched copy and the file set aside" % label)
			assert_eq(Save.legacy_backup_path(), _user_path("save.v1.json"), label)
			assert_eq(_bytes(_user_path("save.v1.json")), good, "%s: save.v1.json is the 1.0 file, byte for byte" % label)
			assert_eq(_bytes(_user_path("save.json.bak")), good, "%s: the good backup is still there, byte for byte" % label)
			assert_eq(_bytes(_user_path("save.bad.json")), damaged, "%s: the unreadable file is set aside" % label)
			assert_eq(int(_parsed(_bytes(_user_path("save.json"))).get("version", 0)), 2, label)
			# Read again from the disk: version 2, and still every fact of the 1.0 backup.
			Save.load_game()
			assert_false(Save.was_migrated(), "%s: the new save.json is a version 2 file" % label)
			_assert_1_0_progress(label + " (read again)", original)
			# Later saves rotate the ordinary backup; the copy and the file set aside stay as they are.
			assert_eq(Save.save_game(), OK, label)
			assert_eq(int(_parsed(_bytes(_user_path("save.json.bak"))).get("version", 0)), 2, "%s: the backup moved on" % label)
			assert_eq(_bytes(_user_path("save.v1.json")), good, "%s: the copy of the 1.0 file is never written again" % label)
			assert_eq(_bytes(_user_path("save.bad.json")), damaged, label)
			assert_eq(_names(_snapshot()), PackedStringArray(["save.bad.json", "save.json", "save.json.bak", "save.v1.json"]),
				label)
	assert_true(facts > 300, "three profiles, five kinds: more than 300 facts (compared %d)" % facts)
	print("    damaged saves beside 1.0 backups: %d profiles x %d kinds, %d facts compared, none lost" % [
		PROFILES_1_0.size(), KINDS.size(), facts])


## The untouched copy of the 1.0 file comes first: while it cannot be made, the unreadable file is not set aside
## and nothing else is written either.
func test_the_1_0_copy_is_still_made_before_anything_else_is_touched() -> void:
	var good: PackedByteArray = _bytes(DIR_1_0 + "mid_expert/save.json.bak")
	for kind: String in KINDS:
		var damaged: PackedByteArray = _damaged(kind, _bytes(DIR_1_0 + "mid_expert/save.json"))
		_install_damaged(damaged, good)
		assert_eq(DirAccess.make_dir_absolute(_user_path(Save.legacy_backup_name(1))), OK, kind)
		Save.load_game()
		var before: Dictionary = _snapshot()
		expect_errors(1)
		assert_eq(Save.save_game(), ERR_FILE_CANT_WRITE, "%s: no write without the copy of the 1.0 file" % kind)
		assert_eq(_snapshot(), before, "%s: no file changed, appeared or vanished" % kind)
		assert_eq(_bytes(_user_path("save.json")), damaged, kind)
		assert_eq(_bytes(_user_path("save.json.bak")), good, kind)
		assert_eq(DirAccess.remove_absolute(ProjectSettings.globalize_path(_user_path(Save.legacy_backup_name(1)))), OK)
		assert_eq(Save.save_game(), OK, kind)
		assert_eq(_bytes(_user_path("save.v1.json")), good, "%s: the copy first, byte for byte" % kind)
		assert_eq(_bytes(_user_path("save.json.bak")), good, kind)
		assert_eq(_bytes(_user_path("save.bad.json")), damaged, kind)


# --- Settings -------------------------------------------------------------------------------------------------------

## The unreadable settings files: [name, bytes, engine errors a load logs] - a ConfigFile parse error is one.
func _bad_settings() -> Array[Array]:
	var zeros: PackedByteArray = PackedByteArray()
	zeros.resize(64)
	var garbage: PackedByteArray = PackedByteArray([0x00, 0xff])
	garbage.append_array("[[[ not a config \n=== ".to_utf8_buffer())
	garbage.append_array(PackedByteArray([0x01, 0x02]))
	return [
		["garbage", garbage, 1],
		["half_written", "[audio]\nmaster=0.5\nmusic=".to_utf8_buffer(), 1],
		["zero_filled", zeros, 0],
		["another_file", '{"version": 2, "spaces": {}}'.to_utf8_buffer(), 0],
	]


func test_an_unreadable_settings_file_is_kept_before_the_defaults_replace_it() -> void:
	for entry: Array in _bad_settings():
		var kind: String = entry[0]
		var damaged: PackedByteArray = entry[1]
		_clear_user_folder()
		_write(_user_path("settings.cfg"), damaged)
		expect_errors(int(entry[2]))
		Settings.load_settings()
		assert_eq(_snapshot(), {"settings.cfg": damaged}, "%s: loading writes nothing" % kind)
		assert_true(Settings.has_unreadable_file(), "%s: the file is known to be unreadable" % kind)
		assert_almost_eq(Settings.get_float("audio/music"), 0.8, 0.0001, "%s: the defaults are in use" % kind)
		assert_false(Settings.has_custom_bindings(), kind)
		# The first save: the unreadable file is kept, then the defaults take its place.
		Settings.set_value("audio/music", 0.25)
		assert_eq(Settings.save(), OK, kind)
		assert_eq(_names(_snapshot()), PackedStringArray(["settings.bad.cfg", "settings.cfg"]), kind)
		assert_eq(_bytes(_user_path("settings.bad.cfg")), damaged, "%s: kept byte for byte" % kind)
		assert_false(Settings.has_unreadable_file(), kind)
		var written: ConfigFile = ConfigFile.new()
		assert_eq(written.load(_user_path("settings.cfg")), OK, "%s: the new file is readable" % kind)
		assert_eq(int(written.get_value("meta", "version", 0)), Settings.VERSION, kind)
		# Later saves and loads leave the kept file alone and make no second one.
		Settings.load_settings()
		assert_false(Settings.has_unreadable_file(), kind)
		assert_almost_eq(Settings.get_float("audio/music"), 0.25, 0.0001, kind)
		assert_eq(Settings.save(), OK, kind)
		assert_eq(_names(_snapshot()), PackedStringArray(["settings.bad.cfg", "settings.cfg"]), kind)
		assert_eq(_bytes(_user_path("settings.bad.cfg")), damaged, kind)
		Settings.reset()


func test_a_second_bad_settings_file_gets_a_number_and_the_same_one_is_kept_once() -> void:
	var kinds: Array[Array] = _bad_settings()
	var first: PackedByteArray = kinds[2][1]
	var second: PackedByteArray = kinds[3][1]
	assert_eq(Settings.bad_file_name(), "settings.bad.cfg")
	assert_eq(Settings.bad_file_name(2), "settings.bad.2.cfg")
	for bytes: PackedByteArray in [first, second, first]:
		_write(_user_path("settings.cfg"), bytes)
		Settings.load_settings()
		assert_true(Settings.has_unreadable_file())
		assert_eq(Settings.save(), OK)
	assert_eq(_names(_snapshot()), PackedStringArray(["settings.bad.2.cfg", "settings.bad.cfg", "settings.cfg"]),
		"two different unreadable files, two kept; the first one a second time adds nothing")
	assert_eq(_bytes(_user_path("settings.bad.cfg")), first)
	assert_eq(_bytes(_user_path("settings.bad.2.cfg")), second)


func test_a_readable_or_missing_settings_file_is_never_set_aside() -> void:
	Settings.load_settings()
	assert_false(Settings.has_unreadable_file(), "no file: nothing to keep")
	assert_eq(Settings.save(), OK)
	assert_eq(_names(_snapshot()), PackedStringArray(["settings.cfg"]))
	# A real 1.0.0 settings file with changed options and rebound keys.
	var real: PackedByteArray = _bytes(DIR_1_0 + "mid_beginner/settings.cfg")
	assert_true(real.size() > 100)
	_write(_user_path("settings.cfg"), real)
	Settings.load_settings()
	assert_false(Settings.has_unreadable_file(), "a 1.0 file is readable")
	assert_almost_eq(Settings.get_float("audio/music"), 0.5, 0.0001, "and read")
	assert_eq(Settings.save(), OK)
	assert_eq(_names(_snapshot()), PackedStringArray(["settings.cfg"]), "no file is set aside")


func test_the_defaults_never_replace_a_settings_file_that_could_not_be_kept() -> void:
	var damaged: PackedByteArray = _bad_settings()[2][1]
	_write(_user_path("settings.cfg"), damaged)
	# Something sits where the kept file belongs (a folder of that name).
	assert_eq(DirAccess.make_dir_absolute(_user_path(Settings.bad_file_name())), OK)
	Settings.load_settings()
	expect_errors(1)
	assert_eq(Settings.save(), ERR_FILE_CANT_WRITE)
	assert_eq(_bytes(_user_path("settings.cfg")), damaged, "the unreadable file is where it was")
	assert_true(Settings.has_unreadable_file(), "it still waits")
	assert_eq(DirAccess.remove_absolute(ProjectSettings.globalize_path(_user_path(Settings.bad_file_name()))), OK)
	assert_eq(Settings.save(), OK)
	assert_eq(_bytes(_user_path("settings.bad.cfg")), damaged)
	var written: ConfigFile = ConfigFile.new()
	assert_eq(written.load(_user_path("settings.cfg")), OK)
