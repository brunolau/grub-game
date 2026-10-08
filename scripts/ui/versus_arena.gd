class_name VersusArenaScreen
extends UiScreen
## The arena select of a versus match (DESIGN.md E.8 step 3, E.5; PLAN.md P2.8; Flow.SCREEN_VERSUS_ARENA).
##
## A grid of cards: **Random** first (a different arena of the mode every round), then every arena for this many
## players and the match's mode (VersusMatch.available_arenas; developer `test_*` arenas too in debug builds), then
## **Party Mix** (arena and mode per round). Each arena card shows a thumbnail - art-A's `ui/arena/thumb_<id>.png`, or
## a mini map drawn from the arena file ([method thumbnail]: terrain, ledges, liquid, spots, springs, cookpots and
## spawns in the biome's colours) - its name and how many players it takes. An arena a painting reward opens
## (UnlockTable.reward_of_arena) shows a lock and the paintings its reward needs until it is open; it cannot be
## chosen (the info line says how many are still missing, VersusMatch.arena_paintings_needed).
##
## G50 (PLAN.md cut 4's switch): an arena's meta `bots` (a list of modes, or `none`; default every mode it has) names the
## modes CPUs play it in. While a CPU seat is filled, an arena whose `bots` leaves out the match's mode shows greyed with
## "Humans only" and cannot be chosen ([method bots_play]); with every seat human it is offered as any other.
##
## The focused card is the match's arena (Game.versus_match.arena); confirm starts the match (Flow.start_versus).
## Like the rules screen, only the owner (args {"owner": slot}, the player who pressed START) drives it. "Back" returns
## to the rules.

## Size of a thumbnail (art px): one arena cell = THUMB_CELL px.
const THUMB_CELL: int = 6
const THUMB_SIZE: Vector2i = Vector2i(VersusTuning.ARENA_COLS * THUMB_CELL, VersusTuning.ARENA_ROWS * THUMB_CELL)
const THUMB_DIR: String = "res://assets/ui/arena/thumb_"
const CARD_SIZE: Vector2 = Vector2(140.0, 104.0)
const COLUMNS: int = 4
## Colours of the mini maps by biome: [sky top, sky bottom, ground, ground top, liquid].
const BIOME_COLOURS: Dictionary = {
	"jungle": [Color("8fd8ff"), Color("c8f0ff"), Color("6b4a2b"), Color("5fbf3a"), Color("3f9fe8")],
	"cave": [Color("2d2541"), Color("4a3f63"), Color("6a6478"), Color("9c96aa"), Color("3f7fc8")],
	"ice": [Color("a8d8ff"), Color("e6f6ff"), Color("7fa6c9"), Color("ffffff"), Color("3f9fe8")],
	"volcano": [Color("a8301a"), Color("e0704a"), Color("3a2a2a"), Color("7a4a3a"), Color("ff8a1a")],
	"swamp": [Color("3d5a52"), Color("7a9a7a"), Color("3a3326"), Color("6b7a3a"), Color("2a2238")],
	"coast": [Color("7fd0ff"), Color("d0f2ff"), Color("c2a26a"), Color("f0d89a"), Color("2f8fd8")],
	"feast": [Color("ffc8e0"), Color("fff0f6"), Color("c98a5a"), Color("ffb3d9"), Color("ff7ab8")],
	"canyon": [Color("f0a060"), Color("ffe0a8"), Color("a8482a"), Color("e08a4a"), Color("3f9fe8")],
	"ruins": [Color("6aa0a0"), Color("c0e0d0"), Color("6a6a5a"), Color("8fbf6a"), Color("3f9fe8")],
	"sky": [Color("b8c8f0"), Color("eef3ff"), Color("6b7895"), Color("e7edf7"), Color("3f9fe8")],
}
const LIQUID_COLOURS: Dictionary = {
	"water": Color("3f9fe8"), "lava": Color("ff8a1a"), "tar": Color("2a2238"), "honey": Color("f0b030"),
	"syrup": Color("ff7ab8"),
}

