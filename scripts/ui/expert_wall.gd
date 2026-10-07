class_name ExpertWallScreen
extends UiScreen
## The Beginner wall (GAMEPLAY.md 1.3, 11.1 step 10): a castle picture and "To enter you must be an expert
## eater!". Waits for the confirm button, then returns to the title. The castle is composed from village props
## (ASSET_MANIFEST.md 16) on volcano ground, centred whatever the view width.
##
## 2.0 (DESIGN.md A.2, GAMEPLAY.md 13.1, PLAN.md P2.8): a Book II run (Game.book 2, or args {"book": 2}) meets the wall
## after the tally of 7-2b with its own picture - "Only an expert eater may climb to the Roc!": the Sky Spire of world
## 9 climbs out of the mesa into a storm cloud (slate rock with its ledges, the Far Shore map's colours), the Storm
## Roc (the pterodactyl in storm slate) circles under the cloud beside the lightning, and a warrior keeps the path at
## its foot. The spire stands in the right part of the view and the same text panel on the left, so the picture shows
## beside the words; the same way back to the title.

const PROP_DIR: String = "res://assets/tiles/village/props/"
## Book II: the Roc's flight, a slow ellipse under the storm cloud around the spire (art px; the centre's y is the
## bird's feet line), and where the spire stands (fraction of the view width).
const ROC_ORBIT: Vector2 = Vector2(104.0, 18.0)
const ROC_CENTRE_Y: float = 132.0
const ROC_SECONDS: float = 9.0
const SPIRE_AT: float = 0.7
## Book II: the text panel's width on the left (the Book I panel is centred and wider).
const PANEL_WIDTH_B2: float = 236.0
## The storm tint of the Book II sky.
const STORM_TINT: Color = Color(0.55, 0.6, 0.78)
## The spire's storm slate, dark to light (the Far Shore map's spire).
const SLATE: Array[Color] = [Color("1d2233"), Color("3f4862"), Color("6b7895"), Color("a9b5cc"), Color("e7edf7")]

var _castle: Control = null
var _ground: UiGround = null
var _guard: UiActor = null
## Castle pieces (tower, keep, wall), held for the whole screen: a texture drawn from a local would be freed
## right after the draw call and show up white.
var _tower: Texture2D = null
var _keep: Texture2D = null
var _wall: Texture2D = null
## The book of the run that met the wall (1 / 2).
var _book: int = 1
var _roc: UiActor = null
var _time: float = 0.0


func _build_screen() -> void:
	_book = clampi(int(Flow.args.get("book", maxi(Game.book, 1))), 1, Levels.BOOK_2)
	if _book == Levels.BOOK_2:
		var sky: UiBackdrop = UiBackdrop.new("ice", 6.0)
		sky.modulate = STORM_TINT
		add_child(sky)
		_ground = UiGround.new("canyon/terrain_mesa", 2)
		add_child(_ground)
		_castle = Control.new()
		_castle.set_anchors_preset(Control.PRESET_FULL_RECT)
		_castle.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_castle.draw.connect(_draw_spire)
		add_child(_castle)
		_roc = UiActor.new(&"pterodactyl", &"fly")
		_roc.modulate = Color(0.62, 0.68, 0.86)
		add_child(_roc)
	else:
		add_child(UiBackdrop.new("volcano", 10.0))
		_ground = UiGround.new("volcano/terrain_obsidian", 2)
		add_child(_ground)
		_tower = UiKit.tex(PROP_DIR + "watchtower.png")
		_keep = UiKit.tex(PROP_DIR + "hut_bone.png")
		_wall = UiKit.tex(PROP_DIR + "palisade.png")
		_castle = Control.new()
		_castle.set_anchors_preset(Control.PRESET_FULL_RECT)
		_castle.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_castle.draw.connect(_draw_castle)
		add_child(_castle)
	_guard = UiActor.new(&"warrior", &"idle")
	add_child(_guard)

	var column: VBoxContainer = VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	safe.add_child(column)
	var text: VBoxContainer = VBoxContainer.new()
	text.add_theme_constant_override(&"separation", 4)
	var heading: Label = UiKit.label("UI_WALL_HEADING", UiKit.Style.HUD, HORIZONTAL_ALIGNMENT_CENTER)
	heading.add_theme_color_override(&"font_color", UiKit.COL_FOCUS)
	text.add_child(heading)
	var body: Label = UiKit.label(wall_text_key(_book), UiKit.Style.BODY, HORIZONTAL_ALIGNMENT_CENTER)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(PANEL_WIDTH_B2 if _book == Levels.BOOK_2 else 360.0, 0.0)
	text.add_child(body)
	var box: PanelContainer = UiKit.panel_box(text, 12)
	box.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN if _book == Levels.BOOK_2 else Control.SIZE_SHRINK_CENTER
	column.add_child(box)
	var spacer: Control = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(spacer)
	var prompts: UiPrompts = UiPrompts.new()
	prompts.alignment = BoxContainer.ALIGNMENT_END
	prompts.add_hint(&"ui_accept", "UI_HINT_TITLE", _on_accept)
	column.add_child(prompts)
	box.modulate.a = 0.0
	box.ready.connect(_reveal.bind(box))


