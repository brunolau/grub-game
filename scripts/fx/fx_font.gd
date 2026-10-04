class_name FxFont
extends RefCounted
## The white outlined HUD capitals (ASSET_MANIFEST.md 12 `fonts/font_hud.png`) for text drawn into the level:
## score pop-ups and code-stone characters. The picture sheet is turned into a font by the ui module
## (`resources/ui/font_hud.fnt`); while that resource is missing the 8 px pixel TTF of the art set is used.

const HUD_FONT_PATH: String = "res://resources/ui/font_hud.fnt"
const FALLBACK_FONT_PATH: String = "res://assets/fonts/press_start_2p.ttf"
## Native pixel size of the HUD font, and the size the fallback is drawn at so that it matches.
const SIZE: int = 20
const FALLBACK_SIZE: int = 16

static var _font: Font = null
static var _size: int = SIZE


## The font to draw with (loaded once).
static func get_font() -> Font:
	if _font == null:
		if ResourceLoader.exists(HUD_FONT_PATH):
			_font = load(HUD_FONT_PATH) as Font
			_size = SIZE
		if _font == null:
			_font = load(FALLBACK_FONT_PATH) as Font
			_size = FALLBACK_SIZE
	return _font


## Pixel size to draw the font at.
static func get_size() -> int:
	get_font()
	return _size


## Width of `text` in art px.
static func width(text: String) -> int:
	return int(get_font().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, get_size()).x)


## Draw `text` on `canvas` centred on x = `center_x` with its baseline at `baseline_y` (local art px).
static func draw_centered(canvas: CanvasItem, text: String, center_x: int, baseline_y: int, color: Color) -> void:
	var font: Font = get_font()
	var x: int = center_x - (width(text) >> 1)
	canvas.draw_string(font, Vector2(x, baseline_y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, get_size(), color)