static var _thumbs: Dictionary = {}

## The player slot whose Start opened the rules (-1 = anybody drives it).
var owner_slot: int = -1

var _cards: Array[ArenaCard] = []
var _info: Label = null
var _status: Label = null
var _scroll: ScrollContainer = null


## One choice of the grid: Random, Party Mix or an arena (its thumbnail, name and players; locked: a lock and the
## paintings it needs).
class ArenaCard:
	extends Button

	## VersusMatch.ARENA_RANDOM, ARENA_PARTY_MIX or an arena id.
	var arena: StringName = &""
	## True while a painting reward keeps the arena closed.
	var locked: bool = false
	## Paintings the reward needs (locked cards).
	var needs: int = 0
	## G50: true while a CPU is seated and the arena's `bots` leaves out the match's mode (it cannot be chosen).
	var humans_only: bool = false

	var _thumb: Texture2D = null
	var _small: Font = UiKit.font(UiKit.Style.SMALL)
	var _hud: Font = UiKit.font(UiKit.Style.HUD)
	var _body: Font = UiKit.font(UiKit.Style.BODY)
	var _time: float = 0.0

	func _init(p_arena: StringName, p_locked: bool, p_needs: int, p_humans_only: bool = false) -> void:
		arena = p_arena
		locked = p_locked
		needs = p_needs
		humans_only = p_humans_only
		flat = true
		focus_mode = Control.FOCUS_ALL
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		custom_minimum_size = VersusArenaScreen.CARD_SIZE
		if arena != VersusMatch.ARENA_RANDOM and arena != VersusMatch.ARENA_PARTY_MIX:
			_thumb = VersusArenaScreen.thumbnail(arena)
		focus_entered.connect(_on_focus)
		focus_exited.connect(queue_redraw)
		gui_input.connect(_on_gui_input)

	func _process(delta: float) -> void:
		if arena == VersusMatch.ARENA_RANDOM or arena == VersusMatch.ARENA_PARTY_MIX:
			_time += delta
			queue_redraw()

	func _on_focus() -> void:
		UiKit.play_focus_sound()
		queue_redraw()

	func _on_gui_input(event: InputEvent) -> void:
		if event is InputEventMouseMotion and not has_focus():
			grab_focus()

	func _draw() -> void:
		var focused: bool = has_focus()
		var lift: float = -3.0 if focused else 0.0
		var rect: Rect2 = Rect2(Vector2(0.0, 3.0 + lift), size - Vector2(0.0, 3.0))
		draw_rect(rect, UiKit.COL_INK)
		draw_rect(rect.grow(-2.0), Color("5a4a3a") if not focused else Color("7a6248"))
		var picture: Rect2 = Rect2(Vector2(roundf((size.x - float(VersusArenaScreen.THUMB_SIZE.x)) * 0.5), rect.position.y
				+ 6.0), Vector2(VersusArenaScreen.THUMB_SIZE))
		draw_rect(picture.grow(1.0), UiKit.COL_INK)
		match arena:
			VersusMatch.ARENA_RANDOM:
				_draw_random(picture)
			VersusMatch.ARENA_PARTY_MIX:
				_draw_party_mix(picture)
			_:
				if _thumb != null:
					draw_texture_rect(_thumb, picture, false, Color(0.35, 0.35, 0.4) if locked or humans_only
							else Color.WHITE)
				if locked:
					_draw_lock(picture.get_center())
				elif humans_only:
					_draw_humans_only(picture)
		var name: String = tr(VersusArenaScreen.card_title(arena))
		var name_font: Font = _small
		var name_size: int = UiKit.SIZE_SMALL
		var baseline: float = picture.end.y + 14.0
		var width: float = name_font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1.0, name_size).x
		while name.length() > 3 and width > size.x - 8.0:
			name = name.left(name.length() - 2) + "."
			width = name_font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1.0, name_size).x
		var colour: Color = UiKit.COL_FOCUS if focused else UiKit.COL_CREAM
		if locked or humans_only:
			colour = UiKit.COL_DIM
		draw_string_outline(name_font, Vector2(roundf((size.x - width) * 0.5), baseline), name,
				HORIZONTAL_ALIGNMENT_LEFT, -1.0, name_size, 4, UiKit.COL_INK)
		draw_string(name_font, Vector2(roundf((size.x - width) * 0.5), baseline), name, HORIZONTAL_ALIGNMENT_LEFT,
				-1.0, name_size, colour)
		if focused:
			draw_rect(rect, UiKit.COL_FOCUS, false, 2.0)

	## A big die on the picture, its face changing.
	func _draw_random(picture: Rect2) -> void:
		draw_rect(picture, Color("3a4a6a"))
		var die: Rect2 = Rect2(picture.get_center() - Vector2(18.0, 18.0), Vector2(36.0, 36.0))
		draw_rect(die.grow(2.0), UiKit.COL_INK)
		draw_rect(die, Color("fff1cf"))
		var face: int = int(_time * 3.0) % 6 + 1
		var spots: Dictionary = {
			1: [Vector2(0, 0)], 2: [Vector2(-1, -1), Vector2(1, 1)], 3: [Vector2(-1, -1), Vector2(0, 0), Vector2(1, 1)],
			4: [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)],
			5: [Vector2(-1, -1), Vector2(1, -1), Vector2(0, 0), Vector2(-1, 1), Vector2(1, 1)],
			6: [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 0), Vector2(1, 0), Vector2(-1, 1), Vector2(1, 1)],
		}
		for spot: Vector2 in spots[face]:
			draw_rect(Rect2(die.get_center() + spot * 10.0 - Vector2(3.0, 3.0), Vector2(6.0, 6.0)), UiKit.COL_INK)

	## Four small arena tiles, turning.
	func _draw_party_mix(picture: Rect2) -> void:
		draw_rect(picture, Color("6a3a5a"))
		var colours: Array[Color] = [Color("5fbf3a"), Color("9c96aa"), Color("ffffff"), Color("ff8a1a")]
		var shift: int = int(_time * 2.0) % 4
		for i: int in 4:
			var cell: Rect2 = Rect2(picture.position + Vector2(14.0 + float(i % 2) * 48.0, 6.0 + float(i / 2) * 28.0),
					Vector2(44.0, 24.0))
			draw_rect(cell.grow(1.0), UiKit.COL_INK)
			draw_rect(cell, Color("8fd8ff"))
			draw_rect(Rect2(cell.position + Vector2(0.0, 18.0), Vector2(44.0, 6.0)), colours[(i + shift) % 4])

	## G50: "Humans only" across the greyed picture, in the small face on an ink band.
	func _draw_humans_only(picture: Rect2) -> void:
		var text: String = tr("UI_VS_ARENA_HUMANS_ONLY")
		var width: float = _small.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, UiKit.SIZE_SMALL).x
		var band: Rect2 = Rect2(Vector2(picture.position.x, roundf(picture.get_center().y - 8.0)),
				Vector2(picture.size.x, 16.0))
		draw_rect(band, Color(UiKit.COL_INK, 0.75))
		var at: Vector2 = Vector2(roundf(picture.get_center().x - width * 0.5), band.position.y + 12.0)
		draw_string_outline(_small, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, UiKit.SIZE_SMALL, 4, UiKit.COL_INK)
		draw_string(_small, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, UiKit.SIZE_SMALL, UiKit.COL_CREAM)

	func _draw_lock(centre: Vector2) -> void:
		var body: Rect2 = Rect2(centre - Vector2(10.0, 2.0), Vector2(20.0, 16.0))
		draw_arc(centre + Vector2(0.0, -2.0), 7.0, PI, TAU, 10, UiKit.COL_INK, 5.0)
		draw_arc(centre + Vector2(0.0, -2.0), 7.0, PI, TAU, 10, Color("c9b27a"), 2.0)
		draw_rect(body.grow(1.0), UiKit.COL_INK)
		draw_rect(body, Color("e8a930"))
		draw_rect(Rect2(centre + Vector2(-1.0, 3.0), Vector2(2.0, 6.0)), UiKit.COL_INK)
		var text: String = str(needs)
		var width: float = _hud.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, UiKit.SIZE_HUD).x
		var at: Vector2 = Vector2(roundf(centre.x - width * 0.5), centre.y + 32.0)
		draw_string_outline(_hud, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, UiKit.SIZE_HUD, 4, UiKit.COL_INK)
		draw_string(_hud, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, UiKit.SIZE_HUD, UiKit.COL_FOCUS)


