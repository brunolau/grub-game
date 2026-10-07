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
##   key <name> [<name> ...]          press and release keys by name (`key B R U T`, `key Enter`), for typing; a
##                                    name with a space is written with `_` (`key Kp_0`, Num 0)
##   hold <name> [<name> ...]         press keys by physical position and keep them down (`hold D Space` for P1,
##                                    `hold Kp_4 Kp_0` for P2 of the classic layout); with `input device` the heroes
##                                    read them, one tick per frame with --fast
##   release <name> [<name> ...]|all  let held keys go (`release all`: every key a `hold` pressed)
##   pad <button> [frames]            press and release a gamepad control as a real pad reports it (device 0, no
##                                    action event): a button index or name (a, b, x, y, back, start, up, down, left,
##                                    right, lb, rb) or a stick direction (lx-, lx+, ly-, ly+); `frames` held
##                                    (default 2). For gamepad-only menu paths through the input map
##   play <ticks:KEYS,...>            gameplay input for the next ticks, keys L R U D F K S as in `--inputs`; waits
##                                    until it is played or gameplay ends (level completed, game over, or another
##                                    stage starts: a linked sub-stage, a bonus stage behind a warp, the stage after a
##                                    trophy). Outside `play` the hero gets no input. Several heroes: one key set per
##                                    player separated by `|` (`play 8:R|L,4:|U`; an empty part = that player idle;
##                                    Autoplay.parse_inputs_multi)
##   play_file <path>                 the same, read from a file (commas or new lines; `#` lines are comments; a
##                                    `# route:` header names the number of players)
##   input device|script [<player>]   `device`: the hero reads the real devices (keys and pads sent with `key` / `pad`,
##                                    which then also run the clock with --fast); `script` (the default): only `play`.
##                                    With a player number (1..4) only that player's hero switches; the others keep
##                                    their input
##   weapon <name> [<player>]         hand a hero this weapon (club, hammer, axe, boomerang, spear): P1 by default
##                                    (Game.set_weapon), or player 2..4 (Game.runs[player - 1]); e.g. the one a route
##                                    was recorded with
##   shot <name>                      save a screenshot now: <out>/<NN>_<name>.png
##   every <ticks> [name]             also save a screenshot every <ticks> simulation ticks (0 = off):
##                                    <out>/t<tick count>_<name>.png
##   expect <expr>                    check a condition; a failure is reported and sets the exit code
##   log <path> [<path> ...]          print values
##   reset_events                     set the `events.*` counters back to zero
##   start_level <id> [expert] [players=<n>]   shortcut for segment work: a new run straight into a level (no
##                                    menus); with players=2..4 a co-op run of that party (a versus run in an arena)
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
## xvel, yvel, state, dead]; with a party also one "party" row per tick and further hero: [frame, level, tick, player,
## x, y, xvel, yvel, state, dead].
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
## The input of the running `play`, one stream per player slot (all of the same length `_length`).
var _streams: Array[PackedInt32Array] = []
var _length: int = 0
var _flag_index: int = 0
## Sim.total_ticks of the last sample that read the script, and the entry that sample read (every slot of one
## tick reads the same entry, whichever slots are scripted).
var _sampled_at: int = -1
var _current: int = 0
## Player slots that read the real devices (`input device [<player>]`), one bit per slot.
var _device_slots: int = 0
## Further heroes of a party, per tick: frame, tick, slot, x, y, xvel, yvel, state, dead (and the level of each row).
var _party_trace: PackedInt32Array = PackedInt32Array()
var _party_levels: Array[StringName] = []
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
## Keys a `hold` pressed and no `release` let go yet.
var _held_keys: Array[Key] = []


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


