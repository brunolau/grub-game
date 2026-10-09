extends Node
## D5 development probe (see probe.gd). Injects draft level files into the registry, validates them, runs the solo
## search on their gates, measures sign texts, replays routes printing the heroes, and RECORDS routes from closed-loop
## macro scripts (--rec): every command is evaluated against the live simulation before each tick, the flags it
## gives are stored, and the result is written as an open-loop route file and replayed through the bench runner.
##
## Macro script (--rec=<file>), one directive per line:
##   header: <a header line of the route file, the first one is the "# route:" line>
##   out: <route file name>           (written into --dir)
##   seg: <comment>                   starts a segment (both players' commands run in parallel; the segment ends
##                                     when both lists are exhausted)
##   p1: <commands>   p2: <commands>  (appended to the current segment)
## A command: KEYS*N (hold N ticks), KEYS?EXPR[;MAX] (hold until EXPR is true, checked before each tick),
## KEYS!T (hold until stage tick T), |name (barrier: wait for the other player's |name). KEYS are L R U D F K S or
## nothing. EXPR variables: x y vx vy g t c st px py pg dn (partner of p2 is p1); methods of this node (en(), bs()...).

const RUNNER: String = "res://scripts/core/dev/sim_bench_runner.gd"

var _opts: Dictionary = {}
var _ids: Array[StringName] = []
var _every: int = 10
var _from: int = 0
var _to: int = 999999
var _tick: int = 0
var _last: Dictionary = {}
var _hero: PlayerBase = null
var _level: LevelBase = null
var _quiet_events: bool = false
var _jump_ahead: int = 70
var _cur_flags: Array[int] = [0, 0, 0, 0]


func run(arguments: PackedStringArray) -> int:
	for argument: String in arguments:
		if argument.begins_with("--"):
			var eq: int = argument.find("=")
			if eq < 0:
				_opts[argument.substr(2)] = ""
			else:
				_opts[argument.substr(2, eq - 2)] = argument.substr(eq + 1)
	var levels: Node = get_tree().root.get_node("Levels")
	for path: String in str(_opts.get("level", "")).split(",", false):
		var text: String = FileAccess.get_file_as_string(path)
		var id: StringName = StringName(path.get_file().get_basename())
		levels._meta[id] = levels.parse_meta(text)
		levels._paths[id] = path
		_ids.append(id)
	levels._index_campaign()
	var user: String = "res://build/run_users/levels_recp_%d" % OS.get_process_id()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(user))
	Save.set_storage_dir(user)
	Settings.set_storage_dir(user)
	_every = int(_opts.get("every", "10"))
	_from = int(_opts.get("from", "0"))
	_to = int(_opts.get("to", "999999"))
	if _opts.has("signs"):
		_signs(str(_opts["signs"]))
	if _opts.has("validate"):
		_validate()
	if _opts.has("search"):
		_search(str(_opts["search"]))
	if _opts.has("allgates"):
		await _all_gates(_opts.has("noyield"))
	if _opts.has("throwtest"):
		var tt: PackedStringArray = str(_opts["throwtest"]).split(",")
		var data_t: LevelData = LevelData.load_file(Levels.get_level_path(StringName(tt[0])))
		var grid_t: TileGrid = CoopSearch.grid_at_rest(data_t, Defs.Difficulty.BEGINNER)
		var ca: Vector2i = Vector2i(tt[1].to_int(), tt[2].to_int())
		var cb: Vector2i = Vector2i(tt[3].to_int(), tt[4].to_int())
		var sa: Array[Vector2i] = CoopSearch.strike_spots(grid_t, ca)
		var sb: Array[Vector2i] = CoopSearch.strike_spots(grid_t, cb)
		print("spots a %s b %s" % [str(sa), str(sb)])
		for sp: Vector2i in sa:
			var one: Array[Vector2i] = [sp]
			print("from a spot %s crosses b: %s" % [sp, CoopSearch.throw_crosses(one, cb)])
		for sp: Vector2i in sb:
			var one2: Array[Vector2i] = [sp]
			print("from b spot %s crosses a: %s" % [sp, CoopSearch.throw_crosses(one2, ca)])
	if _opts.has("rec"):
		await _record(str(_opts["rec"]))
	elif _opts.has("route"):
		await _route(str(_opts["route"]))
	return 0


# =================================================================================================================
# Signs, validator, search
# =================================================================================================================

func _signs(path: String) -> void:
	var key: String = ""
	for line: String in FileAccess.get_file_as_string(path).split("\n"):
		line = line.strip_edges()
		if line.begins_with("msgid "):
			key = line.substr(7, line.length() - 8)
		elif line.begins_with("msgstr ") and key != "":
			var text: String = line.substr(8, line.length() - 9).c_unescape()
			print("SIGN %-26s %d lines %3d chars  %s" % [key, SignBoard.text_lines(text), text.length(), text])


func _validate() -> void:
	var validator: LevelValidator = LevelValidator.new()
	validator.add_folder("res://levels")
	for id: StringName in _ids:
		var path: String = Levels.get_level_path(id)
		if not path.begins_with("res://levels/"):
			validator.add_file(path)
	validator.run()
	var only: Array[StringName] = _ids.duplicate()
	if only.is_empty():
		for id: StringName in Levels.all_ids():
			if String(id).begins_with("w5_") or String(id).begins_with("bonus_d"):
				only.append(id)
	for id: StringName in only:
		var path: String = Levels.get_level_path(id)
		var problems: Array[Dictionary] = validator.problems_of(path)
		print("VALIDATE %s: %d problem(s)" % [id, problems.size()])
		for problem: Dictionary in problems:
			print("  " + LevelValidator.format_problem(problem))


## Every co-op gate as tests/test_coop_gates.gd lists them, one frame between gates (the message queue is flushed).
func _all_gates(no_yield: bool) -> void:
	var failures: int = 0
	var count: int = 0
	for level_id: StringName in Levels.all_ids():
		if not Levels.is_coop_level(level_id):
			continue
		var data: LevelData = LevelData.load_file(Levels.get_level_path(level_id))
		if data == null:
			continue
		for difficulty: int in [Defs.Difficulty.BEGINNER, Defs.Difficulty.EXPERT]:
			if not Levels.is_available(level_id, difficulty):
				continue
			for record: Dictionary in data.entity_records():
				var params: Dictionary = record["params"]
				if String(record["id"]) != "objects/x2_tablet" or not params.has("gate") \
						or not LevelText.applies_to(params, difficulty):
					continue
				count += 1
				if count < int(_opts.get("gate_from", "1")) or count > int(_opts.get("gate_to", "999")):
					continue
				var gate: String = str(params["gate"])
				var start: int = Time.get_ticks_msec()
				var result: Dictionary = CoopSearch.search_gate(level_id, difficulty, gate)
				var bad: bool = bool(result.get("reached", true))
				var line: String = "GATE %s %s %s: reached=%s explored=%d bound=%d objects=%d (%d ms)" % [level_id,
					Defs.difficulty_name(difficulty), gate, str(result.get("reached")), int(result.get("explored", 0)),
					int(result.get("bound", 0)), int(Performance.get_monitor(Performance.OBJECT_COUNT)),
					Time.get_ticks_msec() - start]
				for window: Dictionary in result.get("windows", []):
					var ok: bool = int(window["window"]) <= int(window["solo_min"]) - 4
					bad = bad or not ok
					line += " | %s %d/%d %s" % [window.get("what", "?"), window["window"], window["solo_min"],
						"ok" if ok else "TOO LONG"]
				if bad:
					failures += 1
					line += " FAIL " + str(result.get("detail", ""))
				print(line)
				if not no_yield:
					await get_tree().process_frame
	print("ALLGATES %d gates, %d failures" % [count, failures])


