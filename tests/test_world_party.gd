extends TestCase
## The co-op party rules of world-A (docs/expansion/PLAN.md P1.6; docs/spec/PHYSICS.md C.10-C.13, GAMEPLAY.md 13.9)
## on real heroes in levels loaded by the world module: the PartyDriver and the tribe camera exist only for a co-op
## party, the edge walls, the leash, a death toss that ends in an egg, the egg drift, the hatch by a box and by a
## stomp, Batter Up, Shoulder Hop and Totem Ride, the team wipe, the team exit, gate travel, the shared checkpoint,
## bones to the partner, the Relay Bounce, locked views that take the whole party and eggs that touch no zone.

const LEVEL_SCENE: String = "res://scenes/world/level.tscn"
const BASE_VIEW: Vector2i = Vector2i(640, 360)
## 64 x 14 cells, ground from row 12: '@' at column 4, P2's start at column 6 (both on the floor of row 12).
const LEVEL_TEXT: String = """[meta]
format = 2
id = test_world_party_inline
kind = %s
biome = canyon
terrain_a = canyon/terrain
terrain_b = canyon/terrain_mesa
background = canyon
music = level_cave
[legend]
[tiles]
%s
[entities]
objects/hero_start 6 11 slot=2
%s
"""
const COLS: int = 64
const ROWS: int = 14
const FLOOR_Y: int = 12 * 16

var _was_manual: bool = false


func before_each() -> void:
	_was_manual = Sim.manual
	Game.new_game(Defs.Difficulty.BEGINNER)


func after_each() -> void:
	GameInput.clear_scripted()
	Sim.stop()
	Sim.manual = _was_manual
	Flow.pending_level_id = &""
	Game.new_game(Defs.Difficulty.BEGINNER)
	Game.begin_level(&"")
	Audio.stop_music(0.0)


## A loaded level: `party` heroes in co-op (1 = single-player), `rows` the [tiles] text (default: flat ground).
func _load(party: int = 2, entity_lines: String = "", kind: String = "test", rows: String = "",
		difficulty: int = Defs.Difficulty.BEGINNER) -> Level:
	if party > 1:
		Game.start_run(difficulty, Defs.GameMode.COOP, party)
	else:
		Game.start_run(difficulty)
	Sim.manual = true
	Game.begin_level(&"test_world_party_inline")
	var level: Level = (load(LEVEL_SCENE) as PackedScene).instantiate() as Level
	level.setup_from_text(&"test_world_party_inline", LEVEL_TEXT % [kind, rows if rows != "" else _flat(), entity_lines])
	add_node(level)
	level.set_view_size(BASE_VIEW)
	return level


func _flat() -> String:
	var lines: PackedStringArray = PackedStringArray()
	for row: int in ROWS:
		var line: String = (TileGrid.CH_SOLID_A if row >= 12 else TileGrid.CH_AIR).repeat(COLS)
		if row == 11:
			line = line.substr(0, 4) + TileGrid.CH_PLAYER_START + line.substr(5)
		lines.append(line)
	return "\n".join(lines)


func _driver(level: Level) -> PartyDriver:
	return level.party_driver as PartyDriver


## Hold `flags` on `slot` from now on.
func _hold(slot: int, flags: int) -> void:
	GameInput.set_scripted_slot(slot, func(_tick: int) -> int: return flags)


# =================================================================================================================
# Who gets what
# =================================================================================================================

func test_single_player_gets_no_driver_and_no_tribe_camera() -> void:
	var solo: Level = _load(1)
	assert_eq(solo.hero_count(), 1)
	assert_null(solo.party_driver, "single-player: no driver")
	assert_null(solo.get_tribe_camera(), "single-player: the 1.0 camera")
	assert_eq(solo.get_edge_walls(), Vector2i.ZERO, "no edge walls")
	assert_null(solo.get_lights(), "a Book I level played solo keeps 1.0's look: no lights")


func test_a_coop_party_gets_the_driver_and_the_tribe_camera() -> void:
	var level: Level = _load(2)
	assert_eq(level.hero_count(), 2)
	var driver: PartyDriver = _driver(level)
	assert_not_null(driver, "co-op: the PartyDriver")
	assert_not_null(level.get_tribe_camera())
	var kinds: Array[SimEntity] = level.get_kind(Defs.Kind.OTHER)
	assert_true(driver._sim_serial > level.get_hero(1)._sim_serial, "registered after every hero")
	assert_true(kinds.has(driver))
	var frame: Rect2i = level.get_party_frame()
	assert_eq(frame.size, Vector2i(320, 176), "the authentic 20 x 11-cell view")
	assert_eq(level.get_edge_walls(), Vector2i(frame.position.x + 8, frame.end.x - 8))
	assert_eq(level.get_view_rect().position, level.get_tribe_camera().pos, "the base view is the authentic view")
	assert_not_null(level.get_lights(), "a party keeps seeing itself in the dark: lights")
	assert_not_null(level.get_egg_scout(), "and the egg scouts' glint")


func test_a_versus_party_gets_no_coop_driver() -> void:
	Game.start_run(Defs.Difficulty.BEGINNER, Defs.GameMode.VERSUS, 2)
	Sim.manual = true
	Game.begin_level(&"test_world_party_inline")
	var level: Level = (load(LEVEL_SCENE) as PackedScene).instantiate() as Level
	level.setup_from_text(&"test_world_party_inline", LEVEL_TEXT % ["test", _flat(), ""])
	add_node(level)
	assert_false(level.party_driver is PartyDriver, "versus is world-B's referee, never the co-op driver")
	assert_null(level.get_tribe_camera())


# =================================================================================================================
# Edge walls and the leash (C.13)
# =================================================================================================================

func test_the_view_edges_are_walls_for_the_leader() -> void:
	var level: Level = _load(2)
	var p1: PlayerBase = level.player
	var p2: PlayerBase = level.get_hero(1)
	# P2 stays at column 1 of the view: the camera cannot page, so P1 walks into the right edge wall. (P2 holds a key
	# on the spot: he COUNTS. An idle P2 holds no view - wf11 R6, the tests further down.)
	p2.teleport(Vector2i(level.get_party_frame().position.x + 24, FLOOR_Y))
	_hold(0, Defs.IN_RIGHT)
	_hold(1, Defs.IN_SWAP)
	Sim.step(90)
	var walls: Vector2i = level.get_edge_walls()
	assert_eq(level.get_party_frame().position.x, 0, "the camera never paged")
	assert_true(p1.sim_pos.x < walls.y and p1.sim_pos.x >= walls.y - 6, "P1 stopped at the right wall: %d" % p1.sim_pos.x)
	assert_false(p1.dead)


func test_a_hero_off_the_view_becomes_an_egg_after_the_leash() -> void:
	var level: Level = _load(2)
	var p2: PlayerBase = level.get_hero(1)
	var frame: Rect2i = level.get_party_frame()
	# Outside the authentic view (column 20) on the floor; standing still, the edge wall keeps him there.
	p2.teleport(Vector2i(frame.end.x + 8, FLOOR_Y))
	var limit: int = PartyTuning.leash_egg_ticks(Defs.Difficulty.BEGINNER)
	Sim.step(limit - 1)
	assert_eq(p2.leash, limit - 1, "the stone countdown runs")
	assert_false(p2.is_down())
	Sim.step(1)
	assert_true(p2.is_down(), "121 ticks off the view: an egg")
	assert_false(p2.dead, "no death, no life lost")
	assert_eq(Game.lives, Tuning.LIVES_START)
	assert_true(level.get_party_frame().grow(-PartyTuning.EGG_VIEW_INSET_PX).has_point(p2.sim_pos - Vector2i(0, 1)),
			"the egg is inside the view")


