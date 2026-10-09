extends TestCase
## Book II objects of objects-B (docs/expansion/PLAN.md P1.10): `items/painting` (DESIGN.md C.9), `objects/vine` and
## rolled vines (C.3, PHYSICS.md C.4), `objects/bark_board` + `objects/spear_step` (C.2, PHYSICS.md C.3),
## `objects/geyser` (C.4, PHYSICS.md C.6), `objects/raft` with currents (C.5, PHYSICS.md C.7) and `objects/mount` +
## `objects/rex_pen` (C.8, PHYSICS.md C.9; the mount table is pinned by docs/spec/PARTY_REFERENCE.json), plus
## levels/test_objects_book2.lvl through the real loader and the validator.

const LEVEL_SCENE: String = "res://scenes/world/level.tscn"
const PLAYER_SCENE: String = "res://scenes/player/player.tscn"
const BOOK2_LEVEL: String = "res://levels/test_objects_book2.lvl"
const PARTY_REFERENCE_PATH: String = "res://docs/spec/PARTY_REFERENCE.json"
const BASE_VIEW: Vector2i = Vector2i(640, 360)


## A flying spear as player-B's projectile will be: a 24 x 6 box (x_offset 12), xvel 192, its thrower's slot.
class FakeSpear:
	extends SimEntity

	var owner_slot: int = 0

	func _init() -> void:
		set_box(Vector3i(Tuning.SPEAR_BOX_W, Tuning.SPEAR_BOX_H, Tuning.SPEAR_BOX_XO))


## A heave boulder that says it plugs whatever vent it is asked about.
class FakeBoulder:
	extends SimEntity

	var plugging: bool = true

	func plugs_vent(_vent: Rect2i) -> bool:
		return plugging


var level: LevelBase = null
var _was_manual: bool = false
var _found: Array[int] = []
var _spots_opened: int = 0
static var _party_reference: Dictionary = {}


func before_each() -> void:
	_was_manual = Sim.manual
	Game.new_game(Defs.Difficulty.BEGINNER)
	Game.begin_level(&"test_objects_book2")
	Sim.start(1)
	_found.clear()
	_spots_opened = 0
	if not Events.painting_found.is_connected(_on_painting_found):
		Events.painting_found.connect(_on_painting_found)
	if not Events.hidden_spot_opened.is_connected(_on_spot_opened):
		Events.hidden_spot_opened.connect(_on_spot_opened)


func after_each() -> void:
	Events.painting_found.disconnect(_on_painting_found)
	Events.hidden_spot_opened.disconnect(_on_spot_opened)
	Sim.stop()
	Sim.manual = _was_manual
	GameInput.clear_scripted()
	Game.new_game(Defs.Difficulty.BEGINNER)
	Game.begin_level(&"")
	Audio.stop_music(0.0)


func _on_painting_found(index: int) -> void:
	_found.append(index)


func _on_spot_opened(_pos: Vector2i, _kind: StringName) -> void:
	_spots_opened += 1


static func party_reference() -> Dictionary:
	if _party_reference.is_empty():
		var json: JSON = JSON.new()
		if json.parse(FileAccess.get_file_as_string(PARTY_REFERENCE_PATH)) == OK and json.data is Dictionary:
			_party_reference = json.data
	return _party_reference


## A level from tile rows (the legend characters of the level files), one screen or more.
func _rows(rows: Array) -> LevelBase:
	level = make_level(PackedStringArray(rows))
	return level


## A bare hero (no controller) of player slot `slot` standing at `pos`.
func _hero(pos: Vector2i, slot: int = 0) -> PlayerBase:
	var hero: PlayerBase = PlayerBase.new()
	place(level, hero, pos, {"slot": slot})
	hero.respawn_at(pos)
	return hero


## The real hero (scene) at `pos`.
func _player(pos: Vector2i) -> Player:
	var hero: Player = (load(PLAYER_SCENE) as PackedScene).instantiate() as Player
	hero.spawn_setup(pos, {})
	level.add_child(hero)
	hero.respawn_at(pos)
	return hero


func _spawn(id: StringName, col: float, row: float, params: Dictionary = {}) -> Node:
	return level.spawn(id, LevelText.cell_to_feet(col, row), params)


# =================================================================================================================
# Cave Paintings
# =================================================================================================================

func test_a_painting_is_saved_announced_and_pays_its_points() -> void:
	Save.reset()
	_rows(["....................", "....................", "####################"])
	var painting: Painting = _spawn(&"items/painting", 5, 1, {"index": 7}) as Painting
	assert_not_null(painting, "items/painting has a scene")
	assert_eq(painting.points, Tuning.PAINTING_POINTS)
	assert_false(painting.found_before)
	assert_false(painting.expires, "a key item: never blinks away when dropped")
	var score: int = Game.score
	_hero(painting.sim_pos)
	Sim.step(1)
	assert_true(painting.collected)
	assert_true(Save.has_painting(7), "recorded profile-wide")
	assert_eq(_found, [7] as Array[int], "Events.painting_found(index)")
	assert_true(painting.was_new)
	assert_eq(Game.score - score, Tuning.PAINTING_POINTS)
	Save.reset()


func test_a_painting_found_before_shows_as_an_outline_and_pays_again() -> void:
	Save.reset()
	Save.add_painting(3)
	_rows(["....................", "....................", "####################"])
	var painting: Painting = _spawn(&"items/painting", 5, 1, {"index": 3}) as Painting
	assert_true(painting.found_before, "drawn as an outline")
	var count: int = Save.painting_count()
	var score: int = Game.score
	_hero(painting.sim_pos)
	Sim.step(1)
	assert_true(painting.collected)
	assert_false(painting.was_new, "not counted twice")
	assert_eq(Save.painting_count(), count)
	assert_eq(Game.score - score, Tuning.PAINTING_POINTS, "its points are paid again")
	assert_eq(_found, [3] as Array[int])
	Save.reset()


func test_a_painting_index_out_of_range_is_clamped() -> void:
	_rows(["....................", "####################"])
	var painting: Painting = _spawn(&"items/painting", 2, 0, {"index": 40}) as Painting
	assert_eq(painting.index, Tuning.PAINTING_COUNT - 1)


# =================================================================================================================
# Vines
# =================================================================================================================

## Ledge cells 6-9 in row 6 (surface y 96), ground in row 12 (y 192), a vine of `length` anchored at (10, 6).
func _vine_level(params: Dictionary) -> Vine:
	var rows: Array = []
	for row: int in 12:
		rows.append("......####.........." if row == 6 else "....................")
	rows.append("####################")
	_rows(rows)
	return _spawn(&"objects/vine", 10, 6, params) as Vine


func test_vine_geometry_and_reach() -> void:
	var vine: Vine = _vine_level({"length": 5})
	assert_not_null(vine, "objects/vine has a scene")
	assert_eq(vine.vine_x, 168, "the anchor cell's centre")
	assert_eq(vine.top, 96, "the anchor cell's top")
	assert_eq(vine.bottom, 176, "top + 16 * length")
	assert_eq(vine.sim_pos, Vector2i(168, 96), "its anchor point")
	assert_true(vine.is_climbable())
	assert_true(vine.reaches(168, 192), "from the ground: the hands (32 px up) reach the bottom")
	assert_true(vine.reaches(174, 192), "6 px aside")
	assert_false(vine.reaches(175, 192), "7 px aside")
	assert_false(vine.reaches(168, 209), "the hands below the bottom")
	assert_true(vine.reaches(168, 208))
	assert_false(vine.reaches(168, 96), "feet at the top: on the ledge, not on the vine")
	assert_true(vine.reaches(168, 97))
	assert_eq(Vine.find_grab(level, 170, 192), vine)
	assert_null(Vine.find_grab(level, 170, 192, vine), "the vine under a re-grab lock is skipped")
	assert_null(Vine.find_grab(level, 100, 192))
	assert_true(Vine.level_has_vines(level))
	assert_false(vine.is_hit_by(Vector2i(191, 94)), "weapons pass a hanging vine")


func test_vine_defaults() -> void:
	var vine: Vine = _vine_level({})
	assert_eq(vine.length, 4, "length [4]")
	assert_false(vine.rolled, "rolled [false]")
	assert_eq(vine.bottom, 96 + 64)


