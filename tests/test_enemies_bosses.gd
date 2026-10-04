extends "res://tests/test_enemies_case.gd"
## Boss logic (GAMEPLAY.md 6.1, 6.3): the Brute's phases, weak point, stagger, bounce, pound and defeat; the Wall
## Colossus' thrown-only hits, attack loop, rage and defeat; energy bars through Events.boss_*.

var _started: Array[BossBase] = []
var _energy: Array[Vector2i] = []
var _defeated: Array[BossBase] = []


func before_each() -> void:
	super.before_each()
	_started.clear()
	_energy.clear()
	_defeated.clear()
	Events.boss_started.connect(_on_boss_started)
	Events.boss_energy_changed.connect(_on_boss_energy)
	Events.boss_defeated.connect(_on_boss_defeated)


func after_each() -> void:
	Events.boss_started.disconnect(_on_boss_started)
	Events.boss_energy_changed.disconnect(_on_boss_energy)
	Events.boss_defeated.disconnect(_on_boss_defeated)


# =================================================================================================================
# The Brute
# =================================================================================================================

func test_brute_sleeps_until_the_hero_is_near() -> void:
	var brute: Brute = _brute()
	Sim.step(5)
	assert_false(brute.fighting)
	assert_true(brute.visible, "bosses are visible before the fight")
	assert_eq(brute.sim_pos, Vector2i(400, 160))
	assert_eq(_level.get_kind(Defs.Kind.BOSS).size(), 1)
	assert_eq(_level.get_kind(Defs.Kind.ENEMY).size(), 0, "not in the ordinary enemy list")
	_hero.teleport(Vector2i(200, 160))
	Sim.step(1)
	assert_true(brute.fighting, "within 250 px")
	assert_eq(_started, [brute] as Array[BossBase])
	assert_eq(_energy.back(), Vector2i(8, 8), "64 hit points = 8 pips")
	assert_eq(brute.get_state(), Brute.State.WATCH)


func test_brute_watches_then_jumps_high_then_leaps() -> void:
	var brute: Brute = _brute()
	_hero.teleport(Vector2i(200, 160))
	var ticks: int = _step_until_state(brute, Brute.State.JUMP, 200)
	assert_eq(ticks, EnemyTuning.BRUTE_WATCH_TICKS, "watches for 110 ticks")
	assert_eq(brute.get_anger(), 1)
	var top: int = 160
	var shook: bool = false
	var left: int = brute.sim_pos.x
	for tick: int in 130:
		Sim.step(1)
		top = mini(top, brute.sim_pos.y)
		left = mini(left, brute.sim_pos.x)
		shook = shook or _level.shake >= EnemyTuning.BOSS_STOMP_SHAKE
		if brute.get_state() != Brute.State.JUMP:
			break
	assert_eq(top, 160 - 105, "a very high jump (105 px)")
	assert_true(shook, "the landing shakes the screen")
	assert_eq(left, brute.left_x, "the far leap toward the hero stops at the arena limit")
	assert_eq(brute.get_state(), Brute.State.WATCH)
	assert_eq(brute.get_anger(), EnemyTuning.BRUTE_ANGER_AFTER_JUMP)


func test_brute_gets_angry_at_a_swinging_hero() -> void:
	var brute: Brute = _brute()
	_hero.teleport(Vector2i(300, 160))
	_hero.attack_gate = true
	var ticks: int = _step_until_state(brute, Brute.State.JUMP, 200)
	assert_eq(ticks, 4 * (EnemyTuning.BRUTE_ANGER_PERIOD_MASK + 1), "anger above 3 after 4 x 8 ticks")
	assert_eq(brute.get_anger(), 4)
	brute._anger = EnemyTuning.BRUTE_ANGER_ATTACK
	brute._set_state(Brute.State.WATCH)
	Sim.step(1)
	assert_eq(brute.get_state(), Brute.State.ATTACK, "anger 10 or more: attack routine")