## wf9 DB1 -> player-A: a hero CARRIED past the side of the frame (more than the 20 columns of C.13's off-screen rule,
## e.g. by a ride platform: his own steps stop at the edge walls) while a partner holds the view is leashed like a hero
## above or below it - an egg after the leash, no instant "off_screen" death that wipes the team. With nobody holding
## the view the 1.0 rule still downs him at once.
func test_a_hero_carried_past_the_side_of_the_view_is_leashed_not_killed() -> void:
	var level: Level = _load(2)
	var p2: PlayerBase = level.get_hero(1)
	var frame: Rect2i = level.get_party_frame()
	var cell_x: int = frame.position.x >> 4
	p2.teleport(Vector2i((cell_x + Tuning.DEATH_COLS_FROM_CAMERA + 3) * 16 + 8, FLOOR_Y))
	Sim.step(1)
	assert_false(p2.dead, "beside the frame while P1 holds the view: not downed off_screen")
	assert_false(p2.is_down())
	var limit: int = PartyTuning.leash_egg_ticks(Defs.Difficulty.BEGINNER)
	Sim.step(limit)
	assert_true(p2.is_down(), "the leash made him an egg")
	assert_false(p2.dead)
	assert_eq(Game.lives, Tuning.LIVES_START, "no life lost, no team wipe")
	# Nobody holds the view (P1 an egg): the 1.0 rule.
	var p1: PlayerBase = level.player
	p2.hatch(null, 2)
	p1.go_down(&"voluntary")
	frame = level.get_party_frame()
	p2.teleport(Vector2i(((frame.position.x >> 4) + Tuning.DEATH_COLS_FROM_CAMERA + 3) * 16 + 8, FLOOR_Y))
	Sim.step(1)
	assert_true(p2.dead, "alone in the tribe: off_screen at once")


func test_a_hero_standing_on_a_high_ledge_is_never_leashed() -> void:
	# 30 rows, the floor's feet at y 416 (row 26); a pillar at columns 12-15 whose top is 8 rows higher (y 288): an
	# Expert boost ledge. P1 stands on the floor, P2 on the ledge - neither moves for longer than the leash.
	var lines: PackedStringArray = PackedStringArray()
	for row: int in 30:
		var line: String = (TileGrid.CH_SOLID_A if row >= 26 else TileGrid.CH_AIR).repeat(COLS)
		if row >= 18 and row < 26:
			line = line.substr(0, 12) + TileGrid.CH_SOLID_A.repeat(4) + line.substr(16)
		if row == 25:
			line = line.substr(0, 4) + TileGrid.CH_PLAYER_START + line.substr(5)
		lines.append(line)
	var level: Level = _load(2, "", "test", "\n".join(lines), Defs.Difficulty.EXPERT)
	var p1: PlayerBase = level.player
	var p2: PlayerBase = level.get_hero(1)
	Sim.step(30)
	p2.teleport(Vector2i(13 * 16 + 8, 18 * 16))
	assert_false(level.get_party_frame().has_point(p2.sim_pos - Vector2i(0, LevelCamera.KEEP_HEAD_PX)),
			"the set-up: the ledge is above the view")
	Sim.step(PartyTuning.LEASH_EGG_TICKS_BEGINNER + 10)
	assert_false(p2.is_down(), "never leashed: the view came up to the hero on the ledge")
	assert_true(level.get_party_frame().has_point(p2.sim_pos - Vector2i(0, LevelCamera.KEEP_HEAD_PX)), "P2 whole")
	assert_true(level.get_party_frame().has_point(p1.sim_pos - Vector2i(0, 1)), "P1 still on the view")
	assert_eq(p2.leash, 0)


func test_the_leash_resets_when_the_hero_is_back() -> void:
	var level: Level = _load(2, "", "test", "", Defs.Difficulty.EXPERT)
	var p2: PlayerBase = level.get_hero(1)
	p2.teleport(Vector2i(level.get_party_frame().end.x + 8, FLOOR_Y))
	Sim.step(40)
	assert_eq(p2.leash, 40)
	p2.teleport(Vector2i(100, FLOOR_Y))
	Sim.step(1)
	assert_eq(p2.leash, 0)
	p2.teleport(Vector2i(level.get_party_frame().end.x + 8, FLOOR_Y))
	Sim.step(PartyTuning.LEASH_EGG_TICKS_EXPERT)
	assert_true(p2.is_down(), "Expert: 73 ticks")


# =================================================================================================================
# Deaths, eggs, hatching (C.12)
# =================================================================================================================

func test_a_death_toss_ends_in_an_egg_while_the_partner_plays() -> void:
	var level: Level = _load(2)
	var p2: PlayerBase = level.get_hero(1)
	var at: Vector2i = p2.sim_pos
	p2.kill(&"spikes")
	Sim.step(Tuning.DEATH_ANIM_TICKS)
	assert_true(p2.is_down(), "the toss is over: an egg")
	assert_false(p2.dead)
	assert_eq(Game.lives, Tuning.LIVES_START, "a down costs no life")
	var born: Vector2i = PartyDriver.clamp_egg(at, level.get_party_frame())
	assert_true(absi(p2.sim_pos.x - born.x) <= PartyTuning.EGG_DRIFT_FAST_PX
			and absi(p2.sim_pos.y - born.y) <= PartyTuning.EGG_DRIFT_FAST_PX,
			"born where the toss started (one drift step since): %s / %s" % [p2.sim_pos, born])


func test_the_toss_origin_is_walked_back_from_the_toss() -> void:
	var level: Level = _load(2)
	var p2: PlayerBase = level.get_hero(1)
	var at: Vector2i = p2.sim_pos
	p2.kill(&"spikes")
	Sim.step(25)
	assert_eq(PartyDriver.death_origin(p2), at)


func test_an_egg_drifts_after_its_partner_and_its_owner_nudges_it() -> void:
	var level: Level = _load(2)
	var p1: PlayerBase = level.player
	var p2: PlayerBase = level.get_hero(1)
	p2.go_down(&"voluntary")
	p2.teleport(Vector2i(200, 100))
	p1.facing = 1
	Sim.step(1)
	assert_eq(p2.sim_pos, Vector2i(200 - PartyTuning.EGG_DRIFT_FAST_PX, 100 + PartyTuning.EGG_DRIFT_PX),
			"x: 6 px while farther than 64 px, y: 2 px")
	var target: Vector2i = p1.sim_pos + Vector2i(PartyTuning.EGG_OFFSET_X, PartyTuning.EGG_OFFSET_Y)
	Sim.step(60)
	assert_eq(p2.sim_pos, PartyDriver.clamp_egg(target, level.get_party_frame()), "it waits behind his head")
	_hold(1, Defs.IN_RIGHT)
	Sim.step(1)
	assert_eq(p2.sim_pos.x, target.x + PartyTuning.EGG_NUDGE_PX - 0, "the owner's nudge (the drift pulls back next)")


func test_expert_eggs_fly_back_to_the_checkpoint() -> void:
	var level: Level = _load(2, "", "test", "", Defs.Difficulty.EXPERT)
	var p2: PlayerBase = level.get_hero(1)
	p2.go_down(&"voluntary")
	Sim.step(PartyTuning.EGG_RETURN_TICKS_EXPERT)
	var before: Vector2i = p2.sim_pos
	Game.set_checkpoint(Vector2i(before.x + 100, FLOOR_Y))
	Sim.step(1)
	assert_eq(p2.sim_pos.x, before.x + PartyTuning.EGG_RETURN_SPEED_PX, "6 px per tick towards the checkpoint")
	Sim.step(40)
	assert_eq(p2.sim_pos, Vector2i(before.x + 100, FLOOR_Y), "and waits there")


func test_a_partner_box_hatches_an_egg() -> void:
	var level: Level = _load(2)
	var p1: Player = level.player as Player
	var p2: PlayerBase = level.get_hero(1)
	p2.go_down(&"voluntary")
	p2.teleport(Vector2i(300, FLOOR_Y))
	p1.club_box_active = true
	p1.club_frame = Tuning.ClubFrame.OVERHEAD
	p1.club_box_xo = 8
	p1.club_box = Rect2i(292, FLOOR_Y - 20, 16, 16)
	p1.club_power = Tuning.WEAPON_POWER[Defs.Weapon.CLUB]
	_driver(level).weapon_pass(p1)
	assert_false(p2.is_down(), "any frame of a partner's box hatches")
	assert_false(p1.club_box_active, "the box is used up")
	assert_eq(p2.run.hearts, PartyTuning.HATCH_HEARTS_BEGINNER)
	assert_eq(p2.shield, PartyTuning.HATCH_BLINK_TICKS)
	assert_eq(p2.yvel, PartyTuning.HATCH_POP_YVEL)


