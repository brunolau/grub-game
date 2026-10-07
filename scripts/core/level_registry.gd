extends Node
## Autoload `Levels`: discovers level files and answers questions about the campaign.
##
## CONTRACT FILE (docs/ARCHITECTURE.md 3.8 and 7). Owner: core. Public methods are frozen.
##
## There is NO hand-maintained level list: every `res://levels/<id>.lvl` is found by scanning the folder and
## described by its own `[meta]` section. Adding a level = adding one file.
## Syntax (sections, value typing) is implemented once, in LevelText; this script only interprets [meta].
##
## Level format 2 (2.0, docs/expansion/DESIGN.md A.1 and D.9, ARCHITECTURE.md 7.11) makes the queries mode-aware:
##  - Books: every level belongs to a book (meta `book`, default 1). The campaign queries ([method get_campaign],
##    [method first_level], [method next_level], [method has_locked_successor], [method parent_level]) work inside the
##    book of the level asked about; the 1.0 calls without a book mean Book I, so the 15 1.0 files answer exactly as
##    in 1.0 whatever else lies in the folder.
##  - `kind = coop` (the co-op version of the solo level `coop_of`) and `kind = arena` (a versus arena) never appear in
##    a solo query: not in a campaign, not as the level that links to a sub-stage, not behind a code.
##  - The co-op campaign of a book is its solo campaign with every stop replaced by that stop's co-op file
##    ([method get_coop_campaign], [method get_coop_level]); a co-op file continues where its solo level continues
##    ([method next_level]) and records its result at the solo map stop ([method parent_level]).
##  - Arenas: [method get_arenas].

## The folder was (re)scanned.
signal rescanned(count: int)

const LEVEL_DIR: String = "res://levels"
const LEVEL_EXT: String = "lvl"
## Format version of the 1.0 level files (the `format` key of [meta]). This build also reads format 2
## ([constant FORMAT_2]); [constant FORMATS] lists every format it reads.
const FORMAT_VERSION: int = 1
## Level format 2 (2.0): format 1 plus the keys, the tar floor ':' and the ids of ARCHITECTURE.md 7.11.
const FORMAT_2: int = LevelText.FORMAT_2
## Every `format` this build reads.
const FORMATS: Array[int] = [FORMAT_VERSION, FORMAT_2]
## Values of the `kind` key.
const KIND_MAIN: String = "main"    ## on the world map, part of the campaign order
const KIND_SUB: String = "sub"      ## linked second half of a main level (entered through `next`, no map stop)
const KIND_BONUS: String = "bonus"  ## bonus stage entered through a warp item
const KIND_ENDING: String = "ending"
const KIND_TEST: String = "test"    ## developer / test level, never part of the campaign
const KIND_COOP: String = LevelText.KIND_COOP    ## 2.0: the co-op version of the solo level `coop_of`
const KIND_ARENA: String = LevelText.KIND_ARENA  ## 2.0: a versus arena, never part of a campaign
## Books (meta `book`): Book I "The First Feast" (every file without the key) and Book II "The Far Shore".
const BOOK_1: int = LevelText.BOOK_1
const BOOK_2: int = LevelText.BOOK_2

var _meta: Dictionary = {}   # StringName id -> Dictionary meta
var _paths: Dictionary = {}  # StringName id -> String path
## The Book I campaign (the 1.0 campaign): main levels of book 1 by `order`. The campaign of every book is in
## `_campaigns`; this is `_campaigns[BOOK_1]`.
var _campaign: Array[StringName] = []
## Campaign of each book: int book -> Array[StringName] of its main levels by `order`.
var _campaigns: Dictionary = {}
## Co-op files by the solo level they belong to: StringName solo id -> StringName co-op id (the first by file name
## when two files name the same `coop_of`; the validator reports that).
var _coop_by_base: Dictionary = {}
## Arenas by file name.
var _arenas: Array[StringName] = []
var _no_levels: Array[StringName] = []


func _ready() -> void:
	rescan()


