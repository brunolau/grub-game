extends PlayerTestCase
## Vines and the CLIMB state (docs/spec/PHYSICS.md C.4) and the tar floor (C.5) with the real hero: the grab test,
## climbing up and down, the top step, the leap and the drop with their re-grab lock (the leap pinned against
## docs/spec/PARTY_REFERENCE.json "vine_leap"), what a hurt or a shake does to a climber; wading, the tar hop (pinned
## against "tar_hop"), walking out of tar.

const PARTY_REFERENCE_PATH: String = "res://docs/spec/PARTY_REFERENCE.json"
## The vine column of the worlds below and its x.
const VINE_COL: int = 64
const VINE_X: int = VINE_COL * 16 + 8


## A vine as objects-B's Vine answers it (duck typing: is_climbable, vine_x, top, bottom).
class FakeVine:
	extends SimEntity

	var vine_x: int = 0
	var top: int = 0
	var bottom: int = 0
	var rolled: bool = false

	func is_climbable() -> bool:
		return not rolled


static var _party_reference: Dictionary = {}


static func party_reference() -> Dictionary:
	if _party_reference.is_empty():
		var json: JSON = JSON.new()
		if json.parse(FileAccess.get_file_as_string(PARTY_REFERENCE_PATH)) == OK and json.data is Dictionary:
			_party_reference = json.data
	return _party_reference


## Ground from row 20; with `ledge` a block of solid cells from column VINE_COL + 1 and row 12 (top surface y 192)
## beside the vine; `ceiling_row` >= 0 puts a solid cell in the vine's column on that row.
func vine_world(ledge: bool, ceiling_row: int = -1) -> FollowLevel:
	var rows: PackedStringArray = PackedStringArray()
	for row: int in GROUND_ROW + WORLD_ROWS_BELOW:
		var line: String = ""
		for col: int in WORLD_COLS:
			var solid: bool = row >= GROUND_ROW or (ledge and col > VINE_COL and row >= 12)
			if row == ceiling_row and col == VINE_COL:
				solid = true
			line += TileGrid.CH_SOLID_A if solid else TileGrid.CH_AIR
		rows.append(line)
	return world_rows(rows)


## A vine at VINE_X from `top` to `bottom`, placed before the hero (so his setup finds it).
func add_vine(top: int, bottom: int, rolled: bool = false) -> FakeVine:
	var vine: FakeVine = FakeVine.new()
	vine.vine_x = VINE_X
	vine.top = top
	vine.bottom = bottom
	vine.rolled = rolled
	place(level, vine, Vector2i(VINE_X, top))
	return vine


## A world with tar from column `first_col` to `last_col` on the ground row, solid ground elsewhere.
func tar_world(first_col: int, last_col: int) -> FollowLevel:
	var rows: PackedStringArray = PackedStringArray()
	for row: int in GROUND_ROW + WORLD_ROWS_BELOW:
		var line: String = ""
		for col: int in WORLD_COLS:
			if row == GROUND_ROW and col >= first_col and col <= last_col:
				line += TileGrid.CH_TAR
			elif row >= GROUND_ROW:
				line += TileGrid.CH_SOLID_A
			else:
				line += TileGrid.CH_AIR
		rows.append(line)
	return world_rows(rows)


# =================================================================================================================
# Vines
# =================================================================================================================

func test_book1_hero_has_no_climb_component() -> void:
	world_flat()
	spawn_hero()
	assert_false(hero.hero_climb.active, "no vine and no tar: off")
	vine_world(true)
	add_vine(192, 320)
	spawn_hero()
	assert_true(hero.hero_climb.active, "a level with a vine switches it on")


func test_up_next_to_a_vine_climbs_instead_of_jumping() -> void:
	vine_world(true)
	add_vine(192, 320)
	spawn_hero(Vector2i(VINE_X + 6, 320))
	play(hold("U", 1))
	assert_true(hero.hero_climb.climbing, "grabbed")
	assert_eq(hero.state, Defs.HeroState.CLIMB)
	assert_eq(hero.sim_pos, Vector2i(VINE_X, 320), "x snaps to the vine, no motion on the grab tick")
	assert_eq([hero.xvel, hero.yvel, hero.jump_ticks, hero.fall_ticks], [0, 0, 0, 0])
	var ys: Array[int] = []
	play(hold("U", 5), func(_t: int) -> void: ys.append(hero.sim_pos.y))
	assert_ints_eq(ys, [318, 316, 314, 312, 310], "2 px per tick up")
	ys.clear()
	play(hold("D", 3), func(_t: int) -> void: ys.append(hero.sim_pos.y))
	assert_ints_eq(ys, [313, 316, 319], "3 px per tick down")
	ys.clear()
	play(hold("", 3) + hold("F", 3) + hold("K", 2) + hold("L", 2), func(_t: int) -> void: ys.append(hero.sim_pos.y))
	assert_ints_eq(ys, [319, 319, 319, 319, 319, 319, 319, 319, 319, 319], "hang: nothing, FIRE, LOOK, a direction")
	assert_eq(hero.facing, -1, "a direction alone turns him")
	assert_false(hero.club_box_active, "no strikes on a vine")
	assert_true(hero.hero_climb.climbing)
	play(hold("D", 1))
	assert_false(hero.hero_climb.climbing, "down onto the floor: he lands")
	assert_eq(hero.sim_pos.y, 320)
	assert_true(hero.grounded)
	assert_eq(hero.state, Defs.HeroState.IDLE)
	assert_eq(hero.hero_climb.climb_px, 10 + 9 + 3, "every px climbed counts for the climb frames")


