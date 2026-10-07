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

enum State { IDLE, WATCH, JUMP, ATTACK, POUND, STAGGER, BACK_HOP, DYING }

const SKIN_CALM: String = "brute"
const SKIN_ENRAGED: String = "brute_enraged"

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


## Current state (State), for tests and tools.
func get_state() -> int:
	return _state


## Anger counter of the watch state, for tests and tools.
func get_anger() -> int:
	return _anger


## The weak point this tick (logical px): the top 30 px of the body, mirrored by the facing.
func get_head_rect() -> Rect2i:
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


func _on_lethal_hit() -> void:
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
	var power: int = poll_weapon_hit(get_head_rect())
	if power > 0:
		_on_head_hit(power, hero)
		if dead or _state == State.DYING:
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


## A club or thrown weapon hit the head.
func _on_head_hit(power: int, hero: PlayerBase) -> void:
	apply_boss_hit(power)
	if dead or _state == State.DYING:
		return
	_raise_anger()
	if hero != null and hero.run.has_glider:
		hero.set_glider(false)
	if hp < EnemyTuning.BRUTE_SKIP_WATCH_HP and skin == SKIN_CALM:
		_apply_skin(SKIN_ENRAGED)
	if power > EnemyTuning.BRUTE_STAGGER_MIN_POWER:
		var away: int = -_dir_to(hero) if hero != null else -facing
		xvel = away * EnemyTuning.BRUTE_STAGGER_XVEL
		yvel = EnemyTuning.BRUTE_STAGGER_YVEL_FALLING if yvel > 0 else EnemyTuning.BRUTE_STAGGER_YVEL
		_grounded = false
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
	if _state == State.STAGGER:
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