## Scan LEVEL_DIR again (the editor / tests call this after writing level files).
func rescan() -> void:
	_meta.clear()
	_paths.clear()
	_campaign.clear()
	var dir: DirAccess = DirAccess.open(LEVEL_DIR)
	if dir == null:
		_index_campaign()
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


## Campaign order of every book (main levels sorted by their `order` key), the co-op files by their solo level and
## the arena list. (Tests and the bench that change the level metas call it again.)
func _index_campaign() -> void:
	_campaigns.clear()
	_coop_by_base.clear()
	_arenas.clear()
	var ids: Array[StringName] = all_ids()
	ids.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	for id: StringName in ids:
		var meta: Dictionary = _meta[id]
		var kind: String = str(meta.get("kind", KIND_MAIN))
		if kind == KIND_MAIN and meta.has("order"):
			var book: int = LevelText.meta_book(meta)
			if not _campaigns.has(book):
				var fresh: Array[StringName] = []
				_campaigns[book] = fresh
			var list: Array[StringName] = _campaigns[book]
			list.append(id)
		elif kind == KIND_COOP:
			var base: StringName = StringName(str(meta.get("coop_of", "")))
			if base != &"" and not _coop_by_base.has(base):
				_coop_by_base[base] = id
		elif kind == KIND_ARENA:
			_arenas.append(id)
	for book: int in _campaigns:
		var list: Array[StringName] = _campaigns[book]
		list.sort_custom(_by_order)
	_campaign = _campaigns.get(BOOK_1, _no_levels).duplicate()
	_campaigns[BOOK_1] = _campaign


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


## Main levels in world-map order for a difficulty (levels whose min_difficulty is higher are left out), of one book
## (2.0; default Book I, the 1.0 campaign). Never a co-op file or an arena.
func get_campaign(difficulty: int = Defs.Difficulty.EXPERT, book: int = BOOK_1) -> Array[StringName]:
	var result: Array[StringName] = []
	for id: StringName in _campaigns.get(book, _no_levels):
		if is_available(id, difficulty):
			result.append(id)
	return result


## First level of the campaign of a book (2.0; default Book I) ("" when no main level exists yet).
func first_level(book: int = BOOK_1) -> StringName:
	var campaign: Array[StringName] = _campaigns.get(book, _no_levels)
	return campaign[0] if not campaign.is_empty() else &""


## True when the level may be played in this difficulty (`min_difficulty = expert` hides it from Beginner).
func is_available(level_id: StringName, difficulty: int) -> bool:
	var minimum: String = str(get_level_meta(level_id).get("min_difficulty", "beginner"))
	return minimum != "expert" or difficulty == Defs.Difficulty.EXPERT


## Level that follows `level_id`: its `next` key when present, otherwise the next campaign level (of its book). A
## linked sub-stage (`kind = sub`) without `next` continues after the campaign level it belongs to ([method
## parent_level]). Returns "" at the end of the game (the flow then shows the ending), and "" for unknown ids.
## 2.0: a co-op file continues with the co-op file of the level its solo level leads to (stops without a co-op file
## are passed over); an arena leads nowhere.
func next_level(level_id: StringName, difficulty: int) -> StringName:
	if not _meta.has(level_id):
		return &""
	var kind: String = _kind_of(level_id)
	if kind == KIND_COOP:
		return _coop_next(level_id, difficulty)
	if kind == KIND_ARENA:
		return &""
	var explicit: String = str(get_value(level_id, "next", "", difficulty))
	if explicit != "":
		return StringName(explicit)
	var stop: StringName = parent_level(level_id, difficulty)
	if stop == &"":
		return &""
	var campaign: Array[StringName] = _campaign_of(stop)
	for i: int in range(campaign.find(stop) + 1, campaign.size()):
		if is_available(campaign[i], difficulty):
			return campaign[i]
	return &""


