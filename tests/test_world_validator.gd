extends TestCase
## The level validator (ARCHITECTURE.md 7.9, tools/validate_levels.gd) on good files and on broken texts.

## A minimal valid level; `%s` slots: extra meta lines, extra legend lines, tile rows 8..10, [entities] lines.
const TEMPLATE: String = """[meta]
format = 1
id = %s
kind = test
terrain_a = jungle/terrain_grass
music = level_jungle
%s
[legend]
E = objects/exit
%s
[tiles]
........................
........................
........................
........................
........................
........................
........................
........................
%s
########################
########################
[entities]
%s
"""
const PLAIN_ROWS: String = "........................\n........................\n.@....................E."


func _validator(texts: Dictionary) -> LevelValidator:
	var validator: LevelValidator = LevelValidator.new()
	for id: String in texts:
		validator.add_text(StringName(id), texts[id])
	validator.run()
	return validator


func _level(id: String, meta: String = "", legend: String = "", rows: String = PLAIN_ROWS,
		entities: String = "") -> String:
	return TEMPLATE % [id, meta, legend, rows, entities]


func _messages(validator: LevelValidator) -> String:
	var lines: PackedStringArray = PackedStringArray()
	for problem: Dictionary in validator.problems:
		lines.append(LevelValidator.format_problem(problem))
	return "\n".join(lines)


func test_shipped_world_levels_are_valid() -> void:
	var validator: LevelValidator = LevelValidator.new()
	var dir: DirAccess = DirAccess.open("res://levels")
	var files: PackedStringArray = dir.get_files()
	var count: int = 0
	for file: String in files:
		if file == "test_example.lvl" or (file.begins_with("test_world_") and file.ends_with(".lvl")):
			assert_true(validator.add_file("res://levels/" + file))
			count += 1
	validator.run()
	assert_true(count >= 2, "test_example and the world showcase levels")
	assert_eq(validator.error_count(), 0, _messages(validator))


func test_minimal_level_is_valid_and_lines_are_reported() -> void:
	var validator: LevelValidator = _validator({"good_level": _level("good_level")})
	assert_eq(validator.error_count(), 0, _messages(validator))
	var bad: LevelValidator = _validator({"bad_line": _level("bad_line", "biome = moon")})
	assert_eq(bad.error_count(), 1)
	var problem: Dictionary = bad.problems[0]
	assert_eq(int(problem["line"]), 7, "the line of the offending key")
	assert_eq(LevelValidator.format_problem(problem),
			"bad_line.lvl:7: error: biome 'moon' must be one of: jungle, cave, ice, volcano, feast, village, canyon, "
			+ "swamp, coast, ruins, sky")


func test_header_rules() -> void:
	var text: String = _level("wrong_name", "format = 3\nmusic = disco\nnext = nowhere\nice_a = 5\nwind = 0:8,x\n" +
			"password_beginner = ab\nscroll = sideways\ntime.hard = 3\nflavour = sweet")
	var validator: LevelValidator = _validator({"header": text.replace("format = 1\n", "")})
	assert_true(validator.has_problem("format must be 1 or 2"))
	assert_true(validator.has_problem("must equal the file name"))
	assert_true(validator.has_problem("not a known music context"))
	assert_true(validator.has_problem("next 'nowhere' is not a level"))
	assert_true(validator.has_problem("ice_a = 5 must be an integer 0..3"))
	assert_true(validator.has_problem("wind entry 'x'"))
	assert_true(validator.has_problem("must be 4 characters"))
	assert_true(validator.has_problem("scroll 'sideways'"))
	assert_true(validator.has_problem("variant suffix must be .beginner or .expert"))
	assert_true(validator.has_problem("unknown meta key 'flavour'", LevelValidator.WARNING))


func test_grid_rules() -> void:
	var rows: String = "....../.................\n.@...@..Z...............\n......................E."
	var validator: LevelValidator = _validator({"grid": _level("grid", "", "", rows)})
	assert_true(validator.has_problem("exactly one hero start '@' (found 2)"))
	assert_true(validator.has_problem("character 'Z' in row 9"))
	assert_true(validator.has_problem("slope '/' at column 6, row 8 must stand on"))
	var floating: String = "........................\n.@......................\n........................"
	var no_floor: LevelValidator = _validator({"floating": _level("floating", "", "", floating,
			"objects/exit 20 10")})
	assert_true(no_floor.has_problem("must stand on a floor"))
	var small: LevelValidator = _validator({"small": "[meta]\nformat = 1\nid = small\nterrain_a = jungle/terrain\n" +
			"[legend]\nE = objects/exit\n[tiles]\n.@.E.\n#####\n"})
	assert_true(small.has_problem("outside 20..256 x 12..192"))


func test_entity_rules() -> void:
	var entities: String = "\n".join(PackedStringArray([
		"monsters/ogre 3 9",
		"player/player 4 9",
		"objects/gate 5 9 name=door dest=nowhere",
		"bosses/brute 6 9 arena=missing",
		"items/food 7 9 index=99",
		"objects/hidden_spot 8 10 contents=food:99,banana,weapon:sword,heart:2 tile=#",
		"items/heart 9 11",
		"objects/platform 10 5 dir=9 colour=red",
		"zones/secret 11 5",
		"zones/dark 12 5 rect=20,2,10,2",
		"items/heart 30 5",
		"objects/marker 13 5 name=door",
	]))
	var validator: LevelValidator = _validator({"entities": _level("entities", "", "", PLAIN_ROWS, entities)})
	assert_true(validator.has_problem("'monsters/ogre' has no known category"))
	assert_true(validator.has_problem("'player/player' is spawned by code"))
	assert_true(validator.has_problem("dest 'nowhere' is not the name of a gate or marker"))
	assert_true(validator.has_problem("arena 'missing' is not the name of a zones/arena"))
	assert_true(validator.has_problem("items/food index = 99 must be an integer 0..47"))
	assert_true(validator.has_problem("token 'food:99': index must be 0..47"))
	assert_true(validator.has_problem("token 'banana' is not <item name>"))
	assert_true(validator.has_problem("weapon kind must be club"))
	assert_true(validator.has_problem("'heart' takes no index"))
	assert_true(validator.has_problem("'items/heart' at column 9, row 11 is inside a solid tile"))
	assert_true(validator.has_problem("objects/platform dir = 9"))
	assert_true(validator.has_problem("unknown parameter 'colour'", LevelValidator.WARNING))
	assert_true(validator.has_problem("'zones/secret' needs rect"))
	assert_true(validator.has_problem("rect=20,2,10,2 reaches outside"))
	assert_true(validator.has_problem("'items/heart' at column 30, row 5 is outside the map"))
	assert_true(validator.has_problem("name 'door' is used more than once"))
	assert_false(validator.has_problem("'objects/hidden_spot' at column 8"), "hidden spots belong in the ground")


## `objects/hero_start slot=2..4` (2.0, TECH_AUDIT.md 3.3): a loader marker in the catalogue without a scene; the
## slot is required and in range, one marker per slot and difficulty, standing on a floor.
func test_hero_start_markers() -> void:
	var good: LevelValidator = _validator({"party": _level("party", "", "", PLAIN_ROWS, "\n".join(PackedStringArray([
		"objects/hero_start 3 10 slot=2",
		"objects/hero_start 5 10 slot=3 expert",
		"objects/hero_start 6 10 slot=3 beginner",
	])))})
	assert_eq(good.error_count(), 0, _messages(good))
	assert_false(good.has_problem("hero_start", LevelValidator.WARNING), _messages(good))
	var bad: LevelValidator = _validator({"bad": _level("bad", "", "", PLAIN_ROWS, "\n".join(PackedStringArray([
		"objects/hero_start 3 10 slot=2",
		"objects/hero_start 4 10 slot=2",
		"objects/hero_start 5 10",
		"objects/hero_start 6 10 slot=5",
		"objects/hero_start 7 5 slot=4",
	])))})
	assert_true(bad.has_problem("objects/hero_start slot=2 is placed more than once"), _messages(bad))
	assert_true(bad.has_problem("objects/hero_start needs slot=2..4"))
	assert_true(bad.has_problem("objects/hero_start slot = 5 must be an integer 2..4"))
	assert_true(bad.has_problem("'objects/hero_start' at column 7, row 5 does not stand on a floor",
			LevelValidator.WARNING))
	assert_false(bad.has_problem("no scene for 'objects/hero_start'", LevelValidator.WARNING))
	assert_false(bad.has_problem("'objects/hero_start' is not in the entity catalogue", LevelValidator.WARNING))


## Level format 2 (2.0, ARCHITECTURE.md 7.11): the new keys and values are accepted and checked, a co-op file and an
## arena need their keys, the tar floor ':' is a tile, the new ids are in the catalogue with their parameters.
func test_format_2_headers() -> void:
	var hash: String = "ab".repeat(32)
	var book2: String = _level("book_two", "book = 2\nbelt = fresh\nbiome = canyon\nliquid = tar\nscroll = rising\n"
			+ "rise_speed = 16\nrise_speed.expert = 24\nwind = 0:-24,40:24\nwind_loop = 80", "", PLAIN_ROWS
			.replace(".@....", ".@:::.")).replace("format = 1", "format = 2")
	hash = book2.sha256_text()
	var coop: String = _level("book_two_coop", "kind = coop\nbook = 2\ncoop_of = book_two\ncoop_base_hash = " + hash) \
			.replace("format = 1", "format = 2").replace("kind = test\n", "")
	var arena: String = _arena_text("arena_ring", "modes = grub_stack,last_caveman\nwrap = lr\nsudden = stampede")
	var good: LevelValidator = _validator({"book_two": book2, "book_two_coop": coop, "arena_ring": arena})
	assert_eq(good.error_count(), 0, _messages(good))
	assert_false(good.has_problem("changed since", LevelValidator.WARNING), "the hash of the solo text matches")
	assert_false(good.has_problem("unknown meta key", LevelValidator.WARNING), _messages(good))
	assert_false(good.has_problem("format 2 key", LevelValidator.WARNING), _messages(good))
	assert_false(good.has_problem("no exit"), "an arena has no way out")
	assert_false(good.has_problem("no exit", LevelValidator.WARNING), "an arena has no way out")
	var bad: LevelValidator = _validator({
		"broken": _level("broken", "book = 3\nbelt = rusty\nbiome = mars\nliquid = jam\nscroll = up\n"
				+ "coop_of = nowhere\ncoop_base_hash = 1234\nplayers = 6\nmodes = tag\nwrap = round\nsudden = rain\n"
				+ "rise_speed = 0\nwind_loop = -1").replace("format = 1", "format = 2"),
		"lone_coop": _level("lone_coop").replace("kind = test", "kind = coop").replace("format = 1", "format = 2"),
		"lone_arena": _level("lone_arena").replace("kind = test", "kind = arena").replace("format = 1", "format = 2"),
		"old_style": _level("old_style", "book = 2", "", PLAIN_ROWS.replace(".@....", ".@:::.")),
	})
	for fragment: String in ["book = 3 must be 1 or 2", "belt 'rusty'", "biome 'mars'", "liquid 'jam'",
			"scroll 'up'", "coop_of 'nowhere' is not a level", "coop_base_hash must be the sha256",
			"players = 6 must be an integer 2..4", "modes 'tag'", "wrap 'round'", "sudden 'rain'",
			"rise_speed = 0 must be an integer", "wind_loop = -1 must be an integer",
			"a co-op file (kind = coop) needs meta key 'coop_of'",
			"a co-op file (kind = coop) needs meta key 'coop_base_hash'",
			"an arena (kind = arena) needs meta key 'players'", "an arena (kind = arena) needs meta key 'modes'"]:
		assert_true(bad.has_problem(fragment), "%s\n%s" % [fragment, _messages(bad)])
	assert_true(bad.has_problem("'book' is a format 2 key: set format = 2", LevelValidator.WARNING))
	assert_true(bad.has_problem("the tar floor ':' is format 2", LevelValidator.WARNING))


func test_format_2_entities() -> void:
	var entities: String = "\n".join(PackedStringArray([
		"enemies/roller 3 10 range=6 dizzy=33 coop=shell bond=pair keeper=hall",
		"enemies/snatcher 4 4 kind=gull coop=grab perch=2,9",
		"enemies/walker 5 10 coop=sticky",
		"items/painting 6 10 index=30",
		"items/weapon 7 10 kind=spear temp",
		"objects/geyser 8 10 period=20 skin=mud deadly",
		"objects/column 9 10 size=1,1 rise=0 trigger=keepers:hall rise_while=plate_a",
		"objects/column 10 10 size=1,1 rise=2 trigger=drums:pair",
		"objects/gate 11 10 name=door dest=door2 needs=pair",
		"objects/marker 12 10 name=door2",
		"objects/hidden_spot 13 11 kind=big contents=painting:3 tile=#",
		"zones/current 14 5 rect=2,2,4,2 dir=l speed=4",
		"objects/x2_tablet 15 10 gate=ledge far=20,9",
	]))
	var validator: LevelValidator = _validator({"cast": _level("cast", "", "", PLAIN_ROWS, entities)
			.replace("format = 1", "format = 2")})
	assert_false(validator.has_problem("unknown parameter", LevelValidator.WARNING), _messages(validator))
	assert_false(validator.has_problem("is not in the entity catalogue", LevelValidator.WARNING), _messages(validator))
	assert_false(validator.has_problem("trigger="), "keepers: and drums: name groups, not rectangles")
	assert_false(validator.has_problem("contents token"), "a painting may hide in a big spot")
	assert_false(validator.has_problem("items/weapon kind"), "the spear is a weapon")
	assert_true(validator.has_problem("enemies/snatcher kind 'gull'"))
	assert_true(validator.has_problem("enemies/walker coop 'sticky'"))
	assert_true(validator.has_problem("items/painting index = 30 must be an integer 0..29"))
	assert_true(validator.has_problem("objects/geyser period = 20 must be an integer 34.."))
	assert_true(validator.has_problem("zones/current speed = 4 must be an integer 1..3"))


func test_book2_skins_and_sign_length() -> void:
	var entities: String = "
