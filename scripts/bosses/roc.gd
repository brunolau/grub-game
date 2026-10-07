class_name Roc
extends BossBase
## `bosses/roc` - the Storm Roc of Storm Nest (`w9_l2b`; DESIGN.md B.5, GAMEPLAY.md 13.6). Owner: enemies-C (PLAN.md
## P2.3). Expert only (its level is), but it fights the same on Beginner.
##
## Place the record on the stick nest (a run of one-way floor cells, the arena's middle; GAMEPLAY: cols 6-13, row 8):
## the nest is found on the first tick as the run of floor cells under the feet point. Body 104 x 44 (the shipped
## pterodactyl at 2x until art-B's 4 x 4 re-pack `roc`), feet point at the bottom centre; it flies through scenery.
## Hit points: `hp` [200] are what phases 1-2 take (8 club hits); the whole bar is 3 / 2 of that, the last third falls
## to three hang-glider dives (phase 3).
##
##  - **Phase 1 Gale** (perched on a nest rim, the rims alternating): it rests REST_TICKS, raises its wings WINGS_TICKS
##    (whoosh; the telegraph) and beats them: the level's wind blows GUST_WIND away from it for GUST_TICKS (crouch to
##    brace, PHYSICS.md C.6) while feathers fall like leaves (`projectiles/enemy_ember skin=leaf rain`, a touch costs a
##    bone). Its head (the top band of the body) is open from the nest: a high strike or a bounce and a strike. After
##    GUSTS gusts it takes off.
##  - **Phase 2 Dive**: it circles its target (way-points around him at 3 px/tick), screeches SCREECH_TICKS and dives
##    at the point where he stood when the screech ended (a straight line, DIVE_SPEED px/tick on the longer axis). A
##    miss buries its beak in the nest or the floor for BURY_TICKS: the head (low, at the front) is open. After DIVES
##    dives it perches again, until its hit points are down to a third.
##  - **Phase 3 Storm** (hp <= 1/3): it climbs above the view while lightning strikes the column of a hero
##    (`projectiles/boss_bolt`: a darkening cloud marks it BOLT_MARK ticks ahead; struck nest sticks burn), comes down
##    to cruise over the arena (CRUISE_TICKS), screeches and swoops at a hero, and climbs out again. The hang-glider lies
##    on the nest (`items/glider`; it comes back when lost): a gliding hero diving onto its back (yvel > 32, from
##    above) scores the dive ladder (1 000 / 5 000 / 10 000) and the Roc tumbles low over the nest TUMBLE_TICKS; the
##    third dive brings it down. Weapon hits do nothing in this phase.
##  - **Defeat**: it tumbles down into the clouds and the fire-starter comes out over the nest.
##
## Co-op form (a co-op game of two heroes in a `kind = coop` file; hp 250 for phases 1-2):
##  - Phase 1: a **wing shield** faces the nearer hatched hero; head hits from that side glance (a pincer on the nest).
##  - Phase 2 **Snatch** (Expert, PartyTuning.boss_grabs_on): a dive that touches its target grabs him (no control, he
##    hangs under it) and climbs at SNATCH_RISE px/tick; his partner frees him by hitting its head within SNATCH_TICKS
##    (the hit counts; the Roc drops, stunned STUN_TICKS, head open), else the grabbed hero becomes an egg (no life).
##  - Phase 3 **Pilot and Spotter**: a glider per hero lies on the nest; after a dive the Roc tumbles low over the nest
##    TUMBLE_TICKS, and the dive counts only if a hero other than the pilot strikes its tail feathers meanwhile.
##
## Parameters: `arena` zone name, `hp` [200; co-op 250], `drops` [fire_starter].

enum State {
	DORMANT, REST, WINGS, GUST, TAKEOFF, CIRCLE, SCREECH, DIVE, BURIED, RISE, SNATCH, STUNNED, CLIMB, STORM, DESCEND,
	CRUISE, SWOOP_SCREECH, SWOOP, TUMBLE, DYING,
}

const FEATHER_ID: StringName = &"projectiles/enemy_ember"
const BOLT_ID: StringName = &"projectiles/boss_bolt"
const GLIDER_ID: StringName = &"items/glider"

