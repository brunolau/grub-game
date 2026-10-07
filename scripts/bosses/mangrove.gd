class_name Mangrove
extends BossBase
## `bosses/mangrove` - Old Mangrove, the Rooted Guardian (w6_l2b Heart of the Mangrove; DESIGN.md B.2, GAMEPLAY.md
## 13.6; the tree-stump archetype of GAMEPLAY.md 6.2). Owner: enemies-B (PLAN.md P2.2).
##
## A face set into the right-hand wall of its chamber. Place the record in the floor-level air cell just left of that
## wall: the record moves to the wall's foot (like the Colossus) and works out everything else from the map - the
## wall face, the floor, the face MANGROVE_FACE_RISE px over the floor, the fist's rest on the floor, and the upper
## ledge (the highest one-way ledge of its room, `zones/arena`) where the upper hand rests. Parts:
##  - the FIST on its 3-segment root arm: punches along the floor in bursts; between bursts it rests on the floor, and
##    the resting fist is a SPRINGBOARD - a hero landing on it is launched unharmed (Tuning.BOSS_LAUNCH_YVEL -160,
##    Tuning.BOUNCE_YVEL_UP -224 with Up held) towards the face. Each punch: a MANGROVE_DRAW_TICKS draw-back with a
##    creak (the telegraph), MANGROVE_OUT_TICKS out along the floor (the moving fist: 3 bones and the boss knock-back),
##    one tick back; it shakes the screen (4), shoves the heroes on the floor 2 px and drops one leaf from 150 px over
##    its target (`projectiles/enemy_ember skin=leaf`, a bone).
##  - the UPPER HAND: after a MANGROVE_SHAKE_TICKS ledge shake (the telegraph) it sweeps out of the wall onto the upper
##    ledge (a bone for anyone in its way) and rests there MANGROVE_HAND_REST_TICKS, its fingers hooked over the
##    ledge's edge (reachable by a high strike from the lower ledge, or from the upper ledge itself), then draws back.
##  - the TRUNK: the strip of wall under the face; walking into it pushes the hero back and costs a bone.
## Any weapon counts 1 per hit (archetype 6.2): Beginner 4 / 3 / 3, Expert 6 / 5 / 5 hits per stage.
##  1. FACE: the fist punches (bursts of 3-8, Sim.rng, the first burst 8; rests of 64-184 ticks): the face is the weak
##     point (from the springboard, or a curving throw).
##  2. UPPER HAND: the hand cycle runs and the resting hand is the weak point; the fist keeps punching.
##  3. FIST: bursts of 8; after each burst the fist stays stuck in the floor MANGROVE_STUCK_TICKS, the weak point;
##     burrowing bugs (an `enemies/digger skin=lizard` zone record it raises over its room) come up around the heroes,
##     and every punch sends the bugs that are up back down.
## Co-op form (`kind = coop` files or `form=coop`): stages 1 and 2 merge - the face and the resting hand must both be
## struck within the twin window, by the two heroes (one hero's two hits never twin), a twin hit counting 1 (Beginner 5,
## Expert 7 [R8]); the window is min(PartyTuning.window_ticks, MANGROVE_SOLO_MIN_TICKS - 4), the solo minimum measured
## by tests/test_enemies_mangrove.gd. A hero landing on the resting fist without Up held stands on it and PINS it (no
## punch) until it flings him off (-160) after MANGROVE_PIN_TICKS; with Up held it launches him at once (-224). Stage 3
## (Beginner 3, Expert 6): the knuckle armour of the stuck fist turns to the nearer hero every tick - only a hit from
## the far side (the wrist) counts.
##
## Fairness (B.0): every attack shows itself 10+ ticks ahead (draw-back 10, ledge shake 14); hits never stop or lengthen
## a part's clock (no stun-lock); BossBase.hit_cooldown is shared. Parameters: `arena`, `hp` (stage 1 takes what the
## later stages leave), `drops` [fire_starter], `form=coop|solo`. Numbers: MANGROVE_* below (EnemyTuning once enemies-A
## adopts them).

enum Fist { REST, DRAW, OUT, BACK, STUCK, GONE }
enum Hand { AWAY, SHAKE, SWEEP, REST, RETRACT }

const LEAF_ID: StringName = &"projectiles/enemy_ember"
const BUG_ID: StringName = &"enemies/digger"
const PARTS_TEXTURE: Texture2D = preload("res://assets/sprites/bosses/mangrove_parts.png")
const PARTS_COLUMNS: int = 8
const PARTS_PIVOT: Vector2 = Vector2(40.0, 64.0)
const FRAME_FIST: int = 0
const FRAME_FIST_FLASH: int = 1
const FRAME_HAND: int = 2
const FRAME_ARM: int = 3
const ARM_SEGMENTS: int = 3
const ARM_LINKS: int = 6

# --- Tuning [D B.2] [G 13.6] (tune) ---------------------------------------------------------------------------------
const MANGROVE_HITS_BEGINNER: Array[int] = [4, 3, 3]   ## hits per stage (face, hand, fist)
const MANGROVE_HITS_EXPERT: Array[int] = [6, 5, 5]
const MANGROVE_COOP_HITS_BEGINNER: Array[int] = [5, 3] ## co-op: twin hits, then the fist (*tune*)
const MANGROVE_COOP_HITS_EXPERT: Array[int] = [7, 6]
const MANGROVE_FACE_RISE: int = 106          ## the face's feet point this far over the floor: its weak rect lies 6-35 px
                                             ## higher (above any jump from the floor, at the -160 launch's apex) [own]
