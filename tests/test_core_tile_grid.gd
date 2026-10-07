extends TestCase
## TileGrid: what every level-file tile character means for collision (PHYSICS.md 11.1, ARCHITECTURE.md 7.4).


func test_legend_characters() -> void:
	var grid: TileGrid = TileGrid.from_rows(PackedStringArray([
		".#%;-=_^!~|+",
		"############",
	]))
	assert_eq(grid.cols, 12)
	assert_eq(grid.rows, 2)
	# air
	assert_eq(grid.floor_at(0, 0), TileGrid.FLOOR_EMPTY)
	assert_eq(grid.side_at(0, 0), TileGrid.SIDE_OPEN)
	# solid A / B / invisible: floor + wall + ceiling
	for col: int in [1, 2, 3]:
		assert_eq(grid.floor_at(col, 0), TileGrid.FLOOR_SOLID, "solid col %d floor" % col)
		assert_eq(grid.side_at(col, 0), TileGrid.SIDE_WALL, "solid col %d side" % col)
		assert_eq(grid.ceiling_at(col, 0), TileGrid.CEILING_SOLID, "solid col %d ceiling" % col)
	# one-way platforms: floor only
	for col: int in [4, 5]:
		assert_eq(grid.floor_at(col, 0), TileGrid.FLOOR_SOLID)
		assert_eq(grid.side_at(col, 0), TileGrid.SIDE_OPEN)
		assert_eq(grid.ceiling_at(col, 0), TileGrid.CEILING_NONE)
	assert_eq(grid.floor_at(6, 0), TileGrid.FLOOR_HATCH)
	assert_eq(grid.floor_at(7, 0), TileGrid.FLOOR_DEADLY, "floor spikes")
	assert_eq(grid.ceiling_at(8, 0), TileGrid.CEILING_DEADLY, "ceiling spikes")
	assert_eq(grid.floor_at(8, 0), TileGrid.FLOOR_EMPTY)
	assert_eq(grid.floor_at(9, 0), TileGrid.FLOOR_DEADLY, "liquid floor")
	assert_eq(grid.side_at(9, 0), TileGrid.SIDE_DEADLY, "liquid body")
	assert_eq(grid.side_at(10, 0), TileGrid.SIDE_WALL, "invisible wall")
	assert_eq(grid.floor_at(10, 0), TileGrid.FLOOR_EMPTY)
	assert_eq(grid.floor_at(11, 0), TileGrid.FLOOR_DEADLY, "kill cell")
	assert_eq(grid.side_at(11, 0), TileGrid.SIDE_DEADLY)


func test_out_of_range_reads_as_air() -> void:
	var grid: TileGrid = TileGrid.from_rows(PackedStringArray(["##", "##"]))
	assert_eq(grid.floor_at(-1, 0), 0)
	assert_eq(grid.floor_at(0, -1), 0)
	assert_eq(grid.side_at(2, 0), 0)
	assert_eq(grid.flags_at(0, 2), 0)
	assert_eq(grid.get_char(5, 5), TileGrid.CH_AIR)
	assert_false(grid.in_bounds(2, 1))
	assert_eq(grid.width_px(), 32)
	assert_eq(grid.height_px(), 32)
	assert_eq(grid.x_max_excl(), 24)


func test_shortcut_and_letter_characters() -> void:
	var grid: TileGrid = TileGrid.from_rows(
		PackedStringArray(["@?*$Qz "]), 0, 0, {"Q": "-", "z": "#"}
	)
	assert_eq(grid.get_char(0, 0), TileGrid.CH_AIR, "@ is air")
	assert_eq(grid.get_char(1, 0), TileGrid.CH_SOLID_A, "? stands on solid ground")
	assert_eq(grid.get_char(2, 0), TileGrid.CH_SOLID_A, "* stands on solid ground")
	assert_eq(grid.get_char(3, 0), TileGrid.CH_SOLID_INVISIBLE, "$ is an invisible solid (the block draws itself)")
	assert_eq(grid.get_char(4, 0), TileGrid.CH_ONEWAY_A, "letter with tile=-")
	assert_eq(grid.get_char(5, 0), TileGrid.CH_SOLID_A, "letter with tile=#")
	assert_eq(grid.get_char(6, 0), TileGrid.CH_AIR, "a space is air")
	assert_eq(TileGrid.resolve_char("K"), TileGrid.CH_AIR, "letters without a tile= parameter are air")


