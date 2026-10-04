class_name Patroller
extends EnemyBase
## Archetype 9, patroller (GAMEPLAY.md 5.2): moves between a left and a right limit, accelerating 3 v16 per tick up
## to `speed` and decelerating the same way past a limit, which gives smooth turn-arounds. Base of
## `enemies/walker` (follows the ground and slopes, turns at walls) and `enemies/flyer` (ignores walls and gravity).
##
## Parameters: `left` [-3], `right` [3] tiles relative to the anchor, `speed` v16 [32], `facing` (first direction).

## Left limit, logical px (anchor + `left` tiles).
var left_x: int = 0
## Right limit, logical px (anchor + `right` tiles).
var right_x: int = 0
## Top speed, v16 (level parameter `speed`).
var speed: int = EnemyTuning.PATROL_SPEED

var _heading: int = 1
var _step: int = 0


func _apply_params(params: Dictionary) -> void:
	super._apply_params(params)
	speed = absi(int(params.get("speed", speed)))
	var left_tiles: int = int(params.get("left", EnemyTuning.PATROL_LEFT_TILES))
	var right_tiles: int = int(params.get("right", EnemyTuning.PATROL_RIGHT_TILES))
	left_x = spawn_pos.x + mini(left_tiles, right_tiles) * Tuning.TILE
	right_x = spawn_pos.x + maxi(left_tiles, right_tiles) * Tuning.TILE


func _on_wake() -> void:
	_heading = facing
	_step = 0
	xvel = 0
	yvel = 0
	_play(_move_role())


func _ai_tick() -> void:
	xvel = _step
	if _heading > 0:
		_step = mini(_step + EnemyTuning.PATROL_ACCEL, speed)
		if sim_pos.x > right_x:
			_heading = -1
	else:
		_step = maxi(_step - EnemyTuning.PATROL_ACCEL, -speed)
		if sim_pos.x <= left_x:
			_heading = 1
	_move()
	if xvel != 0:
		facing = signi(xvel)
	_play(_move_role())


## Move one tick with the current xvel. Override.
func _move() -> void:
	sim_pos.x += Tuning.floor16(xvel)


## Animation role while patrolling. Override.
func _move_role() -> StringName:
	return &"walk"


## A wall turned it round: continue the patrol the other way from the speed it bounced off with.
func _bounced(new_xvel: int) -> void:
	_heading = signi(new_xvel)
	_step = new_xvel
