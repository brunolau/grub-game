class_name BookSelectScreen
extends UiScreen
## The book select of Solo and Co-op (DESIGN.md A.1, GAMEPLAY.md 13.1, PLAN.md P1.11): two carved slabs, Book I "The
## First Feast" and Book II "The Far Shore" (open from the start). Each slab shows its first world with the heroes of
## the mode (Grub alone in Solo - with the spear on Book II - or both players in their colours in Co-op), its name,
## its lands and the best score of that mode and book. Confirm = Flow.choose_book(book) (-> Beginner / Expert);
## "back" = the join panel in Co-op (the party stays), the title in Solo. A book without any level in this build
## (development) is shown but cannot be chosen.
##
## In Co-op both players drive the slabs from their own key cluster (GameInput menu clusters).

## One entry per book: caption key, name key, lands key, backdrop set (assets/backgrounds/<set>/), its layers back to
## front, the part of the 1600 x 360 layers the slab shows, the hero sheet of the picture.
const BOOKS: Array[Array] = [
	["UI_BOOK_1", "UI_BOOK_1_NAME", "UI_BOOK_1_INFO", "jungle",
		["layer0_sky", "layer1_far_hills", "layer2_hills", "layer3_forest"], Rect2(870.0, 150.0, 226.0, 92.0),
		"res://assets/sprites/player/hero.png"],
	["UI_BOOK_2", "UI_BOOK_2_NAME", "UI_BOOK_2_INFO", "canyon",
		["layer0_sky", "layer1_far_spires", "layer2_mesas", "layer3_ridge"], Rect2(682.0, 150.0, 226.0, 92.0),
		"res://assets/sprites/player/hero_spear.png"],
]
const CARD_SIZE: Vector2 = Vector2(250.0, 204.0)
const PICTURE_SIZE: Vector2 = Vector2(226.0, 92.0)
## The hero's idle frame inside his 176 x 112 cell, and where his feet stand on the picture.
const HERO_CELL: Vector2i = Vector2i(176, 112)
const HERO_BODY: Rect2 = Rect2(48.0, 26.0, 80.0, 72.0)
const HERO_FEET_Y: float = 96.0
const FEET_FROM_BOTTOM: float = 6.0

var _cards: Array[BookCard] = []


