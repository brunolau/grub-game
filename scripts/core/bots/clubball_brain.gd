class_name ClubballBrain
extends BotBrain
## The Clubball bot (DESIGN.md E.4 / E.7, GAMEPLAY.md 13.10.6): 1v1, 2v1 or 2v2 on Coconut Cove - strike the coconut
## into the other team's goal mouth. Owner: core-B.
##
## Every decision the bot predicts the coconut's next PREDICT_TICKS ticks with the deterministic ball physics
## ([BallPredictor]) and stands **goal-side** of it: at a strike stand of the graph ([method strike_stands]: a node
## point from which a forward, high or low strike facing the attacked goal meets the ball's box, nearest
## STAND_OFFSET_PX behind it) for the first predicted point it reaches in time, so that the strike sends the ball
## towards the attacked goal; a ball resting on a ledge or against a wall is played from wherever there is a stand. In 2v2 (or 2v1) the teammate who reaches the ball first attacks and the
## other keeps (stands in front of his own goal mouth, shuffling, and clears what comes). Shots, facing the attacked
## goal only (a ball between the bot and its own goal is walked around, never struck): a forward drive when the ball
## will be in the front box, a high lob when it will be in the high front box, a low grounder when it rolls at the
## feet; the Hunter and the Chief crouch-charge for a smash when the ball rolls in slowly from afar. Rivals standing
## between the bot and the ball get the forward strike (a hit only knocks back). The Rookie hesitates.

enum Goal { NONE, CHASE, KEEP, WAIT }

## Ticks of ball flight predicted per decision.
const PREDICT_TICKS: int = 60
## The bot stands this far behind the ball (towards its own goal).
const STAND_OFFSET_PX: int = 16
## Extra ticks the bot allows itself to reach an intercept point; the prediction is searched every this many ticks.
const SLACK_TICKS: int = 4
const INTERCEPT_STEP_TICKS: int = 3
## Keeper: this far out of the goal mouth (px), shuffling by KEEP_SHUFFLE_PX every KEEP_SHUFFLE_TICKS (more than the
## arrival tolerance KEEP_TOLERANCE_PX: he really moves, never idle).
const KEEP_OUT_PX: int = 40
const KEEP_SHUFFLE_PX: int = 16
const KEEP_SHUFFLE_TICKS: int = 48
const KEEP_TOLERANCE_PX: int = 3
## A ball within UNDER_PX of the hero's x and at most UNDER_ABOVE_PX over his head is over his head
## ([method _out_from_under]).
const UNDER_PX: int = 14
const UNDER_ABOVE_PX: int = 64
## Hunter / Chief: charge a smash when the ball rolls in from this far (px) at most this fast (v16).
const SMASH_FROM_PX: int = 40
const SMASH_TO_PX: int = 96
const SMASH_MAX_XVEL: int = 48

var goal: int = Goal.NONE
var goal_pos: Vector2i = Vector2i.ZERO
## The direction (+1 / -1) of the goal this bot attacks, and the goal mouths (level px; empty = unknown).
var attack_dir: int = 1
var attack_rect: Rect2i = Rect2i()
var defend_rect: Rect2i = Rect2i()
## The last prediction (tests): the ball's feet points.
var prediction: Array[Vector2i] = []
## Statistics (tests): decisions per goal kind, shots per strike kind.
var decisions: PackedInt32Array = PackedInt32Array([0, 0, 0, 0])
var shots: PackedInt32Array = PackedInt32Array([0, 0, 0])
var _home: Vector2i = BotSenses.NO_POS


func reset() -> void:
	super.reset()
	goal = Goal.NONE
	prediction.clear()
	_home = BotSenses.NO_POS


## The team of this bot (the referee's 1 / 2; free-for-all slots alternate 1, 2, 1, 2).
func my_team(level: LevelBase) -> int:
	var team: int = BotSenses.team_of(level, bot.slot)
	return team if team > 0 else 1 + bot.slot % 2


## The team of another slot (as [method my_team]).
func team_of_slot(level: LevelBase, p_slot: int) -> int:
	var team: int = BotSenses.team_of(level, p_slot)
	return team if team > 0 else 1 + p_slot % 2


