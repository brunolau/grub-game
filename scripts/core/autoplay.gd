extends Node
## Autoload `Autoplay`: scripted-input harness for visual QA (docs/ARCHITECTURE.md 9.2).
##
## Inactive unless the game is started with user arguments (everything after ` -- `):
##
##   --autoplay=<level_id>     load this level and play the input script in it
##   --autoplay-scene=<path>   OR: load any scene (res://...) and only take screenshots
##   --flow=<file>             OR: boot normally and play a flow script (menus, gameplay, checks, screenshots
##                             across scene changes; syntax at the top of scripts/core/dev/autoplay_flow.gd)
##   --inputs=<runs>           run-length input script "ticks:KEYS,ticks:KEYS,..." with KEYS from
##                             L R U D F K (left right up/jump down fire look); "30:" = 30 idle ticks
##   --inputs-file=<path>      the same script read from a text file (commas or new lines)
##   --shots=<n>               save a screenshot every n ticks (default 24), plus the first and the last tick
##   --out=<name>              folder under build/screenshots/ (default: the level id or scene name)
##   --difficulty=<name>       beginner (default) or expert
##   --seed=<n>                simulation RNG seed (default 1)
##   --fast                    run one tick per rendered frame instead of real time
##   --hold=<ticks>            idle ticks appended after the script (default 12)
##   --user-dir=<path>         where saves and settings go during the run (default res://build/autoplay_user):
##                             the harness never touches the player's real save
##   --fresh-user              start that folder empty (no save, default settings)
##   --transitions             keep the timed transitions (default: instant)
##   --smoke=<seconds>         boot check: run the game normally for that long (0.1 .. 120), then quit cleanly.
##                             Exit code 0 only when no error and no warning was logged (works with --headless)
##
## Example (run the windowed console binary, NOT --headless, or no image can be captured):
##   godot --path . -- --autoplay=test_example --inputs=40:R,12:RU,30:R,8:F --shots=10
##
## Output: build/screenshots/<out>/tick_00010.png ... and trace.json (hero position per tick).
## Exit code: 0 = finished, 1 = smoke run logged errors or warnings, 2 = bad arguments / unknown level,
## 3 = scene could not be loaded, 4 = a check of a flow script failed.
##
## RELEASE BUILDS. Everything above is a development tool and works only in debug builds (the editor binary and
## debug export templates). A release build ignores those switches completely; the single switch it honours is
## `--smoke`, the boot check of the build scripts: it only shortens the session and reads nothing but the log.
## In an exported build the smoke run also verifies the package itself (no development file inside).
##   ClubAndGrub.exe --log-file smoke.log -- --smoke=3      (exit code 0 = clean boot)

## Emitted when the script has been played completely (just before the application quits).
signal finished(exit_code: int)

const DEFAULT_SHOT_PERIOD: int = 24
const DEFAULT_HOLD_TICKS: int = 12
const SETTLE_FRAMES: int = 4
## The switches a release build honours; every other one needs a debug build.
const RELEASE_SWITCHES: PackedStringArray = ["smoke"]
const SMOKE_MIN_SECONDS: float = 0.1
const SMOKE_MAX_SECONDS: float = 120.0
## Development files and folders that must never be inside an exported build (export_presets.cfg excludes them).
const DEVELOPMENT_PATHS: PackedStringArray = [
	"res://tests", "res://tools", "res://docs", "res://scenes/core/debug_level.tscn",
	"res://scripts/core/debug_level.gd", "res://levels/test_example.lvl", FLOW_RUNNER,
]
## The flow-script runner (development only, excluded from exports with every `dev` folder).
const FLOW_RUNNER: String = "res://scripts/core/dev/autoplay_flow.gd"
## Saves and settings of harness runs (never the player's real ones).
const DEFAULT_USER_DIR: String = "res://build/autoplay_user"
const USER_FILES: PackedStringArray = ["save.json", "save.json.bak", "save.json.tmp", "settings.cfg"]

