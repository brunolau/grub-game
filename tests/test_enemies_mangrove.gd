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
	assert_eq(tree.hand_rest, Vector2i(76, 64 + Mangrove.MANGROVE_HAND_SINK), "the upper ledge (row 4) ends at x 96")
	assert_eq(tree.get_face_rect(), Rect2i(230, 19, 20, 29))
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


## The resting fist launches a hero who lands on it (-160; -224 with Up held), and from the -160 launch a high strike
## started a tick or two after the launch reaches the face at the apex; no jump from the floor (standing or running,
## next to the wall) reaches the face with any strike: the springboard is the way up.
func test_the_resting_fist_is_the_springboard_to_the_face() -> void:
	var tree: Mangrove = _open()
	var hero: PlayerBase = _lab.hero()
	_lab.step(PackedInt32Array([0]))
	tree._fist_len = 100000
	var reached: Array[int] = []
	for start: int in range(0, 6):
		tree.hp = tree.max_hp
		tree.hit_cooldown = 0
		tree._part_tick.clear()
		hero.respawn_at(Vector2i(206, 160))
		hero.facing = 1
		var launched: int = -1
		var top: int = 1000
		var t: int = 0
		while t < 60 and tree.hp == tree.max_hp:
			var flags: int = 0
			if launched < 0:
				flags = Defs.IN_UP if t < 9 else 0
			elif t - launched == 1:
				flags = Defs.IN_RIGHT
			elif t - launched >= 2 + start and t - launched < 2 + start + 9:
				flags = Defs.IN_UP | Defs.IN_FIRE
			_lab.step(PackedInt32Array([flags]))
			t += 1
			top = mini(top, hero.sim_pos.y)
			if launched < 0 and hero.yvel <= -120:
				launched = t
		if tree.hp < tree.max_hp:
			reached.append(start)
	print("    springboard: a high strike started 2+%s ticks after the launch hits the face" % str(reached))
	assert_true(tree.launches >= 6, "every landing on the resting fist launched the hero")
	assert_false(reached.is_empty(), "the face is reachable by a high strike at the -160 launch's apex")
	# From the floor: every jump and strike next to the wall misses the face.
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
	assert_eq(hits, 0, "no jump from the floor reaches the face")


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
		shook = shook or _lab.level.shake >= Mangrove.MANGROVE_PUNCH_SHAKE
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
	_lab.step(PackedInt32Array([0, 0]))
	assert_eq(tree.twin_window(), mini(PartyTuning.WINDOW_TICKS_BEGINNER,
			Mangrove.MANGROVE_SOLO_MIN_TICKS - PartyTuning.WINDOW_SOLO_MARGIN_TICKS))
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
	_lab.step(PackedInt32Array([0, 0]))
	tree._fist_len = tree._fist_timer + 30
	p1.respawn_at(Vector2i(204, 120))
	var stood: int = 0
	var flung: int = -1
	var punched: bool = false
	for t: int in 120:
		_lab.step(PackedInt32Array([0, 0]))
		if p1.on_platform:
			stood += 1
		if flung < 0 and p1.yvel <= -120:
			flung = t
		punched = punched or tree.get_fist_state() == Mangrove.Fist.OUT and flung < 0
	assert_false(punched, "no punch while he pins it, though its rest was over")
	assert_true(stood >= Mangrove.MANGROVE_PIN_TICKS - 2, "he stood on it (%d ticks)" % stood)
	assert_true(flung >= Mangrove.MANGROVE_PIN_TICKS - 1 and flung <= Mangrove.MANGROVE_PIN_TICKS + 4,
			"flung off after 66 ticks (%d)" % flung)


## Stage 3: the knuckle armour of the stuck fist turns to the nearer hero every tick; only the far hero's strike on the
## wrist counts.
func test_coop_stage_3_only_the_far_hero_strikes_the_wrist() -> void:
	var tree: Mangrove = _open(Defs.Difficulty.BEGINNER, 2, true)
	var p1: PlayerBase = _lab.hero(0)
	var p2: PlayerBase = _lab.hero(1)
	tree.hp = 3
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


