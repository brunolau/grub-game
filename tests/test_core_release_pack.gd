extends TestCase
## What a release build holds (docs/expansion/PLAN.md P4.6): no developer level, test, tool or recorder, no asset
## outside docs/ASSET_MANIFEST.md, no file the export filters do not allow.
##
## Two proofs:
##  1. THE FILTERS, on every run: the file list each preset of export_presets.cfg ships is worked out from the
##     project folder the way the exporter does it ("all resources" plus the include filter, minus the exclude
##     filter, wildcards matched as Godot matches them) and every file of it is judged by [method forbidden].
##  2. THE EXE, when one is named: the environment variable CLUBANDGRUB_RELEASE_EXE names an exported
##     ClubAndGrub.exe (tools/build_windows.ps1 sets it for the exe it has just exported). The test reads the file
##     table of the pack embedded in that exe, judges every packed file the same way and compares the table with
##     the list of proof 1: nothing more, nothing less. Without the variable the test says so in a `pack:` line and
##     checks no exe - a build that leaves the machine always goes through the build script.

const PRESETS_PATH: String = "res://export_presets.cfg"
const MANIFEST_PATH: String = "res://docs/ASSET_MANIFEST.md"
const EXE_VARIABLE: String = "CLUBANDGRUB_RELEASE_EXE"
const PLATFORMS: PackedStringArray = ["Windows Desktop", "macOS", "Android", "iOS"]
## The folders a shipped file lies in, and the two shipped files of the project root.
const SHIPPED_ROOTS: PackedStringArray = ["assets", "scripts", "scenes", "levels", "locale", "resources"]
const SHIPPED_ROOT_FILES: PackedStringArray = ["CREDITS.md", "default_bus_layout.tres"]
## Development folders of the project root.
const DEVELOPMENT_ROOTS: PackedStringArray = ["tests", "tools", "docs", "build", "installer", ".tools", ".godot"]
## Tools that live beside game code: the level validator and the solo-impossibility search of the co-op gates are
## used by tools/ and tests/ only (no shipped script names them), so no export carries them.
const TOOL_SCRIPTS: PackedStringArray = ["scripts/world/level_validator.gd", "scripts/world/coop_search.gd"]
## File types that are tools or their input, wherever they lie.
const TOOL_EXTENSIONS: PackedStringArray = ["py", "sh", "ps1", "cmd", "bat", "flow", "inputs", "iss"]
## Files the exporter adds for the engine itself.
const ENGINE_FILES: PackedStringArray = [
	"project.binary", ".godot/global_script_class_cache.cfg", ".godot/uid_cache.bin",
]
const PACK_MAGIC: int = 0x43504447  # "GDPC"
## Pack format this reader was written against (Godot 4.7.2 writes it); another one fails the test, loudly.
const PACK_FORMAT: int = 4
const PACK_DIR_ENCRYPTED: int = 1
const PACK_REL_FILEBASE: int = 2
const PACK_FILE_REMOVAL: int = 2

## Every name docs/ASSET_MANIFEST.md writes in backticks (read once).
static var _manifest_names: Dictionary = {}
static var _tree: PackedStringArray = PackedStringArray()
## The file list of a pair of filters, worked out once (the four presets share theirs).
static var _shipped_cache: Dictionary = {}


# --- The rules -----------------------------------------------------------------------------------------------------

## Why `path` (a project path without "res://") must not be inside a release build, or "" when it may.
static func forbidden(path: String) -> String:
	var name: String = path.get_file()
	var root: String = path.get_slice("/", 0)
	if DEVELOPMENT_ROOTS.has(root):
		return "lies in the development folder %s/" % root
	if path.contains("/dev/"):
		return "lies in a dev folder"
	if name.begins_with("test_"):
		return "is a developer level or a test file (test_*)"
	if name.to_lower().contains("recorder"):
		return "is a recorder"
	if name.begins_with("debug_level"):
		return "is the debug level"
	if TOOL_EXTENSIONS.has(name.get_extension().to_lower()):
		return "is a tool file (.%s)" % name.get_extension()
	if TOOL_SCRIPTS.has(path):
		return "is a development tool"
	for development: String in Autoplay.DEVELOPMENT_PATHS:
		var plain: String = development.trim_prefix("res://")
		if path == plain or path.begins_with(plain + "/"):
			return "is a development file (Autoplay.DEVELOPMENT_PATHS)"
	if not path.contains("/"):
		return "" if SHIPPED_ROOT_FILES.has(path) else "is no shipped file of the project root"
	if not SHIPPED_ROOTS.has(root):
		return "lies outside the shipped folders"
	if root == "assets" and not in_manifest(path):
		return "is an asset docs/ASSET_MANIFEST.md does not list"
	return ""


