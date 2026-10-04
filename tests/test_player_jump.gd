extends PlayerTestCase
## Jumping, gravity, falling and landing against PHYSICS_REFERENCE.json (PHYSICS.md 6, Appendix B).


func test_standing_jump_up_held() -> void:
	var ref: Dictionary = load_reference()["standing_jump_hold_up"]
	world_flat()
	spawn_hero()
	var rows: Array[Dictionary] = run_rows(jump_flags(-1, 60))
	var landing: int = first_landing()
	assert_eq(landing, int(ref["landing_tick"]), "lands on tick 22")
	assert_ints_eq(column(rows, "height", landing), ref["height"], "height per tick")
	assert_ints_eq(column(rows, "yvel", landing), ref["yvel_after_tick"], "yvel per tick")
	assert_eq(apex(rows, landing), int(ref["apex_px"]))
	var heights: Array = column(rows, "height")
	assert_eq(heights.find(int(ref["apex_px"])) + 1, int(ref["apex_first_tick"]))
	assert_eq(heights.rfind(int(ref["apex_px"]), landing - 1) + 1, int(ref["apex_last_tick"]))
	var again: int = 0
	for i: int in range(landing, rows.size()):
		if int(rows[i]["height"]) > 0:
			again = i + 1
			break
	assert_eq(again, int(ref["next_takeoff_tick_if_up_held"]), "the lock-out delays the next take-off")


func test_variable_jump_height() -> void:
	var ref: Dictionary = load_reference()["variable_jump"]
	for k: int in range(1, 15):
		world_flat()
		spawn_hero()
		var rows: Array[Dictionary] = run_rows(jump_flags(k, 60))
		var expected: Dictionary = ref["up_held_%d_ticks" % k]
		var landing: int = first_landing()
		assert_eq(landing, int(expected["landing_tick"]), "UP held %d ticks: landing tick" % k)
		assert_eq(apex(rows, landing), int(expected["apex_px"]), "UP held %d ticks: apex" % k)
		if k == 1:
			assert_ints_eq(column(rows, "height", landing), ref["tap_height"], "tap jump height per tick")
		elif k == 9:
			assert_ints_eq(column(rows, "height", landing), ref["release_after_9_height"], "release after 9")


func test_running_jumps_up_held() -> void:
	var ref: Dictionary = load_reference()["running_jump"]
	for side: String in ["right", "left"]:
		var direction: int = 1 if side == "right" else -1
		var key: String = "R" if direction > 0 else "L"
		var expected: Dictionary = ref["hold_up_%s" % side]
		world_flat()
		spawn_running_hero(direction)
		var rows: Array[Dictionary] = run_rows(jump_flags(-1, 60, key))
		var landing: int = first_landing()
		assert_eq(landing, int(expected["landing_tick"]), "%s: landing tick" % side)
		assert_ints_eq(column(rows, "x", landing), expected["x"], "%s: x per tick" % side)
		assert_ints_eq(column(rows, "height", landing), expected["height"], "%s: height per tick" % side)
		assert_ints_eq(column(rows, "xvel", landing), expected["xvel_after_tick"], "%s: xvel per tick" % side)
		assert_eq(absi(int(rows[landing - 1]["x"])), int(expected["distance_px"]))
		var standing: Dictionary = ref["standing_start_hold_up_%s" % side]
		world_flat()
		spawn_hero()
		var from_rest: Array[Dictionary] = run_rows(jump_flags(-1, 60, key))
		landing = first_landing()
		assert_eq(landing, int(standing["landing_tick"]), "%s standing start: landing tick" % side)
		assert_ints_eq(column(from_rest, "x", landing), standing["x"], "%s standing start: x per tick" % side)


func test_running_jumps_released_after_k_ticks() -> void:
	var ref: Dictionary = load_reference()["running_jump"]
	for side: String in ["right", "left"]:
		var direction: int = 1 if side == "right" else -1
		var key: String = "R" if direction > 0 else "L"
		var table: Dictionary = ref["release_up_after_k_%s" % side]
		for k: int in range(1, 12):
			world_flat()
			spawn_running_hero(direction)
			var rows: Array[Dictionary] = run_rows(jump_flags(k, 60, key))
			var expected: Dictionary = table["k_%d" % k]
			var landing: int = first_landing()
			assert_eq(landing, int(expected["landing_tick"]), "%s k=%d: landing tick" % [side, k])
			assert_eq(absi(int(rows[landing - 1]["x"])), int(expected["distance_px"]), "%s k=%d: distance" % [side, k])
			assert_eq(apex(rows, landing), int(expected["apex_px"]), "%s k=%d: apex" % [side, k])
			if k == 9:
				var long_jump: Dictionary = ref["release_up_after_9_%s" % side]
				assert_ints_eq(column(rows, "x", landing), long_jump["x"], "%s long jump x" % side)
				assert_ints_eq(column(rows, "height", landing), long_jump["height"], "%s long jump height" % side)


