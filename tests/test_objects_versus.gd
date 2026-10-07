extends TestCase
## Versus objects of objects-B (docs/expansion/PLAN.md P2.7): `objects/cookpot` (Grub Stack banking one unit per 4
## crouched ticks, the Feast Rush lid, 2v2 team pots, the "banking" query of the double stomp steal; DESIGN.md E.3,
## GAMEPLAY.md 13.10.3), `objects/spawn_point` (the arena's spawns, their rotation per round and the respawn at the
## free spawn farthest from the rivals; PHYSICS.md C.14, LEVEL_DESIGN.md 15.8), `objects/coconut` (the Clubball ball:
## bounces, rolls, walls and ceilings, shots and the rally, knock-downs, headers, the missile, losses and resets, the
## bots' prediction, goals; GAMEPLAY.md 13.10.6), `objects/crate_lane` (pterodactyl crates: the shadow, the fall, one
## hit, the contents, the schedule and its rules; GAMEPLAY.md 13.10.3) and Chomper's arena pen timer on `objects/mount`
## (Mesa Rodeo: penned, the rumble and the release every 728 ticks, bites on rivals, the stomp that unseats;
## GAMEPLAY.md 13.10.9), plus levels/test_objects_versus.lvl through the real loader.

const LEVEL_SCENE: String = "res://scenes/world/level.tscn"
const VERSUS_LEVEL: String = "res://levels/test_objects_versus.lvl"
const BASE_VIEW: Vector2i = Vector2i(640, 360)
## The Clubball pitch of DESIGN.md E.5 (Coconut Cove; the goal mouths are zones, the coconut drops in at column 9).
const COVE_ROWS: Array[String] = [
	"....................", "....................", "....................", "....................",
	"%%....--------....%%", "%%................%%", "%%%..............%%%", "......--....--......",
	"....................", "....................", "####################", "####################",
]


## A hero whose club box is of a given frame (Player.club_frame; a bare PlayerBase counts as the forward front frame).
class FramedHero:
	extends PlayerBase

	var club_frame: int = Tuning.ClubFrame.FWD_FRONT


## A stand-in for world-B's referee as the level's party driver: the round clock, the mode, the 2v2 teams, the
## spill ledger and the crate contents hook (crates, Chomper).
class FakeReferee:
	extends SimEntity

	var round_ticks: int = 0
	var mode: int = Defs.VersusMode.GRUB_STACK
	var teams: PackedInt32Array = PackedInt32Array([-1, -1, -1, -1])
	var contents_answer: String = ""
	var spills: Array = []

	func team_of(slot: int) -> int:
		return teams[slot]

	func spill(hero: PlayerBase, units: int, _burst: bool = true) -> int:
		spills.append([hero.slot, units])
		return units

	func crate_contents(_lane: Object) -> String:
		return contents_answer


## The round rules of world-B's referee (VersusRules: the crate period of this round).
class RoundRules:
	extends RefCounted

	var crate_period: int = 0


## A referee with round rules.
class RulesReferee:
	extends FakeReferee

	var rules: RoundRules = null


## A referee that rules Chomper's bites itself.
class BiteReferee:
	extends FakeReferee

	var bites: Array = []

	func bite_hit(driver: PlayerBase, victim: PlayerBase, _mount: SimEntity) -> bool:
		bites.append([driver.slot, victim.slot])
		return true


## A stand-in for world-B's referee: the Grub Stack ledger the cookpot banks into (stacks and banks per slot).
class FakeKeeper:
	extends RefCounted

	var stacks: PackedInt32Array = PackedInt32Array([0, 0, 0, 0])
	var banks: PackedInt32Array = PackedInt32Array([0, 0, 0, 0])
	var teams: PackedInt32Array = PackedInt32Array([-1, -1, -1, -1])
	var feast_rush: bool = false
	var calls: int = 0

	func stack_of(slot: int) -> int:
		return stacks[slot]

	func bank_from_stack(slot: int, units: int) -> int:
		calls += 1
		var moved: int = mini(units, stacks[slot])
		stacks[slot] -= moved
		banks[slot] += moved
		return moved

	func lids_closed() -> bool:
		return feast_rush

	func team_of(slot: int) -> int:
		return teams[slot]


## The referee as the level's party driver (an entity with the ledger methods, found without the test hook).
class DriverKeeper:
	extends SimEntity

	var stacks: PackedInt32Array = PackedInt32Array([0, 0, 0, 0])
	var banks: PackedInt32Array = PackedInt32Array([0, 0, 0, 0])

	func stack_of(slot: int) -> int:
		return stacks[slot]

	func bank_from_stack(slot: int, units: int) -> int:
		var moved: int = mini(units, stacks[slot])
		stacks[slot] -= moved
		banks[slot] += moved
		return moved


var level: LevelBase = null
var _was_manual: bool = false


func before_each() -> void:
	_was_manual = Sim.manual
	Game.new_game(Defs.Difficulty.BEGINNER)
	Game.versus_match = null
	Game.begin_level(&"test_objects_versus")
	Sim.start(1)


func after_each() -> void:
	Sim.stop()
	Sim.manual = _was_manual
	GameInput.clear_scripted()
	Game.versus_match = null
	Game.new_game(Defs.Difficulty.BEGINNER)
	Game.begin_level(&"")
	Audio.stop_music(0.0)


## A 20 x 12 arena-sized level, floor from row 10.
func _arena() -> LevelBase:
	level = make_flat_level(20, 12, 10)
	return level


## A bare hero of player slot `slot` standing at `pos`.
func _hero(slot: int, pos: Vector2i) -> PlayerBase:
	var hero: PlayerBase = PlayerBase.new()
	place(level, hero, pos, {"slot": slot})
	hero.respawn_at(pos)
	return hero


func _pot(col: int, params: Dictionary = {}) -> Cookpot:
	var pot: Cookpot = level.spawn(&"objects/cookpot", LevelText.cell_to_feet(col, 9), params) as Cookpot
	return pot


func _crouch(hero: PlayerBase) -> void:
	hero.state = Defs.HeroState.CROUCH
	hero.grounded = true
	hero.yvel = 0


# =================================================================================================================
# Cookpot
# =================================================================================================================

func test_cookpot_scene_and_bank_rect() -> void:
	_arena()
	var pot: Cookpot = _pot(10)
	assert_not_null(pot, "objects/cookpot has a scene")
	assert_eq(pot.sim_pos, Vector2i(168, 160), "feet point = bottom centre of its cell, on the floor")
	assert_eq(pot.bank_rect(), Rect2i(156, 145, 24, 16))
	assert_true(pot.is_open())
	assert_eq(pot.team, -1, "anyone banks by default")
	assert_eq(pot.banker_slot(), -1)


func test_a_crouching_hero_banks_one_unit_per_4_ticks() -> void:
	_arena()
	var keeper: FakeKeeper = FakeKeeper.new()
	keeper.stacks[0] = 3
	var pot: Cookpot = _pot(10)
	pot.keeper = keeper
	var hero: PlayerBase = _hero(0, Vector2i(170, 160))
	_crouch(hero)
	Sim.step(VersusTuning.COOKPOT_BANK_TICKS - 1)
	assert_eq(keeper.banks[0], 0, "nothing before the 4th crouched tick")
	assert_true(pot.is_slot_banking(0), "but he is banking (a stomp would steal double)")
	assert_eq(pot.banker_slot(), 0)
	assert_true(Cookpot.slot_banking_anywhere(level, 0))
	Sim.step(1)
	assert_eq(keeper.banks[0], 1, "one unit on the 4th tick")
	assert_eq(keeper.stacks[0], 2)
	Sim.step(VersusTuning.COOKPOT_BANK_TICKS * 2)
	assert_eq(keeper.banks[0], 3, "one more every 4 ticks")
	assert_eq(keeper.stacks[0], 0)
	assert_eq(pot.banked_total, 3)
	Sim.step(VersusTuning.COOKPOT_BANK_TICKS)
	assert_eq(keeper.banks[0], 3, "an empty head banks nothing")


