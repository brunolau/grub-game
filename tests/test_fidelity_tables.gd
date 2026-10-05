extends FidelityCase
## Every hero table of docs/spec/PHYSICS_REFERENCE.json, tick for tick, in real levels built by the world loader:
## walk, stop, reverse, crawl, ice, standing / variable / running jumps, falls from 1 to 16 tiles, impulse rises,
## hurt knock-back and immunity, the three strike timelines, weapon repeat periods, charge, the jump lock-out, air
## control, thrown weapons, walls, ceilings, hatches and the horizontal camera page. The scenario set-ups mirror
## reference_sim.py (running_hero, airborne_hero, injected hurt / impulses).

const KEY_OF: Dictionary = {1: "R", -1: "L"}
const SIDE_OF: Dictionary = {1: "right", -1: "left"}


# --- Horizontal movement (PHYSICS.md 5) --------------------------------------------------------------------------

func test_walk_from_rest() -> void:
	var ref: Dictionary = load_reference()["walk"]
	for direction: int in [1, -1]:
		var expected: Dictionary = ref[SIDE_OF[direction]]
		load_world(flat_rows())
		var rows: Array[Dictionary] = run(hold(KEY_OF[direction], 8))
		var label: String = "walk %s" % SIDE_OF[direction]
		assert_ints_eq(column(rows, "xvel"), expected["xvel"], label + ": xvel")
		assert_ints_eq(rel_x(rows, START_X), expected["x"], label + ": x")
		var top: int = _first_tick(column(rows, "xvel"), Tuning.WALK_CAP * direction)
		assert_eq(top, int(expected["ticks_to_top_speed"]), label + ": ticks to top speed")
		assert_eq(absi(int(rows[top - 1]["x"]) - START_X), int(expected["px_to_top_speed"]), label + ": px")
		assert_eq(absi(int(rows[7]["x"]) - int(rows[6]["x"])), int(expected["top_speed_px_per_tick"]))


func test_stop_from_full_speed() -> void:
	var ref: Dictionary = load_reference()["stop"]
	for direction: int in [1, -1]:
		var expected: Dictionary = ref[SIDE_OF[direction]]
		load_world(flat_rows())
		set_running(direction)
		var rows: Array[Dictionary] = run(hold("", 10))
		var label: String = "stop %s" % SIDE_OF[direction]
		assert_ints_eq(column(rows, "xvel"), expected["xvel"], label + ": xvel")
		assert_ints_eq(rel_x(rows, START_X), expected["x"], label + ": x")
		assert_eq(_first_tick(column(rows, "xvel"), 0), int(expected["ticks_until_xvel_zero"]), label)
		assert_eq(absi(int(rows[9]["x"]) - START_X), int(expected["distance_px"]), label + ": distance")


func test_reverse_at_full_speed() -> void:
	var ref: Dictionary = load_reference()["reverse"]
	for direction: int in [1, -1]:
		var expected: Dictionary = ref["from_right" if direction > 0 else "from_left"]
		load_world(flat_rows())
		set_running(direction)
		var rows: Array[Dictionary] = run(hold(KEY_OF[-direction], 12))
		var label: String = "reverse from %s" % SIDE_OF[direction]
		assert_ints_eq(column(rows, "xvel"), expected["xvel"], label + ": xvel")
		var xs: Array = rel_x(rows, START_X)
		assert_ints_eq(xs, expected["x"], label + ": x")
		var zero: int = _first_tick(column(rows, "xvel"), 0)
		assert_eq(zero, int(expected["ticks_to_zero"]), label + ": ticks to zero")
		assert_eq(_first_tick(column(rows, "xvel"), -direction * Tuning.WALK_CAP),
				int(expected["ticks_to_full_reverse"]), label + ": ticks to full reverse")
		var overshoot: int = 0
		for i: int in zero:
			overshoot = maxi(overshoot, absi(int(xs[i])))
		assert_eq(overshoot, int(expected["overshoot_px"]), label + ": overshoot")


func test_crawl() -> void:
	var ref: Dictionary = load_reference()["crawl"]
	for direction: int in [1, -1]:
		var expected: Dictionary = ref[SIDE_OF[direction]]
		load_world(flat_rows())
		var rows: Array[Dictionary] = run(hold(KEY_OF[direction] + "D", 6))
		var label: String = "crawl %s" % SIDE_OF[direction]
		assert_ints_eq(column(rows, "xvel"), expected["xvel"], label + ": xvel")
		assert_ints_eq(rel_x(rows, START_X), expected["x"], label + ": x")
		assert_eq(_first_tick(column(rows, "xvel"), direction * Tuning.CRAWL_CAP), int(expected["ticks_to_cap"]))
		assert_eq(absi(int(rows[5]["x"]) - int(rows[4]["x"])), int(expected["cap_px_per_tick"]))
	var slide: Dictionary = ref["enter_at_full_speed_right"]
	load_world(flat_rows())
	set_running(1)
	var slide_rows: Array[Dictionary] = run(hold("RD", 12))
	assert_ints_eq(column(slide_rows, "xvel"), slide["xvel"], "crawl entered at full speed: xvel")
	assert_ints_eq(rel_x(slide_rows, START_X), slide["x"], "crawl entered at full speed: x")


