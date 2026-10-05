class_name UiKit
extends RefCounted
## Shared look of every menu, screen and overlay (docs/ARCHITECTURE.md 8.6, ASSET_MANIFEST.md 12).
##
## Owner: ui. One place for fonts, colours, the theme, texture cells, safe-area margins and the translation
## catalogue, so that every screen is built from the same parts. All sizes are art px (the root viewport is
## 640 x 360 or larger, ARCHITECTURE.md 2); nothing here assumes a view size.

## Text styles of [method label].
enum Style {
	HUD,     ## white 16 px capitals with a dark outline (font_hud): menu items, counters
	TITLE,   ## carved-stone capitals (font_title): headings
	DIGITS,  ## big stone digits (font_digits_big): tally score
	BODY,    ## proportional pixel sans with lower case (22 px): descriptions, credits
	SMALL,   ## the same face at 11 px: fine print
	MONO,    ## 8 px bitmap-style face: key caps
}

const COL_INK: Color = Color("272018")        ## the 2 px outline colour of all art (manifest 1)
const COL_TEXT: Color = Color("ffffff")
const COL_FOCUS: Color = Color("ffd75e")      ## focused / highlighted text
const COL_PRESSED: Color = Color("ffa52e")
const COL_DIM: Color = Color(1.0, 1.0, 1.0, 0.5)
const COL_CREAM: Color = Color("fff1cf")      ## body text
const COL_SHADE: Color = Color(0.153, 0.125, 0.094, 0.72)  ## translucent ink for dimming layers
const COL_GOOD: Color = Color("8fde5d")
const COL_BAD: Color = Color("ff6b5a")

## Distance of UI from the screen edge (the mock HUD sits 8 px in); at least 16 px on phones (manifest 12).
const MARGIN: int = 8
const MARGIN_MOBILE: int = 16
## Smallest touch target (ARCHITECTURE.md 11).
const TOUCH_TARGET: int = 56

const SIZE_HUD: int = 20
const SIZE_TITLE: int = 36
const SIZE_DIGITS: int = 40
const SIZE_BODY: int = 22
const SIZE_SMALL: int = 11
const SIZE_MONO: int = 8
## Extra px after every space of the SMALL style: the face's own space is only 2 px wide at 11 px, so words ran
## together ("Score0000400").
const SMALL_WORD_SPACING: int = 2

const FONT_HUD: String = "res://resources/ui/font_hud.fnt"
const FONT_TITLE: String = "res://resources/ui/font_title.fnt"
const FONT_DIGITS: String = "res://resources/ui/font_digits_big.fnt"
const FONT_BODY: String = "res://assets/fonts/pixelify_sans.ttf"
const FONT_MONO: String = "res://assets/fonts/press_start_2p.ttf"

const TEX_PANEL: String = "res://assets/ui/panel.png"
const TEX_ICONS: String = "res://assets/ui/icons.png"
const TEX_HERO: String = "res://assets/sprites/player/hero.png"
const TEX_LETTERS: String = "res://assets/sprites/items/letters.png"
const TEX_FOOD: String = "res://assets/sprites/items/food.png"
const TEX_PICKUPS: String = "res://assets/sprites/items/pickups.png"

## Cells of `ui/icons.png` used by the menus (manifest 12: 0 up, 1 right, 2 down, 3 left, 4 cross, 5 exclaim,
## 6 question, 7 sword, 8 shield, 9 heart, 10 skull, 11 fruit).
const ICON_UP: int = 0
const ICON_RIGHT: int = 1
const ICON_DOWN: int = 2
const ICON_FRUIT: int = 11
const ICON_CELL: int = 32

const PANEL_MARGIN: int = 16
const LOCALE_DIR: String = "res://locale"

static var _fonts: Dictionary = {}
static var _textures: Dictionary = {}
static var _theme: Theme = null
static var _locale_ready: bool = false
static var _focus_muted: bool = false


# =================================================================================================================
# Translations
# =================================================================================================================

