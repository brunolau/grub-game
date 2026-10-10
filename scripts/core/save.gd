extends Node
## Autoload `Save`: persistent progress in `user://save.json` (versioned JSON, atomic write).
##
## CONTRACT FILE (docs/ARCHITECTURE.md 3.6). Owner: core. Public methods are frozen.
##
## Replaces the original's machine-specific level codes (GAMEPLAY.md 12.4): the highest level reached is stored
## per difficulty, plus best results per level. There are no mid-level saves and no continues.
## Difficulty arguments are Defs.Difficulty values; level ids are the level file names without extension.
##
## Version 2 (docs/expansion/PLAN.md P0.4, DESIGN.md A.1 / C.1 / C.9): progress lives in NAMESPACES, one per
## (mode, book, difficulty) - "single/book1/beginner" ... "coop/book2/expert" ([method space]) - each with its own
## unlocked levels, level results, completion flag, high score and carried weapons (`belt`). The 1.0 methods that
## take a difficulty act on (single, Book I) of that difficulty, exactly as before; the `*_in(space, ...)` twins act
## on any namespace. Profile-wide (every mode): the high-score record of any run, code stones, statistics, Cave
## Paintings and unlocks. A 1.0 file (version 1) is migrated on load into (single, Book I); nothing is lost.
## Versus keeps no campaign progress (no namespace is created for it unless a caller writes one).
##
## The file of another version is never written over before it is safe (2.0.0): when [method load_game] reads a
## save.json (or its backup) whose version is not VERSION, the migration runs in memory and is checked against the
## file ([method migration_losses]); nothing is written. The first [method save_game] after it copies the file's
## bytes to `save.v<version>.json` next to it and reads the copy back ([method legacy_backup_path]); only then does
## it replace save.json, and while that copy cannot be made it writes nothing and returns an error. The game never
## changes or removes the copy: a player who goes back to 1.0.0 puts it back as save.json. (Should the check ever
## name a loss, each one is logged as an error; the copy is still made before anything is written, so the 1.0 file
## itself is never lost.)
##
## A good backup is never thrown away for a bad file (2.0.0): a save.json or save.json.bak that is there and cannot
## be read - garbage, a write that was cut off, an empty or zero-filled file, JSON that is no object - is reported
## and remembered by [method load_game], which still writes nothing. The first [method save_game] after it writes the
## new file and reads it back, then SETS THE UNREADABLE FILE ASIDE under [method bad_file_name] ("save.bad.json";
## "save.bad.2.json" ... when that name holds other bytes) instead of rotating it into save.json.bak: the readable
## backup the progress came from stays where it is until the save after that one, when the new, read-back save.json
## takes its place. The game never deletes an unreadable file it has not kept byte for byte.
##
## Layout of save.json, version 2:
##   {"version": 2, "high_score": int, "code_stones": [String], "stats": {String: int},
##    "paintings": [int], "unlocks": {"all": bool, "rewards": [String]},
##    "spaces": {"single/book1/beginner": {"unlocked": [String], "results": {id: {"percent", "score", "clears"}},
##               "completed": bool, "high_score": int, "belt": [{"hand": int, "belt": int}, ...]}, ...}}

## Data was written to disk.
signal saved
## Data was read from disk (or reset).
signal loaded
## 2.0: a found Cave Painting opened reward `reward` (Save.UNLOCK_*; UnlockTable.REWARDS) that was closed before -
## emitted by add_painting, once per reward, in ladder order (the HUD's / map's "new reward" notice).
signal reward_unlocked(reward: StringName)

const FILE_NAME: String = "save.json"
const TEMP_NAME: String = "save.json.tmp"
const BACKUP_NAME: String = "save.json.bak"
## Bump when the layout changes; add a step to _migrate().
const VERSION: int = 2
## The untouched copy of a save file of another version, kept beside save.json before 2.0 writes over it:
## "save.v1.json" is the file 1.0.0 wrote (see [method legacy_backup_name]).
const LEGACY_BACKUP_NAME: String = "save.v%d.json"
## A later file of the same old version with other content (the player went back to 1.0.0 and returned) gets a
## number instead of replacing the first copy: "save.v1.2.json" ... up to this many.
const LEGACY_BACKUP_MAX: int = 99
## Where an unreadable save.json or save.json.bak is set aside, byte for byte, by the first save after it was found
## (see [method bad_file_name]): "save.bad.json", then "save.bad.2.json" ... up to this many; the last name is used
## again when every one holds other bytes, so a folder full of them never stops the game from saving.
const BAD_NAME: String = "save.bad.json"
const BAD_MAX: int = 99

## Modes that keep campaign progress (Defs.GameMode); a namespace exists for each with both books and difficulties.
const SPACE_MODES: Array[int] = [Defs.GameMode.SINGLE, Defs.GameMode.COOP]
## Campaign books.
const BOOKS: Array[int] = [1, 2]

