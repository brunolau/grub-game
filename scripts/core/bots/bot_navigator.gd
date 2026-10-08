class_name BotNavigator
extends RefCounted
## Turns "go to that feet point" into the flags a human would press, on a level's [NavGraph] (DESIGN.md E.7).
##
## Owner: core-B. Used by [HeroBot] once per tick (GameInput.sample(), between ticks). Inside a node it walks and
## brakes onto the target x (the braking distance is the hero's own friction rule, PHYSICS.md 5.1). Between nodes it
## follows the cheapest path of links of its weight class (the Grub Stack stack, the Hot Rock ember: [method
## set_weight_class]): it walks into the next link's take-off window, waits until the hero is at rest
## (NavSim.is_settled - the state every link was verified from) and, for a timed link, until the geyser's spout tick or
## the mover's take-off state, then plays the link's script until he lands. A link that does not land where it should
## (and was not disturbed by a hit, a body, a head under his feet or a geyser) is retried once, then blocked for this
## bot and class until the level changes, and the path is planned again. Everything is integer and deterministic.
##
## In the air without a link (knocked back, falling) it steers toward the target's column; a versus bot
## ([member safe_falls]) lets go or steers back when that push would leave him with nothing to land on under the
## point his drift ends at - a rival's column across a tar pit is no place to fall to (core-B wf10). On the ground
## such a bot never walks past an end of his node beyond which there is nothing to land on ([method _walk_on]:
## walk_to lets go when the slide ends within the tolerance of the goal, which at the last px of a node is up to 2 px
## beyond it), and with no route to his target he waits FALL_MARGIN_PX inside such an end. Where every fall ends on
## a node - a floor from wall to wall, a ledge over a floor, a level that wraps top to bottom - nothing changes.
## Such a bot left with no route on a node whose links he blocked after misses gives them one more try every
## RETRY_BLOCKED_TICKS (Floe Rink: the wind makes the one jump off a floe miss twice, and he stood there to the gong
## - before the edge rule he walked off the floe's end into the water instead).

## Re-plan the path at most this often while walking (ticks).
const REPLAN_TICKS: int = 12
## A link that misses its target this often (undisturbed) is not used again on this level.
const LINK_FAILURES_TO_BLOCK: int = 2
## Ticks without progress before the navigator tries a hop.
const STUCK_TICKS: int = 24
## Ticks a link may run at most (a stuck script ends).
const LINK_MAX_TICKS: int = 120
## Ticks a bot waits in a take-off window for a timed or mover link before it plans around it.
const WAIT_MAX_TICKS: int = 200
## [member safe_falls]: one tick of a direction key in the air changes the speed by at most this (v16), and the ground
## under the point his drift ends at must reach this far (px) on to the side he drifts to.
const AIR_PUSH_V16: int = 32
const FALL_MARGIN_PX: int = 6
## [member safe_falls]: a node that ends at a wall face counts as ground this far (px) into the wall (the longest
## drift a push can add is shorter).
const WALL_REACH_PX: int = 48
## [member safe_falls]: ticks without a route after which the blocked links of the node he stands on get one more try.
const RETRY_BLOCKED_TICKS: int = 72

var graph: NavGraph = null
## Link ids not to use (id -> true), of the current weight class.
var blocked: Dictionary = {}
## Weight class of the hero (NavGraph.WEIGHT_*: the Grub Stack stack, the Hot Rock holder; PHYSICS.md C.14): he walks
## and jumps differently, so he uses the links verified for his class and blocks failures per class.
var weight_class: int = NavGraph.WEIGHT_LIGHT
var _blocked_by_weight: Array[Dictionary] = [{}, {}, {}, {}]
var _failures_by_weight: Array[Dictionary] = [{}, {}, {}, {}]
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
## Statistics (tests): links played, links that landed where they should, links blocked, disturbed ones.
var links_played: int = 0
var links_landed: int = 0
var links_failed: int = 0
var links_disturbed: int = 0
## Ticks spent waiting in take-off windows for timed links (statistics).
var waited_ticks: int = 0
## The last undisturbed misses (at most 8): "link <id> (<from> -> <to>, <keys>) from x <x> ended on node <n> at <pos>".
var failure_log: PackedStringArray = PackedStringArray()
## Never steer a fall to where there is no node to land on ([method _air_flags]) and never walk past the end of a node
## ([method _walk_on]). HeroBot turns it on for the versus bots; a boss body (the Rival Chieftains, whose recorded
## routes replay the navigator) keeps the plain rules.
var safe_falls: bool = false
## Statistics: ticks on which [member safe_falls] changed the air steering / the walk, and blocked links tried again.
var falls_steered: int = 0
var edges_held: int = 0
var links_retried: int = 0
var _stranded: int = 0
var _link_start_x: int = 0

