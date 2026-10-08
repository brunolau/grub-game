extends "res://tests/test_enemies_case.gd"
## The Twin Idols (scripts/bosses/idols.gd; DESIGN.md B.4, GAMEPLAY.md 13.6; PLAN.md P2.3, owner enemies-C): the two
## idols in the walls, the shared brain (one awake idol spits, the asleep one drops masonry), 1 per hit of any weapon
## (the club works), the rage every 4th hit and the role swap, the telegraphs of B.0, defeat; the co-op Twin Hit (both
## awake, each only while a hero who counts - hatched, not idle - stands on its half, a crack only within the twin
## window and by the OTHER hero, the crossed targets after a rage), the single-hero search against it with the real hero
## (his partner an egg, or hatched and idle anywhere: G33 / G34), the weak points clear of the HUD (G35) and the
## recorded club routes on the test level.
##
## The court: 20 x 11 cells, walls in columns 0 and 19, floor at row 10 (feet y 160). The Sun Idol stands in the
## right wall (feet x 336), the Moon Idol in the left (feet x -16): bodies -16..88 and 232..336, the halves meet at 160.

const PLAYER_SCENE: String = "res://scenes/player/player.tscn"
const SUN_X: int = 336
const MOON_X: int = -16
const MID: int = 160
const FEET_Y: int = 160
## The developer level (DESIGN.md B.4's court: the 2-row altar at cols 8-11, a ledge in front of each idol's jaws),
## played in the real level scene by the Lab of tests/test_enemies_tusker.gd. Its floor is row 11 (feet y 176).
const LEVEL_PATH: String = "res://levels/test_enemies_idols.lvl"
const LEVEL_FLOOR_Y: int = 176
const Lab = preload("res://tests/test_enemies_tusker.gd").Lab

var _p2: PlayerBase = null
## Where the single-hero search keeps its idle partner.
var _p2_spot: Vector2i = Vector2i.ZERO
var _defeated: Array[BossBase] = []
var _lab: Lab = null
var _was_manual: bool = false


func before_each() -> void:
	super.before_each()
	_defeated.clear()
	_p2 = null
	_lab = null
	_was_manual = Sim.manual
	Events.boss_defeated.connect(_on_defeated)


func after_each() -> void:
	Events.boss_defeated.disconnect(_on_defeated)
	GameInput.clear_scripted()
	if _lab != null:
		Sim.stop()
		Sim.manual = _was_manual
		Audio.stop_music(0.0)
		Lab.cleanup_flow(get_tree())
		_lab = null
	Game.new_game(Defs.Difficulty.BEGINNER)
	Game.begin_level(&"")


# =================================================================================================================
# Placement and the solo form
# =================================================================================================================

func test_the_idols_sit_in_both_walls_mirrored() -> void:
	var idols: Idols = _court()
	Sim.step(1)
	assert_eq(idols.get_idol_pos(Idols.SUN), Vector2i(SUN_X, FEET_Y), "the Sun: 32 px inside the right wall")
	assert_eq(idols.get_idol_pos(Idols.MOON), Vector2i(MOON_X, FEET_Y), "the Moon: 32 px inside the left wall")
	assert_eq(idols.get_floor_y(), 160, "the floor's top")
	assert_eq(idols.get_body_rect(Idols.SUN), Rect2i(SUN_X - 104, FEET_Y - 95, 104, 95))
	assert_eq(idols.get_body_rect(Idols.MOON), Rect2i(MOON_X, FEET_Y - 95, 104, 95))
	assert_eq(idols.get_mid_x(), MID)
	var sun_head: Rect2i = idols.get_head_rect(Idols.SUN)
	var moon_head: Rect2i = idols.get_head_rect(Idols.MOON)
	assert_eq(sun_head, Rect2i(SUN_X - 106, FEET_Y - 70, 46, 31), "the Colossus idle head")
	assert_eq(moon_head.position.x - MOON_X, SUN_X - sun_head.end.x, "the Moon's head is the mirror image")
	assert_eq(moon_head.position.y, sun_head.position.y)
	assert_eq(idols.get_mouth(Idols.MOON).x - MOON_X, SUN_X - idols.get_mouth(Idols.SUN).x)
	assert_false(idols.is_coop_form())
	assert_true(idols.fighting, "a hero in the court wakes them (every spot is within the Colossus wake range)")
	assert_eq(_level.get_kind(Defs.Kind.BOSS).size(), 1, "one boss record, one shared brain")


func test_solo_one_idol_is_awake_and_only_its_jaws_count() -> void:
	var idols: Idols = _fight()
	assert_eq(idols.get_role(Idols.SUN), Idols.Role.AWAKE)
	assert_eq(idols.get_role(Idols.MOON), Idols.Role.ASLEEP)
	assert_eq(idols.max_hp, 14, "7 hits per idol")
	assert_eq(idols.get_max_pips(), 7)
	var stars: int = _count_fx(&"fx/hit_stars")
	_club(idols.get_head_rect(Idols.MOON), 25)
	Sim.step(1)
	_hero.club_box_active = false
	assert_eq(idols.hp, 14, "the asleep idol is armoured")
	assert_eq(_count_fx(&"fx/hit_stars"), stars + 1, "the club glances off with a spark")
	_club(idols.get_head_rect(Idols.SUN), 100)
	Sim.step(1)
	_hero.club_box_active = false
	assert_eq(idols.get_hits_left(Idols.SUN), 6, "the club works on the awake idol: 1 per hit, whatever the power")
	assert_eq(idols.hp, 13)
	assert_eq(idols.last_hitter, _hero)
	_club(idols.get_head_rect(Idols.SUN), 25)
	Sim.step(1)
	_hero.club_box_active = false
	assert_eq(idols.hp, 13, "one hit per hurt pose (the Colossus cooldown)")
	Sim.step(Idols.HURT_TICKS)
	_throw_at(idols.get_head_rect(Idols.SUN), 20)
	Sim.step(1)
	assert_eq(idols.get_hits_left(Idols.SUN), 5, "any thrown weapon counts 1")


func test_the_awake_idol_spits_and_the_asleep_one_drops_masonry_over_the_hero() -> void:
	var idols: Idols = _fight()
	_hero.teleport(Vector2i(130, 160))
	var opened: int = -1
	var rock: SimEntity = null
	for tick: int in 200:
		Sim.step(1)
		if opened < 0 and idols.get_head_rect(Idols.SUN) == _spit_head(idols, Idols.SUN):
			opened = tick
		var rocks: Array[SimEntity] = _of_scene(Defs.Kind.ENEMY_PROJECTILE, &"projectiles/boss_rock")
		if not rocks.is_empty():
			rock = rocks[0]
			assert_true(tick - opened >= 10, "the jaws open 10+ ticks before the rock leaves")
			break
	assert_not_null(rock, "a rock after the first idle loop")
	assert_eq(rock.sim_pos, idols.get_mouth(Idols.SUN), "from the Sun's jaws")
	assert_true(rock.xvel < 0, "toward the middle of the room")
	var block: BossStalactite = null
	for tick: int in 80:
		Sim.step(1)
		var drops: Array[SimEntity] = _of_scene(Defs.Kind.ENEMY_PROJECTILE, &"projectiles/boss_stalactite")
		if not drops.is_empty():
			block = drops[0] as BossStalactite
			break
	assert_not_null(block, "then the asleep idol slams: masonry")
	assert_eq(block.skin, "masonry")
	assert_eq(block.sim_pos.x, 130, "over the hero")
	assert_eq(block.sim_pos.y, 16 + EnemyTuning.STALACTITE_BOX.y, "under the ceiling")
	assert_true(block.is_warning(), "it rattles first")
	assert_eq(idols.get_role(Idols.MOON), Idols.Role.ASLEEP, "the slam was the asleep idol's")


