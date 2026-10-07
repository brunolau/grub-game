extends TestCase
## The auto-tiling table of ARCHITECTURE.md 7.4 (LevelTiles) and the TileSet built from the 40-index atlases.

const A: int = LevelTiles.SET_A
const B: int = LevelTiles.SET_B
const L: int = LevelTiles.SET_LIQUID


func _look_at(rows: PackedStringArray, col: int, row: int) -> int:
	var grid: TileGrid = TileGrid.from_rows(rows)
	return LevelTiles.cell_look(LevelTiles.codes_from_grid(grid), grid.cols, col, row)


func _look(set_id: int, index: int) -> int:
	return LevelTiles.look(set_id, index)


func test_hash_is_the_documented_formula() -> void:
	assert_eq(LevelTiles.cell_hash(0, 0), 0)
	assert_eq(LevelTiles.cell_hash(1, 2), 103314787, "((1 * 73856093) ^ (2 * 19349663)) & 0x7FFFFFFF")
	assert_eq(LevelTiles.cell_hash(3, 5), 149986828)


func test_ground_surface_and_underside() -> void:
	var rows: PackedStringArray = PackedStringArray([
		"..............",
		"..####........",
		"..####........",
		"..............",
		"..............",
		".......#......",
		"..............",
	])
	assert_eq(_look_at(rows, 2, 1), _look(A, LevelTiles.TOP_LEFT), "only the right neighbour is solid")
	assert_eq(_look_at(rows, 3, 1), _look(A, LevelTiles.TOP))
	assert_eq(_look_at(rows, 5, 1), _look(A, LevelTiles.TOP_RIGHT), "only the left neighbour is solid")
	assert_eq(_look_at(rows, 2, 2), _look(A, LevelTiles.BOTTOM_LEFT))
	assert_eq(_look_at(rows, 5, 2), _look(A, LevelTiles.BOTTOM_RIGHT))
	assert_eq(_look_at(rows, 7, 5), _look(A, LevelTiles.TOP), "no solid neighbour on either side: plain top")
	# bottom (17), or bottom_b (26) when hash % 4 == 0
	for col: int in [3, 4]:
		var expected: int = LevelTiles.BOTTOM_B if LevelTiles.cell_hash(col, 2) % 4 == 0 else LevelTiles.BOTTOM
		assert_eq(_look_at(rows, col, 2), _look(A, expected))
	assert_eq(_look_at(rows, 0, 0), LevelTiles.LOOK_NONE, "air draws nothing")


func test_walls_and_fill_variants() -> void:
	var rows: PackedStringArray = PackedStringArray([
		"..............",
		"..##########..",
		"..##########..",
		"..##########..",
		"..##########..",
		"..##########..",
		"..............",
	])
	assert_eq(_look_at(rows, 2, 3), _look(A, LevelTiles.LEFT))
	assert_eq(_look_at(rows, 11, 3), _look(A, LevelTiles.RIGHT))
	var variants: int = 0
	for row: int in range(2, 5):
		for col: int in range(3, 11):
			var expected: int = LevelTiles.FILL
			if LevelTiles.cell_hash(col, row) % 8 == 0:
				expected = LevelTiles.FILL_B
				variants += 1
			assert_eq(_look_at(rows, col, row), _look(A, expected), "fill at %d,%d" % [col, row])
	assert_true(variants > 0, "the block contains at least one fill_b cell (hash % 8 == 0)")


func test_outside_the_map_counts_as_solid() -> void:
	var rows: PackedStringArray = PackedStringArray([
		"####......",
		"##........",
		"..........",
		"..........",
		"##########",
	])
	assert_eq(_look_at(rows, 0, 4), _look(A, LevelTiles.TOP), "left edge continues into the outside")
	assert_eq(_look_at(rows, 9, 4), _look(A, LevelTiles.TOP), "right edge too")
	assert_eq(_look_at(rows, 0, 0), _look(A, LevelTiles.FILL_B), "solid all around (outside too); hash 0 -> fill_b")
	assert_eq(_look_at(rows, 3, 0), _look(A, LevelTiles.BOTTOM_RIGHT), "solid above (outside), open below")
	assert_eq(_look_at(rows, 1, 1), _look(A, LevelTiles.BOTTOM_RIGHT))


