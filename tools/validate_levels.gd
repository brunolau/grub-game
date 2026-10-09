extends SceneTree
## Level validator (docs/ARCHITECTURE.md 7.9, docs/LEVEL_DESIGN.md). Owner: world-B (docs/expansion/PLAN.md 4.1).
##
## Usage (from the project root):
##   bash .tools/gd.sh script res://tools/validate_levels.gd                       every level in res://levels
##   bash .tools/gd.sh script res://tools/validate_levels.gd -- levels/w1_l1.lvl   only these files (the others
##                                                                                  are still read for references)
##   bash .tools/gd.sh script res://tools/validate_levels.gd -- w1_l1 w1_l2        the same by level id
##   ... -- --strict        warnings count as failures too
##   ... -- --quiet         print errors only
##   ... -- --coop          co-op files only (kind = coop; the given ones, else every one), and every x2 gate of them
##                          through the solo-impossibility search (scripts/world/coop_search.gd, LEVEL_DESIGN.md
##                          15.7.6): a gate one hero can pass (OPEN), a gate whose search stopped at its bound without
##                          its evidence (UNPROVEN, DESIGN.md G59) and a window above its solo minimum - 4 are
##                          errors; a refused gate prints its verdict - refused (exhaustive) or refused (bounded) -
##                          with the evidence. A gate takes up to a few minutes (the result cache of the search is
##                          used: build/coop_search_cache); many files: tools/world_coop_gates.sh.
##
## Prints `file:line: error: message` / `file:line: warning: message` and a summary. Exit code 0 = no errors,
## 1 = errors found (or, with --strict, warnings), 2 = bad arguments.

const LEVEL_DIR: String = "res://levels"
## The solo search, loaded by path when --coop asks for it: it drives the real hero through the Sim / GameInput
## autoloads, which a tool script cannot name when it is compiled.
const SEARCH_PATH: String = "res://scripts/world/coop_search.gd"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var files: PackedStringArray = PackedStringArray()
	var strict: bool = false
	var quiet: bool = false
	var coop: bool = false
	for argument: String in OS.get_cmdline_user_args():
		if argument == "--strict":
			strict = true
		elif argument == "--quiet":
			quiet = true
		elif argument == "--coop":
			coop = true
		elif argument.begins_with("--"):
			print("validate_levels: unknown option %s" % argument)
			_finish(2)
			return
		else:
			files.append(_to_resource_path(argument))
	var validator: LevelValidator = LevelValidator.new()
	var count: int = validator.add_folder(LEVEL_DIR)
	for file: String in files:
		if not file.begins_with(LEVEL_DIR + "/"):
			validator.add_file(file)
	if coop and files.is_empty():
		files = _coop_files()
	validator.run()
	var errors: int = 0
	var warnings: int = 0
	for problem: Dictionary in validator.problems:
		if (not files.is_empty() or coop) and not files.has(str(problem["path"])):
			continue
		var is_error: bool = int(problem["severity"]) == LevelValidator.ERROR
		if is_error:
			errors += 1
		else:
			warnings += 1
		if is_error or not quiet:
			print(LevelValidator.format_problem(problem))
	if coop:
		errors += await _search_gates(files)
	var scope: String = "%d level file(s)" % count if files.is_empty() else "%d file(s)" % files.size()
	print("validate_levels: %s checked, %d error(s), %d warning(s)" % [scope, errors, warnings])
	_finish(1 if errors > 0 or (strict and warnings > 0) else 0)


## Every co-op file of the level folder (kind = coop), sorted.
func _coop_files() -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	var dir: DirAccess = DirAccess.open(LEVEL_DIR)
	if dir == null:
		return result
	var names: PackedStringArray = dir.get_files()
	names.sort()
	for file_name: String in names:
		if file_name.get_extension() != "lvl":
			continue
		var path: String = LEVEL_DIR.path_join(file_name)
		if str(LevelText.parse_meta(FileAccess.get_file_as_string(path)).get("kind", "")) == LevelText.KIND_COOP:
			result.append(path)
	return result


