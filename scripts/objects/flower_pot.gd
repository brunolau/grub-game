class_name FlowerPot
extends HittableBase
## `objects/flower_pot` (DESIGN.md D.5, GAMEPLAY.md 13.9.7): the drop gift of a boost ledge. It stands on the ledge's
## edge cell. A strike (any weapon box, thrown weapon or batted ball: the weapon pass of the hittables) pushes it in
## the strike's direction at ObjTuning.FLOWER_POT_PUSH_XVEL; it slides to the edge of its floor (or stops at a wall:
## then it can be struck again), falls with the hero's gravity keeping its speed, and becomes a permanent
## `objects/spring` (-224) where it lands - a way back up for the lower hero. A pot that falls into a liquid, onto
## spikes or out of the map is lost; a team wipe (the level reset) puts a lost or moving pot back on its ledge, while a
## landed spring stays for the rest of the stage. It never counts for the completion percentage.

enum State { IDLE, SLIDE, FALL, SPRUNG, LOST }

## Sheet [M flower_pot]: 0 idle; tumble 0-3 at 12 fps; 4 smash; sprout 5-7 at 12 fps (7 = the spring's frame 0).
const FRAME_IDLE: int = 0
const TUMBLE_FRAMES: int = 4
const FRAME_SMASH: int = 4
const SPROUT_FRAMES: Array[int] = [5, 6, 7]
const ID_SPRING: StringName = &"objects/spring"
const ID_DUST: StringName = &"fx/dust"

var state: int = State.IDLE
## The spring it became (null until it landed).
var spring: SimEntity = null

var _home: Vector2i = Vector2i.ZERO
var _home_cell: Vector2i = Vector2i.ZERO
var _sprite: Sprite2D = null
var _anim: int = -1


func _init() -> void:
	super()
	counts_for_completion = false
	spot_kind = &"flower_pot"
	# The pot of the 64 x 32 art px cell: about 14 x 14 logical px, bottom-centred.
	set_box(Vector3i(14, 14, 7))


func _sim_phases() -> PackedInt32Array:
	return PackedInt32Array([Defs.Phase.ITEMS, Defs.Phase.WORLD])


func _apply_params(params: Dictionary) -> void:
	super._apply_params(params)
	hits_left = 1
	hits_total = 1
	_home = sim_pos
	_home_cell = cell
	_sprite = get_node_or_null(^"Sprite") as Sprite2D
	_show()


## Struck while standing: pushed in the strike's direction (consumes the weapon). Moving, landed or lost: the weapon
## passes on.
func take_hit(_power: int, source: SimEntity) -> bool:
	if state != State.IDLE:
		return false
	_doze_wake_now()
	if source is PlayerBase and not (source as PlayerBase).is_curled():
		strike_dir = source.facing
	elif source != null:
		# A thrown weapon or a batted ball (a curled hero) pushes it along its flight.
		strike_dir = -1 if source.xvel < 0 else 1
	xvel = strike_dir * ObjTuning.FLOWER_POT_PUSH_XVEL
	yvel = 0
	state = State.SLIDE
	Audio.play_sfx(Sfx.CLUB_HIT_SCENERY)
	if Game.level != null:
		Game.level.spawn_fx(&"fx/star_puff", get_hit_point())
	return true


func is_hit_by(origin: Vector2i) -> bool:
	return state == State.IDLE and super.is_hit_by(origin)


func get_hit_point() -> Vector2i:
	return Vector2i(sim_pos.x, sim_pos.y - (box_h >> 1))


func _sim_tick(phase: int) -> void:
	if phase == Defs.Phase.WORLD:
		super._sim_tick(phase)
		return
	var level: LevelBase = Game.level
	if level == null:
		return
	match state:
		State.SLIDE:
			_slide(level)
		State.FALL:
			_fall(level)
		State.SPRUNG:
			_sprout_tick()


func _slide(level: LevelBase) -> void:
	if not _step_x(level):
		# Against a wall: it stands again where it stopped.
		state = State.IDLE
		cell = Vector2i(sim_pos.x >> 4, (sim_pos.y - 1) >> 4)
		_doze_note()
		return
	if not TileGrid.is_ground(level.grid.floor_at(sim_pos.x >> 4, sim_pos.y >> 4)):
		state = State.FALL
		yvel = 0
		_anim = 0


