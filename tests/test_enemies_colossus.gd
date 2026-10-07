extends TestCase
## The tuned Wall Colossus of Colossus Hall (w4_l2b) and the route aids made for world 4 (owner: level design w4).
## The world 4 route proofs (every level with every weapon, the fight with 2+ hearts left in 45-90 s) live in
## tests/test_campaign_routes.gd.
##
## The Colossus tests pin its fairness tuning (scripts/bosses/colossus.gd, EnemyTuning COLOSSUS_* / ROCK_* /
## STALACTITE_*): every attack shows its pose at least 10 ticks before anything can reach the hero, every rock speed
## can be jumped by a hero on the throwing slab with a reaction time to spare, a stalactite over the hero can be
## walked away from long after it appeared, hits never stop the attacks, the red rage pose is armoured, and both
## thrown weapons reach the head from the slab.
##
## 2.0 (enemies-C, PLAN.md P2.3): the co-op visor Colossus of w4_l2b_coop and its fairness per hero, at the end.
##
## Route-building aids (no tests of their own; with one of them set only that aid runs, every other test is skipped):
##   ARMS_PROBE=<route file> ARMS_WEAPON=<n> [ARMS_LEVEL=<id>] [ARMS_EVERY=n] [ARMS_INPUTS=<res:// file>]
##       [ARMS_PROBE_FIT=1]   replay a route line by line with a weapon, print the hero and the events of every line
##   ARMS_REPAIR=<route file> ARMS_WEAPON=<n> [...]   re-time a route for a weapon (see test_repair_route; it made the
##       Cinder Shaft weapon routes, keeping the hero in step with the sinking view)
##   ARMS_BOT=<weapon> ARMS_BOT_PREFIX=<res:// file> [ARMS_BOT_HOME=x] [ARMS_BOT_STRIKE=fwd]   record a Colossus fight
##   ARMS_FAIR=1   print the dodge table of the Colossus fight;  ARMS_ROCKS=1   print the rock paths
##   ARMS_BENCH=1   time a level start and a replay

const ROUTE_DIR: String = "res://tools/autoplay/routes/"
const VIEW: Vector2i = Vector2i(Tuning.VIEW_W, Tuning.VIEW_H)
const OUT_DIR: String = "res://build/arms_w4"
const CLUB: int = Defs.Weapon.CLUB
const HAMMER: int = Defs.Weapon.HAMMER
const AXE: int = Defs.Weapon.AXE
const BOOMERANG: int = Defs.Weapon.BOOMERANG
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
var _exit_kinds: Array[StringName] = []
var _boss_hits: int = 0
var _words: int = 0
var _connections: Array[Array] = []
var _problems: ProblemCounter = null


func after_each() -> void:
	if _problems != null:
		OS.remove_logger(_problems)
		_problems = null
	for connection: Array in _connections:
		var signal_ref: Signal = connection[0]
		if signal_ref.is_connected(connection[1]):
			signal_ref.disconnect(connection[1])
	_connections.clear()
	_counts.clear()
	_exit_kinds.clear()
	_boss_hits = 0
	_words = 0
	GameInput.clear_scripted()
	Sim.manual = false
	Sim.stop()
	if get_tree().current_scene != null:
		get_tree().current_scene.free()
		get_tree().current_scene = null
	Flow.current_screen = Flow.SCREEN_BOOT
	Flow.args = {}
	if _hall != null:
		_coop_teardown()


## Play a route in the running stage until it ends or the stage is left; the numbers of the stage.
func _play(file: String) -> Dictionary:
	var flags: PackedInt32Array = Autoplay.parse_inputs(FileAccess.get_file_as_string(ROUTE_DIR + file))
	var index: Array[int] = [0]
	GameInput.set_scripted(func(_tick: int) -> int:
		var value: int = flags[index[0]] if index[0] < flags.size() else 0
		index[0] += 1
		return value
	)
	var level: LevelBase = Game.level
	var result: Dictionary = {"ticks": 0, "hearts": Game.hearts, "boss_up": -1, "boss_down": -1}
	var played: int = 0
	var start_view_y: int = level.get_view_rect().position.y
	var deepest_view_y: int = start_view_y
	var embers: Dictionary = {}
	var close: Dictionary = {}
	while played < flags.size() and Sim.running and Game.level == level:
		Sim.step(1)
		played += 1
		if Game.level == level and level.player != null:
			deepest_view_y = maxi(deepest_view_y, level.get_view_rect().position.y)
			for entity: SimEntity in level.get_kind(Defs.Kind.ENEMY_PROJECTILE):
				if entity is EnemyEmber:
					embers[entity.get_instance_id()] = true
					var rel: Vector2i = entity.sim_pos - level.player.sim_pos
					if absi(rel.x) < 24 and rel.y > -56 and rel.y < 8:
						close[entity.get_instance_id()] = true
		if int(result["boss_up"]) < 0 and _count(&"boss_started") > 0:
			result["boss_up"] = played
		if int(result["boss_down"]) < 0 and _count(&"boss_defeated") > 0:
			result["boss_down"] = played
	GameInput.clear_scripted()
	result["ticks"] = played
	result["hearts"] = Game.hearts
	result["hurts"] = _count(&"player_hurt")
	result["view_sank"] = deepest_view_y - start_view_y
	result["embers"] = embers.size()
	result["embers_close"] = close.size()
	return result


func _enter(level_id: StringName) -> void:
	_watch_events()
	Sim.manual = true
	await _idle()
	Flow.start_level(level_id, Defs.Transition.NONE)
	await _settle()
	assert_eq(Flow.current_screen, Flow.SCREEN_LEVEL, "%s started" % level_id)
	_set_view()


func _reset_watch() -> void:
	_counts.clear()
	_exit_kinds.clear()
	_boss_hits = 0
	_words = 0


func _aid_running() -> bool:
	for name: String in ["ARMS_PROBE", "ARMS_REPAIR", "ARMS_BOT", "ARMS_FAIR", "ARMS_ROCKS", "ARMS_BENCH"]:
		if not OS.get_environment(name).is_empty():
			return true
	return false


# =================================================================================================================
# The tuned Wall Colossus
# =================================================================================================================

