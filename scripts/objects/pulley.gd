class_name Pulley
extends SimEntity
## `objects/pulley a=<platform> b=<platform> range=<rows>` [3] (DESIGN.md D.5, GAMEPLAY.md 13.9.7): two linked
## `objects/platform` (best `mode=ride`) named `a` and `b`, hanging from a beam at the pulley's cell. While the pulley
## drives them their own motion is off (MovingPlatform.pulley). Weight as on plates (PlatformBase.rider_weight():
## hatched heroes riding it; eggs weigh nothing): the heavier side sinks PartyTuning.PULLEY_SPEED_PX px per tick and
## the other rises as much, each at most `range` rows from its start; equal weights do not move.
##
## Timing (independent of the file order): in the WORLD phase of a tick it compares the weights of that tick's ride
## tests and sets each platform's MovingPlatform.pulley_dy; the platforms move by it in the next PLATFORMS phase. A
## team wipe (the level reset) puts both back at their starts. It never dozes.
##
## The picture: a wheel on a strap above each platform at the pulley's height, a rope from each wheel down to its
## platform and one between the wheels (drawn from the pieces of pulley.png); the wheels turn while it moves.

## Sheet [M pulley]: 0-3 wheel turn, 4 rope, 5 knot, 6 hanger strap; 32 x 32 art px cells, pivot = cell centre.
const TEXTURE: Texture2D = preload("res://assets/sprites/objects/pulley.png")
const CELL_ART: int = 32
const FRAME_ROPE: int = 4
const FRAME_KNOT: int = 5
const FRAME_STRAP: int = 6
const WHEEL_FRAMES: int = 4
## The wheel hangs 6 art px below the strap's bolt [M pulley].
const WHEEL_DROP_ART: float = 6.0

## Names of the two platforms (`a`, `b`).
var name_a: StringName = &""
var name_b: StringName = &""
## Rows each side may travel from its start (`range`).
var range_rows: int = PartyTuning.PULLEY_RANGE_ROWS
## Px platform `a` has sunk below its start (platform `b` has risen as much); within +/- range_rows tiles.
var offset: int = 0
## The step set for the next PLATFORMS phase (+ = `a` sinks) and the weights it compared.
var step: int = 0
var weight_a: int = 0
var weight_b: int = 0

var _a: MovingPlatform = null
var _b: MovingPlatform = null
var _resolved: bool = false
var _warned: bool = false
var _turn: int = 0


func _init() -> void:
	z_index = Defs.Z_PLATFORMS + 1
	set_box(Vector3i(Tuning.TILE * 2, Tuning.TILE, Tuning.TILE))


## ITEMS (before the platforms move): take the platforms over on the first tick; WORLD: compare the weights.
func _sim_phases() -> PackedInt32Array:
	return PackedInt32Array([Defs.Phase.ITEMS, Defs.Phase.WORLD])


func _apply_params(params: Dictionary) -> void:
	name_a = StringName(str(params.get("a", "")))
	name_b = StringName(str(params.get("b", "")))
	range_rows = maxi(int(params.get("range", range_rows)), 1)


## Platform `a` / `b` (null until resolved, or when the level has none of that name).
func platform_a() -> MovingPlatform:
	return _a


func platform_b() -> MovingPlatform:
	return _b


## Find the platforms by name and take them over (once).
func _resolve(level: LevelBase) -> bool:
	if _resolved:
		return _a != null and _b != null
	_resolved = true
	_a = level.find_named(name_a) as MovingPlatform if name_a != &"" else null
	_b = level.find_named(name_b) as MovingPlatform if name_b != &"" else null
	if _a == null or _b == null or _a == _b:
		if not _warned:
			_warned = true
			push_warning("objects/pulley: platforms a='%s' / b='%s' not found (objects/platform name=...)" % [
				name_a, name_b])
		_a = null
		_b = null
		return false
	_a.pulley = self
	_b.pulley = self
	return true


func _sim_tick(phase: int) -> void:
	var level: LevelBase = Game.level
	if level == null or not _resolve(level) or phase != Defs.Phase.WORLD:
		return
	weight_a = _a.rider_weight()
	weight_b = _b.rider_weight()
	var limit: int = range_rows * Tuning.TILE
	var was: int = step
	step = 0
	if weight_a > weight_b:
		step = mini(PartyTuning.PULLEY_SPEED_PX, limit - offset)
	elif weight_b > weight_a:
		step = -mini(PartyTuning.PULLEY_SPEED_PX, limit + offset)
	offset += step
	_a.pulley_dy = step
	_b.pulley_dy = -step
	if step != 0:
		_turn += 1 if step > 0 else -1
		if was == 0:
			ObjTuning.play_cue(Sfx.PULLEY, Sfx.QUAKE)


func _on_level_reset() -> void:
	offset = 0
	step = 0
	weight_a = 0
	weight_b = 0
	if _a != null:
		_a.pulley_dy = 0
	if _b != null:
		_b.pulley_dy = 0


func _process(_delta: float) -> void:
	if is_visible_in_tree():
		queue_redraw()


func _draw() -> void:
	if _a == null or _b == null or not is_instance_valid(_a) or not is_instance_valid(_b):
		return
	var beam_y: float = -float(Tuning.TILE * Tuning.ART_SCALE) / 2.0
	var wheel: int = posmod(ObjTuning.anim_frame(absi(_turn), ObjTuning.PULLEY_TURN_FPS) * signi(_turn),
			WHEEL_FRAMES)
	var xs: Array[float] = []
	for platform: MovingPlatform in [_a, _b]:
		var x: float = platform.position.x - position.x
		var wheel_y: float = beam_y + WHEEL_DROP_ART
		var top: float = platform.position.y - position.y - float(platform.box_h * Tuning.ART_SCALE)
		_draw_rope(x, wheel_y, top)
		_draw_cell(FRAME_KNOT, Vector2(x, top - CELL_ART / 2.0))
		_draw_cell(wheel, Vector2(x, wheel_y))
		_draw_cell(FRAME_STRAP, Vector2(x, beam_y))
		xs.append(x)
	# The rope between the wheel tops.
	var left: float = minf(xs[0], xs[1])
	var right: float = maxf(xs[0], xs[1])
	var y: float = beam_y + WHEEL_DROP_ART - CELL_ART / 2.0 + 2.0
	draw_line(Vector2(left, y), Vector2(right, y), Color8(46, 39, 31), 4.0)
	draw_line(Vector2(left, y), Vector2(right, y), Color8(176, 134, 82), 2.0)


func _draw_cell(frame: int, centre: Vector2) -> void:
	draw_texture_rect_region(TEXTURE, Rect2(centre - Vector2(CELL_ART, CELL_ART) / 2.0, Vector2(CELL_ART, CELL_ART)),
			Rect2(frame * CELL_ART, 0, CELL_ART, CELL_ART))


## The rope piece tiled from `from_y` down to `to_y` (local art px) at x.
func _draw_rope(x: float, from_y: float, to_y: float) -> void:
	var y: float = from_y
	while y < to_y:
		var h: float = minf(CELL_ART, to_y - y)
		draw_texture_rect_region(TEXTURE, Rect2(x - CELL_ART / 2.0, y, CELL_ART, h),
				Rect2(FRAME_ROPE * CELL_ART, 0, CELL_ART, h))
		y += CELL_ART
