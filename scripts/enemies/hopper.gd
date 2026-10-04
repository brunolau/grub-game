class_name Hopper
extends EnemyBase
## `enemies/hopper` - archetype 8, hopper (GAMEPLAY.md 5.2): waits `pause` ticks, then - once the hero is within a
## box of `range` x `range` tiles - jumps toward him with a take-off speed of `jump_x` px per tick forward and
## `jump_y` px per tick up (height v (v + 1) / 2 px with the enemy gravity), lands without bouncing, pauses and
## jumps again toward wherever he is now. Ground physics with wall turns.
##
## Parameters: `range` tiles [6], `pause` ticks [22], `jump_x` px per tick [3], `jump_y` px per tick [8],
## `skin` [mini_rex], `hp` [25], `score` [2].

enum State { WATCH, AIR, REST }

## Trigger box half size in tiles (level parameter `range`).
var range_tiles: int = EnemyTuning.HOPPER_RANGE_TILES
## Ticks between two jumps (level parameter `pause`).
var pause: int = EnemyTuning.HOPPER_PAUSE
## Horizontal take-off speed, px per tick (level parameter `jump_x`).
var jump_x: int = EnemyTuning.HOPPER_JUMP_X
## Vertical take-off speed, px per tick (level parameter `jump_y`).
var jump_y: int = EnemyTuning.HOPPER_JUMP_Y

var _state: int = State.WATCH
var _timer: int = 0


func _default_skin() -> String:
	return "mini_rex"


func _apply_params(params: Dictionary) -> void:
	score_index = EnemyTuning.SCORE_HOPPER
	super._apply_params(params)
	range_tiles = maxi(int(params.get("range", range_tiles)), 0)
	pause = maxi(int(params.get("pause", pause)), 0)
	jump_x = absi(int(params.get("jump_x", jump_x)))
	jump_y = absi(int(params.get("jump_y", jump_y)))


func _on_wake() -> void:
	_state = State.WATCH
	_timer = pause
	xvel = 0
	yvel = 0
	_play(&"idle")


func _ai_tick() -> void:
	var hero: PlayerBase = _target_hero()
	match _state:
		State.WATCH, State.REST:
			_ground_step(false, false)
			if hero != null:
				facing = _dir_to(hero)
			if _timer > 0:
				_timer -= 1
				return
			if hero == null or not _grounded:
				return
			if _state == State.WATCH and (
					Tuning.to_cell(absi(hero.sim_pos.x - sim_pos.x)) > range_tiles
					or Tuning.to_cell(absi(hero.sim_pos.y - sim_pos.y)) > range_tiles):
				return
			_jump(hero)
		State.AIR:
			if _ground_step(false, false):
				xvel = 0
				_state = State.REST
				_timer = pause
				_play(&"idle")
			elif xvel != 0:
				facing = signi(xvel)


func _jump(hero: PlayerBase) -> void:
	facing = _dir_to(hero)
	xvel = jump_x * Tuning.V16_PER_PX * facing
	yvel = -jump_y * Tuning.V16_PER_PX
	_grounded = false
	_state = State.AIR
	_play(&"air")
