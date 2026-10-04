extends SceneTree
## Level validator (docs/ARCHITECTURE.md 7.9, docs/LEVEL_DESIGN.md). Owner: world.
##
## Usage (from the project root):
##   bash .tools/gd.sh script res://tools/validate_levels.gd                       every level in res://levels
##   bash .tools/gd.sh script res://tools/validate_levels.gd -- levels/w1_l1.lvl   only these files (the others
##                                                                                  are still read for references)
##   ... -- --strict        warnings count as failures too
##   ... -- --quiet         print errors only
##
## Prints `file:line: error: message` / `file:line: warning: message` and a summary. Exit code 0 = no errors,
## 1 = errors found (or, with --strict, warnings), 2 = bad arguments.

const LEVEL_DIR: String = "res://levels"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var files: PackedStringArray = PackedStringArray()
	var strict: bool = false
	var quiet: bool = false
	for argument: String in OS.get_cmdline_user_args():
		if argument == "--strict":
			strict = true
		elif argument == "--quiet":
			quiet = true
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
	validator.run()
	var errors: int = 0
	var warnings: int = 0
	for problem: Dictionary in validator.problems:
		if not files.is_empty() and not files.has(str(problem["path"])):
			continue
		var is_error: bool = int(problem["severity"]) == LevelValidator.ERROR
		if is_error:
			errors += 1
		else:
			warnings += 1
		if is_error or not quiet:
			print(LevelValidator.format_problem(problem))
	var scope: String = "%d level file(s)" % count if files.is_empty() else "%d file(s)" % files.size()
	print("validate_levels: %s checked, %d error(s), %d warning(s)" % [scope, errors, warnings])
	_finish(1 if errors > 0 or (strict and warnings > 0) else 0)


func _to_resource_path(argument: String) -> String:
	var text: String = argument.replace("\\", "/")
	if text.begins_with("res://"):
		return text
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