func test_ice_levels() -> void:
	var ref: Dictionary = load_reference()["ice"]
	for ice: int in 4:
		var expected: Dictionary = ref["ice_%d" % ice]
		var label: String = "ice %d" % ice
		load_world(flat_rows(), START_CELL, ice)
		hero.ice = ice
		var rows: Array[Dictionary] = run(hold("R", 60))
		assert_eq(int(rows[0]["xvel"]), int(expected["accel_v16"]), label + ": acceleration step")
		var up: int = _first_tick(column(rows, "xvel"), Tuning.WALK_CAP)
		assert_eq(up, int(expected["ticks_0_to_cap"]), label + ": ticks 0 -> 80")
		assert_eq(int(rows[up - 1]["x"]) - START_X, int(expected["px_0_to_cap"]), label + ": px 0 -> 80")
		assert_eq(hero.ice, ice, label + ": the floor sets ice")
		load_world(flat_rows(), START_CELL, ice)
		hero.ice = ice
		set_running(1)
		rows = run(hold("", 120))
		assert_eq(Tuning.WALK_CAP - int(rows[0]["xvel"]), int(expected["friction_v16"]), label + ": braking step")
		assert_eq(_first_tick(column(rows, "xvel"), 0), int(expected["ticks_cap_to_0"]), label + ": ticks 80 -> 0")
		assert_eq(int(rows[119]["x"]) - START_X, int(expected["slide_px_right"]), label + ": slide")


# --- Jumps (PHYSICS.md 6) -------------------------------------------------------------------------------------------

func test_standing_jump_up_held() -> void:
	var ref: Dictionary = load_reference()["standing_jump_hold_up"]
	load_world(flat_rows())
	var rows: Array[Dictionary] = run(hold("U", 60))
	var land: int = landing_tick(rows)
	assert_eq(land, int(ref["landing_tick"]), "landing tick")
	assert_eq(land - 1, int(ref["airborne_ticks"]))
	assert_ints_eq(heights(rows, START.y, land), ref["height"], "height per tick")
	assert_ints_eq(column(rows, "yvel", land), ref["yvel_after_tick"], "yvel per tick")
	var hs: Array = heights(rows, START.y, land)
	var apex: int = int(hs.max())
	assert_eq(apex, int(ref["apex_px"]), "apex")
	assert_eq(hs.find(apex) + 1, int(ref["apex_first_tick"]))
	assert_eq(hs.rfind(apex) + 1, int(ref["apex_last_tick"]))
	assert_eq(int(rows[land - 1]["yvel"]), 0, "soft landing")
	assert_eq(int(rows[land - 1]["x"]) - START_X, int(ref["x_at_landing"]))
	var peak: int = 0
	var previous: int = 0
	for h: Variant in hs:
		peak = maxi(peak, int(h) - previous)
		previous = int(h)
	assert_eq(peak, int(ref["peak_rise_px_in_one_tick"]))
	var again: int = 0
	for i: int in range(land, rows.size()):
		if START.y - int(rows[i]["y"]) > 0:
			again = i + 1
			break
	assert_eq(again, int(ref["next_takeoff_tick_if_up_held"]), "next take-off with UP held")
	assert_eq(again - 1, int(ref["jump_period_ticks_if_up_held"]))
	assert_eq(again - land, int(ref["grounded_lockout_ticks"]), "grounded lock-out")


func test_variable_jump_heights() -> void:
	var ref: Dictionary = load_reference()["variable_jump"]
	for k: int in range(1, 15):
		var expected: Dictionary = ref["up_held_%d_ticks" % k]
		load_world(flat_rows())
		var rows: Array[Dictionary] = run(flags_of([[k, "U"], [60 - k, ""]]))
		var land: int = landing_tick(rows)
		var label: String = "UP held %d ticks" % k
		assert_eq(land, int(expected["landing_tick"]), label + ": landing tick")
		assert_eq(land - 1, int(expected["airborne_ticks"]), label + ": airborne ticks")
		assert_eq(int(heights(rows, START.y, land).max()), int(expected["apex_px"]), label + ": apex")
		if k == 1:
			assert_ints_eq(heights(rows, START.y, land), ref["tap_height"], "tap jump height per tick")
		if k == 9:
			assert_ints_eq(heights(rows, START.y, land), ref["release_after_9_height"], "release after 9")


