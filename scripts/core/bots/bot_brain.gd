class_name BotBrain
extends RefCounted
## The decisions of a [HeroBot] in one versus mode (DESIGN.md E.7): [method think] chooses a goal every
## VersusTuning.BOT_GOAL_PERIOD_TICKS by utility, [method act] turns the goal and the combat micro-rules into this
## tick's flags. Owner: core-B. This base class only wanders (a mode without a brain of its own); see [GrubStackBrain].
##
## Shared helpers: the strike geometry of the club (Tuning.STRIKE_SCRIPT_* / CLUB_ORIGIN / CLUB_BOX, PHYSICS.md 8.1 -
## 8.3), where to stand to strike a spot, timed actions (hold some flags for n ticks), wandering.

## Strike kinds: the keys pressed with the facing direction, and the frames they play.
const STRIKE_FORWARD: int = 0
const STRIKE_HIGH: int = 1
const STRIKE_LOW: int = 2
const STRIKE_FLAGS: Array[int] = [Defs.IN_FIRE, Defs.IN_FIRE | Defs.IN_UP, Defs.IN_FIRE | Defs.IN_DOWN]
## Ticks a wander target is kept at most.
const WANDER_TICKS: int = 146

## The bot this brain decides for (held weakly: the bot owns the brain, so a strong reference back would be a
## reference cycle that never frees).
var bot: HeroBot:
	get:
		return _bot_ref.get_ref() as HeroBot if _bot_ref != null else null
	set(value):
		_bot_ref = weakref(value) if value != null else null
var _bot_ref: WeakRef = null
static var _stand_cache: Dictionary = {}


## Forget the cached spot stands (tests; a re-baked graph).
static func clear_cache() -> void:
	_stand_cache.clear()
## The timed action being held (flags) and its ticks left.
var action_flags: int = 0
var action_ticks: int = 0
var _wander: Vector2i = Vector2i(-1, -1)
var _wander_age: int = 0


## Forget goals and actions (a new level or round).
func reset() -> void:
	action_flags = 0
	action_ticks = 0
	_wander = Vector2i(-1, -1)
	_wander_age = 0


## True when the brain wants a decision this tick outside the regular period (no goal yet).
func needs_thinking(_tick: int) -> bool:
	return false


## Choose a goal (every VersusTuning.BOT_GOAL_PERIOD_TICKS ticks).
func think(hero: PlayerBase, _level: LevelBase, _tick: int) -> void:
	wander_target(hero)


## The flags of this tick.
func act(hero: PlayerBase, _level: LevelBase, tick: int) -> int:
	if bot.nav.is_busy():
		return bot.nav.step(hero, tick)
	if action_ticks > 0:
		return hold_action()
	if _wander.x < 0:
		_pick_wander(hero)
	bot.nav.set_target(_wander, 6)
	return bot.nav.step(hero, tick)


## Start holding `flags` for `ticks` ticks (a strike, a crouch).
func start_action(flags: int, ticks: int) -> int:
	action_flags = flags
	action_ticks = ticks
	return hold_action()


## One tick of the held action.
func hold_action() -> int:
	if action_ticks <= 0:
		return 0
	action_ticks -= 1
	return action_flags


## Direction flag toward `dx` (0 when dx is 0).
static func dir_flag(dx: int) -> int:
	if dx > 0:
		return Defs.IN_RIGHT
	if dx < 0:
		return Defs.IN_LEFT
	return 0


## Ticks a strike kind takes (its script length).
static func strike_ticks(kind: int) -> int:
	match kind:
		STRIKE_HIGH:
			return Tuning.STRIKE_SCRIPT_HIGH.size()
		STRIKE_LOW:
			return Tuning.STRIKE_SCRIPT_LOW.size()
	return Tuning.STRIKE_SCRIPT_FORWARD.size()


static func _frames(kind: int) -> Array[int]:
	match kind:
		STRIKE_HIGH:
			return Tuning.STRIKE_SCRIPT_HIGH
		STRIKE_LOW:
			return Tuning.STRIKE_SCRIPT_LOW
	return Tuning.STRIKE_SCRIPT_FORWARD


## True when a strike of `kind` by a hero standing still at `feet` facing `facing` would hit the hidden cell `cell`
## on one of its frames (the hidden-tile test of PHYSICS.md 8.3 #2 on the club origin).
static func strike_hits_cell(feet: Vector2i, facing: int, kind: int, cell: Vector2i) -> bool:
	for frame: int in _frames(kind):
		var origin: Vector2i = Tuning.CLUB_ORIGIN[frame]
		var ox: int = feet.x + facing * origin.x
		var oy: int = feet.y + origin.y
		if absi(cell.x - (ox >> 4)) <= Tuning.HIDDEN_HIT_COLS \
				and absi(cell.y * Tuning.TILE - (oy - Tuning.TILE)) < Tuning.HIDDEN_HIT_PX:
			return true
	return false