## Register every catalogue of `res://locale` with the TranslationServer (once). Called by every ui scene before
## it creates text, because the project file lists no translations (adding a language = adding one .po file).
static func ensure_locale() -> void:
	if _locale_ready:
		return
	_locale_ready = true
	# ResourceLoader lists the catalogues under their source names in the editor and in exported builds alike.
	var names: PackedStringArray = ResourceLoader.list_directory(LOCALE_DIR)
	names.sort()
	for file_name: String in names:
		if file_name.get_extension() != "po":
			continue
		var catalogue: Translation = load(LOCALE_DIR + "/" + file_name) as Translation
		if catalogue != null:
			TranslationServer.add_translation(catalogue)


## Locale codes that have a catalogue, sorted ("en", ...).
static func available_locales() -> PackedStringArray:
	ensure_locale()
	var result: PackedStringArray = TranslationServer.get_loaded_locales()
	result.sort()
	return result


# =================================================================================================================
# Fonts, textures, theme
# =================================================================================================================

## Font of a text style. The three bitmap fonts fall back to the TTF faces for characters they do not have.
static func font(style: int) -> Font:
	if style == Style.SMALL:
		return _small_font()
	var path: String = FONT_HUD
	match style:
		Style.TITLE:
			path = FONT_TITLE
		Style.DIGITS:
			path = FONT_DIGITS
		Style.BODY, Style.SMALL:
			path = FONT_BODY
		Style.MONO:
			path = FONT_MONO
	if _fonts.has(path):
		return _fonts[path]
	var loaded: Font = null
	if ResourceLoader.exists(path):
		loaded = load(path) as Font
	if loaded == null:
		loaded = ThemeDB.fallback_font
	elif path == FONT_HUD or path == FONT_TITLE:
		var file: FontFile = loaded as FontFile
		if file != null and ResourceLoader.exists(FONT_MONO):
			var fallbacks: Array[Font] = [load(FONT_MONO) as Font]
			file.fallbacks = fallbacks
	_fonts[path] = loaded
	return loaded


## The body face with wider word spacing for the SMALL style (cached).
static func _small_font() -> Font:
	const KEY: String = "small"
	if _fonts.has(KEY):
		return _fonts[KEY]
	var small: FontVariation = FontVariation.new()
	small.base_font = font(Style.BODY)
	small.spacing_space = SMALL_WORD_SPACING
	_fonts[KEY] = small
	return small


## Pixel size to request for a text style.
static func font_size(style: int) -> int:
	match style:
		Style.TITLE:
			return SIZE_TITLE
		Style.DIGITS:
			return SIZE_DIGITS
		Style.BODY:
			return SIZE_BODY
		Style.SMALL:
			return SIZE_SMALL
		Style.MONO:
			return SIZE_MONO
		_:
			return SIZE_HUD


## A texture by path, cached; null when the file does not exist.
static func tex(path: String) -> Texture2D:
	if _textures.has(path):
		return _textures[path]
	var texture: Texture2D = null
	if ResourceLoader.exists(path):
		texture = load(path) as Texture2D
	_textures[path] = texture
	return texture


## One cell of a uniform sprite sheet as a texture (`index` is row-major, manifest 1).
static func cell(path: String, cell_size: Vector2i, index: int) -> AtlasTexture:
	var atlas: AtlasTexture = AtlasTexture.new()
	var sheet: Texture2D = tex(path)
	atlas.atlas = sheet
	var columns: int = 1
	if sheet != null:
		columns = maxi(1, sheet.get_width() / cell_size.x)
	atlas.region = Rect2(
		float((index % columns) * cell_size.x), float((index / columns) * cell_size.y),
		float(cell_size.x), float(cell_size.y)
	)
	return atlas


## One of the twelve menu icons (ICON_*).
static func icon(index: int) -> AtlasTexture:
	return cell(TEX_ICONS, Vector2i(ICON_CELL, ICON_CELL), index)


