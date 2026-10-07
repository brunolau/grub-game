class_name SignBoard
extends SimEntity
## `objects/sign` (`text=<translation key>`): a hint board. While the hero stands near it a wooden board with the
## text rises above it.
##
## The rule (when the text shows) is the objects module's and runs in the tick; how it looks is the ui module's: the
## board is the menu panel (`ui/panel.png`, nine-patch) with a wooden tail that points down at the sign, and the
## text is set like the in-level hint panel of the HUD (HUD face in cream, balanced wrapping, the same fade; 2.0: a
## tighter line spacing). The board lives in the world, so it has no safe-area margins; it is kept inside the view
## and below the HUD row, so a sign near an edge of the view stays readable.
##
## Read time (presentation only, the tick rule is unchanged): once shown, a board stays at least READ_SECONDS, and
## LINGER_SECONDS after the hero left the sign, while the sign is in or near the view (the board waits at the view's
## edge when the camera pages on) - a hero walking past at full speed overlaps it for half a second. The level's
## intro banner gives way to a board that appears under it (Hud.dismiss_intro()), so the first sign of a stage is
## never hidden by the stage name.
##
## 2.0 (G1 follow-up; presentation only, the tick rule and the digest are untouched):
## - **One board at a time**: the board a hero came to last is in front; any other board - held for its read time or
##   read by the partner - fades out while it shows, so two boards never cover each other (co-op signs stand a few
##   columns apart). When the front board's reader has left, a board a hero still stands at comes back to the front.
## - **Never over a hero or the HUD**: a board tries the places of [enum Place] in order - above the sign centred on
##   it, above it shifted left or right (the tail still points at the sign from near the board's corner), then
##   hanging under the sign (centred, left, right; the tail points up) - and takes the first whose rectangle keeps
##   clear of every hero's body (grown by HERO_ROOM; eggs too). A board that the HUD row or a panel would push down
##   over its own sign (a sign near the top of the view) never stands there with its tail pointing away: it hangs.
##   It keeps its place while that stays clear, and moves only after a hero stayed behind it for MOVE_SECONDS (a hero
##   jumping through it does not make it jump about); while a hero is behind it the board fades to COVER_ALPHA, so
##   he shows through. When no place keeps clear (heroes above and below the sign) it stays where it covers the
##   least, translucent. Its top edge never goes above the HUD
##   row (Hud.get_row_bottom(), so the larger safe area of a phone counts) or the boss bar during a fight, and the
##   board and its tail keep clear of the HUD's party panels (Hud.get_party_panel_rects(): P2's co-op panel under the
##   letters, the versus corners). [method plan_board] is the pure geometry of it.
## - **Small boards**: tight padding and line spacing; a sign's text should take at most MAX_LINES lines of the board
##   (LEVEL_DESIGN.md 15: about 60 characters); [method text_lines] measures a text the way the board wraps it.

## The places a board tries, in this order (see the class comment).
enum Place { ABOVE, ABOVE_LEFT, ABOVE_RIGHT, BELOW, BELOW_LEFT, BELOW_RIGHT }

