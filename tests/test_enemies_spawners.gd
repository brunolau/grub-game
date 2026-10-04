extends "res://tests/test_enemies_case.gd"
## Zone spawners (GAMEPLAY.md 5.1 / 5.2 types 0, 10, 11): the record keeps producing one-shot copies with a pause,
## at most `max` alive; killing the copies never stops it; the hero's respawn removes the copies.


func test_dropper_drops_from_the_sky_and_walks() -> void:
	var record: Dropper = _enemy(&"enemies/dropper", Vector2i(200, 160)) as Dropper
	Sim.step(1)
	assert_false(record.awake, "the record itself never shows up")
	assert_eq(record.alive_copies(), 1, "the hero is inside the default zone")
	var copies: Array[SimEntity] = _copies(&"enemies/dropper")
	assert_eq(copies.size(), 1)
	var copy: Dropper = copies[0] as Dropper
	assert_true(copy.is_copy())
	assert_true(copy.awake, "takes a slot at once")
	assert_true(copy.one_shot)
	assert_eq(copy.sim_pos, Vector2i(40 + EnemyTuning.DROPPER_SIDE_PX, -EnemyTuning.DROPPER_ABOVE_VIEW_PX),
			"above the view, 192 px beside the hero (the left side is outside the level)")
	Sim.step(EnemyTuning.DROPPER_PAUSE + 1)
	assert_eq(copy.sim_pos.y, -EnemyTuning.DROPPER_ABOVE_VIEW_PX, "waits `pause` ticks")
	assert_eq(record.alive_copies(), 2, "the second copy after the pause")
	var landed: bool = false
	for tick: int in 80:
		Sim.step(1)
		if copy.xvel != 0:
			landed = true
			break
	assert_true(landed)
	assert_eq(copy.sim_pos.y, 160, "fell to the floor")
	assert_eq(copy.xvel, -EnemyTuning.DROPPER_SPEED, "walks toward the side the hero is on")
	Sim.step(100)
	assert_eq(record.alive_copies(), 2, "never more than `max`")
	copy.kill(&"weapon", _hero)
	_step_until_freed(copy, EnemyTuning.DEATH_ARC_MAX_TICKS)
	assert_true(copy.is_queued_for_deletion(), "a dead copy is freed")
	assert_eq(record.alive_copies(), 1)
	Sim.step(EnemyTuning.DROPPER_PAUSE + 1)
	assert_eq(record.alive_copies(), 2, "killing copies never stops the record")


func test_dropper_respects_its_zone_and_the_reset() -> void:
	var record: Dropper = _enemy(&"enemies/dropper", Vector2i(600, 160), {"zone": "30,0,10,12", "max": 1}) as Dropper
	Sim.step(10)
	assert_eq(record.alive_copies(), 0, "the hero is outside the zone")
	_hero.teleport(Vector2i(500, 160))
	Sim.step(1)
	assert_eq(record.alive_copies(), 1)
	var copy: EnemyBase = _copies(&"enemies/dropper")[0] as EnemyBase
	Sim.step(5)
	_level.reset_entities()
	assert_true(copy.is_queued_for_deletion(), "copies vanish when the hero respawns")
	assert_false(copy.awake)
	assert_eq(record.alive_copies(), 0)
	assert_eq(_level.active_enemies, 0)


func test_digger_rises_walks_and_sinks() -> void:
	var record: Digger = _enemy(&"enemies/digger", Vector2i(200, 160)) as Digger
	_hero.teleport(Vector2i(100, 160))
	Sim.step(EnemyTuning.DIGGER_PAUSE)
	assert_eq(record.alive_copies(), 0, "waits `pause` ticks while the hero is in the zone")
	Sim.step(1)
	assert_eq(record.alive_copies(), 1)
	var copy: Digger = _copies(&"enemies/digger")[0] as Digger
	assert_eq(copy.sim_pos, Vector2i(100 + EnemyTuning.DIGGER_OFFSETS[0], 160), "on the floor at the first offset")
	assert_false(copy.tangible, "intangible while rising")
	Sim.step(EnemyTuning.DIGGER_RISE_TICKS)
	assert_true(copy.tangible, "walks tangible")
	assert_eq(copy.xvel, -EnemyTuning.DIGGER_SPEED, "toward the hero")
	var x: int = copy.sim_pos.x
	Sim.step(10)
	assert_eq(copy.sim_pos.x, x - 20, "2 px per tick")
	Sim.step(EnemyTuning.DIGGER_WALK_TICKS - 10)
	assert_false(copy.tangible, "sinks back")
	Sim.step(EnemyTuning.DIGGER_RISE_TICKS)
	assert_true(copy.is_queued_for_deletion(), "gone after sinking")
	assert_eq(record.alive_copies(), 0)
	Sim.step(EnemyTuning.DIGGER_PAUSE + 3)
	assert_eq(record.alive_copies(), 1, "and the next one comes")