func test_every_fourth_hit_both_rage_armoured_then_the_roles_swap() -> void:
	var idols: Idols = _fight()
	for hit: int in 3:
		_hit_open(idols, Idols.SUN)
		Sim.step(Idols.HURT_TICKS)
	assert_eq(idols.get_hits_left(Idols.SUN), 4)
	assert_ne(idols.get_state(), Idols.State.RAGE, "three hits: no rage")
	_hit_open(idols, Idols.SUN)
	var raged: bool = false
	for tick: int in 60:
		Sim.step(1)
		if idols.get_state() == Idols.State.RAGE:
			raged = true
			break
	assert_true(raged, "the 4th hit starts a rage (after the attack under way)")
	assert_false(idols.is_open(Idols.SUN), "raging idols are armoured")
	var hp: int = idols.hp
	_hero.teleport(Vector2i(MID, 160))
	_club(idols.get_head_rect(Idols.SUN), 25)
	Sim.step(1)
	_hero.club_box_active = false
	assert_eq(idols.hp, hp, "a hit glances during the rage")
	var rocks: int = _of_scene(Defs.Kind.ENEMY_PROJECTILE, &"projectiles/boss_rock").size()
	var blocks_before: int = _of_scene(Defs.Kind.ENEMY_PROJECTILE, &"projectiles/boss_stalactite").size()
	var spat: int = 0
	var dropped: int = 0
	for tick: int in EnemyTuning.COLOSSUS_RAGE_TICKS:
		Sim.step(1)
		spat = maxi(spat, _of_scene(Defs.Kind.ENEMY_PROJECTILE, &"projectiles/boss_rock").size() - rocks)
		dropped = maxi(dropped, _of_scene(Defs.Kind.ENEMY_PROJECTILE, &"projectiles/boss_stalactite").size()
				- blocks_before)
		if idols.get_state() != Idols.State.RAGE:
			break
	assert_true(spat >= 1 and dropped >= 2, "the Colossus rage: a rock and two blocks")
	assert_eq(idols.get_state(), Idols.State.IDLE)
	assert_eq(idols.get_role(Idols.MOON), Idols.Role.AWAKE, "the roles swap after the rage")
	assert_eq(idols.get_role(Idols.SUN), Idols.Role.ASLEEP)
	assert_true(idols.is_open(Idols.MOON))


func test_an_idol_breaks_and_the_survivor_does_everything_then_defeat() -> void:
	var idols: Idols = _fight()
	idols._hits_left[Idols.SUN] = 1
	idols.hp = 1 + idols.get_hits_left(Idols.MOON)
	_hit_open(idols, Idols.SUN)
	Sim.step(1)
	assert_eq(idols.get_role(Idols.SUN), Idols.Role.BROKEN, "its hits are used up")
	assert_eq(idols.get_role(Idols.MOON), Idols.Role.AWAKE, "the Moon wakes")
	assert_false(idols.dead)
	_hero.club_box_active = false
	Sim.step(Idols.HURT_TICKS)
	var hp: int = idols.hp
	_club(idols.get_head_rect(Idols.SUN), 25)
	Sim.step(1)
	_hero.club_box_active = false
	assert_eq(idols.hp, hp, "a broken idol takes nothing")
	idols._step = 1  # the next loop step is a slam
	idols._clock = 1000
	var dropped: bool = false
	for tick: int in 40:
		Sim.step(1)
		if not _of_scene(Defs.Kind.ENEMY_PROJECTILE, &"projectiles/boss_stalactite").is_empty():
			dropped = true
			break
	assert_true(dropped, "the survivor also takes the slam steps")
	idols._hits_left[Idols.MOON] = 1
	idols.hp = 1
	Sim.step(Idols.HURT_TICKS)
	_hit_open(idols, Idols.MOON)
	Sim.step(1)
	assert_true(idols.dead, "both broken: defeated")
	assert_eq(_defeated, [idols] as Array[BossBase])
	assert_eq(idols.get_role(Idols.MOON), Idols.Role.BROKEN)
	assert_true(idols.visible, "the broken idols stay in the walls")
	if Spawner.exists(&"items/fire_starter"):
		assert_eq(_of_scene(Defs.Kind.COLLECTIBLE, &"items/fire_starter").size(), 1, "the fire-starter")
	_level.reset_entities()
	assert_true(idols.dead, "a defeated boss stays defeated")


## The bodies hurt as the Colossus' does (the original's body test: within 64 px of the feet point, the hero lending
## half his width), the Moon as the mirror image of the Sun; the knock-back pushes away from each.
func test_bodies_cost_a_bone_and_push_away_mirrored() -> void:
	var idols: Idols = _fight()
	_hero.teleport(Vector2i(MOON_X + 52, 160))
	Sim.step(1)
	assert_eq(Game.bones, Tuning.BONES_PER_HEART - 1, "the Moon's body costs a bone")
	assert_eq(_hero.xvel, Tuning.BOSS_KNOCK_XVEL, "knocked away from the Moon (to the right)")
	_hero.hit_timer = 0
	_hero.teleport(Vector2i(SUN_X - 52, 160))
	Sim.step(1)
	assert_eq(_hero.xvel, -Tuning.BOSS_KNOCK_XVEL, "knocked away from the Sun (to the left)")
	var moon_reach: int = MOON_X
	var sun_reach: int = SUN_X
	for x: int in range(MOON_X, SUN_X):
		if idols._body_touches(Idols.MOON, _at(x)):
			moon_reach = x
		if idols._body_touches(Idols.SUN, _at(SUN_X + MOON_X - x)):
			sun_reach = SUN_X + MOON_X - x
	assert_true(absi((moon_reach - MOON_X) - (SUN_X - sun_reach)) <= 2,
			"the Moon reaches as far as the Sun, mirrored (%d / %d px; the hero's box is 15 + 17 px)"
			% [moon_reach - MOON_X, SUN_X - sun_reach])
	assert_eq(idols.hp, 14)


func test_the_fight_is_never_stun_locked() -> void:
	var idols: Idols = _fight()
	var longest: int = 0
	var quiet: int = 0
	var shots: int = 0
	for tick: int in 900:
		var awake: int = Idols.SUN if idols.get_role(Idols.SUN) == Idols.Role.AWAKE else Idols.MOON
		if idols.is_open(awake):
			_throw_at(idols.get_head_rect(awake), 20)
		var before: int = _level.get_kind(Defs.Kind.ENEMY_PROJECTILE).size()
		Sim.step(1)
		_hero.hit_timer = 0
		Game.hearts = Tuning.ENERGY_START
		if idols.dead:
			break
		if _level.get_kind(Defs.Kind.ENEMY_PROJECTILE).size() > before:
			shots += 1
			quiet = 0
		else:
			quiet += 1
			longest = maxi(longest, quiet)
	assert_true(idols.dead, "a perfect thrower wins")
	assert_true(shots >= 8, "it attacked all the way")
	assert_true(longest <= 140, "never pausing long: hits do not stun-lock it (longest %d)" % longest)


## Book II rule (DESIGN.md B.0): the solo Idols fall to the club. The real hero, club only, keeps to the awake idol's
## side and jump-strikes its head whenever it may count (kept alive: the fairness is pinned elsewhere).
func test_the_real_hero_beats_the_solo_idols_with_the_club() -> void:
	var idols: Idols = _court()
	var hero: PlayerBase = _real_hero(Vector2i(MID, 160), 0)
	var won: int = -1
	var plan: Array[int] = []
	for tick: int in 4000:
		var flags: int = _club_pilot(idols, hero, plan, tick)
		GameInput.set_scripted_slot(0, func(_t: int) -> int: return flags)
		Sim.step(1)
		hero.run.hearts = Tuning.ENERGY_START
		if hero.dead:
			break
		if idols.dead:
			won = tick
			break
	GameInput.clear_scripted()
	assert_true(won > 0, "the club alone beats the solo Idols (14 hits; hp left %d)" % idols.hp)


# =================================================================================================================
# The test level: the Moon's wall and the recorded club routes
# =================================================================================================================

