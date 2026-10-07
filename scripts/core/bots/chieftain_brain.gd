class_name ChieftainBrain
extends BotBrain
## The brain of a Rival Chieftain (DESIGN.md B.6, GAMEPLAY.md 13.6, PLAN.md P2.3 / P2.5): the boss interface between
## enemies-C's chieftain shell (the phase machine: who fights, tags in, stacks, carries the roast, hatches) and a
## [HeroBot] that drives the chieftain's hero body ([method HeroBot.for_boss]). Owner: core-B.
##
## The shell gives orders ([method order]); the brain turns them into the flags a human would press on the body, on
## what it saw of the heroes `reaction` ticks ago (never cheating), with its own SimRng:
##   WAIT          stand at `pos` (or where he is), facing the nearest hero (the waiting chief on the pyre)
##   GOTO          walk / jump to `pos` and stand ([method order_done] when there)
##   RAID          P1: flank `target_slot` (-1 = the lone rule, [method lone_target]): stand behind him, strike when his
##                 body will be in the front box, high strike when he jumps over, jump on his head when he crouches
##   STACK_BOTTOM  P2: walk (never jump: the mate rides on his head) towards the target
##   STACK_TOP     P2: get onto the mate's head (jump on it) and stay there; high strike a hero in the high front box
##   CURL          curl (Down + Swap) and hold it, to be batted
##   BAT           P2: stand behind the curled mate (the mate between him and the target), face the target, strike
##                 forward when the mate's curled body is in the front box ([method order_done] after the swing)
##   CARRY         P3: run to `pos` with the roast; never strikes ([method order_done] when there)
##   HATCH         egg revive: get beside `pos` (the egg's top centre) and jump onto it; [member hatch_jumps] counts
## **Telegraph** (13.6: "every attack is announced by a HUP! pop-up and a 14-tick crouch"): before every strike, bat
## and stomp jump he crouches TELEGRAPH_TICKS ticks; on the first of them [member on_telegraph] is called with the
## attack kind (ATTACK_*) and [method telegraphing] is true; then the attack is played whatever the hero did meanwhile
## (it was announced). Combat is only what the order asks: no micro-rules of their own.

enum Order { WAIT, GOTO, RAID, STACK_BOTTOM, STACK_TOP, CURL, BAT, CARRY, HATCH }

## Attack kinds passed to on_telegraph.
const ATTACK_STRIKE: int = 0
const ATTACK_HIGH: int = 1
const ATTACK_BAT: int = 2
const ATTACK_STOMP: int = 3
## The announcing crouch (ticks).
const TELEGRAPH_TICKS: int = 14
## RAID: the flank point is this far behind the target (px); strike from at most this far.
const FLANK_PX: int = 20
## RAID: jump on a croucher this far away (px, same floor).
const STOMP_FROM_PX: int = 12
const STOMP_TO_PX: int = 56
## RAID / STACK_TOP: ticks between two attacks at least (he is a boss, not a blender).
const ATTACK_GAP_TICKS: int = 22
## BAT: stand this far behind the mate's centre.
const BAT_STAND_PX: int = 18
## HATCH: get this close beside the egg before the jump (px).
const HATCH_FROM_PX: int = 18
## GOTO / CARRY / WAIT: arrival tolerance (px).
const ARRIVE_PX: int = 6

## The order being carried out, its target hero slot (-1 = none / the lone rule) and point.
var order_kind: int = Order.WAIT
var target_slot: int = -1
var target_pos: Vector2i = BotSenses.NO_POS
## The other chieftain's body (null = none: solo, or he is out).
var mate: PlayerBase = null
## Callable(kind: int) called on the first tick of every telegraph crouch (the shell's "HUP!").
var on_telegraph: Callable = Callable()
## Statistics (tests): telegraphs per attack kind, hatch jumps, bats.
var telegraphs: PackedInt32Array = PackedInt32Array([0, 0, 0, 0])
var hatch_jumps: int = 0

var _telegraph_left: int = 0
var _telegraph_kind: int = -1
var _telegraph_dir: int = 1
var _attack_cooldown: int = 0
var _done: bool = false
var _batted: bool = false


func reset() -> void:
	super.reset()
	_telegraph_left = 0
	_telegraph_kind = -1
	_attack_cooldown = 0
	_done = false
	_batted = false


## Give an order (Order.*), with its target hero slot and point where it needs them. A new order drops the attack
## being announced or played.
func order(kind: int, p_target_slot: int = -1, pos: Vector2i = BotSenses.NO_POS) -> void:
	if kind != order_kind or p_target_slot != target_slot or pos != target_pos:
		_done = false
		_batted = false
		hatch_jumps = 0 if kind == Order.HATCH and order_kind != Order.HATCH else hatch_jumps
		cancel_actions()
		_telegraph_left = 0
	order_kind = kind
	target_slot = p_target_slot
	target_pos = pos