## Watch the Colossus of Colossus Hall for 1500 ticks after it wakes (the hero, kept alive, stands at the far end of
## the hall; a thrown weapon reaches its head every 160 ticks, so it roars and rages too): its first rock leaves on
## the 94th tick of the fight, the open jaws (spit or red rage pose) show for at least 10 ticks before every rock, every
## stalactite comes after the slam pose and rattles 14 ticks below the low ceiling before it falls, so its tip
## reaches the head of a hero standing under it at least 24 ticks after it appeared - and the attacks keep coming however often it is hit.
func test_colossus_shows_every_attack_ahead() -> void:
	if _aid_running():
		assert_true(true, "skipped while a route-building aid runs")
		return
	var watch: Dictionary = await _watch_colossus(1500, 160)
	print("    Colossus watched: first rock %d ticks after waking, %d rocks (jaws open at least %d ticks before), %d stalactites (still for at least %d ticks, at head height after at least %d), %d rages, %d hits, longest pause between attacks %d ticks" % [
		watch["first_rock"], watch["rocks"], watch["min_jaws"], watch["drops"], watch["min_still"], watch["min_head"],
		watch["rages"], watch["hits"], watch["longest_pause"]])
	assert_eq(int(watch["first_rock"]) + 1, EnemyTuning.COLOSSUS_IDLE_TICKS[0] + EnemyTuning.COLOSSUS_SPIT_RELEASE_TICK,
			"the first rock leaves on the 94th tick of the fight")
	assert_true(int(watch["first_rock"]) >= 90, "time to reach the slab before the first rock")
	assert_true(int(watch["rocks"]) >= 8 and int(watch["drops"]) >= 8, "it spits and slams (%d, %d)" % [
		watch["rocks"], watch["drops"]])
	assert_true(int(watch["rages"]) >= 2, "it raged after the 1st and the 5th hit")
	assert_true(int(watch["min_jaws"]) >= 10, "every rock: the jaws are open %d+ ticks before" % watch["min_jaws"])
	assert_true(int(watch["min_still"]) >= EnemyTuning.STALACTITE_WARN_TICKS, "every stalactite rattles first")
	assert_true(int(watch["min_head"]) >= 24, "every stalactite reaches head height %d+ ticks after it appears" % [
		watch["min_head"]])
	assert_true(int(watch["longest_pause"]) <= 140, "hits never stop the attacks (longest pause %d ticks)" % [
		watch["longest_pause"]])


## A perfect thrower (a thrown weapon on the head on every tick it can count - no player throws that fast) beats the
## Colossus no sooner than its roars and armoured rages allow (about 33 s; the recorded fights with real throws take
## 46-52 s), and it attacks all the same, never pausing longer than 140 ticks: hits cannot stun-lock it.
func test_colossus_cannot_be_stun_locked() -> void:
	if _aid_running():
		assert_true(true, "skipped while a route-building aid runs")
		return
	var watch: Dictionary = await _watch_colossus(2400, 0)
	print("    Colossus against a perfect thrower: beaten after %d ticks (%.1f s), %d hits, %d rocks, %d stalactites, %d rages, %d glanced off the rage pose, longest pause between attacks %d ticks" % [
		watch["down"], watch["down"] / Tuning.TICK_HZ, watch["hits"], watch["rocks"], watch["drops"], watch["rages"],
		watch["glanced"], watch["longest_pause"]])
	assert_true(int(watch["down"]) > 0, "it is beaten")
	assert_eq(int(watch["hits"]), EnemyTuning.COLOSSUS_HP, "24 hits")
	assert_eq(int(watch["rages"]), 6, "a rage after hits 1, 5, 9, 13, 17 and 21")
	assert_true(int(watch["glanced"]) > 0, "weapons glance off the red rage pose")
	assert_true(int(watch["down"]) >= 6 * EnemyTuning.COLOSSUS_RAGE_TICKS + 18 * (EnemyTuning.COLOSSUS_HURT_TICKS + 1),
			"the roars and rages take their time")
	assert_true(int(watch["rocks"]) + int(watch["drops"]) >= 20, "it keeps attacking while it is hit (%d attacks)" % [
		int(watch["rocks"]) + int(watch["drops"])])
	assert_true(int(watch["longest_pause"]) <= 140, "longest pause between attacks %d ticks" % watch["longest_pause"])


## Every rock speed, met anywhere on the throwing slab: it reaches a hero who stands still no sooner than 14 ticks
## after it leaves the jaws (24 after they opened), and a standing jump (Up held) started on any of at least 4
## neighbouring ticks, the first of them 6 or more ticks after the rock left, lets it pass - a reaction, not a
## frame-perfect input. (Printed for comparison: the floor just in front of the slab, where a fast rock's arc comes
## down - there the jump must start as the jaws open.)
func test_colossus_rocks_can_be_jumped() -> void:
	if _aid_running():
		assert_true(true, "skipped while a route-building aid runs")
		return
	var arena: Dictionary = await _frozen_arena()
	var spots: Array[Vector2i] = [Vector2i(532, 176), Vector2i(556, 176), Vector2i(574, 176), Vector2i(590, 192)]
	var trials: int = 0
	for step: int in EnemyTuning.ROCK_XVEL_STEPS:
		var speed: int = EnemyTuning.ROCK_XVEL_MIN + step * EnemyTuning.ROCK_XVEL_STEP
		var line: PackedStringArray = PackedStringArray()
		for spot: Vector2i in spots:
			var still: int = int(_rock_trial(arena, speed, spot, -1)["hit"])
			var good: PackedInt32Array = PackedInt32Array()
			if still >= 0:
				for jump: int in range(0, still + 1):
					if int(_rock_trial(arena, speed, spot, jump)["hit"]) < 0:
						good.append(jump)
					trials += 1
					if trials % 40 == 0:
						await get_tree().process_frame
				if spot.y == 176:
					assert_true(still >= 14, "rock v%d at %s: reaches a standing hero after %d ticks" % [speed, spot, still])
					assert_true(_longest_run(good, 6) >= 4, "rock v%d at %s: jump starts that let it pass: %s" % [
						speed, spot, _ranges(good)])
			line.append("%d: %s" % [spot.x, "jump %s (hit at %d)" % [_ranges(good), still] if still >= 0 else "passes"])
		print("    rock v%d | %s" % [speed, " | ".join(line)])


## A stalactite shaken loose right over the hero (on the floor of the hall, or on the slab) rattles long enough to
## react: its tip reaches his head 22+ ticks after it appeared (the slam pose shows 4 ticks before that), and he gets
## away walking if he starts on any tick up to 16 ticks after it appeared.
func test_colossus_stalactites_can_be_escaped() -> void:
	if _aid_running():
		assert_true(true, "skipped while a route-building aid runs")
		return
	var arena: Dictionary = await _frozen_arena()
	for spot: Vector2i in [Vector2i(440, 192), Vector2i(500, 192), Vector2i(556, 176), Vector2i(600, 192)]:
		var drop: Dictionary = await _drop_trial(arena, spot, 24)
		var escape: PackedInt32Array = drop["escape"]
		print("    stalactite over %s: at head height %d ticks after it appeared; walking away works when started on tick %s" % [
			spot, drop["head"], _ranges(escape)])
		assert_true(int(drop["head"]) >= 22, "over %s: at head height after %d ticks" % [spot, drop["head"]])
		var all_early: bool = true
		for start: int in 17:
			all_early = all_early and escape.has(start)
		assert_true(all_early, "over %s: walking away started on any of ticks 0-16 works (%s)" % [spot, _ranges(escape)])


