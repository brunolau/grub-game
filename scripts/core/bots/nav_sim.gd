class_name NavSim
extends RefCounted
## The real hero on a level's collision grid, for the nav-graph baker (PLAN.md P1.2 / P2.5: "every link verified by
## simulating the real hero", like the route proofs).
##
## Owner: core-B. A bare [LevelBase] holding the level's TileGrid plus the entities that move a hero (NAV_ENTITY_IDS:
## springs and geysers; MOVER_IDS: platforms, drop platforms, see-saws, pulleys - spawned fresh for every run), and
## one hero from `scenes/player/player.tscn` in slot 0, driven through GameInput.set_scripted_slot(0). [method run]
## puts him at rest at a feet point, feeds an input script and reports where he lands. The world is the level as it
## starts (no enemies, no items, no referee): the movers start every run at their level-start state, may be rolled
## forward first without the hero ([method run]'s `preroll`), and their state on the tick the script starts is reported
## (Outcome.mover_states) for the links that wait for it.
##
## While a NavSim is set up it owns the simulation: Sim.manual is on, GameInput slot 0 is scripted, Game.level is the
## sim level, Game.mode / Game.party read SINGLE / 1 (the hero's party components stay off: walking and jumping are the
## 1.0 physics in every mode). [method teardown] restores all of it. Never set one up during a running match.

const PLAYER_SCENE: String = "res://scenes/player/player.tscn"
## Entities that move a hero, spawned once into the sim level from the level file.
const NAV_ENTITY_IDS: Array[StringName] = [&"objects/spring", &"objects/geyser"]
## Geysers among them (objects-B's Geyser: `period`, `delay`, `plugged`, `state`, `launches`).
const GEYSER_ID: StringName = &"objects/geyser"
## Movers: platforms a hero rides (respawned fresh for every run, in file order).
const MOVER_IDS: Array[StringName] = [&"objects/platform", &"objects/drop_platform", &"objects/seesaw",
		&"objects/pulley"]
## A landing counts once the hero stood this many consecutive ticks (the hard-landing hop lifts him once more).
const SETTLE_GROUNDED_TICKS: int = 2
## Ticks after the landing in which he must settle on the landing node.
const SETTLE_MAX_TICKS: int = 14
## Ticks after a walk script in which he must slide to a stop (ice slides long).
const SETTLE_WALK_MAX_TICKS: int = 96
## Where the hero waits (suspended) while the movers are rolled forward without him.
const PARK: Vector2i = Vector2i(-4096, -4096)
## The arena wrap of world-B (`static func wrap_hero(level, hero) -> bool`), looked up by class name so that this file
## compiles without it.
const WRAP_CLASS: StringName = &"VersusArena"
const WRAP_METHOD: StringName = &"wrap_hero"

## Outcome of [method run].
class Outcome:
	extends RefCounted
	## True when he left the ground and settled on a floor again, alive.
	var landed: bool = false
	## True when he never left the ground and slid to a stop after the script, alive (a walk, a wrap seam).
	var walked: bool = false
	## True when he died (pit, liquid, spikes, off the playfield).
	var died: bool = false
	## True when he never left the ground while the script ran.
	var stayed: bool = false
	## Tick (1-based) on which the bot gets control back: the landing, or the last tick of a script that stayed on
	## the ground; 0 = none.
	var landing_tick: int = 0
	## Feet point when the run ended.
	var pos: Vector2i = Vector2i.ZERO
	## Feet point on the tick the bot got control back (landing_tick).
	var handback_pos: Vector2i = Vector2i.ZERO
	## True when an objects/spring launched him on the way.
	var sprung: bool = false
	## True when a geyser launched him on the way.
	var geysered: bool = false
	## The platform he stands on when the run ended (null = none).
	var platform: SimEntity = null
	## The movers' state on the tick before the script started: [offset x, offset y, motion x, motion y] per mover
	## part ([member NavSim.mover_parts] order).
	var mover_states: Array[PackedInt32Array] = []
	## Ticks simulated.
	var ticks: int = 0


## The level used by the sim: one fixed view over the whole grid (an arena is one screen).
class SimLevel:
	extends LevelBase

	var view: Rect2i = Rect2i(0, 0, Tuning.VIEW_W, Tuning.VIEW_H)

	func get_view_rect() -> Rect2i:
		return view

	func get_camera_cell() -> Vector2i:
		return Vector2i(view.position.x >> 4, view.position.y >> 4)


