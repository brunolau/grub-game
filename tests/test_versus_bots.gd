extends TestCase
## The Grub Stack bots on a running arena (DESIGN.md E.3 / E.7, PLAN.md P1.2 for the G1 slice: "Totem Ring Grub
## Stack with two humans and two Rookie bots"): HeroBots in GameInput's BOT slots beside scripted "humans", on world-B's
## referee (VersusReferee) and objects-B's cookpots, on the flat test arena. Seek food, strike spots, attack stacked
## rivals, bank at the cookpot, never idle, and a match replays tick for tick.

const LEVEL_SCENE: String = "res://scenes/world/level.tscn"
const FLAT_ARENA: String = "res://levels/test_world_arena_flat.lvl"
const FLAT_ID: StringName = &"test_world_arena_flat"
## world-B's copy of the Totem Ring sketch: wrap left-right, springs to the wrap ledges, a cookpot on the totem top.
const RING_ARENA: String = "res://levels/test_world_arena_ring.lvl"

var _level: Level = null
var _bots: Array[HeroBot] = []


func before_each() -> void:
	Game.new_game(Defs.Difficulty.BEGINNER)
	NavGraph.clear_cache()
	_level = null
	_bots.clear()


func after_each() -> void:
	for bot: HeroBot in _bots:
		bot.uninstall()
	_bots.clear()
	GameInput.clear_scripted()
	GameInput.reset_slots()
	NavGraph.clear_cache()
	BotBrain.clear_cache()
	Sim.stop()
	_level = null
	Game.new_game(Defs.Difficulty.BEGINNER)


# =================================================================================================================
# Goals
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
	assert_true(got, "the bot fetched the food (stack %d, referee %s, hero at %s, item %s, goal %d)" % [
		BotSenses.stack_of(_level, 1), referee, hero.sim_pos, is_instance_valid(item),
		(_bots[0].brain as GrubStackBrain).goal,
	])
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
	if referee == null:
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


func test_bots_bank_on_the_totem_ring() -> void:
	# The Totem Ring copy: pots on the totem top (row 3, up by the bridges) and on the left floor; the wrap seam and
	# the springs are in the graph.
	if not _start(4, {2: Defs.BotLevel.ROOKIE, 3: Defs.BotLevel.HUNTER}, 4, RING_ARENA):
		return
	var referee: Object = BotSenses.referee(_level)
	if referee == null:
		assert_true(true, "no referee yet")
		return
	GameInput.set_scripted_slot(0, func(_tick: int) -> int: return 0)
	GameInput.set_scripted_slot(1, func(_tick: int) -> int: return 0)
	referee.call(&"add_food", _level.get_hero(2), 10)
	referee.call(&"add_food", _level.get_hero(3), 10)
	var banked: bool = _run_until(700, func() -> bool:
		return int(referee.call(&"banked_of", 2)) > 0 and int(referee.call(&"banked_of", 3)) > 0)
	assert_true(banked, "both bots banked (banked %d / %d)" % [
		int(referee.call(&"banked_of", 2)), int(referee.call(&"banked_of", 3)),
	])
	for bot: HeroBot in _bots:
		assert_eq(bot.nav.links_failed, 0, "bot %d: every link landed" % bot.slot)


func test_hunter_attacks_a_stacked_rival() -> void:
	if not _start(2, {1: Defs.BotLevel.HUNTER}):
		return
	var referee: Object = BotSenses.referee(_level)
	if referee == null:
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


# =================================================================================================================
# The G1 slice: two humans and two Rookie bots
# =================================================================================================================

func test_two_humans_and_two_rookies_play_a_round() -> void:
	var trace: PackedInt32Array = _slice_round(21)
	if trace.is_empty():
		return
	var again: PackedInt32Array = _slice_round(21)
	assert_eq(again, trace, "the round replays tick for tick")


func test_no_bot_stands_idle_for_ten_seconds() -> void:
	if not _start(4, {0: Defs.BotLevel.HUNTER, 1: Defs.BotLevel.HUNTER, 2: Defs.BotLevel.ROOKIE,
			3: Defs.BotLevel.ROOKIE}):
		return
	var worst: PackedInt32Array = PackedInt32Array([0, 0, 0, 0])
	for t: int in 1200:
		Sim.step(1)
		for i: int in _bots.size():
			worst[i] = maxi(worst[i], _bots[i].idle_ticks)
	for i: int in _bots.size():
		assert_true(worst[i] <= VersusTuning.BOT_IDLE_MAX_TICKS, "bot %d stood still %d ticks" % [i, worst[i]])


# =================================================================================================================
# Helpers
# =================================================================================================================

## Load the flat arena as a Grub Stack round of `party` heroes, put HeroBots in the slots of `bots` (slot -> level),
## bake (or load) the graph first, skip the intro. False (and the test passes with a note) without the arena file.
func _start(party: int, bots: Dictionary, seed_value: int = 3, path: String = FLAT_ARENA) -> bool:
	if not FileAccess.file_exists(path):
		assert_true(true, "%s does not exist yet" % path)
		return false
	var level_id: StringName = StringName(path.get_file().get_basename())
	var text: String = FileAccess.get_file_as_string(path)
	var graph: NavGraph = NavGraph.load_file(NavGraph.path_for(level_id))
	if graph == null or graph.source_sha256 != NavGraph.text_sha256(text):
		graph = NavBaker.new().bake_text(self, level_id, text)
	NavGraph.cache(graph)
	Sim.manual = true
	Game.start_run(Defs.Difficulty.BEGINNER, Defs.GameMode.VERSUS, party, 1)
	Game.begin_level(level_id)
	_level = (load(LEVEL_SCENE) as PackedScene).instantiate() as Level
	_level.setup_from_text(level_id, text)
	add_node(_level)
	_level.set_view_size(Vector2i(640, 360))
	Sim.start(seed_value)
	var referee: Object = BotSenses.referee(_level)
	if referee != null and referee.has_method(&"start_round_now"):
		referee.call(&"start_round_now")
	for slot: int in bots:
		var bot: HeroBot = HeroBot.new(slot, int(bots[slot]), seed_value)
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
		if referee != null:
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