func _search(only: String) -> void:
	var ids: Array[StringName] = _ids.duplicate()
	if _opts.has("ids"):
		ids.clear()
		for id: String in str(_opts["ids"]).split(",", false):
			ids.append(StringName(id))
	for id: StringName in ids:
		if not Levels.is_coop_level(id):
			continue
		var data: LevelData = LevelData.load_file(Levels.get_level_path(id))
		for difficulty: int in [Defs.Difficulty.BEGINNER, Defs.Difficulty.EXPERT]:
			if _opts.has("mode") and Defs.difficulty_name(difficulty).to_lower() != str(_opts["mode"]).to_lower():
				continue
			for record: Dictionary in data.entity_records():
				var params: Dictionary = record["params"]
				if String(record["id"]) != "objects/x2_tablet" or not params.has("gate") \
						or not LevelText.applies_to(params, difficulty):
					continue
				var gate: String = str(params["gate"])
				if only != "" and gate != only:
					continue
				var start: int = Time.get_ticks_msec()
				var result: Dictionary = CoopSearch.search_gate(id, difficulty, gate)
				print("SEARCH %s %s gate %s: reached=%s explored=%d starts=%s (%d ms)" % [id,
					Defs.difficulty_name(difficulty), gate, str(result.get("reached")), int(result.get("explored", 0)),
					str(result.get("starts")), Time.get_ticks_msec() - start])
				if str(result.get("detail", "")) != "":
					print("  detail: " + str(result["detail"]))
				for window: Dictionary in result.get("windows", []):
					var ok: bool = int(window["window"]) <= int(window["solo_min"]) - 4
					print("  window %s: %d solo_min %d %s" % [window["what"], window["window"], window["solo_min"],
						"ok" if ok else "TOO LONG"])


# =================================================================================================================
# Replay with a trace
# =================================================================================================================

func _route(file: String) -> void:
	var runner: Node = (load(RUNNER) as GDScript).new() as Node
	runner.name = "SimBench"
	get_tree().root.add_child(runner)
	var dir: String = str(_opts.get("dir", "res://build/g2/w/routes/"))
	var table: Dictionary = runner.call(&"header_routes", dir)
	if not table.has(file):
		print("ROUTE: no header route %s in %s (%s)" % [file, dir, str(table.keys())])
		return
	if not (table[file]["errors"] as PackedStringArray).is_empty():
		print("ROUTE: header errors: %s" % "; ".join(table[file]["errors"]))
		return
	var mode: String = str(_opts.get("mode", "beginner"))
	_connect_events()
	var options: Dictionary = {"routes": table, "route_dir": dir, "on_tick": _on_tick,
		"doze": not _opts.has("no-doze")}
	if _opts.has("belt"):
		options["belt"] = int(_opts["belt"])
	var result: Dictionary = await runner.call(&"replay", file, mode, options)
	var lines: PackedStringArray = result.get("lines", PackedStringArray())
	for line: String in lines:
		if line.begins_with("end "):
			print("END " + line)
	print("RESULT screen=%s level=%s input_ticks=%d mismatches=%d" % [result.get("screen"), result.get("level_id"),
		int(result.get("input_ticks", 0)), int(result.get("input_mismatches", 0))])


# =================================================================================================================
# Recording from a macro script
# =================================================================================================================

class Actor:
	extends RefCounted
	var slot: int = 0
	var cmds: PackedStringArray = PackedStringArray()
	var index: int = 0
	var held: int = 0       ## ticks the current command has run
	var flags: int = 0
	var barrier: String = ""
	var jump: int = 0
	var jump_dir: int = 0


func _record(script_path: String) -> void:
	var header: PackedStringArray = PackedStringArray()
	var out_name: String = ""
	var segments: Array = []   # [comment, [p1 cmds], [p2 cmds]]
	for raw: String in FileAccess.get_file_as_string(script_path).split("\n"):
		var line: String = raw.strip_edges()
		if line.is_empty() or line.begins_with("//"):
			continue
		if line.begins_with("header:"):
			header.append(line.substr(7).strip_edges())
		elif line.begins_with("out:"):
			out_name = line.substr(4).strip_edges()
		elif line.begins_with("seg:"):
			segments.append([line.substr(4).strip_edges(), PackedStringArray(), PackedStringArray(), ""])
		elif line.begins_with("raw:"):
			segments[-1][3] = str(segments[-1][3]) + line.substr(4).strip_edges() + "
"
		elif line.begins_with("p1:") or line.begins_with("p2:"):
			if segments.is_empty():
				segments.append(["", PackedStringArray(), PackedStringArray(), ""])
			var which: int = 1 if line.begins_with("p1:") else 2
			var list: PackedStringArray = segments[-1][which]
			list.append_array(line.substr(3).strip_edges().split(" ", false))
			segments[-1][which] = list
	var spec: Dictionary = Autoplay.parse_route_header(header[0])
	if not (spec.get("errors", PackedStringArray()) as PackedStringArray).is_empty():
		print("REC: header errors %s" % str(spec["errors"]))
		return
	var mode: String = str(_opts.get("mode", (spec["modes"] as Array)[0]))
	var players: int = int(spec.get("players", 1))
	var runner: Node = (load(RUNNER) as GDScript).new() as Node
	runner.name = "SimBench"
	get_tree().root.add_child(runner)
	runner.call(&"_begin_replay", {"routes": {}, "route_dir": "res://build/g2/w/routes/"})
	runner.call(&"_start_header_run", spec, mode)
	if spec.has("source"):
		Game.warp_return_level = StringName(str(spec["source"]))
	if not await runner.call(&"_enter", StringName(str(spec["level"]))):
		print("REC: the level did not start")
		return
	runner.call(&"_put_on_belts", spec)
	_connect_events()
	var level: LevelBase = Game.level
	_level = level
	var cur: Array[int] = [0, 0, 0, 0]
	if players == 1:
		GameInput.set_scripted(func(_t: int) -> int: return cur[0])
	else:
		for slot: int in players:
			var s: int = slot
			GameInput.set_scripted_slot(slot, func(_t: int) -> int: return cur[s])
	var streams: Array[PackedInt32Array] = []
	for slot: int in players:
		streams.append(PackedInt32Array())
	var marks: Array = []   # [tick index, comment]
	var played: int = 0
	var failed: String = ""
	for seg_index: int in segments.size():
		var seg: Array = segments[seg_index]
		marks.append([played, str(seg[0])])
		var ps: Array[Actor] = []
		for slot: int in players:
			var p: Actor = Actor.new()
			p.slot = slot
			p.cmds = seg[slot + 1] if slot < 2 else PackedStringArray()
			ps.append(p)
		if str(seg[3]) != "":
			var rawst: Array[PackedInt32Array] = Autoplay.parse_inputs_multi(str(seg[3]))
			var n: int = rawst[0].size()
			var k: int = 0
			while k < n and Sim.running and Game.level == level:
				for slot: int in players:
					cur[slot] = rawst[slot][k] if slot < rawst.size() else 0
					streams[slot].append(cur[slot])
				Sim.step(1)
				played += 1
				k += 1
				if Sim.running and Game.level == level:
					_on_tick(level, played)
		while Sim.running and Game.level == level:
			var all_done: bool = true
			for p: Actor in ps:
				_cur_flags = cur
				var f: int = _next_flags(p, ps, level, played)
				if f == -2:
					failed = "segment %d '%s' P%d command '%s' timed out at t=%d" % [seg_index, seg[0], p.slot + 1,
						p.cmds[p.index], played]
					f = 0
				if f >= 0:
					all_done = false
				cur[p.slot] = maxi(f, 0)
			if failed != "":
				break
			if all_done:
				break
			for slot: int in players:
				streams[slot].append(cur[slot])
			if _opts.has("dbg") and played >= _from and played <= _to:
				print("FLAGS t=%d %s" % [played, str(cur)])
			Sim.step(1)
			played += 1
			if Sim.running and Game.level == level:
				_on_tick(level, played)
		if failed != "" or not (Sim.running and Game.level == level):
			break
	GameInput.clear_scripted()
	print("REC: %d ticks recorded; stage %s; screen %s%s" % [played, "ended" if Game.level != level else "running",
		Flow.current_screen, ("; FAILED: " + failed) if failed != "" else ""])
	if level != null and is_instance_valid(level) and Game.level == level:
		for hero: PlayerBase in level.heroes:
			print("REC end P%d %s" % [hero.slot + 1, _hero_text(hero)])
	# Write the route.
	var text: String = "\n".join(header) + "\n"
	for m: int in marks.size():
		var a: int = int(marks[m][0])
		var b: int = int(marks[m + 1][0]) if m + 1 < marks.size() else played
		if b <= a:
			continue
		var chunk: Array[PackedInt32Array] = []
		for slot: int in players:
			chunk.append(streams[slot].slice(a, b))
		var comment: PackedStringArray = PackedStringArray()
		if str(marks[m][1]) != "":
			for c: String in str(marks[m][1]).split("\\n"):
				comment.append("# " + c)
		text += Autoplay.format_inputs(chunk, comment)
	var dir: String = str(_opts.get("dir", "res://build/g2/w/routes/"))
	var out: FileAccess = FileAccess.open(dir + out_name, FileAccess.WRITE)
	out.store_string(text)
	out.close()
	print("REC: wrote %s%s" % [dir, out_name])
	await runner.call(&"_reset")
	runner.call(&"_end_replay", true)
	runner.queue_free()
	if _opts.has("verify"):
		_quiet_events = true
		_every = 1000000
		await _route(out_name)