# --- Private tuning (enemies-C; to move into EnemyTuning with enemies-A, request wf8_enemies_c_to_enemies-A) --------
## Body 104 x 44 (the pterodactyl's 52 x 22 at 2x), feet point at the bottom centre.
const BOX: Vector3i = Vector3i(104, 44, 52)
## Hit points phases 1-2 take [G 13.6]; the co-op form [R8].
const HP_PHASES: int = 200
const HP_PHASES_COOP: int = 250
## Phase 1.
const REST_TICKS: int = 44
const WINGS_TICKS: int = 14
const GUST_TICKS: int = 66
const GUST_WIND: int = 48
const GUSTS: int = 3
const FEATHER_PERIOD: int = 11
## Flight (px per tick per axis).
const FLY_SPEED: int = 3
const TAKEOFF_HEIGHT: int = 72            ## circling height over the nest top
const CIRCLE_TICKS: int = 66
const WAYPOINT_TICKS: int = 22
const CIRCLE_WAYPOINTS: Array[Vector2i] = [Vector2i(80, -72), Vector2i(0, -96), Vector2i(-80, -72), Vector2i(0, -96)]
## Phase 2.
const SCREECH_TICKS: int = 14
const DIVE_SPEED: int = 6
const DIVES: int = 3
const BURY_TICKS: int = 44
## Co-op Snatch.
const SNATCH_RISE: int = 2
const SNATCH_TICKS: int = 73
const SNATCH_HANG_DY: int = 34            ## the held hero's feet below the Roc's feet point ... (he hangs from its talons)
const STUN_TICKS: int = 66
const FREE_SHIELD_TICKS: int = 44
## Phase 3.
const STORM_HEIGHT: int = 64              ## above the room's top while the lightning strikes
const BOLTS: int = 3
const BOLT_PERIOD: int = 33
const BOLT_MARK: int = 22
const CRUISE_HEIGHT: int = 40             ## cruise: feet this far over the nest top
const CRUISE_SPEED: int = 2
const CRUISE_TICKS: int = 132
const TUMBLE_TICKS: int = 24
const TUMBLE_HEIGHT: int = 6              ## tumbling: feet this far over the nest top (a hero on the nest reaches the tail)
const GLIDER_CHECK_PERIOD: int = 66
const DYING_TICKS: int = 48
## Weak points relative to the feet point (facing right; mirrored when facing left).
const HEAD_BAND: Rect2i = Rect2i(-52, -44, 104, 20)  ## perched / snatching: the top band (head, neck and wing tops)
const HEAD_LOW: Rect2i = Rect2i(16, -30, 40, 26)     ## beak buried / stunned: the head down at the front
const TAIL: Rect2i = Rect2i(-56, -30, 44, 26)        ## co-op tumble: the tail feathers at the back
## Tint of the shared pterodactyl sheet until art-B's `roc` sheet (storm slate).
const TINT: Color = Color(0.66, 0.72, 0.9)
const SKIN_ROC: String = "roc"
const SKIN_FALLBACK: String = "pterodactyl"
## The body of art-B's roc sheet is drawn this many logical px above its pivot (WORLD9_HANDOVER: body y -58..-14).
const ROC_ART_BODY_LIFT: int = 14
const FALLBACK_SCALE: float = 2.0

var _state: int = State.DORMANT
var _timer: int = 0
var _gusts: int = 0
var _dives: int = 0
var _rim: int = 0                         ## 0 = the nest's left rim, 1 = its right rim
var _waypoint: int = 0
var _waypoint_ticks: int = 0
var _aim: Vector2i = Vector2i.ZERO        ## the dive's goal (where the target stood at the end of the screech)
var _vel: Vector2i = Vector2i.ZERO        ## dive velocity, v16
var _acc: Vector2i = Vector2i.ZERO        ## sub-pixel remainder of the dive (v16)
var _bolts: int = 0
var _cruise_dir: int = 1
var _held: PlayerBase = null
var _held_took_control: bool = false
var _snatch_ticks: int = 0
var _pilot: PlayerBase = null             ## co-op: the hero whose dive waits for the spotter's strike
var _dive_pending: bool = false
var _phase3: bool = false
var _coop: bool = false
var _phases_hp: int = HP_PHASES
var _glider_check: int = 0
## The nest: its cells [x0, x1) in px and the y of its top; found on the first tick.
var nest_x0: int = 0
var nest_x1: int = 0
var nest_top: int = 0
var _nest_found: bool = false


func _default_skin() -> String:
	return SKIN_ROC if EnemySkin.find(SKIN_ROC) != null else SKIN_FALLBACK


func _apply_params(params: Dictionary) -> void:
	music = Sfx.MUSIC_BOSS_ROC
	boss_drops = [&"fire_starter"]
	super._apply_params(params)
	_phases_hp = maxi(int(params.get("hp", HP_PHASES)), 3)
	_configure_form()


func _ready() -> void:
	set_box(BOX)
	if _sprite != null and skin == SKIN_FALLBACK:
		_sprite.scale = Vector2(FALLBACK_SCALE, FALLBACK_SCALE)
		_sprite.self_modulate = TINT
	elif _sprite != null:
		# art-B's roc sheet draws the body 14 logical px above its pivot (body y -58..-14): lowered onto the box.
		_sprite.position.y = float(ROC_ART_BODY_LIFT * Tuning.ART_SCALE)


func _sim_phases() -> PackedInt32Array:
	# CONTACT_ENEMIES: a snatched hero is hung under the talons after his own update (the grab rule of CoopTraits).
	return PackedInt32Array([Defs.Phase.ENEMIES, Defs.Phase.CONTACT_ENEMIES])


