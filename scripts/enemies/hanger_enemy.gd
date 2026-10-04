class_name HangerEnemy
extends EnemyBase
## Base of the enemies that hang on a thread (yo-yo dangler, ceiling dropper, pendulum; GAMEPLAY.md 5.2 types 2-4).
##
## The thread hangs from the ceiling above the anchor (or from the top of the anchor cell when there is no ceiling
## within EnemyTuning.THREAD_SEARCH_ROWS) down to the top of the body. It is purely cosmetic: it is drawn every
## rendered frame from the interpolated position, behind the sprite.

## True while the thread is drawn.
var _thread_on: bool = false
## Attach point of the thread (logical px).
var _thread_top: Vector2i = Vector2i.ZERO
var _thread_drawn: bool = false


func _process(_delta: float) -> void:
	if _thread_on or _thread_drawn:
		queue_redraw()


func _draw() -> void:
	_thread_drawn = _thread_on and visible and not dead
	if not _thread_drawn:
		return
	var top: Vector2 = Vector2(_thread_top) * float(Tuning.ART_SCALE) - position
	var end: Vector2 = Vector2(0.0, -float(_thread_end_art()))
	draw_line(top, end, EnemyTuning.THREAD_COLOR, EnemyTuning.THREAD_WIDTH)


## Where the thread meets the body, in art px above the feet point.
func _thread_end_art() -> int:
	var height: int = _skin.body_height if _skin != null else box_h * Tuning.ART_SCALE
	return maxi(height - EnemyTuning.THREAD_OVERLAP_ART, 0)


## Find the ceiling above the anchor and put the attach point under it, centred on the anchor column.
func _find_thread_top() -> Vector2i:
	var anchor_row: int = Tuning.to_cell(spawn_pos.y - 1)
	var top_y: int = anchor_row * Tuning.TILE
	var level: LevelBase = Game.level
	if level != null:
		var col: int = Tuning.to_cell(spawn_pos.x)
		for row: int in range(anchor_row - 1, anchor_row - 1 - EnemyTuning.THREAD_SEARCH_ROWS, -1):
			if row < 0:
				top_y = 0
				break
			if level.grid.ceiling_at(col, row) != TileGrid.CEILING_NONE \
					or level.grid.side_at(col, row) != TileGrid.SIDE_OPEN \
					or level.grid.floor_at(col, row) != TileGrid.FLOOR_EMPTY:
				top_y = (row + 1) * Tuning.TILE
				break
	return Vector2i(spawn_pos.x, top_y)
