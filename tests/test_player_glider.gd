extends PlayerTestCase
## The hang-glider (PHYSICS.md 13.2) and riding platforms (11.4) with the real hero.


func test_carrying_the_glider_runs_the_crouch_handler() -> void:
	world_flat()
	spawn_running_hero(1)
	hero.set_glider(true)
	assert_true(Game.has_glider)
	var boxes: Array[int] = [0]
	play(hold("F", 10), func(_t: int) -> void:
		if hero.club_box_active:
			boxes[0] += 1
	)
	assert_eq(boxes[0], 0, "no strikes with the glider")
	assert_eq(hero.handler, Defs.HeroState.CROUCH)
	assert_eq(hero.xvel, 0, "standing still brakes with FRICTION")
	assert_eq(hero.drop_timer, Tuning.DROP_TIMER - 1)
	assert_true(hero.charge > 0)


func test_glider_jump_is_halved_and_ignores_the_lockout() -> void:
	world_flat()
	spawn_hero()
	hero.set_glider(true)
	hero.no_jump = Tuning.NO_JUMP_TICKS
	play(hold("U", 1))
	assert_eq(hero.handler, Defs.HeroState.JUMP, "the glider jump does not check no_jump")
	assert_eq(hero.yvel, Tuning.shr(Tuning.JUMP_IMPULSES[0], 1) + Tuning.GRAVITY, "impulse halved: -33")


func test_run_up_and_take_off() -> void:
	world_flat()
	spawn_hero()
	hero.set_glider(true)
	play(hold("R", 27))
	assert_eq(hero.glider_runup, Tuning.GLIDER_RUNUP_TICKS - 1, "|xvel| >= 64 counts from the 5th walking tick")
	play(hold("RU", 1))
	assert_false(hero.is_gliding(), "23 ticks of run-up are not enough: a halved jump")
	world_flat()
	spawn_hero()
	hero.set_glider(true)
	play(hold("R", 28))
	assert_eq(hero.glider_runup, Tuning.GLIDER_RUNUP_TICKS)
	var y: int = hero.sim_pos.y
	play(hold("RU", 1))
	assert_true(hero.is_gliding(), "take-off")
	assert_eq(hero.glider_lift, Tuning.GLIDER_LIFT_START)
	assert_eq(hero.sim_pos.y, y + Tuning.GLIDER_TAKEOFF_DY, "lifted 3 px")
	assert_eq(hero.yvel, Tuning.GLIDE_GRAVITY, "quarter gravity")
	var climbs: Array[int] = []
	play(hold("RU", 6), func(_t: int) -> void: climbs.append(hero.glider_tilt))
	assert_ints_eq(climbs, [4, 5, 6, 6, 6, 6], "UP raises the nose 1 per tick up to 6")
	assert_eq(hero.yvel, Tuning.GLIDER_CLIMB_YVEL + Tuning.GLIDE_GRAVITY, "climbing at 4 px/tick")
	assert_true(hero.sim_pos.y < y - 15, "and he climbs")
	assert_eq(hero.glider_lift, Tuning.GLIDER_LIFT_START - 6, "spending one lift per climbing tick")


func test_gliding_sinks_one_pixel_per_tick() -> void:
	world_flat()
	spawn_airborne_hero(Tuning.WALK_CAP, 1, 200)
	hero.set_glider(true)
	hero.yvel = 200
	play(hold("R", 1))
	assert_true(hero.is_gliding(), "a fall faster than 160 opens the glider")
	play(hold("R", 40))
	assert_eq(hero.yvel, Tuning.GLIDE_CAP, "sink cap 24 v16")
	var y: int = hero.sim_pos.y
	play(hold("R", 3))
	assert_eq(hero.sim_pos.y, y + 3, "1 px per tick")
	assert_eq(hero.xvel, Tuning.WALK_CAP, "the airborne step still accelerates")
	assert_eq(hero.glider_tilt, 3, "the nose returns to neutral")


