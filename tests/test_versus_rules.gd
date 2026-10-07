extends ObjectsTestCase
## The versus referee (docs/spec/PHYSICS.md C.14, GAMEPLAY.md 13.10, DESIGN.md E.2 / E.3; PLAN.md 8 V4.a): arena
## set-up, gather-then-apply hits, clang, deflect, the stomp ladder, curl and bat, teammates, the spawn shield, Grub
## Stack (stack, spills, steals, cookpot, weight, round clock, Feast Rush, Golden Drumstick), knock-outs and respawns,
## wrap edges. Owner: world-B (scripts/world/versus/**).
##
## Most rules are driven on bare PlayerBase heroes (they stay where they are put; a club box stays live until the
## referee consumes it), so each rule is checked on its own; the last tests drive real heroes from scripted input
## streams through a real arena file.

const FLAT_ROWS: PackedStringArray = [
	"....................", "....................", "....................", "....................",
	"....................", "....................", "....................", "...-----....-----...",
	"....................", "....................", "####################", "####################",
]
const FLOOR_Y: int = 160
const BOX_FWD: Rect2i = Rect2i(11, -15, 24, 13)

var referee: VersusReferee = null
var heroes: Array[PlayerBase] = []
var ended: Array[PackedInt32Array] = []
var kos: Array[Array] = []


func before_each() -> void:
	super.before_each()
	ended.clear()
	kos.clear()
	heroes.clear()
	Events.round_ended.connect(_on_round_ended)
	Events.hero_ko.connect(_on_hero_ko)


func after_each() -> void:
	Events.round_ended.disconnect(_on_round_ended)
	Events.hero_ko.disconnect(_on_hero_ko)
	super.after_each()
	Game.new_game(Defs.Difficulty.BEGINNER)
	Game.begin_level(&"")
	referee = null


func _on_round_ended(_round_index: int, winners: PackedInt32Array) -> void:
	ended.append(winners)


func _on_hero_ko(victim: PlayerBase, killer: PlayerBase, cause: StringName) -> void:
	kos.append([victim, killer, cause])


## An arena of `count` bare heroes standing on the floor at `xs` (slot order), the round running with no shields.
func _arena(count: int, xs: Array = [64, 128, 192, 256], wrap_name: String = "none",
		rows: PackedStringArray = FLAT_ROWS) -> void:
	Game.start_run(Defs.Difficulty.BEGINNER, Defs.GameMode.VERSUS, count)
	Game.begin_level(&"test_versus")
	make_recording_level(rows)
	level.meta = {"kind": "arena", "players": 4, "modes": "grub_stack", "wrap": wrap_name, "round_time": 90}
	level.start_pos = Vector2i(int(xs[0]), FLOOR_Y)
	level.start_positions.clear()
	for slot: int in Defs.MAX_PLAYERS:
		level.start_positions.append(Vector2i(int(xs[slot % xs.size()]), FLOOR_Y))
	for slot: int in count:
		var hero: PlayerBase = PlayerBase.new()
		place(level, hero, Vector2i(int(xs[slot]), FLOOR_Y), {"slot": slot})
		hero.respawn_at(Vector2i(int(xs[slot]), FLOOR_Y))
		heroes.append(hero)
	referee = VersusArena.setup(level)
	referee.start_round_now()
	_unshield()


func _unshield() -> void:
	for hero: PlayerBase in heroes:
		hero.shield = 0
		referee._shield_left[hero.slot] = 0


## A forward club box of `hero` (facing `dir`) where he stands, live for the next weapon pass.
func _box(hero: PlayerBase, dir: int, power: int = 25, rect: Rect2i = BOX_FWD) -> void:
	hero.facing = dir
	var origin_x: int = hero.sim_pos.x + dir * (rect.position.x + rect.size.x / 2)
	hero.club_box_xo = rect.size.x / 2
	hero.club_box = Rect2i(origin_x - hero.club_box_xo, hero.sim_pos.y + rect.position.y, rect.size.x, rect.size.y)
	hero.club_origin = Vector2i(origin_x, hero.sim_pos.y)
	hero.club_power = power
	hero.club_box_active = true


func _give(hero: PlayerBase, units: int) -> void:
	referee.add_food(hero, units)


# =================================================================================================================
# Arena set-up
# =================================================================================================================

