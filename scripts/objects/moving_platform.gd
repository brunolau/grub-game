class_name MovingPlatform
extends PlatformBase
## `objects/platform` (PHYSICS.md 11.4 movers, GAMEPLAY.md 7.3): moves in one of 8 directions and back.
##
## Parameters: `dir` 0..7 [2] (0 up, clockwise), `speed` px/tick [2], `travel` ticks [44], `mode=always|ride`
## [always], `skin=wood|ice|stone|small` [by biome]. The speed changes by Tuning.PLATFORM_ACCEL each tick toward a
## signed target; after `travel` ticks at the target the target is negated (ping-pong). A `ride` platform waits
## until the hero rides it and stops at the end of the cycle after he stepped off.
## The standing surface is the top edge of the cell the platform is placed in.

## Movement per direction 0..7, in units of the speed.
const DIR_X: Array[int] = [0, 1, 1, 1, 0, -1, -1, -1]
const DIR_Y: Array[int] = [-1, -1, 0, 1, 1, 1, 0, -1]
const DIRECTIONS: int = 8

## Direction 0..7.
var direction: int = ObjTuning.PLATFORM_DEFAULT_DIR
## Top speed, px per tick.
var speed: int = ObjTuning.PLATFORM_DEFAULT_SPEED
## Ticks at top speed before turning back.
var travel: int = ObjTuning.PLATFORM_DEFAULT_TRAVEL
## True for mode=ride.
var ride_only: bool = false
## Current signed speed along the direction (px per tick) and the signed speed it moves toward.
var velocity: int = 0
var target: int = 0
## Feet point the platform starts from (and returns to on a level reset).
var home: Vector2i = Vector2i.ZERO
## 2.0: the objects/pulley that drives this platform (null: it moves by its own parameters). While driven, its own
## motion is off and it moves [member pulley_dy] px on its next PLATFORMS tick (set by the pulley in the WORLD phase
## before; used once).
var pulley: SimEntity = null
var pulley_dy: int = 0

var _counter: int = 0


func _apply_params(params: Dictionary) -> void:
	super._apply_params(params)
	direction = posmod(int(params.get("dir", direction)), DIRECTIONS)
	speed = maxi(int(params.get("speed", speed)), 0)
	travel = maxi(int(params.get("travel", travel)), 1)
	ride_only = str(params.get("mode", "always")) == "ride"
	PlatformSkin.apply(self, PlatformSkin.resolve(str(params.get("skin", ""))))
	home = Vector2i(sim_pos.x, sim_pos.y - (Tuning.TILE - box_h))
	teleport(home)
	_reset_motion()


func _move_tick() -> void:
	if pulley != null:
		dy = pulley_dy
		pulley_dy = 0
		return
	if velocity == 0 and target >= 0 and ride_only and not ridden:
		return
	if target > velocity:
		velocity += Tuning.PLATFORM_ACCEL
	elif target < velocity:
		velocity -= Tuning.PLATFORM_ACCEL
	dx = DIR_X[direction] * velocity
	dy = DIR_Y[direction] * velocity
	if velocity == target:
		_counter += 1
		if _counter >= travel:
			target = -target
			_counter = 0


func _on_level_reset() -> void:
	teleport(home)
	ridden = false
	pulley_dy = 0
	_reset_motion()


func _reset_motion() -> void:
	velocity = 0
	target = speed
	_counter = 0
