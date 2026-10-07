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


## Level format 2 (ARCHITECTURE.md 7.11): the same syntax; `coop_base_hash` always stays text; the book and belt
## rules (LEVEL_DESIGN.md 15.2) shared by the registry and the loader.
func test_format_2_header() -> void:
	assert_eq(LevelText.FORMATS, [1, 2] as Array[int])
	assert_eq(Levels.FORMATS, [Levels.FORMAT_VERSION, Levels.FORMAT_2] as Array[int])
	assert_eq(Levels.FORMAT_VERSION, 1, "format 1 = the 1.0 files")
	var digits: String = "1234567890123456789012345678901234567890123456789012345678901234"
	var meta: Dictionary = LevelText.parse_key_values(PackedStringArray([
		"format = 2", "book = 2", "kind = coop", "coop_of = w5_l1", "coop_base_hash = " + digits,
		"rise_speed.expert = 24", "modes = grub_stack,hot_rock", "wind = 0:-24,40:24", "wind_loop = 80",
	]))
	assert_eq(meta["coop_base_hash"], digits, "a hash made of digits only stays text")
	assert_true(meta["coop_base_hash"] is String)
	assert_eq(meta["book"], 2)
	assert_eq(meta["rise_speed.expert"], 24)
	assert_eq(LevelText.to_list(meta["modes"]), PackedStringArray(["grub_stack", "hot_rock"]))
	assert_eq(LevelText.meta_book(meta), 2)
	assert_eq(LevelText.meta_book({}), LevelText.BOOK_1, "every 1.0 file is Book I")
	# belt: fresh for book 2 and for co-op files, carry for every other file; the key and its variants win.
	assert_eq(LevelText.meta_belt(meta), LevelText.BELT_FRESH)
	assert_eq(LevelText.meta_belt({}), LevelText.BELT_CARRY, "the 1.0 weapon rule")
	assert_eq(LevelText.meta_belt({"kind": "coop"}), LevelText.BELT_FRESH, "a Book I co-op file")
	assert_eq(LevelText.meta_belt({"book": 2, "kind": "sub"}), LevelText.BELT_FRESH)
	assert_eq(LevelText.meta_belt({"book": 2, "belt": "carry"}), LevelText.BELT_CARRY)
	assert_eq(LevelText.meta_belt({"belt": "carry", "belt.expert": "fresh"}, Defs.Difficulty.EXPERT),
			LevelText.BELT_FRESH)
	assert_eq(LevelText.meta_belt({"belt": "carry", "belt.expert": "fresh"}, Defs.Difficulty.BEGINNER),
			LevelText.BELT_CARRY)
	assert_eq(LevelText.default_belt(1, "arena"), LevelText.BELT_CARRY)
	# The loader resolves every format-2 key with its default, and the same belt rule.
	var text: String = "[meta]\nformat = 2\nid = demo\nbook = 2\nkind = sub\nscroll = rising\nliquid = tar\n" \
			+ "[tiles]\n.@.\n#:#\n"
	var data: LevelData = LevelData.parse(&"demo", text)
	var resolved: Dictionary = data.resolved_meta(Defs.Difficulty.BEGINNER)
	assert_eq(resolved["book"], 2)
	assert_eq(resolved["belt"], LevelText.BELT_FRESH)
	assert_eq(resolved["rise_speed"], Tuning.RISE_SPEED)
	assert_eq(resolved["wrap"], "none")
	assert_eq(resolved["round_time"], 90)
	assert_eq(resolved["wind_loop"], 0)
	assert_eq(resolved["coop_of"], "")
	assert_true(data.build_grid().is_tar(1, 1), "the tar floor of the text")
	var old: Dictionary = LevelData.parse(&"old", "[meta]\nformat = 1\nid = old\n[tiles]\n.@.\n###\n") \
			.resolved_meta(Defs.Difficulty.EXPERT)
	assert_eq(old["book"], 1)
	assert_eq(old["belt"], LevelText.BELT_CARRY)
	for key: String in LevelText.META_KEYS_2:
		assert_true(LevelData.META_KEYS.has(key), "the loader knows %s" % key)


