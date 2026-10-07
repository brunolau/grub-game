extends TestCase
## Versus objects of objects-B (docs/expansion/PLAN.md P2.7, pulled into phase 1 for the Totem Ring slice):
## `objects/cookpot` (Grub Stack banking one unit per 4 crouched ticks, the Feast Rush lid, 2v2 team pots, the
## "banking" query of the double stomp steal; DESIGN.md E.3, GAMEPLAY.md 13.10.3) and `objects/spawn_point` (the
## arena's spawns, their rotation per round and the respawn at the free spawn farthest from the rivals; PHYSICS.md
## C.14, LEVEL_DESIGN.md 15.8), plus levels/test_objects_versus.lvl through the real loader.

const LEVEL_SCENE: String = "res://scenes/world/level.tscn"
const VERSUS_LEVEL: String = "res://levels/test_objects_versus.lvl"
const BASE_VIEW: Vector2i = Vector2i(640, 360)


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
	Game.begin_level(&"test_objects_versus")
	Sim.start(1)


func after_each() -> void:
	Sim.stop()
	Sim.manual = _was_manual
	GameInput.clear_scripted()
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


func test_the_versus_test_level_is_valid() -> void:
	var validator: LevelValidator = LevelValidator.new()
	assert_true(validator.add_file(VERSUS_LEVEL))
	validator.run()
	var lines: PackedStringArray = PackedStringArray()
	for problem: Dictionary in validator.problems:
		lines.append(LevelValidator.format_problem(problem))
	assert_eq(validator.error_count(), 0, "\n".join(lines))
