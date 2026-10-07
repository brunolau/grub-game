extends TestCase
## ui module: localisation completeness. Runs tools/check_locale.gd: every key the scripts, scenes, CREDITS.md and
## level files ask a translation for is in locale/en.po (no duplicates, no empty texts); unused entries are only
## reported.

const CHECKER: String = "res://tools/check_locale.gd"
const CATALOGUE: String = "res://locale/en.po"


func test_every_text_the_game_shows_is_in_the_english_catalogue() -> void:
	var checker: GDScript = load(CHECKER) as GDScript
	assert_not_null(checker, "the check exists")
	if checker == null:
		return
	var report: Dictionary = checker.call("scan")
	assert_true(int(report["keys"]) > 100, "keys found: %d" % int(report["keys"]))
	assert_eq(report["missing"], [] as Array[String], "keys without an entry in locale/en.po")
	assert_eq(report["errors"], [] as Array[String], "catalogue problems")
	for key: String in report["unused"]:
		print("    warning: locale/en.po entry %s is not used" % key)


## Level names are shown through TranslationServer (UiKit.level_name): each shipped level's name is a msgid of the
## catalogue, so a translator can translate it.
func test_level_names_and_sign_texts_are_catalogue_entries() -> void:
	var catalogue: Translation = load(CATALOGUE) as Translation
	assert_not_null(catalogue)
	if catalogue == null:
		return
	for level_id: StringName in Levels.all_ids():
		# The 1.0 stages: Book I solo files (2.0 Book II / co-op names live in locale/levels/<lang>/*.po, P1.12).
		if str(Levels.get_value(level_id, "kind", Levels.KIND_MAIN)) == Levels.KIND_TEST \
				or Levels.get_book(level_id) != Levels.BOOK_1 or not Levels.is_solo_level(level_id):
			continue
		var raw: String = str(Levels.get_value(level_id, "name", ""))
		assert_ne(raw, "", "%s has a name" % level_id)
		assert_eq(String(catalogue.get_message(raw)), raw, "%s: '%s' is an entry of en.po" % [level_id, raw])
	assert_true(String(catalogue.get_message("SIGN_W1_CLUB")).begins_with("Odd-looking"), "sign texts")