## G2 verifier fix (wf8_g2_verify_to_enemies-C #1): on DESIGN.md B.4's court the 2-row altar block stands on the
## Sun's feet row in the middle of the room; the Moon's wall is the first column that is a wall on the feet row AND at
## head height, so the Moon sits in the left wall (feet x -16), not on the altar (it once stood at x 160, both idols
## overlapping in the middle). Pinned on the real level file, so the court of w8_l2b (D8) cannot regress.
func test_the_moon_sits_in_the_left_wall_of_the_test_court() -> void:
	var idols: Idols = _open_lab(Defs.Difficulty.EXPERT)
	_lab.step(PackedInt32Array([0]))
	var feet_y: int = LEVEL_FLOOR_Y
	assert_eq(idols.get_idol_pos(Idols.SUN), Vector2i(SUN_X, feet_y), "the Sun: 32 px inside the right wall")
	assert_eq(idols.get_idol_pos(Idols.MOON), Vector2i(MOON_X, feet_y), "the Moon: 32 px inside the LEFT wall")
	assert_eq(idols.get_body_rect(Idols.MOON), Rect2i(MOON_X, feet_y - 95, 104, 95), "body -16..88")
	assert_eq(idols.get_mid_x(), MID, "the halves meet over the altar")
	var altar: Rect2i = Rect2i(8 * Tuning.TILE, 9 * Tuning.TILE, 4 * Tuning.TILE, 2 * Tuning.TILE)
	assert_false(idols.get_body_rect(Idols.MOON).intersects(altar), "no idol on the altar")
	assert_false(idols.get_body_rect(Idols.MOON).intersects(idols.get_body_rect(Idols.SUN)), "the bodies apart")
	var moon_sprite: Node2D = idols.get_node_or_null("MoonSprite") as Node2D
	if moon_sprite != null:
		assert_eq(Vector2i(moon_sprite.position), (Vector2i(MOON_X, feet_y) - idols.sim_pos) * Tuning.ART_SCALE,
				"the Moon is drawn where it stands")


## The same rule on D8's real court (levels/w8_l2b.lvl, the arena zone `court`, its 2-row altar in the middle and a
## ledge in front of each idol's jaws): each idol stands in its own wall - the Moon's body reaches the court's left wall,
## the Sun's its right wall - on its own half, the bodies apart and neither on the altar, the halves meeting over the
## altar. Structural, so D8 may move things; skipped while the file does not exist.
func test_the_moon_sits_in_the_left_wall_of_the_real_court() -> void:
	var path: String = "res://levels/w8_l2b.lvl"
	if not FileAccess.file_exists(path):
		assert_true(true, "w8_l2b.lvl not built yet")
		return
	if _level != null and is_instance_valid(_level):
		_level.free()
	_level = null
	_hero = null
	_lab = Lab.new()
	assert_true(_lab.open(self, path, "bosses/idols", Defs.Difficulty.EXPERT), "the court came up")
	var idols: Idols = _lab.boss as Idols
	_lab.step(PackedInt32Array([0]))
	var zone: SimEntity = _lab.level.find_named(idols.arena)
	assert_not_null(zone, "the arena zone of the record")
	if zone == null:
		return
	var court: Rect2i = LevelText.to_rect_px(zone.spawn_params["rect"])
	var grid: TileGrid = _lab.level.grid
	var feet: Vector2i = idols.get_idol_pos(Idols.SUN)
	var row: int = Tuning.to_cell(feet.y - 1)
	# The court's inner walls on the idols' feet row (the first open cell from either side of the zone).
	var inner_left: int = court.position.x
	while inner_left < court.end.x and grid.side_at(Tuning.to_cell(inner_left), row) == TileGrid.SIDE_WALL:
		inner_left += Tuning.TILE
	var inner_right: int = court.end.x
	while inner_right > court.position.x and grid.side_at(Tuning.to_cell(inner_right - 1), row) == TileGrid.SIDE_WALL:
		inner_right -= Tuning.TILE
	var moon: Rect2i = idols.get_body_rect(Idols.MOON)
	var sun: Rect2i = idols.get_body_rect(Idols.SUN)
	assert_eq(idols.get_idol_pos(Idols.MOON).y, feet.y, "both on the same floor")
	assert_true(moon.position.x <= inner_left, "the Moon's body reaches into the left wall (%s, wall at %d)" % [moon,
			inner_left])
	assert_true(sun.end.x >= inner_right, "the Sun's body reaches into the right wall (%s, wall at %d)" % [sun, inner_right])
	assert_true(moon.end.x <= idols.get_mid_x() and sun.position.x >= idols.get_mid_x(), "each on its own half")
	assert_false(moon.intersects(sun), "the bodies apart")
	assert_true(absi(idols.get_mid_x() - ((inner_left + inner_right) >> 1)) <= Tuning.TILE, "the halves meet in the middle")
	_close_lab()


## G35 (lead designer, wf9 #2 as corrected): every pose in which a head can be struck lies wholly in the locked view of
## the test court, clear of the fight HUD (Hud.weak_point_problem: 24 px under the band - 55 px under the view's top,
## 72 px in the boss bar's columns), on the real level's view; and in a view whose last row is the court's floor (the
## framing D8 copies for w8_l2b).
func test_the_strikable_heads_stay_clear_of_the_hud() -> void:
	var idols: Idols = _open_lab(Defs.Difficulty.EXPERT)
	_lab.step(PackedInt32Array([0]))
	var views: Array[Rect2i] = [_lab.level.get_view_rect(),
			Rect2i(0, LEVEL_FLOOR_Y + Tuning.TILE - Tuning.VIEW_H, Tuning.VIEW_W, Tuning.VIEW_H)]
	for view: Rect2i in views:
		for idol: int in [Idols.MOON, Idols.SUN]:
			for pose: StringName in [&"idle", &"spit", &"slam", &"hurt", &"rage"]:
				idols._pose[idol] = pose
				var head: Rect2i = idols.get_head_rect(idol)
				assert_true(view.encloses(head), "view %s, idol %d %s: wholly in the view" % [view, idol, pose])
				var art: Rect2 = Rect2(Vector2(head.position - view.position) * 2, Vector2(head.size) * 2)
				assert_eq(Hud.weak_point_problem(art, Vector2(view.size) * 2), "", "view %s, idol %d %s: the HUD rule" % [
						view, idol, pose])
	idols._pose[0] = &"idle"
	idols._pose[1] = &"idle"


## G2 criterion (PLAN.md 5, enemies-C): the solo Idols fall to the club on their test level, played by the real hero
## from the level start with no refill - replayed tick for tick from the routes [IdolsClubPilot] recorded (run
## test_the_club_pilot_still_wins_on_the_test_court with IDOLS_ROUTE=1 to print fresh ones). The club stays in his
## hand all the way (no special lies in the court).
func test_the_club_routes_beat_the_solo_idols_on_the_test_court() -> void:
	for case: Array in [[Defs.Difficulty.BEGINNER, ROUTE_BEGINNER], [Defs.Difficulty.EXPERT, ROUTE_EXPERT]]:
		var idols: Idols = _open_lab(int(case[0]))
		var hero: PlayerBase = _lab.hero()
		var lives: int = Game.lives
		var route: PackedInt32Array = Lab.parse_route(str(case[1]))
		var specials: Array[int] = [0]
		var played: int = _lab.play([route] as Array[PackedInt32Array], func() -> bool:
			if hero.run.weapon != Defs.Weapon.CLUB:
				specials[0] += 1
			return idols.dead or hero.dead)
		print("    idols route difficulty %d: beaten on tick %d of %d, hearts %d bones %d" % [case[0], played,
				route.size(), hero.run.hearts, hero.run.bones])
		assert_true(idols.dead, "difficulty %d: the club route beats the Twin Idols (hp left %d)" % [case[0], idols.hp])
		assert_false(hero.dead, "difficulty %d: without a death" % case[0])
		assert_eq(Game.lives, lives, "no life lost")
		assert_eq(specials[0], 0, "the club in his hand all the way")
		assert_false(idols.is_coop_form(), "the solo form")
		_close_lab()