func test_repeated_jumps_with_up_held() -> void:
	var ref: Dictionary = load_reference()["running_jump"]["hold_up_right_repeated"]
	world_flat()
	spawn_running_hero(1)
	var rows: Array[Dictionary] = run_rows(jump_flags(-1, 90, "R"))
	var takeoffs: Array[int] = []
	for i: int in rows.size():
		if int(rows[i]["height"]) > 0 and (i == 0 or int(rows[i - 1]["height"]) == 0):
			takeoffs.append(i + 1)
	assert_ints_eq(takeoffs.slice(0, 3), ref["takeoff_ticks"], "a jump every 27 ticks")
	assert_ints_eq(landing_ticks.slice(0, 3), ref["landing_ticks"])
	var xs: Array[int] = []
	for tick: int in landing_ticks.slice(0, 3):
		xs.append(int(rows[tick - 1]["x"]))
	assert_ints_eq(xs, ref["x_at_landings"])
	assert_ints_eq(column(rows, "xvel").slice(21, 27), ref["xvel_on_ground_between_jumps"], "braking in the lock-out")


func test_walking_off_ledges() -> void:
	var ref: Dictionary = load_reference()["fall"]
	var edge_col: int = 70
	for n: int in range(1, 17):
		var expected: Dictionary = ref["by_drop_tiles"]["%d" % n]
		world_ledge(edge_col, n)
		spawn_running_hero(1, Vector2i(edge_col * 16 - 5, START.y))
		var rows: Array[Dictionary] = run_rows(hold("R", 80))
		var t: int = first_landing()
		var label: String = "drop %d tiles" % n
		assert_eq(t, int(expected["landing_tick"]), label + ": touchdown tick")
		var before: Dictionary = rows[t - 2]
		assert_eq(int(before["fall_ticks"]), int(expected["fall_ticks_at_touchdown"]), label + ": fall ticks")
		assert_eq(int(before["yvel"]), int(expected["yvel_at_touchdown"]), label + ": yvel at touchdown")
		assert_eq("hard" if landed_hard(t) else "soft", str(expected["landing_type"]), label + ": landing type")
		assert_eq(level.shake_requests.size() > 0, bool(expected["shake"]), label + ": screen shake")
		assert_eq(int(rows[t - 1]["x"]) - 5, int(expected["x_travel_px_at_touchdown"]), label + ": travel")
		var rise: int = 0
		for i: int in range(t - 1, rows.size()):
			rise = maxi(rise, int(rows[i]["height"]) - int(rows[t - 1]["height"]))
		assert_eq(rise, int(expected["hop_rise_px"]), label + ": hop")
		var settle: int = t
		for i: int in landing_ticks.size():
			if landing_ticks[i] > t and not landing_hard[i]:
				settle = landing_ticks[i]
				break
		assert_eq(settle, int(expected["settle_tick"]), label + ": settle tick")
		if n == 16:
			var fall: Array[int] = []
			var per_tick: Array[int] = []
			for i: int in t - 1:
				fall.append(-int(rows[i]["height"]))
				per_tick.append(fall[i] - (0 if i == 0 else fall[i - 1]))
			assert_ints_eq(fall, ref["cumulative_fall_px"], "cumulative fall")
			assert_ints_eq(per_tick, ref["per_tick_fall_px"], "fall per tick: 0, 1, 2 ... 12, 12")
			assert_ints_eq(column(rows, "yvel", t - 1), ref["yvel_after_tick"], "yvel per tick")


func test_impulse_rise_heights() -> void:
	var ref: Dictionary = load_reference()["impulse_rise"]
	for key: String in ref:
		world_flat()
		spawn_hero()
		hero.yvel = int(key)
		var rows: Array[Dictionary] = run_rows(hold("", 60))
		var landing: int = first_landing()
		assert_eq(landing, int(ref[key]["landing_tick"]), "yvel %s: landing tick" % key)
		assert_eq(apex(rows, landing), int(ref[key]["rise_px"]), "yvel %s: rise" % key)


