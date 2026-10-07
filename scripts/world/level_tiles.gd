class_name LevelTiles
extends RefCounted
## Visual auto-tiling of the level grid (docs/ARCHITECTURE.md 7.4, atlas indices of ASSET_MANIFEST 10.1).
## Owner: world.
##
## Pure functions from tile characters to atlas tiles: the level scene paints its TileMapLayers with them, the
## preview renderer draws the same picture on the CPU and the tests check the table. Nothing here touches
## collision (that is TileGrid) and nothing here is state.
##
## A level is given as `codes`: one byte per cell (the fixed legend character of TileGrid.get_char), row-major,
## `cols` wide. A look is one int: -1 = draw nothing, otherwise `set * LOOK_SET + atlas index`.

# --- Atlas layout ---------------------------------------------------------------------------------------------------
const ATLAS_COLUMNS: int = 8
const ATLAS_ROWS: int = 5
const ATLAS_TILES: int = 40
## Liquid strips are 8 x 1 tiles: surface frames 0..5, body 6, body with bubbles 7.
const LIQUID_COLUMNS: int = 8
const LIQUID_SURFACE: int = 0
const LIQUID_SURFACE_FRAMES: int = 6
const LIQUID_BODY: int = 6
const LIQUID_BODY_BUBBLES: int = 7
## 2.0: the tar floor ':' (PHYSICS.md C.5, LEVEL_DESIGN.md 15.3) is drawn from a 4 x 1 floor strip in the level's
## liquid skin (ASSET_MANIFEST 17.6 `tiles/canyon/mud_floor.png`: top_left, top, top_right, fill) that WorldTileSet
## appends to the liquid strip: its tiles are the indices TAR_FLOOR_FIRST.. of SET_LIQUID (drawn on the main layer).
const TAR_FLOOR_COLUMNS: int = 4
const TAR_FLOOR_FIRST: int = LIQUID_COLUMNS
const TAR_TOP_LEFT: int = TAR_FLOOR_FIRST
const TAR_TOP: int = TAR_FLOOR_FIRST + 1
const TAR_TOP_RIGHT: int = TAR_FLOOR_FIRST + 2
const TAR_FILL: int = TAR_FLOOR_FIRST + 3

# --- Terrain atlas indices -----------------------------------------------------------------------------------------
const TOP_LEFT: int = 0
const TOP: int = 1
const TOP_RIGHT: int = 2
const CAP_LEFT: int = 3
const CAP_RIGHT: int = 4
const SLOPE_UP_RIGHT: int = 5
const SLOPE_UP_LEFT: int = 6
const BLOCK: int = 7
const LEFT: int = 8
const FILL: int = 9
const RIGHT: int = 10
const GENTLE_UR_LOW: int = 11
const GENTLE_UR_HIGH: int = 12
const GENTLE_UL_HIGH: int = 13
const GENTLE_UL_LOW: int = 14
const FILL_INSET: int = 15
const BOTTOM_LEFT: int = 16
const BOTTOM: int = 17
const BOTTOM_RIGHT: int = 18
const UNDER_SLOPE_UP_RIGHT: int = 19
const UNDER_SLOPE_UP_LEFT: int = 20
const UNDER_GENTLE_UR_LOW: int = 21
const UNDER_GENTLE_UR_HIGH: int = 22
const FILL_B: int = 23
const UNDER_GENTLE_UL_HIGH: int = 24
const UNDER_GENTLE_UL_LOW: int = 25
const BOTTOM_B: int = 26
const ONEWAY_LEFT: int = 27
const ONEWAY_MID: int = 28
const ONEWAY_RIGHT: int = 29
const HANG_LEFT: int = 30
const HANG_MID: int = 31
const HANG_RIGHT: int = 32
const HANG_CAP: int = 33
const SMALL_BLOCK: int = 34
const BACK_FILL: int = 35
const BACK_DECO_A: int = 36
const BACK_DECO_B: int = 37
const SPIKES_FLOOR: int = 38
const SPIKES_CEILING: int = 39

# --- Looks ------------------------------------------------------------------------------------------------------------
## Tile sets a look can draw from; also the source ids of the TileSet built by WorldTileSet.
const SET_A: int = 0
const SET_B: int = 1
const SET_LIQUID: int = 2
## A look is `set * LOOK_SET + index`.
const LOOK_SET: int = 64
const LOOK_NONE: int = -1