## Both thrown weapons reach the head from the throwing slab in every pose the Colossus can be hit in: the axe thrown
## high (Up + Fire), the swirling axe thrown straight (Fire; it curves up).
func test_thrown_weapons_reach_the_head_from_the_slab() -> void:
	if _aid_running():
		assert_true(true, "skipped while a route-building aid runs")
		return
	var arena: Dictionary = await _frozen_arena()
	var colossus: Colossus = arena["colossus"]
	for pose: StringName in [&"idle", &"spit", &"slam"]:
		colossus._play(pose, true)
		var line: PackedStringArray = PackedStringArray()
		for throw: Array in [[AXE, Defs.IN_UP | Defs.IN_FIRE, 9], [BOOMERANG, Defs.IN_FIRE, 7]]:
			var reach: PackedInt32Array = PackedInt32Array()
			for x: int in range(530, 576, 4):
				if await _throw_reaches(arena, int(throw[0]), int(throw[1]), int(throw[2]), Vector2i(x, 176)):
					reach.append(x)
			line.append("weapon %d from x %s" % [throw[0], _ranges(reach)])
			assert_true(reach.size() >= 4, "%s pose: weapon %d reaches the head from the slab (%s)" % [pose, throw[0],
					_ranges(reach)])
		print("    head in the %s pose: %s" % [pose, ", ".join(line)])


## Throw `weapon` from `spot` facing the statue; true when the weapon's box meets the head rectangle of the current
## pose (the statue is frozen, so the weapon flies on).
func _throw_reaches(arena: Dictionary, weapon: int, keys: int, ticks: int, spot: Vector2i) -> bool:
	var level: LevelBase = arena["level"]
	var hero: PlayerBase = arena["hero"]
	var colossus: Colossus = arena["colossus"]
	Game.set_weapon(weapon)
	for entity: SimEntity in level.get_kind(Defs.Kind.HERO_PROJECTILE):
		(entity as ProjectileBase).consume()
	_clear_projectiles(level)
	_settle_hero(hero, spot)
	hero.facing = 1
	var clock: Array[int] = [0]
	GameInput.set_scripted(func(_tick: int) -> int:
		return keys if clock[0] < ticks else 0
	)
	var head: Rect2i = colossus.get_head_rect()
	var reached: bool = false
	while clock[0] < ticks + 24 and not reached:
		Sim.step(1)
		clock[0] += 1
		for entity: SimEntity in level.get_kind(Defs.Kind.HERO_PROJECTILE):
			var projectile: ProjectileBase = entity as ProjectileBase
			if projectile != null and not projectile.spent and Overlap.rects(projectile.get_box(), head):
				reached = true
	GameInput.clear_scripted()
	await get_tree().process_frame
	return reached


## Watch the Colossus of Colossus Hall for `ticks` after it wakes, the hero kept alive at the far end of the hall.
## `every` > 0: a thrown weapon reaches the head every `every` ticks; 0: on every tick it can count (a perfect
## thrower). Returns what it did.
func _watch_colossus(ticks: int, every: int) -> Dictionary:
	await _start(&"w4_l2b", AXE)
	var level: LevelBase = Game.level
	var hero: PlayerBase = level.player
	Sim.step(2)
	_teleport(hero, Vector2i(560, 192))
	var colossus: Colossus = _colossus()
	var woke: int = -1
	var t: int = 0
	while woke < 0 and t < 30:
		Sim.step(1)
		t += 1
		if colossus.fighting:
			woke = t
	_teleport(hero, Vector2i(424, 192))
	var watch: Dictionary = {"first_rock": -1, "rocks": 0, "drops": 0, "rages": 0, "hits": 0, "glanced": 0,
		"min_jaws": 1 << 20, "min_still": 1 << 20, "min_head": 1 << 20, "longest_pause": 0, "down": -1}
	var seen: Dictionary = {}
	var drops: Dictionary = {}  # instance id -> [tick it appeared, its first y, tick it first moved]
	var jaws: int = 0
	var last_attack: int = 0
	var last_state: int = -1
	var hits_before: int = 0
	var state: int = colossus.get_state()
	for tick: int in range(1, ticks + 1):
		Game.hearts = Tuning.ENERGY_START
		if colossus.dead:
			break
		var flying: int = 0
		for entity: SimEntity in level.get_kind(Defs.Kind.HERO_PROJECTILE):
			flying += 0 if (entity as ProjectileBase).spent else 1
		var hittable: bool = colossus.hit_cooldown <= 1 and flying == 0
		var due: bool = every == 0 or tick % every == 0
		var thrown: ProjectileBase = null
		if due and hittable:
			var head: Rect2i = colossus.get_head_rect()
			thrown = level.spawn(&"projectiles/hero_axe", Vector2i(head.get_center().x, head.end.y),
					{"from_hero": true, "power": 20, "xvel": 0, "yvel": 0, "yacc": 0}) as ProjectileBase
		hits_before = colossus.get_hits()
		Sim.step(1)
		if colossus.dead:
			watch["down"] = tick
			break
		if thrown != null and thrown.spent and colossus.get_hits() == hits_before and state == Colossus.State.RAGE:
			watch["glanced"] = int(watch["glanced"]) + 1
		state = colossus.get_state()
		jaws = jaws + 1 if state == Colossus.State.SPIT or state == Colossus.State.RAGE else 0
		if state == Colossus.State.RAGE and last_state != Colossus.State.RAGE:
			watch["rages"] = int(watch["rages"]) + 1
		last_state = state
		for entity: SimEntity in level.get_kind(Defs.Kind.ENEMY_PROJECTILE):
			var id: int = entity.get_instance_id()
			if seen.has(id):
				continue
			seen[id] = true
			watch["longest_pause"] = maxi(int(watch["longest_pause"]), tick - last_attack)
			last_attack = tick
			if entity is BossRock:
				watch["rocks"] = int(watch["rocks"]) + 1
				# The rock appeared during this tick: the jaws were open on the ticks before it.
				watch["min_jaws"] = mini(int(watch["min_jaws"]), jaws - 1)
				if int(watch["first_rock"]) < 0:
					watch["first_rock"] = tick + t - woke
			elif entity is BossStalactite:
				watch["drops"] = int(watch["drops"]) + 1
				drops[id] = [tick, entity.sim_pos.y, -1, -1]
		for entity: SimEntity in level.get_kind(Defs.Kind.ENEMY_PROJECTILE):
			var id: int = entity.get_instance_id()
			if not drops.has(id):
				continue
			var info: Array = drops[id]
			if int(info[2]) < 0 and entity.sim_pos.y != int(info[1]):
				info[2] = tick
				watch["min_still"] = mini(int(watch["min_still"]), tick - int(info[0]))
			if int(info[3]) < 0 and entity.sim_pos.y >= 192 - Tuning.HERO_BOX_STAND.y:
				info[3] = tick
				watch["min_head"] = mini(int(watch["min_head"]), tick - int(info[0]))
		if tick % 100 == 0:
			await get_tree().process_frame
	watch["hits"] = colossus.get_hits() if not colossus.dead else EnemyTuning.COLOSSUS_HP
	return watch


