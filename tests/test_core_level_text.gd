extends TestCase
## LevelText + Levels: the syntax of the level file format and the level registry (ARCHITECTURE.md 7),
## checked against the shipped example level.

const EXAMPLE: StringName = &"test_example"


func test_value_typing() -> void:
	assert_eq(LevelText.parse_value("true"), true)
	assert_eq(LevelText.parse_value(" false "), false)
	assert_eq(LevelText.parse_value("42"), 42)
	assert_eq(LevelText.parse_value("-3"), -3)
	assert_eq(LevelText.parse_value("0"), 0)
	assert_eq(LevelText.parse_value("1.5"), 1.5)
	assert_eq(LevelText.parse_value("\"Vine Bridges\""), "Vine Bridges")
	assert_eq(LevelText.parse_value("jungle/terrain"), "jungle/terrain")
	assert_eq(LevelText.parse_value("0042"), "0042", "leading zeros stay text")
	assert_eq(LevelText.parse_value("12E4"), "12E4", "exponent notation stays text")
	assert_eq(LevelText.parse_value("3,4,10,2"), "3,4,10,2", "lists stay text")
	assert_eq(LevelText.parse_value(""), "")


func test_sections_and_comments() -> void:
	var sections: Dictionary = LevelText.split_sections(
		"# preamble\n[meta]\n# comment\n  id = demo  \n\nname = \"A B\"\n[tiles]\n#.#\n\n . \n"
		+ "[entities]\nitems/heart 1 2\n"
	)
	assert_eq(sections.size(), 3)
	assert_eq(sections["meta"].size(), 2, "comments and blank lines are dropped outside raw sections")
	assert_eq(sections["meta"][0], "id = demo")
	assert_eq(sections["tiles"].size(), 2, "tile rows are kept verbatim, '#' is a tile there")
	assert_eq(sections["tiles"][0], "#.#")
	assert_eq(sections["tiles"][1], " . ")
	assert_eq(sections["entities"][0], "items/heart 1 2")
	assert_eq(LevelText.section_name("[meta]"), "meta")
	assert_eq(LevelText.section_name("[Meta]"), "")
	assert_eq(LevelText.section_name("#.#"), "")
	var meta: Dictionary = LevelText.parse_key_values(sections["meta"])
	assert_eq(meta["id"], "demo")
	assert_eq(meta["name"], "A B")


func test_legend_and_entity_lines() -> void:
	var entry: Dictionary = LevelText.parse_legend_line("T = enemies/walker skin=turtle left=-3 right=3 expert")
	assert_eq(entry["char"], "T")
	assert_eq(entry["id"], &"enemies/walker")
	assert_eq(entry["params"]["skin"], "turtle")
	assert_eq(entry["params"]["left"], -3)
	assert_eq(entry["params"]["expert"], true, "a bare word is a flag")
	assert_true(LevelText.applies_to(entry["params"], Defs.Difficulty.EXPERT))
	assert_false(LevelText.applies_to(entry["params"], Defs.Difficulty.BEGINNER))
	var legend_lines: PackedStringArray = PackedStringArray(["? = objects/hidden_spot kind=small count=9 tile=#"])
	var legend: Dictionary = LevelText.parse_legend(legend_lines)
	assert_eq(legend["?"]["params"]["count"], 9, "a level may redefine the shortcut characters")
	assert_eq(legend["$"]["id"], &"objects/breakable_block", "built-in default legend")
	assert_eq(LevelText.legend_tiles(legend)["$"], ";")
	var entity: Dictionary = LevelText.parse_entity_line("zones/secret 17 3.5 name=sky rect=16,2,6,3")
	assert_eq(entity["id"], &"zones/secret")
	assert_almost_eq(entity["col"], 17.0)
	assert_almost_eq(entity["row"], 3.5)
	assert_eq(LevelText.to_rect_px(entity["params"]["rect"]), Rect2i(256, 32, 96, 48))
	assert_eq(LevelText.to_int_list("1,2,3"), PackedInt32Array([1, 2, 3]))
	assert_eq(LevelText.to_list("food:3,food:17").size(), 2)
	assert_eq(LevelText.cell_to_feet(2.0, 10.0), Vector2i(40, 176), "bottom-centre of the cell")
	assert_eq(LevelText.cell_to_feet(2.0, 10.0, {"dx": -3, "dy": 2}), Vector2i(37, 178))
	assert_eq(LevelText.cell_to_feet(2.5, 9.5), Vector2i(48, 168))


