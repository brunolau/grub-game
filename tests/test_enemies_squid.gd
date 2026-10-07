extends TestCase
## Inkjaw, the Grotto Squid (scripts/bosses/squid.gd, scripts/projectiles/boss_ink.gd; DESIGN.md B.3, GAMEPLAY.md 13.6;
## PLAN.md P2.2, owner enemies-B) on its test level levels/test_enemies_squid.lvl, in the real level scene with the real
## hero(es) (the Lab of tests/test_enemies_tusker.gd).
##
## Pinned here (DESIGN.md B.0): the bubbles, the rising tentacle, the open jaws and the island's rumble each show
## their attack 10+ ticks ahead; every attack can be escaped; hits never stop or lengthen a surfacing (no stun-lock)
## and count at most once per BOSS_HIT_COOLDOWN; an ink blob dims the screen 66 ticks; the whirlpool sinks the middle
## island under two rafts on a reversing current; the club beats the solo form on a scripted route (Beginner and
## Expert); the co-op flinch window is shorter than the measured solo minimum; the single-hero search cannot hurt the
## co-op form's Tentacle Lock.

const Lab = preload("res://tests/test_enemies_tusker.gd").Lab
const LEVEL_PATH: String = "res://levels/test_enemies_squid.lvl"
const BOSS_ID: String = "bosses/squid"
const GAP_A: int = 112
const GAP_B: int = 208
const SURFACE: int = 144

var _lab: Lab = null
var _was_manual: bool = false


var _t0_tmp: int = 0


func before_each() -> void:
	_t0_tmp = Time.get_ticks_msec()
	_was_manual = Sim.manual
	_lab = Lab.new()


func after_each() -> void:
	print("    TIMING %d ms" % (Time.get_ticks_msec() - _t0_tmp))
	GameInput.clear_scripted()
	Sim.stop()
	Sim.manual = _was_manual
	Game.new_game(Defs.Difficulty.BEGINNER)
	Game.begin_level(&"")
	Audio.stop_music(0.0)
	Lab.cleanup_flow(get_tree())
	_lab = null


func _open(difficulty: int = Defs.Difficulty.BEGINNER, party: int = 1, coop_form: bool = false,
		weapon: int = Defs.Weapon.CLUB) -> Squid:
	assert_true(_lab.open(self, LEVEL_PATH, BOSS_ID, difficulty, party, coop_form, weapon), "the test level came up")
	return _lab.boss as Squid


func _fresh() -> void:
	if _lab != null and _lab.level != null and is_instance_valid(_lab.level):
		_lab.level.free()
	_lab = Lab.new()


# =================================================================================================================
# Basics
# =================================================================================================================

func test_inkjaw_reads_its_grotto_and_surfaces_after_its_bubbles() -> void:
	var squid: Squid = _open()
	assert_eq(squid.max_hp, Squid.SQUID_HP_BEGINNER)
	assert_eq(squid.surface_y, SURFACE)
	assert_eq(squid.gaps, [GAP_A, GAP_B] as Array[int], "the two gaps between the islands")
	assert_eq(squid._island, Vector2i(8, 11), "the middle island")
	_lab.step(PackedInt32Array([0]))
	assert_true(squid.fighting)
	assert_eq(squid.get_state(), Squid.State.DIVE)
	var bubbles: int = 0
	var up_at: int = -1
	for t: int in 120:
		_lab.step(PackedInt32Array([0]))
		bubbles += 1 if squid.get_state() == Squid.State.BUBBLES else 0
		if up_at < 0 and squid.is_up():
			up_at = t
	assert_eq(bubbles, Squid.SQUID_BUBBLE_TICKS, "22 ticks of bubbles")
	assert_true(squid.gaps.has(squid.get_spot()), "it came up in a gap")
	assert_true(up_at > 0)
	for case: Array in [[Defs.Difficulty.EXPERT, false, 225], [Defs.Difficulty.BEGINNER, true, 187],
			[Defs.Difficulty.EXPERT, true, 280]]:
		_fresh()
		var other: Squid = _open(int(case[0]), 1, bool(case[1]))
		assert_eq(other.max_hp, int(case[2]))


## An ink blob costs a heart and 6 bones and dims the screen to the night palette for 66 ticks; then the light returns.
func test_an_ink_blob_dims_the_screen() -> void:
	var squid: Squid = _open()
	var hero: PlayerBase = _lab.hero()
	_lab.step(PackedInt32Array([0]))
	var hearts: int = hero.run.hearts
	var ink: BossInk = _lab.level.spawn(&"projectiles/boss_ink", hero.sim_pos + Vector2i(0, -10),
			{"xvel": 0, "yvel": 0, "yacc": 0}) as BossInk
	ink.set_squid(squid)
	_lab.step(PackedInt32Array([0]))
	assert_eq(hero.run.hearts, hearts - 1, "a heart")
	assert_true(_lab.level.dark, "the night palette")
	assert_eq(squid.ink_hits, 1)
	for t: int in Squid.SQUID_DIM_TICKS - 2:
		_lab.step(PackedInt32Array([0]))
	assert_true(_lab.level.dark, "for 66 ticks")
	_lab.step(PackedInt32Array([0]))
	_lab.step(PackedInt32Array([0]))
	assert_false(_lab.level.dark, "then the light is back")


## Phase 3: the middle island rumbles 22 ticks and sinks; two rafts take its place (a hero standing on the island ends
## up on a raft) and ride a current over the pool that reverses every 132 ticks.
func test_the_whirlpool_sinks_the_middle_island_under_two_rafts() -> void:
	var squid: Squid = _open()
	var hero: PlayerBase = _lab.hero()
	squid.hp = 40
	hero.respawn_at(Vector2i(160, SURFACE))
	var rumble: int = 0
	var t: int = 0
	while t < 200 and not squid.is_whirlpool():
		Lab.top_up(hero)
		_lab.step(PackedInt32Array([0]))
		t += 1
		rumble += 1 if squid.get_state() == Squid.State.RUMBLE else 0
	assert_true(squid.is_whirlpool(), "the island sank")
	assert_eq(rumble, Squid.SQUID_RUMBLE_TICKS, "after a 22-tick rumble")
	var grid: TileGrid = _lab.level.grid
	for col: int in range(8, 12):
		assert_eq(grid.get_char(col, 9), TileGrid.CH_LIQUID, "column %d is water now" % col)
	assert_eq(squid.get_rafts().size(), 2, "two rafts")
	for k: int in 6:
		_lab.step(PackedInt32Array([0]))
	assert_false(hero.dead, "the hero on the island stands on a raft")
	assert_true(hero.on_platform, "riding it")
	var first: Vector2i = (squid.get_rafts()[1] as SimEntity).sim_pos
	for k: int in 20:
		Lab.top_up(hero)
		_lab.step(PackedInt32Array([0]))
	assert_ne((squid.get_rafts()[1] as SimEntity).sim_pos.x, first.x, "the current moves the rafts")
	assert_eq(str(squid._current.spawn_params["dir"]), "r")
	for k: int in Squid.SQUID_CURRENT_FLIP:
		Lab.top_up(hero)
		_lab.step(PackedInt32Array([0]))
	assert_eq(str(squid._current.spawn_params["dir"]), "l", "the current reversed")
	# A death resets the grotto.
	_lab.level.reset_entities()
	assert_false(squid.is_whirlpool())
	assert_eq(grid.get_char(9, 9), TileGrid.CH_SOLID_A, "the island is back")