## Rewards of the Cave Paintings (DESIGN.md C.9), for [method is_unlocked]: each needs a number of paintings
## (Tuning.PAINTING_UNLOCK_*).
## The ladder after cut 3 (DESIGN.md G60): no arena is a reward. An id a file holds that is no reward any more (a
## development save's `mesa_rodeo` / `cloud_top`) is ignored: [method is_unlocked] asks only for the ids below.
const UNLOCK_PATTERNS: StringName = &"patterns"         ## four loincloth patterns for P1-P4
const UNLOCK_LOINCLOTHS: StringName = &"loincloths"     ## four more loincloth patterns
const UNLOCK_VARIANTS: StringName = &"variants"         ## versus variants Big Bounce, Lights Out, Giant Rain
const UNLOCK_SPEAR_PARTY: StringName = &"spear_party"   ## variant Spear Party
const UNLOCK_GOLD: StringName = &"gold"                 ## the golden loincloth palette
const UNLOCK_MURAL: StringName = &"mural"               ## the mural that ends The Long Raft Home
## Paintings each reward needs.
const UNLOCK_PAINTINGS: Dictionary = {
	UNLOCK_PATTERNS: Tuning.PAINTING_UNLOCK_PATTERNS,
	UNLOCK_LOINCLOTHS: Tuning.PAINTING_UNLOCK_LOINCLOTHS,
	UNLOCK_VARIANTS: Tuning.PAINTING_UNLOCK_VARIANTS,
	UNLOCK_SPEAR_PARTY: Tuning.PAINTING_UNLOCK_SPEAR_PARTY,
	UNLOCK_GOLD: Tuning.PAINTING_UNLOCK_GOLD,
	UNLOCK_MURAL: Tuning.PAINTING_UNLOCK_MURAL,
}
## Rewards that Options > Versus > "Unlock everything" opens (the versus content; the mural stays the campaign's).
const UNLOCK_EVERYTHING_REWARDS: Array[StringName] = [
	UNLOCK_PATTERNS, UNLOCK_LOINCLOTHS, UNLOCK_VARIANTS, UNLOCK_SPEAR_PARTY, UNLOCK_GOLD,
]

## Directory of the save file. Tests point it at `res://build/...` so they never touch real user data.
var storage_dir: String = "user://"

## When false a damaged save file is handled silently (error-path tests).
var report_damage: bool = true

var _data: Dictionary = {}
## The file of another version that the data was read from (FILE_NAME or BACKUP_NAME; "" = none) and its version,
## while no untouched copy of it is known to exist: save_game makes that copy first, or writes nothing.
var _legacy_source: String = ""
var _legacy_version: int = 0
## True when the last load_game read a file of another version.
var _migrated: bool = false
## Where the untouched copy of the last migrated file is (a path in storage_dir; "" = no file was migrated).
var _legacy_backup: String = ""
## What the last migration did not carry over (empty = nothing lost, or no file was migrated).
var _migration_losses: PackedStringArray = PackedStringArray()
## The save files (FILE_NAME, BACKUP_NAME) the last load_game found but could not read: save_game sets them aside.
var _unreadable: PackedStringArray = PackedStringArray()


func _ready() -> void:
	load_game()


## Use another directory (created if missing) and reload from it.
func set_storage_dir(dir_path: String) -> void:
	storage_dir = dir_path if dir_path.ends_with("/") else dir_path + "/"
	DirAccess.make_dir_recursive_absolute(storage_dir)
	load_game()


## Read the save file. A missing file yields a fresh save; a damaged file falls back to the backup, then to a
## fresh save (never crashes, never blocks the game). A file of another version (a 1.0 save) is migrated in
## memory and checked; reading writes nothing (see [method save_game]), also when a file cannot be read: that one
## is named in a warning and set aside by the next save ([method unreadable_files]).
func load_game() -> void:
	_legacy_source = ""
	_legacy_version = 0
	_migrated = false
	_legacy_backup = ""
	_migration_losses = PackedStringArray()
	_unreadable = PackedStringArray()
	var source: String = FILE_NAME
	_data = _read(FILE_NAME)
	if _data.is_empty():
		source = BACKUP_NAME
		_data = _read(BACKUP_NAME)
	if _data.is_empty():
		_data = _fresh()
	else:
		var version: int = _int_value(_data.get("version"))
		if version != VERSION:
			var original: Dictionary = _data.duplicate(true)
			_data = _migrate(_data, version)
			_fill_missing(_data)
			if version < VERSION:
				_migration_losses = _v1_losses(original, _data)
				for loss: String in _migration_losses:
					push_error("Save: the migration of %s (version %d) lost %s" % [source, version, loss])
			_migrated = true
			_legacy_source = source
			_legacy_version = version
		else:
			_fill_missing(_data)
	loaded.emit()


