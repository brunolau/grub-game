extends TestCase
## The IDLE rule of phase 3 (orchestrator decision; PlayerBase.is_idle / counts_for_coop / note_own_input, the dozing
## look of HeroParty, the PartyDriver's own rules) on real heroes in levels loaded by the world module: the per-hero
## timer that only the hero's own input resets, the 243-tick threshold, the "never pressed anything" start, the Zzz,
## single-player and versus untouched, and the driver's rules (Shoulder Hop, lee, Relay Bounce) refusing a dozing
## partner. The co-op objects' side is tests/test_objects_idle.gd.

const LEVEL_SCENE: String = "res://scenes/world/level.tscn"
const BASE_VIEW: Vector2i = Vector2i(640, 360)
## 64 x 14 cells, ground from row 12: '@' at column 4, P2's start at column 6.
const LEVEL_TEXT: String = """[meta]
format = 2
id = test_player_idle_inline
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
"""
const COLS: int = 64
const ROWS: int = 14
const FLOOR_Y: int = 12 * 16
const IDLE: int = PlayerBase.IDLE_TICKS

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


## A loaded level with `party` heroes in `mode` (party 1 = single-player).
func _load(party: int = 2, mode: int = Defs.GameMode.COOP, kind: String = "test") -> Level:
	if party > 1:
		Game.start_run(Defs.Difficulty.BEGINNER, mode, party)
	else:
		Game.start_run(Defs.Difficulty.BEGINNER)
	Sim.manual = true
	Game.begin_level(&"test_player_idle_inline")
	var level: Level = (load(LEVEL_SCENE) as PackedScene).instantiate() as Level
	level.setup_from_text(&"test_player_idle_inline", LEVEL_TEXT % [kind, _flat()])
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


## Hold `flags` on `slot` from now on (0 = release).
func _hold(slot: int, flags: int) -> void:
	GameInput.set_scripted_slot(slot, func(_tick: int) -> int: return flags)


## `slot` presses Swap for one tick (refused with an empty belt: nothing moves), then nothing.
func _tap(slot: int) -> void:
	_hold(slot, Defs.IN_SWAP)
	Sim.step(1)
	_hold(slot, 0)


func _party(hero: PlayerBase) -> HeroParty:
	return (hero as Player).hero_party


# =================================================================================================================
# The timer
# =================================================================================================================

func test_the_idle_threshold_is_ten_seconds() -> void:
	assert_eq(PlayerBase.IDLE_TICKS, roundi(10.0 * Tuning.TICK_HZ), "243 ticks = 10 s at the original's tick rate")


func test_a_hero_who_never_pressed_anything_counts_for_no_rule_but_does_not_doze_yet() -> void:
	var level: Level = _load(2)
	var p1: PlayerBase = level.player
	var p2: PlayerBase = level.get_hero(1)
	_hold(0, Defs.IN_RIGHT)
	_hold(1, 0)
	Sim.step(1)
	assert_false(p1.is_idle(), "P1 walks: his own input")
	assert_true(p1.counts_for_coop())
	assert_true(p2.is_idle(), "P2's player has not pressed anything since the level start")
	assert_false(p2.counts_for_coop())
	assert_true(p2.is_party_targetable(), "an idle hero stays a target")
	assert_false(_party(p2).is_dozing_shown(), "no Zzz before 10 s without input")
	_tap(1)
	assert_false(p2.is_idle(), "one press and he counts")
	Sim.step(1)
	assert_eq(p2.input_idle_ticks, 1, "counted from the press")


func test_ten_seconds_without_own_input_make_a_hero_idle_and_his_next_input_wakes_him() -> void:
	var level: Level = _load(2)
	var p2: PlayerBase = level.get_hero(1)
	_hold(0, Defs.IN_RIGHT)
	_tap(1)
	assert_eq(p2.input_idle_ticks, 0, "the press itself")
	Sim.step(IDLE - 1)
	assert_eq(p2.input_idle_ticks, IDLE - 1)
	assert_false(p2.is_idle(), "242 ticks without input: still there")
	assert_false(_party(p2).is_dozing_shown())
	Sim.step(1)
	assert_true(p2.is_idle(), "the 243rd: idle")
	assert_false(p2.counts_for_coop())
	assert_true(_party(p2).is_dozing_shown(), "and drawn dozing (Zzz)")
	assert_false(_party(level.player).is_dozing_shown(), "P1 walks the whole time")
	Sim.step(500)
	assert_eq(p2.input_idle_ticks, IDLE, "the count is capped")
	assert_true(p2.is_idle())
	_hold(1, Defs.IN_LOOK)
	Sim.step(1)
	assert_false(p2.is_idle(), "any flag of his own slot wakes him")
	assert_false(_party(p2).is_dozing_shown())