func _screen_ready() -> void:
	Audio.play_music(Sfx.MUSIC_MENU)
	resized.connect(_layout)
	_layout()


func _process(delta: float) -> void:
	if _roc == null:
		return
	_time += delta
	_place_roc()


func _on_accept() -> void:
	leave()


func _on_cancel() -> void:
	leave()


## The text of the wall for `book`: Book I's castle, Book II's Roc.
static func wall_text_key(book: int) -> String:
	return "UI_WALL_B2_TEXT" if book >= Levels.BOOK_2 else "UI_WALL_TEXT"


## The book whose wall shows (tests).
func get_book() -> int:
	return _book


## Back to the title screen.
func leave() -> void:
	if not is_accepting_input():
		return
	Audio.play_sfx(Sfx.MENU_BACK)
	go_to(Flow.SCREEN_TITLE)


func _reveal(box: Control) -> void:
	var tween: Tween = box.create_tween()
	tween.tween_interval(0.3)
	tween.tween_property(box, "modulate:a", 1.0, 0.4)


func _layout() -> void:
	if _book == Levels.BOOK_2:
		_guard.position = Vector2(roundf(_spire_x() - 128.0), _ground.position.y + 10.0)
		_guard.face(1)
		_place_roc()
	else:
		_guard.position = Vector2(roundf(size.x * 0.5 + 40.0), _ground.position.y + 10.0)
		_guard.face(-1)
	_castle.queue_redraw()


## The Roc circles the spire top: wide and slow, nearer (lower) on the way to the left.
func _place_roc() -> void:
	var angle: float = _time * TAU / ROC_SECONDS
	var centre: Vector2 = Vector2(_spire_x(), ROC_CENTRE_Y)
	_roc.position = (centre + Vector2(cos(angle) * ROC_ORBIT.x, sin(angle) * ROC_ORBIT.y)).round()
	_roc.face(-1 if sin(angle) > 0.0 else 1)


## The x of the spire's centre line (Book II).
func _spire_x() -> float:
	return roundf(size.x * SPIRE_AT)


func _draw_castle() -> void:
	var base: float = _ground.position.y + 6.0
	var mid: float = roundf(_castle.size.x * 0.5)
	var tower: Texture2D = _tower
	var keep: Texture2D = _keep
	var wall: Texture2D = _wall
	if tower == null or keep == null or wall == null:
		return
	var keep_left: float = mid - roundf(keep.get_width() * 0.5)
	var tower_left: float = keep_left - tower.get_width() + 6.0
	var tower_right: float = keep_left + keep.get_width() - 6.0
	# Palisade runs from both towers to the screen edges.
	var x: float = tower_left - wall.get_width() + 8.0
	while x > -float(wall.get_width()):
		_castle.draw_texture(wall, Vector2(x, base - wall.get_height()))
		x -= wall.get_width() - 4.0
	x = tower_right + tower.get_width() - 8.0
	while x < _castle.size.x:
		_castle.draw_texture(wall, Vector2(x, base - wall.get_height()))
		x += wall.get_width() - 4.0
	_castle.draw_texture(tower, Vector2(tower_left, base - tower.get_height()))
	_castle.draw_texture_rect(tower, Rect2(tower_right, base - tower.get_height(), -tower.get_width(),
			tower.get_height()), false)
	_castle.draw_texture(keep, Vector2(keep_left, base - keep.get_height()))