func test_brute_attack_hops_and_punches() -> void:
	var brute: Brute = _brute()
	_hero.teleport(Vector2i(250, 160))
	Sim.step(1)
	brute._anger = 5
	brute._set_state(Brute.State.ATTACK)
	Sim.step(1)
	assert_eq(brute.xvel, -(EnemyTuning.BRUTE_ATTACK_HOP_XVEL_BASE + 2 * EnemyTuning.BRUTE_ATTACK_HOP_XVEL_STEP),
			"hops toward a hero farther than 100 px")
	assert_eq(brute.yvel, EnemyTuning.BRUTE_ATTACK_HOP_YVEL)
	brute.teleport(Vector2i(400, 160))
	brute.xvel = 0
	brute.yvel = 0
	brute._grounded = true
	_hero.teleport(Vector2i(345, 160))
	var fisted: bool = false
	for tick: int in 12:
		Sim.step(1)
		var fist: Rect2i = brute.get_fist_rect()
		if fist.size.x > 0:
			fisted = true
			assert_eq(fist.position.x, 400 - EnemyTuning.BRUTE_FIST_FAR, "the fist reaches 40..70 px in front")
	assert_true(fisted, "punches when closer than 100 px")
	assert_eq(Game.hearts, Tuning.ENERGY_START - 1, "the fist costs a bone")
	assert_eq(Game.bones, Tuning.BONES_PER_HEART - 1)


func test_brute_head_is_the_weak_point() -> void:
	var brute: Brute = _brute()
	_hero.teleport(Vector2i(300, 160))
	Sim.step(2)
	_club(brute.get_head_rect(), 25)
	Sim.step(1)
	assert_eq(brute.hp, 64 - 25)
	assert_eq(_energy.back(), Vector2i(5, 8))
	assert_eq(brute.get_state(), Brute.State.STAGGER, "a hit stronger than 20 staggers it")
	assert_eq(brute.skin, "brute_enraged", "red under 60 hit points")
	assert_true(brute.hit_cooldown > 0)
	assert_true(brute.xvel > 0, "thrown back away from the hero")
	_club(brute.get_head_rect(), 25)
	Sim.step(1)
	assert_eq(brute.hp, 64 - 25, "hits count at most once per 22 ticks")
	_hero.club_box_active = false
	Sim.step(Tuning.BOSS_HIT_COOLDOWN)
	assert_eq(brute.get_state(), Brute.State.JUMP, "the stagger lasts 19 ticks; under 60 it skips watching")
	var body: Rect2i = brute.get_box()
	_club(Rect2i(body.position.x, body.end.y - 10, body.size.x, 10), 25)
	Sim.step(1)
	assert_eq(brute.hp, 64 - 25, "the body is not a weak point")
	_hero.club_box_active = false
	var axe: ProjectileBase = ProjectileBase.new()
	var head: Rect2i = brute.get_head_rect()
	place(_level, axe, Vector2i(head.get_center().x, head.end.y), {"from_hero": true, "power": 20})
	Sim.step(1)
	assert_true(axe.spent, "a thrown weapon on the head is used up")
	assert_eq(brute.hp, 64 - 45)
	assert_ne(brute.get_state(), Brute.State.STAGGER, "20 power does not stagger")


