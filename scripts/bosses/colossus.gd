class_name Colossus
extends BossBase
## `bosses/colossus` - BOSS 2, the Wall Colossus (minotaur archetype, GAMEPLAY.md 6.3).
##
## A statue that is part of the arena's right-hand wall. Place it in the floor-level air cell just left of that wall:
## the feet point is the bottom-RIGHT corner of the picture (ASSET_MANIFEST.md 5) and is put 32 px inside the wall,
## so that the stone rim drawn in the last 64 art px of every frame covers the face of the wall.
## Only thrown weapons that reach its head count, each for exactly 1 hit point (24 = 6 pips of 4); the head moves
## with the pose, so the vulnerable rectangle changes with every animation. Its body costs the hero a bone.
## Pattern: breathing idle loops alternating with attacks - it spits a rock that bounces along the floor to the
## left (`projectiles/boss_rock`) or slams the wall so that a stalactite drops from the ceiling at a random x in the
## left part of the room (`projectiles/boss_stalactite`). The pauses shorten as it weakens (three phases). Every
## hit makes it roar in the hurt pose; the 1st hit and every 4th after it start a rage: one rock and two stalactites
## in quick succession. Defeat: the broken pose stays, 4 trophies fly out with the bonus burst.
##
## Fairness rules (tuned in wf4, numbers in EnemyTuning): every attack shows its pose for at least 10 ticks before
## anything can reach the hero (the rearing open jaws before a rock, the red rage pose before its rock, the slam plus
## the stalactite's rattle before a drop). Hits never stop the attacks: the idle clock runs on through hurt poses
## (an attack that fell due during one follows the roar at once), and an attack that is under way when a hit lands
## is finished first - the roar (hurt pose, and the rage when one is due) comes after it.
##
## Parameters: `arena` zone name, `hp` [24], `drops` [trophy,trophy,trophy,trophy].
##
## 2.0 co-op form, the **visor** (DESIGN.md B.7, GAMEPLAY.md 13.6; enemies-C, PLAN.md P2.3) - only in a co-op game of two
## heroes on a co-op file (`kind = coop`: w4_l2b_coop); everywhere else, a party of one included, the statue above
## runs unchanged. Hit points x2/3 (24 -> 16, 4 pips; wf10 boss balance: the x5/4 form took a duo 137 s, the target is
## 45-90 s), its idle pauses shortening after 14 hits taken (as the x5/4 form's did). A stone visor covers its face; the two `objects/plate` of the hall (the
## left-most and the right-most plate inside its room) hold its chains, and the visor is up only while an ACTIVE hero
## (PlayerBase.counts_for_coop: hatched, not idle - DESIGN.md G33) stands on the plate whose chain glows
## (Plate.holder_mask, its last weight test, which weighs no dozing hero; checked here too). Thrown weapons only, as
## in 1.0, and a throw counts only while the visor is up and its thrower is not the one holding the plate: the holder
## dodges, the other hero throws. Rocks are spat at the plate holder (the 1.0 speeds, aimed), the ceiling drops rattle
## over the thrower. Each rage (the 1st hit and every 4th) moves the live chain to the other plate: the roles swap. A
## hall without two plates is a content error (warned once): its visor then stays up and only the holder rule is lost.
##
## 2.0 versus, the **neutral statue** of Colossus Hall (DESIGN.md E.5 / G43): in an arena (`kind = arena`) it is a
## picture in the wall ([method is_neutral]) - no hits, no bar, no music, no wake, no rocks or drops of its own, a body
## that neither hurts nor blocks; world-B's referee spits at the leader through [method arena_spit] /
## [method arena_mouth] (scripts/world/versus/signatures.gd).

enum State { DORMANT, IDLE, SPIT, SLAM, HURT, RAGE, BROKEN }
enum Attack { SPIT, SLAM }

const ROCK_ID: StringName = &"projectiles/boss_rock"
const STALACTITE_ID: StringName = &"projectiles/boss_stalactite"
## The attack loop: spit, slam, spit, slam, slam (idle pauses in EnemyTuning.COLOSSUS_IDLE_TICKS).
const LOOP: Array[int] = [Attack.SPIT, Attack.SLAM, Attack.SPIT, Attack.SLAM, Attack.SLAM]