func test_the_grab_test() -> void:
	vine_world(false)
	add_vine(192, 280)
	spawn_hero(Vector2i(VINE_X + 7, 320))
	play(hold("U", 1))
	assert_false(hero.hero_climb.climbing, "7 px from the vine: too far")
	assert_eq(hero.handler, Defs.HeroState.JUMP, "so UP jumps")
	vine_world(false)
	add_vine(192, 287)
	spawn_hero(Vector2i(VINE_X, 320))
	play(hold("U", 1))
	assert_false(hero.hero_climb.climbing, "his hands (feet - 32 = 288) do not reach a vine ending at 287")
	vine_world(false)
	add_vine(192, 288)
	spawn_hero(Vector2i(VINE_X, 320))
	play(hold("U", 1))
	assert_true(hero.hero_climb.climbing, "a vine ending at 288 is in reach")
	vine_world(false)
	add_vine(320, 400)
	spawn_hero(Vector2i(VINE_X, 320))
	play(hold("U", 1))
	assert_false(hero.hero_climb.climbing, "y must be below the vine's top (y > top)")
	for blocker: String in ["none", "glider", "strike", "stun", "rolled", "egg", "curl"]:
		vine_world(false)
		add_vine(192, 320, blocker == "rolled")
		spawn_hero(Vector2i(VINE_X, 300))
		match blocker:
			"glider":
				hero.run.set_glider(true)
			"strike":
				hero.attack_gate = true
			"stun":
				hero.hit_timer = Tuning.HIT_STUN_MIN
			"curl":
				hero.curl = PlayerBase.CURL_CURLED
			"egg":
				hero.down = true
		var grabs: bool = hero.hero_climb.can_grab(level) and hero.hero_climb.find_vine(VINE_X, 300) != null
		assert_eq(grabs, blocker == "none", "grab with %s" % blocker)
		hero.down = false
		hero.curl = PlayerBase.CURL_NONE
		hero.attack_gate = false
		hero.hit_timer = 0
		if blocker == "glider":
			hero.run.set_glider(false)


func test_holding_up_while_jumping_past_a_vine_grabs_it() -> void:
	vine_world(false)
	add_vine(96, 300)
	spawn_hero(Vector2i(VINE_X - 30, 320))
	var ticks: int = 0
	while not hero.hero_climb.climbing and ticks < 20:
		play(hold("RU", 1))
		ticks += 1
	assert_true(hero.hero_climb.climbing, "grabbed in the air")
	assert_eq(hero.sim_pos.x, VINE_X)
	assert_true(hero.sim_pos.y < 320)
	var y: int = hero.sim_pos.y
	play(hold("", 4))
	assert_eq(hero.sim_pos.y, y, "no gravity on a vine")


func test_top_step_onto_the_ledge_and_hanging_at_a_bare_top() -> void:
	vine_world(true)
	add_vine(192, 320)
	spawn_hero(Vector2i(VINE_X, 200))
	hero.grounded = false
	play(hold("U", 1))
	assert_true(hero.hero_climb.climbing)
	play(hold("U", 3))
	assert_eq(hero.sim_pos.y, 194)
	play(hold("U", 1))
	assert_false(hero.hero_climb.climbing, "y - 2 <= top: the top step")
	assert_eq(hero.sim_pos, Vector2i(VINE_X + Tuning.VINE_TOP_STEP_PX, 192), "12 px onto the ledge, feet on its top")
	assert_true(hero.grounded)
	assert_eq(hero.state, Defs.HeroState.IDLE)
	play(hold("U", 3))
	assert_eq(hero.sim_pos.y, 192, "UP still held does not jump at once off the ledge (the landing lock-out)")
	assert_true(hero.grounded)
	# Facing away from the ledge: the other side is tried.
	vine_world(true)
	add_vine(192, 320)
	spawn_hero(Vector2i(VINE_X, 196))
	hero.facing = -1
	hero.grounded = false
	play(hold("U", 3))
	assert_eq(hero.sim_pos, Vector2i(VINE_X + Tuning.VINE_TOP_STEP_PX, 192), "d = facing, then -facing")
	# No ledge on either side: he hangs at top + 1.
	vine_world(false)
	add_vine(96, 300)
	spawn_hero(Vector2i(VINE_X, 104))
	hero.grounded = false
	play(hold("U", 8))
	assert_true(hero.hero_climb.climbing)
	assert_eq(hero.sim_pos.y, 97, "hangs at top + 1")


