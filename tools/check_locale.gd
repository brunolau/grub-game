extends SceneTree
## Localisation completeness check (owner: ui): every text the game asks a translation for must have an entry in
## the English catalogue `locale/en.po`, the source language; entries that nothing uses are warnings.
##
##   bash .tools/gd.sh script res://tools/check_locale.gd                 report; exit 1 when a key is missing
##   bash .tools/gd.sh script res://tools/check_locale.gd -- --strict     unused entries fail as well
##
## Where the keys come from:
##   scripts/**/*.gd, scenes/**/*.tscn  string literals shaped like a key (UI_..., SIGN_..., ZONE_..., MSG_...,
##                                      HINT_...): tr() / atr() arguments, labels, buttons, prompts and option
##                                      rows created with a key, key tables (ARCHITECTURE.md 8.6: every string is
##                                      a tr() key)
##   CREDITS.md                         the roles of the "Suggested in-game wording" line: UI_CREDITS_<ROLE>
##                                      (scripts/ui/credits.gd builds those keys at run time)
##   levels/*.lvl                       `text=<key>` of signs (objects/sign) and hint zones (zones/message) of
##                                      every level, and the `name` of every shipped level (not test_*.lvl): the
##                                      name is shown through TranslationServer.translate (UiKit.level_name), so it
##                                      is its own msgid
## Also reported: a msgid listed twice or with an empty msgstr in en.po (errors), and keys of en.po that another
## catalogue (de.po, ...) lacks (warnings: that language shows English there).
##
## tests/test_ui_locale.gd runs the same check ([method scan]) with the test suite.

const CATALOGUE: String = "res://locale/en.po"
const LOCALE_DIR: String = "res://locale"
const SOURCE_DIRS: PackedStringArray = ["res://scripts", "res://scenes"]
const LEVEL_DIR: String = "res://levels"
## 2.0 level sub-catalogues (locale/levels/<lang>/*.po, loaded beside the language file, PLAN.md P1.12): the texts of
## Book II, co-op and arena files may live in the English ones instead of en.po (LEVEL_DESIGN.md 15.1). They are no
## language of their own: the "another catalogue lacks a key" warnings skip them.
const LEVEL_LOCALE_DIR: String = "res://locale/levels"
const LEVEL_LOCALE_EN: String = "res://locale/levels/en"
const CREDITS: String = "res://CREDITS.md"
## A string literal that is a translation key.
const KEY_PATTERN: String = "\"((?:UI|SIGN|ZONE|MSG|HINT)_[A-Z0-9_]*[A-Z0-9])\""
## tr("...") / atr("...") with any literal (plain-text keys).
const TR_PATTERN: String = "\\ba?tr\\(\\s*\"([^\"\\\\]+)\"\\s*[,)]"


func _init() -> void:
	var strict: bool = OS.get_cmdline_user_args().has("--strict")
	var report: Dictionary = scan()
	print_report(report)
	var failed: bool = not (report["missing"] as Array).is_empty() or not (report["errors"] as Array).is_empty()
	if strict and not (report["unused"] as Array).is_empty():
		failed = true
	print("check_locale: %s" % ("FAIL" if failed else "OK"))
	quit(1 if failed else 0)


## Run the check. Returns {"keys": number of keys asked for, "entries": number of msgids in en.po,
## "missing": ["KEY (where)", ...], "unused": ["KEY", ...], "errors": [...], "warnings": [...]}.
static func scan() -> Dictionary:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var entries: Dictionary = read_catalogue(CATALOGUE, errors)
	var used: Dictionary = {}  # key -> first place it is used
	for dir_path: String in SOURCE_DIRS:
		for path: String in list_files(dir_path, ["gd", "tscn"]):
			_collect_source(path, used)
	_collect_credits(used)
	var level_used: Dictionary = {}
	_collect_levels(used, level_used)
	var level_entries: Dictionary = {}
	for path: String in list_files(LEVEL_LOCALE_EN, ["po"]):
		level_entries.merge(read_catalogue(path, errors))
	var missing: Array[String] = []
	for key: String in used:
		if not entries.has(key):
			missing.append("%s (%s)" % [key, used[key]])
	for key: String in level_used:
		if entries.has(key):
			_use(used, key, str(level_used[key]))
		elif not level_entries.has(key):
			missing.append("%s (%s; not in en.po nor %s/*.po)" % [key, level_used[key], LEVEL_LOCALE_EN])
	missing.sort()
	var unused: Array[String] = []
	for key: String in entries:
		if not used.has(key):
			unused.append(key)
	unused.sort()
	for path: String in list_files(LOCALE_DIR, ["po"]):
		if path == CATALOGUE or path.begins_with(LEVEL_LOCALE_DIR + "/"):
			continue
		var other: Dictionary = read_catalogue(path, warnings)
		for key: String in entries:
			if not other.has(key):
				warnings.append("%s has no entry for %s (shown in English)" % [path.get_file(), key])
	return {"keys": used.size(), "entries": entries.size(), "missing": missing, "unused": unused, "errors": errors,
		"warnings": warnings}