func test_standing_up_or_stepping_out_restarts_the_count() -> void:
	_arena()
	var keeper: FakeKeeper = FakeKeeper.new()
	keeper.stacks[0] = 10
	var pot: Cookpot = _pot(10)
	pot.keeper = keeper
	var hero: PlayerBase = _hero(0, Vector2i(170, 160))
	_crouch(hero)
	Sim.step(3)
	hero.state = Defs.HeroState.IDLE
	Sim.step(1)
	assert_false(pot.is_slot_banking(0), "standing: not banking")
	_crouch(hero)
	Sim.step(3)
	assert_eq(keeper.banks[0], 0, "the count restarted")
	Sim.step(1)
	assert_eq(keeper.banks[0], 1)
	hero.teleport(Vector2i(190, 160))
	_crouch(hero)
	Sim.step(8)
	assert_eq(keeper.banks[0], 1, "outside the bank rect: nothing")
	assert_false(Cookpot.slot_banking_anywhere(level, 0))
	hero.teleport(Vector2i(156, 160))
	hero.state = Defs.HeroState.CRAWL
	Sim.step(8)
	assert_eq(keeper.banks[0], 1, "crawling is not crouching")
	hero.state = Defs.HeroState.CROUCH
	hero.grounded = false
	Sim.step(8)
	assert_eq(keeper.banks[0], 1, "in the air: nothing")


func test_the_feast_rush_lid_stops_banking() -> void:
	_arena()
	var keeper: FakeKeeper = FakeKeeper.new()
	keeper.stacks[0] = 10
	var pot: Cookpot = _pot(10)
	pot.keeper = keeper
	var hero: PlayerBase = _hero(0, Vector2i(170, 160))
	_crouch(hero)
	keeper.feast_rush = true
	Sim.step(8)
	assert_false(pot.is_open(), "the keeper's lids_closed() shuts the lid")
	assert_eq(keeper.banks[0], 0, "no banking in the Feast Rush")
	assert_false(pot.is_slot_banking(0), "nobody banks under a lid (no double steal)")
	keeper.feast_rush = false
	Sim.step(4)
	assert_true(pot.is_open())
	assert_eq(keeper.banks[0], 1, "open again: banking resumes")


func test_lids_can_be_pushed_by_the_referee() -> void:
	_arena()
	var a: Cookpot = _pot(4)
	var b: Cookpot = _pot(15)
	Cookpot.set_all_lids(level, true)
	assert_false(a.is_open())
	assert_false(b.is_open())
	assert_eq(Cookpot.pots_of(level).size(), 2)
	Sim.step(2)
	assert_false(a.is_open(), "without a keeper the pushed lid stays shut")
	Cookpot.set_all_lids(level, false)
	assert_true(a.is_open() and b.is_open())


func test_team_pots_bank_only_their_team() -> void:
	_arena()
	var keeper: FakeKeeper = FakeKeeper.new()
	keeper.stacks = PackedInt32Array([5, 5, 5, 5])
	keeper.teams = PackedInt32Array([1, 2, 1, 2])
	var pot: Cookpot = _pot(10, {"team": 1})
	pot.keeper = keeper
	assert_eq(pot.team, 1)
	var p1: PlayerBase = _hero(0, Vector2i(164, 160))
	var p2: PlayerBase = _hero(1, Vector2i(172, 160))
	_crouch(p1)
	_crouch(p2)
	Sim.step(4)
	assert_eq(keeper.banks[0], 1, "team 1 banks in the team-1 pot")
	assert_eq(keeper.banks[1], 0, "team 2 does not")
	assert_false(pot.is_slot_banking(1))


func test_two_heroes_bank_side_by_side() -> void:
	_arena()
	var keeper: FakeKeeper = FakeKeeper.new()
	keeper.stacks = PackedInt32Array([2, 2, 0, 0])
	var pot: Cookpot = _pot(10)
	pot.keeper = keeper
	var p1: PlayerBase = _hero(0, Vector2i(160, 160))
	var p2: PlayerBase = _hero(1, Vector2i(176, 160))
	_crouch(p1)
	_crouch(p2)
	Sim.step(4)
	assert_eq(keeper.banks[0], 1)
	assert_eq(keeper.banks[1], 1)
	assert_eq(pot.banker_slot(), 0, "the lowest slot banking")


func test_the_party_driver_is_the_default_keeper() -> void:
	_arena()
	var driver: DriverKeeper = DriverKeeper.new()
	driver.stacks[0] = 2
	var pot: Cookpot = _pot(10)
	var hero: PlayerBase = _hero(0, Vector2i(170, 160))
	level.register_party_driver(driver)
	_crouch(hero)
	Sim.step(4)
	assert_eq(driver.banks[0], 1, "banked into Game.level.party_driver")
	assert_eq(pot.banked_total, 1)


func test_without_a_keeper_nothing_is_banked_and_nothing_breaks() -> void:
	_arena()
	var pot: Cookpot = _pot(10)
	var hero: PlayerBase = _hero(0, Vector2i(170, 160))
	_crouch(hero)
	Sim.step(12)
	assert_eq(pot.banked_total, 0)
	assert_true(pot.is_slot_banking(0), "the pose still counts as banking")


func test_dead_or_egg_heroes_never_bank() -> void:
	_arena()
	var keeper: FakeKeeper = FakeKeeper.new()
	keeper.stacks[0] = 5
	var pot: Cookpot = _pot(10)
	pot.keeper = keeper
	var hero: PlayerBase = _hero(0, Vector2i(170, 160))
	_crouch(hero)
	hero.dead = true
	Sim.step(8)
	assert_eq(keeper.banks[0], 0, "a dead hero")
	hero.dead = false
	hero.down = true
	Sim.step(8)
	assert_eq(keeper.banks[0], 0, "an egg")


# =================================================================================================================
# Spawn points
# =================================================================================================================

func _spawn_point(col: int, index: int) -> SpawnPoint:
	return level.spawn(&"objects/spawn_point", LevelText.cell_to_feet(col, 9), {"index": index}) as SpawnPoint


func test_spawn_list_starts_at_the_hero_start_then_by_index() -> void:
	_arena()
	level.start_pos = LevelText.cell_to_feet(1, 9)
	var four: SpawnPoint = _spawn_point(18, 4)
	_spawn_point(13, 3)
	_spawn_point(6, 2)
	assert_not_null(four, "objects/spawn_point has a scene")
	assert_eq(four.index, 4)
	assert_eq(SpawnPoint.spawn_list(level), [
		LevelText.cell_to_feet(1, 9), LevelText.cell_to_feet(6, 9), LevelText.cell_to_feet(13, 9),
		LevelText.cell_to_feet(18, 9),
	] as Array[Vector2i], "'@' is spawn 1, then index 2, 3, 4")
	assert_eq(_spawn_point(2, 9).index, Defs.MAX_PLAYERS, "index is clamped to 2..4")


