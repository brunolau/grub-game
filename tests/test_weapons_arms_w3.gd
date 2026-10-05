extends TestCase
## Weapon proofs of World 3 and Feast Land C (owner: arms_w3): Frost Summit (w3_l1), Blizzard Pass (w3_l1b), Crystal
## Grotto (w3_l2, the swirling axe = boomerang is picked up inside) and Feast Land C (bonus_c).
##
## A run keeps its weapon from level to level (GAMEPLAY.md 8.1), and a swing locks the hero for the weapon's recovery
## (club 2 ticks, hammer and axe 6, swirling axe 12), so a route recorded with one weapon proves nothing for another.
## MATRIX names one route per (level, difficulty, weapon) a player can hold when entering the level: club, axe and
## hammer in World 3 (the axe of 1-2, the hammer of 2-1), and the swirling axe of 3-2 too in Feast Land C. Each cell is
## played from a fresh start with that weapon and must end the level the documented way (exit / warp back) without
## losing a life and without an engine warning or error. A Frost Summit cell goes on into Blizzard Pass with the
## same weapon's Blizzard Pass route (the linked pair as a campaign plays it); a Crystal Grotto cell ends with the
## swirling axe.
##
## Route-building aids (the matrix tests are skipped while one runs), several jobs in one Godot run:
##   WEAPONS_JOBS=<file>   one job per line, "probe|adapt <route> [club|hammer|axe|boomerang] [beginner|expert]
##       [level=<id>] [every=n] [ticks=from-to] [trace=<file>] [absorb] [out=<file>]"; <route> is a file of the route
##       folder or a res:// / absolute path. A probe replays the route from a fresh run with that weapon and prints
##       the hero's cell, state and the events after every input line (every n ticks, every tick inside `ticks`;
##       `trace` writes "tick x y xvel yvel state dead" per tick). An adapt replays a club route with another weapon
##       and delays the input a longer swing recovery would swallow (see _adapt), writing the result to `out`.
##   WEAPONS_PROBE=<route> / WEAPONS_ADAPT=<route> [WEAPONS_WEAPON=..] [WEAPONS_DIFF=expert] [WEAPONS_LEVEL=..]
##       [WEAPONS_EVERY=n] [WEAPONS_TICKS=a-b] [WEAPONS_TRACE=..] [WEAPONS_ABSORB=1] [WEAPONS_OUT=..]   one such job.

const ROUTE_DIR: String = "res://tools/autoplay/routes/"
## Logical view of the 1280 x 720 game window (integer scale 2): enemies wake by the view.
const VIEW: Vector2i = Vector2i(Tuning.VIEW_W, Tuning.VIEW_H)
const BEGINNER: String = "beginner"
const EXPERT: String = "expert"
const WEAPON_NAMES: Array[String] = ["club", "hammer", "axe", "boomerang"]

## Every cell: level -> mode -> weapon (Defs.Weapon) -> route file. The club routes are the campaign routes.
const MATRIX: Dictionary = {
	"w3_l1": {
		BEGINNER: {Defs.Weapon.CLUB: "w3_l1.inputs"},
		EXPERT: {Defs.Weapon.CLUB: "w3_l1.expert.inputs"},
	},
	"w3_l1b": {
		BEGINNER: {Defs.Weapon.CLUB: "w3_l1b.inputs"},
		EXPERT: {Defs.Weapon.CLUB: "w3_l1b.expert.inputs"},
	},
	"w3_l2": {
		BEGINNER: {Defs.Weapon.CLUB: "w3_l2.inputs"},
		EXPERT: {Defs.Weapon.CLUB: "w3_l2.expert.inputs"},
	},
	"bonus_c": {
		BEGINNER: {Defs.Weapon.CLUB: "bonus_c.inputs"},
		EXPERT: {Defs.Weapon.CLUB: "bonus_c.inputs"},
	},
}

## The weapons a player can hold when entering each level (pick-ups: 1-2 axe, 2-1 hammer, 3-2 swirling axe).
const ENTRY_WEAPONS: Dictionary = {
	"w3_l1": [Defs.Weapon.CLUB, Defs.Weapon.AXE, Defs.Weapon.HAMMER],
	"w3_l1b": [Defs.Weapon.CLUB, Defs.Weapon.AXE, Defs.Weapon.HAMMER],
	"w3_l2": [Defs.Weapon.CLUB, Defs.Weapon.AXE, Defs.Weapon.HAMMER],
	"bonus_c": [Defs.Weapon.CLUB, Defs.Weapon.AXE, Defs.Weapon.HAMMER, Defs.Weapon.BOOMERANG],
}

## How each level ends: [exit kind, what follows ("tally" or "level:<id>"), source level of a bonus stage].
const ENDS: Dictionary = {
	"w3_l1": [&"exit", "level:w3_l1b", ""],
	"w3_l1b": [&"exit", "tally", ""],
	"w3_l2": [&"exit", "tally", ""],
	"bonus_c": [&"warp", "tally", "w3_l2"],
}


