extends Node
## Flow runner of the autoplay harness (docs/ARCHITECTURE.md 9.2). Owner: core. Development only: Autoplay loads
## it for `--flow=<file>` in debug builds, and exports leave it out (folder `dev`), so it has no class_name.
##
## A flow script drives the whole game the way a player does - menus, gameplay, pause menu, scene changes - from
## the boot to the ending, checks the game state on the way and saves screenshots. One command per line; a line
## starting with `#` is a comment, blank lines are ignored:
##
##   wait <frames>                    let rendered frames pass
##   wait_until <expr> [frames]       wait until the condition holds (timeout DEFAULT_TIMEOUT frames; a timeout is a
##                                    failed check and ends the run)
##   press <action> [frames]          press an input action (ui_accept, ui_down, pause, ...) and release it after
##                                    `frames` frames (default 2), as a keyboard or pad would
##   key <name> [<name> ...]          press and release keys by name (`key B R U T`, `key Enter`), for typing
##   pad <button> [frames]            press and release a gamepad control as a real pad reports it (device 0, no
##                                    action event): a button index or name (a, b, x, y, back, start, up, down, left,
##                                    right, lb, rb) or a stick direction (lx-, lx+, ly-, ly+); `frames` held
##                                    (default 2). For gamepad-only menu paths through the input map
##   play <ticks:KEYS,...>            gameplay input for the next ticks, keys L R U D F K as in `--inputs`; waits
##                                    until it is played or gameplay ends (level completed, game over, or another
##                                    stage starts: a linked sub-stage, a bonus stage behind a warp, the stage after a
##                                    trophy). Outside `play` the hero gets no input.
##   play_file <path>                 the same, read from a file (commas or new lines; `#` lines are comments)
##   input device|script              `device`: the hero reads the real devices (keys and pads sent with `key` / `pad`,
##                                    which then also run the clock with --fast); `script` (the default): only `play`
##   weapon <club|hammer|axe|boomerang>   hand the hero this weapon (Game.set_weapon), e.g. the one a route was
##                                    recorded with
##   shot <name>                      save a screenshot now: <out>/<NN>_<name>.png
##   every <ticks> [name]             also save a screenshot every <ticks> simulation ticks (0 = off):
##                                    <out>/t<tick count>_<name>.png
##   expect <expr>                    check a condition; a failure is reported and sets the exit code
##   log <path> [<path> ...]          print values
##   reset_events                     set the `events.*` counters back to zero
##   start_level <id> [expert]        shortcut for segment work: a new run straight into a level (no menus)
##   window <width> <height>          resize the game window (os px) and wait until the view follows: 1600 720 gives
##                                    the 800 x 360 view of a wide phone, 1364 1024 the 682 x 512 view of a tablet
##   focus out|in                     the application loses / regains the focus, as when the player switches to
##                                    another window (also switches Flow.pause_on_focus_loss back on, as in a game)
##   quit                             end the run here
##
## Expressions are `<path> <op> <value>` (op: == != < <= > >=) or a single path that must be true. A path starts
## with a root - game, flow, sim, save, input, audio, level, hero (P1), hero2 .. hero4 (the heroes of player slots
## 1..3 of a party, null without one), boss, enemy (the living enemy nearest to the hero), hud, scene, tree,
## events - followed by `.property` segments: `hero.sim_pos:x` reads a sub-property,
## `game.completion_percent()` calls a method, `save.is_level_unlocked(test_integration_boss,0)` passes arguments
## (int, bool or text), a segment after a Dictionary reads its key. `events.<signal>` is how often that Events
## signal was emitted since the run started (`events.player_died`), `events.screen_<name>` how often a screen was
## entered; `reset_events` zeroes them. `settings.<key>` reads a setting (`settings.video/screen_shake`).
## Values: integers, decimals, true, false, null or text.
##
## The simulation runs one tick per rendered frame with `--fast` (never while paused or covered), otherwise in real
## time. With `--fast` a stage that has just started waits for its first `play`: its clock starts with the first
## scripted tick, so a route file plays exactly as in the headless route tests (tests/test_campaign_routes.gd), no
## matter how many frames the commands before it took. trace.json gets one row per tick: [frame, level, tick, x, y,
## xvel, yvel, state, dead].
## Exit code: 0 = the script ran to the end and every check passed, 4 = a check failed or a wait timed out,
## 2 = the script could not be read.

