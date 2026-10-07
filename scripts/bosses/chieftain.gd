class_name Chieftain
extends BossBase
## `bosses/chieftain` - the Rival Chieftains Gorm and Gulla, the final boss of Chieftains' Pyre (`w9_l3`; DESIGN.md B.6,
## GAMEPLAY.md 13.6). Owner: enemies-C (PLAN.md P2.3). Two records, each `name=<own>` and `mate=<the other's name>`;
## the one whose name sorts first (Gorm) leads: he runs the pair's phase machine and gives both their orders.
##
## **The phase machine** (one per pair, in the lead). Energy: PIPS (4) each, one pip per counted hit of any weapon (the
## body is the weak point; BOSS_HIT_COOLDOWN per chieftain). Every attack is announced by a "HUP!" and a
## TELEGRAPH_TICKS (14) crouch. A chieftain's phase is his own pips:
##  - **P1 Raiders** (4-3 pips): flank and strike, jump on a crouching hero's head; the target is the hero farther from
##    the view centre (the `lone` rule of 13.9.5; one hero: him).
##  - **P2 Totem Chief** (2 pips): co-op, both at 2 or less: they **stack** (the bottom walks at the target, the top
##    strikes high) for STACK_TICKS, then the top curls and the bottom **bats** him across the arena at a hero (a line
##    drive); the batted chief lies **dazed** DAZE_TICKS where he lands (the opening), then they swap places. Solo: the
##    chief on the pyre comes down only to bat the fighting one at the hero, then climbs back.
##  - **P3 Roast Thieves** (last pip): he fetches the Great Roast from the altar (the first floor under the middle of the
##    arena, 6 tiles up) and runs for the Roc perch at the arena edge farther from the heroes; he cannot strike while he
##    carries it; a hit makes him drop it (it goes back to the altar); at the perch it returns to the altar and he
##    regains a pip.
##  - **Egg revive**: knocked to 0 he becomes an egg where he fell; his mate runs to hatch it with a head bounce unless
##    the heroes smash it first (EGG_SMASH_HITS hits); unhatched it hatches by itself after EGG_TICKS_COOP (66) in
##    co-op, EGG_TICKS_SOLO (132) solo. Hatched he has 1 pip. Knocked to 0 with no mate left to hatch him he is out at
##    once. The fight is won when both are out; then the trophy (`drops`, default on the lead) and the bonus burst.
##  - **Co-op: "one hero smashes the egg while the other keeps the surviving chieftain away"** - an egg cracks only while
##    a hero other than the one striking it stands within HOLD_OFF_PX of the mate (or of the mate's own egg: both may be
##    eggs at once, and then neither is out until both are smashed). One hero alone can never smash an egg of the co-op
##    pair: the single-hero search of tests/test_enemies_chieftain.gd pins it.
##  - **Solo** (a party of one, or any game on a solo file): they tag in one at a time - the lead fights, the mate waits
##    on the pyre (his record's place; out of reach); when the fighter falls the waiting one tags in with half energy
##    (at most 2 pips); a hatched egg waits on the pyre with 1 pip. **Co-op** (a co-op game of two on a co-op file):
##    both fight at once.
##
## **How they move.** Two executors carry out the same orders (WAIT, GOTO, RAID, STACK_BOTTOM, STACK_TOP, CURL, BAT,
## CARRY, HATCH - the order set of core-B's ChieftainBrain):
##  - the **state machine** (the PLAN cut-list fallback, default while [member hero_bot_enabled] is false): Brute-style
##    moves on the enemy physics (walk 4 px per tick, hops, leaps), the hero's strike scripts and club boxes;
##  - **hero physics driven by HeroBot** ([member hero_bot_enabled], PLAN.md P2.3 / P2.5): each chieftain owns a body -
##    an instance of `scenes/player/player.tscn` that is NOT in the level (not one of level.heroes), slot 2 (Gorm) / 3
##    (Gulla) - fed every tick by `HeroBot.for_boss` (core-B) through its GameInput slot, with its own seeded SimRng;
##    the shell steps the body's PLAYER update itself in its ENEMIES phase and mirrors its position, boxes and pose; the
##    party moves between the two bodies (the curl, the stack, the bat) are applied by the shell (the bodies are no
##    party heroes). Their club boxes and stomps hit the heroes as a boss body (one bone, the boss knock-back); their
##    bodies are not solid; a hero landing on a chieftain bounces and harms nobody.
##
## Parameters: `name`, `mate` (the other's name), `arena` zone name, `drops` [the lead: trophy], `hp` pips [4].

enum Life { FIGHT, WAIT, EGG, OUT }
## The orders (the values of ChieftainBrain.Order).
enum Order { WAIT, GOTO, RAID, STACK_BOTTOM, STACK_TOP, CURL, BAT, CARRY, HATCH }
## What the state machine executor is doing.
enum Act { IDLE, TELEGRAPH, STRIKE, HIGH, LEAP, CURLED, BALL, DAZED }
## The pair routines of the lead.
enum Routine { RAID, STACK, BAT, DAZE }

const PLAYER_SCENE: String = "res://scenes/player/player.tscn"
const SKIN_GORM: String = "chieftain_gorm"
const SKIN_GULLA: String = "chieftain_gulla"
const SKIN_FALLBACK: String = "rival"
const TINT_GORM: Color = Color(0.5, 0.46, 0.46)
const TINT_GULLA: Color = Color(1.0, 0.72, 0.42)

## Use the hero-physics executor driven by HeroBot (PLAN.md P2.3: the state machine stays the default until the bot
## version passes its tests). Tests and the developer menu may switch it; read when a fight starts.
static var hero_bot_enabled: bool = false