## One book slab: a button with the book's picture, caption, name and lands.
class BookCard:
	extends Button

	const LIFT_PX: float = 6.0
	const DIM: Color = Color(0.72, 0.72, 0.72, 1.0)

	## The book (1 / 2).
	var book: int = 1
	## False when this build has no level of the book (it cannot be chosen).
	var available: bool = true

	var _body: Control = null
	var _caption: Label = null
	var _lift: Tween = null
	# The backdrop layers drawn on the picture, held while the card shows (UiKit.tex keeps no cache).
	var _layers: Array[Texture2D] = []
	var _crop: Rect2 = Rect2()

	func _init(p_book: int, entry: Array, heroes: Array[Array], p_available: bool, best: int) -> void:
		book = p_book
		available = p_available
		flat = true
		focus_mode = Control.FOCUS_ALL
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		custom_minimum_size = BookSelectScreen.CARD_SIZE
		_body = Control.new()
		_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_body.set_anchors_preset(Control.PRESET_FULL_RECT)
		_body.modulate = DIM
		add_child(_body)
		var back: NinePatchRect = UiKit.panel()
		back.set_anchors_preset(Control.PRESET_FULL_RECT)
		_body.add_child(back)
		var margin: MarginContainer = MarginContainer.new()
		margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		margin.set_anchors_preset(Control.PRESET_FULL_RECT)
		for side: StringName in [&"margin_left", &"margin_top", &"margin_right", &"margin_bottom"]:
			margin.add_theme_constant_override(side, 12)
		_body.add_child(margin)
		var column: VBoxContainer = VBoxContainer.new()
		column.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_theme_constant_override(&"separation", 1)
		margin.add_child(column)
		column.add_child(_picture(entry, heroes))
		_caption = UiKit.label(str(entry[0]), UiKit.Style.HUD, HORIZONTAL_ALIGNMENT_CENTER)
		column.add_child(_caption)
		var title: Label = UiKit.label(str(entry[1]), UiKit.Style.BODY, HORIZONTAL_ALIGNMENT_CENTER)
		column.add_child(title)
		var lands: Label = UiKit.label(str(entry[2]), UiKit.Style.SMALL, HORIZONTAL_ALIGNMENT_CENTER)
		column.add_child(lands)
		var foot: Label = UiKit.label("", UiKit.Style.SMALL, HORIZONTAL_ALIGNMENT_CENTER)
		foot.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		if available:
			foot.text = "%s %s" % [TranslationServer.translate("UI_HIGH_SCORE"), UiKit.score_text(best)]
			foot.add_theme_color_override(&"font_color", UiKit.COL_FOCUS)
		else:
			foot.text = TranslationServer.translate("UI_BOOK_MISSING")
			foot.add_theme_color_override(&"font_color", UiKit.COL_BAD)
		column.add_child(foot)
		focus_entered.connect(_on_focus_changed.bind(true))
		focus_exited.connect(_on_focus_changed.bind(false))
		gui_input.connect(_on_gui_input)

	## The picture: the book's first world (its backdrop layers) with the heroes standing in front.
	func _picture(entry: Array, heroes: Array[Array]) -> Control:
		var frame: Control = Control.new()
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.custom_minimum_size = BookSelectScreen.PICTURE_SIZE + Vector2(4.0, 4.0)
		frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		frame.draw.connect(_draw_frame.bind(frame))
		var view: Control = Control.new()
		view.mouse_filter = Control.MOUSE_FILTER_IGNORE
		view.clip_contents = true
		view.position = Vector2(2.0, 2.0)
		view.size = BookSelectScreen.PICTURE_SIZE
		view.draw.connect(_draw_layers.bind(view))
		frame.add_child(view)
		_crop = entry[5]
		for layer: Variant in entry[4]:
			var texture: Texture2D = UiKit.tex("%s%s/%s.png" % [UiBackdrop.BACKGROUND_DIR, entry[3], layer])
			if texture != null:
				_layers.append(texture)
		var count: int = heroes.size()
		for i: int in count:
			var cell: AtlasTexture = UiKit.cell(str(entry[6]), BookSelectScreen.HERO_CELL, 0)
			var body: Rect2 = BookSelectScreen.HERO_BODY
			cell.region = Rect2(cell.region.position + body.position, body.size)
			var hero: TextureRect = UiKit.picture(cell)
			hero.material = HeroPalette.material_for(heroes[i][0], int(heroes[i][1]))
			var spread: float = 0.0 if count <= 1 else (float(i) - float(count - 1) * 0.5) * 56.0
			hero.position = Vector2(
				roundf((BookSelectScreen.PICTURE_SIZE.x - BookSelectScreen.HERO_BODY.size.x) * 0.5 + spread),
				BookSelectScreen.PICTURE_SIZE.y - BookSelectScreen.FEET_FROM_BOTTOM
						- (BookSelectScreen.HERO_FEET_Y - BookSelectScreen.HERO_BODY.position.y))
			if i % 2 == 1:
				hero.flip_h = true
			view.add_child(hero)
		return frame

	func _draw_frame(frame: Control) -> void:
		frame.draw_rect(Rect2(Vector2.ZERO, frame.size), UiKit.COL_INK)

	func _draw_layers(view: Control) -> void:
		for texture: Texture2D in _layers:
			view.draw_texture_rect_region(texture, Rect2(Vector2.ZERO, BookSelectScreen.PICTURE_SIZE), _crop)

	func _on_focus_changed(focused: bool) -> void:
		if focused:
			UiKit.play_focus_sound()
		_caption.add_theme_color_override(&"font_color", UiKit.COL_FOCUS if focused else UiKit.COL_TEXT)
		if _lift != null and _lift.is_valid():
			_lift.kill()
		_lift = create_tween().set_parallel(true)
		_lift.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_lift.tween_property(_body, "position:y", -LIFT_PX if focused else 0.0, 0.18)
		_lift.tween_property(_body, "modulate", Color.WHITE if focused else DIM, 0.18)

	## The pointer takes the focus when it moves over the card (not when the card appears under a resting pointer).
	func _on_gui_input(event: InputEvent) -> void:
		if event is InputEventMouseMotion and not has_focus():
			grab_focus()