func _sim_tick(phase: int) -> void:
	if phase == Defs.Phase.CONTACT_ENEMIES:
		if _held != null:
			_place_held()
		return
	super._sim_tick(phase)


# =================================================================================================================
# Queries (tests and tools)
# =================================================================================================================

func get_state() -> int:
	return _state


## True in the last phase (the glider dives).
func is_storm_phase() -> bool:
	return _phase3


## True in the co-op form.
func is_coop_form() -> bool:
	return _coop


## The hero it holds (co-op Snatch), or null.
func get_held() -> PlayerBase:
	return _held


## Hit points phases 1-2 take; the rest (a third of the bar) falls to the dives.
func get_phases_hp() -> int:
	return _phases_hp


## Hit points left at the start of the storm phase (a third of the bar).
func get_storm_hp() -> int:
	return max_hp - _phases_hp


## The weak point this tick (logical px; empty when nothing can hurt it now).
func get_head_rect() -> Rect2i:
	match _state:
		State.REST, State.WINGS, State.GUST, State.SNATCH:
			return _rel(HEAD_BAND)
		State.BURIED, State.STUNNED:
			return _rel(HEAD_LOW)
		State.TUMBLE:
			return _rel(TAIL) if _dive_pending else Rect2i()
	return Rect2i()


## The perch on a rim (0 left, 1 right): its feet point.
func get_perch(rim: int) -> Vector2i:
	_find_nest()
	var half: int = BOX.x >> 1
	if rim == 0:
		return Vector2i(nest_x0 + half - Tuning.TILE, nest_top)
	return Vector2i(nest_x1 - half + Tuning.TILE, nest_top)


func get_nest_center() -> Vector2i:
	_find_nest()
	return Vector2i((nest_x0 + nest_x1) >> 1, nest_top)


# =================================================================================================================
# The tick
# =================================================================================================================

func start_fight() -> void:
	if not fighting and not dead and _state == State.DORMANT:
		_configure_form()
	super.start_fight()


func _on_reset() -> void:
	_release_held(false)
	_state = State.DORMANT
	_timer = 0
	_gusts = 0
	_dives = 0
	_rim = 0
	_bolts = 0
	_phase3 = false
	_pilot = null
	_dive_pending = false
	_glider_check = 0
	_set_wind(0)
	_configure_form()
	set_box(BOX)
	visible = true


func _burst_origin() -> Vector2i:
	var centre: Vector2i = get_nest_center()
	return Vector2i(centre.x, centre.y + EnemyTuning.BOSS_DROP_DY)


func _on_lethal_hit() -> void:
	_release_held(false)
	_set_wind(0)
	_set_state(State.DYING)
	_play(&"dead", true)
	yvel = 0


func _on_defeated() -> void:
	visible = false
	_set_wind(0)


func _ai_tick() -> void:
	_find_nest()
	if dead:
		return
	if _state == State.DYING:
		_dying_tick()
		return
	var hero: PlayerBase = _target_hero()
	if not fighting:
		_play(&"land")
		if _wakes_for_any(hero):
			start_fight()
		if not fighting:
			return
	if _state == State.DORMANT:
		_configure_form()
		_perch(0)
	if hit_cooldown > 0:
		hit_cooldown -= 1
	_poll_hits()
	if dead or _state == State.DYING:
		return
	_glider_dives()
	if dead or _state == State.DYING:
		return
	_timer += 1
	match _state:
		State.REST:
			_face_heroes()
			_play(&"land")
			if _timer >= REST_TICKS:
				_set_state(State.WINGS)
				Audio.play_sfx(Sfx.LOOP_WIND)
		State.WINGS:
			_play(&"screech")
			if _timer >= WINGS_TICKS:
				_set_state(State.GUST)
				_set_wind(-GUST_WIND * facing)
		State.GUST:
			_gust_tick(hero)
		State.TAKEOFF:
			_play(&"fly")
			if _fly_to(Vector2i(sim_pos.x, nest_top - TAKEOFF_HEIGHT), FLY_SPEED):
				_begin_circle()
		State.CIRCLE:
			_circle_tick(hero)
		State.SCREECH:
			_play(&"screech")
			_face(hero)
			if _timer >= SCREECH_TICKS:
				_begin_dive(hero, State.DIVE)
		State.DIVE:
			_dive_tick(true)
		State.BURIED:
			_play(&"hurt")
			if _timer >= BURY_TICKS:
				_after_dive()
		State.RISE:
			_play(&"fly")
			if _fly_to(Vector2i(sim_pos.x, nest_top - TAKEOFF_HEIGHT), FLY_SPEED):
				_after_rise()
		State.SNATCH:
			_snatch_tick()
		State.STUNNED:
			_play(&"hurt")
			if _timer >= STUN_TICKS:
				_set_state(State.RISE)
		State.CLIMB:
			_play(&"fly")
			if _fly_to(Vector2i(sim_pos.x, _room().position.y - STORM_HEIGHT), FLY_SPEED):
				_set_state(State.STORM)
				_bolts = 0
		State.STORM:
			_storm_tick(hero)
		State.DESCEND:
			_play(&"fly")
			if _fly_to(Vector2i(get_nest_center().x, nest_top - CRUISE_HEIGHT), FLY_SPEED):
				_set_state(State.CRUISE)
		State.CRUISE:
			_cruise_tick()
		State.SWOOP_SCREECH:
			_play(&"screech")
			_face(hero)
			if _timer >= SCREECH_TICKS:
				_begin_dive(hero, State.SWOOP)
		State.SWOOP:
			_dive_tick(false)
		State.TUMBLE:
			_tumble_tick()
	if _phase3:
		_keep_gliders()
	_contact_every()