func test_arena_setup_locks_the_camera_and_registers_the_referee() -> void:
	_arena(2)
	assert_eq(level.party_driver, referee, "the referee is the arena's party driver (after the heroes)")
	assert_eq(VersusReferee.find(level), referee)
	assert_true(level.is_camera_locked())
	assert_eq(level.get_camera_lock(), Rect2i(0, 0, 320, 176), "the authentic 20 x 11 screen")
	assert_eq(VersusArena.setup(level), referee, "a second call returns the same referee")
	assert_eq(referee.mode, Defs.VersusMode.GRUB_STACK, "the arena's first mode")
	assert_eq(referee.round_length(), VersusTuning.STACK_ROUND_TICKS_2P, "Grub Stack plays 60 s with two players")
	assert_true(referee.handle_hero_death(heroes[0]), "every arena death is the referee's")
	var plain: LevelBase = make_level(FLAT_ROWS)
	plain.meta = {"kind": "main"}
	assert_null(VersusArena.setup(plain), "a level that is not an arena is left alone")
	assert_null(VersusReferee.find(plain))


func test_arena_meta_helpers() -> void:
	var meta: Dictionary = {"kind": "arena", "modes": "hot_rock,grub_stack,tag", "wrap": "tb", "players": 3}
	assert_true(VersusArena.is_arena_meta(meta))
	assert_false(VersusArena.is_arena_meta({"kind": "coop"}))
	assert_eq(VersusArena.wrap_mode(meta), VersusArena.WRAP_TB)
	assert_eq(VersusArena.wrap_mode({}), VersusArena.WRAP_NONE)
	assert_eq(VersusArena.modes_of(meta), PackedInt32Array([Defs.VersusMode.HOT_ROCK, Defs.VersusMode.GRUB_STACK]))
	assert_eq(VersusArena.default_mode(meta), Defs.VersusMode.HOT_ROCK)
	assert_eq(VersusArena.default_mode({}), Defs.VersusMode.GRUB_STACK)
	assert_eq(VersusArena.players_of(meta), 3)


func test_intro_countdown_freezes_the_heroes_then_grub() -> void:
	_arena(2)
	var counts: Array[int] = []
	var started: Array[int] = []
	var on_count: Callable = func(_r: int, count: int) -> void: counts.append(count)
	var on_start: Callable = func(r: int) -> void: started.append(r)
	Events.round_countdown.connect(on_count)
	Events.round_started.connect(on_start)
	referee.begin_round(0)
	assert_eq(referee.phase, VersusReferee.PHASE_INTRO)
	assert_false(heroes[0].control_enabled, "frozen during the countdown")
	Sim.step(VersusTuning.COUNTDOWN_STEPS * VersusReferee.INTRO_COUNT_TICKS)
	Events.round_countdown.disconnect(on_count)
	Events.round_started.disconnect(on_start)
	assert_eq(counts, [3, 2, 1, 0] as Array[int], "3, 2, 1, GRUB!")
	assert_eq(started, [0] as Array[int])
	assert_eq(referee.phase, VersusReferee.PHASE_PLAY)
	assert_true(heroes[0].control_enabled)
	assert_eq(heroes[1].shield, VersusTuning.SPAWN_SHIELD_TICKS - 1, "the spawn shield of the round start (counting)")


func test_spawns_rotate_every_round() -> void:
	_arena(3, [40, 160, 280])
	referee.begin_round(0)
	assert_eq(heroes[0].sim_pos.x, 40)
	assert_eq(heroes[1].sim_pos.x, 160)
	referee.begin_round(1)
	assert_eq(heroes[0].sim_pos.x, 160, "round 1: slot 0 takes spawn 2")
	assert_eq(heroes[1].sim_pos.x, 280)
	assert_eq(heroes[2].sim_pos.x, 40)
	assert_eq(heroes[2].facing, 1, "facing the middle")
	assert_eq(heroes[1].facing, -1)


# =================================================================================================================
# Hits
# =================================================================================================================

func test_a_hit_knocks_back_spills_the_stack_and_stops_both() -> void:
	_arena(2, [100, 125])
	_give(heroes[1], 12)
	_box(heroes[0], 1)
	Sim.step(1)
	var victim: PlayerBase = heroes[1]
	assert_false(heroes[0].club_box_active, "one target per box: consumed")
	assert_eq(victim.xvel, VersusTuning.HIT_XVEL, "knocked away from the attacker")
	assert_eq(victim.yvel, VersusTuning.HIT_YVEL)
	assert_eq(victim.hit_timer, VersusTuning.HURT_TIMER_TICKS - 0, "12 stunned + 30 immune (+1)")
	assert_eq(victim.hit_stop, VersusTuning.HIT_STOP_TICKS - 1, "hit-stop counted by the referee")
	assert_eq(heroes[0].hit_stop, VersusTuning.HIT_STOP_TICKS - 1)
	assert_eq(referee.stack_of(1), 12 - (1 + 12 / VersusTuning.SPILL_HIT_DIV), "1 + stack / 5 pieces fly off")
	assert_eq(count_items(&"items/food"), 3, "the spilled pieces fly out as dropped food")
	assert_eq(Game.runs[1].hearts, Tuning.ENERGY_START, "no heart lost: the stack is the currency")
	assert_eq(Game.runs[0].hits, 1)
	assert_eq(Game.runs[1].dropped, 3)


