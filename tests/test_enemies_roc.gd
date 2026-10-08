extends "res://tests/test_enemies_case.gd"
## The Storm Roc (scripts/bosses/roc.gd, scripts/projectiles/boss_bolt.gd; DESIGN.md B.5, GAMEPLAY.md 13.6; PLAN.md
## P2.3, owner enemies-C): the nest and the perch, phase 1 (wings telegraph, gusts of wind, feathers, the head open from
## the nest), phase 2 (circle, a 14-tick screech, the dive, the buried beak), phase 3 (lightning marked 22 ticks ahead,
## burning nest sticks, the gliders on the nest, three glider dives, the defeat), the hit-point floor between the
## phases; the co-op form (the wing shield, the Snatch and the rescue, Pilot and Spotter) and the single-hero search;
## the weak points clear of the HUD (G35) with the phase-3 cruise over one runway half (G46); a nest bolt sparing the
## hero beneath the nest; and the recorded club (+ glider) routes on the test level.
##
## The room: 20 x 12 cells, invisible walls in columns 0 and 19, the nest of one-way cells in columns 6-13 of row 8
## (top y 128), the floor at row 10 (feet y 160). The Roc's record stands on the nest at column 9.

const PLAYER_SCENE: String = "res://scenes/player/player.tscn"
const NEST_X0: int = 96
const NEST_X1: int = 224
const NEST_TOP: int = 128
## The developer level (the same nest and floor; no clouds over the runways, G46; its arena locks the authentic 11-row
## view), played in the real level scene by the Lab of tests/test_enemies_tusker.gd.
const LEVEL_PATH: String = "res://levels/test_enemies_roc.lvl"
const Lab = preload("res://tests/test_enemies_tusker.gd").Lab

var _p2: PlayerBase = null
## Where the single-hero search keeps its idle partner (x < 0: none kept).
var _p2_spot: Vector2i = Vector2i(-1, -1)
var _defeated: Array[BossBase] = []
var _lab: Lab = null
var _was_manual: bool = false


func before_each() -> void:
	super.before_each()
	_defeated.clear()
	_p2 = null
	_p2_spot = Vector2i(-1, -1)
	_lab = null
	_was_manual = Sim.manual
	Events.boss_defeated.connect(_on_defeated)


func after_each() -> void:
	Events.boss_defeated.disconnect(_on_defeated)
	GameInput.clear_scripted()
	Game.helper_mode = false
	if _level != null and is_instance_valid(_level):
		_level.set_wind(0)
	if _lab != null:
		if _lab.level != null and is_instance_valid(_lab.level):
			_lab.level.set_wind(0)
		Sim.stop()
		Sim.manual = _was_manual
		Audio.stop_music(0.0)
		Lab.cleanup_flow(get_tree())
		_lab = null
	Game.new_game(Defs.Difficulty.BEGINNER)
	Game.begin_level(&"")


# =================================================================================================================
# The test level: the weak points clear of the HUD
# =================================================================================================================

## G35 (lead designer, wf9 #2 as corrected): on the test level's locked view every strikable pose keeps its weak point
## wholly in the view and clear of the fight HUD (ui's Hud.weak_point_problem) - the perched head band on both rims,
## the buried / stunned head, the tumbling tail.
func test_the_weak_points_stay_clear_of_the_hud_on_the_test_level() -> void:
	var roc: Roc = _open_lab(Defs.Difficulty.EXPERT)
	_lab.step(PackedInt32Array([0]))
	var view: Rect2i = _lab.level.get_view_rect()
	var poses: Array[Array] = []
	for rim: int in [0, 1]:
		roc._perch(rim)
		poses.append(["perched on rim %d" % rim, roc.get_head_rect()])
		roc._set_state(Roc.State.BURIED)
		poses.append(["beak buried on rim %d" % rim, roc.get_head_rect()])
	roc._tumble()
	roc._dive_pending = true
	poses.append(["tumbling", roc.get_head_rect()])
	roc._dive_pending = false
	for pose: Array in poses:
		var rect: Rect2i = pose[1]
		assert_true(rect.has_area(), "%s: a weak point" % pose[0])
		assert_true(view.encloses(rect), "%s: wholly in the view" % pose[0])
		var art: Rect2 = Rect2(Vector2(rect.position - view.position) * 2, Vector2(rect.size) * 2)
		assert_eq(Hud.weak_point_problem(art, Vector2(view.size) * 2), "", "%s: the HUD rule" % pose[0])


## G46 (lead designer, wf9 #3; DESIGN.md B.5): in the storm the Roc cruises over ONE runway half - the right one first,
## then the left - with its feet 61 px over the floor (29 over the nest top), its back (the glider dive's weak point,
## get_head_rect there) wholly in the view, out of the boss bar's columns and 55 px under the view's top in every view
## the arena's lock allows (Lab.hud_clear: Hud.weak_point_problem), its feet point a cell or more off the nest; a hero
## standing on the floor keeps 26 px under it. The test level's lock is the authentic 11-row view (its top = the
## arena's top).
func test_the_storm_cruise_keeps_its_back_clear_of_the_hud_on_the_test_level() -> void:
	var roc: Roc = _open_lab(Defs.Difficulty.EXPERT)
	var hero: PlayerBase = _lab.hero()
	_lab.step(PackedInt32Array([0]))
	assert_true(_lab.level.is_camera_locked(), "the arena zone locks the camera")
	var views: Array[Rect2i] = _lab.locked_views()
	for view: Rect2i in views:
		assert_eq(view.position.y, 0, "every lockable view's top is the arena's top (%s)" % view)
	assert_eq(roc.lowest_view_top(), 0)
	var floor_y: int = 160
	roc.hp = roc.get_storm_hp()
	roc._begin_storm()
	var view_centre: int = _lab.level.get_view_rect().get_center().x
	for cruise: int in 2:
		var cruised: int = 0
		for tick: int in 800:
			# The hero stays on the floor at the far end (kept alive): the bolts follow him, the swoops miss or hurt him.
			_lab.step(PackedInt32Array([0]))
			Lab.top_up(hero)
			hero.hit_timer = mini(hero.hit_timer, 1)
			var back: Rect2i = roc.get_back_rect()
			if roc.get_state() == Roc.State.CRUISE or roc.get_state() == Roc.State.SWOOP_SCREECH:
				cruised += 1
				assert_eq(roc.get_head_rect(), back, "the back is the weak point the HUD sees")
				assert_eq(back, roc.get_box(), "the whole body")
				var problem: String = _lab.hud_clear(back)
				if problem != "":
					assert_eq(problem, "", "cruise %d tick %d" % [cruise, tick])
					return
				assert_eq(roc.sim_pos.y, floor_y - 61, "feet 61 px over the floor")
				assert_eq(roc.sim_pos.y, NEST_TOP - 29, "29 px over the nest top")
				assert_eq(back.position.y - _lab.level.get_view_rect().position.y, 55, "the back's top 55 px under the view's top")
				assert_true(back.end.x <= view_centre - Roc.BAR_LEFT_PX or back.position.x >= view_centre + Roc.BAR_RIGHT_PX,
						"out of the boss bar's columns (%s)" % back)
				assert_true(floor_y - Tuning.HERO_BOX_STAND.y - roc.sim_pos.y >= 26, "a hero on the floor keeps 26 px under it")
				if cruise == 0:
					assert_true(roc.sim_pos.x >= NEST_X1 + Tuning.TILE, "cruise 1: the right half, a cell off the nest (%d)" % roc.sim_pos.x)
				else:
					assert_true(roc.sim_pos.x <= NEST_X0 - Tuning.TILE, "cruise 2: the left half, a cell off the nest (%d)" % roc.sim_pos.x)
			elif cruised > 0:
				break
			else:
				assert_false(back.has_area(), "no back to dive on while it storms or comes down (state %d)" % roc.get_state())
			hero.teleport(Vector2i(30 if cruise == 0 else 290, floor_y))
		assert_eq(cruised, Roc.CRUISE_TICKS + Roc.SCREECH_TICKS, "cruise %d: it cruised and screeched at the spot" % cruise)
		_step_lab_until(func() -> bool: return roc.get_state() == Roc.State.STORM, 400)


## G46: only the cruise spot takes a glider dive (its back clear of the HUD); coming down or swooping a gliding hero
## who lands on it just bounces; and no weapon ever counts on the cruising Roc (phase 3 falls to the dives alone).
func test_the_glider_dive_counts_only_at_the_cruise_spot_and_weapons_never() -> void:
	var roc: Roc = _fight()
	_hero.teleport(Vector2i(30, 160))
	roc.hp = roc.get_storm_hp()
	roc._begin_storm()
	_step_until(func() -> bool: return roc.get_state() == Roc.State.DESCEND, 400)
	Sim.step(10)
	assert_eq(roc.get_state(), Roc.State.DESCEND)
	assert_false(roc.get_head_rect().has_area(), "coming down: no weak point")
	_glide_onto(_hero, roc)
	Sim.step(1)
	_hero.glide = 0
	assert_eq(roc.dive_count, 0, "a landing on the descending Roc counts nothing")
	assert_ne(roc.get_state(), Roc.State.TUMBLE)
	_hero.teleport(Vector2i(30, 160))
	_step_until(func() -> bool: return roc.get_state() == Roc.State.CRUISE, 200)
	_hero.club_box_active = true
	_hero.club_box = roc.get_head_rect()
	_hero.club_power = 100
	Sim.step(1)
	_hero.club_box_active = false
	assert_eq(roc.hp, roc.get_storm_hp(), "a club on its back counts nothing")
	_throw_at(roc.get_head_rect(), 100)
	Sim.step(1)
	assert_eq(roc.hp, roc.get_storm_hp(), "nor a throw")
	_glide_onto(_hero, roc)
	Sim.step(1)
	_hero.glide = 0
	assert_eq(roc.dive_count, 1, "the glider dive at the cruise spot counts")
	assert_eq(roc.get_state(), Roc.State.TUMBLE)
	_hero.teleport(Vector2i(30, 160))
	_step_until(func() -> bool: return roc.get_state() == Roc.State.SWOOP, 800)
	assert_eq(roc.get_state(), Roc.State.SWOOP)
	assert_false(roc.get_head_rect().has_area(), "swooping: no weak point")
	_glide_onto(_hero, roc)
	Sim.step(1)
	_hero.glide = 0
	assert_eq(roc.dive_count, 1, "a landing on the swooping Roc counts nothing")