## Write the save file atomically (temp file, read back, then rename; the previous file becomes the backup). When
## the data came from a file of another version, that file is first copied untouched to
## [method legacy_backup_path]; if the copy cannot be made, nothing is written and ERR_FILE_CANT_WRITE is returned: a
## 1.0 save is never replaced before it is safe. A file the last [method load_game] could not read is set aside
## ([method bad_file_name]) and never becomes the backup: the readable backup beside it stays. No file is touched
## before the new one has been written whole (ERR_FILE_CORRUPT when its read-back differs) and while an unreadable
## one is still in the way (ERR_FILE_CANT_WRITE).
func save_game() -> Error:
	if not _legacy_source.is_empty() and not _keep_legacy_copy():
		push_error("Save: %s (version %d) is not written over: its copy %s could not be made" % [
				storage_dir + _legacy_source, _legacy_version, legacy_backup_name(_legacy_version)])
		return ERR_FILE_CANT_WRITE
	_data["version"] = VERSION
	var bytes: PackedByteArray = JSON.stringify(_data, "  ", true).to_utf8_buffer()
	var file: FileAccess = FileAccess.open(storage_dir + TEMP_NAME, FileAccess.WRITE)
	if file == null:
		var open_err: Error = FileAccess.get_open_error()
		push_error("Save: cannot open %s (error %d)" % [storage_dir + TEMP_NAME, open_err])
		return open_err
	file.store_buffer(bytes)
	file.close()
	# Read back, byte for byte, before anything it replaces is touched: a write that a full disk cut off must not
	# push the last good file out of the backup's place one save later.
	if FileAccess.get_file_as_bytes(storage_dir + TEMP_NAME) != bytes:
		push_error("Save: %s was not written whole; the save files are left as they were" % [storage_dir + TEMP_NAME])
		return ERR_FILE_CORRUPT
	var dir: DirAccess = DirAccess.open(storage_dir)
	if dir == null:
		return ERR_CANT_OPEN
	for unreadable: String in _unreadable:
		if dir.file_exists(unreadable) and not _set_aside(dir, unreadable):
			push_error("Save: the unreadable %s could not be set aside as %s; nothing was replaced" % [
					storage_dir + unreadable, BAD_NAME])
			return ERR_FILE_CANT_WRITE
	_unreadable = PackedStringArray()
	if dir.file_exists(FILE_NAME):
		if dir.file_exists(BACKUP_NAME):
			dir.remove(BACKUP_NAME)
		dir.rename(FILE_NAME, BACKUP_NAME)
	var err: Error = dir.rename(TEMP_NAME, FILE_NAME)
	if err != OK:
		push_error("Save: cannot replace %s (error %d)" % [storage_dir + FILE_NAME, err])
		return err
	saved.emit()
	return OK


## Forget all progress (options menu "erase save"). Writes immediately.
func reset() -> void:
	_data = _fresh()
	save_game()
	loaded.emit()


## Name of the untouched copy of a save file of version `version`: "save.v1.json"; `number` > 1 names a later file
## of that version with other content ("save.v1.2.json").
static func legacy_backup_name(version: int, number: int = 1) -> String:
	var base: String = LEGACY_BACKUP_NAME % version
	return base if number <= 1 else "%s.%d.json" % [base.get_basename(), number]


## Path of the untouched copy of the file the last [method load_game] migrated (a 1.0 save: storage_dir +
## "save.v1.json"), or "" when no file of another version was read or nothing was saved since (the copy is made by
## the first [method save_game]).
func legacy_backup_path() -> String:
	return _legacy_backup


## True when the last [method load_game] read a file of another version (and migrated it).
func was_migrated() -> bool:
	return _migrated


## Name of the file an unreadable save file is set aside as: "save.bad.json"; `number` > 1 names a later one with
## other bytes ("save.bad.2.json").
static func bad_file_name(number: int = 1) -> String:
	return BAD_NAME if number <= 1 else "%s.%d.json" % [BAD_NAME.get_basename(), number]


## The save files (FILE_NAME, BACKUP_NAME) the last [method load_game] found and could not read, while they wait
## for the next [method save_game] to set them aside; empty after it.
func unreadable_files() -> PackedStringArray:
	return _unreadable.duplicate()


## What the last migration did not carry into the namespaces, one text per item ("unlocked beginner w1_l2"); empty
## when nothing was lost. Entries of a 1.0 file that 1.0.0 itself could not read (wrong types) are not counted.
func migration_losses() -> PackedStringArray:
	return _migration_losses