func test_a_charged_hit_launches_and_spills_half() -> void:
	_arena(2, [100, 125])
	_give(heroes[1], 10)
	_box(heroes[0], 1, Tuning.WEAPON_POWER[0] * Tuning.CHARGE_MULTIPLIER)
	Sim.step(1)
	var victim: PlayerBase = heroes[1]
	assert_eq(victim.xvel, VersusTuning.CHARGED_XVEL)
	assert_eq(victim.yvel, VersusTuning.CHARGED_YVEL)
	assert_eq(victim.ice, VersusTuning.CHARGED_SLIDE_ICE, "the launch slides")
	assert_eq(victim.hit_stop, VersusTuning.HIT_STOP_BIG_TICKS - 1, "the big hit-stop")
	assert_eq(referee.stack_of(1), 10 - (1 + 10 / VersusTuning.SPILL_CHARGED_DIV))
	assert_eq(count_items(&"items/treasure"), 1, "six units: a 5 and a 1")
	assert_eq(count_items(&"items/food"), 1)


func test_the_hammer_knocks_one_and_a_half_and_left_is_left() -> void:
	_arena(2, [100, 125])
	Game.runs[1].set_weapon(Defs.Weapon.HAMMER)
	_box(heroes[1], -1, Tuning.WEAPON_POWER[Defs.Weapon.HAMMER])
	Sim.step(1)
	assert_eq(heroes[0].xvel, -VersusTuning.HIT_XVEL * 3 / 2, "hammer x1.5, away to the left")


func test_a_trade_hits_both_heroes() -> void:
	_arena(2, [100, 125])
	_give(heroes[0], 5)
	_give(heroes[1], 5)
	_box(heroes[0], 1, 25, Rect2i(11, -15, 10, 13))
	_box(heroes[1], -1, 25, Rect2i(16, -15, 10, 13))
	assert_false(Overlap.rects(heroes[0].club_box, heroes[1].club_box), "the boxes miss each other")
	Sim.step(1)
	assert_eq(referee.stack_of(0), 3, "nobody wins a trade by slot order")
	assert_eq(referee.stack_of(1), 3)
	assert_eq(heroes[0].xvel, -VersusTuning.HIT_XVEL)
	assert_eq(heroes[1].xvel, VersusTuning.HIT_XVEL)


func test_clang_cancels_both_boxes_and_pushes_the_heroes_apart() -> void:
	_arena(2, [100, 125])
	_give(heroes[1], 5)
	_box(heroes[0], 1)
	_box(heroes[1], -1)
	assert_true(Overlap.rects(heroes[0].club_box, heroes[1].club_box))
	Sim.step(1)
	assert_eq(referee.stack_of(1), 5, "neither hits")
	assert_eq(heroes[0].sim_pos.x, 100 - VersusTuning.CLANG_PUSH_EACH_PX)
	assert_eq(heroes[1].sim_pos.x, 125 + VersusTuning.CLANG_PUSH_EACH_PX, "16 px apart")
	assert_eq(heroes[0].hit_timer, 0)
	assert_eq(Game.runs[0].clangs, 1)
	assert_eq(Game.runs[1].clangs, 1)


func test_a_charged_box_wins_the_clang() -> void:
	_arena(2, [100, 125])
	_give(heroes[1], 10)
	_box(heroes[0], 1, 100)
	_box(heroes[1], -1)
	Sim.step(1)
	assert_eq(heroes[1].xvel, VersusTuning.CHARGED_XVEL, "the charged box hits")
	assert_eq(heroes[0].hit_timer, 0, "the uncharged one is cancelled")
	assert_eq(referee.stack_of(1), 4)


func test_an_immune_or_feasting_hero_is_not_hit() -> void:
	_arena(3, [100, 125, 200])
	_give(heroes[1], 5)
	heroes[1].hit_timer = 20
	_box(heroes[0], 1)
	Sim.step(1)
	assert_eq(referee.stack_of(1), 5, "immune after a hit")
	heroes[1].hit_timer = 0
	heroes[1].feast = 50
	_box(heroes[0], 1)
	Sim.step(1)
	assert_eq(referee.stack_of(1), 5, "a feasting hero cannot be touched")


