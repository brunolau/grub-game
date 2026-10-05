class_name Hud
extends Control
## In-game HUD overlay (GAMEPLAY.md 2, ASSET_MANIFEST.md 12): lives and score top-left (with the time left under
## the score on levels that have a time limit), hearts (and the bone fraction) top-centre, the bonus word
## top-right, boss energy pips bottom-left while a boss fights, the level intro banner when a level starts and
## the hint panel of `zones/message` (Events.message_requested) under the HUD row; a hint asked for while the
## intro banner shows waits until the banner is gone.
##
## Owner: ui. Instantiated by Flow into the HUD CanvasLayer. It only reacts to `Game` and `Events` signals and
## never reaches into the level. Layout follows the mock-ups at 640 x 360 and stays anchored to the safe area on
## every other view size.

const HEART_SPACING: float = 34.0
const LETTER_SPACING: float = 40.0
## Vertical stagger of the five letters (the original's offsets, GAMEPLAY.md 2).
const LETTER_STAGGER: Array[int] = [4, 0, 6, 3, 1]
const PIP_SPACING: float = 18.0
const BONE_W: float = 9.0
const INTRO_SECONDS: float = 2.6
const INTRO_TOP: float = 64.0  ## the level banner sits under the HUD row, clear of the hero
const COL_LETTER_MISSING: Color = Color(0.38, 0.5, 0.62, 0.55)
## The time-limit counter turns red for the last seconds.
const TIME_WARN_SECONDS: int = 10
## Hint panel: top edge inside the safe area (the intro banner's row), widest text line, fade time, padding.
const HINT_TOP: float = INTRO_TOP - float(UiKit.MARGIN)
const HINT_MAX_TEXT_W: float = 420.0
const HINT_FADE_SECONDS: float = 0.18
const HINT_PAD_X: int = 12
const HINT_PAD_Y: int = 8
const HINT_ICON: int = 5  ## "!" of ui/icons.png
const HINT_ICON_GAP: int = 8
const COL_HINT_BACK: Color = Color(0.153, 0.125, 0.094, 0.9)
const COL_HINT_EDGE: Color = Color(1.0, 0.945, 0.812, 0.45)
## The HUD row (lives, score, hearts, letters) fades to this alpha while the hero is under it, so he stays visible
## where the view's top edge matters (the auto-scrolling shaft kills at that edge).
const ROW_UNDER_HERO_ALPHA: float = 0.3
const ROW_FADE_SECONDS: float = 0.15
## Height of the HUD row below the safe-area top (art px): the hero is "under it" when his head is above that line.
const ROW_HEIGHT: float = 48.0

## Hearts drawn (mirrors Game.hearts).
var shown_hearts: int = 0
## Bone fraction drawn (mirrors Game.bones).
var shown_bones: int = 0
## Letter mask drawn.
var shown_letters: int = 0
## Boss pips: filled / maximum; maximum 0 = no boss bar.
var boss_pips: int = 0
var boss_max_pips: int = 0
## Seconds shown by the time-limit counter; -1 = the level has no limit (the counter is hidden).
var shown_time: int = -1

var _safe: MarginContainer = null
var _lives_label: Label = null
var _score_label: Label = null
var _time_label: Label = null
var _hearts: Array[TextureRect] = []
var _bones: Control = null
var _letters: Array[TextureRect] = []
var _boss_bar: Control = null
var _intro: Control = null
var _blink_left: float = 0.0
var _heart_full: AtlasTexture = null
var _heart_empty: AtlasTexture = null
var _pip_full: AtlasTexture = null
var _pip_empty: AtlasTexture = null
## Hints asked for through Events.message_requested, oldest first (sources and their texts, parallel).
var _hint_sources: Array[Node] = []
var _hint_texts: PackedStringArray = PackedStringArray()
var _hint_holder: CenterContainer = null
var _hint_label: Label = null
var _hint_shown_text: String = ""
## The top-row elements that fade while the hero is under them, and their current alpha.
var _row_nodes: Array[CanvasItem] = []
var row_alpha: float = 1.0
var _row_area: Control = null


func _init() -> void:
	UiKit.ensure_locale()
	theme = UiKit.theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_heart_full = UiKit.cell("res://assets/ui/hud_heart.png", Vector2i(32, 32), 0)
	_heart_empty = UiKit.cell("res://assets/ui/hud_heart.png", Vector2i(32, 32), 1)
	_pip_full = UiKit.cell("res://assets/ui/hud_boss_pip.png", Vector2i(16, 16), 0)
	_pip_empty = UiKit.cell("res://assets/ui/hud_boss_pip.png", Vector2i(16, 16), 1)


