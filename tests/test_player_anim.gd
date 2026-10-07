extends PlayerTestCase
## The hero's picture: scene layout (ARCHITECTURE 8.2), sheet frames of ASSET_MANIFEST 3 per pose, mirroring,
## weapon sheets, the hurt blink, the glider overlay and the sprite boxes of PHYSICS.md 2.1.


func test_scene_layout_follows_the_manifest() -> void:
	world_flat()
	spawn_hero()
	var sprite: Sprite2D = hero.get_node(^"Sprite") as Sprite2D
	assert_not_null(sprite)
	assert_eq(sprite.hframes, 8)
	assert_eq(sprite.vframes, 7)
	assert_false(sprite.centered)
	assert_eq(sprite.offset, Vector2(-88, -96), "pivot (88, 96): the feet point")
	assert_not_null(hero.get_node_or_null(^"GliderSprite"))
	assert_eq(hero.weapon_sheets.size(), 4)
	assert_eq(hero.z_index, Defs.Z_PLAYER)
	play(hold("R", 3))
	await get_tree().process_frame
	assert_eq(hero.position, Vector2(hero.sim_pos * Tuning.ART_SCALE), "drawn at the feet point in art px")


func test_frames_per_pose() -> void:
	world_flat()
	spawn_hero()
	assert_true(_frames(hold("", 24)).all(func(f: int) -> bool: return f >= 0 and f <= 5), "idle 0-5")
	var walk: Array[int] = _frames(hold("R", 24))
	assert_true(walk.slice(1).all(func(f: int) -> bool: return f >= 6 and f <= 13), "walk 6-13")
	assert_eq(_distinct(walk.slice(1)), 8, "the whole walk cycle plays")
	hero.respawn_at(START)
	var jump: Array[int] = _frames(jump_flags(-1, 21))
	assert_true(jump.slice(0, 9).all(func(f: int) -> bool: return f >= 14 and f <= 16), "rising 14-16")
	assert_true(jump.slice(13, 20).all(func(f: int) -> bool: return f >= 17 and f <= 19), "falling 17-19")
	hero.respawn_at(START)
	assert_true(_frames(hold("D", 4)).all(func(f: int) -> bool: return f == 21), "crouch 21")
	var crawl: Array[int] = _frames(hold("RD", 12))
	assert_true(crawl.all(func(f: int) -> bool: return f == 22 or f == 23), "crawl 22-23")


func test_strike_frames_follow_the_script() -> void:
	world_flat()
	spawn_hero()
	assert_ints_eq(_frames(hold("F", 7)), [27, 27, 28, 28, 29, 29, 30], "forward: wind-up, overhead, hit")
	play(hold("", 12))
	assert_ints_eq(_frames(hold("UF", 9)), [31, 31, 31, 31, 31, 31, 32, 32, 32], "high: hit frame on the active ticks")
	play(hold("", 12))
	assert_ints_eq(_frames(hold("DF", 9)), [33, 33, 33, 33, 33, 33, 34, 34, 34], "low")
	play(hold("", 16))
	hero.sim_pos.y -= 40
	hero.yvel = 64
	hero.grounded = false
	hero.fall_ticks = 4
	var air: Array[int] = _frames(hold("F", 6))
	assert_ints_eq(air.slice(0, 4), [35, 35, 35, 35], "swing in the air: attack_air")
	assert_eq(air[4], 36)


func test_hurt_death_land_glide_and_victory_frames() -> void:
	world_ledge(70, 6)
	spawn_running_hero(1, Vector2i(70 * 16 - 5, START.y))
	var fall: Array[int] = _frames(hold("", 20))
	assert_true(fall.has(HeroAnim.LAND), "a hard landing shows the landing squash")
	hero.hurt(null)
	var hurt: Array[int] = _frames(hold("", 10))
	assert_true(hurt.all(func(f: int) -> bool: return f == 37 or f == 38), "hurt 37-38")
	hero.kill(&"spikes")
	var death: Array[int] = _frames(hold("", 10))
	assert_true(death.all(func(f: int) -> bool: return f == 39 or f == 40), "death toss 39-40")
	world_flat()
	spawn_airborne_hero(0, 1, 200)
	hero.set_glider(true)
	hero.yvel = 200
	var glide: Array[int] = _frames(hold("", 10))
	assert_true(glide.slice(1).all(func(f: int) -> bool: return f == 50 or f == 51), "glide 50-51")
	var glider: Sprite2D = hero.get_node(^"GliderSprite") as Sprite2D
	assert_true(glider.visible, "the glider is drawn over the hero")
	assert_eq(glider.position.y, float(Player.GLIDER_HANDS_Y), "at his raised hands")
	world_flat()
	spawn_hero()
	Events.exit_reached.emit(&"exit")
	assert_true(_frames(hold("", 6)).all(func(f: int) -> bool: return f == 48 or f == 49), "victory 48-49")


func test_mirroring_weapon_sheets_and_blink() -> void:
	world_flat()
	spawn_hero()
	var sprite: Sprite2D = hero.get_node(^"Sprite") as Sprite2D
	play(hold("L", 1))
	assert_true(sprite.flip_h, "facing left mirrors the sheet")
	play(hold("R", 1))
	assert_false(sprite.flip_h)
	for weapon: int in 4:
		Game.set_weapon(weapon)
		assert_eq(sprite.texture, hero.weapon_sheets[weapon], "sheet of weapon %d" % weapon)
	Game.set_weapon(Defs.Weapon.CLUB)
	hero.hurt(null)
	var shown: Array[int] = [0]
	play(hold("", 40), func(_t: int) -> void:
		if sprite.modulate.a == 1.0:
			shown[0] += 1
	)
	assert_eq(shown[0], 10, "drawn solid 1 tick in 4 while invulnerable")
	play(hold("", 4))
	assert_eq(sprite.modulate.a, 1.0)