func _step_lab_until(done: Callable, max_ticks: int) -> int:
	for tick: int in max_ticks:
		_lab.step(PackedInt32Array([0]))
		Lab.top_up(_lab.hero())
		if done.call():
			return tick + 1
	return -1


## The test level in the real level scene (the fixture's own room freed first), one real hero, club in hand.
func _open_lab(difficulty: int, party: int = 1) -> Roc:
	if _level != null and is_instance_valid(_level):
		_level.free()
	_level = null
	_hero = null
	_lab = Lab.new()
	assert_true(_lab.open(self, LEVEL_PATH, "bosses/roc", difficulty, party), "the nest came up")
	return _lab.boss as Roc


func _close_lab() -> void:
	if _lab != null and _lab.level != null and is_instance_valid(_lab.level):
		_lab.level.set_wind(0)
		_lab.level.free()
	GameInput.clear_scripted()
	_lab = null


# =================================================================================================================
# The test level: the recorded club routes (G2 criterion)
# =================================================================================================================

## G2 criterion (PLAN.md 5, enemies-C): the solo Storm Roc falls to the club - and the hang-glider of its last phase -
## on its test level, played by the real hero from the level start with no refill: replayed tick for tick from the
## routes [RocClubPilot] recorded (ROC_ROUTE=1 on test_the_club_pilot_still_wins_on_the_test_level prints fresh ones).
## The club stays his weapon all the way (the glider is no weapon); every phase is played: the gale, the dives (or
## enough head hits on the perch to skip them), three glider dives onto its back in the storm.
func test_the_club_routes_beat_the_solo_roc_on_the_test_level() -> void:
	for case: Array in [[Defs.Difficulty.BEGINNER, ROUTE_BEGINNER], [Defs.Difficulty.EXPERT, ROUTE_EXPERT]]:
		var roc: Roc = _open_lab(int(case[0]))
		var hero: PlayerBase = _lab.hero()
		var lives: int = Game.lives
		var route: PackedInt32Array = Lab.parse_route(str(case[1]))
		var specials: Array[int] = [0]
		var dives: Array[int] = [0]
		var played: int = _lab.play([route] as Array[PackedInt32Array], func() -> bool:
			if hero.run.weapon != Defs.Weapon.CLUB:
				specials[0] += 1
			dives[0] = roc.dive_count
			return roc.dead or hero.dead)
		print("    roc route difficulty %d: beaten on tick %d of %d, hearts %d bones %d" % [case[0], played, route.size(),
				hero.run.hearts, hero.run.bones])
		assert_true(roc.dead, "difficulty %d: the club route beats the Storm Roc (hp left %d, state %d)" % [case[0], roc.hp,
				roc.get_state()])
		assert_eq(dives[0], 3, "three glider dives in the storm")
		assert_false(hero.dead, "difficulty %d: without a death" % case[0])
		assert_eq(Game.lives, lives, "no life lost")
		assert_eq(specials[0], 0, "the club his weapon all the way")
		assert_false(roc.is_coop_form(), "the solo form")
		_close_lab()


## The pilot that recorded those routes still wins from the level start (a guard against tuning drift). ROC_ROUTE=1
## prints the fresh routes; ROC_DEBUG=<tick> traces ROC_SPAN (600) ticks from there, every ROC_EVERY-th (3).
func test_the_club_pilot_still_wins_on_the_test_level() -> void:
	var trace_from: int = OS.get_environment("ROC_DEBUG").to_int() if OS.has_environment("ROC_DEBUG") else -1
	var span: int = OS.get_environment("ROC_SPAN").to_int() if OS.has_environment("ROC_SPAN") else 600
	var every: int = maxi(OS.get_environment("ROC_EVERY").to_int(), 1) if OS.has_environment("ROC_EVERY") else 3
	for difficulty: int in [Defs.Difficulty.BEGINNER, Defs.Difficulty.EXPERT]:
		var roc: Roc = _open_lab(difficulty)
		var hero: PlayerBase = _lab.hero()
		var pilot: RocClubPilot = RocClubPilot.new()
		var hurts: Array[String] = []
		var on_hurt: Callable = func(_h: PlayerBase, kind: int, source: SimEntity) -> void:
			hurts.append("t%d kind %d by %s at %s (hero %s, roc state %d)" % [_lab.ticks(), kind,
					source.scene_file_path.get_file() if source != null else "-", source.sim_pos if source != null
					else Vector2i.ZERO, _h.sim_pos, roc.get_state()])
		Events.hero_hurt.connect(on_hurt)
		for tick: int in 9000:
			var f: int = pilot.flags(hero, roc, _lab.level)
			if trace_from >= 0 and tick >= trace_from and tick < trace_from + span and tick % every == 0:
				var body: Player = hero as Player
				print("t%d hero %s v(%d,%d) g%s glide %d lift %d tilt %d run %d | roc %d %s hp %d cd %d dives %d | %s %s" % [
						tick, hero.sim_pos, hero.xvel, hero.yvel, hero.is_grounded(), hero.glide, body.glider_lift,
						body.glider_tilt, body.glider_runup, roc.get_state(), roc.sim_pos, roc.hp, roc.hit_cooldown,
						roc.dive_count, Lab.keys(f), pilot.note])
			_lab.step(PackedInt32Array([f]))
			if roc.dead or hero.dead:
				break
		Events.hero_hurt.disconnect(on_hurt)
		if OS.get_environment("ROC_ROUTE") != "":
			print("ROUTE %d %s" % [difficulty, Lab.route_text(_lab.streams[0])])
		print("    roc pilot difficulty %d: dead %s after %d ticks, hp %d, dives %d, hearts %d bones %d, hero dead %s" % [
				difficulty, roc.dead, _lab.ticks(), roc.hp, roc.dive_count, hero.run.hearts, hero.run.bones, hero.dead])
		if trace_from >= 0 or not roc.dead:
			for line: String in hurts:
				print("      hurt " + line)
		assert_true(roc.dead, "difficulty %d: the club pilot beats the Storm Roc (hp left %d)" % [difficulty, roc.hp])
		assert_false(hero.dead)
		_close_lab()