func _build_screen() -> void:
	add_child(UiBackdrop.new("jungle", 24.0))
	var shade: ColorRect = ColorRect.new()
	shade.color = Color(UiKit.COL_INK, 0.4)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	if Game.versus_match == null:
		Game.versus_match = VersusMatch.from_settings()
	var versus_match: VersusMatch = Game.versus_match
	owner_slot = int(Flow.args.get("owner", versus_match.rules_owner))

	var column: VBoxContainer = VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override(&"separation", 3)
	safe.add_child(column)
	column.add_child(UiKit.label("UI_VS_ARENA_HEADING", UiKit.Style.TITLE, HORIZONTAL_ALIGNMENT_CENTER))
	var line: Label = UiKit.label(subtitle_text(), UiKit.Style.SMALL, HORIZONTAL_ALIGNMENT_CENTER)
	line.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	column.add_child(line)

	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	column.add_child(_scroll)
	var centre: CenterContainer = CenterContainer.new()
	centre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scroll.add_child(centre)
	var grid: GridContainer = GridContainer.new()
	grid.columns = COLUMNS
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid.add_theme_constant_override(&"h_separation", 8)
	grid.add_theme_constant_override(&"v_separation", 6)
	centre.add_child(grid)
	for entry: Array in choices(maxi(versus_match.player_count(), VersusTuning.PLAYERS_MIN), versus_match.mode,
			has_cpu(versus_match)):
		var card: ArenaCard = ArenaCard.new(entry[0], bool(entry[1]), int(entry[2]), bool(entry[3]))
		card.pressed.connect(choose.bind(card.arena))
		card.focus_entered.connect(_on_card_focused.bind(card))
		grid.add_child(card)
		_cards.append(card)

	_info = UiKit.label("", UiKit.Style.SMALL, HORIZONTAL_ALIGNMENT_CENTER)
	_info.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_info.custom_minimum_size = Vector2(0.0, 14.0)
	column.add_child(_info)
	_status = UiKit.label("", UiKit.Style.SMALL, HORIZONTAL_ALIGNMENT_CENTER)
	_status.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_status.add_theme_color_override(&"font_color", UiKit.COL_BAD)
	column.add_child(_status)
	var prompts: UiPrompts = UiPrompts.new()
	prompts.alignment = BoxContainer.ALIGNMENT_END
	prompts.add_hint(&"ui_accept", "UI_VS_START")
	prompts.add_hint(&"ui_cancel", "UI_HINT_BACK", _on_cancel)
	column.add_child(prompts)
	_link_focus()