func _longest_run(values: PackedInt32Array, from: int) -> int:
	var best: int = 0
	var run: int = 0
	var last: int = -10
	for value: int in values:
		if value < from:
			continue
		run = run + 1 if value == last + 1 else 1
		last = value
		best = maxi(best, run)
	return best


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
	if OS.get_environment("ARMS_PROBE_FIT") != "":
		# The whole route with the swings fitted to the weapon, as one line per original line is lost: one tick each.
		var fitted: PackedInt32Array = _fit_strikes(Autoplay.parse_inputs(text), weapon)
		var parts: PackedStringArray = PackedStringArray()
		for value: int in fitted:
			parts.append("1:%s" % _keys(value))
		text = ",".join(parts)
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


## ARMS_ROCKS=1: the paths of the Colossus' rocks for every spit speed, in the real arena of w4_l2b (the statue
## frozen once it woke, the hero at the far end of the hall so the view stays locked on the arena).
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
	_teleport(hero, Vector2i(430, 192))
	Sim.step(60)
	colossus.sim_active = false
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


## ARMS_FAIR=1 prints the dodge table of the Colossus fight in the real arena (statue frozen after it woke): for
## every rock speed and every throwing spot, whether a hero standing still is hit, and the jump starts (ticks after
## the rock leaves the jaws, Up held 14 ticks) that let it pass; then the stalactite's warning.
func test_fight_table() -> void:
	assert_true(true)
	if OS.get_environment("ARMS_FAIR").is_empty():
		return
	var arena: Dictionary = await _frozen_arena()
	var spots: Array[Vector2i] = [Vector2i(520, 192), Vector2i(536, 176), Vector2i(556, 176), Vector2i(572, 176),
		Vector2i(590, 192), Vector2i(610, 192), Vector2i(628, 192)]
	for step: int in EnemyTuning.ROCK_XVEL_STEPS:
		var speed: int = EnemyTuning.ROCK_XVEL_MIN + step * EnemyTuning.ROCK_XVEL_STEP
		var line: PackedStringArray = PackedStringArray()
		for spot: Vector2i in spots:
			var still: Dictionary = _rock_trial(arena, speed, spot, -1)
			var good: PackedInt32Array = PackedInt32Array()
			for jump: int in 60:
				if int(_rock_trial(arena, speed, spot, jump)["hit"]) < 0:
					good.append(jump)
			line.append("%d,%d: %s %s" % [spot.x, spot.y, "hit@%d" % still["hit"] if int(still["hit"]) >= 0 else "safe",
				_ranges(good)])
		print("ROCK v%d | %s" % [speed, " | ".join(line)])
	for spot: Vector2i in [Vector2i(440, 192), Vector2i(500, 192), Vector2i(556, 176), Vector2i(600, 192)]:
		var drop: Dictionary = await _drop_trial(arena, spot)
		print("DROP %s: tip at head height %d ticks after it appears; a hero under it who starts walking on tick %s gets away" % [
			spot, drop["head"], _ranges(drop["escape"])])


## The w4_l2b arena with the fight started and the Colossus frozen: {"level", "hero", "colossus"}.
func _frozen_arena() -> Dictionary:
	await _start(&"w4_l2b", Defs.Weapon.AXE)
	var level: LevelBase = Game.level
	var hero: PlayerBase = level.player
	Sim.step(2)
	_teleport(hero, Vector2i(560, 192))
	Sim.step(4)
	var colossus: Colossus = _colossus()
	colossus.sim_active = false
	return {"level": level, "hero": hero, "colossus": colossus}


func _clear_projectiles(level: LevelBase) -> void:
	for entity: SimEntity in level.get_kind(Defs.Kind.ENEMY_PROJECTILE):
		(entity as ProjectileBase).consume()
	Sim.step(1)


## Hero standing at `spot`; a rock of `speed` leaves the jaws; the hero starts a standing jump (Up 14 ticks) `jump`
## ticks later (-1: never). Returns the tick of the hit (-1 = none).
func _rock_trial(arena: Dictionary, speed: int, spot: Vector2i, jump: int) -> Dictionary:
	var level: LevelBase = arena["level"]
	var hero: PlayerBase = arena["hero"]
	var colossus: Colossus = arena["colossus"]
	_clear_projectiles(level)
	_settle_hero(hero, spot)
	var rock: ProjectileBase = level.spawn(&"projectiles/boss_rock", colossus.sim_pos + EnemyTuning.COLOSSUS_MOUTH,
			{"xvel": -speed, "yvel": 0}) as ProjectileBase
	var hurts: int = _count(&"player_hurt")
	var result: Dictionary = {"hit": -1}
	var clock: Array[int] = [0]
	GameInput.set_scripted(func(_tick: int) -> int:
		return Defs.IN_UP if jump >= 0 and clock[0] >= jump and clock[0] < jump + 14 else 0
	)
	while clock[0] < 90 and not rock.spent:
		Sim.step(1)
		clock[0] += 1
		if _count(&"player_hurt") > hurts:
			result["hit"] = clock[0]
			break
	GameInput.clear_scripted()
	return result


func _settle_hero(hero: PlayerBase, spot: Vector2i) -> void:
	Game.hearts = Tuning.ENERGY_START
	hero.hit_timer = 0
	hero.xvel = 0
	hero.yvel = 0
	_teleport(hero, spot)
	GameInput.clear_scripted()
	Sim.step(10)


## A stalactite shaken loose over a hero standing at `spot` (it hangs under the ceiling there, as the Colossus drops
## it): when its tip reaches his head, and the ticks after it appeared on which he can still start walking away (to
## the left) and get away. Up to `last` start ticks are tried.
func _drop_trial(arena: Dictionary, spot: Vector2i, last: int = 40) -> Dictionary:
	var level: LevelBase = arena["level"]
	var hero: PlayerBase = arena["hero"]
	var colossus: Colossus = arena["colossus"]
	var hang: Vector2i = Vector2i(spot.x, colossus._ceiling_y(spot.x, 2 * Tuning.TILE) + EnemyTuning.STALACTITE_BOX.y)
	var head: int = -1
	var escape: PackedInt32Array = PackedInt32Array()
	for start: int in range(-1, last):
		_clear_projectiles(level)
		_settle_hero(hero, spot)
		var drop: ProjectileBase = level.spawn(&"projectiles/boss_stalactite", hang) as ProjectileBase
		var hurts: int = _count(&"player_hurt")
		var clock: Array[int] = [0]
		var hit: bool = false
		GameInput.set_scripted(func(_tick: int) -> int:
			return Defs.IN_LEFT if start >= 0 and clock[0] >= start else 0
		)
		while clock[0] < 70 and not drop.spent:
			Sim.step(1)
			clock[0] += 1
			if start < 0 and head < 0 and drop.sim_pos.y >= spot.y - Tuning.HERO_BOX_STAND.y:
				head = clock[0]
			if _count(&"player_hurt") > hurts:
				hit = true
				break
		GameInput.clear_scripted()
		if start >= 0 and not hit:
			escape.append(start)
		if start % 10 == 9:
			await get_tree().process_frame
	return {"head": head, "escape": escape}


