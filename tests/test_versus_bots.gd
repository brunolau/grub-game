extends TestCase
## PLAN.md 8 V4.b - the versus bots on every arena (slow module: tests/run_tests.gd SLOW_FILES; run it with
## `GD_TIMEOUT=1800 bash .tools/gd.sh test versus_bots`). Owner: core-B (PLAN.md P2.5).
##
## For every (arena, supported launch mode) - every levels/arena_*.lvl with the launch modes of its `modes`, world-B's
## test arenas (levels/test_world_arena_flat.lvl: Grub Stack, Last Caveman Standing, Hot Rock; the Totem Ring copy
## levels/test_world_arena_ring.lvl) and, until DA's Coconut Cove exists, a Clubball pitch of this file - Hunter
## HeroBots fill every seat (four where the arena takes four) and play the seeded set: one match of a full spawn
## rotation per seed (round r puts slot s on spawn s + r, VersusReferee.begin_round; SEEDS on a shipped arena,
## TEST_ARENA_SEEDS of them on the others), through world-B's referee and the real heroes, the bots fed through
## GameInput's BOT slots exactly as Flow does (HeroBot.new per seat, reset_round with the round seed). Checked:
##  - every round ends by the mode's own rule (the gong, the last one standing, five goals), within ROUND_LIMIT_TICKS;
##  - no bot stands idle more than VersusTuning.BOT_IDLE_MAX_TICKS (10 s) while it is in play;
##  - no hit and no stomp lands on a hero within VersusTuning.SPAWN_SHIELD_TICKS of his spawn (the round start, a
##    respawn, a Clubball kick-off);
##  - on a shipped arena (levels/arena_*.lvl), the win rate per spawn point is within
##    VersusTuning.BOT_WIN_RATE_SPREAD_PERCENT points of the fair share (the test arenas print theirs);
##  - a match log replays identically: the first round of each set is played again from the same start with the
##    bots' recorded flags as plain scripted input (no bot) and gives the same digest on every tick.
## Each set prints one line (rounds, ticks, wins per spawn with the mean score, links played / failed) for the arena
## designers. Also here (too slow for the quick tests): the rider movers of the arena kit - a see-saw's two ends and a
## pulley's two lifts - bake as mover nodes whose every link verifies.

const LEVEL_SCENE: String = "res://scenes/world/level.tscn"
const LEVEL_DIR: String = "res://levels"
const TEST_ARENAS: PackedStringArray = ["res://levels/test_world_arena_flat.lvl", "res://levels/test_world_arena_ring.lvl"]
const LAUNCH_MODES: Array[int] = [Defs.VersusMode.GRUB_STACK, Defs.VersusMode.LAST_CAVEMAN, Defs.VersusMode.HOT_ROCK,
		Defs.VersusMode.CLUBBALL]
## The seeded set of a shipped arena: one match (a full spawn rotation) per seed - 48 rounds on a 4-player arena, so
## that a fair spawn stays inside the +/-15 points with a margin of about 2.4 standard deviations.
const SEEDS: PackedInt32Array = [11, 23, 37, 41, 53, 67, 71, 89, 97, 101, 113, 127]
## The test arenas (rules, not balance) play the first seeds only.
const TEST_ARENA_SEEDS: int = 2
## A round that has not ended by the mode's rule after its clock (or this long without one) fails the check.
const ROUND_LIMIT_TICKS: int = 5200
## The Clubball stand-in for Coconut Cove (DESIGN.md E.5 sketch, walls of '#'): goal mouths 3 rows high at both ends
## (the referee's sketch mouths, VersusClubball.goal_zones), a lob bridge, two low ledges, the coconut's drop point.
const PITCH: String = """[meta]
format = 2
id = test_versus_bots_pitch
kind = arena
players = 4
modes = clubball
biome = coast
wrap = none
[legend]
B = objects/spawn_point index=2
C = objects/spawn_point index=3
D = objects/spawn_point index=4
[tiles]
....................
....................
....................
....................
##....--------....##
##................##
###..............###
......--....--......
....................
.@..C..........D..B.
####################
####################
[entities]
objects/coconut 9 9 dx=8
"""
const PITCH_ID: StringName = &"test_versus_bots_pitch"

