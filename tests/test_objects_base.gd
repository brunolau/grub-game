class_name ObjectsTestCase
extends TestCase
## Shared set-up of the objects module's tests (no test methods of its own): a bare level that records what the
## objects ask of it, a bare hero, and helpers to spawn entities by id and to count what is in the level.


## A bare LevelBase that records the calls the world module would turn into visuals or flow.
class RecordingLevel:
	extends LevelBase

	## Exit kinds passed to complete(), in order.
	var completed_kinds: Array[StringName] = []
	## Cell -> atlas index of the last set_cell_look() for that cell.
	var looks: Dictionary = {}
	## Number of snap_camera() calls.
	var snaps: int = 0

	func complete(exit_kind: StringName) -> void:
		if completed:
			return
		completed = true
		completed_kinds.append(exit_kind)

	func set_cell_look(col: int, row: int, atlas_index: int) -> void:
		looks[Vector2i(col, row)] = atlas_index

	func snap_camera() -> void:
		snaps += 1


## Counts warnings and errors while it is attached (OS.add_logger).
class LogCounter:
	extends Logger

	var warnings: int = 0
	var errors: int = 0

	func _log_error(
			_function: String, _file: String, _line: int, _code: String, _rationale: String, _editor_notify: bool,
			error_type: int, _script_backtraces: Array[ScriptBacktrace]
	) -> void:
		if error_type == Logger.ERROR_TYPE_WARNING:
			warnings += 1
		else:
			errors += 1

	func _log_message(_message: String, _error: bool) -> void:
		pass


var level: RecordingLevel = null
var hero: PlayerBase = null


func before_each() -> void:
	Game.new_game(Defs.Difficulty.BEGINNER)
	Game.begin_level(&"test_objects")
	Sim.start(1)


func after_each() -> void:
	Sim.stop()


## A recording level from tile rows (level-file legend), jungle biome, that becomes Game.level.
func make_recording_level(tile_rows: PackedStringArray, biome: String = "jungle") -> RecordingLevel:
	var made: RecordingLevel = RecordingLevel.new()
	made.level_id = &"test_objects"
	made.meta = {"biome": biome, "world": 1}
	made.grid = TileGrid.from_rows(tile_rows)
	add_node(made)
	level = made
	return made


## A recording level of `cols` x `rows` tiles, solid ('#') from `ground_row` down.
func make_ground_level(cols: int = 40, rows: int = 16, ground_row: int = 10) -> RecordingLevel:
	var lines: PackedStringArray = PackedStringArray()
	for row: int in rows:
		lines.append((TileGrid.CH_SOLID_A if row >= ground_row else TileGrid.CH_AIR).repeat(cols))
	return make_recording_level(lines)


## A bare hero (no controller: he stays where he is put) standing at `pos`.
func add_hero(pos: Vector2i) -> PlayerBase:
	hero = PlayerBase.new()
	place(level, hero, pos)
	hero.respawn_at(pos)
	return hero


## Spawn an entity by id with its feet point at `pos`.
func spawn(id: StringName, pos: Vector2i, params: Dictionary = {}) -> Node:
	return level.spawn(id, pos, params)


## Live entities of one kind whose script is `type` (instances queued for deletion are not counted).
func count_alive(kind: int, type: Script = null) -> int:
	var count: int = 0
	for entity: SimEntity in level.get_kind(kind):
		if is_instance_valid(entity) and not entity.is_queued_for_deletion() \
				and (type == null or entity.get_script() == type):
			count += 1
	return count


## Live collectibles with item id `item_id` ("" = any).
func count_items(item_id: StringName = &"") -> int:
	var count: int = 0
	for entity: SimEntity in level.get_kind(Defs.Kind.COLLECTIBLE):
		var item: CollectibleBase = entity as CollectibleBase
		if item != null and not item.is_queued_for_deletion() and not item.collected \
				and (item_id == &"" or item.item_id == item_id):
			count += 1
	return count


## The live collectibles with item id `item_id`.
func items_of(item_id: StringName) -> Array[CollectibleBase]:
	var found: Array[CollectibleBase] = []
	for entity: SimEntity in level.get_kind(Defs.Kind.COLLECTIBLE):
		var item: CollectibleBase = entity as CollectibleBase
		if item != null and not item.is_queued_for_deletion() and not item.collected and item.item_id == item_id:
			found.append(item)
	return found
