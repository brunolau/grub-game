class_name GameOverScreen
extends UiScreen
## Game over (GAMEPLAY.md 11.1 step 9): bouncing "GAME OVER" letters, the crying companion and three creatures
## circling him. Ends on the confirm button or after AUTO_LEAVE seconds and returns to the title (the next run
## starts fresh: Flow.start_new_game resets score, lives, letters and the feast kit).

const AUTO_LEAVE: float = 9.0
const LETTER_BOUNCE_PX: float = 14.0
const CIRCLE_RADIUS: Vector2 = Vector2(78.0, 26.0)
const CIRCLE_SPEED: float = 1.6

var _time: float = 0.0
var _letters: Array[Label] = []
var _letter_row: HBoxContainer = null
var _companion: UiActor = null
var _circlers: Array[UiActor] = []
var _ground: UiGround = null


func _build_screen() -> void:
	var dusk: UiBackdrop = UiBackdrop.new("cave", 8.0)
	dusk.modulate = Color(0.55, 0.5, 0.62)
	add_child(dusk)
	_ground = UiGround.new("cave/terrain_stone", 2)
	add_child(_ground)
	_companion = UiActor.new(&"companion", &"cry")
	_companion.z_index = 1
	add_child(_companion)
	for kind: StringName in [&"bat", &"bat", &"bat"]:
		var creature: UiActor = UiActor.new(kind, &"fly")
		add_child(creature)
		_circlers.append(creature)

	var column: VBoxContainer = VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override(&"separation", 6)
	safe.add_child(column)
	var top_space: Control = Control.new()
	top_space.custom_minimum_size = Vector2(0.0, 34.0)
	top_space.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(top_space)
	_letter_row = HBoxContainer.new()
	_letter_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_letter_row.add_theme_constant_override(&"separation", 0)
	_letter_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_letter_row)
	var words: String = tr("UI_GAME_OVER")
	for i: int in words.length():
		var letter: Label = UiKit.label(words[i], UiKit.Style.TITLE)
		letter.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		_letter_row.add_child(letter)
		_letters.append(letter)
	var score: Label = UiKit.label("%s %s" % [tr("UI_TALLY_SCORE"), UiKit.score_text(Game.score)], UiKit.Style.HUD,
			HORIZONTAL_ALIGNMENT_CENTER)
	score.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	column.add_child(score)
	if Game.score > 0 and Game.score >= Save.get_high_score():
		var record: Label = UiKit.label("UI_NEW_HIGH_SCORE", UiKit.Style.HUD, HORIZONTAL_ALIGNMENT_CENTER)
		record.add_theme_color_override(&"font_color", UiKit.COL_FOCUS)
		column.add_child(record)
	var spacer: Control = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(spacer)
	var prompts: UiPrompts = UiPrompts.new()
	prompts.alignment = BoxContainer.ALIGNMENT_END
	prompts.add_hint(&"ui_accept", "UI_HINT_CONTINUE", _on_accept)
	column.add_child(prompts)


func _screen_ready() -> void:
	Audio.play_jingle(Sfx.MUSIC_GAME_OVER, Sfx.MUSIC_GAME_OVER_LOOP)
	_place()


func _process(delta: float) -> void:
	_time += delta
	_place()
	if _time >= AUTO_LEAVE:
		leave()


func _on_accept() -> void:
	leave()


func _on_cancel() -> void:
	leave()


## Back to the title screen.
func leave() -> void:
	if begin_leave():
		Flow.goto_title()


func _place() -> void:
	# Letters drop in one after the other, then keep bouncing in a wave.
	for i: int in _letters.size():
		var local: float = _time - float(i) * 0.08
		var y: float = 0.0
		if local < 0.5:
			y = -200.0 * (1.0 - clampf(local / 0.5, 0.0, 1.0))
		else:
			y = -absf(sin((local - 0.5) * 3.2 + float(i) * 0.5)) * LETTER_BOUNCE_PX
		_letters[i].position.y = roundf(y)
	var floor_y: float = _ground.position.y + 10.0
	_companion.position = Vector2(roundf(size.x * 0.5), floor_y)
	var center: Vector2 = Vector2(size.x * 0.5, floor_y - 92.0)
	for i: int in _circlers.size():
		var angle: float = _time * CIRCLE_SPEED + TAU * float(i) / float(_circlers.size())
		var creature: UiActor = _circlers[i]
		creature.position = (center + Vector2(cos(angle) * CIRCLE_RADIUS.x, sin(angle) * CIRCLE_RADIUS.y)).round()
		creature.z_index = 2 if sin(angle) > 0.0 else 0
		creature.face(-1 if sin(angle) > 0.0 else 1)