## The rider movers of Floe Rink and Tar Pulleys (DESIGN.md E.5) in one room: a see-saw (two plank ends, each a mover
## part) on the floor and two ride platforms hanging from a pulley beside two side ledges. Its graph must have every
## part as a rider mover node and every link verified (a bake of about half a minute: here, not in the quick tests).
const MOVERS_ROOM: String = """[meta]
format = 2
id = test_core_bots_seesaw
kind = arena
players = 2
modes = last_caveman
biome = jungle
[legend]
S = objects/seesaw len=5
P = objects/platform name=pa mode=ride
Q = objects/platform name=pb mode=ride
W = objects/pulley a=pa b=pb range=3
[tiles]
|..................|
|..................|
|..................|
|.........W........|
|..................|
|..................|
|##.P......Q...####|
|..................|
|..................|
|.@.......S......B.|
####################
####################
[entities]
"""

## Graphs baked in this run (level id -> JSON text), so that each arena is baked at most once.
static var _baked: Dictionary = {}

var _level: Level = null


func before_each() -> void:
	Game.new_game(Defs.Difficulty.BEGINNER)
	NavGraph.clear_cache()
	_level = null


func after_each() -> void:
	_free_level()
	GameInput.clear_scripted()
	GameInput.reset_slots()
	NavGraph.clear_cache()
	BotBrain.clear_cache()
	Sim.stop()
	Game.new_game(Defs.Difficulty.BEGINNER)


func test_hunter_bots_play_every_arena_and_mode() -> void:
	var arenas: Array[Dictionary] = _arenas()
	assert_true(not arenas.is_empty(), "arenas to play")
	var sets: int = 0
	for arena: Dictionary in arenas:
		for mode: int in arena["modes"]:
			_play_set(arena, mode)
			sets += 1
	assert_true(sets >= 4, "%d (arena, mode) sets" % sets)


func test_see_saw_and_pulley_lifts_bake_as_verified_rider_movers() -> void:
	var graph: NavGraph = NavBaker.new().bake_text(self, &"test_core_bots_seesaw", MOVERS_ROOM)
	assert_not_null(graph)
	if graph == null:
		return
	var parts: Dictionary = {}
	for mover: Dictionary in graph.movers:
		assert_eq(StringName(str(mover["kind"])), NavGraph.MOVER_RIDER, "%s moves under its riders" % mover["key"])
		parts[str(mover["id"])] = int(parts.get(str(mover["id"]), 0)) + 1
	assert_eq(int(parts.get("objects/seesaw", 0)), 2, "both plank ends of the see-saw (%s)" % [parts])
	assert_eq(int(parts.get("objects/platform", 0)), 2, "both pulley lifts (%s)" % [parts])
	var onto: int = 0
	var off: int = 0
	for link: NavGraph.NavLink in graph.links:
		if not link.cond.is_empty():
			if graph.nodes[link.to].mover >= 0 and graph.nodes[link.from].mover < 0:
				onto += 1
			elif graph.nodes[link.from].mover >= 0:
				off += 1
	assert_true(onto >= 2 and off >= 4, "links onto (%d) and off (%d) the movers" % [onto, off])
	var baker: NavBaker = NavBaker.new()
	var data: LevelData = LevelData.parse(graph.level_id, MOVERS_ROOM)
	assert_true(baker.sim.setup(self, graph.level_id, data.build_grid(0), data.resolved_meta(0), data.entity_records()))
	var problems: PackedStringArray = baker.verify_graph(graph)
	baker.sim.teardown()
	assert_eq(problems.size(), 0, "; ".join(problems))


# =================================================================================================================
# One (arena, mode) set
# =================================================================================================================

