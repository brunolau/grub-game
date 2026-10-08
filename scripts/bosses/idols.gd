class_name Idols
extends BossBase
## `bosses/idols` - the Twin Idols of Idol Court (`w8_l2b`; DESIGN.md B.4, GAMEPLAY.md 13.6): the Wall Colossus
## archetype (GAMEPLAY.md 6.3) twice, one shared brain. Owner: enemies-C (PLAN.md P2.3).
##
## Place the record like the Colossus: in the floor-level air cell just left of the arena's RIGHT wall - that is the
## Sun Idol (sandstone gold; feet point = the bottom-right corner of its picture, 32 px inside the wall). The Moon Idol
## (jade) is its mirror image in the LEFT wall: its feet point (the bottom-LEFT corner) is found on the first tick, 32 px
## inside the first wall to the left that stands both on the floor-level row and at head height (else mirrored in the
## arena rectangle). Its open jaws (95 px over the feet) stay clear of the fight HUD with the floor on the view's last
## row (DESIGN.md G35 as corrected: 55 px under the view top outside the boss bar's columns; the test pins it).
##
## Solo (and a party of one): one idol is **Awake** (glowing eyes; the Colossus attack loop of spits - jaws open
## EnemyTuning.COLOSSUS_SPIT_RELEASE_TICK ticks ahead, rocks of 32-96 v16 that bounce twice); the other is **Asleep**
## and armoured and takes the loop's slam steps: it slams its wall and a sandstone masonry block (`projectiles/
## boss_stalactite skin=masonry`, the stalactite rules: a 14-tick rattle) drops over the hero. The weak point is the
## awake idol's head in its current pose (its open jaws): a forward or high strike from its ledge, a jump strike, any
## thrown weapon; every hit of any weapon counts 1 (archetype 6.3; the club works - Book II rule). The asleep idol's
## head glances. Every RAGE_EVERY-th counted hit both idols **rage** for EnemyTuning.COLOSSUS_RAGE_TICKS (armoured;
## the Colossus rage timings: the awake idol spits one rock, the asleep one drops two blocks), then they swap roles.
## An idol whose hits are used up breaks (its broken pose stays in the wall); the other is then awake for good and
## also takes the slam steps. Both broken: defeat (the fire-starter and the bonus burst).
##
## Co-op form ("Twin Hit"; a co-op game of two heroes in a `kind = coop` file): both idols wake together, each facing
## the hero on its own half of the room. An idol is awake - it spits and slams - only while a hero who
## COUNTS (PlayerBase.counts_for_coop: hatched and not idle, DESIGN.md G33) stands on its half; with nobody of the kind
## on its side it sleeps, armoured (an egg or a dozing partner wakes nothing). A twin crack shuts both jaws until the
## idols have spat again (wf10 boss balance, [method jaws_open]); a hit on shut jaws glances. A hit on open jaws cracks
## the idol only if
## its twin is struck within the twin window (PartyTuning.window_ticks: 24 Beginner / 12 Expert) by a hero of ANOTHER
## slot (G34: one hero's throw plus his own strike never twin): both crack together (one hit each), else the lone hit
## fades. Every COOP_RAGE_EVERY-th (2nd) twin crack both rage for COOP_RAGE_TICKS (wf10), then their targets swap (each spits at the hero on the far half and
## drops masonry over him). Hits per idol: 8 (7 solo).
##
## Rules of B.0 kept: every attack shows its pose 10+ ticks ahead (the open jaws before a rock, the slam and the
## 14-tick rattle before a block), the attack clock runs on through hurt poses (no stun-lock), a head bounce bounces
## the hero and harms nobody, the bodies cost a bone (boss body knock-back).
##
## Parameters: `arena` zone name, `hp` hits per idol [7; co-op 8], `drops` [fire_starter].

enum State { DORMANT, IDLE, SPIT, SLAM, RAGE, BROKEN }
enum Role { AWAKE, ASLEEP, BROKEN }
enum Attack { SPIT, SLAM }

const MOON: int = 0
const SUN: int = 1
const ROCK_ID: StringName = &"projectiles/boss_rock"
const MASONRY_ID: StringName = &"projectiles/boss_stalactite"
const MASONRY_SKIN: String = "masonry"
## The spat rocks in each idol's colour (art-B's idols_parts roles), by idol.
const ROCK_SKINS: Array[String] = ["rock_moon", "rock_sun"]
## The shared attack loop: the Colossus loop (spit, slam, spit, slam, slam; idle pauses COLOSSUS_IDLE_TICKS).
const LOOP: Array[int] = [Attack.SPIT, Attack.SLAM, Attack.SPIT, Attack.SLAM, Attack.SLAM]

