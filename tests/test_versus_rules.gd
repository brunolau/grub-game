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


# =================================================================================================================
# PLAN.md P2.4: the other launch modes, sudden deaths, crates, temporary specials, the feast, presets and variants
# =================================================================================================================

## Switch the running round to `mode` (round 0 begins again: heroes back at their spawns), the round running.
func _mode(mode: int) -> void:
	referee.mode = mode
	referee.begin_round(0)
	referee.start_round_now()
	_unshield()


## An arena (as _arena) whose referee first gets `rules`, then begins round 0 in `mode`.
func _arena_rules(count: int, mode: int, rules: VersusRules, xs: Array = [64, 128, 192, 256]) -> void:
	_arena(count, xs)
	referee.rules = rules
	_mode(mode)


## Feed `slot` a scripted flags stream from the next tick on (GameInput, as a human or a bot would).
func _script_slot(slot: int, flags: PackedInt32Array) -> void:
	var first_tick: int = Sim.tick + 1
	GameInput.set_scripted_slot(slot, func(tick: int) -> int:
		var index: int = tick - first_tick
		return flags[index] if index >= 0 and index < flags.size() else 0
	)


func _flags(value: int, count: int) -> PackedInt32Array:
	var result: PackedInt32Array = PackedInt32Array()
	result.resize(count)
	result.fill(value)
	return result


# --- Last Caveman Standing ------------------------------------------------------------------------------------------

func test_lcs_bones_heal_a_heart_up_to_three() -> void:
	_arena(2, [100, 250])
	_mode(Defs.VersusMode.LAST_CAVEMAN)
	var hero: PlayerBase = heroes[0]
	hero.run.hearts = 2
	for i: int in VersusTuning.LCS_HEART_BONES:
		spawn(&"items/bone", hero.sim_pos)
	Sim.step(1)
	assert_eq(hero.run.hearts, 3, "six bones heal a heart")
	for i: int in VersusTuning.LCS_HEART_BONES:
		spawn(&"items/bone", hero.sim_pos)
	Sim.step(1)
	assert_eq(hero.run.hearts, 3, "never more than 3")


func test_lcs_stock_respawns_until_the_last_life() -> void:
	var rules: VersusRules = VersusRules.new()
	rules.stock = true
	_arena_rules(2, Defs.VersusMode.LAST_CAVEMAN, rules, [60, 260])
	assert_false(referee.knockouts_final, "Stock: a knock-out is not final")
	assert_eq(referee.stocks_of(1), VersusTuning.LCS_STOCKS)
	for life: int in VersusTuning.LCS_STOCKS - 1:
		heroes[1].kill(&"liquid")
		Sim.step(VersusTuning.RESPAWN_TICKS + 1)
		assert_false(heroes[1].dead, "respawned (life %d)" % life)
		assert_eq(heroes[1].run.hearts, VersusTuning.LCS_HEARTS, "with full hearts")
		assert_eq(ended.size(), 0, "the round goes on")
		_unshield()
	assert_eq(referee.stocks_of(1), 1)
	heroes[1].kill(&"liquid")
	Sim.step(2)
	assert_true(referee.is_out(1), "the last life is gone: out")
	assert_eq(ended.size(), 1)
	assert_eq(ended[0], PackedInt32Array([0]), "the last caveman standing")


func test_lcs_an_out_player_rides_a_grudge_pterodactyl_and_his_rock_dazes() -> void:
	_arena(3, [100, 160, 220])
	_mode(Defs.VersusMode.LAST_CAVEMAN)
	var below: PlayerBase = heroes[1]   # x 160: no one-way ledge over him (FLAT_ROWS row 7)
	heroes[2].teleport(Vector2i(140, FLOOR_Y))
	heroes[2].kill(&"liquid")
	Sim.step(1)
	assert_true(referee.is_out(2))
	assert_eq(referee.grudge_pos(2), Vector2i(-1, -1), "not yet in the air")
	Sim.step(VersusTuning.RESPAWN_TICKS)
	var at: Vector2i = referee.grudge_pos(2)
	assert_eq(at, Vector2i(140, VersusGrudge.RIDE_Y), "a Grudge Pterodactyl along row 1 over where he fell")
	assert_true(referee.grudge_ready(2))
	# Right for 5 ticks: 4 px per tick, then a Strike: the 10-tick squawk, then the rock.
	_script_slot(2, _flags(Defs.IN_RIGHT, 5) + _flags(0, 1) + _flags(Defs.IN_FIRE, 1))
	Sim.step(7)
	assert_eq(referee.grudge_pos(2).x, 160, "steered 20 px to the right")
	assert_false(referee.grudge_ready(2), "squawking")
	var hearts: int = below.run.hearts
	var dazed_on: int = -1
	for t: int in 60:
		Sim.step(1)
		if referee.is_dazed(1):
			dazed_on = t
			break
	GameInput.clear_scripted()
	assert_true(dazed_on >= VersusTuning.GRUDGE_SQUAWK_TICKS - 1, "the rock falls after the squawk (%d)" % dazed_on)
	assert_eq(below.run.hearts, hearts, "a rock costs no heart")
	assert_eq(below.hit_timer, VersusTuning.HURT_TIMER_TICKS, "stunned")
	Sim.step(VersusTuning.GRUDGE_ROCK_DAZE_TICKS)
	assert_false(referee.is_dazed(1))
	assert_eq(below.hit_timer, 0, "12 ticks, then no immunity")
	assert_false(referee.grudge_ready(2), "one rock per 73 ticks")
	Sim.step(VersusTuning.GRUDGE_ROCK_PERIOD_TICKS)
	assert_true(referee.grudge_ready(2))