# --- Character codes (the bytes of `codes`) ---------------------------------------------------------------------------
const C_AIR: int = 46            # .
const C_SOLID_A: int = 35        # #
const C_SOLID_B: int = 37        # %
const C_ONEWAY_A: int = 45       # -
const C_ONEWAY_B: int = 61       # =
const C_HATCH: int = 95          # _
const C_SLOPE_UR: int = 47       # /
const C_SLOPE_UL: int = 92       # \
const C_GENTLE_UR_LOW: int = 49  # 1
const C_GENTLE_UR_HIGH: int = 50 # 2
const C_GENTLE_UL_HIGH: int = 51 # 3
const C_GENTLE_UL_LOW: int = 52  # 4
const C_SPIKES_FLOOR: int = 94   # ^
const C_SPIKES_CEILING: int = 33 # !
const C_LIQUID: int = 126        # ~
const C_TAR: int = 58            # : (format 2: the tar floor)


## The fixed legend characters of a collision grid as bytes, row-major.
static func codes_from_grid(grid: TileGrid) -> PackedByteArray:
	var codes: PackedByteArray = PackedByteArray()
	codes.resize(grid.cols * grid.rows)
	for row: int in grid.rows:
		for col: int in grid.cols:
			codes[row * grid.cols + col] = grid.get_char(col, row).unicode_at(0)
	return codes


## The codes of tile rows written with the fixed legend (tests, tools).
static func codes_from_rows(tile_rows: PackedStringArray) -> PackedByteArray:
	return codes_from_grid(TileGrid.from_rows(tile_rows))


## `hash` of section 7.4: picks the variants (fill_b, bottom_b, bubbles, back-wall decor) per cell.
static func cell_hash(col: int, row: int) -> int:
	return ((col * 73856093) ^ (row * 19349663)) & 0x7FFFFFFF


## Compose a look.
static func look(set_id: int, index: int) -> int:
	return set_id * LOOK_SET + index


## Set of a look (SET_A, SET_B or SET_LIQUID).
static func look_set(look_value: int) -> int:
	return look_value / LOOK_SET


## Atlas index of a look.
static func look_index(look_value: int) -> int:
	return look_value % LOOK_SET


## Atlas cell (column, row) of an atlas index in an 8-column atlas.
static func atlas_coords(index: int) -> Vector2i:
	return Vector2i(index % ATLAS_COLUMNS, index / ATLAS_COLUMNS)


## True for looks drawn in front of the actors (liquids; not the tar floor, which is ground).
static func is_front(look_value: int) -> bool:
	return look_value >= 0 and look_set(look_value) == SET_LIQUID and look_index(look_value) < TAR_FLOOR_FIRST


## True for the looks of the tar floor ':' (2.0).
static func is_tar_floor(look_value: int) -> bool:
	return look_value >= 0 and look_set(look_value) == SET_LIQUID and look_index(look_value) >= TAR_FLOOR_FIRST


## Code at a cell; cells outside the map read as solid ground of set A (section 7.4: "cells outside the map count
## as solid-like").
static func code_at(codes: PackedByteArray, cols: int, col: int, row: int) -> int:
	if col < 0 or row < 0 or col >= cols:
		return C_SOLID_A
	var index: int = row * cols + col
	if index >= codes.size():
		return C_SOLID_A
	return codes[index]


## The look of one cell by the table of section 7.4.
static func cell_look(codes: PackedByteArray, cols: int, col: int, row: int) -> int:
	var code: int = code_at(codes, cols, col, row)
	match code:
		C_SOLID_A:
			return look(SET_A, _ground_index(codes, cols, col, row))
		C_SOLID_B:
			return look(SET_B, _ground_index(codes, cols, col, row))
		C_ONEWAY_A:
			return look(SET_A, _oneway_index(codes, cols, col, row))
		C_ONEWAY_B:
			return look(SET_B, _oneway_index(codes, cols, col, row))
		C_HATCH:
			return look(SET_A, ONEWAY_MID)
		C_SPIKES_FLOOR:
			return look(SET_A, SPIKES_FLOOR)
		C_SPIKES_CEILING:
			return look(SET_A, SPIKES_CEILING)
		C_LIQUID:
			if code_at(codes, cols, col, row - 1) != C_LIQUID:
				return look(SET_LIQUID, LIQUID_SURFACE)
			return look(SET_LIQUID, LIQUID_BODY_BUBBLES if cell_hash(col, row) % 4 == 0 else LIQUID_BODY)
		C_TAR:
			return look(SET_LIQUID, _tar_index(codes, cols, col, row))
	var slope: int = _slope_index(code)
	if slope >= 0:
		var below_set: int = SET_B if code_at(codes, cols, col, row + 1) == C_SOLID_B else SET_A
		return look(below_set, slope)
	return LOOK_NONE


