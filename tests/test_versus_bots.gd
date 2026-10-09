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
##    a Last Caveman Standing round at the latest at its hard cap (PLAN.md 8 V4.c: 2 914 ticks of play);
##  - no bot stands idle more than VersusTuning.BOT_IDLE_MAX_TICKS (10 s) while it is in play;
##  - no hit and no stomp lands on a hero within VersusTuning.SPAWN_SHIELD_TICKS of his spawn (the round start, a
##    respawn, a Clubball kick-off);
##  - on a shipped arena (levels/arena_*.lvl), the win rate per spawn point is within
##    VersusTuning.BOT_WIN_RATE_SPREAD_PERCENT points of the fair share (the test arenas print theirs);
##  - a match log replays identically: the first round of each set is played again from the same start with the
##    bots' recorded flags as plain scripted input (no bot) and gives the same digest on every tick.
## Each set prints one line (rounds, ticks, wins per spawn with the mean score, links played / failed, the longest
## round) for the arena
## designers. G50 (PLAN.md cut 4's switch): an (arena, mode) outside the arena's meta `bots` (a mode list or `none`;
## default every mode) ships human-only - it prints a skip line "human-only (cut 4)" and is not played. Every round
## awaits a frame (the freed levels' queued callbacks are flushed; one frame for all sets overflowed Godot's message
## queue, wf9_integration_to_core-B.txt #1). VERSUS_BOTS_SHARD=<i>/<n> plays every n-th (arena, mode) set from the
## i-th (tools/g3_versus_bots.sh runs the shards side by side; the mover bake runs in shard 0). Also here (too slow
## for the quick tests): heroes who never move on every arena that lists Last Caveman Standing - the hard cap ends
## what no sudden death does, and three drawn rounds end the match (PLAN.md 8 V4.c, DESIGN.md G78; shard 0); the rider movers of the arena kit - a see-saw's two ends
## and a pulley's two lifts - bake as
## mover nodes whose every link verifies, the lifts with links at every still state of their pulley (core-B wf10); a
## bot gets off and on lifts that a rival holds between their stops; every committed graph with pulley lifts is
## verified in full (the last shard; the quick tests check a sample). Bakes and long verifications run in frames
## (NavBaker's header: one go overflows the engine's callback queue). And a shard of the versus soak (PLAN.md 7 P4.1,
## tools/bots/soak_runner.gd; phase 4): one seeded round on every (mode, arena that lists it, 2 / 3 / 4 players) cell -
## 54 rounds, CPUs of all three levels on the seats, the game's default rules through a real VersusMatch - with the
## soak's checks on every tick (no engine error, every round ends, no score against the mode's rules, no hero left
## outside the arena); about a minute, in the last shard but one. The 4 x 1 000 rounds are `bash tools/bots/soak.sh`.

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

const MOVERS_ID: StringName = &"test_core_bots_seesaw"

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
	var shard: Vector2i = _shard()
	var sets: int = 0
	var index: int = 0
	for arena: Dictionary in arenas:
		for mode: int in arena["modes"]:
			if not (arena["bots"] as Array).has(mode):
				print("    %s/%s: human-only (cut 4) - meta `bots` leaves the mode out (G50), no bot set" % [arena["id"],
						Defs.VERSUS_MODE_NAMES[mode]])
				continue
			index += 1
			if (index - 1) % shard.y != shard.x:
				continue
			await _play_set(arena, mode)
			sets += 1
	assert_true(sets >= (4 if shard.y == 1 else 1), "%d (arena, mode) sets" % sets)


## VERSUS_BOTS_SHARD=<i>/<n>: (i, n); (0, 1) without it.
static func _shard() -> Vector2i:
	var text: String = OS.get_environment("VERSUS_BOTS_SHARD")
	var parts: PackedStringArray = text.split("/")
	if parts.size() != 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int() or int(parts[1]) < 1:
		return Vector2i(0, 1)
	return Vector2i(clampi(int(parts[0]), 0, int(parts[1]) - 1), int(parts[1]))