func test_brute_body_costs_a_bone_and_the_head_is_a_springboard() -> void:
	var brute: Brute = _brute()
	_hero.teleport(Vector2i(300, 160))
	Sim.step(2)
	_hero.teleport(Vector2i(brute.sim_pos.x - 20, 160))
	Sim.step(1)
	assert_eq(Game.hearts, Tuning.ENERGY_START - 1)
	assert_eq(Game.bones, Tuning.BONES_PER_HEART - 1, "one bone")
	assert_eq(_hero.hit_timer, Tuning.HIT_TIMER)
	assert_eq(_hero.xvel, -Tuning.BOSS_KNOCK_XVEL, "knocked away")
	_hero.hit_timer = 0
	_hero.teleport(Vector2i(brute.sim_pos.x, brute.sim_pos.y - brute.box_h + 6))
	_hero.yvel = 64
	var bounces: Array[SimEntity] = []
	var on_bounce: Callable = func(target: SimEntity, _m: int) -> void: bounces.append(target)
	Events.player_bounced.connect(on_bounce)
	Sim.step(1)
	Events.player_bounced.disconnect(on_bounce)
	assert_eq(_hero.yvel, Tuning.BOSS_BOUNCE_YVEL, "landing on the head bounces")
	assert_eq(bounces, [brute] as Array[SimEntity])
	assert_eq(Game.bones, Tuning.BONES_PER_HEART - 1, "without damage")
	assert_eq(brute.hp, 64, "to either side")


func test_brute_ground_pound_under_40() -> void:
	var brute: Brute = _brute()
	brute.hp = 30
	_hero.teleport(Vector2i(400 - 77, 160))
	Sim.step(1)
	assert_eq(brute.get_state(), Brute.State.JUMP, "skips watching under 60 hit points")
	_step_until_state(brute, Brute.State.POUND, 60)
	assert_eq(brute.get_state(), Brute.State.POUND, "close and under 40: ground pound instead of the high jump")
	Sim.step(2)
	assert_true(_level.shake >= EnemyTuning.BOSS_BOB_SHAKE, "continuous screen shake")
	assert_eq(Game.bones, 0, "the hero 77 px away is safe")
	_hero.teleport(Vector2i(brute.sim_pos.x - 40, 160))
	Sim.step(6)
	assert_eq(Game.bones, Tuning.BONES_PER_HEART - 1, "the pounding fists hit the floor in front of it")
	_hero.hit_timer = 0
	_hero.teleport(Vector2i(400 - 77, 160))
	Sim.step(EnemyTuning.BRUTE_POUND_TICKS - 7)
	assert_eq(brute.get_state(), Brute.State.ATTACK, "66 ticks of pounding")


func test_brute_defeat_leaps_up_and_drops_the_fire_starter() -> void:
	var brute: Brute = _brute()
	_hero.teleport(Vector2i(300, 160))
	Sim.step(2)
	_level.lock_camera(Rect2i(200, 0, 320, 180))
	brute.hp = 1
	_club(brute.get_head_rect(), 25)
	Sim.step(1)
	_hero.club_box_active = false
	assert_eq(brute.get_state(), Brute.State.DYING)
	assert_false(brute.dead, "leaps up first")
	var y: int = brute.sim_pos.y
	Sim.step(5)
	assert_true(brute.sim_pos.y < y)
	Sim.step(20)
	assert_true(brute.dead)
	assert_false(brute.visible, "vanishes")
	assert_eq(_defeated, [brute] as Array[BossBase])
	assert_eq(_energy.back(), Vector2i(0, 8))
	assert_false(_level.is_camera_locked(), "the arena lock is released")
	if Spawner.exists(&"items/fire_starter"):
		assert_eq(_of_scene(Defs.Kind.COLLECTIBLE, &"items/fire_starter").size(), 1)
	_level.reset_entities()
	assert_true(brute.dead, "a defeated boss stays defeated")
	assert_false(brute.visible)


func test_brute_reset_before_defeat() -> void:
	var brute: Brute = _brute({"enraged": true})
	assert_eq(brute.skin, "brute_enraged", "the Expert rematch starts red")
	_hero.teleport(Vector2i(300, 160))
	Sim.step(3)
	brute.hp = 20
	_level.reset_entities()
	assert_false(brute.fighting)
	assert_eq(brute.hp, 64)
	assert_eq(brute.get_state(), Brute.State.IDLE)
	assert_eq(_energy.back(), Vector2i(0, 8), "the energy bar is hidden")
	assert_true(brute.visible)
	assert_eq(brute.sim_pos, Vector2i(400, 160))