## Back-wall tile of a cell inside a [backwall] rectangle: 35, or 36 / 37 for `deco` percent of the cells.
static func backwall_index(col: int, row: int, deco: int) -> int:
	var h: int = cell_hash(col, row)
	if deco > 0 and h % 100 < deco:
		return BACK_DECO_A if (h / 100) % 2 == 0 else BACK_DECO_B
	return BACK_FILL


## True when a back wall is drawn behind this code (every cell that is not solid ground).
static func shows_backwall(code: int) -> bool:
	return code != C_SOLID_A and code != C_SOLID_B


## True for '#' and '%' (and the tar floor ':', ground whose surface lies lower: 2.0).
static func is_solid_like(code: int) -> bool:
	return code == C_SOLID_A or code == C_SOLID_B or code == C_TAR


## True for the six slope characters.
static func is_slope(code: int) -> bool:
	return _slope_index(code) >= 0


static func _slope_index(code: int) -> int:
	match code:
		C_SLOPE_UR:
			return SLOPE_UP_RIGHT
		C_SLOPE_UL:
			return SLOPE_UP_LEFT
		C_GENTLE_UR_LOW:
			return GENTLE_UR_LOW
		C_GENTLE_UR_HIGH:
			return GENTLE_UR_HIGH
		C_GENTLE_UL_HIGH:
			return GENTLE_UL_HIGH
		C_GENTLE_UL_LOW:
			return GENTLE_UL_LOW
	return -1


static func _under_slope_index(slope_code: int) -> int:
	match slope_code:
		C_SLOPE_UR:
			return UNDER_SLOPE_UP_RIGHT
		C_SLOPE_UL:
			return UNDER_SLOPE_UP_LEFT
		C_GENTLE_UR_LOW:
			return UNDER_GENTLE_UR_LOW
		C_GENTLE_UR_HIGH:
			return UNDER_GENTLE_UR_HIGH
		C_GENTLE_UL_HIGH:
			return UNDER_GENTLE_UL_HIGH
		C_GENTLE_UL_LOW:
			return UNDER_GENTLE_UL_LOW
	return -1


## Left / right neighbour test: solid ground and slopes continue a surface.
static func _joins_side(code: int) -> bool:
	return is_solid_like(code) or is_slope(code)


static func _ground_index(codes: PackedByteArray, cols: int, col: int, row: int) -> int:
	var above: int = code_at(codes, cols, col, row - 1)
	var under: int = _under_slope_index(above)
	if under >= 0:
		return under
	var up: bool = is_solid_like(above)
	var down: bool = is_solid_like(code_at(codes, cols, col, row + 1))
	var left: bool = _joins_side(code_at(codes, cols, col - 1, row))
	var right: bool = _joins_side(code_at(codes, cols, col + 1, row))
	if not up:
		if right and not left:
			return TOP_LEFT
		if left and not right:
			return TOP_RIGHT
		return TOP
	if not down:
		if right and not left:
			return BOTTOM_LEFT
		if left and not right:
			return BOTTOM_RIGHT
		return BOTTOM_B if cell_hash(col, row) % 4 == 0 else BOTTOM
	if not left:
		return LEFT
	if not right:
		return RIGHT
	return FILL_B if cell_hash(col, row) % 8 == 0 else FILL


## The tar floor (2.0): the surface tiles where no ground or tar lies above (the ends of a surface run where the
## neighbour is no tar), the fill below the surface.
static func _tar_index(codes: PackedByteArray, cols: int, col: int, row: int) -> int:
	if is_solid_like(code_at(codes, cols, col, row - 1)):
		return TAR_FILL
	var left: bool = code_at(codes, cols, col - 1, row) == C_TAR
	var right: bool = code_at(codes, cols, col + 1, row) == C_TAR
	if right and not left:
		return TAR_TOP_LEFT
	if left and not right:
		return TAR_TOP_RIGHT
	return TAR_TOP


## A one-way platform ends where its neighbour is neither another thin floor (one-way or hatch) nor ground.
static func _oneway_joins(code: int) -> bool:
	return code == C_ONEWAY_A or code == C_ONEWAY_B or code == C_HATCH or _joins_side(code)


static func _oneway_index(codes: PackedByteArray, cols: int, col: int, row: int) -> int:
	if not _oneway_joins(code_at(codes, cols, col - 1, row)):
		return ONEWAY_LEFT
	if not _oneway_joins(code_at(codes, cols, col + 1, row)):
		return ONEWAY_RIGHT
	return ONEWAY_MID