const MANGROVE_TRUNK_PX: int = 4             ## the trunk strip in front of the wall face (a bone, pushed back)
const MANGROVE_FIST_REST_DX: int = 40        ## the resting fist's centre this far from the wall face [own]
const MANGROVE_FIST_DRAW_DX: int = 16        ## drawn back to this far from the wall face [own]
const MANGROVE_PUNCH_REACH: int = 112        ## a punch carries the fist's centre this far past its rest [own]
const MANGROVE_DRAW_TICKS: int = 10          ## the draw-back with a creak: the punch's telegraph
const MANGROVE_OUT_TICKS: int = 3            ## out along the floor (the moving fist)
const MANGROVE_BACK_TICKS: int = 1           ## and back
const MANGROVE_FIRST_BURST: int = 8
const MANGROVE_BURST_MIN: int = 3
const MANGROVE_BURST_MAX: int = 8
const MANGROVE_REST_MIN: int = 64            ## rest between bursts: the springboard's time
const MANGROVE_REST_MAX: int = 184
const MANGROVE_FIRST_REST: int = 44          ## the fight opens with this rest before the first burst [own]
const MANGROVE_FACE_HIT_REST: int = 10       ## a face hit cuts the fist's rest to at most this long [own]
const MANGROVE_PUNCH_BONES: int = 3          ## the moving fist costs 3 bones
const MANGROVE_PUNCH_SHAKE: int = 4
const MANGROVE_SHOVE_PX: int = 2             ## each punch shoves the heroes on the floor away from the wall
const MANGROVE_STUCK_TICKS: int = 20         ## stage 3: stuck in the floor after each burst (the weak point)
const MANGROVE_SHAKE_TICKS: int = 14         ## the ledge shake before the upper hand sweeps
const MANGROVE_HAND_SPEED: int = 8           ## px per tick of the sweep and the retreat [own]
const MANGROVE_HAND_REST_TICKS: int = 44     ## the hand rests on the ledge this long
const MANGROVE_HAND_PAUSE: int = 66          ## ticks between the hand's retreat and its next ledge shake [own]
const MANGROVE_HAND_SINK: int = 12           ## the resting hand's fingers hang this far below the ledge top [own]
const MANGROVE_HAND_FIRST_PAUSE: int = 22    ## the first shake of a stage comes this long after it began [own]
const MANGROVE_PIN_TICKS: int = 66           ## co-op: a hero standing on the resting fist pins it this long ...
const MANGROVE_FLING_YVEL: int = Tuning.BOSS_LAUNCH_YVEL  ## ... then it flings him off
## Co-op: the pin holds through this many ticks without a rider (a screen-shake nudge lifts a standing hero off the
## fist's ride band for a tick or two; PHYSICS.md 13.3) [own]
const MANGROVE_PIN_GRACE: int = 3
## Co-op: feet up to this far over the fist's top still stand on it (the shake nudge, Tuning.SHAKE_NUDGE) [own]
const MANGROVE_PIN_HOVER_PX: int = 6
## Co-op: the least ticks one hero needs between a face hit and a hand hit on the test level, measured by
## tests/test_enemies_mangrove.gd (launched from the fist with the spear, the axe or the swirling axe, a throw at the face
## and one back at the resting hand; the axe does it in 10), which pins this as a lower bound: the twin window is
## min(PartyTuning.window_ticks, this - PartyTuning.WINDOW_SOLO_MARGIN_TICKS) = 6 ticks on both difficulties
## (GAMEPLAY.md 13.9.3). One hero's two hits never twin anyway (the slot rule of _twin_half).
const MANGROVE_SOLO_MIN_TICKS: int = 10
const MANGROVE_COUNT_IN_TICKS: int = 8       ## the twin count-in: three blips 8 ticks apart, then "go"
const MANGROVE_PART_DEBOUNCE: int = 8        ## one strike lights a part once (its boxes live up to 3 ticks) [own]
const MANGROVE_DYING_TICKS: int = 44         ## withering before the bonus burst [own]
const MANGROVE_BUG_PAUSE: int = 44           ## the bugs' `pause`
const MANGROVE_WAKE_RANGE: int = 224         ## starts the fight by itself when a hero is this close to the wall [own]
## Weak and contact rectangles relative to their part's feet point (art-B's zones_logical and the parts' boxes).
const MANGROVE_FACE: Rect2i = Rect2i(-10, -35, 20, 29)
const MANGROVE_FIST_BOX: Vector2i = Vector2i(40, 32)
const MANGROVE_HAND_BOX: Vector2i = Vector2i(40, 32)

## True for the co-op form (DESIGN.md B.2).
var coop_form: bool = false
## Hits per stage in this game (solo: face, hand, fist; co-op: twin, fist).
var stage_hits: Array[int] = []

## Geometry worked out from the map (logical px).
var wall_x: int = 0
var floor_y: int = 0
var fist_rest_x: int = 0
var fist_draw_x: int = 0
var fist_out_x: int = 0
var hand_rest: Vector2i = Vector2i.ZERO
var hand_home: Vector2i = Vector2i.ZERO

