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
	heroes[0].grounded = false
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


func test_a_stomp_is_a_landing() -> void:
	# G15 (PHYSICS.md C.14): a hero standing on the one-way bridge (row 7, feet y 112) never stomps a rival whose head
	# rises into his feet from below (a pogo under the bridge) - no steal, no bounce, no squash.
	_arena(2, [100, 160])
	_give(heroes[1], 6)
	var stander: PlayerBase = heroes[0]
	var riser: PlayerBase = heroes[1]
	stander.teleport(Vector2i(72, 112))
	stander.grounded = true
	stander.yvel = 0
	Sim.step(1)
	riser.teleport(Vector2i(72, 112 + riser.box_h - 4))
	riser.yvel = -96
	riser.grounded = false
	Sim.step(1)
	assert_eq(referee.stack_of(1), 6, "no steal from a head that rose into standing feet")
	assert_eq(referee.stack_of(0), 0)
	assert_eq(stander.yvel, 0, "no bounce")
	assert_eq(riser.squash, 0, "no squash")
	# The same rival jumped on from above: the stomp as before.
	stander.teleport(Vector2i(160, FLOOR_Y - 30))
	stander.grounded = false
	stander.yvel = 64
	riser.teleport(Vector2i(160, FLOOR_Y))
	riser.yvel = 0
	riser.grounded = true
	Sim.step(1)
	assert_eq(stander.yvel, Tuning.BOUNCE_YVEL, "a landing on the head bounces")
	assert_eq(referee.stack_of(0), 1, "and steals")


func test_a_hero_squeezed_out_of_the_arenas_side_is_knocked_out() -> void:
	# Phase 4, found by the versus soak (rules=mix: Echo Hollow, Grub Stack with the sudden-death event, seed 4001
	# round 0): a Cave-in block settled at the arena's edge beside a hero; one step into its column and the 1.0
	# collision slid him through it and out of the map, 10 px beyond the edge, where the x commit rule refuses every
	# step back - on a top-bottom wrap arena he fell through the seam for the rest of the round. Nobody stays outside
	# the arena's sides: the arena that squeezed him out has crushed him.
	_arena(2, [100, 250])
	_give(heroes[1], 6)
	var view: Rect2i = VersusArena.view_rect()
	heroes[1].teleport(Vector2i(-10, FLOOR_Y))
	Sim.step(1)
	assert_true(heroes[1].dead, "left of the arena: knocked out")
	assert_eq(kos.size(), 1, "one knock-out")
	if kos.size() == 1:
		assert_eq(kos[0][0], heroes[1])
		assert_eq(kos[0][2], VersusReferee.CAUSE_SQUEEZED, "the Cave-in's crush")
	assert_eq(referee.stack_of(1), 0, "a hazard's knock-out: the stack is spilled")
	Sim.step(VersusTuning.RESPAWN_TICKS + 1)
	assert_false(heroes[1].dead, "Grub Stack: back after the respawn time")
	assert_true(view.has_point(heroes[1].sim_pos - Vector2i(0, 1)), "inside the arena (%s)" % heroes[1].sim_pos)
	# Inside the view nothing happens - also in the 8 px at the edge that no walker reaches by himself.
	heroes[0].teleport(Vector2i(3, FLOOR_Y))
	Sim.step(1)
	assert_false(heroes[0].dead, "x 3 is inside the arena")
	heroes[0].teleport(Vector2i(view.end.x - 1, FLOOR_Y))
	Sim.step(1)
	assert_false(heroes[0].dead, "so is the last pixel column")
	heroes[0].teleport(Vector2i(view.end.x + 10, FLOOR_Y))
	Sim.step(1)
	assert_true(heroes[0].dead, "right of the arena: knocked out too")
	# Last Caveman Standing: a hazard's knock-out is final - and the other one has won.
	_mode(Defs.VersusMode.LAST_CAVEMAN)
	ended.clear()
	heroes[1].teleport(Vector2i(-10, FLOOR_Y))
	Sim.step(2)
	assert_true(referee.is_out(1), "out of the round")
	assert_eq(ended.size(), 1, "the round is over")
	if ended.size() == 1:
		assert_eq(ended[0], PackedInt32Array([0]), "the last caveman standing")


func test_an_arena_that_wraps_left_right_has_no_side_to_be_squeezed_out_of() -> void:
	_arena(2, [100, 250], "lr")
	heroes[1].teleport(Vector2i(-10, FLOOR_Y))
	Sim.step(2)
	assert_false(heroes[1].dead, "Totem Ring's sides are a seam, not an edge")
	assert_eq(kos.size(), 0)


func test_a_pair_ramming_each_other_is_knocked_once_not_lifted() -> void:
	# core-B's floating pair: both hold toward each other; after a knock they are in the air and only nudged apart
	# until they land - they never rise off the screen.
	_arena(2, [100, 112])
	var a: PlayerBase = heroes[0]
	var b: PlayerBase = heroes[1]
	a.xvel = 80
	b.xvel = -80
	Sim.step(1)
	assert_eq(a.yvel, VersusTuning.BODY_KNOCK_YVEL, "the knock")
	var gap: int = b.sim_pos.x - a.sim_pos.x
	assert_true(gap > 12, "nudged apart on the knock tick too (%d px)" % gap)
	a.xvel = 80
	b.xvel = -80
	a.yvel = 32
	Sim.step(1)
	assert_eq(a.yvel, 32, "airborne from the knock: no second knock")
	assert_eq(b.xvel, -80)


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


# --- The hard cap of a Last Caveman Standing round (ruling R8) ---------------------------------------------------------

## Round `mode` on the flat arena with a sudden death that never kills (the syrup flood only slows), so that heroes
## who stand still outlast it - the round only the hard cap ends.
func _lcs_no_kill(count: int, xs: Array, rules: VersusRules = null) -> void:
	_arena(count, xs)
	level.meta["sudden"] = String(VersusSuddenDeath.SYRUP_FLOOD)
	if rules != null:
		referee.rules = rules
	_mode(Defs.VersusMode.LAST_CAVEMAN)


## Jump the running round to its sudden death (the cap is armed on that tick).
func _to_sudden_death() -> void:
	referee.round_ticks = VersusTuning.SUDDEN_DEATH_AT_TICKS - 1
	Sim.step(1)
	_unshield()