func test_see_saw_and_pulley_lifts_bake_as_verified_rider_movers() -> void:
	if _shard().x != 0:
		assert_true(true, "the mover bake runs in shard 0")
		return
	var graph: NavGraph = await _movers_graph()
	assert_not_null(graph)
	if graph == null:
		return
	var parts: Dictionary = {}
	var lifts: Dictionary = {}  # mover index -> node id
	for index: int in graph.movers.size():
		var mover: Dictionary = graph.movers[index]
		assert_eq(StringName(str(mover["kind"])), NavGraph.MOVER_RIDER, "%s moves under its riders" % mover["key"])
		parts[str(mover["id"])] = int(parts.get(str(mover["id"]), 0)) + 1
		if graph.is_pulley_lift(index):
			assert_eq(int(mover["limit"]), 48, "%s: its pulley's travel (range 3)" % mover["key"])
			for node: NavGraph.NavNode in graph.nodes:
				if node.mover == index:
					lifts[index] = node.id
	assert_eq(int(parts.get("objects/seesaw", 0)), 2, "both plank ends of the see-saw (%s)" % [parts])
	assert_eq(int(parts.get("objects/platform", 0)), 2, "both pulley lifts (%s)" % [parts])
	assert_eq(lifts.size(), 2, "both lifts know their pulley")
	var onto: int = 0
	var off: int = 0
	# Per lift: the pulley offsets (px) that have a link off it / onto it.
	var off_states: Dictionary = {}
	var onto_states: Dictionary = {}
	for link: NavGraph.NavLink in graph.links:
		if link.cond.is_empty():
			continue
		if graph.nodes[link.to].mover >= 0 and graph.nodes[link.from].mover < 0:
			onto += 1
		elif graph.nodes[link.from].mover >= 0:
			off += 1
		var mover: int = link.cond[0]
		if not lifts.has(mover):
			continue
		assert_eq(Vector2i(link.cond[3], link.cond[4]), Vector2i.ZERO, "link %d: the lift stands still" % link.id)
		assert_eq(link.cond[1], 0, "link %d: a lift only moves up and down" % link.id)
		var p: int = graph.link_pulley_offset(link)
		var states: Dictionary = off_states if graph.nodes[link.from].mover == mover else onto_states
		var seen: Dictionary = states.get(mover, {})
		seen[p] = true
		states[mover] = seen
	assert_true(onto >= 2 and off >= 4, "links onto (%d) and off (%d) the movers" % [onto, off])
	# A pulley never returns to its level start, so a rider needs a way off at EVERY still state of it (2 px apart) -
	# a lift held between its stops by an equal weight on the other one stranded the bots of Tar Pulleys at G3.
	var offsets: PackedInt32Array = NavMovers.pulley_offsets(48)
	for mover: int in lifts:
		var missing: PackedInt32Array = PackedInt32Array()
		for p: int in offsets:
			if not (off_states.get(mover, {}) as Dictionary).has(p):
				missing.append(p)
		assert_eq(Array(missing), [], "%s: a link off it at every pulley state" % graph.movers[mover]["key"])
		var boards: Dictionary = onto_states.get(mover, {})
		assert_true(boards.has(0) and (boards.has(48) or boards.has(-48)) and boards.size() >= 12,
				"%s: links onto it at rest, at a stop and between (%d states)" % [graph.movers[mover]["key"], boards.size()])
	var baker: NavBaker = NavBaker.new()
	var data: LevelData = LevelData.parse(graph.level_id, MOVERS_ROOM)
	assert_true(baker.sim.setup(self, graph.level_id, data.build_grid(0), data.resolved_meta(0), data.entity_records()))
	var problems: PackedStringArray = await baker.verify_graph_in_frames(graph, self)
	baker.sim.teardown()
	assert_eq(problems.size(), 0, "; ".join(problems))
	print("    %s: %d links (%d onto, %d off the movers), all verified" % [graph.level_id, graph.links.size(), onto, off])


## A brain that only walks to `target`.
class _Steer:
	extends BotBrain

	var target: Vector2i = Vector2i.ZERO

	func think(_hero: PlayerBase, _level: LevelBase, _tick: int) -> void:
		pass

	func act(hero: PlayerBase, _level: LevelBase, tick: int) -> int:
		bot.nav.set_target(target, 4)
		return bot.nav.step(hero, tick)


