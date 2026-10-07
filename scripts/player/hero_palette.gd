class_name HeroPalette
extends RefCounted
## Hero colours for P1-P4 (docs/expansion/DESIGN.md D.1, E.9, F.1): the palette swap of the hero sheets by a 16 x 1
## LUT shader per slot, with no baked sheets (TECH_AUDIT.md 5.3), and its CPU twin for tests and tools.
##
## Owner: player-A (docs/expansion/PLAN.md 4.1, P1.4). Contract and executable reference: the art pipeline's
## docs/art/expansion/pipeline/build_hero_palettes.py (`Palettes.apply`) and the data it writes,
## assets/sprites/player/palettes/hero_palettes.json (its "shader" block is the rule this file implements):
##  - key LUT `hero_lut_key.png` (16 x 1): the 1.0 colours that are replaced (alpha 0 = unused entry);
##  - slot LUT `hero_lut_<colour>.png` (16 x 1): the replacement of each key entry, same order;
##  - cloth atlas `hero_cloth.png`: one window per sheet cell; per loincloth pixel R + 256 G = pattern bits, B = the
##    tone under it (1 main, 2 shadow). Key entries 0-2 (cloth, shadow, ink) inside a cell's window become
##    `bit(pattern) ? 2 : (B == 2 ? 1 : 0)`; every key texel then takes the slot LUT's colour with its own alpha.
## Colour `yellow` equals the key, so yellow + pattern 0 (`spots`, the sheet's own ink) is the 1.0 look on every
## hero sheet: [method material_for] returns null for it and the sprite keeps NO material at all - P1 of a
## single-player game (which never asks) and a yellow P1 of a party are pixel-identical to 1.0 by construction.
## Sprites that are not hero sheets (the revive egg `hero_egg.png`) use the LUT with the pattern step off.
##
## Materials are shared: one ShaderMaterial per (colour, pattern, cloth step) for every hero that uses it (one draw
## state per colour, ARCHITECTURE.md 11). Nothing here is read by the simulation.

const DIR: String = "res://assets/sprites/player/palettes/"
const META_PATH: String = DIR + "hero_palettes.json"
const KEY_LUT_PATH: String = DIR + "hero_lut_key.png"
const CLOTH_PATH: String = DIR + "hero_cloth.png"
## The colour and pattern that reproduce the 1.0 hero.
const IDENTITY_COLOUR: StringName = &"yellow"
const IDENTITY_PATTERN: int = 0
const LUT_SIZE: int = 16
## Key entries 0..CLOTH_ENTRIES - 1 are the loincloth (main, shadow, ink): the pattern step re-picks among them.
const CLOTH_ENTRIES: int = 3
const ENTRY_CLOTH: int = 0
const ENTRY_SHADOW: int = 1
const ENTRY_INK: int = 2
## Shader parameters of a hero sheet (ASSET_MANIFEST.md 3: 8 x 7 cells of 176 x 112 art px); the cloth window comes
## from the JSON.
const HERO_CELL: Vector2i = Vector2i(176, 112)