func _screen_ready() -> void:
	Audio.play_music(Sfx.MUSIC_VERSUS_LOBBY)
	GameInput.set_menu_clusters(true)
	Flow.play_mode = Defs.GameMode.VERSUS
	var at: int = 0
	for i: int in _cards.size():
		if _cards[i].arena == Game.versus_match.arena and not _cards[i].locked and not _cards[i].humans_only:
			at = i
	UiKit.focus_silently(_cards[at])
	_on_card_focused(_cards[at])


## Only the owner's devices drive the screen (VersusRulesScreen.is_foreign).
func _input(event: InputEvent) -> void:
	if not is_accepting_input() or owner_slot < 0:
		return
	if event is InputEventKey or event is InputEventJoypadButton or event is InputEventJoypadMotion:
		var slot: int = GameInput.event_slot(event)
		if slot >= 0 and slot != owner_slot:
			get_viewport().set_input_as_handled()


## The cards for a match of `players` in `mode` (Defs.VersusMode): [id, locked, paintings its reward needs, humans
## only] - Random, the open arenas (VersusMatch.available_arenas), the closed ones that fit (UnlockTable.is_arena_open),
## the developer arenas in debug builds, Party Mix. With `with_cpu` (a CPU seat is filled) an open arena whose `bots`
## leaves out `mode` is "humans only" (G50, [method bots_play]).
static func choices(players: int, mode: int, with_cpu: bool = false) -> Array[Array]:
	var result: Array[Array] = [[VersusMatch.ARENA_RANDOM, false, 0, false]]
	var mode_name: StringName = Defs.versus_mode_name(mode)
	var open: Array[StringName] = VersusMatch.available_arenas(players, mode)
	for id: StringName in Levels.get_arenas(players, mode_name):
		var humans_only: bool = with_cpu and not bots_play(id, mode)
		if open.has(id):
			result.append([id, false, 0, humans_only])
		elif not UnlockTable.is_arena_open(id):
			result.append([id, true, UnlockTable.paintings_needed(UnlockTable.reward_of_arena(id)), false])
		elif OS.is_debug_build() and String(id).begins_with(VersusMatch.DEVELOPER_ARENA_PREFIX):
			result.append([id, false, 0, humans_only])
	result.append([VersusMatch.ARENA_PARTY_MIX, false, 0, false])
	return result