func test_lcs_hard_cap_ends_the_round_sixty_seconds_into_the_sudden_death() -> void:
	_lcs_no_kill(2, [100, 250])
	assert_eq(VersusTuning.SUDDEN_DEATH_CAP_TICKS, Tuning.seconds_to_ticks(60.0), "60 s by default")
	assert_eq(referee.cap_at, -1, "no cap before the sudden death")
	assert_eq(referee.cap_ticks_left(), -1)
	assert_eq(referee.round_length(), 0, "and no clock on the HUD")
	assert_eq(referee.round_ticks_left(), -1)
	_to_sudden_death()
	assert_true(referee.sudden_death.is_running(), "the sudden death started")
	assert_eq(referee.cap_at, VersusTuning.SUDDEN_DEATH_AT_TICKS + VersusTuning.SUDDEN_DEATH_CAP_TICKS,
			"the cap is armed with it")
	assert_eq(referee.round_length(), VersusTuning.SUDDEN_DEATH_CAP_TICKS, "the HUD's sundial is the cap's from here")
	assert_eq(referee.round_ticks_left(), VersusTuning.SUDDEN_DEATH_CAP_TICKS, "counting the last 60 s down")
	assert_eq(referee.time_left_ticks(), -1, "the round clock the bots read is not it")
	referee.start_sudden_death()
	assert_eq(referee.cap_at, VersusTuning.SUDDEN_DEATH_AT_TICKS + VersusTuning.SUDDEN_DEATH_CAP_TICKS,
			"a second start does not move the cap")
	Sim.step(VersusTuning.SUDDEN_DEATH_CAP_TICKS - 1)
	assert_eq(ended.size(), 0, "one tick before the cap both still stand")
	assert_eq(referee.round_ticks_left(), 1)
	Sim.step(1)
	assert_eq(referee.phase, VersusReferee.PHASE_OVER, "the cap ends the round")
	assert_eq(referee.round_ticks, VersusTuning.SUDDEN_DEATH_AT_TICKS + VersusTuning.SUDDEN_DEATH_CAP_TICKS)
	assert_eq(ended.size(), 1)
	assert_eq(ended[0], PackedInt32Array(), "nobody was hurt: a draw")
	assert_eq(referee.round_ticks_left(), -1, "no clock after the gong")
	assert_false(referee.sudden_death.is_running(), "the sudden death stops with the round")
	# The next round starts without a cap.
	referee.begin_round(1)
	assert_eq(referee.cap_at, -1)
	assert_eq(referee.round_length(), 0)


func test_lcs_at_the_cap_the_hero_with_fewer_hurts_wins() -> void:
	_lcs_no_kill(2, [100, 125])
	# P2 has a handicap card of 5 hearts: he may take a hurt and still show more hearts than P1 - the cap counts what
	# a hero TOOK this round, not what he has left.
	referee.start_hearts = PackedInt32Array([3, 5, 3, 3])
	_mode(Defs.VersusMode.LAST_CAVEMAN)
	_to_sudden_death()
	_box(heroes[0], 1)
	Sim.step(1)
	assert_eq(referee.hurts_of(1), 1, "P1's hit: one hurt for P2")
	assert_eq(referee.hurts_of(0), 0)
	assert_eq(Game.runs[1].hearts, 4, "P2 still has more hearts than P1")
	assert_eq(referee.cap_winners(), PackedInt32Array([0]), "fewer hurts taken")
	referee.round_ticks = referee.cap_at - 1
	Sim.step(1)
	assert_eq(ended.size(), 1, "the cap")
	assert_eq(ended[0], PackedInt32Array([0]), "P1 took fewer hurts: his round")


func test_lcs_cap_counts_a_charged_hit_twice_and_healing_takes_no_hurt_back() -> void:
	_lcs_no_kill(3, [100, 125, 250])
	_to_sudden_death()
	_box(heroes[0], 1, 100)
	Sim.step(1)
	assert_eq(referee.hurts_of(1), VersusTuning.LCS_CHARGED_HEARTS, "a charged hit is two hurts")
	heroes[1].run.hearts = VersusTuning.LCS_HEARTS
	assert_eq(referee.hurts_of(1), 2, "six bones heal the heart, not the hurt")
	referee._lose_hearts(heroes[0], 1, null, &"hit")
	referee._lose_hearts(heroes[2], 1, null, &"hit")
	assert_eq(referee.cap_winners(), PackedInt32Array(), "P1 and P3 took one hurt each, P2 two: the best two tie - a draw")
	referee._lose_hearts(heroes[2], 1, null, &"hit")
	assert_eq(referee.cap_winners(), PackedInt32Array([0]), "P1 alone took the fewest")
	referee.round_ticks = referee.cap_at - 1
	Sim.step(1)
	assert_eq(ended.size(), 1)
	assert_eq(ended[0], PackedInt32Array([0]))


func test_lcs_cap_in_teams_and_with_stock() -> void:
	# 2v2: the side with more heroes standing, then the side that took fewer hurts (summed), both members winning.
	_lcs_no_kill(4, [60, 120, 200, 260])
	referee.teams = PackedInt32Array([1, 1, 2, 2])
	_to_sudden_death()
	referee._lose_hearts(heroes[0], 2, null, &"hit")
	referee._lose_hearts(heroes[2], 1, null, &"hit")
	assert_eq(referee.cap_winners(), PackedInt32Array([2, 3]), "team 2 took one hurt, team 1 two")
	heroes[3].kill(&"liquid")
	Sim.step(2)
	assert_true(referee.is_out(3), "a hazard took P4 out")
	assert_eq(ended.size(), 0, "one of team 2 still stands")
	assert_eq(referee.cap_winners(), PackedInt32Array([0, 1]), "two standing beat one, whatever the hurts")
	referee.round_ticks = referee.cap_at - 1
	Sim.step(1)
	assert_eq(ended.size(), 1)
	assert_eq(ended[0], PackedInt32Array([0, 1]), "the whole team wins the round")


func test_lcs_cap_with_stock_counts_lives_before_hurts() -> void:
	var rules: VersusRules = VersusRules.new()
	rules.stock = true
	_lcs_no_kill(2, [60, 260], rules)
	_to_sudden_death()
	referee._lose_hearts(heroes[0], 2, null, &"hit")
	assert_eq(referee.cap_winners(), PackedInt32Array([1]), "the same lives: fewer hurts")
	heroes[1].kill(&"liquid")
	Sim.step(VersusTuning.RESPAWN_TICKS + 1)
	assert_false(heroes[1].dead, "Stock: P2 is back")
	assert_eq(referee.stocks_of(1), VersusTuning.LCS_STOCKS - 1)
	assert_eq(referee.cap_winners(), PackedInt32Array([0]), "a hazard took a life without a hurt: more lives win")


