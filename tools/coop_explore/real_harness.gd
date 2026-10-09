extends RefCounted
## CONTINUOUS PLAY IN THE REAL GAME (the G3b verifier's real_lib.gd, adopted by world-B in wf11): the calls of
## harness.gd on a co-op run of two started through Flow as the route proofs start one (sim_bench_runner:
## Game.start_run, Flow.start_level, the real level scene with its camera, edge walls, leash, dozing, checkpoints,
## signs and props), P1 driven by the caller's inputs and P2's player away: his slot never reads a key, so he is the
## idle partner of DESIGN.md G33 from the first tick.
## A run starts with the game's own team-wipe reset (LevelBase.respawn_player through Level._respawn_now: the level
## state reset, every hero respawned hatched at the active checkpoint) at the last checkpoint before the gate's
## tablet - the state a lone player is in after a death there. No entity, rule or tile is touched. (This is the
## GAME's reset, not the search world's exact one: a route of the real game is replayed as the first run of a fresh
## process.) Used by replay.gd for a route file that says real=true and by explorer.gd with real=1.

const BENCH: String = "res://scripts/core/dev/sim_bench_runner.gd"
const NOWHERE: Vector2i = Vector2i(-1, -1)
const SEED: int = 0x5EA2C4


## What the explorer reads through `lib.s` (the Searcher of harness.gd).
class Shim:
	extends RefCounted

	var level: LevelBase = null
	var partner: PlayerBase = null
	var _flags: PackedInt32Array = PackedInt32Array()

	func signature() -> String:
		var parts: PackedStringArray = PackedStringArray()
		for kind: int in Defs.KIND_COUNT:
			if kind == Defs.Kind.HERO_PROJECTILE or kind == Defs.Kind.PLAYER:
				continue
			for entity: SimEntity in level.get_kind(kind):
				if entity is PlayerBase or not is_instance_valid(entity):
					continue
				var part: String = CoopSearch.probe(entity)
				if part != "":
					parts.append(part)
		return "|".join(parts)


var s: Shim = Shim.new()
var data: LevelData = null
var difficulty: int = 0
var gate: String = ""
var far: Vector2i = NOWHERE
var tablet: Dictionary = {}
var starts: Array[Vector2i] = []
var t: int = 0
var hurts: int = 0
var bounces: int = 0
var min_y: int = 1 << 30
var checkpoint_cell: Vector2i = NOWHERE
var tablet_entity: SimEntity = null
var _bench: Node = null
var _level: Level = null
var _flag: int = 0
var _tick_base: int = 0
var _p1: PlayerBase = null
var _checkpoint: CheckpointBase = null
## Added to the clock at every [method begin] (the phase of geysers, lifts and whatever runs on Sim.tick).
var tick_offset: int = 0
## Times the level had to be entered again (a run left the stage: a warp, the exit, a game over).
var restarts: int = 0
## True when the last run ended because the stage was left (not a death).
var left_stage: bool = false
var _level_id: StringName = &""
var _mode: String = ""
var _checkpoint_pos: Vector2i = NOWHERE


