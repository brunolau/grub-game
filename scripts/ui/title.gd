class_name TitleScreen
extends UiScreen
## Title picture + main menu + attract loop (GAMEPLAY.md 11.1 steps 3-4).
##
## Menu: start (mode select), continue (level select / code entry), options, credits, quit (desktop only).
## After ATTRACT_DELAY seconds without input the menu steps aside and the attract loop runs: the hero races
## across the picture chased by a small dinosaur, then races back chased by three. Any input returns to the menu.

## Seconds without input before the attract loop starts (the original waits about 4 s, `blues` 15 s).
const ATTRACT_DELAY: float = 10.0
const RUN_SPEED: float = 230.0       ## art px per second of the chase
const RUN_MARGIN: float = 120.0      ## how far outside the view a runner starts and ends
const GROUND_FROM_BOTTOM: int = 26   ## feet line of the runners above the bottom edge
const LOGO_TOP: int = 14
const LOGO_DROP: float = 120.0
const TEX_FOREGROUND: String = "res://assets/ui/title_background.png"
const TEX_LOGO: String = "res://assets/ui/title_logo.png"
## Width of the dithered fade at both edges of the title picture on views wider than the picture.
const EDGE_FADE: int = 48
const BAYER_4X4: PackedInt32Array = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]

## True while the attract loop is on screen.
var attract_running: bool = false

var _foreground: Control = null
var _stage: Node2D = null
var _logo: TextureRect = null
var _logo_height: float = 0.0
var _menu_panel: Control = null
var _footer: Control = null
var _buttons: Array[UiButton] = []
var _idle: float = 0.0
var _logo_time: float = 0.0
var _logo_ready: bool = false
var _attract: Tween = null
var _faded_picture: Texture2D = null
## The title picture, held for the whole screen (a texture drawn from a local would be freed after the draw call).
var _picture: Texture2D = null


func _build_screen() -> void:
	add_child(UiBackdrop.new("jungle", 0.0))
	_picture = UiKit.tex(TEX_FOREGROUND)
	_foreground = Control.new()
	_foreground.set_anchors_preset(Control.PRESET_FULL_RECT)
	_foreground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_foreground.draw.connect(_draw_foreground)
	add_child(_foreground)
	_stage = Node2D.new()
	add_child(_stage)

	var column: VBoxContainer = VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override(&"separation", 0)
	safe.add_child(column)

	var logo_texture: Texture2D = UiKit.tex(TEX_LOGO)
	var logo_holder: Control = Control.new()
	logo_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	logo_holder.custom_minimum_size = Vector2(0.0, 96.0)
	column.add_child(logo_holder)
	_logo = UiKit.picture(logo_texture)
	_logo.set_anchors_preset(Control.PRESET_CENTER_TOP)
	if logo_texture != null:
		_logo.offset_left = -logo_texture.get_width() * 0.5
		_logo.offset_right = logo_texture.get_width() * 0.5
		_logo_height = float(logo_texture.get_height())
		_logo.offset_bottom = _logo_height
	logo_holder.add_child(_logo)

	var middle: CenterContainer = CenterContainer.new()
	middle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(middle)
	var list: VBoxContainer = VBoxContainer.new()
	list.add_theme_constant_override(&"separation", 0)
	list.custom_minimum_size = Vector2(230.0, 0.0)
	_add_entry(list, "UI_TITLE_START", _on_start)
	_add_entry(list, "UI_TITLE_CONTINUE", _on_continue)
	_add_entry(list, "UI_TITLE_OPTIONS", _on_options)
	_add_entry(list, "UI_TITLE_CREDITS", _on_credits)
	if not OS.has_feature("mobile") and not OS.has_feature("web"):
		_add_entry(list, "UI_TITLE_QUIT", _on_quit)
	_menu_panel = UiKit.panel_box(list, 12)
	middle.add_child(_menu_panel)

	var footer: HBoxContainer = HBoxContainer.new()
	footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	footer.custom_minimum_size = Vector2(0.0, 24.0)
	column.add_child(footer)
	_footer = footer
	var high: Label = UiKit.label(
		"%s %s" % [tr("UI_HIGH_SCORE"), UiKit.score_text(Save.get_high_score())], UiKit.Style.HUD
	)
	high.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	high.size_flags_vertical = Control.SIZE_SHRINK_END
	footer.add_child(high)
	var prompts: UiPrompts = UiPrompts.new()
	prompts.size_flags_vertical = Control.SIZE_SHRINK_END
	prompts.add_hint(&"ui_accept", "UI_HINT_SELECT")
	footer.add_child(prompts)
	var version: Label = UiKit.label(
		"v%s" % str(ProjectSettings.get_setting("application/config/version", "")), UiKit.Style.SMALL,
		HORIZONTAL_ALIGNMENT_RIGHT
	)
	version.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	version.size_flags_vertical = Control.SIZE_SHRINK_END
	footer.add_child(version)