func test_the_spawn_shield_blocks_hits_and_ends_on_a_strike() -> void:
	_arena(2, [100, 125])
	_give(heroes[1], 5)
	referee._shield_left[1] = VersusTuning.SPAWN_SHIELD_TICKS
	heroes[1].shield = VersusTuning.SPAWN_SHIELD_TICKS
	_box(heroes[0], 1)
	Sim.step(1)
	assert_eq(referee.stack_of(1), 5, "shielded")
	assert_eq(heroes[1].shield, VersusTuning.SPAWN_SHIELD_TICKS - 1, "counted down by the referee")
	heroes[1].attack_gate = true
	Sim.step(1)
	assert_eq(heroes[1].shield, 0, "his first strike ends it")
	heroes[1].attack_gate = false
	heroes[1].hit_timer = 20
	heroes[1].attack_gate = true
	Sim.step(1)
	assert_eq(heroes[1].hit_timer, 0, "a strike ends the immunity at once")


func test_teammates_only_bump() -> void:
	_arena(2, [100, 125])
	referee.teams = PackedInt32Array([1, 1, -1, -1])
	_give(heroes[1], 5)
	_box(heroes[0], 1)
	Sim.step(1)
	assert_eq(referee.stack_of(1), 5, "a friendly hit costs nothing")
	assert_eq(heroes[1].xvel, VersusTuning.TEAMMATE_BUMP_XVEL)
	assert_eq(heroes[1].hit_timer, 0)


func test_a_curled_rival_is_batted_from_the_side_and_glances_from_above() -> void:
	_arena(2, [100, 125])
	var curled: PlayerBase = heroes[1]
	curled.curl = PlayerBase.CURL_CURLED
	heroes[0].sim_pos.y = FLOOR_Y - VersusTuning.CURL_GLANCE_ABOVE_PX
	_box(heroes[0], 1)
	heroes[0].club_box.position.y += 10
	Sim.step(1)
	assert_eq(curled.curl, PlayerBase.CURL_CURLED, "a box from above glances off the curl")
	heroes[0].sim_pos.y = FLOOR_Y
	_box(heroes[0], 1)
	Sim.step(1)
	assert_eq(curled.curl, PlayerBase.CURL_BALL, "a front box from the side bats him")
	assert_eq(curled.xvel, PartyTuning.BAT_LINE_DRIVE_XVEL, "a line drive in the batter's facing")
	assert_eq(curled.yvel, PartyTuning.BAT_LINE_DRIVE_YVEL)
	assert_eq(curled.ball_batter, heroes[0])
	assert_eq(curled.hit_timer, 0, "batting costs him nothing by itself")
	assert_eq(Game.runs[0].bats, 1)


func test_a_front_box_deflects_a_rival_special() -> void:
	_arena(2, [100, 200])
	_box(heroes[0], 1)
	var axe: ProjectileBase = spawn(&"projectiles/hero_axe", Vector2i(123, FLOOR_Y - 4),
			{"from_hero": true, "power": 20, "xvel": -208, "yvel": 0, "owner": 1, "facing": "l"}) as ProjectileBase
	assert_not_null(axe)
	Sim.step(1)
	assert_eq(axe.owner_slot, 0, "now owned by the striker")
	assert_eq(axe.xvel, 208 + VersusTuning.DEFLECT_SPEEDUP, "reversed, 2 px/tick faster")
	assert_false(heroes[0].club_box_active, "the box is consumed")
	assert_eq(heroes[0].hit_timer, 0)


func test_a_thrown_special_spills_an_eighth() -> void:
	_arena(2, [100, 200])
	_give(heroes[1], 16)
	var axe: ProjectileBase = spawn(&"projectiles/hero_axe", Vector2i(200, FLOOR_Y - 8),
			{"from_hero": true, "power": 20, "xvel": 208, "yvel": 0, "owner": 0, "facing": "r"}) as ProjectileBase
	Sim.step(1)
	assert_true(not is_instance_valid(axe) or axe.spent, "the special is used up on the rival")
	assert_eq(referee.stack_of(1), 16 - (1 + 16 / VersusTuning.SPILL_THROWN_DIV))
	assert_eq(heroes[1].xvel, VersusTuning.HIT_XVEL, "knocked along the flight")
	assert_eq(heroes[0].hit_stop, 0, "a thrower far away gets no hit-stop")


# =================================================================================================================
# Stomps, bumps
# =================================================================================================================

