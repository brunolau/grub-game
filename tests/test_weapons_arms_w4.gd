extends TestCase
## Weapon proofs of world 4 and the ending (owner: level design w4).
##
## WORK IN PROGRESS - analysis aids first.

const ROUTE_DIR: String = "res://tools/autoplay/routes/"
const VIEW: Vector2i = Vector2i(Tuning.VIEW_W, Tuning.VIEW_H)
const OUT_DIR: String = "res://build/arms_w4"

var _counts: Dictionary = {}
var _exit_kinds: Array[StringName] = []
var _boss_hits: int = 0
var _connections: Array[Array] = []


func after_each() -> void:
	for connection: Array in _connections:
		var signal_ref: Signal = connection[0]
		if signal_ref.is_connected(connection[1]):
			signal_ref.disconnect(connection[1])
	_connections.clear()
	_counts.clear()
	_exit_kinds.clear()
	_boss_hits = 0
	GameInput.clear_scripted()
	Sim.manual = false
	Sim.stop()
	if get_tree().current_scene != null:
		get_tree().current_scene.free()
		get_tree().current_scene = null
	Flow.current_screen = Flow.SCREEN_BOOT
	Flow.args = {}


# =================================================================================================================
# Route-building aids
# =================================================================================================================

## ARMS_PROBE=<route file> ARMS_WEAPON=<n> [ARMS_LEVEL=<id>] [ARMS_EVERY=n] [ARMS_INPUTS=<res:// file>]
func test_probe() -> void:
	var file: String = OS.get_environment("ARMS_PROBE")
	assert_true(true)
	if file.is_empty():
		return
	var level_id: StringName = StringName(OS.get_environment("ARMS_LEVEL")) if OS.get_environment("ARMS_LEVEL") != "" \
			else StringName(file.get_slice(".", 0))
	var weapon: int = OS.get_environment("ARMS_WEAPON").to_int()
	var every: int = maxi(OS.get_environment("ARMS_EVERY").to_int(), 0)
	var text: String = FileAccess.get_file_as_string(ROUTE_DIR + file)
	if OS.get_environment("ARMS_INPUTS") != "":
		text = FileAccess.get_file_as_string(OS.get_environment("ARMS_INPUTS"))
	await _start(level_id, weapon)
	var log_lines: PackedStringArray = PackedStringArray()
	var on_event: Callable = func(signal_name: StringName) -> void: log_lines.append(String(signal_name))
	for info: Dictionary in Events.get_signal_list():
		var name: StringName = StringName(str(info["name"]))
		if name in [&"popup_requested", &"player_landed", &"player_jumped", &"shake_requested", &"wind_changed",
				&"boss_energy_changed", &"energy_changed"]:
			continue
		var callable: Callable = on_event.bind(name)
		var arguments: int = (info["args"] as Array).size()
		_connect(Signal(Events, name), callable.unbind(arguments) if arguments > 0 else callable)
	var played: int = 0
	var line_no: int = 0
	var comment: String = ""
	var level: LevelBase = Game.level
	for line: String in text.split("\n"):
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
			if every > 0 and played % every == 0:
				print("    t%5d %s" % [played, _hero_text()])
		if flags.size() > 0:
			print("L%3d t%5d %s | %s %s" % [line_no, played, _hero_text(), " ".join(log_lines), comment])
			log_lines.clear()
		if not Sim.running or Game.level != level:
			break
	print("PROBE END t%d score %d lives %d hearts %d weapon %d level %s screen %s" % [
		played, Game.score, Game.lives, Game.hearts, Game.weapon, Game.level_id, Flow.current_screen])


