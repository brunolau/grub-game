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


# =================================================================================================================
# The rising climb: the footing room (LevelCamera._follow_footing, head_peek; PHYSICS.md C.8, the wf10 follow-up of
# G42: "the hero must not climb under the HUD band or leave the top of the view")
# =================================================================================================================

const ROOM: int = LevelCamera.FOOTING_ROOM_PX
## The HUD band on any device (logical px: Hud.band_rects with the touch margin, 14 + 48 art px) and the hero's height.
const BAND_PX: int = 31
const HERO_PX: int = 35
const VIEW_PX: int = Tuning.VIEW_ROWS * Tuning.TILE


## A camera whose band rises (footing mode) with its top `gap` px above FLOOR_Y.
func _rising_camera(gap: int) -> LevelCamera:
	var camera: LevelCamera = _camera()
	camera.footing_mode = true
	camera.pos.y = FLOOR_Y - gap
	camera.prev = camera.pos
	return camera


## Tick `camera` (solo on P1, or the tribe) until it rests; returns its steps (px per tick, the rest tick left out).
func _settle(camera: LevelCamera, group: bool) -> Array[int]:
	var steps: Array[int] = []
	for i: int in 60:
		var before: int = camera.pos.y
		if group:
			camera.tick_group(_party)
		else:
			camera.tick(_a)
		if camera.pos.y == before:
			break
		steps.append(before - camera.pos.y)
	return steps


func test_the_footing_room_and_what_it_buys() -> void:
	assert_eq(ROOM, 72, "a footing is kept 72 px (4.5 rows) under the view's top")
	assert_eq(Hud.band_rects(Vector2(640.0, 360.0), false, false)[0].end.y / float(Tuning.ART_SCALE), float(BAND_PX),
			"the HUD band on a phone: 31 logical px")
	assert_eq(Tuning.HERO_BOX_STAND.y, HERO_PX)
	assert_true(ROOM - HERO_PX > BAND_PX, "standing: his head %d px under the top - under the band" % (ROOM - HERO_PX))
	assert_true(ROOM - 64 >= 8, "the highest standing jump (64 px): the feet stay 8 px inside the view")
	assert_true(VIEW_PX - ROOM >= 6 * Tuning.TILE + 8, "six rows under the footing are in view (the 6-2b painting nook)")
	# The draw-only peek supplies what a jump needs over that: 33 px over the head, at most 4 rows.
	assert_eq(LevelCamera.HEAD_ROOM_PX, BAND_PX + 2)
	assert_eq(LevelCamera.HEAD_PEEK_MAX_PX, 4 * Tuning.TILE)
	assert_true(LevelCamera.HEAD_ROOM_PX - (ROOM - 64 - HERO_PX) <= LevelCamera.HEAD_PEEK_MAX_PX,
			"a standing jump from the footing room is covered by the peek")


func test_every_footing_too_near_the_top_is_brought_down() -> void:
	# G42 as built moved only for a footing on view row 3 or higher and stopped a row later: a hero stood on rows 3-4
	# with his head 13-28 px under the top (in the band).
	for gap: int in [8, 24, 40, 48, 56, 63, 66, 71]:
		var camera: LevelCamera = _rising_camera(gap)
		var steps: Array[int] = _settle(camera, false)
		assert_eq(camera.pos.y, FLOOR_Y - ROOM, "feet %d px under the top: the view rose until they are %d under it" % [
			gap, ROOM])
		assert_true(steps.size() <= 12, "%d px: at rest after %d ticks" % [ROOM - gap, steps.size()])
		for step: int in steps:
			assert_true(step >= 1 and step <= 16, "1 to 16 px per tick (%d)" % step)
	# At the room or lower nothing moves - the view never follows a footing down.
	for gap: int in [ROOM, 80, 100, 128, 160, 175, 200]:
		var camera: LevelCamera = _rising_camera(gap)
		assert_eq(_settle(camera, false), [] as Array[int], "feet %d px under the top: the view stays" % gap)