func _fall(level: LevelBase) -> void:
	_step_x(level)
	sim_pos.y += Tuning.floor16(yvel)
	yvel = mini(yvel + Tuning.GRAVITY, Tuning.TERMINAL)
	_anim += 1
	_show()
	var grid: TileGrid = level.grid
	var col: int = sim_pos.x >> 4
	var row: int = sim_pos.y >> 4
	var floor_value: int = grid.floor_at(col, row)
	if TileGrid.is_ground(floor_value):
		var surface: int = row * Tuning.TILE + grid.surface_offset(col, row, sim_pos.x)
		if sim_pos.y >= surface:
			_land(level, surface)
	elif grid.get_char(col, row) == TileGrid.CH_LIQUID:
		var liquid: String = "lava" if str(level.meta.get("liquid", "water")) == "lava" else "water"
		level.spawn_fx(&"fx/splash", Vector2i(sim_pos.x, row * Tuning.TILE + 2), {"kind": liquid})
		Audio.play_sfx(Sfx.SPLASH)
		_lose()
	elif floor_value == TileGrid.FLOOR_DEADLY or sim_pos.y > grid.height_px() + Tuning.PIT_DEPTH_PX:
		_lose()


## One step of `xvel`; false (and xvel 0) when a wall or the map's edge is in the way.
func _step_x(level: LevelBase) -> bool:
	if xvel == 0:
		return true
	var grid: TileGrid = level.grid
	var next_x: int = sim_pos.x + Tuning.floor16(xvel)
	var probe: int = next_x + (box_xo if xvel > 0 else -box_xo)
	var outside: bool = next_x < 0 or (grid.cols > 0 and next_x >= grid.width_px())
	if outside or grid.side_at(probe >> 4, (sim_pos.y - 1) >> 4) == TileGrid.SIDE_WALL:
		xvel = 0
		return false
	sim_pos.x = next_x
	return true


func _land(level: LevelBase, surface: int) -> void:
	sim_pos.y = surface
	xvel = 0
	yvel = 0
	state = State.SPRUNG
	_anim = 0
	level.spawn_fx(ID_DUST, sim_pos)
	Audio.play_sfx(Sfx.IMPACT)
	spring = level.spawn(ID_SPRING, sim_pos) as SimEntity
	if spring != null:
		spring.visible = false
	_show()


func _lose() -> void:
	state = State.LOST
	xvel = 0
	yvel = 0
	visible = false
	_doze_note()


## Smash, then the sprout; at its end the spring shows and the pot is gone.
func _sprout_tick() -> void:
	if _anim < 0:
		return
	_anim += 1
	var sprout_age: int = _anim - ObjTuning.FLOWER_POT_SMASH_TICKS
	if sprout_age >= 0 and ObjTuning.anim_frame(sprout_age, ObjTuning.FLOWER_POT_ANIM_FPS) >= SPROUT_FRAMES.size():
		_anim = -1
		visible = false
		if is_instance_valid(spring):
			spring.visible = true
		_doze_note()
		return
	_show()


func _is_idle() -> bool:
	return (state == State.IDLE or state == State.SPRUNG or state == State.LOST) and _anim < 0


func _on_level_reset() -> void:
	cooldown = 0
	if state == State.SPRUNG:
		if _anim >= 0:
			_anim = -1
			visible = false
			if is_instance_valid(spring):
				spring.visible = true
		return
	state = State.IDLE
	xvel = 0
	yvel = 0
	_anim = -1
	cell = _home_cell
	visible = true
	teleport(_home)
	_show()


func _show() -> void:
	if _sprite == null:
		return
	match state:
		State.FALL:
			_sprite.frame = ObjTuning.anim_frame(maxi(_anim, 0), ObjTuning.FLOWER_POT_ANIM_FPS) % TUMBLE_FRAMES
		State.SPRUNG:
			var sprout_age: int = _anim - ObjTuning.FLOWER_POT_SMASH_TICKS
			if sprout_age < 0:
				_sprite.frame = FRAME_SMASH
			else:
				var index: int = ObjTuning.anim_frame(sprout_age, ObjTuning.FLOWER_POT_ANIM_FPS)
				_sprite.frame = SPROUT_FRAMES[mini(index, SPROUT_FRAMES.size() - 1)]
		_:
			_sprite.frame = FRAME_IDLE
