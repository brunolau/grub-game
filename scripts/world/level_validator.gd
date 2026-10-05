class_name LevelValidator
extends RefCounted
## Content checks of level files (docs/ARCHITECTURE.md 7.9, docs/LEVEL_DESIGN.md "Validate"). Owner: world.
##
## Add files or texts, call [method run], read [member problems] or print [method format_problem] lines
## (`file:line: error: message`). Errors make a level invalid; warnings point at things that are legal but
## probably not meant. Besides the rules of 7.9 it checks what can be decided statically about playability:
## the hero start stands on a floor, an exit path exists (and a locked exit can be opened), no entity is buried
## in solid tiles, references and contents are valid, parameters are known and in range.
##
## It uses no autoload, so the command-line tool can run it in any context.

const ERROR: int = 0
const WARNING: int = 1

## Size limits of a level in tiles (section 7.1).
const MIN_COLS: int = 20
const MIN_ROWS: int = 12
## Entity limits (section 7.9).
const MAX_ENEMIES: int = Tuning.MAX_ENEMY_RECORDS
const MAX_ITEMS: int = Tuning.MAX_PLACED_ITEMS
const MAX_HITTABLES: int = Tuning.MAX_HIDDEN_SPOTS
const MAX_PLATFORMS: int = Tuning.MAX_PLATFORMS

