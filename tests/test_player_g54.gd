extends PartyTestCase
## G54 - a head is never a step into rock (DESIGN.md G54, PHYSICS.md C.10; lead designer's ruling in
## build/engine_requests/wf9_lead_design_to_party.txt #3). When standing on, riding or bouncing off a head (an enemy's,
## a boss body's or a hero's) would put a hero's box into a solid cell, he slides off that head instead and the bounce
## is cut to the free room under the ceiling (PlayerBase.bounce, land_on_partner, carry_totem). The cases the reports
## named are pinned on their real files: the 9-3 crown (D9b's w9_l3 hall: a hero on a chieftain who stands on the
## altar under the 5-row crown was juggled with his head in the rock for 170 ticks, or lifted into it and leashed -
## enemies-C's test_enemies_chieftain.lvl has the same hall) and the 4-1 co-op zigzag ledges (DB3: a hero swinging
## under the ledge his partner walks on was lifted onto the partner's head and into the rock above it).

const LEVEL_SCENE: String = "res://scenes/world/level.tscn"
## The crown of the generic tests: rock from the top down to row CROWN_ROW (its underside at (CROWN_ROW + 1) * 16)
## over the middle of the world; the floor at GROUND_ROW. Three rows of air between (48 px): a hero (35) fits, a hero
## on a 35 px body does not (13 px of room over its head).
const CROWN_ROW: int = GROUND_ROW - 4
const BODY_BOX: Vector3i = Vector3i(32, 35, 16)

var _bounces: int = 0


func after_each() -> void:
	if Events.hero_bounced.is_connected(_on_bounced):
		Events.hero_bounced.disconnect(_on_bounced)
	GameInput.clear_scripted()
	super.after_each()


func _on_bounced(_hero: PlayerBase, _target: SimEntity, _multiplier: int) -> void:
	_bounces += 1


## Level-file rows: the floor from GROUND_ROW down; rock over columns `from`..`to` from the top to `bottom`.
func _crown_rows(from: int = 52, to: int = 72, bottom: int = CROWN_ROW) -> PackedStringArray:
	var rows: PackedStringArray = PackedStringArray()
	for row: int in GROUND_ROW + WORLD_ROWS_BELOW:
		var line: String = ""
		for col: int in WORLD_COLS:
			var rock: bool = row >= GROUND_ROW or (row <= bottom and col >= from and col <= to)
			line += TileGrid.CH_SOLID_A if rock else TileGrid.CH_AIR
		rows.append(line)
	return rows


## A plain enemy body of BODY_BOX standing at `pos`, awake and drawn (its contact is the 1.0 head bounce).
func _body_at(pos: Vector2i) -> EnemyBase:
	var enemy: EnemyBase = EnemyBase.new()
	place(level if level != null else Game.level, enemy, pos, {"hp": 25})
	enemy.set_box(BODY_BOX)
	enemy.wake()
	enemy.on_screen = true
	return enemy


func _falling(h: PlayerBase, pos: Vector2i, yvel: int) -> void:
	h.teleport(pos)
	h.yvel = yvel
	h.grounded = false
	h.on_platform = false
	h.fall_ticks = 8
	h.no_jump = Tuning.NO_JUMP_TICKS


# =================================================================================================================
# The rule's own pieces
# =================================================================================================================