## The commands of a flow script and how many arguments each takes ([min, max]; -1 = any number).
const COMMAND_ARGS: Dictionary = {
	"wait": [1, 1], "wait_until": [1, -1], "press": [1, 2], "key": [1, -1], "hold": [1, -1], "release": [1, -1],
	"pad": [1, 2], "play": [1, -1],
	"play_file": [1, 1], "input": [1, 2], "weapon": [1, 2], "shot": [1, -1], "every": [1, 2], "expect": [1, -1],
	"log": [1, -1], "reset_events": [0, 0], "start_level": [1, 3], "window": [2, 2], "focus": [1, 1],
	"quit": [0, 0],
}
## Pad control names of `pad` (besides button numbers).
const PAD_NAMES: PackedStringArray = [
	"a", "b", "x", "y", "back", "start", "up", "down", "left", "right", "lb", "rb", "lx-", "lx+", "ly-", "ly+",
]


## Check a flow script without running it (tests/test_integration_flows.gd): every command known with the right
## number of arguments, actions, keys, pad controls, weapons, player numbers and expression roots valid, `play`
## inputs readable. Returns {"errors": PackedStringArray (a broken script), "missing": PackedStringArray (a
## `play_file` route or a `start_level` level that does not exist yet - the open stops of a skeleton flow)}, each
## line "line <n>: <what>".
static func lint(script_text: String) -> Dictionary:
	var errors: PackedStringArray = PackedStringArray()
	var missing: PackedStringArray = PackedStringArray()
	var number: int = 0
	for raw: String in script_text.split("\n"):
		number += 1
		var line: String = raw.strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		var command: PackedStringArray = line.split(" ", false)
		var op: String = command[0]
		var at: String = "line %d: " % number
		if not COMMAND_ARGS.has(op):
			errors.append(at + "unknown command '%s'" % op)
			continue
		var bounds: Array = COMMAND_ARGS[op]
		var count: int = command.size() - 1
		if count < int(bounds[0]) or (int(bounds[1]) >= 0 and count > int(bounds[1])):
			errors.append(at + "'%s' takes %d..%s argument(s), not %d" % [op, bounds[0],
					"any" if int(bounds[1]) < 0 else str(bounds[1]), count])
			continue
		match op:
			"wait", "every", "window":
				for argument: String in command.slice(1, 3 if op == "window" else 2):
					if not argument.is_valid_int():
						errors.append(at + "'%s' needs a number, not '%s'" % [op, argument])
			"press":
				if not InputMap.has_action(StringName(command[1])):
					errors.append(at + "unknown action '%s'" % command[1])
			"key", "hold", "release":
				for key_name: String in command.slice(1):
					if key_code(key_name) == KEY_NONE and not (op == "release" and key_name == "all"):
						errors.append(at + "unknown key '%s'" % key_name)
			"pad":
				if not PAD_NAMES.has(command[1].to_lower()) and not command[1].is_valid_int():
					errors.append(at + "unknown pad control '%s'" % command[1])
			"input":
				if command[1] != "device" and command[1] != "script":
					errors.append(at + "'input' needs 'device' or 'script'")
				if count == 2 and not _is_player(command[2]):
					errors.append(at + "'%s' is not a player number" % command[2])
			"weapon":
				var known: bool = false
				for weapon: int in Defs.Weapon.values():
					known = known or Defs.weapon_name(weapon) == command[1]
				if not known:
					errors.append(at + "unknown weapon '%s'" % command[1])
				if count == 2 and not _is_player(command[2]):
					errors.append(at + "'%s' is not a player number" % command[2])
			"play":
				_lint_inputs(" ".join(command.slice(1)).replace(" ", ","), at, errors)
			"play_file":
				var path: String = command[1] if command[1].begins_with("res://") else "res://" + command[1]
				if not FileAccess.file_exists(path):
					missing.append(at + "route %s" % command[1])
				else:
					_lint_inputs(FileAccess.get_file_as_string(path), at, errors)
			"expect", "wait_until", "log":
				var parts: PackedStringArray = command.slice(1)
				if op == "wait_until" and (parts.size() == 4 or parts.size() == 2) and parts[parts.size() - 1].is_valid_int():
					parts = parts.slice(0, parts.size() - 1)
				var paths: PackedStringArray = parts if op == "log" else PackedStringArray([parts[0]])
				if op != "log" and parts.size() != 1 and (parts.size() != 3 or not OPERATORS.has(parts[1])):
					errors.append(at + "'%s' needs '<path> <op> <value>' or '<path>'" % " ".join(parts))
				for path: String in paths:
					var root: String = path.get_slice(".", 0).get_slice(":", 0).get_slice("(", 0)
					if not ROOTS.has(root):
						errors.append(at + "unknown root '%s' (%s)" % [root, ", ".join(ROOTS)])
			"start_level":
				if not Levels.has_level(StringName(command[1])):
					missing.append(at + "level %s" % command[1])
				for argument: String in command.slice(2):
					var players: String = argument.trim_prefix("players=")
					if argument != "expert" and not (argument.begins_with("players=") and _is_player(players)):
						errors.append(at + "'%s' is not 'expert' or 'players=<n>'" % argument)
			"focus":
				if command[1] != "out" and command[1] != "in":
					errors.append(at + "'focus' needs 'out' or 'in'")
	return {"errors": errors, "missing": missing}