## The club box of the front frame of a strike (forward: FWD_FRONT, high: HIGH_FRONT, low: LOW_FRONT) for a hero at
## `feet` facing `facing`, in level px.
static func front_box(feet: Vector2i, facing: int, kind: int) -> Rect2i:
	var frame: int = Tuning.ClubFrame.FWD_FRONT
	if kind == STRIKE_HIGH:
		frame = Tuning.ClubFrame.HIGH_FRONT
	elif kind == STRIKE_LOW:
		frame = Tuning.ClubFrame.LOW_FRONT
	var rect: Rect2i = Tuning.CLUB_BOX[frame]
	var origin: Vector2i = Tuning.CLUB_ORIGIN[frame]
	var xo: int = origin.x - rect.position.x
	var ox: int = feet.x + facing * origin.x
	return Rect2i(ox - xo, feet.y + rect.position.y, rect.size.x, rect.size.y)


## The standing body box of a hero whose feet are at `feet` (Tuning.HERO_BOX_STAND, x_offset centred).
static func body_box(feet: Vector2i) -> Rect2i:
	var box: Vector3i = Tuning.HERO_BOX_STAND
	return Rect2i(feet.x - box.z, feet.y - box.y, box.x, box.y)


## Every place to stand to strike the hidden cell `cell` from: [{"node", "x0", "x1", "x", "facing", "kind"}], one per
## (node, strike kind, facing) - the longest run of feet x on that node from which a strike of that kind, facing
## that way, reaches the cell (never from inside the cell's own column); `x` is the run's middle. Ordered by
## preference: forward strikes first, then high, then low; wider runs first. Cached per graph and cell (the stands of
## a level never change).
static func spot_stands(graph: NavGraph, cell: Vector2i) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if graph == null:
		return result
	var key: String = "%s:%d:%d:%d" % [graph.level_id, graph.get_instance_id(), cell.x, cell.y]
	if _stand_cache.has(key):
		return _stand_cache[key]
	for node: NavGraph.NavNode in graph.nodes:
		if absi(node.row - cell.y) > 4 or node.x1 < (cell.x - 3) * Tuning.TILE or node.x0 > (cell.x + 4) * Tuning.TILE:
			continue
		for kind: int in [STRIKE_FORWARD, STRIKE_HIGH, STRIKE_LOW]:
			for facing: int in [1, -1]:
				var best0: int = 0
				var best1: int = -1
				var run0: int = -1
				for x: int in range(node.x0, node.x1 + 2):
					var hits: bool = x <= node.x1 and (x >> 4) != cell.x 							and strike_hits_cell(Vector2i(x, node.y), facing, kind, cell)
					if hits and run0 < 0:
						run0 = x
					elif not hits and run0 >= 0:
						if x - 1 - run0 > best1 - best0:
							best0 = run0
							best1 = x - 1
						run0 = -1
				if best1 >= best0:
					result.append({
						"node": node.id, "x0": best0, "x1": best1, "x": (best0 + best1) / 2, "facing": facing,
						"kind": kind,
					})
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["kind"]) != int(b["kind"]):
			return int(a["kind"]) < int(b["kind"])
		var wa: int = int(a["x1"]) - int(a["x0"])
		var wb: int = int(b["x1"]) - int(b["x0"])
		if wa != wb:
			return wa > wb
		if int(a["node"]) != int(b["node"]):
			return int(a["node"]) < int(b["node"])
		return int(a["x0"]) < int(b["x0"])
	)
	_stand_cache[key] = result
	return result


func _pick_wander(hero: PlayerBase) -> void:
	var graph: NavGraph = bot.nav.graph
	if graph == null or graph.nodes.is_empty():
		_wander = Vector2i(hero.sim_pos.x + (bot.rng.range_int(-80, 80)), hero.sim_pos.y)
	else:
		var node: NavGraph.NavNode = graph.nodes[bot.rng.next_int(graph.nodes.size())]
		_wander = Vector2i(bot.rng.range_int(node.x0, node.x1), node.y)
	_wander_age = 0


## Keep a wander target for a while, then pick a new one; returns the target. Called once per decision
## (every VersusTuning.BOT_GOAL_PERIOD_TICKS ticks).
func wander_target(hero: PlayerBase) -> Vector2i:
	_wander_age += VersusTuning.BOT_GOAL_PERIOD_TICKS
	if _wander.x < 0 or _wander_age > WANDER_TICKS or (bot.nav.arrived(hero) and bot.nav.target == _wander):
		_pick_wander(hero)
	return _wander
