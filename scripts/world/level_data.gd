class_name LevelData
extends RefCounted
## One parsed level file (docs/ARCHITECTURE.md 7). Owner: world.
##
## The single reader of the level format above the lexical layer: the loader (Level), the validator
## (LevelValidator) and the preview renderer (LevelRenderer) all work on this class, so they cannot disagree
## about what a file means. Syntax (sections, values, legend and entity lines) comes from LevelText; this class
## adds the defaults of section 7.3, the difficulty variants, typed records and SOURCE LINE NUMBERS.
##
## Parsing never logs: every syntax problem is collected in [member issues] with its line, and the caller decides
## what to do with it (the loader reports it once and carries on, the validator prints `file:line: message`).

const SECTION_META: String = "meta"
const SECTION_LEGEND: String = "legend"
const SECTION_TILES: String = "tiles"
const SECTION_ENTITIES: String = "entities"
const SECTION_BACKWALL: String = "backwall"
const SECTION_OVERRIDES: String = "overrides"
## Every section of format 1.
const SECTIONS: Array[String] = ["meta", "legend", "tiles", "entities", "backwall", "overrides"]

const KINDS: Array[String] = ["main", "sub", "bonus", "ending", "test"]
const BIOMES: Array[String] = ["jungle", "cave", "ice", "volcano", "feast", "village"]
const LIQUIDS: Array[String] = ["water", "lava", "ice_water"]
const BACKGROUNDS: Array[String] = ["jungle", "cave", "ice", "volcano", "volcano_shaft", "feast", "none"]
const SCROLLS: Array[String] = ["normal", "vertical", "autoscroll"]
const DIFFICULTIES: Array[String] = ["beginner", "expert"]
const OVERRIDE_LAYERS: Array[String] = ["back", "main", "front"]

## Parallax set used when `background` is missing, by biome.
const BIOME_BACKGROUND: Dictionary = {
	"jungle": "jungle", "cave": "cave", "ice": "ice", "volcano": "volcano", "feast": "feast", "village": "jungle",
}
## Music context used when `music` is missing, by biome.
const BIOME_MUSIC: Dictionary = {
	"jungle": Sfx.MUSIC_JUNGLE, "cave": Sfx.MUSIC_CAVE, "ice": Sfx.MUSIC_ICE, "volcano": Sfx.MUSIC_VOLCANO,
	"feast": Sfx.MUSIC_BONUS, "village": Sfx.MUSIC_ENDING,
}
## Terrain atlas used when `terrain_a` is missing or does not exist, by biome.
const BIOME_TERRAIN: Dictionary = {
	"jungle": "jungle/terrain_grass", "cave": "cave/terrain", "ice": "ice/terrain", "volcano": "volcano/terrain",
	"feast": "feast/terrain", "village": "jungle/terrain_grass",
}
## Plain defaults of the [meta] keys (section 7.3). Keys whose default depends on other keys (`name`,
## `terrain_a`, `terrain_b`, `background`, `music`, `fast_vscroll`, `bonus_tier`) are resolved in [method value].
const META_DEFAULTS: Dictionary = {
	"format": 0, "id": "", "kind": "main", "world": 0, "stage": 0, "biome": "jungle", "ice_a": 0, "ice_b": 0,
	"liquid": "water", "time": 0, "password_beginner": "", "password_expert": "", "next": "", "tally": true,
	"bonus": "", "min_difficulty": "beginner", "scroll": "normal", "low_band": false, "home_row": -1,
	"dark": false, "wind": "",
}
## Every key a [meta] section may contain (a difficulty suffix `.beginner` / `.expert` may follow any of them).
const META_KEYS: Array[String] = [
	"format", "id", "name", "kind", "order", "world", "stage", "biome", "terrain_a", "terrain_b", "ice_a", "ice_b",
	"liquid", "background", "music", "time", "password_beginner", "password_expert", "next", "tally", "bonus",
	"min_difficulty", "scroll", "low_band", "home_row", "fast_vscroll", "dark", "wind", "bonus_tier", "author",
	"notes",
]
const TERRAIN_DIR: String = "res://assets/tiles/"