## True when docs/ASSET_MANIFEST.md names the asset `path` ("assets/..."): in backticks, with or without the
## leading "assets/", as the manifest writes every file.
static func in_manifest(path: String) -> bool:
	if _manifest_names.is_empty():
		var parts: PackedStringArray = FileAccess.get_file_as_string(MANIFEST_PATH).split("`")
		for i: int in range(1, parts.size(), 2):
			_manifest_names[parts[i]] = true
	return _manifest_names.has(path) or _manifest_names.has(path.trim_prefix("assets/"))


# --- The file list of a preset, worked out from the project folder -------------------------------------------------

## Every file of the project folder the editor knows (project paths without "res://"): hidden folders, folders with
## a .gdignore and nested projects are no part of the project.
static func project_files() -> PackedStringArray:
	if _tree.is_empty():
		_walk("res://", _tree)
		_tree.sort()
	return _tree


static func _walk(dir_path: String, into: PackedStringArray) -> void:
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return
	for file: String in dir.get_files():
		into.append((dir_path + file).trim_prefix("res://"))
	for sub: String in dir.get_directories():
		var sub_path: String = dir_path + sub + "/"
		if sub.begins_with(".") or FileAccess.file_exists(sub_path + ".gdignore") \
				or FileAccess.file_exists(sub_path + "project.godot"):
			continue
		_walk(sub_path, into)


## True when the editor exports `path` under "export all resources": an imported file (it has a .import beside
## it) or a file type the engine loads as a resource (scripts, scenes, resources, shaders, JSON, translations).
static func is_resource(path: String, resource_extensions: PackedStringArray) -> bool:
	if path.ends_with(".import") or path.ends_with(".uid"):
		return false
	if FileAccess.file_exists("res://" + path + ".import"):
		# A file the editor is told to skip (the sheets of the bitmap fonts: their pixels are inside the imported
		# .fnt) is no resource and is not exported.
		return not FileAccess.get_file_as_string("res://" + path + ".import").contains('importer="skip"')
	return resource_extensions.has(path.get_extension().to_lower())


static func _patterns(filter: String) -> PackedStringArray:
	var patterns: PackedStringArray = PackedStringArray()
	for pattern: String in filter.split(",", false):
		if not pattern.strip_edges().is_empty():
			patterns.append(pattern.strip_edges())
	return patterns


static func _matches(path: String, patterns: PackedStringArray) -> bool:
	for pattern: String in patterns:
		# The exporter tries the path with and without "res://".
		if path.matchn(pattern) or ("res://" + path).matchn(pattern):
			return true
	return false


## The project files a preset ships: {"files": PackedStringArray, "error": String}.
static func shipped_files(presets: ConfigFile, section: String) -> Dictionary:
	if str(presets.get_value(section, "export_filter", "")) != "all_resources":
		return {"files": PackedStringArray(), "error": "export_filter is not all_resources"}
	var include_filter: String = str(presets.get_value(section, "include_filter", ""))
	var exclude_filter: String = str(presets.get_value(section, "exclude_filter", ""))
	var cache_key: String = include_filter + " | " + exclude_filter
	if not _shipped_cache.has(cache_key):
		var includes: PackedStringArray = _patterns(include_filter)
		var excludes: PackedStringArray = _patterns(exclude_filter)
		var extensions: PackedStringArray = ResourceLoader.get_recognized_extensions_for_type("")
		var files: PackedStringArray = PackedStringArray()
		for path: String in project_files():
			if path.ends_with(".import") or path.ends_with(".uid"):
				continue
			if (is_resource(path, extensions) or _matches(path, includes)) and not _matches(path, excludes):
				files.append(path)
		_shipped_cache[cache_key] = files
	return {"files": _shipped_cache[cache_key], "error": ""}