## The goals: the referee's goal_rect(team) when it has them, else the arena edge on the side the bot started on is
## its own (spawns face the field).
func _read_goals(hero: PlayerBase, level: LevelBase) -> void:
	if _home == BotSenses.NO_POS:
		_home = hero.sim_pos
	var team: int = my_team(level)
	defend_rect = BotSenses.goal_rect(level, team)
	attack_rect = BotSenses.goal_rect(level, 3 - team)
	var width: int = level.grid.cols * Tuning.TILE if level.grid != null else Tuning.VIEW_W
	if defend_rect.size.x > 0 and attack_rect.size.x > 0:
		attack_dir = 1 if attack_rect.get_center().x > defend_rect.get_center().x else -1
	else:
		attack_dir = 1 if _home.x < width / 2 else -1
		var floor_y: int = hero.sim_pos.y
		defend_rect = Rect2i(0 if attack_dir > 0 else width - 16, floor_y - 48, 16, 48)
		attack_rect = Rect2i(width - 16 if attack_dir > 0 else 0, floor_y - 48, 16, 48)


func worth_hitting(rival: int, seen: PackedInt32Array) -> bool:
	# Only a rival in the way: nearer to the ball than the bot, on its side.
	if prediction.is_empty():
		return false
	var ball: Vector2i = prediction[0]
	var pos: Vector2i = Vector2i(seen[HeroBot.SEEN_X], seen[HeroBot.SEEN_Y])
	var me: Vector2i = bot.seen_pos(bot.slot) if bot.body == null else Vector2i.ZERO
	return rival >= 0 and absi(pos.x - ball.x) < absi(me.x - ball.x) and signi(pos.x - me.x) == signi(ball.x - me.x)


func think(hero: PlayerBase, level: LevelBase, tick: int) -> void:
	_read_goals(hero, level)
	var ball: SimEntity = BotSenses.ball(level)
	if ball == null:
		prediction.clear()
		_goal_to(Goal.WAIT, _keep_point(hero, level, tick))
		return
	prediction = BallPredictor.predict(level, ball, PREDICT_TICKS)
	var intercept: Vector2i = _intercept(hero)
	# 2v2: whoever gets there first attacks, the other keeps.
	var mine: int = absi(intercept.x - hero.sim_pos.x)
	var keeper: bool = false
	for mate: int in Defs.MAX_PLAYERS:
		if mate == bot.slot or not bot.seen_alive(mate) or team_of_slot(level, mate) != my_team(level):
			continue
		var theirs: int = absi(intercept.x - bot.seen_pos(mate).x)
		if theirs + 12 < mine or (theirs <= mine + 12 and mate < bot.slot and theirs <= mine):
			keeper = true
	# Stood still too long (a ball it cannot play, juggling on a head or resting where only the other side has a stand):
	# back to its goal mouth for a while, so that it never idles.
	if keeper or restless():
		_goal_to(Goal.KEEP, _keep_point(hero, level, tick))
	else:
		_goal_to(Goal.CHASE, intercept)


## The point to stand at: a strike stand (a node point from which a forward, high or low strike facing the attacked
## goal meets the ball's box) for the first predicted point the hero reaches in time - every INTERCEPT_STEP_TICKS of
## the prediction, the stand he reaches soonest; when none is in time, the first stand at all; without any, the
## floor goal-side of the ball's last predicted point. A ball resting on a ledge or against a wall is played from
## wherever the graph has a stand for it.
func _intercept(hero: PlayerBase) -> Vector2i:
	var graph: NavGraph = bot.nav.graph
	var last: Vector2i = prediction[prediction.size() - 1] if not prediction.is_empty() else hero.sim_pos
	var fallback_pos: Vector2i = Vector2i(last.x - attack_dir * STAND_OFFSET_PX, hero.sim_pos.y)
	if graph == null:
		return fallback_pos
	var reach: Dictionary = bot.nav.reach(hero)
	var first: Vector2i = BotSenses.NO_POS
	var t: int = 0
	while t < prediction.size():
		var best: Vector2i = BotSenses.NO_POS
		var best_cost: int = NavGraph.UNREACHABLE
		for stand: Vector2i in strike_stands(graph, prediction[t], attack_dir):
			var cost: int = graph.reach_cost(reach, stand)
			if cost < best_cost:
				best_cost = cost
				best = stand
		if best != BotSenses.NO_POS:
			if first == BotSenses.NO_POS:
				first = best
			if best_cost <= t + SLACK_TICKS:
				return best
		t += INTERCEPT_STEP_TICKS
	if first != BotSenses.NO_POS:
		return first
	return fallback_pos


