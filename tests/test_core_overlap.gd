extends TestCase
## Overlap: the sprite-overlap test of PHYSICS.md 2.2.


func _entity(x: int, y: int, w: int, h: int, xo: int) -> SimEntity:
	var entity: SimEntity = SimEntity.new()
	entity.box_w = w
	entity.box_h = h
	entity.box_xo = xo
	entity.sim_pos = Vector2i(x, y)
	add_node(entity)
	return entity


func test_coarse_reject_gates() -> void:
	assert_false(Overlap.test(0, 0, 200, 200, 100, 64, 0, 200, 200, 100), "|dx| >= 64 rejects")
	assert_true(Overlap.test(0, 0, 200, 200, 100, 63, 0, 200, 200, 100), "|dx| = 63 passes the gate")
	assert_false(Overlap.test(0, 0, 200, 200, 100, 0, 70, 200, 200, 100), "|dy| >= 70 rejects")
	assert_true(Overlap.test(0, 0, 200, 200, 100, 0, 69, 200, 200, 100), "|dy| = 69 passes the gate")


func test_only_the_lower_objects_height_matters() -> void:
	# A is high (y = 100) and very tall, B is low (y = 140) with height 30: top of B = 110 >= 100 -> no overlap.
	assert_false(Overlap.test(0, 100, 32, 60, 16, 0, 140, 32, 30, 16))
	# B's height 41: top = 99 < 100 -> overlap.
	assert_true(Overlap.test(0, 100, 32, 60, 16, 0, 140, 32, 41, 16))


func test_body_contact_uses_half_the_leftmost_width() -> void:
	# A: left = -16, width 32 -> counts 16 px: reaches x = 0. B's left edge at 0 does not overlap, at -1 it does.
	assert_false(Overlap.test(0, 100, 32, 35, 16, 16, 100, 32, 35, 16), "left + w/2 == other.left is no contact")
	assert_true(Overlap.test(0, 100, 32, 35, 16, 15, 100, 32, 35, 16))
	# The weapon variant uses the full width.
	assert_true(Overlap.test(0, 100, 32, 35, 16, 16, 100, 32, 35, 16, true))
	assert_true(Overlap.test(0, 100, 32, 35, 16, 31, 100, 32, 35, 16, true))
	assert_false(Overlap.test(0, 100, 32, 35, 16, 32, 100, 32, 35, 16, true))


func test_stomp_flag_by_fall_speed() -> void:
	var hero: SimEntity = _entity(100, 100, 32, 35, 15)
	var enemy: SimEntity = _entity(100, 100, 26, 15, 13)
	hero.yvel = Tuning.STOMP_MIN_YVEL
	assert_true(Overlap.body(hero, enemy, hero))
	assert_true(Overlap.stomp, "falling at 8 px/tick or faster: any contact is a stomp")
	hero.yvel = Tuning.STOMP_MIN_YVEL - 1
	assert_true(Overlap.body(hero, enemy, hero))
	assert_false(Overlap.stomp, "same level, slow: the hero (low on a tie) is hurt")


func test_stomp_flag_by_top_half_rule() -> void:
	var hero: SimEntity = _entity(100, 90, 32, 35, 15)
	var enemy: SimEntity = _entity(100, 100, 26, 30, 13)
	# Enemy is low: top = 70, depth = 90 - 70 = 20 > 15 -> not in the top half.
	assert_true(Overlap.body(hero, enemy, hero))
	assert_false(Overlap.stomp)
	assert_eq(Overlap.depth, 20)
	# Feet 10 px into the enemy box: depth 10 <= 15 -> stomp.
	hero.sim_pos.y = 80
	assert_true(Overlap.body(hero, enemy, hero))
	assert_true(Overlap.stomp)
	assert_eq(Overlap.depth, 10)
	# Hero below the enemy: the low object is the hero, never a stomp at low speed.
	hero.sim_pos.y = 110
	assert_true(Overlap.body(hero, enemy, hero))
	assert_false(Overlap.stomp)


func test_flags_are_cleared_by_every_test() -> void:
	var hero: SimEntity = _entity(100, 80, 32, 35, 15)
	var enemy: SimEntity = _entity(100, 100, 26, 30, 13)
	assert_true(Overlap.body(hero, enemy, hero))
	assert_true(Overlap.stomp)
	enemy.sim_pos.x = 400
	assert_false(Overlap.body(hero, enemy, hero))
	assert_false(Overlap.stomp, "the stomp flag never survives into the next test (PHYSICS.md 14.1 #7)")
	assert_eq(Overlap.depth, 0)


func test_weapon_box_helper() -> void:
	var enemy: SimEntity = _entity(130, 100, 26, 15, 13)
	# Forward front box of the default club for a hero at (100, 100) facing right: x +11..+35, y -15..-2.
	var box: Rect2i = Tuning.CLUB_BOX[Tuning.ClubFrame.FWD_FRONT]
	box.position += Vector2i(100, 100)
	var frame: int = Tuning.ClubFrame.FWD_FRONT
	var x_offset: int = Tuning.CLUB_ORIGIN[frame].x - Tuning.CLUB_BOX[frame].position.x
	assert_eq(x_offset, 12)
	assert_true(Overlap.weapon(box, x_offset, enemy))
	assert_false(Overlap.stomp)
	enemy.sim_pos.x = 150
	assert_false(Overlap.weapon(box, x_offset, enemy),
			"35 px reach: an enemy whose left edge is at 137 is out of range")


func test_rect_helpers() -> void:
	assert_true(Overlap.rects(Rect2i(0, 0, 10, 10), Rect2i(9, 9, 10, 10)))
	assert_false(Overlap.rects(Rect2i(0, 0, 10, 10), Rect2i(10, 0, 10, 10)))
	assert_true(Overlap.point_in(Rect2i(16, 16, 32, 16), 16, 31))
	assert_false(Overlap.point_in(Rect2i(16, 16, 32, 16), 48, 20))