static func _preset_section(presets: ConfigFile, platform: String) -> String:
	for section: String in presets.get_sections():
		if not section.ends_with(".options") and str(presets.get_value(section, "platform", "")) == platform:
			return section
	return ""


func _presets() -> ConfigFile:
	var presets: ConfigFile = ConfigFile.new()
	assert_eq(presets.load(PRESETS_PATH), OK, "export_presets.cfg is readable")
	return presets


# --- The file table of an exported exe -----------------------------------------------------------------------------

## The paths packed inside an exported exe (the pack embedded at its end), read from the pack's file table:
## {"paths": PackedStringArray, "error": String, "engine": String}.
static func read_pack(exe_path: String) -> Dictionary:
	var result: Dictionary = {"paths": PackedStringArray(), "error": "", "engine": ""}
	var file: FileAccess = FileAccess.open(exe_path, FileAccess.READ)
	if file == null:
		result["error"] = "cannot open %s (error %d)" % [exe_path, FileAccess.get_open_error()]
		return result
	var size: int = file.get_length()
	if size < 128:
		result["error"] = "%s is no exported game (%d bytes)" % [exe_path, size]
		return result
	file.seek(size - 4)
	if file.get_32() != PACK_MAGIC:
		result["error"] = "%s has no embedded pack (the preset must embed it: binary_format/embed_pck)" % exe_path
		return result
	file.seek(size - 12)
	var pack_size: int = file.get_64()
	var start: int = size - 12 - pack_size
	if pack_size <= 0 or start < 0:
		result["error"] = "the pack size at the end of %s is wrong (%d)" % [exe_path, pack_size]
		return result
	file.seek(start)
	if file.get_32() != PACK_MAGIC:
		result["error"] = "no pack header where the end of %s says it starts" % exe_path
		return result
	var format: int = file.get_32()
	result["engine"] = "%d.%d.%d" % [file.get_32(), file.get_32(), file.get_32()]
	var flags: int = file.get_32()
	file.get_64()  # the base offset of the file data
	if format != PACK_FORMAT or (flags & PACK_REL_FILEBASE) == 0 or (flags & PACK_DIR_ENCRYPTED) != 0:
		result["error"] = "pack format %d with flags %d (engine %s): this reader knows format %d with relative offsets and a plain file table - check read_pack() against the engine before trusting it" % [
			format, flags, result["engine"], PACK_FORMAT]
		return result
	var table: int = start + file.get_64()
	if table <= start or table >= size:
		result["error"] = "the file table of the pack lies outside the file"
		return result
	file.seek(table)
	var count: int = file.get_32()
	if count <= 0 or count > 1000000:
		result["error"] = "the pack names %d files" % count
		return result
	var paths: PackedStringArray = PackedStringArray()
	for i: int in count:
		var length: int = file.get_32()
		if length <= 0 or length > 4096 or file.get_position() + length + 36 > size:
			result["error"] = "entry %d of the file table is damaged" % i
			return result
		var raw: PackedByteArray = file.get_buffer(length)
		var end: int = raw.find(0)
		var path: String = (raw.slice(0, end) if end >= 0 else raw).get_string_from_utf8()
		file.get_64()  # offset
		file.get_64()  # size
		file.get_buffer(16)  # md5
		var entry_flags: int = file.get_32()
		if (entry_flags & PACK_FILE_REMOVAL) == 0:
			paths.append(path.trim_prefix("res://"))
	paths.sort()
	result["paths"] = paths
	return result


