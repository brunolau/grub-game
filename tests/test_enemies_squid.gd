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


func before_each() -> void:
	_was_manual = Sim.manual
	_lab = Lab.new()


func after_each() -> void:
	GameInput.clear_scripted()
	Sim.stop()
	Sim.manual = _was_manual
	Game.new_game(Defs.Difficulty.BEGINNER)
	Game.begin_level(&"")
	Audio.stop_music(0.0)
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
	_lab.step(PackedInt32Array([0, 0]))
	assert_eq(squid.flinch_window(), mini(Squid.SQUID_FLINCH_BEGINNER,
			Squid.SQUID_SOLO_MIN_TICKS - PartyTuning.WINDOW_SOLO_MARGIN_TICKS))
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
	assert_eq(squid.get_open_ticks(), Squid.SQUID_OPEN_TICKS - 1)
	_shot_at(squid.get_head_rect(), 0)
	_step2()
	assert_eq(squid.hp, squid.max_hp - 20, "and takes a hit")
	# One hero's two flinches never open it.
	_wait2(Squid.SQUID_OPEN_TICKS)
	p1.respawn_at(Vector2i(GAP_A - 37, SURFACE))
	_shot_at(squid.get_tentacle_rect(-1), 0)
	_step2()
	p1.respawn_at(Vector2i(GAP_A + 37, SURFACE))
	_shot_at(squid.get_tentacle_rect(1), 0)
	_step2()
	assert_true(squid.get_flinch(-1) > 0 and squid.get_flinch(1) > 0, "both flinch ...")
	assert_eq(squid.get_open_ticks(), 0, "... for the same hero: shut")


## The flinch window is shorter than the measured solo minimum: one hero who flinches the left tentacle from the left
## island and then crosses over the squid (bouncing off its head) to flinch the right one needs at least the measured
## ticks; SQUID_SOLO_MIN_TICKS is no more than that, so the flinch (min(24 / 16, solo minimum - 4)) stays 4+ below it.
func test_coop_flinch_window_is_shorter_than_the_measured_solo_minimum() -> void:
	var squid: Squid = _open(Defs.Difficulty.BEGINNER, 1, true)
	var hero: PlayerBase = _lab.hero()
	_lab.step(PackedInt32Array([0]))
	var best: int = 100000
	var how: String = ""
	var trials: int = 0
	for weapon: int in [Defs.Weapon.CLUB, Defs.Weapon.SPEAR]:
		hero.run.set_weapon(weapon)
		for jump_at: int in range(8, 13):
			for hold: int in [5, 9]:
				for strike_at: int in range(10, 26, 2):
					trials += 1
					for entity: SimEntity in _lab.level.get_kind(Defs.Kind.HERO_PROJECTILE):
						(entity as ProjectileBase).consume()
					squid.flinch_log.clear()
					squid._part_tick = [-1000, -1000]
					hero.respawn_at(Vector2i(GAP_A - 37, SURFACE))
					hero.facing = 1
					Lab.top_up(hero)
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
						_lab.step(PackedInt32Array([flags]))
					var left_at: int = -1
					var right_at: int = -1
					for entry: Vector3i in squid.flinch_log:
						if entry.y < 0 and left_at < 0:
							left_at = entry.x
						elif entry.y > 0 and right_at < 0:
							right_at = entry.x
					if left_at >= 0 and right_at >= 0 and right_at - left_at < best:
						best = right_at - left_at
						how = "weapon %d, jump at %d held %d, strike %d later" % [weapon, jump_at, hold, strike_at]
	print("    one hero from the left tentacle to the right one: %d ticks at best (%s), %d trials" % [best, how, trials])
	assert_true(best < 100000, "the search flinched both tentacles (it is not blind)")
	assert_true(best >= Squid.SQUID_SOLO_MIN_TICKS, "SQUID_SOLO_MIN_TICKS (%d) is a lower bound of the measured %d" % [
		Squid.SQUID_SOLO_MIN_TICKS, best])
	for difficulty: int in [Defs.Difficulty.BEGINNER, Defs.Difficulty.EXPERT]:
		Game.difficulty = difficulty
		assert_true(squid.flinch_window() <= best - PartyTuning.WINDOW_SOLO_MARGIN_TICKS)
	assert_eq(squid.hp, squid.max_hp, "and the head never opened for him")


## The single-hero search cannot hurt the co-op form: one hero with every weapon, from both islands and the ledge over
## the gap, striking forward / high / low standing and out of jumps (over the squid too), never lands a hit on the
## locked squid - while the same search hurts the solo form; the solo club route never hurts the co-op form.
func test_the_single_hero_search_cannot_hurt_the_coop_form() -> void:
	var coop: Dictionary = _search(true)
	var solo: Dictionary = _search(false)
	print("    single-hero search: %d trials, co-op form hit %d times; solo form hit %d times" % [coop["trials"],
		coop["hits"], solo["hits"]])
	assert_true(int(coop["trials"]) >= 200)
	assert_eq(int(coop["hits"]), 0, "one hero never hurts the locked squid: %s" % coop["first"])
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