## The arena wrap in the sim: ticks in the PLAYER phase after the hero (registered after him), as the referee does
## in a match (it calls VersusArena.wrap_hero first in its own PLAYER step).
class WrapDriver:
	extends SimEntity

	var step: Callable = Callable()
	var target: PlayerBase = null

	func _sim_phases() -> PackedInt32Array:
		return PackedInt32Array([Defs.Phase.PLAYER])

	func _can_doze() -> bool:
		return false

	func _sim_tick(_phase: int) -> void:
		if step.is_valid() and target != null and Game.level != null:
			step.call(Game.level, target)


var level: SimLevel = null
var hero: PlayerBase = null
## Ticks simulated since setup (statistics).
var ticks_simulated: int = 0
## The wrap step in use (`step.call(level, hero) -> bool`), invalid when the level does not wrap or world-B's
## VersusArena.wrap_hero is not available.
var wrap_step: Callable = Callable()
## Weight class of the sim hero (NavGraph.WEIGHT_*): the walk / air cap and jump impulses a Grub Stack weight or the
## Hot Rock ember give him (PHYSICS.md C.14), set on him after every respawn exactly as world-B's referee writes them.
var weight_class: int = NavGraph.WEIGHT_LIGHT
## The geysers of the level (in file order). Every run starts with all of them plugged (no spout) except the one a
## geyser link is verified with, whose cycle is moved so that it spouts on the run's first tick.
var geysers: Array[SimEntity] = []
## The mover records of the level (LevelData.entity_records() entries of MOVER_IDS that apply), in file order.
var mover_records: Array[Dictionary] = []
## The movers spawned for the current run (one per record; fresh every run).
var movers: Array[SimEntity] = []
## The platform parts of the movers (a platform itself, a see-saw's two ends): {"mover": record index, "part": child
## index or -1, "entity": PlatformBase} - rebuilt with every respawn, same order every time.
var mover_parts: Array[Dictionary] = []
## Box position of every part at the level start (after the spawn), the frame of mover offsets.
var part_homes: Array[Vector2i] = []
var _wrap_driver: WrapDriver = null

var _springs: Array[SimEntity] = []
var _flags: PackedInt32Array = PackedInt32Array()
var _first_tick: int = 0
var _prev_level: LevelBase = null
var _prev_manual: bool = false
var _prev_mode: int = Defs.GameMode.SINGLE
var _prev_party: int = 1
var _prev_glider: bool = false


## Build the sim world under `parent` from a level's grid, meta and entity records (LevelData.entity_records()).
## Returns false (and logs) when the hero scene is missing.
func setup(parent: Node, level_id: StringName, grid: TileGrid, meta: Dictionary, records: Array[Dictionary]) -> bool:
	if not ResourceLoader.exists(PLAYER_SCENE):
		push_error("NavSim: %s is missing" % PLAYER_SCENE)
		return false
	_prev_level = Game.level
	_prev_manual = Sim.manual
	_prev_mode = Game.mode
	_prev_party = Game.party
	_prev_glider = Game.runs[0].has_glider
	Sim.manual = true
	Game.mode = Defs.GameMode.SINGLE
	Game.party = 1
	Game.runs[0].has_glider = false
	level = SimLevel.new()
	level.name = "NavSimLevel"
	level.level_id = level_id
	level.meta = meta.duplicate()
	level.grid = grid
	level.view = Rect2i(0, 0, maxi(Tuning.VIEW_W, grid.cols * Tuning.TILE), maxi(Tuning.VIEW_H, grid.rows * Tuning.TILE))
	parent.add_child(level)
	for record: Dictionary in records:
		var id: StringName = record["id"]
		if not Spawner.exists(id):
			continue
		var params: Dictionary = (record["params"] as Dictionary).duplicate()
		if not LevelText.applies_to(params, Game.difficulty):
			continue
		if MOVER_IDS.has(id):
			mover_records.append(record)
			continue
		if not NAV_ENTITY_IDS.has(id):
			continue
		var node: Node = level.spawn(id, LevelText.cell_to_feet(float(record["col"]), float(record["row"]), params),
				params)
		if node is SimEntity:
			_springs.append(node as SimEntity)
			if id == GEYSER_ID:
				geysers.append(node as SimEntity)
	var scene: PackedScene = load(PLAYER_SCENE) as PackedScene
	hero = scene.instantiate() as PlayerBase
	hero.spawn_setup(Vector2i(grid.cols * Tuning.TILE / 2, grid.rows * Tuning.TILE), {})
	level.add_child(hero)
	if str(meta.get("wrap", "none")) != "none":
		wrap_step = find_wrap_step()
		if wrap_step.is_valid():
			_wrap_driver = WrapDriver.new()
			_wrap_driver.step = wrap_step
			_wrap_driver.target = hero
			_wrap_driver.spawn_setup(Vector2i.ZERO, {})
			level.add_child(_wrap_driver)
	_spawn_movers()
	part_homes.clear()
	for part: Dictionary in mover_parts:
		part_homes.append((part["entity"] as SimEntity).get_box().position)
	return true