## The club-and-glider pilot of the solo Storm Roc on the test level (it recorded ROUTE_BEGINNER / ROUTE_EXPERT).
## - Perched (the gale): a high strike at the head band from the nest beside it (PERCH_DX from its feet point, on the
##   nest's inner side) whenever a hit may count. On the floor it walks under the nest to that spot - crawling where the
##   perched body (its feet 3 px under a standing hero's head) would touch him - and jumps straight up onto the nest.
## - The dives: it waits on the floor in the middle; when the Roc dives it runs on in the dive's direction (the Roc
##   buries its beak where he stood), then strikes forward at the low head from BURIED_DX in front of the beak.
## - The storm: it fetches the glider from the nest, steps out of every marked bolt column, and waits on the floor at the
##   far end of the coming cruise half (the Roc comes down over the right half first, then the halves alternate); when
##   it comes down it runs up across the floor away from it (24 ticks at speed), takes off and climbs, turns, dives once
##   at speed to refill the lift and climbs again over the cruising Roc, then dives onto its back (yvel > 32).
class RocClubPilot:
	extends RefCounted

	const FLOOR_Y: int = 160
	const NEST_TOP: int = 128
	const NEST_X0: int = 96
	const NEST_X1: int = 224
	const MID_X: int = 160
	const X_MIN: int = 32
	const X_MAX: int = 288
	const PERCH_DX: int = 62
	const BURIED_DX: int = 40
	const HIGH_TICKS: int = 9
	const STRIKE_TICKS: int = 7
	const JUMP_TICKS: int = 8
	const BOLT_CLEAR: int = 30
	const REFILL_LIFT: int = 25

	var plan: Array[int] = []
	## What it is doing (traces).
	var note: String = ""
	var _dodge_dir: int = 0
	## Storm: the cruise half it prepares for (1 right, 0 left), the run-up direction while it runs (0: none), true
	## while the dive-to-refill lasts.
	var _half: int = -1
	var _run: int = 0
	var _refill: bool = false
	var _last_x: int = -100000
	var _stuck: int = 0

	func flags(hero: PlayerBase, roc: Roc, level: LevelBase) -> int:
		if not plan.is_empty():
			return plan.pop_front()
		if roc.dead or roc.get_state() == Roc.State.DYING:
			note = "won"
			return 0
		if hero.hit_timer >= Tuning.HIT_STUN_MIN:
			note = "hurt"
			return 0
		if roc.is_storm_phase():
			return _storm(hero, roc, level)
		match roc.get_state():
			Roc.State.REST, Roc.State.WINGS, Roc.State.GUST:
				_dodge_dir = 0
				return _perched(hero, roc)
			Roc.State.DIVE:
				return _dodge(hero, roc)
			Roc.State.BURIED:
				return _buried(hero, roc)
		_dodge_dir = 0
		note = "middle"
		return _to_floor_spot(hero, MID_X, null)

	# --- Phase 1 ------------------------------------------------------------------------------------------------------

	func _perched(hero: PlayerBase, roc: Roc) -> int:
		var rx: int = roc.sim_pos.x
		var inward: int = 1 if rx < MID_X else -1
		var spot: int = rx + inward * PERCH_DX
		if not hero.is_grounded():
			note = "air"
			return 0
		if hero.sim_pos.y >= FLOOR_Y:
			note = "to perch spot (floor)"
			if absi(hero.sim_pos.x - spot) <= 2 and absi(hero.xvel) < 16:
				for i: int in JUMP_TICKS - 1:
					plan.append(Defs.IN_UP)
				return Defs.IN_UP
			return _floor_walk(hero, spot, roc)
		note = "perch spot"
		var move: int = go_to(hero, spot)
		if move >= 0:
			return move
		var face: int = -inward
		if hero.facing != face:
			return key_of(face)
		if hero.attack_gate:
			return 0
		if roc.hit_cooldown == 0 and roc.hp > roc.get_storm_hp() \
				and Overlap.rects(high_box(hero.sim_pos, face), roc.get_head_rect()):
			note = "high strike"
			for i: int in HIGH_TICKS - 2:
				plan.append(Defs.IN_UP | Defs.IN_FIRE)
			plan.append(0)
			return Defs.IN_UP | Defs.IN_FIRE
		return 0

	## On the floor towards `spot`; crawling (Down + the direction) where a perched Roc's body would touch a standing
	## hero (its feet 3 px under his head: his feet x in (rx - 53, rx + 15), the body test of Overlap).
	func _floor_walk(hero: PlayerBase, spot: int, roc: Roc) -> int:
		var move: int = go_to(hero, spot)
		if move < 0:
			return 0
		if roc != null and (roc.get_state() == Roc.State.REST or roc.get_state() == Roc.State.WINGS \
				or roc.get_state() == Roc.State.GUST):
			var rx: int = roc.sim_pos.x
			var x: int = hero.sim_pos.x
			var dir: int = 1 if spot > x else -1
			var ahead: int = x + dir * 8
			if (ahead > rx - 53 - 4 and ahead < rx + 15 + 4) or (x > rx - 53 - 4 and x < rx + 15 + 4):
				note = "crawl under the perch"
				return Defs.IN_DOWN | key_of(dir)
		return move

	# --- Phase 2 ------------------------------------------------------------------------------------------------------

	func _dodge(hero: PlayerBase, roc: Roc) -> int:
		if _dodge_dir == 0:
			_dodge_dir = signi(roc._aim.x - roc.sim_pos.x)
			if _dodge_dir == 0:
				_dodge_dir = 1 if hero.sim_pos.x < MID_X else -1
		note = "dodge %d" % _dodge_dir
		return key_of(_dodge_dir)

	func _buried(hero: PlayerBase, roc: Roc) -> int:
		var f: int = roc.facing
		var spot: int = roc.sim_pos.x + f * BURIED_DX
		note = "to the beak"
		if not hero.is_grounded():
			return 0
		if absi(hero.sim_pos.y - roc.sim_pos.y) > 4:
			return 0
		var move: int = go_to(hero, spot)
		if move >= 0:
			return move
		if hero.facing != -f:
			return key_of(-f)
		if hero.attack_gate:
			return 0
		if roc.hit_cooldown == 0 and roc.hp > roc.get_storm_hp() \
				and Overlap.rects(front_box(hero.sim_pos, -f), roc.get_head_rect()):
			note = "strike the beak"
			for i: int in STRIKE_TICKS - 2:
				plan.append(Defs.IN_FIRE)
			plan.append(0)
			return Defs.IN_FIRE
		return 0

	## To feet x `x` on the floor (walking off the nest's nearer end first when he stands on it).
	func _to_floor_spot(hero: PlayerBase, x: int, roc: Roc) -> int:
		if not hero.is_grounded():
			return 0
		if hero.sim_pos.y < FLOOR_Y:
			var off: int = NEST_X0 - 24 if absi(hero.sim_pos.x - NEST_X0) < absi(hero.sim_pos.x - NEST_X1) else NEST_X1 + 24
			if hero.sim_pos.y != NEST_TOP:
				off = x
			return key_of(1 if off > hero.sim_pos.x else -1)
		var move: int = _floor_walk(hero, x, roc)
		return move

	# --- Phase 3 ------------------------------------------------------------------------------------------------------

	func _storm(hero: PlayerBase, roc: Roc, level: LevelBase) -> int:
		var state: int = roc.get_state()
		if (hero.glide & 1) != 0:
			return _glide(hero, roc, level)
		_refill = false
		if not hero.is_grounded():
			note = "air"
			return 0
		if not hero.run.has_glider:
			_run = 0
			return _fetch_glider(hero, level)
		var half: int = roc._cruise_half
		if state == Roc.State.DESCEND or state == Roc.State.CRUISE or state == Roc.State.SWOOP_SCREECH:
			half = 1 if roc._cruise_x0 >= MID_X else 0
		var start: int = X_MAX if half == 1 else X_MIN
		var run_dir: int = -1 if half == 1 else 1
		if hero.sim_pos.y < FLOOR_Y:
			note = "off the nest"
			return _to_floor_spot(hero, bolt_safe(hero, level, start), null)
		if state == Roc.State.SWOOP:
			_run = 0
			note = "swoop dodge"
			var away: int = -1 if roc._aim.x >= roc.sim_pos.x else 1
			return key_of(-away)
		var cruising: bool = state == Roc.State.DESCEND or state == Roc.State.CRUISE
		if _run != 0 or (cruising and absi(hero.sim_pos.x - start) <= 4):
			_run = run_dir
			if (hero as Player).glider_runup >= Tuning.GLIDER_RUNUP_TICKS:
				note = "take off"
				_run = 0
				return Defs.IN_UP | key_of(run_dir)
			note = "run-up %d" % (hero as Player).glider_runup
			return key_of(run_dir)
		var safe: int = bolt_safe(hero, level, start)
		note = "wait at %d" % safe
		return maxi(go_to(hero, safe), 0)

	## The glider lies on the nest's middle: under it on the floor, then straight up onto the nest.
	func _fetch_glider(hero: PlayerBase, level: LevelBase) -> int:
		var glider_x: int = MID_X
		for entity: SimEntity in level.get_kind(Defs.Kind.COLLECTIBLE):
			var item: CollectibleBase = entity as CollectibleBase
			if item != null and item.item_id == &"items/glider" and not item.collected:
				glider_x = item.sim_pos.x
		var goal: int = bolt_safe(hero, level, glider_x)
		note = "fetch the glider at %d (goal %d)" % [glider_x, goal]
		if goal != glider_x:
			return maxi(go_to(hero, goal), 0)
		if hero.sim_pos.y >= FLOOR_Y:
			if absi(hero.sim_pos.x - glider_x) <= 3 and absi(hero.xvel) < 16:
				for i: int in JUMP_TICKS - 1:
					plan.append(Defs.IN_UP)
				return Defs.IN_UP
			return maxi(go_to(hero, glider_x), 0)
		return maxi(go_to(hero, glider_x), 0)

	## The feet x a hero heading for `goal` may go to: a marked or striking bolt column (the burning sticks, for a hero
	## on the nest) keeps him BOLT_CLEAR px away on his own side of it (the other side when a wall is too near); a hero
	## beneath the struck floor is sheltered.
	static func bolt_safe(hero: PlayerBase, level: LevelBase, goal: int) -> int:
		for entity: SimEntity in level.get_kind(Defs.Kind.ENEMY_PROJECTILE):
			var bolt: BossBolt = entity as BossBolt
			if bolt == null or bolt.spent:
				continue
			if bolt.is_burning() and hero.sim_pos.y != bolt.strike_y:
				continue
			if hero.sim_pos.y > bolt.strike_y:
				continue
			var bx: int = bolt.sim_pos.x
			var side: int = 1 if hero.sim_pos.x >= bx else -1
			if bx + side * BOLT_CLEAR > X_MAX or bx + side * BOLT_CLEAR < X_MIN:
				side = -side
			if absi(goal - bx) < BOLT_CLEAR or signi(goal - bx) != side:
				goal = bx + side * BOLT_CLEAR
		return clampi(goal, X_MIN, X_MAX)

	## Gliding: away from a marked bolt column within reach (the direction), else 0.
	static func bolt_steer(hero: PlayerBase, level: LevelBase) -> int:
		for entity: SimEntity in level.get_kind(Defs.Kind.ENEMY_PROJECTILE):
			var bolt: BossBolt = entity as BossBolt
			if bolt == null or bolt.spent or bolt.is_burning() or hero.sim_pos.y > bolt.strike_y:
				continue
			var dx: int = hero.sim_pos.x - bolt.sim_pos.x
			if absi(dx) < BOLT_CLEAR + 8:
				var away: int = 1 if dx >= 0 else -1
				if hero.sim_pos.x + away * BOLT_CLEAR > X_MAX or hero.sim_pos.x + away * BOLT_CLEAR < X_MIN:
					away = -away
				return away
		return 0

	## Gliding: climb out of the run-up, turn to the Roc, refill the lift with a dive at speed while too low, climb
	## again; above its back and where a dive meets it, dive.
	func _glide(hero: PlayerBase, roc: Roc, level: LevelBase) -> int:
		var lift: int = (hero as Player).glider_lift
		var state: int = roc.get_state()
		if state != Roc.State.DESCEND and state != Roc.State.CRUISE and state != Roc.State.SWOOP_SCREECH:
			# No dive to make now (it tumbles, climbs, storms or swoops): down to the floor fast, clear of the bolts.
			_refill = false
			var steer: int = bolt_steer(hero, level)
			note = "land"
			return Defs.IN_DOWN | (key_of(steer) if steer != 0 else 0)
		var cx: int = roc.sim_pos.x
		var top: int = roc._cruise_y - Roc.BOX.y
		if roc.get_state() == Roc.State.CRUISE or roc.get_state() == Roc.State.SWOOP_SCREECH:
			top = roc.get_box().position.y
		else:
			cx = (roc._cruise_x0 + roc._cruise_x1) >> 1
		var x: int = hero.sim_pos.x
		var y: int = hero.sim_pos.y
		# The contact range of a landing on its back (Overlap.body: his feet x in (cx - 53, cx + 15)).
		var lo: int = cx - 53 + 4
		var hi: int = cx + 15 - 4
		var goal: int = clampi((lo + hi) >> 1, X_MIN, X_MAX)
		var toward: int = 1 if goal > x else -1
		var target_ready: bool = roc.get_state() == Roc.State.CRUISE or roc.get_state() == Roc.State.SWOOP_SCREECH
		if y < top - 2:
			# Above its back: dive when the fall meets it, else glide on towards it.
			var t: int = 0
			var v: int = hero.yvel
			var yy: int = y
			while yy < top + 6 and t < 40:
				v = mini(v + Tuning.GRAVITY, Tuning.TERMINAL)
				yy += Tuning.floor16(v)
				t += 1
			var land_x: int = x + Tuning.floor16(hero.xvel) * t
			if target_ready and land_x > lo and land_x < hi:
				note = "dive onto the back (t %d at %d)" % [t, land_x]
				return Defs.IN_DOWN | (key_of(toward) if absi(goal - land_x) > 8 else 0)
			if lift > 0 and y > 24 and absi(goal - x) > 60:
				note = "climb over"
				return Defs.IN_UP | key_of(toward)
			note = "glide over"
			return key_of(toward)
		# Below its back's top: climb while lift lasts, else dive at speed to refill it.
		if _refill:
			if lift >= REFILL_LIFT or y > FLOOR_Y - 40:
				_refill = false
			else:
				note = "refill %d" % lift
				return Defs.IN_DOWN | key_of(signi(hero.xvel) if hero.xvel != 0 else toward)
		if lift > 0:
			note = "climb %d" % lift
			var dir: int = signi(hero.xvel) if absi(hero.xvel) >= 64 else toward
			# Climbing out of the run-up away from it: keep the direction until the lift is spent.
			return Defs.IN_UP | key_of(dir)
		if signi(hero.xvel) != toward or absi(hero.xvel) < 64:
			note = "turn"
			return key_of(toward)
		if y < FLOOR_Y - 70:
			_refill = true
			note = "refill start"
			return Defs.IN_DOWN | key_of(toward)
		note = "too low"
		return key_of(toward)

	# --- Helpers ------------------------------------------------------------------------------------------------------

	static func key_of(dir: int) -> int:
		return Defs.IN_RIGHT if dir > 0 else Defs.IN_LEFT

	## The flags that bring the hero to `spot` (braking in time), -1 when he stands there.
	func go_to(hero: PlayerBase, spot: int) -> int:
		var x: int = hero.sim_pos.x
		var dx: int = spot - x
		var v: int = hero.xvel
		if absi(dx) <= 2 and absi(v) < 16:
			_last_x = x
			_stuck = 0
			return -1
		var key: int = Defs.IN_RIGHT if dx > 0 else Defs.IN_LEFT
		var back: int = Defs.IN_LEFT if dx > 0 else Defs.IN_RIGHT
		var brake: int = v * v / 384 + absi(v) / 32
		if signi(v) == signi(dx) and absi(dx) <= brake + 1:
			return back if not hero.is_grounded() else 0
		if absi(dx) <= 2:
			return back if not hero.is_grounded() else 0
		return key

	## The high-front club box of a hero standing at `feet` facing `facing` (PHYSICS.md 8.2).
	static func high_box(feet: Vector2i, facing: int) -> Rect2i:
		var rect: Rect2i = Tuning.CLUB_BOX[Tuning.ClubFrame.HIGH_FRONT]
		var origin: Vector2i = Tuning.CLUB_ORIGIN[Tuning.ClubFrame.HIGH_FRONT]
		var xo: int = origin.x - rect.position.x
		var ox: int = feet.x + facing * origin.x
		return Rect2i(ox - xo, feet.y + rect.position.y, rect.size.x, rect.size.y)

	## The forward strike's front box (PHYSICS.md 8.2) of a hero at `feet` facing `facing`.
	static func front_box(feet: Vector2i, facing: int) -> Rect2i:
		var rect: Rect2i = Tuning.CLUB_BOX[Tuning.ClubFrame.FWD_FRONT]
		var origin: Vector2i = Tuning.CLUB_ORIGIN[Tuning.ClubFrame.FWD_FRONT]
		var xo: int = origin.x - rect.position.x
		var ox: int = feet.x + facing * origin.x
		return Rect2i(ox - xo, feet.y + rect.position.y, rect.size.x, rect.size.y)


