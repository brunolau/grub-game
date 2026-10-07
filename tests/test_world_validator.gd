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
			"bad_line.lvl:7: error: biome 'moon' must be one of: jungle, cave, ice, volcano, feast, village")


func test_header_rules() -> void:
	var text: String = _level("wrong_name", "format = 2\nmusic = disco\nnext = nowhere\nice_a = 5\nwind = 0:8,x\n" +
			"password_beginner = ab\nscroll = sideways\ntime.hard = 3\nflavour = sweet")
	var validator: LevelValidator = _validator({"header": text.replace("format = 1\n", "")})
	assert_true(validator.has_problem("format must be 1"))
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
