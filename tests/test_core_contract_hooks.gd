extends PlayerTestCase
## The hooks for parallel work of docs/expansion/PLAN.md P0.8: the hero's egg / shield / curl / mount-seat / launch /
## fence API (PlayerBase), the component calls of Player for hero_belt.gd, hero_climb.gd, hero_mount.gd and
## hero_party.gd, the EnemyBase hit bookkeeping and hooks, the bond and keeper registry, BossBase.last_hitter, the
## platform's riders and LevelBase.register_party_driver. Every hook keeps its 1.0 default for a single-player hero
## (the route digests prove the ticks: tools/sp_identity.sh); these tests prove what the hooks do when used.


## A component that logs every hook call into a shared log and may take the update or a hurt over.
class RecordingParty:
	extends HeroParty

	var log: Array = []
	var take_over: bool = false

	func weapon_pass(_level: LevelBase) -> void:
		log.append("party.weapon_pass")

	func update(_level: LevelBase) -> bool:
		log.append("party.update")
		return take_over

	func tick_timers() -> void:
		log.append("party.timers")

	func post_step(_level: LevelBase) -> void:
		log.append("party.post")

	func on_hurt(_source: SimEntity, _kind: int) -> bool:
		log.append("party.hurt")
		return false

	func on_respawn() -> void:
		log.append("party.respawn")


class RecordingMount:
	extends HeroMount

	var log: Array = []
	var absorb: bool = false

	func update(_level: LevelBase) -> bool:
		log.append("mount.update")
		return false

	func tick_timers() -> void:
		log.append("mount.timers")

	func on_hurt(_source: SimEntity, _kind: int) -> bool:
		log.append("mount.hurt")
		return absorb

	func on_respawn() -> void:
		log.append("mount.respawn")


class RecordingBelt:
	extends HeroBelt

	var log: Array = []

	func update(_level: LevelBase) -> bool:
		log.append("belt.update")
		return false

	func tick_timers() -> void:
		log.append("belt.timers")

	func on_respawn() -> void:
		log.append("belt.respawn")


class RecordingClimb:
	extends HeroClimb

	var log: Array = []

	func update(_level: LevelBase) -> bool:
		log.append("climb.update")
		return false

	func tick_timers() -> void:
		log.append("climb.timers")

	func on_hurt(_source: SimEntity, _kind: int) -> bool:
		log.append("climb.hurt")
		return false

	func on_respawn() -> void:
		log.append("climb.respawn")


## An enemy that logs the 2.0 hit hooks and may refuse hits or choose no target.
class HookEnemy:
	extends EnemyBase

	var refuse: bool = false
	var no_target: bool = false
	var hits: Array = []
	var refused: int = 0

	func accepts_hit_from(_source: SimEntity) -> bool:
		return not refuse

	func _on_hit_by(slot: int, power: int) -> void:
		hits.append([slot, power])

	func _on_hit_refused(_source: SimEntity) -> void:
		refused += 1

	func _choose_target() -> PlayerBase:
		return null if no_target else super._choose_target()


## A party driver that logs the deaths it is asked to handle.
class RecordingDriver:
	extends SimEntity

	var handled: bool = true
	var deaths: Array[PlayerBase] = []

	func handle_hero_death(hero: PlayerBase) -> bool:
		deaths.append(hero)
		return handled


var _events: Array = []


func before_each() -> void:
	super.before_each()
	_events.clear()
	Sim.start(1)


func after_each() -> void:
	for connection: Dictionary in Events.hero_down.get_connections():
		if connection["callable"] == _on_hero_down:
			Events.hero_down.disconnect(_on_hero_down)
	for connection: Dictionary in Events.hero_revived.get_connections():
		if connection["callable"] == _on_hero_revived:
			Events.hero_revived.disconnect(_on_hero_revived)
	Sim.stop()
	super.after_each()


func _on_hero_down(who: PlayerBase, cause: StringName) -> void:
	_events.append(["down", who, cause])


func _on_hero_revived(who: PlayerBase, by: PlayerBase) -> void:
	_events.append(["revived", who, by])


# =================================================================================================================
# PlayerBase
# =================================================================================================================

