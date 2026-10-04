class_name LevelLooks
extends RefCounted
## What every cell of a level shows on the three tile layers (ARCHITECTURE.md 5.2, 7.4, 7.8). Owner: world.
##
## Combines the automatic tiles of LevelTiles with the level file's [backwall] and [overrides] sections and the
## run-time looks of LevelBase.set_cell_look(). The level scene paints its TileMapLayers from it and the preview
## renderer (tools/world_render_level.gd) draws the very same picture, so they cannot disagree.
##
## Layers: BACK (z -50, back walls), MAIN (z 0, terrain) and FRONT (z 80, liquids and front overrides).
## Precedence on MAIN: run-time look > override > automatic tile; on BACK: override > back wall; on FRONT:
## override > liquid.

enum Layer { BACK, MAIN, FRONT }

## Shade of the BACK layer: back walls read as "behind" next to the solid terrain of the same atlas (in some
## sets the back-wall tiles are as bright as the ground).
const BACK_TINT: Color = Color(0.74, 0.76, 0.84)
## Ceiling-anchored props (ASSET_MANIFEST 10.4): anchored top-centre at the top of their cell.
const CEILING_PROPS: Array[String] = ["stalactite", "drips", "drip_cap", "icicle", "vine_a", "vine_b", "moss_fringe"]

## Width of the map in tiles.
var cols: int = 0
## Height of the map in tiles.
var rows: int = 0
## Fixed legend character of every cell as a byte (LevelTiles codes), row-major.
var codes: PackedByteArray = PackedByteArray()
## Problems of the [backwall] / [overrides] sections found by [method setup]: { "line", "message" }.
var issues: Array[Dictionary] = []

var _looks: Dictionary = {}            # Vector2i -> look set at run time (set_cell_look)
var _main_overrides: Dictionary = {}   # Vector2i -> look
var _back_overrides: Dictionary = {}
var _front_overrides: Dictionary = {}
var _backwall: Dictionary = {}         # Vector2i -> back-wall look


## Build from a parsed level and its collision grid. Front overrides also mark their cells FLAG_FOREGROUND in
## the grid (cosmetic flag of PHYSICS.md 11.1).
func setup(data: LevelData, grid: TileGrid) -> void:
	cols = grid.cols
	rows = grid.rows
	codes = LevelTiles.codes_from_grid(grid)
	issues.clear()
	_looks.clear()
	_backwall.clear()
	for wall: Dictionary in data.backwalls:
		var rect: Rect2i = wall["rect"]
		var set_id: int = LevelTiles.SET_B if bool(wall["set_b"]) else LevelTiles.SET_A
		for row: int in range(rect.position.y, rect.end.y):
			for col: int in range(rect.position.x, rect.end.x):
				if grid.in_bounds(col, row):
					_backwall[Vector2i(col, row)] = LevelTiles.look(
						set_id, LevelTiles.backwall_index(col, row, int(wall["deco"]))
					)
	_main_overrides.clear()
	_back_overrides.clear()
	_front_overrides.clear()
	for entry: Dictionary in data.overrides:
		var cell: Vector2i = entry["cell"]
		var index: int = int(entry["index"])
		if not grid.in_bounds(cell.x, cell.y) or index < 0 or index >= LevelTiles.ATLAS_TILES:
			issues.append({"line": int(entry["line"]), "message": "override outside the map or index not 0..39"})
			continue
		var look: int = LevelTiles.look(LevelTiles.SET_B if bool(entry["set_b"]) else LevelTiles.SET_A, index)
		match str(entry["layer"]):
			"back":
				_back_overrides[cell] = look
			"front":
				_front_overrides[cell] = look
				grid.set_flag_bits(cell.x, cell.y, TileGrid.FLAG_FOREGROUND, true)
			_:
				_main_overrides[cell] = look


## True when (col, row) is inside the map.
func in_map(col: int, row: int) -> bool:
	return col >= 0 and row >= 0 and col < cols and row < rows


## The fixed legend character of a cell changed (LevelBase.set_cell).
func set_code(col: int, row: int, ch: String) -> void:
	if in_map(col, row):
		codes[row * cols + col] = ch.unicode_at(0)


