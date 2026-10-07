class_name BotBrain
extends RefCounted
## The decisions of a [HeroBot] in one versus mode (DESIGN.md E.7): [method think] chooses a goal every
## VersusTuning.BOT_GOAL_PERIOD_TICKS by utility, [method act] turns the goal and the combat micro-rules into this
## tick's flags. Owner: core-B. This base class only wanders (a mode without a brain of its own); the modes:
## [GrubStackBrain], [LastCavemanBrain], [HotRockBrain], [ClubballBrain]; the boss: [ChieftainBrain].
##
## Shared here: the strike geometry of the club (Tuning.STRIKE_SCRIPT_* / CLUB_ORIGIN / CLUB_BOX, PHYSICS.md 8.1 -
## 8.3), where to stand to strike a spot, timed actions (hold some flags for n ticks), wandering, safety from the
## telegraphed dangers, and the **combat micro-rules** of E.7 on what the bot saw `reaction` ticks ago:
##  - anti-air: a high strike against a jumper above within VersusTuning.BOT_ANTI_AIR_PX (every level);
##  - a forward strike when a rival worth hitting ([method worth_hitting]) will be in the club's front box;
##  - bat a curled rival towards a hazard (a front box from the side, PHYSICS.md C.11);
##  - Hunter and Chief: stomp a croucher (jump at him), crouch-charge against a rival walking in;
##  - deflect a rival's thrown special with a forward strike: never the Rookie, the Hunter HUNTER_DEFLECT_PERCENT of
##    the time, the Chief VersusTuning.BOT_CHIEF_DEFLECT_PERCENT (decided once per projectile, on the bot's SimRng);
##  - Chief: stomp chains - falling, he steers onto the next rival head and holds UP for the big bounce;
##  - the Rookie hesitates (takes a micro-rule only half of the time), never charges, stomps or deflects; the Hunter
##    and the Chief wait a random 0-3 / 0-1 ticks before a forward strike ([method strike_now]), so two bots never
##    swing in lockstep into clang after clang.
## A mode narrows them with [method worth_hitting] and [method may_contact] (Hot Rock: never touch the holder).
## Always: a bot keeps its spawn shield - no strike or throw while it is up ([method may_strike]; PLAN.md 8 V4.b: no
## hit within 48 ticks of a spawn); it attacks from a strike stand beside the rival ([method attack_stand]), never by
## running into him ([method guard_ramming]: the C.14 body knock gains nothing), and runs from a chaser to the place
## he reaches latest ([method escape_point]).

## Strike kinds: the keys pressed with the facing direction, and the frames they play.
const STRIKE_FORWARD: int = 0
const STRIKE_HIGH: int = 1
const STRIKE_LOW: int = 2
const STRIKE_FLAGS: Array[int] = [Defs.IN_FIRE, Defs.IN_FIRE | Defs.IN_UP, Defs.IN_FIRE | Defs.IN_DOWN]
## Ticks a wander target is kept at most.
const WANDER_TICKS: int = 146
## Hunter: crouch-charge when a rival walks toward it from this far (px), for this long (ticks).
const CHARGE_FROM_PX: int = 96
const CHARGE_TO_PX: int = 44
const CHARGE_TICKS: int = 10
## Hunter: jump at a croucher this far away (px, same floor).
const STOMP_MIN_PX: int = 10
const STOMP_MAX_PX: int = 56
## Ticks the strike rule looks ahead on the seen rival (the front box is out on ticks 5-7 of the swing).
const STRIKE_LEAD_TICKS: int = 5
## The Hunter deflects a rival's special this often (percent; the Chief: VersusTuning.BOT_CHIEF_DEFLECT_PERCENT).
const HUNTER_DEFLECT_PERCENT: int = 25
## A bot that stood still this long (HeroBot.idle_ticks) looks for another place (never idle 10 s, PLAN 8 V4.b).
const RESTLESS_TICKS: int = 96
## Look this far ahead for telegraphed dangers (ticks) and keep this far away from them (px).
const DANGER_LOOKAHEAD_TICKS: int = 24
const DANGER_MARGIN_PX: int = 12
## A safe point is picked this much farther out still (the walk stops within a few px of it).
const SAFETY_SLACK_PX: int = 8
## Escaping a chaser ([method escape_point]): a point counts as safe when the hero gets there this many ticks before
## him; chaser costs are capped here (an unreachable point is this far away for him).
const ESCAPE_MARGIN_TICKS: int = 12
const ESCAPE_CAP_TICKS: int = 240
## Attacking: stand this far from the rival's feet point (his body is in the forward front box from 0 to 49 px away),
## on the hero's own side of him - a strike, not a body bump.
const STRIKE_STAND_PX: int = 28
## Once a rival is in reach, the forward strike waits a random 0..n ticks per Defs.BotLevel (the Rookie hesitates by
## [method decide] instead), so that two bots never swing in lockstep into clang after clang.
const STRIKE_JITTER_TICKS: Array[int] = [0, 3, 1]
## Ramming guard: never run at a rival closer than this (px apart, same floor) at 3+ px/tick - two heroes running into
## each other are knocked back (PHYSICS.md C.14 body bump), which gains nothing. The Hot Rock holder may.
const RAM_GUARD_PX: int = 38
const RAM_MIN_XVEL: int = 48