func test_lcs_sudden_death_starts_at_sixty_seconds() -> void:
	_arena(2, [100, 250])
	_mode(Defs.VersusMode.LAST_CAVEMAN)
	var started: Array[StringName] = []
	var on_start: Callable = func(_r: int, kind: StringName) -> void: started.append(kind)
	Events.round_sudden_death_started.connect(on_start)
	referee.round_ticks = VersusTuning.SUDDEN_DEATH_AT_TICKS - 2
	Sim.step(1)
	assert_false(referee.sudden_death.is_running())
	Sim.step(1)
	Events.round_sudden_death_started.disconnect(on_start)
	assert_true(referee.sudden_death.is_running(), "at 1 457 ticks")
	assert_eq(started, [VersusSuddenDeath.STAMPEDE] as Array[StringName], "the jungle's Stampede")


func test_one_bonk_and_big_bounce() -> void:
	var rules: VersusRules = VersusRules.new()
	rules.set_variant(VersusRules.ONE_BONK)
	rules.set_variant(VersusRules.BIG_BOUNCE)
	_arena_rules(3, Defs.VersusMode.LAST_CAVEMAN, rules, [100, 125, 220])
	_box(heroes[0], 1)
	Sim.step(1)
	assert_eq(Game.runs[1].hearts, 0, "One-Bonk: a hit costs every heart")
	assert_true(heroes[1].dead)
	var stomper: PlayerBase = heroes[0]
	stomper.teleport(Vector2i(220, FLOOR_Y - 30))
	stomper.yvel = 64
	stomper.grounded = false
	_script_slot(0, _flags(Defs.IN_UP, 2))
	Sim.step(1)
	GameInput.clear_scripted()
	assert_eq(stomper.yvel, VersusRules.BIG_BOUNCE_YVEL, "Big Bounce: Up gives -288")


# --- Hot Rock ---------------------------------------------------------------------------------------------------------

func test_hot_rock_first_pick_fuse_and_the_holders_speed() -> void:
	_arena(3, [60, 160, 260])
	var picks: Array[int] = []
	referee.ember_changed.connect(func(slot: int) -> void: picks.append(slot))
	_mode(Defs.VersusMode.HOT_ROCK)
	assert_true(referee.knockouts_final, "Hot Rock: a pop is final")
	assert_eq(referee.round_length(), 0, "no clock: last one standing")
	Sim.step(VersusTuning.HOT_ROCK_FIRST_PICK_TICKS - 1)
	assert_eq(referee.ember_holder(), -1, "nobody before 66 ticks")
	Sim.step(1)
	var holder: int = referee.ember_holder()
	assert_true(holder >= 0, "picked by Sim.rng 66 ticks after the gong")
	assert_eq(picks, [holder] as Array[int])
	assert_true(referee.hot_rock.fuse_total >= VersusTuning.HOT_ROCK_FUSE_MIN_TICKS
			and referee.hot_rock.fuse_total <= VersusTuning.HOT_ROCK_FUSE_MAX_TICKS, "a 12-20 s fuse")
	Sim.step(1)
	assert_eq(referee.walk_cap_of(holder), VersusTuning.HOT_ROCK_HOLDER_WALK_CAP, "the holder is the faster one")
	assert_eq(referee.walk_cap_of((holder + 1) % 3), Tuning.WALK_CAP)
	assert_eq(heroes[holder].walk_cap, VersusTuning.HOT_ROCK_HOLDER_WALK_CAP, "written to the hero")


func test_hot_rock_passes_on_a_touch_and_the_passer_cannot_get_it_back() -> void:
	_arena(2, [100, 250])
	_mode(Defs.VersusMode.HOT_ROCK)
	referee.hot_rock.pass_to(0, referee.round_ticks)
	referee.hot_rock.fuse_left = 400
	heroes[1].teleport(Vector2i(108, FLOOR_Y))
	Sim.step(1)
	assert_eq(referee.ember_holder(), 1, "a body touch passes it")
	assert_eq(Game.runs[0].passes, 1, "Hot Potato")
	assert_true(referee.ember_pass_immune(0) > 0, "the passer cannot get it back")
	heroes[0].teleport(heroes[1].sim_pos)
	Sim.step(1)
	assert_eq(referee.ember_holder(), 1, "still with P2 while P1's 44 ticks run")
	Sim.step(VersusTuning.HOT_ROCK_PASS_IMMUNE_TICKS)
	heroes[0].teleport(heroes[1].sim_pos)
	Sim.step(1)
	assert_eq(referee.ember_holder(), 0, "after 44 ticks it can come back")


