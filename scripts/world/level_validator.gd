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
## Level format 2 (2.0, ARCHITECTURE.md 7.11): the format-level rules - `format` 1 or 2, the new [meta] keys and
## their values, the keys a co-op file / an arena needs, the tar floor ':', the catalogue rows of the new ids.
## Content rules of the co-op and versus files (world-B, PLAN.md P1.7; LEVEL_DESIGN.md 15.7 / 15.8, DESIGN.md D.5-D.8,
## E.5; [method _check_content]): traits and co-op-only enemies only in co-op files, the `coop_base_hash` drift
## warning, x2 tablets (`gate=` / `far=` / `secret`, one per gate name, every co-op mechanism inside a gate), plates
## (name, `mode=hold|latch|timed:<ticks>`, 8+ tiles from their door, every `rise_while` / `sink_while` name a plate),
## keeper / drum / bond pairing, the trait share, keeper and Guard halls exactly 4 rows high, the gate count per
## stage kind, the static solo-impossibility rules around boost ledges, and the arena checks (size, the HUD row,
## spawns, cookpots, Clubball goals, forbidden objects, wrap seams, spots, gaps).

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
## Parameters every enemy and boss accepts. Format 2 (2.0): `coop=<trait>`, `bond=<name>`, `keeper=<name>` and
## `perch=c,r` (the trait rules of DESIGN.md D.6; "traits only in co-op files" is a world-B rule of phase 1).
const ENEMY_PARAMS: Array[String] = ["skin", "hp", "score", "coop", "bond", "keeper", "perch", "window"]
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
	"items/trophy": ["skin"],
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
	"objects/spring": ["power", "skin"],
	"objects/sign": ["text"],
	"objects/npc": ["kind", "turn"],
	"objects/hero_start": ["slot"],
	"zones/secret": ["rect"],
	"zones/arena": ["rect", "music"],
	"zones/camera_lock": ["rect"],
	"zones/dark": ["rect", "on"],
	"zones/kill": ["rect"],
	"zones/autoscroll_stop": ["rect"],
	"zones/message": ["rect", "text"],
	"zones/ember_rain": ["rect", "period", "skin"],
	"zones/flies": ["rect", "count"],
	# --- Level format 2 (2.0, ARCHITECTURE.md 6.2 / 7.11; DESIGN.md appendix, LEVEL_DESIGN.md 15.4) ---------------
	"enemies/roller": ["range", "speed", "dizzy", "left", "right"],
	"enemies/guard": ["turn", "left", "right", "speed"],
	"enemies/mimic": ["contents", "range"],
	"enemies/shellback": ["turn", "left", "right", "speed"],
	"enemies/raptor": ["range", "pause", "jump_x", "jump_y"],
	"enemies/snatcher": ["kind", "depth", "speed", "range"],
	"enemies/leech": ["range", "pause"],
	"enemies/bull_rex": ["speed"],
	"enemies/tar_splitter": ["left", "right", "speed"],
	"enemies/shaman": ["left", "right", "speed"],
	"bosses/tusker": ["arena", "drops"],
	"bosses/mangrove": ["arena", "drops"],
	"bosses/squid": ["arena", "drops"],
	"bosses/idols": ["arena", "drops"],
	"bosses/roc": ["arena", "drops"],
	"bosses/chieftain": ["arena", "mate", "drops"],
	"items/painting": ["index"],
	"objects/vine": ["length", "rolled"],
	"objects/bark_board": ["face"],
	"objects/geyser": ["period", "delay", "power", "skin", "deadly"],
	"objects/raft": ["width", "skin", "rails"],
	"objects/mount": ["kind", "pen", "wild"],
	"objects/rex_pen": [],
	"objects/plate": ["count", "mode", "w"],
	"objects/drum": ["bond", "skin"],
	"objects/seesaw": ["len", "skin"],
	"objects/boulder_heavy": [],
	"objects/pulley": ["a", "b", "range"],
	"objects/flower_pot": [],
	"objects/x2_tablet": ["gate", "far", "secret"],
	"objects/spawn_point": ["index"],
	"objects/cookpot": ["team"],
	"objects/coconut": [],
	"objects/crate_lane": ["rect"],
	"zones/current": ["rect", "dir", "speed"],
	"zones/lightning": ["rect", "period", "delay", "mark"],
	"zones/food_rain": ["rect", "period", "skin"],
	"zones/goal": ["rect", "team"],
}
## The sign board (objects-A) and the ui kit whose wrap measures a sign's lines (loaded by path: tools may run without).
const SIGN_SCRIPT: String = "res://scripts/objects/sign_board.gd"
const UI_KIT_SCRIPT: String = "res://scripts/ui/ui_kit.gd"
const SIGN_MAX_LINES: int = 3
## zones/lightning defaults (world-A's LightningZone.DEFAULT_PERIOD / mark / BOLT_TICKS; mirrored, the zone is
## world-A's file): a period under mark + bolt makes the strikes overlap (a warning).
const LIGHTNING_DEFAULT_PERIOD: int = 66
const LIGHTNING_DEFAULT_MARK: int = 22
const LIGHTNING_BOLT_TICKS: int = 4
## Format 2 parameters of 1.0 ids (merged into CATALOGUE by [method _catalogue_params]): the column's plate and
## trigger rules, the gate's drum lock, the versus weapon pick-up.
const CATALOGUE_2: Dictionary = {
	"objects/column": ["rise_while", "sink_while"],
	"objects/gate": ["needs"],
	"items/weapon": ["temp"],
}
## `trigger` values of a column that name a group instead of a rectangle (format 2, LEVEL_DESIGN.md 15.4):
## `keepers:<name>` (every enemy tagged `keeper=<name>` dead) and `drums:<bond>` (that drum bond struck in time).
const TRIGGER_GROUPS: Array[String] = ["keepers:", "drums:"]
## Parameters of scenery props.
const PROP_PARAMS: Array[String] = ["layer", "flip"]
## Enumerated parameter values: "id:param" -> allowed values.
const CHOICES: Dictionary = {
	"*:facing": ["l", "r", "left", "right"],
	"objects/exit:kind": ["exit", "warp", "trophy"],
	"objects/hidden_spot:kind": ["small", "big"],
	"objects/hidden_spot:look": ["plain", "inset", "block"],
	"objects/breakable_block:skin": ["auto", "dirt", "cave", "ice", "obsidian"],
	"objects/container:skin": ["barrel", "crate", "pot", "chest"],
	"objects/platform:mode": ["always", "ride"],
	"objects/platform:skin": ["wood", "ice", "stone", "small", "cloud", "driftwood"],
	"objects/drop_platform:skin": ["wood", "ice", "stone", "small", "cloud", "driftwood"],
	"objects/gate:skin": ["arch", "hole", "none"],
	"objects/npc:kind": ["elder", "kid", "warrior"],
	"items/weapon:kind": ["club", "hammer", "axe", "boomerang", "spear"],
	"props:layer": ["back", "front"],
	"zones/ember_rain:skin": ["ember", "leaf"],
	"zones/food_rain:skin": ["food", "fruit"],
	"enemies/snatcher:kind": ["dangler", "stinger"],
	"*:coop": ["shell", "bond", "daze", "heavy", "lone", "grab", "leech", "split"],
	"objects/bark_board:face": ["l", "r"],
	"objects/geyser:skin": ["mud", "blowhole", "steam", "soda"],
	"objects/raft:skin": ["log", "wafer"],
	"objects/mount:kind": ["rex"],
	"zones/current:dir": ["l", "r", "u", "d"],
	"objects/seesaw:skin": ["wood", "mushroom", "floe"],
	"objects/spring:skin": ["flower", "cap"],
	"objects/drum:skin": ["drum", "cap"],
	"items/trophy:skin": ["cup", "roast"],
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
	"*:window": Vector2i(0, 9999),
	"zones/ember_rain:period": Vector2i(1, 9999),
	"zones/flies:count": Vector2i(1, 20),
	"objects/hero_start:slot": Vector2i(2, Defs.MAX_PLAYERS),
	"items/painting:index": Vector2i(0, Tuning.PAINTING_COUNT - 1),
	"objects/spawn_point:index": Vector2i(2, Defs.MAX_PLAYERS),
	"objects/vine:length": Vector2i(1, Tuning.MAP_MAX_ROWS),
	"objects/geyser:period": Vector2i(34, 9999),
	"objects/geyser:delay": Vector2i(0, 9999),
	"objects/raft:width": Vector2i(3, 4),
	"objects/plate:count": Vector2i(1, 2),
	"objects/plate:w": Vector2i(1, 16),
	"objects/seesaw:len": Vector2i(2, 32),
	"objects/pulley:range": Vector2i(1, Tuning.MAP_MAX_ROWS),
	"zones/current:speed": Vector2i(1, 3),
	"zones/lightning:period": Vector2i(1, 9999),
	"zones/lightning:delay": Vector2i(0, 9999),
	"zones/lightning:mark": Vector2i(1, 9999),
	"zones/food_rain:period": Vector2i(1, 9999),
	"zones/goal:team": Vector2i(1, 2),
	"objects/cookpot:team": Vector2i(1, 2),
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
	"painting": Vector2i(0, Tuning.PAINTING_COUNT - 1),
}
## Entities whose anchor cell is meant to be solid (they ARE the tile, or live inside a wall).
const SOLID_ANCHOR_IDS: Array[String] = [
	"objects/hidden_spot", "objects/breakable_block", "objects/column", "bosses/colossus",
]
## Entities that must stand on a floor.
const GROUNDED_IDS: Array[String] = ["objects/exit", "objects/checkpoint", "objects/hero_start"]
## Markers the level loader reads itself and never spawns (no scene): the start of player 2..4 (`slot=2..4`; 2.0,
## TECH_AUDIT.md 3.3 / 4.10; read by Level._place_party_starts, ignored in single-player).
const LOADER_MARKER_IDS: Array[String] = ["objects/hero_start"]
## Default `drops` of the bosses (ARCHITECTURE.md 6.2).
const BOSS_DROPS: Dictionary = {"bosses/brute": "fire_starter", "bosses/colossus": "trophy,trophy,trophy,trophy"}
const PASSWORD_CHARS: String = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"

