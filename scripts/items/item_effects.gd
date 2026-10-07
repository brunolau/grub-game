class_name ItemEffects
extends RefCounted
## Effects shared by several items (the real pick-ups and the random bonus that can turn into them), and the
## helpers that throw items into the level: fan bursts and drops from the sky.

const ID_BONE: StringName = &"items/bone"
const ID_EXPLOSION: StringName = &"fx/explosion"


## Throw `count` items of entity id `id` from `pos` as a fan burst (bones of a hurt hero, scattered energy).
static func burst(id: StringName, pos: Vector2i, count: int) -> void:
	var level: LevelBase = Game.level
	if level == null:
		return
	for i: int in count:
		level.spawn(id, pos, {"dropped": true, "fan": i})


## Skull (GAMEPLAY.md 4.1): the hurt pose without losing a life, ALL energy thrown out as bones, screen shake.
## Returns false when the hit was not applied (the item then stays).
static func skull(hero: PlayerBase, source: SimEntity) -> bool:
	var level: LevelBase = Game.level
	if level == null:
		return false
	# The energy of the hero it hits (2.0: his PlayerRun; P1's run is Game's, so Game.hearts / bones in 1.0).
	var energy: int = hero.run.hearts * Tuning.BONES_PER_HEART + hero.run.bones
	var items_before: int = level.get_kind(Defs.Kind.COLLECTIBLE).size()
	if not hero.hurt(source, Defs.HurtKind.TRAP):
		return false
	level.request_shake(ObjTuning.SHAKE_SKULL)
	# A hero implementation may scatter the bones itself; only do it here when nothing appeared.
	if level.get_kind(Defs.Kind.COLLECTIBLE).size() == items_before:
		burst(ID_BONE, hero.sim_pos + Vector2i(0, ObjTuning.BONE_SCATTER_DY), energy)
	return true


## Kill-all item (GAMEPLAY.md 4.1): every enemy on screen dies normally and pays its score; strong shake.
## Returns the number of enemies killed.
static func kill_all(hero: PlayerBase) -> int:
	var level: LevelBase = Game.level
	if level == null:
		return 0
	var enemies: Array[SimEntity] = level.get_kind(Defs.Kind.ENEMY)
	var killed: int = 0
	for i: int in range(enemies.size() - 1, -1, -1):
		var enemy: EnemyBase = enemies[i] as EnemyBase
		if enemy != null and enemy.is_targetable():
			level.spawn_fx(ID_EXPLOSION, Vector2i(enemy.sim_pos.x, enemy.sim_pos.y - (enemy.box_h >> 1)))
			enemy.kill(&"kill_all", hero)
			killed += 1
	level.request_shake(ObjTuning.SHAKE_KILL_ALL)
	return killed


## Grenade (GAMEPLAY.md 4.1 / 8.3): every enemy on screen vanishes into Tuning.GRENADE_ITEMS_PER_ENEMY random
## bonus items. Returns the number of enemies hit.
static func grenade() -> int:
	var level: LevelBase = Game.level
	if level == null:
		return 0
	var enemies: Array[SimEntity] = level.get_kind(Defs.Kind.ENEMY)
	var hit: int = 0
	for i: int in range(enemies.size() - 1, -1, -1):
		var enemy: EnemyBase = enemies[i] as EnemyBase
		if enemy != null and enemy.is_targetable():
			level.spawn_fx(ID_EXPLOSION, Vector2i(enemy.sim_pos.x, enemy.sim_pos.y - (enemy.box_h >> 1)))
			enemy.burst_into_items(Tuning.GRENADE_ITEMS_PER_ENEMY)
			hit += 1
	return hit


## Feet y from which something dropped "from the sky" above (`x`, `y`) starts: Tuning.GIANT_BONUS_DROP_PX higher,
## or as high as the open space above that point reaches when a ceiling is in the way.
static func sky_drop_y(x: int, y: int) -> int:
	var level: LevelBase = Game.level
	var top: int = y - Tuning.GIANT_BONUS_DROP_PX
	if level == null:
		return top
	var grid: TileGrid = level.grid
	var col: int = x >> 4
	var row: int = (y - 1) >> 4
	var free_y: int = y
	while free_y > top:
		if grid.ceiling_at(col, row) != TileGrid.CEILING_NONE or grid.floor_at(col, row) != TileGrid.FLOOR_EMPTY:
			break
		free_y = row * Tuning.TILE
		row -= 1
	return maxi(free_y, top)