var _state: int = State.DORMANT
var _timer: int = 0
var _step: int = 0
var _hits: int = 0
## Ticks of breathing since the last attack ended (hurt poses count): the next attack starts when it reaches
## the idle length of the loop step.
var _clock: int = 0
## A hit landed during an attack: the hurt pose follows the attack.
var _hurt_due: bool = false
## A hit that starts a rage (the 1st and every 4th after it) landed: the rage follows its hurt pose.
var _rage_due: bool = false

# 2.0 co-op form (every field keeps its default in a party of one).
## Co-op rock aim: a rock leaves the jaws flat and lands about this many ticks later.
const COOP_ROCK_FALL_TICKS: int = 12
## Co-op hit points = the solo hit points x COOP_HP_NUM / COOP_HP_DEN (24 -> 16). wf10 boss balance (orchestrator: a
## co-op boss fight lasts 45-90 s for a competent pair): with x5/4 (30) the visor fight took DB3's duo 137 s, every
## role swap costing a walk across the hall; 16 hits take the same duo about 70 s. (tune)
const COOP_HP_NUM: int = 2
const COOP_HP_DEN: int = 3
## Co-op idle phases: the pauses shorten after this many hits taken (the x5/4 form's 30 - 16 and 30 - 8). (tune)
const COOP_PHASE_TAKEN: Array[int] = [14, 22]
var _coop: bool = false
var _solo_hp: int = 0
## The hall's two plates (left-most, right-most) and the index of the one whose chain glows.
var _plates: Array[Plate] = []
var _live: int = 0
var _visor: Node2D = null
static var _warned_plates: bool = false

# 2.0 versus: the neutral statue of an arena (Colossus Hall). -1 = not decided yet.
## The open-jaw pose stays this long after the referee's rock left.
const ARENA_SPIT_LINGER_TICKS: int = 6
var _neutral: int = -1
var _arena_spit_left: int = 0


func _default_skin() -> String:
	return "colossus"


func _apply_params(params: Dictionary) -> void:
	max_hp = EnemyTuning.COLOSSUS_HP
	hp_per_pip = EnemyTuning.COLOSSUS_HP_PER_PIP
	thrown_only = true
	music = Sfx.MUSIC_BOSS_FINAL
	boss_drops = [&"trophy", &"trophy", &"trophy", &"trophy"]
	super._apply_params(params)
	_solo_hp = max_hp
	facing = 1
	_spawn_facing = 1
	spawn_pos.x += (Tuning.TILE >> 1) + EnemyTuning.COLOSSUS_RIM_PX
	teleport(spawn_pos)


func _ready() -> void:
	set_box(EnemyTuning.COLOSSUS_BOX)


## Current state (State), for tests and tools.
func get_state() -> int:
	return _state


## The weak point this tick (logical px): the head rectangle of the current pose.
func get_head_rect() -> Rect2i:
	var head: Rect2i = EnemyTuning.COLOSSUS_HEAD_IDLE
	match _anim_role:
		&"spit", &"rage":
			head = EnemyTuning.COLOSSUS_HEAD_SPIT
		&"slam":
			head = EnemyTuning.COLOSSUS_HEAD_SLAM
		&"hurt":
			head = EnemyTuning.COLOSSUS_HEAD_HURT
	return Rect2i(sim_pos + head.position, head.size)


## Hits taken so far (rage every 4th), for tests and tools.
func get_hits() -> int:
	return _hits


## 2.0: true in the co-op form (the visor).
func is_coop_form() -> bool:
	return _coop


## 2.0 co-op: true while the visor is up (an active hero on the live plate; always false in the solo form).
func is_visor_up() -> bool:
	if not _coop:
		return false
	var plate: Plate = get_live_plate()
	return plate == null or _holder() != null


## 2.0 co-op: the plate whose chain glows (null without plates).
func get_live_plate() -> Plate:
	if _plates.size() < 2:
		return null
	return _plates[_live]


## 2.0 co-op: the hall's plates found for the visor (left-most first).
func get_plates() -> Array[Plate]:
	return _plates


func _on_reset() -> void:
	_state = State.DORMANT
	_timer = 0
	_step = 0
	_hits = 0
	_clock = 0
	_hurt_due = false
	_rage_due = false
	set_box(EnemyTuning.COLOSSUS_BOX)
	if _coop:
		_coop = false
		_live = 0
		max_hp = _solo_hp
		hp = max_hp
		_show_visor()