## The single-hero search against the up squid in a gap (co-op or solo form).
func _search(coop_form: bool) -> Dictionary:
	var squid: Squid = _open(Defs.Difficulty.BEGINNER, 1, coop_form)
	var hero: PlayerBase = _lab.hero()
	_lab.step(PackedInt32Array([0]))
	var result: Dictionary = {"trials": 0, "hits": 0, "first": ""}
	var starts: Array[Vector2i] = [Vector2i(GAP_A - 37, SURFACE), Vector2i(GAP_A - 52, SURFACE),
		Vector2i(GAP_A + 37, SURFACE), Vector2i(GAP_A + 52, SURFACE), Vector2i(GAP_A - 8, 96), Vector2i(GAP_A + 8, 96)]
	for weapon: int in [Defs.Weapon.CLUB, Defs.Weapon.HAMMER, Defs.Weapon.AXE, Defs.Weapon.BOOMERANG, Defs.Weapon.SPEAR]:
		hero.run.set_weapon(weapon)
		for start: Vector2i in starts:
			var toward: int = 1 if start.x < GAP_A else -1
			for macro: PackedInt32Array in _macros(toward):
				result["trials"] = int(result["trials"]) + 1
				for entity: SimEntity in _lab.level.get_kind(Defs.Kind.HERO_PROJECTILE):
					(entity as ProjectileBase).consume()
				squid.hp = squid.max_hp
				squid.hit_cooldown = 0
				squid._flinch = [0, 0]
				squid._open = 0
				squid._part_tick = [-1000, -1000]
				hero.respawn_at(start)
				hero.facing = toward
				Lab.top_up(hero)
				var frame: PackedInt32Array = PackedInt32Array([0])
				for flags: int in macro:
					_hold_up(squid, GAP_A)
					frame[0] = flags
					_lab.step(frame)
					if squid.hp < squid.max_hp or hero.dead:
						break
				if squid.hp < squid.max_hp:
					result["hits"] = int(result["hits"]) + 1
					if str(result["first"]) == "":
						result["first"] = "weapon %d from %s (%s)" % [weapon, start, Lab.route_text(macro)]
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

## Plays the solo form with the club: goes to the island edge (or raft) beside the gap the bubbles mark, high-strikes
## the head as soon as it is up, steps away from the tentacle's shadow and comes back for a second strike; stays by the
## squid while the jaws are open (the blob arcs over him). With `attack` off it only dodges: it keeps away from the
## surfacing spot.
class SquidBot:
	extends RefCounted

	const SIDE_DX: int = 37
	const SURFACE_Y: int = 144
	var attack: bool = true
	var _jump: int = 0
	var _jump_flags: int = 0
	var _side: int = -1

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
				return _jump_flags | (Defs.IN_UP if _jump <= 9 else 0)
		var spot_x: int = squid.get_spot()
		var state: int = squid.get_state()
		var target: int = _target_x(hero, squid, level, spot_x)
		# Out from under the tentacle.
		var mark: int = squid.get_slam_mark()
		var slam: Rect2i = squid.get_slam_rect()
		var danger: int = mark if mark >= 0 else (slam.get_center().x if slam.size.x > 0 else -1)
		if danger >= 0 and absi(danger - x) < 34:
			var away: int = 1 if x >= danger else -1
			if not _standable(level, squid, x + away * 20):
				away = -away
			return _walk(level, squid, hero, x + away * 40)
		if not attack:
			# Keep away: the far edge of the current island, never by the spot.
			var keep: int = _keep_away_x(level, squid, x, spot_x)
			return _walk(level, squid, hero, keep)
		if absi(x - target) > 3 or not grounded:
			return _walk(level, squid, hero, target)
		var face: int = 1 if spot_x >= x else -1
		if hero.facing != face and not hero.is_striking():
			return Defs.IN_RIGHT if face > 0 else Defs.IN_LEFT
		if state == Squid.State.UP or (state == Squid.State.RISE and squid.get_state_ticks() >= 0):
			if squid.hit_cooldown <= 6 or hero.is_striking():
				return Defs.IN_UP | Defs.IN_FIRE
		return 0

	## The strike spot beside the squid's spot on the side the hero is on (the other side when that one is water).
	func _target_x(hero: PlayerBase, squid: Squid, level: LevelBase, spot_x: int) -> int:
		var side: int = -1 if hero.sim_pos.x < spot_x else 1
		var near: int = spot_x + side * SIDE_DX
		if _standable(level, squid, near):
			return near
		var far: int = spot_x - side * SIDE_DX
		if _standable(level, squid, far):
			return far
		return near

	func _keep_away_x(level: LevelBase, squid: Squid, x: int, spot_x: int) -> int:
		var best: int = x
		var best_score: int = -1
		for candidate: int in [40, 56, 72, 152, 168, 248, 264, 280]:
			if not _standable(level, squid, candidate):
				continue
			var score: int = absi(candidate - spot_x) * 2 - absi(candidate - x)
			if score > best_score:
				best_score = score
				best = candidate
		return best

	## Ground (an island) or a raft under the feet at x.
	func _standable(level: LevelBase, squid: Squid, x: int) -> bool:
		var grid: TileGrid = level.grid
		if TileGrid.is_ground(grid.floor_at(Tuning.to_cell(x), Tuning.to_cell(SURFACE_Y))) \
				and grid.get_char(Tuning.to_cell(x), Tuning.to_cell(SURFACE_Y)) != TileGrid.CH_LIQUID:
			return true
		for raft: SimEntity in squid.get_rafts():
			if is_instance_valid(raft) and absi(raft.sim_pos.x - x) <= raft.box_xo - 10:
				return true
		return false

	## Walk towards `goal`, jumping when the next step is over water.
	func _walk(level: LevelBase, squid: Squid, hero: PlayerBase, goal: int) -> int:
		var x: int = hero.sim_pos.x
		if absi(goal - x) <= 3:
			return 0
		var dir: int = 1 if goal > x else -1
		var dir_flag: int = Defs.IN_RIGHT if dir > 0 else Defs.IN_LEFT
		if hero.is_grounded() and not _standable(level, squid, x + dir * 14):
			_jump = 1
			_jump_flags = dir_flag
			return dir_flag | Defs.IN_UP
		return dir_flag


## Recorded by test_the_club_bot_still_wins with SQUID_ROUTE=1 (Beginner, Expert).
const ROUTE_BEGINNER: String = ""
const ROUTE_EXPERT: String = ""