var _stage: int = 0
var _fist: int = Fist.REST
var _fist_timer: int = 0
var _fist_len: int = 0
var _fist_x: int = 0
var _fist_from: int = 0
var _burst_left: int = 0
var _first_burst: bool = true
var _fist_facing: int = -1
var _hand: int = Hand.AWAY
var _hand_timer: int = 0
var _hand_pos: Vector2i = Vector2i.ZERO
var _dying: int = -1
## Co-op twin: the slot and tick of the last face and hand hit (-1 = none).
var _face_slot: int = -1
var _face_tick: int = -1
var _hand_slot: int = -1
var _hand_tick: int = -1
## Co-op: ticks the resting fist has been pinned, ticks since a hero last stood on it; the count-in clock.
var _pinned: int = 0
var _pin_gone: int = 0
## Co-op: bit per slot - the heroes who stood on the fist during the running pin.
var _pin_mask: int = 0
var _count_in: int = -1
## Debounce of part hits (Sim.total_ticks of the last one per part).
var _part_tick: Dictionary = {}
var _bugs: EnemyBase = null
var _top: FistTop = null
var _parts: Node2D = null
var _fist_sprite: Sprite2D = null
var _hand_sprite: Sprite2D = null
var _links: Array[Sprite2D] = []
var _hand_links: Array[Sprite2D] = []
## Statistics for tests and tools: punches thrown, sweeps, launches from the springboard, twin hits counted.
var punches: int = 0
var sweeps: int = 0
var launches: int = 0
var twins: int = 0


## The resting fist's top as a platform (PHYSICS.md 11.4 ride test, PLATFORMS phase): the springboard, and in co-op the
## pin. Owned by its boss; never placed.
class FistTop:
	extends SimEntity

	var boss: Mangrove = null
	## Bit per slot: the hero stood on it this tick (co-op pin).
	var riders: int = 0

	func _sim_phases() -> PackedInt32Array:
		return PackedInt32Array([Defs.Phase.PLATFORMS])

	func _sim_tick(_phase: int) -> void:
		riders = 0
		if boss == null or not boss.fist_is_springboard():
			return
		var level: LevelBase = Game.level
		if level == null:
			return
		for hero: PlayerBase in level.contact_order():
			if _catches(hero):
				boss.on_fist_rider(hero, self)

	## The ride test of PlatformBase (a band the platform's height below its top, deeper for a fast fall).
	func _catches(hero: PlayerBase) -> bool:
		if hero.dead or hero.down or hero.yvel <= Tuning.PLATFORM_RIDE_MIN_YVEL_EXCL \
				or hero.carried_on_tick == Sim.total_ticks:
			return false
		var depth: int = box_h
		if hero.yvel >= Tuning.PLATFORM_CATCH_YVEL:
			depth = maxi(box_h, Tuning.PLATFORM_CATCH_DEPTH)
		var band_bottom: int = sim_pos.y - box_h + depth
		if band_bottom <= hero.sim_pos.y:
			return false
		var ride: Vector3i = Tuning.HERO_BOX_RIDE
		return Overlap.test(hero.sim_pos.x, hero.sim_pos.y, ride.x, ride.y, ride.z,
				sim_pos.x, band_bottom, box_w, depth, box_xo, false, hero.yvel, 1)


func _default_skin() -> String:
	return "mangrove"


func _apply_params(params: Dictionary) -> void:
	coop_form = Tusker._coop_form_of(params)
	var expert: bool = Game.difficulty == Defs.Difficulty.EXPERT
	if coop_form:
		stage_hits = (MANGROVE_COOP_HITS_EXPERT if expert else MANGROVE_COOP_HITS_BEGINNER).duplicate()
	else:
		stage_hits = (MANGROVE_HITS_EXPERT if expert else MANGROVE_HITS_BEGINNER).duplicate()
	max_hp = 0
	for hits: int in stage_hits:
		max_hp += hits
	hp_per_pip = 1
	music = Sfx.MUSIC_BOSS_MANGROVE
	boss_drops = [&"fire_starter"]
	super._apply_params(params)
	# The record stands in the floor cell left of the wall: move it to the wall's foot.
	wall_x = (cell_col() + 1) * Tuning.TILE
	floor_y = sim_pos.y
	spawn_pos = Vector2i(wall_x, floor_y)
	teleport(spawn_pos)
	facing = -1
	_spawn_facing = -1
	fist_rest_x = wall_x - MANGROVE_FIST_REST_DX
	fist_draw_x = wall_x - MANGROVE_FIST_DRAW_DX
	fist_out_x = fist_rest_x - MANGROVE_PUNCH_REACH
	hand_home = Vector2i(wall_x, floor_y - MANGROVE_FACE_RISE + 8)
	hand_rest = hand_home + Vector2i(-160, 0)


func _ready() -> void:
	set_box(Vector3i(MANGROVE_TRUNK_PX, MANGROVE_FACE_RISE, MANGROVE_TRUNK_PX))
	var sprite: Sprite2D = get_node_or_null(^"Sprite") as Sprite2D
	if sprite != null:
		sprite.position = Vector2(0.0, -float(MANGROVE_FACE_RISE) * Tuning.ART_SCALE)
	_top = FistTop.new()
	_top.name = "FistTop"
	_top.boss = self
	_top.set_box(Vector3i(MANGROVE_FIST_BOX.x, 8, MANGROVE_FIST_BOX.x >> 1))
	_top.spawn_setup(Vector2i(fist_rest_x, floor_y - MANGROVE_FIST_BOX.y + 8), {})
	_top.visible = false
	add_child(_top)
	_build_parts()
	if Game.level != null and Game.level.grid != null:
		_find_hand_rest()
	Spawner.preload_ids([BUG_ID, LEAF_ID])
	_reset_parts()


# =================================================================================================================
# Queries (tests, tools)
# =================================================================================================================

## Stage 1, 2 or 3 (co-op: 1 = the merged face-and-hand stage, 3 = the fist).
func get_stage() -> int:
	if hp <= stage_hits[stage_hits.size() - 1]:
		return 3
	if coop_form:
		return 1
	return 2 if hp <= stage_hits[1] + stage_hits[2] else 1