# =================================================================================================================
# The nest and phase 1
# =================================================================================================================

func test_the_roc_finds_its_nest_and_perches_on_a_rim() -> void:
	var roc: Roc = _fight()
	assert_eq([roc.nest_x0, roc.nest_x1, roc.nest_top], [NEST_X0, NEST_X1, NEST_TOP], "the run of nest cells")
	assert_eq(roc.get_state(), Roc.State.REST)
	assert_eq(roc.sim_pos, Vector2i(NEST_X0 + 52 - 16, NEST_TOP), "on the left rim")
	assert_eq(roc.get_box(), Rect2i(roc.sim_pos.x - 52, NEST_TOP - 44, 104, 44), "104 x 44")
	assert_eq(roc.max_hp, 300, "phases 1-2 take 200; the last third falls to three dives")
	assert_eq(roc.get_storm_hp(), 100)
	assert_false(roc.is_coop_form())
	assert_eq(_level.get_kind(Defs.Kind.BOSS).size(), 1)


func test_wings_telegraph_then_a_gust_blows_away_from_it_with_feathers() -> void:
	var roc: Roc = _fight()
	_hero.teleport(Vector2i(200, NEST_TOP))
	Sim.step(Roc.REST_TICKS - 1)
	assert_eq(roc.get_state(), Roc.State.WINGS, "rests 44 ticks (the first was the fight's), then raises its wings")
	assert_eq(_level.wind, 0, "the wings come first: no wind yet")
	Sim.step(Roc.WINGS_TICKS - 1)
	assert_eq(_level.wind, 0, "14 ticks of warning")
	Sim.step(1)
	assert_eq(roc.get_state(), Roc.State.GUST)
	assert_eq(_level.wind, -Roc.GUST_WIND, "facing right: the gust blows to the right, away from it")
	Sim.step(Roc.FEATHER_PERIOD + 1)
	assert_true(_of_scene(Defs.Kind.ENEMY_PROJECTILE, &"projectiles/enemy_ember").size() >= 1, "feathers fall")
	for feather: SimEntity in _of_scene(Defs.Kind.ENEMY_PROJECTILE, &"projectiles/enemy_ember"):
		assert_eq((feather as EnemyEmber).skin, EnemyEmber.SKIN_FEATHER, "drawn as roc_parts feathers (enemies-A / C)")
	Sim.step(Roc.GUST_TICKS - Roc.FEATHER_PERIOD - 1)
	assert_eq(_level.wind, 0, "66 ticks of wind")
	assert_eq(roc.get_state(), Roc.State.REST, "then it rests again")
	roc._refresh_visual()
	assert_null(roc.get_gust_sprite(), "the swirl only while the gust blows")
	for gust: int in Roc.GUSTS - 1:
		Sim.step(Roc.REST_TICKS + Roc.WINGS_TICKS + Roc.GUST_TICKS)
		_hero.hit_timer = 0
		Game.hearts = Tuning.ENERGY_START
	assert_eq(roc.get_state(), Roc.State.TAKEOFF, "after 3 gusts it takes off")


