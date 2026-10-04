extends FidelityCase
## Hero rules of PHYSICS.md that the reference tables do not cover, in real levels built by the world loader:
## left/right asymmetries, slopes (our 45 degree and half-gradient profiles, ARCHITECTURE 3.2, with the HEIGHT
## rules of PHYSICS.md 11.2 #4 unchanged), ice in the air, ceilings (head bumps while running, the corner slip,
## deadly ceilings), deadly floors and sides, ledge walk-offs without coyote time, the landing lock-out after a
## hard landing, hurt by a real enemy contact with its immunity window and the fourth hit, the strikes' active
## ticks against a real enemy, charge, pogo, enemy bounces with and without UP, and the screen-shake nudge.
##
## Expected values that are not in PHYSICS_REFERENCE.json were derived by hand from the spec text with an
## integer model of the same rules (reference_sim.py extended by the HEIGHT profiles of 11.1 / 11.2 #4 and the
## step-18 nudge of 13.3); every array below is quoted from that derivation.

## Hill: '/' and '\' over solid ground, two tiles high, columns 64..68 (rows 18-19).
const HILL: Array[String] = ["/###\\", "/#\\"]
const KEY_OF: Dictionary = {1: "R", -1: "L"}


# --- Asymmetries (PHYSICS.md 2, 5.3, 6.4, 10.1, 15.5) ------------------------------------------------------------

## floor16 and the -96 floor make leftward motion longer; the reference numbers hold in both directions.
func test_left_right_asymmetries() -> void:
	load_world(flat_rows())
	set_running(1)
	var right: Array[Dictionary] = run(hold("", 10))
	load_world(flat_rows())
	set_running(-1)
	var left: Array[Dictionary] = run(hold("", 10))
	assert_eq(int(right[9]["x"]) - START_X, 12, "release at +80 slides 12 px")
	assert_eq(START_X - int(left[9]["x"]), 17, "release at -80 slides 17 px")
	load_world(flat_rows())
	set_running(1)
	right = run(hold("RU", 22))
	load_world(flat_rows())
	set_running(-1)
	left = run(hold("LU", 22))
	assert_eq(int(right[21]["x"]) - START_X, 88, "UP + RIGHT held: 88 px (4 px per tick)")
	assert_eq(START_X - int(left[21]["x"]), 110, "UP + LEFT held: 110 px (5 px per tick, unsigned test)")
	assert_eq(int(right[5]["x"]) - int(right[4]["x"]), 4)
	assert_eq(int(left[4]["x"]) - int(left[5]["x"]), 5)
	load_world(flat_rows())
	set_running(1)
	hero.hurt(null, Defs.HurtKind.ENEMY)
	right = run(hold("", 20))
	load_world(flat_rows())
	set_running(-1)
	hero.hurt(null, Defs.HurtKind.ENEMY)
	left = run(hold("", 20))
	assert_eq(START_X - int(right[19]["x"]), 23, "hit while moving right: thrown 23 px left")
	assert_eq(int(left[19]["x"]) - START_X, 31, "hit while moving left: thrown 31 px right")


## The x commit rule (PHYSICS.md 2, bounds of ARCHITECTURE.md 7.4: 8 <= x < min(4088, cols * 16 - 8)): a step
## that would leave the range is not applied and xvel is left unchanged.
func test_x_commit_rule_at_the_level_edges() -> void:
	load_world(flat_rows())
	place_hero(Vector2i(COLS * 16 - 48, START.y))
	set_running(1)
	var rows: Array[Dictionary] = run(hold("R", 10))
	assert_ints_eq(column(rows, "x"), [2005, 2010, 2015, 2020, 2025, 2030, 2035, 2035, 2035, 2035])
	assert_eq(column(rows, "xvel").count(Tuning.WALK_CAP), 10, "xvel unchanged at the edge")
	load_world(flat_rows())
	place_hero(Vector2i(40, START.y))
	set_running(-1)
	rows = run(hold("L", 10))
	assert_ints_eq(column(rows, "x"), [35, 30, 25, 20, 15, 10, 10, 10, 10, 10])
	assert_eq(column(rows, "xvel").count(-Tuning.WALK_CAP), 10)


# --- Slopes (PHYSICS.md 7, 11.1 HEIGHT, 11.2 #4) -----------------------------------------------------------------

func test_walk_over_a_hill_both_ways() -> void:
	_load_hill()
	var rows: Array[Dictionary] = run(hold("R", 40))
	assert_ints_eq(column(rows, "x"), [1001, 1003, 1006, 1010, 1015, 1020, 1025, 1030, 1035, 1040, 1045, 1050, 1055,
			1060, 1065, 1070, 1075, 1080, 1085, 1090, 1095, 1100, 1105, 1110, 1115, 1120, 1125, 1130, 1135, 1140,
			1145, 1150, 1155, 1160, 1165, 1170, 1175, 1180, 1185, 1190], "uphill and downhill: no speed change")
	assert_ints_eq(column(rows, "y"), [320, 320, 320, 320, 320, 320, 318, 313, 308, 303, 298, 293, 288, 288, 288,
			288, 291, 296, 301, 306, 311, 316, 320, 320, 320, 320, 320, 320, 320, 320, 320, 320, 320, 320, 320, 320,
			320, 320, 320, 320], "feet snapped to the surface, glued on the way down")
	assert_eq(column(rows, "grounded").count(0), 0, "never airborne on the hill")
	assert_eq(column(rows, "yvel").count(0), 40, "slopes add no vertical speed")
	_load_hill()
	place_hero(Vector2i(1176, START.y))
	rows = run(hold("L", 40))
	assert_ints_eq(column(rows, "y"), [320, 320, 320, 320, 320, 320, 320, 320, 320, 320, 320, 320, 320, 320, 320,
			320, 317, 312, 307, 302, 297, 292, 288, 288, 288, 288, 292, 297, 302, 307, 312, 317, 320, 320, 320, 320,
			320, 320, 320, 320], "the same hill walked to the left")
	assert_eq(int(rows[39]["x"]), 986)
	assert_eq(column(rows, "grounded").count(0), 0)


