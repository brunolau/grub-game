class_name Dropper
extends SpawnerEnemy
## `enemies/dropper` - archetype 0, sky dropper (GAMEPLAY.md 5.2): while the hero is inside the trigger rectangle,
## copies appear above the screen EnemyTuning.DROPPER_SIDE_PX to the right and to the left of him (alternating),
## wait `pause` ticks, fall (rolled up as an egg), land with a small bounce and walk toward the side the hero was on
## at `speed` with gravity and wall turns.
##
## Parameters: `zone=c,r,w,h` trigger in tiles [10 tiles around the anchor], `pause` ticks [44], `speed` v16 [32],
## `max` copies alive [2], `skin` [egg_kid], `hp` [25], `score` [1].

enum State { WAIT, FALL, LAND, WALK }

## Walking speed, v16 (level parameter `speed`).
var speed: int = EnemyTuning.DROPPER_SPEED

var _zone: Rect2i = Rect2i()
var _state: int = State.WAIT
var _timer: int = 0
var _side: int = 1


func _default_skin() -> String:
	return "egg_kid"


func _apply_params(params: Dictionary) -> void:
	score_index = EnemyTuning.SCORE_DROPPER
	max_alive = EnemyTuning.DROPPER_MAX_ALIVE
	pause = EnemyTuning.DROPPER_PAUSE
	super._apply_params(params)
	speed = absi(int(params.get("speed", speed)))
	_zone = _zone_from_params(params)


func _copy_id() -> StringName:
	return &"enemies/dropper"


func _first_cooldown() -> int:
	return 0


func _triggered(hero_node: PlayerBase) -> bool:
	return Overlap.point_in(_zone, hero_node.sim_pos.x, hero_node.sim_pos.y)


func _trigger_area() -> Rect2i:
	return _zone


## Above the top of the view, 192 px to one side of the hero (the other side next time); falls back to the other
## side when that column is inside rock or outside the level. A party: beside the hero who triggered it, above the
## view he is drawn in (LevelBase.get_view_rect_of; one view: the view).
func _pick_spawn(hero_node: PlayerBase) -> bool:
	var level: LevelBase = Game.level
	var top: int = level.get_view_rect_of(hero_node).position.y - EnemyTuning.DROPPER_ABOVE_VIEW_PX
	for _attempt: int in 2:
		_side = -_side
		var x: int = hero_node.sim_pos.x + _side * EnemyTuning.DROPPER_SIDE_PX
		if x < Tuning.X_MIN or x >= level.grid.x_max_excl():
			continue
		var col: int = Tuning.to_cell(x)
		var row: int = Tuning.to_cell(top - 1)
		var open: bool = level.grid.side_at(col, row) == TileGrid.SIDE_OPEN
		if open and level.grid.floor_at(col, row) == TileGrid.FLOOR_EMPTY:
			_spawn_at = Vector2i(x, top)
			return true
	return false


func _on_wake() -> void:
	_state = State.WAIT
	_timer = pause
	xvel = 0
	yvel = 0
	var hero: PlayerBase = _target_hero()
	facing = _dir_to(hero) if hero != null else facing
	_play(&"roll")


func _ai_tick() -> void:
	match _state:
		State.WAIT:
			if _timer > 0:
				_timer -= 1
				return
			_state = State.FALL
		State.FALL:
			if _ground_step(false, true):
				_state = State.LAND
				_timer = EnemyTuning.DROPPER_LAND_TICKS
				_play(&"land")
				Audio.play_sfx(Sfx.ENEMY_VOICE)
		State.LAND:
			_timer -= 1
			if _timer <= 0:
				var hero: PlayerBase = _target_hero()
				facing = _dir_to(hero) if hero != null else facing
				xvel = speed * facing
				_state = State.WALK
				_play(&"walk")
		State.WALK:
			var grounded: bool = _ground_step(false, true)
			if xvel != 0:
				facing = signi(xvel)
			_play(&"walk" if grounded else &"air")