func test_a_bot_gets_off_and_on_lifts_a_rival_holds_between_their_stops() -> void:
	# wf9_da_to_core_b.txt #1: two heroes, one on each lift, weigh the same, so the pulley stands wherever it was -
	# the bots had links for its level-start state only and stood there for good. Here a rival camps on the right
	# lift; the bot on the left one must leave it at a state between two stops, board it again where it then rests
	# (risen to its top stop) and leave it there too.
	if _shard().x != 0:
		assert_true(true, "the lift ride runs in shard 0")
		return
	var graph: NavGraph = await _movers_graph()
	assert_not_null(graph)
	if graph == null:
		return
	var arena: Dictionary = _arena_entry(MOVERS_ID, MOVERS_ROOM)
	var referee: VersusReferee = _load_round(arena, Defs.VersusMode.LAST_CAVEMAN, 2, 0, 7)
	assert_not_null(referee)
	if referee == null:
		return
	var left: MovingPlatform = _level.find_named(&"pa") as MovingPlatform
	var right: MovingPlatform = _level.find_named(&"pb") as MovingPlatform
	assert_true(left != null and right != null, "both lifts")
	var hero: PlayerBase = _level.get_hero(0)
	var rival: PlayerBase = _level.get_hero(1)
	GameInput.set_scripted_slot(0, func(_tick: int) -> int: return 0)
	GameInput.set_scripted_slot(1, func(_tick: int) -> int: return 0)
	# The hero alone on the left lift: it sinks 2 px a tick; the rival steps onto the right one on the way.
	hero.respawn_at(Vector2i(left.get_box().get_center().x, left.get_box().position.y + NavMovers.RIDE_SINK_PX))
	Sim.step(7)
	rival.respawn_at(Vector2i(right.get_box().get_center().x, right.get_box().position.y + NavMovers.RIDE_SINK_PX))
	Sim.step(6)
	var pulley: Pulley = left.pulley as Pulley
	assert_not_null(pulley, "the pulley drives the lifts")
	if pulley == null:
		return
	var held: int = pulley.offset
	assert_true(held > 0 and held < 48 and not NavMovers.is_grid_offset(held, 48),
			"the pulley is held between two stops and off the searched grid (offset %d)" % held)
	Sim.step(8)
	assert_eq(pulley.offset, held, "equal weights: it stands")
	GameInput.clear_scripted_slot(0)
	var bot: HeroBot = HeroBot.new(0, Defs.BotLevel.HUNTER, 5, Defs.VersusMode.LAST_CAVEMAN)
	var steering: _Steer = _Steer.new()
	steering.bot = bot
	bot.brain = steering
	bot.install()
	var lift_node: int = -1
	var ledge: int = graph.node_at(Vector2i(32, 96))
	for node: NavGraph.NavNode in graph.nodes:
		if node.mover >= 0 and graph.movers[node.mover].get("side", 0) == 1:
			lift_node = node.id
	assert_true(lift_node >= 0 and ledge >= 0, "the left lift and the left ledge are nodes")
	# 1. Off the held lift, to the ledge beside it.
	steering.target = Vector2i(32, 96)
	var left_at: int = -1
	var worst_idle: int = 0
	var reached: bool = false
	for t: int in 300:
		Sim.step(1)
		worst_idle = maxi(worst_idle, bot.idle_ticks)
		if left_at < 0 and not hero.on_platform:
			left_at = pulley.offset if absi(pulley.offset - held) <= PartyTuning.PULLEY_SPEED_PX else -999
		if bot.nav.arrived(hero) and not bot.nav.is_busy():
			reached = true
			break
	assert_true(reached, "the bot left the held lift for the ledge (stands at %s, offset %d)" % [hero.sim_pos,
			pulley.offset])
	assert_true(left_at != -999 and left_at >= 0, "he took off while the pulley was held at %d (it was at %d)" % [held,
			left_at])
	# 2. The rival's side sinks to its stop, the left lift rises to its top: board it there.
	for t: int in 80:
		Sim.step(1)
		if pulley.offset == -48 and pulley.step == 0:
			break
	assert_eq(pulley.offset, -48, "the rival's lift sank to its stop")
	reached = false
	for t: int in 500:
		steering.target = Vector2i(left.get_box().get_center().x, left.get_box().position.y)
		Sim.step(1)
		worst_idle = maxi(worst_idle, bot.idle_ticks)
		if hero.on_platform and bot.nav.node_of(hero) == lift_node and not bot.nav.is_busy():
			reached = true
			break
	assert_true(reached, "the bot boarded the risen lift (stands at %s, lift top %s)" % [hero.sim_pos,
			left.get_box().position])
	Sim.step(4)
	assert_eq(pulley.offset, -48, "both ride again: it stands at its stop")
	# 3. And off it again, down to the floor.
	steering.target = Vector2i(40, 160)
	reached = false
	for t: int in 400:
		Sim.step(1)
		worst_idle = maxi(worst_idle, bot.idle_ticks)
		if bot.nav.arrived(hero) and not bot.nav.is_busy():
			reached = true
			break
	assert_true(reached, "the bot left the risen lift for the floor (stands at %s)" % hero.sim_pos)
	assert_true(worst_idle <= 60, "he never stood idle for long (%d ticks)" % worst_idle)
	assert_eq(bot.nav.links_failed, 0, "; ".join(bot.nav.failure_log))
	print("    lift ride: held at %d, %d links played, worst idle %d" % [held, bot.nav.links_played, worst_idle])
	bot.uninstall()
	GameInput.clear_scripted()
	_free_level()


