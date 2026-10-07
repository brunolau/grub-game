class_name LevelLights
extends Node2D
## Lights in the dark (2.0, DESIGN.md A.3: 6-2 "near darkness, glowing caps mark the way", 7-2 dark sea caves, 8-2
## "darkness"; Inkjaw's ink; co-op in Book I's dark caves). Owner: world-A.
##
## The darkness of GAMEPLAY.md 7.10 is the night palette over the whole level (Level's CanvasModulate). On a Book II
## level, an arena and in a party, Level adds this node: while the palette is dark, every hero carries a soft warm glow
## (so partners and rivals keep seeing each other) and every glowing prop - a prop whose picture name holds "glow",
## such as swamp/props/glowcaps and glowcap_big - lights the rock around it in its own colour. The lights are Godot 2D
## point lights under the CanvasModulate: they brighten what lies near them instead of painting over it, and they
## fade with the palette (no light at all in daylight, where each one is switched off). A Book I level played solo
## never has this node: its look is 1.0's.
##
## Presentation only: positions come from the drawn nodes, nothing in the simulation reads a light.

## Light texture size (art px, a radial gradient: white centre, clear rim) and energy at full darkness.
const HERO_LIGHT_ART: int = 224
const PROP_LIGHT_ART: int = 160
const HERO_ENERGY: float = 0.85
const PROP_ENERGY: float = 0.75
const HERO_COLOR: Color = Color(1.0, 0.9, 0.72)
## The light of a glowing prop: teal (glowing caps, cyan anemones, crystal coral) unless its picture is listed here
## (art-B's hand-over: the 8-2 brazier burns warm, the pink anemone of 7-2 glows pink).
const PROP_COLOR: Color = Color(0.55, 1.0, 0.9)
const PROP_COLORS: Dictionary = {
	"brazier_glow": Color("ffb050"),
	"glow_anemone_pink": Color("e870a8"),
}
## The hero's light sits at the middle of his body (16 logical px over the feet).
const HERO_LIGHT_RISE_ART: float = 16.0 * Tuning.ART_SCALE
## A light whose reach is this far (art px) outside the visible view is switched off.
const CULL_MARGIN_ART: float = 64.0
## Picture names that glow.
const GLOW_TAG: String = "glow"

## Darkness 0..1 of the last frame (the palette fade), and the lights by role.
var darkness: float = 0.0
var hero_lights: Array[PointLight2D] = []
var prop_lights: Array[PointLight2D] = []

static var _textures: Dictionary = {}


func _init() -> void:
	name = "Lights"


## True when the prop picture `path` glows in the dark.
static func is_glow_prop(path: String) -> bool:
	return path.get_file().to_lower().contains(GLOW_TAG)


## True when a level with this header and party size gets lights in its dark: Book II, an arena, or two or more heroes.
static func wanted(meta: Dictionary, hero_count: int) -> bool:
	return int(meta.get("book", 1)) >= 2 or str(meta.get("kind", "")) == "arena" or hero_count > 1


## The light colour of the glowing prop picture `path` (PROP_COLORS by its file name, else teal).
static func prop_color(path: String) -> Color:
	return PROP_COLORS.get(path.get_file().get_basename(), PROP_COLOR)


## A glowing prop at `centre` (art px, world coordinates): a light of `color` (default: the prop teal) there.
func add_prop_light(centre: Vector2, color: Color = PROP_COLOR) -> void:
	var light: PointLight2D = _new_light(PROP_LIGHT_ART, color)
	light.position = centre
	prop_lights.append(light)


## Called every frame by Level: `fade` = how dark the palette is (0 day .. 1 night), `heroes` the party, `view` the
## visible view (art px).
func update_lights(fade: float, heroes: Array[PlayerBase], view: Rect2) -> void:
	darkness = clampf(fade, 0.0, 1.0)
	while hero_lights.size() < heroes.size():
		hero_lights.append(_new_light(HERO_LIGHT_ART, HERO_COLOR))
	var area: Rect2 = view.grow(CULL_MARGIN_ART)
	for i: int in hero_lights.size():
		var light: PointLight2D = hero_lights[i]
		var hero: PlayerBase = heroes[i] if i < heroes.size() else null
		var lit: bool = darkness > 0.0 and hero != null and is_instance_valid(hero) and not hero.dead
		light.enabled = lit
		if lit:
			light.position = hero.position - Vector2(0.0, HERO_LIGHT_RISE_ART)
			light.energy = HERO_ENERGY * darkness
	for light: PointLight2D in prop_lights:
		var reach: float = float(PROP_LIGHT_ART) * 0.5
		var lit_prop: bool = darkness > 0.0 and area.intersects(Rect2(light.position - Vector2(reach, reach),
				Vector2(reach, reach) * 2.0))
		light.enabled = lit_prop
		if lit_prop:
			light.energy = PROP_ENERGY * darkness


func _new_light(size_art: int, color: Color) -> PointLight2D:
	var light: PointLight2D = PointLight2D.new()
	light.texture = _texture(size_art)
	light.color = color
	light.energy = 0.0
	light.enabled = false
	light.shadow_enabled = false
	light.blend_mode = Light2D.BLEND_MODE_ADD
	add_child(light)
	return light


## A radial light picture `size_art` px across (shared by every light of that size).
static func _texture(size_art: int) -> Texture2D:
	if _textures.has(size_art):
		return _textures[size_art]
	var gradient: Gradient = Gradient.new()
	gradient.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	gradient.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	gradient.add_point(0.55, Color(1.0, 1.0, 1.0, 0.55))
	var texture: GradientTexture2D = GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = size_art
	texture.height = size_art
	_textures[size_art] = texture
	return texture
