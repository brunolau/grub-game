class_name BotNavigator
extends RefCounted
## Turns "go to that feet point" into the flags a human would press, on a level's [NavGraph] (DESIGN.md E.7).
##
## Owner: core-B. Used by [HeroBot] once per tick (GameInput.sample(), between ticks). Inside a node it walks and
## brakes onto the target x (the braking distance is the hero's own friction rule, PHYSICS.md 5.1). Between nodes it
## follows the cheapest path of links: it walks into the next link's take-off window, waits until the hero is at rest
## (NavSim.is_settled - the state every link was verified from), then plays the link's script until he lands. A link
## that does not land where it should (and was not disturbed by a hit) is retried once, then blocked for this bot until
## the level changes, and the path is planned again. Everything is integer and deterministic.

## Re-plan the path at most this often while walking (ticks).
const REPLAN_TICKS: int = 12
## A link that misses its target this often (undisturbed) is not used again on this level.
const LINK_FAILURES_TO_BLOCK: int = 2
## Ticks without progress before the navigator tries a hop.
const STUCK_TICKS: int = 24
## Ticks a link may run at most (a stuck script ends).
const LINK_MAX_TICKS: int = 120

var graph: NavGraph = null
## Link ids not to use (id -> true).
var blocked: Dictionary = {}
## Grub Stack weight class of the hero (0 light, 1 = 10+ units, 2 = 20+; PHYSICS.md C.14): a heavy hero walks and
## jumps shorter than the hero the graph was verified with, so links are blocked per weight class.
var weight_class: int = 0
var _blocked_by_weight: Array[Dictionary] = [{}, {}, {}]
var _failures_by_weight: Array[Dictionary] = [{}, {}, {}]
## The target feet point and the node it belongs to (-1 = none).
var target: Vector2i = Vector2i.ZERO
var target_node: int = -1
## How close (px) the feet must get to target.x.
var tolerance: int = 4
## The link being played (null = none), the tick its first input was sampled, and what happened so far.
var link: NavGraph.NavLink = null
var link_tick: int = 0
var link_airborne: bool = false
var link_disturbed: bool = false
## Statistics (tests): links played, links that landed where they should, links blocked.
var links_played: int = 0
var links_landed: int = 0
var links_failed: int = 0
## The last undisturbed misses (at most 8): "link <id> (<from> -> <to>, <keys>) from x <x> ended on node <n> at <pos>".
var failure_log: PackedStringArray = PackedStringArray()
var _link_start_x: int = 0

var _path: PackedInt32Array = PackedInt32Array()
var _path_from: int = -1
var _path_age: int = 0
var _failures: Dictionary = {}
var _last_x: int = -(1 << 30)
var _still: int = 0
var _hop: int = 0


func _init(p_graph: NavGraph = null) -> void:
	graph = p_graph
	blocked = _blocked_by_weight[0]
	_failures = _failures_by_weight[0]


## Forget the path, the link and the blocked links (a new level, a respawn).
func reset() -> void:
	link = null
	_path = PackedInt32Array()
	_path_from = -1
	_path_age = 0
	for i: int in _blocked_by_weight.size():
		_blocked_by_weight[i].clear()
		_failures_by_weight[i].clear()
	weight_class = 0
	blocked = _blocked_by_weight[0]
	_failures = _failures_by_weight[0]
	_still = 0
	_hop = 0
	_last_x = -(1 << 30)


## Switch to the links known to work for weight class `p_class` (0..2; the stack on the head, PHYSICS.md C.14).
func set_weight_class(p_class: int) -> void:
	var value: int = clampi(p_class, 0, _blocked_by_weight.size() - 1)
	if value == weight_class:
		return
	weight_class = value
	blocked = _blocked_by_weight[value]
	_failures = _failures_by_weight[value]
	_path = PackedInt32Array()