func test_stomps_steal_by_the_ladder_and_squash() -> void:
	_arena(3, [100, 160, 220])
	_give(heroes[1], 6)
	_give(heroes[2], 6)
	var stomper: PlayerBase = heroes[0]
	stomper.teleport(Vector2i(160, FLOOR_Y - 30))
	stomper.yvel = 64
	stomper.grounded = false
	Sim.step(1)
	assert_eq(stomper.yvel, Tuning.BOUNCE_YVEL, "he bounces as on an enemy (UP not held)")
	assert_eq(referee.stack_of(0), 1, "the first stomp of a chain steals 1")
	assert_eq(referee.stack_of(1), 5)
	assert_eq(heroes[1].squash, VersusTuning.STOMP_SQUASH_TICKS - 1, "squashed 8 ticks")
	stomper.teleport(Vector2i(220, FLOOR_Y - 30))
	stomper.yvel = 64
	Sim.step(1)
	assert_eq(referee.stack_of(0), 3, "the second stomp without touching the ground steals 2")
	assert_eq(referee.stack_of(2), 4)
	assert_eq(Game.runs[0].best_chain, 2)
	assert_eq(Game.runs[0].stolen, 3)
	stomper.teleport(Vector2i(160, FLOOR_Y - 30))
	stomper.yvel = 64
	Sim.step(1)
	assert_eq(referee.stack_of(1), 5, "the squashed head is immune now: a free springboard")
	assert_eq(stomper.yvel, Tuning.BOUNCE_YVEL)
	stomper.teleport(Vector2i(100, FLOOR_Y))
	stomper.yvel = 0
	stomper.grounded = true
	Sim.step(1)
	assert_eq(referee._chain[0], 0, "the ground ends the chain")


func test_a_stomp_on_a_banking_hero_steals_double() -> void:
	_arena(2, [100, 160])
	_give(heroes[1], 6)
	var banker: PlayerBase = heroes[1]
	banker.state = Defs.HeroState.CROUCH
	Sim.step(1)
	referee.bank_from(banker)
	assert_true(referee.is_banking(banker.slot))
	var stomper: PlayerBase = heroes[0]
	stomper.teleport(Vector2i(160, FLOOR_Y - 30))
	stomper.yvel = 64
	stomper.grounded = false
	Sim.step(1)
	assert_eq(referee.stack_of(0), 2, "x2 on a banking hero")


func test_teammate_and_curled_heads_are_springboards() -> void:
	_arena(2, [100, 160])
	referee.teams = PackedInt32Array([1, 1, -1, -1])
	_give(heroes[1], 6)
	heroes[0].teleport(Vector2i(160, FLOOR_Y - 30))
	heroes[0].yvel = 64
	Sim.step(1)
	assert_eq(heroes[0].yvel, Tuning.BOUNCE_YVEL)
	assert_eq(referee.stack_of(1), 6, "a teammate's head is free")
	referee.teams = PackedInt32Array([-1, -1, -1, -1])
	heroes[1].curl = PlayerBase.CURL_CURLED
	heroes[0].teleport(Vector2i(160, FLOOR_Y - 30))
	heroes[0].yvel = 64
	Sim.step(1)
	assert_eq(referee.stack_of(1), 6, "a curled hero ignores stomps")
	assert_eq(heroes[1].squash, 0)


func test_body_bump_nudges_and_knocks() -> void:
	_arena(2, [100, 110])
	Sim.step(1)
	assert_eq(heroes[0].sim_pos.x, 99, "overlapping rivals move 1 px apart per tick")
	assert_eq(heroes[1].sim_pos.x, 111)
	heroes[0].xvel = 80
	heroes[1].xvel = -80
	Sim.step(1)
	assert_eq(heroes[0].xvel, -VersusTuning.BODY_KNOCK_XVEL, "running into each other knocks both back")
	assert_eq(heroes[1].xvel, VersusTuning.BODY_KNOCK_XVEL)
	assert_eq(heroes[0].yvel, VersusTuning.BODY_KNOCK_YVEL)
	assert_eq(heroes[0].hit_timer, 0, "no damage, no stun")


# =================================================================================================================
# Grub Stack
# =================================================================================================================

func test_food_stacks_by_class() -> void:
	_arena(2, [100, 250])
	var hero: PlayerBase = heroes[0]
	assert_eq(VersusReferee.food_units(&"items/food", 100), 1)
	assert_eq(VersusReferee.food_units(&"items/food", 700), 2)
	assert_eq(VersusReferee.food_units(&"items/treasure", 2000), 5)
	assert_eq(VersusReferee.food_units(&"items/giant_bonus", 60000), 10)
	assert_eq(VersusReferee.food_units(&"items/heart", 0), 0)
	spawn(&"items/food", hero.sim_pos, {"index": 0})
	Sim.step(1)
	assert_eq(referee.stack_of(0), 1, "small food")
	spawn(&"items/food", hero.sim_pos, {"index": 27})
	Sim.step(1)
	assert_eq(referee.stack_of(0), 3, "big food counts 2")
	spawn(&"items/treasure", hero.sim_pos, {"index": 0})
	Sim.step(1)
	assert_eq(referee.stack_of(0), 8)
	spawn(&"items/giant_bonus", hero.sim_pos, {"index": 0})
	Sim.step(1)
	assert_eq(referee.stack_of(0), 18)
	assert_eq(referee.stack_of(1), 0, "only the collector's head")
	assert_eq(Game.runs[0].food, 18)
	assert_eq(Game.runs[0].best_stack, 18)
	assert_eq(referee.leader_slot(), 0, "the crown on the tallest stack")
	_give(heroes[1], 18)
	assert_eq(referee.leader_slot(), -1, "no crown on a tie")


