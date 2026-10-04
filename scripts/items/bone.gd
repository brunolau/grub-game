class_name Bone
extends CollectibleBase
## `items/bone`: an energy fragment. Six bones restore one heart (GAMEPLAY.md 4.2). Bones fly out of enemies that
## stole a heart and out of the hero when a skull or a boss hits him; they spin while they fly.

const SPIN_FRAMES: int = 4


func _init() -> void:
	super()
	item_id = &"items/bone"
	set_box(Vector3i(12, 12, 6))


func _apply(_hero: PlayerBase) -> bool:
	if Game.add_bones(1) > 0:
		Audio.play_sfx(Sfx.HEART)
		Events.popup_requested.emit(&"heart", 1, Vector2i(sim_pos.x, sim_pos.y - box_h))
	return true


func _move_tick() -> void:
	super._move_tick()
	if dropped and not resting:
		show_cell(ObjTuning.anim_frame(age, ObjTuning.BONE_SPIN_FPS) % SPIN_FRAMES)


func _update_look() -> void:
	show_cell(0)