func test_ice_levels_follow_the_terrain_set() -> void:
	var grid: TileGrid = TileGrid.from_rows(PackedStringArray([
		"/./.",
		"#-%=",
	]), 1, 2)
	assert_eq(grid.floor_at(0, 1), TileGrid.FLOOR_ICE_1, "set A solid")
	assert_eq(grid.floor_at(1, 1), TileGrid.FLOOR_ICE_1, "set A one-way")
	assert_eq(grid.floor_at(2, 1), TileGrid.FLOOR_ICE_2, "set B solid")
	assert_eq(grid.floor_at(3, 1), TileGrid.FLOOR_ICE_2, "set B one-way")
	assert_eq(grid.floor_at(0, 0), TileGrid.FLOOR_ICE_1, "slope above set A")
	assert_eq(grid.floor_at(2, 0), TileGrid.FLOOR_ICE_2, "slope above set B")
	assert_eq(TileGrid.floor_ice(TileGrid.FLOOR_ICE_2), 2)
	assert_eq(TileGrid.floor_ice(TileGrid.FLOOR_SOLID), 0)
	assert_eq(TileGrid.floor_ice(TileGrid.FLOOR_HATCH), 0)
	assert_true(TileGrid.is_ground(TileGrid.FLOOR_HATCH))
	assert_false(TileGrid.is_ground(TileGrid.FLOOR_DEADLY))


func test_slope_profiles() -> void:
	var grid: TileGrid = TileGrid.from_rows(PackedStringArray([
		"/\\1234",
		"######",
	]))
	for col: int in 6:
		assert_true(grid.has_profile(col, 0), "slope col %d has a profile" % col)
		assert_eq(grid.side_at(col, 0), TileGrid.SIDE_OPEN, "slopes are never walls")
		assert_eq(grid.ceiling_at(col, 0), TileGrid.CEILING_NONE)
		assert_eq(grid.floor_at(col, 0), TileGrid.FLOOR_SOLID)
	# '/' rises to the right: 15 px below the tile top at its left edge, 0 at its right edge.
	assert_eq(grid.surface_offset(0, 0, 0), 15)
	assert_eq(grid.surface_offset(0, 0, 15), 0)
	# '\' rises to the left.
	assert_eq(grid.surface_offset(1, 0, 16), 0)
	assert_eq(grid.surface_offset(1, 0, 31), 15)
	# gentle pair rising to the right: 15..8 then 7..0
	assert_eq(grid.surface_offset(2, 0, 32), 15)
	assert_eq(grid.surface_offset(2, 0, 47), 8)
	assert_eq(grid.surface_offset(3, 0, 48), 7)
	assert_eq(grid.surface_offset(3, 0, 63), 0)
	# gentle pair rising to the left: 0..7 then 8..15
	assert_eq(grid.surface_offset(4, 0, 64), 0)
	assert_eq(grid.surface_offset(4, 0, 79), 7)
	assert_eq(grid.surface_offset(5, 0, 80), 8)
	assert_eq(grid.surface_offset(5, 0, 95), 15)
	# every offset stays inside the tile (0..15), so the feet never change row on a slope
	for profile: int in range(TileGrid.PROFILE_UP_RIGHT_45, TileGrid.PROFILE_UP_LEFT_LOW + 1):
		for x: int in 16:
			var offset: int = TileGrid.profile_offset(profile, x)
			assert_true(offset >= 0 and offset <= 15, "profile %d x %d" % [profile, x])
	assert_eq(TileGrid.profile_offset(TileGrid.PROFILE_LOWERED_BASE + 3, 7), 3)
	assert_false(grid.has_profile(0, 1), "the fill under a slope is plain ground")