## The flags of player `p` for the next tick: >= 0, -1 when its commands are exhausted, -2 on a timeout.
func _next_flags(p: Actor, ps: Array[Actor], level: LevelBase, t: int) -> int:
	while p.index < p.cmds.size():
		var cmd: String = p.cmds[p.index]
		if cmd.begins_with("|"):
			p.barrier = cmd
			var all_there: bool = true
			for other: Actor in ps:
				if other != p and other.barrier != cmd and other.index < other.cmds.size():
					all_there = false
			if all_there:
				p.index += 1
				p.held = 0
				continue
			return 0
		if cmd.begins_with("@tduo"):
			var boar2: Tusker = boss() as Tusker
			if boar2 == null or boar2.dead:
				p.index += 1
				p.held = 0
				continue
			p.held += 1
			if p.held > 5000:
				return -2
			return _tduo_flags(p, level.heroes[p.slot], boar2, level)
		if cmd.begins_with("@tusker"):
			var boar: Tusker = boss() as Tusker
			if boar == null or boar.dead:
				p.index += 1
				p.held = 0
				continue
			p.held += 1
			if p.held > 5000:
				return -2
			return _tusker_flags(p, level.heroes[p.slot], boar, level)
		if cmd.begins_with("@swat:"):
			# Stand (up to N ticks) and club every harrier that dives within reach; done when none is alive within
			# 240 px (or after N ticks).
			var hero_w: PlayerBase = level.heroes[p.slot]
			var bird: EnemyBase = null
			for e: SimEntity in level.get_kind(Defs.Kind.ENEMY):
				var foe_w: EnemyBase = e as EnemyBase
				if foe_w != null and not foe_w.dead and _kind_ok(foe_w, "harrier") \
						and absi(foe_w.sim_pos.x - hero_w.sim_pos.x) <= 240 and absi(foe_w.sim_pos.y - hero_w.sim_pos.y) <= 200:
					bird = foe_w
			if bird == null or p.held >= cmd.substr(6).to_int():
				if p.jump == 0:
					p.index += 1
					p.held = 0
					continue
			p.held += 1
			if p.jump > 0:
				p.jump -= 1
				return p.flags if p.jump > 6 else 0
			if bird == null:
				return 0
			# Predict the bird 5 ticks on (when the club box is out) and strike if it falls in the high or forward box.
			var px5: int = bird.sim_pos.x + (bird.xvel * 5) / 16
			var py5: int = bird.sim_pos.y + (bird.yvel * 5) / 16
			var bdx: int = px5 - hero_w.sim_pos.x
			var bdy: int = hero_w.sim_pos.y - py5
			var bside: int = 1 if bdx >= 0 else -1
			if not hero_w.is_grounded():
				return 0
			if hero_w.facing != bside and absi(bdx) <= 60:
				return Defs.IN_RIGHT if bside > 0 else Defs.IN_LEFT
			var adx: int = absi(bdx)
			if adx >= 0 and adx <= 34 and bdy >= 18 and bdy <= 52:
				p.jump = 14
				p.flags = Defs.IN_UP | Defs.IN_FIRE
				return p.flags
			if adx >= 4 and adx <= 44 and bdy >= -12 and bdy < 18:
				p.jump = 14
				p.flags = Defs.IN_FIRE
				return p.flags
			return 0
		if cmd.begins_with("@xl:") or cmd.begins_with("@xr:"):
			# levels (wf11): stand still EXACTLY at x, facing left (@xl) or right (@xr). Measured: a one-tick tap moves a
			# standing hero 2 px to the left or 1 px to the right (and turns him); far away he walks.
			var hero_x: PlayerBase = level.heroes[p.slot]
			var want_left: bool = cmd.begins_with("@xl:")
			var d: int = hero_x.sim_pos.x - cmd.substr(4).to_int()
			if p.held > 600:
				return -2
			p.held += 1
			if d > 22 and hero_x.is_grounded():
				return Defs.IN_LEFT
			if d < -22 and hero_x.is_grounded():
				return Defs.IN_RIGHT
			if not hero_x.is_grounded() or hero_x.xvel != 0:
				return 0
			if want_left:
				if d == 0 and hero_x.facing < 0:
					p.index += 1
					p.held = 0
					continue
				if d <= 0 or (d & 1) == 1:
					return Defs.IN_RIGHT
				return Defs.IN_LEFT
			if d == 0 and hero_x.facing > 0:
				p.index += 1
				p.held = 0
				continue
			if d < 0:
				return Defs.IN_RIGHT
			if d == 0:
				return Defs.IN_RIGHT
			return Defs.IN_LEFT
		if cmd.begins_with("@atl:"):
			# levels (wf11): the mirror of @atr - stand still exactly at x, facing left: back off to the right of x if past
			# it, then 1-tick taps left.
			var hero_l: PlayerBase = level.heroes[p.slot]
			var txl: int = cmd.substr(5).to_int()
			if p.held > 400:
				return -2
			p.held += 1
			if not hero_l.is_grounded() or hero_l.xvel != 0:
				p.jump = 0
				return 0
			if hero_l.sim_pos.x == txl and hero_l.facing < 0:
				p.index += 1
				p.held = 0
				continue
			if hero_l.sim_pos.x <= txl:
				return Defs.IN_RIGHT if hero_l.sim_pos.x < txl + 4 else 0
			if hero_l.sim_pos.x - txl > 16:
				return Defs.IN_LEFT
			p.jump += 1
			return Defs.IN_LEFT if p.jump % 2 == 1 else 0
		if cmd.begins_with("@atr:"):
			# G2: stand still exactly at x, facing right: back off to the left of x if past it, then 1-tick taps right.
			var hero_r: PlayerBase = level.heroes[p.slot]
			var tx: int = cmd.substr(5).to_int()
			if p.held > 400:
				return -2
			p.held += 1
			if not hero_r.is_grounded() or hero_r.xvel != 0:
				p.jump = 0
				return 0
			if hero_r.sim_pos.x == tx and hero_r.facing > 0:
				p.index += 1
				p.held = 0
				continue
			if hero_r.sim_pos.x >= tx:
				return Defs.IN_LEFT if hero_r.sim_pos.x > tx - 4 else 0
			if tx - hero_r.sim_pos.x > 16:
				return Defs.IN_RIGHT
			# a single tap, then wait for him to stop
			p.jump += 1
			return Defs.IN_RIGHT if p.jump % 2 == 1 else 0
		if cmd.begins_with("@at:"):
			# Stand still within 6 px of x: walk while far, then single taps until close and stopped.
			var hero_a: PlayerBase = level.heroes[p.slot]
			var at_parts: PackedStringArray = cmd.substr(4).split(":")
			var dxa: int = at_parts[0].to_int() - hero_a.sim_pos.x
			var tol: int = at_parts[1].to_int() if at_parts.size() > 1 else 6
			if p.held > 300:
				return -2
			p.held += 1
			if absi(dxa) <= tol and hero_a.xvel == 0 and hero_a.is_grounded():
				p.index += 1
				p.held = 0
				continue
			if hero_a.xvel != 0 or not hero_a.is_grounded():
				return 0 if absi(dxa) <= 24 else (Defs.IN_RIGHT if dxa > 0 else Defs.IN_LEFT)
			return Defs.IN_RIGHT if dxa > 0 else Defs.IN_LEFT
		if cmd.begins_with("@dodge:"):
			# Stand N ticks facing right, jumping straight up whenever an enemy rolls in from the right within reach.
			var hero_d: PlayerBase = level.heroes[p.slot]
			if p.held >= cmd.substr(7).to_int() and p.jump == 0 and hero_d.is_grounded():
				p.index += 1
				p.held = 0
				continue
			p.held += 1
			if p.jump > 0:
				p.jump += 1
				if hero_d.is_grounded() and p.jump > 8:
					p.jump = 0
				else:
					return Defs.IN_UP if p.jump <= 9 else 0
			if hero_d.is_grounded() and hero_d.no_jump == 0 and _foe_ahead(hero_d, 1):
				p.jump = 1
				return Defs.IN_UP
			return 0
		if cmd.begins_with("@copy"):
			# Copy P1's flags of this tick (P1 is evaluated first) until P1's commands of the segment are done.
			var leader: Actor = ps[0]
			if leader.index >= leader.cmds.size():
				p.index += 1
				p.held = 0
				continue
			p.held += 1
			return _cur_flags[0]
		if cmd.begins_with("@strike:"):
			# Wait for the enemies in cols c0..c1 and club each one within reach in front; done when none is left.
			var cs: PackedStringArray = cmd.substr(8).split(",")
			_hero = level.heroes[p.slot]
			var only: String = cs[4] if cs.size() > 4 else ""
			if ec(cs[0].to_int(), cs[1].to_int(), only) == 0:
				p.index += 1
				p.held = 0
				continue
			if p.held > 900:
				return -2
			var hero_s: PlayerBase = level.heroes[p.slot]
			p.held += 1
			if p.jump > 0:
				p.jump -= 1
				return Defs.IN_FIRE if p.jump > 6 else 0
			var fx: int = ex(cs[0].to_int(), cs[1].to_int(), only)
			var side: int = 1 if fx >= hero_s.sim_pos.x else -1
			if hero_s.facing != side:
				return Defs.IN_RIGHT if side > 0 else Defs.IN_LEFT
			var reach: int = int(cs[2]) if cs.size() > 2 else 34
			var dist: int = absi(fx - hero_s.sim_pos.x)
			if dist <= reach and hero_s.is_grounded():
				p.jump = 14
				return Defs.IN_FIRE
			var walk: bool = cs.size() > 3 and cs[3] == "w"
			if walk and (dist > reach + 30 or (hero_s.xvel == 0 and dist > reach)):
				return Defs.IN_RIGHT if side > 0 else Defs.IN_LEFT
			return 0
		if cmd.begins_with("@goto:"):
			# Walk to x (px), jumping over any skull lying ahead; done when there and on the ground.
			var goto_parts: PackedStringArray = cmd.substr(6).split(":")
			var target: int = goto_parts[0].to_int()
			var jump_foes: bool = goto_parts.size() > 1 and goto_parts[1] == "e"
			var hero: PlayerBase = level.heroes[p.slot]
			if p.held > 600:
				return -2
			if p.jump > 0:
				p.jump += 1
				if hero.is_grounded() and p.jump > 8:
					p.jump = 0
				else:
					var df: int = 0 if p.jump_dir == 0 else (Defs.IN_RIGHT if p.jump_dir > 0 else Defs.IN_LEFT)
					p.held += 1
					return df | (Defs.IN_UP if p.jump <= 9 else 0)
			var dx: int = target - hero.sim_pos.x
			if absi(dx) <= 4 and hero.is_grounded():
				p.index += 1
				p.held = 0
				continue
			var dir: int = 1 if dx > 0 else -1
			p.held += 1
			if jump_foes and hero.is_grounded() and (_curler_ahead(hero, dir) or _roller_coming(hero, dir)) 					and not (hero.no_jump == 0 and _foe_ahead(hero, dir)):
				return 0
			if hero.is_grounded() and hero.no_jump == 0 and jump_foes and _foe_ahead(hero, dir):
				p.jump = 1
				p.jump_dir = 0
				return Defs.IN_UP
			if hero.is_grounded() and hero.no_jump == 0 and _skull_ahead(hero, dir):
				p.jump = 1
				p.jump_dir = dir
				return (Defs.IN_RIGHT if dir > 0 else Defs.IN_LEFT) | Defs.IN_UP
			return Defs.IN_RIGHT if dir > 0 else Defs.IN_LEFT
		var keys: String = ""
		var i: int = 0
		while i < cmd.length() and "LRUDFKS".contains(cmd[i]):
			keys += cmd[i]
			i += 1
		var flags: int = _key_flags(keys)
		var rest: String = cmd.substr(i)
		var done: bool = false
		var limit: int = 900
		if rest.begins_with("*"):
			done = p.held >= rest.substr(1).to_int()
		elif rest.begins_with("!"):
			done = t >= rest.substr(1).to_int()
		elif rest.begins_with("?"):
			var expr: String = rest.substr(1)
			var semi: int = expr.rfind(";")
			if semi > 0:
				limit = expr.substr(semi + 1).to_int()
				expr = expr.substr(0, semi)
			done = _eval(expr, p, level, t)
			if not done and p.held >= limit:
				return -2
		else:
			print("REC: bad command '%s'" % cmd)
			return -2
		if done:
			p.index += 1
			p.held = 0
			continue
		p.held += 1
		return flags
	return -1


