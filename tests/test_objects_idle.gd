extends ObjectsTestCase
## The phase-3 IDLE rule on the co-op objects (PlayerBase.counts_for_coop; orchestrator decision): a hero whose own
## player gave no input for 10 s counts for no co-op rule - he weighs nothing on a plate or a pulley lift, flips no
## see-saw, pushes no heave boulder, readies no drum count-in, lights no drum, solves no x2 tablet - while he still
## stands, rides and is launched like any hero. Bare heroes (PlayerBase: no controller) of a co-op party of two; their
## [member PlayerBase.idle] is set by the test (the real timer is tests/test_player_idle.gd's).

const FLOOR_Y: int = 160

var p2: PlayerBase = null


func before_each() -> void:
	super.before_each()
	Game.start_run(Defs.Difficulty.BEGINNER, Defs.GameMode.COOP, 2)
	Game.begin_level(&"test_objects")


func after_each() -> void:
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


func push(who: PlayerBase, x: int, flags: int) -> void:
	who.teleport(Vector2i(x, FLOOR_Y))
	who.input_flags = flags


func test_counts_for_coop_is_alive_hatched_and_not_idle() -> void:
	party(40, 60)
	assert_true(p2.counts_for_coop())
	p2.idle = true
	assert_false(p2.counts_for_coop(), "idle")
	assert_true(p2.is_party_targetable(), "but enemies still see him")
	p2.idle = false
	p2.go_down(&"test")
	assert_false(p2.counts_for_coop(), "an egg")
	p2.respawn_at(Vector2i(60, FLOOR_Y))
	p2.kill(&"test")
	assert_false(p2.counts_for_coop(), "a death toss")


func test_an_idle_hero_weighs_nothing_on_a_plate() -> void:
	party(40, 400)
	var plate: Plate = spawn(&"objects/plate", feet(10, 9), {"name": "p"}) as Plate
	var two: Plate = spawn(&"objects/plate", feet(20, 9), {"name": "two", "count": 2}) as Plate
	p2.teleport(Vector2i(170, FLOOR_Y))
	Sim.step(1)
	assert_true(plate.pressed, "P2 who plays holds it")
	p2.idle = true
	Sim.step(1)
	assert_false(plate.pressed, "P2 dozing on it: released")
	assert_eq(plate.weight, 0)
	assert_eq(plate.holder_mask, 0)
	p2.idle = false
	Sim.step(1)
	assert_true(plate.pressed, "awake again")
	# A plate for two: one player and his dozing partner are one weight.
	hero.teleport(Vector2i(20 * 16 + 4, FLOOR_Y))
	p2.teleport(Vector2i(20 * 16 + 20, FLOOR_Y))
	Sim.step(1)
	assert_true(two.pressed)
	p2.idle = true
	Sim.step(1)
	assert_false(two.pressed, "count=2 needs two heroes who play")
	assert_eq(two.weight, PartyTuning.PLATE_WEIGHT_HERO)


func test_an_idle_rider_weighs_nothing_on_a_pulley() -> void:
	party(40, 60)
	var a: MovingPlatform = spawn(&"objects/platform", feet(8, 6), {"name": "pa", "mode": "ride"}) as MovingPlatform
	var b: MovingPlatform = spawn(&"objects/platform", feet(14, 6), {"name": "pb", "mode": "ride"}) as MovingPlatform
	var pulley: Pulley = spawn(&"objects/pulley", feet(11, 3), {"a": "pa", "b": "pb", "range": 2}) as Pulley
	Sim.step(1)
	p2.idle = true
	for i: int in 4:
		ride(p2, a)
		Sim.step(1)
	assert_eq(a.rider_mask, 2, "the dozing hero rides lift a (physics)")
	assert_eq(pulley.weight_a, 0, "but weighs nothing")
	assert_eq(pulley.offset, 0, "nothing moves")
	p2.idle = false
	for i: int in 4:
		ride(p2, a)
		Sim.step(1)
	assert_eq(pulley.weight_a, PartyTuning.PLATE_WEIGHT_HERO)
	assert_true(pulley.offset > 0, "awake: lift a sinks")


func test_an_idle_hero_landing_on_the_high_end_flips_no_see_saw() -> void:
	party(40, 60)
	var seesaw: Seesaw = spawn(&"objects/seesaw", feet(10, 9), {"len": 5}) as Seesaw
	Sim.step(1)
	# P1 waits on the low end; P2's dozing body falls onto the high end (hatched over it by his partner).
	ride(hero, seesaw.low_end())
	p2.idle = true
	p2.teleport(Vector2i(seesaw.high_end().sim_pos.x, seesaw.high_end().top() + 3))
	p2.yvel = 200
	p2.fall_ticks = 14
	Sim.step(1)
	assert_eq(seesaw.flips, 0, "a dozing lander flips nothing")
	assert_eq(seesaw.high_side, 1)
	assert_true(hero.yvel >= 0, "P1 is not launched")
	# The same landing by a partner who plays (P2 first off the plank, so that his next catch is a landing).
	level.reset_entities()
	p2.teleport(Vector2i(600, FLOOR_Y))
	Sim.step(2)
	ride(hero, seesaw.low_end())
	p2.idle = false
	p2.teleport(Vector2i(seesaw.high_end().sim_pos.x, seesaw.high_end().top() + 3))
	p2.yvel = 200
	p2.fall_ticks = 14
	Sim.step(1)
	assert_eq(seesaw.flips, 1, "a landing that counts flips it")
	assert_true(hero.yvel < 0, "and launches the low-end rider")