## The bot this brain decides for (held weakly: the bot owns the brain, so a strong reference back would be a
## reference cycle that never frees).
var bot: HeroBot:
	get:
		return _bot_ref.get_ref() as HeroBot if _bot_ref != null else null
	set(value):
		_bot_ref = weakref(value) if value != null else null
var _bot_ref: WeakRef = null
static var _stand_cache: Dictionary = {}

## The timed action being held (flags) and its ticks left.
var action_flags: int = 0
var action_ticks: int = 0
## Statistics (tests): strikes, charges, stomp jumps, deflects, bats, chain steers, danger escapes.
var strikes: int = 0
var charges: int = 0
var stomp_jumps: int = 0
var deflects: int = 0
var bats: int = 0
var chain_steers: int = 0
var escapes: int = 0
var _wander: Vector2i = Vector2i(-1, -1)
var _wander_age: int = 0
var _sequence: Array[Vector2i] = []
# Projectile instance id -> true (deflect) / false (let it be): decided once each.
var _deflect_choice: Dictionary = {}
var _projectile_seen: Dictionary = {}
# The forward strike's jitter: ticks still to wait (-1 = none drawn) and the last tick a rival was in reach.
var _strike_wait: int = -1
var _strike_tick: int = -2
# The dangers of the last decision (safety_target).
var _dangers: Array[Rect2i] = []


## Forget the cached spot stands (tests; a re-baked graph).
static func clear_cache() -> void:
	_stand_cache.clear()


## Forget goals and actions (a new level or round).
func reset() -> void:
	action_flags = 0
	action_ticks = 0
	_wander = Vector2i(-1, -1)
	_wander_age = 0
	_sequence.clear()
	_deflect_choice.clear()
	_projectile_seen.clear()
	_strike_wait = -1
	_strike_tick = -2
	_dangers.clear()


## True when the brain wants body contact with rivals (the Hot Rock holder passing the ember): no ramming guard.
func wants_contact() -> bool:
	return false


## Where to stand to strike the rival whose feet were seen at `pos`: STRIKE_STAND_PX from him on the hero's side.
func attack_stand(hero: PlayerBase, pos: Vector2i) -> Vector2i:
	var side: int = -1 if hero.sim_pos.x < pos.x else 1
	if hero.sim_pos.x == pos.x:
		side = -hero.facing if hero.facing != 0 else -1
	return Vector2i(pos.x + side * STRIKE_STAND_PX, pos.y)


## `flags` without a walk at a rival close ahead while the hero already runs at him (the ramming guard; the rival's
## place is extrapolated from what the bot saw over its reaction ticks, as a player anticipates).
func guard_ramming(hero: PlayerBase, flags: int) -> int:
	if wants_contact() or not hero.is_grounded() or (flags & (Defs.IN_LEFT | Defs.IN_RIGHT)) == 0:
		return flags
	var dir: int = 1 if (flags & Defs.IN_RIGHT) != 0 else -1
	if hero.xvel * dir < RAM_MIN_XVEL:
		return flags
	for rival: int in Defs.MAX_PLAYERS:
		if not bot.is_rival(rival) or not bot.seen_alive(rival):
			continue
		var pos: Vector2i = bot.predicted_pos(rival)
		var dx: int = (pos.x - hero.sim_pos.x) * dir
		if dx > 0 and dx < RAM_GUARD_PX and absi(pos.y - hero.sim_pos.y) < Tuning.HERO_BOX_STAND.y:
			return flags & ~(Defs.IN_LEFT | Defs.IN_RIGHT)
	return flags


