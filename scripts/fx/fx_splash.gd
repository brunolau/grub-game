class_name FxSplash
extends FxAnim
## `fx/splash` (`kind=water|lava` [water]): something fell into a liquid.

const TEX_LAVA: Texture2D = preload("res://assets/sprites/fx/splash_lava.png")


func _apply_kind(kind: String) -> void:
	var sprite: Sprite2D = get_sprite()
	if kind == "lava" and sprite != null:
		sprite.texture = TEX_LAVA
