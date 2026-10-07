extends TestCase
## The tribe camera of a co-op party (docs/spec/PHYSICS.md C.13, DESIGN.md D.2; LevelCamera.tick_group /
## snap_group / follow_frame / apply_rising): group paging with the rear-hero margins, standing still never pages,
## one hero of H is exactly the 1.0 camera, the vertical follow on the grounded anchor, the look-around claim that
## keeps the partner on the view, the visible camera centred on the authentic view, the rising tide's pull.

const BASE_VIEW: Vector2i = Vector2i(640, 360)
const FLOOR_Y: int = 320

var _a: PlayerBase = null
var _b: PlayerBase = null
var _party: Array[PlayerBase] = []


func before_each() -> void:
	_a = PlayerBase.new()
	_a.slot = 0
	_b = PlayerBase.new()
	_b.slot = 1
	_party = [_a, _b]
	for hero: PlayerBase in _party:
		hero.teleport(Vector2i(0, FLOOR_Y))
		hero.grounded = true


func after_each() -> void:
	_a.free()
	_b.free()


func _camera(cols: int = 256, rows: int = 40, view_art: Vector2i = BASE_VIEW) -> LevelCamera:
	var camera: LevelCamera = LevelCamera.new()
	camera.set_bounds(Rect2i(0, 0, cols * Tuning.TILE, rows * Tuning.TILE))
	camera.set_view_art(view_art)
	camera.pos = Vector2i(40 * Tuning.TILE, FLOOR_Y - 7 * Tuning.TILE)
	return camera


## Put `hero` at screen column `sc` of `camera` (middle of the cell).
func _at(camera: LevelCamera, hero: PlayerBase, sc: int) -> void:
	hero.sim_pos.x = (camera.get_cell().x + sc) * Tuning.TILE + 8


func _sc(camera: LevelCamera, hero: PlayerBase) -> int:
	return Tuning.to_cell(hero.sim_pos.x) - camera.get_cell().x


func test_standing_still_never_moves_the_view() -> void:
	var camera: LevelCamera = _camera()
	_at(camera, _a, 18)
	_at(camera, _b, 2)
	var before: Vector2i = camera.pos
	for i: int in 10:
		camera.tick_group(_party)
	assert_eq(camera.pos, before, "nobody moves: no page, even with a hero at column 18")
	assert_eq(camera.h_dir, LevelCamera.DIR_IDLE)


func test_paging_right_waits_for_the_rear_hero() -> void:
	var camera: LevelCamera = _camera()
	var col: int = camera.get_cell().x
	_at(camera, _a, 16)
	_at(camera, _b, 1)
	_a.xvel = Tuning.WALK_CAP
	camera.tick_group(_party)
	camera.tick_group(_party)
	assert_eq(camera.get_cell().x, col, "the rear hero at the margin column 1: no page")
	_at(camera, _b, 2)
	camera.tick_group(_party)
	assert_eq(camera.h_dir, LevelCamera.DIR_RIGHT, "rear hero at column 2: the page starts ...")
	assert_eq(camera.get_cell().x, col, "... and moves from the next tick on")
	camera.tick_group(_party)
	assert_eq(camera.get_cell().x, col + 1, "one column per tick")
	# The rear hero stands: every page step brings him one column nearer to the margin.
	camera.tick_group(_party)
	assert_eq(_sc(camera, _b), PartyTuning.CAM_REAR_MARGIN_COL, "he reached column 1")
	camera.tick_group(_party)
	assert_eq(camera.h_dir, LevelCamera.DIR_IDLE, "the rear hero at the margin stops the page")
	assert_eq(camera.get_cell().x, col + 1)