func _ranges(values: PackedInt32Array) -> String:
	if values.is_empty():
		return "-"
	var parts: PackedStringArray = PackedStringArray()
	var first: int = values[0]
	var last: int = values[0]
	for i: int in range(1, values.size() + 1):
		if i < values.size() and values[i] == last + 1:
			last = values[i]
			continue
		parts.append(str(first) if first == last else "%d-%d" % [first, last])
		if i < values.size():
			first = values[i]
			last = values[i]
	return ",".join(parts)


## ARMS_REPAIR=<route file> ARMS_LEVEL=<id> ARMS_WEAPON=<n> [ARMS_REPAIR_INPUTS=<res:// file to start from>]
## [ARMS_REPAIR_DROP_STRIKES=1] [ARMS_REPAIR_FIT_STRIKES=1] [ARMS_REPAIR_DEATHS_ONLY=1] [ARMS_REPAIR_HORIZON=90]
## [ARMS_REPAIR_WINDOW=60] [ARMS_REPAIR_BRANCH=3] [ARMS_REPAIR_REF=<route file> ARMS_REPAIR_REF_WEAPON=<n>]
## [ARMS_REPAIR_REF_SHIFTS=tick:n,...] [ARMS_REPAIR_NO_SYNC=1]: replays the route with the weapon and, at the first
## hit (or death), tries local changes in the ticks before it that keep the rest of the route in step - a hop or a
## short hold in place, a switch of input moved a few ticks earlier or later, a step, a strike - and keeps the first
## one that gets the hero through the next HORIZON ticks unhurt and back onto the reference run (the club route played
## with the club; REF_SHIFTS adds the waits a re-timed route inserts); depth-first, BRANCH changes per problem, until
## the level is left. DROP_STRIKES first turns every swing into standing still, FIT_STRIKES drops the swings that do
## not fit the weapon's recovery. Writes build/arms_w4/<file>.w<weapon>. (Made w4_l1.hammer / .axe / .boomerang.)
func test_repair_route() -> void:
	assert_true(true)
	var file: String = OS.get_environment("ARMS_REPAIR")
	if file.is_empty():
		return
	var level_id: StringName = StringName(OS.get_environment("ARMS_LEVEL")) if OS.get_environment("ARMS_LEVEL") != "" \
			else StringName(file.get_slice(".", 0))
	var weapon: int = OS.get_environment("ARMS_WEAPON").to_int()
	var text: String = FileAccess.get_file_as_string(ROUTE_DIR + file)
	if OS.get_environment("ARMS_REPAIR_INPUTS") != "":
		text = FileAccess.get_file_as_string(OS.get_environment("ARMS_REPAIR_INPUTS"))
	var inputs: PackedInt32Array = Autoplay.parse_inputs(text)
	if OS.get_environment("ARMS_REPAIR_DROP_STRIKES") != "":
		for t: int in inputs.size():
			if inputs[t] & Defs.IN_FIRE:
				inputs[t] = 0
	if OS.get_environment("ARMS_REPAIR_FIT_STRIKES") != "":
		inputs = _fit_strikes(inputs, weapon)
	var deaths_only: bool = OS.get_environment("ARMS_REPAIR_DEATHS_ONLY") != ""
	# The reference: the club route played with the club (the hero's feet per tick); a change must bring him back
	# onto it.
	var ref_file: String = OS.get_environment("ARMS_REPAIR_REF") if OS.get_environment("ARMS_REPAIR_REF") != "" else file
	var ref_inputs: PackedInt32Array = Autoplay.parse_inputs(FileAccess.get_file_as_string(ROUTE_DIR + ref_file))
	var ref_run: Dictionary = await _check_replay(level_id, int(OS.get_environment("ARMS_REPAIR_REF_WEAPON").to_int()),
			ref_inputs, ref_inputs.size(), true)
	_ref_trace = ref_run["trace"]
	# ARMS_REPAIR_REF_SHIFTS="tick:n,...": the route waits n ticks more at that reference tick (a longer recovery);
	# the reference hero stands still there for n more ticks.
	var shifts: PackedStringArray = OS.get_environment("ARMS_REPAIR_REF_SHIFTS").split(",", false)
	shifts.reverse()
	for shift: String in shifts:
		var at: int = shift.get_slice(":", 0).to_int()
		for n: int in shift.get_slice(":", 1).to_int():
			_ref_trace.insert(at, _ref_trace[at])
	print("REPAIR reference %s: %d ticks, bad %d, left %s" % [ref_file, _ref_trace.size(), ref_run["bad"], ref_run["left"]])
	_repair_started = Time.get_ticks_msec()
	var fixes: PackedStringArray = PackedStringArray()
	var repaired: PackedInt32Array = await _repair_dfs(level_id, weapon, inputs, deaths_only, fixes, 0)
	if not repaired.is_empty():
		inputs = repaired
	var outcome: Dictionary = await _check_replay(level_id, weapon, inputs, inputs.size(), deaths_only)
	outcome.erase("trace")
	print("REPAIR %s weapon %d: %s; fixes: %s" % [file, weapon, str(outcome), ", ".join(fixes)])
	_write_inputs("%s.w%d" % [file, weapon], inputs, "# %s repaired for weapon %d: %s" % [file, weapon,
			", ".join(fixes)])


var _repair_started: int = 0


## Depth-first repair: at the first hit (or death) try the changes of _repair_at one after the other; for each that
## gets past it, repair the rest; give up on a branch after ARMS_REPAIR_BRANCH (3) changes that led nowhere.
func _repair_dfs(level_id: StringName, weapon: int, inputs: PackedInt32Array, deaths_only: bool,
		fixes: PackedStringArray, depth: int) -> PackedInt32Array:
	var outcome: Dictionary = await _check_replay(level_id, weapon, inputs, inputs.size(), deaths_only)
	print("REPAIR depth %d: bad %d (%s) left %s, %d ticks, %d s" % [depth, outcome["bad"], outcome["kind"],
		outcome["left"], outcome["played"], (Time.get_ticks_msec() - _repair_started) / 1000])
	if int(outcome["bad"]) < 0:
		return inputs if bool(outcome["left"]) else PackedInt32Array()
	if depth >= 12:
		return PackedInt32Array()
	var branch: int = OS.get_environment("ARMS_REPAIR_BRANCH").to_int() if OS.get_environment("ARMS_REPAIR_BRANCH") != "" else 3
	var skip: int = 0
	for attempt: int in branch:
		var fixed: Dictionary = await _repair_at(level_id, weapon, inputs, int(outcome["bad"]), deaths_only, skip)
		if (fixed["inputs"] as PackedInt32Array).is_empty():
			break
		skip = int(fixed["index"]) + 1
		print("  depth %d fix %s" % [depth, fixed["what"]])
		fixes.append(str(fixed["what"]))
		var rest: PackedInt32Array = await _repair_dfs(level_id, weapon, fixed["inputs"], deaths_only, fixes, depth + 1)
		if not rest.is_empty():
			return rest
		fixes.remove_at(fixes.size() - 1)
	return PackedInt32Array()