## Aim at the feet point `pos` (the node under it; the nearest node when there is none).
func set_target(pos: Vector2i, p_tolerance: int = 4) -> void:
	tolerance = maxi(p_tolerance, 0)
	if pos == target and target_node >= 0:
		return
	target = pos
	var node: int = -1
	if graph != null:
		node = graph.node_at(pos)
		if node < 0:
			node = graph.node_below(pos)
		if node < 0:
			node = graph.nearest_node(pos)
	if node != target_node:
		# Another node: plan again (a target moving along one node keeps the path; the last walk follows it).
		target_node = node
		_path = PackedInt32Array()


## True while a link script is being played (the bot is committed to the move).
func is_busy() -> bool:
	return link != null


## The node the hero stands on (-1 in the air or off the graph).
func node_of(hero: PlayerBase) -> int:
	if graph == null or not hero.is_grounded():
		return -1
	return graph.node_at(hero.sim_pos)


## True when the hero stands on the target node within the tolerance of target.x.
func arrived(hero: PlayerBase) -> bool:
	if not hero.is_grounded():
		return false
	var node: int = node_of(hero)
	if graph != null and node != target_node:
		return false
	return absi(hero.sim_pos.x - target.x) <= tolerance


## Estimated ticks for `hero` to reach `pos` (UNREACHABLE when the graph has no route).
func cost_to(hero: PlayerBase, pos: Vector2i) -> int:
	if graph == null:
		return NavGraph.walk_ticks(pos.x - hero.sim_pos.x)
	var from: int = node_of(hero)
	if from < 0:
		from = graph.node_below(hero.sim_pos)
	if from < 0:
		from = graph.nearest_node(hero.sim_pos)
	var to: int = graph.node_at(pos)
	if to < 0:
		to = graph.node_below(pos)
	if to < 0:
		return NavGraph.UNREACHABLE
	return graph.path_cost(from, hero.sim_pos.x, to, pos.x, blocked)


## The flags for this tick (`tick` = the tick about to run, Sim.tick of GameInput.sample()).
func step(hero: PlayerBase, tick: int) -> int:
	if link != null:
		var link_flags: int = _play_link(hero, tick)
		if link != null:
			return link_flags
	_track_progress(hero)
	if not hero.is_grounded():
		# In the air (knocked back, falling): steer toward the target column.
		return _toward(target.x - hero.sim_pos.x, 0)
	if graph == null or target_node < 0:
		return walk_to(hero, target.x, tolerance)
	var here: int = graph.node_at(hero.sim_pos)
	if here < 0:
		# On a floor the graph does not know (a sliver by a wall): walk toward the target, hop when stuck.
		return _unstick(hero, walk_to(hero, target.x, tolerance))
	if here == target_node:
		_path = PackedInt32Array()
		return walk_to(hero, target.x, tolerance)
	_path_age += 1
	if _path.is_empty() or _path_from != here or _path_age >= REPLAN_TICKS:
		_path = graph.find_path(here, hero.sim_pos.x, target_node, target.x, blocked)
		_path_from = here
		_path_age = 0
	if _path.is_empty():
		# No route: get as close as this node allows.
		return walk_to(hero, graph.nodes[here].clamp_x(target.x), tolerance)
	var next: NavGraph.NavLink = graph.links[_path[0]]
	var center: int = next.window_center()
	var inside: bool = hero.sim_pos.x >= next.x0 and hero.sim_pos.x <= next.x1
	if inside and NavSim.is_settled(hero):
		return _start_link(hero, next, tick)
	var half: int = maxi((next.x1 - next.x0) / 2, 0)
	var flags: int = walk_to(hero, center, half)
	return _unstick(hero, flags)


## Flags that walk the hero to `x` and stop him within `tol` px (0 = there, or braking).
static func walk_to(hero: PlayerBase, x: int, tol: int) -> int:
	var dx: int = x - hero.sim_pos.x
	var v: int = hero.xvel
	var ice: int = hero.ice
	if absi(dx) <= tol:
		# Inside: brake (no input); a tap would only push him out again.
		return 0
	var slide: int = stop_distance(v, ice)
	if dx > 0:
		if v > 0 and hero.sim_pos.x + slide >= x - tol:
			return 0
		return Defs.IN_RIGHT
	if v < 0 and hero.sim_pos.x + slide <= x + tol:
		return 0
	return Defs.IN_LEFT


