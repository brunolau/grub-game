class_name FxAnim
extends FxBase
## A one-shot sheet animation (star puff, hit stars, poof, explosions, ring, splash): plays `frame_count` frames
## of the "Sprite" sheet at `fps` (ASSET_MANIFEST.md 9) once, then frees itself. Optional parameter `flip`
## mirrors it.
##
## 2.0 `row=<n>` (versus, DESIGN.md E.9 "hit sparks in the attacker's colour"): a scene with a [member row_texture]
## plays row n of that sheet instead (`fx/hit_stars`: sprites/fx/hit_stars_players.png, rows in
## UiPlayers.PALETTE_COLOURS order). Without `row` nothing changes.

## Frames of the animation (the sheet's columns).
@export var frame_count: int = 1
## Frames per second of the manifest.
@export var fps: int = 16
## 2.0: the sheet of colour rows (`row`), `frame_count` columns by [member rows] rows; null = no rows.
@export var row_texture: Texture2D = null
@export var rows: int = 1

## Row played (0 = the plain sheet's only row).
var _row: int = 0


func _apply_params(params: Dictionary) -> void:
	lifetime = ObjTuning.anim_ticks(frame_count, fps)
	var sprite: Sprite2D = get_sprite()
	if sprite != null:
		sprite.frame = 0
		sprite.flip_h = param_bool("flip", false)
	if params.has("kind"):
		_apply_kind(str(params["kind"]))
	if params.has("row") and row_texture != null and sprite != null:
		_row = clampi(int(params["row"]), 0, maxi(rows, 1) - 1)
		sprite.texture = row_texture
		sprite.hframes = frame_count
		sprite.vframes = maxi(rows, 1)
		sprite.frame = _row * frame_count


func _fx_tick() -> void:
	var sprite: Sprite2D = get_sprite()
	if sprite != null:
		sprite.frame = _row * frame_count + mini(ObjTuning.anim_frame(age, fps), frame_count - 1)


## Variant selected by the `kind` parameter. Override.
func _apply_kind(_kind: String) -> void:
	pass
