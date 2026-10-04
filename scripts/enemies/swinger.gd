class_name Swinger
extends HangerEnemy
## `enemies/swinger` - archetype 4, pendulum (GAMEPLAY.md 5.2): lowers itself on a thread from the ceiling above its
## anchor until the thread is `radius` px long, then swings like a pendulum (about 51 degrees to each side, a period
## of about 34 ticks). Integer pendulum: the angle is in 1/256 turns, the pull toward the rest position is a
## constant angular deceleration, positions come from a quarter-sine table.
##
## Parameters: `radius` px [40], `skin` [bat_b], `hp` [25], `score` [1].

## Thread length when swinging, px (level parameter `radius`).
var radius: int = EnemyTuning.SWINGER_RADIUS

var _length: int = 0
var _angle: int = 0
var _spin: int = 0
var _swinging: bool = false


func _default_skin() -> String:
	return "bat_b"


func _apply_params(params: Dictionary) -> void:
	score_index = EnemyTuning.SCORE_SWINGER
	super._apply_params(params)
	radius = maxi(int(params.get("radius", radius)), 0)


func _on_wake() -> void:
	_thread_top = _find_thread_top()
	_thread_on = true
	_length = 0
	_angle = 0
	_spin = EnemyTuning.SWINGER_KICK * facing
	_swinging = false
	_place()
	teleport(sim_pos)
	_play(&"hang")


func _ai_tick() -> void:
	if not _swinging:
		_length = mini(_length + EnemyTuning.SWINGER_LOWER_SPEED, radius)
		_swinging = _length >= radius
	else:
		_angle += _spin
		if _angle > 0:
			_spin -= EnemyTuning.SWINGER_PULL
		elif _angle < 0:
			_spin += EnemyTuning.SWINGER_PULL
		if _spin != 0:
			facing = signi(_spin)
		_play(&"dive")
	_place()


## Thread angle in 1/256 turns (0 = straight down; positive = to the right). For tests and tools.
func get_angle() -> int:
	return _angle


## Feet point from the thread: the thread end hangs `_length` px from the attach point at `_angle`, the body hangs
## below the thread end.
func _place() -> void:
	var turn: int = clampi(absi(_angle), 0, EnemyTuning.SINE_QUARTER_STEPS)
	var sine: int = EnemyTuning.SINE_QUARTER[turn] * signi(_angle)
	var cosine: int = EnemyTuning.SINE_QUARTER[EnemyTuning.SINE_QUARTER_STEPS - turn]
	var hang: int = _skin.body_height / Tuning.ART_SCALE if _skin != null else box_h
	sim_pos = _thread_top + Vector2i(
		Tuning.shr(_length * sine, EnemyTuning.SINE_SHIFT),
		Tuning.shr(_length * cosine, EnemyTuning.SINE_SHIFT) + hang
	)
