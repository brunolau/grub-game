class_name WardMark
extends RefCounted
## THE WARD MARK (phase 4 ruling Q2, docs/expansion/DESIGN.md G85): the chalk war paint an enemy wears while it stands
## in the ward of a co-op gate (LevelBase.in_ward of its feet column, in a level a co-op party plays:
## LevelBase.ward_marks). It tells the players which beasts are "no stepping stones" - inside a ward no enemy gives a
## hero lift, rest or carry (G73). Owner: objects-A (scripts/fx/**); worn by EnemyBase._refresh_visual.
##
## DRAWING ONLY. Nothing here is read by the simulation, and nothing of the simulation changes with it: the mark is ONE
## shared ShaderMaterial put on the enemy's own "Sprite" node (and taken off again), so it follows every frame, flip,
## skin and palette of every sheet by itself, needs no art file and no extra node, and adds no canvas item. It is not a
## per-entity material (ARCHITECTURE.md 11): every marked enemy of the game shares this one, like the hero palettes
## (HeroPalette), so marked enemies of one sheet still batch together - the cost is at most one more draw state per
## sheet that is on the view both marked and unmarked.
##
## What is drawn: chevron bands of chalk across the body - a zigzag every BAND_PERIOD art px, CHALK_PX of chalk white
## between two EDGE_PX lines of dark ink (the ink keeps the bands readable on pale sheets: gulls, ghosts, snow
## turtles, the light half of a slime; the chalk on dark ones). The bands are cut in the sprite's own space (art px
## from the enemy's feet point), whole pixels, only where the sheet's texel is opaque - so they lie on the body like
## paint and never on the air around it. The hit flash still shows through (the bands take the sprite's modulate).
## Not a HUD element, no text, no motion of its own.

## The bands: slanted one art px down per art px to the right; BAND_PERIOD art px from one band to the next (measured
## along a row), CHALK_PX of chalk between two EDGE_PX lines of ink, the first band BAND_SHIFT px from the feet point.
const BAND_PERIOD: int = 26
const CHALK_PX: int = 5
const EDGE_PX: int = 2
const BAND_SHIFT: int = 9
## The paint keeps this many art px off the edge of the silhouette (the sheet's own outline stays whole).
const RIM_PX: int = 2
const CHALK_COLOUR: Color = Color8(246, 240, 222)
const INK_COLOUR: Color = Color8(46, 39, 31)

const SHADER_CODE: String = """
shader_type canvas_item;

uniform float band_period = 26.0;
uniform float chalk_px = 6.0;
uniform float edge_px = 1.0;
uniform float band_shift = 9.0;
uniform float rim_px = 2.0;
uniform vec4 chalk_colour : source_color = vec4(0.965, 0.941, 0.871, 1.0);
uniform vec4 ink_colour : source_color = vec4(0.180, 0.153, 0.122, 1.0);

varying vec2 local_px;
varying vec4 vertex_colour;

void vertex() {
	local_px = VERTEX;
	vertex_colour = COLOR;
}

void fragment() {
	// COLOR is the sheet's texel times the sprite's modulate here (the default canvas fragment).
	if (COLOR.a > 0.5) {
		vec2 p = floor(local_px);
		float band = mod(p.x + p.y + band_shift + band_period * 64.0, band_period);
		if (band < chalk_px + edge_px * 2.0) {
			// The paint keeps off the rim of the silhouette (the sheet's own ink outline stays whole): only where the
			// texels rim_px to the left, right, above and below are opaque too.
			vec2 step_x = vec2(TEXTURE_PIXEL_SIZE.x * rim_px, 0.0);
			vec2 step_y = vec2(0.0, TEXTURE_PIXEL_SIZE.y * rim_px);
			float inside = min(min(texture(TEXTURE, UV - step_x).a, texture(TEXTURE, UV + step_x).a),
					min(texture(TEXTURE, UV - step_y).a, texture(TEXTURE, UV + step_y).a));
			if (inside > 0.5) {
				bool chalk = band >= edge_px && band < edge_px + chalk_px;
				vec4 paint = chalk ? chalk_colour : ink_colour;
				COLOR = vec4(paint.rgb * vertex_colour.rgb, COLOR.a);
			}
		}
	}
}
"""

static var _shader: Shader = null
static var _material: ShaderMaterial = null


## The one material of the mark (made on first need; shared by every enemy that wears it).
static func material() -> ShaderMaterial:
	if _material == null:
		_shader = Shader.new()
		_shader.code = SHADER_CODE
		_material = ShaderMaterial.new()
		_material.shader = _shader
		_material.set_shader_parameter(&"band_period", float(BAND_PERIOD))
		_material.set_shader_parameter(&"chalk_px", float(CHALK_PX))
		_material.set_shader_parameter(&"edge_px", float(EDGE_PX))
		_material.set_shader_parameter(&"band_shift", float(BAND_SHIFT))
		_material.set_shader_parameter(&"rim_px", float(RIM_PX))
		_material.set_shader_parameter(&"chalk_colour", CHALK_COLOUR)
		_material.set_shader_parameter(&"ink_colour", INK_COLOUR)
	return _material


## The CPU twin of the shader, for tests and tools: what the mark makes of the art pixel at `local` (art px from the
## enemy's feet point, y down) of an opaque texel - 0 = the sheet's own colour, 1 = ink, 2 = chalk.
static func paint_at(local: Vector2i) -> int:
	var band: int = posmod(local.x + local.y + BAND_SHIFT, BAND_PERIOD)
	if band >= CHALK_PX + EDGE_PX * 2:
		return 0
	return 2 if band >= EDGE_PX and band < EDGE_PX + CHALK_PX else 1