## Counts what the engine logs during a smoke run.
class LogCounter:
	extends Logger

	var errors: int = 0
	var warnings: int = 0

	func _log_error(
			_function: String, _file: String, _line: int, _code: String, _rationale: String, _editor_notify: bool,
			error_type: int, _script_backtraces: Array[ScriptBacktrace]
	) -> void:
		if error_type == Logger.ERROR_TYPE_WARNING:
			warnings += 1
		else:
			errors += 1

	func _log_message(_message: String, _error: bool) -> void:
		pass


## True when this run is driven by the harness.
var active: bool = false
## True when a flow script drives the run: the game boots and runs normally (title screen included); the script
## plays the input.
var flow_mode: bool = false

var _level_id: StringName = &""
var _scene_path: String = ""
var _flags: PackedInt32Array = PackedInt32Array()
var _shot_period: int = DEFAULT_SHOT_PERIOD
var _out_dir: String = ""
var _fast: bool = false
var _seed: int = 1
var _difficulty: int = Defs.Difficulty.BEGINNER
var _trace: Array[Array] = []
var _shots_saved: int = 0
var _done: bool = false
var _can_capture: bool = true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)
	var requested: Dictionary = parse_args(OS.get_cmdline_user_args())
	var options: Dictionary = allowed_options(requested, OS.is_debug_build())
	var driven: bool = requested.has("autoplay") or requested.has("autoplay-scene") or requested.has("flow")
	if requested.size() != options.size() and driven:
		print("Autoplay: development switches are ignored by release builds")
	if options.has("smoke"):
		_smoke(clampf(str(options["smoke"]).to_float(), SMOKE_MIN_SECONDS, SMOKE_MAX_SECONDS))
		return
	if not options.has("autoplay") and not options.has("autoplay-scene") and not options.has("flow"):
		return
	active = true
	flow_mode = options.has("flow")
	# The harness window rarely has the focus (several runs share one desktop): never pause for that.
	Flow.pause_on_focus_loss = false
	_configure(options)
	_redirect_user_data(str(options.get("user-dir", DEFAULT_USER_DIR)), options.has("fresh-user"))
	if flow_mode:
		_start_flow(str(options["flow"]))
		return
	# Start after the main scene finished its own _ready.
	_run.call_deferred()


## The options this build may act on: all of them in a debug build, only RELEASE_SWITCHES in a release build,
## so that no development switch can change what a player's copy of the game does.
func allowed_options(options: Dictionary, debug_build: bool) -> Dictionary:
	if debug_build:
		return options
	var result: Dictionary = {}
	for key: String in RELEASE_SWITCHES:
		if options.has(key):
			result[key] = options[key]
	return result


## Development files found in this build (paths of DEVELOPMENT_PATHS that exist, plus test levels). Empty for
## a correct export; meaningless in the editor, where all of them exist.
func find_development_files() -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	for path: String in DEVELOPMENT_PATHS:
		if FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(path) or ResourceLoader.exists(path):
			found.append(path)
	for id: StringName in Levels.all_ids():
		if String(id).begins_with("test_") and not found.has(Levels.get_level_path(id)):
			found.append(Levels.get_level_path(id))
	return found


## Parse "--key=value" / "--flag" arguments into a Dictionary (keys without the dashes; flags map to "").
func parse_args(arguments: PackedStringArray) -> Dictionary:
	var options: Dictionary = {}
	for argument: String in arguments:
		if not argument.begins_with("--"):
			continue
		var body: String = argument.substr(2)
		var eq: int = body.find("=")
		if eq < 0:
			options[body] = ""
		else:
			options[body.substr(0, eq)] = body.substr(eq + 1)
	return options