".join(PackedStringArray([
		"objects/seesaw 3 10 len=5 skin=mushroom",
		"objects/container 4 10 skin=chest",
		"objects/platform 5 8 skin=cloud",
		"objects/drop_platform 6 8 skin=driftwood",
		"objects/spring 7 10 skin=cap",
		"objects/drum 8 10 bond=pair skin=cap",
		"objects/drum 9 10 bond=pair skin=drum",
		"items/trophy 10 10 skin=roast",
		"objects/spring 11 10 skin=mushroom",
		"objects/sign 12 10 text=SIGN_SHORT",
	]))
	var validator: LevelValidator = _validator({"skins": _level("skins", "", "", PLAIN_ROWS, entities)
			.replace("format = 1", "format = 2")})
	assert_false(validator.has_problem("unknown parameter", LevelValidator.WARNING), _messages(validator))
	for accepted: String in ["seesaw skin", "container skin", "platform skin", "drop_platform skin", "trophy skin",
			"drum skin"]:
		assert_false(validator.has_problem("objects/%s" % accepted) or validator.has_problem("items/%s" % accepted),
				"%s accepted: %s" % [accepted, _messages(validator)])
	assert_true(validator.has_problem("objects/spring skin 'mushroom'"), "the spring is a flower or a cap")
	assert_false(validator.has_problem("sign text 'SIGN_SHORT'", LevelValidator.WARNING))
	if ResourceLoader.exists(LevelValidator.SIGN_SCRIPT):
		# An untranslated key is measured as it stands: a long text takes more than three board lines.
		validator._check_sign_text("skins.lvl", 13, "A very long sign text that goes on and on about clubbing. ".repeat(3))
		assert_true(validator.has_problem("board lines (at most 3", LevelValidator.WARNING),
				"a sign longer than three board lines is warned: %s" % _messages(validator))


func test_exit_path_rules() -> void:
	var none: LevelValidator = _validator({"no_exit": _level("no_exit", "", "", PLAIN_ROWS.replace("E", "."))
			.replace("kind = test", "kind = main")})
	assert_true(none.has_problem("the level has no exit"))
	var test_level: LevelValidator = _validator({"no_exit": _level("no_exit", "", "", PLAIN_ROWS.replace("E", "."))})
	assert_true(test_level.has_problem("the level has no exit", LevelValidator.WARNING),
			"developer levels (kind = test) only get a warning")
	var two: LevelValidator = _validator({"two_exits": _level("two_exits", "", "", PLAIN_ROWS.replace(".@", "E@"))})
	assert_true(two.has_problem("2 objects/exit"))
	var locked: LevelValidator = _validator({"locked": _level("locked", "", "",
			PLAIN_ROWS.replace("E", "L")).replace("E = objects/exit", "L = objects/exit locked=true")})
	assert_true(locked.has_problem("no fire-starter"))
	var opened_rows: String = PLAIN_ROWS.replace("E", "L").replace(".@..", ".@F.")
	var opened: LevelValidator = _validator({"opened": _level("opened", "", "F = items/fire_starter",
			opened_rows).replace("E = objects/exit", "L = objects/exit locked=true")})
	assert_false(opened.has_problem("no fire-starter"), _messages(opened))
	var trophy: LevelValidator = _validator({"final": _level("final", "", "", PLAIN_ROWS.replace("E", "."),
			"zones/arena 10 9 name=hall rect=2,2,20,8\nbosses/colossus 20 9 arena=hall")})
	assert_false(trophy.has_problem("no exit"), "the Colossus drops the trophies")
	var bonus: LevelValidator = _validator({"bonus_room": _level("bonus_room", "kind = bonus", "W = items/warp",
			PLAIN_ROWS.replace("E", "W"))})
	assert_false(bonus.has_problem("exit"), "a bonus stage is left through its warp")


func test_passwords_are_unique_across_levels() -> void:
	var validator: LevelValidator = _validator({
		"first": _level("first", "password_beginner = AB12"),
		"second": _level("second", "password_expert = ab12"),
	})
	assert_true(validator.has_problem("password 'AB12' is already used by first.lvl (password_beginner)"))


func test_references_between_levels_resolve() -> void:
	var validator: LevelValidator = _validator({
		"first": _level("first", "next = second\nbonus = second"),
		"second": _level("second"),
	})
	assert_eq(validator.error_count(), 0, _messages(validator))


func test_visual_sections_and_syntax() -> void:
	var text: String = _level("visual") + "[backwall]\n0 0 30 2\n1 1 two 2\n[overrides]\n3 3 a 45\n3 3 c 1\n" \
			+ "3 3 a 1 layer=top\n[colours]\nred\n"
	var validator: LevelValidator = _validator({"visual": text})
	assert_true(validator.has_problem("reaches outside the map"))
	assert_true(validator.has_problem("malformed backwall line '1 1 two 2'"))
	assert_true(validator.has_problem("atlas index 45 must be 0..39"))
	assert_true(validator.has_problem("malformed override line '3 3 c 1'"))
	assert_true(validator.has_problem("override layer 'top'"))
	assert_true(validator.has_problem("unknown section [colours]", LevelValidator.WARNING))


func test_legend_rules() -> void:
	var validator: LevelValidator = _validator({"legend": _level("legend",
			"", "Q = objects/hidden_spot tile=ab\nU = items/heart\nk = props/jungle/nothing_here")})
	assert_true(validator.has_problem("tile=ab must be one fixed tile character"))
	assert_true(validator.has_problem("legend character 'U' is never used", LevelValidator.WARNING))
	assert_true(validator.has_problem("prop 'props/jungle/nothing_here' does not exist"))


# =================================================================================================================
# Content rules of co-op files and arenas (world-B, PLAN.md P1.7; LEVEL_DESIGN.md 15.7 / 15.8)
# =================================================================================================================

const ARENA_ROWS: PackedStringArray = [
	"....................", "....................", "....................", "....................",
	"....................", "....................", "....................", "...-----....-----...",
	"....................", ".@..C....P....Q.D.B.", "###?###?####?###?###", "####################",
]
const ARENA_LEGEND: String = "B = objects/spawn_point index=2\nC = objects/spawn_point index=3\n" \
		+ "D = objects/spawn_point index=4\nP = objects/cookpot\nQ = objects/cookpot team=1\n"
const COOP_COLS: int = 40
const COOP_ROWS: int = 16


## A 20 x 12 arena (format 2, four spawns, two cookpots, four spots) with extra meta lines.
func _arena_text(id: String, meta: String = "modes = grub_stack", rows: PackedStringArray = ARENA_ROWS,
		legend: String = ARENA_LEGEND, entities: String = "") -> String:
	return "[meta]\nformat = 2\nid = %s\nkind = arena\nterrain_a = jungle/terrain_grass\nmusic = level_jungle\n" % id \
			+ "players = 4\n%s\n[legend]\n%s\n[tiles]\n%s\n[entities]\n%s\n" % [meta, legend, "\n".join(rows), entities]


## 40 x 16 cells: air, '@' at column 1 and an exit at column 38 on row 13, solid rows 14-15.
func _coop_rows() -> PackedStringArray:
	var rows: PackedStringArray = PackedStringArray()
	for row: int in COOP_ROWS:
		rows.append((TileGrid.CH_SOLID_A if row >= 14 else TileGrid.CH_AIR).repeat(COOP_COLS))
	rows[13] = ".@" + ".".repeat(COOP_COLS - 4) + "E."
	return rows


## Put `ch` into cells `from_col`..`to_col` of a row.
func _paint(rows: PackedStringArray, row: int, from_col: int, to_col: int, ch: String = "#") -> void:
	var line: String = rows[row]
	for col: int in range(from_col, to_col + 1):
		line = line.substr(0, col) + ch + line.substr(col + 1)
	rows[row] = line


func _coop_text(id: String, entities: String, rows: PackedStringArray = PackedStringArray(),
		coop_of: String = "solo_main") -> String:
	var tiles: PackedStringArray = rows if not rows.is_empty() else _coop_rows()
	return "[meta]\nformat = 2\nid = %s\nkind = coop\nbook = 2\nterrain_a = jungle/terrain_grass\n" % id \
			+ "music = level_jungle\ncoop_of = %s\ncoop_base_hash = %s\n[legend]\nE = objects/exit\n[tiles]\n%s\n" % [
			coop_of, "ab".repeat(32), "\n".join(tiles)] + "[entities]\n%s\n" % entities


func _solo(id: String, kind: String = "main") -> String:
	return _level(id).replace("kind = test", "kind = " + kind)


func test_traits_and_coop_only_enemies_only_in_coop_files() -> void:
	var cast: String = "enemies/walker 5 10 coop=shell\nenemies/shellback 8 10\nobjects/plate 10 10 name=p"
	var solo: LevelValidator = _validator({"solo_cast": _level("solo_cast", "", "", PLAIN_ROWS, cast)
			.replace("kind = test", "kind = main")})
	assert_true(solo.has_problem("'enemies/walker' coop=: co-op traits exist only in co-op files"), _messages(solo))
	assert_true(solo.has_problem("'enemies/shellback' is a co-op-only enemy"))
	assert_true(solo.has_problem("'objects/plate' is a co-op object in a solo file", LevelValidator.WARNING))
	var developer: LevelValidator = _validator({"dev_cast": _level("dev_cast", "", "", PLAIN_ROWS, cast)})
	assert_false(developer.has_problem("co-op traits exist only"), "developer levels may test traits")
	assert_false(developer.has_problem("co-op-only enemy"))
	var arena: LevelValidator = _validator({"arena_cast": _arena_text("arena_cast", "modes = grub_stack",
			ARENA_ROWS, ARENA_LEGEND, "enemies/walker 10 9 coop=lone")})
	assert_true(arena.has_problem("co-op traits exist only in co-op files"), "no traits in an arena")


func test_coop_base_hash_drift_warning() -> void:
	var solo_text: String = _solo("solo_main")
	var fresh: String = _coop_text("fresh_coop", "").replace("ab".repeat(32), solo_text.sha256_text())
	var stale: String = _coop_text("stale_coop", "")
	var validator: LevelValidator = _validator({"solo_main": solo_text, "fresh_coop": fresh, "stale_coop": stale})
	var fresh_problems: Array[Dictionary] = validator.problems_of("fresh_coop.lvl")
	for problem: Dictionary in fresh_problems:
		assert_false(str(problem["message"]).contains("changed since"), "the hash matches the solo text")
	assert_true(validator.has_problem("the solo file 'solo_main' changed since this co-op copy was made: review the "
			+ "copy, then set coop_base_hash = " + solo_text.sha256_text(), LevelValidator.WARNING), _messages(validator))
	var crlf: String = _coop_text("crlf_coop", "").replace("ab".repeat(32), solo_text.replace("\n", "\r\n")
			.sha256_text())
	var windows: LevelValidator = _validator({"solo_main": solo_text, "crlf_coop": crlf})
	assert_true(windows.has_problem("changed since", LevelValidator.WARNING), "a different text is a drift")


func test_x2_tablets_name_their_gate_and_a_far_cell() -> void:
	var entities: String = "\n".join(PackedStringArray([
		"objects/x2_tablet 5 13 gate=g1 far=20,13",
		"objects/x2_tablet 6 13 far=20,13",
		"objects/x2_tablet 7 13 gate=g2",
		"objects/x2_tablet 8 13 gate=g3 far=20,14",
		"objects/x2_tablet 9 13 gate=g1 far=21,13",
		"objects/x2_tablet 10 13 gate=g4 far=99,13",
		"objects/x2_tablet 11 13 secret far=22,13",
		"objects/x2_tablet 12 13 gate=g5 far=23,13 expert",
		"objects/x2_tablet 13 13 gate=g5 far=23,13 beginner",
	]))
	var validator: LevelValidator = _validator({"solo_main": _solo("solo_main"),
		"tablets_coop": _coop_text("tablets_coop", entities)})
	assert_true(validator.has_problem("objects/x2_tablet needs gate=<name> (or secret"), _messages(validator))
	assert_true(validator.has_problem("objects/x2_tablet needs far=c,r"))
	assert_true(validator.has_problem("far=20,14 must be an air cell above a floor"))
	assert_true(validator.has_problem("gate 'g1' has two x2 tablets in beginner"))
	assert_true(validator.has_problem("far=99,13 is outside the map"))
	assert_false(validator.has_problem("gate 'g5' has two"), "one tablet per difficulty")
	var tablet: Dictionary = LevelValidator.parse_tablet({"id": &"objects/x2_tablet", "col": 3.0, "row": 4.0,
		"params": {"gate": "hop", "far": "7,2"}, "line": 9})
	assert_eq(tablet["gate"], "hop")
	assert_eq(tablet["far"], Vector2i(7, 2))
	assert_eq(tablet["cell"], Vector2i(3, 4))
	assert_false(tablet["secret"])


func test_plates_name_mode_and_distance() -> void:
	assert_true(LevelValidator.is_plate_mode("hold"))
	assert_true(LevelValidator.is_plate_mode("latch"))
	assert_true(LevelValidator.is_plate_mode("timed:44"))
	assert_false(LevelValidator.is_plate_mode("timed:0"))
	assert_false(LevelValidator.is_plate_mode("timed:soon"))
	assert_false(LevelValidator.is_plate_mode("sometimes"))
	var entities: String = "\n".join(PackedStringArray([
		"objects/x2_tablet 4 13 gate=doors far=30,13",
		"objects/plate 2 13 name=near",
		"objects/column 6 13 size=1,3 rise_while=near",
		"objects/plate 10 13 name=far_away mode=timed:44",
		"objects/column 19 13 size=1,3 rise_while=far_away",
		"objects/plate 22 13 mode=sometimes",
		"objects/plate 24 13 name=lazy mode=timed:0",
		"objects/column 28 13 sink_while=ghost",
	]))
	var validator: LevelValidator = _validator({"solo_main": _solo("solo_main"),
		"plates_coop": _coop_text("plates_coop", entities)})
	assert_true(validator.has_problem("plate 'near' is 3 tiles from its door"), _messages(validator))
	assert_false(validator.has_problem("plate 'far_away' is"), "8 + tiles away")
	assert_true(validator.has_problem("objects/plate needs a name"))
	assert_true(validator.has_problem("objects/plate mode 'sometimes' must be hold, latch or timed:<ticks>"))
	assert_true(validator.has_problem("objects/plate mode 'timed:0'"))
	assert_true(validator.has_problem("plate 'lazy' drives no column", LevelValidator.WARNING))
	assert_true(validator.has_problem("column sink_while 'ghost' is not the name of an objects/plate"))


func test_keepers_drums_and_bonds_are_paired() -> void:
	var entities: String = "\n".join(PackedStringArray([
		"objects/x2_tablet 4 13 gate=all far=30,13",
		"objects/column 30 13 trigger=keepers:hall",
		"enemies/raptor 10 13 keeper=lonely coop=daze",
		"objects/drum 12 13 bond=solo_drum",
		"objects/column 31 13 trigger=drums:solo_drum",
		"objects/drum 14 13 bond=idle",
		"objects/drum 16 13 bond=idle",
		"objects/drum 18 13",
		"enemies/walker 20 13 coop=bond",
		"enemies/walker 22 13 coop=bond bond=single",
		"enemies/stinger 24 5 coop=grab",
		"enemies/walker 26 13 keeper=plain",
		"objects/column 32 13 trigger=keepers:plain",
	]))
	var validator: LevelValidator = _validator({"solo_main": _solo("solo_main"),
		"pairs_coop": _coop_text("pairs_coop", entities)})
	assert_true(validator.has_problem("keeper door 'keepers:hall' has no enemy with keeper=hall"), _messages(validator))
	assert_true(validator.has_problem("keeper=lonely: no objects/column trigger=keepers:lonely waits for it"))
	assert_true(validator.has_problem("drum bond 'solo_drum' needs two or more objects/drum"))
	assert_true(validator.has_problem("drum bond 'idle' opens nothing"))
	assert_true(validator.has_problem("objects/drum needs bond=<name>"))
	assert_true(validator.has_problem("'enemies/walker' coop=bond needs bond=<name>"))
	assert_true(validator.has_problem("bond 'single' has one member"))
	assert_true(validator.has_problem("'enemies/stinger' coop=grab needs perch=c,r"))
	assert_true(validator.has_problem("keeper 'plain' carries no shell, bond or daze trait", LevelValidator.WARNING))