var _path: PackedInt32Array = PackedInt32Array()
var _path_from: int = -1
var _path_age: int = 0
var _failures: Dictionary = {}
# Links not to plan with on a level with pulley lifts (core-B wf10): [member blocked] plus the pulley links of every
# pulley state but the one the pulley will rest in for this hero ([method update_movers]); "" = none (plan with
# `blocked` alone).
var _avoid: Dictionary = {}
var _avoid_key: String = ""
var _pulley_links: PackedInt32Array = PackedInt32Array()
var _clear_links: PackedInt32Array = PackedInt32Array()
var _pulley_graph: NavGraph = null
var _last_x: int = -(1 << 30)
var _still: int = 0
var _hop: int = 0
var _wait: int = 0


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
	weight_class = NavGraph.WEIGHT_LIGHT
	blocked = _blocked_by_weight[0]
	_failures = _failures_by_weight[0]
	_still = 0
	_hop = 0
	_wait = 0
	_last_x = -(1 << 30)
	_avoid = {}
	_avoid_key = ""
	_stranded = 0


## Pulley lifts (core-B wf10, wf9_da_to_core_b.txt #1): plan only with the pulley links of the state the pulley will
## rest in - links onto a lift (and moves that hop off one) at the offset it rests at with this hero off it, links off
## a lift at the offset it rests at with him on that lift (NavMoversLive.pulley_plan). A link past a lift's column
## (NavLink.clear_at) is planned with only while the pulley is, and will rest, where that lift is out of its way
## (NavMoversLive.pulley_states). Call once per tick after `live.update()` and [method set_weight_class]; a level
## without pulley lifts costs nothing.
func update_movers(hero: PlayerBase, live: NavMoversLive) -> void:
	if graph == null or live == null or not live.has_pulleys():
		_avoid_key = ""
		return
	if _pulley_graph != graph:
		_pulley_graph = graph
		_pulley_links = PackedInt32Array()
		_clear_links = PackedInt32Array()
		for candidate: NavGraph.NavLink in graph.links:
			if candidate.cond.size() >= 5 and graph.is_pulley_lift(candidate.cond[0]):
				_pulley_links.append(candidate.id)
			elif candidate.clear_at.size() >= 3:
				_clear_links.append(candidate.id)
	var plan: Dictionary = live.pulley_plan(hero)
	var states: Dictionary = live.pulley_states() if not _clear_links.is_empty() else {}
	var key: String = "%s|%s|%d|%d" % [plan, states, weight_class, blocked.size()]
	if key == _avoid_key:
		return
	_avoid_key = key
	_avoid = blocked.duplicate()
	for id: int in _pulley_links:
		var candidate: NavGraph.NavLink = graph.links[id]
		var mover: int = candidate.cond[0]
		if not plan.has(mover):
			continue
		var want: Vector2i = plan[mover]
		var p: int = want.y if graph.nodes[candidate.from].mover == mover else want.x
		if graph.link_pulley_offset(candidate) != p or candidate.cond[3] != 0 or candidate.cond[4] != 0:
			_avoid[id] = true
	for id: int in _clear_links:
		var candidate: NavGraph.NavLink = graph.links[id]
		if states.has(candidate.clear_at[0]):
			var state: Vector2i = states[candidate.clear_at[0]]
			if not NavGraph.link_clear(candidate, state.x, state.y):
				_avoid[id] = true
	# The planned path may use a pulley link of the old state: plan again.
	_path = PackedInt32Array()


## The links the searches leave out: [member blocked], plus the pulley links of other states ([method update_movers]).
func search_blocked() -> Dictionary:
	return _avoid if _avoid_key != "" else blocked


## Switch to the links known to work for weight class `p_class` (NavGraph.WEIGHT_*).
func set_weight_class(p_class: int) -> void:
	var value: int = clampi(p_class, 0, _blocked_by_weight.size() - 1)
	if value == weight_class:
		return
	weight_class = value
	blocked = _blocked_by_weight[value]
	_failures = _failures_by_weight[value]
	_path = PackedInt32Array()


## The class whose links are used: the hero's when the graph has it, else the light class.
func search_class() -> int:
	return graph.usable_class(weight_class) if graph != null else NavGraph.WEIGHT_LIGHT