func test_digger_needs_a_floor_with_room_above() -> void:
	var rows: PackedStringArray = PackedStringArray()
	for row: int in 10:
		rows.append(".".repeat(40) if row < 8 else "#".repeat(40))
	rows.append("#".repeat(40))
	_rows_level(rows)
	var record: Digger = _enemy(&"enemies/digger", Vector2i(200, 128), {"pause": 0}) as Digger
	_hero.teleport(Vector2i(100, 128))
	Sim.step(2)
	var copy: Digger = _copies(&"enemies/digger")[0] as Digger
	assert_eq(copy.sim_pos.y, 128, "on top of the ground, never inside it")
	assert_eq(record.alive_copies(), 1)


func test_leaper_defaults() -> void:
	var record: Leaper = _enemy(&"enemies/leaper", Vector2i(200, 160)) as Leaper
	assert_eq(record.speed, EnemyTuning.LEAPER_SPEED)
	assert_eq(record.rise, EnemyTuning.LEAPER_SPEED * EnemyTuning.LEAPER_RISE_FACTOR)
	assert_eq(record.sink, EnemyTuning.LEAPER_SPEED >> EnemyTuning.LEAPER_SINK_SHIFT)
	assert_eq(record.pause, EnemyTuning.LEAPER_PAUSE)
	var slow: Leaper = _enemy(&"enemies/leaper", Vector2i(260, 160), {"speed": 8}) as Leaper
	assert_eq(slow.sink, Tuning.V16_PER_PX, "always sinks at least 1 px per tick")


func test_leaper_leaps_and_glides() -> void:
	_hero.teleport(Vector2i(100, 160))
	var record: Leaper = _enemy(&"enemies/leaper", Vector2i(200, 160), {"speed": 16, "rise": 96, "sink": 24}) as Leaper
	Sim.step(EnemyTuning.LEAPER_PAUSE)
	assert_eq(record.alive_copies(), 0, "after a pause")
	Sim.step(1)
	assert_eq(record.alive_copies(), 1)
	var copy: Leaper = _copies(&"enemies/leaper")[0] as Leaper
	assert_eq(copy.sim_pos.x, 200)
	assert_true(copy.sim_pos.y <= 160 and copy.sim_pos.y > 160 - EnemyTuning.LEAPER_HEIGHT_RANDOM,
			"up to 63 px above its anchor")
	assert_false(copy.tangible, "poised")
	Sim.step(EnemyTuning.LEAPER_POISE_TICKS)
	assert_true(copy.tangible)
	assert_eq(copy.xvel, -16, "toward the hero")
	assert_eq(copy.yvel, -96)
	var yvels: Array[int] = []
	for tick: int in 20:
		Sim.step(1)
		yvels.append(copy.yvel)
	assert_eq(yvels[0], -96 + Tuning.ENEMY_SOFT_GRAVITY, "soft gravity")
	assert_eq(yvels[1], -96 + 2 * Tuning.ENEMY_SOFT_GRAVITY)
	assert_eq(yvels[19], 24, "glides at the sink cap")
	var landed: bool = false
	for tick: int in 200:
		Sim.step(1)
		if copy.yvel == 0 and copy.sim_pos.y == 160:
			landed = true
			break
	assert_true(landed, "comes down on the floor and rests")
	Sim.step(EnemyTuning.LEAPER_REST_TICKS)
	assert_eq(copy.yvel, -96, "then leaps again")
	_level.view = Rect2i(2000, 0, Tuning.VIEW_W, Tuning.VIEW_H)
	_step_until_freed(copy, 200)
	assert_true(copy.is_queued_for_deletion(), "gone once it left the view")
	assert_eq(record.alive_copies(), 0)


func test_leaper_falls_back_into_its_pit() -> void:
	var rows: PackedStringArray = PackedStringArray()
	for row: int in 10:
		rows.append(".".repeat(40))
	rows.append("#".repeat(12) + "~".repeat(4) + "#".repeat(24))
	_rows_level(rows)
	var params: Dictionary = {"speed": 0, "rise": 96, "pause": 0}
	var record: Leaper = _enemy(&"enemies/leaper", Vector2i(13 * Tuning.TILE + 8, 160), params) as Leaper
	Sim.step(2)
	var copy: Leaper = _copies(&"enemies/leaper")[0] as Leaper
	_step_until_freed(copy, 150)
	assert_true(copy.is_queued_for_deletion(), "a straight leap ends back in the liquid")
	assert_true(copy.sim_pos.y >= 160)
	assert_eq(record.alive_copies(), 0)


func _copies(id: StringName) -> Array[SimEntity]:
	var result: Array[SimEntity] = []
	for entity: SimEntity in _of_scene(Defs.Kind.ENEMY, id):
		var spawner: SpawnerEnemy = entity as SpawnerEnemy
		if spawner != null and spawner.is_copy():
			result.append(entity)
	return result


func _step_until_freed(entity: SimEntity, max_ticks: int) -> void:
	for tick: int in max_ticks:
		if entity.is_queued_for_deletion():
			return
		Sim.step(1)
