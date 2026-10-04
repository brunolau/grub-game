extends PlayerTestCase
## Horizontal movement against PHYSICS_REFERENCE.json: the state table (4.3), walking, braking, reversing,
## crawling (5.3, 7), ice (7), air control (5.4), facing (4.2), wind (13.1) and look-around (12.3).


func test_state_table_selects_every_state() -> void:
	var lut: Array = load_reference()["state_table"]["lut"]
	assert_ints_eq(Tuning.STATE_LUT, lut, "Tuning copy of the table")
	world_flat()
	spawn_hero()
	var selected: PackedInt32Array = PackedInt32Array()
	for mask: int in lut.size():
		hero.respawn_at(START)
		play(PackedInt32Array([mask]))
		selected.append(hero.state)
	assert_ints_eq(selected, lut, "state of the first tick for every input combination")


func test_swing_lock_and_hurt_override_the_table() -> void:
	world_flat()
	spawn_hero()
	hero.swing_lock = 2
	play(hold("R", 1))
	assert_eq(hero.state, Defs.HeroState.IDLE, "swing_lock: inputs count as released for the table")
	assert_eq(hero.xvel, 0, "and the idle handler does not walk")
	assert_eq(hero.facing, 1)
	hero.respawn_at(START)
	hero.hit_timer = Tuning.HIT_STUN_MIN
	play(hold("L", 1))
	assert_eq(hero.state, Defs.HeroState.HURT, "hit_timer >= 22: hurt state whatever is held")
	assert_eq(hero.facing, -1, "facing still follows the keys")


func test_walk_from_rest() -> void:
	var ref: Dictionary = load_reference()["walk"]
	for side: String in ["right", "left"]:
		world_flat()
		spawn_hero()
		var rows: Array[Dictionary] = run_rows(hold("R" if side == "right" else "L", 8))
		assert_ints_eq(column(rows, "xvel"), ref[side]["xvel"], "walk %s xvel" % side)
		assert_ints_eq(column(rows, "x"), ref[side]["x"], "walk %s x" % side)


func test_release_at_full_speed() -> void:
	var ref: Dictionary = load_reference()["stop"]
	for side: String in ["right", "left"]:
		world_flat()
		spawn_running_hero(1 if side == "right" else -1)
		var rows: Array[Dictionary] = run_rows(hold("", 10))
		assert_ints_eq(column(rows, "xvel"), ref[side]["xvel"], "stop %s xvel" % side)
		assert_ints_eq(column(rows, "x"), ref[side]["x"], "stop %s x" % side)


func test_reverse_at_full_speed() -> void:
	var ref: Dictionary = load_reference()["reverse"]
	for side: String in ["from_right", "from_left"]:
		var direction: int = 1 if side == "from_right" else -1
		world_flat()
		spawn_running_hero(direction)
		var rows: Array[Dictionary] = run_rows(hold("L" if direction > 0 else "R", 12))
		assert_ints_eq(column(rows, "xvel"), ref[side]["xvel"], "reverse %s xvel" % side)
		assert_ints_eq(column(rows, "x"), ref[side]["x"], "reverse %s x" % side)
		assert_eq(hero.facing, -direction, "facing flips at once")


func test_crawl() -> void:
	var ref: Dictionary = load_reference()["crawl"]
	for side: String in ["right", "left"]:
		world_flat()
		spawn_hero()
		var rows: Array[Dictionary] = run_rows(hold("RD" if side == "right" else "LD", 6))
		assert_ints_eq(column(rows, "xvel"), ref[side]["xvel"], "crawl %s xvel" % side)
		assert_ints_eq(column(rows, "x"), ref[side]["x"], "crawl %s x" % side)
		assert_eq(hero.state, Defs.HeroState.CRAWL)
		assert_true(hero.is_low())
		assert_eq(hero.get_box(), Rect2i(hero.sim_pos.x - 20, hero.sim_pos.y - 30, 40, 30), "crawl box 40 x 30")
	world_flat()
	spawn_running_hero(1)
	var slide: Array[Dictionary] = run_rows(hold("RD", 12))
	var entry: Dictionary = ref["enter_at_full_speed_right"]
	assert_ints_eq(column(slide, "xvel"), entry["xvel"], "entering a crawl at full speed slides first")
	assert_ints_eq(column(slide, "x"), entry["x"])
	assert_eq(int(slide[0]["handler"]), Defs.HeroState.IDLE, "the slide runs the idle handler")
	assert_eq(int(slide[4]["handler"]), Defs.HeroState.CRAWL)


func test_ice_levels() -> void:
	var ref: Dictionary = load_reference()["ice"]
	for ice: int in 4:
		var expected: Dictionary = ref["ice_%d" % ice]
		assert_eq(Tuning.accel_step(ice), int(expected["accel_v16"]))
		assert_eq(Tuning.friction_step(ice), int(expected["friction_v16"]))
		world_flat(GROUND_ROW, TileGrid.FLOOR_SOLID + ice)
		spawn_hero()
		hero.ice = ice
		var rows: Array[Dictionary] = run_rows(hold("R", 60))
		var up: int = column(rows, "xvel").find(Tuning.WALK_CAP) + 1
		assert_eq(up, int(expected["ticks_0_to_cap"]), "ice %d: ticks to top speed" % ice)
		assert_eq(int(rows[up - 1]["x"]), int(expected["px_0_to_cap"]), "ice %d: px to top speed" % ice)
		assert_eq(hero.ice, ice, "the floor sets the ice level")
		world_flat(GROUND_ROW, TileGrid.FLOOR_SOLID + ice)
		spawn_running_hero(1)
		hero.ice = ice
		var stop: Array[Dictionary] = run_rows(hold("", 120))
		assert_eq(column(stop, "xvel").find(0) + 1, int(expected["ticks_cap_to_0"]), "ice %d: ticks to stop" % ice)
		assert_eq(int(stop[-1]["x"]), int(expected["slide_px_right"]), "ice %d: slide distance" % ice)