func test_rock_is_the_hero_body_cells_of_his_tile_collision() -> void:
	var rows: PackedStringArray = _crown_rows()
	var grid: TileGrid = TileGrid.from_rows(rows)
	var x: int = 62 * 16 + 8
	var floor_y: int = GROUND_ROW * 16
	var underside: int = (CROWN_ROW + 1) * 16
	assert_false(PlayerBase.grid_rock_at(grid, x, floor_y), "standing on the floor under the crown: free")
	assert_false(PlayerBase.grid_rock_at(grid, x, underside + 32), "feet 32 px under the crown: free")
	assert_true(PlayerBase.grid_rock_at(grid, x, underside + 31), "one px higher: his head-probe row is the crown")
	assert_true(PlayerBase.grid_rock_at(grid, x, underside + 8), "the wall-probe row in the crown")
	assert_true(PlayerBase.grid_rock_at(grid, x, floor_y + 5), "feet inside a full block")
	assert_false(PlayerBase.grid_rock_at(grid, 20 * 16 + 8, underside + 8), "no crown over that column")
	# One-way ledges are no rock (the content workaround the lead designer allowed DB3).
	var ledge: TileGrid = TileGrid.from_rows(PackedStringArray(["......", "------", "......", "######"]))
	assert_false(PlayerBase.grid_rock_at(ledge, 24, 40), "a one-way ledge over his head is no rock")
	assert_eq(PlayerBase.rise_px(Tuning.BOUNCE_YVEL), 10, "-64 rises 10 px (PHYSICS.md C.0 table)")
	assert_eq(PlayerBase.rise_px(Tuning.BOUNCE_YVEL_UP), 105, "-224 rises 105 px")
	assert_eq(PlayerBase.cut_to_room(Tuning.BOUNCE_YVEL_UP, 0), 0, "no room: no rise")
	assert_eq(PlayerBase.cut_to_room(Tuning.BOUNCE_YVEL, 8), -48, "8 px of room: -48 (6 px)")
	assert_eq(PlayerBase.cut_to_room(Tuning.BOUNCE_YVEL, 10), Tuning.BOUNCE_YVEL, "room enough: unchanged")
	assert_eq(PlayerBase.cut_to_room(64, 0), 64, "a fall keeps its speed")


# =================================================================================================================
# A head under a ceiling (the lead designer's test): he slides off and never enters the rock
# =================================================================================================================

func test_a_hero_landing_on_a_body_one_row_under_a_ceiling_slides_off_and_never_enters_the_rock() -> void:
	for up: bool in [false, true]:
		world_rows(_crown_rows())
		var body_x: int = START_X
		spawn_hero(START + Vector2i(-160, 0))
		var enemy: EnemyBase = _body_at(Vector2i(body_x, START.y))
		var hearts: int = Game.hearts
		_bounces = 0
		Events.hero_bounced.connect(_on_bounced)
		# Falling fast (8 px/tick: any contact is a stomp) beside its head, his feet 16 px under its top.
		_falling(hero, Vector2i(body_x + 6, START.y - 16), Tuning.STOMP_MIN_YVEL)
		var label: String = "UP held" if up else "UP released"
		var worst: Array[int] = [0]
		var first: Array[Vector2i] = [Vector2i.ZERO]
		play(hold("U" if up else "", 60), func(t: int) -> void:
			if hero.body_in_rock(hero.sim_pos.x, hero.sim_pos.y):
				worst[0] += 1
			if t == 1:
				first[0] = hero.sim_pos
		)
		Events.hero_bounced.disconnect(_on_bounced)
		assert_eq(_bounces, 1, label + ": one stomp, no juggle between the head and the ceiling")
		assert_eq(worst[0], 0, label + ": never in the rock")
		assert_true(first[0].y >= START.y - 8, label + ": not lifted onto the head (feet %d)" % first[0].y)
		var off: bool = not Overlap.test(first[0].x, first[0].y, Tuning.HERO_BOX_HURT.x, Tuning.HERO_BOX_HURT.y,
				Tuning.HERO_BOX_HURT.z, enemy.sim_pos.x, enemy.sim_pos.y, enemy.box_w, enemy.box_h, enemy.box_xo)
		assert_true(off, label + ": slid off the head on the contact tick (x %d, the body at %d)" % [first[0].x, body_x])
		assert_true(first[0].x > body_x, label + ": to the nearer side (he came down right of its middle)")
		assert_eq(hero.sim_pos.y, START.y, label + ": on the floor beside it")
		assert_eq(Game.hearts, hearts, label + ": not hurt")
		assert_eq(enemy.bounce_count, 1, label + ": the stomp still counts on the enemy")


func test_the_slide_goes_away_from_the_rock() -> void:
	# The crown ends one column right of the body: the rock the lift would meet is on his left only.
	world_rows(_crown_rows(40, 62))
	spawn_hero(START + Vector2i(-160, 0))
	var enemy: EnemyBase = _body_at(Vector2i(62 * 16 + 4, START.y))
	_falling(hero, Vector2i(enemy.sim_pos.x - 4, START.y - 16), Tuning.STOMP_MIN_YVEL)
	play(hold("", 1))
	assert_true(hero.sim_pos.x > enemy.sim_pos.x, "left of its middle, but the rock is left: he goes right")
	assert_false(hero.body_in_rock(hero.sim_pos.x, hero.sim_pos.y))