func test_the_view_catches_up_with_a_landing_three_rows_up() -> void:
	var camera: LevelCamera = _rising_camera(ROOM)
	camera.tick(_a)
	# A ledge three rows up (the 6-2b climb): the hero lands 24 px under the top.
	_a.sim_pos.y = FLOOR_Y - 3 * Tuning.TILE
	var steps: Array[int] = _settle(camera, false)
	assert_eq(steps, [12, 12, 10, 7, 2, 2, 1, 1, 1] as Array[int], "the fast curve of 12.2 for the distance left")
	assert_eq(camera.pos.y, _a.sim_pos.y - ROOM)
	# 41 of the 48 px are done after 4 ticks: his head is under the band again (a jump starts 6 ticks after a landing at
	# the earliest); meanwhile the drawn view covers him (head_peek, below).
	assert_eq(steps[0] + steps[1] + steps[2] + steps[3], 41)
	assert_true(24 + 41 - HERO_PX >= BAND_PX - 1, "4 ticks after the landing: head %d px under the top" % (24 + 41 - HERO_PX))
	# A landing six rows up (a Shoulder Hop, a launch): at rest within 14 ticks.
	_a.sim_pos.y -= 6 * Tuning.TILE
	steps = _settle(camera, false)
	assert_eq(steps[0], 15, "96 px: the curve's second fastest step")
	assert_true(steps.size() <= 14, "at rest after %d ticks" % steps.size())
	assert_eq(camera.pos.y, _a.sim_pos.y - ROOM)


func test_a_jump_never_raises_the_rising_view_and_lands_in_it() -> void:
	var camera: LevelCamera = _rising_camera(ROOM)
	var top: int = camera.pos.y
	camera.tick(_a)  # he stands: the footing is his feet
	assert_eq(camera.footing_of(_a), FLOOR_Y)
	# A standing jump: airborne up to 64 px over the footing, then back.
	_a.grounded = false
	for rise: int in [10, 30, 50, 64, 60, 40, 20, 5]:
		_a.sim_pos.y = FLOOR_Y - rise
		_a.yvel = -64
		camera.tick(_a)
		assert_eq(camera.pos.y, top, "feet %d px over the footing: the view stays" % rise)
		assert_true(_a.sim_pos.y - camera.pos.y >= 8, "his feet stay on the view")
	_a.sim_pos.y = FLOOR_Y
	_a.yvel = 0
	_a.grounded = true
	camera.tick(_a)
	assert_eq(camera.pos.y, top, "landed where he stood: nothing moved")
	# A lower footing never brings the view down: six rows down he is still in view.
	_a.sim_pos.y = FLOOR_Y + 6 * Tuning.TILE
	camera.tick(_a)
	assert_eq(camera.pos.y, top, "six rows down: the view stays")
	assert_true(_a.sim_pos.y - camera.pos.y <= VIEW_PX - 8, "and his feet are 8 px over its bottom edge")


func test_a_vine_climber_is_followed_as_he_rises() -> void:
	var camera: LevelCamera = _rising_camera(ROOM)
	camera.tick(_a)
	# A climber on a vine (2 px per tick): his own y is his footing.
	_a.grounded = false
	_a.state = Defs.HeroState.CLIMB
	var worst: int = ROOM
	for i: int in 60:
		_a.sim_pos.y -= 2
		camera.tick(_a)
		worst = mini(worst, _a.sim_pos.y - camera.pos.y)
	assert_true(worst >= ROOM - 5, "the view rises with the climber: never more than 5 px short (%d)" % worst)
	assert_true(worst - HERO_PX >= BAND_PX, "his head is under the band all the way (%d px)" % (worst - HERO_PX))
	_a.state = Defs.HeroState.IDLE
	_a.grounded = true
	assert_true(_settle(camera, false).size() <= 4)
	assert_eq(camera.pos.y, _a.sim_pos.y - ROOM)