## G50 (DESIGN.md appendix, PLAN.md cut 4's switch): the launch modes CPUs play `arena_id` in - its meta `bots`, a list
## of mode names (`bots = grub_stack,last_caveman`) or `none`; without the key (or with an empty one) every mode the
## arena has (VersusMatch.arena_modes).
static func bot_modes(arena_id: StringName) -> Array[int]:
	var modes: Array[int] = VersusMatch.arena_modes(arena_id)
	var value: Variant = Levels.get_value(arena_id, "bots", null)
	if value == null or str(value).strip_edges() == "":
		return modes
	var listed: PackedStringArray = PackedStringArray()
	for part: String in LevelText.to_list(value):
		listed.append(part.strip_edges())
	var result: Array[int] = []
	for mode: int in modes:
		if listed.has(String(Defs.versus_mode_name(mode))):
			result.append(mode)
	return result


## G50: true when CPUs may play `arena_id` in `mode` (Random and Party Mix: the round's pick decides).
static func bots_play(arena_id: StringName, mode: int) -> bool:
	if arena_id == VersusMatch.ARENA_RANDOM or arena_id == VersusMatch.ARENA_PARTY_MIX:
		return true
	return bot_modes(arena_id).has(mode)


## True when a CPU seat of `versus_match` is filled.
static func has_cpu(versus_match: VersusMatch) -> bool:
	return versus_match != null and versus_match.player_count() > versus_match.human_count()


## G50: "Humans only: no CPU plays Grub Stack here."
static func humans_only_text(mode: int) -> String:
	return TranslationServer.translate("UI_VS_ARENA_HUMANS_ONLY_INFO").format({"mode": TranslationServer.translate(
			str(VersusLobbyScreen.MODE_KEYS.get(mode, [""])[0]))})


## The title of a card: Random, Party Mix or the arena's name.
static func card_title(arena_id: StringName) -> String:
	return VersusLobbyScreen.arena_text(arena_id)


## "Grub Stack, 4 players".
static func subtitle_text() -> String:
	var versus_match: VersusMatch = Game.versus_match
	if versus_match == null:
		return ""
	var mode_key: String = str(VersusLobbyScreen.MODE_KEYS.get(versus_match.mode, [""])[0])
	return "%s  -  %s" % [TranslationServer.translate(mode_key),
			TranslationServer.translate("UI_VS_FIRST_TO").format({"wins": versus_match.round_wins_needed()})]


