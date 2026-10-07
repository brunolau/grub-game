class_name Charger
extends EnemyBase
## `enemies/charger` - archetype 12, edge rusher (GAMEPLAY.md 5.2): placed above the hero's path, about a screen
## away. It triggers when the hero is below its anchor and about one screen away (closer than two screens
## horizontally; within one screen horizontally only while he is between one and two screens lower), then runs in
## from its anchor at `speed` along the ground toward him. It is one-shot: after Tuning.EDGE_RUSHER_OFFSCREEN_TICKS
## ticks off screen, or once killed, it is gone until the level resets.
##
## Parameters: `speed` v16 [64], `skin` [rival], `hp` [25], `score` [4].

## Running speed, v16 (level parameter `speed`).
var speed: int = EnemyTuning.CHARGER_SPEED

var _offscreen_ticks: int = 0


func _default_skin() -> String:
	return "rival"


func _apply_params(params: Dictionary) -> void:
	score_index = EnemyTuning.SCORE_CHARGER
	super._apply_params(params)
	speed = absi(int(params.get("speed", speed)))
	one_shot = true


func _should_wake() -> bool:
	var hero: PlayerBase = _target_hero()
	if hero == null or not _slot_free():
		return false
	var view: Vector2i = Game.level.get_view_rect_of(hero).size
	var dy: int = hero.sim_pos.y - spawn_pos.y
	var dx: int = absi(hero.sim_pos.x - spawn_pos.x)
	if dy <= 0 or dx >= view.x * 2:
		return false
	return dx > view.x or (dy > view.y and dy < view.y * 2)


## Only the off-screen timer removes it.
func _should_sleep() -> bool:
	return false


## It wakes by the hero's distance (up to two screens), not by the view: it never dozes while it waits.
func _asleep_waits_for_view() -> bool:
	return false


func _on_wake() -> void:
	_offscreen_ticks = 0
	var hero: PlayerBase = _target_hero()
	facing = _dir_to(hero) if hero != null else facing
	xvel = speed * facing
	yvel = 0
	Audio.play_sfx(Sfx.ENEMY_VOICE)
	_play(&"walk")


func _ai_tick() -> void:
	_ground_step(false, true)
	if xvel != 0:
		facing = signi(xvel)
	_play(&"walk" if _grounded else &"air")
	_offscreen_ticks = 0 if on_screen else _offscreen_ticks + 1
	if _offscreen_ticks >= Tuning.EDGE_RUSHER_OFFSCREEN_TICKS:
		sleep()