func test_walk_over_a_gentle_ramp_both_ways() -> void:
	var lines: PackedStringArray = flat_rows()
	put(lines, 64, GROUND_ROW - 1, "12##34")
	load_world(lines)
	var rows: Array[Dictionary] = run(hold("R", 30))
	assert_ints_eq(column(rows, "y"), [320, 320, 320, 320, 320, 320, 319, 316, 314, 311, 309, 306, 304, 304, 304,
			304, 304, 304, 304, 305, 307, 310, 312, 315, 317, 320, 320, 320, 320, 320], "half-gradient ramp, right")
	assert_eq(int(rows[29]["x"]), 1140)
	load_world(lines)
	place_hero(Vector2i(1144, START.y))
	rows = run(hold("L", 30))
	assert_ints_eq(column(rows, "y"), [320, 320, 320, 320, 320, 320, 319, 317, 314, 312, 309, 307, 304, 304, 304,
			304, 304, 304, 304, 304, 307, 309, 312, 314, 317, 319, 320, 320, 320, 320], "half-gradient ramp, left")
	assert_eq(column(rows, "grounded").count(0), 0)


## Standing on a slope: no sliding force (PHYSICS.md 7).
func test_standing_on_a_slope_does_not_slide() -> void:
	_load_hill()
	place_hero(Vector2i(1032, 311))
	var rows: Array[Dictionary] = run(hold("", 20))
	assert_eq(column(rows, "x").count(1032), 20)
	assert_eq(column(rows, "y").count(311), 20)


## Landing on a profiled tile while falling: the surface offset is limited to this tick's fall (11.2 #4), so the
## feet settle onto a steep slope over two ticks.
func test_jump_landings_on_slopes() -> void:
	_load_hill()
	place_hero(Vector2i(1032, 311))
	var rows: Array[Dictionary] = run(hold("U", 24))
	assert_ints_eq(column(rows, "y"), [306, 299, 291, 283, 275, 268, 262, 257, 253, 251, 251, 252, 254, 257, 261,
			266, 272, 279, 287, 296, 311, 311, 311, 311], "rising slope: lands on the surface at once")
	assert_ints_eq(column(rows, "yvel"), [-49, -84, -103, -107, -101, -90, -76, -61, -45, -13, 19, 35, 51, 67, 83,
			99, 115, 131, 147, 163, 0, 0, 0, 0])
	_load_hill()
	place_hero(Vector2i(1084, 300))
	rows = run(hold("U", 24))
	assert_ints_eq(column(rows, "y"), [295, 288, 280, 272, 264, 257, 251, 246, 242, 240, 240, 241, 243, 246, 250,
			255, 261, 268, 276, 285, 298, 300, 300, 300], "falling slope: offset 12 limited to the 10 px fall")
	_load_hill()
	rows = run(hold("RU", 30))
	assert_ints_eq(column(rows, "x"), [1001, 1004, 1007, 1010, 1013, 1017, 1021, 1025, 1029, 1033, 1037, 1041,
			1045, 1049, 1053, 1057, 1061, 1065, 1068, 1070, 1072, 1073, 1073, 1074, 1077, 1080, 1083, 1086, 1090,
			1094], "standing jump onto the hill top")
	assert_ints_eq(column(rows, "y"), [315, 308, 300, 292, 284, 277, 271, 266, 262, 260, 260, 261, 263, 266, 270,
			275, 281, 288, 288, 288, 288, 289, 289, 284, 277, 269, 261, 253, 246, 240])
	assert_ints_eq(column(rows, "xvel"), [32, 64, 68, 72, 76, 80, 80, 80, 80, 80, 80, 80, 80, 80, 80, 80, 80, 68,
			56, 44, 32, 20, 8, 40, 64, 68, 72, 76, 80, 80], "UP held: the lock-out brakes on the hill")


# --- Ice (PHYSICS.md 7: ice keeps its value in the air) -----------------------------------------------------------

func test_ice_grade_air_control_after_jumping_off_ice() -> void:
	load_world(flat_rows(), START_CELL, 3)
	var rows: Array[Dictionary] = run(flags_of([[3, ""], [1, "U"], [20, "L"]]))
	assert_ints_eq(column(rows, "xvel"), [0, 0, 0, 0, -4, -8, -12, -16, -20, -24, -28, -32, -36, -38, -40, -42, -44,
			-46, -48, -50, -52, -54, -56, -58], "ice 3: 2 v16 per ACCEL in the air (two per tick), 2 on the ground")
	assert_ints_eq(column(rows, "x"), [1000, 1000, 1000, 1000, 999, 998, 997, 996, 994, 992, 990, 988, 985, 982, 979,
			976, 973, 970, 967, 963, 959, 955, 951, 947])
	load_world(flat_rows())
	rows = run(flags_of([[3, ""], [1, "U"], [20, "L"]]))
	assert_ints_eq(column(rows, "xvel"), [0, 0, 0, 0, -32, -64, -80, -80, -80, -80, -80, -80, -80, -80, -80, -80,
			-80, -80, -80, -80, -80, -80, -80, -80], "normal ground: 32 v16 per tick in the air")


