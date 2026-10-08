extends TestCase
## The bot brains of the four launch modes and the boss interface (PLAN.md P2.5, DESIGN.md E.7 / B.6, GAMEPLAY.md
## 13.10.10 / 13.6) on world-B's flat test arena through GameInput's BOT slots: Grub Stack (food, spots, banking,
## attacks, the G1 slice), the combat micro-rules per level (Rookie / Hunter / Chief: deflects, stomp chains),
## Last Caveman Standing (fighting, bones, the Grudge Pterodactyl), Hot Rock (chase and flee), Clubball (the ball
## predictor and the shots), and the Chieftain brain's orders on a stand-in hero body. The quick tests of the bots; the
## long versus checks of PLAN 8 V4.b are tests/test_versus_bots.gd (slow module).
##
## The modes whose referee rules come in PLAN P2.4 (world-B) are read through BotSenses.test_referee here (a stub
## that answers the reading API of wf8_core-B_to_world-B.txt), so the brains are proven before those rules land.

const LEVEL_SCENE: String = "res://scenes/world/level.tscn"
const FLAT_ARENA: String = "res://levels/test_world_arena_flat.lvl"
const RING_ARENA: String = "res://levels/test_world_arena_ring.lvl"
## A walled 20 x 12 pitch (stand-in Coconut Cove): flat floor, walls on both sides, goal mouths 3 rows high.
const PITCH: String = """[meta]
format = 2
id = test_core_bots_pitch
kind = arena
players = 4
modes = clubball
biome = coast
[legend]
B = objects/spawn_point index=2
[tiles]
|..................|
|..................|
|..................|
|..................|
|..................|
|..................|
|..................|
|..................|
|..................|
|.@..............B.|
####################
####################
[entities]
"""
const PITCH_ID: StringName = &"test_core_bots_pitch"
## The pitch with Coconut Cove's lob bridge (row 4) and a low ledge exactly 3 rows under it (row 7).
const BRIDGE_PITCH: String = """[meta]
format = 2
id = test_core_bots_bridge
kind = arena
players = 4
modes = clubball
biome = coast
[legend]
B = objects/spawn_point index=2
[tiles]
|..................|
|..................|
|..................|
|..................|
|.....--------.....|
|..................|
|..................|
|.....--....--.....|
|..................|
|.@..............B.|
####################
####################
[entities]
"""
const BRIDGE_PITCH_ID: StringName = &"test_core_bots_bridge"

var _level: Level = null
var _bots: Array[HeroBot] = []


func before_each() -> void:
	Game.new_game(Defs.Difficulty.BEGINNER)
	NavGraph.clear_cache()
	BotSenses.test_referee = null
	_level = null
	_bots.clear()


func after_each() -> void:
	for bot: HeroBot in _bots:
		bot.uninstall()
	_bots.clear()
	BotSenses.test_referee = null
	GameInput.clear_scripted()
	GameInput.reset_slots()
	NavGraph.clear_cache()
	BotBrain.clear_cache()
	Sim.stop()
	_level = null
	Game.new_game(Defs.Difficulty.BEGINNER)


# =================================================================================================================
# A referee stand-in for the P2.4 reading API (Hot Rock, Clubball, LCS out-of-round, dangers)
# =================================================================================================================

class StubReferee:
	extends RefCounted

	var mode: int = Defs.VersusMode.HOT_ROCK
	var phase: int = 1
	var holder: int = -1
	var immune: Dictionary = {}
	var hurry: bool = false
	var ball_entity: SimEntity = null
	var goals: Dictionary = {}
	var teams: Dictionary = {}
	var dangers: Array[Rect2i] = []
	var out: Dictionary = {}
	var grudge: Dictionary = {}
	var ready: bool = true

	func stack_of(_slot: int) -> int:
		return 0

	func team_of(slot: int) -> int:
		return int(teams.get(slot, -1))

	func ember_holder() -> int:
		return holder

	func ember_pass_immune(slot: int) -> int:
		return int(immune.get(slot, 0))

	func ember_hurry() -> bool:
		return hurry

	func ball() -> SimEntity:
		return ball_entity if ball_entity != null and is_instance_valid(ball_entity) else null

	func goal_rect(team: int) -> Rect2i:
		return goals.get(team, Rect2i())

	func danger_rects(_lookahead: int) -> Array:
		return dangers

	func is_out(slot: int) -> bool:
		return bool(out.get(slot, false))

	func grudge_pos(slot: int) -> Vector2i:
		return grudge.get(slot, Vector2i(-1, -1))

	func grudge_ready(_slot: int) -> bool:
		return ready


