class_name TheEndScreen
extends UiScreen
## "THE END" picture after the ending stage (GAMEPLAY.md 1.5, 11.1 step 11): the hero cheers with the companion
## and the villagers in front of the village. The confirm button or AUTO_LEAVE seconds lead to the credits.
##
## 2.0 (DESIGN.md C.9 reward 30, GAMEPLAY.md 13.1; PLAN.md P2.8): Flow.ending_args() hands {"book", "mode", "mural"};
## at the end of The Long Raft Home with all 30 Cave Paintings found ("mural" true) the cave mural replaces the picture:
## art-A's `ui/mural.png` - the 30 pieces the paintings showed one by one, now one picture of the Far Shore story - at
## 3x on the torch-lit cave wall (`ui/cave_wall.png`).
## Phase 3: a picture per book and mode ([method picture_of]): Book I's village; Book II's home beach after the Long
## Raft Home - the raft pulled up on the sand, the Great Roast back on its log (the giant roast), palms and the home
## huts - where Grub cheers with Munch (DESIGN.md A.1) and the village. In co-op every hero of the party cheers in his
## own colours in the hero's place (Book II: P2 is Munch).

enum Picture { VILLAGE = 0, BEACH = 1 }

const AUTO_LEAVE: float = 12.0
const PROP_DIR: String = "res://assets/tiles/village/props/"
const COAST_PROP_DIR: String = "res://assets/tiles/coast/props/"
const MURAL_SCALE: float = 3.0
## Book II: the raft (objects/raft.png row 1, the 4-wide log raft; its pivot is the deck's top centre) and the Great
## Roast (items/giant_bonus.png cell 0, the giant roast) on a driftwood log.
const TEX_RAFT: String = "res://assets/sprites/objects/raft.png"
const RAFT_CELL: Vector2 = Vector2(128.0, 24.0)
const TEX_ROAST: String = "res://assets/sprites/items/giant_bonus.png"
const ROAST_CELL: Vector2 = Vector2(72.0, 72.0)
## Book II solo: Munch wears P2's blue (DESIGN.md A.1).
const MUNCH_PALETTE: StringName = &"blue"

var _time: float = 0.0
var _ground: UiGround = null
var _village: Control = null
var _heading: Label = null
var _cast: Array[UiActor] = []
## Village pieces (huts, fence; Book II: palm, hut, log, raft, roast), held for the whole screen: a texture drawn from
## a local would be freed right after the draw call and show up white.
var _props: Array[Texture2D] = []
var _cast_offsets: PackedFloat32Array = PackedFloat32Array([-150.0, -86.0, 0.0, 70.0, 140.0])
## True when the cave mural shows instead of the village (the end of Book II with every painting found).
var _mural: bool = false
## The picture shown (Picture), the book that ended and the heroes who cheer (player slots; Munch is -1).
var _picture: int = Picture.VILLAGE
var _book: int = 1
var _heroes: PackedInt32Array = PackedInt32Array([0])


## The picture of the end of `book`: Book I's village, Book II's home beach.
static func picture_of(book: int) -> int:
	return Picture.BEACH if book >= Levels.BOOK_2 else Picture.VILLAGE


## The heroes who cheer at the end of `book` in `mode` with a party of `party`: every player of a co-op party; in solo
## P1 (Book II: and Munch, -1).
static func cheering_heroes(book: int, mode: int, party: int) -> PackedInt32Array:
	var result: PackedInt32Array = PackedInt32Array([0])
	if mode == Defs.GameMode.COOP and party > 1:
		for slot: int in range(1, mini(party, Defs.MAX_PLAYERS)):
			result.append(slot)
	elif book >= Levels.BOOK_2:
		result.append(-1)
	return result