func get_fist_state() -> int:
	return _fist


func get_hand_state() -> int:
	return _hand


## The fist's box this tick (logical px; on the floor).
func get_fist_rect() -> Rect2i:
	return Rect2i(_fist_x - (MANGROVE_FIST_BOX.x >> 1), floor_y - MANGROVE_FIST_BOX.y, MANGROVE_FIST_BOX.x,
			MANGROVE_FIST_BOX.y)


## The face's weak rectangle.
func get_face_rect() -> Rect2i:
	var feet: Vector2i = Vector2i(wall_x, floor_y - MANGROVE_FACE_RISE)
	return Rect2i(feet + MANGROVE_FACE.position, MANGROVE_FACE.size)


## The upper hand's box this tick (empty while it is in the wall).
func get_hand_rect() -> Rect2i:
	if _hand == Hand.AWAY or _hand == Hand.SHAKE:
		return Rect2i()
	return Rect2i(_hand_pos.x - (MANGROVE_HAND_BOX.x >> 1), _hand_pos.y - MANGROVE_HAND_BOX.y, MANGROVE_HAND_BOX.x,
			MANGROVE_HAND_BOX.y)


## The trunk strip under the face.
func get_trunk_rect() -> Rect2i:
	var top: int = floor_y - MANGROVE_FACE_RISE
	return Rect2i(wall_x - MANGROVE_TRUNK_PX, top, MANGROVE_TRUNK_PX, MANGROVE_FACE_RISE)


## The side the stuck fist's knuckle armour faces (co-op stage 3).
func get_fist_facing() -> int:
	return _fist_facing


## True while the fist rests on the floor (the springboard).
func fist_is_springboard() -> bool:
	return fighting and not dead and _dying < 0 and _fist == Fist.REST and _fist_x == fist_rest_x


## The twin window of this game (co-op).
func twin_window() -> int:
	return PartyTuning.window_ticks(Game.difficulty, MANGROVE_SOLO_MIN_TICKS)


# =================================================================================================================
# Life cycle
# =================================================================================================================

func _on_reset() -> void:
	_remove_bugs()
	_reset_parts()
	_dying = -1
	punches = 0
	sweeps = 0
	launches = 0
	twins = 0


func _reset_parts() -> void:
	_stage = 0
	_fist = Fist.REST
	_fist_timer = 0
	_fist_len = MANGROVE_FIRST_REST
	_fist_x = fist_rest_x
	_burst_left = 0
	_first_burst = true
	_fist_facing = -1
	_hand = Hand.AWAY
	_hand_timer = 0
	_hand_pos = hand_home
	_face_slot = -1
	_face_tick = -1
	_hand_slot = -1
	_hand_tick = -1
	_pinned = 0
	_pin_gone = 0
	_pin_mask = 0
	_count_in = -1
	_part_tick.clear()
	_place_parts()


func _on_lethal_hit() -> void:
	_dying = 0
	_remove_bugs()
	_play(&"hurt", true)
	Audio.play_sfx(Sfx.BOSS_ROAR)


func _on_defeated() -> void:
	visible = true
	_play(&"dead", true)
	_fist = Fist.GONE
	_hand = Hand.AWAY
	_place_parts()


func _ai_tick() -> void:
	if dead:
		_play(&"dead")
		return
	if _dying >= 0:
		_dying += 1
		_play(&"dead" if _dying > 8 else &"hurt")
		_fist_x = mini(_fist_x + MANGROVE_HAND_SPEED, wall_x)
		_hand_pos = _step_toward(_hand_pos, hand_home, MANGROVE_HAND_SPEED)
		_place_parts()
		if _dying >= MANGROVE_DYING_TICKS:
			defeat(boss_drops)
		return
	var target: PlayerBase = _target_hero()
	if not fighting:
		_play(&"idle")
		if _wakes_for_any(target):
			start_fight()
		if not fighting:
			_place_parts()
			return
	var stage: int = get_stage()
	if stage != _stage:
		_enter_stage(stage)
	_poll_parts()
	if dead or _dying >= 0:
		return
	_fist_tick(target)
	_hand_tick_update()
	_count_in_tick()
	_contact_every()
	_place_parts()
	if _anim_role != &"hurt" or _anim_done():
		_play(&"charge" if _hand == Hand.SHAKE else (&"attack" if _fist == Fist.DRAW else &"idle"))


func _enter_stage(stage: int) -> void:
	_stage = stage
	if stage == 3:
		if _hand != Hand.AWAY:
			_hand = Hand.RETRACT
		_raise_bugs()
	elif stage == 2 or coop_form:
		_hand = Hand.AWAY
		_hand_timer = MANGROVE_HAND_PAUSE - MANGROVE_HAND_FIRST_PAUSE


# =================================================================================================================
# The fist
# =================================================================================================================