## A coconut stand-in: GAMEPLAY 13.10.6 flight by BallPredictor.step, struck by any hero's live front club box (drive
## +/-144, -128; lob +/-32, -240; grounder +/-96 along the floor; once per swing).
class StubBall:
	extends SimEntity

	var hits: int = 0
	var last_dir: int = 0
	var _state: BallPredictor.State = BallPredictor.State.new()
	var _struck_by: Dictionary = {}

	func _init() -> void:
		box_w = 16
		box_h = 16
		box_xo = 8

	func _sim_phases() -> PackedInt32Array:
		return PackedInt32Array([Defs.Phase.ITEMS, Defs.Phase.CONTACT_ITEMS])

	func _can_doze() -> bool:
		return false

	func _sim_tick(phase: int) -> void:
		var level: LevelBase = Game.level
		if level == null:
			return
		if phase == Defs.Phase.ITEMS:
			_state.pos = sim_pos
			_state.xvel = xvel
			_state.yvel = yvel
			BallPredictor.step(level.grid, _state)
			sim_pos = _state.pos
			xvel = _state.xvel
			yvel = _state.yvel
			return
		for hero: PlayerBase in level.heroes:
			var id: int = hero.get_instance_id()
			if not hero.club_box_active:
				_struck_by.erase(id)
				continue
			if _struck_by.has(id) or not hero.club_box.intersects(get_box()):
				continue
			_struck_by[id] = true
			hits += 1
			last_dir = hero.facing
			if (hero.input_flags & Defs.IN_UP) != 0:
				xvel = 32 * hero.facing
				yvel = -240
			elif (hero.input_flags & Defs.IN_DOWN) != 0:
				xvel = 96 * hero.facing
				yvel = 0
			else:
				xvel = 144 * hero.facing
				yvel = -128
			_state.grounded = false


## A rival's thrown special stand-in (HERO_PROJECTILE kind) for the deflect rule.
class StubProjectile:
	extends SimEntity

	var owner_slot: int = 0
	var spent: bool = false

	func _init() -> void:
		box_w = 16
		box_h = 8
		box_xo = 8

	func get_kind() -> int:
		return Defs.Kind.HERO_PROJECTILE

	func _sim_phases() -> PackedInt32Array:
		return PackedInt32Array()


# =================================================================================================================
# Grub Stack (moved from the G1 test_versus_bots: the quick goal checks)
# =================================================================================================================

func test_bot_picks_up_food_lying_in_the_arena() -> void:
	if not _start(2, {1: Defs.BotLevel.ROOKIE}):
		return
	var referee: Object = BotSenses.referee(_level)
	var hero: PlayerBase = _level.get_hero(1)
	# A big food item on the far floor: the only thing worth having.
	var item: Node = _level.spawn(&"items/food", Vector2i(hero.sim_pos.x + (120 if hero.sim_pos.x < 160 else -120),
			160), {"index": 20, "points": 800})
	assert_not_null(item)
	var got: bool = _run_until(300, func() -> bool: return BotSenses.stack_of(_level, 1) > 0)
	assert_true(got, "the bot fetched the food (stack %d, hero at %s)" % [BotSenses.stack_of(_level, 1), hero.sim_pos])
	var brain: GrubStackBrain = _bots[0].brain as GrubStackBrain
	assert_true(brain.decisions[GrubStackBrain.Goal.FOOD] >= 1)
	if referee != null:
		assert_eq(int(referee.call(&"stack_of", 1)), 2, "big food is worth 2")


func test_bot_strikes_the_spots_open() -> void:
	if not _start(2, {1: Defs.BotLevel.HUNTER}):
		return
	var hits: Array[int] = [0]
	var counter: Callable = func(_spot: Node, _used_up: bool) -> void: hits[0] += 1
	Events.hittable_hit.connect(counter)
	var opened: bool = _run_until(600, func() -> bool: return hits[0] >= 2)
	Events.hittable_hit.disconnect(counter)
	assert_true(opened, "the bot struck spots (%d hits)" % hits[0])
	var brain: GrubStackBrain = _bots[0].brain as GrubStackBrain
	assert_true(brain.decisions[GrubStackBrain.Goal.SPOT] >= 1)
	assert_true(brain.strikes >= 2)


func test_bot_banks_a_tall_stack_in_the_cookpot() -> void:
	if not _start(2, {1: Defs.BotLevel.ROOKIE}):
		return
	var referee: Object = BotSenses.referee(_level)
	if referee == null or not referee.has_method(&"add_food"):
		assert_true(true, "no referee yet")
		return
	referee.call(&"add_food", _level.get_hero(1), 9)
	var banked: bool = _run_until(500, func() -> bool: return int(referee.call(&"banked_of", 1)) >= 3)
	assert_true(banked, "the bot banked (stack %d, banked %d)" % [
		int(referee.call(&"stack_of", 1)), int(referee.call(&"banked_of", 1)),
	])
	assert_eq(int(referee.call(&"stack_of", 1)) + int(referee.call(&"banked_of", 1)), 9, "nothing lost")
	var brain: GrubStackBrain = _bots[0].brain as GrubStackBrain
	assert_true(brain.decisions[GrubStackBrain.Goal.BANK] >= 1)


func test_heavy_bots_use_their_weight_class() -> void:
	if not _start(2, {1: Defs.BotLevel.HUNTER}):
		return
	var referee: Object = BotSenses.referee(_level)
	if referee == null or not referee.has_method(&"add_food"):
		assert_true(true, "no referee yet")
		return
	referee.call(&"add_food", _level.get_hero(1), 21)
	_run_until(3, func() -> bool: return false)
	assert_eq(_bots[0].nav.weight_class, NavGraph.WEIGHT_HEAVIER, "21 units: the 20+ class")
	assert_eq(GrubStackBrain.weight_class(9), NavGraph.WEIGHT_LIGHT)
	assert_eq(GrubStackBrain.weight_class(10), NavGraph.WEIGHT_HEAVY)
	assert_eq(GrubStackBrain.weight_class(20), NavGraph.WEIGHT_HEAVIER)