# =================================================================================================================
# Phase 1: the gale
# =================================================================================================================

func _perch(rim: int) -> void:
	_rim = rim
	teleport(get_perch(rim))
	xvel = 0
	yvel = 0
	facing = 1 if rim == 0 else -1
	_gusts = 0
	_set_state(State.REST)


func _gust_tick(hero: PlayerBase) -> void:
	_play(&"fly")
	if _timer % FEATHER_PERIOD == 1:
		var slot: int = hero.slot if hero != null else 0
		_spawn_optional(FEATHER_ID, sim_pos, {"rain": true, "skin": "leaf", "rain_slot": slot})
	if _timer < GUST_TICKS:
		return
	_set_wind(0)
	_gusts += 1
	if _gusts >= GUSTS or hp <= get_storm_hp():
		_take_off()
	else:
		_set_state(State.REST)


func _take_off() -> void:
	_set_wind(0)
	if hp <= get_storm_hp():
		_begin_storm()
		return
	_dives = 0
	_set_state(State.TAKEOFF)


## Perched: face the heroes (solo: the hero; co-op: the nearer hatched hero - the wing shield's side).
func _face_heroes() -> void:
	var near: PlayerBase = _nearest_hero()
	if near != null:
		facing = 1 if near.sim_pos.x >= sim_pos.x else -1


# =================================================================================================================
# Phase 2: circle, screech, dive, bury
# =================================================================================================================

func _begin_circle() -> void:
	_set_state(State.CIRCLE)
	_waypoint = 0
	_waypoint_ticks = 0


func _circle_tick(hero: PlayerBase) -> void:
	_play(&"fly")
	if hero == null:
		return
	var goal: Vector2i = hero.sim_pos + CIRCLE_WAYPOINTS[_waypoint]
	goal = _clamp_to_room(goal)
	_waypoint_ticks += 1
	if _fly_to(goal, FLY_SPEED) or _waypoint_ticks >= WAYPOINT_TICKS:
		_waypoint = (_waypoint + 1) % CIRCLE_WAYPOINTS.size()
		_waypoint_ticks = 0
	_face(hero)
	if _timer >= CIRCLE_TICKS:
		_set_state(State.SCREECH)
		Audio.play_sfx(Sfx.BOSS_ROAR)


## Dive (or swoop) at the point where the target stands now: a straight line at DIVE_SPEED px per tick on the longer
## axis.
func _begin_dive(hero: PlayerBase, state: int) -> void:
	_aim = hero.sim_pos if hero != null else Vector2i(sim_pos.x, nest_top)
	var dx: int = _aim.x - sim_pos.x
	var dy: int = maxi(_aim.y - sim_pos.y, 1)
	var longer: int = maxi(absi(dx), dy)
	_vel = Vector2i(dx * DIVE_SPEED * 16 / longer, dy * DIVE_SPEED * 16 / longer)
	_acc = Vector2i.ZERO
	if dx != 0:
		facing = signi(dx)
	_set_state(state)


## One tick of a dive (`bury`: phase 2 - a miss buries the beak) or a swoop (phase 3 - it pulls up).
func _dive_tick(bury: bool) -> void:
	_play(&"dive")
	_acc += _vel
	var step: Vector2i = Vector2i(_acc.x / 16, _acc.y / 16)
	_acc -= step * 16
	sim_pos += step
	sim_pos.x = clampi(sim_pos.x, _room().position.x + (BOX.x >> 1), _room().end.x - (BOX.x >> 1))
	if _dive_contact():
		return
	# Only the target's floor (or one below it) stops the dive: a dive at the floor passes through the nest.
	var surface: int = _surface_under()
	var landed: bool = surface != EnemyBase.NO_FLOOR and sim_pos.y >= surface and surface >= _aim.y - Tuning.TILE
	if landed:
		sim_pos.y = surface
	if landed or sim_pos.y >= _aim.y or _timer > 90:
		if bury and landed:
			_set_state(State.BURIED)
			Audio.play_sfx(Sfx.QUAKE)
			if Game.level != null:
				Game.level.request_shake(EnemyTuning.BOSS_BOB_SHAKE)
		elif bury:
			_after_dive()
		else:
			_set_state(State.CLIMB)


