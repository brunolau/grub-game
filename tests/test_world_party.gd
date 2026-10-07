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
	# P2 stays at column 1 of the view: the camera cannot page, so P1 walks into the right edge wall.
	p2.teleport(Vector2i(level.get_party_frame().position.x + 24, FLOOR_Y))
	_hold(0, Defs.IN_RIGHT)
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


func test_a_small_locked_view_is_the_party_frame() -> void:
	var level: Level = _load(2)
	var room: Rect2i = Rect2i(160, 16, 320, 176)
	level.lock_camera(room)
	assert_eq(level.get_party_frame(), room, "a one-screen room is the frame, however the screen centres it")
	assert_eq(level.get_edge_walls(), Vector2i(168, 472))
	level.unlock_camera()
	level.lock_camera(Rect2i(0, 0, 640, 224))
	assert_eq(level.get_party_frame().size, Vector2i(320, 176), "a larger lock: the tribe camera's view")