func test_hot_rock_passes_on_a_hit_and_a_stomp_and_hits_cost_nothing() -> void:
	_arena(3, [100, 125, 250])
	_mode(Defs.VersusMode.HOT_ROCK)
	referee.hot_rock.pass_to(0, referee.round_ticks)
	referee.hot_rock.fuse_left = 400
	_box(heroes[0], 1)
	Sim.step(1)
	assert_eq(referee.ember_holder(), 1, "the holder's hit passes it to the victim")
	assert_eq(heroes[1].xvel, VersusTuning.HIT_XVEL, "a hit only knocks back")
	assert_eq(Game.runs[1].hearts, Tuning.ENERGY_START)
	var stomper: PlayerBase = heroes[2]
	stomper.teleport(Vector2i(heroes[1].sim_pos.x, FLOOR_Y - 30))
	heroes[1].hit_timer = 0
	stomper.yvel = 64
	stomper.grounded = false
	Sim.step(1)
	assert_eq(referee.ember_holder(), 2, "a stomp on the holder passes it to the stomper")


func test_hot_rock_the_fuse_pops_the_holder_and_the_last_one_standing_wins() -> void:
	_arena(3, [60, 160, 260])
	_mode(Defs.VersusMode.HOT_ROCK)
	referee.hot_rock.pass_to(1, referee.round_ticks)
	referee.hot_rock.fuse_left = 5
	Sim.step(4)
	assert_true(referee.ember_hurry(), "it bubbles faster at the end")
	assert_false(heroes[1].dead)
	Sim.step(1)
	assert_true(heroes[1].dead, "the holder pops")
	Sim.step(1)
	assert_true(referee.is_out(1), "and is out")
	assert_eq(kos.size(), 1)
	assert_eq(kos[0][2], &"hot_rock")
	assert_eq(referee.ember_holder(), -1)
	assert_eq(ended.size(), 0, "two still stand")
	Sim.step(VersusTuning.HOT_ROCK_REPICK_TICKS)
	var holder: int = referee.ember_holder()
	assert_true(holder == 0 or holder == 2, "66 ticks later a new holder among the rest")
	referee.hot_rock.fuse_left = 1
	Sim.step(2)
	assert_eq(ended.size(), 1)
	assert_eq(ended[0], PackedInt32Array([2 - holder]), "the last one standing wins")


# --- Clubball ---------------------------------------------------------------------------------------------------------

## A Clubball arena of two bare heroes and objects-B's coconut on its drop point (column 9, the floor), spawned
## before the referee as in a loaded arena (level entities tick before the heroes and the driver).
func _clubball(xs: Array = [64, 256]) -> Coconut:
	Game.start_run(Defs.Difficulty.BEGINNER, Defs.GameMode.VERSUS, 2)
	Game.begin_level(&"test_versus")
	make_recording_level(FLAT_ROWS)
	level.meta = {"kind": "arena", "players": 2, "modes": "clubball", "wrap": "none"}
	level.start_pos = Vector2i(int(xs[0]), FLOOR_Y)
	level.start_positions.clear()
	heroes.clear()
	for slot: int in Defs.MAX_PLAYERS:
		level.start_positions.append(Vector2i(int(xs[slot % xs.size()]), FLOOR_Y))
	var coconut: Coconut = spawn(&"objects/coconut", Vector2i(9 * 16 + 8, FLOOR_Y)) as Coconut
	for slot: int in 2:
		var hero: PlayerBase = PlayerBase.new()
		place(level, hero, Vector2i(int(xs[slot]), FLOOR_Y), {"slot": slot})
		hero.respawn_at(Vector2i(int(xs[slot]), FLOOR_Y))
		heroes.append(hero)
	referee = VersusArena.setup(level)
	referee.start_round_now()
	_unshield()
	return coconut


func test_clubball_sides_goal_pause_and_kickoff() -> void:
	var coconut: Coconut = _clubball()
	assert_not_null(coconut, "objects/coconut exists (objects-B)")
	if coconut == null:
		return
	assert_eq(referee.mode, Defs.VersusMode.CLUBBALL)
	assert_eq(referee.round_length(), VersusTuning.CLUBBALL_MATCH_TICKS, "3 minutes")
	assert_eq(referee.team_of(0), 1)
	assert_eq(referee.team_of(1), 2, "two sides even in 1v1")
	assert_eq(referee.goal_rect(1), Rect2i(0, 112, 16, 48), "team 1 defends the left mouth, 3 rows high")
	assert_eq(referee.ball(), coconut)
	var goals: Array[Array] = []
	referee.goal_scored.connect(func(team: int, a: int, b: int) -> void: goals.append([team, a, b]))
	heroes[0].teleport(Vector2i(150, FLOOR_Y))
	coconut.teleport(Vector2i(312, FLOOR_Y - 8))
	coconut.xvel = 0
	coconut.yvel = 0
	Sim.step(1)
	assert_eq(goals, [[1, 1, 0]] as Array[Array], "the centre in team 2's goal: team 1 scores")
	assert_eq(referee.score_of(0), 1)
	assert_false(coconut.in_play(), "out of play for the pause")
	Sim.step(VersusTuning.BALL_RESET_TICKS - 1)
	assert_eq(heroes[0].sim_pos.x, 150, "still the pause")
	Sim.step(1)
	assert_true(coconut.in_play(), "back at its drop point")
	assert_eq(heroes[0].sim_pos, Vector2i(64, FLOOR_Y), "kick-off: every hero at his side's spawn")
	assert_eq(heroes[0].shield, VersusTuning.SPAWN_SHIELD_TICKS - 1, "shielded (counting)")