# --- Content rules of co-op files and arenas (world-B, PLAN.md P1.7) -----------------------------------------------
## Keeper and Guard halls are exactly this many rows of air under a ceiling: 4 (64 px; the orchestrator's resolution
## of PLAN P1 - the Guard and Shellback art is 54 px tall - replacing the 3 of LEVEL_DESIGN.md 15.7.5).
const HALL_ROWS: int = PartyTuning.KEEPER_HALL_ROWS
## The level kinds that may carry traits and co-op objects: co-op files, and developer levels that test them.
const TRAIT_KINDS: Array[String] = ["coop", "test"]
## The kinds of a solo campaign (no co-op objects there).
const SOLO_KINDS: Array[String] = ["main", "sub", "bonus", "ending"]
## Enemy parameters that are co-op traits (DESIGN.md D.6, R10).
## `window=<ticks>` caps a bond / split window or a daze (LEVEL_DESIGN.md 15.7.6, CoopTraits.capped_window).
const TRAIT_PARAMS: Array[String] = ["coop", "bond", "keeper", "perch", "window"]
## Co-op-only enemies (DESIGN.md D.7): presets of an archetype and a trait.
const COOP_ONLY_ENEMIES: Array[String] = [
	"enemies/shellback", "enemies/raptor", "enemies/snatcher", "enemies/leech", "enemies/bull_rex",
	"enemies/tar_splitter", "enemies/shaman",
]
## Enemies that patrol a hall with a shield (their hall is a keeper hall): the Guard and its co-op preset.
const GUARD_IDS: Array[String] = ["enemies/guard", "enemies/shellback"]
## Co-op objects (DESIGN.md D.5) other than columns: never in a solo campaign file.
const COOP_OBJECTS: Array[String] = [
	"objects/plate", "objects/drum", "objects/boulder_heavy", "objects/pulley", "objects/flower_pot",
	"objects/x2_tablet", "objects/hero_start",
]
## Co-op mechanisms that must lie inside some x2 tablet's gate (LEVEL_DESIGN.md 15.7.4), besides the driven columns.
const GATE_MECHANISMS: Array[String] = [
	"objects/plate", "objects/drum", "objects/boulder_heavy", "objects/pulley", "objects/seesaw",
]
## A gate's area: the rectangle of its tablet and its far cell, grown by one view (20 x 11 cells, LEVEL_DESIGN.md
## 15.7.7: keep each gate inside one view).
const GATE_AREA_COLS: int = Tuning.VIEW_COLS
const GATE_AREA_ROWS: int = Tuning.VIEW_ROWS
## A tablet whose far cell lies this many rows or more above it marks a height gate (boost, Totem or lob ledge).
const HEIGHT_GATE_ROWS: int = 4
## The static reach around a ledge gate's top (LEVEL_DESIGN.md 15.7.6, R25): 10 cells across, 11 rows below.
const REACH_COLS: int = 10
const REACH_ROWS: int = 11
## No bark board within this many cells of any gate (a spear step would climb it).
const BARK_GATE_CELLS: int = 12
## Things a single hero could climb on near a ledge gate (enemies are checked by category).
const BOOSTERS: Array[String] = [
	"objects/spring", "objects/geyser", "objects/vine", "objects/bark_board", "items/glider", "objects/platform",
	"objects/drop_platform", "objects/mount", "objects/rex_pen",
]
## Hittables (a column of two or more is a club pogo ladder).
const HITTABLE_IDS: Array[String] = ["objects/hidden_spot", "objects/breakable_block", "objects/container"]
## Ids an arena never holds (LEVEL_DESIGN.md 15.8: no exit, no checkpoint, no co-op objects but see-saws and pulleys).
const ARENA_FORBIDDEN: Array[String] = [
	"objects/exit", "objects/checkpoint", "objects/gate", "items/warp", "objects/plate", "objects/drum",
	"objects/boulder_heavy", "objects/flower_pot", "objects/x2_tablet", "objects/hero_start",
]
## Plate modes (DESIGN.md D.5): `hold`, `latch`, `timed:<ticks>`.
const PLATE_MODES: Array[String] = ["hold", "latch"]
const PLATE_TIMED: String = "timed:"