## True when the campaign continues after `level_id` but only for a higher difficulty: the flow shows the
## "you must be an expert" wall instead of the ending (GAMEPLAY.md 1.3). A sub-stage asks for its main level, a
## co-op file for its solo level (2.0).
func has_locked_successor(level_id: StringName, difficulty: int) -> bool:
	var stop: StringName = parent_level(level_id, difficulty)
	if stop == &"":
		return false
	var campaign: Array[StringName] = _campaign_of(stop)
	for i: int in range(campaign.find(stop) + 1, campaign.size()):
		if not is_available(campaign[i], difficulty):
			return true
	return false


## The campaign (world-map) level that `level_id` is part of: the level itself when it is on the campaign; for a
## linked sub-stage (`kind = sub`) the main level whose `next` (in this difficulty) leads to it, directly or
## through further sub-stages. "" when there is none (bonus, ending and test levels, unknown ids). Its result
## is recorded under that level and the campaign continues after it.
## 2.0: a co-op file belongs to the map stop of its solo level `coop_of` (the solo id: co-op progress is kept per
## solo stop, in the co-op save namespace); an arena belongs to none.
func parent_level(level_id: StringName, difficulty: int) -> StringName:
	var current: StringName = level_id
	if _kind_of(current) == KIND_COOP:
		current = get_coop_base(current)
		if _kind_of(current) == KIND_COOP:
			return &""
	var seen: Dictionary = {}
	while _meta.has(current) and not seen.has(current):
		if _in_campaign(current):
			return current
		seen[current] = true
		if _kind_of(current) != KIND_SUB:
			return &""
		current = _linking_level(current, difficulty)
	return &""


## The solo level (not a co-op file, not an arena) whose `next` (in this difficulty) is `level_id` ("" when none;
## the first by file name).
func _linking_level(level_id: StringName, difficulty: int) -> StringName:
	for id: StringName in _meta:
		if id != level_id and _is_solo(id) and str(get_value(id, "next", "", difficulty)) == String(level_id):
			return id
	return &""


## Level and difficulty a 4-character code belongs to: {"level_id": StringName, "difficulty": int}, or {} when
## the code is unknown. Codes are compared case-insensitively, and the look-alike pairs O / 0 and I / 1 count as
## the same character (normalize_code), so "BONE" finds the code B0NE. The validator keeps codes unique that way.
## Codes are solo only (2.0): co-op files and arenas never answer one.
func find_by_password(code: String) -> Dictionary:
	var wanted: String = normalize_code(code)
	if wanted.is_empty():
		return {}
	for id: StringName in _meta:
		if not _is_solo(id):
			continue
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


# =================================================================================================================
# 2.0: books, belts, co-op files, arenas (level format 2)
# =================================================================================================================

## The book a level belongs to (meta `book`, default BOOK_1; a co-op file keeps the book of its solo level). 0 for an
## unknown id.
func get_book(level_id: StringName) -> int:
	if not _meta.has(level_id):
		return 0
	return LevelText.meta_book(_meta[level_id])


## The `kind` of a level (KIND_MAIN when the file does not say; "" for an unknown id).
func get_level_kind(level_id: StringName) -> String:
	return _kind_of(level_id) if _meta.has(level_id) else ""


## The weapon-belt rule of a level for a difficulty (PHYSICS.md C.2): LevelText.BELT_FRESH (club in hand at every
## stage start; the default of book 2 and of co-op files) or LevelText.BELT_CARRY (the 1.0 rule; every 1.0 file).
func get_belt_rule(level_id: StringName, difficulty: int = -1) -> String:
	return LevelText.meta_belt(get_level_meta(level_id), difficulty)


## True for a level of the solo game: every kind but `coop` and `arena` (test levels included).
func is_solo_level(level_id: StringName) -> bool:
	return _meta.has(level_id) and _is_solo(level_id)


## True for a co-op file (`kind = coop`).
func is_coop_level(level_id: StringName) -> bool:
	return _meta.has(level_id) and _kind_of(level_id) == KIND_COOP


## True for a versus arena (`kind = arena`).
func is_arena(level_id: StringName) -> bool:
	return _meta.has(level_id) and _kind_of(level_id) == KIND_ARENA


