extends TestCase
## Old Mangrove, the Rooted Guardian (scripts/bosses/mangrove.gd; DESIGN.md B.2, GAMEPLAY.md 13.6; PLAN.md P2.2, owner
## enemies-B) on its test level levels/test_enemies_mangrove.lvl, in the real level scene with the real hero(es)
## (the Lab of tests/test_enemies_tusker.gd).
##
## Pinned here (DESIGN.md B.0): every punch and sweep shows itself 10+ ticks ahead; every attack can be escaped; hits
## never stop or lengthen its clocks (no stun-lock) and count at most once per BOSS_HIT_COOLDOWN; the resting fist is a
## springboard to the face (and the face is out of reach of any jump from the floor); the club beats the solo form on a
## scripted route (Beginner and Expert); the co-op twin window is shorter than the measured solo minimum; the
## single-hero search cannot hurt the co-op form.

const Lab = preload("res://tests/test_enemies_tusker.gd").Lab
const LEVEL_PATH: String = "res://levels/test_enemies_mangrove.lvl"
const BOSS_ID: String = "bosses/mangrove"

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
		weapon: int = Defs.Weapon.CLUB) -> Mangrove:
	assert_true(_lab.open(self, LEVEL_PATH, BOSS_ID, difficulty, party, coop_form, weapon), "the test level came up")
	return _lab.boss as Mangrove


func _fresh() -> void:
	if _lab != null and _lab.level != null and is_instance_valid(_lab.level):
		_lab.level.free()
	_lab = Lab.new()


# =================================================================================================================
# Basics: hit points, geometry, the springboard
# =================================================================================================================

func test_mangrove_reads_its_chamber_and_counts_hits_by_stage() -> void:
	var tree: Mangrove = _open()
	assert_false(tree.coop_form)
	assert_eq(tree.max_hp, 10, "Beginner 4 + 3 + 3 hits (any weapon counts 1)")
	assert_eq(tree.wall_x, 240, "the wall face right of its cell")
	assert_eq(tree.floor_y, 160)
	assert_eq(tree.sim_pos, Vector2i(240, 160), "the record moved to the wall's foot")
	assert_eq(tree.fist_rest_x, 200)
	assert_eq(tree.hand_rest, Vector2i(76, 80 + Mangrove.MANGROVE_HAND_SINK), "the upper ledge (row 5) ends at x 96")
	assert_eq(tree.hand_home, Vector2i(240, 80), "it comes out of the wall at the ledge top")
	assert_eq(tree.get_face_rect(), Rect2i(230, 55, 20, 29), "76-105 px over the floor (G35)")
	_lab.step(PackedInt32Array([0]))
	assert_true(tree.fighting)
	assert_eq(tree.get_stage(), 1)
	tree.hp = 6
	assert_eq(tree.get_stage(), 2)
	tree.hp = 3
	assert_eq(tree.get_stage(), 3)
	_fresh()
	var expert: Mangrove = _open(Defs.Difficulty.EXPERT)
	assert_eq(expert.max_hp, 16, "Expert 6 + 5 + 5")
	_fresh()
	var coop: Mangrove = _open(Defs.Difficulty.BEGINNER, 2, true)
	assert_eq(coop.max_hp, 8, "co-op Beginner: 5 twin hits + 3")
	_fresh()
	var coop_expert: Mangrove = _open(Defs.Difficulty.EXPERT, 2, true)
	assert_eq(coop_expert.max_hp, 13, "co-op Expert: 7 twin hits + 6")
	assert_true(coop_expert.max_hp * PartyTuning.BOSS_HP_MAX_DEN <= 16 * PartyTuning.BOSS_HP_MAX_NUM)


## The drops come out on the floor in front of the trunk strip (BossBase._drop_origin, the G2 integration;
## wf8_D6_to_enemies_b.txt): from the face, inside the bark wall, a first drop without sideways speed stayed in the
## wall and a level's locked exit could never open. The defeat effect and the bonus burst stay at the face.
func test_the_drops_land_on_the_floor_in_front_of_the_trunk() -> void:
	var tree: Mangrove = _open()
	_lab.step(PackedInt32Array([0]))
	var drops: Array[StringName] = [&"fire_starter"]
	tree.defeat(drops)
	for i: int in 90:
		_lab.step(PackedInt32Array([0]))
	var starters: Array[FireStarter] = []
	for entity: SimEntity in _lab.level.get_kind(Defs.Kind.COLLECTIBLE):
		if entity is FireStarter:
			starters.append(entity as FireStarter)
	assert_eq(starters.size(), 1, "the fire-starter was dropped")
	if starters.is_empty():
		return
	var starter: FireStarter = starters[0]
	assert_true(starter.sim_pos.x < tree.wall_x - Mangrove.MANGROVE_TRUNK_PX,
			"in front of the trunk strip, out of the wall (x %d, wall %d)" % [starter.sim_pos.x, tree.wall_x])
	assert_true(starter.sim_pos.y <= tree.floor_y, "not under the floor")
	var grid: TileGrid = _lab.level.grid
	assert_ne(grid.floor_at(starter.sim_pos.x >> 4, starter.sim_pos.y >> 4), TileGrid.FLOOR_EMPTY,
			"at rest on ground a hero reaches (the floor or the root ledge in front of the wall) at %s" % starter.sim_pos)


## The resting fist launches a hero who lands on it (-160; -224 with Up held) and the launch carries him past the face
## (since G35 76-105 px over the floor, the launch rises through it): a strike timed around the launch - forward or
## high, started a few ticks before he lands on the fist or after - reaches the face. A jump from the floor beside the
## trunk is counted too (printed: with the face this low some floor jumps reach it - the springboard is no longer the
## only way up, DESIGN.md G35 accepted that height).
func test_the_resting_fist_is_the_springboard_to_the_face() -> void:
	var tree: Mangrove = _open()
	var hero: PlayerBase = _lab.hero()
	_lab.step(PackedInt32Array([0]))
	tree._fist_len = 100000
	var reached: Array[String] = []
	var launches: int = tree.launches
	var land: int = -1
	for trial: int in 23:
		var strike: int = Defs.IN_FIRE if trial % 2 == 1 else (Defs.IN_UP | Defs.IN_FIRE)
		var start: int = trial / 2 - 4
		tree.hp = tree.max_hp
		tree.hit_cooldown = 0
		tree._part_tick.clear()
		# A face hit cuts the fist's rest short: every trial starts with the fist at a long rest.
		tree._set_fist(Mangrove.Fist.REST)
		tree._fist_x = tree.fist_rest_x
		tree._fist_len = 100000
		hero.respawn_at(Vector2i(206, 160))
		hero.facing = 1
		var launched: int = -1
		var t: int = 0
		while t < 60 and tree.hp == tree.max_hp:
			# Trial 0 finds the tick he lands on the fist (a plain jump, no strike); the others strike around it.
			var flags: int = Defs.IN_UP if t < 9 else 0
			if trial > 0 and t >= land + start and t < land + start + 9:
				flags = strike
			if launched >= 0 and t - launched <= 1:
				flags |= Defs.IN_RIGHT
			_lab.step(PackedInt32Array([flags]))
			if launched < 0 and hero.yvel <= -120:
				launched = t
				if trial == 0:
					land = t
			t += 1
		if trial > 0 and tree.hp < tree.max_hp:
			reached.append("%s %+d" % ["forward" if strike == Defs.IN_FIRE else "high", start])
	print("    springboard (lands on the fist on tick %d): strikes that hit the face - %s" % [land, reached])
	assert_true(land > 0, "a jump from beside the fist lands on it and is launched")
	assert_true(tree.launches - launches >= 20, "every landing on the resting fist launched the hero")
	assert_true(reached.size() >= 2, "the face is reachable from the springboard")
	# From the floor beside the trunk: counted, not forbidden any more.
	var hits: int = 0
	for x: int in [196, 206, 214, 220]:
		for hold: int in [5, 9]:
			for strike: int in [Defs.IN_FIRE, Defs.IN_UP | Defs.IN_FIRE]:
				for delay: int in range(0, 12, 2):
					tree.hp = tree.max_hp
					tree.hit_cooldown = 0
					tree._part_tick.clear()
					tree._fist = Mangrove.Fist.BACK
					tree._fist_x = tree.fist_out_x
					tree._burst_left = 1000
					hero.respawn_at(Vector2i(x, 160))
					hero.facing = 1
					for t: int in 40:
						var flags: int = Defs.IN_UP if t < hold else 0
						if t >= delay and t < delay + 9:
							flags |= strike
						tree._fist = Mangrove.Fist.BACK
						tree._fist_timer = 0
						_lab.step(PackedInt32Array([flags]))
					hits += 1 if tree.hp < tree.max_hp else 0
	print("    from the floor beside the trunk: %d of 96 jump-strikes reach the face" % hits)


