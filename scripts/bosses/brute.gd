class_name Brute
extends BossBase
## `bosses/brute` - BOSS 1, the Brute (gorilla archetype, GAMEPLAY.md 6.1).
##
## A giant ape that moves between two arena limits. The head (top 30 px of its body, ASSET_MANIFEST.md 5) is the
## only weak point; the body and the punching fist cost the hero one bone; landing on the head is a safe bounce.
## Hits count at most once per Tuning.BOSS_HIT_COOLDOWN ticks; under 60 hit points it turns red (`brute_enraged`).
## State machine:
##  1. IDLE until the hero is within 250 px (or the arena zone starts the fight): energy bar and boss music.
##  2. WATCH: breathes for up to 110 ticks. A striking hero nearby raises the anger every 8th tick; anger above 3
##     starts the jump routine, 10 or more the attack routine. Under 60 hit points it skips watching.
##  3. JUMP: 44 ticks of chest-beating (rushes when the hero comes within 75 px), a very high jump that shakes the
##     screen on landing (under 40 hit points and close: a ground pound instead), then on tick 88 a leap aimed at
##     the hero - a short hop when he is close, a long flat leap when he is farther than speed class x 80 px.
##  4. ATTACK (66 ticks, 154 while the hit points are within 25 of 50): hops toward the hero when he is farther than
##     100 px, punches when closer, pounds the ground at 25..35 px, hops backwards when calm (anger 0).
##  5. POUND: 66 ticks of hammering the floor with a continuous screen shake (crouch to stand firm).
##  6. STAGGER: a hit stronger than 20 power throws it back and interrupts it for 19 ticks.
##  7. DYING: leaps up, vanishes at the top, bursts into 64 bonus items and drops the fire-starter.
##
## Parameters: `arena` zone name, `left`, `right` absolute columns [10 columns around the anchor], `hp` [64],
## `speed` class 0..4 [2], `enraged` flag (red from the start: the Expert rematch), `drops` [fire_starter],
## `skin` [brute / brute_enraged].
##
## 2.0 co-op form (DESIGN.md B.7, GAMEPLAY.md 13.6; enemies-C, PLAN.md P2.3) - only in a co-op game of two heroes on a
## co-op file (`kind = coop`: w2_l2b_coop); everywhere else, a party of one included, the Brute above runs unchanged:
##  - hit points x5/4 (64 -> 80; PartyTuning.BOSS_HP_MAX_NUM / DEN), counted in club hits: every counted head hit takes
##    COOP_HIT_POWER (25, charged or not), then its head is covered for COOP_COVER_TICKS - every blow glances (wf10 boss
##    balance: 45-90 s for a pair);
##  - it targets whoever hit it last (before the first hit, or when he is down: the nearest ACTIVE hero -
##    LevelBase.nearest_coop_hero, hatched and not idle, DESIGN.md G33 - so a dozing partner never draws the guard);
##  - its **arm guard** faces its target: every head hit of the target hero glances off (a clank and a spark), a club
##    or a throw alike - only the partner reaches the head, from any side (G34: his own hits); a target riding his
##    ACTIVE partner's head (Totem Ride; there is no ride on an idle carrier, G33) is above the guard and his strikes
##    count;
##  - below half its hit points (Expert; PartyTuning.boss_grabs_on) the **Grab**: a GRAB_BEAT_TICKS chest beat, then
##    its hands open GRAB_OPEN_TICKS; an active target whose feet are within GRAB_REACH_PX in front is squeezed (a dozing
##    hero is no bait for the partner's rescue, G33): he cannot move
##    or strike and loses a bone every GRAB_SQUEEZE_TICKS; wriggling (Left and Right pressed in turn) shortens the hold
##    by GRAB_WRIGGLE_TICKS per press; his partner's head hit frees him (and counts) and staggers the Brute
##    BRUTE_STAGGER_TICKS. A hold ends after GRAB_HOLD_TICKS at most; the next grab waits GRAB_COOLDOWN_TICKS.
##  - the ground pound shakes both heroes (the level's shake; crouch to stand firm), as in 1.0.

enum State { IDLE, WATCH, JUMP, ATTACK, POUND, STAGGER, BACK_HOP, DYING, GRAB_BEAT, GRAB_OPEN, HOLD }

const SKIN_CALM: String = "brute"
const SKIN_ENRAGED: String = "brute_enraged"