## Parameters every entity accepts (ARCHITECTURE.md 6.1).
const COMMON_PARAMS: Array[String] = ["name", "facing", "expert", "beginner", "dx", "dy", "tile"]
const ENEMY_PARAMS: Array[String] = ["skin", "hp", "score"]
const ITEM_PARAMS: Array[String] = ["dropped", "fan", "points"]
## The catalogue of ARCHITECTURE.md 6.2: id -> its own parameters.
const CATALOGUE: Dictionary = {
	"enemies/dropper": ["zone", "pause", "speed", "max"],
	"enemies/dangler": ["depth", "speed"],
	"enemies/lurker": ["range", "pause"],
	"enemies/swinger": ["radius"],
	"enemies/stinger": ["range", "speed"],
	"enemies/harrier": ["range"],
	"enemies/dart": ["range", "speed"],
	"enemies/hopper": ["range", "pause", "jump_x", "jump_y"],
	"enemies/walker": ["left", "right", "speed"],
	"enemies/flyer": ["left", "right", "speed"],
	"enemies/digger": ["zone", "pause", "speed"],
	"enemies/leaper": ["speed", "pause"],
	"enemies/charger": ["speed"],
	"enemies/snapper": ["range"],
	"enemies/decoration": ["prop"],
	"bosses/brute": ["arena", "left", "right", "speed", "enraged", "drops"],
	"bosses/colossus": ["arena", "drops"],
	"items/food": ["index"],
	"items/treasure": ["index"],
	"items/giant_bonus": ["index"],
	"items/letter": ["index"],
	"items/jackpot": [],
	"items/feast_piece": ["index"],
	"items/fire_starter": [],
	"items/heart": [],
	"items/one_up": [],
	"items/bone": [],
	"items/skull": [],
	"items/kill_all": [],
	"items/grenade": [],
	"items/weapon": ["kind"],
	"items/glider": [],
	"items/water_bucket": [],
	"items/warp": [],
	"items/trophy": [],
	"items/code_stone": ["index"],
	"items/random_bonus": ["tier"],
	"objects/checkpoint": [],
	"objects/exit": ["locked", "kind"],
	"objects/hidden_spot": ["kind", "count", "hits", "contents", "look", "prop"],
	"objects/breakable_block": ["hits", "skin", "contents"],
	"objects/container": ["skin", "contents", "hits"],
	"objects/platform": ["dir", "speed", "travel", "mode", "skin"],
	"objects/drop_platform": ["delay", "skin"],
	"objects/column": ["size", "rise", "trigger", "shake"],
	"objects/gate": ["dest", "lock", "skin"],
	"objects/marker": [],
	"objects/spring": ["power"],
	"objects/sign": ["text"],
	"objects/npc": ["kind", "turn"],
	"zones/secret": ["rect"],
	"zones/arena": ["rect", "music"],
	"zones/camera_lock": ["rect"],
	"zones/dark": ["rect", "on"],
	"zones/kill": ["rect"],
	"zones/autoscroll_stop": ["rect"],
	"zones/message": ["rect", "text"],
	"zones/ember_rain": ["rect", "period", "skin"],
	"zones/flies": ["rect", "count"],
}
## Parameters of scenery props.
const PROP_PARAMS: Array[String] = ["layer", "flip"]
## Enumerated parameter values: "id:param" -> allowed values.
const CHOICES: Dictionary = {
	"*:facing": ["l", "r", "left", "right"],
	"objects/exit:kind": ["exit", "warp", "trophy"],
	"objects/hidden_spot:kind": ["small", "big"],
	"objects/hidden_spot:look": ["plain", "inset", "block"],
	"objects/breakable_block:skin": ["auto", "dirt", "cave", "ice", "obsidian"],
	"objects/container:skin": ["barrel", "crate", "pot"],
	"objects/platform:mode": ["always", "ride"],
	"objects/platform:skin": ["wood", "ice", "stone", "small"],
	"objects/drop_platform:skin": ["wood", "ice", "stone", "small"],
	"objects/gate:skin": ["arch", "hole", "none"],
	"objects/npc:kind": ["elder", "kid", "warrior"],
	"items/weapon:kind": ["club", "hammer", "axe", "boomerang"],
	"props:layer": ["back", "front"],
	"zones/ember_rain:skin": ["ember", "leaf"],
}
## Integer parameters with their inclusive range: "id:param" -> Vector2i(min, max).
const RANGES: Dictionary = {
	"objects/hidden_spot:count": Vector2i(1, 64),
	"objects/hidden_spot:hits": Vector2i(1, 128),
	"objects/breakable_block:hits": Vector2i(1, 64),
	"objects/container:hits": Vector2i(1, 64),
	"objects/platform:dir": Vector2i(0, 7),
	"objects/platform:speed": Vector2i(1, 16),
	"objects/platform:travel": Vector2i(1, 9999),
	"objects/drop_platform:delay": Vector2i(0, 9999),
	"items/food:index": Vector2i(0, 47),
	"items/treasure:index": Vector2i(0, 15),
	"items/giant_bonus:index": Vector2i(0, 6),
	"items/letter:index": Vector2i(0, 4),
	"items/feast_piece:index": Vector2i(0, 2),
	"items/code_stone:index": Vector2i(0, 3),
	"items/random_bonus:tier": Vector2i(0, 2),
	"*:score": Vector2i(0, 11),
	"*:hp": Vector2i(0, 9999),
	"zones/ember_rain:period": Vector2i(1, 9999),
	"zones/flies:count": Vector2i(1, 20),
}
## Parameters that are a tile rectangle `c,r,w,h`.
const RECT_PARAMS: Array[String] = ["rect", "zone", "trigger"]
## Content tokens (`contents`, `drops`): item name -> range of its index argument (Vector2i(-1, -1) = none).
const CONTENT_ITEMS: Dictionary = {
	"food": Vector2i(0, 47), "treasure": Vector2i(0, 15), "giant_bonus": Vector2i(0, 6), "giant": Vector2i(0, 6),
	"letter": Vector2i(0, 4), "jackpot": Vector2i(-1, -1), "feast_piece": Vector2i(0, 2),
	"fire_starter": Vector2i(-1, -1), "heart": Vector2i(-1, -1), "one_up": Vector2i(-1, -1),
	"bone": Vector2i(-1, -1), "skull": Vector2i(-1, -1), "kill_all": Vector2i(-1, -1), "grenade": Vector2i(-1, -1),
	"weapon": Vector2i(-1, -1), "glider": Vector2i(-1, -1), "water_bucket": Vector2i(-1, -1),
	"warp": Vector2i(-1, -1), "trophy": Vector2i(-1, -1), "code_stone": Vector2i(0, 3),
	"random_bonus": Vector2i(0, 2), "random": Vector2i(0, 2),
}
## Entities whose anchor cell is meant to be solid (they ARE the tile, or live inside a wall).
const SOLID_ANCHOR_IDS: Array[String] = [
	"objects/hidden_spot", "objects/breakable_block", "objects/column", "bosses/colossus",
]
## Entities that must stand on a floor.
const GROUNDED_IDS: Array[String] = ["objects/exit", "objects/checkpoint"]
## Default `drops` of the bosses (ARCHITECTURE.md 6.2).
const BOSS_DROPS: Dictionary = {"bosses/brute": "fire_starter", "bosses/colossus": "trophy,trophy,trophy,trophy"}
const PASSWORD_CHARS: String = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"

## Every problem found by [method run]: { "path": String, "line": int, "severity": ERROR / WARNING,
## "message": String }, in file order.
var problems: Array[Dictionary] = []
## Level ids that count as existing for `next` / `bonus` besides the levels added (tests).
var known_ids: PackedStringArray = PackedStringArray()

var _levels: Array[LevelData] = []
var _all_ids: Dictionary = {}


## Add a level file. Returns false when it cannot be read (reported as an error).
func add_file(path: String) -> bool:
	var data: LevelData = LevelData.load_file(path)
	if data == null:
		_add(path, 0, ERROR, "cannot read the file")
		return false
	_levels.append(data)
	return true