func test_hatch_all_and_bones_to_the_partner() -> void:
	var level: Level = _load(2)
	var p1: PlayerBase = level.player
	var p2: PlayerBase = level.get_hero(1)
	var driver: PartyDriver = _driver(level)
	p2.go_down(&"voluntary")
	assert_eq(driver.hatch_all(p1), 1, "the shared checkpoint hatches every egg")
	assert_false(p2.is_down())
	assert_eq(driver.hatch_all(p1), 0)
	p2.run.hearts = 1
	p2.run.bones = 0
	assert_eq(driver.bones_to_partner(p1, 1), 1, "P1 is full: his bone flies to P2")
	assert_eq(p2.run.bones, 1)
	p2.run.hearts = Tuning.ENERGY_START
	assert_eq(driver.bones_to_partner(p1, 1), 0, "nobody needs it")


# =================================================================================================================
# Batter Up, Shoulder Hop, Totem Ride (C.10, C.11)
# =================================================================================================================

func test_a_front_strike_bats_a_curled_partner() -> void:
	var level: Level = _load(2)
	var p1: Player = level.player as Player
	var p2: PlayerBase = level.get_hero(1)
	p2.teleport(Vector2i(300, FLOOR_Y))
	p2.curl = PlayerBase.CURL_CURLED
	p2.set_box(Vector3i(PartyTuning.CURL_BOX_W, PartyTuning.CURL_BOX_H, PartyTuning.CURL_BOX_XO))
	p1.facing = -1
	p1.club_box_active = true
	p1.club_frame = Tuning.ClubFrame.FWD_FRONT
	p1.club_box_xo = 10
	p1.club_box = Rect2i(290, FLOOR_Y - 18, 20, 12)
	p1.club_power = Tuning.WEAPON_POWER[Defs.Weapon.CLUB]
	_driver(level).weapon_pass(p1)
	assert_eq(p2.curl, PlayerBase.CURL_BALL, "a line drive")
	assert_eq(p2.xvel, -PartyTuning.BAT_LINE_DRIVE_XVEL, "the batter's facing")
	assert_eq(p2.yvel, PartyTuning.BAT_LINE_DRIVE_YVEL)
	assert_eq(p2.ball_batter, p1)
	assert_false(p1.club_box_active)


func test_bat_launches_follow_the_strike_and_the_charge() -> void:
	var hero: Player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate() as Player
	hero.facing = 1
	hero.club_frame = Tuning.ClubFrame.HIGH_FRONT
	hero.club_power = Tuning.WEAPON_POWER[Defs.Weapon.CLUB]
	assert_eq(PartyDriver.bat_launch(hero), Vector2i(PartyTuning.BAT_LOB_XVEL, PartyTuning.BAT_LOB_YVEL), "lob")
	hero.club_frame = Tuning.ClubFrame.LOW_FRONT
	assert_eq(PartyDriver.bat_launch(hero), Vector2i(PartyTuning.BAT_GROUNDER_XVEL, 0), "grounder")
	hero.club_power *= Tuning.CHARGE_MULTIPLIER
	assert_eq(PartyDriver.bat_launch(hero), Vector2i(144, 0), "charged x3/2")
	hero.club_frame = Tuning.ClubFrame.FWD_FRONT
	assert_eq(PartyDriver.bat_launch(hero), Vector2i(216, -192), "charged line drive")
	hero.club_frame = Tuning.ClubFrame.OVERHEAD
	assert_eq(PartyDriver.bat_launch(hero), Vector2i.ZERO, "no front frame: no bat")
	hero.free()


func test_landing_on_the_partner_hops_with_up_and_rides_without() -> void:
	var level: Level = _load(2)
	var p1: PlayerBase = level.player
	var p2: PlayerBase = level.get_hero(1)
	_wake(level, p2)
	p2.teleport(Vector2i(200, FLOOR_Y))
	p1.teleport(Vector2i(200, FLOOR_Y - 40))
	p1.yvel = 64
	p1.grounded = false
	p1.no_jump = Tuning.NO_JUMP_TICKS  # falling: Up adds no jump of its own
	_hold(0, Defs.IN_UP)
	var hopped: bool = false
	for i: int in 12:
		Sim.step(1)
		if p1.yvel <= -200:
			hopped = true
			break
	assert_true(hopped, "Shoulder Hop: the enemy bounce with Up (-224)")
	assert_null(p1.totem_carrier)
	GameInput.clear_scripted()
	p1.teleport(Vector2i(200, FLOOR_Y - 40))
	p1.yvel = 64
	Sim.step(12)
	assert_eq(p1.totem_carrier, p2, "no Up: Totem Ride")
	assert_eq(p2.totem_rider, p1)
	assert_eq(p1.sim_pos.y, p2.sim_pos.y - PartyTuning.TOTEM_REST_PX, "standing on his head")
	_hold(1, Defs.IN_RIGHT)
	var x1: int = p1.sim_pos.x
	var x2: int = p2.sim_pos.x
	Sim.step(10)
	assert_eq(p1.sim_pos.x - x1, p2.sim_pos.x - x2, "carried along")
	assert_eq(p1.totem_carrier, p2)


## `hero` presses Swap for one tick (refused with an empty belt: nothing moves) - his player is there: ACTIVE.
func _wake(level: Level, hero: PlayerBase) -> void:
	_hold(hero.slot, Defs.IN_SWAP)
	Sim.step(1)
	GameInput.clear_scripted()
	assert_true(_driver(level).is_active(hero), "any input makes a hatched hero active")


## P1 falls with UP held from `drop` px over the floor onto x = 200 and keeps UP held for `ticks` ticks; returns
## [the most negative yvel, the highest feet y] seen after the first head contact (`first_contact` is the yvel then).
func _fall_with_up(level: Level, drop: int, ticks: int) -> Array[int]:
	var p1: PlayerBase = level.player
	p1.end_totem_ride()
	p1.teleport(Vector2i(200, FLOOR_Y - drop))
	p1.yvel = 64
	p1.grounded = false
	p1.no_jump = Tuning.NO_JUMP_TICKS
	_hold(0, Defs.IN_UP)
	var low_yvel: int = 0
	var high_y: int = FLOOR_Y
	for i: int in ticks:
		Sim.step(1)
		low_yvel = mini(low_yvel, p1.yvel)
		high_y = mini(high_y, p1.sim_pos.y)
	GameInput.clear_scripted()
	return [low_yvel, high_y]


func test_an_egg_is_no_springboard() -> void:
	var level: Level = _load(2)
	var p1: PlayerBase = level.player
	var p2: PlayerBase = level.get_hero(1)
	p1.facing = 1
	p2.go_down(&"voluntary")
	assert_false(_driver(level).is_active(p2), "an egg is never active")
	# The egg floats behind P1's head (feet + (-24, -48)); P1 drops onto it with UP held.
	p2.teleport(Vector2i(200, FLOOR_Y - 30))
	p1.teleport(Vector2i(200, FLOOR_Y - 90))
	p1.yvel = 64
	p1.grounded = false
	p1.no_jump = Tuning.NO_JUMP_TICKS
	_hold(0, Defs.IN_UP)
	var hatch_yvel: int = 0
	for i: int in 20:
		Sim.step(1)
		if not p2.is_down():
			hatch_yvel = p1.yvel
			break
	assert_false(p2.is_down(), "the stomp hatches the egg (as designed)")
	assert_eq(hatch_yvel, Tuning.BOUNCE_YVEL, "but with the plain enemy bounce, UP held or not - never -224")
	assert_false(_driver(level).is_active(p2), "he pops out idle")
	# Up stays held: P1 comes down on the idle body that popped out - no Shoulder Hop off it.
	var low_yvel: int = 0
	var high_y: int = FLOOR_Y
	for i: int in 50:
		Sim.step(1)
		low_yvel = mini(low_yvel, p1.yvel)
		high_y = mini(high_y, p1.sim_pos.y)
	GameInput.clear_scripted()
	assert_true(low_yvel > Tuning.BOUNCE_YVEL_UP + 24, "no Shoulder Hop from the hatched egg (yvel %d)" % low_yvel)
	assert_true(FLOOR_Y - high_y < 7 * Tuning.TILE, "nowhere near a boost ledge: %d px" % (FLOOR_Y - high_y))


