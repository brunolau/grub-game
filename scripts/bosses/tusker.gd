class_name Tusker
extends BossBase
## `bosses/tusker` - Tusker, the Boar King (w5_l2b Tusker's Wallow; DESIGN.md B.1, GAMEPLAY.md 13.6). Owner: enemies-B
## (PLAN.md P2.2).
##
## A boar twice the hero's height in a walled pit with a mesa bank in each corner and a mud wallow (`:` tar floor) in
## the middle. Place it on the pit floor; `zones/arena` (or the hero coming within TUSKER_WAKE_RANGE px) starts the
## fight. The body (76 x 57, the sheet's box) costs a bone; landing on top always bounces the hero and harms nobody.
## Hit points (club 25, charged x4): Beginner 150, Expert 225; the co-op form 187 / 280 [R8] (`hp` overrides).
##
## Solo form, by phase (hit points left of the full bar):
##  1. Above 60 %: IDLE 44 ticks facing its target, PAW 22 ticks (the telegraph: dust and a snort), CHARGE at 96 v16.
##     Into a wall: it bounces back (RECOIL) and lies DIZZY 44 ticks. Across the wallow it wades at 32 v16; at the
##     wallow's centre it is STUCK 22 ticks, then wades out and charges on (once per charge).
##  2. 60 % down to 30 %: SQUEAL 14 ticks while it curls (the telegraph), then ROLL at 96 v16 as a ball, bouncing off
##     the walls in two arcs (yvel -128), then a HOP (yvel -192) whose landing shakes the screen (8: crouch to stand
##     firm); it uncurls DIZZY 33 ticks.
##  3. Below 30 % (red): phase 1 with idles of 22; every wall impact shakes 3 rocks loose over arena columns at least
##     2 apart (Sim.rng), each marked by a dust trickle 14 ticks before it falls (`projectiles/boss_rock`).
## Weak point: the head while RECOIL / DIZZY / STUCK; any other time hits on the head glance (the tusks during a
## charge, the ball while rolling). A lying boar (recoil, dizzy, stuck, dazed) is harmless to touch.
##
## Co-op form (`<id>_coop` files: meta `kind = coop`; tests force it with the parameter `form=coop`): it charges whoever
## hit it last (at first the nearest hero who counts); while it lies open (recoil, dizzy, stuck) it turns EVERY tick to
## face the nearer hero and its head glances: only a hero BEHIND it (his x on the side it turns away from; for a thrown
## weapon its thrower's x) can strike the leafy rump, once it lies on the ground (dizzy, stuck - not in the recoil
## hop, whose apex would lift the rump under the fight HUD, G35). Phase 3: its charges skid and turn 32 px before a
## wall (no impact, no rocks, no dizziness); a charge may still stick in the wallow (DESIGN.md G38: the rump from
## behind, a pair's opening). A Brace Wall (PHYSICS.md C.10: two crouching heroes within 16 px, both grounded) in the
## path of a charge stops it dead: DAZED 66 ticks with head and rump open to everybody; a lone croucher is trampled.
## IDLE rule (DESIGN.md G33 / G34): every "nearer hero" here is the nearer hero who COUNTS (PlayerBase.counts_for_coop:
## alive, hatched, not idle - LevelBase.nearest_coop_hero), the striker behind must count too, and the Brace Wall
## refuses an idle partner (PlayerBase.braces_with). A dozing partner parked anywhere is no bait: one player is always
## the nearer hero who counts, so he can never be behind it, and he can never brace alone - the single-hero search of
## tests/test_enemies_tusker.gd (with an egg and with an idle hatched partner placed around the boar) proves it.
## Targeting and harm still take any hatched hero (LevelBase.target_hero: a dozing hero is trampled like any other).
##
## Fairness (B.0, pinned by tests/test_enemies_tusker.gd): every attack shows itself 10+ ticks ahead; a hit never
## stops or lengthens a state (the clocks run through the flash: no stun-lock); BossBase.hit_cooldown (22) is shared by
## every hero. Parameters: `arena`, `hp`, `drops` [fire_starter], `form=coop|solo` [by the level kind].
##
## Numbers: the TUSKER_* constants below are this boss's tuning (PLAN.md rule 5: EnemyTuning once enemies-A adopts
## them; until then they stay here, ARCHITECTURE.md 1.2).

enum State { DORMANT, IDLE, PAW, CHARGE, STUCK, RECOIL, DIZZY, SQUEAL, ROLL, HOP, SKID, DAZED, DYING }