## G35 (as corrected): every weak point the club can strike - the face (Hud.weak_point_rects), the resting upper hand
## and the stuck fist of stage 3, wherever the club routes see them - lies wholly inside every view the chamber's camera
## lock allows and 24 px clear of the fight HUD's band (Hud.weak_point_problem).
func test_every_weak_point_is_clear_of_the_hud() -> void:
	var worst: Array[int] = [1 << 20]
	var checked: Array[int] = [0]
	var kinds: Dictionary = {}
	for case: Array in [[Defs.Difficulty.BEGINNER, ROUTE_BEGINNER], [Defs.Difficulty.EXPERT, ROUTE_EXPERT]]:
		var tree: Mangrove = _open(int(case[0]))
		var route: PackedInt32Array = Lab.parse_route(str(case[1]))
		var problems: Array[String] = []
		_lab.play([route] as Array[PackedInt32Array], func() -> bool:
			if tree.fighting and not tree.dead and tree._dying < 0:
				var rects: Dictionary = {}
				if tree.get_stage() == 1:
					rects["face"] = tree.get_face_rect()
				if tree.get_hand_state() == Mangrove.Hand.REST:
					rects["hand"] = tree.get_hand_rect()
				if tree.get_fist_state() == Mangrove.Fist.STUCK:
					rects["fist"] = tree.get_fist_rect()
				for rect: Rect2i in Hud.weak_point_rects(tree):
					rects["hud %s" % rect] = rect
				for key: String in rects:
					var rect: Rect2i = rects[key]
					var why: String = _lab.hud_clear(rect)
					if why != "" and problems.size() < 3:
						problems.append("%s: %s" % [key, why])
					worst[0] = mini(worst[0], _lab.top_clearance(rect))
					checked[0] += 1
					kinds[key.get_slice(" ", 0)] = true
			return tree.dead)
		assert_true(problems.is_empty(), "difficulty %d: %s" % [case[0], problems])
		_fresh()
	print("    G35: %d weak rects checked (%s), the highest top %d px under the view's top" % [checked[0], kinds.keys(),
		worst[0]])
	for kind: String in ["face", "hand", "fist"]:
		assert_true(kinds.has(kind), "the routes saw the %s strikable" % kind)


## Each punch: a 10-tick draw-back with a creak, 3 ticks out (3 bones and the knock-back), shake 4, a leaf over the
## target; between bursts the fist rests; the trunk costs a bone.
func test_punches_and_the_trunk() -> void:
	var tree: Mangrove = _open()
	var hero: PlayerBase = _lab.hero()
	_lab.step(PackedInt32Array([0]))
	hero.respawn_at(Vector2i(150, 160))
	tree._fist_len = tree._fist_timer + 1
	var drew: int = 0
	var bones_before: int = hero.run.hearts * Tuning.BONES_PER_HEART + hero.run.bones
	var shook: bool = false
	var leaves: int = 0
	for t: int in 14:
		_lab.step(PackedInt32Array([0]))
		drew += 1 if tree.get_fist_state() == Mangrove.Fist.DRAW else 0
		# (the hero's own update counts the shake down by 1 on the tick of the punch, PHYSICS.md 13.3)
		shook = shook or _lab.level.shake >= Mangrove.MANGROVE_PUNCH_SHAKE - 1
		if tree.get_fist_state() == Mangrove.Fist.OUT:
			break
	for entity: SimEntity in _lab.level.get_kind(Defs.Kind.ENEMY_PROJECTILE):
		leaves += 1 if entity is EnemyEmber else 0
	assert_eq(drew, Mangrove.MANGROVE_DRAW_TICKS, "drawn back 10 ticks")
	for t: int in 3:
		_lab.step(PackedInt32Array([0]))
	var bones_after: int = hero.run.hearts * Tuning.BONES_PER_HEART + hero.run.bones
	assert_eq(bones_before - bones_after, Mangrove.MANGROVE_PUNCH_BONES, "the moving fist costs 3 bones")
	assert_true(shook, "the punch shakes the screen")
	assert_eq(leaves, 1, "and drops a leaf over its target")
	# The trunk.
	hero.respawn_at(Vector2i(222, 160))
	hero.hit_timer = 0
	_lab.step(PackedInt32Array([Defs.IN_RIGHT]))
	_lab.step(PackedInt32Array([Defs.IN_RIGHT]))
	assert_true(hero.hit_timer > 0, "walking into the trunk costs a bone and pushes him back")


# =================================================================================================================
# B.0 fairness
# =================================================================================================================

## The whole Expert fight played by the club bot, watched: every punch comes after its 10-tick draw-back, every sweep
## of the upper hand after its 14-tick ledge shake, every leaf falls from 150 px above (37+ ticks to reach the hero).
func test_every_attack_shows_itself_10_ticks_ahead() -> void:
	var tree: Mangrove = _open(Defs.Difficulty.EXPERT)
	var hero: PlayerBase = _lab.hero()
	var bot: MangroveBot = MangroveBot.new()
	var draws: Array[int] = []
	var shakes: Array[int] = []
	var fist_last: int = -1
	var hand_last: int = -1
	var since_fist: int = 0
	var since_hand: int = 0
	var t: int = 0
	while t < 9000 and not tree.dead:
		Lab.top_up(hero)
		_lab.step(PackedInt32Array([bot.flags(hero, tree, _lab.level)]))
		t += 1
		var fist: int = tree.get_fist_state()
		if fist != fist_last:
			if fist == Mangrove.Fist.OUT:
				draws.append(since_fist)
			fist_last = fist
			since_fist = 0
		since_fist += 1
		var hand: int = tree.get_hand_state()
		if hand != hand_last:
			if hand == Mangrove.Hand.SWEEP:
				shakes.append(since_hand)
			hand_last = hand
			since_hand = 0
		since_hand += 1
	print("    Mangrove telegraphs (Expert club fight, %d ticks): %d punches (draw-back %s..%s), %d sweeps (ledge shake %s)" % [
		t, draws.size(), draws.min() if not draws.is_empty() else -1, draws.max() if not draws.is_empty() else -1,
		shakes.size(), shakes])
	assert_true(tree.dead, "the fight was played to its end")
	assert_true(draws.size() >= 10 and shakes.size() >= 2)
	for draw: int in draws:
		assert_true(draw >= 10, "a punch after %d ticks of draw-back" % draw)
	for shake: int in shakes:
		assert_true(shake >= 10, "a sweep after %d ticks of ledge shake" % shake)


## Every attack can be escaped: a hero who only dodges (on the lower ledge in stages 1-2 - over the punches and under
## the sweeping hand -, on the floor beyond the punches' reach in stage 3, stepping away from falling leaves) is never
## hurt in 1200 ticks of each stage.
func test_every_attack_can_be_escaped() -> void:
	for stage_hp: int in [10, 6, 3]:
		var tree: Mangrove = _open()
		tree.hp = stage_hp
		var bot: MangroveBot = MangroveBot.new()
		bot.attack = false
		var hero: PlayerBase = _lab.hero()
		var hurts: int = 0
		for t: int in 1200:
			_lab.step(PackedInt32Array([bot.flags(hero, tree, _lab.level)]))
			if hero.hit_timer == Tuning.HIT_TIMER - 1:
				hurts += 1
		print("    dodging stage %d: %d punches, %d sweeps, %d hurts" % [tree.get_stage(), tree.punches, tree.sweeps,
			hurts])
		assert_true(tree.punches >= 8, "it kept punching")
		if tree.get_stage() == 2:
			assert_true(tree.sweeps >= 2, "and sweeping")
		assert_eq(hurts, 0, "stage %d: never hurt while dodging" % tree.get_stage())
		_fresh()