func test_no_hard_cap_outside_last_caveman_standing() -> void:
	_arena(3, [60, 160, 260])
	_mode(Defs.VersusMode.HOT_ROCK)
	referee.start_sudden_death()
	assert_eq(referee.cap_at, -1, "Hot Rock ends by its fuse")
	assert_eq(referee.round_length(), 0)
	var rules: VersusRules = VersusRules.new()
	rules.sudden_death_event = true
	referee.rules = rules
	_mode(Defs.VersusMode.GRUB_STACK)
	referee.start_sudden_death()
	assert_eq(referee.cap_at, -1, "Grub Stack ends by its clock")
	assert_eq(referee.round_length(), VersusTuning.stack_round_ticks(3), "whose sundial stays its own")


# --- "TIME!": the banner of a round the hard cap ended (phase 4) ----------------------------------------------------------

func test_only_the_gong_of_the_hard_cap_is_ended_by_cap() -> void:
	_lcs_no_kill(2, [100, 250])
	var cap: int = VersusTuning.SUDDEN_DEATH_AT_TICKS + VersusTuning.SUDDEN_DEATH_CAP_TICKS
	assert_false(referee.ended_by_cap(), "a running round")
	_to_sudden_death()
	Sim.step(VersusTuning.SUDDEN_DEATH_CAP_TICKS - 1)
	assert_false(referee.ended_by_cap(), "one tick before the cap")
	Sim.step(1)
	assert_eq(referee.round_ticks, cap)
	assert_true(referee.ended_by_cap(), "the cap's gong")
	Sim.step(3)
	assert_true(referee.ended_by_cap(), "and it stays said after the gong")
	# The next round starts clean; the last one standing on the cap's OWN tick is a win by standing (that rule is
	# asked first, G78): no "TIME!".
	_mode(Defs.VersusMode.LAST_CAVEMAN)
	assert_false(referee.ended_by_cap(), "a new round")
	_to_sudden_death()
	referee.round_ticks = referee.cap_at - 1
	heroes[1].kill(&"liquid")
	Sim.step(1)
	assert_eq(referee.phase, VersusReferee.PHASE_OVER)
	assert_eq(referee.round_ticks, cap, "the gong fell on the cap's tick")
	assert_eq(referee.winner_slots, PackedInt32Array([0]), "by the last one standing")
	assert_false(referee.ended_by_cap(), "which is not the cap's doing")
	# A clock's gong (Grub Stack) and a fuse's (Hot Rock) are never the cap's.
	_mode(Defs.VersusMode.GRUB_STACK)
	_give(heroes[0], 3)
	referee.round_ticks = referee.round_total - 1
	Sim.step(1)
	assert_eq(referee.phase, VersusReferee.PHASE_OVER, "the clock ended the Grub Stack round")
	assert_false(referee.ended_by_cap())
	_mode(Defs.VersusMode.HOT_ROCK)
	heroes[1].kill(&"hot_rock")
	Sim.step(2)
	assert_eq(referee.phase, VersusReferee.PHASE_OVER, "one left: the Hot Rock round is over")
	assert_false(referee.ended_by_cap())


func test_time_banner_stands_over_the_result_when_the_cap_ends_a_round() -> void:
	# The versus HUD's own round banner, with the real HUD in the tree: at the cap "TIME!" is the banner and the result
	# line the HUD wrote at the gong - the winner, or its "Draw!" - stands under it; any other gong keeps its result.
	assert_true(FileAccess.get_file_as_string("res://locale/en.po").contains("msgid \"UI_VS_TIME\"\nmsgstr \"TIME!\""),
			"the catalogue has the string")
	_lcs_no_kill(2, [100, 125])
	var hud: Hud = (load(Flow.HUD_SCENE) as PackedScene).instantiate() as Hud
	add_node(hud)
	await get_tree().process_frame
	var banner: HudVersus = hud.get_versus()
	assert_not_null(banner, "the versus HUD")
	if banner == null:
		return
	# 1. P1 hits P2 once, then nobody moves: at the cap P1 took fewer hurts.
	_to_sudden_death()
	_box(heroes[0], 1)
	Sim.step(1)
	assert_eq(referee.hurts_of(1), 1)
	referee.round_ticks = referee.cap_at - 1
	Sim.step(1)
	assert_true(referee.ended_by_cap())
	var p1_wins: String = HudVersus.result_text(PackedInt32Array([0]))
	assert_eq(banner.banner_text, p1_wins, "the HUD's result line on the gong's tick")
	await get_tree().process_frame
	assert_eq(banner.banner_text, tr("UI_VS_TIME"), "then \"TIME!\" is the banner")
	assert_eq(banner.banner_hint, p1_wins, "with the result under it")
	assert_true(banner.is_banner_visible())
	# 2. Nobody hurt: "TIME!" over "Draw!".
	_mode(Defs.VersusMode.LAST_CAVEMAN)
	_to_sudden_death()
	referee.round_ticks = referee.cap_at - 1
	Sim.step(1)
	assert_eq(referee.winner_slots, PackedInt32Array(), "a draw")
	await get_tree().process_frame
	assert_eq(banner.banner_text, tr("UI_VS_TIME"))
	assert_eq(banner.banner_hint, tr("UI_VS_DRAW"))
	# 3. A round that the last one standing ends says who won, as ever - also late in the sudden death.
	_mode(Defs.VersusMode.LAST_CAVEMAN)
	_to_sudden_death()
	heroes[1].kill(&"liquid")
	Sim.step(2)
	assert_eq(referee.phase, VersusReferee.PHASE_OVER)
	await get_tree().process_frame
	assert_eq(banner.banner_text, p1_wins, "no \"TIME!\" without the cap")
	assert_eq(banner.banner_hint, "")