## The solo-impossibility search on every x2 gate of the co-op `files`, on every difficulty the file is played in.
## Returns the errors printed.
## A coroutine: a frame passes after every gate (a search plays tens of thousands of moves without one, and the nodes
## it freed leave their deferred calls in the engine's message queue until then - content's wf10 #1: six gates in a
## row filled it and Godot crashed).
func _search_gates(files: PackedStringArray) -> int:
	var errors: int = 0
	var search: GDScript = load(SEARCH_PATH) as GDScript
	if search == null:
		print("validate_levels: error: the solo search %s cannot be loaded" % SEARCH_PATH)
		return 1
	for path: String in files:
		var data: LevelData = LevelData.load_file(path)
		if data == null or str(data.value("kind")) != LevelText.KIND_COOP:
			continue
		for difficulty: int in [Defs.Difficulty.BEGINNER, Defs.Difficulty.EXPERT]:
			# Only the difficulties the file is played in (LevelRegistry.is_available, the rule of
			# tests/test_coop_gates.gd): an Expert-only file has no Beginner gate - its windows are the Expert ones
			# (G3b: `w4_l2_coop` 'drums' was reported OPEN on Beginner, a difficulty nobody can start it in).
			if difficulty == Defs.Difficulty.BEGINNER and str(data.value("min_difficulty")) == "expert":
				continue
			var gates: Dictionary = {}
			for record: Dictionary in data.entity_records():
				if String(record["id"]) == "objects/x2_tablet" and LevelText.applies_to(record["params"], difficulty):
					var tablet: Dictionary = LevelValidator.parse_tablet(record)
					if tablet["gate"] != "":
						gates[tablet["gate"]] = int(tablet["line"])
			for gate: String in gates:
				var result: Dictionary = search.call(&"search_gate", data.id, difficulty, gate)
				await process_frame
				var where: String = "%s:%d" % [path, int(gates[gate])]
				var label: String = "gate '%s' (%s)" % [gate, Defs.difficulty_name(difficulty)]
				var verdict: Dictionary = search.call(&"gate_verdict", result)
				if str(verdict["verdict"]) == "unproven":
					errors += 1
					print("%s: error: %s: UNPROVEN (G59) - %s" % [where, label, verdict["evidence"]])
				elif bool(result["reached"]):
					errors += 1
					print("%s: error: %s: OPEN - a single hero gets through - %s" % [where, label, result["detail"]])
				else:
					print("%s: note: %s %s by the solo search: %s (%d moves played%s)" % [where, label,
						verdict["verdict"], verdict["evidence"], int(result.get("runs", 0)),
						"" if bool(result.get("flood", true)) else "; the bare grid has no path either"])
				for window: Dictionary in result["windows"]:
					# A slot-bound rule (G34 / G47: the daze) is one a single player never meets, whatever its window.
					var ok: bool = bool(window.get("slot_bound", false)) 							or int(window["window"]) <= int(window["solo_min"]) - PartyTuning.WINDOW_SOLO_MARGIN_TICKS
					if not ok:
						errors += 1
					print("%s: %s: %s: %s window %d, solo minimum %d" % [where, "note" if ok else "error", label,
						window["what"], int(window["window"]), int(window["solo_min"])])
	return errors


func _to_resource_path(argument: String) -> String:
	var text: String = argument.replace("\\", "/")
	if text.begins_with("res://"):
		return text
	if not text.contains("/") and text.get_extension() != "lvl":
		# A bare level id ("w1_l1"): the file of that level.
		return LEVEL_DIR + "/" + text + ".lvl"
	var absolute: String = ProjectSettings.globalize_path("res://")
	if text.begins_with(absolute):
		return "res://" + text.substr(absolute.length())
	return "res://" + text.trim_prefix("./")


func _finish(code: int) -> void:
	# Let the audio autoload release its players before the engine shuts down (no leak reports).
	var audio: Node = root.get_node_or_null("Audio")
	if audio != null and audio.has_method("shutdown"):
		audio.call("shutdown")
	await create_timer(0.1).timeout
	quit(code)
