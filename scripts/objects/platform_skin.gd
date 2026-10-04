class_name PlatformSkin
extends RefCounted
## Pictures of the sprite platforms (ASSET_MANIFEST.md 8): wood (jungle, cave), ice, stone (volcano) and the small
## bracket. Every picture is drawn with its top edge on the standing surface.

const NAMES: Array[String] = ["wood", "ice", "stone", "small"]
const TEXTURES: Array[Texture2D] = [
	preload("res://assets/sprites/objects/platform_wood.png"),
	preload("res://assets/sprites/objects/platform_ice.png"),
	preload("res://assets/sprites/objects/platform_stone.png"),
	preload("res://assets/sprites/objects/platform_small.png"),
]
## Half width of each picture in art px (the pivot is the top centre).
const HALF_WIDTHS: Array[int] = [48, 48, 48, 32]
## Contact boxes (w, h, x_offset) in logical px: the standing surface is the full picture width.
const BOXES: Array[Vector3i] = [Vector3i(48, 8, 24), Vector3i(48, 8, 24), Vector3i(48, 8, 24), Vector3i(32, 8, 16)]
const BIOME_SKINS: Dictionary = {"ice": "ice", "volcano": "stone"}
const DEFAULT_SKIN: int = 0


## Skin index for a `skin` parameter ("" or unknown = by the biome of the running level).
static func resolve(skin_name: String) -> int:
	var index: int = NAMES.find(skin_name)
	if index >= 0:
		return index
	if not skin_name.is_empty():
		push_warning("platform: unknown skin '%s'" % skin_name)
	var biome: String = str(Game.level.meta.get("biome", "")) if Game.level != null else ""
	return NAMES.find(str(BIOME_SKINS.get(biome, NAMES[DEFAULT_SKIN])))


## Dress `platform` (its "Sprite" child and its box) in skin `index`.
static func apply(platform: PlatformBase, index: int) -> void:
	platform.set_box(BOXES[index])
	var sprite: Sprite2D = platform.get_node_or_null(^"Sprite") as Sprite2D
	if sprite != null:
		sprite.texture = TEXTURES[index]
		sprite.offset = Vector2(-HALF_WIDTHS[index], -BOXES[index].y * Tuning.ART_SCALE)