const DEFAULT_TIMEOUT: int = 2400
const DEFAULT_PRESS_FRAMES: int = 2
## Frames a `window` command waits for the window manager and the layouts to follow.
const RESIZE_FRAMES: int = 6
## A `play` that sees no tick for this many frames fails (the game is paused or no level runs).
const STALL_FRAMES: int = 600
const ROOTS: PackedStringArray = [
	"game", "flow", "sim", "save", "input", "audio", "level", "hero", "boss", "enemy", "hud", "scene", "tree",
	"settings", "events", "hero2", "hero3", "hero4",
]
const OPERATORS: PackedStringArray = ["==", "!=", "<=", ">=", "<", ">"]
const EXIT_OK: int = 0
const EXIT_BAD_SCRIPT: int = 2
const EXIT_FAILED: int = 4


## How often each Events signal fired; read as `events.<signal>` (unknown names read 0).
class EventCounts:
	extends RefCounted

	var counts: Dictionary = {}

	func count(signal_name: StringName) -> void:
		counts[signal_name] = int(counts.get(signal_name, 0)) + 1

	func _get(property: StringName) -> Variant:
		return int(counts.get(property, 0))


var _commands: Array[PackedStringArray] = []
var _out_dir: String = ""
var _fast: bool = false
var _can_capture: bool = true
var _flags: PackedInt32Array = PackedInt32Array()
var _flag_index: int = 0
var _checks: int = 0
var _failures: PackedStringArray = PackedStringArray()
var _shots: int = 0
var _every: int = 0
var _every_name: String = ""
var _ticks: int = 0
var _frame: int = 0
## Trace rows: 8 ints per tick (frame, tick, x, y, xvel, yvel, state, dead) and the level of each row; packed, so
## that the measured tick allocates nothing for the trace.
var _trace: PackedInt32Array = PackedInt32Array()
var _trace_levels: Array[StringName] = []
var _finished: bool = false
var _events: EventCounts = EventCounts.new()
## True while a `play` feeds input.
var _playing: bool = false
## The stage whose clock the runner steps; a new stage waits for its first `play` (see the header).
var _stepping_level: int = 0
## True after `input device`: the hero reads the real devices and the clock runs without a `play`.
var _device_input: bool = false


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


## Parse `script_text` and run it once the boot scene is up. `out_dir` is an absolute folder for screenshots.
func begin(script_text: String, out_dir: String, fast: bool, can_capture: bool) -> void:
	_out_dir = out_dir
	_fast = fast
	_can_capture = can_capture
	for raw: String in script_text.split("\n"):
		var line: String = raw.strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		_commands.append(line.split(" ", false))
	if _commands.is_empty():
		push_error("Autoplay flow: the script has no commands")
		_finish.call_deferred(EXIT_BAD_SCRIPT)
		return
	GameInput.set_scripted(_next_flags)
	Sim.tick_finished.connect(_on_tick_finished)
	for info: Dictionary in Events.get_signal_list():
		var signal_name: StringName = StringName(str(info["name"]))
		var arguments: int = (info["args"] as Array).size()
		var counter: Callable = _events.count.bind(signal_name)
		Events.connect(signal_name, counter.unbind(arguments) if arguments > 0 else counter)
	Flow.screen_changed.connect(func(screen: StringName) -> void: _events.count(StringName("screen_" + screen)))
	Sim.manual = _fast
	_run.call_deferred()


func _process(_delta: float) -> void:
	_frame += 1
	if _fast and not _finished and Sim.running and not Sim.frozen and not get_tree().paused and _may_step():
		Sim.step(1)


## False while a stage that just started waits for its first `play`.
func _may_step() -> bool:
	if not is_instance_valid(Game.level):
		return true
	var level: int = Game.level.get_instance_id()
	if level == _stepping_level:
		return true
	if not _playing and not _device_input:
		return false
	_stepping_level = level
	return true


func _run() -> void:
	print("Autoplay flow: %d command(s), output %s" % [_commands.size(), _out_dir])
	for command: PackedStringArray in _commands:
		if _finished:
			return
		if not await _execute(command):
			_failures.append("stopped at: %s" % " ".join(command))
			break
	_finish(EXIT_OK if _failures.is_empty() else EXIT_FAILED)