func test_running_jumps() -> void:
	var ref: Dictionary = load_reference()["running_jump"]
	for direction: int in [1, -1]:
		var side: String = SIDE_OF[direction]
		var key: String = KEY_OF[direction]
		var held: Dictionary = ref["hold_up_" + side]
		load_world(flat_rows())
		set_running(direction)
		var rows: Array[Dictionary] = run(hold(key + "U", 60))
		var land: int = landing_tick(rows)
		var label: String = "running jump %s, UP held" % side
		assert_eq(land, int(held["landing_tick"]), label + ": landing tick")
		assert_ints_eq(rel_x(rows, START_X, land), held["x"], label + ": x")
		assert_ints_eq(heights(rows, START.y, land), held["height"], label + ": height")
		assert_ints_eq(column(rows, "xvel", land), held["xvel_after_tick"], label + ": xvel")
		assert_eq(absi(int(rows[land - 1]["x"]) - START_X), int(held["distance_px"]), label + ": distance")
		assert_eq(int(heights(rows, START.y, land).max()), int(held["apex_px"]), label + ": apex")
		assert_eq(absi(int(rows[5]["x"]) - int(rows[4]["x"])), int(held["px_per_tick_steady"]), label)
		var released: Dictionary = ref["release_up_after_k_" + side]
		for k: int in range(1, 12):
			var expected: Dictionary = released["k_%d" % k]
			load_world(flat_rows())
			set_running(direction)
			rows = run(flags_of([[k, key + "U"], [60 - k, key]]))
			land = landing_tick(rows)
			label = "running jump %s, UP released after %d" % [side, k]
			assert_eq(land, int(expected["landing_tick"]), label + ": landing tick")
			assert_eq(absi(int(rows[land - 1]["x"]) - START_X), int(expected["distance_px"]), label + ": distance")
			assert_eq(int(heights(rows, START.y, land).max()), int(expected["apex_px"]), label + ": apex")
			if k == 9:
				var nine: Dictionary = ref["release_up_after_9_" + side]
				assert_ints_eq(rel_x(rows, START_X, land), nine["x"], label + ": x")
				assert_ints_eq(heights(rows, START.y, land), nine["height"], label + ": height")
		var standing: Dictionary = ref["standing_start_hold_up_" + side]
		load_world(flat_rows())
		rows = run(hold(key + "U", 60))
		land = landing_tick(rows)
		assert_eq(land, int(standing["landing_tick"]), "standing start %s: landing tick" % side)
		assert_ints_eq(rel_x(rows, START_X, land), standing["x"], "standing start %s: x" % side)
	var repeated: Dictionary = ref["hold_up_right_repeated"]
	load_world(flat_rows())
	set_running(1)
	var repeat_rows: Array[Dictionary] = run(hold("RU", 90))
	var takeoffs: Array = []
	var landings: Array = []
	var x_at: Array = []
	for i: int in repeat_rows.size():
		var up: bool = int(repeat_rows[i]["y"]) < START.y
		if up and (i == 0 or int(repeat_rows[i - 1]["y"]) == START.y):
			takeoffs.append(i + 1)
		if i > 0 and int(repeat_rows[i]["grounded"]) == 1 and int(repeat_rows[i - 1]["grounded"]) == 0:
			landings.append(i + 1)
			x_at.append(int(repeat_rows[i]["x"]) - START_X)
	assert_ints_eq(takeoffs, repeated["takeoff_ticks"], "repeated jumps: take-off ticks", true)
	assert_ints_eq(landings, repeated["landing_ticks"], "repeated jumps: landing ticks", true)
	assert_ints_eq(x_at, repeated["x_at_landings"], "repeated jumps: x at landings", true)
	assert_ints_eq(column(repeat_rows, "xvel").slice(21, 27), repeated["xvel_on_ground_between_jumps"],
			"repeated jumps: braking during the lock-out")