func test_keeper_and_guard_halls_are_four_rows_high() -> void:
	var rows: PackedStringArray = _coop_rows()
	_paint(rows, 9, 10, 20)        # a 4-row hall (rows 10-13) over columns 10-20
	_paint(rows, 10, 24, 30)       # a 3-row hall (rows 11-13) over columns 24-30
	var entities: String = "\n".join(PackedStringArray([
		"objects/x2_tablet 4 13 gate=halls far=36,13",
		"enemies/shellback 15 13 left=-3 right=3",
		"enemies/raptor 27 13 keeper=low coop=daze",
		"objects/column 31 13 trigger=keepers:low",
		"enemies/guard 35 13 left=-2 right=2 coop=shell",
	]))
	var validator: LevelValidator = _validator({"solo_main": _solo("solo_main"),
		"halls_coop": _coop_text("halls_coop", entities, rows)})
	assert_false(validator.has_problem("hall of 'enemies/shellback'"), "4 rows: right")
	assert_true(validator.has_problem("the keeper hall of 'enemies/raptor' is 3 rows high"), _messages(validator))
	assert_true(validator.has_problem("the Guard hall of 'enemies/guard' is open to the sky"))
	assert_eq(LevelValidator.HALL_ROWS, 4, "the orchestrator's resolution: 4 rows (64 px)")
	var grid: TileGrid = TileGrid.from_rows(rows)
	assert_eq(LevelValidator.hall_height(grid, 15, 13), 4)
	assert_eq(LevelValidator.hall_height(grid, 27, 13), 3)
	assert_eq(LevelValidator.hall_height(grid, 35, 13), grid.rows + 1, "open sky")


func test_keepers_that_can_be_led_warn() -> void:
	# G66 (world-B's probe on w9_l1b_coop 'stormwall'): a keeper of an archetype that follows its target can be led.
	var rows: PackedStringArray = _coop_rows()
	_paint(rows, 9, 10, 30)
	var entities: String = "
".join(PackedStringArray([
		"objects/x2_tablet 4 13 gate=led far=36,13",
		"enemies/hopper 15 13 keeper=led coop=bond bond=led",
		"enemies/harrier 20 13 keeper=led coop=bond bond=led",
		"enemies/walker 25 13 left=0 right=0 keeper=led coop=bond bond=led",
		"enemies/hopper 28 13 coop=bond bond=free",
		"objects/column 31 13 trigger=keepers:led",
	]))
	var validator: LevelValidator = _validator({"solo_main": _solo("solo_main"),
		"led_coop": _coop_text("led_coop", entities, rows)})
	assert_true(validator.has_problem("'enemies/hopper' is a keeper ('led') that can be led", LevelValidator.WARNING),
			_messages(validator))
	assert_false(validator.has_problem("'enemies/harrier' is a keeper", LevelValidator.WARNING),
			"a keeper Harrier holds its perch (G66)")
	assert_false(validator.has_problem("'enemies/walker' is a keeper", LevelValidator.WARNING), "a walker stands")
	var count: int = 0
	for problem: Dictionary in validator.problems:
		count += 1 if str(problem["message"]).contains("that can be led") else 0
	assert_eq(count, 1, "only keepers: a bond member that opens no door is no gate")


func test_gate_count_by_the_kind_of_the_solo_stage() -> void:
	var one_gate: String = "objects/x2_tablet 4 13 gate=a far=30,13"
	var two_gates: String = one_gate + "\nobjects/x2_tablet 6 13 gate=b far=31,13\nobjects/x2_tablet 8 13 secret far=32,13"
	var boss: String = "zones/arena 20 5 name=den rect=0,0,40,16\nbosses/brute 20 13 arena=den"
	var validator: LevelValidator = _validator({
		"solo_main": _solo("solo_main"), "solo_sub": _solo("solo_sub", "sub"), "solo_bonus": _solo("solo_bonus", "bonus"),
		"main_one_coop": _coop_text("main_one_coop", one_gate),
		"main_two_coop": _coop_text("main_two_coop", two_gates),
		"sub_boss_coop": _coop_text("sub_boss_coop", boss, PackedStringArray(), "solo_sub"),
		"bonus_coop": _coop_text("bonus_coop", "", PackedStringArray(), "solo_bonus"),
	})
	assert_true(validator.has_problem("a co-op main stage needs 2 co-op gates (x2 tablets with gate=) in beginner; "
			+ "found 1"), _messages(validator))
	for path: String in ["main_two_coop.lvl", "sub_boss_coop.lvl", "bonus_coop.lvl"]:
		for problem: Dictionary in validator.problems_of(path):
			assert_false(str(problem["message"]).contains("co-op gates"), "%s: %s" % [path, problem["message"]])


func test_a_third_of_the_enemies_carry_a_trait() -> void:
	var plain: String = "enemies/walker 10 13\nenemies/walker 14 13\nenemies/walker 18 13"
	var mixed: String = "enemies/walker 10 13 coop=shell\nenemies/walker 14 13\nenemies/walker 18 13"
	var validator: LevelValidator = _validator({"solo_bonus": _solo("solo_bonus", "bonus"),
		"plain_coop": _coop_text("plain_coop", plain, PackedStringArray(), "solo_bonus"),
		"mixed_coop": _coop_text("mixed_coop", mixed, PackedStringArray(), "solo_bonus")})
	assert_true(validator.has_problem("0 of 3 enemy records carry a co-op trait in beginner"), _messages(validator))
	for problem: Dictionary in validator.problems_of("mixed_coop.lvl"):
		assert_false(str(problem["message"]).contains("carry a co-op trait"))


func test_static_reach_around_a_ledge_gate() -> void:
	var rows: PackedStringArray = _coop_rows()
	_paint(rows, 6, 6, 12)         # the boost ledge: far cell 8,5 stands on it
	var entities: String = "\n".join(PackedStringArray([
		"objects/x2_tablet 5 13 gate=hop far=8,5",
		"objects/spring 12 13",
		"enemies/walker 3 13 coop=shell",
		"objects/geyser 14 13 deadly",
		"objects/bark_board 17 10",
		"objects/hidden_spot 15 12",
		"objects/hidden_spot 15 13",
		"objects/spring 35 13",
	]))
	var validator: LevelValidator = _validator({"solo_bonus": _solo("solo_bonus", "bonus"),
		"reach_coop": _coop_text("reach_coop", entities, rows, "solo_bonus")})
	assert_true(validator.has_problem("'objects/spring' at 12,13 is within reach of the ledge of gate 'hop'"),
			_messages(validator))
	assert_true(validator.has_problem("'enemies/walker' at 3,13 is within reach of the ledge of gate 'hop'"))
	assert_false(validator.has_problem("'objects/geyser' at 14,13"), "a deadly vent lifts nobody")
	assert_false(validator.has_problem("'objects/spring' at 35,13"), "out of reach")
	assert_true(validator.has_problem("bark board at 17,10 is within 12 cells of gate 'hop'"))
	assert_true(validator.has_problem("hittables at 15,12 and 15,13 stack up near gate 'hop': a club pogo ladder"))


func test_mechanisms_belong_to_a_gate() -> void:
	var lonely: String = "objects/plate 2 13 name=p\nobjects/column 12 13 rise_while=p"
	var far_off: String = "objects/x2_tablet 2 13 gate=near far=3,13\nobjects/seesaw 36 13"
	var validator: LevelValidator = _validator({"solo_bonus": _solo("solo_bonus", "bonus"),
		"lonely_coop": _coop_text("lonely_coop", lonely, PackedStringArray(), "solo_bonus"),
		"faroff_coop": _coop_text("faroff_coop", far_off, PackedStringArray(), "solo_bonus")})
	assert_true(validator.has_problem("'objects/plate' is a co-op mechanism but the file has no objects/x2_tablet"),
			_messages(validator))
	assert_true(validator.has_problem("'objects/seesaw' at 36,13 belongs to no x2 tablet's gate",
			LevelValidator.WARNING))


func test_a_good_arena_is_valid() -> void:
	var validator: LevelValidator = _validator({"arena_good": _arena_text("arena_good",
			"modes = grub_stack,hot_rock\nwrap = lr\nsudden = stampede")})
	assert_eq(validator.error_count(), 0, _messages(validator))
	assert_false(validator.has_problem("unknown parameter 'team'", LevelValidator.WARNING), "a team pot")


func test_arena_rules() -> void:
	var rows: PackedStringArray = ARENA_ROWS.duplicate()
	rows[1] = "....###............."      # something to stand on in the HUD row
	rows[10] = ".##?###?####?###?##."     # the floor does not continue across the lr seam
	var broken: String = _arena_text("arena_broken", "modes = grub_stack,clubball\nwrap = lr", rows,
			ARENA_LEGEND.replace("D = objects/spawn_point index=4\n", "").replace("Q = objects/cookpot team=1\n", ""),
			"objects/exit 10 9\nzones/goal 0 7 rect=0,6,1,4 team=1")
	var validator: LevelValidator = _validator({"arena_broken": broken})
	for fragment: String in ["row 1 of an arena holds a floor at column 4",
			"the arena is for 4 players but has no objects/spawn_point index=4",
			"Grub Stack needs 2 objects/cookpot on a 4-player arena; found 1",
			"Clubball needs an objects/coconut", "Clubball needs a zones/goal team=2", "a goal mouth is 3 rows high",
			"'objects/exit' has no place in an arena", "wrap = lr: the floor (row 10) must continue across the seam"]:
		assert_true(validator.has_problem(fragment), "%s\n%s" % [fragment, _messages(validator)])
	var small: PackedStringArray = PackedStringArray()
	for row: String in ARENA_ROWS:
		small.append(row + "#")
	var wide: LevelValidator = _validator({"arena_wide": _arena_text("arena_wide", "modes = hot_rock", small)})
	assert_true(wide.has_problem("an arena is 20 x 12 cells"), _messages(wide))
	var gappy_rows: PackedStringArray = ARENA_ROWS.duplicate()
	gappy_rows[7] = "-..................-"
	gappy_rows[10] = "####################"
	var gappy: LevelValidator = _validator({"arena_gappy": _arena_text("arena_gappy", "modes = hot_rock",
			gappy_rows)})
	assert_true(gappy.has_problem("a clear gap of 18 cells in row 7", LevelValidator.WARNING), _messages(gappy))
	assert_true(gappy.has_problem("0 hidden spots: an arena has 4-8 visible ones", LevelValidator.WARNING))


# =================================================================================================================
# The solo-impossibility search (scripts/world/coop_search.gd, PLAN.md P1.7 v1; tests/test_coop_gates.gd uses it)
# =================================================================================================================

## A 30 x 16 co-op map: floor rows 14-15, '@' at column 1, an exit at column 28; `ledge_row` puts a 7-cell
## one-cell-thick ledge (columns 14-20) whose top is that row.
func _search_level(id: String, ledge_row: int, entities: String) -> LevelData:
	var rows: PackedStringArray = PackedStringArray()
	for row: int in 16:
		rows.append((TileGrid.CH_SOLID_A if row >= 14 else TileGrid.CH_AIR).repeat(30))
	rows[13] = ".@" + ".".repeat(26) + "E."
	_paint(rows, ledge_row, 14, 20)
	var text: String = "[meta]\nformat = 2\nid = %s\nkind = coop\nbook = 2\nterrain_a = jungle/terrain_grass\n" % id \
			+ "music = level_jungle\ncoop_of = solo_bonus\ncoop_base_hash = %s\n[legend]\nE = objects/exit\n" % "ab".repeat(32) \
			+ "[tiles]\n%s\n[entities]\n%s\n" % ["\n".join(rows), entities]
	return LevelData.parse(StringName(id), text, "%s.lvl" % id)



## A 30 x 16 co-op map from `rows` (16 strings of 30 cells; '@' and the exit are added at row 13).
func _search_rows(id: String, rows: PackedStringArray, entities: String) -> LevelData:
	rows[13] = ".@" + rows[13].substr(2, 26) + "E."
	var text: String = "[meta]
format = 2
id = %s
kind = coop
book = 2
terrain_a = jungle/terrain_grass
" % id 			+ "music = level_jungle
coop_of = solo_bonus
coop_base_hash = %s
[legend]
E = objects/exit
" % "ab".repeat(32) 			+ "[tiles]
%s
[entities]
%s
" % ["
".join(rows), entities]
	return LevelData.parse(StringName(id), text, "%s.lvl" % id)


## The plate-door map: a wall at column 22 from row 2 down to the floor, its two bottom cells a door that rises into
## the wall while plate `p` (columns 10-11, 12 tiles away) is pressed; the far cell 25,13 lies behind it.
func _door_level(id: String, mode: String) -> LevelData:
	var rows: PackedStringArray = PackedStringArray()
	for row: int in 16:
		rows.append((TileGrid.CH_SOLID_A if row >= 14 else TileGrid.CH_AIR).repeat(30))
	for row: int in range(2, 14):
		_paint(rows, row, 22, 22)
	return _search_rows(id, rows, "
".join(PackedStringArray([
		"objects/x2_tablet 6 13 gate=door far=25,13",
		"objects/plate 10 13 name=p mode=%s" % mode,
		"objects/column 22 13 size=1,2 rise=2 rise_while=p",
	])))

func test_search_refuses_a_high_ledge_and_finds_a_low_one() -> void:
	var high: Dictionary = CoopSearch.search_data(_search_level("high_coop", 6, "objects/x2_tablet 10 13 gate=hop far=16,5"),
			Defs.Difficulty.BEGINNER, "hop")
	assert_false(bool(high["reached"]), "8 rows: no single hero gets up there (%s)" % high["detail"])
	# The flood diagnostic agrees (no chain of feet cells climbs 8 rows), but it decides nothing since v2: the
	# refusal is the search's own.
	assert_false(bool(high["flood"]), "the flood finds no chain either")
	assert_true(int(high["explored"]) > 10, "the floor was searched (%d resting points)" % int(high["explored"]))
	assert_true(int(high["runs"]) > 100, "with real runs of the hero (%d)" % int(high["runs"]))
	assert_eq(high["bound"], CoopSearch.BOUND_TICKS)
	assert_true((high["starts"] as Array).has(Vector2i(10, 13)), "it starts at the tablet")
	assert_true((high["starts"] as Array).has(Vector2i(1, 13)), "and at the start before it (no checkpoint)")
	var low: Dictionary = CoopSearch.search_data(_search_level("low_coop", 11, "objects/x2_tablet 10 13 gate=hop far=16,10"),
			Defs.Difficulty.BEGINNER, "hop")
	assert_true(bool(low["reached"]), "3 rows: a plain jump")
	assert_true(str(low["detail"]).contains("one hero reached 16,10"), str(low["detail"]))
	assert_null(Game.level, "the search level is gone again")