## The shader of hero_palettes.json "shader". TEXTURE is read texel-exact (texelFetch at the texel UV falls in), so a
## sprite of any frame, flip or scale picks the same key; texels that match no key keep the default COLOR (1.0).
## Key texels get the slot colour times the interpolated vertex colour, which carries modulate / self_modulate
## exactly as the default canvas fragment does (COLOR = vertex colour * texture).
const SHADER_CODE: String = """
shader_type canvas_item;

uniform sampler2D key_lut : filter_nearest, repeat_disable;
uniform sampler2D slot_lut : filter_nearest, repeat_disable;
uniform sampler2D cloth_atlas : filter_nearest, repeat_disable;
uniform int pattern = 0;
uniform bool use_cloth = true;
uniform ivec2 cell_size = ivec2(176, 112);
uniform ivec4 cloth_window = ivec4(69, 62, 42, 36);

varying vec4 vertex_colour;

void vertex() {
	vertex_colour = COLOR;
}

void fragment() {
	ivec2 size = textureSize(TEXTURE, 0);
	ivec2 px = clamp(ivec2(floor(UV * vec2(size))), ivec2(0), size - ivec2(1));
	vec4 c = texelFetch(TEXTURE, px, 0);
	if (c.a > 0.0) {
		ivec3 rgb = ivec3(round(c.rgb * 255.0));
		int index = -1;
		for (int i = 0; i < 16; i++) {
			vec4 k = texelFetch(key_lut, ivec2(i, 0), 0);
			if (k.a > 0.0 && ivec3(round(k.rgb * 255.0)) == rgb) {
				index = i;
				break;
			}
		}
		if (index >= 0) {
			if (use_cloth && index < 3) {
				ivec2 cell = px / cell_size;
				ivec2 local = px - cell * cell_size - cloth_window.xy;
				if (local.x >= 0 && local.y >= 0 && local.x < cloth_window.z && local.y < cloth_window.w) {
					vec4 t = texelFetch(cloth_atlas, cell * cloth_window.zw + local, 0);
					if (t.a > 0.0) {
						int bits = int(round(t.r * 255.0)) + 256 * int(round(t.g * 255.0));
						if (((bits >> pattern) & 1) == 1) {
							index = 2;
						} else {
							index = int(round(t.b * 255.0)) == 2 ? 1 : 0;
						}
					}
				}
			}
			vec4 s = texelFetch(slot_lut, ivec2(index, 0), 0);
			COLOR = vec4(s.rgb, c.a) * vertex_colour;
		}
	}
}
"""

static var _meta: Dictionary = {}
static var _shader: Shader = null
static var _materials: Dictionary = {}
static var _luts: Dictionary = {}
static var _key_lut: Texture2D = null
static var _cloth: Texture2D = null


# =================================================================================================================
# Data (hero_palettes.json)
# =================================================================================================================

## The parsed hero_palettes.json (cached; empty when the file is missing).
static func meta() -> Dictionary:
	if _meta.is_empty() and FileAccess.file_exists(META_PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(META_PATH))
		if parsed is Dictionary:
			_meta = parsed
	return _meta


## Every colour name of the file, in its order (yellow, blue, pink, green, white, gold).
static func colour_names() -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	for name: Variant in (meta().get("palettes", {}) as Dictionary).keys():
		names.append(str(name))
	return names


## True when `colour` is a palette of the file.
static func has_colour(colour: StringName) -> bool:
	return (meta().get("palettes", {}) as Dictionary).has(String(colour))


## Number of loincloth patterns (index 0..count - 1).
static func pattern_count() -> int:
	return (meta().get("patterns", []) as Array).size()


## Index of the pattern called `pattern_name` (-1 when unknown).
static func pattern_index(pattern_name: String) -> int:
	for entry: Variant in meta().get("patterns", []):
		if entry is Dictionary and str(entry.get("name", "")) == pattern_name:
			return int(entry.get("index", -1))
	return -1


## The default colour of player slot `slot` (0 = P1 yellow, 1 = P2 blue, 2 = P3 pink, 3 = P4 green).
static func slot_default_colour(slot: int) -> StringName:
	var entry: Dictionary = (meta().get("slot_defaults", {}) as Dictionary).get("p%d" % (slot + 1), {})
	return StringName(str(entry.get("colour", IDENTITY_COLOUR)))


## The default loincloth pattern index of player slot `slot` (P1 spots = the 1.0 look, P2 stripes ...).
static func slot_default_pattern(slot: int) -> int:
	var entry: Dictionary = (meta().get("slot_defaults", {}) as Dictionary).get("p%d" % (slot + 1), {})
	return maxi(pattern_index(str(entry.get("pattern", "spots"))), 0)


