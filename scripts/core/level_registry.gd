extends Node
## Autoload `Levels`: discovers level files and answers questions about the campaign.
##
## CONTRACT FILE (docs/ARCHITECTURE.md 3.8 and 7). Owner: core. Public methods are frozen.
##
## There is NO hand-maintained level list: every `res://levels/<id>.lvl` is found by scanning the folder and
## described by its own `[meta]` section. Adding a level = adding one file.
## Syntax (sections, value typing) is implemented once, in LevelText; this script only interprets [meta].

## The folder was (re)scanned.
signal rescanned(count: int)

const LEVEL_DIR: String = "res://levels"
const LEVEL_EXT: String = "lvl"
## Format version this build understands (the `format` key of [meta]).
const FORMAT_VERSION: int = 1
## Values of the `kind` key.
const KIND_MAIN: String = "main"    ## on the world map, part of the campaign order
const KIND_SUB: String = "sub"      ## linked second half of a main level (entered through `next`, no map stop)
const KIND_BONUS: String = "bonus"  ## bonus stage entered through a warp item
const KIND_ENDING: String = "ending"
const KIND_TEST: String = "test"    ## developer / test level, never part of the campaign

var _meta: Dictionary = {}   # StringName id -> Dictionary meta
var _paths: Dictionary = {}  # StringName id -> String path
var _campaign: Array[StringName] = []


func _ready() -> void:
	rescan()


## Scan LEVEL_DIR again (the editor / tests call this after writing level files).
func rescan() -> void:
	_meta.clear()
	_paths.clear()
	_campaign.clear()
	var dir: DirAccess = DirAccess.open(LEVEL_DIR)
	if dir == null:
		rescanned.emit(0)
		return
	var names: PackedStringArray = dir.get_files()
	names.sort()
	for file_name: String in names:
		if file_name.get_extension() != LEVEL_EXT:
			continue
		var path: String = LEVEL_DIR + "/" + file_name
		var id: StringName = StringName(file_name.get_basename())
		var meta: Dictionary = parse_meta(FileAccess.get_file_as_string(path))
		if meta.is_empty():
			push_error("Levels: %s has no [meta] section" % path)
			continue
		if str(meta.get("id", "")) != String(id):
			push_error("Levels: %s: meta id '%s' must equal the file name" % [path, meta.get("id", "")])
			continue
		_meta[id] = meta
		_paths[id] = path
	_index_campaign()
	rescanned.emit(_meta.size())


## Campaign order: main levels sorted by their `order` key. (Tests that add level metas call it again.)
func _index_campaign() -> void:
	var ordered: Array[StringName] = []
	for id: StringName in _meta:
		if str(_meta[id].get("kind", KIND_MAIN)) == KIND_MAIN and _meta[id].has("order"):
			ordered.append(id)
	ordered.sort_custom(_by_order)
	_campaign = ordered


## True when a level file with this id exists.
func has_level(level_id: StringName) -> bool:
	return _meta.has(level_id)


## Every known level id, sorted by file name.
func all_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for id: StringName in _meta:
		ids.append(id)
	return ids


## Path of the level file ("" when unknown).
func get_level_path(level_id: StringName) -> String:
	return str(_paths.get(level_id, ""))


## The parsed [meta] section of a level (empty when unknown). Do not modify the returned dictionary.
func get_level_meta(level_id: StringName) -> Dictionary:
	return _meta.get(level_id, {})


## A [meta] value with the difficulty variant applied: `key.expert` / `key.beginner` overrides `key`.
func get_value(level_id: StringName, key: String, default: Variant = null, difficulty: int = -1) -> Variant:
	return meta_value(get_level_meta(level_id), key, default, difficulty)


## Same lookup on a meta dictionary you already hold (used by the loader).
static func meta_value(meta: Dictionary, key: String, default: Variant = null, difficulty: int = -1) -> Variant:
	if difficulty >= 0:
		var variant_key: String = "%s.%s" % [key, Defs.difficulty_name(difficulty)]
		if meta.has(variant_key):
			return meta[variant_key]
	return meta.get(key, default)


## Main levels in world-map order for a difficulty (levels whose min_difficulty is higher are left out).
func get_campaign(difficulty: int = Defs.Difficulty.EXPERT) -> Array[StringName]:
	var result: Array[StringName] = []
	for id: StringName in _campaign:
		if is_available(id, difficulty):
			result.append(id)
	return result


## First level of the campaign ("" when no main level exists yet).
func first_level() -> StringName:
	return _campaign[0] if not _campaign.is_empty() else &""