func test_hunter_attacks_a_stacked_rival() -> void:
	if not _start(2, {1: Defs.BotLevel.HUNTER}):
		return
	var referee: Object = BotSenses.referee(_level)
	if referee == null or not referee.has_method(&"add_food"):
		assert_true(true, "no referee yet")
		return
	# P1 (a "human" who stands still) carries 12 units; nothing else is worth having (the spots are taken out).
	for spot: HittableBase in BotSenses.spots(_level):
		spot.open()
	referee.call(&"add_food", _level.get_hero(0), 12)
	GameInput.set_scripted_slot(0, func(_tick: int) -> int: return 0)
	var hit: bool = _run_until(400, func() -> bool: return int(referee.call(&"stack_of", 0)) < 12)
	assert_true(hit, "the Hunter knocked food off the leader (stack %d)" % int(referee.call(&"stack_of", 0)))
	var brain: GrubStackBrain = _bots[0].brain as GrubStackBrain
	assert_true(brain.decisions[GrubStackBrain.Goal.ATTACK] >= 1)


func test_two_humans_and_two_rookies_play_a_round() -> void:
	var trace: PackedInt32Array = _slice_round(21)
	if trace.is_empty():
		return
	var again: PackedInt32Array = _slice_round(21)
	assert_eq(again, trace, "the round replays tick for tick")


func test_bots_flee_a_telegraphed_danger() -> void:
	if not _start(2, {1: Defs.BotLevel.ROOKIE}):
		return
	var stub: StubReferee = StubReferee.new()
	stub.mode = Defs.VersusMode.GRUB_STACK
	BotSenses.test_referee = stub
	_run_until(4, func() -> bool: return false)
	var hero: PlayerBase = _level.get_hero(1)
	# A danger box over the floor around him (a stampede lane, say).
	stub.dangers = [Rect2i(hero.sim_pos.x - 40, 150, 80, 10)]
	var away: bool = _run_until(200, func() -> bool:
		return absi(hero.sim_pos.x - (stub.dangers[0] as Rect2i).get_center().x) > 40 + 16 + 12 or hero.sim_pos.y < 150)
	assert_true(away, "the bot left the danger (at %s)" % hero.sim_pos)
	assert_true((_bots[0].brain as BotBrain).escapes >= 1)


# =================================================================================================================
# Combat micro-rules per level
# =================================================================================================================

func test_deflect_rates_follow_the_level() -> void:
	if not _start(2, {}):
		return
	var counts: PackedInt32Array = PackedInt32Array()
	# The thrower far away on the left, the bot standing on the right; the special comes from the right.
	_level.get_hero(0).respawn_at(Vector2i(40, 160))
	_level.get_hero(1).respawn_at(Vector2i(240, 160))
	# Past the spawn shield (a bot keeps it: no strike while it is up, BotBrain.may_strike).
	Sim.step(VersusTuning.SPAWN_SHIELD_TICKS + 2)
	for bot_level: int in [Defs.BotLevel.ROOKIE, Defs.BotLevel.HUNTER, Defs.BotLevel.CHIEF]:
		var bot: HeroBot = HeroBot.new(1, bot_level, 40 + bot_level, Defs.VersusMode.LAST_CAVEMAN)
		bot.bind(_level)
		bot._record(Sim.tick)
		var hero: PlayerBase = _level.get_hero(1)
		var front: Rect2i = BotBrain.front_box(hero.sim_pos, 1, BotBrain.STRIKE_FORWARD)
		var deflected: int = 0
		for i: int in 40:
			var projectile: StubProjectile = StubProjectile.new()
			projectile.owner_slot = 0
			# Its box will be on the club's front box in STRIKE_LEAD_TICKS ticks at -96 v16.
			projectile.spawn_setup(Vector2i(front.get_center().x + 30, front.get_center().y + 4), {})
			projectile.xvel = -96
			_level.add_child(projectile)
			# Seen long enough ago (its reaction), coming straight at him: decide.
			bot.brain._projectile_seen[projectile.get_instance_id()] = Sim.tick - 20
			bot.brain.cancel_actions()
			var flags: int = bot.brain.combat(hero, _level)
			if flags >= 0 and (flags & Defs.IN_FIRE) != 0:
				deflected += 1
			bot.brain.cancel_actions()
			projectile.free()
		counts.append(deflected)
	assert_eq(counts[0], 0, "the Rookie never deflects")
	assert_true(counts[1] >= 3 and counts[1] <= 18, "the Hunter deflects about a quarter (%d / 40)" % counts[1])
	assert_true(counts[2] >= 12 and counts[2] <= 30, "the Chief about half (%d / 40)" % counts[2])
	assert_true(counts[2] > counts[1], "the Chief deflects more than the Hunter")


func test_reaction_by_level() -> void:
	assert_eq(HeroBot.new(0, Defs.BotLevel.ROOKIE).reaction, 10)
	assert_eq(HeroBot.new(0, Defs.BotLevel.HUNTER).reaction, 6)
	assert_eq(HeroBot.new(0, Defs.BotLevel.CHIEF).reaction, 3)
	assert_true(HeroBot.make_brain(Defs.VersusMode.GRUB_STACK) is GrubStackBrain)
	assert_true(HeroBot.make_brain(Defs.VersusMode.LAST_CAVEMAN) is LastCavemanBrain)
	assert_true(HeroBot.make_brain(Defs.VersusMode.HOT_ROCK) is HotRockBrain)
	assert_true(HeroBot.make_brain(Defs.VersusMode.CLUBBALL) is ClubballBrain)
	assert_true(HeroBot.make_brain(Defs.VersusMode.KING_OF_THE_FEAST) is GrubStackBrain, "second wave: Grub Stack")


