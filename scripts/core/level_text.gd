class_name LevelText
extends RefCounted
## Lexical layer of the level file format (docs/ARCHITECTURE.md 7): sections, `key = value` lines, legend and
## entity lines, value typing.
##
## CONTRACT FILE. Owner: core. This is the single implementation of how level text is split and typed; the level
## registry, the world loader, the level validator and the debug level all go through it, so level designers and
## engineers cannot disagree about syntax. It knows nothing about what entities or tiles mean.
## Level format 2 (2.0, ARCHITECTURE.md 7.11) has exactly the syntax of format 1: new [meta] keys, one new tile
## character and new entity ids, no new rule here except that `coop_base_hash` stays a String (STRING_KEYS).

## Sections whose lines are kept verbatim (every character is a tile; no comments, no trimming).
const RAW_SECTIONS: Array[String] = ["tiles"]
## Characters a [legend] line may define: letters, plus the three shortcut characters that have built-in defaults.
const LEGEND_KEYS: String = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz?*$"
## [meta] keys whose values always stay Strings (besides every key starting with "password"): format 2's
## `coop_base_hash`, a sha256 in hex that must never be read as a number.
const STRING_KEYS: Array[String] = ["coop_base_hash"]
## Every problem reported since the last clear_problems() (the level validator prints them with file names).
static var problems: PackedStringArray = PackedStringArray()
## When true problems are only collected, not sent to push_error (validator runs, error-path tests).
static var quiet: bool = false

# --- Level format 2 (2.0, docs/expansion/DESIGN.md appendix, ARCHITECTURE.md 7.11): facts every reader shares -----
## `format` of the 1.0 files.
const FORMAT_1: int = 1
## `format` of the 2.0 files: format 1 plus the [meta] keys, the tar floor ':' and the entity ids of 7.11.
const FORMAT_2: int = 2
## Every format this build reads (a format-1 file loads exactly as in 1.0).
const FORMATS: Array[int] = [FORMAT_1, FORMAT_2]
## Meta `book`: 1 = Book I "The First Feast" (the default: every 1.0 file), 2 = Book II "The Far Shore".
const BOOK_1: int = 1
const BOOK_2: int = 2
const BOOKS: Array[int] = [BOOK_1, BOOK_2]
## Meta `belt` (PHYSICS.md C.2): `fresh` = every stage starts with the club in hand and a special on the belt;
## `carry` = the 1.0 rule (one weapon, carried and replaced on pick-up; Swap ignored).
const BELT_FRESH: String = "fresh"
const BELT_CARRY: String = "carry"
const BELTS: Array[String] = [BELT_FRESH, BELT_CARRY]
## Meta `kind` values added by format 2 (the 1.0 kinds are the KIND_* constants of the `Levels` registry):
## `coop` = the co-op version of the solo level named by `coop_of`; `arena` = a versus arena. Neither ever appears in
## a solo registry query.
const KIND_COOP: String = "coop"
const KIND_ARENA: String = "arena"
## The [meta] keys format 2 adds (each may take a `.beginner` / `.expert` variant like every key).
const META_KEYS_2: Array[String] = [
	"book", "belt", "coop_of", "coop_base_hash", "players", "round_time", "modes", "wrap", "sudden", "rise_speed",
	"wind_loop",
]

## Built-in legend entries (a level may override them by defining the same character in [legend]).
const DEFAULT_LEGEND: Dictionary = {
	"?": "objects/hidden_spot kind=small count=3 tile=#",
	"*": "objects/hidden_spot kind=big hits=3 tile=#",
	"$": "objects/breakable_block hits=2 tile=;",
}


## Forget the collected problems.
static func clear_problems() -> void:
	problems = PackedStringArray()


static func _problem(message: String) -> void:
	problems.append(message)
	if not quiet:
		push_error(message)


## Split the text of a level file into sections: { "meta": PackedStringArray, "tiles": PackedStringArray, ... }.
## Outside raw sections blank lines and comment lines (first non-blank character '#') are dropped and lines are
## trimmed. Inside raw sections only a trailing carriage return is removed and completely empty lines are dropped.
## A section that appears twice is concatenated.
static func split_sections(text: String) -> Dictionary:
	var sections: Dictionary = {}
	var current: String = ""
	var raw: bool = false
	for source_line: String in text.split("\n"):
		var line: String = source_line.trim_suffix("\r")
		var stripped: String = line.strip_edges()
		var header: String = section_name(stripped)
		if header != "":
			current = header
			raw = RAW_SECTIONS.has(current)
			if not sections.has(current):
				sections[current] = PackedStringArray()
			continue
		if current == "":
			continue
		var lines: PackedStringArray = sections[current]
		if raw:
			if line != "":
				lines.append(line)
		elif stripped != "" and not stripped.begins_with("#"):
			lines.append(stripped)
		sections[current] = lines
	return sections