## Every arena file that lists Last Caveman Standing (the shipped ones and the developer arena), real heroes, the
## real referee, the arena's own sudden death: `players` heroes who never press a key. The round must end by the cap.
func _idle_round(id: StringName, text: String, players: int, round_index: int) -> Dictionary:
	var was_manual: bool = Sim.manual
	Sim.manual = true
	Game.start_run(Defs.Difficulty.BEGINNER, Defs.GameMode.VERSUS, players, 1)
	Game.begin_level(id)
	var real: Level = (load("res://scenes/world/level.tscn") as PackedScene).instantiate() as Level
	real.setup_from_text(id, text)
	add_child(real)
	real.set_view_size(Vector2i(Tuning.VIEW_W, Tuning.VIEW_H) * Tuning.ART_SCALE)
	Sim.start(VersusTuning.round_seed(7, round_index))
	var result: Dictionary = {}
	var ref: VersusReferee = VersusReferee.find(real)
	if ref != null:
		ref.mode = Defs.VersusMode.LAST_CAVEMAN
		ref.begin_round(round_index)
		ref.start_round_now()
		for slot: int in players:
			GameInput.set_scripted_slot(slot, func(_tick: int) -> int: return 0)
		var limit: int = VersusTuning.SUDDEN_DEATH_AT_TICKS + VersusTuning.SUDDEN_DEATH_CAP_TICKS
		var moved: bool = false
		var spawns: Array[Vector2i] = []
		for slot: int in players:
			spawns.append(real.get_hero(slot).sim_pos)
		while ref.phase != VersusReferee.PHASE_OVER and ref.round_ticks < limit + 5:
			Sim.step(1)
		var hurts: PackedInt32Array = PackedInt32Array()
		var standing: PackedInt32Array = PackedInt32Array()
		for slot: int in players:
			hurts.append(ref.hurts_of(slot))
			if not ref.is_out(slot) and not real.get_hero(slot).dead:
				standing.append(slot)
			moved = moved or absi(real.get_hero(slot).sim_pos.x - spawns[slot].x) > Tuning.TILE * 3
		result = {"over": ref.phase == VersusReferee.PHASE_OVER, "ticks": ref.round_ticks, "limit": limit,
				"winners": ref.winner_slots.duplicate(), "hurts": hurts, "standing": standing,
				"capped": ref.cap_at >= 0 and ref.round_ticks >= ref.cap_at, "moved": moved,
				"theme": VersusSuddenDeath.theme_of(real.meta)}
	GameInput.clear_scripted()
	Sim.stop()
	Sim.manual = was_manual
	remove_child(real)
	real.free()
	return result


# --- Drawn rounds end the match (DESIGN.md G78, the last clause) --------------------------------------------------------

## A match of `count` seats nobody feeds (bot seats without a bot source stand idle), first to `to_win` round wins.
func _idle_match(count: int, mode: int, to_win: int = 0) -> VersusMatch:
	var versus_match: VersusMatch = VersusMatch.new()
	for i: int in count:
		versus_match.seat_bot(Defs.BotLevel.HUNTER)
	versus_match.mode = mode
	versus_match.rounds_to_win = to_win
	versus_match.begin_match(5)
	return versus_match


func _record(versus_match: VersusMatch, winners: Array) -> void:
	versus_match.begin_round(&"test_world_arena_flat")
	versus_match.record_round(PackedInt32Array(winners))


func test_three_drawn_rounds_in_a_row_end_the_match_on_its_standings() -> void:
	assert_eq(VersusTuning.DRAW_ROUNDS_TO_END, 3)
	# Nobody ever won a round: a drawn match, nobody named.
	var versus_match: VersusMatch = _idle_match(2, Defs.VersusMode.LAST_CAVEMAN)
	for i: int in 2:
		_record(versus_match, [])
		assert_false(versus_match.is_over(), "%d drawn round(s): the match goes on" % (i + 1))
	_record(versus_match, [])
	assert_true(versus_match.ended_by_draws(), "three in a row")
	assert_true(versus_match.is_over(), "the match is over")
	assert_eq(versus_match.leaders(), PackedInt32Array(), "nobody won a round: a drawn match")
	assert_eq(versus_match.round_index, 3)
	# A round with a winner breaks the row; the leader takes a match that draws end.
	versus_match = _idle_match(3, Defs.VersusMode.LAST_CAVEMAN)
	_record(versus_match, [])
	_record(versus_match, [])
	_record(versus_match, [1])
	assert_eq(versus_match.draws_in_a_row, 0, "a won round starts the count again")
	_record(versus_match, [])
	_record(versus_match, [])
	assert_false(versus_match.is_over(), "two drawn rounds after P2's win")
	_record(versus_match, [])
	assert_true(versus_match.is_over())
	assert_eq(versus_match.leaders(), PackedInt32Array([1]), "the one side that leads takes the match")
	var runs: Array[PlayerRun] = []
	for slot: int in 3:
		var run: PlayerRun = PlayerRun.new()
		run.slot = slot
		runs.append(run)
	versus_match.finish(runs)
	assert_eq(runs[0].comeback, 0, "no Comeback Caveman for a match nobody came back in")
	# Level sides share a drawn match: nobody is named, however many rounds each won.
	versus_match = _idle_match(2, Defs.VersusMode.LAST_CAVEMAN)
	_record(versus_match, [0])
	_record(versus_match, [1])
	for i: int in 3:
		_record(versus_match, [])
	assert_true(versus_match.is_over())
	assert_eq(versus_match.leaders(), PackedInt32Array(), "1 : 1 and three draws: a drawn match")
	# 2v2: a team is one side - both of the leading team win.
	versus_match = _idle_match(4, Defs.VersusMode.LAST_CAVEMAN)
	for slot: int in 4:
		versus_match.get_seat(slot).team = 1 if slot % 2 == 0 else 2
	_record(versus_match, [0, 2])
	for i: int in 3:
		_record(versus_match, [])
	assert_eq(versus_match.leaders(), PackedInt32Array([0, 2]), "the leading team, both members")
	# A match that wins end is what it was; a rematch starts the count again; every mode has the rule.
	versus_match = _idle_match(2, Defs.VersusMode.GRUB_STACK, 1)
	_record(versus_match, [])
	_record(versus_match, [])
	_record(versus_match, [0])
	assert_true(versus_match.is_over(), "first to 1")
	assert_false(versus_match.ended_by_draws())
	assert_eq(versus_match.leaders(), PackedInt32Array([0]))
	for i: int in 3:
		versus_match.rematch()
		assert_eq(versus_match.draws_in_a_row, 0)
		assert_false(versus_match.is_over())
		_record(versus_match, [])
	assert_false(versus_match.is_over(), "one drawn round in each of three matches is no row")
	_record(versus_match, [])
	_record(versus_match, [])
	assert_true(versus_match.is_over(), "Grub Stack too: three drawn rounds in one match")