## True when the order is carried out (GOTO / CARRY / WAIT: standing at the point; BAT: the swing is done; HATCH: he
## jumped onto the egg and stands again).
func order_done() -> bool:
	return _done


## True while the announcing crouch runs.
func telegraphing() -> bool:
	return _telegraph_left > 0


## The hero the lone rule picks (GAMEPLAY.md 13.6 P1: the one farther from the view centre; 13.9.5): -1 when none.
func lone_target(level: LevelBase) -> int:
	var centre: Vector2i = level.get_view_rect().get_center() if level != null else Vector2i.ZERO
	var best: int = -1
	var best_distance: int = -1
	for p_slot: int in Defs.MAX_PLAYERS:
		if not bot.is_rival(p_slot) or not bot.seen_alive(p_slot):
			continue
		var pos: Vector2i = bot.seen_pos(p_slot)
		var distance: int = absi(pos.x - centre.x) + absi(pos.y - centre.y)
		if distance > best_distance:
			best_distance = distance
			best = p_slot
	return best


## The hero an order aims at: its `target_slot` while that hero is a rival in play (as seen), else the lone rule.
func victim_slot(level: LevelBase) -> int:
	if target_slot >= 0 and bot.is_rival(target_slot) and bot.seen_alive(target_slot):
		return target_slot
	return lone_target(level)


## The hero nearest to `pos` (seen); -1 when none.
func nearest_hero(pos: Vector2i) -> int:
	var best: int = -1
	var best_distance: int = 1 << 30
	for p_slot: int in Defs.MAX_PLAYERS:
		if not bot.is_rival(p_slot) or not bot.seen_alive(p_slot):
			continue
		var other: Vector2i = bot.seen_pos(p_slot)
		var distance: int = absi(other.x - pos.x) + absi(other.y - pos.y)
		if distance < best_distance:
			best_distance = distance
			best = p_slot
	return best


func think(_hero: PlayerBase, _level: LevelBase, _tick: int) -> void:
	pass


func act(hero: PlayerBase, level: LevelBase, tick: int) -> int:
	if _attack_cooldown > 0:
		_attack_cooldown -= 1
	if hero.hit_timer >= Tuning.HIT_STUN_MIN:
		cancel_actions()
		_telegraph_left = 0
		return 0
	if _telegraph_left > 0:
		_telegraph_left -= 1
		if _telegraph_left == 0:
			return _attack(hero)
		return Defs.IN_DOWN
	if in_sequence():
		var flags: int = play_sequence()
		if not in_sequence() and order_kind == Order.HATCH:
			hatch_jumps += 1
		return flags
	if action_ticks > 0:
		var held: int = hold_action()
		if action_ticks == 0 and order_kind == Order.BAT and _batted:
			_done = true
		return held
	if bot.nav.is_busy():
		return bot.nav.step(hero, tick)
	match order_kind:
		Order.GOTO, Order.CARRY:
			return _go(hero, tick, target_pos if target_pos != BotSenses.NO_POS else hero.sim_pos)
		Order.WAIT:
			return _wait(hero, tick)
		Order.RAID:
			return _raid(hero, level, tick)
		Order.STACK_BOTTOM:
			return _stack_bottom(hero, level)
		Order.STACK_TOP:
			return _stack_top(hero, tick)
		Order.CURL:
			if hero.is_curled():
				return Defs.IN_DOWN
			return Defs.IN_DOWN | Defs.IN_SWAP if hero.is_grounded() and (tick % 2) == 0 else Defs.IN_DOWN
		Order.BAT:
			return _bat(hero, level, tick)
		Order.HATCH:
			return _hatch(hero, tick)
	return 0


# --- Orders --------------------------------------------------------------------------------------------------------

func _go(hero: PlayerBase, tick: int, pos: Vector2i) -> int:
	bot.nav.set_target(pos, ARRIVE_PX)
	if bot.nav.arrived(hero) or (bot.nav.graph == null and absi(hero.sim_pos.x - pos.x) <= ARRIVE_PX):
		_done = true
		return 0
	_done = false
	return bot.nav.step(hero, tick)


func _wait(hero: PlayerBase, tick: int) -> int:
	if target_pos != BotSenses.NO_POS and absi(hero.sim_pos.x - target_pos.x) > ARRIVE_PX:
		return _go(hero, tick, target_pos)
	_done = true
	var nearest: int = nearest_hero(hero.sim_pos)
	if nearest >= 0 and hero.is_grounded() and absi(hero.xvel) == 0:
		var dx: int = bot.seen_pos(nearest).x - hero.sim_pos.x
		if dx != 0 and signi(dx) != hero.facing and (tick % 8) == 0:
			return dir_flag(dx)  # a tap turns him (1 px)
	return 0


