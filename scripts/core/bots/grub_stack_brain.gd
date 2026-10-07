class_name GrubStackBrain
extends BotBrain
## The Grub Stack bot (docs/expansion/DESIGN.md E.3 / E.7, GAMEPLAY.md 13.10.3 / 13.10.10): seek food, strike the
## visible spots, attack rivals with tall stacks, bank at the cookpot when the stack is tall - Rookie and Hunter
## (and a first Chief: Hunter decisions on a 3-tick reaction). Owner: core-B.
##
## Goals (re-chosen every VersusTuning.BOT_GOAL_PERIOD_TICKS by utility = value / ticks to get there, one route search
## per decision): FOOD (an item lying in the arena, by its stack value; the skull is avoided), SPOT (a visible spot:
## walk to a stand from which a strike reaches its cell - the bot never knows what is inside), BANK (crouch in an open
## cookpot once the stack reaches BANK_AT, sooner when the Feast Rush is near), ATTACK (a rival carrying food; the
## Hunter prefers the leader and the banker, whom a stomp robs double), WANDER (nothing better: never idle). A goal is
## kept unless another is clearly better (HYSTERESIS_PERCENT).
## Combat micro-rules, on what the bot saw `reaction` ticks ago: a forward strike when a rival's body will be in the
## club's front box, a high strike against a jumper above within VersusTuning.BOT_ANTI_AIR_PX; the Hunter also
## crouch-charges against an approaching rival and jumps to stomp a croucher (a banker). The Rookie never charges,
## never stomps on purpose and hesitates (it acts on a micro-rule only half of the time, its own SimRng).

enum Goal { NONE, WANDER, FOOD, SPOT, BANK, ATTACK }

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
## Hunter: crouch-charge when a rival walks toward it from this far (px), for this long (ticks).
const CHARGE_FROM_PX: int = 96
const CHARGE_TO_PX: int = 44
const CHARGE_TICKS: int = 10
## Hunter: jump at a croucher this far away (px, same floor).
const STOMP_MIN_PX: int = 10
const STOMP_MAX_PX: int = 56
## Ticks the strike rule looks ahead on the seen rival (the front box is out on ticks 5-7 of the swing).
const STRIKE_LEAD_TICKS: int = 5

var goal: int = Goal.NONE
var goal_pos: Vector2i = Vector2i.ZERO
var goal_utility: int = 0
## The goal's entity (item, spot, pot) or rival slot; checked every tick.
var goal_entity: Object = null
var goal_slot: int = -1
## SPOT: the stand {"node", "x", "facing", "kind"}.
var goal_stand: Dictionary = {}
## Statistics (tests): decisions per goal kind, strikes, charges, stomp jumps.
var decisions: PackedInt32Array = PackedInt32Array([0, 0, 0, 0, 0, 0])
var strikes: int = 0
var charges: int = 0
var stomp_jumps: int = 0

var _sequence: Array[Vector2i] = []
# Strikes at a spot that did not lower its hits: instance id -> [strikes, hits_left when counted].
var _spot_tries: Dictionary = {}


## A spot struck this often without effect is given up for the level (a stand that does not reach it after all).
const SPOT_TRIES_MAX: int = 4


func reset() -> void:
	super.reset()
	goal = Goal.NONE
	goal_entity = null
	goal_slot = -1
	goal_stand = {}
	goal_utility = 0
	_sequence.clear()
	_spot_tries.clear()


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
	var reach: Dictionary = {}
	if graph != null:
		var from: int = bot.nav.node_of(hero)
		if from < 0:
			from = graph.node_below(hero.sim_pos)
		if from < 0:
			from = graph.nearest_node(hero.sim_pos)
		reach = graph.reach_from(from, hero.sim_pos.x, bot.nav.blocked)
	var best: Dictionary = {"goal": Goal.WANDER, "utility": 0}
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
		_offer(best, Goal.SPOT, value * SCALE / (cost + COST_BIAS + strike), stand_pos, spot, -1, stand)
	# BANK
	var bank_at: int = BANK_AT[bot.bot_level]
	var left: int = BotSenses.ticks_left(level)
	var rush_near: bool = left >= 0 and left <= VersusTuning.FEAST_RUSH_TICKS + BANK_BEFORE_RUSH_TICKS
	var banking_now: bool = goal == Goal.BANK
	if stack > 0 and (stack >= bank_at or banking_now or (rush_near and bot.bot_level != Defs.BotLevel.ROOKIE)):
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
		if not BotSenses.are_rivals(level, bot.slot, rival):
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
		if bot.bot_level == Defs.BotLevel.ROOKIE:
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
		action_ticks = 0
		_sequence.clear()


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
	nav.set_weight_class(weight_class(BotSenses.stack_of(level, bot.slot)))
	var stun_min: int = VersusTuning.STUN_HIT_TIMER_MIN if Game.mode == Defs.GameMode.VERSUS else Tuning.HIT_STUN_MIN
	if hero.hit_timer >= stun_min:
		# Stunned: the hero ignores every input; drop what was planned for these ticks.
		action_ticks = 0
		_sequence.clear()
		return 0
	if nav.is_busy():
		return nav.step(hero, tick)
	if not _sequence.is_empty():
		return _play_sequence()
	if action_ticks > 0:
		return hold_action()
	var micro: int = _micro_rules(hero, level)
	if micro >= 0:
		return micro
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


