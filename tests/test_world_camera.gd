extends TestCase
## The camera of PHYSICS.md 12 (LevelCamera): page timing against `camera.walk_right` / `walk_left` of
## PHYSICS_REFERENCE.json, variable view sizes, both vertical curves, centring, locks, spawn placement,
## look-around, auto-scroll and the smooth comfort follow.

const BASE_VIEW: Vector2i = Vector2i(640, 360)
## The reference run starts at x 1000 on a floor at y 320 (reference_sim.py START_X / GROUND_ROW).
const START_X: int = 1000
const FLOOR_Y: int = 320

var _hero: PlayerBase = null


func before_each() -> void:
	_hero = PlayerBase.new()
	_hero.teleport(Vector2i(START_X, FLOOR_Y))


func after_each() -> void:
	_hero.free()


func _camera(cols: int = 256, rows: int = 40, view_art: Vector2i = BASE_VIEW) -> LevelCamera:
	var camera: LevelCamera = LevelCamera.new()
	camera.set_bounds(Rect2i(0, 0, cols * Tuning.TILE, rows * Tuning.TILE))
	camera.set_view_art(view_art)
	return camera


## Run the reference page: the hero runs at full speed from screen column 10 and the camera follows.
func _page_run(camera: LevelCamera, direction: int, ticks: int) -> Array[PackedInt32Array]:
	var cols: PackedInt32Array = PackedInt32Array()
	var screen_cols: PackedInt32Array = PackedInt32Array()
	_hero.xvel = Tuning.WALK_CAP * direction
	_hero.facing = direction
	for tick: int in range(1, ticks + 1):
		_hero.sim_pos.x += Tuning.floor16(_hero.xvel)
		camera.tick(_hero)
		cols.append(camera.get_cell().x)
		screen_cols.append(Tuning.to_cell(_hero.sim_pos.x) - camera.get_cell().x)
	return [cols, screen_cols]


func test_view_size_gives_columns_and_rows() -> void:
	var camera: LevelCamera = _camera()
	assert_eq(camera.view, Vector2i(Tuning.VIEW_W, Tuning.VIEW_H))
	assert_eq(camera.cols, Tuning.VIEW_COLS, "640 art px = 20 columns")
	assert_eq(camera.rows, Tuning.VIEW_ROWS, "360 art px = 11 rows (floor of 11.25)")
	assert_true(camera.set_view_art(Vector2i(800, 360)), "a phone in landscape")
	assert_eq(camera.cols, 25)
	assert_eq(camera.rows, 11)
	camera.set_view_art(Vector2i(682, 512))
	assert_eq(camera.cols, 22, "ceil(341 / 16)")
	assert_eq(camera.rows, 16, "floor(256 / 16)")
	assert_false(camera.set_view_art(Vector2i(682, 512)), "no change")


func test_page_timing_walking_right_matches_the_reference() -> void:
	var reference: Dictionary = load_reference()["camera"]["walk_right"]
	var expected_cols: Array = reference["camera_col_per_tick"]
	var camera: LevelCamera = _camera()
	camera.pos = Vector2i(int(reference["start_camera_col"]) * Tuning.TILE, FLOOR_Y - 7 * Tuning.TILE)
	var run: Array[PackedInt32Array] = _page_run(camera, 1, expected_cols.size())
	assert_ints_eq(run[0], expected_cols, "camera column per tick")
	assert_ints_eq(run[1], reference["hero_screen_col_per_tick"], "hero screen column per tick")
	assert_eq(camera.h_dir, LevelCamera.DIR_IDLE, "the page ended")


func test_page_timing_walking_left_matches_the_reference() -> void:
	var reference: Dictionary = load_reference()["camera"]["walk_left"]
	var expected_cols: Array = reference["camera_col_per_tick"]
	var camera: LevelCamera = _camera()
	camera.pos = Vector2i(int(reference["start_camera_col"]) * Tuning.TILE, FLOOR_Y - 7 * Tuning.TILE)
	var run: Array[PackedInt32Array] = _page_run(camera, -1, expected_cols.size())
	assert_ints_eq(run[0], expected_cols, "camera column per tick")
	assert_ints_eq(run[1], reference["hero_screen_col_per_tick"], "hero screen column per tick")