## The pilot that recorded those routes still wins from the level start (a guard against tuning drift). With
## IDOLS_ROUTE=1 it prints the fresh routes; IDOLS_DEBUG=<tick> traces 600 ticks from there (every IDOLS_EVERY-th, 6)
## and every hurt with its source.
func test_the_club_pilot_still_wins_on_the_test_court() -> void:
	var trace_from: int = OS.get_environment("IDOLS_DEBUG").to_int() if OS.has_environment("IDOLS_DEBUG") else -1
	var every: int = maxi(OS.get_environment("IDOLS_EVERY").to_int(), 1) if OS.has_environment("IDOLS_EVERY") else 6
	for difficulty: int in [Defs.Difficulty.BEGINNER, Defs.Difficulty.EXPERT]:
		var idols: Idols = _open_lab(difficulty)
		var hero: PlayerBase = _lab.hero()
		var pilot: IdolsClubPilot = IdolsClubPilot.new()
		var on_hurt: Callable = func(_h: PlayerBase, kind: int, source: SimEntity) -> void:
			if trace_from >= 0:
				print("  hurt kind %d by %s at %s (hero %s), idols state %d" % [kind,
						source.scene_file_path.get_file() if source != null else "-",
						source.sim_pos if source != null else Vector2i.ZERO, _h.sim_pos, idols.get_state()])
		Events.hero_hurt.connect(on_hurt)
		for tick: int in 6000:
			var f: int = pilot.flags(hero, idols, _lab.level)
			if trace_from >= 0 and tick >= trace_from and tick < trace_from + 600 and tick % every == 0:
				_trace_pilot(tick, hero, idols, f)
			_lab.step(PackedInt32Array([f]))
			if idols.dead or hero.dead:
				break
		Events.hero_hurt.disconnect(on_hurt)
		if OS.get_environment("IDOLS_ROUTE") != "":
			print("ROUTE %d %s" % [difficulty, Lab.route_text(_lab.streams[0])])
		print("    idols pilot difficulty %d: dead %s after %d ticks, hp %d, hearts %d bones %d, hero dead %s" % [
				difficulty, idols.dead, _lab.ticks(), idols.hp, hero.run.hearts, hero.run.bones, hero.dead])
		assert_true(idols.dead, "difficulty %d: the club pilot beats the Twin Idols (hp left %d)" % [difficulty, idols.hp])
		assert_false(hero.dead)
		_close_lab()


# =================================================================================================================
# The co-op form: Twin Hit
# =================================================================================================================

func test_coop_both_wake_and_each_jaw_opens_only_for_a_hero_on_its_half() -> void:
	var idols: Idols = _coop_fight(Vector2i(100, 160), Vector2i(220, 160))
	assert_true(idols.is_coop_form())
	assert_eq(idols.max_hp, 16, "8 hits per idol")
	assert_eq(idols.get_role(Idols.MOON), Idols.Role.AWAKE, "both wake together")
	assert_eq(idols.get_role(Idols.SUN), Idols.Role.AWAKE)
	assert_true(idols.is_open(Idols.MOON) and idols.is_open(Idols.SUN))
	_p2.teleport(Vector2i(140, 160))
	Sim.step(1)
	assert_true(idols.is_open(Idols.MOON))
	assert_false(idols.is_open(Idols.SUN), "nobody on the Sun's half: it sleeps, armoured")
	_p2.down = true
	_p2.teleport(Vector2i(220, 160))
	Sim.step(1)
	assert_false(idols.is_open(Idols.SUN), "an egg on its half does not wake it")


func test_coop_a_twin_hit_within_the_window_cracks_both() -> void:
	var idols: Idols = _coop_fight(Vector2i(100, 160), Vector2i(220, 160))
	var window: int = PartyTuning.window_ticks(Game.difficulty)
	assert_eq(window, 24, "Beginner")
	_club_by(_hero, idols.get_head_rect(Idols.MOON))
	Sim.step(1)
	_hero.club_box_active = false
	assert_eq(idols.hp, 16, "a lone hit waits for its twin")
	Sim.step(window - 2)
	_club_by(_p2, idols.get_head_rect(Idols.SUN))
	Sim.step(1)
	_p2.club_box_active = false
	assert_eq(idols.get_hits_left(Idols.MOON), 7, "both crack together")
	assert_eq(idols.get_hits_left(Idols.SUN), 7)
	assert_eq(idols.hp, 14)
	Sim.step(Idols.HURT_TICKS)
	_club_by(_hero, idols.get_head_rect(Idols.MOON))
	Sim.step(1)
	_hero.club_box_active = false
	Sim.step(window)
	_club_by(_p2, idols.get_head_rect(Idols.SUN))
	Sim.step(1)
	_p2.club_box_active = false
	assert_eq(idols.hp, 14, "too late: the first hit faded, the second waits alone")
	Sim.step(window + 2)
	assert_eq(idols.hp, 14, "and fades too")


func test_coop_a_rage_crosses_the_targets() -> void:
	var idols: Idols = _coop_fight(Vector2i(100, 160), Vector2i(220, 160))
	for crack: int in Idols.COOP_RAGE_EVERY:
		_until_jaws_open(idols, Vector2i(100, 160), Vector2i(220, 160))
		_club_by(_hero, idols.get_head_rect(Idols.MOON))
		_club_by(_p2, idols.get_head_rect(Idols.SUN))
		Sim.step(1)
		_hero.club_box_active = false
		_p2.club_box_active = false
		Sim.step(Idols.HURT_TICKS)
	assert_eq(idols.hp, 16 - 2 * Idols.COOP_RAGE_EVERY)
	var raged: bool = idols.get_state() == Idols.State.RAGE
	var rage_ticks: int = 0
	for tick: int in 400:
		if raged and idols.get_state() != Idols.State.RAGE:
			break
		Sim.step(1)
		_hold_heroes(Vector2i(100, 160), Vector2i(220, 160))
		raged = raged or idols.get_state() == Idols.State.RAGE
		if idols.get_state() == Idols.State.RAGE:
			rage_ticks += 1
	assert_true(raged, "every 2nd twin crack (wf10): both rage")
	assert_true(rage_ticks >= Idols.COOP_RAGE_TICKS - 2, "for %d ticks" % rage_ticks)
	assert_true(idols.is_crossed(), "then each idol aims at the far half")
	assert_eq(idols._target_of(Idols.MOON), _p2, "the Moon now aims at the Sun's hero")
	assert_eq(idols._target_of(Idols.SUN), _hero)


## wf10 boss balance (co-op Idols harder): a twin crack SHUTS both jaws - a twin on them glances - until the idols have
## spat again (the end of the next spit step); then the next twin cracks them. Solo: no shut jaws.
func test_coop_a_twin_crack_shuts_the_jaws_until_they_have_spat() -> void:
	var idols: Idols = _coop_fight(Vector2i(100, 160), Vector2i(220, 160))
	_until_jaws_open(idols, Vector2i(100, 160), Vector2i(220, 160))
	_club_by(_hero, idols.get_head_rect(Idols.MOON))
	_club_by(_p2, idols.get_head_rect(Idols.SUN))
	Sim.step(1)
	_hero.club_box_active = false
	_p2.club_box_active = false
	assert_eq(idols.hp, 14, "a twin crack")
	assert_false(idols.jaws_open(Idols.MOON) or idols.jaws_open(Idols.SUN), "both jaws shut")
	assert_true(idols.is_open(Idols.MOON) and idols.is_open(Idols.SUN), "though both are awake")
	Sim.step(Idols.HURT_TICKS)
	_hold_heroes(Vector2i(100, 160), Vector2i(220, 160))
	if not idols.jaws_open(Idols.MOON):
		_club_by(_hero, idols.get_head_rect(Idols.MOON))
		_club_by(_p2, idols.get_head_rect(Idols.SUN))
		Sim.step(1)
		_hero.club_box_active = false
		_p2.club_box_active = false
		assert_eq(idols.hp, 14, "a twin on shut jaws glances")
	var spat: bool = false
	var opened: bool = false
	for tick: int in 400:
		Sim.step(1)
		_hold_heroes(Vector2i(100, 160), Vector2i(220, 160))
		spat = spat or idols.get_state() == Idols.State.SPIT
		if idols.jaws_open(Idols.MOON):
			opened = true
			assert_true(spat, "they open only after a spit")
			assert_ne(idols.get_state(), Idols.State.SPIT, "at the end of the spit step")
			break
	assert_true(opened, "open again")
	_club_by(_hero, idols.get_head_rect(Idols.MOON))
	_club_by(_p2, idols.get_head_rect(Idols.SUN))
	Sim.step(1)
	assert_eq(idols.hp, 12, "the next twin cracks them")


## Step until both co-op jaws are open (the heroes held at their spots, unhurt).
func _until_jaws_open(idols: Idols, p1: Vector2i, p2: Vector2i) -> void:
	for tick: int in 600:
		if idols.jaws_open(Idols.MOON) and idols.jaws_open(Idols.SUN) and idols._cooldown[Idols.MOON] == 0 				and idols._cooldown[Idols.SUN] == 0:
			return
		Sim.step(1)
		_hold_heroes(p1, p2)
	assert_true(false, "the jaws never opened")


func _hold_heroes(p1: Vector2i, p2: Vector2i) -> void:
	for pair: Array in [[_hero, p1], [_p2, p2]]:
		var hero: PlayerBase = pair[0]
		hero.run.hearts = Tuning.ENERGY_START
		hero.hit_timer = 0
		if hero.sim_pos != pair[1]:
			hero.teleport(pair[1])


