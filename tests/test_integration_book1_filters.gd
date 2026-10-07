extends TestCase
## The 1.0 checks see Book I only (owner: integration; docs/expansion/PLAN.md P1.3, first step).
##
## Every 1.0 test and development tool that walked the level folder treated each non-test level as a Book I solo
## stage (the stage order, the code count, the translations, the signs). Since 2.0 the folder also holds Book II
## files, co-op files and arenas, so those checks filter on `Levels.get_book(id) == 1 and Levels.is_solo_level(id)`.
## This test puts a Book II stage, a co-op file and an arena into the registry - in memory, their texts under build/,
## so no other test run sees them - each built to trip the old checks (a bonus key of Book I, codes, a name and a
## sign text that locale/en.po does not know), and runs the 1.0 checks against that registry.

const OUT_DIR: String = "res://build/test_integration_book1_filters/"
const CAMPAIGN_TEST: String = "res://tests/test_campaign_routes.gd"
const LOCALE_TEST: String = "res://tests/test_ui_locale.gd"
const SIGN_PREVIEW: String = "res://scripts/ui/dev/sign_preview.gd"
## The fakes: id -> level text. Book II stage (with a Book I bonus, codes, an unknown name and sign text), a Book I
## co-op file and an arena (unknown names and texts too).
const FAKES: Dictionary = {
	&"zz2_fake_stage": "[meta]\nid = \"zz2_fake_stage\"\nformat = 2\nbook = 2\nname = \"ZZ FAKE BOOK II STAGE\"\n" +
		"world = 5\norder = 1\nbonus = \"bonus_a\"\npassword_beginner = \"ZQ2B\"\npassword_expert = \"ZQ2E\"\n\n" +
		"[entities]\nobjects/sign 3 4 text=SIGN_ZZ_FAKE_STAGE\nitems/weapon 6 4 kind=hammer\n",
	&"zz_w1_l1_coop_fake": "[meta]\nid = \"zz_w1_l1_coop_fake\"\nformat = 2\nkind = coop\ncoop_of = \"w1_l1\"\n" +
		"name = \"ZZ FAKE CO-OP FILE\"\n\n[entities]\nobjects/sign 3 4 text=SIGN_ZZ_FAKE_COOP\n",
	&"zz_arena_fake": "[meta]\nid = \"zz_arena_fake\"\nformat = 2\nkind = arena\nplayers = 4\n" +
		"modes = \"grub_stack\"\nname = \"ZZ FAKE ARENA\"\n\n[entities]\nobjects/sign 3 4 text=SIGN_ZZ_FAKE_ARENA\n",
}

var _injected: bool = false


func after_each() -> void:
	if _injected:
		Levels.rescan()
		_injected = false


## Register the fakes in memory (Levels._meta / _paths, as tests/test_core_level_text.gd and the bench's snapshot do).
func _inject() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	for id: StringName in FAKES:
		var path: String = OUT_DIR + String(id) + ".lvl"
		var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
		file.store_string(str(FAKES[id]))
		file.close()
		Levels._meta[id] = Levels.parse_meta(str(FAKES[id]))
		Levels._paths[id] = path
	Levels._index_campaign()
	_injected = true


## Run test method `method` of the test file `path` on a fresh instance; returns its failures.
func _run_other(path: String, method: StringName) -> PackedStringArray:
	var other: TestCase = (load(path) as GDScript).new() as TestCase
	add_node(other)
	other._begin_test()
	other.call(method)
	var failures: PackedStringArray = other._failures.duplicate()
	if other._checks == 0:
		failures.append("%s made no assertion" % method)
	return failures


func test_the_fakes_are_what_the_old_checks_tripped_over() -> void:
	_inject()
	assert_eq(Levels.get_book(&"zz2_fake_stage"), Levels.BOOK_2)
	assert_true(Levels.is_coop_level(&"zz_w1_l1_coop_fake"))
	assert_true(Levels.is_arena(&"zz_arena_fake"))
	assert_eq(Levels.get_campaign(Defs.Difficulty.EXPERT, Levels.BOOK_2), [&"zz2_fake_stage"] as Array[StringName])
	var not_test: int = 0
	for level_id: StringName in Levels.all_ids():
		if Levels.get_level_kind(level_id) != Levels.KIND_TEST:
			not_test += 1
	var book1: Array[StringName] = (load(CAMPAIGN_TEST) as GDScript).call("book1_stages")
	assert_eq(not_test, book1.size() + FAKES.size(), "the old filter (kind != test) would take the fakes as stages")
	assert_eq(book1.size(), 15, "the 15 Book I stages")
	for id: StringName in FAKES:
		assert_false(book1.has(id), "%s is no Book I stage" % id)
	var catalogue: Translation = load("res://locale/en.po") as Translation
	assert_eq(String(catalogue.get_message("ZZ FAKE BOOK II STAGE")), "", "en.po does not know the fake name")
	assert_false(FileAccess.get_file_as_string("res://locale/en.po").contains("SIGN_ZZ_FAKE_STAGE"),
			"en.po does not know the fake sign text")


## tests/test_campaign_routes.gd: the campaign's shape, the codes, the translations and the stage order pass with
## Book II, co-op and arena files beside the Book I files.
func test_the_campaign_shape_checks_see_book1_only() -> void:
	_inject()
	for method: StringName in [&"test_the_campaign_order_and_links", &"test_every_stage_has_a_unique_code_per_mode",
			&"test_every_level_text_is_translated", &"test_every_weapon_a_run_can_bring_has_a_route"]:
		assert_eq(_run_other(CAMPAIGN_TEST, method), PackedStringArray(), String(method))


## tests/test_ui_locale.gd (the level names of en.po) and the sign preview (scripts/ui/dev/sign_preview.gd).
func test_the_ui_checks_and_tools_see_book1_only() -> void:
	_inject()
	assert_eq(_run_other(LOCALE_TEST, &"test_level_names_and_sign_texts_are_catalogue_entries"), PackedStringArray())
	var signs: Array[StringName] = (load(SIGN_PREVIEW) as GDScript).call("levels_with_signs")
	assert_true(signs.has(&"w1_l1"), "the Book I stages with signs: %s" % str(signs))
	for id: StringName in FAKES:
		assert_false(signs.has(id), "the sign preview does not start %s in a Book I run" % id)


## A Book II code that repeats a Book I code (read as the code screen reads it) is caught.
func test_a_book2_code_may_not_repeat_a_book1_code() -> void:
	_inject()
	var meta: Dictionary = Levels._meta[&"zz2_fake_stage"]
	meta["password_expert"] = "GROT"  # 3-2 Crystal Grotto's Beginner code GR0T, typed with the letter O
	var failures: PackedStringArray = _run_other(CAMPAIGN_TEST, &"test_every_stage_has_a_unique_code_per_mode")
	assert_eq(failures.size(), 1, "\n".join(failures))
	assert_true(failures.size() == 1 and failures[0].contains("zz2_fake_stage"), str(failures))
