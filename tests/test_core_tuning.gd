extends TestCase
## Tuning: integer helpers and agreement of every constant with docs/spec/PHYSICS_REFERENCE.json.
## The last three tests run the bare rules of PHYSICS.md 5 / 6 on flat ground with nothing but Tuning, and are
## the pattern the player module's golden-trace tests should follow.


func test_floor16_rounds_toward_minus_infinity() -> void:
	assert_eq(Tuning.floor16(80), 5)
	assert_eq(Tuning.floor16(68), 4)
	assert_eq(Tuning.floor16(15), 0)
	assert_eq(Tuning.floor16(0), 0)
	assert_eq(Tuning.floor16(-1), -1)
	assert_eq(Tuning.floor16(-16), -1)
	assert_eq(Tuning.floor16(-17), -2)
	assert_eq(Tuning.floor16(-68), -5, "leftward motion is 1 px/tick faster (PHYSICS.md 2)")
	assert_eq(Tuning.floor16(-80), -5)
	assert_eq(Tuning.shr(-16, 3), -2)


func test_tile_helpers_work_for_negative_coordinates() -> void:
	assert_eq(Tuning.tile_top(0), 0)
	assert_eq(Tuning.tile_top(15), 0)
	assert_eq(Tuning.tile_top(16), 16)
	assert_eq(Tuning.tile_top(335), 320)
	assert_eq(Tuning.tile_top(-5), -16)
	assert_eq(Tuning.to_cell(-1), -1)
	assert_eq(Tuning.to_cell(31), 1)
	assert_eq(Tuning.in_cell(-1), 15)
	assert_eq(Tuning.in_cell(35), 3)


func test_unsigned_below_matches_the_jump_handler_rule() -> void:
	assert_true(Tuning.unsigned_below(0, Tuning.JUMP_HELD_CAP))
	assert_true(Tuning.unsigned_below(47, Tuning.JUMP_HELD_CAP))
	assert_false(Tuning.unsigned_below(48, Tuning.JUMP_HELD_CAP))
	assert_false(Tuning.unsigned_below(-1, Tuning.JUMP_HELD_CAP), "every negative xvel brakes")
	assert_false(Tuning.unsigned_below(-80, Tuning.JUMP_HELD_CAP))


func test_tick_rate_and_conversions() -> void:
	var meta: Dictionary = load_reference()["meta"]
	assert_almost_eq(Tuning.TICK_HZ, float(meta["tick_hz"]), 0.0001)
	assert_almost_eq(Tuning.TICK_DT, float(meta["tick_dt_s"]), 0.0000001)
	assert_almost_eq(Tuning.TICK_HZ * Tuning.TICK_DT, 1.0, 0.0000001)
	assert_almost_eq(Tuning.v16_to_px_per_second(80), 121.4, 0.05)
	assert_eq(Tuning.seconds_to_ticks(1.0), 24)
	assert_almost_eq(Tuning.ticks_to_seconds(22), 0.906, 0.001)
	assert_eq(Tuning.to_art(Vector2(10.0, 20.0)), Vector2(20.0, 40.0))
	assert_eq(Tuning.to_logical(Vector2(21.0, 41.0)), Vector2i(10, 20))