## The forward strike's jitter (Hunter 0-3, Chief 0-1 random ticks once a rival is in reach; the Rookie decides by
## [method decide]): true on the tick to strike.
func strike_now() -> bool:
	if rookie():
		return decide()
	var tick: int = Sim.tick
	if _strike_tick != tick - 1 and _strike_tick != tick:
		_strike_wait = -1
	_strike_tick = tick
	if _strike_wait < 0:
		_strike_wait = bot.rng.range_int(0, STRIKE_JITTER_TICKS[bot.bot_level])
	if _strike_wait == 0:
		_strike_wait = -1
		return true
	_strike_wait -= 1
	return false


## True when the brain wants a decision this tick outside the regular period (no goal yet).
func needs_thinking(_tick: int) -> bool:
	return false


## Choose a goal (every VersusTuning.BOT_GOAL_PERIOD_TICKS ticks).
func think(hero: PlayerBase, _level: LevelBase, _tick: int) -> void:
	wander_target(hero)


## The flags of this tick.
func act(hero: PlayerBase, level: LevelBase, tick: int) -> int:
	var common: int = act_common(hero, level, tick)
	if common >= 0:
		return common
	if _wander.x < 0:
		_pick_wander(hero)
	bot.nav.set_target(_wander, 6)
	return bot.nav.step(hero, tick)


## The flags of a tick while the hero is out of play (dead, out of the round): 0 here; the Last Caveman Standing
## brain steers its Grudge Pterodactyl.
func act_out(_level: LevelBase, _tick: int) -> int:
	return 0


## The weight class of the hero for the navigator (NavGraph.WEIGHT_*): light here.
func nav_class(_hero: PlayerBase, _level: LevelBase) -> int:
	return NavGraph.WEIGHT_LIGHT


## Is the seen rival in `rival` worth a strike? (every rival here)
func worth_hitting(_rival: int, _seen: PackedInt32Array) -> bool:
	return true


## May the bot touch (strike, stomp, bump) the rival in `rival`? (always here; Hot Rock: never the holder)
func may_contact(_rival: int) -> bool:
	return true


## The part of [method act] every mode shares; -1 when the mode decides: a stunned hero presses nothing, a link or a
## held action or sequence continues, the micro-rules.
func act_common(hero: PlayerBase, level: LevelBase, tick: int) -> int:
	var stun_min: int = VersusTuning.STUN_HIT_TIMER_MIN if Game.mode == Defs.GameMode.VERSUS else Tuning.HIT_STUN_MIN
	if hero.hit_timer >= stun_min:
		# Stunned: the hero ignores every input; drop what was planned for these ticks.
		action_ticks = 0
		_sequence.clear()
		return 0
	if bot.nav.is_busy():
		var air: int = air_steer(hero, level)
		if air >= 0 and not (bot.nav.link.kind in [NavGraph.KIND_SPRING, NavGraph.KIND_GEYSER]):
			bot.nav.link = null
			return air
		return bot.nav.step(hero, tick)
	if not _sequence.is_empty():
		return play_sequence()
	if action_ticks > 0:
		return hold_action()
	if not hero.is_grounded():
		var steer: int = air_steer(hero, level)
		if steer >= 0:
			return steer
	return combat(hero, level)


## Start holding `flags` for `ticks` ticks (a strike, a crouch).
func start_action(flags: int, ticks: int) -> int:
	action_flags = flags
	action_ticks = ticks
	return hold_action()


## One tick of the held action.
func hold_action() -> int:
	if action_ticks <= 0:
		return 0
	action_ticks -= 1
	return action_flags


## Start a sequence of (flags, ticks) steps.
func start_sequence(steps: Array[Vector2i]) -> int:
	_sequence = steps.duplicate()
	return play_sequence()


## True while a sequence is being played.
func in_sequence() -> bool:
	return not _sequence.is_empty()


## One tick of the sequence.
func play_sequence() -> int:
	while not _sequence.is_empty() and _sequence[0].y <= 0:
		_sequence.pop_front()
	if _sequence.is_empty():
		return 0
	var step: Vector2i = _sequence[0]
	_sequence[0] = Vector2i(step.x, step.y - 1)
	return step.x


## Drop what is being held (a new goal).
func cancel_actions() -> void:
	action_ticks = 0
	_sequence.clear()