## A dive met a hero: the body hurts him (a bone, the boss knock-back) and it pulls up; co-op (Expert): the target is
## snatched instead (never a Helper-mode P2, PlayerBase.is_helper: the touch spares him). True when the dive ended.
func _dive_contact() -> bool:
	var level: LevelBase = Game.level
	if level == null:
		return false
	for hero: PlayerBase in level.contact_order():
		if hero.dead or hero.is_down() or hero.is_immune() or hero.is_feasting():
			continue
		if not Overlap.body(hero, self, hero):
			continue
		if _state == State.DIVE and _coop and PartyTuning.boss_grabs_on(Game.difficulty) \
				and hero == _target_hero() and not hero.is_helper():
			_snatch(hero)
			return true
		touch_hero(hero)
		if _state == State.DIVE:
			_after_dive()
		else:
			_set_state(State.CLIMB)
		return true
	return false


func _after_dive() -> void:
	_dives += 1
	_set_state(State.RISE)


func _after_rise() -> void:
	if hp <= get_storm_hp():
		_begin_storm()
	elif _dives >= DIVES:
		_set_state(State.TAKEOFF)
		_perch(1 - _rim)
	else:
		_begin_circle()


# --- Co-op Snatch ---------------------------------------------------------------------------------------------------

func _snatch(hero: PlayerBase) -> void:
	_held = hero
	_held_took_control = hero.control_enabled
	if _held_took_control:
		hero.set_control_enabled(false)
	_snatch_ticks = 0
	_set_state(State.SNATCH)
	_place_held()
	if Game.level != null:
		Game.level.notify_hero_teleported(hero)
	Audio.play_sfx(Sfx.BOSS_ROAR)


func _snatch_tick() -> void:
	_play(&"fly")
	_snatch_ticks += 1
	sim_pos.y -= SNATCH_RISE
	if _held == null or not is_instance_valid(_held) or _held.dead or _held.is_down():
		_release_held(false)
		_after_dive()
		return
	if _snatch_ticks >= SNATCH_TICKS:
		var hero: PlayerBase = _held
		_release_held(false)
		hero.go_down(&"enemy")
		_after_dive()


func _place_held() -> void:
	if _held == null or not is_instance_valid(_held) or _held.dead or _held.is_down():
		return
	_held.sim_pos = sim_pos + Vector2i(0, SNATCH_HANG_DY)
	_held.xvel = 0
	_held.yvel = 0
	_held.attack_gate = false
	_held.club_box_active = false


func _release_held(freed: bool) -> void:
	var hero: PlayerBase = _held
	_held = null
	if hero == null or not is_instance_valid(hero):
		_held_took_control = false
		return
	if _held_took_control and not hero.dead and not hero.is_down():
		hero.set_control_enabled(true)
	_held_took_control = false
	if freed and not hero.dead and not hero.is_down():
		hero.shield = maxi(hero.shield, FREE_SHIELD_TICKS)


## The partner's hit freed the snatched hero: the Roc drops to the ground below, stunned with its head open.
func _rescued() -> void:
	_release_held(true)
	var surface: int = _surface_under_from(sim_pos.y)
	if surface != EnemyBase.NO_FLOOR:
		sim_pos.y = surface
	_set_state(State.STUNNED)


# =================================================================================================================
# Phase 3: the storm
# =================================================================================================================

func _begin_storm() -> void:
	_phase3 = true
	_set_wind(0)
	_bolts = 0
	_set_state(State.CLIMB)
	_keep_gliders()


func _storm_tick(hero: PlayerBase) -> void:
	_play(&"fly")
	if _timer % BOLT_PERIOD == 0:
		var target: PlayerBase = _bolt_target()
		if target != null:
			var room: Rect2i = _room()
			_spawn_optional(BOLT_ID, Vector2i(target.sim_pos.x, room.position.y), {
				"mark": BOLT_MARK, "bottom": room.end.y, "nest_x0": nest_x0, "nest_x1": nest_x1,
				"nest_top": nest_top,
			})
		_bolts += 1
	if _bolts >= BOLTS and _timer % BOLT_PERIOD == BOLT_PERIOD - 1:
		teleport(Vector2i(get_nest_center().x, sim_pos.y))
		_set_state(State.DESCEND)


## The bolts alternate between the hatched heroes (one hero: always him).
func _bolt_target() -> PlayerBase:
	var level: LevelBase = Game.level
	if level == null:
		return null
	var heroes: Array[PlayerBase] = []
	for hero: PlayerBase in level.contact_order():
		if hero.is_party_targetable():
			heroes.append(hero)
	if heroes.is_empty():
		return null
	return heroes[_bolts % heroes.size()]