# --- Private tuning (enemies-C; to move into EnemyTuning with enemies-A) -----------------------------------------------
const PIPS: int = 4                        ## [G 13.6]
const TELEGRAPH_TICKS: int = 14            ## the HUP! crouch [G 13.6]
const DAZE_TICKS: int = 30                 ## a batted chief lies dazed [G 13.6]
const EGG_TICKS_SOLO: int = 132            ## [G 13.6]
const EGG_TICKS_COOP: int = 66             ## [G 13.6]
const EGG_SMASH_HITS: int = 3              ## [G 13.6]
const EGG_HIT_GAP_TICKS: int = 8           ## least ticks between two counted egg hits
const EGG_BOX: Vector3i = Vector3i(24, 24, 12)
const HOLD_OFF_PX: int = 64                ## co-op: the partner keeps the mate busy within this distance (both axes)
const BOX: Vector3i = Tuning.HERO_BOX_STAND
const WALK_XVEL: int = 64                  ## 4 px per tick (the hero's walk is 5)
const STACK_XVEL: int = 32                 ## the bottom of a stack walks slowly
const HOP_YVEL: int = -160                 ## a hop over a step (rises 55 px)
const HIGH_LEAP_YVEL: int = -224           ## a leap to the altar (rises 105 px)
const STOMP_LEAP_YVEL: int = -128          ## a leap onto a crouching hero's head
const STOMP_BOUNCE_YVEL: int = -64
const LEAP_XVEL_MAX: int = 64
const ATTACK_GAP_TICKS: int = 22           ## least ticks between two attacks of one chieftain
const STRIKE_REACH_PX: int = 34            ## strikes when the target's feet are this close in front
const HIGH_REACH_PX: int = 40              ## the stack's top strikes high at a hero this close
const STOMP_REACH_PX: int = 56             ## jumps on a croucher this close
const BAT_STAND_PX: int = 18               ## the batter stands this far behind the curled mate
const BAT_XVEL: int = PartyTuning.BAT_LINE_DRIVE_XVEL   ## the bat is a line drive (PHYSICS.md C.11)
const BAT_YVEL: int = PartyTuning.BAT_LINE_DRIVE_YVEL
const STACK_TICKS: int = 132
const SOLO_RAID_TICKS: int = 110           ## solo P2: raids this long between two bats
const THIEF_RETRY_TICKS: int = 66          ## after dropping the roast he raids this long before the next try
const ARRIVE_PX: int = 6
const PERCH_INSET_PX: int = 24
const STACK_HEAD_PX: int = 34              ## the top stands this far above the bottom's feet (Totem Ride: K.y - 34)
const BOT_SLOT_BASE: int = 2               ## the bodies read GameInput slots 2 (lead) and 3
const BOT_SEED: int = 0x0C41EF
## Strike scripts and their front-box ticks (PHYSICS.md 8.1).
const STRIKE_TICKS: int = 7
const STRIKE_FRONT: Vector2i = Vector2i(4, 6)
const HIGH_TICKS: int = 9
const HIGH_FRONT: Vector2i = Vector2i(6, 8)

## The other chieftain (null until found or when the record has no mate).
var mate: Chieftain = null
var life: int = Life.FIGHT
var order_kind: int = Order.WAIT
var order_target: PlayerBase = null
var order_pos: Vector2i = Vector2i.ZERO
## The lead's pair state (the lead only).
var routine: int = Routine.RAID
var roast_holder: Chieftain = null
var altar: Vector2i = Vector2i.ZERO
var perch: Vector2i = Vector2i.ZERO

var _mate_name: StringName = &""
var _coop: bool = false
var _post: Vector2i = Vector2i.ZERO        ## the record's place (the pyre for the waiting chief)
var _act: int = Act.IDLE
var _act_timer: int = 0
var _attack_gap: int = 0
var _attack_after: int = Act.STRIKE        ## what the telegraph announces
var _routine_timer: int = 0
var _thief_wait: int = 0
var _egg_timer: int = 0
var _egg_hits: int = 0
var _egg_gap: int = 0
var _done: bool = false
var _hup: Label = null
var _hup_ticks: int = 0
var _roast_drawing: Node2D = null
var _arena_found: bool = false
## The lead: the Totem routine's roles are swapped (the other chief is the bottom).
var _stack_swapped: bool = false
## Hero-physics executor: the body, its bot, true while it runs.
var _body: PlayerBase = null
var _bot: HeroBot = null
var _bot_on: bool = false


func _default_skin() -> String:
	var own: String = SKIN_GULLA if _is_gulla() else SKIN_GORM
	return own if EnemySkin.find(own) != null else SKIN_FALLBACK


func _apply_params(params: Dictionary) -> void:
	max_hp = PIPS
	hp_per_pip = 1
	music = Sfx.MUSIC_BOSS_CHIEFTAINS
	boss_drops = []
	super._apply_params(params)
	_mate_name = StringName(str(params.get("mate", "")))
	_post = spawn_pos


func _ready() -> void:
	set_box(BOX)
	if _sprite != null and skin == SKIN_FALLBACK:
		_sprite.self_modulate = TINT_GULLA if _is_gulla() else TINT_GORM
	_hup = Label.new()
	_hup.text = "HUP!"
	_hup.visible = false
	_hup.position = Vector2(-20.0, -float(BOX.y + 22) * Tuning.ART_SCALE)
	_hup.add_theme_color_override(&"font_color", Color(1.0, 0.95, 0.6))
	add_child(_hup)


func _exit_tree() -> void:
	_stop_bot()


# =================================================================================================================
# Queries (tests and tools)
# =================================================================================================================

## True for the record that runs the pair (its name sorts first, or it has no mate).
func is_lead() -> bool:
	_resolve_mate()
	return mate == null or String(spawn_params.get("name", "")) < String(mate.spawn_params.get("name", ""))


func is_coop_form() -> bool:
	return _coop


## Pips left (= hit points).
func get_pips_left() -> int:
	return hp


func get_act() -> int:
	return _act


## True while the "HUP!" telegraph crouch runs.
func is_telegraphing() -> bool:
	if _bot_on and _bot != null and _bot.brain != null:
		return bool(_bot.brain.call(&"telegraphing"))
	return _act == Act.TELEGRAPH


## True while carrying the Great Roast.
func carries_roast() -> bool:
	var lead: Chieftain = _lead()
	return lead != null and lead.roast_holder == self


## The hero-physics body (null while the state machine executor runs).
func get_body() -> PlayerBase:
	return _body if _bot_on else null


## The club box this chieftain has live now (logical px; empty when none).
func get_attack_box() -> Rect2i:
	if _bot_on and _body != null:
		return _body.club_box if _body.club_box_active else Rect2i()
	if _act == Act.STRIKE and _act_timer >= STRIKE_FRONT.x and _act_timer <= STRIKE_FRONT.y:
		return _club_rect(Tuning.ClubFrame.FWD_FRONT)
	if _act == Act.HIGH and _act_timer >= HIGH_FRONT.x and _act_timer <= HIGH_FRONT.y:
		return _club_rect(Tuning.ClubFrame.HIGH_FRONT)
	return Rect2i()


## The weak point: the body (the egg's box while an egg); empty while waiting on the pyre or out.
func get_weak_rect() -> Rect2i:
	if life == Life.FIGHT:
		return get_box()
	if life == Life.EGG:
		return Rect2i(sim_pos.x - EGG_BOX.z, sim_pos.y - EGG_BOX.y, EGG_BOX.x, EGG_BOX.y)
	return Rect2i()