func test_paging_right_stops_when_the_front_hero_is_back_at_column_5() -> void:
	var camera: LevelCamera = _camera()
	_at(camera, _a, 17)
	_at(camera, _b, 15)
	_a.xvel = Tuning.WALK_CAP
	_b.xvel = Tuning.WALK_CAP
	var pages: int = 0
	for i: int in 40:
		var col: int = camera.get_cell().x
		camera.tick_group(_party)
		if camera.get_cell().x != col:
			pages += 1
		if camera.h_dir == LevelCamera.DIR_IDLE and pages > 0:
			break
	assert_eq(maxi(_sc(camera, _a), _sc(camera, _b)), PartyTuning.CAM_FRONT_STOP_COL, "front hero at column 5")
	assert_eq(pages, 12, "17 -> 5: twelve columns (the heroes stand still meanwhile)")


func test_paging_left_mirrors_the_rules() -> void:
	var camera: LevelCamera = _camera()
	var col: int = camera.get_cell().x
	_at(camera, _a, 4)
	_at(camera, _b, 18)
	_a.xvel = -Tuning.WALK_CAP
	camera.tick_group(_party)
	camera.tick_group(_party)
	assert_eq(camera.get_cell().x, col, "the rear (right) hero at column 18: no page")
	_at(camera, _b, 17)
	camera.tick_group(_party)
	camera.tick_group(_party)
	assert_eq(camera.get_cell().x, col - 1, "rear at 17: it pages left")
	assert_eq(camera.h_dir, LevelCamera.DIR_LEFT)
	camera.tick_group(_party)
	assert_eq(camera.h_dir, LevelCamera.DIR_IDLE, "the rear hero reached column 18: stop")


func test_one_hero_of_h_is_the_1_0_camera() -> void:
	var tribe: LevelCamera = _camera()
	var solo: LevelCamera = _camera()
	_b.down = true  # an egg is not in H
	_a.sim_pos = Vector2i(tribe.pos.x + 10 * Tuning.TILE + 8, FLOOR_Y)
	_a.xvel = Tuning.WALK_CAP
	var other: PlayerBase = PlayerBase.new()
	other.teleport(_a.sim_pos)
	other.xvel = _a.xvel
	for i: int in 60:
		_a.sim_pos.x += Tuning.floor16(_a.xvel)
		other.sim_pos.x = _a.sim_pos.x
		if i == 30:
			_a.yvel = -100
			other.yvel = -100
		_a.sim_pos.y += Tuning.floor16(_a.yvel)
		other.sim_pos.y = _a.sim_pos.y
		tribe.tick_group(_party)
		solo.tick(other)
		if tribe.pos != solo.pos:
			fail("tick %d: tribe %s, 1.0 %s" % [i, tribe.pos, solo.pos])
			break
	assert_eq(tribe.pos, solo.pos, "the same path tick for tick")
	assert_eq(tribe.anchor_slot, 0)
	other.free()


func test_nobody_in_h_holds_the_view() -> void:
	var camera: LevelCamera = _camera()
	_a.dead = true
	_b.down = true
	_at(camera, _a, 19)
	var before: Vector2i = camera.pos
	camera.tick_group(_party)
	assert_eq(camera.pos, before)
	assert_eq(camera.anchor_slot, -1)


func test_a_falling_hero_never_drags_the_view_while_his_partner_stands() -> void:
	var camera: LevelCamera = _camera()
	camera.pos.y = FLOOR_Y - 7 * Tuning.TILE
	_at(camera, _a, 8)
	_at(camera, _b, 10)
	camera.tick_group(_party)
	var y: int = camera.pos.y
	# B falls far below the view's comfort rows; A keeps standing on the floor.
	_b.grounded = false
	_b.yvel = 128
	for i: int in 8:
		_b.sim_pos.y += 8
		camera.tick_group(_party)
	assert_eq(camera.anchor_slot, 0, "the standing hero is the anchor")
	assert_eq(camera.pos.y, y, "the view does not follow the falling hero")
	# A jumps, B lands lower down: B had ground more recently, he becomes the anchor and the view follows him.
	_a.grounded = false
	_a.yvel = -100
	_b.grounded = true
	_b.yvel = 0
	_b.sim_pos.y = camera.pos.y + 10 * Tuning.TILE + 8
	camera.tick_group(_party)
	assert_eq(camera.anchor_slot, 1, "the latest hero with ground under his feet")
	for i: int in 30:
		camera.tick_group(_party)
	assert_true(camera.pos.y > y, "the view went down to him")


