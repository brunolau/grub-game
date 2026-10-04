class_name Leaper
extends SpawnerEnemy
## `enemies/leaper` - archetype 11, arc leaper (GAMEPLAY.md 5.2): a zone spawner at a fixed point. While its anchor
## is near the view, after `pause` ticks a copy appears there (0..63 px higher, at random), poises for a moment and
## leaps toward the hero with `speed` forward and `rise` upward, then sinks with the soft enemy gravity
## (Tuning.ENEMY_SOFT_GRAVITY) capped at `sink` - a glide. It flies through walls; coming down on a floor it lands,
## rests and leaps again toward the hero, coming down into a liquid (the pit it jumped out of) it is gone, and it is
## gone once it left the view. The record then waits `pause` ticks before the next one.
##
## Parameters: `speed` v16 [48], `pause` ticks [66], `rise` v16 [speed x 2], `sink` v16 [speed / 2, at least 16],
## `skin` [dragon], `hp` [25], `score` [3].

enum State { POISE, FLIGHT, REST }

const FX_SPLASH: StringName = &"fx/splash"

## Horizontal leap speed, v16 (level parameter `speed`).
var speed: int = EnemyTuning.LEAPER_SPEED
## Upward take-off speed, v16 (level parameter `rise`).
var rise: int = EnemyTuning.LEAPER_SPEED * EnemyTuning.LEAPER_RISE_FACTOR
## Glide sink cap, v16 (level parameter `sink`).
var sink: int = Tuning.shr(EnemyTuning.LEAPER_SPEED, EnemyTuning.LEAPER_SINK_SHIFT)

var _state: int = State.POISE
var _timer: int = 0


func _default_skin() -> String:
	return "dragon"


func _apply_params(params: Dictionary) -> void:
	score_index = EnemyTuning.SCORE_LEAPER
	pause = EnemyTuning.LEAPER_PAUSE
	super._apply_params(params)
	speed = absi(int(params.get("speed", speed)))
	rise = absi(int(params.get("rise", speed * EnemyTuning.LEAPER_RISE_FACTOR)))
	sink = maxi(absi(int(params.get("sink", Tuning.shr(speed, EnemyTuning.LEAPER_SINK_SHIFT)))),
			Tuning.V16_PER_PX)


func _copy_id() -> StringName:
	return &"enemies/leaper"


func _triggered(_hero_node: PlayerBase) -> bool:
	return Game.level.is_in_view(self, Tuning.ENEMY_SPAWN_MARGIN_PX)


func _pick_spawn(_hero_node: PlayerBase) -> bool:
	_spawn_at = spawn_pos - Vector2i(0, Sim.rng.next_int(EnemyTuning.LEAPER_HEIGHT_RANDOM))
	return true


func _on_wake() -> void:
	_state = State.POISE
	_timer = EnemyTuning.LEAPER_POISE_TICKS
	tangible = false
	xvel = 0
	yvel = 0
	var hero: PlayerBase = _target_hero()
	facing = _dir_to(hero) if hero != null else facing
	_play(&"idle")
	_spawn_optional(FX_POOF, sim_pos + Vector2i(0, -(box_h >> 1)))


func _ai_tick() -> void:
	match _state:
		State.POISE, State.REST:
			var hero: PlayerBase = _target_hero()
			if hero != null:
				facing = _dir_to(hero)
			_timer -= 1
			if _timer > 0:
				return
			_state = State.FLIGHT
			_timer = 0
			tangible = true
			xvel = speed * facing
			yvel = -rise
			Audio.play_sfx(Sfx.ENEMY_VOICE)
		State.FLIGHT:
			sim_pos.x += Tuning.floor16(xvel)
			sim_pos.y += Tuning.floor16(yvel)
			if yvel < sink:
				yvel = mini(yvel + Tuning.ENEMY_SOFT_GRAVITY, sink)
			_timer += 1
			if _timer > EnemyTuning.LEAPER_MIN_FLIGHT_TICKS and not on_screen:
				sleep()
				return
			if yvel > 0 and _came_down():
				return
	_play(&"leap" if yvel < 0 else &"glide")


## Descending onto a floor: land and rest; into a liquid or onto spikes: splash and go. True when it stopped flying.
func _came_down() -> bool:
	var grid: TileGrid = Game.level.grid
	var col: int = Tuning.to_cell(sim_pos.x)
	var row: int = Tuning.to_cell(sim_pos.y)
	var floor_value: int = grid.floor_at(col, row)
	if floor_value == TileGrid.FLOOR_DEADLY:
		var liquid: String = "lava" if str(Game.level.meta.get("liquid", "")) == "lava" else "water"
		_spawn_optional(FX_SPLASH, Vector2i(sim_pos.x, row * Tuning.TILE), {"kind": liquid})
		Audio.play_sfx(Sfx.SPLASH)
		sleep()
		return true
	var surface: int = _surface_y(grid, col, row)
	if surface == NO_FLOOR or sim_pos.y < surface:
		return false
	sim_pos.y = surface
	xvel = 0
	yvel = 0
	_state = State.REST
	_timer = EnemyTuning.LEAPER_REST_TICKS
	_play(&"idle")
	return true