# --- Wind (PHYSICS.md 13.1: WIND calls per tick: idle 1, 2 airborne late in a jump, walk 1, jump 2, hurt 1, ---------
# --- crouch / crawl / strike 0) ------------------------------------------------------------------------------------

func test_wind_calls_per_state() -> void:
	var strong: String = "wind = 1:128"
	load_world(flat_rows(), START_CELL, 0, strong)
	assert_eq(level.wind, 128, "the level's wind script blows from tick 1")
	var rows: Array[Dictionary] = run(hold("", 12))
	assert_ints_eq(column(rows, "xvel"), [-4, -8, -12, -16, -20, -24, -28, -32, -36, -40, -44, -48],
			"standing: WIND 16 then FRICTION 12 per tick")
	assert_ints_eq(column(rows, "x"), [999, 998, 997, 996, 994, 992, 990, 988, 985, 982, 979, 976])
	load_world(flat_rows(), START_CELL, 0, "wind = 1:64")
	rows = run(hold("", 12))
	assert_eq(column(rows, "x").count(START_X), 12, "a wind below 12 v16 per call cannot move a standing hero")
	load_world(flat_rows(), START_CELL, 0, strong)
	rows = run(hold("D", 12))
	assert_eq(column(rows, "x").count(START_X), 12, "crouching is immune to wind")
	load_world(flat_rows(), START_CELL, 0, strong)
	rows = run(hold("RD", 12))
	assert_ints_eq(column(rows, "x"), [1001, 1003, 1005, 1007, 1009, 1011, 1013, 1015, 1017, 1019, 1021, 1023],
			"crawling is immune to wind")
	load_world(flat_rows(), START_CELL, 0, strong)
	rows = run(hold("R", 12))
	assert_eq(column(rows, "x").count(START_X), 12, "walking: ACCEL 16 and one WIND 16 cancel out")
	load_world(flat_rows(), START_CELL, 0, strong)
	rows = run(hold("F", 7))
	assert_eq(column(rows, "xvel").count(0), 7, "striking: no WIND")
	load_world(flat_rows(), START_CELL, 0, strong)
	hero.hurt(null, Defs.HurtKind.ENEMY)
	hero.hit_timer -= 1
	rows = run(hold("", 17))
	assert_ints_eq(column(rows, "xvel"), [-4, -8, -12, -16, -20, -24, -28, -32, -36, -40, -44, -48, -52, -56, -60, -64,
			-68], "hurt: one WIND per tick")
	load_world(flat_rows(), START_CELL, 0, strong)
	rows = run(flags_of([[1, "U"], [11, ""]]))
	assert_ints_eq(column(rows, "xvel"), [-32, -36, -40, -44, -48, -52, -56, -60, -64, -68, -72, -76],
			"jump: two WIND calls, then one per airborne idle tick while jump_ticks <= 4")
	load_world(flat_rows(), START_CELL, 0, "wind = 1:32")
	rows = run(flags_of([[6, "U"], [18, ""]]))
	assert_ints_eq(column(rows, "xvel"), [-8, -8, -8, -8, -8, -8, -4, -4, -4, -4, -4, -4, -4, -4, -4, -4, -4, -4, -4, -4,
			-4, -4, -4, -4], "airborne idle after more than 4 jump ticks: a second WIND")
	assert_eq(int(rows[23]["x"]), 976)


# --- Ceilings, deadly tiles (PHYSICS.md 11.2 #4, #5, #7) ----------------------------------------------------------

func test_running_jump_head_bumps() -> void:
	var lines: PackedStringArray = flat_rows()
	put(lines, 40, GROUND_ROW - 4, "#".repeat(60))
	load_world(lines)
	set_running(1)
	var rows: Array[Dictionary] = run(hold("RU", 24))
	assert_ints_eq(column(rows, "y"), [315, 308, 304, 305, 307, 310, 314, 319, 320, 320, 320, 320, 320, 320, 315, 308,
			304, 305, 307, 310, 314, 319, 320, 320], "ceiling 48 px up: bump on tick 3, pushed to the row boundary")
	assert_ints_eq(column(rows, "yvel"), [-49, -84, 16, 32, 48, 64, 80, 96, 0, 0, 0, 0, 0, 0, -49, -84, 16, 32, 48,
			64, 80, 96, 0, 0])
	assert_ints_eq(column(rows, "x"), [1004, 1008, 1012, 1016, 1020, 1024, 1028, 1032, 1036, 1039, 1041, 1043, 1044,
			1044, 1045, 1048, 1051, 1054, 1057, 1061, 1065, 1069, 1073, 1076])
	lines = flat_rows()
	put(lines, 40, GROUND_ROW - 3, "#".repeat(60))
	load_world(lines)
	set_running(1)
	rows = run(hold("RU", 24))
	assert_eq(column(rows, "y").count(320), 24, "ceiling 32 px up: every jump is stopped on its first tick")
	assert_ints_eq(column(rows, "yvel"), [16, 0, 0, 0, 0, 0, 0, 16, 0, 0, 0, 0, 0, 0, 16, 0, 0, 0, 0, 0, 0, 16, 0, 0])
	assert_ints_eq(column(rows, "x"), [1004, 1008, 1011, 1013, 1015, 1016, 1016, 1017, 1018, 1019, 1019, 1019, 1019,
			1019, 1020, 1021, 1021, 1021, 1021, 1021, 1021, 1022, 1023, 1023])