## Level format 2 in the registry (DESIGN.md A.1, D.9; PLAN.md P0.7): campaigns per book, co-op files by
## substitution, arenas; co-op files and arenas never answer a solo query, and every 1.0 query of the Book I files
## answers exactly as before. The metas are added in memory; the registry is rescanned at the end.
func test_registry_books_coop_files_and_arenas() -> void:
	var beginner: int = Defs.Difficulty.BEGINNER
	var expert: int = Defs.Difficulty.EXPERT
	var before: Dictionary = _book1_answers()
	# Book II: A (main 110) -> A2 (sub, its linked half) -> B (main 120) -> C (main 130, Expert only) -> the
	# ending E (C's `next`); co-op files for A, A2 and C, none for B; two arenas. A's co-op copy kept A's `next` and
	# code and is registered first, so a solo query that looked at it would find it before A.
	var add: Dictionary = {
		&"zz2_a_coop": {"kind": "coop", "book": 2, "coop_of": "zz2_a", "tally": false, "next": "zz2_a2",
				"password_beginner": "ZZA1", "bonus": "zz2_bonus"},
		&"zz2_a": {"kind": "main", "book": 2, "order": 110, "tally": false, "next": "zz2_a2",
				"password_beginner": "ZZA1", "password_expert": "ZZA2", "bonus": "zz2_bonus"},
		&"zz2_a2": {"kind": "sub", "book": 2},
		&"zz2_b": {"kind": "main", "book": 2, "order": 120},
		&"zz2_c": {"kind": "main", "book": 2, "order": 130, "min_difficulty": "expert", "next": "zz2_e"},
		&"zz2_e": {"kind": "ending", "book": 2, "min_difficulty": "expert"},
		&"zz2_bonus": {"kind": "bonus", "book": 2},
		&"zz2_a2_coop": {"kind": "coop", "book": 2, "coop_of": "zz2_a2"},
		&"zz2_c_coop": {"kind": "coop", "book": 2, "coop_of": "zz2_c", "min_difficulty": "expert", "next": "zz2_e"},
		&"zz_w1_l1_coop": {"kind": "coop", "coop_of": "w1_l1", "order": 5},
		&"zz_arena_one": {"kind": "arena", "players": 4, "modes": "grub_stack,last_caveman", "order": 1},
		&"zz_arena_two": {"kind": "arena", "players": 2, "modes": "clubball"},
	}
	for id: StringName in add:
		var meta: Dictionary = add[id]
		meta["id"] = String(id)
		Levels._meta[id] = meta
	Levels._index_campaign()
	# Book I: unchanged, whatever lies beside it.
	assert_eq(_book1_answers(), before, "every 1.0 query of the Book I files answers as in 1.0")
	assert_false(Levels.get_campaign(expert).has(&"zz2_a"), "Book II is not in the Book I campaign")
	assert_false(Levels.get_campaign(expert).has(&"zz_w1_l1_coop"), "a co-op file with an order is no map stop")
	assert_false(Levels.get_campaign(expert).has(&"zz_arena_one"), "nor is an arena")
	# Book II.
	assert_eq(Levels.get_campaign(expert, 2), [&"zz2_a", &"zz2_b", &"zz2_c"] as Array[StringName])
	assert_eq(Levels.get_campaign(beginner, 2), [&"zz2_a", &"zz2_b"] as Array[StringName])
	assert_eq(Levels.first_level(2), &"zz2_a")
	assert_eq(Levels.first_level(), &"w1_l1", "the 1.0 call is Book I")
	assert_eq(Levels.first_level(7), &"", "a book without levels")
	assert_eq(Levels.next_level(&"zz2_a", beginner), &"zz2_a2", "the linked half")
	assert_eq(Levels.next_level(&"zz2_a2", beginner), &"zz2_b", "a sub-stage continues in its own book")
	assert_eq(Levels.next_level(&"zz2_b", expert), &"zz2_c")
	assert_eq(Levels.next_level(&"zz2_b", beginner), &"", "Beginner ends before the Expert stage ...")
	assert_true(Levels.has_locked_successor(&"zz2_b", beginner), "... at the expert wall")
	assert_eq(Levels.next_level(&"zz2_c", expert), &"zz2_e", "the trophy's epilogue")
	assert_eq(Levels.parent_level(&"zz2_a2", beginner), &"zz2_a")
	assert_eq(Levels.get_book(&"zz2_a2"), 2)
	assert_eq(Levels.get_book(&"w1_l1"), 1)
	assert_eq(Levels.get_book(&"no_such_level"), 0)
	assert_eq(Levels.get_belt_rule(&"zz2_b"), LevelText.BELT_FRESH, "Book II starts every stage with the club")
	assert_eq(Levels.get_belt_rule(&"w1_l1"), LevelText.BELT_CARRY, "Book I keeps the 1.0 weapon rule")
	assert_eq(Levels.get_belt_rule(&"zz_w1_l1_coop"), LevelText.BELT_FRESH, "co-op files start with the club")
	# Co-op files: by substitution, never in a solo query.
	assert_eq(Levels.get_coop_level(&"zz2_a"), &"zz2_a_coop")
	assert_eq(Levels.get_coop_level(&"zz2_b"), &"", "no co-op file yet")
	assert_eq(Levels.get_coop_level(&"zz2_a_coop"), &"zz2_a_coop")
	assert_eq(Levels.get_coop_level(&"w1_l1"), &"zz_w1_l1_coop")
	assert_eq(Levels.get_coop_base(&"zz2_a2_coop"), &"zz2_a2")
	assert_eq(Levels.get_coop_base(&"zz2_a"), &"", "a solo level has no base")
	assert_eq(Levels.get_coop_campaign(expert, 2), [&"zz2_a_coop", &"zz2_c_coop"] as Array[StringName],
			"the stops with a co-op file")
	assert_eq(Levels.get_coop_campaign(beginner, 1), [&"zz_w1_l1_coop"] as Array[StringName])
	assert_eq(Levels.next_level(&"zz2_a_coop", expert), &"zz2_a2_coop", "the linked half, as a co-op file")
	assert_eq(Levels.next_level(&"zz2_a2_coop", expert), &"zz2_c_coop", "B has no co-op file: passed over")
	assert_eq(Levels.next_level(&"zz2_a2_coop", beginner), &"", "Beginner: nothing after B")
	assert_true(Levels.has_locked_successor(&"zz2_a2_coop", beginner))
	assert_eq(Levels.next_level(&"zz2_c_coop", expert), &"", "no co-op ending yet")
	assert_eq(Levels.parent_level(&"zz2_a2_coop", expert), &"zz2_a", "co-op results go to the solo map stop")
	assert_eq(Levels.parent_level(&"zz_w1_l1_coop", expert), &"w1_l1")
	assert_eq(Levels.parent_level(&"zz2_a2", expert), &"zz2_a", "the co-op copy's `next` never links a solo level")
	assert_eq(Levels.find_by_password("ZZA1"), {"level_id": &"zz2_a", "difficulty": beginner},
			"a code never leads into a co-op file")
	assert_true(Levels.is_coop_level(&"zz2_a_coop"))
	assert_false(Levels.is_solo_level(&"zz2_a_coop"))
	assert_true(Levels.is_solo_level(&"zz2_a"))
	assert_true(Levels.is_solo_level(&"test_example"), "test levels are solo levels")
	assert_eq(Levels.get_level_kind(&"zz2_a_coop"), Levels.KIND_COOP)
	assert_eq(Levels.get_level_kind(&"w1_l1"), Levels.KIND_MAIN)
	assert_eq(Levels.get_level_kind(&"no_such_level"), "")
	# Modes.
	assert_eq(Levels.level_for_mode(&"zz2_a", Defs.GameMode.COOP), &"zz2_a_coop")
	assert_eq(Levels.level_for_mode(&"zz2_bonus", Defs.GameMode.COOP), &"", "no co-op bonus file yet")
	assert_eq(Levels.level_for_mode(&"zz2_a_coop", Defs.GameMode.SINGLE), &"zz2_a")
	assert_eq(Levels.level_for_mode(&"w1_l1", Defs.GameMode.SINGLE), &"w1_l1")
	assert_eq(Levels.level_for_mode(&"zz_arena_one", Defs.GameMode.SINGLE), &"")
	assert_eq(Levels.level_for_mode(&"zz_arena_one", Defs.GameMode.VERSUS), &"zz_arena_one")
	assert_eq(Levels.level_for_mode(&"w1_l1", Defs.GameMode.VERSUS), &"")
	# Arenas.
	assert_eq(Levels.get_arenas(), [&"zz_arena_one", &"zz_arena_two"] as Array[StringName])
	assert_eq(Levels.get_arenas(3), [&"zz_arena_one"] as Array[StringName], "built for 3+ players")
	assert_eq(Levels.get_arenas(0, &"clubball"), [&"zz_arena_two"] as Array[StringName])
	assert_eq(Levels.get_arenas(2, &"hot_rock"), [] as Array[StringName])
	assert_true(Levels.is_arena(&"zz_arena_two"))
	assert_eq(Levels.next_level(&"zz_arena_one", expert), &"")
	assert_eq(Levels.parent_level(&"zz_arena_one", expert), &"")
	for book: int in [1, 2]:
		for difficulty: int in [beginner, expert]:
			for id: StringName in Levels.get_campaign(difficulty, book):
				assert_true(Levels.is_solo_level(id), "%s: only solo files are map stops" % id)
	Levels.rescan()
	assert_eq(_book1_answers(), before, "rescanned")
	assert_false(Levels.has_level(&"zz2_a"))


## Every registry answer the 1.0 game asks about the solo levels of the folder, by difficulty.
func _book1_answers() -> Dictionary:
	var answers: Dictionary = {}
	for difficulty: int in [Defs.Difficulty.BEGINNER, Defs.Difficulty.EXPERT]:
		answers["campaign %d" % difficulty] = Levels.get_campaign(difficulty)
		for id: StringName in Levels.all_ids():
			if String(id).begins_with("zz"):
				continue
			answers["%s %d" % [id, difficulty]] = [
				Levels.next_level(id, difficulty), Levels.has_locked_successor(id, difficulty),
				Levels.parent_level(id, difficulty), Levels.is_available(id, difficulty),
				Levels.get_password(id, difficulty),
			]
			var code: String = Levels.get_password(id, difficulty)
			if code != "":
				answers["code %s" % code] = Levels.find_by_password(code)
	answers["first"] = Levels.first_level()
	return answers


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