func test_a_ceiling_stops_the_climb() -> void:
	vine_world(false, 9)
	add_vine(64, 300)
	spawn_hero(Vector2i(VINE_X, 200))
	hero.grounded = false
	play(hold("U", 10))
	assert_true(hero.hero_climb.climbing)
	assert_eq(hero.sim_pos.y, 192, "the head probe (col, row - 2) of y 190 is the solid cell of row 9")


func test_vine_leap_matches_the_reference() -> void:
	var reference: Dictionary = party_reference().get("vine_leap", {})
	assert_false(reference.is_empty(), "PARTY_REFERENCE.json vine_leap")
	for case: String in ["up_held", "up_released"]:
		vine_world(false)
		add_vine(64, 300)
		spawn_hero(Vector2i(VINE_X, 200))
		hero.grounded = false
		play(hold("U", 1))
		assert_true(hero.hero_climb.climbing)
		play(hold("RU", 1))
		assert_false(hero.hero_climb.climbing, "a direction + UP leaps off")
		assert_eq([hero.xvel, hero.yvel, hero.no_jump], [Tuning.VINE_JUMP_XVEL, Tuning.VINE_JUMP_YVEL,
				Tuning.NO_JUMP_TICKS], "launch(+32, -128)")
		assert_eq(hero.hero_climb.regrab_lock, Tuning.VINE_REGRAB_LOCK_TICKS - 1)
		var origin: Vector2i = hero.sim_pos
		var got: Array = []
		play(hold("RU" if case == "up_held" else "R", 17), func(t: int) -> void:
			got.append([t, hero.sim_pos.x - origin.x, origin.y - hero.sim_pos.y])
		)
		var want: Array = reference.get(case, [])
		assert_eq(got.size(), want.size(), case)
		for i: int in mini(got.size(), want.size()):
			assert_ints_eq(got[i], want[i], "%s tick %d (t, dx, rise)" % [case, i + 1])
		assert_false(hero.hero_climb.climbing, "%s: the re-grab lock keeps him off the same vine" % case)


func test_drop_and_the_regrab_lock() -> void:
	vine_world(false)
	var vine: FakeVine = add_vine(64, 300)
	spawn_hero(Vector2i(VINE_X, 200))
	hero.grounded = false
	play(hold("U", 1))
	play(hold("DU", 1))
	assert_false(hero.hero_climb.climbing, "DOWN + UP drops")
	assert_eq(hero.yvel, 0)
	assert_eq(hero.sim_pos.y, 200, "he falls from the next tick")
	assert_eq(hero.hero_climb.regrab_vine, vine)
	play(hold("U", 5))
	assert_false(hero.hero_climb.climbing, "UP cannot grab the same vine during the lock")
	assert_true(hero.sim_pos.y > 200)
	vine_world(false)
	add_vine(64, 300)
	spawn_hero(Vector2i(VINE_X, 200))
	hero.grounded = false
	play(hold("U", 1) + hold("DU", 1) + hold("", 2))
	var y: int = hero.sim_pos.y
	play(hold("", Tuning.VINE_REGRAB_LOCK_TICKS - 3) + hold("U", 1))
	assert_true(hero.hero_climb.climbing, "the lock is over after 12 ticks (fell %d px)" % (hero.sim_pos.y - y))


func test_climbing_down_past_the_bottom_lets_go() -> void:
	vine_world(false)
	add_vine(64, 224)
	spawn_hero(Vector2i(VINE_X, 230))
	hero.grounded = false
	play(hold("U", 1))
	assert_true(hero.hero_climb.climbing)
	play(hold("D", 3))
	assert_true(hero.hero_climb.climbing, "y 239 <= bottom + 16")
	play(hold("D", 1))
	assert_false(hero.hero_climb.climbing, "y 242 > bottom + 16: he lets go")
	play(hold("", 3))
	assert_true(hero.sim_pos.y > 242, "and falls")


