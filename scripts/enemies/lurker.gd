class_name Lurker
extends HangerEnemy
## `enemies/lurker` - archetype 3, ceiling dropper -> chaser (GAMEPLAY.md 5.2): hangs intangible at its anchor; once
## the hero is within `range` tiles horizontally (checked after a `pause`) it descends on its thread at 2 px per
## tick down to the floor, then runs at 3 px per tick toward the hero and climbs walls.
##
## Parameters: `range` tiles [4], `pause` ticks [22], `skin` [insect], `hp` [25], `score` [2].

enum State { HANG, DESCEND, RUN }

## Horizontal trigger distance in tiles (level parameter `range`).
var range_tiles: int = EnemyTuning.LURKER_RANGE_TILES
## Ticks it hangs before it starts to watch for the hero (level parameter `pause`).
var pause: int = EnemyTuning.LURKER_PAUSE

var _state: int = State.HANG
var _timer: int = 0


func _default_skin() -> String:
	return "insect"


func _apply_params(params: Dictionary) -> void:
	score_index = EnemyTuning.SCORE_LURKER
	super._apply_params(params)
	range_tiles = maxi(int(params.get("range", range_tiles)), 0)
	pause = maxi(int(params.get("pause", pause)), 0)


func _on_wake() -> void:
	_state = State.HANG
	_timer = pause
	tangible = false
	xvel = 0
	yvel = 0
	_thread_top = _find_thread_top()
	_thread_on = true
	_play(&"hang")


func _on_reset() -> void:
	tangible = true
	_thread_on = false


func _ai_tick() -> void:
	match _state:
		State.HANG:
			if _timer > 0:
				_timer -= 1
				return
			var hero: PlayerBase = _target_hero()
			if hero != null and Tuning.to_cell(absi(spawn_pos.x - hero.sim_pos.x)) <= range_tiles:
				_state = State.DESCEND
				tangible = true
		State.DESCEND:
			sim_pos.y += Tuning.floor16(EnemyTuning.LURKER_DROP_YVEL)
			var grid: TileGrid = Game.level.grid
			var surface: int = _surface_y(grid, Tuning.to_cell(sim_pos.x), Tuning.to_cell(sim_pos.y))
			if surface != NO_FLOOR and sim_pos.y >= surface:
				sim_pos.y = surface
				_thread_on = false
				_state = State.RUN
				_grounded = true
				var hero: PlayerBase = _target_hero()
				facing = _dir_to(hero) if hero != null else facing
				xvel = EnemyTuning.LURKER_RUN_XVEL * facing
				_play(&"walk")
		State.RUN:
			var hero: PlayerBase = _target_hero()
			if hero != null and not _climbing and _grounded \
					and (hero.sim_pos.x - sim_pos.x) * signi(xvel) < -EnemyTuning.LURKER_TURN_PX:
				xvel = -xvel
			_ground_step(true, false)
			if xvel != 0:
				facing = signi(xvel)