## The combat micro-rules; -1 when none applies.
func _micro_rules(hero: PlayerBase, level: LevelBase) -> int:
	if not hero.is_grounded() or hero.attack_gate or hero.swing_lock > 0:
		return -1
	var hunter: bool = bot.bot_level != Defs.BotLevel.ROOKIE
	var me: Vector2i = hero.sim_pos
	var banking: bool = goal == Goal.BANK and hero.is_low()
	for rival: int in Defs.MAX_PLAYERS:
		if not BotSenses.are_rivals(level, bot.slot, rival):
			continue
		var seen: PackedInt32Array = bot.seen(rival)
		var bits: int = seen[HeroBot.SEEN_BITS]
		if (bits & HeroBot.SEEN_PRESENT) == 0 or (bits & HeroBot.SEEN_SAFE) != 0:
			continue
		var pos: Vector2i = Vector2i(seen[HeroBot.SEEN_X], seen[HeroBot.SEEN_Y])
		var ahead: Vector2i = pos + Vector2i(Tuning.floor16(seen[HeroBot.SEEN_XVEL] * STRIKE_LEAD_TICKS),
				Tuning.floor16(seen[HeroBot.SEEN_YVEL] * STRIKE_LEAD_TICKS))
		var dx: int = ahead.x - me.x
		var facing: int = 1 if dx >= 0 else -1
		var worth: bool = seen[HeroBot.SEEN_STACK] > 0 or goal_slot == rival \
				or (seen[HeroBot.SEEN_BITS] & HeroBot.SEEN_STRIKING) != 0
		if banking and not hunter:
			continue
		# Anti-air: a jumper above within reach.
		if (bits & HeroBot.SEEN_GROUNDED) == 0 and pos.y < me.y - 16 and absi(pos.x - me.x) <= VersusTuning.BOT_ANTI_AIR_PX \
				and front_box(me, facing, STRIKE_HIGH).intersects(body_box(ahead)):
			if _decide():
				strikes += 1
				return start_action(dir_flag(facing) | STRIKE_FLAGS[STRIKE_HIGH], strike_ticks(STRIKE_HIGH))
		# Forward strike: his body will be in the front box.
		if worth and front_box(me, facing, STRIKE_FORWARD).intersects(body_box(ahead)):
			if _decide():
				strikes += 1
				return start_action(dir_flag(facing) | STRIKE_FLAGS[STRIKE_FORWARD], strike_ticks(STRIKE_FORWARD))
		if not hunter or banking:
			continue
		var same_floor: bool = absi(pos.y - me.y) <= 8 and (bits & HeroBot.SEEN_GROUNDED) != 0
		var distance: int = absi(pos.x - me.x)
		# Stomp a croucher (a banker pays double).
		if same_floor and (bits & HeroBot.SEEN_CROUCHING) != 0 and distance >= STOMP_MIN_PX \
				and distance <= STOMP_MAX_PX and hero.no_jump == 0:
			stomp_jumps += 1
			var toward: int = dir_flag(pos.x - me.x)
			var drift: int = clampi(distance / 3, 2, 14)
			_sequence = [Vector2i(Defs.IN_UP | toward, drift), Vector2i(Defs.IN_UP, 14 - mini(drift, 13)),
					Vector2i(0, 8)]
			return _play_sequence()
		# Crouch-charge against a rival walking in.
		var closing: bool = seen[HeroBot.SEEN_XVEL] != 0 and (seen[HeroBot.SEEN_XVEL] > 0) == (pos.x < me.x)
		if worth and same_floor and closing and distance <= CHARGE_FROM_PX and distance >= CHARGE_TO_PX \
				and hero.charge == 0 and absi(hero.xvel) < 16:
			charges += 1
			return start_action(Defs.IN_DOWN, CHARGE_TICKS)
	return -1


## Weight class of a stack (PHYSICS.md C.14: 10+ units heavy, 20+ heavier).
static func weight_class(stack: int) -> int:
	if stack >= VersusTuning.STACK_HEAVIER:
		return 2
	if stack >= VersusTuning.STACK_HEAVY:
		return 1
	return 0


## The Rookie hesitates: it takes a micro-rule only half of the time (its own SimRng).
func _decide() -> bool:
	if bot.bot_level == Defs.BotLevel.ROOKIE:
		return bot.rng.chance(1, 2)
	return true


func _play_sequence() -> int:
	while not _sequence.is_empty() and _sequence[0].y <= 0:
		_sequence.pop_front()
	if _sequence.is_empty():
		return 0
	var step: Vector2i = _sequence[0]
	_sequence[0] = Vector2i(step.x, step.y - 1)
	return step.x