## Inside a wall tile (a moving platform or a gate exit can put him there) he is slid out 2 px per tick, also
## while standing (the ceiling block runs with yvel <= 0).
func test_corner_slip_out_of_a_wall() -> void:
	var lines: PackedStringArray = flat_rows()
	for row: int in GROUND_ROW:
		put(lines, 62, row, "|")
	load_world(lines, Vector2i(20, GROUND_ROW - 1))
	place_hero(START)
	var rows: Array[Dictionary] = run(hold("", 6))
	assert_ints_eq(column(rows, "x"), [1002, 1004, 1006, 1008, 1008, 1008])


func test_deadly_and_solid_ceilings_over_a_standing_hero() -> void:
	var lines: PackedStringArray = flat_rows()
	put(lines, 62, GROUND_ROW - 2, "#")
	load_world(lines)
	var rows: Array[Dictionary] = run(hold("", 10))
	assert_eq(column(rows, "y").count(320), 10, "a solid ceiling does nothing while yvel == 0")
	assert_eq(death_ticks.size(), 0)
	lines = flat_rows()
	put(lines, 62, GROUND_ROW - 2, "!")
	load_world(lines)
	run(hold("", 3))
	assert_eq(death_ticks, PackedInt32Array([1]), "ceiling spikes kill a standing hero on the first tick")


func test_deadly_floor_and_side_tiles() -> void:
	var lines: PackedStringArray = flat_rows()
	put(lines, 64, GROUND_ROW, "^")
	load_world(lines)
	run(hold("R", 10))
	assert_eq(death_ticks, PackedInt32Array([7]), "spikes: the tick the feet point enters column 64 (x 1025)")
	lines = flat_rows()
	put(lines, 66, GROUND_ROW - 1, "~")
	load_world(lines)
	run(hold("R", 14))
	assert_eq(death_ticks, PackedInt32Array([12]), "deadly side: the 9 px wall probe reaches column 66 at x 1050")


# --- Ledges and the lock-out (PHYSICS.md 6.4, 6.5) --------------------------------------------------------------

func test_ledge_walk_off_has_no_coyote_time() -> void:
	load_world(ledge_rows(70, 1))
	place_hero(Vector2i(70 * 16 - 5, START.y))
	set_running(1)
	var rows: Array[Dictionary] = run(flags_of([[1, "R"], [14, "RU"]]))
	assert_ints_eq(column(rows, "handler"), [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 2, 2],
			"UP from the tick after the floor was lost: idle until 6 grounded ticks have passed")
	assert_ints_eq(column(rows, "no_jump"), [6, 6, 6, 6, 6, 6, 5, 4, 3, 2, 1, 0, 0, 0, 0])
	assert_ints_eq(column(rows, "y"), [320, 321, 323, 326, 330, 335, 336, 336, 336, 336, 336, 336, 331, 324, 316])
	assert_ints_eq(column(rows, "x"), [1120, 1124, 1128, 1132, 1136, 1140, 1144, 1147, 1149, 1151, 1152, 1152, 1153,
			1156, 1159], "the held direction brakes during the lock-out")


func test_hard_landing_rearms_the_lockout() -> void:
	load_world(ledge_rows(70, 4))
	place_hero(Vector2i(70 * 16 - 5, START.y))
	set_running(1)
	var rows: Array[Dictionary] = run(flags_of([[1, "R"], [30, "U"]]))
	assert_ints_eq(column(rows, "y"), [320, 321, 323, 326, 330, 335, 341, 348, 356, 365, 375, 384, 382, 381, 381,
			382, 384, 384, 384, 384, 384, 384, 379, 372, 364, 356, 348, 341, 335, 330, 326],
			"hard landing on tick 12, 3 px hop, soft touchdown on tick 17, next jump on tick 23")
	assert_ints_eq(column(rows, "yvel"), [16, 32, 48, 64, 80, 96, 112, 128, 144, 160, 176, -32, -16, 0, 16, 32, 0, 0,
			0, 0, 0, 0, -49, -84, -103, -107, -101, -90, -76, -61, -45])
	assert_ints_eq(column(rows, "no_jump"), [6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 5, 4, 3, 2, 1, 0, 0, 0,
			0, 0, 0, 0, 0, 0, 0])
	assert_eq(landing_ticks, PackedInt32Array([12, 17]))
	assert_eq(landing_hard, [true, false] as Array[bool])


# --- Hurt by a real enemy contact (PHYSICS.md 9, 10.1, 10.2) ------------------------------------------------------

## A standing hero inside a tall enemy: hit on tick 2 (the enemy is first drawn on tick 1), contact skipped for
## 43 ticks, hit again 44 ticks later; the fourth hit at 0 hearts kills.
func test_enemy_contact_immunity_and_fourth_hit() -> void:
	load_world(flat_rows())
	add_dummy(START, Vector2i(32, 64))
	var ref: Dictionary = load_reference()["hurt"]["standing"]
	var rows: Array[Dictionary] = run(hold("", 140))
	assert_eq(hurt_ticks, PackedInt32Array([2, 46, 90, 134]), "contact hits 44 ticks apart")
	assert_eq(death_ticks, PackedInt32Array([134]), "the fourth hit kills")
	assert_ints_eq(heights(rows.slice(2, 19), START.y), ref["height"], "knock-up after a real contact")
	var stunned: Array = []
	for i: int in range(2, 46):
		if int(rows[i]["state"]) == Defs.HeroState.HURT:
			stunned.append(i + 1)
	assert_eq(stunned.size(), 22, "22 stunned ticks")
	assert_eq(int(stunned[0]), 3)
	assert_eq(int(rows[45]["hit_timer"]), Tuning.HIT_TIMER - 1, "hit again on tick 46")
	assert_eq(int(rows[44]["hit_timer"]), 0, "immunity over at the end of tick 45")


