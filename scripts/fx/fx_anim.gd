class_name FxAnim
extends FxBase
## A one-shot sheet animation (star puff, hit stars, poof, explosions, ring, splash): plays `frame_count` frames
## of the "Sprite" sheet at `fps` (ASSET_MANIFEST.md 9) once, then frees itself. Optional parameter `flip`
## mirrors it.

## Frames of the animation (the sheet's columns).
@export var frame_count: int = 1
## Frames per second of the manifest.
@export var fps: int = 16


func _apply_params(params: Dictionary) -> void:
	lifetime = ObjTuning.anim_ticks(frame_count, fps)
	var sprite: Sprite2D = get_sprite()
	if sprite != null:
		sprite.frame = 0
		sprite.flip_h = param_bool("flip", false)
	if params.has("kind"):
		_apply_kind(str(params["kind"]))


func _fx_tick() -> void:
	var sprite: Sprite2D = get_sprite()
	if sprite != null:
		sprite.frame = mini(ObjTuning.anim_frame(age, fps), frame_count - 1)


## Variant selected by the `kind` parameter. Override.
func _apply_kind(_kind: String) -> void:
	pass