## The project file a packed path stands for: {"source": String, "kind": String}. `kind` is "file" (a project
## file, as it is or converted), "cache" (the imported or converted form of one, checked against the pack's own
## list by [method orphans]) or "engine" (ENGINE_FILES); "unknown" for anything else.
static func source_of(packed: String) -> Dictionary:
	if ENGINE_FILES.has(packed):
		return {"source": "", "kind": "engine"}
	if packed.begins_with(".godot/imported/") or packed.begins_with(".godot/exported/"):
		return {"source": "", "kind": "cache"}
	if packed.begins_with(".godot/"):
		return {"source": "", "kind": "unknown"}
	if packed.ends_with(".import") or packed.ends_with(".remap"):
		return {"source": packed.get_basename(), "kind": "file"}
	if packed.ends_with(".gdc"):
		return {"source": packed.get_basename() + ".gd", "kind": "file"}
	return {"source": packed, "kind": "file"}


## Imported and converted files of the pack that no packed project file stands behind.
static func orphans(packed_paths: PackedStringArray, sources: Dictionary) -> PackedStringArray:
	var imported_names: Dictionary = {}
	var converted_names: Dictionary = {}
	for source: String in sources:
		imported_names[source.get_file()] = true
		converted_names[source.get_file().get_basename()] = true
	var result: PackedStringArray = PackedStringArray()
	for packed: String in packed_paths:
		var name: String = packed.get_file()
		if packed.begins_with(".godot/imported/"):
			# <file name>-<md5 of its path>.<imported type>
			var dash: int = name.rfind("-")
			if dash < 0 or not imported_names.has(name.substr(0, dash)):
				result.append(packed)
		elif packed.begins_with(".godot/exported/"):
			# export-<md5 of its path>-<scene or resource name>.scn / .res
			var parts: PackedStringArray = name.get_basename().split("-", true, 2)
			if parts.size() != 3 or parts[0] != "export" or not converted_names.has(parts[2]):
				result.append(packed)
	return result


# --- Proof 1: the filters ------------------------------------------------------------------------------------------

func test_the_rules_know_a_development_file() -> void:
	for path: String in ["tests/test_core_save.gd", "tools/validate_levels.gd", "docs/BUILD.md", "build/x.png",
			"levels/test_example.lvl", "resources/bots/test_world_arena_flat.json", "scripts/core/dev/autoplay_flow.gd",
			"scripts/core/dev/input_recorder.gd", "scenes/ui/dev/ui_preview.tscn", "scripts/core/debug_level.gd",
			"scenes/core/debug_level.tscn", "resources/ui/make_bitmap_fonts.py", "tools/autoplay/routes/w1_l1.inputs",
			"scripts/world/coop_search.gd", "scripts/world/level_validator.gd", "README.md", "export_presets.cfg",
			"installer/club_and_grub.iss", "assets/sprites/not_in_the_manifest.png", "addons/x/plugin.gd",
			"scripts/tools/route_recorder.gd", "levels/routes/w1_l1.inputs"]:
		assert_ne(forbidden(path), "", "%s must not be shipped" % path)
	for path: String in ["levels/w1_l1.lvl", "levels/w9_l3_coop.lvl", "levels/arena_totem_ring.lvl", "CREDITS.md",
			"default_bus_layout.tres", "scripts/core/save.gd", "scripts/ui/ui_key_test.gd", "locale/en.po",
			"assets/icon.png", "assets/licenses/README.md", "resources/bots/w9_l3.json", "scenes/main.tscn"]:
		assert_eq(forbidden(path), "", "%s is shipped" % path)
		assert_true(FileAccess.file_exists("res://" + path), "%s exists" % path)


func test_every_preset_ships_no_development_file() -> void:
	var presets: ConfigFile = _presets()
	var first: PackedStringArray = PackedStringArray()
	for platform: String in PLATFORMS:
		var section: String = _preset_section(presets, platform)
		assert_ne(section, "", "a %s preset exists" % platform)
		if section.is_empty():
			continue
		var shipped: Dictionary = shipped_files(presets, section)
		assert_eq(str(shipped["error"]), "", platform)
		var files: PackedStringArray = shipped["files"]
		assert_true(files.size() > 1000, "%s ships the game (%d files)" % [platform, files.size()])
		var problems: PackedStringArray = PackedStringArray()
		for path: String in files:
			var reason: String = forbidden(path)
			if not reason.is_empty():
				problems.append("%s %s" % [path, reason])
		assert_eq(problems.size(), 0, "%s would ship %d file(s) a release must not hold:\n      %s" % [
			platform, problems.size(), "\n      ".join(problems.slice(0, 30))])
		if first.is_empty():
			first = files
		else:
			assert_eq(files, first, "%s ships the same files as %s" % [platform, PLATFORMS[0]])
	print("    pack: the filters of %d presets ship %d project file(s) each, no development file among them" % [
		PLATFORMS.size(), first.size()])