func test_spawns_rotate_every_round() -> void:
	_arena()
	level.start_pos = LevelText.cell_to_feet(1, 9)
	_spawn_point(6, 2)
	_spawn_point(13, 3)
	_spawn_point(18, 4)
	var list: Array[Vector2i] = SpawnPoint.spawn_list(level)
	for round_index: int in 5:
		var used: Dictionary = {}
		for slot: int in 4:
			var pos: Vector2i = SpawnPoint.round_spawn(level, slot, round_index)
			assert_eq(pos, list[(slot + round_index) % 4], "slot %d, round %d" % [slot, round_index])
			used[pos] = true
		assert_eq(used.size(), 4, "every player on his own spawn in round %d" % round_index)
	assert_ne(SpawnPoint.round_spawn(level, 0, 0), SpawnPoint.round_spawn(level, 0, 1), "P1 moves on")


func test_respawn_at_the_free_spawn_farthest_from_the_rivals() -> void:
	_arena()
	level.start_pos = LevelText.cell_to_feet(1, 9)
	_spawn_point(6, 2)
	_spawn_point(13, 3)
	_spawn_point(18, 4)
	var victim: PlayerBase = _hero(0, Vector2i(100, 100))
	var rival: PlayerBase = _hero(1, LevelText.cell_to_feet(17, 9))
	assert_eq(SpawnPoint.farthest_free(level, victim), LevelText.cell_to_feet(1, 9), "away from the rival on the right")
	rival.teleport(LevelText.cell_to_feet(2, 9))
	assert_eq(SpawnPoint.farthest_free(level, victim), LevelText.cell_to_feet(18, 9))
	var other: PlayerBase = _hero(2, LevelText.cell_to_feet(18, 9))
	assert_eq(SpawnPoint.farthest_free(level, victim), LevelText.cell_to_feet(13, 9),
			"spawn 4 is taken (a hero stands on it): the farthest free one")
	other.dead = true
	assert_eq(SpawnPoint.farthest_free(level, victim), LevelText.cell_to_feet(18, 9), "dead heroes do not count")
	other.dead = false
	rival.down = true
	assert_eq(SpawnPoint.farthest_free(level, victim), LevelText.cell_to_feet(1, 9), "eggs do not count either")


func test_respawn_ties_go_to_the_lower_spawn_and_no_rival_means_spawn_1() -> void:
	_arena()
	level.start_pos = LevelText.cell_to_feet(1, 9)
	_spawn_point(18, 2)
	var victim: PlayerBase = _hero(0, Vector2i(100, 100))
	assert_eq(SpawnPoint.farthest_free(level, victim), LevelText.cell_to_feet(1, 9), "alone: the first spawn")
	_hero(1, Vector2i(LevelText.cell_to_feet(1, 9).x + LevelText.cell_to_feet(18, 9).x >> 1, 160))
	assert_eq(SpawnPoint.farthest_free(level, victim), LevelText.cell_to_feet(1, 9), "a tie: the lower index")


# =================================================================================================================
# The coconut (Clubball)
# =================================================================================================================

func _ball(col: int, row: int = 9) -> Coconut:
	return level.spawn(&"objects/coconut", LevelText.cell_to_feet(col, row)) as Coconut


## A live club box of `hero` lying on the ball (24 x 13, x_offset 12), with `power` (25 = the club, 100 = charged).
func _box_on(hero: PlayerBase, ball: Coconut, power: int = 25) -> void:
	hero.club_box = Rect2i(ball.sim_pos.x - 12, ball.sim_pos.y - 14, 24, 13)
	hero.club_box_xo = 12
	hero.club_power = power
	hero.club_box_active = true


func _framed(slot: int, pos: Vector2i, frame: int) -> FramedHero:
	var hero: FramedHero = FramedHero.new()
	hero.club_frame = frame
	place(level, hero, pos, {"slot": slot})
	hero.respawn_at(pos)
	return hero


func _cove() -> LevelBase:
	level = make_level(PackedStringArray(COVE_ROWS))
	return level


func test_coconut_scene_defaults_and_rest() -> void:
	_arena()
	var ball: Coconut = _ball(10)
	assert_not_null(ball, "objects/coconut has a scene")
	assert_eq(Vector3i(ball.box_w, ball.box_h, ball.box_xo), Coconut.BOX, "16 x 16")
	assert_eq(ball.drop_point, Vector2i(168, 160), "its cell's feet point is the drop point")
	assert_eq(ball.center(), Vector2i(168, 152))
	assert_eq(ball.ball_rect(), Rect2i(160, 144, 16, 16))
	assert_true(ball.in_play())
	assert_eq(Coconut.find(level), ball)
	var sprite: Sprite2D = ball.get_node(^"Sprite") as Sprite2D
	assert_eq(sprite.texture.resource_path, Coconut.OWN_SHEET_PATH, "art-A's coconut sheet")
	ball.golden = true
	assert_true(sprite.frame >= Coconut.OWN_SHEET_COLUMNS, "the golden coconut's row")
	ball.golden = false
	Sim.step(5)
	assert_eq(ball.sim_pos, Vector2i(168, 160), "it rests on the floor")
	assert_eq([ball.xvel, ball.yvel], [0, 0])


func test_floor_bounces_at_three_quarters_then_the_ball_rests() -> void:
	_arena()
	var ball: Coconut = _ball(10)
	ball.teleport(Vector2i(168, 96))
	Sim.step(11)
	assert_eq(ball.sim_pos.y, 96 + 55, "falling: 0, 1, 2 ... px per tick (gravity 16)")
	Sim.step(1)
	assert_eq(ball.sim_pos.y, 160, "lands on the surface on tick 12")
	assert_eq(ball.yvel, Tuning.shr(-(176 * 3), 2) + VersusTuning.BALL_GRAVITY,
			"yvel = -(yvel * 3) >> 2 = -132, and it leaves the floor on that tick (gravity)")
	var bounces: int = 0
	for i: int in 200:
		var before: int = ball.yvel
		Sim.step(1)
		if before > 0 and ball.yvel < 0:
			bounces += 1
		if ball.yvel == 0 and ball.sim_pos.y == 160:
			break
	assert_eq([ball.sim_pos.y, ball.yvel], [160, 0], "the bounces die down")
	assert_true(bounces >= 2 and bounces <= 6, "%d more bounces" % bounces)
	Sim.step(20)
	assert_eq([ball.sim_pos.y, ball.yvel], [160, 0], "and it stays at rest")
	var grid: TileGrid = level.grid
	var state: PackedInt32Array = PackedInt32Array([168, 158, 0, 32])
	Coconut.physics_step(grid, state)
	assert_eq([state[1], state[3]], [160, -24 + 16], "yvel 32 still bounces")
	state = PackedInt32Array([168, 159, 0, 31])
	Coconut.physics_step(grid, state)
	assert_eq([state[1], state[3]], [160, 0], "under 32 it rests")


func test_a_resting_ball_rolls_losing_2_per_tick() -> void:
	_arena()
	var ball: Coconut = _ball(10)
	ball.xvel = 40
	Sim.step(1)
	assert_eq(ball.xvel, 38, "the roll loss comes before the x step")
	assert_eq(ball.sim_pos.x, 170)
	Sim.step(19)
	assert_eq(ball.xvel, 0, "40 v16 roll out in 20 ticks")
	assert_eq(ball.sim_pos.x, 184, "16 px in all")
	ball.xvel = -40
	Sim.step(1)
	assert_eq(ball.xvel, -38, "both ways")