## True when the hero has stood still RESTLESS_TICKS: time to move somewhere else.
func restless() -> bool:
	return bot.idle_ticks >= RESTLESS_TICKS


func rookie() -> bool:
	return bot.bot_level == Defs.BotLevel.ROOKIE


func chief() -> bool:
	return bot.bot_level == Defs.BotLevel.CHIEF


## True when the hero may start a strike or a throw now: a versus bot keeps its spawn shield (PHYSICS.md C.14: 48
## ticks after every (re)spawn, ended by the hero's own first strike or throw), so nobody lands a hit on it within
## VersusTuning.SPAWN_SHIELD_TICKS of a spawn (PLAN.md 8 V4.b); it walks to its goal meanwhile. A boss body has no
## shield rule.
func may_strike(hero: PlayerBase) -> bool:
	return bot.body != null or hero.shield <= 0


## The Rookie hesitates: it takes a micro-rule only half of the time (its own SimRng).
func decide() -> bool:
	if rookie():
		return bot.rng.chance(1, 2)
	return true


# =================================================================================================================
# Combat micro-rules (DESIGN.md E.7)
# =================================================================================================================

## The grounded micro-rules on the seen rivals; -1 when none applies.
func combat(hero: PlayerBase, level: LevelBase) -> int:
	if not hero.is_grounded() or hero.attack_gate or hero.swing_lock > 0 or hero.is_curled() or hero.squash > 0 \
			or not may_strike(hero):
		return -1
	var deflect: int = _deflect(hero, level)
	if deflect >= 0:
		return deflect
	var me: Vector2i = hero.sim_pos
	for rival: int in Defs.MAX_PLAYERS:
		if not bot.is_rival(rival) or not may_contact(rival):
			continue
		var seen: PackedInt32Array = bot.seen(rival)
		var bits: int = seen[HeroBot.SEEN_BITS]
		if (bits & HeroBot.SEEN_PRESENT) == 0 or (bits & HeroBot.SEEN_GONE) != 0:
			continue
		var pos: Vector2i = Vector2i(seen[HeroBot.SEEN_X], seen[HeroBot.SEEN_Y])
		var ahead: Vector2i = pos + Vector2i(Tuning.floor16(seen[HeroBot.SEEN_XVEL] * STRIKE_LEAD_TICKS),
				Tuning.floor16(seen[HeroBot.SEEN_YVEL] * STRIKE_LEAD_TICKS))
		var dx: int = ahead.x - me.x
		var facing: int = 1 if dx >= 0 else -1
		# Bat a curled rival towards a hazard (no immunity protects a curled hero from a bat).
		if (bits & HeroBot.SEEN_CURLED) != 0:
			var hazard: int = BotSenses.hazard_side(level, pos)
			if hazard != 0 and hazard == facing and front_box(me, facing, STRIKE_FORWARD).intersects(body_box(ahead)) \
					and decide():
				bats += 1
				strikes += 1
				return start_action(dir_flag(facing) | STRIKE_FLAGS[STRIKE_FORWARD], strike_ticks(STRIKE_FORWARD))
			continue
		if (bits & HeroBot.SEEN_SAFE) != 0:
			continue
		# Anti-air: a jumper above within reach.
		if (bits & HeroBot.SEEN_GROUNDED) == 0 and pos.y < me.y - 16 and absi(pos.x - me.x) <= VersusTuning.BOT_ANTI_AIR_PX \
				and front_box(me, facing, STRIKE_HIGH).intersects(body_box(ahead)):
			if decide():
				strikes += 1
				return start_action(dir_flag(facing) | STRIKE_FLAGS[STRIKE_HIGH], strike_ticks(STRIKE_HIGH))
		var worth: bool = worth_hitting(rival, seen)
		# Forward strike: his body will be in the front box (both moving on for the lead ticks).
		var me_ahead: Vector2i = me + Vector2i(Tuning.floor16(hero.xvel * STRIKE_LEAD_TICKS), 0)
		if worth and (front_box(me_ahead, facing, STRIKE_FORWARD).intersects(body_box(ahead))
				or front_box(me, facing, STRIKE_FORWARD).intersects(body_box(ahead))):
			if strike_now():
				strikes += 1
				return start_action(dir_flag(facing) | STRIKE_FLAGS[STRIKE_FORWARD], strike_ticks(STRIKE_FORWARD))
			continue
		if rookie():
			continue
		var same_floor: bool = absi(pos.y - me.y) <= 8 and (bits & HeroBot.SEEN_GROUNDED) != 0
		var distance: int = absi(pos.x - me.x)
		# Stomp a croucher (a banker pays double).
		if worth and same_floor and (bits & HeroBot.SEEN_CROUCHING) != 0 and distance >= STOMP_MIN_PX \
				and distance <= STOMP_MAX_PX and hero.no_jump == 0:
			stomp_jumps += 1
			var toward: int = dir_flag(pos.x - me.x)
			var drift: int = clampi(distance / 3, 2, 14)
			return start_sequence([Vector2i(Defs.IN_UP | toward, drift), Vector2i(Defs.IN_UP, 14 - mini(drift, 13)),
					Vector2i(0, 8)])
		# Crouch-charge against a rival walking in.
		var closing: bool = seen[HeroBot.SEEN_XVEL] != 0 and (seen[HeroBot.SEEN_XVEL] > 0) == (pos.x < me.x)
		if worth and same_floor and closing and distance <= CHARGE_FROM_PX and distance >= CHARGE_TO_PX \
				and hero.charge == 0 and absi(hero.xvel) < 16:
			charges += 1
			return start_action(Defs.IN_DOWN, CHARGE_TICKS)
	return -1