func test_a_rolled_vine_is_unrolled_by_a_strike_on_its_coil() -> void:
	var vine: Vine = _vine_level({"length": 5, "rolled": true})
	assert_true(vine.rolled)
	assert_false(vine.is_climbable(), "coiled: nothing to grab")
	assert_null(Vine.find_grab(level, 168, 192))
	assert_eq(vine.cell, Vector2i(10, 5), "the cell beside the ledge top (and the anchor cell under it)")
	assert_eq(vine.coil_rect(), Rect2i(160, 80, 16, 32))
	# A hero on the ledge (feet 96) striking forward: the club origin is 23 px ahead, 2 px over his feet.
	var origin: Vector2i = Vector2i(152 + 23, 96 - 2)
	assert_true(vine.is_hit_by(origin), "the forward strike from the ledge reaches the coil")
	assert_true(vine.is_hit_by(Vector2i(152 + 9, 96 + 10)), "so does the low strike (origin 9 px ahead, 10 below)")
	assert_false(vine.is_hit_by(Vector2i(152 + 23, 96 - 40)), "a box far above misses")
	assert_false(vine.is_hit_by(Vector2i(130, 94)), "two columns away misses")
	assert_true(vine.take_hit(25, null), "the box is consumed")
	assert_true(vine.unrolled)
	assert_false(vine.is_climbable(), "while it unrolls (8 ticks)")
	assert_false(vine.is_hit_by(origin), "only once")
	Sim.step(Vine.UNROLL_TICKS - 1)
	assert_false(vine.is_climbable())
	Sim.step(1)
	assert_true(vine.is_climbable())
	assert_eq(Vine.find_grab(level, 168, 192), vine)
	assert_eq(_spots_opened, 0, "never a hidden spot (no Events.hidden_spot_opened, no completion count)")
	level.reset_entities()
	assert_true(vine.unrolled and vine.is_climbable(), "stays unrolled through a death")


func test_the_heros_club_pass_unrolls_the_coil() -> void:
	var vine: Vine = _vine_level({"length": 5, "rolled": true})
	var hero: Player = _player(Vector2i(152, 96))
	hero.club_box_active = true
	hero.club_origin = Vector2i(175, 94)
	hero.club_box = Rect2i(163, 81, 24, 13)
	hero.club_box_xo = 12
	hero.club_power = 25
	Sim.step(1)
	assert_true(vine.unrolled, "the WEAPONS pass of the hero found the coil")


func test_a_batted_ball_unrolls_a_vine_once() -> void:
	var vine: Vine = _vine_level({"rolled": true})
	assert_true(vine.unroll(null))
	assert_false(vine.unroll(null), "already unrolled")


## The coil rule (DESIGN.md G67 (1), PHYSICS.md C.4): in a co-op file a rolled vine unrolls only for a hit from its
## own level - the hitting hero's feet at most one row under the coil's ledge; any other hit passes the coil.
func test_in_a_coop_file_the_coil_unrolls_only_for_a_hit_from_its_own_level() -> void:
	var vine: Vine = _vine_level({"length": 5, "rolled": true})
	assert_false(Vine.coil_rule_on(), "a solo file: any hit unrolls")
	var hero: Player = _player(Vector2i(152, vine.top + Vine.COIL_LEVEL_PX + 1))
	assert_eq(level.get_hero(0), hero)
	assert_true(vine.hit_from_its_level(hero), "solo: the rule is off wherever the hero stands")
	level.meta["kind"] = "coop"
	assert_true(Vine.coil_rule_on(), "a co-op file")
	assert_false(vine.hit_from_its_level(hero), "his feet 17 px under the ledge: not from its level")
	assert_false(vine.take_hit(25, hero), "the hit passes the coil: the box is not consumed")
	assert_false(vine.unrolled, "and nothing unrolls")
	# A thrown weapon counts by its thrower's feet at the moment it hits; the ball by its own.
	var axe: ProjectileBase = ProjectileBase.new()
	axe.from_hero = true
	axe.owner_slot = 0
	assert_false(vine.take_hit(25, axe), "his axe from the floor below passes too")
	assert_false(vine.unroll(hero), "and so does he as a batted ball that is still under the ledge")
	assert_false(vine.unrolled)
	# (respawn_at: he STANDS there - the rule asks for the ground under him too, G81 below.)
	hero.respawn_at(Vector2i(152, vine.top + Vine.COIL_LEVEL_PX))
	assert_true(vine.hit_from_its_level(hero), "feet y <= top + 16: one row under the ledge still counts")
	hero.respawn_at(Vector2i(152, vine.top))
	assert_true(vine.take_hit(25, axe), "thrown from the ledge the axe unrolls it")
	assert_true(vine.unrolled)
	axe.free()
	# A hit nobody's hero made (a tool, a test) unrolls as before.
	var second: Vine = _spawn(&"objects/vine", 12, 6, {"rolled": true}) as Vine
	assert_true(second.take_hit(25, null))
	level.meta["kind"] = "test"


## G81 (the seventh cause of the G3c round: the coil rule was met IN MID-AIR): "its own level" is where the hitter
## STANDS. The top of a jump or of a bounce from a place under the coil's level brings his feet there for a few ticks -
## a special thrown then unrolled the coil 8 columns away (w2_l2_coop and w6_l2_coop 'seesaw',
## tools/coop_explore/evidence/*.coil_from_drop_ledge.txt, *.wf11_explorer.txt). The rule asks for the ground he last
## had under his feet as well; a batted ball is its own delivery and must only count.
func test_the_coil_asks_where_the_hitter_stands_not_where_a_jump_took_his_feet() -> void:
	var vine: Vine = _vine_level({"length": 5, "rolled": true})
	var shelf_y: int = vine.top + 3 * Tuning.TILE   # a place 3 rows under the coil's ledge: within a jump of its level
	var hero: Player = _player(Vector2i(152, shelf_y))
	var axe: ProjectileBase = ProjectileBase.new()
	axe.from_hero = true
	axe.owner_slot = 0
	# The top of his jump: feet at the coil's level, the ground he left 3 rows under it.
	hero.teleport(Vector2i(152, vine.top + 8))
	assert_eq(hero.last_ground_y, shelf_y, "the set-up: in the air over the shelf")
	assert_true(vine.hit_from_its_level(hero), "a solo file: the rule is off")
	level.meta["kind"] = "coop"
	assert_false(vine.hit_from_its_level(hero), "a co-op file: his feet are there, he does not stand there")
	assert_false(vine.take_hit(25, hero), "his strike at the top of the jump passes the coil")
	assert_false(vine.take_hit(25, axe), "and so does the special he throws then")
	assert_false(vine.unrolled)
	# A bounce carries him higher still - over the ledge: no better.
	hero.teleport(Vector2i(152, vine.top - 40))
	assert_false(vine.take_hit(25, axe), "over the coil's ledge at the top of a bounce: still not standing on its level")
	# He lands on the ledge (the ground is his now) and jumps: the strike hop and the jump of a hero who stands there
	# keep the coil.
	hero.respawn_at(Vector2i(152, vine.top))
	hero.teleport(Vector2i(152, vine.top - 30))
	assert_true(vine.hit_from_its_level(hero), "a jump from the coil's own ledge is from its level")
	# ... and falls past it: the feet rule of G67 still holds for him.
	hero.teleport(Vector2i(152, vine.top + Vine.COIL_LEVEL_PX + 1))
	assert_false(vine.hit_from_its_level(hero), "17 px under the ledge on the way down: not from its level")
	# A batted ball is its own delivery (a lob lands him on the ledge): the ball's feet at the level are enough -
	# when the batted hero counts.
	hero.respawn_at(Vector2i(152, shelf_y))
	hero.teleport(Vector2i(152, vine.top + 8))
	hero.curl = PlayerBase.CURL_BALL
	assert_true(vine.hit_from_its_level(hero), "the ball at the coil's level unrolls it, wherever it was batted from")
	hero.idle = true
	assert_false(vine.hit_from_its_level(hero), "a dozing partner batted at the coil counts for nobody")
	hero.idle = false
	assert_true(vine.unroll(hero), "the ball unrolls it")
	hero.curl = PlayerBase.CURL_NONE
	axe.free()
	level.meta["kind"] = "test"


## The same with the real hero's own jump: from a shelf 3 rows under the ledge he jumps with Up held; on every tick his
## feet are within a row of the coil's ledge the coil is asked - never from its level in a co-op file, on some ticks
## in a solo file (the 1.0 hittable pass asks nothing).
func test_a_jump_from_three_rows_under_the_coil_never_meets_its_level_in_a_coop_file() -> void:
	for coop: bool in [false, true]:
		var rows: Array = []
		for row: int in 12:
			var line: String = "...................."
			if row == 3:
				line = "......####.........."   # the coil's ledge (top y 48)
			elif row == 6:
				line = "..............####.."   # the shelf, 3 rows under it (top y 96)
			rows.append(line)
		rows.append("####################")
		_rows(rows)
		level.meta["kind"] = "coop" if coop else "test"
		var vine: Vine = _spawn(&"objects/vine", 10, 3, {"length": 8, "rolled": true}) as Vine
		var hero: Player = _player(Vector2i(250, 96))
		var at_level: Array[int] = [0]
		var allowed: Array[int] = [0]
		GameInput.set_scripted_slot(0, func(_tick: int) -> int: return Defs.IN_UP)
		for _i: int in 40:
			Sim.step(1)
			if hero.sim_pos.y <= vine.top + Vine.COIL_LEVEL_PX:
				at_level[0] += 1
				if vine.hit_from_its_level(hero):
					allowed[0] += 1
		GameInput.clear_scripted()
		assert_true(at_level[0] >= 3, "the set-up: the jump brings his feet to the coil's level for %d tick(s)" % at_level[0])
		if coop:
			assert_eq(allowed[0], 0, "a co-op file: on none of them is he a hitter from its level")
		else:
			assert_eq(allowed[0], at_level[0], "a solo file: any hit unrolls")
		hero.free()
		level.free()
		level = null