func test_only_an_active_partners_head_gives_the_shoulder_hop() -> void:
	var level: Level = _load(2)
	var p2: PlayerBase = level.get_hero(1)
	var driver: PartyDriver = _driver(level)
	p2.teleport(Vector2i(200, FLOOR_Y))
	Sim.step(2)
	assert_false(driver.is_active(p2), "no input since the level start: idle")
	var idle: Array[int] = _fall_with_up(level, 60, 30)
	assert_true(idle[0] > Tuning.BOUNCE_YVEL_UP + 24, "an idle head is no springboard (yvel %d)" % idle[0])
	assert_null(level.player.totem_carrier, "and with UP held no ride either: P1 passes through")
	_wake(level, p2)
	var active: Array[int] = _fall_with_up(level, 60, 30)
	assert_eq(active[0], PartyTuning.SHOULDER_HOP_YVEL, "an active partner's head: the full Shoulder Hop")
	assert_true(FLOOR_Y - active[1] >= 8 * Tuning.TILE, "a boost-ledge height: %d px" % (FLOOR_Y - active[1]))


func test_going_down_and_hatching_make_a_hero_idle_again() -> void:
	var level: Level = _load(2)
	var p1: PlayerBase = level.player
	var p2: PlayerBase = level.get_hero(1)
	var driver: PartyDriver = _driver(level)
	_wake(level, p1)  # P1 plays too (wf11 R6: were his pad on the table, the last counting hero going down is a wipe)
	_wake(level, p2)
	p2.go_down(&"voluntary")
	Sim.step(1)
	assert_false(driver.is_active(p2), "an egg")
	assert_eq(driver.hatch_all(p1), 1)
	assert_false(driver.is_active(p2), "hatched by the checkpoint: idle until his player presses something")
	Sim.step(5)
	assert_false(driver.is_active(p2))
	_wake(level, p2)
	_wake(level, p1)
	# Without UP a partner who has not pressed anything since his hatch (not ACTIVE, but not IDLE either: his player
	# pressed something a moment ago) still carries a Totem Ride (a still carrier's jump stays below every boost
	# ledge). An IDLE partner carries none (G33: tests/test_player_idle.gd).
	p2.go_down(&"voluntary")
	assert_eq(driver.hatch_all(p1), 1)
	p2.teleport(Vector2i(200, FLOOR_Y))
	p1.teleport(Vector2i(200, FLOOR_Y - 40))
	p1.yvel = 64
	p1.grounded = false
	Sim.step(12)
	assert_false(driver.is_active(p2), "not active since the hatch")
	assert_false(p2.is_idle(), "but not idle")
	assert_eq(p1.totem_carrier, p2, "no UP: the ride on a partner who has not pressed anything since his hatch")


# =================================================================================================================
# The lee (co-op gusts: the "lee leapfrog" of DESIGN.md 3-1b / 9-2)
# =================================================================================================================

## Both heroes on the floor: P1 at x `p1_x`, P2 (who crouches from now on) at x 200; the wind blows at `wind`.
func _lee_pair(level: Level, p1_x: int, wind: int, p1_y: int = FLOOR_Y) -> void:
	level.set_wind(wind)
	level.player.teleport(Vector2i(p1_x, p1_y))
	level.get_hero(1).teleport(Vector2i(200, FLOOR_Y))
	_hold(1, Defs.IN_DOWN)
	Sim.step(2)
	level.player.teleport(Vector2i(p1_x, p1_y))
	Sim.step(1)


func test_a_crouching_partner_shelters_the_hero_downwind() -> void:
	var level: Level = _load(2)
	var p1: PlayerBase = level.player
	var p2: PlayerBase = level.get_hero(1)
	level.set_wind(40)
	Sim.step(2)
	assert_eq(level.lee_mask, 0, "nobody crouches: no lee")
	assert_eq(level.wind_for(p1), 40)
	_lee_pair(level, 200 - 32, 40)
	assert_eq(p2.state, Defs.HeroState.CROUCH, "P2 crouches")
	assert_eq(level.wind_for(p1), 0, "the wind blows left: 32 px left of a crouching partner is his lee")
	assert_eq(level.wind_for(p2), 40, "the windbreak is not sheltered (his crouch braces him anyway)")
	_lee_pair(level, 200 - PartyDriver.LEE_REACH_PX, 40)
	assert_eq(level.wind_for(p1), 0, "the lee reaches LEE_REACH_PX downwind")
	_lee_pair(level, 200 - PartyDriver.LEE_REACH_PX - 1, 40)
	assert_eq(level.wind_for(p1), 40, "one pixel farther: the wind")
	_lee_pair(level, 200 + 32, 40)
	assert_eq(level.wind_for(p1), 40, "upwind of him: no shelter")
	_lee_pair(level, 200 + 32, -40)
	assert_eq(level.wind_for(p1), 0, "a wind to the right: the lee is on his right")
	_lee_pair(level, 200 - 32, 40, FLOOR_Y - PartyDriver.LEE_DY_PX - 16)
	assert_eq(level.wind_for(p1), 40, "feet two rows over the croucher's: out of his lee")
	_hold(1, 0)
	Sim.step(2)
	assert_eq(level.wind_for(p1), 40, "the partner stood up: the shelter is gone")
	level.set_wind(0)
	_lee_pair(level, 200 - 32, 0)
	assert_eq(level.lee_mask, 0, "no wind, no lee")


func test_a_jump_taken_in_the_lee_stays_sheltered_until_it_lands() -> void:
	var level: Level = _load(2)
	var p1: PlayerBase = level.player
	var p2: PlayerBase = level.get_hero(1)
	_lee_pair(level, 200 - 24, 40)
	assert_eq(level.wind_for(p1), 0, "in the lee")
	_hold(0, Defs.IN_UP)
	var sheltered_high: bool = false
	for i: int in 8:
		Sim.step(1)
		if FLOOR_Y - p1.sim_pos.y > PartyDriver.LEE_DY_PX:
			sheltered_high = level.wind_for(p1) == 0
	assert_false(p1.is_grounded(), "he jumped")
	assert_true(sheltered_high, "higher than the croucher's lee reaches, the jump keeps it")
	_hold(0, 0)
	_hold(1, 0)
	Sim.step(1)
	assert_eq(level.wind_for(p1), 0, "airborne: sheltered even after the windbreak stood up")
	for i: int in 60:
		if p1.is_grounded():
			break
		Sim.step(1)
	assert_true(p1.is_grounded(), "he landed")
	Sim.step(1)
	assert_eq(level.wind_for(p1), 40, "landed, nobody crouches: the wind again")
	# The wind turns in mid-air: the jump loses its shelter.
	Sim.step(10)
	_lee_pair(level, 200 - 24, 40)
	_hold(0, Defs.IN_UP)
	Sim.step(4)
	assert_false(p1.is_grounded(), "the second jump")
	assert_eq(level.wind_for(p1), 0)
	level.set_wind(-40)
	Sim.step(1)
	assert_eq(level.wind_for(p1), -40, "the gust turned: no lee for this jump any more")
	assert_eq(p2.state, Defs.HeroState.CROUCH, "though his partner still crouches")


func test_single_player_and_eggs_have_no_lee() -> void:
	var solo: Level = _load(1)
	solo.set_wind(40)
	_hold(0, Defs.IN_DOWN)
	Sim.step(3)
	assert_eq(solo.lee_mask, 0, "single-player: never a lee")
	assert_eq(solo.wind_for(solo.player), 40, "wind_for is exactly the wind")
	solo.free()
	GameInput.clear_scripted()
	var level: Level = _load(2)
	_lee_pair(level, 200 - 32, 40)
	assert_eq(level.wind_for(level.player), 0)
	level.player.go_down(&"voluntary")
	Sim.step(1)
	assert_eq(level.wind_for(level.player), 40, "an egg is in nobody's lee")
	assert_eq(level.lee_mask, 0)


# =================================================================================================================
# The team: wipe, exit, gate travel (C.12, GAMEPLAY.md 13.9.2)
# =================================================================================================================

func test_the_last_hero_turning_egg_wipes_the_team() -> void:
	var level: Level = _load(2)
	var p1: PlayerBase = level.player
	var p2: PlayerBase = level.get_hero(1)
	var wipes: Array[int] = [0]
	var on_wipe: Callable = func() -> void: wipes[0] += 1
	Events.party_wiped.connect(on_wipe)
	p2.go_down(&"voluntary")
	Sim.step(1)
	assert_eq(wipes[0], 0, "P1 still plays")
	p1.go_down(&"leash")
	Sim.step(3)
	Events.party_wiped.disconnect(on_wipe)
	assert_eq(wipes[0], 1, "both are eggs: one team wipe")
	assert_eq(Game.lives, Tuning.LIVES_START - 1, "one life from the pool")