func test_constants_match_reference_json() -> void:
	var c: Dictionary = load_reference()["constants"]
	var expected: Dictionary = {
		"tile": Tuning.TILE, "view_cols": Tuning.VIEW_COLS, "view_rows": Tuning.VIEW_ROWS,
		"x_min": Tuning.X_MIN, "x_max_excl": Tuning.X_MAX_EXCL,
		"accel": Tuning.ACCEL, "friction": Tuning.FRICTION, "walk_cap": Tuning.WALK_CAP,
		"crawl_cap": Tuning.CRAWL_CAP, "jump_held_cap": Tuning.JUMP_HELD_CAP, "left_floor": Tuning.LEFT_FLOOR,
		"gravity": Tuning.GRAVITY, "terminal": Tuning.TERMINAL, "no_jump_ticks": Tuning.NO_JUMP_TICKS,
		"idle_air_second_wind_after_jump_ticks": Tuning.IDLE_AIR_SECOND_WIND_AFTER,
		"soft_landing_max_fall_ticks": Tuning.SOFT_LANDING_MAX_FALL_TICKS,
		"drop_min_px": Tuning.DROP_MIN_PX, "drop_min_yvel": Tuning.DROP_MIN_YVEL,
		"hard_landing_min_fall_ticks_excl": Tuning.HARD_LANDING_MIN_FALL_TICKS_EXCL,
		"hard_landing_hop": Tuning.HARD_LANDING_HOP, "shake_min_fall_ticks": Tuning.SHAKE_MIN_FALL_TICKS,
		"shake_min_yvel_excl": Tuning.SHAKE_MIN_YVEL_EXCL, "shake_value": Tuning.SHAKE_LANDING,
		"wall_probe": Tuning.WALL_PROBE, "corner_slip": Tuning.CORNER_SLIP, "drop_timer": Tuning.DROP_TIMER,
		"charge_step": Tuning.CHARGE_STEP, "charge_step_max_at": Tuning.CHARGE_STEP_MAX_AT,
		"charge_multiplier": Tuning.CHARGE_MULTIPLIER, "hit_timer": Tuning.HIT_TIMER,
		"hit_stun_min": Tuning.HIT_STUN_MIN, "hurt_yvel": Tuning.HURT_YVEL,
		"hurt_xvel_factor": Tuning.HURT_XVEL_FACTOR, "energy_start": Tuning.ENERGY_START,
		"lives_start": Tuning.LIVES_START, "bounce_yvel": Tuning.BOUNCE_YVEL,
		"bounce_yvel_up": Tuning.BOUNCE_YVEL_UP, "pogo_yvel": Tuning.POGO_YVEL,
		"stomp_min_yvel": Tuning.STOMP_MIN_YVEL, "death_anim_ticks": Tuning.DEATH_ANIM_TICKS,
		"feast_ticks": Tuning.FEAST_TICKS, "cam_right_start": Tuning.CAM_RIGHT_START,
		"cam_left_start": Tuning.CAM_LEFT_START, "cam_right_stop": Tuning.CAM_RIGHT_STOP,
		"cam_left_stop": Tuning.CAM_LEFT_STOP, "cam_idle_split": Tuning.CAM_IDLE_SPLIT,
		"cam_step_px": Tuning.CAM_STEP_PX,
	}
	for key: String in expected:
		assert_true(c.has(key), "reference has no constant '%s'" % key)
		assert_eq(int(expected[key]), int(c[key]), "constant '%s'" % key)
	assert_ints_eq(Tuning.JUMP_IMPULSES, c["jump_impulses"], "jump impulses")
	assert_eq(Tuning.JUMP_IMPULSES.size(), Tuning.JUMP_IMPULSE_TICKS)


func test_state_table_matches_reference_json() -> void:
	var table: Dictionary = load_reference()["state_table"]
	assert_ints_eq(Tuning.STATE_LUT, table["lut"], "state LUT")
	assert_eq(Tuning.STATE_LUT[Defs.IN_FIRE], Defs.HeroState.STRIKE)
	assert_eq(Tuning.STATE_LUT[Defs.IN_UP | Defs.IN_FIRE], Defs.HeroState.HIGH_STRIKE)
	assert_eq(Tuning.STATE_LUT[Defs.IN_DOWN | Defs.IN_FIRE], Defs.HeroState.LOW_STRIKE)
	assert_eq(Tuning.STATE_LUT[Defs.IN_DOWN | Defs.IN_LEFT], Defs.HeroState.CRAWL)
	assert_eq(Tuning.STATE_LUT[Defs.IN_UP | Defs.IN_RIGHT], Defs.HeroState.JUMP)
	assert_eq(Tuning.STATE_LUT[Defs.IN_LEFT | Defs.IN_RIGHT], Defs.HeroState.IDLE)
	assert_eq(Tuning.STATE_LUT[Defs.IN_UP | Defs.IN_DOWN | Defs.IN_LEFT], Defs.HeroState.WALK)
	assert_eq(Tuning.STATE_LUT[Defs.IN_UP | Defs.IN_DOWN | Defs.IN_RIGHT], Defs.HeroState.IDLE,
		"the LEFT / RIGHT asymmetry under UP + DOWN is original")
	assert_eq(GameInput.keys_to_flags("RU"), Defs.IN_RIGHT | Defs.IN_UP)


