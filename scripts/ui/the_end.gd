class_name TheEndScreen
extends UiScreen
## "THE END" picture after the ending stage (GAMEPLAY.md 1.5, 11.1 step 11): the hero cheers with the companion
## and the villagers in front of the village. The confirm button or AUTO_LEAVE seconds lead to the credits.
##
## 2.0 (DESIGN.md C.9 reward 30, GAMEPLAY.md 13.1; PLAN.md P2.8): Flow.ending_args() hands {"book", "mode", "mural"};
## at the end of The Long Raft Home with all 30 Cave Paintings found ("mural" true) the cave mural replaces the picture:
## art-A's `ui/mural.png` - the 30 pieces the paintings showed one by one, now one picture of the Far Shore story - at
## 3x on the torch-lit cave wall (`ui/cave_wall.png`).

const AUTO_LEAVE: float = 12.0
const PROP_DIR: String = "res://assets/tiles/village/props/"
const MURAL_SCALE: float = 3.0

var _time: float = 0.0
var _ground: UiGround = null
var _village: Control = null
var _heading: Label = null
var _cast: Array[UiActor] = []
## Village pieces (huts, fence), held for the whole screen: a texture drawn from a local would be freed right
## after the draw call and show up white.
var _props: Array[Texture2D] = []
var _cast_offsets: PackedFloat32Array = PackedFloat32Array([-150.0, -86.0, 0.0, 70.0, 140.0])
## True when the cave mural shows instead of the village (the end of Book II with every painting found).
var _mural: bool = false


func _build_screen() -> void:
	_mural = bool(Flow.args.get("mural", false))
	if _mural:
		_build_mural()
		return
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
	if _mural:
		return
	resized.connect(_layout)
	_layout()


## True when the cave mural shows (tests).
func is_mural() -> bool:
	return _mural


## The end of Book II with all 30 Cave Paintings: the whole mural on the cave wall, THE END above it.
func _build_mural() -> void:
	var backdrop: UiBackdrop = UiBackdrop.new("cave", 0.0)
	backdrop.modulate = Color(0.5, 0.45, 0.42)
	add_child(backdrop)
	var wall_texture: Texture2D = UiKit.tex(VersusResultsScreen.TEX_WALL)
	if wall_texture != null:
		var wall: TextureRect = TextureRect.new()
		wall.texture = wall_texture
		wall.mouse_filter = Control.MOUSE_FILTER_IGNORE
		wall.set_anchors_preset(Control.PRESET_CENTER)
		wall.offset_left = -wall_texture.get_width() * 0.5
		wall.offset_right = wall_texture.get_width() * 0.5
		wall.offset_top = -wall_texture.get_height() * 0.5
		wall.offset_bottom = wall_texture.get_height() * 0.5
		add_child(wall)
	var column: VBoxContainer = VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override(&"separation", 4)
	safe.add_child(column)
	_heading = UiKit.label("UI_THE_END", UiKit.Style.TITLE, HORIZONTAL_ALIGNMENT_CENTER)
	column.add_child(_heading)
	var mural_texture: Texture2D = UiKit.tex(UnlocksScreen.TEX_MURAL)
	var mural: TextureRect = TextureRect.new()
	mural.texture = mural_texture
	mural.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mural.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mural.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var mural_size: Vector2 = (mural_texture.get_size() if mural_texture != null else Vector2(144.0, 80.0)) * MURAL_SCALE
	mural.custom_minimum_size = mural_size
	mural.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(mural)
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


func _process(delta: float) -> void:
	_time += delta
	if _mural:
		if _time >= AUTO_LEAVE:
			leave()
		return
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