# =================================================================================================================
# Fight start, reset, defeat
# =================================================================================================================

func start_fight() -> void:
	if fighting or dead:
		return
	_resolve_mate()
	_coop = _coop_form_wanted()
	hp = max_hp
	_find_arena()
	if is_lead():
		life = Life.FIGHT
		routine = Routine.RAID
		roast_holder = null
	else:
		life = Life.FIGHT if _coop else Life.WAIT
	if hero_bot_enabled:
		_start_bot()
	super.start_fight()
	_show_roast()


func _on_reset() -> void:
	_stop_bot()
	life = Life.FIGHT
	order_kind = Order.WAIT
	order_target = null
	routine = Routine.RAID
	roast_holder = null
	_act = Act.IDLE
	_act_timer = 0
	_attack_gap = 0
	_routine_timer = 0
	_thief_wait = 0
	_egg_timer = 0
	_egg_hits = 0
	_done = false
	_coop = false
	visible = true
	set_box(BOX)
	_show_hup(false)
	_show_roast()


func _on_lethal_hit() -> void:
	_knocked_out()


func _on_defeated() -> void:
	visible = false
	_stop_bot()
	_show_roast()


## The trophy and the bonus burst come out where the lead stands (or where the roast's altar is).
func _burst_origin() -> Vector2i:
	return (altar if _arena_found else sim_pos) + Vector2i(0, EnemyTuning.BOSS_DROP_DY)


# =================================================================================================================
# The tick
# =================================================================================================================

func _ai_tick() -> void:
	if dead:
		return
	_resolve_mate()
	var hero: PlayerBase = _target_hero()
	if not fighting:
		_play(&"idle")
		_physics_idle()
		if _wakes_for_any(hero):
			start_fight()
		if not fighting:
			return
	if hit_cooldown > 0:
		hit_cooldown -= 1
	if _attack_gap > 0:
		_attack_gap -= 1
	if _hup_ticks > 0:
		_hup_ticks -= 1
		if _hup_ticks == 0:
			_show_hup(false)
	if is_lead():
		_pair_tick()
	match life:
		Life.OUT:
			visible = false
			return
		Life.EGG:
			_egg_tick()
			return
		Life.WAIT:
			_execute()
			return
	_poll_hits()
	if dead or life != Life.FIGHT:
		return
	_execute()
	_attack_heroes()
	_heroes_bounce()
	_show_roast()


# --- The pair's phase machine (the lead) -------------------------------------------------------------------------------

func _pair_tick() -> void:
	var a: Chieftain = self
	var b: Chieftain = mate
	_routine_timer += 1
	if a == null and b == null:
		return
	if not _coop:
		_solo_orders()
	else:
		_coop_orders()


## Solo: the fighter by his pips; the waiting chief stays on the pyre, or comes down to bat the fighter (P2).
func _solo_orders() -> void:
	var fighter: Chieftain = null
	var waiter: Chieftain = null
	for chief: Chieftain in [self, mate]:
		if chief == null:
			continue
		if chief.life == Life.FIGHT:
			fighter = chief
		elif chief.life == Life.WAIT:
			waiter = chief
	if waiter != null and not (routine == Routine.BAT and fighter != null):
		waiter.give_order(Order.WAIT, null, waiter._post)
	if fighter == null:
		return
	var target: PlayerBase = _pick_target()
	if fighter.hp <= 1 and _thief_tick(fighter, target):
		return
	if fighter.hp == 2 and waiter != null:
		match routine:
			Routine.RAID:
				fighter.give_order(Order.RAID, target, Vector2i.ZERO)
				if _routine_timer >= SOLO_RAID_TICKS and fighter.is_grounded_now():
					_set_routine(Routine.BAT)
			Routine.BAT:
				fighter.give_order(Order.CURL, null, fighter.sim_pos)
				waiter.give_order(Order.BAT, target, fighter.sim_pos)
				if fighter._act == Act.BALL or fighter._act == Act.DAZED or _routine_timer > 300:
					_set_routine(Routine.DAZE)
			Routine.DAZE:
				if fighter._act != Act.BALL and fighter._act != Act.DAZED:
					_set_routine(Routine.RAID)
		return
	if routine != Routine.RAID:
		_set_routine(Routine.RAID)
	fighter.give_order(Order.RAID, target, Vector2i.ZERO)


## Co-op: both fight; the Totem routine while both are at 2 pips or less; the thief with his last pip.
func _coop_orders() -> void:
	var fighters: Array[Chieftain] = []
	for chief: Chieftain in [self, mate]:
		if chief == null or chief.life != Life.FIGHT:
			continue
		if chief.mate != null and chief.mate.life == Life.EGG:
			# Egg revive: he runs to hatch his mate's egg (the heroes must smash it first).
			chief.give_order(Order.HATCH, null, chief.mate.sim_pos)
			continue
		fighters.append(chief)
	var both_low: bool = fighters.size() == 2 and fighters[0].hp <= 2 and fighters[1].hp <= 2
	if both_low and _totem_tick(fighters):
		return
	if routine != Routine.RAID and not both_low:
		_set_routine(Routine.RAID)
	for chief: Chieftain in fighters:
		var target: PlayerBase = _pick_target()
		if chief.hp <= 1 and _thief_tick(chief, target):
			continue
		chief.give_order(Order.RAID, target, Vector2i.ZERO)


## The Totem routine of the pair (co-op, both low): stack - curl and bat - the batted lies dazed - swap. True when it
## gave the orders.
func _totem_tick(fighters: Array[Chieftain]) -> bool:
	var bottom: Chieftain = fighters[1] if _stack_swapped else fighters[0]
	var top: Chieftain = fighters[0] if _stack_swapped else fighters[1]
	if roast_holder != null:
		return false
	var target: PlayerBase = _pick_target()
	match routine:
		Routine.RAID:
			_set_routine(Routine.STACK)
			return _totem_tick(fighters)
		Routine.STACK:
			bottom.give_order(Order.STACK_BOTTOM, target, Vector2i.ZERO)
			top.give_order(Order.STACK_TOP, target, Vector2i.ZERO)
			if _routine_timer >= STACK_TICKS:
				_set_routine(Routine.BAT)
		Routine.BAT:
			top.give_order(Order.CURL, null, top.sim_pos)
			bottom.give_order(Order.BAT, target, top.sim_pos)
			if top._act == Act.BALL or top._act == Act.DAZED or _routine_timer > 300:
				_set_routine(Routine.DAZE)
		Routine.DAZE:
			if top._act != Act.BALL and top._act != Act.DAZED:
				# Swap places: the batted chief is the bottom of the next stack.
				_stack_swapped = not _stack_swapped
				_set_routine(Routine.STACK)
	return true