func test_clubball_rallies_escalate_through_the_coconut() -> void:
	var coconut: Coconut = _clubball([120, 260])
	if coconut == null:
		return
	coconut.teleport(Vector2i(140, FLOOR_Y))
	heroes[0].teleport(Vector2i(118, FLOOR_Y))
	_box(heroes[0], 1)
	Sim.step(1)
	assert_eq(coconut.xvel, Coconut.DRIVE_XVEL, "a drive")
	coconut.teleport(Vector2i(140, FLOOR_Y))
	_box(heroes[0], 1)
	Sim.step(1)
	assert_eq(coconut.xvel, Coconut.DRIVE_XVEL + VersusTuning.RALLY_STEP, "a strike within 44 ticks adds 16")
	assert_eq(heroes[1].hit_timer, 0, "the shot hits nobody")


func test_clubball_first_to_five_and_the_golden_coconut() -> void:
	var coconut: Coconut = _clubball()
	if coconut == null:
		return
	referee.clubball.goals = PackedInt32Array([0, 4, 3])
	coconut.teleport(Vector2i(312, FLOOR_Y - 8))
	Sim.step(1)
	assert_eq(ended.size(), 1, "five goals end the game")
	assert_eq(ended[0], PackedInt32Array([0]), "team 1 (P1) wins")
	# A tie at the clock's end plays on with the golden coconut.
	coconut = _clubball()
	referee.round_ticks = VersusTuning.CLUBBALL_MATCH_TICKS - 1
	Sim.step(1)
	assert_eq(referee.phase, VersusReferee.PHASE_GOLDEN, "0 : 0 at the gong")
	assert_true(coconut.golden, "the golden coconut")
	assert_eq(referee.round_ticks_left(), -1, "the clock stops")
	coconut.teleport(Vector2i(8, FLOOR_Y - 8))
	Sim.step(1)
	assert_eq(ended.size(), 2, "the next goal wins")
	assert_eq(ended[1], PackedInt32Array([1]), "team 2 scored in team 1's goal")


# --- Themed sudden deaths --------------------------------------------------------------------------------------------

func test_every_sudden_death_is_telegraphed_ten_ticks_ahead() -> void:
	for theme: StringName in VersusSuddenDeath.THEMES:
		_arena(2, [40, 280])
		_mode(Defs.VersusMode.LAST_CAVEMAN)
		referee.start_sudden_death(theme)
		var armed: Array[String] = []
		for t: int in 260:
			Sim.step(1)
			for node: Node in get_tree().get_nodes_in_group(VersusReferee.ROUND_GROUP):
				var hazard: VersusHazard = node as VersusHazard
				if hazard != null and hazard.armed_tick == Sim.tick:
					armed.append("%s:%d" % [hazard.kind, hazard.armed_tick - hazard.warn_tick])
					assert_true(hazard.armed_tick - hazard.warn_tick >= VersusSuddenDeath.MIN_TELEGRAPH_TICKS,
							"%s: %s armed %d ticks after its telegraph" % [theme, hazard.kind,
							hazard.armed_tick - hazard.warn_tick])
		var threats: Array[Dictionary] = referee.sudden_death.threats
		assert_true(threats.size() >= 1, "%s: at least one threat in 260 ticks" % theme)
		for threat: Dictionary in threats:
			assert_true(int(threat["strike"]) - int(threat["warn"]) >= VersusSuddenDeath.MIN_TELEGRAPH_TICKS,
					"%s: %s telegraphed %d ticks ahead" % [theme, threat["what"],
					int(threat["strike"]) - int(threat["warn"])])
		if not VersusSuddenDeath.is_band(theme) and theme != VersusSuddenDeath.WHITEOUT:
			assert_true(armed.size() >= 1, "%s: a hazard turned deadly" % theme)


