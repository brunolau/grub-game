class_name SignBoard
extends SimEntity
## `objects/sign` (`text=<translation key>`): a hint board. While the hero stands near it a wooden board with the
## text rises above it.
##
## The rule (when the text shows) is the objects module's and runs in the tick; how it looks is the ui module's: the
## board is the menu panel (`ui/panel.png`, nine-patch) with a wooden tail that points down at the sign, and the
## text is set like the in-level hint panel of the HUD (HUD face in cream, the same line spacing and balanced
## wrapping, the same fade). The board lives in the world, so it has no safe-area margins; it is kept inside the
## view and below the HUD row, so a sign near an edge of the view stays readable.

## Widest text line (art px) and the room around the text inside the board.
const TEXT_MAX_W: float = 360.0
const PAD_X: int = 14
const PAD_Y: int = 10
const LINE_SPACING: int = 4
## Lowest edge of the board above the feet point (art px): with the tail under it, clear of the hero's head.
const BOARD_BOTTOM_ART: float = -90.0
## Distance the board keeps from the left / right edge of the view, and the top edge it never goes above (under
## the HUD row of lives, hearts and letters), view px.
const VIEW_EDGE: float = 8.0
const VIEW_TOP: float = 56.0
## Fade in / out, like the HUD's hint panel.
const FADE_SECONDS: float = 0.18
## Colours of ui/panel.png's edge: outline, rim and face. The tail is drawn with them.
const COL_EDGE: Color = Color8(46, 39, 31)
const COL_RIM: Color = Color8(108, 61, 40)
const COL_FACE: Color = Color8(201, 109, 46)
## Draw order of the board: above the front tiles and the weather of the level.
const BOARD_Z: int = Defs.Z_FRONT_TILES + 10
## Half-width of the tail where it leaves the board, and how far the tail keeps from the board's corners.
const TAIL_HALF: int = 10
const TAIL_INSET: float = 18.0

## Translation key of the text.
var text_key: String = ""

var _label: Label = null
var _tail: Control = null
var _near: bool = false
var _alpha: float = 0.0


func _init() -> void:
	z_index = Defs.Z_OBJECTS
	# The reading area is wider than the board.
	set_box(Vector3i(48, 24, 24))


func _sim_phases() -> PackedInt32Array:
	return PackedInt32Array([Defs.Phase.CONTACT_ITEMS])


func _apply_params(params: Dictionary) -> void:
	text_key = str(params.get("text", ""))
	_label = get_node_or_null(^"Text") as Label
	if _label == null:
		return
	_label.text = tr(text_key)
	_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_font_override(&"font", UiKit.font(UiKit.Style.HUD))
	_label.add_theme_font_size_override(&"font_size", UiKit.SIZE_HUD)
	_label.add_theme_color_override(&"font_color", UiKit.COL_CREAM)
	_label.add_theme_constant_override(&"line_spacing", LINE_SPACING)
	_label.add_theme_stylebox_override(&"normal", _board_style())
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UiKit.wrap_balanced(_label, TEXT_MAX_W)
	_label.position = Vector2(roundf(-_label.size.x * 0.5), BOARD_BOTTOM_ART - _label.size.y)
	# In front of everything in the level (actors, effects, weather, front tiles): it is text to read.
	_label.z_as_relative = false
	_label.z_index = BOARD_Z
	_label.visible = false
	_label.modulate.a = 0.0
	if _tail != null:
		return
	_tail = Control.new()
	_tail.name = "Tail"
	_tail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tail.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tail.draw.connect(_draw_tail)
	_label.add_child(_tail)


func _sim_tick(_phase: int) -> void:
	if _label == null or text_key.is_empty():
		return
	var level: LevelBase = Game.level
	var near: bool = level != null and level.player != null and not level.player.dead \
			and Overlap.body(self, level.player, level.player)
	_near = near
	if near:
		_label.visible = true


## Dozing (SimEntity, ARCHITECTURE.md 11): while the hero is not at the board its tick only repeats the overlap
## test, which fails while he is far away (the fade runs in _process, not in the tick).
func _doze_area() -> Rect2i:
	return _doze_box()


func _can_doze() -> bool:
	return not _near


## Presentation only: fade the board and keep it inside the view.
func _process(delta: float) -> void:
	if _label == null or not _label.visible:
		return
	_alpha = move_toward(_alpha, 1.0 if _near else 0.0, delta / FADE_SECONDS)
	_label.modulate.a = _alpha
	if _alpha <= 0.0 and not _near:
		_label.visible = false
		return
	_place_board()


## The wooden board: ui/panel.png as a nine-patch around the text.
func _board_style() -> StyleBoxTexture:
	var style: StyleBoxTexture = StyleBoxTexture.new()
	style.texture = UiKit.tex(UiKit.TEX_PANEL)
	style.set_texture_margin_all(float(UiKit.PANEL_MARGIN))
	style.content_margin_left = float(PAD_X)
	style.content_margin_right = float(PAD_X)
	style.content_margin_top = float(PAD_Y)
	style.content_margin_bottom = float(PAD_Y)
	return style


## Centre the board over the sign, then move it inside the view (left / right edge, below the HUD row).
func _place_board() -> void:
	var canvas: Transform2D = get_global_transform_with_canvas()
	var scale_x: float = maxf(absf(canvas.get_scale().x), 0.001)
	var scale_y: float = maxf(absf(canvas.get_scale().y), 0.001)
	var origin: Vector2 = canvas.origin
	var view: Vector2 = get_viewport_rect().size
	var board: Vector2 = _label.size * Vector2(scale_x, scale_y)
	var left: float = origin.x - board.x * 0.5
	left = clampf(left, VIEW_EDGE, maxf(VIEW_EDGE, view.x - VIEW_EDGE - board.x))
	var top: float = maxf(origin.y + BOARD_BOTTOM_ART * scale_y - board.y, VIEW_TOP)
	var target: Vector2 = Vector2(roundf((left - origin.x) / scale_x), roundf((top - origin.y) / scale_y))
	if target != _label.position:
		_label.position = target
		_tail.queue_redraw()


## Board rectangle in the sign's own coordinates (art px), e.g. for tests and previews.
func get_board_rect() -> Rect2:
	return Rect2(_label.position, _label.size) if _label != null else Rect2()


## The tail under the board, pointing at the sign: a 45-degree wedge in the board's outline, rim and face colours
## that opens the board's bottom edge (pixel rows, no anti-aliasing).
func _draw_tail() -> void:
	var size: Vector2 = _label.size
	var center: float = clampf(roundf(-_label.position.x), TAIL_INSET, size.x - TAIL_INSET)
	var bottom: float = size.y
	# Open the board's bottom edge (its shade and rim rows) above the tail.
	_tail.draw_rect(Rect2(center - float(TAIL_HALF - 3), bottom - 5.0, float(2 * TAIL_HALF - 6), 3.0), COL_FACE)
	for k: int in TAIL_HALF + 1:
		var y: float = bottom - 2.0 + float(k)
		var outline: int = TAIL_HALF - k
		if outline <= 0:
			break
		_tail.draw_rect(Rect2(center - float(outline), y, float(2 * outline), 1.0), COL_EDGE)
		if outline > 2:
			_tail.draw_rect(Rect2(center - float(outline - 2), y, float(2 * (outline - 2)), 1.0), COL_RIM)
		if outline > 4:
			_tail.draw_rect(Rect2(center - float(outline - 4), y, float(2 * (outline - 4)), 1.0), COL_FACE)
