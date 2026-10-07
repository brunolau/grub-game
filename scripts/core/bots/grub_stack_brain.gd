class_name GrubStackBrain
extends BotBrain
## The Grub Stack bot (docs/expansion/DESIGN.md E.3 / E.7, GAMEPLAY.md 13.10.3 / 13.10.10): seek food, strike the
## visible spots, attack rivals with tall stacks, bank at the cookpot when the stack is tall. Owner: core-B.
##
## Goals (re-chosen every VersusTuning.BOT_GOAL_PERIOD_TICKS by utility = value / ticks to get there, one route search
## per decision): SAFETY (a telegraphed danger reaches the hero: get out), FOOD (an item lying in the arena, by its
## stack value; the skull is avoided), SPOT (a visible spot: walk to a stand from which a strike reaches its cell -
## the bot never knows what is inside; a spot a rival stands nearer to is worth half: the bots spread out), BANK
## (crouch in an open cookpot once the stack reaches BANK_AT, sooner when the Feast Rush is near), ATTACK (a rival
## carrying food; the Hunter and the Chief prefer the leader and the banker, whom a stomp robs double), WANDER (nothing
## better: never idle). A goal is kept unless another is clearly better (HYSTERESIS_PERCENT).
## Combat: the micro-rules of [BotBrain] on rivals worth hitting (food on the head, the goal, or a striker). Levels:
## Rookie (10-tick reaction, hesitates, banks early, attacks only near rivals), Hunter (6 ticks; stomps, charges,
## deflects now and then), Chief (3 ticks; stomp chains, deflects half the time, banks before the rush like the
## Hunter).

enum Goal { NONE, WANDER, FOOD, SPOT, BANK, ATTACK, SAFETY }

## Stack at which banking becomes the plan, per Defs.BotLevel (Rookie, Hunter, Chief).
const BANK_AT: Array[int] = [6, 9, 9]
## Bank anything once the Feast Rush (lids shut) is this close.
const BANK_BEFORE_RUSH_TICKS: int = 146
## A new goal must beat the current one by this much (percent) to replace it.
const HYSTERESIS_PERCENT: int = 130
## Utility scale: value units are multiplied by this before dividing by the ticks.
const SCALE: int = 10000
## Ticks added to every route cost (no division by zero, and a near goal is not infinitely good).
const COST_BIAS: int = 24
## Expected stack units behind one strike at a small / big spot (the bot does not know the contents; a big spot needs
## VersusTuning.BIG_SPOT_HITS strikes for its giant bonus).
const SPOT_VALUE_SMALL: int = 1
const SPOT_VALUE_BIG: int = 3
## The Rookie attacks only rivals this close (ticks).
const ROOKIE_ATTACK_TICKS: int = 72
## A spot struck this often without effect is given up for the level (a stand that does not reach it after all).
const SPOT_TRIES_MAX: int = 4

var goal: int = Goal.NONE
var goal_pos: Vector2i = Vector2i.ZERO
var goal_utility: int = 0
## The goal's entity (item, spot, pot) or rival slot; checked every tick.
var goal_entity: Object = null
var goal_slot: int = -1
## SPOT: the stand {"node", "x", "facing", "kind"}.
var goal_stand: Dictionary = {}
## Statistics (tests): decisions per goal kind.
var decisions: PackedInt32Array = PackedInt32Array([0, 0, 0, 0, 0, 0, 0])

# Strikes at a spot that did not lower its hits: instance id -> [strikes, hits_left when counted].
var _spot_tries: Dictionary = {}


func reset() -> void:
	super.reset()
	goal = Goal.NONE
	goal_entity = null
	goal_slot = -1
	goal_stand = {}
	goal_utility = 0
	_spot_tries.clear()


func nav_class(_hero: PlayerBase, level: LevelBase) -> int:
	return weight_class(BotSenses.stack_of(level, bot.slot))


func worth_hitting(rival: int, seen: PackedInt32Array) -> bool:
	return seen[HeroBot.SEEN_STACK] > 0 or goal_slot == rival \
			or (seen[HeroBot.SEEN_BITS] & HeroBot.SEEN_STRIKING) != 0