## True when the level may be played in this difficulty (`min_difficulty = expert` hides it from Beginner).
func is_available(level_id: StringName, difficulty: int) -> bool:
	var minimum: String = str(get_level_meta(level_id).get("min_difficulty", "beginner"))
	return minimum != "expert" or difficulty == Defs.Difficulty.EXPERT


## Level that follows `level_id`: its `next` key when present, otherwise the next campaign level. A linked
## sub-stage (`kind = sub`) without `next` continues after the campaign level it belongs to ([method parent_level]).
## Returns "" at the end of the game (the flow then shows the ending), and "" for unknown ids.
func next_level(level_id: StringName, difficulty: int) -> StringName:
	if not _meta.has(level_id):
		return &""
	var explicit: String = str(get_value(level_id, "next", "", difficulty))
	if explicit != "":
		return StringName(explicit)
	var index: int = _campaign_index(level_id, difficulty)
	if index < 0:
		return &""
	for i: int in range(index + 1, _campaign.size()):
		if is_available(_campaign[i], difficulty):
			return _campaign[i]
	return &""


## True when the campaign continues after `level_id` but only for a higher difficulty: the flow shows the
## "you must be an expert" wall instead of the ending (GAMEPLAY.md 1.3). A sub-stage asks for its main level.
func has_locked_successor(level_id: StringName, difficulty: int) -> bool:
	var index: int = _campaign_index(level_id, difficulty)
	if index < 0:
		return false
	for i: int in range(index + 1, _campaign.size()):
		if not is_available(_campaign[i], difficulty):
			return true
	return false


## The campaign (world-map) level that `level_id` is part of: the level itself when it is on the campaign; for a
## linked sub-stage (`kind = sub`) the main level whose `next` (in this difficulty) leads to it, directly or
## through further sub-stages. "" when there is none (bonus, ending and test levels, unknown ids). Its result
## is recorded under that level and the campaign continues after it.
func parent_level(level_id: StringName, difficulty: int) -> StringName:
	var current: StringName = level_id
	var seen: Dictionary = {}
	while _meta.has(current) and not seen.has(current):
		if _campaign.has(current):
			return current
		seen[current] = true
		if str(_meta[current].get("kind", KIND_MAIN)) != KIND_SUB:
			return &""
		current = _linking_level(current, difficulty)
	return &""


## Index in the campaign of the level itself or, for a sub-stage, of its main level (-1 = none).
func _campaign_index(level_id: StringName, difficulty: int) -> int:
	var index: int = _campaign.find(level_id)
	if index >= 0:
		return index
	var parent: StringName = parent_level(level_id, difficulty)
	return _campaign.find(parent) if parent != &"" else -1


## The level whose `next` (in this difficulty) is `level_id` ("" when none; the first by file name).
func _linking_level(level_id: StringName, difficulty: int) -> StringName:
	for id: StringName in _meta:
		if id != level_id and str(get_value(id, "next", "", difficulty)) == String(level_id):
			return id
	return &""


## Level and difficulty a 4-character code belongs to: {"level_id": StringName, "difficulty": int}, or {} when
## the code is unknown. Codes are compared case-insensitively, and the look-alike pairs O / 0 and I / 1 count as
## the same character (normalize_code), so "BONE" finds the code B0NE. The validator keeps codes unique that way.
func find_by_password(code: String) -> Dictionary:
	var wanted: String = normalize_code(code)
	if wanted.is_empty():
		return {}
	for id: StringName in _meta:
		var meta: Dictionary = _meta[id]
		if normalize_code(str(meta.get("password_beginner", ""))) == wanted:
			return {"level_id": id, "difficulty": Defs.Difficulty.BEGINNER}
		if normalize_code(str(meta.get("password_expert", ""))) == wanted:
			return {"level_id": id, "difficulty": Defs.Difficulty.EXPERT}
	return {}


## A level code as it is compared: trimmed, upper case, the letter O read as the digit 0 and the letter I as 1
## (the pixel font draws them alike; a player who types the other one still gets in).
static func normalize_code(code: String) -> String:
	return code.strip_edges().to_upper().replace("O", "0").replace("I", "1")


## Code of a level for a difficulty ("" when it has none).
func get_password(level_id: StringName, difficulty: int) -> String:
	return str(get_level_meta(level_id).get("password_" + Defs.difficulty_name(difficulty), ""))


## Parse the `[meta]` section out of the text of a level file ({} when there is none).
## Forwards to LevelText, the single implementation of the format's syntax.
static func parse_meta(text: String) -> Dictionary:
	return LevelText.parse_meta(text)


func _by_order(a: StringName, b: StringName) -> bool:
	var order_a: int = int(_meta[a].get("order", 0))
	var order_b: int = int(_meta[b].get("order", 0))
	if order_a == order_b:
		return String(a) < String(b)
	return order_a < order_b
