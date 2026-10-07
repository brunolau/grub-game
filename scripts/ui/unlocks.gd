class_name UnlocksScreen
extends UiScreen
## The Cave Paintings and their rewards (DESIGN.md C.9, GAMEPLAY.md 13.7, PLAN.md P2.8; Flow.SCREEN_UNLOCKS).
##
## art-A's stone slab at 2x (`ui/painting_slab.png`): 30 sockets (items/painting index 0..29: the 20 Book II levels in
## the order of GAMEPLAY.md 13.2, then the ten Book I co-op secrets); a found painting fills its socket with its piece of
## the mural (`ui/mural.png`: painting i is the mural's piece i, so the finds assemble one picture - the mural that
## ends The Long Raft Home once all 30 are found), a missing one leaves the socket empty. The count plate says "17/30";
## the six carved reward marks light up (`ui/unlock_icons.png`) as their rewards open. The focused socket names where
## its painting hides ("5-1 Red Mesa Trail", "Co-op: 1-1 ...") and whether it was found, and shows its own picture at 2x
## on a stone left of the slab (`ui/paintings.png`; a carved "?" while it is missing). Under the slab the reward
## ladder of C.9 - 5 Mesa Rodeo, 10 loincloths, 15 variants, 20 Cloud Top, 25 Spear Party and gold, 30 the mural - each
## "Unlocked!" or the paintings it needs (found paintings, a reward opened by hand or Options > Versus > "Unlock
## everything"). Paintings are saved per profile across modes, so this screen reads only Save and UnlockTable.
##
## Args: {"back": StringName} - the screen "back" returns to: the versus lobby (Flow.open_versus_lobby: seats and ready
## flags kept), else the title (Flow.goto_title). Reached from the versus lobby's "Cave Paintings" button; the Far
## Shore map shows the same state small (WorldMapScreen.PaintingSlab).
##
## Where the paintings hide and what they open is core-A's UnlockTable (one table for every module); this screen only
## shows it. Shared parts (map slab, rules screen, arena screen, THE END): mural_region, draw_mural, reward_icon_region,
## reward_needs, reward_text, next_text, painting_where, draw_sand_slab.

const TEX_SLAB: String = "res://assets/ui/painting_slab.png"
const TEX_MURAL: String = "res://assets/ui/mural.png"
const TEX_UNLOCK_ICONS: String = "res://assets/ui/unlock_icons.png"
## art-A's Cave Painting pictures (ui/paintings.png): one 32 x 32 cell per painting index in a row, ochre on
## transparent; the focused painting shows at 2x on a stone beside the slab.
const TEX_PAINTINGS: String = "res://assets/ui/paintings.png"
const PAINTING_CELL: float = 32.0
## The mural (ui/mural.png, 144 x 80): 6 x 5 pieces of 24 x 16, piece i = painting i.
const MURAL_COLUMNS: int = 6
const MURAL_ROWS: int = 5
const MURAL_PIECE: Vector2 = Vector2(24.0, 16.0)
## ui/painting_slab.png (220 x 104): the sockets' top-left corner, the count plate and the six reward marks (24 x 24).
const SLAB_SOCKETS_AT: Vector2 = Vector2(8.0, 12.0)
const SLAB_COUNT_PLATE: Rect2 = Rect2(160.0, 8.0, 52.0, 14.0)
const SLAB_MARKS: Array[Vector2] = [
	Vector2(162, 26), Vector2(188, 26), Vector2(162, 51), Vector2(188, 51), Vector2(162, 76), Vector2(188, 76),
]
## ui/unlock_icons.png: 6 x 2 cells of 24 x 24, column = reward in UnlockTable.REWARDS order, row 0 closed, 1 open.
const ICON_CELL: float = 24.0
## The slab is shown at this scale.
const SLAB_SCALE: float = 2.0
## Colours of the sand slab (sampled from painting_slab.png): rim, highlight, sand, groove, empty socket.
const COL_RIM: Color = Color("272018")
const COL_HIGHLIGHT: Color = Color("fef8e8")
const COL_SAND: Color = Color("ebb678")
const COL_GROOVE: Color = Color("70604a")
const COL_SOCKET: Color = Color("b99f7c")
## The text keys of the rewards (UnlockTable.REWARDS "text"), listed here as well so that the locale checks see them.
const REWARD_KEYS: Dictionary = {
	&"mesa_rodeo": "UI_REWARD_MESA_RODEO", &"loincloths": "UI_REWARD_LOINCLOTHS", &"variants": "UI_REWARD_VARIANTS",
	&"cloud_top": "UI_REWARD_CLOUD_TOP", &"spear_party": "UI_REWARD_SPEAR_PARTY", &"mural": "UI_REWARD_MURAL",
}