func test_a_single_player_hero_keeps_every_2_0_default() -> void:
	world_flat()
	spawn_hero()
	for part: Object in [hero.hero_belt, hero.hero_climb, hero.hero_mount, hero.hero_party]:
		assert_false(part.get(&"active"), "%s is off for a Book I hero" % part.get_script().get_global_name())
		assert_eq(part.get(&"hero"), hero)
	assert_false(hero.down)
	assert_false(hero.is_down())
	assert_eq(hero.shield, 0)
	assert_eq(hero.curl, PlayerBase.CURL_NONE)
	assert_false(hero.is_curled())
	assert_null(hero.mount)
	assert_eq(hero.mount_seat, PlayerBase.SEAT_NONE)
	assert_false(hero.is_mounted())
	assert_true(hero.fence_allows(-100000), "no fence")
	assert_eq([hero.leash, hero.hit_stop, hero.squash], [0, 0, 0], "no leash, hit-stop or squash")
	play(hold("R", 8))
	assert_true(hero.sim_pos.x > START_X, "he walks as in 1.0")
	assert_eq([hero.leash, hero.hit_stop, hero.squash], [0, 0, 0], "nothing in single-player sets them")
	hero.leash = 40
	hero.hit_stop = 2
	hero.squash = 8
	hero.respawn_at(START)
	assert_eq([hero.leash, hero.hit_stop, hero.squash], [0, 0, 0], "a respawn clears the leash, hit-stop and squash")


func test_two_crouching_heroes_side_by_side_brace() -> void:
	var a: PlayerBase = PlayerBase.new()
	var b: PlayerBase = PlayerBase.new()
	for pair: Array in [[a, 100], [b, 100 + PartyTuning.BRACE_GAP_PX]]:
		var one: PlayerBase = pair[0]
		one.state = Defs.HeroState.CROUCH
		one.grounded = true
		one.sim_pos = Vector2i(int(pair[1]), 160)
	assert_true(a.braces_with(b), "both crouch on the ground within 16 px")
	assert_true(b.braces_with(a))
	assert_false(a.braces_with(null), "no partner, no brace (single-player)")
	assert_false(a.braces_with(a))
	b.sim_pos = Vector2i(101 + PartyTuning.BRACE_GAP_PX, 160)
	assert_false(a.braces_with(b), "17 px apart")
	b.sim_pos = Vector2i(100 - PartyTuning.BRACE_GAP_PX, 160)
	assert_true(a.braces_with(b), "on either side")
	b.state = Defs.HeroState.CRAWL
	assert_false(a.braces_with(b), "a crawl is no brace")
	b.state = Defs.HeroState.CROUCH
	b.grounded = false
	assert_false(a.braces_with(b), "both on the ground")
	b.grounded = true
	b.down = true
	assert_false(a.braces_with(b), "an egg cannot brace")
	a.free()
	b.free()


func test_launch_clamps_each_axis_and_arms_the_landing_lock() -> void:
	world_flat()
	spawn_hero()
	hero.on_platform = true
	hero.fall_ticks = 9
	hero.launch(400, -500)
	assert_eq(hero.xvel, PartyTuning.LAUNCH_AXIS_CAP)
	assert_eq(hero.yvel, -PartyTuning.LAUNCH_AXIS_CAP)
	assert_eq(PartyTuning.LAUNCH_AXIS_CAP, 288, "18 px per tick, the doze reach")
	assert_eq(hero.no_jump, Tuning.NO_JUMP_TICKS)
	assert_eq(hero.fall_ticks, 0)
	assert_false(hero.on_platform)
	assert_false(hero.grounded)
	hero.xvel = 40
	hero.launch(PlayerBase.LAUNCH_KEEP, -224)
	assert_eq(hero.xvel, 40, "LAUNCH_KEEP keeps a component (a geyser keeps xvel)")
	assert_eq(hero.yvel, -224)