## The theme shared by every ui scene.
static func theme() -> Theme:
	if _theme != null:
		return _theme
	var result: Theme = Theme.new()
	result.default_font = font(Style.HUD)
	result.default_font_size = SIZE_HUD
	result.set_color(&"font_color", &"Label", COL_TEXT)
	result.set_constant(&"line_spacing", &"Label", 2)
	var empty: StyleBoxEmpty = StyleBoxEmpty.new()
	for state: StringName in [&"normal", &"hover", &"pressed", &"focus", &"disabled", &"hover_pressed"]:
		result.set_stylebox(state, &"Button", empty)
	result.set_color(&"font_color", &"Button", COL_TEXT)
	result.set_color(&"font_hover_color", &"Button", COL_TEXT)
	result.set_color(&"font_focus_color", &"Button", COL_FOCUS)
	result.set_color(&"font_pressed_color", &"Button", COL_PRESSED)
	result.set_color(&"font_hover_pressed_color", &"Button", COL_PRESSED)
	result.set_color(&"font_disabled_color", &"Button", COL_DIM)
	result.set_stylebox(&"panel", &"ScrollContainer", empty)
	var track: StyleBoxFlat = StyleBoxFlat.new()
	track.bg_color = Color(COL_INK, 0.45)
	track.content_margin_left = 3.0
	track.content_margin_right = 3.0
	var grabber: StyleBoxFlat = StyleBoxFlat.new()
	grabber.bg_color = COL_CREAM
	grabber.content_margin_left = 3.0
	grabber.content_margin_right = 3.0
	var grabber_lit: StyleBoxFlat = grabber.duplicate() as StyleBoxFlat
	grabber_lit.bg_color = COL_FOCUS
	result.set_stylebox(&"scroll", &"VScrollBar", track)
	result.set_stylebox(&"scroll_focus", &"VScrollBar", track)
	result.set_stylebox(&"grabber", &"VScrollBar", grabber)
	result.set_stylebox(&"grabber_highlight", &"VScrollBar", grabber_lit)
	result.set_stylebox(&"grabber_pressed", &"VScrollBar", grabber_lit)
	_theme = result
	return result


# =================================================================================================================
# Building blocks
# =================================================================================================================