## The club bot of tests/test_enemies_tusker.gd (TuskerBot) in the arena of this level (offset by the arena zone):
## waits on a bank while the boar is dangerous, drops into the pit and clubs the head while it lies open.
func _tusker_flags(p: Actor, hero: PlayerBase, boar: Tusker, level: LevelBase) -> int:
	if hero == null or hero.dead or boar == null or boar.dead:
		return 0
	var origin: Vector2i = _arena_origin(level)
	var left_safe: int = origin.x + 32
	var right_safe: int = origin.x + 288
	var pit_left: int = origin.x + 64
	var pit_right: int = origin.x + 256
	var bank_y: int = origin.y + 112
	var x: int = hero.sim_pos.x
	var grounded: bool = hero.is_grounded()
	if p.jump > 0:
		if grounded and p.jump > 2:
			p.jump = 0
		else:
			p.jump += 1
			var dir_flag: int = Defs.IN_RIGHT if p.jump_dir > 0 else Defs.IN_LEFT
			return dir_flag | (Defs.IN_UP if p.jump <= 9 else 0)
	var on_bank: bool = hero.sim_pos.y <= bank_y and grounded
	var rocks: Array[int] = []
	for drop: Vector3i in boar.pending_rocks():
		rocks.append(drop.x)
	for entity: SimEntity in level.get_kind(Defs.Kind.ENEMY_PROJECTILE):
		rocks.append(entity.sim_pos.x)
	var attack: bool = false
	match boar.get_state():
		Tusker.State.RECOIL:
			attack = true
		Tusker.State.DIZZY:
			attack = boar.get_state_ticks() < boar._dizzy_len - 6
		Tusker.State.STUCK:
			attack = boar.get_state_ticks() < Tusker.TUSKER_STUCK_TICKS - 16
	if attack:
		var head: Rect2i = boar.get_head_rect()
		var spot: int = head.end.x + 20 if boar.facing > 0 else head.position.x - 20
		spot = clampi(spot, pit_left + 18, pit_right - 18)
		spot = _away_from(spot, rocks)
		if absi(x - spot) > 4:
			return Defs.IN_RIGHT if spot > x else Defs.IN_LEFT
		var to_boar: int = 1 if boar.sim_pos.x >= x else -1
		if hero.facing != to_boar and not hero.is_striking():
			return Defs.IN_RIGHT if to_boar > 0 else Defs.IN_LEFT
		return Defs.IN_FIRE
	var left_bank: bool = x < (pit_left + pit_right) / 2
	var safe: int = left_safe if left_bank else right_safe
	if on_bank:
		var target: int = _away_from(safe, rocks, 26, origin.x + (24 if left_bank else 266),
				origin.x + (46 if left_bank else 290))
		if absi(x - target) > 3:
			return Defs.IN_RIGHT if target > x else Defs.IN_LEFT
		return 0
	var face: int = pit_left if left_bank else pit_right
	var dir: int = -1 if left_bank else 1
	if grounded and absi(x - face) <= 30:
		p.jump = 1
		p.jump_dir = dir
		return (Defs.IN_RIGHT if dir > 0 else Defs.IN_LEFT) | Defs.IN_UP
	return Defs.IN_RIGHT if dir > 0 else Defs.IN_LEFT