func test_attack_tables_match_reference_json() -> void:
	var attack: Dictionary = load_reference()["attack"]
	var frame_names: Array[String] = [
		"fwd_windup", "overhead", "fwd_front", "high_lowback", "high_backup", "high_front", "low_back", "low_front",
	]
	var boxes: Dictionary = attack["club_box_default_club_facing_right"]
	for i: int in frame_names.size():
		var box: Dictionary = boxes[frame_names[i]]
		var rect: Rect2i = Tuning.CLUB_BOX[i]
		assert_ints_eq([rect.position.x, rect.position.x + rect.size.x], box["x"], frame_names[i] + " x range")
		assert_ints_eq([rect.position.y, rect.position.y + rect.size.y], box["y"], frame_names[i] + " y range")
		assert_ints_eq([Tuning.CLUB_ORIGIN[i].x, Tuning.CLUB_ORIGIN[i].y], box["origin"], frame_names[i] + " origin")
	var scripts: Dictionary = {
		"forward": Tuning.STRIKE_SCRIPT_FORWARD, "high": Tuning.STRIKE_SCRIPT_HIGH, "low": Tuning.STRIKE_SCRIPT_LOW,
	}
	for key: String in scripts:
		var script: Array = attack[key]["script"]
		var ours: Array = scripts[key]
		assert_eq(ours.size(), script.size(), key + " strike length")
		for i: int in script.size():
			assert_eq(frame_names[int(ours[i])], str(script[i]), "%s strike tick %d" % [key, i + 1])
	assert_eq(Tuning.STRIKE_HOP_FORWARD, int(attack["forward"]["hop_v16"]))
	assert_eq(Tuning.STRIKE_HOP_HIGH, int(attack["high"]["hop_v16"]))
	assert_eq(Tuning.STRIKE_HOP_LOW, int(attack["low"]["hop_v16"]))
	var weapons: Array = attack["weapons"]
	for i: int in weapons.size():
		assert_eq(Tuning.WEAPON_POWER[i], int(weapons[i]["power"]), "weapon %d power" % i)
		assert_eq(Tuning.WEAPON_LOCK[i], int(weapons[i]["lock"]), "weapon %d lock" % i)
		assert_eq(Tuning.WEAPON_THROWN[i], bool(weapons[i]["thrown"]), "weapon %d thrown" % i)
	var thrown: Dictionary = load_reference()["thrown_weapons"]
	assert_eq(Tuning.THROW_XVEL, int(thrown["axe"]["xvel"]))
	assert_eq(Tuning.AXE_YVEL, int(thrown["axe"]["yvel_start"]))
	assert_eq(Tuning.AXE_YACC, int(thrown["axe"]["yvel_change_per_tick"]))
	assert_eq(Tuning.BOOMERANG_YVEL, int(thrown["swirling_axe"]["yvel_start"]))
	assert_eq(Tuning.BOOMERANG_YACC, int(thrown["swirling_axe"]["yvel_change_per_tick"]))
	assert_eq(Tuning.MAX_THROWN, int(thrown["max_in_flight"]))


func test_camera_curves_match_reference_json() -> void:
	var camera: Dictionary = load_reference()["camera"]
	var slow: Array = camera["vertical_speed_px_per_tick_by_distance"]
	var fast: Array = camera["vertical_speed_px_per_tick_by_distance_backdrop_visible"]
	assert_eq(slow.size(), Tuning.CAM_V_MAX_DISTANCE + 1)
	assert_eq(fast.size(), Tuning.CAM_V_MAX_DISTANCE + 1)
	var ours_slow: PackedInt32Array = PackedInt32Array()
	var ours_fast: PackedInt32Array = PackedInt32Array()
	for distance: int in Tuning.CAM_V_MAX_DISTANCE + 1:
		ours_slow.append(Tuning.cam_v_speed(distance, false))
		ours_fast.append(Tuning.cam_v_speed(distance, true))
	assert_ints_eq(ours_slow, slow, "slow vertical curve")
	assert_ints_eq(ours_fast, fast, "fast vertical curve")
	assert_eq(Tuning.cam_v_speed(-1, false), 0)
	assert_eq(Tuning.cam_v_speed(132, true), 0)
	var rows: Dictionary = camera["vertical_target_rows"]
	assert_eq(Tuning.CAM_V_AIR_LOW_TARGET, int(rows["airborne_sr_ge_9"]))
	assert_eq(Tuning.CAM_V_AIR_HIGH_TARGET, int(rows["airborne_sr_le_2"]))
	assert_eq(Tuning.CAM_V_GROUND_LOW_TARGET, int(rows["grounded_sr_ge_10"]))
	assert_eq(Tuning.CAM_V_GROUND_HIGH_TARGET, int(rows["grounded_sr_le_3"]))
	assert_eq(Tuning.CAM_V_ALT_LOW_TARGET, int(rows["grounded_flag0_sr_ge_8"]))
	assert_eq(Tuning.CAM_V_ALT_HIGH_TARGET, int(rows["grounded_flag0_sr_le_5"]))