# --- Private tuning (enemies-C; to move into EnemyTuning with enemies-A, request wf8_enemies_c_to_enemies-A) --------
## Hits each idol takes (any weapon counts 1) [G 13.6]; the co-op form [G 13.6, R8].
const HITS_PER_IDOL: int = 7
const HITS_PER_IDOL_COOP: int = 8
## Every this many counted hits (solo) / twin cracks (co-op) both idols rage.
const RAGE_EVERY: int = 4
## Co-op (wf10 boss balance: co-op Idols harder): both rage every COOP_RAGE_EVERY-th twin crack, for COOP_RAGE_TICKS
## (the Colossus rage's rock and drops at its ticks 10, 18 and 28; armoured all along), then their targets cross. (tune)
const COOP_RAGE_EVERY: int = 2
const COOP_RAGE_TICKS: int = 88
## Co-op (wf10 boss balance): after a twin crack both jaws stay shut until the idols have spat again - the end of the
## first spit step that begins this long or longer after the crack (0: the next spit; 66 cost D8's duo a rock on
## every twin, the jaws opening as the rock left them). (tune)
const COOP_SHUT_MIN_TICKS: int = 0
## Ticks between two hits that may count on the same idol (its hurt pose; the Colossus' own cooldown).
const HURT_TICKS: int = EnemyTuning.COLOSSUS_HURT_TICKS
## Co-op: a hit on open jaws waits this long at most for its twin (PartyTuning.window_ticks overrides it); a pending
## hit may be renewed by another hit on the same idol after PENDING_RENEW_TICKS.
const PENDING_RENEW_TICKS: int = 8
## Co-op aim of a spat rock: a rock leaves the jaws flat and lands about ROCK_FALL_TICKS later.
const ROCK_FALL_TICKS: int = 12
## Tints of the shared colossus sheet until art-B's gradient-mapped `idol_moon` / `idol_sun` sheets exist.
const TINT_MOON: Color = Color(0.62, 1.0, 0.78)
const TINT_SUN: Color = Color(1.0, 0.86, 0.52)
const SKIN_MOON: String = "idol_moon"
const SKIN_SUN: String = "idol_sun"
const SKIN_FALLBACK: String = "colossus"
## How far left of the Sun's body the Moon's wall is searched for (cells).
const WALL_SCAN_COLS: int = 40

var _state: int = State.DORMANT
var _timer: int = 0
var _step: int = 0
## Ticks since the last attack ended (the Colossus idle clock).
var _clock: int = 0
var _rage_due: bool = false
## Counted hits (solo) or twin cracks (co-op) so far: the rage counter.
var _counted: int = 0
## Co-op: true after an odd number of rages (each idol aims at the far half).
var _crossed: bool = false
## Per idol (MOON, SUN): role, hits left, hurt pose ticks left, cooldown, pending co-op hit tick, the pose shown.
var _role: Array[int] = [Role.ASLEEP, Role.AWAKE]
var _hits_left: Array[int] = [HITS_PER_IDOL, HITS_PER_IDOL]
var _hurt: Array[int] = [0, 0]
var _cooldown: Array[int] = [0, 0]
var _pending: Array[int] = [-1, -1]
var _pending_age: Array[int] = [0, 0]
## Co-op: the slot of the hero whose hit waits for its twin (G34: the twin must come from another slot).
var _pending_slot: Array[int] = [-1, -1]
var _pose: Array[StringName] = [&"idle", &"idle"]
var _pose_age: Array[int] = [0, 0]
var _flash_idol: Array[int] = [0, 0]
## Which idols take part in the running attack (SPIT / SLAM / RAGE).
var _attackers: Array[bool] = [false, false]
## The Moon's feet point (bottom-left corner of its picture); found on the first tick.
var _moon_pos: Vector2i = Vector2i.ZERO
var _moon_placed: bool = false
var _per_idol: int = HITS_PER_IDOL
var _coop: bool = false
## Co-op (wf10): both jaws shut after a twin crack (the Sim tick of the crack; -1 = open), until the end of a spit step
## that began COOP_SHUT_MIN_TICKS or more after it.
var _shut: bool = false
var _shut_tick: int = -1
var _spit_began: int = -1
var _moon_sprite: Sprite2D = null
var _moon_skin: EnemySkin = null
var _sun_skin: EnemySkin = null
var _glance_tick_idol: int = -1000


func _default_skin() -> String:
	return SKIN_SUN if EnemySkin.find(SKIN_SUN) != null else SKIN_FALLBACK


func _apply_params(params: Dictionary) -> void:
	max_hp = HITS_PER_IDOL * 2
	hp_per_pip = 2
	music = Sfx.MUSIC_BOSS_IDOLS
	boss_drops = [&"fire_starter"]
	super._apply_params(params)
	_per_idol = maxi(int(params.get("hp", HITS_PER_IDOL)), 1)
	facing = 1
	_spawn_facing = 1
	spawn_pos.x += (Tuning.TILE >> 1) + EnemyTuning.COLOSSUS_RIM_PX
	teleport(spawn_pos)
	_configure_form()


func _ready() -> void:
	set_box(EnemyTuning.COLOSSUS_BOX)
	_build_moon_sprite()
	_refresh_visual()


# =================================================================================================================
# Queries (tests and tools)
# =================================================================================================================

## Current state of the shared brain (State).
func get_state() -> int:
	return _state


## Role of an idol (MOON or SUN): Role.AWAKE, ASLEEP or BROKEN.
func get_role(idol: int) -> int:
	return _role[idol]


## Hits an idol still takes.
func get_hits_left(idol: int) -> int:
	return _hits_left[idol]