## True when at least one level beyond the first was reached in any mode (title screen shows "Continue"): in any
## namespace (a 1.0 save: in either difficulty).
func has_progress() -> bool:
	var spaces: Dictionary = _data["spaces"]
	for key: Variant in spaces:
		var unlocked: Array = spaces[key]["unlocked"]
		if unlocked.size() > 0:
			return true
	return false


## True when `level_id` may be started from the level select in the given difficulty.
## The first level of the campaign is always unlocked (the registry decides which one that is).
## (single, Book I) namespace of the difficulty; see [method is_level_unlocked_in].
func is_level_unlocked(level_id: StringName, difficulty: int) -> bool:
	return is_level_unlocked_in(_book1(difficulty), level_id)


## Mark a level as reachable from the level select. Does not write to disk; call save_game(). (single, Book I)
func unlock_level(level_id: StringName, difficulty: int) -> void:
	unlock_level_in(_book1(difficulty), level_id)


## Every unlocked level id of a difficulty. (single, Book I)
func get_unlocked_levels(difficulty: int) -> Array[StringName]:
	return get_unlocked_levels_in(_book1(difficulty))


## Store the result of a completed level, keeping the best percentage and best score. Returns true when a
## record was improved. Does not write to disk; call save_game(). (single, Book I)
func record_level_result(level_id: StringName, difficulty: int, level_score: int, percent: int) -> bool:
	return record_level_result_in(_book1(difficulty), level_id, level_score, percent)


## Best result of a level: {"percent": int, "score": int, "clears": int}; zeros when never completed.
## (single, Book I)
func get_level_result(level_id: StringName, difficulty: int) -> Dictionary:
	return get_level_result_in(_book1(difficulty), level_id)


## Highest total score of any run (the profile record, every mode and namespace).
func get_high_score() -> int:
	return int(_data["high_score"])


## Report the score of a finished run. Returns true when it is a new high score (the profile record; see
## [method submit_score_in] for a namespace's table).
func submit_score(run_score: int) -> bool:
	if run_score > int(_data["high_score"]):
		_data["high_score"] = run_score
		return true
	return false


## True when the game was finished at least once in the given difficulty. (single, Book I)
func is_game_completed(difficulty: int) -> bool:
	return is_game_completed_in(_book1(difficulty))


## Mark the game as finished in the given difficulty. (single, Book I)
func set_game_completed(difficulty: int) -> void:
	set_game_completed_in(_book1(difficulty))


## Code stones (collectible lore, GAMEPLAY.md 12.4) found so far: ids are "<level_id>:<index>".
func add_code_stone(stone_id: String) -> void:
	var stones: Array = _data["code_stones"]
	if not stones.has(stone_id):
		stones.append(stone_id)


func has_code_stone(stone_id: String) -> bool:
	var stones: Array = _data["code_stones"]
	return stones.has(stone_id)


## Free-form counters for statistics / achievements (e.g. "enemies_killed"). Returns the new value.
func add_stat(stat: String, amount: int = 1) -> int:
	var stats: Dictionary = _data["stats"]
	stats[stat] = int(stats.get(stat, 0)) + amount
	return int(stats[stat])


func get_stat(stat: String) -> int:
	var stats: Dictionary = _data["stats"]
	return int(stats.get(stat, 0))


# =================================================================================================================
# 2.0: namespaces (mode x book x difficulty)
# =================================================================================================================

## The namespace of a (mode, book, difficulty): "<mode>/book<n>/<difficulty>", e.g. "coop/book2/expert"
## (Defs.game_mode_name, Defs.difficulty_name). The 1.0 methods use space(Defs.GameMode.SINGLE, 1, difficulty).
static func space(mode: int, book: int, difficulty: int) -> String:
	return "%s/book%d/%s" % [Defs.game_mode_name(mode), book, Defs.difficulty_name(difficulty)]


## Every namespace the save holds (at least the SPACE_MODES x BOOKS x difficulties ones), sorted.
func get_spaces() -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for key: Variant in _data["spaces"]:
		result.append(str(key))
	result.sort()
	return result


## True when `level_id` may be started from the level select of namespace `space_key`.
func is_level_unlocked_in(space_key: String, level_id: StringName) -> bool:
	var unlocked: Array = _read_space(space_key)["unlocked"]
	return unlocked.has(String(level_id))


## Mark a level as reachable from the level select of a namespace. Does not write to disk.
func unlock_level_in(space_key: String, level_id: StringName) -> void:
	var unlocked: Array = _write_space(space_key)["unlocked"]
	if not unlocked.has(String(level_id)):
		unlocked.append(String(level_id))


## Every unlocked level id of a namespace.
func get_unlocked_levels_in(space_key: String) -> Array[StringName]:
	var result: Array[StringName] = []
	for id: Variant in _read_space(space_key)["unlocked"]:
		result.append(StringName(str(id)))
	return result