func test_hatching_carrying_bumping_and_a_team_wipe_do_not_wake_an_idle_hero() -> void:
	var level: Level = _load(2)
	var p1: PlayerBase = level.player
	var p2: PlayerBase = level.get_hero(1)
	var driver: PartyDriver = level.party_driver as PartyDriver
	_tap(1)
	_hold(0, Defs.IN_SWAP)
	Sim.step(IDLE)
	assert_true(p2.is_idle())
	# Carried: P1 standing on his head moves nothing of his; a bump (a launch) neither.
	p2.launch(PlayerBase.LAUNCH_KEEP, -128)
	Sim.step(20)
	assert_true(p2.is_idle(), "launched: still idle")
	# Hatched by the partner (the checkpoint's hatch_all).
	p2.go_down(&"voluntary")
	Sim.step(1)
	assert_eq(driver.hatch_all(p1), 1)
	Sim.step(1)
	assert_true(p2.is_idle(), "a hatch is not his input")
	assert_false(p2.counts_for_coop())
	# A team wipe (respawn of the whole party).
	level.respawn_player()
	Sim.step(1)
	assert_true(p2.is_idle(), "a respawn is not his input either")
	assert_eq(p2.input_idle_ticks, IDLE)


func test_an_eggs_nudge_is_his_own_input() -> void:
	var level: Level = _load(2)
	var p2: PlayerBase = level.get_hero(1)
	_hold(0, Defs.IN_SWAP)
	p2.go_down(&"voluntary")
	Sim.step(IDLE + 2)
	assert_true(p2.is_idle())
	assert_false(_party(p2).is_dozing_shown(), "an egg shows no Zzz")
	_hold(1, Defs.IN_LEFT)
	Sim.step(1)
	assert_false(p2.is_idle(), "the egg's nudge is his player's input")
	assert_false(p2.counts_for_coop(), "but an egg still counts for nothing")


# =================================================================================================================
# G58 (the IDLE UX decision of wf10): a held key is input on every tick; the "Zzz soon" bubble from the 170th tick
# =================================================================================================================

func test_a_held_key_is_input_on_every_tick_it_is_held() -> void:
	var level: Level = _load(2)
	var p2: PlayerBase = level.get_hero(1)
	_hold(0, Defs.IN_SWAP)
	# P2 crouches (Down held, nothing pressed anew) for 600 ticks - two and a half idle spans.
	_hold(1, Defs.IN_DOWN)
	var quiet: int = 0
	var uncounted: int = 0
	var marked: int = 0
	for t: int in 600:
		Sim.step(1)
		quiet = maxi(quiet, p2.input_idle_ticks)
		if not p2.counts_for_coop():
			uncounted += 1
		if _party(p2).is_idle_warning_shown() or _party(p2).is_dozing_shown():
			marked += 1
	assert_eq(quiet, 0, "a held Down restarts the count on every tick it is held")
	assert_eq(uncounted, 0, "the croucher counts for the co-op rules on all 600 ticks")
	assert_eq(marked, 0, "no warning bubble and no Zzz over a hero who holds a key")
	assert_true(p2.is_crouching(), "he is crouching all the while")
	# Released: the same hero goes idle after 243 quiet ticks, as anyone.
	_hold(1, 0)
	Sim.step(IDLE - 1)
	assert_true(p2.counts_for_coop(), "242 ticks after letting go: still counted")
	Sim.step(1)
	assert_true(p2.is_idle(), "the 243rd quiet tick: idle")
	assert_false(p2.counts_for_coop())