## The roast run of a chief with his last pip: fetch it from the altar, carry it to the perch. True when it gave him an
## order (false: someone else carries it or he waits after a drop).
func _thief_tick(chief: Chieftain, _target: PlayerBase) -> bool:
	if _thief_wait > 0:
		_thief_wait -= 1
		return false
	if roast_holder != null and roast_holder != chief:
		return false
	if roast_holder == null:
		chief.give_order(Order.GOTO, null, altar)
		if absi(chief.sim_pos.x - altar.x) <= ARRIVE_PX * 2 and absi(chief.sim_pos.y - altar.y) <= 4 \
				and chief.is_grounded_now():
			roast_holder = chief
			perch = _perch_point()
			Audio.play_sfx(Sfx.PICKUP_BIG)
		return true
	chief.give_order(Order.CARRY, null, perch)
	if absi(chief.sim_pos.x - perch.x) <= ARRIVE_PX and chief.is_grounded_now():
		# At the perch: the roast goes back to the altar and he regains a pip.
		roast_holder = null
		chief.hp = mini(chief.hp + 1, chief.max_hp)
		Events.boss_energy_changed.emit(chief, chief.get_pips(), chief.get_max_pips())
		_thief_wait = THIEF_RETRY_TICKS
	return true


func _set_routine(value: int) -> void:
	routine = value
	_routine_timer = 0


## The P1 target: the hero farther from the view centre (the lone rule; ties -> the higher slot); one hero: him.
func _pick_target() -> PlayerBase:
	var level: LevelBase = Game.level
	if level == null:
		return null
	var centre: Vector2i = level.get_view_rect().get_center()
	var best: PlayerBase = null
	var best_d: int = -1
	for hero: PlayerBase in level.contact_order():
		if not hero.is_party_targetable():
			continue
		var d: int = absi(hero.sim_pos.x - centre.x) + absi(hero.sim_pos.y - centre.y)
		if d >= best_d:
			best = hero
			best_d = d
	return best


## The perch: the arena's floor edge farther from the heroes.
func _perch_point() -> Vector2i:
	var room: Rect2i = _room()
	var floor_y: int = maxi(_post.y, mate._post.y if mate != null else _post.y)
	var heroes_x: int = 0
	var count: int = 0
	var level: LevelBase = Game.level
	for hero: PlayerBase in level.contact_order():
		if hero.is_party_targetable():
			heroes_x += hero.sim_pos.x
			count += 1
	var mid: int = room.get_center().x
	var heroes_mid: int = heroes_x / count if count > 0 else mid
	var x: int = room.position.x + PERCH_INSET_PX if heroes_mid >= mid else room.end.x - PERCH_INSET_PX
	return Vector2i(x, _floor_under(x, floor_y - Tuning.TILE * 2))


# --- Orders ---------------------------------------------------------------------------------------------------------

## The lead's order for this chieftain (a new order restarts its executor's bookkeeping).
func give_order(kind: int, target: PlayerBase, pos: Vector2i) -> void:
	if kind != order_kind:
		_done = false
		if _act == Act.TELEGRAPH or _act == Act.STRIKE or _act == Act.HIGH:
			_set_act(Act.IDLE)
	order_kind = kind
	order_target = target
	order_pos = pos


func is_grounded_now() -> bool:
	if _bot_on and _body != null:
		return _body.is_grounded()
	return _grounded


## Carry out the order of this tick (the state machine or the hero-physics executor).
func _execute() -> void:
	if _bot_on and _body != null:
		_bot_execute()
	else:
		_fsm_execute()


# =================================================================================================================
# The state machine executor (PLAN cut 8: the fallback)
# =================================================================================================================

func _fsm_execute() -> void:
	_act_timer += 1
	match _act:
		Act.TELEGRAPH:
			xvel = 0
			_physics()
			_play(&"crouch")
			if _act_timer >= TELEGRAPH_TICKS:
				_begin_attack()
			return
		Act.STRIKE:
			xvel = 0
			_physics()
			_play(&"attack")
			_try_bat()
			if _act_timer >= STRIKE_TICKS:
				_end_attack()
			return
		Act.HIGH:
			_ride_or_physics()
			_play(&"attack")
			if _act_timer >= HIGH_TICKS:
				_end_attack()
			return
		Act.LEAP:
			_physics()
			_play(&"air")
			if _grounded and _act_timer > 2:
				_set_act(Act.IDLE)
			return
		Act.BALL:
			_physics()
			_play(&"roll")
			if _grounded and _act_timer > 2:
				_set_act(Act.DAZED)
			return
		Act.DAZED:
			xvel = 0
			_physics()
			_play(&"hurt")
			if _act_timer >= DAZE_TICKS:
				_set_act(Act.IDLE)
			return
		Act.CURLED:
			if order_kind != Order.CURL:
				_set_act(Act.IDLE)
			else:
				xvel = 0
				_physics()
				_play(&"roll")
				return
	match order_kind:
		Order.WAIT:
			_walk_to(order_pos, WALK_XVEL)
			_face_nearest()
			_play_move()
		Order.GOTO, Order.CARRY:
			_done = _walk_to(order_pos, WALK_XVEL)
			_play_move()
		Order.RAID:
			_raid()
		Order.STACK_BOTTOM:
			var target: PlayerBase = order_target
			var goal: Vector2i = target.sim_pos if target != null else sim_pos
			_walk_to(Vector2i(goal.x, sim_pos.y), STACK_XVEL, false)
			_play_move()
		Order.STACK_TOP:
			_stack_top()
		Order.CURL:
			if _grounded:
				_set_act(Act.CURLED)
				Audio.play_sfx(Sfx.CURL)
			_physics()
			_play(&"roll")
		Order.BAT:
			_bat()
		Order.HATCH:
			_hatch()


func _raid() -> void:
	var target: PlayerBase = order_target
	if target == null:
		_physics()
		_play(&"idle")
		return
	var dx: int = target.sim_pos.x - sim_pos.x
	var dy: int = target.sim_pos.y - sim_pos.y
	var ahead: int = dx * facing
	if _grounded and _attack_gap == 0:
		if target.is_low() and absi(dx) <= STOMP_REACH_PX and absi(dy) <= Tuning.TILE:
			facing = signi(dx) if dx != 0 else facing
			_announce(Act.LEAP)
			return
		if ahead >= 0 and ahead <= STRIKE_REACH_PX and absi(dy) <= Tuning.TILE:
			_announce(Act.STRIKE)
			return
	# Flank: stand just in front of him, on his side.
	var side: int = -1 if dx > 0 else 1
	var goal: Vector2i = Vector2i(target.sim_pos.x + side * (STRIKE_REACH_PX - 8), target.sim_pos.y)
	_walk_to(goal, WALK_XVEL)
	if absi(dx) > 2:
		facing = signi(dx)
	_play_move()