## True in the co-op form (Twin Hit).
func is_coop_form() -> bool:
	return _coop


## True after an odd number of co-op rages: each idol aims at the hero on the far half.
func is_crossed() -> bool:
	return _crossed


## The feet point of an idol (logical px): the Sun's bottom-right, the Moon's bottom-left corner.
func get_idol_pos(idol: int) -> Vector2i:
	_place_moon()
	return _moon_pos if idol == MOON else sim_pos


## The body of an idol (logical px).
func get_body_rect(idol: int) -> Rect2i:
	var box: Vector3i = EnemyTuning.COLOSSUS_BOX
	var pos: Vector2i = get_idol_pos(idol)
	if idol == MOON:
		return Rect2i(pos.x, pos.y - box.y, box.x, box.y)
	return Rect2i(pos.x - box.x, pos.y - box.y, box.x, box.y)


## The head of an idol in its current pose (logical px): the Colossus head rectangles, mirrored for the Moon.
func get_head_rect(idol: int) -> Rect2i:
	var head: Rect2i = EnemyTuning.COLOSSUS_HEAD_IDLE
	match _pose[idol]:
		&"spit", &"rage":
			head = EnemyTuning.COLOSSUS_HEAD_SPIT
		&"slam":
			head = EnemyTuning.COLOSSUS_HEAD_SLAM
		&"hurt":
			head = EnemyTuning.COLOSSUS_HEAD_HURT
	var pos: Vector2i = get_idol_pos(idol)
	if idol == MOON:
		return Rect2i(pos.x - head.position.x - head.size.x, pos.y + head.position.y, head.size.x, head.size.y)
	return Rect2i(pos + head.position, head.size)


## True when a hit on this idol's head can count now (the solo awake idol; co-op: a hero who counts - hatched, not
## idle - on its half), outside a rage.
func is_open(idol: int) -> bool:
	if _role[idol] == Role.BROKEN or _state == State.RAGE or _state == State.DORMANT or not fighting:
		return false
	if _coop:
		return _side_hero(idol, false) != null
	return _role[idol] == Role.AWAKE


## True when a hit on this idol's head counts now: [method is_open] and, in the co-op form, jaws that are not shut
## (wf10 boss balance: co-op Idols harder - with jaws open whenever a hero stood on each half, D8's duo cracked all 8
## twins in 19 s, one every 35-50 ticks): a twin crack SHUTS both jaws until the idols have spat again (the end of the
## next spit step of the loop), so the pair cracks them at most twice per attack loop, each time after dodging the
## rocks the spit aimed at them. Solo: [method is_open].
func jaws_open(idol: int) -> bool:
	if not is_open(idol):
		return false
	return not (_coop and _shut)


## The y of the floor's top under the idols (their feet point stands on it).
func get_floor_y() -> int:
	return sim_pos.y


## Where a spat rock of this idol leaves its jaws.
func get_mouth(idol: int) -> Vector2i:
	var mouth: Vector2i = EnemyTuning.COLOSSUS_MOUTH
	var pos: Vector2i = get_idol_pos(idol)
	if idol == MOON:
		return Vector2i(pos.x - mouth.x, pos.y + mouth.y)
	return pos + mouth


## x that splits the room into the Moon's half (left of it) and the Sun's half: the middle between the two faces.
func get_mid_x() -> int:
	var moon: Rect2i = get_body_rect(MOON)
	var sun: Rect2i = get_body_rect(SUN)
	return (moon.end.x + sun.position.x) >> 1


# =================================================================================================================
# The tick
# =================================================================================================================

func _on_reset() -> void:
	_state = State.DORMANT
	_timer = 0
	_step = 0
	_clock = 0
	_rage_due = false
	_counted = 0
	_crossed = false
	_shut = false
	_shut_tick = -1
	_spit_began = -1
	_configure_form()
	for idol: int in 2:
		_hurt[idol] = 0
		_cooldown[idol] = 0
		_pending[idol] = -1
		_pending_age[idol] = 0
		_pending_slot[idol] = -1
		_flash_idol[idol] = 0
		_attackers[idol] = false
		_set_pose(idol, &"idle")
	set_box(EnemyTuning.COLOSSUS_BOX)


func _burst_origin() -> Vector2i:
	return Vector2i(get_mid_x(), get_floor_y() + EnemyTuning.BOSS_DROP_DY * 4)


func _on_defeated() -> void:
	_state = State.BROKEN
	visible = true
	for idol: int in 2:
		_role[idol] = Role.BROKEN
		_set_pose(idol, &"dead")
	_refresh_visual()


## The last hit point is gone: the last idol breaks, then the defeat.
func _on_lethal_hit() -> void:
	defeat(boss_drops)