func test_search_reports_a_broken_static_rule_and_unknown_gates() -> void:
	var sprung: Dictionary = CoopSearch.search_data(_search_level("sprung_coop", 6,
			"objects/x2_tablet 10 13 gate=hop far=16,5\nobjects/spring 12 13"), Defs.Difficulty.BEGINNER, "hop")
	assert_true(bool(sprung["reached"]))
	assert_true(str(sprung["detail"]).begins_with("static rule: 'objects/spring' at 12,13"), str(sprung["detail"]))
	var missing: Dictionary = CoopSearch.search_data(_search_level("missing_coop", 6, ""), Defs.Difficulty.BEGINNER, "hop")
	assert_true(bool(missing["reached"]), "a gate that cannot be searched is not proven")
	assert_true(str(missing["detail"]).begins_with("unproven"))
	var unread: Dictionary = CoopSearch.search_gate(&"no_such_level_coop", Defs.Difficulty.BEGINNER, "hop")
	assert_true(bool(unread["reached"]))


func test_search_measures_the_windows_near_the_gate() -> void:
	var entities: String = "\n".join(PackedStringArray([
		"objects/x2_tablet 10 13 gate=drums far=27,13",
		"objects/drum 6 12 bond=twin",
		"objects/drum 9 12 bond=twin",
		"objects/column 25 13 trigger=drums:twin",
		"enemies/raptor 4 13 coop=daze",
	]))
	var result: Dictionary = CoopSearch.search_data(_search_level("windows_coop", 6, entities),
			Defs.Difficulty.EXPERT, "drums")
	var drums: Dictionary = {}
	var daze: Dictionary = {}
	for window: Dictionary in result["windows"]:
		if str(window["what"]).begins_with("drums twin"):
			drums = window
		elif str(window["what"]).begins_with("daze enemies/raptor"):
			daze = window
	assert_true(bool(result["reached"]), "a level gate on open floor (the windows are measured anyway)")
	assert_false(drums.is_empty(), "%s %s" % [str(result["windows"]), result["detail"]])
	assert_eq(int(drums["window"]), PartyTuning.WINDOW_TICKS_EXPERT)
	assert_eq(int(drums["solo_min"]), 0, "three cells apart: an axe from beside one crosses the other")
	assert_false(daze.is_empty(), str(result["windows"]))
	assert_eq(int(daze["window"]), PartyTuning.DAZE_TICKS_EXPERT)
	var measured: int = int(daze["solo_min"])
	assert_true(measured >= 2 and measured <= 30, "bounce to first hit of the real hero: %d ticks" % measured)
	assert_eq(CoopSearch.measure_daze_solo_min("enemies/raptor"), measured, "measured once per box")


func test_search_helpers() -> void:
	var macros: Array[Dictionary] = CoopSearch.make_macros()
	assert_true(macros.size() >= 16, "walks, jumps, hops, running jumps, drift-backs, crawls, both ways")
	var names: PackedStringArray = PackedStringArray()
	for macro: Dictionary in macros:
		names.append(str(macro["name"]))
	assert_true(names.has("run-jump R") and names.has("run-jump L"))
	assert_eq(CoopSearch.node_key(Vector2i(17, 224)), CoopSearch.node_key(Vector2i(23, 224)))
	var data: LevelData = _search_level("helper_coop", 6, "objects/column 3 12 size=2,1 rise=0 expert\n"
			+ "objects/x2_tablet 10 13 gate=g far=16,5")
	var expert: TileGrid = CoopSearch.grid_at_rest(data, Defs.Difficulty.EXPERT)
	var beginner: TileGrid = CoopSearch.grid_at_rest(data, Defs.Difficulty.BEGINNER)
	assert_eq(expert.get_char(4, 12), TileGrid.CH_SOLID_A, "the Expert-only static block (R18)")
	assert_eq(beginner.get_char(4, 12), TileGrid.CH_AIR)
	var tablet: Dictionary = CoopSearch.find_tablet(data, Defs.Difficulty.BEGINNER, "g")
	assert_eq(tablet["far"], Vector2i(16, 5))
	assert_eq(CoopSearch.gate_area(tablet, beginner), Rect2i(0, 0, 30, 16), "one view around tablet and far cell")
	assert_true(CoopSearch.throw_crosses([Vector2i(56, 224)] as Array[Vector2i], Vector2i(12, 13)))
	assert_false(CoopSearch.throw_crosses([Vector2i(56, 224)] as Array[Vector2i], Vector2i(4, 2)),
			"nothing thrown reaches a cell high up behind the thrower")
	# Bond members far apart: the lower bound decides without a search (D5's 731 s bond).
	assert_eq(CoopSearch.pair_lower_bound(Vector2i(4, 13), Vector2i(84, 13)), (80 - 4) * Tuning.TILE / 6)
	assert_eq(CoopSearch.pair_solo_min(Vector2i(4, 13), Vector2i(84, 13), expert, Rect2i(0, 0, 30, 16), null),
			CoopSearch.pair_lower_bound(Vector2i(4, 13), Vector2i(84, 13)), "no search for members 80 columns apart")


func test_search_world_runs_the_real_doors_and_carries_a_latched_plate() -> void:
	# One player alone (his partner only ever an egg): a held plate 12 tiles from its door shuts it before he gets
	# there; the search ran the real plate and door to say so.
	CoopSearch.idle_partner = false
	var held: Dictionary = CoopSearch.search_data(_door_level("door_hold_coop", "hold"), Defs.Difficulty.BEGINNER, "door")
	CoopSearch.idle_partner = true
	assert_false(bool(held["reached"]), "the door shuts before one hero gets there (%s)" % held["detail"])
	assert_false(bool(held["flood"]), "the flood sees only the closed door")
	assert_true(int(held["explored"]) > 5, "the refusal is the search's own (%d resting points)" % int(held["explored"]))
	# A latch stays down: the changed world (plate pressed, door up) is carried to the next move by its replay.
	var latched: Dictionary = CoopSearch.search_data(_door_level("door_latch_coop", "latch"), Defs.Difficulty.BEGINNER,
			"door")
	assert_true(bool(latched["reached"]), "a latch stays down: the door stays open for the next move")
	assert_true(str(latched["detail"]).contains("one hero reached 25,13"), str(latched["detail"]))
	assert_null(Game.level, "the search world is gone again")
	assert_eq(Game.mode, Defs.GameMode.SINGLE, "the co-op game of the search is put back")


func test_search_windows_report_the_records_caps() -> void:
	var entities: String = "
".join(PackedStringArray([
		"objects/x2_tablet 10 13 gate=g far=27,13",
		"enemies/walker 4 13 coop=bond bond=pair window=20",
		"enemies/walker 24 13 coop=bond bond=pair window=9",
		"enemies/walker 12 13 coop=bond bond=wide",
		"enemies/walker 26 13 coop=bond bond=wide",
		"enemies/raptor 6 13 coop=daze window=5",
	]))
	var data: LevelData = _search_level("caps_coop", 6, entities)
	CoopSearch.measure_daze_solo_min("enemies/raptor")
	CoopSearch.daze_slot_bound()   # the engine probe builds a world of its own: before the bare searcher (no nesting)
	var bare: CoopSearch.Searcher = CoopSearch.Searcher.new()
	assert_true(bare.build(data.id, data.resolved_meta(Defs.Difficulty.BEGINNER), CoopSearch.grid_at_rest(data,
			Defs.Difficulty.BEGINNER)))
	var windows: Array = CoopSearch.measure_windows(data, Defs.Difficulty.BEGINNER, Rect2i(0, 0, 30, 16), bare)
	bare.close()
	var by_what: Dictionary = {}
	for window: Dictionary in windows:
		by_what[str(window["what"]).get_slice(" at ", 0).get_slice(" (", 0)] = int(window["window"])
	assert_eq(by_what.get("bond pair", -1), 9, "a bond: the smallest window= of its members (%s)" % str(windows))
	assert_eq(by_what.get("bond wide", -1), PartyTuning.window_ticks(Defs.Difficulty.BEGINNER), "no cap: the difficulty's")
	assert_eq(by_what.get("daze enemies/raptor", -1), 5, "a daze record: its own window=")
	for window: Dictionary in windows:
		# G47: the daze record is slot-bound exactly when the engine binds the daze to the other slot; bonds never are.
		var daze: bool = str(window["what"]).begins_with("daze ")
		assert_eq(bool(window.get("slot_bound", false)), daze and CoopSearch.daze_slot_bound(), str(window))
	var validator: LevelValidator = _validator({"solo_bonus": _solo("solo_bonus", "bonus"), "capped_coop":
			_coop_text("capped_coop", "enemies/walker 3 13 coop=bond bond=b window=x
enemies/walker 9 13 coop=bond bond=b window=12",
			PackedStringArray(), "solo_bonus")})
	assert_false(validator.has_problem("unknown parameter 'window'", LevelValidator.WARNING), _messages(validator))
	assert_true(validator.has_problem("enemies/walker window"), "an integer: %s" % _messages(validator))


# =================================================================================================================
# Phase 3 (world-B): the IDLE partner of the search (G33), bonded pairs (G36), lee gaps (G41), arena signatures (G43)
# =================================================================================================================

## A 30 x 16 search map like [method _search_level] with extra meta lines (`meta`).
func _search_level_meta(id: String, ledge_row: int, entities: String, meta: String) -> LevelData:
	var rows: PackedStringArray = PackedStringArray()
	for row: int in 16:
		rows.append((TileGrid.CH_SOLID_A if row >= 14 else TileGrid.CH_AIR).repeat(30))
	rows[13] = ".@" + ".".repeat(26) + "E."
	_paint(rows, ledge_row, 14, 20)
	var text: String = "[meta]\nformat = 2\nid = %s\nkind = coop\nbook = 2\nterrain_a = jungle/terrain_grass\n" % id \
			+ "music = level_jungle\ncoop_of = solo_bonus\ncoop_base_hash = %s\n%s\n" % ["ab".repeat(32), meta] \
			+ "[legend]\nE = objects/exit\n[tiles]\n%s\n[entities]\n%s\n" % ["\n".join(rows), entities]
	return LevelData.parse(StringName(id), text, "%s.lvl" % id)


## A search world of `data` (Beginner, every column) for direct runs; close it after use.
func _search_world(data: LevelData) -> CoopSearch.Searcher:
	var searcher: CoopSearch.Searcher = CoopSearch.Searcher.new()
	assert_true(searcher.build_world(data, Defs.Difficulty.BEGINNER, CoopSearch.grid_at_rest(data,
			Defs.Difficulty.BEGINNER), Vector2i(0, data.cols)), "the search world builds")
	return searcher


func _config(start: Vector2i, partner_mode: int = CoopSearch.PARTNER_EGG, partner_at: Vector2i = CoopSearch.NOWHERE,
		hand: int = -1) -> Dictionary:
	return {"start": start, "facing": 1, "hand": hand, "partner": partner_mode, "partner_at": partner_at}


func test_search_partner_is_idle_and_parked_anywhere_counts_for_nothing() -> void:
	# G33: the lone player's partner never pressed anything - IDLE from his first tick, whether an egg or hatched
	# and parked; the lone hero is not. Parked on the plate of a held door, he does not press it.
	var data: LevelData = _door_level("door_probe_coop", "hold")
	var searcher: CoopSearch.Searcher = _search_world(data)
	var plate: SimEntity = null
	var spawned: PackedStringArray = PackedStringArray()
	for i: int in searcher._entities.size():
		var entity: SimEntity = searcher._entities[i]
		spawned.append("%s=%s" % [searcher._records[i]["id"], entity.get_script().resource_path if entity != null
				else "null"])
		if String(searcher._records[i]["id"]) == "objects/plate":
			plate = entity
	var on_plate: Vector2i = Vector2i(10 * Tuning.TILE + 12, 14 * Tuning.TILE)
	var outcome: Dictionary = searcher.run(_config(Vector2i(40, 224), CoopSearch.PARTNER_EGG, on_plate),
			PackedInt32Array([0, 0, 0, 0, 0, 0]), {})
	var partner_idle: bool = searcher.partner.is_idle()
	var partner_counts: bool = searcher.partner.counts_for_coop()
	var hero_idle: bool = searcher.hero.is_idle()
	var partner_at: Vector2i = searcher.partner.sim_pos
	var plate_found: bool = plate != null
	var pressed: bool = bool(plate.get(&"pressed")) if plate_found else true
	searcher.close()   # (frees the world: the plate reads null from here on)
	assert_false(outcome.is_empty(), "the hero stood still")
	assert_true(partner_idle, "the search world's partner is IDLE (PlayerBase.is_idle)")
	assert_false(partner_counts, "he counts for no co-op rule")
	assert_false(hero_idle, "the lone hero is active")
	assert_eq(partner_at, on_plate, "parked where the lone player hatched him")
	assert_true(plate_found, "the plate is in the search world: %s" % ", ".join(spawned))
	assert_false(pressed, "an idle partner weighs nothing on a plate (G33)")
	# The whole search: the held plate door 12 tiles from its plate stays shut for one player even with his partner
	# parked anywhere near it (the search parks him and finds nothing).
	CoopSearch.node_limit = 90
	var held: Dictionary = CoopSearch.search_data(_door_level("door_idle_coop", "hold"), Defs.Difficulty.BEGINNER,
			"door")
	CoopSearch.node_limit = CoopSearch.MAX_NODES
	assert_false(bool(held["reached"]), "one player and his idle partner: %s" % held["detail"])
	# The search parks the idle partner at a mechanism as a node of its own only while the engine weighs an idle hero
	# on a plate (CoopSearch.idle_partner_weighs: the regression probe of G33 - since G33 it does not, and those
	# nodes only copied the graph); the idle-bait probes put him on the plate and in the door's way all the same.
	assert_eq(int(held.get("placements", 0)) > 0, CoopSearch.idle_partner_weighs(),
			"parked nodes at the plate exactly while an idle hero weighs on one (%d nodes)" % int(held.get("placements", 0)))
	assert_true(int(held["probes"][CoopSearch.PROBE_IDLE_BAIT]["runs"]) > 0,
			"the idle-bait probes ran with him on the plate and at the door: %s" % str(held["probes"]))