const ROCK_ID: StringName = &"projectiles/boss_rock"
const FX_DUST: StringName = &"fx/dust"
const SKIN_CALM: String = "tusker"
const SKIN_RAGE: String = "tusker_rage"
## "No wallow under this charge" (an x no level reaches).
const NO_WALLOW: int = -1073741824

# --- Tuning [D B.1] [G 13.6] (tune) ---------------------------------------------------------------------------------
const TUSKER_HP_BEGINNER: int = 150          ## 6 club hits
const TUSKER_HP_EXPERT: int = 225            ## 9 club hits
const TUSKER_COOP_HP_BEGINNER: int = 187     ## [R8] at most x1.25 of the solo form (rounded down)
const TUSKER_COOP_HP_EXPERT: int = 280       ## [R8]
const TUSKER_HP_PER_PIP: int = 25            ## one pip per club hit
const TUSKER_PHASE2_PERCENT: int = 60        ## phase 2 at or below 60 % of the full bar ...
const TUSKER_PHASE3_PERCENT: int = 30        ## ... phase 3 below 30 %
const TUSKER_WAKE_RANGE: int = 200           ## starts the fight by itself when a hero is this close (px) [own]
const TUSKER_WAKE_DY: int = 96
const TUSKER_IDLE_TICKS: int = 44            ## phase 1 idle between attacks
const TUSKER_IDLE_TICKS_RAGE: int = 22       ## phase 3
const TUSKER_PAW_TICKS: int = 22             ## the charge's telegraph (dust, snort)
const TUSKER_PAW_DUST_PERIOD: int = 6        ## a dust puff behind it every 6 ticks of pawing [own]
const TUSKER_CHARGE_XVEL: int = 96           ## v16 (6 px per tick)
const TUSKER_WALLOW_XVEL: int = 32           ## v16 in the mud (PHYSICS.md C.5: ground enemies at most 32 on `:`)
const TUSKER_CHARGE_MAX_TICKS: int = 160     ## a charge that meets no wall ends after this long [own]
const TUSKER_STUCK_TICKS: int = 22           ## stuck at the wallow's centre, head open
const TUSKER_RECOIL_XVEL: int = 48           ## v16: it bounces back off the wall it ran into ... [own]
const TUSKER_RECOIL_YVEL: int = -96          ## ... in a short hop (21 px, about 39 px back) [own]
const TUSKER_DIZZY_TICKS: int = 44           ## after a wall impact
const TUSKER_ROLL_DIZZY_TICKS: int = 33      ## after the Spin Ball's hop
const TUSKER_SQUEAL_TICKS: int = 14          ## the Spin Ball's telegraph (squeal, then the curl)
const TUSKER_SQUEAL_FRAMES_TICKS: int = 6    ## the squeal frames show first, then the curl [own]
const TUSKER_ROLL_XVEL: int = 96             ## v16
const TUSKER_ROLL_ARC_YVEL: int = -128       ## v16 at each wall: an arc of 36 px
const TUSKER_ROLL_ARCS: int = 2              ## two arcs, then the hop
const TUSKER_ROLL_MAX_TICKS: int = 220       ## a roll that meets no wall hops after this long [own]
const TUSKER_HOP_YVEL: int = -192            ## v16: the high hop (78 px)
const TUSKER_HOP_SHAKE: int = 8              ## its landing shakes the screen (crouch to stand firm)
const TUSKER_SLAM_TICKS: int = 4             ## the landing burst pose before the dizzy frames [own]
const TUSKER_IMPACT_SHAKE: int = 7           ## a wall impact (EnemyTuning.BOSS_STOMP_SHAKE)
const TUSKER_ROCKS: int = 3                  ## phase 3: rocks shaken loose per wall impact ...
const TUSKER_ROCK_WARN_TICKS: int = 14       ## ... each marked by a dust trickle this long before it falls ...
const TUSKER_ROCK_COL_GAP: int = 2           ## ... over arena columns at least this far apart
const TUSKER_ROCK_TRIES: int = 24            ## column draws per rock before it is given up [own]
const TUSKER_COOP_SKID_PX: int = 32          ## co-op phase 3: the charge skids and turns this far before a wall
const TUSKER_SKID_DECEL: int = 12            ## v16 per tick while skidding (96 -> 0 in 8 ticks) [own]
const TUSKER_BRACE_DAZE_TICKS: int = 66      ## co-op: a Brace Wall dazes it this long [R24]
const TUSKER_DYING_TICKS: int = 44           ## on its back before the bonus burst [own]
## Body box of the ball (curl, roll, hop): the ball frames are about 96 x 88 art px. [own]
const TUSKER_BALL_BOX: Vector3i = Vector3i(48, 44, 24)
## Weak points relative to the feet point, facing right (art-B's zones_logical, world5_registry.json; mirrored when
## facing left): the head (solo; the tusks around it glance) and the leafy rump (the co-op weak point).
const TUSKER_HEAD: Rect2i = Rect2i(8, -37, 28, 26)
const TUSKER_RUMP: Rect2i = Rect2i(-39, -43, 23, 40)