## Add every `*.lvl` of a folder (sorted by name). Returns the number of files added.
func add_folder(dir_path: String) -> int:
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		_add(dir_path, 0, ERROR, "cannot open the folder")
		return 0
	var names: PackedStringArray = dir.get_files()
	names.sort()
	var count: int = 0
	for file_name: String in names:
		if file_name.get_extension() == "lvl" and add_file(dir_path.path_join(file_name)):
			count += 1
	return count


## Add a level from text (tests); `path` is what the messages show.
func add_text(level_id: StringName, text: String, path: String = "") -> void:
	_levels.append(LevelData.parse(level_id, text, path if path != "" else "%s.lvl" % level_id))


## Validate everything added. Levels reference each other (next, bonus, unique passwords), so all of them are
## checked together.
func run() -> void:
	_all_ids.clear()
	for id: String in known_ids:
		_all_ids[id] = true
	for data: LevelData in _levels:
		_all_ids[String(data.id)] = true
	for data: LevelData in _levels:
		_check_level(data)
	_check_passwords()


func error_count() -> int:
	return _count(ERROR)


func warning_count() -> int:
	return _count(WARNING)


## Problems of one file (all files when `path` is "").
func problems_of(path: String = "") -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for problem: Dictionary in problems:
		if path == "" or problem["path"] == path:
			result.append(problem)
	return result


## True when some problem's message contains `fragment` (tests).
func has_problem(fragment: String, severity: int = ERROR) -> bool:
	for problem: Dictionary in problems:
		if int(problem["severity"]) == severity and str(problem["message"]).contains(fragment):
			return true
	return false


## `file:line: error: message` (the format editors and CI understand).
static func format_problem(problem: Dictionary) -> String:
	return "%s:%d: %s: %s" % [
		problem["path"], problem["line"], "error" if int(problem["severity"]) == ERROR else "warning",
		problem["message"],
	]


# =================================================================================================================
# One level
# =================================================================================================================

func _check_level(data: LevelData) -> void:
	for issue: Dictionary in data.issues:
		_add(data.path, int(issue["line"]), ERROR, str(issue["message"]))
	for section: String in data.section_lines:
		if not LevelData.SECTIONS.has(section):
			_add(data.path, int(data.section_lines[section]), WARNING, "unknown section [%s] is ignored" % section)
	if not data.section_lines.has(LevelData.SECTION_META):
		_add(data.path, 1, ERROR, "the file has no [meta] section")
	if not data.section_lines.has(LevelData.SECTION_TILES):
		_add(data.path, 1, ERROR, "the file has no [tiles] section")
	_check_meta(data)
	var grid: TileGrid = data.build_grid()
	_check_tiles(data, grid)
	_check_legend(data)
	_check_entities(data, grid)
	_check_visual_sections(data)


func _check_meta(data: LevelData) -> void:
	var path: String = data.path
	if not data.meta.has("format"):
		_add(path, _meta_line(data, ""), ERROR, "meta key 'format' is required")
	elif data.meta["format"] != 1:
		_add(path, _meta_line(data, "format"), ERROR, "format must be 1 (found %s)" % str(data.meta["format"]))
	if not data.meta.has("id"):
		_add(path, _meta_line(data, ""), ERROR, "meta key 'id' is required")
	elif str(data.meta["id"]) != String(data.id):
		_add(path, _meta_line(data, "id"), ERROR, "id '%s' must equal the file name '%s'" % [data.meta["id"], data.id])
	if not _is_snake_case(String(data.id)):
		_add(path, _meta_line(data, "id"), ERROR, "level id '%s' must be lower_snake_case" % data.id)
	if not data.meta.has("terrain_a"):
		_add(path, _meta_line(data, ""), ERROR, "meta key 'terrain_a' is required")
	for key: String in data.meta:
		_check_meta_value(data, key, data.meta[key])