func _ai_tick() -> void:
	_place_moon()
	if dead:
		return
	var hero: PlayerBase = _target_hero()
	if not fighting:
		_hold_pose()
		if _wakes_for_any(hero):
			start_fight()
		if not fighting:
			return
	if _state == State.DORMANT:
		_configure_form()
		_begin_idle()
	for idol: int in 2:
		if _cooldown[idol] > 0:
			_cooldown[idol] -= 1
		if _flash_idol[idol] > 0:
			_flash_idol[idol] -= 1
	_poll_hits()
	if dead:
		return
	_expire_pending()
	_touch_every()
	_timer += 1
	if _state == State.IDLE:
		_clock += 1
	match _state:
		State.IDLE:
			if _clock >= _idle_length():
				_begin_attack()
		State.SPIT:
			if _timer == EnemyTuning.COLOSSUS_SPIT_RELEASE_TICK:
				for idol: int in 2:
					if _attackers[idol]:
						_spit(idol)
			if _timer >= EnemyTuning.COLOSSUS_SPIT_TICKS:
				_end_attack(true)
		State.SLAM:
			if _timer == EnemyTuning.COLOSSUS_SLAM_RELEASE_TICK:
				for idol: int in 2:
					if _attackers[idol]:
						_drop_masonry(idol)
			if _timer >= EnemyTuning.COLOSSUS_SLAM_TICKS:
				_end_attack(true)
		State.RAGE:
			if _timer == EnemyTuning.COLOSSUS_RAGE_ROCK_TICK:
				for idol: int in 2:
					if _rage_spitter(idol):
						_spit(idol)
			elif _timer == EnemyTuning.COLOSSUS_RAGE_DROP_TICK_A or _timer == EnemyTuning.COLOSSUS_RAGE_DROP_TICK_B:
				for idol: int in 2:
					if _rage_dropper(idol):
						_drop_masonry(idol)
			if _timer >= (COOP_RAGE_TICKS if _coop else EnemyTuning.COLOSSUS_RAGE_TICKS):
				_end_rage()
	_update_poses()


## Start the fight (BossBase.start_fight; the arena zone or the wake rule): the form and the hits per idol are fixed
## first, so the energy bar opens with the right size.
func start_fight() -> void:
	if not fighting and not dead and _state == State.DORMANT:
		_configure_form()
	super.start_fight()


# =================================================================================================================
# Hits
# =================================================================================================================

## Weapons against both heads, Moon first: every hero's thrown weapons (newest first), then every club box in contact
## order (BossBase.poll_weapon_hit order, with a cooldown per idol). A hit on a closed head (asleep, raging, no hero on
## its half in co-op) glances off: consumed, a clank and a spark, no damage and no pogo.
func _poll_hits() -> void:
	var level: LevelBase = Game.level
	if level == null:
		return
	for idol: int in 2:
		if _role[idol] == Role.BROKEN:
			continue
		var head: Rect2i = get_head_rect(idol)
		var open: bool = jaws_open(idol)
		var projectiles: Array[SimEntity] = level.get_kind(Defs.Kind.HERO_PROJECTILE)
		var hit_slot: int = -1
		var hit_hero: PlayerBase = null
		for i: int in range(projectiles.size() - 1, -1, -1):
			var projectile: ProjectileBase = projectiles[i] as ProjectileBase
			if projectile == null or projectile.spent or not Overlap.rects(projectile.get_box(), head):
				continue
			projectile.consume()
			if not open:
				_glance_at(level, head.get_center())
			elif _cooldown[idol] == 0:
				hit_slot = projectile.owner_slot
			break
		if hit_slot < 0:
			for hero: PlayerBase in level.contact_order():
				if hero.club_box_active and Overlap.rects(hero.club_box, head):
					if not open:
						_glance_at(level, hero.club_box.intersection(head).get_center())
						break
					if _cooldown[idol] > 0:
						break
					hero.notify_weapon_hit()
					hit_slot = hero.slot
					hit_hero = hero
					break
		if hit_slot < 0:
			continue
		_note_hitter(level, hit_slot)
		if hit_hero != null:
			level.spawn_fx(&"fx/hit_stars", hit_hero.club_box.intersection(head).get_center())
		if _coop:
			_coop_hit(idol, hit_slot)
		else:
			_count_hit(idol)
		if dead:
			return


## Solo: the hit counts 1 on this idol.
func _count_hit(idol: int) -> void:
	_cooldown[idol] = HURT_TICKS
	_crack(idol)
	if dead:
		return
	_counted += 1
	if _counted % RAGE_EVERY == 0:
		_rage_due = true
	if _role[idol] == Role.BROKEN:
		_wake_survivor()


## Co-op: a hit on open jaws waits for its twin; a hit on the twin within the window, by a hero of another slot (G34),
## while both jaws are open (a hero who counts on each half), cracks both. The same hero's hit on the twin (his throw
## and his own strike) only renews his own wait.
func _coop_hit(idol: int, slot: int) -> void:
	var twin: int = 1 - idol
	_cooldown[idol] = PENDING_RENEW_TICKS
	var now: int = Sim.total_ticks
	if _role[twin] == Role.BROKEN:
		# The twin is gone (both crack together, so this is only a level that set different hp): it counts alone.
		_cooldown[idol] = HURT_TICKS
		_crack(idol)
		return
	if _pending[twin] >= 0 and now - _pending[twin] < _window() and jaws_open(twin) and _pending_slot[twin] != slot:
		_pending[idol] = -1
		_pending[twin] = -1
		_pending_slot[idol] = -1
		_pending_slot[twin] = -1
		_cooldown[idol] = HURT_TICKS
		_cooldown[twin] = HURT_TICKS
		_shut = true
		_shut_tick = now
		_crack(idol)
		if dead:
			return
		_crack(twin)
		if dead:
			return
		_counted += 1
		if _counted % COOP_RAGE_EVERY == 0:
			_rage_due = true
		return
	_pending[idol] = now
	_pending_age[idol] = 0
	_pending_slot[idol] = slot
	_flash_idol[idol] = EnemyTuning.FLASH_TICKS
	Audio.play_sfx(Sfx.COUNT_IN)


