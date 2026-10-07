class_name LastCavemanBrain
extends BotBrain
## The Last Caveman Standing bot (DESIGN.md E.4 / E.7, GAMEPLAY.md 13.10.4): three hearts each, a hit costs one (a
## charged hit two), a lost heart bursts into 6 bones that heal (6 bones = 1 heart, at most 3), last one alive wins;
## the arena's sudden death from 60 s on; the eliminated ride Grudge Pterodactyls and drop rocks. Owner: core-B.
##
## Goals (every VersusTuning.BOT_GOAL_PERIOD_TICKS, utility = value / ticks): SAFETY (a telegraphed danger reaches the
## hero), BONES (bones lying in the arena: worth a lot while hurt, a little to deny them when whole), ATTACK (a rival
## in play: the Hunter and the Chief prefer the weakest and finish a one-heart rival; the Rookie only near ones),
## EVADE (Hunter / Chief on their last heart: keep away from a healthier rival who is not stunned), WANDER.
## Combat: the micro-rules of [BotBrain] on every rival in play. Out of the round: steer the Grudge Pterodactyl over
## the rival with the most hearts and drop a rock when it is ready ([method act_out]).

enum Goal { NONE, WANDER, BONES, ATTACK, EVADE, SAFETY }

const SCALE: int = 10000
const COST_BIAS: int = 24
const HYSTERESIS_PERCENT: int = 130
## A bone's value while hurt / while whole.
const BONE_VALUE_HURT: int = 3
const BONE_VALUE_WHOLE: int = 1
## The Rookie attacks only rivals this close (ticks).
const ROOKIE_ATTACK_TICKS: int = 96
## Evade from rivals closer than this (ticks) on the last heart.
const EVADE_NEAR_TICKS: int = 48
## The Grudge rock: drop within this many px of the target's x.
const GRUDGE_AIM_PX: int = 8

var goal: int = Goal.NONE
var goal_pos: Vector2i = Vector2i.ZERO
var goal_entity: Object = null
var goal_slot: int = -1
var goal_score: int = 0
## Statistics (tests): decisions per goal kind, rocks dropped.
var decisions: PackedInt32Array = PackedInt32Array([0, 0, 0, 0, 0, 0])
var rocks: int = 0


func reset() -> void:
	super.reset()
	goal = Goal.NONE
	goal_entity = null
	goal_slot = -1
	goal_score = 0


func needs_thinking(_tick: int) -> bool:
	if goal == Goal.NONE:
		return true
	if goal == Goal.BONES:
		# A picked-up bone can be freed between two ticks (several ticks per frame on a slow machine): never cast a
		# freed object (GrubStackBrain._goal_valid does the same).
		if goal_entity == null or not is_instance_valid(goal_entity):
			return true
		var item: CollectibleBase = goal_entity as CollectibleBase
		return item == null or item.collected
	if goal == Goal.ATTACK:
		return not bot.seen_alive(goal_slot)
	return false


func think(hero: PlayerBase, level: LevelBase, _tick: int) -> void:
	var safe: Vector2i = safety_target(hero, level)
	if safe != BotSenses.NO_POS:
		_goal_to(Goal.SAFETY, safe, null, -1, SCALE * 100)
		return
	var reach: Dictionary = bot.nav.reach(hero)
	var hearts: int = BotSenses.hearts_of(level, bot.slot)
	var best: Dictionary = {"goal": Goal.WANDER, "score": 0}
	# BONES
	var hurt: bool = hearts < VersusTuning.LCS_HEARTS
	for item: CollectibleBase in BotSenses.items(level):
		if item.item_id != &"items/bone" or is_dangerous(item.sim_pos):
			continue
		var cost: int = _cost(hero, reach, item.sim_pos)
		if cost >= NavGraph.UNREACHABLE:
			continue
		var value: int = BONE_VALUE_HURT if hurt else BONE_VALUE_WHOLE
		_offer(best, Goal.BONES, value * SCALE / (cost + COST_BIAS), item.sim_pos, item, -1)
	# ATTACK and EVADE
	var threat: int = -1
	var threat_cost: int = NavGraph.UNREACHABLE
	for rival: int in Defs.MAX_PLAYERS:
		if not bot.is_rival(rival) or not bot.seen_alive(rival):
			continue
		var seen: PackedInt32Array = bot.seen(rival)
		var pos: Vector2i = Vector2i(seen[HeroBot.SEEN_X], seen[HeroBot.SEEN_Y])
		var cost: int = _cost(hero, reach, pos)
		if cost >= NavGraph.UNREACHABLE:
			continue
		var rival_hearts: int = maxi(seen[HeroBot.SEEN_HEARTS], 1)
		var stunned: bool = seen[HeroBot.SEEN_HIT_TIMER] >= VersusTuning.STUN_HIT_TIMER_MIN
		if rival_hearts > hearts and not stunned and cost < threat_cost:
			threat = rival
			threat_cost = cost
		var utility: int = 2 * SCALE / (cost + COST_BIAS + 16)
		if rookie():
			if cost > ROOKIE_ATTACK_TICKS:
				continue
		else:
			# The weakest first; a rival on his last heart is a knock-out away.
			utility = utility * (VersusTuning.LCS_HEARTS + 1) / rival_hearts
			if stunned:
				utility = utility * 3 / 2
		_offer(best, Goal.ATTACK, utility, pos, null, rival)
	if not rookie() and hearts <= 1 and threat >= 0 and threat_cost < EVADE_NEAR_TICKS:
		var chasers: Array[int] = [threat]
		var point: Vector2i = escape_point(hero, chasers, 120, NavGraph.WEIGHT_LIGHT, restless())
		if point != BotSenses.NO_POS:
			_goal_to(Goal.EVADE, point, null, threat, SCALE)
			return
	_goal_to(int(best["goal"]), best.get("pos", Vector2i.ZERO), best.get("entity"), int(best.get("slot", -1)),
			int(best.get("score", 0)))
	if goal == Goal.WANDER:
		goal_pos = wander_target(hero)


