extends TestCase
## The base classes working together in a bare LevelBase: this is also the smallest example of how a module can
## test its entities without the world module (ARCHITECTURE.md 9.1).

var _level: LevelBase = null
var _hero: PlayerBase = null


func before_each() -> void:
	Game.new_game(Defs.Difficulty.BEGINNER)
	Game.begin_level(&"test")
	_level = make_flat_level(40, 16, 10)
	_hero = PlayerBase.new()
	place(_level, _hero, Vector2i(100, 160))


func test_level_registers_itself_and_its_entities() -> void:
	assert_eq(Game.level, _level)
	assert_eq(_level.player, _hero)
	assert_eq(_level.get_kind(Defs.Kind.PLAYER).size(), 1)
	var enemy: EnemyBase = EnemyBase.new()
	place(_level, enemy, Vector2i(160, 160), {"name": "bob", "hp": 60, "score": 2})
	assert_eq(_level.get_kind(Defs.Kind.ENEMY).size(), 1)
	assert_eq(_level.find_named(&"bob"), enemy)
	assert_eq(enemy.hp, 60)
	enemy.free()
	assert_eq(_level.get_kind(Defs.Kind.ENEMY).size(), 0)
	assert_null(_level.find_named(&"bob"))
	assert_true(_level.is_in_group(Defs.GROUP_LEVEL))
	assert_eq(_level.grid.floor_at(3, 10), TileGrid.FLOOR_SOLID)
	assert_eq(_level.get_cell(3, 9), TileGrid.CH_AIR)


func test_on_screen_flags_follow_the_view() -> void:
	var near: EnemyBase = EnemyBase.new()
	var far: EnemyBase = EnemyBase.new()
	place(_level, near, Vector2i(200, 160))
	place(_level, far, Vector2i(600, 160))
	Sim.step(1)
	assert_true(near.on_screen)
	assert_false(far.on_screen)
	assert_true(_level.is_in_view(near))
	assert_false(_level.is_in_view(far))
	assert_true(_level.is_in_view(far, 400), "margin grows the view")
	assert_eq(_level.get_camera_cell(), Vector2i(0, 0))


func test_enemy_slots_hits_and_death() -> void:
	var enemy: EnemyBase = EnemyBase.new()
	place(_level, enemy, Vector2i(160, 160), {"hp": 40, "score": 3})
	assert_false(enemy.awake)
	assert_false(enemy.take_hit(25, _hero), "a sleeping enemy cannot be hit")
	Sim.step(2)
	assert_true(enemy.awake, "woken when its anchor is near the view")
	assert_eq(_level.active_enemies, 1)
	assert_true(enemy.is_targetable())
	assert_true(enemy.take_hit(25, _hero))
	assert_eq(enemy.hp, 15)
	assert_false(enemy.dead)
	assert_eq(enemy.on_bounced(_hero), 0)
	assert_eq(enemy.on_bounced(_hero), 2, "every second bounce shows the multiplier")
	assert_true(enemy.take_hit(25, _hero))
	assert_true(enemy.dead, "dies when hit points drop below zero")
	assert_eq(Game.score, 500 * 2, "ladder value x bounce multiplier")
	assert_eq(_level.active_enemies, 0)
	_level.reset_entities()
	assert_false(enemy.dead, "enemies come back when the hero respawns")
	assert_eq(enemy.hp, 40)


func test_hero_damage_and_respawn_flow() -> void:
	var died: Array[StringName] = []
	var on_died: Callable = func(cause: StringName) -> void: died.append(cause)
	Events.player_died.connect(on_died)
	_hero.xvel = 80
	assert_true(_hero.hurt(null))
	assert_eq(Game.hearts, 2)
	assert_eq(_hero.hit_timer, Tuning.HIT_TIMER)
	assert_eq(_hero.yvel, Tuning.HURT_YVEL)
	assert_eq(_hero.xvel, -320, "thrown back against his own motion: xvel = -(xvel * 4)")
	assert_false(_hero.hurt(null), "immune while hit_timer > 0")
	_hero.kill(&"spikes")
	assert_true(_hero.dead)
	Events.player_died.disconnect(on_died)
	assert_eq(died, [&"spikes"] as Array[StringName])
	Game.set_checkpoint(Vector2i(320, 160))
	Events.player_death_finished.emit()
	assert_eq(Game.lives, Tuning.LIVES_START - 1)
	assert_false(_hero.dead)
	assert_eq(_hero.sim_pos, Vector2i(320, 160), "respawns at the active checkpoint")
	assert_eq(Game.hearts, Tuning.ENERGY_START)
	assert_eq(_hero.hit_timer, 0)


func test_boss_body_hit_costs_a_bone() -> void:
	var boss: BossBase = BossBase.new()
	place(_level, boss, Vector2i(140, 160), {"hp": 64, "arena": "pit"})
	assert_eq(boss.get_max_pips(), 8)
	assert_eq(_level.get_kind(Defs.Kind.BOSS).size(), 1)
	assert_eq(_level.get_kind(Defs.Kind.ENEMY).size(), 0, "bosses are not in the ordinary enemy list")
	assert_true(boss.touch_hero(_hero))
	assert_eq(Game.hearts, 2)
	assert_eq(Game.bones, 5)
	assert_eq(_hero.xvel, -Tuning.BOSS_KNOCK_XVEL, "knocked away from the boss")
	assert_eq(_hero.ice, Tuning.ICE_MAX)
	assert_eq(boss.arena, &"pit")