func test_stampede_spares_a_hero_during_the_dust_then_runs_him_down() -> void:
	_arena(2, [24, 280])
	_mode(Defs.VersusMode.LAST_CAVEMAN)
	referee.start_sudden_death(VersusSuddenDeath.STAMPEDE)
	Sim.step(1)
	var lane: Array[Rect2i] = referee.danger_rects(VersusTuning.STAMPEDE_DUST_TICKS)
	assert_eq(lane.size(), 1, "the charger's lane shows with its dust")
	Sim.step(VersusTuning.STAMPEDE_DUST_TICKS - 2)
	assert_false(heroes[0].dead, "safe during the 22 ticks of dust")
	Sim.step(12)
	assert_true(heroes[0].dead, "the charger runs along the floor")
	Sim.step(1)
	assert_eq(kos.size(), 1)
	assert_eq(kos[0][2], &"sudden_death")


func test_lava_rises_a_row_per_44_ticks() -> void:
	_arena(2, [100, 250])
	_mode(Defs.VersusMode.LAST_CAVEMAN)
	referee.start_sudden_death(VersusSuddenDeath.LAVA_RISE)
	var band: VersusSuddenDeath = referee.sudden_death
	assert_eq(band.band_top, 176, "the band starts under the floor")
	Sim.step(VersusSuddenDeath.BAND_RUMBLE_TICKS + 1)
	assert_eq(band.band_top, FLOOR_Y, "one row after the rumble: level with the floor")
	assert_false(heroes[0].dead)
	Sim.step(VersusTuning.LAVA_RISE_ROW_TICKS)
	assert_eq(band.band_top, FLOOR_Y - Tuning.TILE, "the next row 44 ticks later")
	assert_true(heroes[0].dead, "feet under a deadly band")


func test_syrup_flood_only_slows() -> void:
	_arena(2, [100, 250])
	_mode(Defs.VersusMode.GRUB_STACK)
	referee.start_sudden_death(VersusSuddenDeath.SYRUP_FLOOD)
	Sim.step(VersusSuddenDeath.BAND_RUMBLE_TICKS + 2 + VersusTuning.LAVA_RISE_ROW_TICKS)
	assert_eq(referee.sudden_death.band_top, FLOOR_Y - Tuning.TILE, "two rows up")
	assert_false(heroes[0].dead, "syrup never kills")
	assert_eq(referee.walk_cap_of(0), VersusSuddenDeath.SYRUP_WALK_CAP, "it slows to the tar caps")
	Sim.step(VersusTuning.LAVA_RISE_ROW_TICKS * 6)
	assert_eq(referee.sudden_death.band_top, VersusSuddenDeath.SYRUP_TOP_ROW * Tuning.TILE, "up to row 7, no higher")


func test_cave_in_fills_the_edge_columns() -> void:
	_arena(2, [100, 250])
	_mode(Defs.VersusMode.LAST_CAVEMAN)
	referee.start_sudden_death(VersusSuddenDeath.CAVE_IN)
	Sim.step(60)
	assert_eq(level.grid.get_char(0, 9), TileGrid.CH_SOLID_A, "the first block settled at the left edge")
	assert_eq(level.grid.get_char(19, 9), TileGrid.CH_SOLID_A, "the second at the right edge")


func test_whiteout_wind_grows_and_alternates() -> void:
	_arena(2, [100, 250])
	_mode(Defs.VersusMode.LAST_CAVEMAN)
	referee.start_sudden_death(VersusSuddenDeath.WHITEOUT)
	Sim.step(VersusSuddenDeath.WHITEOUT_WARN_TICKS - 1)
	assert_eq(level.wind, 0, "announced 22 ticks ahead")
	Sim.step(1)
	assert_eq(level.wind, VersusSuddenDeath.WHITEOUT_STEP)
	Sim.step(VersusTuning.WHITEOUT_STEP_TICKS)
	assert_eq(level.wind, -2 * VersusSuddenDeath.WHITEOUT_STEP, "it grows by 8 and turns")


func test_sudden_death_as_an_event_in_grub_stack() -> void:
	var rules: VersusRules = VersusRules.new()
	rules.sudden_death_event = true
	_arena_rules(2, Defs.VersusMode.GRUB_STACK, rules)
	assert_eq(referee.sudden_death_at, VersusTuning.STACK_ROUND_TICKS_2P - VersusTuning.FEAST_RUSH_TICKS,
			"a 60 s round: with the Feast Rush")
	_arena_rules(2, Defs.VersusMode.GRUB_STACK, VersusRules.new())
	assert_eq(referee.sudden_death_at, -1, "off unless toggled")


# --- Crates, temporary specials, the feast ---------------------------------------------------------------------------

func test_crate_contents_follow_the_mode_and_the_rules() -> void:
	Sim.start(7)
	var stack: String = VersusCrates.contents_for(Defs.VersusMode.GRUB_STACK, VersusRules.new())
	assert_true(stack.begins_with("food:"), "Grub Stack crates hold food: %s" % stack)
	assert_true(stack.contains("weapon:") and stack.contains("feast_piece:"))
	var lcs: String = VersusCrates.contents_for(Defs.VersusMode.LAST_CAVEMAN, VersusRules.new())
	assert_true(lcs.contains("heart") and not lcs.contains("food") and not lcs.contains("skull"), lcs)
	assert_eq(VersusCrates.contents_for(Defs.VersusMode.CLUBBALL, VersusRules.new()), "", "no crates in Clubball")
	var rain: VersusRules = VersusRules.new()
	rain.set_variant(VersusRules.AXE_RAIN)
	assert_eq(VersusCrates.contents_for(Defs.VersusMode.HOT_ROCK, rain), "weapon:axe", "Axe Rain")
	var club: VersusRules = VersusRules.new()
	club.club_only = true
	for i: int in 20:
		assert_false(VersusCrates.contents_for(Defs.VersusMode.GRUB_STACK, club).contains("weapon:"), "club only")
	var tokens: ItemContents = ItemContents.parse(stack)
	assert_eq(tokens.size(), stack.split(",").size(), "every token names an item")