## world-B's arena wrap step (VersusArena.wrap_hero) as a callable; invalid when that class does not exist.
static func find_wrap_step() -> Callable:
	for entry: Dictionary in ProjectSettings.get_global_class_list():
		if StringName(str(entry.get("class", ""))) != WRAP_CLASS:
			continue
		var script: Script = load(str(entry.get("path", ""))) as Script
		if script == null:
			continue
		for method: Dictionary in script.get_script_method_list():
			if StringName(str(method.get("name", ""))) == WRAP_METHOD:
				return Callable(script, WRAP_METHOD)
	return Callable()


## Remove the sim world and give the simulation back (Game.level, Sim.manual, slot 0's script, mode, party).
func teardown() -> void:
	GameInput.clear_scripted_slot(0)
	if level != null and is_instance_valid(level):
		level.get_parent().remove_child(level)
		level.free()
	level = null
	hero = null
	_wrap_driver = null
	_springs.clear()
	geysers.clear()
	movers.clear()
	mover_parts.clear()
	mover_records.clear()
	Sim.manual = _prev_manual
	Game.mode = _prev_mode
	Game.party = _prev_party
	Game.runs[0].has_glider = _prev_glider
	if _prev_level != null and is_instance_valid(_prev_level):
		Game.level = _prev_level


## Put the hero at rest at `start` (feet point; the state of NavSim.is_settled), play `flags` (one value per tick)
## and report. The script ends where HeroBot hands control back: at the landing (the first grounded tick after being
## airborne) or, for a script that never leaves the ground (a walk, a walk across a wrap seam), at its last tick. The
## check then goes on with neutral input until he stood still SETTLE_GROUNDED_TICKS consecutive ticks (at most
## SETTLE_MAX_TICKS); `landed` / `walked` say he settled. A death or `max_ticks` end the run too.
## `geyser` >= 0: that geyser (index into [member geysers]) spouts from the run's first tick on (a geyser link).
## `preroll` > 0: the movers run that many ticks without the hero before he is put down. `stand` > 0: he stands at
## `start` with neutral input that many ticks before the script (a rider waiting on a platform); the mover states are
## taken after it.
func run(start: Vector2i, flags: PackedInt32Array, max_ticks: int, geyser: int = -1, preroll: int = 0,
		stand: int = 0) -> Outcome:
	var outcome: Outcome = Outcome.new()
	_reset_world()
	_arm_geysers(geyser)
	if preroll > 0:
		roll_movers(preroll)
	hero.respawn_at(start)
	apply_weight(hero, weight_class)
	if stand > 0:
		_flags = PackedInt32Array()
		_first_tick = Sim.tick + 1
		GameInput.set_scripted_slot(0, _script_flags)
		for t: int in stand:
			Sim.step(1)
			ticks_simulated += 1
		if geyser >= 0:
			_arm_geysers(geyser)
	outcome.mover_states = mover_states()
	_flags = flags
	_first_tick = Sim.tick + 1
	GameInput.set_scripted_slot(0, _script_flags)
	var airborne: bool = false
	var handed_back: bool = false
	var settle: int = 0
	var settle_ticks: int = 0
	var launches: int = _spring_launches()
	var spouts: int = _geyser_launches()
	for t: int in range(1, max_ticks + 1):
		Sim.step(1)
		ticks_simulated += 1
		outcome.ticks = t
		if hero.dead:
			outcome.died = true
			break
		var standing: bool = hero.is_grounded() and hero.yvel == 0 and (airborne or hero.xvel == 0 or hero.on_platform)
		if not handed_back:
			if not hero.is_grounded():
				airborne = true
				continue
			if airborne:
				outcome.landing_tick = t
			elif t >= flags.size():
				outcome.stayed = true
				outcome.landing_tick = t
			else:
				continue
			# The bot takes over here: the check runs on neutral input.
			handed_back = true
			outcome.handback_pos = hero.sim_pos
			_flags = PackedInt32Array()
			settle = 1 if standing else 0
		else:
			settle_ticks += 1
			settle = settle + 1 if standing else 0
		if settle >= SETTLE_GROUNDED_TICKS:
			outcome.landed = airborne
			outcome.walked = not airborne
			break
		if settle_ticks >= (SETTLE_MAX_TICKS if airborne else SETTLE_WALK_MAX_TICKS):
			break
	outcome.pos = hero.sim_pos
	outcome.platform = platform_under(hero)
	outcome.sprung = _spring_launches() != launches
	outcome.geysered = _geyser_launches() != spouts
	GameInput.clear_scripted_slot(0)
	return outcome