func _check_meta_value(data: LevelData, key: String, value: Variant) -> void:
	var path: String = data.path
	var line: int = _meta_line(data, key)
	var parts: PackedStringArray = key.split(".")
	var base: String = parts[0]
	if parts.size() > 2 or (parts.size() == 2 and not LevelData.DIFFICULTIES.has(parts[1])):
		_add(path, line, ERROR, "'%s': a variant suffix must be .beginner or .expert" % key)
		return
	if not LevelData.META_KEYS.has(base):
		_add(path, line, WARNING, "unknown meta key '%s'" % key)
		return
	if parts.size() == 2 and (base == "format" or base == "id"):
		_add(path, line, ERROR, "'%s' cannot have a difficulty variant" % base)
	var text: String = str(value)
	match base:
		"kind":
			_check_choice(path, line, key, text, LevelData.KINDS)
		"biome":
			_check_choice(path, line, key, text, LevelData.BIOMES)
		"liquid":
			_check_choice(path, line, key, text, LevelData.LIQUIDS)
		"background":
			_check_choice(path, line, key, text, LevelData.BACKGROUNDS)
		"scroll":
			_check_choice(path, line, key, text, LevelData.SCROLLS)
		"min_difficulty":
			_check_choice(path, line, key, text, LevelData.DIFFICULTIES)
		"terrain_a", "terrain_b":
			if not ResourceLoader.exists(LevelData.terrain_path(text)):
				_add(path, line, ERROR, "%s: terrain atlas '%s' does not exist (%s)" % [
					key, text, LevelData.terrain_path(text)])
		"music":
			if not AudioTable.MUSIC.has(StringName(text)):
				_add(path, line, ERROR, "music '%s' is not a known music context" % text)
		"ice_a", "ice_b":
			_check_int(path, line, key, value, 0, Tuning.ICE_MAX)
		"bonus_tier":
			_check_int(path, line, key, value, 0, 2)
		"time":
			_check_int(path, line, key, value, 0, 99999)
		"world", "stage", "order":
			_check_int(path, line, key, value, 0, 99999)
		"home_row":
			_check_int(path, line, key, value, -1, maxi(data.row_count() - 1, -1))
		"tally", "low_band", "fast_vscroll", "dark":
			if not value is bool:
				_add(path, line, ERROR, "%s must be true or false" % key)
		"password_beginner", "password_expert":
			if text != "" and not _is_password(text):
				_add(path, line, ERROR, "%s '%s' must be 4 characters 0-9 / A-Z" % [key, text])
		"next", "bonus":
			if text != "" and not _all_ids.has(text):
				_add(path, line, ERROR, "%s '%s' is not a level" % [key, text])
		"wind":
			for entry: String in LevelText.to_list(value):
				var pair: PackedStringArray = entry.split(":")
				if pair.size() != 2 or not pair[0].is_valid_int() or not pair[1].is_valid_int() \
						or pair[0].to_int() < 0:
					_add(path, line, ERROR, "wind entry '%s' must be tick:value" % entry)
		"id", "name", "format", "author", "notes":
			pass


func _check_tiles(data: LevelData, grid: TileGrid) -> void:
	var path: String = data.path
	var tiles_line: int = int(data.section_lines.get(LevelData.SECTION_TILES, 0))
	if data.cols < MIN_COLS or data.cols > Tuning.MAP_MAX_COLS or data.row_count() < MIN_ROWS \
			or data.row_count() > Tuning.MAP_MAX_ROWS:
		_add(path, tiles_line, ERROR, "size %d x %d tiles is outside %d..%d x %d..%d" % [
			data.cols, data.row_count(), MIN_COLS, Tuning.MAP_MAX_COLS, MIN_ROWS, Tuning.MAP_MAX_ROWS])
	for row: int in data.row_count():
		var line: String = data.rows[row]
		var bad: PackedStringArray = PackedStringArray()
		for col: int in line.length():
			var ch: String = line[col]
			if not TileGrid.LEGEND_CHARS.contains(ch) and not data.legend.has(ch) and not bad.has(ch):
				bad.append(ch)
			if _is_slope_char(grid.get_char(col, row)):
				var below: String = grid.get_char(col, row + 1)
				if below != TileGrid.CH_SOLID_A and below != TileGrid.CH_SOLID_B:
					_add(path, data.row_lines[row], ERROR,
							"slope '%s' at column %d, row %d must stand on '#' or '%%'" % [ch, col, row])
		for ch: String in bad:
			_add(path, data.row_lines[row], ERROR,
					"character '%s' in row %d is neither a fixed tile nor defined in [legend]" % [ch, row])
	var starts: Array[Vector2i] = data.find_starts()
	if starts.size() != 1:
		_add(path, tiles_line, ERROR, "the level needs exactly one hero start '@' (found %d)" % starts.size())
	for start: Vector2i in starts:
		if not TileGrid.is_ground(grid.floor_at(start.x, start.y + 1)):
			_add(path, data.row_lines[start.y], ERROR,
					"the hero start at column %d, row %d must stand on a floor" % [start.x, start.y])


func _check_legend(data: LevelData) -> void:
	var used: Dictionary = {}
	for line: String in data.rows:
		for i: int in line.length():
			used[line[i]] = true
	for key: String in data.legend_lines:
		var line: int = int(data.legend_lines[key])
		var params: Dictionary = data.legend[key]["params"]
		if params.has("tile"):
			var tile: String = str(params["tile"])
			if tile.length() != 1 or not TileGrid.LEGEND_CHARS.contains(tile) or tile == TileGrid.CH_PLAYER_START:
				_add(data.path, line, ERROR, "legend '%s': tile=%s must be one fixed tile character" % [key, tile])
		if not used.has(key) and not LevelText.DEFAULT_LEGEND.has(key):
			_add(data.path, line, WARNING, "legend character '%s' is never used in [tiles]" % key)