# --- Co-op form tuning (enemies-C; private until moved into EnemyTuning with enemies-A) ----------------------------
const GRAB_BEAT_TICKS: int = 22          ## the chest beat before the hands open (the telegraph) [G 13.6]
const GRAB_OPEN_TICKS: int = 8           ## hands open [G 13.6]
const GRAB_REACH_PX: int = 30            ## a target's feet within this many px in front are seized [G 13.6]
const GRAB_TRIGGER_PX: int = 60          ## it starts a grab when its target is this close (grounded, same floor)
const GRAB_SQUEEZE_TICKS: int = 44       ## one bone per this many ticks held [G 13.6]
const GRAB_WRIGGLE_TICKS: int = 4        ## each Left / Right press in turn shortens the hold this much [G 13.6]
const GRAB_HOLD_TICKS: int = 132         ## a hold ends after this long at most (tune)
const GRAB_COOLDOWN_TICKS: int = 132     ## ticks between two grabs (tune)
const GRAB_FREE_SHIELD_TICKS: int = 44   ## a freed or released hero blinks this long (the grab trait's rule)
## wf10 boss balance (orchestrator: a co-op boss fight lasts 45-90 s for a competent pair; DB2's duo beat the co-op
## Brute in 6 s Beginner / 10 s Expert with two / four charged blows of 100): in the co-op form every counted head hit
## takes COOP_HIT_POWER - one club hit, charged or not, whatever the weapon - so its hit points count club hits
## (Beginner 187 = 8, Expert 312 = 13; x5/4 of the solo club hits, B.0), and after each counted hit it covers its head
## for COOP_COVER_TICKS (its hit cooldown): every blow glances (a clank) until it has fought on that long. During a
## Grab the partner's blow still frees the held hero at once. (tune)
const COOP_HIT_POWER: int = 25
const COOP_COVER_TICKS: int = 110

## Left and right limits of the feet point, logical px (level parameters `left` / `right`, absolute columns).
var left_x: int = 0
var right_x: int = 0
## Speed class 0..4 (level parameter `speed`): leap distance and hop speeds.
var speed_class: int = EnemyTuning.BRUTE_SPEED_CLASS
## True when it starts red (level flag `enraged`).
var enraged: bool = false

var _state: int = State.IDLE
var _counter: int = 0
var _anger: int = 0
var _air_ticks: int = 0
var _punch_rest: int = 0

# 2.0 co-op form (every field keeps its default in a party of one).
var _coop: bool = false
var _solo_hp: int = 0
var _held: PlayerBase = null
var _held_took_control: bool = false
var _hold_left: int = 0
var _hold_ticks: int = 0
var _wriggle_dir: int = 0
var _grab_cooldown: int = 0


func _default_skin() -> String:
	return SKIN_ENRAGED if enraged else SKIN_CALM


func _apply_params(params: Dictionary) -> void:
	max_hp = EnemyTuning.BRUTE_HP
	hp_per_pip = EnemyTuning.BRUTE_HP_PER_PIP
	boss_drops = [&"fire_starter"]
	super._apply_params(params)
	speed_class = clampi(int(params.get("speed", speed_class)), 0, EnemyTuning.BRUTE_SPEED_CLASS_MAX)
	enraged = param_bool("enraged", enraged)
	var reach: int = EnemyTuning.BRUTE_DEFAULT_REACH_TILES
	var left_col: int = int(params.get("left", cell_col() - reach))
	var right_col: int = int(params.get("right", cell_col() + reach))
	left_x = mini(left_col, right_col) * Tuning.TILE + (Tuning.TILE >> 1)
	right_x = maxi(left_col, right_col) * Tuning.TILE + (Tuning.TILE >> 1)
	_solo_hp = max_hp


## Current state (State), for tests and tools.
func get_state() -> int:
	return _state


## Anger counter of the watch state, for tests and tools.
func get_anger() -> int:
	return _anger


## 2.0: true in the co-op form (DESIGN.md B.7).
func is_coop_form() -> bool:
	return _coop


## 2.0: the hero the co-op Grab holds, or null.
func get_held() -> PlayerBase:
	return _held


## 2.0: hold ticks left of the co-op Grab (0 when it holds nobody).
func get_hold_left() -> int:
	return _hold_left if _held != null else 0