func test_running_into_an_enemy_knocks_back() -> void:
	var ref: Dictionary = load_reference()["hurt"]
	for direction: int in [1, -1]:
		load_world(flat_rows())
		add_dummy(Vector2i(START_X + direction * 100, START.y), Vector2i(16, 16))
		set_running(direction)
		var contact: int = 19 if direction > 0 else 18
		var rows: Array[Dictionary] = run(flags_of([[contact, KEY_OF[direction]], [30, ""]]))
		assert_eq(hurt_ticks, PackedInt32Array([contact]), "body contact on tick %d" % contact)
		var expected: Dictionary = ref["moving_right" if direction > 0 else "moving_left"]
		var hit_x: int = int(rows[contact - 1]["x"])
		var after: Array[Dictionary] = rows.slice(contact, contact + 17)
		assert_ints_eq(rel_x(after, hit_x), expected["x"], "knock-back x after the contact")
		assert_ints_eq(heights(after, START.y), expected["height"], "knock-up after the contact")


# --- Strikes against a real enemy (PHYSICS.md 8.1 - 8.5, 9) -----------------------------------------------------

func test_forward_strike_active_ticks_and_pogo() -> void:
	load_world(flat_rows())
	add_dummy(Vector2i(START_X + 30, START.y), Vector2i(16, 16), 1000, false)
	var rows: Array[Dictionary] = run(flags_of([[7, "F"], [16, ""]]))
	assert_eq(hit_log, [Vector2i(6, 25), Vector2i(7, 25), Vector2i(8, 25)] as Array[Vector2i],
			"front boxes of ticks 5-7 hit on ticks 6-8")
	assert_ints_eq(column(rows, "y"), [320, 320, 320, 320, 320, 320, 318, 313, 309, 306, 304, 303, 303, 304, 306, 309,
			313, 318, 320, 320, 320, 320, 320], "the box of the hop tick pogoes (yvel -80 on tick 8)")
	assert_ints_eq(column(rows, "yvel"), [0, 0, 0, 0, 0, 0, -16, -64, -48, -32, -16, 0, 16, 32, 48, 64, 80, 96, 0, 0,
			0, 0, 0])


func test_high_strike_active_ticks() -> void:
	load_world(flat_rows())
	add_dummy(Vector2i(START_X + 18, START.y - 30), Vector2i(16, 16), 1000, false)
	var rows: Array[Dictionary] = run(flags_of([[9, "UF"], [6, ""]]))
	assert_eq(hit_log, [Vector2i(8, 25), Vector2i(9, 25), Vector2i(10, 25)] as Array[Vector2i])
	assert_eq(column(rows, "y").count(320), 15, "the high strike has no hop, so no pogo")


func test_low_strike_active_ticks_and_pogo() -> void:
	load_world(flat_rows())
	add_dummy(Vector2i(START_X + 16, START.y), Vector2i(16, 8), 1000, false)
	var rows: Array[Dictionary] = run(flags_of([[9, "DF"], [18, ""]]))
	assert_eq(hit_log, [Vector2i(8, 25), Vector2i(9, 25), Vector2i(10, 25)] as Array[Vector2i])
	assert_ints_eq(column(rows, "y"), [320, 320, 320, 320, 320, 320, 320, 320, 317, 312, 308, 305, 303, 302, 302, 303,
			305, 308, 312, 317, 320, 320, 320, 320, 320, 320, 320])
	assert_ints_eq(column(rows, "yvel"), [0, 0, 0, 0, 0, 0, 0, 0, -32, -64, -48, -32, -16, 0, 16, 32, 48, 64, 80, 96,
			0, 0, 0, 0, 0, 0, 0])


func test_wind_up_boxes_hit_behind() -> void:
	load_world(flat_rows())
	add_dummy(Vector2i(START_X - 12, START.y), Vector2i(16, 20), 1000, false)
	run(hold("F", 7))
	assert_eq(hit_log, [Vector2i(2, 25), Vector2i(3, 25)] as Array[Vector2i], "wind-up boxes of ticks 1-2")


func test_charge_build_up_and_charged_hits() -> void:
	load_world(flat_rows())
	var rows: Array[Dictionary] = run(hold("D", 60))
	var expected: Array = []
	for k: int in range(1, 61):
		expected.append(k if k <= 49 else (48 if (k & 1) == 0 else 49))
	assert_ints_eq(column(rows, "charge"), expected, "+1 net per crouched tick, saturating at 48 / 49")
	load_world(flat_rows())
	add_dummy(Vector2i(START_X + 30, START.y), Vector2i(16, 16), 1000, false)
	run(flags_of([[5, "D"], [7, "F"], [2, ""]]))
	assert_eq(hit_log, [Vector2i(11, 100), Vector2i(12, 25), Vector2i(13, 25)] as Array[Vector2i],
			"5 crouched ticks: only the first front box is charged")


# --- Enemy bounces (PHYSICS.md 9) ---------------------------------------------------------------------------------