## End to end with the real hero (DB1's probe of 1-2 'treehouse', G67): on the floor 8 rows under a boost ledge he
## plays the hop jump with a high strike - a low strike, Up from its 8th tick, a high strike from tick 10-16 - whose
## box reaches 123 px: the coil at the ledge's edge. In a solo file that unrolls the vine (1.0 hittable pass); in a
## co-op file it never does, and a strike from the ledge still does.
func test_a_hop_jump_strike_from_the_floor_below_opens_a_solo_coil_and_never_a_coop_one() -> void:
	for coop: bool in [false, true]:
		var opened: int = 0
		var best: int = 0
		for strike_tick: int in [10, 12, 13, 14, 16]:
			for x: int in [170, 178, 186]:
				var vine: Vine = _boost_ledge(coop)
				var floor_y: int = 11 * Tuning.TILE
				var hero: Player = _player(Vector2i(x, floor_y))
				hero.facing = -1
				var lowest: Array[int] = [floor_y]
				var tick: Array[int] = [0]
				GameInput.set_scripted_slot(0, func(_tick: int) -> int:
					var n: int = tick[0]
					tick[0] += 1
					var keys: int = (Defs.IN_FIRE | Defs.IN_DOWN) if n < 8 else Defs.IN_UP
					if n >= strike_tick and n < strike_tick + 8:
						keys = Defs.IN_UP | Defs.IN_FIRE
					return keys)
				for _i: int in 60:
					Sim.step(1)
					lowest[0] = mini(lowest[0], hero.sim_pos.y)
				GameInput.clear_scripted()
				best = maxi(best, floor_y - lowest[0])
				if vine.unrolled:
					opened += 1
				if coop and not vine.unrolled:
					# The same coil from its own level: a hero standing on the ledge strikes it open.
					hero.respawn_at(Vector2i(152, vine.top))
					assert_true(vine.take_hit(25, hero), "from the ledge the coil unrolls")
				hero.free()
				level.free()
				level = null
		if coop:
			assert_eq(opened, 0, "a co-op file: no hop-jump strike from the floor below unrolls the coil (15 trials)")
			assert_true(best >= 70 and best < 7 * Tuning.TILE - Tuning.TILE, "and his feet rise %d px: over a" % best 					+ " standing jump's 64, under the corner catch of even a 7-row ledge (96)")
		else:
			# (Solo: the strike that unrolls it is a pogo, and with Up held he grabs the vine and climbs - the way
			# through the gate that DB1's one-player bot found.)
			assert_true(opened > 0, "a solo file: the high strike of a hop jump reaches the coil 8 rows up (%d of 15)" % opened)


## An 8-row boost ledge (top row 3, cols 6-9) over the floor (row 11: inside the 11 rows of the bare level's view) with
## a rolled vine at its edge (cell 10, 3).
func _boost_ledge(coop: bool) -> Vine:
	var rows: Array = []
	for row: int in 11:
		rows.append("......####.........." if row >= 3 and row <= 4 else "....................")
	rows.append("####################")
	_rows(rows)
	level.meta["kind"] = "coop" if coop else "test"
	return _spawn(&"objects/vine", 10, 3, {"length": 8, "rolled": true}) as Vine


# =================================================================================================================
# Bark boards and spear steps
# =================================================================================================================

## A palisade in column 10 (rows 4-9) on the ground row 10, a bark board in its cell (10, 8).
func _board_level(params: Dictionary = {}) -> BarkBoard:
	var rows: Array = []
	for row: int in 10:
		rows.append("..........#........." if row >= 4 else "....................")
	rows.append("####################")
	rows.append("####################")
	_rows(rows)
	return _spawn(&"objects/bark_board", 10, 8, params) as BarkBoard


func _spear(pos: Vector2i, xvel: int, slot: int = 0) -> FakeSpear:
	var spear: FakeSpear = FakeSpear.new()
	spear.owner_slot = slot
	place(level, spear, pos)
	spear.xvel = xvel
	return spear


func test_bark_board_faces_and_catching() -> void:
	var board: BarkBoard = _board_level({"face": "l"})
	assert_not_null(board, "objects/bark_board has a scene")
	assert_eq(board.cell, Vector2i(10, 8))
	assert_eq(board.get_face(), -1, "face=l: the air is on the left")
	# A spear flying right (into the left face), its box over the board's cell.
	var spear: FakeSpear = _spear(Vector2i(158, 140), Tuning.SPEAR_XVEL)
	assert_true(board.catches(spear))
	assert_eq(BarkBoard.find_catching(level, spear), board)
	spear.xvel = -Tuning.SPEAR_XVEL
	assert_false(board.catches(spear), "a spear flying out of the face")
	spear.xvel = Tuning.SPEAR_XVEL
	spear.teleport(Vector2i(158, 170))
	assert_false(board.catches(spear), "below the board's cell")
	spear.teleport(Vector2i(140, 140))
	assert_false(board.catches(spear), "not there yet")
	assert_null(BarkBoard.find_catching(level, spear))


func test_bark_board_face_found_from_the_tiles() -> void:
	var rows: Array = []
	for row: int in 10:
		rows.append(".........##........." if row >= 4 else "....................")
	rows.append("####################")
	_rows(rows)
	var right_open: BarkBoard = _spawn(&"objects/bark_board", 10, 6) as BarkBoard
	var left_open: BarkBoard = _spawn(&"objects/bark_board", 9, 6) as BarkBoard
	assert_eq(right_open.get_face(), 1, "air on the right")
	assert_eq(left_open.get_face(), -1, "air on the left")


func test_a_spear_sticks_and_makes_one_step() -> void:
	var board: BarkBoard = _board_level({"face": "l"})
	var spear: FakeSpear = _spear(Vector2i(158, 140), Tuning.SPEAR_XVEL, 1)
	var step: SpearStep = board.stick(spear)
	assert_not_null(step, "objects/spear_step spawned")
	assert_eq(board.step, step)
	assert_true(board.has_step())
	assert_eq(step.owner_slot, 1, "the thrower")
	assert_eq(step.box_w, Tuning.BARK_BOARD_STEP_W)
	assert_eq(step.sim_pos.x, 9 * 16 + 8, "in the air cell in front of the face")
	assert_eq(step.sim_pos.y - step.box_h, 8 * 16, "its top on the top edge of the board's cell")
	assert_eq(step.life, Tuning.BARK_BOARD_STEP_TICKS)
	assert_eq(board.sticks, 1)
	var second: FakeSpear = _spear(Vector2i(158, 140), Tuning.SPEAR_XVEL)
	assert_null(board.stick(second), "one step per board: the second spear glances off")
	assert_eq(board.glances, 1)


func test_a_spear_step_carries_a_hero_then_blinks_and_falls() -> void:
	var board: BarkBoard = _board_level({"face": "l"})
	var step: SpearStep = board.stick(_spear(Vector2i(158, 140), Tuning.SPEAR_XVEL))
	Sim.step(1)
	var hero: PlayerBase = _hero(Vector2i(step.sim_pos.x, step.sim_pos.y - step.box_h + 1))
	hero.yvel = 1
	Sim.step(1)
	assert_true(step.ridden, "a hero stands on the step")
	assert_true(hero.on_platform)
	assert_eq(hero.sim_pos.y, 8 * 16 + 1, "on its top")
	Sim.step(Tuning.BARK_BOARD_STEP_TICKS - Tuning.BARK_BOARD_BLINK_TICKS - 3)
	assert_eq(step.life, Tuning.BARK_BOARD_BLINK_TICKS + 1)
	assert_true(step.visible, "before the blink")
	var blinked: bool = false
	for i: int in Tuning.BARK_BOARD_BLINK_TICKS:
		Sim.step(1)
		blinked = blinked or not step.visible
		assert_true(step.is_solid(), "solid while it blinks (tick %d)" % i)
	assert_true(blinked, "it blinks in its last %d ticks" % Tuning.BARK_BOARD_BLINK_TICKS)
	Sim.step(1)
	assert_false(step.is_solid(), "gone after %d ticks" % Tuning.BARK_BOARD_STEP_TICKS)
	hero.on_platform = false
	Sim.step(1)
	assert_false(step.ridden, "riders fall")
	assert_false(board.has_step())
	assert_not_null(board.stick(_spear(Vector2i(158, 140), Tuning.SPEAR_XVEL)), "a new spear makes a new step")