func test_with_room_over_the_head_the_1_0_bounce_is_unchanged() -> void:
	world_flat()
	spawn_hero(START + Vector2i(-160, 0))
	var enemy: EnemyBase = _body_at(Vector2i(START_X, START.y))
	_falling(hero, Vector2i(START_X + 6, START.y - 16), Tuning.STOMP_MIN_YVEL)
	play(hold("", 1))
	assert_eq(hero.sim_pos.y, START.y - BODY_BOX.y, "lifted by the depth onto the head (PHYSICS.md 9)")
	assert_eq(hero.sim_pos.x, START_X + 6, "not moved sideways")
	assert_eq(hero.yvel, Tuning.BOUNCE_YVEL, "the full bounce")
	assert_eq(enemy.bounce_count, 1)


# =================================================================================================================
# Hero heads (C.10): a Shoulder Hop or a Totem Ride into rock is no head contact; a carry into rock lifts nobody
# =================================================================================================================

func test_no_totem_ride_and_no_shoulder_hop_whose_place_is_in_the_rock() -> void:
	for up: bool in [false, true]:
		party(Defs.GameMode.COOP, P1_START + Vector2i(-160, 0), Vector2i(START_X, START.y), true, _crown_rows())
		var label: String = "UP held" if up else "no UP"
		_falling(p1, Vector2i(START_X + 4, START.y - 18), Tuning.STOMP_MIN_YVEL)
		var in_rock: Array[int] = [0]
		var contacts: Array[int] = [0]
		play_party([[30, "U|" if up else "|"]], func(_t: int) -> void:
			if p1.body_in_rock(p1.sim_pos.x, p1.sim_pos.y):
				in_rock[0] += 1
			contacts[0] += driver.contacts.size()
		)
		assert_eq(contacts[0], 0, label + ": no head contact under the crown (he passes through his partner)")
		assert_null(p1.totem_carrier, label + ": no ride")
		assert_eq(in_rock[0], 0, label + ": never in the rock")
		assert_eq(p1.sim_pos.y, START.y, label + ": down on the floor")
	# The same pair in the open: the ride and the hop are there (the guard acts only where rock is).
	party(Defs.GameMode.COOP, P1_START + Vector2i(-160, 0), Vector2i(START_X, START.y), true)
	_falling(p1, Vector2i(START_X + 4, START.y - 18), Tuning.STOMP_MIN_YVEL)
	play_party([[2, "|"]])
	assert_eq(p1.totem_carrier, p2, "in the open: a Totem Ride")


func test_a_carrier_jumping_under_rock_sheds_his_rider_without_lifting_him_into_it() -> void:
	# Two rows more of air: a rider fits on P2's head (feet 34 px over P2's, 11 px of room over his own head), but the
	# carrier's halved hop (15 px) would carry him into the crown.
	party(Defs.GameMode.COOP, P1_START + Vector2i(-160, 0), Vector2i(START_X, START.y), true,
			_crown_rows(52, 72, CROWN_ROW - 2))
	_falling(p1, Vector2i(START_X, START.y - PartyTuning.TOTEM_REST_PX - 4), 64)
	play_party([[3, "|"]])
	assert_eq(p1.totem_carrier, p2, "riding: there is room for him on the head")
	assert_false(p1.body_in_rock(p1.sim_pos.x, p1.sim_pos.y))
	var in_rock: Array[int] = [0]
	var peak: Array[int] = [p1.sim_pos.y]
	play_party([[40, "|U"]], func(_t: int) -> void:
		if p1.body_in_rock(p1.sim_pos.x, p1.sim_pos.y):
			in_rock[0] += 1
		peak[0] = mini(peak[0], p1.sim_pos.y)
	)
	assert_null(p1.totem_carrier, "scraped off his carrier's head at the rock")
	assert_eq(in_rock[0], 0, "never carried into the rock")
	assert_eq(peak[0], START.y - PartyTuning.TOTEM_REST_PX, "never lifted over the place he rode at")
	assert_eq(p1.sim_pos.y, START.y, "fell to the floor")


# =================================================================================================================
# The 9-3 crown (D9b, w9_l3): a chieftain on the altar under the 5-row crown
# =================================================================================================================