## Counts the warnings and errors the engine logs while a route plays.
class ProblemCounter:
	extends Logger

	var count: int = 0
	var first: String = ""

	func _log_error(
			function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool,
			_error_type: int, _script_backtraces: Array[ScriptBacktrace]
	) -> void:
		count += 1
		if first == "":
			first = "%s (%s:%d %s) %s" % [code, file, line, function, rationale]

	func _log_message(_message: String, _error: bool) -> void:
		pass


var _counts: Dictionary = {}
var _letters: Dictionary = {}
var _words: int = 0
var _exits: Array[StringName] = []
var _connections: Array[Array] = []
var _problems: ProblemCounter = null
## One line per cell played: the report of the matrix.
var _report: PackedStringArray = PackedStringArray()


func after_each() -> void:
	_stop_counting()
	for connection: Array in _connections:
		var signal_ref: Signal = connection[0]
		if signal_ref.is_connected(connection[1]):
			signal_ref.disconnect(connection[1])
	_connections.clear()
	_reset_watch()
	GameInput.clear_scripted()
	Sim.manual = false
	Sim.stop()
	if get_tree().current_scene != null:
		get_tree().current_scene.free()
		get_tree().current_scene = null
	Flow.current_screen = Flow.SCREEN_BOOT
	Flow.args = {}


# =================================================================================================================
# The matrix
# =================================================================================================================

## Every weapon a player can bring into each level, on every difficulty the level exists in, has a route.
func test_the_matrix_is_complete() -> void:
	for level_id: String in ENTRY_WEAPONS:
		for mode: String in [BEGINNER, EXPERT]:
			if not Levels.is_available(StringName(level_id), _difficulty(mode)):
				continue
			var cells: Dictionary = (MATRIX.get(level_id, {}) as Dictionary).get(mode, {})
			for weapon: int in ENTRY_WEAPONS[level_id]:
				assert_true(cells.has(weapon), "%s (%s) has a route for the %s" % [level_id, mode, WEAPON_NAMES[weapon]])
				if cells.has(weapon):
					assert_true(FileAccess.file_exists(ROUTE_DIR + str(cells[weapon])), "%s exists" % cells[weapon])


func test_frost_summit_with_every_weapon() -> void:
	await _play_level("w3_l1")


func test_blizzard_pass_with_every_weapon() -> void:
	await _play_level("w3_l1b")


func test_crystal_grotto_with_every_weapon() -> void:
	await _play_level("w3_l2")


func test_feast_land_c_with_every_weapon() -> void:
	await _play_level("bonus_c")


## Route-building aids: the jobs of WEAPONS_JOBS (or the single WEAPONS_PROBE / WEAPONS_ADAPT job), each from a
## fresh run, in one Godot run (see the header).
func test_route_aids() -> void:
	assert_true(true)
	for job: Dictionary in _jobs():
		print("=== JOB %s" % job["text"])
		if job["kind"] == "adapt":
			await _adapt(job)
		elif job["kind"] == "sync":
			await _sync(job)
		else:
			await _probe(job)
		after_each()


