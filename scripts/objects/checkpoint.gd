class_name Checkpoint
extends CheckpointBase
## `objects/checkpoint`: the restart fire (GAMEPLAY.md 7.6). Cold until the hero touches it, then the roast turns
## over a lit fire; only the last one touched is lit. The fire crackles while it is on screen.

## Sheet animation [M 8]: off 0, on 1-4 at 8 fps.
const FRAME_OFF: int = 0
const FRAME_ON_FIRST: int = 1
const ON_FRAMES: int = 4
const ON_FPS: int = 8
const ID_RING: StringName = &"fx/ring"
const ID_STAR_PUFF: StringName = &"fx/star_puff"

var _sprite: Sprite2D = null
var _anim: int = 0
var _loop_on: bool = false
## The frame last written to the sprite: the lit fire changes it at 8 fps, so most ticks write nothing (2.0, player-A's
## two-hero performance pass, PLAN P2.12; presentation only).
var _shown_frame: int = -1


func _sim_phases() -> PackedInt32Array:
	return PackedInt32Array([Defs.Phase.CONTACT_ITEMS, Defs.Phase.WORLD])


func _apply_params(params: Dictionary) -> void:
	super._apply_params(params)
	_sprite = get_node_or_null(^"Sprite") as Sprite2D
	_on_active_changed()


func _sim_tick(phase: int) -> void:
	if phase == Defs.Phase.CONTACT_ITEMS:
		super._sim_tick(phase)
	elif phase == Defs.Phase.WORLD and active:
		_anim += 1
		_show_frame(FRAME_ON_FIRST + ObjTuning.anim_frame(_anim, ON_FPS) % ON_FRAMES)
		_set_loop(on_screen)


func _exit_tree() -> void:
	_set_loop(false)


func activate(hero: PlayerBase) -> void:
	super.activate(hero)
	if Game.level != null:
		var middle: Vector2i = Vector2i(sim_pos.x, sim_pos.y - (box_h >> 1))
		Game.level.spawn_fx(ID_RING, middle)
		Game.level.spawn_fx(ID_STAR_PUFF, middle)


func _on_active_changed() -> void:
	_anim = 0
	_show_frame(FRAME_ON_FIRST if active else FRAME_OFF)
	if not active:
		_set_loop(false)


func _show_frame(frame: int) -> void:
	if _sprite != null and frame != _shown_frame:
		_shown_frame = frame
		_sprite.frame = frame


func _set_loop(on: bool) -> void:
	if on == _loop_on:
		return
	_loop_on = on
	if on:
		Audio.start_loop(Sfx.LOOP_FIRE)
	else:
		Audio.stop_loop(Sfx.LOOP_FIRE)
