extends Node
## A clean replay of ONE route file (harness.gd: tools/coop_explore/evidence/*.txt, an explorer's found_*.txt) in this
## fresh process - in the solo search's own world, or in the real game for a file that says real=true - with what
## happened on the way, so the cause can be named. The G3b verifier's replay.gd, adopted in wf11 (R7 (b): a gate is
## closed only when every route of the evidence set says "not reached").
## Usage: bash .tools/gd.sh script res://tools/coop_explore/main.gd -- replay <route file> [trace=<every n ticks>]
##        [fine=<from>-<to>] [noevents=1] [cache=1]
## A real=true route file may say `checkpoint=<column>` (the run's checkpoint, default: the last one before the
## tablet) and `kit=<mask>` (a feast kit carried into the stage): what a real player brings to a gate.
##   trace=   a line every n ticks: the hero, the awake enemies and the movers near him, the partner
##   fine=    ... and every tick of this range
##   cache=1  keep the result for the gate test (harness.gd replay_key)
## Prints `REPLAY <level> d<difficulty> <gate>: REACHED the far cell | DIED | not reached at tick <t> ...`; the exit
## code is 0 whatever the route did (1: the file cannot be read or the world cannot be built).

const HARNESS: String = "res://tools/coop_explore/harness.gd"
const REAL_HARNESS: String = "res://tools/coop_explore/real_harness.gd"


func run(arguments: PackedStringArray) -> int:
	if arguments.is_empty():
		print("REPLAY: want a route file")
		return 1
	var path: String = arguments[0]
	var every: int = 0
	var no_events: bool = false
	var keep: bool = false
	var fine_from: int = 1 << 30
	var fine_to: int = -1
	for i: int in range(1, arguments.size()):
		if arguments[i].begins_with("trace="):
			every = arguments[i].get_slice("=", 1).to_int()
		elif arguments[i] == "noevents=1":
			no_events = true
		elif arguments[i] == "cache=1":
			keep = true
		elif arguments[i].begins_with("fine="):
			fine_from = arguments[i].get_slice("=", 1).get_slice("-", 0).to_int()
			fine_to = arguments[i].get_slice("=", 1).get_slice("-", 1).to_int()
	var harness: GDScript = load(HARNESS) as GDScript
	var route: Dictionary = harness.call(&"read_route", path)
	if route.is_empty():
		print("REPLAY %s: not a route file" % path)
		return 1
	var level: StringName = route["level"]
	var gate: String = str(route["gate"])
	var difficulty: int = int(route["difficulty"])
	var real: bool = bool(route["real"])
	var lib: RefCounted = null
	var built: bool = false
	if real:
		lib = (load(REAL_HARNESS) as GDScript).new()
		built = await lib.build(self, level, gate, difficulty)
		lib.tick_offset = int(route["tickoff"])
		if built and int(route["checkpoint"]) >= 0:
			built = lib.use_checkpoint(int(route["checkpoint"]))
		lib.kit = int(route["kit"])
	else:
		lib = harness.new()
		built = lib.build(level, gate, difficulty, bool(route["whole"]), int(route["tick0"]))
	if not built:
		print("REPLAY %s d%d %s: cannot build the world" % [level, difficulty, gate])
		return 1
	var events: Array = [] if no_events else (route["events"] as Array)
	var flags: PackedInt32Array = route["flags"]
	var start: Vector2i = lib.starts[clampi(int(route["start"]), 0, lib.starts.size() - 1)]
	await lib.begin(start, 1)
	var hero: PlayerBase = lib.hero()
	var next_event: int = 0
	var end: String = ""
	var last_bounces: int = 0
	var last_hurts: int = 0
	print("REPLAY %s d%d %s start %s far %s, %d ticks, %d event(s)%s%s" % [level, difficulty, gate, str(start),
		str(lib.far), flags.size(), events.size(), " (events left out)" if no_events else "",
		" REAL GAME" if real else ""])
	for i: int in flags.size():
		while next_event < events.size() and int(events[next_event][0]) <= i:
			var event: Array = events[next_event]
			if str(event[1]) == "hand":
				lib.set_hand(int(event[2]))
			elif str(event[1]) == "place":
				lib.place_partner()
			if every > 0:
				print("    t%d event %s (hero at %s)" % [i, str(event), str(hero.sim_pos)])
			next_event += 1
		end = lib.step(flags[i])
		if lib.bounces != last_bounces:
			last_bounces = lib.bounces
			print("    t%d HEAD BOUNCE %d: hero at %s (row %.1f), yvel %d" % [lib.t, lib.bounces, str(hero.sim_pos),
				hero.sim_pos.y / 16.0, hero.yvel])
		if lib.hurts != last_hurts:
			last_hurts = lib.hurts
			print("    t%d hurt %d: hero at %s" % [lib.t, lib.hurts, str(hero.sim_pos)])
		if every > 0 and (lib.t % every == 0 or (lib.t >= fine_from and lib.t <= fine_to)):
			_trace(lib, hero, flags[i])
		if end != "":
			break
	var outcome: String = "REACHED the far cell" if end == "goal" else ("DIED" if end == "dead" else "not reached")
	print("REPLAY %s d%d %s: %s at tick %d; hero at %s (cell %d,%d); highest feet y %d (row %.1f); %d head bounce(s), %d hurt(s)" % [
		level, difficulty, gate, outcome, lib.t, str(hero.sim_pos), hero.sim_pos.x >> 4, (hero.sim_pos.y - 1) >> 4,
		lib.min_y, lib.min_y / 16.0, lib.bounces, lib.hurts])
	if lib.get("left_stage") == true:
		print("REPLAY note: the run ended because the STAGE WAS LEFT (screen %s, level %s) - a warp or an exit, not a death" % [
			str(Flow.current_screen), str(Game.level_id)])
	if keep:
		harness.call(&"cache_write", harness.call(&"replay_key", path), {"route": path.get_file(),
			"level": String(level), "gate": gate, "difficulty": difficulty, "reached": end == "goal",
			"outcome": outcome, "ticks": lib.t, "real": real})
	lib.close()
	return 0