func test_a_partner_crouching_on_a_plate_holds_it_and_one_who_just_stands_lets_go_at_243() -> void:
	var level: Level = _load(2)
	var p2: PlayerBase = level.get_hero(1)
	# A hold plate on the floor (two cells from column 12, inside the tribe's view: no leash); P2 stands on it.
	var plate: Plate = level.spawn(&"objects/plate", LevelText.cell_to_feet(12.0, 11.0), {"name": "p"}) as Plate
	assert_not_null(plate, "the plate spawned")
	if plate == null:
		return
	p2.teleport(Vector2i(12 * 16 + 16, FLOOR_Y))
	_hold(0, Defs.IN_SWAP)
	_hold(1, Defs.IN_DOWN)
	var released: int = 0
	for t: int in 600:
		Sim.step(1)
		if t >= 1 and not plate.pressed:
			released += 1
	assert_eq(released, 0, "Down held: the plate stays pressed for all 600 ticks (10 s is 243)")
	assert_eq(plate.holder_mask, 1 << 1, "held by P2")
	# The same holder standing still without a key: the warning from his 170th quiet tick, the plate lets go at 243.
	_hold(1, 0)
	Sim.step(HeroParty.IDLE_WARN_TICKS - 1)
	assert_true(plate.pressed, "169 quiet ticks: held")
	assert_false(_party(p2).is_idle_warning_shown())
	Sim.step(1)
	assert_true(plate.pressed, "170: still held ...")
	assert_true(_party(p2).is_idle_warning_shown(), "... and the Zzz soon bubble warns the pair")
	Sim.step(IDLE - HeroParty.IDLE_WARN_TICKS - 1)
	assert_true(plate.pressed, "242: the last held tick")
	Sim.step(1)
	assert_false(plate.pressed, "243: the dozing holder weighs nothing - the plate lets go")
	assert_true(_party(p2).is_dozing_shown())
	# One tap of Down and he holds it again.
	_hold(1, Defs.IN_DOWN)
	Sim.step(1)
	assert_true(plate.pressed, "any input of his own wakes him: the plate is held again")


func test_the_zzz_soon_bubble_shows_from_the_170th_quiet_tick_and_the_zzz_from_the_243rd() -> void:
	assert_eq(HeroParty.IDLE_WARN_TICKS, 170, "G58: the warning starts 73 ticks (3 s) before the doze")
	assert_true(HeroParty.IDLE_WARN_TICKS < IDLE)
	var level: Level = _load(2)
	var p1: PlayerBase = level.player
	var p2: PlayerBase = level.get_hero(1)
	# P1 holds a key on the spot (wf11 R6: were he to walk on, the view would go with him once P2 dozes and the leash
	# would make the sleeper an egg - tests/test_world_party.gd; an egg shows no bubble).
	_hold(0, Defs.IN_SWAP)
	_tap(1)
	var first_warning: int = -1
	var first_zzz: int = -1
	var both: int = 0
	var warning_ticks: int = 0
	for t: int in range(1, IDLE + 40):
		Sim.step(1)
		var warning: bool = _party(p2).is_idle_warning_shown()
		var zzz: bool = _party(p2).is_dozing_shown()
		if warning and first_warning < 0:
			first_warning = t
		if zzz and first_zzz < 0:
			first_zzz = t
		if warning and zzz:
			both += 1
		if warning:
			warning_ticks += 1
		if t == HeroParty.IDLE_WARN_TICKS:
			assert_false(p2.is_idle(), "warned, not idle: he still counts for every rule")
			assert_true(p2.counts_for_coop())
	assert_eq(first_warning, HeroParty.IDLE_WARN_TICKS, "the bubble appears on the 170th quiet tick, not before")
	assert_eq(first_zzz, IDLE, "the Zzz on the 243rd, not before")
	assert_eq(warning_ticks, IDLE - HeroParty.IDLE_WARN_TICKS, "73 ticks of warning, then the Zzz replaces it")
	assert_eq(both, 0, "never both at once")
	assert_false(_party(p1).is_idle_warning_shown(), "P1 holds a key the whole time: no bubble")
	# His next input clears whichever shows; the warning comes back 170 ticks later.
	_tap(1)
	Sim.step(1)
	assert_false(_party(p2).is_dozing_shown())
	assert_false(_party(p2).is_idle_warning_shown())
	Sim.step(HeroParty.IDLE_WARN_TICKS - 2)
	assert_false(_party(p2).is_idle_warning_shown(), "169 quiet ticks after the tap")
	Sim.step(1)
	assert_true(_party(p2).is_idle_warning_shown(), "170 again")
	_hold(1, Defs.IN_LOOK)
	Sim.step(1)
	assert_false(_party(p2).is_idle_warning_shown(), "an input during the warning ends it: he never dozed")
	assert_false(p2.is_idle())


