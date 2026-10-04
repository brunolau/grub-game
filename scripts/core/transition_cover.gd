class_name TransitionCover
extends ColorRect
## The full-screen cover of Flow's transitions (GAMEPLAY.md 11.1). Owner: core.
##
## Three shapes, selected with a Defs.Transition value:
##  - FADE: the whole screen fades to the cover colour.
##  - CURTAIN: two panels slide in from the left and the right edge and meet at the column `focus.x`
##    (gameplay "opens with a centre-out curtain": the same movement backwards).
##  - IRIS: a frame closes in a circle on the point `focus` (the hero at the end of a level).
##
## `amount` is the only animated value: 0 = nothing covered (the node hides itself, so it costs no draw call),
## 1 = everything covered. Flow owns the single instance on CanvasLayer Defs.LAYER_TRANSITION and tweens it.

const SHADER: Shader = preload("res://scripts/core/transition_cover.gdshader")
## Extra px added to the reach, so that an opening of "reach" really uncovers the farthest pixel.
const REACH_MARGIN: float = 1.0

## Shape of the cover (Defs.Transition.FADE, CURTAIN or IRIS; NONE behaves like FADE).
var shape: int = Defs.Transition.FADE:
	set(value):
		shape = value
		_refresh()

## 0 = nothing covered ... 1 = everything covered.
var amount: float = 0.0:
	set(value):
		amount = clampf(value, 0.0, 1.0)
		_refresh()

## Centre of the iris / meeting column of the curtain, in px of this rectangle (= viewport px).
var focus: Vector2 = Vector2.ZERO:
	set(value):
		focus = value
		_refresh()

var _material: ShaderMaterial = ShaderMaterial.new()


func _init() -> void:
	color = Color.BLACK
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_material.shader = SHADER
	material = _material
	visible = false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(_refresh)
	_refresh()


## Put the focus in the middle of the rectangle.
func center_focus() -> void:
	focus = size * 0.5


## Distance in px from the focus to the farthest point the shape has to reach: the farther side edge for the
## curtain, the farthest corner for the iris. An opening of this size uncovers the whole rectangle.
func get_reach() -> float:
	var span: Vector2 = Vector2(maxf(focus.x, size.x - focus.x), maxf(focus.y, size.y - focus.y))
	if shape == Defs.Transition.CURTAIN:
		return span.x + REACH_MARGIN
	return span.length() + REACH_MARGIN


## Current size of the opening in px: half the gap between the curtain panels, or the radius of the iris hole.
func get_opening() -> float:
	return get_reach() * (1.0 - amount)


## The `amount` at which the opening is `opening_px` wide (used for the short stop of the iris around the hero).
func amount_for_opening(opening_px: float) -> float:
	return clampf(1.0 - opening_px / get_reach(), 0.0, 1.0)


func _refresh() -> void:
	visible = amount > 0.0
	if not visible:
		return
	_material.set_shader_parameter(&"shape", shape)
	_material.set_shader_parameter(&"amount", amount)
	_material.set_shader_parameter(&"rect_size", size)
	_material.set_shader_parameter(&"focus", focus)
	_material.set_shader_parameter(&"opening", get_opening())
