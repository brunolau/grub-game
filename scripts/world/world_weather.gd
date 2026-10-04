class_name WorldWeather
extends Node2D
## Snowfall that shows the wind of a blizzard level (GAMEPLAY.md 7.9, PHYSICS.md 13.1). Owner: world.
##
## Cosmetic only: flakes from `sprites/fx/particles_snow.png` drift across the view, their number and slant
## follow the level's wind value. Positions are a function of a free-running clock in art px; nothing here is
## read by the simulation.

const SNOW_TEXTURE: String = "res://assets/sprites/fx/particles_snow.png"
const FLAKE_CELL: int = 20
const FLAKE_FRAMES: int = 6
## Flakes at the strongest wind; fewer for a light wind.
const MAX_FLAKES: int = 96
## Wind value (v16 per WIND call, PHYSICS.md 13.1) at which the snow is at its densest.
const FULL_WIND: int = 96
## Fall speed of a flake in art px per second, and the extra sideways speed at full wind.
const FALL_SPEED: float = 70.0
const DRIFT_SPEED: float = 260.0
## Z order: in front of every actor and the front props, behind the front tiles.
const Z_WEATHER: int = Defs.Z_PROPS_FRONT + 5

var _texture: Texture2D = null
var _wind: int = 0
var _clock: float = 0.0
var _view_pos: Vector2 = Vector2.ZERO
var _view_size: Vector2 = Vector2.ZERO
var _seeds: PackedVector4Array = PackedVector4Array()


func _init() -> void:
	z_index = Z_WEATHER
	visible = false
	# Flake layout from a fixed integer hash: the same level always shows the same snowfall.
	for i: int in MAX_FLAKES:
		_seeds.append(Vector4(
			_unit(i, 1), _unit(i, 2), 0.6 + 0.8 * _unit(i, 3), float(LevelTiles.cell_hash(i, 4) % FLAKE_FRAMES)
		))


func _ready() -> void:
	if ResourceLoader.exists(SNOW_TEXTURE):
		_texture = load(SNOW_TEXTURE) as Texture2D


## The level's wind value changed.
func set_wind(value: int) -> void:
	_wind = value
	visible = _wind != 0 and _texture != null


## Where the view is (art px) and how much real time passed.
func advance(view_pos: Vector2, view_size: Vector2, delta: float) -> void:
	if not visible:
		return
	_clock += delta
	_view_pos = view_pos
	_view_size = view_size
	queue_redraw()


static func _unit(index: int, salt: int) -> float:
	return float(LevelTiles.cell_hash(index * 7 + salt, salt * 131 + index) % 10007) / 10007.0


func _draw() -> void:
	if _texture == null or _view_size.x <= 0.0:
		return
	var strength: float = clampf(absf(float(_wind)) / float(FULL_WIND), 0.0, 1.0)
	var count: int = int(ceilf(float(MAX_FLAKES) * strength))
	var direction: float = -signf(float(_wind))
	var span: Vector2 = _view_size + Vector2(FLAKE_CELL, FLAKE_CELL) * 2.0
	for i: int in count:
		var flake: Vector4 = _seeds[i]
		var speed: float = flake.z
		var x: float = flake.x * span.x + direction * DRIFT_SPEED * strength * speed * _clock
		var y: float = flake.y * span.y + FALL_SPEED * speed * _clock
		var at: Vector2 = Vector2(fposmod(x, span.x), fposmod(y, span.y)) - Vector2(FLAKE_CELL, FLAKE_CELL)
		var frame: int = int(flake.w) % FLAKE_FRAMES
		draw_texture_rect_region(
			_texture, Rect2((_view_pos + at).round(), Vector2(FLAKE_CELL, FLAKE_CELL)),
			Rect2(frame * FLAKE_CELL, 0, FLAKE_CELL, FLAKE_CELL)
		)