# =================================================================================================================
# B.0 fairness
# =================================================================================================================

## The whole Expert fight played by the club bot, watched: every surfacing after 22 ticks of bubbles over its gap,
## every slam after its tentacle rose 12 ticks over the marked spot, every ink blob after the jaws opened 10 ticks,
## the island's sinking after a 22-tick rumble.
func test_every_attack_shows_itself_10_ticks_ahead() -> void:
	var squid: Squid = _open(Defs.Difficulty.EXPERT)
	var hero: PlayerBase = _lab.hero()
	var bot: SquidBot = SquidBot.new()
	var watch: Dictionary = {"bubbles": [], "tentacle": [], "jaws": [], "rumble": []}
	var last: int = -1
	var since: int = 0
	var mark_since: int = -1
	var jaws_since: int = -1
	var spits: int = 0
	var t: int = 0
	while t < 9000 and not squid.dead:
		Lab.top_up(hero)
		_lab.step(PackedInt32Array([bot.flags(hero, squid, _lab.level)]))
		t += 1
		var state: int = squid.get_state()
		if state != last:
			if state == Squid.State.RISE:
				(watch["bubbles"] as Array).append(since)
			if last == Squid.State.RUMBLE:
				(watch["rumble"] as Array).append(since)
			last = state
			since = 0
		since += 1
		if squid.get_slam_mark() >= 0:
			mark_since = mark_since + 1 if mark_since >= 0 else 1
		elif mark_since >= 0:
			if squid.get_slam_rect().size.x > 0:
				(watch["tentacle"] as Array).append(mark_since)
			mark_since = -1
		if squid.get_jaws() > 0:
			jaws_since = jaws_since + 1 if jaws_since >= 0 else 1
		if squid.spits > spits:
			spits = squid.spits
			(watch["jaws"] as Array).append(jaws_since + 1)
			jaws_since = -1
	print("    Inkjaw telegraphs (Expert club fight, %d ticks): bubbles %s, tentacle %s, jaws %s, rumble %s" % [t,
		_span(watch["bubbles"]), _span(watch["tentacle"]), _span(watch["jaws"]), watch["rumble"]])
	assert_true(squid.dead, "the fight was played to its end")
	for key: String in ["bubbles", "tentacle", "jaws", "rumble"]:
		assert_false((watch[key] as Array).is_empty(), "%s seen" % key)
		for value: Variant in watch[key]:
			assert_true(int(value) >= 10, "%s: %d ticks ahead" % [key, int(value)])
	# And each its own length (DESIGN.md B.3).
	var lengths: Dictionary = {"bubbles": Squid.SQUID_BUBBLE_TICKS, "tentacle": Squid.SQUID_TENTACLE_RISE_TICKS,
		"jaws": Squid.SQUID_JAWS_TICKS, "rumble": Squid.SQUID_RUMBLE_TICKS}
	for key: String in lengths:
		if not (watch[key] as Array).is_empty():
			assert_eq(int((watch[key] as Array).min()), int(lengths[key]), "%s lasts its %d ticks" % [key, lengths[key]])


## Every attack can be escaped: a hero who only dodges (keeps away from the surfacing gap, steps out from under the
## tentacle's shadow, keeps clear of the blob's arc) is never hurt in 1500 ticks of each phase.
func test_every_attack_can_be_escaped() -> void:
	for phase_hp: int in [150, 75, 40]:
		var squid: Squid = _open()
		squid.hp = phase_hp
		var bot: SquidBot = SquidBot.new()
		bot.attack = false
		var hero: PlayerBase = _lab.hero()
		var hurts: int = 0
		for t: int in 1500:
			_lab.step(PackedInt32Array([bot.flags(hero, squid, _lab.level)]))
			if hero.hit_timer == Tuning.HIT_TIMER - 1 or hero.dead:
				hurts += 1
			if hero.dead:
				break
		print("    dodging phase %d: %d surfacings, %d slams, %d spits, %d hurts" % [squid.get_phase(), squid.surfacings,
			squid.slams, squid.spits, hurts])
		assert_true(squid.slams >= 5, "it kept slamming")
		assert_eq(hurts, 0, "phase %d: never hurt while dodging" % squid.get_phase())
		_fresh()


## Hits never stop it: a perfect thrower (an axe on the head on every tick it is up) sees every surfacing last its 44
## ticks and the next one come; hits are BOSS_HIT_COOLDOWN apart; the fight ends.
func test_hits_never_stun_lock_it() -> void:
	var squid: Squid = _open(Defs.Difficulty.EXPERT)
	var hero: PlayerBase = _lab.hero()
	var hit_ticks: Array[int] = []
	var ups: Array[int] = []
	var up_since: int = 0
	var t: int = 0
	while t < 6000 and not squid.dead:
		Lab.top_up(hero)
		if squid.is_up():
			_shot_at(squid.get_head_rect())
		var hp: int = squid.hp
		var was_up: bool = squid.is_up()
		_lab.step(PackedInt32Array([0]))
		t += 1
		if squid.hp < hp:
			hit_ticks.append(t)
		if squid.is_up():
			up_since += 1
		elif was_up and squid.get_state() == Squid.State.SINK:
			ups.append(up_since)
			up_since = 0
	print("    perfect thrower: beaten after %d ticks, %d hits, surfacings lasted %s" % [t, hit_ticks.size(),
		_span(ups)])
	assert_true(squid.dead)
	for i: int in range(1, hit_ticks.size()):
		assert_true(hit_ticks[i] - hit_ticks[i - 1] >= Tuning.BOSS_HIT_COOLDOWN)
	for up: int in ups:
		assert_eq(up, Squid.SQUID_UP_TICKS, "every surfacing lasts its 44 ticks however often it is hit")


