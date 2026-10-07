class_name DropPlatform
extends PlatformBase
## `objects/drop_platform` (`delay` ticks [0], `skin=wood|ice|stone|small|cloud|driftwood` [by biome, PlatformSkin]):
## PHYSICS.md 11.4 droppers, GAMEPLAY.md 7.3. It waits; when the hero has stood on it for `delay` ticks (at once while
## it is still returning) it falls with Tuning.DROPPER_ACCEL v16 per tick up to Tuning.DROPPER_MAX until it reaches a
## floor or 3 rows below the map; there it rests until the hero has been off it for Tuning.DROPPER_REST_TICKS, then
## rises back at Tuning.DROPPER_RETURN_SPEED px per tick. The standing surface is the top edge of the cell it is
## placed in.
##
## 2.0 (GAMEPLAY.md 13.3): Book II's drop clouds, crumbling clouds and driftwood floes are this platform in the
## `cloud` / `driftwood` skins (pictures only). A geyser's spout (objects/geyser, 6-2's spore geysers) throws it up
## ([method launch]): it enters FALL with a negative `fall_speed` and rises under the hero's gravity (Tuning.GRAVITY:
## -224 lifts it 105 px, as the spout lifts everything) together with its riders, whom it launches with the same
## power - one arc for all, as a raft's (Raft.launch). From the top of the arc its dropper fall (DROPPER_ACCEL, slower
## than a hero's fall) brings it down, so its riders land on it again, until it rests on a floor below its home row.
## A 1.0 dropper never has a negative `fall_speed`.

enum State { WAIT = 0, FALL = 1, REST = 2 }

## Ticks the hero must stand on it before it falls.
var delay: int = 0
## Current state.
var state: int = State.WAIT
## Fall speed, v16.
var fall_speed: int = 0
## Feet point it starts from and returns to.
var home: Vector2i = Vector2i.ZERO

var _delay_left: int = 0
var _rest_left: int = 0


func _apply_params(params: Dictionary) -> void:
	super._apply_params(params)
	delay = maxi(int(params.get("delay", 0)), 0)
	PlatformSkin.apply(self, PlatformSkin.resolve(str(params.get("skin", ""))))
	home = Vector2i(sim_pos.x, sim_pos.y - (Tuning.TILE - box_h))
	teleport(home)
	_reset_state()


func _move_tick() -> void:
	match state:
		State.WAIT:
			var returning: bool = sim_pos.y > home.y
			if returning:
				dy = -mini(Tuning.DROPPER_RETURN_SPEED, sim_pos.y - home.y)
			if ridden:
				if returning or _delay_left <= 0:
					state = State.FALL
					fall_speed = 0
				else:
					_delay_left -= 1
		State.FALL:
			_fall()
		State.REST:
			if ridden:
				_rest_left = Tuning.DROPPER_REST_TICKS
			else:
				_rest_left -= 1
				if _rest_left <= 0:
					state = State.WAIT
					_delay_left = delay


## 2.0: thrown up with `power` v16 (negative) by a geyser's spout (GAMEPLAY.md 13.3): it rises from wherever it is,
## and every hero riding it (its last ride test, [member rider_mask]) is launched with the same power, keeping his x
## speed (PlayerBase.launch), so they rise together; see the class comment.
func launch(power: int) -> void:
	_doze_wake_now()
	var level: LevelBase = Game.level
	if level != null:
		for hero: PlayerBase in level.contact_order():
			if (rider_mask & (1 << hero.slot)) != 0 and not hero.dead and not hero.is_down():
				hero.launch(PlayerBase.LAUNCH_KEEP, power)
	state = State.FALL
	fall_speed = power
	_rest_left = 0


func _on_level_reset() -> void:
	teleport(home)
	ridden = false
	_reset_state()


func _fall() -> void:
	dy = Tuning.floor16(fall_speed)
	if fall_speed < 0:
		# 2.0: rising from a spout (launch) - the hero's gravity up to the top of the arc.
		fall_speed = mini(fall_speed + Tuning.GRAVITY, 0)
	elif fall_speed < Tuning.DROPPER_MAX:
		fall_speed = mini(fall_speed + Tuning.DROPPER_ACCEL, Tuning.DROPPER_MAX)
	var level: LevelBase = Game.level
	if level == null:
		return
	var grid: TileGrid = level.grid
	var y: int = sim_pos.y + dy
	var row: int = y >> 4
	if row >= grid.rows + ObjTuning.DROPPER_BELOW_MAP_ROWS:
		_stop()
	elif TileGrid.is_ground(grid.floor_at(sim_pos.x >> 4, row)) and row > (home.y >> 4):
		# Rest on top of the floor it ran into.
		dy = Tuning.tile_top(y) - sim_pos.y
		_stop()


func _stop() -> void:
	state = State.REST
	fall_speed = 0
	_rest_left = Tuning.DROPPER_REST_TICKS


func _reset_state() -> void:
	state = State.WAIT
	fall_speed = 0
	_delay_left = delay
	_rest_left = 0