func _burst_origin() -> Vector2i:
	var head: Rect2i = get_head_rect()
	return head.position + head.size / 2


func _on_defeated() -> void:
	_state = State.BROKEN
	visible = true
	_play(&"dead", true)


func _ai_tick() -> void:
	if dead:
		_play(&"dead")
		return
	if _neutral != 0 and is_neutral():
		_neutral_tick()
		return
	var hero: PlayerBase = _target_hero()
	if not fighting:
		_play(&"idle")
		if _wakes_for_any(hero):
			start_fight()
		if not fighting:
			return
	if _state == State.DORMANT:
		_begin_idle()
	var power: int = _coop_poll() if _coop else poll_weapon_hit(get_head_rect())
	if power > 0 and _state == State.RAGE:
		# The red rage pose is armoured: the weapon glances off.
		Audio.play_sfx(Sfx.CLUB_HIT_SCENERY)
		power = 0
	if power > 0:
		apply_boss_hit(power)
		if dead:
			return
		# Its own cooldown: the next hit counts once the roar (hurt pose) is over.
		hit_cooldown = maxi(hit_cooldown, EnemyTuning.COLOSSUS_HURT_TICKS)
		_hits += 1
		var rage: bool = (_hits - 1) % EnemyTuning.COLOSSUS_RAGE_EVERY == 0
		_rage_due = _rage_due or rage
		if _coop and rage and _plates.size() >= 2:
			# 2.0 co-op: every rage moves the live chain to the other plate (the roles swap).
			_live = 1 - _live
		Audio.play_sfx(Sfx.BOSS_ROAR)
		if _state == State.IDLE:
			_begin_hurt()
		else:
			_hurt_due = true
	_touch_every(hero)
	_timer += 1
	if _state == State.IDLE or _state == State.HURT:
		_clock += 1
	match _state:
		State.IDLE:
			_play(&"idle")
			if _clock >= _idle_length():
				_begin_attack()
		State.SPIT:
			if _timer == EnemyTuning.COLOSSUS_SPIT_RELEASE_TICK:
				_spit()
			if _timer >= EnemyTuning.COLOSSUS_SPIT_TICKS:
				_end_attack(true)
		State.SLAM:
			if _timer == EnemyTuning.COLOSSUS_SLAM_RELEASE_TICK:
				_drop_stalactite()
			if _timer >= EnemyTuning.COLOSSUS_SLAM_TICKS:
				_end_attack(true)
		State.HURT:
			if _timer >= EnemyTuning.COLOSSUS_HURT_TICKS:
				if _rage_due:
					_rage_due = false
					_state = State.RAGE
					_timer = 0
					_play(&"rage", true)
				elif _clock >= _idle_length():
					_begin_attack()
				else:
					_state = State.IDLE
					_play(&"idle", true)
		State.RAGE:
			if _timer == EnemyTuning.COLOSSUS_RAGE_ROCK_TICK:
				_spit()
			elif _timer == EnemyTuning.COLOSSUS_RAGE_DROP_TICK_A or _timer == EnemyTuning.COLOSSUS_RAGE_DROP_TICK_B:
				_drop_stalactite()
			if _timer >= EnemyTuning.COLOSSUS_RAGE_TICKS:
				_end_attack(false)
	if _coop:
		_show_visor()


# =================================================================================================================
# Internals
# =================================================================================================================

## Wake rule (BossBase._wakes_for_any): the hero is within COLOSSUS_WAKE_RANGE px of the statue's left edge and
## less than a screen height away.
func _wakes_for(hero: PlayerBase) -> bool:
	return absi(hero.sim_pos.x - box_left()) < EnemyTuning.COLOSSUS_WAKE_RANGE \
			and absi(hero.sim_pos.y - sim_pos.y) < Tuning.VIEW_H


## The statue's body against the heroes: the target hero (1.0); a party: every living hero in contact order.
func _touch_every(target: PlayerBase) -> void:
	var level: LevelBase = Game.level
	if level == null or level.hero_count() <= 1:
		if target != null and not target.is_immune() and not target.is_feasting() \
				and Overlap.body(target, self, target):
			touch_hero(target)
		return
	for hero: PlayerBase in level.contact_order():
		if not hero.dead and not hero.is_immune() and not hero.is_feasting() and Overlap.body(hero, self, hero):
			touch_hero(hero)