## enemies-C's test hall (the w9_l3 hall of D9b: crown rows 0-4 - underside y 80 -, one-way ledges and the altar on
## row 8, top y 128): a hero falling fast beside a chieftain who stands on the altar meets his head 13 px under the
## crown. The chieftain's own head bounce (Chieftain._heroes_bounce, enemies-C) reaches PlayerBase.bounce: no lift
## into the crown, no juggle, he slides off and lands on the altar's level.
func test_the_9_3_crown_a_hero_on_a_chieftain_under_the_crown_never_enters_the_rock() -> void:
	var path: String = "res://levels/test_enemies_chieftain.lvl"
	assert_true(FileAccess.file_exists(path), "enemies-C's chieftain hall exists")
	if not FileAccess.file_exists(path):
		return
	Sim.manual = true
	Game.start_run(Defs.Difficulty.EXPERT, Defs.GameMode.SINGLE, 1, 2)
	Game.begin_level(&"test_enemies_chieftain")
	var hall: Level = (load(LEVEL_SCENE) as PackedScene).instantiate() as Level
	hall.setup_from_text(&"test_enemies_chieftain", FileAccess.get_file_as_string(path))
	add_node(hall)
	hall.set_view_size(Vector2i(640, 360))
	var chief: Chieftain = null
	for entity: SimEntity in hall.get_kind(Defs.Kind.BOSS):
		var candidate: Chieftain = entity as Chieftain
		if candidate != null and (chief == null or candidate.sim_pos.y < chief.sim_pos.y):
			chief = candidate  # the one on the altar (Gulla)
	assert_not_null(chief, "the hall has its chieftains")
	if chief == null:
		return
	var h: PlayerBase = hall.player
	var top: int = chief.sim_pos.y - chief.box_h
	assert_true(top - 80 < 32, "his head is less than a hero's height under the crown (top %d)" % top)
	# Feet 19 px under his top, falling 8 px/tick (a stomp by speed); 112 is the lowest the crown lets a hero rise to.
	_falling(h, Vector2i(chief.sim_pos.x + 4, top + 19), Tuning.STOMP_MIN_YVEL)
	assert_false(h.body_in_rock(h.sim_pos.x, h.sim_pos.y), "he starts out of the rock")
	_bounces = 0
	Events.hero_bounced.connect(_on_bounced)
	chief._heroes_bounce()
	Events.hero_bounced.disconnect(_on_bounced)
	assert_eq(_bounces, 1, "the chieftain bounced him")
	assert_false(h.body_in_rock(h.sim_pos.x, h.sim_pos.y), "not lifted into the crown (feet %s)" % h.sim_pos)
	assert_true(h.sim_pos.y >= top + 19, "no lift at all")
	assert_true(h.yvel >= 0, "no rise: there is no room over that head")
	var off: bool = not Overlap.test(h.sim_pos.x, h.sim_pos.y, Tuning.HERO_BOX_HURT.x, Tuning.HERO_BOX_HURT.y,
			Tuning.HERO_BOX_HURT.z, chief.sim_pos.x, chief.sim_pos.y, chief.box_w, chief.box_h, chief.box_xo)
	assert_true(off, "slid off his head (the chieftain found by the overlap test)")
	hall.free()
	Sim.stop()
	Game.new_game(Defs.Difficulty.BEGINNER)
	Game.begin_level(&"")


# =================================================================================================================
# The 4-1 co-op zigzag ledges (DB3, w4_l1_coop): a partner swinging under the other's ledge is never a step into rock
# =================================================================================================================

func _load_w4_l1_coop() -> Level:
	Sim.manual = true
	Game.start_run(Defs.Difficulty.EXPERT, Defs.GameMode.COOP, 2, 1)
	Game.begin_level(&"w4_l1_coop")
	var shaft: Level = (load(LEVEL_SCENE) as PackedScene).instantiate() as Level
	shaft.setup_from_text(&"w4_l1_coop", FileAccess.get_file_as_string("res://levels/w4_l1_coop.lvl"))
	add_node(shaft)
	shaft.set_view_size(Vector2i(640, 360))
	return shaft


func _close(shaft: Level) -> void:
	GameInput.clear_scripted()
	shaft.free()
	Sim.stop()
	Game.new_game(Defs.Difficulty.BEGINNER)
	Game.begin_level(&"")


