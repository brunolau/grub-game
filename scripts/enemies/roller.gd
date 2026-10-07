class_name Roller
extends Walker
## `enemies/roller` - 2.0 archetype 13, roller (GAMEPLAY.md 13.5, DESIGN.md A.5): patrols between its limits at
## EnemyTuning.ROLLER_WALK_SPEED; when its target is within `range` tiles horizontally and
## EnemyTuning.ROLLER_SENSE_ROWS rows vertically it curls up (a 14-tick visible tuck, no motion) and rolls at the
## target's side at `speed`, following floors and slopes (+4 v16 per tick down a slope, up to 96), off ledges and into
## liquids (gone). While it is a ball (tuck and roll) weapon hits glance; its contact hurts; a head bounce is safe as
## on every enemy. A wall stops it: dizzy for `dizzy` ticks (hittable), then it uncurls (8 ticks) and walks; after
## 154 ticks of rolling it uncurls by itself. Co-op: it rolls at the nearest hero (the base targeting); `bond` pairs.
## Doze rule (ARCHITECTURE.md 11.1): the default one - asleep at its anchor it waits for the view.
##
## Parameters: `range` tiles [6], `speed` v16 [64] (the roll), `dizzy` ticks [33], `left` [-3] / `right` [3] tiles,
## `skin` [roller; Expert roller_b], `hp` [25], `score` [3].

enum State { WALK, CURL, ROLL, DIZZY, UNCURL }

## Trigger distance in tiles (level parameter `range`).
var range_tiles: int = EnemyTuning.ROLLER_RANGE_TILES
## Rolling speed, v16 (level parameter `speed`).
var roll_speed: int = EnemyTuning.ROLLER_SPEED
## Ticks dizzy after hitting a wall (level parameter `dizzy`).
var dizzy_ticks: int = EnemyTuning.ROLLER_DIZZY_TICKS

var _state: int = State.WALK
var _timer: int = 0


func _default_skin() -> String:
	return "roller"


func _apply_params(params: Dictionary) -> void:
	super._apply_params(params)
	# Walker sets its own default score first: this archetype's default, unless the level gives `score`.
	score_index = clampi(int(params.get("score", EnemyTuning.SCORE_ROLLER)), 0, Tuning.SCORE_LADDER.size() - 1)
	roll_speed = maxi(absi(int(params.get("speed", EnemyTuning.ROLLER_SPEED))), 1)
	speed = EnemyTuning.ROLLER_WALK_SPEED
	range_tiles = maxi(int(params.get("range", range_tiles)), 0)
	dizzy_ticks = maxi(int(params.get("dizzy", dizzy_ticks)), 0)


## Current State (tests and tools).
func get_state() -> int:
	return _state


## True while it is a ball (tuck, roll, dizzy).
func is_ball() -> bool:
	return _state == State.CURL or _state == State.ROLL or _state == State.DIZZY


func _on_wake() -> void:
	super._on_wake()
	_enter(State.WALK)


func _on_reset() -> void:
	_state = State.WALK
	_timer = 0
	_walk_box()


## Weapon hits glance off the ball while it tucks and rolls (dizzy, it can be hurt).
func accepts_hit_from(source: SimEntity) -> bool:
	return super.accepts_hit_from(source) and _state != State.CURL and _state != State.ROLL


func _ai_tick() -> void:
	match _state:
		State.WALK:
			super._ai_tick()
			if not awake:
				return
			var hero: PlayerBase = _target_hero()
			if hero != null and _grounded and _in_range(hero):
				facing = _dir_to(hero)
				_enter(State.CURL)
		State.CURL:
			xvel = 0
			_ground_step(false, false)
			_timer -= 1
			if _timer <= 0:
				_start_roll()
		State.ROLL:
			_roll_tick()
		State.DIZZY:
			xvel = 0
			_ground_step(false, false)
			_timer -= 1
			if dizzy_ticks - _timer > EnemyTuning.ROLLER_BUMP_TICKS:
				_play(&"dizzy")
			if _timer <= 0:
				_enter(State.UNCURL)
		State.UNCURL:
			xvel = 0
			_ground_step(false, false)
			_timer -= 1
			if _timer <= 0:
				_enter(State.WALK)


func _in_range(hero: PlayerBase) -> bool:
	return Tuning.to_cell(absi(hero.sim_pos.x - sim_pos.x)) <= range_tiles \
			and Tuning.to_cell(absi(hero.sim_pos.y - sim_pos.y)) <= EnemyTuning.ROLLER_SENSE_ROWS


func _start_roll() -> void:
	var hero: PlayerBase = _target_hero()
	if hero != null:
		facing = _dir_to(hero)
	xvel = roll_speed * facing
	_timer = 0
	_state = State.ROLL
	_play(&"roll", true)
	Audio.play_sfx(Sfx.ENEMY_VOICE)


func _roll_tick() -> void:
	var before: int = xvel
	var was_grounded: bool = _grounded
	var y0: int = sim_pos.y
	_ground_step(false, false)
	if not awake:
		return  # rolled into a liquid: gone (EnemyBase._sank_in_liquid)
	if before != 0 and signi(xvel) != signi(before):
		# A wall: it stops dead and is dizzy.
		xvel = 0
		_enter(State.DIZZY)
		return
	if was_grounded and _grounded and sim_pos.y > y0:
		var cap: int = maxi(EnemyTuning.ROLLER_SPEED_CAP, roll_speed)
		xvel = signi(xvel) * mini(absi(xvel) + EnemyTuning.ROLLER_SLOPE_ACCEL, cap)
	if xvel != 0:
		facing = signi(xvel)
	_timer += 1
	if _timer >= EnemyTuning.ROLLER_ROLL_MAX_TICKS:
		_enter(State.UNCURL)


func _enter(state: int) -> void:
	_state = state
	match state:
		State.WALK:
			_walk_box()
			xvel = 0
			_heading = facing
			_step = 0
			_play(_move_role(), true)
		State.CURL:
			set_box(EnemyTuning.ROLLER_BALL_BOX)
			xvel = 0
			_timer = EnemyTuning.ROLLER_CURL_TICKS
			_play(&"curl", true)
		State.DIZZY:
			set_box(EnemyTuning.ROLLER_BALL_BOX)
			xvel = 0
			_timer = dizzy_ticks
			_play(&"bump", true)
			Audio.play_sfx(Sfx.IMPACT)
			if dizzy_ticks <= EnemyTuning.ROLLER_BUMP_TICKS:
				_play(&"dizzy", true)
		State.UNCURL:
			_walk_box()
			xvel = 0
			_timer = EnemyTuning.ROLLER_UNCURL_TICKS
			_play(&"uncurl", true)


## The walking body box of the skin.
func _walk_box() -> void:
	if _skin != null:
		set_box(Vector3i(_skin.box.x, _skin.box.y, _skin.box.x >> 1))