func _fist_tick(target: PlayerBase) -> void:
	_fist_timer += 1
	match _fist:
		Fist.REST:
			_fist_x = fist_rest_x
			var standing: int = _standing_mask() if coop_form else 0
			var ridden: bool = standing != 0
			_pin_gone = 0 if ridden else _pin_gone + 1
			var pinned_now: bool = ridden or (_pinned > 0 and _pin_gone <= MANGROVE_PIN_GRACE)
			if pinned_now:
				_pin_mask |= standing
				_pinned += 1
				if _pinned >= MANGROVE_PIN_TICKS:
					_fling()
				return
			_pinned = 0
			_pin_mask = 0
			if _fist_timer >= _fist_len:
				_start_burst()
		Fist.DRAW:
			_fist_x = _fist_from + (fist_draw_x - _fist_from) * mini(_fist_timer, MANGROVE_DRAW_TICKS) \
					/ MANGROVE_DRAW_TICKS
			if _fist_timer >= MANGROVE_DRAW_TICKS:
				_set_fist(Fist.OUT)
				_punch_effects(target)
		Fist.OUT:
			var from: int = _fist_x
			_fist_x = fist_draw_x + (fist_out_x - fist_draw_x) * _fist_timer / MANGROVE_OUT_TICKS
			_punch_heroes(from)
			if _fist_timer >= MANGROVE_OUT_TICKS:
				_burst_left -= 1
				if _burst_left <= 0 and _stage == 3:
					_set_fist(Fist.STUCK)
					_play(&"hurt", true)
				else:
					_set_fist(Fist.BACK)
		Fist.BACK:
			_fist_x = fist_rest_x
			if _fist_timer >= MANGROVE_BACK_TICKS:
				if _burst_left > 0:
					_fist_from = _fist_x
					_set_fist(Fist.DRAW)
					Audio.play_sfx(Sfx.ENEMY_VOICE)
				else:
					_set_fist(Fist.REST)
					_fist_len = Sim.rng.range_int(MANGROVE_REST_MIN, MANGROVE_REST_MAX)
		Fist.STUCK:
			_fist_x = fist_out_x
			if coop_form:
				var nearer: PlayerBase = _nearest_to(Vector2i(_fist_x, floor_y))
				if nearer != null:
					_fist_facing = 1 if nearer.sim_pos.x >= _fist_x else -1
			if _fist_timer >= MANGROVE_STUCK_TICKS:
				_set_fist(Fist.BACK)


func _set_fist(state: int) -> void:
	_fist = state
	_fist_timer = 0


func _start_burst() -> void:
	if _stage == 3:
		_burst_left = MANGROVE_BURST_MAX
	elif _first_burst:
		_burst_left = MANGROVE_FIRST_BURST
	else:
		_burst_left = Sim.rng.range_int(MANGROVE_BURST_MIN, MANGROVE_BURST_MAX)
	_first_burst = false
	_pinned = 0
	_fist_from = _fist_x
	_set_fist(Fist.DRAW)
	Audio.play_sfx(Sfx.ENEMY_VOICE)


## A punch leaves: shake, shove, a leaf over the target, the bugs back down.
func _punch_effects(target: PlayerBase) -> void:
	punches += 1
	var level: LevelBase = Game.level
	level.request_shake(MANGROVE_PUNCH_SHAKE)
	Audio.play_sfx(Sfx.QUAKE)
	for hero: PlayerBase in level.contact_order():
		if hero.dead or hero.is_down() or not hero.is_grounded() or hero.sim_pos.y != floor_y:
			continue
		var x: int = hero.sim_pos.x - MANGROVE_SHOVE_PX
		var probe: int = x - (hero.box_xo + 1)
		if level.grid.side_at(Tuning.to_cell(probe), Tuning.to_cell(hero.sim_pos.y - 1)) != TileGrid.SIDE_WALL:
			hero.sim_pos.x = x
	if target != null:
		_spawn_optional(LEAF_ID, target.sim_pos, {"skin": "leaf", "rain": true, "rain_slot": target.slot})
	_send_bugs_down()


## The moving fist (its sweep from `from` to where it is now) against every hero: 3 bones and the knock-back.
func _punch_heroes(from: int) -> void:
	var half: int = MANGROVE_FIST_BOX.x >> 1
	var left: int = mini(from, _fist_x) - half
	var right: int = maxi(from, _fist_x) + half
	var swept: Rect2i = Rect2i(left, floor_y - MANGROVE_FIST_BOX.y, right - left, MANGROVE_FIST_BOX.y)
	for hero: PlayerBase in Game.level.contact_order():
		if hero.dead or hero.is_down() or hero.is_immune() or hero.is_feasting():
			continue
		if Overlap.rects(hero.get_box(), swept) and touch_hero(hero):
			for i: int in MANGROVE_PUNCH_BONES - 1:
				if hero.run.lose_bone():
					hero.kill(&"enemy")
					break


# =================================================================================================================
# The springboard and the co-op pin (FistTop, PLATFORMS phase)
# =================================================================================================================

## A hero's feet reached the resting fist's top this tick: launch him (solo; co-op with Up held), or let him stand on
## it and pin it (co-op).
func on_fist_rider(hero: PlayerBase, top: FistTop) -> void:
	var up: bool = (hero.input_flags & Defs.IN_UP) != 0
	if coop_form and not up:
		hero.carried_on_tick = Sim.total_ticks
		hero.ride_platform(top, 0, 0)
		top.riders |= 1 << hero.slot
		return
	hero.sim_pos.y = top.sim_pos.y - top.box_h
	hero.bounce(Tuning.BOUNCE_YVEL_UP if up else Tuning.BOSS_LAUNCH_YVEL)
	launches += 1
	Audio.play_sfx(Sfx.BOUNCE)


## Co-op: bit per slot - the heroes standing on the resting fist this tick: caught by its top in the last PLATFORMS
## phase, or with their feet on or just over it and not jumping (the screen-shake nudge of PHYSICS.md 13.3 lifts a
## standing hero up to 3 px over it for a few ticks, out of the ride band; he still stands there).
func _standing_mask() -> int:
	var mask: int = _top.riders if _top != null else 0
	var top_y: int = floor_y - MANGROVE_FIST_BOX.y
	for hero: PlayerBase in Game.level.contact_order():
		if hero.dead or hero.is_down() or hero.yvel <= Tuning.PLATFORM_RIDE_MIN_YVEL_EXCL:
			continue
		if absi(hero.sim_pos.x - _fist_x) <= (MANGROVE_FIST_BOX.x >> 1) \
				and hero.sim_pos.y >= top_y - MANGROVE_PIN_HOVER_PX and hero.sim_pos.y <= top_y + 2:
			mask |= 1 << hero.slot
	return mask