## Run the movers `ticks` ticks without the hero (he is parked and suspended meanwhile).
func roll_movers(ticks: int) -> void:
	if ticks <= 0:
		return
	hero.respawn_at(PARK)
	Sim.suspend(hero)
	GameInput.set_scripted_slot(0, func(_tick: int) -> int: return 0)
	for t: int in ticks:
		Sim.step(1)
		ticks_simulated += 1
	Sim.resume(hero)


## The state of every mover part now: [offset x, offset y, motion x, motion y] (offset from its level-start box).
func mover_states() -> Array[PackedInt32Array]:
	var result: Array[PackedInt32Array] = []
	for i: int in mover_parts.size():
		var entity: SimEntity = mover_parts[i]["entity"]
		var offset: Vector2i = entity.get_box().position - part_homes[i]
		var motion: Vector2i = entity.sim_pos - entity.sim_prev
		result.append(PackedInt32Array([offset.x, offset.y, motion.x, motion.y]))
	return result


## The mover part a hero stands on (his feet on its top, within its box), null when none.
func platform_under(p_hero: PlayerBase) -> SimEntity:
	if not p_hero.on_platform:
		return null
	for part: Dictionary in mover_parts:
		var entity: SimEntity = part["entity"]
		var box: Rect2i = entity.get_box()
		if absi(p_hero.sim_pos.y - box.position.y) <= 2 and p_hero.sim_pos.x >= box.position.x - 8 \
				and p_hero.sim_pos.x < box.end.x + 8:
			return entity
	return null


## Index of a mover part entity in [member mover_parts] (-1 when none).
func part_index(entity: SimEntity) -> int:
	for i: int in mover_parts.size():
		if mover_parts[i]["entity"] == entity:
			return i
	return -1


## Put the movement limits of weight class `weight_class` (NavGraph.WEIGHT_*) on a hero, as the referee does every
## tick of a versus round (PlayerBase.walk_cap_override, jump_scale_3_4; PHYSICS.md C.14).
static func apply_weight(p_hero: PlayerBase, p_class: int) -> void:
	p_hero.walk_cap_override = NavGraph.class_walk_cap(p_class)
	p_hero.jump_scale_3_4 = NavGraph.class_jumps_short(p_class)


## Plug every geyser but `index`, whose cycle is moved so that its first spout tick is the next tick (Sim.tick + 1).
func _arm_geysers(index: int) -> void:
	for i: int in geysers.size():
		var geyser: SimEntity = geysers[i]
		if not is_instance_valid(geyser):
			continue
		geyser.set(&"plugged", i != index)
		geyser.set(&"state", 0)
		if i == index:
			var period: int = maxi(int(geyser.get(&"period")), Tuning.GEYSER_PERIOD_MIN)
			geyser.set(&"delay", Sim.tick + 1 - (period - Tuning.GEYSER_SPOUT_TICKS))


## The cycle [period, delay, at] a geyser link of geyser `index` waits for on the real level: the level file's
## period and delay, `at` = the first spout tick of the cycle.
func geyser_cycle(index: int) -> PackedInt32Array:
	var geyser: SimEntity = geysers[index]
	var period: int = maxi(int(geyser.get(&"period")), Tuning.GEYSER_PERIOD_MIN)
	var delay: int = int(geyser.spawn_params.get("delay", 0))
	return PackedInt32Array([period, delay, period - Tuning.GEYSER_SPOUT_TICKS])


func _geyser_launches() -> int:
	var total: int = 0
	for geyser: SimEntity in geysers:
		if is_instance_valid(geyser):
			total += int(geyser.get(&"launches")) if geyser.get(&"launches") != null else 0
	return total