func test_jump_lockout_and_no_coyote_time() -> void:
	var ref: Dictionary = load_reference()["jump_lockout"]
	load_world(ledge_rows(70, 1))
	place_hero(Vector2i(70 * 16 - 5, START.y))
	set_running(1)
	var rows: Array[Dictionary] = run(flags_of([[1, "R"], [39, "RU"]]))
	var land: int = landing_tick(rows)
	assert_eq(land, int(ref["landing_tick"]), "landing tick after a 1-tile drop")
	var jump: int = 0
	for i: int in range(land, rows.size()):
		if int(rows[i]["state"]) == Defs.HeroState.JUMP and int(rows[i]["yvel"]) < 0:
			jump = i + 1
			break
	assert_eq(jump, int(ref["first_tick_jump_handler_runs_again"]), "first jump after the landing")
	assert_eq(jump - land, int(ref["grounded_ticks_before_jump"]))
	assert_eq(int(ref["coyote_ticks"]), 0)
	assert_eq(int(rows[1]["handler"]), Defs.HeroState.IDLE, "UP one tick after the floor was lost: no jump")
	load_world(ledge_rows(70, 1))
	place_hero(Vector2i(70 * 16 - 5, START.y))
	set_running(1)
	rows = run(hold("RU", 3))
	assert_eq(int(rows[0]["yvel"]) < 0, bool(ref["up_pressed_on_the_floor_loss_tick_still_jumps"]),
			"UP on the tick the floor is lost still jumps")


func test_falls_from_ledges() -> void:
	var ref: Dictionary = load_reference()["fall"]
	var drops: Dictionary = ref["by_drop_tiles"]
	for n: int in range(1, 17):
		var expected: Dictionary = drops["%d" % n]
		var label: String = "walk off a %d-tile ledge" % n
		load_world(ledge_rows(70, n))
		place_hero(Vector2i(70 * 16 - 5, START.y))
		set_running(1)
		# Step 18 is not part of the reference model: a shake is recorded, then taken away (see test_fidelity_more).
		cancel_shake = true
		var rows: Array[Dictionary] = run(hold("R", 80))
		assert_eq(death_ticks.size(), 0, label + ": the hero stays alive in the real level")
		var land: int = landing_tick(rows)
		assert_eq(land, int(expected["landing_tick"]), label + ": touchdown tick")
		var before: Dictionary = rows[land - 2]
		assert_eq(int(before["fall_ticks"]), int(expected["fall_ticks_at_touchdown"]), label + ": fall_ticks")
		assert_eq(int(before["yvel"]), int(expected["yvel_at_touchdown"]), label + ": yvel at touchdown")
		assert_eq(Tuning.floor16(int(before["yvel"])), int(expected["px_per_tick_at_touchdown"]))
		var hard: bool = int(rows[land - 1]["yvel"]) == Tuning.HARD_LANDING_HOP
		assert_eq("hard" if hard else "soft", str(expected["landing_type"]), label + ": landing type")
		assert_eq(shake_log[land - 1] > 0, bool(expected["shake"]), label + ": screen shake")
		assert_eq(int(rows[land - 1]["x"]) - 70 * 16, int(expected["x_travel_px_at_touchdown"]),
				label + ": travel past the edge")
		var land_y: int = int(rows[land - 1]["y"])
		var top: int = land_y
		var settle: int = land
		for i: int in range(land, rows.size()):
			top = mini(top, int(rows[i]["y"]))
			if int(rows[i]["grounded"]) == 1 and int(rows[i - 1]["grounded"]) == 0:
				settle = i + 1
				break
		assert_eq(land_y - top, int(expected["hop_rise_px"]), label + ": hop")
		assert_eq(settle, int(expected["settle_tick"]), label + ": settles")
		if n == 16:
			var fall: Array = []
			for i: int in land - 1:
				fall.append(int(rows[i]["y"]) - START.y)
			assert_ints_eq(fall, ref["cumulative_fall_px"], "cumulative fall")
			var per_tick: Array = []
			var previous: int = 0
			for value: Variant in fall:
				per_tick.append(int(value) - previous)
				previous = int(value)
			assert_ints_eq(per_tick, ref["per_tick_fall_px"], "fall per tick")
			assert_ints_eq(column(rows, "yvel", land - 1), ref["yvel_after_tick"], "yvel per tick")
			var terminal: int = _first_tick(column(rows, "yvel"), Tuning.TERMINAL)
			assert_eq(terminal, int(ref["terminal_yvel_reached_after_tick"]))
			assert_eq(int(fall[terminal]), int(ref["px_fallen_when_first_moving_at_terminal"]))
			assert_eq(int(rows[0]["no_jump"]), Tuning.NO_JUMP_TICKS, "no_jump armed on the first falling tick")
			assert_eq(int(ref["no_jump_armed_on_tick"]), 1)


func test_impulse_rises() -> void:
	var ref: Dictionary = load_reference()["impulse_rise"]
	for key: String in ref:
		var expected: Dictionary = ref[key]
		load_world(flat_rows())
		hero.yvel = int(key)
		var rows: Array[Dictionary] = run(hold("", 60))
		var land: int = landing_tick(rows)
		assert_eq(land, int(expected["landing_tick"]), "yvel %s: landing tick" % key)
		assert_eq(int(heights(rows, START.y, land).max()), int(expected["rise_px"]), "yvel %s: rise" % key)