## Both stand: A on the floor, B on a ledge `rows_up` rows higher. Returns the camera after `ticks` group steps.
func _ledge(rows_up: int, ticks: int) -> LevelCamera:
	var camera: LevelCamera = _camera()
	_at(camera, _a, 8)
	_at(camera, _b, 10)
	_b.sim_pos.y = FLOOR_Y - rows_up * Tuning.TILE
	for i: int in ticks:
		camera.tick_group(_party)
	return camera


func _whole_on_view(camera: LevelCamera, hero: PlayerBase) -> bool:
	return hero.sim_pos.y - LevelCamera.KEEP_HEAD_PX >= camera.pos.y \
			and hero.sim_pos.y <= camera.pos.y + camera.rows * Tuning.TILE


func test_a_hero_standing_on_a_high_ledge_is_brought_onto_the_view() -> void:
	var camera: LevelCamera = _camera()
	_at(camera, _a, 8)
	_at(camera, _b, 10)
	_b.sim_pos.y = FLOOR_Y - 8 * Tuning.TILE  # an Expert boost ledge: his feet one row above the view's top
	var start_y: int = camera.pos.y
	assert_false(_whole_on_view(camera, _b), "the set-up: B is off the view")
	camera.tick_group(_party)
	assert_eq(camera.anchor_slot, 0, "both stand: the anchor is P1 (ties: the lower slot) ...")
	assert_true(camera.pos.y < start_y, "... but the view rises towards the hero on the ledge")
	assert_true(start_y - camera.pos.y <= 16, "at the 12.2 speed: %d px" % (start_y - camera.pos.y))
	for i: int in 30:
		camera.tick_group(_party)
	assert_true(_whole_on_view(camera, _b), "B whole on the view")
	assert_true(_whole_on_view(camera, _a), "and A too")
	var settled: int = camera.pos.y
	for i: int in 60:
		camera.tick_group(_party)
	assert_eq(camera.pos.y, settled, "it settles: P1's follow (his feet now in the bottom rows) never pushes B off again")


func test_the_anchor_never_pushes_a_standing_partner_off_the_view() -> void:
	# B 8 rows up, both whole on the view; A's own follow would lower the view (his feet in the bottom row, 12.2:
	# grounded at row 10 or below -> row 9).
	var camera: LevelCamera = _camera()
	camera.pos.y = FLOOR_Y - 10 * Tuning.TILE - 8
	camera.prev = camera.pos
	_at(camera, _a, 8)
	_at(camera, _b, 10)
	_b.sim_pos.y = FLOOR_Y - 8 * Tuning.TILE
	assert_true(_whole_on_view(camera, _a) and _whole_on_view(camera, _b))
	for i: int in 40:
		camera.tick_group(_party)
		assert_true(_whole_on_view(camera, _b), "tick %d: B stays whole on the view" % i)
	# B jumps (no ground under him): the 1.0 window on the anchor takes over again.
	_b.grounded = false
	_b.yvel = -100
	var held: int = camera.pos.y
	for i: int in 10:
		camera.tick_group(_party)
	assert_true(camera.pos.y > held, "with only P1 standing, his follow lowers the view")


func test_a_hero_on_a_vine_is_kept_on_the_view_too() -> void:
	var camera: LevelCamera = _camera()
	_at(camera, _a, 8)
	_at(camera, _b, 10)
	_b.grounded = false
	_b.state = Defs.HeroState.CLIMB
	_b.sim_pos.y = FLOOR_Y - 8 * Tuning.TILE  # high up his vine
	for i: int in 30:
		camera.tick_group(_party)
	assert_true(_whole_on_view(camera, _b), "the climber holds his place: the view comes up to him")
	assert_true(_whole_on_view(camera, _a))
	_b.state = Defs.HeroState.JUMP
	_b.yvel = -60
	_b.sim_pos.y -= 3 * Tuning.TILE
	var held: int = camera.pos.y
	camera.tick_group(_party)
	assert_true(camera.pos.y >= held, "a leap off the vine is a jump: it never drags the view up")