func _cost(hero: PlayerBase, reach: Dictionary, pos: Vector2i) -> int:
	if reach.is_empty():
		return NavGraph.walk_ticks(pos.x - hero.sim_pos.x) + 2 * absi(pos.y - hero.sim_pos.y)
	return bot.nav.graph.reach_cost(reach, pos)


func _offer(best: Dictionary, kind: int, utility: int, pos: Vector2i, entity: Object, rival: int) -> void:
	var same: bool = kind == goal and entity == goal_entity and rival == goal_slot
	var score: int = utility if same else utility * 100 / HYSTERESIS_PERCENT
	if score > int(best.get("score", 0)):
		best["goal"] = kind
		best["score"] = score
		best["pos"] = pos
		best["entity"] = entity
		best["slot"] = rival


func _goal_to(kind: int, pos: Vector2i, entity: Object, rival: int, score: int) -> void:
	if kind != goal or entity != goal_entity or rival != goal_slot:
		decisions[kind] += 1
		if kind == Goal.SAFETY:
			escapes += 1
		cancel_actions()
	goal = kind
	goal_pos = pos
	goal_entity = entity
	goal_slot = rival
	goal_score = score


func worth_hitting(rival: int, seen: PackedInt32Array) -> bool:
	# Everyone in play is worth a hit; on the run (EVADE) only the one who comes too close.
	return goal != Goal.EVADE or rival == goal_slot or (seen[HeroBot.SEEN_BITS] & HeroBot.SEEN_STRIKING) != 0


func act(hero: PlayerBase, level: LevelBase, tick: int) -> int:
	var common: int = act_common(hero, level, tick)
	if common >= 0:
		return common
	var nav: BotNavigator = bot.nav
	match goal:
		Goal.BONES:
			if goal_entity != null and is_instance_valid(goal_entity):
				var item: CollectibleBase = goal_entity as CollectibleBase
				if item != null:
					goal_pos = item.sim_pos
			nav.set_target(goal_pos, 3)
		Goal.ATTACK:
			nav.set_target(attack_stand(hero, bot.predicted_pos(goal_slot)), 8)
		Goal.WANDER:
			nav.set_target(goal_pos, 6)
		_:
			nav.set_target(goal_pos, 4)
	return nav.step(hero, tick)


## Out of the round: steer the Grudge Pterodactyl (Left / Right) over the rival with the most hearts and drop a rock
## (Strike) when it is ready and he is under it; the Rookie hesitates.
func act_out(level: LevelBase, _tick: int) -> int:
	var at: Vector2i = BotSenses.grudge_pos(level, bot.slot)
	if at == BotSenses.NO_POS:
		return 0
	var target: int = -1
	var best_hearts: int = 0
	for rival: int in Defs.MAX_PLAYERS:
		if rival == bot.slot or not bot.seen_alive(rival):
			continue
		var hearts: int = bot.seen(rival)[HeroBot.SEEN_HEARTS]
		if hearts > best_hearts:
			best_hearts = hearts
			target = rival
	if target < 0:
		return 0
	var seen: PackedInt32Array = bot.seen(target)
	# Lead the target by its speed over the rock's fall (about 20 ticks for 10 rows).
	var aim: int = seen[HeroBot.SEEN_X] + Tuning.floor16(seen[HeroBot.SEEN_XVEL] * 20)
	var dx: int = aim - at.x
	var flags: int = 0
	if absi(dx) > 2:
		flags = dir_flag(dx)
	if absi(dx) <= GRUDGE_AIM_PX and BotSenses.grudge_ready(level, bot.slot) and decide():
		rocks += 1
		flags |= Defs.IN_FIRE
	return flags