## The weak point this tick (logical px): the top 30 px of the body, mirrored by the facing. G56: none after the lethal
## blow (DYING, every form: nothing hits a dying Brute) and, in the co-op form, none from the high jump's take-off to
## its landing (the 1.0 leap lifts the head out of the den view, under the HUD band: a hit there glances).
func get_head_rect() -> Rect2i:
	if _state == State.DYING or (_coop and _state == State.JUMP and not _grounded):
		return Rect2i()
	var back: int = EnemyTuning.BRUTE_HEAD_BACK if facing > 0 else EnemyTuning.BRUTE_HEAD_FRONT
	var width: int = EnemyTuning.BRUTE_HEAD_BACK + EnemyTuning.BRUTE_HEAD_FRONT
	return Rect2i(sim_pos.x - back, sim_pos.y - box_h, width, EnemyTuning.BRUTE_HEAD_HEIGHT)


## The fists this tick (logical px; empty when they hurt nothing): the punch reaches 40..70 px in front at chest
## height, the ground pound hammers the floor 18..37 px in front while the fists are down (ASSET_MANIFEST.md 5).
func get_fist_rect() -> Rect2i:
	var near: int = 0
	var far: int = 0
	var top: int = 0
	var bottom: int = 0
	if _anim_role == &"attack" and _anim_step() >= EnemyTuning.BRUTE_FIST_FIRST_FRAME:
		near = EnemyTuning.BRUTE_FIST_NEAR
		far = EnemyTuning.BRUTE_FIST_FAR
		top = EnemyTuning.BRUTE_FIST_TOP
		bottom = EnemyTuning.BRUTE_FIST_BOTTOM
	elif _anim_role == &"pound" and _grounded and (_anim_step() & 1) == 0:
		near = EnemyTuning.BRUTE_POUND_NEAR
		far = EnemyTuning.BRUTE_POUND_FAR
		top = EnemyTuning.BRUTE_POUND_TOP
	else:
		return Rect2i()
	var left: int = sim_pos.x + near if facing > 0 else sim_pos.x - far
	return Rect2i(left, sim_pos.y - top, far - near, top - bottom)


func _on_reset() -> void:
	_state = State.IDLE
	_counter = 0
	_anger = 0
	_air_ticks = 0
	_punch_rest = 0
	if skin == SKIN_ENRAGED and not enraged:
		_apply_skin(SKIN_CALM)
	if _coop or _held != null:
		_coop_reset()


func _on_lethal_hit() -> void:
	if _held != null:
		_release(true)
	_set_state(State.DYING)
	xvel = 0
	yvel = EnemyTuning.BRUTE_DEFEAT_YVEL
	_play(&"dead", true)


func _ai_tick() -> void:
	if dead:
		return
	if _state == State.DYING:
		sim_pos.y += Tuning.floor16(yvel)
		yvel += Tuning.ENEMY_GRAVITY
		if yvel >= 0:
			defeat(boss_drops)
		return
	var hero: PlayerBase = _target_hero()
	_physics_step()
	if not fighting:
		_play(&"idle")
		if _wakes_for_any(hero):
			start_fight()
		if not fighting:
			return
	if _state == State.IDLE:
		_set_state(State.WATCH)
	var power: int = _coop_poll(hero) if _coop else poll_weapon_hit(get_head_rect())
	if power > 0:
		_on_head_hit(power, hero)
		if dead or _state == State.DYING:
			return
	if _coop:
		hero = _target_hero()
		if _coop_tick(hero):
			_update_box()
			return
	if hero == null:
		_play(&"idle")
		return
	_contact_every(hero)
	var dist: int = absi(hero.sim_pos.x - sim_pos.x)
	if dist > EnemyTuning.BRUTE_ACTIVE_DX or absi(hero.sim_pos.y - sim_pos.y) > EnemyTuning.BRUTE_ACTIVE_DY:
		_play(&"idle")
		return
	if _grounded and _state != State.BACK_HOP and _state != State.STAGGER:
		facing = _dir_to(hero)
	_counter += 1
	match _state:
		State.WATCH:
			_watch_tick(hero)
		State.JUMP:
			_jump_tick(hero, dist)
		State.ATTACK:
			_attack_tick(hero, dist)
		State.POUND:
			_pound_tick()
		State.STAGGER:
			_play(&"hurt")
			if _counter > EnemyTuning.BRUTE_STAGGER_TICKS:
				_set_state(State.WATCH)
		State.BACK_HOP:
			_back_hop_tick(hero)
	_update_box()


# =================================================================================================================
# States
# =================================================================================================================