## Widest text line (art px) and the room around the text inside the board.
const TEXT_MAX_W: float = 360.0
const PAD_X: int = 12
const PAD_Y: int = 6
const LINE_SPACING: int = 2
## Most lines a sign's text should take on its board (designers' rule, LEVEL_DESIGN.md 15).
const MAX_LINES: int = 3
## Lowest edge of the board above the feet point (art px): with the tail under it, clear of the hero's head.
const BOARD_BOTTOM_ART: float = -90.0
## Distance the board keeps from the left / right / bottom edge of the view, and the top edge it never goes above
## (under the HUD row of lives, hearts and letters; the HUD's own row height wins when it is lower), view px.
const VIEW_EDGE: float = 8.0
const VIEW_TOP: float = 56.0
## Fade in / out, like the HUD's hint panel.
const FADE_SECONDS: float = 0.18
## Least time a board stays up once shown, and how long it stays after the hero left the sign (seconds).
const READ_SECONDS: float = 2.5
const LINGER_SECONDS: float = 1.0
## How far beyond the view's edge (view px) the sign of a held board may be (the board waits at the edge).
const HOLD_MARGIN: float = 200.0
## Top edge of the board while a boss bar shows under the hearts (view px): the board stays below the bar, and a
## held board gives way to the fight.
const VIEW_TOP_BOSS: float = 96.0
## Gap a board and its tail keep from the HUD's party panels and the boss bar (view px).
const P2_PANEL_GAP: float = 4.0
## Top edge of a board hanging under its sign, below the sign's feet point (art px).
const BOARD_BELOW_ART: float = 14.0
## Top of the sign's picture over its feet point (art px; sign_board.png is 24 art px tall): a board standing above
## the sign keeps its tail's tip at or over it, so a board pushed down by the HUD row or a panel never ends below the
## sign with its tail pointing away from it - it hangs under the sign instead.
const SIGN_TOP_ART: float = -24.0
## Room a board keeps around every hero's body (view px), how long a hero may stay behind a board before it moves
## to a clear place (seconds), and its alpha while a hero is behind it.
const HERO_ROOM: float = 6.0
const MOVE_SECONDS: float = 0.25
const COVER_ALPHA: float = 0.35
## Most px the top limit is probed below VIEW_TOP for the HUD row's bottom edge, from a HUD without get_row_bottom().
const ROW_PROBE_MAX: int = 64
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
## Seconds since the board appeared, and since the hero left the sign.
var _shown_for: float = 0.0
var _away_for: float = 0.0
## True while the HUD shows a boss bar.
var _boss_bar: bool = false
## Presentation: a hero was at the board on the last frame; the board in front (the one a hero came to last).
var _was_near: bool = false
static var _front: SignBoard = null
## Presentation: the board hangs under the sign; its place (a Place, -1 = not placed since it appeared); seconds a
## hero has been behind it while a clear place waits; true while a hero is behind it.
var _flipped: bool = false
var _place: int = -1
var _cover_for: float = 0.0
var _covering: bool = false


## A place of a board: which [enum Place], its rectangle (view px) and how much of the heroes' bodies it covers
## (view px squared; 0 = clear). See [method plan_board].
class BoardPlace:
	extends RefCounted
	var place: int = 0
	var rect: Rect2 = Rect2()
	var covered: float = 0.0


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
	# Shown while any living hero is at the board (2.0, TECH_AUDIT.md 3.12; 1.0: the one hero).
	var level: LevelBase = Game.level
	var near: bool = false
	if level != null:
		for hero: PlayerBase in level.contact_order():
			if not hero.dead and Overlap.body(self, hero, hero):
				near = true
				break
	_near = near
	if near:
		_label.visible = true


## Dozing (SimEntity, ARCHITECTURE.md 11): while the hero is not at the board its tick only repeats the overlap
## test, which fails while he is far away (the fade runs in _process, not in the tick).
func _doze_area() -> Rect2i:
	return _doze_box()


func _can_doze() -> bool:
	return not _near


## Presentation only: fade the board, hold it for the read time, keep it inside the view and clear of the heroes.
func _process(delta: float) -> void:
	if _label == null or not _label.visible:
		_shown_for = 0.0
		_place = -1
		return
	var hud: Node = get_tree().get_first_node_in_group(Defs.GROUP_HUD)
	if _shown_for == 0.0 and hud != null and hud.has_method(&"dismiss_intro"):
		hud.call(&"dismiss_intro")
	_boss_bar = hud != null and hud.has_method(&"is_boss_bar_visible") and bool(hud.call(&"is_boss_bar_visible"))
	_shown_for += delta
	_away_for = 0.0 if _near else _away_for + delta
	var front_valid: bool = is_instance_valid(_front) and _front.is_inside_tree()
	if _near and (not _was_near or not front_valid or not _front._near):
		_front = self
		front_valid = true
	_was_near = _near
	var held: bool = (_shown_for < READ_SECONDS or _away_for < LINGER_SECONDS) and _sign_in_view() and not _boss_bar
	var behind: bool = front_valid and _front != self and _front.is_board_shown()
	var wanted: bool = (_near or held) and not behind
	_place_board(hud, delta)
	var shown: float = COVER_ALPHA if _covering else 1.0
	_alpha = move_toward(_alpha, shown if wanted else 0.0, delta / FADE_SECONDS)
	_label.modulate.a = _alpha
	if _alpha <= 0.0 and not wanted:
		_label.visible = false
		_shown_for = 0.0
		_place = -1