func test_scoring_tables() -> void:
	assert_eq(Tuning.SCORE_LADDER.size(), 17)
	assert_eq(Tuning.SCORE_LADDER[0], 100)
	assert_eq(Tuning.SCORE_LADDER[16], 100000)
	assert_eq(Tuning.bounce_multiplier(0), 1)
	assert_eq(Tuning.bounce_multiplier(2), 2)
	assert_eq(Tuning.bounce_multiplier(5), 3)
	assert_eq(Tuning.bounce_multiplier(7), 4)
	assert_eq(Tuning.bounce_multiplier(9), 6)
	assert_eq(Tuning.bounce_multiplier(99), 8)


func test_walk_rules_reproduce_reference() -> void:
	# PHYSICS.md 5.1 / 5.3 on flat ground: ACCEL(80) while a direction is held, FRICTION when released.
	var reference: Dictionary = load_reference()
	for side: String in ["right", "left"]:
		var facing: int = 1 if side == "right" else -1
		var xvel: int = 0
		var x: int = 0
		var xs: PackedInt32Array = PackedInt32Array()
		for tick: int in 8:
			xvel = clampi(xvel + facing * Tuning.accel_step(0), -Tuning.WALK_CAP, Tuning.WALK_CAP)
			x += Tuning.floor16(xvel)
			xs.append(x)
		assert_ints_eq(xs, reference["walk"][side]["x"], "walk " + side)
		xs = PackedInt32Array()
		x = 0
		for tick: int in 10:
			if xvel > 0:
				xvel = maxi(xvel - Tuning.friction_step(0), 0)
			else:
				xvel = mini(xvel + Tuning.friction_step(0), 0)
			x += Tuning.floor16(xvel)
			xs.append(x)
		assert_ints_eq(xs, reference["stop"][side]["x"], "stop " + side)


func test_ice_rules_reproduce_reference() -> void:
	var reference: Dictionary = load_reference()["ice"]
	for ice: int in 4:
		var entry: Dictionary = reference["ice_%d" % ice]
		assert_eq(Tuning.accel_step(ice), int(entry["accel_v16"]))
		assert_eq(Tuning.friction_step(ice), int(entry["friction_v16"]))
		var xvel: int = 0
		var ticks: int = 0
		while xvel < Tuning.WALK_CAP:
			xvel = mini(xvel + Tuning.accel_step(ice), Tuning.WALK_CAP)
			ticks += 1
		assert_eq(ticks, int(entry["ticks_0_to_cap"]), "ice %d ticks to top speed" % ice)


func test_standing_jump_rules_reproduce_reference() -> void:
	# PHYSICS.md 6.1-6.3 with UP held on flat ground: jump handler (impulse table, then gravity), integration,
	# then the airborne step (gravity) - in that order.
	var reference: Dictionary = load_reference()["standing_jump_hold_up"]
	var ground_y: int = 320
	var y: int = ground_y
	var yvel: int = 0
	var jump_ticks: int = 0
	var no_jump: int = 0
	var heights: PackedInt32Array = PackedInt32Array()
	var landing_tick: int = -1
	for tick: int in range(1, 23):
		if no_jump == 0:
			var n: int = jump_ticks
			jump_ticks += 1
			if n < Tuning.JUMP_IMPULSE_TICKS:
				yvel += Tuning.JUMP_IMPULSES[n]
			else:
				yvel = mini(yvel + Tuning.GRAVITY, Tuning.TERMINAL)
		y += Tuning.floor16(yvel)
		if y >= ground_y and yvel >= 0:
			y = ground_y
			yvel = 0
			landing_tick = tick
		else:
			yvel = mini(yvel + Tuning.GRAVITY, Tuning.TERMINAL)
			if yvel > 0:
				no_jump = Tuning.NO_JUMP_TICKS
		heights.append(ground_y - y)
		if landing_tick > 0:
			break
	assert_ints_eq(heights, reference["height"], "height per tick")
	assert_eq(landing_tick, int(reference["landing_tick"]))
	var apex: int = 0
	for height: int in heights:
		apex = maxi(apex, height)
	assert_eq(apex, int(reference["apex_px"]))
