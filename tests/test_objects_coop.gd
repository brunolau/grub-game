extends ObjectsTestCase
## The co-op objects of 2.0 (docs/expansion/PLAN.md P1.9; DESIGN.md D.5, GAMEPLAY.md 13.9.2 / 13.9.7, PHYSICS.md C):
## x2 tablets, hero starts, plates and the plate / keeper / drum doors of objects/column, drums and drum-locked gates,
## the see-saw (its launches against docs/spec/PARTY_REFERENCE.json), the heave boulder, the pulley, the flower pot,
## the team exit and team gate, the checkpoint that hatches eggs, the per-hero item effects and the spear pick-up.
## Bare heroes (PlayerBase: no controller, no gravity) of a co-op party of two stand where the tests put them; the
## real heroes play levels/test_objects_coop.lvl at the end. Single-player is untouched by all of it: the route
## digests (tools/sp_identity.sh) prove that.

const PARTY_REFERENCE: String = "res://docs/spec/PARTY_REFERENCE.json"
const COOP_LEVEL: StringName = &"test_objects_coop"
const NEW_IDS: Array[StringName] = [
	&"objects/x2_tablet", &"objects/hero_start", &"objects/plate", &"objects/drum", &"objects/seesaw",
	&"objects/boulder_heavy", &"objects/pulley", &"objects/flower_pot",
]
## The floor of make_ground_level(): row 10 is ground, so a hero standing on it has his feet at y 160.
const FLOOR_Y: int = 160

var p2: PlayerBase = null
## The real level of the last load_coop_level() (null otherwise), and Sim.manual before it.
var real: Level = null
var _was_manual: bool = false


func before_each() -> void:
	super.before_each()
	Game.start_run(Defs.Difficulty.BEGINNER, Defs.GameMode.COOP, 2)
	Game.begin_level(&"test_objects")


func after_each() -> void:
	if real != null:
		GameInput.clear_scripted()
		Sim.manual = _was_manual
		Flow.pending_level_id = &""
		Audio.stop_music(0.0)
		real = null
	super.after_each()
	Game.new_game(Defs.Difficulty.BEGINNER)
	Game.begin_level(&"")
	p2 = null


## A ground level (row 10 down solid) with P1 (`hero`) and P2 (`p2`) standing at the given x.
func party(x1: int, x2: int, cols: int = 48) -> void:
	make_ground_level(cols, 16, 10)
	add_hero(Vector2i(x1, FLOOR_Y))
	p2 = PlayerBase.new()
	place(level, p2, Vector2i(x2, FLOOR_Y), {"slot": 1})
	p2.respawn_at(Vector2i(x2, FLOOR_Y))


func feet(col: float, row: float) -> Vector2i:
	return LevelText.cell_to_feet(col, row)


## A bare hero standing on a platform's surface (feet 1 px inside its top, as after a ride test).
func ride(who: PlayerBase, platform: PlatformBase) -> void:
	who.teleport(Vector2i(platform.sim_pos.x, platform.sim_pos.y - platform.box_h + 1))
	who.yvel = 0


func fill(col: int, row: int, w: int, h: int, ch: String) -> void:
	for r: int in range(row, row + h):
		for c: int in range(col, col + w):
			level.set_cell(c, r, ch)


# =================================================================================================================
# Scenes, x2 tablets, hero starts
# =================================================================================================================

func test_every_co_op_object_has_its_scene() -> void:
	for id: StringName in NEW_IDS:
		assert_true(Spawner.exists(id), "%s has a scene" % id)


func test_x2_tablet_marks_its_gate_and_lights_up_when_a_hatched_hero_reaches_the_far_cell() -> void:
	party(40, 60)
	var tablet: X2Tablet = spawn(&"objects/x2_tablet", feet(4, 9), {"gate": "ledge", "far": "20,9"}) as X2Tablet
	var secret: X2Tablet = spawn(&"objects/x2_tablet", feet(8, 9), {"gate": "cache", "far": "30, 4",
		"secret": true}) as X2Tablet
	var broken: X2Tablet = spawn(&"objects/x2_tablet", feet(10, 9), {"gate": "x", "far": "nowhere"}) as X2Tablet
	assert_eq(tablet.gate_name, &"ledge")
	assert_eq(tablet.far_cell, Vector2i(20, 9))
	assert_eq((tablet.get_node("Sprite") as Sprite2D).frame, X2Tablet.FRAME_GATE)
	assert_eq(secret.far_cell, Vector2i(30, 4))
	assert_eq((secret.get_node("Sprite") as Sprite2D).frame, X2Tablet.FRAME_SECRET, "an x2 secret")
	assert_eq(broken.far_cell, Vector2i(-1, -1), "a malformed far cell")
	Sim.step(2)
	assert_false(tablet.solved)
	p2.go_down(&"test")
	p2.teleport(feet(20, 9))
	Sim.step(1)
	assert_false(tablet.solved, "an egg touches nothing")
	hero.teleport(feet(20, 9))
	Sim.step(1)
	assert_true(tablet.solved, "a hatched hero stood in the far cell")
	assert_eq((tablet.get_node("Sprite") as Sprite2D).frame, X2Tablet.FRAME_SOLVED)
	level.reset_entities()
	assert_true(tablet.solved, "the marks stay lit through a team wipe")
	assert_false(secret.solved)
	assert_true(tablet._can_doze(), "a tablet only waits: it may doze far from the heroes")


func test_hero_start_is_a_marker_with_the_slot_picture() -> void:
	party(40, 60)
	var start: HeroStart = spawn(&"objects/hero_start", feet(6, 9), {"slot": 3}) as HeroStart
	assert_eq(start.slot, 3)
	assert_eq((start.get_node("Sprite") as Sprite2D).frame, 2, "frame = slot - 1")
	assert_eq(start._sim_phases().size(), 0, "it takes no phase")
	var clamped: HeroStart = spawn(&"objects/hero_start", feet(7, 9), {"slot": 9}) as HeroStart
	assert_eq(clamped.slot, Defs.MAX_PLAYERS)


# =================================================================================================================
# Plates
# =================================================================================================================

func test_a_plate_counts_hatched_heroes_standing_on_its_cells() -> void:
	party(40, 400)
	var plate: Plate = spawn(&"objects/plate", feet(10, 9), {"name": "p"}) as Plate
	assert_eq([plate.left_px(), plate.right_px(), plate.floor_y()], [160, 192, FLOOR_Y], "anchor = left cell, w 2")
	assert_eq(plate.count, 1)
	assert_eq(plate.mode, Plate.Mode.HOLD)
	Sim.step(1)
	assert_false(plate.pressed)
	p2.teleport(Vector2i(170, FLOOR_Y))
	Sim.step(1)
	assert_true(plate.pressed, "P2 stands on it")
	assert_eq(plate.weight, PartyTuning.PLATE_WEIGHT_HERO)
	assert_eq(plate.holder_mask, 2)
	assert_eq(plate.presses, 1)
	p2.teleport(Vector2i(191, FLOOR_Y))
	Sim.step(1)
	assert_true(plate.pressed, "the last px of its cells")
	p2.teleport(Vector2i(192, FLOOR_Y))
	Sim.step(1)
	assert_false(plate.pressed, "beyond its cells")
	p2.teleport(Vector2i(170, FLOOR_Y - ObjTuning.PLATE_FEET_SLACK_PX))
	Sim.step(1)
	assert_true(plate.pressed, "lifted a few px (a screen shake) he still stands on it")
	p2.teleport(Vector2i(170, FLOOR_Y - ObjTuning.PLATE_FEET_SLACK_PX - 1))
	Sim.step(1)
	assert_false(plate.pressed, "higher up he does not")
	p2.teleport(Vector2i(170, FLOOR_Y - 2))
	p2.grounded = false
	p2.yvel = -32
	Sim.step(1)
	assert_false(plate.pressed, "a hero jumping off it does not press it")
	p2.respawn_at(Vector2i(170, FLOOR_Y))
	p2.go_down(&"test")
	Sim.step(1)
	assert_false(plate.pressed, "an egg weighs nothing")
	assert_eq(plate.weight, 0)