## True while the sign is inside the view or less than HOLD_MARGIN beyond its edge: the camera pages ahead of a
## running hero, so a held board waits at the view's edge for the rest of its read time, but never follows a sign
## that is far away.
func _sign_in_view() -> bool:
	var x: float = get_global_transform_with_canvas().origin.x
	return x >= -HOLD_MARGIN and x <= get_viewport_rect().size.x + HOLD_MARGIN


## True while the board is on screen (also while it fades or is held for the read time).
func is_board_shown() -> bool:
	return _label != null and _label.visible and _alpha > 0.0


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


## Put the board at its place (see the class comment): the place it has while that keeps clear of the heroes, else
## the first clear one once a hero stayed behind it for MOVE_SECONDS (at once when it has no place yet). Sets
## `_covering` while a hero is behind the board.
func _place_board(hud: Node, delta: float) -> void:
	var canvas: Transform2D = get_global_transform_with_canvas()
	var zoom: Vector2 = Vector2(maxf(absf(canvas.get_scale().x), 0.001), maxf(absf(canvas.get_scale().y), 0.001))
	var origin: Vector2 = canvas.origin
	var view: Vector2 = get_viewport_rect().size
	var board: Vector2 = _label.size * zoom
	var top: float = _top_limit(hud)
	var panels: Array[Rect2] = _panel_rects(hud)
	var bodies: Array[Rect2] = hero_bodies()
	var plan: BoardPlace = plan_board(origin, board, view, zoom.y, top, panels, bodies, _place)
	if _place >= 0 and plan.place != _place:
		var kept: BoardPlace = board_place(_place, origin, board, view, zoom.y, top, panels, bodies)
		if kept != null:
			_cover_for += delta
			if _cover_for < MOVE_SECONDS:
				plan = kept
	if plan.place != _place or plan.covered <= 0.0:
		_cover_for = 0.0
	_place = plan.place
	_covering = plan.covered > 0.0
	var flip: bool = plan.place >= Place.BELOW
	var target: Vector2 = ((plan.rect.position - origin) / zoom).round()
	if target != _label.position or flip != _flipped:
		_label.position = target
		_flipped = flip
		_tail.queue_redraw()


## Highest the board's top edge may be (view px): under the HUD row (VIEW_TOP, or lower where the HUD says its row
## ends lower, e.g. inside a phone's larger safe area) and under the boss bar during a fight.
func _top_limit(hud: Node) -> float:
	var top: float = VIEW_TOP
	if hud != null and hud.has_method(&"get_row_bottom"):
		top = maxf(top, float(hud.call(&"get_row_bottom")))
	elif hud != null and hud.has_method(&"is_under_row"):
		var steps: int = 0
		while steps < ROW_PROBE_MAX and bool(hud.call(&"is_under_row", top)):
			top += 1.0
			steps += 1
	if _boss_bar:
		top = maxf(top, VIEW_TOP_BOSS)
		if hud.has_method(&"get_boss_bar_rect"):
			top = maxf(top, (hud.call(&"get_boss_bar_rect") as Rect2).end.y + P2_PANEL_GAP)
	return top


## The HUD's party panels on screen (view px): Hud.get_party_panel_rects() - P2's co-op panel, the versus corner
## panels - or, from a HUD without it, P2's panel (Hud.get_p2_panel()).
static func _panel_rects(hud: Node) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	if hud == null:
		return rects
	if hud.has_method(&"get_party_panel_rects"):
		for rect: Rect2 in hud.call(&"get_party_panel_rects"):
			rects.append(rect)
		return rects
	if hud.has_method(&"get_p2_panel"):
		var panel: Control = hud.call(&"get_p2_panel") as Control
		if panel != null and panel.is_visible_in_tree():
			rects.append(panel.get_global_rect())
	return rects