## Level id (the file name without extension).
var id: StringName = &""
## Path of the file ("" when the text did not come from a file).
var path: String = ""
## The [meta] section exactly as written (difficulty variants are separate keys). Use [method value] to read it.
var meta: Dictionary = {}
## Legend of the level: built-in entries overridden by the [legend] lines. { char: { "char", "id", "params" } }.
var legend: Dictionary = {}
## Characters defined by the level's own [legend] lines, mapped to their source line.
var legend_lines: Dictionary = {}
## The rows of [tiles], verbatim.
var rows: PackedStringArray = PackedStringArray()
## Width of the widest row, in tiles.
var cols: int = 0
## Entity records of [entities], in file order: { "id", "col", "row", "params", "line" }.
var entities: Array[Dictionary] = []
## Back-wall rectangles: { "rect": Rect2i (tiles), "set_b": bool, "deco": int, "line": int }.
var backwalls: Array[Dictionary] = []
## Tile overrides: { "cell": Vector2i, "set_b": bool, "index": int, "layer": String, "line": int }.
var overrides: Array[Dictionary] = []
## Names of the sections found in the file, in file order (unknown ones included), mapped to their header line.
var section_lines: Dictionary = {}
## Source line of every [meta] key (variants included).
var meta_lines: Dictionary = {}
## Source line of every row of [tiles].
var row_lines: PackedInt32Array = PackedInt32Array()
## Syntax problems found while parsing: { "line": int, "message": String }.
var issues: Array[Dictionary] = []


## Parse the text of a level file. Never returns null and never logs.
static func parse(level_id: StringName, text: String, file_path: String = "") -> LevelData:
	var data: LevelData = LevelData.new()
	data.id = level_id
	data.path = file_path
	data._parse(text)
	return data


## Read and parse a level file. Returns null when the file cannot be read.
static func load_file(file_path: String) -> LevelData:
	if not FileAccess.file_exists(file_path):
		return null
	var text: String = FileAccess.get_file_as_string(file_path)
	return parse(StringName(file_path.get_file().get_basename()), text, file_path)


## Number of tile rows.
func row_count() -> int:
	return rows.size()


## True when [meta] contains the key (plain or as a variant of `difficulty`).
func has_value(key: String, difficulty: int = -1) -> bool:
	if difficulty >= 0 and meta.has("%s.%s" % [key, Defs.difficulty_name(difficulty)]):
		return true
	return meta.has(key)


## A [meta] value with the difficulty variant and the defaults of section 7.3 applied.
func value(key: String, difficulty: int = -1) -> Variant:
	if difficulty >= 0:
		var variant_key: String = "%s.%s" % [key, Defs.difficulty_name(difficulty)]
		if meta.has(variant_key):
			return meta[variant_key]
	if meta.has(key):
		return meta[key]
	match key:
		"name":
			return String(id)
		"terrain_a":
			return str(BIOME_TERRAIN.get(str(value("biome", difficulty)), BIOME_TERRAIN["jungle"]))
		"terrain_b":
			return value("terrain_a", difficulty)
		"background":
			return str(BIOME_BACKGROUND.get(str(value("biome", difficulty)), "jungle"))
		"music":
			return String(BIOME_MUSIC.get(str(value("biome", difficulty)), Sfx.MUSIC_JUNGLE))
		"fast_vscroll":
			return str(value("background", difficulty)) != "none"
		"bonus_tier":
			return clampi(int(value("world", difficulty)) - 1, 0, 2)
	return META_DEFAULTS.get(key, "")


## The complete header for one difficulty: every key of section 7.3 with variants and defaults resolved, plus
## whatever else the file contains. This is what LevelBase.meta holds while the level runs.
func resolved_meta(difficulty: int) -> Dictionary:
	var result: Dictionary = meta.duplicate()
	for key: String in META_KEYS:
		if key == "order" or key == "author" or key == "notes":
			continue
		result[key] = value(key, difficulty)
	return result


## Resource path of a terrain atlas named in [meta] ("jungle/terrain_grass" -> res://assets/tiles/....png).
static func terrain_path(atlas: String) -> String:
	return "%s%s.png" % [TERRAIN_DIR, atlas]


## Resource path of a liquid strip ("water" -> res://assets/tiles/common/water.png).
static func liquid_path(liquid: String) -> String:
	return "%scommon/%s.png" % [TERRAIN_DIR, liquid]


## Collision grid of the level (TileGrid is the only definition of what a tile character means).
func build_grid(difficulty: int = -1) -> TileGrid:
	return TileGrid.from_rows(
		rows, int(value("ice_a", difficulty)), int(value("ice_b", difficulty)), LevelText.legend_tiles(legend)
	)