func test_search_rides_on_an_idle_partner_only_as_the_engine_allows() -> void:
	# The `partner` ride macros stay as a regression check (G33): the search reaches the 6-row ledge through them
	# exactly when the engine still lets a hero ride an idle head (a Totem Ride starts and he rests on it).
	var probe: CoopSearch.Searcher = _search_world(_search_level("ride_probe_coop", 6, ""))
	var rest: Dictionary = probe.run(_config(Vector2i(40, 224), CoopSearch.PARTNER_IDLE),
			CoopSearch._repeat(Defs.IN_UP, 9) + CoopSearch._repeat(0, 16), {})
	var rides: bool = probe.hero.is_riding_totem()
	probe.close()
	if rides:
		assert_true(rest.is_empty(), "a rest on the partner's head is no node (the ride macros play the jump off)")
	# A 7-row ledge: one row over what a lone hero's hop jump reaches (wf10: 5 and 6 rows fall to it, see
	# test_search_hop_jump_reaches_six_rows_not_seven), under the 98 px step of a ride.
	CoopSearch.node_limit = 90
	var totem: Dictionary = CoopSearch.search_data(_search_level("totem_coop", 7,
			"objects/x2_tablet 10 13 gate=totem far=16,6"), Defs.Difficulty.BEGINNER, "totem")
	CoopSearch.node_limit = CoopSearch.MAX_NODES
	if rides:
		assert_true(bool(totem["reached"]), "7 rows: a ride on the idle partner")
		assert_true(str(totem["detail"]).contains("partner-"), str(totem["detail"]))
	else:
		assert_false(bool(totem["reached"]), "G33: an idle head carries no Totem Ride - %s" % totem["detail"])
	CoopSearch.idle_partner = false
	CoopSearch.node_limit = 90
	var alone: Dictionary = CoopSearch.search_data(_search_level("totem_coop", 7,
			"objects/x2_tablet 10 13 gate=totem far=16,6"), Defs.Difficulty.BEGINNER, "totem")
	CoopSearch.node_limit = CoopSearch.MAX_NODES
	CoopSearch.idle_partner = true
	assert_false(bool(alone["reached"]), "7 rows alone, the partner an egg (-64): %s" % alone["detail"])


func test_search_hand_is_no_world_change_and_the_wind_blows() -> void:
	# The special in his hand is a free choice per move (every belt special of the reference hero): a throw that
	# hits nothing leaves the world signature as it was, so it costs no replay.
	var searcher: CoopSearch.Searcher = _search_world(_search_level("throw_probe_coop", 6, ""))
	var thrown: Dictionary = searcher.run(_config(Vector2i(40, 224), CoopSearch.PARTNER_EGG, CoopSearch.NOWHERE,
			Defs.Weapon.AXE), CoopSearch._repeat(Defs.IN_RIGHT, 1) + CoopSearch._repeat(Defs.IN_FIRE, 6)
			+ CoopSearch._repeat(0, 24), {})
	var baseline: String = searcher._baseline
	searcher.close()
	assert_false(thrown.is_empty())
	assert_eq(str(thrown.get("sig", "")), baseline, "an axe thrown at nothing changes nothing")
	assert_false(baseline.contains("hand:"), "the hand is not part of the world")
	# The level's wind runs in the search world (Level's script: an entry t:v is the wind from tick t on).
	var windy: CoopSearch.Searcher = _search_world(_search_level_meta("windy_coop", 6, "", "wind = 0:0,20:24"))
	windy.run(_config(Vector2i(40, 224)), CoopSearch._repeat(0, 30), {})
	var late: int = windy.level.wind
	windy.close()
	assert_eq(late, 24, "the gust of tick 20 blows in the search world")


func test_search_result_file_cache_round_trip() -> void:
	var data: LevelData = _search_level("cache_probe_coop", 6, "objects/x2_tablet 10 13 gate=hop far=16,5")
	var path: String = "res://levels/w5_l1_coop.lvl"
	var key_b: String = CoopSearch.file_cache_key(path, data, Defs.Difficulty.BEGINNER, "hop")
	var key_e: String = CoopSearch.file_cache_key(path, data, Defs.Difficulty.EXPERT, "hop")
	var key_g: String = CoopSearch.file_cache_key(path, data, Defs.Difficulty.BEGINNER, "x")
	assert_ne(key_b, key_e, "the difficulty is part of the key")
	assert_ne(key_b, key_g, "and the gate")
	assert_eq(key_b, CoopSearch.file_cache_key(path, data, Defs.Difficulty.BEGINNER, "hop"))
	assert_eq(CoopSearch.code_fingerprint().length(), 32, "an md5 of the simulation's files")
	var result: Dictionary = {"reached": false, "bound": CoopSearch.BOUND_TICKS, "detail": "", "explored": 220,
		"runs": 5000, "starts": [Vector2i(10, 13)], "windows": [{"what": "bond b", "window": 24, "solo_min": 40}]}
	var key: String = "test_" + key_b
	CoopSearch._file_cache_write(key, result)
	var back: Dictionary = CoopSearch._file_cache_read(key)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(CoopSearch.FILE_CACHE_DIR.path_join(key + ".json")))
	assert_true(bool(back.get("cached", false)))
	assert_false(bool(back["reached"]))
	assert_eq(back["starts"], [Vector2i(10, 13)])
	assert_eq(int(back["explored"]), 220)
	assert_eq(back["windows"], [{"what": "bond b", "window": 24, "solo_min": 40}])
	assert_true(CoopSearch._file_cache_read("no_such_key").is_empty())


func test_search_gate_table_and_shards_partition_it() -> void:
	var table: Array[Dictionary] = CoopSearch.gate_table()
	var seen: Dictionary = {}
	for shard: int in 3:
		for entry: Dictionary in CoopSearch.shard_gates(table, shard, 3):
			var label: String = "%s:%d:%s" % [entry["level"], int(entry["difficulty"]), entry["gate"]]
			assert_false(seen.has(label), "%s in one shard only" % label)
			seen[label] = true
	assert_eq(seen.size(), table.size(), "the shards together hold every gate")
	for entry: Dictionary in table:
		assert_true(String(entry["level"]).ends_with("_coop"), str(entry))
		assert_ne(entry["far"], Vector2i(-1, -1), "%s names its far cell" % str(entry))


func test_bonded_pairs_one_throw_hits_are_errors() -> void:
	var entities: String = "\n".join(PackedStringArray([
		"objects/x2_tablet 4 13 gate=drums far=36,13",
		"objects/drum 8 12 bond=near",
		"objects/drum 11 12 bond=near",
		"objects/column 36 13 trigger=drums:near",
		"enemies/walker 6 13 coop=bond bond=row",
		"enemies/walker 16 13 coop=bond bond=row",
		"enemies/walker 14 13 coop=bond bond=apart",
		"enemies/walker 20 2 coop=bond bond=apart",
	]))
	var validator: LevelValidator = _validator({"solo_main": _solo("solo_main"),
		"bonded_coop": _coop_text("bonded_coop", entities)})
	assert_true(validator.has_problem("drum bond 'near' (beginner): one thrown special"), _messages(validator))
	assert_true(validator.has_problem("bond 'row' (expert): one thrown special"), "a spear flies far along one row")
	assert_false(validator.has_problem("bond 'apart'"), "no throw line from the floor reaches 11 rows up")


func test_lee_gap_without_a_crouching_spot_warns() -> void:
	var rows: PackedStringArray = _coop_rows()
	_paint(rows, 14, 10, 11, ".")      # a 2-cell gap with floor on both sides
	_paint(rows, 15, 10, 11, ".")
	_paint(rows, 14, 20, 21, ".")      # a 2-cell gap whose right (upwind) side is a wall
	_paint(rows, 15, 20, 21, ".")
	for row: int in range(6, 14):
		_paint(rows, row, 22, 22)
	var windy: String = _coop_text("lee_coop", "", rows).replace("music = level_jungle",
			"music = level_jungle\nwind = 0:24")
	var validator: LevelValidator = _validator({"solo_main": _solo("solo_main"), "lee_coop": windy})
	assert_true(validator.has_problem("gust gap at columns 20-21 over row 14", LevelValidator.WARNING),
			_messages(validator))
	assert_false(validator.has_problem("gust gap at columns 10-11", LevelValidator.WARNING), "a crouching spot there")
	var calm: LevelValidator = _validator({"solo_main": _solo("solo_main"), "calm_coop": _coop_text("calm_coop", "",
			rows)})
	assert_false(calm.has_problem("gust gap", LevelValidator.WARNING), "no wind, no gust gap")


func test_arena_signature_keys_colossus_and_kid_safe_syrup() -> void:
	var good: LevelValidator = _validator({"arena_sig": _arena_text("arena_sig",
			"modes = grub_stack\ndark_pulse = 486\nregrow = 364\nember_lane = 8,4,66", ARENA_ROWS, ARENA_LEGEND,
			"bosses/colossus 19 9\nenemies/dangler 10 2")})
	assert_eq(good.error_count(), 0, _messages(good))
	assert_false(good.has_problem("unknown meta key", LevelValidator.WARNING), _messages(good))
	var bad: LevelValidator = _validator({"arena_bad": _arena_text("arena_bad",
			"modes = grub_stack\ndark_pulse = 40:50\nregrow = 0\nember_lane = 18,4", ARENA_ROWS, ARENA_LEGEND,
			"bosses/colossus 19 9\nbosses/colossus 0 9\nbosses/brute 10 9")})
	for fragment: String in ["dark_pulse = 40:50 must be", "regrow = 0 must be", "ember_lane = 18,4 must be",
			"an arena holds one neutral bosses/colossus", "'bosses/brute' has no place in an arena"]:
		assert_true(bad.has_problem(fragment), "%s\n%s" % [fragment, _messages(bad)])
	var outside: LevelValidator = _validator({"pulse_level": _level("pulse_level", "dark_pulse = 486")})
	assert_true(outside.has_problem("only an arena (kind = arena) runs it", LevelValidator.WARNING), _messages(outside))
	var rows: PackedStringArray = ARENA_ROWS.duplicate()
	rows[10] = "###?###~####?###?###"
	var syrup: LevelValidator = _validator({"arena_syrup": _arena_text("arena_syrup",
			"modes = hot_rock\nsudden = syrup_flood", rows)})
	assert_true(syrup.has_problem("sudden = syrup_flood (kid-safe, no deaths): '~'", LevelValidator.WARNING),
			_messages(syrup))


func test_arena_gap_rule_counts_platforms_and_planks() -> void:
	# DA's Tar Pulleys (wf9 #2): two lifts bridge the row of the side ledges.
	var rows: PackedStringArray = ARENA_ROWS.duplicate()
	rows[6] = "##?...L......R...?##"
	var legend: String = ARENA_LEGEND + "L = objects/platform name=lift_l mode=ride\nR = objects/platform name=lift_r mode=ride\n"
	var lifts: LevelValidator = _validator({"arena_lifts": _arena_text("arena_lifts", "modes = grub_stack", rows,
			legend)})
	assert_false(lifts.has_problem("a clear gap of", LevelValidator.WARNING), _messages(lifts))
	var bare_rows: PackedStringArray = rows.duplicate()
	bare_rows[6] = "##?..............?##"
	var bare: LevelValidator = _validator({"arena_bare": _arena_text("arena_bare", "modes = grub_stack", bare_rows)})
	assert_true(bare.has_problem("a clear gap of 14 cells in row 6", LevelValidator.WARNING), _messages(bare))


func test_search_engine_probes_daze_and_ride() -> void:
	# G47: the probe dazes a still `coop=daze` target with a real head bounce (the other slot's hit is accepted: the
	# control) and reads whether the bouncer's own hit glances - slot-bound exactly then.
	var probe: Dictionary = CoopSearch.probe_daze()
	assert_true(bool(probe["dazed"]), "the probe's head bounce dazes the target: %s" % str(probe))
	assert_true(bool(probe["other"]), "a hero of the other slot may hurt it while it is dazed: %s" % str(probe))
	assert_eq(CoopSearch.daze_slot_bound(), not bool(probe["own"]), "slot-bound = the bouncer's own hit glances")
	assert_null(Game.level, "the probe's world is gone again")
	assert_eq(Game.mode, Defs.GameMode.SINGLE, "and the co-op game of two put back")
	# G33: the ride probe agrees with a direct run, and the partner ride macros follow it (the probe first: it builds a
	# world of its own).
	var carries: bool = CoopSearch.idle_partner_carries()
	var direct: CoopSearch.Searcher = _search_world(_search_level("ride_probe_direct_coop", 6, ""))
	direct.run(_config(Vector2i(10 * Tuning.TILE + 8, 224), CoopSearch.PARTNER_IDLE),
			CoopSearch._repeat(Defs.IN_UP, 9) + CoopSearch._repeat(0, 16), {})
	var rides: bool = direct.hero.is_riding_totem()
	var ride_macro: Dictionary = {}
	for macro: Dictionary in direct.macros:
		if str(macro["kind"]) == "partner":
			ride_macro = macro
	var fits: bool = direct._macro_fits(ride_macro, {"pos": Vector2i(10 * Tuning.TILE + 8, 224),
		"prefix": PackedInt32Array()})
	direct.close()
	assert_eq(carries, rides, "the probe = the engine (a ride on an idle head: %s)" % rides)
	assert_false(ride_macro.is_empty(), "the ride macros are still made (the regression check)")
	assert_eq(fits, rides, "and run exactly while a ride on an idle head is possible")


func test_search_strikes_and_throws_face_their_targets() -> void:
	var searcher: CoopSearch.Searcher = _search_world(_search_level("facing_coop", 6, "enemies/walker 20 13"))
	var walker: Vector2i = searcher._targets[0]
	var left_of: Vector2i = walker - Vector2i(5 * Tuning.TILE, 0)
	var on_it: Vector2i = walker + Vector2i(Tuning.TILE, 0)
	var strike_r: bool = searcher.target_near(left_of, CoopSearch.STRIKE_REACH_CELLS, 1)
	var strike_l: bool = searcher.target_near(left_of, CoopSearch.STRIKE_REACH_CELLS, -1)
	var close_l: bool = searcher.target_near(on_it, CoopSearch.STRIKE_REACH_CELLS, 1)
	var either: bool = searcher.target_near(left_of, CoopSearch.STRIKE_REACH_CELLS)
	searcher.close()
	assert_true(strike_r, "a target 5 cells ahead: the strikes facing it run")
	assert_false(strike_l, "facing away from it they do not")
	assert_true(close_l, "a target within BEHIND_REACH_PX behind him still counts (it may come round him)")
	assert_true(either, "without a facing: either side")