func test_sprite_box_per_pose() -> void:
	world_ledge(70, 8)
	spawn_hero()
	play(hold("", 1))
	assert_eq(_box(), Tuning.HERO_BOX_STAND, "stand 32 x 35")
	play(hold("D", 1))
	assert_eq(_box(), Tuning.HERO_BOX_CROUCH, "crouch 40 x 30")
	hero.respawn_at(START)
	play(hold("U", 2))
	assert_eq(_box(), Tuning.HERO_BOX_JUMP_UP, "rising 32 x 38")
	hero.respawn_at(START)
	hero.facing = 1
	hero.xvel = Tuning.WALK_CAP
	hero.teleport(Vector2i(70 * 16 - 5, START.y))
	play(hold("", 3))
	assert_eq(_box(), Tuning.HERO_BOX_FALL, "falling 40 x 31")
	play(hold("", 10))
	assert_eq(_box(), Tuning.HERO_BOX_FALL_LONG, "48 x 31 after 12 ticks of falling")
	hero.respawn_at(START)
	hero.hurt(null)
	play(hold("", 1))
	assert_eq(_box(), Tuning.HERO_BOX_HURT, "hurt 48 x 32")


## The performance pass (PLAN.md P2.12) writes the frame cycles out in HeroAnim._frame: every looping animation still
## shows FIRST + _cycle(fps, count) on every clock value, as before.
func test_written_out_frame_cycles_equal_the_cycle_helper() -> void:
	world_flat()
	spawn_hero()
	var animator: HeroAnim = HeroAnim.new()
	var cycles: Array = [
		[HeroAnim.Anim.IDLE, HeroAnim.IDLE_FIRST, HeroAnim.IDLE_FPS, HeroAnim.IDLE_COUNT],
		[HeroAnim.Anim.PANT, HeroAnim.IDLE_FIRST, HeroAnim.PANT_FPS, HeroAnim.IDLE_COUNT],
		[HeroAnim.Anim.FALL, HeroAnim.FALL_FIRST, HeroAnim.FALL_FPS, HeroAnim.FALL_COUNT],
		[HeroAnim.Anim.CRAWL, HeroAnim.CRAWL_FIRST, HeroAnim.CRAWL_FPS, HeroAnim.CRAWL_COUNT],
		[HeroAnim.Anim.HURT, HeroAnim.HURT_FIRST, HeroAnim.HURT_FPS, HeroAnim.HURT_COUNT],
		[HeroAnim.Anim.DEATH, HeroAnim.DEATH_FIRST, HeroAnim.DEATH_FPS, HeroAnim.DEATH_AIR_COUNT],
		[HeroAnim.Anim.GLIDE, HeroAnim.GLIDE_FIRST, HeroAnim.GLIDE_FPS, HeroAnim.GLIDE_COUNT],
		[HeroAnim.Anim.VICTORY, HeroAnim.VICTORY_FIRST, HeroAnim.VICTORY_FPS, HeroAnim.VICTORY_COUNT],
		[HeroAnim.Anim.BALL, HeroAnim.ROLL_FIRST, HeroAnim.ROLL_FPS, HeroAnim.ROLL_COUNT],
	]
	for cycle: Array in cycles:
		animator.anim = int(cycle[0])
		for clock: int in 100:
			animator.clock = clock
			var want: int = int(cycle[1]) + animator._cycle(int(cycle[2]), int(cycle[3]))
			assert_eq(animator._frame(hero), want, "anim %d clock %d" % [cycle[0], clock])
	animator.anim = HeroAnim.Anim.JUMP
	for clock: int in 40:
		animator.clock = clock
		assert_eq(animator._frame(hero), HeroAnim.JUMP_FIRST + mini(clock * HeroAnim.JUMP_FPS
				/ Tuning.ANIM_TICKS_PER_SECOND, HeroAnim.JUMP_COUNT - 1), "jump clock %d" % clock)


## The crouch charge glows (PHYSICS.md 8.5 presentation) and the tint goes back to white when the charge is spent;
## a hero without a charge never writes the tint (the performance pass keeps the usual tick at two field tests).
func test_charge_tint_comes_and_goes() -> void:
	world_flat()
	spawn_hero()
	var sprite: Sprite2D = hero.get_node(^"Sprite") as Sprite2D
	play(hold("", 4))
	assert_eq(sprite.self_modulate, Color.WHITE, "no charge: white")
	play(hold("D", 12))
	assert_true(hero.charge > 0)
	assert_ne(sprite.self_modulate, Color.WHITE, "charged: the glow")
	var glow_seen: Array[bool] = [false]
	play(hold("", 80), func(_t: int) -> void:
		if hero.charge > 0 and sprite.self_modulate != Color.WHITE:
			glow_seen[0] = true
		if hero.charge == 0:
			assert_eq(sprite.self_modulate, Color.WHITE, "the charge is spent: white again")
	)
	assert_true(glow_seen[0], "the glow lasts while the charge does")
	assert_eq(hero.charge, 0)


func _frames(flags: PackedInt32Array) -> Array[int]:
	var frames: Array[int] = []
	var sprite: Sprite2D = hero.get_node(^"Sprite") as Sprite2D
	play(flags, func(_t: int) -> void:
		assert_eq(sprite.frame, hero.anim_frame, "the sprite shows the frame of the tick")
		frames.append(hero.anim_frame)
	)
	return frames


func _distinct(values: Array[int]) -> int:
	var seen: Dictionary = {}
	for value: int in values:
		seen[value] = true
	return seen.size()


func _box() -> Vector3i:
	return Vector3i(hero.box_w, hero.box_h, hero.box_xo)