func test_every_preset_ships_the_whole_game() -> void:
	var presets: ConfigFile = _presets()
	var shipped: Dictionary = shipped_files(presets, _preset_section(presets, PLATFORMS[0]))
	var files: PackedStringArray = shipped["files"]
	var levels: PackedStringArray = PackedStringArray()
	for path: String in files:
		if path.begins_with("levels/"):
			levels.append(path.get_file().get_basename())
	var expected: PackedStringArray = PackedStringArray()
	for file: String in DirAccess.get_files_at("res://levels"):
		if file.ends_with(".lvl") and not file.begins_with("test_"):
			expected.append(file.get_basename())
			# A developer level is one by its name AND by its kind: no shipped file is of kind test.
			assert_false(FileAccess.get_file_as_string("res://levels/" + file).contains("\nkind = test"),
				"%s is shipped, so it is no level of kind test" % file)
	expected.sort()
	levels.sort()
	assert_eq(levels, expected, "every level file except the developer levels test_*.lvl")
	assert_true(levels.size() >= 78, "15 + 20 solo stages, 35 co-op files and 8 arenas (found %d)" % levels.size())
	for required: String in ["CREDITS.md", "assets/licenses/README.md", "assets/licenses/godot_engine.txt",
			"default_bus_layout.tres", "scenes/main.tscn", "scripts/core/save.gd", "locale/en.po", "assets/icon.png"]:
		assert_true(files.has(required), "%s is shipped" % required)
	# Every baked bot graph that is shipped belongs to a shipped level.
	for path: String in files:
		if path.begins_with("resources/bots/"):
			assert_true(levels.has(path.get_file().get_basename()), "%s belongs to a shipped level" % path)


func test_no_shipped_file_names_a_tool_that_is_left_out() -> void:
	# The exporter drops TOOL_SCRIPTS; a shipped script or scene that named one of their classes or paths would
	# break in the release build only. (Comments may mention them.)
	var presets: ConfigFile = _presets()
	var files: PackedStringArray = shipped_files(presets, _preset_section(presets, PLATFORMS[0]))["files"]
	var names: PackedStringArray = PackedStringArray()
	for tool_path: String in TOOL_SCRIPTS:
		assert_true(FileAccess.file_exists("res://" + tool_path), "%s exists" % tool_path)
		names.append(tool_path.get_file())
		for line: String in FileAccess.get_file_as_string("res://" + tool_path).split("\n"):
			if line.begins_with("class_name "):
				names.append(line.trim_prefix("class_name ").strip_edges())
				break
	assert_eq(names.size(), TOOL_SCRIPTS.size() * 2, "every tool script has a class name: %s" % str(names))
	var users: PackedStringArray = PackedStringArray()
	for path: String in files:
		if not (path.ends_with(".gd") or path.ends_with(".tscn") or path.ends_with(".tres")):
			continue
		for line: String in FileAccess.get_file_as_string("res://" + path).split("\n"):
			var code: String = line.get_slice("#", 0)
			for name: String in names:
				if code.contains(name):
					users.append("%s: %s" % [path, line.strip_edges().left(80)])
	assert_eq(users.size(), 0, "shipped code uses a tool no export carries:\n      %s" % "\n      ".join(users))


# --- Proof 2: the exe ------------------------------------------------------------------------------------------------