## Hits never stop its clocks: a perfect thrower (a weapon on the weak part of the stage on every tick it can count)
## sees the punches and sweeps go on; hits come at least BOSS_HIT_COOLDOWN apart; the fight ends.
func test_hits_never_stun_lock_it() -> void:
	var tree: Mangrove = _open(Defs.Difficulty.EXPERT)
	var hero: PlayerBase = _lab.hero()
	var hit_ticks: Array[int] = []
	var punches_per_stage: Dictionary = {}
	var t: int = 0
	while t < 6000 and not tree.dead:
		Lab.top_up(hero)
		var stage: int = tree.get_stage()
		var weak: Rect2i = tree.get_face_rect()
		if stage == 2:
			weak = tree.get_hand_rect() if tree.get_hand_state() == Mangrove.Hand.REST else Rect2i()
		elif stage == 3:
			weak = tree.get_fist_rect() if tree.get_fist_state() == Mangrove.Fist.STUCK else Rect2i()
		if weak.size.x > 0:
			_shot_at(weak)
		var hp: int = tree.hp
		var punches: int = tree.punches
		_lab.step(PackedInt32Array([0]))
		t += 1
		punches_per_stage[stage] = int(punches_per_stage.get(stage, 0)) + tree.punches - punches
		if tree.hp < hp:
			hit_ticks.append(t)
	print("    perfect thrower: beaten after %d ticks, %d hits, punches by stage %s" % [t, hit_ticks.size(),
		punches_per_stage])
	assert_true(tree.dead)
	for i: int in range(1, hit_ticks.size()):
		assert_true(hit_ticks[i] - hit_ticks[i - 1] >= Tuning.BOSS_HIT_COOLDOWN, "hits %d ticks apart" % [
			hit_ticks[i] - hit_ticks[i - 1]])
	assert_true(int(punches_per_stage.get(3, 0)) >= 8, "the stage-3 bursts kept coming")


# =================================================================================================================
# The club beats the solo form
# =================================================================================================================

func test_the_club_beats_the_solo_form_on_its_scripted_routes() -> void:
	for case: Array in [[Defs.Difficulty.BEGINNER, ROUTE_BEGINNER], [Defs.Difficulty.EXPERT, ROUTE_EXPERT]]:
		var tree: Mangrove = _open(int(case[0]))
		var hero: PlayerBase = _lab.hero()
		var route: PackedInt32Array = Lab.parse_route(str(case[1]))
		var played: int = _lab.play([route] as Array[PackedInt32Array], func() -> bool: return tree.dead)
		print("    route difficulty %d: beaten on tick %d of %d, hero %d hearts %d bones" % [case[0], played,
			route.size(), hero.run.hearts, hero.run.bones])
		assert_true(tree.dead, "difficulty %d: the club route beats Old Mangrove" % case[0])
		assert_false(hero.dead)
		assert_eq(hero.run.weapon, Defs.Weapon.CLUB)
		_fresh()


func test_the_club_bot_still_wins() -> void:
	for difficulty: int in [Defs.Difficulty.BEGINNER, Defs.Difficulty.EXPERT]:
		var tree: Mangrove = _open(difficulty)
		var hero: PlayerBase = _lab.hero()
		var bot: MangroveBot = MangroveBot.new()
		var hurts: int = 0
		var t: int = 0
		var trace: bool = OS.get_environment("MANGROVE_TRACE") != ""
		var last: Vector3i = Vector3i(-1, -1, -1)
		while t < 9000 and not tree.dead and not hero.dead:
			_lab.step(PackedInt32Array([bot.flags(hero, tree, _lab.level)]))
			t += 1
			if hero.hit_timer == Tuning.HIT_TIMER - 1:
				hurts += 1
				if trace:
					print("      t%d HURT hero %s fist %d@%d hand %d" % [t, hero.sim_pos, tree.get_fist_state(),
						tree._fist_x, tree.get_hand_state()])
			var now: Vector3i = Vector3i(tree.get_stage(), tree.hp, tree.get_fist_state())
			if trace and now != last:
				last = now
				print("      t%d stage %d hp %d fist %d hand %d hero %s" % [t, now.x, now.y, now.z,
					tree.get_hand_state(), hero.sim_pos])
		print("    club bot difficulty %d: won %s in %d ticks, %d hurts, %d hearts left" % [difficulty, tree.dead, t,
			hurts, hero.run.hearts])
		if OS.get_environment("MANGROVE_ROUTE") != "":
			print("ROUTE %d %s" % [difficulty, Lab.route_text(_lab.streams[0])])
		assert_true(tree.dead, "difficulty %d" % difficulty)
		assert_false(hero.dead)
		_fresh()


# =================================================================================================================
# The co-op form
# =================================================================================================================

## Stages 1 and 2 merge: the face and the resting hand struck by the two heroes within the twin window count one
## twin hit; one hero's two hits never twin; hits too far apart never twin.
func test_coop_twin_hits_need_both_heroes_within_the_window() -> void:
	var tree: Mangrove = _open(Defs.Difficulty.BEGINNER, 2, true)
	_wake_both()
	_lab.step(PackedInt32Array([0, 0]))
	assert_eq(tree.twin_window(), PartyTuning.WINDOW_TICKS_BEGINNER,
			"G34: a slot-bound twin is exempt from the solo_min cap - the difficulty's window, 24 on Beginner")
	Game.difficulty = Defs.Difficulty.EXPERT
	assert_eq(tree.twin_window(), PartyTuning.WINDOW_TICKS_EXPERT, "12 on Expert")
	Game.difficulty = Defs.Difficulty.BEGINNER
	_rest_hand(tree)
	# P1 the face, P2 the hand, on the same tick: a twin hit.
	_shot_at(tree.get_face_rect(), 0)
	_shot_at(tree.get_hand_rect(), 1)
	_lab.step(PackedInt32Array([0, 0]))
	assert_eq(tree.hp, tree.max_hp - 1, "a twin hit counts one")
	assert_eq(tree.twins, 1)
	# One hero's face and hand hits: no twin.
	_wait(Tuning.BOSS_HIT_COOLDOWN + 2)
	_rest_hand(tree)
	_shot_at(tree.get_face_rect(), 0)
	_lab.step(PackedInt32Array([0, 0]))
	_shot_at(tree.get_hand_rect(), 0)
	_lab.step(PackedInt32Array([0, 0]))
	assert_eq(tree.hp, tree.max_hp - 1, "one hero's two hits never twin")
	# Both heroes, but further apart than the window: no twin.
	_wait(Tuning.BOSS_HIT_COOLDOWN + 2)
	_rest_hand(tree)
	_shot_at(tree.get_face_rect(), 0)
	_wait(tree.twin_window())
	_rest_hand(tree)
	_shot_at(tree.get_hand_rect(), 1)
	_lab.step(PackedInt32Array([0, 0]))
	assert_eq(tree.hp, tree.max_hp - 1, "too late: no twin")
	# Within the window's last tick: a twin.
	_wait(Tuning.BOSS_HIT_COOLDOWN + 2)
	_rest_hand(tree)
	_shot_at(tree.get_hand_rect(), 1)
	_wait(tree.twin_window() - 1)
	_rest_hand(tree)
	_shot_at(tree.get_face_rect(), 0)
	_lab.step(PackedInt32Array([0, 0]))
	assert_eq(tree.hp, tree.max_hp - 2, "hand first, face within the window: a twin")