func _stack_top() -> void:
	if mate == null or mate.life != Life.FIGHT:
		_physics()
		return
	var head: Vector2i = Vector2i(mate.sim_pos.x, mate.sim_pos.y - STACK_HEAD_PX)
	var riding: bool = absi(sim_pos.x - head.x) <= 2 and absi(sim_pos.y - head.y) <= 2
	if not riding:
		# Hop onto the mate's head (straight to it: a leap of the state machine).
		if _grounded and absi(sim_pos.x - mate.sim_pos.x) <= Tuning.TILE * 2:
			teleport(head)
			_grounded = true
			yvel = 0
		else:
			_walk_to(mate.sim_pos, WALK_XVEL)
			_play_move()
			return
	_ride_or_physics()
	var target: PlayerBase = order_target
	if target != null:
		facing = 1 if target.sim_pos.x >= sim_pos.x else -1
		if _attack_gap == 0 and absi(target.sim_pos.x - sim_pos.x) <= HIGH_REACH_PX:
			_announce(Act.HIGH)
			return
	_play(&"idle")


## The top of a stack stands on the mate's head (the Totem rule: feet 34 px above the bottom's).
func _ride_or_physics() -> void:
	if order_kind == Order.STACK_TOP and mate != null and mate.life == Life.FIGHT \
			and absi(sim_pos.x - mate.sim_pos.x) <= Tuning.TILE:
		sim_pos = Vector2i(mate.sim_pos.x, mate.sim_pos.y - STACK_HEAD_PX)
		xvel = 0
		yvel = 0
		_grounded = true
	else:
		_physics()


func _bat() -> void:
	if mate == null or mate.life != Life.FIGHT:
		_physics()
		return
	var target: PlayerBase = order_target
	var toward: int = 1
	if target != null:
		toward = 1 if target.sim_pos.x >= mate.sim_pos.x else -1
	var stand: Vector2i = Vector2i(mate.sim_pos.x - toward * BAT_STAND_PX, mate.sim_pos.y)
	if mate._act != Act.CURLED:
		_walk_to(stand, WALK_XVEL)
		_play_move()
		return
	if not _walk_to(stand, WALK_XVEL):
		_play_move()
		return
	facing = toward
	if _grounded and _attack_gap == 0:
		_announce(Act.STRIKE)
		return
	_play(&"idle")


## The batter's front box on the curled mate launches him as a line drive (PHYSICS.md C.11): he flies with gravity and
## hurts whoever he meets, and lies dazed where he lands.
func _try_bat() -> void:
	if order_kind != Order.BAT or mate == null or mate._act != Act.CURLED:
		return
	var box: Rect2i = get_attack_box()
	if box.size.x <= 0 or not Overlap.rects(box, mate.get_box()):
		return
	mate.xvel = facing * BAT_XVEL
	mate.yvel = BAT_YVEL
	mate._grounded = false
	mate._set_act(Act.BALL)
	mate.facing = facing
	Audio.play_sfx(Sfx.BAT_HIT)
	_done = true


func _hatch() -> void:
	var egg: Vector2i = order_pos
	if absi(sim_pos.x - egg.x) <= Tuning.TILE and _grounded:
		# Hop onto the egg: the next landing on its top hatches it (the lead's egg tick tests the head bounce).
		yvel = HOP_YVEL
		xvel = signi(egg.x - sim_pos.x) * 16
		_grounded = false
		_set_act(Act.LEAP)
		return
	_walk_to(Vector2i(egg.x, sim_pos.y), WALK_XVEL)
	_play_move()


## Announce an attack: the "HUP!" pop-up and the 14-tick crouch, then `act` (STRIKE, HIGH or LEAP).
func _announce(act: int) -> void:
	_attack_after = act
	_set_act(Act.TELEGRAPH)
	xvel = 0
	_show_hup(true)


func _begin_attack() -> void:
	_attack_gap = ATTACK_GAP_TICKS
	match _attack_after:
		Act.LEAP:
			var target: PlayerBase = order_target
			var dx: int = (target.sim_pos.x - sim_pos.x) if target != null else 0
			xvel = clampi(dx * 16 / 10, -LEAP_XVEL_MAX, LEAP_XVEL_MAX)
			yvel = STOMP_LEAP_YVEL
			_grounded = false
			_set_act(Act.LEAP)
		Act.HIGH:
			_set_act(Act.HIGH)
		_:
			_set_act(Act.STRIKE)


func _end_attack() -> void:
	_set_act(Act.IDLE)
	if order_kind == Order.BAT:
		_done = true


func _set_act(act: int) -> void:
	_act = act
	_act_timer = 0


## Walk toward `goal` (x; hop when a wall or a ledge up to 3 rows high is in the way, leap up to the altar when it is
## right above). True when standing there.
func _walk_to(goal: Vector2i, speed: int, may_jump: bool = true) -> bool:
	var dx: int = goal.x - sim_pos.x
	if absi(dx) <= ARRIVE_PX and absi(goal.y - sim_pos.y) <= 4:
		xvel = 0
		_physics()
		return _grounded
	xvel = signi(dx) * speed if absi(dx) > 2 else 0
	if xvel != 0:
		facing = signi(xvel)
	if may_jump and _grounded:
		var up: int = sim_pos.y - goal.y
		var grid: TileGrid = Game.level.grid if Game.level != null else null
		var blocked: bool = grid != null and xvel != 0 and _blocked_ahead(grid, signi(xvel))
		if up > Tuning.TILE and absi(dx) <= Tuning.TILE * 4:
			yvel = HIGH_LEAP_YVEL if up > 55 else HOP_YVEL
			xvel = clampi(dx * 16 / 14, -LEAP_XVEL_MAX, LEAP_XVEL_MAX)
			_grounded = false
		elif blocked:
			yvel = HOP_YVEL
			_grounded = false
	_physics()
	return false


## The enemy physics of the arena (gravity, floors, walls), inside the arena room.
func _physics() -> void:
	var keep: int = xvel
	_ground_step(false, false)
	if signi(xvel) != signi(keep) and keep != 0:
		# _ground_step turns an enemy round at a wall; a chieftain just stops.
		xvel = 0
		facing = signi(keep)
	var room: Rect2i = _room()
	sim_pos.x = clampi(sim_pos.x, room.position.x + (BOX.x >> 1), room.end.x - (BOX.x >> 1))