func test_a_dozing_rider_of_the_low_end_is_still_thrown() -> void:
	party(40, 60)
	var seesaw: Seesaw = spawn(&"objects/seesaw", feet(10, 9), {"len": 5}) as Seesaw
	Sim.step(1)
	ride(p2, seesaw.low_end())
	p2.idle = true
	hero.teleport(Vector2i(seesaw.high_end().sim_pos.x, seesaw.high_end().top() + 3))
	hero.yvel = 200
	hero.fall_ticks = 14
	Sim.step(1)
	assert_eq(seesaw.flips, 1, "P1 who plays lands on the high end")
	assert_true(p2.yvel < 0, "the plank throws whatever stands on the low end (physics, not a rule)")


func test_an_idle_hero_pushes_no_heave_boulder() -> void:
	party(40, 60)
	var boulder: HeavyBoulder = spawn(&"objects/boulder_heavy", feet(20, 9)) as HeavyBoulder
	var face: int = 20 * 16
	push(hero, face - Tuning.WALL_PROBE - 1, Defs.IN_RIGHT)
	push(p2, face - Tuning.WALL_PROBE - 2, Defs.IN_RIGHT)
	p2.idle = true
	Sim.step(PartyTuning.BOULDER_STEP_TICKS * 2)
	assert_eq(boulder.pushers_right, 1, "only P1 pushes")
	assert_eq(boulder.moves, 0, "one hero who plays cannot move it")
	p2.idle = false
	Sim.step(PartyTuning.BOULDER_STEP_TICKS)
	assert_eq(boulder.moves, 1, "two who play do")


func test_drums_count_in_only_for_heroes_who_play_and_an_idle_hit_lights_nothing() -> void:
	party(40, 60)
	var d1: Drum = spawn(&"objects/drum", feet(5, 9), {"bond": "twin"}) as Drum
	var d2: Drum = spawn(&"objects/drum", feet(30, 9), {"bond": "twin"}) as Drum
	hero.teleport(d1.sim_pos)
	p2.teleport(d2.sim_pos)
	Sim.step(1)
	assert_true(d1._heroes_ready(level, d1.bond_drums(level)), "a hero beside each drum: the count-in")
	p2.idle = true
	assert_false(d1._heroes_ready(level, d1.bond_drums(level)), "a dozing partner readies nothing")
	# A box of a dozing hero (his own swing or his ball) lights nothing; the drum still sounds.
	d2.take_hit(25, p2)
	assert_eq(d2.hits, 1, "the hit is taken")
	assert_false(d2.lit, "but lights nothing")
	assert_eq(d1.window_left, 0, "no window opened")
	p2.idle = false
	Sim.step(Tuning.HIDDEN_SPOT_HIT_COOLDOWN)
	d2.take_hit(25, p2)
	assert_true(d2.lit, "a hit of a hero who plays")


func test_an_idle_hero_solves_no_x2_tablet() -> void:
	party(40, 60)
	var tablet: X2Tablet = spawn(&"objects/x2_tablet", feet(4, 9), {"gate": "ledge", "far": "20,9"}) as X2Tablet
	Sim.step(1)
	p2.idle = true
	p2.teleport(feet(20, 9))
	Sim.step(2)
	assert_false(tablet.solved, "a dozing body in the far cell solves nothing")
	p2.idle = false
	Sim.step(1)
	assert_true(tablet.solved, "his player is back")


func test_a_dozing_driver_lets_the_gunner_weigh_chomper_on_a_plate() -> void:
	party(40, 400)
	var plate: Plate = spawn(&"objects/plate", feet(10, 9), {"name": "p", "count": 2}) as Plate
	var holder: MountStub = MountStub.new()
	place(level, holder, Vector2i(170, FLOOR_Y))
	hero.sit_on_mount(holder, PlayerBase.SEAT_DRIVER)
	p2.sit_on_mount(holder, PlayerBase.SEAT_GUNNER)
	holder.driver = hero
	holder.gunner = p2
	Sim.step(1)
	assert_eq(plate.weight, PartyTuning.PLATE_WEIGHT_CHOMPER, "the mount weighs once, through its driver")
	hero.idle = true
	Sim.step(1)
	assert_eq(plate.weight, PartyTuning.PLATE_WEIGHT_CHOMPER, "a dozing driver: through the gunner who plays")
	p2.idle = true
	Sim.step(1)
	assert_eq(plate.weight, 0, "both dozing: nothing")
	hero.idle = false
	p2.idle = false
	hero.leave_mount()
	p2.leave_mount()


## A stand-in for objects/mount: an entity with the `driver` / `gunner` fields the plate reads.
class MountStub:
	extends SimEntity
	var driver: PlayerBase = null
	var gunner: PlayerBase = null