## Every problem found by [method run]: { "path": String, "line": int, "severity": ERROR / WARNING,
## "message": String }, in file order.
var problems: Array[Dictionary] = []
## Level ids that count as existing for `next` / `bonus` besides the levels added (tests).
var known_ids: PackedStringArray = PackedStringArray()

var _levels: Array[LevelData] = []
var _all_ids: Dictionary = {}
## Level id -> the text of a level added by [method add_text] (the drift check hashes it like a file).
var _texts: Dictionary = {}
## Level id -> its LevelData (every level added).
var _by_id: Dictionary = {}


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


## Add a level parsed already (the solo search checks one file's static rules this way).
func add_data(data: LevelData) -> void:
	if data != null:
		_levels.append(data)


## Add a level from text (tests); `path` is what the messages show.
func add_text(level_id: StringName, text: String, path: String = "") -> void:
	_levels.append(LevelData.parse(level_id, text, path if path != "" else "%s.lvl" % level_id))
	_texts[String(level_id)] = text


## Validate everything added. Levels reference each other (next, bonus, unique passwords), so all of them are
## checked together.
func run() -> void:
	_all_ids.clear()
	for id: String in known_ids:
		_all_ids[id] = true
	for data: LevelData in _levels:
		_all_ids[String(data.id)] = true
		_by_id[String(data.id)] = data
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
	_check_content(data, grid)
	_check_visual_sections(data)


func _check_meta(data: LevelData) -> void:
	var path: String = data.path
	if not data.meta.has("format"):
		_add(path, _meta_line(data, ""), ERROR, "meta key 'format' is required")
	elif not data.meta["format"] is int or not LevelText.FORMATS.has(int(data.meta["format"])):
		_add(path, _meta_line(data, "format"), ERROR, "format must be 1 or 2 (found %s)" % str(data.meta["format"]))
	_check_format_2(data)
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
		# --- format 2 (ARCHITECTURE.md 7.11) ---
		"book":
			if not value is int or not LevelText.BOOKS.has(int(value)):
				_add(path, line, ERROR, "%s = %s must be 1 or 2" % [key, text])
		"belt":
			_check_choice(path, line, key, text, LevelText.BELTS)
		"coop_of":
			if text == "" or not _all_ids.has(text):
				_add(path, line, ERROR, "%s '%s' is not a level" % [key, text])
			elif text == String(data.id):
				_add(path, line, ERROR, "%s '%s' names the file itself" % [key, text])
		"coop_base_hash":
			if not _is_sha256(text):
				_add(path, line, ERROR, "%s must be the sha256 of the solo file (64 hex digits)" % key)
		"players":
			_check_int(path, line, key, value, 2, Defs.MAX_PLAYERS)
		"round_time":
			_check_int(path, line, key, value, 1, 99999)
		"modes":
			var modes: PackedStringArray = LevelText.to_list(value)
			if modes.is_empty():
				_add(path, line, ERROR, "modes lists no versus mode")
			var known: Array = []
			for mode_name: StringName in Defs.VERSUS_MODE_NAMES:
				known.append(String(mode_name))
			for mode: String in modes:
				_check_choice(path, line, key, mode, known)
		"wrap":
			_check_choice(path, line, key, text, LevelData.WRAPS)
		"sudden":
			_check_choice(path, line, key, text, LevelData.SUDDEN_DEATHS)
		"rise_speed":
			_check_int(path, line, key, value, 1, PartyTuning.LAUNCH_AXIS_CAP)
		"wind_loop":
			_check_int(path, line, key, value, 0, 99999)
		"id", "name", "format", "author", "notes":
			pass


## Format-2 rules of the header (ARCHITECTURE.md 7.11): a co-op file names its solo level and that file's hash, an
## arena its players and modes; format-2 keys and the tar floor ':' in a format-1 file are reported (LEVEL_DESIGN.md
## 15.1: new files are format 2).
func _check_format_2(data: LevelData) -> void:
	var path: String = data.path
	var kind: String = str(data.value("kind"))
	if kind == LevelText.KIND_COOP:
		for key: String in ["coop_of", "coop_base_hash"]:
			if not data.meta.has(key):
				_add(path, _meta_line(data, ""), ERROR, "a co-op file (kind = coop) needs meta key '%s'" % key)
	elif kind == LevelText.KIND_ARENA:
		for key: String in ["players", "modes"]:
			if not data.meta.has(key):
				_add(path, _meta_line(data, ""), ERROR, "an arena (kind = arena) needs meta key '%s'" % key)
	if int(data.meta.get("format", LevelText.FORMAT_2)) != LevelText.FORMAT_1:
		return
	for key: String in data.meta:
		if LevelText.META_KEYS_2.has(key.get_slice(".", 0)):
			_add(path, _meta_line(data, key), WARNING, "'%s' is a format 2 key: set format = 2" % key)
	for row: int in data.row_count():
		if data.rows[row].contains(TileGrid.CH_TAR):
			_add(path, data.row_lines[row], WARNING, "the tar floor ':' is format 2: set format = 2")
			return


static func _is_sha256(text: String) -> bool:
	if text.length() != 64:
		return false
	for i: int in text.length():
		if not "0123456789abcdefABCDEF".contains(text[i]):
			return false
	return true


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
		_check_hero_starts(data, records, difficulty)
	_check_exit_path(data, records)


## At most one `objects/hero_start` per player slot in each difficulty (the loader would take the last one).
func _check_hero_starts(data: LevelData, records: Array[Dictionary], difficulty: int) -> void:
	var seen: Dictionary = {}
	for record: Dictionary in records:
		if String(record["id"]) != "objects/hero_start" or not LevelText.applies_to(record["params"], difficulty):
			continue
		var slot: Variant = record["params"].get("slot")
		if not slot is int:
			continue
		if seen.has(slot):
			_add(data.path, int(record["line"]), ERROR, "objects/hero_start slot=%d is placed more than once in %s" % [
				int(slot), Defs.difficulty_name(difficulty)])
		seen[slot] = true


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
	if not Spawner.exists(StringName(id)) and not LOADER_MARKER_IDS.has(id):
		_add(path, line, WARNING, "no scene for '%s' yet (%s)" % [id, Spawner.scene_path(StringName(id))])
	if id == "objects/hero_start" and not params.has("slot"):
		_add(path, line, ERROR, "objects/hero_start needs slot=2..%d (its player number)" % Defs.MAX_PLAYERS)
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
	if id == "items/warp" and _stage_kind(data) != "bonus" and str(data.value("bonus")) == "":
		_add(path, line, WARNING, "items/warp in a level without a 'bonus' stage acts as a plain exit")
	for key: String in ["contents", "drops"]:
		if params.has(key):
			_check_contents(path, line, key, str(params[key]))
	for key: String in RECT_PARAMS:
		if params.has(key) and not (key == "trigger" and _is_trigger_group(str(params[key]))):
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
	if id == "objects/sign" and params.has("text"):
		_check_sign_text(path, line, str(params["text"]))
	if id == "zones/lightning":
		_check_lightning(path, line, params)