func test_heroes_too_far_apart_keep_the_anchor_rule() -> void:
	var camera: LevelCamera = _ledge(10, 40)
	assert_eq(camera.anchor_slot, 0)
	assert_true(_whole_on_view(camera, _a), "no view holds both: the anchor's view, as before (the leash decides)")
	assert_false(_whole_on_view(camera, _b))


func test_look_claims_the_camera_but_keeps_the_partner_on_the_view() -> void:
	var camera: LevelCamera = _camera()
	var col: int = camera.get_cell().x
	_at(camera, _a, 10)
	_at(camera, _b, 4)
	_a.looking = true
	_a.facing = 1
	for i: int in 10:
		camera.tick_group(_party)
	assert_eq(camera.get_cell().x, col + 3, "three look steps, then the partner would leave column 1")
	assert_eq(_sc(camera, _b), PartyTuning.CAM_REAR_MARGIN_COL)
	assert_eq(camera.anchor_slot, 0, "the looker is the anchor")
	_a.looking = false
	_b.looking = true
	_b.facing = -1
	for i: int in 30:
		camera.tick_group(_party)
	assert_eq(_sc(camera, _a), 18, "B looks left until A is at column 18")


func test_snap_group_places_the_view_on_the_first_hatched_hero() -> void:
	var tribe: LevelCamera = _camera()
	var solo: LevelCamera = _camera()
	_a.down = true
	_b.sim_pos = Vector2i(90 * Tuning.TILE + 8, FLOOR_Y)
	tribe.snap_group(_party)
	solo.snap(_b)
	assert_eq(tribe.pos, solo.pos, "12.5 on P2 (P1 is an egg)")
	assert_eq(tribe.anchor_slot, 1)
	assert_eq(tribe.cell_rect(), Rect2i(tribe.get_cell() * Tuning.TILE, Vector2i(320, 176)), "the authentic view")


func test_the_visible_view_is_centred_on_the_authentic_one() -> void:
	var tribe: LevelCamera = _camera()
	var wide: LevelCamera = _camera(256, 40, Vector2i(1280, 720))
	tribe.pos = Vector2i(60 * Tuning.TILE, 10 * Tuning.TILE)
	wide.follow_frame(tribe.get_rect(), true)
	assert_eq(wide.pos, tribe.pos - Vector2i(160, 90), "a 640 x 360 view around the 320 x 180 one")
	assert_eq(wide.prev, wide.pos, "a snap: no interpolation")
	var same: LevelCamera = _camera()
	same.follow_frame(tribe.get_rect())
	assert_eq(same.pos, tribe.pos, "the base view is the authentic view")
	tribe.pos = Vector2i.ZERO
	wide.follow_frame(tribe.get_rect())
	assert_eq(wide.pos, Vector2i.ZERO, "kept inside the level")


func test_the_rising_band_pulls_the_view_up_and_it_never_sinks() -> void:
	var camera: LevelCamera = _camera()
	camera.pos.y = 400
	camera.prev = camera.pos
	camera.apply_rising(1000)
	assert_eq(camera.pos.y, 400, "a band far below changes nothing")
	camera.prev = camera.pos
	camera.pos.y = 420  # the follow wanted to sink
	camera.apply_rising(1000)
	assert_eq(camera.pos.y, 400, "never lower than the previous tick")
	camera.prev = camera.pos
	camera.apply_rising(500)
	assert_eq(camera.pos.y, 500 + Tuning.TILE - Tuning.VIEW_ROWS * Tuning.TILE, "the band's top row is the bottom row")
	camera.prev = camera.pos
	camera.apply_rising(10)
	assert_eq(camera.pos.y, 0, "never above the level")
