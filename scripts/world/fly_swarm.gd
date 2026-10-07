class_name FlySwarm
extends Node2D
## The flies of GAMEPLAY.md 7.9: after a hero walked over dirty ground (`zones/flies`), up to Tuning.MAX_FLIES
## single-pixel flies buzz around him until he picks up `items/water_bucket` (Events.item_collected), the level
## respawns or he leaves the level. Owner: world.
##
## 2.0 (G1 follow-up, TECH_AUDIT.md 3.13 "swarm per hero"): one swarm PER HERO - the flies a hero gathered circle
## him, not P1; the water bucket washes only the hero who took it (the one nearest to the bucket in a party). A party
## of one is exactly the 1.0 swarm.
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

## Flies of every swarm together (a party of one: around the hero).
var count: int = 0

var _positions: PackedVector2Array = PackedVector2Array()
var _velocities: PackedVector2Array = PackedVector2Array()
var _targets: PackedVector2Array = PackedVector2Array()
## The player slot each fly circles.
var _owners: PackedInt32Array = PackedInt32Array()
var _retarget: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _init() -> void:
	z_index = Defs.Z_FX
	_rng.seed = 7


func _ready() -> void:
	Events.item_collected.connect(_on_item_collected)
	Events.level_respawned.connect(clear)


## More flies join the swarm of the hero of `slot` (at most Tuning.MAX_FLIES around him); they appear around him.
func attract(amount: int, slot: int = 0) -> void:
	var wanted: int = clampi(count_of(slot) + amount, 0, Tuning.MAX_FLIES)
	var centre: Vector2 = _centre(slot)
	var have: int = count_of(slot)
	while have < wanted:
		_positions.append(centre + _random_offset())
		_velocities.append(Vector2.ZERO)
		_targets.append(_random_offset())
		_owners.append(slot)
		have += 1
		count += 1
	queue_redraw()


## Flies around the hero of `slot`.
func count_of(slot: int) -> int:
	var found: int = 0
	for who: int in _owners:
		if who == slot:
			found += 1
	return found


## Every fly is gone (`slot` < 0: every swarm - a respawn), or only those of the hero of `slot` (water).
func clear(slot: int = -1) -> void:
	if slot < 0:
		count = 0
		_positions.clear()
		_velocities.clear()
		_targets.clear()
		_owners.clear()
		queue_redraw()
		return
	for i: int in range(_owners.size() - 1, -1, -1):
		if _owners[i] == slot:
			_positions.remove_at(i)
			_velocities.remove_at(i)
			_targets.remove_at(i)
			_owners.remove_at(i)
			count -= 1
	queue_redraw()


func _process(delta: float) -> void:
	if count == 0:
		return
	_retarget -= delta
	var retarget: bool = _retarget <= 0.0
	if retarget:
		_retarget = RETARGET_SECONDS
	var centres: Dictionary = {}
	for i: int in count:
		var slot: int = _owners[i]
		if not centres.has(slot):
			centres[slot] = _centre(slot, _positions[i])
		var centre: Vector2 = centres[slot]
		if retarget and _rng.randi_range(0, 2) == 0:
			_targets[i] = _random_offset()
		var velocity: Vector2 = _velocities[i] + (centre + _targets[i] - _positions[i]).normalized() * PULL * delta
		_velocities[i] = velocity.limit_length(MAX_SPEED)
		_positions[i] += _velocities[i] * delta
	queue_redraw()


func _draw() -> void:
	for i: int in count:
		draw_rect(Rect2(_positions[i].round(), FLY_SIZE), FLY_COLOR)


## Where the swarm of `slot` circles: above that hero's (interpolated, drawn) position; without him it stays put
## (around `fallback`).
func _centre(slot: int, fallback: Vector2 = Vector2.ZERO) -> Vector2:
	var hero: PlayerBase = _hero(slot)
	if hero == null:
		return fallback
	return hero.position - Vector2(0.0, CENTRE_RISE)


static func _hero(slot: int) -> PlayerBase:
	var level: LevelBase = Game.level
	if level == null:
		return null
	return level.player if slot == 0 else level.get_hero(slot)


func _random_offset() -> Vector2:
	return Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(RADIUS * 0.3, RADIUS)


## The water bucket washes the hero who took it: in a party the living hero nearest to where it lay.
func _on_item_collected(item_id: StringName, _index: int, _points: int, pos: Vector2i) -> void:
	if item_id != WATER_BUCKET:
		return
	var level: LevelBase = Game.level
	if level == null or level.hero_count() <= 1:
		clear()
		return
	var best: int = 0
	var best_distance: int = 1 << 30
	for hero: PlayerBase in level.contact_order():
		if hero.dead or hero.is_down():
			continue
		var distance: int = absi(hero.sim_pos.x - pos.x) + absi(hero.sim_pos.y - pos.y)
		if distance < best_distance:
			best_distance = distance
			best = hero.slot
	clear(best)