## Co-op: the pin is over - every hero who pinned it and still stands on (or just over) the fist is flung off upwards.
func _fling() -> void:
	_pinned = 0
	var top_y: int = floor_y - MANGROVE_FIST_BOX.y
	for hero: PlayerBase in Game.level.contact_order():
		if (_pin_mask & (1 << hero.slot)) == 0 or hero.dead or hero.is_down():
			continue
		var over: bool = absi(hero.sim_pos.x - _fist_x) <= (MANGROVE_FIST_BOX.x >> 1) + 8 \
				and hero.sim_pos.y >= top_y - 8 and hero.sim_pos.y <= top_y + 8
		if over:
			hero.launch(PlayerBase.LAUNCH_KEEP, MANGROVE_FLING_YVEL)
			launches += 1
	_pin_mask = 0
	Audio.play_sfx(Sfx.BOUNCE)
	_start_burst()


# =================================================================================================================
# The upper hand
# =================================================================================================================

func _hand_tick_update() -> void:
	var active: bool = _stage != 3 and (_stage == 2 or coop_form)
	_hand_timer += 1
	match _hand:
		Hand.AWAY:
			_hand_pos = hand_home
			if active and _hand_timer >= MANGROVE_HAND_PAUSE:
				_set_hand(Hand.SHAKE)
				Audio.play_sfx(Sfx.QUAKE)
		Hand.SHAKE:
			if _hand_timer % 4 == 1:
				Game.level.request_shake(EnemyTuning.BOSS_BOB_SHAKE)
			if _hand_timer >= MANGROVE_SHAKE_TICKS:
				_set_hand(Hand.SWEEP)
				sweeps += 1
				_hand_pos = hand_home
				Audio.play_sfx(Sfx.CLUB_SWING)
		Hand.SWEEP:
			var from: Vector2i = _hand_pos
			_hand_pos = _step_toward(_hand_pos, hand_rest, MANGROVE_HAND_SPEED)
			_sweep_heroes(from)
			if _hand_pos == hand_rest:
				_set_hand(Hand.REST)
		Hand.REST:
			if _hand_timer >= MANGROVE_HAND_REST_TICKS or not active:
				_set_hand(Hand.RETRACT)
		Hand.RETRACT:
			_hand_pos = _step_toward(_hand_pos, hand_home, MANGROVE_HAND_SPEED)
			if _hand_pos == hand_home:
				_set_hand(Hand.AWAY)


func _set_hand(state: int) -> void:
	_hand = state
	_hand_timer = 0


func _sweep_heroes(from: Vector2i) -> void:
	var box: Rect2i = get_hand_rect()
	var swept: Rect2i = box.merge(Rect2i(from - Vector2i(MANGROVE_HAND_BOX.x >> 1, MANGROVE_HAND_BOX.y),
			MANGROVE_HAND_BOX))
	for hero: PlayerBase in Game.level.contact_order():
		if hero.dead or hero.is_down() or hero.is_immune() or hero.is_feasting():
			continue
		if Overlap.rects(hero.get_box(), swept):
			touch_hero(hero)


## The upper ledge: the highest row of one-way floor cells in the room left of the wall (its rightmost run); the hand
## rests at that run's right end with its fingers hooked MANGROVE_HAND_SINK below the ledge top.
func _find_hand_rest() -> void:
	var grid: TileGrid = Game.level.grid
	var room: Rect2i = _room()
	var first_row: int = maxi(Tuning.to_cell(room.position.y), 0)
	var last_row: int = Tuning.to_cell(floor_y) - 3
	var last_col: int = Tuning.to_cell(wall_x) - 1
	var first_col: int = maxi(Tuning.to_cell(room.position.x), 0)
	for row: int in range(first_row, last_row + 1):
		for col: int in range(last_col, first_col - 1, -1):
			var ch: String = grid.get_char(col, row)
			if ch == TileGrid.CH_ONEWAY_A or ch == TileGrid.CH_ONEWAY_B:
				var right: int = (col + 1) * Tuning.TILE
				hand_rest = Vector2i(right - (MANGROVE_HAND_BOX.x >> 1), row * Tuning.TILE + MANGROVE_HAND_SINK)
				hand_home = Vector2i(wall_x, hand_rest.y)
				return


# =================================================================================================================
# Hits
# =================================================================================================================