## Sync job: re-time a route (recorded with `base=<weapon>`, default the club) for the job's weapon. The base replay
## gives the hero's resting point at the end of every input line where he stands still; line by line the new
## replay must meet him there (same cell position, facing, no death, no more hits). Where it does not, the movement
## runs of the lines since the last meeting point are made a few ticks longer or shorter (the line's idle ticks pay
## the difference, so the world keeps its timing) until one variant meets him. Writes the result to `out` (default
## res://build/arms_w3/<route>.<weapon>.inputs) and prints every repair.
func _sync(job: Dictionary) -> void:
	var file: String = str(job["file"])
	var source_text: String = FileAccess.get_file_as_string(_route_path(file))
	var lines: Array[Dictionary] = _parse_lines(source_text)
	var base_weapon: int = WEAPON_NAMES.find(str(job.get("base", "club")))
	var first_line: int = int(str(job.get("from", "0")).to_int()) if job.has("from") and int(job["from"]) > 0 else 0
	var base_job: Dictionary = job.duplicate()
	base_job["weapon"] = base_weapon
	var ends: PackedInt32Array = _line_ends(lines)
	var base: Array[Dictionary] = await _replay_marks(base_job, _flatten(lines), ends)
	var fixes: PackedStringArray = PackedStringArray()
	var last_sync: int = -1
	for l: int in lines.size():
		var target: Dictionary = base[l]
		if not bool(target["rest"]) or int(target["deaths"]) > 0 or l < first_line:
			continue
		ends = _line_ends(lines)
		var now: Dictionary = (await _replay_marks(job, _flatten(lines), PackedInt32Array([ends[l]])))[0]
		if _meets(now, target):
			last_sync = l
			continue
		var found: bool = false
		var best: Array = [1 << 20, null]
		for j: int in range(l, last_sync, -1):
			var runs: Array = lines[j]["runs"]
			for r: int in runs.size():
				var run: Vector2i = runs[r]
				if (run.y & (Defs.IN_LEFT | Defs.IN_RIGHT | Defs.IN_UP)) == 0 and run.y != 0:
					continue
				for delta: int in [1, -1, 2, -2, 3, -3, 4, -4, 5, -5, 6, -6, 8, -8, 10, -10, 12]:
					var variant: Array[Dictionary] = _resize_run(lines, j, r, delta)
					if variant.is_empty():
						continue
					var check: Dictionary = (await _replay_marks(job, _flatten(variant),
							PackedInt32Array([_line_ends(variant)[l]])))[0]
					if _meets(check, target):
						fixes.append("L%d run %d (%dx%s) %+d for L%d" % [lines[j]["no"], r, run.x, _keys(run.y), delta,
							lines[l]["no"]])
						lines = variant
						found = true
						break
					var miss: int = absi(int(check["x"]) - int(target["x"])) + absi(int(check["y"]) - int(target["y"]))
					if int(check["deaths"]) == 0 and int(check["hurts"]) <= int(target["hurts"]) and miss < int(best[0]):
						best = [miss, variant]
				if found:
					break
			if found:
				break
		if found:
			last_sync = l
			continue
		print("SYNC %s: no variant meets the base hero at the end of L%d (base %s, now %s, closest miss %d px)" % [
			file, lines[l]["no"], _state_text(target), _state_text(now), best[0]])
		if best[1] != null and int(best[0]) <= 16:
			lines = best[1]
			fixes.append("L%d closest (%d px)" % [lines[l]["no"], best[0]])
		last_sync = l
	# The whole route once more: how it ends.
	ends = _line_ends(lines)
	var flags: PackedInt32Array = _flatten(lines)
	var final: Dictionary = (await _replay_marks(job, flags, PackedInt32Array([flags.size()])))[0]
	var result: String = "%s with the %s (%s): %d fixes, ends %s, exits %s, deaths %d, hurt %d" % [file,
		WEAPON_NAMES[int(job["weapon"])], job["mode"], fixes.size(), _state_text(final), str(final["exits"]),
		final["deaths"], final["hurts"]]
	print("SYNC " + result + "\n    " + "\n    ".join(fixes))
	var target_file: String = str(job["out"])
	if target_file.is_empty():
		target_file = "res://build/arms_w3/%s.%s.inputs" % [file.get_file().get_basename(), WEAPON_NAMES[int(job["weapon"])]]
	_write_lines(target_file, lines, "Synced from %s: %s" % [file.get_file(), result])


## The base hero is met: same position and facing, no death, no more hits than he took.
func _meets(now: Dictionary, target: Dictionary) -> bool:
	return int(now["x"]) == int(target["x"]) and int(now["y"]) == int(target["y"]) \
			and int(now["facing"]) == int(target["facing"]) and int(now["deaths"]) == 0 \
			and int(now["hurts"]) <= int(target["hurts"]) and bool(now["alive"])


func _state_text(state: Dictionary) -> String:
	return "x%d y%d f%d v(%d,%d) hurt %d deaths %d" % [state["x"], state["y"], state["facing"], state["xvel"],
		state["yvel"], state["hurts"], state["deaths"]]


## The input lines of a route: {"no": file line number, "comments": comment lines before it, "runs": [Vector2i(ticks,
## flags)]}; comments after the last input line go into a final entry without runs.
func _parse_lines(text: String) -> Array[Dictionary]:
	var lines: Array[Dictionary] = []
	var comments: PackedStringArray = PackedStringArray()
	var no: int = 0
	for line: String in text.split("\n"):
		no += 1
		var stripped: String = line.strip_edges()
		if stripped.begins_with("#"):
			comments.append(stripped)
			continue
		var runs: Array[Vector2i] = []
		for item: String in stripped.split(",", false):
			var entry: String = item.strip_edges()
			if entry.is_empty():
				continue
			var colon: int = entry.find(":")
			var count: int = (entry if colon < 0 else entry.substr(0, colon)).to_int()
			var keys: String = "" if colon < 0 else entry.substr(colon + 1).strip_edges().to_upper()
			runs.append(Vector2i(count, GameInput.keys_to_flags(keys)))
		if runs.is_empty():
			continue
		lines.append({"no": no, "comments": comments, "runs": runs})
		comments = PackedStringArray()
	if not comments.is_empty():
		lines.append({"no": no, "comments": comments, "runs": [] as Array[Vector2i]})
	return lines


func _flatten(lines: Array[Dictionary]) -> PackedInt32Array:
	var flags: PackedInt32Array = PackedInt32Array()
	for line: Dictionary in lines:
		for run: Vector2i in line["runs"]:
			for i: int in run.x:
				flags.append(run.y)
	return flags


## Tick count at the end of every line.
func _line_ends(lines: Array[Dictionary]) -> PackedInt32Array:
	var ends: PackedInt32Array = PackedInt32Array()
	var total: int = 0
	for line: Dictionary in lines:
		for run: Vector2i in line["runs"]:
			total += run.x
		ends.append(total)
	return ends