func test_diving_refills_lift_and_landing_keeps_the_glider() -> void:
	world_flat()
	spawn_airborne_hero(Tuning.WALK_CAP, 1, 200)
	hero.set_glider(true)
	hero.yvel = 200
	play(hold("R", 1))
	hero.glider_lift = 0
	play(hold("RD", 3))
	assert_eq(hero.glider_tilt, 0, "DOWN lowers the nose")
	assert_true(hero.glider_lift > 0, "nose down at speed refills the lift")
	assert_true(hero.glider_lift <= 5 * 5, "up to 5 x |floor16(xvel)|")
	play(hold("R", 300))
	assert_true(hero.grounded)
	assert_false(hero.is_gliding(), "landing folds the glider")
	assert_true(Game.has_glider, "but keeps it")


func test_enemy_hit_costs_the_glider_not_energy() -> void:
	world_flat()
	spawn_hero()
	hero.set_glider(true)
	assert_true(hero.hurt(null))
	assert_false(Game.has_glider)
	assert_eq(Game.hearts, Tuning.ENERGY_START)


func test_glider_bump_and_dive_stomp() -> void:
	for dive: bool in [false, true]:
		world_flat()
		spawn_airborne_hero(0, 1, 20)
		hero.set_glider(true)
		hero.glide = 1
		hero.yvel = 64 if dive else 24
		var enemy: EnemyBase = EnemyBase.new()
		place(level, enemy, START, {"hp": 25})
		enemy.wake()
		enemy.on_screen = true
		var lowest_yvel: Array[int] = [hero.yvel]
		play(hold("D" if dive else "", 8), func(_t: int) -> void: lowest_yvel[0] = mini(lowest_yvel[0], hero.yvel))
		var label: String = "dive" if dive else "glide"
		assert_eq(Game.hearts, Tuning.ENERGY_START, label + ": not hurt")
		assert_eq(enemy.dive_count, 1 if dive else 0, label + ": only a dive faster than 32 v16 counts as a stomp")
		assert_true(lowest_yvel[0] <= Tuning.GLIDER_BUMP_YVEL + Tuning.GRAVITY, label + ": bumped up by -96")
		assert_false(enemy.dead, label + ": the first stomp does not kill")


func test_riding_a_platform() -> void:
	world_flat()
	var platform: PlatformBase = PlatformBase.new()
	place(level, platform, START + Vector2i(0, -120))
	var top: int = platform.sim_pos.y - platform.box_h
	spawn_hero(Vector2i(START_X, top + 2))
	play(hold("", 4))
	assert_true(hero.on_platform, "standing on the platform")
	assert_true(hero.grounded)
	assert_eq(hero.sim_pos.y, top + 1, "feet 1 px inside the top (PHYSICS.md 11.4)")
	play(hold("F", 8))
	assert_eq(hero.sim_pos.y, top + 1, "no strike hop on a platform")
	play(hold("", 2))
	play(hold("U", 1))
	assert_false(hero.on_platform, "jumping clears the flag")
	play(hold("", 3))
	assert_true(hero.sim_pos.y < top - 8, "and he rises: the jump table restarted on the platform")
	# A tap jump comes back at 5 px/tick: slow enough for the 8 px thin platform's ride window.
	play(hold("", 12))
	assert_true(hero.on_platform, "lands on it again from above")
	assert_eq(hero.sim_pos.y, top + 1)


func test_falling_from_a_platform_edge() -> void:
	world_flat()
	var platform: PlatformBase = PlatformBase.new()
	place(level, platform, START + Vector2i(0, -120))
	spawn_hero(Vector2i(START_X, platform.sim_pos.y - platform.box_h + 2))
	play(hold("", 3))
	assert_true(hero.on_platform)
	play(hold("R", 12))
	assert_false(hero.on_platform, "walked off the end")
	play(hold("", 30))
	assert_true(hero.grounded)
	assert_eq(hero.sim_pos.y, START.y, "on the floor below")