# =================================================================================================================
# The club beats the solo form
# =================================================================================================================

func test_the_club_beats_the_solo_form_on_its_scripted_routes() -> void:
	for case: Array in [[Defs.Difficulty.BEGINNER, ROUTE_BEGINNER], [Defs.Difficulty.EXPERT, ROUTE_EXPERT]]:
		var squid: Squid = _open(int(case[0]))
		var hero: PlayerBase = _lab.hero()
		var route: PackedInt32Array = Lab.parse_route(str(case[1]))
		var played: int = _lab.play([route] as Array[PackedInt32Array], func() -> bool: return squid.dead)
		print("    route difficulty %d: beaten on tick %d of %d, hero %d hearts %d bones" % [case[0], played,
			route.size(), hero.run.hearts, hero.run.bones])
		assert_true(squid.dead, "difficulty %d: the club route beats Inkjaw" % case[0])
		assert_false(hero.dead)
		assert_eq(hero.run.weapon, Defs.Weapon.CLUB)
		_fresh()


func test_the_club_bot_still_wins() -> void:
	for difficulty: int in [Defs.Difficulty.BEGINNER, Defs.Difficulty.EXPERT]:
		var squid: Squid = _open(difficulty)
		var hero: PlayerBase = _lab.hero()
		var bot: SquidBot = SquidBot.new()
		var hurts: int = 0
		var t: int = 0
		var trace: bool = OS.get_environment("SQUID_TRACE") != ""
		var last: Vector3i = Vector3i(-1, -1, -1)
		while t < 9000 and not squid.dead and not hero.dead:
			_lab.step(PackedInt32Array([bot.flags(hero, squid, _lab.level)]))
			t += 1
			if hero.hit_timer == Tuning.HIT_TIMER - 1:
				hurts += 1
				if trace:
					print("      t%d HURT hero %s squid %d at %d" % [t, hero.sim_pos, squid.get_state(), squid.get_spot()])
			var now: Vector3i = Vector3i(squid.get_state(), squid.hp, squid.get_spot())
			if trace and now != last:
				last = now
				print("      t%d state %d hp %d spot %d hero %s" % [t, now.x, now.y, now.z, hero.sim_pos])
		print("    club bot difficulty %d: won %s in %d ticks, %d hurts, %d hearts left%s" % [difficulty, squid.dead,
			t, hurts, hero.run.hearts, " (DIED)" if hero.dead else ""])
		if OS.get_environment("SQUID_ROUTE") != "":
			print("ROUTE %d %s" % [difficulty, Lab.route_text(_lab.streams[0])])
		assert_true(squid.dead, "difficulty %d" % difficulty)
		assert_false(hero.dead)
		_fresh()


# =================================================================================================================
# The co-op form: the Tentacle Lock
# =================================================================================================================

## While up in phases 1-2 the head is armoured; a tentacle flinches only for a strike from its own side; both flinching
## by the two heroes open the head 33 ticks; one hero's two flinches never open it; the flinch is the capped window.
func test_coop_tentacle_lock() -> void:
	var squid: Squid = _open(Defs.Difficulty.BEGINNER, 2, true)
	var p1: PlayerBase = _lab.hero(0)
	var p2: PlayerBase = _lab.hero(1)
	_wake_both()
	_lab.step(PackedInt32Array([0, 0]))
	assert_eq(squid.flinch_window(), Squid.SQUID_FLINCH_BEGINNER,
			"G34: a slot-bound twin is exempt from the solo_min cap - 24 on Beginner")
	Game.difficulty = Defs.Difficulty.EXPERT
	assert_eq(squid.flinch_window(), Squid.SQUID_FLINCH_EXPERT, "16 on Expert")
	Game.difficulty = Defs.Difficulty.BEGINNER
	_hold_up(squid, GAP_A)
	p1.respawn_at(Vector2i(GAP_A - 37, SURFACE))
	p2.respawn_at(Vector2i(GAP_A + 37, SURFACE))
	_shot_at(squid.get_head_rect(), 0)
	_step2()
	assert_eq(squid.hp, squid.max_hp, "the crossed tentacles armour the head")
	_shot_at(squid.get_tentacle_rect(1), 0)
	_step2()
	assert_eq(squid.get_flinch(1), 0, "P1 stands left: the right tentacle does not flinch for him")
	_shot_at(squid.get_tentacle_rect(-1), 0)
	_step2()
	assert_true(squid.get_flinch(-1) > 0, "the left one flinches for P1")
	assert_eq(squid.get_open_ticks(), 0)
	_shot_at(squid.get_tentacle_rect(1), 1)
	_step2()
	assert_true(squid.get_open_ticks() > 0, "both flinch: the head opens")
	assert_eq(squid.get_open_ticks(), Squid.SQUID_OPEN_TICKS, "for 33 ticks from the next")
	_shot_at(squid.get_head_rect(), 0)
	_step2()
	assert_eq(squid.hp, squid.max_hp - 20, "and takes a hit")
	# One hero's two flinches never open it.
	for t: int in Squid.SQUID_OPEN_TICKS:
		_hold_up(squid, GAP_A)
		_step2()
	assert_eq(squid.get_open_ticks(), 0, "the head closed again after its 33 ticks")
	_hold_up(squid, GAP_A)
	p1.respawn_at(Vector2i(GAP_A - 37, SURFACE))
	_shot_at(squid.get_tentacle_rect(-1), 0)
	_step2()
	_hold_up(squid, GAP_A)
	p1.respawn_at(Vector2i(GAP_A + 37, SURFACE))
	_shot_at(squid.get_tentacle_rect(1), 0)
	_step2()
	assert_true(squid.get_flinch(-1) > 0 and squid.get_flinch(1) > 0, "both flinch ...")
	assert_eq(squid.get_open_ticks(), 0, "... for the same hero: shut")