## Play `flags` from rest at `start` and return the hero's club origin and club box (feet-relative, facing as he
## faced) on every tick a box existed: [{"tick", "origin": Vector2i, "box": Rect2i, "facing"}]. For strike geometry.
func strike_frames(start: Vector2i, flags: PackedInt32Array) -> Array[Dictionary]:
	var frames: Array[Dictionary] = []
	_reset_world()
	_arm_geysers(-1)
	hero.respawn_at(start)
	apply_weight(hero, weight_class)
	_flags = flags
	_first_tick = Sim.tick + 1
	GameInput.set_scripted_slot(0, _script_flags)
	for t: int in range(1, flags.size() + 1):
		Sim.step(1)
		ticks_simulated += 1
		if hero.club_box_active:
			frames.append({
				"tick": t, "origin": hero.club_origin - hero.sim_pos, "facing": hero.facing,
				"box": Rect2i(hero.club_box.position - hero.sim_pos, hero.club_box.size),
			})
	GameInput.clear_scripted_slot(0)
	return frames


## The state from which every link of a graph was verified (respawn_at): standing still on the ground, no jump
## lock-out, no strike, no hurt, no charge, not crouching. HeroBot waits for it before it plays a link.
static func is_settled(p_hero: PlayerBase) -> bool:
	return p_hero.grounded and not p_hero.on_platform and p_hero.xvel == 0 and p_hero.yvel == 0 \
			and p_hero.no_jump == 0 and p_hero.swing_lock == 0 and not p_hero.attack_gate and p_hero.hit_timer == 0 \
			and p_hero.charge == 0 and p_hero.drop_timer == 0 and p_hero.jump_ticks == 0 and not p_hero.dead \
			and p_hero.state != Defs.HeroState.CROUCH and p_hero.state != Defs.HeroState.CRAWL \
			and p_hero.squash == 0 and p_hero.hit_stop == 0 and not p_hero.is_down() and not p_hero.is_curled()


## [method is_settled] for a hero standing on a platform (a mover node): carried, not walking on it, no jump, strike,
## hurt, charge or crouch.
static func is_settled_on_mover(p_hero: PlayerBase) -> bool:
	return p_hero.on_platform and p_hero.xvel == 0 and p_hero.no_jump == 0 and p_hero.swing_lock == 0 \
			and not p_hero.attack_gate and p_hero.hit_timer == 0 and p_hero.charge == 0 and p_hero.drop_timer == 0 \
			and p_hero.jump_ticks == 0 and not p_hero.dead and p_hero.state != Defs.HeroState.CROUCH \
			and p_hero.state != Defs.HeroState.CRAWL and p_hero.squash == 0 and p_hero.hit_stop == 0 \
			and not p_hero.is_down() and not p_hero.is_curled()


func _script_flags(tick: int) -> int:
	var index: int = tick - _first_tick
	return _flags[index] if index >= 0 and index < _flags.size() else 0


func _reset_world() -> void:
	level.shake = 0
	level.shake_offset = 0
	level.wind = 0
	# Effects spawned by the last run (dust, rings) end with queue_free(), which needs a rendered frame; the baker
	# runs thousands of runs without one, so they are freed here (or they would pile up and keep ticking). The movers
	# go too and come back fresh.
	for child: Node in level.get_children():
		if child == hero or child == _wrap_driver or _springs.has(child):
			continue
		level.remove_child(child)
		child.free()
	_spawn_movers()


func _spawn_movers() -> void:
	movers.clear()
	mover_parts.clear()
	for index: int in mover_records.size():
		var record: Dictionary = mover_records[index]
		var params: Dictionary = (record["params"] as Dictionary).duplicate()
		var node: Node = level.spawn(record["id"], LevelText.cell_to_feet(float(record["col"]), float(record["row"]),
				params), params)
		var entity: SimEntity = node as SimEntity
		movers.append(entity)
		if entity == null:
			continue
		if entity is PlatformBase:
			mover_parts.append({"mover": index, "part": -1, "entity": entity})
			continue
		var part: int = 0
		for child: Node in entity.get_children():
			if child is PlatformBase:
				mover_parts.append({"mover": index, "part": part, "entity": child})
				part += 1


func _spring_launches() -> int:
	var total: int = 0
	for spring: SimEntity in _springs:
		if is_instance_valid(spring):
			total += int(spring.get("launches")) if spring.get("launches") != null else 0
	return total