# =================================================================================================================
# The Wall Colossus
# =================================================================================================================

func test_colossus_stands_in_the_wall_and_wakes() -> void:
	var colossus: Colossus = _colossus()
	var face: int = 20 * Tuning.TILE
	assert_eq(colossus.sim_pos, Vector2i(face + EnemyTuning.COLOSSUS_RIM_PX, 160), "the rim covers the wall face")
	assert_eq(colossus.get_box(), Rect2i(face + EnemyTuning.COLOSSUS_RIM_PX - 104, 160 - 95, 104, 95))
	Sim.step(3)
	assert_false(colossus.fighting)
	_hero.teleport(Vector2i(100, 160))
	Sim.step(1)
	assert_true(colossus.fighting)
	assert_eq(_energy.back(), Vector2i(6, 6), "24 hit points = 6 pips of 4")


func test_colossus_attack_loop_spits_rocks_and_drops_stalactites() -> void:
	var colossus: Colossus = _colossus()
	_hero.teleport(Vector2i(100, 160))
	Sim.step(1)
	Sim.step(EnemyTuning.COLOSSUS_IDLE_TICKS[0] + EnemyTuning.COLOSSUS_SPIT_RELEASE_TICK - 1)
	var rocks: Array[SimEntity] = _of_scene(Defs.Kind.ENEMY_PROJECTILE, &"projectiles/boss_rock")
	assert_eq(rocks.size(), 1, "a rock after the first idle loop")
	var rock: SimEntity = rocks[0]
	assert_eq(rock.sim_pos, colossus.sim_pos + EnemyTuning.COLOSSUS_MOUTH, "from the open jaws")
	assert_true(rock.xvel <= -EnemyTuning.ROCK_XVEL_MIN and rock.xvel >= -120, "to the left, random speed")
	assert_eq(posmod(rock.xvel, EnemyTuning.ROCK_XVEL_STEP), 0)
	var drops: Array[SimEntity] = []
	for tick: int in 60:
		Sim.step(1)
		drops = _of_scene(Defs.Kind.ENEMY_PROJECTILE, &"projectiles/boss_stalactite")
		if not drops.is_empty():
			break
	assert_eq(drops.size(), 1, "then a stalactite")
	var drop: SimEntity = drops[0]
	assert_true(drop.sim_pos.x >= EnemyTuning.COLOSSUS_DROP_MARGIN, "in the left part of the room")
	assert_true(drop.sim_pos.x <= colossus.get_box().position.x - EnemyTuning.COLOSSUS_DROP_MARGIN,
			"never under the statue")
	assert_eq(drop.sim_pos.y, EnemyTuning.STALACTITE_BOX.y, "hangs under the top of the room")