## A hero standing on the resting fist (no Up) pins it - no punch - until it flings him off after 66 ticks; with Up
## held he is launched at once; the count-in plays while the hand rests and a hero stands on the fist.
func test_coop_pin_and_fling() -> void:
	var tree: Mangrove = _open(Defs.Difficulty.BEGINNER, 2, true)
	var p1: PlayerBase = _lab.hero(0)
	_wake_both()
	_lab.step(PackedInt32Array([0, 0]))
	tree._fist_len = tree._fist_timer + 30
	p1.respawn_at(Vector2i(204, 120))
	var stood: int = 0
	var flung: int = -1
	var punched: bool = false
	var counted: bool = false
	for t: int in 120:
		_lab.step(PackedInt32Array([0, 0]))
		# Standing on it: carried by its top, or lifted just over it by the hand's ledge-shake nudge.
		if flung < 0 and (tree._standing_mask() & 1) != 0:
			stood += 1
		if flung < 0 and p1.yvel <= -120:
			flung = t
		punched = punched or tree.get_fist_state() == Mangrove.Fist.OUT and flung < 0
		counted = counted or tree._count_in >= 0
	assert_false(punched, "no punch while he pins it, though its rest was over")
	assert_true(stood >= Mangrove.MANGROVE_PIN_TICKS - 2, "he stood on it (%d ticks)" % stood)
	assert_true(flung >= Mangrove.MANGROVE_PIN_TICKS - 1 and flung <= Mangrove.MANGROVE_PIN_TICKS + 8,
			"flung off after 66 ticks (%d)" % flung)
	assert_true(counted, "the count-in ran while the hand rested and he stood on the fist")
	# With Up held a landing launches him at once (-224).
	tree._set_fist(Mangrove.Fist.REST)
	tree._fist_x = tree.fist_rest_x
	tree._fist_len = 100000
	p1.respawn_at(Vector2i(206, 160))
	var launched: bool = false
	for t: int in 40:
		# A jump from the floor beside it, Up held through the landing on its top.
		_lab.step(PackedInt32Array([Defs.IN_UP, 0]))
		launched = launched or p1.yvel <= Tuning.BOUNCE_YVEL_UP + 16
	assert_true(launched, "Up held: launched at once")


## Stage 3: the knuckle armour of the stuck fist turns to the nearer hero every tick; only the far hero's strike on the
## wrist counts.
func test_coop_stage_3_only_the_far_hero_strikes_the_wrist() -> void:
	var tree: Mangrove = _open(Defs.Difficulty.BEGINNER, 2, true)
	var p1: PlayerBase = _lab.hero(0)
	var p2: PlayerBase = _lab.hero(1)
	tree.hp = 3
	_wake_both()
	_lab.step(PackedInt32Array([0, 0]))
	assert_eq(tree.get_stage(), 3)
	tree._set_fist(Mangrove.Fist.STUCK)
	tree._fist_x = tree.fist_out_x
	p1.respawn_at(Vector2i(tree.fist_out_x - 40, 160))
	p2.respawn_at(Vector2i(tree.fist_out_x + 60, 160))
	_lab.step(PackedInt32Array([0, 0]))
	assert_eq(tree.get_fist_facing(), -1, "the knuckles face P1, the nearer")
	_shot_at(tree.get_fist_rect(), 0)
	_lab.step(PackedInt32Array([0, 0]))
	assert_eq(tree.hp, 3, "P1's hit on the knuckles glances")
	_shot_at(tree.get_fist_rect(), 1)
	_lab.step(PackedInt32Array([0, 0]))
	assert_eq(tree.hp, 2, "P2's on the wrist counts")


## G33: a dozing partner counts for none of Old Mangrove's co-op rules. A twin half "struck" by a hero who no longer
## counts lights nothing. Standing on the resting fist he is carried but pins nothing: the fist punches when its rest is
## over and no count-in plays. In stage 3 the knuckles turn to the hero who plays even while the dozing one is nearer,
## so the player's strike glances - until the partner's player presses something: then the knuckles turn to him and the
## player, on the wrist side now, strikes home.
func test_coop_an_idle_partner_counts_for_nothing() -> void:
	var tree: Mangrove = _open(Defs.Difficulty.BEGINNER, 2, true)
	var p1: PlayerBase = _lab.hero(0)
	var p2: PlayerBase = _lab.hero(1)
	_lab.step(PackedInt32Array([0, 0]))
	assert_true(p2.is_idle(), "a partner who never pressed anything is idle (G33)")
	_lab.wake(0)
	# A twin half from the dozing hero lights nothing; the player's half does.
	_rest_hand(tree)
	_shot_at(tree.get_face_rect(), 0)
	_shot_at(tree.get_hand_rect(), 1)
	_lab.step(PackedInt32Array([0, 0]))
	assert_true(tree._face_tick >= 0, "P1's face half is lit")
	assert_eq(tree._hand_tick, -1, "the dozing P2's 'hit' on the hand lights nothing")
	assert_eq(tree.hp, tree.max_hp, "no twin")
	# The dozing hero on the resting fist pins nothing.
	tree._hand = Mangrove.Hand.AWAY
	tree._hand_timer = 0
	_rest_hand(tree)
	tree._set_fist(Mangrove.Fist.REST)
	tree._fist_x = tree.fist_rest_x
	tree._fist_len = 30
	p1.respawn_at(Vector2i(40, 160))
	p2.respawn_at(Vector2i(204, 120))
	var stood: int = 0
	var punched: int = -1
	var counted: bool = false
	var trace: Array[int] = []
	for t: int in 60:
		_lab.step(PackedInt32Array([0, 0]))
		var top_y: int = tree.floor_y - Mangrove.MANGROVE_FIST_BOX.y
		if t < 12:
			trace.append(p2.sim_pos.y)
		if punched < 0 and absi(p2.sim_pos.y - top_y) <= 2 and absi(p2.sim_pos.x - tree.fist_rest_x) <= 24 \
				and p2.yvel >= 0:
			stood += 1
		assert_eq(tree._standing_mask() & 2, 0, "tick %d: the dozing hero never pins" % t)
		counted = counted or tree._count_in >= 0
		if punched < 0 and tree.get_fist_state() == Mangrove.Fist.OUT:
			punched = t
	assert_true(stood >= 10, "he stood on the fist (%d ticks; feet y %s): carried like on any platform" % [stood, trace])
	assert_true(punched >= 0 and punched <= 30 + Mangrove.MANGROVE_DRAW_TICKS,
			"the fist punched when its rest was over (tick %d)" % punched)
	assert_false(counted, "no count-in for a dozing hero on the fist")
	# Stage 3: the knuckles turn to the player, not to his nearer dozing partner.
	tree.hp = tree.stage_hits[tree.stage_hits.size() - 1]
	tree.hit_cooldown = 0
	_lab.step(PackedInt32Array([0, 0]))
	assert_eq(tree.get_stage(), 3)
	tree._set_fist(Mangrove.Fist.STUCK)
	tree._fist_x = tree.fist_out_x
	_lab.wake(0)
	p1.respawn_at(Vector2i(tree.fist_out_x + 60, 160))
	p2.hit_timer = 0
	p2.respawn_at(Vector2i(tree.fist_out_x - 20, 160))
	_lab.step(PackedInt32Array([0, 0]))
	tree._fist_timer = 0
	assert_true(p2.is_idle() and p1.counts_for_coop())
	assert_eq(tree.get_fist_facing(), 1, "the knuckles face P1, the player, though dozing P2 is nearer")
	var hp: int = tree.hp
	_shot_at(tree.get_fist_rect(), 0)
	_lab.step(PackedInt32Array([0, 0]))
	tree._fist_timer = 0
	assert_eq(tree.hp, hp, "P1's strike meets the knuckles")
	_lab.step(PackedInt32Array([0, Defs.IN_DOWN]))
	tree._fist_timer = 0
	assert_true(p2.counts_for_coop())
	assert_eq(tree.get_fist_facing(), -1, "P2's player pressed something: the knuckles turn to him, the nearer")
	_shot_at(tree.get_fist_rect(), 0)
	_lab.step(PackedInt32Array([0, 0]))
	assert_eq(tree.hp, hp - 1, "P1, on the wrist side now, strikes home")