## Run-time look of a cell (LevelBase.set_cell_look): a terrain-atlas index drawn from the cell's own set, or -1
## to go back to the automatic tile.
func set_look(col: int, row: int, atlas_index: int) -> void:
	var cell: Vector2i = Vector2i(col, row)
	if not in_map(col, row) or atlas_index < 0 or atlas_index >= LevelTiles.ATLAS_TILES:
		_looks.erase(cell)
		return
	var set_id: int = LevelTiles.SET_B if codes[row * cols + col] == LevelTiles.C_SOLID_B else LevelTiles.SET_A
	_looks[cell] = LevelTiles.look(set_id, atlas_index)


## The look of a cell on a layer (LevelTiles look, LevelTiles.LOOK_NONE = nothing).
func look_at(col: int, row: int, layer: Layer) -> int:
	if not in_map(col, row):
		return LevelTiles.LOOK_NONE
	var cell: Vector2i = Vector2i(col, row)
	var code: int = codes[row * cols + col]
	match layer:
		Layer.BACK:
			if not _back_overrides.is_empty() and _back_overrides.has(cell):
				return _back_overrides[cell]
			if not _backwall.is_empty() and _backwall.has(cell) and LevelTiles.shows_backwall(code):
				return _backwall[cell]
			return LevelTiles.LOOK_NONE
		Layer.FRONT:
			if not _front_overrides.is_empty() and _front_overrides.has(cell):
				return _front_overrides[cell]
			if code != LevelTiles.C_LIQUID:
				return LevelTiles.LOOK_NONE
			return LevelTiles.cell_look(codes, cols, col, row)
	if not _looks.is_empty() and _looks.has(cell):
		return _looks[cell]
	if not _main_overrides.is_empty() and _main_overrides.has(cell):
		return _main_overrides[cell]
	if code == LevelTiles.C_AIR or code == LevelTiles.C_LIQUID:
		return LevelTiles.LOOK_NONE
	return LevelTiles.cell_look(codes, cols, col, row)


## Looks of the cells OUTSIDE the map within `area` (tiles): the ground continues beyond the edges, so a view
## larger than the level never shows a cut-off map. Solid edge cells continue outwards in every direction,
## liquid continues sideways and downwards, everything else is air. Returns { Vector2i: look }.
func apron_looks(area: Rect2i) -> Dictionary:
	var result: Dictionary = {}
	if cols == 0 or rows == 0:
		return result
	var ext_cols: int = area.size.x
	var ext: PackedByteArray = PackedByteArray()
	ext.resize(ext_cols * area.size.y)
	for r: int in area.size.y:
		for c: int in ext_cols:
			ext[r * ext_cols + c] = _apron_code(c + area.position.x, r + area.position.y)
	for r: int in area.size.y:
		for c: int in ext_cols:
			var col: int = c + area.position.x
			var row: int = r + area.position.y
			if in_map(col, row):
				continue
			var look: int = LevelTiles.cell_look(ext, ext_cols, c, r)
			if look >= 0:
				result[Vector2i(col, row)] = look
	return result


## Top-left corner (art px) of a prop picture of `texture_size` placed with its feet point at `feet` (logical
## px): bottom-centre anchored, or top-centre at the top of the cell for ceiling props.
static func prop_top_left(id: StringName, feet: Vector2i, texture_size: Vector2i) -> Vector2i:
	var anchor: Vector2i = feet * Tuning.ART_SCALE
	if is_ceiling_prop(id):
		return Vector2i(anchor.x - texture_size.x / 2, anchor.y - Tuning.TILE_ART)
	return Vector2i(anchor.x - texture_size.x / 2, anchor.y - texture_size.y)


## True for the ceiling-anchored props.
static func is_ceiling_prop(id: StringName) -> bool:
	return CEILING_PROPS.has(String(id).get_file())


func _apron_code(col: int, row: int) -> int:
	var code: int = codes[clampi(row, 0, rows - 1) * cols + clampi(col, 0, cols - 1)]
	if in_map(col, row) or LevelTiles.is_solid_like(code):
		return code
	if code == LevelTiles.C_LIQUID and row >= 0:
		return code
	return LevelTiles.C_AIR