func _watch_tick(hero: PlayerBase) -> void:
	_play(&"idle")
	if hp < EnemyTuning.BRUTE_SKIP_WATCH_HP:
		_set_state(State.JUMP)
		return
	if _striking_near(hero) and (_counter & EnemyTuning.BRUTE_ANGER_PERIOD_MASK) == 0:
		_raise_anger()
	if _counter >= EnemyTuning.BRUTE_WATCH_TICKS:
		_raise_anger()
		_set_state(State.JUMP)
	elif _anger >= EnemyTuning.BRUTE_ANGER_ATTACK:
		_set_state(State.ATTACK)
	elif _anger > EnemyTuning.BRUTE_ANGER_JUMP:
		_set_state(State.JUMP)


func _jump_tick(hero: PlayerBase, dist: int) -> void:
	var taunt: int = EnemyTuning.BRUTE_TAUNT_TICKS
	var leap_at: int = taunt + EnemyTuning.BRUTE_LEAP_DELAY
	if _counter < taunt:
		_play(&"taunt")
		if _counter == 1:
			Audio.play_sfx(Sfx.BOSS_CHEST_BEAT)
		if dist < EnemyTuning.BRUTE_RUSH_RANGE:
			_set_state(State.ATTACK)
	elif _counter == taunt:
		if hp < EnemyTuning.BRUTE_POUND_HP and dist < EnemyTuning.BRUTE_CLOSE_RANGE:
			_set_state(State.POUND)
			return
		yvel = EnemyTuning.BRUTE_HIGH_JUMP_YVEL
		xvel = 0
		_grounded = false
		_play(&"air", true)
	elif _counter < leap_at:
		_play_air_pose()
		if dist <= EnemyTuning.BRUTE_CLOSE_RANGE:
			_anger = EnemyTuning.BRUTE_ANGER_RUSH
			_set_state(State.ATTACK)
	elif _counter == leap_at:
		var dir: int = _dir_to(hero)
		facing = dir
		if dist > speed_class * EnemyTuning.BRUTE_LEAP_FAR_PER_CLASS:
			yvel = EnemyTuning.BRUTE_LEAP_YVEL
			xvel = dir * (EnemyTuning.BRUTE_LEAP_XVEL_BASE + speed_class * EnemyTuning.BRUTE_LEAP_XVEL_STEP)
		else:
			yvel = EnemyTuning.BRUTE_HOP_YVEL
			xvel = dir * clampi(dist * EnemyTuning.BRUTE_HOP_XVEL_PER_PX, EnemyTuning.BRUTE_HOP_XVEL_MIN,
					EnemyTuning.BRUTE_HOP_XVEL_MAX)
		_grounded = false
		_play(&"roll", true)
	elif _grounded:
		_anger = EnemyTuning.BRUTE_ANGER_AFTER_JUMP
		_set_state(State.WATCH)
	else:
		_play(&"roll")


func _attack_tick(hero: PlayerBase, dist: int) -> void:
	var length: int = EnemyTuning.BRUTE_ATTACK_TICKS
	if absi(hp - EnemyTuning.BRUTE_ATTACK_LONG_HP) <= EnemyTuning.BRUTE_ATTACK_LONG_BAND:
		length = EnemyTuning.BRUTE_ATTACK_LONG_TICKS
	if _counter > length:
		_set_state(State.JUMP)
		return
	if not _grounded:
		_play_air_pose()
		return
	if _anim_role == &"attack" and not _anim_done():
		return
	if dist > EnemyTuning.BRUTE_HOP_RANGE:
		xvel = _dir_to(hero) * (EnemyTuning.BRUTE_ATTACK_HOP_XVEL_BASE
				+ speed_class * EnemyTuning.BRUTE_ATTACK_HOP_XVEL_STEP)
		yvel = EnemyTuning.BRUTE_ATTACK_HOP_YVEL
		_grounded = false
		_play(&"air", true)
		return
	if dist > EnemyTuning.BRUTE_PUNCH_RANGE and dist <= EnemyTuning.BRUTE_POUND_RANGE:
		_set_state(State.POUND)
		return
	if dist > EnemyTuning.BRUTE_POUND_RANGE and _anger == 0:
		_set_state(State.BACK_HOP)
		return
	if _punch_rest > 0:
		_punch_rest -= 1
		_play(&"idle")
		return
	_punch_rest = EnemyTuning.BRUTE_PUNCH_REST_TICKS
	_play(&"attack", true)