## V3.d fairness per hero: whichever hero the boss targets, the punch comes after its 10-tick draw-back and its leaf
## falls over HIM from high above; the twin counts whichever hero strikes the face and whichever the hand; either hero
## pins the resting fist; in stage 3 either hero strikes the wrist while the other draws the knuckles.
func test_coop_form_is_fair_to_either_hero() -> void:
	for slot: int in 2:
		var tree: Mangrove = _open(Defs.Difficulty.EXPERT, 2, true)
		var me: PlayerBase = _lab.hero(slot)
		var mate: PlayerBase = _lab.hero(1 - slot)
		_wake_both()
		_lab.step(PackedInt32Array([0, 0]))
		# The target (the nearer hero, on the lower ledge over the punches) and his leaf.
		me.respawn_at(Vector2i(130, 112))
		mate.respawn_at(Vector2i(30, 160))
		tree._held_target = null
		tree._set_fist(Mangrove.Fist.REST)
		tree._fist_len = tree._fist_timer + 2
		var drew: int = 0
		var leaf: SimEntity = null
		for t: int in 20:
			_lab.step(PackedInt32Array([0, 0]))
			drew += 1 if tree.get_fist_state() == Mangrove.Fist.DRAW else 0
			for entity: SimEntity in _lab.level.get_kind(Defs.Kind.ENEMY_PROJECTILE):
				if entity is EnemyEmber and leaf == null:
					leaf = entity
			if leaf != null:
				break
		assert_eq(drew, Mangrove.MANGROVE_DRAW_TICKS, "slot %d targeted: a 10-tick draw-back" % slot)
		assert_not_null(leaf, "slot %d: a leaf" % slot)
		if leaf != null:
			assert_eq(int(leaf.spawn_params.get("rain_slot", -1)), me.slot, "slot %d: the leaf falls on him" % slot)
			assert_true(absi(leaf.sim_pos.x - me.sim_pos.x) <= EnemyTuning.EMBER_DROP_SPREAD,
					"slot %d: over him (x %d, him %d)" % [slot, leaf.sim_pos.x, me.sim_pos.x])
			assert_true(me.sim_pos.y - leaf.sim_pos.y >= 100, "slot %d: from high above (%d px)" % [slot,
				me.sim_pos.y - leaf.sim_pos.y])
		# The twin, both ways round.
		_wait(Tuning.BOSS_HIT_COOLDOWN + 2)
		var hp: int = tree.hp
		_rest_hand(tree)
		_shot_at(tree.get_face_rect(), me.slot)
		_shot_at(tree.get_hand_rect(), mate.slot)
		_lab.step(PackedInt32Array([0, 0]))
		assert_eq(tree.hp, hp - 1, "slot %d on the face, his partner on the hand: a twin" % slot)
		_wait(Tuning.BOSS_HIT_COOLDOWN + 2)
		_rest_hand(tree)
		_shot_at(tree.get_face_rect(), mate.slot)
		_shot_at(tree.get_hand_rect(), me.slot)
		_lab.step(PackedInt32Array([0, 0]))
		assert_eq(tree.hp, hp - 2, "slot %d on the hand, his partner on the face: a twin" % slot)
		# He pins the resting fist.
		tree._set_fist(Mangrove.Fist.REST)
		tree._fist_x = tree.fist_rest_x
		tree._fist_len = tree._fist_timer + 20
		me.respawn_at(Vector2i(204, 120))
		var pinned: int = 0
		var punched: bool = false
		for t: int in 40:
			_lab.step(PackedInt32Array([0, 0]))
			pinned += 1 if (tree._standing_mask() & (1 << me.slot)) != 0 else 0
			punched = punched or tree.get_fist_state() == Mangrove.Fist.OUT
		assert_true(pinned >= 20, "slot %d pins the fist (%d ticks)" % [slot, pinned])
		assert_false(punched, "slot %d: no punch while he pins it" % slot)
		# Stage 3: he draws the knuckles, his partner strikes the wrist.
		_lab.wake(0)
		_lab.wake(1)
		tree.hp = tree.stage_hits[tree.stage_hits.size() - 1]
		tree.hit_cooldown = 0
		_lab.step(PackedInt32Array([0, 0]))
		tree._set_fist(Mangrove.Fist.STUCK)
		tree._fist_x = tree.fist_out_x
		me.respawn_at(Vector2i(tree.fist_out_x - 30, 160))
		mate.respawn_at(Vector2i(tree.fist_out_x + 60, 160))
		_lab.step(PackedInt32Array([0, 0]))
		tree._fist_timer = 0
		hp = tree.hp
		_shot_at(tree.get_fist_rect(), me.slot)
		_lab.step(PackedInt32Array([0, 0]))
		tree._fist_timer = 0
		assert_eq(tree.hp, hp, "slot %d, the nearer: on the knuckles" % slot)
		_shot_at(tree.get_fist_rect(), mate.slot)
		_lab.step(PackedInt32Array([0, 0]))
		assert_eq(tree.hp, hp - 1, "slot %d's partner strikes the wrist" % slot)
		_fresh()


## G34: the twin is slot-bound (two heroes' own hits), so its window is the difficulty's - 24 Beginner / 12 Expert -,
## not capped by one player's solo minimum, which stays a measured fact. The measurement (V3.d's one player with his
## toolkit): P1 launched from the springboard (Up held: the co-op fist launches at once) throws a spear, an axe or a
## swirling axe at the face and then back at the resting hand, every start of both throws, forward or high, while his
## IDLE partner stands where his player could have hatched him (by the resting hand on the upper ledge, on the lower
## ledge, on the floor) or lies on the floor as an egg. No trial ever twins - though one player's two hits come well
## inside the 24-tick window, they never pair - and none is faster than MANGROVE_SOLO_MIN_TICKS. Lighter than at G2:
## spent throws are freed between trials (Lab.flush) and a trial ends once its hits can no longer fall within a window.
func test_coop_one_player_never_twins_and_the_solo_minimum_holds() -> void:
	var measured: Dictionary = _measure_solo_twin()
	print("    one player from the face to the hand: %d ticks at best (%s); %d trials, %d twins, partner counted on %d ticks" % [
		measured["best"], measured["how"], measured["trials"], measured["twins"], measured["partner_counted"]])
	assert_true(int(measured["trials"]) >= 500)
	assert_true(int(measured["best"]) < 100000, "the search reached both parts (it is not blind)")
	assert_true(int(measured["best"]) >= Mangrove.MANGROVE_SOLO_MIN_TICKS,
			"MANGROVE_SOLO_MIN_TICKS (%d) is a lower bound of the measured %d" % [Mangrove.MANGROVE_SOLO_MIN_TICKS,
			measured["best"]])
	assert_true(int(measured["best"]) < PartyTuning.WINDOW_TICKS_BEGINNER,
			"his two hits came inside the Beginner window (%d < 24): the slot rule, not the window, refuses him" % measured["best"])
	assert_eq(int(measured["twins"]), 0, "one player's hits never counted as a twin")
	assert_eq(int(measured["partner_counted"]), 0, "his partner never counted for a co-op rule")


## V3.d, the single-hero search cannot hurt the co-op form: one player never twins (above), never strikes the wrist of
## the stuck fist from either side with any weapon while his IDLE partner stands on the floor on the far side (nearer
## than he: the bait a dozing body would be), further out, on the lower ledge, or lies there as an egg; and the solo
## club route played against the co-op form never hurts it - while the same stage-3 trials alone do hurt the solo form.
func test_the_single_hero_search_cannot_hurt_the_coop_form() -> void:
	var coop: Dictionary = _search_fist(true, true)
	var solo: Dictionary = _search_fist(false, false)
	print("    single-hero search on the stuck fist: %d trials (partner idle %d / egg %d), co-op form hit %d times; solo form hit %d times" % [
		coop["trials"], coop["idle_trials"], coop["egg_trials"], coop["hits"], solo["hits"]])
	assert_true(int(coop["idle_trials"]) >= 100 and int(coop["egg_trials"]) >= 20, "both partner kinds were tried")
	assert_eq(int(coop["partner_counted"]), 0, "the partner never counted")
	assert_eq(int(coop["hits"]), 0, "one player never strikes the wrist: %s" % coop["first"])
	assert_true(int(solo["hits"]) >= 10, "the same trials hurt the solo form")
	var tree: Mangrove = _open(Defs.Difficulty.BEGINNER, 1, true)
	var route: PackedInt32Array = Lab.parse_route(ROUTE_BEGINNER)
	var lowest: Array[int] = [tree.hp]
	_lab.play([route] as Array[PackedInt32Array], func() -> bool:
		lowest[0] = mini(lowest[0], tree.hp)
		return _lab.hero().dead)
	assert_eq(lowest[0], tree.max_hp, "the solo route never hurts the co-op form")