func test_chief_steers_onto_heads_while_falling() -> void:
	if not _start(2, {}):
		return
	var chief: HeroBot = HeroBot.new(1, Defs.BotLevel.CHIEF, 5, Defs.VersusMode.LAST_CAVEMAN)
	var rookie: HeroBot = HeroBot.new(1, Defs.BotLevel.ROOKIE, 5, Defs.VersusMode.LAST_CAVEMAN)
	for bot: HeroBot in [chief, rookie]:
		bot.bind(_level)
	var me: PlayerBase = _level.get_hero(1)
	var rival: PlayerBase = _level.get_hero(0)
	# He falls from above, the rival stands 20 px to his right below him.
	me.respawn_at(Vector2i(150, 90))
	me.grounded = false
	me.yvel = 32
	rival.respawn_at(Vector2i(170, 160))
	for bot: HeroBot in [chief, rookie]:
		for i: int in 4:
			bot._record(Sim.tick)
	var flags: int = chief.brain.air_steer(me, _level)
	assert_true(flags >= 0 and (flags & Defs.IN_RIGHT) != 0, "the Chief steers onto the head (flags %d)" % flags)
	assert_true((flags & Defs.IN_UP) != 0, "with UP held: the big bounce of a chain")
	assert_eq(rookie.brain.air_steer(me, _level), -1, "the Rookie does not")


# =================================================================================================================
# Last Caveman Standing
# =================================================================================================================

func test_lcs_hunters_fight_until_hearts_fall() -> void:
	if not _start(2, {0: Defs.BotLevel.HUNTER, 1: Defs.BotLevel.HUNTER}, 7, FLAT_ARENA, Defs.VersusMode.LAST_CAVEMAN):
		return
	assert_true(_bots[0].brain is LastCavemanBrain)
	var start: int = BotSenses.hearts_of(_level, 0) + BotSenses.hearts_of(_level, 1)
	var fell: bool = _run_until(900, func() -> bool:
		return BotSenses.hearts_of(_level, 0) + BotSenses.hearts_of(_level, 1) < start)
	assert_true(fell, "a heart fell (hearts %d / %d)" % [BotSenses.hearts_of(_level, 0), BotSenses.hearts_of(_level, 1)])
	var attacks: int = 0
	for bot: HeroBot in _bots:
		attacks += (bot.brain as LastCavemanBrain).decisions[LastCavemanBrain.Goal.ATTACK]
	assert_true(attacks >= 2, "both went for each other")


func test_lcs_hurt_bot_fetches_bones() -> void:
	if not _start(2, {1: Defs.BotLevel.ROOKIE}, 3, FLAT_ARENA, Defs.VersusMode.LAST_CAVEMAN):
		return
	GameInput.set_scripted_slot(0, func(_tick: int) -> int: return 0)
	var hero: PlayerBase = _level.get_hero(1)
	hero.run.hearts = 1
	var side: int = 1 if hero.sim_pos.x < 160 else -1
	var bones: Array[Node] = []
	for i: int in 3:
		bones.append(_level.spawn(&"items/bone", Vector2i(hero.sim_pos.x + side * (60 + 12 * i), 160), {}))
	var got: bool = _run_until(400, func() -> bool:
		for bone: Node in bones:
			if is_instance_valid(bone) and not (bone as CollectibleBase).collected:
				return false
		return true)
	assert_true(got, "the hurt bot collected the bones")
	assert_true((_bots[0].brain as LastCavemanBrain).decisions[LastCavemanBrain.Goal.BONES] >= 1)


func test_lcs_grudge_rider_aims_and_drops() -> void:
	if not _start(2, {1: Defs.BotLevel.HUNTER}, 3, FLAT_ARENA, Defs.VersusMode.LAST_CAVEMAN):
		return
	var stub: StubReferee = StubReferee.new()
	stub.mode = Defs.VersusMode.LAST_CAVEMAN
	stub.out = {1: true}
	BotSenses.test_referee = stub
	GameInput.set_scripted_slot(0, func(_tick: int) -> int: return 0)
	var target_x: int = _level.get_hero(0).sim_pos.x
	stub.grudge = {1: Vector2i(target_x - 60, 24)}
	_run_until(12, func() -> bool: return false)
	var flags: int = GameInput.get_flags(1)
	assert_eq(flags & (Defs.IN_LEFT | Defs.IN_RIGHT), Defs.IN_RIGHT, "it steers towards the rival")
	assert_eq(flags & Defs.IN_FIRE, 0, "no rock while off target")
	stub.grudge = {1: Vector2i(target_x + 3, 24)}
	_run_until(2, func() -> bool: return false)
	assert_ne(GameInput.get_flags(1) & Defs.IN_FIRE, 0, "a rock when above him and ready")
	stub.ready = false
	_run_until(2, func() -> bool: return false)
	assert_eq(GameInput.get_flags(1) & Defs.IN_FIRE, 0, "not before the rock is ready")


# =================================================================================================================
# Hot Rock
# =================================================================================================================