func test_a_stunned_hero_cannot_pick_up() -> void:
	_arena(2, [100, 250])
	heroes[0].hit_timer = VersusTuning.HURT_TIMER_TICKS
	spawn(&"items/food", heroes[0].sim_pos, {"index": 0})
	Sim.step(1)
	assert_eq(referee.stack_of(0), 0)
	assert_eq(count_items(&"items/food"), 1, "the piece lies where it was")


func test_the_cookpot_banks_one_unit_per_four_ticks_until_the_lids_close() -> void:
	_arena(2, [100, 250])
	var hero: PlayerBase = heroes[0]
	_give(hero, 5)
	hero.state = Defs.HeroState.CROUCH
	var banked: int = 0
	for i: int in VersusTuning.COOKPOT_BANK_TICKS * 2:
		Sim.step(1)
		if referee.bank_from(hero):
			banked += 1
	assert_eq(banked, 2)
	assert_eq(referee.banked_of(0), 2)
	assert_eq(referee.stack_of(0), 3)
	assert_eq(referee.score_of(0), 5, "final score = banked + stack")
	hero.state = Defs.HeroState.IDLE
	Sim.step(1)
	assert_false(referee.bank_from(hero), "standing up stops the banking")
	hero.state = Defs.HeroState.CROUCH
	referee._start_feast_rush()
	assert_true(referee.lids_closed())
	for i: int in VersusTuning.COOKPOT_BANK_TICKS:
		Sim.step(1)
		referee.bank_from(hero)
	assert_eq(referee.banked_of(0), 2, "no banking in the Feast Rush")


func test_two_versus_two_shares_one_pot() -> void:
	_arena(4)
	referee.teams = PackedInt32Array([1, 2, 1, 2])
	_give(heroes[2], 4)
	heroes[2].state = Defs.HeroState.CROUCH
	for i: int in VersusTuning.COOKPOT_BANK_TICKS:
		Sim.step(1)
		referee.bank_from(heroes[2])
	assert_eq(referee.banked_of(0), 1, "the team's shared pot")
	assert_eq(referee.banked_of(2), 1)
	assert_eq(referee.banked_of(1), 0)


func test_weight_caps_the_walk() -> void:
	_arena(2)
	assert_eq(referee.walk_cap_of(0), Tuning.WALK_CAP)
	_give(heroes[0], VersusTuning.STACK_HEAVY)
	Sim.step(1)
	assert_eq(referee.walk_cap_of(0), VersusTuning.STACK_HEAVY_WALK_CAP)
	_give(heroes[0], VersusTuning.STACK_HEAVIER - VersusTuning.STACK_HEAVY)
	Sim.step(1)
	assert_eq(referee.walk_cap_of(0), VersusTuning.STACK_HEAVIER_WALK_CAP)


func test_the_stack_guard_scales_every_spill() -> void:
	_arena(2)
	referee.guard_percent = PackedInt32Array([50, 150, 100, 100])
	_give(heroes[0], 20)
	_give(heroes[1], 20)
	assert_eq(referee.spill(heroes[0], 5), 2, "x0.5 rounded down")
	assert_eq(referee.spill(heroes[1], 5), 7, "x1.5 rounded down")
	assert_eq(referee.spill(heroes[0], 1), 1, "at least one")


func test_a_hazard_spills_everything_and_respawns_shielded_after_48_ticks() -> void:
	_arena(3, [40, 160, 280])
	_give(heroes[1], 11)
	heroes[0].teleport(Vector2i(135, FLOOR_Y))
	_box(heroes[0], 1)
	Sim.step(1)
	assert_eq(referee.stack_of(1), 8, "hit first: 3 off")
	var before: int = count_items()
	heroes[1].kill(&"liquid")
	Sim.step(1)
	assert_eq(referee.stack_of(1), 0, "a hazard spills everything")
	assert_eq(count_items() - before, 4, "half of the 8 bursts out (four 1s), the rest is lost")
	assert_eq(kos.size(), 1)
	assert_eq(kos[0][0], heroes[1])
	assert_eq(kos[0][1], heroes[0], "credited to the last hitter within 3 s")
	assert_eq(kos[0][2], &"liquid")
	assert_eq(Game.runs[0].kills, 1)
	Sim.step(VersusTuning.RESPAWN_TICKS - 1)
	assert_true(heroes[1].dead, "not yet")
	Sim.step(1)
	assert_false(heroes[1].dead, "back 48 ticks after the hazard")
	assert_eq(heroes[1].shield, VersusTuning.SPAWN_SHIELD_TICKS, "with the spawn shield")
	assert_eq(heroes[1].sim_pos.x, 40, "at the free spawn farthest from the rivals (280 is taken)")


