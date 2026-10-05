class_name WorldParallax
extends Node2D
## The parallax backdrop of a level (ASSET_MANIFEST 11, ARCHITECTURE.md 5.2 `Parallax`). Owner: world.
##
## Draws the layers of one ParallaxSets set behind everything, in level coordinates at the camera's top-left
## corner, so the picture always covers the whole view whatever its size. Horizontal offsets are whole pixels
## and wrap at each image's width (the loop length); seamless wall patterns also scroll and wrap vertically.
## Purely visual: it is told where the view is every rendered frame.

var _set_name: String = "none"
var _fill: Color = ParallaxSets.NONE_FILL
var _layers: Array[Dictionary] = []
var _textures: Array[Texture2D] = []
var _view_pos: Vector2 = Vector2.ZERO
var _view_size: Vector2 = Vector2(Tuning.VIEW_W * Tuning.ART_SCALE, Tuning.VIEW_H * Tuning.ART_SCALE)
var _sink: float = 0.0
var _rise: float = 0.0


func _init() -> void:
	z_index = Defs.Z_PARALLAX
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED


## Use the parallax set `set_id` (meta key `background`; "none" = plain fill colour). Returns false when the
## set or one of its images does not exist (the backdrop is then the plain fill).
func setup(set_id: String) -> bool:
	_set_name = set_id
	_fill = ParallaxSets.fill_color(set_id)
	_layers.clear()
	_textures.clear()
	var complete: bool = set_id == "none" or ParallaxSets.has_set(set_id)
	for layer: Dictionary in ParallaxSets.layers(set_id):
		var path: String = ParallaxSets.texture_path(layer)
		if not ResourceLoader.exists(path):
			complete = false
			continue
		_layers.append(layer)
		_textures.append(load(path) as Texture2D)
	queue_redraw()
	return complete


## Name of the set in use.
func get_set_name() -> String:
	return _set_name


## Number of image layers drawn.
func get_layer_count() -> int:
	return _layers.size()


## Where the view is: top-left corner and size in art px (whole pixels), and how far it is above its lowest
## (`sink`) and below its highest (`rise`) position, for the vertical parallax of the edge bands.
func set_view(top_left: Vector2, size: Vector2, sink: float = 0.0, rise: float = 0.0) -> void:
	if top_left == _view_pos and size == _view_size and sink == _sink and rise == _rise:
		return
	_view_pos = top_left
	_view_size = size
	_sink = sink
	_rise = rise
	queue_redraw()


func _draw() -> void:
	var covered: float = 0.0
	if not _layers.is_empty():
		match int(_layers[0]["anchor"]):
			ParallaxSets.Anchor.SKY:
				covered = float(_textures[0].get_height())
			ParallaxSets.Anchor.TILE:
				covered = _view_size.y
	if covered < _view_size.y:
		draw_rect(Rect2(_view_pos + Vector2(0.0, covered), Vector2(_view_size.x, _view_size.y - covered)), _fill)
	for i: int in _layers.size():
		var layer: Dictionary = _layers[i]
		var texture: Texture2D = _textures[i]
		var image_size: Vector2i = Vector2i(texture.get_width(), texture.get_height())
		var scroll: float = float(layer["scroll"])
		var offset: int = ParallaxSets.scroll_offset(_view_pos.x, scroll, image_size.x)
		var offset_y: int = 0
		if int(layer["anchor"]) == ParallaxSets.Anchor.TILE:
			offset_y = ParallaxSets.scroll_offset(_view_pos.y, scroll, image_size.y)
		for piece: Array in ParallaxSets.layer_pieces(layer, image_size, _view_size, offset, _sink, _rise):
			var dest: Rect2 = piece[0]
			var source: Rect2 = piece[1]
			source.position.y += offset_y
			draw_texture_rect_region(
				texture, Rect2(_view_pos + dest.position, dest.size), source, Color.WHITE, false, false
			)