func _physics_idle() -> void:
	xvel = 0
	_physics()


func _play_move() -> void:
	if not _grounded:
		_play(&"air")
	elif xvel != 0:
		_play(&"walk")
	else:
		_play(&"idle")


func _face_nearest() -> void:
	var hero: PlayerBase = _target_hero()
	if hero != null and hero.sim_pos.x != sim_pos.x:
		facing = 1 if hero.sim_pos.x > sim_pos.x else -1


## A club box of the hero's tables (PHYSICS.md 8.2) at this feet point and facing.
func _club_rect(frame: int) -> Rect2i:
	var rect: Rect2i = Tuning.CLUB_BOX[frame]
	var origin: Vector2i = Tuning.CLUB_ORIGIN[frame]
	var xo: int = origin.x - rect.position.x
	var ox: int = sim_pos.x + facing * origin.x
	return Rect2i(ox - xo, sim_pos.y + rect.position.y, rect.size.x, rect.size.y)


# =================================================================================================================
# The hero-physics executor (HeroBot, core-B's boss interface)
# =================================================================================================================

func _start_bot() -> void:
	if _bot_on or not ResourceLoader.exists(PLAYER_SCENE):
		return
	var key: int = BOT_SLOT_BASE + (0 if is_lead() else 1)
	_body = (load(PLAYER_SCENE) as PackedScene).instantiate() as PlayerBase
	if _body == null:
		return
	_body.spawn_setup(sim_pos, {"slot": key})
	_body.facing = facing
	_body.grounded = true
	_body.run.reset_energy()
	var level_id: int = 1 if Game.difficulty == Defs.Difficulty.BEGINNER else 2
	_bot = HeroBot.for_boss(_body, BOT_SEED + key, Defs.BotLevel.HUNTER if level_id == 1 else Defs.BotLevel.CHIEF,
			key)
	_bot.install()
	if _bot.brain != null and _bot.brain.get(&"on_telegraph") != null:
		_bot.brain.set(&"on_telegraph", func(_kind: int) -> void: _show_hup(true))
	_bot_on = true


func _stop_bot() -> void:
	if _bot != null:
		_bot.uninstall()
	_bot = null
	if _body != null and is_instance_valid(_body):
		_body.free()
	_body = null
	_bot_on = false


## One tick on hero physics: the orders go to the brain, the body runs its own PLAYER update with the flags the bot put
## into its GameInput slot, then the shell applies what the bodies cannot do with each other (the curl, the stack,
## the bat) and mirrors the body.
func _bot_execute() -> void:
	var brain: Object = _bot.brain
	if mate != null and mate._bot_on:
		brain.set(&"mate", mate._body)
	var slot: int = order_target.slot if order_target != null else -1
	var pos: Vector2i = order_pos if order_kind in [Order.WAIT, Order.GOTO, Order.CARRY, Order.HATCH] \
			else BotSenses.NO_POS
	brain.call(&"order", order_kind, slot, pos)
	var body: PlayerBase = _body
	if _act == Act.DAZED:
		body.set_control_enabled(false)
		_act_timer += 1
		if _act_timer >= DAZE_TICKS:
			_set_act(Act.IDLE)
			body.set_control_enabled(true)
	body.sim_prev = body.sim_pos
	body._sim_tick(Defs.Phase.PLAYER)
	body._sim_tick(Defs.Phase.POST)
	# The curl (the body is no party hero: Down + Swap does nothing for it).
	if order_kind == Order.CURL and body.is_grounded() and body.curl == PlayerBase.CURL_NONE:
		body.curl = PlayerBase.CURL_CURLED
		Audio.play_sfx(Sfx.CURL)
	elif order_kind != Order.CURL and body.curl == PlayerBase.CURL_CURLED:
		body.curl = PlayerBase.CURL_NONE
	# The ball lands: dazed where it lands.
	if body.curl == PlayerBase.CURL_BALL:
		if _act != Act.BALL:
			_set_act(Act.BALL)
		elif body.grounded and _act_timer > 2:
			body.curl = PlayerBase.CURL_NONE
			_set_act(Act.DAZED)
		_act_timer += 1
	# The stack: on the mate's head (the Totem Ride rule: feet 34 px above his).
	if order_kind == Order.STACK_TOP and mate != null and mate._bot_on and mate._body != null:
		var other: PlayerBase = mate._body
		if absi(body.sim_pos.x - other.sim_pos.x) <= Tuning.TILE and body.yvel >= 0 \
				and absi(body.sim_pos.y - (other.sim_pos.y - STACK_HEAD_PX)) <= 8:
			body.sim_pos = Vector2i(other.sim_pos.x, other.sim_pos.y - STACK_HEAD_PX)
			body.yvel = 0
			body.on_platform = true
	# The bat: this body's front club box on the curled mate launches him as a line drive.
	if mate != null and mate._bot_on and mate._body != null and body.club_box_active \
			and mate._body.curl == PlayerBase.CURL_CURLED and Overlap.rects(body.club_box, mate._body.get_box()):
		mate._body.bat(body.facing * BAT_XVEL, BAT_YVEL, body)
		Audio.play_sfx(Sfx.BAT_HIT)
	teleport(body.sim_pos)
	facing = body.facing
	_grounded = body.is_grounded()
	set_box(Vector3i(body.box_w, body.box_h, body.box_xo))
	_play(_body_role(body))


func _body_role(body: PlayerBase) -> StringName:
	if body.curl != PlayerBase.CURL_NONE:
		return &"roll"
	if _act == Act.DAZED or body.hit_timer > 0:
		return &"hurt"
	if body.attack_gate:
		return &"attack"
	if body.is_crouching():
		return &"crouch"
	if not body.is_grounded():
		return &"air"
	return &"walk" if body.xvel != 0 else &"idle"


# =================================================================================================================
# Hits, contacts, eggs
# =================================================================================================================