# =================================================================================================================
# Helpers
# =================================================================================================================

## A hero's thrown axe right on `rect` this tick (slot `owner`).
func _shot_at(rect: Rect2i, owner: int = 0) -> void:
	_lab.level.spawn(&"projectiles/hero_axe", Vector2i(rect.get_center().x, rect.end.y - 1),
			{"from_hero": true, "power": 20, "xvel": 0, "yvel": 0, "yacc": 0, "owner": owner})


func _wait(ticks: int) -> void:
	var frame: PackedInt32Array = PackedInt32Array()
	frame.resize(_lab.party)
	for t: int in ticks:
		_lab.step(frame)


## True while some hero projectile is still in flight (not spent, not on its way out of the tree).
func _flying() -> bool:
	for entity: SimEntity in _lab.level.get_kind(Defs.Kind.HERO_PROJECTILE):
		var shot: ProjectileBase = entity as ProjectileBase
		if shot != null and not shot.spent and not shot.is_queued_for_deletion():
			return true
	return false


## Both heroes of a co-op test are players who have just pressed something (G33: they count for the co-op rules).
func _wake_both() -> void:
	_lab.wake(0)
	_lab.wake(1)


## Put the upper hand at rest on the ledge for a long while.
func _rest_hand(tree: Mangrove) -> void:
	tree._hand = Mangrove.Hand.REST
	tree._hand_timer = -100000
	tree._hand_pos = tree.hand_rest


## One player (P1) with a throwing weapon - the spear, the axe, the swirling axe - throws at the face and then turns and
## throws at the resting hand; the least ticks between a face hit and a hand hit. Two families of tries, over the starts
## of both throws (forward or high): launched from the springboard (Up held through the landing: the co-op fist launches
## at once, -224, past the face), and a jump from the lower ledge (since G35 the face, 76-105 px over the floor, and the
## hand on its row-5 ledge share a height band). His partner P2 never presses anything (IDLE, G33) and stands, per trial,
## by the resting hand on the upper ledge, on the lower ledge, on the floor, or lies on the floor as an egg. A trial ends
## when both parts were hit, when the first hit lies a whole twin window back with no second one, or when both throws
## are over and nothing flies any more.
func _measure_solo_twin() -> Dictionary:
	var tree: Mangrove = _open(Defs.Difficulty.BEGINNER, 2, true)
	var hero: PlayerBase = _lab.hero()
	var p2: PlayerBase = _lab.hero(1)
	_lab.step(PackedInt32Array([0, 0]))
	var result: Dictionary = {"best": 100000, "how": "", "trials": 0, "twins": 0, "partner_counted": 0}
	var window: int = tree.twin_window()
	var spots: Array[Vector2i] = [Vector2i(tree.hand_rest.x - 36, 80), Vector2i(60, 112), Vector2i(60, 160),
		Vector2i(150, 160)]
	var frame: PackedInt32Array = PackedInt32Array([0, 0])
	var tries: Array[Dictionary] = []
	for weapon: int in [Defs.Weapon.SPEAR, Defs.Weapon.AXE, Defs.Weapon.BOOMERANG]:
		for first: int in [1, 2, 3]:
			for gap: int in [8, 12, 16, 20, 24]:
				for variant: int in 4:
					tries.append({"weapon": weapon, "ledge": false, "x": 206, "hold": 0, "first": first, "gap": gap,
						"high_first": (variant & 1) != 0, "high": (variant & 2) != 0})
		for x: int in [120, 140]:
			for hold: int in [4, 9]:
				for first: int in [1, 3, 5]:
					for gap: int in [6, 8, 10, 12, 14]:
						for high: bool in [false, true]:
							tries.append({"weapon": weapon, "ledge": true, "x": x, "hold": hold, "first": first,
								"gap": gap, "high_first": false, "high": high})
	for one: Dictionary in tries:
		var ledge: bool = bool(one["ledge"])
		var first: int = int(one["first"])
		var gap: int = int(one["gap"])
		var hold: int = int(one["hold"])
		var high_first: bool = bool(one["high_first"])
		var high: bool = bool(one["high"])
		var trial: int = int(result["trials"])
		result["trials"] = trial + 1
		if hero.run.weapon != int(one["weapon"]):
			hero.run.set_weapon(int(one["weapon"]))
		for entity: SimEntity in _lab.level.get_kind(Defs.Kind.HERO_PROJECTILE):
			(entity as ProjectileBase).consume()
		_lab.flush()
		tree.hp = tree.max_hp
		tree.hit_cooldown = 0
		tree._fist = Mangrove.Fist.REST
		tree._fist_x = tree.fist_rest_x
		tree._fist_len = 100000
		_rest_hand(tree)
		tree._face_tick = -1
		tree._hand_tick = -1
		tree._part_tick.clear()
		hero.respawn_at(Vector2i(int(one["x"]), 112 if ledge else 160))
		hero.facing = 1
		Lab.top_up(hero)
		_lab.wake(0)
		var pick: int = trial % spots.size()
		p2.respawn_at(spots[pick])
		if pick == spots.size() - 1:
			p2.go_down(&"voluntary")
		# The ledge jump starts at once; the springboard's script starts when the launch is seen.
		var launched: int = 0 if ledge else -1
		var face_at: int = -1
		var hand_at: int = -1
		for t: int in 70:
			var flags: int = 0
			if launched < 0:
				# Up held through the landing: the co-op fist launches him at once instead of the pin.
				flags = Defs.IN_UP
			else:
				var k: int = t - launched
				if ledge and k < hold:
					flags = Defs.IN_UP
				if not ledge and k == 1:
					flags = Defs.IN_RIGHT
				elif k >= first + 1 and k < first + 1 + 7:
					flags |= Defs.IN_FIRE | (Defs.IN_UP if high_first else 0)
				elif k == first + gap:
					flags = Defs.IN_LEFT
				elif k > first + gap and k < first + gap + 8:
					flags = Defs.IN_FIRE | (Defs.IN_UP if high else 0)
			frame[0] = flags
			_lab.step(frame)
			if p2.counts_for_coop():
				result["partner_counted"] = int(result["partner_counted"]) + 1
			if launched < 0 and hero.yvel <= -120:
				launched = t
			if face_at < 0 and tree._face_tick >= 0:
				face_at = t
			if hand_at < 0 and tree._hand_tick >= 0:
				hand_at = t
			if face_at >= 0 and hand_at >= 0:
				break
			var lone: int = face_at if hand_at < 0 else hand_at
			if lone >= 0 and t - lone > window:
				break
			if launched >= 0 and t - launched > first + gap + 8 and not _flying():
				break
		if tree.hp < tree.max_hp:
			result["twins"] = int(result["twins"]) + 1
		if face_at >= 0 and hand_at >= 0 and absi(hand_at - face_at) < int(result["best"]):
			result["best"] = absi(hand_at - face_at)
			result["how"] = "weapon %d, %s, throws %d and %d ticks after it%s%s" % [int(one["weapon"]),
				"a jump from the lower ledge at x %d (Up %d)" % [int(one["x"]), hold] if ledge else "the springboard",
				first + 1, first + gap + 1, ", the first high" if high_first else "", ", the second high" if high else ""]
	return result