func test_slope_foot_gets_glue() -> void:
	# A hill: the flat ground cells diagonally below the low end of each slope must let the hero step down.
	var grid: TileGrid = TileGrid.from_rows(PackedStringArray([
		"..../\\....",
		".../##\\...",
		"##########",
	]))
	assert_eq(grid.profile_at(2, 2), TileGrid.PROFILE_FLAT_GLUE, "left foot of the hill")
	assert_eq(grid.profile_at(7, 2), TileGrid.PROFILE_FLAT_GLUE, "right foot of the hill")
	assert_eq(grid.profile_at(1, 2), TileGrid.PROFILE_NONE)
	assert_eq(grid.profile_at(8, 2), TileGrid.PROFILE_NONE)
	assert_eq(grid.profile_at(4, 1), TileGrid.PROFILE_NONE, "a covered cell is plain")
	assert_eq(grid.surface_offset(2, 2, 40), 0, "glue cells are flat")
	assert_true(grid.has_profile(2, 2))


func test_set_char_updates_collision_and_neighbours() -> void:
	var grid: TileGrid = TileGrid.from_rows(PackedStringArray([
		"...",
		".;.",
		"###",
	]))
	assert_eq(grid.side_at(1, 1), TileGrid.SIDE_WALL)
	grid.set_char(1, 1, TileGrid.CH_AIR)
	assert_eq(grid.get_char(1, 1), TileGrid.CH_AIR)
	assert_eq(grid.floor_at(1, 1), TileGrid.FLOOR_EMPTY, "a broken block no longer collides")
	assert_eq(grid.side_at(1, 1), TileGrid.SIDE_OPEN)
	grid.set_char(0, 1, TileGrid.CH_SLOPE_UP_LEFT)
	assert_eq(grid.profile_at(0, 1), TileGrid.PROFILE_UP_LEFT_45)
	assert_eq(grid.profile_at(1, 2), TileGrid.PROFILE_FLAT_GLUE, "glue appears when a slope is placed")
	grid.set_char(0, 1, TileGrid.CH_AIR)
	assert_eq(grid.profile_at(1, 2), TileGrid.PROFILE_NONE, "and disappears with it")
	grid.set_flag_bits(2, 2, TileGrid.FLAG_FOREGROUND, true)
	grid.set_char(2, 2, TileGrid.CH_SOLID_B)
	assert_true((grid.flags_at(2, 2) & TileGrid.FLAG_FOREGROUND) != 0, "cosmetic flags survive a rewrite")
	assert_eq(grid.ceiling_at(2, 2), TileGrid.CEILING_SOLID)


## Level format 2: the tar floor ':' is '#' (floor with set A's ice, wall, solid ceiling) with a surface 6 px lower
## and the TAR material (PHYSICS.md C.5, LEVEL_DESIGN.md 15.3).
func test_tar_floor() -> void:
	assert_true(TileGrid.LEGEND_CHARS.contains(TileGrid.CH_TAR), "':' is a fixed legend character")
	assert_eq(TileGrid.resolve_char(":"), TileGrid.CH_TAR)
	assert_eq(TileGrid.PROFILE_TAR, TileGrid.PROFILE_LOWERED_BASE + Tuning.TAR_SURFACE_DROP_PX)
	var grid: TileGrid = TileGrid.from_rows(PackedStringArray([
		".T.....",
		"#::#%:T",
	]), 1, 2, {"T": ":"})
	for col: int in [1, 2, 5, 6]:
		assert_eq(grid.get_char(col, 1), TileGrid.CH_TAR, "tar col %d" % col)
		assert_eq(grid.floor_at(col, 1), TileGrid.FLOOR_ICE_1, "tar is set-A ground (ice_a) col %d" % col)
		assert_eq(grid.side_at(col, 1), TileGrid.SIDE_WALL)
		assert_eq(grid.ceiling_at(col, 1), TileGrid.CEILING_SOLID)
		assert_eq(grid.profile_at(col, 1), TileGrid.PROFILE_TAR)
		assert_true(grid.has_profile(col, 1), "a lowered surface counts as HEIGHT != 0")
		assert_eq(grid.surface_offset(col, 1, col * 16 + 5), Tuning.TAR_SURFACE_DROP_PX, "the surface lies 6 px lower")
		assert_true(grid.is_tar(col, 1))
		assert_eq(grid.material_at(col, 1), TileGrid.MATERIAL_TAR)
	assert_eq(grid.get_char(1, 0), TileGrid.CH_TAR, "a legend letter with tile=:")
	for col: int in [0, 3, 4]:
		assert_false(grid.is_tar(col, 1), "'#' and '%' are no tar")
		assert_eq(grid.profile_at(col, 1), TileGrid.PROFILE_NONE, "no glue, no lowering next to tar")
	assert_eq(grid.floor_at(4, 1), TileGrid.FLOOR_ICE_2)
	assert_false(grid.is_tar(0, 0), "air")
	assert_false(grid.is_tar(-1, 1), "outside the grid")
	assert_eq(grid.material_at(99, 99), TileGrid.MATERIAL_NONE)
	# set_char keeps the material table in step: a tar cell that is rewritten is no tar any more and back.
	grid.set_char(2, 1, TileGrid.CH_SOLID_A)
	assert_false(grid.is_tar(2, 1))
	assert_eq(grid.profile_at(2, 1), TileGrid.PROFILE_NONE)
	grid.set_char(3, 1, TileGrid.CH_TAR)
	assert_true(grid.is_tar(3, 1))
	assert_eq(grid.surface_offset(3, 1, 50), Tuning.TAR_SURFACE_DROP_PX)
	# A fresh grid and a resize hold no material.
	grid.resize(3, 2)
	assert_false(grid.is_tar(1, 1))


