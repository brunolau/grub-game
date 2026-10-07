class_name PlatformSkin
extends RefCounted
## Pictures of the sprite platforms (ASSET_MANIFEST.md 8): wood (jungle, cave), ice, stone (volcano) and the small
## bracket. Every picture is drawn with its top edge on the standing surface.
##
## 2.0 (GAMEPLAY.md 13.3: "drop clouds / crumbling clouds / driftwood floes are 1.0 drop platforms in new skins"):
## `cloud` (9-1 Cloudbreak Climb, 9-2 The Roc's Spire, the Storm Roc's nest; default of the `sky` biome) and
## `driftwood` (7-2 Sea Caves' drop floes; default of the `coast` biome); the `ruins` biome defaults to `stone`. They
## are pictures only: every 48-px skin has the wood platform's box, so the rules and the routes never see a skin.
## A picture that art-A has not delivered yet (PATHS) is drawn with its STAND_INS skin until the file exists.

const NAMES: Array[String] = ["wood", "ice", "stone", "small", "cloud", "driftwood"]
const TEXTURES: Array[Texture2D] = [
	preload("res://assets/sprites/objects/platform_wood.png"),
	preload("res://assets/sprites/objects/platform_ice.png"),
	preload("res://assets/sprites/objects/platform_stone.png"),
	preload("res://assets/sprites/objects/platform_small.png"),
]
## Files of the 2.0 skins (index - TEXTURES.size()), 96 x 16 art px like platform_wood.png [M 8], and the skin drawn
## instead while a file does not exist.
const PATHS: Array[String] = [
	"res://assets/sprites/objects/platform_cloud.png",
	"res://assets/sprites/objects/platform_driftwood.png",
]
const STAND_INS: Array[int] = [1, 0]
## Half width of each picture in art px (the pivot is the top centre).
const HALF_WIDTHS: Array[int] = [48, 48, 48, 32, 48, 48]
## Contact boxes (w, h, x_offset) in logical px: the standing surface is the full picture width.
const BOXES: Array[Vector3i] = [
	Vector3i(48, 8, 24), Vector3i(48, 8, 24), Vector3i(48, 8, 24), Vector3i(32, 8, 16),
	Vector3i(48, 8, 24), Vector3i(48, 8, 24),
]
const BIOME_SKINS: Dictionary = {
	"ice": "ice", "volcano": "stone", "ruins": "stone", "sky": "cloud", "coast": "driftwood",
}
const DEFAULT_SKIN: int = 0
const SKIN_CLOUD: int = 4
const SKIN_DRIFTWOOD: int = 5


## Skin index for a `skin` parameter ("" or unknown = by the biome of the running level).
static func resolve(skin_name: String) -> int:
	var index: int = NAMES.find(skin_name)
	if index >= 0:
		return index
	if not skin_name.is_empty():
		push_warning("platform: unknown skin '%s'" % skin_name)
	var biome: String = str(Game.level.meta.get("biome", "")) if Game.level != null else ""
	return NAMES.find(str(BIOME_SKINS.get(biome, NAMES[DEFAULT_SKIN])))


## The picture of skin `index` (a 2.0 skin whose file is not there yet: its stand-in's picture).
static func texture(index: int) -> Texture2D:
	if index < TEXTURES.size():
		return TEXTURES[index]
	var extra: int = index - TEXTURES.size()
	return ObjTuning.picture(PATHS[extra], TEXTURES[STAND_INS[extra]])


## Dress `platform` (its "Sprite" child and its box) in skin `index`.
static func apply(platform: PlatformBase, index: int) -> void:
	platform.set_box(BOXES[index])
	var sprite: Sprite2D = platform.get_node_or_null(^"Sprite") as Sprite2D
	if sprite != null:
		sprite.texture = texture(index)
		sprite.offset = Vector2(-HALF_WIDTHS[index], -BOXES[index].y * Tuning.ART_SCALE)