## Airborne steering onto a rival head below (Hunter: a croucher; Chief: any head - stomp chains), UP held for the
## big bounce when the Chief chains; -1 when there is none to steer at.
func air_steer(hero: PlayerBase, _level: LevelBase) -> int:
	if rookie() or hero.is_grounded() or hero.yvel < 0 or hero.is_curled():
		return -1
	var me: Vector2i = hero.sim_pos
	var best: int = -1
	var best_dx: int = 1 << 20
	for rival: int in Defs.MAX_PLAYERS:
		if not bot.is_rival(rival) or not may_contact(rival):
			continue
		var seen: PackedInt32Array = bot.seen(rival)
		var bits: int = seen[HeroBot.SEEN_BITS]
		if (bits & HeroBot.SEEN_PRESENT) == 0 or (bits & (HeroBot.SEEN_GONE | HeroBot.SEEN_CURLED)) != 0:
			continue
		if not chief() and (bits & HeroBot.SEEN_CROUCHING) == 0:
			continue
		if not worth_hitting(rival, seen):
			continue
		var head: int = seen[HeroBot.SEEN_Y] - Tuning.HERO_BOX_STAND.y
		var below: int = head - me.y
		var dx: int = seen[HeroBot.SEEN_X] - me.x
		# Reachable while falling: under him, not too far aside for the fall left.
		if below < 4 or below > 96 or absi(dx) > 8 + below:
			continue
		if absi(dx) < absi(best_dx):
			best_dx = dx
			best = rival
	if best < 0:
		return -1
	chain_steers += 1
	var flags: int = dir_flag(best_dx) if absi(best_dx) > 3 else 0
	if chief():
		flags |= Defs.IN_UP
	return flags


## Deflect a rival's special flying at the hero: a forward strike timed so that the front box meets it.
func _deflect(hero: PlayerBase, level: LevelBase) -> int:
	if rookie():
		return -1
	var percent: int = VersusTuning.BOT_CHIEF_DEFLECT_PERCENT if chief() else HUNTER_DEFLECT_PERCENT
	var me: Vector2i = hero.sim_pos
	for projectile: SimEntity in BotSenses.rival_projectiles(level, bot.slot if bot.body == null else -1):
		var id: int = projectile.get_instance_id()
		# Seen as late as the heroes: only after `reaction` ticks in the air.
		var first: int = int(_projectile_seen.get(id, Sim.tick))
		_projectile_seen[id] = first
		if Sim.tick - first < bot.reaction:
			continue
		var toward: int = -1 if projectile.xvel > 0 else 1  # the side of the hero it comes from
		if (projectile.sim_pos.x - me.x) * toward <= 0 or projectile.xvel == 0:
			continue
		var at: Vector2i = projectile.sim_pos + Vector2i(Tuning.floor16(projectile.xvel * STRIKE_LEAD_TICKS),
				Tuning.floor16(projectile.yvel * STRIKE_LEAD_TICKS))
		var box: Rect2i = Rect2i(at.x - projectile.box_xo, at.y - projectile.box_h, projectile.box_w, projectile.box_h)
		if not front_box(me, toward, STRIKE_FORWARD).intersects(box):
			continue
		if not _deflect_choice.has(id):
			_deflect_choice[id] = bot.rng.chance(percent, 100)
		if not bool(_deflect_choice[id]):
			continue
		deflects += 1
		strikes += 1
		return start_action(dir_flag(toward) | STRIKE_FLAGS[STRIKE_FORWARD], strike_ticks(STRIKE_FORWARD))
	return -1


