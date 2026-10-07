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


func test_search_refuses_a_high_ledge_and_finds_a_low_one() -> void:
	var high: Dictionary = CoopSearch.search_data(_search_level("high_coop", 6, "objects/x2_tablet 10 13 gate=hop far=16,5"),
			Defs.Difficulty.BEGINNER, "hop")
	assert_false(bool(high["reached"]), "8 rows: no single hero gets up there (%s)" % high["detail"])
	# The static prefilter (G1 integration) already refuses it: no chain of feet cells climbs 8 rows.
	assert_true(bool(high.get("prefilter", false)), "the prefilter refused it without simulating")
	# The full search agrees, from the same starts.
	CoopSearch.prefilter = false
	var searched: Dictionary = CoopSearch.search_data(_search_level("high_coop", 6,
			"objects/x2_tablet 10 13 gate=hop far=16,5"), Defs.Difficulty.BEGINNER, "hop")
	CoopSearch.prefilter = true
	assert_false(bool(searched["reached"]), "the full search refuses it too (%s)" % searched["detail"])
	assert_true(int(searched["explored"]) > 10, "the floor was searched (%d resting points)" % int(searched["explored"]))
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
		if str(window["what"]) == "drums twin":
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


func test_zz_debug_daze() -> void:
	var rows: PackedStringArray = PackedStringArray()
	for row: int in 16:
		rows.append((TileGrid.CH_SOLID_A if row >= 14 else TileGrid.CH_AIR).repeat(30))
	var searcher: CoopSearch.Searcher = CoopSearch.Searcher.new()
	assert_true(searcher.build(&"coop_search_daze", {}, TileGrid.from_rows(rows)))
	var target: EnemyBase = EnemyBase.new()
	target.set_box(Vector3i(32, 32, 16))
	target.spawn_setup(Vector2i(240, 224), {})
	searcher.level.add_child(target)
	target.max_hp = 99999
	target.hp = 99999
	var hero: PlayerBase = searcher.hero
	target.teleport(Vector2i(240, 224))
	target.wake()
	hero.run.reset_energy()
	hero.respawn_at(Vector2i(240 - 36, 224))
	hero.facing = 1
	var flags: PackedInt32Array = CoopSearch._repeat(Defs.IN_UP | Defs.IN_RIGHT, 5) + CoopSearch._repeat(Defs.IN_RIGHT, 30)
	searcher._flags = flags
	searcher._first_tick = Sim.tick + 1
	for t: int in 40:
		Sim.step(1)
		print("t%d hero %s y%d st%d tgt %s awake%s onscr%s targ%s bc%d hp%d dead%s" % [t, hero.sim_pos, hero.yvel, hero.state, target.sim_pos, target.awake, target.on_screen, target.is_targetable(), target.bounce_count, hero.run.hearts, hero.dead])
	target.free()
	searcher.close()