func test_hot_rock_holder_chases_and_touches() -> void:
	if not _start(2, {1: Defs.BotLevel.HUNTER}, 3, FLAT_ARENA, Defs.VersusMode.HOT_ROCK):
		return
	var stub: StubReferee = StubReferee.new()
	stub.holder = 1
	BotSenses.test_referee = stub
	GameInput.set_scripted_slot(0, func(_tick: int) -> int: return 0)
	var me: PlayerBase = _level.get_hero(1)
	var rival: PlayerBase = _level.get_hero(0)
	# Any touch, hit or stomp passes the ember: a body overlap or a hit on the rival counts.
	var touched: bool = _run_until(400, func() -> bool:
		return (absi(me.sim_pos.x - rival.sim_pos.x) < Tuning.HERO_BOX_STAND.x
				and absi(me.sim_pos.y - rival.sim_pos.y) < Tuning.HERO_BOX_STAND.y) or rival.hit_timer > 0)
	assert_true(touched, "the holder ran into his rival (%s vs %s)" % [me.sim_pos, rival.sim_pos])
	assert_eq(_bots[0].nav.weight_class, NavGraph.WEIGHT_HOLDER, "the holder plans with the holder's links")
	var brain: HotRockBrain = _bots[0].brain as HotRockBrain
	assert_true(brain.decisions[HotRockBrain.Goal.CHASE] >= 1)


func test_hot_rock_others_flee_and_never_touch_the_holder() -> void:
	if not _start(2, {1: Defs.BotLevel.HUNTER}, 3, FLAT_ARENA, Defs.VersusMode.HOT_ROCK):
		return
	var stub: StubReferee = StubReferee.new()
	stub.holder = 0
	BotSenses.test_referee = stub
	var me: PlayerBase = _level.get_hero(1)
	var holder: PlayerBase = _level.get_hero(0)
	# The holder (a scripted human) walks at the bot all the time.
	GameInput.set_scripted_slot(0, func(_tick: int) -> int:
		return Defs.IN_RIGHT if me.sim_pos.x > holder.sim_pos.x else Defs.IN_LEFT)
	var total: int = 0
	var samples: int = 0
	for t: int in 600:
		Sim.step(1)
		if t >= 60:
			total += absi(me.sim_pos.x - holder.sim_pos.x) + absi(me.sim_pos.y - holder.sim_pos.y)
			samples += 1
	var brain: HotRockBrain = _bots[0].brain as HotRockBrain
	assert_true(brain.decisions[HotRockBrain.Goal.FLEE] >= 1, "it fled")
	assert_true(total / samples >= 48, "it kept away (mean distance %d px)" % (total / samples))
	assert_eq(brain.strikes, 0, "a non-holder never strikes the holder")
	assert_true(_bots[0].idle_ticks < VersusTuning.BOT_IDLE_MAX_TICKS)


# =================================================================================================================
# Clubball
# =================================================================================================================

func test_ball_predictor_bounces_rolls_and_stops() -> void:
	var grid: TileGrid = TileGrid.from_rows(PackedStringArray([
		"|..................|", "|..................|", "|..................|", "|..................|",
		"|..................|", "|..................|", "|..................|", "|..................|",
		"|..................|", "|..................|", "####################", "####################",
	]))
	var state: BallPredictor.State = BallPredictor.State.new()
	state.pos = Vector2i(160, 32)
	state.xvel = 64
	var apexes: PackedInt32Array = PackedInt32Array()
	var rising: bool = false
	var lowest: int = 0
	for t: int in 400:
		var before: int = state.pos.y
		BallPredictor.step(grid, state)
		assert_true(state.pos.y <= 160, "never below the floor top (tick %d: %s)" % [t, state.pos])
		assert_true(state.pos.x >= 8 + 8 and state.pos.x <= 304 + 8, "never inside a wall (tick %d: %s)" % [t, state.pos])
		if state.pos.y < before:
			rising = true
		elif rising and state.pos.y > before:
			rising = false
			apexes.append(before)
		lowest = maxi(lowest, state.pos.y)
	assert_true(apexes.size() >= 2, "it bounced (apexes %s)" % apexes)
	for i: int in range(1, apexes.size()):
		assert_true(apexes[i] >= apexes[i - 1], "every bounce lower than the last (%s)" % apexes)
	assert_eq(state.pos.y, 160, "it lies on the floor")
	assert_eq(state.xvel, 0, "rolling friction stopped it")
	assert_eq(state.yvel, 0)
	assert_eq(BallPredictor.reflect(100), -75)
	assert_eq(BallPredictor.reflect(-100), 75)


func test_ball_predictor_matches_the_coconut() -> void:
	# objects-B's objects/coconut (P2.7) on a Clubball pitch (the coconut sits out every other mode): the prediction is
	# its own flight, tick for tick (tiles only: the flight stays clear of both heroes and both goal mouths).
	if not Spawner.exists(&"objects/coconut"):
		assert_true(true, "objects/coconut does not exist yet")
		return
	if not _start(2, {}, 3, "", Defs.VersusMode.CLUBBALL, PITCH, PITCH_ID):
		return
	GameInput.set_scripted_slot(0, func(_tick: int) -> int: return 0)
	GameInput.set_scripted_slot(1, func(_tick: int) -> int: return 0)
	var ball: SimEntity = _level.spawn(&"objects/coconut", Vector2i(120, 64), {}) as SimEntity
	assert_not_null(ball)
	Sim.step(1)
	ball.xvel = 40
	ball.yvel = -64
	var path: Array[Vector2i] = BallPredictor.predict(_level, ball, 40)
	assert_eq(path.size(), 40)
	var bounced: bool = false
	for t: int in mini(40, path.size()):
		Sim.step(1)
		assert_eq(ball.sim_pos, path[t], "tick %d" % t)
		bounced = bounced or (t > 0 and path[t].y < path[t - 1].y and path[t - 1].y >= 150)
	assert_true(bounced, "the flight bounced on the floor (%s)" % [path])