## Name of a section header line "[name]" (lower-case letters, digits, underscore), or "" when it is not one.
static func section_name(stripped_line: String) -> String:
	if stripped_line.length() < 3 or not stripped_line.begins_with("[") or not stripped_line.ends_with("]"):
		return ""
	var inner: String = stripped_line.substr(1, stripped_line.length() - 2)
	for i: int in inner.length():
		var c: String = inner[i]
		if not ((c >= "a" and c <= "z") or (c >= "0" and c <= "9") or c == "_"):
			return ""
	return inner


## Convert the text of a value to a typed Variant:
## `true` / `false` -> bool; integers without leading zeros -> int; decimals with a point and no exponent ->
## float; "quoted" -> String without the quotes; anything else -> the trimmed String (lists such as `3,4,10,2`
## stay Strings; split them with to_list / to_int_list / to_rect).
static func parse_value(text: String) -> Variant:
	var value: String = text.strip_edges()
	if value.length() >= 2 and value.begins_with("\"") and value.ends_with("\""):
		return value.substr(1, value.length() - 2)
	if value == "true":
		return true
	if value == "false":
		return false
	if value.is_valid_int():
		var digits: String = value.trim_prefix("-").trim_prefix("+")
		if digits.length() == 1 or not digits.begins_with("0"):
			return value.to_int()
		return value
	if value.is_valid_float() and value.contains(".") and not value.to_lower().contains("e"):
		return value.to_float()
	return value


## Parse `key = value` lines (already split by split_sections) into a Dictionary. Keys starting with
## "password" and the keys of STRING_KEYS always stay Strings.
static func parse_key_values(lines: PackedStringArray) -> Dictionary:
	var result: Dictionary = {}
	for line: String in lines:
		var eq: int = line.find("=")
		if eq <= 0:
			_problem("LevelText: malformed line '%s' (expected key = value)" % line)
			continue
		var key: String = line.substr(0, eq).strip_edges()
		var value_text: String = line.substr(eq + 1).strip_edges()
		if key.begins_with("password") or STRING_KEYS.has(key.get_slice(".", 0)):
			result[key] = value_text.trim_prefix("\"").trim_suffix("\"")
		else:
			result[key] = parse_value(value_text)
	return result


## The [meta] section of a level file as a Dictionary ({} when the file has none).
static func parse_meta(text: String) -> Dictionary:
	var sections: Dictionary = split_sections(text)
	if not sections.has("meta"):
		return {}
	return parse_key_values(sections["meta"])


## Parse whitespace-separated parameter tokens: `key=value` pairs and bare flags (`expert` -> true).
static func parse_params(tokens: PackedStringArray, first: int = 0) -> Dictionary:
	var params: Dictionary = {}
	for i: int in range(first, tokens.size()):
		var token: String = tokens[i]
		var eq: int = token.find("=")
		if eq < 0:
			params[token] = true
		elif eq > 0:
			params[token.substr(0, eq)] = parse_value(token.substr(eq + 1))
		else:
			_problem("LevelText: malformed parameter '%s'" % token)
	return params


## Parse one [legend] line `<char> = <entity id> [params]`.
## Returns { "char": String, "id": StringName, "params": Dictionary } or {} when malformed.
static func parse_legend_line(line: String) -> Dictionary:
	var eq: int = line.find("=")
	if eq <= 0:
		_problem("LevelText: malformed legend line '%s'" % line)
		return {}
	var key: String = line.substr(0, eq).strip_edges()
	if key.length() != 1 or not LEGEND_KEYS.contains(key):
		_problem("LevelText: legend key '%s' must be one letter or one of ? * $" % key)
		return {}
	var tokens: PackedStringArray = line.substr(eq + 1).strip_edges().split(" ", false)
	if tokens.is_empty():
		_problem("LevelText: legend line '%s' has no entity id" % line)
		return {}
	return {"char": key, "id": StringName(tokens[0]), "params": parse_params(tokens, 1)}