func test_the_stampede_runs_along_the_floor_of_every_stampede_arena() -> void:
	# Totem Ring's middle column is its totem: the chargers ran along the totem's top (y 64), over every head on the
	# floor, until the idle rounds of ruling R8 showed that its stampede never ended a round (wf11).
	var checked: int = 0
	for file: String in DirAccess.get_files_at("res://levels"):
		if file.get_extension() != "lvl" or not (file.begins_with("arena_") or file.begins_with("test_world_arena")):
			continue
		var id: StringName = StringName(file.get_basename())
		var text: String = FileAccess.get_file_as_string("res://levels/%s" % file)
		var meta: Dictionary = LevelData.parse(id, text).resolved_meta(Defs.Difficulty.BEGINNER)
		if VersusSuddenDeath.theme_of(meta) != VersusSuddenDeath.STAMPEDE:
			continue
		var was_manual: bool = Sim.manual
		Sim.manual = true
		Game.start_run(Defs.Difficulty.BEGINNER, Defs.GameMode.VERSUS, 2, 1)
		Game.begin_level(id)
		var real: Level = (load("res://scenes/world/level.tscn") as PackedScene).instantiate() as Level
		real.setup_from_text(id, text)
		add_child(real)
		real.set_view_size(Vector2i(Tuning.VIEW_W, Tuning.VIEW_H) * Tuning.ART_SCALE)
		Sim.start(3)
		var ref: VersusReferee = VersusReferee.find(real)
		assert_not_null(ref, "%s: a referee" % id)
		if ref != null:
			ref.mode = Defs.VersusMode.LAST_CAVEMAN
			ref.begin_round(0)
			ref.start_round_now()
			for slot: int in 2:
				GameInput.set_scripted_slot(slot, func(_tick: int) -> int: return 0)
			ref.start_sudden_death()
			Sim.step(2)
			var chargers: int = 0
			for node: Node in get_tree().get_nodes_in_group(VersusReferee.ROUND_GROUP):
				var hazard: VersusHazard = node as VersusHazard
				if hazard != null and hazard.kind == VersusHazard.CHARGER:
					chargers += 1
					assert_eq(hazard.sim_pos.y, VersusTuning.ARENA_FLOOR_ROW * Tuning.TILE,
							"%s: the charger's feet are on the arena floor (row %d)" % [id, VersusTuning.ARENA_FLOOR_ROW])
			assert_eq(chargers, 1, "%s: the first charger of the stampede" % id)
			checked += 1
		GameInput.clear_scripted()
		Sim.stop()
		Sim.manual = was_manual
		remove_child(real)
		real.free()
	assert_true(checked >= 2, "%d stampede arenas (Totem Ring and the developer arenas)" % checked)


func test_two_heroes_who_never_move_end_every_last_caveman_arena_by_the_cap() -> void:
	var files: PackedStringArray = PackedStringArray()
	for file: String in DirAccess.get_files_at("res://levels"):
		if file.get_extension() == "lvl" and (file.begins_with("arena_") or file == "test_world_arena_flat.lvl"):
			files.append(file)
	files.sort()
	var arenas: int = 0
	var capped: int = 0
	for file: String in files:
		var id: StringName = StringName(file.get_basename())
		var text: String = FileAccess.get_file_as_string("res://levels/%s" % file)
		var meta: Dictionary = LevelData.parse(id, text).resolved_meta(Defs.Difficulty.BEGINNER)
		if not VersusArena.modes_of(meta).has(Defs.VersusMode.LAST_CAVEMAN):
			continue
		arenas += 1
		# (heroes, round): two heroes on spawns 1 + 2 - the spawns of every round of a 2-player match. The other
		# rotations of two and all four at once: the slow module (tests/test_versus_bots.gd); the same table with and
		# without the cap: build/versus/idle_nocap.gd (wf11). One round per arena keeps this test at about 2 s.
		var cases: Array[Vector2i] = [Vector2i(2, 0)]
		var lines: PackedStringArray = PackedStringArray()
		for case: Vector2i in cases:
			var result: Dictionary = _idle_round(id, text, case.x, case.y)
			var name: String = "%s, %d idle heroes, round %d" % [id, case.x, case.y]
			assert_false(result.is_empty(), "%s: the arena has a referee" % name)
			if result.is_empty():
				continue
			assert_true(bool(result["over"]), "%s: the round ended (%d ticks played)" % [name, result["ticks"]])
			assert_true(int(result["ticks"]) <= int(result["limit"]),
					"%s: within %d ticks of play - sudden death at %d, the cap %d later (took %d)" % [name, result["limit"],
					VersusTuning.SUDDEN_DEATH_AT_TICKS, VersusTuning.SUDDEN_DEATH_CAP_TICKS, result["ticks"]])
			var winners: PackedInt32Array = result["winners"]
			var standing: PackedInt32Array = result["standing"]
			var hurts: PackedInt32Array = result["hurts"]
			if bool(result["capped"]):
				capped += 1
				# The cap's rule on what the round left: the fewest hurts among the standing, alone, or nobody.
				var fewest: int = 1 << 30
				for slot: int in standing:
					fewest = mini(fewest, hurts[slot])
				var best: PackedInt32Array = PackedInt32Array()
				for slot: int in standing:
					if hurts[slot] == fewest:
						best.append(slot)
				assert_eq(winners, best if best.size() == 1 else PackedInt32Array(),
						"%s: at the cap the fewest hurts win, else a draw (standing %s, hurts %s)" % [name, standing, hurts])
			else:
				assert_true(standing.size() <= 1, "%s: before the cap only the last one standing ends it (%s)" % [name,
						standing])
			lines.append("%dp r%d: %d ticks %s winners %s" % [case.x, case.y, result["ticks"],
					"CAP" if bool(result["capped"]) else str(result["theme"]), winners])
		print("    %s: %s" % [id, "; ".join(lines)])
	assert_true(arenas >= 5, "%d arena files list Last Caveman Standing" % arenas)
	assert_true(capped >= 1, "the cap ended %d of the rounds (Colossus Hall's ledges hide two campers for good)" % capped)


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