func test_a_plate_for_two_and_the_timed_and_latched_modes() -> void:
	party(40, 400)
	var two: Plate = spawn(&"objects/plate", feet(10, 9), {"name": "two", "count": 2}) as Plate
	var timed: Plate = spawn(&"objects/plate", feet(20, 9), {"name": "t", "mode": "timed:5"}) as Plate
	var latch: Plate = spawn(&"objects/plate", feet(30, 9), {"name": "l", "mode": "latch", "w": 1}) as Plate
	assert_eq(timed.mode, Plate.Mode.TIMED)
	assert_eq(timed.timed_ticks, 5)
	assert_eq(latch.right_px() - latch.left_px(), Tuning.TILE)
	hero.teleport(Vector2i(165, FLOOR_Y))
	Sim.step(1)
	assert_false(two.pressed, "one hero is not enough for count=2")
	p2.teleport(Vector2i(185, FLOOR_Y))
	Sim.step(1)
	assert_true(two.pressed, "two are")
	# Timed: pressed for exactly 5 ticks after the weight left.
	hero.teleport(Vector2i(330, FLOOR_Y))
	Sim.step(1)
	assert_true(timed.pressed)
	hero.teleport(Vector2i(40, FLOOR_Y))
	var held: int = 0
	for i: int in 10:
		Sim.step(1)
		if timed.pressed:
			held += 1
	assert_eq(held, 5, "timed:5 stays pressed 5 ticks")
	# Latch: pressed for good, until the team wipe.
	p2.teleport(Vector2i(485, FLOOR_Y))
	Sim.step(1)
	p2.teleport(Vector2i(40, FLOOR_Y))
	Sim.step(5)
	assert_true(latch.pressed, "a latch stays pressed")
	level.reset_entities()
	assert_false(latch.pressed, "the team wipe releases it")
	assert_false(two.pressed)


func test_a_heave_boulder_resting_on_a_plate_weighs_two() -> void:
	party(40, 60)
	var plate: Plate = spawn(&"objects/plate", feet(10, 9), {"name": "p", "count": 2}) as Plate
	spawn(&"objects/boulder_heavy", feet(10, 9))
	Sim.step(1)
	assert_eq(plate.weight, PartyTuning.PLATE_WEIGHT_BOULDER)
	assert_true(plate.pressed, "a boulder holds a plate for two")


# =================================================================================================================
# Doors: plate columns, keeper doors, static blocks
# =================================================================================================================

## A wall at column 20 (rows 0..9) whose bottom three cells are a plate door rising into the wall above.
func make_door(params: Dictionary) -> RisingColumn:
	fill(20, 0, 1, 10, TileGrid.CH_SOLID_A)
	var all: Dictionary = {"size": "1,3", "rise": 3}
	all.merge(params, true)
	return spawn(&"objects/column", feet(20, 9), all) as RisingColumn


func test_a_plate_door_opens_while_the_plate_is_held_and_closes_when_released() -> void:
	party(40, 400)
	var plate: Plate = spawn(&"objects/plate", feet(8, 9), {"name": "p"}) as Plate
	var door: RisingColumn = make_door({"rise_while": "p"})
	assert_eq(door.drive, RisingColumn.Drive.PLATES)
	assert_eq(door.shake, 0, "plate doors do not shake by default")
	assert_false(door._can_doze(), "a plate door never dozes")
	Sim.step(5)
	assert_eq(door.risen, 0)
	hero.teleport(Vector2i(140, FLOOR_Y))
	Sim.step(1)
	assert_true(plate.pressed)
	Sim.step(PartyTuning.PLATE_COLUMN_PERIOD - 1)
	assert_eq(door.risen, 1, "one row after one period")
	assert_eq(level.get_cell(20, 9), TileGrid.CH_AIR, "a door: the cell it leaves becomes air")
	assert_eq(level.get_cell(20, 6), TileGrid.CH_SOLID_A)
	Sim.step(PartyTuning.PLATE_COLUMN_PERIOD * 4)
	assert_eq(door.risen, 3, "open: `rise` rows")
	for row: int in range(7, 10):
		assert_eq(level.get_cell(20, row), TileGrid.CH_AIR, "row %d open" % row)
	# Released: it comes back one row per period, but never down into a hero standing in the doorway.
	p2.teleport(Vector2i(20 * 16 + 8, FLOOR_Y))
	hero.teleport(Vector2i(40, FLOOR_Y))
	Sim.step(1 + PartyTuning.PLATE_COLUMN_PERIOD * 3)
	assert_eq(door.risen, 2, "it waits above P2 (his body reaches row 8)")
	p2.teleport(Vector2i(400, FLOOR_Y))
	Sim.step(PartyTuning.PLATE_COLUMN_PERIOD * 3)
	assert_eq(door.risen, 0, "closed again")
	for row: int in range(0, 10):
		assert_eq(level.get_cell(20, row), TileGrid.CH_SOLID_A, "row %d as at rest" % row)


func test_two_plates_must_both_be_held_and_a_plate_pillar_lifts_its_riders() -> void:
	party(40, 400)
	spawn(&"objects/plate", feet(4, 9), {"name": "a"})
	spawn(&"objects/plate", feet(40, 9), {"name": "b"})
	spawn(&"objects/plate", feet(14, 9), {"name": "c"})
	# Pillars of the ground (row 10) rising into the air: ground under them stays ground.
	var twin: RisingColumn = spawn(&"objects/column", feet(25, 10), {"size": "1,1", "rise": 2,
		"rise_while": "a,b"}) as RisingColumn
	var lift: RisingColumn = spawn(&"objects/column", feet(30, 10), {"size": "2,1", "rise": 2,
		"rise_while": "c"}) as RisingColumn
	assert_eq(twin.plate_names, PackedStringArray(["a", "b"]))
	hero.teleport(Vector2i(70, FLOOR_Y))
	Sim.step(PartyTuning.PLATE_COLUMN_PERIOD * 2)
	assert_eq(twin.risen, 0, "one plate of two")
	p2.teleport(Vector2i(650, FLOOR_Y))
	Sim.step(PartyTuning.PLATE_COLUMN_PERIOD)
	assert_eq(twin.risen, 1, "both held")
	assert_eq(level.get_cell(25, 9), TileGrid.CH_SOLID_A, "the pillar rose")
	assert_eq(level.get_cell(25, 10), TileGrid.CH_SOLID_A, "ground under a pillar stays ground")
	# P1 holds c, P2 rides the two-cell pillar up.
	p2.teleport(Vector2i(30 * 16 + 16, FLOOR_Y))
	hero.teleport(Vector2i(14 * 16 + 4, FLOOR_Y))
	Sim.step(PartyTuning.PLATE_COLUMN_PERIOD * 2)
	assert_eq(lift.risen, 2)
	assert_eq(p2.sim_pos.y, FLOOR_Y - 2 * Tuning.TILE, "it lifted P2")
	assert_eq(level.get_cell(30, 8), TileGrid.CH_SOLID_A)
	assert_eq(level.get_cell(31, 9), TileGrid.CH_SOLID_A)


func test_a_sinking_plate_door_sinks_into_the_floor_and_comes_back() -> void:
	party(40, 400)
	spawn(&"objects/plate", feet(4, 9), {"name": "p"})
	level.set_cell(30, 9, TileGrid.CH_SOLID_A)
	var gate: RisingColumn = spawn(&"objects/column", feet(30, 9), {"rise": 1, "sink_while": "p"}) as RisingColumn
	assert_true(gate.sinks)
	hero.teleport(Vector2i(70, FLOOR_Y))
	Sim.step(PartyTuning.PLATE_COLUMN_PERIOD + 1)
	assert_eq(gate.risen, 1)
	assert_eq(level.get_cell(30, 9), TileGrid.CH_AIR, "sunk: the doorway is open")
	assert_eq(level.get_cell(30, 10), TileGrid.CH_SOLID_A)
	hero.teleport(Vector2i(40, FLOOR_Y))
	Sim.step(PartyTuning.PLATE_COLUMN_PERIOD + 1)
	assert_eq(gate.risen, 0)
	assert_eq(level.get_cell(30, 9), TileGrid.CH_SOLID_A, "back up")
	hero.teleport(Vector2i(70, FLOOR_Y))
	Sim.step(PartyTuning.PLATE_COLUMN_PERIOD + 1)
	level.reset_entities()
	assert_eq(gate.risen, 0, "a team wipe puts it back")
	assert_eq(level.get_cell(30, 9), TileGrid.CH_SOLID_A)