func test_the_reader_refuses_what_is_no_exported_game() -> void:
	assert_ne(str(read_pack("res://build/no_such_file.exe")["error"]), "")
	assert_ne(str(read_pack("res://project.godot")["error"]), "", "a file without a pack at its end")
	assert_eq(source_of("scripts/core/save.gdc"), {"source": "scripts/core/save.gd", "kind": "file"})
	assert_eq(source_of("scripts/core/save.gd.remap"), {"source": "scripts/core/save.gd", "kind": "file"})
	assert_eq(source_of("assets/icon.png.import"), {"source": "assets/icon.png", "kind": "file"})
	assert_eq(source_of("scenes/main.tscn.remap"), {"source": "scenes/main.tscn", "kind": "file"})
	assert_eq(source_of("levels/w1_l1.lvl"), {"source": "levels/w1_l1.lvl", "kind": "file"})
	assert_eq(source_of("project.binary")["kind"], "engine")
	assert_eq(source_of(".godot/imported/icon.png-0123.ctex")["kind"], "cache")
	assert_eq(source_of(".godot/editor/x.cfg")["kind"], "unknown")
	var sources: Dictionary = {"assets/icon.png": true, "scenes/main.tscn": true}
	assert_eq(orphans(PackedStringArray([".godot/imported/icon.png-0123.ctex", ".godot/exported/1/export-ab-main.scn",
		".godot/imported/stray.png-0123.ctex", ".godot/exported/1/export-ab-stray.scn"]), sources),
		PackedStringArray([".godot/imported/stray.png-0123.ctex", ".godot/exported/1/export-ab-stray.scn"]))


func test_the_exported_exe_holds_only_what_the_filters_allow() -> void:
	var exe_path: String = OS.get_environment(EXE_VARIABLE)
	if exe_path.is_empty():
		assert_true(true, "no exe is named")
		print("    pack: no exe was checked - %s is not set (tools/build_windows.ps1 sets it for the exe it exports)" % EXE_VARIABLE)
		return
	var pack: Dictionary = read_pack(exe_path)
	assert_eq(str(pack["error"]), "", "the pack inside %s is readable" % exe_path)
	if not str(pack["error"]).is_empty():
		return
	var packed: PackedStringArray = pack["paths"]
	var sources: Dictionary = {}
	var problems: PackedStringArray = PackedStringArray()
	for path: String in packed:
		var entry: Dictionary = source_of(path)
		match str(entry["kind"]):
			"unknown":
				problems.append("%s is a file this check does not know" % path)
			"file":
				sources[str(entry["source"])] = true
				var reason: String = forbidden(str(entry["source"]))
				if not reason.is_empty():
					problems.append("%s %s" % [path, reason])
	for path: String in orphans(packed, sources):
		problems.append("%s belongs to no packed project file" % path)
	assert_eq(problems.size(), 0, "%s holds %d file(s) a release must not hold:\n      %s" % [
		exe_path, problems.size(), "\n      ".join(problems.slice(0, 40))])
	# The exe against the filters, both ways: no file outside the list, no file of the list missing.
	var presets: ConfigFile = _presets()
	var expected: PackedStringArray = shipped_files(presets, _preset_section(presets, "Windows Desktop"))["files"]
	var extra: PackedStringArray = PackedStringArray()
	for source: String in sources:
		if not expected.has(source):
			extra.append(source)
	var missing: PackedStringArray = PackedStringArray()
	for path: String in expected:
		if not sources.has(path):
			missing.append(path)
	extra.sort()
	assert_eq(extra.size(), 0, "%d packed file(s) the filters do not ship (an exe of another tree?):\n      %s" % [
		extra.size(), "\n      ".join(extra.slice(0, 40))])
	assert_eq(missing.size(), 0, "%d file(s) the filters ship are not in the exe:\n      %s" % [
		missing.size(), "\n      ".join(missing.slice(0, 40))])
	var levels: int = 0
	for source: String in sources:
		if source.begins_with("levels/") and source.ends_with(".lvl"):
			levels += 1
	print("    pack: %d file(s) inside %s (engine %s): %d project files, %d levels, no developer level, test, tool or recorder, every asset in the manifest, nothing beside the filters' list" % [
		packed.size(), exe_path.get_file(), pack["engine"], sources.size(), levels])