func _check_entities(data: LevelData, grid: TileGrid) -> void:
	var records: Array[Dictionary] = data.entity_records()
	var names: Dictionary = {}          # name -> id
	var name_lines: Dictionary = {}     # name -> line
	for record: Dictionary in records:
		var params: Dictionary = record["params"]
		if params.has("name"):
			var entity_name: String = str(params["name"])
			if names.has(entity_name):
				_add(data.path, int(record["line"]), ERROR,
						"name '%s' is used more than once (find_named needs it unique)" % entity_name)
			names[entity_name] = String(record["id"])
			name_lines[entity_name] = int(record["line"])
	var checked_chars: Dictionary = {}
	for key: String in data.legend_lines:
		var used: bool = false
		for line: String in data.rows:
			if line.contains(key):
				used = true
				break
		if not used:
			var entry: Dictionary = data.legend[key]
			_check_entity(data, {
				"id": entry["id"], "params": entry["params"], "line": data.legend_lines[key], "char": key,
			}, names)
	for record: Dictionary in records:
		var ch: String = record["char"]
		if ch != "" and checked_chars.has(ch):
			_check_position(data, grid, record)
			continue
		checked_chars[ch] = true
		_check_entity(data, record, names)
		_check_position(data, grid, record)
	for entity_name: String in names:
		if names[entity_name] == "zones/arena":
			var referenced: bool = false
			for record: Dictionary in records:
				if str(record["params"].get("arena", "")) == entity_name and Spawner.category(record["id"]) == "bosses":
					referenced = true
			if not referenced:
				_add(data.path, int(name_lines[entity_name]), WARNING,
						"arena '%s' has no boss (it will never lock the camera)" % entity_name)
	for difficulty: int in [Defs.Difficulty.BEGINNER, Defs.Difficulty.EXPERT]:
		_check_limits(data, records, difficulty)
	_check_exit_path(data, records)


func _check_entity(data: LevelData, record: Dictionary, names: Dictionary) -> void:
	var path: String = data.path
	var line: int = int(record["line"])
	var id: String = String(record["id"])
	var params: Dictionary = record["params"]
	var category: String = Spawner.category(StringName(id))
	if not Spawner.CATEGORIES.has(category):
		_add(path, line, ERROR, "'%s' has no known category (%s)" % [id, ", ".join(Spawner.CATEGORIES)])
		return
	if params.has("expert") and params.has("beginner") and bool(params["expert"]) and bool(params["beginner"]):
		_add(path, line, WARNING, "'%s' is marked both expert and beginner: it never spawns" % id)
	match category:
		"player", "projectiles":
			_add(path, line, ERROR, "'%s' is spawned by code and cannot be placed in a level" % id)
			return
		"fx":
			_add(path, line, WARNING, "'%s' is a one-shot effect; placing it in a level shows it once at load" % id)
		"props":
			_check_prop(path, line, id, params)
			return
	if not CATALOGUE.has(id):
		_add(path, line, WARNING, "'%s' is not in the entity catalogue (ARCHITECTURE.md 6.2)" % id)
	if not Spawner.exists(StringName(id)):
		_add(path, line, WARNING, "no scene for '%s' yet (%s)" % [id, Spawner.scene_path(StringName(id))])
	_check_params(path, line, id, category, params)
	if params.has("dest") and not names.has(str(params["dest"])):
		_add(path, line, ERROR, "dest '%s' is not the name of a gate or marker" % str(params["dest"]))
	elif params.has("dest") and not ["objects/gate", "objects/marker"].has(names[str(params["dest"])]):
		_add(path, line, ERROR, "dest '%s' names a %s, not a gate or marker" % [
			str(params["dest"]), names[str(params["dest"])]])
	if params.has("arena") and category == "bosses":
		var arena: String = str(params["arena"])
		if names.get(arena, "") != "zones/arena":
			_add(path, line, ERROR, "arena '%s' is not the name of a zones/arena" % arena)
	if category == "zones" and not params.has("rect"):
		_add(path, line, ERROR, "'%s' needs rect=c,r,w,h" % id)
	if id == "zones/arena" and not params.has("name"):
		_add(path, line, ERROR, "zones/arena needs a name (bosses refer to it with arena=)")
	if id == "items/warp" and str(data.value("kind")) != "bonus" and str(data.value("bonus")) == "":
		_add(path, line, WARNING, "items/warp in a level without a 'bonus' stage acts as a plain exit")
	for key: String in ["contents", "drops"]:
		if params.has(key):
			_check_contents(path, line, key, str(params[key]))
	for key: String in RECT_PARAMS:
		if params.has(key):
			_check_rect(data, line, key, params[key])
	if params.has("lock"):
		var cell: PackedInt32Array = LevelText.to_int_list(params["lock"])
		if cell.size() != 2 or cell[0] < 0 or cell[1] < 0 or cell[0] >= data.cols or cell[1] >= data.row_count():
			_add(path, line, ERROR, "lock=%s must be a camera cell c,r inside the map" % str(params["lock"]))
	if params.has("size"):
		var size: PackedInt32Array = LevelText.to_int_list(params["size"])
		if size.size() != 2 or size[0] <= 0 or size[1] <= 0:
			_add(path, line, ERROR, "size=%s must be w,h in tiles" % str(params["size"]))
	if id == "enemies/decoration" and params.has("prop"):
		_check_prop_name(path, line, "props/" + str(params["prop"]))
	if id == "objects/hidden_spot" and params.has("prop"):
		_check_prop_name(path, line, "props/" + str(params["prop"]))


