class_name FxDebris
extends FxBase
## `fx/debris` (`kind=rock|wood|ice|leaf` [rock], `count` [4]): bits of scenery sprayed by a club hit, a broken
## block or a smashed container. Hand-rolled sprites (no particle system): every bit flies on its own arc with
## gravity, drawn between ticks with the simulation's interpolation, and blinks out at the end.
##
## Bits collide cheaply with the level's tiles, one cell lookup per bit and tick: a falling bit that crosses the
## surface of a floor (solid, one-way, hatch, slope) bounces off it with lost energy and soon lies still; a rising
## bit that crosses into a solid ceiling stops rising. Spikes and liquids let it through.

const KINDS: Array[String] = ["rock", "wood", "ice", "leaf"]
const TEXTURES: Array[Texture2D] = [
	preload("res://assets/sprites/fx/debris_rock.png"),
	preload("res://assets/sprites/fx/debris_wood.png"),
	preload("res://assets/sprites/fx/particles_snow.png"),
	preload("res://assets/sprites/fx/particles_leaf.png"),
]
## Frames per sheet [M 9] and the half size of a cell (pivot), art px.
const FRAMES: Array[int] = [4, 5, 6, 4]
const PIVOT: Vector2 = Vector2(10, 10)
## Extra upward speed range of a bit, v16.
const LIFT_RANGE: int = 64
## A bounce keeps BOUNCE_KEEP / 8 of the falling speed (upwards) and half the sideways speed; a bounce slower than
## REST_YVEL v16 lays the bit to rest on the floor.
const BOUNCE_KEEP: int = 3
const REST_YVEL: int = 20

var _x16: PackedInt32Array = PackedInt32Array()
var _y16: PackedInt32Array = PackedInt32Array()
var _prev_x16: PackedInt32Array = PackedInt32Array()
var _prev_y16: PackedInt32Array = PackedInt32Array()
var _vx: PackedInt32Array = PackedInt32Array()
var _vy: PackedInt32Array = PackedInt32Array()
## 1 while a bit lies on a floor.
var _resting: PackedByteArray = PackedByteArray()
var _bits: Array[Sprite2D] = []


func _apply_params(params: Dictionary) -> void:
	lifetime = ObjTuning.DEBRIS_LIFE
	var kind: int = maxi(KINDS.find(str(params.get("kind", KINDS[0]))), 0)
	var count: int = clampi(int(params.get("count", ObjTuning.DEBRIS_DEFAULT_COUNT)), 1, ObjTuning.DEBRIS_MAX_COUNT)
	var rng: SimRng = make_rng()
	for i: int in count:
		var bit: Sprite2D = Sprite2D.new()
		bit.texture = TEXTURES[kind]
		bit.hframes = FRAMES[kind]
		bit.frame = rng.next_int(FRAMES[kind])
		bit.centered = false
		bit.offset = -PIVOT
		bit.flip_h = rng.chance(1, 2)
		add_child(bit)
		_bits.append(bit)
		# Alternate sides so that even a small count sprays both ways.
		var side: int = 1 if (i & 1) == 0 else -1
		_x16.append(0)
		_y16.append(0)
		_prev_x16.append(0)
		_prev_y16.append(0)
		_vx.append(side * rng.range_int(ObjTuning.DEBRIS_XVEL >> 2, ObjTuning.DEBRIS_XVEL))
		_vy.append(ObjTuning.DEBRIS_YVEL - rng.next_int(LIFT_RANGE))
		_resting.append(0)


func _fx_tick() -> void:
	var grid: TileGrid = Game.level.grid if Game.level != null else null
	for i: int in _bits.size():
		_prev_x16[i] = _x16[i]
		_prev_y16[i] = _y16[i]
		if _resting[i] != 0:
			continue
		_x16[i] += _vx[i]
		_y16[i] += _vy[i]
		if grid != null:
			_collide(grid, i)
		if _resting[i] == 0:
			_vy[i] += ObjTuning.DEBRIS_GRAVITY
	if lifetime - age <= Tuning.DROPPED_ITEM_BLINK >> 1:
		visible = (age & 1) == 0


## True while bit `index` lies still on a floor (tests).
func is_resting(index: int) -> bool:
	return _resting[index] != 0


## Logical feet point of bit `index` after the last tick (tests).
func bit_pos(index: int) -> Vector2i:
	return sim_pos + Vector2i(_x16[index] >> 4, _y16[index] >> 4)


## One cell lookup: land on (and bounce off) a floor surface crossed while falling, stop under a solid ceiling
## entered while rising.
func _collide(grid: TileGrid, i: int) -> void:
	var x: int = sim_pos.x + (_x16[i] >> 4)
	var y: int = sim_pos.y + (_y16[i] >> 4)
	var prev_y: int = sim_pos.y + (_prev_y16[i] >> 4)
	var col: int = x >> 4
	var row: int = y >> 4
	if _vy[i] < 0:
		if row < (prev_y >> 4) and grid.ceiling_at(col, row) == TileGrid.CEILING_SOLID:
			_y16[i] = ((row + 1) * Tuning.TILE - sim_pos.y) << 4
			_vy[i] = 0
		return
	if not TileGrid.is_ground(grid.floor_at(col, row)):
		return
	var surface: int = row * Tuning.TILE + grid.surface_offset(col, row, x)
	if y < surface or prev_y >= surface:
		return
	_y16[i] = (surface - sim_pos.y) << 4
	var rebound: int = (_vy[i] * BOUNCE_KEEP) >> 3
	_vx[i] /= 2
	if rebound < REST_YVEL:
		_resting[i] = 1
		_vy[i] = 0
		_vx[i] = 0
	else:
		_vy[i] = -rebound


func _process(_delta: float) -> void:
	var alpha: float = Sim.alpha
	var scale_px: float = float(Tuning.ART_SCALE) / 16.0
	for i: int in _bits.size():
		var x: float = lerpf(float(_prev_x16[i]), float(_x16[i]), alpha) * scale_px
		var y: float = lerpf(float(_prev_y16[i]), float(_y16[i]), alpha) * scale_px
		_bits[i].position = Vector2(roundf(x), roundf(y))