## One player (P1) against the stuck fist of stage 3 from both sides, every weapon, forward / high / low strikes standing
## and out of jumps. `partner`: P2 never presses anything (IDLE, G33) and stands, per trial, on the floor on the far
## side of the fist (nearer to it than P1: the bait a dozing body would be), further out on the far side, on the lower
## ledge, or lies on the far side as an egg.
func _search_fist(coop_form: bool, partner: bool) -> Dictionary:
	var tree: Mangrove = _open(Defs.Difficulty.BEGINNER, 2 if partner else 1, coop_form)
	var hero: PlayerBase = _lab.hero()
	var p2: PlayerBase = _lab.hero(1) if partner else null
	var frame: PackedInt32Array = PackedInt32Array([0, 0]) if partner else PackedInt32Array([0])
	var result: Dictionary = {"trials": 0, "hits": 0, "first": "", "idle_trials": 0, "egg_trials": 0,
		"partner_counted": 0}
	var start_hp: int = tree.stage_hits[tree.stage_hits.size() - 1]
	for weapon: int in [Defs.Weapon.CLUB, Defs.Weapon.HAMMER, Defs.Weapon.AXE, Defs.Weapon.BOOMERANG,
			Defs.Weapon.SPEAR]:
		hero.run.set_weapon(weapon)
		for dx: int in [-56, -44, -32, -20, 20, 32, 44, 56]:
			for macro: Array in [[12, Defs.IN_FIRE], [12, Defs.IN_UP | Defs.IN_FIRE], [12, Defs.IN_DOWN | Defs.IN_FIRE],
					[-1, Defs.IN_FIRE]]:
				var trial: int = int(result["trials"])
				result["trials"] = trial + 1
				for entity: SimEntity in _lab.level.get_kind(Defs.Kind.HERO_PROJECTILE):
					(entity as ProjectileBase).consume()
				_lab.flush()
				tree.hp = start_hp
				tree.hit_cooldown = 0
				tree._part_tick.clear()
				hero.respawn_at(Vector2i(tree.fist_out_x + dx, 160))
				hero.facing = -signi(dx)
				Lab.top_up(hero)
				if partner:
					_lab.wake(0)
					var spots: Array[Vector2i] = [Vector2i(tree.fist_out_x - signi(dx) * 14, 160),
						Vector2i(tree.fist_out_x - signi(dx) * 40, 160), Vector2i(100, 112),
						Vector2i(tree.fist_out_x - signi(dx) * 24, 160)]
					var pick: int = trial % spots.size()
					p2.respawn_at(spots[pick])
					if pick == spots.size() - 1:
						p2.go_down(&"voluntary")
						result["egg_trials"] = int(result["egg_trials"]) + 1
					else:
						result["idle_trials"] = int(result["idle_trials"]) + 1
				for t: int in 34:
					tree._stage = 3
					tree._fist = Mangrove.Fist.STUCK
					tree._fist_timer = 0
					tree._fist_x = tree.fist_out_x
					var flags: int = int(macro[1])
					if int(macro[0]) < 0:
						flags = (Defs.IN_UP | (Defs.IN_LEFT if dx > 0 else Defs.IN_RIGHT)) if t < 6 else \
								(Defs.IN_FIRE if t < 18 else 0)
					elif t >= int(macro[0]):
						flags = 0
					frame[0] = flags
					_lab.step(frame)
					if partner and p2.counts_for_coop():
						result["partner_counted"] = int(result["partner_counted"]) + 1
				if tree.hp < start_hp:
					result["hits"] = int(result["hits"]) + 1
					if str(result["first"]) == "":
						result["first"] = "weapon %d from dx %d%s" % [weapon, dx, " partner at %s" % p2.sim_pos \
								if partner else ""]
	_fresh()
	return result


# =================================================================================================================
# The bot
# =================================================================================================================

## Plays the solo form with the club. Stages 1-2: waits on the lower ledge (over the punches, under the sweeping hand);
## while the fist rests with time to spare it drops to the floor, jumps onto the fist, is launched, high-strikes the face
## at the apex and jumps back to the ledge; when the upper hand rests it high-strikes it from the ledge. Stage 3: waits
## on the floor beyond the punches' reach and clubs the stuck fist. Steps away from falling leaves. With `attack` off
## it only dodges (the escape test).
class MangroveBot:
	extends RefCounted

	const LEDGE_Y: int = 112
	const UPPER_Y: int = 80
	const UPPER_SAFE: int = 26
	const LEDGE_END: int = 143
	const LEDGE_SPOT: int = 112
	const FLOOR_Y: int = 160
	const FLOOR_SPOT: int = 44
	const FIST_SPOT: int = 206
	var attack: bool = true
	var _jump: int = 0
	var _jump_flags: int = 0
	var _jump_hold: int = 9
	var _launched: int = 0

	func flags(hero: PlayerBase, tree: Mangrove, level: LevelBase) -> int:
		if hero == null or hero.dead or tree == null or tree.dead:
			return 0
		var x: int = hero.sim_pos.x
		var y: int = hero.sim_pos.y
		var grounded: bool = hero.is_grounded()
		if _launched > 0:
			return _launch_tick(hero)
		if not grounded and hero.yvel <= -120 and y < 140:
			_launched = 1
			return _launch_tick(hero)
		if _jump > 0:
			if grounded and _jump > 2:
				_jump = 0
			else:
				_jump += 1
				return _jump_flags | (Defs.IN_UP if _jump <= _jump_hold else 0)
		var stage: int = tree.get_stage()
		var on_ledge: bool = grounded and y == LEDGE_Y
		var on_floor: bool = grounded and y == FLOOR_Y
		var dodge: int = _leaf_dodge(hero, level)
		if stage == 3:
			var bug_flags: int = _bug_flags(hero, level)
			if bug_flags >= 0 and on_floor:
				return bug_flags
			if on_ledge or (grounded and y == UPPER_Y):
				# Down to the floor over the ledge's end while the fist is stuck or rests long enough for the walk to
				# the far wall (one-way ledges cannot be dropped through).
				var fist: int = tree.get_fist_state()
				var stuck: bool = fist == Mangrove.Fist.STUCK
				var resting: bool = fist == Mangrove.Fist.REST and tree._fist_len - tree._fist_timer >= 50
				if stuck or resting:
					return Defs.IN_RIGHT
				return dodge
			if attack and tree.get_fist_state() == Mangrove.Fist.STUCK and tree._fist_timer < Mangrove.MANGROVE_STUCK_TICKS - 4:
				var spot: int = tree.fist_out_x - 40
				if absi(x - spot) > 4:
					return Defs.IN_RIGHT if spot > x else Defs.IN_LEFT
				if hero.facing < 0 and not hero.is_striking():
					return Defs.IN_RIGHT
				return Defs.IN_FIRE
			if dodge != 0:
				return dodge
			var safe: int = FLOOR_SPOT
			if absi(x - safe) > 4:
				return Defs.IN_RIGHT if safe > x else Defs.IN_LEFT
			if hero.facing < 0:
				return Defs.IN_RIGHT
			return 0
		# Stages 1 and 2. The upper hand in the air (shaking out, sweeping, drawing back) owns the space over the lower
		# ledge: no jumps then, and a crouch on the lower ledge (a shake nudge must not lift him into the sweep).
		var hand: int = tree.get_hand_state()
		var hand_out: bool = hand == Mangrove.Hand.SHAKE or hand == Mangrove.Hand.SWEEP or hand == Mangrove.Hand.RETRACT
		var hand_soon: bool = hand == Mangrove.Hand.AWAY and stage == 2 \
				and tree._hand_timer >= Mangrove.MANGROVE_HAND_PAUSE - 24
		var on_upper: bool = grounded and y == UPPER_Y
		if attack and stage == 1 and not hand_out and _go_for_face(tree):
			if on_ledge or on_upper:
				return Defs.IN_RIGHT
			if on_floor:
				if absi(x - FIST_SPOT) > 3:
					return Defs.IN_RIGHT if FIST_SPOT > x else Defs.IN_LEFT
				_start_jump(0, 9)
				return Defs.IN_UP
			return Defs.IN_RIGHT if x < FIST_SPOT else 0
		if on_upper:
			# Off the upper ledge's end while the hand stays in the wall, else wait at its far end.
			if not hand_out and not hand_soon and hand != Mangrove.Hand.REST:
				return Defs.IN_RIGHT
			if x > UPPER_SAFE + 3:
				return Defs.IN_LEFT
			return 0
		if on_floor:
			var fist_coming: bool = tree.get_fist_state() == Mangrove.Fist.DRAW \
					or tree.get_fist_state() == Mangrove.Fist.OUT
			if hand != Mangrove.Hand.AWAY or hand_soon or (fist_coming and x > FLOOR_SPOT + 8):
				# Wait beyond the punches' reach, under nothing.
				if absi(x - FLOOR_SPOT) > 3:
					return Defs.IN_RIGHT if FLOOR_SPOT > x else Defs.IN_LEFT
				return 0
			# Back up to the ledge: jump towards it from under its end.
			if x > LEDGE_END - 4:
				if x > LEDGE_END + 30:
					return Defs.IN_LEFT
				_start_jump(Defs.IN_LEFT, 9)
				return Defs.IN_LEFT | Defs.IN_UP
			_start_jump(Defs.IN_RIGHT, 9)
			return Defs.IN_RIGHT | Defs.IN_UP
		if not on_ledge:
			return Defs.IN_LEFT if x > LEDGE_END - 8 else 0
		if dodge != 0:
			return dodge
		if hand_out or hand_soon:
			if absi(x - LEDGE_SPOT) > 3 and hand == Mangrove.Hand.AWAY:
				return Defs.IN_RIGHT if LEDGE_SPOT > x else Defs.IN_LEFT
			return Defs.IN_DOWN
		if attack and stage == 2 and tree.get_hand_state() == Mangrove.Hand.REST:
			if absi(x - LEDGE_SPOT) > 3:
				return Defs.IN_RIGHT if LEDGE_SPOT > x else Defs.IN_LEFT
			if hero.facing > 0 and not hero.is_striking():
				return Defs.IN_LEFT
			return Defs.IN_UP | Defs.IN_FIRE
		if dodge != 0:
			return dodge
		if absi(x - LEDGE_SPOT) > 3:
			return Defs.IN_RIGHT if LEDGE_SPOT > x else Defs.IN_LEFT
		return 0

	## After the springboard: a forward strike at once while drifting to the wall (since G35 the launch rises through the
	## face, 76-105 px over the floor), then away to the left and back to the ledge.
	func _launch_tick(hero: PlayerBase) -> int:
		_launched += 1
		if hero.is_grounded() and _launched > 4:
			_launched = 0
			if hero.sim_pos.y == FLOOR_Y:
				_start_jump(Defs.IN_LEFT, 9)
				return Defs.IN_LEFT | Defs.IN_UP
			return 0
		if _launched == 2:
			return Defs.IN_RIGHT | Defs.IN_FIRE
		if _launched >= 3 and _launched < 11:
			return Defs.IN_FIRE
		return Defs.IN_LEFT

	func _start_jump(direction: int, hold: int) -> void:
		_jump = 1
		_jump_flags = direction
		_jump_hold = hold

	## The fist rests with enough time left to get there and up.
	func _go_for_face(tree: Mangrove) -> bool:
		return tree.fist_is_springboard() and tree._fist_len - tree._fist_timer >= 60

	## A burrowing bug walking at him on the floor: turn to it and club it when it is close and solid (-1 = no bug).
	func _bug_flags(hero: PlayerBase, level: LevelBase) -> int:
		var best: EnemyBase = null
		for entity: SimEntity in level.get_kind(Defs.Kind.ENEMY):
			var bug: Digger = entity as Digger
			if bug == null or not bug.is_copy() or not bug.awake or bug.dead:
				continue
			if absi(bug.sim_pos.y - hero.sim_pos.y) > 20 or absi(bug.sim_pos.x - hero.sim_pos.x) > 60:
				continue
			if best == null or absi(bug.sim_pos.x - hero.sim_pos.x) < absi(best.sim_pos.x - hero.sim_pos.x):
				best = bug
		if best == null:
			return -1
		var dir: int = 1 if best.sim_pos.x >= hero.sim_pos.x else -1
		if hero.facing != dir and not hero.is_striking():
			return Defs.IN_RIGHT if dir > 0 else Defs.IN_LEFT
		if best.tangible and absi(best.sim_pos.x - hero.sim_pos.x) <= 44:
			return Defs.IN_FIRE
		return 0

	## A leaf about to fall on him: the direction to step aside (0 = none).
	func _leaf_dodge(hero: PlayerBase, level: LevelBase) -> int:
		for entity: SimEntity in level.get_kind(Defs.Kind.ENEMY_PROJECTILE):
			var dx: int = entity.sim_pos.x - hero.sim_pos.x
			var dy: int = hero.sim_pos.y - entity.sim_pos.y
			if absi(dx) < 26 and dy > 0 and dy < 110:
				return Defs.IN_LEFT if dx >= 0 else Defs.IN_RIGHT
		return 0


