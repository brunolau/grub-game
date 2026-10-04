class_name Dart
extends EnemyBase
## `enemies/dart` - archetype 7, kamikaze diver (GAMEPLAY.md 5.2): waits at its anchor facing the hero; when he is
## within `range` tiles horizontally it dives diagonally toward him at `speed` px per tick on both axes and never
## returns: once launched it is one-shot (gone for good after it despawns). Flies through scenery.
##
## Parameters: `range` tiles [8], `speed` px per tick [4], `skin` [pterodactyl_b], `hp` [25], `score` [3].

## Activation distance in tiles (level parameter `range`).
var range_tiles: int = EnemyTuning.DART_RANGE_TILES
## Dive speed per axis, px per tick (level parameter `speed`).
var speed: int = EnemyTuning.DART_SPEED

var _launched: bool = false


func _default_skin() -> String:
	return "pterodactyl_b"


func _apply_params(params: Dictionary) -> void:
	score_index = EnemyTuning.SCORE_DART
	super._apply_params(params)
	range_tiles = maxi(int(params.get("range", range_tiles)), 0)
	speed = maxi(absi(int(params.get("speed", speed))), 1)


func _on_wake() -> void:
	_launched = false
	xvel = 0
	yvel = 0
	_play(&"fly")


func _on_reset() -> void:
	one_shot = false
	_launched = false


## True once it dived (tests and tools).
func is_launched() -> bool:
	return _launched


func _ai_tick() -> void:
	if not _launched:
		var hero: PlayerBase = _target_hero()
		if hero == null:
			return
		facing = _dir_to(hero)
		if Tuning.to_cell(absi(hero.sim_pos.x - sim_pos.x)) > range_tiles:
			return
		_launched = true
		one_shot = true
		xvel = speed * Tuning.V16_PER_PX * facing
		yvel = speed * Tuning.V16_PER_PX * (1 if hero.sim_pos.y >= sim_pos.y else -1)
		Audio.play_sfx(Sfx.ENEMY_VOICE)
		_play(&"dive")
	sim_pos.x += Tuning.floor16(xvel)
	sim_pos.y += Tuning.floor16(yvel)