## Store the result of a completed level in a namespace, keeping the best percentage and best score. Returns true
## when a record was improved. Does not write to disk.
func record_level_result_in(space_key: String, level_id: StringName, level_score: int, percent: int) -> bool:
	var results: Dictionary = _write_space(space_key)["results"]
	var key: String = String(level_id)
	var entry: Dictionary = results.get(key, {"percent": 0, "score": 0, "clears": 0})
	var improved: bool = percent > int(entry["percent"]) or level_score > int(entry["score"])
	entry["percent"] = maxi(int(entry["percent"]), percent)
	entry["score"] = maxi(int(entry["score"]), level_score)
	entry["clears"] = int(entry["clears"]) + 1
	results[key] = entry
	return improved


## Best result of a level in a namespace: {"percent": int, "score": int, "clears": int}; zeros when never completed.
func get_level_result_in(space_key: String, level_id: StringName) -> Dictionary:
	var results: Dictionary = _read_space(space_key)["results"]
	return results.get(String(level_id), {"percent": 0, "score": 0, "clears": 0})


## Highest total score of a run in a namespace (its high-score table; 0 when none). A 1.0 high score did not
## record its difficulty: after the migration it is the profile record ([method get_high_score]) only.
func get_high_score_in(space_key: String) -> int:
	return int(_read_space(space_key)["high_score"])


## Report the score of a finished run of a namespace: updates the namespace's table and the profile record. Returns
## true when it is a new high score of the namespace.
func submit_score_in(space_key: String, run_score: int) -> bool:
	submit_score(run_score)
	var data: Dictionary = _write_space(space_key)
	if run_score > int(data["high_score"]):
		data["high_score"] = run_score
		return true
	return false


## True when the campaign of a namespace was finished at least once.
func is_game_completed_in(space_key: String) -> bool:
	return bool(_read_space(space_key)["completed"])


## Mark the campaign of a namespace as finished.
func set_game_completed_in(space_key: String) -> void:
	_write_space(space_key)["completed"] = true


## The weapons player slot `slot` carried when the run of a namespace was last saved (DESIGN.md C.1: hand and belt
## are kept from stage to stage): {"hand": Defs.Weapon, "belt": Defs.Weapon or PlayerRun.BELT_EMPTY}. The club and
## an empty belt when nothing was stored (so for every 1.0 save). Flow decides whether a continue uses it (C.1
## rule 4: a stage started from a code or the level select begins with the club and an empty belt).
func get_belt_in(space_key: String, slot: int) -> Dictionary:
	var belts: Array = _read_space(space_key)["belt"]
	if slot >= 0 and slot < belts.size() and belts[slot] is Dictionary:
		var stored: Dictionary = belts[slot]
		return {"hand": _weapon_value(stored.get("hand"), Defs.Weapon.CLUB),
				"belt": _weapon_value(stored.get("belt"), PlayerRun.BELT_EMPTY)}
	return {"hand": Defs.Weapon.CLUB, "belt": PlayerRun.BELT_EMPTY}


## Store the weapons of player slot `slot` (0..Defs.MAX_PLAYERS - 1) for a namespace. Does not write to disk.
func set_belt_in(space_key: String, slot: int, hand: int, belt: int) -> void:
	if slot < 0 or slot >= Defs.MAX_PLAYERS:
		push_error("Save.set_belt_in: no player slot %d" % slot)
		return
	var belts: Array = _write_space(space_key)["belt"]
	while belts.size() <= slot:
		belts.append({"hand": Defs.Weapon.CLUB, "belt": PlayerRun.BELT_EMPTY})
	belts[slot] = {"hand": _weapon_value(hand, Defs.Weapon.CLUB), "belt": _weapon_value(belt, PlayerRun.BELT_EMPTY)}


# =================================================================================================================
# 2.0: Cave Paintings and unlocks (profile-wide, DESIGN.md C.9)
# =================================================================================================================

## Record Cave Painting `index` (0..Tuning.PAINTING_COUNT - 1) as found. Returns true when it is new. Does not write
## to disk. A painting that opens a reward announces it ([signal reward_unlocked]; not for a reward already open by
## hand or by "Unlock everything").
func add_painting(index: int) -> bool:
	if index < 0 or index >= Tuning.PAINTING_COUNT:
		push_error("Save.add_painting: no painting %d" % index)
		return false
	var paintings: Array = _data["paintings"]
	if paintings.has(index):
		return false
	var before: int = paintings.size()
	var closed: Array[StringName] = []
	for reward: StringName in UNLOCK_PAINTINGS:
		if not is_unlocked(reward):
			closed.append(reward)
	paintings.append(index)
	paintings.sort()
	for reward: StringName in UnlockTable.rewards_between(before, paintings.size()):
		if closed.has(reward):
			reward_unlocked.emit(reward)
	return true