func test_a_death_with_the_partner_already_an_egg_waits_for_the_toss_then_wipes() -> void:
	var level: Level = _load(2)
	var p1: PlayerBase = level.player
	var p2: PlayerBase = level.get_hero(1)
	p2.go_down(&"voluntary")
	p1.kill(&"spikes")
	Sim.step(Tuning.DEATH_ANIM_TICKS - 2)
	assert_eq(Game.lives, Tuning.LIVES_START, "the toss plays out first")
	Sim.step(4)
	assert_eq(Game.lives, Tuning.LIVES_START - 1, "then the team wipe")


func test_the_team_exit_waits_for_the_partner_or_his_egg_on_the_view() -> void:
	var level: Level = _load(2)
	var p1: PlayerBase = level.player
	var p2: PlayerBase = level.get_hero(1)
	var driver: PartyDriver = _driver(level)
	assert_false(driver.exit_touched(null, p1), "P2 is not there")
	assert_true(driver.is_at_exit(p1))
	assert_false(p1.control_enabled, "P1 waits at the totem")
	assert_false(driver.exit_touched(null, p1), "idempotent")
	p2.go_down(&"voluntary")
	assert_true(driver.team_at_exit(), "an egg on the view counts as present")
	p2.hatch(null, 2)
	assert_false(driver.team_at_exit())
	assert_true(driver.exit_touched(null, p2), "both at the exit")


## IDLE rule (G33, lead designer's ruling of phase 3): the exit waits only for heroes who play - an IDLE partner on
## the view counts as present (as an egg does); off the view, or in his death toss, he does not.
func test_the_team_exit_does_not_wait_for_an_idle_partner_on_the_view() -> void:
	var level: Level = _load(2)
	var p1: PlayerBase = level.player
	var p2: PlayerBase = level.get_hero(1)
	var driver: PartyDriver = _driver(level)
	_hold(0, Defs.IN_SWAP)
	_hold(1, 0)
	Sim.step(1)
	assert_true(p2.is_idle(), "P2's player never pressed anything")
	assert_false(p1.is_idle())
	var frame: Rect2i = level.get_party_frame()
	assert_true(frame.has_point(p2.sim_pos - Vector2i(0, 1)), "P2 stands on the view")
	assert_true(driver.exit_touched(null, p1), "P1 arrives: the dozing partner on the view counts as present")
	driver.exit_mask = 0
	p1.set_control_enabled(true)
	p2.teleport(Vector2i(frame.end.x + 64, p2.sim_pos.y))
	assert_false(driver.exit_touched(null, p1), "an idle partner off the view is not there (the leash eggs him)")
	p2.teleport(Vector2i(p1.sim_pos.x + 32, p1.sim_pos.y))
	assert_true(driver.team_at_exit(), "back on the view: present")
	p2.idle = false
	assert_false(driver.team_at_exit(), "a partner who plays must walk to the totem himself")


func test_a_gate_takes_the_partner_along_or_as_an_egg() -> void:
	var level: Level = _load(2)
	var p1: PlayerBase = level.player
	var p2: PlayerBase = level.get_hero(1)
	var driver: PartyDriver = _driver(level)
	var from: Vector2i = p1.sim_pos
	var to: Vector2i = Vector2i(40 * 16 + 8, FLOOR_Y)
	p1.teleport(to)
	driver.travel_party(p1, from, to)
	assert_false(p2.is_down(), "within one view: hatched")
	assert_eq(p2.sim_pos, level.party_spread_point(to, 1), "24 px beside the user")
	p2.teleport(Vector2i(8 + 16, FLOOR_Y))
	driver.travel_party(p1, to, Vector2i(10 * 16 + 8, FLOOR_Y))
	assert_true(p2.is_down(), "more than a view away: he arrives as an egg")


# =================================================================================================================
# Relay Bounce (GAMEPLAY.md 13.9.8)
# =================================================================================================================

func test_relay_bounce_alternates_past_eleven_in_a_feast_land() -> void:
	var level: Level = _load(2, "", "bonus")
	var p1: PlayerBase = level.player
	var p2: PlayerBase = level.get_hero(1)
	var driver: PartyDriver = _driver(level)
	var enemy: SimEntity = SimEntity.new()
	assert_true(driver.relay_active())
	assert_eq(driver.relay_bounce_count(enemy, p1, 3), 4, "below 11: the 1.0 counter")
	assert_eq(driver.relay_bounce_count(enemy, p1, 11), 11, "the same hero twice: it stops at 11")
	assert_eq(driver.relay_bounce_count(enemy, p2, 11), 12, "the other hero: 12")
	assert_eq(driver.relay_bounce_count(enemy, p2, 12), 12)
	assert_eq(driver.relay_bounce_count(enemy, p1, 14), 15)
	assert_eq(driver.relay_bounce_count(enemy, p2, 15), 15, "at most 15")
	assert_eq(PartyDriver.relay_multiplier(11), 8)
	assert_eq(PartyDriver.relay_multiplier(12), 10)
	assert_eq(PartyDriver.relay_multiplier(13), 10)
	assert_eq(PartyDriver.relay_multiplier(14), 12)
	assert_eq(PartyDriver.relay_multiplier(15), 12)
	enemy.free()


func test_relay_bounce_is_off_outside_the_feast_lands() -> void:
	var plain: Level = _load(2)
	var other: SimEntity = SimEntity.new()
	assert_false(_driver(plain).relay_active(), "not a Feast Land")
	assert_eq(_driver(plain).relay_bounce_count(other, plain.player, 11), 11)
	assert_eq(_driver(plain).relay_bounce_count(other, plain.get_hero(1), 11), 11, "1.0: the counter stops at 11")
	other.free()


# =================================================================================================================
# Zones: locked views take the party, eggs touch nothing
# =================================================================================================================

func test_a_camera_lock_pulls_the_partner_in() -> void:
	var level: Level = _load(2, "zones/camera_lock 14 11 rect=10,0,20,12")
	var p1: PlayerBase = level.player
	var p2: PlayerBase = level.get_hero(1)
	p1.teleport(Vector2i(12 * 16 + 8, FLOOR_Y))
	p1.facing = 1
	Sim.step(1)
	assert_true(level.is_camera_locked())
	assert_eq(p2.sim_pos, Vector2i(p1.sim_pos.x - PartyTuning.PULL_IN_BEHIND_PX, FLOOR_Y),
			"pulled to 24 px behind the trigger hero")


func test_an_egg_touches_no_zone() -> void:
	var level: Level = _load(2, "zones/secret 30 11 name=nook rect=28,8,4,4")
	var p2: PlayerBase = level.get_hero(1)
	p2.go_down(&"voluntary")
	p2.teleport(Vector2i(29 * 16 + 8, FLOOR_Y))
	var zone: SecretZone = null
	for entity: SimEntity in level.get_kind(Defs.Kind.ZONE):
		if entity is SecretZone:
			zone = entity
	zone._sim_tick(Defs.Phase.CONTACT_ITEMS)
	assert_false(zone.found, "an egg finds no secret")
	assert_eq(zone.inside_mask & 2, 0)