func _pound_tick() -> void:
	_play(&"pound")
	if _counter > EnemyTuning.BRUTE_POUND_TICKS:
		_set_state(State.ATTACK)
		return
	if _grounded and Game.level != null:
		Game.level.request_shake(EnemyTuning.BOSS_BOB_SHAKE)
		if _counter % EnemyTuning.BRUTE_POUND_SOUND_PERIOD == 1:
			Audio.play_sfx(Sfx.QUAKE)


func _back_hop_tick(hero: PlayerBase) -> void:
	if _counter > EnemyTuning.BRUTE_BACK_HOP_TICKS:
		_set_state(State.WATCH)
		return
	if _counter == 1:
		facing = _dir_to(hero)
		yvel = EnemyTuning.BRUTE_BACK_HOP_YVEL
		xvel = -facing * EnemyTuning.BRUTE_BACK_HOP_XVEL
		_grounded = false
		_play(&"air", true)
	elif _grounded:
		_play(&"idle")
	else:
		_play_air_pose()


# =================================================================================================================
# Internals
# =================================================================================================================

func _set_state(state: int) -> void:
	_state = state
	_counter = 0
	_punch_rest = 0


func _raise_anger() -> void:
	_anger = mini(_anger + 1, EnemyTuning.BRUTE_ANGER_MAX)


## Gravity, floors and walls of the arena; the feet stay between the limits. A landing after a real flight shakes
## the screen.
func _physics_step() -> void:
	var was_grounded: bool = _grounded
	_ground_step(false, false)
	sim_pos.x = clampi(sim_pos.x, left_x, right_x)
	if _grounded:
		xvel = 0
		if not was_grounded and _air_ticks >= EnemyTuning.BRUTE_SHAKE_MIN_AIR_TICKS and Game.level != null:
			Game.level.request_shake(EnemyTuning.BOSS_STOMP_SHAKE)
			Audio.play_sfx(Sfx.QUAKE)
		_air_ticks = 0
	else:
		_air_ticks += 1


func _play_air_pose() -> void:
	if _grounded:
		_play(&"idle")
	elif yvel < 0:
		_play(&"air")
	else:
		_play(&"land")


func _update_box() -> void:
	match _anim_role:
		&"roll":
			set_box(EnemyTuning.BRUTE_BOX_BALL)
		&"land", &"pound", &"crouch":
			set_box(EnemyTuning.BRUTE_BOX_LOW)
		_:
			set_box(EnemyTuning.BRUTE_BOX_STAND)


## A club or thrown weapon hit the head. 2.0 co-op (wf10): one club hit's worth, then the head is covered.
func _on_head_hit(power: int, hero: PlayerBase) -> void:
	if _coop:
		power = COOP_HIT_POWER
	apply_boss_hit(power)
	if dead or _state == State.DYING:
		return
	if _coop:
		hit_cooldown = COOP_COVER_TICKS
	_raise_anger()
	if hero != null and hero.run.has_glider:
		hero.set_glider(false)
	if hp < EnemyTuning.BRUTE_SKIP_WATCH_HP and skin == SKIN_CALM:
		_apply_skin(SKIN_ENRAGED)
	if _coop and _held != null and last_hitter != _held:
		# 2.0 co-op Grab: the partner's head hit frees the held hero and staggers the Brute.
		_release(true)
		_stagger_from(last_hitter)
		return
	if _coop and last_hitter != null:
		hero = last_hitter
	if power > EnemyTuning.BRUTE_STAGGER_MIN_POWER:
		var away: int = -_dir_to(hero) if hero != null else -facing
		xvel = away * EnemyTuning.BRUTE_STAGGER_XVEL
		yvel = EnemyTuning.BRUTE_STAGGER_YVEL_FALLING if yvel > 0 else EnemyTuning.BRUTE_STAGGER_YVEL
		_grounded = false
		_set_state(State.STAGGER)
		_play(&"hurt", true)


# =================================================================================================================
# 2.0 co-op form (DESIGN.md B.7): last hitter, arm guard, the Grab
# =================================================================================================================

## Start the fight (the arena zone or the wake rule): the form is fixed first, so the bar opens with its hit points.
func start_fight() -> void:
	if not fighting and not dead:
		_configure_form()
	super.start_fight()