func test_walls_level_edges_and_ceilings_reflect_at_three_quarters() -> void:
	var rows: PackedStringArray = PackedStringArray()
	for row: int in 12:
		var line: String = "...................."
		if row == 3:
			line = "####################"
		elif row >= 10:
			line = "####################"
		elif row >= 4:
			line = "....#.........#....."
		rows.append(line)
	level = make_level(rows)
	var grid: TileGrid = level.grid
	var state: PackedInt32Array = PackedInt32Array([210, 120, 64, 0])
	Coconut.physics_step(grid, state)
	assert_eq(state[0], 214, "4 px on: the right edge 221 is still clear")
	var events: int = Coconut.physics_step(grid, state)
	assert_true((events & Coconut.EV_WALL) != 0)
	assert_eq([state[0], state[2]], [216, Tuning.shr(-(64 * 3), 2)], "flush against column 14's wall, xvel -48")
	state = PackedInt32Array([92, 120, -64, 0])
	Coconut.physics_step(grid, state)
	Coconut.physics_step(grid, state)
	assert_eq([state[0], state[2]], [88, 48], "the left wall (column 4): flush at 88, +48")
	state = PackedInt32Array([216, 120, 288, 0])
	Coconut.physics_step(grid, state)
	assert_eq([state[0], state[2]], [216, Tuning.shr(-(288 * 3), 2)], "18 px a tick never tunnels through a wall")
	level = make_flat_level(20, 12, 10)
	state = PackedInt32Array([12, 120, -96, 0])
	Coconut.physics_step(level.grid, state)
	assert_eq([state[0], state[2]], [8, 72], "the level edge is a wall")
	state = PackedInt32Array([308, 120, 96, 0])
	Coconut.physics_step(level.grid, state)
	assert_eq([state[0], state[2]], [312, -72])
	level = make_level(rows)
	state = PackedInt32Array([168, 84, 0, -80])
	events = Coconut.physics_step(level.grid, state)
	assert_true((events & Coconut.EV_CEILING) != 0, "row 3 is a ceiling")
	assert_eq(state[1], 80, "stopped under it")
	assert_eq(state[3], Tuning.shr(-(-80 * 3), 2) + 16, "reflected at 3/4 (60), then gravity")


func test_a_fast_fall_never_tunnels_through_a_one_way_floor() -> void:
	level = make_level(PackedStringArray([
		"....................", "....................", "....................", "....................",
		"....................", "....................", "....................", "....................",
		"..........-.........", "....................", "####################", "####################",
	]))
	var state: PackedInt32Array = PackedInt32Array([168, 127, 0, 288])
	var events: int = Coconut.physics_step(level.grid, state)
	assert_true((events & Coconut.EV_FLOOR) != 0, "crossed row 8's surface from above")
	assert_eq(state[1], 128)
	state = PackedInt32Array([168, 132, 0, 16])
	Coconut.physics_step(level.grid, state)
	assert_eq(state[1], 128, "feet inside a one-way cell land on it (the 1.0 rule)")


func test_a_forward_front_box_drives_the_ball() -> void:
	_arena()
	var ball: Coconut = _ball(10)
	var hero: PlayerBase = _hero(0, Vector2i(120, 160))
	_box_on(hero, ball)
	var shots: Array = []
	ball.shot_made.connect(func(slot: int, kind: int, charged: bool) -> void: shots.append([slot, kind, charged]))
	Sim.step(1)
	assert_false(hero.club_box_active, "the box is consumed (one target per box)")
	assert_eq(ball.xvel, Coconut.DRIVE_XVEL, "drive +144 by facing")
	assert_eq(ball.yvel, Coconut.DRIVE_YVEL + VersusTuning.BALL_GRAVITY, "-128, then this tick's gravity")
	assert_eq(ball.sim_pos, Vector2i(168 + 9, 160 - 8), "it moves in the same tick")
	assert_eq(ball.last_touch_slot, 0)
	assert_eq(shots, [[0, Coconut.SHOT_DRIVE, false]])
	assert_eq(ball.rally, 0, "the first shot of a rally")


func test_lob_grounder_smash_and_frames_that_do_not_shoot() -> void:
	_arena()
	var ball: Coconut = _ball(10)
	var lobber: FramedHero = _framed(0, Vector2i(120, 160), Tuning.ClubFrame.HIGH_FRONT)
	_box_on(lobber, ball)
	Sim.step(1)
	assert_eq([ball.xvel, ball.yvel], [Coconut.LOB_XVEL, Coconut.LOB_YVEL + 16], "lob +32, -240")
	# Every next shot comes after the rally window (no escalation in this test).
	Sim.step(VersusTuning.RALLY_WINDOW_TICKS + 1)
	ball.teleport(Vector2i(168, 160))
	ball.xvel = 0
	ball.yvel = 0
	var grounder: FramedHero = _framed(1, Vector2i(220, 160), Tuning.ClubFrame.LOW_FRONT)
	grounder.facing = -1
	_box_on(grounder, ball)
	Sim.step(1)
	assert_eq(ball.yvel, 0, "a grounder runs along the floor")
	assert_eq(ball.xvel, -Coconut.GROUNDER_XVEL + VersusTuning.BALL_ROLL_LOSS, "-96 by facing left, rolling")
	Sim.step(VersusTuning.RALLY_WINDOW_TICKS + 1)
	ball.teleport(Vector2i(168, 160))
	ball.xvel = 0
	ball.yvel = 0
	var windup: FramedHero = _framed(2, Vector2i(120, 160), Tuning.ClubFrame.FWD_WINDUP)
	_box_on(windup, ball)
	Sim.step(1)
	assert_true(windup.club_box_active, "a wind-up frame is no shot: its box stays")
	assert_eq([ball.xvel, ball.yvel], [0, 0])
	windup.club_box_active = false
	var smasher: PlayerBase = _hero(3, Vector2i(120, 160))
	_box_on(smasher, ball, Tuning.WEAPON_POWER[Defs.Weapon.CLUB] * Tuning.CHARGE_MULTIPLIER)
	Sim.step(1)
	assert_eq([ball.xvel, ball.yvel], [216, -192 + 16], "a charged box smashes x3/2")
	assert_eq(Coconut.shot_velocity(Coconut.SHOT_LOB, 1, true), Vector2i(48, -Coconut.AXIS_CAP),
			"every component within +/-288")
	assert_eq(Coconut.shot_velocity(Coconut.SHOT_DRIVE, -1, false), Vector2i(-144, -128))


func test_thrown_weapons_never_shoot() -> void:
	_arena()
	var ball: Coconut = _ball(10)
	var hero: PlayerBase = _hero(0, Vector2i(120, 160))
	hero.run.weapon = Defs.Weapon.AXE
	_box_on(hero, ball)
	Sim.step(1)
	assert_eq([ball.xvel, ball.yvel], [0, 0], "only melee boxes shoot")


func test_a_rally_escalates_up_to_12_px_per_tick() -> void:
	_arena()
	var ball: Coconut = _ball(5)
	var hero: PlayerBase = _hero(0, Vector2i(40, 160))
	for expected: int in [144, 160, 176, 192, 192]:
		ball.teleport(Vector2i(88, 160))
		ball.xvel = 0
		ball.yvel = 0
		_box_on(hero, ball)
		Sim.step(1)
		assert_eq(ball.xvel, expected, "rally %d" % ball.rally)
		Sim.step(10)
	ball.teleport(Vector2i(88, 160))
	_box_on(hero, ball, 100)
	Sim.step(1)
	assert_eq(ball.xvel, 216, "a smash keeps its own speed over the rally cap")
	Sim.step(VersusTuning.RALLY_WINDOW_TICKS + 1)
	ball.teleport(Vector2i(88, 160))
	_box_on(hero, ball)
	Sim.step(1)
	assert_eq(ball.rally, 0, "more than 44 ticks after the last shot: a new rally")
	assert_eq(ball.xvel, 144)