## The gale's direction swirl (art-B's roc_parts `gust`, 3 frames): drawn while a gust blows, in front of the Roc on
## the downwind side and pointing downwind; mirrored when it blows the other way.
func test_a_gust_shows_the_swirl_pointing_downwind() -> void:
	var roc: Roc = _fight()
	if EnemySkin.find(Roc.PARTS_SKIN) == null:
		assert_true(true, "no roc_parts sheet: nothing to draw")
		return
	for rim: int in [0, 1]:
		# The hero across the nest: it faces him, the gust blows his way.
		_hero.teleport(Vector2i(290 if rim == 0 else 30, 160))
		roc._perch(rim)
		_step_until(func() -> bool: return roc.get_state() == Roc.State.GUST, 120)
		roc._refresh_visual()
		var swirl: Sprite2D = roc.get_gust_sprite()
		assert_not_null(swirl, "rim %d: the swirl shows during the gust" % rim)
		if swirl == null:
			continue
		var downwind: int = 1 if rim == 0 else -1
		assert_eq(roc.facing, downwind, "rim %d: it faces the hero across the nest" % rim)
		assert_eq(signi(_level.wind), -downwind, "rim %d: the wind blows away from it (wind > 0 blows left)" % rim)
		assert_true(swirl.frame >= 5 and swirl.frame <= 7, "a gust frame (%d)" % swirl.frame)
		assert_eq(swirl.flip_h, downwind < 0, "pointing downwind")
		assert_eq(signi(int(swirl.position.x)), downwind, "in front of it, downwind")
		Sim.step(3)
		roc._refresh_visual()
		assert_ne(swirl.frame, -1)


func test_the_perched_head_takes_a_high_strike_from_the_nest() -> void:
	var roc: Roc = _fight()
	var head: Rect2i = roc.get_head_rect()
	assert_eq(head, Rect2i(roc.sim_pos.x - 52, NEST_TOP - 44, 104, 20), "the top band of the body")
	var high: Rect2i = _high_box(Vector2i(roc.sim_pos.x + 62, NEST_TOP), -1)
	assert_true(Overlap.rects(high, head), "a high strike from the nest beside it reaches the head")
	assert_false(Overlap.body(_at(Vector2i(roc.sim_pos.x + 62, NEST_TOP)), roc, _hero), "without touching its body")
	_hero.club_box_active = true
	_hero.club_box = high
	_hero.club_power = 25
	Sim.step(1)
	_hero.club_box_active = false
	assert_eq(roc.hp, 275, "a club hit")
	assert_eq(roc.last_hitter, _hero)


func test_dive_screeches_14_ticks_and_a_miss_buries_the_beak() -> void:
	var roc: Roc = _fight()
	_hero.teleport(Vector2i(60, 160))
	roc._take_off()
	var circled: int = _step_until(func() -> bool: return roc.get_state() == Roc.State.SCREECH, 300)
	assert_true(circled > 0, "takes off, circles, then screeches")
	var aim: Vector2i = _hero.sim_pos
	Sim.step(Roc.SCREECH_TICKS - 1)
	assert_eq(roc.get_state(), Roc.State.SCREECH, "14 ticks of screech")
	Sim.step(1)
	assert_eq(roc.get_state(), Roc.State.DIVE, "then the dive")
	_hero.teleport(Vector2i(300, 160))
	var buried: int = _step_until(func() -> bool: return roc.get_state() == Roc.State.BURIED, 60)
	assert_true(buried > 0, "the hero stepped away: a miss")
	assert_eq(roc.sim_pos.y, 160, "the beak in the floor")
	assert_true(absi(roc.sim_pos.x - aim.x) <= Roc.DIVE_SPEED, "where he stood at the end of the screech")
	var head: Rect2i = roc.get_head_rect()
	assert_true(head.size.x > 0 and head.end.y > 160 - 16, "the head is low: open to a forward strike")
	_throw_at(head, 25)
	Sim.step(1)
	assert_eq(roc.hp, 275)
	Sim.step(Roc.BURY_TICKS)
	assert_eq(roc.get_state(), Roc.State.RISE, "44 ticks, then it rises")


func test_a_dive_that_meets_a_hero_hurts_and_pulls_up() -> void:
	var roc: Roc = _fight()
	_hero.teleport(Vector2i(60, 160))
	roc._take_off()
	_step_until(func() -> bool: return roc.get_state() == Roc.State.DIVE, 300)
	var hurt: int = _step_until(func() -> bool: return _hero.hit_timer > 0, 60)
	assert_true(hurt > 0, "the dive reaches the hero who stays")
	assert_eq(Game.bones, Tuning.BONES_PER_HEART - 1, "the boss body: a bone")
	assert_eq(roc.get_state(), Roc.State.RISE, "it pulls up")


func test_phases_one_and_two_stop_at_a_third_and_the_storm_follows() -> void:
	var roc: Roc = _fight()
	roc.hp = roc.get_storm_hp() + 10
	_hero.club_box_active = true
	_hero.club_box = roc.get_head_rect()
	_hero.club_power = 100
	Sim.step(1)
	_hero.club_box_active = false
	assert_eq(roc.hp, roc.get_storm_hp(), "weapons stop at the last third")
	Sim.step(Tuning.BOSS_HIT_COOLDOWN)
	_hero.club_box_active = true
	_hero.club_box = roc.get_head_rect()
	Sim.step(1)
	_hero.club_box_active = false
	assert_eq(roc.hp, roc.get_storm_hp(), "it glances now")
	_step_until(func() -> bool: return roc.is_storm_phase(), 400)
	assert_true(roc.is_storm_phase(), "the gust ends, then the storm")
	assert_eq(_gliders(), 1, "the hang-glider lies on the nest")
	var glider: SimEntity = _of_scene(Defs.Kind.COLLECTIBLE, &"items/glider")[0]
	assert_eq(glider.sim_pos.y, NEST_TOP)
	assert_true(glider.sim_pos.x >= NEST_X0 and glider.sim_pos.x < NEST_X1)
	_step_until(func() -> bool: return roc.get_state() == Roc.State.STORM, 200)
	assert_true(roc.sim_pos.y < 0, "it climbs above the view")


func test_lightning_is_marked_22_ticks_ahead_and_nest_sticks_burn() -> void:
	_room()
	var bolt: BossBolt = _spawn(&"projectiles/boss_bolt", Vector2i(120, 0), {
		"mark": 22, "bottom": 192, "nest_x0": NEST_X0, "nest_x1": NEST_X1, "nest_top": NEST_TOP}) as BossBolt
	_hero.teleport(Vector2i(122, NEST_TOP))
	assert_eq(bolt.strike_y, NEST_TOP, "it strikes the nest under the column")
	assert_true(bolt.burns)
	Sim.step(21)
	assert_true(bolt.is_marking())
	assert_eq(Game.hearts, Tuning.ENERGY_START, "the darkening cloud harms nobody")
	Sim.step(1)
	assert_true(bolt.is_striking(), "22 ticks after the mark")
	Sim.step(1)
	assert_eq(Game.hearts, Tuning.ENERGY_START - 1, "the bolt hurts as an enemy contact")
	_hero.hit_timer = 0
	Sim.step(BossBolt.BOLT_TICKS)
	assert_true(bolt.is_burning(), "the struck sticks burn")
	Sim.step(1)
	assert_eq(Game.hearts, Tuning.ENERGY_START - 2, "and burn whoever stands in them")
	Sim.step(BossBolt.BURN_TICKS)
	assert_true(bolt.spent, "for 66 ticks")
	var floor_bolt: BossBolt = _spawn(&"projectiles/boss_bolt", Vector2i(88, 0), {
		"bottom": 192, "nest_x0": NEST_X0, "nest_x1": NEST_X1, "nest_top": NEST_TOP}) as BossBolt
	assert_eq(floor_bolt.strike_y, 160, "beside the nest it strikes the floor")
	assert_false(floor_bolt.burns)
	Game.runs[0].has_glider = true
	_hero.hit_timer = 0
	_hero.teleport(Vector2i(88, 60))
	Sim.step(23)
	assert_false(Game.runs[0].has_glider, "a glider is lost instead of a heart")
	assert_eq(Game.hearts, Tuning.ENERGY_START - 2)


## The struck floor shelters whoever stands beneath it: a hero on the floor under the nest (his head 3 px into the
## one-way nest row) is neither struck nor burnt by a bolt on the nest over him; a hero on the nest there is.
func test_a_hero_under_the_nest_is_sheltered_from_a_nest_bolt() -> void:
	_room()
	var bolt: BossBolt = _spawn(&"projectiles/boss_bolt", Vector2i(152, 0), {
		"mark": 22, "bottom": 192, "nest_x0": NEST_X0, "nest_x1": NEST_X1, "nest_top": NEST_TOP}) as BossBolt
	assert_true(bolt.burns, "it strikes the nest")
	_hero.teleport(Vector2i(150, 160))
	assert_true(Overlap.rects(Rect2i(144, NEST_TOP - BossBolt.BURN_H, 16, BossBolt.BURN_H), _hero.get_box()),
			"his head reaches into the burning sticks' rectangle")
	Sim.step(22 + BossBolt.BOLT_TICKS + 10)
	assert_eq(Game.hearts, Tuning.ENERGY_START, "under the nest: neither struck nor burnt")
	_hero.teleport(Vector2i(150, NEST_TOP))
	Sim.step(1)
	assert_eq(Game.hearts, Tuning.ENERGY_START - 1, "on the burning sticks he is")


