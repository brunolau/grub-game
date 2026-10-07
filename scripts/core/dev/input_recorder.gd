extends Node
## Input recorder of the autoplay harness: `--record=<file>` (docs/expansion/TECH_AUDIT.md 4.11, LEVEL_DESIGN.md
## 15.9). Owner: integration. Development only: Autoplay loads it in debug builds, and exports leave it out (folder
## `dev`), so it has no class_name.
##
## While a stage runs, it appends every player slot's sampled flags (GameInput.get_flags) on Sim.tick_started -
## after the sample and before the first phase - so the file it writes replays that stage tick for tick: the
## route tests feed a route's n-th entry to the stage's n-th tick, from the level's own tick 1 and seed. Whatever
## drives a slot is recorded the same way: keys, pads, touch, a bot, a script.
##
## One file per stage played: the first stage goes to `<file>`, every later one (a linked sub-stage, a bonus stage,
## a restart after a lost life, the next map stop) to `<file stem>.<n>.<extension>` (n = 2, 3, ...). A file is
## written when its stage ends (another stage starts, the screen leaves the level, the application quits). It holds
## a `# route:` header skeleton (level, difficulty, players, how the stage ended; add `after` and `expect` by hand),
## a comment line, and the run-length entries of Autoplay.format_inputs: `ticks:KEYS` for one hero, one key set per
## player separated by `|` for a party.

## Emitted after a stage's file was written (path, level id, ticks, players).
signal written(path: String, level_id: StringName, ticks: int, players: int)

var _path: String = ""
## Instance id of the stage being recorded (0 = none); an id, because a freed level compares equal to null.
var _stage: int = 0
var _level_id: StringName = &""
var _difficulty: int = Defs.Difficulty.BEGINNER
var _streams: Array[PackedInt32Array] = []
## How the recorded stage ended: "exit", "warp", "trophy" or "none".
var _ends: String = "none"
var _files: int = 0
## Paths written so far, in order.
var files_written: PackedStringArray = PackedStringArray()


## Start recording into `path` (res://, user:// or an absolute path).
func begin(path: String) -> void:
	_path = path
	Sim.tick_started.connect(_on_tick_started)
	Events.exit_reached.connect(_on_exit_reached)
	Flow.screen_changed.connect(_on_screen_changed)
	print("Autoplay: recording the input of every stage into %s" % ProjectSettings.globalize_path(_path))


## Write the stage being recorded now (it is written anyway when it ends). Returns the path, "" when nothing was
## recorded.
func flush() -> String:
	if _stage == 0 or _streams.is_empty() or _streams[0].is_empty():
		_stage = 0
		return ""
	_files += 1
	var target: String = _path if _files == 1 else "%s.%d.%s" % [_path.get_basename(), _files, _path.get_extension()]
	var header: String = "%s level=%s difficulty=%s players=%d ends=%s" % [Autoplay.ROUTE_HEADER, _level_id,
			Defs.difficulty_name(_difficulty), _streams.size(), _ends]
	if Game.helper_mode:
		header += " helper=1"  # recorded in Helper mode: the route replays with it (DESIGN.md D.3)
	var note: String = "# recorded with --record: %d ticks of %s, seed 1; add after= and expect= to the header" % [
			_streams[0].size(), _level_id]
	var text: String = Autoplay.format_inputs(_streams, PackedStringArray([header, note]))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(target).get_base_dir())
	var file: FileAccess = FileAccess.open(target, FileAccess.WRITE)
	var ticks: int = _streams[0].size()
	var players: int = _streams.size()
	var level_id: StringName = _level_id
	_stage = 0
	_streams = []
	if file == null:
		push_error("Autoplay: cannot write the recording %s (error %d)" % [target, FileAccess.get_open_error()])
		return ""
	file.store_string(text)
	file.close()
	files_written.append(target)
	print("Autoplay: recorded %s, %d ticks, %d player(s) -> %s" % [level_id, ticks, players,
			ProjectSettings.globalize_path(target)])
	written.emit(target, level_id, ticks, players)
	return target


func _on_tick_started(_tick: int) -> void:
	var level: LevelBase = Game.level
	if not is_instance_valid(level):
		return
	if level.get_instance_id() != _stage:
		flush()
		_stage = level.get_instance_id()
		_level_id = level.level_id
		_difficulty = Game.difficulty
		_ends = "none"
		_streams = []
		for slot: int in clampi(level.hero_count(), 1, Defs.MAX_PLAYERS):
			_streams.append(PackedInt32Array())
	for slot: int in _streams.size():
		_streams[slot].append(GameInput.get_flags(slot))


func _on_exit_reached(exit_kind: StringName) -> void:
	if _stage != 0:
		_ends = String(exit_kind)


func _on_screen_changed(screen: StringName) -> void:
	if screen != Flow.SCREEN_LEVEL:
		flush()


func _exit_tree() -> void:
	flush()