func _check_prop(path: String, line: int, id: String, params: Dictionary) -> void:
	_check_prop_name(path, line, id)
	for key: String in params:
		if not PROP_PARAMS.has(key) and not COMMON_PARAMS.has(key):
			_add(path, line, WARNING, "'%s': unknown prop parameter '%s'" % [id, key])
	if params.has("layer"):
		_check_choice(path, line, "layer", str(params["layer"]), CHOICES["props:layer"])


func _check_prop_name(path: String, line: int, id: String) -> void:
	var texture: String = Spawner.prop_texture_path(StringName(id))
	if texture.is_empty():
		_add(path, line, ERROR, "'%s' must be props/<biome>/<name>" % id)
	elif not ResourceLoader.exists(texture):
		_add(path, line, ERROR, "prop '%s' does not exist (%s)" % [id, texture])


func _check_params(path: String, line: int, id: String, category: String, params: Dictionary) -> void:
	var allowed: Array = []
	allowed.append_array(COMMON_PARAMS)
	allowed.append_array(CATALOGUE.get(id, []))
	if category == "enemies" or category == "bosses":
		allowed.append_array(ENEMY_PARAMS)
	if category == "items":
		allowed.append_array(ITEM_PARAMS)
	for key: String in params:
		if CATALOGUE.has(id) and not allowed.has(key):
			_add(path, line, WARNING, "'%s': unknown parameter '%s'" % [id, key])
		var choice_key: String = "%s:%s" % [id, key]
		if not CHOICES.has(choice_key):
			choice_key = "*:%s" % key
		if CHOICES.has(choice_key):
			_check_choice(path, line, "%s %s" % [id, key], str(params[key]), CHOICES[choice_key])
		var range_key: String = "%s:%s" % [id, key]
		if not RANGES.has(range_key):
			range_key = "*:%s" % key
		if RANGES.has(range_key):
			var bounds: Vector2i = RANGES[range_key]
			_check_int(path, line, "%s %s" % [id, key], params[key], bounds.x, bounds.y)
	if params.has("tile") and not str(params["tile"]).length() == 1:
		_add(path, line, ERROR, "'%s': tile=%s must be one fixed tile character" % [id, str(params["tile"])])


func _check_contents(path: String, line: int, key: String, text: String) -> void:
	var tokens: PackedStringArray = LevelText.to_list(text)
	if tokens.is_empty():
		_add(path, line, ERROR, "%s is empty" % key)
	for token: String in tokens:
		var pieces: PackedStringArray = token.split(":")
		var item: String = pieces[0]
		if pieces.size() > 2 or not CONTENT_ITEMS.has(item):
			_add(path, line, ERROR, "%s token '%s' is not <item name>[:<index or kind>]" % [key, token])
			continue
		if pieces.size() == 1:
			continue
		var argument: String = pieces[1]
		if item == "weapon":
			if not CHOICES["items/weapon:kind"].has(argument):
				_add(path, line, ERROR, "%s token '%s': weapon kind must be club, hammer, axe or boomerang" % [
					key, token])
			continue
		var bounds: Vector2i = CONTENT_ITEMS[item]
		if bounds.x < 0:
			_add(path, line, ERROR, "%s token '%s': '%s' takes no index" % [key, token, item])
		elif not argument.is_valid_int() or argument.to_int() < bounds.x or argument.to_int() > bounds.y:
			_add(path, line, ERROR, "%s token '%s': index must be %d..%d" % [key, token, bounds.x, bounds.y])


func _check_rect(data: LevelData, line: int, key: String, value: Variant) -> void:
	var parts: PackedInt32Array = LevelText.to_int_list(value)
	if parts.size() != 4 or parts[2] <= 0 or parts[3] <= 0:
		_add(data.path, line, ERROR, "%s=%s must be c,r,w,h in tiles" % [key, str(value)])
		return
	var rect: Rect2i = Rect2i(parts[0], parts[1], parts[2], parts[3])
	if not Rect2i(0, 0, data.cols, data.row_count()).encloses(rect):
		_add(data.path, line, ERROR, "%s=%s reaches outside the %d x %d map" % [
			key, str(value), data.cols, data.row_count()])


