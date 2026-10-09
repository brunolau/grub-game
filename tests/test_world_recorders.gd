extends TestCase
## The co-op route recorders (tools/autoplay/recorders, wf12; owner: world-B for the kit, PLAN.md 7 P4).
##
## Every two-stream route of a co-op file was played by a closed-loop pair bot or a macro script of its designer.
## Until wf12 those lived unversioned under build/; the kit keeps them, and tools/autoplay/recorders/routes.txt names
## for every co-op route file the one command that records it again (`bash tools/autoplay/recorders/record.sh
## <route file>`). This test keeps the table and the kit whole: a co-op route without a line, a line without its route,
## a probe or a script that is gone, a kit script that would enter the game's class table. It records nothing (a
## recording is minutes of play: `record.sh --all` is the check of the kit on a tree).

const KIT: String = "res://tools/autoplay/recorders"
const TABLE: String = "res://tools/autoplay/recorders/routes.txt"
const ROUTES: String = "res://tools/autoplay/routes"
const PATH_CHARS: String = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_./-"


## The table: route file -> [kind, probe, script, difficulty, arguments].
func _table() -> Dictionary:
	var lines: Dictionary = {}
	for line: String in FileAccess.get_file_as_string(TABLE).split("\n", false):
		if line.begins_with("#") or line.strip_edges() == "":
			continue
		var cells: PackedStringArray = line.split("\t")
		var fields: Array = []
		for i: int in range(1, 6):
			fields.append(cells[i].strip_edges() if i < cells.size() else "")
		lines[cells[0]] = fields
	return lines


## The co-op route files: a `# route:` header that names a co-op file and two or more players.
func _coop_routes() -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	for file: String in DirAccess.get_files_at(ROUTES):
		if not file.ends_with(".inputs"):
			continue
		var header: String = FileAccess.get_file_as_string(ROUTES.path_join(file)).get_slice("\n", 0)
		var level: String = ""
		var players: int = 1
		for token: String in header.split(" ", false):
			if token.begins_with("level="):
				level = token.trim_prefix("level=")
			elif token.begins_with("players="):
				players = token.trim_prefix("players=").to_int()
		if level != "" and players >= 2 and Levels.is_coop_level(StringName(level)):
			found.append(file)
	found.sort()
	return found


func test_every_coop_route_has_its_recorder() -> void:
	assert_true(FileAccess.file_exists(TABLE), "the recorders' table %s" % TABLE)
	var table: Dictionary = _table()
	var routes: PackedStringArray = _coop_routes()
	print("    co-op routes: %d, table lines: %d" % [routes.size(), table.size()])
	var problems: PackedStringArray = PackedStringArray()
	for file: String in routes:
		if not table.has(file):
			problems.append("%s: a co-op route without a line in routes.txt" % file)
	for file: String in table:
		var fields: Array = table[file]
		if not routes.has(file):
			problems.append("%s: a table line without its co-op route under tools/autoplay/routes" % file)
		if not ["bot", "rec"].has(str(fields[0])):
			problems.append("%s: kind '%s' (bot or rec)" % [file, fields[0]])
		if not ["beginner", "expert"].has(str(fields[3])):
			problems.append("%s: difficulty '%s'" % [file, fields[3]])
		for index: int in [1, 2]:
			if not FileAccess.file_exists(KIT.path_join(str(fields[index]))):
				problems.append("%s: %s is not in the kit" % [file, fields[index]])
		# A file a bot is handed by an argument (the repair-search bots' fixes) is in the kit too.
		for token: String in str(fields[4]).split(" ", false):
			var at: int = token.find("res://")
			if at >= 0 and not FileAccess.file_exists(token.substr(at)):
				problems.append("%s: the argument %s names a file that is gone" % [file, token])
	assert_eq(problems, PackedStringArray(), "the recorders' table")
	assert_true(FileAccess.file_exists(KIT.path_join("record.sh")), "the one command: record.sh")


func test_the_kit_stays_out_of_the_game() -> void:
	# A recorder is a development tool loaded by path: no class_name (the game's class table), and what it names
	# under res://build/ is scratch it writes, never a file the kit holds.
	var scripts: PackedStringArray = PackedStringArray()
	_collect(KIT, scripts)
	assert_true(scripts.size() > 20, "%d kit scripts" % scripts.size())
	var problems: PackedStringArray = PackedStringArray()
	for path: String in scripts:
		var text: String = FileAccess.get_file_as_string(path)
		for line: String in text.split("\n"):
			if line.begins_with("class_name "):
				problems.append("%s declares %s" % [path, line.strip_edges()])
			var at: int = line.find("res://build/")
			while at >= 0:
				var end: int = at + 12
				while end < line.length() and PATH_CHARS.contains(line[end]):
					end += 1
				var moved: String = KIT.path_join(line.substr(at + 12, end - at - 12).rstrip("./"))
				if moved.get_extension() != "" and FileAccess.file_exists(moved):
					problems.append("%s still names %s (the kit holds it)" % [path, line.substr(at, end - at)])
				at = line.find("res://build/", end)
	assert_eq(problems, PackedStringArray(), "the kit's scripts")


func _collect(dir_path: String, into: PackedStringArray) -> void:
	for file: String in DirAccess.get_files_at(dir_path):
		if file.ends_with(".gd"):
			into.append(dir_path.path_join(file))
	for sub: String in DirAccess.get_directories_at(dir_path):
		_collect(dir_path.path_join(sub), into)