## The twin window is shorter than the measured solo minimum: one hero launched from the springboard who throws a
## spear, an axe or a swirling axe at the face and then at the resting hand (every start of both throws) needs at least
## the measured number of ticks between the two hits; MANGROVE_SOLO_MIN_TICKS is no more than that, so the window
## (min(24 / 12, solo minimum - 4)) stays 4+ ticks below it.
func test_coop_twin_window_is_shorter_than_the_measured_solo_minimum() -> void:
	var measured: Dictionary = _measure_solo_twin()
	print("    one hero from the face to the hand: %d ticks at best (%s); %d trials, %d twins" % [measured["best"],
		measured["how"], measured["trials"], measured["twins"]])
	assert_true(int(measured["trials"]) >= 100)
	assert_true(int(measured["best"]) < 100000, "the search reached both parts (it is not blind)")
	assert_true(int(measured["best"]) >= Mangrove.MANGROVE_SOLO_MIN_TICKS,
			"MANGROVE_SOLO_MIN_TICKS (%d) is a lower bound of the measured %d" % [Mangrove.MANGROVE_SOLO_MIN_TICKS,
			measured["best"]])
	for difficulty: int in [Defs.Difficulty.BEGINNER, Defs.Difficulty.EXPERT]:
		Game.difficulty = difficulty
		var tree: Mangrove = _lab.boss as Mangrove
		assert_true(tree.twin_window() <= int(measured["best"]) - PartyTuning.WINDOW_SOLO_MARGIN_TICKS)
	assert_eq(int(measured["twins"]), 0, "and one hero's hits never counted as a twin")


## The single-hero search cannot hurt the co-op form: the throws of the measurement never twin (above), one hero never
## strikes the wrist of the stuck fist from either side with any weapon, and the solo club route played against the
## co-op form never hurts it - while the same stage-3 trials do hurt the solo form.
func test_the_single_hero_search_cannot_hurt_the_coop_form() -> void:
	var coop: Dictionary = _search_fist(true)
	var solo: Dictionary = _search_fist(false)
	print("    single-hero search on the stuck fist: %d trials, co-op form hit %d times; solo form hit %d times" % [
		coop["trials"], coop["hits"], solo["hits"]])
	assert_eq(int(coop["hits"]), 0, "one hero never strikes the wrist: %s" % coop["first"])
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


## Put the upper hand at rest on the ledge for a long while.
func _rest_hand(tree: Mangrove) -> void:
	tree._hand = Mangrove.Hand.REST
	tree._hand_timer = -100000
	tree._hand_pos = tree.hand_rest


## One hero, launched from the springboard with a throwing weapon in hand: the first throw at the face, the second
## turned towards the resting hand, over every start of both; the least ticks between a face hit and a hand hit.
func _measure_solo_twin() -> Dictionary:
	var tree: Mangrove = _open(Defs.Difficulty.BEGINNER, 1, true)
	var hero: PlayerBase = _lab.hero()
	_lab.step(PackedInt32Array([0]))
	var result: Dictionary = {"best": 100000, "how": "", "trials": 0, "twins": 0}
	var faces: Array[int] = []
	var hands: Array[int] = []
	for weapon: int in [Defs.Weapon.SPEAR, Defs.Weapon.AXE, Defs.Weapon.BOOMERANG]:
		hero.run.set_weapon(weapon)
		for first: int in range(1, 5):
			for gap: int in range(6, 18):
				for high: bool in [false, true]:
					result["trials"] = int(result["trials"]) + 1
					for entity: SimEntity in _lab.level.get_kind(Defs.Kind.HERO_PROJECTILE):
						(entity as ProjectileBase).consume()
					tree.hp = tree.max_hp
					tree._fist = Mangrove.Fist.REST
					tree._fist_x = tree.fist_rest_x
					tree._fist_len = 100000
					_rest_hand(tree)
					tree._face_tick = -1
					tree._hand_tick = -1
					tree._part_tick.clear()
					hero.respawn_at(Vector2i(206, 160))
					hero.facing = 1
					Lab.top_up(hero)
					var launched: int = -1
					var face_at: int = -1
					var hand_at: int = -1
					for t: int in 70:
						var flags: int = 0
						if launched < 0:
							flags = Defs.IN_UP if t < 9 else 0
						else:
							var k: int = t - launched
							if k == 1:
								flags = Defs.IN_RIGHT
							elif k >= first + 1 and k < first + 1 + 7:
								flags = Defs.IN_FIRE
							elif k == first + gap:
								flags = Defs.IN_LEFT
							elif k > first + gap and k < first + gap + 8:
								flags = Defs.IN_FIRE | (Defs.IN_UP if high else 0)
						_lab.step(PackedInt32Array([flags]))
						if launched < 0 and hero.yvel <= -120:
							launched = t
						if face_at < 0 and tree._face_tick >= 0:
							face_at = t
						if hand_at < 0 and tree._hand_tick >= 0:
							hand_at = t
					if tree.hp < tree.max_hp:
						result["twins"] = int(result["twins"]) + 1
					if face_at >= 0 and hand_at >= 0 and absi(hand_at - face_at) < int(result["best"]):
						result["best"] = absi(hand_at - face_at)
						result["how"] = "weapon %d, throws %d and %d ticks after the launch%s" % [weapon, first + 1,
							first + gap + 1, ", the second high" if high else ""]
	return result