func test_round_clock_feast_rush_gong_and_winner() -> void:
	_arena(2)
	var rush: Array[int] = []
	var on_rush: Callable = func(r: int) -> void: rush.append(r)
	Events.round_feast_rush_started.connect(on_rush)
	referee.round_total = VersusTuning.FEAST_RUSH_TICKS + 10
	_give(heroes[0], 3)
	_give(heroes[1], 5)
	Sim.step(9)
	assert_false(referee.in_feast_rush())
	assert_eq(referee.time_left_ticks(), VersusTuning.FEAST_RUSH_TICKS + 1)
	Sim.step(1)
	assert_true(referee.in_feast_rush(), "the last 15 s")
	assert_eq(rush, [0] as Array[int])
	Sim.step(VersusTuning.FEAST_RUSH_TICKS)
	Events.round_feast_rush_started.disconnect(on_rush)
	assert_eq(referee.phase, VersusReferee.PHASE_OVER, "the gong")
	assert_eq(ended.size(), 1)
	assert_eq(ended[0], PackedInt32Array([1]))
	assert_false(heroes[0].control_enabled, "frozen for the round loop")


func test_a_tie_drops_the_golden_drumstick() -> void:
	_arena(2, [100, 250])
	_give(heroes[0], 4)
	_give(heroes[1], 4)
	referee.end_round()
	assert_eq(referee.phase, VersusReferee.PHASE_GOLDEN)
	assert_eq(ended.size(), 0)
	var golden: CollectibleBase = referee._golden
	assert_not_null(golden)
	golden.teleport(heroes[1].sim_pos)
	golden.age = Tuning.DROPPED_ITEM_NO_PICKUP + 1
	Sim.step(1)
	assert_eq(ended.size(), 1)
	assert_eq(ended[0], PackedInt32Array([1]), "first to grab it wins")


func test_team_wins_count_both_members() -> void:
	_arena(4)
	referee.teams = PackedInt32Array([1, 2, 1, 2])
	_give(heroes[0], 3)
	_give(heroes[2], 3)
	_give(heroes[1], 5)
	referee.end_round()
	assert_eq(ended[0], PackedInt32Array([0, 2]), "6 against 5: the whole team wins")


# =================================================================================================================
# Last Caveman Standing (hearts)
# =================================================================================================================

func test_last_caveman_hits_cost_hearts_and_the_last_one_standing_wins() -> void:
	_arena(2, [100, 125])
	referee.mode = Defs.VersusMode.LAST_CAVEMAN
	referee.knockouts_final = true
	_box(heroes[0], 1, 100)
	Sim.step(1)
	assert_eq(Game.runs[1].hearts, 1, "a charged hit costs 2 hearts")
	assert_eq(count_items(&"items/bone"), 2 * VersusTuning.LCS_HEART_BONES, "each heart bursts into 6 bones")
	heroes[1].hit_timer = 0
	_box(heroes[0], 1)
	Sim.step(1)
	assert_true(heroes[1].dead, "0 hearts: out")
	Sim.step(1)
	assert_eq(ended.size(), 1)
	assert_eq(ended[0], PackedInt32Array([0]))


# =================================================================================================================
# Wrap edges
# =================================================================================================================

func test_lr_wrap_carries_a_hero_across_the_seam() -> void:
	_arena(2, [9, 200], "lr")
	var hero: PlayerBase = heroes[0]
	hero.xvel = -80
	Sim.step(1)
	assert_eq(hero.sim_pos.x, 9 - 5 + 304, "the refused step continues on the other side")
	hero.teleport(Vector2i(310, FLOOR_Y))
	hero.xvel = 80
	Sim.step(1)
	assert_eq(hero.sim_pos.x, 310 + 5 - 304)


func test_tb_wrap_carries_a_falling_hero_to_the_top() -> void:
	_arena(2, [100, 200], "tb")
	var hero: PlayerBase = heroes[0]
	hero.teleport(Vector2i(100, 178))
	hero.yvel = 64
	Sim.step(1)
	assert_eq(hero.sim_pos.y, 2, "his feet passed the view's bottom")


# =================================================================================================================
# Real heroes from scripted streams through a real arena file
# =================================================================================================================