func test_clubball_bot_drives_the_ball_at_the_goal() -> void:
	if not _start(2, {1: Defs.BotLevel.HUNTER}, 3, "", Defs.VersusMode.CLUBBALL, PITCH, PITCH_ID):
		return
	var stub: StubReferee = StubReferee.new()
	stub.mode = Defs.VersusMode.CLUBBALL
	# The bot (slot 1, on the right) defends the right goal and attacks the left one.
	stub.teams = {0: 1, 1: 2}
	stub.goals = {1: Rect2i(0, 112, 24, 48), 2: Rect2i(296, 112, 24, 48)}
	var ball: StubBall = StubBall.new()
	ball.spawn_setup(Vector2i(170, 120), {})
	_level.add_child(ball)
	stub.ball_entity = ball
	BotSenses.test_referee = stub
	GameInput.set_scripted_slot(0, func(_tick: int) -> int: return 0)
	_level.get_hero(0).respawn_at(Vector2i(40, 160))
	var scored: bool = _run_until(900, func() -> bool: return ball.sim_pos.x < 48)
	var brain: ClubballBrain = _bots[0].brain as ClubballBrain
	assert_true(ball.hits >= 1, "the bot struck the coconut (%d hits, ball at %s)" % [ball.hits, ball.sim_pos])
	assert_eq(ball.last_dir, -1, "towards the goal it attacks")
	assert_true(scored, "the ball reached the left goal (at %s, hits %d)" % [ball.sim_pos, ball.hits])
	assert_eq(brain.attack_dir, -1)
	assert_false(brain.prediction.is_empty())


func test_clubball_keeper_and_attacker_split() -> void:
	if not _start(3, {1: Defs.BotLevel.HUNTER, 2: Defs.BotLevel.HUNTER}, 3, "", Defs.VersusMode.CLUBBALL, PITCH,
			PITCH_ID):
		return
	var stub: StubReferee = StubReferee.new()
	stub.mode = Defs.VersusMode.CLUBBALL
	stub.teams = {0: 1, 1: 2, 2: 2}
	stub.goals = {1: Rect2i(0, 112, 24, 48), 2: Rect2i(296, 112, 24, 48)}
	var ball: StubBall = StubBall.new()
	ball.spawn_setup(Vector2i(120, 100), {})
	_level.add_child(ball)
	stub.ball_entity = ball
	BotSenses.test_referee = stub
	GameInput.set_scripted_slot(0, func(_tick: int) -> int: return 0)
	_run_until(60, func() -> bool: return false)
	var goals: Array[int] = []
	for bot: HeroBot in _bots:
		goals.append((bot.brain as ClubballBrain).goal)
	assert_true(goals.has(ClubballBrain.Goal.CHASE) and goals.has(ClubballBrain.Goal.KEEP),
			"one teammate chases, the other keeps (%s)" % [goals])


func test_clubball_bot_does_not_dodge_a_ball_lying_on_the_bridge_over_him() -> void:
	# wf10_content_to_core-B.txt #7 (Coconut Cove, seed 53 round 3): the coconut rests on the lob bridge, the keeper
	# stands on the low ledge 3 rows under it - his head (35 px up) is in the bridge's own row, which the floor scan
	# of _out_from_under left out, so he stepped "out from under it" every tick and the round never ended.
	if not _start(2, {1: Defs.BotLevel.HUNTER}, 3, "", Defs.VersusMode.CLUBBALL, BRIDGE_PITCH, BRIDGE_PITCH_ID):
		return
	var stub: StubReferee = StubReferee.new()
	stub.mode = Defs.VersusMode.CLUBBALL
	stub.teams = {0: 1, 1: 2}
	stub.goals = {1: Rect2i(0, 112, 24, 48), 2: Rect2i(296, 112, 24, 48)}
	var ball: StubBall = StubBall.new()
	ball.spawn_setup(Vector2i(114, 64), {})
	_level.add_child(ball)
	stub.ball_entity = ball
	BotSenses.test_referee = stub
	GameInput.set_scripted_slot(0, func(_tick: int) -> int: return 0)
	Sim.step(2)
	var brain: ClubballBrain = _bots[0].brain as ClubballBrain
	_bots[0].uninstall()
	GameInput.set_scripted_slot(1, func(_tick: int) -> int: return 0)
	var hero: PlayerBase = _level.get_hero(1)
	hero.respawn_at(Vector2i(112, 112))
	Sim.step(4)
	assert_true(hero.is_grounded() and hero.sim_pos.y == 112, "he stands on the low ledge (%s)" % [hero.sim_pos])
	ball.teleport(Vector2i(114, 64))
	assert_eq((hero.sim_pos.y - Tuning.HERO_BOX_STAND.y) >> 4, 4, "his head is in the bridge's row")
	assert_eq(brain._out_from_under(hero), -1, "the coconut lies on the bridge: nothing comes down on his head")
	# The same coconut in the air right over him, no floor between: he steps out from under it.
	ball.teleport(Vector2i(114, 70))
	hero.respawn_at(Vector2i(160, 160))
	Sim.step(4)
	ball.teleport(Vector2i(hero.sim_pos.x + 2, 100))
	assert_true(brain._out_from_under(hero) >= 0, "a coconut over his head with nothing between: he moves")


# =================================================================================================================
# The Rival Chieftains: the boss interface
# =================================================================================================================