## Convert an input script "40:R,12:RU,8:" into one flags value (Defs.IN_*) per tick.
## Entries are separated by commas or new lines; a missing key part means "nothing held". A line whose first
## non-blank character is `#` is a comment (it may contain commas).
func parse_inputs(script: String) -> PackedInt32Array:
	var result: PackedInt32Array = PackedInt32Array()
	var entries: PackedStringArray = PackedStringArray()
	for line: String in script.split("\n"):
		if not line.strip_edges().begins_with("#"):
			entries.append_array(line.split(",", false))
	for entry: String in entries:
		var item: String = entry.strip_edges()
		if item.is_empty():
			continue
		var colon: int = item.find(":")
		var count_text: String = item if colon < 0 else item.substr(0, colon)
		var keys: String = "" if colon < 0 else item.substr(colon + 1).strip_edges().to_upper()
		if not count_text.strip_edges().is_valid_int():
			push_error("Autoplay: bad input entry '%s' (expected ticks:KEYS)" % item)
			continue
		var value: int = GameInput.keys_to_flags(keys)
		for i: int in count_text.strip_edges().to_int():
			result.append(value)
	return result


func _smoke(seconds: float) -> void:
	var counter: LogCounter = LogCounter.new()
	OS.add_logger(counter)
	if OS.has_feature("template"):
		for path: String in find_development_files():
			push_error("Smoke: development file %s is inside this export" % path)
	await get_tree().create_timer(seconds, true, false, true).timeout
	OS.remove_logger(counter)
	print("Smoke: %s %s (%s build), %d level(s), screen '%s'" % [
		ProjectSettings.get_setting("application/config/name"),
		ProjectSettings.get_setting("application/config/version"),
		"debug" if OS.is_debug_build() else "release", Levels.all_ids().size(), Flow.current_screen,
	])
	print("Smoke: ran %.1f s, %d error(s), %d warning(s) logged" % [seconds, counter.errors, counter.warnings])
	Flow.shutdown_and_quit(0 if counter.errors + counter.warnings == 0 else 1)


func _configure(options: Dictionary) -> void:
	_level_id = StringName(str(options.get("autoplay", "")))
	_scene_path = str(options.get("autoplay-scene", ""))
	var script: String = str(options.get("inputs", ""))
	if options.has("inputs-file"):
		script = FileAccess.get_file_as_string(str(options["inputs-file"]))
	_flags = parse_inputs(script)
	var hold: int = str(options.get("hold", str(DEFAULT_HOLD_TICKS))).to_int()
	for i: int in maxi(hold, 0):
		_flags.append(0)
	_shot_period = maxi(str(options.get("shots", str(DEFAULT_SHOT_PERIOD))).to_int(), 1)
	_seed = str(options.get("seed", "1")).to_int()
	_fast = options.has("fast")
	if str(options.get("difficulty", "beginner")) == "expert":
		_difficulty = Defs.Difficulty.EXPERT
	var out_name: String = str(options.get("out", ""))
	if out_name.is_empty() and options.has("flow"):
		out_name = str(options["flow"]).get_file().get_basename()
	if out_name.is_empty():
		out_name = String(_level_id) if _level_id != &"" else _scene_path.get_file().get_basename()
	var root: String = "res://build/screenshots/" if OS.has_feature("editor") else "user://screenshots/"
	_out_dir = ProjectSettings.globalize_path(root + out_name.validate_filename())
	_can_capture = DisplayServer.get_name() != "headless"
	Flow.instant_transitions = not options.has("transitions")


## Saves and settings of this run go to `dir_path` (the player's real ones are never touched); `fresh` empties it.
func _redirect_user_data(dir_path: String, fresh: bool) -> void:
	var absolute: String = ProjectSettings.globalize_path(dir_path)
	DirAccess.make_dir_recursive_absolute(absolute)
	if fresh:
		for file: String in USER_FILES:
			if FileAccess.file_exists(absolute + "/" + file):
				DirAccess.remove_absolute(absolute + "/" + file)
	Settings.set_storage_dir(dir_path)
	Save.set_storage_dir(dir_path)
	print("Autoplay: user data in %s" % absolute)