## One counted hit on an idol: its hits and the boss's hit points drop, it roars in the hurt pose; at 0 it breaks.
func _crack(idol: int) -> void:
	_hits_left[idol] = maxi(_hits_left[idol] - 1, 0)
	_hurt[idol] = HURT_TICKS
	_flash_idol[idol] = EnemyTuning.FLASH_TICKS
	Audio.play_sfx(Sfx.BOSS_ROAR)
	if _hits_left[idol] == 0:
		_role[idol] = Role.BROKEN
		_hurt[idol] = 0
		_set_pose(idol, &"dead")
		if Game.level != null:
			Game.level.request_shake(EnemyTuning.BOSS_STOMP_SHAKE)
	apply_boss_hit(1)


## A pending co-op hit fades when its window ran out (the twin was not hit in time) or when its idol closed (nobody
## on its half any more): a twin crack needs both jaws open at once, so one hero who crosses the middle cannot do it.
func _expire_pending() -> void:
	if not _coop:
		return
	for idol: int in 2:
		if _pending[idol] < 0:
			continue
		_pending_age[idol] += 1
		if Sim.total_ticks - _pending[idol] >= _window() or not is_open(idol):
			_pending[idol] = -1
			_pending_slot[idol] = -1


func _window() -> int:
	return PartyTuning.window_ticks(Game.difficulty)


## An awake idol broke: the other wakes (and also takes the slam steps from now on).
func _wake_survivor() -> void:
	for idol: int in 2:
		if _role[idol] == Role.ASLEEP:
			_role[idol] = Role.AWAKE


func _glance_at(level: LevelBase, point: Vector2i) -> void:
	if Sim.total_ticks - _glance_tick_idol < GLANCE_TICKS:
		return
	_glance_tick_idol = Sim.total_ticks
	Audio.play_sfx(Sfx.CLUB_HIT_SCENERY)
	level.spawn_fx(&"fx/hit_stars", point)


# =================================================================================================================
# The shared attack loop
# =================================================================================================================

func _begin_idle() -> void:
	_state = State.IDLE
	_timer = 0
	_clock = 0
	for idol: int in 2:
		_attackers[idol] = false


func _begin_attack() -> void:
	_timer = 0
	var spit: bool = LOOP[_step] == Attack.SPIT
	_state = State.SPIT if spit else State.SLAM
	for idol: int in 2:
		_attackers[idol] = _takes_step(idol, spit)
		if _attackers[idol]:
			_hurt[idol] = 0
			_set_pose(idol, &"spit" if spit else &"slam")
	if spit:
		_spit_began = Sim.total_ticks
		Audio.play_sfx(Sfx.BOSS_SPIT)


## Does this idol take the loop step? Solo: the awake idol spits, the asleep one slams (a lone survivor does both).
## Co-op: every idol with a hero on its half (awake) spits and slams.
func _takes_step(idol: int, spit: bool) -> bool:
	if _role[idol] == Role.BROKEN:
		return false
	if _coop:
		return _side_hero(idol, false) != null
	if spit:
		return _role[idol] == Role.AWAKE
	return _role[idol] == Role.ASLEEP or _role[1 - idol] == Role.BROKEN


func _end_attack(advance: bool) -> void:
	if _state == State.SPIT and _spit_began - _shut_tick >= COOP_SHUT_MIN_TICKS:
		_shut = false
	if advance:
		_step = (_step + 1) % LOOP.size()
	for idol: int in 2:
		_attackers[idol] = false
	if _rage_due:
		_begin_rage()
	else:
		_begin_idle()


func _begin_rage() -> void:
	_rage_due = false
	_state = State.RAGE
	_timer = 0
	for idol: int in 2:
		_hurt[idol] = 0
		if _role[idol] != Role.BROKEN:
			_set_pose(idol, &"rage")
	Audio.play_sfx(Sfx.BOSS_ROAR)


## The rage is over: the roles swap (solo) or the targets cross over (co-op); a fresh breath.
func _end_rage() -> void:
	if _coop:
		_crossed = not _crossed
	elif _role[MOON] != Role.BROKEN and _role[SUN] != Role.BROKEN:
		var moon: int = _role[MOON]
		_role[MOON] = _role[SUN]
		_role[SUN] = moon
	_begin_idle()


func _rage_spitter(idol: int) -> bool:
	if _role[idol] == Role.BROKEN:
		return false
	if _coop:
		return true
	return _role[idol] == Role.AWAKE


func _rage_dropper(idol: int) -> bool:
	if _role[idol] == Role.BROKEN:
		return false
	if _coop:
		return true
	return _role[idol] == Role.ASLEEP or _role[1 - idol] == Role.BROKEN