## True when Cave Painting `index` was found (in any mode).
func has_painting(index: int) -> bool:
	var paintings: Array = _data["paintings"]
	return paintings.has(index)


## Number of Cave Paintings found.
func painting_count() -> int:
	var paintings: Array = _data["paintings"]
	return paintings.size()


## The indices of the Cave Paintings found, ascending.
func get_paintings() -> PackedInt32Array:
	return PackedInt32Array(_data["paintings"])


## True when a reward (UNLOCK_*) is open: enough paintings found (UNLOCK_PAINTINGS), opened by [method unlock],
## or a versus reward while "Unlock everything" is on. An unknown reward is never open.
func is_unlocked(reward: StringName) -> bool:
	if not UNLOCK_PAINTINGS.has(reward):
		return false
	if bool(_data["unlocks"]["all"]) and UNLOCK_EVERYTHING_REWARDS.has(reward):
		return true
	var rewards: Array = _data["unlocks"]["rewards"]
	return rewards.has(String(reward)) or painting_count() >= int(UNLOCK_PAINTINGS[reward])


## Open a reward (UNLOCK_*) regardless of the paintings. Does not write to disk.
func unlock(reward: StringName) -> void:
	if not UNLOCK_PAINTINGS.has(reward):
		push_error("Save.unlock: unknown reward '%s'" % reward)
		return
	var rewards: Array = _data["unlocks"]["rewards"]
	if not rewards.has(String(reward)):
		rewards.append(String(reward))


## Options > Versus > "Unlock everything" (DESIGN.md C.9): opens UNLOCK_EVERYTHING_REWARDS. Does not write to disk.
func set_unlock_everything(on: bool) -> void:
	_data["unlocks"]["all"] = on


## True while "Unlock everything" is on.
func is_unlock_everything() -> bool:
	return bool(_data["unlocks"]["all"])


func _fresh() -> Dictionary:
	var data: Dictionary = {}
	_fill_missing(data)
	return data


func _fill_missing(data: Dictionary) -> void:
	data["version"] = VERSION
	if not data.get("spaces") is Dictionary:
		data["spaces"] = {}
	var spaces: Dictionary = data["spaces"]
	for key: Variant in spaces.keys():
		if not spaces[key] is Dictionary:
			spaces[key] = {}
		_fill_space(spaces[key])
	for mode: int in SPACE_MODES:
		for book: int in BOOKS:
			for difficulty: int in [Defs.Difficulty.BEGINNER, Defs.Difficulty.EXPERT]:
				var key: String = space(mode, book, difficulty)
				if not spaces.has(key):
					spaces[key] = {}
					_fill_space(spaces[key])
	if not data.get("code_stones") is Array:
		data["code_stones"] = []
	if not data.get("stats") is Dictionary:
		data["stats"] = {}
	if not (data.get("high_score") is float or data.get("high_score") is int):
		data["high_score"] = 0
	var paintings: Array = []
	var stored: Variant = data.get("paintings")
	if stored is Array:
		for index: Variant in stored:
			var value: int = _int_value(index) if (index is float or index is int) else -1
			if value >= 0 and value < Tuning.PAINTING_COUNT and not paintings.has(value):
				paintings.append(value)
	paintings.sort()
	data["paintings"] = paintings
	if not data.get("unlocks") is Dictionary:
		data["unlocks"] = {}
	var unlocks: Dictionary = data["unlocks"]
	if not unlocks.get("all") is bool:
		unlocks["all"] = false
	if not unlocks.get("rewards") is Array:
		unlocks["rewards"] = []


static func _fill_space(space_data: Dictionary) -> void:
	if not space_data.get("unlocked") is Array:
		space_data["unlocked"] = []
	if not space_data.get("results") is Dictionary:
		space_data["results"] = {}
	if not space_data.get("completed") is bool:
		space_data["completed"] = false
	if not (space_data.get("high_score") is float or space_data.get("high_score") is int):
		space_data["high_score"] = 0
	if not space_data.get("belt") is Array:
		space_data["belt"] = []


func _migrate(data: Dictionary, from_version: int) -> Dictionary:
	# A file from a NEWER build is kept as far as it is understood.
	if from_version > VERSION:
		push_warning("Save: file version %d is newer than this build (%d)" % [from_version, VERSION])
		return data
	if from_version <= 1:
		_migrate_v1(data)
	return data