## A lightning zone whose period is shorter than its mark plus the bolt (LightningZone: period 66, mark 22 by default,
## bolt 4 ticks) strikes again while the last bolt still burns or its mark still shows: legal, but a WARNING.
func _check_lightning(path: String, line: int, params: Dictionary) -> void:
	var period_text: String = str(params.get("period", LIGHTNING_DEFAULT_PERIOD))
	var mark_text: String = str(params.get("mark", LIGHTNING_DEFAULT_MARK))
	if not period_text.is_valid_int() or not mark_text.is_valid_int():
		return  # the range check reports it
	var period: int = period_text.to_int()
	var mark: int = mark_text.to_int()
	if period < mark + LIGHTNING_BOLT_TICKS:
		_add(path, line, WARNING, "zones/lightning period %d is shorter than its mark %d + the %d-tick bolt: %s"
				% [period, mark, LIGHTNING_BOLT_TICKS, "the strikes overlap"])


## A sign's text must fit its board: at most SignBoard.MAX_LINES lines as the board wraps it (objects-A's
## SignBoard.text_lines on the translated text; about 60 characters). A WARNING. Skipped where the sign or the ui kit
## cannot be loaded (tools that run without them).
func _check_sign_text(path: String, line: int, key: String) -> void:
	if not ResourceLoader.exists(SIGN_SCRIPT) or not ResourceLoader.exists(UI_KIT_SCRIPT):
		return
	var sign_board: Script = load(SIGN_SCRIPT) as Script
	var ui_kit: Script = load(UI_KIT_SCRIPT) as Script
	if sign_board == null or ui_kit == null or not sign_board.has_script_method(&"text_lines"):
		return
	if ui_kit.has_script_method(&"ensure_locale"):
		ui_kit.call(&"ensure_locale")
	var lines: int = int(sign_board.call(&"text_lines", TranslationServer.translate(key)))
	var limit: int = SIGN_MAX_LINES
	var constants: Dictionary = sign_board.get_script_constant_map()
	if constants.get("MAX_LINES") is int:
		limit = int(constants["MAX_LINES"])
	if lines > limit:
		_add(path, line, WARNING, "sign text '%s' takes %d board lines (at most %d, about 60 characters): shorten it"
				% [key, lines, limit])


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
	allowed.append_array(CATALOGUE_2.get(id, []))
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
				_add(path, line, ERROR, "%s token '%s': weapon kind must be %s" % [
					key, token, ", ".join(PackedStringArray(CHOICES["items/weapon:kind"]))])
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
		var kind: String = _stage_kind(data)
		if kind == LevelText.KIND_ARENA:
			pass  # a versus arena has no way out (LEVEL_DESIGN.md 15.8)
		elif kind == "bonus":
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
# Content rules of co-op files and arenas (world-B, PLAN.md P1.7)
# =================================================================================================================

func _check_content(data: LevelData, grid: TileGrid) -> void:
	var kind: String = str(data.value("kind"))
	var records: Array[Dictionary] = data.entity_records()
	_check_trait_places(data, kind, records)
	_check_plates(data, records)
	if kind == LevelText.KIND_COOP:
		_check_coop_hash(data)
		_check_pairings(data, records)
		# The co-op copy of a developer level (coop_of a kind = test file) is a test bed: no trait share.
		var campaign: bool = SOLO_KINDS.has(_solo_kind(str(data.value("coop_of"))))
		for difficulty: int in [Defs.Difficulty.BEGINNER, Defs.Difficulty.EXPERT]:
			var tablets: Array[Dictionary] = _check_tablets(data, grid, records, difficulty)
			_check_gate_mechanisms(data, records, tablets, difficulty)
			_check_gate_count(data, records, tablets, difficulty)
			if campaign:
				_check_trait_share(data, records, difficulty)
			_check_ledge_reach(data, records, tablets, difficulty)
		_check_halls(data, grid, records)
	elif kind == LevelText.KIND_ARENA:
		_check_arena(data, grid, records)


## Traits (`coop=`, `bond=`, `keeper=`, `perch=` on enemies) and the co-op-only enemies exist only in co-op files
## (DESIGN.md D.6 / D.7); developer levels may test them. Co-op objects in a solo campaign file are probably a copy
## mistake (a warning).
func _check_trait_places(data: LevelData, kind: String, records: Array[Dictionary]) -> void:
	if TRAIT_KINDS.has(kind):
		return
	for record: Dictionary in records:
		var id: String = String(record["id"])
		var category: String = Spawner.category(StringName(id))
		var line: int = int(record["line"])
		if category == "enemies" or category == "bosses":
			for key: String in TRAIT_PARAMS:
				if record["params"].has(key):
					_add(data.path, line, ERROR, "'%s' %s=: co-op traits exist only in co-op files (kind = coop)" % [
						id, key])
			if COOP_ONLY_ENEMIES.has(id):
				_add(data.path, line, ERROR, "'%s' is a co-op-only enemy: only in co-op files (kind = coop)" % id)
		elif COOP_OBJECTS.has(id) and SOLO_KINDS.has(kind):
			_add(data.path, line, WARNING, "'%s' is a co-op object in a solo file (it belongs in the _coop.lvl copy)" % id)


## Plates (DESIGN.md D.5): a name, `mode=hold|latch|timed:<ticks>`, at least PartyTuning.PLATE_DOOR_MIN_TILES from
## every door they drive; every `rise_while` / `sink_while` name is a plate. The name and the distance are content
## rules of co-op files (warnings in developer levels, which show plates and doors side by side).
func _check_plates(data: LevelData, records: Array[Dictionary]) -> void:
	var content: int = ERROR if str(data.value("kind")) == LevelText.KIND_COOP else WARNING
	var plates: Dictionary = {}       # name -> record
	for record: Dictionary in records:
		if String(record["id"]) != "objects/plate":
			continue
		var params: Dictionary = record["params"]
		var line: int = int(record["line"])
		if not params.has("name"):
			_add(data.path, line, content, "objects/plate needs a name (columns name it in rise_while= / sink_while=)")
		else:
			plates[str(params["name"])] = record
		if params.has("mode") and not is_plate_mode(str(params["mode"])):
			_add(data.path, line, ERROR, "objects/plate mode '%s' must be hold, latch or timed:<ticks> (ticks >= 1)" % str(
				params["mode"]))
	var driven: Dictionary = {}
	for record: Dictionary in records:
		if String(record["id"]) != "objects/column":
			continue
		var params: Dictionary = record["params"]
		for key: String in ["rise_while", "sink_while"]:
			if not params.has(key):
				continue
			for plate_name: String in LevelText.to_list(params[key]):
				var name_key: String = plate_name.strip_edges()
				driven[name_key] = true
				if not plates.has(name_key):
					_add(data.path, int(record["line"]), ERROR, "column %s '%s' is not the name of an objects/plate" % [
						key, name_key])
					continue
				var gap: int = _cell_gap(_plate_cells(plates[name_key]), _column_cells(record))
				if gap < PartyTuning.PLATE_DOOR_MIN_TILES:
					_add(data.path, int(plates[name_key]["line"]), content,
							"plate '%s' is %d tiles from its door (the column at line %d); at least %d" % [
							name_key, gap, int(record["line"]), PartyTuning.PLATE_DOOR_MIN_TILES])
	for plate_name: String in plates:
		if not driven.has(plate_name):
			_add(data.path, int(plates[plate_name]["line"]), WARNING,
					"plate '%s' drives no column (rise_while= / sink_while=)" % plate_name)