func test_slopes_and_the_ground_under_them() -> void:
	var rows: PackedStringArray = PackedStringArray([
		"................",
		"./##\\...12##34..",
		"################",
	])
	assert_eq(_look_at(rows, 1, 1), _look(A, LevelTiles.SLOPE_UP_RIGHT))
	assert_eq(_look_at(rows, 4, 1), _look(A, LevelTiles.SLOPE_UP_LEFT))
	assert_eq(_look_at(rows, 2, 1), _look(A, LevelTiles.TOP), "slopes count as solid for the left / right test")
	assert_eq(_look_at(rows, 3, 1), _look(A, LevelTiles.TOP))
	assert_eq(_look_at(rows, 8, 1), _look(A, LevelTiles.GENTLE_UR_LOW))
	assert_eq(_look_at(rows, 9, 1), _look(A, LevelTiles.GENTLE_UR_HIGH))
	assert_eq(_look_at(rows, 12, 1), _look(A, LevelTiles.GENTLE_UL_HIGH))
	assert_eq(_look_at(rows, 13, 1), _look(A, LevelTiles.GENTLE_UL_LOW))
	assert_eq(_look_at(rows, 1, 2), _look(A, LevelTiles.UNDER_SLOPE_UP_RIGHT))
	assert_eq(_look_at(rows, 4, 2), _look(A, LevelTiles.UNDER_SLOPE_UP_LEFT))
	assert_eq(_look_at(rows, 8, 2), _look(A, LevelTiles.UNDER_GENTLE_UR_LOW))
	assert_eq(_look_at(rows, 9, 2), _look(A, LevelTiles.UNDER_GENTLE_UR_HIGH))
	assert_eq(_look_at(rows, 12, 2), _look(A, LevelTiles.UNDER_GENTLE_UL_HIGH))
	assert_eq(_look_at(rows, 13, 2), _look(A, LevelTiles.UNDER_GENTLE_UL_LOW))
	assert_eq(_look_at(rows, 0, 2), _look(A, LevelTiles.TOP), "ground next to a slope foot keeps its surface")


func test_set_b_ground_and_slopes() -> void:
	var rows: PackedStringArray = PackedStringArray([
		"........",
		"..%/....",
		"%%%%%###",
	])
	assert_eq(_look_at(rows, 2, 1), _look(B, LevelTiles.TOP_LEFT), "% draws from terrain set B")
	assert_eq(_look_at(rows, 3, 1), _look(B, LevelTiles.SLOPE_UP_RIGHT), "a slope takes the set of the cell below")
	assert_eq(_look_at(rows, 3, 2), _look(B, LevelTiles.UNDER_SLOPE_UP_RIGHT))
	assert_eq(_look_at(rows, 6, 2), _look(A, LevelTiles.TOP), "the two sets join without an edge")


func test_one_way_floors_and_hatches() -> void:
	var rows: PackedStringArray = PackedStringArray([
		"..............",
		"..---..===....",
		"..-..#--_-....",
		"..............",
	])
	assert_eq(_look_at(rows, 2, 1), _look(A, LevelTiles.ONEWAY_LEFT))
	assert_eq(_look_at(rows, 3, 1), _look(A, LevelTiles.ONEWAY_MID))
	assert_eq(_look_at(rows, 4, 1), _look(A, LevelTiles.ONEWAY_RIGHT))
	assert_eq(_look_at(rows, 7, 1), _look(B, LevelTiles.ONEWAY_LEFT), "= draws from set B")
	assert_eq(_look_at(rows, 9, 1), _look(B, LevelTiles.ONEWAY_RIGHT))
	assert_eq(_look_at(rows, 2, 2), _look(A, LevelTiles.ONEWAY_LEFT), "a single piece is a left end")
	assert_eq(_look_at(rows, 6, 2), _look(A, LevelTiles.ONEWAY_MID), "ground continues the platform")
	assert_eq(_look_at(rows, 7, 2), _look(A, LevelTiles.ONEWAY_MID), "a hatch continues the platform")
	assert_eq(_look_at(rows, 8, 2), _look(A, LevelTiles.ONEWAY_MID), "hatch = 28 of set A")
	assert_eq(_look_at(rows, 9, 2), _look(A, LevelTiles.ONEWAY_RIGHT))


func test_hazards_liquids_and_invisible_cells() -> void:
	var rows: PackedStringArray = PackedStringArray([
		"..!!..........",
		"..............",
		"#^^#~~~#;|+@..",
		"####~~~#......",
		"####~~~#......",
	])
	assert_eq(_look_at(rows, 2, 0), _look(A, LevelTiles.SPIKES_CEILING))
	assert_eq(_look_at(rows, 1, 2), _look(A, LevelTiles.SPIKES_FLOOR))
	assert_eq(_look_at(rows, 4, 2), _look(L, LevelTiles.LIQUID_SURFACE), "liquid under air: animated surface")
	for row: int in [3, 4]:
		for col: int in range(4, 7):
			var bubbles: bool = LevelTiles.cell_hash(col, row) % 4 == 0
			var expected: int = LevelTiles.LIQUID_BODY_BUBBLES if bubbles else LevelTiles.LIQUID_BODY
			assert_eq(_look_at(rows, col, row), _look(L, expected), "liquid body at %d,%d" % [col, row])
	assert_true(LevelTiles.is_front(_look_at(rows, 4, 2)), "liquids are drawn in front of the actors")
	for col: int in [8, 9, 10, 11]:
		assert_eq(_look_at(rows, col, 2), LevelTiles.LOOK_NONE, "; | + @ draw nothing")
	assert_eq(_look_at(rows, 3, 2), _look(A, LevelTiles.TOP), "ground beside spikes keeps its surface")
	assert_eq(_look_at(rows, 7, 2), _look(A, LevelTiles.TOP), "liquid and ';' are not solid-like for the neighbours")