func _cruise_tick() -> void:
	_play(&"fly")
	var room: Rect2i = _room()
	var left: int = room.position.x + BOX.x
	var right: int = room.end.x - BOX.x
	sim_pos.x += _cruise_dir * CRUISE_SPEED
	if sim_pos.x <= left:
		sim_pos.x = left
		_cruise_dir = 1
	elif sim_pos.x >= right:
		sim_pos.x = right
		_cruise_dir = -1
	facing = _cruise_dir
	if _timer >= CRUISE_TICKS:
		_set_state(State.SWOOP_SCREECH)
		Audio.play_sfx(Sfx.BOSS_ROAR)


## A gliding hero dives onto its back (phase 3; GLIDER rule of PHYSICS.md 9: gliding, yvel > 32, from above): he is
## bumped up, the dive ladder pays, and the Roc tumbles low over the nest. Solo the dive counts at once; co-op it
## waits for the spotter's strike on the tail.
func _glider_dives() -> void:
	if not _phase3 or _state == State.TUMBLE or _state == State.STORM or _state == State.CLIMB:
		return
	var level: LevelBase = Game.level
	if level == null:
		return
	for hero: PlayerBase in level.contact_order():
		if hero.dead or hero.is_down() or not hero.is_gliding() or hero.yvel <= Tuning.GLIDER_DIVE_MIN_YVEL_EXCL:
			continue
		if not Overlap.body(hero, self, hero) or not Overlap.stomp:
			continue
		hero.bounce(Tuning.GLIDER_BUMP_YVEL, Overlap.depth)
		Audio.play_sfx(Sfx.BOUNCE)
		if _coop:
			_pilot = hero
			_dive_pending = true
		else:
			_count_dive(hero)
			if dead or _state == State.DYING:
				return
		_tumble()
		return


func _tumble() -> void:
	teleport(Vector2i(get_nest_center().x, nest_top - TUMBLE_HEIGHT))
	_set_state(State.TUMBLE)


func _tumble_tick() -> void:
	_play(&"hurt")
	if _timer >= TUMBLE_TICKS:
		_dive_pending = false
		_pilot = null
		_set_state(State.CLIMB)


## A dive counts: the ladder pays (1 000 / 5 000 / 10 000) and a third of the storm's hit points goes; the third dive
## brings it down.
func _count_dive(hero: PlayerBase) -> void:
	var index: int = mini(dive_count, Tuning.GLIDER_DIVE_SCORES.size() - 1)
	Game.add_score(Tuning.GLIDER_DIVE_SCORES[index])
	Events.popup_requested.emit(&"score", Tuning.GLIDER_DIVE_SCORES[index], sim_pos)
	dive_count += 1
	var storm: int = get_storm_hp()
	var left: int = storm * maxi(Tuning.GLIDER_DIVE_KILLS_ON - dive_count, 0) / Tuning.GLIDER_DIVE_KILLS_ON
	if hero != null:
		_note_hitter(Game.level, hero.slot)
	hit_cooldown = 0
	apply_boss_hit(maxi(hp - left, 1))


## The gliders on the nest: one (solo) or one per hero (co-op) - a hero carrying one counts; a lost one comes back.
func _keep_gliders() -> void:
	_glider_check -= 1
	if _glider_check > 0:
		return
	_glider_check = GLIDER_CHECK_PERIOD
	var level: LevelBase = Game.level
	if level == null or not Spawner.exists(GLIDER_ID):
		return
	var want: int = 2 if _coop else 1
	var have: int = 0
	for hero: PlayerBase in level.contact_order():
		if hero.run.has_glider:
			have += 1
	for entity: SimEntity in level.get_kind(Defs.Kind.COLLECTIBLE):
		var item: CollectibleBase = entity as CollectibleBase
		if item != null and item.item_id == GLIDER_ID and not item.collected and not item.is_queued_for_deletion():
			have += 1
	var centre: Vector2i = get_nest_center()
	for i: int in range(have, want):
		var x: int = centre.x + (i * 2 - 1) * 24 if want > 1 else centre.x
		_spawn_optional(GLIDER_ID, Vector2i(x, nest_top))


func _dying_tick() -> void:
	_play(&"dead")
	_timer += 1
	yvel = mini(yvel + Tuning.ENEMY_GRAVITY, Tuning.ENEMY_TERMINAL)
	sim_pos.y += Tuning.floor16(yvel)
	if _timer >= DYING_TICKS:
		defeat(boss_drops)


# =================================================================================================================
# Hits
# =================================================================================================================

