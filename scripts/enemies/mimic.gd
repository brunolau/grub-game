class_name Mimic
extends Snapper
## `enemies/mimic` - 2.0 archetype 15, mimic (GAMEPLAY.md 13.5, DESIGN.md A.5): drawn exactly as a chest (art-B's
## mimic sheet, whose frame 0 is the chest container's closed chest pixel for pixel). Waiting, it is a closed chest that
## faces the nearer hero; when a hero comes within EnemyTuning.MIMIC_SENSE_PX horizontally on its floor it shudders
## EnemyTuning.MIMIC_SHUDDER_TICKS (the telegraph), then bites with the snapper rules (the strip of `range` px in front
## of it, every hero in it, then the recovery and the 22-tick rest). Hits from the side it faces glance (the clank and
## spark of the Guard); hits from behind count; a head bounce (safe, as on every enemy) dazes it
## EnemyTuning.MIMIC_DAZE_TICKS, during which every hit counts and it neither turns nor bites. Killed, it throws out
## `contents`. The original's cruel joke (the skull) as an enemy.
## Co-op (GAMEPLAY.md 13.9.4): it bites the nearer hero and its back faces the far one - no trait ("a solo joke stays a
## solo joke"). Doze rule (ARCHITECTURE.md 11.1): the default one.
##
## Parameters: `contents` [treasure] (ItemContents tokens), `range` px [42], `hp` [25], `score` [5].

## What it throws out when it dies (level parameter `contents`).
var contents: ItemContents = null

## Ticks left of the shudder, of the daze.
var _shudder: int = 0
var _dazed: int = 0
## The sprite's x offset as last written (mirrored about the feet point when it faces left; rattled by the shudder).
var _offset_x: float = 0.0


func _default_skin() -> String:
	return "mimic"


func _apply_params(params: Dictionary) -> void:
	super._apply_params(params)
	score_index = clampi(int(params.get("score", EnemyTuning.SCORE_MIMIC)), 0, Tuning.SCORE_LADDER.size() - 1)
	reach = maxi(int(params.get("range", EnemyTuning.SNAPPER_RANGE)), 0)
	contents = ItemContents.parse(params.get("contents", "treasure"))


## Ticks left dazed after a head bounce (tests and tools).
func get_dazed() -> int:
	return _dazed


## Current Snapper.State (tests and tools).
func get_state() -> int:
	return _state


func _on_wake() -> void:
	super._on_wake()
	_shudder = 0
	_dazed = 0
	var hero: PlayerBase = _nearest_hero()
	if hero != null:
		facing = _dir_to(hero)


func _on_reset() -> void:
	_shudder = 0
	_dazed = 0
	_state = State.IDLE


## Front hits glance unless it is dazed.
func accepts_hit_from(source: SimEntity) -> bool:
	return super.accepts_hit_from(source) and (_dazed > 0 or not _hit_from_front(source))


## A head bounce: the usual count, and it is dazed (its lid hangs open).
func on_bounced(hero: PlayerBase) -> int:
	var shown: int = super.on_bounced(hero)
	if not dead:
		if _dazed == 0:
			Audio.play_sfx(Sfx.DAZE)  # "an enemy is dazed" (DESIGN.md F.2), once per daze
		_dazed = EnemyTuning.MIMIC_DAZE_TICKS
		_shudder = 0
		_state = State.REST
		_timer = 0
		_play(&"dizzy", true)
	return shown


func kill(cause: StringName, killer: SimEntity = null) -> void:
	var was_alive: bool = not dead
	var at: Vector2i = sim_pos
	super.kill(cause, killer)
	if was_alive and dead:
		_throw_contents(at, killer)


func _ai_tick() -> void:
	if _dazed > 0:
		_dazed -= 1
		_play(&"dizzy")
		if _dazed == 0:
			_state = State.REST
			_timer = 0
			_play(&"idle", true)
		return
	match _state:
		State.IDLE:
			var hero: PlayerBase = _nearest_hero()
			if hero == null:
				return
			facing = _dir_to(hero)
			_play(&"idle")
			if _senses(hero):
				_state = State.WINDUP
				_shudder = EnemyTuning.MIMIC_SHUDDER_TICKS
				_play(&"shudder", true)
		State.WINDUP:
			_shudder -= 1
			if _shudder <= 0:
				_state = State.BITE
				_play(&"bite", true)
				Audio.play_sfx(Sfx.ENEMY_VOICE)
		State.BITE:
			_bite()
			if _anim_done():
				_state = State.RECOVER
				_play(&"recover", true)
		State.RECOVER, State.HURT:
			if _anim_done():
				_state = State.REST
				_timer = EnemyTuning.SNAPPER_REST_TICKS
				_play(&"idle")
		State.REST:
			_timer -= 1
			if _timer <= 0:
				_state = State.IDLE


## A hit it survived: the Snapper's hurt pose, unless it is dazed (the daze goes on).
func _on_hurt(power: int) -> void:
	if _dazed > 0:
		return
	super._on_hurt(power)


## The nearer hatched hero (GAMEPLAY.md 13.9.4: "bites the nearer; its back faces the far hero"); in a party of one
## the hero (LevelBase.target_hero).
func _nearest_hero() -> PlayerBase:
	return Game.level.target_hero(self) if Game.level != null else null


## A hero within EnemyTuning.MIMIC_SENSE_PX horizontally, on its floor.
func _senses(hero: PlayerBase) -> bool:
	return absi(hero.sim_pos.x - sim_pos.x) <= EnemyTuning.MIMIC_SENSE_PX \
			and absi(hero.sim_pos.y - sim_pos.y) <= EnemyTuning.MIMIC_SENSE_DY


func _throw_contents(at: Vector2i, killer: SimEntity) -> void:
	var level: LevelBase = Game.level
	if contents == null or contents.is_empty() or level == null:
		return
	var away: int = _away_from(killer)
	for i: int in contents.size():
		var side: int = away if (i & 1) == 0 else -away
		var speed: int = maxi(EnemyTuning.MIMIC_DROP_XVEL - (i >> 1) * EnemyTuning.MIMIC_DROP_FAN_STEP, 0)
		contents.spawn(level, i, at + Vector2i(0, EnemyTuning.BURST_DY), side * speed, EnemyTuning.MIMIC_DROP_YVEL)


## Waiting (idle) it is drawn exactly as the chest container draws its closed chest: never mirrored, offset -pivot.
## Revealed (shudder, bite, recovery, rest, daze) it is mirrored when it faces left - the chest's pivot is off-centre,
## so its offset is mirrored too - and the shudder rattles it. Cosmetic.
func _refresh_visual() -> void:
	super._refresh_visual()
	if _sprite == null or _skin == null:
		return
	var flip: bool = facing < 0 and (_state != State.IDLE or _dazed > 0)
	if _sprite.flip_h != flip:
		_sprite.flip_h = flip
	var x: float = -float(_skin.cell.x - _skin.pivot.x) if flip else -float(_skin.pivot.x)
	if _state == State.WINDUP and awake and (_anim_age & 1) == 1:
		x += float(EnemyTuning.MIMIC_SHUDDER_ART_PX)
	if x != _offset_x or _sprite.offset.x != x:
		_offset_x = x
		_sprite.offset.x = x