func test_a_keeper_door_opens_when_every_keeper_is_dead_and_closes_on_a_team_wipe() -> void:
	party(40, 60)
	var keepers: Array[EnemyBase] = []
	for x: int in [200, 240]:
		var enemy: EnemyBase = EnemyBase.new()
		place(level, enemy, Vector2i(x, FLOOR_Y), {"keeper": "hall"})
		keepers.append(enemy)
	var bystander: EnemyBase = EnemyBase.new()
	place(level, bystander, Vector2i(280, FLOOR_Y))
	var door: RisingColumn = make_door({"trigger": "keepers:hall"})
	assert_eq(door.drive, RisingColumn.Drive.KEEPERS)
	assert_eq(door.group, &"hall")
	Sim.step(3)
	assert_false(door.triggered)
	keepers[0].kill(&"weapon", hero)
	Sim.step(3)
	assert_false(door.triggered, "one keeper still stands")
	keepers[1].kill(&"weapon", p2)
	Sim.step(1)
	assert_true(door.triggered, "every keeper is dead (the bystander does not count)")
	Sim.step(Tuning.COLUMN_RISE_PERIOD * 3)
	assert_eq(door.risen, 3)
	for row: int in range(7, 10):
		assert_eq(level.get_cell(20, row), TileGrid.CH_AIR, "the keeper door is open at row %d" % row)
	level.reset_entities()
	assert_false(keepers[0].dead, "the keepers are back")
	for row: int in range(0, 10):
		assert_eq(level.get_cell(20, row), TileGrid.CH_SOLID_A, "and the door is shut at row %d" % row)


func test_a_static_column_is_an_expert_only_block() -> void:
	party(40, 60)
	var block: RisingColumn = spawn(&"objects/column", feet(12, 6), {"size": "2,1", "rise": 0}) as RisingColumn
	assert_eq(block.drive, RisingColumn.Drive.STATIC)
	assert_eq(level.get_cell(12, 6), TileGrid.CH_SOLID_A, "its air cells became ground")
	assert_eq(level.get_cell(13, 6), TileGrid.CH_SOLID_A)
	hero.teleport(feet(12, 5))
	Sim.step(20)
	assert_eq(block.risen, 0)
	assert_eq(level.get_cell(12, 5), TileGrid.CH_AIR, "it never moves")


# =================================================================================================================
# Drums and drum-locked doors and gates
# =================================================================================================================

func test_twin_drums_succeed_inside_the_window_and_go_dark_after_it() -> void:
	party(40, 60)
	var d1: Drum = spawn(&"objects/drum", feet(5, 9), {"bond": "twin"}) as Drum
	var d2: Drum = spawn(&"objects/drum", feet(30, 9), {"bond": "twin"}) as Drum
	var other: Drum = spawn(&"objects/drum", feet(40, 9), {"bond": "solo"}) as Drum
	assert_eq(d1.bond_drums(level), [d1, d2] as Array[Drum], "the bond in registration order; d1 leads")
	var window: int = PartyTuning.window_ticks(Defs.Difficulty.BEGINNER)
	assert_eq(d1.window_ticks(), window)
	assert_eq(window, 24)
	# Too late: the window closes after `window` ticks and both go dark.
	assert_true(d2.take_hit(25, p2), "a hit is consumed")
	assert_true(d2.lit)
	assert_eq(d1.window_left, window, "the first hit of a try opens the window on the leader")
	Sim.step(window)
	assert_eq(d1.window_left, 0)
	assert_false(d2.lit, "dark again")
	d1.take_hit(25, hero)
	assert_false(d1.succeeded, "a hit after the window starts a new try")
	assert_true(d1.lit)
	assert_eq(d1.window_left, window)
	# In time: the second drum on the window's last tick.
	level.reset_entities()
	assert_false(d1.lit)
	d1.take_hit(25, hero)
	Sim.step(window - 1)
	assert_eq(d1.window_left, 1)
	d2.take_hit(25, p2)
	assert_true(d1.succeeded and d2.succeeded, "both lit inside the window")
	assert_true(Drum.bond_succeeded(level, &"twin"))
	assert_false(Drum.bond_succeeded(level, &"solo"))
	assert_false(Drum.bond_succeeded(level, &"nothing"), "no drum, no success")
	Sim.step(window + 5)
	assert_true(d1.lit and d2.succeeded, "for good")
	assert_false(other.lit)
	level.reset_entities()
	assert_false(Drum.bond_succeeded(level, &"twin"), "a team wipe undoes it")


func test_a_drum_takes_one_hit_per_cool_down_and_its_hit_test_covers_its_body() -> void:
	party(40, 60)
	var drum: Drum = spawn(&"objects/drum", feet(10, 9), {"bond": "b"}) as Drum
	drum.take_hit(25, hero)
	assert_true(drum.take_hit(25, hero), "consumed during the cool-down")
	assert_eq(drum.hits, 1, "but not counted")
	Sim.step(Tuning.HIDDEN_SPOT_HIT_COOLDOWN)
	drum.take_hit(25, hero)
	assert_eq(drum.hits, 2)
	assert_true(drum.is_hit_by(Vector2i(168, 150)), "a box origin at its body")
	assert_true(drum.is_hit_by(Vector2i(152, 170)), "one column beside, down to the floor cell")
	assert_false(drum.is_hit_by(Vector2i(200, 150)), "two columns away")
	assert_false(drum.is_hit_by(Vector2i(168, 120)), "above its top")


func test_the_expert_window_is_twelve_ticks() -> void:
	party(40, 60)
	Game.difficulty = Defs.Difficulty.EXPERT
	var d1: Drum = spawn(&"objects/drum", feet(5, 9), {"bond": "twin"}) as Drum
	spawn(&"objects/drum", feet(30, 9), {"bond": "twin"})
	assert_eq(d1.window_ticks(), 12)
	d1.window = 7
	assert_eq(d1.window_ticks(), 7, "a tool may shorten it (window = min(base, solo_min - 4))")
	Game.difficulty = Defs.Difficulty.BEGINNER


func test_a_drum_bond_opens_its_column_and_unlocks_its_gate() -> void:
	party(40, 60)
	var d1: Drum = spawn(&"objects/drum", feet(5, 9), {"bond": "gong"}) as Drum
	var d2: Drum = spawn(&"objects/drum", feet(35, 9), {"bond": "gong"}) as Drum
	var door: RisingColumn = make_door({"trigger": "drums:gong"})
	var gate: Gate = spawn(&"objects/gate", feet(2, 9), {"name": "in", "dest": "out", "skin": "none",
		"needs": "gong"}) as Gate
	spawn(&"objects/marker", Vector2i(600, FLOOR_Y), {"name": "out"})
	assert_eq(door.drive, RisingColumn.Drive.DRUMS)
	assert_true(gate.locked)
	hero.teleport(feet(2, 9))
	hero.drop_timer = Tuning.DROP_TIMER
	Sim.step(2)
	assert_eq(hero.sim_pos, feet(2, 9), "the locked gate takes nobody")
	d1.take_hit(25, hero)
	d2.take_hit(25, p2)
	hero.drop_timer = 0
	Sim.step(1)
	assert_false(gate.locked, "the bond unlocked it")
	assert_true(door.triggered, "and started its door")
	hero.drop_timer = Tuning.DROP_TIMER
	Sim.step(1)
	assert_eq(hero.sim_pos, Vector2i(600, FLOOR_Y), "the gate works now")