## Fresh start of `level_id` with `weapon`, play `inputs` up to `until` ticks: the first tick on which the hero was
## hurt (or died), whether the level was left, and the run's numbers.
func _check_replay(level_id: StringName, weapon: int, inputs: PackedInt32Array, until: int,
		deaths_only: bool = false) -> Dictionary:
	after_each()
	await _start(level_id, weapon)
	var level: LevelBase = Game.level
	var index: Array[int] = [0]
	GameInput.set_scripted(func(_tick: int) -> int:
		var value: int = inputs[index[0]] if index[0] < inputs.size() else 0
		index[0] += 1
		return value
	)
	var result: Dictionary = {"bad": -1, "kind": "", "left": false, "played": 0}
	var played: int = 0
	var lives: int = Game.lives
	var trace: PackedVector2Array = PackedVector2Array()
	while played < until and Sim.running and Game.level == level:
		var hurts: int = _count(&"player_hurt")
		var deaths: int = _count(&"player_died")
		Sim.step(1)
		played += 1
		if Game.level == level and level.player != null:
			trace.append(Vector2(level.player.sim_pos))
		if _count(&"player_died") > deaths:
			result["bad"] = played - 1
			result["kind"] = "died"
			break
		if not deaths_only and _count(&"player_hurt") > hurts:
			result["bad"] = played - 1
			result["kind"] = "hurt"
			break
		if not _exit_kinds.is_empty():
			result["left"] = true
			break
	GameInput.clear_scripted()
	result["played"] = played
	result["trace"] = trace
	result["lives"] = Game.lives - lives
	result["hurts"] = _count(&"player_hurt")
	result["score"] = Game.score
	result["exits"] = _exit_kinds.duplicate()
	return result


## Local changes before tick `bad` that keep the route's length: first hops and short holds in place, then a switch
## of input moved by a few ticks, then longer overwrites (a step, a strike). The first that gets the hero through
## the next ARMS_REPAIR_HORIZON (90) ticks without a hit (or death) and back onto the reference run wins.
func _repair_at(level_id: StringName, weapon: int, inputs: PackedInt32Array, bad: int, deaths_only: bool,
		skip: int = 0) -> Dictionary:
	var horizon: int = OS.get_environment("ARMS_REPAIR_HORIZON").to_int() if OS.get_environment("ARMS_REPAIR_HORIZON") != "" else 90
	var window: int = OS.get_environment("ARMS_REPAIR_WINDOW").to_int() if OS.get_environment("ARMS_REPAIR_WINDOW") != "" else 60
	var until: int = mini(inputs.size(), bad + horizon)
	var runs: Array[Vector3i] = _runs(inputs)
	var tries: Array[int] = [0]
	var candidates: Array = []
	# 1. Hops and holds in place.
	for back: int in range(1, mini(window, 40) + 1):
		for plan: Array in [["U", 4], ["U", 8], ["U", 12], ["", 3], ["", 6]]:
			candidates.append(["o", bad - back, plan[0], plan[1]])
	# 2. A switch of input moved by d ticks.
	for d: int in [1, -1, 2, -2, 3, -3, 4, -4, 6, -6, 8, -8]:
		for k: int in range(runs.size() - 1, 0, -1):
			if runs[k].x <= bad + 2 and runs[k].x >= bad - window:
				candidates.append(["s", k, d, 0])
	# 3. Longer overwrites.
	for back: int in range(1, window + 1):
		for plan: Array in [["L", 4], ["R", 4], ["U", 16], ["F", 8], ["UF", 10], ["DF", 10], ["", 10], ["L", 8],
				["R", 8], ["LU", 8], ["RU", 8]]:
			candidates.append(["o", bad - back, plan[0], plan[1]])
	for d: int in [10, -10, 13, -13, 16, -16]:
		for k: int in range(runs.size() - 1, 0, -1):
			if runs[k].x <= bad + 2 and runs[k].x >= bad - window:
				candidates.append(["s", k, d, 0])
	for index: int in range(skip, candidates.size()):
		var c: Array = candidates[index]
		var candidate: PackedInt32Array = inputs.duplicate()
		var what: String = ""
		if c[0] == "o":
			var at: int = int(c[1])
			if at < 0:
				continue
			var value: int = GameInput.keys_to_flags(str(c[2]))
			for n: int in int(c[3]):
				if at + n < candidate.size():
					candidate[at + n] = value
			what = "%d x %s at %d" % [c[3], c[2], at]
		else:
			var k: int = int(c[1])
			var d: int = int(c[2])
			if runs[k - 1].y + d < 1 or runs[k].y - d < 1:
				continue
			var start: int = runs[k].x
			for t: int in range(mini(start, start + d), maxi(start, start + d)):
				candidate[t] = runs[k - 1].z if d > 0 else runs[k].z
			what = "switch at %d %+d" % [start, d]
		if candidate == inputs:
			continue
		tries[0] += 1
		var check: Dictionary = await _check_replay(level_id, weapon, candidate, until, deaths_only)
		if int(check["bad"]) < 0 and _back_on_reference(check["trace"], until - 8, until):
			return {"inputs": candidate, "what": "t%d: %s (%d tries)" % [bad, what, tries[0]], "index": index}
	return {"inputs": PackedInt32Array(), "what": "", "index": -1}


var _ref_trace: PackedVector2Array = PackedVector2Array()


## True when the hero stands where the reference run has him on some tick of [from, to): the change put him back in
## step with the route.
func _back_on_reference(trace: PackedVector2Array, from: int, to: int) -> bool:
	if _ref_trace.is_empty() or OS.get_environment("ARMS_REPAIR_NO_SYNC") != "":
		return true
	if trace.size() < to or _ref_trace.size() < to:
		return trace.size() >= _ref_trace.size()
	for t: int in range(maxi(from, 0), to):
		if absf(trace[t].x - _ref_trace[t].x) > 6.0 or trace[t].y != _ref_trace[t].y:
			return false
	return true


## Drop the swings that do not fit the weapon's recovery: one that starts while the previous swing still locks the
## input, and one whose own recovery would swallow inputs that move the hero (they would put him out of step). A
## swing completes after 7 ticks of Fire (9 with Up or Down) and then locks the input for Tuning.WEAPON_LOCK ticks.
func _fit_strikes(flags: PackedInt32Array, weapon: int) -> PackedInt32Array:
	var out: PackedInt32Array = flags.duplicate()
	var lock_end: int = -1
	var t: int = 0
	while t < out.size():
		if (out[t] & Defs.IN_FIRE) == 0:
			t += 1
			continue
		var run_end: int = t
		while run_end < out.size() and out[run_end] == out[t]:
			run_end += 1
		var need: int = 9 if (out[t] & (Defs.IN_UP | Defs.IN_DOWN)) != 0 else 7
		var keep: bool = t > lock_end and run_end - t >= need
		if keep:
			var done: int = t + need - 1
			for u: int in range(maxi(run_end, done + 1), mini(done + 1 + Tuning.WEAPON_LOCK[weapon], out.size())):
				if out[u] != 0 and (out[u] & Defs.IN_FIRE) == 0:
					keep = false
			if keep:
				lock_end = done + Tuning.WEAPON_LOCK[weapon]
		if not keep:
			for u: int in range(t, run_end):
				out[u] = 0
		t = run_end
	return out