func test_back_wall_decor_percentage() -> void:
	for col: int in 30:
		assert_eq(LevelTiles.backwall_index(col, 3, 0), LevelTiles.BACK_FILL, "deco 0: plain wall")
		var full: int = LevelTiles.backwall_index(col, 3, 100)
		assert_true(full == LevelTiles.BACK_DECO_A or full == LevelTiles.BACK_DECO_B, "deco 100: every cell decorated")
	assert_true(LevelTiles.shows_backwall(LevelTiles.C_AIR))
	assert_true(LevelTiles.shows_backwall(LevelTiles.C_SLOPE_UR))
	assert_false(LevelTiles.shows_backwall(LevelTiles.C_SOLID_A))
	assert_false(LevelTiles.shows_backwall(LevelTiles.C_SOLID_B))


func test_tile_set_has_every_atlas_tile_and_the_liquid_animation() -> void:
	var tile_set: TileSet = WorldTileSet.build("cave/terrain", "cave/terrain_stone", "lava")
	assert_eq(tile_set.tile_size, Vector2i(Tuning.TILE_ART, Tuning.TILE_ART))
	for set_id: int in [A, B]:
		var source: TileSetAtlasSource = tile_set.get_source(set_id) as TileSetAtlasSource
		assert_not_null(source)
		assert_eq(source.get_tiles_count(), LevelTiles.ATLAS_TILES)
		assert_true(source.has_tile(LevelTiles.atlas_coords(LevelTiles.SPIKES_CEILING)))
	var liquid: TileSetAtlasSource = tile_set.get_source(L) as TileSetAtlasSource
	assert_eq(liquid.get_tile_animation_frames_count(Vector2i.ZERO), LevelTiles.LIQUID_SURFACE_FRAMES)
	assert_almost_eq(liquid.get_tile_animation_frame_duration(Vector2i.ZERO, 0),
			Tuning.ticks_to_seconds(Tuning.TILE_ANIM_TICKS), 0.0001, "4 ticks per frame")
	assert_true(liquid.has_tile(Vector2i(LevelTiles.LIQUID_BODY_BUBBLES, 0)))
	# One shared texture (one batch per rendering quadrant): A on top, B below it, the liquid strip at the bottom with
	# the 4-cell tar-floor strip of ':' to its right (2.0: 12 cells of 32 px, wider than a 256 px terrain atlas).
	var lava: Texture2D = load(LevelData.liquid_path("lava")) as Texture2D
	var stone: Texture2D = load(LevelData.terrain_path("cave/terrain_stone")) as Texture2D
	var shared: Texture2D = (tile_set.get_source(A) as TileSetAtlasSource).texture
	assert_true(shared == (tile_set.get_source(B) as TileSetAtlasSource).texture and shared == liquid.texture,
			"the three sources share one texture")
	assert_eq((tile_set.get_source(A) as TileSetAtlasSource).margins, Vector2i.ZERO)
	assert_eq((tile_set.get_source(B) as TileSetAtlasSource).margins, Vector2i(0, stone.get_height()))
	assert_eq(liquid.margins, Vector2i(0, stone.get_height() * 2))
	var liquid_width: int = (LevelTiles.LIQUID_COLUMNS + LevelTiles.TAR_FLOOR_COLUMNS) * Tuning.TILE_ART
	assert_eq(shared.get_size(), Vector2(maxi(stone.get_width(), liquid_width), stone.get_height() * 2
			+ lava.get_height()))
	assert_true(liquid.has_tile(Vector2i(LevelTiles.TAR_FILL, 0)), "the tar-floor tiles")
	var atlas: Image = shared.get_image()
	var strip: Image = lava.get_image()
	for x: int in [0, 37, strip.get_width() - 1]:
		assert_eq(atlas.get_pixel(x, liquid.margins.y + 5), strip.get_pixel(x, 5), "liquid pixel %d" % x)
	var fallback: TileSet = WorldTileSet.build("nowhere/none", "nowhere/none", "tar")
	assert_not_null((fallback.get_source(A) as TileSetAtlasSource).texture, "unknown atlases fall back to jungle")
	assert_false(WorldTileSet.has_terrain("nowhere/none"))
	assert_true(WorldTileSet.has_terrain("volcano/terrain_obsidian"))