# =================================================================================================================
# Safety
# =================================================================================================================

## A feet point out of every telegraphed danger near the hero (the cheapest node point whose body box stays
## DANGER_MARGIN_PX away from every danger box); BotSenses.NO_POS when the hero is safe (or nowhere is).
## The dangers it read are kept for [method is_dangerous] until the next decision.
func safety_target(hero: PlayerBase, level: LevelBase) -> Vector2i:
	var dangers: Array[Rect2i] = BotSenses.danger_rects(level, DANGER_LOOKAHEAD_TICKS)
	_dangers = dangers
	if dangers.is_empty() or not _in_danger(hero.sim_pos, dangers):
		return BotSenses.NO_POS
	var graph: NavGraph = bot.nav.graph
	var best: Vector2i = BotSenses.NO_POS
	var best_cost: int = NavGraph.UNREACHABLE
	if graph == null:
		for dx: int in [-48, 48, -96, 96]:
			var p: Vector2i = Vector2i(hero.sim_pos.x + dx, hero.sim_pos.y)
			if not _in_danger(p, dangers, DANGER_MARGIN_PX + SAFETY_SLACK_PX) and absi(dx) < best_cost:
				best_cost = absi(dx)
				best = p
		return best
	var reach: Dictionary = bot.nav.reach(hero)
	for node: NavGraph.NavNode in graph.nodes:
		var x0: int = graph.node_x0(node)
		var x1: int = graph.node_x1(node)
		var y: int = graph.node_y(node)
		var x: int = x0
		while x <= x1:
			var p: Vector2i = Vector2i(x, y)
			if not _in_danger(p, dangers, DANGER_MARGIN_PX + SAFETY_SLACK_PX):
				var cost: int = graph.reach_cost(reach, p)
				if cost < best_cost:
					best_cost = cost
					best = p
			x += 8
	return best


## True when a hero standing at `feet` would be inside a danger the last [method safety_target] read (goals there are
## not worth it).
func is_dangerous(feet: Vector2i) -> bool:
	return not _dangers.is_empty() and _in_danger(feet, _dangers)


static func _in_danger(feet: Vector2i, dangers: Array[Rect2i], margin: int = DANGER_MARGIN_PX) -> bool:
	var box: Rect2i = body_box(feet).grow(margin)
	for rect: Rect2i in dangers:
		if rect.intersects(box):
			return true
	return false


# =================================================================================================================
# Geometry
# =================================================================================================================

## Direction flag toward `dx` (0 when dx is 0).
static func dir_flag(dx: int) -> int:
	if dx > 0:
		return Defs.IN_RIGHT
	if dx < 0:
		return Defs.IN_LEFT
	return 0


## Ticks a strike kind takes (its script length).
static func strike_ticks(kind: int) -> int:
	match kind:
		STRIKE_HIGH:
			return Tuning.STRIKE_SCRIPT_HIGH.size()
		STRIKE_LOW:
			return Tuning.STRIKE_SCRIPT_LOW.size()
	return Tuning.STRIKE_SCRIPT_FORWARD.size()


static func _frames(kind: int) -> Array[int]:
	match kind:
		STRIKE_HIGH:
			return Tuning.STRIKE_SCRIPT_HIGH
		STRIKE_LOW:
			return Tuning.STRIKE_SCRIPT_LOW
	return Tuning.STRIKE_SCRIPT_FORWARD


## True when a strike of `kind` by a hero standing still at `feet` facing `facing` would hit the hidden cell `cell`
## on one of its frames (the hidden-tile test of PHYSICS.md 8.3 #2 on the club origin).
static func strike_hits_cell(feet: Vector2i, facing: int, kind: int, cell: Vector2i) -> bool:
	for frame: int in _frames(kind):
		var origin: Vector2i = Tuning.CLUB_ORIGIN[frame]
		var ox: int = feet.x + facing * origin.x
		var oy: int = feet.y + origin.y
		if absi(cell.x - (ox >> 4)) <= Tuning.HIDDEN_HIT_COLS \
				and absi(cell.y * Tuning.TILE - (oy - Tuning.TILE)) < Tuning.HIDDEN_HIT_PX:
			return true
	return false