func test_an_egg_is_out_of_play_until_it_hatches() -> void:
	world_flat()
	spawn_hero()
	Events.hero_down.connect(_on_hero_down)
	Events.hero_revived.connect(_on_hero_revived)
	var hearts: int = hero.run.hearts
	hero.go_down(&"leash")
	assert_true(hero.down)
	assert_true(hero.is_down())
	assert_false(hero.is_party_targetable())
	assert_true(hero.is_immune(), "an egg touches nothing")
	assert_false(hero.control_enabled)
	assert_eq(_events, [["down", hero, &"leash"]])
	assert_false(hero.hurt(null), "an egg cannot be hurt")
	assert_eq(hero.run.hearts, hearts)
	hero.kill(&"pit")
	assert_false(hero.dead, "nor killed")
	var at: Vector2i = hero.sim_pos
	play(hold("R", 5))
	assert_eq(hero.sim_pos, at, "without its party component an egg only waits")
	hero.hatch(null, PartyTuning.HATCH_HEARTS_BEGINNER)
	assert_false(hero.down)
	assert_true(hero.control_enabled)
	assert_eq(hero.shield, PartyTuning.HATCH_BLINK_TICKS)
	assert_eq(hero.run.hearts, PartyTuning.HATCH_HEARTS_BEGINNER)
	assert_eq(hero.run.bones, 0)
	assert_eq(hero.yvel, PartyTuning.HATCH_POP_YVEL, "the pop")
	assert_eq(hero.no_jump, Tuning.NO_JUMP_TICKS)
	assert_eq(_events[1], ["revived", hero, null])
	assert_true(hero.is_immune(), "the shield skips enemy contact")
	assert_true(hero.is_party_targetable())
	hero.hatch(null, 1)
	assert_eq(_events.size(), 2, "a hatched hero cannot hatch again")
	hero.respawn_at(START)
	assert_eq(hero.shield, 0, "a respawn clears the shield")
	assert_false(hero.is_immune())


func test_bat_seats_and_respawn() -> void:
	world_flat()
	spawn_hero()
	var batter: PlayerBase = PlayerBase.new()
	hero.curl = PlayerBase.CURL_CURLED
	assert_true(hero.is_curled())
	hero.bat(500, -100, batter)
	assert_eq(hero.curl, PlayerBase.CURL_BALL)
	assert_eq(hero.ball_batter, batter)
	assert_eq(hero.xvel, PartyTuning.LAUNCH_AXIS_CAP, "a batted ball obeys the launch cap")
	assert_eq(hero.yvel, -100)
	var mount: SimEntity = SimEntity.new()
	hero.sit_on_mount(mount, PlayerBase.SEAT_GUNNER)
	assert_true(hero.is_mounted())
	assert_eq(hero.mount, mount)
	assert_eq(hero.mount_seat, PlayerBase.SEAT_GUNNER)
	hero.sit_on_mount(mount, 7)
	assert_eq(hero.mount_seat, PlayerBase.SEAT_DRIVER, "any other seat is the driver's")
	hero.leave_mount()
	assert_false(hero.is_mounted())
	hero.sit_on_mount(mount, PlayerBase.SEAT_DRIVER)
	hero.respawn_at(START)
	assert_false(hero.is_mounted(), "a respawn leaves the seat ...")
	assert_eq(hero.curl, PlayerBase.CURL_NONE, "... uncurls ...")
	assert_null(hero.ball_batter)
	batter.free()
	mount.free()


func test_a_fence_limits_the_x_step_of_its_tick() -> void:
	world_flat()
	spawn_hero()
	hero.fence_x(START_X - 100, START_X + 50)
	hero.fence_x(START_X - 40, START_X + 300)
	assert_true(hero.fence_allows(START_X + 49))
	assert_false(hero.fence_allows(START_X + 50), "fences intersect")
	assert_false(hero.fence_allows(START_X - 41))
	hero.clear_fence()
	hero.fence_x(START_X - 16, START_X + 4)
	play(hold("R", 12), func(_tick: int) -> void: hero.fence_x(START_X - 16, START_X + 4))
	assert_true(hero.sim_pos.x < START_X + 4, "the fence holds him back (x %d)" % hero.sim_pos.x)
	assert_true(hero.sim_pos.x >= START_X)
	hero.clear_fence()
	play(hold("R", 6))
	assert_true(hero.sim_pos.x >= START_X + 4, "without a fence he walks on")


# =================================================================================================================
# Player components
# =================================================================================================================