func test_chieftain_goes_raids_with_a_telegraph() -> void:
	if not _start(2, {}):
		return
	var victim: PlayerBase = _level.get_hero(0)
	var body: PlayerBase = _level.get_hero(1)
	GameInput.set_scripted_slot(0, func(_tick: int) -> int: return 0)
	var bot: HeroBot = HeroBot.for_boss(body, 11, Defs.BotLevel.HUNTER, 1)
	bot.install()
	_bots.append(bot)
	var brain: ChieftainBrain = bot.brain as ChieftainBrain
	assert_not_null(brain)
	assert_false(bot.is_rival(1), "his own body is no rival")
	assert_true(bot.is_rival(0))
	var calls: Array[int] = []
	brain.on_telegraph = func(kind: int) -> void: calls.append(kind)
	# GOTO a point on the floor.
	var point: Vector2i = Vector2i(240 if body.sim_pos.x < 160 else 80, 160)
	brain.order(ChieftainBrain.Order.GOTO, -1, point)
	var there: bool = _run_until(300, func() -> bool: return brain.order_done())
	assert_true(there, "GOTO arrived (at %s, wanted %s)" % [body.sim_pos, point])
	assert_true(absi(body.sim_pos.x - point.x) <= ChieftainBrain.ARRIVE_PX)
	# RAID the standing hero: a 14-tick crouch, then the strike.
	brain.order(ChieftainBrain.Order.RAID, 0)
	var crouch: Array[int] = [0]
	var max_crouch: Array[int] = [0]
	var struck: bool = _run_until(400, func() -> bool:
		if body.is_crouching():
			crouch[0] += 1
			max_crouch[0] = maxi(max_crouch[0], crouch[0])
		else:
			crouch[0] = 0
		return body.club_box_active)
	assert_true(struck, "the raid struck (body %s, victim %s)" % [body.sim_pos, victim.sim_pos])
	assert_true(calls.size() >= 1 and calls[0] == ChieftainBrain.ATTACK_STRIKE, "HUP! for a strike (%s)" % [calls])
	assert_true(max_crouch[0] >= ChieftainBrain.TELEGRAPH_TICKS - 2,
			"the strike came after the announcing crouch (%d ticks)" % max_crouch[0])
	assert_true(brain.telegraphs[ChieftainBrain.ATTACK_STRIKE] >= 1)


func test_chieftain_lone_rule_and_bat() -> void:
	if not _start(3, {}):
		return
	var body: PlayerBase = _level.get_hero(2)
	var mate: PlayerBase = _level.get_hero(1)
	var target: PlayerBase = _level.get_hero(0)
	var bot: HeroBot = HeroBot.for_boss(body, 3, Defs.BotLevel.CHIEF, 0)
	bot.install()
	_bots.append(bot)
	var brain: ChieftainBrain = bot.brain as ChieftainBrain
	brain.mate = mate
	target.respawn_at(Vector2i(40, 160))
	mate.respawn_at(Vector2i(170, 160))
	body.respawn_at(Vector2i(230, 160))
	# The mate curls (a scripted human here: Down + Swap, then Down) and waits to be batted towards the target.
	GameInput.set_scripted_slot(0, func(_tick: int) -> int: return 0)
	GameInput.set_scripted_slot(1, func(tick: int) -> int: return Defs.IN_DOWN | (Defs.IN_SWAP if tick % 4 == 0 else 0))
	_run_until(8, func() -> bool: return false)
	assert_eq(brain.lone_target(_level), 0, "the lone rule: the hero farther from the view centre")
	brain.order(ChieftainBrain.Order.BAT, 0)
	var start_x: int = mate.sim_pos.x
	var batted: bool = _run_until(300, func() -> bool: return brain.order_done())
	assert_true(batted, "the bat swing came (mate curled: %s)" % mate.is_curled())
	assert_true(brain.telegraphs[ChieftainBrain.ATTACK_BAT] >= 1, "announced")
	_run_until(20, func() -> bool: return false)
	if mate.is_curled() or mate.sim_pos.x != start_x:
		assert_true(mate.sim_pos.x < start_x - 24, "the mate flew towards the target (%d -> %d)" % [start_x, mate.sim_pos.x])


func test_chieftain_curls_and_stacks() -> void:
	if not _start(2, {}):
		return
	var body: PlayerBase = _level.get_hero(1)
	var mate: PlayerBase = _level.get_hero(0)
	var bot: HeroBot = HeroBot.for_boss(body, 5, Defs.BotLevel.HUNTER, 1)
	bot.install()
	_bots.append(bot)
	var brain: ChieftainBrain = bot.brain as ChieftainBrain
	brain.mate = mate
	GameInput.set_scripted_slot(0, func(_tick: int) -> int: return 0)
	brain.order(ChieftainBrain.Order.CURL)
	var curled: bool = _run_until(30, func() -> bool: return body.is_curled())
	assert_true(curled, "CURL curls him")
	brain.order(ChieftainBrain.Order.STACK_TOP)
	mate.respawn_at(Vector2i(160, 160))
	var head: int = mate.sim_pos.y - Tuning.HERO_BOX_STAND.y
	var highest: Array[int] = [999]
	_run_until(300, func() -> bool:
		if absi(body.sim_pos.x - mate.sim_pos.x) <= 16:
			highest[0] = mini(highest[0], body.sim_pos.y)
		return false)
	assert_true(highest[0] <= head + 4, "he got onto the mate's head (best feet y %d, head %d)" % [highest[0], head])