func test_a_pulled_spear_collapses_its_step_at_once() -> void:
	var board: BarkBoard = _board_level({"face": "l"})
	var step: SpearStep = board.stick(_spear(Vector2i(158, 140), Tuning.SPEAR_XVEL))
	step.collapse()
	assert_false(step.is_solid())
	assert_false(board.has_step())
	var other: SpearStep = board.stick(_spear(Vector2i(158, 140), Tuning.SPEAR_XVEL))
	assert_not_null(other)
	level.reset_entities()
	assert_false(other.is_solid(), "a level reset removes the steps")


## player-B's real spear (projectiles/hero_spear, looked up by id: no class reference) meets the board in its own
## PROJECTILES move and leaves a step; a second spear glances off while the step stands.
func test_the_real_hero_spear_sticks_and_glances() -> void:
	var board: BarkBoard = _board_level({"face": "l"})
	if not Spawner.exists(&"projectiles/hero_spear"):
		assert_true(true, "projectiles/hero_spear is not built yet")
		return
	var params: Dictionary = {
		"from_hero": true, "power": Tuning.SPEAR_POWER, "xvel": Tuning.SPEAR_XVEL, "yvel": 0, "yacc": 0,
		"facing": "r", "owner": 0,
	}
	var spear: SimEntity = level.spawn(&"projectiles/hero_spear", Vector2i(110, 140), params) as SimEntity
	assert_not_null(spear)
	Sim.step(5)
	assert_true(board.has_step(), "the spear stuck: a step stands")
	assert_eq(board.step.owner_slot, 0, "the thrower's slot")
	assert_true(not is_instance_valid(spear) or spear.is_queued_for_deletion() or not spear.visible,
			"the flying spear is gone")
	var second: SimEntity = level.spawn(&"projectiles/hero_spear", Vector2i(110, 140), params) as SimEntity
	Sim.step(5)
	assert_eq(board.glances, 1, "one step per board: the second spear glances off")
	assert_true(not is_instance_valid(second) or second.is_queued_for_deletion() or not second.visible)


func test_a_right_face_step_stands_right_of_the_wall() -> void:
	var board: BarkBoard = _board_level({"face": "r"})
	var step: SpearStep = board.stick(_spear(Vector2i(170, 140), -Tuning.SPEAR_XVEL))
	assert_not_null(step)
	assert_eq(step.sim_pos.x, 11 * 16 + 8)
	assert_eq(step.face, 1)


# =================================================================================================================
# Geysers
# =================================================================================================================

func _geyser_level() -> void:
	_rows([
		"....................", "....................", "....................", "....................",
		"....................", "....................", "....................", "....................",
		"....................", "....................", "####################", "####################",
	])


func test_geyser_cycle_is_a_function_of_the_tick() -> void:
	var period: int = 88
	for tick: int in period * 2:
		var p: int = tick % period
		var expected: int = Geyser.Cycle.IDLE
		if p >= period - Tuning.GEYSER_SPOUT_TICKS:
			expected = Geyser.Cycle.SPOUT
		elif p >= period - Tuning.GEYSER_SPOUT_TICKS - Tuning.GEYSER_BUBBLE_TICKS:
			expected = Geyser.Cycle.BUBBLE
		assert_eq(Geyser.cycle_at(tick, period, 0), expected, "tick %d" % tick)
	assert_eq(Geyser.cycle_at(53, 88, 0), Geyser.Cycle.IDLE)
	assert_eq(Geyser.cycle_at(54, 88, 0), Geyser.Cycle.BUBBLE, "22 ticks of bubbling ...")
	assert_eq(Geyser.cycle_at(76, 88, 0), Geyser.Cycle.SPOUT, "... then 12 of spout")
	assert_eq(Geyser.cycle_at(87, 88, 0), Geyser.Cycle.SPOUT)
	assert_eq(Geyser.cycle_at(88, 88, 0), Geyser.Cycle.IDLE)
	assert_eq(Geyser.cycle_at(80, 88, 10), Geyser.Cycle.BUBBLE, "the delay shifts the cycle")
	assert_eq(Geyser.cycle_at(5, 40, 30), Geyser.Cycle.IDLE, "idle before the delay")


func test_geyser_defaults_and_period_floor() -> void:
	_geyser_level()
	var geyser: Geyser = _spawn(&"objects/geyser", 5, 9) as Geyser
	assert_not_null(geyser, "objects/geyser has a scene")
	assert_eq(geyser.period, Tuning.GEYSER_PERIOD)
	assert_eq(geyser.power, Tuning.GEYSER_POWER)
	assert_eq(geyser.skin, "mud")
	assert_false(geyser.deadly)
	assert_eq(geyser.vent_rect(), Rect2i(76, 144, 24, 16), "24 x 16 above the anchor floor")
	var short: Geyser = _spawn(&"objects/geyser", 10, 9, {"period": 20, "skin": "lava"}) as Geyser
	assert_eq(short.period, Tuning.GEYSER_PERIOD_MIN, "never shorter than bubble + spout")
	assert_eq(short.skin, "mud", "an unknown skin falls back")


## Sim.step until the geyser's next spout tick has run (returns the ticks stepped).
func _until_spout(geyser: Geyser) -> int:
	var stepped: int = 0
	while geyser.state != Geyser.Cycle.SPOUT and stepped < 400:
		Sim.step(1)
		stepped += 1
	return stepped


func test_a_spout_launches_a_standing_hero_once_per_spout() -> void:
	_geyser_level()
	var geyser: Geyser = _spawn(&"objects/geyser", 5, 9, {"period": 40}) as Geyser
	var hero: PlayerBase = _hero(Vector2i(88, 160))
	var aside: PlayerBase = _hero(Vector2i(101, 160), 1)
	_until_spout(geyser)
	assert_eq(hero.yvel, Tuning.GEYSER_POWER, "launched with the power")
	assert_eq(hero.no_jump, Tuning.NO_JUMP_TICKS, "a launch arms no_jump (C.0 #4)")
	assert_false(hero.grounded)
	assert_eq(aside.yvel, 0, "13 px aside is outside the vent")
	assert_eq(geyser.launches, 1)
	hero.yvel = 0
	Sim.step(1)
	assert_eq(hero.yvel, 0, "not launched twice by one spout")
	Sim.step(Tuning.GEYSER_SPOUT_TICKS)
	_until_spout(geyser)
	assert_eq(hero.yvel, Tuning.GEYSER_POWER, "the next spout launches again")


func test_a_geyser_over_tar_launches_the_hero_wading_there() -> void:
	_rows([
		"....................", "....................", "....................", "....................",
		"....................", "....................", "....................", "....................",
		"....................", "....................", "###:::::::##########", "####################",
	])
	var geyser: Geyser = _spawn(&"objects/geyser", 5, 9, {"period": 40}) as Geyser
	var surface: int = 160 + Tuning.TAR_SURFACE_DROP_PX
	assert_eq(geyser.sim_pos, Vector2i(88, surface), "placed by the loader's rule, the vent sits on the tar surface")
	assert_eq(geyser.vent_rect(), Rect2i(76, surface - 16, 24, 16))
	var wader: PlayerBase = _hero(Vector2i(90, surface))
	_until_spout(geyser)
	assert_eq(wader.yvel, Tuning.GEYSER_POWER, "a hero wading in the tar is launched (the way out of a tar pit)")
	var on_rock: Geyser = _spawn(&"objects/geyser", 14, 9) as Geyser
	assert_eq(on_rock.sim_pos.y, 160, "on level ground nothing moves")
	var placed_low: Geyser = level.spawn(&"objects/geyser", Vector2i(120, surface)) as Geyser
	assert_eq(placed_low.sim_pos.y, surface, "a vent placed on the surface itself stays there")


func test_gliders_eggs_and_rising_heroes_ignore_a_spout() -> void:
	_geyser_level()
	var geyser: Geyser = _spawn(&"objects/geyser", 5, 9, {"period": 40}) as Geyser
	var glider: PlayerBase = _hero(Vector2i(88, 160))
	glider.glide = 1
	var egg: PlayerBase = _hero(Vector2i(86, 160), 1)
	egg.down = true
	var rising: PlayerBase = _hero(Vector2i(90, 158), 2)
	rising.yvel = -20
	_until_spout(geyser)
	assert_eq(glider.yvel, 0, "a glider ignores it")
	assert_eq(egg.yvel, 0, "an egg ignores it")
	assert_eq(rising.yvel, -20, "yvel >= 0 only")