func test_three_glider_dives_bring_it_down() -> void:
	var roc: Roc = _fight()
	roc.hp = roc.get_storm_hp()
	roc._begin_storm()
	var score: int = Game.score
	for dive: int in 3:
		_step_until(func() -> bool: return roc.get_state() == Roc.State.CRUISE, 400)
		assert_eq(roc.get_state(), Roc.State.CRUISE, "dive %d: it cruises in view" % dive)
		_glide_onto(_hero, roc)
		Sim.step(1)
		if dive < 2:
			assert_eq(roc.get_state(), Roc.State.TUMBLE, "it tumbles low over the nest")
			assert_eq(_hero.yvel, Tuning.GLIDER_BUMP_YVEL, "the pilot is bumped up")
		_hero.glide = 0
		_hero.teleport(Vector2i(30, 160))
	assert_eq(Game.score - score, 1000 + 5000 + 10000, "the dive ladder")
	assert_eq(roc.get_state(), Roc.State.DYING, "the third dive brings it down")
	_step_until(func() -> bool: return roc.dead, 80)
	assert_true(roc.dead)
	assert_eq(_defeated, [roc] as Array[BossBase])
	if Spawner.exists(&"items/fire_starter"):
		var starters: Array[SimEntity] = _of_scene(Defs.Kind.COLLECTIBLE, &"items/fire_starter")
		assert_eq(starters.size(), 1, "the fire-starter")
		assert_true(absi(starters[0].sim_pos.x - (NEST_X0 + NEST_X1) / 2) <= 16, "over the nest")
	assert_eq(_level.wind, 0)


## Book II rule: the solo Roc falls. Bare heroes play it through: club hits on the head whenever it is open (phases 1-2),
## glider dives in the storm; it is defeated and never stun-locked (it keeps acting between the hits).
func test_the_solo_roc_can_be_beaten_through_all_phases() -> void:
	var roc: Roc = _fight()
	var states: Dictionary = {}
	for tick: int in 6000:
		var head: Rect2i = roc.get_head_rect()
		# Four hits while it perches, the rest on the buried beak: both phases get their turn.
		var perched_hits_done: bool = roc.hp <= roc.max_hp - 100
		var buried: bool = roc.get_state() == Roc.State.BURIED
		if head.size.x > 0 and roc.hit_cooldown == 0 and not roc.is_storm_phase() \
				and (buried or not perched_hits_done):
			_hero.club_box_active = true
			_hero.club_box = head
			_hero.club_power = 25
		if roc.get_state() == Roc.State.CRUISE:
			_glide_onto(_hero, roc)
		Sim.step(1)
		_hero.club_box_active = false
		_hero.glide = 0
		# Stand at the left end; once a dive is under way step to the right end: every dive misses.
		var diving: bool = roc.get_state() == Roc.State.DIVE or roc.get_state() == Roc.State.SWOOP
		_hero.teleport(Vector2i(290 if diving else 30, 160))
		_hero.hit_timer = 0
		Game.hearts = Tuning.ENERGY_START
		states[roc.get_state()] = true
		if roc.dead:
			break
	assert_true(roc.dead, "beaten (hp %d)" % roc.hp)
	for state: int in [Roc.State.GUST, Roc.State.DIVE, Roc.State.BURIED, Roc.State.STORM, Roc.State.CRUISE]:
		assert_true(states.has(state), "went through state %d" % state)


# =================================================================================================================
# The co-op form
# =================================================================================================================

func test_coop_the_wing_shield_faces_the_nearer_hero() -> void:
	var roc: Roc = _coop_fight(Vector2i(roc_right(), NEST_TOP), Vector2i(20, 160))
	assert_true(roc.is_coop_form())
	assert_eq(roc.max_hp, 375, "phases 1-2 take 250")
	assert_eq(roc.facing, 1, "it faces P1, the nearer")
	_hero.club_box_active = true
	_hero.club_box = roc.get_head_rect()
	_hero.club_power = 25
	Sim.step(1)
	_hero.club_box_active = false
	assert_eq(roc.hp, 375, "a hit from the shield's side glances")
	_p2.teleport(Vector2i(roc.sim_pos.x - 62, NEST_TOP))
	_hero.teleport(Vector2i(roc.sim_pos.x + 80, NEST_TOP))
	Sim.step(1)
	_p2.club_box_active = true
	_p2.club_box = roc.get_head_rect()
	_p2.club_power = 25
	Sim.step(1)
	_p2.club_box_active = false
	assert_eq(roc.facing, -1, "now P2 is nearer: the shield turns to him")
	assert_eq(roc.hp, 375, "and his hit glances")
	Sim.step(Tuning.BOSS_HIT_COOLDOWN)
	_hero.club_box_active = true
	_hero.club_box = roc.get_head_rect()
	Sim.step(1)
	_hero.club_box_active = false
	assert_eq(roc.hp, 350, "the far hero's hit counts: a pincer")
	Sim.step(Tuning.BOSS_HIT_COOLDOWN)
	var axe: ProjectileBase = _shot(Vector2i(roc.sim_pos.x, NEST_TOP - 30), 100, 0)
	Sim.step(1)
	assert_true(axe.spent)
	assert_eq(roc.hp, 350, "a throw flying in from the shield's side (P2's) glances, whoever threw it")


func test_coop_snatch_and_the_partners_rescue() -> void:
	Game.difficulty = Defs.Difficulty.EXPERT
	var roc: Roc = _coop_fight(Vector2i(60, 160), Vector2i(260, 160))
	roc._take_off()
	_step_until(func() -> bool: return roc.get_state() == Roc.State.SCREECH, 300)
	var target: PlayerBase = roc._target_hero()
	_step_until(func() -> bool: return roc.get_state() != Roc.State.SCREECH and roc.get_state() != Roc.State.DIVE, 80)
	assert_eq(roc.get_state(), Roc.State.SNATCH, "the dive grabs its target")
	assert_eq(roc.get_held(), target)
	assert_false(target.control_enabled, "he cannot move or strike")
	var y0: int = roc.sim_pos.y
	Sim.step(10)
	assert_eq(roc.sim_pos.y, maxi(y0 - 10 * Roc.SNATCH_RISE, roc.snatch_ceiling()),
			"it climbs at 2 px per tick (to its G35 ceiling at most)")
	assert_eq(target.sim_pos, roc.sim_pos + Vector2i(0, Roc.SNATCH_HANG_DY), "he hangs under it")
	var partner: PlayerBase = _p2 if target == _hero else _hero
	partner.club_box_active = true
	partner.club_box = roc.get_head_rect()
	partner.club_power = 25
	Sim.step(1)
	partner.club_box_active = false
	assert_null(roc.get_held(), "the partner's hit frees him")
	assert_true(target.control_enabled)
	assert_eq(target.shield, Roc.FREE_SHIELD_TICKS)
	assert_eq(roc.get_state(), Roc.State.STUNNED, "the rescue stuns it")
	assert_eq(roc.hp, 350, "the hit counts")
	assert_true(roc.get_head_rect().size.x > 0, "head open")
	Sim.step(Roc.STUN_TICKS)
	assert_eq(roc.get_state(), Roc.State.RISE, "66 ticks")


func test_coop_an_unrescued_hero_becomes_an_egg() -> void:
	Game.difficulty = Defs.Difficulty.EXPERT
	var roc: Roc = _coop_fight(Vector2i(60, 160), Vector2i(260, 160))
	roc._take_off()
	_step_until(func() -> bool: return roc.get_state() == Roc.State.SNATCH, 400)
	var target: PlayerBase = roc.get_held()
	assert_not_null(target)
	var downs: Array[PlayerBase] = []
	var on_down: Callable = func(hero: PlayerBase, _cause: StringName) -> void: downs.append(hero)
	Events.hero_down.connect(on_down)
	Sim.step(Roc.SNATCH_TICKS)
	Events.hero_down.disconnect(on_down)
	assert_true(target.is_down(), "73 ticks without a rescue: an egg")
	assert_eq(downs, [target] as Array[PlayerBase])
	assert_null(roc.get_held())


## Helper mode (PHYSICS.md C.12): the Snatch makes an egg outside hurt(), so a Helper-mode P2 is never snatched; the
## dive's touch spares him like every boss body.
func test_coop_a_helper_is_never_snatched() -> void:
	Game.difficulty = Defs.Difficulty.EXPERT
	var roc: Roc = _coop_fight(Vector2i(60, 160), Vector2i(260, 160))
	Game.helper_mode = true
	_hero.down = true
	assert_true(_p2.is_helper())
	roc._take_off()
	var dived: bool = false
	for tick: int in 500:
		Sim.step(1)
		_p2.hit_timer = 0
		dived = dived or roc.get_state() == Roc.State.DIVE
		assert_null(roc.get_held(), "never holds the helper")
	assert_true(dived, "it dived at him")
	assert_false(_p2.is_down(), "no egg")
	Game.helper_mode = false


## G33: the wing shield faces the nearer ACTIVE hero. P2 dozes right beside the perched Roc, P1 strikes from the other
## side: the shield stays on P1 (his hit glances); once P2 plays again the shield turns to him and P1's hit counts.
func test_coop_the_wing_shield_ignores_a_dozing_partner() -> void:
	var roc: Roc = _coop_fight(Vector2i(roc_right(), NEST_TOP), Vector2i(20, 160))
	_p2.teleport(Vector2i(roc.sim_pos.x - 62, NEST_TOP))
	_hero.teleport(Vector2i(roc.sim_pos.x + 80, NEST_TOP))
	_p2.idle = true
	Sim.step(1)
	assert_eq(roc.facing, 1, "P2 is nearer but dozes: the shield faces P1")
	_hero.club_box_active = true
	_hero.club_box = roc.get_head_rect()
	_hero.club_power = 25
	Sim.step(1)
	_hero.club_box_active = false
	assert_eq(roc.hp, roc.max_hp, "P1's hit glances off the shield")
	Sim.step(Tuning.BOSS_HIT_COOLDOWN)
	_p2.idle = false
	Sim.step(1)
	assert_eq(roc.facing, -1, "P2 plays again: the shield turns to him")
	_hero.club_box_active = true
	_hero.club_box = roc.get_head_rect()
	Sim.step(1)
	_hero.club_box_active = false
	assert_eq(roc.hp, roc.max_hp - 25, "the pincer: P1's hit counts")