## Co-op: it targets whoever hit it last (BossBase.last_hitter) while he may be targeted; else the nearest ACTIVE hero
## (LevelBase.nearest_coop_hero, G33: the guard never faces a dozing partner, so a lone player is always its target),
## else the party's rule (EnemyBase._choose_target). A party of one: the 1.0 target.
func _choose_target() -> PlayerBase:
	if _coop and last_hitter != null and is_instance_valid(last_hitter) and last_hitter.is_party_targetable():
		return last_hitter
	if _coop and Game.level != null:
		var active: PlayerBase = Game.level.nearest_coop_hero(self)
		if active != null:
			return active
	return super._choose_target()


## The co-op form in a co-op game of two or more heroes on a co-op file; the hit points x5/4. Idempotent; a party of
## one, a solo file or another mode keeps (or gets back) the 1.0 Brute.
func _configure_form() -> void:
	var level: LevelBase = Game.level
	var want: bool = level != null and Game.mode == Defs.GameMode.COOP and level.hero_count() > 1 \
			and str(level.meta.get("kind", "")) == "coop"
	if want == _coop:
		return
	_coop = want
	if _coop:
		max_hp = _solo_hp * PartyTuning.BOSS_HP_MAX_NUM / PartyTuning.BOSS_HP_MAX_DEN
	else:
		max_hp = _solo_hp
	hp = max_hp


func _coop_reset() -> void:
	if _held != null:
		_release(false)
	_hold_left = 0
	_hold_ticks = 0
	_wriggle_dir = 0
	_grab_cooldown = 0
	_coop = false
	max_hp = _solo_hp
	hp = max_hp


## The weapon test of the co-op form (BossBase.poll_weapon_hit's order and cooldown): a hit by the target hero glances
## off the arm guard unless he rides his partner's head; the held hero cannot strike. Returns the power that counts.
func _coop_poll(target: PlayerBase) -> int:
	if hit_cooldown > 0:
		hit_cooldown -= 1
	if _glance_ticks > 0:
		_glance_ticks -= 1
	var level: LevelBase = Game.level
	if level == null or dead or not fighting:
		return 0
	var head: Rect2i = get_head_rect()
	var projectiles: Array[SimEntity] = level.get_kind(Defs.Kind.HERO_PROJECTILE)
	for i: int in range(projectiles.size() - 1, -1, -1):
		var projectile: ProjectileBase = projectiles[i] as ProjectileBase
		if projectile == null or projectile.spent or not Overlap.rects(projectile.get_box(), head):
			continue
		projectile.consume()
		if _guarded(level.get_hero(projectile.owner_slot), target):
			_guard_glance(level, head.get_center())
			return 0
		if _covered():
			_guard_glance(level, head.get_center())
			return 0
		_note_hitter(level, projectile.owner_slot)
		return projectile.power
	for hero: PlayerBase in level.contact_order():
		if hero == _held or not hero.club_box_active or not Overlap.rects(hero.club_box, head):
			continue
		if _guarded(hero, target):
			_guard_glance(level, hero.club_box.intersection(head).get_center())
			continue
		if _covered():
			# wf10: the head is covered after a counted hit (the hit cooldown): the blow glances.
			_guard_glance(level, hero.club_box.intersection(head).get_center())
			return 0
		hero.notify_weapon_hit()
		_note_hitter(level, hero.slot)
		return hero.club_power
	return 0


## True when the arm guard stops a hit of `hitter`: he is the target (the guard faces him) and does not ride a Totem
## on an ACTIVE carrier (G33). During a Grab the guard is down: only the held hero cannot hit (his partner always can).
func _guarded(hitter: PlayerBase, target: PlayerBase) -> bool:
	if hitter == null:
		return false
	if _held != null:
		return hitter == _held
	var over_guard: bool = hitter.is_riding_totem() and hitter.totem_carrier.counts_for_coop()
	return hitter == target and not over_guard


## Co-op: the head is covered - the hit cooldown runs (COOP_COVER_TICKS after a counted hit) and nobody is held (the
## partner's blow during a Grab frees the held hero at once).
func _covered() -> bool:
	return hit_cooldown > 0 and _held == null


func _guard_glance(level: LevelBase, point: Vector2i) -> void:
	if _glance_ticks > 0:
		return
	_glance_ticks = GLANCE_TICKS
	Audio.play_sfx(Sfx.CLUB_HIT_SCENERY)
	level.spawn_fx(&"fx/hit_stars", point)


