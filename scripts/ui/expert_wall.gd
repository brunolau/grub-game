class_name ExpertWallScreen
extends UiScreen
## The Beginner wall (GAMEPLAY.md 1.3, 11.1 step 10): a castle picture and "To enter you must be an expert
## eater!". Waits for the confirm button, then returns to the title. The castle is composed from village props
## (ASSET_MANIFEST.md 16) on volcano ground, centred whatever the view width.

const PROP_DIR: String = "res://assets/tiles/village/props/"

var _castle: Control = null
var _ground: UiGround = null
var _guard: UiActor = null
## Castle pieces (tower, keep, wall), held for the whole screen: a texture drawn from a local would be freed
## right after the draw call and show up white.
var _tower: Texture2D = null
var _keep: Texture2D = null
var _wall: Texture2D = null


func _build_screen() -> void:
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
	var body: Label = UiKit.label("UI_WALL_TEXT", UiKit.Style.BODY, HORIZONTAL_ALIGNMENT_CENTER)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(360.0, 0.0)
	text.add_child(body)
	var box: PanelContainer = UiKit.panel_box(text, 12)
	box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
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


func _on_accept() -> void:
	leave()


func _on_cancel() -> void:
	leave()


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
	_guard.position = Vector2(roundf(size.x * 0.5 + 40.0), _ground.position.y + 10.0)
	_guard.face(-1)
	_castle.queue_redraw()


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