func test_search_queue_claims_and_cost_order() -> void:
	var queue: String = "res://build/coop_gates/test_queue_%d" % OS.get_process_id()
	assert_true(CoopSearch.claim_gate(queue, &"probe_coop", 0, "a"), "the first claim of a gate wins")
	assert_false(CoopSearch.claim_gate(queue, &"probe_coop", 0, "a"), "a second claim of the same gate loses")
	assert_true(CoopSearch.claim_gate(queue, &"probe_coop", 1, "a"), "the other difficulty is another gate")
	for name: String in ["probe_coop__a__0", "probe_coop__a__1"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(queue.path_join(name)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(queue))
	var level: StringName = StringName("cost_probe_%d_coop" % OS.get_process_id())
	CoopSearch.record_cost(level, 0, "cheap", 12.5, 1000)
	CoopSearch.record_cost(level, 0, "dear", 250.0, 90000)
	var table: Array = [{"level": level, "difficulty": 0, "gate": "cheap"}, {"level": level, "difficulty": 0,
		"gate": "new"}, {"level": level, "difficulty": 0, "gate": "dear"}]
	var order: Array = CoopSearch.order_by_cost(table)
	var cheap_cost: float = CoopSearch.gate_cost(level, 0, "cheap")
	var unknown_cost: float = CoopSearch.gate_cost(level, 0, "new")
	for gate: String in ["cheap", "dear"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(CoopSearch.COST_DIR.path_join("%s__%s__0.txt" % [
			level, gate])))
	assert_eq(cheap_cost, 12.5)
	assert_eq(unknown_cost, -1.0, "never searched")
	assert_eq(order.map(func(entry: Dictionary) -> String: return str(entry["gate"])), ["dear", "new", "cheap"],
			"dearest first, a gate never searched counts UNKNOWN_COST_SECONDS")


func test_search_cache_fingerprint_leaves_out_presentation_but_not_for_bosses() -> void:
	var narrow: String = CoopSearch.code_fingerprint()
	var full: String = CoopSearch.code_fingerprint(true)
	assert_eq(full.length(), 32)
	assert_ne(narrow, full, "the screens, the referee, the bots and the dev tools are left out")
	var files: PackedStringArray = PackedStringArray()
	CoopSearch._collect_files("res://scripts", files, false)
	var skipped: PackedStringArray = PackedStringArray()
	for file: String in files:
		for folder: String in ["res://scripts/ui/", "res://scripts/world/versus/", "res://scripts/core/bots/"]:
			if file.begins_with(folder):
				skipped.append(file)
	assert_eq(skipped.size(), 0, "no file of a skipped folder in the narrow fingerprint: %s" % ", ".join(skipped))
	assert_true(files.has("res://scripts/world/coop_search.gd") and files.has("res://scripts/player/player.gd"),
			"the simulation is in it")
	var plain: LevelData = _search_level("fp_plain_coop", 6, "objects/x2_tablet 10 13 gate=g far=16,5")
	var boss: LevelData = _search_level("fp_boss_coop", 6, "objects/x2_tablet 10 13 gate=g far=16,5
bosses/brute 20 13")
	var path: String = "res://levels/w5_l1_coop.lvl"
	var key_plain: String = CoopSearch.file_cache_key(path, plain, 0, "g")
	var key_boss: String = CoopSearch.file_cache_key(path, boss, 0, "g")
	assert_true(CoopSearch.world_has_boss(boss, 0, "g"), "the Brute stands in the gate's search world")
	assert_ne(key_plain, key_boss, "a gate whose search world holds a boss keys on the full fingerprint")
	# A boss stage's other gate: the boss's arena lies far beyond the gate's columns (its search world spawns no boss),
	# so the screens / bots edits of other owners do not throw that gate's result away.
	var rows: PackedStringArray = PackedStringArray()
	for row: int in 16:
		rows.append((TileGrid.CH_SOLID_A if row >= 14 else TileGrid.CH_AIR).repeat(120))
	rows[13] = ".@" + ".".repeat(116) + "E."
	var wide: LevelData = LevelData.parse(&"fp_far_boss_coop", "[meta]\nformat = 2\nid = fp_far_boss_coop\nkind = coop\n"
			+ "book = 2\nterrain_a = jungle/terrain_grass\nmusic = level_jungle\ncoop_of = solo_bonus\n"
			+ "coop_base_hash = %s\n[legend]\nE = objects/exit\n[tiles]\n%s\n[entities]\n" % ["ab".repeat(32),
			"\n".join(rows)] + "objects/x2_tablet 10 13 gate=g far=16,13\nobjects/x2_tablet 100 13 gate=h far=106,13\n"
			+ "bosses/brute 110 13\n", "fp_far_boss_coop.lvl")
	assert_not_null(wide)
	if wide == null:
		return
	assert_false(CoopSearch.world_has_boss(wide, 0, "g"), "gate g's columns end far before the Brute")
	assert_true(CoopSearch.world_has_boss(wide, 0, "h"), "gate h's world holds the Brute")
	assert_true(CoopSearch.world_has_boss(wide, 0, "nope"), "an unknown gate: the cautious answer")
	assert_eq(CoopSearch.file_cache_key(path, wide, 0, "g").length(), 32)


func test_visor_colossus_chain_plates_are_no_gate_mechanism() -> void:
	# G49 (DB3's w4_l2b_coop): the plates in the Colossus's room that drive no column are its chains - no gate needed,
	# no "drives no column"; fewer than two is an error.
	var hall: String = "\n".join(PackedStringArray([
		"zones/arena 30 13 name=hall rect=20,2,20,12",
		"bosses/colossus 39 13 arena=hall",
		"objects/plate 22 13 name=chain_west",
		"objects/plate 34 13 name=chain_east",
	]))
	var two: LevelValidator = _validator({"solo_main": _solo("solo_main"), "visor_coop": _coop_text("visor_coop", hall)})
	assert_false(two.has_problem("drives no column", LevelValidator.WARNING), _messages(two))
	assert_false(two.has_problem("is a co-op mechanism but the file has no objects/x2_tablet"), _messages(two))
	assert_false(two.has_problem("the visor Colossus needs two chain plates"), _messages(two))
	var one: LevelValidator = _validator({"solo_main": _solo("solo_main"), "visor1_coop": _coop_text("visor1_coop",
			hall.replace("objects/plate 34 13 name=chain_east", ""))})
	assert_true(one.has_problem("the visor Colossus needs two chain plates in its arena"), _messages(one))
	# A plate outside the room still is a gate mechanism (and drives nothing).
	var outside: LevelValidator = _validator({"solo_main": _solo("solo_main"), "visor2_coop": _coop_text(
			"visor2_coop", hall + "\nobjects/plate 4 13 name=loose")})
	assert_true(outside.has_problem("plate 'loose' drives no column", LevelValidator.WARNING), _messages(outside))
	assert_true(outside.has_problem("is a co-op mechanism but the file has no objects/x2_tablet"), _messages(outside))


func test_arena_bots_key_is_a_subset_of_the_modes() -> void:
	# G50: `bots` lists the modes the arena's bots play (a subset of `modes`) or `none`.
	for meta: String in ["modes = grub_stack,hot_rock\nbots = hot_rock", "modes = grub_stack\nbots = none"]:
		var good: LevelValidator = _validator({"arena_bots": _arena_text("arena_bots", meta)})
		assert_false(good.has_problem("bots"), "%s\n%s" % [meta, _messages(good)])
	var bad: LevelValidator = _validator({"arena_badbots": _arena_text("arena_badbots",
			"modes = grub_stack\nbots = grub_stack,clubball")})
	assert_true(bad.has_problem("bots: 'clubball' is not one of the arena's modes"), _messages(bad))
	var elsewhere: LevelValidator = _validator({"bots_level": _level("bots_level", "bots = none")})
	assert_true(elsewhere.has_problem("unknown meta key 'bots'", LevelValidator.WARNING), _messages(elsewhere))


func test_arena_gap_rule_ignores_planks_and_bumps_on_a_floor() -> void:
	# DA's wf9 #3a: two see-saws at the ends of a continuous floor make no gap in the row above it.
	var rows: PackedStringArray = ARENA_ROWS.duplicate()
	rows[7] = "...................."
	var planks: LevelValidator = _validator({"arena_floes": _arena_text("arena_floes", "modes = grub_stack", rows,
			ARENA_LEGEND, "objects/seesaw 1.5 9 len=3\nobjects/seesaw 17.5 9 len=3")})
	assert_false(planks.has_problem("a clear gap of", LevelValidator.WARNING), _messages(planks))
	# Two bumps on the floor: a row walked across a row lower is no gap either.
	var bumps: PackedStringArray = rows.duplicate()
	bumps[9] = "#@..C....P....Q.D.B#"
	var bumped: LevelValidator = _validator({"arena_bumps": _arena_text("arena_bumps", "modes = grub_stack", bumps)})
	assert_false(bumped.has_problem("gap of 17 cells in row 9", LevelValidator.WARNING), _messages(bumped))


func test_search_idle_doorstop_route_follows_g53() -> void:
	# G53 (lead designer, after the search found it): a plate door / column / slab does not wait for an IDLE hero. The
	# route the search found in w2_l1_coop 'hatches' - the idle partner parked beside slab H1 kept it open while the
	# lone hero ran from plate pa to the hole - is replayed on both difficulties as the regression probe: it never
	# reaches the hole without the partner, and since objects-A built G53 (ObjTuning.push_idle_out) not with him either:
	# the slab sinks through the idle body's cells and pushes him out.
	var data: LevelData = LevelData.load_file("res://levels/w2_l1_coop.lvl")
	assert_not_null(data)
	if data == null:
		return
	for difficulty: int in [Defs.Difficulty.BEGINNER, Defs.Difficulty.EXPERT]:
		var tablet: Dictionary = CoopSearch.find_tablet(data, difficulty, "hatches")
		if tablet.is_empty():
			print("    w2_l1_coop has no gate 'hatches' any more: nothing to replay")
			return
		var grid: TileGrid = CoopSearch.grid_at_rest(data, difficulty)
		var area: Rect2i = CoopSearch.gate_area(tablet, grid)
		var starts: Array[Vector2i] = CoopSearch.start_points(data, difficulty, tablet, grid)
		var searcher: CoopSearch.Searcher = CoopSearch.Searcher.new()
		assert_true(searcher.build_world(data, difficulty, CoopSearch.grid_at_rest(data, difficulty),
				CoopSearch.world_columns_of(area, starts, grid)))
		var macros: Dictionary = {}
		for macro: Dictionary in searcher.macros:
			macros[str(macro["name"])] = macro
		var slab: SimEntity = null
		for i: int in searcher._entities.size():
			if String(searcher._records[i]["id"]) == "objects/column" \
					and str(searcher._records[i]["params"].get("rise_while", "")) == "pa":
				slab = searcher._entities[i]
		var first: Dictionary = searcher.run(searcher._config(starts[0], 1, -1, CoopSearch.PARTNER_EGG,
				CoopSearch.NOWHERE), macros["walk R10"]["flags"], {})
		if slab == null or first.is_empty() or first["pos"] != Vector2i(924, 288):
			searcher.close()
			print("    w2_l1_coop 'hatches' changed: the doorstop route no longer applies (%s)" % str(first.get("pos")))
			return
		var spot: Vector2i = first["pos"]
		var outcome: Dictionary = {}
		for parked: bool in [false, true]:
			var at: Vector2i = spot if parked else CoopSearch.NOWHERE
			var config: Dictionary = searcher._config(spot, -1, -1, CoopSearch.PARTNER_EGG, at)
			var jump: Dictionary = searcher.run(config, macros["jump L"]["flags"], {})
			if jump.is_empty():
				continue
			var played: PackedInt32Array = jump["played"]
			var walk: Dictionary = searcher.run(config, played + (macros["walk R24"]["flags"] as PackedInt32Array),
					{tablet["far"]: true}, played.size(), jump["pos"])
			outcome[parked] = [bool(walk.get("goal", false)), int(slab.get(&"risen")) > 0]
		searcher.close()
		var label: String = Defs.difficulty_name(difficulty)
		assert_true(outcome.has(false) and outcome.has(true), "%s: the route replays (%s)" % [label, str(outcome)])
		if not outcome.has(true) or not outcome.has(false):
			continue
		assert_false(bool(outcome[false][0]), "%s: alone (the partner an egg) the hole is shut again" % label)
		assert_false(bool(outcome[true][1]), "%s: G53 - slab H1 does not wait for the idle partner (%s)" % [label,
				str(outcome)])
		assert_false(bool(outcome[true][0]), "%s: G53 - the parked idle partner keeps no door open: the route fails (%s)" % [
				label, str(outcome)])


func test_search_parks_the_partner_beside_keepers_and_shells() -> void:
	# Lead designer's wf9 #5 (G33 shell facing): from every start the idle partner is also parked in front of and behind
	# every keeper and shell enemy of the gate's area, within club reach - so a refusal holds even where the engine
	# still lets an idle body turn a shell or bait a keeper.
	var data: LevelData = _search_level("bait_coop", 6, "\n".join(PackedStringArray([
		"objects/x2_tablet 4 13 gate=g far=27,13",
		"enemies/walker 16 13 left=0 right=0 speed=0 coop=shell keeper=k",
		"enemies/walker 23 13 left=0 right=0 speed=0",
	])))
	var searcher: CoopSearch.Searcher = _search_world(data)
	var spots: Array[Vector2i] = searcher._bait_spots.duplicate()
	var keeper: Vector2i = Vector2i(-1, -1)
	for i: int in searcher._entities.size():
		if str(searcher._records[i]["params"].get("keeper", "")) == "k":
			keeper = searcher._entities[i].sim_pos
	var found: Dictionary = searcher.explore([Vector2i(40, 224)], {Vector2i(27, 13): true}, Rect2i(0, 0, 30, 16),
			CoopSearch.BOUND_TICKS, 4)
	searcher.close()
	assert_eq(spots.size(), 2, "in front of and behind the shell keeper, none for the plain walker: %s" % str(spots))
	for spot: Vector2i in spots:
		assert_eq(spot.y, keeper.y, "on the keeper's floor")
		assert_true(absi(spot.x - keeper.x) > 8 and absi(spot.x - keeper.x) <= 32, "within club reach: %s" % str(spot))
	assert_true(spots.size() == 2 and signi(spots[0].x - keeper.x) != signi(spots[1].x - keeper.x), "one each side")
	assert_true(int(found.get("placements", 0)) >= 2, "both parked from the start: %s" % str(found))


func test_search_idle_bait_keeper_replays_follow_g33_shell_facing() -> void:
	# Lead designer's wf9 #6 (D8's build/d8/bot_idle_bait.gd / bot_idle_bait_l1.gd): one player opens w8_l1_coop 'hall'
	# and w8_l2_coop 'shamans' with today's engine - his idle partner hatched in front of a shell keeper, he strikes its
	# back. The regression probe, in the search world of EVERY gate whose area holds a shell keeper (so 'den' and 'gully'
	# get their own replay too, as the lead designer's ruling asks): for each such keeper the hero stands behind it (14 px
	# clear of its box, facing it) and strikes for 400 ticks (D8's rhythm: 8 ticks on, 8 off) - once with the partner an
	# egg behind him, once with the idle partner parked in front of it (10 px clear: the nearer body). Alone every back
	# strike must glance. With the idle bait the keeper dies exactly while the engine turns the shell to the idle partner
	# (coop_traits.gd's post_ai SHELL reads Game.level.target_hero, G33 not built: printed KNOWN); once the shell faces
	# the nearer ACTIVE hero (LevelBase.nearest_coop_hero) the replay must fail. (It places the striker behind the keeper;
	# whether one player gets there is the route's question - D8's replays show it for 'hall' and 'shamans'.)
	var strikes: PackedInt32Array = PackedInt32Array()
	for i: int in 400:
		strikes.append(Defs.IN_FIRE if i % 16 < 8 else 0)
	var probed: Dictionary = {}
	var named: Array = [["w8_l1_coop", "hall"], ["w8_l2_coop", "shamans"]]
	var named_seen: int = 0
	for entry: Dictionary in CoopSearch.gate_table():
		var gate: String = str(entry["gate"])
		var difficulty: int = int(entry["difficulty"])
		var label: String = "%s (%s) '%s'" % [entry["level"], Defs.difficulty_name(difficulty), gate]
		var path: String = CoopSearch.level_path(entry["level"])
		var text: String = FileAccess.get_file_as_string(path)
		if not "keeper=" in text or not ("enemies/shellback" in text or "coop=shell" in text):
			continue
		var data: LevelData = LevelData.load_file(path)
		assert_not_null(data, label)
		if data == null:
			continue
		var tablet: Dictionary = CoopSearch.find_tablet(data, difficulty, gate)
		var grid: TileGrid = CoopSearch.grid_at_rest(data, difficulty)
		var area: Rect2i = CoopSearch.gate_area(tablet, grid)
		var starts: Array[Vector2i] = CoopSearch.start_points(data, difficulty, tablet, grid)
		var searcher: CoopSearch.Searcher = CoopSearch.Searcher.new()
		assert_true(searcher.build_world(data, difficulty, CoopSearch.grid_at_rest(data, difficulty),
				CoopSearch.world_columns_of(area, starts, grid)), label)
		var keepers: Array[int] = []
		for i: int in searcher._entities.size():
			var enemy: EnemyBase = searcher._entities[i] as EnemyBase
			if enemy != null and enemy.keeper != &"" and enemy.coop_trait == Defs.CoopTrait.SHELL 					and area.has_point(Vector2i(Tuning.to_cell(enemy.sim_pos.x), Tuning.to_cell(enemy.sim_pos.y - 1))):
				keepers.append(i)
		if [str(entry["level"]), gate] in named:
			named_seen += 1
			assert_true(keepers.size() >= 1, "%s: its shell keepers are in the search world" % label)
		for i: int in keepers:
			var keeper: EnemyBase = searcher._entities[i] as EnemyBase
			var home: Vector2i = keeper.sim_pos
			var spots: Array[Vector2i] = searcher.bait_spots(keeper)
			if spots.size() != 2:
				print("    %s: keeper at %s has no floor on both sides - skipped" % [label, str(home)])
				continue
			var bait: Vector2i = spots[0]                          # in front (left), 10 px clear
			var behind: Vector2i = spots[1] + Vector2i(4, 0)       # behind (right), 14 px clear: the farther body
			var outcome: Dictionary = {}
			var faces_idle: bool = false
			for parked: bool in [false, true]:
				var config: Dictionary = searcher._config(behind, -1, -1, CoopSearch.PARTNER_EGG,
						bait if parked else CoopSearch.NOWHERE)
				if parked:
					# Which way the shell turns with the idle partner the nearer body (the cause, read before the strikes).
					searcher.run(config, PackedInt32Array([0, 0, 0, 0]), {})
					var turned: EnemyBase = searcher._entities[i] as EnemyBase
					faces_idle = turned != null and turned.facing < 0
				searcher.run(config, strikes, {})
				var after: EnemyBase = searcher._entities[i] as EnemyBase
				outcome[parked] = after == null or not is_instance_valid(after) or after.dead
			var where: String = "%s: keeper at %s" % [label, str(home)]
			assert_false(bool(outcome[false]), "%s: alone, every back strike glances (%s)" % [where, str(outcome)])
			assert_eq(bool(outcome[true]), faces_idle, "%s: the idle bait kills it exactly while the shell faces the idle partner (G33: never) - %s" % [where, str(outcome)])
			if faces_idle:
				print("    %s: KNOWN - its shell faces the idle partner (coop_traits.gd post_ai SHELL, G33 not built): one player kills it from behind" % where)
			probed[label] = true
		searcher.close()
	if named_seen < 2:
		print("    D8's w8_l1_coop 'hall' / w8_l2_coop 'shamans' are not both in the gate table any more")
	print("    shell keeper gates replayed: %s" % ", ".join(PackedStringArray(probed.keys())))


func test_deadly_cells_felt_through_one_row_of_rock_warn() -> void:
	# LEVEL_DESIGN.md 4 "Collision facts" (D6's report, lead designer 08:42): the body probes look through solid tiles,
	# so a liquid / kill cell needs TWO solid rows between it and any space a hero can rise into below it.
	var rows: PackedStringArray = _coop_rows()
	_paint(rows, 9, 5, 8, TileGrid.CH_LIQUID)      # a basin on a deck one row thick, over the path (floor row 14)
	_paint(rows, 10, 5, 8)
	_paint(rows, 9, 15, 18, TileGrid.CH_LIQUID)    # the same basin on two rows of rock: fine
	_paint(rows, 10, 15, 18)
	_paint(rows, 11, 15, 18)
	_paint(rows, 4, 25, 28, TileGrid.CH_LIQUID)    # one row of rock, but no floor within a jump below it: fine
	_paint(rows, 5, 25, 28)
	var validator: LevelValidator = _validator({"solo_main": _solo("solo_main"), "rock_coop": _coop_text("rock_coop",
			"", rows)})
	assert_true(validator.has_problem("deadly cells at columns 5-8 of row 9 have one solid row under them",
			LevelValidator.WARNING), _messages(validator))
	assert_true(validator.has_problem("rising from the floor of row 14", LevelValidator.WARNING), _messages(validator))
	assert_false(validator.has_problem("deadly cells at columns 15-18", LevelValidator.WARNING), "two rows of rock")
	assert_false(validator.has_problem("deadly cells at columns 25-28", LevelValidator.WARNING),
			"no floor a hero rises from within 7 rows")
	# A frozen format-1 file is never checked (Book I stays as 1.0 shipped it); the same rows in a 2.0 file are.
	var trap: String = "\n".join(PackedStringArray(["....." + TileGrid.CH_LIQUID.repeat(4) + ".".repeat(15),
			".....####" + ".".repeat(15), ".@" + ".".repeat(20) + "E."]))
	var frozen: LevelValidator = _validator({"frozen_main": _solo("frozen_main").replace(PLAIN_ROWS, trap)})
	assert_false(frozen.has_problem("felt through", LevelValidator.WARNING), _messages(frozen))
	var fresh: LevelValidator = _validator({"fresh_main": _solo("fresh_main").replace(PLAIN_ROWS, trap)
			.replace("format = 1", "format = 2")})
	assert_true(fresh.has_problem("deadly cells at columns 5-8 of row 8", LevelValidator.WARNING), _messages(fresh))


# =================================================================================================================
# wf10 (world-B): the orchestrator's SEARCH decision (DESIGN.md G59) - "refused" never means "stopped at the bound":
# the verdicts, the two passes, the continuous-play probes, the settled and shared worlds, the message-queue guard
# =================================================================================================================

## A raw search result as [method CoopSearch.judge] reads it.
func _raw_result(explored: int, exhausted: bool, stopped: String, required: Dictionary, covered: Dictionary) -> Dictionary:
	var probes: Dictionary = {}
	for family: String in CoopSearch.PROBE_FAMILIES:
		var targets: Dictionary = covered.get(family, {})
		var runs: int = 0
		for target: String in targets:
			runs += int(targets[target])
		probes[family] = {"runs": runs, "sites": targets.size(), "kills": 0, "seeds": 0, "dead": 0, "reached": false,
			"targets": targets}
	return {"reached": false, "detail": "", "explored": explored, "exhausted": exhausted, "stopped": stopped,
		"queued": 0 if exhausted else 40, "probes": probes, "probes_required": required, "probes_on": true,
		"probe_targets": {"e1": "shellback 12,13", "p2": "plate 6,13", "f": "the far cell 16,5"}}


func test_search_verdicts_name_their_evidence() -> void:
	var keeper: Dictionary = {CoopSearch.PROBE_HOP_OVER: ["e1"], CoopSearch.PROBE_IDLE_BAIT: ["e1"],
		CoopSearch.PROBE_THROWN: ["e1"]}
	var all_run: Dictionary = {CoopSearch.PROBE_HOP_OVER: {"e1": 48}, CoopSearch.PROBE_IDLE_BAIT: {"e1": 32},
		CoopSearch.PROBE_THROWN: {"e1": 18}}
	# The frontier emptied: exhaustive, whatever the count.
	var dry: Dictionary = CoopSearch.judge(_raw_result(11, true, "", keeper, all_run))
	assert_eq(dry["verdict"], CoopSearch.VERDICT_EXHAUSTIVE)
	assert_true(str(dry["evidence"]).contains("11 resting points") and str(dry["evidence"]).contains("hop-over 0/48"),
			str(dry["evidence"]))
	# Stopped at a bound: refused only from 660 resting points on AND with every probe of the gate's kind run.
	var bounded: Dictionary = CoopSearch.judge(_raw_result(700, false, "ticks", keeper, all_run))
	assert_eq(bounded["verdict"], CoopSearch.VERDICT_BOUNDED)
	assert_true(str(bounded["evidence"]).contains("bounded at 700 resting points by the tick bound"),
			str(bounded["evidence"]))
	var shallow: Dictionary = CoopSearch.judge(_raw_result(CoopSearch.BOUNDED_MIN_NODES - 1, false, "ticks", keeper, all_run))
	assert_eq(shallow["verdict"], CoopSearch.VERDICT_UNPROVEN, "659 resting points: stopped at the bound, not refused")
	var gap: Dictionary = all_run.duplicate(true)
	gap.erase(CoopSearch.PROBE_IDLE_BAIT)
	var unprobed: Dictionary = CoopSearch.judge(_raw_result(900, false, "nodes", keeper, gap))
	assert_eq(unprobed["verdict"], CoopSearch.VERDICT_UNPROVEN, "a probe of the gate's kind did not run")
	assert_eq(Array(unprobed["missing"] as PackedStringArray), ["idle-bait at shellback 12,13"])
	assert_true(str(unprobed["evidence"]).contains("probes missing: idle-bait at shellback 12,13"),
			str(unprobed["evidence"]))
	# The queue ran dry but a replay missed its world (a move was not played): bounded with its probes, not exhaustive.
	var missed: Dictionary = _raw_result(40, true, "", keeper, all_run)
	missed["misses"] = 3
	assert_eq(CoopSearch.judge(missed)["verdict"], CoopSearch.VERDICT_BOUNDED)
	assert_true(str(CoopSearch.judge(missed)["evidence"]).contains("3 move(s) from changed worlds were not played"),
			str(CoopSearch.judge(missed)["evidence"]))
	# The first pass ran dry and the budget ended in the second (only longer replays left): bounded with its probes.
	var second: Dictionary = _raw_result(200, false, "ticks", keeper, all_run)
	second["passes"] = 2
	assert_eq(CoopSearch.judge(second)["verdict"], CoopSearch.VERDICT_BOUNDED, str(CoopSearch.judge(second)["evidence"]))
	var blind: Dictionary = _raw_result(900, false, "nodes", keeper, all_run)
	blind["probes_on"] = false
	assert_eq(CoopSearch.judge(blind)["verdict"], CoopSearch.VERDICT_UNPROVEN, "a bounded search without probes")
	# Reached, a broken static rule, a gate that cannot be searched.
	var open: Dictionary = _raw_result(5, false, "found", keeper, all_run)
	open["reached"] = true
	open["detail"] = "one hero reached 16,5 in 99 ticks: start > probe hop-over"
	assert_eq(CoopSearch.judge(open)["verdict"], CoopSearch.VERDICT_OPEN)
	assert_eq(CoopSearch.judge({"reached": true, "detail": "unproven: no objects/x2_tablet gate=x"})["verdict"],
			CoopSearch.VERDICT_UNPROVEN)
	# The stored verdict wins (a cached result), and the line of the G3 table.
	var stored: Dictionary = {"reached": false, "verdict": CoopSearch.VERDICT_BOUNDED, "evidence": "e", "missing": []}
	assert_eq(CoopSearch.gate_verdict(stored)["verdict"], CoopSearch.VERDICT_BOUNDED)
	assert_eq(CoopSearch.verdict_line(&"w0_l0_coop", Defs.Difficulty.EXPERT, "hall", stored),
			"GATE w0_l0_coop expert hall: refused (bounded) (e)")


func test_search_small_gate_is_exhaustive_and_probed() -> void:
	# The 8-row ledge: the whole floor is searched until nothing is left (both passes), and the leaps of the ledge
	# kind ran (hop-over with run-ups, idle-bait with the partner at the take-off spot).
	var high: Dictionary = CoopSearch.search_data(_search_level("verdict_coop", 6,
			"objects/x2_tablet 10 13 gate=hop far=16,5"), Defs.Difficulty.BEGINNER, "hop")
	assert_false(bool(high["reached"]), str(high["detail"]))
	assert_true(bool(high["exhausted"]), "the queue ran dry: %s" % str(high.get("evidence", "")))
	assert_eq(high["verdict"], CoopSearch.VERDICT_EXHAUSTIVE)
	assert_eq(high["gate_kinds"], ["ledge or gap"])
	assert_true(int(high["probes"][CoopSearch.PROBE_HOP_OVER]["runs"]) >= 18, str(high["probes"]))
	assert_true(int(high["probes"][CoopSearch.PROBE_IDLE_BAIT]["runs"]) >= 9, str(high["probes"]))
	assert_eq((high["missing"] as Array).size(), 0, str(high["missing"]))
	assert_eq(int(high["misses"]), 0, "no replay missed its world")
	var lines: PackedStringArray = CoopSearch.report_lines(high)
	assert_true(lines[0].begins_with("search: EXHAUSTIVE"), lines[0])
	assert_true("\n".join(lines).contains("probe hop-over: "), "\n".join(lines))
	# The same gate under a bound it cannot finish in: not refused - UNPROVEN, and search_gate's contract says so.
	CoopSearch.node_limit = 5
	var cut: Dictionary = CoopSearch.search_data(_search_level("verdict_cut_coop", 6,
			"objects/x2_tablet 10 13 gate=hop far=16,5"), Defs.Difficulty.BEGINNER, "hop")
	CoopSearch.node_limit = CoopSearch.MAX_NODES
	assert_false(bool(cut["reached"]), "the raw result: not reached")
	assert_false(bool(cut["exhausted"]))
	assert_eq(cut["stopped"], "nodes")
	assert_eq(cut["verdict"], CoopSearch.VERDICT_UNPROVEN, str(cut["evidence"]))
	var held: Dictionary = CoopSearch.hold_to_verdict(cut.duplicate(true))
	assert_true(bool(held["reached"]), "G59: a gate that stopped at its bound without its evidence is not refused")
	assert_true(str(held["detail"]).begins_with("unproven: bounded at 5 resting points"), str(held["detail"]))
	assert_eq(CoopSearch.gate_verdict(held)["verdict"], CoopSearch.VERDICT_UNPROVEN)
	var kept: Dictionary = CoopSearch.hold_to_verdict(high.duplicate(true))
	assert_false(bool(kept["reached"]), "a refusal with its evidence stays a refusal")


## The keeper-door map: a 4-row hall cell over a keeper with 100 hit points at column 16 (four club strikes in a co-op
## file, G57), a wall at column 22 whose bottom four cells are the door its death opens; the far cell lies behind it.
func _keeper_level(id: String) -> LevelData:
	var rows: PackedStringArray = _flat_rows()
	for row: int in range(2, 14):
		_paint(rows, row, 22, 22)
	_paint(rows, 9, 16, 16)
	return _search_rows(id, rows, "\n".join(PackedStringArray([
		"objects/x2_tablet 6 13 gate=door far=25,13",
		"enemies/walker 16 13 left=0 right=0 hp=100 keeper=k",
		"objects/column 22 13 size=1,4 rise=4 trigger=keepers:k",
	])))


func test_search_probes_and_carried_wounds_kill_what_one_move_cannot() -> void:
	# One strike takes 25 of the keeper's 100 hit points (one hit per strike in a co-op file, G57), and a move holds
	# one strike: the search before wf10 (wounds not carried, no probes) never opened this door - its blind spot.
	CoopSearch.node_limit = 150
	CoopSearch.carry_hits = false
	CoopSearch.probes = false
	var blind: Dictionary = CoopSearch.search_data(_keeper_level("keeper_blind_coop"), Defs.Difficulty.BEGINNER, "door")
	# A continuous-play probe (the duel: over the keeper, then strike after strike) opens it.
	CoopSearch.probes = true
	var probed: Dictionary = CoopSearch.search_data(_keeper_level("keeper_probe_coop"), Defs.Difficulty.BEGINNER, "door")
	CoopSearch.carry_hits = true
	CoopSearch.node_limit = CoopSearch.MAX_NODES
	assert_false(str(blind["detail"]).begins_with("static rule"), str(blind["detail"]))
	assert_false(bool(blind["reached"]), "one strike a move, no wound carried: %s" % str(blind["detail"]))
	assert_true(bool(probed["reached"]), "a duel of continuous play kills the keeper: %s" % str(probed.get("evidence", "")))
	assert_true(str(probed["detail"]).contains("probe "), str(probed["detail"]))
	assert_eq(probed["verdict"], CoopSearch.VERDICT_OPEN)
	# And the move search carries a wound: a wounded keeper is a changed world (the next strike move starts from it).
	var searcher: CoopSearch.Searcher = _search_world(_keeper_level("keeper_wound_coop"))
	var strike: PackedInt32Array = CoopSearch._repeat(Defs.IN_RIGHT, 1) + CoopSearch._repeat(Defs.IN_FIRE, 12) 			+ CoopSearch._repeat(0, 4)
	var wounded: String = ""
	var unhurt: String = ""
	for gap: int in [40, 34, 28, 22, 46]:
		var carried: Dictionary = searcher.run(_config(Vector2i(16 * Tuning.TILE + 8 - gap, 224)), strike, {})
		if not carried.is_empty() and str(carried["sig"]) != searcher._baseline:
			wounded = searcher.sig_changes(str(carried["sig"]))
			CoopSearch.carry_hits = false
			var plain: Dictionary = searcher.run(_config(Vector2i(16 * Tuning.TILE + 8 - gap, 224)), strike, {})
			CoopSearch.carry_hits = true
			unhurt = "lost" if plain.is_empty() else ("same" if str(plain["sig"]) == searcher._baseline else "changed")
			break
	searcher.close()
	assert_true(wounded.contains("walker 16,13: e0:75"), "one strike: the keeper at 75 is a changed world (%s)" % wounded)
	assert_eq(unhurt, "same", "without carry_hits the same strike left the level-file world")


func test_search_settles_the_world_and_shares_changed_worlds() -> void:
	# A held plate: the node "he stands on the plate" is ONE world (the door fully risen), not a world per door phase;
	# stepping off it and waiting gives the level-file world back (a plain node). The gate stays shut for one player.
	CoopSearch.idle_partner = false
	var held: Dictionary = CoopSearch.search_data(_door_level("settle_hold_coop", "hold"), Defs.Difficulty.BEGINNER, "door")
	CoopSearch.settle_world = false
	CoopSearch.share_worlds = false
	var before: Dictionary = CoopSearch.search_data(_door_level("settle_old_coop", "hold"), Defs.Difficulty.BEGINNER,
			"door")
	CoopSearch.settle_world = true
	CoopSearch.share_worlds = true
	CoopSearch.idle_partner = true
	assert_false(bool(held["reached"]), str(held["detail"]))
	assert_false(bool(before["reached"]), str(before["detail"]))
	assert_true(bool(held["exhausted"]), str(held.get("evidence", "")))
	assert_true(int(held["worlds"]) >= 1, "the pressed plate is a changed world (%d)" % int(held["worlds"]))
	assert_eq(int(held["misses"]), 0, "every shared world's replay came back to its end")
	assert_true(int(held["changed"]) < int(before["changed"]),
			"settled: fewer changed-world nodes (%d) than a node per door phase (%d)" % [int(held["changed"]),
			int(before["changed"])])
	assert_true(int(held["replayed"]) < int(before["replayed"]), "and cheaper replays (%d < %d ticks)" % [
			int(held["replayed"]), int(before["replayed"])])
	# A latch: the changed world still carries the open door to the next move.
	var latched: Dictionary = CoopSearch.search_data(_door_level("settle_latch_coop", "latch"), Defs.Difficulty.BEGINNER,
			"door")
	assert_true(bool(latched["reached"]), "a latched door stays open across moves: %s" % str(latched.get("evidence", "")))


func test_search_hop_jump_reaches_six_rows_not_seven() -> void:
	# DB1's finding (wf10 #1): a jump begun in a low strike's hop (Up from the strike's 8th tick) rises 73-82 px, so a
	# ledge 5 or 6 rows over the floor is no gate for one hero; 7 rows is (and 8, the boost ledge, with room to spare).
	var six: Dictionary = CoopSearch.search_data(_search_level("hop_six_coop", 8,
			"objects/x2_tablet 10 13 gate=hop far=16,7"), Defs.Difficulty.BEGINNER, "hop")
	var seven: Dictionary = CoopSearch.search_data(_search_level("hop_seven_coop", 7,
			"objects/x2_tablet 10 13 gate=hop far=16,6"), Defs.Difficulty.BEGINNER, "hop")
	assert_true(bool(six["reached"]), "6 rows: the hop jump (%s)" % str(six.get("evidence", "")))
	assert_true(str(six["detail"]).contains("low-hop-"), str(six["detail"]))
	assert_false(bool(seven["reached"]), "7 rows: out of one hero's reach (%s)" % str(seven["detail"]))
	assert_eq(seven["verdict"], CoopSearch.VERDICT_EXHAUSTIVE)
	var names: PackedStringArray = PackedStringArray()
	for macro: Dictionary in CoopSearch.make_macros(true):
		names.append(str(macro["name"]))
	for name: String in ["low-hop-jump R", "low-hop-high L", "jump-high R", "climb", "climb-leap L"]:
		assert_true(names.has(name), "the search plays '%s'" % name)


func test_search_reset_respawns_what_a_level_reset_leaves_changed() -> void:
	# An unrolled vine stays unrolled "through deaths and team wipes" - but not from one move of the search to the
	# next: the search world spawns it again (before wf10 every later move played with the vine down).
	# The coil lies one row over the floor: in a co-op file it unrolls only for a hit from its own level - the
	# striker's feet at most one row under its ledge (DESIGN.md G67; two rows over the floor it passes his strike).
	var searcher: CoopSearch.Searcher = _search_world(_search_level("leak_coop", 6, "objects/vine 12 13 length=1 rolled"))
	var strike: PackedInt32Array = CoopSearch._repeat(Defs.IN_RIGHT, 1) + CoopSearch._repeat(Defs.IN_FIRE, 12) 			+ CoopSearch._repeat(0, 12)
	var unrolled: String = ""
	for gap: int in [10, 16, 22, 28, 4]:
		var struck: Dictionary = searcher.run(_config(Vector2i(12 * Tuning.TILE + 8 - gap, 224)), strike, {})
		if not struck.is_empty() and str(struck["sig"]) != searcher._baseline:
			unrolled = searcher.sig_changes(str(struck["sig"]))
			break
	var leaks_before: int = searcher.leaks
	var after: Dictionary = searcher.run(_config(Vector2i(40, 224)), CoopSearch._repeat(0, 4), {})
	var back: bool = not after.is_empty() and str(after["sig"]) == searcher._baseline
	var leaks_after: int = searcher.leaks
	searcher.close()
	assert_true(unrolled.contains("vine 12,13") and unrolled.contains("opened=true"),
			"a strike unrolls the vine: a changed world (%s)" % unrolled)
	assert_true(back, "the next move starts in the level-file world again: the vine is rolled")
	assert_eq(leaks_after - leaks_before, 1, "the search spawned the vine again (a level reset leaves it unrolled)")


func test_search_level_spawns_no_effect_and_counts_the_rest() -> void:
	# Godot's message queue (content's wf10 #1): a search passes no frame, so its level makes no cosmetic node at all.
	var searcher: CoopSearch.Searcher = _search_world(_search_level("fx_coop", 6, ""))
	var before: int = searcher.level.spawned
	var effect: Node = searcher.level.spawn(&"fx/dust", Vector2i(100, 224))
	var effects: int = searcher.level.spawned - before
	var item: Node = searcher.level.spawn(&"items/food", Vector2i(100, 224), {"index": 1})
	var counted: int = searcher.level.spawned - before
	var made: bool = item != null
	searcher.close()
	assert_null(effect, "no fx/ node in a search level")
	assert_eq(effects, 0)
	assert_true(made, "everything else spawns as in the game")
	assert_eq(counted, 1, "and is counted (CoopSearch.SPAWN_LIMIT stops a search before the queue is full)")


func test_search_probe_sites_gate_box_and_partner_places() -> void:
	var data: LevelData = _search_rows("sites_coop", _flat_rows(), "\n".join(PackedStringArray([
		"objects/x2_tablet 6 13 gate=door far=25,13",
		"objects/plate 10 13 name=p mode=hold",
		"objects/column 22 13 size=1,2 rise=2 rise_while=p",
		"objects/plate 2 3 name=other mode=hold",
	])))
	var searcher: CoopSearch.Searcher = _search_world(data)
	var tablet: Dictionary = CoopSearch.find_tablet(data, Defs.Difficulty.BEGINNER, "door")
	var box: Rect2i = CoopSearch.gate_box_of(tablet, searcher.level.grid)
	searcher.set_gate_box(box)
	var area: Rect2i = Rect2i(0, 0, 30, 16)
	var needs: Dictionary = searcher.probe_requirements(area, Vector2i(25, 13))
	var names: Dictionary = needs["names"]
	var own: PackedStringArray = PackedStringArray()
	for target: String in needs["required"][CoopSearch.PROBE_THROWN]:
		own.append(str(names[target]))
	# Sites: the first node in reach, then one NEAR the target on each side of it - no third on a side, none too close.
	var sites: Dictionary = {}
	var at: Vector2i = Vector2i(400, 224)
	var first: bool = searcher._probe_site(sites, "e9", at, Vector2i(100, 224))
	var far_again: bool = searcher._probe_site(sites, "e9", at, Vector2i(180, 224))
	var near_left: bool = searcher._probe_site(sites, "e9", at, Vector2i(330, 224))
	var left_again: bool = searcher._probe_site(sites, "e9", at, Vector2i(270, 224))
	var near_right: bool = searcher._probe_site(sites, "e9", at, Vector2i(460, 224))
	var full: bool = searcher._probe_site(sites, "e9", at, Vector2i(520, 224))
	var out_of_reach: bool = searcher._probe_site({}, "e9", at, Vector2i(400 + 21 * Tuning.TILE, 224))
	# The parked partner's places: six cells wide (CoopSearch.PARK_KEY_PX).
	var here: Dictionary = searcher._node(Vector2i(100, 224), 0, "", "", Vector2i(200, 224))
	var close: Dictionary = searcher._node(Vector2i(100, 224), 0, "", "", Vector2i(260, 224))
	var apart: Dictionary = searcher._node(Vector2i(100, 224), 0, "", "", Vector2i(300, 224))
	var same_place: bool = searcher._key_of(here) == searcher._key_of(close)
	var other_place: bool = searcher._key_of(here) != searcher._key_of(apart)
	searcher.close()
	assert_eq(box, Rect2i(0, 7, 30, 9), "tablet and far cell grown by GATE_BOX_MARGIN, inside the map")
	assert_true(own.has("plate 10,13") and own.has("column 22,13"), "the gate's own plate and door: %s" % str(own))
	assert_false(own.has("plate 2,3"), "a plate of the area outside the gate box is not waited for: %s" % str(own))
	assert_eq(int(needs["others"]), 1)
	assert_true((needs["kinds"] as PackedStringArray).has("plate door / pulley / see-saw / boulder"), str(needs["kinds"]))
	assert_true((needs["required"][CoopSearch.PROBE_PLATES] as Array).size() == 1, str(needs["required"]))
	assert_true(first and near_left and near_right, "first in reach, then near on each side")
	assert_false(far_again, "a second site must be near the target")
	assert_false(left_again, "one near site a side")
	assert_false(full, "PROBE_SITES at most")
	assert_false(out_of_reach, "21 cells away: out of reach")
	assert_true(same_place, "60 px apart inside one stretch of six cells: one place of the parked partner")
	assert_true(other_place, "100 px apart: another place")


## 16 rows of 30 cells, floor rows 14-15.
func _flat_rows() -> PackedStringArray:
	var rows: PackedStringArray = PackedStringArray()
	for row: int in 16:
		rows.append((TileGrid.CH_SOLID_A if row >= 14 else TileGrid.CH_AIR).repeat(30))
	return rows
