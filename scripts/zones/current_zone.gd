class_name CurrentZone
extends ZoneBase
## `zones/current rect=c,r,w,h dir=l|r|u|d speed=1..3` (docs/spec/PHYSICS.md C.7, DESIGN.md C.5): water that flows.
## Owner: world-A.
##
## The zone itself moves nothing and never ticks: what floats asks it. A raft (objects-B) whose anchor is inside a
## current with `dir = l|r` drifts `speed` px per tick that way (C.7 step 1; the raft finds every Kind.ZONE entity
## with `dir` and `speed` in its spawn parameters, or calls [method find_at]); `dir = u|d` currents move only floating
## dropped items ([method drift_at]). Heroes are not moved (water is deadly). Parameters: `rect` (tiles, required),
## `dir` [r], `speed` px per tick [1], clamped to Tuning.CURRENT_SPEED_MIN_PX .. CURRENT_SPEED_MAX_PX, `name`.

## The flow direction: &"l", &"r", &"u" or &"d".
var dir: StringName = &"r"
## px per tick.
var speed: int = Tuning.CURRENT_SPEED_MIN_PX


func _apply_params(params: Dictionary) -> void:
	super._apply_params(params)
	var value: String = param_str("dir", "r").to_lower()
	if not ["l", "r", "u", "d"].has(value):
		push_warning("%s: dir must be l, r, u or d (got '%s'); using r" % [name, value])
		value = "r"
	dir = StringName(value)
	speed = clampi(param_int("speed", Tuning.CURRENT_SPEED_MIN_PX), Tuning.CURRENT_SPEED_MIN_PX,
			Tuning.CURRENT_SPEED_MAX_PX)


## A current tests nobody: it never ticks (and so never dozes or wakes).
func _sim_phases() -> PackedInt32Array:
	return PackedInt32Array()


## The drift of this current in px per tick: (+/-speed, 0) for l / r, (0, +/-speed) for u / d.
func drift() -> Vector2i:
	match dir:
		&"l":
			return Vector2i(-speed, 0)
		&"u":
			return Vector2i(0, -speed)
		&"d":
			return Vector2i(0, speed)
	return Vector2i(speed, 0)


## The first current (spawn order) of `level` whose rectangle holds the point `pos` (logical px), null when none.
static func find_at(level: LevelBase, pos: Vector2i) -> CurrentZone:
	if level == null:
		return null
	var zones: Array[SimEntity] = level.get_kind(Defs.Kind.ZONE)
	for i: int in zones.size():
		var current: CurrentZone = zones[i] as CurrentZone
		if current != null and current.rect.has_point(pos):
			return current
	return null


## The drift (px per tick) at the point `pos`: that of [method find_at], Vector2i.ZERO outside every current.
static func drift_at(level: LevelBase, pos: Vector2i) -> Vector2i:
	var current: CurrentZone = find_at(level, pos)
	return current.drift() if current != null else Vector2i.ZERO