func test_clubball_a_coconut_wedged_in_a_wall_is_lost_and_drops_in_again() -> void:
	# Phase 4, found by the versus soak (tools/bots/soak.sh: Coconut Cove, seed 4075 round 2, three and four CPUs): a
	# lob came down INSIDE the block over a goal mouth - the coconut at rest on the cell under it, its centre in a wall
	# cell, where no strike reaches it - and the golden coconut, which has no clock, never ended. A coconut that lies
	# so for VersusClubball.WEDGED_TICKS is lost: out of play, then in again at its drop point; nobody scores.
	var coconut: Coconut = _clubball()
	if coconut == null:
		return
	var drop: Vector2i = coconut.drop_point
	# Inside the floor's upper row, at rest on its lower row (rows 10 and 11 are solid).
	var inside: Vector2i = Vector2i(200, FLOOR_Y + Tuning.TILE)
	heroes[0].teleport(Vector2i(150, FLOOR_Y))
	coconut.teleport(inside)
	coconut.xvel = 0
	coconut.yvel = 0
	Sim.step(1)
	assert_eq(coconut.sim_pos, inside, "it rests there")
	assert_eq(Vector2i(coconut.xvel, coconut.yvel), Vector2i.ZERO)
	assert_eq(level.grid.side_at(coconut.center().x >> 4, coconut.center().y >> 4), TileGrid.SIDE_WALL,
			"its centre is in a wall cell")
	Sim.step(VersusClubball.WEDGED_TICKS - 2)
	assert_true(coconut.in_play(), "one tick before: still wedged")
	assert_eq(referee.clubball.wedged_ticks, VersusClubball.WEDGED_TICKS - 1)
	Sim.step(1)
	assert_false(coconut.in_play(), "lost: out of play")
	assert_eq(referee.clubball.wedged_resets, 1)
	assert_eq([referee.goals_of(1), referee.goals_of(2)], [0, 0], "nobody scores")
	Sim.step(VersusTuning.BALL_RESET_TICKS)
	assert_true(coconut.in_play(), "and in again")
	assert_eq(coconut.sim_pos.x, drop.x, "over its drop point")
	assert_true(coconut.sim_pos.y <= FLOOR_Y, "above the floor (%s)" % coconut.sim_pos)
	assert_eq(heroes[0].sim_pos, Vector2i(150, FLOOR_Y), "no kick-off: the heroes stay where they are")
	assert_eq(referee.phase, VersusReferee.PHASE_PLAY, "the game goes on")
	# A coconut lying still on the floor is nobody's business.
	coconut.teleport(Vector2i(200, FLOOR_Y))
	coconut.xvel = 0
	coconut.yvel = 0
	Sim.step(VersusClubball.WEDGED_TICKS * 2)
	assert_true(coconut.in_play(), "a coconut at rest on open ground stays in play")
	assert_eq(referee.clubball.wedged_resets, 1)
	# The golden coconut stays golden through it.
	referee.clubball.start_golden()
	coconut.teleport(inside)
	coconut.xvel = 0
	coconut.yvel = 0
	Sim.step(VersusClubball.WEDGED_TICKS + VersusTuning.BALL_RESET_TICKS + 1)
	assert_eq(referee.clubball.wedged_resets, 2)
	assert_true(coconut.in_play() and coconut.golden, "the golden coconut drops in again, golden")


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


# =================================================================================================================
# Requests of phase 2 (objects-B's Mesa Rodeo bite, ui-B's hearts, core-A's unlocked Mayhem variants)
# =================================================================================================================

func test_a_chomper_bite_costs_the_modes_currency() -> void:
	_arena(3, [100, 125, 250])
	var mount: SimEntity = SimEntity.new()
	place(level, mount, Vector2i(100, FLOOR_Y))
	_give(heroes[1], 10)
	assert_true(referee.bite_hit(heroes[0], heroes[1], mount), "Grub Stack: the bite lands")
	assert_eq(referee.stack_of(1), 10 - VersusTuning.RODEO_BITE_SPILL, "the rider's bite spills 3")
	assert_eq(heroes[1].xvel, VersusTuning.HIT_XVEL, "knocked away from the rider")
	assert_eq(heroes[1].hit_timer, VersusTuning.HURT_TIMER_TICKS, "the versus hurt timing")
	assert_false(referee.bite_hit(heroes[0], heroes[1], mount), "immune after the bite: it does not land")
	referee.teams = PackedInt32Array([1, 2, 1, -1])
	assert_false(referee.bite_hit(heroes[0], heroes[2], mount), "never a teammate")
	referee.teams = PackedInt32Array([-1, -1, -1, -1])
	_mode(Defs.VersusMode.LAST_CAVEMAN)
	assert_true(referee.bite_hit(heroes[0], heroes[2], mount))
	assert_eq(Game.runs[2].hearts, VersusTuning.LCS_HEARTS - 1, "Last Caveman Standing: a heart, like a hit")
	assert_eq(referee.hearts_of(2), VersusTuning.LCS_HEARTS - 1, "the corner panel's hearts (ui-B)")
	assert_eq(count_items(&"items/bone"), VersusTuning.LCS_HEART_BONES, "the lost heart bursts into bones")
	referee.end_round(false)
	assert_false(referee.bite_hit(heroes[0], heroes[1], mount), "nothing after the gong")
	mount.free()


func test_hearts_of_reads_zero_for_an_out_player() -> void:
	_arena(2, [100, 125])
	_mode(Defs.VersusMode.LAST_CAVEMAN)
	assert_eq(referee.hearts_of(1), VersusTuning.LCS_HEARTS)
	heroes[1].kill(&"lava")
	Sim.step(1)
	assert_true(referee.is_out(1))
	assert_eq(referee.hearts_of(1), 0, "out: no hearts on his panel")
	assert_eq(referee.hearts_of(7), 0, "an unknown slot")


func test_mayhem_rolls_only_variants_the_profile_has_opened() -> void:
	var closed: Array[StringName] = []
	for variant: StringName in VersusRules.VARIANTS:
		if not UnlockTable.is_variant_open(variant):
			closed.append(variant)
	assert_false(closed.is_empty(), "a fresh profile has painting-locked variants (DESIGN.md C.9)")
	var rolled: Dictionary = {}
	var all_rolled: Dictionary = {}
	for seed_value: int in 200:
		rolled[VersusRules.mayhem_variant(seed_value, Defs.VersusMode.GRUB_STACK)] = true
		all_rolled[VersusRules.mayhem_variant(seed_value, Defs.VersusMode.GRUB_STACK, false)] = true
	for variant: StringName in closed:
		assert_false(rolled.has(variant), "%s is closed: never rolled" % variant)
		assert_true(all_rolled.has(variant), "%s is in the full table" % variant)
	assert_eq(VersusRules.VARIANTS, VersusMatch.VARIANT_NAMES, "core-A's list mirrors ours")
	Save.set_unlock_everything(true)
	var opened: Dictionary = {}
	for seed_value: int in 200:
		opened[VersusRules.mayhem_variant(seed_value, Defs.VersusMode.GRUB_STACK)] = true
	Save.set_unlock_everything(false)
	for variant: StringName in closed:
		assert_true(opened.has(variant), "Unlock everything opens %s" % variant)


# =================================================================================================================
# Phase 3: the arena signatures (VersusSignatures; DESIGN.md E.5, DA's wf8 / wf9 requests, G31 / G43) and the
# Clubball sides rotating per round
# =================================================================================================================

## An arena (as _arena) whose level gets the extra `meta` (and the file `level_id` the referee reads its markers from,
## "" = none), then round 0 in `mode` begins again (the signatures read the arena afresh).
func _signature_arena(count: int, xs: Array, meta: Dictionary, mode: int = Defs.VersusMode.GRUB_STACK,
		level_id: StringName = &"") -> void:
	heroes.clear()
	_arena(count, xs)
	for key: String in meta:
		level.meta[key] = meta[key]
	if level_id != &"":
		level.level_id = level_id
	_mode(mode)