func test_committed_graphs_with_pulley_lifts_hold_in_every_state() -> void:
	# tests/test_core_bots.gd checks a sample of a committed pulley sweep in the quick run; here every link of every
	# committed graph that has pulley lifts is re-simulated from every x of its window (the last shard).
	var shard: Vector2i = _shard()
	if shard.x != shard.y - 1:
		assert_true(true, "the pulley graphs are verified in the last shard")
		return
	var checked: int = 0
	for file: String in DirAccess.get_files_at(NavGraph.DIR):
		if file.get_extension() != "json":
			continue
		var graph: NavGraph = NavGraph.load_file("%s/%s" % [NavGraph.DIR, file])
		if graph == null:
			continue
		var swept: bool = false
		for index: int in graph.movers.size():
			swept = swept or graph.is_pulley_lift(index)
		var level_path: String = "%s/%s.lvl" % [LEVEL_DIR, graph.level_id]
		if not swept or not FileAccess.file_exists(level_path):
			continue
		var text: String = FileAccess.get_file_as_string(level_path)
		if NavGraph.text_sha256(text) != graph.source_sha256:
			continue  # stale: test_core_bots.test_committed_graphs_hold fails on it
		var data: LevelData = LevelData.parse(graph.level_id, text, level_path)
		var baker: NavBaker = NavBaker.new()
		assert_true(baker.sim.setup(self, graph.level_id, data.build_grid(0), data.resolved_meta(0),
				data.entity_records()))
		var started: int = Time.get_ticks_msec()
		var problems: PackedStringArray = await baker.verify_graph_in_frames(graph, self)
		baker.sim.teardown()
		assert_eq(problems.size(), 0, "%s: %s" % [file, "; ".join(problems)])
		print("    %s: %d links verified in every pulley state (%d ms)" % [file, graph.links.size(),
				Time.get_ticks_msec() - started])
		checked += 1
	assert_true(true, "%d graph(s) with pulley lifts" % checked)


func test_heroes_who_never_move_end_every_last_caveman_arena_by_the_cap() -> void:
	# PLAN.md 8 V4.c (ruling R8, DESIGN.md G78): no Last Caveman Standing round lasts for ever. The default run plays
	# two idle heroes on spawns 1 + 2 (tests/test_versus_rules.gd); here the other three rotations of two and all four
	# at once, on every arena file that lists the mode - also where CPUs do not play it (Tar Pulleys) - with the arena's
	# own sudden death. Whoever no threat reaches is stopped by the hard cap.
	if _shard().x != 0:
		assert_true(true, "the idle rounds run in shard 0")
		return
	var cap: int = VersusTuning.SUDDEN_DEATH_AT_TICKS + VersusTuning.SUDDEN_DEATH_CAP_TICKS
	var played: int = 0
	var capped: int = 0
	var arenas: int = 0
	for arena: Dictionary in _arenas():
		if not (arena["modes"] as Array).has(Defs.VersusMode.LAST_CAVEMAN):
			continue
		arenas += 1
		# (heroes, round): two heroes on spawns 2 + 3, 3 + 4 and 4 + 1 (spawns 1 + 2: the default run), then all four.
		for case: Vector2i in [Vector2i(2, 1), Vector2i(2, 2), Vector2i(2, 3), Vector2i(mini(int(arena["players"]), 4), 0)]:
			var players: int = case.x
			var referee: VersusReferee = _load_round(arena, Defs.VersusMode.LAST_CAVEMAN, players, case.y,
					VersusTuning.round_seed(7, case.y))
			assert_not_null(referee, "%s: a referee" % arena["id"])
			if referee == null:
				continue
			for slot: int in players:
				GameInput.set_scripted_slot(slot, func(_tick: int) -> int: return 0)
			while referee.phase != VersusReferee.PHASE_OVER and referee.round_ticks < cap + 5:
				Sim.step(1)
			var standing: PackedInt32Array = PackedInt32Array()
			for slot: int in players:
				if not referee.is_out(slot) and not _level.get_hero(slot).dead:
					standing.append(slot)
			var by_cap: bool = referee.cap_at >= 0 and referee.round_ticks >= referee.cap_at
			var name: String = "%s, %d idle heroes, round %d" % [arena["id"], players, case.y]
			assert_eq(referee.phase, VersusReferee.PHASE_OVER, "%s: the round ended (%d ticks played)" % [name,
					referee.round_ticks])
			assert_true(referee.round_ticks <= cap, "%s: by the hard cap at %d ticks of play (took %d)" % [name, cap,
					referee.round_ticks])
			if by_cap:
				capped += 1
				assert_eq(referee.winner_slots, PackedInt32Array(), "%s: nobody was hurt - the cap's draw (standing %s)" % [
					name, standing])
			print("    %s/last_caveman, %d idle heroes, round %d: %d ticks, ended by %s, standing %s, winners %s" % [
				arena["id"], players, case.y, referee.round_ticks, "the CAP" if by_cap else "its sudden death", standing,
				referee.winner_slots])
			played += 1
			GameInput.clear_scripted()
			_free_level()
			await get_tree().process_frame
	assert_true(arenas >= 5, "%d arena files list Last Caveman Standing (%d idle rounds)" % [arenas, played])
	assert_true(capped >= 1, "the cap ended %d of them" % capped)