func test_page_thresholds_follow_a_wider_view() -> void:
	var camera: LevelCamera = _camera(256, 40, Vector2i(800, 360))
	camera.pos = Vector2i(52 * Tuning.TILE, FLOOR_Y - 7 * Tuning.TILE)
	var run: Array[PackedInt32Array] = _page_run(camera, 1, 80)
	var first_move: int = -1
	for i: int in run[0].size():
		if run[0][i] != 52:
			first_move = i
			break
	assert_true(first_move > 0)
	assert_eq(run[1][first_move - 1], 21, "with 25 columns the page starts at screen column 25 - 4 = 21")
	var stop: int = run[0].size() - 1
	while run[0][stop] == run[0][stop - 1]:
		stop -= 1
	assert_eq(run[1][stop], Tuning.CAM_RIGHT_STOP, "and stops at column 5")


func test_standing_still_never_moves_the_view() -> void:
	var camera: LevelCamera = _camera()
	camera.pos = Vector2i(52 * Tuning.TILE, FLOOR_Y - 7 * Tuning.TILE)
	_hero.sim_pos.x = 52 * Tuning.TILE + 18 * Tuning.TILE
	for i: int in 30:
		camera.tick(_hero)
	assert_eq(camera.pos.x, 52 * Tuning.TILE, "xvel == 0 inside the view: idle even at column 18")


func test_vertical_curves_by_distance() -> void:
	var reference: Dictionary = load_reference()["camera"]
	var camera: LevelCamera = _camera()
	camera.fast = false
	var slow: PackedInt32Array = PackedInt32Array()
	for distance: int in 132:
		slow.append(camera.vertical_step(distance))
	assert_ints_eq(slow, reference["vertical_speed_px_per_tick_by_distance"], "first curve (opaque screens)")
	camera.fast = true
	var fast: PackedInt32Array = PackedInt32Array()
	for distance: int in 132:
		fast.append(camera.vertical_step(distance))
	assert_ints_eq(fast, reference["vertical_speed_px_per_tick_by_distance_backdrop_visible"], "second curve")
	assert_eq(camera.vertical_step(132), 0, "no step outside 0..131")
	assert_eq(camera.vertical_step(-1), 0)


func test_falling_hero_scrolls_down_with_the_curve() -> void:
	var camera: LevelCamera = _camera()
	camera.fast = true
	camera.pos = Vector2i(0, 160)
	_hero.sim_pos = Vector2i(100, 160 + 10 * Tuning.TILE + 4)
	_hero.yvel = 96
	camera.tick(_hero)
	var distance: int = _hero.sim_pos.y - 160 - Tuning.CAM_V_AIR_LOW_TARGET * Tuning.TILE
	assert_eq(camera.v_target, Tuning.CAM_V_AIR_LOW_TARGET, "airborne in row >= 9: target row 3")
	assert_eq(camera.pos.y, 160 + Tuning.cam_v_speed(distance, true))
	camera.fast = false
	var before: int = camera.pos.y
	camera.tick(_hero)
	distance = _hero.sim_pos.y - before - Tuning.CAM_V_AIR_LOW_TARGET * Tuning.TILE
	assert_eq(camera.pos.y, before + Tuning.cam_v_speed(distance, false))


func test_grounded_band_rows_4_to_9_does_not_scroll() -> void:
	var camera: LevelCamera = _camera()
	camera.pos = Vector2i(0, 160)
	for row: int in range(4, 10):
		_hero.sim_pos = Vector2i(100, 160 + row * Tuning.TILE)
		camera.tick(_hero)
		assert_eq(camera.pos.y, 160, "standing in screen row %d" % row)
	_hero.sim_pos = Vector2i(100, 160 + 10 * Tuning.TILE)
	camera.tick(_hero)
	assert_true(camera.pos.y > 160, "row 10: the view moves down towards row 9")
	camera.pos.y = 160
	camera.v_active = 0
	camera.scroll_flags = Defs.SCROLL_LOW_BAND
	_hero.sim_pos = Vector2i(100, 160 + 8 * Tuning.TILE)
	camera.tick(_hero)
	assert_eq(camera.v_target, Tuning.CAM_V_ALT_LOW_TARGET, "low band: row 8 already scrolls, towards row 7")