## Aim at the feet point `pos` (the node under it; the nearest node when there is none).
func set_target(pos: Vector2i, p_tolerance: int = 4) -> void:
	tolerance = maxi(p_tolerance, 0)
	if pos == target and target_node >= 0:
		return
	target = pos
	var node: int = graph.node_for(pos) if graph != null else -1
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
	return graph.node_at(hero.sim_pos, hero.on_platform)


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
		from = graph.node_for(hero.sim_pos)
	var to: int = graph.node_at(pos)
	if to < 0:
		to = graph.node_below(pos)
	if to < 0:
		return NavGraph.UNREACHABLE
	return graph.path_cost(from, hero.sim_pos.x, to, pos.x, search_blocked(), search_class())


## One search from the hero to every node (NavGraph.reach_from with this bot's class and blocked links).
func reach(hero: PlayerBase) -> Dictionary:
	if graph == null:
		return {}
	var from: int = node_of(hero)
	if from < 0:
		from = graph.node_for(hero.sim_pos)
	return graph.reach_from(from, hero.sim_pos.x, search_blocked(), search_class())


## The flags for this tick (`tick` = the tick about to run, Sim.tick of GameInput.sample()).
func step(hero: PlayerBase, tick: int) -> int:
	if link != null:
		var link_flags: int = _play_link(hero, tick)
		if link != null:
			return link_flags
	_track_progress(hero)
	if not hero.is_grounded():
		# In the air (knocked back, falling): steer toward the target column.
		_wait = 0
		return _air_flags(hero)
	if graph == null or target_node < 0:
		return walk_to(hero, target.x, tolerance)
	var here: int = graph.node_at(hero.sim_pos, hero.on_platform)
	if here < 0:
		# On a floor the graph does not know (a sliver by a wall): walk toward the target, hop when stuck.
		return _unstick(hero, _off_graph_flags(hero))
	if here == target_node:
		_path = PackedInt32Array()
		_wait = 0
		_stranded = 0
		var node: NavGraph.NavNode = graph.nodes[here]
		return _walk_on(hero, clampi(target.x, graph.node_x0(node), graph.node_x1(node)), tolerance, node)
	_path_age += 1
	if _path.is_empty() or _path_from != here or _path_age >= REPLAN_TICKS:
		_path = graph.find_path(here, hero.sim_pos.x, target_node, target.x, search_blocked(), search_class())
		_path_from = here
		_path_age = 0
	if _path.is_empty():
		# No route: get as close as this node allows (a versus bot: not onto the very end of it; and the links he
		# blocked from this node get another try after a while).
		var node: NavGraph.NavNode = graph.nodes[here]
		if safe_falls:
			_retry_blocked(here)
		var inside: int = mini(FALL_MARGIN_PX, (graph.node_x1(node) - graph.node_x0(node)) / 2) if safe_falls else 0
		var lo: int = graph.node_x0(node) + (inside if inside > 0 and _end_drops(node, true) else 0)
		var hi: int = graph.node_x1(node) - (inside if inside > 0 and _end_drops(node, false) else 0)
		return _walk_on(hero, clampi(target.x, lo, hi), tolerance, node)
	_stranded = 0
	var next: NavGraph.NavLink = graph.links[_path[0]]
	var offset: Vector2i = graph.node_offset(graph.nodes[next.from])
	var x0: int = next.x0 + offset.x
	var x1: int = next.x1 + offset.x
	var inside: bool = hero.sim_pos.x >= x0 and hero.sim_pos.x <= x1
	if inside and settled(hero, graph.nodes[next.from]):
		if _may_start(next, tick):
			_wait = 0
			return _start_link(hero, next, tick)
		_wait += 1
		waited_ticks += 1
		if _wait > WAIT_MAX_TICKS:
			# The geyser or mover never came: try another way for a while.
			_wait = 0
			_fail(next, hero, "waited %d ticks" % WAIT_MAX_TICKS)
			_path = PackedInt32Array()
		return 0
	var half: int = maxi((x1 - x0) / 2, 0)
	var flags: int = _walk_on(hero, (x0 + x1) / 2, half, graph.nodes[here])
	return _unstick(hero, flags)


## A tick without a route on node `here`: after RETRY_BLOCKED_TICKS of them the links from this node that were blocked
## after misses are open again, one miss from being blocked once more (the path is planned again on the next tick).
func _retry_blocked(here: int) -> void:
	_stranded += 1
	if _stranded < RETRY_BLOCKED_TICKS:
		return
	_stranded = 0
	for id: int in graph.links_from(here, search_class()):
		if blocked.has(id):
			blocked.erase(id)
			_failures[id] = LINK_FAILURES_TO_BLOCK - 1
			links_retried += 1
			if _avoid_key != "":
				# The pulley list holds a copy of the blocked links: build it again.
				_avoid_key = "retry"