func _build_screen() -> void:
	_mural = bool(Flow.args.get("mural", false))
	if _mural:
		_build_mural()
		return
	_book = clampi(int(Flow.args.get("book", maxi(Game.book, 1))), 1, Levels.BOOK_2)
	_picture = picture_of(_book)
	_heroes = cheering_heroes(_book, int(Flow.args.get("mode", Game.mode)), Game.party)
	var roles: Array[Array] = []
	if _picture == Picture.BEACH:
		add_child(UiBackdrop.new("coast", 14.0))
		for prop: String in [COAST_PROP_DIR + "palm_tall.png", PROP_DIR + "hut_dome.png", COAST_PROP_DIR + "driftwood_log.png",
				TEX_RAFT, TEX_ROAST, COAST_PROP_DIR + "palm_short.png"]:
			_props.append(UiKit.tex(prop))
		_ground = UiGround.new("coast/terrain_sand", 2)
		roles.append([&"kid", &"idle", -1, -190.0])
		for i: int in _heroes.size():
			roles.append([&"hero", &"victory", _heroes[i], -50.0 + 66.0 * float(i)])
		var after: float = -50.0 + 66.0 * float(_heroes.size() - 1)
		roles.append([&"companion", &"idle", -1, after + 76.0])
		roles.append([&"elder", &"idle", -1, after + 146.0])
	else:
		add_child(UiBackdrop.new("jungle", 14.0))
		for prop: String in ["hut_dome.png", "hut_bone.png", "fence.png"]:
			_props.append(UiKit.tex(PROP_DIR + prop))
		_ground = UiGround.new("jungle/terrain", 2)
		# Solo: the 1.0 picture (elder -150, kid -86, hero 0, companion 70, warrior 140); a party stands in the middle.
		var party: bool = _heroes.size() > 1
		roles.append([&"elder", &"idle", -1, -170.0 if party else -150.0])
		roles.append([&"kid", &"idle", -1, -110.0 if party else -86.0])
		for i: int in _heroes.size():
			roles.append([&"hero", &"victory", _heroes[i], (-44.0 + 58.0 * float(i)) if party else 0.0])
		var last: float = (-44.0 + 58.0 * float(_heroes.size() - 1)) if party else 0.0
		roles.append([&"companion", &"idle", -1, last + 70.0])
		roles.append([&"warrior", &"idle", -1, last + 140.0])
	_village = Control.new()
	_village.set_anchors_preset(Control.PRESET_FULL_RECT)
	_village.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_village.draw.connect(_draw_beach if _picture == Picture.BEACH else _draw_village)
	add_child(_village)
	add_child(_ground)
	_cast_offsets = PackedFloat32Array()
	for role: Array in roles:
		var actor: UiActor = UiActor.new(role[0], role[1])
		actor.set_meta(&"kind", role[0])
		if role[0] == &"hero":
			var slot: int = int(role[2])
			if slot < 0:
				actor.material = HeroPalette.material_for(MUNCH_PALETTE, HeroPalette.slot_default_pattern(1))
			elif _heroes.size() > 1 and _heroes.has(1):
				TallyScreen.dress_hero(actor, slot)
			actor.set_meta(&"slot", slot)
		add_child(actor)
		_cast.append(actor)
		_cast_offsets.append(float(role[3]))

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
		if _cast[i].has_meta(&"slot") and int(_cast[i].get_meta(&"slot")) == 0:
			_cast[i].face(1)
	_village.queue_redraw()


## The picture shown (Picture; tests).
func get_picture() -> int:
	return _picture


## The cast: [kind, player slot or -2 for a villager / the companion (Munch is -1), feet x from the view centre].
func get_cast() -> Array[Array]:
	var result: Array[Array] = []
	for i: int in _cast.size():
		var slot: int = int(_cast[i].get_meta(&"slot", -2))
		result.append([StringName(str(_cast[i].get_meta(&"kind", ""))), slot, _cast_offsets[i]])
	return result


## The cheering heroes' actors (tests): P1 first, then the partners or Munch.
func get_heroes() -> Array[UiActor]:
	var result: Array[UiActor] = []
	for actor: UiActor in _cast:
		if actor.has_meta(&"slot"):
			result.append(actor)
	return result


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


## Book II: the home beach - a short palm and the raft pulled up on the sand on the left, the Great Roast back on its
## driftwood log between the kid and the heroes, the home hut and a tall palm behind the villagers on the right.
func _draw_beach() -> void:
	var base: float = _ground.position.y + 6.0
	var mid: float = roundf(_village.size.x * 0.5)
	var palm: Texture2D = _props[0]
	var hut: Texture2D = _props[1]
	var log_tex: Texture2D = _props[2]
	var raft: Texture2D = _props[3]
	var roast: Texture2D = _props[4]
	var short_palm: Texture2D = _props[5]
	if palm == null or hut == null or log_tex == null or raft == null or roast == null or short_palm == null:
		return
	_village.draw_texture(hut, Vector2(mid + 70.0, base - hut.get_height()))
	_village.draw_texture(palm, Vector2(mid + 236.0, base - palm.get_height()))
	_village.draw_texture(short_palm, Vector2(mid - 330.0, base - short_palm.get_height()))
	# The raft lies on the sand: its deck (row 1, the 4-wide log raft) a little sunk into it.
	_village.draw_texture_rect_region(raft, Rect2(Vector2(mid - 300.0, base - RAFT_CELL.y + 4.0), RAFT_CELL),
			Rect2(Vector2(0.0, RAFT_CELL.y), RAFT_CELL))
	var log_at: Vector2 = Vector2(mid - 160.0, base - log_tex.get_height() + 4.0)
	_village.draw_texture(log_tex, log_at)
	_village.draw_texture_rect_region(roast, Rect2(Vector2(log_at.x + (log_tex.get_width() - ROAST_CELL.x) * 0.5,
			log_at.y - ROAST_CELL.y + 12.0), ROAST_CELL), Rect2(Vector2.ZERO, ROAST_CELL))
