class_name Harrier
extends EnemyBase
## `enemies/harrier` - archetype 6, clever flyer (GAMEPLAY.md 5.2): perches until the hero is within `range` tiles
## horizontally, then flies at 3 px per tick per axis through a loop of way-points defined relative to the hero
## (from his right and 40 px up, across 50-60 px above his head, to 32 px to his left and a swoop through head
## height), so that it circles him and swoops. While he is striking it flies 5 px higher. Flies through scenery.
## 2.0 co-op, G66 (DESIGN.md; world-B's hop-over probe opened w9_l1b_coop 'stormwall': a woken keeper followed a lone
## hero 14 columns to its mate's perch and he clubbed both inside the bond window): A FLYING KEEPER HOLDS ITS PERCH -
## a record with `keeper=<name>` (co-op files only) never takes off: when its target comes within `range` it turns to
## him and screeches once (the wake sound, the `screech` pose for EnemyTuning.HARRIER_KEEPER_SCREECH_TICKS - drawing
## and sound only) and stays on its anchor: no way-points, no swoop, no speed. It is struck where it sits and its body
## hurts on touch as any enemy's. A Harrier without `keeper=` is exactly the 1.0 Harrier.
##
## Parameters: `range` tiles [8], `skin` [pterodactyl], `hp` [25], `score` [4]; `keeper=<name>` pins it (G66).

## Activation distance in tiles (level parameter `range`).
var range_tiles: int = EnemyTuning.HARRIER_RANGE_TILES

var _circling: bool = false
var _waypoint: int = 0
var _waypoint_ticks: int = 0
## G66: ticks left of a keeper's screech pose.
var _screech: int = 0


func _default_skin() -> String:
	return "pterodactyl"


func _apply_params(params: Dictionary) -> void:
	score_index = EnemyTuning.SCORE_HARRIER
	super._apply_params(params)
	range_tiles = maxi(int(params.get("range", range_tiles)), 0)


func _on_wake() -> void:
	_circling = false
	_waypoint = 0
	_waypoint_ticks = 0
	_screech = 0
	_play(&"fly")


## Index of the way-point it is heading for (tests and tools).
func get_waypoint() -> int:
	return _waypoint


func _ai_tick() -> void:
	var hero: PlayerBase = _target_hero()
	if hero == null:
		return
	if not _circling:
		facing = _dir_to(hero)
		if Tuning.to_cell(absi(hero.sim_pos.x - sim_pos.x)) > range_tiles:
			return
		_circling = true
		Audio.play_sfx(Sfx.ENEMY_VOICE)
		if keeper != &"":
			_screech = EnemyTuning.HARRIER_KEEPER_SCREECH_TICKS
	if keeper != &"":
		# G66: a flying keeper holds its perch (no way-points, no swoop); every other Harrier is the 1.0 one below.
		_hold_perch(hero)
		return
	var point: Vector2i = EnemyTuning.HARRIER_WAYPOINTS[_waypoint]
	var height: int = point.y + (EnemyTuning.HARRIER_STRIKE_RISE if hero.is_striking() else 0)
	var target: Vector2i = Vector2i(hero.sim_pos.x + point.x, hero.sim_pos.y - height)
	var dx: int = clampi(target.x - sim_pos.x, -EnemyTuning.HARRIER_SPEED, EnemyTuning.HARRIER_SPEED)
	var dy: int = clampi(target.y - sim_pos.y, -EnemyTuning.HARRIER_SPEED, EnemyTuning.HARRIER_SPEED)
	sim_pos += Vector2i(dx, dy)
	xvel = dx * Tuning.V16_PER_PX
	yvel = dy * Tuning.V16_PER_PX
	facing = signi(dx) if dx != 0 else _dir_to(hero)
	_waypoint_ticks += 1
	if sim_pos == target or _waypoint_ticks >= EnemyTuning.HARRIER_WAYPOINT_TICKS:
		_waypoint = (_waypoint + 1) % EnemyTuning.HARRIER_WAYPOINTS.size()
		_waypoint_ticks = 0
	_play(&"screech" if point.y <= EnemyTuning.HARRIER_SWOOP_HEIGHT else &"fly")


## G66: a keeper holds its perch - on its anchor, facing its target, the screech pose while it lasts.
func _hold_perch(hero: PlayerBase) -> void:
	sim_pos = spawn_pos
	xvel = 0
	yvel = 0
	facing = _dir_to(hero)
	if _screech > 0:
		_screech -= 1
	_play(&"screech" if _screech > 0 else &"fly")