func _real_arena(count: int) -> Level:
	Game.start_run(Defs.Difficulty.BEGINNER, Defs.GameMode.VERSUS, count)
	Flow.pending_level_id = &"test_world_arena_flat"
	var scene: PackedScene = load("res://scenes/world/level.tscn") as PackedScene
	var real: Level = scene.instantiate() as Level
	add_node(real)
	# The base viewport (640 x 360 art): the arena lock shows the authentic screen at the camera cell (0, 0).
	real.set_view_size(Vector2i(640, 360))
	return real


func test_scripted_match_on_the_flat_arena() -> void:
	var real: Level = _real_arena(2)
	var ref: VersusReferee = VersusArena.setup(real)
	assert_not_null(ref, "the arena file becomes a versus stage")
	referee = ref
	ref.start_round_now()
	var p1: PlayerBase = real.get_hero(0)
	var p2: PlayerBase = real.get_hero(1)
	assert_not_null(p2)
	assert_eq(p1.sim_pos, real.get_start_pos_for(0))
	# Let the spawn shields run out, P1 walks up to P2 (who looks away) and strikes.
	p2.teleport(Vector2i(p1.sim_pos.x + 40, p1.sim_pos.y))
	ref.add_food(p2, 10)
	var deaths: Array[String] = []
	var on_died: Callable = func(hero: PlayerBase, cause: StringName) -> void:
		deaths.append("P%d %s at %s" % [hero.slot + 1, cause, hero.sim_pos])
	Events.hero_died.connect(on_died)
	run_party_inputs([[VersusTuning.SPAWN_SHIELD_TICKS + 1, "|"], [3, "R|L"], [9, "F|"], [30, "|"]])
	Events.hero_died.disconnect(on_died)
	assert_true(ref.stack_of(1) < 10, "P1's strike knocked food off P2's head: %d left" % ref.stack_of(1))
	assert_eq(Game.runs[1].hearts, Tuning.ENERGY_START, "Grub Stack hits never cost hearts")
	assert_eq(deaths, [] as Array[String], "nobody died (view %s, camera cell %s, locked %s)" % [real.get_view_rect(),
			real.get_camera_cell(), real.get_camera_lock()])


func test_the_stack_tower_regroups_above_eight_pictures() -> void:
	assert_eq(VersusStackDisplay.tower_pictures(0), PackedInt32Array())
	assert_eq(VersusStackDisplay.tower_pictures(3), PackedInt32Array([1, 1, 1]), "one picture per unit")
	assert_eq(VersusStackDisplay.tower_pictures(VersusTuning.STACK_PICTURES_MAX).size(), VersusTuning.STACK_PICTURES_MAX)
	assert_eq(VersusStackDisplay.tower_pictures(9), PackedInt32Array([5, 1, 1, 1, 1]), "above 8: 5s and 1s")
	assert_eq(VersusStackDisplay.tower_pictures(23), PackedInt32Array([10, 10, 1, 1, 1]), "10s at the bottom")
	assert_eq(VersusReferee.weight_class(9), 0)
	assert_eq(VersusReferee.weight_class(10), 1)
	assert_eq(VersusReferee.weight_class(20), 2)


## A visible spot that counts its refills (objects' HittableBase.refill() is duck-typed by the referee).
class RefillSpot:
	extends HittableBase

	var refills: int = 0

	func refill() -> void:
		refills += 1
		opened = false


func test_skull_spills_all_and_grenade_makes_rivals_spill_five() -> void:
	_arena(3, [100, 200, 260])
	_give(heroes[0], 6)
	_give(heroes[1], 7)
	_give(heroes[2], 3)
	spawn(&"items/grenade", heroes[0].sim_pos)
	Sim.step(1)
	assert_eq(referee.stack_of(1), 2, "a rival spills 5")
	assert_eq(referee.stack_of(2), 0, "or all he has")
	assert_eq(referee.stack_of(0), 6, "not the one who picked it up")
	spawn(&"items/skull", heroes[0].sim_pos)
	Sim.step(1)
	assert_eq(referee.stack_of(0), 0, "the skull spills everything")


func test_emptied_spots_refill_after_fifteen_seconds() -> void:
	_arena(2)
	var spot: RefillSpot = RefillSpot.new()
	place(level, spot, Vector2i(160, FLOOR_Y + Tuning.TILE))
	spot.opened = true
	Sim.step(VersusTuning.SPOT_REFILL_TICKS)
	assert_eq(spot.refills, 0, "not yet")
	Sim.step(2)
	assert_eq(spot.refills, 1, "refilled 364 ticks after it was found empty")
	spot.opened = true
	referee._start_feast_rush()
	assert_eq(spot.refills, 2, "the Feast Rush refills every spot at once")
	assert_eq(count_items(&"items/giant_bonus"), 1, "and drops a second giant bonus")