## The socket that has the focus (painting index).
var focused_index: int = 0

var _slab: PaintingWall = null
var _picture: PaintingPicture = null
var _info: Label = null
var _rows: Array[Label] = []


## The slab at 2x: the picture, the mural pieces of the paintings found, the count and the reward marks; a focusable
## socket over each painting.
class PaintingWall:
	extends Control

	signal slot_focused(index: int)

	var slots: Array[PaintingSlot] = []
	var _slab: Texture2D = UiKit.tex(UnlocksScreen.TEX_SLAB)
	var _mural: Texture2D = UiKit.tex(UnlocksScreen.TEX_MURAL)
	var _icons: Texture2D = UiKit.tex(UnlocksScreen.TEX_UNLOCK_ICONS)
	var _hud: Font = UiKit.font(UiKit.Style.HUD)

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var picture: Vector2 = _slab.get_size() if _slab != null else Vector2(220.0, 104.0)
		custom_minimum_size = picture * UnlocksScreen.SLAB_SCALE
		var piece: Vector2 = UnlocksScreen.MURAL_PIECE * UnlocksScreen.SLAB_SCALE
		for index: int in Tuning.PAINTING_COUNT:
			var slot: PaintingSlot = PaintingSlot.new(index, piece)
			slot.position = UnlocksScreen.SLAB_SOCKETS_AT * UnlocksScreen.SLAB_SCALE + piece * Vector2(
					index % UnlocksScreen.MURAL_COLUMNS, index / UnlocksScreen.MURAL_COLUMNS)
			slot.focus_entered.connect(_on_slot_focused.bind(index))
			add_child(slot)
			slots.append(slot)
		var columns: int = UnlocksScreen.MURAL_COLUMNS
		var rows: int = UnlocksScreen.MURAL_ROWS
		for index: int in slots.size():
			var slot: PaintingSlot = slots[index]
			var col: int = index % columns
			var row: int = index / columns
			slot.focus_neighbor_left = slot.get_path_to(slots[row * columns + posmod(col - 1, columns)])
			slot.focus_neighbor_right = slot.get_path_to(slots[row * columns + (col + 1) % columns])
			slot.focus_neighbor_top = slot.get_path_to(slots[posmod(row - 1, rows) * columns + col])
			slot.focus_neighbor_bottom = slot.get_path_to(slots[((row + 1) % rows) * columns + col])

	func _on_slot_focused(index: int) -> void:
		slot_focused.emit(index)

	func _draw() -> void:
		var scale: float = UnlocksScreen.SLAB_SCALE
		if _slab != null:
			draw_texture_rect(_slab, Rect2(Vector2.ZERO, _slab.get_size() * scale), false)
		else:
			UnlocksScreen.draw_sand_slab(self, Rect2(Vector2.ZERO, size))
		UnlocksScreen.draw_mural(self, Rect2(UnlocksScreen.SLAB_SOCKETS_AT * scale, UnlocksScreen.MURAL_PIECE * scale
				* Vector2(UnlocksScreen.MURAL_COLUMNS, UnlocksScreen.MURAL_ROWS)), _mural, _slab != null)
		var plate: Rect2 = Rect2(UnlocksScreen.SLAB_COUNT_PLATE.position * scale, UnlocksScreen.SLAB_COUNT_PLATE.size * scale)
		var count: String = "%d/%d" % [Save.painting_count(), Tuning.PAINTING_COUNT]
		var count_w: float = _hud.get_string_size(count, HORIZONTAL_ALIGNMENT_LEFT, -1.0, UiKit.SIZE_HUD).x
		var baseline: float = roundf(plate.get_center().y - float(UiKit.SIZE_HUD) * 0.5) + _hud.get_ascent(UiKit.SIZE_HUD)
		draw_string(_hud, Vector2(roundf(plate.get_center().x - count_w * 0.5), baseline), count,
				HORIZONTAL_ALIGNMENT_LEFT, -1.0, UiKit.SIZE_HUD, UiKit.COL_FOCUS)
		for i: int in mini(UnlockTable.REWARDS.size(), UnlocksScreen.SLAB_MARKS.size()):
			if _icons != null and UnlockTable.is_open(UnlockTable.REWARDS[i]["id"]):
				draw_texture_rect_region(_icons, Rect2(UnlocksScreen.SLAB_MARKS[i] * scale,
						Vector2(UnlocksScreen.ICON_CELL, UnlocksScreen.ICON_CELL) * scale),
						UnlocksScreen.reward_icon_region(i, true))