func test_two_boxes_on_one_tick_add_up() -> void:
	_arena()
	var ball: Coconut = _ball(10)
	var left: PlayerBase = _hero(0, Vector2i(120, 160))
	var right: PlayerBase = _hero(1, Vector2i(220, 160))
	right.facing = -1
	_box_on(left, ball)
	_box_on(right, ball)
	Sim.step(1)
	assert_false(left.club_box_active or right.club_box_active, "both boxes consumed")
	assert_eq(ball.xvel, 0, "opposite drives cancel sideways: nobody wins by slot order")
	assert_eq(ball.yvel, -256 + 16, "both lift it")
	assert_eq(ball.last_touch_slot, 0, "the lowest slot is named")


func test_a_fast_ball_knocks_a_hero_down_without_immunity() -> void:
	_arena()
	var ball: Coconut = _ball(11)
	var hero: PlayerBase = _hero(0, Vector2i(200, 160))
	var hearts: int = hero.run.hearts
	var knocked: Array = []
	ball.knocked_down.connect(func(who: PlayerBase) -> void: knocked.append(who))
	ball.teleport(Vector2i(180, 160))
	ball.xvel = 160
	Sim.step(1)
	assert_eq(knocked, [hero], "faster than 8 px/tick: knocked down")
	assert_true(hero.hit_timer > 0, "the versus hurt (stunned)")
	assert_eq(hero.run.hearts, hearts, "it costs no energy")
	assert_eq([ball.xvel, ball.yvel], [-79, 0], "and bounces back at half speed")
	hero.hit_timer = VersusTuning.STUN_HIT_TIMER_MIN
	Sim.step(1)
	assert_eq(hero.hit_timer, VersusTuning.STUN_HIT_TIMER_MIN, "still stunned")
	hero.hit_timer = VersusTuning.STUN_HIT_TIMER_MIN - 1
	Sim.step(1)
	assert_eq(hero.hit_timer, 0, "the stun is over: no immunity")
	ball.teleport(Vector2i(180, 160))
	ball.xvel = 160
	Sim.step(1)
	assert_eq(knocked.size(), 2)
	hero.hit_timer = 35
	Sim.step(1)
	hero.hit_timer = VersusTuning.HURT_TIMER_TICKS
	Sim.step(1)
	hero.hit_timer = VersusTuning.STUN_HIT_TIMER_MIN - 1
	Sim.step(1)
	assert_eq(hero.hit_timer, VersusTuning.STUN_HIT_TIMER_MIN - 1, "a new hit in between keeps its own immunity")
	ball.teleport(Vector2i(180, 160))
	ball.xvel = 100
	hero.hit_timer = 0
	Sim.step(1)
	assert_eq(knocked.size(), 2, "8 px/tick or slower passes through a body")


func test_the_striker_is_not_knocked_down_by_his_own_shot() -> void:
	_arena()
	var ball: Coconut = _ball(10)
	var striker: PlayerBase = _hero(0, Vector2i(172, 160))
	_box_on(striker, ball)
	Sim.step(1)
	assert_true(Overlap.body(ball, striker), "the ball flies through its striker")
	assert_true(ball.is_fast())
	assert_eq(striker.hit_timer, 0, "the shooter's grace")
	assert_eq(ball.knockdowns, 0)


func test_heads_bounce_the_ball() -> void:
	_arena()
	var ball: Coconut = _ball(3)
	var hero: PlayerBase = _hero(0, Vector2i(168, 160))
	var top: int = 160 - hero.box_h
	ball.teleport(Vector2i(168, top - 1))
	ball.yvel = 48
	Sim.step(1)
	assert_eq(ball.sim_pos.y, top, "on the head")
	assert_eq(ball.yvel, Coconut.HEAD_BOUNCE_MIN_YVEL, "3/4 of 64 is -48: at least -96")
	assert_eq(ball.last_touch_slot, 0, "a header counts as a touch")
	hero.hit_timer = 10
	ball.teleport(Vector2i(168, top - 6))
	ball.yvel = 128
	Sim.step(1)
	assert_eq(ball.yvel, Tuning.shr(-(144 * 3), 2), "a faster ball on an immune head: 3/4 of 144")
	assert_eq(ball.knockdowns, 0)


func test_a_batted_hero_passes_his_speed_on() -> void:
	_arena()
	var ball: Coconut = _ball(10)
	var batter: PlayerBase = _hero(0, Vector2i(40, 160))
	var missile: PlayerBase = _hero(1, Vector2i(160, 160))
	missile.curl = PlayerBase.CURL_BALL
	missile.ball_batter = batter
	missile.xvel = 144
	missile.yvel = -128
	Sim.step(1)
	assert_eq([ball.xvel, ball.yvel], [144, -128], "the missile's velocity passes to the coconut")
	assert_eq(ball.last_touch_slot, 0, "credited to the batter")
	assert_eq(ball.shots, 1)
	ball.teleport(Vector2i(168, 160))
	ball.xvel = 0
	ball.yvel = 0
	Sim.step(1)
	assert_eq(ball.shots, 1, "once per flight")
	missile.curl = PlayerBase.CURL_NONE
	Sim.step(1)
	missile.curl = PlayerBase.CURL_BALL
	ball.teleport(Vector2i(168, 160))
	Sim.step(1)
	assert_eq(ball.shots, 2, "a new flight passes again")


func test_a_ball_in_the_water_drops_in_again_at_its_drop_point() -> void:
	level = make_level(PackedStringArray([
		"....................", "....................", "....................", "....................",
		"....................", "....................", "....................", "....................",
		"....................", "....................", "############~~~#####", "####################",
	]))
	var ball: Coconut = _ball(5)
	var losses: Array = [0]
	ball.lost.connect(func() -> void: losses[0] += 1)
	ball.teleport(Vector2i(216, 150))
	ball.yvel = 16
	for i: int in 20:
		Sim.step(1)
		if not ball.in_play():
			break
	assert_eq(losses[0], 1, "it fell into the ~")
	assert_false(ball.visible)
	assert_eq(ball.reset_ticks_left(), VersusTuning.BALL_RESET_TICKS)
	assert_true(ball.predict_ahead(10).is_empty(), "nothing to predict while it is out")
	Sim.step(VersusTuning.BALL_RESET_TICKS - 1)
	assert_false(ball.in_play())
	Sim.step(1)
	assert_true(ball.in_play())
	assert_eq(ball.sim_pos, Vector2i(88, 160 - Coconut.DROP_IN_PX), "it drops in over its drop point")
	assert_true(ball.visible)
	assert_eq(ball.last_touch_slot, -1)


func test_reset_after_a_goal_and_the_goal_query() -> void:
	_cove()
	var ball: Coconut = _ball(9)
	var goal: ZoneBase = ZoneBase.new()
	place(level, goal, LevelText.cell_to_feet(0, 9), {"rect": "0,7,1,3", "team": 1})
	assert_eq(ball.goal_team(), 0)
	ball.teleport(Vector2i(8, 160))
	assert_eq(ball.goal_team(), 1, "the centre in team 1's goal mouth")
	ball.reset_after(VersusTuning.BALL_RESET_TICKS)
	assert_false(ball.in_play())
	assert_eq(ball.goal_team(), 0, "out of play: no goal")
	Sim.step(VersusTuning.BALL_RESET_TICKS)
	assert_true(ball.in_play())
	assert_eq(ball.sim_pos, Vector2i(152, 160 - Coconut.DROP_IN_PX))
	ball.reset_after(0)
	assert_eq(ball.sim_pos, Vector2i(152, 160 - Coconut.DROP_IN_PX), "0 = at once")
	assert_true(ball.in_play())