# =================================================================================================================
# See-saw
# =================================================================================================================

func test_seesaw_launches_the_low_end_rider_as_the_reference_table_says() -> void:
	party(40, 60)
	var seesaw: Seesaw = spawn(&"objects/seesaw", feet(10, 9), {"len": 5}) as Seesaw
	assert_eq(seesaw.high_side, 1, "facing right: the right end is high")
	assert_eq(seesaw.low_end(), seesaw.left_end)
	assert_eq(seesaw.low_end().top(), FLOOR_Y - ObjTuning.SEESAW_LOW_TOP_PX)
	assert_eq(seesaw.high_end().top(), FLOOR_Y - ObjTuning.SEESAW_LOW_TOP_PX - ObjTuning.SEESAW_STEP_PX)
	Sim.step(1)
	var json: JSON = JSON.new()
	assert_eq(json.parse(FileAccess.get_file_as_string(PARTY_REFERENCE)), OK)
	var rows: Array = (json.data as Dictionary)["seesaw"]
	assert_eq(rows.size(), 6)
	for row: Dictionary in rows:
		level.reset_entities()
		var landing: int = int(row["landing_yvel"])
		# A walk-off fall of n tiles: the landing move is the k-th airborne tick (v = 16 (k - 1)); the ride test of the
		# next tick finds the hero one airborne step later: yvel + 16 (capped), k fall ticks.
		var k: int = landing / Tuning.GRAVITY + 1
		if int(row["walk_off_tiles"]) == 8:
			k = 20
		ride(p2, seesaw.low_end())
		hero.teleport(Vector2i(seesaw.high_end().sim_pos.x, seesaw.high_end().top() + 3))
		hero.yvel = mini(landing + Tuning.GRAVITY, Tuning.TERMINAL)
		hero.fall_ticks = k
		Sim.step(1)
		assert_eq(seesaw.last_launch, int(row["launch"]), "%d tiles: launch" % int(row["walk_off_tiles"]))
		assert_eq(p2.yvel, int(row["launch"]), "%d tiles: P2 on the low end is launched" % int(row["walk_off_tiles"]))
		assert_eq(seesaw.high_side, -1, "and the plank flipped")


func test_seesaw_flips_in_two_ticks_and_a_weak_landing_only_lifts() -> void:
	party(40, 60)
	var seesaw: Seesaw = spawn(&"objects/seesaw", feet(10, 9), {"len": 5}) as Seesaw
	var left: Seesaw.End = seesaw.left_end
	var right: Seesaw.End = seesaw.right_end
	var low_top: int = left.top()
	var high_top: int = right.top()
	Sim.step(1)
	# A landing at 16 v16 (contact yvel 16: launch -48, weaker than -64): P2 is only lifted by the rising end.
	ride(p2, left)
	hero.teleport(Vector2i(right.sim_pos.x, high_top + 2))
	hero.yvel = 32
	hero.fall_ticks = 2
	Sim.step(1)
	assert_eq(seesaw.flips, 1)
	assert_eq(seesaw.last_launch, -48)
	assert_eq(p2.yvel, 1, "not launched")
	Sim.step(ObjTuning.SEESAW_FLIP_TICKS)
	assert_eq(left.top(), high_top, "the left end is up after 2 ticks")
	assert_eq(right.top(), low_top)
	assert_eq(p2.sim_pos.y, high_top + 1, "and P2 rose with it")
	# Walking onto the plank (no landing speed) never flips it; an egg rides nothing.
	var flips: int = seesaw.flips
	hero.teleport(Vector2i(left.sim_pos.x + 8, high_top + 1))
	hero.yvel = 0
	Sim.step(3)
	assert_eq(seesaw.flips, flips, "standing on the high end does not flip it")
	hero.teleport(Vector2i(40, FLOOR_Y))
	p2.go_down(&"test")
	p2.teleport(Vector2i(left.sim_pos.x, high_top + 3))
	p2.yvel = 112
	p2.fall_ticks = 7
	Sim.step(2)
	assert_eq(seesaw.flips, flips, "an egg flips nothing")
	level.reset_entities()
	assert_eq(seesaw.high_side, 1, "a team wipe puts the plank back")
	assert_eq(right.top(), high_top)


func test_seesaw_throws_enemies_off_the_low_end() -> void:
	party(40, 300)
	var seesaw: Seesaw = spawn(&"objects/seesaw", feet(10, 9), {"len": 5}) as Seesaw
	var enemy: EnemyBase = EnemyBase.new()
	place(level, enemy, Vector2i(seesaw.left_end.sim_pos.x, FLOOR_Y))
	enemy.wake()
	Sim.step(1)
	hero.teleport(Vector2i(seesaw.right_end.sim_pos.x, seesaw.right_end.top() + 3))
	hero.yvel = 112
	hero.fall_ticks = 7
	Sim.step(1)
	assert_eq(seesaw.last_launch, -128)
	assert_eq(enemy.yvel, -128, "the enemy on the low end is thrown off")


func test_seesaw_contact_speed_from_the_ride_test() -> void:
	assert_eq(Seesaw.contact_yvel(112, 7), 96)
	assert_eq(Seesaw.contact_yvel(Tuning.TERMINAL, 12), 176, "at the terminal speed: from the fall ticks")
	assert_eq(Seesaw.contact_yvel(Tuning.TERMINAL, 13), 192)
	assert_eq(Seesaw.contact_yvel(Tuning.TERMINAL, 30), Tuning.TERMINAL)


# =================================================================================================================
# Heave boulder
# =================================================================================================================

func push(who: PlayerBase, x: int, flags: int) -> void:
	who.teleport(Vector2i(x, FLOOR_Y))
	who.input_flags = flags


func test_a_heave_boulder_moves_one_tile_after_two_heroes_push_six_ticks() -> void:
	party(40, 60)
	var boulder: HeavyBoulder = spawn(&"objects/boulder_heavy", feet(20, 9)) as HeavyBoulder
	assert_eq(boulder.block, Rect2i(20, 8, 2, 2))
	assert_eq(boulder.sim_pos, Vector2i(21 * 16, FLOOR_Y), "the feet point is the bottom centre of its 2 x 2 cells")
	for cell: Vector2i in [Vector2i(20, 8), Vector2i(21, 8), Vector2i(20, 9), Vector2i(21, 9)]:
		assert_eq(level.get_cell(cell.x, cell.y), TileGrid.CH_SOLID_INVISIBLE, "solid at %s" % cell)
	var face: int = 20 * 16
	# One hero alone only strains.
	push(hero, face - Tuning.WALL_PROBE - 1, Defs.IN_RIGHT)
	Sim.step(PartyTuning.BOULDER_STEP_TICKS * 2)
	assert_eq(boulder.moves, 0, "one hero cannot move it")
	assert_eq(boulder.pushers_right, 1)
	# Two heroes: one tile after 6 ticks in a row.
	push(p2, face - Tuning.WALL_PROBE - 2, Defs.IN_RIGHT)
	Sim.step(PartyTuning.BOULDER_STEP_TICKS - 1)
	assert_eq(boulder.moves, 0)
	Sim.step(1)
	assert_eq(boulder.moves, 1)
	assert_eq(boulder.block.position, Vector2i(21, 8))
	assert_eq(level.get_cell(20, 9), TileGrid.CH_AIR, "the cells it left are air again")
	assert_eq(level.get_cell(22, 9), TileGrid.CH_SOLID_INVISIBLE)
	# A wall stops it; so does a hero in the way.
	fill(23, 8, 1, 2, TileGrid.CH_SOLID_A)
	push(hero, 21 * 16 - 10, Defs.IN_RIGHT)
	push(p2, 21 * 16 - 11, Defs.IN_RIGHT)
	Sim.step(PartyTuning.BOULDER_STEP_TICKS * 2)
	assert_eq(boulder.block.position, Vector2i(21, 8), "the wall holds it")
	# Back to the left: both push from the right.
	fill(23, 8, 1, 2, TileGrid.CH_AIR)
	push(hero, 23 * 16 + 10, Defs.IN_LEFT)
	push(p2, 23 * 16 + 11, Defs.IN_LEFT | Defs.IN_RIGHT)
	Sim.step(PartyTuning.BOULDER_STEP_TICKS * 2)
	assert_eq(boulder.moves, 1, "Left + Right together pushes nowhere")
	push(p2, 23 * 16 + 11, Defs.IN_LEFT)
	Sim.step(PartyTuning.BOULDER_STEP_TICKS)
	assert_eq(boulder.block.position, Vector2i(20, 8))
	level.reset_entities()
	assert_eq(boulder.block, Rect2i(20, 8, 2, 2), "home after a team wipe")