func test_the_4_1_zigzag_a_partner_falling_under_a_ledge_is_never_lifted_into_its_rock() -> void:
	var shaft: Level = _load_w4_l1_coop()
	var a: PlayerBase = shaft.player
	var b: PlayerBase = shaft.get_hero(1)
	var grid: TileGrid = shaft.grid
	# The first zigzag: the one-way ledge of row 10 runs under the rock block of rows 7-8 (columns 12 on).
	assert_eq(grid.get_char(12, 10), TileGrid.CH_ONEWAY_A, "the zigzag ledge of row 10")
	assert_eq(grid.get_char(12, 8), TileGrid.CH_SOLID_A, "the rock over it")
	for slot: int in 2:
		GameInput.set_scripted_slot(slot, func(_tick: int) -> int: return Defs.IN_SWAP)
	Sim.step(2)  # both players are there (the IDLE rule: no head contact with a hero who never pressed anything)
	# (1) DB3's report: P2 stands on the ledge, P1 falls fast just below it - the stomp-by-speed contact would put him on
	# P2's head, 34 px over P2's feet: inside the rock block.
	b.teleport(Vector2i(200, 160))
	b.grounded = true
	b.yvel = 0
	_falling(a, Vector2i(202, 181), Tuning.STOMP_MIN_YVEL)
	assert_true(PlayerBase.grid_rock_at(grid, 202, 160 - PartyTuning.TOTEM_REST_PX), "the ride spot is rock")
	Sim.step(1)
	assert_null(a.totem_carrier, "(1) no ride into the rock")
	assert_false(a.body_in_rock(a.sim_pos.x, a.sim_pos.y), "(1) P1 is not in the rock (%s)" % a.sim_pos)
	assert_true(a.sim_pos.y > 181, "(1) he falls on, past the ledge")
	# (2) The other way round (the replay below found it): P2 walks on the ledge while P1 falls right under it, so P2's
	# feet are in the top half of P1's box - P2 would stand on P1's head with his own head in the rock.
	b.teleport(Vector2i(214, 160))
	b.grounded = true
	b.yvel = 0
	_falling(a, Vector2i(216, 181), 64)
	Sim.step(1)
	assert_null(b.totem_carrier, "(2) no ride for P2 either")
	assert_eq(b.sim_pos.y, 160, "(2) P2 stays on his ledge, not lifted into the rock block")
	_close(shaft)


## The original report, replayed: both players play the route's P1 keys (P2 two ticks behind) down the first zigzags;
## until G54 P2 rode onto P1's head into the rock block on tick 120. No hero rides or is carried with his box in rock.
func test_the_4_1_zigzag_same_keys_descent_never_rides_into_rock() -> void:
	var shaft: Level = _load_w4_l1_coop()
	var text: String = FileAccess.get_file_as_string("res://tools/autoplay/routes/w4_l1_coop.inputs")
	var keys: PackedInt32Array = Autoplay.parse_inputs_multi(text)[0]
	var first: int = Sim.tick + 1
	GameInput.set_scripted_slot(0, func(tick: int) -> int:
		var i: int = tick - first
		return keys[i] if i >= 0 and i < keys.size() else 0
	)
	GameInput.set_scripted_slot(1, func(tick: int) -> int:
		var i: int = tick - first - 2
		return keys[i] if i >= 0 and i < keys.size() else 0
	)
	var bad: PackedStringArray = PackedStringArray()
	var close_calls: int = 0
	for t: int in 130:
		Sim.step(1)
		for h: PlayerBase in shaft.heroes:
			if h.totem_carrier != null and h.body_in_rock(h.sim_pos.x, h.sim_pos.y):
				bad.append("tick %d P%d riding at %s" % [t + 1, h.slot + 1, h.sim_pos])
		var dy: int = shaft.heroes[0].sim_pos.y - shaft.heroes[1].sim_pos.y
		if absi(shaft.heroes[0].sim_pos.x - shaft.heroes[1].sim_pos.x) < 16 and absi(dy) > 8 and absi(dy) < 35:
			close_calls += 1
	assert_eq(bad, PackedStringArray(), "no hero rides with his box in the rock")
	assert_true(close_calls > 0, "the descent brings one hero right under the other (the reported case)")
	_close(shaft)