func test_coop_rocks_are_aimed_at_the_hero_on_each_side() -> void:
	var idols: Idols = _coop_fight(Vector2i(100, 160), Vector2i(200, 160))
	var rocks: Array[SimEntity] = []
	for tick: int in 140:
		Sim.step(1)
		_hero.hit_timer = 0
		_p2.hit_timer = 0
		rocks = _of_scene(Defs.Kind.ENEMY_PROJECTILE, &"projectiles/boss_rock")
		if rocks.size() >= 2:
			break
	assert_eq(rocks.size(), 2, "both spit")
	for rock: SimEntity in rocks:
		var from_moon: bool = rock.xvel > 0
		var dx: int = (100 - idols.get_mouth(Idols.MOON).x) if from_moon else (idols.get_mouth(Idols.SUN).x - 200)
		assert_eq(absi(rock.xvel), Idols._aimed_speed(dx), "aimed at its own hero")


## G33: only a hero who COUNTS (hatched, not idle) on a half wakes its idol: a dozing partner on the Sun's half leaves
## it asleep and armoured (and its target is nobody), an egg too; once he presses something again it wakes.
func test_coop_an_idle_partner_on_a_half_wakes_nothing() -> void:
	var idols: Idols = _coop_fight(Vector2i(100, 160), Vector2i(220, 160))
	assert_true(idols.is_open(Idols.SUN), "an active P2 on the Sun's half: open")
	_p2.idle = true
	Sim.step(1)
	assert_true(idols.is_open(Idols.MOON), "P1 plays on the Moon's half")
	assert_false(idols.is_open(Idols.SUN), "P2 dozes on the Sun's half: asleep, armoured")
	assert_null(idols._target_of(Idols.SUN), "and it aims at nobody")
	assert_false(idols._takes_step(Idols.SUN, true), "nor spits")
	_club_by(_p2, idols.get_head_rect(Idols.SUN))
	Sim.step(1)
	_p2.club_box_active = false
	assert_eq(idols._pending[Idols.SUN], -1, "a hit on its closed jaws glances")
	_p2.idle = false
	Sim.step(1)
	assert_true(idols.is_open(Idols.SUN), "awake again once he plays")


## G34: the twin must be struck by the OTHER hero. P1's strike on the Moon and his own hit on the Sun (both jaws open:
## an active P2 stands on the Sun's half) within the window crack nothing; P2's strike on the Sun does.
func test_coop_the_twin_must_come_from_the_other_hero() -> void:
	var idols: Idols = _coop_fight(Vector2i(100, 160), Vector2i(220, 160))
	_club_by(_hero, idols.get_head_rect(Idols.MOON))
	Sim.step(1)
	_hero.club_box_active = false
	Sim.step(4)
	_club_by(_hero, idols.get_head_rect(Idols.SUN))
	Sim.step(1)
	_hero.club_box_active = false
	assert_eq(idols.hp, idols.max_hp, "one hero's two hits never twin")
	assert_eq(idols._pending_slot[Idols.SUN], 0, "his Sun hit only waits for a twin of P2's")
	Sim.step(Idols.PENDING_RENEW_TICKS)
	_club_by(_p2, idols.get_head_rect(Idols.MOON))
	Sim.step(1)
	_p2.club_box_active = false
	assert_eq(idols.hp, idols.max_hp - 2, "P2's hit on the Moon twins P1's waiting Sun hit")
	assert_eq(idols.get_hits_left(Idols.MOON), idols.get_hits_left(Idols.SUN))


## V3.d: one hero cannot beat the Twin Hit. The real hero (club, then the axe, the swirling axe and the spear), with
## his partner an egg, or hatched and IDLE anywhere in the court (G33 / G34: on either half, by either idol, never
## moving), from many places throws at the far idol and strikes the near one on every timing offset within the window,
## and plays seeded random inputs: no idol ever cracks.
func test_the_single_hero_search_cannot_crack_the_twin_idols() -> void:
	var idols: Idols = _coop_court()
	var hero: PlayerBase = _real_hero(Vector2i(MID, 160), 0)
	_p2 = _add_hero2(Vector2i(MID + 40, 160))
	idols.start_fight()
	assert_true(idols.is_coop_form(), "two heroes in a co-op file: the Twin Hit")
	var rng: SimRng = SimRng.new(4242)
	var episodes: int = 0
	# The partner: an egg, then hatched and idle at spots over the whole court (both halves, under each idol's jaws).
	var partners: Array[int] = [-1, 40, 150, 175, 280]
	for partner_x: int in partners:
		_p2_spot = Vector2i(partner_x if partner_x >= 0 else 200, 160)
		_p2.respawn_at(_p2_spot)
		_p2.idle = true
		_p2.down = partner_x < 0
		var offsets: Array[int] = [0, 7]
		var starts: Array[int] = [96, 225]
		var weapons: Array[int] = [Defs.Weapon.CLUB, Defs.Weapon.AXE]
		if partner_x < 0:
			offsets = [0, 4, 8, 12]
			starts = [96, 120, 150, 175, 200, 225]
			weapons = [Defs.Weapon.CLUB, Defs.Weapon.AXE, Defs.Weapon.BOOMERANG, Defs.Weapon.SPEAR]
		for weapon: int in weapons:
			for start_x: int in starts:
				for offset: int in offsets:
					_episode(hero, weapon, Vector2i(start_x, 160), _throw_then_strike(start_x, offset))
					episodes += 1
					assert_eq(idols.hp, idols.max_hp, "partner %d, weapon %d from x %d, offset %d: no crack" % [
							partner_x, weapon, start_x, offset])
			for run: int in (3 if partner_x < 0 else 1):
				_episode(hero, weapon, Vector2i(rng.range_int(96, 225), 160), _random_flags(rng, 240))
				episodes += 1
		assert_eq(idols.hp, idols.max_hp, "partner at %d: no crack" % partner_x)
	assert_eq(idols.hp, idols.max_hp, "%d single-hero episodes, no crack" % episodes)
	assert_false(idols.dead)


# =================================================================================================================
# Helpers
# =================================================================================================================

## The court of the header with the idols (solo form unless the game and the level say co-op).
func _court() -> Idols:
	var rows: PackedStringArray = PackedStringArray()
	rows.append("#".repeat(20))
	for row: int in range(1, 10):
		rows.append("#" + ".".repeat(18) + "#")
	rows.append("#".repeat(20))
	rows.append("#".repeat(20))
	_rows_level(rows)
	_hero.teleport(Vector2i(MID, 160))
	_level.view = Rect2i(0, 0, Tuning.VIEW_W, Tuning.VIEW_H)
	return _enemy(&"bosses/idols", Vector2i(18 * Tuning.TILE + 8, 160)) as Idols


## The court with the fight on (one tick stepped).
func _fight() -> Idols:
	var idols: Idols = _court()
	idols.start_fight()
	Sim.step(1)
	return idols


## A co-op game in a co-op file: the court with P1 and P2 (bare heroes) and the fight on.
func _coop_fight(p1: Vector2i, p2: Vector2i) -> Idols:
	var idols: Idols = _coop_court()
	_hero.teleport(p1)
	_p2 = _add_hero2(p2)
	idols.start_fight()
	Sim.step(1)
	return idols


func _coop_court() -> Idols:
	Game.start_run(Defs.Difficulty.BEGINNER, Defs.GameMode.COOP, 2)
	Game.begin_level(&"test")
	Sim.rng.reseed(1)
	var idols: Idols = _court()
	_level.meta["kind"] = "coop"
	return idols


func _add_hero2(pos: Vector2i) -> PlayerBase:
	var p2: PlayerBase = PlayerBase.new()
	place(_level, p2, pos, {"slot": 1})
	p2.respawn_at(pos)
	return p2


## The real hero (scenes/player/player.tscn) of `slot` at `pos`, replacing the bare P1 of the fixture for slot 0.
func _real_hero(pos: Vector2i, slot: int) -> PlayerBase:
	if slot == 0 and _hero != null and is_instance_valid(_hero):
		_hero.free()
	var hero: PlayerBase = (load(PLAYER_SCENE) as PackedScene).instantiate() as PlayerBase
	place(_level, hero, pos, {"slot": slot})
	hero.respawn_at(pos)
	if slot == 0:
		_hero = hero
	return hero