func test_colossus_takes_only_thrown_weapons_one_point_each() -> void:
	var colossus: Colossus = _colossus()
	_hero.teleport(Vector2i(100, 160))
	Sim.step(2)
	_club(colossus.get_head_rect(), 100)
	Sim.step(1)
	assert_eq(colossus.hp, 24, "the club cannot hurt it")
	_hero.club_box_active = false
	_throw_at(colossus.get_head_rect(), 120)
	Sim.step(1)
	assert_eq(colossus.hp, 23, "exactly one hit point, whatever the power")
	assert_eq(_energy.back(), Vector2i(6, 6))
	assert_eq(colossus.get_state(), Colossus.State.HURT)
	assert_eq(colossus.get_hits(), 1)
	var before: int = _level.get_kind(Defs.Kind.ENEMY_PROJECTILE).size()
	Sim.step(EnemyTuning.COLOSSUS_HURT_TICKS)
	assert_eq(colossus.get_state(), Colossus.State.RAGE, "the first hit starts a rage")
	Sim.step(EnemyTuning.COLOSSUS_RAGE_TICKS)
	var rocks: int = _of_scene(Defs.Kind.ENEMY_PROJECTILE, &"projectiles/boss_rock").size()
	var drops: int = _of_scene(Defs.Kind.ENEMY_PROJECTILE, &"projectiles/boss_stalactite").size()
	assert_true(rocks >= 1 and drops >= 2, "one rock and two stalactites in quick succession")
	assert_true(_level.get_kind(Defs.Kind.ENEMY_PROJECTILE).size() >= before + 3)
	for hit: int in 3:
		_throw_at(colossus.get_head_rect(), 20)
		Sim.step(1)
		assert_eq(colossus.get_state(), Colossus.State.HURT)
		Sim.step(EnemyTuning.COLOSSUS_HURT_TICKS)
		assert_eq(colossus.get_state(), Colossus.State.IDLE, "hits 2-4 only hurt")
	_throw_at(colossus.get_head_rect(), 20)
	Sim.step(1 + EnemyTuning.COLOSSUS_HURT_TICKS)
	assert_eq(colossus.get_hits(), 5)
	assert_eq(colossus.get_state(), Colossus.State.RAGE, "every 4th hit after the first rages again")
	assert_eq(colossus.hp, 19)


func test_colossus_defeat_breaks_the_statue() -> void:
	var colossus: Colossus = _colossus()
	_hero.teleport(Vector2i(100, 160))
	Sim.step(2)
	colossus.hp = 1
	_throw_at(colossus.get_head_rect(), 20)
	Sim.step(2)
	assert_true(colossus.dead)
	assert_eq(colossus.get_state(), Colossus.State.BROKEN)
	assert_true(colossus.visible, "the broken statue stays in the wall")
	var sprite: Sprite2D = colossus.get_node(^"Sprite")
	assert_eq(sprite.frame, 16, "broken pose")
	assert_eq(_defeated, [colossus] as Array[BossBase])
	if Spawner.exists(&"items/trophy"):
		assert_eq(_of_scene(Defs.Kind.COLLECTIBLE, &"items/trophy").size(), 4, "four trophies")


# =================================================================================================================
# Projectiles
# =================================================================================================================

func test_rock_bounces_along_the_floor_and_crumbles() -> void:
	_hero.teleport(Vector2i(600, 160))
	var rock: ProjectileBase = _spawn(&"projectiles/boss_rock", Vector2i(250, 100), {"xvel": -64, "yvel": 0})
	var bounced: bool = false
	var landed: bool = false
	var ticks: int = 0
	while not rock.spent and ticks < 200:
		Sim.step(1)
		ticks += 1
		assert_true(rock.sim_pos.y <= 160, "never inside the floor")
		landed = landed or rock.sim_pos.y == 160
		bounced = bounced or (landed and rock.yvel < 0)
	assert_true(landed and bounced, "falls and bounces at half height")
	assert_true(rock.spent)
	assert_true(ticks <= EnemyTuning.ROCK_LIFE)
	assert_eq(Game.hearts, Tuning.ENERGY_START, "never touched the hero")


func test_rock_hurts_the_hero() -> void:
	var rock: ProjectileBase = _spawn(&"projectiles/boss_rock", Vector2i(44, 160), {"xvel": -16})
	Sim.step(1)
	assert_true(rock.spent)
	assert_eq(Game.hearts, Tuning.ENERGY_START - 1, "a full heart")
	assert_eq(_hero.hit_timer, Tuning.HIT_TIMER)


func test_stalactite_rattles_falls_and_shatters() -> void:
	var drop: BossStalactite = _spawn(&"projectiles/boss_stalactite", Vector2i(250, 60)) as BossStalactite
	Sim.step(EnemyTuning.STALACTITE_WARN_TICKS - 1)
	assert_eq(drop.sim_pos.y, 60, "rattles at the ceiling first")
	assert_true(drop.is_warning())
	for tick: int in 40:
		Sim.step(1)
		assert_true(drop.sim_pos.y <= 160)
		if drop.spent:
			break
	assert_true(drop.spent, "shatters on the floor")
	assert_eq(drop.sim_pos.y, 160)