# Version 1 (1.0.0) kept unlocked levels, results and the completion flag per difficulty at the top level: they
# become the (single, Book I) namespaces. Code stones, statistics and the high score stay profile-wide. A file that
# already holds namespaces (a 2.0 save written again by 1.0.0) is merged, never overwritten: unlocked levels are
# united, results keep the best of both, completion stays set.
static func _migrate_v1(data: Dictionary) -> void:
	if not data.get("spaces") is Dictionary:
		data["spaces"] = {}
	var spaces: Dictionary = data["spaces"]
	for difficulty: int in [Defs.Difficulty.BEGINNER, Defs.Difficulty.EXPERT]:
		var difficulty_name: String = Defs.difficulty_name(difficulty)
		var key: String = space(Defs.GameMode.SINGLE, 1, difficulty)
		if not spaces.get(key) is Dictionary:
			spaces[key] = {}
		var target: Dictionary = spaces[key]
		_fill_space(target)
		var old_unlocked: Variant = _v1_entry(data, "unlocked", difficulty_name)
		if old_unlocked is Array:
			var unlocked: Array = target["unlocked"]
			for id: Variant in old_unlocked:
				if id is String and not unlocked.has(id):
					unlocked.append(id)
		var old_results: Variant = _v1_entry(data, "results", difficulty_name)
		if old_results is Dictionary:
			var results: Dictionary = target["results"]
			for id: Variant in old_results:
				if old_results[id] is Dictionary:
					results[str(id)] = _merge_result(results.get(str(id), {}), old_results[id])
		var old_completed: Variant = _v1_entry(data, "completed", difficulty_name)
		if old_completed is bool and old_completed:
			target["completed"] = true
	data.erase("unlocked")
	data.erase("results")
	data.erase("completed")


# What a version 1 file held that the migrated data does not: the check between the migration and the first write.
# Only entries 1.0.0 itself could read count (ids as text, results as dictionaries, numbers as numbers).
static func _v1_losses(original: Dictionary, migrated: Dictionary) -> PackedStringArray:
	var losses: PackedStringArray = PackedStringArray()
	var spaces: Dictionary = migrated["spaces"] if migrated.get("spaces") is Dictionary else {}
	for difficulty: int in [Defs.Difficulty.BEGINNER, Defs.Difficulty.EXPERT]:
		var difficulty_name: String = Defs.difficulty_name(difficulty)
		var target: Dictionary = {}
		if spaces.get(space(Defs.GameMode.SINGLE, 1, difficulty)) is Dictionary:
			target = spaces[space(Defs.GameMode.SINGLE, 1, difficulty)]
		var old_unlocked: Variant = _v1_entry(original, "unlocked", difficulty_name)
		var unlocked: Array = target["unlocked"] if target.get("unlocked") is Array else []
		if old_unlocked is Array:
			for id: Variant in old_unlocked:
				if id is String and not unlocked.has(id):
					losses.append("unlocked %s %s" % [difficulty_name, id])
		var old_results: Variant = _v1_entry(original, "results", difficulty_name)
		var results: Dictionary = target["results"] if target.get("results") is Dictionary else {}
		if old_results is Dictionary:
			for id: Variant in old_results:
				if not old_results[id] is Dictionary:
					continue
				var kept: Dictionary = results[str(id)] if results.get(str(id)) is Dictionary else {}
				for field: String in ["percent", "score", "clears"]:
					if _int_value(kept.get(field)) < _int_value(old_results[id].get(field)):
						losses.append("result %s %s %s" % [difficulty_name, id, field])
		var old_completed: Variant = _v1_entry(original, "completed", difficulty_name)
		if old_completed is bool and old_completed and not (target.get("completed") is bool and target["completed"]):
			losses.append("completed %s" % difficulty_name)
	var stones: Array = migrated["code_stones"] if migrated.get("code_stones") is Array else []
	if original.get("code_stones") is Array:
		for stone: Variant in original["code_stones"]:
			if not stones.has(stone):
				losses.append("code stone %s" % str(stone))
	var stats: Dictionary = migrated["stats"] if migrated.get("stats") is Dictionary else {}
	if original.get("stats") is Dictionary:
		for stat: Variant in original["stats"]:
			var old_stat: Variant = original["stats"][stat]
			if (old_stat is float or old_stat is int) and _int_value(stats.get(stat)) != int(old_stat):
				losses.append("stat %s" % str(stat))
	var old_high: Variant = original.get("high_score")
	if (old_high is float or old_high is int) and _int_value(migrated.get("high_score")) < int(old_high):
		losses.append("high score")
	return losses