## G33: a dozing partner counts for none of the lock's rules. With P2 idle on the right flank the count-in never plays;
## a "strike" credited to the dozing hero flinches nothing; P1 flinches his own tentacle, and the head stays shut. The
## moment P2's player presses something the count-in starts, and his strike on his tentacle opens the head.
func test_coop_an_idle_partner_counts_for_nothing() -> void:
	var squid: Squid = _open(Defs.Difficulty.BEGINNER, 2, true)
	var p1: PlayerBase = _lab.hero(0)
	var p2: PlayerBase = _lab.hero(1)
	_lab.step(PackedInt32Array([0, 0]))
	assert_true(p2.is_idle(), "a partner who never pressed anything is idle (G33)")
	_lab.wake(0)
	_hold_up(squid, GAP_A)
	p1.respawn_at(Vector2i(GAP_A - 37, SURFACE))
	p2.respawn_at(Vector2i(GAP_A + 37, SURFACE))
	var counted: bool = false
	for t: int in 40:
		_hold_up(squid, GAP_A)
		_step2()
		counted = counted or squid._count_in >= 0
	assert_false(counted, "no count-in with a dozing hero on the right flank")
	_hold_up(squid, GAP_A)
	_shot_at(squid.get_tentacle_rect(1), 1)
	_step2()
	assert_eq(squid.get_flinch(1), 0, "the dozing hero's 'strike' flinches nothing")
	_hold_up(squid, GAP_A)
	_shot_at(squid.get_tentacle_rect(-1), 0)
	_step2()
	assert_true(squid.get_flinch(-1) > 0, "P1 flinches his tentacle")
	assert_eq(squid.get_open_ticks(), 0, "and the head stays shut")
	# P2's player presses something: he counts, the count-in runs, his strike opens the head.
	_hold_up(squid, GAP_A)
	_lab.step(PackedInt32Array([0, Defs.IN_DOWN]))
	assert_true(p2.counts_for_coop())
	assert_true(squid._count_in >= 0, "the count-in starts")
	_hold_up(squid, GAP_A)
	_shot_at(squid.get_tentacle_rect(1), 1)
	_step2()
	assert_true(squid.get_open_ticks() > 0, "both flinch for the two players: the head opens")


## V3.d fairness per hero: whichever hero it goes for, the tentacle's shadow marks HIS spot 12 ticks before the slam and
## he escapes it by stepping out from under it; the ink blob (phase 2) is aimed at him after the 10-tick jaws; and the
## lock opens whichever hero takes which flank.
func test_coop_form_is_fair_to_either_hero() -> void:
	for slot: int in 2:
		var squid: Squid = _open(Defs.Difficulty.EXPERT, 2, true)
		var me: PlayerBase = _lab.hero(slot)
		var mate: PlayerBase = _lab.hero(1 - slot)
		_wake_both()
		_step2()
		# The slam at him: the target is the nearer hero.
		me.respawn_at(Vector2i(GAP_A - 50, SURFACE))
		mate.respawn_at(Vector2i(GAP_B + 60, SURFACE))
		squid._held_target = null
		_hold_up(squid, GAP_A)
		squid._timer = Squid.SQUID_TENTACLE_AT - 1
		_step2()
		assert_eq(squid.get_slam_mark(), me.sim_pos.x, "slot %d: the shadow marks his spot" % slot)
		var marked: int = 0
		var hurt: bool = false
		var slammed: bool = false
		for t: int in 30:
			# He steps out from under it (outward, away from the squid) while it rises.
			var flags: PackedInt32Array = PackedInt32Array([0, 0])
			flags[slot] = Defs.IN_LEFT if t < 6 else 0
			_lab.step(flags)
			marked += 1 if squid.get_slam_mark() >= 0 else 0
			slammed = slammed or squid.get_slam_rect().size.x > 0
			hurt = hurt or me.hit_timer > 0
		assert_eq(marked + 1, Squid.SQUID_TENTACLE_RISE_TICKS, "slot %d: 12 ticks of shadow" % slot)
		assert_true(slammed, "slot %d: it slammed" % slot)
		assert_false(hurt, "slot %d: he stepped out from under it" % slot)
		# The ink (phase 2) at him.
		squid.hp = squid.max_hp / 2
		squid._held_target = null
		me.respawn_at(Vector2i(GAP_A - 50, SURFACE))
		_hold_up(squid, GAP_A)
		squid._timer = Squid.SQUID_JAWS_AT - 1
		var jaws: int = 0
		var spits: int = squid.spits
		for t: int in 20:
			_lab.step(PackedInt32Array([0, 0]))
			if squid.spits > spits:
				break
			jaws += 1 if squid.get_jaws() > 0 else 0
		assert_true(jaws >= 10 - 1, "slot %d: the jaws open 10 ticks first (%d seen open)" % [slot, jaws])
		assert_eq(squid.facing, signi(me.sim_pos.x - squid.sim_pos.x), "slot %d: the blob flies at him" % slot)
		# The lock, this hero on the left flank, then on the right.
		squid.hp = squid.max_hp
		squid.hit_cooldown = 0
		for side: int in [-1, 1]:
			_hold_up(squid, GAP_A)
			squid._flinch = [0, 0]
			squid._open = 0
			squid._part_tick = [-1000, -1000]
			me.respawn_at(Vector2i(GAP_A + side * 37, SURFACE))
			mate.respawn_at(Vector2i(GAP_A - side * 37, SURFACE))
			_hold_up(squid, GAP_A)
			_shot_at(squid.get_tentacle_rect(side), me.slot)
			_shot_at(squid.get_tentacle_rect(-side), mate.slot)
			_step2()
			assert_true(squid.get_open_ticks() > 0, "slot %d on the %s flank: the head opens" % [slot,
				"left" if side < 0 else "right"])
		_fresh()