func _ready() -> void:
	add_to_group(Defs.GROUP_HUD)
	_safe = MarginContainer.new()
	_safe.set_anchors_preset(Control.PRESET_FULL_RECT)
	_safe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_safe)
	var area: Control = Control.new()
	area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_safe.add_child(area)
	_row_area = area
	_build_left(area)
	_build_hearts(area)
	_build_letters(area)
	for child: Node in area.get_children():
		_row_nodes.append(child as CanvasItem)
	_build_boss_bar(area)
	_build_hint(area)
	_apply_margins()
	get_viewport().size_changed.connect(_apply_margins)
	Game.score_changed.connect(_on_score_changed)
	Game.lives_changed.connect(_on_lives_changed)
	Game.extra_life_awarded.connect(_on_extra_life)
	Game.energy_changed.connect(_on_energy_changed)
	Game.letters_changed.connect(_on_letters_changed)
	Game.letters_completed.connect(_on_letters_completed)
	Game.run_started.connect(_on_run_started)
	Events.boss_started.connect(_on_boss_started)
	Events.boss_energy_changed.connect(_on_boss_energy_changed)
	Events.boss_defeated.connect(_on_boss_defeated)
	Events.level_respawned.connect(_on_level_respawned)
	Events.time_left_changed.connect(_on_time_left_changed)
	Events.message_requested.connect(_on_message_requested)
	refresh()
	# The level armed its time limit before this overlay existed: show the current value.
	_on_time_left_changed(Game.level.get_time_left_seconds() if Game.level != null else -1)
	if Flow.current_screen == Flow.SCREEN_LEVEL and Game.level_id != &"":
		show_intro(Game.level_id)


func _process(delta: float) -> void:
	_fade_hint(delta)
	_fade_row(delta)
	if _blink_left <= 0.0:
		return
	_blink_left -= delta
	var lit: bool = int(_blink_left * 8.0) % 2 == 0
	for letter: TextureRect in _letters:
		letter.modulate = Color.WHITE if lit else COL_LETTER_MISSING
	if _blink_left <= 0.0:
		_show_letters(Game.letters)


## Fade the top row while the hero's head is under it (see ROW_UNDER_HERO_ALPHA).
func _fade_row(delta: float) -> void:
	var level: LevelBase = Game.level
	var under: bool = false
	if level != null and level.player != null and level.player.is_inside_tree() and not level.player.dead:
		var feet: Vector2 = level.player.get_global_transform_with_canvas().origin
		under = is_under_row(feet.y - float(level.player.box_h * Tuning.ART_SCALE))
	row_alpha = move_toward(row_alpha, ROW_UNDER_HERO_ALPHA if under else 1.0, delta / ROW_FADE_SECONDS)
	for node: CanvasItem in _row_nodes:
		node.modulate.a = row_alpha


## True when a screen y (viewport px) lies within the HUD row.
func is_under_row(screen_y: float) -> bool:
	var top: float = _row_area.get_global_rect().position.y if _row_area != null else 0.0
	return screen_y < top + ROW_HEIGHT


## Show everything as it is in `Game` now.
func refresh() -> void:
	_on_score_changed(Game.score)
	_on_lives_changed(Game.lives)
	_set_energy(Game.hearts, Game.bones, false)
	_show_letters(Game.letters)
	_set_boss(0, 0)


## Text of the score counter.
func get_score_text() -> String:
	return _score_label.text


## Text of the lives counter.
func get_lives_text() -> String:
	return _lives_label.text


## True while the boss energy bar is shown.
func is_boss_bar_visible() -> bool:
	return _boss_bar.visible


## True while the time-limit counter is shown.
func is_time_visible() -> bool:
	return _time_label.visible


## Text of the time-limit counter.
func get_time_text() -> String:
	return _time_label.text


## Translated text of the level hint that is asked for now ("" = none).
func get_hint_text() -> String:
	var index: int = _current_hint()
	return tr(_hint_texts[index]) if index >= 0 else ""


## True while the hint panel is on screen (also while it fades in or out).
func is_hint_visible() -> bool:
	return _hint_holder.visible


## The text the hint panel shows (it keeps the last hint while fading out).
func get_hint_shown_text() -> String:
	return _hint_shown_text