func test_a_real_hero_rises_105_px() -> void:
	_geyser_level()
	var geyser: Geyser = _spawn(&"objects/geyser", 5, 9, {"period": 60}) as Geyser
	var hero: Player = _player(Vector2i(88, 160))
	_until_spout(geyser)
	assert_eq(hero.yvel, Tuning.GEYSER_POWER)
	var lowest_y: int = hero.sim_pos.y
	for i: int in 40:
		Sim.step(1)
		lowest_y = mini(lowest_y, hero.sim_pos.y)
	var expected: int = 0
	for launch: Dictionary in party_reference().get("launches", []):
		if int(launch["yvel"]) == Tuning.GEYSER_POWER:
			expected = int(launch["rise_px"])
	assert_eq(expected, 105, "PARTY_REFERENCE.json: -224 rises 105 px")
	assert_eq(160 - lowest_y, expected, "the hero's rise")


func test_a_spout_launches_enemies_drop_platforms_and_rafts() -> void:
	_geyser_level()
	var geyser: Geyser = _spawn(&"objects/geyser", 5, 9, {"period": 40}) as Geyser
	var enemy: EnemyBase = EnemyBase.new()
	place(level, enemy, Vector2i(84, 160))
	enemy.wake()
	var dropper: DropPlatform = DropPlatform.new()
	place(level, dropper, Vector2i(92, 160))
	dropper.teleport(Vector2i(92, 160))
	dropper.state = DropPlatform.State.REST
	_until_spout(geyser)
	assert_eq(enemy.yvel, Tuning.GEYSER_POWER, "a ground enemy")
	assert_eq(dropper.state, DropPlatform.State.FALL, "a drop platform rises ...")
	assert_true(dropper.fall_speed < 0, "... with the power, then its dropper fall")
	assert_eq(geyser.launches, 2)


## objects-A's DropPlatform.launch (wf8_objects_a_to_objects_b.txt): a hero riding a drop platform the spout throws up
## rises with it, though he stands outside the vent box (6-2's spore geysers lifting drop platforms).
func test_a_spout_lifts_a_drop_platform_with_its_rider_outside_the_vent() -> void:
	_geyser_level()
	var geyser: Geyser = _spawn(&"objects/geyser", 5, 9, {"period": 40}) as Geyser
	var dropper: DropPlatform = DropPlatform.new()
	# Placed a cell lower, so its home (its standing surface: the top edge of the placement cell) is the floor; a long
	# delay keeps it waiting under its rider until the spout.
	place(level, dropper, Vector2i(92, 160 + Tuning.TILE - 8), {"delay": 999})
	assert_eq(dropper.sim_pos, Vector2i(92, 160), "waiting on the floor over the vent")
	Sim.step(1)
	# 1 px into the contact band (as the raft tests stand a rider on a raft), right of the vent box: the ride test
	# (PHYSICS.md 11.4, the original's overlap) lends half the platform's width, so his box's left edge (x - 16) must
	# be left of the platform's centre - x 104 rides, and the vent box ends at x 99.
	var rider: PlayerBase = _hero(Vector2i(104, dropper.sim_pos.y - dropper.box_h + 1))
	assert_false(geyser.vent_rect().has_point(rider.sim_pos), "he stands outside the vent box")
	Sim.step(1)
	assert_ne(dropper.rider_mask, 0, "riding it (platform %s, hero %s)" % [dropper.sim_pos, rider.sim_pos])
	_until_spout(geyser)
	assert_eq(dropper.state, DropPlatform.State.FALL)
	assert_true(dropper.fall_speed < 0, "thrown up")
	assert_eq(rider.yvel, Tuning.GEYSER_POWER, "and its rider with it, with the same power")
	assert_eq(geyser.launches, 1, "the vent launched the platform; the platform its rider")


func test_a_deadly_vent_kills_and_a_boulder_plugs_it() -> void:
	_geyser_level()
	var vent: Geyser = _spawn(&"objects/geyser", 5, 9, {"period": 40, "deadly": true}) as Geyser
	assert_true(vent.deadly)
	assert_eq(vent.deadly_rect(), Rect2i(76, 96, 24, 64), "24 x 64 above the vent")
	var hero: PlayerBase = _hero(Vector2i(88, 130))
	_until_spout(vent)
	assert_true(hero.dead, "the spout kills")
	assert_eq(hero.yvel, 0, "no launch")
	hero.respawn_at(Vector2i(88, 130))
	var boulder: FakeBoulder = FakeBoulder.new()
	place(level, boulder, Vector2i(88, 160))
	vent._boulders_found = false
	Sim.step(Tuning.GEYSER_SPOUT_TICKS)
	_until_spout(vent)
	assert_true(vent.is_plugged(), "a boulder resting on the vent plugs it")
	assert_false(hero.dead, "a plugged vent does not spout")
	boulder.plugging = false
	assert_false(vent.is_plugged())


func test_a_plugged_geyser_launches_nothing() -> void:
	_geyser_level()
	var geyser: Geyser = _spawn(&"objects/geyser", 5, 9, {"period": 40}) as Geyser
	geyser.plugged = true
	var hero: PlayerBase = _hero(Vector2i(88, 160))
	_until_spout(geyser)
	Sim.step(2)
	assert_eq(hero.yvel, 0)
	assert_eq(geyser.launches, 0)


# =================================================================================================================
# Rafts and currents
# =================================================================================================================

## Water in row 8 (cols 2-17) and below, banks of solid ground at cols 0-1 and 18-19.
func _raft_level() -> void:
	var rows: Array = []
	for row: int in 8:
		rows.append("....................")
	rows.append("##~~~~~~~~~~~~~~~~##")
	rows.append("##~~~~~~~~~~~~~~~~##")
	rows.append("####################")
	_rows(rows)


func _raft(col: int, params: Dictionary = {}) -> Raft:
	return _spawn(&"objects/raft", col, 8, params) as Raft


func test_a_raft_floats_on_the_top_water_row() -> void:
	_raft_level()
	var raft: Raft = _raft(5)
	assert_not_null(raft, "objects/raft has a scene")
	assert_eq(raft.width, 3, "width [3]")
	assert_eq(raft.box_w, 48)
	assert_eq(raft.box_h, Tuning.RAFT_HEIGHT_PX)
	assert_eq(raft.sim_pos, Vector2i(88, 8 * 16 + Tuning.RAFT_FLOAT_DEPTH_PX), "4 px into its ~ cell")
	assert_eq(raft.surface_row, 8)
	var wide: Raft = _raft(12, {"width": 4, "skin": "wafer"})
	assert_eq(wide.box_w, 64)
	assert_eq(wide.skin, "wafer")
	Sim.step(10)
	assert_eq(raft.sim_pos, Vector2i(88, 132), "still water: it stays")


func test_paddling_drag_and_the_speed_cap() -> void:
	_raft_level()
	var raft: Raft = _raft(8)
	raft.paddle(1)
	assert_eq(raft.rx, -Tuning.RAFT_PADDLE_V16, "a forward strike facing right pushes it left")
	raft.paddle(1)
	raft.paddle(1)
	raft.paddle(1)
	assert_eq(raft.rx, -Tuning.RAFT_SPEED_CAP, "up to 3 px/tick of its own")
	var xs: Array[int] = []
	var x0: int = raft.sim_pos.x
	for i: int in 9:
		Sim.step(1)
		xs.append(x0 - raft.sim_pos.x)
	assert_eq(xs, [3, 6, 9, 12, 15, 18, 21, 23, 25] as Array[int], "3 px/tick, slowed by 1 px/tick every 8th tick")
	assert_eq(raft.rx, -32)
	Sim.step(40)
	assert_eq(raft.rx, 0, "drag brings it to rest")


func test_a_bank_stops_the_raft() -> void:
	_raft_level()
	var raft: Raft = _raft(14)
	raft.rx = Tuning.RAFT_SPEED_CAP
	for i: int in 30:
		Sim.step(1)
	assert_eq(raft.rx, 0, "stopped at the bank")
	assert_true(raft.sim_pos.x + 23 < 18 * 16, "its edge never enters the bank cell")
	assert_true(raft.sim_pos.x + 23 >= 18 * 16 - 3, "it got there")
	var x: int = raft.sim_pos.x
	Sim.step(5)
	assert_eq(raft.sim_pos.x, x)