## Start the co-op run and the level; the active checkpoint is the last one before the gate's tablet (the search's
## second start). `host`: a node inside the tree (the bench runner is added to it). A coroutine.
func build(host: Node, level_id: StringName, gate_name: String, p_difficulty: int, _whole: bool = true) -> bool:
	data = LevelData.load_file(CoopSearch.level_path(level_id))
	difficulty = p_difficulty
	gate = gate_name
	tablet = CoopSearch.find_tablet(data, difficulty, gate)
	if tablet.is_empty():
		return false
	far = tablet["far"]
	var grid: TileGrid = CoopSearch.grid_at_rest(data, difficulty)
	var search_starts: Array[Vector2i] = CoopSearch.start_points(data, difficulty, tablet, grid)
	_bench = (load(BENCH) as GDScript).new() as Node
	_bench.name = "SimBench"
	host.add_child(_bench)
	var mode: String = "expert" if difficulty == Defs.Difficulty.EXPERT else "beginner"
	_level_id = level_id
	_mode = mode
	_bench.call(&"_start_header_run", {"level": String(level_id), "players": 2}, mode)
	if not await _bench.call(&"_enter", level_id):
		return false
	_level = Game.level as Level
	s.level = _level
	# The checkpoint record nearest to the search's checkpoint start (the last one before the tablet by column).
	var want: Vector2i = search_starts[search_starts.size() - 1]
	var best: CheckpointBase = null
	for entity: SimEntity in _level.get_kind(Defs.Kind.CHECKPOINT):
		var checkpoint: CheckpointBase = entity as CheckpointBase
		if checkpoint == null:
			continue
		if best == null or absi(checkpoint.sim_pos.x - want.x) + absi(checkpoint.sim_pos.y - want.y) \
				< absi(best.sim_pos.x - want.x) + absi(best.sim_pos.y - want.y):
			best = checkpoint
	if best != null and absi(best.sim_pos.x - want.x) + absi(best.sim_pos.y - want.y) <= 48:
		for entity: SimEntity in _level.get_kind(Defs.Kind.CHECKPOINT):
			(entity as CheckpointBase).active = entity == best
		Game.set_checkpoint(best.sim_pos)
		_checkpoint = best
		_checkpoint_pos = best.sim_pos
		checkpoint_cell = Vector2i(best.sim_pos.x >> 4, (best.sim_pos.y - 1) >> 4)
		starts = [best.sim_pos]
	else:
		# No checkpoint before the tablet: the search's second start is the level start, and so is the respawn.
		Game.has_checkpoint = false
		starts = [_level.get_respawn_pos()]
	# The search's first start - the tablet itself (the pair reached it, then one player left): after the reset both
	# heroes are put there ([method begin]).
	if search_starts.size() > 1 and search_starts[0] != starts[0]:
		starts.append(search_starts[0])
	for kind: int in Defs.KIND_COUNT:
		for entity: SimEntity in _level.get_kind(kind):
			if entity is X2Tablet and tablet_entity == null \
					and absi((entity.sim_pos.x >> 4) - int(tablet["cell"].x)) <= 1 \
					and absi(((entity.sim_pos.y - 1) >> 4) - int(tablet["cell"].y)) <= 1:
				tablet_entity = entity
	_tick_base = Sim.tick
	Events.hero_hurt.connect(func(hero: PlayerBase, _kind: int, _source: SimEntity) -> void:
		if hero == _p1:
			hurts += 1)
	Events.hero_bounced.connect(func(hero: PlayerBase, target: SimEntity, _multiplier: int) -> void:
		if hero == _p1 and target is EnemyBase:
			bounces += 1)
	GameInput.set_scripted_slot(0, func(_tick: int) -> int: return _flag)
	GameInput.set_scripted_slot(1, func(_tick: int) -> int: return 0)
	return true


func close() -> void:
	GameInput.clear_scripted()


