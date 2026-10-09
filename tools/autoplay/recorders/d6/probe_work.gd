extends Node
## D6 development probe (see probe.gd; based on DB1's). Injects draft level files into the registry, validates them,
## runs the solo search on their gates, replays a route printing the heroes, and records a bot's play as a route.

const RUNNER: String = "res://scripts/core/dev/sim_bench_runner.gd"

var _opts: Dictionary = {}
var _ids: Array[StringName] = []
var _every: int = 10
var _from: int = 0
var _to: int = 999999
var _tick: int = 0
var _last: Dictionary = {}
var _quiet_events: bool = false


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
	var user: String = "res://build/run_users/d6_%d" % OS.get_process_id()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(user))
	Save.set_storage_dir(user)
	Settings.set_storage_dir(user)
	_every = int(_opts.get("every", "10"))
	_from = int(_opts.get("from", "0"))
	_to = int(_opts.get("to", "999999"))
	if _opts.has("validate"):
		_validate()
	if _opts.has("signs"):
		_signs(str(_opts["signs"]))
	if _opts.has("search"):
		_search(str(_opts["search"]))
	if _opts.has("bot"):
		await _bot()
	elif _opts.has("route"):
		await _route()
	return 0


func _validate() -> void:
	var validator: LevelValidator = LevelValidator.new()
	validator.add_folder("res://levels")
	for id: StringName in _ids:
		var path: String = Levels.get_level_path(id)
		if not path.begins_with("res://levels/"):
			validator.add_file(path)
	validator.run()
	for id: StringName in _ids:
		var path: String = Levels.get_level_path(id)
		var problems: Array[Dictionary] = validator.problems_of(path)
		print("VALIDATE %s: %d problem(s)" % [id, problems.size()])
		for problem: Dictionary in problems:
			print("  " + LevelValidator.format_problem(problem))