## Run one command; false ends the script (bad command or a timed-out wait).
func _execute(command: PackedStringArray) -> bool:
	var op: String = command[0]
	var rest: String = " ".join(command.slice(1))
	match op:
		"wait":
			for i: int in maxi(_int_arg(command, 1, 1), 0):
				await get_tree().process_frame
		"wait_until":
			return await _wait_until(command)
		"press":
			await _press(StringName(_arg(command, 1)), maxi(_int_arg(command, 2, DEFAULT_PRESS_FRAMES), 1))
		"key":
			for i: int in range(1, command.size()):
				await _key(command[i])
		"pad":
			if not await _pad(_arg(command, 1), maxi(_int_arg(command, 2, DEFAULT_PRESS_FRAMES), 1)):
				return false
		"input":
			match _arg(command, 1):
				"device":
					GameInput.clear_scripted()
					_device_input = true
				"script":
					GameInput.set_scripted(_next_flags)
					_device_input = false
				_:
					push_error("Autoplay flow: 'input' needs 'device' or 'script'")
					return false
		"play":
			return await _play(rest)
		"play_file":
			return await _play(FileAccess.get_file_as_string(_project_path(rest)))
		"weapon":
			var weapon: int = -1
			for w: int in [Defs.Weapon.CLUB, Defs.Weapon.HAMMER, Defs.Weapon.AXE, Defs.Weapon.BOOMERANG]:
				if Defs.weapon_name(w) == _arg(command, 1):
					weapon = w
			if weapon < 0:
				push_error("Autoplay flow: 'weapon' needs club, hammer, axe or boomerang")
				return false
			print("Autoplay flow: weapon %s handed over (the hero carried %s)" % [_arg(command, 1),
					Defs.weapon_name(Game.weapon)])
			Game.set_weapon(weapon)
		"shot":
			await _capture("%02d_%s" % [_shots, rest.validate_filename()])
		"every":
			_every = maxi(_int_arg(command, 1, 0), 0)
			_every_name = _arg(command, 2) if command.size() > 2 else "play"
		"expect":
			_check(rest, true)
		"reset_events":
			_events.counts.clear()
		"log":
			for i: int in range(1, command.size()):
				print("Autoplay flow: %s = %s" % [command[i], str(_resolve(command[i]))])
		"start_level":
			var idle: PackedStringArray = PackedStringArray(["wait_until", "flow.busy", "==", "false", "600"])
			if not await _wait_until(idle):
				return false
			var difficulty: int = Defs.Difficulty.EXPERT if _arg(command, 2) == "expert" else Defs.Difficulty.BEGINNER
			Game.new_game(difficulty)
			Flow.start_level(StringName(_arg(command, 1)), Defs.Transition.NONE)
			return await _wait_until(idle) and _check("flow.current_screen == level", true)
		"window":
			await _resize_window(Vector2i(_int_arg(command, 1, 0), _int_arg(command, 2, 0)))
		"focus":
			if _arg(command, 1) != "out" and _arg(command, 1) != "in":
				push_error("Autoplay flow: 'focus' needs 'out' or 'in'")
				return false
			Flow.pause_on_focus_loss = true
			var what: int = NOTIFICATION_APPLICATION_FOCUS_OUT if _arg(command, 1) == "out" \
					else NOTIFICATION_APPLICATION_FOCUS_IN
			get_tree().root.propagate_notification(what)
			await get_tree().process_frame
		"quit":
			_finish(EXIT_OK if _failures.is_empty() else EXIT_FAILED)
		_:
			push_error("Autoplay flow: unknown command '%s'" % op)
			return false
	return true


func _wait_until(command: PackedStringArray) -> bool:
	var parts: PackedStringArray = command.slice(1)
	var timeout: int = DEFAULT_TIMEOUT
	if parts.size() == 4 or parts.size() == 2:
		timeout = parts[parts.size() - 1].to_int()
		parts = parts.slice(0, parts.size() - 1)
	var expression: String = " ".join(parts)
	for i: int in timeout:
		if _check(expression, false):
			return true
		await get_tree().process_frame
	_check(expression, true)
	print("Autoplay flow: timed out after %d frames waiting for '%s'" % [timeout, expression])
	return false


func _press(action: StringName, frames: int) -> void:
	if not InputMap.has_action(action):
		push_error("Autoplay flow: unknown action '%s'" % action)
		return
	_send_action(action, true)
	for i: int in frames:
		await get_tree().process_frame
	_send_action(action, false)
	await get_tree().process_frame


func _send_action(action: StringName, pressed: bool) -> void:
	var event: InputEventAction = InputEventAction.new()
	event.action = action
	event.pressed = pressed
	event.strength = 1.0 if pressed else 0.0
	Input.parse_input_event(event)