## The bodies of the living heroes of the running level on screen (view px; eggs too): their contact boxes.
static func hero_bodies() -> Array[Rect2]:
	var bodies: Array[Rect2] = []
	var level: LevelBase = Game.level
	if level == null:
		return bodies
	for hero: PlayerBase in level.heroes:
		if not is_instance_valid(hero) or not hero.is_inside_tree() or hero.dead:
			continue
		var canvas: Transform2D = hero.get_global_transform_with_canvas()
		var zoom: Vector2 = Vector2(absf(canvas.get_scale().x), absf(canvas.get_scale().y)) * float(Tuning.ART_SCALE)
		var feet: Vector2 = canvas.origin
		bodies.append(Rect2(feet.x - float(hero.box_xo) * zoom.x, feet.y - float(hero.box_h) * zoom.y,
				float(hero.box_w) * zoom.x, float(hero.box_h) * zoom.y))
	return bodies


## Where a board goes (pure geometry in view px; the board and the tests call it). `sign` is the sign's feet point on
## screen, `board` the board's size, `view` the view's size, `art` view px per art px (vertically), `top` the highest
## its top edge may be, `panels` the HUD's party panels, `bodies` the heroes' bodies and `keep` the place the board has
## now (-1: none). Returns `keep` while it keeps clear of every body, else the first clear place of [enum Place]; when
## none is clear, `keep` again (or, without one, the place that covers the least). Never null: when no place fits
## (a board taller than the room above and under its sign) it is the standing place clamped into the view.
static func plan_board(sign: Vector2, board: Vector2, view: Vector2, art: float, top: float, panels: Array[Rect2],
		bodies: Array[Rect2], keep: int = -1) -> BoardPlace:
	var best: BoardPlace = null
	var kept: BoardPlace = null
	for place: int in Place.size():
		var candidate: BoardPlace = board_place(place, sign, board, view, art, top, panels, bodies)
		if candidate == null:
			continue
		if place == keep:
			kept = candidate
		if best == null or candidate.covered < best.covered:
			best = candidate
	if best == null:
		return _place_at(Place.ABOVE, sign, board, view, art, top, panels, bodies, false)
	if kept != null and (kept.covered <= 0.0 or best.covered > 0.0):
		return kept
	return best


## One place of a board (see [method plan_board] for the arguments); null when it does not fit there: a board hanging
## under a sign near the bottom of the view, or a standing board that the HUD row or a panel would push down below
## the sign's top (SIGN_TOP_ART; it hangs under the sign then). Every place keeps the board inside the view's left /
## right edges, under `top`, and clear of every party panel by P2_PANEL_GAP, its tail included (TAIL_HALF art px over
## the top edge of a hanging board, under the bottom edge of a standing one): under a panel of the view's upper half
## that it lies under, above one of the lower half.
static func board_place(place: int, sign: Vector2, board: Vector2, view: Vector2, art: float, top: float,
		panels: Array[Rect2], bodies: Array[Rect2]) -> BoardPlace:
	return _place_at(place, sign, board, view, art, top, panels, bodies, true)