func _play_set(arena: Dictionary, mode: int) -> void:
	var name: String = "%s/%s" % [arena["id"], Defs.VERSUS_MODE_NAMES[mode]]
	var players: int = int(arena["players"])
	var spawn_count: int = 0
	var wins: PackedFloat32Array = PackedFloat32Array()
	wins.resize(Defs.MAX_PLAYERS)
	wins.fill(0.0)
	var rounds: int = 0
	var ticks: int = 0
	var scores: PackedInt32Array = PackedInt32Array()
	scores.resize(Defs.MAX_PLAYERS)
	var worst_idle: int = 0
	var spawn_hits: Array[String] = []
	var unfinished: Array[String] = []
	var played: int = 0
	var failed: int = 0
	var failures: PackedStringArray = PackedStringArray()
	var started_msec: int = Time.get_ticks_msec()
	var seeds: PackedInt32Array = SEEDS if bool(arena["shipped"]) else SEEDS.slice(0, TEST_ARENA_SEEDS)
	for seed_value: int in seeds:
		var bots: Array[HeroBot] = []
		for slot: int in players:
			bots.append(HeroBot.new(slot, Defs.BotLevel.HUNTER, seed_value, mode))
		for round_index: int in players:
			var round_seed: int = VersusTuning.round_seed(seed_value, round_index)
			var record: bool = seed_value == SEEDS[0] and round_index == 0
			var result: Dictionary = _play_round(arena, mode, players, round_index, round_seed, bots, record)
			if result.is_empty():
				fail("%s: the round could not start" % name)
				return
			rounds += 1
			ticks += int(result["ticks"])
			spawn_count = int(result["spawn_count"])
			worst_idle = maxi(worst_idle, int(result["worst_idle"]))
			for line: String in result["spawn_hits"]:
				spawn_hits.append(line)
			if not bool(result["ended"]):
				unfinished.append("seed %d round %d" % [seed_value, round_index])
			var round_scores: PackedInt32Array = result["spawn_scores"]
			for spawn: int in Defs.MAX_PLAYERS:
				scores[spawn] += round_scores[spawn]
			var winners: PackedInt32Array = result["winner_spawns"]
			for spawn: int in winners:
				wins[spawn] += 1.0
			if record:
				_check_replay(name, arena, mode, players, round_index, round_seed, result)
		for bot: HeroBot in bots:
			played += bot.nav.links_played
			failed += bot.nav.links_failed
			if not bot.nav.failure_log.is_empty() and failures.size() < 4:
				failures.append("P%d: %s" % [bot.slot + 1, bot.nav.failure_log[-1]])
	var shares: PackedStringArray = PackedStringArray()
	var total: float = 0.0
	for spawn: int in spawn_count:
		total += wins[spawn]
	var mean: float = total / float(maxi(spawn_count, 1)) / float(maxi(rounds, 1))
	var spread: float = float(VersusTuning.BOT_WIN_RATE_SPREAD_PERCENT) / 100.0
	for spawn: int in spawn_count:
		var share: float = wins[spawn] / float(maxi(rounds, 1))
		shares.append("%d:%d%% (score %.1f)" % [spawn + 1, roundi(share * 100.0),
				float(scores[spawn]) / float(maxi(rounds, 1))])
		# Spawn fairness is a property of a shipped arena (mirrored layouts, DESIGN.md E.5); world-B's test arenas and
		# this file's pitch are built for rules, not balance: their shares are printed only.
		if bool(arena["shipped"]):
			assert_true(absf(share - mean) <= spread + 0.0001,
					"%s: spawn %d wins %d%% of %d rounds (fair share %d%%, +/-%d)" % [name, spawn + 1,
					roundi(share * 100.0), rounds, roundi(mean * 100.0), VersusTuning.BOT_WIN_RATE_SPREAD_PERCENT])
	print("    %s: %d rounds, %d ticks (%d ms), wins per spawn %s, worst idle %d, links %d played / %d failed%s" % [
		name, rounds, ticks, Time.get_ticks_msec() - started_msec, " ".join(shares), worst_idle, played, failed,
		"" if failures.is_empty() else " (" + "; ".join(failures) + ")",
	])
	assert_true(unfinished.is_empty(), "%s: every round ended by its rule (not: %s)" % [name, ", ".join(PackedStringArray(unfinished))])
	assert_true(worst_idle <= VersusTuning.BOT_IDLE_MAX_TICKS, "%s: a bot stood idle %d ticks (at most %d)" % [
		name, worst_idle, VersusTuning.BOT_IDLE_MAX_TICKS,
	])
	assert_true(spawn_hits.is_empty(), "%s: no hit or stomp within %d ticks of a spawn (%s)" % [
		name, VersusTuning.SPAWN_SHIELD_TICKS, "; ".join(PackedStringArray(spawn_hits)),
	])