func test_embers_fall_sway_and_are_limited() -> void:
	var embers: Array[ProjectileBase] = []
	for i: int in EnemyTuning.EMBER_MAX_ALIVE + 2:
		var params: Dictionary = {"rain": true, "skin": "leaf"}
		embers.append(_spawn(&"projectiles/enemy_ember", Vector2i.ZERO, params) as ProjectileBase)
	var falling: int = 0
	for ember: ProjectileBase in embers:
		falling += 0 if ember.spent else 1
	assert_eq(falling, EnemyTuning.EMBER_MAX_ALIVE, "up to 5 at once")
	var ember: ProjectileBase = embers[0]
	assert_eq(ember.sim_pos.y, 160 - EnemyTuning.EMBER_DROP_ABOVE_HERO, "150 px above the hero")
	assert_true(absi(ember.sim_pos.x - 40) <= EnemyTuning.EMBER_DROP_SPREAD)
	assert_true(ember.yvel >= 16 and ember.yvel <= 64 and ember.yvel % 16 == 0, "1..4 px per tick")
	var x0: int = ember.sim_pos.x
	var y0: int = ember.sim_pos.y
	Sim.step(8)
	assert_true(absi(ember.sim_pos.x - x0) <= EnemyTuning.EMBER_SWAY_PX and ember.sim_pos.x != x0, "sways")
	assert_eq(ember.sim_pos.y, y0 + 8 * Tuning.floor16(ember.yvel))
	Sim.step(200)
	assert_true(ember.spent, "fizzles on the floor")


func test_ember_costs_a_bone() -> void:
	var ember: ProjectileBase = _spawn(&"projectiles/enemy_ember", Vector2i(40, 150), {"yvel": 16})
	Sim.step(1)
	assert_true(ember.spent)
	assert_eq(Game.bones, Tuning.BONES_PER_HEART - 1)
	assert_eq(Game.hearts, Tuning.ENERGY_START - 1)


# =================================================================================================================
# Helpers
# =================================================================================================================

func _brute(params: Dictionary = {}) -> Brute:
	var all: Dictionary = {"arena": "pit", "left": 20, "right": 30}
	all.merge(params, true)
	return _enemy(&"bosses/brute", Vector2i(400, 160), all) as Brute


func _colossus() -> Colossus:
	var rows: PackedStringArray = PackedStringArray()
	for row: int in 10:
		rows.append(".".repeat(20) + "#".repeat(10))
	rows.append("#".repeat(30))
	_rows_level(rows)
	return _enemy(&"bosses/colossus", Vector2i(19 * Tuning.TILE + 8, 160)) as Colossus


## Make the hero's club box (of the "previous tick") cover `box`.
func _club(box: Rect2i, power: int) -> void:
	_hero.club_box_active = true
	_hero.club_box = box
	_hero.club_power = power


## A thrown weapon of the hero in the middle of `target`.
func _throw_at(target: Rect2i, power: int) -> void:
	var axe: ProjectileBase = ProjectileBase.new()
	place(_level, axe, Vector2i(target.get_center().x, target.end.y), {"from_hero": true, "power": power})


func _step_until_state(boss: EnemyBase, state: int, max_ticks: int) -> int:
	for tick: int in max_ticks:
		Sim.step(1)
		if boss.call(&"get_state") == state:
			return tick + 1
	return -1


func _on_boss_started(boss: BossBase) -> void:
	_started.append(boss)


func _on_boss_energy(_boss: BossBase, pips: int, max_pips: int) -> void:
	_energy.append(Vector2i(pips, max_pips))


func _on_boss_defeated(boss: BossBase) -> void:
	_defeated.append(boss)