## Print a report of [method scan] for people.
static func print_report(report: Dictionary) -> void:
	print("check_locale: %d key(s) used, %d entr(ies) in %s" % [report["keys"], report["entries"], CATALOGUE])
	for line: String in report["errors"]:
		print("ERROR   %s" % line)
	for line: String in report["missing"]:
		print("MISSING %s" % line)
	for line: String in report["unused"]:
		print("UNUSED  %s (warning)" % line)
	for line: String in report["warnings"]:
		print("WARNING %s" % line)


## msgid -> msgstr of a .po file (multi-line strings joined). Duplicates and empty texts go to `problems`.
static func read_catalogue(path: String, problems: Array[String]) -> Dictionary:
	var result: Dictionary = {}
	var text: String = FileAccess.get_file_as_string(path)
	if text.is_empty():
		problems.append("%s is missing or empty" % path)
		return result
	var key: String = ""
	var value: String = ""
	var field: String = ""
	for raw: String in (text + "\n").split("\n"):
		var line: String = raw.strip_edges()
		if line.begins_with("msgid "):
			_store(path, key, value, result, problems)
			key = _unquote(line.substr(6))
			value = ""
			field = "id"
		elif line.begins_with("msgstr "):
			value = _unquote(line.substr(7))
			field = "str"
		elif line.begins_with("\"") and field != "":
			if field == "id":
				key += _unquote(line)
			else:
				value += _unquote(line)
		elif line.is_empty() or line.begins_with("#"):
			_store(path, key, value, result, problems)
			key = ""
			value = ""
			field = ""
	return result


static func _store(path: String, key: String, value: String, result: Dictionary, problems: Array[String]) -> void:
	if key.is_empty():
		return
	if result.has(key):
		problems.append("%s lists %s twice" % [path.get_file(), key])
	elif value.is_empty():
		problems.append("%s: %s has an empty text" % [path.get_file(), key])
	result[key] = value


static func _unquote(text: String) -> String:
	var trimmed: String = text.strip_edges()
	if trimmed.length() >= 2 and trimmed.begins_with("\"") and trimmed.ends_with("\""):
		trimmed = trimmed.substr(1, trimmed.length() - 2)
	return trimmed.c_unescape()


## Every file below `dir_path` (recursively) with one of the extensions, sorted.
static func list_files(dir_path: String, extensions: PackedStringArray) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return result
	for file_name: String in dir.get_files():
		if extensions.has(file_name.get_extension()):
			result.append(dir_path.path_join(file_name))
	for sub: String in dir.get_directories():
		if not sub.begins_with("."):
			result.append_array(list_files(dir_path.path_join(sub), extensions))
	result.sort()
	return result


static func _collect_source(path: String, used: Dictionary) -> void:
	var text: String = FileAccess.get_file_as_string(path)
	var place: String = path.trim_prefix("res://")
	for pattern: String in [KEY_PATTERN, TR_PATTERN]:
		for found: RegExMatch in RegEx.create_from_string(pattern).search_all(text):
			_use(used, found.get_string(1), "%s:%d" % [place, _line_of(text, found.get_start())])


## The credits roll builds UI_CREDITS_<ROLE> from the roles of the suggested wording in CREDITS.md.
static func _collect_credits(used: Dictionary) -> void:
	var text: String = FileAccess.get_file_as_string(CREDITS)
	var at: int = text.find("Suggested in-game wording:")
	if at < 0:
		return
	var wording: String = text.substr(at).get_slice("\n", 0).get_slice("\"", 1)
	var roles: RegEx = RegEx.create_from_string("([A-Z][a-z]+): ")
	for found: RegExMatch in roles.search_all(wording):
		_use(used, "UI_CREDITS_" + found.get_string(1).to_upper(), "CREDITS.md (credits roll)")


## 2.0 (PLAN.md P1.3): only the Book I solo files ask locale/en.po; the keys of Book II, co-op and arena files go to
## `level_used` and may also come from the English level sub-catalogues (LEVEL_LOCALE_EN, LEVEL_DESIGN.md 15.1).
static func _collect_levels(used: Dictionary, level_used: Dictionary = {}) -> void:
	var keys: RegEx = RegEx.create_from_string("(?:^|\\s)text=([^\\s]+)")
	var names: RegEx = RegEx.create_from_string("(?m)^\\s*name\\s*=\\s*\"((?:[^\"\\\\]|\\\\.)*)\"")
	for path: String in list_files(LEVEL_DIR, ["lvl"]):
		var text: String = FileAccess.get_file_as_string(path)
		var place: String = path.trim_prefix("res://")
		var meta: Dictionary = LevelText.parse_meta(text)
		var kind: String = str(meta.get("kind", "main"))
		var book1_solo: bool = LevelText.meta_book(meta) == LevelText.BOOK_1 and kind != LevelText.KIND_COOP \
				and kind != LevelText.KIND_ARENA
		var target: Dictionary = used if book1_solo else level_used
		for found: RegExMatch in keys.search_all(text):
			_use(target, found.get_string(1), "%s:%d" % [place, _line_of(text, found.get_start(1))])
		if path.get_file().begins_with("test_"):
			continue
		var name: RegExMatch = names.search(text)
		if name != null:
			_use(target, name.get_string(1).c_unescape(), "%s (level name)" % place)


static func _use(used: Dictionary, key: String, place: String) -> void:
	if not used.has(key):
		used[key] = place


static func _line_of(text: String, offset: int) -> int:
	return text.substr(0, maxi(offset, 0)).count("\n") + 1