## A copy of `lines` with run `r` of line `j` longer by `delta`; the line's last idle run (after r) pays it back.
## Empty when a run would vanish.
func _resize_run(lines: Array[Dictionary], j: int, r: int, delta: int) -> Array[Dictionary]:
	var copy: Array[Dictionary] = []
	for line: Dictionary in lines:
		copy.append({"no": line["no"], "comments": line["comments"], "runs": (line["runs"] as Array).duplicate()})
	var runs: Array = copy[j]["runs"]
	var run: Vector2i = runs[r]
	if run.x + delta < 1:
		return []
	runs[r] = Vector2i(run.x + delta, run.y)
	for p: int in range(runs.size() - 1, r, -1):
		var pay: Vector2i = runs[p]
		if pay.y == 0 and pay.x - delta >= 1:
			runs[p] = Vector2i(pay.x - delta, 0)
			break
	return copy


## Replay `flags` from a fresh run of the job's level with the job's weapon; the hero's state at each tick of
## `marks` (ascending): position, speed, facing, at rest, hits and deaths so far, exits.
func _replay_marks(job: Dictionary, flags: PackedInt32Array, marks: PackedInt32Array) -> Array[Dictionary]:
	after_each()
	await _start_job(job)
	var states: Array[Dictionary] = []
	var index: Array[int] = [0]
	GameInput.set_scripted(func(_tick: int) -> int:
		var value: int = flags[index[0]] if index[0] < flags.size() else 0
		index[0] += 1
		return value
	)
	var level: LevelBase = Game.level
	var played: int = 0
	var still: int = 0
	for mark: int in marks:
		while played < mark and Sim.running and Game.level == level:
			Sim.step(1)
			played += 1
			var hero: PlayerBase = level.player
			still = still + 1 if hero != null and hero.xvel == 0 and hero.yvel == 0 and not hero.dead else 0
		var state: Dictionary = {"x": -1, "y": -1, "xvel": 0, "yvel": 0, "facing": 0, "rest": false, "alive": false,
			"hurts": _count(&"player_hurt"), "deaths": _count(&"player_died"), "exits": _exits.duplicate(),
			"tick": played}
		if Game.level == level and is_instance_valid(level) and level.player != null:
			var hero: PlayerBase = level.player
			state.merge({"x": hero.sim_pos.x, "y": hero.sim_pos.y, "xvel": hero.xvel, "yvel": hero.yvel,
				"facing": hero.facing, "rest": still >= 3 and hero.swing_lock == 0, "alive": not hero.dead}, true)
		states.append(state)
	GameInput.clear_scripted()
	return states


## Write route lines (with their comments) to `target`.
func _write_lines(target: String, lines: Array[Dictionary], note: String) -> void:
	var out: PackedStringArray = PackedStringArray(["# " + note])
	for line: Dictionary in lines:
		out.append_array(line["comments"] as PackedStringArray)
		var parts: PackedStringArray = PackedStringArray()
		for run: Vector2i in line["runs"]:
			parts.append("%d:%s" % [run.x, _keys(run.y).replace("-", "")])
		if not parts.is_empty():
			out.append(",".join(parts))
	var absolute: String = ProjectSettings.globalize_path(target) if target.begins_with("res://") else target
	DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	var handle: FileAccess = FileAccess.open(absolute, FileAccess.WRITE)
	if handle != null:
		handle.store_string("\n".join(out) + "\n")
		handle.close()
	print("WROTE " + absolute)


## The jobs to run: lines "probe|adapt <route> [club|hammer|axe|boomerang] [beginner|expert] [level=<id>] [every=n]
## [ticks=from-to] [trace=<file>] [absorb] [out=<file>]" of the file WEAPONS_JOBS, or one job from the WEAPONS_*
## variables.
func _jobs() -> Array[Dictionary]:
	var lines: PackedStringArray = PackedStringArray()
	var jobs_file: String = OS.get_environment("WEAPONS_JOBS")
	if not jobs_file.is_empty():
		lines = FileAccess.get_file_as_string(jobs_file).split("\n")
	else:
		var single: String = ""
		if not OS.get_environment("WEAPONS_PROBE").is_empty():
			single = "probe " + OS.get_environment("WEAPONS_PROBE")
		elif not OS.get_environment("WEAPONS_ADAPT").is_empty():
			single = "adapt " + OS.get_environment("WEAPONS_ADAPT")
		if single.is_empty():
			return []
		single += " " + (OS.get_environment("WEAPONS_WEAPON") if OS.get_environment("WEAPONS_WEAPON") != "" else "club")
		single += " expert" if OS.get_environment("WEAPONS_DIFF") == EXPERT else " beginner"
		for key: String in ["level", "every", "ticks", "trace", "out"]:
			if OS.get_environment("WEAPONS_" + key.to_upper()) != "":
				single += " %s=%s" % [key, OS.get_environment("WEAPONS_" + key.to_upper())]
		if OS.get_environment("WEAPONS_ABSORB") != "":
			single += " absorb"
		lines.append(single)
	var jobs: Array[Dictionary] = []
	for line: String in lines:
		var tokens: PackedStringArray = line.strip_edges().split(" ", false)
		if tokens.size() < 2 or tokens[0].begins_with("#"):
			continue
		var file: String = tokens[1]
		var job: Dictionary = {"text": line.strip_edges(), "kind": tokens[0], "file": file, "weapon": Defs.Weapon.CLUB,
			"mode": BEGINNER, "level": file.get_file().get_slice(".", 0), "every": 0, "from": -1, "to": -1, "trace": "",
			"absorb": false, "out": ""}
		for token: String in tokens.slice(2):
			if WEAPON_NAMES.has(token):
				job["weapon"] = WEAPON_NAMES.find(token)
			elif token == EXPERT or token == BEGINNER:
				job["mode"] = token
			elif token == "absorb":
				job["absorb"] = true
			elif token.begins_with("ticks="):
				job["from"] = token.get_slice("=", 1).get_slice("-", 0).to_int()
				job["to"] = token.get_slice("=", 1).get_slice("-", 1).to_int()
			elif token.contains("="):
				var key: String = token.get_slice("=", 0)
				var value: String = token.substr(key.length() + 1)
				job[key] = value.to_int() if key == "every" else value
		jobs.append(job)
	return jobs