## True when a skull (a bad thrown-out random bonus) lies 8..44 px ahead of the hero within 24 px of his feet height.
func _skull_ahead(hero: PlayerBase, dir: int) -> bool:
	for e: SimEntity in _level.get_kind(Defs.Kind.COLLECTIBLE):
		var c: CollectibleBase = e as CollectibleBase
		if c == null or not is_instance_valid(c) or c.collected or String(c.item_id) != "items/skull":
			continue
		var ahead: int = (c.sim_pos.x - hero.sim_pos.x) * dir
		if ahead >= 8 and ahead <= 44 and absi(c.sim_pos.y - hero.sim_pos.y) <= 24:
			return true
	return false


## True when a live enemy is 8..48 px ahead of the hero within 32 px of his feet height.
func _foe_ahead(hero: PlayerBase, dir: int) -> bool:
	for e: SimEntity in _level.get_kind(Defs.Kind.ENEMY):
		var foe: EnemyBase = e as EnemyBase
		if foe == null or foe.dead:
			continue
		var ahead: int = absi(foe.sim_pos.x - hero.sim_pos.x)
		var coming: bool = foe.xvel * signi(hero.sim_pos.x - foe.sim_pos.x) >= 40
		if _opts.has("dbg") and absi(ahead) <= 60:
			print("DBG t=%d P%d ahead=%d coming=%s dy=%d nj=%d g=%s" % [_tick, hero.slot + 1, ahead, coming, foe.sim_pos.y - hero.sim_pos.y, hero.no_jump, hero.is_grounded()])
		if coming and ahead >= 0 and ahead <= _jump_ahead and absi(foe.sim_pos.y - hero.sim_pos.y) <= 40:
			return true
	return false


## True when a Roller curls (about to roll) 0..140 px ahead of the hero within 64 px of his height: wait for it.
func _curler_ahead(hero: PlayerBase, dir: int) -> bool:
	for e: SimEntity in _level.get_kind(Defs.Kind.ENEMY):
		var foe: EnemyBase = e as EnemyBase
		if foe == null or foe.dead or not foe.has_method(&"get_state") or not _kind_ok(foe, "roller"):
			continue
		var ahead: int = (foe.sim_pos.x - hero.sim_pos.x) * dir
		if int(foe.call(&"get_state")) == 1 and ahead >= 0 and ahead <= 140 and absi(foe.sim_pos.y - hero.sim_pos.y) <= 64:
			return true
	return false


## True when an enemy rolls (or charges) toward the hero from 0..160 px ahead within 64 px of his height.
func _roller_coming(hero: PlayerBase, dir: int) -> bool:
	for e: SimEntity in _level.get_kind(Defs.Kind.ENEMY):
		var foe: EnemyBase = e as EnemyBase
		if foe == null or foe.dead:
			continue
		var ahead: int = absi(foe.sim_pos.x - hero.sim_pos.x)
		if foe.xvel * signi(hero.sim_pos.x - foe.sim_pos.x) >= 40 and ahead <= 160 				and absi(foe.sim_pos.y - hero.sim_pos.y) <= 64:
			return true
	return false