## The solo level a co-op file belongs to (its `coop_of`); "" for any other level.
func get_coop_base(level_id: StringName) -> StringName:
	if not is_coop_level(level_id):
		return &""
	return StringName(str(_meta[level_id].get("coop_of", "")))


## The co-op file of a solo level ("" when it has none yet); a co-op file answers itself.
func get_coop_level(level_id: StringName) -> StringName:
	if is_coop_level(level_id):
		return level_id
	return _coop_by_base.get(level_id, &"")


## The co-op campaign of a book for a difficulty: [method get_campaign] with every stop replaced by its co-op file
## (DESIGN.md D.9; stops without a co-op file yet are left out).
func get_coop_campaign(difficulty: int = Defs.Difficulty.EXPERT, book: int = BOOK_1) -> Array[StringName]:
	var result: Array[StringName] = []
	for id: StringName in get_campaign(difficulty, book):
		var coop: StringName = get_coop_level(id)
		if coop != &"":
			result.append(coop)
	return result


## The file to play for `level_id` in a game mode (Defs.GameMode): SINGLE = the solo level (a co-op file answers its
## `coop_of`), COOP = its co-op file ("" when it has none), VERSUS = the level itself when it is an arena, else "".
## Flow maps every level it is about to start (map stop, `next`, `bonus`) through this.
func level_for_mode(level_id: StringName, mode: int) -> StringName:
	if not _meta.has(level_id):
		return &""
	match mode:
		Defs.GameMode.COOP:
			return get_coop_level(level_id)
		Defs.GameMode.VERSUS:
			return level_id if is_arena(level_id) else &""
	if is_coop_level(level_id):
		return get_coop_base(level_id)
	return level_id if _is_solo(level_id) else &""


## Every versus arena by file name; `players` > 0 keeps those built for at least that many players (meta `players`),
## a non-empty `mode` (a Defs.VERSUS_MODE_NAMES name) those that list it in `modes`. Unlocks are not applied here.
func get_arenas(players: int = 0, mode: StringName = &"") -> Array[StringName]:
	var result: Array[StringName] = []
	for id: StringName in _arenas:
		var meta: Dictionary = _meta[id]
		if players > 0 and int(meta.get("players", 0)) < players:
			continue
		if mode != &"" and not LevelText.to_list(meta.get("modes", "")).has(String(mode)):
			continue
		result.append(id)
	return result


# =================================================================================================================
# Internals
# =================================================================================================================

func _kind_of(level_id: StringName) -> String:
	return str(_meta[level_id].get("kind", KIND_MAIN)) if _meta.has(level_id) else ""


func _is_solo(level_id: StringName) -> bool:
	var kind: String = _kind_of(level_id)
	return kind != KIND_COOP and kind != KIND_ARENA


## The campaign of the book `level_id` belongs to.
func _campaign_of(level_id: StringName) -> Array[StringName]:
	return _campaigns.get(LevelText.meta_book(get_level_meta(level_id)), _no_levels)


## True when the level is a stop of its book's campaign.
func _in_campaign(level_id: StringName) -> bool:
	return _campaign_of(level_id).has(level_id)


## next_level of a co-op file: where its solo level leads, as a co-op file. Solo levels without a co-op file yet are
## passed over (their successors are asked in turn), so a book with a few co-op files plays them in order.
func _coop_next(level_id: StringName, difficulty: int) -> StringName:
	var current: StringName = get_coop_base(level_id)
	var seen: Dictionary = {}
	while current != &"" and _meta.has(current) and _is_solo(current) and not seen.has(current):
		seen[current] = true
		current = next_level(current, difficulty)
		if current == &"":
			return &""
		var coop: StringName = get_coop_level(current)
		if coop != &"":
			return coop
	return &""


func _by_order(a: StringName, b: StringName) -> bool:
	var order_a: int = int(_meta[a].get("order", 0))
	var order_b: int = int(_meta[b].get("order", 0))
	if order_a == order_b:
		return String(a) < String(b)
	return order_a < order_b