func _screen_ready() -> void:
	Audio.play_music(Sfx.MUSIC_TITLE)
	UiKit.focus_silently(_buttons[0])
	_layout_stage()
	resized.connect(_layout_stage)
	# The logo drops in and settles; afterwards it bobs gently (see _process).
	_set_logo_top(float(LOGO_TOP) - LOGO_DROP)
	var drop: Tween = create_tween()
	drop.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	drop.tween_method(_set_logo_top, float(LOGO_TOP) - LOGO_DROP, float(LOGO_TOP), 0.9)
	drop.tween_callback(_on_logo_landed)
	_menu_panel.modulate.a = 0.0
	var reveal: Tween = create_tween()
	reveal.tween_interval(0.35)
	reveal.tween_property(_menu_panel, "modulate:a", 1.0, 0.3)


func _process(delta: float) -> void:
	if _logo_ready:
		_logo_time += delta
		_set_logo_top(float(LOGO_TOP) + roundf(sin(_logo_time * 2.0) * 2.0))
	if attract_running or not is_accepting_input():
		return
	_idle += delta
	if _idle >= ATTRACT_DELAY:
		start_attract()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion or event is InputEventJoypadMotion or event.is_echo():
		return
	if not event.is_pressed():
		return
	_idle = 0.0
	if attract_running:
		# Any button only ends the attract loop; it must not also trigger a menu entry.
		get_viewport().set_input_as_handled()
		stop_attract()


## Start the attract loop now (normally started by the idle timer).
func start_attract() -> void:
	if attract_running:
		return
	attract_running = true
	_idle = 0.0
	var view: float = size.x
	var hide_menu: Tween = create_tween().set_parallel(true)
	hide_menu.tween_property(_menu_panel, "modulate:a", 0.0, 0.3)
	hide_menu.tween_property(_footer, "modulate:a", 0.0, 0.3)
	var first: Node2D = _make_pack(1, [&"mini_rex"])
	var second: Node2D = _make_pack(-1, [&"rex", &"mini_rex_b", &"mini_rex"])
	var flyer: UiActor = UiActor.new(&"pterodactyl", &"fly")
	flyer.face(-1)
	flyer.position = Vector2(view + RUN_MARGIN, -150.0)
	_stage.add_child(flyer)
	var first_width: float = 170.0
	var second_width: float = 400.0
	first.position.x = -RUN_MARGIN
	second.position.x = view + RUN_MARGIN
	var first_distance: float = view + RUN_MARGIN * 2.0 + first_width
	var second_distance: float = view + RUN_MARGIN * 2.0 + second_width
	_attract = create_tween()
	_attract.tween_interval(0.4)
	_attract.tween_property(first, "position:x", first.position.x + first_distance, first_distance / RUN_SPEED)
	_attract.parallel().tween_property(flyer, "position:x", -RUN_MARGIN, (view + RUN_MARGIN * 2.0) / 150.0)
	_attract.tween_interval(0.5)
	_attract.tween_property(second, "position:x", second.position.x - second_distance, second_distance / RUN_SPEED)
	_attract.tween_interval(0.4)
	_attract.tween_callback(stop_attract)