func test_enemy_bounce_with_and_without_up() -> void:
	for up: bool in [false, true]:
		load_world(flat_rows())
		var enemy: EnemyBase = add_dummy(START, Vector2i(32, 16))
		place_hero(Vector2i(START_X, START.y - 100))
		# UP is pressed only once he is falling: held from the start it would jump in mid-air (PHYSICS.md 6.1).
		var rows: Array[Dictionary] = run(flags_of([[13, ""], [67, "U" if up else ""]]))
		var label: String = "bounce with UP" if up else "bounce without UP"
		assert_eq(hurt_ticks.size(), 0, label + ": never hurt")
		assert_true(bounce_ticks.size() >= 2, label + ": keeps bouncing")
		if bounce_ticks.size() < 2:
			continue
		assert_eq(bounce_ticks[0], 14, label + ": falling at 12 px per tick he lands on the head on tick 14")
		var top: int = enemy.sim_pos.y - enemy.box_h
		var bounce_yvel: int = Tuning.BOUNCE_YVEL_UP if up else Tuning.BOUNCE_YVEL
		var first: Dictionary = rows[13]
		assert_eq(int(first["y"]), top, label + ": lifted by the depth onto the head")
		assert_eq(int(first["yvel"]), bounce_yvel)
		assert_eq(int(first["fall_ticks"]), 0)
		# From the head: y += floor16(yvel), then gravity (PHYSICS.md 2, 6.2), until he is below the head again.
		var want: Array = []
		var y: int = top
		var v: int = bounce_yvel
		while y <= top:
			y += Tuning.floor16(v)
			v = mini(v + Tuning.GRAVITY, Tuning.TERMINAL)
			want.append(y)
		var period: int = want.size()
		assert_eq(bounce_ticks[1], 14 + period, label + ": next bounce")
		var got: Array = column(rows.slice(14, 14 + period - 1), "y")
		want.resize(period - 1)
		assert_ints_eq(got, want, label + ": flight between bounces")
		assert_eq(top - int(column(rows.slice(14, 14 + period), "y").min()), 105 if up else 10, label + ": rise")


# --- State overrides during a strike (PHYSICS.md 4.2, 4.3 overrides 1 and 4, 8.1) ----------------------------------

func test_switching_strike_type_restarts_the_script() -> void:
	load_world(flat_rows())
	var rows: Array[Dictionary] = run(flags_of([[3, "F"], [10, "UF"]]))
	assert_ints_eq(column(rows, "handler"), [3, 3, 3, 6, 6, 6, 6, 6, 6, 6, 6, 6, 0])
	assert_eq(column(rows, "club"), ["fwd_windup", "fwd_windup", "overhead", "high_lowback", "high_lowback",
			"high_lowback", "high_backup", "high_backup", "high_backup", "high_front", "high_front", "high_front", ""])


func test_movement_input_cannot_interrupt_a_strike() -> void:
	load_world(flat_rows())
	var rows: Array[Dictionary] = run(flags_of([[3, "F"], [8, "R"]]))
	assert_ints_eq(column(rows, "state"), [3, 3, 3, 1, 1, 1, 1, 0, 1, 1, 1], "walk selected, strike handler runs")
	assert_ints_eq(column(rows, "handler"), [3, 3, 3, 3, 3, 3, 3, 0, 1, 1, 1])
	assert_eq(column(rows, "club"), ["fwd_windup", "fwd_windup", "overhead", "overhead", "fwd_front", "fwd_front",
			"fwd_front", "", "", "", ""])
	assert_ints_eq(column(rows, "xvel"), [0, 0, 0, 0, 0, 0, 16, 20, 52, 80, 80],
			"held RIGHT still feeds the airborne ACCEL during the hop and the swing lock")
	assert_ints_eq(column(rows, "x"), [1000, 1000, 1000, 1000, 1000, 1000, 1000, 1000, 1002, 1006, 1011])


func test_facing_flips_mid_swing() -> void:
	load_world(flat_rows())
	var rows: Array[Dictionary] = run(flags_of([[3, "F"], [5, "LF"]]))
	assert_ints_eq(column(rows, "facing"), [1, 1, 1, -1, -1, -1, -1, -1])
	assert_eq(column(rows, "club"), ["fwd_windup", "fwd_windup", "overhead", "overhead", "fwd_front", "fwd_front",
			"fwd_front", ""], "the script continues")
	var boxes: Array = column(rows, "club_rel")
	assert_ints_eq(boxes[2], [-19, 5, -43, -25], "overhead, facing right")
	assert_ints_eq(boxes[3], [-5, 19, -43, -25], "overhead, mirrored")
	assert_ints_eq(boxes[4], [-35, -11, -15, -2], "front box behind the old facing")


func test_swing_lock_ignores_the_state_table_not_air_control() -> void:
	load_world(flat_rows())
	var rows: Array[Dictionary] = run(flags_of([[7, "F"], [6, "R"]]))
	assert_ints_eq(column(rows, "state"), [3, 3, 3, 3, 3, 3, 3, 0, 1, 1, 1, 1, 1], "tick 8: swing lock, state 0")
	assert_ints_eq(column(rows, "xvel"), [0, 0, 0, 0, 0, 0, 0, 16, 48, 80, 80, 80, 80])
	assert_ints_eq(column(rows, "x"), [1000, 1000, 1000, 1000, 1000, 1000, 1000, 1000, 1002, 1006, 1011, 1016, 1021])
	assert_ints_eq(column(rows, "y"), [320, 320, 320, 320, 320, 320, 318, 317, 317, 318, 320, 320, 320])