func test_shake_nudges_the_hero_on_odd_ticks() -> void:
	Sim.start(1)
	_level.request_shake(Tuning.SHAKE_LANDING)
	var y: int = _hero.sim_pos.y
	Sim.step(1)
	assert_eq(_hero.sim_pos.y, y - Tuning.SHAKE_NUDGE, "tick 1 (odd): lifted 3 px")
	assert_eq(_level.shake_offset, Tuning.SHAKE_LANDING + 1)
	Sim.step(1)
	assert_eq(_hero.sim_pos.y, y - Tuning.SHAKE_NUDGE, "tick 2 (even): nothing")
	assert_eq(_level.shake_offset, 0)
	_hero.state = Defs.HeroState.CROUCH
	Sim.step(1)
	assert_eq(_hero.sim_pos.y, y - Tuning.SHAKE_NUDGE, "crouching resists the earthquake")
	Sim.stop()


func test_collectible_checkpoint_and_exit() -> void:
	Game.add_completion_totals(0, 1)
	var item: CollectibleBase = CollectibleBase.new()
	item.item_id = &"items/food"
	item.points = 300
	item.counts_for_completion = true
	place(_level, item, Vector2i(104, 160), {"index": 13})
	var checkpoint: CheckpointBase = CheckpointBase.new()
	place(_level, checkpoint, Vector2i(96, 160))
	var exit: LevelExitBase = LevelExitBase.new()
	place(_level, exit, Vector2i(300, 160), {"locked": true})
	assert_false(exit.is_open(), "a locked exit needs the fire-starter")
	Sim.step(1)
	assert_true(item.collected)
	assert_eq(Game.score, 300)
	assert_eq(Game.completion_percent(), 100)
	assert_eq(Game.tally_count(), 1)
	assert_true(checkpoint.active)
	assert_eq(Game.checkpoint_pos, _hero.sim_pos, "the HERO's position is stored")
	Game.unlock_exit()
	assert_true(exit.is_open())
	assert_false(exit.used, "not touched yet")


func test_hittable_rule_and_cooldown() -> void:
	Game.add_completion_totals(1, 0)
	var spot: HittableBase = HittableBase.new()
	place(_level, spot, Vector2i(136, 160), {"kind": "small", "count": 2})
	assert_eq(spot.cell, Vector2i(8, 9), "cell containing the point just above the feet")
	# Forward front box of a hero standing at (110, 160): origin (133, 158).
	assert_true(spot.is_hit_by(Vector2i(133, 158)))
	assert_false(spot.is_hit_by(Vector2i(170, 158)), "more than one tile away horizontally")
	assert_false(spot.is_hit_by(Vector2i(133, 118)), "16 px or more away vertically")
	assert_true(spot.take_hit(25, _hero))
	assert_eq(spot.hits_left, 1)
	assert_true(spot.take_hit(25, _hero), "a hit during the cooldown is consumed without effect")
	assert_eq(spot.hits_left, 1)
	Sim.step(Tuning.HIDDEN_SPOT_HIT_COOLDOWN)
	assert_true(spot.take_hit(25, _hero))
	assert_true(spot.opened)
	assert_eq(Game.completion_percent(), 100)
	assert_false(spot.take_hit(25, _hero), "an opened spot no longer consumes weapon boxes")


func test_platform_carries_the_hero() -> void:
	var platform: PlatformBase = PlatformBase.new()
	place(_level, platform, Vector2i(100, 168))
	Sim.step(1)
	assert_true(platform.on_screen)
	assert_false(platform.ridden, "standing exactly on the top edge is not an overlap yet")
	_hero.sim_pos = Vector2i(100, 163)
	_hero.jump_ticks = 5
	Sim.step(1)
	assert_true(platform.ridden)
	assert_true(_hero.on_platform)
	assert_eq(_hero.jump_ticks, 0)
	assert_eq(_hero.sim_pos.y, 161, "feet rest 1 px inside the platform top (168 - 8 + 1), PHYSICS.md 11.4")
	assert_eq(_hero.yvel, 1)
	Sim.step(1)
	assert_true(platform.ridden, "and that keeps him on it")
	_hero.yvel = -32
	Sim.step(1)
	assert_false(platform.ridden, "rising through a platform is ignored (one-way)")


func test_spawner_naming_convention() -> void:
	assert_eq(Spawner.scene_path(&"enemies/walker"), "res://scenes/enemies/walker.tscn")
	assert_eq(Spawner.category(&"enemies/walker"), "enemies")
	assert_eq(Spawner.category(&"nonsense"), "")
	assert_true(Spawner.is_prop(&"props/jungle/bush_big"))
	assert_eq(Spawner.prop_texture_path(&"props/jungle/bush_big"), "res://assets/tiles/jungle/props/bush_big.png")
	assert_true(Spawner.exists(&"props/jungle/bush_big"), "prop textures are found by convention")
	assert_false(Spawner.exists(&"enemies/does_not_exist"))
	assert_false(Spawner.exists(&"wrongcategory/thing"))
	expect_errors(0)
	Spawner.clear_cache()
