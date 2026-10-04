class_name LevelExit
extends LevelExitBase
## `objects/exit` (`locked` [false], `kind=exit|warp|trophy` [exit]): the exit totem, the original's traffic light
## (GAMEPLAY.md 7.6). A locked totem burns red until the fire-starter is collected, then green; touching a green
## one ends the level.

## Sheet animation [M 8]: cold 0, locked 1-2, open 3-4, both at 6 fps.
const FRAME_LOCKED_FIRST: int = 1
const FRAME_OPEN_FIRST: int = 3
const FLAME_FRAMES: int = 2
const FLAME_FPS: int = 6
const ID_RING: StringName = &"fx/ring"
const ID_STAR_PUFF: StringName = &"fx/star_puff"
## Height of the flame above the feet point, logical px.
const FLAME_DY: int = 38

var _sprite: Sprite2D = null
var _anim: int = 0
var _was_open: bool = false


func _sim_phases() -> PackedInt32Array:
	return PackedInt32Array([Defs.Phase.CONTACT_ITEMS, Defs.Phase.WORLD])


func _apply_params(params: Dictionary) -> void:
	super._apply_params(params)
	_sprite = get_node_or_null(^"Sprite") as Sprite2D
	_was_open = is_open()
	_show_frame()


func _sim_tick(phase: int) -> void:
	if phase == Defs.Phase.CONTACT_ITEMS:
		super._sim_tick(phase)
		return
	if phase != Defs.Phase.WORLD:
		return
	_anim += 1
	var open_now: bool = is_open()
	if open_now != _was_open:
		_was_open = open_now
		if open_now and Game.level != null:
			Game.level.spawn_fx(ID_STAR_PUFF, Vector2i(sim_pos.x, sim_pos.y - FLAME_DY))
	_show_frame()


func use(hero: PlayerBase) -> void:
	if used:
		return
	super.use(hero)
	if Game.level != null:
		Game.level.spawn_fx(ID_RING, Vector2i(sim_pos.x, sim_pos.y - FLAME_DY))


func _on_open_changed() -> void:
	Audio.play_sfx(Sfx.EXIT_OPEN)


func _show_frame() -> void:
	if _sprite == null:
		return
	var first: int = FRAME_OPEN_FIRST if is_open() else FRAME_LOCKED_FIRST
	_sprite.frame = first + ObjTuning.anim_frame(_anim, FLAME_FPS) % FLAME_FRAMES