func test_a_crate_lane_asks_the_referee_for_its_contents() -> void:
	_arena(2, [100, 250])
	_mode(Defs.VersusMode.LAST_CAVEMAN)
	var lane: SimEntity = spawn(&"objects/crate_lane", Vector2i(2 * 16 + 8, 32), {"rect": "2,1,16,9"}) as SimEntity
	assert_not_null(lane, "objects/crate_lane exists (objects-B)")
	if lane == null:
		return
	Sim.step(VersusTuning.CRATE_PERIOD_TICKS)
	var contents: String = str(lane.get(&"contents"))
	assert_true(contents.contains("heart") and not contents.contains("food"),
			"the lane holds what the referee answered for LCS: %s" % contents)


func test_temporary_specials_run_out_after_their_throws() -> void:
	_arena(2, [100, 250])
	var hero: PlayerBase = heroes[0]
	spawn(&"items/weapon", hero.sim_pos, {"kind": "boomerang", "temp": true})
	Sim.step(1)
	assert_eq(hero.run.special(), Defs.Weapon.BOOMERANG)
	assert_eq(referee.throws_left(0), VersusTuning.SPECIAL_THROWS[Defs.Weapon.BOOMERANG], "a swirling axe: 2 throws")
	for i: int in 2:
		spawn(&"projectiles/hero_boomerang", Vector2i(100, 120), {"from_hero": true, "power": 20, "xvel": 0,
				"yvel": 0, "owner": 0})
		Sim.step(1)
	assert_eq(referee.throws_left(0), 0)
	assert_eq(hero.run.weapon, Defs.Weapon.CLUB, "gone after the last throw")
	assert_eq(hero.run.belt, PlayerRun.BELT_EMPTY)
	spawn(&"items/weapon", hero.sim_pos, {"kind": "hammer", "temp": true})
	Sim.step(1)
	assert_eq(hero.run.special(), Defs.Weapon.HAMMER)
	hero.kill(&"liquid")
	Sim.step(1)
	assert_eq(hero.run.special(), PlayerRun.BELT_EMPTY, "the hammer goes on a knock-out")
	Sim.step(VersusTuning.RESPAWN_TICKS)
	spawn(&"items/weapon", hero.sim_pos, {"kind": "axe", "temp": true})
	Sim.step(1)
	referee.end_round(false)
	assert_eq(hero.run.special(), PlayerRun.BELT_EMPTY, "and every special at the round end")


func test_the_versus_feast_is_each_heros_own() -> void:
	_arena(2, [100, 250])
	var feaster: PlayerBase = heroes[0]
	for index: int in 2:
		spawn(&"items/feast_piece", feaster.sim_pos, {"index": index})
		Sim.step(1)
	spawn(&"items/feast_piece", heroes[1].sim_pos, {"index": 2})
	Sim.step(1)
	assert_eq(feaster.feast, 0, "a spoon in another hand does not complete his kit")
	assert_eq(referee.cutlery_of(0), 3)
	assert_eq(referee.cutlery_of(1), 4)
	assert_eq(Game.feast_kit, 0, "the 1.0 team kit is not used in versus")
	# A hit drops the victim's cutlery.
	heroes[1].teleport(Vector2i(250, FLOOR_Y))
	heroes[0].teleport(Vector2i(225, FLOOR_Y))
	_box(heroes[0], 1)
	Sim.step(1)
	assert_eq(referee.cutlery_of(1), 0, "dropped on a hit")
	assert_eq(count_items(&"items/feast_piece"), 1)
	heroes[1].hit_timer = 0
	spawn(&"items/feast_piece", feaster.sim_pos, {"index": 2})
	Sim.step(1)
	assert_eq(feaster.feast, VersusTuning.FEAST_TICKS - 1, "his third piece: 8 s of feast")
	_give(heroes[1], 9)
	heroes[1].teleport(Vector2i(feaster.sim_pos.x + 10, FLOOR_Y))
	Sim.step(1)
	assert_eq(referee.stack_of(1), 9 - VersusTuning.FEAST_TOUCH_SPILL, "a feaster's touch knocks 3 off")
	_box(heroes[1], -1)
	heroes[1].hit_timer = 0
	_give(heroes[0], 5)
	Sim.step(1)
	assert_eq(referee.stack_of(0), 5, "hits cannot touch the feaster")