func test_two_who_never_move_draw_a_match_after_three_capped_rounds() -> void:
	# A 2-player match plays on spawns 1 and 2 (they swap every round): on Colossus Hall both stand under ledges no
	# stalactite reaches. Before the cap the first round never ended; with it every round is a draw at 2 914 ticks -
	# and the third drawn round ends the match.
	var id: StringName = &"arena_colossus_hall"
	var text: String = FileAccess.get_file_as_string("res://levels/%s.lvl" % id)
	if _shard().x != 0:
		assert_true(true, "the drawn match runs in shard 0")
		return
	var versus_match: VersusMatch = VersusMatch.new()
	# Two seats nobody feeds (bot seats without a bot source): their heroes stand idle.
	versus_match.seat_bot(Defs.BotLevel.HUNTER)
	versus_match.seat_bot(Defs.BotLevel.HUNTER)
	versus_match.mode = Defs.VersusMode.LAST_CAVEMAN
	versus_match.arena = id
	versus_match.begin_match(5)
	var cap: int = VersusTuning.SUDDEN_DEATH_AT_TICKS + VersusTuning.SUDDEN_DEATH_CAP_TICKS
	Sim.manual = true
	var rounds: int = 0
	var played: int = 0
	var first_spawns: Array[Vector2i] = []
	while not versus_match.is_over() and rounds < 6:
		assert_eq(versus_match.arena_for_round(versus_match.round_index), id)
		versus_match.begin_round(id)
		Game.versus_match = versus_match
		Game.start_run(Defs.Difficulty.BEGINNER, Defs.GameMode.VERSUS, 2, 1)
		Game.begin_level(id)
		_free_level()
		_level = (load(LEVEL_SCENE) as PackedScene).instantiate() as Level
		_level.setup_from_text(id, text)
		add_node(_level)
		_level.set_view_size(Vector2i(Tuning.VIEW_W, Tuning.VIEW_H) * Tuning.ART_SCALE)
		Sim.start(versus_match.round_seed())
		var ref: VersusReferee = VersusReferee.find(_level)
		# Without Game.versus_match the referee ends the round by Events.round_ended, not through Flow's screens.
		Game.versus_match = null
		assert_not_null(ref)
		if ref == null:
			break
		assert_eq(ref.mode, Defs.VersusMode.LAST_CAVEMAN, "the match's mode reached the referee")
		assert_eq(ref.round_index, rounds)
		var spawns: Array[Vector2i] = [_level.get_hero(0).sim_pos, _level.get_hero(1).sim_pos]
		if rounds == 0:
			first_spawns = spawns
		elif rounds == 1:
			assert_eq(spawns, [first_spawns[1], first_spawns[0]] as Array[Vector2i], "two players swap spawns 1 and 2")
		ref.start_round_now()
		for slot: int in 2:
			GameInput.set_scripted_slot(slot, func(_tick: int) -> int: return 0)
		while ref.phase != VersusReferee.PHASE_OVER and ref.round_ticks < cap + 5:
			Sim.step(1)
		assert_eq(ref.phase, VersusReferee.PHASE_OVER, "round %d ended" % rounds)
		assert_eq(ref.round_ticks, cap, "round %d: at the hard cap" % rounds)
		assert_eq(ref.winner_slots, PackedInt32Array(), "round %d: nobody was hurt - a draw" % rounds)
		played += ref.round_ticks
		assert_true(versus_match.record_round(ref.winner_slots))
		rounds += 1
		GameInput.clear_scripted()
		_free_level()
		await get_tree().process_frame
	assert_eq(rounds, VersusTuning.DRAW_ROUNDS_TO_END, "the third drawn round ends the match")
	assert_true(versus_match.is_over())
	assert_eq(played, VersusTuning.DRAW_ROUNDS_TO_END * cap, "3 x 2 914 ticks of play")
	assert_eq(versus_match.leaders(), PackedInt32Array(), "a drawn match: nobody is named")
	assert_eq(versus_match.round_wins, PackedInt32Array([0, 0, 0, 0]))