## The key of a key name (OS.find_keycode_from_string; `_` stands for a space: `Kp_0` is "Kp 0"); KEY_NONE when
## unknown.
static func key_code(key_name: String) -> Key:
	var code: Key = OS.find_keycode_from_string(key_name)
	if code == KEY_NONE and key_name.contains("_"):
		code = OS.find_keycode_from_string(key_name.replace("_", " "))
	return code


static func _is_player(text: String) -> bool:
	return text.is_valid_int() and text.to_int() >= 1 and text.to_int() <= Defs.MAX_PLAYERS


# Input entries of a `play` / `play_file`: every entry `ticks:KEYS[|KEYS...]` with known key letters.
static func _lint_inputs(text: String, at: String, errors: PackedStringArray) -> void:
	for line: String in text.split("\n"):
		if line.strip_edges().begins_with("#"):
			continue
		for entry: String in line.split(",", false):
			var item: String = entry.strip_edges()
			if item.is_empty():
				continue
			var colon: int = item.find(":")
			var count: String = (item if colon < 0 else item.substr(0, colon)).strip_edges()
			var keys: String = "" if colon < 0 else item.substr(colon + 1).replace("|", "").replace(" ", "").to_upper()
			var bad: bool = not count.is_valid_int()
			for letter: String in keys:
				bad = bad or not "LRUDFKS".contains(letter)
			if bad:
				errors.append(at + "bad input entry '%s'" % item)
				return


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
	_script_slots(-1)
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
		"hold", "release":
			for i: int in range(1, command.size()):
				if not _hold(command[i], op == "hold"):
					return false
			Input.flush_buffered_events()
			await get_tree().process_frame
		"pad":
			if not await _pad(_arg(command, 1), maxi(_int_arg(command, 2, DEFAULT_PRESS_FRAMES), 1)):
				return false
		"input":
			var slot: int = _player_arg(command, 2)
			if slot < -1:
				return false
			match _arg(command, 1):
				"device":
					if slot < 0:
						GameInput.clear_scripted()
						_device_slots = (1 << Defs.MAX_PLAYERS) - 1
					else:
						GameInput.clear_scripted_slot(slot)
						_device_slots |= 1 << slot
				"script":
					_script_slots(slot)
					_device_slots = 0 if slot < 0 else _device_slots & ~(1 << slot)
				_:
					push_error("Autoplay flow: 'input' needs 'device' or 'script'")
					return false
			_device_input = _device_slots != 0
		"play":
			return await _play(rest)
		"play_file":
			return await _play(FileAccess.get_file_as_string(_project_path(rest)), true)
		"weapon":
			var weapon: int = -1
			for w: int in Defs.Weapon.values():
				if Defs.weapon_name(w) == _arg(command, 1):
					weapon = w
			var slot: int = _player_arg(command, 2)
			if weapon < 0 or slot < -1:
				push_error("Autoplay flow: 'weapon' needs club, hammer, axe, boomerang or spear [and a player 1..%d]" %
						Defs.MAX_PLAYERS)
				return false
			slot = maxi(slot, 0)
			print("Autoplay flow: weapon %s handed over to P%d (the hero carried %s)" % [_arg(command, 1), slot + 1,
					Defs.weapon_name(Game.runs[slot].weapon)])
			if slot == 0:
				Game.set_weapon(weapon)
			else:
				Game.runs[slot].set_weapon(weapon)
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
			var difficulty: int = Defs.Difficulty.EXPERT if command.slice(2).has("expert") else Defs.Difficulty.BEGINNER
			var level_id: StringName = StringName(_arg(command, 1))
			var players: int = 1
			for argument: String in command.slice(2):
				if argument.begins_with("players="):
					players = clampi(argument.substr(8).to_int(), 1, Defs.MAX_PLAYERS)
			var book: int = maxi(Levels.get_book(level_id), 1)
			if players > 1 or book > 1:
				var mode: int = Defs.GameMode.VERSUS if Levels.is_arena(level_id) else Defs.GameMode.COOP
				Game.start_run(difficulty, mode if players > 1 else Defs.GameMode.SINGLE, players, book)
			else:
				Game.new_game(difficulty)
			Flow.start_level(level_id, Defs.Transition.NONE)
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