## Weapons against the weak point of this state (BossBase.poll_weapon_hit order and cooldown). Co-op: the wing shield
## turns head hits from the nearer hero's side into glances; a hit on the snatching Roc by the partner frees the held
## hero; a strike on the tumbling Roc's tail by a hero other than the pilot makes his dive count.
func _poll_hits() -> void:
	var weak: Rect2i = get_head_rect()
	var level: LevelBase = Game.level
	if weak.size.x <= 0 or level == null:
		return
	var source: SimEntity = null
	var power: int = 0
	var projectiles: Array[SimEntity] = level.get_kind(Defs.Kind.HERO_PROJECTILE)
	for i: int in range(projectiles.size() - 1, -1, -1):
		var projectile: ProjectileBase = projectiles[i] as ProjectileBase
		if projectile != null and not projectile.spent and Overlap.rects(projectile.get_box(), weak):
			if _held != null and projectile.owner_slot == _held.slot:
				continue
			projectile.consume()
			if hit_cooldown > 0:
				return
			source = projectile
			power = projectile.power
			break
	if source == null:
		if hit_cooldown > 0:
			return
		for hero: PlayerBase in level.contact_order():
			if hero == _held or not hero.club_box_active or not Overlap.rects(hero.club_box, weak):
				continue
			hero.notify_weapon_hit()
			source = hero
			power = hero.club_power
			break
	if source == null:
		return
	var slot: int = Defs.hitter_slot(source)
	if _state == State.TUMBLE:
		if _pilot != null and slot == _pilot.slot:
			return
		_dive_pending = false
		var pilot: PlayerBase = _pilot
		_pilot = null
		_count_dive(pilot)
		return
	if _coop and _is_shielded(source):
		_glance_at(level, weak.get_center())
		return
	_note_hitter(level, slot)
	var floor_hp: int = get_storm_hp() if not _phase3 else 0
	var damage: int = mini(power, maxi(hp - floor_hp, 0))
	if damage <= 0:
		_glance_at(level, weak.get_center())
		hit_cooldown = Tuning.BOSS_HIT_COOLDOWN
		return
	apply_boss_hit(damage)
	if dead:
		return
	if _state == State.SNATCH:
		_rescued()


## Co-op phase 1: the wing shield faces the nearer hatched hero; a hit from that side glances (a thrown weapon by its
## flight, a striker by his x), and so does every hit of that hero himself.
func _is_shielded(source: SimEntity) -> bool:
	if _state != State.REST and _state != State.WINGS and _state != State.GUST:
		return false
	var near: PlayerBase = _nearest_hero()
	if near == null:
		return false
	if Defs.hitter_slot(source) == near.slot:
		# The shield faces him: none of his own hits gets round it (a boomerang on its way back included).
		return true
	var shield_side: int = 1 if near.sim_pos.x >= sim_pos.x else -1
	var from_side: int = 0
	if source.get_kind() == Defs.Kind.HERO_PROJECTILE and source.xvel != 0:
		from_side = -signi(source.xvel)
	else:
		from_side = 1 if source.sim_pos.x >= sim_pos.x else -1
	return from_side == shield_side


func _glance_at(level: LevelBase, point: Vector2i) -> void:
	if _glance_ticks > 0:
		return
	_glance_ticks = GLANCE_TICKS
	Audio.play_sfx(Sfx.CLUB_HIT_SCENERY)
	level.spawn_fx(&"fx/hit_stars", point)


# =================================================================================================================
# Body contact
# =================================================================================================================

## The body against every living hero (the target in a party of one): a landing on its back bounces him harmlessly
## (the glider dive is [method _glider_dives]); anything else costs a bone with the boss knock-back. Harmless while it
## tumbles, lies stunned or dies, and while it holds a hero (the held one hangs in it).
func _contact_every() -> void:
	if _state == State.TUMBLE or _state == State.STUNNED or _state == State.SNATCH or _state == State.STORM:
		return
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
		if hero.dead or hero.is_down() or hero.is_feasting() or hero.is_immune():
			continue
		if not Overlap.body(hero, self, hero):
			continue
		if Overlap.stomp and hero.yvel >= 0:
			var held: bool = (hero.input_flags & Defs.IN_UP) != 0
			hero.bounce(Tuning.BOSS_BOUNCE_YVEL_UP if held else Tuning.BOSS_BOUNCE_YVEL, Overlap.depth)
			Events.player_bounced.emit(self, 0)
			Events.hero_bounced.emit(hero, self, 0)
			continue
		touch_hero(hero)


## Wake rule: a hero within a screen's width of the nest and at about its height.
func _wakes_for(hero: PlayerBase) -> bool:
	return absi(hero.sim_pos.x - sim_pos.x) < Tuning.VIEW_W and absi(hero.sim_pos.y - sim_pos.y) < Tuning.VIEW_H


# =================================================================================================================
# Internals
# =================================================================================================================

func _set_state(state: int) -> void:
	_state = state
	_timer = 0


