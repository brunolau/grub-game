class_name TheEndScreen
extends UiScreen
## "THE END" picture after the ending stage (GAMEPLAY.md 1.5, 11.1 step 11): the hero cheers with the companion
## and the villagers in front of the village. The confirm button or AUTO_LEAVE seconds lead to the credits.

const AUTO_LEAVE: float = 12.0
const PROP_DIR: String = "res://assets/tiles/village/props/"

var _time: float = 0.0
var _ground: UiGround = null
var _village: Control = null
var _heading: Label = null
var _cast: Array[UiActor] = []
## Village pieces (huts, fence), held for the whole screen: a texture drawn from a local would be freed right
## after the draw call and show up white.
var _props: Array[Texture2D] = []
var _cast_offsets: PackedFloat32Array = PackedFloat32Array([-150.0, -86.0, 0.0, 70.0, 140.0])


func _build_screen() -> void:
	add_child(UiBackdrop.new("jungle", 14.0))
	for prop: String in ["hut_dome.png", "hut_bone.png", "fence.png"]:
		_props.append(UiKit.tex(PROP_DIR + prop))
	_village = Control.new()
	_village.set_anchors_preset(Control.PRESET_FULL_RECT)
	_village.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_village.draw.connect(_draw_village)
	add_child(_village)
	_ground = UiGround.new("jungle/terrain", 2)
	add_child(_ground)
	var roles: Array[Array] = [[&"elder", &"idle"], [&"kid", &"idle"], [&"hero", &"victory"],
		[&"companion", &"idle"], [&"warrior", &"idle"]]
	for role: Array in roles:
		var actor: UiActor = UiActor.new(role[0], role[1])
		add_child(actor)
		_cast.append(actor)

	var column: VBoxContainer = VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override(&"separation", 6)
	safe.add_child(column)
	var holder: Control = Control.new()
	holder.custom_minimum_size = Vector2(0.0, 80.0)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(holder)
	_heading = UiKit.label("UI_THE_END", UiKit.Style.TITLE, HORIZONTAL_ALIGNMENT_CENTER)
	_heading.scale = Vector2(2.0, 2.0)
	holder.add_child(_heading)
	var thanks: Label = UiKit.label("UI_THE_END_THANKS", UiKit.Style.BODY, HORIZONTAL_ALIGNMENT_CENTER)
	column.add_child(thanks)
	var score: Label = UiKit.label("%s %s" % [tr("UI_TALLY_SCORE"), UiKit.score_text(Game.score)], UiKit.Style.HUD,
			HORIZONTAL_ALIGNMENT_CENTER)
	score.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	column.add_child(score)
	var spacer: Control = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(spacer)
	var prompts: UiPrompts = UiPrompts.new()
	prompts.alignment = BoxContainer.ALIGNMENT_END
	prompts.add_hint(&"ui_accept", "UI_HINT_CONTINUE", _on_accept)
	column.add_child(prompts)


func _screen_ready() -> void:
	Audio.play_music(Sfx.MUSIC_CREDITS)
	resized.connect(_layout)
	_layout()


func _process(delta: float) -> void:
	_time += delta
	var holder: Control = _heading.get_parent() as Control
	var width: float = _heading.get_combined_minimum_size().x * 2.0
	_heading.position = Vector2(roundf((holder.size.x - width) * 0.5), roundf(sin(_time * 2.0) * 3.0))
	if _time >= AUTO_LEAVE:
		leave()


func _on_accept() -> void:
	leave()


func _on_cancel() -> void:
	leave()


## Continue to the credits.
func leave() -> void:
	go_to(Flow.SCREEN_CREDITS)


func _layout() -> void:
	var floor_y: float = _ground.position.y + 10.0
	var mid: float = roundf(size.x * 0.5)
	for i: int in _cast.size():
		_cast[i].position = Vector2(mid + _cast_offsets[i], floor_y)
		_cast[i].face(1 if _cast_offsets[i] < 0.0 else -1)
	_cast[2].face(1)
	_village.queue_redraw()


func _draw_village() -> void:
	var base: float = _ground.position.y + 6.0
	var mid: float = roundf(_village.size.x * 0.5)
	var left_hut: Texture2D = _props[0]
	var right_hut: Texture2D = _props[1]
	var fence: Texture2D = _props[2]
	if left_hut == null or right_hut == null or fence == null:
		return
	_village.draw_texture(left_hut, Vector2(mid - 300.0, base - left_hut.get_height()))
	_village.draw_texture(right_hut, Vector2(mid + 96.0, base - right_hut.get_height()))
	var x: float = mid - 92.0
	while x < mid + 96.0:
		_village.draw_texture(fence, Vector2(x, base - fence.get_height()))
		x += fence.get_width()