## The done-criterion of PLAN.md P0.7: the 15 Book I level files build, through the format-2 TileGrid and LevelData,
## exactly the collision grids the 1.0 code built (tests/fixtures/book1_grid_hashes.txt, frozen before format 2), in
## both difficulties, and none of their cells is tar.
func test_book1_files_build_the_same_grids() -> void:
	var text: String = FileAccess.get_file_as_string("res://tests/fixtures/book1_grid_hashes.txt")
	var checked: int = 0
	for line: String in text.split("\n", false):
		var entry: String = line.strip_edges()
		if entry.is_empty() or entry.begins_with("#"):
			continue
		var parts: PackedStringArray = entry.split(" ", false)
		assert_eq(parts.size(), 4, "fixture line '%s'" % entry)
		if parts.size() != 4:
			continue
		var data: LevelData = LevelData.load_file("res://levels/%s.lvl" % parts[0])
		assert_not_null(data, parts[0])
		if data == null:
			continue
		var grid: TileGrid = data.build_grid(parts[1].to_int())
		assert_eq("%dx%d" % [grid.cols, grid.rows], parts[2], "%s size" % parts[0])
		assert_eq(_grid_hash(grid), parts[3], "%s (%s) builds the 1.0 grid" % [parts[0], parts[1]])
		var tar: int = 0
		for row: int in grid.rows:
			for col: int in grid.cols:
				if grid.material_at(col, row) != TileGrid.MATERIAL_NONE:
					tar += 1
		assert_eq(tar, 0, "%s has no format-2 material" % parts[0])
		checked += 1
	assert_eq(checked, 30, "15 Book I files x 2 difficulties")


## sha256 over every cell in reading order, 5 bytes per cell (floor, side, flags, profile, char), as the fixture.
static func _grid_hash(grid: TileGrid) -> String:
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(grid.cols * grid.rows * 5)
	var i: int = 0
	for row: int in grid.rows:
		for col: int in grid.cols:
			bytes[i] = grid.floor_at(col, row)
			bytes[i + 1] = grid.side_at(col, row)
			bytes[i + 2] = grid.flags_at(col, row)
			bytes[i + 3] = grid.profile_at(col, row)
			bytes[i + 4] = grid.get_char(col, row).unicode_at(0)
			i += 5
	var context: HashingContext = HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode()


func test_rows_of_different_length_are_padded() -> void:
	var grid: TileGrid = TileGrid.from_rows(PackedStringArray(["#", "###", "##"]))
	assert_eq(grid.cols, 3)
	assert_eq(grid.floor_at(2, 0), TileGrid.FLOOR_EMPTY)
	assert_eq(grid.floor_at(2, 1), TileGrid.FLOOR_SOLID)
	assert_eq(grid.floor_at(2, 2), TileGrid.FLOOR_EMPTY)
