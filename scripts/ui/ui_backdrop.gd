class_name UiBackdrop
extends Control
## Full-screen parallax backdrop for menus, drawn from one of the background sets (ASSET_MANIFEST.md 11).
##
## Owner: ui. The layers are 360 art px high and loop horizontally; they are anchored to the bottom edge and the
## back layer continues above them on views taller than 360 px (mirrored skies, tiled walls), so the picture is
## complete on every aspect ratio. Layers drift at their manifest scroll factors for a slow, living backdrop.

## set name -> { "top": colour behind everything, "tile_up": layer 0 repeats upwards as it is (walls) instead
##               of mirrored (skies), "layers": [[file name, scroll factor], ...] back to front }.
const SETS: Dictionary = {
	"jungle": {
		"top": Color("98e6ff"), "tile_up": false,
		"layers": [["layer0_sky", 0.0], ["layer1_far_hills", 0.1], ["layer2_hills", 0.25], ["layer3_forest", 0.5]],
	},
	"cave": {
		"top": Color("2d2541"), "tile_up": true,
		"layers": [["layer0_wall", 0.1], ["layer1_rocks_far", 0.3], ["layer2_ceiling_near", 0.6]],
	},
	"ice": {
		"top": Color("c6eaff"), "tile_up": false,
		"layers": [["layer0_sky", 0.0], ["layer1_far_peaks", 0.1], ["layer2_ridges", 0.25],
			["layer3_snow_forest", 0.5]],
	},
	"volcano": {
		"top": Color("cc3817"), "tile_up": false,
		"layers": [["layer0_sky", 0.0], ["layer1_far_cones", 0.1], ["layer2_basalt", 0.25],
			["layer3_burnt_forest", 0.5]],
	},
	"feast": {
		"top": Color("ffe3ef"), "tile_up": false,
		"layers": [["layer0_sky", 0.0], ["layer1_clouds", 0.08], ["layer2_scoops", 0.25], ["layer3_meadow", 0.5]],
	},
}
const BACKGROUND_DIR: String = "res://assets/backgrounds/"

## Drift of a plane with scroll factor 1 in art px per second (0 = static picture).
var speed: float = 24.0

var _top: Color = UiKit.COL_INK
var _tile_up: bool = false
var _textures: Array[Texture2D] = []
var _factors: PackedFloat32Array = PackedFloat32Array()
var _scroll: float = 0.0


func _init(set_id: String = "jungle", p_speed: float = 24.0) -> void:
	speed = p_speed
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	set_backdrop(set_id)


func _process(delta: float) -> void:
	if speed == 0.0:
		return
	_scroll += delta * speed
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), _top)
	for i: int in _textures.size():
		var texture: Texture2D = _textures[i]
		var width: float = texture.get_size().x
		var height: float = texture.get_size().y
		var top: float = size.y - height
		var start: float = -floorf(fposmod(_scroll * _factors[i], width))
		var rows: int = 1
		if i == 0 and top > 0.0:
			rows = 1 + ceili(top / height)
		for row: int in rows:
			# Above the picture the back layer repeats: tiled for walls, mirrored for skies (seamless clouds).
			var mirrored: bool = row % 2 == 1 and not _tile_up
			var y: float = top - float(row) * height
			var x: float = start
			while x < size.x:
				if mirrored:
					draw_texture_rect(texture, Rect2(x, y, width, -height), false)
				else:
					draw_texture(texture, Vector2(x, y))
				x += width


## Switch to another background set (a key of SETS).
func set_backdrop(set_id: String) -> void:
	_textures.clear()
	_factors = PackedFloat32Array()
	var entry: Dictionary = SETS.get(set_id, {})
	if entry.is_empty():
		push_error("UiBackdrop: unknown background set '%s'" % set_id)
		return
	_top = entry["top"]
	_tile_up = bool(entry["tile_up"])
	for layer: Array in entry["layers"]:
		var texture: Texture2D = UiKit.tex(BACKGROUND_DIR + set_id + "/" + str(layer[0]) + ".png")
		if texture != null:
			_textures.append(texture)
			_factors.append(float(layer[1]))
	queue_redraw()