func test_a_party_is_followed_by_its_highest_footing() -> void:
	# Together on one ledge: as one hero.
	var camera: LevelCamera = _rising_camera(40)
	_at(camera, _a, 8)
	_at(camera, _b, 10)
	_settle(camera, true)
	assert_eq(camera.pos.y, FLOOR_Y - ROOM, "both on the floor")
	# Whoever climbs ahead - P1 is the 1.0 anchor (the lower slot), so P2 leading is the case the old follow missed.
	for leader: PlayerBase in [_b, _a]:
		var other: PlayerBase = _a if leader == _b else _b
		for rows_apart: int in [1, 3, 6]:
			other.sim_pos.y = FLOOR_Y
			leader.sim_pos.y = FLOOR_Y
			camera.pos.y = FLOOR_Y - ROOM
			camera.prev = camera.pos
			camera.tick_group(_party)
			leader.sim_pos.y = FLOOR_Y - rows_apart * Tuning.TILE
			_settle(camera, true)
			var who: String = "P%d leads by %d row(s)" % [leader.slot + 1, rows_apart]
			assert_eq(leader.sim_pos.y - camera.pos.y, ROOM, who + ": the view rests on his footing")
			assert_true(leader.sim_pos.y - HERO_PX - camera.pos.y > BAND_PX, who + ": his head under the band")
			assert_true(other.sim_pos.y - camera.pos.y <= VIEW_PX, who + ": his partner is on the view")
		# Seven rows behind the partner is under the view: the leash's and the band's case, never the leader's.
		other.sim_pos.y = FLOOR_Y
		leader.sim_pos.y = FLOOR_Y - 7 * Tuning.TILE
		_settle(camera, true)
		assert_eq(leader.sim_pos.y - camera.pos.y, ROOM)
		assert_true(other.sim_pos.y - camera.pos.y > VIEW_PX, "seven rows behind: under the view")
	# The view never comes down when the leader drops back.
	var top: int = camera.pos.y
	_a.sim_pos.y = FLOOR_Y
	_b.sim_pos.y = FLOOR_Y
	assert_eq(_settle(camera, true), [] as Array[int])
	assert_eq(camera.pos.y, top)


func test_a_partners_jump_or_egg_does_not_move_the_rising_view() -> void:
	var camera: LevelCamera = _rising_camera(ROOM)
	_at(camera, _a, 8)
	_at(camera, _b, 10)
	var top: int = camera.pos.y
	camera.tick_group(_party)  # both stand: their footings
	# P2 jumps while P1 stands (and the other way round): footings, not feet.
	for jumper: PlayerBase in [_b, _a]:
		jumper.grounded = false
		jumper.yvel = -64
		for rise: int in [20, 50, 64, 40, 10]:
			jumper.sim_pos.y = FLOOR_Y - rise
			camera.tick_group(_party)
			assert_eq(camera.pos.y, top, "P%d jumps %d px: the view stays" % [jumper.slot + 1, rise])
		jumper.sim_pos.y = FLOOR_Y
		jumper.yvel = 0
		jumper.grounded = true
	# An egg is not of the tribe: the view follows the hatched hero alone.
	_b.down = true
	_b.sim_pos.y = FLOOR_Y - 9 * Tuning.TILE
	_a.sim_pos.y = FLOOR_Y - 3 * Tuning.TILE
	_settle(camera, true)
	assert_eq(camera.pos.y, _a.sim_pos.y - ROOM, "P1's footing alone")
	_b.down = false