func _trace(lib: RefCounted, hero: PlayerBase, flag: int) -> void:
	var near: String = ""
	for entity: SimEntity in lib.s.level.get_kind(Defs.Kind.ENEMY):
		var enemy: EnemyBase = entity as EnemyBase
		if enemy != null and enemy.awake and not enemy.dead and absi(enemy.sim_pos.x - hero.sim_pos.x) < 200:
			near += " %s@%s" % [String((enemy.get_script() as Script).resource_path).get_file().get_basename(),
				str(enemy.sim_pos)]
	for kind: int in [Defs.Kind.PLATFORM, Defs.Kind.HITTABLE]:
		for entity: SimEntity in lib.s.level.get_kind(kind):
			if absi(entity.sim_pos.x - hero.sim_pos.x) < 140 and absi(entity.sim_pos.y - hero.sim_pos.y) < 200:
				near += " %s[%s]" % [String((entity.get_script() as Script).resource_path).get_file().get_basename(),
					CoopSearch.probe(entity).left(60)]
	near += " state %d plat %s" % [hero.state, str(hero.on_platform)]
	var mate: PlayerBase = lib.s.partner
	print("    t%d hero %s (cell %d,%d) yv %d ground %s keys %s |%s | partner %s %s" % [lib.t, str(hero.sim_pos),
		hero.sim_pos.x >> 4, (hero.sim_pos.y - 1) >> 4, hero.yvel, str(hero.is_grounded()), lib.keys(flag), near,
		str(mate.sim_pos) if mate != null else "-",
		"-" if mate == null else ("egg" if mate.is_down() else ("idle" if mate.is_idle() else "ACTIVE"))])