## The club box of the front frame of a strike (forward: FWD_FRONT, high: HIGH_FRONT, low: LOW_FRONT) for a hero at
## `feet` facing `facing`, in level px.
static func front_box(feet: Vector2i, facing: int, kind: int) -> Rect2i:
	var frame: int = Tuning.ClubFrame.FWD_FRONT
	if kind == STRIKE_HIGH:
		frame = Tuning.ClubFrame.HIGH_FRONT
	elif kind == STRIKE_LOW:
		frame = Tuning.ClubFrame.LOW_FRONT
	var rect: Rect2i = Tuning.CLUB_BOX[frame]
	var origin: Vector2i = Tuning.CLUB_ORIGIN[frame]
	var xo: int = origin.x - rect.position.x
	var ox: int = feet.x + facing * origin.x
	return Rect2i(ox - xo, feet.y + rect.position.y, rect.size.x, rect.size.y)


## The standing body box of a hero whose feet are at `feet` (Tuning.HERO_BOX_STAND, x_offset centred).
static func body_box(feet: Vector2i) -> Rect2i:
	var box: Vector3i = Tuning.HERO_BOX_STAND
	return Rect2i(feet.x - box.z, feet.y - box.y, box.x, box.y)


## Every place to stand to strike the hidden cell `cell` from: [{"node", "x0", "x1", "x", "facing", "kind"}], one per
## (node, strike kind, facing) - the longest run of feet x on that node from which a strike of that kind, facing
## that way, reaches the cell (never from inside the cell's own column); `x` is the run's middle. Ordered by
## preference: forward strikes first, then high, then low; wider runs first. Cached per graph and cell (the stands of
## a level never change). Mover nodes are skipped.
static func spot_stands(graph: NavGraph, cell: Vector2i) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if graph == null:
		return result
	var key: String = "%s:%d:%d:%d" % [graph.level_id, graph.get_instance_id(), cell.x, cell.y]
	if _stand_cache.has(key):
		return _stand_cache[key]
	for node: NavGraph.NavNode in graph.nodes:
		if node.mover >= 0:
			continue
		if absi(node.row - cell.y) > 4 or node.x1 < (cell.x - 3) * Tuning.TILE or node.x0 > (cell.x + 4) * Tuning.TILE:
			continue
		for kind: int in [STRIKE_FORWARD, STRIKE_HIGH, STRIKE_LOW]:
			for facing: int in [1, -1]:
				var best0: int = 0
				var best1: int = -1
				var run0: int = -1
				for x: int in range(node.x0, node.x1 + 2):
					var hits: bool = x <= node.x1 and (x >> 4) != cell.x \
							and strike_hits_cell(Vector2i(x, node.y), facing, kind, cell)
					if hits and run0 < 0:
						run0 = x
					elif not hits and run0 >= 0:
						if x - 1 - run0 > best1 - best0:
							best0 = run0
							best1 = x - 1
						run0 = -1
				if best1 >= best0:
					result.append({
						"node": node.id, "x0": best0, "x1": best1, "x": (best0 + best1) / 2, "facing": facing,
						"kind": kind,
					})
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["kind"]) != int(b["kind"]):
			return int(a["kind"]) < int(b["kind"])
		var wa: int = int(a["x1"]) - int(a["x0"])
		var wb: int = int(b["x1"]) - int(b["x0"])
		if wa != wb:
			return wa > wb
		if int(a["node"]) != int(b["node"]):
			return int(a["node"]) < int(b["node"])
		return int(a["x0"]) < int(b["x0"])
	)
	_stand_cache[key] = result
	return result


# =================================================================================================================
# Wandering
# =================================================================================================================

func _pick_wander(hero: PlayerBase) -> void:
	var graph: NavGraph = bot.nav.graph
	if graph == null or graph.nodes.is_empty():
		_wander = Vector2i(hero.sim_pos.x + (bot.rng.range_int(-80, 80)), hero.sim_pos.y)
	else:
		var node: NavGraph.NavNode = graph.nodes[bot.rng.next_int(graph.nodes.size())]
		_wander = Vector2i(bot.rng.range_int(node.x0, node.x1), node.y)
	_wander_age = 0