func test_ice_level_is_kept_in_the_air() -> void:
	world_rows(PackedStringArray([
		"........................................",
		"........................................",
		"........................................",
		"........................................",
		"........................................",
		"........................................",
		"........................................",
		"........................................",
		"########################################",
		"########################################",
	]), 2)
	spawn_hero(Vector2i(100, 128))
	play(hold("R", 3))
	assert_eq(hero.ice, 2, "set by the floor tile")
	play(jump_flags(-1, 6, "R"))
	assert_false(hero.grounded)
	assert_eq(hero.ice, 2, "keeps its last value while airborne (ice-grade air control)")


func test_air_control() -> void:
	var ref: Dictionary = load_reference()["air_control"]
	var cases: Dictionary = {
		"from_rest_hold_right": [0, 1, "R"],
		"from_rest_hold_left": [0, -1, "L"],
		"full_speed_right_release": [Tuning.WALK_CAP, 1, ""],
		"full_speed_left_release": [-Tuning.WALK_CAP, -1, ""],
		"full_speed_right_hold_left": [Tuning.WALK_CAP, 1, "L"],
		"full_speed_right_hold_right": [Tuning.WALK_CAP, 1, "R"],
		"full_speed_left_hold_left": [-Tuning.WALK_CAP, -1, "L"],
		"from_rest_hold_up_and_right": [0, 1, "RU"],
		"full_speed_right_hold_up_and_right": [Tuning.WALK_CAP, 1, "RU"],
		"full_speed_left_hold_up_and_left": [-Tuning.WALK_CAP, -1, "LU"],
	}
	for case_name: String in cases:
		var setup: Array = cases[case_name]
		world_flat()
		spawn_airborne_hero(int(setup[0]), int(setup[1]))
		var rows: Array[Dictionary] = run_rows(hold(str(setup[2]), 10))
		assert_ints_eq(column(rows, "xvel"), ref[case_name]["xvel_after_tick"], "%s xvel" % case_name)
		assert_ints_eq(column(rows, "x"), ref[case_name]["x"], "%s x" % case_name)


func test_wind_pushes_left_except_crouching() -> void:
	world_flat()
	spawn_hero()
	level.set_wind(40)
	play(hold("", 1))
	# WIND subtracts 40 >> 3 = 5, then FRICTION brakes it back to 0: standing resists winds below 12 v16.
	assert_eq(hero.xvel, 0, "standing still resists a light wind")
	level.set_wind(160)
	play(hold("", 1))
	assert_eq(hero.xvel, -8, "a stronger wind (20) wins over the braking (12)")
	hero.respawn_at(START)
	play(hold("D", 4))
	assert_eq(hero.xvel, 0, "crouching is immune to the wind")
	assert_eq(hero.sim_pos.x, START_X)
	hero.respawn_at(START)
	level.set_wind(8000)
	play(hold("", 1))
	assert_eq(hero.xvel, Tuning.LEFT_FLOOR + Tuning.friction_step(0), "leftward floor -96 before braking")


func test_look_around_needs_a_standing_hero() -> void:
	world_flat()
	spawn_hero()
	play(hold("K", 1))
	assert_true(hero.looking, "LOOK while standing still")
	play(hold("LR", 1))
	assert_true(hero.looking, "LEFT + RIGHT also looks")
	assert_eq(hero.state, Defs.HeroState.IDLE)
	play(hold("R", 1))
	assert_false(hero.looking, "moving ends it")


func test_out_of_breath_after_a_long_run() -> void:
	world_flat()
	spawn_hero()
	play(hold("R", 40))
	assert_eq(hero.idle_timer, 40, "walking ticks are counted")
	play(hold("", 8))
	assert_eq(hero.xvel, 0, "stopped on the 7th tick")
	assert_true(hero.panting)
	assert_eq(hero.idle_timer, 40 - 2 * Tuning.BREATH_IDLE_DECAY, "idle_timer -= 3 per panting tick")
	assert_eq(hero.get_anim(), HeroAnim.Anim.PANT)
	play(hold("", 20))
	assert_false(hero.panting, "until the counter drops below 30")
	play(hold("RD", 1))
	assert_eq(hero.idle_timer, 0, "crawling zeroes it")


func test_skid_only_when_braking_forwards() -> void:
	world_flat()
	spawn_running_hero(1)
	play(hold("", 1))
	assert_true(hero.skidding, "moving the way he faces with nothing held")
	assert_eq(hero.get_anim(), HeroAnim.Anim.SKID)
	hero.respawn_at(START)
	hero.xvel = Tuning.WALK_CAP
	hero.facing = -1
	play(hold("", 1))
	assert_false(hero.skidding, "moving against his facing shows the standing frame")


func test_level_bounds_block_the_x_step() -> void:
	world_flat()
	spawn_hero(Vector2i(Tuning.X_MIN + 2, START.y))
	play(hold("L", 6))
	assert_true(hero.sim_pos.x >= Tuning.X_MIN, "x never goes below 8")
	assert_true(hero.xvel < 0, "the commit rule leaves xvel unchanged")
	var right_edge: int = level.grid.x_max_excl()
	hero.respawn_at(Vector2i(right_edge - 3, START.y))
	play(hold("R", 6))
	assert_true(hero.sim_pos.x < right_edge, "x stays below the level width - 8")