## Recorded by test_the_club_bot_still_wins with MANGROVE_ROUTE=1 (Beginner, Expert).
const ROUTE_BEGINNER: String = (
	"9:RU,10:R,10:L,2:,8:R,3:,4:L,110:,18:R,9:UF,15:L,1:,2:L,5:,4:R,37:,18:R,9:UF,15:L,1:,3:L,3:,6:R,36:,20:R," +
	"3:U,5:L,9:U,13:,1:R,9:UF,15:L,1:,3:L,4:,4:R,37:,17:R,10:L,9:LU,10:L,16:R,1:,8:L,2:,6:R,67:,20:R,3:U,5:L,9:U," +
	"13:,1:R,9:UF,15:L,1:,3:L,3:,34:D,3:R,1:L,1:UF,3:,11:UF,3:,22:UF,21:D,42:,59:D,8:UF,15:,2:L,2:R,10:,3:R,1:L," +
	"10:,4:L,10:,4:L,10:,2:R,2:L,10:,3:L,1:R,10:,4:L,10:,3:L,20:R,1:,7:R,15:L,4:,7:F,8:L,1:R,1:,8:R,2:,6:L,1:R," +
	"82:,1:R,13:,1:R,13:,1:R,13:,1:R,13:,1:R,13:,1:R,13:,1:R,2:,2:R,14:F,48:,7:F,80:,2:R,4:,2:L,1:R,50:,3:R,13:F," +
	"3:L,1:R,19:,7:F,109:,7:F,59:,1:R,13:,1:R,13:,1:R,13:,1:R,2:,2:R,50:F"
)
const ROUTE_EXPERT: String = (
	"9:RU,10:R,10:L,2:,8:R,3:,4:L,110:,18:R,9:UF,15:L,1:,2:L,5:,4:R,37:,18:R,9:UF,15:L,1:,3:L,3:,6:R,36:,20:R," +
	"3:U,5:L,9:U,13:,1:R,9:UF,15:L,1:,3:L,4:,4:R,37:,17:R,10:L,9:LU,10:L,16:R,1:,8:L,2:,6:R,67:,20:R,3:U,5:L,9:U," +
	"13:,1:R,9:UF,15:L,1:,3:L,4:,4:R,51:,18:R,9:UF,13:L,5:LU,26:R,9:U,12:,6:R,6:L,1:,10:R,1:,8:L,2:,6:R,123:," +
	"20:R,3:U,5:L,9:U,13:,1:R,9:UF,15:L,1:,2:L,32:,21:R,3:U,5:L,9:U,13:,1:R,9:UF,15:L,1:,3:L,3:,34:D,3:R,1:L," +
	"1:UF,3:,11:UF,3:,11:UF,3:,8:UF,21:D,42:,59:D,44:UF,21:D,42:,59:D,8:UF,10:R,25:L,1:R,1:,8:R,3:,4:L,1:R,40:," +
	"7:F,79:,2:R,4:,2:L,1:R,50:,3:R,13:F,3:L,1:R,19:,7:F,109:,7:F,65:,1:R,13:,1:R,13:,1:R,13:,1:R,13:,1:R,2:,2:R," +
	"14:F,24:,7:F,102:,2:R,4:,2:L,1:R,50:,3:R,13:F,3:L,1:R,72:,7:F,102:,1:R,13:,1:R,13:,1:R,13:,1:R,13:,1:R,2:," +
	"2:R,14:F,60:,7:F,107:,2:R,40:,2:R,11:,1:F,3:,5:R,41:F"
)