# --- Presets, variants, handicap, Party Mix --------------------------------------------------------------------------

func test_rules_from_a_match_presets_variants_and_auto_handicap() -> void:
	var versus_match: VersusMatch = VersusMatch.new()
	versus_match.seat_bot(Defs.BotLevel.HUNTER)
	versus_match.seat_bot(Defs.BotLevel.HUNTER)
	versus_match.preset = VersusMatch.Preset.CLASSIC
	var classic: VersusRules = VersusRules.from_match(versus_match, Defs.VersusMode.GRUB_STACK)
	assert_true(classic.club_only, "Classic: club only")
	assert_eq(classic.crate_period, 0, "no crates")
	versus_match.preset = VersusMatch.Preset.FEAST
	versus_match.variants = PackedStringArray(["gusty", "not_a_variant"])
	var feast: VersusRules = VersusRules.from_match(versus_match, Defs.VersusMode.GRUB_STACK)
	assert_eq(feast.crate_period, VersusTuning.CRATE_PERIOD_TICKS)
	assert_true(feast.has(VersusRules.GUSTY))
	assert_eq(feast.variants.size(), 1, "unknown names are left out")
	versus_match.preset = VersusMatch.Preset.MAYHEM
	versus_match.variants = PackedStringArray()
	var mayhem: VersusRules = VersusRules.from_match(versus_match, Defs.VersusMode.GRUB_STACK)
	assert_eq(mayhem.crate_period, VersusTuning.MAYHEM_CRATE_PERIOD_TICKS)
	assert_eq(mayhem.variants.size(), 1, "Mayhem: a random variant per round")
	assert_eq(VersusRules.from_match(versus_match, Defs.VersusMode.GRUB_STACK).variants, mayhem.variants,
			"drawn from the round seed: the same every time")
	var clubball: VersusRules = VersusRules.from_match(versus_match, Defs.VersusMode.CLUBBALL)
	assert_eq(clubball.crate_period, 0, "Clubball has no crates")
	assert_false(clubball.has(VersusRules.GIANT_RAIN) or clubball.has(VersusRules.HAMMER_TIME))
	versus_match.round_wins = PackedInt32Array([2, 0, 0, 0])
	versus_match.get_seat(1).auto_handicap = true
	versus_match.preset = VersusMatch.Preset.FEAST
	var auto: VersusRules = VersusRules.from_match(versus_match, Defs.VersusMode.GRUB_STACK)
	assert_eq(auto.leaf_shield, PackedByteArray([0, 1, 0, 0]), "Auto: two rounds behind gets a leaf shield")


func test_the_leaf_shield_absorbs_one_hit() -> void:
	var rules: VersusRules = VersusRules.new()
	rules.leaf_shield = PackedByteArray([0, 1, 0, 0])
	_arena_rules(2, Defs.VersusMode.GRUB_STACK, rules, [100, 125])
	_give(heroes[1], 10)
	assert_true(referee.has_leaf(1))
	_box(heroes[0], 1)
	Sim.step(1)
	assert_eq(referee.stack_of(1), 10, "the leaf takes the hit")
	assert_false(referee.has_leaf(1))
	assert_eq(heroes[1].hit_timer, 0)
	heroes[0].teleport(Vector2i(100, FLOOR_Y))
	heroes[1].teleport(Vector2i(125, FLOOR_Y))
	_box(heroes[0], 1)
	Sim.step(1)
	assert_eq(referee.stack_of(1), 7, "the next one counts")


func test_hammer_time_spear_party_slippery_gusty_lights_out_and_giant_rain() -> void:
	var rules: VersusRules = VersusRules.new()
	for variant: StringName in [VersusRules.HAMMER_TIME, VersusRules.SPEAR_PARTY, VersusRules.SLIPPERY,
			VersusRules.GUSTY, VersusRules.LIGHTS_OUT, VersusRules.GIANT_RAIN]:
		rules.set_variant(variant)
	_arena_rules(2, Defs.VersusMode.GRUB_STACK, rules, [100, 250])
	var hero: PlayerBase = heroes[0]
	assert_eq(hero.run.weapon, Defs.Weapon.HAMMER, "Hammer Time: the hammer in the hand")
	assert_eq(hero.run.belt, Defs.Weapon.SPEAR, "Spear Party: a spear on the belt")
	assert_eq(referee.throws_left(0), -1, "that never runs out")
	assert_true(level.dark, "Lights Out")
	Sim.step(1)
	assert_eq(hero.ice, VersusRules.SLIPPERY_ICE, "Slippery: every floor is ice 2")
	assert_eq(level.wind, VersusRules.GUSTY_WIND, "Gusty")
	Sim.step(VersusRules.GUSTY_PERIOD_TICKS)
	assert_eq(level.wind, -VersusRules.GUSTY_WIND, "alternating every 66 ticks")
	var before: int = count_items(&"items/giant_bonus")
	Sim.step(VersusRules.GIANT_RAIN_PERIOD_TICKS - VersusRules.GUSTY_PERIOD_TICKS - 1)
	assert_eq(count_items(&"items/giant_bonus"), before + 1, "Giant Rain: a giant bonus every 364 ticks")