## A fresh breath: the idle clock starts again.
func _begin_idle() -> void:
	_state = State.IDLE
	_timer = 0
	_clock = 0
	_play(&"idle")


func _begin_hurt() -> void:
	_state = State.HURT
	_timer = 0
	_play(&"hurt", true)


func _begin_attack() -> void:
	_timer = 0
	if LOOP[_step] == Attack.SPIT:
		_state = State.SPIT
		_play(&"spit", true)
	else:
		_state = State.SLAM
		_play(&"slam", true)


## An attack is over (`advance`: a step of the loop, not a rage): the roar of a hit that landed during it, or the
## next breath. Either way the idle clock starts again.
func _end_attack(advance: bool) -> void:
	if advance:
		_step = (_step + 1) % LOOP.size()
	if _hurt_due:
		_hurt_due = false
		_clock = 0
		_begin_hurt()
	else:
		_begin_idle()


## Idle pause before the next attack: the loop's value shortened by the phase (above 16 hit points, above 8, last 8;
## 2.0 co-op: after 14 and 22 hits taken, see _phase_hp).
func _idle_length() -> int:
	var phase: int = 0
	while phase < EnemyTuning.COLOSSUS_PHASE_HP.size() and hp <= _phase_hp(phase):
		phase += 1
	return EnemyTuning.COLOSSUS_IDLE_TICKS[_step] * EnemyTuning.COLOSSUS_PHASE_PERCENT[phase] / 100


## The hit points at or under which idle phase `phase` + 1 starts: EnemyTuning.COLOSSUS_PHASE_HP (solo, unchanged);
## the co-op form after the hits TAKEN at which the x5/4 visor form (30) reached them - 14 and 22 (COOP_PHASE_TAKEN):
## the 16-hit visor fight shortens its pauses for its last two hits only (the holder dodges rocks aimed at him and
## every rage is a walk across the hall; DB3's duo route was recorded on these pauses).
func _phase_hp(phase: int) -> int:
	if not _coop:
		return EnemyTuning.COLOSSUS_PHASE_HP[phase]
	return max_hp - COOP_PHASE_TAKEN[phase]


## A rock from the open jaws, to the left with a random speed (2.0 co-op: a speed aimed at the plate holder).
func _spit() -> void:
	var speed: int = EnemyTuning.ROCK_XVEL_MIN \
			+ Sim.rng.next_int(EnemyTuning.ROCK_XVEL_STEPS) * EnemyTuning.ROCK_XVEL_STEP
	if _coop:
		var holder: PlayerBase = _holder()
		if holder != null:
			speed = _aimed_speed(absi(sim_pos.x + EnemyTuning.COLOSSUS_MOUTH.x - holder.sim_pos.x))
	_spawn_optional(ROCK_ID, sim_pos + EnemyTuning.COLOSSUS_MOUTH, {"xvel": -speed, "yvel": 0})
	Audio.play_sfx(Sfx.BOSS_SPIT)


## A stalactite under the ceiling at a random x between the left end of the room and the statue.
func _drop_stalactite() -> void:
	var room: Rect2i = _room()
	var low: int = room.position.x + EnemyTuning.COLOSSUS_DROP_MARGIN
	var high: int = sim_pos.x - box_xo - EnemyTuning.COLOSSUS_DROP_MARGIN
	if high < low:
		return
	var x: int = Sim.rng.range_int(low, high)
	if _coop:
		var thrower: PlayerBase = _thrower()
		if thrower != null:
			x = clampi(thrower.sim_pos.x, low, high)
	var top: int = _ceiling_y(x, room.position.y)
	_spawn_optional(STALACTITE_ID, Vector2i(x, top + EnemyTuning.STALACTITE_BOX.y))
	Audio.play_sfx(Sfx.QUAKE)


## The fight room in logical px: the arena zone's rectangle, else the camera lock, else one base screen to the
## left of the statue.
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


## Bottom of the first ceiling above the floor at x, not higher than `limit`.
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


# =================================================================================================================
# 2.0 co-op form: the visor and the plates (DESIGN.md B.7)
# =================================================================================================================