## True for the co-op form (DESIGN.md B.1): set from the level kind or the `form` parameter.
var coop_form: bool = false

var _state: int = State.DORMANT
var _timer: int = 0
## The direction of the running charge or roll (+1 right, -1 left).
var _dir: int = 1
## Wall arcs of the running roll.
var _arcs: int = 0
## True once the running charge was stuck in the wallow (it gets stuck once per charge).
var _stuck_done: bool = false
## x of the centre of the wallow the running charge is crossing (NO_WALLOW = none).
var _wallow_centre: int = NO_WALLOW
## Length of the running dizzy.
var _dizzy_len: int = TUSKER_DIZZY_TICKS
## True while airborne (recoil, roll arcs, hop) since the last landing.
var _airborne: bool = false
## Rocks about to fall: (x, ceiling y, ticks left).
var _pending: Array[Vector3i] = []
## Attacks started so far (paws and squeals; tests and tools).
var attacks: int = 0


func _default_skin() -> String:
	return SKIN_CALM


func _apply_params(params: Dictionary) -> void:
	coop_form = _coop_form_of(params)
	var expert: bool = Game.difficulty == Defs.Difficulty.EXPERT
	if coop_form:
		max_hp = TUSKER_COOP_HP_EXPERT if expert else TUSKER_COOP_HP_BEGINNER
	else:
		max_hp = TUSKER_HP_EXPERT if expert else TUSKER_HP_BEGINNER
	hp_per_pip = TUSKER_HP_PER_PIP
	music = Sfx.MUSIC_BOSS_TUSKER
	boss_drops = [&"fire_starter"]
	super._apply_params(params)


## The co-op form: the parameter `form=coop|solo`, else a co-op level file (meta `kind = coop`). Shared rule of the
## enemies-B bosses (Mangrove and Squid call it too).
static func _coop_form_of(params: Dictionary) -> bool:
	var form: String = str(params.get("form", ""))
	if form == "coop":
		return true
	if form == "solo":
		return false
	var level: LevelBase = Game.level
	return level != null and str(level.meta.get("kind", "")) == LevelText.KIND_COOP


# =================================================================================================================
# Queries (tests, tools, the HUD)
# =================================================================================================================

## Current state (State).
func get_state() -> int:
	return _state


## Ticks spent in the current state.
func get_state_ticks() -> int:
	return _timer


## Phase 1, 2 or 3 by the hit points left.
func get_phase() -> int:
	if hp * 100 < max_hp * TUSKER_PHASE3_PERCENT:
		return 3
	if hp * 100 <= max_hp * TUSKER_PHASE2_PERCENT:
		return 2
	return 1


## True while it lies open (recoil, dizzy, stuck, dazed): the only time a hit can count.
func is_open() -> bool:
	return _state == State.RECOIL or _state == State.DIZZY or _state == State.STUCK or _state == State.DAZED


## True while its body can hurt a hero (everything but lying open, dying and dormant).
func is_dangerous() -> bool:
	return fighting and not dead and not is_open() and _state != State.DYING and _state != State.DORMANT


## The head as a weak point this tick (logical px): while a hit on it can count - lying open in the solo form, dazed by
## a Brace Wall in the co-op form -, else empty (the contract of Hud.weak_point_rects and the G35 route checks: an
## empty rect cannot be struck now). [method get_head_box] is the head whatever it does.
func get_head_rect() -> Rect2i:
	if is_open() and (not coop_form or _state == State.DAZED):
		return get_head_box()
	return Rect2i()


## The leafy rump as a weak point this tick (logical px): while it lies open ON THE GROUND in the co-op form (dizzy,
## stuck, dazed - not in the recoil hop), else empty (as [method get_head_rect]).
func get_rump_rect() -> Rect2i:
	if coop_form and is_open() and _state != State.RECOIL:
		return get_rump_box()
	return Rect2i()


## The head's box this tick, open or not (logical px; the tusks glance on it while it is closed).
func get_head_box() -> Rect2i:
	return _part(TUSKER_HEAD)


## The leafy rump's box this tick, open or not (logical px).
func get_rump_box() -> Rect2i:
	return _part(TUSKER_RUMP)