# --- Hurt (PHYSICS.md 10.1) ---------------------------------------------------------------------------------------

func test_hurt_knockback_tables() -> void:
	var ref: Dictionary = load_reference()["hurt"]
	for scenario: String in ["standing", "moving_right", "moving_left"]:
		var expected: Dictionary = ref[scenario]
		load_world(flat_rows())
		if scenario != "standing":
			set_running(1 if scenario == "moving_right" else -1)
		assert_true(hero.hurt(null, Defs.HurtKind.ENEMY), scenario + ": the hit is applied")
		hero.hit_timer -= 1  # the draw step of the hit tick (reference_sim.sc_hurt)
		var rows: Array[Dictionary] = run(hold("", 50))
		var land: int = landing_tick(rows)
		assert_eq(land, int(expected["landing_tick"]), scenario + ": back on the ground")
		assert_ints_eq(rel_x(rows, START_X, land), expected["x"], scenario + ": x")
		assert_ints_eq(heights(rows, START.y, land), expected["height"], scenario + ": height")
		var xs: Array = rel_x(rows, START_X)
		var per_tick: Array = []
		var previous: int = 0
		for i: int in 8:
			per_tick.append(int(xs[i]) - previous)
			previous = int(xs[i])
		assert_ints_eq(per_tick, expected["x_per_tick"], scenario + ": x per tick")
		assert_eq(int(xs[49]), int(expected["knockback_px"]), scenario + ": knock-back")
		assert_eq(int(heights(rows, START.y).max()), int(expected["rise_px"]), scenario + ": rise")
		var stun: Array = []
		for i: int in rows.size():
			if int(rows[i]["state"]) == Defs.HeroState.HURT:
				stun.append(i + 1)
		assert_eq(stun.size(), int(expected["stun_ticks"]), scenario + ": stunned ticks")
		assert_eq(int(stun[-1]) + 1, int(expected["first_tick_with_control"]), scenario + ": control returns")
	load_world(flat_rows())
	hero.hurt(null, Defs.HurtKind.ENEMY)
	assert_eq(hero.hit_timer, int(ref["hit_timer_start"]))
	hero.hit_timer -= 1
	var contact_rows: Array[Dictionary] = run(hold("", 50))
	# The contact pass runs only while hit_timer == 0: it is skipped on every tick that starts with hit_timer > 0.
	var cleared: int = _first_tick(column(contact_rows, "hit_timer"), 0)
	assert_eq(cleared, int(ref["immune_contact_passes"]), "immune contact passes after the hit tick")
	assert_eq(cleared + 1, int(ref["ticks_after_hit_tick_until_contact_tested_again"]))


# --- Club attack (PHYSICS.md 8) -------------------------------------------------------------------------------------

func test_strike_timelines() -> void:
	var ref: Dictionary = load_reference()["attack"]
	for scenario: String in ["forward", "high", "low"]:
		var expected: Dictionary = ref[scenario]
		load_world(flat_rows())
		var keys: String = {"forward": "F", "high": "UF", "low": "DF"}[scenario]
		var rows: Array[Dictionary] = run(hold(keys, 40))
		var lock: int = Tuning.WEAPON_LOCK[Defs.Weapon.CLUB]
		var ends: Array = _strike_ends(rows, lock)
		assert_true(ends.size() >= 2, scenario + ": two strikes in 40 ticks")
		var length: int = int(expected["length_ticks"])
		assert_eq(int(ends[0]), length, scenario + ": strike length")
		var per_tick: Array = expected["per_tick"]
		assert_eq(per_tick.size(), int(ends[1]) - 1)
		for i: int in per_tick.size():
			var want: Dictionary = per_tick[i]
			var got: Dictionary = rows[i]
			var label: String = "%s strike tick %d" % [scenario, i + 1]
			assert_eq(STATE_NAMES[int(got["state"])], str(want["state"]), label + ": state")
			assert_eq(START.y - int(got["y"]), int(want["height"]), label + ": height")
			assert_eq(int(got["grounded"]) == 1, bool(want["grounded"]), label + ": grounded")
			if want["club_box"] == null:
				assert_eq(str(got["club"]), "", label + ": no club box")
			else:
				var box: Dictionary = want["club_box"]
				assert_eq(str(got["club"]), str(box["frame"]), label + ": frame")
				var rel: Array = got["club_rel"]
				assert_ints_eq(rel, ints(box["x"]) + ints(box["y"]), label + ": box x0, x1, y0, y1")
		var created: Array = []
		for i: int in length:
			if str(rows[i]["club"]) == CLUB_FRAME_NAMES[_front_frame(scenario)]:
				created.append(i + 1)
		assert_ints_eq(created, expected["front_box_created_on_ticks"], scenario + ": front box ticks")
		assert_eq(int(rows[length - 1]["swing_lock"]) + 1, int(expected["swing_lock_set"]), scenario + ": swing_lock")
		for tick: Variant in expected["input_ignored_ticks"]:
			assert_eq(int(rows[int(tick) - 1]["state"]), Defs.HeroState.IDLE, scenario + ": input ignored")
		assert_eq(int(ends[1]) - int(ends[0]), int(expected["auto_repeat_period_ticks"]), scenario + ": period")
		var next: int = int(ends[0]) + lock
		assert_eq(next, int(expected["next_strike_first_tick"]))
		assert_ne(int(rows[next - 1]["state"]), Defs.HeroState.IDLE, scenario + ": next strike starts")
		var first: Array[Dictionary] = rows.slice(0, int(ends[1]) - 1)
		assert_eq(int(heights(first, START.y).max()), int(expected["hop_rise_px"]), scenario + ": hop")
		var airborne: Array = []
		for i: int in first.size():
			if int(first[i]["grounded"]) == 0:
				airborne.append(i + 1)
		assert_ints_eq(airborne, expected["airborne_ticks_first_strike"], scenario + ": airborne ticks")


