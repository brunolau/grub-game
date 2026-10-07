extends "res://tests/test_enemies_case.gd"
## The Twin Idols (scripts/bosses/idols.gd; DESIGN.md B.4, GAMEPLAY.md 13.6; PLAN.md P2.3, owner enemies-C): the two
## idols in the walls, the shared brain (one awake idol spits, the asleep one drops masonry), 1 per hit of any weapon
## (the club works), the rage every 4th hit and the role swap, the telegraphs of B.0, defeat; the co-op Twin Hit (both
## awake, each only while a hero stands on its half, a crack only within the twin window, the crossed targets after a
## rage) and the single-hero search against it with the real hero.
##
## The court: 20 x 11 cells, walls in columns 0 and 19, floor at row 10 (feet y 160). The Sun Idol stands in the
## right wall (feet x 336), the Moon Idol in the left (feet x -16): bodies -16..88 and 232..336, the halves meet at 160.

const PLAYER_SCENE: String = "res://scenes/player/player.tscn"
const SUN_X: int = 336
const MOON_X: int = -16
const MID: int = 160

var _p2: PlayerBase = null
var _defeated: Array[BossBase] = []


func before_each() -> void:
	super.before_each()
	_defeated.clear()
	_p2 = null
	Events.boss_defeated.connect(_on_defeated)


func after_each() -> void:
	Events.boss_defeated.disconnect(_on_defeated)
	GameInput.clear_scripted()
	Game.new_game(Defs.Difficulty.BEGINNER)
	Game.begin_level(&"")


# =================================================================================================================
# Placement and the solo form
# =================================================================================================================

func test_the_idols_sit_in_both_walls_mirrored() -> void:
	var idols: Idols = _court()
	Sim.step(1)
	assert_eq(idols.get_idol_pos(Idols.SUN), Vector2i(SUN_X, 160), "the Sun: 32 px inside the right wall")
	assert_eq(idols.get_idol_pos(Idols.MOON), Vector2i(MOON_X, 160), "the Moon: 32 px inside the left wall")
	assert_eq(idols.get_body_rect(Idols.SUN), Rect2i(SUN_X - 104, 65, 104, 95))
	assert_eq(idols.get_body_rect(Idols.MOON), Rect2i(MOON_X, 65, 104, 95))
	assert_eq(idols.get_mid_x(), MID)
	var sun_head: Rect2i = idols.get_head_rect(Idols.SUN)
	var moon_head: Rect2i = idols.get_head_rect(Idols.MOON)
	assert_eq(sun_head, Rect2i(SUN_X - 106, 90, 46, 31), "the Colossus idle head")
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
	for crack: int in Idols.RAGE_EVERY:
		_club_by(_hero, idols.get_head_rect(Idols.MOON))
		_club_by(_p2, idols.get_head_rect(Idols.SUN))
		Sim.step(1)
		_hero.club_box_active = false
		_p2.club_box_active = false
		Sim.step(Idols.HURT_TICKS)
	assert_eq(idols.hp, 16 - 2 * Idols.RAGE_EVERY)
	var raged: bool = idols.get_state() == Idols.State.RAGE
	for tick: int in 80:
		if raged and idols.get_state() != Idols.State.RAGE:
			break
		Sim.step(1)
		raged = raged or idols.get_state() == Idols.State.RAGE
	assert_true(raged, "every 4th twin crack: both rage")
	assert_true(idols.is_crossed(), "then each idol aims at the far half")
	assert_eq(idols._target_of(Idols.MOON), _p2, "the Moon now aims at the Sun's hero")
	assert_eq(idols._target_of(Idols.SUN), _hero)


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


## V3.d: one hero cannot beat the Twin Hit. The real hero (club, then the axe, the swirling axe and the spear) with his
## partner an egg, from many places in the court, throws at the far idol and strikes the near one on every timing
## offset within the window, and plays seeded random inputs: no idol ever cracks.
func test_the_single_hero_search_cannot_crack_the_twin_idols() -> void:
	var idols: Idols = _coop_court()
	var hero: PlayerBase = _real_hero(Vector2i(MID, 160), 0)
	_p2 = _add_hero2(Vector2i(MID + 40, 160))
	_p2.down = true
	idols.start_fight()
	assert_true(idols.is_coop_form(), "two heroes in a co-op file: the Twin Hit")
	var rng: SimRng = SimRng.new(4242)
	var episodes: int = 0
	for weapon: int in [Defs.Weapon.CLUB, Defs.Weapon.AXE, Defs.Weapon.BOOMERANG, Defs.Weapon.SPEAR]:
		for start_x: int in [96, 120, 150, 175, 200, 225]:
			for offset: int in [0, 4, 8, 12]:
				_episode(hero, weapon, Vector2i(start_x, 160), _throw_then_strike(start_x, offset))
				episodes += 1
				assert_eq(idols.hp, idols.max_hp, "weapon %d from x %d, offset %d: no crack" % [weapon, start_x, offset])
		for run: int in 3:
			_episode(hero, weapon, Vector2i(rng.range_int(96, 225), 160), _random_flags(rng, 240))
			episodes += 1
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
	GameInput.clear_scripted()


func _on_defeated(boss: BossBase) -> void:
	_defeated.append(boss)