## The complete legend of a level: built-in defaults overridden by the [legend] lines.
## Returns { char: { "char", "id", "params" } }.
static func parse_legend(lines: PackedStringArray) -> Dictionary:
	var legend: Dictionary = {}
	for key: String in DEFAULT_LEGEND:
		legend[key] = parse_legend_line("%s = %s" % [key, DEFAULT_LEGEND[key]])
	for line: String in lines:
		var entry: Dictionary = parse_legend_line(line)
		if not entry.is_empty():
			legend[entry["char"]] = entry
	return legend


## Map of legend character -> tile character for TileGrid.from_rows (the `tile=` parameter of each entry).
static func legend_tiles(legend: Dictionary) -> Dictionary:
	var tiles: Dictionary = {}
	for key: String in legend:
		var params: Dictionary = legend[key]["params"]
		if params.has("tile"):
			tiles[key] = str(params["tile"])
	return tiles


## Parse one [entities] line `<entity id> <col> <row> [params]` (col / row may be decimals).
## Returns { "id": StringName, "col": float, "row": float, "params": Dictionary } or {} when malformed.
static func parse_entity_line(line: String) -> Dictionary:
	var tokens: PackedStringArray = line.split(" ", false)
	if tokens.size() < 3 or not tokens[1].is_valid_float() or not tokens[2].is_valid_float():
		_problem("LevelText: malformed entity line '%s' (expected: id col row [params])" % line)
		return {}
	return {
		"id": StringName(tokens[0]),
		"col": tokens[1].to_float(),
		"row": tokens[2].to_float(),
		"params": parse_params(tokens, 3),
	}


## Feet point (logical px) of an entity placed in cell (col, row): bottom-centre of the cell, plus the optional
## `dx` / `dy` parameters. Decimals shift by fractions of a tile.
static func cell_to_feet(col: float, row: float, params: Dictionary = {}) -> Vector2i:
	return Vector2i(
		roundi(col * Tuning.TILE) + Tuning.TILE / 2 + int(params.get("dx", 0)),
		roundi(row * Tuning.TILE) + Tuning.TILE + int(params.get("dy", 0))
	)


## True when a legend entry / entity line applies in the given difficulty (flags `expert` / `beginner`).
static func applies_to(params: Dictionary, difficulty: int) -> bool:
	if params.has("expert") and bool(params["expert"]) and difficulty != Defs.Difficulty.EXPERT:
		return false
	if params.has("beginner") and bool(params["beginner"]) and difficulty != Defs.Difficulty.BEGINNER:
		return false
	return true


## The `belt` rule of a level that does not set the key (PHYSICS.md C.2, LEVEL_DESIGN.md 15.2): BELT_FRESH for
## book 2 and for every co-op file, else BELT_CARRY (so every 1.0 file keeps the 1.0 weapon rule).
static func default_belt(book: int, kind: String) -> String:
	return BELT_FRESH if book == BOOK_2 or kind == KIND_COOP else BELT_CARRY


## The book of a parsed [meta] section (`book`, default BOOK_1).
static func meta_book(meta: Dictionary) -> int:
	return int(meta.get("book", BOOK_1))


## The belt rule of a parsed [meta] section for a difficulty (-1 = none): `belt` with its difficulty variant, else
## [method default_belt] of its book and kind.
static func meta_belt(meta: Dictionary, difficulty: int = -1) -> String:
	if difficulty >= 0:
		var variant_key: String = "belt.%s" % Defs.difficulty_name(difficulty)
		if meta.has(variant_key):
			return str(meta[variant_key])
	if meta.has("belt"):
		return str(meta["belt"])
	return default_belt(meta_book(meta), str(meta.get("kind", "main")))


## Split a list value `a,b,c` into Strings (a single value yields one element; "" yields none).
static func to_list(value: Variant) -> PackedStringArray:
	var text: String = str(value).strip_edges()
	if text.is_empty():
		return PackedStringArray()
	return text.split(",", false)


## Split a list value `1,2,3` into ints.
static func to_int_list(value: Variant) -> PackedInt32Array:
	var result: PackedInt32Array = PackedInt32Array()
	for part: String in to_list(value):
		result.append(part.strip_edges().to_int())
	return result


## Convert `col,row,w,h` (tiles) into a rectangle in logical px. Returns an empty Rect2i when malformed.
static func to_rect_px(value: Variant) -> Rect2i:
	var parts: PackedInt32Array = to_int_list(value)
	if parts.size() != 4:
		_problem("LevelText: '%s' is not a col,row,w,h rectangle" % str(value))
		return Rect2i()
	return Rect2i(parts[0] * Tuning.TILE, parts[1] * Tuning.TILE, parts[2] * Tuning.TILE, parts[3] * Tuning.TILE)