## Releasing and re-pressing UP while still rising continues the impulse table (PHYSICS.md 6.1).
func test_repressing_up_while_rising_continues_the_impulses() -> void:
	load_world(flat_rows())
	var rows: Array[Dictionary] = run(flags_of([[2, "U"], [1, ""], [5, "U"], [20, ""]]))
	assert_ints_eq(column(rows, "jump_ticks"), [1, 2, 2, 3, 4, 5, 6, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 0,
			0, 0, 0, 0])
	assert_ints_eq(column(rows, "yvel"), [-49, -84, -68, -87, -91, -85, -74, -60, -44, -28, -12, 4, 20, 36, 52, 68,
			84, 100, 116, 132, 148, 164, 180, 0, 0, 0, 0, 0])
	assert_ints_eq(column(rows, "y"), [315, 308, 302, 295, 288, 281, 275, 270, 266, 263, 261, 260, 260, 261, 263, 266,
			270, 275, 281, 288, 296, 305, 315, 320, 320, 320, 320, 320])


## Levels with scroll flag bit 0 (`low_band`): a hard landing gives no hop; he settles one tick later.
func test_low_band_hard_landing_has_no_hop() -> void:
	load_world(ledge_rows(70, 4), START_CELL, 0, "low_band = true")
	assert_eq(level.scroll_flags & Defs.SCROLL_LOW_BAND, Defs.SCROLL_LOW_BAND)
	place_hero(Vector2i(70 * 16 - 5, START.y))
	set_running(1)
	var rows: Array[Dictionary] = run(hold("", 20))
	assert_ints_eq(column(rows, "y"), [320, 320, 321, 323, 326, 330, 335, 341, 348, 356, 365, 375, 384, 384, 384, 384,
			384, 384, 384, 384])
	assert_ints_eq(column(rows, "yvel"), [0, 16, 32, 48, 64, 80, 96, 112, 128, 144, 160, 176, 176, 0, 0, 0, 0, 0, 0,
			0])
	assert_ints_eq(column(rows, "no_jump"), [0, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 5, 4, 3, 2, 1, 0, 0])


# --- Platforms (PHYSICS.md 11.4, 11.2 #6: the hero side of the ride) -----------------------------------------------

## A static platform (bottom 340, 8 px high, so the top is 332) over empty air: he falls onto it, the ride test
## puts his feet at top + 1 with yvel 1, the tile collision then applies no gravity and does the grounded
## bookkeeping (no_jump goes down twice per tick: ride test and collision), the strike hop is skipped, and a
## jump leaves it.
func test_landing_on_striking_on_and_jumping_off_a_platform() -> void:
	load_world(flat_rows(23))
	var platform: PlatformBase = PlatformBase.new()
	platform.spawn_setup(Vector2i(START_X, 340), {})
	level.get_container("objects").add_child(platform)
	place_hero(Vector2i(START_X, 260))
	var rows: Array[Dictionary] = run(hold("", 20))
	assert_ints_eq(column(rows, "y"), [260, 261, 263, 266, 270, 275, 281, 288, 296, 305, 315, 326, 338, 333, 333, 333,
			333, 333, 333, 333], "feet 6 px into the platform after tick 13, then on top + 1")
	assert_ints_eq(column(rows, "yvel"), [16, 32, 48, 64, 80, 96, 112, 128, 144, 160, 176, 192, 192, 1, 1, 1, 1, 1, 1,
			1])
	assert_ints_eq(column(rows, "no_jump"), [6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 4, 2, 0, 0, 0, 0, 0])
	assert_ints_eq(column(rows, "fall_ticks"), [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 0, 0, 0, 0, 0, 0, 0])
	assert_eq(column(rows, "grounded").slice(13).count(1), 7, "riding counts as grounded")
	assert_true(hero.on_platform)
	rows = run(hold("F", 7))
	assert_eq(column(rows, "y").count(333), 7, "no strike hop on a platform")
	assert_eq(column(rows, "yvel").count(1), 7)
	rows = run(flags_of([[2, ""], [1, "U"], [12, ""]]))
	assert_ints_eq(column(rows, "y"), [333, 333, 329, 326, 324, 323, 323, 324, 326, 329, 333, 333, 333, 333, 333],
			"tap jump from yvel 1: -64 on the first tick")
	assert_ints_eq(column(rows, "yvel"), [1, 1, -48, -32, -16, 0, 16, 32, 48, 64, 80, 1, 1, 1, 1])
	assert_false(bool(rows[2]["grounded"]), "jumping clears on_platform")


## A moving platform (the objects module's mover) carries him by exactly its own movement every tick.
func test_moving_platform_carries_the_hero() -> void:
	load_world(flat_rows(23))
	var mover: PlatformBase = level.spawn(&"objects/platform", Vector2i(START_X, 340), {
		"dir": 2, "speed": 2, "travel": 22, "mode": "always",
	}) as PlatformBase
	assert_not_null(mover)
	if mover == null:
		return
	place_hero(Vector2i(START_X, mover.sim_pos.y - mover.box_h + 1))
	run(hold("", 1))
	var problem: String = ""
	var moved_right: bool = false
	var moved_left: bool = false
	for i: int in 80:
		var before: int = hero.sim_pos.x
		run(hold("", 1))
		var top: int = mover.sim_pos.y - mover.box_h
		if problem.is_empty() and (hero.sim_pos.x - before != mover.dx or not hero.on_platform
				or hero.sim_pos.y != top + 1 or hero.yvel != 1):
			problem = "tick %d: hero dx %d, platform dx %d, on_platform %s, y %d (top %d), yvel %d" % [
				Sim.tick, hero.sim_pos.x - before, mover.dx, hero.on_platform, hero.sim_pos.y, top, hero.yvel,
			]
		moved_right = moved_right or mover.dx > 0
		moved_left = moved_left or mover.dx < 0
	assert_true(moved_right and moved_left, "the mover went both ways")
	assert_eq(problem, "", "x += platform dx, feet on top + 1, yvel 1 on every tick")


