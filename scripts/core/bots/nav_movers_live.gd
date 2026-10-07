class_name NavMoversLive
extends RefCounted
## The live side of a graph's mover nodes (NavGraph header, [NavMovers]): finds the platforms of a running level that
## belong to the graph's movers and writes where they are into the graph every tick, so that [method
## NavGraph.node_at] and the navigator see the mover nodes where the platforms are now. Owner: core-B.
##
## A mover is found by the feet point it was spawned at (SimEntity.spawn_pos = the graph mover's "x", "y") and, for a
## see-saw end, its index among the see-saw's platform children ("part"). Read-only on the level.

## Live entity per mover index of the graph it was bound to (null = not found).
var entities: Array[SimEntity] = []
var _graph: NavGraph = null
var _level: LevelBase = null
var _tops: Array[Vector2i] = []


## Bind to `level` and `graph` (once per level; a graph without movers costs nothing).
func bind(level: LevelBase, graph: NavGraph) -> void:
	_level = level
	_graph = graph
	entities.clear()
	_tops.clear()
	if graph == null or level == null:
		return
	for mover: Dictionary in graph.movers:
		var entity: SimEntity = find(level, mover)
		entities.append(entity)
		var top: Variant = mover.get("top", [0, 0])
		_tops.append(Vector2i(int(top[0]), int(top[1])) if top is Array and (top as Array).size() >= 2 else Vector2i.ZERO)


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
