class_name ModeSelectScreen
extends UiScreen
## BEGINNER / EXPERT choice before a new run (GAMEPLAY.md 1.3, 11.1 step 5). Always starts at the first level.
##
## Left / Right (or Up / Down) move between the two cards, the confirm button or a tap starts the run with
## `Flow.start_new_game(difficulty)`; "back" returns to the title. The card of the mode played last is preselected.

const HERO_CELL: Vector2i = Vector2i(176, 112)
const PORTRAIT: Rect2 = Rect2(52.0, 30.0, 72.0, 68.0)   ## the hero inside his 176 x 112 cell

var _cards: Array[UiCard] = []


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
	column.add_child(UiKit.label("UI_MODE_HEADING", UiKit.Style.TITLE, HORIZONTAL_ALIGNMENT_CENTER))

	var middle: CenterContainer = CenterContainer.new()
	middle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(middle)
	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override(&"separation", 24)
	middle.add_child(row)
	_add_card(row, UiKit.TEX_HERO, "UI_MODE_BEGINNER", "UI_MODE_BEGINNER_INFO", Defs.Difficulty.BEGINNER)
	_add_card(row, "res://assets/sprites/player/hero_axe.png", "UI_MODE_EXPERT", "UI_MODE_EXPERT_INFO",
			Defs.Difficulty.EXPERT)
	_cards[0].focus_neighbor_right = _cards[0].get_path_to(_cards[1])
	_cards[1].focus_neighbor_left = _cards[1].get_path_to(_cards[0])
	_cards[0].focus_neighbor_bottom = _cards[0].get_path_to(_cards[1])
	_cards[1].focus_neighbor_top = _cards[1].get_path_to(_cards[0])
	_cards[0].focus_neighbor_top = _cards[0].get_path_to(_cards[1])
	_cards[1].focus_neighbor_bottom = _cards[1].get_path_to(_cards[0])

	var prompts: UiPrompts = UiPrompts.new()
	prompts.add_hint(&"ui_accept", "UI_HINT_SELECT")
	prompts.add_hint(&"ui_cancel", "UI_HINT_BACK", _on_cancel)
	column.add_child(prompts)


func _screen_ready() -> void:
	Audio.play_music(Sfx.MUSIC_MENU)
	var last: int = clampi(Settings.get_int("game/last_difficulty"), 0, _cards.size() - 1)
	UiKit.focus_silently(_cards[last])


func _on_cancel() -> void:
	if is_accepting_input():
		Audio.play_sfx(Sfx.MENU_BACK)
		go_to(Flow.SCREEN_TITLE)


func _on_tap() -> void:
	pass


## Start a new run in `difficulty` (Defs.Difficulty).
func choose(difficulty: int) -> void:
	if begin_leave():
		Flow.start_new_game(difficulty)


func _add_card(row: HBoxContainer, sheet: String, caption: String, info: String, difficulty: int) -> void:
	var portrait: AtlasTexture = UiKit.cell(sheet, HERO_CELL, 0)
	portrait.region = Rect2(portrait.region.position + PORTRAIT.position, PORTRAIT.size)
	var card: UiCard = UiCard.new(portrait, caption, info)
	card.pressed.connect(choose.bind(difficulty))
	row.add_child(card)
	_cards.append(card)