## One round of `mode` on a fresh copy of the arena: round `round_index` (spawns rotated by it), Sim.rng from
## `round_seed`, the bots of `bots` in their slots (reset_round as Flow does). `record`: keep the flags of every slot
## and the digest of every tick. {} when the level cannot be loaded.
func _play_round(arena: Dictionary, mode: int, players: int, round_index: int, round_seed: int, bots: Array[HeroBot],
		record: bool) -> Dictionary:
	var referee: VersusReferee = _load_round(arena, mode, players, round_index, round_seed)
	if referee == null:
		return {}
	for bot: HeroBot in bots:
		bot.reset_round(round_seed)
		bot.install()
	var spawns: Array[Vector2i] = VersusArena.spawn_points(_level)
	var spawn_hits: Array[String] = []
	var result: Dictionary = {
		"ticks": 0, "ended": false, "worst_idle": 0, "spawn_hits": spawn_hits,
		"winner_spawns": PackedInt32Array(), "spawn_count": spawns.size(), "flags": PackedInt32Array(),
		"digests": PackedInt32Array(),
	}
	var start_spawn: PackedInt32Array = PackedInt32Array()
	for slot: int in players:
		start_spawn.append(_spawn_index(spawns, _level.get_hero(slot).sim_pos))
	var watch: Watch = _watch_start(players)
	var limit: int = (referee.round_length() if referee.round_length() > 0 else 0) + ROUND_LIMIT_TICKS
	var flags: PackedInt32Array = PackedInt32Array()
	var digests: PackedInt32Array = PackedInt32Array()
	var t: int = 0
	while t < limit and referee.phase != VersusReferee.PHASE_OVER:
		Sim.step(1)
		t += 1
		_watch_tick(watch, referee, players, spawn_hits)
		for bot: HeroBot in bots:
			var hero: PlayerBase = _level.get_hero(bot.slot)
			if hero != null and not hero.dead and not BotSenses.is_out(_level, bot.slot) and hero.control_enabled:
				result["worst_idle"] = maxi(int(result["worst_idle"]), bot.idle_ticks)
		if record:
			for slot: int in players:
				flags.append(GameInput.get_flags(slot))
			digests.append(_digest(referee, players))
	result["ticks"] = t
	result["ended"] = referee.phase == VersusReferee.PHASE_OVER
	var spawn_scores: PackedInt32Array = PackedInt32Array()
	spawn_scores.resize(Defs.MAX_PLAYERS)
	for slot: int in players:
		if start_spawn[slot] >= 0:
			spawn_scores[start_spawn[slot]] += referee.score_of(slot)
	result["spawn_scores"] = spawn_scores
	var winner_spawns: PackedInt32Array = PackedInt32Array()
	for slot: int in referee.winner_slots:
		if slot >= 0 and slot < start_spawn.size() and start_spawn[slot] >= 0:
			winner_spawns.append(start_spawn[slot])
	result["winner_spawns"] = winner_spawns
	result["flags"] = flags
	result["digests"] = digests
	for bot: HeroBot in bots:
		bot.uninstall()
	_free_level()
	return result