func test_the_coconut_sits_out_the_other_modes() -> void:
	_cove()
	var ball: Coconut = _ball(9)
	var referee: FakeReferee = FakeReferee.new()
	referee.mode = Defs.VersusMode.GRUB_STACK
	level.register_party_driver(referee)
	var hero: PlayerBase = _hero(0, Vector2i(110, 160))
	_box_on(hero, ball)
	Sim.step(1)
	assert_false(ball.is_active(), "Coconut Cove in Grub Stack: no ball")
	assert_false(ball.in_play())
	assert_false(ball.visible)
	assert_true(hero.club_box_active, "it takes no box")
	assert_eq([ball.xvel, ball.yvel], [0, 0])
	referee.mode = Defs.VersusMode.CLUBBALL
	Sim.step(1)
	assert_true(ball.in_play() and ball.visible, "Clubball: it plays")
	assert_eq(ball.xvel, Coconut.DRIVE_XVEL, "and takes the box")


func test_the_bots_prediction_is_the_balls_own_physics() -> void:
	_cove()
	var ball: Coconut = _ball(9)
	ball.xvel = 176
	ball.yvel = -240
	var predicted: PackedVector2Array = ball.predict_ahead(120)
	var static_path: PackedVector2Array = Coconut.predict(level.grid, ball.sim_pos, 176, -240, 120)
	assert_eq(predicted, static_path, "the instance and the static prediction agree")
	var actual: PackedVector2Array = PackedVector2Array()
	var touched: Array[int] = [0, 0]
	for i: int in 120:
		Sim.step(1)
		actual.append(Vector2(ball.sim_pos))
		if ball.sim_pos.x <= 40 or ball.sim_pos.x >= 280:
			touched[0] += 1
	assert_eq(actual, predicted, "tick for tick, walls, rims, ledges and floor included")
	assert_true(touched[0] > 0, "the flight met the rims (a real test)")
	ball.teleport(Vector2i(152, 100))
	ball.xvel = 0
	ball.yvel = 0
	assert_eq(ball.predict_landing(), Vector2i(152, 160), "the first floor touch")


# =================================================================================================================
# Crate lanes
# =================================================================================================================

func _lane(rect: String, col: int = 2) -> CrateLane:
	return level.spawn(&"objects/crate_lane", LevelText.cell_to_feet(col, 1), {"rect": rect}) as CrateLane


func test_crate_lane_scene_and_its_drop_columns() -> void:
	level = make_level(PackedStringArray([
		"....................", "....................", "....................", "....................",
		"....................", "....................", "....................", "....---.............",
		"....................", "....................", "#######~~~##########", "####################",
	]))
	var lane: CrateLane = _lane("2,1,16,10")
	assert_not_null(lane, "objects/crate_lane has a scene")
	assert_eq(lane.lane, Rect2i(2, 1, 16, 10))
	assert_eq(lane.state, CrateLane.STATE_IDLE)
	assert_true(lane.opened, "an empty lane is no target")
	assert_false(lane.counts_for_completion)
	assert_false(lane.is_hit_by(Vector2i(40, 160)))
	var columns: PackedInt32Array = lane.drop_columns()
	assert_eq(columns.size(), 13, "16 columns but the 3 over the ~")
	assert_false(columns.has(8))
	assert_eq(lane.landing_y(5), 112, "the one-way bridge of row 7 catches it")
	assert_eq(lane.landing_y(12), 160)
	assert_eq(lane.landing_y(8), -1, "a ~ under the drop: never chosen")
	assert_false(lane.drop(8, "food:1"), "nothing can land there")


func test_a_crate_shows_its_shadow_then_falls_and_lands() -> void:
	_arena()
	var lane: CrateLane = _lane("2,1,16,10")
	assert_true(lane.drop(8, "food:3"))
	assert_true(lane.shows_shadow())
	assert_eq(lane.land_point, Vector2i(136, 160), "the shadow on the landing point")
	assert_eq(lane.drop_point, Vector2i(136, 32), "released from the lane's top row")
	assert_eq(lane.ticks_to_drop(), VersusTuning.CRATE_SHADOW_TICKS)
	assert_false(lane.drop(10, "food:1"), "one crate per lane")
	Sim.step(VersusTuning.CRATE_SHADOW_TICKS - 1)
	assert_eq(lane.state, CrateLane.STATE_INCOMING)
	assert_true(lane.opened, "nothing to hit in the air")
	Sim.step(1)
	assert_eq(lane.state, CrateLane.STATE_FALLING, "dropped 22 ticks after the shadow showed")
	assert_eq(lane.crates_dropped, 1)
	Sim.step(17)
	assert_eq(lane.state, CrateLane.STATE_FALLING)
	Sim.step(1)
	assert_eq(lane.state, CrateLane.STATE_LANDED, "128 px in 18 ticks (gravity 16, at most 12 px a tick)")
	assert_eq(lane.sim_pos, Vector2i(136, 160))
	assert_eq(lane.cell, Vector2i(8, 9))
	assert_true(lane.has_crate())
	assert_false(lane.opened)
	assert_true(lane.is_hit_by(Vector2i(140, 160)), "a club box near it hits it")


func test_one_hit_opens_the_crate_and_specials_are_temporary() -> void:
	_arena()
	var lane: CrateLane = _lane("2,1,16,10")
	assert_true(lane.drop(8, "food:3,weapon:axe,feast_piece:1,skull", 0))
	Sim.step(18)
	assert_true(lane.has_crate())
	var hero: PlayerBase = _hero(0, Vector2i(110, 160))
	assert_true(lane.take_hit(Tuning.WEAPON_POWER[Defs.Weapon.CLUB], hero))
	assert_eq(lane.crates_opened, 1)
	assert_eq(lane.state, CrateLane.STATE_IDLE)
	assert_true(lane.opened)
	var found: Dictionary = {}
	for entity: SimEntity in level.get_kind(Defs.Kind.COLLECTIBLE):
		var item: CollectibleBase = entity as CollectibleBase
		found[String(item.item_id)] = item
		assert_true(item.dropped, "%s flies out as a dropped item" % item.item_id)
	assert_eq(found.size(), 4, "food, a special, a cutlery piece, the skull: %s" % [found.keys()])
	var weapon: WeaponPickup = found.get("items/weapon") as WeaponPickup
	assert_not_null(weapon)
	assert_eq(weapon.weapon, Defs.Weapon.AXE)
	assert_true(weapon.temp, "a crate special is temporary (onto the belt)")
	assert_eq((found["items/food"] as CollectibleBase).index, 3)
	assert_eq((found["items/feast_piece"] as CollectibleBase).index, 1)
	assert_true(found.has("items/skull"))
	lane.refill()
	assert_true(lane.opened, "a refill (spot refills, the Feast Rush) brings no crate")


func test_the_scheduler_drops_one_crate_per_period_on_a_free_lane() -> void:
	_arena()
	var a: CrateLane = _lane("2,1,8,10", 2)
	var b: CrateLane = _lane("10,1,8,10", 10)
	var period: int = VersusTuning.CRATE_PERIOD_TICKS
	var shadow: int = VersusTuning.CRATE_SHADOW_TICKS
	Sim.step(period - shadow - 1)
	assert_eq([a.state, b.state], [CrateLane.STATE_IDLE, CrateLane.STATE_IDLE])
	Sim.step(1)
	var first: CrateLane = a if a.state == CrateLane.STATE_INCOMING else b
	var other: CrateLane = b if first == a else a
	assert_eq(first.state, CrateLane.STATE_INCOMING, "a shadow 22 ticks before the first period")
	assert_eq(other.state, CrateLane.STATE_IDLE, "one crate per period")
	assert_false(first.contents.is_empty())
	Sim.step(shadow)
	assert_eq(first.state, CrateLane.STATE_FALLING, "dropped on the period")
	Sim.step(40)
	assert_true(first.has_crate())
	Sim.step(period - shadow - 40 - 1)
	assert_eq(other.state, CrateLane.STATE_IDLE)
	Sim.step(1)
	assert_eq(other.state, CrateLane.STATE_INCOMING, "the busy lane (its crate still lies there) is skipped")
	assert_true(first.has_crate())