## The focused painting at 2x on a stone (art-A's picture of it once found; a carved "?" while it is missing).
class PaintingPicture:
	extends Control

	## The painting shown (items/painting index) and whether it was found.
	var index: int = 0
	var found: bool = false
	var _sheet: Texture2D = UiKit.tex(UnlocksScreen.TEX_PAINTINGS)
	var _hud: Font = UiKit.font(UiKit.Style.HUD)

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(76.0, 76.0)

	## Show painting `p_index`.
	func show_painting(p_index: int) -> void:
		index = p_index
		found = Save.has_painting(index)
		queue_redraw()

	func _draw() -> void:
		var rect: Rect2 = Rect2(Vector2.ZERO, custom_minimum_size)
		UnlocksScreen.draw_sand_slab(self, rect)
		var inner: Rect2 = rect.grow(-6.0)
		if found and _sheet != null:
			draw_texture_rect_region(_sheet, inner, Rect2(float(index) * UnlocksScreen.PAINTING_CELL, 0.0,
					UnlocksScreen.PAINTING_CELL, UnlocksScreen.PAINTING_CELL))
			return
		draw_rect(inner, UnlocksScreen.COL_SOCKET)
		var mark: String = "?"
		var width: float = _hud.get_string_size(mark, HORIZONTAL_ALIGNMENT_LEFT, -1.0, UiKit.SIZE_HUD).x
		var baseline: float = roundf(inner.get_center().y - float(UiKit.SIZE_HUD) * 0.5) + _hud.get_ascent(UiKit.SIZE_HUD)
		draw_string(_hud, Vector2(roundf(inner.get_center().x - width * 0.5), baseline), mark, HORIZONTAL_ALIGNMENT_LEFT,
				-1.0, UiKit.SIZE_HUD, UnlocksScreen.COL_GROOVE)


## One socket: focusable, a gold frame while focused.
class PaintingSlot:
	extends Control

	var index: int = 0
	var found: bool = false

	func _init(p_index: int, socket: Vector2) -> void:
		index = p_index
		found = Save.has_painting(index)
		focus_mode = Control.FOCUS_ALL
		mouse_filter = Control.MOUSE_FILTER_STOP
		size = socket
		custom_minimum_size = socket
		focus_entered.connect(_on_focus_changed)
		focus_exited.connect(queue_redraw)
		gui_input.connect(_on_gui_input)

	func _on_focus_changed() -> void:
		UiKit.play_focus_sound()
		queue_redraw()

	func _on_gui_input(event: InputEvent) -> void:
		if event is InputEventMouseMotion and not has_focus():
			grab_focus()

	func _draw() -> void:
		if has_focus():
			draw_rect(Rect2(Vector2.ZERO, size).grow(1.0), UiKit.COL_INK, false, 3.0)
			draw_rect(Rect2(Vector2.ZERO, size), UiKit.COL_FOCUS, false, 2.0)