## Keep a wander target for a while, then pick a new one; returns the target. Called once per decision
## (every VersusTuning.BOT_GOAL_PERIOD_TICKS ticks).
func wander_target(hero: PlayerBase) -> Vector2i:
	_wander_age += VersusTuning.BOT_GOAL_PERIOD_TICKS
	if _wander.x < 0 or _wander_age > WANDER_TICKS or (bot.nav.arrived(hero) and bot.nav.target == _wander):
		_pick_wander(hero)
	return _wander


## Where to run from the seen rivals in `chasers` (Hot Rock: the holder; LCS: a healthier rival): the node point
## (sampled every 16 px) the hero reaches within `max_cost` ticks that the nearest chaser - planning on the graph with
## the weight class `chaser_class` from where he was seen - reaches latest, among those the hero reaches first
## (ESCAPE_MARGIN_TICKS ahead of every chaser); when no point is safe, the one where the hero is least late. A chaser
## standing between the hero and a point makes it cheap for him, so the bot never runs past him. `avoid_here`: the
## points within 32 px of the hero score less (a restless bot moves on). NO_POS when there is no point.
func escape_point(hero: PlayerBase, chasers: Array[int], max_cost: int, chaser_class: int = NavGraph.WEIGHT_LIGHT,
		avoid_here: bool = false) -> Vector2i:
	var graph: NavGraph = bot.nav.graph
	var away: Array[Vector2i] = []
	for chaser: int in chasers:
		away.append(bot.seen_pos(chaser))
	if graph == null or graph.nodes.is_empty():
		return far_point(hero, away, max_cost)
	var mine: Dictionary = bot.nav.reach(hero)
	var theirs: Array[Dictionary] = []
	for pos: Vector2i in away:
		var from: int = graph.node_for(pos)
		theirs.append(graph.reach_from(from, pos.x, {}, graph.usable_class(chaser_class)))
	var best: Vector2i = BotSenses.NO_POS
	var best_score: int = -(1 << 30)
	for node: NavGraph.NavNode in graph.nodes:
		var x: int = graph.node_x0(node)
		var x1: int = graph.node_x1(node)
		var y: int = graph.node_y(node)
		while x <= x1:
			var p: Vector2i = Vector2i(x, y)
			x += 16
			var my_cost: int = graph.reach_cost(mine, p)
			if my_cost > max_cost or is_dangerous(p):
				continue
			var his: int = ESCAPE_CAP_TICKS
			for reach: Dictionary in theirs:
				his = mini(his, graph.reach_cost(reach, p))
			var margin: int = his - my_cost
			var score: int = 0
			if margin >= ESCAPE_MARGIN_TICKS:
				score = (1 << 20) + 4 * mini(his, ESCAPE_CAP_TICKS) - my_cost
			else:
				score = 8 * margin - my_cost
			if avoid_here and absi(p.x - hero.sim_pos.x) + absi(p.y - hero.sim_pos.y) < 32:
				score -= 1 << 21
			if score > best_score:
				best_score = score
				best = p
	return best


## The point of `graph`'s nodes (sampled every 16 px) farthest from `away` among those the hero reaches within
## `max_cost` ticks; score = min(distance, cap) * 4 - cost. NO_POS when there is no graph.
func far_point(hero: PlayerBase, away: Array[Vector2i], max_cost: int, cap: int = 160) -> Vector2i:
	var graph: NavGraph = bot.nav.graph
	if graph == null:
		var side: int = 1 if away.is_empty() or away[0].x < hero.sim_pos.x else -1
		return Vector2i(hero.sim_pos.x + side * 64, hero.sim_pos.y)
	var reach: Dictionary = bot.nav.reach(hero)
	var best: Vector2i = BotSenses.NO_POS
	var best_score: int = -(1 << 30)
	for node: NavGraph.NavNode in graph.nodes:
		var x: int = graph.node_x0(node)
		var x1: int = graph.node_x1(node)
		var y: int = graph.node_y(node)
		while x <= x1:
			var p: Vector2i = Vector2i(x, y)
			var cost: int = graph.reach_cost(reach, p)
			if cost <= max_cost:
				var nearest: int = cap
				for other: Vector2i in away:
					nearest = mini(nearest, absi(other.x - p.x) + absi(other.y - p.y))
				var score: int = nearest * 4 - cost
				if score > best_score:
					best_score = score
					best = p
			x += 16
	return best