func test_jump_lockout_and_no_coyote_time() -> void:
	var ref: Dictionary = load_reference()["jump_lockout"]
	world_ledge(70, 1)
	spawn_running_hero(1, Vector2i(70 * 16 - 5, START.y))
	var flags: PackedInt32Array = hold("R", 1)
	flags.append_array(hold("RU", 39))
	var rows: Array[Dictionary] = run_rows(flags)
	var landing: int = first_landing()
	assert_eq(landing, int(ref["landing_tick"]), "UP held while falling does not jump")
	var jump: int = 0
	for i: int in range(landing, rows.size()):
		if int(rows[i]["state"]) == Defs.HeroState.JUMP and int(rows[i]["yvel"]) < 0:
			jump = i + 1
			break
	assert_eq(jump, int(ref["first_tick_jump_handler_runs_again"]))
	assert_eq(jump - landing, int(ref["grounded_ticks_before_jump"]), "6 grounded ticks of lock-out")
	world_ledge(70, 1)
	spawn_running_hero(1, Vector2i(70 * 16 - 5, START.y))
	var first: Array[Dictionary] = run_rows(hold("RU", 3))
	assert_eq(int(first[0]["yvel"]) < 0, bool(ref["up_pressed_on_the_floor_loss_tick_still_jumps"]))
	world_ledge(70, 1)
	spawn_running_hero(1, Vector2i(70 * 16 - 5, START.y))
	var lost: Array[Dictionary] = run_rows(hold("R", 1))
	assert_eq(int(lost[0]["yvel"]), Tuning.GRAVITY, "gravity on the tick the floor is lost")
	assert_eq(int(lost[0]["no_jump"]), Tuning.NO_JUMP_TICKS, "and the lock-out is armed at once")
	play(hold("RU", 1))
	assert_true(hero.yvel > 0, "one tick later UP does not jump")


func test_no_double_jump_but_the_impulse_resumes() -> void:
	world_flat()
	spawn_hero()
	play(jump_flags(2, 3))
	assert_eq(hero.jump_ticks, 2)
	var rising: int = hero.yvel
	assert_true(rising < 0, "still rising after releasing UP")
	play(hold("U", 1))
	assert_eq(hero.jump_ticks, 3, "re-pressing UP while rising continues the impulse table")
	assert_eq(hero.yvel, rising + Tuning.JUMP_IMPULSES[2] + Tuning.GRAVITY)
	play(hold("", 14))
	assert_true(hero.yvel > 0, "falling now")
	var falling: int = hero.yvel
	play(hold("U", 1))
	assert_eq(hero.yvel, falling + Tuning.GRAVITY, "UP while falling runs the idle handler: no second jump")


func test_hard_landing_hop_unless_low_band() -> void:
	world_ledge(70, 6)
	spawn_running_hero(1, Vector2i(70 * 16 - 5, START.y))
	play(hold("", 30))
	assert_eq(landing_ticks.size(), 2, "hard landing, then the hop settles")
	assert_true(landing_hard[0])
	world_ledge(70, 6)
	level.scroll_flags = Defs.SCROLL_LOW_BAND
	spawn_running_hero(1, Vector2i(70 * 16 - 5, START.y))
	var floor_y: int = (GROUND_ROW + 6) * 16
	var highest: Array[int] = [floor_y]
	play(hold("", 30), func(_tick: int) -> void:
		if not landing_ticks.is_empty():
			highest[0] = mini(highest[0], hero.sim_pos.y)
	)
	assert_eq(landing_ticks.size(), 2, "scroll flag bit 0: no hop ...")
	assert_true(landing_hard[0])
	assert_eq(landing_ticks[1], landing_ticks[0] + 1, "... he settles one tick later")
	assert_eq(highest[0], floor_y, "never above the floor after the touchdown")
	assert_eq(hero.yvel, 0)


func test_hard_landing_shakes_the_screen_and_lifts_the_hero() -> void:
	world_ledge(70, 12)
	level.apply_shakes = true
	spawn_running_hero(1, Vector2i(70 * 16 - 5, START.y))
	var lifted: Array[int] = []
	var floor_y: int = (GROUND_ROW + 12) * 16
	play(hold("", 40), func(_tick: int) -> void:
		if level.shake_offset > 0 and hero.sim_pos.y < floor_y:
			lifted.append(floor_y - hero.sim_pos.y)
	)
	assert_ints_eq(level.shake_requests, PackedInt32Array([Tuning.SHAKE_LANDING]))
	assert_false(lifted.is_empty(), "the shake nudges the standing hero up on odd ticks")
	world_ledge(70, 12)
	level.apply_shakes = true
	spawn_running_hero(1, Vector2i(70 * 16 - 5, START.y))
	play(hold("R", 23))
	assert_eq(first_landing(), 23)
	assert_true(level.shake > 0, "shaking after the landing")
	play(hold("D", 5))
	var nudged: Array[int] = []
	var shaking_ticks: Array[int] = [0]
	play(hold("D", 8), func(_tick: int) -> void:
		if level.shake_offset > 0:
			shaking_ticks[0] += 1
		if hero.sim_pos.y != floor_y:
			nudged.append(hero.sim_pos.y)
	)
	assert_true(shaking_ticks[0] > 0, "the earthquake goes on ...")
	assert_true(nudged.is_empty(), "... but crouching resists it")