## The level banner: "WORLD 1 - STAGE 2" and the level name, sliding in and out (the level intro).
func show_intro(level_id: StringName) -> void:
	if _intro != null:
		_intro.queue_free()
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 0)
	var number: String = UiKit.level_number(level_id)
	if number != "":
		var where: Label = UiKit.label(tr("UI_HUD_STAGE").format({"number": number}), UiKit.Style.HUD,
				HORIZONTAL_ALIGNMENT_CENTER)
		where.add_theme_color_override(&"font_color", UiKit.COL_CREAM)
		where.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		column.add_child(where)
	var title: Label = UiKit.label(UiKit.level_name(level_id), UiKit.Style.HUD, HORIZONTAL_ALIGNMENT_CENTER)
	title.add_theme_color_override(&"font_color", UiKit.COL_FOCUS)
	title.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	column.add_child(title)
	var banner: PanelContainer = PanelContainer.new()
	banner.add_theme_stylebox_override(&"panel", UiKit.plate(UiKit.COL_SHADE, 8))
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.add_child(column)
	var holder: VBoxContainer = VBoxContainer.new()
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gap: Control = Control.new()
	gap.custom_minimum_size = Vector2(0.0, INTRO_TOP)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(gap)
	var middle: CenterContainer = CenterContainer.new()
	middle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	middle.add_child(banner)
	holder.add_child(middle)
	add_child(holder)
	_intro = holder
	holder.modulate.a = 0.0
	var tween: Tween = holder.create_tween()
	tween.tween_property(holder, "modulate:a", 1.0, 0.25)
	tween.tween_interval(INTRO_SECONDS)
	tween.tween_property(holder, "modulate:a", 0.0, 0.4)
	tween.tween_callback(holder.queue_free)


func _build_left(area: Control) -> void:
	var icon: TextureRect = UiKit.picture(UiKit.tex("res://assets/ui/hud_lives_icon.png"))
	icon.position = Vector2.ZERO
	area.add_child(icon)
	_lives_label = UiKit.label("", UiKit.Style.HUD)
	_lives_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_lives_label.position = Vector2(50.0, 8.0)
	area.add_child(_lives_label)
	_score_label = UiKit.label("", UiKit.Style.HUD)
	_score_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_score_label.position = Vector2(104.0, 8.0)
	area.add_child(_score_label)
	_time_label = UiKit.label("", UiKit.Style.HUD)
	_time_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_time_label.position = Vector2(104.0, 30.0)
	_time_label.visible = false
	area.add_child(_time_label)


func _build_hearts(area: Control) -> void:
	var row: Control = Control.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_anchors_preset(Control.PRESET_CENTER_TOP)
	row.offset_left = -HEART_SPACING * 1.5
	row.offset_right = HEART_SPACING * 1.5
	area.add_child(row)
	for i: int in Tuning.ENERGY_START:
		var heart: TextureRect = UiKit.picture(_heart_full)
		heart.position = Vector2(float(i) * HEART_SPACING, 2.0)
		heart.pivot_offset = Vector2(16.0, 16.0)
		row.add_child(heart)
		_hearts.append(heart)
	_bones = Control.new()
	_bones.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bones_width: float = BONE_W * float(Tuning.BONES_PER_HEART - 2) + 6.0
	_bones.position = Vector2(roundf(HEART_SPACING * 1.5 - bones_width * 0.5), 37.0)
	_bones.draw.connect(_draw_bones)
	row.add_child(_bones)


func _build_letters(area: Control) -> void:
	var letter_box: Control = Control.new()
	letter_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	letter_box.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	letter_box.offset_left = -LETTER_SPACING * float(Tuning.LETTER_COUNT)
	letter_box.offset_right = 0.0
	area.add_child(letter_box)
	for i: int in Tuning.LETTER_COUNT:
		var letter: TextureRect = UiKit.picture(UiKit.cell(UiKit.TEX_LETTERS, Vector2i(40, 40), i))
		letter.position = Vector2(float(i) * LETTER_SPACING, float(LETTER_STAGGER[i % LETTER_STAGGER.size()] - 2))
		letter.pivot_offset = Vector2(20.0, 20.0)
		letter_box.add_child(letter)
		_letters.append(letter)


func _build_boss_bar(area: Control) -> void:
	_boss_bar = Control.new()
	_boss_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_bar.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_boss_bar.offset_top = -16.0
	_boss_bar.offset_bottom = 0.0
	_boss_bar.offset_right = PIP_SPACING * float(Tuning.BOSS_BAR_MAX_PIPS)
	_boss_bar.draw.connect(_draw_boss_bar)
	area.add_child(_boss_bar)