func test_an_untouched_partner_shows_the_same_bubble_from_his_170th_tick() -> void:
	var level: Level = _load(2)
	var p2: PlayerBase = level.get_hero(1)
	_hold(0, Defs.IN_SWAP)  # P1 plays on the spot (R6: a P1 who walks off takes the view, and the leash the sleeper)
	_hold(1, 0)
	Sim.step(HeroParty.IDLE_WARN_TICKS - 1)
	assert_true(p2.is_idle(), "never pressed anything: counted by no rule from the start (G33)")
	assert_false(_party(p2).is_idle_warning_shown(), "but no picture before his 170th tick")
	assert_false(_party(p2).is_dozing_shown())
	Sim.step(1)
	assert_true(_party(p2).is_idle_warning_shown(), "the 170th: Zzz soon")
	Sim.step(IDLE - HeroParty.IDLE_WARN_TICKS)
	assert_true(_party(p2).is_dozing_shown(), "the 243rd: Zzz")
	assert_false(_party(p2).is_idle_warning_shown())


func test_the_warning_bubble_is_a_picture_only_an_egg_shows_none() -> void:
	var level: Level = _load(2)
	var p2: PlayerBase = level.get_hero(1)
	_hold(0, Defs.IN_SWAP)
	_tap(1)
	Sim.step(HeroParty.IDLE_WARN_TICKS)
	assert_true(_party(p2).is_idle_warning_shown())
	var mark: HeroParty.IdleMark = _party(p2)._idle_mark
	assert_eq(mark.mode, HeroParty.IdleMark.Mode.WARNING)
	assert_eq(mark.ticks_left, IDLE - HeroParty.IDLE_WARN_TICKS, "73 ticks to the doze")
	# The pulse: full and dim halves, quicker in the last second (the alpha only - nothing else moves).
	var alphas: Dictionary = {}
	for t: int in 40:
		Sim.step(1)
		alphas[snappedf(mark.modulate.a, 0.01)] = true
	assert_eq(alphas.size(), 2, "it blinks between two alphas (%s)" % [alphas.keys()])
	# An egg shows neither picture.
	p2.go_down(&"voluntary")
	Sim.step(1)
	assert_false(_party(p2).is_idle_warning_shown(), "an egg shows no bubble")
	assert_false(_party(p2).is_dozing_shown())


# =================================================================================================================
# Single-player and versus: never idle
# =================================================================================================================

func test_single_player_never_counts_idle_ticks() -> void:
	var level: Level = _load(1)
	var hero: PlayerBase = level.player
	Sim.step(IDLE + 20)
	assert_false(hero.is_idle(), "a party of one is the 1.0 hero")
	assert_eq(hero.input_idle_ticks, 0, "nothing is counted")
	assert_true(hero.counts_for_coop(), "counts_for_coop is is_party_targetable for a party of one")
	assert_false(_party(hero).is_dozing_shown())
	assert_false(_party(hero).is_idle_warning_shown(), "G58: single-player never shows the warning bubble")
	assert_null(_party(hero)._idle_mark, "no idle picture is ever made for a party of one")


func test_versus_heroes_are_never_idle() -> void:
	var level: Level = _load(2, Defs.GameMode.VERSUS)
	Sim.step(IDLE + 20)
	for hero: PlayerBase in level.contact_order():
		assert_false(hero.is_idle(), "versus: P%d is never idle" % (hero.slot + 1))
		assert_false(_party(hero).is_dozing_shown())
		assert_false(_party(hero).is_idle_warning_shown(), "G58: versus never shows the warning bubble")


# =================================================================================================================
# The PartyDriver's rules
# =================================================================================================================