func test_components_run_in_their_order_only_while_active() -> void:
	world_flat()
	spawn_hero()
	var log: Array = []
	var party: RecordingParty = RecordingParty.new(hero)
	var mount: RecordingMount = RecordingMount.new(hero)
	var belt: RecordingBelt = RecordingBelt.new(hero)
	var climb: RecordingClimb = RecordingClimb.new(hero)
	party.log = log
	mount.log = log
	belt.log = log
	climb.log = log
	hero.hero_party = party
	hero.hero_mount = mount
	hero.hero_belt = belt
	hero.hero_climb = climb
	play(hold("R", 2))
	assert_eq(log, [], "inactive components are never called")
	for part: Object in [party, mount, belt, climb]:
		part.set(&"active", true)
	play(hold("F", 1))
	assert_eq(log, [
		"party.update", "mount.update", "belt.update", "climb.update",
		"belt.timers", "climb.timers", "mount.timers", "party.timers", "party.post",
	], "one tick (PLAYER phase, its timers, POST)")
	var ticks: int = 0
	while not hero.club_box_active and ticks < 20:
		play(hold("F", 1))
		ticks += 1
	assert_true(hero.club_box_active, "the strike made a club box")
	log.clear()
	play(hold("", 1))
	assert_eq(log[0], "party.weapon_pass", "the strike's box meets the party first in the next weapon pass")
	log.clear()
	party.take_over = true
	var at: Vector2i = hero.sim_pos
	play(hold("R", 3))
	assert_eq(hero.sim_pos, at, "a component that takes the update over moves him itself")
	assert_false(log.has("mount.update"), "and the components after it do not run")
	party.take_over = false
	log.clear()
	mount.absorb = true
	var hearts: int = hero.run.hearts
	assert_true(hero.hurt(null), "the mount takes the hit")
	assert_eq(hero.run.hearts, hearts)
	assert_eq(hero.hit_timer, 0, "no 1.0 hurt")
	assert_eq(log, ["mount.hurt"])
	mount.absorb = false
	log.clear()
	assert_true(hero.hurt(null))
	assert_eq(log, ["mount.hurt", "climb.hurt", "party.hurt"])
	assert_eq(hero.run.hearts, hearts - 1, "the 1.0 hurt follows")
	log.clear()
	hero.respawn_at(START)
	assert_eq(log, ["party.respawn", "mount.respawn", "belt.respawn", "climb.respawn"])


# =================================================================================================================
# Enemies, bosses, platforms, the party driver
# =================================================================================================================

func test_enemy_hits_are_noted_and_hooked() -> void:
	var made: LevelBase = make_flat_level(48, 12, 10)
	var p1: PlayerBase = PlayerBase.new()
	place(made, p1, Vector2i(100, 160))
	var enemy: HookEnemy = HookEnemy.new()
	enemy.set_box(Vector3i(16, 16, 8))
	place(made, enemy, Vector2i(140, 160), {"hp": 100, "coop": "shell", "bond": "pair", "keeper": "hall"})
	enemy.wake()
	enemy.on_screen = true
	assert_eq(enemy.last_hit_slot, -1)
	assert_eq(enemy.last_hit_tick, -1)
	assert_eq(enemy.coop_trait, Defs.CoopTrait.SHELL)
	assert_eq(enemy.bond, &"pair")
	assert_eq(enemy.keeper, &"hall")
	Sim.step(3)
	assert_true(enemy.take_hit(25, p1))
	assert_eq(enemy.hp, 75)
	assert_eq(enemy.last_hit_slot, 0)
	assert_eq(enemy.last_hit_tick, Sim.total_ticks)
	assert_eq(enemy.hits, [[0, 25]])
	enemy.refuse = true
	assert_true(enemy.take_hit(25, p1), "a refused hit is consumed ...")
	assert_eq(enemy.hp, 75, "... and glances")
	assert_eq(enemy.refused, 1)
	assert_eq(enemy.hits.size(), 1)
	enemy.refuse = false
	assert_true(enemy.take_hit(10, null))
	assert_eq(enemy.hits[1], [-1, 10], "no hero's hit")
	assert_eq(enemy.last_hit_slot, 0, "keeps the last hero")
	assert_eq(enemy._target_hero(), made.target_hero(enemy), "the default target is the level's")
	assert_eq(enemy._target_hero(), p1)
	enemy.no_target = true
	assert_null(enemy._target_hero(), "_choose_target decides what every archetype sees")
	# The tag registry: bonds and keepers.
	var mate: HookEnemy = HookEnemy.new()
	place(made, mate, Vector2i(200, 160), {"bond": "pair"})
	var plain: EnemyBase = EnemyBase.new()
	place(made, plain, Vector2i(250, 160))
	assert_eq(plain.coop_trait, Defs.CoopTrait.NONE)
	assert_eq(plain.bond, &"")
	assert_eq(plain.bond_mates(), [] as Array[SimEntity])
	assert_eq(made.get_tagged(&"bond", &"pair"), [enemy, mate] as Array[SimEntity])
	assert_eq(made.get_tagged(&"keeper", &"hall"), [enemy] as Array[SimEntity])
	assert_eq(made.get_tagged(&"bond", &"nobody"), [] as Array[SimEntity])
	assert_eq(enemy.bond_mates(), [mate] as Array[SimEntity])
	mate.free()
	assert_eq(made.get_tagged(&"bond", &"pair"), [enemy] as Array[SimEntity], "a freed member leaves its group")
	var odd: EnemyBase = EnemyBase.new()
	place(made, odd, Vector2i(280, 160), {"coop": "sticky"})
	assert_eq(odd.coop_trait, Defs.CoopTrait.NONE, "an unknown trait is none")