func _runs(flags: PackedInt32Array) -> Array[Vector3i]:
	var runs: Array[Vector3i] = []
	for t: int in flags.size():
		if runs.is_empty() or runs[-1].z != flags[t]:
			runs.append(Vector3i(t, 1, flags[t]))
		else:
			runs[-1].y += 1
	return runs


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
	_connect(Game.letters_completed, _on_word)


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


func _on_word() -> void:
	_words += 1


func _hero_text() -> String:
	var level: LevelBase = Game.level
	if level == null or level.player == null:
		return "(no hero)"
	var hero: PlayerBase = level.player
	return "x%5d y%5d c%3d r%3d st%d v(%d,%d) h%d w%d%s" % [hero.sim_pos.x, hero.sim_pos.y, hero.sim_pos.x >> 4,
		(hero.sim_pos.y - 1) >> 4, hero.state, hero.xvel, hero.yvel, Game.hearts, Game.weapon,
		" DEAD" if hero.dead else ""]


# =================================================================================================================
# 2.0: the co-op visor Colossus (enemies-C, PLAN.md P2.3; DESIGN.md B.7) - fairness per hero
# =================================================================================================================
# A hall of 20 air columns (floor row 10, feet y 160) with the statue's wall from column 20 and two plates: the left
# one at columns 3-4, the right one at columns 12-13. P1 (slot 0) and P2 (slot 1) are bare heroes (they never move by
# themselves); the game is a co-op game and the level a co-op file unless a test says otherwise.

const COOP_PLAYER_SCENE: String = "res://scenes/player/player.tscn"
const PLATE_LEFT_X: int = 3 * 16 + 8
const PLATE_RIGHT_X: int = 12 * 16 + 8

var _hall: LevelBase = null
var _p1: PlayerBase = null
var _p2: PlayerBase = null


func test_coop_visor_only_in_a_coop_game_of_two_on_a_coop_file() -> void:
	if _aid_running():
		assert_true(true, "skipped while a route-building aid runs")
		return
	var colossus: Colossus = _visor_hall(true, true)
	assert_true(colossus.is_coop_form())
	assert_eq(colossus.max_hp, 30, "24 -> 30 (x5/4)")
	assert_eq(colossus.get_plates().size(), 2, "the hall's two plates")
	assert_eq(colossus.get_live_plate(), colossus.get_plates()[0], "the left chain glows first")
	_coop_teardown()
	var solo_file: Colossus = _visor_hall(true, false)
	assert_false(solo_file.is_coop_form(), "a co-op game on a solo file: the 1.0 statue")
	assert_eq(solo_file.max_hp, 24)
	_coop_teardown()
	var alone: Colossus = _visor_hall(false, true)
	assert_false(alone.is_coop_form(), "a party of one: the 1.0 statue")
	assert_false(alone.is_visor_up())
	_coop_teardown()


func test_coop_the_plate_holder_lifts_the_visor_and_only_the_other_hero_hurts_it() -> void:
	if _aid_running():
		assert_true(true, "skipped while a route-building aid runs")
		return
	var colossus: Colossus = _visor_hall(true, true)
	_p1.teleport(Vector2i(160, 160))
	_p2.teleport(Vector2i(100, 160))
	Sim.step(2)
	assert_false(colossus.is_visor_up(), "nobody on the glowing plate: the visor is down")
	_head_shot(colossus, 1)
	Sim.step(1)
	assert_eq(colossus.hp, 30, "a throw glances off the visor")
	_p1.teleport(Vector2i(PLATE_LEFT_X, 160))
	Sim.step(2)
	assert_true(colossus.is_visor_up(), "P1 on the glowing plate lifts it")
	_head_shot(colossus, 0)
	Sim.step(1)
	assert_eq(colossus.hp, 30, "the holder's own throw does not count")
	_head_shot(colossus, 1)
	Sim.step(1)
	assert_eq(colossus.hp, 29, "P2's throw counts one")
	assert_eq(colossus.last_hitter, _p2)
	_coop_teardown()


func test_coop_every_rage_moves_the_live_chain_and_the_roles_swap() -> void:
	if _aid_running():
		assert_true(true, "skipped while a route-building aid runs")
		return
	var colossus: Colossus = _visor_hall(true, true)
	_p1.teleport(Vector2i(PLATE_LEFT_X, 160))
	_p2.teleport(Vector2i(160, 160))
	Sim.step(2)
	_head_shot(colossus, 1)
	Sim.step(1)
	assert_eq(colossus.get_hits(), 1)
	assert_eq(colossus.get_live_plate(), colossus.get_plates()[1], "the 1st hit's rage: the right chain glows")
	Sim.step(2)
	assert_false(colossus.is_visor_up(), "P1 on the old plate holds nothing now")
	_p2.teleport(Vector2i(PLATE_RIGHT_X, 160))
	_p1.teleport(Vector2i(100, 160))
	Sim.step(2)
	assert_true(colossus.is_visor_up(), "P2 holds the new one: the roles swapped")
	_coop_teardown()


## Fairness per hero (test_colossus_rocks_can_be_jumped / _stalactites_can_be_escaped hold for the 1.0 rock speeds
## and drops; the co-op form only aims them): whichever hero holds the plate, the open jaws show 10+ ticks before the
## rock leaves, the rock's speed is one of the 1.0 speeds aimed at him, and the drop rattles 14 ticks over the other.
func test_coop_rocks_go_for_the_holder_and_drops_for_the_thrower_whoever_they_are() -> void:
	if _aid_running():
		assert_true(true, "skipped while a route-building aid runs")
		return
	for holder_slot: int in 2:
		var colossus: Colossus = _visor_hall(true, true)
		var holder: PlayerBase = _p1 if holder_slot == 0 else _p2
		var thrower: PlayerBase = _p2 if holder_slot == 0 else _p1
		holder.teleport(Vector2i(PLATE_LEFT_X, 160))
		thrower.teleport(Vector2i(150, 160))
		var jaws: int = -1
		var rock: SimEntity = null
		var drop: SimEntity = null
		var drop_seen: int = -1
		var rock_speed: int = 0
		for tick: int in 260:
			Sim.step(1)
			for hero: PlayerBase in [_p1, _p2]:
				hero.hit_timer = 0
				hero.run.hearts = Tuning.ENERGY_START
			if jaws < 0 and colossus.get_state() == Colossus.State.SPIT:
				jaws = tick
			if rock == null:
				for entity: SimEntity in _hall.get_kind(Defs.Kind.ENEMY_PROJECTILE):
					if entity is BossRock:
						rock = entity
						rock_speed = -rock.xvel
						assert_true(tick - jaws >= 10, "slot %d holds: the jaws open 10+ ticks ahead" % holder_slot)
			if drop == null:
				for entity: SimEntity in _hall.get_kind(Defs.Kind.ENEMY_PROJECTILE):
					if entity is BossStalactite:
						drop = entity
						drop_seen = tick
			if rock != null and drop != null:
				break
		assert_not_null(rock, "slot %d: a rock" % holder_slot)
		assert_not_null(drop, "slot %d: a drop" % holder_slot)
		if rock == null or drop == null:
			_coop_teardown()
			return
		var mouth_x: int = colossus.sim_pos.x + EnemyTuning.COLOSSUS_MOUTH.x
		assert_eq(rock_speed, Colossus._aimed_speed(mouth_x - holder.sim_pos.x), "aimed at the holder")
		assert_true(rock_speed >= EnemyTuning.ROCK_XVEL_MIN and rock_speed <= 96, "a 1.0 rock speed")
		assert_eq(drop.sim_pos.x, thrower.sim_pos.x, "the drop rattles over the thrower")
		assert_true((drop as BossStalactite).is_warning(), "rattling first")
		var fell: int = -1
		for tick: int in 40:
			Sim.step(1)
			if not (drop as BossStalactite).is_warning():
				fell = tick + 1
				break
		assert_true(fell + 1 >= EnemyTuning.STALACTITE_WARN_TICKS - 1, "slot %d: 14 ticks of rattle (%d)" % [
			holder_slot, fell])
		assert_true(drop_seen >= 0)
		_coop_teardown()