## ARMS_ROCKS=1: the paths of the Colossus' rocks for every spit speed, from the real arena of w4_l2b (the statue
## frozen, the hero out of the way on the antechamber floor... kept in the arena so the view holds it).
func test_rock_paths() -> void:
	assert_true(true)
	if OS.get_environment("ARMS_ROCKS").is_empty():
		return
	await _start(&"w4_l2b", Defs.Weapon.AXE)
	var level: LevelBase = Game.level
	var hero: PlayerBase = level.player
	var colossus: Colossus = null
	for entity: SimEntity in level.get_kind(Defs.Kind.BOSS):
		colossus = entity as Colossus
	Sim.step(2)
	print("running %s tick %d hero %s" % [Sim.running, Sim.tick, hero.sim_pos])
	_teleport(hero, Vector2i(430, 192))
	Sim.step(60)
	colossus.sim_active = false
	print("view %s hero %s" % [level.get_view_rect(), hero.sim_pos])
	for step: int in EnemyTuning.ROCK_XVEL_STEPS:
		var speed: int = EnemyTuning.ROCK_XVEL_MIN + step * EnemyTuning.ROCK_XVEL_STEP
		_teleport(hero, Vector2i(430, 192))
		Game.hearts = 3
		var rock: ProjectileBase = level.spawn(&"projectiles/boss_rock", colossus.sim_pos + EnemyTuning.COLOSSUS_MOUTH,
				{"xvel": -speed, "yvel": 0}) as ProjectileBase
		var path: PackedStringArray = PackedStringArray()
		var t: int = 0
		while not rock.spent and t < 200:
			Sim.step(1)
			t += 1
			path.append("%d:%d,%d" % [t, rock.sim_pos.x, rock.sim_pos.y])
		print("ROCK v%d (%d ticks): %s" % [speed, t, " ".join(path)])


## ARMS_BENCH=1: time a level start and a replay of the w4_l2b route.
func test_bench() -> void:
	assert_true(true)
	if OS.get_environment("ARMS_BENCH").is_empty():
		return
	var flags: PackedInt32Array = Autoplay.parse_inputs(FileAccess.get_file_as_string(ROUTE_DIR + "w4_l2b.inputs"))
	for i: int in 3:
		var t0: int = Time.get_ticks_usec()
		await _start(&"w4_l2b", Defs.Weapon.CLUB)
		var t1: int = Time.get_ticks_usec()
		var played: int = _run(flags)
		var t2: int = Time.get_ticks_usec()
		print("BENCH start %d ms, %d ticks in %d ms (%.3f ms/tick)" % [(t1 - t0) / 1000, played, (t2 - t1) / 1000,
				float(t2 - t1) / 1000.0 / maxf(played, 1)])
		after_each()


## ARMS_BOT=<Defs.Weapon> builds a Colossus Hall route for a thrown weapon: a simple policy (stand at ARMS_BOT_HOME,
## throw whenever the head will take the hit) with backtracking - every hit the hero would take is undone by a dodge
## (a jump or a step) inserted before it, found by replaying the level from its start. ARMS_BOT_PREFIX=<res:// file>
## gives the walk into the arena (lines up to "# FIGHT"). Writes build/arms_w4/w4_l2b.<weapon>.bot.inputs.
## ARMS_BOT_STRIKE=high|fwd picks the throw.
func test_colossus_bot() -> void:
	assert_true(true)
	if OS.get_environment("ARMS_BOT").is_empty():
		return
	var weapon: int = OS.get_environment("ARMS_BOT").to_int()
	_bot = {
		"weapon": weapon,
		"home": OS.get_environment("ARMS_BOT_HOME").to_int() if OS.get_environment("ARMS_BOT_HOME") != "" else 556,
		"high": OS.get_environment("ARMS_BOT_STRIKE") != "fwd",
		"lead": OS.get_environment("ARMS_BOT_LEAD").to_int() if OS.get_environment("ARMS_BOT_LEAD") != "" else 2,
	}
	var prefix_text: String = FileAccess.get_file_as_string(OS.get_environment("ARMS_BOT_PREFIX"))
	var cut: int = prefix_text.find("# FIGHT")
	var inputs: PackedInt32Array = Autoplay.parse_inputs(prefix_text.substr(0, cut) if cut >= 0 else prefix_text)
	var marks: Dictionary = {"fight": inputs.size()}
	var plays: int = 0
	var fixes: PackedStringArray = PackedStringArray()
	var started: int = Time.get_ticks_msec()
	for iteration: int in 600:
		var run: Dictionary = await _bot_play(weapon, inputs, 48)
		plays += 1
		if int(run["hurt"]) >= 0:
			var fixed: Dictionary = await _bot_fix(weapon, inputs, run)
			plays += int(fixed["plays"])
			if (fixed["inputs"] as PackedInt32Array).is_empty():
				print("BOT stuck: hurt at t%d (%s), no dodge found; keeping the hit" % [run["hurt"], run["what"]])
				inputs.append_array(run["policy"])
				fixes.append("HIT t%d" % run["hurt"])
				continue
			inputs = fixed["inputs"]
			fixes.append("t%d:%s" % [run["hurt"], fixed["plan"]])
			continue
		inputs.append_array(run["policy"])
		if bool(run["defeated"]) and not marks.has("defeated"):
			marks["defeated"] = int(run["defeated_at"])
		if bool(run["left"]):
			break
	var final: Dictionary = await _bot_play(weapon, inputs, 0)
	print("BOT weapon %d: %d ticks (fight from t%d, boss down at t%s), %d plays, %d s; hurt %d, hearts %d, lives %d, hits %d, exits %s" % [
		weapon, inputs.size(), marks["fight"], str(marks.get("defeated", -1)), plays,
		(Time.get_ticks_msec() - started) / 1000, final["hurts"], Game.hearts, Game.lives, final["boss_hits"],
		str(final["exits"])])
	print("BOT fixes: %s" % ", ".join(fixes))
	_write_inputs("w4_l2b.%d.bot.inputs" % weapon, inputs, "# Colossus bot, weapon %d, home %d" % [weapon, _bot["home"]])


