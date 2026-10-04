extends PlayerTestCase
## The hero-versus-tile procedure of PHYSICS.md 11.2 against PHYSICS_REFERENCE.json ("collision") and the rules
## the reference model leaves out: slopes, one-way floors, the corner slip, deadly tiles and pits.


func test_walk_into_a_wall_on_the_right() -> void:
	var ref: Dictionary = load_reference()["collision"]["walk_into_wall_right"]
	var wall_col: int = 70
	world_wall(wall_col, WORLD_COLS - 1)
	var x_start: int = wall_col * 16 - 40
	spawn_running_hero(1, Vector2i(x_start, START.y))
	var rows: Array[Dictionary] = run_rows(hold("R", 12))
	var xs: Array[int] = []
	for row: Dictionary in rows:
		xs.append(x_start + int(row["x"]))
	assert_ints_eq(xs, ref["x_abs"], "x per tick")
	assert_ints_eq(column(rows, "xvel"), ref["xvel"], "xvel per tick")
	assert_eq(hero.sim_pos.x, int(ref["rest_x_abs"]))
	assert_eq(int(ref["wall_left_edge_x"]) - hero.sim_pos.x, int(ref["gap_px_feet_to_wall"]), "rests 10 px away")


func test_walk_into_a_wall_on_the_left() -> void:
	var ref: Dictionary = load_reference()["collision"]["walk_into_wall_left"]
	var wall_last: int = 60
	world_wall(0, wall_last)
	spawn_running_hero(-1, Vector2i((wall_last + 1) * 16 + 40, START.y))
	play(hold("L", 12))
	assert_eq(hero.sim_pos.x, int(ref["rest_x_abs"]))
	assert_eq(hero.sim_pos.x - int(ref["wall_right_edge_x"]), int(ref["gap_px_wall_to_feet"]), "rests 9 px away")
	assert_eq(hero.xvel, 0)


func test_walls_are_only_sensed_in_the_row_above_the_feet() -> void:
	# A wall tile two rows up (head height) does not block: low passages only need SIDE 0 in the bottom row.
	world_rows(PackedStringArray([
		"..................................",
		"..................................",
		"..................................",
		"..................................",
		"..................................",
		"..................................",
		"..............||||||||||..........",
		"..................................",
		"##################################",
		"##################################",
	]))
	spawn_running_hero(1, Vector2i(150, 128))
	play(hold("R", 40))
	assert_true(hero.sim_pos.x > 18 * 16, "walked under the wall tiles")
	assert_true(hero.grounded)


func test_standing_jump_under_a_ceiling() -> void:
	var ref: Dictionary = load_reference()["collision"]["standing_jump_under_ceiling"]
	for gap_rows: int in [2, 3, 4, 5]:
		var expected: Dictionary = ref["ceiling_bottom_%d_px_above_feet" % ((gap_rows - 1) * 16)]
		world_ceiling(GROUND_ROW - gap_rows)
		spawn_hero()
		var bump: Array[int] = [0]
		var rows: Array[Dictionary] = []
		var origin: Vector2i = hero.sim_pos
		play(jump_flags(-1, 40), func(tick: int) -> void:
			if hero.bumped_head and bump[0] == 0:
				bump[0] = tick
			rows.append({"height": origin.y - hero.sim_pos.y})
		)
		var label: String = "ceiling %d rows up" % gap_rows
		var expected_bump: int = int(expected["head_bump_tick"]) if expected["head_bump_tick"] != null else 0
		assert_eq(bump[0], expected_bump, label + ": head bump tick")
		var landing: int = first_landing()
		assert_eq(landing, int(expected["landing_tick"]), label + ": landing tick")
		assert_eq(apex(rows, landing), int(expected["apex_px"]), label + ": apex")