func test_a_current_drifts_the_raft_and_it_keeps_its_momentum() -> void:
	_raft_level()
	var current: ZoneBase = ZoneBase.new()
	place(level, current, LevelText.cell_to_feet(2, 7), {"rect": "2,7,6,3", "dir": "r", "speed": 2})
	var raft: Raft = _raft(4)
	var x0: int = raft.sim_pos.x
	Sim.step(3)
	assert_eq(raft.cd, 2, "inside the current: cd = speed")
	assert_eq(raft.sim_pos.x - x0, 6, "2 px per tick")
	assert_eq(raft.rx, 0)
	while raft.sim_pos.x < 8 * 16:
		Sim.step(1)
	Sim.step(1)
	assert_eq(raft.cd, 0, "out of the current")
	assert_eq(raft.rx, 32, "it keeps its momentum (rx = 16 * cd)")
	Sim.step(60)
	assert_eq(raft.rx, 0)


## A current spawned during play (Inkjaw's whirlpool, B.3) carries rafts already afloat: a raft looks for its
## currents again when the level's zones change. A real `zones/current` without `speed` drifts 1 px per tick (its
## default), and the direction it is switched to is followed.
func test_a_current_spawned_during_play_carries_rafts_already_afloat() -> void:
	_raft_level()
	var raft: Raft = _raft(6)
	Sim.step(5)
	assert_eq(raft.cd, 0, "no current yet")
	var x0: int = raft.sim_pos.x
	var current: SimEntity = level.spawn(&"zones/current", LevelText.cell_to_feet(2, 8), {"rect": "2,8,16,2", "dir": "r"})
	assert_not_null(current, "world-A's zones/current")
	Sim.step(4)
	assert_eq(raft.cd, 1, "the new current: 1 px per tick by default")
	assert_true(raft.sim_pos.x > x0, "it drifts")
	current.spawn_params["dir"] = "l"
	current.set(&"dir", &"l")
	Sim.step(1)
	assert_eq(raft.cd, -1, "and follows a reversed current")
	current.queue_free()
	Sim.step(2)
	assert_eq(raft.cd, 0, "out of the current once it is gone")


func test_a_raft_carries_its_rider() -> void:
	_raft_level()
	var raft: Raft = _raft(6)
	Sim.step(1)
	var hero: PlayerBase = _hero(Vector2i(raft.sim_pos.x, raft.sim_pos.y - raft.box_h + 1))
	raft.rx = 32
	Sim.step(1)
	assert_true(raft.ridden)
	assert_eq(raft.rider_count(), 1)
	var dx: int = hero.sim_pos.x - raft.sim_pos.x
	Sim.step(4)
	assert_eq(hero.sim_pos.x - raft.sim_pos.x, dx, "carried along")


## A hero falling onto a raft faster than its 4 px over the liquid cell used to die in the liquid before the ride
## test caught him (wf8_D6_to_objects_b.txt #1): the deck catches him in his own move (Raft.catch_sinking, the G2
## integration). Away from the raft the same fall still kills.
func test_a_hero_falling_fast_onto_a_raft_lands_on_it() -> void:
	_raft_level()
	var raft: Raft = _raft(6)
	Sim.step(1)
	var top: int = raft.sim_pos.y - raft.box_h
	var hero: Player = _player(Vector2i(raft.sim_pos.x, top - 4))
	hero.yvel = 182
	hero.grounded = false
	run_inputs([[1, ""]])
	assert_false(hero.dead, "caught by the deck, not drowned")
	assert_true(hero.on_platform, "riding the raft")
	assert_eq(hero.sim_pos.y, top + 1, "on the deck (PlayerBase.ride_platform)")
	run_inputs([[6, ""]])
	assert_false(hero.dead)
	assert_true(raft.ridden, "the ride test keeps him")
	var swimmer: Player = _player(Vector2i(14 * 16, top - 4))
	swimmer.yvel = 182
	swimmer.grounded = false
	run_inputs([[1, ""]])
	assert_true(swimmer.dead, "no raft under him: the liquid kills as before")


func test_rails_keep_a_rider_on_the_raft() -> void:
	_raft_level()
	var raft: Raft = _raft(6, {"rails": true})
	Sim.step(1)
	var hero: PlayerBase = _hero(Vector2i(raft.sim_pos.x, raft.sim_pos.y - raft.box_h + 1))
	Sim.step(1)
	assert_true(raft.ridden)
	assert_true(hero.fence_allows(raft.sim_pos.x + 16), "within raft.x + 8 * width - 8")
	assert_false(hero.fence_allows(raft.sim_pos.x + 17), "not beyond")
	assert_false(hero.fence_allows(raft.sim_pos.x - 17))
	hero.clear_fence()
	hero.teleport(Vector2i(raft.sim_pos.x, 60))
	hero.yvel = -50
	hero.grounded = false
	Sim.step(1)
	assert_false(hero.fence_allows(raft.sim_pos.x + 40), "airborne after leaving it: still fenced")
	hero.clear_fence()
	hero.teleport(Vector2i(8, 128))
	hero.yvel = 0
	hero.grounded = true
	Sim.step(1)
	assert_true(hero.fence_allows(raft.sim_pos.x + 40), "on the bank's floor: free")


## G45: a railed raft carries its rider over the whole fence - also at the bow, where the 1.0 halved-width overlap let
## him fall through - and once a bank stops it the fence opens over that bank (he may step off onto the beach).
func test_a_railed_raft_carries_to_the_bow_and_opens_at_a_bank() -> void:
	_raft_level()
	var raft: Raft = _raft(6, {"rails": true, "width": 4})
	Sim.step(1)
	var hero: PlayerBase = _hero(Vector2i(raft.sim_pos.x, raft.sim_pos.y - raft.box_h + 1))
	Sim.step(1)
	assert_true(raft.ridden)
	hero.teleport(Vector2i(raft.rail_right_excl() - 1, raft.sim_pos.y - raft.box_h))
	Sim.step(3)
	assert_eq(raft.rider_count(), 1, "at the bow (x = centre + %d): still carried" % (hero.sim_pos.x - raft.sim_pos.x))
	hero.clear_fence()
	Sim.step(1)
	assert_false(hero.fence_allows(raft.rail_right_excl()), "fenced while it floats free")
	hero.teleport(Vector2i(raft.rail_left(), raft.sim_pos.y - raft.box_h))
	Sim.step(3)
	assert_eq(raft.rider_count(), 1, "at the stern too")
	raft.teleport(Vector2i(18 * 16 - 8 * raft.width - 6, raft.sim_pos.y))
	hero.teleport(Vector2i(raft.sim_pos.x, raft.sim_pos.y - raft.box_h))
	Sim.step(1)
	raft.rx = 32
	Sim.step(6)
	assert_eq(raft.sim_pos.x + 8 * raft.width, 18 * 16, "the right bank stopped it")
	assert_eq(raft.rx, 0)
	assert_eq(raft.rider_count(), 1)
	hero.clear_fence()  # a bare hero never ends his fences himself (the real one does after his x step)
	Sim.step(1)
	assert_true(hero.fence_allows(raft.rail_right_excl() + 8), "docked: the fence is open over the bank")
	assert_false(hero.fence_allows(raft.rail_left() - 1), "the water side stays fenced")


func test_a_geyser_launch_flies_the_raft_and_it_settles_again() -> void:
	_raft_level()
	var raft: Raft = _raft(6)
	Sim.step(1)
	var hero: PlayerBase = _hero(Vector2i(raft.sim_pos.x, raft.sim_pos.y - raft.box_h + 1))
	Sim.step(1)
	raft.launch(Tuning.GEYSER_POWER)
	assert_true(raft.flying)
	assert_eq(hero.yvel, Tuning.GEYSER_POWER, "its riders are launched the same tick")
	var top_y: int = raft.sim_pos.y
	for i: int in 40:
		Sim.step(1)
		top_y = mini(top_y, raft.sim_pos.y)
	assert_false(raft.flying, "back on the water")
	assert_false(raft.beached)
	assert_eq(raft.sim_pos.y, 132)
	assert_eq(132 - top_y, 105, "-224 rises 105 px")


func test_a_raft_launched_over_a_bank_beaches() -> void:
	_raft_level()
	var raft: Raft = _raft(15)
	raft.rx = 32
	raft.launch(Tuning.GEYSER_POWER)
	for i: int in 40:
		Sim.step(1)
	assert_true(raft.beached, "it came down on the bank's floor")
	assert_eq(raft.sim_pos.y, 8 * 16, "standing on the floor")
	assert_eq(raft.rx, 0)
	var x: int = raft.sim_pos.x
	Sim.step(10)
	assert_eq(raft.sim_pos.x, x, "a beached raft stays")
	level.reset_entities()
	assert_false(raft.beached, "a level reset floats it home")
	assert_eq(raft.sim_pos, Vector2i(15 * 16 + 8, 132))