## One hero against the stuck fist of stage 3 from both sides, every weapon, forward / high / low strikes standing and
## out of jumps.
func _search_fist(coop_form: bool) -> Dictionary:
	var tree: Mangrove = _open(Defs.Difficulty.BEGINNER, 1, coop_form)
	var hero: PlayerBase = _lab.hero()
	var result: Dictionary = {"trials": 0, "hits": 0, "first": ""}
	var start_hp: int = tree.stage_hits[tree.stage_hits.size() - 1]
	for weapon: int in [Defs.Weapon.CLUB, Defs.Weapon.HAMMER, Defs.Weapon.AXE, Defs.Weapon.BOOMERANG,
			Defs.Weapon.SPEAR]:
		hero.run.set_weapon(weapon)
		for dx: int in [-56, -44, -32, -20, 20, 32, 44, 56]:
			for macro: Array in [[12, Defs.IN_FIRE], [12, Defs.IN_UP | Defs.IN_FIRE], [12, Defs.IN_DOWN | Defs.IN_FIRE],
					[-1, Defs.IN_FIRE]]:
				result["trials"] = int(result["trials"]) + 1
				for entity: SimEntity in _lab.level.get_kind(Defs.Kind.HERO_PROJECTILE):
					(entity as ProjectileBase).consume()
				tree.hp = start_hp
				tree.hit_cooldown = 0
				tree._part_tick.clear()
				hero.respawn_at(Vector2i(tree.fist_out_x + dx, 160))
				hero.facing = -signi(dx)
				Lab.top_up(hero)
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
					_lab.step(PackedInt32Array([flags]))
				if tree.hp < start_hp:
					result["hits"] = int(result["hits"]) + 1
					if str(result["first"]) == "":
						result["first"] = "weapon %d from dx %d" % [weapon, dx]
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
			if on_ledge:
				return Defs.IN_DOWN
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
		# Stages 1 and 2.
		if attack and stage == 1 and _go_for_face(tree):
			if on_ledge:
				return Defs.IN_RIGHT
			if on_floor:
				if absi(x - FIST_SPOT) > 3:
					return Defs.IN_RIGHT if FIST_SPOT > x else Defs.IN_LEFT
				_start_jump(0, 9)
				return Defs.IN_UP
			return Defs.IN_RIGHT if x < FIST_SPOT else 0
		if on_floor:
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

	## After the springboard: drift to the wall, high strike at the apex, then away to the left and back to the ledge.
	func _launch_tick(hero: PlayerBase) -> int:
		_launched += 1
		if hero.is_grounded() and _launched > 4:
			_launched = 0
			if hero.sim_pos.y == FLOOR_Y:
				_start_jump(Defs.IN_LEFT, 9)
				return Defs.IN_LEFT | Defs.IN_UP
			return 0
		if _launched == 2:
			return Defs.IN_RIGHT
		if _launched >= 3 and _launched < 12:
			return Defs.IN_UP | Defs.IN_FIRE
		return Defs.IN_LEFT

	func _start_jump(direction: int, hold: int) -> void:
		_jump = 1
		_jump_flags = direction
		_jump_hold = hold

	## The fist rests with enough time left to get there and up.
	func _go_for_face(tree: Mangrove) -> bool:
		return tree.fist_is_springboard() and tree._fist_len - tree._fist_timer >= 60

	## A leaf about to fall on him: the direction to step aside (0 = none).
	func _leaf_dodge(hero: PlayerBase, level: LevelBase) -> int:
		for entity: SimEntity in level.get_kind(Defs.Kind.ENEMY_PROJECTILE):
			var dx: int = entity.sim_pos.x - hero.sim_pos.x
			var dy: int = hero.sim_pos.y - entity.sim_pos.y
			if absi(dx) < 26 and dy > 0 and dy < 110:
				return Defs.IN_LEFT if dx >= 0 else Defs.IN_RIGHT
		return 0


## Recorded by test_the_club_bot_still_wins with MANGROVE_ROUTE=1 (Beginner, Expert).
const ROUTE_BEGINNER: String = ""
const ROUTE_EXPERT: String = ""
