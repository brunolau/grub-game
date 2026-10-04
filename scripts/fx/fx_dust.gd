class_name FxDust
extends FxBase
## `fx/dust`: two small smoke balls that roll apart along the ground and fade (landings, skids, low strikes).
## Optional `dir=-1|1` makes it a one-sided skid puff that drifts against the given direction.

const DRIFT_ART: int = 2           ## art px per tick each ball moves sideways
const RISE_EVERY: int = 3          ## a ball rises 1 art px every few ticks
const FRAME_COUNT: int = 4         ## sprites/fx/particles_smoke.png

var _left: Sprite2D = null
var _right: Sprite2D = null
var _dir: int = 0


func _apply_params(params: Dictionary) -> void:
	lifetime = ObjTuning.DUST_LIFE
	_dir = clampi(int(params.get("dir", 0)), -1, 1)
	_left = get_node_or_null(^"PuffLeft") as Sprite2D
	_right = get_node_or_null(^"PuffRight") as Sprite2D
	if _dir != 0 and _right != null and _left != null:
		# One-sided puff: both balls trail behind the motion.
		_right.visible = false


func _fx_tick() -> void:
	var frame: int = mini(age * FRAME_COUNT / lifetime, FRAME_COUNT - 1)
	var fade: float = 1.0 - float(age) / float(lifetime)
	var drift: float = float(age * DRIFT_ART)
	var rise: float = -float(age / RISE_EVERY)
	if _left != null:
		_left.frame = frame
		_left.position = Vector2(drift * (float(-_dir) if _dir != 0 else -1.0), rise)
		_left.modulate.a = fade
	if _right != null:
		_right.frame = frame
		_right.position = Vector2(drift, rise)
		_right.modulate.a = fade