## Start the job's level from a fresh run with its weapon.
func _start_job(job: Dictionary) -> void:
	var level_id: String = str(job["level"])
	Game.new_game(_difficulty(str(job["mode"])))
	if str(ENDS.get(level_id, ["", "", ""])[2]) != "":
		Game.warp_return_level = StringName(str(ENDS[level_id][2]))
	Game.set_weapon(int(job["weapon"]))
	await _enter(StringName(level_id))


func _route_path(file: String) -> String:
	return file if file.begins_with("res://") or file.is_absolute_path() else ROUTE_DIR + file


## Adapt job: replays a club route with another weapon. After every swing it delays the next input that the longer
## recovery would swallow (input the club route gives while the new weapon still locks) by just as many ticks as
## needed, so the hero meets the rest of the route in the same state; with `absorb` the delay is won back where he
## has stood still for a while and the route idles or crouches on. Writes the result (with the route's comments) to
## `out` (default res://build/arms_w3/<route>.<weapon>.inputs).
func _adapt(job: Dictionary) -> void:
	var file: String = str(job["file"])
	var source_text: String = FileAccess.get_file_as_string(_route_path(file))
	var original: PackedInt32Array = Autoplay.parse_inputs(source_text)
	var mode: String = str(job["mode"])
	var weapon: int = int(job["weapon"])
	var absorb: bool = bool(job["absorb"])
	await _start_job(job)
	# The weapon the route was recorded with at each point: the club, then whatever it picks up (so does the replay).
	var recorded: Array[int] = [Defs.Weapon.CLUB]
	var state: Dictionary = {"index": 0, "insert_at": -1, "insert_n": 0, "debt": 0, "padded": 0, "absorbed": 0,
		"swings": 0}
	var on_strike: Callable = func(_strike: int, used: int) -> void:
		state["swings"] += 1
		var old_lock: int = Tuning.WEAPON_LOCK[recorded[0]]
		var new_lock: int = Tuning.WEAPON_LOCK[used]
		var i: int = state["index"]
		for m: int in range(old_lock, new_lock):
			if i + m < original.size() and original[i + m] != 0:
				state["insert_at"] = i + m
				state["insert_n"] = new_lock - m
				state["padded"] += new_lock - m
				state["debt"] += new_lock - m
				break
	var on_weapon: Callable = func(new_weapon: int) -> void: recorded[0] = new_weapon
	_connect(Events.player_struck, on_strike)
	_connect(Game.weapon_changed, on_weapon)
	var out: PackedInt32Array = PackedInt32Array()
	var out_index: PackedInt32Array = PackedInt32Array()
	var rest: Array[int] = [0]
	GameInput.set_scripted(func(_tick: int) -> int:
		var hero: PlayerBase = Game.level.player if Game.level != null else null
		var still: bool = hero != null and hero.xvel == 0 and hero.yvel == 0 and hero.swing_lock == 0
		rest[0] = rest[0] + 1 if still else 0
		# Win the delay back where he has stood still for a while and the route idles or crouches on: one input fewer
		# changes nothing for him, and puts the world (enemies, the wind) back in step.
		while absorb and int(state["debt"]) > 0 and int(state["insert_n"]) == 0 and rest[0] > 8 \
				and int(state["index"]) + 1 < original.size() \
				and original[int(state["index"])] in [0, Defs.IN_DOWN] \
				and original[int(state["index"]) + 1] == original[int(state["index"])]:
			state["index"] += 1
			state["debt"] -= 1
			state["absorbed"] += 1
		var i: int = state["index"]
		if i == int(state["insert_at"]) and int(state["insert_n"]) > 0:
			state["insert_n"] -= 1
			out.append(0)
			out_index.append(-1)
			return 0
		var value: int = original[i] if i < original.size() else 0
		state["index"] = i + 1
		out.append(value)
		out_index.append(i)
		return value
	)
	var level: LevelBase = Game.level
	var played: int = 0
	var first_hurt: int = -1
	while int(state["index"]) < original.size() and Sim.running and Game.level == level:
		var hurts: int = _count(&"player_hurt") + _count(&"player_died")
		Sim.step(1)
		played += 1
		if first_hurt < 0 and _count(&"player_hurt") + _count(&"player_died") > hurts:
			first_hurt = played
	GameInput.clear_scripted()
	var result: String = "%s with the %s (%s): %d ticks (route %d), %d swings, %d ticks delayed, %d won back, exits %s, deaths %d, hurt %d (first at t%d), lives %d, score %d" % [
		file, WEAPON_NAMES[weapon], mode, played, original.size(), state["swings"], state["padded"], state["absorbed"],
		str(_exits), _count(&"player_died"), _count(&"player_hurt"), first_hurt, Game.lives, Game.score]
	print("ADAPT " + result)
	var target: String = str(job["out"])
	if target.is_empty():
		target = "res://build/arms_w3/%s.%s.inputs" % [file.get_file().get_basename(), WEAPON_NAMES[weapon]]
	_write_inputs(target, out, out_index, source_text, "Adapted from %s: %s" % [file.get_file(), result])