func test_forward_repeat_period_per_weapon() -> void:
	var ref: Dictionary = load_reference()["attack"]["repeat_period_forward"]
	var names: Array[String] = ["club", "hammer", "axe", "swirling_axe"]
	for weapon: int in 4:
		load_world(flat_rows())
		Game.set_weapon(weapon)
		var rows: Array[Dictionary] = run(hold("F", 50))
		var ends: Array = _strike_ends(rows, Tuning.WEAPON_LOCK[weapon])
		assert_true(ends.size() >= 2, names[weapon] + ": two strikes")
		assert_eq(int(ends[1]) - int(ends[0]), int(ref[names[weapon]]), names[weapon] + ": period with FIRE held")


func test_charge_table() -> void:
	var ref: Dictionary = load_reference()["attack"]["charge"]
	for k: int in [1, 2, 4, 5, 6, 7, 10, 60]:
		var expected: Dictionary = ref["crouch_%d_ticks" % k]
		load_world(flat_rows())
		run(hold("D", k))
		assert_eq(hero.charge, int(expected["charge_after_crouch"]), "crouch %d: charge" % k)
		var rows: Array[Dictionary] = run(hold("F", 7))
		var powers: Array = column(rows, "club_power")
		var want: Array = []
		for p: Variant in expected["box_power_per_strike_tick"]:
			want.append(-1 if p == null else int(p))
		assert_ints_eq(powers, want, "crouch %d: power of each strike tick's box" % k)
		var charged: int = 0
		for i: int in range(4, 7):
			if int(powers[i]) == Tuning.WEAPON_POWER[Defs.Weapon.CLUB] * Tuning.CHARGE_MULTIPLIER:
				charged += 1
		assert_eq(charged, int(expected["charged_front_frames"]), "crouch %d: charged front boxes" % k)
	load_world(flat_rows())
	run(hold("D", 80))
	assert_eq(hero.charge, int(ref["saturation_value_after_long_crouch"]), "charge saturates")
	var standing_rows: Array[Dictionary] = run(hold("", 60))
	assert_eq(_first_tick(column(standing_rows, "charge"), 0), int(ref["ticks_until_zero_after_standing_up"]))


func test_thrown_weapon_flight() -> void:
	var ref: Dictionary = load_reference()["thrown_weapons"]
	for weapon: int in [Defs.Weapon.AXE, Defs.Weapon.BOOMERANG]:
		var expected: Dictionary = ref["axe" if weapon == Defs.Weapon.AXE else "swirling_axe"]
		for direction: int in [1, -1]:
			load_world(flat_rows())
			level.set_view_size(Vector2i(1600, 1000))
			Game.set_weapon(weapon)
			hero.facing = direction
			run(hold("F", 6))
			# The hand: origin of the front box of strike tick 6 (PHYSICS.md 8.4, [P] club-box reference).
			var anchor: Vector2i = Vector2i(START_X + direction * 23, START.y - 2)
			run(hold("F", 1))
			var thrown: Array[SimEntity] = level.get_kind(Defs.Kind.HERO_PROJECTILE)
			assert_eq(thrown.size(), 1, "one weapon thrown on the last strike tick")
			if thrown.size() != 1:
				continue
			var projectile: ProjectileBase = thrown[0] as ProjectileBase
			var offset: Array = ints(expected["spawn_offset_from_reference"])
			assert_eq(projectile.sim_pos, anchor + Vector2i(direction * int(offset[0]), int(offset[1])), "spawn")
			assert_eq(projectile.xvel, direction * int(expected["xvel"]))
			assert_eq(projectile.yvel, int(expected["yvel_start"]))
			assert_eq(projectile.yacc, int(expected["yvel_change_per_tick"]))
			var dx: Array = []
			var dy: Array = []
			var last: Vector2i = projectile.sim_pos
			for i: int in 12:
				run(hold("", 1))
				if not is_instance_valid(projectile) or projectile.spent:
					break
				dx.append(direction * (projectile.sim_pos.x - last.x))
				dy.append(projectile.sim_pos.y - last.y)
				last = projectile.sim_pos
			assert_ints_eq(dx, expected["dx_per_tick"], "flight dx")
			assert_ints_eq(dy, expected["dy_per_tick"], "flight dy")


