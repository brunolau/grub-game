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


func _default_skin() -> String:
	return "colossus"


func _apply_params(params: Dictionary) -> void:
	max_hp = EnemyTuning.COLOSSUS_HP
	hp_per_pip = EnemyTuning.COLOSSUS_HP_PER_PIP
	thrown_only = true
	music = Sfx.MUSIC_BOSS_FINAL
	boss_drops = [&"trophy", &"trophy", &"trophy", &"trophy"]
	super._apply_params(params)
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


func _on_reset() -> void:
	_state = State.DORMANT
	_timer = 0
	_step = 0
	_hits = 0
	_clock = 0
	_hurt_due = false
	_rage_due = false
	set_box(EnemyTuning.COLOSSUS_BOX)


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
	var hero: PlayerBase = _target_hero()
	if not fighting:
		_play(&"idle")
		if hero != null and absi(hero.sim_pos.x - box_left()) < EnemyTuning.COLOSSUS_WAKE_RANGE \
				and absi(hero.sim_pos.y - sim_pos.y) < Tuning.VIEW_H:
			start_fight()
		if not fighting:
			return
	if _state == State.DORMANT:
		_begin_idle()
	var power: int = poll_weapon_hit(get_head_rect())
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
		_rage_due = _rage_due or (_hits - 1) % EnemyTuning.COLOSSUS_RAGE_EVERY == 0
		Audio.play_sfx(Sfx.BOSS_ROAR)
		if _state == State.IDLE:
			_begin_hurt()
		else:
			_hurt_due = true
	if hero != null and not hero.is_immune() and not hero.is_feasting() and Overlap.body(hero, self, hero):
		touch_hero(hero)
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


# =================================================================================================================
# Internals
# =================================================================================================================

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


## Idle pause before the next attack: the loop's value shortened by the phase (above 16 hit points, above 8, last 8).
func _idle_length() -> int:
	var phase: int = 0
	while phase < EnemyTuning.COLOSSUS_PHASE_HP.size() and hp <= EnemyTuning.COLOSSUS_PHASE_HP[phase]:
		phase += 1
	return EnemyTuning.COLOSSUS_IDLE_TICKS[_step] * EnemyTuning.COLOSSUS_PHASE_PERCENT[phase] / 100


## A rock from the open jaws, to the left with a random speed.
func _spit() -> void:
	var speed: int = EnemyTuning.ROCK_XVEL_MIN \
			+ Sim.rng.next_int(EnemyTuning.ROCK_XVEL_STEPS) * EnemyTuning.ROCK_XVEL_STEP
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
