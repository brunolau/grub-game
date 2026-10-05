class_name Digger
extends SpawnerEnemy
## `enemies/digger` - archetype 10, burrower zone spawner (GAMEPLAY.md 5.2): while the hero is inside the trigger
## rectangle (and after `pause` ticks) a copy rises out of a valid floor at one of eight offsets around him
## (-120 .. +120 px, used in turn), intangible while it rises, walks at `speed` for about 120 ticks with ground
## physics and wall turns, sinks back intangible and is gone; then the next one comes.
## Rising and sinking reveal the sprite bottom-up with a region of its frame (ASSET_MANIFEST.md 2).
##
## Parameters: `zone=c,r,w,h` trigger in tiles [10 tiles around the anchor], `pause` ticks [44], `speed` v16 [32],
## `max` copies alive [1], `skin` [lizard], `hp` [25], `score` [2].

enum State { RISE, WALK, SINK }

## Walking speed, v16 (level parameter `speed`).
var speed: int = EnemyTuning.DIGGER_SPEED

var _zone: Rect2i = Rect2i()
var _state: int = State.RISE
var _timer: int = 0
var _offset_index: int = 0
## Visible height of the body in art px while rising / sinking; -1 = the whole sprite.
var _reveal: int = -1


func _default_skin() -> String:
	return "lizard"


func _apply_params(params: Dictionary) -> void:
	score_index = EnemyTuning.SCORE_DIGGER
	pause = EnemyTuning.DIGGER_PAUSE
	super._apply_params(params)
	speed = absi(int(params.get("speed", speed)))
	_zone = _zone_from_params(params)


func _copy_id() -> StringName:
	return &"enemies/digger"


func _triggered(hero_node: PlayerBase) -> bool:
	return Overlap.point_in(_zone, hero_node.sim_pos.x, hero_node.sim_pos.y)


func _trigger_area() -> Rect2i:
	return _zone


func _on_reset() -> void:
	_offset_index = 0


## A floor cell with two free cells above it, searched upward from a few rows below the hero at the next offset.
func _pick_spawn(hero_node: PlayerBase) -> bool:
	var grid: TileGrid = Game.level.grid
	var offset: int = EnemyTuning.DIGGER_OFFSETS[_offset_index % EnemyTuning.DIGGER_OFFSETS.size()]
	_offset_index += 1
	var x: int = hero_node.sim_pos.x + offset
	if x < Tuning.X_MIN or x >= grid.x_max_excl():
		return false
	var col: int = Tuning.to_cell(x)
	var start: int = Tuning.to_cell(hero_node.sim_pos.y) + EnemyTuning.DIGGER_SCAN_BELOW_ROWS
	for row: int in range(start, start - EnemyTuning.DIGGER_SCAN_ROWS, -1):
		if row < 2 or row >= grid.rows:
			continue
		if not TileGrid.is_ground(grid.floor_at(col, row)) or grid.profile_at(col, row) > TileGrid.PROFILE_FLAT_GLUE:
			continue
		if _is_free(grid, col, row - 1) and _is_free(grid, col, row - 2):
			_spawn_at = Vector2i(x, row * Tuning.TILE)
			return true
	return false


func _on_wake() -> void:
	_state = State.RISE
	_timer = 0
	tangible = false
	xvel = 0
	yvel = 0
	_reveal = 0
	var hero: PlayerBase = _target_hero()
	facing = _dir_to(hero) if hero != null else facing
	_play(&"idle")


func _ai_tick() -> void:
	var height: int = _skin.body_height if _skin != null else box_h * Tuning.ART_SCALE
	match _state:
		State.RISE:
			_timer += 1
			_reveal = height * _timer / EnemyTuning.DIGGER_RISE_TICKS
			if _timer >= EnemyTuning.DIGGER_RISE_TICKS:
				_reveal = -1
				tangible = true
				_state = State.WALK
				_timer = EnemyTuning.DIGGER_WALK_TICKS
				xvel = speed * facing
				_play(&"walk")
		State.WALK:
			_ground_step(false, false)
			if xvel != 0:
				facing = signi(xvel)
			_timer -= 1
			if _timer <= 0 and _grounded:
				_state = State.SINK
				_timer = EnemyTuning.DIGGER_RISE_TICKS
				tangible = false
				xvel = 0
				_play(&"idle")
		State.SINK:
			_timer -= 1
			_reveal = height * _timer / EnemyTuning.DIGGER_RISE_TICKS
			if _timer <= 0:
				sleep()


## Draw only the top `_reveal` art px of the frame while it is in the ground.
func _refresh_visual() -> void:
	if _sprite != null and _skin != null and _reveal < 0 and _sprite.region_enabled:
		_sprite.region_enabled = false
		_sprite.hframes = _skin.columns
		_sprite.vframes = _skin.rows
		_sprite.offset = _skin.sprite_offset()
	super._refresh_visual()
	if _sprite == null or _skin == null or _reveal < 0:
		return
	var frame: int = _anim.x + _anim_step()
	var cell_x: float = float((frame % _skin.columns) * _skin.cell.x)
	var cell_y: float = float((frame / _skin.columns) * _skin.cell.y)
	_sprite.frame = 0
	_sprite.hframes = 1
	_sprite.vframes = 1
	_sprite.region_enabled = true
	_sprite.region_rect = Rect2(
		cell_x, cell_y + float(_skin.pivot.y - _reveal), float(_skin.cell.x), float(_reveal)
	)
	_sprite.offset = Vector2(-float(_skin.pivot.x), -float(_reveal))


static func _is_free(grid: TileGrid, col: int, row: int) -> bool:
	return grid.floor_at(col, row) == TileGrid.FLOOR_EMPTY and grid.side_at(col, row) == TileGrid.SIDE_OPEN