## Four weapons in flight: the next throw is refused (PHYSICS.md 8.4 "up to 4 in flight").
func test_at_most_four_thrown_weapons() -> void:
	load_world(flat_rows())
	Game.set_weapon(Defs.Weapon.AXE)
	for i: int in int(load_reference()["thrown_weapons"]["max_in_flight"]):
		level.spawn(&"projectiles/hero_axe", START - Vector2i(-40 - 20 * i, 60), {
			"from_hero": true, "power": 20, "xvel": 0, "yvel": 0, "yacc": 0,
		})
	run(hold("F", 7))
	assert_eq(level.get_kind(Defs.Kind.HERO_PROJECTILE).size(), Tuning.MAX_THROWN, "no fifth weapon")


# --- Air control (PHYSICS.md 5.4) ---------------------------------------------------------------------------------

func test_air_control() -> void:
	var ref: Dictionary = load_reference()["air_control"]
	var cases: Dictionary = {
		"from_rest_hold_right": [0, 1, "R"], "from_rest_hold_left": [0, -1, "L"],
		"full_speed_right_release": [80, 1, ""], "full_speed_left_release": [-80, -1, ""],
		"full_speed_right_hold_left": [80, 1, "L"], "full_speed_right_hold_right": [80, 1, "R"],
		"full_speed_left_hold_left": [-80, -1, "L"], "from_rest_hold_up_and_right": [0, 1, "RU"],
		"full_speed_right_hold_up_and_right": [80, 1, "RU"], "full_speed_left_hold_up_and_left": [-80, -1, "LU"],
	}
	assert_eq(cases.size(), ref.size(), "every air-control case of the reference")
	for scenario: String in cases:
		var setup: Array = cases[scenario]
		# reference_sim.airborne_hero: already falling (yvel 16, no_jump armed) 400 px above the floor.
		load_world(flat_rows(40))
		place_hero(Vector2i(START_X, 40 * 16 - 400))
		hero.xvel = int(setup[0])
		hero.facing = int(setup[1])
		hero.yvel = Tuning.GRAVITY
		hero.no_jump = Tuning.NO_JUMP_TICKS
		hero.fall_ticks = 1
		hero.grounded = false
		var rows: Array[Dictionary] = run(hold(str(setup[2]), 10))
		assert_ints_eq(column(rows, "xvel"), ref[scenario]["xvel_after_tick"], scenario + ": xvel")
		assert_ints_eq(rel_x(rows, START_X), ref[scenario]["x"], scenario + ": x")


# --- Collision (PHYSICS.md 11.2) -----------------------------------------------------------------------------------

func test_walls() -> void:
	var ref: Dictionary = load_reference()["collision"]
	var right: Dictionary = ref["walk_into_wall_right"]
	var lines: PackedStringArray = flat_rows()
	for row: int in GROUND_ROW:
		put(lines, 70, row, "|".repeat(COLS - 70))
	load_world(lines)
	place_hero(Vector2i(70 * 16 - 40, START.y))
	set_running(1)
	var rows: Array[Dictionary] = run(hold("R", 12))
	assert_ints_eq(column(rows, "x"), right["x_abs"], "wall on the right: x")
	assert_ints_eq(column(rows, "xvel"), right["xvel"], "wall on the right: xvel")
	assert_eq(hero.sim_pos.x, int(right["rest_x_abs"]))
	assert_eq(int(right["wall_left_edge_x"]) - hero.sim_pos.x, int(right["gap_px_feet_to_wall"]))
	var left: Dictionary = ref["walk_into_wall_left"]
	lines = flat_rows()
	for row: int in GROUND_ROW:
		put(lines, 0, row, "|".repeat(61))
	load_world(lines)
	place_hero(Vector2i(61 * 16 + 40, START.y))
	set_running(-1)
	run(hold("L", 12))
	assert_eq(hero.sim_pos.x, int(left["rest_x_abs"]), "wall on the left: rest x")
	assert_eq(hero.sim_pos.x - int(left["wall_right_edge_x"]), int(left["gap_px_wall_to_feet"]))