## Rocks waiting to fall: (x, ceiling y, ticks left).
func pending_rocks() -> Array[Vector3i]:
	return _pending.duplicate()


# =================================================================================================================
# Life cycle
# =================================================================================================================

func _on_reset() -> void:
	_state = State.DORMANT
	_timer = 0
	_dir = facing
	_arcs = 0
	_stuck_done = false
	_wallow_centre = NO_WALLOW
	_dizzy_len = TUSKER_DIZZY_TICKS
	_airborne = false
	_pending.clear()
	attacks = 0
	if skin != SKIN_CALM:
		_apply_skin(SKIN_CALM)
	_body_box()
	queue_redraw()


func _on_lethal_hit() -> void:
	_set_state(State.DYING)
	xvel = 0
	_pending.clear()
	_body_box()
	_play(&"dead", true)
	Audio.play_sfx(Sfx.BOSS_ROAR)
	queue_redraw()


func _on_defeated() -> void:
	# It stays on its back where it fell.
	visible = true
	_play(&"dead", true)


func _ai_tick() -> void:
	if dead:
		_play(&"dead")
		return
	if _state == State.DYING:
		_ground_still()
		if _timer >= TUSKER_DYING_TICKS:
			defeat(boss_drops)
		_timer += 1
		return
	var target: PlayerBase = _target_hero()
	if not fighting:
		_ground_still()
		_play(&"idle")
		if _wakes_for_any(target):
			start_fight()
		if not fighting:
			return
	if _state == State.DORMANT:
		# The first idle starts on this tick with its clock at 0, like every state entered on a tick.
		_begin_idle()
	else:
		_timer += 1
	_tick_rocks()
	if coop_form and is_open() and _state != State.DAZED:
		_face_nearer()
	var power: int = _poll_hits()
	if power > 0:
		apply_boss_hit(power)
		if dead or _state == State.DYING:
			return
	match _state:
		State.IDLE:
			_idle_tick(target)
		State.PAW:
			_paw_tick()
		State.CHARGE:
			_charge_tick()
		State.STUCK:
			_ground_still()
			_play(&"dizzy")
			if _timer >= TUSKER_STUCK_TICKS:
				# Wades out and charges on.
				_stuck_done = true
				_set_state(State.CHARGE)
		State.RECOIL:
			_recoil_tick()
		State.DIZZY:
			_ground_still()
			_play(&"slam" if _timer <= TUSKER_SLAM_TICKS and _dizzy_len == TUSKER_ROLL_DIZZY_TICKS else &"dizzy")
			if _timer >= _dizzy_len:
				_begin_idle()
		State.SQUEAL:
			_ground_still()
			_play(&"squeal" if _timer <= TUSKER_SQUEAL_FRAMES_TICKS else &"curl")
			if _timer >= TUSKER_SQUEAL_TICKS:
				_begin_roll()
		State.ROLL:
			_roll_tick()
		State.HOP:
			_hop_tick()
		State.SKID:
			_skid_tick()
		State.DAZED:
			_ground_still()
			_play(&"dizzy")
			if _timer >= TUSKER_BRACE_DAZE_TICKS:
				_begin_idle()
	_contact_every()


# =================================================================================================================
# States
# =================================================================================================================

func _set_state(state: int) -> void:
	_state = state
	_timer = 0


func _begin_idle() -> void:
	_set_state(State.IDLE)
	xvel = 0
	_body_box()
	var rage: bool = get_phase() == 3
	if rage and skin != SKIN_RAGE:
		_apply_skin(SKIN_RAGE)
	_body_box()
	_play(&"idle", true)


func _idle_tick(target: PlayerBase) -> void:
	_ground_still()
	_play(&"idle")
	var aim: PlayerBase = _charge_target(target)
	if aim != null:
		facing = _dir_to(aim)
	var length: int = TUSKER_IDLE_TICKS_RAGE if get_phase() == 3 else TUSKER_IDLE_TICKS
	if _timer < length or aim == null:
		return
	attacks += 1
	if get_phase() == 2:
		_set_state(State.SQUEAL)
		_play(&"squeal", true)
		Audio.play_sfx(Sfx.ENEMY_VOICE)
	else:
		_set_state(State.PAW)
		_play(&"paw", true)
		Audio.play_sfx(Sfx.ENEMY_VOICE)