## G35 (as corrected): every weak point the club can strike - the head while up (Hud.weak_point_rects) and the co-op
## lock's two tentacles - wherever the club routes see it surface, lies wholly inside every view the grotto's camera
## lock allows and 24 px clear of the fight HUD's band (Hud.weak_point_problem).
func test_every_weak_point_is_clear_of_the_hud() -> void:
	var worst: Array[int] = [1 << 20]
	var checked: Array[int] = [0]
	for case: Array in [[Defs.Difficulty.BEGINNER, ROUTE_BEGINNER], [Defs.Difficulty.EXPERT, ROUTE_EXPERT]]:
		var squid: Squid = _open(int(case[0]))
		var route: PackedInt32Array = Lab.parse_route(str(case[1]))
		var problems: Array[String] = []
		_lab.play([route] as Array[PackedInt32Array], func() -> bool:
			if squid.is_up() and not squid.dead:
				var rects: Array[Rect2i] = Hud.weak_point_rects(squid)
				rects.append_array([squid.get_tentacle_rect(-1), squid.get_tentacle_rect(1)])
				for rect: Rect2i in rects:
					var why: String = _lab.hud_clear(rect)
					if why != "" and problems.size() < 3:
						problems.append(why)
					worst[0] = mini(worst[0], _lab.top_clearance(rect))
					checked[0] += 1
			return squid.dead)
		assert_true(problems.is_empty(), "difficulty %d: %s" % [case[0], problems])
		_fresh()
	print("    G35: %d up-pose weak rects checked, the highest top %d px under the view's top" % [checked[0], worst[0]])
	assert_true(checked[0] > 100, "the routes saw it up (%d)" % checked[0])


## G34: the Tentacle Lock is slot-bound (two heroes' own strikes), so the flinch is the difficulty's - 24 Beginner / 16
## Expert -, not capped by one player's solo minimum, which stays a measured fact. The measurement (V3.d's one player
## with his toolkit): P1 (every hand weapon) flinches the left tentacle from the left island, then crosses over the
## squid (bouncing off its head) to flinch the right one, while his IDLE partner stands where his player could have
## hatched him (the right island, the ledge over the gap, the far end of the left island) or lies on the right island as
## an egg. The lock never opens for him - though his two flinches come inside the 24-tick Beginner flinch, they never
## pair - and no trial is faster than SQUID_SOLO_MIN_TICKS. Lighter than at G2: spent throws are freed between trials
## (Lab.flush) and a trial ends once its second flinch can no longer fall inside the first one's window.
func test_coop_one_player_never_opens_the_lock_and_the_solo_minimum_holds() -> void:
	var squid: Squid = _open(Defs.Difficulty.BEGINNER, 2, true)
	var hero: PlayerBase = _lab.hero()
	var p2: PlayerBase = _lab.hero(1)
	_lab.step(PackedInt32Array([0, 0]))
	var best: int = 100000
	var how: String = ""
	var trials: int = 0
	var opened: int = 0
	var counted: int = 0
	var window: int = squid.flinch_window()
	var spots: Array[Vector2i] = [Vector2i(GAP_A + 52, SURFACE), Vector2i(GAP_A + 8, 96), Vector2i(GAP_A - 70, SURFACE),
		Vector2i(GAP_A + 44, SURFACE)]
	var frame: PackedInt32Array = PackedInt32Array([0, 0])
	for weapon: int in [Defs.Weapon.CLUB, Defs.Weapon.HAMMER, Defs.Weapon.AXE, Defs.Weapon.BOOMERANG, Defs.Weapon.SPEAR]:
		hero.run.set_weapon(weapon)
		for jump_at: int in range(8, 13):
			for hold: int in [5, 9]:
				for strike_at: int in range(10, 26, 2):
					for entity: SimEntity in _lab.level.get_kind(Defs.Kind.HERO_PROJECTILE):
						(entity as ProjectileBase).consume()
					_lab.flush()
					squid.flinch_log.clear()
					squid._part_tick = [-1000, -1000]
					squid._flinch = [0, 0]
					squid._open = 0
					hero.respawn_at(Vector2i(GAP_A - 37, SURFACE))
					hero.facing = 1
					Lab.top_up(hero)
					_lab.wake(0)
					var pick: int = trials % spots.size()
					p2.respawn_at(spots[pick])
					if pick == spots.size() - 1:
						p2.go_down(&"voluntary")
					trials += 1
					var left_at: int = -1
					var right_at: int = -1
					for t: int in 50:
						_hold_up(squid, GAP_A)
						var flags: int = 0
						if t < 9:
							flags = Defs.IN_UP | Defs.IN_FIRE
						elif t >= jump_at and t < jump_at + hold:
							flags = Defs.IN_UP | Defs.IN_RIGHT
						elif t >= jump_at + strike_at - 1 and t < jump_at + strike_at:
							flags = Defs.IN_LEFT
						elif t >= jump_at + strike_at and t < jump_at + strike_at + 9:
							flags = Defs.IN_UP | Defs.IN_FIRE
						elif t >= jump_at and t < jump_at + strike_at:
							flags = Defs.IN_RIGHT
						frame[0] = flags
						_lab.step(frame)
						opened += 1 if squid.get_open_ticks() > 0 else 0
						counted += 1 if p2.counts_for_coop() else 0
						for entry: Vector3i in squid.flinch_log:
							if entry.y < 0 and left_at < 0:
								left_at = entry.x
							elif entry.y > 0 and right_at < 0:
								right_at = entry.x
						if right_at >= 0 or (left_at >= 0 and Sim.total_ticks - left_at > window):
							break
					if left_at >= 0 and right_at >= 0 and right_at - left_at < best:
						best = right_at - left_at
						how = "weapon %d, jump at %d held %d, strike %d later" % [weapon, jump_at, hold, strike_at]
	print("    one player from the left tentacle to the right one: %d ticks at best (%s), %d trials; open on %d ticks, partner counted on %d" % [
		best, how, trials, opened, counted])
	assert_true(best < 100000, "the search flinched both tentacles (it is not blind)")
	assert_true(best >= Squid.SQUID_SOLO_MIN_TICKS, "SQUID_SOLO_MIN_TICKS (%d) is a lower bound of the measured %d" % [
		Squid.SQUID_SOLO_MIN_TICKS, best])
	assert_true(best < Squid.SQUID_FLINCH_BEGINNER,
			"his two flinches came inside the Beginner flinch (%d < 24): the slot rule, not the window, refuses him" % best)
	assert_eq(opened, 0, "the head never opened for one player")
	assert_eq(counted, 0, "his partner never counted for a co-op rule")
	assert_eq(squid.hp, squid.max_hp)