## The colour and pattern a hero of player slot `slot` wears: his run's choice (PlayerRun.palette / pattern, written by
## the join panel and the versus lobby) or the slot's default; in versus the arena swaps of the file (green -> white on
## jungle and swamp arenas, DESIGN.md E.9) by the level's biome. Returns [colour: StringName, pattern: int].
static func resolve(slot: int, run: PlayerRun = null, biome: String = "", versus: bool = false) -> Array:
	var colour: StringName = slot_default_colour(slot)
	var pattern: int = slot_default_pattern(slot)
	if run != null:
		if run.palette != &"" and has_colour(run.palette):
			colour = run.palette
		if run.pattern >= 0 and run.pattern < pattern_count():
			pattern = run.pattern
	if versus and not biome.is_empty():
		var swaps: Dictionary = (meta().get("arena_swaps", {}) as Dictionary).get(biome, {})
		if swaps.has(String(colour)):
			colour = StringName(str(swaps[String(colour)]))
	return [colour, pattern]


## True when (colour, pattern) is the 1.0 hero: the sprite needs no material. With the pattern step off (the egg) only
## the colour counts.
static func is_identity(colour: StringName, pattern: int, use_cloth: bool = true) -> bool:
	return colour == IDENTITY_COLOUR and (pattern == IDENTITY_PATTERN or not use_cloth)


## The UI colours of `colour` (hero_palettes.json `ui_colours`: fill, light, shade, dark) for tags, arrows and the
## emote bubble; white when unknown.
static func ui_colour(colour: StringName, role: String = "fill") -> Color:
	var entry: Dictionary = (meta().get("ui_colours", {}) as Dictionary).get(String(colour), {})
	return Color.html(str(entry.get(role, "#ffffff")))


# =================================================================================================================
# The shader material
# =================================================================================================================

## The shared material that paints a hero sheet (or, with `use_cloth` false, any sprite drawn in the key colours) in
## `colour` with loincloth `pattern`; null for the 1.0 look ([method is_identity]) or when the palette files are
## missing (the sprite then keeps the 1.0 colours).
static func material_for(colour: StringName, pattern: int, use_cloth: bool = true) -> ShaderMaterial:
	if is_identity(colour, pattern, use_cloth) or not has_colour(colour):
		return null
	var key: String = "%s|%d|%d" % [colour, pattern if use_cloth else -1, 1 if use_cloth else 0]
	if _materials.has(key):
		return _materials[key]
	var slot_lut: Texture2D = _lut(colour)
	if slot_lut == null or _key() == null or (use_cloth and _cloth_atlas() == null):
		return null
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = shader()
	material.set_shader_parameter(&"key_lut", _key())
	material.set_shader_parameter(&"slot_lut", slot_lut)
	material.set_shader_parameter(&"cloth_atlas", _cloth_atlas())
	material.set_shader_parameter(&"pattern", clampi(pattern, 0, 15))
	material.set_shader_parameter(&"use_cloth", use_cloth)
	material.set_shader_parameter(&"cell_size", HERO_CELL)
	material.set_shader_parameter(&"cloth_window", cloth_window())
	_materials[key] = material
	return material


## The palette shader (one shared instance).
static func shader() -> Shader:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER_CODE
	return _shader


## The cloth window of the JSON as (x, y, w, h) inside a 176 x 112 cell.
static func cloth_window() -> Vector4i:
	var window: Dictionary = meta().get("cloth_window", {})
	return Vector4i(int(window.get("x", 0)), int(window.get("y", 0)), int(window.get("w", 0)), int(window.get("h", 0)))


static func _key() -> Texture2D:
	if _key_lut == null and ResourceLoader.exists(KEY_LUT_PATH):
		_key_lut = load(KEY_LUT_PATH) as Texture2D
	return _key_lut


static func _cloth_atlas() -> Texture2D:
	if _cloth == null and ResourceLoader.exists(CLOTH_PATH):
		_cloth = load(CLOTH_PATH) as Texture2D
	return _cloth