## The node points (sampled every 4 px) from which a strike facing `facing` meets a ball whose feet point is `ball`:
## the forward, high or low front box (BotBrain.front_box) overlaps its 16 x 16 box. At most one point per node: the
## one nearest STAND_OFFSET_PX behind the ball.
static func strike_stands(graph: NavGraph, ball: Vector2i, facing: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var box: Rect2i = Rect2i(ball.x - BallPredictor.BOX / 2, ball.y - BallPredictor.BOX, BallPredictor.BOX,
			BallPredictor.BOX)
	var ideal: int = ball.x - facing * STAND_OFFSET_PX
	for node: NavGraph.NavNode in graph.nodes:
		var y: int = graph.node_y(node)
		# The front boxes reach from 43 px over the feet (high) to below them (low).
		if y - ball.y > 60 or ball.y - y > 24:
			continue
		var found: Vector2i = BotSenses.NO_POS
		for kind: int in [STRIKE_FORWARD, STRIKE_HIGH, STRIKE_LOW]:
			# The box of a hero at feet x is front_box(x) = (x + shift, y + top, w, h): it meets the ball's box for the
			# feet x of an interval (the vertical test does not depend on x).
			var probe: Rect2i = front_box(Vector2i(0, y), facing, kind)
			if probe.position.y >= box.end.y or box.position.y >= probe.end.y:
				continue
			var lo: int = maxi(box.position.x - probe.size.x - probe.position.x + 1, graph.node_x0(node))
			var hi: int = mini(box.end.x - probe.position.x - 1, graph.node_x1(node))
			if lo > hi:
				continue
			var x: int = clampi(ideal, lo, hi)
			if found == BotSenses.NO_POS or absi(x - ideal) < absi(found.x - ideal):
				found = Vector2i(x, y)
		if found != BotSenses.NO_POS:
			result.append(found)
	return result


## The keeper's place: KEEP_OUT_PX in front of the own goal mouth, shuffling a little (never idle).
func _keep_point(hero: PlayerBase, level: LevelBase, tick: int) -> Vector2i:
	var mouth: Vector2i = defend_rect.get_center()
	var x: int = mouth.x + attack_dir * KEEP_OUT_PX
	if (tick / KEEP_SHUFFLE_TICKS) % 2 == 1:
		x += attack_dir * KEEP_SHUFFLE_PX
	var y: int = defend_rect.end.y if defend_rect.size.y > 0 else hero.sim_pos.y
	var graph: NavGraph = bot.nav.graph
	if graph != null:
		var node: int = graph.node_for(Vector2i(x, y - 1))
		if node >= 0:
			var n: NavGraph.NavNode = graph.nodes[node]
			return Vector2i(clampi(x, graph.node_x0(n), graph.node_x1(n)), graph.node_y(n))
	return Vector2i(x, level.grid.rows * Tuning.TILE if level.grid != null else y)


func _goal_to(kind: int, pos: Vector2i) -> void:
	if kind != goal:
		decisions[kind] += 1
	goal = kind
	goal_pos = pos


func act(hero: PlayerBase, level: LevelBase, tick: int) -> int:
	var common: int = act_common(hero, level, tick)
	if common >= 0:
		return common
	var shot: int = _shot(hero)
	if shot >= 0:
		return shot
	var away: int = _out_from_under(hero)
	if away >= 0:
		return away
	var nav: BotNavigator = bot.nav
	nav.set_target(goal_pos, 3 if goal == Goal.CHASE else KEEP_TOLERANCE_PX)
	var flags: int = nav.step(hero, tick)
	if flags == 0 and goal == Goal.CHASE and nav.arrived(hero) and hero.is_grounded() and hero.facing != attack_dir:
		# Turn to face the goal it attacks (a tap; the stand keeps it within the tolerance).
		flags = dir_flag(attack_dir)
	return flags


## A ball coming down onto the hero's head bounces off it at 3/4 and at least 96 v16 (GAMEPLAY.md 13.10.6), so a hero
## standing under it juggles it for ever: step out from under it (behind it, as seen from the attacked goal, when
## there is room; else forward) and let it land. -1 when the ball is not over his head.
func _out_from_under(hero: PlayerBase) -> int:
	var ball: SimEntity = BotSenses.ball(bot.level)
	if ball == null or not hero.is_grounded() or hero.attack_gate:
		return -1
	var dx: int = ball.sim_pos.x - hero.sim_pos.x
	var above: int = hero.sim_pos.y - Tuning.HERO_BOX_STAND.y - ball.sim_pos.y
	if absi(dx) > UNDER_PX or above < -4 or above > UNDER_ABOVE_PX:
		return -1
	# A ball lying on a floor over him (a bridge, a ledge) does not come down on his head.
	var grid: TileGrid = bot.level.grid if bot.level != null else null
	if grid != null:
		var col: int = ball.sim_pos.x >> 4
		for row: int in range(ball.sim_pos.y >> 4, (hero.sim_pos.y - Tuning.HERO_BOX_STAND.y) >> 4):
			if grid.in_bounds(col, row) and grid.floor_at(col, row) != TileGrid.FLOOR_EMPTY:
				return -1
	var step: int = -attack_dir
	var graph: NavGraph = bot.nav.graph
	if graph != null:
		var node: int = graph.node_at(hero.sim_pos, hero.on_platform)
		if node >= 0:
			var n: NavGraph.NavNode = graph.nodes[node]
			var room: int = (hero.sim_pos.x - graph.node_x0(n)) if step < 0 else (graph.node_x1(n) - hero.sim_pos.x)
			if room < UNDER_PX + 4:
				step = -step
	return dir_flag(step)


## A strike at the ball facing the attacked goal; -1 when none fits now.
func _shot(hero: PlayerBase) -> int:
	if prediction.is_empty() or not hero.is_grounded() or hero.attack_gate or hero.swing_lock > 0 or hero.squash > 0 \
			or not may_strike(hero):
		return -1
	var ball: SimEntity = BotSenses.ball(bot.level)
	if ball == null:
		return -1
	var me: Vector2i = hero.sim_pos
	var lead: int = mini(STRIKE_LEAD_TICKS, prediction.size()) - 1
	var at: Vector2i = prediction[lead]
	var box: Rect2i = Rect2i(at.x - BallPredictor.BOX / 2, at.y - BallPredictor.BOX, BallPredictor.BOX, BallPredictor.BOX)
	if (at.x - me.x) * attack_dir < -4:
		return -1  # the ball is behind: walk around it
	for kind: int in [STRIKE_FORWARD, STRIKE_HIGH, STRIKE_LOW]:
		if kind == STRIKE_LOW and at.y < me.y - 12:
			continue
		if front_box(me, attack_dir, kind).intersects(box) and decide():
			shots[kind] += 1
			strikes += 1
			return start_action(dir_flag(attack_dir) | STRIKE_FLAGS[kind], strike_ticks(kind))
	# Hunter / Chief: crouch-charge for a smash when it rolls in slowly.
	if not rookie() and hero.charge == 0 and absi(hero.xvel) < 16:
		var now: Vector2i = ball.sim_pos
		var distance: int = (now.x - me.x) * attack_dir
		var incoming: bool = ball.xvel != 0 and signi(ball.xvel) == -attack_dir and absi(ball.xvel) <= SMASH_MAX_XVEL
		if incoming and distance >= SMASH_FROM_PX and distance <= SMASH_TO_PX and absi(now.y - me.y) <= 8:
			charges += 1
			return start_action(Defs.IN_DOWN, CHARGE_TICKS)
	return -1