## A fresh run: the game's team-wipe reset at the active checkpoint. `_start` and the partner arguments of
## harness.gd are not used: the game puts both heroes where it puts them.
func begin(_start: Vector2i = NOWHERE, _facing: int = 1, hand: int = -1, _partner_at: Vector2i = NOWHERE) -> void:
	if not is_instance_valid(_level) or Game.level != _level or Flow.current_screen != Flow.SCREEN_LEVEL:
		# The run before left the stage (a warp, the exit, a game over): the level again, as build() entered it.
		restarts += 1
		await _bench.call(&"_reset")
		_bench.call(&"_start_header_run", {"level": String(_level_id), "players": 2}, _mode)
		await _bench.call(&"_enter", _level_id)
		_level = Game.level as Level
		s.level = _level
		_checkpoint = null
		for entity: SimEntity in _level.get_kind(Defs.Kind.CHECKPOINT):
			if entity.sim_pos == _checkpoint_pos:
				_checkpoint = entity as CheckpointBase
		GameInput.set_scripted_slot(0, func(_tick: int) -> int: return _flag)
		GameInput.set_scripted_slot(1, func(_tick: int) -> int: return 0)
	Sim.tick = _tick_base + tick_offset
	# The gate's checkpoint again (a run may have touched a later one), then the game's own reset.
	for entity: SimEntity in _level.get_kind(Defs.Kind.CHECKPOINT):
		(entity as CheckpointBase).active = entity == _checkpoint
	if _checkpoint != null:
		Game.set_checkpoint(_checkpoint.sim_pos)
	else:
		Game.has_checkpoint = false
	_level._respawn_now()
	Sim.rng.reseed(SEED)
	_p1 = _level.get_hero(0)
	s.partner = _level.get_hero(1)
	if _start != NOWHERE and not starts.is_empty() and _start != starts[0]:
		# The tablet start: both heroes at the tablet (as PlayerBase.respawn_at puts a hero at a checkpoint).
		_p1.respawn_at(_start)
		s.partner.respawn_at(_start)
		_level.snap_camera()
	s._flags = PackedInt32Array()
	set_hand(hand)
	t = 0
	hurts = 0
	bounces = 0
	min_y = 1 << 30
	_flag = 0
	left_stage = false


func step(flag: int) -> String:
	s._flags.append(flag)
	_flag = flag
	Sim.step(1)
	t += 1
	if not is_instance_valid(_level) or Game.level != _level or Flow.current_screen != Flow.SCREEN_LEVEL:
		left_stage = true
		return "dead"
	var hero: PlayerBase = _p1
	if hero.dead or hero.is_down():
		return "dead"
	min_y = mini(min_y, hero.sim_pos.y)
	var cell: Vector2i = Vector2i(Tuning.to_cell(hero.sim_pos.x), Tuning.to_cell(hero.sim_pos.y - 1))
	if cell == far:
		return "goal"
	return ""


## Not in the real game: the partner is where the game has him (hatched and idle at the checkpoint, then the leash's
## egg drifting after P1).
func place_partner() -> void:
	pass


func set_hand(hand: int) -> void:
	var run: PlayerRun = Game.runs[0]
	run.set_weapon(hand if hand >= 0 else Defs.Weapon.CLUB)
	run.set_belt(Defs.Weapon.CLUB if hand > Defs.Weapon.CLUB else PlayerRun.BELT_EMPTY)


func hero() -> PlayerBase:
	return _p1


func entity(id_part: String, col: int, row: int) -> SimEntity:
	for kind: int in Defs.KIND_COUNT:
		for found: SimEntity in _level.get_kind(kind):
			var script: Script = found.get_script() as Script
			if script == null or not String(script.resource_path).contains(id_part.get_slice("/", 1) if "/" in id_part
					else id_part):
				continue
			var spawn: Variant = found.get("spawn_pos")
			if spawn is Vector2i and (spawn as Vector2i).x >> 4 == col and absi((((spawn as Vector2i).y - 1) >> 4) - row) <= 1:
				return found
	return null


func route_text() -> String:
	var parts: PackedStringArray = PackedStringArray()
	var flags: PackedInt32Array = s._flags
	var i: int = 0
	while i < flags.size():
		var j: int = i
		while j < flags.size() and flags[j] == flags[i]:
			j += 1
		parts.append("%d:%s" % [j - i, keys(flags[i])])
		i = j
	return ",".join(parts)


static func keys(flags: int) -> String:
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
	if flags & Defs.IN_SWAP:
		text += "S"
	return text


static func dir_flag(dir: int) -> int:
	return Defs.IN_RIGHT if dir > 0 else (Defs.IN_LEFT if dir < 0 else 0)