func test_a_heave_boulder_falls_into_a_gap_but_never_onto_a_hero() -> void:
	party(40, 400)
	fill(30, 10, 2, 2, TileGrid.CH_AIR)
	var boulder: HeavyBoulder = spawn(&"objects/boulder_heavy", feet(30, 9)) as HeavyBoulder
	p2.teleport(Vector2i(30 * 16 + 8, 12 * 16))
	Sim.step(ObjTuning.BOULDER_FALL_TICKS * 3)
	assert_eq(boulder.block.position.y, 8, "P2 stands in the gap: it waits")
	assert_true(boulder.falling)
	p2.teleport(Vector2i(400, FLOOR_Y))
	Sim.step(ObjTuning.BOULDER_FALL_TICKS * 2)
	assert_eq(boulder.block, Rect2i(30, 10, 2, 2), "it fills the gap")
	assert_false(boulder.falling)
	assert_eq(level.get_cell(30, 9), TileGrid.CH_AIR)
	assert_eq(level.get_cell(31, 11), TileGrid.CH_SOLID_INVISIBLE)
	assert_true(HeavyBoulder.cell_is_boulder(level, 31, 10), "a vent under it would be plugged")
	assert_false(HeavyBoulder.cell_is_boulder(level, 31, 9))
	Sim.step(10)
	assert_eq(boulder.block.position.y, 10, "it rests on the floor of the gap")


# =================================================================================================================
# Pulley
# =================================================================================================================

func test_a_pulley_sinks_the_heavier_platform_and_lifts_the_other_within_its_range() -> void:
	party(40, 60)
	var a: MovingPlatform = spawn(&"objects/platform", feet(8, 6), {"name": "pa", "mode": "ride"}) as MovingPlatform
	var b: MovingPlatform = spawn(&"objects/platform", feet(14, 6), {"name": "pb", "mode": "ride"}) as MovingPlatform
	var pulley: Pulley = spawn(&"objects/pulley", feet(11, 3), {"a": "pa", "b": "pb", "range": 1}) as Pulley
	var a_home: Vector2i = a.sim_pos
	var b_home: Vector2i = b.sim_pos
	Sim.step(1)
	assert_eq(pulley.platform_a(), a)
	assert_eq(a.pulley, pulley, "it drives both platforms")
	Sim.step(3)
	assert_eq(a.sim_pos, a_home, "equal weights (none) do not move")
	for i: int in 3:
		ride(hero, a)
		Sim.step(1)
	assert_eq(pulley.weight_a, 1)
	assert_eq(a.sim_pos.y - a_home.y, PartyTuning.PULLEY_SPEED_PX * 2, "a sinks 2 px per tick (one tick later)")
	assert_eq(b_home.y - b.sim_pos.y, PartyTuning.PULLEY_SPEED_PX * 2, "b rises as much")
	for i: int in 20:
		ride(hero, a)
		Sim.step(1)
	assert_eq(pulley.offset, Tuning.TILE, "range=1: one row at most")
	assert_eq(a.sim_pos.y - a_home.y, Tuning.TILE)
	assert_eq(b_home.y - b.sim_pos.y, Tuning.TILE)
	for i: int in 4:
		ride(hero, a)
		ride(p2, b)
		Sim.step(1)
	assert_eq(pulley.offset, Tuning.TILE, "equal weights hold")
	p2.go_down(&"test")
	for i: int in 4:
		ride(hero, a)
		p2.teleport(Vector2i(b.sim_pos.x, b.sim_pos.y - b.box_h + 1))
		Sim.step(1)
	assert_eq(pulley.weight_b, 0, "an egg weighs nothing")
	level.reset_entities()
	assert_eq(a.sim_pos, a_home)
	assert_eq(b.sim_pos, b_home)
	assert_eq(pulley.offset, 0)


# =================================================================================================================
# Flower pot
# =================================================================================================================

func test_a_struck_flower_pot_falls_off_its_ledge_and_becomes_a_spring() -> void:
	party(40, 400)
	fill(0, 4, 11, 1, TileGrid.CH_SOLID_A)
	var pot: FlowerPot = spawn(&"objects/flower_pot", feet(10, 3)) as FlowerPot
	assert_eq(pot.sim_pos, Vector2i(168, 64))
	assert_true(pot.is_hit_by(Vector2i(160, 70)), "the weapon pass reaches it like a hidden cell")
	hero.facing = 1
	assert_true(pot.take_hit(25, hero))
	assert_eq(pot.state, FlowerPot.State.SLIDE)
	assert_false(pot.take_hit(25, hero), "moving, it lets the weapon pass")
	var springs: int = count_alive(Defs.Kind.OTHER, preload("res://scripts/objects/spring.gd"))
	for i: int in 60:
		Sim.step(1)
		if pot.state == FlowerPot.State.SPRUNG:
			break
	assert_eq(pot.state, FlowerPot.State.SPRUNG)
	assert_eq(pot.sim_pos.y, FLOOR_Y, "it landed on the ground")
	assert_true(pot.sim_pos.x > 176, "beyond the ledge's edge")
	assert_eq(count_alive(Defs.Kind.OTHER, preload("res://scripts/objects/spring.gd")), springs + 1)
	var spring: SpringPad = pot.spring as SpringPad
	assert_not_null(spring)
	assert_eq(spring.sim_pos, pot.sim_pos, "a spring where it landed")
	assert_eq(spring.power, ObjTuning.SPRING_DEFAULT_POWER)
	Sim.step(20)
	assert_true(spring.visible, "after the sprout the spring shows")
	assert_false(pot.visible)
	level.reset_entities()
	assert_eq(pot.state, FlowerPot.State.SPRUNG, "a landed spring stays through a team wipe")
	assert_true(is_instance_valid(spring))


func test_a_flower_pot_lost_in_a_liquid_returns_and_a_wall_stops_it() -> void:
	party(40, 400)
	fill(0, 4, 11, 1, TileGrid.CH_SOLID_A)
	fill(11, 10, 3, 1, TileGrid.CH_LIQUID)
	level.set_cell(9, 3, TileGrid.CH_SOLID_A)
	var pot: FlowerPot = spawn(&"objects/flower_pot", feet(10, 3)) as FlowerPot
	hero.facing = -1
	pot.take_hit(25, hero)
	Sim.step(10)
	assert_eq(pot.state, FlowerPot.State.IDLE, "pushed into the wall it stands again")
	hero.facing = 1
	Sim.step(Tuning.HIDDEN_SPOT_HIT_COOLDOWN)
	assert_true(pot.take_hit(25, hero), "and can be struck again")
	for i: int in 60:
		Sim.step(1)
	assert_eq(pot.state, FlowerPot.State.LOST, "it fell into the water")
	level.reset_entities()
	assert_eq(pot.state, FlowerPot.State.IDLE, "a team wipe puts it back on its ledge")
	assert_eq(pot.sim_pos, Vector2i(168, 64))
	assert_true(pot.visible)


# =================================================================================================================
# Team exit, team gate, the checkpoint that hatches
# =================================================================================================================