## Idle pause before the next attack: the Colossus values shortened by the phase (by the share of hits left).
func _idle_length() -> int:
	var left: int = _hits_left[MOON] + _hits_left[SUN]
	var total: int = maxi(_per_idol * 2, 1)
	var phase: int = 0
	if left * 3 <= total:
		phase = 2
	elif left * 3 <= total * 2:
		phase = 1
	return EnemyTuning.COLOSSUS_IDLE_TICKS[_step] * EnemyTuning.COLOSSUS_PHASE_PERCENT[phase] / 100


## A rock from this idol's open jaws toward the middle of the room. Solo: a random speed (the Colossus rule); co-op:
## aimed at the idol's target (its half's hero, the far half's after an odd number of rages).
func _spit(idol: int) -> void:
	var mouth: Vector2i = get_mouth(idol)
	var away: int = 1 if idol == MOON else -1
	var speed: int = EnemyTuning.ROCK_XVEL_MIN \
			+ Sim.rng.next_int(EnemyTuning.ROCK_XVEL_STEPS) * EnemyTuning.ROCK_XVEL_STEP
	if _coop:
		var target: PlayerBase = _target_of(idol)
		if target != null:
			speed = _aimed_speed(absi(target.sim_pos.x - mouth.x))
	_spawn_optional(ROCK_ID, mouth, {"xvel": away * speed, "yvel": 0, "skin": ROCK_SKINS[idol]})
	Audio.play_sfx(Sfx.BOSS_SPIT)


## The rock speed (a multiple of ROCK_XVEL_STEP within the Colossus range) whose first landing is about `dx` px out.
static func _aimed_speed(dx: int) -> int:
	var speed: int = dx * 16 / ROCK_FALL_TICKS
	speed = (speed / EnemyTuning.ROCK_XVEL_STEP) * EnemyTuning.ROCK_XVEL_STEP
	var top: int = EnemyTuning.ROCK_XVEL_MIN + (EnemyTuning.ROCK_XVEL_STEPS - 1) * EnemyTuning.ROCK_XVEL_STEP
	return clampi(speed, EnemyTuning.ROCK_XVEL_MIN, top)


## A sandstone block under the ceiling over this idol's target (the stalactite rules: a 14-tick rattle, then it falls).
func _drop_masonry(idol: int) -> void:
	var room: Rect2i = _room()
	var low: int = get_body_rect(MOON).end.x + EnemyTuning.COLOSSUS_DROP_MARGIN
	var high: int = get_body_rect(SUN).position.x - EnemyTuning.COLOSSUS_DROP_MARGIN
	if high < low:
		return
	var target: PlayerBase = _target_of(idol)
	var x: int = Sim.rng.range_int(low, high) if target == null else clampi(target.sim_pos.x, low, high)
	# The ceiling over the target's feet (on the altar too: the altar is no ceiling of a hero standing on it).
	var from_y: int = get_floor_y() if target == null else mini(target.sim_pos.y, get_floor_y())
	var top: int = _ceiling_y(x, room.position.y, from_y)
	_spawn_optional(MASONRY_ID, Vector2i(x, top + EnemyTuning.STALACTITE_BOX.y), {"skin": MASONRY_SKIN})
	Audio.play_sfx(Sfx.QUAKE)


## The hero an idol aims at: solo the target hero; co-op the hero on its half (the far half when crossed).
func _target_of(idol: int) -> PlayerBase:
	if not _coop:
		return _target_hero()
	return _side_hero(idol, _crossed)


## Co-op: the hero who COUNTS (PlayerBase.counts_for_coop: hatched and not idle, G33) whose feet are on this idol's
## half (`far`: on the other half); the nearer to the idol first. It wakes the idol (is_open, _takes_step) and is its
## target (_target_of): an egg or a dozing partner on a half wakes nothing and is spat at by nobody.
func _side_hero(idol: int, far: bool) -> PlayerBase:
	var level: LevelBase = Game.level
	if level == null:
		return null
	var mid: int = get_mid_x()
	var side: int = idol if not far else 1 - idol
	var best: PlayerBase = null
	var best_dx: int = 0
	var face: int = get_body_rect(side).end.x if side == MOON else get_body_rect(side).position.x
	for hero: PlayerBase in level.contact_order():
		if not hero.counts_for_coop():
			continue
		var on_moon_half: bool = hero.sim_pos.x < mid
		if on_moon_half != (side == MOON):
			continue
		var dx: int = absi(hero.sim_pos.x - face)
		if best == null or dx < best_dx:
			best = hero
			best_dx = dx
	return best


# =================================================================================================================
# Bodies, wake rule, room
# =================================================================================================================

## Wake rule (BossBase._wakes_for_any): the hero is within COLOSSUS_WAKE_RANGE px of either idol's face and less than
## a screen height away.
func _wakes_for(hero: PlayerBase) -> bool:
	if absi(hero.sim_pos.y - sim_pos.y) >= Tuning.VIEW_H:
		return false
	return absi(hero.sim_pos.x - get_body_rect(SUN).position.x) < EnemyTuning.COLOSSUS_WAKE_RANGE \
			or absi(hero.sim_pos.x - get_body_rect(MOON).end.x) < EnemyTuning.COLOSSUS_WAKE_RANGE