## Every weapon against the parts this tick (thrown weapons newest first, then every hero's club box): the weak point
## of the stage counts (1 per hit), the other parts glance. One call per tick: it runs the hit cooldown.
func _poll_parts() -> void:
	if hit_cooldown > 0:
		hit_cooldown -= 1
	if _glance_ticks > 0:
		_glance_ticks -= 1
	var level: LevelBase = Game.level
	if level == null or not fighting:
		return
	var face: Rect2i = get_face_rect()
	var hand: Rect2i = get_hand_rect() if _hand == Hand.REST else Rect2i()
	var fist: Rect2i = get_fist_rect() if _fist == Fist.STUCK else Rect2i()
	var projectiles: Array[SimEntity] = level.get_kind(Defs.Kind.HERO_PROJECTILE)
	for i: int in range(projectiles.size() - 1, -1, -1):
		var shot: ProjectileBase = projectiles[i] as ProjectileBase
		if shot == null or shot.spent:
			continue
		var box: Rect2i = shot.get_box()
		var hero: PlayerBase = level.get_hero(shot.owner_slot)
		for part: Array in [[&"face", face], [&"hand", hand], [&"fist", fist]]:
			var rect: Rect2i = part[1]
			if rect.size.x > 0 and Overlap.rects(box, rect):
				shot.consume()
				_strike(part[0], hero, shot.owner_slot, box.get_center())
				break
		if dead or _dying >= 0:
			return
	for hero: PlayerBase in level.contact_order():
		if not hero.club_box_active:
			continue
		for part: Array in [[&"face", face], [&"hand", hand], [&"fist", fist]]:
			var rect: Rect2i = part[1]
			if rect.size.x > 0 and Overlap.rects(hero.club_box, rect):
				if _strike(part[0], hero, hero.slot, hero.club_box.intersection(rect).get_center()):
					hero.notify_weapon_hit()
				break
		if dead or _dying >= 0:
			return


## A weapon met a part (`what`: face, hand, fist) - struck by `hero` of player slot `slot` at `at`. True when it
## counted (or lit a co-op twin half).
func _strike(what: StringName, hero: PlayerBase, slot: int, at: Vector2i) -> bool:
	var level: LevelBase = Game.level
	var now: int = Sim.total_ticks
	var weak: bool = false
	match what:
		&"face":
			weak = _stage == 1
		&"hand":
			weak = (_stage == 2 and not coop_form) or (_stage == 1 and coop_form)
		&"fist":
			weak = _stage == 3 and (not coop_form or _from_wrist(hero))
	if not weak:
		_clank(level, at)
		return false
	if int(_part_tick.get(what, -1000)) > now - MANGROVE_PART_DEBOUNCE:
		return false
	_part_tick[what] = now
	if coop_form and _stage == 1:
		return _twin_half(what, slot, at)
	if hit_cooldown > 0:
		return false
	_note_hitter(level, slot)
	_count_hit(what)
	return true


## Co-op twin: light the face or the hand for the hitter; a twin hit counts once both are lit by the two heroes
## within the window.
func _twin_half(what: StringName, slot: int, at: Vector2i) -> bool:
	var now: int = Sim.total_ticks
	if what == &"face":
		_face_slot = slot
		_face_tick = now
	else:
		_hand_slot = slot
		_hand_tick = now
	Audio.play_sfx(Sfx.DRUM)
	Game.level.spawn_fx(&"fx/hit_stars", at)
	var window: int = twin_window()
	if _face_tick < 0 or _hand_tick < 0 or _face_slot == _hand_slot or slot < 0:
		return true
	if absi(_face_tick - _hand_tick) >= window or hit_cooldown > 0:
		return true
	_face_tick = -1
	_hand_tick = -1
	twins += 1
	_note_hitter(Game.level, slot)
	_count_hit(&"twin")
	return true


func _count_hit(what: StringName) -> void:
	apply_boss_hit(1)
	if dead or _dying >= 0:
		return
	_play(&"hurt", true)
	Audio.play_sfx(Sfx.BOSS_ROAR)
	if what == &"face" and _fist == Fist.REST:
		# The face roars and the fist answers: the rest is cut short.
		_fist_len = mini(_fist_len, _fist_timer + MANGROVE_FACE_HIT_REST)


## Co-op stage 3: true when `hero` strikes the stuck fist from the wrist side (away from the knuckle armour).
func _from_wrist(hero: PlayerBase) -> bool:
	if hero == null or not is_instance_valid(hero):
		return false
	var dx: int = hero.sim_pos.x - _fist_x
	return absi(dx) >= EnemyTuning.FRONT_DX and signi(dx) == -_fist_facing


func _clank(level: LevelBase, at: Vector2i) -> void:
	if _glance_ticks > 0:
		return
	_glance_ticks = GLANCE_TICKS
	Audio.play_sfx(Sfx.CLUB_HIT_SCENERY)
	level.spawn_fx(&"fx/hit_stars", at)


## Co-op count-in: three blips 8 ticks apart while the hand rests and a hero stands pinned on the fist, then "go".
func _count_in_tick() -> void:
	if not coop_form or _stage != 1 or _hand != Hand.REST or _pinned == 0:
		_count_in = -1
		return
	_count_in += 1
	if _count_in > PartyTuning.COUNT_IN_BEEPS * MANGROVE_COUNT_IN_TICKS:
		return
	if _count_in % MANGROVE_COUNT_IN_TICKS == 0:
		var go: bool = _count_in == PartyTuning.COUNT_IN_BEEPS * MANGROVE_COUNT_IN_TICKS
		Audio.play_sfx(Sfx.COUNTDOWN_GO if go else Sfx.COUNT_IN)


# =================================================================================================================
# Contact
# =================================================================================================================

## The trunk against every hero (a bone, pushed back); the moving fist and the sweeping hand hurt in their own ticks.
func _contact_every() -> void:
	var trunk: Rect2i = get_trunk_rect()
	for hero: PlayerBase in Game.level.contact_order():
		if hero.dead or hero.is_down() or hero.is_immune() or hero.is_feasting():
			continue
		if Overlap.rects(hero.get_box(), trunk):
			touch_hero(hero)


# =================================================================================================================
# Bugs (stage 3)
# =================================================================================================================