## Start the fight (the arena zone or the wake rule): the form is fixed first, so the bar opens with its hit points.
## The neutral statue of an arena never fights (no bar, no music).
func start_fight() -> void:
	if is_neutral():
		return
	if not fighting and not dead:
		_configure_form()
	super.start_fight()


# =================================================================================================================
# 2.0 versus: the neutral statue of Colossus Hall (DESIGN.md E.5 / G43; DA and world-B, wf9)
# =================================================================================================================

## True in an arena (`kind = arena`, VersusArena.is_arena): the statue is a NEUTRAL picture in the wall - it never
## wakes, fights, attacks or takes a hit (weapons pass it), its body neither hurts nor blocks (the arena's own tiles are
## the collision); world-B's referee (VersusSignatures) makes it spit at the leader through [method arena_spit] and
## [method arena_mouth]. Decided on its first look at the level; everywhere else the statue above runs unchanged.
func is_neutral() -> bool:
	if _neutral < 0:
		var level: LevelBase = Game.level
		if level == null:
			return false
		_neutral = 1 if VersusArena.is_arena(level) else 0
	return _neutral == 1


## The feet point a spat rock starts from (logical px): its open jaws (VersusSignatures, duck-typed).
func arena_mouth() -> Vector2i:
	return sim_pos + EnemyTuning.COLOSSUS_MOUTH


## The referee's spit is due in `ticks` ticks: the open-jaw pose shows from now until a little after the rock left
## (VersusSignatures calls it at the start of VersusTuning.COLOSSUS_JAWS_TICKS; the rock and its touch are world-B's).
func arena_spit(ticks: int) -> void:
	_arena_spit_left = maxi(ticks, 1) + ARENA_SPIT_LINGER_TICKS
	_play(&"spit", true)


## One tick of the neutral statue: the spit pose while the referee's spit runs, else idle. Nothing else.
func _neutral_tick() -> void:
	if _arena_spit_left > 0:
		_arena_spit_left -= 1
		_play(&"spit")
	else:
		_play(&"idle")


## The co-op form in a co-op game of two or more heroes on a co-op file: hit points x2/3 (wf10), the plates of the hall.
func _configure_form() -> void:
	var level: LevelBase = Game.level
	var want: bool = level != null and Game.mode == Defs.GameMode.COOP and level.hero_count() > 1 \
			and str(level.meta.get("kind", "")) == "coop"
	if want == _coop:
		return
	_coop = want
	max_hp = maxi(_solo_hp * COOP_HP_NUM / COOP_HP_DEN, 1) if _coop else _solo_hp
	hp = max_hp
	_live = 0
	_plates.clear()
	if _coop:
		_find_plates()
	_show_visor()


## The left-most and the right-most `objects/plate` inside the room.
func _find_plates() -> void:
	var level: LevelBase = Game.level
	var room: Rect2i = _room()
	var found: Array[Plate] = []
	for entity: SimEntity in level.get_kind(Defs.Kind.OTHER):
		var plate: Plate = entity as Plate
		if plate != null and plate.sim_pos.x >= room.position.x and plate.sim_pos.x < room.end.x:
			found.append(plate)
	found.sort_custom(func(a: Plate, b: Plate) -> bool: return a.sim_pos.x < b.sim_pos.x)
	if found.size() >= 2:
		_plates = [found[0], found[found.size() - 1]]
	elif not _warned_plates:
		_warned_plates = true
		push_warning("Colossus: the co-op visor needs two objects/plate in its hall (found %d)" % found.size())


## The weapon test of the co-op form (BossBase.poll_weapon_hit's order and cooldown): thrown weapons only; one counts
## while the visor is up and its thrower does not hold the live plate, else it glances off the stone. Returns 1 or 0.
func _coop_poll() -> int:
	if hit_cooldown > 0:
		hit_cooldown -= 1
	if _glance_ticks > 0:
		_glance_ticks -= 1
	var level: LevelBase = Game.level
	if level == null or dead or not fighting:
		return 0
	var head: Rect2i = get_head_rect()
	var plate: Plate = get_live_plate()
	var projectiles: Array[SimEntity] = level.get_kind(Defs.Kind.HERO_PROJECTILE)
	for i: int in range(projectiles.size() - 1, -1, -1):
		var projectile: ProjectileBase = projectiles[i] as ProjectileBase
		if projectile == null or projectile.spent or not Overlap.rects(projectile.get_box(), head):
			continue
		projectile.consume()
		var held_by_thrower: bool = plate != null and (plate.holder_mask & (1 << projectile.owner_slot)) != 0
		if not is_visor_up() or held_by_thrower:
			_visor_glance(level, head.get_center())
			return 0
		if hit_cooldown > 0:
			return 0
		_note_hitter(level, projectile.owner_slot)
		return 1
	for hero: PlayerBase in level.contact_order():
		_glance(level, hero, head)
	return 0