func test_clubball_sides_rotate_every_round() -> void:
	var coconut: Coconut = _clubball()
	if coconut == null:
		return
	assert_false(referee.clubball.swapped, "round 0: the file's sides")
	assert_eq(referee.goal_rect(1), Rect2i(0, 112, 16, 48), "team 1 defends the left mouth")
	referee.begin_round(1)
	referee.start_round_now()
	_unshield()
	assert_true(referee.clubball.swapped, "round 1: the sides changed ends")
	assert_eq(referee.goal_rect(1), Rect2i(304, 112, 16, 48), "team 1 defends the right mouth now")
	assert_eq(referee.goal_rect(2), Rect2i(0, 112, 16, 48))
	assert_eq(heroes[0].sim_pos.x, 256, "team 1 kicks off on the right half (the spawn nearest its own goal)")
	assert_eq(heroes[1].sim_pos.x, 64)
	var goals: Array[Array] = []
	referee.goal_scored.connect(func(team: int, a: int, b: int) -> void: goals.append([team, a, b]))
	coconut.teleport(Vector2i(8, FLOOR_Y - 8))
	coconut.xvel = 0
	coconut.yvel = 0
	Sim.step(1)
	assert_eq(goals, [[1, 1, 0]] as Array[Array], "the left mouth is team 2's this round: team 1 scores there")
	referee.begin_round(2)
	assert_false(referee.clubball.swapped, "round 2: back to the file's sides")
	assert_eq(referee.goal_rect(1), Rect2i(0, 112, 16, 48))


func test_goal_mouths_are_ring_outs_in_the_other_modes() -> void:
	_signature_arena(2, [64, 256], {}, Defs.VersusMode.GRUB_STACK, &"arena_coconut_cove")
	assert_eq(referee.signatures.ring_rects, [Rect2i(0, 112, 16, 48), Rect2i(304, 112, 16, 48)] as Array[Rect2i],
			"Coconut Cove's two zones/goal mouths")
	assert_true(referee.danger_rects(0).has(Rect2i(0, 112, 16, 48)), "the bots keep out of them")
	_give(heroes[0], 10)
	heroes[0].teleport(Vector2i(24, FLOOR_Y))
	Sim.step(1)
	assert_false(heroes[0].dead, "the beach before the mouth is safe")
	heroes[0].teleport(Vector2i(10, FLOOR_Y))
	Sim.step(1)
	assert_true(heroes[0].dead, "feet in the mouth: into the surf")
	assert_eq(referee.stack_of(0), 0, "knocked out as by a hazard: everything spilled")
	assert_eq(kos.size(), 1)
	assert_eq(kos[0][2], VersusSignatures.CAUSE_SURF)
	# Last Caveman Standing: the surf puts him out.
	_signature_arena(2, [64, 256], {}, Defs.VersusMode.LAST_CAVEMAN, &"arena_coconut_cove")
	heroes[1].teleport(Vector2i(310, FLOOR_Y))
	Sim.step(1)
	assert_true(referee.is_out(1), "LCS: a ring-out is out")
	# Clubball: the mouths are goals, never ring-outs.
	_signature_arena(2, [64, 256], {}, Defs.VersusMode.CLUBBALL, &"arena_coconut_cove")
	assert_true(referee.signatures.ring_rects.is_empty(), "Clubball keeps its goals")


func test_echo_hollow_darkness_pulse() -> void:
	_signature_arena(2, [64, 256], {"dark_pulse": "40:10"})
	assert_eq(referee.signatures.dark_period, 40)
	assert_eq(referee.signatures.dark_ticks, 10)
	var nights: Array[int] = []
	for t: int in 100:
		Sim.step(1)
		if level.dark:
			nights.append(referee.round_ticks)
	assert_eq(nights.size(), 20, "two nights of 10 ticks in 100: %s" % str(nights))
	assert_eq(nights[0], 40, "the first night from round tick 40 (one period in)")
	assert_eq(nights[10], 80)
	assert_eq(VersusSignatures.parse_pulse("486"), PackedInt32Array([486, VersusTuning.ECHO_DARK_TICKS]),
			"Echo Hollow: every 20 s, 3 s of night")
	assert_eq(VersusSignatures.parse_pulse(""), PackedInt32Array([0, 0]))
	# Lights Out keeps the night between the pulses.
	var rules: VersusRules = VersusRules.new()
	rules.variants[VersusRules.LIGHTS_OUT] = true
	_signature_arena(2, [64, 256], {"dark_pulse": "40:10"})
	referee.rules = rules
	_mode(Defs.VersusMode.GRUB_STACK)
	Sim.step(55)
	assert_true(level.dark, "Lights Out: still night after the pulse")


func test_echo_hollow_walls_grow_back() -> void:
	_signature_arena(2, [24, 280], {"regrow": "60"})
	level.set_cell(10, 9, TileGrid.CH_SOLID_INVISIBLE)
	var block: BreakableBlock = spawn(&"objects/breakable_block", Vector2i(10 * 16 + 8, 160), {"hits": 1}) \
			as BreakableBlock
	assert_not_null(block)
	if block == null:
		return
	_mode(Defs.VersusMode.GRUB_STACK)
	block.take_hit(25, heroes[0])
	assert_true(block.opened, "one hit breaks it")
	assert_eq(level.get_cell(10, 9), TileGrid.CH_AIR)
	Sim.step(60 - VersusSignatures.REGROW_WARN_TICKS)
	assert_eq(level.get_cell(10, 9), TileGrid.CH_AIR, "the ghost first: nothing blocks yet")
	# A hero stands in the cell when its time comes: the block waits for him.
	heroes[1].teleport(Vector2i(10 * 16 + 8, FLOOR_Y))
	Sim.step(VersusSignatures.REGROW_WARN_TICKS + 4)
	assert_eq(level.get_cell(10, 9), TileGrid.CH_AIR, "never closes on a hero")
	heroes[1].teleport(Vector2i(280, FLOOR_Y))
	Sim.step(2)
	assert_eq(level.get_cell(10, 9), TileGrid.CH_SOLID_INVISIBLE, "solid again once the cell is clear")
	assert_false(block.opened, "the block is back to its level-file state")
	assert_eq(block.hits_left, block.hits_total)
	assert_true(block.take_hit(25, heroes[0]), "and breaks again")