## Write `flags` as a route file: runs of equal input as "ticks:KEYS", the source's comment lines before the tick that
## played the input they precede (`at[t]` = index of the source input played at tick t, -1 = an inserted tick).
func _write_inputs(target: String, flags: PackedInt32Array, at: PackedInt32Array, source_text: String,
		note: String) -> void:
	var comments: Dictionary = {}
	var count: int = 0
	for line: String in source_text.split("\n"):
		if line.strip_edges().begins_with("#"):
			var notes: PackedStringArray = comments.get(count, PackedStringArray())
			notes.append(line.strip_edges())
			comments[count] = notes
		else:
			count += Autoplay.parse_inputs(line).size()
	var lines: PackedStringArray = PackedStringArray(["# " + note])
	var runs: PackedStringArray = PackedStringArray()
	var shown: Dictionary = {}
	var run_value: int = -1
	var run_length: int = 0
	for t: int in flags.size() + 1:
		var index: int = at[t] if t < at.size() else -1
		var comment: bool = index >= 0 and comments.has(index) and not shown.has(index)
		if t < flags.size() and flags[t] == run_value and not comment:
			run_length += 1
			continue
		if run_length > 0:
			runs.append("%d:%s" % [run_length, _keys(run_value).replace("-", "")])
		if comment or t == flags.size() or ",".join(runs).length() > 100:
			if not runs.is_empty():
				lines.append(",".join(runs))
			runs.clear()
		if comment:
			shown[index] = true
			lines.append_array(comments[index] as PackedStringArray)
		if t < flags.size():
			run_value = flags[t]
			run_length = 1
	var absolute: String = ProjectSettings.globalize_path(target) if target.begins_with("res://") else target
	DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	var handle: FileAccess = FileAccess.open(absolute, FileAccess.WRITE)
	if handle != null:
		handle.store_string("\n".join(lines) + "\n")
		handle.close()
	print("WROTE " + absolute)


## Probe job: replay a route and print the hero's cell, state and the events after every input line.
func _probe(job: Dictionary) -> void:
	var file: String = str(job["file"])
	var path: String = _route_path(file)
	assert_true(FileAccess.file_exists(path), "%s exists" % path)
	var mode: String = str(job["mode"])
	var weapon: int = int(job["weapon"])
	var every: int = maxi(int(job["every"]), 0)
	var from_tick: int = int(job["from"])
	var to_tick: int = int(job["to"])
	await _start_job(job)
	var log_lines: PackedStringArray = PackedStringArray()
	var on_event: Callable = func(signal_name: StringName) -> void: log_lines.append(String(signal_name))
	for info: Dictionary in Events.get_signal_list():
		var name: StringName = StringName(str(info["name"]))
		if name in [&"popup_requested", &"player_landed", &"player_jumped", &"shake_requested", &"wind_changed",
				&"player_struck"]:
			continue
		var callable: Callable = on_event.bind(name)
		var arguments: int = (info["args"] as Array).size()
		_connect(Signal(Events, name), callable.unbind(arguments) if arguments > 0 else callable)
	var trace_path: String = str(job["trace"])
	var trace: PackedStringArray = PackedStringArray()
	var played: int = 0
	var line_no: int = 0
	var comment: String = ""
	var level: LevelBase = Game.level
	for line: String in FileAccess.get_file_as_string(path).split("\n"):
		line_no += 1
		var stripped: String = line.strip_edges()
		if stripped.begins_with("#"):
			comment = stripped.substr(0, 60)
			continue
		var flags: PackedInt32Array = Autoplay.parse_inputs(stripped)
		for i: int in flags.size():
			if not Sim.running or Game.level != level:
				break
			played += _run(PackedInt32Array([flags[i]]))
			if (every > 0 and played % every == 0) or (played >= from_tick and played <= to_tick):
				print("    t%5d %s %s" % [played, _keys(flags[i]), _hero_text()])
			if not trace_path.is_empty() and Game.level == level and level.player != null:
				var hero: PlayerBase = level.player
				trace.append("%d %d %d %d %d %d %d" % [played, hero.sim_pos.x, hero.sim_pos.y, hero.xvel, hero.yvel,
					hero.state, int(hero.dead)])
		if flags.size() > 0:
			print("L%3d t%5d %s | %s %s" % [line_no, played, _hero_text(), " ".join(log_lines), comment])
			log_lines.clear()
			comment = ""
		if not Sim.running or Game.level != level:
			break
	if not trace_path.is_empty():
		var handle: FileAccess = FileAccess.open(trace_path, FileAccess.WRITE)
		if handle != null:
			handle.store_string("\n".join(trace) + "\n")
			handle.close()
	print("PROBE END %s %s %s: t%d exits %s deaths %d hurt %d score %d lives %d hearts %d weapon %d letters %s words %d secrets %d checkpoints %d spots %d/%d items %d/%d completion %d%%" % [
		file, mode, WEAPON_NAMES[weapon], played, str(_exits), _count(&"player_died"), _count(&"player_hurt"),
		Game.score, Game.lives, Game.hearts, Game.weapon, str(_letters.keys()), _words, _count(&"secret_found"),
		_count(&"checkpoint_activated"), Game.spots_opened, Game.spots_total, Game.items_collected, Game.items_total,
		Game.completion_percent()])