func test_a_hurt_knocks_him_off_and_a_shake_does_not_move_him() -> void:
	vine_world(false)
	add_vine(64, 300)
	spawn_hero(Vector2i(VINE_X, 200))
	hero.grounded = false
	play(hold("U", 1))
	hero.apply_shake_nudge(Tuning.SHAKE_NUDGE)
	assert_eq(hero.sim_pos.y, 200 - Tuning.SHAKE_NUDGE)
	play(hold("", 1))
	assert_eq(hero.sim_pos.y, 200, "no shake nudge on a vine")
	assert_true(hero.hero_climb.climbing)
	var hearts: int = hero.run.hearts
	assert_true(hero.hurt(null))
	assert_false(hero.hero_climb.climbing, "a hurt ends CLIMB")
	assert_eq(hero.run.hearts, hearts - 1, "the 1.0 hurt")
	assert_eq(hero.yvel, Tuning.HURT_YVEL)
	play(hold("U", 10))
	assert_false(hero.hero_climb.climbing, "stunned: no grab")
	hero.respawn_at(START)
	assert_false(hero.hero_climb.climbing)
	assert_eq(hero.hero_climb.regrab_lock, 0)


func test_a_launch_takes_him_off_the_vine() -> void:
	vine_world(false)
	add_vine(64, 300)
	spawn_hero(Vector2i(VINE_X, 200))
	hero.grounded = false
	play(hold("U", 1))
	hero.launch(PlayerBase.LAUNCH_KEEP, Tuning.GEYSER_POWER)
	play(hold("", 1))
	assert_false(hero.hero_climb.climbing, "a geyser's launch moves him off")
	assert_true(hero.sim_pos.y < 200)


func test_swap_works_on_a_vine() -> void:
	vine_world(false)
	level.meta = {"book": 2, "belt": LevelText.BELT_FRESH}
	add_vine(64, 300)
	spawn_hero(Vector2i(VINE_X, 200))
	hero.grounded = false
	hero.run.set_belt(Defs.Weapon.AXE)
	play(hold("U", 1) + hold("S", 1))
	assert_true(hero.hero_climb.climbing)
	assert_eq(hero.run.weapon, Defs.Weapon.AXE, "Swap works on a vine")
	var frame: int = hero.hero_climb.climb_frame()
	assert_true(frame >= HeroClimb.CLIMB_FRAME_FIRST and frame < HeroClimb.CLIMB_FRAME_FIRST + 4, "climb frames 44-47")


func test_climbing_objects_b_vine() -> void:
	vine_world(true)
	if not Spawner.exists(&"objects/vine"):
		print("    PENDING objects-B objects/vine")
		assert_true(true)
		return
	var vine: SimEntity = level.spawn(&"objects/vine", LevelText.cell_to_feet(VINE_COL, 12), {"length": 8})
	var rolled: SimEntity = level.spawn(&"objects/vine", LevelText.cell_to_feet(VINE_COL - 20, 12),
			{"length": 8, "rolled": true})
	assert_not_null(vine)
	spawn_hero(Vector2i(VINE_X + 3, 320))
	assert_true(hero.hero_climb.active, "the level's vine switches the component on")
	play(hold("U", 1))
	assert_true(hero.hero_climb.climbing, "UP next to the real vine grabs it")
	assert_eq(hero.hero_climb.vine, vine)
	var ticks: int = 0
	while hero.hero_climb.climbing and ticks < 80:
		play(hold("U", 1))
		ticks += 1
	assert_eq(ticks, 64, "128 px at 2 px per tick, then the top step")
	assert_eq(hero.sim_pos, Vector2i(VINE_X + Tuning.VINE_TOP_STEP_PX, 192), "onto the ledge")
	assert_true(hero.grounded)
	# A rolled vine cannot be grabbed until something unrolls it.
	hero.respawn_at(Vector2i((VINE_COL - 20) * 16 + 8, 320))
	play(hold("U", 1))
	assert_false(hero.hero_climb.climbing, "a rolled vine is not climbable")
	assert_not_null(rolled)


func test_the_player_book2_level_is_valid() -> void:
	var validator: LevelValidator = LevelValidator.new()
	assert_true(validator.add_file("res://levels/test_player_book2.lvl"))
	validator.run()
	var lines: PackedStringArray = PackedStringArray()
	for problem: Dictionary in validator.problems_of():
		if int(problem["severity"]) == LevelValidator.ERROR:
			lines.append(LevelValidator.format_problem(problem))
	assert_eq(validator.error_count(), 0, "\n".join(lines))
	var text: String = FileAccess.get_file_as_string("res://levels/test_player_book2.lvl")
	for needed: String in ["objects/vine", "objects/bark_board", "kind=spear", "objects/mount", ":::"]:
		assert_true(text.contains(needed), "the walk shows %s" % needed)


