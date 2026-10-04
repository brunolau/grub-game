extends TestCase
## Shared fixture of the enemies tests (no tests of its own): a bare level with a movable view, a still hero
## (PlayerBase: it never moves by itself) and spawning by entity id, exactly as the level does it.

## A bare level whose view can be moved (the base LevelBase always shows 0, 0 - 320 x 180).
class ViewLevel:
	extends LevelBase

	var view: Rect2i = Rect2i(0, 0, Tuning.VIEW_W, Tuning.VIEW_H)

	func get_view_rect() -> Rect2i:
		return view


var _level: ViewLevel = null
var _hero: PlayerBase = null


func before_each() -> void:
	Game.new_game(Defs.Difficulty.BEGINNER)
	Game.begin_level(&"test")
	Sim.rng.reseed(1)
	_level = null
	_flat_level(60, 16, 10)


## Spawn an entity scene by id into the test level (like LevelBase.spawn, but at once and owned by the test).
func _spawn(id: StringName, pos: Vector2i, params: Dictionary = {}) -> SimEntity:
	var entity: SimEntity = Spawner.instantiate(id) as SimEntity
	place(_level, entity, pos, params)
	return entity


func _enemy(id: StringName, pos: Vector2i, params: Dictionary = {}) -> EnemyBase:
	return _spawn(id, pos, params) as EnemyBase


## `cols` x `rows` tiles, solid from `ground_row` down.
func _flat_level(cols: int, rows: int, ground_row: int) -> ViewLevel:
	var lines: PackedStringArray = PackedStringArray()
	for row: int in rows:
		lines.append((TileGrid.CH_SOLID_A if row >= ground_row else TileGrid.CH_AIR).repeat(cols))
	return _rows_level(lines)


## A level from tile rows (level-file legend), replacing the current one, with a new hero at (40, 160).
func _rows_level(lines: PackedStringArray) -> ViewLevel:
	if _level != null and is_instance_valid(_level):
		_level.free()
	var level: ViewLevel = ViewLevel.new()
	level.level_id = &"test"
	level.grid = TileGrid.from_rows(lines)
	add_node(level)
	_level = level
	_hero = PlayerBase.new()
	place(_level, _hero, Vector2i(40, 160))
	return level


## Every entity of a kind that came from the scene of `id`.
func _of_scene(kind: int, id: StringName) -> Array[SimEntity]:
	var result: Array[SimEntity] = []
	for entity: SimEntity in _level.get_kind(kind):
		if entity.scene_file_path == Spawner.scene_path(id) and is_instance_valid(entity):
			result.append(entity)
	return result