## P1 falls with UP held from 60 px onto P2 (x = 200) for 30 ticks: the most negative yvel seen.
func _fall_on_p2_with_up(level: Level) -> int:
	var p1: PlayerBase = level.player
	p1.end_totem_ride()
	p1.teleport(Vector2i(200, FLOOR_Y - 60))
	p1.yvel = 64
	p1.grounded = false
	p1.no_jump = Tuning.NO_JUMP_TICKS
	_hold(0, Defs.IN_UP)
	var low_yvel: int = 0
	for i: int in 30:
		Sim.step(1)
		low_yvel = mini(low_yvel, p1.yvel)
	_hold(0, 0)
	return low_yvel


func test_no_shoulder_hop_off_an_idle_partners_head() -> void:
	var level: Level = _load(2)
	var p2: PlayerBase = level.get_hero(1)
	var driver: PartyDriver = level.party_driver as PartyDriver
	p2.teleport(Vector2i(200, FLOOR_Y))
	_tap(1)
	assert_true(driver.is_active(p2))
	assert_eq(_fall_on_p2_with_up(level), PartyTuning.SHOULDER_HOP_YVEL, "an active partner: the full Shoulder Hop")
	Sim.step(IDLE)
	assert_true(p2.is_idle())
	assert_false(driver.is_active(p2), "idle: not active any more")
	assert_true(_fall_on_p2_with_up(level) > Tuning.BOUNCE_YVEL_UP + 24, "a dozing head is no springboard")
	_tap(1)
	assert_eq(_fall_on_p2_with_up(level), PartyTuning.SHOULDER_HOP_YVEL, "awake again: the hop is back")


## P1 falls (no UP) from 40 px over P2's feet at x = 200 for 12 ticks.
func _drop_p1_on_p2(level: Level) -> void:
	var p1: PlayerBase = level.player
	level.get_hero(1).teleport(Vector2i(200, FLOOR_Y))
	p1.teleport(Vector2i(200, FLOOR_Y - 40))
	p1.yvel = 64
	p1.grounded = false
	p1.no_jump = Tuning.NO_JUMP_TICKS
	Sim.step(12)


func test_an_idle_partners_head_is_no_platform() -> void:
	var level: Level = _load(2)
	var p1: PlayerBase = level.player
	var p2: PlayerBase = level.get_hero(1)
	_hold(0, Defs.IN_SWAP)
	Sim.step(1)
	assert_true(p2.is_idle(), "P2's player never pressed anything")
	_drop_p1_on_p2(level)
	assert_null(p1.totem_carrier, "no Totem Ride on a dozing head (G33): P1 passes through")
	assert_eq(p1.sim_pos.y, FLOOR_Y, "down to the floor")
	# The same drop once P2's player is there.
	_hold(1, Defs.IN_SWAP)
	_drop_p1_on_p2(level)
	assert_eq(p1.totem_carrier, p2, "a partner who plays carries him")


func test_an_idle_hero_starts_no_ride_on_his_partner() -> void:
	var level: Level = _load(2)
	var p1: PlayerBase = level.player
	_hold(1, Defs.IN_SWAP)
	Sim.step(1)
	assert_true(p1.is_idle(), "P1's player never pressed anything")
	_drop_p1_on_p2(level)
	assert_null(p1.totem_carrier, "a dozing body falling onto a partner who plays rides nothing")
	assert_eq(p1.sim_pos.y, FLOOR_Y)


func test_a_ride_ends_when_the_carrier_or_the_rider_dozes_off() -> void:
	var level: Level = _load(2)
	var p1: PlayerBase = level.player
	var p2: PlayerBase = level.get_hero(1)
	_hold(0, Defs.IN_SWAP)
	_hold(1, Defs.IN_SWAP)
	_drop_p1_on_p2(level)
	assert_eq(p1.totem_carrier, p2, "both play: a Totem Ride")
	_hold(1, 0)
	Sim.step(IDLE - 2)
	assert_eq(p1.totem_carrier, p2, "the carrier is still there")
	Sim.step(2)
	assert_true(p2.is_idle())
	assert_null(p1.totem_carrier, "his carrier dozed off: the rider falls through")
	assert_null(p2.totem_rider)
	Sim.step(12)
	assert_eq(p1.sim_pos.y, FLOOR_Y, "down to the floor")
	# The other way round: the rider dozes off.
	_hold(1, Defs.IN_SWAP)
	_drop_p1_on_p2(level)
	assert_eq(p1.totem_carrier, p2, "riding again")
	_hold(0, 0)
	Sim.step(IDLE)
	assert_true(p1.is_idle())
	assert_null(p1.totem_carrier, "a dozing rider falls off")


