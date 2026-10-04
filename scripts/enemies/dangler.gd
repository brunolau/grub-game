class_name Dangler
extends HangerEnemy
## `enemies/dangler` - archetype 2, yo-yo dangler (GAMEPLAY.md 5.2): hangs on a thread from the ceiling above its
## anchor, lowers itself `depth` px at `speed` px per tick, climbs back to the anchor and repeats.
##
## Parameters: `depth` px [48], `speed` px per tick [2], `skin` [bat], `hp` [25], `score` [0].

## How far below the anchor it goes, px (level parameter `depth`).
var depth: int = EnemyTuning.DANGLER_DEPTH
## Thread speed, px per tick (level parameter `speed`).
var speed: int = EnemyTuning.DANGLER_SPEED

var _going_down: bool = true


func _default_skin() -> String:
	return "bat"


func _apply_params(params: Dictionary) -> void:
	score_index = EnemyTuning.SCORE_DANGLER
	super._apply_params(params)
	depth = maxi(int(params.get("depth", depth)), 0)
	speed = maxi(absi(int(params.get("speed", speed))), 1)


func _on_wake() -> void:
	_thread_top = _find_thread_top()
	_thread_on = true
	_going_down = true
	_play(&"hang")


func _ai_tick() -> void:
	var bottom: int = spawn_pos.y + depth
	if _going_down:
		sim_pos.y = mini(sim_pos.y + speed, bottom)
		_going_down = sim_pos.y < bottom
	else:
		sim_pos.y = maxi(sim_pos.y - speed, spawn_pos.y)
		_going_down = sim_pos.y <= spawn_pos.y
	_play(&"hang")