func _note_spot_strike(spot: HittableBase) -> void:
	var id: int = spot.get_instance_id()
	var entry: Array = _spot_tries.get(id, [0, spot.hits_left])
	if int(entry[1]) != spot.hits_left:
		entry = [0, spot.hits_left]
	entry[0] = int(entry[0]) + 1
	_spot_tries[id] = entry


func _spot_given_up(spot: HittableBase) -> bool:
	var entry: Array = _spot_tries.get(spot.get_instance_id(), [0, spot.hits_left])
	return int(entry[1]) == spot.hits_left and int(entry[0]) >= SPOT_TRIES_MAX


func needs_thinking(_tick: int) -> bool:
	return goal == Goal.NONE or not _goal_valid()


# =================================================================================================================
# Decisions
# =================================================================================================================

func think(hero: PlayerBase, level: LevelBase, _tick: int) -> void:
	var graph: NavGraph = bot.nav.graph
	var best: Dictionary = {"goal": Goal.WANDER, "utility": 0}
	var safe: Vector2i = safety_target(hero, level)
	if safe != BotSenses.NO_POS:
		best = {"goal": Goal.SAFETY, "utility": SCALE * 100, "score": SCALE * 100, "pos": safe, "entity": null,
				"slot": -1, "stand": {}}
		_choose(best, hero)
		return
	var reach: Dictionary = bot.nav.reach(hero)
	var stack: int = BotSenses.stack_of(level, bot.slot)
	# FOOD
	for item: CollectibleBase in BotSenses.items(level):
		var value: int = BotSenses.food_value(level, item)
		if value <= 0:
			continue
		var cost: int = _cost(hero, reach, item.sim_pos)
		if cost >= NavGraph.UNREACHABLE:
			continue
		_offer(best, Goal.FOOD, value * SCALE / (cost + COST_BIAS), item.sim_pos, item, -1, {})
	# SPOT
	for spot: HittableBase in BotSenses.spots(level):
		if _spot_given_up(spot):
			continue
		var stand: Dictionary = {}
		var cost: int = NavGraph.UNREACHABLE
		for option: Dictionary in BotBrain.spot_stands(graph, spot.cell):
			var option_pos: Vector2i = Vector2i(int(option["x"]), graph.nodes[int(option["node"])].y)
			# Forward strikes are preferred: a high or low one counts as 6 ticks farther.
			var option_cost: int = _cost(hero, reach, option_pos) + 6 * int(option["kind"])
			if option_cost < cost:
				cost = option_cost
				stand = option
		if stand.is_empty():
			continue
		var stand_pos: Vector2i = Vector2i(int(stand["x"]), graph.nodes[int(stand["node"])].y)
		var value: int = SPOT_VALUE_BIG if spot.spot_kind == &"big" else SPOT_VALUE_SMALL
		var strike: int = BotBrain.strike_ticks(int(stand["kind"])) + spot.cooldown
		var utility: int = value * SCALE / (cost + COST_BIAS + strike)
		if _contested(hero, stand_pos):
			utility /= 2
		_offer(best, Goal.SPOT, utility, stand_pos, spot, -1, stand)
	# BANK
	var bank_at: int = BANK_AT[bot.bot_level]
	var left: int = BotSenses.ticks_left(level)
	var rush_near: bool = left >= 0 and left <= VersusTuning.FEAST_RUSH_TICKS + BANK_BEFORE_RUSH_TICKS
	var banking_now: bool = goal == Goal.BANK
	if stack > 0 and (stack >= bank_at or banking_now or (rush_near and not rookie())):
		for pot: SimEntity in BotSenses.cookpots(level):
			if not BotSenses.pot_usable(level, pot, bot.slot):
				continue
			var cost: int = _cost(hero, reach, pot.sim_pos)
			if cost >= NavGraph.UNREACHABLE:
				continue
			var weight: int = 2 if stack >= bank_at or banking_now else 1
			if stack >= bank_at + 4 or banking_now:
				weight = 3
			_offer(best, Goal.BANK, weight * stack * SCALE / (cost + COST_BIAS), pot.sim_pos, pot, -1, {})
	# ATTACK
	var leader: int = _leader(level)
	for rival: int in Defs.MAX_PLAYERS:
		if not bot.is_rival(rival):
			continue
		var seen: PackedInt32Array = bot.seen(rival)
		var bits: int = seen[HeroBot.SEEN_BITS]
		if (bits & HeroBot.SEEN_PRESENT) == 0 or (bits & HeroBot.SEEN_GONE) != 0:
			continue
		var rival_stack: int = seen[HeroBot.SEEN_STACK]
		if rival_stack <= 0:
			continue
		var pos: Vector2i = Vector2i(seen[HeroBot.SEEN_X], seen[HeroBot.SEEN_Y])
		var cost: int = _cost(hero, reach, pos)
		if cost >= NavGraph.UNREACHABLE:
			continue
		var gain: int = 1 + rival_stack / VersusTuning.SPILL_HIT_DIV
		var utility: int = gain * SCALE / (cost + COST_BIAS + 16)
		if rookie():
			if cost > ROOKIE_ATTACK_TICKS:
				continue
			utility /= 2
		else:
			utility = utility * 3 / 2
			if rival == leader:
				utility = utility * 3 / 2
			if (bits & HeroBot.SEEN_BANKING) != 0:
				utility *= 2
		_offer(best, Goal.ATTACK, utility, pos, null, rival, {})
	_choose(best, hero)