func test_party_mix_mode_and_match_rules_reach_the_referee() -> void:
	var versus_match: VersusMatch = VersusMatch.new()
	versus_match.seat_bot(Defs.BotLevel.HUNTER)
	versus_match.seat_bot(Defs.BotLevel.HUNTER)
	versus_match.arena = VersusMatch.ARENA_PARTY_MIX
	versus_match.stock = true
	versus_match.begin_match(5)
	versus_match.round_mode = Defs.VersusMode.LAST_CAVEMAN
	Game.versus_match = versus_match
	_arena(2, [100, 250])
	Game.versus_match = null
	assert_eq(referee.mode, Defs.VersusMode.LAST_CAVEMAN, "the round's mode as Party Mix picked it")
	assert_true(referee.rules.stock, "the match's Stock option")
	assert_false(referee.knockouts_final)


# --- Dazes --------------------------------------------------------------------------------------------------------

func test_a_daze_stuns_twelve_ticks_and_leaves_no_immunity() -> void:
	_arena(2, [100, 125])
	_give(heroes[1], 10)
	referee.daze(heroes[1], VersusTuning.STUN_TICKS)
	spawn(&"items/food", heroes[1].sim_pos, {"index": 0})
	Sim.step(1)
	assert_eq(referee.stack_of(1), 10, "no pick-ups while dazed")
	assert_true(referee.is_pvp_immune(heroes[1]), "not hit while stunned")
	Sim.step(VersusTuning.STUN_TICKS - 1)
	assert_eq(heroes[1].hit_timer, 0, "no immunity after a daze")
	_box(heroes[0], 1)
	Sim.step(1)
	assert_true(referee.stack_of(1) < 11, "hittable at once")


func test_a_falling_giant_bonus_bonks_the_head_it_lands_on() -> void:
	_arena(2, [100, 250])
	var giant: Node = spawn(&"items/giant_bonus", Vector2i(100, FLOOR_Y - 34), {"index": 0, "dropped": true,
			"xvel": 0, "yvel": 64})
	assert_not_null(giant)
	Sim.step(1)
	assert_true(referee.is_dazed(0), "bonked")
	assert_eq(Game.runs[0].bonks, 1, "Head Case")


# --- Scripted multi-stream matches on the flat arena -----------------------------------------------------------------

## The flat arena file with real heroes, a match of `mode` in Game.versus_match (Party Mix style round_mode).
func _real_match(count: int, mode: int) -> Level:
	var versus_match: VersusMatch = VersusMatch.new()
	for i: int in count:
		versus_match.seat_bot(Defs.BotLevel.HUNTER)
	versus_match.begin_match(3)
	versus_match.round_mode = mode
	Game.versus_match = versus_match
	var real: Level = _real_arena(count)
	Game.versus_match = null
	referee = VersusArena.setup(real)
	referee.start_round_now()
	return real


func test_scripted_last_caveman_match_strikes_cost_hearts() -> void:
	var real: Level = _real_match(2, Defs.VersusMode.LAST_CAVEMAN)
	var p1: PlayerBase = real.get_hero(0)
	var p2: PlayerBase = real.get_hero(1)
	assert_eq(referee.mode, Defs.VersusMode.LAST_CAVEMAN)
	p2.teleport(Vector2i(p1.sim_pos.x + 40, p1.sim_pos.y))
	# The shields run out, P1 walks up to P2 and strikes; P2 stands still (immune 30 ticks after each hit).
	var runs: Array = [[VersusTuning.SPAWN_SHIELD_TICKS + 1, "|"], [3, "R|"]]
	for i: int in 3:
		runs.append([1, "F|"])
		runs.append([VersusTuning.HURT_TIMER_TICKS + 4, "|"])
		runs.append([2, "R|"])
	run_party_inputs(runs)
	assert_true(Game.runs[1].hearts < VersusTuning.LCS_HEARTS, "P1's strikes cost P2 hearts: %d left"
			% Game.runs[1].hearts)
	assert_eq(Game.runs[0].hearts, VersusTuning.LCS_HEARTS, "P1 untouched")


func test_scripted_hot_rock_match_a_walk_passes_the_ember() -> void:
	var real: Level = _real_match(2, Defs.VersusMode.HOT_ROCK)
	var p1: PlayerBase = real.get_hero(0)
	var p2: PlayerBase = real.get_hero(1)
	p2.teleport(Vector2i(p1.sim_pos.x + 48, p1.sim_pos.y))
	run_party_inputs([[VersusTuning.HOT_ROCK_FIRST_PICK_TICKS, "|"]])
	var holder: int = referee.ember_holder()
	assert_true(holder >= 0, "the first pick")
	var walk: String = "R|" if holder == 0 else "|L"
	run_party_inputs([[20, walk]])
	assert_eq(referee.ember_holder(), 1 - holder, "the holder walked into his rival: passed")