func test_hidden_spots_within_two_tiles_of_an_egg_glint() -> void:
	var rows: String = _flat()
	var lines: PackedStringArray = rows.split("\n")
	lines[12] = lines[12].substr(0, 20) + "?" + lines[12].substr(21, 19) + "?" + lines[12].substr(41)
	var level: Level = _load(2, "", "test", "\n".join(lines))
	var p2: PlayerBase = level.get_hero(1)
	assert_not_null(level.get_egg_scout(), "a co-op party scouts")
	assert_true(EggScout.spots_near_eggs(level).is_empty(), "no egg, no glint")
	p2.go_down(&"voluntary")
	p2.teleport(Vector2i(20 * 16 + 8, FLOOR_Y - 10))
	assert_eq(EggScout.spots_near_eggs(level), [Vector2i(20, 12)] as Array[Vector2i], "the spot under the egg")
	# The egg's box reaches 12 px right of its x; the spot glints while the gap is at most 32 px (2 tiles).
	p2.teleport(Vector2i(21 * 16 + 32 + 12 - 1, FLOOR_Y - 10))
	assert_eq(EggScout.spots_near_eggs(level).size(), 1, "2 tiles away: still")
	p2.teleport(Vector2i(21 * 16 + 32 + 12 + 1, FLOOR_Y - 10))
	assert_true(EggScout.spots_near_eggs(level).is_empty(), "farther: no glint")
	p2.teleport(Vector2i(40 * 16 + 8, FLOOR_Y - 10))
	assert_eq(EggScout.spots_near_eggs(level), [Vector2i(40, 12)] as Array[Vector2i])
	for entity: SimEntity in level.get_kind(Defs.Kind.HITTABLE):
		if (entity as HittableBase).cell == Vector2i(40, 12):
			(entity as HittableBase).opened = true
	assert_true(EggScout.spots_near_eggs(level).is_empty(), "an opened spot never glints")
	p2.hatch(null, 2)
	assert_true(EggScout.spots_near_eggs(level).is_empty(), "hatched: no egg, no glint")


func test_every_hero_has_his_own_fly_swarm() -> void:
	var level: Level = _load(2, "zones/flies 10 11 rect=9,10,3,2 count=6")
	var p1: PlayerBase = level.player
	var p2: PlayerBase = level.get_hero(1)
	p2.teleport(Vector2i(10 * 16 + 8, FLOOR_Y))
	level.notify_hero_teleported(p2)
	Sim.step(2)
	assert_eq(level.get_fly_count(1), 6, "P2 walked over the dirty ground: his swarm")
	assert_eq(level.get_fly_count(0), 0, "not P1's")
	p1.teleport(Vector2i(11 * 16 + 8, FLOOR_Y))
	level.notify_hero_teleported(p1)
	Sim.step(2)
	assert_eq(level.get_fly_count(0), 6)
	assert_eq(level.get_fly_count(), 12, "two swarms")
	p1.teleport(Vector2i(100, FLOOR_Y))
	Events.item_collected.emit(&"items/water_bucket", 0, 0, p1.sim_pos)
	assert_eq(level.get_fly_count(0), 0, "the bucket washes the hero who took it ...")
	assert_eq(level.get_fly_count(1), 6, "... not his partner")


func test_a_small_locked_view_is_the_party_frame() -> void:
	var level: Level = _load(2)
	var room: Rect2i = Rect2i(160, 16, 320, 176)
	level.lock_camera(room)
	assert_eq(level.get_party_frame(), room, "a one-screen room is the frame, however the screen centres it")
	assert_eq(level.get_edge_walls(), Vector2i(168, 472))
	level.unlock_camera()
	level.lock_camera(Rect2i(0, 0, 640, 224))
	assert_eq(level.get_party_frame().size, Vector2i(320, 176), "a larger lock: the tribe camera's view")


# =================================================================================================================
# wf11 ruling R6: an idle hero is no camera anchor, and he is the one the leash takes
# =================================================================================================================

func test_an_idle_partner_holds_no_view_and_the_leash_takes_him() -> void:
	# The pair of test_the_view_edges_are_walls_for_the_leader with the pad of P2 on the table (he never pressed
	# anything: idle by the rule). The view goes with P1, P2 is left behind and HE becomes the egg; P1 is never leashed.
	var level: Level = _load(2)
	var p1: PlayerBase = level.player
	var p2: PlayerBase = level.get_hero(1)
	var p2_start: Vector2i = p2.sim_pos
	_hold(0, Defs.IN_RIGHT)
	var limit: int = PartyTuning.leash_egg_ticks(Defs.Difficulty.BEGINNER)
	var p1_leash: int = 0
	var p2_off_at: int = -1
	var egg_at: int = -1
	for t: int in range(1, 181):
		Sim.step(1)
		p1_leash = maxi(p1_leash, p1.leash)
		if p2_off_at < 0 and p2.leash > 0:
			p2_off_at = t
		if egg_at < 0 and p2.is_down():
			egg_at = t
	assert_true(p2.is_idle(), "P2 never pressed a key")
	assert_true(level.get_party_frame().position.x > 0, "the view paged with P1 (frame at %d)" % level.get_party_frame().position.x)
	assert_true(p1.sim_pos.x > 320, "P1 walked on past the first view (x %d): no edge wall held him" % p1.sim_pos.x)
	assert_true(level.get_party_frame().has_point(p1.sim_pos - Vector2i(0, 1)), "P1 is on the view")
	assert_eq(p1_leash, 0, "P1 was never off the view for a tick")
	assert_false(p1.is_down())
	assert_true(p2_off_at > 0, "P2 stood where he was (x %d) and the view left him" % p2_start.x)
	assert_eq(egg_at, p2_off_at + limit - 1, "the leash took the idle hero after its %d ticks" % limit)
	assert_false(p2.dead, "an egg, not a death")
	assert_eq(Game.lives, Tuning.LIVES_START, "no life lost")
	assert_true(level.get_party_frame().grow(-PartyTuning.EGG_VIEW_INSET_PX).has_point(p2.sim_pos - Vector2i(0, 1)),
			"his egg came onto the view, with the hero who plays")


func test_a_partner_holds_the_view_until_the_idle_rule_says_he_is_gone() -> void:
	# P2 pressed a key once, then put the pad down. For 243 ticks he still counts: the view waits for him and P1 stands
	# at the edge wall, as ever. From the 243rd the view is the view of P1.
	var level: Level = _load(2)
	var p1: PlayerBase = level.player
	var p2: PlayerBase = level.get_hero(1)
	p2.teleport(Vector2i(level.get_party_frame().position.x + 24, FLOOR_Y))
	_hold(0, Defs.IN_RIGHT)
	var first: int = Sim.tick + 1
	GameInput.set_scripted_slot(1, func(tick: int) -> int: return Defs.IN_LOOK if tick == first else 0)
	Sim.step(1)
	assert_false(p2.is_idle(), "one key: he counts")
	Sim.step(PlayerBase.IDLE_TICKS - 1)
	assert_false(p2.is_idle(), "242 quiet ticks: still counted")
	assert_eq(level.get_party_frame().position.x, 0, "the view waited for him the whole time")
	var walls: Vector2i = level.get_edge_walls()
	assert_true(p1.sim_pos.x < walls.y and p1.sim_pos.x >= walls.y - 6, "P1 stands at the right wall: %d" % p1.sim_pos.x)
	assert_eq(p2.leash, 0)
	Sim.step(1)
	assert_true(p2.is_idle(), "the 243rd: idle")
	var limit: int = PartyTuning.leash_egg_ticks(Defs.Difficulty.BEGINNER)
	var p1_leash: int = 0
	for t: int in limit + 40:
		Sim.step(1)
		p1_leash = maxi(p1_leash, p1.leash)
	assert_true(level.get_party_frame().position.x > 0, "the view went on with P1")
	assert_true(p2.is_down(), "and the leash took the sleeper")
	assert_eq(p1_leash, 0, "never the hero who plays")
	assert_false(p1.is_down())