## The duo bot against the co-op Tusker (DESIGN.md B.1): P1 waits on the left bank, P2 on the right one. While the boar
## lies open (recoil, dizzy) the hero on the side it faces runs up to its head (the nearer hero: it keeps facing him)
## and the other strikes its leafy rump from behind. In phase 3 both crouch side by side on the left dry floor (a Brace
## Wall) and club the dazed boar.
func _tduo_flags(p: Actor, hero: PlayerBase, boar: Tusker, level: LevelBase) -> int:
	if hero == null or hero.dead or hero.is_down():
		return 0
	var origin: Vector2i = _arena_origin(level)
	var pit_left: int = origin.x + 64
	var pit_right: int = origin.x + 256
	var bank_y: int = origin.y + 112
	var my_side: int = -1 if p.slot == 0 else 1
	var safe: int = origin.x + 32 if my_side < 0 else origin.x + 288
	var x: int = hero.sim_pos.x
	var grounded: bool = hero.is_grounded()
	if p.jump > 0:
		if grounded and p.jump > 2:
			p.jump = 0
		else:
			p.jump += 1
			var dir_flag: int = Defs.IN_RIGHT if p.jump_dir > 0 else Defs.IN_LEFT
			return dir_flag | (Defs.IN_UP if p.jump <= 9 else 0)
	var st: int = boar.get_state()
	var phase: int = boar.get_phase()
	if st == Tusker.State.DAZED:
		var to_boar: int = 1 if boar.sim_pos.x >= x else -1
		if absi(boar.sim_pos.x - x) > 44:
			return Defs.IN_RIGHT if to_boar > 0 else Defs.IN_LEFT
		if hero.facing != to_boar and not hero.is_striking():
			return Defs.IN_RIGHT if to_boar > 0 else Defs.IN_LEFT
		return Defs.IN_FIRE
	if phase >= 3 and st != Tusker.State.DIZZY and st != Tusker.State.RECOIL:
		# The Brace Wall on the dry floor away from the boar (decided once, the same for both heroes).
		if p.barrier == "":
			p.barrier = "L" if boar.sim_pos.x >= origin.x + 160 else "R"
		var spot: int = origin.x + (92 if p.slot == 0 else 104)
		if p.barrier == "R":
			spot = origin.x + (212 if p.slot == 0 else 224)
		var to_spot: int = 1 if spot > x else -1
		var between: bool = signi(boar.sim_pos.x - x) == to_spot and absi(boar.sim_pos.x - x) < absi(spot - x)
		if between and absi(x - spot) > 3:
			if grounded and hero.no_jump == 0 and absi(boar.sim_pos.x - x) <= 76 					and st != Tusker.State.CHARGE and st != Tusker.State.SKID:
				p.jump = 1
				p.jump_dir = to_spot
				return (Defs.IN_RIGHT if to_spot > 0 else Defs.IN_LEFT) | Defs.IN_UP
			if absi(boar.sim_pos.x - x) > 80:
				return Defs.IN_RIGHT if to_spot > 0 else Defs.IN_LEFT
			return 0
		if absi(x - spot) > 3 and st != Tusker.State.CHARGE and st != Tusker.State.PAW:
			return Defs.IN_RIGHT if to_spot > 0 else Defs.IN_LEFT
		return Defs.IN_DOWN
	var open: bool = false
	match st:
		Tusker.State.RECOIL:
			open = true
		Tusker.State.DIZZY:
			open = boar.get_state_ticks() < boar._dizzy_len - 8
	var front: bool = my_side == boar.facing
	if st == Tusker.State.HOP:
		# The Spin Ball comes down: be at its head and rump as it lands. The hero on the side it lands on is the head.
		open = true
		var right_half: bool = boar.sim_pos.x >= origin.x + 160
		var head_side: int = 1 if right_half else -1
		front = my_side == head_side
		if front:
			var spot_h: int = clampi(boar.sim_pos.x + head_side * 44, pit_left + 10, pit_right - 10)
			if absi(x - spot_h) > 4:
				return Defs.IN_RIGHT if spot_h > x else Defs.IN_LEFT
			return 0
		var w_l: int = origin.x + 128
		var w_r: int = origin.x + 191
		var spot_r: int = clampi(boar.sim_pos.x - head_side * 52, pit_left + 10, pit_right - 10)
		for k: int in range(54, 74, 2):
			var cand_r: int = boar.sim_pos.x - head_side * k
			if (cand_r < w_l - 6 or cand_r > w_r + 6) and cand_r > pit_left + 8 and cand_r < pit_right - 8:
				spot_r = cand_r
				break
		if absi(x - spot_r) > 4:
			return Defs.IN_RIGHT if spot_r > x else Defs.IN_LEFT
		var face_b: int = head_side
		if hero.facing != face_b:
			return Defs.IN_RIGHT if face_b > 0 else Defs.IN_LEFT
		return 0
	if open and front and st == Tusker.State.DIZZY and boar.get_state_ticks() >= boar._dizzy_len - 18:
		open = false
	if open and front:
		var spot_f: int = clampi(boar.sim_pos.x + boar.facing * 22, pit_left + 10, pit_right - 10)
		if absi(x - spot_f) > 4:
			return Defs.IN_RIGHT if spot_f > x else Defs.IN_LEFT
		return 0
	if open:
		var wallow_l: int = origin.x + 128
		var wallow_r: int = origin.x + 191
		var spot_b: int = clampi(boar.sim_pos.x - boar.facing * 52, pit_left + 10, pit_right - 10)
		for k: int in range(44, 72, 2):
			var cand: int = boar.sim_pos.x - boar.facing * k
			if (cand < wallow_l - 6 or cand > wallow_r + 6) and cand > pit_left + 8 and cand < pit_right - 8:
				spot_b = cand
				break
		if absi(x - spot_b) > 4:
			return Defs.IN_RIGHT if spot_b > x else Defs.IN_LEFT
		if hero.facing != boar.facing and not hero.is_striking():
			return Defs.IN_RIGHT if boar.facing > 0 else Defs.IN_LEFT
		return Defs.IN_FIRE
	# Back to my bank.
	if hero.sim_pos.y <= bank_y and grounded:
		if absi(x - safe) > 3:
			return Defs.IN_RIGHT if safe > x else Defs.IN_LEFT
		return 0
	var face: int = pit_left if my_side < 0 else pit_right
	if grounded and absi(x - face) <= 30:
		p.jump = 1
		p.jump_dir = my_side
		return (Defs.IN_RIGHT if my_side > 0 else Defs.IN_LEFT) | Defs.IN_UP
	return Defs.IN_RIGHT if my_side > 0 else Defs.IN_LEFT


func _arena_origin(level: LevelBase) -> Vector2i:
	var data_rect: Variant = _opts.get("arena", "")
	if str(data_rect) != "":
		var parts: PackedStringArray = str(data_rect).split(",")
		return Vector2i(parts[0].to_int() * 16, parts[1].to_int() * 16)
	return Vector2i.ZERO


static func _away_from(spot: int, rocks: Array[int], clearance: int = 26, low: int = -100000,
		high: int = 100000) -> int:
	for shift: int in [0, 8, -8, 16, -16, 24, -24, 32, -32, 40, -40, 48, -48]:
		var xx: int = clampi(spot + shift, low, high)
		var clear: bool = true
		for rock: int in rocks:
			clear = clear and absi(rock - xx) >= clearance
		if clear:
			return xx
	return spot


func _key_flags(keys: String) -> int:
	var flags: int = 0
	for pair: Array in Autoplay.KEY_LETTERS:
		if keys.contains(str(pair[1])):
			flags |= int(pair[0])
	return flags


var _expr_cache: Dictionary = {}
const VARS: PackedStringArray = ["x", "y", "vx", "vy", "g", "t", "c", "st", "px", "py", "pg", "dn", "h", "p", "pvx"]