func test_small_level_is_centred_and_never_scrolls() -> void:
	var camera: LevelCamera = _camera(15, 8)
	_hero.teleport(Vector2i(40, 100))
	camera.snap(_hero)
	assert_eq(camera.pos, Vector2i(-40, -16),
			"centred on a 240 x 128 px level in a 320 x 180 px view; the 26 px above it rounded down to a tile")
	_hero.xvel = 80
	_hero.yvel = 64
	for i: int in 20:
		_hero.sim_pos += Vector2i(5, 3)
		camera.tick(_hero)
	assert_eq(camera.pos, Vector2i(-40, -16))
	var narrow: LevelCamera = _camera(15, 40)
	narrow.snap(_hero)
	assert_eq(narrow.pos.x, -40, "centred horizontally only")
	assert_true(narrow.get_max().y > narrow.get_min().y, "vertical follow stays")


func test_level_bounds_limit_the_view() -> void:
	var camera: LevelCamera = _camera(40, 20)
	_hero.teleport(Vector2i(39 * Tuning.TILE, 19 * Tuning.TILE))
	camera.snap(_hero)
	assert_eq(camera.pos, Vector2i(40 * Tuning.TILE - Tuning.VIEW_W, 20 * Tuning.TILE - Tuning.VIEW_H))
	_hero.teleport(Vector2i(8, 16))
	camera.snap(_hero)
	assert_eq(camera.pos, Vector2i.ZERO)


func test_spawn_placement_rules() -> void:
	var camera: LevelCamera = _camera(100, 60)
	_hero.teleport(Vector2i(30 * Tuning.TILE + 8, 30 * Tuning.TILE))
	camera.snap(_hero)
	assert_eq(camera.get_cell().x, 21,
			"a standing hero pages only while beyond the view (to column 19), then the 10-column shift")
	assert_eq(Tuning.to_cell(_hero.sim_pos.y) - camera.get_cell().y, Tuning.CAM_V_GROUND_LOW_TARGET,
			"vertical: settled with the feet in row 9")
	assert_eq(camera.prev, camera.pos, "nothing to interpolate after a snap")
	_hero.teleport(Vector2i(15 * Tuning.TILE + 8, 30 * Tuning.TILE))
	camera.snap(_hero)
	assert_eq(camera.get_cell().x, 10, "screen column >= 12 after settling: shifted right by 10 columns")
	_hero.teleport(Vector2i(8 * Tuning.TILE + 8, 30 * Tuning.TILE))
	camera.snap(_hero)
	assert_eq(camera.get_cell().x, 0, "near the left edge: no shift")


func test_locks_fix_or_restrict_the_view() -> void:
	var camera: LevelCamera = _camera(100, 40)
	_hero.teleport(Vector2i(5 * Tuning.TILE, 10 * Tuning.TILE))
	camera.snap(_hero)
	camera.lock(Rect2i(30 * Tuning.TILE, 0, Tuning.VIEW_W, Tuning.VIEW_H))
	camera.tick(_hero)
	assert_eq(camera.pos.x, Tuning.CAM_STEP_PX, "a camera outside the lock glides in one tile per tick")
	for i: int in 40:
		camera.tick(_hero)
	assert_eq(camera.pos, Vector2i(30 * Tuning.TILE, 0))
	_hero.xvel = 80
	for i: int in 40:
		_hero.sim_pos.x += 5
		camera.tick(_hero)
	assert_eq(camera.pos, Vector2i(30 * Tuning.TILE, 0), "a screen lock ignores the hero")
	camera.lock(Rect2i(40 * Tuning.TILE, 10 * Tuning.TILE, 10 * Tuning.TILE, 5 * Tuning.TILE))
	camera.snap(_hero)
	assert_eq(camera.pos, Vector2i(40 * Tuning.TILE - 80, 10 * Tuning.TILE - 48),
			"a lock smaller than the view is centred (rows: whole tiles)")
	camera.lock(Rect2i(0, 0, 10 * Tuning.TILE, 5 * Tuning.TILE))
	camera.snap(_hero)
	assert_eq(camera.pos, Vector2i.ZERO, "but never shows what lies outside the level")
	camera.lock(Rect2i(0, 16, 20 * Tuning.TILE, 11 * Tuning.TILE))
	camera.snap(_hero)
	assert_eq(camera.pos.y, 16, "an 11-row room in the 11.25-row view: the camera row is the room's top row")
	camera.unlock()
	camera.snap(_hero)
	assert_true(camera.pos.x >= 0 and camera.pos.y >= 0, "unlocked: the level bounds apply again")