# Copy the file of another version that the data came from, byte for byte, to its legacy name
# ([method legacy_backup_name]; never over a file with other content: that one keeps its name and this one gets
# the next number), and read the copy back. True when the copy exists - save_game may then write - or when the
# source file is gone (nothing is left to protect).
func _keep_legacy_copy() -> bool:
	if _legacy_source.is_empty():
		return true
	var source_path: String = storage_dir + _legacy_source
	if not FileAccess.file_exists(source_path):
		_legacy_source = ""
		return true
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(source_path)
	if bytes.is_empty():
		return false
	for number: int in range(1, LEGACY_BACKUP_MAX + 1):
		var path: String = storage_dir + legacy_backup_name(_legacy_version, number)
		if FileAccess.file_exists(path):
			if FileAccess.get_file_as_bytes(path) == bytes:
				_legacy_backup = path
				_legacy_source = ""
				return true
			continue
		var temp_path: String = path + ".tmp"
		var file: FileAccess = FileAccess.open(temp_path, FileAccess.WRITE)
		if file == null:
			return false
		file.store_buffer(bytes)
		file.close()
		var dir: DirAccess = DirAccess.open(storage_dir)
		if dir == null or FileAccess.get_file_as_bytes(temp_path) != bytes 				or dir.rename(temp_path.get_file(), path.get_file()) != OK 				or FileAccess.get_file_as_bytes(path) != bytes:
			if dir != null:
				dir.remove(temp_path.get_file())
			return false
		_legacy_backup = path
		_legacy_source = ""
		return true
	return false


# Move an unreadable save file out of the way, byte for byte (a rename), to the first "save.bad" name that is free
# ([method bad_file_name]); a file whose bytes one of those names already keeps is removed instead of kept twice.
# When all BAD_MAX names hold other bytes the last one is replaced. False when the file is still in the way.
func _set_aside(dir: DirAccess, file_name: String) -> bool:
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(storage_dir + file_name)
	for number: int in range(1, BAD_MAX + 1):
		var bad: String = bad_file_name(number)
		if dir.file_exists(bad):
			if FileAccess.get_file_as_bytes(storage_dir + bad) == bytes:
				return dir.remove(file_name) == OK
			if number < BAD_MAX:
				continue
			dir.remove(bad)
		return dir.rename(file_name, bad) == OK
	return false


static func _v1_entry(data: Dictionary, section: String, difficulty_name: String) -> Variant:
	var by_difficulty: Variant = data.get(section)
	if by_difficulty is Dictionary:
		return (by_difficulty as Dictionary).get(difficulty_name)
	return null


static func _merge_result(a: Variant, b: Dictionary) -> Dictionary:
	var first: Dictionary = a if a is Dictionary else {}
	var merged: Dictionary = {}
	for field: String in ["percent", "score", "clears"]:
		merged[field] = maxi(_int_value(first.get(field)), _int_value(b.get(field)))
	return merged


static func _int_value(value: Variant) -> int:
	return int(value) if value is float or value is int else 0


# A stored weapon value: a Defs.Weapon (0..SPEAR), BELT_EMPTY for a negative belt, otherwise `fallback`.
static func _weapon_value(value: Variant, fallback: int) -> int:
	if not (value is float or value is int):
		return fallback
	var weapon: int = int(value)
	if weapon < 0:
		return fallback
	return weapon if weapon <= Defs.Weapon.SPEAR else fallback


static func _book1(difficulty: int) -> String:
	return space(Defs.GameMode.SINGLE, 1, difficulty)


# A namespace for reading: the stored one, or an empty one (not added to the save).
func _read_space(space_key: String) -> Dictionary:
	var spaces: Dictionary = _data["spaces"]
	if spaces.get(space_key) is Dictionary:
		return spaces[space_key]
	var empty: Dictionary = {}
	_fill_space(empty)
	return empty


# A namespace for writing: created when missing.
func _write_space(space_key: String) -> Dictionary:
	var spaces: Dictionary = _data["spaces"]
	if not spaces.get(space_key) is Dictionary:
		spaces[space_key] = {}
		_fill_space(spaces[space_key])
	return spaces[space_key]


# The data of a save file of storage_dir; {} when it is missing or cannot be read. A file that is there and holds no
# save - garbage, a write that was cut off, an empty or zero-filled file, JSON that is no object or an empty one -
# is unreadable: it is named in a warning and remembered, so that save_game sets it aside.
func _read(file_name: String) -> Dictionary:
	var path: String = storage_dir + file_name
	if not FileAccess.file_exists(path):
		return {}
	var text: String = FileAccess.get_file_as_string(path)
	var json: JSON = JSON.new()
	var reason: String = ""
	if text.is_empty():
		reason = "no text in its %d byte(s)" % FileAccess.get_file_as_bytes(path).size()
	elif json.parse(text) != OK:
		reason = json.get_error_message()
	elif not json.data is Dictionary:
		reason = "not a JSON object"
	elif (json.data as Dictionary).is_empty():
		reason = "an empty JSON object"
	if reason.is_empty():
		return json.data
	_unreadable.append(file_name)
	if report_damage:
		push_warning("Save: %s is damaged (%s)" % [path, reason])
	return {}