## Cells that contain the hero start character, in reading order.
func find_starts() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for row: int in rows.size():
		var line: String = rows[row]
		var col: int = line.find(TileGrid.CH_PLAYER_START)
		while col >= 0:
			result.append(Vector2i(col, row))
			col = line.find(TileGrid.CH_PLAYER_START, col + 1)
	return result


## Every entity the file places, in SPAWN ORDER: the legend characters of the grid row by row and left to right,
## then the lines of [entities]. Records are { "id": StringName, "col": float, "row": float, "params": Dictionary,
## "line": int, "char": String ("" for [entities] lines) }. Difficulty flags are NOT applied here.
func entity_records() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for row: int in rows.size():
		var line: String = rows[row]
		for col: int in line.length():
			var ch: String = line[col]
			if not legend.has(ch):
				continue
			var entry: Dictionary = legend[ch]
			result.append({
				"id": entry["id"], "col": float(col), "row": float(row), "params": entry["params"],
				"line": row_lines[row] if row < row_lines.size() else 0, "char": ch,
			})
	for record: Dictionary in entities:
		var copy: Dictionary = record.duplicate()
		copy["char"] = ""
		result.append(copy)
	return result


## The wind script of [meta] `wind` ("tick:value,tick:value") as (tick, value) pairs sorted by tick.
## Malformed entries are skipped (the validator reports them through [method wind_problems]).
func wind_script(difficulty: int = -1) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for part: String in LevelText.to_list(value("wind", difficulty)):
		var pair: PackedStringArray = part.split(":")
		if pair.size() == 2 and pair[0].is_valid_int() and pair[1].is_valid_int():
			result.append(Vector2i(pair[0].to_int(), pair[1].to_int()))
	result.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x < b.x)
	return result


## Entries of the wind script that are not `tick:value` with a non-negative tick.
func wind_problems(difficulty: int = -1) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for part: String in LevelText.to_list(value("wind", difficulty)):
		var pair: PackedStringArray = part.split(":")
		if pair.size() != 2 or not pair[0].is_valid_int() or not pair[1].is_valid_int() or pair[0].to_int() < 0:
			result.append(part)
	return result


func _parse(text: String) -> void:
	var was_quiet: bool = LevelText.quiet
	var kept: PackedStringArray = LevelText.problems
	LevelText.quiet = true
	LevelText.clear_problems()
	var sections: Dictionary = LevelText.split_sections(text)
	var numbers: Dictionary = _line_numbers(text, sections)
	_parse_meta(sections.get(SECTION_META, PackedStringArray()), numbers.get(SECTION_META, PackedInt32Array()))
	_parse_legend(sections.get(SECTION_LEGEND, PackedStringArray()), numbers.get(SECTION_LEGEND, PackedInt32Array()))
	rows = sections.get(SECTION_TILES, PackedStringArray())
	row_lines = numbers.get(SECTION_TILES, PackedInt32Array())
	cols = 0
	for line: String in rows:
		cols = maxi(cols, line.length())
	_parse_entities(
		sections.get(SECTION_ENTITIES, PackedStringArray()), numbers.get(SECTION_ENTITIES, PackedInt32Array())
	)
	_parse_backwalls(
		sections.get(SECTION_BACKWALL, PackedStringArray()), numbers.get(SECTION_BACKWALL, PackedInt32Array())
	)
	_parse_overrides(
		sections.get(SECTION_OVERRIDES, PackedStringArray()), numbers.get(SECTION_OVERRIDES, PackedInt32Array())
	)
	LevelText.problems = kept
	LevelText.quiet = was_quiet


## Source line (1-based) of every line LevelText.split_sections keeps, per section, and the header lines.
## Mirrors the rules of split_sections: outside raw sections blank and comment lines are dropped.
func _line_numbers(text: String, sections: Dictionary) -> Dictionary:
	var numbers: Dictionary = {}
	var current: String = ""
	var raw: bool = false
	var number: int = 0
	for source_line: String in text.split("\n"):
		number += 1
		var line: String = source_line.trim_suffix("\r")
		var stripped: String = line.strip_edges()
		var header: String = LevelText.section_name(stripped)
		if header != "":
			current = header
			raw = LevelText.RAW_SECTIONS.has(current)
			if not numbers.has(current):
				numbers[current] = PackedInt32Array()
				section_lines[current] = number
			continue
		if current == "":
			continue
		var keep: bool = line != "" if raw else (stripped != "" and not stripped.begins_with("#"))
		if keep:
			var list: PackedInt32Array = numbers[current]
			list.append(number)
			numbers[current] = list
	# Never trust the mirror blindly: a mismatch would attach problems to wrong lines.
	for section: String in sections:
		var lines: PackedStringArray = sections[section]
		var list: PackedInt32Array = numbers.get(section, PackedInt32Array())
		if list.size() != lines.size():
			list.resize(lines.size())
			list.fill(int(section_lines.get(section, 0)))
			numbers[section] = list
	return numbers