func test_neutral_enemies_are_springboards() -> void:
	_arena(2, [64, 256])
	var dangler: EnemyBase = spawn(&"enemies/dangler", Vector2i(160, 100), {"depth": 0}) as EnemyBase
	assert_not_null(dangler)
	if dangler == null:
		return
	_mode(Defs.VersusMode.LAST_CAVEMAN)
	assert_true(referee.signatures.neutrals.has(dangler), "every enemy of an arena is neutral")
	assert_false(dangler.contact_hurts, "it hurts nobody")
	dangler.take_hit(250, heroes[0])
	Sim.step(1)
	assert_false(dangler.dead, "hits glance off it")
	assert_eq(dangler.hp, VersusSignatures.NEUTRAL_HP)
	# A springboard: a hero falling onto its head bounces as on any enemy (the referee makes the bounce: the hero's own
	# contact skips an enemy that hurts nobody), and nobody is hurt.
	_unshield()
	var hearts: int = heroes[0].run.hearts
	var bounces: int = dangler.bounce_count
	# (The bare heroes of these tests do not move by themselves: his feet are put 3 px into the head, falling.)
	var top: int = dangler.sim_pos.y - dangler.box_h
	heroes[0].teleport(Vector2i(dangler.sim_pos.x, top + 3))
	heroes[0].yvel = 64
	heroes[0].grounded = false
	Sim.step(1)
	assert_eq(heroes[0].yvel, Tuning.BOUNCE_YVEL, "a hero falling onto the dangler's head bounces off it (-64)")
	assert_eq(heroes[0].sim_pos.y, top, "lifted out of the head by the overlap, as a bounce does")
	assert_eq(dangler.bounce_count, bounces + 1, "the enemy counts the bounce")
	assert_false(dangler.dead)
	assert_eq(heroes[0].run.hearts, hearts, "a springboard hurts nobody")
	# Rising into it from below is no stomp: no bounce.
	heroes[1].teleport(Vector2i(dangler.sim_pos.x + 4, dangler.sim_pos.y + 10))
	heroes[1].yvel = -48
	heroes[1].grounded = false
	Sim.step(1)
	assert_eq(heroes[1].yvel, -48, "no bounce from below")


func test_cinder_pit_ember_lane() -> void:
	# The lane over open ground (column 9; an ember fizzles on the first floor it meets - a one-way bridge shelters).
	_signature_arena(2, [152, 256], {"ember_lane": "9,1,30"})
	assert_eq(VersusSignatures.parse_lane("8,4"), PackedInt32Array([8, 4, VersusSignatures.EMBER_PERIOD]))
	_give(heroes[0], 10)
	var warned: Array[int] = []
	var armed: Array[int] = []
	for t: int in 90:
		Sim.step(1)
		for node: Node in get_tree().get_nodes_in_group(VersusReferee.ROUND_GROUP):
			var hazard: VersusHazard = node as VersusHazard
			if hazard == null or hazard.kind != VersusHazard.EMBER:
				continue
			if hazard.warn_tick == Sim.tick:
				warned.append(referee.round_ticks)
				assert_true(referee.danger_rects(VersusSignatures.EMBER_WARN_TICKS).size() >= 1,
						"its glow is in the danger rects")
			if hazard.armed_tick == Sim.tick:
				armed.append(hazard.armed_tick - hazard.warn_tick)
		if referee.stack_of(0) < 10:
			break
	assert_eq(warned[0], 30 - VersusSignatures.EMBER_WARN_TICKS, "the glow 12 ticks before the period")
	assert_eq(armed[0], VersusSignatures.EMBER_WARN_TICKS, "telegraphed 12 ticks")
	assert_eq(referee.stack_of(0), 7, "an ember on the head: the spill of a hit (1 + 10 / 5)")
	assert_eq(referee.stack_of(1), 0)


func test_colossus_hall_spits_at_the_crowned_leader() -> void:
	_signature_arena(2, [64, 256], {})
	var statue: SimEntity = SimEntity.new()
	place(level, statue, Vector2i(312, 160))
	referee.signatures.colossus = statue
	assert_eq(referee.signatures.spit_target(), -1, "nobody crowned: no spit")
	_give(heroes[1], 10)
	assert_eq(referee.signatures.spit_target(), 1, "Grub Stack: the tallest stack")
	var period: int = VersusTuning.COLOSSUS_SPIT_PERIOD_TICKS
	var spat: Array[int] = []
	for t: int in period + 40:
		Sim.step(1)
		for node: Node in get_tree().get_nodes_in_group(VersusReferee.ROUND_GROUP):
			var hazard: VersusHazard = node as VersusHazard
			if hazard != null and hazard.kind == VersusHazard.SPIT and hazard.warn_tick == Sim.tick:
				spat.append(referee.round_ticks)
				assert_eq(hazard.target_slot, 1)
		if referee.stack_of(1) < 10:
			break
	assert_eq(spat, [period - VersusTuning.COLOSSUS_JAWS_TICKS] as Array[int], "the jaws 10 ticks before the period")
	assert_eq(referee.stack_of(1), 7, "the rock hit the leader: the spill of a hit")
	# Last Caveman Standing: the most hearts; a tie is no target.
	_signature_arena(2, [64, 256], {}, Defs.VersusMode.LAST_CAVEMAN)
	referee.signatures.colossus = statue
	assert_eq(referee.signatures.spit_target(), -1, "equal hearts: no spit")
	Game.runs[0].hearts = 1
	assert_eq(referee.signatures.spit_target(), 1)
	_mode(Defs.VersusMode.HOT_ROCK)
	assert_eq(referee.signatures.spit_target(), -1, "no crown in Hot Rock (G43: Grub Stack and LCS only)")


func test_arena_wind_is_round_synced_and_gives_way() -> void:
	_signature_arena(2, [64, 256], {"wind": "0:16,20:-16", "wind_loop": 40})
	var winds: Dictionary = {}
	for t: int in 45:
		Sim.step(1)
		winds[referee.round_ticks] = level.wind
	assert_eq(winds[1], 16)
	assert_eq(winds[19], 16)
	assert_eq(winds[20], -16, "the entry of round tick 20")
	assert_eq(winds[40], 16, "the loop restarts at 40")
	assert_eq(VersusSignatures.wind_at([Vector2i(5, 8)] as Array[Vector2i], 0, 3), 0, "calm before the first entry")
	assert_eq(VersusSignatures.wind_at([Vector2i(5, 8)] as Array[Vector2i], 20, 23), 8, "a later round keeps the last")
	# The Gusty variant replaces the arena's gusts.
	var rules: VersusRules = VersusRules.new()
	rules.variants[VersusRules.GUSTY] = true
	_signature_arena(2, [64, 256], {"wind": "0:16"})
	referee.rules = rules
	_mode(Defs.VersusMode.GRUB_STACK)
	Sim.step(3)
	assert_eq(level.wind, VersusRules.GUSTY_WIND, "Gusty's wind, not the arena's 16")