func _build_screen() -> void:
	add_child(UiBackdrop.new("cave", 10.0))
	var shade: ColorRect = ColorRect.new()
	shade.color = Color(UiKit.COL_INK, 0.35)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	var column: VBoxContainer = VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override(&"separation", 2)
	safe.add_child(column)
	column.add_child(UiKit.label("UI_PAINTINGS_HEADING", UiKit.Style.TITLE, HORIZONTAL_ALIGNMENT_CENTER))
	var middle: HBoxContainer = HBoxContainer.new()
	middle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	middle.alignment = BoxContainer.ALIGNMENT_CENTER
	middle.add_theme_constant_override(&"separation", 8)
	column.add_child(middle)
	# The focused painting's picture on the left, the slab in the middle, a spacer as wide as the picture on the right
	# (the slab stays centred).
	_picture = PaintingPicture.new()
	_picture.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	middle.add_child(_picture)
	_slab = PaintingWall.new()
	_slab.slot_focused.connect(_on_slot_focused)
	middle.add_child(_slab)
	var balance: Control = Control.new()
	balance.mouse_filter = Control.MOUSE_FILTER_IGNORE
	balance.custom_minimum_size = _picture.custom_minimum_size
	middle.add_child(balance)
	_info = UiKit.label("", UiKit.Style.SMALL, HORIZONTAL_ALIGNMENT_CENTER)
	_info.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	column.add_child(_info)

	var ladder: GridContainer = GridContainer.new()
	ladder.columns = 3
	ladder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ladder.add_theme_constant_override(&"h_separation", 10)
	ladder.add_theme_constant_override(&"v_separation", 0)
	for i: int in UnlockTable.REWARDS.size():
		ladder.add_child(_reward_row(UnlockTable.REWARDS[i], i))
	var ladder_holder: CenterContainer = CenterContainer.new()
	ladder_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ladder_holder.add_child(ladder)
	column.add_child(ladder_holder)
	if Save.is_unlock_everything():
		var everything: Label = UiKit.label("UI_PAINTINGS_EVERYTHING", UiKit.Style.SMALL, HORIZONTAL_ALIGNMENT_CENTER)
		everything.add_theme_color_override(&"font_color", UiKit.COL_DIM)
		column.add_child(everything)

	var spacer: Control = Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(spacer)
	var footer: HBoxContainer = HBoxContainer.new()
	footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(footer)
	var found: Label = UiKit.label(found_text(), UiKit.Style.SMALL)
	found.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	found.add_theme_color_override(&"font_color", UiKit.COL_FOCUS)
	found.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	found.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	footer.add_child(found)
	var prompts: UiPrompts = UiPrompts.new()
	prompts.alignment = BoxContainer.ALIGNMENT_END
	prompts.add_hint(&"ui_cancel", "UI_HINT_BACK", _on_cancel)
	footer.add_child(prompts)


func _screen_ready() -> void:
	# The versus front end keeps both players' menu keys (it came from the lobby); the title's does not.
	GameInput.set_menu_clusters(_back_screen() == Flow.SCREEN_VERSUS_LOBBY)
	UiKit.focus_silently(_slab.slots[_first_focus()])
	_on_slot_focused(_first_focus())


## The text of "7 of 30 found".
static func found_text() -> String:
	return TranslationServer.translate("UI_PAINTINGS_FOUND").format({
		"count": Save.painting_count(), "total": Tuning.PAINTING_COUNT})