## Both bodies against the heroes (the target hero in a party of one; every living hero of a party): one bone and the
## boss knock-back; a hero landing on top bounces (the head-bounce rule of B.0) and nobody is harmed.
func _touch_every() -> void:
	var level: LevelBase = Game.level
	if level == null:
		return
	var heroes: Array[PlayerBase] = []
	if level.hero_count() <= 1:
		var target: PlayerBase = _target_hero()
		if target != null:
			heroes.append(target)
	else:
		heroes = level.contact_order()
	for hero: PlayerBase in heroes:
		if hero.dead or hero.is_down() or hero.is_feasting():
			continue
		for idol: int in 2:
			if not _body_touches(idol, hero):
				continue
			if Overlap.stomp and hero.yvel >= 0 and not hero.is_gliding():
				var held: bool = (hero.input_flags & Defs.IN_UP) != 0
				hero.bounce(Tuning.BOSS_BOUNCE_YVEL_UP if held else Tuning.BOSS_BOUNCE_YVEL, Overlap.depth)
				Events.player_bounced.emit(self, 0)
				Events.hero_bounced.emit(hero, self, 0)
				break
			if not hero.is_immune() and touch_hero(hero) and idol == MOON:
				# The boss knock-back pushes away from the source: the Moon's body is on the hero's left.
				hero.xvel = absi(hero.xvel)
			break


## The body test of PHYSICS.md 2.2 between an idol and a hero (Overlap.test, the stomp flag for the hero). The Sun is
## tested as the Colossus is; the Moon in mirrored coordinates (x -> -x), so that its body meets a hero exactly as the
## Sun's meets his mirror image (the test's left-most-box rule is not symmetric).
func _body_touches(idol: int, hero: PlayerBase) -> bool:
	var box: Vector3i = EnemyTuning.COLOSSUS_BOX
	var pos: Vector2i = get_idol_pos(idol)
	if idol == SUN:
		return Overlap.test(hero.sim_pos.x, hero.sim_pos.y, hero.box_w, hero.box_h, hero.box_xo,
				pos.x, pos.y, box.x, box.y, box.z, false, hero.yvel, 1)
	return Overlap.test(-hero.sim_pos.x, hero.sim_pos.y, hero.box_w, hero.box_h, hero.box_w - hero.box_xo,
			-pos.x, pos.y, box.x, box.y, box.x, false, hero.yvel, 1)


## The Moon's feet point: 32 px inside the first wall to the left of the Sun that stands both on the floor-level row
## and at its head's height (a full-height wall: the 2-row altar block of DESIGN.md B.4 in the middle of the floor, or a
## solid ledge in front of the jaws, is not one), at the Sun's feet height, else mirrored in the room.
func _place_moon() -> void:
	if _moon_placed:
		return
	var level: LevelBase = Game.level
	if level == null:
		return
	_moon_placed = true
	var grid: TileGrid = level.grid
	var row: int = Tuning.to_cell(get_floor_y() - 1)
	var head_row: int = Tuning.to_cell(sim_pos.y + EnemyTuning.COLOSSUS_HEAD_IDLE.position.y)
	var col: int = Tuning.to_cell(sim_pos.x - EnemyTuning.COLOSSUS_BOX.x)
	var face: int = -1
	for i: int in WALL_SCAN_COLS:
		var c: int = col - i
		if c < 0:
			break
		if grid.side_at(c, row) == TileGrid.SIDE_WALL and grid.side_at(c, head_row) == TileGrid.SIDE_WALL:
			face = (c + 1) * Tuning.TILE
			break
	if face < 0:
		var room: Rect2i = _room()
		_moon_pos = Vector2i(room.position.x + room.end.x - sim_pos.x, sim_pos.y)
	else:
		_moon_pos = Vector2i(face - EnemyTuning.COLOSSUS_RIM_PX, sim_pos.y)
	if _moon_sprite != null:
		_moon_sprite.position = Vector2((_moon_pos - sim_pos) * Tuning.ART_SCALE)


## The co-op form (Twin Hit) in a co-op game of two heroes in a co-op file; solo otherwise. Sets the hits per idol.
func _configure_form() -> void:
	_coop = _coop_form_wanted()
	var per: int = _per_idol
	if _coop and not spawn_params.has("hp"):
		per = HITS_PER_IDOL_COOP
	_hits_left = [per, per]
	max_hp = per * 2
	hp = max_hp
	if _coop:
		_role = [Role.AWAKE, Role.AWAKE]
	else:
		_role = [Role.ASLEEP, Role.AWAKE]


## True in a co-op game (Game.mode COOP, two or more heroes in the level) on a co-op file (`kind = coop`).
static func _coop_form_wanted() -> bool:
	var level: LevelBase = Game.level
	return level != null and Game.mode == Defs.GameMode.COOP and level.hero_count() > 1 \
			and str(level.meta.get("kind", "")) == "coop"