## Ceiling-only cells (FLAGS ceiling, no floor, no side) as in reference_sim.sc_collision. The legend has no such
## character, so the row is loaded as air and given the ceiling property through the grid's cell setter.
func test_standing_jump_under_ceilings() -> void:
	var ref: Dictionary = load_reference()["collision"]["standing_jump_under_ceiling"]
	for gap: int in range(2, 6):
		var expected: Dictionary = ref["ceiling_bottom_%d_px_above_feet" % ((gap - 1) * 16)]
		load_world(flat_rows())
		for col: int in COLS:
			level.grid.set_props(col, GROUND_ROW - gap, TileGrid.FLOOR_EMPTY, TileGrid.SIDE_OPEN,
					TileGrid.CEILING_SOLID, TileGrid.PROFILE_NONE)
		var rows: Array[Dictionary] = run(hold("U", 40))
		var label: String = "ceiling %d rows up" % gap
		# A bump stops him (yvel 0) on a row boundary; the airborne step then adds one gravity step.
		var bump: int = 0
		for i: int in rows.size():
			var rising: bool = i == 0 or int(rows[i - 1]["yvel"]) < 0
			if rising and int(rows[i]["yvel"]) == Tuning.GRAVITY and (int(rows[i]["y"]) & 15) == 0:
				bump = i + 1
				break
		var land: int = landing_tick(rows)
		if expected["head_bump_tick"] == null:
			assert_eq(bump, 0, label + ": no bump")
		else:
			assert_eq(bump, int(expected["head_bump_tick"]), label + ": bump tick")
		assert_eq(int(heights(rows, START.y, land).max()), int(expected["apex_px"]), label + ": apex")
		assert_eq(land, int(expected["landing_tick"]), label + ": landing tick")


func test_hatch_drop() -> void:
	var ref: Dictionary = load_reference()["collision"]["hatch_drop"]
	var lines: PackedStringArray = flat_rows(24, 28)
	put(lines, 0, GROUND_ROW, "_".repeat(COLS))
	load_world(lines)
	var rows: Array[Dictionary] = run(flags_of([[3, "D"], [37, ""]]))
	assert_eq(_first_tick(column(rows, "grounded"), 0), int(ref["first_airborne_tick"]), "falls through at once")
	assert_eq(landing_tick(rows), int(ref["landing_tick"]), "lands four rows lower")


# --- Horizontal camera page (PHYSICS.md 12.1; the world module's camera, driven by the real hero) ---------------

func test_camera_page_while_walking() -> void:
	var ref: Dictionary = load_reference()["camera"]
	for direction: int in [1, -1]:
		var expected: Dictionary = ref["walk_" + SIDE_OF[direction]]
		load_world(flat_rows())
		var camera: LevelCamera = level.get_camera()
		camera.pos = Vector2i(int(expected["start_camera_col"]) * 16, camera.pos.y)
		camera.prev = camera.pos
		set_running(direction)
		var cols: Array = []
		var screen: Array = []
		for i: int in 79:
			run(hold(KEY_OF[direction], 1))
			cols.append(level.get_camera_cell().x)
			screen.append(Tuning.to_cell(hero.sim_pos.x) - level.get_camera_cell().x)
		var label: String = "camera, walking %s" % SIDE_OF[direction]
		assert_ints_eq(cols, expected["camera_col_per_tick"], label + ": camera column", true)
		assert_ints_eq(screen, expected["hero_screen_col_per_tick"], label + ": hero screen column", true)


# --- Helpers ------------------------------------------------------------------------------------------------------

## First tick (1-based) whose value equals `value`, 0 = never.
func _first_tick(values: Array, value: int) -> int:
	for i: int in values.size():
		if int(values[i]) == value:
			return i + 1
	return 0


## Ticks on which a strike script ended: swing_lock was set to `lock` and already decremented once.
func _strike_ends(rows: Array[Dictionary], lock: int) -> Array:
	var ends: Array = []
	for i: int in rows.size():
		if int(rows[i]["swing_lock"]) == lock - 1 and (i == 0 or int(rows[i - 1]["swing_lock"]) == 0):
			ends.append(i + 1)
	return ends


func _front_frame(strike: String) -> int:
	match strike:
		"high":
			return Tuning.ClubFrame.HIGH_FRONT
		"low":
			return Tuning.ClubFrame.LOW_FRONT
	return Tuning.ClubFrame.FWD_FRONT
