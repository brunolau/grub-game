extends "res://tests/test_enemies_case.gd"
## Shared enemy rules (EnemyBase, GAMEPLAY.md 5.1 / 12.2): activation slots, wake / sleep, hits and hit points,
## flash and knock-back, death arc, stolen heart, grenade, feast food swap, Expert-only flag, level reset, ground
## physics.


func test_wakes_near_the_view_and_takes_a_slot() -> void:
	var near: EnemyBase = _enemy(&"enemies/walker", Vector2i(200, 160))
	var far: EnemyBase = _enemy(&"enemies/walker", Vector2i(700, 160))
	assert_false(near.visible, "asleep records are hidden")
	Sim.step(1)
	assert_true(near.awake, "anchor inside the view")
	assert_true(near.visible)
	assert_false(far.awake, "anchor far outside the view")
	assert_false(far.visible)
	assert_eq(_level.active_enemies, 1)
	var edge: EnemyBase = _enemy(&"enemies/walker", Vector2i(Tuning.VIEW_W + 40, 160))
	Sim.step(1)
	assert_true(edge.awake, "within about 2 tiles of the visible area")
	assert_eq(_level.active_enemies, 2)


func test_at_most_twelve_awake() -> void:
	var enemies: Array[EnemyBase] = []
	for i: int in Tuning.MAX_ACTIVE_ENEMIES + 2:
		enemies.append(_enemy(&"enemies/walker", Vector2i(60 + i * 18, 160)))
	Sim.step(2)
	var awake: int = 0
	for enemy: EnemyBase in enemies:
		awake += 1 if enemy.awake else 0
	assert_eq(awake, Tuning.MAX_ACTIVE_ENEMIES)
	assert_eq(_level.active_enemies, Tuning.MAX_ACTIVE_ENEMIES)
	assert_false(enemies[Tuning.MAX_ACTIVE_ENEMIES].awake, "slots are taken in spawn order")
	enemies[0].kill(&"weapon", _hero)
	Sim.step(1)
	assert_true(enemies[Tuning.MAX_ACTIVE_ENEMIES].awake, "a freed slot is taken by the next record")
	assert_eq(_level.active_enemies, Tuning.MAX_ACTIVE_ENEMIES)


func test_sleeps_when_left_behind_and_waits_until_its_anchor_was_out_of_view() -> void:
	var enemy: EnemyBase = _enemy(&"enemies/walker", Vector2i(200, 160))
	Sim.step(2)
	assert_true(enemy.awake)
	enemy.teleport(Vector2i(800, 160))
	Sim.step(1)
	assert_true(enemy.awake, "the on_screen flag of the previous frame still counts")
	Sim.step(1)
	assert_false(enemy.awake, "not drawn and more than one screen away from the hero")
	assert_eq(enemy.sim_pos, Vector2i(200, 160), "back at its anchor")
	assert_eq(_level.active_enemies, 0)
	Sim.step(5)
	assert_false(enemy.awake, "no pop-in: the anchor is still on screen")
	_level.view = Rect2i(600, 0, Tuning.VIEW_W, Tuning.VIEW_H)
	Sim.step(2)
	assert_false(enemy.awake)
	_level.view = Rect2i(0, 0, Tuning.VIEW_W, Tuning.VIEW_H)
	Sim.step(1)
	assert_true(enemy.awake, "wakes again once its anchor came back into view")


func test_a_close_enemy_never_sleeps_off_screen() -> void:
	var enemy: EnemyBase = _enemy(&"enemies/flyer", Vector2i(200, 100), {"speed": 0})
	_hero.teleport(Vector2i(8, 160))
	Sim.step(2)
	enemy.teleport(Vector2i(Tuning.VIEW_W + 20, 100))
	Sim.step(3)
	assert_false(enemy.on_screen)
	assert_true(enemy.awake, "inside the activation area: no wake / sleep flicker")


func test_hit_points_against_weapon_power() -> void:
	var one: EnemyBase = _enemy(&"enemies/walker", Vector2i(150, 160), {"hp": 24})
	var two: EnemyBase = _enemy(&"enemies/walker", Vector2i(250, 160), {"hp": 25})
	assert_false(one.take_hit(25, _hero), "asleep: cannot be hit")
	Sim.step(2)
	assert_true(one.take_hit(25, _hero))
	assert_true(one.dead, "hp 0..24 dies on one club hit")
	assert_true(two.take_hit(25, _hero))
	assert_false(two.dead, "hp 25 survives the first hit (0 is not below zero)")
	assert_eq(two.hp, 0)
	assert_eq(two.flash, EnemyTuning.FLASH_TICKS, "survivors flash")
	assert_true(two.take_hit(25, _hero))
	assert_true(two.dead)
	assert_false(two.take_hit(25, _hero), "the dead are not targetable")