## The co-op parts of a tick: the grab cooldown and the Grab states. True when the Grab ran the tick.
func _coop_tick(target: PlayerBase) -> bool:
	if _grab_cooldown > 0:
		_grab_cooldown -= 1
	match _state:
		State.GRAB_BEAT:
			_counter += 1
			xvel = 0
			_play(&"taunt")
			if _counter == 1:
				Audio.play_sfx(Sfx.BOSS_CHEST_BEAT)
			if _counter >= GRAB_BEAT_TICKS:
				_set_state(State.GRAB_OPEN)
			if target != null:
				_contact_every(target)
			return true
		State.GRAB_OPEN:
			_counter += 1
			_play(&"attack")
			if target != null and _in_grab_reach(target):
				_seize(target)
				return true
			if _counter >= GRAB_OPEN_TICKS:
				_grab_cooldown = GRAB_COOLDOWN_TICKS
				_set_state(State.WATCH)
			if target != null:
				_contact_every(target)
			return true
		State.HOLD:
			_hold_tick()
			return true
	if _grab_wanted(target):
		facing = _dir_to(target)
		_set_state(State.GRAB_BEAT)
		return true
	return false


## A grab starts (from watching or attacking, grounded) below half its hit points on Expert when its target stands
## close on its floor and the last grab is long enough ago.
func _grab_wanted(target: PlayerBase) -> bool:
	if target == null or _grab_cooldown > 0 or not _grounded or hp * 2 >= max_hp or target.is_helper():
		return false
	if not PartyTuning.boss_grabs_on(Game.difficulty):
		return false
	if _state != State.WATCH and _state != State.ATTACK:
		return false
	return absi(target.sim_pos.x - sim_pos.x) <= GRAB_TRIGGER_PX and absi(target.sim_pos.y - sim_pos.y) <= Tuning.TILE


## The target's feet within GRAB_REACH_PX in front of the feet point, on its floor (16 px up or down). A hero blinking
## after a hurt is seized all the same (whoever stands that close has touched the body); a Helper-mode P2
## (PlayerBase.is_helper, PHYSICS.md C.12) never is.
func _in_grab_reach(hero: PlayerBase) -> bool:
	if hero.dead or hero.is_down() or not hero.counts_for_coop() or hero.is_helper():
		return false
	var ahead: int = (hero.sim_pos.x - sim_pos.x) * facing
	return ahead >= 0 and ahead <= GRAB_REACH_PX and absi(hero.sim_pos.y - sim_pos.y) <= Tuning.TILE


func _seize(hero: PlayerBase) -> void:
	_held = hero
	_held_took_control = hero.control_enabled
	if _held_took_control:
		hero.set_control_enabled(false)
	_hold_left = GRAB_HOLD_TICKS
	_hold_ticks = 0
	_wriggle_dir = 0
	_set_state(State.HOLD)
	_place_held()
	if Game.level != null:
		Game.level.notify_hero_teleported(hero)
	Audio.play_sfx(Sfx.BOSS_ROAR)


## One tick of the hold: squeeze (a bone per GRAB_SQUEEZE_TICKS), read the wriggle (his own slot's keys, GameInput:
## Left and Right in turn), keep him in the hands; the hold ends when its time is used up.
func _hold_tick() -> void:
	_play(&"crouch")
	xvel = 0
	if _held == null or not is_instance_valid(_held) or _held.dead or _held.is_down():
		_release(false)
		_after_grab()
		return
	_hold_ticks += 1
	_hold_left -= 1
	var keys: int = GameInput.get_flags(_held.slot) & (Defs.IN_LEFT | Defs.IN_RIGHT)
	var dir: int = 0
	if keys == Defs.IN_LEFT:
		dir = -1
	elif keys == Defs.IN_RIGHT:
		dir = 1
	if dir != 0 and dir != _wriggle_dir:
		if _wriggle_dir != 0:
			_hold_left -= GRAB_WRIGGLE_TICKS
		_wriggle_dir = dir
	if _hold_ticks % GRAB_SQUEEZE_TICKS == 0:
		var hero: PlayerBase = _held
		Audio.play_sfx(Sfx.PLAYER_HURT_HEAVY)
		if hero.run.lose_bone():
			_release(false)
			hero.kill(&"enemy")
			_after_grab()
			return
	if _hold_left <= 0:
		_release(true)
		_after_grab()
		return
	_place_held()
	_contact_every(_held)