func _eval(text: String, p: Actor, level: LevelBase, t: int) -> bool:
	var expr: Expression = _expr_cache.get(text)
	if expr == null:
		expr = Expression.new()
		if expr.parse(text, VARS) != OK:
			print("REC: bad expression '%s': %s" % [text, expr.get_error_text()])
			return true
		_expr_cache[text] = expr
	var hero: PlayerBase = level.heroes[p.slot] if p.slot < level.heroes.size() else null
	var partner: PlayerBase = null
	if level.heroes.size() > 1:
		partner = level.heroes[1 - p.slot] if p.slot < 2 else null
	_hero = hero
	var values: Array = [hero.sim_pos.x, hero.sim_pos.y, hero.xvel, hero.yvel, hero.is_grounded(), t,
		hero.state == Defs.HeroState.CLIMB, hero.state,
		partner.sim_pos.x if partner != null else 0, partner.sim_pos.y if partner != null else 0,
		partner.is_grounded() if partner != null else false, hero.dead or hero.is_down(), hero, partner,
		partner.xvel if partner != null else 0]
	var result: Variant = expr.execute(values, self)
	if expr.has_execute_failed():
		print("REC: expression '%s' failed: %s" % [text, expr.get_error_text()])
		return true
	return bool(result)


# --- helpers for expressions ---------------------------------------------------------------------------------------

## Horizontal distance from the hero to the nearest live enemy (99999 when none) within `dy` px vertically.
func en(dy: int = 64) -> int:
	var best: int = 99999
	for e: SimEntity in _level.get_kind(Defs.Kind.ENEMY):
		var foe: EnemyBase = e as EnemyBase
		if foe == null or foe.dead or absi(foe.sim_pos.y - _hero.sim_pos.y) > dy:
			continue
		best = mini(best, absi(foe.sim_pos.x - _hero.sim_pos.x))
	return best


static func _kind_ok(foe: EnemyBase, only: String) -> bool:
	return only == "" or (foe.get_script() != null and foe.get_script().resource_path.get_file().begins_with(only))


## Live enemies whose x lies in cells c0..c1 (`only`: a script file name prefix, e.g. "walker").
func ec(c0: int, c1: int, only: String = "") -> int:
	var n: int = 0
	for e: SimEntity in _level.get_kind(Defs.Kind.ENEMY):
		var foe: EnemyBase = e as EnemyBase
		if foe != null and not foe.dead and foe.sim_pos.x >= c0 * 16 and foe.sim_pos.x < (c1 + 1) * 16 				and _kind_ok(foe, only) and (_hero == null or absi(foe.sim_pos.y - _hero.sim_pos.y) <= 80):
			n += 1
	return n


## xvel of the first live enemy whose x lies in cells c0..c1 (0 when none).
func exv(c0: int, c1: int, only: String = "") -> int:
	for e: SimEntity in _level.get_kind(Defs.Kind.ENEMY):
		var foe: EnemyBase = e as EnemyBase
		if foe != null and not foe.dead and foe.sim_pos.x >= c0 * 16 and foe.sim_pos.x < (c1 + 1) * 16 				and _kind_ok(foe, only) and (_hero == null or absi(foe.sim_pos.y - _hero.sim_pos.y) <= 80):
			return foe.xvel
	return 0


## y of the first live enemy whose x lies in cells c0..c1 (-1 when none; no height filter).
func ey(c0: int, c1: int, only: String = "") -> int:
	for e: SimEntity in _level.get_kind(Defs.Kind.ENEMY):
		var foe: EnemyBase = e as EnemyBase
		if foe != null and not foe.dead and foe.sim_pos.x >= c0 * 16 and foe.sim_pos.x < (c1 + 1) * 16 				and _kind_ok(foe, only):
			return foe.sim_pos.y
	return -1


## x of the first live enemy whose x lies in cells c0..c1 (-1 when none).
func ex(c0: int, c1: int, only: String = "") -> int:
	for e: SimEntity in _level.get_kind(Defs.Kind.ENEMY):
		var foe: EnemyBase = e as EnemyBase
		if foe != null and not foe.dead and foe.sim_pos.x >= c0 * 16 and foe.sim_pos.x < (c1 + 1) * 16 				and _kind_ok(foe, only) and (_hero == null or absi(foe.sim_pos.y - _hero.sim_pos.y) <= 80):
			return foe.sim_pos.x
	return -1


func boss() -> BossBase:
	for e: SimEntity in _level.get_kind(Defs.Kind.BOSS):
		if e is BossBase and not (e as BossBase).dead:
			return e as BossBase
	return null


func bs() -> int:
	var b: BossBase = boss()
	return b.call(&"get_state") if b != null and b.has_method(&"get_state") else -1


func bst() -> int:
	var b: BossBase = boss()
	return b.call(&"get_state_ticks") if b != null and b.has_method(&"get_state_ticks") else -1


func bx() -> int:
	var b: BossBase = boss()
	return b.sim_pos.x if b != null else -1


func bf() -> int:
	var b: BossBase = boss()
	return b.facing if b != null else 0


## x of the first collectible with this item id (e.g. "items/fire_starter"); -1 when none.
func ix(item: String) -> int:
	for e: SimEntity in _level.get_kind(Defs.Kind.COLLECTIBLE):
		var c: CollectibleBase = e as CollectibleBase
		if c != null and String(c.item_id) == item and is_instance_valid(c):
			return c.sim_pos.x
	return -1


## y of the first collectible with this item id; -1 when none.
func iy(item: String) -> int:
	for e: SimEntity in _level.get_kind(Defs.Kind.COLLECTIBLE):
		var c: CollectibleBase = e as CollectibleBase
		if c != null and String(c.item_id) == item and is_instance_valid(c):
			return c.sim_pos.y
	return -1


## The nearest live enemy (not a boss) to the hero: [dx, dy] (enemy - hero); [99999, 99999] when none.
func _nearest() -> Vector2i:
	var best: Vector2i = Vector2i(99999, 99999)
	for e: SimEntity in _level.get_kind(Defs.Kind.ENEMY):
		var foe: EnemyBase = e as EnemyBase
		if foe == null or foe.dead:
			continue
		var d: Vector2i = foe.sim_pos - _hero.sim_pos
		if maxi(absi(d.x), absi(d.y)) < maxi(absi(best.x), absi(best.y)):
			best = d
	return best


func ed() -> int:
	var d: Vector2i = _nearest()
	return maxi(absi(d.x), absi(d.y))


func edx() -> int:
	return _nearest().x


func edy() -> int:
	return _nearest().y


## Skulls lying around: "x,y x,y ...".
func skulls() -> String:
	var out: PackedStringArray = PackedStringArray()
	for e: SimEntity in _level.get_kind(Defs.Kind.COLLECTIBLE):
		var c: CollectibleBase = e as CollectibleBase
		if c != null and is_instance_valid(c) and not c.collected and String(c.item_id) == "items/skull":
			out.append("%d,%d" % [c.sim_pos.x, c.sim_pos.y])
	return " ".join(out)


## Enemy projectiles in flight (rocks, ink...).
func np() -> int:
	var n: int = 0
	for e: SimEntity in _level.get_kind(Defs.Kind.ENEMY_PROJECTILE):
		if is_instance_valid(e) and not bool(e.get(&"spent")):
			n += 1
	return n


## The enemy projectiles as text.
func pl() -> String:
	var out: PackedStringArray = PackedStringArray()
	for e: SimEntity in _level.get_kind(Defs.Kind.ENEMY_PROJECTILE):
		out.append("%s %s spent=%s age=%s rest=%s active=%s doze=%s" % [e.get_script().resource_path.get_file() if e.get_script() else "", e.sim_pos, e.get(&"spent"), e.get(&"_age"), e.get(&"_resting"), e.sim_active, e.is_dozing()])
	for e: SimEntity in _level.get_kind(Defs.Kind.HAZARD):
		out.append("H %s %s" % [e.get_script().resource_path.get_file() if e.get_script() else "", e.sim_pos])
	return ", ".join(out)