## True for a valid `objects/plate mode=` value: `hold`, `latch` or `timed:<ticks>` with ticks >= 1.
static func is_plate_mode(text: String) -> bool:
	if PLATE_MODES.has(text):
		return true
	if not text.begins_with(PLATE_TIMED):
		return false
	var ticks: String = text.substr(PLATE_TIMED.length())
	return ticks.is_valid_int() and ticks.to_int() >= 1


## The `coop_base_hash` drift warning (DESIGN.md D.9): the solo file `coop_of` must still hash to the value the co-op
## copy was made from (sha256 of the file, its text with CRLF read as LF also accepted).
func _check_coop_hash(data: LevelData) -> void:
	var base_id: String = str(data.value("coop_of"))
	var expected: String = str(data.value("coop_base_hash")).to_lower()
	if base_id == "" or not _is_sha256(expected):
		return
	var text: String = ""
	if _texts.has(base_id):
		text = str(_texts[base_id])
	else:
		var path: String = "res://levels/%s.lvl" % base_id
		if _by_id.has(base_id) and (_by_id[base_id] as LevelData).path != "":
			path = (_by_id[base_id] as LevelData).path
		if not FileAccess.file_exists(path):
			return
		if FileAccess.get_sha256(path).to_lower() == expected:
			return
		text = FileAccess.get_file_as_string(path)
	var hashes: Array[String] = [text.sha256_text(), text.replace("\r\n", "\n").sha256_text()]
	if hashes.has(expected):
		return
	_add(data.path, _meta_line(data, "coop_base_hash"), WARNING,
			"the solo file '%s' changed since this co-op copy was made: review the copy, then set coop_base_hash = %s" % [
			base_id, hashes[1]])


## Keeper doors, drum bonds and enemy bonds are paired (R10): every `trigger=keepers:<name>` has keepers and every
## `keeper=<name>` a door; every drum bond (`trigger=drums:<bond>` / `needs=<bond>`) has two or more drums and every
## drum bond opens something; `coop=bond` needs `bond=<name>` with two or more members; `grab` needs `perch=c,r`.
func _check_pairings(data: LevelData, records: Array[Dictionary]) -> void:
	var keepers: Dictionary = {}       # name -> [records]
	var keeper_doors: Dictionary = {}  # name -> line
	var drums: Dictionary = {}         # bond -> [records]
	var drum_users: Dictionary = {}    # bond -> line
	var bonds: Dictionary = {}         # enemy bond -> [records]
	for record: Dictionary in records:
		var id: String = String(record["id"])
		var params: Dictionary = record["params"]
		var line: int = int(record["line"])
		var category: String = Spawner.category(StringName(id))
		if id == "objects/column" and params.has("trigger"):
			var trigger: String = str(params["trigger"])
			if trigger.begins_with("keepers:"):
				keeper_doors[trigger.substr(8)] = line
			elif trigger.begins_with("drums:"):
				drum_users[trigger.substr(6)] = line
		if id == "objects/gate" and params.has("needs"):
			drum_users[str(params["needs"])] = line
		if id == "objects/drum":
			if not params.has("bond"):
				_add(data.path, line, ERROR, "objects/drum needs bond=<name> (the drums struck together)")
			else:
				_append_to(drums, str(params["bond"]), record)
		if category != "enemies" and category != "bosses":
			continue
		if params.has("keeper"):
			_append_to(keepers, str(params["keeper"]), record)
		var coop_trait: String = str(params.get("coop", ""))
		if coop_trait == "bond" and not params.has("bond"):
			_add(data.path, line, ERROR, "'%s' coop=bond needs bond=<name> (its partners)" % id)
		if params.has("bond"):
			_append_to(bonds, str(params["bond"]), record)
		if coop_trait == "grab":
			var perch: PackedInt32Array = LevelText.to_int_list(params.get("perch", ""))
			if perch.size() != 2:
				_add(data.path, line, ERROR, "'%s' coop=grab needs perch=c,r (the pit-side cell it carries a hero to)" % id)
			elif perch[0] < 0 or perch[1] < 0 or perch[0] >= data.cols or perch[1] >= data.row_count():
				_add(data.path, line, ERROR, "'%s' perch=%s is outside the map" % [id, str(params["perch"])])
	for keeper_name: String in keeper_doors:
		if not keepers.has(keeper_name):
			_add(data.path, int(keeper_doors[keeper_name]), ERROR,
					"keeper door 'keepers:%s' has no enemy with keeper=%s" % [keeper_name, keeper_name])
	for keeper_name: String in keepers:
		var first: Dictionary = (keepers[keeper_name] as Array)[0]
		if not keeper_doors.has(keeper_name):
			_add(data.path, int(first["line"]), ERROR,
					"keeper=%s: no objects/column trigger=keepers:%s waits for it" % [keeper_name, keeper_name])
		for record: Dictionary in keepers[keeper_name]:
			var carried: String = str(record["params"].get("coop", ""))
			if not ["shell", "bond", "daze"].has(carried) and not COOP_ONLY_ENEMIES.has(String(record["id"])):
				_add(data.path, int(record["line"]), WARNING,
						"keeper '%s' carries no shell, bond or daze trait: one hero may beat it alone" % keeper_name)
	for bond: String in drum_users:
		if not drums.has(bond) or (drums[bond] as Array).size() < 2:
			_add(data.path, int(drum_users[bond]), ERROR,
					"drum bond '%s' needs two or more objects/drum bond=%s" % [bond, bond])
	for bond: String in drums:
		if not drum_users.has(bond):
			_add(data.path, int((drums[bond] as Array)[0]["line"]), ERROR,
					"drum bond '%s' opens nothing (objects/column trigger=drums:%s or objects/gate needs=%s)" % [
					bond, bond, bond])
	for bond: String in bonds:
		if (bonds[bond] as Array).size() < 2:
			_add(data.path, int((bonds[bond] as Array)[0]["line"]), ERROR,
					"bond '%s' has one member: a bond links two or more enemies" % bond)