## The piece of the mural painting `index` shows (ui/mural.png px).
static func mural_region(index: int) -> Rect2:
	return Rect2(MURAL_PIECE * Vector2(posmod(index, MURAL_COLUMNS), posmod(index, Tuning.PAINTING_COUNT) / MURAL_COLUMNS),
			MURAL_PIECE)


## The icon of reward number `reward_index` (UnlockTable.REWARDS order) in ui/unlock_icons.png: carved (closed) or lit.
static func reward_icon_region(reward_index: int, open: bool) -> Rect2:
	return Rect2(Vector2(float(reward_index) * ICON_CELL, ICON_CELL if open else 0.0), Vector2(ICON_CELL, ICON_CELL))


## Draw the mural into `area` on `canvas` (6 x 5 sockets): the piece of every painting found, an empty socket for every
## one still missing (`over_slab`: the slab picture already shows the empty sockets, so nothing is drawn for them).
## `everything` shows the whole mural (the ending's reward).
static func draw_mural(canvas: CanvasItem, area: Rect2, mural: Texture2D, over_slab: bool = false,
		everything: bool = false) -> void:
	var piece: Vector2 = area.size / Vector2(MURAL_COLUMNS, MURAL_ROWS)
	for index: int in Tuning.PAINTING_COUNT:
		var cell: Rect2 = Rect2(area.position + piece * Vector2(index % MURAL_COLUMNS, index / MURAL_COLUMNS), piece)
		if (everything or Save.has_painting(index)) and mural != null:
			canvas.draw_texture_rect_region(mural, cell, mural_region(index))
		elif not over_slab:
			canvas.draw_rect(cell, COL_GROOVE)
			canvas.draw_rect(Rect2(cell.position + Vector2(1.0, 1.0), cell.size - Vector2(1.0, 1.0)), COL_SOCKET)


## A sand slab like painting_slab.png filling `rect` on `canvas`: ink rim, a highlight, the sand.
static func draw_sand_slab(canvas: CanvasItem, rect: Rect2) -> void:
	canvas.draw_rect(rect, COL_RIM)
	canvas.draw_rect(rect.grow(-1.0), COL_HIGHLIGHT)
	canvas.draw_rect(rect.grow(-2.0), COL_SAND)
	canvas.draw_rect(Rect2(rect.position + Vector2(2.0, rect.size.y - 3.0), Vector2(rect.size.x - 4.0, 1.0)),
			COL_SAND.darkened(0.2))


## Paintings a reward (Save.UNLOCK_* id) needs (UnlockTable).
static func reward_needs(reward: StringName) -> int:
	return UnlockTable.paintings_needed(reward)


## The translated name of a reward.
static func reward_text(reward: StringName) -> String:
	var entry: Dictionary = UnlockTable.reward(reward)
	var key: String = str(entry.get("text", REWARD_KEYS.get(reward, String(reward))))
	return TranslationServer.translate(key)


## The line under the slab: "3 more: Mesa Rodeo arena", or "Every painting found!" (UnlockTable.next_reward).
static func next_text() -> String:
	var next: Dictionary = UnlockTable.next_reward()
	if next.is_empty():
		return TranslationServer.translate("UI_PAINTINGS_ALL")
	return TranslationServer.translate("UI_PAINTINGS_NEXT").format({
		"count": int(next["missing"]), "reward": reward_text(next["id"])})


