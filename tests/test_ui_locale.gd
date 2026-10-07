extends TestCase
## ui module: localisation completeness. Runs tools/check_locale.gd: every key the scripts, scenes, CREDITS.md and
## level files ask a translation for is in locale/en.po (no duplicates, no empty texts); unused entries are only
## reported. 2.0 (ui-B, PLAN.md P1.12 / 6.1): the level texts of the Book II and co-op designers live in sub-catalogues
## `locale/levels/<lang>/*.po`, loaded beside the language file (UiKit.load_level_catalogues) and never offered as a
## language: a key found in a sub-catalogue of English counts as present.

const CHECKER: String = "res://tools/check_locale.gd"
const CATALOGUE: String = "res://locale/en.po"
const LEVEL_CATALOGUES: String = "res://locale/levels"
## Scratch folder of the sub-catalogue test (build/ is never shipped).
const SCRATCH: String = "res://build/test_ui_locale/levels"

var _added: Array[Translation] = []


func after_each() -> void:
	for catalogue: Translation in _added:
		TranslationServer.remove_translation(catalogue)
	_added.clear()
	var locale: String = str(Settings.get_value("game/locale", ""))
	TranslationServer.set_locale(locale if locale != "" else OS.get_locale())


func test_every_text_the_game_shows_is_in_the_english_catalogue() -> void:
	var checker: GDScript = load(CHECKER) as GDScript
	assert_not_null(checker, "the check exists")
	if checker == null:
		return
	var report: Dictionary = checker.call("scan")
	assert_true(int(report["keys"]) > 100, "keys found: %d" % int(report["keys"]))
	var sub: Dictionary = _english_sub_entries(checker)
	var missing: Array[String] = []
	for line: String in report["missing"]:
		if not sub.has(line.get_slice(" (", 0)):
			missing.append(line)
	assert_eq(missing, [] as Array[String], "keys without an entry in locale/en.po or locale/levels/en/*.po")
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


## A sub-catalogue `levels/<lang>/<file>.po` translates its keys for the locale of its folder (whatever its header
## says), beside the language file, and never becomes a language of Options; the shipped ones are loaded at start.
func test_level_sub_catalogues_load_beside_the_language_file() -> void:
	UiKit.ensure_locale()
	_write(SCRATCH + "/en/ui_b_test.po", _po("en", "SIGN_UI_B_SUBCATALOGUE", "Read me from a sub-catalogue"))
	_write(SCRATCH + "/eo/ui_b_test.po", _po("en", "SIGN_UI_B_SUBCATALOGUE", "Legu min"))
	var before: PackedStringArray = UiKit.available_locales()
	_added = UiKit.load_level_catalogues(SCRATCH)
	assert_eq(_added.size(), 2, "both sub-catalogues loaded")
	if _added.size() != 2:
		return
	assert_eq(String(_added[0].locale), "en")
	assert_eq(String(_added[1].locale), "eo", "the folder names the locale, not the header")
	TranslationServer.set_locale("en")
	assert_eq(String(TranslationServer.translate("SIGN_UI_B_SUBCATALOGUE")), "Read me from a sub-catalogue")
	assert_eq(String(TranslationServer.translate("UI_TITLE_START")), "Start Game", "the language file still answers")
	TranslationServer.set_locale("eo")
	assert_eq(String(TranslationServer.translate("SIGN_UI_B_SUBCATALOGUE")), "Legu min")
	TranslationServer.set_locale("en")
	assert_eq(UiKit.available_locales(), before, "a sub-catalogue is never offered as a language")
	assert_false(UiKit.available_locales().has("eo"))
	# The shipped sub-catalogues (PLAN.md 6.1: w5.po ... coop_b2.po) are loaded at start and well formed.
	var checker: GDScript = load(CHECKER) as GDScript
	if checker == null:
		return
	for locale: String in UiKit._list_entries(LEVEL_CATALOGUES, true):
		TranslationServer.set_locale(locale)
		for file_name: String in UiKit._list_entries(LEVEL_CATALOGUES.path_join(locale), false):
			var problems: Array[String] = []
			var path: String = LEVEL_CATALOGUES.path_join(locale).path_join(file_name)
			var entries: Dictionary = checker.call("read_catalogue", path, problems)
			assert_eq(problems, [] as Array[String], "%s has no problems" % path)
			for key: String in entries:
				assert_eq(String(TranslationServer.translate(key)), str(entries[key]), "%s: %s" % [path, key])
	TranslationServer.set_locale("en")


## Every msgid of the English level sub-catalogues (msgid -> msgstr).
func _english_sub_entries(checker: GDScript) -> Dictionary:
	var result: Dictionary = {}
	var dir: String = LEVEL_CATALOGUES.path_join("en")
	for file_name: String in UiKit._list_entries(dir, false):
		if file_name.get_extension() != "po":
			continue
		var problems: Array[String] = []
		var entries: Dictionary = checker.call("read_catalogue", dir.path_join(file_name), problems)
		result.merge(entries)
	return result


func _po(language: String, key: String, text: String) -> String:
	var lines: PackedStringArray = [
		"msgid \"\"", "msgstr \"\"", "\"Language: %s\\n\"" % language,
		"\"Content-Type: text/plain; charset=UTF-8\\n\"", "", "msgid \"%s\"" % key, "msgstr \"%s\"" % text, "",
	]
	return "\n".join(lines)


func _write(path: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path).get_base_dir())
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()