## The open jaws' head rectangle of the spit pose (to see the jaws open).
func _spit_head(idols: Idols, idol: int) -> Rect2i:
	var keep: StringName = idols._pose[idol]
	idols._pose[idol] = &"spit"
	var head: Rect2i = idols.get_head_rect(idol)
	idols._pose[idol] = keep
	return head


## A club box of the bare P1 on an idol's head while it is open (one tick).
func _hit_open(idols: Idols, idol: int) -> void:
	for tick: int in 120:
		if idols.is_open(idol) and idols._cooldown[idol] == 0:
			break
		Sim.step(1)
		_hero.hit_timer = 0
	_hero.teleport(Vector2i(MID, 160))
	_club(idols.get_head_rect(idol), 25)
	Sim.step(1)
	_hero.club_box_active = false


## The bare P1 moved to (x, 160), standing (for the body tests).
func _at(x: int) -> PlayerBase:
	_hero.teleport(Vector2i(x, 160))
	_hero.yvel = 0
	return _hero


func _club(box: Rect2i, power: int) -> void:
	_hero.club_box_active = true
	_hero.club_box = box
	_hero.club_power = power


func _club_by(hero: PlayerBase, box: Rect2i) -> void:
	hero.club_box_active = true
	hero.club_box = box
	hero.club_power = 25


func _throw_at(target: Rect2i, power: int) -> void:
	var axe: ProjectileBase = ProjectileBase.new()
	place(_level, axe, Vector2i(target.get_center().x, target.end.y), {"from_hero": true, "power": power})


func _count_fx(id: StringName) -> int:
	var count: int = 0
	for entity: SimEntity in _level.get_kind(Defs.Kind.FX):
		if entity.scene_file_path.get_file().get_basename() == String(id).get_file():
			count += 1
	return count


## One tick of the club pilot: stand in front of the awake idol, face it and jump-strike its head when it may count.
## `plan` holds the flags still to press of a started jump strike.
func _club_pilot(idols: Idols, hero: PlayerBase, plan: Array[int], _tick: int) -> int:
	if not plan.is_empty():
		return plan.pop_front()
	var idol: int = Idols.SUN if idols.get_role(Idols.SUN) == Idols.Role.AWAKE else Idols.MOON
	var head: Rect2i = idols.get_head_rect(idol)
	var spot: int = head.position.x - 20 if idol == Idols.SUN else head.end.x + 20
	var dir: int = 1 if idol == Idols.SUN else -1
	var toward: int = Defs.IN_RIGHT if dir > 0 else Defs.IN_LEFT
	var away: int = Defs.IN_LEFT if dir > 0 else Defs.IN_RIGHT
	var dx: int = spot - hero.sim_pos.x
	if absi(dx) > 6:
		return Defs.IN_RIGHT if dx > 0 else Defs.IN_LEFT
	if not hero.is_grounded():
		return 0
	if hero.facing != dir:
		return toward
	if idols.is_open(idol) and idols._cooldown[idol] == 0:
		# Jump (UP held) and strike forward near the apex, then step back.
		for i: int in 8:
			plan.append(Defs.IN_UP)
		plan.append(Defs.IN_FIRE | toward)
		for i: int in 8:
			plan.append(0)
		plan.append(away)
		return Defs.IN_UP
	return 0


## Throw toward the far idol from `start_x` (facing it), wait `offset` ticks, then turn and strike the near idol with
## a jump strike (flags per tick).
func _throw_then_strike(start_x: int, offset: int) -> PackedInt32Array:
	var flags: PackedInt32Array = PackedInt32Array()
	var far_dir: int = Defs.IN_RIGHT if start_x < MID else Defs.IN_LEFT
	var near_dir: int = Defs.IN_LEFT if start_x < MID else Defs.IN_RIGHT
	flags.append(far_dir)
	for i: int in 2:
		flags.append(Defs.IN_FIRE | Defs.IN_UP)
	for i: int in 8:
		flags.append(0)
	for i: int in offset:
		flags.append(0)
	flags.append(near_dir)
	for i: int in 7:
		flags.append(Defs.IN_UP)
	flags.append(Defs.IN_FIRE | near_dir)
	for i: int in 20:
		flags.append(0)
	return flags


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
			left = rng.range_int(2, 14)
		left -= 1
		flags.append(held)
	return flags


## One episode of the single-hero search: the hero respawned at `pos` with `weapon` plays `flags` (kept alive).
func _episode(hero: PlayerBase, weapon: int, pos: Vector2i, flags: PackedInt32Array) -> void:
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
		if _p2 != null and is_instance_valid(_p2) and not _p2.is_down():
			# The idle partner stays where he was put, hatched and idle (a hurt would knock him about).
			_p2.run.hearts = Tuning.ENERGY_START
			if _p2.dead or _p2.sim_pos != _p2_spot:
				_p2.respawn_at(_p2_spot)
			_p2.idle = true
	GameInput.clear_scripted()


func _on_defeated(boss: BossBase) -> void:
	_defeated.append(boss)


## The test level in the real level scene (the fixture's own room freed first), one real hero, club in hand.
func _open_lab(difficulty: int, party: int = 1) -> Idols:
	if _level != null and is_instance_valid(_level):
		_level.free()
	_level = null
	_hero = null
	_lab = Lab.new()
	assert_true(_lab.open(self, LEVEL_PATH, "bosses/idols", difficulty, party), "the court came up")
	return _lab.boss as Idols


func _close_lab() -> void:
	if _lab != null and _lab.level != null and is_instance_valid(_lab.level):
		_lab.level.free()
	GameInput.clear_scripted()
	_lab = null


## One trace line of the pilot (IDOLS_DEBUG): the hero, the shared brain, the live projectiles and the keys.
func _trace_pilot(tick: int, hero: PlayerBase, idols: Idols, keys: int) -> void:
	var live: Array[String] = []
	for entity: SimEntity in _lab.level.get_kind(Defs.Kind.ENEMY_PROJECTILE):
		if not (entity as ProjectileBase).spent:
			live.append("%s%s" % [entity.scene_file_path.get_file().get_basename(), entity.sim_pos])
	print("t%d hero %s xvel %d grounded %s | state %d roles %d/%d hp %d next rock in %d | keys %s | %s" % [tick,
			hero.sim_pos, hero.xvel, hero.is_grounded(), idols.get_state(), idols.get_role(Idols.MOON),
			idols.get_role(Idols.SUN), idols.hp, IdolsClubPilot.release_in(idols), Lab.keys(keys), ", ".join(live)])