## The held hero stands in the hands: his feet GRAB_REACH_PX in front, on the Brute's floor, no motion, no strike.
func _place_held() -> void:
	if _held == null:
		return
	_held.sim_pos = Vector2i(sim_pos.x + facing * GRAB_REACH_PX, sim_pos.y)
	_held.xvel = 0
	_held.yvel = 0
	_held.attack_gate = false
	_held.club_box_active = false


## Let the held hero go (`shielded`: he blinks GRAB_FREE_SHIELD_TICKS, contact skipped).
func _release(shielded: bool) -> void:
	var hero: PlayerBase = _held
	_held = null
	_hold_left = 0
	if hero == null or not is_instance_valid(hero):
		_held_took_control = false
		return
	if _held_took_control and not hero.dead and not hero.is_down():
		hero.set_control_enabled(true)
	_held_took_control = false
	if shielded and not hero.dead and not hero.is_down():
		hero.shield = maxi(hero.shield, GRAB_FREE_SHIELD_TICKS)


func _after_grab() -> void:
	_grab_cooldown = GRAB_COOLDOWN_TICKS
	_set_state(State.WATCH)


## The partner's hit during a hold: thrown back away from him for BRUTE_STAGGER_TICKS (the 1.0 stagger).
func _stagger_from(hitter: PlayerBase) -> void:
	var away: int = -_dir_to(hitter) if hitter != null else -facing
	xvel = away * EnemyTuning.BRUTE_STAGGER_XVEL
	yvel = EnemyTuning.BRUTE_STAGGER_YVEL
	_grounded = false
	_grab_cooldown = GRAB_COOLDOWN_TICKS
	_set_state(State.STAGGER)
	_play(&"hurt", true)


## Wake rule (BossBase._wakes_for_any): the hero is within BRUTE_WAKE_RANGE px horizontally, at about its height.
func _wakes_for(hero: PlayerBase) -> bool:
	return absi(hero.sim_pos.x - sim_pos.x) < EnemyTuning.BRUTE_WAKE_RANGE \
			and absi(hero.sim_pos.y - sim_pos.y) <= EnemyTuning.BRUTE_ACTIVE_DY


## True when a strike raises the anger: the target hero strikes (1.0; he is within the active range here); a party:
## any targetable hero within the active range strikes.
func _striking_near(target: PlayerBase) -> bool:
	var level: LevelBase = Game.level
	if level == null or level.hero_count() <= 1:
		return target.is_striking()
	for hero: PlayerBase in level.contact_order():
		if hero.is_party_targetable() and hero.is_striking() \
				and absi(hero.sim_pos.x - sim_pos.x) <= EnemyTuning.BRUTE_ACTIVE_DX \
				and absi(hero.sim_pos.y - sim_pos.y) <= EnemyTuning.BRUTE_ACTIVE_DY:
			return true
	return false


## Body, head and fists against every hero in contact order (1.0: the target hero, the only one; the AI itself
## still follows the target). Dead heroes are skipped, as 1.0 never tested a dead target.
func _contact_every(target: PlayerBase) -> void:
	var level: LevelBase = Game.level
	if level == null or level.hero_count() <= 1:
		_contact(target)
		return
	for hero: PlayerBase in level.contact_order():
		if not hero.dead:
			_contact(hero)


## Body, head and fist against the hero: a landing on the head bounces him, everything else costs a bone.
func _contact(hero: PlayerBase) -> void:
	if _state == State.STAGGER or hero == _held:
		return
	if Overlap.body(hero, self, hero):
		if Overlap.stomp and hero.yvel >= 0 and not hero.is_gliding():
			var held: bool = (hero.input_flags & Defs.IN_UP) != 0
			hero.bounce(Tuning.BOSS_BOUNCE_YVEL_UP if held else Tuning.BOSS_BOUNCE_YVEL, Overlap.depth)
			Events.player_bounced.emit(self, 0)
			Events.hero_bounced.emit(hero, self, 0)
			return
		if _hurt_hero(hero):
			return
	var fist: Rect2i = get_fist_rect()
	if fist.size.x > 0 and Overlap.rects(fist, hero.get_box()):
		_hurt_hero(hero)


func _hurt_hero(hero: PlayerBase) -> bool:
	if hero.is_immune() or hero.is_feasting() or not touch_hero(hero):
		return false
	_anger = maxi(_anger - (EnemyTuning.BRUTE_ANGER_CALM_BASE - speed_class), 0)
	return true