func test_an_idle_croucher_is_no_windbreak() -> void:
	var level: Level = _load(2)
	var p1: PlayerBase = level.player
	var p2: PlayerBase = level.get_hero(1)
	var driver: PartyDriver = level.party_driver as PartyDriver
	level.set_wind(40)
	p2.teleport(Vector2i(200, FLOOR_Y))
	p1.teleport(Vector2i(200 - 32, FLOOR_Y))
	_hold(1, Defs.IN_DOWN)
	Sim.step(3)
	assert_eq(p2.state, Defs.HeroState.CROUCH)
	assert_eq(level.wind_for(p1), 0, "a crouching partner who is there: the lee")
	# A crouch needs Down held, so a dozing croucher only exists by the rule's own test: the windbreak query asks it.
	p2.idle = true
	assert_false(driver.in_lee(level.contact_order(), p1, 1), "an idle partner shelters nobody")
	p2.idle = false
	assert_true(driver.in_lee(level.contact_order(), p1, 1))


func test_an_idle_heros_bounce_relays_nothing() -> void:
	var level: Level = _load(2, Defs.GameMode.COOP, "bonus")
	var p1: PlayerBase = level.player
	var p2: PlayerBase = level.get_hero(1)
	var driver: PartyDriver = level.party_driver as PartyDriver
	var enemy: SimEntity = SimEntity.new()
	assert_true(driver.relay_active())
	assert_eq(driver.relay_bounce_count(enemy, p1, 11), 11)
	p2.idle = true
	assert_eq(driver.relay_bounce_count(enemy, p2, 11), 11, "a dozing body dropped on it is not the other hero")
	assert_eq(driver.relay_bounce_count(enemy, p1, 11), 11, "and it does not count as the last bouncer either")
	p2.idle = false
	assert_eq(driver.relay_bounce_count(enemy, p2, 11), 12, "the partner who plays: the relay")
	enemy.free()


func test_the_nearest_coop_hero_skips_a_dozing_partner_but_targeting_does_not() -> void:
	var level: Level = _load(2)
	var p1: PlayerBase = level.player
	var p2: PlayerBase = level.get_hero(1)
	var post: SimEntity = SimEntity.new()
	post.sim_pos = Vector2i(300, FLOOR_Y)
	p1.teleport(Vector2i(100, FLOOR_Y))
	p2.teleport(Vector2i(320, FLOOR_Y))
	assert_eq(level.nearest_coop_hero(post), p2, "both play: the nearer one")
	p2.idle = true
	assert_eq(level.nearest_coop_hero(post), p1, "P2 dozes: a position rule reads P1 (no bait)")
	assert_eq(level.target_hero(post), p2, "enemies still go for the nearer body")
	p1.idle = true
	assert_null(level.nearest_coop_hero(post), "nobody plays")
	p1.idle = false
	p2.idle = false
	post.free()


func test_the_nearest_coop_hero_of_a_party_of_one_is_the_target() -> void:
	var solo: Level = _load(1)
	var other: SimEntity = SimEntity.new()
	assert_eq(solo.nearest_coop_hero(other), solo.player)
	assert_eq(solo.nearest_coop_hero(other), solo.target_hero(other), "a party of one: target_hero")
	other.free()


func test_an_idle_partner_braces_nothing() -> void:
	var level: Level = _load(2)
	var p1: PlayerBase = level.player
	var p2: PlayerBase = level.get_hero(1)
	p1.teleport(Vector2i(200, FLOOR_Y))
	p2.teleport(Vector2i(200 + PartyTuning.BRACE_GAP_PX, FLOOR_Y))
	_hold(0, Defs.IN_DOWN)
	_hold(1, Defs.IN_DOWN)
	Sim.step(3)
	assert_true(p1.braces_with(p2), "both crouch side by side: a Brace Wall")
	assert_eq(p1.brace_partner(), p2)
	p2.idle = true
	assert_false(p1.braces_with(p2), "never with an idle partner")
	assert_false(p2.braces_with(p1))
	assert_null(p1.brace_partner())
	p2.idle = false