## A label in one of the text styles. `text` is a translation key (or already final text).
static func label(text: String, style: int = Style.HUD, align: int = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var result: Label = Label.new()
	result.text = text
	result.horizontal_alignment = align as HorizontalAlignment
	style_label(result, style)
	return result


## Apply a text style to an existing label.
static func style_label(target: Label, style: int) -> void:
	target.add_theme_font_override(&"font", font(style))
	target.add_theme_font_size_override(&"font_size", font_size(style))
	match style:
		Style.BODY:
			target.add_theme_color_override(&"font_color", COL_CREAM)
			target.add_theme_color_override(&"font_outline_color", COL_INK)
			target.add_theme_constant_override(&"outline_size", 6)
			target.add_theme_constant_override(&"line_spacing", -2)
		Style.SMALL:
			target.add_theme_color_override(&"font_color", COL_CREAM)
			target.add_theme_color_override(&"font_outline_color", COL_INK)
			target.add_theme_constant_override(&"outline_size", 4)
			target.add_theme_constant_override(&"line_spacing", 0)
		Style.MONO:
			target.add_theme_color_override(&"font_color", COL_CREAM)
		Style.TITLE, Style.DIGITS:
			target.add_theme_constant_override(&"line_spacing", 0)


## The menu / dialog panel (nine-patch of `ui/panel.png`). Put the content in a MarginContainer on top of it, or
## use [method panel_box].
static func panel() -> NinePatchRect:
	var result: NinePatchRect = NinePatchRect.new()
	result.texture = tex(TEX_PANEL)
	result.patch_margin_left = PANEL_MARGIN
	result.patch_margin_top = PANEL_MARGIN
	result.patch_margin_right = PANEL_MARGIN
	result.patch_margin_bottom = PANEL_MARGIN
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return result


## A panel that sizes itself around `content` with `padding` art px on every side.
static func panel_box(content: Control, padding: int = 14) -> PanelContainer:
	var box: PanelContainer = PanelContainer.new()
	var style: StyleBoxTexture = StyleBoxTexture.new()
	style.texture = tex(TEX_PANEL)
	style.set_texture_margin_all(float(PANEL_MARGIN))
	style.set_content_margin_all(float(padding))
	box.add_theme_stylebox_override(&"panel", style)
	box.add_child(content)
	return box


## A flat ink-coloured box (key caps, value fields, translucent text plates).
static func plate(color: Color = COL_SHADE, padding: int = 4) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = color
	style.set_content_margin_all(float(padding))
	style.anti_aliasing = false
	return style


## A texture rectangle that keeps the picture's own size (pixel art is never stretched).
static func picture(texture: Texture2D) -> TextureRect:
	var rect: TextureRect = TextureRect.new()
	rect.texture = texture
	rect.stretch_mode = TextureRect.STRETCH_KEEP
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


## Give `control` the keyboard / gamepad focus without the cursor sound (first focus of a screen).
static func focus_silently(control: Control) -> void:
	if control == null or not control.is_inside_tree():
		return
	_focus_muted = true
	control.grab_focus()
	_focus_muted = false


## Cursor sound of a focus change; silent during [method focus_silently].
static func play_focus_sound() -> void:
	if not _focus_muted:
		Audio.play_sfx(Sfx.MENU_MOVE)


## Height of a menu row: taller on phones so that every row is a comfortable touch target.
static func row_height() -> int:
	return 40 if OS.has_feature("mobile") else 28


# =================================================================================================================
# Safe area
# =================================================================================================================

## Margins (left, top, right, bottom as x, y, z, w; art px) that keep UI inside the display's safe area: notches,
## rounded corners and system bars on phones, plus the base margin of the mock-ups.
static func safe_margins(viewport: Viewport) -> Vector4i:
	var base: int = MARGIN
	var margins: Vector4i = Vector4i(base, base, base, base)
	if viewport == null or not OS.has_feature("mobile"):
		return margins
	base = MARGIN_MOBILE
	margins = Vector4i(base, base, base, base)
	var window_size: Vector2 = Vector2(DisplayServer.window_get_size())
	var view_size: Vector2 = viewport.get_visible_rect().size
	if window_size.x <= 0.0 or window_size.y <= 0.0 or view_size.x <= 0.0:
		return margins
	var device_px_per_art: float = window_size.x / view_size.x
	var safe: Rect2 = Rect2(DisplayServer.get_display_safe_area())
	if safe.size.x <= 0.0 or safe.size.y <= 0.0:
		return margins
	margins.x = maxi(base, ceili(safe.position.x / device_px_per_art))
	margins.y = maxi(base, ceili(safe.position.y / device_px_per_art))
	margins.z = maxi(base, ceili((window_size.x - safe.end.x) / device_px_per_art))
	margins.w = maxi(base, ceili((window_size.y - safe.end.y) / device_px_per_art))
	return margins


## Write safe-area margins into a MarginContainer.
static func apply_safe_margins(container: MarginContainer) -> void:
	var margins: Vector4i = safe_margins(container.get_viewport())
	container.add_theme_constant_override(&"margin_left", margins.x)
	container.add_theme_constant_override(&"margin_top", margins.y)
	container.add_theme_constant_override(&"margin_right", margins.z)
	container.add_theme_constant_override(&"margin_bottom", margins.w)


# =================================================================================================================
# Text helpers
# =================================================================================================================

## Score as shown everywhere: seven digits with leading zeros (GAMEPLAY.md 2).
static func score_text(score: int) -> String:
	return "%07d" % clampi(score, 0, 9999999)


## "1-2" for a campaign level, "" for levels without a world number (bonus stages, test levels).
static func level_number(level_id: StringName) -> String:
	var world: int = int(Levels.get_value(level_id, "world", 0))
	var stage: int = int(Levels.get_value(level_id, "stage", 0))
	if world <= 0 or stage <= 0:
		return ""
	return "%d-%d" % [world, stage]


## Display name of a level (its `name` key, which doubles as a translation key).
static func level_name(level_id: StringName) -> String:
	var raw: String = str(Levels.get_value(level_id, "name", String(level_id)))
	return TranslationServer.translate(raw)


## True for the "confirm" inputs of screens that only wait for a button: accept, attack, jump, or a tap / click.
static func is_accept(event: InputEvent) -> bool:
	if event.is_echo():
		return false
	if event.is_action_pressed(&"ui_accept") or event.is_action_pressed(Defs.ACT_ATTACK) \
			or event.is_action_pressed(Defs.ACT_JUMP):
		return true
	return is_tap(event)


## True for a left click or a tap (touches arrive as emulated mouse clicks).
static func is_tap(event: InputEvent) -> bool:
	var button: InputEventMouseButton = event as InputEventMouseButton
	return button != null and button.pressed and button.button_index == MOUSE_BUTTON_LEFT


## True for the "back" inputs.
static func is_cancel(event: InputEvent) -> bool:
	return not event.is_echo() and event.is_action_pressed(&"ui_cancel")