static func _lut(colour: StringName) -> Texture2D:
	if not _luts.has(colour):
		var path: String = DIR + "hero_lut_%s.png" % colour
		_luts[colour] = load(path) as Texture2D if ResourceLoader.exists(path) else null
	return _luts[colour]


# =================================================================================================================
# CPU twin (tests, tools): exactly the shader's rule on an Image
# =================================================================================================================

## A copy of `image` (a hero sheet laid out in 176 x 112 cells, or with `use_cloth` false any sprite in key colours)
## recoloured as the shader paints it: [method material_for]'s result, texel for texel. Returns null when the palette
## files are missing. RGBA8 out.
static func apply_image(image: Image, colour: StringName, pattern: int, use_cloth: bool = true) -> Image:
	var key_image: Image = _image_of(_key())
	var slot_image: Image = _image_of(_lut(colour))
	var cloth_image: Image = _image_of(_cloth_atlas()) if use_cloth else null
	if key_image == null or slot_image == null or (use_cloth and cloth_image == null):
		return null
	# Key colours as 0xRRGGBB -> entry, replacement bytes per entry.
	var keys: Dictionary = {}
	var out_rgb: PackedInt32Array = PackedInt32Array()
	out_rgb.resize(LUT_SIZE)
	for i: int in LUT_SIZE:
		var k: Color = key_image.get_pixel(i, 0)
		if k.a8 > 0 and not keys.has(_rgb24(k)):
			keys[_rgb24(k)] = i
		out_rgb[i] = _rgb24(slot_image.get_pixel(i, 0))
	var window: Vector4i = cloth_window()
	var cloth: PackedByteArray = PackedByteArray()
	var cloth_w: int = 0
	if cloth_image != null:
		cloth_w = cloth_image.get_width()
		cloth = cloth_image.get_data()
	var result: Image = image.duplicate() as Image
	if result.get_format() != Image.FORMAT_RGBA8:
		result.convert(Image.FORMAT_RGBA8)
	var data: PackedByteArray = result.get_data()
	var width: int = result.get_width()
	var count: int = data.size() / 4
	for p: int in count:
		var o: int = p * 4
		if data[o + 3] == 0:
			continue
		var rgb: int = (data[o] << 16) | (data[o + 1] << 8) | data[o + 2]
		if not keys.has(rgb):
			continue
		var index: int = keys[rgb]
		if use_cloth and index < CLOTH_ENTRIES:
			var x: int = p % width
			var y: int = p / width
			var col: int = x / HERO_CELL.x
			var row: int = y / HERO_CELL.y
			var lx: int = x - col * HERO_CELL.x - window.x
			var ly: int = y - row * HERO_CELL.y - window.y
			if lx >= 0 and ly >= 0 and lx < window.z and ly < window.w:
				var t: int = ((row * window.w + ly) * cloth_w + col * window.z + lx) * 4
				if cloth[t + 3] > 0:
					var bits: int = cloth[t] + 256 * cloth[t + 1]
					if (bits >> pattern) & 1 == 1:
						index = ENTRY_INK
					else:
						index = ENTRY_SHADOW if cloth[t + 2] == 2 else ENTRY_CLOTH
		var c: int = out_rgb[index]
		data[o] = (c >> 16) & 0xFF
		data[o + 1] = (c >> 8) & 0xFF
		data[o + 2] = c & 0xFF
	return Image.create_from_data(width, result.get_height(), false, Image.FORMAT_RGBA8, data)


static func _image_of(texture: Texture2D) -> Image:
	if texture == null:
		return null
	var image: Image = texture.get_image()
	if image == null:
		return null
	if image.get_format() != Image.FORMAT_RGBA8:
		image.convert(Image.FORMAT_RGBA8)
	return image


static func _rgb24(c: Color) -> int:
	return (c.r8 << 16) | (c.g8 << 8) | c.b8