func test_look_around_pans_in_the_facing_direction() -> void:
	var camera: LevelCamera = _camera(100, 40)
	_hero.teleport(Vector2i(50 * Tuning.TILE + 8, 20 * Tuning.TILE))
	camera.snap(_hero)
	var start: int = camera.get_cell().x
	assert_eq(start, 41, "spawn placement: screen column 9")
	_hero.looking = true
	_hero.facing = 1
	for i: int in 30:
		camera.tick(_hero)
	assert_eq(Tuning.to_cell(_hero.sim_pos.x) - camera.get_cell().x, Tuning.CAM_LOOK_MIN_SC,
			"pans right while the hero's screen column is > 2")
	_hero.looking = false
	camera.tick(_hero)
	assert_eq(Tuning.to_cell(_hero.sim_pos.x) - camera.get_cell().x, Tuning.CAM_LOOK_MIN_SC, "the view stays")
	_hero.looking = true
	_hero.facing = -1
	for i: int in 40:
		camera.tick(_hero)
	assert_eq(Tuning.to_cell(_hero.sim_pos.x) - camera.get_cell().x, Tuning.CAM_LOOK_MAX_SC,
			"pans left while the hero's screen column is < 17")
	assert_true(camera.get_cell().x < start)


func test_autoscroll_moves_down_one_pixel_per_tick() -> void:
	var camera: LevelCamera = _camera(20, 100)
	camera.scroll_flags = Defs.SCROLL_AUTO_DOWN | Defs.SCROLL_NO_HORIZONTAL
	_hero.teleport(Vector2i(100, 5 * Tuning.TILE))
	camera.snap(_hero)
	var y: int = camera.pos.y
	for i: int in 10:
		camera.tick(_hero)
	assert_eq(camera.pos.y, y + 10 * Tuning.CAM_AUTOSCROLL_PX)


func test_vertical_only_level_never_follows_horizontally() -> void:
	var camera: LevelCamera = _camera(60, 60)
	camera.scroll_flags = Defs.SCROLL_NO_HORIZONTAL
	_hero.teleport(Vector2i(50 * Tuning.TILE, 30 * Tuning.TILE))
	camera.snap(_hero)
	assert_eq(camera.pos.x, 0)


func test_home_row_holds_the_main_floor() -> void:
	# Feet in screen row 10 on the main floor: a level without a home row scrolls down, one with home row 10
	# refuses while the camera is already below row 10.
	for home: int in [-1, 10]:
		var camera: LevelCamera = _camera(40, 60)
		camera.home_row = home
		camera.pos = Vector2i(0, 11 * Tuning.TILE)
		_hero.teleport(Vector2i(100, (home + Tuning.VIEW_ROWS) * Tuning.TILE if home >= 0 else 21 * Tuning.TILE))
		camera.tick(_hero)
		if home < 0:
			assert_true(camera.pos.y > 11 * Tuning.TILE, "no home row: the view follows down")
		else:
			assert_eq(camera.pos.y, 11 * Tuning.TILE, "home row: no downward step below the main floor")
			assert_eq(camera.v_active, 0)


func test_smooth_follow_keeps_the_hero_inside_the_margins() -> void:
	var camera: LevelCamera = _camera(200, 40)
	camera.smooth = true
	_hero.teleport(Vector2i(160, 20 * Tuning.TILE))
	camera.snap(_hero)
	_hero.xvel = 80
	for i: int in 120:
		_hero.sim_pos.x += 5
		camera.tick(_hero)
		var sx: int = _hero.sim_pos.x - camera.pos.x
		assert_true(sx <= Tuning.VIEW_W - Tuning.CAM_SMOOTH_MARGIN + 1, "right margin at tick %d (%d)" % [i, sx])
		assert_eq(camera.pos.x & 1, 0, "even pixel positions only")
	assert_eq(_hero.sim_pos.x - camera.pos.x >= Tuning.VIEW_W - Tuning.CAM_SMOOTH_MARGIN - 1, true)
