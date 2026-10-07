class_name UiGround
extends Control
## A strip of terrain along the bottom edge of a screen, drawn from a terrain atlas (ASSET_MANIFEST.md 10.1):
## one row of surface tiles on top of fill tiles. Characters of cut scenes stand on [method get_surface_y].
##
## Owner: ui. Anchored to the bottom edge and as wide as the parent, whatever the view size.

const TILE: int = 32
const COLUMNS: int = 8
const TILE_TOP: int = 1
const TILE_FILL: int = 9
const TILE_FILL_B: int = 23
const TERRAIN_DIR: String = "res://assets/tiles/"

var _atlas: Texture2D = null
var _rows: int = 2


## `terrain` is an atlas path under assets/tiles without extension, e.g. "jungle/terrain_grass".
func _init(terrain: String = "jungle/terrain_grass", rows: int = 2) -> void:
	_atlas = UiKit.tex(TERRAIN_DIR + terrain + ".png")
	_rows = maxi(1, rows)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	offset_top = -float(_rows * TILE)
	offset_bottom = 0.0


## True when the terrain atlas was found (else the strip is drawn in ink).
func has_atlas() -> bool:
	return _atlas != null


## Y of the walkable surface in the parent's coordinates (a few px into the grass, like the level art).
func get_surface_y() -> float:
	return position.y + 10.0


func _draw() -> void:
	if _atlas == null:
		draw_rect(Rect2(Vector2.ZERO, size), UiKit.COL_INK)
		return
	var columns: int = ceili(size.x / float(TILE)) + 1
	for row: int in _rows:
		for column: int in columns:
			var index: int = TILE_TOP
			if row > 0:
				index = TILE_FILL_B if ((column * 7 + row * 3) % 9) == 0 else TILE_FILL
			var source: Rect2 = Rect2(
				float((index % COLUMNS) * TILE), float((index / COLUMNS) * TILE), float(TILE), float(TILE)
			)
			draw_texture_rect_region(_atlas, Rect2(float(column * TILE), float(row * TILE), float(TILE),
					float(TILE)), source)
