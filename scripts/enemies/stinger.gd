class_name Stinger
extends EnemyBase
## `enemies/stinger` - archetype 5, sentry diver that levels out (GAMEPLAY.md 5.2): hovers at its anchor facing the
## hero; when he enters a box of `range` x `range` tiles around it, it dives diagonally toward him at `speed` px per
## tick on both axes; once level with him (within 8 px) it continues horizontally. Flies through scenery.
##
## Parameters: `range` tiles [6], `speed` px per tick [3], `skin` [insect], `hp` [25], `score` [3].

enum State { HOVER, DIVE, LEVEL }

## Trigger box half size in tiles (level parameter `range`).
var range_tiles: int = EnemyTuning.STINGER_RANGE_TILES
## Dive speed per axis, px per tick (level parameter `speed`).
var speed: int = EnemyTuning.STINGER_SPEED

var _state: int = State.HOVER


func _default_skin() -> String:
	return "insect"


func _apply_params(params: Dictionary) -> void:
	score_index = EnemyTuning.SCORE_STINGER
	super._apply_params(params)
	range_tiles = maxi(int(params.get("range", range_tiles)), 0)
	speed = maxi(absi(int(params.get("speed", speed))), 1)


func _on_wake() -> void:
	_state = State.HOVER
	xvel = 0
	yvel = 0
	_play(&"fly")


func _ai_tick() -> void:
	var hero: PlayerBase = _target_hero()
	match _state:
		State.HOVER:
			if hero == null:
				return
			facing = _dir_to(hero)
			var dx: int = Tuning.to_cell(absi(hero.sim_pos.x - sim_pos.x))
			var dy: int = Tuning.to_cell(absi(hero.sim_pos.y - sim_pos.y))
			if dx > range_tiles or dy > range_tiles:
				return
			xvel = speed * Tuning.V16_PER_PX * facing
			yvel = speed * Tuning.V16_PER_PX * (1 if hero.sim_pos.y >= sim_pos.y else -1)
			_state = State.DIVE
		State.DIVE:
			if hero != null and absi(sim_pos.y - hero.sim_pos.y) <= EnemyTuning.STINGER_LEVEL_PX:
				yvel = 0
				_state = State.LEVEL
	sim_pos.x += Tuning.floor16(xvel)
	sim_pos.y += Tuning.floor16(yvel)