func test_the_team_exit_waits_for_both_heroes_and_counts_an_egg_on_the_view() -> void:
	party(40, 60)
	spawn(&"objects/exit", Vector2i(300, FLOOR_Y))
	var exit: LevelExitBase = level.get_kind(Defs.Kind.EXIT)[0] as LevelExitBase
	hero.teleport(Vector2i(300, FLOOR_Y))
	Sim.step(2)
	assert_false(level.completed, "P1 alone at the totem: it waits")
	assert_eq(exit.present_mask, 1)
	assert_true(hero.control_enabled, "and he keeps control")
	p2.kill(&"pit")
	Sim.step(2)
	assert_false(level.completed, "a partner in his death toss is not present")
	p2.respawn_at(Vector2i(100, FLOOR_Y))
	p2.go_down(&"test")
	p2.teleport(Vector2i(600, 100))
	Sim.step(1)
	assert_false(level.completed, "an egg off the view is not present")
	p2.teleport(Vector2i(100, 100))
	Sim.step(1)
	assert_true(level.completed, "an egg on the view counts")
	assert_eq(level.completed_kinds, [&"exit"] as Array[StringName])


func test_the_team_exit_needs_both_touching_it() -> void:
	party(40, 60)
	spawn(&"objects/exit", Vector2i(300, FLOOR_Y))
	p2.teleport(Vector2i(300, FLOOR_Y))
	Sim.step(1)
	assert_false(level.completed)
	hero.teleport(Vector2i(304, FLOOR_Y))
	Sim.step(1)
	assert_true(level.completed, "both at the totem")
	assert_false(hero.control_enabled, "the totem took the first toucher in slot order (P1)")
	assert_eq(level.completed_kinds, [&"exit"] as Array[StringName])


func test_the_team_gate_takes_the_partner_behind_the_hero_and_a_far_one_as_an_egg() -> void:
	party(40, 60)
	spawn(&"objects/gate", feet(5, 9), {"name": "in", "dest": "out", "skin": "none"})
	spawn(&"objects/marker", Vector2i(600, FLOOR_Y), {"name": "out"})
	hero.teleport(feet(5, 9))
	hero.facing = 1
	hero.drop_timer = Tuning.DROP_TIMER
	Sim.step(1)
	assert_eq(hero.sim_pos, Vector2i(600, FLOOR_Y), "P1 travels")
	assert_eq(p2.sim_pos, Vector2i(600 - PartyTuning.PULL_IN_BEHIND_PX, FLOOR_Y), "P2 arrives behind him")
	assert_true(p2.control_enabled and hero.control_enabled)
	assert_false(p2.is_down())
	# Back through a gate at the destination, with P2 far away: he arrives as an egg.
	hero.drop_timer = 0
	p2.drop_timer = 0
	Sim.step(1)
	spawn(&"objects/gate", feet(37, 9), {"name": "back", "dest": "home", "skin": "none"})
	spawn(&"objects/marker", feet(3, 9), {"name": "home"})
	hero.teleport(feet(37, 9))
	hero.facing = -1
	p2.teleport(Vector2i(30, FLOOR_Y))
	hero.drop_timer = Tuning.DROP_TIMER
	Sim.step(1)
	assert_eq(hero.sim_pos, feet(3, 9))
	assert_true(p2.is_down(), "more than a view away: an egg")
	assert_eq(p2.sim_pos, feet(3, 9) + Vector2i(PartyTuning.EGG_OFFSET_X * -1, PartyTuning.EGG_OFFSET_Y),
			"at the egg's place beside him")


func test_partner_spot_needs_a_floor_behind_the_hero() -> void:
	party(40, 60)
	assert_eq(Gate.partner_spot(level, Vector2i(300, FLOOR_Y), 1), Vector2i(276, FLOOR_Y))
	fill(17, 10, 1, 1, TileGrid.CH_AIR)
	assert_eq(Gate.partner_spot(level, Vector2i(300, FLOOR_Y), 1), Vector2i(300, FLOOR_Y), "no floor: his own point")
	assert_eq(Gate.partner_spot(level, Vector2i(10, FLOOR_Y), 1), Vector2i(10, FLOOR_Y), "the map's edge")


func test_a_checkpoint_touched_by_either_hero_hatches_every_egg() -> void:
	party(40, 60)
	var checkpoint: Checkpoint = spawn(&"objects/checkpoint", Vector2i(200, FLOOR_Y)) as Checkpoint
	p2.go_down(&"test")
	p2.teleport(Vector2i(150, 100))
	p2.teleport(Vector2i(200, FLOOR_Y))
	Sim.step(1)
	assert_false(checkpoint.active, "an egg touches no checkpoint")
	p2.teleport(Vector2i(150, 100))
	hero.teleport(Vector2i(200, FLOOR_Y))
	Sim.step(1)
	assert_true(checkpoint.active)
	assert_false(p2.is_down(), "P1 lit it and hatched P2")
	assert_eq(p2.run.hearts, PartyTuning.HATCH_HEARTS_BEGINNER)
	assert_eq(p2.shield, PartyTuning.HATCH_BLINK_TICKS)
	assert_eq(p2.sim_pos, Vector2i(150, 100), "in place")
	# The active checkpoint hatches again (Expert: one heart).
	Game.difficulty = Defs.Difficulty.EXPERT
	hero.teleport(Vector2i(40, FLOOR_Y))
	p2.go_down(&"test")
	Sim.step(2)
	assert_true(p2.is_down())
	hero.teleport(Vector2i(200, FLOOR_Y))
	Sim.step(1)
	assert_false(p2.is_down(), "touching the active checkpoint hatches the egg")
	assert_eq(p2.run.hearts, PartyTuning.HATCH_HEARTS_EXPERT)
	Game.difficulty = Defs.Difficulty.BEGINNER


# =================================================================================================================
# Items: per-hero effects, the belt rule and the spear
# =================================================================================================================

func test_a_bone_at_full_energy_flies_to_the_partner_below_full() -> void:
	party(40, 400)
	Game.runs[1].hearts = 1
	Game.runs[1].bones = Tuning.BONES_PER_HEART - 1
	spawn(&"items/bone", Vector2i(40, FLOOR_Y))
	Sim.step(1)
	assert_eq(Game.runs[1].hearts, 2, "P2's sixth bone restored a heart")
	assert_eq(Game.runs[1].bones, 0)
	assert_eq(Game.hearts, Tuning.ENERGY_START, "P1 is full")
	assert_eq(Game.bones, 0, "and kept nothing")
	Game.runs[1].hearts = Tuning.ENERGY_START
	spawn(&"items/bone", Vector2i(40, FLOOR_Y))
	Sim.step(1)
	assert_eq(Game.bones, 1, "both full: the collector keeps it (1.0)")


func test_a_heart_stays_for_the_partner_and_the_feast_feeds_the_whole_party() -> void:
	party(40, 400)
	Game.runs[1].hearts = 1
	var heart: CollectibleBase = spawn(&"items/heart", Vector2i(40, FLOOR_Y)) as CollectibleBase
	Sim.step(1)
	assert_false(heart.collected, "P1 is full: it stays")
	p2.teleport(Vector2i(40, FLOOR_Y))
	hero.teleport(Vector2i(300, FLOOR_Y))
	Sim.step(1)
	assert_true(heart.collected, "for P2")
	assert_eq(Game.runs[1].hearts, 2)
	Game.collect_feast_piece(0)
	Game.collect_feast_piece(1)
	spawn(&"items/feast_piece", Vector2i(300, FLOOR_Y), {"index": 2})
	Sim.step(1)
	assert_true(hero.is_feasting(), "the collector feasts")
	assert_true(p2.is_feasting(), "and so does his partner")