func test_malformed_lines_are_reported_not_fatal() -> void:
	LevelText.quiet = true
	LevelText.clear_problems()
	assert_true(LevelText.parse_legend_line("TT = enemies/walker").is_empty())
	assert_true(LevelText.parse_entity_line("enemies/walker here there").is_empty())
	assert_eq(LevelText.to_rect_px("1,2,3"), Rect2i())
	assert_true(LevelText.parse_key_values(PackedStringArray(["no equals sign"])).is_empty())
	LevelText.quiet = false
	assert_eq(LevelText.problems.size(), 4, "every problem is collected for the level validator")
	assert_true(LevelText.problems[0].contains("TT"))
	LevelText.clear_problems()
	assert_true(LevelText.problems.is_empty())


func test_registry_finds_the_example_level() -> void:
	assert_true(Levels.has_level(EXAMPLE))
	assert_eq(Levels.get_level_path(EXAMPLE), "res://levels/test_example.lvl")
	var meta: Dictionary = Levels.get_level_meta(EXAMPLE)
	assert_eq(meta["format"], Levels.FORMAT_VERSION)
	assert_eq(meta["id"], "test_example")
	assert_eq(meta["name"], "Example Meadow")
	assert_eq(meta["kind"], Levels.KIND_TEST)
	assert_eq(meta["biome"], "jungle")
	assert_eq(meta["music"], String(Sfx.MUSIC_JUNGLE))
	assert_true(AudioTable.MUSIC.has(StringName(str(meta["music"]))), "music names a known context")
	assert_eq(Levels.get_value(EXAMPLE, "time", 99, Defs.Difficulty.EXPERT), 0, ".expert variant is applied")
	assert_eq(Levels.get_value(EXAMPLE, "no_such_key", 7), 7)
	assert_false(Levels.get_campaign().has(EXAMPLE), "test levels are not part of the campaign")
	assert_true(Levels.is_available(EXAMPLE, Defs.Difficulty.BEGINNER))


func test_registry_passwords() -> void:
	var found: Dictionary = Levels.find_by_password("c1ub")
	assert_eq(found.get("level_id"), EXAMPLE)
	assert_eq(found.get("difficulty"), Defs.Difficulty.BEGINNER)
	found = Levels.find_by_password("6RUB")
	assert_eq(found.get("difficulty"), Defs.Difficulty.EXPERT)
	assert_true(Levels.find_by_password("ZZZZ").is_empty())
	assert_true(Levels.find_by_password("").is_empty())
	assert_eq(Levels.get_password(EXAMPLE, Defs.Difficulty.EXPERT), "6RUB")


func test_example_level_is_well_formed() -> void:
	var text: String = FileAccess.get_file_as_string(Levels.get_level_path(EXAMPLE))
	var sections: Dictionary = LevelText.split_sections(text)
	for section: String in ["meta", "legend", "tiles", "entities", "backwall", "overrides"]:
		assert_true(sections.has(section), "section [%s]" % section)
	var rows: PackedStringArray = sections["tiles"]
	assert_eq(rows.size(), 14)
	var legend: Dictionary = LevelText.parse_legend(sections["legend"])
	var starts: int = 0
	for row: String in rows:
		assert_eq(row.length(), 36, "all rows have the same width")
		for i: int in row.length():
			var ch: String = row[i]
			if ch == TileGrid.CH_PLAYER_START:
				starts += 1
			assert_true(
				TileGrid.LEGEND_CHARS.contains(ch) or legend.has(ch),
				"character '%s' is a fixed tile or defined in [legend]" % ch
			)
	assert_eq(starts, 1, "exactly one player start")
	for key: String in legend:
		var id: StringName = legend[key]["id"]
		assert_true(Spawner.CATEGORIES.has(Spawner.category(id)), "legend id '%s' uses a known category" % id)
	for line: String in sections["entities"]:
		assert_false(LevelText.parse_entity_line(line).is_empty(), line)
	var grid: TileGrid = TileGrid.from_rows(rows, 0, 0, LevelText.legend_tiles(legend))
	assert_eq(grid.cols, 36)
	assert_eq(grid.get_char(8, 11), TileGrid.CH_SOLID_A, "'?' hidden spot stands in solid ground")
	assert_eq(grid.get_char(30, 10), TileGrid.CH_SOLID_INVISIBLE, "'$' breakable block is solid")
	assert_eq(grid.floor_at(18, 11), TileGrid.FLOOR_DEADLY, "water pit")
	assert_eq(grid.floor_at(20, 4), TileGrid.FLOOR_HATCH)
	assert_eq(grid.profile_at(20, 10), TileGrid.PROFILE_UP_RIGHT_45)
	assert_eq(grid.profile_at(19, 11), TileGrid.PROFILE_NONE, "liquid is not a slope foot")
	assert_eq(grid.profile_at(26, 11), TileGrid.PROFILE_FLAT_GLUE, "foot of the hill")