## The soak shard plays seeds of its own, beside the thousand of tools/bots/soak.sh (SoakRunner.SEED_BASE 4001 ..).
const SOAK_RUNNER: String = "res://tools/bots/soak_runner.gd"
const SOAK_SHARD_SEED: int = 9001


func test_a_soak_shard_plays_every_cell_once_without_an_anomaly() -> void:
	# PLAN.md 7 P4.1: the soak's own round loop and checks (tools/bots/soak_runner.gd), one round per cell - every mode
	# on every arena that lists it with 2, 3 and 4 CPUs, also where the game seats none (Tar Pulleys' Last Caveman
	# Standing: the rules are soaked, the bots are the hands). Cell i plays seed SOAK_SHARD_SEED + i as round i %
	# players, so the spawn rotations differ from cell to cell.
	var shard: Vector2i = _shard()
	if shard.x != maxi(shard.y - 2, 0):
		assert_true(true, "the soak shard runs in the last shard but one")
		return
	_free_level()
	var runner: Node = (load(SOAK_RUNNER) as GDScript).new() as Node
	add_node(runner)
	var specs: Array[Dictionary] = []
	var modes: Dictionary = {}
	for mode: int in LAUNCH_MODES:
		for cell: Dictionary in runner.call(&"cells", mode):
			var spec: Dictionary = cell.duplicate()
			spec["seed"] = SOAK_SHARD_SEED + specs.size()
			spec["round"] = specs.size() % int(cell["players"])
			specs.append(spec)
			modes[mode] = int(modes.get(mode, 0)) + 1
	assert_eq(modes.size(), LAUNCH_MODES.size(), "every launch mode has cells (%s)" % [modes])
	assert_true(specs.size() >= 50, "%d cells: 22 (arena, mode) pairs x 2, 3 and 4 players" % specs.size())
	var result: Dictionary = await runner.call(&"play_all", specs)
	assert_eq(int(result["rounds"]), specs.size(), "every cell played its round")
	assert_eq(int(result["anomalies"]), 0, "no anomaly (each line names the round that replays it: %s)" % [
		" || ".join(result["anomaly_lines"] as PackedStringArray)])
	assert_true(int(result["longest"]) <= VersusTuning.CLUBBALL_MATCH_TICKS + ROUND_LIMIT_TICKS,
			"the longest round ran %d ticks of play" % int(result["longest"]))
	for line: String in result["lines"]:
		print("    %s" % line)
	print("    soak shard: %d rounds, %d ticks, %d ms" % [result["rounds"], result["ticks"], result["ms"]])


## The graph of MOVERS_ROOM, baked once per run (in frames: its pulley sweep is a long bake).
func _movers_graph() -> NavGraph:
	if not _baked.has(MOVERS_ID):
		var started: int = Time.get_ticks_msec()
		var baked: NavGraph = await NavBaker.new().bake_text_in_frames(self, MOVERS_ID, MOVERS_ROOM)
		_baked[MOVERS_ID] = baked.to_json() if baked != null else ""
		if baked != null:
			print("    %s: baked in %d ms (%d candidate runs)" % [MOVERS_ID, Time.get_ticks_msec() - started,
					int(baked.baker.get("candidates", 0))])
	var json: JSON = JSON.new()
	if str(_baked[MOVERS_ID]).is_empty() or json.parse(str(_baked[MOVERS_ID])) != OK:
		return null
	return NavGraph.from_dict(json.data)


