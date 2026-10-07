extends TestCase
## Book I is frozen (docs/expansion/PLAN.md 2.3 and 8 V1.d). Owner: core.
##
## The 15 Book I level files and the 72 Book I route files of 1.0.0 are never edited: their sha256 must equal
## tests/fixtures/book1_hashes.txt (frozen once by PLAN P0.1; hashes over the text with every CR removed, i.e. the
## bytes git stores, so a Windows checkout with CRLF copies passes as tools/sp_identity.sh does). The list must also
## still name exactly the Book I files of the tree: every solo level of book 1 that is not a test level, every route
## file without a `# route:` header (a 1.0 route), and every route of the 1.0 ROUTES table.
##
## Drift check (PLAN.md P0.9: the guard must fail on a deliberately drifted copy and pass on the tree):
##   BOOK1_FROZEN_ROOT=<dir> checks the copy under <dir> (<dir>/levels/..., <dir>/tools/autoplay/routes/...) instead
##   of res://, e.g. `BOOK1_FROZEN_ROOT=res://build/guard_drift/book1 bash .tools/gd.sh test core_book1` must FAIL.

const HASHES: String = "res://tests/fixtures/book1_hashes.txt"
const LEVEL_PREFIX: String = "levels/"
const ROUTE_PREFIX: String = "tools/autoplay/routes/"
const ROUTES_TEST: String = "res://tests/test_campaign_routes.gd"
const LEVELS: int = 15
const ROUTES: int = 72


## The fixture as [hash, relative path] pairs ('#' and blank lines skipped).
func _frozen() -> Array[PackedStringArray]:
	var pairs: Array[PackedStringArray] = []
	for line: String in FileAccess.get_file_as_string(HASHES).split("\n"):
		var text: String = line.strip_edges()
		if text.is_empty() or text.begins_with("#"):
			continue
		var parts: PackedStringArray = text.split(" ", false)
		pairs.append(PackedStringArray([parts[0], parts[parts.size() - 1]]))
	return pairs


func _root() -> String:
	var root: String = OS.get_environment("BOOK1_FROZEN_ROOT")
	return "res://" if root.is_empty() else root.trim_suffix("/") + "/"


## sha256 (hex) of a file's bytes with every CR removed; "" when the file cannot be read.
static func text_sha256(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
	var lf: PackedByteArray = PackedByteArray()
	lf.resize(bytes.size())
	var size: int = 0
	for byte: int in bytes:
		if byte != 13:
			lf[size] = byte
			size += 1
	lf.resize(size)
	var context: HashingContext = HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(lf)
	return context.finish().hex_encode()


func test_the_book1_files_are_unchanged() -> void:
	var root: String = _root()
	if root != "res://":
		print("    book1_frozen: checking the copy %s" % root)
	var pairs: Array[PackedStringArray] = _frozen()
	assert_eq(pairs.size(), LEVELS + ROUTES, "the list names 15 levels and 72 routes")
	var changed: PackedStringArray = PackedStringArray()
	for pair: PackedStringArray in pairs:
		var found: String = text_sha256(root + pair[1])
		if found != pair[0]:
			changed.append("%s (%s)" % [pair[1], "missing" if found.is_empty() else "sha256 " + found])
	assert_eq(changed, PackedStringArray(), "frozen Book I files changed - never edit them (PLAN.md 2.3)")


func test_the_list_names_every_book1_file() -> void:
	var root: String = _root()
	var listed: Dictionary = {}
	for pair: PackedStringArray in _frozen():
		listed[pair[1]] = true
	# Every Book I solo level of the registry (not a test level) is frozen; nothing else under levels/ is listed.
	var levels: PackedStringArray = PackedStringArray()
	for level_id: StringName in Levels.all_ids():
		if Levels.get_book(level_id) == 1 and Levels.is_solo_level(level_id) \
				and Levels.get_level_kind(level_id) != Levels.KIND_TEST:
			levels.append(LEVEL_PREFIX + String(level_id) + ".lvl")
	levels.sort()
	var listed_levels: PackedStringArray = PackedStringArray()
	for path: String in listed:
		if path.begins_with(LEVEL_PREFIX):
			listed_levels.append(path)
	listed_levels.sort()
	assert_eq(levels, listed_levels, "the Book I levels of the registry are the frozen ones")
	assert_eq(levels.size(), LEVELS)
	# Every 1.0 route file (no `# route:` header) is frozen, and the 1.0 ROUTES table describes exactly them.
	var routes: PackedStringArray = PackedStringArray()
	for file: String in DirAccess.get_files_at(root + ROUTE_PREFIX):
		if file.get_extension() == "inputs" and \
				Autoplay.parse_route_header(FileAccess.get_file_as_string(root + ROUTE_PREFIX + file)).is_empty():
			routes.append(ROUTE_PREFIX + file)
	routes.sort()
	var listed_routes: PackedStringArray = PackedStringArray()
	for path: String in listed:
		if path.begins_with(ROUTE_PREFIX):
			listed_routes.append(path)
	listed_routes.sort()
	assert_eq(routes, listed_routes, "the route files without a header are the frozen 1.0 routes")
	assert_eq(listed_routes.size(), ROUTES)
	var table: PackedStringArray = PackedStringArray()
	for file: String in (load(ROUTES_TEST) as GDScript).get_script_constant_map()["ROUTES"]:
		table.append(ROUTE_PREFIX + file)
	table.sort()
	assert_eq(table, listed_routes, "the 1.0 ROUTES table names the frozen routes")


func test_hashes_read_crlf_as_lf() -> void:
	var dir: String = "res://build/test_core_book1_frozen/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	for pair: Array in [["lf.txt", "a\nb\n"], ["crlf.txt", "a\r\nb\r\n"], ["other.txt", "a\nc\n"]]:
		var file: FileAccess = FileAccess.open(dir + str(pair[0]), FileAccess.WRITE)
		file.store_buffer(str(pair[1]).to_utf8_buffer())
		file.close()
	var lf: String = text_sha256(dir + "lf.txt")
	assert_eq(lf, "a\nb\n".sha256_text(), "the sha256 of the text")
	assert_eq(text_sha256(dir + "crlf.txt"), lf, "a CRLF copy is the same file")
	assert_ne(text_sha256(dir + "other.txt"), lf, "one changed byte is not")
	assert_eq(text_sha256(dir + "missing.txt"), "")