## Where painting `index` hides: "5-1 Red Mesa Trail" for a Book II level, "Co-op: 1-1 Fresh Meadow" for a Book I
## co-op secret (the name alone for a stage without a number; "9-2" from the id while the level is not in this
## build).
static func painting_where(index: int) -> String:
	var level_id: StringName = UnlockTable.painting_level(index)
	if level_id == &"":
		return ""
	var name: String = String(level_id)
	var parts: RegexMatch = RegEx.create_from_string("^w(\\d+)_l(\\d+)(b?)").search(name)
	if parts != null:
		# A stage still being built: its number ("9-2b") rather than the file id.
		name = "%s-%s%s" % [parts.get_string(1), parts.get_string(2), parts.get_string(3)]
	if Levels.has_level(level_id):
		var number: String = UiKit.level_number(level_id)
		name = UiKit.level_name(level_id) if number == "" else "%s %s" % [number, UiKit.level_name(level_id)]
	if UnlockTable.is_coop_only(index):
		return TranslationServer.translate("UI_PAINTINGS_COOP").format({"level": name})
	return name


## The socket of `index` (tests).
func get_slot(index: int) -> PaintingSlot:
	return _slab.slots[index] if index >= 0 and index < _slab.slots.size() else null


## The reward rows' status texts, in UnlockTable.REWARDS order (tests).
func get_reward_status() -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for label: Label in _rows:
		result.append(label.text)
	return result


## The picture of the focused painting (tests).
func get_picture() -> PaintingPicture:
	return _picture


## The info line of the focused socket.
func get_info_text() -> String:
	return _info.text


## Back to where the screen was opened from.
func leave() -> void:
	if not begin_leave():
		return
	Audio.play_sfx(Sfx.MENU_BACK)
	if _back_screen() == Flow.SCREEN_VERSUS_LOBBY:
		VersusLobbyScreen.keep_ready_on_return()
		Flow.open_versus_lobby()
	else:
		Flow.goto_title()


func _on_cancel() -> void:
	leave()


func _on_tap() -> void:
	pass


func _back_screen() -> StringName:
	return StringName(str(Flow.args.get("back", Flow.SCREEN_TITLE)))


## The first painting not found yet (the hunt goes on there), or the first socket.
func _first_focus() -> int:
	for index: int in Tuning.PAINTING_COUNT:
		if not Save.has_painting(index):
			return index
	return 0


func _on_slot_focused(index: int) -> void:
	focused_index = index
	_picture.show_painting(index)
	var found: bool = Save.has_painting(index)
	_info.text = painting_where(index) if found else "%s  -  %s" % [painting_where(index), tr("UI_PAINTINGS_MISSING")]
	_info.add_theme_color_override(&"font_color", UiKit.COL_CREAM if found else UiKit.COL_DIM)


## One rung of the reward ladder (an entry of UnlockTable.REWARDS, number `reward_index`): its icon (lit once open),
## its name, and "Unlocked!" or the paintings it needs.
func _reward_row(entry: Dictionary, reward_index: int) -> Control:
	var reward: StringName = entry["id"]
	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override(&"separation", 4)
	var open: bool = UnlockTable.is_open(reward)
	var icon: TextureRect = TextureRect.new()
	var atlas: AtlasTexture = AtlasTexture.new()
	atlas.atlas = UiKit.tex(TEX_UNLOCK_ICONS)
	atlas.region = reward_icon_region(reward_index, open)
	icon.texture = atlas
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	var texts: VBoxContainer = VBoxContainer.new()
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.add_theme_constant_override(&"separation", -3)
	var name: Label = UiKit.label(reward_text(reward), UiKit.Style.SMALL)
	name.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	name.custom_minimum_size = Vector2(150.0, 0.0)
	name.add_theme_color_override(&"font_color", UiKit.COL_CREAM if open else UiKit.COL_DIM)
	texts.add_child(name)
	var status: Label = UiKit.label("", UiKit.Style.SMALL)
	status.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	if open:
		status.text = tr("UI_PAINTINGS_OPEN")
		status.add_theme_color_override(&"font_color", UiKit.COL_GOOD)
	else:
		status.text = tr("UI_PAINTINGS_NEEDS").format({"count": reward_needs(reward)})
		status.add_theme_color_override(&"font_color", UiKit.COL_DIM)
	texts.add_child(status)
	row.add_child(texts)
	_rows.append(status)
	return row