## [method walk_to] for a hero standing on node `node`. With [member safe_falls] the push is taken only while the
## slide it leads to ends on the node; when even letting go would carry him past an end he brakes against it.
func _walk_on(hero: PlayerBase, x: int, tol: int, node: NavGraph.NavNode) -> int:
	var flags: int = walk_to(hero, x, tol)
	if not safe_falls or node == null:
		return flags
	var lo: int = graph.node_x0(node)
	var hi: int = graph.node_x1(node)
	var accel: int = Tuning.ACCEL >> clampi(hero.ice, 0, Tuning.ICE_MAX)
	var push: int = 0
	if (flags & Defs.IN_RIGHT) != 0:
		push = accel
	elif (flags & Defs.IN_LEFT) != 0:
		push = -accel
	var stop: int = hero.sim_pos.x + stop_distance(hero.xvel + push, hero.ice)
	if (stop >= lo or not _end_drops(node, true)) and (stop <= hi or not _end_drops(node, false)):
		return flags
	var coast: int = hero.sim_pos.x + stop_distance(hero.xvel, hero.ice)
	var held: int = 0
	if coast < lo and _end_drops(node, true):
		held = Defs.IN_RIGHT
	elif coast > hi and _end_drops(node, false):
		held = Defs.IN_LEFT
	if held != flags:
		edges_held += 1
	return held


## True when a hero falling from feet point (x, y) has a node to land on: one at or below y whose x range holds x.
## x is brought inside the level first, and a static node reaches WALL_REACH_PX farther at an end that stops at a wall
## (NavBaker.span_nodes keeps a node WALL_PROBE px from a wall face; a drift that would end inside the wall ends at
## its face, over that node). A level that wraps top to bottom always has one; one that wraps left to right is asked
## at the x he comes out at.
func _ground_below(x: int, y: int) -> bool:
	if graph.wrap == "tb":
		return true
	var cx: int = clampi(x, Tuning.X_MIN, graph.cols * Tuning.TILE - Tuning.WALL_PROBE)
	if graph.wrap == "lr":
		cx = posmod(x, maxi(graph.cols * Tuning.TILE, 1))
	for node: NavGraph.NavNode in graph.nodes:
		if graph.node_y(node) < y:
			continue
		var lo: int = graph.node_x0(node)
		var hi: int = graph.node_x1(node)
		if node.mover < 0:
			if _at_wall(lo, true):
				lo -= WALL_REACH_PX
			if _at_wall(hi, false):
				hi += WALL_REACH_PX
		if cx >= lo and cx <= hi:
			return true
	return false


## True when the left / right end x of a static node stops at a wall face or at the level's edge.
func _at_wall(x: int, left: bool) -> bool:
	if left:
		return posmod(x, Tuning.TILE) == Tuning.WALL_PROBE or x <= Tuning.X_MIN
	return posmod(x, Tuning.TILE) == Tuning.TILE - Tuning.WALL_PROBE - 1 or x >= graph.cols * Tuning.TILE - Tuning.WALL_PROBE


## True when nothing is to land on beyond the left / right end of `node` (a pit, a liquid): the end a versus bot
## keeps away from.
func _end_drops(node: NavGraph.NavNode, left: bool) -> bool:
	var x: int = graph.node_x0(node) if left else graph.node_x1(node)
	if node.mover < 0 and _at_wall(x, left):
		return false
	var beyond: int = x - FALL_MARGIN_PX - 2 if left else x + FALL_MARGIN_PX + 2
	return not _ground_below(beyond, graph.node_y(node))


## The steering of a hero in the air without a link: toward the target's column. With [member safe_falls] that push
## is taken only when a node lies under the point his drift would end at if he let go after it (PlayerBase's air
## drag is the ground friction: [method stop_distance]) and FALL_MARGIN_PX farther; else he steers to the nearest
## point that has one - over a pit or a liquid the target's column is where a rival stands on the other side.
func _air_flags(hero: PlayerBase) -> int:
	var flags: int = _toward(target.x - hero.sim_pos.x, 0)
	if not safe_falls or graph == null:
		return flags
	var push: int = 0
	if (flags & Defs.IN_RIGHT) != 0:
		push = AIR_PUSH_V16
	elif (flags & Defs.IN_LEFT) != 0:
		push = -AIR_PUSH_V16
	var feet: Vector2i = hero.sim_pos
	var stop: int = feet.x + stop_distance(hero.xvel + push, 0)
	var ahead: int = stop + FALL_MARGIN_PX * signi(hero.xvel + push)
	if _ground_below(stop, feet.y) and _ground_below(ahead, feet.y):
		return flags
	# Nothing to land on there: the nearest point over a node at or below his feet (a little inside its ends).
	var coast: int = feet.x + stop_distance(hero.xvel, 0)
	var best: int = coast
	var best_distance: int = NavGraph.UNREACHABLE
	for node: NavGraph.NavNode in graph.nodes:
		if graph.node_y(node) < feet.y:
			continue
		var lo: int = graph.node_x0(node)
		var hi: int = graph.node_x1(node)
		var inside: int = mini(FALL_MARGIN_PX, (hi - lo) / 2)
		var x: int = clampi(coast, lo + inside, hi - inside)
		if absi(x - coast) < best_distance:
			best_distance = absi(x - coast)
			best = x
	if best_distance == NavGraph.UNREACHABLE:
		return flags
	var safe: int = _toward(best - coast, 0)
	if safe != flags:
		falls_steered += 1
	return safe