## The x2 tablets of one difficulty (LEVEL_DESIGN.md 15.7.4): each names its gate (`gate=`) or marks a secret, has
## a `far=c,r` air cell above a floor, and no gate has two. Returns the valid ones: {"gate", "secret", "cell",
## "far", "line"}.
func _check_tablets(data: LevelData, grid: TileGrid, records: Array[Dictionary], difficulty: int) -> Array[Dictionary]:
	var tablets: Array[Dictionary] = []
	var names: Dictionary = {}
	for record: Dictionary in records:
		if String(record["id"]) != "objects/x2_tablet" or not LevelText.applies_to(record["params"], difficulty):
			continue
		var tablet: Dictionary = parse_tablet(record)
		var line: int = int(record["line"])
		var label: String = "objects/x2_tablet"
		if tablet["gate"] == "" and not tablet["secret"]:
			_add(data.path, line, ERROR, "%s needs gate=<name> (or secret for an x2 secret)" % label)
			continue
		if tablet["far"] == Vector2i(-1, -1):
			_add(data.path, line, ERROR, "%s needs far=c,r: the cell beyond the gate (the solo search's goal)" % label)
			continue
		var far: Vector2i = tablet["far"]
		if not grid.in_bounds(far.x, far.y):
			_add(data.path, line, ERROR, "%s far=%d,%d is outside the map" % [label, far.x, far.y])
			continue
		if grid.side_at(far.x, far.y) == TileGrid.SIDE_WALL or not TileGrid.is_ground(grid.floor_at(far.x, far.y + 1)):
			_add(data.path, line, ERROR, "%s far=%d,%d must be an air cell above a floor" % [label, far.x, far.y])
		var gate: String = tablet["gate"]
		if gate != "":
			if names.has(gate):
				_add(data.path, line, ERROR, "gate '%s' has two x2 tablets in %s (one per gate)" % [
					gate, Defs.difficulty_name(difficulty)])
				continue
			names[gate] = true
		tablets.append(tablet)
	return tablets


## An x2 tablet record as {"gate": String ("" = none), "secret": bool, "cell": Vector2i, "far": Vector2i
## ((-1, -1) = missing or malformed), "line": int}. Shared with the solo search (CoopSearch).
static func parse_tablet(record: Dictionary) -> Dictionary:
	var params: Dictionary = record["params"]
	var far: Vector2i = Vector2i(-1, -1)
	var parts: PackedStringArray = str(params.get("far", "")).replace(" ", "").split(",")
	if parts.size() == 2 and parts[0].is_valid_int() and parts[1].is_valid_int():
		far = Vector2i(parts[0].to_int(), parts[1].to_int())
	return {
		"gate": str(params.get("gate", "")) if params.has("gate") and not params["gate"] is bool else "",
		"secret": params.has("secret") and bool(params["secret"]),
		"cell": Vector2i(int(record["col"]), int(record["row"])),
		"far": far,
		"line": int(record["line"]),
	}


## Every co-op mechanism lies inside the area of some x2 tablet's gate (its tablet and far cell grown by one view);
## a file with mechanisms needs tablets at all.
func _check_gate_mechanisms(data: LevelData, records: Array[Dictionary], tablets: Array[Dictionary],
		difficulty: int) -> void:
	var areas: Array[Rect2i] = []
	for tablet: Dictionary in tablets:
		if tablet["gate"] != "":
			areas.append(_gate_area(tablet))
	for record: Dictionary in records:
		if not LevelText.applies_to(record["params"], difficulty) or not _is_mechanism(record):
			continue
		var cell: Vector2i = Vector2i(int(record["col"]), int(record["row"]))
		if areas.is_empty():
			_add(data.path, int(record["line"]), ERROR,
					"'%s' is a co-op mechanism but the file has no objects/x2_tablet gate= (in %s)" % [
					String(record["id"]), Defs.difficulty_name(difficulty)])
			return
		var inside: bool = false
		for area: Rect2i in areas:
			inside = inside or area.has_point(cell)
		if not inside:
			_add(data.path, int(record["line"]), WARNING,
					"'%s' at %d,%d belongs to no x2 tablet's gate (one view around a tablet and its far cell)" % [
					String(record["id"]), cell.x, cell.y])


## Gate count by the stage kind of `coop_of` (DESIGN.md D.8 #1): a main stage 2+ gates, a sub-stage 1+ gate, a boss's
## co-op form counts for both; bonus stages and endings need none.
func _check_gate_count(data: LevelData, records: Array[Dictionary], tablets: Array[Dictionary],
		difficulty: int) -> void:
	var solo_kind: String = _solo_kind(str(data.value("coop_of")))
	var needed: int = 0
	if solo_kind == "main":
		needed = PartyTuning.MAIN_MIN_GATES
	elif solo_kind == "sub":
		needed = PartyTuning.SUB_MIN_GATES
	if needed == 0:
		return
	var gates: Dictionary = {}
	for tablet: Dictionary in tablets:
		if tablet["gate"] != "" and not tablet["secret"]:
			gates[tablet["gate"]] = true
	if gates.size() >= needed:
		return
	for record: Dictionary in records:
		if Spawner.category(record["id"]) == "bosses" and LevelText.applies_to(record["params"], difficulty):
			return  # the boss's co-op form is the gate
	_add(data.path, int(data.section_lines.get(LevelData.SECTION_ENTITIES, data.section_lines.get(
			LevelData.SECTION_TILES, 0))), ERROR, "a co-op %s stage needs %d co-op gates (x2 tablets with gate=) in %s; found %d" % [
			solo_kind, needed, Defs.difficulty_name(difficulty), gates.size()])


## At least a third of the enemy records of a co-op stage carry a trait (DESIGN.md D.6; co-op-only enemies count).
func _check_trait_share(data: LevelData, records: Array[Dictionary], difficulty: int) -> void:
	var enemies: int = 0
	var traits: int = 0
	for record: Dictionary in records:
		var id: String = String(record["id"])
		if Spawner.category(StringName(id)) != "enemies" or id == "enemies/decoration" \
				or not LevelText.applies_to(record["params"], difficulty):
			continue
		enemies += 1
		if record["params"].has("coop") or COOP_ONLY_ENEMIES.has(id):
			traits += 1
	if enemies > 0 and traits * PartyTuning.TRAIT_SHARE_DEN < enemies:
		_add(data.path, int(data.section_lines.get(LevelData.SECTION_TILES, 0)), ERROR,
				"%d of %d enemy records carry a co-op trait in %s: at least a third must" % [
				traits, enemies, Defs.difficulty_name(difficulty)])


## Static solo-impossibility rules (LEVEL_DESIGN.md 15.7.6): within REACH_COLS across and REACH_ROWS below the far
## cell of a height gate nothing a single hero could climb on (an enemy to bounce on, a spring, a geyser that is not a
## deadly vent, a vine, a bark board, a glider, a moving or dropping platform, a mount, a pogo ladder of hittables);
## no bark board within BARK_GATE_CELLS of any gate.
func _check_ledge_reach(data: LevelData, records: Array[Dictionary], tablets: Array[Dictionary],
		difficulty: int) -> void:
	for tablet: Dictionary in tablets:
		if tablet["gate"] == "":
			continue
		var far: Vector2i = tablet["far"]
		var cell: Vector2i = tablet["cell"]
		var height_gate: bool = cell.y - far.y >= HEIGHT_GATE_ROWS
		var reach: Rect2i = Rect2i(far.x - REACH_COLS, far.y, REACH_COLS * 2 + 1, REACH_ROWS + 1)
		var hittable_cells: Dictionary = {}
		for record: Dictionary in records:
			if not LevelText.applies_to(record["params"], difficulty):
				continue
			var id: String = String(record["id"])
			var at: Vector2i = Vector2i(int(record["col"]), int(record["row"]))
			if id == "objects/bark_board" and (_chebyshev(at, cell) <= BARK_GATE_CELLS
					or _chebyshev(at, far) <= BARK_GATE_CELLS):
				_add(data.path, int(record["line"]), ERROR,
						"bark board at %d,%d is within %d cells of gate '%s' (a spear step climbs it alone)" % [
						at.x, at.y, BARK_GATE_CELLS, tablet["gate"]])
				continue
			if not height_gate or not reach.has_point(at):
				continue
			var booster: bool = BOOSTERS.has(id)
			if id == "objects/geyser" and record["params"].has("deadly") and bool(record["params"]["deadly"]):
				booster = false
			if Spawner.category(StringName(id)) == "enemies" and id != "enemies/decoration":
				booster = true
			if booster:
				_add(data.path, int(record["line"]), ERROR,
						"'%s' at %d,%d is within reach of the ledge of gate '%s' (%d cells across, %d rows below its top): a single hero could climb on it" % [
						id, at.x, at.y, tablet["gate"], REACH_COLS, REACH_ROWS])
			if HITTABLE_IDS.has(id):
				hittable_cells[at] = true
		for at: Vector2i in hittable_cells:
			if hittable_cells.has(at + Vector2i(0, 1)):
				_add(data.path, int(tablet["line"]), ERROR,
						"hittables at %d,%d and %d,%d stack up near gate '%s': a club pogo ladder" % [
						at.x, at.y, at.x, at.y + 1, tablet["gate"]])