func test_a_real_hero_paddles_with_a_forward_strike() -> void:
	_raft_level()
	var raft: Raft = _raft(8)
	Sim.step(1)
	var hero: Player = _player(Vector2i(raft.sim_pos.x, raft.sim_pos.y - raft.box_h + 1))
	run_inputs([[4, ""]])
	assert_true(raft.ridden, "he stands on the raft")
	run_inputs([[1, "F"], [14, ""]])
	assert_eq(raft.paddles, 1, "one forward strike = one paddle stroke")
	assert_true(raft.sim_pos.x < 8 * 16 + 8, "pushed backward (he faces right)")
	assert_eq(hero.facing, 1)


# =================================================================================================================
# Chomper, the mount, and his pen
# =================================================================================================================

## A flat 20 x 12 screen (floor from row 10) with a tame mount at column 5 (feet 88, 160).
func _mount_level(params: Dictionary = {}) -> Mount:
	level = make_flat_level(20, 12, 10)
	return _spawn(&"objects/mount", 5, 9, params) as Mount


## `hero` falling onto the mount's back.
func _drop_on(hero: PlayerBase, mount: Mount) -> void:
	hero.teleport(Vector2i(mount.sim_pos.x, mount.sim_pos.y - mount.box_h + 4))
	hero.yvel = 32
	hero.grounded = false


func test_mount_defaults_and_seating_from_above() -> void:
	var mount: Mount = _mount_level({"kind": "rex"})
	assert_not_null(mount, "objects/mount has a scene")
	assert_true(mount.tame and mount.present)
	assert_eq(Vector3i(mount.box_w, mount.box_h, mount.box_xo), Mount.BOX)
	var walker: PlayerBase = _hero(Vector2i(70, 160))
	Sim.step(2)
	assert_false(walker.is_mounted(), "walking into Chomper does not seat")
	var rider: PlayerBase = _hero(Vector2i(10, 160), 1)
	_drop_on(rider, mount)
	Sim.step(1)
	assert_true(rider.is_mounted(), "landing on the saddle seats")
	assert_eq(mount.driver, rider)
	assert_eq(rider.mount_seat, PlayerBase.SEAT_DRIVER)
	assert_eq(rider.sim_pos, Vector2i(88, 160 - Mount.SADDLE_PX), "the driver's feet are 26 px over the mount's")
	assert_eq(Vector3i(mount.box_w, mount.box_h, mount.box_xo), Mount.RIDDEN_BOX)
	_drop_on(walker, mount)
	Sim.step(1)
	assert_false(walker.is_mounted(), "single-player: no gunner seat")


## Drives the mount with `runs` (slot 0's keys) and returns [t, xvel, dx] rows like PARTY_REFERENCE.json.
func _drive(mount: Mount, runs: Array) -> Array:
	var rows: Array = []
	var x0: int = mount.sim_pos.x
	var y0: int = mount.sim_pos.y
	var flags: PackedInt32Array = GameInput.expand_runs(runs)
	var first: int = Sim.tick + 1
	GameInput.set_scripted(func(tick: int) -> int:
		var i: int = tick - first
		return flags[i] if i >= 0 and i < flags.size() else 0)
	for t: int in flags.size():
		Sim.step(1)
		rows.append([t + 1, mount.xvel, mount.sim_pos.x - x0, y0 - mount.sim_pos.y])
	GameInput.clear_scripted()
	return rows


func _seated_mount() -> Mount:
	var mount: Mount = _mount_level()
	var rider: PlayerBase = _hero(Vector2i(10, 160))
	_drop_on(rider, mount)
	Sim.step(1)
	assert_eq(mount.driver, rider)
	return mount


func test_mount_walk_and_stop_match_the_reference() -> void:
	var reference: Dictionary = party_reference().get("mount", {})
	assert_false(reference.is_empty(), "PARTY_REFERENCE.json has the mount table")
	var mount: Mount = _seated_mount()
	var walk: Array = _drive(mount, [[8, "R"]])
	for row: Array in reference["walk_from_rest"]:
		var t: int = int(row[0])
		assert_eq([walk[t - 1][1], walk[t - 1][2]], [int(row[1]), int(row[2])], "walk tick %d (xvel, x)" % t)
	var stop: Array = _drive(mount, [[7, ""]])
	for row: Array in reference["stop_from_full_speed"]:
		var t: int = int(row[0])
		assert_eq([stop[t - 1][1], stop[t - 1][2]], [int(row[1]), int(row[2])], "stop tick %d (xvel, x)" % t)


func test_mount_hops_match_the_reference() -> void:
	var reference: Dictionary = party_reference().get("mount", {})
	var mount: Mount = _seated_mount()
	_drive(mount, [[8, "R"]])
	assert_eq(mount.xvel, Mount.WALK_CAP)
	var full: Array = _drive(mount, [[1, "RU"], [21, "R"]])
	for row: Array in reference["hop_from_full_speed"]:
		var t: int = int(row[0])
		assert_eq([full[t - 1][2], full[t - 1][3]], [int(row[1]), int(row[2])], "full-speed hop tick %d (x, h)" % t)
	assert_true(mount.grounded, "landed on tick %d" % int(reference["hop_landing_tick"]))
	_drive(mount, [[10, ""]])
	var rest: Array = _drive(mount, [[1, "LU"], [21, "L"]])
	for row: Array in reference["hop_from_rest_direction_held"]:
		var t: int = int(row[0])
		assert_eq([-rest[t - 1][2], rest[t - 1][3]], [int(row[1]), int(row[2])], "hop from rest tick %d (x, h)" % t)


func test_dismount_launch_and_remount_lock() -> void:
	var mount: Mount = _seated_mount()
	var rider: PlayerBase = mount.driver
	run_inputs([[1, "DU"]])
	assert_false(rider.is_mounted(), "Down + Jump dismounts")
	assert_null(mount.driver)
	assert_eq(rider.yvel, Mount.DISMOUNT_YVEL, "launch(0, -128)")
	assert_true(mount.is_remount_locked(rider))
	_drop_on(rider, mount)
	Sim.step(1)
	assert_false(rider.is_mounted(), "locked for %d ticks" % Mount.REMOUNT_LOCK)
	Sim.step(Mount.REMOUNT_LOCK)
	_drop_on(rider, mount)
	Sim.step(1)
	assert_true(rider.is_mounted(), "then he can sit again")


func test_the_bite_eats_small_enemies_and_bites_big_ones() -> void:
	var mount: Mount = _seated_mount()
	var small: EnemyBase = EnemyBase.new()
	place(level, small, Vector2i(mount.sim_pos.x + 30, 160))
	small.wake()
	var score: int = Game.score
	var points: int = small.get_points()
	run_inputs([[1, "F"], [8, ""]])
	assert_true(small.dead, "hp 25 < 50: eaten")
	assert_eq(mount.eaten, 1)
	assert_false(small.visible, "no death arc: it vanished into the jaws")
	assert_eq(Game.score - score, points + Mount.FOOD_BONUS, "its score plus the food bonus")
	assert_eq(small.last_hit_slot, 0, "credited to the driver")
	var big: EnemyBase = EnemyBase.new()
	big.max_hp = 80
	big.hp = 80
	place(level, big, Vector2i(mount.sim_pos.x + 30, 160))
	big.wake()
	run_inputs([[1, "F"], [8, ""]])
	assert_false(big.dead)
	assert_eq(big.hp, 80 - Mount.BITE_POWER, "hp >= 50 takes 25")
	assert_eq(mount.bites_landed, 1)
	var behind: EnemyBase = EnemyBase.new()
	place(level, behind, Vector2i(mount.sim_pos.x - 30, 160))
	behind.wake()
	run_inputs([[1, "F"], [8, ""]])
	assert_false(behind.dead, "the bite box is in front only")


func test_a_hit_throws_the_rider_off_and_the_mount_bolts_home() -> void:
	var mount: Mount = _mount_level({"pen": "pen1"})
	var pen: RexPen = _spawn(&"objects/rex_pen", 14, 9, {"name": "pen1"}) as RexPen
	assert_not_null(pen, "objects/rex_pen has a scene")
	mount._resolve_home()
	assert_eq(mount.get_home(), pen.sim_pos, "home is the pen")
	var rider: PlayerBase = _hero(Vector2i(10, 160))
	_drop_on(rider, mount)
	Sim.step(1)
	var hearts: int = rider.run.hearts
	var enemy: EnemyBase = EnemyBase.new()
	place(level, enemy, Vector2i(mount.sim_pos.x + 6, 160))
	enemy.wake()
	Sim.step(2)
	assert_false(rider.is_mounted(), "thrown off (the enemy is touchable once it was on screen)")
	assert_eq(rider.hit_timer, Tuning.HIT_TIMER, "stunned and blinking")
	assert_eq(rider.yvel, Mount.RIDER_HIT_YVEL)
	assert_eq(rider.xvel, -Mount.RIDER_HIT_XVEL, "away from the enemy")
	assert_eq(rider.run.hearts, hearts, "no heart lost")
	assert_false(mount.present, "the mount bolted")
	assert_false(mount.visible)
	enemy.sleep()
	Sim.step(Mount.BOLT_TICKS)
	assert_true(mount.present, "back after %d ticks" % Mount.BOLT_TICKS)
	assert_eq(mount.sim_pos, pen.sim_pos, "waiting in its pen")
	assert_true(mount.tame)


