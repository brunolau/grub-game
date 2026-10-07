class_name WorldWeather
extends Node2D
## What shows the wind of a level (GAMEPLAY.md 7.9, PHYSICS.md 13.1; 2.0 alternating gusts, C.6). Owner: world.
##
## Two styles, picked by the level's biome ([method set_style]): SNOW (the 1.0 blizzard: flakes from
## `sprites/fx/particles_snow.png` drift across the view, their number and slant follow the wind value) on ice levels,
## and GUST (2.0, every other biome - the Roc's Spire, Cloud Top, the Gusty variant): pale streaks race across the
## view in the wind's direction, more and faster as it blows harder, so a player sees a gust turn before it pushes
## him. Both follow the sign of the wind (negative = it blows to the right).
##
## Cosmetic only: positions are a function of a free-running clock in art px; nothing here is read by the simulation.

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

## Styles ([method set_style]).
const STYLE_SNOW: int = 0
const STYLE_GUST: int = 1
## Gust streaks at full wind, their length range and speed (art px, art px per second at full wind), colour.
const MAX_STREAKS: int = 40
const STREAK_MIN_ART: float = 14.0
const STREAK_MAX_ART: float = 46.0
const STREAK_SPEED: float = 900.0
const STREAK_COLOR: Color = Color(1.0, 1.0, 1.0, 0.42)

## The style in use (STYLE_SNOW on ice levels, STYLE_GUST elsewhere).
var style: int = STYLE_SNOW

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


## The style of the level's biome: snow on `ice`, gust streaks everywhere else.
static func style_for_biome(biome: String) -> int:
	return STYLE_SNOW if biome == "ice" else STYLE_GUST


func set_style(value: int) -> void:
	style = value
	set_wind(_wind)


## The level's wind value changed.
func set_wind(value: int) -> void:
	_wind = value
	visible = _wind != 0 and (_texture != null or style == STYLE_GUST)


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


## Gust streak `index` at `clock` seconds for a wind of `wind`, in a view of `view_size` art px: its rectangle in view
## coordinates (art px). Streaks run the way the wind blows (positive wind: to the left).
static func gust_streak(index: int, clock: float, wind: int, view_size: Vector2) -> Rect2:
	var strength: float = clampf(absf(float(wind)) / float(FULL_WIND), 0.0, 1.0)
	var direction: float = -signf(float(wind))
	var length: float = lerpf(STREAK_MIN_ART, STREAK_MAX_ART, _unit(index, 5)) * (0.5 + 0.5 * strength)
	var span: Vector2 = view_size + Vector2(STREAK_MAX_ART * 2.0, 0.0)
	var speed: float = STREAK_SPEED * (0.35 + 0.65 * strength) * (0.7 + 0.6 * _unit(index, 6))
	var x: float = fposmod(_unit(index, 7) * span.x + direction * speed * clock, span.x) - STREAK_MAX_ART
	var y: float = _unit(index, 8) * view_size.y + sin(clock * 3.0 + float(index)) * 3.0
	return Rect2(Vector2(x, y).round(), Vector2(roundf(length), 2.0))


func _draw() -> void:
	if _view_size.x <= 0.0:
		return
	var strength: float = clampf(absf(float(_wind)) / float(FULL_WIND), 0.0, 1.0)
	if style == STYLE_GUST:
		var streaks: int = int(ceilf(float(MAX_STREAKS) * strength))
		for i: int in streaks:
			var streak: Rect2 = gust_streak(i, _clock, _wind, _view_size)
			draw_rect(Rect2(_view_pos + streak.position, streak.size), STREAK_COLOR)
		return
	if _texture == null:
		return
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