# =================================================================================================================
# Helpers
# =================================================================================================================

## Load an arena (a file, or `text`) as a versus round of `party` heroes in `mode`, put HeroBots in the slots of `bots`
## (slot -> level), bake (or load) the graph first, skip the intro. False (and the test passes with a note) without
## the arena file or a referee that compiles.
func _start(party: int, bots: Dictionary, seed_value: int = 3, path: String = FLAT_ARENA,
		mode: int = Defs.VersusMode.GRUB_STACK, text: String = "", text_id: StringName = PITCH_ID) -> bool:
	if text.is_empty() and not FileAccess.file_exists(path):
		assert_true(true, "%s does not exist yet" % path)
		return false
	var level_text: String = text if not text.is_empty() else FileAccess.get_file_as_string(path)
	var level_id: StringName = StringName(path.get_file().get_basename()) if text.is_empty() else text_id
	var graph: NavGraph = NavGraph.load_file(NavGraph.path_for(level_id))
	if graph == null or graph.source_sha256 != NavGraph.text_sha256(level_text):
		graph = NavBaker.new().bake_text(self, level_id, level_text, Defs.Difficulty.BEGINNER,
				NavGraph.weight_classes_for(LevelData.parse(level_id, level_text).resolved_meta(0)))
	NavGraph.cache(graph)
	if not ResourceLoader.exists("res://scripts/world/versus/referee.gd") \
			or not (load("res://scripts/world/versus/referee.gd") as Script).can_instantiate():
		assert_true(true, "the referee does not compile right now (world-B)")
		return false
	Sim.manual = true
	Game.start_run(Defs.Difficulty.BEGINNER, Defs.GameMode.VERSUS, party, 1)
	Game.begin_level(level_id)
	_level = (load(LEVEL_SCENE) as PackedScene).instantiate() as Level
	_level.setup_from_text(level_id, level_text)
	add_node(_level)
	_level.set_view_size(Vector2i(640, 360))
	Sim.start(seed_value)
	var referee: Object = BotSenses.referee(_level)
	if referee != null:
		if mode != Defs.VersusMode.GRUB_STACK and referee.get(&"mode") != null:
			referee.set(&"mode", mode)
			if referee.has_method(&"begin_round"):
				referee.call(&"begin_round", 0)
		if referee.has_method(&"start_round_now"):
			referee.call(&"start_round_now")
	for slot: int in bots:
		var bot: HeroBot = HeroBot.new(slot, int(bots[slot]), seed_value, mode)
		bot.install()
		_bots.append(bot)
	return true


## Step until `done` holds (checked after every tick) or `ticks` ran out; true when it held.
func _run_until(ticks: int, done: Callable) -> bool:
	for t: int in ticks:
		Sim.step(1)
		if bool(done.call()):
			return true
	return false


## The G1 configuration on the flat arena: P1 and P2 are "humans" (deterministic scripted wandering and swings),
## P3 and P4 Rookie bots; one whole round (or 1600 ticks). The trace is every slot's flags per tick plus the scores.
func _slice_round(seed_value: int) -> PackedInt32Array:
	if not _start(4, {2: Defs.BotLevel.ROOKIE, 3: Defs.BotLevel.ROOKIE}, seed_value):
		return PackedInt32Array()
	var human: SimRng = SimRng.new(seed_value)
	var keys: PackedInt32Array = PackedInt32Array([0, 0])
	GameInput.set_scripted_slot(0, func(_tick: int) -> int: return keys[0])
	GameInput.set_scripted_slot(1, func(_tick: int) -> int: return keys[1])
	var choices: PackedInt32Array = PackedInt32Array([Defs.IN_LEFT, Defs.IN_RIGHT, Defs.IN_RIGHT | Defs.IN_UP,
			Defs.IN_LEFT | Defs.IN_UP, Defs.IN_FIRE | Defs.IN_RIGHT, Defs.IN_FIRE | Defs.IN_LEFT, 0, Defs.IN_DOWN])
	var trace: PackedInt32Array = PackedInt32Array()
	var referee: Object = BotSenses.referee(_level)
	var ended: Array[bool] = [false]
	var on_end: Callable = func(_round: int, _winners: PackedInt32Array) -> void: ended[0] = true
	Events.round_ended.connect(on_end)
	var bot_score: int = 0
	for t: int in 2400:
		if t % 12 == 0:
			keys[0] = choices[human.next_int(choices.size())]
			keys[1] = choices[human.next_int(choices.size())]
		Sim.step(1)
		for slot: int in 4:
			trace.append(GameInput.get_flags(slot))
		if referee != null and referee.has_method(&"score_of"):
			bot_score = maxi(bot_score, int(referee.call(&"score_of", 2)) + int(referee.call(&"score_of", 3)))
		if ended[0]:
			break
	Events.round_ended.disconnect(on_end)
	for slot: int in 4:
		trace.append(_level.get_hero(slot).sim_pos.x)
		trace.append(BotSenses.stack_of(_level, slot) + BotSenses.banked_of(_level, slot))
	if referee != null:
		assert_true(ended[0], "the round reached its gong")
		assert_true(bot_score > 0, "the Rookies scored")
	for bot: HeroBot in _bots:
		assert_true(bot.nav.links_played > 0, "bot %d used the graph" % bot.slot)
		bot.uninstall()
	_bots.clear()
	GameInput.clear_scripted()
	_level.free()
	_level = null
	Sim.stop()
	return trace