## Weapons against the body (BossBase.poll_weapon_hit's order, the cooldown per chieftain): one pip per hit. A hit on
## the thief makes him drop the roast.
func _poll_hits() -> void:
	var weak: Rect2i = get_weak_rect()
	var level: LevelBase = Game.level
	if weak.size.x <= 0 or level == null:
		return
	var slot: int = -1
	var projectiles: Array[SimEntity] = level.get_kind(Defs.Kind.HERO_PROJECTILE)
	for i: int in range(projectiles.size() - 1, -1, -1):
		var projectile: ProjectileBase = projectiles[i] as ProjectileBase
		if projectile != null and not projectile.spent and Overlap.rects(projectile.get_box(), weak):
			projectile.consume()
			if hit_cooldown > 0:
				return
			slot = projectile.owner_slot
			break
	if slot < 0:
		if hit_cooldown > 0:
			return
		for hero: PlayerBase in level.contact_order():
			if hero.club_box_active and Overlap.rects(hero.club_box, weak):
				hero.notify_weapon_hit()
				slot = hero.slot
				level.spawn_fx(&"fx/hit_stars", hero.club_box.intersection(weak).get_center())
				break
	if slot < 0:
		return
	_note_hitter(level, slot)
	if carries_roast():
		_lead().roast_holder = null
		_lead()._thief_wait = THIEF_RETRY_TICKS
	if _act == Act.TELEGRAPH or _act == Act.STRIKE or _act == Act.HIGH:
		_set_act(Act.IDLE)
		_show_hup(false)
	apply_boss_hit(1)


## The club box (and the stomp of a falling chieftain) against the heroes: one bone and the boss knock-back. A batted
## ball hurts whoever it meets.
func _attack_heroes() -> void:
	var level: LevelBase = Game.level
	if level == null:
		return
	var box: Rect2i = get_attack_box()
	var falling: bool = (yvel > 0 and _act == Act.LEAP) or _act == Act.BALL
	if _bot_on and _body != null:
		falling = _body.yvel > 0 and not _body.is_grounded()
	for hero: PlayerBase in level.contact_order():
		if hero.dead or hero.is_down() or hero.is_immune() or hero.is_feasting():
			continue
		if box.size.x > 0 and Overlap.rects(box, hero.get_box()):
			touch_hero(hero)
			continue
		if falling and Overlap.body(self, hero, self) and (Overlap.stomp or _act == Act.BALL):
			touch_hero(hero)
			if _act == Act.LEAP:
				yvel = STOMP_BOUNCE_YVEL


## A hero landing on a chieftain bounces (the head-bounce rule: nobody is harmed); the egg tick tests the mate's hatch.
func _heroes_bounce() -> void:
	var level: LevelBase = Game.level
	if level == null:
		return
	for hero: PlayerBase in level.contact_order():
		if hero.dead or hero.is_down() or hero.yvel < 0:
			continue
		if Overlap.body(hero, self, hero) and Overlap.stomp:
			var held: bool = (hero.input_flags & Defs.IN_UP) != 0
			hero.bounce(Tuning.BOSS_BOUNCE_YVEL_UP if held else Tuning.BOSS_BOUNCE_YVEL, Overlap.depth)
			Events.player_bounced.emit(self, 0)
			Events.hero_bounced.emit(hero, self, 0)


## Knocked to 0: an egg where he fell, or out at once when no mate is left to hatch him. Solo: the waiting chief tags
## in with half energy.
func _knocked_out() -> void:
	_show_hup(false)
	_set_act(Act.IDLE)
	if carries_roast():
		_lead().roast_holder = null
	var mate_in_play: bool = mate != null and (mate.life == Life.FIGHT or mate.life == Life.WAIT)
	if _coop and mate != null and mate.life == Life.EGG:
		# Co-op: both may be eggs at once; each still waits for its own smash (with the other's egg held off).
		mate_in_play = true
	if not mate_in_play:
		_go_out()
		return
	life = Life.EGG
	_egg_timer = 0
	_egg_hits = 0
	_egg_gap = 0
	if _bot_on and _body != null:
		_body.set_control_enabled(false)
	set_box(EGG_BOX)
	Audio.play_sfx(Sfx.EGG_DOWN)
	if not _coop and mate.life == Life.WAIT:
		mate.life = Life.FIGHT
		mate.hp = mini(mate.hp, PIPS / 2)
		Events.boss_energy_changed.emit(mate, mate.get_pips(), mate.get_max_pips())
		_lead()._set_routine(Routine.RAID)


func _egg_tick() -> void:
	_play(&"roll")
	xvel = 0
	_physics()
	_egg_timer += 1
	if _egg_gap > 0:
		_egg_gap -= 1
	if _egg_smashed():
		_egg_hits += 1
		_egg_gap = EGG_HIT_GAP_TICKS
		flash = EnemyTuning.FLASH_TICKS
		Audio.play_sfx(Sfx.BOSS_HIT)
		if _egg_hits >= EGG_SMASH_HITS:
			_go_out()
			return
	if _mate_hatches() or _egg_timer >= (EGG_TICKS_COOP if _coop else EGG_TICKS_SOLO):
		_hatch_egg()


## A hero's weapon on the egg (any box or throw, one count per EGG_HIT_GAP_TICKS). Co-op: it counts only while another
## hero holds the mate off ([method _held_off]); else it glances.
func _egg_smashed() -> bool:
	var level: LevelBase = Game.level
	if level == null or _egg_gap > 0:
		return false
	var egg: Rect2i = get_weak_rect()
	var smasher: int = -1
	for entity: SimEntity in level.get_kind(Defs.Kind.HERO_PROJECTILE):
		var projectile: ProjectileBase = entity as ProjectileBase
		if projectile != null and not projectile.spent and Overlap.rects(projectile.get_box(), egg):
			projectile.consume()
			smasher = projectile.owner_slot
			break
	if smasher < 0:
		for hero: PlayerBase in level.contact_order():
			if hero.club_box_active and Overlap.rects(hero.club_box, egg):
				hero.notify_weapon_hit()
				smasher = hero.slot
				break
	if smasher < 0:
		return false
	if _coop and not _held_off(smasher):
		_egg_gap = EGG_HIT_GAP_TICKS
		Audio.play_sfx(Sfx.CLUB_HIT_SCENERY)
		level.spawn_fx(&"fx/hit_stars", egg.get_center())
		return false
	return true


## Co-op: true when a hatched hero other than the one in `smasher_slot` stands within HOLD_OFF_PX of the mate (or of
## the mate's egg) on both axes - or there is no mate left.
func _held_off(smasher_slot: int) -> bool:
	if mate == null or mate.life == Life.OUT:
		return true
	var level: LevelBase = Game.level
	for hero: PlayerBase in level.contact_order():
		if hero.slot == smasher_slot or not hero.is_party_targetable():
			continue
		if absi(hero.sim_pos.x - mate.sim_pos.x) <= HOLD_OFF_PX and absi(hero.sim_pos.y - mate.sim_pos.y) <= HOLD_OFF_PX:
			return true
	return false