## Resize the window and let a few frames pass so that the stretched view and every layout follow.
func _resize_window(size: Vector2i) -> void:
	if size.x <= 0 or size.y <= 0:
		push_error("Autoplay flow: 'window' needs a width and a height")
		return
	if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_WINDOWED:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(size)
	for i: int in RESIZE_FRAMES:
		await get_tree().process_frame
	print("Autoplay flow: window %s, view %s" % [str(DisplayServer.window_get_size()),
			str(get_viewport().get_visible_rect().size)])


func _key(key_name: String) -> void:
	var code: Key = OS.find_keycode_from_string(key_name)
	if code == KEY_NONE:
		push_error("Autoplay flow: unknown key '%s'" % key_name)
		return
	for pressed: bool in [true, false]:
		var event: InputEventKey = InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.unicode = int(code) if code >= KEY_SPACE and code <= KEY_Z else 0
		event.pressed = pressed
		Input.parse_input_event(event)
		await get_tree().process_frame


## Press and release one gamepad control (see the header); false for an unknown name.
func _pad(control: String, frames: int) -> bool:
	const BUTTONS: Dictionary = {
		"a": JOY_BUTTON_A, "b": JOY_BUTTON_B, "x": JOY_BUTTON_X, "y": JOY_BUTTON_Y, "back": JOY_BUTTON_BACK,
		"start": JOY_BUTTON_START, "up": JOY_BUTTON_DPAD_UP, "down": JOY_BUTTON_DPAD_DOWN,
		"left": JOY_BUTTON_DPAD_LEFT, "right": JOY_BUTTON_DPAD_RIGHT, "lb": JOY_BUTTON_LEFT_SHOULDER,
		"rb": JOY_BUTTON_RIGHT_SHOULDER,
	}
	const AXES: Dictionary = {
		"lx-": [JOY_AXIS_LEFT_X, -1.0], "lx+": [JOY_AXIS_LEFT_X, 1.0],
		"ly-": [JOY_AXIS_LEFT_Y, -1.0], "ly+": [JOY_AXIS_LEFT_Y, 1.0],
	}
	var control_name: String = control.to_lower()
	if AXES.has(control_name):
		var axis: Array = AXES[control_name]
		for value: float in [float(axis[1]), 0.0]:
			var motion: InputEventJoypadMotion = InputEventJoypadMotion.new()
			motion.device = 0
			motion.axis = int(axis[0]) as JoyAxis
			motion.axis_value = value
			Input.parse_input_event(motion)
			for i: int in (frames if value != 0.0 else 1):
				await get_tree().process_frame
		return true
	var index: int = -1
	if BUTTONS.has(control_name):
		index = int(BUTTONS[control_name])
	elif control_name.is_valid_int():
		index = control_name.to_int()
	if index < 0:
		push_error("Autoplay flow: unknown pad control '%s'" % control)
		return false
	for pressed: bool in [true, false]:
		var event: InputEventJoypadButton = InputEventJoypadButton.new()
		event.device = 0
		event.button_index = index as JoyButton
		event.pressed = pressed
		event.pressure = 1.0 if pressed else 0.0
		Input.parse_input_event(event)
		for i: int in (frames if pressed else 1):
			await get_tree().process_frame
	return true


## Gameplay input for the next ticks; returns when it was played or gameplay ended (true), or false when no tick
## ran for STALL_FRAMES frames (paused, or nothing to simulate).
func _play(script_text: String) -> bool:
	# Entries may also be separated by spaces on a `play` line; comment lines keep their leading '#'.
	_flags = Autoplay.parse_inputs(script_text.replace(" ", ","))
	_flag_index = 0
	_playing = true
	var idle_frames: int = 0
	var stalled: int = 0
	var last_index: int = 0
	var played: bool = true
	# The stage is told apart by its instance id: a freed level compares equal to null.
	var stage: int = Game.level.get_instance_id() if Game.level != null else 0
	while _flag_index < _flags.size():
		await get_tree().process_frame
		if Flow.current_screen != Flow.SCREEN_LEVEL and not Flow.busy:
			idle_frames += 1
			if idle_frames > 2:
				print("Autoplay flow: gameplay ended after %d of %d ticks" % [_flag_index, _flags.size()])
				break
		var current: int = Game.level.get_instance_id() if is_instance_valid(Game.level) else 0
		if stage == 0:
			stage = current
		elif current != 0 and current != stage:
			# A linked sub-stage, a bonus stage or the stage after a trophy took over: its own input comes next.
			print("Autoplay flow: %s started after %d of %d ticks" % [Game.level.level_id, _flag_index, _flags.size()])
			break
		stalled = 0 if _flag_index != last_index else stalled + 1
		last_index = _flag_index
		if stalled >= STALL_FRAMES:
			_failures.append("play: no tick ran for %d frames (paused?)" % STALL_FRAMES)
			played = false
			break
	_flags = PackedInt32Array()
	_flag_index = 0
	_playing = false
	return played


