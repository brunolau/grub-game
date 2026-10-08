class_name NavMoversLive
extends RefCounted
## The live side of a graph's mover nodes (NavGraph header, [NavMovers]): finds the platforms of a running level that
## belong to the graph's movers and writes where they are into the graph every tick, so that [method
## NavGraph.node_at] and the navigator see the mover nodes where the platforms are now. Owner: core-B.
##
## A mover is found by the feet point it was spawned at (SimEntity.spawn_pos = the graph mover's "x", "y") and, for a
## see-saw end, its index among the see-saw's platform children ("part"). Read-only on the level.
##
## Pulley lifts (core-B wf10): [method pulley_plan] says at which pulley offset a hero can use a lift's links - the
## state the pulley will rest in when he boards the lift, and while he rides it - from what anyone sees: where the
## lifts are and who stands on them (objects-B's Pulley: the heavier side sinks to its limit, equal weights stay).

## Live entity per mover index of the graph it was bound to (null = not found).
var entities: Array[SimEntity] = []
var _graph: NavGraph = null
var _level: LevelBase = null
var _tops: Array[Vector2i] = []
# The pulleys of the graph: pulley id -> {"a": mover index (side +1) or -1, "b": mover index (side -1) or -1,
# "limit": px}.
var _pulleys: Dictionary = {}


## Bind to `level` and `graph` (once per level; a graph without movers costs nothing).
func bind(level: LevelBase, graph: NavGraph) -> void:
	_level = level
	_graph = graph
	entities.clear()
	_tops.clear()
	_pulleys.clear()
	if graph == null or level == null:
		return
	for i: int in graph.movers.size():
		var mover: Dictionary = graph.movers[i]
		var entity: SimEntity = find(level, mover)
		entities.append(entity)
		var top: Variant = mover.get("top", [0, 0])
		_tops.append(Vector2i(int(top[0]), int(top[1])) if top is Array and (top as Array).size() >= 2 else Vector2i.ZERO)
		if mover.has("pulley"):
			var id: int = int(mover["pulley"])
			var group: Dictionary = _pulleys.get(id, {"a": -1, "b": -1, "limit": int(mover.get("limit", 0))})
			group["a" if int(mover.get("side", 1)) > 0 else "b"] = i
			_pulleys[id] = group


## Write the movers' live offsets and motions into the graph (call once per tick before planning).
func update() -> void:
	if _graph == null or entities.is_empty():
		return
	for i: int in entities.size():
		var entity: SimEntity = entities[i]
		if entity == null or not is_instance_valid(entity):
			continue
		var box: Rect2i = entity.get_box()
		var motion: Vector2i = entity.sim_pos - entity.sim_prev
		_graph.set_mover_state(i, box.position - _tops[i], motion)


## True when the bound graph has pulley lifts.
func has_pulleys() -> bool:
	return not _pulleys.is_empty()


## Per graph mover index of a pulley lift: Vector2i(the pulley offset its board links need - where the pulley rests
## with `hero` off it -, the offset its off links need - where it rests with him on that lift). The weights are the
## lifts' riders now (PlatformBase.rider_weight) without `hero`, plus his own on the lift he rides in the second case;
## the offset is the pulley's after its pending step (Pulley.offset), else the lift's live one.
func pulley_plan(hero: PlayerBase) -> Dictionary:
	var plan: Dictionary = {}
	if _graph == null or hero == null:
		return plan
	var own: int = PartyTuning.PLATE_WEIGHT_HERO
	for id: Variant in _pulleys:
		var group: Dictionary = _pulleys[id]
		var a: int = int(group["a"])
		var b: int = int(group["b"])
		var limit: int = int(group["limit"])
		var lift_a: PlatformBase = _lift(a)
		var lift_b: PlatformBase = _lift(b)
		var p: int = _graph.mover_offset(a).y if a >= 0 else -_graph.mover_offset(b).y
		var pulley: Object = null
		for lift: PlatformBase in [lift_a, lift_b]:
			if lift != null and pulley == null:
				pulley = lift.get(&"pulley") as Object
		if pulley != null and is_instance_valid(pulley) and pulley.get(&"offset") != null:
			p = int(pulley.get(&"offset"))
		var weight_a: int = _weight_without(lift_a, hero)
		var weight_b: int = _weight_without(lift_b, hero)
		var on_a: bool = _rides(lift_a, hero)
		var on_b: bool = _rides(lift_b, hero)
		var ground: int = NavGraph.pulley_rest(p, weight_a, weight_b, limit)
		if a >= 0:
			plan[a] = Vector2i(ground, NavGraph.pulley_rest(p if on_a else ground, weight_a + own, weight_b, limit))
		if b >= 0:
			plan[b] = Vector2i(ground, NavGraph.pulley_rest(p if on_b else ground, weight_a, weight_b + own, limit))
	return plan


func _lift(index: int) -> PlatformBase:
	if index < 0 or index >= entities.size():
		return null
	var entity: SimEntity = entities[index]
	if entity == null or not is_instance_valid(entity):
		return null
	return entity as PlatformBase


## True when `hero` rode `lift` in its last ride test.
static func _rides(lift: PlatformBase, hero: PlayerBase) -> bool:
	return lift != null and (lift.rider_mask & (1 << hero.slot)) != 0


## The weight on `lift` without `hero` (0 for none).
static func _weight_without(lift: PlatformBase, hero: PlayerBase) -> int:
	if lift == null:
		return 0
	var weight: int = lift.rider_weight()
	if _rides(lift, hero) and hero.counts_for_coop():
		weight -= PartyTuning.PLATE_WEIGHT_HERO
	return maxi(weight, 0)


## The live entity of a graph mover ({"x", "y", "part"}) in `level`; null when none.
static func find(level: LevelBase, mover: Dictionary) -> SimEntity:
	var at: Vector2i = Vector2i(int(mover.get("x", 0)), int(mover.get("y", 0)))
	var part: int = int(mover.get("part", -1))
	for kind: int in [Defs.Kind.PLATFORM, Defs.Kind.OTHER]:
		for entity: SimEntity in level.get_kind(kind):
			if entity.spawn_pos != at:
				continue
			if part < 0:
				if entity is PlatformBase:
					return entity
				continue
			var index: int = 0
			for child: Node in entity.get_children():
				if child is PlatformBase:
					if index == part:
						return child as SimEntity
					index += 1
	return null


## True when the live mover of `cond` ([mover, dx, dy, mx, my]) is where and how the link was verified.
static func matches(graph: NavGraph, cond: PackedInt32Array) -> bool:
	if graph == null or cond.size() < 5:
		return true
	return graph.mover_offset(cond[0]) == Vector2i(cond[1], cond[2]) \
			and graph.mover_motion(cond[0]) == Vector2i(cond[3], cond[4])