func test_the_footing_is_known_before_the_band_starts_to_rise() -> void:
	# The band waits for the first input (footing_mode off); the level already has the camera watch the footings
	# (footing_watch). A hero whose first input is a jump is then followed by the ground he left, not by his jump.
	var camera: LevelCamera = _camera()
	camera.footing_watch = true
	camera.pos.y = FLOOR_Y - 100
	camera.prev = camera.pos
	camera.tick(_a)
	assert_eq(camera.footing_of(_a), FLOOR_Y, "kept while the band waits")
	var top: int = camera.pos.y
	camera.footing_mode = true
	_a.grounded = false
	_a.yvel = -64
	for rise: int in [20, 45, 64, 50, 20]:
		_a.sim_pos.y = FLOOR_Y - rise
		camera.tick(_a)
		assert_eq(camera.pos.y, top, "his first jump (%d px): the view stays" % rise)
	# Without the watch his own y would stand in for the footing (the fallback before a first footing).
	var blind: LevelCamera = _camera()
	_a.sim_pos.y = FLOOR_Y - 64
	assert_eq(blind.footing_of(_a), FLOOR_Y - 64, "no footing known: his current feet")
	_a.sim_pos.y = FLOOR_Y
	_a.grounded = true
	_a.yvel = 0


func test_the_head_peek_is_a_bounded_look_up_of_the_drawn_view() -> void:
	var top: float = 1000.0
	var view: float = float(VIEW_PX)
	var room: float = float(LevelCamera.HEAD_ROOM_PX)
	# Standing at the footing room: head 37 px under the top - nothing to do.
	assert_eq(LevelCamera.head_peek(top, top + float(ROOM - HERO_PX), top + float(ROOM), view, 0.0), 0.0)
	# The apex of the highest standing jump from there: head 27 px over the top - 60 px of look-up, the head 33 under
	# the drawn top.
	var head: float = top + float(ROOM - 64 - HERO_PX)
	var peek: float = LevelCamera.head_peek(top, head, head + float(HERO_PX), view, 0.0)
	assert_eq(peek, room + 27.0)
	assert_eq(head - (top - peek), room, "the head sits %d px under the drawn top" % LevelCamera.HEAD_ROOM_PX)
	# A landing three rows up, before the view has caught up: head 11 px over the top.
	head = top + float(ROOM - 48 - HERO_PX)
	assert_eq(LevelCamera.head_peek(top, head, head + float(HERO_PX), view, 0.0), room + 11.0)
	# A 105 px launch: capped at four rows - the feet are on the drawn view, the head over it for the apex.
	head = top + float(ROOM - 105 - HERO_PX)
	peek = LevelCamera.head_peek(top, head, head + float(HERO_PX), view, 0.0)
	assert_eq(peek, float(LevelCamera.HEAD_PEEK_MAX_PX))
	assert_true(head + float(HERO_PX) - (top - peek) >= 0.0, "his feet are on the drawn view")
	# Never so far that the lowest feet of the tribe leave the bottom: a partner 20 px over the bottom edge allows 20.
	head = top + float(ROOM - 64 - HERO_PX)
	assert_eq(LevelCamera.head_peek(top, head, top + view - 20.0, view, 0.0), 20.0)
	assert_eq(LevelCamera.head_peek(top, head, top + view + 30.0, view, 0.0), 0.0, "a partner already under the view: none")
	# Never above the level's top.
	assert_eq(LevelCamera.head_peek(top, head, head + float(HERO_PX), view, top - 10.0), 10.0)
	assert_eq(LevelCamera.head_peek(top, head, head + float(HERO_PX), view, top), 0.0)


func test_outside_a_rising_climb_the_follow_is_the_1_0_rule() -> void:
	# The same footing on view row 5 without the rising band: 12.2's ground rule does not move (rows 4-9 are its rest).
	var camera: LevelCamera = _camera()
	camera.pos.y = FLOOR_Y - 88
	camera.prev = camera.pos
	for i: int in 20:
		camera.tick(_a)
	assert_eq(camera.pos.y, FLOOR_Y - 88, "no footing mode: the 1.0 follow, untouched")
	var tribe: LevelCamera = _camera()
	tribe.pos.y = FLOOR_Y - 88
	tribe.prev = tribe.pos
	_at(tribe, _a, 8)
	_at(tribe, _b, 10)
	for i: int in 20:
		tribe.tick_group(_party)
	assert_eq(tribe.pos.y, FLOOR_Y - 88, "nor does the tribe camera")