## The club pilot of the solo Idols on the test court (it recorded ROUTE_BEGINNER / ROUTE_EXPERT). Its strike spot is
## under the awake idol's jaws, SPOT_DX px from its feet point - outside the body test (the coarse reject of 64 px),
## where a spat rock leaves over his head and the masonry (clamped COLOSSUS_DROP_MARGIN px off the bodies) cannot
## reach - and from there it high-strikes the head whenever it may count. Its home is the altar's top on that idol's
## side: a rock (a heart a touch) never climbs the 2-row altar, so it waits there while a rock rolls about the court,
## while the next spit is due within SPIT_MARGIN ticks (the shared loop's clock) and through a rage; it crosses the
## court on the altar. A masonry block rattling over him sends him aside first (toward the altar's middle up there).
class IdolsClubPilot:
	extends RefCounted

	const SPOT_DX: int = 74
	const HOME_DX: int = 16          ## home: this far from the altar's middle (cols 8-11), away from the spitting idol
	const ALTAR_MID: int = 160
	const ALTAR_HALF: int = 26       ## the hero's feet stay this close to the altar's middle (its top: 128..192)
	const DODGE_PX: int = 24         ## aside from a falling block (his box -15..+17 clears its 10 px)
	const FLOOR_Y: int = 176
	const SPIT_MARGIN: int = 34
	const HIGH_TICKS: int = 9
	const JUMP_TICKS: int = 8

	var plan: Array[int] = []
	var _last_x: int = -100000
	var _stuck: int = 0

	func flags(hero: PlayerBase, idols: Idols, level: LevelBase) -> int:
		if not plan.is_empty() and not (block_over(hero, level) and not hero.attack_gate):
			return plan.pop_front()
		plan.clear()
		var idol: int = target(idols)
		var dir: int = 1 if idol == Idols.SUN else -1
		var toward: int = Defs.IN_RIGHT if dir > 0 else Defs.IN_LEFT
		var x: int = hero.sim_pos.x
		var jump: int = rock_jump(hero, level)
		if jump >= 0:
			return jump
		for entity: SimEntity in level.get_kind(Defs.Kind.ENEMY_PROJECTILE):
			# (A spent projectile stays listed until the frame ends - the Lab steps without frames.)
			var block: BossStalactite = entity as BossStalactite
			if block != null and not block.spent and absi(block.sim_pos.x - x) < DODGE_PX - 2 \
					and block.sim_pos.y < hero.sim_pos.y:
				# Aside by DODGE_PX (clear of its box), away from it - on the altar never off it (rocks roll below).
				var away: int = -1 if block.sim_pos.x >= x else 1
				var dest: int = block.sim_pos.x + away * DODGE_PX
				if hero.sim_pos.y < FLOOR_Y and absi(dest - ALTAR_MID) > ALTAR_HALF:
					dest = block.sim_pos.x - away * DODGE_PX
				var dodge: int = go_to(hero, dest)
				return dodge if dodge >= 0 else 0
		var spot: int = idols.get_idol_pos(idol).x - dir * SPOT_DX
		var at_spot: bool = absi(x - spot) <= 12 and hero.sim_pos.y >= FLOOR_Y
		# At the spot he stays (a spat rock leaves over his head; one that comes back is jumped); the way out from the
		# altar is taken only with no rock about and no spit due before he gets there; a rage sends him home.
		var travel: int = absi(x - spot) / 4 + SPIT_MARGIN / 2
		var danger: bool = idols._rage_due or idols.get_state() == Idols.State.RAGE \
				or (not at_spot and (rock_alive(level) or release_in(idols) <= travel))
		var goal: int = ALTAR_MID - dir * HOME_DX if danger else spot
		var move: int = go_to(hero, goal)
		if move >= 0:
			return move
		if danger or not hero.is_grounded() or hero.attack_gate:
			return 0
		if hero.facing != dir:
			return toward
		if idols.is_open(idol) and idols._cooldown[idol] == 0 \
				and Overlap.rects(high_box(hero.sim_pos, dir), idols.get_head_rect(idol)):
			for i: int in HIGH_TICKS - 1:
				plan.append(Defs.IN_UP | Defs.IN_FIRE)
			plan.append(0)
			return Defs.IN_UP | Defs.IN_FIRE
		return 0

	## True while a masonry block hangs or falls within reach over him.
	static func block_over(hero: PlayerBase, level: LevelBase) -> bool:
		for entity: SimEntity in level.get_kind(Defs.Kind.ENEMY_PROJECTILE):
			var block: BossStalactite = entity as BossStalactite
			if block != null and not block.spent and absi(block.sim_pos.x - hero.sim_pos.x) < DODGE_PX - 2 \
					and block.sim_pos.y < hero.sim_pos.y:
				return true
		return false

	## True while a spat rock is still about (flying, hopping or rolling out).
	static func rock_alive(level: LevelBase) -> bool:
		for entity: SimEntity in level.get_kind(Defs.Kind.ENEMY_PROJECTILE):
			var rock: BossRock = entity as BossRock
			if rock != null and not rock.spent:
				return true
		return false

	## Ticks until the next rock leaves the jaws (the shared loop of idols.gd: idle pauses, then LOOP's steps).
	static func release_in(idols: Idols) -> int:
		var step: int = idols._step
		var t: int = 0
		match idols.get_state():
			Idols.State.SPIT:
				if idols._timer < EnemyTuning.COLOSSUS_SPIT_RELEASE_TICK:
					return EnemyTuning.COLOSSUS_SPIT_RELEASE_TICK - idols._timer
				t = EnemyTuning.COLOSSUS_SPIT_TICKS - idols._timer
				step = (step + 1) % Idols.LOOP.size()
			Idols.State.SLAM:
				t = EnemyTuning.COLOSSUS_SLAM_TICKS - idols._timer
				step = (step + 1) % Idols.LOOP.size()
			Idols.State.IDLE:
				t = idols._idle_length() - idols._clock
				if Idols.LOOP[step] == Idols.Attack.SPIT:
					return t + EnemyTuning.COLOSSUS_SPIT_RELEASE_TICK
				t += EnemyTuning.COLOSSUS_SLAM_TICKS
				step = (step + 1) % Idols.LOOP.size()
			_:
				return 0
		for i: int in Idols.LOOP.size():
			t += EnemyTuning.COLOSSUS_IDLE_TICKS[step] * 50 / 100
			if Idols.LOOP[step] == Idols.Attack.SPIT:
				return t + EnemyTuning.COLOSSUS_SPIT_RELEASE_TICK
			t += EnemyTuning.COLOSSUS_SLAM_TICKS
			step = (step + 1) % Idols.LOOP.size()
		return t

	## A rock rolling or hopping at him low (one that came back off the altar's face, or a fresh one across the court):
	## jump it in time (JUMP_TICKS of Up with his current direction); -1 when none is coming.
	func rock_jump(hero: PlayerBase, level: LevelBase) -> int:
		if not hero.is_grounded() or hero.attack_gate:
			return -1
		var x: int = hero.sim_pos.x
		for entity: SimEntity in level.get_kind(Defs.Kind.ENEMY_PROJECTILE):
			var rock: BossRock = entity as BossRock
			if rock == null or rock.spent or rock.sim_pos.y < hero.sim_pos.y - 30 or rock.sim_pos.y > hero.sim_pos.y + 4:
				continue
			if hero.sim_pos.y < FLOOR_Y and absi(rock.sim_pos.x - ALTAR_MID) > 37:
				continue  # on the altar: a rock beside it never reaches him
			var gap: int = rock.sim_pos.x - x
			var closing: int = -signi(gap) * (rock.xvel - hero.xvel)
			if closing <= 0 or absi(gap) > 28 + closing * 6 / 16 or absi(gap) < 4:
				continue
			var key: int = hero.input_flags & (Defs.IN_LEFT | Defs.IN_RIGHT)
			for i: int in JUMP_TICKS - 1:
				plan.append(Defs.IN_UP | key)
			return Defs.IN_UP | key
		return -1

	## The flags that bring the hero to `spot` (braking in time: no friction in the air, so he steers back there), -1
	## when he stands there. A wall face in the way (the altar) is jumped: JUMP_TICKS of Up with the direction.
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
		if hero.is_grounded() and x == _last_x:
			_stuck += 1
		else:
			_stuck = 0
		_last_x = x
		if _stuck >= 2:
			_stuck = 0
			for i: int in JUMP_TICKS - 1:
				plan.append(Defs.IN_UP | key)
			return Defs.IN_UP | key
		return key

	## The idol to strike: the awake one (solo), the survivor when one broke.
	static func target(idols: Idols) -> int:
		if idols.get_role(Idols.SUN) == Idols.Role.BROKEN:
			return Idols.MOON
		if idols.get_role(Idols.MOON) == Idols.Role.BROKEN:
			return Idols.SUN
		return Idols.SUN if idols.get_role(Idols.SUN) == Idols.Role.AWAKE else Idols.MOON

	## The high-front club box of a hero standing at `feet` facing `facing` (PHYSICS.md 8.2).
	static func high_box(feet: Vector2i, facing: int) -> Rect2i:
		var rect: Rect2i = Tuning.CLUB_BOX[Tuning.ClubFrame.HIGH_FRONT]
		var origin: Vector2i = Tuning.CLUB_ORIGIN[Tuning.ClubFrame.HIGH_FRONT]
		var xo: int = origin.x - rect.position.x
		var ox: int = feet.x + facing * origin.x
		return Rect2i(ox - xo, feet.y + rect.position.y, rect.size.x, rect.size.y)