func _raid(hero: PlayerBase, level: LevelBase, tick: int) -> int:
	var victim: int = victim_slot(level)
	if victim < 0:
		return _wait(hero, tick)
	var seen: PackedInt32Array = bot.seen(victim)
	var pos: Vector2i = Vector2i(seen[HeroBot.SEEN_X], seen[HeroBot.SEEN_Y])
	var me: Vector2i = hero.sim_pos
	var bits: int = seen[HeroBot.SEEN_BITS]
	if hero.is_grounded() and not hero.attack_gate and hero.swing_lock == 0 and _attack_cooldown == 0:
		var ahead: Vector2i = pos + Vector2i(Tuning.floor16(seen[HeroBot.SEEN_XVEL] * (TELEGRAPH_TICKS + STRIKE_LEAD_TICKS)), 0)
		var facing: int = 1 if ahead.x >= me.x else -1
		var safe: bool = (bits & HeroBot.SEEN_SAFE) != 0
		if not safe:
			if (bits & HeroBot.SEEN_GROUNDED) == 0 and pos.y < me.y - 16 and absi(pos.x - me.x) <= VersusTuning.BOT_ANTI_AIR_PX:
				return _announce(ATTACK_HIGH, facing)
			var distance: int = absi(pos.x - me.x)
			if (bits & HeroBot.SEEN_CROUCHING) != 0 and absi(pos.y - me.y) <= 8 and distance >= STOMP_FROM_PX \
					and distance <= STOMP_TO_PX and hero.no_jump == 0:
				return _announce(ATTACK_STOMP, facing)
			if front_box(me, facing, STRIKE_FORWARD).grow(4).intersects(body_box(ahead)):
				return _announce(ATTACK_STRIKE, facing)
	# Flank: the point behind him (away from where he faces), on his floor.
	var behind: int = -seen[HeroBot.SEEN_FACING] if seen[HeroBot.SEEN_FACING] != 0 else -1
	var flank: Vector2i = Vector2i(pos.x + behind * FLANK_PX, pos.y)
	if not hero.is_grounded():
		return dir_flag(flank.x - me.x)
	bot.nav.set_target(flank, 6)
	return bot.nav.step(hero, tick)


func _stack_bottom(hero: PlayerBase, level: LevelBase) -> int:
	var victim: int = victim_slot(level)
	if victim < 0:
		return 0
	# Walk only (the mate rides on his head): along his own floor towards the target.
	return BotNavigator.walk_to(hero, bot.seen_pos(victim).x, 12)


func _stack_top(hero: PlayerBase, tick: int) -> int:
	if mate == null or not is_instance_valid(mate):
		return 0
	var me: Vector2i = hero.sim_pos
	var head_y: int = mate.sim_pos.y - Tuning.HERO_BOX_STAND.y
	var on_head: bool = hero.is_riding_totem() or (hero.is_grounded() and absi(me.y - head_y) <= 2
			and absi(me.x - mate.sim_pos.x) <= 16)
	if on_head:
		_done = true
		if _attack_cooldown == 0 and not hero.attack_gate and hero.swing_lock == 0:
			for p_slot: int in Defs.MAX_PLAYERS:
				if not bot.is_rival(p_slot) or not bot.seen_alive(p_slot):
					continue
				var seen: PackedInt32Array = bot.seen(p_slot)
				if (seen[HeroBot.SEEN_BITS] & HeroBot.SEEN_SAFE) != 0:
					continue
				var pos: Vector2i = Vector2i(seen[HeroBot.SEEN_X], seen[HeroBot.SEEN_Y])
				var facing: int = 1 if pos.x >= me.x else -1
				if front_box(me, facing, STRIKE_HIGH).grow(8).intersects(body_box(pos)) \
						or front_box(me, facing, STRIKE_FORWARD).grow(8).intersects(body_box(pos)):
					return _announce(ATTACK_HIGH, facing)
		return 0
	_done = false
	if not hero.is_grounded():
		return dir_flag(mate.sim_pos.x - me.x) if absi(mate.sim_pos.x - me.x) > 3 else 0
	var dx: int = mate.sim_pos.x - me.x
	if absi(dx) <= 24 and absi(mate.sim_pos.y - me.y) <= 8 and hero.no_jump == 0:
		# Jump onto his head: up, drifting over him, then let go to fall on it.
		var drift: int = clampi(absi(dx) / 3, 1, 8)
		return start_sequence([Vector2i(Defs.IN_UP | dir_flag(dx), drift), Vector2i(Defs.IN_UP, 12 - drift),
				Vector2i(0, 6)])
	bot.nav.set_target(Vector2i(mate.sim_pos.x - signi(dx) * 20, mate.sim_pos.y), 6)
	return bot.nav.step(hero, tick)


