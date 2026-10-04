extends Node
## Autoload `Save`: persistent progress in `user://save.json` (versioned JSON, atomic write).
##
## CONTRACT FILE (docs/ARCHITECTURE.md 3.6). Owner: core. Public methods are frozen.
##
## Replaces the original's machine-specific level codes (GAMEPLAY.md 12.4): the highest level reached is stored
## per difficulty, plus best results per level. There are no mid-level saves and no continues.
## Difficulty arguments are Defs.Difficulty values; level ids are the level file names without extension.

## Data was written to disk.
signal saved
## Data was read from disk (or reset).
signal loaded

const FILE_NAME: String = "save.json"
const TEMP_NAME: String = "save.json.tmp"
const BACKUP_NAME: String = "save.json.bak"
## Bump when the layout changes; add a step to _migrate().
const VERSION: int = 1

## Directory of the save file. Tests point it at `res://build/...` so they never touch real user data.
var storage_dir: String = "user://"

## When false a damaged save file is handled silently (error-path tests).
var report_damage: bool = true

var _data: Dictionary = {}


func _ready() -> void:
	load_game()


## Use another directory (created if missing) and reload from it.
func set_storage_dir(dir_path: String) -> void:
	storage_dir = dir_path if dir_path.ends_with("/") else dir_path + "/"
	DirAccess.make_dir_recursive_absolute(storage_dir)
	load_game()


## Read the save file. A missing file yields a fresh save; a damaged file falls back to the backup, then to a
## fresh save (never crashes, never blocks the game).
func load_game() -> void:
	_data = _read(storage_dir + FILE_NAME)
	if _data.is_empty():
		_data = _read(storage_dir + BACKUP_NAME)
	if _data.is_empty():
		_data = _fresh()
	else:
		var version: int = int(_data.get("version", 0))
		if version != VERSION:
			_data = _migrate(_data, version)
		_fill_missing(_data)
	loaded.emit()


## Write the save file atomically (temp file, then rename; the previous file becomes the backup).
func save_game() -> Error:
	_data["version"] = VERSION
	var file: FileAccess = FileAccess.open(storage_dir + TEMP_NAME, FileAccess.WRITE)
	if file == null:
		var open_err: Error = FileAccess.get_open_error()
		push_error("Save: cannot open %s (error %d)" % [storage_dir + TEMP_NAME, open_err])
		return open_err
	file.store_string(JSON.stringify(_data, "  ", true))
	file.close()
	var dir: DirAccess = DirAccess.open(storage_dir)
	if dir == null:
		return ERR_CANT_OPEN
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


## True when at least one level beyond the first was reached in any mode (title screen shows "Continue").
func has_progress() -> bool:
	for mode: String in ["beginner", "expert"]:
		var unlocked: Array = _data["unlocked"][mode]
		if unlocked.size() > 0:
			return true
	return false


## True when `level_id` may be started from the level select in the given difficulty.
## The first level of the campaign is always unlocked (the registry decides which one that is).
func is_level_unlocked(level_id: StringName, difficulty: int) -> bool:
	var unlocked: Array = _data["unlocked"][Defs.difficulty_name(difficulty)]
	return unlocked.has(String(level_id))


## Mark a level as reachable from the level select. Does not write to disk; call save_game().
func unlock_level(level_id: StringName, difficulty: int) -> void:
	var unlocked: Array = _data["unlocked"][Defs.difficulty_name(difficulty)]
	if not unlocked.has(String(level_id)):
		unlocked.append(String(level_id))


## Every unlocked level id of a difficulty.
func get_unlocked_levels(difficulty: int) -> Array[StringName]:
	var result: Array[StringName] = []
	for id: Variant in _data["unlocked"][Defs.difficulty_name(difficulty)]:
		result.append(StringName(str(id)))
	return result


## Store the result of a completed level, keeping the best percentage and best score. Returns true when a
## record was improved. Does not write to disk; call save_game().
func record_level_result(level_id: StringName, difficulty: int, level_score: int, percent: int) -> bool:
	var results: Dictionary = _data["results"][Defs.difficulty_name(difficulty)]
	var key: String = String(level_id)
	var entry: Dictionary = results.get(key, {"percent": 0, "score": 0, "clears": 0})
	var improved: bool = percent > int(entry["percent"]) or level_score > int(entry["score"])
	entry["percent"] = maxi(int(entry["percent"]), percent)
	entry["score"] = maxi(int(entry["score"]), level_score)
	entry["clears"] = int(entry["clears"]) + 1
	results[key] = entry
	return improved


## Best result of a level: {"percent": int, "score": int, "clears": int}; zeros when never completed.
func get_level_result(level_id: StringName, difficulty: int) -> Dictionary:
	var results: Dictionary = _data["results"][Defs.difficulty_name(difficulty)]
	return results.get(String(level_id), {"percent": 0, "score": 0, "clears": 0})


## Highest total score of any run.
func get_high_score() -> int:
	return int(_data["high_score"])


## Report the score of a finished run. Returns true when it is a new high score.
func submit_score(run_score: int) -> bool:
	if run_score > int(_data["high_score"]):
		_data["high_score"] = run_score
		return true
	return false


## True when the game was finished at least once in the given difficulty.
func is_game_completed(difficulty: int) -> bool:
	return bool(_data["completed"][Defs.difficulty_name(difficulty)])


## Mark the game as finished in the given difficulty.
func set_game_completed(difficulty: int) -> void:
	_data["completed"][Defs.difficulty_name(difficulty)] = true


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


func _fresh() -> Dictionary:
	var data: Dictionary = {}
	_fill_missing(data)
	return data


func _fill_missing(data: Dictionary) -> void:
	data["version"] = VERSION
	if not data.get("unlocked") is Dictionary:
		data["unlocked"] = {}
	if not data.get("results") is Dictionary:
		data["results"] = {}
	if not data.get("completed") is Dictionary:
		data["completed"] = {}
	for mode: String in ["beginner", "expert"]:
		if not data["unlocked"].get(mode) is Array:
			data["unlocked"][mode] = []
		if not data["results"].get(mode) is Dictionary:
			data["results"][mode] = {}
		if not data["completed"].get(mode) is bool:
			data["completed"][mode] = false
	if not data.get("code_stones") is Array:
		data["code_stones"] = []
	if not data.get("stats") is Dictionary:
		data["stats"] = {}
	if not (data.get("high_score") is float or data.get("high_score") is int):
		data["high_score"] = 0


func _migrate(data: Dictionary, from_version: int) -> Dictionary:
	# Version 1 is the first layout. A file from a NEWER build is kept as far as it is understood.
	if from_version > VERSION:
		push_warning("Save: file version %d is newer than this build (%d)" % [from_version, VERSION])
	return data


func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var text: String = FileAccess.get_file_as_string(path)
	if text.is_empty():
		return {}
	var json: JSON = JSON.new()
	if json.parse(text) != OK or not json.data is Dictionary:
		if report_damage:
			push_warning("Save: %s is damaged (%s)" % [path, json.get_error_message()])
		return {}
	return json.data