## Hand the run to the flow-script runner (debug builds only; the runner is not exported).
func _start_flow(path: String) -> void:
	DirAccess.make_dir_recursive_absolute(_out_dir)
	var script_path: String = path if path.begins_with("res://") or path.is_absolute_path() else "res://" + path
	var text: String = FileAccess.get_file_as_string(script_path)
	var runner_script: GDScript = load(FLOW_RUNNER) as GDScript if ResourceLoader.exists(FLOW_RUNNER) else null
	if text.is_empty() or runner_script == null:
		push_error("Autoplay: cannot read flow script '%s' (or the runner is missing)" % script_path)
		_finish.call_deferred(2)
		return
	print("Autoplay: output folder %s" % _out_dir)
	var runner: Node = runner_script.new() as Node
	runner.name = "FlowRunner"
	add_child(runner)
	runner.call("begin", text, _out_dir, _fast, _can_capture)


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(_out_dir)
	print("Autoplay: output folder %s" % _out_dir)
	if not _can_capture:
		print("Autoplay: headless display, screenshots are skipped (trace.json is still written)")
	if _scene_path != "":
		if not ResourceLoader.exists(_scene_path):
			push_error("Autoplay: scene '%s' does not exist" % _scene_path)
			_finish(3)
			return
		get_tree().change_scene_to_file(_scene_path)
	else:
		if not Levels.has_level(_level_id):
			push_error("Autoplay: unknown level '%s' (known: %s)" % [_level_id, str(Levels.all_ids())])
			_finish(2)
			return
		Game.new_game(_difficulty)
		Flow.start_level(_level_id, Defs.Transition.NONE)
		await Flow.transition_finished
	for i: int in SETTLE_FRAMES:
		await get_tree().process_frame
	GameInput.set_scripted(_flags_for_tick)
	Sim.tick_finished.connect(_on_tick_finished)
	if not Sim.running:
		Sim.start(_seed)
	else:
		Sim.rng.reseed(_seed)
		Sim.tick = 0
	Sim.manual = _fast
	await _capture(0)
	set_process(true)


func _process(_delta: float) -> void:
	if _done:
		return
	if _fast:
		Sim.step(1)


func _flags_for_tick(tick: int) -> int:
	var index: int = tick - 1
	if index < 0 or index >= _flags.size():
		return 0
	return _flags[index]


func _on_tick_finished(tick: int) -> void:
	if _done:
		return
	var level: LevelBase = Game.level
	if level != null and level.player != null:
		var hero: PlayerBase = level.player
		_trace.append([tick, hero.sim_pos.x, hero.sim_pos.y, hero.xvel, hero.yvel, hero.state])
	var last: bool = tick >= _flags.size()
	if last:
		_done = true
		Sim.manual = true
	if last or tick % _shot_period == 0:
		_capture_then(tick, last)


func _capture_then(tick: int, last: bool) -> void:
	await _capture(tick)
	if last:
		_write_trace()
		print("Autoplay: %d ticks played, %d screenshots saved" % [tick, _shots_saved])
		_finish(0)


func _capture(tick: int) -> void:
	if not _can_capture:
		return
	await RenderingServer.frame_post_draw
	var texture: ViewportTexture = get_viewport().get_texture()
	var image: Image = texture.get_image() if texture != null else null
	if image == null or image.is_empty():
		push_warning("Autoplay: could not capture tick %d" % tick)
		return
	var path: String = "%s/tick_%05d.png" % [_out_dir, tick]
	var err: Error = image.save_png(path)
	if err != OK:
		push_error("Autoplay: cannot write %s (error %d)" % [path, err])
		return
	_shots_saved += 1


func _write_trace() -> void:
	var file: FileAccess = FileAccess.open(_out_dir + "/trace.json", FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({
		"level": String(_level_id),
		"scene": _scene_path,
		"seed": _seed,
		"ticks": _flags.size(),
		"columns": ["tick", "x", "y", "xvel", "yvel", "state"],
		"rows": _trace,
	}))
	file.close()


func _finish(exit_code: int) -> void:
	_done = true
	GameInput.clear_scripted()
	finished.emit(exit_code)
	Flow.shutdown_and_quit(exit_code)
