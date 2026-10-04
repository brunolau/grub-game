class_name FlySwarm
extends Node2D
## The flies of GAMEPLAY.md 7.9: after the hero walked over dirty ground (`zones/flies`), up to Tuning.MAX_FLIES
## single-pixel flies buzz around him until he picks up `items/water_bucket` (Events.item_collected), respawns or
## leaves the level. Owner: world.
##
## Cosmetic only: the flies move in `_process` with their own random generator (never Sim.rng) and nothing in the
## simulation reads them.

## Fly colour: the dark outline brown of the art set.
const FLY_COLOR: Color = Color("272018")
## A fly is one logical px.
const FLY_SIZE: Vector2 = Vector2(Tuning.ART_SCALE, Tuning.ART_SCALE)
## The swarm circles this point above the hero's feet (art px) ...
const CENTRE_RISE: float = 36.0
## ... within this radius (art px).
const RADIUS: float = 30.0
## Steering toward a random point of the swarm area, and the top speed, in art px per second (squared).
const PULL: float = 900.0
const MAX_SPEED: float = 160.0
## A fly picks a new point to head for after this many seconds.
const RETARGET_SECONDS: float = 0.35
const WATER_BUCKET: StringName = &"items/water_bucket"

## Flies around the hero now.
var count: int = 0

var _positions: PackedVector2Array = PackedVector2Array()
var _velocities: PackedVector2Array = PackedVector2Array()
var _targets: PackedVector2Array = PackedVector2Array()
var _retarget: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _init() -> void:
	z_index = Defs.Z_FX
	_rng.seed = 7


func _ready() -> void:
	Events.item_collected.connect(_on_item_collected)
	Events.level_respawned.connect(clear)


## More flies join the swarm (at most Tuning.MAX_FLIES in all); they appear around the hero.
func attract(amount: int) -> void:
	var wanted: int = clampi(count + amount, 0, Tuning.MAX_FLIES)
	var centre: Vector2 = _centre()
	while count < wanted:
		var start: Vector2 = centre + _random_offset()
		_positions.append(start)
		_velocities.append(Vector2.ZERO)
		_targets.append(_random_offset())
		count += 1
	queue_redraw()


## Every fly is gone (water, respawn).
func clear() -> void:
	count = 0
	_positions.clear()
	_velocities.clear()
	_targets.clear()
	queue_redraw()


func _process(delta: float) -> void:
	if count == 0:
		return
	_retarget -= delta
	var retarget: bool = _retarget <= 0.0
	if retarget:
		_retarget = RETARGET_SECONDS
	var centre: Vector2 = _centre()
	for i: int in count:
		if retarget and _rng.randi_range(0, 2) == 0:
			_targets[i] = _random_offset()
		var velocity: Vector2 = _velocities[i] + (centre + _targets[i] - _positions[i]).normalized() * PULL * delta
		_velocities[i] = velocity.limit_length(MAX_SPEED)
		_positions[i] += _velocities[i] * delta
	queue_redraw()


func _draw() -> void:
	for i: int in count:
		draw_rect(Rect2(_positions[i].round(), FLY_SIZE), FLY_COLOR)


## Where the swarm circles: above the hero's (interpolated, drawn) position; the swarm stays put without a hero.
func _centre() -> Vector2:
	var level: LevelBase = Game.level
	if level == null or level.player == null:
		return _positions[0] if not _positions.is_empty() else Vector2.ZERO
	return level.player.position - Vector2(0.0, CENTRE_RISE)


func _random_offset() -> Vector2:
	return Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(RADIUS * 0.3, RADIUS)


func _on_item_collected(item_id: StringName, _index: int, _points: int, _pos: Vector2i) -> void:
	if item_id == WATER_BUCKET:
		clear()