func _signs(po_path: String) -> void:
	var text: String = FileAccess.get_file_as_string(po_path)
	var key: String = ""
	for line: String in text.split("
"):
		if line.begins_with("msgid "):
			key = line.substr(7, line.length() - 8)
		elif line.begins_with("msgstr ") and key.begins_with("SIGN_"):
			var value: String = line.substr(8, line.length() - 9)
			print("SIGN %s: %d line(s) (max %d) \"%s\"" % [key, SignBoard.text_lines(value), SignBoard.MAX_LINES, value])


func _search(only: String) -> void:
	for id: StringName in _ids:
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


# --- Replaying a route file ---------------------------------------------------------------------------------------

func _route() -> void:
	var runner: Node = (load(RUNNER) as GDScript).new() as Node
	runner.name = "SimBench"
	get_tree().root.add_child(runner)
	var dir: String = str(_opts.get("dir", "res://build/d6/w/routes/"))
	var table: Dictionary = runner.call(&"header_routes", dir)
	var file: String = str(_opts["route"])
	if not table.has(file):
		print("ROUTE: no header route %s in %s (%s)" % [file, dir, str(table.keys())])
		return
	if not (table[file]["errors"] as PackedStringArray).is_empty():
		print("ROUTE: header errors: %s" % "; ".join(table[file]["errors"]))
		return
	var mode: String = str(_opts.get("mode", "beginner"))
	_quiet_events = _opts.has("quiet")
	_connect_events()
	var options: Dictionary = {"routes": table, "route_dir": dir, "on_tick": _on_tick,
		"doze": not _opts.has("no-doze"), "chain": not _opts.has("no-chain")}
	if _opts.has("belt"):
		options["belt"] = int(_opts["belt"])
	var result: Dictionary = await runner.call(&"replay", file, mode, options)
	var lines: PackedStringArray = result.get("lines", PackedStringArray())
	for line: String in lines:
		if line.begins_with("end "):
			print("END " + line)
	print("RESULT screen=%s level=%s input_ticks=%d mismatches=%d" % [result.get("screen"), result.get("level_id"),
		int(result.get("input_ticks", 0)), int(result.get("input_mismatches", 0))])
	if _opts.has("digest-out"):
		var out: FileAccess = FileAccess.open(str(_opts["digest-out"]), FileAccess.WRITE)
		for line: String in lines:
			out.store_line(line)
		out.close()


# --- Recording a bot ---------------------------------------------------------------------------------------------

func _bot() -> void:
	var mode: String = str(_opts.get("mode", "beginner"))
	var difficulty: int = Defs.Difficulty.EXPERT if mode == "expert" else Defs.Difficulty.BEGINNER
	var players: int = int(_opts.get("players", "1"))
	var level_id: StringName = StringName(str(_opts.get("start", String(_ids[0]))))
	var bot: Object = (load(str(_opts["bot"])) as GDScript).new()
	bot.call(&"setup", mode, players, _opts)
	var game_mode: int = Defs.GameMode.COOP if players > 1 else Defs.GameMode.SINGLE
	Game.start_run(difficulty, game_mode, players, maxi(Levels.get_book(level_id), 1))
	Sim.manual = true
	await get_tree().process_frame
	while Flow.busy:
		await get_tree().process_frame
	Flow.start_level(level_id, Defs.Transition.NONE)
	for i: int in 3:
		await get_tree().process_frame
	while Flow.busy:
		await get_tree().process_frame
	if Flow.current_screen != Flow.SCREEN_LEVEL or Game.level == null:
		print("BOT: %s did not start" % level_id)
		return
	var level: LevelBase = Game.level
	(level as Level).set_view_size(Vector2i(Tuning.VIEW_W, Tuning.VIEW_H) * Tuning.ART_SCALE)
	for slot: int in Game.party:
		Game.runs[slot].set_belt(PlayerRun.BELT_EMPTY)
	_quiet_events = _opts.has("quiet")
	_connect_events()
	var current: PackedInt32Array = PackedInt32Array()
	current.resize(players)
	var streams: Array[PackedInt32Array] = []
	for slot: int in players:
		streams.append(PackedInt32Array())
		var s: int = slot
		GameInput.set_scripted_slot(slot, func(_t: int) -> int: return current[s])
	var limit: int = int(_opts.get("limit", "20000"))
	var played: int = 0
	while played < limit and Sim.running and Game.level == level:
		var flags: PackedInt32Array = bot.call(&"flags", level, played)
		if flags.is_empty():
			break
		for slot: int in players:
			current[slot] = flags[slot] if slot < flags.size() else 0
			streams[slot].append(current[slot])
		Sim.step(1)
		played += 1
		if Sim.running and Game.level == level:
			_on_tick(level, played)
	GameInput.clear_scripted()
	print("BOT END tick %d screen %s level %s score %d lives %d hearts %d" % [played, Flow.current_screen,
		Game.level_id, Game.score, Game.lives, Game.hearts])
	if bot.has_method("report"):
		bot.call(&"report")
	if _opts.has("out"):
		var header: String = str(bot.call(&"header")) if bot.has_method("header") else ""
		var out: FileAccess = FileAccess.open(str(_opts["out"]), FileAccess.WRITE)
		out.store_string(header + _rle(streams, players) + "\n")
		out.close()
		print("BOT wrote %s (%d ticks)" % [_opts["out"], played])


static func _key_text(flags: int) -> String:
	var text: String = ""
	if flags & Defs.IN_LEFT:
		text += "L"
	if flags & Defs.IN_RIGHT:
		text += "R"
	if flags & Defs.IN_UP:
		text += "U"
	if flags & Defs.IN_DOWN:
		text += "D"
	if flags & Defs.IN_FIRE:
		text += "F"
	if flags & Defs.IN_LOOK:
		text += "K"
	if flags & Defs.IN_SWAP:
		text += "S"
	return text


static func _rle(streams: Array[PackedInt32Array], players: int) -> String:
	var entries: PackedStringArray = PackedStringArray()
	var n: int = streams[0].size()
	var i: int = 0
	while i < n:
		var j: int = i + 1
		while j < n:
			var same: bool = true
			for s: int in players:
				if streams[s][j] != streams[s][i]:
					same = false
			if not same:
				break
			j += 1
		var keys: PackedStringArray = PackedStringArray()
		for s: int in players:
			keys.append(_key_text(streams[s][i]))
		entries.append("%d:%s" % [j - i, "|".join(keys)])
		i = j
	var lines: PackedStringArray = PackedStringArray()
	var line: String = ""
	for entry: String in entries:
		if line.length() + entry.length() + 1 > 112 and line != "":
			lines.append(line.trim_suffix(","))
			line = ""
		line += entry + ","
	if line != "":
		lines.append(line.trim_suffix(","))
	return "\n".join(lines)


# --- Tracing ------------------------------------------------------------------------------------------------------

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
	if hero.is_mounted():
		flags += "M"
	if hero.is_riding_totem():
		flags += "T"
	return "(%d,%d) c%d,%d v%d,%d s%d h%d %s" % [hero.sim_pos.x, hero.sim_pos.y, hero.sim_pos.x >> 4,
		(hero.sim_pos.y - 1) >> 4, hero.xvel, hero.yvel, hero.state, hero.hit_timer, flags]


func _on_tick(level: LevelBase, stage_tick: int) -> void:
	_tick = stage_tick
	if stage_tick < _from or stage_tick > _to:
		return
	var text: String = ""
	for hero: PlayerBase in level.heroes:
		text += " | P%d %s" % [hero.slot + 1, _hero_text(hero)]
	var key: String = ""
	for hero: PlayerBase in level.heroes:
		key += "%s%s" % [hero.dead, hero.down]
	if _every > 0 and (stage_tick % _every == 0 or key != str(_last.get("key", ""))):
		if _opts.has("plats"):
			var range_p: PackedStringArray = str(_opts["plats"]).split(",")
			for entity: SimEntity in level.get_kind(Defs.Kind.PLATFORM):
				if entity.sim_pos.x >= range_p[0].to_int() * 16 and entity.sim_pos.x <= range_p[1].to_int() * 16:
					var extra: String = ""
					if entity is Raft:
						extra = " rx%d cd%d" % [(entity as Raft).rx, (entity as Raft).cd]
					text += " | %s (%d,%d)%s dz%d" % [entity.name, entity.sim_pos.x, entity.sim_pos.y, extra,
						int(entity.is_dozing())]
		if _opts.has("items"):
			var range_i: PackedStringArray = str(_opts["items"]).split(",")
			for entity: SimEntity in level.get_kind(Defs.Kind.COLLECTIBLE):
				if entity.sim_pos.x >= range_i[0].to_int() * 16 and entity.sim_pos.x <= range_i[1].to_int() * 16:
					text += " | %s %s (%d,%d)" % [entity.name, str(entity.get_script().resource_path.get_file()) if entity.get_script() else "", entity.sim_pos.x, entity.sim_pos.y]
			for entity: SimEntity in level.get_kind(Defs.Kind.HITTABLE):
				if entity.sim_pos.x >= range_i[0].to_int() * 16 and entity.sim_pos.x <= range_i[1].to_int() * 16:
					text += " | %s (%d,%d) op%d" % [entity.name, entity.sim_pos.x, entity.sim_pos.y,
						int((entity as HittableBase).opened)]
		if _opts.has("enemies"):
			var range_x: PackedStringArray = str(_opts["enemies"]).split(",")
			for enemy: SimEntity in level.get_kind(Defs.Kind.ENEMY):
				var foe: EnemyBase = enemy as EnemyBase
				if foe != null and not foe.dead and foe.sim_pos.x >= range_x[0].to_int() * 16 \
						and foe.sim_pos.x <= range_x[1].to_int() * 16:
					text += " | %s (%d,%d) f%d aw%d hp%d" % [foe.name, foe.sim_pos.x, foe.sim_pos.y, foe.facing,
						int(foe.awake), foe.hp]
		if _opts.has("boss"):
			for entity: SimEntity in level.get_kind(Defs.Kind.BOSS):
				var tree: Mangrove = entity as Mangrove
				if tree == null:
					continue
				text += " | MG hp%d st%d fist%d@%d t%d face%d fr%s cd%d" % [tree.hp, tree.get_stage(), tree.get_fist_state(),
					tree._fist_x, tree._fist_timer, tree.get_fist_facing(), str(tree.get_fist_rect()), tree.hit_cooldown]
				for hero: PlayerBase in level.heroes:
					text += " c%d %s %s" % [hero.slot + 1, str(hero.club_box) if hero.club_box_active else "-",
						str(hero.counts_for_coop())]
		print("t=%d%s | cam %s | score %d lives %d hearts %d" % [stage_tick, text, level.get_camera_cell(), Game.score,
			Game.lives, Game.hearts])
	_last["key"] = key


func _connect_events() -> void:
	Events.hero_down.connect(func(hero: PlayerBase, cause: StringName) -> void:
		print("EV t=%d hero_down P%d %s" % [_tick, hero.slot + 1, cause]))
	Events.hero_revived.connect(func(hero: PlayerBase, _by: PlayerBase) -> void:
		print("EV t=%d hero_revived P%d" % [_tick, hero.slot + 1]))
	Events.party_wiped.connect(func() -> void: print("EV t=%d party_wiped" % _tick))
	Events.hero_died.connect(func(hero: PlayerBase, cause: StringName) -> void:
		print("EV t=%d hero_died P%d %s at %s" % [_tick, hero.slot + 1, cause, hero.sim_pos]))
	Events.checkpoint_activated.connect(func(cp: CheckpointBase) -> void:
		print("EV t=%d checkpoint %s" % [_tick, str(cp.sim_pos)]))
	Events.exit_reached.connect(func(kind: StringName) -> void: print("EV t=%d exit_reached %s" % [_tick, kind]))
	Events.level_completed.connect(func(id: StringName, kind: StringName) -> void:
		print("EV t=%d level_completed %s %s" % [_tick, id, kind]))
	Events.secret_found.connect(func(zone: StringName) -> void: print("EV t=%d secret %s" % [_tick, zone]))
	Events.painting_found.connect(func(index: int) -> void: print("EV t=%d painting %d" % [_tick, index]))
	Events.hero_hurt.connect(func(hero: PlayerBase, _kind: int, source: SimEntity) -> void:
		print("EV t=%d HURT P%d by %s at %s" % [_tick, hero.slot + 1, source.name if source != null else "?",
			hero.sim_pos]))
	Events.item_collected.connect(func(item_id: StringName, index: int, _points: int, _pos: Vector2i) -> void:
		if item_id == &"items/letter" or item_id == &"items/weapon" or item_id == &"items/painting" \
				or item_id == &"items/feast_piece" or item_id == &"items/water_bucket":
			print("EV t=%d item %s %d" % [_tick, item_id, index]))
	Events.hittable_hit.connect(func(h: SimEntity, used: bool) -> void:
		print("EV t=%d hittable %s at %s used %s" % [_tick, h.name, h.sim_pos, used]))
	if _quiet_events:
		return
	Events.hero_bounced.connect(func(hero: PlayerBase, target: SimEntity, _mult: int) -> void:
		print("EV t=%d bounce P%d on %s" % [_tick, hero.slot + 1, target.name if target != null else "?"]))
	Events.enemy_killed.connect(func(enemy: EnemyBase, _points: int, cause: StringName) -> void:
		print("EV t=%d kill %s at %s (%s)" % [_tick, enemy.name, str(enemy.sim_pos), cause]))
	Events.gate_used.connect(func(a: Vector2i, b: Vector2i) -> void: print("EV t=%d gate %s->%s" % [_tick, a, b]))