func test_rider_hit_from_a_projectile_path() -> void:
	var mount: Mount = _seated_mount()
	var rider: PlayerBase = mount.driver
	var shot: SimEntity = SimEntity.new()
	place(level, shot, Vector2i(10, 120))
	mount.rider_hit(shot)
	assert_false(rider.is_mounted())
	assert_eq(rider.xvel, Mount.RIDER_HIT_XVEL, "thrown away from the source on the left")
	assert_false(mount.present)


func test_the_mount_dies_in_water_with_its_rider() -> void:
	level = make_level(PackedStringArray([
		"....................", "....................", "....................", "....................",
		"....................", "....................", "....................", "....................",
		"....................", "....................", "########~~~#########", "####################",
	]))
	var mount: Mount = _spawn(&"objects/mount", 5, 9) as Mount
	var rider: PlayerBase = _hero(Vector2i(10, 160))
	_drop_on(rider, mount)
	Sim.step(1)
	run_inputs([[30, "R"]])
	assert_true(rider.dead, "~ still kills (C.9)")
	assert_false(mount.present, "and the mount bolts")


func test_the_mount_walks_over_floor_spikes() -> void:
	level = make_level(PackedStringArray([
		"....................", "....................", "....................", "....................",
		"....................", "....................", "....................", "....................",
		"....................", "....................", "########^^^#########", "####################",
	]))
	var mount: Mount = _spawn(&"objects/mount", 5, 9) as Mount
	var rider: PlayerBase = _hero(Vector2i(10, 160))
	_drop_on(rider, mount)
	Sim.step(1)
	run_inputs([[20, "R"]])
	assert_false(rider.dead, "spikes count as floor for Chomper")
	assert_true(mount.present)
	assert_true(mount.sim_pos.x >= 8 * 16, "it crossed the spikes")
	assert_eq(mount.sim_pos.y, 160, "on the spike row's top")


func test_a_wild_rex_hurts_paces_and_is_tamed_by_three_bounces() -> void:
	var mount: Mount = _mount_level({"wild": true})
	assert_true(mount.wild)
	assert_false(mount.tame)
	var xs: Array[int] = []
	for i: int in 200:
		Sim.step(1)
		xs.append(mount.sim_pos.x)
	assert_true(xs.min() >= 88 - Mount.WILD_PACE_CELLS * 16 - 1 and xs.max() <= 88 + Mount.WILD_PACE_CELLS * 16 + 1,
			"paces +/-3 cells from home: %d..%d" % [xs.min(), xs.max()])
	assert_true(xs.max() - xs.min() >= 80, "and does pace")
	var hero: PlayerBase = _hero(Vector2i(mount.sim_pos.x - 20, 160))
	var hearts: int = hero.run.hearts
	Sim.step(1)
	assert_eq(hero.run.hearts, hearts - 1, "its side hurts")
	assert_false(hero.is_mounted(), "a wild rex cannot be ridden")
	hero.hit_timer = 0
	for bounce: int in Mount.TAME_BOUNCES:
		_drop_on(hero, mount)
		Sim.step(1)
		assert_eq(hero.yvel, Tuning.BOUNCE_YVEL, "bounce %d" % (bounce + 1))
	assert_true(mount.tame, "three bounces in a row tame it")
	assert_false(hero.is_mounted(), "taming is not sitting")


func test_a_grounded_tick_breaks_the_taming_chain() -> void:
	var mount: Mount = _mount_level({"wild": true})
	var hero: PlayerBase = _hero(Vector2i(10, 160))
	_drop_on(hero, mount)
	Sim.step(1)
	_drop_on(hero, mount)
	Sim.step(1)
	assert_eq(mount.tame_count, 2)
	hero.teleport(Vector2i(10, 160))
	hero.yvel = 0
	hero.grounded = true
	Sim.step(1)
	assert_eq(mount.tame_count, 0, "he landed: the chain restarts")
	_drop_on(hero, mount)
	Sim.step(1)
	assert_false(mount.tame)
	level.reset_entities()
	assert_true(mount.wild and not mount.tame, "a death keeps a never-tamed rex wild")


func test_co_op_gunner_seat() -> void:
	Game.start_run(Defs.Difficulty.BEGINNER, Defs.GameMode.COOP, 2)
	Game.begin_level(&"test_objects_book2")
	var mount: Mount = _mount_level()
	var driver: PlayerBase = _hero(Vector2i(10, 160), 0)
	var gunner: PlayerBase = _hero(Vector2i(30, 160), 1)
	_drop_on(driver, mount)
	Sim.step(1)
	_drop_on(gunner, mount)
	Sim.step(1)
	assert_eq(mount.driver, driver)
	assert_eq(mount.gunner, gunner, "the partner who lands on his back is the gunner")
	assert_eq(gunner.mount_seat, PlayerBase.SEAT_GUNNER)
	assert_eq(gunner.sim_pos, Vector2i(88 - Mount.GUNNER_BEHIND_PX, 160 - Mount.SADDLE_PX), "14 px behind the driver")
	mount.dismount(driver)
	assert_eq(mount.driver, gunner, "the gunner takes the reins")
	assert_eq(gunner.mount_seat, PlayerBase.SEAT_DRIVER)
	Game.new_game(Defs.Difficulty.BEGINNER)


func test_a_level_reset_puts_the_mount_back_tame_and_empty() -> void:
	var mount: Mount = _seated_mount()
	var rider: PlayerBase = mount.driver
	run_inputs([[10, "R"]])
	assert_ne(mount.sim_pos.x, 88)
	rider.respawn_at(Vector2i(10, 160))
	level.reset_entities()
	assert_false(mount.is_ridden())
	assert_eq(mount.sim_pos, Vector2i(88, 160), "home")
	assert_true(mount.present and mount.tame)
	Sim.step(1)
	assert_false(rider.is_mounted())


# =================================================================================================================
# The test walk through the real loader and the validator
# =================================================================================================================

func test_the_book2_test_level_loads_every_object() -> void:
	Sim.manual = true
	Game.begin_level(&"test_objects_book2")
	var loaded: Level = (load(LEVEL_SCENE) as PackedScene).instantiate() as Level
	loaded.setup_from_text(&"test_objects_book2", FileAccess.get_file_as_string(BOOK2_LEVEL))
	add_node(loaded)
	loaded.set_view_size(BASE_VIEW)
	level = loaded
	var counts: Dictionary = {}
	for kind: int in Defs.KIND_COUNT:
		for entity: SimEntity in loaded.get_kind(kind):
			var script: Script = entity.get_script() as Script
			var global: StringName = script.get_global_name() if script != null else &""
			counts[global] = int(counts.get(global, 0)) + 1
	assert_eq(int(counts.get(&"Vine", 0)), 2, "a hanging and a rolled vine")
	assert_eq(int(counts.get(&"BarkBoard", 0)), 1)
	assert_eq(int(counts.get(&"Painting", 0)), 1)
	assert_eq(int(counts.get(&"Geyser", 0)), 2)
	assert_eq(int(counts.get(&"Raft", 0)), 1)
	assert_eq(int(counts.get(&"Mount", 0)), 1)
	assert_eq(int(counts.get(&"RexPen", 0)), 1)
	var board: BarkBoard = null
	for entity: SimEntity in loaded.get_kind(Defs.Kind.OTHER):
		if entity is BarkBoard:
			board = entity
	assert_eq(board.get_face(), -1, "the palisade board faces left")
	assert_true(loaded.grid.side_at(board.cell.x, board.cell.y) == TileGrid.SIDE_WALL, "it sits in a wall cell")
	for entity: SimEntity in loaded.get_kind(Defs.Kind.PLATFORM):
		if entity is Raft:
			assert_eq(loaded.grid.get_char(entity.sim_pos.x >> 4, (entity as Raft).surface_row), TileGrid.CH_LIQUID,
					"the raft floats on ~")
	Sim.step(5)
	assert_true(true, "five ticks of the walk ran")


func test_the_book2_test_level_is_valid() -> void:
	var validator: LevelValidator = LevelValidator.new()
	assert_true(validator.add_file(BOOK2_LEVEL))
	validator.run()
	var lines: PackedStringArray = PackedStringArray()
	for problem: Dictionary in validator.problems:
		lines.append(LevelValidator.format_problem(problem))
	assert_eq(validator.error_count(), 0, "\n".join(lines))