func test_survivor_is_pushed_back_by_a_quarter_of_its_speed() -> void:
	var enemy: EnemyBase = _enemy(&"enemies/flyer", Vector2i(200, 100), {"hp": 60, "speed": 0})
	Sim.step(2)
	enemy.xvel = 40
	var x: int = enemy.sim_pos.x
	assert_true(enemy.take_hit(25, _hero))
	assert_eq(enemy.sim_pos.x, x - Tuning.shr(40, Tuning.ENEMY_KNOCKBACK_SHIFT))
	enemy.xvel = -40
	x = enemy.sim_pos.x
	enemy.take_hit(25, _hero)
	assert_eq(enemy.sim_pos.x, x - Tuning.shr(-40, Tuning.ENEMY_KNOCKBACK_SHIFT), "floors like the original")


func test_death_arc_pays_the_score_and_falls_off_screen() -> void:
	var enemy: EnemyBase = _enemy(&"enemies/walker", Vector2i(200, 160), {"score": 3})
	Sim.step(2)
	var killed: Array[int] = []
	var on_killed: Callable = func(_e: EnemyBase, points: int, _cause: StringName) -> void: killed.append(points)
	Events.enemy_killed.connect(on_killed)
	enemy.on_bounced(_hero)
	enemy.on_bounced(_hero)
	enemy.kill(&"weapon", _hero)
	Events.enemy_killed.disconnect(on_killed)
	assert_eq(killed, [500 * 2] as Array[int], "ladder value x bounce multiplier")
	assert_eq(Game.score, 1000)
	assert_eq(_level.active_enemies, 0, "the slot is freed at once")
	assert_true(enemy.visible, "the corpse is shown")
	assert_false(enemy.is_targetable())
	var start: Vector2i = enemy.sim_pos
	Sim.step(3)
	assert_true(enemy.sim_pos.x > start.x, "thrown away from the hero (who is on its left)")
	assert_true(enemy.sim_pos.y < start.y, "up first")
	Sim.step(EnemyTuning.DEATH_ARC_MAX_TICKS)
	assert_false(enemy.visible, "gone once it fell off the screen")
	assert_true(enemy.dead)


func test_heart_thief_bursts_into_bones() -> void:
	var enemy: EnemyBase = _enemy(&"enemies/walker", Vector2i(200, 160))
	Sim.step(2)
	enemy.on_hurt_hero(_hero)
	assert_true(enemy.stole_heart)
	var before: int = _level.get_kind(Defs.Kind.COLLECTIBLE).size()
	enemy.kill(&"weapon", _hero)
	assert_false(enemy.visible, "no death arc: it bursts")
	if Spawner.exists(&"items/bone"):
		var bones: int = 0
		for item: SimEntity in _level.get_kind(Defs.Kind.COLLECTIBLE):
			bones += 1 if item.scene_file_path.ends_with("bone.tscn") else 0
		assert_eq(bones, Tuning.BONES_PER_HEART)
		assert_eq(_level.get_kind(Defs.Kind.COLLECTIBLE).size() - before, Tuning.BONES_PER_HEART)


func test_grenade_and_kill_while_asleep() -> void:
	var enemy: EnemyBase = _enemy(&"enemies/walker", Vector2i(200, 160), {"score": 5})
	var asleep: EnemyBase = _enemy(&"enemies/walker", Vector2i(900, 160), {"score": 5})
	Sim.step(2)
	var causes: Array[StringName] = []
	var on_killed: Callable = func(_e: EnemyBase, _p: int, cause: StringName) -> void: causes.append(cause)
	Events.enemy_killed.connect(on_killed)
	enemy.burst_into_items()
	Events.enemy_killed.disconnect(on_killed)
	assert_eq(causes, [&"grenade"] as Array[StringName])
	assert_true(enemy.dead)
	assert_false(enemy.visible)
	assert_eq(Game.score, 0, "the grenade pays no score")
	asleep.kill(&"kill_all")
	assert_true(asleep.dead)
	assert_false(asleep.visible, "an enemy that was not awake leaves no corpse")
	assert_eq(Game.score, 700)


func test_glider_dives_score_and_the_third_kills() -> void:
	var enemy: EnemyBase = _enemy(&"enemies/walker", Vector2i(200, 160))
	Sim.step(2)
	enemy.on_glider_stomp(_hero)
	enemy.on_glider_stomp(_hero)
	assert_false(enemy.dead)
	assert_eq(Game.score, 6000)
	enemy.on_glider_stomp(_hero)
	assert_true(enemy.dead)
	assert_eq(Game.score, 16000 + 100)


func test_bounce_counter_saturates() -> void:
	var enemy: EnemyBase = _enemy(&"enemies/walker", Vector2i(200, 160))
	var shown: Array[int] = []
	for i: int in 14:
		shown.append(enemy.on_bounced(_hero))
	assert_eq(shown, [0, 2, 0, 3, 0, 4, 0, 6, 0, 8, 0, 0, 0, 0] as Array[int], "the counter stops at 11")
	assert_eq(enemy.bounce_count, Tuning.BOUNCE_COUNT_MAX)
	assert_eq(enemy.get_points(), 100 * 8)