func test_crate_rules_follow_the_match() -> void:
	_arena()
	_lane("2,1,16,10")
	assert_eq(CrateLane.crate_period(level), VersusTuning.CRATE_PERIOD_TICKS, "no match: every 20 s")
	assert_true(CrateLane.default_contents().contains("weapon:"))
	var rules: VersusMatch = VersusMatch.new()
	Game.versus_match = rules
	rules.preset = VersusMatch.Preset.CLASSIC
	assert_eq(CrateLane.crate_period(level), 0, "Classic: no crates")
	rules.preset = VersusMatch.Preset.FEAST
	assert_eq(CrateLane.crate_period(level), VersusTuning.CRATE_PERIOD_TICKS)
	rules.preset = VersusMatch.Preset.MAYHEM
	assert_eq(CrateLane.crate_period(level), VersusTuning.MAYHEM_CRATE_PERIOD_TICKS)
	rules.preset = VersusMatch.Preset.FEAST
	rules.crates = false
	assert_eq(CrateLane.crate_period(level), 0, "crates off")
	rules.crates = true
	rules.variants = PackedStringArray(["axe_rain"])
	assert_eq(CrateLane.crate_period(level), VersusTuning.MAYHEM_CRATE_PERIOD_TICKS, "Axe Rain: every 8 s ...")
	assert_eq(CrateLane.default_contents(), CrateLane.AXE_RAIN_CONTENTS, "... only axes")
	rules.variants = PackedStringArray()
	rules.weapons = &"club"
	for i: int in 20:
		var text: String = CrateLane.default_contents()
		assert_false(text.contains("weapon:"), "club only: no specials (%s)" % text)
		assert_true(text.contains("food:") and text.contains("feast_piece:"))
	var referee: RulesReferee = RulesReferee.new()
	referee.mode = Defs.VersusMode.CLUBBALL
	level.register_party_driver(referee)
	assert_eq(CrateLane.crate_period(level), 0, "Clubball: club only, no crates")
	referee.mode = Defs.VersusMode.GRUB_STACK
	referee.rules = RoundRules.new()
	referee.rules.crate_period = 194
	assert_eq(CrateLane.crate_period(level), 194, "the referee's round rules win over the match (Mayhem's Axe Rain)")


func test_the_referee_clock_contents_hook_and_manual_drops() -> void:
	_arena()
	var referee: FakeReferee = FakeReferee.new()
	referee.contents_answer = "treasure:8"
	level.register_party_driver(referee)
	var lane: CrateLane = _lane("2,1,16,10")
	Sim.step(VersusTuning.CRATE_PERIOD_TICKS)
	assert_eq(lane.state, CrateLane.STATE_IDLE, "the round clock stands still (intro): nothing")
	referee.round_ticks = VersusTuning.CRATE_PERIOD_TICKS - VersusTuning.CRATE_SHADOW_TICKS
	Sim.step(1)
	assert_eq(lane.state, CrateLane.STATE_INCOMING, "on the referee's round clock")
	assert_eq(lane.contents, "treasure:8", "the referee's contents")
	Sim.step(VersusTuning.CRATE_SHADOW_TICKS + 20)
	assert_true(lane.has_crate())
	assert_true(lane.take_hit(25, null))
	CrateLane.set_auto(level, false)
	referee.round_ticks = VersusTuning.CRATE_PERIOD_TICKS * 2 - VersusTuning.CRATE_SHADOW_TICKS
	Sim.step(1)
	assert_eq(lane.state, CrateLane.STATE_IDLE, "auto off: the referee drops crates itself")
	assert_true(lane.drop(4, "food:0", 0))
	assert_eq(lane.state, CrateLane.STATE_FALLING, "lead 0: released at once")


# =================================================================================================================
# Chomper in the arena (Mesa Rodeo)
# =================================================================================================================

## A flat arena (meta kind = arena) with Chomper's pen at column 14 and Chomper placed at column 5.
func _rodeo() -> Mount:
	level = make_flat_level(20, 12, 10)
	level.meta = {"kind": "arena"}
	level.spawn(&"objects/rex_pen", LevelText.cell_to_feet(14, 9), {"name": "pen1"})
	return level.spawn(&"objects/mount", LevelText.cell_to_feet(5, 9), {"pen": "pen1"}) as Mount


func _drop_on_mount(hero: PlayerBase, mount: Mount) -> void:
	hero.teleport(Vector2i(mount.sim_pos.x, mount.sim_pos.y - mount.box_h + 4))
	hero.yvel = 32
	hero.grounded = false


## Chomper out of his pen with `hero` in the saddle.
func _ridden_rodeo(hero_slot: int = 0) -> Mount:
	var mount: Mount = _rodeo()
	mount.release()
	var rider: PlayerBase = _hero(hero_slot, Vector2i(20, 160))
	_drop_on_mount(rider, mount)
	Sim.step(1)
	assert_eq(mount.driver, rider, "seated")
	return mount


func test_outside_an_arena_chomper_has_no_pen_timer() -> void:
	level = make_flat_level(20, 12, 10)
	var mount: Mount = level.spawn(&"objects/mount", LevelText.cell_to_feet(5, 9)) as Mount
	assert_false(mount.arena)
	assert_false(mount.is_penned())
	assert_eq(mount.ticks_to_release(), -1)


func test_chomper_waits_in_his_pen_and_leaves_it_every_30_s() -> void:
	var mount: Mount = _rodeo()
	var pen_feet: Vector2i = LevelText.cell_to_feet(14, 9)
	assert_true(mount.arena)
	assert_true(mount.is_penned(), "a round starts with Chomper penned")
	assert_eq(mount.sim_pos, pen_feet, "in his pen")
	assert_eq(mount.ticks_to_release(), VersusTuning.RODEO_CHOMPER_PERIOD_TICKS)
	var hero: PlayerBase = _hero(0, Vector2i(20, 160))
	_drop_on_mount(hero, mount)
	Sim.step(1)
	assert_false(hero.is_mounted(), "nobody sits on a penned Chomper")
	hero.teleport(Vector2i(20, 160))
	hero.yvel = 0
	var period: int = VersusTuning.RODEO_CHOMPER_PERIOD_TICKS
	var rumble: int = VersusTuning.RODEO_RUMBLE_TICKS
	Sim.step(period - rumble - 2)
	assert_false(mount.is_rumbling())
	Sim.step(1)
	assert_true(mount.is_rumbling(), "the rumble, 22 ticks ahead")
	Sim.step(rumble - 1)
	assert_true(mount.is_penned() and mount.is_rumbling())
	Sim.step(1)
	assert_false(mount.is_penned(), "out on the 728th tick")
	assert_false(mount.is_rumbling())
	assert_eq(mount.ticks_to_release(), 0)
	_drop_on_mount(hero, mount)
	Sim.step(1)
	assert_true(hero.is_mounted(), "now he can be ridden")


func test_the_pen_follows_the_referees_round_clock() -> void:
	var mount: Mount = _rodeo()
	var referee: FakeReferee = FakeReferee.new()
	level.register_party_driver(referee)
	var period: int = VersusTuning.RODEO_CHOMPER_PERIOD_TICKS
	Sim.step(period + 5)
	assert_true(mount.is_penned(), "the round clock stands still (intro)")
	referee.round_ticks = period - VersusTuning.RODEO_RUMBLE_TICKS
	Sim.step(1)
	assert_true(mount.is_rumbling())
	assert_eq(mount.ticks_to_release(), VersusTuning.RODEO_RUMBLE_TICKS)
	referee.round_ticks = period
	Sim.step(1)
	assert_false(mount.is_penned())