func _build_screen() -> void:
	add_child(UiBackdrop.new("jungle", 24.0))
	var shade: ColorRect = ColorRect.new()
	shade.color = Color(UiKit.COL_INK, 0.25)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	var column: VBoxContainer = VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override(&"separation", 6)
	safe.add_child(column)
	column.add_child(UiKit.label("UI_BOOK_HEADING", UiKit.Style.TITLE, HORIZONTAL_ALIGNMENT_CENTER))
	var mode: Label = UiKit.label("UI_PLAY_COOP" if is_coop() else "UI_PLAY_SOLO", UiKit.Style.HUD,
			HORIZONTAL_ALIGNMENT_CENTER)
	mode.add_theme_color_override(&"font_color", UiKit.COL_CREAM)
	column.add_child(mode)

	var middle: CenterContainer = CenterContainer.new()
	middle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(middle)
	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override(&"separation", 24)
	middle.add_child(row)
	var heroes: Array[Array] = party_looks()
	for book: int in range(1, BOOKS.size() + 1):
		var card: BookCard = BookCard.new(book, BOOKS[book - 1], heroes, is_available(book), best_score(book))
		card.pressed.connect(choose.bind(book))
		row.add_child(card)
		_cards.append(card)
	for i: int in _cards.size():
		var next: BookCard = _cards[(i + 1) % _cards.size()]
		var previous: BookCard = _cards[posmod(i - 1, _cards.size())]
		_cards[i].focus_neighbor_right = _cards[i].get_path_to(next)
		_cards[i].focus_neighbor_bottom = _cards[i].get_path_to(next)
		_cards[i].focus_neighbor_left = _cards[i].get_path_to(previous)
		_cards[i].focus_neighbor_top = _cards[i].get_path_to(previous)

	var prompts: UiPrompts = UiPrompts.new()
	prompts.add_hint(&"ui_accept", "UI_HINT_SELECT")
	prompts.add_hint(&"ui_cancel", "UI_HINT_BACK", _on_cancel)
	column.add_child(prompts)


func _screen_ready() -> void:
	Audio.play_music(Sfx.MUSIC_COOP_MENU if is_coop() else Sfx.MUSIC_MENU)
	GameInput.set_menu_clusters(is_coop())
	UiKit.focus_silently(_cards[clampi(Flow.play_book, 1, _cards.size()) - 1])


## True when the book select prepares a co-op run.
static func is_coop() -> bool:
	return Flow.play_mode == Defs.GameMode.COOP


## True when this build has a level of `book` to start (a co-op run without co-op files plays the solo ones).
static func is_available(book: int) -> bool:
	return Levels.first_level(book) != &""


## The best score of `book` in the mode being prepared, over both difficulties.
static func best_score(book: int) -> int:
	var mode: int = Defs.GameMode.COOP if is_coop() else Defs.GameMode.SINGLE
	var best: int = 0
	for difficulty: int in [Defs.Difficulty.BEGINNER, Defs.Difficulty.EXPERT]:
		best = maxi(best, Save.get_high_score_in(Save.space(mode, book, difficulty)))
	return best


## The looks of the heroes the pictures show: [colour, pattern] of P1 (Solo), of both joined players (Co-op).
static func party_looks() -> Array[Array]:
	var result: Array[Array] = []
	var count: int = maxi(Flow.party_size(), PartyTuning.COOP_PLAYERS) if is_coop() else 1
	for slot: int in count:
		result.append(HeroPalette.resolve(slot, Game.get_run(slot)) if is_coop()
				else [HeroPalette.IDENTITY_COLOUR, HeroPalette.IDENTITY_PATTERN])
	return result


## The book card of `book` (1 / 2), for tests.
func get_card(book: int) -> BookCard:
	return _cards[book - 1] if book >= 1 and book <= _cards.size() else null


## Choose `book`: on to Beginner / Expert. A book without levels in this build only answers with a sound.
func choose(book: int) -> void:
	if not is_accepting_input():
		return
	if not is_available(book):
		Audio.play_sfx(Sfx.MENU_BACK)
		return
	if begin_leave():
		Flow.choose_book(book)


func _on_cancel() -> void:
	if not is_accepting_input():
		return
	Audio.play_sfx(Sfx.MENU_BACK)
	if is_coop() and Flow.has_screen(Flow.SCREEN_JOIN):
		go_to(Flow.SCREEN_JOIN)
	elif begin_leave():
		Flow.goto_title()


func _on_tap() -> void:
	pass