## Press (`down`) or release one key by physical position for `hold` / `release` (`release all` lets every held key
## go); false for an unknown name.
func _hold(key_name: String, down: bool) -> bool:
	if not down and key_name == "all":
		for code: Key in _held_keys.duplicate():
			_hold_event(code, false)
		return true
	var code: Key = key_code(key_name)
	if code == KEY_NONE:
		push_error("Autoplay flow: unknown key '%s'" % key_name)
		return false
	if down != _held_keys.has(code):
		_hold_event(code, down)
	return true


func _hold_event(code: Key, down: bool) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = down
	Input.parse_input_event(event)
	if down:
		_held_keys.append(code)
	else:
		_held_keys.erase(code)


func _key(key_name: String) -> void:
	var code: Key = key_code(key_name)
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
## ran for STALL_FRAMES frames (paused, or nothing to simulate). `from_file`: the text of a route file (its comment
## lines, the `# route:` header among them, are kept as they are).
func _play(script_text: String, from_file: bool = false) -> bool:
	# Entries may also be separated by spaces (on a `play` line, and between the entries of a file).
	var lines: PackedStringArray = PackedStringArray()
	for line: String in script_text.split("\n"):
		lines.append(line if from_file and line.strip_edges().begins_with("#") else line.replace(" ", ","))
	_streams = Autoplay.parse_inputs_multi("\n".join(lines))
	_length = _streams[0].size()
	var heroes: int = Game.level.hero_count() if is_instance_valid(Game.level) else 1
	if _streams.size() > maxi(heroes, 1):
		push_warning("Autoplay flow: the input has %d players, the level %d hero(es)" % [_streams.size(), heroes])
	_flag_index = 0
	_playing = true
	var idle_frames: int = 0
	var stalled: int = 0
	var last_index: int = 0
	var played: bool = true
	# The stage is told apart by its instance id: a freed level compares equal to null.
	var stage: int = Game.level.get_instance_id() if Game.level != null else 0
	while _flag_index < _length:
		await get_tree().process_frame
		if Flow.current_screen != Flow.SCREEN_LEVEL and not Flow.busy:
			idle_frames += 1
			if idle_frames > 2:
				print("Autoplay flow: gameplay ended after %d of %d ticks" % [_flag_index, _length])
				break
		var current: int = Game.level.get_instance_id() if is_instance_valid(Game.level) else 0
		if stage == 0:
			stage = current
		elif current != 0 and current != stage:
			# A linked sub-stage, a bonus stage or the stage after a trophy took over: its own input comes next.
			print("Autoplay flow: %s started after %d of %d ticks" % [Game.level.level_id, _flag_index, _length])
			break
		stalled = 0 if _flag_index != last_index else stalled + 1
		last_index = _flag_index
		if stalled >= STALL_FRAMES:
			_failures.append("play: no tick ran for %d frames (paused?)" % STALL_FRAMES)
			played = false
			break
	_streams = []
	_length = 0
	_flag_index = 0
	_playing = false
	return played