## Print a value (an expression helper for probing); true.
func pr(a: Variant, b: Variant = null) -> bool:
	print("PR t=%d %s %s" % [_tick, str(a), str(b) if b != null else ""])
	return true


func ent(name: String) -> SimEntity:
	return _level.find_named(StringName(name)) as SimEntity


# =================================================================================================================
# Trace
# =================================================================================================================

func _hero_text(hero: PlayerBase) -> String:
	if hero == null or not is_instance_valid(hero):
		return "-"
	var flags: String = ""
	if hero.dead:
		flags += "D"
	if hero.down:
		flags += "E"
	if hero.grounded:
		flags += "g"
	if hero.state == Defs.HeroState.CLIMB:
		flags += "V"
	if hero.is_riding_totem():
		flags += "T"
	if hero.is_curled():
		flags += "C"
	return "(%d,%d) c%d,%d v%d,%d s%d f%d h%d %s" % [hero.sim_pos.x, hero.sim_pos.y, hero.sim_pos.x >> 4,
		(hero.sim_pos.y - 1) >> 4, hero.xvel, hero.yvel, hero.state, hero.facing, hero.run.hearts, flags]


func _on_tick(level: LevelBase, stage_tick: int) -> void:
	_tick = stage_tick
	_level = level
	if stage_tick < _from or stage_tick > _to:
		return
	var heroes: Array = level.heroes
	var text: String = ""
	for hero: PlayerBase in heroes:
		text += " | P%d %s" % [hero.slot + 1, _hero_text(hero)]
	var key: String = ""
	for hero: PlayerBase in heroes:
		key += "%s%s" % [hero.dead, hero.down]
	var same: bool = text == str(_last.get("text", ""))
	_last["text"] = text
	if (stage_tick % _every == 0 and not same) or key != str(_last.get("key", "")):
		if _opts.has("enemies"):
			var range_x: PackedStringArray = str(_opts["enemies"]).split(",")
			for enemy: SimEntity in level.get_kind(Defs.Kind.ENEMY):
				var foe: EnemyBase = enemy as EnemyBase
				if foe != null and not foe.dead and foe.sim_pos.x >= range_x[0].to_int() * 16 \
						and foe.sim_pos.x <= range_x[1].to_int() * 16:
					var st: String = ""
					if foe.has_method(&"get_state"):
						st = " st%d" % int(foe.call(&"get_state"))
					text += " | %s (%d,%d) f%d hp%d%s" % [foe.name, foe.sim_pos.x, foe.sim_pos.y, foe.facing, foe.hp, st]
		for b: SimEntity in level.get_kind(Defs.Kind.BOSS):
			if b is Tusker and not (b as Tusker).dead:
				text += " | BOAR (%d,%d) f%d st%d/%d ph%d hp%d" % [b.sim_pos.x, b.sim_pos.y, b.facing, (b as Tusker).get_state(),
					(b as Tusker).get_state_ticks(), (b as Tusker).get_phase(), (b as Tusker).hp]
		print("t=%d%s | cam %s | score %d lives %d" % [stage_tick, text, level.get_camera_cell(), Game.score,
			Game.lives])
	_last["key"] = key
	for kind: int in Defs.KIND_COUNT:
		for entity: SimEntity in level.get_kind(kind):
			if not is_instance_valid(entity):
				continue
			var note: String = ""
			if entity is FlowerPot:
				note = "pot state %d at %s" % [(entity as FlowerPot).state, entity.sim_pos]
				if (entity as FlowerPot).state == FlowerPot.State.SLIDE or (entity as FlowerPot).state == FlowerPot.State.FALL:
					note = "pot moving"
			elif entity is Plate:
				note = "plate %s pressed %s" % [entity.param_str("name"), (entity as Plate).pressed]
			elif entity is RisingColumn:
				note = "column %s risen %d" % [str((entity as RisingColumn).block.position), (entity as RisingColumn).risen]
			if note == "":
				continue
			var nk: String = "n%d" % entity.get_instance_id()
			if note != str(_last.get(nk, "")):
				print("EV t=%d %s" % [stage_tick, note])
				_last[nk] = note


var _connected: bool = false


func _connect_events() -> void:
	if _connected:
		return
	_connected = true
	Events.hero_down.connect(func(hero: PlayerBase, cause: StringName) -> void:
		print("EV t=%d hero_down P%d %s" % [_tick, hero.slot + 1, cause]))
	Events.hero_revived.connect(func(hero: PlayerBase, _by: PlayerBase) -> void:
		print("EV t=%d hero_revived P%d" % [_tick, hero.slot + 1]))
	Events.party_wiped.connect(func() -> void: print("EV t=%d party_wiped" % _tick))
	Events.boss_defeated.connect(func(b: BossBase) -> void: print("EV t=%d boss_defeated at %s" % [_tick, b.sim_pos]))
	Events.boss_started.connect(func(b: BossBase) -> void: print("EV t=%d boss_started at %s" % [_tick, b.sim_pos]))
	Events.exit_unlocked.connect(func() -> void: print("EV t=%d exit_unlocked" % _tick))
	Events.hero_died.connect(func(hero: PlayerBase, cause: StringName) -> void:
		print("EV t=%d hero_died P%d %s" % [_tick, hero.slot + 1, cause]))
	Events.player_died.connect(func(cause: StringName) -> void: print("EV t=%d player_died %s" % [_tick, cause]))
	Events.checkpoint_activated.connect(func(cp: CheckpointBase) -> void:
		if not _quiet_events:
			print("EV t=%d checkpoint %s" % [_tick, str(cp.sim_pos)]))
	Events.exit_reached.connect(func(kind: StringName) -> void: print("EV t=%d exit_reached %s" % [_tick, kind]))
	Events.level_completed.connect(func(id: StringName, kind: StringName) -> void:
		print("EV t=%d level_completed %s %s" % [_tick, id, kind]))
	Events.hero_bounced.connect(func(hero: PlayerBase, target: SimEntity, _mult: int) -> void:
		if not _quiet_events:
			print("EV t=%d bounce P%d on %s" % [_tick, hero.slot + 1, target.name if target != null else "?"]))
	Events.enemy_killed.connect(func(enemy: EnemyBase, _points: int, _cause: StringName) -> void:
		if not _quiet_events:
			print("EV t=%d kill %s at %s" % [_tick, enemy.name, str(enemy.sim_pos)]))
	Events.secret_found.connect(func(zone: StringName) -> void: print("EV t=%d secret %s" % [_tick, zone]))
	Events.painting_found.connect(func(index: int) -> void: print("EV t=%d painting %d" % [_tick, index]))
	Events.hero_hurt.connect(func(hero: PlayerBase, _kind: int, source: SimEntity) -> void:
		print("EV t=%d HURT P%d by %s %s at %s" % [_tick, hero.slot + 1, source.name if source != null else "?",
			source.get_script().resource_path.get_file() if source != null and source.get_script() != null else "",
			source.sim_pos if source != null else Vector2i.ZERO]))
	Events.gate_used.connect(func(a: Vector2i, b: Vector2i) -> void: print("EV t=%d gate %s->%s" % [_tick, a, b]))
	Events.item_collected.connect(func(item_id: StringName, index: int, _points: int, pos: Vector2i) -> void:
		if not _quiet_events and (item_id == &"items/letter" or item_id == &"items/warp" or item_id == &"items/fire_starter"):
			print("EV t=%d item %s %d at %s" % [_tick, item_id, index, pos]))