## V3.d, the single-hero search cannot hurt the co-op form: one player with every weapon, from both islands and the
## ledge over the gap, striking forward / high / low standing and out of jumps (over the squid too), with his IDLE
## partner standing on the other flank of the gap (where the lock wants a hero), on the ledge, further out, or lying on
## the other flank as an egg, never lands a hit on the locked squid - while the same search alone hurts the solo form;
## the solo club route never hurts the co-op form.
func test_the_single_hero_search_cannot_hurt_the_coop_form() -> void:
	var coop: Dictionary = _search(true, true)
	var solo: Dictionary = _search(false, false, 20)
	print("    single-hero search: %d trials (partner idle %d / egg %d), co-op form hit %d times; solo form hit %d times in %d trials" % [
		coop["trials"], coop["idle_trials"], coop["egg_trials"], coop["hits"], solo["hits"], solo["trials"]])
	assert_true(int(coop["trials"]) >= 200)
	assert_true(int(coop["idle_trials"]) >= 150 and int(coop["egg_trials"]) >= 40, "both partner kinds were tried")
	assert_eq(int(coop["partner_counted"]), 0, "the partner never counted")
	assert_eq(int(coop["hits"]), 0, "one player never hurts the locked squid: %s" % coop["first"])
	assert_true(int(solo["hits"]) >= 20, "the same search hurts the solo form")
	var squid: Squid = _open(Defs.Difficulty.BEGINNER, 1, true)
	var route: PackedInt32Array = Lab.parse_route(ROUTE_BEGINNER)
	var lowest: Array[int] = [squid.hp]
	_lab.play([route] as Array[PackedInt32Array], func() -> bool:
		lowest[0] = mini(lowest[0], squid.hp)
		return _lab.hero().dead)
	assert_eq(lowest[0], squid.max_hp, "the solo route never hurts the co-op form")


# =================================================================================================================
# Helpers
# =================================================================================================================

func _shot_at(rect: Rect2i, owner: int = 0) -> void:
	_lab.level.spawn(&"projectiles/hero_axe", Vector2i(rect.get_center().x, rect.end.y - 1),
			{"from_hero": true, "power": 20, "xvel": 0, "yvel": 0, "yacc": 0, "owner": owner})


func _step2() -> void:
	_lab.step(PackedInt32Array([0, 0]))


func _wait2(ticks: int) -> void:
	for t: int in ticks:
		_step2()


## Keep the squid up in the gap at `x` (no slam, no spit: its UP clock held at 5).
func _hold_up(squid: Squid, x: int) -> void:
	if squid.get_state() != Squid.State.UP or squid.sim_pos.x != x:
		squid._up_x = x
		squid.teleport(Vector2i(x, SURFACE))
		squid.visible = true
		squid._state = Squid.State.UP
	squid._timer = 5
	squid._slam_timer = -1
	squid._jaws = -1


static func _span(values: Array) -> String:
	if values.is_empty():
		return "-"
	return "%d..%d (%d)" % [int(values.min()), int(values.max()), values.size()]


## Both heroes of a co-op test are players who have just pressed something (G33: they count for the co-op rules).
func _wake_both() -> void:
	_lab.wake(0)
	_lab.wake(1)


## The single-hero search against the up squid in a gap (co-op or solo form). `partner`: P2 never presses anything
## (IDLE, G33) and stands, per trial, on the other flank of the gap from P1's start (where the lock wants the second
## hero), on the ledge over the gap, further out on the other island, or lies on the other flank as an egg.
## `max_hits` > 0 ends the search at that many hits (the solo form's "not blind" check).
func _search(coop_form: bool, partner: bool, max_hits: int = 0) -> Dictionary:
	var squid: Squid = _open(Defs.Difficulty.BEGINNER, 2 if partner else 1, coop_form)
	var hero: PlayerBase = _lab.hero()
	var p2: PlayerBase = _lab.hero(1) if partner else null
	var frame: PackedInt32Array = PackedInt32Array([0, 0]) if partner else PackedInt32Array([0])
	_lab.step(frame)
	var result: Dictionary = {"trials": 0, "hits": 0, "first": "", "idle_trials": 0, "egg_trials": 0,
		"partner_counted": 0}
	var starts: Array[Vector2i] = [Vector2i(GAP_A - 37, SURFACE), Vector2i(GAP_A - 52, SURFACE),
		Vector2i(GAP_A + 37, SURFACE), Vector2i(GAP_A + 52, SURFACE), Vector2i(GAP_A - 8, 96), Vector2i(GAP_A + 8, 96)]
	for weapon: int in [Defs.Weapon.CLUB, Defs.Weapon.HAMMER, Defs.Weapon.AXE, Defs.Weapon.BOOMERANG, Defs.Weapon.SPEAR]:
		hero.run.set_weapon(weapon)
		for start: Vector2i in starts:
			var toward: int = 1 if start.x < GAP_A else -1
			for macro: PackedInt32Array in _macros(toward):
				if max_hits > 0 and int(result["hits"]) >= max_hits:
					break
				var trial: int = int(result["trials"])
				result["trials"] = trial + 1
				for entity: SimEntity in _lab.level.get_kind(Defs.Kind.HERO_PROJECTILE):
					(entity as ProjectileBase).consume()
				_lab.flush()
				squid.hp = squid.max_hp
				squid.hit_cooldown = 0
				squid._flinch = [0, 0]
				squid._open = 0
				squid._part_tick = [-1000, -1000]
				hero.respawn_at(start)
				hero.facing = toward
				Lab.top_up(hero)
				if partner:
					_lab.wake(0)
					var spots: Array[Vector2i] = [Vector2i(GAP_A + toward * 37, SURFACE), Vector2i(GAP_A + 8, 96),
						Vector2i(GAP_A + toward * 60, SURFACE), Vector2i(GAP_A + toward * 37, SURFACE)]
					var pick: int = trial % spots.size()
					p2.respawn_at(spots[pick])
					if pick == spots.size() - 1:
						p2.go_down(&"voluntary")
						result["egg_trials"] = int(result["egg_trials"]) + 1
					else:
						result["idle_trials"] = int(result["idle_trials"]) + 1
				for flags: int in macro:
					_hold_up(squid, GAP_A)
					frame[0] = flags
					_lab.step(frame)
					if partner and p2.counts_for_coop():
						result["partner_counted"] = int(result["partner_counted"]) + 1
					if squid.hp < squid.max_hp or hero.dead:
						break
				if squid.hp < squid.max_hp:
					result["hits"] = int(result["hits"]) + 1
					if str(result["first"]) == "":
						result["first"] = "weapon %d from %s%s (%s)" % [weapon, start, " partner at %s" % p2.sim_pos \
								if partner else "", Lab.route_text(macro)]
	_fresh()
	return result