## True when a rival (as seen) stands nearer to `pos` than the hero (in px): someone else is going for it.
func _contested(hero: PlayerBase, pos: Vector2i) -> bool:
	var mine: int = absi(hero.sim_pos.x - pos.x) + absi(hero.sim_pos.y - pos.y)
	for rival: int in Defs.MAX_PLAYERS:
		if rival == bot.slot or not bot.seen_alive(rival):
			continue
		var other: Vector2i = bot.seen_pos(rival)
		if absi(other.x - pos.x) + absi(other.y - pos.y) + 8 < mine:
			return true
	return false


func _cost(hero: PlayerBase, reach: Dictionary, pos: Vector2i) -> int:
	if reach.is_empty():
		return NavGraph.walk_ticks(pos.x - hero.sim_pos.x) + 2 * absi(pos.y - hero.sim_pos.y)
	return bot.nav.graph.reach_cost(reach, pos)


func _offer(best: Dictionary, kind: int, utility: int, pos: Vector2i, entity: Object, rival: int, stand: Dictionary) -> void:
	# The current goal competes with its fresh utility, the others must beat it by the hysteresis.
	var same: bool = kind == goal and entity == goal_entity and rival == goal_slot
	var score: int = utility if same else utility * 100 / HYSTERESIS_PERCENT
	if score > int(best.get("score", 0)):
		best["goal"] = kind
		best["utility"] = utility
		best["score"] = score
		best["pos"] = pos
		best["entity"] = entity
		best["slot"] = rival
		best["stand"] = stand


func _choose(best: Dictionary, hero: PlayerBase) -> void:
	var kind: int = int(best["goal"])
	var changed: bool = kind != goal or best.get("entity") != goal_entity or int(best.get("slot", -1)) != goal_slot
	goal = kind
	goal_utility = int(best.get("utility", 0))
	goal_entity = best.get("entity")
	goal_slot = int(best.get("slot", -1))
	goal_stand = best.get("stand", {})
	if kind == Goal.WANDER:
		goal_pos = wander_target(hero)
	else:
		goal_pos = best["pos"]
	if changed:
		decisions[kind] += 1
		if kind == Goal.SAFETY:
			escapes += 1
		cancel_actions()