## G33: a dozing target is never snatched (the Snatch and its rescue are co-op rules): the dive only knocks him, as
## solo, and pulls up.
func test_coop_a_dozing_target_is_not_snatched() -> void:
	Game.difficulty = Defs.Difficulty.EXPERT
	var roc: Roc = _coop_fight(Vector2i(60, 160), Vector2i(260, 160))
	_hero.down = true
	_p2.idle = true
	roc._take_off()
	var dived: bool = false
	var hurt: bool = false
	for tick: int in 500:
		Sim.step(1)
		dived = dived or roc.get_state() == Roc.State.DIVE
		hurt = hurt or _p2.hit_timer > 0
		assert_null(roc.get_held(), "never holds the dozing hero")
		_p2.run.hearts = Tuning.ENERGY_START
		_p2.hit_timer = mini(_p2.hit_timer, 1)
		if hurt:
			break
	assert_true(dived, "it dived at him")
	assert_true(hurt, "the dive's touch knocks him")
	assert_false(_p2.is_down(), "no egg")


## G35: a snatching Roc climbs at 2 px per tick, but its head band (the rescue's weak point) never comes closer than
## 72 px to the view's top (the boss bar's columns' bound, wherever it flies) - it hovers there until the rescue or the
## egg; ui's Hud.weak_point_problem agrees all the way.
func test_coop_the_snatch_climbs_no_higher_than_the_hud_allows() -> void:
	Game.difficulty = Defs.Difficulty.EXPERT
	var roc: Roc = _coop_fight(Vector2i(60, 160), Vector2i(260, 160))
	roc._take_off()
	_step_until(func() -> bool: return roc.get_state() == Roc.State.SNATCH, 400)
	assert_eq(roc.get_state(), Roc.State.SNATCH)
	var view: Rect2i = _level.get_view_rect()
	var highest: int = 1000
	for tick: int in Roc.SNATCH_TICKS - 1:
		Sim.step(1)
		if roc.get_state() != Roc.State.SNATCH:
			break
		var head: Rect2i = roc.get_head_rect()
		highest = mini(highest, head.position.y - view.position.y)
		assert_true(view.encloses(head), "the head band stays in the view")
		var art: Rect2 = Rect2(Vector2(head.position - view.position) * 2, Vector2(head.size) * 2)
		assert_eq(Hud.weak_point_problem(art, Vector2(view.size) * 2), "", "tick %d: the HUD rule" % tick)
	assert_eq(highest, Roc.HUD_CLEAR_PX, "it climbs to 72 px under the view top and no higher")


func test_coop_beginner_has_no_snatch() -> void:
	var roc: Roc = _coop_fight(Vector2i(60, 160), Vector2i(260, 160))
	roc._take_off()
	_step_until(func() -> bool: return roc.get_state() == Roc.State.DIVE, 300)
	_step_until(func() -> bool: return roc.get_state() != Roc.State.DIVE, 60)
	assert_ne(roc.get_state(), Roc.State.SNATCH, "boss grabs are off on Beginner (GAMEPLAY 13.9.10)")


func test_coop_pilot_and_spotter() -> void:
	var roc: Roc = _coop_fight(Vector2i(30, 160), Vector2i(150, NEST_TOP))
	roc.hp = roc.get_storm_hp()
	roc._begin_storm()
	Sim.step(1)
	assert_eq(_gliders() + int(_hero.run.has_glider) + int(_p2.run.has_glider), 2,
			"a glider per hero on the nest (P2 stands on one and takes it)")
	_step_until(func() -> bool: return roc.get_state() == Roc.State.CRUISE, 400)
	_glide_onto(_hero, roc)
	Sim.step(1)
	_hero.glide = 0
	assert_eq(roc.get_state(), Roc.State.TUMBLE)
	assert_eq(roc.hp, roc.get_storm_hp(), "the dive waits for the spotter")
	var tail: Rect2i = roc.get_head_rect()
	assert_true(tail.size.x > 0, "the tail feathers are open")
	assert_true(tail.end.y >= NEST_TOP - 15, "low enough for a strike from the nest")
	_hero.teleport(Vector2i(tail.get_center().x, NEST_TOP))
	_hero.club_box_active = true
	_hero.club_box = tail
	_hero.club_power = 25
	Sim.step(1)
	_hero.club_box_active = false
	assert_eq(roc.hp, roc.get_storm_hp(), "the pilot's own strike does not count")
	_p2.club_box_active = true
	_p2.club_box = tail
	_p2.club_power = 25
	Sim.step(1)
	_p2.club_box_active = false
	assert_true(roc.hp < roc.get_storm_hp(), "the spotter's strike makes the dive count")
	assert_eq(roc.dive_count, 1)
	_step_until(func() -> bool: return roc.get_state() == Roc.State.CRUISE, 600)
	_glide_onto(_hero, roc)
	Sim.step(Roc.TUMBLE_TICKS + 2)
	_hero.glide = 0
	assert_eq(roc.dive_count, 1, "a dive nobody spotted within 24 ticks is lost")


## V3.d: one hero cannot beat the co-op Roc. The real hero - his partner an egg, or hatched and IDLE anywhere he could
## be hatched (on the nest by either rim, on the floor on both sides; G33 / G34) - with every weapon from every spot of
## the nest and the floor plus seeded random inputs, never hurts the perched Roc (the wing shield always faces him);
## and in the storm his own dives never count without a spotter (Pilot and Spotter), the dozing partner on the nest.
func test_the_single_hero_search_cannot_beat_the_coop_roc() -> void:
	var roc: Roc = _coop_room()
	var hero: PlayerBase = _real_hero(Vector2i(200, NEST_TOP))
	_p2 = _add_hero2(Vector2i(30, 160))
	roc.start_fight()
	assert_true(roc.is_coop_form())
	var rng: SimRng = SimRng.new(77)
	var partners: Array[Vector2i] = [Vector2i(-1, -1), Vector2i(NEST_X0 + 8, NEST_TOP), Vector2i(NEST_X1 - 8, NEST_TOP),
			Vector2i(150, NEST_TOP), Vector2i(30, 160), Vector2i(290, 160)]
	for partner: Vector2i in partners:
		_p2_spot = partner if partner.x >= 0 else Vector2i(30, 160)
		_p2.respawn_at(_p2_spot)
		_p2.idle = true
		_p2.down = partner.x < 0
		var weapons: Array[int] = [Defs.Weapon.CLUB, Defs.Weapon.HAMMER, Defs.Weapon.AXE, Defs.Weapon.BOOMERANG,
				Defs.Weapon.SPEAR]
		if partner.x >= 0:
			weapons = [Defs.Weapon.CLUB, Defs.Weapon.AXE, Defs.Weapon.SPEAR]
		for weapon: int in weapons:
			for x: int in [100, 150, 170, 200, 215, 40, 280]:
				roc._perch(0 if x >= 150 else 1)
				var y: int = NEST_TOP if x >= NEST_X0 and x < NEST_X1 else 160
				_episode(hero, weapon, Vector2i(x, y), _random_flags(rng, 120))
				assert_eq(roc.hp, roc.max_hp, "partner %s, perched: weapon %d from x %d never counts" % [partner,
						weapon, x])
	_p2_spot = Vector2i(150, NEST_TOP)
	_p2.respawn_at(_p2_spot)
	_p2.idle = true
	roc.hp = roc.get_storm_hp()
	roc._begin_storm()
	hero.set_glider(true)
	for dive: int in 3:
		_step_until(func() -> bool: return roc.get_state() == Roc.State.CRUISE, 600)
		_glide_onto(hero, roc)
		var strikes: PackedInt32Array = _random_flags(rng, Roc.TUMBLE_TICKS + 4)
		strikes[1] = Defs.IN_FIRE
		_episode(hero, Defs.Weapon.CLUB, hero.sim_pos, strikes, false)
	assert_eq(roc.hp, roc.get_storm_hp(), "his own dives never count alone (the dozing partner on the nest)")
	assert_false(roc.dead)


# =================================================================================================================
# Helpers
# =================================================================================================================

func roc_right() -> int:
	return NEST_X0 + 52 - 16 + 62


## The room of the header (P1 at (30, 160)); returns nothing.
func _room() -> void:
	var rows: PackedStringArray = PackedStringArray()
	for row: int in 12:
		var line: String = "|" + ".".repeat(18) + "|"
		if row == 5:
			line = "|.---..........---.|"
		elif row == 8:
			line = "|.....--------.....|"
		elif row >= 10:
			line = "#".repeat(20)
		rows.append(line)
	_rows_level(rows)
	_hero.teleport(Vector2i(30, 160))
	_level.view = Rect2i(0, 0, Tuning.VIEW_W, Tuning.VIEW_H)


func _roc() -> Roc:
	_room()
	return _enemy(&"bosses/roc", Vector2i(9 * Tuning.TILE + 8, NEST_TOP)) as Roc


func _fight() -> Roc:
	var roc: Roc = _roc()
	roc.start_fight()
	Sim.step(1)
	return roc