## Signed px a hero moving at `v` (v16) slides on the ground before he stands, with no input (PHYSICS.md 5.1:
## friction 12 >> ice per tick, then the x step with floor16).
static func stop_distance(v: int, ice: int) -> int:
	var distance: int = 0
	var speed: int = v
	var step_size: int = maxi(Tuning.friction_step(ice), 1)
	var guard: int = 0
	while speed != 0 and guard < 400:
		var magnitude: int = maxi(absi(speed) - step_size, 0)
		speed = -magnitude if speed < 0 else magnitude
		distance += Tuning.floor16(speed)
		guard += 1
	return distance


func _start_link(hero: PlayerBase, next: NavGraph.NavLink, tick: int) -> int:
	link = next
	_link_start_x = hero.sim_pos.x
	link_tick = tick
	link_airborne = false
	link_disturbed = false
	links_played += 1
	return _play_link(hero, tick)


func _play_link(hero: PlayerBase, tick: int) -> int:
	var index: int = tick - link_tick
	if index > 0:
		# What the last tick did: hit, bumped by another hero, airborne, landed.
		if hero.hit_timer > 0 or hero.dead or hero.is_down() or _touches_other_hero(hero):
			link_disturbed = true
		if not hero.is_grounded():
			link_airborne = true
		elif link_airborne:
			_finish_link(hero)
			return 0
	if index >= link.flags.size() or index >= LINK_MAX_TICKS:
		if hero.is_grounded() and not link_airborne:
			# The script ended without leaving the ground.
			_finish_link(hero)
			return 0
		return 0 if index < LINK_MAX_TICKS else _abort_link()
	return link.flags[index]


func _finish_link(hero: PlayerBase) -> void:
	var landed: int = graph.node_at(hero.sim_pos) if hero.is_grounded() else -1
	if landed == link.to:
		links_landed += 1
	elif not link_disturbed:
		links_failed += 1
		if failure_log.size() >= 8:
			failure_log.remove_at(0)
		failure_log.append("link %d (%d -> %d, %s) from x %d ended on node %d at %s" % [
			link.id, link.from, link.to, link.keys, _link_start_x, landed, hero.sim_pos,
		])
		var count: int = int(_failures.get(link.id, 0)) + 1
		_failures[link.id] = count
		if count >= LINK_FAILURES_TO_BLOCK:
			blocked[link.id] = true
	link = null
	_path = PackedInt32Array()


## True when another living hero's body overlaps this one's (a body bump or a head to stand on changes the move: the
## link was not at fault).
static func _touches_other_hero(hero: PlayerBase) -> bool:
	var level: LevelBase = Game.level
	if level == null:
		return false
	for other: PlayerBase in level.heroes:
		if other == null or other == hero or other.dead or other.is_down():
			continue
		if absi(other.sim_pos.x - hero.sim_pos.x) < Tuning.HERO_BOX_STAND.x \
				and absi(other.sim_pos.y - hero.sim_pos.y) < Tuning.HERO_BOX_STAND.y + 4:
			return true
	return false


func _abort_link() -> int:
	link = null
	_path = PackedInt32Array()
	return 0


func _track_progress(hero: PlayerBase) -> void:
	if hero.sim_pos.x == _last_x:
		_still += 1
	else:
		_still = 0
	_last_x = hero.sim_pos.x
	if _hop > 0:
		_hop -= 1


## A hero pushing against something for STUCK_TICKS hops once (UP for 8 ticks with the direction).
func _unstick(hero: PlayerBase, flags: int) -> int:
	if flags == 0:
		_still = 0
		return flags
	if _hop > 0:
		return flags | Defs.IN_UP
	if _still >= STUCK_TICKS and hero.is_grounded() and hero.no_jump == 0:
		_still = 0
		_hop = 8
		return flags | Defs.IN_UP
	return flags


static func _toward(dx: int, dead_zone: int) -> int:
	if dx > dead_zone:
		return Defs.IN_RIGHT
	if dx < -dead_zone:
		return Defs.IN_LEFT
	return 0