func _paw_tick() -> void:
	_ground_still()
	_play(&"paw")
	if _timer % TUSKER_PAW_DUST_PERIOD == 1:
		_spawn_optional(FX_DUST, sim_pos + Vector2i(-facing * (box_w >> 2), 0), {"dir": facing})
	if _timer >= TUSKER_PAW_TICKS:
		_dir = facing
		_stuck_done = false
		_wallow_centre = NO_WALLOW
		_set_state(State.CHARGE)
		_play(&"charge", true)
		Audio.play_sfx(Sfx.BOSS_ROAR)


func _charge_tick() -> void:
	_play(&"charge")
	facing = _dir
	var grid: TileGrid = Game.level.grid
	var in_mud: bool = _on_tar(grid)
	if in_mud:
		if _wallow_centre == NO_WALLOW:
			_wallow_centre = _wallow_centre_x(grid)
			# Stuck only on the way into the middle: a charge that starts at or past the centre wades out.
			_stuck_done = _stuck_done or signi(_wallow_centre - sim_pos.x) != _dir
		if not _stuck_done and _crossed(_wallow_centre):
			xvel = 0
			_set_state(State.STUCK)
			_play(&"dizzy", true)
			Audio.play_sfx(Sfx.TAR_GLUG)
			return
	var speed: int = TUSKER_WALLOW_XVEL if in_mud else TUSKER_CHARGE_XVEL
	xvel = speed * _dir
	if coop_form and get_phase() == 3 and _wall_within(grid, TUSKER_COOP_SKID_PX):
		_set_state(State.SKID)
		_play(&"walk", true)
		Audio.play_sfx(Sfx.SKID_ICE)
		return
	if _wall_next(grid):
		_impact()
		return
	_ground_step(false, false)
	if _timer >= TUSKER_CHARGE_MAX_TICKS:
		_begin_idle()


func _impact() -> void:
	var level: LevelBase = Game.level
	_snap_to_wall(level.grid)
	level.request_shake(TUSKER_IMPACT_SHAKE)
	Audio.play_sfx(Sfx.QUAKE)
	Audio.play_sfx(Sfx.IMPACT)
	if not coop_form and get_phase() == 3:
		_shake_rocks_loose()
	xvel = -_dir * TUSKER_RECOIL_XVEL
	yvel = TUSKER_RECOIL_YVEL
	_grounded = false
	_airborne = true
	_dizzy_len = TUSKER_DIZZY_TICKS
	_set_state(State.RECOIL)
	_play(&"flash", true)


func _recoil_tick() -> void:
	_play(&"flash")
	if not coop_form:
		facing = _dir
	var grid: TileGrid = Game.level.grid
	if _wall_next(grid):
		xvel = 0
	_ground_step(false, false)
	if _grounded and _timer > 1:
		xvel = 0
		_airborne = false
		_set_state(State.DIZZY)
		_play(&"dizzy", true)


func _begin_roll() -> void:
	_dir = facing
	_arcs = 0
	_set_state(State.ROLL)
	set_box(TUSKER_BALL_BOX)
	xvel = TUSKER_ROLL_XVEL * _dir
	_play(&"roll", true)
	Audio.play_sfx(Sfx.CURL)


func _roll_tick() -> void:
	_play(&"roll")
	facing = _dir
	var grid: TileGrid = Game.level.grid
	if _grounded or not _airborne:
		xvel = (TUSKER_WALLOW_XVEL if _on_tar(grid) else TUSKER_ROLL_XVEL) * _dir
	if _wall_next(grid):
		_snap_to_wall(grid)
		_dir = -_dir
		facing = _dir
		xvel = TUSKER_ROLL_XVEL * _dir
		yvel = TUSKER_ROLL_ARC_YVEL
		_grounded = false
		_airborne = true
		_arcs += 1
		Game.level.request_shake(EnemyTuning.BOSS_BOB_SHAKE)
		Audio.play_sfx(Sfx.IMPACT)
		return
	_ground_step(false, false)
	if _grounded and _airborne:
		_airborne = false
		if _arcs >= TUSKER_ROLL_ARCS:
			_begin_hop()
			return
	if _timer >= TUSKER_ROLL_MAX_TICKS and _grounded:
		_begin_hop()


func _begin_hop() -> void:
	_set_state(State.HOP)
	xvel = 0
	yvel = TUSKER_HOP_YVEL
	_grounded = false
	_airborne = true
	_play(&"spin", true)
	Audio.play_sfx(Sfx.JUMP)


func _hop_tick() -> void:
	_play(&"spin")
	_ground_step(false, false)
	if _grounded and _timer > 1:
		_airborne = false
		Game.level.request_shake(TUSKER_HOP_SHAKE)
		Audio.play_sfx(Sfx.QUAKE)
		_body_box()
		_dizzy_len = TUSKER_ROLL_DIZZY_TICKS
		_set_state(State.DIZZY)
		_play(&"slam", true)