func _coop_room() -> Roc:
	Game.start_run(Game.difficulty, Defs.GameMode.COOP, 2)
	Game.begin_level(&"test")
	Sim.rng.reseed(1)
	var roc: Roc = _roc()
	_level.meta["kind"] = "coop"
	return roc


func _coop_fight(p1: Vector2i, p2: Vector2i) -> Roc:
	var difficulty: int = Game.difficulty
	Game.start_run(difficulty, Defs.GameMode.COOP, 2)
	Game.begin_level(&"test")
	Sim.rng.reseed(1)
	var roc: Roc = _roc()
	_level.meta["kind"] = "coop"
	_hero.teleport(p1)
	_p2 = _add_hero2(p2)
	roc.start_fight()
	Sim.step(1)
	return roc


func _add_hero2(pos: Vector2i) -> PlayerBase:
	var p2: PlayerBase = PlayerBase.new()
	place(_level, p2, pos, {"slot": 1})
	p2.respawn_at(pos)
	return p2


func _real_hero(pos: Vector2i) -> PlayerBase:
	if _hero != null and is_instance_valid(_hero):
		_hero.free()
	var hero: PlayerBase = (load(PLAYER_SCENE) as PackedScene).instantiate() as PlayerBase
	place(_level, hero, pos, {"slot": 0})
	hero.respawn_at(pos)
	_hero = hero
	return hero


func _at(pos: Vector2i) -> PlayerBase:
	_hero.teleport(pos)
	_hero.yvel = 0
	return _hero


## The high-front club box of a hero standing at `feet` facing `facing` (PHYSICS.md 8.2).
func _high_box(feet: Vector2i, facing: int) -> Rect2i:
	var rect: Rect2i = Tuning.CLUB_BOX[Tuning.ClubFrame.HIGH_FRONT]
	var origin: Vector2i = Tuning.CLUB_ORIGIN[Tuning.ClubFrame.HIGH_FRONT]
	var xo: int = origin.x - rect.position.x
	var ox: int = feet.x + facing * origin.x
	return Rect2i(ox - xo, feet.y + rect.position.y, rect.size.x, rect.size.y)


## A gliding hero coming down onto the Roc's back (yvel 64: a dive).
func _glide_onto(hero: PlayerBase, roc: Roc) -> void:
	hero.teleport(Vector2i(roc.sim_pos.x, roc.sim_pos.y - 44 + 6))
	hero.glide = 1
	hero.yvel = 64
	hero.hit_timer = 0


func _gliders() -> int:
	var count: int = 0
	for item: SimEntity in _of_scene(Defs.Kind.COLLECTIBLE, &"items/glider"):
		if not (item as CollectibleBase).collected:
			count += 1
	return count


func _throw_at(target: Rect2i, power: int) -> void:
	var axe: ProjectileBase = ProjectileBase.new()
	place(_level, axe, Vector2i(target.get_center().x, target.end.y), {"from_hero": true, "power": power})


func _shot(pos: Vector2i, p_xvel: int, owner: int) -> ProjectileBase:
	var shot: ProjectileBase = ProjectileBase.new()
	place(_level, shot, pos, {"from_hero": true, "power": 25, "xvel": p_xvel, "owner": owner, "life": 1})
	return shot


func _step_until(done: Callable, max_ticks: int) -> int:
	for tick: int in max_ticks:
		Sim.step(1)
		for hero: PlayerBase in [_hero, _p2]:
			if hero != null and is_instance_valid(hero) and not hero.is_down():
				hero.run.hearts = Tuning.ENERGY_START
		if done.call():
			return tick + 1
	return -1


func _random_flags(rng: SimRng, ticks: int) -> PackedInt32Array:
	var flags: PackedInt32Array = PackedInt32Array()
	var keys: Array[int] = [0, Defs.IN_LEFT, Defs.IN_RIGHT, Defs.IN_UP, Defs.IN_FIRE, Defs.IN_UP | Defs.IN_FIRE,
			Defs.IN_FIRE | Defs.IN_LEFT, Defs.IN_FIRE | Defs.IN_RIGHT, Defs.IN_UP | Defs.IN_LEFT,
			Defs.IN_UP | Defs.IN_RIGHT, Defs.IN_DOWN | Defs.IN_FIRE]
	var held: int = 0
	var left: int = 0
	for tick: int in ticks:
		if left <= 0:
			held = keys[rng.next_int(keys.size())]
			left = rng.range_int(2, 12)
		left -= 1
		flags.append(held)
	return flags


## One episode of the single-hero search: the real hero (respawned at `pos` unless `respawn` is false) with `weapon`
## plays `flags`, kept alive; the Roc perched episodes hold it on the nest (its phase-1 clock reset).
func _episode(hero: PlayerBase, weapon: int, pos: Vector2i, flags: PackedInt32Array, respawn: bool = true) -> void:
	if respawn:
		hero.respawn_at(pos)
	hero.run.set_weapon(weapon)
	var first: int = Sim.tick + 1
	GameInput.set_scripted_slot(0, func(tick: int) -> int:
		var index: int = tick - first
		return flags[index] if index >= 0 and index < flags.size() else 0
	)
	for tick: int in flags.size():
		Sim.step(1)
		hero.run.hearts = Tuning.ENERGY_START
		hero.hit_timer = mini(hero.hit_timer, 1)
		if hero.dead or hero.is_down():
			hero.respawn_at(pos)
		if _p2 != null and is_instance_valid(_p2) and not _p2.is_down() and _p2_spot.x >= 0:
			# The search's idle partner stays where he was put, hatched and idle.
			_p2.run.hearts = Tuning.ENERGY_START
			_p2.hit_timer = mini(_p2.hit_timer, 1)
			if _p2.dead or _p2.sim_pos != _p2_spot:
				_p2.respawn_at(_p2_spot)
			_p2.idle = true
	GameInput.clear_scripted()


func _on_defeated(boss: BossBase) -> void:
	_defeated.append(boss)


## Recorded by test_the_club_pilot_still_wins_on_the_test_level with ROC_ROUTE=1 (Beginner, Expert).
const ROUTE_BEGINNER: String = (
	"8:R,39:RD,6:R,4:,1:R,2:,7:L,1:,8:U,16:,19:L,2:,1:L,2:,8:U,13:,4:L,5:,2:R,2:,1:L,8:UF,22:,8:UF,22:,8:UF,22:," +
	"8:UF,22:,8:UF,22:,8:UF,22:,8:UF,22:,8:UF,3:,5:L,1:,20:R,8:,8:R,2:,1:R,52:,5:L,17:,1:R,3:,5:R,2:,9:L,14:,1:R," +
	"2:,6:R,1:,11:L,11:,1:R,3:,8:R,2:,1:R,2:,31:L,25:LU,37:R,2:RD,1:R,3:RD,3:RU,4:R,5:L,1:LD,8:D,3:LD,2:L,4:R,2:RD," +
	"2:D,1:RD,3:D,1:RD,2:D,2:RU,5:L,4:LD,3:L,5:R,1:RD,14:D,1:RU,24:D,52:L,42:,5:R,5:,1:R,11:,1:L,23:,11:R,2:,4:R," +
	"2:,1:R,23:L,3:,3:L,3:,31:R,25:RU,47:L,3:LD,22:D,50:R,2:,1:R,43:,5:L,17:,1:R,3:,5:R,2:,9:L,14:,1:R,2:,6:R,1:," +
	"11:L,11:,1:R,3:,8:R,2:,1:R,2:,31:L,25:LU,37:R,2:RD,1:R,3:RD,3:RU,4:R,5:L,1:LD,8:D,3:LD,2:L,4:R,2:RD,2:D,1:RD," +
	"3:D,1:RD,2:D,2:RU,5:L,4:LD,3:L,5:R,1:RD,14:D,1:RU,48:"
)
const ROUTE_EXPERT: String = (
	"8:R,39:RD,6:R,4:,1:R,2:,7:L,1:,8:U,16:,19:L,2:,1:L,2:,8:U,13:,4:L,5:,2:R,2:,1:L,8:UF,22:,8:UF,22:,8:UF,22:," +
	"8:UF,22:,8:UF,22:,8:UF,22:,8:UF,22:,8:UF,3:,5:L,1:,20:R,8:,8:R,2:,1:R,52:,5:L,17:,1:R,3:,5:R,2:,9:L,14:,1:R," +
	"2:,6:R,1:,11:L,11:,1:R,3:,8:R,2:,1:R,2:,31:L,25:LU,37:R,2:RD,1:R,3:RD,3:RU,4:R,5:L,1:LD,8:D,3:LD,2:L,4:R,2:RD," +
	"2:D,1:RD,3:D,1:RD,2:D,2:RU,5:L,4:LD,3:L,5:R,1:RD,14:D,1:RU,24:D,52:L,42:,5:R,5:,1:R,11:,1:L,23:,11:R,2:,4:R," +
	"2:,1:R,23:L,3:,3:L,3:,31:R,25:RU,47:L,3:LD,22:D,50:R,2:,1:R,43:,5:L,17:,1:R,3:,5:R,2:,9:L,14:,1:R,2:,6:R,1:," +
	"11:L,11:,1:R,3:,8:R,2:,1:R,2:,31:L,25:LU,37:R,2:RD,1:R,3:RD,3:RU,4:R,5:L,1:LD,8:D,3:LD,2:L,4:R,2:RD,2:D,1:RD," +
	"3:D,1:RD,2:D,2:RU,5:L,4:LD,3:L,5:R,1:RD,14:D,1:RU,48:"
)