func _check_position(data: LevelData, grid: TileGrid, record: Dictionary) -> void:
	var id: String = String(record["id"])
	var params: Dictionary = record["params"]
	var feet: Vector2i = LevelText.cell_to_feet(float(record["col"]), float(record["row"]), params)
	var col: int = Tuning.to_cell(feet.x)
	var row: int = Tuning.to_cell(feet.y - 1)
	var line: int = int(record["line"])
	if col < 0 or row < 0 or col >= data.cols or row >= data.row_count():
		_add(data.path, line, ERROR, "'%s' at column %d, row %d is outside the map" % [id, col, row])
		return
	var category: String = Spawner.category(StringName(id))
	if category == "props" or category == "zones" or params.has("tile") or SOLID_ANCHOR_IDS.has(id):
		return
	var ch: String = grid.get_char(col, row)
	if ch == TileGrid.CH_SOLID_A or ch == TileGrid.CH_SOLID_B or ch == TileGrid.CH_SOLID_INVISIBLE:
		_add(data.path, line, ERROR, "'%s' at column %d, row %d is inside a solid tile" % [id, col, row])
	elif GROUNDED_IDS.has(id) and not TileGrid.is_ground(grid.floor_at(col, row + 1)):
		_add(data.path, line, WARNING, "'%s' at column %d, row %d does not stand on a floor" % [id, col, row])


func _check_limits(data: LevelData, records: Array[Dictionary], difficulty: int) -> void:
	var enemies: int = 0
	var items: int = 0
	var hittables: int = 0
	var platforms: int = 0
	for record: Dictionary in records:
		if not LevelText.applies_to(record["params"], difficulty):
			continue
		var id: String = String(record["id"])
		match Spawner.category(StringName(id)):
			"enemies", "bosses":
				enemies += 1
			"items":
				items += 1
		if id == "objects/hidden_spot" or id == "objects/breakable_block" or id == "objects/container":
			hittables += 1
		elif id == "objects/platform" or id == "objects/drop_platform":
			platforms += 1
	var mode: String = Defs.difficulty_name(difficulty)
	var line: int = int(data.section_lines.get(LevelData.SECTION_TILES, 0))
	if enemies > MAX_ENEMIES:
		_add(data.path, line, ERROR, "%d enemies in %s (at most %d)" % [enemies, mode, MAX_ENEMIES])
	if items > MAX_ITEMS:
		_add(data.path, line, ERROR, "%d placed items in %s (at most %d)" % [items, mode, MAX_ITEMS])
	if hittables > MAX_HITTABLES:
		_add(data.path, line, ERROR, "%d hittables in %s (at most %d)" % [hittables, mode, MAX_HITTABLES])
	if platforms > MAX_PLATFORMS:
		_add(data.path, line, ERROR, "%d platforms in %s (at most %d)" % [platforms, mode, MAX_PLATFORMS])


## Exactly one way out (section 7.7): one objects/exit; bonus stages may use items/warp instead, a final boss
## level the trophy its boss drops. A locked exit needs a fire-starter somewhere.
func _check_exit_path(data: LevelData, records: Array[Dictionary]) -> void:
	var exits: Array[Dictionary] = []
	var warps: int = 0
	var trophies: int = 0
	var fire_starters: int = 0
	for record: Dictionary in records:
		var id: String = String(record["id"])
		var params: Dictionary = record["params"]
		match id:
			"objects/exit":
				exits.append(record)
			"items/warp":
				warps += 1
			"items/trophy":
				trophies += 1
			"items/fire_starter":
				fire_starters += 1
		var dropped: String = str(params.get("contents", ""))
		if Spawner.category(StringName(id)) == "bosses":
			dropped = str(params.get("drops", BOSS_DROPS.get(id, "")))
		for token: String in LevelText.to_list(dropped):
			var item: String = token.split(":")[0]
			if item == "trophy":
				trophies += 1
			elif item == "fire_starter":
				fire_starters += 1
	var line: int = int(data.section_lines.get(LevelData.SECTION_TILES, 0))
	# Developer levels may leave out the way out; the campaign may not.
	var missing: int = WARNING if str(data.value("kind")) == "test" else ERROR
	if exits.size() > 1:
		var message: String = "the level has %d objects/exit (exactly one allowed)" % exits.size()
		_add(data.path, int(exits[1]["line"]), ERROR, message)
	elif exits.is_empty():
		var kind: String = str(data.value("kind"))
		if kind == "bonus":
			if warps == 0:
				_add(data.path, line, missing, "a bonus stage needs an items/warp or an objects/exit to leave it")
		elif trophies == 0:
			_add(data.path, line, missing, "the level has no exit (objects/exit, or a trophy dropped by a boss)")
	for exit: Dictionary in exits:
		var params: Dictionary = exit["params"]
		if params.has("locked") and bool(params["locked"]) and fire_starters == 0:
			_add(data.path, int(exit["line"]), ERROR,
					"the exit is locked but no fire-starter is placed, hidden or dropped by a boss")