func _visor_glance(level: LevelBase, point: Vector2i) -> void:
	if _glance_ticks > 0:
		return
	_glance_ticks = GLANCE_TICKS
	Audio.play_sfx(Sfx.CLUB_HIT_SCENERY)
	level.spawn_fx(&"fx/hit_stars", point)


## The ACTIVE hero standing on the live plate (G33: a dozing hero holds nothing up; the rocks' target), or null.
func _holder() -> PlayerBase:
	var plate: Plate = get_live_plate()
	var level: LevelBase = Game.level
	if plate == null or level == null:
		return null
	for hero: PlayerBase in level.contact_order():
		if hero.counts_for_coop() and (plate.holder_mask & (1 << hero.slot)) != 0:
			return hero
	return null


## The hatched hero who does not hold the live plate (the drops' target), the nearer to the statue first; null when
## nobody else is up.
func _thrower() -> PlayerBase:
	var level: LevelBase = Game.level
	if level == null:
		return null
	var holder: PlayerBase = _holder()
	var best: PlayerBase = null
	for hero: PlayerBase in level.contact_order():
		if hero == holder or not hero.is_party_targetable():
			continue
		if best == null or absi(hero.sim_pos.x - sim_pos.x) < absi(best.sim_pos.x - sim_pos.x):
			best = hero
	return best


## The rock speed (a multiple of ROCK_XVEL_STEP within the 1.0 range) whose first landing is about `dx` px out.
static func _aimed_speed(dx: int) -> int:
	var speed: int = (dx * 16 / COOP_ROCK_FALL_TICKS / EnemyTuning.ROCK_XVEL_STEP) * EnemyTuning.ROCK_XVEL_STEP
	var top: int = EnemyTuning.ROCK_XVEL_MIN + (EnemyTuning.ROCK_XVEL_STEPS - 1) * EnemyTuning.ROCK_XVEL_STEP
	return clampi(speed, EnemyTuning.ROCK_XVEL_MIN, top)


## The visor over the face and the two chains (the live one glowing): a drawing of its own until art-A's visor cut.
func _show_visor() -> void:
	if not _coop:
		if _visor != null:
			_visor.visible = false
		return
	if _visor == null:
		_visor = VisorDrawing.new()
		_visor.name = "Visor"
		add_child(_visor)
	_visor.visible = true
	var drawing: VisorDrawing = _visor as VisorDrawing
	drawing.head = Rect2(Vector2((get_head_rect().position - sim_pos) * Tuning.ART_SCALE),
			Vector2(get_head_rect().size * Tuning.ART_SCALE))
	drawing.up = is_visor_up()
	drawing.anchors.clear()
	for plate: Plate in _plates:
		drawing.anchors.append(Vector2((Vector2i(plate.sim_pos.x + 16, plate.sim_pos.y) - sim_pos) * Tuning.ART_SCALE))
	drawing.live = _live
	drawing.queue_redraw()


## The stone visor and its chains (cosmetic).
class VisorDrawing:
	extends Node2D

	const VISOR_COLOR: Color = Color(0.42, 0.38, 0.36)
	const CHAIN_COLOR: Color = Color(0.3, 0.28, 0.26)
	const CHAIN_LIVE_COLOR: Color = Color(1.0, 0.82, 0.35)

	var head: Rect2 = Rect2()
	var up: bool = false
	var anchors: Array[Vector2] = []
	var live: int = 0

	func _draw() -> void:
		var plate: Rect2 = head
		if up:
			plate.position.y -= head.size.y * 0.8
		draw_rect(plate.grow(4.0), VISOR_COLOR)
		var hook: Vector2 = Vector2(plate.position.x + plate.size.x * 0.5, plate.position.y)
		for i: int in anchors.size():
			draw_line(hook, anchors[i], CHAIN_LIVE_COLOR if i == live else CHAIN_COLOR, 3.0)