## The thumbnail of an arena: art-A's picture when it exists, else a mini map drawn from the arena file (cached).
static func thumbnail(arena_id: StringName) -> Texture2D:
	var art: String = THUMB_DIR + String(arena_id) + ".png"
	if ResourceLoader.exists(art):
		return UiKit.tex(art)
	if _thumbs.has(arena_id):
		return _thumbs[arena_id]
	var image: Image = mini_map(arena_id)
	var texture: Texture2D = ImageTexture.create_from_image(image) if image != null else null
	_thumbs[arena_id] = texture
	return texture


## A mini map of an arena file, THUMB_CELL px per cell: the sky of its biome, solid ground with its top row lit,
## one-way ledges as planks, liquids, tar floors, breakable blocks, spikes, food spots (gold, the big spot larger),
## springs (red), cookpots (dark) and spawn points in the player colours; small arrows on the edges that wrap.
static func mini_map(arena_id: StringName) -> Image:
	var path: String = Levels.get_level_path(arena_id)
	if path == "" or not FileAccess.file_exists(path):
		return null
	var sections: Dictionary = LevelText.split_sections(FileAccess.get_file_as_string(path))
	var rows: PackedStringArray = sections.get("tiles", PackedStringArray())
	var legend: Dictionary = LevelText.parse_legend(sections.get("legend", PackedStringArray()))
	var biome: String = str(Levels.get_value(arena_id, "biome", "jungle"))
	var colours: Array = BIOME_COLOURS.get(biome, BIOME_COLOURS["jungle"])
	var liquid_name: String = str(Levels.get_value(arena_id, "liquid", ""))
	var liquid: Color = LIQUID_COLOURS.get(liquid_name, colours[4])
	var image: Image = Image.create(THUMB_SIZE.x, THUMB_SIZE.y, false, Image.FORMAT_RGBA8)
	for y: int in THUMB_SIZE.y:
		image.fill_rect(Rect2i(0, y, THUMB_SIZE.x, 1), (colours[0] as Color).lerp(colours[1], float(y) / float(THUMB_SIZE.y)))
	var c: int = THUMB_CELL
	for row: int in mini(rows.size(), VersusTuning.ARENA_ROWS):
		var line: String = rows[row]
		for col: int in mini(line.length(), VersusTuning.ARENA_COLS):
			var ch: String = line[col]
			var cell: Rect2i = Rect2i(col * c, row * c, c, c)
			var tile: String = ch
			var entity: StringName = &""
			if legend.has(ch):
				entity = (legend[ch] as Dictionary)["id"]
				tile = str(((legend[ch] as Dictionary)["params"] as Dictionary).get("tile", "."))
			_paint_tile(image, cell, tile, row, rows, col, colours, liquid)
			_paint_entity(image, cell, entity, legend.get(ch, {}) as Dictionary, ch)
	var wrap: String = str(Levels.get_value(arena_id, "wrap", "none"))
	var arrow: Color = Color("fff1cf")
	if wrap == "lr":
		for y: int in [THUMB_SIZE.y / 2 - 2, THUMB_SIZE.y / 2 + 1]:
			image.fill_rect(Rect2i(0, y, 3, 1), arrow)
			image.fill_rect(Rect2i(THUMB_SIZE.x - 3, y, 3, 1), arrow)
	elif wrap == "tb":
		for x: int in [THUMB_SIZE.x / 2 - 2, THUMB_SIZE.x / 2 + 1]:
			image.fill_rect(Rect2i(x, 0, 1, 3), arrow)
			image.fill_rect(Rect2i(x, THUMB_SIZE.y - 3, 1, 3), arrow)
	return image


