class_name Decoration
extends EnemyBase
## `enemies/decoration` - archetype 1, decoration (GAMEPLAY.md 5.2): a static, intangible picture (spider webs,
## vines). It never takes an active slot, cannot be hit or touched and is never drawn as food.
##
## Parameters: `prop=<biome>/<name>` picture `res://assets/tiles/<biome>/props/<name>.png` [jungle/vine_a].
## Ceiling pieces (ASSET_MANIFEST.md 10.4) hang from the top of the cell; everything else stands on its bottom.

const DEFAULT_PROP: String = "jungle/vine_a"
## Props that are anchored top-centre at the top of the cell (ARCHITECTURE.md 7.5).
const CEILING_PROPS: PackedStringArray = [
	"stalactite", "drips", "drip_cap", "icicle", "vine_a", "vine_b", "moss_fringe",
]

## Picture of the decoration (level parameter `prop`).
var prop: String = DEFAULT_PROP

static var _warned_props: Dictionary[String, bool] = {}


func _apply_params(params: Dictionary) -> void:
	super._apply_params(params)
	prop = str(params.get("prop", prop))
	contact_hurts = false
	tangible = false
	_hide_asleep = false


func _ready() -> void:
	var path: String = Spawner.prop_texture_path(StringName("props/" + prop))
	if path.is_empty() or not ResourceLoader.exists(path):
		if not _warned_props.has(prop):
			_warned_props[prop] = true
			push_warning("Decoration: unknown prop '%s', using '%s'" % [prop, DEFAULT_PROP])
		prop = DEFAULT_PROP
		path = Spawner.prop_texture_path(StringName("props/" + prop))
	var texture: Texture2D = load(path) as Texture2D
	if _sprite == null or texture == null:
		return
	_sprite.texture = texture
	_sprite.centered = false
	_sprite.hframes = 1
	_sprite.vframes = 1
	_sprite.frame = 0
	var size: Vector2 = texture.get_size()
	_sprite.offset = Vector2(-floorf(size.x * 0.5), -size.y)
	var w: int = ceili(size.x / float(Tuning.ART_SCALE))
	var h: int = ceili(size.y / float(Tuning.ART_SCALE))
	set_box(Vector3i(w, h, w >> 1))
	if CEILING_PROPS.has(prop.get_file()):
		# Hang from the top of the cell: the feet point is the bottom of the picture.
		teleport(Vector2i(spawn_pos.x, spawn_pos.y - Tuning.TILE + h))


## Decorations never take a slot.
func _asleep_tick() -> void:
	pass


func _on_level_reset() -> void:
	visible = true