## End the attract loop and bring the menu back.
func stop_attract() -> void:
	if not attract_running:
		return
	attract_running = false
	_idle = 0.0
	if _attract != null and _attract.is_valid():
		_attract.kill()
	_attract = null
	for child: Node in _stage.get_children():
		child.queue_free()
	var show_menu: Tween = create_tween().set_parallel(true)
	show_menu.tween_property(_menu_panel, "modulate:a", 1.0, 0.25)
	show_menu.tween_property(_footer, "modulate:a", 1.0, 0.25)


## A hero running in `direction` followed by the given chasers, as one node.
func _make_pack(direction: int, chasers: Array[StringName]) -> Node2D:
	var pack: Node2D = Node2D.new()
	var hero: UiActor = UiActor.new(&"hero", &"run")
	hero.face(direction)
	pack.add_child(hero)
	var gap: float = 110.0
	for i: int in chasers.size():
		var chaser: UiActor = UiActor.new(chasers[i], &"run")
		chaser.face(direction)
		chaser.position.x = -float(direction) * gap * float(i + 1)
		pack.add_child(chaser)
	_stage.add_child(pack)
	return pack


func _add_entry(list: VBoxContainer, key: String, callback: Callable) -> void:
	var button: UiButton = UiButton.new(key)
	button.pressed.connect(callback)
	list.add_child(button)
	_buttons.append(button)


func _layout_stage() -> void:
	_stage.position = Vector2(0.0, size.y - float(GROUND_FROM_BOTTOM))
	_foreground.queue_redraw()


func _set_logo_top(top: float) -> void:
	_logo.offset_top = top
	_logo.offset_bottom = top + _logo_height


func _on_logo_landed() -> void:
	_logo_ready = true


## The title picture is 640 px wide, centred and anchored to the bottom edge (its sky is transparent). On wider
## views its side edges dissolve in an ordered dither into the jungle backdrop behind it.
func _draw_foreground() -> void:
	var picture: Texture2D = _picture
	if picture == null:
		return
	var left: float = roundf((_foreground.size.x - picture.get_size().x) * 0.5)
	var top: float = _foreground.size.y - picture.get_size().y
	if left > 0.0:
		if _faded_picture == null:
			_faded_picture = _dither_edges(picture)
		picture = _faded_picture
	_foreground.draw_texture(picture, Vector2(left, top))


## A copy of `picture` whose left and right EDGE_FADE columns turn transparent in a 4 x 4 Bayer pattern.
func _dither_edges(picture: Texture2D) -> Texture2D:
	var image: Image = picture.get_image()
	if image == null:
		return picture
	image.decompress()
	image.convert(Image.FORMAT_RGBA8)
	var width: int = image.get_width()
	for y: int in image.get_height():
		for x: int in EDGE_FADE:
			var threshold: int = BAYER_4X4[(y % 4) * 4 + (x % 4)]
			var keep: bool = x * 16 / EDGE_FADE > threshold
			if not keep:
				image.set_pixel(x, y, Color(0.0, 0.0, 0.0, 0.0))
				image.set_pixel(width - 1 - x, y, Color(0.0, 0.0, 0.0, 0.0))
	return ImageTexture.create_from_image(image)


func _on_start() -> void:
	go_to(Flow.SCREEN_MODE_SELECT)


func _on_continue() -> void:
	go_to(Flow.SCREEN_CODE_ENTRY)


func _on_options() -> void:
	go_to(Flow.SCREEN_OPTIONS)


func _on_credits() -> void:
	go_to(Flow.SCREEN_CREDITS)


func _on_quit() -> void:
	if begin_leave():
		Flow.quit_game()