## The mate lands on the egg (a head bounce): it hatches.
func _mate_hatches() -> bool:
	if mate == null or mate.life != Life.FIGHT or not _coop:
		return false
	var feet: Vector2i = mate.sim_pos
	var falling: bool = mate.yvel > 0 or (mate._bot_on and mate._body != null and mate._body.yvel > 0)
	var egg: Rect2i = get_weak_rect()
	return falling and feet.x >= egg.position.x - 4 and feet.x < egg.end.x + 4 \
			and feet.y >= egg.position.y and feet.y <= egg.position.y + (egg.size.y >> 1) + 4


func _hatch_egg() -> void:
	hp = 1
	set_box(BOX)
	Audio.play_sfx(Sfx.EGG_HATCH)
	Events.boss_energy_changed.emit(self, get_pips(), get_max_pips())
	if _bot_on and _body != null:
		_body.set_control_enabled(true)
	if _coop:
		life = Life.FIGHT
		if mate != null and mate.order_kind == Order.HATCH:
			mate.give_order(Order.RAID, _pick_target(), Vector2i.ZERO)
	else:
		life = Life.WAIT
		teleport(_post)


## Out of the fight (the egg smashed, or knocked out with no mate left): when both are out the fight is won.
func _go_out() -> void:
	life = Life.OUT
	visible = false
	hp = 0
	_spawn_optional(&"fx/poof", sim_pos + Vector2i(0, -12))
	Events.boss_energy_changed.emit(self, 0, get_max_pips())
	if mate == null or mate.life == Life.OUT:
		_win()


## Both are out: they hand back the Great Roast - the trophy (the records' `drops`, by default on the lead) and the
## bonus burst once, the boss music and the arena lock released, boss_defeated for each.
func _win() -> void:
	var lead: Chieftain = _lead()
	var other: Chieftain = lead.mate if lead != null else null
	if lead == null:
		return
	var drops: Array[StringName] = lead.boss_drops.duplicate()
	if other != null:
		drops.append_array(other.boss_drops)
	if drops.is_empty():
		drops = [&"trophy"]
	if other != null and not other.dead:
		other._defeat_quietly()
	lead.roast_holder = null
	lead.defeat(drops)


## Defeated without the burst and the drops (the mate of the lead: the pair hands back one roast).
func _defeat_quietly() -> void:
	if dead:
		return
	dead = true
	fighting = false
	sleep()
	_stop_bot()
	Audio.pop_music()
	Events.boss_energy_changed.emit(self, 0, get_max_pips())
	Events.boss_defeated.emit(self)
	died.emit(self, &"weapon")
	_on_defeated()


# =================================================================================================================
# Internals
# =================================================================================================================

func _resolve_mate() -> void:
	if mate != null and is_instance_valid(mate):
		return
	mate = null
	if _mate_name == &"" or Game.level == null:
		return
	mate = Game.level.find_named(_mate_name) as Chieftain


func _lead() -> Chieftain:
	return self if is_lead() else mate


func _is_gulla() -> bool:
	var own: String = String(spawn_params.get("name", "")).to_lower()
	if own.contains("gulla"):
		return true
	if own.contains("gorm"):
		return false
	return String(spawn_params.get("name", "")) > String(spawn_params.get("mate", ""))


## The co-op form in a co-op game of two or more heroes on a co-op file.
static func _coop_form_wanted() -> bool:
	var level: LevelBase = Game.level
	return level != null and Game.mode == Defs.GameMode.COOP and level.hero_count() > 1 \
			and str(level.meta.get("kind", "")) == "coop"


## The altar (the first floor under the middle of the arena, from its top) and the perch.
func _find_arena() -> void:
	var room: Rect2i = _room()
	var x: int = room.get_center().x
	altar = Vector2i(x, _floor_under(x, room.position.y))
	perch = Vector2i(room.position.x + PERCH_INSET_PX, _post.y)
	_arena_found = true
	if mate != null:
		mate.altar = altar
		mate._arena_found = true


## The first floor surface at or below `from_y` in the column of `x` (the record's floor when none).
func _floor_under(x: int, from_y: int) -> int:
	var level: LevelBase = Game.level
	if level == null:
		return _post.y
	var col: int = Tuning.to_cell(x)
	for row: int in range(maxi(Tuning.to_cell(from_y), 0), level.grid.rows):
		if TileGrid.is_ground(level.grid.floor_at(col, row)):
			return row * Tuning.TILE + level.grid.surface_offset(col, row, x)
	return _post.y


## Wake rule: a hero within a screen's width and at about its height (the arena zone starts it as a rule).
func _wakes_for(hero: PlayerBase) -> bool:
	return absi(hero.sim_pos.x - sim_pos.x) < Tuning.VIEW_W and absi(hero.sim_pos.y - sim_pos.y) < Tuning.VIEW_H


func _room() -> Rect2i:
	var level: LevelBase = Game.level
	if level != null and arena != &"":
		var zone: SimEntity = level.find_named(arena)
		if zone != null and zone.spawn_params.has("rect"):
			var rect: Rect2i = LevelText.to_rect_px(zone.spawn_params["rect"])
			if rect.size.x > 0:
				return rect
	if level != null and level.is_camera_locked():
		return level.get_camera_lock()
	var view: Rect2i = level.get_view_rect() if level != null else Rect2i(0, 0, Tuning.VIEW_W, Tuning.VIEW_H)
	return view


func _show_hup(on: bool) -> void:
	if _hup == null:
		return
	_hup.visible = on
	if on:
		_hup_ticks = TELEGRAPH_TICKS
		Audio.play_sfx(Sfx.ENEMY_VOICE)


## The Great Roast: drawn on the altar or over its carrier's head by the lead (cosmetic).
func _show_roast() -> void:
	if not is_lead():
		return
	if _roast_drawing == null:
		_roast_drawing = RoastDrawing.new()
		_roast_drawing.name = "Roast"
		_roast_drawing.top_level = false
		add_child(_roast_drawing)
	var where: Vector2i = altar
	if roast_holder != null:
		where = roast_holder.sim_pos + Vector2i(0, -BOX.y - 6)
	_roast_drawing.visible = fighting and _arena_found and not dead
	_roast_drawing.position = Vector2((where - sim_pos) * Tuning.ART_SCALE)


## The roast (a placeholder drawing until art-A's / art-B's prop).
class RoastDrawing:
	extends Node2D

	func _draw() -> void:
		draw_circle(Vector2(0.0, -10.0), 10.0, Color(0.6, 0.32, 0.14))
		draw_circle(Vector2(-4.0, -14.0), 4.0, Color(0.85, 0.55, 0.3))
		draw_line(Vector2(8.0, -14.0), Vector2(16.0, -22.0), Color(0.95, 0.92, 0.85), 3.0)