## Off the graph on the ground: walk toward the target; when that asks for nothing (the target straight above him) and
## he stands on the floor row of a node just beyond its end (a sliver between the node's end and a wall face under a
## slab, wf9_da_to_core_b.txt #2), walk back onto that node. On a head or a body he stays (a brain may keep him there).
func _off_graph_flags(hero: PlayerBase) -> int:
	var flags: int = walk_to(hero, target.x, tolerance)
	if flags != 0 or graph == null or hero.on_platform:
		return flags
	var near: int = graph.nearest_node(hero.sim_pos)
	if near < 0:
		return 0
	var node: NavGraph.NavNode = graph.nodes[near]
	if node.mover >= 0 or node.row != (hero.sim_pos.y >> 4):
		return 0
	var x: int = hero.sim_pos.x
	if x >= node.x0 and x <= node.x1:
		return 0
	return walk_to(hero, clampi(x, node.x0, node.x1), 0)


## True when the hero is in the state a link from `node` was verified from (NavSim.is_settled; on a mover node he
## stands on the platform).
static func settled(hero: PlayerBase, node: NavGraph.NavNode) -> bool:
	if node != null and node.mover >= 0:
		return NavSim.is_settled_on_mover(hero)
	return NavSim.is_settled(hero)


## True when `next` may start on tick `tick` (timed: the geyser's spout tick; mover: the mover's take-off state).
func _may_start(next: NavGraph.NavLink, tick: int) -> bool:
	if not next.starts_on(tick):
		return false
	if next.cond.size() >= 5:
		return NavMoversLive.matches(graph, next.cond)
	return true


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
		# What the last tick did: hit, bumped by another hero, launched by a geyser, airborne, landed.
		if hero.hit_timer > 0 or hero.dead or hero.is_down() or hero.squash > 0 or _touches_other_hero(hero) \
				or (link.kind != NavGraph.KIND_GEYSER and _in_spouting_vent(hero)):
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
	var landed: int = graph.node_at(hero.sim_pos, hero.on_platform) if hero.is_grounded() else -1
	if landed == link.to:
		links_landed += 1
	elif landed < 0 and hero.is_grounded():
		# Grounded off every node: on a head, or on a body poking through a one-way floor (not the link's fault).
		links_disturbed += 1
	elif link_disturbed:
		links_disturbed += 1
	else:
		_fail(link, hero, "ended on node %d at %s" % [landed, hero.sim_pos])
	link = null
	_path = PackedInt32Array()


func _fail(failed: NavGraph.NavLink, _hero: PlayerBase, what: String) -> void:
	links_failed += 1
	if failure_log.size() >= 8:
		failure_log.remove_at(0)
	failure_log.append("link %d (%d -> %d, %s, class %d) from x %d %s" % [
		failed.id, failed.from, failed.to, failed.keys, failed.weight, _link_start_x, what,
	])
	var count: int = int(_failures.get(failed.id, 0)) + 1
	_failures[failed.id] = count
	if count >= LINK_FAILURES_TO_BLOCK:
		blocked[failed.id] = true
		if _avoid_key != "":
			_avoid[failed.id] = true


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


## True when the hero's feet are in the vent of a geyser that spouts now (an unplanned launch).
static func _in_spouting_vent(hero: PlayerBase) -> bool:
	for geyser: SimEntity in BotSenses.geysers(Game.level):
		if not geyser.has_method(&"is_spouting") or not bool(geyser.call(&"is_spouting")):
			continue
		var vent: Rect2i = geyser.call(&"vent_rect")
		if vent.grow(2).has_point(hero.sim_pos - Vector2i(0, 1)):
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