func _next_flags(_tick: int) -> int:
	if _flag_index >= _flags.size():
		return 0
	var value: int = _flags[_flag_index]
	_flag_index += 1
	return value


func _on_tick_finished(tick: int) -> void:
	if _finished:
		return
	_ticks += 1
	var level: LevelBase = Game.level
	if level != null and level.player != null:
		var hero: PlayerBase = level.player
		_trace.append(_frame)
		_trace.append(tick)
		_trace.append(hero.sim_pos.x)
		_trace.append(hero.sim_pos.y)
		_trace.append(hero.xvel)
		_trace.append(hero.yvel)
		_trace.append(hero.state)
		_trace.append(1 if hero.dead else 0)
		_trace_levels.append(level.level_id)
	if _every > 0 and _ticks % _every == 0:
		_capture("t%06d_%s" % [_ticks, _every_name])


func _capture(file_name: String) -> void:
	_shots += 1
	if not _can_capture:
		return
	await RenderingServer.frame_post_draw
	var texture: ViewportTexture = get_viewport().get_texture()
	var image: Image = texture.get_image() if texture != null else null
	if image == null or image.is_empty():
		push_warning("Autoplay flow: could not capture %s" % file_name)
		return
	var path: String = "%s/%s.png" % [_out_dir, file_name]
	if image.save_png(path) != OK:
		push_error("Autoplay flow: cannot write %s" % path)


# --- Expressions -------------------------------------------------------------------------------------------------

## Evaluate `expression`; when `record` is true it counts as a check (and a failure is reported).
func _check(expression: String, record: bool) -> bool:
	var parts: PackedStringArray = expression.split(" ", false)
	var result: bool = false
	var shown: String = ""
	if parts.size() == 1:
		var value: Variant = _resolve(parts[0])
		result = value is bool and value
		shown = str(value)
	elif parts.size() == 3 and OPERATORS.has(parts[1]):
		var value: Variant = _resolve(parts[0])
		result = _compare(value, parts[1], _parse_value(parts[2]), parts[2])
		shown = str(value)
	else:
		if record:
			_failures.append("malformed expression '%s'" % expression)
		return false
	if record:
		_checks += 1
		if result:
			print("Autoplay flow: ok   %s" % expression)
		else:
			print("Autoplay flow: FAIL %s (value: %s)" % [expression, shown])
			_failures.append("%s (value: %s)" % [expression, shown])
	return result


func _resolve(path: String) -> Variant:
	var dot: int = path.find(".")
	var root_name: String = path if dot < 0 else path.substr(0, dot)
	var rest: String = "" if dot < 0 else path.substr(dot + 1)
	if not ROOTS.has(root_name):
		push_error("Autoplay flow: unknown root '%s' in '%s'" % [root_name, path])
		return null
	if root_name == "settings":
		return Settings.get_value(rest)
	var target: Variant = _root(root_name)
	if rest.is_empty():
		return target
	for segment: String in _segments(rest):
		if target is Dictionary:
			var dictionary: Dictionary = target
			target = dictionary.get(segment)
			continue
		if not (target is Object) or not is_instance_valid(target):
			return null
		var object: Object = target
		var paren: int = segment.find("(")
		if paren > 0 and segment.ends_with(")"):
			var method: String = segment.substr(0, paren)
			var arguments: Array = []
			for argument: String in segment.substr(paren + 1, segment.length() - paren - 2).split(",", false):
				arguments.append(_parse_value(argument.strip_edges()))
			target = object.callv(method, arguments) if object.has_method(method) else null
		else:
			target = object.get_indexed(NodePath(segment))
	return target


## Split "a.b(c,d).e:f" at the dots that are not inside parentheses.
func _segments(rest: String) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	var depth: int = 0
	var start: int = 0
	for i: int in rest.length():
		var ch: String = rest[i]
		if ch == "(":
			depth += 1
		elif ch == ")":
			depth -= 1
		elif ch == "." and depth == 0:
			result.append(rest.substr(start, i - start))
			start = i + 1
	result.append(rest.substr(start))
	return result