## Keeper and Guard halls are exactly HALL_ROWS rows of air under a ceiling over the whole patrol, so nobody jumps or
## bounces over the keeper (orchestrator resolution: 4 rows; LEVEL_DESIGN.md 15.7.5).
func _check_halls(data: LevelData, grid: TileGrid, records: Array[Dictionary]) -> void:
	for record: Dictionary in records:
		var id: String = String(record["id"])
		var params: Dictionary = record["params"]
		if not params.has("keeper") and not GUARD_IDS.has(id):
			continue
		var feet: Vector2i = LevelText.cell_to_feet(float(record["col"]), float(record["row"]), params)
		var col: int = Tuning.to_cell(feet.x)
		var row: int = Tuning.to_cell(feet.y - 1)
		var left: int = int(params.get("left", -3)) if GUARD_IDS.has(id) or params.has("left") else 0
		var right: int = int(params.get("right", 3)) if GUARD_IDS.has(id) or params.has("right") else 0
		var worst: int = HALL_ROWS
		var worst_col: int = col
		for c: int in range(maxi(col + mini(left, 0), 0), mini(col + maxi(right, 0), grid.cols - 1) + 1):
			if grid.side_at(c, row) == TileGrid.SIDE_WALL or not TileGrid.is_ground(grid.floor_at(c, row + 1)):
				continue  # a wall or a gap ends the patrol there
			var height: int = hall_height(grid, c, row)
			if height != HALL_ROWS and (worst == HALL_ROWS or absi(height - HALL_ROWS) > absi(worst - HALL_ROWS)):
				worst = height
				worst_col = c
		if worst != HALL_ROWS:
			var what: String = "keeper" if params.has("keeper") else "Guard"
			var shown: String = "open to the sky" if worst > grid.rows else "%d rows high" % worst
			_add(data.path, int(record["line"]), ERROR,
					"the %s hall of '%s' is %s at column %d: exactly %d rows of air under a ceiling (nobody bounces over it)" % [
					what, id, shown, worst_col, HALL_ROWS])


## Rows of air from the cell (col, row) up to the first wall cell (grid.rows + 1 when there is none: open sky).
static func hall_height(grid: TileGrid, col: int, row: int) -> int:
	var height: int = 0
	var r: int = row
	while r >= 0:
		if grid.side_at(col, r) == TileGrid.SIDE_WALL:
			return height
		height += 1
		r -= 1
	return grid.rows + 1


## Arena checks (LEVEL_DESIGN.md 15.8): 20 x 12 cells, nothing to stand on in the HUD row, a spawn per player, the
## cookpots of Grub Stack, the Clubball pitch, no forbidden objects, the wrap seams, 4-8 visible spots, gaps.
func _check_arena(data: LevelData, grid: TileGrid, records: Array[Dictionary]) -> void:
	var path: String = data.path
	var tiles_line: int = int(data.section_lines.get(LevelData.SECTION_TILES, 0))
	if data.cols != VersusTuning.ARENA_COLS or data.row_count() != VersusTuning.ARENA_FILE_ROWS:
		_add(path, tiles_line, ERROR, "an arena is %d x %d cells (one screen and its fill row); found %d x %d" % [
			VersusTuning.ARENA_COLS, VersusTuning.ARENA_FILE_ROWS, data.cols, data.row_count()])
	for row: int in mini(2, grid.rows):
		for col: int in grid.cols:
			if TileGrid.is_ground(grid.floor_at(col, row)):
				_add(path, data.row_lines[row] if row < data.row_lines.size() else tiles_line, ERROR,
						"row %d of an arena holds a floor at column %d: row 0 is the HUD row (nothing to stand on)" % [
						row, col])
				break
	var players: int = clampi(int(data.value("players")), VersusTuning.PLAYERS_MIN, VersusTuning.PLAYERS_MAX)
	var modes: PackedStringArray = LevelText.to_list(data.value("modes"))
	var spawns: Dictionary = {}
	var cookpots: int = 0
	var coconuts: int = 0
	var goals: Dictionary = {}
	var spots: int = 0
	for record: Dictionary in records:
		var id: String = String(record["id"])
		var params: Dictionary = record["params"]
		var line: int = int(record["line"])
		if ARENA_FORBIDDEN.has(id):
			_add(path, line, ERROR, "'%s' has no place in an arena (no exit, checkpoint or co-op object)" % id)
		match id:
			"objects/spawn_point":
				var index: int = int(params.get("index", 0))
				if index > players:
					_add(path, line, WARNING, "spawn_point index=%d but the arena is for %d players" % [index, players])
				if spawns.has(index):
					_add(path, line, ERROR, "spawn_point index=%d is placed twice" % index)
				spawns[index] = true
				var feet: Vector2i = LevelText.cell_to_feet(float(record["col"]), float(record["row"]), params)
				if not TileGrid.is_ground(grid.floor_at(Tuning.to_cell(feet.x), Tuning.to_cell(feet.y - 1) + 1)):
					_add(path, line, ERROR, "spawn_point index=%d does not stand on a floor" % index)
			"objects/cookpot":
				cookpots += 1
			"objects/coconut":
				coconuts += 1
			"zones/goal":
				var team: int = int(params.get("team", 0))
				goals[team] = true
				var rect: PackedInt32Array = LevelText.to_int_list(params.get("rect", ""))
				if rect.size() == 4 and rect[3] != VersusTuning.GOAL_ROWS:
					_add(path, line, ERROR, "a goal mouth is %d rows high (rect h = %d)" % [VersusTuning.GOAL_ROWS, rect[3]])
			"objects/hidden_spot":
				spots += 1
	for index: int in range(2, players + 1):
		if not spawns.has(index):
			_add(path, tiles_line, ERROR, "the arena is for %d players but has no objects/spawn_point index=%d" % [
				players, index])
	if modes.has("grub_stack"):
		var needed: int = VersusTuning.COOKPOTS_4P if players >= VersusTuning.PLAYERS_MAX else VersusTuning.COOKPOTS
		if cookpots < needed:
			_add(path, tiles_line, ERROR, "Grub Stack needs %d objects/cookpot on a %d-player arena; found %d" % [
				needed, players, cookpots])
	if modes.has("clubball"):
		if coconuts < 1:
			_add(path, tiles_line, ERROR, "Clubball needs an objects/coconut (the drop point)")
		for team: int in [1, 2]:
			if not goals.has(team):
				_add(path, tiles_line, ERROR, "Clubball needs a zones/goal team=%d" % team)
	if spots < VersusTuning.ARENA_SPOTS_MIN or spots > VersusTuning.ARENA_SPOTS_MAX:
		_add(path, tiles_line, WARNING, "%d hidden spots: an arena has %d-%d visible ones" % [
			spots, VersusTuning.ARENA_SPOTS_MIN, VersusTuning.ARENA_SPOTS_MAX])
	var wrap: String = str(data.value("wrap"))
	if wrap == "lr" and grid.cols > 0:
		var floor_row: int = VersusTuning.ARENA_FLOOR_ROW
		if not TileGrid.is_ground(grid.floor_at(0, floor_row)) or not TileGrid.is_ground(grid.floor_at(grid.cols - 1,
				floor_row)):
			_add(path, tiles_line, ERROR, "wrap = lr: the floor (row %d) must continue across the seam (columns 0 and %d)" % [
				floor_row, grid.cols - 1])
		for row: int in grid.rows:
			if TileGrid.is_ground(grid.floor_at(0, row)) != TileGrid.is_ground(grid.floor_at(grid.cols - 1, row)) \
					and row != floor_row:
				_add(path, data.row_lines[row] if row < data.row_lines.size() else tiles_line, WARNING,
						"wrap = lr: row %d stands on one side of the seam only" % row)
	elif wrap == "tb":
		for col: int in grid.cols:
			if grid.floor_at(col, grid.rows - 1) == TileGrid.FLOOR_DEADLY:
				_add(path, tiles_line, WARNING, "wrap = tb: the bottom row is the seam - no deadly cells there (column %d)" % col)
				break
	for row: int in grid.rows:
		var gap: int = _widest_gap(grid, row)
		if gap > VersusTuning.ARENA_GAP_MAX_CELLS:
			_add(path, data.row_lines[row] if row < data.row_lines.size() else tiles_line, WARNING,
					"a clear gap of %d cells in row %d (at most %d in an arena)" % [gap, row, VersusTuning.ARENA_GAP_MAX_CELLS])