func _raise_bugs() -> void:
	if _bugs != null and is_instance_valid(_bugs):
		return
	var room: Rect2i = _room()
	var zone: String = "%d,%d,%d,%d" % [Tuning.to_cell(room.position.x), Tuning.to_cell(room.position.y),
		maxi(room.size.x >> 4, 1), maxi(room.size.y >> 4, 1)]
	var at: Vector2i = Vector2i((room.position.x + wall_x) >> 1, floor_y)
	_bugs = _spawn_optional(BUG_ID, at, {"zone": zone, "pause": MANGROVE_BUG_PAUSE, "max": 1, "skin": "lizard"}) \
			as EnemyBase


func _send_bugs_down() -> void:
	if Game.level == null:
		return
	for entity: SimEntity in Game.level.get_kind(Defs.Kind.ENEMY):
		var bug: Digger = entity as Digger
		if bug != null and bug.is_copy() and bug.awake and not bug.dead and bug.is_targetable():
			bug.sleep()


func _remove_bugs() -> void:
	_send_bugs_down()
	if _bugs != null and is_instance_valid(_bugs):
		_bugs._coop_remove()
	_bugs = null


# =================================================================================================================
# Pictures (cosmetic)
# =================================================================================================================

func _build_parts() -> void:
	_parts = Node2D.new()
	_parts.name = "Parts"
	_parts.z_index = 1
	add_child(_parts)
	_fist_sprite = _part_sprite(FRAME_FIST)
	_hand_sprite = _part_sprite(FRAME_HAND)
	for i: int in ARM_LINKS:
		_links.append(_part_sprite(FRAME_ARM + i % ARM_SEGMENTS))
		_hand_links.append(_part_sprite(FRAME_ARM + i % ARM_SEGMENTS))


func _part_sprite(frame: int) -> Sprite2D:
	var sprite: Sprite2D = Sprite2D.new()
	sprite.texture = PARTS_TEXTURE
	sprite.hframes = PARTS_COLUMNS
	sprite.frame = frame
	sprite.centered = false
	sprite.offset = -PARTS_PIVOT
	_parts.add_child(sprite)
	return sprite


## Put the fist, the hand and their root arms where the simulation has them (art px, relative to the wall's foot).
func _place_parts() -> void:
	if _parts == null:
		return
	var origin: Vector2 = Vector2(sim_pos)
	var fist_on: bool = _fist != Fist.GONE
	_fist_sprite.visible = fist_on
	_fist_sprite.position = (Vector2(_fist_x, floor_y) - origin) * Tuning.ART_SCALE
	_fist_sprite.frame = FRAME_FIST_FLASH if _fist == Fist.OUT or _fist == Fist.STUCK else FRAME_FIST
	_chain(_links, Vector2(wall_x, floor_y - 12), Vector2(_fist_x + 12, floor_y - 12), fist_on)
	var hand_on: bool = _hand == Hand.SWEEP or _hand == Hand.REST or _hand == Hand.RETRACT
	_hand_sprite.visible = hand_on
	_hand_sprite.position = (Vector2(_hand_pos) - origin) * Tuning.ART_SCALE
	_chain(_hand_links, Vector2(hand_home), Vector2(_hand_pos.x + 12, _hand_pos.y - 12), hand_on)


func _chain(links: Array[Sprite2D], from: Vector2, to: Vector2, on: bool) -> void:
	var origin: Vector2 = Vector2(sim_pos)
	for i: int in links.size():
		var t: float = (float(i) + 0.5) / float(links.size())
		var point: Vector2 = from.lerp(to, t)
		links[i].visible = on and from.distance_to(to) > 24.0
		links[i].position = (point + Vector2(0.0, 16.0) - origin) * Tuning.ART_SCALE
		links[i].rotation = PI * 0.5


# =================================================================================================================
# Helpers
# =================================================================================================================

## The fight room in logical px: the arena zone's rectangle, else the camera lock, else one base screen left of it.
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
	return Rect2i(wall_x - Tuning.VIEW_W, floor_y - Tuning.VIEW_H + Tuning.TILE, Tuning.VIEW_W, Tuning.VIEW_H)


## The hatched hero nearest to `point` (|dx| + |dy|, ties to the lower slot), null when none.
func _nearest_to(point: Vector2i) -> PlayerBase:
	var best: PlayerBase = null
	var best_distance: int = 1 << 30
	for hero: PlayerBase in Game.level.contact_order():
		if hero.dead or hero.is_down():
			continue
		var distance: int = absi(hero.sim_pos.x - point.x) + absi(hero.sim_pos.y - point.y)
		if distance < best_distance:
			best = hero
			best_distance = distance
	return best


## One step of at most `speed` px per axis from `from` towards `to`.
static func _step_toward(from: Vector2i, to: Vector2i, speed: int) -> Vector2i:
	return Vector2i(from.x + clampi(to.x - from.x, -speed, speed), from.y + clampi(to.y - from.y, -speed, speed))


func _burst_origin() -> Vector2i:
	return get_face_rect().get_center()


## The level's drops come out on the floor in front of the trunk strip, half a cell out from the wall: from the face
## (inside the bark wall) a drop without sideways speed stayed in the wall and a locked exit could never open
## (wf8_D6_to_enemies_b.txt). The bonus burst still flies out of the face.
func _drop_origin() -> Vector2i:
	return Vector2i(wall_x - MANGROVE_TRUNK_PX - (Tuning.TILE >> 1), floor_y - Tuning.TILE)


## Wake rule (BossBase._wakes_for_any): a hero within MANGROVE_WAKE_RANGE px of the wall, at most a screen up or down.
func _wakes_for(hero: PlayerBase) -> bool:
	return absi(hero.sim_pos.x - wall_x) < MANGROVE_WAKE_RANGE and absi(hero.sim_pos.y - floor_y) < Tuning.VIEW_H