# =================================================================================================================
# One (arena, mode) set
# =================================================================================================================

func _play_set(arena: Dictionary, mode: int) -> void:
	var name: String = "%s/%s" % [arena["id"], Defs.VERSUS_MODE_NAMES[mode]]
	await _bake_missing(arena)
	var players: int = int(arena["players"])
	var spawn_count: int = 0
	var wins: PackedFloat32Array = PackedFloat32Array()
	wins.resize(Defs.MAX_PLAYERS)
	wins.fill(0.0)
	var rounds: int = 0
	var ticks: int = 0
	var longest: int = 0
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
			longest = maxi(longest, int(result["ticks"]))
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
			await get_tree().process_frame
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
	print("    %s: %d rounds, %d ticks (%d ms), wins per spawn %s, worst idle %d, links %d played / %d failed%s; longest round %d" % [
		name, rounds, ticks, Time.get_ticks_msec() - started_msec, " ".join(shares), worst_idle, played, failed,
		"" if failures.is_empty() else " (" + "; ".join(failures) + ")", longest,
	])
	assert_true(unfinished.is_empty(), "%s: every round ended by its rule (not: %s)" % [name, ", ".join(PackedStringArray(unfinished))])
	if mode == Defs.VersusMode.LAST_CAVEMAN:
		# PLAN.md 8 V4.c (ruling R8, DESIGN.md G78): no bot round outlasts the hard cap of the mode - the sudden death at
		# VersusTuning.SUDDEN_DEATH_AT_TICKS, the gong at the latest VersusTuning.SUDDEN_DEATH_CAP_TICKS after it.
		var cap: int = VersusTuning.SUDDEN_DEATH_AT_TICKS + VersusTuning.SUDDEN_DEATH_CAP_TICKS
		assert_true(longest <= cap, "%s: no round outlasts the hard cap (the longest ran %d ticks, the cap falls at %d)" % [
			name, longest, cap])
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
	# G50: the modes bots play here (meta `bots`: a list of mode names or `none`; absent or empty: every mode).
	var bots: Array[int] = modes.duplicate()
	var listed: String = str(meta.get("bots", "")).strip_edges()
	if listed != "":
		bots.clear()
		var names: PackedStringArray = PackedStringArray()
		for part: String in listed.split(",", false):
			names.append(part.strip_edges())
		for mode: int in modes:
			if names.has(String(Defs.versus_mode_name(mode))):
				bots.append(mode)
	return {"id": id, "text": text, "modes": modes, "players": mini(VersusArena.players_of(meta), Defs.MAX_PLAYERS),
			"meta": meta, "shipped": String(id).begins_with("arena_"), "bots": bots}


## The arena's graph: the committed one when it was baked from this text, else the bake of this run
## ([method _bake_missing], before the set's first round); null when there is neither.
func _graph_for(arena: Dictionary) -> NavGraph:
	var id: StringName = arena["id"]
	var text: String = arena["text"]
	var graph: NavGraph = NavGraph.load_file(NavGraph.path_for(id))
	if graph != null and graph.source_sha256 == NavGraph.text_sha256(text):
		return graph
	var json: JSON = JSON.new()
	if str(_baked.get(id, "")).is_empty() or json.parse(str(_baked[id])) != OK:
		return null
	return NavGraph.from_dict(json.data)


## Bake the arena's graph when no committed one was baked from its text (once per run; in frames - await it - and never
## while a level runs: the bake has a sim world of its own).
func _bake_missing(arena: Dictionary) -> void:
	var id: StringName = arena["id"]
	var text: String = arena["text"]
	if _baked.has(id):
		return
	var graph: NavGraph = NavGraph.load_file(NavGraph.path_for(id))
	if graph != null and graph.source_sha256 == NavGraph.text_sha256(text):
		return
	_free_level()
	var baked: NavGraph = await NavBaker.new().bake_text_in_frames(self, id, text, Defs.Difficulty.BEGINNER,
			NavGraph.weight_classes_for(arena["meta"]))
	_baked[id] = baked.to_json() if baked != null else ""


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