## Recorded by test_the_club_pilot_still_wins_on_the_test_court with IDOLS_ROUTE=1 (Beginner, Expert).
const ROUTE_BEGINNER: String = (
	"1:L,22:R,4:,1:R,3:,9:UF,25:,9:UF,30:,9:UF,25:,9:UF,1:,2:L,8:LU,10:L,1:R,2:L,1:R,1:L,1:R,12:L,4:,4:R,6:L," +
	"6:R,1:L,2:R,2:,1:R,52:,5:L,2:,8:R,7:L,1:,13:L,2:R,1:L,1:,2:L,1:,1:L,3:,5:R,3:,1:L,9:UF,25:,9:UF,32:,9:UF," +
	"25:,9:UF,1:,20:R,8:RU,4:R,1:L,1:R,2:L,1:R,1:L,2:R,1:L,8:LU,3:L,1:R,13:L,1:LU,2:L,1:,3:L,1:,6:R,1:,1:R,1:," +
	"4:L,4:R,2:L,2:,5:R,2:,1:L,16:R,3:,1:R,4:,9:UF,25:,9:UF,30:,9:UF,1:,11:L,19:R,1:RU,3:R,17:L,8:LU,1:L,5:R," +
	"6:L,1:R,3:,4:R,4:L,4:R,4:L,4:R,7:L,2:,14:L,6:,9:UF,1:,18:R,8:RU,4:R,1:L,1:R,2:L,1:R,1:L,2:R,8:L,3:,4:R," +
	"1:,6:L,3:,6:R,6:L,6:R,2:L,3:R,9:,5:L,2:,8:R,7:L,1:,4:R,2:L,4:R,28:,5:L,2:,8:R,7:L,1:,4:R,2:L,4:R,4:,2:L," +
	"2:R,2:L,2:R,55:,8:U,11:,3:L,1:R,1:L,2:,6:R,6:L,6:R,4:L,5:R,27:,5:L,2:,8:R,7:L,1:,4:R,2:L,4:R,4:,2:L,2:R," +
	"2:L,2:R,74:,5:L,2:,8:R,7:L,1:,4:R,2:L,4:R,4:,1:R,23:,5:L,2:,8:R,7:L,1:,4:R,2:L,4:R,4:,2:L,2:R,2:L,2:R," +
	"74:,5:L,2:,8:R,7:L,1:,4:R,2:L,4:R,28:,5:L,2:,8:R,7:L,1:,4:R,2:L,4:R,4:,2:L,2:R,2:L,3:R,73:,5:L,2:,8:R," +
	"7:L,1:,4:R,2:L,4:R,28:,5:L,2:,8:R,7:L,1:,4:R,2:L,4:R,4:,2:L,2:R,2:L,2:R,74:,5:L,2:,8:R,7:L,1:,4:R,2:L," +
	"4:R,4:,1:R,23:,5:L,2:,8:R,7:L,1:,4:R,2:L,4:R,4:,2:L,2:R,2:L,2:R,74:,5:L,2:,8:R,7:L,1:,4:R,2:L,4:R,28:," +
	"5:L,2:,8:R,7:L,1:,4:R,2:L,4:R,4:,2:L,2:R,2:L,3:R,73:,5:L,2:,8:R,7:L,1:,4:R,2:L,4:R,28:,5:L,2:,8:R,7:L,1:," +
	"4:R,2:L,4:R,4:,2:L,2:R,2:L,2:R,74:,5:L,2:,8:R,7:L,1:,4:R,2:L,4:R,4:,1:R,23:,5:L,2:,8:R,7:L,1:,4:R,2:L," +
	"4:R,4:,2:L,2:R,2:L,2:R,74:,5:L,2:,8:R,7:L,1:,4:R,2:L,4:R,28:,5:L,2:,8:R,7:L,1:,4:R,2:L,4:R,4:,2:L,2:R," +
	"2:L,3:R,73:,5:L,2:,8:R,7:L,1:,4:R,2:L,4:R,28:,5:L,2:,8:R,7:L,1:,4:R,2:L,4:R,4:,2:L,2:R,2:L,2:R,74:,5:L," +
	"2:,8:R,7:L,1:,4:R,2:L,4:R,4:,1:R,23:,5:L,2:,8:R,7:L,1:,4:R,2:L,4:R,4:,2:L,2:R,2:L,2:R,74:,5:L,2:,8:R,7:L," +
	"1:,4:R,2:L,4:R,14:,8:U,6:,3:L,1:R,1:L,2:R,16:L,15:,9:UF,25:,8:UF"
)
const ROUTE_EXPERT: String = (
	"1:L,22:R,4:,1:R,3:,9:UF,25:,9:UF,30:,9:UF,25:,9:UF,1:,2:L,8:LU,10:L,1:R,2:L,1:R,1:L,1:R,12:L,4:,4:R,6:L," +
	"6:R,1:L,2:R,2:,1:R,52:,5:L,2:,8:R,7:L,1:,13:L,2:R,1:L,1:,2:L,1:,1:L,3:,5:R,3:,1:L,9:UF,25:,9:UF,32:,9:UF," +
	"25:,9:UF,1:,20:R,8:RU,4:R,1:L,1:R,2:L,1:R,1:L,2:R,1:L,8:LU,3:L,1:R,13:L,1:LU,2:L,1:,3:L,1:,6:R,1:,1:R,1:," +
	"4:L,4:R,2:L,2:,5:R,2:,1:L,16:R,3:,1:R,4:,9:UF,25:,9:UF,30:,9:UF,1:,11:L,19:R,1:RU,3:R,17:L,8:LU,1:L,5:R," +
	"6:L,1:R,3:,4:R,4:L,4:R,4:L,4:R,7:L,2:,14:L,6:,9:UF,1:,18:R,8:RU,4:R,1:L,1:R,2:L,1:R,1:L,2:R,8:L,3:,4:R," +
	"1:,6:L,3:,6:R,6:L,6:R,2:L,3:R,9:,5:L,2:,8:R,7:L,1:,4:R,2:L,4:R,28:,5:L,2:,8:R,7:L,1:,4:R,2:L,4:R,4:,2:L," +
	"2:R,2:L,2:R,55:,8:U,11:,3:L,1:R,1:L,2:,6:R,6:L,6:R,4:L,5:R,27:,5:L,2:,8:R,7:L,1:,4:R,2:L,4:R,4:,2:L,2:R," +
	"2:L,2:R,74:,5:L,2:,8:R,7:L,1:,4:R,2:L,4:R,4:,1:R,23:,5:L,2:,8:R,7:L,1:,4:R,2:L,4:R,4:,2:L,2:R,2:L,2:R," +
	"74:,5:L,2:,8:R,7:L,1:,4:R,2:L,4:R,28:,5:L,2:,8:R,7:L,1:,4:R,2:L,4:R,4:,2:L,2:R,2:L,3:R,73:,5:L,2:,8:R," +
	"7:L,1:,4:R,2:L,4:R,28:,5:L,2:,8:R,7:L,1:,4:R,2:L,4:R,4:,2:L,2:R,2:L,2:R,74:,5:L,2:,8:R,7:L,1:,4:R,2:L," +
	"4:R,4:,1:R,23:,5:L,2:,8:R,7:L,1:,4:R,2:L,4:R,4:,2:L,2:R,2:L,2:R,74:,5:L,2:,8:R,7:L,1:,4:R,2:L,4:R,28:," +
	"5:L,2:,8:R,7:L,1:,4:R,2:L,4:R,4:,2:L,2:R,2:L,3:R,73:,5:L,2:,8:R,7:L,1:,4:R,2:L,4:R,28:,5:L,2:,8:R,7:L,1:," +
	"4:R,2:L,4:R,4:,2:L,2:R,2:L,2:R,74:,5:L,2:,8:R,7:L,1:,4:R,2:L,4:R,4:,1:R,23:,5:L,2:,8:R,7:L,1:,4:R,2:L," +
	"4:R,4:,2:L,2:R,2:L,2:R,74:,5:L,2:,8:R,7:L,1:,4:R,2:L,4:R,28:,5:L,2:,8:R,7:L,1:,4:R,2:L,4:R,4:,2:L,2:R," +
	"2:L,3:R,73:,5:L,2:,8:R,7:L,1:,4:R,2:L,4:R,28:,5:L,2:,8:R,7:L,1:,4:R,2:L,4:R,4:,2:L,2:R,2:L,2:R,74:,5:L," +
	"2:,8:R,7:L,1:,4:R,2:L,4:R,4:,1:R,23:,5:L,2:,8:R,7:L,1:,4:R,2:L,4:R,4:,2:L,2:R,2:L,2:R,74:,5:L,2:,8:R,7:L," +
	"1:,4:R,2:L,4:R,14:,8:U,6:,3:L,1:R,1:L,2:R,16:L,15:,9:UF,25:,8:UF"
)
