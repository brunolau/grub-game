class_name ClubballBrain
extends BotBrain
## The Clubball bot (DESIGN.md E.4 / E.7, GAMEPLAY.md 13.10.6): 1v1, 2v1 or 2v2 on Coconut Cove - strike the coconut
## into the other team's goal mouth. Owner: core-B.
##
## Every decision the bot predicts the coconut's next PREDICT_TICKS ticks with the deterministic ball physics
## ([BallPredictor]) and stands **goal-side** of it: at the first predicted point it can reach in time where the ball
## is low enough to strike, STAND_OFFSET_PX behind the ball as seen from the goal it attacks, so that a strike facing
## the attacked goal sends the ball there. In 2v2 (or 2v1) the teammate who reaches the ball first attacks and the
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
## The ball counts as strikeable when its feet are at most this far above a floor node (body height and a bit).
const REACH_PX: int = 44
## Extra ticks the bot allows itself to reach an intercept point.
const SLACK_TICKS: int = 4
## Keeper: this far out of the goal mouth (px), shuffling by KEEP_SHUFFLE_PX every KEEP_SHUFFLE_TICKS.
const KEEP_OUT_PX: int = 40
const KEEP_SHUFFLE_PX: int = 10
const KEEP_SHUFFLE_TICKS: int = 48
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
	if keeper:
		_goal_to(Goal.KEEP, _keep_point(hero, level, tick))
	else:
		_goal_to(Goal.CHASE, intercept)


## The point to stand at: goal-side of the first predicted point the hero reaches in time with the ball low enough;
## of the landing point when none is reachable in time.
func _intercept(hero: PlayerBase) -> Vector2i:
	var graph: NavGraph = bot.nav.graph
	var reach: Dictionary = bot.nav.reach(hero)
	var fallback: Vector2i = BotSenses.NO_POS
	for t: int in prediction.size():
		var p: Vector2i = prediction[t]
		var node: int = graph.node_below(p) if graph != null else -1
		var floor_y: int = graph.node_y(graph.nodes[node]) if node >= 0 else hero.sim_pos.y
		if floor_y - p.y > REACH_PX:
			continue
		var stand: Vector2i = Vector2i(p.x - attack_dir * STAND_OFFSET_PX, floor_y)
		if graph != null and node >= 0:
			var n: NavGraph.NavNode = graph.nodes[node]
			stand.x = clampi(stand.x, graph.node_x0(n), graph.node_x1(n))
		if fallback == BotSenses.NO_POS:
			fallback = stand
		var cost: int = graph.reach_cost(reach, stand) if not reach.is_empty() \
				else NavGraph.walk_ticks(stand.x - hero.sim_pos.x)
		if cost <= t + SLACK_TICKS:
			return stand
	if fallback != BotSenses.NO_POS:
		return fallback
	var last: Vector2i = prediction[prediction.size() - 1] if not prediction.is_empty() else hero.sim_pos
	return Vector2i(last.x - attack_dir * STAND_OFFSET_PX, hero.sim_pos.y)


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
	var nav: BotNavigator = bot.nav
	nav.set_target(goal_pos, 3 if goal == Goal.CHASE else 6)
	var flags: int = nav.step(hero, tick)
	if flags == 0 and goal == Goal.CHASE and nav.arrived(hero) and hero.is_grounded() and hero.facing != attack_dir:
		# Turn to face the goal it attacks (a tap; the stand keeps it within the tolerance).
		flags = dir_flag(attack_dir)
	return flags


## A strike at the ball facing the attacked goal; -1 when none fits now.
func _shot(hero: PlayerBase) -> int:
	if prediction.is_empty() or not hero.is_grounded() or hero.attack_gate or hero.swing_lock > 0 or hero.squash > 0:
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