func _skid_tick() -> void:
	_play(&"walk")
	var grid: TileGrid = Game.level.grid
	var speed: int = maxi(absi(xvel) - TUSKER_SKID_DECEL, 0)
	xvel = speed * _dir
	if _wall_next(grid):
		xvel = 0
	_ground_step(false, false)
	if xvel == 0:
		_dir = -_dir
		facing = _dir
		_begin_idle()


# =================================================================================================================
# Hits
# =================================================================================================================

## BossBase.poll_weapon_hit with the co-op rule: the weak points this tick and who may strike them. Thrown weapons
## (newest first), then every hero's club box in contact order; a box on a weak point it may not strike, or on the
## armoured head, glances (a clank and a spark, no damage, no pogo; a thrown weapon is used up). One call per tick:
## it runs the hit cooldown and the glance clock.
func _poll_hits() -> int:
	if hit_cooldown > 0:
		hit_cooldown -= 1
	if _glance_ticks > 0:
		_glance_ticks -= 1
	var level: LevelBase = Game.level
	if level == null or dead or not fighting:
		return 0
	var parts: Array[Rect2i] = []
	var behind_only: bool = false
	if is_open():
		if _state == State.DAZED:
			parts = [get_head_box(), get_rump_box()]
		elif coop_form:
			# The rump counts once it lies on the ground (B.1: "while dizzy"; stuck too) - not in the recoil hop, whose
			# apex would lift it into the fight HUD's band (G35; 5-2b's arena).
			if _state != State.RECOIL:
				parts = [get_rump_box()]
			behind_only = true
		else:
			parts = [get_head_box()]
	var armour: Rect2i = get_box() if _state == State.ROLL or _state == State.HOP else get_head_box()
	var projectiles: Array[SimEntity] = level.get_kind(Defs.Kind.HERO_PROJECTILE)
	for i: int in range(projectiles.size() - 1, -1, -1):
		var projectile: ProjectileBase = projectiles[i] as ProjectileBase
		if projectile == null or projectile.spent:
			continue
		var box: Rect2i = projectile.get_box()
		var on_part: bool = _touches_any(box, parts)
		if on_part and (not behind_only or _is_behind(level.get_hero(projectile.owner_slot))):
			projectile.consume()
			if hit_cooldown > 0:
				return 0
			_note_hitter(level, projectile.owner_slot)
			return projectile.power
		if on_part or (not is_open() and Overlap.rects(box, armour)) or (behind_only and Overlap.rects(box, armour)):
			projectile.consume()
			_clank(level, box.get_center())
	for hero: PlayerBase in level.contact_order():
		if not hero.club_box_active:
			continue
		var on_part: bool = _touches_any(hero.club_box, parts)
		if on_part and (not behind_only or _is_behind(hero)):
			if hit_cooldown > 0:
				return 0
			hero.notify_weapon_hit()
			_note_hitter(level, hero.slot)
			return hero.club_power
		if on_part:
			_glance(level, hero, hero.club_box)
		elif (not is_open() or behind_only) and Overlap.rects(hero.club_box, armour):
			_glance(level, hero, armour)
	return 0


static func _touches_any(box: Rect2i, parts: Array[Rect2i]) -> bool:
	for part: Rect2i in parts:
		if Overlap.rects(box, part):
			return true
	return false


## True when `hero` stands behind it: his x on the side it faces away from, at least EnemyTuning.FRONT_DX px from its
## feet point (the shell rule of GAMEPLAY.md 13.9.5); he must count for the co-op rules (G33: alive, hatched, not idle).
func _is_behind(hero: PlayerBase) -> bool:
	if hero == null or not is_instance_valid(hero) or not hero.counts_for_coop():
		return false
	var dx: int = hero.sim_pos.x - sim_pos.x
	return absi(dx) >= EnemyTuning.FRONT_DX and signi(dx) == -facing


func _clank(level: LevelBase, at: Vector2i) -> void:
	if _glance_ticks > 0:
		return
	_glance_ticks = GLANCE_TICKS
	Audio.play_sfx(Sfx.CLUB_HIT_SCENERY)
	level.spawn_fx(&"fx/hit_stars", at)


# =================================================================================================================
# Contact
# =================================================================================================================

## Body against every hero in contact order (1.0 idiom: a party of one tests the target hero): a landing on top
## bounces him; a co-op charge into a braced pair stops dead; otherwise the body costs a bone unless it lies open.
func _contact_every() -> void:
	var level: LevelBase = Game.level
	if level == null:
		return
	for hero: PlayerBase in level.contact_order():
		if hero.dead or hero.is_down():
			continue
		_contact(hero)