## Book II: the Sky Spire from the ground into the storm cloud, with three ledges, lit from the left.
func _draw_spire() -> void:
	var palette: Array[Color] = SLATE
	var base: float = _ground.position.y + 4.0
	var mid: float = _spire_x()
	# Half widths from the foot (row 0) to the top (inside the storm cloud): a wide foot, a waist, a ledge, the
	# narrow top.
	var outline: PackedVector2Array = PackedVector2Array()
	var shape: Array[Vector2] = [
		Vector2(-96.0, 0.0), Vector2(-74.0, -40.0), Vector2(-60.0, -46.0), Vector2(-58.0, -110.0),
		Vector2(-70.0, -116.0), Vector2(-46.0, -124.0), Vector2(-40.0, -190.0), Vector2(-48.0, -196.0),
		Vector2(-30.0, -204.0), Vector2(-26.0, -262.0),
	]
	for point: Vector2 in shape:
		outline.append(Vector2(mid + point.x, base + point.y))
	var right: Array[Vector2] = [
		Vector2(24.0, -262.0), Vector2(30.0, -236.0), Vector2(62.0, -230.0), Vector2(56.0, -160.0),
		Vector2(52.0, -96.0), Vector2(84.0, -88.0), Vector2(78.0, -40.0), Vector2(104.0, 0.0),
	]
	for point: Vector2 in right:
		outline.append(Vector2(mid + point.x, base + point.y))
	_castle.draw_colored_polygon(outline, Color(palette[2]))
	for y: int in range(int(base) - 262, int(base), 2):
		var span: Vector2 = _span(outline, float(y) + 1.0)
		if span.y <= span.x:
			continue
		var width: float = span.y - span.x
		var stripe: float = float(posmod(y * 37, 7))
		_castle.draw_rect(Rect2(span.x, float(y), minf(8.0 + stripe, width), 2.0), Color(palette[3]))
		_castle.draw_rect(Rect2(span.y - minf(16.0 + stripe, width), float(y), minf(16.0 + stripe, width), 2.0),
				Color(palette[1]))
		if posmod(y, 10) == 0 and width > 50.0:
			_castle.draw_rect(Rect2(span.x + 18.0 + stripe * 4.0, float(y), 10.0, 1.0), Color(palette[1]))
	# The ledges' snowy tops.
	for ledge: Array in [[-60.0, -46.0, -58.0], [-70.0, -116.0, -46.0], [-48.0, -196.0, -30.0], [30.0, -230.0, 62.0],
			[52.0, -88.0, 84.0]]:
		var left_x: float = mid + minf(float(ledge[0]), float(ledge[2]))
		var right_x: float = mid + maxf(float(ledge[0]), float(ledge[2]))
		_castle.draw_rect(Rect2(left_x, base + float(ledge[1]), right_x - left_x, 2.0), Color(palette[4]))
	var closed: PackedVector2Array = outline.duplicate()
	closed.append(outline[0])
	_castle.draw_polyline(closed, UiKit.COL_INK, 2.0)
	# The storm cloud over the top, and its lightning.
	var top: float = base - 254.0
	for blob: Vector3 in [Vector3(-70, 8, 26), Vector3(-30, -6, 36), Vector3(20, -12, 44), Vector3(70, -2, 34),
			Vector3(112, 10, 24)]:
		_castle.draw_circle(Vector2(mid + blob.x, top + blob.y), blob.z + 2.0, Color(palette[0]))
	for blob: Vector3 in [Vector3(-70, 8, 26), Vector3(-30, -6, 36), Vector3(20, -12, 44), Vector3(70, -2, 34),
			Vector3(112, 10, 24)]:
		_castle.draw_circle(Vector2(mid + blob.x, top + blob.y), blob.z, Color(palette[1]))
		_castle.draw_circle(Vector2(mid + blob.x - 5.0, top + blob.y - 7.0), maxf(blob.z - 12.0, 3.0), Color(palette[2]))
	var bolt: PackedVector2Array = [Vector2(mid + 96.0, top + 30.0), Vector2(mid + 84.0, top + 62.0),
			Vector2(mid + 98.0, top + 66.0), Vector2(mid + 86.0, top + 104.0)]
	_castle.draw_polyline(bolt, UiKit.COL_INK, 4.0)
	_castle.draw_polyline(bolt, Color("ffe94f"), 2.0)


## Left and right x of polygon `points` at row `y`.
static func _span(points: PackedVector2Array, y: float) -> Vector2:
	var left: float = INF
	var right: float = -INF
	for i: int in points.size():
		var a: Vector2 = points[i]
		var b: Vector2 = points[(i + 1) % points.size()]
		if (a.y <= y and b.y > y) or (b.y <= y and a.y > y):
			var x: float = a.x + (y - a.y) * (b.x - a.x) / (b.y - a.y)
			left = minf(left, x)
			right = maxf(right, x)
	return Vector2(roundf(left), roundf(right)) if left < right else Vector2.ZERO