func test_the_riders_bite_bites_rivals() -> void:
	var mount: Mount = _ridden_rodeo()
	var rival: PlayerBase = _hero(1, Vector2i(mount.sim_pos.x + 30, 160))
	var hearts: int = rival.run.hearts
	run_inputs([[1, "F"], [8, ""]])
	assert_eq(mount.bites_on_rivals, 1, "bitten")
	assert_true(rival.hit_timer > 0, "the versus knock-back")
	assert_eq(rival.run.hearts, hearts, "no energy (the currency is the referee's)")
	assert_false(mount.driver == null, "the rider stays seated")


func test_a_grub_stack_bite_spills_3_and_teammates_are_spared() -> void:
	var mount: Mount = _ridden_rodeo()
	var referee: FakeReferee = FakeReferee.new()
	level.register_party_driver(referee)
	var rival: PlayerBase = _hero(1, Vector2i(mount.sim_pos.x + 30, 160))
	run_inputs([[1, "F"], [8, ""]])
	assert_eq(referee.spills, [[1, VersusTuning.RODEO_BITE_SPILL]], "Grub Stack: the bite spills 3")
	rival.hit_timer = 0
	referee.teams = PackedInt32Array([1, 1, -1, -1])
	run_inputs([[1, "F"], [8, ""]])
	assert_eq(mount.bites_on_rivals, 1, "a teammate is never bitten")


func test_the_referee_may_rule_the_bite() -> void:
	var mount: Mount = _ridden_rodeo()
	var referee: BiteReferee = BiteReferee.new()
	level.register_party_driver(referee)
	var rival: PlayerBase = _hero(1, Vector2i(mount.sim_pos.x + 30, 160))
	run_inputs([[1, "F"], [8, ""]])
	assert_eq(referee.bites, [[0, 1]], "bite_hit(driver, victim, mount)")
	assert_eq(rival.hit_timer, 0, "nothing else is applied")
	assert_eq(mount.bites_on_rivals, 1)


func test_a_stomp_on_the_rider_unseats_him() -> void:
	var mount: Mount = _ridden_rodeo()
	var rider: PlayerBase = mount.driver
	var stomper: PlayerBase = _hero(1, Vector2i(250, 160))
	_drop_on_mount(stomper, mount)
	stomper.teleport(Vector2i(rider.sim_pos.x, rider.sim_pos.y - rider.box_h + 4))
	Sim.step(1)
	assert_false(rider.is_mounted(), "unseated")
	assert_eq(mount.stomp_unseats, 1)
	assert_eq([rider.xvel, rider.yvel], [Mount.RIDER_HIT_XVEL, Mount.RIDER_HIT_YVEL], "thrown off, away")
	assert_eq(rider.hit_timer, 0, "no stun from the unseat itself")
	assert_eq(stomper.yvel, Tuning.BOUNCE_YVEL, "no referee: the stomper bounces here")
	assert_true(mount.present and not mount.is_penned(), "Chomper stays out for the next rider")
	assert_true(mount.is_remount_locked(rider))


func test_an_immune_rider_is_a_free_springboard_and_the_referee_bounces() -> void:
	var mount: Mount = _ridden_rodeo()
	var rider: PlayerBase = mount.driver
	var referee: FakeReferee = FakeReferee.new()
	level.register_party_driver(referee)
	var stomper: PlayerBase = _hero(1, Vector2i(250, 160))
	rider.hit_timer = 10
	stomper.teleport(Vector2i(rider.sim_pos.x, rider.sim_pos.y - rider.box_h + 4))
	stomper.yvel = 32
	Sim.step(1)
	assert_true(rider.is_mounted(), "immune: stays seated")
	rider.hit_timer = 0
	stomper.teleport(Vector2i(rider.sim_pos.x, rider.sim_pos.y - rider.box_h + 4))
	stomper.yvel = 32
	Sim.step(1)
	assert_false(rider.is_mounted())
	assert_eq(stomper.yvel, 32, "with a referee the stomp itself is the referee's")


func test_a_hit_rider_sends_chomper_home_penned_until_the_next_release() -> void:
	var mount: Mount = _ridden_rodeo()
	var rider: PlayerBase = mount.driver
	var source: SimEntity = SimEntity.new()
	place(level, source, Vector2i(10, 120))
	mount.rider_hit(source)
	assert_false(rider.is_mounted())
	assert_false(mount.present)
	Sim.step(Mount.BOLT_TICKS)
	assert_true(mount.present)
	assert_true(mount.is_penned(), "home again: penned")
	assert_eq(mount.sim_pos, LevelText.cell_to_feet(14, 9))
	var left: int = mount.ticks_to_release()
	assert_true(left > 0 and left <= VersusTuning.RODEO_CHOMPER_PERIOD_TICKS)
	Sim.step(left)
	assert_false(mount.is_penned(), "out again on the next multiple of 728")


# =================================================================================================================
# The test arena through the real loader
# =================================================================================================================

func test_the_versus_test_level_loads_with_its_spawns_and_pots() -> void:
	Sim.manual = true
	Game.begin_level(&"test_objects_versus")
	var loaded: Level = (load(LEVEL_SCENE) as PackedScene).instantiate() as Level
	loaded.setup_from_text(&"test_objects_versus", FileAccess.get_file_as_string(VERSUS_LEVEL))
	add_node(loaded)
	loaded.set_view_size(BASE_VIEW)
	level = loaded
	var spawns: Array[Vector2i] = SpawnPoint.spawn_list(loaded)
	assert_eq(spawns.size(), 4, "'@' and spawn points 2..4")
	for slot: int in range(1, 4):
		assert_eq(loaded.get_start_pos_for(slot), spawns[slot], "the loader's start of slot %d is its spawn" % slot)
	var pots: Array[Cookpot] = Cookpot.pots_of(loaded)
	assert_eq(pots.size(), 2, "two cookpots on a 4-player arena")
	for pot: Cookpot in pots:
		var under: int = loaded.grid.floor_at(pot.sim_pos.x >> 4, pot.sim_pos.y >> 4)
		assert_true(TileGrid.is_ground(under), "the pot at %s stands on a floor" % pot.sim_pos)
	var ball: Coconut = Coconut.find(loaded)
	assert_not_null(ball, "the coconut")
	assert_true(TileGrid.is_ground(loaded.grid.floor_at(ball.sim_pos.x >> 4, ball.sim_pos.y >> 4)), "on the floor")
	var lanes: Array[CrateLane] = CrateLane.lanes_of(loaded)
	assert_eq(lanes.size(), 1, "the crate lane")
	assert_eq(lanes[0].lane, Rect2i(2, 1, 16, 11))
	assert_eq(lanes[0].drop_columns().size(), 16, "every column has a floor (a tier or the ground)")
	assert_eq(lanes[0].landing_y(4), 5 * Tuning.TILE, "a crate over the tier lands on it")
	Sim.step(3)
	assert_eq(ball.sim_pos, ball.drop_point, "the ball rests")


func test_the_versus_test_level_is_valid() -> void:
	var validator: LevelValidator = LevelValidator.new()
	assert_true(validator.add_file(VERSUS_LEVEL))
	validator.run()
	var lines: PackedStringArray = PackedStringArray()
	for problem: Dictionary in validator.problems:
		lines.append(LevelValidator.format_problem(problem))
	assert_eq(validator.error_count(), 0, "\n".join(lines))