# =================================================================================================================
# Tar floor
# =================================================================================================================

func test_wading_in_tar() -> void:
	tar_world(40, 90)
	spawn_hero(Vector2i(START_X, 326))
	assert_true(hero.hero_climb.active, "a tar floor switches the component on")
	var xs: Array[int] = []
	var origin: int = hero.sim_pos.x
	play(hold("R", 8), func(_t: int) -> void: xs.append(hero.sim_pos.x - origin))
	assert_ints_eq(xs, [1, 3, 5, 7, 9, 11, 13, 15], "ACCEL(32): 2 px per tick")
	assert_eq(hero.xvel, Tuning.TAR_WALK_CAP)
	assert_eq(hero.sim_pos.y, 326, "6 px lower than the ground")
	assert_true(hero.hero_climb.on_tar)
	play(hold("D", 6))
	assert_eq(hero.state, Defs.HeroState.CROUCH, "crouch is normal")
	assert_eq(hero.xvel, 0)


func test_tar_hop_matches_the_reference() -> void:
	var reference: Dictionary = party_reference().get("tar_hop", {})
	assert_false(reference.is_empty(), "PARTY_REFERENCE.json tar_hop")
	for side: String in ["right", "left"]:
		tar_world(30, 90)
		spawn_hero(Vector2i(START_X, 326))
		var d: int = 1 if side == "right" else -1
		hero.facing = d
		hero.xvel = Tuning.TAR_WALK_CAP * d
		var origin: Vector2i = hero.sim_pos
		var rows: Array = []
		var landed: Array[int] = [0]
		play(hold(("R" if d > 0 else "L") + "U", 40), func(t: int) -> void:
			if landed[0] != 0:
				return
			rows.append([t, hero.sim_pos.x - origin.x, origin.y - hero.sim_pos.y])
			if t > 1 and hero.grounded:
				landed[0] = t
		)
		var want: Dictionary = reference.get(side, {})
		var top: int = 0
		for row: Array in rows:
			top = maxi(top, int(row[2]))
		assert_eq(top, int(want.get("apex_px", -1)), "%s: apex 33 px" % side)
		# The reference flies over a flat floor (lands on tick 17, 33 px right / 34 left). On the tar itself the feet
		# enter the tar cell on tick 16 (5 px over the lowered surface, inside the cell whose top is 6 px higher) and
		# the 1.0 LAND of 11.2 puts them on the surface: one tick, and one tick of motion, earlier.
		assert_eq(landed[0], int(want.get("landing_tick", -1)) - 1, "%s: lands on tick 16 on the tar" % side)
		assert_eq(int(rows[-1][1]), 32 * d, "%s: 2 px per tick over 16 ticks" % side)
		assert_eq(int(rows[-1][2]), 0, "%s: back on the tar surface" % side)
		assert_true(absi(int(rows[-1][1])) <= 2 * landed[0], "%s: a hop is no faster than wading" % side)


func test_walking_out_of_tar_snaps_up_and_ends_the_slow_down() -> void:
	tar_world(40, 62)
	spawn_hero(Vector2i(62 * 16 + 4, 326))
	play(hold("R", 12))
	assert_true(hero.sim_pos.x >= 63 * 16, "out of the tar")
	assert_eq(hero.sim_pos.y, 320, "the normal snap up of 6 px")
	assert_false(hero.hero_climb.on_tar)
	play(hold("R", 6))
	assert_eq(hero.xvel, Tuning.WALK_CAP, "full walking speed on the ground")


func test_a_hop_from_tar_onto_ground_ends_the_tar_rules() -> void:
	tar_world(40, 63)
	spawn_hero(Vector2i(63 * 16 + 2, 326))
	hero.xvel = Tuning.TAR_WALK_CAP
	play(hold("RU", 1))
	assert_true(hero.hero_climb.on_tar, "a hop taken from tar stays a tar hop")
	var ticks: int = 0
	while not hero.grounded and ticks < 30:
		play(hold("R", 1))
		ticks += 1
		assert_true(absi(hero.xvel) <= Tuning.TAR_AIR_CAP, "air control capped at 32 during the tar hop")
	assert_true(hero.grounded)
	assert_eq(hero.sim_pos.y, 320, "landed on the ground beside the tar")
	play(hold("R", 6))
	assert_false(hero.hero_climb.on_tar, "the landing ended it")
	assert_eq(hero.xvel, Tuning.WALK_CAP)