func _check_visual_sections(data: LevelData) -> void:
	var map: Rect2i = Rect2i(0, 0, data.cols, data.row_count())
	for wall: Dictionary in data.backwalls:
		var rect: Rect2i = wall["rect"]
		if rect.size.x <= 0 or rect.size.y <= 0 or not map.encloses(rect):
			_add(data.path, int(wall["line"]), ERROR, "back wall %s is empty or reaches outside the map" % str(rect))
		var deco: int = int(wall["deco"])
		if deco < 0 or deco > 100:
			_add(data.path, int(wall["line"]), ERROR, "deco=%d must be 0..100" % deco)
	for entry: Dictionary in data.overrides:
		var cell: Vector2i = entry["cell"]
		var line: int = int(entry["line"])
		if not map.has_point(cell):
			_add(data.path, line, ERROR, "override cell %s is outside the map" % str(cell))
		var index: int = int(entry["index"])
		if index < 0 or index >= LevelTiles.ATLAS_TILES:
			_add(data.path, line, ERROR, "atlas index %d must be 0..%d" % [index, LevelTiles.ATLAS_TILES - 1])
		if not LevelData.OVERRIDE_LAYERS.has(str(entry["layer"])):
			_add(data.path, line, ERROR, "override layer '%s' must be back, main or front" % entry["layer"])


# =================================================================================================================
# Across levels
# =================================================================================================================

func _check_passwords() -> void:
	var seen: Dictionary = {}
	for data: LevelData in _levels:
		var kind: String = str(data.value("kind"))
		for key: String in data.meta:
			if not key.begins_with("password_"):
				continue
			var code: String = str(data.meta[key]).to_upper()
			if code == "":
				continue
			# O / 0 and I / 1 are the same character for the code screen (Levels.normalize_code).
			var same: String = code.replace("O", "0").replace("I", "1")
			if seen.has(same):
				_add(data.path, _meta_line(data, key), ERROR,
						"password '%s' is already used by %s (O = 0, I = 1)" % [code, seen[same]])
			else:
				seen[same] = "%s (%s)" % [data.path.get_file(), key]
			if kind == "bonus":
				_add(data.path, _meta_line(data, key), WARNING,
						"%s: a bonus stage started by its code has no source level to return to; only its warp should lead in" % key)
			if key == "password_beginner" and str(data.value("min_difficulty")) == "expert":
				_add(data.path, _meta_line(data, key), WARNING,
						"password_beginner on an Expert-only level (min_difficulty = expert) can never be used")


# =================================================================================================================
# Helpers
# =================================================================================================================

func _add(path: String, line: int, severity: int, message: String) -> void:
	problems.append({"path": path, "line": line, "severity": severity, "message": message})


func _count(severity: int) -> int:
	var count: int = 0
	for problem: Dictionary in problems:
		if int(problem["severity"]) == severity:
			count += 1
	return count


func _meta_line(data: LevelData, key: String) -> int:
	if data.meta_lines.has(key):
		return int(data.meta_lines[key])
	return int(data.section_lines.get(LevelData.SECTION_META, 1))


func _check_choice(path: String, line: int, key: String, value: String, allowed: Array) -> void:
	if not allowed.has(value):
		_add(path, line, ERROR, "%s '%s' must be one of: %s" % [key, value, ", ".join(PackedStringArray(allowed))])


func _check_int(path: String, line: int, key: String, value: Variant, low: int, high: int) -> void:
	if not value is int or int(value) < low or int(value) > high:
		_add(path, line, ERROR, "%s = %s must be an integer %d..%d" % [key, str(value), low, high])


static func _is_slope_char(ch: String) -> bool:
	return ch == TileGrid.CH_SLOPE_UP_RIGHT or ch == TileGrid.CH_SLOPE_UP_LEFT or ch == TileGrid.CH_GENTLE_UR_LOW \
			or ch == TileGrid.CH_GENTLE_UR_HIGH or ch == TileGrid.CH_GENTLE_UL_HIGH or ch == TileGrid.CH_GENTLE_UL_LOW


static func _is_snake_case(text: String) -> bool:
	if text.is_empty() or not (text[0] >= "a" and text[0] <= "z"):
		return false
	for i: int in text.length():
		var c: String = text[i]
		if not ((c >= "a" and c <= "z") or (c >= "0" and c <= "9") or c == "_"):
			return false
	return true


static func _is_password(text: String) -> bool:
	if text.length() != 4:
		return false
	for i: int in text.length():
		if not PASSWORD_CHARS.contains(text[i]):
			return false
	return true