# --- Hang-glider (PHYSICS.md 13.2) --------------------------------------------------------------------------------

func test_glider_carried_on_the_ground() -> void:
	load_world(flat_rows())
	hero.set_glider(true)
	var rows: Array[Dictionary] = run(hold("U", 13))
	# Halved impulses -33, -26, -18, -10, -5, -3, -1, -1, 0; the glider jump ignores the lock-out.
	assert_ints_eq(column(rows, "yvel"), [-17, -27, -29, -23, -12, 1, 16, 31, 47, 79, 111, 0, -17])
	assert_ints_eq(column(rows, "y"), [317, 314, 311, 308, 306, 305, 305, 305, 306, 309, 314, 320, 317])
	load_world(flat_rows())
	hero.set_glider(true)
	rows = run(hold("F", 5))
	assert_ints_eq(column(rows, "state"), [3, 3, 3, 3, 3])
	assert_ints_eq(column(rows, "handler"), [5, 5, 5, 5, 5], "strikes run the crouch handler")
	assert_eq(column(rows, "club"), ["", "", "", "", ""], "no club box")
	assert_ints_eq(column(rows, "charge"), [1, 2, 3, 4, 5])


func test_glider_take_off_climb_and_glide() -> void:
	load_world(flat_rows())
	hero.set_glider(true)
	var rows: Array[Dictionary] = run(flags_of([[28, "R"], [2, "RU"], [24, ""]]))
	assert_eq(int(rows[27]["y"]), START.y, "still walking on tick 28 (run-up counted from tick 5: |xvel| >= 64)")
	assert_eq(int(rows[28]["y"]), START.y - 3, "take-off on tick 29: y - 3")
	assert_eq(int(rows[28]["yvel"]), Tuning.GLIDE_GRAVITY, "glide gravity")
	assert_ints_eq(column(rows, "y").slice(29), [313, 309, 305, 301, 298, 295, 292, 289, 287, 285, 283, 281, 280, 279,
			278, 277, 277, 277, 277, 277, 278, 279, 280, 281, 282], "climb at -64 while UP, then +4 per tick")
	assert_ints_eq(column(rows, "yvel").slice(29), [-60, -56, -52, -48, -44, -40, -36, -32, -28, -24, -20, -16, -12,
			-8, -4, 0, 4, 8, 12, 16, 20, 24, 24, 24, 24], "sink capped at 24 v16")
	assert_eq(column(rows, "xvel").slice(28).count(Tuning.WALK_CAP), 26, "no friction while gliding")
	assert_true(hero.is_gliding())


# --- Screen-shake nudge (PHYSICS.md 13.3) -------------------------------------------------------------------------

## The 12-tile golden trace, this time with step 18: on odd ticks while shake > 1 the standing hero is lifted 3 px
## (he falls back and lands again), except in the crouch state.
func test_shake_nudge_after_a_heavy_landing() -> void:
	var keys: Array = [[9, "R"], [6, "L"], [5, "RU"], [10, "R"], [20, ""]]
	load_world(ledge_rows(64, 12))
	var rows: Array[Dictionary] = run(flags_of(keys))
	assert_ints_eq(column(rows, "y").slice(28), [509, 507, 503, 503, 501, 503, 503, 507, 509, 509, 507, 509, 512, 512,
			512, 512, 512, 512, 512, 512, 512, 512], "nudged on ticks 29, 31, 33, 35, 37, 39")
	assert_ints_eq(column(rows, "yvel").slice(28), [-32, -16, 0, 16, 32, 48, 64, 80, 0, 16, 32, 48, 0, 0, 0, 0, 0, 0,
			0, 0, 0, 0])
	keys[4] = [20, "D"]
	load_world(ledge_rows(64, 12))
	rows = run(flags_of(keys))
	assert_ints_eq(column(rows, "y").slice(28), [509, 507, 506, 506, 507, 509, 512, 512, 512, 512, 512, 512, 512, 512,
			512, 512, 512, 512, 512, 512, 512, 512], "crouching: only the landing tick (still state 1) is nudged")
	keys[4] = [20, "RD"]
	load_world(ledge_rows(64, 12))
	rows = run(flags_of(keys))
	assert_eq(int(rows[30]["state"]), Defs.HeroState.CRAWL)
	assert_ints_eq(column(rows, "y").slice(28), [509, 507, 503, 503, 501, 503, 503, 507, 509, 509, 507, 509, 512, 512,
			512, 512, 512, 512, 512, 512, 512, 512], "crawling does not resist the nudge (PHYSICS.md 7)")
	assert_ints_eq(column(rows, "x").slice(28), [1079, 1084, 1088, 1092, 1096, 1100, 1104, 1108, 1112, 1115, 1118,
			1122, 1126, 1129, 1131, 1133, 1135, 1137, 1139, 1141, 1143, 1145])


# --- Helpers ------------------------------------------------------------------------------------------------------

func _load_hill() -> void:
	var lines: PackedStringArray = flat_rows()
	put(lines, 64, GROUND_ROW - 1, HILL[0])
	put(lines, 65, GROUND_ROW - 2, HILL[1])
	load_world(lines)