func test_eggs_never_collect_and_a_co_op_hero_keeps_his_share_of_the_score() -> void:
	party(40, 400)
	p2.go_down(&"test")
	p2.teleport(Vector2i(300, FLOOR_Y))
	var food: CollectibleBase = spawn(&"items/food", Vector2i(300, FLOOR_Y), {"index": 3}) as CollectibleBase
	Sim.step(2)
	assert_false(food.collected, "an egg touches no item")
	hero.teleport(Vector2i(300, FLOOR_Y))
	var score: int = Game.score
	Sim.step(1)
	assert_true(food.collected)
	assert_eq(Game.runs[0].score, Game.score - score, "P1's share of the tribe score")
	assert_eq(Game.runs[1].score, 0)


## The belt rule itself is the hero's (HeroBelt.give_weapon, player-B; tests/test_player_belt.gd and the real heroes of
## the level test below): a bare hero has no belt, so he gets the 1.0 rule.
func test_the_spear_pick_up_and_the_one_weapon_rule_without_a_belt() -> void:
	party(40, 400)
	var spear: WeaponPickup = spawn(&"items/weapon", Vector2i(40, FLOOR_Y), {"kind": "spear"}) as WeaponPickup
	assert_eq(spear.weapon, Defs.Weapon.SPEAR)
	assert_eq(spear.index, Defs.Weapon.SPEAR)
	var sprite: Sprite2D = spear.get_node("Sprite") as Sprite2D
	assert_eq(sprite.texture.resource_path, "res://assets/sprites/items/weapon_spear.png")
	assert_eq(sprite.offset, WeaponPickup.SPEAR_OFFSET, "the planted spear stands on its butt")
	var hammer: WeaponPickup = spawn(&"items/weapon", Vector2i(300, FLOOR_Y), {"kind": "hammer"}) as WeaponPickup
	assert_eq((hammer.get_node("Sprite") as Sprite2D).offset, Vector2(-16, -40), "the other pick-ups keep theirs")
	Sim.step(1)
	assert_eq([Game.weapon, Game.runs[0].belt], [Defs.Weapon.SPEAR, PlayerRun.BELT_EMPTY], "1.0: one weapon")
	assert_true(spear.visible == false and spear.reappears_on_respawn, "it reappears on a respawn")
	var temp: WeaponPickup = spawn(&"items/weapon", Vector2i(400, FLOOR_Y), {"kind": "axe", "temp": true}) \
			as WeaponPickup
	assert_true(temp.temp)
	Sim.step(1)
	assert_eq(Game.runs[1].weapon, Defs.Weapon.AXE, "P2's own run")


# =================================================================================================================
# Eggs touch nothing
# =================================================================================================================

func test_eggs_ride_no_platform_bounce_on_no_spring_and_trigger_no_column() -> void:
	party(40, 400)
	var platform: PlatformBase = PlatformBase.new()
	place(level, platform, Vector2i(100, 120))
	var spring: SpringPad = spawn(&"objects/spring", Vector2i(200, FLOOR_Y)) as SpringPad
	var column: RisingColumn = spawn(&"objects/column", feet(30, 10), {"size": "1,1", "rise": 1}) as RisingColumn
	var thorn: HazardBase = HazardBase.new()
	place(level, thorn, Vector2i(300, FLOOR_Y))
	Sim.step(1)
	p2.go_down(&"test")
	ride(p2, platform)
	p2.yvel = 0
	Sim.step(1)
	assert_false(platform.ridden, "an egg rides nothing")
	p2.teleport(Vector2i(200, 152))
	p2.yvel = 32
	Sim.step(1)
	assert_eq(spring.launches, 0, "an egg bounces on no spring")
	p2.teleport(feet(30, 9))
	Sim.step(1)
	assert_false(column.triggered, "an egg triggers no column")
	p2.teleport(Vector2i(300, FLOOR_Y))
	Sim.step(1)
	assert_eq(p2.hit_timer, 0, "and touches no hazard")


## Versus (world-B's Grub Stack refills): HittableBase.refill() puts a used-up spot or container back; a broken block
## stays broken.
func test_refill_puts_a_used_up_spot_and_a_container_back() -> void:
	party(40, 400)
	var spot: HittableBase = spawn(&"objects/hidden_spot", feet(10, 10), {"kind": "small", "count": 1,
		"contents": "food:3", "look": "inset"}) as HittableBase
	var crate: HittableBase = spawn(&"objects/container", feet(14, 9), {"contents": "food:4"}) as HittableBase
	level.set_cell(18, 9, TileGrid.CH_SOLID_INVISIBLE)
	var block: HittableBase = spawn(&"objects/breakable_block", feet(18, 9), {"hits": 1}) as HittableBase
	for hittable: HittableBase in [spot, crate, block]:
		hittable.take_hit(25, hero)
		assert_true(hittable.opened)
	Sim.step(Tuning.HIDDEN_SPOT_HIT_COOLDOWN)
	spot.refill()
	crate.refill()
	block.refill()
	assert_false(spot.opened, "the spot is back")
	assert_eq(spot.hits_left, 1)
	assert_eq(level.looks.get(Vector2i(10, 10)), ObjTuning.ATLAS_INSET, "with its inset look")
	assert_false(crate.opened)
	assert_true((crate.get_node("Sprite") as Sprite2D).visible, "the crate stands again")
	assert_true(block.opened, "a broken block stays broken")
	var items: int = count_items()
	spot.take_hit(25, hero)
	assert_eq(count_items(), items + 1, "and it throws its item again")


# =================================================================================================================
# levels/test_objects_coop.lvl with two real heroes (the level scene, its loader and world-A's PartyDriver)
# =================================================================================================================

## The workshop level with a co-op party of two real heroes (P2 at his objects/hero_start).
func load_coop_level() -> Level:
	_was_manual = Sim.manual
	Sim.manual = true
	Game.start_run(Defs.Difficulty.BEGINNER, Defs.GameMode.COOP, 2)
	Game.begin_level(COOP_LEVEL)
	var made: Level = (load(Flow.LEVEL_SCENE) as PackedScene).instantiate() as Level
	made.setup_from_text(COOP_LEVEL, FileAccess.get_file_as_string(Levels.get_level_path(COOP_LEVEL)))
	add_node(made)
	made.set_view_size(Vector2i(Tuning.VIEW_W, Tuning.VIEW_H) * Tuning.ART_SCALE)
	real = made
	return made


## The first live entity of `kind` whose script is `script`.
func first_of(lv: LevelBase, kind: int, script: Script) -> SimEntity:
	for entity: SimEntity in lv.get_kind(kind):
		if entity.get_script() == script:
			return entity
	return null


## Put a real hero at `pos` (feet), facing `face`.
func put(who: PlayerBase, pos: Vector2i, face: int = 1) -> void:
	who.respawn_at(pos)
	who.facing = face


func test_the_workshop_level_is_valid_and_loads_both_heroes_and_every_object() -> void:
	var validator: LevelValidator = LevelValidator.new()
	assert_true(validator.add_file(Levels.get_level_path(COOP_LEVEL)))
	validator.run()
	var errors: PackedStringArray = PackedStringArray()
	for problem: Dictionary in validator.problems:
		if int(problem["severity"]) == LevelValidator.ERROR:
			errors.append(LevelValidator.format_problem(problem))
		else:
			print("    warning: %s" % LevelValidator.format_problem(problem))
	assert_eq(errors, PackedStringArray(), "no validator error")
	var lv: Level = load_coop_level()
	assert_eq(lv.hero_count(), 2)
	assert_eq(lv.get_hero(1).sim_pos, feet(5, 9), "P2 at his hero_start")
	assert_not_null(lv.party_driver, "a co-op level runs world-A's PartyDriver")
	for script: Script in [preload("res://scripts/objects/x2_tablet.gd"), preload("res://scripts/objects/seesaw.gd"),
			preload("res://scripts/objects/boulder_heavy.gd"), preload("res://scripts/objects/pulley.gd"),
			preload("res://scripts/objects/plate.gd")]:
		assert_not_null(first_of(lv, Defs.Kind.OTHER, script), "%s spawned" % script.resource_path)
	assert_not_null(first_of(lv, Defs.Kind.HITTABLE, preload("res://scripts/objects/drum.gd")))
	assert_not_null(first_of(lv, Defs.Kind.HITTABLE, preload("res://scripts/objects/flower_pot.gd")))
	assert_eq(lv.get_cell(64, 9), TileGrid.CH_SOLID_INVISIBLE, "the boulder's cells are solid")
	var pulley: Pulley = first_of(lv, Defs.Kind.OTHER, preload("res://scripts/objects/pulley.gd")) as Pulley
	Sim.step(1)
	assert_not_null(pulley.platform_a(), "the pulley found its platforms")