## Replay the recorded round with its flags as scripted input (no bot): the digests must be the same on every tick.
func _check_replay(name: String, arena: Dictionary, mode: int, players: int, round_index: int, round_seed: int,
		recorded: Dictionary) -> void:
	var referee: VersusReferee = _load_round(arena, mode, players, round_index, round_seed)
	if referee == null:
		fail("%s: the replay could not start" % name)
		return
	var flags: PackedInt32Array = recorded["flags"]
	var digests: PackedInt32Array = recorded["digests"]
	var first: int = Sim.tick + 1
	for slot: int in players:
		var index: int = slot
		GameInput.set_scripted_slot(slot, func(tick: int) -> int:
			var at: int = (tick - first) * players + index
			return flags[at] if at >= 0 and at < flags.size() else 0)
	var mismatch: int = -1
	for t: int in digests.size():
		Sim.step(1)
		if _digest(referee, players) != digests[t]:
			mismatch = t
			break
	GameInput.clear_scripted()
	assert_eq(mismatch, -1, "%s: the match log replays identically (first difference on tick %d of %d)" % [
		name, mismatch, digests.size(),
	])
	_free_level()


# =================================================================================================================
# Watching a round: spawns, hits, stomps
# =================================================================================================================

## Per slot: the tick of his last spawn, and his shield, hurts count and squash of the last tick.
class Watch:
	extends RefCounted
	var spawn: PackedInt32Array = PackedInt32Array()
	var shield: PackedInt32Array = PackedInt32Array()
	var hurts: PackedInt32Array = PackedInt32Array()
	var squash: PackedInt32Array = PackedInt32Array()


func _watch_start(players: int) -> Watch:
	var watch: Watch = Watch.new()
	for slot: int in players:
		var hero: PlayerBase = _level.get_hero(slot)
		watch.spawn.append(Sim.tick)
		watch.shield.append(hero.shield)
		watch.hurts.append(hero.run.hurts)
		watch.squash.append(hero.squash)
	return watch


## After a tick: a spawn is a spawn shield going up (the referee writes SPAWN_SHIELD_TICKS on every spawn); a hit is
## the victim's hurts count rising, a stomp his squash starting.
func _watch_tick(watch: Watch, referee: VersusReferee, players: int, hits: Array[String]) -> void:
	for slot: int in players:
		var hero: PlayerBase = _level.get_hero(slot)
		var hit: bool = hero.run.hurts > watch.hurts[slot]
		var stomped: bool = hero.squash > watch.squash[slot] and hero.squash >= VersusTuning.STOMP_SQUASH_TICKS
		watch.hurts[slot] = hero.run.hurts
		watch.squash[slot] = hero.squash
		# A hit counts against the spawn before it (a respawn later in the same tick - a kick-off in WORLD - comes after
		# the hits of WEAPONS and CONTACT_*).
		if (hit or stomped) and referee.phase != VersusReferee.PHASE_INTRO 				and Sim.tick - watch.spawn[slot] < VersusTuning.SPAWN_SHIELD_TICKS and hits.size() < 8:
			hits.append("P%d %s %d ticks after his spawn (tick %d)" % [slot + 1, "hit" if hit else "stomped",
					Sim.tick - watch.spawn[slot], Sim.tick])
		if hero.shield > watch.shield[slot]:
			watch.spawn[slot] = Sim.tick
		watch.shield[slot] = hero.shield


## A digest of the tick: every hero's feet, speed, state, timers and score, the round's phase and clock.
func _digest(referee: VersusReferee, players: int) -> int:
	var h: int = referee.phase * 7919 + referee.round_ticks
	for slot: int in players:
		var hero: PlayerBase = _level.get_hero(slot)
		for value: int in [hero.sim_pos.x, hero.sim_pos.y, hero.xvel, hero.yvel, hero.state, hero.hit_timer,
				hero.facing, int(hero.dead), referee.score_of(slot), hero.run.hearts]:
			h = (h * 1000003 + value) & 0x7FFFFFFF
	return h


# =================================================================================================================
# Arenas and levels
# =================================================================================================================

