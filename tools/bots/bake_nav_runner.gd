extends Node
## The work of tools/bots/bake_nav.gd (see its header), run after the autoloads exist. Owner: core-B.

const LEVEL_DIR: String = "res://levels"


## Run the tool with its user arguments; returns the exit code.
func run(arguments: PackedStringArray) -> int:
	var out_dir: String = NavGraph.DIR
	var check: bool = false
	var verify: bool = false
	var verbose: bool = false
	var difficulty: int = Defs.Difficulty.BEGINNER
	var files: PackedStringArray = PackedStringArray()
	for argument: String in arguments:
		if argument.begins_with("--out="):
			out_dir = argument.trim_prefix("--out=").trim_suffix("/")
		elif argument == "--check":
			check = true
		elif argument == "--verify":
			verify = true
		elif argument == "--verbose":
			verbose = true
		elif argument.begins_with("--difficulty="):
			var value: String = argument.trim_prefix("--difficulty=")
			if value != "beginner" and value != "expert":
				print("bake_nav: unknown difficulty %s" % value)
				return 2
			difficulty = Defs.Difficulty.EXPERT if value == "expert" else Defs.Difficulty.BEGINNER
		elif argument.begins_with("--"):
			print("bake_nav: unknown option %s" % argument)
			return 2
		else:
			files.append(_to_level_path(argument))
	if files.is_empty():
		files = default_levels()
	if files.is_empty():
		print("bake_nav: no arena level found")
		return 1
	Game.new_game(difficulty)
	var failed: int = 0
	for path: String in files:
		if not FileAccess.file_exists(path):
			print("bake_nav: %s does not exist" % path)
			failed += 1
			continue
		var level_id: StringName = StringName(path.get_file().get_basename())
		var target: String = "%s/%s.json" % [out_dir, level_id]
		if verify:
			failed += 0 if _verify(path, target, difficulty) else 1
			continue
		var baker: NavBaker = NavBaker.new()
		baker.progress_every = 1000 if verbose else 0
		var graph: NavGraph = baker.bake_file(self, path, difficulty)
		for line: String in baker.report:
			print("bake_nav: " + line)
		if graph == null:
			failed += 1
			continue
		if check:
			var committed: String = FileAccess.get_file_as_string(target) if FileAccess.file_exists(target) else ""
			if committed.replace("\r\n", "\n") != graph.to_json():
				print("bake_nav: %s is stale (re-bake: bash .tools/gd.sh script res://tools/bots/bake_nav.gd -- %s)" % [
					target, level_id,
				])
				failed += 1
			else:
				print("bake_nav: %s is up to date" % target)
			continue
		var error: int = graph.save(target)
		if error != OK:
			print("bake_nav: cannot write %s (error %d)" % [target, error])
			failed += 1
		else:
			print("bake_nav: wrote %s" % target)
	print("bake_nav: %d level(s), %d problem(s)" % [files.size(), failed])
	return 1 if failed > 0 else 0


## Every arena file of the project: levels/arena_*.lvl and the test arenas levels/test_world_arena*.lvl.
static func default_levels() -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for file: String in DirAccess.get_files_at(LEVEL_DIR):
		if file.get_extension() == "lvl" and (file.begins_with("arena_") or file.begins_with("test_world_arena")):
			result.append("%s/%s" % [LEVEL_DIR, file])
	result.sort()
	return result


func _verify(path: String, target: String, difficulty: int) -> bool:
	var graph: NavGraph = NavGraph.load_file(target)
	if graph == null:
		print("bake_nav: %s has no graph %s" % [path, target])
		return false
	var text: String = FileAccess.get_file_as_string(path)
	if NavGraph.text_sha256(text) != graph.source_sha256:
		print("bake_nav: %s was baked from another version of %s (re-bake it)" % [target, path])
	var data: LevelData = LevelData.parse(graph.level_id, text, path)
	var baker: NavBaker = NavBaker.new()
	if not baker.sim.setup(self, graph.level_id, data.build_grid(difficulty), data.resolved_meta(difficulty),
			data.entity_records()):
		return false
	var problems: PackedStringArray = baker.verify_graph(graph)
	baker.sim.teardown()
	for problem: String in problems:
		print("bake_nav: %s: %s" % [graph.level_id, problem])
	print("bake_nav: %s: %d links verified, %d problem(s)" % [graph.level_id, graph.links.size(), problems.size()])
	return problems.is_empty()


func _to_level_path(argument: String) -> String:
	var text: String = argument.replace("\\", "/")
	if text.begins_with("res://"):
		return text
	if not text.contains("/") and text.get_extension() != "lvl":
		return "%s/%s.lvl" % [LEVEL_DIR, text]
	var absolute: String = ProjectSettings.globalize_path("res://")
	if text.begins_with(absolute):
		return "res://" + text.substr(absolute.length())
	return "res://" + text.trim_prefix("./")