func _take_problems(line: int) -> bool:
	if LevelText.problems.is_empty():
		return false
	for message: String in LevelText.problems:
		issues.append({"line": line, "message": message.trim_prefix("LevelText: ")})
	LevelText.clear_problems()
	return true


func _parse_meta(lines: PackedStringArray, numbers: PackedInt32Array) -> void:
	for i: int in lines.size():
		var parsed: Dictionary = LevelText.parse_key_values(PackedStringArray([lines[i]]))
		_take_problems(numbers[i])
		for key: String in parsed:
			if meta.has(key):
				issues.append({"line": numbers[i], "message": "meta key '%s' is defined twice" % key})
			meta[key] = parsed[key]
			meta_lines[key] = numbers[i]


func _parse_legend(lines: PackedStringArray, numbers: PackedInt32Array) -> void:
	legend = LevelText.parse_legend(PackedStringArray())
	_take_problems(0)
	for i: int in lines.size():
		var entry: Dictionary = LevelText.parse_legend_line(lines[i])
		if _take_problems(numbers[i]) or entry.is_empty():
			continue
		var key: String = entry["char"]
		if legend_lines.has(key):
			issues.append({"line": numbers[i], "message": "legend character '%s' is defined twice" % key})
		legend[key] = entry
		legend_lines[key] = numbers[i]


func _parse_entities(lines: PackedStringArray, numbers: PackedInt32Array) -> void:
	for i: int in lines.size():
		var record: Dictionary = LevelText.parse_entity_line(lines[i])
		if _take_problems(numbers[i]) or record.is_empty():
			continue
		record["line"] = numbers[i]
		entities.append(record)


func _parse_backwalls(lines: PackedStringArray, numbers: PackedInt32Array) -> void:
	for i: int in lines.size():
		var tokens: PackedStringArray = lines[i].split(" ", false)
		if tokens.size() < 4 or not _all_ints(tokens, 4):
			issues.append({
				"line": numbers[i],
				"message": "malformed backwall line '%s' (expected: col row w h [set=a|b] [deco=0..100])" % lines[i],
			})
			continue
		var params: Dictionary = LevelText.parse_params(tokens, 4)
		_take_problems(numbers[i])
		var set_name: String = str(params.get("set", "a"))
		if set_name != "a" and set_name != "b":
			issues.append({"line": numbers[i], "message": "backwall set '%s' must be a or b" % set_name})
		backwalls.append({
			"rect": Rect2i(tokens[0].to_int(), tokens[1].to_int(), tokens[2].to_int(), tokens[3].to_int()),
			"set_b": set_name == "b",
			"deco": int(params.get("deco", 0)),
			"line": numbers[i],
		})


func _parse_overrides(lines: PackedStringArray, numbers: PackedInt32Array) -> void:
	for i: int in lines.size():
		var tokens: PackedStringArray = lines[i].split(" ", false)
		if tokens.size() < 4 or not _all_ints(tokens, 2) or not tokens[3].is_valid_int() \
				or (tokens[2] != "a" and tokens[2] != "b"):
			issues.append({
				"line": numbers[i],
				"message": "malformed override line '%s' (expected: col row a|b index [layer=back|main|front])"
						% lines[i],
			})
			continue
		var params: Dictionary = LevelText.parse_params(tokens, 4)
		_take_problems(numbers[i])
		overrides.append({
			"cell": Vector2i(tokens[0].to_int(), tokens[1].to_int()),
			"set_b": tokens[2] == "b",
			"index": tokens[3].to_int(),
			"layer": str(params.get("layer", "main")),
			"line": numbers[i],
		})


func _all_ints(tokens: PackedStringArray, count: int) -> bool:
	for i: int in count:
		if not tokens[i].is_valid_int():
			return false
	return true