func test_a_boss_remembers_its_last_hitter() -> void:
	var made: LevelBase = make_flat_level(64, 24, 20)
	var p1: PlayerBase = PlayerBase.new()
	place(made, p1, Vector2i(200, 320))
	var boss: BossBase = BossBase.new()
	place(made, boss, Vector2i(240, 320), {"hp": 100})
	boss.fighting = true
	assert_null(boss.last_hitter)
	var weak_point: Rect2i = Rect2i(220, 280, 40, 40)
	p1.club_box_active = true
	p1.club_box = Rect2i(230, 290, 20, 10)
	p1.club_power = 25
	assert_eq(boss.poll_weapon_hit(weak_point), 25)
	assert_eq(boss.last_hitter, p1)
	assert_eq(boss.last_hit_slot, 0)
	assert_eq(boss.last_hit_tick, Sim.total_ticks)


func test_a_platform_counts_its_riders() -> void:
	var made: LevelBase = make_flat_level(48, 16, 10)
	var p1: PlayerBase = PlayerBase.new()
	place(made, p1, Vector2i(92, 160))
	var p2: PlayerBase = PlayerBase.new()
	place(made, p2, Vector2i(108, 160), {"slot": 1})
	var platform: PlatformBase = PlatformBase.new()
	place(made, platform, Vector2i(100, 168))
	Sim.step(1)
	assert_eq(platform.rider_mask, 0)
	p1.sim_pos = Vector2i(92, 163)
	Sim.step(1)
	assert_true(platform.ridden)
	assert_eq(platform.rider_mask, 1)
	assert_eq(platform.rider_count(), 1)
	assert_eq(platform.rider_weight(), PartyTuning.PLATE_WEIGHT_HERO)
	p1.sim_pos = Vector2i(92, 163)
	p2.sim_pos = Vector2i(108, 163)
	Sim.step(1)
	assert_eq(platform.rider_mask, 3, "both slots")
	assert_eq(platform.rider_count(), 2)
	assert_eq(platform.rider_weight(), 2 * PartyTuning.PLATE_WEIGHT_HERO)


func test_the_party_driver_registers_after_the_heroes_and_takes_their_deaths() -> void:
	var made: LevelBase = make_flat_level(48, 16, 10)
	var p1: PlayerBase = PlayerBase.new()
	place(made, p1, Vector2i(92, 160))
	var p2: PlayerBase = PlayerBase.new()
	place(made, p2, Vector2i(108, 160), {"slot": 1})
	assert_eq(made.hero_count(), 2)
	assert_null(made.party_driver)
	var driver: RecordingDriver = RecordingDriver.new()
	made.register_party_driver(driver)
	assert_eq(made.party_driver, driver)
	assert_true(driver.is_inside_tree(), "the level adds the driver")
	var other: RecordingDriver = RecordingDriver.new()
	made.register_party_driver(other)
	assert_eq(made.party_driver, driver, "the first driver stays")
	other.free()
	var lives: int = Game.lives
	p2.dead = true
	made.hero_death_finished(p2)
	assert_eq(driver.deaths, [p2] as Array[PlayerBase], "the driver is asked first")
	assert_eq(Game.lives, lives, "and took the death")
	driver.handled = false
	made.hero_death_finished(p2)
	assert_eq(driver.deaths.size(), 2)
	assert_eq(Game.lives, lives, "the neutral default: P1 still plays")
	driver.free()
	assert_null(made.party_driver, "a freed driver is forgotten")