## The hint panel: "!" icon and the hint in the HUD face on an almost opaque ink plate with a thin cream edge,
## centred under the HUD row. Hidden until a zone asks for a hint.
func _build_hint(area: Control) -> void:
	_hint_holder = CenterContainer.new()
	_hint_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint_holder.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_hint_holder.offset_top = HINT_TOP
	_hint_holder.offset_bottom = HINT_TOP
	_hint_holder.visible = false
	_hint_holder.modulate.a = 0.0
	var plate: StyleBoxFlat = UiKit.plate(COL_HINT_BACK, HINT_PAD_Y)
	plate.content_margin_left = float(HINT_PAD_X)
	plate.content_margin_right = float(HINT_PAD_X)
	plate.set_border_width_all(2)
	plate.border_color = COL_HINT_EDGE
	var panel: PanelContainer = PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override(&"panel", plate)
	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override(&"separation", HINT_ICON_GAP)
	var icon: TextureRect = UiKit.picture(UiKit.icon(HINT_ICON))
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)
	_hint_label = UiKit.label("", UiKit.Style.HUD, HORIZONTAL_ALIGNMENT_CENTER)
	_hint_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_hint_label.add_theme_color_override(&"font_color", UiKit.COL_CREAM)
	_hint_label.add_theme_constant_override(&"line_spacing", 4)
	_hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hint_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_hint_label)
	panel.add_child(row)
	_hint_holder.add_child(panel)
	area.add_child(_hint_holder)


func _on_message_requested(source: Node, text: String) -> void:
	var index: int = _hint_sources.find(source)
	if index >= 0:
		_hint_sources.remove_at(index)
		_hint_texts.remove_at(index)
	if text.is_empty() or source == null:
		return
	_hint_sources.append(source)
	_hint_texts.append(text)


## Index of the newest hint whose source still exists (-1 = none). Forgets the hints of freed sources.
func _current_hint() -> int:
	for i: int in range(_hint_sources.size() - 1, -1, -1):
		if is_instance_valid(_hint_sources[i]):
			return i
		_hint_sources.remove_at(i)
		_hint_texts.remove_at(i)
	return -1


func _fade_hint(delta: float) -> void:
	var text: String = get_hint_text()
	var intro_showing: bool = _intro != null and is_instance_valid(_intro)
	var wanted: bool = not text.is_empty() and not intro_showing
	if wanted and text != _hint_shown_text:
		_hint_shown_text = text
		_layout_hint()
	var alpha: float = move_toward(_hint_holder.modulate.a, 1.0 if wanted else 0.0, delta / HINT_FADE_SECONDS)
	_hint_holder.modulate.a = alpha
	_hint_holder.visible = alpha > 0.0