## The co-op form on a co-op file in a co-op game; sets the hit points.
func _configure_form() -> void:
	var level: LevelBase = Game.level
	_coop = level != null and Game.mode == Defs.GameMode.COOP and level.hero_count() > 1 \
			and str(level.meta.get("kind", "")) == "coop"
	var phases: int = _phases_hp
	if _coop and not spawn_params.has("hp"):
		phases = HP_PHASES_COOP
	_phases_hp = phases
	max_hp = phases * 3 / 2
	hp = max_hp
	hp_per_pip = maxi(max_hp / Tuning.BOSS_BAR_MAX_PIPS, 1)


## The nest: the run of floor cells under the feet point.
func _find_nest() -> void:
	if _nest_found:
		return
	var level: LevelBase = Game.level
	if level == null:
		return
	_nest_found = true
	var grid: TileGrid = level.grid
	var row: int = Tuning.to_cell(spawn_pos.y)
	var col: int = Tuning.to_cell(spawn_pos.x)
	var c0: int = col
	var c1: int = col
	while c0 > 0 and TileGrid.is_ground(grid.floor_at(c0 - 1, row)):
		c0 -= 1
	while c1 < grid.cols - 1 and TileGrid.is_ground(grid.floor_at(c1 + 1, row)):
		c1 += 1
	if not TileGrid.is_ground(grid.floor_at(col, row)):
		c0 = col - 4
		c1 = col + 3
	nest_x0 = c0 * Tuning.TILE
	nest_x1 = (c1 + 1) * Tuning.TILE
	nest_top = row * Tuning.TILE
	if TileGrid.is_ground(grid.floor_at(col, row)):
		nest_top += grid.surface_offset(col, row, spawn_pos.x)


## Move toward `goal` by up to `speed` px per axis; true when there.
func _fly_to(goal: Vector2i, speed: int) -> bool:
	sim_pos.x += clampi(goal.x - sim_pos.x, -speed, speed)
	sim_pos.y += clampi(goal.y - sim_pos.y, -speed, speed)
	return sim_pos == goal


func _clamp_to_room(point: Vector2i) -> Vector2i:
	var room: Rect2i = _room()
	var half: int = BOX.x >> 1
	return Vector2i(clampi(point.x, room.position.x + half, room.end.x - half),
			clampi(point.y, room.position.y + BOX.y, nest_top - BOX.y))


func _face(hero: PlayerBase) -> void:
	if hero != null and hero.sim_pos.x != sim_pos.x:
		facing = 1 if hero.sim_pos.x > sim_pos.x else -1


## The nearest hatched hero (the target hero in a party of one).
func _nearest_hero() -> PlayerBase:
	var level: LevelBase = Game.level
	if level == null:
		return null
	if level.hero_count() <= 1:
		return _target_hero()
	var best: PlayerBase = null
	var best_d: int = 0
	for hero: PlayerBase in level.contact_order():
		if not hero.is_party_targetable():
			continue
		var d: int = absi(hero.sim_pos.x - sim_pos.x) + absi(hero.sim_pos.y - sim_pos.y)
		if best == null or d < best_d:
			best = hero
			best_d = d
	return best


## A rectangle given relative to the feet point facing right, for the current facing.
func _rel(rect: Rect2i) -> Rect2i:
	if facing >= 0:
		return Rect2i(sim_pos + rect.position, rect.size)
	return Rect2i(sim_pos.x - rect.position.x - rect.size.x, sim_pos.y + rect.position.y, rect.size.x, rect.size.y)


## The surface y of the floor cell at the feet point (EnemyBase.NO_FLOOR when that cell is no floor).
func _surface_under() -> int:
	var grid: TileGrid = Game.level.grid if Game.level != null else null
	if grid == null:
		return EnemyBase.NO_FLOOR
	var col: int = Tuning.to_cell(sim_pos.x)
	var row: int = Tuning.to_cell(sim_pos.y)
	if not TileGrid.is_ground(grid.floor_at(col, row)):
		return EnemyBase.NO_FLOOR
	return row * Tuning.TILE + grid.surface_offset(col, row, sim_pos.x)


## The first floor surface at or below `y` under the feet point.
func _surface_under_from(y: int) -> int:
	var grid: TileGrid = Game.level.grid if Game.level != null else null
	if grid == null:
		return EnemyBase.NO_FLOOR
	var col: int = Tuning.to_cell(sim_pos.x)
	for row: int in range(Tuning.to_cell(y), grid.rows):
		if TileGrid.is_ground(grid.floor_at(col, row)):
			return row * Tuning.TILE + grid.surface_offset(col, row, sim_pos.x)
	return EnemyBase.NO_FLOOR


func _set_wind(value: int) -> void:
	if Game.level != null and Game.level.wind != value:
		Game.level.set_wind(value)


## The fight room in logical px: the arena zone's rectangle, else the camera lock, else one base screen around the nest.
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
	var centre: Vector2i = get_nest_center()
	return Rect2i(centre.x - (Tuning.VIEW_W >> 1), nest_top - 8 * Tuning.TILE, Tuning.VIEW_W, Tuning.VIEW_H)