## The widest run of cells without a floor between two floor cells of one row (0 when the row has fewer than two).
## A run that ends at a wall face (a side wall with a side wall above it, e.g. the Totem Ring's totem) is no gap
## anybody jumps across, so it does not count (DA's report, G1 integration).
static func _widest_gap(grid: TileGrid, row: int) -> int:
	var widest: int = 0
	var last: int = -1
	for col: int in grid.cols:
		if TileGrid.is_ground(grid.floor_at(col, row)):
			if last >= 0 and not _wall_face(grid, col, row) and not _wall_face(grid, last, row):
				widest = maxi(widest, col - last - 1)
			last = col
	return widest


## True when the cell is a side wall with a side wall right above it (a wall face, not a ledge to land on).
static func _wall_face(grid: TileGrid, col: int, row: int) -> bool:
	return row > 0 and grid.side_at(col, row) == TileGrid.SIDE_WALL and grid.side_at(col, row - 1) == TileGrid.SIDE_WALL


func _is_mechanism(record: Dictionary) -> bool:
	var id: String = String(record["id"])
	if GATE_MECHANISMS.has(id):
		return true
	if id != "objects/column":
		return false
	var params: Dictionary = record["params"]
	return params.has("rise_while") or params.has("sink_while") or _is_trigger_group(str(params.get("trigger", "")))


func _gate_area(tablet: Dictionary) -> Rect2i:
	var cell: Vector2i = tablet["cell"]
	var far: Vector2i = tablet["far"]
	var area: Rect2i = Rect2i(cell, Vector2i.ONE).merge(Rect2i(far, Vector2i.ONE))
	return area.grow_individual(GATE_AREA_COLS, GATE_AREA_ROWS, GATE_AREA_COLS, GATE_AREA_ROWS)


## The kind of the solo level `level_id` (an added level, else its file in res://levels; "" when unknown).
## The kind of stage a file plays as: its own `kind`, or for a co-op file (`kind = coop`) the kind of its solo level
## `coop_of` - a co-op Feast Land is left through its warp like the solo one (Flow resolves it the same way,
## SceneFlow._campaign_kind; wf8_D5_to_world-B.txt #2).
func _stage_kind(data: LevelData) -> String:
	var kind: String = str(data.value("kind"))
	if kind == LevelText.KIND_COOP:
		var base: String = _solo_kind(str(data.value("coop_of")))
		if base != "":
			return base
	return kind


func _solo_kind(level_id: String) -> String:
	if level_id == "":
		return ""
	if _by_id.has(level_id):
		return str((_by_id[level_id] as LevelData).value("kind"))
	var path: String = "res://levels/%s.lvl" % level_id
	if not FileAccess.file_exists(path):
		return ""
	return str(LevelText.parse_meta(FileAccess.get_file_as_string(path)).get("kind", "main"))


## Cells of a plate: its anchor cell and `w - 1` cells to the right.
func _plate_cells(record: Dictionary) -> Rect2i:
	var w: int = maxi(int(record["params"].get("w", 2)), 1)
	return Rect2i(int(record["col"]), int(record["row"]), w, 1)


## Cells of a column's block at rest: `size=w,h` with the anchor as its bottom-left cell.
func _column_cells(record: Dictionary) -> Rect2i:
	var size: PackedInt32Array = LevelText.to_int_list(record["params"].get("size", "1,1"))
	var w: int = maxi(size[0], 1) if size.size() >= 1 else 1
	var h: int = maxi(size[1], 1) if size.size() >= 2 else 1
	return Rect2i(int(record["col"]), int(record["row"]) - h + 1, w, h)


## Cells between two cell rectangles (Chebyshev: the larger of the column and row gaps; 0 when they touch).
static func _cell_gap(a: Rect2i, b: Rect2i) -> int:
	var dx: int = maxi(maxi(b.position.x - a.end.x, a.position.x - b.end.x) + 1, 0)
	var dy: int = maxi(maxi(b.position.y - a.end.y, a.position.y - b.end.y) + 1, 0)
	return maxi(dx, dy)


static func _chebyshev(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))


static func _append_to(groups: Dictionary, key: String, record: Dictionary) -> void:
	if not groups.has(key):
		groups[key] = []
	(groups[key] as Array).append(record)


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


## True when a column `trigger` names a group (`keepers:<name>`, `drums:<bond>`) instead of a rectangle.
static func _is_trigger_group(text: String) -> bool:
	for prefix: String in TRIGGER_GROUPS:
		if text.begins_with(prefix) and text.length() > prefix.length():
			return true
	return false


static func _is_password(text: String) -> bool:
	if text.length() != 4:
		return false
	for i: int in text.length():
		if not PASSWORD_CHARS.contains(text[i]):
			return false
	return true