func _root(root_name: String) -> Variant:
	var level: LevelBase = Game.level
	match root_name:
		"game":
			return Game
		"flow":
			return Flow
		"sim":
			return Sim
		"save":
			return Save
		"input":
			return GameInput
		"audio":
			return Audio
		"level":
			return level
		"hero":
			return level.player if level != null else null
		"hero2", "hero3", "hero4":
			return level.get_hero(int(root_name.substr(4)) - 1) if level != null else null
		"boss":
			if level == null or level.get_kind(Defs.Kind.BOSS).is_empty():
				return null
			return level.get_kind(Defs.Kind.BOSS)[0]
		"enemy":
			return _nearest_enemy(level)
		"hud":
			return get_tree().get_first_node_in_group(Defs.GROUP_HUD)
		"scene":
			return get_tree().current_scene
		"tree":
			return get_tree()
		"events":
			return _events
	return null


func _nearest_enemy(level: LevelBase) -> EnemyBase:
	if level == null or level.player == null:
		return null
	var best: EnemyBase = null
	var best_distance: int = 0
	for entity: SimEntity in level.get_kind(Defs.Kind.ENEMY):
		var enemy: EnemyBase = entity as EnemyBase
		if enemy == null or enemy.dead:
			continue
		var delta: Vector2i = enemy.sim_pos - level.player.sim_pos
		var distance: int = absi(delta.x) + absi(delta.y)
		if best == null or distance < best_distance:
			best = enemy
			best_distance = distance
	return best


func _parse_value(text: String) -> Variant:
	if text == "true":
		return true
	if text == "false":
		return false
	if text == "null":
		return null
	if text.is_valid_int():
		return text.to_int()
	if text.is_valid_float():
		return text.to_float()
	return text


## Compare `actual` with the parsed `expected`; text values are compared with the value as written (`raw`), so
## "0000000" matches a HUD text exactly.
func _compare(actual: Variant, op: String, expected: Variant, raw: String) -> bool:
	var numeric: bool = _is_number(actual) and _is_number(expected)
	if numeric:
		var a: float = float(actual)
		var b: float = float(expected)
		match op:
			"==":
				return is_equal_approx(a, b)
			"!=":
				return not is_equal_approx(a, b)
			"<":
				return a < b
			"<=":
				return a <= b
			">":
				return a > b
			">=":
				return a >= b
		return false
	var same: bool = false
	if actual == null or expected == null:
		same = actual == null and expected == null
	elif actual is bool or expected is bool:
		same = typeof(actual) == typeof(expected) and actual == expected
	else:
		same = str(actual) == raw
	match op:
		"==":
			return same
		"!=":
			return not same
	return false


func _is_number(value: Variant) -> bool:
	return typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT


# --- Helpers -----------------------------------------------------------------------------------------------------

func _arg(command: PackedStringArray, index: int) -> String:
	return command[index] if index < command.size() else ""


func _int_arg(command: PackedStringArray, index: int, default: int) -> int:
	return command[index].to_int() if index < command.size() and command[index].is_valid_int() else default


## A path of the script: res:// and absolute paths as they are, anything else relative to the project.
func _project_path(path: String) -> String:
	if path.begins_with("res://") or path.is_absolute_path():
		return path
	return "res://" + path


func _finish(exit_code: int) -> void:
	if _finished:
		return
	_finished = true
	GameInput.clear_scripted()
	var file: FileAccess = FileAccess.open(_out_dir + "/trace.json", FileAccess.WRITE)
	if file != null:
		var rows: Array[Array] = []
		for i: int in _trace_levels.size():
			var k: int = i * 8
			rows.append([_trace[k], String(_trace_levels[i]), _trace[k + 1], _trace[k + 2], _trace[k + 3],
				_trace[k + 4], _trace[k + 5], _trace[k + 6], _trace[k + 7] != 0])
		file.store_string(JSON.stringify({
			"columns": ["frame", "level", "tick", "x", "y", "xvel", "yvel", "state", "dead"], "rows": rows,
		}))
		file.close()
	print("Autoplay flow: %d check(s), %d failure(s), %d screenshot(s), %d tick(s), %d frame(s)" % [
		_checks, _failures.size(), _shots, _ticks, _frame,
	])
	for failure: String in _failures:
		print("Autoplay flow: failed: %s" % failure)
	print("Autoplay flow: RESULT %s" % ("PASS" if exit_code == EXIT_OK else "FAIL"))
	Autoplay.finished.emit(exit_code)
	Flow.shutdown_and_quit(exit_code)