var _bot: Dictionary = {}
var _queue: PackedInt32Array = PackedInt32Array()


## Fresh start, replay `inputs`, then let the policy play up to `horizon` ticks. Stops at the first hit the hero
## takes during the policy part, at the trophy, or when the level is left.
func _bot_play(weapon: int, inputs: PackedInt32Array, horizon: int, check_from: int = -1) -> Dictionary:
	if check_from < 0:
		check_from = inputs.size()
	after_each()
	await _start(&"w4_l2b", weapon)
	var level: LevelBase = Game.level
	var policy: PackedInt32Array = PackedInt32Array()
	var index: Array[int] = [0]
	_queue = PackedInt32Array()
	GameInput.set_scripted(func(_tick: int) -> int:
		var i: int = index[0]
		index[0] += 1
		if i < inputs.size():
			return inputs[i]
		var value: int = _bot_policy()
		policy.append(value)
		return value
	)
	var result: Dictionary = {"hurt": -1, "what": "", "policy": policy, "defeated": false, "defeated_at": -1,
		"left": false}
	var played: int = 0
	var colossus: Colossus = _colossus()
	while played < inputs.size() + horizon and Sim.running and Game.level == level:
		var hurts: int = _count(&"player_hurt")
		Sim.step(1)
		played += 1
		if not _exit_kinds.is_empty() or Game.level != level:
			result["left"] = true
			break
		if colossus != null and colossus.dead and not bool(result["defeated"]):
			result["defeated"] = true
			result["defeated_at"] = played
		if _count(&"player_hurt") > hurts and played > check_from:
			result["hurt"] = played - 1
			result["what"] = _threats_text()
			break
		if level.player.dead:
			result["hurt"] = played - 1
			result["what"] = "death"
			break
	GameInput.clear_scripted()
	result["policy"] = policy
	result["hurts"] = _count(&"player_hurt")
	result["boss_hits"] = _boss_hits
	result["exits"] = _exit_kinds.duplicate()
	return result