func _goal_valid() -> bool:
	if goal == Goal.FOOD or goal == Goal.SPOT or goal == Goal.BANK:
		if goal_entity == null or not is_instance_valid(goal_entity):
			return false
	match goal:
		Goal.FOOD:
			var item: CollectibleBase = goal_entity as CollectibleBase
			return item != null and is_instance_valid(item) and not item.collected and not item.is_queued_for_deletion()
		Goal.SPOT:
			var spot: HittableBase = goal_entity as HittableBase
			return spot != null and is_instance_valid(spot) and not spot.opened
		Goal.BANK:
			return goal_entity != null and is_instance_valid(goal_entity) \
					and BotSenses.stack_of(bot.level, bot.slot) > 0 \
					and BotSenses.pot_usable(bot.level, goal_entity as SimEntity, bot.slot)
		Goal.ATTACK:
			var seen: PackedInt32Array = bot.seen(goal_slot)
			return goal_slot >= 0 and (seen[HeroBot.SEEN_BITS] & HeroBot.SEEN_GONE) == 0 and seen[HeroBot.SEEN_STACK] > 0
	return goal != Goal.NONE


func _leader(level: LevelBase) -> int:
	var best: int = -1
	var best_stack: int = 0
	for p_slot: int in Defs.MAX_PLAYERS:
		if p_slot == bot.slot:
			continue
		var stack: int = bot.seen(p_slot)[HeroBot.SEEN_STACK]
		if stack > best_stack and BotSenses.are_rivals(level, bot.slot, p_slot):
			best_stack = stack
			best = p_slot
	return best


# =================================================================================================================
# This tick's flags
# =================================================================================================================

func act(hero: PlayerBase, level: LevelBase, tick: int) -> int:
	var nav: BotNavigator = bot.nav
	var common: int = -1
	if goal == Goal.BANK and hero.is_low():
		# Banking: the Rookie keeps crouching whatever happens; the others still fight back.
		common = act_common(hero, level, tick) if not rookie() else -1
	else:
		common = act_common(hero, level, tick)
	if common >= 0:
		return common
	var entity: Object = goal_entity if goal_entity != null and is_instance_valid(goal_entity) else null
	match goal:
		Goal.FOOD:
			var item: CollectibleBase = entity as CollectibleBase
			if item != null:
				goal_pos = item.sim_pos
			nav.set_target(goal_pos, 3)
		Goal.SPOT:
			var half: int = (int(goal_stand.get("x1", goal_pos.x)) - int(goal_stand.get("x0", goal_pos.x))) / 2
			nav.set_target(goal_pos, half)
			var spot: HittableBase = entity as HittableBase
			if nav.arrived(hero) and hero.is_grounded() and absi(hero.xvel) < 16 and spot != null \
					and spot.cooldown <= 1:
				var kind: int = int(goal_stand.get("kind", STRIKE_FORWARD))
				var facing: int = int(goal_stand.get("facing", 1))
				strikes += 1
				_note_spot_strike(spot)
				return start_action(dir_flag(facing) | STRIKE_FLAGS[kind], strike_ticks(kind))
		Goal.BANK:
			var pot: SimEntity = entity as SimEntity
			if pot != null:
				var rect: Rect2i = BotSenses.bank_rect(pot)
				var inside: bool = hero.is_grounded() and hero.sim_pos.x >= rect.position.x + 2 \
						and hero.sim_pos.x < rect.end.x - 2 and hero.sim_pos.y >= rect.position.y \
						and hero.sim_pos.y < rect.end.y
				if inside:
					return Defs.IN_DOWN
				nav.set_target(pot.sim_pos, rect.size.x / 2 - 4)
		Goal.ATTACK:
			var pos: Vector2i = bot.seen_pos(goal_slot)
			nav.set_target(pos, 12)
		_:
			nav.set_target(goal_pos, 6)
	return nav.step(hero, tick)


## Weight class of a stack (PHYSICS.md C.14: 10+ units heavy, 20+ heavier) as NavGraph.WEIGHT_*.
static func weight_class(stack: int) -> int:
	if stack >= VersusTuning.STACK_HEAVIER:
		return NavGraph.WEIGHT_HEAVIER
	if stack >= VersusTuning.STACK_HEAVY:
		return NavGraph.WEIGHT_HEAVY
	return NavGraph.WEIGHT_LIGHT