## Width of the hint text: one line when it fits, else wrapped into as few lines as the view allows, with the
## lines balanced (two half-long lines read better than a full line and a single word).
func _layout_hint() -> void:
	if _hint_label == null:
		return
	_hint_label.text = _hint_shown_text
	var font: Font = UiKit.font(UiKit.Style.HUD)
	var font_size: int = UiKit.SIZE_HUD
	var natural: float = ceilf(font.get_string_size(_hint_shown_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x)
	var margins: Vector4i = UiKit.safe_margins(get_viewport())
	var view_w: float = get_viewport_rect().size.x - float(margins.x + margins.z)
	var room: float = view_w - float(2 * HINT_PAD_X + UiKit.ICON_CELL + HINT_ICON_GAP) - 8.0
	var limit: float = maxf(minf(HINT_MAX_TEXT_W, room), 64.0)
	var width: float = natural
	if natural > limit:
		var lines: int = ceili(natural / limit)
		var line_h: float = font.get_height(font_size)
		width = ceilf(natural / float(lines))
		while width < limit:
			var block: Vector2 = font.get_multiline_string_size(_hint_shown_text, HORIZONTAL_ALIGNMENT_LEFT, width,
					font_size)
			if block.y <= line_h * float(lines) + 0.5:
				break
			width += 8.0
		width = minf(width, limit)
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if natural > width else TextServer.AUTOWRAP_OFF
	_hint_label.custom_minimum_size = Vector2(width, 0.0)
	_hint_label.reset_size()


func _apply_margins() -> void:
	var margins: Vector4i = UiKit.safe_margins(get_viewport())
	_safe.add_theme_constant_override(&"margin_left", margins.x)
	_safe.add_theme_constant_override(&"margin_top", maxi(0, margins.y - 2))
	_safe.add_theme_constant_override(&"margin_right", margins.z)
	_safe.add_theme_constant_override(&"margin_bottom", margins.w)
	if not _hint_shown_text.is_empty():
		_layout_hint()


func _on_score_changed(score: int) -> void:
	_score_label.text = UiKit.score_text(score)


func _on_lives_changed(lives: int) -> void:
	_lives_label.text = "x%d" % clampi(lives, 0, Tuning.LIVES_MAX)


func _on_time_left_changed(seconds: int) -> void:
	shown_time = seconds
	_time_label.visible = seconds >= 0
	if seconds < 0:
		return
	_time_label.text = tr("UI_HUD_TIME").format({"seconds": seconds})
	var warn: bool = seconds <= TIME_WARN_SECONDS
	_time_label.add_theme_color_override(&"font_color", UiKit.COL_BAD if warn else UiKit.COL_TEXT)
	if warn and seconds > 0:
		_pop(_time_label, 1.2)


func _on_extra_life(_lives: int) -> void:
	_pop(_lives_label, 1.4)


func _on_energy_changed(hearts: int, bones: int) -> void:
	_set_energy(hearts, bones, true)


func _set_energy(hearts: int, bones: int, animate: bool) -> void:
	var before: int = shown_hearts
	shown_hearts = clampi(hearts, 0, _hearts.size())
	shown_bones = clampi(bones, 0, Tuning.BONES_PER_HEART - 1)
	for i: int in _hearts.size():
		_hearts[i].texture = _heart_full if i < shown_hearts else _heart_empty
	if animate and shown_hearts < before:
		_shake(shown_hearts)
	elif animate and shown_hearts > before:
		_pop(_hearts[shown_hearts - 1], 1.3)
	_bones.queue_redraw()


func _on_letters_changed(mask: int) -> void:
	if _blink_left > 0.0:
		return
	var gained: int = mask & ~shown_letters
	_show_letters(mask)
	for i: int in _letters.size():
		if gained & (1 << i):
			_pop(_letters[i], 1.4)


func _on_letters_completed() -> void:
	_blink_left = Tuning.ticks_to_seconds(Tuning.LETTERS_BLINK_TICKS)


func _show_letters(mask: int) -> void:
	shown_letters = mask
	for i: int in _letters.size():
		_letters[i].modulate = Color.WHITE if mask & (1 << i) else COL_LETTER_MISSING


func _on_run_started(_difficulty: int) -> void:
	refresh()


func _on_boss_started(_boss: BossBase) -> void:
	_set_boss(Tuning.BOSS_BAR_MAX_PIPS, Tuning.BOSS_BAR_MAX_PIPS)


func _on_boss_energy_changed(_boss: BossBase, pips: int, max_pips: int) -> void:
	_set_boss(pips, max_pips)


func _on_boss_defeated(_boss: BossBase) -> void:
	_set_boss(0, 0)


func _on_level_respawned() -> void:
	_set_boss(0, 0)


func _set_boss(pips: int, max_pips: int) -> void:
	boss_max_pips = clampi(max_pips, 0, Tuning.BOSS_BAR_MAX_PIPS)
	boss_pips = clampi(pips, 0, boss_max_pips)
	_boss_bar.visible = boss_max_pips > 0
	_boss_bar.queue_redraw()


func _draw_boss_bar() -> void:
	for i: int in boss_max_pips:
		_boss_bar.draw_texture(_pip_full if i < boss_pips else _pip_empty, Vector2(float(i) * PIP_SPACING, 0.0))


func _draw_bones() -> void:
	if shown_bones <= 0:
		return
	for i: int in Tuning.BONES_PER_HEART - 1:
		var x: float = float(i) * BONE_W
		var color: Color = UiKit.COL_CREAM if i < shown_bones else Color(UiKit.COL_INK, 0.6)
		_bones.draw_rect(Rect2(x - 1.0, -1.0, 8.0, 6.0), UiKit.COL_INK)
		_bones.draw_rect(Rect2(x, 0.0, 6.0, 4.0), color)


func _pop(target: Control, amount: float) -> void:
	target.pivot_offset = target.size * 0.5
	var tween: Tween = target.create_tween()
	tween.tween_property(target, "scale", Vector2(amount, amount), 0.08)
	tween.tween_property(target, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _shake(heart: int) -> void:
	var target: Control = _hearts[heart]
	var origin: float = float(heart) * HEART_SPACING
	var tween: Tween = target.create_tween()
	for offset: float in [-4.0, 4.0, -3.0, 2.0, 0.0]:
		tween.tween_property(target, "position:x", origin + offset, 0.04)