## Undo the hit of `run`: from the latest tick back, insert a dodge plan and check that the hero gets through the
## next ticks unhurt.
func _bot_fix(weapon: int, inputs: PackedInt32Array, run: Dictionary) -> Dictionary:
	var base: PackedInt32Array = inputs.duplicate()
	base.append_array(run["policy"])
	var hurt: int = int(run["hurt"])
	var plans: Array = [["U", 14], ["U", 8], ["U", 20], ["U", 4], ["L", 8], ["L", 14], ["R", 8], ["LU", 12],
		["RU", 12], ["L", 22], ["", 10]]
	var plays: int = 0
	var low: int = maxi(hurt - 40, 1)
	for back: int in range(1, hurt - low + 1):
		var at: int = hurt - back
		for plan: Array in plans:
			var candidate: PackedInt32Array = base.slice(0, at)
			var value: int = GameInput.keys_to_flags(str(plan[0]))
			for n: int in int(plan[1]):
				candidate.append(value)
			var check: Dictionary = await _bot_play(weapon, candidate, hurt - at + 30, at)
			plays += 1
			if int(check["hurt"]) < 0:
				print("  fix t%d: %s x%d at t%d (%d plays)" % [hurt, plan[0], plan[1], at, plays])
				return {"inputs": candidate, "plan": "%s%d@%d" % [plan[0], plan[1], at], "plays": plays}
	return {"inputs": PackedInt32Array(), "plan": "", "plays": plays}


## The policy: walk to the home spot, face the statue, throw when the weapon will reach the head after its hit
## cooldown; otherwise stand. Inputs come from a queue of whole moves.
func _bot_policy() -> int:
	if not _queue.is_empty():
		var value: int = _queue[0]
		_queue.remove_at(0)
		return value
	var level: LevelBase = Game.level
	var hero: PlayerBase = level.player
	var colossus: Colossus = _colossus()
	if colossus == null or hero.dead:
		return 0
	if colossus.dead:
		return _bot_collect(hero)
	if hero.swing_lock > 0 or not hero.is_grounded() or hero.hit_timer >= Tuning.HIT_STUN_MIN:
		return 0
	var home: int = int(_bot["home"])
	var dx: int = home - hero.sim_pos.x
	# Up onto the slab when it is the home and he stands on the floor below it.
	if hero.sim_pos.y > 176 and home >= 528 and home < 576 and absi(dx) < 40:
		_enqueue(Defs.IN_UP | (Defs.IN_RIGHT if dx > 0 else Defs.IN_LEFT), 7)
		_enqueue(Defs.IN_UP, 4)
		return Defs.IN_UP | (Defs.IN_RIGHT if dx > 0 else Defs.IN_LEFT)
	if dx > 6:
		return Defs.IN_RIGHT
	if dx < -6:
		return Defs.IN_LEFT
	if hero.xvel != 0:
		return 0
	var strike: int = 9 if bool(_bot["high"]) else 7
	if colossus.fighting and colossus.hit_cooldown <= strike + int(_bot["lead"]):
		if hero.facing < 0:
			return Defs.IN_RIGHT
		var keys: int = (Defs.IN_UP | Defs.IN_FIRE) if bool(_bot["high"]) else Defs.IN_FIRE
		_enqueue(keys, strike - 1)
		_enqueue(0, Tuning.WEAPON_LOCK[Game.weapon])
		return keys
	return 0


## After the defeat: wait for the trophies to land, then walk to the nearest one.
func _bot_collect(hero: PlayerBase) -> int:
	var best: SimEntity = null
	for entity: SimEntity in Game.level.get_kind(Defs.Kind.COLLECTIBLE):
		if entity is Trophy and (best == null or absi(entity.sim_pos.x - hero.sim_pos.x) < absi(best.sim_pos.x - hero.sim_pos.x)):
			best = entity
	if best == null:
		return 0
	var dx: int = best.sim_pos.x - hero.sim_pos.x
	if best.yvel != 0:
		return 0
	if absi(dx) <= 4:
		return Defs.IN_UP if best.sim_pos.y < hero.sim_pos.y - 8 else 0
	return Defs.IN_RIGHT if dx > 0 else Defs.IN_LEFT


func _enqueue(value: int, count: int) -> void:
	for i: int in count:
		_queue.append(value)


func _colossus() -> Colossus:
	if Game.level == null:
		return null
	for entity: SimEntity in Game.level.get_kind(Defs.Kind.BOSS):
		if entity is Colossus:
			return entity as Colossus
	return null


func _threats_text() -> String:
	var parts: PackedStringArray = PackedStringArray()
	for entity: SimEntity in Game.level.get_kind(Defs.Kind.ENEMY_PROJECTILE):
		var name: String = "rock" if entity is BossRock else ("drop" if entity is BossStalactite else "other")
		parts.append("%s@%d,%d v%d" % [name, entity.sim_pos.x, entity.sim_pos.y, entity.xvel])
	return " ".join(parts)