func test_an_idle_partner_below_never_costs_the_climber_his_body() -> void:
	# The real-game finding of the G3b verifier (7-1 'stack'): the partner who stood below held the tribe camera and
	# the leash made the CLIMBER an egg. 40 rows; the floor at row 36, a ledge 16 rows higher (more than a view) on a
	# pillar at columns 12-15. The pad of P1 is on the table (idle from the start); P2 plays and stands on the ledge.
	var lines: PackedStringArray = PackedStringArray()
	for row: int in 40:
		var line: String = (TileGrid.CH_SOLID_A if row >= 36 else TileGrid.CH_AIR).repeat(COLS)
		if row >= 20 and row < 36:
			line = line.substr(0, 12) + TileGrid.CH_SOLID_A.repeat(4) + line.substr(16)
		if row == 35:
			line = line.substr(0, 4) + TileGrid.CH_PLAYER_START + line.substr(5)
		lines.append(line)
	for idle_low: bool in [true, false]:
		var level: Level = _load(2, "", "test", "\n".join(lines), Defs.Difficulty.EXPERT)
		var p1: PlayerBase = level.player
		var p2: PlayerBase = level.get_hero(1)
		_hold(1, Defs.IN_SWAP)
		if not idle_low:
			_hold(0, Defs.IN_SWAP)
		Sim.step(5)
		p2.teleport(Vector2i(13 * 16 + 8, 20 * 16))
		level.notify_hero_teleported(p2)
		var limit: int = PartyTuning.leash_egg_ticks(Defs.Difficulty.EXPERT)
		var p2_leash: int = 0
		for t: int in limit + 60:
			Sim.step(1)
			p2_leash = maxi(p2_leash, p2.leash)
		if idle_low:
			assert_true(p1.is_idle() and not p2.is_idle(), "the set-up: P1 idle below, P2 plays above")
			assert_false(p2.is_down(), "the hero who plays keeps his body")
			assert_true(level.get_party_frame().has_point(p2.sim_pos - Vector2i(0, 1)),
					"the view came up to him (frame %s, feet %s)" % [str(level.get_party_frame()), str(p2.sim_pos)])
			assert_true(p1.is_down(), "the idle hero below was left off the view: the leash took HIM")
			assert_false(p1.dead)
		else:
			# Both play (the rule as it was): P1, the lower slot with ground under his feet, is the anchor; the two stand
			# farther apart than a view holds, and the leash takes the hero off it - P2 on the ledge.
			assert_false(p1.is_idle() or p2.is_idle(), "the set-up: both count")
			assert_true(p2.is_down(), "two heroes who count: the leash is what it was (P2 off the view: an egg)")
			assert_false(p1.is_down())
			assert_true(p2_leash >= limit - 1, "his leash ran its %d ticks" % limit)
		GameInput.clear_scripted()
		Sim.stop()
		level.free()


func test_the_edge_walls_hold_the_heroes_who_count_only() -> void:
	# R6 (3): the view is a wall for the heroes it follows. An idle hero is no wall for the view and no view is a wall
	# for him while his partner plays (a mover may carry him out - then the leash takes him).
	for p2_counts: bool in [true, false]:
		var level: Level = _load(2)
		var p2: PlayerBase = level.get_hero(1)
		_hold(0, Defs.IN_SWAP)
		if p2_counts:
			_hold(1, Defs.IN_SWAP)
		Sim.step(2)
		var walls: Vector2i = level.get_edge_walls()
		p2.teleport(Vector2i(walls.y - 3, FLOOR_Y))
		p2.xvel = 160  # shoved towards the right edge: 10 px on the next tick
		Sim.step(1)
		if p2_counts:
			assert_true(p2.sim_pos.x < walls.y, "a hero who counts stops at the edge wall (x %d, the wall at %d)" % [p2.sim_pos.x, walls.y])
		else:
			assert_true(p2.is_idle(), "the set-up: his pad is on the table")
			assert_true(p2.sim_pos.x >= walls.y, "an idle hero is not held by the view of his partner (x %d, the wall at %d)"
					% [p2.sim_pos.x, walls.y])
		GameInput.clear_scripted()
		Sim.stop()
		level.free()
	# Nobody counts: the walls hold everybody, as they always did.
	var both: Level = _load(2)
	var hero: PlayerBase = both.get_hero(1)
	Sim.step(2)
	var both_walls: Vector2i = both.get_edge_walls()
	hero.teleport(Vector2i(both_walls.y - 3, FLOOR_Y))
	hero.xvel = 160
	Sim.step(1)
	assert_true(hero.sim_pos.x < both_walls.y, "two pads on the table: the edge walls are what they were")


func test_the_last_counting_hero_going_down_beside_an_idle_partner_wipes_the_team() -> void:
	# R6 (6). Before: a player who went down beside a hatched partner whose pad lay on the table was an egg nobody
	# could hatch. Now the toss plays out, a life is paid and both stand at the checkpoint again.
	var wipes: Array[int] = [0]
	var on_wipe: Callable = func() -> void: wipes[0] += 1
	Events.party_wiped.connect(on_wipe)
	for way: String in ["toss", "voluntary", "partner plays", "an idle hero goes down", "the survivor rests"]:
		var level: Level = _load(2)
		var p1: PlayerBase = level.player
		var p2: PlayerBase = level.get_hero(1)
		wipes[0] = 0
		var lives: int = Game.lives
		match way:
			"toss":
				_hold(0, Defs.IN_SWAP)  # P1 plays; P2 never touched his pad
				Sim.step(3)
				p1.kill(&"spikes")
				Sim.step(Tuning.DEATH_ANIM_TICKS - 2)
				assert_eq(wipes[0], 0, "toss: it plays out first")
				Sim.step(6)
				assert_eq(wipes[0], 1, "toss: the last counting hero went down beside an idle partner - a team wipe")
				assert_eq(Game.lives, lives - 1, "toss: a life is paid")
				assert_false(p1.is_down() or p1.dead, "toss: P1 stands at the checkpoint again, no egg nobody can hatch")
				assert_false(p2.is_down() or p2.dead, "toss: and so does P2")
			"voluntary":
				_hold(0, Defs.IN_SWAP)
				Sim.step(3)
				p1.go_down(&"voluntary")
				Sim.step(3)
				assert_eq(wipes[0], 1, "an egg made beside an idle partner: the same wipe, at once")
				assert_eq(Game.lives, lives - 1)
				assert_false(p1.is_down())
			"partner plays":
				_hold(0, Defs.IN_SWAP)
				_hold(1, Defs.IN_SWAP)
				Sim.step(3)
				p1.kill(&"spikes")
				Sim.step(Tuning.DEATH_ANIM_TICKS + 4)
				assert_eq(wipes[0], 0, "a partner who counts: no wipe")
				assert_true(p1.is_down(), "... an egg, as ever")
				assert_eq(Game.lives, lives)
			"an idle hero goes down":
				Sim.step(3)
				p2.go_down(&"leash")  # the pad of P2 on the table, and of P1 too: nobody played, nobody is wiped
				Sim.step(3)
				assert_eq(wipes[0], 0, "an idle hero turning egg beside an idle partner wipes nothing")
				assert_true(p2.is_down())
				assert_eq(Game.lives, lives)
			"the survivor rests":
				_hold(0, Defs.IN_SWAP)
				_hold(1, Defs.IN_SWAP)
				Sim.step(3)
				p2.go_down(&"voluntary")
				Sim.step(3)
				GameInput.clear_scripted()
				Sim.step(PlayerBase.IDLE_TICKS + 20)
				assert_true(p1.is_idle(), "the set-up: P1 put the pad down while P2 is an egg")
				# Both pads went down on the same tick, so the egg's own player is away too: nobody is stuck and nothing
				# is wiped (phase 4 Q3 / G86 wipes only beside the egg of a player who is at his pad - the tests below).
				assert_true(p2.is_idle(), "the set-up: ... and P2's player left with him")
				assert_eq(wipes[0], 0, "two pads on the table wipe nothing")
				assert_eq(Game.lives, lives)
		GameInput.clear_scripted()
		Sim.stop()
		level.free()
	Events.party_wiped.disconnect(on_wipe)


# =================================================================================================================
# Phase 4 ruling Q3 (DESIGN.md G86): no dead end beside an idle partner
# =================================================================================================================

## A pair on `difficulty`: both players pressed a key, then P2 went down - an egg beside a partner who plays. Returns
## the level; both slots hold Swap from here on (the callers let go of what they need).
func _egg_beside_a_player(difficulty: int) -> Level:
	var level: Level = _load(2, "", "test", "", difficulty)
	_hold(0, Defs.IN_SWAP)
	_hold(1, Defs.IN_SWAP)
	Sim.step(3)
	level.get_hero(1).go_down(&"voluntary")
	Sim.step(1)
	return level