# =================================================================================================================
# Playing the cells
# =================================================================================================================

## Every cell of `level_id` on both difficulties, each from a fresh run.
func _play_level(level_id: String) -> void:
	if _dev_mode():
		assert_true(true, "the matrix is skipped while a route-building aid runs")
		return
	_report.clear()
	for mode: String in [BEGINNER, EXPERT]:
		var cells: Dictionary = (MATRIX[level_id] as Dictionary).get(mode, {})
		for weapon: int in cells:
			await _play_cell(level_id, mode, weapon, str(cells[weapon]))
			after_each()
	print("  weapon matrix %s:\n%s" % [level_id, "\n".join(_report)])


func _play_cell(level_id: String, mode: String, weapon: int, file: String) -> void:
	var label: String = "%s %s %s (%s)" % [level_id, mode, WEAPON_NAMES[weapon], file]
	Game.new_game(_difficulty(mode))
	var source: String = str(ENDS[level_id][2])
	if source != "":
		Game.warp_return_level = StringName(source)
	Game.set_weapon(weapon)
	await _enter(StringName(level_id))
	var lives: int = Game.lives
	var result: Dictionary = await _play_stage(level_id, file, label)
	var line: String = "    %-9s %-6s %s" % [mode, WEAPON_NAMES[weapon], result["text"]]
	# The linked second half: Blizzard Pass with the same weapon's route, as a campaign run plays the pair.
	var follows: String = str(ENDS[level_id][1])
	if follows.begins_with("level:") and result["left"] and Flow.current_screen == Flow.SCREEN_LEVEL:
		var next_id: String = follows.get_slice(":", 1)
		var next_file: String = str(((MATRIX[next_id] as Dictionary)[mode] as Dictionary).get(Game.weapon, ""))
		assert_ne(next_file, "", "%s: a %s route for the weapon carried on (%d)" % [label, next_id, Game.weapon])
		if next_file != "":
			var next: Dictionary = await _play_stage(next_id, next_file, "%s then %s" % [label, next_file])
			line += "\n    %-16s then %s" % ["", next["text"]]
	assert_true(Game.lives >= lives, "%s: no life lost (%d -> %d)" % [label, lives, Game.lives])
	_report.append(line)


## Play `file` in the running stage `level_id` and check how it ends. Returns {"left": bool, "text": summary}.
func _play_stage(level_id: String, file: String, label: String) -> Dictionary:
	assert_eq(Game.level_id, StringName(level_id), "%s plays in %s" % [label, level_id])
	_reset_watch()
	_start_counting()
	var lives: int = Game.lives
	var flags: PackedInt32Array = Autoplay.parse_inputs(FileAccess.get_file_as_string(ROUTE_DIR + file))
	assert_true(flags.size() > 100, "%s is a real input script" % label)
	var played: int = _run(flags)
	_stop_counting()
	var text: String = "%s: %d ticks, exits %s, hurt %d, deaths %d, lives %d, score %d, weapon %s, secrets %d, checkpoints %d, letters %d words %d, completion %d %%" % [
		file, played, str(_exits), _count(&"player_hurt"), _count(&"player_died"), Game.lives, Game.score,
		WEAPON_NAMES[Game.weapon], _count(&"secret_found"), _count(&"checkpoint_activated"), _letters.size(), _words,
		Game.completion_percent()]
	print("    %s -> %s" % [label, text])
	assert_eq(_count(&"player_died"), 0, "%s: no death" % label)
	assert_true(Game.lives >= lives, "%s: no life lost" % label)
	assert_eq(_problems.count, 0, "%s: no engine warning or error (first: %s)" % [label, _problems.first])
	var kind: StringName = ENDS[level_id][0]
	assert_eq(_exits, [kind] as Array[StringName], "%s leaves through its %s" % [label, kind])
	if level_id == "w3_l2":
		assert_eq(Game.weapon, Defs.Weapon.BOOMERANG, "%s: the swirling axe is taken" % label)
	var left: bool = _exits.size() == 1 and _exits[0] == kind
	if left:
		await _settle()
		var follows: String = str(ENDS[level_id][1])
		if follows == "tally":
			assert_eq(Flow.current_screen, Flow.SCREEN_TALLY, "%s: the tally follows" % label)
		else:
			assert_eq(Flow.current_screen, Flow.SCREEN_LEVEL, "%s: a stage follows without a tally" % label)
			assert_eq(Game.level_id, StringName(follows.get_slice(":", 1)), "%s leads on" % label)
			_set_view()
	return {"left": left, "text": text}