## [method board_place]; `strict` false lets a standing board be pushed down past the sign's top (the last resort of
## [method plan_board]).
static func _place_at(place: int, sign: Vector2, board: Vector2, view: Vector2, art: float, top: float,
		panels: Array[Rect2], bodies: Array[Rect2], strict: bool) -> BoardPlace:
	var x: float = sign.x - board.x * 0.5
	match place % 3:
		1:
			# Left of the sign: the tail leaves the board TAIL_INSET (art px) from its right end.
			x = sign.x + TAIL_INSET * art - board.x
		2:
			x = sign.x - TAIL_INSET * art
	x = clampf(x, VIEW_EDGE, maxf(VIEW_EDGE, view.x - VIEW_EDGE - board.x))
	var hanging: bool = place >= Place.BELOW
	# The tail is drawn in the board's art px: TAIL_HALF art px tall on screen.
	var tail_up: float = float(TAIL_HALF) * art if hanging else 0.0
	var tail_down: float = 0.0 if hanging else float(TAIL_HALF) * art
	var limit: float = top + tail_up
	var floor_y: float = view.y - VIEW_EDGE
	for panel: Rect2 in panels:
		if not panel.has_area() or x >= panel.end.x or x + board.x <= panel.position.x:
			continue
		if panel.get_center().y < view.y * 0.5:
			limit = maxf(limit, panel.end.y + P2_PANEL_GAP + tail_up)
		else:
			floor_y = minf(floor_y, panel.position.y - P2_PANEL_GAP - tail_down)
	var y: float = 0.0
	if not hanging:
		y = clampf(sign.y + BOARD_BOTTOM_ART * art - board.y, limit, maxf(limit, floor_y - board.y))
		if strict and y + board.y + tail_down > sign.y + SIGN_TOP_ART * art + 0.5:
			return null
	else:
		y = maxf(sign.y + BOARD_BELOW_ART * art, limit)
		if y + board.y > floor_y:
			return null
	var result: BoardPlace = BoardPlace.new()
	result.place = place
	result.rect = Rect2(x, y, board.x, board.y)
	for body: Rect2 in bodies:
		var hit: Rect2 = result.rect.intersection(body.grow(HERO_ROOM))
		if hit.has_area():
			result.covered += hit.get_area()
	return result


## Lines `text` (translated) takes on a board: the balanced wrap of the board within TEXT_MAX_W. Designers keep every
## sign within MAX_LINES (LEVEL_DESIGN.md 15).
static func text_lines(text: String) -> int:
	if text.is_empty():
		return 0
	var text_font: Font = UiKit.font(UiKit.Style.HUD)
	var width: float = UiKit.balanced_width(text, text_font, UiKit.SIZE_HUD, TEXT_MAX_W)
	var block: Vector2 = text_font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, width, UiKit.SIZE_HUD)
	return maxi(1, roundi(block.y / maxf(text_font.get_height(UiKit.SIZE_HUD), 1.0)))


## Board rectangle in the sign's own coordinates (art px), e.g. for tests and previews.
func get_board_rect() -> Rect2:
	return Rect2(_label.position, _label.size) if _label != null else Rect2()


## The board's place now (a [enum Place]; -1 while it is not shown), and true while a hero is behind it.
func get_board_place() -> int:
	return _place


func is_covering_a_hero() -> bool:
	return _covering


## The tail under the board, pointing at the sign: a 45-degree wedge in the board's outline, rim and face colours
## that opens the board's bottom edge (pixel rows, no anti-aliasing).
func _draw_tail() -> void:
	var size: Vector2 = _label.size
	var center: float = clampf(roundf(-_label.position.x), TAIL_INSET, size.x - TAIL_INSET)
	if _flipped:
		_draw_tail_up(center)
		return
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


## The tail of a board hanging under its sign: the same wedge mirrored, opening the board's top edge.
func _draw_tail_up(center: float) -> void:
	_tail.draw_rect(Rect2(center - float(TAIL_HALF - 3), 2.0, float(2 * TAIL_HALF - 6), 3.0), COL_FACE)
	for k: int in TAIL_HALF + 1:
		var y: float = 1.0 - float(k)
		var outline: int = TAIL_HALF - k
		if outline <= 0:
			break
		_tail.draw_rect(Rect2(center - float(outline), y, float(2 * outline), 1.0), COL_EDGE)
		if outline > 2:
			_tail.draw_rect(Rect2(center - float(outline - 2), y, float(2 * (outline - 2)), 1.0), COL_RIM)
		if outline > 4:
			_tail.draw_rect(Rect2(center - float(outline - 4), y, float(2 * (outline - 4)), 1.0), COL_FACE)
