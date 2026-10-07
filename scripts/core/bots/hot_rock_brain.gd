class_name HotRockBrain
extends BotBrain
## The Hot Rock bot (DESIGN.md E.4 / E.7, GAMEPLAY.md 13.10.5): a glowing ember sticks to one hero and passes on any
## touch, hit or stomp; whoever passed it cannot get it back for 44 ticks; the holder walks faster (96 v16); when the
## fuse ends the holder pops and is out; last one standing wins. Owner: core-B.
##
## The bot knows who holds the ember and whether it bubbles fast (both visible), never the hidden fuse length.
## Holder: chase the rival it can pass to (not pass-immune) that is cheapest to reach, run into him (a body touch
## passes it; the strike micro-rules too) - the faster walk makes it a real chase; navigation uses the holder's weight
## class (NavGraph.WEIGHT_HOLDER: 96 v16). Not the holder: keep away from the holder - the reachable point whose
## distance from him is largest for the walk it costs ([method BotBrain.far_point]); never touch him (no strike,
## no stomp: [method may_contact]); before the first holder is picked, spread out. Every level reacts late by its
## reaction ticks; the Rookie also re-plans its escape only every other decision.

enum Goal { NONE, WANDER, CHASE, FLEE, SPREAD, SAFETY }

## Flee: points the hero reaches within this many ticks are considered.
const FLEE_MAX_COST: int = 120
## Chase a rival this close with the strike rules too (px).
const CHASE_STRIKE_PX: int = 40

var goal: int = Goal.NONE
var goal_pos: Vector2i = Vector2i.ZERO
var goal_slot: int = -1
## Statistics (tests): decisions per goal kind.
var decisions: PackedInt32Array = PackedInt32Array([0, 0, 0, 0, 0, 0])
var _decisions_made: int = 0


func reset() -> void:
	super.reset()
	goal = Goal.NONE
	goal_slot = -1
	_decisions_made = 0


func nav_class(_hero: PlayerBase, level: LevelBase) -> int:
	return NavGraph.WEIGHT_HOLDER if BotSenses.ember_holder(level) == bot.slot else NavGraph.WEIGHT_LIGHT


func holding(level: LevelBase) -> bool:
	return BotSenses.ember_holder(level) == bot.slot


func wants_contact() -> bool:
	return holding(bot.level)


func may_contact(rival: int) -> bool:
	var level: LevelBase = bot.level
	var holder: int = BotSenses.ember_holder(level)
	if holder == bot.slot:
		# Pass it on: touch anyone who can take it.
		return BotSenses.ember_pass_immune(level, rival) <= 0
	# Never touch the holder.
	return rival != holder


func worth_hitting(rival: int, _seen: PackedInt32Array) -> bool:
	# A non-holder gains nothing from hits; the holder hits the one he chases (or anyone who can take it).
	return holding(bot.level) and (rival == goal_slot or BotSenses.ember_pass_immune(bot.level, rival) <= 0)


func needs_thinking(_tick: int) -> bool:
	if goal == Goal.NONE:
		return true
	var level: LevelBase = bot.level
	var holder_me: bool = holding(level)
	# The ember changed hands: decide now.
	return (goal == Goal.CHASE) != holder_me


func think(hero: PlayerBase, level: LevelBase, _tick: int) -> void:
	_decisions_made += 1
	var safe: Vector2i = safety_target(hero, level)
	if safe != BotSenses.NO_POS:
		_goal_to(Goal.SAFETY, safe, -1)
		return
	var holder: int = BotSenses.ember_holder(level)
	if holder == bot.slot:
		var reach: Dictionary = bot.nav.reach(hero)
		var best: int = -1
		var best_cost: int = NavGraph.UNREACHABLE
		for rival: int in Defs.MAX_PLAYERS:
			if not bot.is_rival(rival) or not bot.seen_alive(rival):
				continue
			if BotSenses.ember_pass_immune(level, rival) > 0:
				continue
			var pos: Vector2i = bot.seen_pos(rival)
			var cost: int = bot.nav.graph.reach_cost(reach, pos) if not reach.is_empty() \
					else NavGraph.walk_ticks(pos.x - hero.sim_pos.x)
			if cost < best_cost:
				best_cost = cost
				best = rival
		if best >= 0:
			_goal_to(Goal.CHASE, bot.seen_pos(best), best)
			return
		_goal_to(Goal.WANDER, wander_target(hero), -1)
		return
	var away: Array[Vector2i] = []
	if restless():
		away.append(hero.sim_pos)  # stood here long enough: somewhere else
	if holder >= 0 and bot.seen_alive(holder):
		# The Rookie re-plans its escape only every other decision (it hesitates).
		if goal == Goal.FLEE and rookie() and _decisions_made % 2 == 1 and not restless():
			return
		# Where the holder (the faster walker, planning with his own links) arrives latest, never past him.
		var chasers: Array[int] = [holder]
		var point: Vector2i = escape_point(hero, chasers, FLEE_MAX_COST, NavGraph.WEIGHT_HOLDER, restless())
		if point != BotSenses.NO_POS:
			_goal_to(Goal.FLEE, point, holder)
			return
	else:
		for rival: int in Defs.MAX_PLAYERS:
			if rival != bot.slot and bot.seen_alive(rival):
				away.append(bot.seen_pos(rival))
		var spread: Vector2i = far_point(hero, away, FLEE_MAX_COST)
		if spread != BotSenses.NO_POS:
			_goal_to(Goal.SPREAD, spread, -1)
			return
	_goal_to(Goal.WANDER, wander_target(hero), -1)


func _goal_to(kind: int, pos: Vector2i, rival: int) -> void:
	if kind != goal or rival != goal_slot:
		decisions[kind] += 1
		if kind == Goal.SAFETY:
			escapes += 1
		cancel_actions()
	goal = kind
	goal_pos = pos
	goal_slot = rival


func act(hero: PlayerBase, level: LevelBase, tick: int) -> int:
	var common: int = act_common(hero, level, tick)
	if common >= 0:
		return common
	var nav: BotNavigator = bot.nav
	match goal:
		Goal.CHASE:
			var pos: Vector2i = bot.seen_pos(goal_slot)
			# Run into him: aim at his feet point, no tolerance.
			nav.set_target(pos, 0)
			var flags: int = nav.step(hero, tick)
			if flags == 0 and not nav.is_busy() and hero.is_grounded() and absi(pos.x - hero.sim_pos.x) <= CHASE_STRIKE_PX:
				flags = dir_flag(pos.x - hero.sim_pos.x)
			return flags
		Goal.FLEE, Goal.SPREAD, Goal.SAFETY:
			nav.set_target(goal_pos, 6)
		_:
			nav.set_target(goal_pos, 6)
	return nav.step(hero, tick)