func _macros(dir: int) -> Array[PackedInt32Array]:
	var go: int = Defs.IN_RIGHT if dir > 0 else Defs.IN_LEFT
	var back: int = Defs.IN_LEFT if dir > 0 else Defs.IN_RIGHT
	var list: Array = [
		[[12, Defs.IN_FIRE]], [[12, Defs.IN_UP | Defs.IN_FIRE]], [[12, Defs.IN_DOWN | Defs.IN_FIRE]],
		[[9, Defs.IN_UP | Defs.IN_FIRE], [2, 0], [9, Defs.IN_UP | Defs.IN_FIRE]],
		[[6, Defs.IN_UP | go], [12, Defs.IN_UP | Defs.IN_FIRE], [8, go]],
		[[9, Defs.IN_UP | go], [6, go], [12, back | Defs.IN_FIRE]],
		[[9, Defs.IN_UP | go], [4, go], [12, Defs.IN_DOWN | Defs.IN_FIRE]],
		[[9, Defs.IN_UP], [12, Defs.IN_UP | Defs.IN_FIRE]],
	]
	var macros: Array[PackedInt32Array] = []
	for runs: Array in list:
		var flags: PackedInt32Array = PackedInt32Array()
		for run: Array in runs:
			for i: int in int(run[0]):
				flags.append(int(run[1]))
		for i: int in 12:
			flags.append(0)
		macros.append(flags)
	return macros


# =================================================================================================================
# The bot
# =================================================================================================================

## Plays the solo form with the club: waits on the island edge beside the gap the bubbles mark, 37 px from the
## squid; when the tentacle marks his spot it steps out from under it on foot (outward, never towards the squid, never
## over water), comes back, and high-strikes the head once the slam is over (the squid stays up long enough); near the
## squid the ink blob arcs over him. It never crosses the gap the squid is in (or bubbling up in), and once the middle
## island is bound to sink (phase 3) it keeps to the side islands (it fights the whirlpool from the pool's edge). With
## `attack` off it moves the same way and never strikes: the escape test.
class SquidBot:
	extends RefCounted

	const SIDE_DX: int = 37
	const SURFACE_Y: int = 144
	## Clear of the slam box (12 px either side of its mark) with the hero's half width (16), and a px.
	const SLAM_CLEAR: int = 29
	## Never this close to the squid's spot while it occupies it (a dodge slides a few px on).
	const SQUID_CLEAR: int = 34
	## Where it waits: at least this far from the edges of the islands (a run takes a few px to stop).
	const SLIDE_MARGIN: int = 12
	## A dodge starts from a stand: less slide.
	const DODGE_MARGIN: int = 6
	## Up held this long for a jump over a gap: a short hop (a full jump overshoots a 64 px island).
	const GAP_JUMP_HOLD: int = 5
	var attack: bool = true
	var _jump: int = 0
	var _jump_flags: int = 0
	var _jump_hold: int = 9
	## Where the running jump should land (it steers there in the air, pressing back once past it).
	var _jump_goal: int = 0

	func flags(hero: PlayerBase, squid: Squid, level: LevelBase) -> int:
		if hero == null or hero.dead or squid == null or squid.dead:
			return 0
		var x: int = hero.sim_pos.x
		var grounded: bool = hero.is_grounded()
		if _jump > 0:
			if grounded and _jump > 2:
				_jump = 0
			else:
				_jump += 1
				var up: int = Defs.IN_UP if _jump <= _jump_hold else 0
				if absi(_jump_goal - x) <= 4:
					return up
				return up | (Defs.IN_RIGHT if _jump_goal > x else Defs.IN_LEFT)
		var spot: int = squid.get_spot()
		var state: int = squid.get_state()
		var occupied: bool = state == Squid.State.BUBBLES or state == Squid.State.RISE or state == Squid.State.UP \
				or state == Squid.State.SINK
		# Phase 3 will sink the middle island (after the next dive and a 22-tick rumble): off it, to the nearer side
		# island, and never back.
		var sinking: bool = squid.get_phase() == 3 and not squid.is_whirlpool()
		if sinking and _on_middle(squid, x) and grounded:
			return _go(level, squid, hero, _side_island_x(level, squid, x), spot, occupied)
		# Out from under the tentacle: on foot, on the same ground, not towards the squid.
		var mark: int = squid.get_slam_mark()
		var slam: Rect2i = squid.get_slam_rect()
		var danger: int = mark if mark >= 0 else (slam.get_center().x if slam.size.x > 0 else -1)
		if squid.is_whirlpool():
			danger = -1  # the whirlpool's slam strikes the raft and hurts nobody
		if danger >= 0 and absi(danger - x) < SLAM_CLEAR and grounded:
			# Outward (away from the squid) first.
			var out: int = -1 if danger < spot else 1
			var best: int = -1
			for c: int in [danger + out * SLAM_CLEAR, danger - out * SLAM_CLEAR]:
				if not _same_ground(level, squid, x, c) or not _roomy(level, squid, c, DODGE_MARGIN):
					continue
				if occupied and absi(c - spot) < SQUID_CLEAR:
					continue
				best = c
				break
			if best >= 0:
				return _step(x, best)
			return 0
		var target: int = _target_x(hero, squid, level, spot, sinking)
		if absi(x - target) > 3 or not grounded:
			return _go(level, squid, hero, target, spot, occupied)
		var face: int = 1 if spot >= x else -1
		if hero.facing != face and not hero.is_striking():
			return Defs.IN_RIGHT if face > 0 else Defs.IN_LEFT
		# Strike once this surfacing's slam is over (a strike locks him 9 ticks: started before the tentacle marks his
		# spot, it would keep him under it); the squid stays up long enough for one hit after it.
		var slam_over: bool = squid.get_state_ticks() > Squid.SQUID_TENTACLE_AT and squid.get_slam_mark() < 0 \
				and squid.get_slam_rect().size.x == 0
		if attack and state == Squid.State.UP and slam_over:
			if squid.hit_cooldown <= 6 or hero.is_striking():
				return Defs.IN_UP | Defs.IN_FIRE
		return 0

	## The strike spot beside the squid's spot on the side the hero is on (the other side when that one is water).
	func _target_x(hero: PlayerBase, squid: Squid, level: LevelBase, spot_x: int, no_middle: bool) -> int:
		var side: int = -1 if hero.sim_pos.x < spot_x else 1
		var near: int = spot_x + side * SIDE_DX
		if _roomy(level, squid, near) and not (no_middle and _on_middle(squid, near)):
			return near
		var far: int = spot_x - side * SIDE_DX
		if _roomy(level, squid, far) and not (no_middle and _on_middle(squid, far)):
			return far
		return hero.sim_pos.x

	## True when x lies over the middle island (the one the whirlpool sinks).
	static func _on_middle(squid: Squid, x: int) -> bool:
		var col: int = Tuning.to_cell(x)
		return squid._island.x >= 0 and col >= squid._island.x and col <= squid._island.y

	## The nearest roomy spot of a side island (not the middle one), searched outwards from x.
	func _side_island_x(level: LevelBase, squid: Squid, x: int) -> int:
		for k: int in range(16, 200, 4):
			for candidate: int in [x - k, x + k]:
				if not _on_middle(squid, candidate) and _roomy(level, squid, candidate):
					return candidate
		return x

	## True when going from `a` to `b` passes within SQUID_CLEAR of `spot_x`.
	static func _passes(a: int, b: int, spot_x: int) -> bool:
		return mini(a, b) - SQUID_CLEAR < spot_x and spot_x < maxi(a, b) + SQUID_CLEAR

	## Walk (jumping water on the way) towards `goal`; while the squid occupies its spot it never goes past it.
	func _go(level: LevelBase, squid: Squid, hero: PlayerBase, goal: int, spot_x: int, occupied: bool) -> int:
		var x: int = hero.sim_pos.x
		if occupied and _passes(x, goal, spot_x) and not _same_ground(level, squid, x, goal):
			return 0
		return _walk(level, squid, hero, goal)

	static func _step(x: int, goal: int) -> int:
		if absi(goal - x) <= 2:
			return 0
		return Defs.IN_RIGHT if goal > x else Defs.IN_LEFT

	## True when every x from `a` to `b` is island ground: no water between.
	func _same_ground(level: LevelBase, squid: Squid, a: int, b: int) -> bool:
		var step: int = 4 if b >= a else -4
		var x: int = a
		while (step > 0 and x <= b) or (step < 0 and x >= b):
			if not _standable(level, squid, x):
				return false
			x += step
		return _standable(level, squid, b)

	## Ground under x and `margin` px either side of it: a spot he can stop on from a run.
	func _roomy(level: LevelBase, squid: Squid, x: int, margin: int = SLIDE_MARGIN) -> bool:
		return _standable(level, squid, x - margin) and _standable(level, squid, x) and _standable(level, squid, x + margin)

	## Island ground under the feet at x.
	static func _island(level: LevelBase, x: int) -> bool:
		var grid: TileGrid = level.grid
		return TileGrid.is_ground(grid.floor_at(Tuning.to_cell(x), Tuning.to_cell(SURFACE_Y))) \
				and grid.get_char(Tuning.to_cell(x), Tuning.to_cell(SURFACE_Y)) != TileGrid.CH_LIQUID

	## Ground under the feet at x: island ground only. He never boards a raft - walking onto one from an island drowns
	## him (his feet leave the island before the raft's ride test can carry him: it carries a hero only while
	## raft x - 24 < his x < raft x + 16, PHYSICS.md 11.4), and a jump onto one may miss it as it drifts; the squid
	## surfaces beside the islands as well.
	func _standable(level: LevelBase, _squid: Squid, x: int) -> bool:
		return _island(level, x)

	## Walk towards `goal`; at the edge of the ground jump the water ahead when there is ground beyond it (and the goal
	## lies beyond), else stop at the edge.
	func _walk(level: LevelBase, squid: Squid, hero: PlayerBase, goal: int) -> int:
		var x: int = hero.sim_pos.x
		if absi(goal - x) <= 3:
			return 0
		var dir: int = 1 if goal > x else -1
		var dir_flag: int = Defs.IN_RIGHT if dir > 0 else Defs.IN_LEFT
		if not hero.is_grounded() or _standable(level, squid, x + dir * 14):
			return dir_flag
		if absi(goal - x) > 20 and _standable(level, squid, x + dir * 46):
			_jump = 1
			_jump_flags = dir_flag
			_jump_hold = GAP_JUMP_HOLD
			# Land on the far island's first roomy spot (on the way to the goal), not beyond it.
			_jump_goal = goal
			for k: int in range(30, 200, 4):
				var land: int = x + dir * k
				if (dir > 0 and land > goal) or (dir < 0 and land < goal):
					break
				if _roomy(level, squid, land):
					_jump_goal = land
					break
			return dir_flag | Defs.IN_UP
		return 0