func _contact(hero: PlayerBase) -> void:
	if not Overlap.body(hero, self, hero):
		return
	if Overlap.stomp and hero.yvel >= 0 and not hero.is_gliding():
		var held: bool = (hero.input_flags & Defs.IN_UP) != 0
		hero.bounce(Tuning.BOSS_BOUNCE_YVEL_UP if held else Tuning.BOSS_BOUNCE_YVEL, Overlap.depth)
		Events.player_bounced.emit(self, 0)
		Events.hero_bounced.emit(hero, self, 0)
		return
	if coop_form and (_state == State.CHARGE or _state == State.SKID) and hero.brace_partner() != null:
		_brace()
		return
	if not is_dangerous() or hero.is_immune() or hero.is_feasting():
		return
	touch_hero(hero)


## Brace Wall (PHYSICS.md C.10, co-op form): stopped dead, dazed TUSKER_BRACE_DAZE_TICKS, head and rump open.
func _brace() -> void:
	xvel = 0
	_set_state(State.DAZED)
	_play(&"dizzy", true)
	Audio.play_sfx(Sfx.BRACE)
	if Game.level != null:
		Game.level.request_shake(EnemyTuning.BOSS_BOB_SHAKE)


# =================================================================================================================
# Rocks (phase 3, solo form)
# =================================================================================================================

func _shake_rocks_loose() -> void:
	var room: Rect2i = _room()
	var low: int = Tuning.to_cell(room.position.x) + 1
	var high: int = Tuning.to_cell(room.end.x - 1) - 1
	if high < low:
		return
	var cols: Array[int] = []
	for i: int in TUSKER_ROCKS:
		for attempt: int in TUSKER_ROCK_TRIES:
			var col: int = Sim.rng.range_int(low, high)
			var free: bool = true
			for other: int in cols:
				free = free and absi(other - col) >= TUSKER_ROCK_COL_GAP
			if free:
				cols.append(col)
				break
	for col: int in cols:
		var x: int = col * Tuning.TILE + (Tuning.TILE >> 1)
		_pending.append(Vector3i(x, _ceiling_y(x, room.position.y), TUSKER_ROCK_WARN_TICKS))
	queue_redraw()


func _tick_rocks() -> void:
	if _pending.is_empty():
		return
	for i: int in range(_pending.size() - 1, -1, -1):
		var drop: Vector3i = _pending[i]
		drop.z -= 1
		if drop.z > 0:
			_pending[i] = drop
			continue
		_pending.remove_at(i)
		_spawn_optional(ROCK_ID, Vector2i(drop.x, drop.y + EnemyTuning.ROCK_BOX.y), {"xvel": 0, "yvel": 0})
	queue_redraw()


## The fight room in logical px: the arena zone's rectangle, else the camera lock, else one base screen around it.
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
	return Rect2i(sim_pos.x - (Tuning.VIEW_W >> 1), sim_pos.y - Tuning.VIEW_H + Tuning.TILE, Tuning.VIEW_W,
			Tuning.VIEW_H)


## Bottom of the first ceiling above x (searched up from its feet row), not higher than `limit`.
func _ceiling_y(x: int, limit: int) -> int:
	var grid: TileGrid = Game.level.grid
	var col: int = Tuning.to_cell(x)
	var row: int = Tuning.to_cell(sim_pos.y - 1)
	var top_row: int = Tuning.to_cell(limit)
	while row > top_row:
		row -= 1
		if grid.ceiling_at(col, row) != TileGrid.CEILING_NONE or grid.side_at(col, row) == TileGrid.SIDE_WALL:
			return (row + 1) * Tuning.TILE
	return maxi(limit, 0)


## The dust trickles over the rocks about to fall (cosmetic).
func _draw() -> void:
	for drop: Vector3i in _pending:
		var top: Vector2 = Vector2(drop.x, drop.y) * Tuning.ART_SCALE - position
		var length: float = float(TUSKER_ROCK_WARN_TICKS - drop.z + 1) * 6.0
		for k: int in 6:
			var y: float = fmod(float(k) * 11.0 + float(drop.z) * 5.0, maxf(length, 1.0))
			draw_rect(Rect2(top + Vector2(-2.0 + float((k * 3) % 5) - 2.0, y), Vector2(3.0, 3.0)),
					Color(0.55, 0.42, 0.3, 0.9))


func _process(_delta: float) -> void:
	if not _pending.is_empty():
		queue_redraw()