func test_hatch_drop_while_crouching() -> void:
	var ref: Dictionary = load_reference()["collision"]["hatch_drop"]
	make_world(
		GROUND_ROW + 6,
		func(_c: int, r: int) -> int:
			if r == GROUND_ROW:
				return TileGrid.FLOOR_HATCH
			return TileGrid.FLOOR_SOLID if r >= GROUND_ROW + 4 else TileGrid.FLOOR_EMPTY,
		func(_c: int, _r: int) -> int: return 0,
		func(_c: int, _r: int) -> int: return 0
	)
	spawn_hero()
	play(hold("", 5))
	assert_true(hero.grounded, "a hatch is a floor while drop_timer == 0")
	hero.respawn_at(START)
	var rows: Array[Dictionary] = run_rows(hold("D", 3) + hold("", 37))
	var airborne: int = 0
	for i: int in rows.size():
		if not bool(rows[i]["grounded"]):
			airborne = i + 1
			break
	assert_eq(airborne, int(ref["first_airborne_tick"]), "crouching opens the hatch at once")
	assert_eq(first_landing(), int(ref["landing_tick"]))


func test_one_way_floors() -> void:
	world_rows(PackedStringArray([
		"..............................",
		"..............................",
		"..............................",
		"..............................",
		"..............................",
		"..........----------..........",
		"..............................",
		"..............................",
		"##############################",
		"##############################",
	]))
	spawn_hero(Vector2i(14 * 16 + 8, 128))
	var passed_up: Array[bool] = [false]
	play(jump_flags(9, 24), func(_tick: int) -> void:
		if hero.sim_pos.y < 5 * 16:
			passed_up[0] = true
	)
	assert_true(passed_up[0], "jumped up through the platform (floors do nothing while rising)")
	assert_true(hero.grounded, "and landed on top of it")
	assert_eq(hero.sim_pos.y, 5 * 16)
	play(hold("", 6))
	play(hold("D", 2) + hold("", 12))
	assert_eq(hero.sim_pos.y, 5 * 16, "a one-way platform is not a hatch: crouching does not drop through")


func test_slopes_carry_the_hero_up_and_down() -> void:
	# A hill: 45 degree slopes on the lower row, gentle half slopes on the upper one (ARCHITECTURE 7.4).
	world_rows(PackedStringArray([
		"..............................",
		"..............................",
		"..............................",
		"..............................",
		"..............................",
		"..........12##34..............",
		"........./######\\.............",
		"########################################",
		"########################################",
	]))
	spawn_hero(Vector2i(6 * 16, 7 * 16))
	var ys: Array[int] = []
	var air: Array[int] = [0]
	play(hold("R", 60), func(_tick: int) -> void:
		ys.append(hero.sim_pos.y)
		if not hero.grounded:
			air[0] += 1
	)
	assert_eq(air[0], 0, "walking over the hill never leaves the ground")
	assert_eq(ys.min(), 5 * 16, "on top of the hill")
	assert_eq(hero.sim_pos.y, 7 * 16, "back on the flat ground after the foot of the hill")
	for i: int in range(1, ys.size()):
		assert_true(absi(ys[i] - ys[i - 1]) <= 5, "follows the surface smoothly (tick %d)" % (i + 1))
	var on_slope: int = 0
	for y: int in ys:
		if y % 16 != 0:
			on_slope += 1
	assert_true(on_slope > 4, "the feet follow the profiles inside the slope cells")


func test_slope_profile_offsets_while_standing() -> void:
	world_rows(PackedStringArray([
		"....................",
		"....................",
		"....................",
		"....................",
		"......./............",
		"########################",
		"########################",
	]))
	for local: int in [0, 5, 10, 15]:
		spawn_hero(Vector2i(7 * 16 + local, 5 * 16))
		play(hold("", 2))
		assert_eq(hero.sim_pos.y, 4 * 16 + (15 - local), "'/' surface at local x %d" % local)
		assert_true(hero.grounded)


func test_corner_slip_pushes_out_of_a_wall() -> void:
	world_rows(PackedStringArray([
		"....................",
		"....................",
		"....................",
		"....................",
		"..........|.........",
		"########################",
		"########################",
	]))
	spawn_hero(Vector2i(10 * 16 + 6, 5 * 16))
	play(hold("", 1))
	assert_eq(hero.sim_pos.x, 10 * 16 + 6 + Tuning.CORNER_SLIP, "standing inside a wall tile: 2 px per tick out")
	play(hold("", 6))
	assert_eq(hero.sim_pos.x, 11 * 16, "until the body tile is free")