func test_real_heroes_the_fresh_belt_takes_the_spear() -> void:
	var lv: Level = load_coop_level()
	var run: PlayerRun = Game.runs[0]
	assert_eq([run.weapon, run.belt], [Defs.Weapon.CLUB, PlayerRun.BELT_EMPTY], "a fresh stage starts with the club")
	put(lv.player, feet(9, 9))
	Sim.step(2)
	assert_eq([run.weapon, run.belt], [Defs.Weapon.SPEAR, Defs.Weapon.CLUB], "special in the hand, club on the belt")


func test_real_heroes_one_holds_the_plate_the_other_walks_through_the_door() -> void:
	var lv: Level = load_coop_level()
	var door: RisingColumn = null
	for entity: SimEntity in lv.get_kind(Defs.Kind.OTHER):
		if entity is RisingColumn and (entity as RisingColumn).drive == RisingColumn.Drive.PLATES:
			door = entity
	assert_not_null(door)
	put(lv.get_hero(1), Vector2i(22 * 16 + 16, FLOOR_Y))
	put(lv.player, Vector2i(28 * 16, FLOOR_Y))
	lv.snap_camera()
	Sim.step(1 + PartyTuning.PLATE_COLUMN_PERIOD * 3)
	assert_eq(door.risen, 3, "P2 on the plate: the door is open")
	run_party_inputs([[30, "R|"]])
	assert_true(lv.player.sim_pos.x > 33 * 16, "P1 walked through the doorway (x %d)" % lv.player.sim_pos.x)
	put(lv.get_hero(1), Vector2i(26 * 16, FLOOR_Y))
	Sim.step(PartyTuning.PLATE_COLUMN_PERIOD * 3 + 1)
	assert_eq(door.risen, 0, "released: the door is shut behind him")


func test_real_heroes_a_drop_onto_the_see_saw_launches_the_partner() -> void:
	var lv: Level = load_coop_level()
	var seesaw: Seesaw = first_of(lv, Defs.Kind.OTHER, preload("res://scripts/objects/seesaw.gd")) as Seesaw
	assert_eq(seesaw.high_side, -1, "facing=l: the left end (under the ledge) is high")
	var p1: PlayerBase = lv.player
	var partner: PlayerBase = lv.get_hero(1)
	# P1 steps off level with the drop ledge's top (row 5, 5 rows over the floor): a fall of 4 rows onto the high end.
	put(p1, Vector2i(seesaw.high_end().sim_pos.x, 5 * 16))
	put(partner, Vector2i(seesaw.low_end().sim_pos.x, FLOOR_Y))
	lv.snap_camera()
	var start_y: int = partner.sim_pos.y
	var top: int = start_y
	var launch: int = 0
	for i: int in 60:
		Sim.step(1)
		if seesaw.flips == 1 and launch == 0:
			launch = seesaw.last_launch
		if launch != 0:
			top = mini(top, partner.sim_pos.y)
			if partner.yvel > 0:
				break
	var json: JSON = JSON.new()
	json.parse(FileAccess.get_file_as_string(PARTY_REFERENCE))
	var four: Dictionary = ((json.data as Dictionary)["seesaw"] as Array)[3]
	assert_eq(launch, int(four["launch"]), "a 4-row walk-off fall is a hard landing: -272")
	assert_eq(start_y - top, int(four["rise_px"]), "P2 rose %d px" % int(four["rise_px"]))
	# P2 comes down on the end that is high now: the plank flips back and throws P1 up (it plays ping-pong).
	for i: int in 60:
		Sim.step(1)
	assert_true(seesaw.flips >= 2, "P2's hard landing flipped it back")


func test_real_heroes_two_push_the_boulder_into_the_gap() -> void:
	var lv: Level = load_coop_level()
	var boulder: HeavyBoulder = first_of(lv, Defs.Kind.OTHER, preload("res://scripts/objects/boulder_heavy.gd")) \
			as HeavyBoulder
	assert_eq(boulder.block, Rect2i(64, 8, 2, 2))
	put(lv.player, Vector2i(64 * 16 - 24, FLOOR_Y))
	put(lv.get_hero(1), Vector2i(64 * 16 - 40, FLOOR_Y))
	lv.snap_camera()
	run_party_inputs([[40, "R|"]])
	assert_eq(boulder.moves, 0, "one hero alone cannot move it")
	run_party_inputs([[160, "R|R"]])
	assert_eq(boulder.block, Rect2i(70, 10, 2, 2), "pushed six tiles and dropped into the gap")
	assert_eq(lv.get_cell(70, 10), TileGrid.CH_SOLID_INVISIBLE, "it fills the gap")


func test_real_heroes_strike_the_twin_drums_and_travel_through_the_gate() -> void:
	var lv: Level = load_coop_level()
	var gate: Gate = null
	for entity: SimEntity in lv.get_kind(Defs.Kind.OTHER):
		if entity is Gate:
			gate = entity
	var drums: Array[Drum] = []
	for entity: SimEntity in lv.get_kind(Defs.Kind.HITTABLE):
		if entity is Drum:
			drums.append(entity)
	assert_eq(drums.size(), 2)
	assert_true(gate.locked)
	assert_eq(drums[1].cell.x - drums[0].cell.x, 10, "10 cells apart")
	# Each hero stands between the drums facing his own (both inside one view).
	put(lv.player, Vector2i(drums[0].sim_pos.x + 20, FLOOR_Y), -1)
	put(lv.get_hero(1), Vector2i(drums[1].sim_pos.x - 20, FLOOR_Y), 1)
	lv.snap_camera()
	run_party_inputs([[1, "F|F"], [24, "|"]])
	assert_eq([drums[0].hits, drums[1].hits], [1, 1], "each hero's strike hit his drum")
	assert_true(Drum.bond_succeeded(lv, &"gong"), "struck together: the bond succeeded")
	Sim.step(1)
	assert_false(gate.locked)
	# Down on the gate takes the team (the PartyDriver brings P2 behind P1).
	put(lv.player, gate.sim_pos, 1)
	put(lv.get_hero(1), gate.sim_pos - Vector2i(40, 0), 1)
	lv.snap_camera()
	run_party_inputs([[4, "D|"]])
	var nest: Vector2i = lv.find_named(&"nest").sim_pos
	assert_eq(lv.player.sim_pos, nest, "P1 at the destination")
	assert_true(absi(lv.get_hero(1).sim_pos.x - nest.x) <= 2 * PartyTuning.RESPAWN_SPREAD_PX, "P2 beside him")
	assert_false(lv.get_hero(1).is_down(), "he was near: he arrives hatched")


func test_real_heroes_the_keeper_door_opens_when_both_keepers_are_dead() -> void:
	var lv: Level = load_coop_level()
	var door: RisingColumn = null
	for entity: SimEntity in lv.get_kind(Defs.Kind.OTHER):
		if entity is RisingColumn and (entity as RisingColumn).drive == RisingColumn.Drive.KEEPERS:
			door = entity
	var keepers: Array[SimEntity] = lv.get_tagged(&"keeper", &"hall")
	assert_eq(keepers.size(), 2, "two walkers keep the hall")
	for keeper: SimEntity in keepers.duplicate():
		(keeper as EnemyBase).kill(&"weapon", lv.player)
	Sim.step(1 + Tuning.COLUMN_RISE_PERIOD * 4)
	assert_eq(door.risen, 4)
	for row: int in range(6, 10):
		assert_eq(lv.get_cell(134, row), TileGrid.CH_AIR, "the keeper door is open at row %d" % row)