## Recorded by test_the_club_bot_still_wins with SQUID_ROUTE=1 (Beginner, Expert).
const ROUTE_BEGINNER: String = (
	"7:R,2:,6:L,1:R,28:,6:R,5:RU,6:R,3:,3:L,4:,2:R,1:,5:R,4:,4:L,1:R,2:,9:UF,15:,2:UF,102:,8:L,14:R,1:UF,13:L," +
	"1:R,1:,6:R,2:,4:L,1:R,93:,8:L,14:R,1:UF,13:L,1:R,1:,6:R,2:,4:L,1:R,93:,8:L,14:R,1:UF,13:L,1:R,1:,6:R,2:,4:L," +
	"1:R,93:,8:L,14:R,1:UF,4:L,21:,5:RU,8:R,2:,4:L,2:,6:R,1:L,1:,6:L,53:,3:R,1:L,1:,6:L,35:,8:UF,44:"
)
const ROUTE_EXPERT: String = (
	"7:R,2:,6:L,1:R,28:,6:R,5:RU,6:R,3:,3:L,4:,2:R,1:,5:R,4:,4:L,1:R,2:,9:UF,15:,2:UF,102:,8:L,14:R,1:UF,13:L," +
	"1:R,1:,6:R,2:,4:L,1:R,93:,8:L,14:R,1:UF,13:L,1:R,1:,6:R,2:,4:L,1:R,93:,8:L,14:R,1:UF,13:L,1:R,1:,6:R,2:,4:L," +
	"1:R,93:,8:L,14:R,1:UF,13:L,1:R,1:,6:R,2:,4:L,1:R,63:,6:L,2:,8:R,1:L,2:,4:L,7:,8:R,14:L,1:UF,14:R,1:L,1:,6:L," +
	"99:,8:R,14:L,1:UF,4:R,21:,5:LU,8:L,1:,6:R,2:,7:L,1:R,1:,6:R,51:,3:L,1:R,1:,8:R,2:,6:L,1:R,24:,9:UF,15:,2:UF," +
	"118:,8:UF,44:"
)