# =================================================================================================================
# Movement helpers
# =================================================================================================================

## Standing on the floor with no motion of its own.
func _ground_still() -> void:
	xvel = 0
	if Game.level != null:
		_ground_step(false, false)


func _body_box() -> void:
	if _skin != null:
		set_box(Vector3i(_skin.box.x, _skin.box.y, _skin.box.x >> 1))


## True when the feet stand in a tar (mud) cell.
func _on_tar(grid: TileGrid) -> bool:
	return _grounded and grid.is_tar(Tuning.to_cell(sim_pos.x), Tuning.to_cell(sim_pos.y))


## x of the centre of the run of tar cells under the feet.
func _wallow_centre_x(grid: TileGrid) -> int:
	var row: int = Tuning.to_cell(sim_pos.y)
	var left: int = Tuning.to_cell(sim_pos.x)
	var right: int = left
	while grid.is_tar(left - 1, row):
		left -= 1
	while grid.is_tar(right + 1, row):
		right += 1
	return (left * Tuning.TILE + (right + 1) * Tuning.TILE) >> 1


func _crossed(centre_x: int) -> bool:
	if centre_x == NO_WALLOW:
		return false
	return sim_pos.x >= centre_x if _dir > 0 else sim_pos.x <= centre_x


## True when the next step at xvel puts the front of the body into a wall (the row above the feet row).
func _wall_next(grid: TileGrid) -> bool:
	var dir: int = signi(xvel)
	if dir == 0:
		return false
	return _wall_at(grid, sim_pos.x + Tuning.floor16(xvel) + dir * (box_w >> 1))


## True when a wall lies within `px` ahead of the front of the body (co-op skid).
func _wall_within(grid: TileGrid, px: int) -> bool:
	return _wall_at(grid, sim_pos.x + _dir * ((box_w >> 1) + px))


func _wall_at(grid: TileGrid, probe_x: int) -> bool:
	if probe_x < Tuning.X_MIN or probe_x >= grid.x_max_excl():
		return true
	return grid.side_at(Tuning.to_cell(probe_x), Tuning.to_cell(sim_pos.y - 1) - 1) == TileGrid.SIDE_WALL \
			or grid.side_at(Tuning.to_cell(probe_x), Tuning.to_cell(sim_pos.y) - 1) == TileGrid.SIDE_WALL


## Put the front of the body right against the wall it is about to enter.
func _snap_to_wall(grid: TileGrid) -> void:
	var dir: int = signi(xvel) if xvel != 0 else _dir
	var half: int = box_w >> 1
	var x: int = sim_pos.x
	for step: int in Tuning.TILE:
		if _wall_at(grid, x + dir + dir * half):
			break
		x += dir
	sim_pos.x = x


## Co-op: lying open it faces the nearer hero on every tick (not the sticky target) - the nearer one who COUNTS (G33:
## LevelBase.nearest_coop_hero, never a dozing partner or an egg); with nobody counting it keeps its facing.
func _face_nearer() -> void:
	var level: LevelBase = Game.level
	if level == null:
		return
	var hero: PlayerBase = level.nearest_coop_hero(self)
	if hero != null:
		facing = _dir_to(hero)


## Who the next attack goes for: solo the target hero; co-op whoever hit it last while he can be targeted, else the
## nearest hero who counts (G33: its first target is never a dozing partner while a player plays), else the nearest
## hatched one.
func _charge_target(target: PlayerBase) -> PlayerBase:
	if not coop_form:
		return target
	if last_hitter != null and is_instance_valid(last_hitter) and last_hitter.is_party_targetable():
		return last_hitter
	var level: LevelBase = Game.level
	if level == null:
		return target
	var nearer: PlayerBase = level.nearest_coop_hero(self)
	return nearer if nearer != null else level.target_hero(self)


## A weak point or armour rectangle relative to the feet point (facing right), mirrored by the facing.
func _part(rel: Rect2i) -> Rect2i:
	var x0: int = rel.position.x if facing > 0 else -(rel.position.x + rel.size.x)
	return Rect2i(sim_pos.x + x0, sim_pos.y + rel.position.y, rel.size.x, rel.size.y)


## Wake rule (BossBase._wakes_for_any): a hero within TUSKER_WAKE_RANGE px across and TUSKER_WAKE_DY up or down.
func _wakes_for(hero: PlayerBase) -> bool:
	return absi(hero.sim_pos.x - sim_pos.x) < TUSKER_WAKE_RANGE and absi(hero.sim_pos.y - sim_pos.y) <= TUSKER_WAKE_DY