func _bat(hero: PlayerBase, level: LevelBase, tick: int) -> int:
	if mate == null or not is_instance_valid(mate) or _batted:
		return 0
	var victim: int = victim_slot(level)
	var toward: int = 1
	if victim >= 0:
		toward = 1 if bot.seen_pos(victim).x >= mate.sim_pos.x else -1
	var me: Vector2i = hero.sim_pos
	var stand: Vector2i = Vector2i(mate.sim_pos.x - toward * BAT_STAND_PX, mate.sim_pos.y)
	var curled_box: Rect2i = Rect2i(mate.sim_pos.x - PartyTuning.CURL_BOX_XO, mate.sim_pos.y - PartyTuning.CURL_BOX_H,
			PartyTuning.CURL_BOX_W, PartyTuning.CURL_BOX_H)
	if hero.is_grounded() and mate.is_curled() and front_box(me, toward, STRIKE_FORWARD).intersects(curled_box) \
			and not hero.attack_gate and hero.swing_lock == 0:
		return _announce(ATTACK_BAT, toward)
	if not hero.is_grounded():
		return dir_flag(stand.x - me.x)
	bot.nav.set_target(stand, 3)
	var flags: int = bot.nav.step(hero, tick)
	if flags == 0 and bot.nav.arrived(hero) and hero.facing != toward:
		flags = dir_flag(toward)
	return flags


func _hatch(hero: PlayerBase, tick: int) -> int:
	if target_pos == BotSenses.NO_POS:
		return 0
	var me: Vector2i = hero.sim_pos
	if hatch_jumps > 0 and hero.is_grounded():
		_done = true
	if not hero.is_grounded():
		return dir_flag(target_pos.x - me.x) if absi(target_pos.x - me.x) > 3 else 0
	var floor_y: int = me.y
	var dx: int = target_pos.x - me.x
	if absi(dx) <= HATCH_FROM_PX + 8 and target_pos.y < me.y + 4 and target_pos.y > me.y - 48 and hero.no_jump == 0:
		var drift: int = clampi(absi(dx) / 3, 1, 10)
		return _announce_sequence([Vector2i(Defs.IN_UP | dir_flag(dx), drift), Vector2i(Defs.IN_UP, 14 - drift),
				Vector2i(0, 8)])
	bot.nav.set_target(Vector2i(target_pos.x - signi(dx) * HATCH_FROM_PX, floor_y), 6)
	return bot.nav.step(hero, tick)


# --- Telegraphed attacks ------------------------------------------------------------------------------------------

## Start the announcing crouch of an attack of `kind` in direction `facing`; returns this tick's flags (DOWN).
func _announce(kind: int, facing: int) -> int:
	_telegraph_kind = kind
	_telegraph_dir = facing
	_telegraph_left = TELEGRAPH_TICKS
	telegraphs[kind] += 1
	if on_telegraph.is_valid():
		on_telegraph.call(kind)
	_telegraph_left -= 1
	return Defs.IN_DOWN


## A hatch jump needs no announcing crouch (it is no attack): straight into the sequence.
func _announce_sequence(steps: Array[Vector2i]) -> int:
	return start_sequence(steps)


## The attack after its telegraph (the crouch's last tick has passed).
func _attack(hero: PlayerBase) -> int:
	_attack_cooldown = ATTACK_GAP_TICKS
	var dir: int = dir_flag(_telegraph_dir)
	match _telegraph_kind:
		ATTACK_HIGH:
			strikes += 1
			return start_action(dir | STRIKE_FLAGS[STRIKE_HIGH], strike_ticks(STRIKE_HIGH))
		ATTACK_STOMP:
			stomp_jumps += 1
			return start_sequence([Vector2i(Defs.IN_UP | dir, 6), Vector2i(Defs.IN_UP, 8), Vector2i(0, 8)])
		ATTACK_BAT:
			bats += 1
			strikes += 1
			_batted = true
			return start_action(dir | STRIKE_FLAGS[STRIKE_FORWARD], strike_ticks(STRIKE_FORWARD))
	strikes += 1
	if hero.facing != _telegraph_dir:
		# Turn first (the strike is aimed where it was announced).
		return start_sequence([Vector2i(dir, 1), Vector2i(dir | STRIKE_FLAGS[STRIKE_FORWARD],
				strike_ticks(STRIKE_FORWARD))])
	return start_action(dir | STRIKE_FLAGS[STRIKE_FORWARD], strike_ticks(STRIKE_FORWARD))