## Write `flags` as a route file to build/arms_w4/<file>: runs of equal input as "ticks:KEYS".
func _write_inputs(file: String, flags: PackedInt32Array, header: String) -> void:
	var lines: PackedStringArray = PackedStringArray([header])
	var runs: PackedStringArray = PackedStringArray()
	var run_value: int = -1
	var run_length: int = 0
	for t: int in flags.size() + 1:
		if t < flags.size() and flags[t] == run_value:
			run_length += 1
			continue
		if run_length > 0:
			runs.append("%d:%s" % [run_length, _keys(run_value)])
		if ",".join(runs).length() > 100 or t == flags.size():
			lines.append(",".join(runs))
			runs.clear()
		if t < flags.size():
			run_value = flags[t]
			run_length = 1
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var handle: FileAccess = FileAccess.open(OUT_DIR + "/" + file, FileAccess.WRITE)
	if handle != null:
		handle.store_string("\n".join(lines) + "\n")
		handle.close()
		print("wrote %s/%s" % [OUT_DIR, file])


func _keys(flags: int) -> String:
	var keys: String = ""
	for pair: Array in [[Defs.IN_LEFT, "L"], [Defs.IN_RIGHT, "R"], [Defs.IN_UP, "U"], [Defs.IN_DOWN, "D"],
			[Defs.IN_FIRE, "F"], [Defs.IN_LOOK, "K"]]:
		if flags & int(pair[0]):
			keys += str(pair[1])
	return keys


# =================================================================================================================
# Helpers
# =================================================================================================================

## A fresh Expert run carrying `weapon`, entering `level_id` through Flow like the map or a level code does.
func _start(level_id: StringName, weapon: int) -> void:
	Game.new_game(Defs.Difficulty.EXPERT)
	Game.set_weapon(weapon)
	_watch_events()
	Sim.manual = true
	await _idle()
	Flow.start_level(level_id, Defs.Transition.NONE)
	await _settle()
	assert_eq(Flow.current_screen, Flow.SCREEN_LEVEL, "%s started" % level_id)
	_set_view()


func _teleport(hero: PlayerBase, pos: Vector2i) -> void:
	hero.teleport(pos)
	var level: Level = Game.level as Level
	if level != null:
		level.snap_camera()


func _set_view() -> void:
	var level: Level = Game.level as Level
	if level != null:
		level.set_view_size(VIEW * Tuning.ART_SCALE)


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
	_connect(Events.enemy_hit, _on_enemy_hit)
	_connect(Events.exit_reached, _on_exit)


func _connect(signal_ref: Signal, callable: Callable) -> void:
	signal_ref.connect(callable)
	_connections.append([signal_ref, callable])


func _idle() -> void:
	await get_tree().process_frame
	while Flow.busy:
		await get_tree().process_frame


func _settle() -> void:
	for i: int in 3:
		await get_tree().process_frame
	while Flow.busy:
		await get_tree().process_frame


func _count(signal_name: StringName) -> int:
	return int(_counts.get(signal_name, 0))


func _on_event(signal_name: StringName) -> void:
	_counts[signal_name] = _count(signal_name) + 1


func _on_enemy_hit(enemy: EnemyBase, _power: int) -> void:
	if enemy is BossBase:
		_boss_hits += 1


func _on_exit(exit_kind: StringName) -> void:
	_exit_kinds.append(exit_kind)


func _hero_text() -> String:
	var level: LevelBase = Game.level
	if level == null or level.player == null:
		return "(no hero)"
	var hero: PlayerBase = level.player
	return "x%5d y%5d c%3d r%3d st%d v(%d,%d) h%d w%d%s" % [hero.sim_pos.x, hero.sim_pos.y, hero.sim_pos.x >> 4,
		(hero.sim_pos.y - 1) >> 4, hero.state, hero.xvel, hero.yvel, Game.hearts, Game.weapon,
		" DEAD" if hero.dead else ""]