func test_feast_turns_enemies_into_food() -> void:
	var enemy: EnemyBase = _enemy(&"enemies/walker", Vector2i(200, 160), {"score": 4})
	Sim.step(2)
	var sprite: Sprite2D = enemy.get_node(^"Sprite")
	assert_true(sprite.visible)
	_hero.feast = Tuning.FEAST_TICKS
	Sim.step(1)
	var food: Sprite2D = enemy.get_node_or_null(^"FeastSprite")
	assert_not_null(food)
	assert_true(food.visible)
	assert_false(sprite.visible)
	assert_eq(food.frame, EnemyTuning.FEAST_FOOD_CELLS[4])
	_hero.feast = 0
	Sim.step(1)
	assert_true(sprite.visible)
	assert_false(food.visible)


func test_expert_only_records() -> void:
	var expert: EnemyBase = _enemy(&"enemies/walker", Vector2i(200, 160), {"expert": true})
	var beginner: EnemyBase = _enemy(&"enemies/walker", Vector2i(260, 160), {"beginner": true})
	Sim.step(3)
	assert_true(expert.expert_only)
	assert_false(expert.awake, "never wakes in Beginner")
	assert_true(beginner.awake)
	Game.new_game(Defs.Difficulty.EXPERT)
	_level.reset_entities()
	Sim.step(3)
	assert_true(expert.awake)
	assert_false(beginner.awake)


func test_level_reset_restores_the_record() -> void:
	var enemy: EnemyBase = _enemy(&"enemies/walker", Vector2i(200, 160), {"hp": 40, "facing": "l"})
	Sim.step(30)
	enemy.take_hit(25, _hero)
	enemy.on_hurt_hero(_hero)
	enemy.on_bounced(_hero)
	assert_ne(enemy.sim_pos, Vector2i(200, 160))
	_level.reset_entities()
	assert_false(enemy.awake)
	assert_eq(enemy.hp, 40)
	assert_eq(enemy.bounce_count, 0)
	assert_false(enemy.stole_heart)
	assert_eq(enemy.sim_pos, Vector2i(200, 160))
	assert_eq(enemy.facing, -1, "the level-file facing comes back")
	enemy.kill(&"weapon", _hero)
	_level.reset_entities()
	assert_false(enemy.dead, "killed enemies come back when the hero respawns")
	Sim.step(1)
	assert_true(enemy.awake)


func test_unknown_skin_falls_back_to_the_default() -> void:
	var enemy: EnemyBase = _enemy(&"enemies/walker", Vector2i(200, 160), {"skin": "no_such_sheet"})
	assert_eq(enemy.skin, "turtle")
	var sprite: Sprite2D = enemy.get_node(^"Sprite")
	assert_eq(sprite.texture.resource_path, "res://assets/sprites/enemies/turtle.png")


func test_ground_physics_gravity_landing_bounce_and_walls() -> void:
	_rows_level(PackedStringArray([
		"....................",
		"....................",
		"....................",
		"....................",
		"....................",
		"....................",
		"....................",
		"....................",
		"..............#.....",
		"..............#.....",
		"####################",
	]))
	var enemy: EnemyBase = _enemy(&"enemies/walker", Vector2i(120, 48), {"speed": 0})
	Sim.step(1)
	var landed_at: int = -1
	var peak_after_landing: int = 1000
	for tick: int in 60:
		Sim.step(1)
		if landed_at < 0 and enemy.sim_pos.y == 160:
			landed_at = tick
		elif landed_at >= 0:
			peak_after_landing = mini(peak_after_landing, enemy.sim_pos.y)
	assert_true(landed_at > 0, "falls with gravity to the floor")
	assert_true(peak_after_landing < 160, "small landing bounce")
	assert_eq(enemy.sim_pos.y, 160, "rests on the floor")
	assert_eq(enemy.yvel, 0)
	var walker: Walker = _enemy(&"enemies/walker", Vector2i(200, 160), {"left": -6, "right": 12, "speed": 32}) as Walker
	for tick: int in 60:
		Sim.step(1)
		assert_true(walker.sim_pos.x + (walker.box_w >> 1) <= 14 * Tuning.TILE + 1, "never inside the wall")
	assert_true(walker.sim_pos.x < 200, "turned round at the wall")


func test_expert_uses_the_second_palette_by_default() -> void:
	Game.new_game(Defs.Difficulty.EXPERT)
	var walker: EnemyBase = _enemy(&"enemies/walker", Vector2i(200, 160))
	var chosen: EnemyBase = _enemy(&"enemies/walker", Vector2i(240, 160), {"skin": "turtle"})
	var swinger: EnemyBase = _enemy(&"enemies/swinger", Vector2i(280, 100))
	assert_eq(walker.skin, "turtle_b", "the `_b` palette in Expert")
	assert_eq(chosen.skin, "turtle", "a skin given by the level wins")
	assert_eq(swinger.skin, "bat_b", "sheets without a second palette keep their default")