# =================================================================================================================
# Helpers
# =================================================================================================================

## Enter `level_id` through Flow like the world map does, with the clock under the test's control.
func _enter(level_id: StringName) -> void:
	_watch_events()
	Sim.manual = true
	await get_tree().process_frame
	while Flow.busy:
		await get_tree().process_frame
	Flow.start_level(level_id, Defs.Transition.NONE)
	await _settle()
	assert_eq(Flow.current_screen, Flow.SCREEN_LEVEL, "%s started" % level_id)
	assert_true(Game.level != null and Game.level.level_id == level_id, "%s is the running level" % level_id)
	_set_view()


## Headless runs have no window: give the level the view of the 1280 x 720 game window before its first tick.
func _set_view() -> void:
	var level: Level = Game.level as Level
	if level != null:
		level.set_view_size(VIEW * Tuning.ART_SCALE)


func _settle() -> void:
	for i: int in 3:
		await get_tree().process_frame
	while Flow.busy:
		await get_tree().process_frame


## Play input flags one tick after the other until they end or the level is left; returns the ticks played.
func _run(flags: PackedInt32Array) -> int:
	var index: Array[int] = [0]
	GameInput.set_scripted(func(_tick: int) -> int:
		var value: int = flags[index[0]] if index[0] < flags.size() else 0
		index[0] += 1
		return value
	)
	var played: int = 0
	var level: LevelBase = Game.level
	while played < flags.size() and Sim.running and Game.level == level:
		Sim.step(1)
		played += 1
	GameInput.clear_scripted()
	return played


func _watch_events() -> void:
	if not _connections.is_empty():
		return
	for info: Dictionary in Events.get_signal_list():
		var signal_name: StringName = StringName(str(info["name"]))
		var callable: Callable = _on_event.bind(signal_name)
		var arguments: int = (info["args"] as Array).size()
		_connect(Signal(Events, signal_name), callable.unbind(arguments) if arguments > 0 else callable)
	_connect(Events.item_collected, _on_item)
	_connect(Events.exit_reached, _on_exit)
	_connect(Game.letters_completed, _on_word)


func _connect(signal_ref: Signal, callable: Callable) -> void:
	signal_ref.connect(callable)
	_connections.append([signal_ref, callable])


func _reset_watch() -> void:
	_counts.clear()
	_letters.clear()
	_words = 0
	_exits.clear()


func _start_counting() -> void:
	_stop_counting()
	_problems = ProblemCounter.new()
	OS.add_logger(_problems)


func _stop_counting() -> void:
	if _problems != null:
		OS.remove_logger(_problems)


## True while one of the route-building aids runs (the matrix is skipped then).
func _dev_mode() -> bool:
	return not OS.get_environment("WEAPONS_PROBE").is_empty() or not OS.get_environment("WEAPONS_ADAPT").is_empty() \
			or not OS.get_environment("WEAPONS_JOBS").is_empty()


func _difficulty(mode: String) -> int:
	return Defs.Difficulty.EXPERT if mode == EXPERT else Defs.Difficulty.BEGINNER


func _count(signal_name: StringName) -> int:
	return int(_counts.get(signal_name, 0))


func _on_event(signal_name: StringName) -> void:
	_counts[signal_name] = _count(signal_name) + 1


func _on_item(item_id: StringName, index: int, _points: int, _pos: Vector2i) -> void:
	if item_id == &"items/letter":
		_letters[index] = true


func _on_exit(exit_kind: StringName) -> void:
	_exits.append(exit_kind)


func _on_word() -> void:
	_words += 1


func _keys(flags: int) -> String:
	var keys: String = ""
	for pair: Array in [[Defs.IN_LEFT, "L"], [Defs.IN_RIGHT, "R"], [Defs.IN_UP, "U"], [Defs.IN_DOWN, "D"],
			[Defs.IN_FIRE, "F"], [Defs.IN_LOOK, "K"]]:
		if flags & int(pair[0]):
			keys += str(pair[1])
	return keys if keys != "" else "-"


func _hero_text() -> String:
	var level: LevelBase = Game.level
	if level == null or level.player == null:
		return "(no hero)"
	var hero: PlayerBase = level.player
	return "x%5d y%5d c%3d r%3d st%2d v(%4d,%4d) h%d w%d lock%2d%s" % [hero.sim_pos.x, hero.sim_pos.y,
		hero.sim_pos.x >> 4, (hero.sim_pos.y - 1) >> 4, hero.state, hero.xvel, hero.yvel, Game.hearts, Game.weapon,
		hero.swing_lock, " DEAD" if hero.dead else ""]