## Script player slot `slot` (every slot for -1): its hero gets the input of `play` and nothing outside it.
func _script_slots(slot: int) -> void:
	for s: int in Defs.MAX_PLAYERS:
		if slot < 0 or s == slot:
			GameInput.set_scripted_slot(s, _next_flags if s == 0 else _slot_flags.bind(s))


func _next_flags(_tick: int) -> int:
	return _scripted_flags(0)


func _slot_flags(_tick: int, slot: int) -> int:
	return _scripted_flags(slot)


## The flags of player slot `slot` for the tick being sampled: one entry of the `play` per tick, the same entry for
## every slot (the first slot sampled in a tick takes it), 0 outside a `play` and for a slot the input does not name.
func _scripted_flags(slot: int) -> int:
	if _sampled_at != Sim.total_ticks:
		_sampled_at = Sim.total_ticks
		_current = _flag_index
		if _flag_index < _length:
			_flag_index += 1
	if _current >= _length or slot >= _streams.size():
		return 0
	return _streams[slot][_current]


## Player number argument `index` of a command (1..Defs.MAX_PLAYERS) as a slot (0-based); -1 when the command has
## none, -2 (and an error) for a bad one.
func _player_arg(command: PackedStringArray, index: int) -> int:
	if index >= command.size():
		return -1
	var text: String = command[index]
	if text.is_valid_int() and text.to_int() >= 1 and text.to_int() <= Defs.MAX_PLAYERS:
		return text.to_int() - 1
	push_error("Autoplay flow: '%s' is not a player number (1..%d)" % [text, Defs.MAX_PLAYERS])
	return -2


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
		for slot: int in range(1, level.hero_count()):
			var other: PlayerBase = level.get_hero(slot)
			if other != null:
				_party_trace.append_array([_frame, tick, slot + 1, other.sim_pos.x, other.sim_pos.y, other.xvel,
						other.yvel, other.state, 1 if other.dead else 0])
				_party_levels.append(level.level_id)
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
	_hold("all", false)
	GameInput.clear_scripted()
	var file: FileAccess = FileAccess.open(_out_dir + "/trace.json", FileAccess.WRITE)
	if file != null:
		var rows: Array[Array] = []
		for i: int in _trace_levels.size():
			var k: int = i * 8
			rows.append([_trace[k], String(_trace_levels[i]), _trace[k + 1], _trace[k + 2], _trace[k + 3],
				_trace[k + 4], _trace[k + 5], _trace[k + 6], _trace[k + 7] != 0])
		var trace: Dictionary = {
			"columns": ["frame", "level", "tick", "x", "y", "xvel", "yvel", "state", "dead"], "rows": rows,
		}
		if not _party_levels.is_empty():
			var party: Array[Array] = []
			for i: int in _party_levels.size():
				var k: int = i * 9
				party.append([_party_trace[k], String(_party_levels[i]), _party_trace[k + 1], _party_trace[k + 2],
					_party_trace[k + 3], _party_trace[k + 4], _party_trace[k + 5], _party_trace[k + 6],
					_party_trace[k + 7], _party_trace[k + 8] != 0])
			trace["party_columns"] = ["frame", "level", "tick", "player", "x", "y", "xvel", "yvel", "state", "dead"]
			trace["party"] = party
		file.store_string(JSON.stringify(trace))
		file.close()
	print("Autoplay flow: %d check(s), %d failure(s), %d screenshot(s), %d tick(s), %d frame(s)" % [
		_checks, _failures.size(), _shots, _ticks, _frame,
	])
	for failure: String in _failures:
		print("Autoplay flow: failed: %s" % failure)
	print("Autoplay flow: RESULT %s" % ("PASS" if exit_code == EXIT_OK else "FAIL"))
	Autoplay.finished.emit(exit_code)
	Flow.shutdown_and_quit(exit_code)