static func _paint_tile(image: Image, cell: Rect2i, tile: String, row: int, rows: PackedStringArray, col: int,
		colours: Array, liquid: Color) -> void:
	var ground: Color = colours[2]
	var top: Color = colours[3]
	match tile:
		"#", "%", ";", "/", "\\":
			image.fill_rect(cell, ground if tile != "%" else (ground as Color).darkened(0.15))
			var above: String = rows[row - 1][col] if row > 0 and col < rows[row - 1].length() else "."
			if above == "." or above == "-" or above == "=" or above == "@":
				image.fill_rect(Rect2i(cell.position, Vector2i(cell.size.x, 2)), top)
		"-", "=", "_":
			image.fill_rect(Rect2i(cell.position, Vector2i(cell.size.x, 2)), (ground as Color).lightened(0.25))
			image.fill_rect(Rect2i(cell.position + Vector2i(0, 2), Vector2i(cell.size.x, 1)), (ground as Color).darkened(0.3))
		"~":
			image.fill_rect(cell, liquid)
			image.fill_rect(Rect2i(cell.position, Vector2i(cell.size.x, 1)), liquid.lightened(0.35))
		":":
			image.fill_rect(cell, ground)
			image.fill_rect(Rect2i(cell.position, Vector2i(cell.size.x, 2)), Color("2a2238"))
		"$":
			image.fill_rect(cell, (ground as Color).lightened(0.2))
			image.fill_rect(cell.grow(-1), (ground as Color).lightened(0.35))
		"^", "!":
			for i: int in 3:
				image.fill_rect(Rect2i(cell.position.x + i * 2, cell.end.y - 2 - (i % 2), 1, 2 + (i % 2)), Color("e8e8f0"))
		"@":
			_paint_spawn(image, cell, 1)


static func _paint_entity(image: Image, cell: Rect2i, entity: StringName, entry: Dictionary, ch: String) -> void:
	var params: Dictionary = entry.get("params", {}) as Dictionary
	match entity:
		&"objects/hidden_spot":
			var big: bool = str(params.get("kind", "small")) == "big" or ch == "*"
			var dot: Rect2i = cell.grow(-1) if big else Rect2i(cell.position + Vector2i(2, 2), Vector2i(2, 2))
			image.fill_rect(dot, Color("ffd75e"))
		&"objects/spring":
			image.fill_rect(Rect2i(cell.position + Vector2i(1, cell.size.y - 3), Vector2i(cell.size.x - 2, 3)),
					Color("ff6b5a"))
		&"objects/cookpot":
			image.fill_rect(Rect2i(cell.position + Vector2i(0, 2), Vector2i(cell.size.x, cell.size.y - 2)), UiKit.COL_INK)
			image.fill_rect(Rect2i(cell.position + Vector2i(1, 3), Vector2i(cell.size.x - 2, 1)), Color("ff8a1a"))
		&"objects/spawn_point":
			_paint_spawn(image, cell, int(params.get("index", 1)))


static func _paint_spawn(image: Image, cell: Rect2i, index: int) -> void:
	var colour: Color = UiPlayers.PALETTE_COLOURS[UiPlayers.SLOT_PALETTES[clampi(index - 1, 0, 3)]][UiPlayers.FILL]
	image.fill_rect(Rect2i(cell.position + Vector2i(1, 1), Vector2i(cell.size.x - 2, cell.size.y - 1)), UiKit.COL_INK)
	image.fill_rect(Rect2i(cell.position + Vector2i(2, 2), Vector2i(cell.size.x - 4, cell.size.y - 3)), colour)


## The cards (tests), Random first.
func get_cards() -> Array[ArenaCard]:
	return _cards


## The card of `arena_id`, or null.
func get_card(arena_id: StringName) -> ArenaCard:
	for card: ArenaCard in _cards:
		if card.arena == arena_id:
			return card
	return null


## The info line under the grid.
func get_info_text() -> String:
	return _info.text


## The status line (why the match does not start).
func get_status_text() -> String:
	return _status.text