## The arenas to play: {"id", "path", "text", "modes" (launch modes), "players"}.
func _arenas() -> Array[Dictionary]:
	var paths: PackedStringArray = PackedStringArray()
	for file: String in DirAccess.get_files_at(LEVEL_DIR):
		if file.get_extension() == "lvl" and file.begins_with("arena_"):
			paths.append("%s/%s" % [LEVEL_DIR, file])
	paths.sort()
	for path: String in TEST_ARENAS:
		if FileAccess.file_exists(path):
			paths.append(path)
	var result: Array[Dictionary] = []
	var clubball: bool = false
	for path: String in paths:
		var id: StringName = StringName(path.get_file().get_basename())
		var entry: Dictionary = _arena_entry(id, FileAccess.get_file_as_string(path))
		if not (entry["modes"] as Array).is_empty():
			result.append(entry)
			clubball = clubball or (entry["modes"] as Array).has(Defs.VersusMode.CLUBBALL)
	if not clubball:
		result.append(_arena_entry(PITCH_ID, PITCH))
	return result


func _arena_entry(id: StringName, text: String) -> Dictionary:
	var meta: Dictionary = LevelData.parse(id, text).resolved_meta(Defs.Difficulty.BEGINNER)
	var modes: Array[int] = []
	for mode: int in VersusArena.modes_of(meta):
		if LAUNCH_MODES.has(mode):
			modes.append(mode)
	return {"id": id, "text": text, "modes": modes, "players": mini(VersusArena.players_of(meta), Defs.MAX_PLAYERS),
			"meta": meta, "shipped": String(id).begins_with("arena_")}


## The arena's graph: the committed one when it was baked from this text, else a bake of this run.
func _graph_for(arena: Dictionary) -> NavGraph:
	var id: StringName = arena["id"]
	var text: String = arena["text"]
	var graph: NavGraph = NavGraph.load_file(NavGraph.path_for(id))
	if graph != null and graph.source_sha256 == NavGraph.text_sha256(text):
		return graph
	if not _baked.has(id):
		var baked: NavGraph = NavBaker.new().bake_text(self, id, text, Defs.Difficulty.BEGINNER,
				NavGraph.weight_classes_for(arena["meta"]))
		_baked[id] = baked.to_json() if baked != null else ""
	var json: JSON = JSON.new()
	if str(_baked[id]).is_empty() or json.parse(str(_baked[id])) != OK:
		return null
	return NavGraph.from_dict(json.data)


## A fresh copy of the arena as round `round_index` of `mode` with `players` heroes, the intro skipped; its referee.
func _load_round(arena: Dictionary, mode: int, players: int, round_index: int, round_seed: int) -> VersusReferee:
	_free_level()
	var graph: NavGraph = _graph_for(arena)
	if graph != null:
		NavGraph.cache(graph)
	var id: StringName = arena["id"]
	Sim.manual = true
	Game.start_run(Defs.Difficulty.BEGINNER, Defs.GameMode.VERSUS, players, 1)
	Game.begin_level(id)
	_level = (load(LEVEL_SCENE) as PackedScene).instantiate() as Level
	_level.setup_from_text(id, str(arena["text"]))
	add_node(_level)
	_level.set_view_size(Vector2i(Tuning.VIEW_W, Tuning.VIEW_H) * Tuning.ART_SCALE)
	Sim.start(round_seed)
	var referee: VersusReferee = VersusReferee.find(_level)
	if referee == null:
		return null
	referee.mode = mode
	referee.begin_round(round_index)
	referee.start_round_now()
	return referee


func _free_level() -> void:
	if _level != null and is_instance_valid(_level):
		_level.get_parent().remove_child(_level)
		_level.free()
	_level = null


## Index of the spawn point at `pos` (-1 when none).
static func _spawn_index(spawns: Array[Vector2i], pos: Vector2i) -> int:
	for i: int in spawns.size():
		if spawns[i] == pos:
			return i
	var best: int = -1
	var best_distance: int = 1 << 30
	for i: int in spawns.size():
		var distance: int = absi(spawns[i].x - pos.x) + absi(spawns[i].y - pos.y)
		if distance < best_distance:
			best_distance = distance
			best = i
	return best