func test_an_egg_beside_an_idle_partner_is_wiped_after_the_idle_wipe_ticks() -> void:
	# Before: P2's egg beside a hatched P1 whose pad lay on the table waited for ever (the pause menu was the way out).
	assert_eq(PartyTuning.IDLE_WIPE_TICKS, 73, "3 s (tune through DESIGN)")
	var idle: int = PlayerBase.IDLE_TICKS
	var limit: int = PartyTuning.IDLE_WIPE_TICKS
	var wipes: Array[int] = [0]
	var on_wipe: Callable = func() -> void: wipes[0] += 1
	Events.party_wiped.connect(on_wipe)
	for difficulty: int in [Defs.Difficulty.BEGINNER, Defs.Difficulty.EXPERT]:
		var what: String = "Expert" if difficulty == Defs.Difficulty.EXPERT else "Beginner"
		var level: Level = _egg_beside_a_player(difficulty)
		var p1: PlayerBase = level.player
		var p2: PlayerBase = level.get_hero(1)
		var driver: PartyDriver = _driver(level)
		var lives: int = Game.lives
		wipes[0] = 0
		assert_true(p2.is_down() and not p1.is_idle(), what + ": the set-up - an egg beside a partner who plays")
		# P1 puts the pad down; P2's player stays at his (a held key is input on every tick, for an egg too).
		_hold(0, 0)
		Sim.step(idle - 1)
		assert_false(p1.is_idle(), what + ": 242 quiet ticks - P1 still counts")
		assert_eq(driver.idle_wipe_ticks, 0, what + ": no clock while a hatched hero counts")
		Sim.step(1)
		assert_true(p1.is_idle() and not p2.is_idle(), what + ": the 243rd - the only hatched hero is idle, the egg's player is not")
		assert_eq(driver.idle_wipe_ticks, 1, what + ": the clock starts on that tick")
		Sim.step(limit - 2)
		assert_eq(driver.idle_wipe_ticks, limit - 1, what + ": %d ticks of it" % (limit - 1))
		assert_eq(wipes[0], 0, what + ": ... and nothing yet")
		assert_eq(Game.lives, lives, what)
		assert_true(p2.is_down(), what + ": still an egg")
		Sim.step(1)
		assert_eq(wipes[0], 1, what + ": the %drd tick - the team is wiped, as when both are down" % limit)
		assert_eq(Game.lives, lives - 1, what + ": one life from the tribe pool")
		Sim.step(2)
		assert_false(p1.is_down() or p1.dead or p2.is_down() or p2.dead, what + ": both stand hatched at the checkpoint")
		assert_eq(driver.idle_wipe_ticks, 0, what + ": the clock is back at 0")
		assert_true(p1.is_idle() and not p2.is_idle(), what + ": the wipe woke nobody - P2 plays on, P1 dozes")
		Sim.step(idle + limit + 20)
		assert_eq(wipes[0], 1, what + ": no egg, no dead end - nothing more happens however long P1 rests")
		assert_eq(Game.lives, lives - 1, what)
		GameInput.clear_scripted()
		Sim.stop()
		level.free()
	Events.party_wiped.disconnect(on_wipe)


func test_the_idle_wipe_clock_is_cleared_by_a_key_a_hatch_and_a_toss() -> void:
	var idle: int = PlayerBase.IDLE_TICKS
	var limit: int = PartyTuning.IDLE_WIPE_TICKS
	var wipes: Array[int] = [0]
	var on_wipe: Callable = func() -> void: wipes[0] += 1
	Events.party_wiped.connect(on_wipe)
	for way: String in ["a key on tick 72", "a hatch", "a toss"]:
		var level: Level = _egg_beside_a_player(Defs.Difficulty.BEGINNER)
		var p1: PlayerBase = level.player
		var p2: PlayerBase = level.get_hero(1)
		var driver: PartyDriver = _driver(level)
		var lives: int = Game.lives
		wipes[0] = 0
		_hold(0, 0)
		Sim.step(idle + limit - 2)
		assert_eq(driver.idle_wipe_ticks, limit - 1, way + ": the set-up - one tick before the wipe")
		assert_eq(wipes[0], 0, way)
		match way:
			"a key on tick 72":
				# P1's player comes back: one key, on the tick that would have been the 73rd.
				var tap: int = Sim.tick + 1
				GameInput.set_scripted_slot(0, func(tick: int) -> int: return Defs.IN_LOOK if tick == tap else 0)
				Sim.step(1)
				assert_false(p1.is_idle(), way + ": he counts again")
				assert_eq(driver.idle_wipe_ticks, 0, way + ": the clock is cleared")
				Sim.step(idle - 1)
				assert_eq(wipes[0], 0, way + ": and stays cleared while he counts (242 quiet ticks)")
				assert_eq(driver.idle_wipe_ticks, 0, way)
				Sim.step(limit - 1)
				assert_eq(wipes[0], 0, way + ": idle again - a new clock, from its first tick")
				Sim.step(1)
				assert_eq(wipes[0], 1, way + ": ... and its own %d ticks later the wipe" % limit)
				assert_eq(Game.lives, lives - 1, way)
			"a hatch":
				# Something hatches the egg (a checkpoint's hatch_all here): no egg, no dead end.
				driver.hatch_all(p1)
				Sim.step(1)
				assert_false(p2.is_down(), way + ": the set-up - hatched")
				assert_eq(driver.idle_wipe_ticks, 0, way + ": the clock is cleared")
				Sim.step(limit + 20)
				assert_eq(wipes[0], 0, way + ": no wipe")
				assert_eq(Game.lives, lives, way)
			"a toss":
				# The dozing hero is killed where he stands: his toss decides first (C.12), the clock does not run in it.
				p1.kill(&"spikes")
				Sim.step(1)
				assert_eq(driver.idle_wipe_ticks, 0, way + ": a hero in his death toss - the clock waits")
				Sim.step(Tuning.DEATH_ANIM_TICKS - 3)
				assert_eq(wipes[0], 0, way + ": the toss plays out")
				Sim.step(6)
				assert_eq(wipes[0], 1, way + ": then the wipe of a party with nobody left - once")
				assert_eq(Game.lives, lives - 1, way + ": one life, not two")
		GameInput.clear_scripted()
		Sim.stop()
		level.free()
	Events.party_wiped.disconnect(on_wipe)


func test_two_pads_on_the_table_never_cost_a_life() -> void:
	# G86 #3: the clock runs only while the EGG's own player is at his pad - the wipe is the stuck player's way out.
	var idle: int = PlayerBase.IDLE_TICKS
	var limit: int = PartyTuning.IDLE_WIPE_TICKS
	var wipes: Array[int] = [0]
	var on_wipe: Callable = func() -> void: wipes[0] += 1
	Events.party_wiped.connect(on_wipe)
	for way: String in ["both players leave", "the egg of a partner who never played"]:
		for difficulty: int in [Defs.Difficulty.BEGINNER, Defs.Difficulty.EXPERT]:
			var what: String = "%s (%s)" % [way, "Expert" if difficulty == Defs.Difficulty.EXPERT else "Beginner"]
			var level: Level = null
			if way == "both players leave":
				level = _egg_beside_a_player(difficulty)
			else:
				# P2's pad was never touched: the leash made him an egg while P1 played on (R6); then P1 takes a rest.
				level = _load(2, "", "test", "", difficulty)
				_hold(0, Defs.IN_SWAP)
				Sim.step(3)
				level.get_hero(1).go_down(&"leash")
				Sim.step(1)
			var p1: PlayerBase = level.player
			var p2: PlayerBase = level.get_hero(1)
			var driver: PartyDriver = _driver(level)
			var lives: int = Game.lives
			wipes[0] = 0
			GameInput.clear_scripted()
			var clock: int = 0
			for t: int in idle + 4 * limit:
				Sim.step(1)
				clock = maxi(clock, driver.idle_wipe_ticks)
			assert_true(p1.is_idle() and p2.is_idle() and p2.is_down(), what + ": the set-up - nobody at a pad, one egg")
			assert_eq(clock, 0, what + ": the clock never ran")
			assert_eq(wipes[0], 0, what + ": no wipe")
			assert_eq(Game.lives, lives, what + ": no life lost")
			# The egg's player comes back and finds his partner dozing: any key of his own starts the clock.
			_hold(1, Defs.IN_LEFT)
			Sim.step(limit - 1)
			assert_eq(wipes[0], 0, what + ": his key starts the clock - %d ticks: nothing yet" % (limit - 1))
			assert_eq(driver.idle_wipe_ticks, limit - 1, what)
			Sim.step(1)
			assert_eq(wipes[0], 1, what + ": the %drd: the wipe, his way out" % limit)
			assert_eq(Game.lives, lives - 1, what)
			GameInput.clear_scripted()
			Sim.stop()
			level.free()
	Events.party_wiped.disconnect(on_wipe)