## V3.d: one hero cannot beat the visor. The real hero with two axes (the co-op checkpoint's), his partner an egg:
## throwing from the glowing plate, from the floor right after stepping off it, and seeded random play - nothing counts.
func test_coop_the_single_hero_search_cannot_hurt_the_visor_colossus() -> void:
	if _aid_running():
		assert_true(true, "skipped while a route-building aid runs")
		return
	var colossus: Colossus = _visor_hall(true, true, true)
	_p2.down = true
	var rng: SimRng = SimRng.new(5)
	for weapon: int in [AXE, BOOMERANG, Defs.Weapon.SPEAR]:
		for start: int in [PLATE_LEFT_X, PLATE_LEFT_X + 8, PLATE_RIGHT_X, 120, 170, 210]:
			_coop_episode(_p1, weapon, Vector2i(start, 160), _throw_and_step(start))
			_coop_episode(_p1, weapon, Vector2i(start, 160), _coop_random(rng, 120))
			assert_eq(colossus.hp, 30, "weapon %d from x %d: nothing counts" % [weapon, start])
	assert_false(colossus.dead)
	_coop_teardown()


## The hall of the section header with the Colossus; `coop_game`: a co-op game of two (else a party of one); `coop_file`:
## the level is a co-op file; `real_p1`: P1 is the real hero.
func _visor_hall(coop_game: bool, coop_file: bool, real_p1: bool = false) -> Colossus:
	if coop_game:
		Game.start_run(Defs.Difficulty.EXPERT, Defs.GameMode.COOP, 2)
	else:
		Game.new_game(Defs.Difficulty.EXPERT)
	Game.begin_level(&"test")
	Sim.rng.reseed(11)
	var rows: PackedStringArray = PackedStringArray()
	for row: int in 10:
		rows.append(".".repeat(20) + "#".repeat(10))
	rows.append("#".repeat(30))
	rows.append("#".repeat(30))
	_hall = make_level(rows)
	if coop_file:
		_hall.meta["kind"] = "coop"
	for x: int in [PLATE_LEFT_X, PLATE_RIGHT_X]:
		var plate: SimEntity = Spawner.instantiate(&"objects/plate") as SimEntity
		place(_hall, plate, Vector2i(x, 160), {"w": 2})
	if real_p1:
		_p1 = (load(COOP_PLAYER_SCENE) as PackedScene).instantiate() as PlayerBase
	else:
		_p1 = PlayerBase.new()
	place(_hall, _p1, Vector2i(100, 160), {"slot": 0})
	_p1.respawn_at(Vector2i(100, 160))
	_p2 = null
	if coop_game:
		_p2 = PlayerBase.new()
		place(_hall, _p2, Vector2i(130, 160), {"slot": 1})
		_p2.respawn_at(Vector2i(130, 160))
	var colossus: Colossus = Spawner.instantiate(&"bosses/colossus") as Colossus
	place(_hall, colossus, Vector2i(19 * Tuning.TILE + 8, 160))
	colossus.start_fight()
	Sim.step(1)
	return colossus


func _coop_teardown() -> void:
	GameInput.clear_scripted()
	if _hall != null and is_instance_valid(_hall):
		_hall.free()
	_hall = null
	Game.new_game(Defs.Difficulty.BEGINNER)
	Game.begin_level(&"")


## A thrown weapon of the hero of `owner` on the Colossus' head.
func _head_shot(colossus: Colossus, owner: int) -> void:
	var head: Rect2i = colossus.get_head_rect()
	var shot: ProjectileBase = ProjectileBase.new()
	place(_hall, shot, Vector2i(head.get_center().x, head.end.y), {"from_hero": true, "power": 20, "owner": owner})


## Face the statue and throw high (Up + Fire), then walk off toward it and throw again.
func _throw_and_step(_start: int) -> PackedInt32Array:
	var flags: PackedInt32Array = PackedInt32Array()
	flags.append(Defs.IN_RIGHT)
	for i: int in 3:
		flags.append(Defs.IN_FIRE | Defs.IN_UP)
	for i: int in 10:
		flags.append(0)
	for i: int in 6:
		flags.append(Defs.IN_RIGHT)
	for i: int in 3:
		flags.append(Defs.IN_FIRE | Defs.IN_UP)
	for i: int in 30:
		flags.append(0)
	return flags


func _coop_random(rng: SimRng, ticks: int) -> PackedInt32Array:
	var flags: PackedInt32Array = PackedInt32Array()
	var keys: Array[int] = [0, Defs.IN_LEFT, Defs.IN_RIGHT, Defs.IN_UP, Defs.IN_FIRE, Defs.IN_UP | Defs.IN_FIRE,
			Defs.IN_FIRE | Defs.IN_RIGHT, Defs.IN_UP | Defs.IN_RIGHT, Defs.IN_UP | Defs.IN_FIRE | Defs.IN_RIGHT]
	var held: int = 0
	var left: int = 0
	for tick: int in ticks:
		if left <= 0:
			held = keys[rng.next_int(keys.size())]
			left = rng.range_int(2, 12)
		left -= 1
		flags.append(held)
	return flags


func _coop_episode(hero: PlayerBase, weapon: int, pos: Vector2i, flags: PackedInt32Array) -> void:
	hero.respawn_at(pos)
	hero.run.set_weapon(weapon)
	var first: int = Sim.tick + 1
	GameInput.set_scripted_slot(0, func(tick: int) -> int:
		var index: int = tick - first
		return flags[index] if index >= 0 and index < flags.size() else 0
	)
	for tick: int in flags.size():
		Sim.step(1)
		hero.run.hearts = Tuning.ENERGY_START
		hero.hit_timer = mini(hero.hit_timer, 1)
		if hero.dead or hero.is_down():
			hero.respawn_at(pos)
	GameInput.clear_scripted()