func test_floor_spikes_kill() -> void:
	world_rows(PackedStringArray([
		"....................",
		"....................",
		"....................",
		"....................",
		"....................",
		"#####^^^^###########",
		"####################",
	]))
	spawn_hero(Vector2i(2 * 16, 5 * 16))
	var causes: Array[StringName] = []
	var on_died: Callable = func(cause: StringName) -> void: causes.append(cause)
	Events.player_died.connect(on_died)
	play(hold("R", 12))
	Events.player_died.disconnect(on_died)
	assert_true(hero.dead)
	assert_eq(causes, [&"spikes"] as Array[StringName], "one death, by the spikes")
	assert_false(hero.control_enabled)


func test_liquid_kills_by_floor_and_by_side() -> void:
	world_rows(PackedStringArray([
		"....................",
		"....................",
		"....................",
		"....................",
		"....................",
		"#####~~~~~##########",
		"#####~~~~~##########",
	]))
	spawn_hero(Vector2i(2 * 16, 5 * 16))
	var causes: Array[StringName] = []
	var on_died: Callable = func(cause: StringName) -> void: causes.append(cause)
	Events.player_died.connect(on_died)
	play(hold("R", 12))
	Events.player_died.disconnect(on_died)
	assert_eq(causes, [&"liquid"] as Array[StringName])


func test_deadly_ceiling_kills_even_a_standing_hero() -> void:
	world_rows(PackedStringArray([
		"....................",
		"....................",
		"....................",
		"...........!........",
		"....................",
		"####################",
		"####################",
	]))
	spawn_hero(Vector2i(8 * 16, 5 * 16))
	play(hold("", 2))
	assert_false(hero.dead, "the spike is two columns away")
	play(hold("R", 20))
	assert_true(hero.dead, "walking under it kills: the ceiling test runs while grounded")


func test_falling_out_of_the_map_is_a_pit_death() -> void:
	world_rows(PackedStringArray([
		"....................",
		"....................",
		"....................",
		"....................",
		"....................",
		"######......########",
	]))
	spawn_hero(Vector2i(4 * 16, 5 * 16))
	var causes: Array[StringName] = []
	var on_died: Callable = func(cause: StringName) -> void: causes.append(cause)
	Events.player_died.connect(on_died)
	play(hold("R", 6) + hold("", 20))
	Events.player_died.disconnect(on_died)
	assert_eq(causes, [&"pit"] as Array[StringName])


func test_leaving_the_view_by_more_than_a_screen_kills() -> void:
	world_flat()
	spawn_hero()
	hero.teleport(START + Vector2i(0, -2 * Tuning.VIEW_H))
	level.player = null  # the view no longer follows him: it stays where it is
	var causes: Array[StringName] = []
	var on_died: Callable = func(cause: StringName) -> void: causes.append(cause)
	Events.player_died.connect(on_died)
	play(hold("", 1))
	Events.player_died.disconnect(on_died)
	assert_eq(causes, [&"off_screen"] as Array[StringName])


func test_deadly_side_tile_in_the_body_rows() -> void:
	var rows: PackedStringArray = PackedStringArray([
		"....................",
		"....................",
		"..........+.........",
		"....................",
		"....................",
		"####################",
		"####################",
	])
	world_rows(rows)
	spawn_hero(Vector2i(8 * 16, 5 * 16))
	play(hold("R", 8))
	assert_true(hero.dead, "standing (35 px) the body probes reach the second row above the feet row")
	world_rows(rows)
	spawn_hero(Vector2i(8 * 16, 5 * 16))
	play(hold("RD", 30))
	assert_false(hero.dead, "crawling (30 px) only the first row above the feet row is probed")
	assert_true(hero.sim_pos.x > 11 * 16, "crawled past it")