## The fight room in logical px: the arena zone's rectangle, else the camera lock, else one base screen around the idols.
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
	return Rect2i(sim_pos.x - Tuning.VIEW_W, sim_pos.y - Tuning.VIEW_H, Tuning.VIEW_W, Tuning.VIEW_H)


## Bottom of the first ceiling above `from_y` (feet y) at x, not higher than `limit` (the Colossus rule; scanned from
## the target's feet, so the 2-row altar of B.4 is the floor of a hero on it, never the ceiling of the drop).
func _ceiling_y(x: int, limit: int, from_y: int) -> int:
	var grid: TileGrid = Game.level.grid
	var col: int = Tuning.to_cell(x)
	var row: int = Tuning.to_cell(from_y - 1)
	var top_row: int = Tuning.to_cell(limit)
	while row > top_row:
		row -= 1
		if grid.ceiling_at(col, row) != TileGrid.CEILING_NONE or grid.side_at(col, row) == TileGrid.SIDE_WALL:
			return (row + 1) * Tuning.TILE
	return maxi(limit, 0)


# =================================================================================================================
# Poses and pictures
# =================================================================================================================

func _set_pose(idol: int, role: StringName) -> void:
	if _pose[idol] == role:
		return
	_pose[idol] = role
	_pose_age[idol] = 0


## Keep each idol's pose in step with the brain: attack and rage poses, the hurt roar, idle; broken stays broken.
func _update_poses() -> void:
	for idol: int in 2:
		if _role[idol] == Role.BROKEN:
			_set_pose(idol, &"dead")
		elif _state == State.RAGE:
			_set_pose(idol, &"rage")
		elif _attackers[idol] and (_state == State.SPIT or _state == State.SLAM):
			_set_pose(idol, &"spit" if _state == State.SPIT else &"slam")
		elif _hurt[idol] > 0:
			_hurt[idol] -= 1
			_set_pose(idol, &"hurt")
		elif not jaws_open(idol) and _has_sleep(idol):
			_set_pose(idol, &"sleep")
		else:
			_set_pose(idol, &"idle")
		_pose_age[idol] += 1


## True when the idol's sheet has the grey-stone sleep frames (art-B's idol sheets; the shipped colossus has none).
func _has_sleep(idol: int) -> bool:
	var sheet: EnemySkin = _moon_skin if idol == MOON else _sun_skin
	return sheet != null and sheet.has_anim(&"sleep")


func _hold_pose() -> void:
	for idol: int in 2:
		if _role[idol] == Role.BROKEN:
			_set_pose(idol, &"dead")
		else:
			_set_pose(idol, &"idle")
		_pose_age[idol] += 1


func _build_moon_sprite() -> void:
	if _moon_sprite != null or _sprite == null:
		return
	_sun_skin = EnemySkin.find(skin)
	var moon_name: String = SKIN_MOON if EnemySkin.find(SKIN_MOON) != null else SKIN_FALLBACK
	_moon_skin = EnemySkin.find(moon_name)
	if _moon_skin == null:
		return
	_moon_sprite = Sprite2D.new()
	_moon_sprite.name = "MoonSprite"
	_moon_sprite.texture = load(_moon_skin.texture_path) as Texture2D
	_moon_sprite.centered = false
	_moon_sprite.hframes = _moon_skin.columns
	_moon_sprite.vframes = _moon_skin.rows
	if moon_name == SKIN_FALLBACK:
		# The colossus sheet mirrored: its pivot (the bottom-right corner of a cell) becomes the bottom-left corner.
		_moon_sprite.flip_h = true
		_moon_sprite.offset = Vector2(-(_moon_skin.cell.x - _moon_skin.pivot.x), -_moon_skin.pivot.y)
		_moon_sprite.self_modulate = TINT_MOON
	else:
		# art-B's idol_moon is drawn mirrored already (pivot at the bottom-left corner).
		_moon_sprite.offset = _moon_skin.sprite_offset()
	add_child(_moon_sprite)
	if skin == SKIN_FALLBACK:
		_sprite.self_modulate = TINT_SUN
	if _moon_placed:
		_moon_sprite.position = Vector2((_moon_pos - sim_pos) * Tuning.ART_SCALE)


func _refresh_visual() -> void:
	if _sprite == null:
		return
	if _sun_skin == null:
		_sun_skin = EnemySkin.find(skin)
	_show_idol(_sprite, _sun_skin, SUN)
	if _moon_sprite != null:
		_show_idol(_moon_sprite, _moon_skin, MOON)


func _show_idol(sprite: Sprite2D, sheet: EnemySkin, idol: int) -> void:
	if sheet == null:
		return
	var anim: Vector4i = sheet.anim(_pose[idol])
	var step: int = _pose_age[idol] / maxi(anim.z, 1)
	step = step % anim.y if anim.w != 0 else mini(step, anim.y - 1)
	var frame: int = clampi(anim.x + step, 0, sprite.hframes * sprite.vframes - 1)
	if sprite.frame != frame:
		sprite.frame = frame
	var lit: bool = (_flash_idol[idol] & EnemyTuning.FLASH_PERIOD_MASK) != 0
	sprite.modulate = FLASH_COLOR if lit else Color.WHITE