## Choose `arena_id` and start the match (Flow.start_versus). A locked arena, or a match that cannot start, stays.
func choose(arena_id: StringName) -> void:
	if not is_accepting_input():
		return
	var card: ArenaCard = get_card(arena_id)
	if card != null and card.locked:
		Audio.play_sfx(Sfx.MENU_BACK)
		_status.text = tr("UI_VS_ARENA_LOCKED_INFO").format({"count": VersusMatch.arena_paintings_needed(arena_id)})
		return
	if card != null and card.humans_only:
		Audio.play_sfx(Sfx.MENU_BACK)
		_status.text = humans_only_text(Game.versus_match.mode)
		return
	var versus_match: VersusMatch = Game.versus_match
	versus_match.arena = arena_id
	if not versus_match.can_start():
		Audio.play_sfx(Sfx.MENU_BACK)
		_status.text = tr("UI_VS_NOT_READY")
		return
	if versus_match.arena_for_round(0) == &"":
		Audio.play_sfx(Sfx.MENU_BACK)
		_status.text = tr("UI_VS_NO_ARENA")
		return
	if not begin_leave():
		return
	Audio.play_sfx(Sfx.MENU_SELECT)
	if not Flow.start_versus():
		leaving = false
		_status.text = tr("UI_VS_NOT_READY")


func _on_cancel() -> void:
	if not begin_leave():
		return
	Audio.play_sfx(Sfx.MENU_BACK)
	Flow.goto_screen(Flow.SCREEN_VERSUS_RULES, Defs.Transition.FADE, {"owner": owner_slot})


func _on_tap() -> void:
	pass


## The focused card becomes the match's arena (unless it is locked or humans only) and explains itself on the info line.
func _on_card_focused(card: ArenaCard) -> void:
	_status.text = ""
	if not card.locked and not card.humans_only:
		Game.versus_match.arena = card.arena
	match card.arena:
		VersusMatch.ARENA_RANDOM:
			_info.text = tr("UI_VS_ARENA_RANDOM_INFO")
		VersusMatch.ARENA_PARTY_MIX:
			_info.text = tr("UI_VS_ARENA_PARTY_MIX_INFO")
		_:
			if card.locked:
				_info.text = tr("UI_VS_ARENA_LOCKED_INFO").format({"count": VersusMatch.arena_paintings_needed(card.arena)})
			elif card.humans_only:
				_info.text = humans_only_text(Game.versus_match.mode)
			else:
				_info.text = arena_info(card.arena)


## "Grub Stack, Hot Rock  -  Up to 4 players" (a developer arena says so).
static func arena_info(arena_id: StringName) -> String:
	var names: PackedStringArray = PackedStringArray()
	for mode: int in VersusMatch.arena_modes(arena_id):
		names.append(TranslationServer.translate(str(VersusLobbyScreen.MODE_KEYS[mode][0])))
	var players: String = TranslationServer.translate("UI_VS_ARENA_PLAYERS").format(
			{"count": int(Levels.get_value(arena_id, "players", VersusTuning.PLAYERS_MAX))})
	var text: String = "%s  -  %s" % [", ".join(names), players]
	if String(arena_id).begins_with(VersusMatch.DEVELOPER_ARENA_PREFIX):
		text = "%s  (%s)" % [text, TranslationServer.translate("UI_VS_ARENA_TEST")]
	return text


## Focus: the grid row by row; Left / Right wrap inside the list, Up / Down by a row.
func _link_focus() -> void:
	var count: int = _cards.size()
	for i: int in count:
		var card: ArenaCard = _cards[i]
		card.focus_neighbor_left = card.get_path_to(_cards[posmod(i - 1, count)])
		card.focus_neighbor_right = card.get_path_to(_cards[(i + 1) % count])
		card.focus_neighbor_top = card.get_path_to(_cards[i - COLUMNS] if i - COLUMNS >= 0 else _cards[i])
		card.focus_neighbor_bottom = card.get_path_to(_cards[i + COLUMNS] if i + COLUMNS < count else _cards[count - 1])
