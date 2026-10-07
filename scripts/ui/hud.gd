class_name Hud
extends Control
## In-game HUD overlay (GAMEPLAY.md 2, ASSET_MANIFEST.md 12): lives and score top-left (with the time left under
## the score on levels that have a time limit), hearts (and the bone fraction) top-centre, the bonus word
## top-right, the boss energy bar under the hearts while a boss fights ([HudBossBar]: it spans the boss's own hit
## points, so every hit shows), the level intro banner when a level starts and the hint panel of `zones/message`
## (Events.message_requested) under the HUD row (below the boss bar during a fight); a hint asked for while the
## intro banner shows waits until the banner is gone. The banner gives way early to a sign board the hero reads and
## to a boss that wakes up (dismiss_intro()).
##
## 2.0 (DESIGN.md C.1 / D.11 / E.9, GAMEPLAY.md 13.9.9): the belt icon right of P1's hearts shows what a Swap brings
## while he owns a special (never in Book I solo, whose belt stays empty, so the 1.0 HUD is unchanged there). In
## co-op P1's hearts get a "P1" tag and P2's panel ([HudPlayerPanel]: tag, hearts, bone fraction, belt icon) sits
## mirrored top-right under the letters; tribe lives, score and letters stay where they are. With the "Rival score"
## option (DESIGN.md D.11, Options > Co-op) the score counter shows P1's own score in his colour and P2's panel shows
## his under his hearts (PlayerRun.score: the share each hero earned). In a party a hero off the view gets an edge
## arrow with the stone countdown of the leash ([HudEdgeArrows]). In versus the campaign rows give way to the corner
## panels, the sundial and the round banners of [HudVersus]. World text that must not sit under a party panel (sign
## boards) asks [method clear_of_panels]. A Cave Painting that opens a reward (Save.reward_unlocked) shows a notice
## under the HUD row for a few seconds ("Unlocked: Mesa Rodeo arena"), below the hint panel while one shows.
##
## Owner: ui-B. Instantiated by Flow into the HUD CanvasLayer. It reacts to `Game` and `Events` signals; of the level it
## reads only the heroes' documented HUD fields (position, leash; ARCHITECTURE.md 3.12) and the versus numbers the
## referee offers ([HudVersus]). Layout follows the mock-ups at 640 x 360 and stays anchored to the safe area on every
## other view size.

const HEART_SPACING: float = 34.0
const LETTER_SPACING: float = 40.0
## Vertical stagger of the five letters (the original's offsets, GAMEPLAY.md 2).
const LETTER_STAGGER: Array[int] = [4, 0, 6, 3, 1]
const BONE_W: float = 9.0
const INTRO_SECONDS: float = 2.6
const INTRO_TOP: float = 64.0  ## the level banner sits under the HUD row, clear of the hero
## The banner gives way this fast to a sign board the hero reads or to a boss that wakes up (dismiss_intro()).
const INTRO_DISMISS_SECONDS: float = 0.2
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
## Boss bar: top edge below the safe-area top (under the hearts and the bone fraction), the gap kept to the intro
## banner and the hint panel that move below it during a fight, and its alpha while the hero is behind it. It sits
## top-centre on every device: the touch buttons fill both bottom corners.
const BOSS_TOP: float = 44.0
const BOSS_GAP: float = 6.0
const BOSS_UNDER_HERO_ALPHA: float = 0.35
## Belt icon (ui/hud_belt.png, 16 logical px): gap right of P1's third heart (art px).
const BELT_GAP: float = 6.0
## Co-op: top of P2's panel below the safe-area top (under the bonus letters), the room P1's "P1" tag takes left of
## his hearts, and how far the level banner and the hint panel move down so that they clear P2's panel.
const P2_TOP: float = 46.0
const P1_TAG_W: float = 32.0
const PARTY_GAP: float = 6.0
## Least gap (art px) that [method clear_of_panels] keeps between a party panel and world text.
const PANEL_CLEAR_GAP: float = 4.0
## The reward notice: how long it stays (seconds, fades included) and its icon (ui/icons.png: the fruit).
const REWARD_SECONDS: float = 3.5
const REWARD_ICON: int = UiKit.ICON_FRUIT

## Hearts drawn (mirrors Game.hearts).
var shown_hearts: int = 0
## Bone fraction drawn (mirrors Game.bones).
var shown_bones: int = 0
## Letter mask drawn.
var shown_letters: int = 0
## Boss energy as the last Events.boss_energy_changed told it: pips filled / maximum (maximum 0 = no boss bar).
var boss_pips: int = 0
var boss_max_pips: int = 0
## Boss hit points shown by the bar: current / maximum (the boss's own; maximum 0 = no boss bar).
var boss_hp: int = 0
var boss_max_hp: int = 0
## Seconds shown by the time-limit counter; -1 = the level has no limit (the counter is hidden).
var shown_time: int = -1

var _safe: MarginContainer = null
var _lives_label: Label = null
var _score_label: Label = null
var _time_label: Label = null
var _hearts: Array[TextureRect] = []
var _bones: Control = null
var _letters: Array[TextureRect] = []
var _boss_bar: HudBossBar = null
var _intro: Control = null
var _intro_gap: Control = null
var _intro_tween: Tween = null
var _boss_bar_was_visible: bool = false
var _blink_left: float = 0.0
var _heart_full: AtlasTexture = null
var _heart_empty: AtlasTexture = null
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
## 2.0: the layout in use (Defs.GameMode of the run; co-op only with a party of two or more).
var hud_layout: int = Defs.GameMode.SINGLE
## Belt icon drawn right of P1's hearts: a Defs.Weapon, or PlayerRun.BELT_EMPTY (hidden).
var shown_belt: int = PlayerRun.BELT_EMPTY
## Alpha of P2's co-op panel (it fades like the row while a hero is behind it).
var p2_alpha: float = 1.0
## True while the score counter and P2's panel show the two players' own scores (co-op with the Rival score option).
var rival_score: bool = false
## Text of the reward notice on screen ("" = none).
var reward_text: String = ""
var _reward_holder: CenterContainer = null
var _reward_label: Label = null
var _reward_left: float = 0.0
var _hearts_row: Control = null
var _p1_belt: TextureRect = null
var _p1_tag: Label = null
var _p2_panel: HudPlayerPanel = null
var _edge_arrows: HudEdgeArrows = null
var _versus: HudVersus = null
var _campaign_nodes: Array[CanvasItem] = []


func _init() -> void:
	UiKit.ensure_locale()
	theme = UiKit.theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_heart_full = UiKit.cell("res://assets/ui/hud_heart.png", Vector2i(32, 32), 0)
	_heart_empty = UiKit.cell("res://assets/ui/hud_heart.png", Vector2i(32, 32), 1)


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
		_campaign_nodes.append(child as CanvasItem)
	_build_boss_bar(area)
	_build_hint(area)
	_build_reward(area)
	_build_party(area)
	_apply_margins()
	get_viewport().size_changed.connect(_apply_margins)
	Game.score_changed.connect(_on_score_changed)
	Game.lives_changed.connect(_on_lives_changed)
	Game.extra_life_awarded.connect(_on_extra_life)
	Game.energy_changed.connect(_on_energy_changed)
	Game.letters_changed.connect(_on_letters_changed)
	Game.letters_completed.connect(_on_letters_completed)
	Game.run_started.connect(_on_run_started)
	Game.run_belt_changed.connect(_on_run_belt_changed)
	Events.boss_started.connect(_on_boss_started)
	Events.boss_energy_changed.connect(_on_boss_energy_changed)
	Events.boss_defeated.connect(_on_boss_defeated)
	Events.level_respawned.connect(_on_level_respawned)
	Events.time_left_changed.connect(_on_time_left_changed)
	Events.message_requested.connect(_on_message_requested)
	Settings.changed.connect(_on_setting_changed)
	Save.reward_unlocked.connect(show_reward)
	refresh()
	# The level armed its time limit before this overlay existed: show the current value.
	_on_time_left_changed(Game.level.get_time_left_seconds() if Game.level != null else -1)
	if Flow.current_screen == Flow.SCREEN_LEVEL and Game.level_id != &"" and hud_layout != Defs.GameMode.VERSUS:
		show_intro(Game.level_id)


func _process(delta: float) -> void:
	_fade_hint(delta)
	_fade_reward(delta)
	_fade_row(delta)
	_fade_boss_bar(delta)
	if _blink_left <= 0.0:
		return
	_blink_left -= delta
	var lit: bool = int(_blink_left * 8.0) % 2 == 0
	for letter: TextureRect in _letters:
		letter.modulate = Color.WHITE if lit else COL_LETTER_MISSING
	if _blink_left <= 0.0:
		_show_letters(Game.letters)


## Fade the top row while the hero's head is under it (see ROW_UNDER_HERO_ALPHA; 2.0: any living hero's head).
func _fade_row(delta: float) -> void:
	var level: LevelBase = Game.level
	var under: bool = false
	if level != null:
		for hero: PlayerBase in level.contact_order():
			if hero.is_inside_tree() and not hero.dead:
				var feet: Vector2 = hero.get_global_transform_with_canvas().origin
				if is_under_row(feet.y - float(hero.box_h * Tuning.ART_SCALE)):
					under = true
					break
	row_alpha = move_toward(row_alpha, ROW_UNDER_HERO_ALPHA if under else 1.0, delta / ROW_FADE_SECONDS)
	for node: CanvasItem in _row_nodes:
		node.modulate.a = row_alpha
	if _p2_panel != null and _p2_panel.visible:
		var behind: bool = level != null and _any_hero_behind(level, _p2_panel.get_global_rect())
		p2_alpha = move_toward(p2_alpha, ROW_UNDER_HERO_ALPHA if behind else 1.0, delta / ROW_FADE_SECONDS)
		_p2_panel.modulate.a = p2_alpha


## True when the body of a living hero of `level` overlaps `rect` (viewport px, grown by 4).
func _any_hero_behind(level: LevelBase, rect: Rect2) -> bool:
	for hero: PlayerBase in level.contact_order():
		if not hero.is_inside_tree() or hero.dead:
			continue
		var feet: Vector2 = hero.get_global_transform_with_canvas().origin
		var box: Vector2 = Vector2(float(hero.box_w), float(hero.box_h)) * float(Tuning.ART_SCALE)
		if Rect2(feet.x - box.x * 0.5, feet.y - box.y, box.x, box.y).intersects(rect.grow(4.0)):
			return true
	return false


## Fade the boss bar while the hero overlaps it (2.0: any living hero).
func _fade_boss_bar(delta: float) -> void:
	if _boss_bar.visible != _boss_bar_was_visible:
		# The bar appeared or finished fading out: move the banner and the hint panel.
		_boss_bar_was_visible = _boss_bar.visible
		_place_below_boss_bar()
	if not _boss_bar.visible:
		_boss_bar.self_modulate.a = 1.0
		return
	var behind: bool = false
	var level: LevelBase = Game.level
	if level != null:
		for hero: PlayerBase in level.contact_order():
			if not hero.is_inside_tree() or hero.dead:
				continue
			var feet: Vector2 = hero.get_global_transform_with_canvas().origin
			var box: Vector2 = Vector2(float(hero.box_w), float(hero.box_h)) * float(Tuning.ART_SCALE)
			var body: Rect2 = Rect2(feet.x - box.x * 0.5, feet.y - box.y, box.x, box.y)
			if body.intersects(get_boss_bar_rect().grow(4.0)):
				behind = true
				break
	var target: float = BOSS_UNDER_HERO_ALPHA if behind else 1.0
	_boss_bar.self_modulate.a = move_toward(_boss_bar.self_modulate.a, target, delta / ROW_FADE_SECONDS)


## Screen rectangle of the boss bar with its skull (viewport px).
func get_boss_bar_rect() -> Rect2:
	var rect: Rect2 = _boss_bar.get_global_rect()
	return Rect2(rect.position + Vector2(HudBossBar.SKULL_POS.x, 0.0),
			rect.size - Vector2(HudBossBar.SKULL_POS.x, 0.0))


## The boss bar (tests, previews).
func get_boss_bar() -> HudBossBar:
	return _boss_bar


## True when a screen y (viewport px) lies within the HUD row.
func is_under_row(screen_y: float) -> bool:
	return screen_y < get_row_bottom()


## Viewport y of the HUD row's bottom edge (the safe area included): world text that must not sit under the row of
## lives, hearts and letters (a sign board) keeps below it. In versus the row of corner panels and the sundial.
func get_row_bottom() -> float:
	if _versus != null and is_instance_valid(_versus):
		return _versus.get_sundial().rect.end.y
	var top: float = _row_area.get_global_rect().position.y if _row_area != null else 0.0
	return top + ROW_HEIGHT


## Show everything as it is in `Game` now.
func refresh() -> void:
	_on_score_changed(Game.score)
	_on_lives_changed(Game.lives)
	_set_energy(Game.hearts, Game.bones, false)
	_show_letters(Game.letters)
	_set_boss(0, 0)
	_set_belt(Game.runs[0].belt)
	_apply_layout_mode()


## Text of the score counter.
func get_score_text() -> String:
	return _score_label.text


## Text of the lives counter.
func get_lives_text() -> String:
	return _lives_label.text


## True while the boss energy bar shows a fight (it fades out after a defeat).
func is_boss_bar_visible() -> bool:
	return _boss_bar.active and _boss_bar.visible


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
	banner.add_theme_stylebox_override(&"panel", _text_plate(UiKit.COL_SHADE))
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.add_child(column)
	var holder: VBoxContainer = VBoxContainer.new()
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gap: Control = Control.new()
	gap.custom_minimum_size = Vector2(0.0, INTRO_TOP + _boss_drop())
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(gap)
	_intro_gap = gap
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
	_intro_tween = tween


## True while the level intro banner is on screen (also while it fades in or out).
func is_intro_visible() -> bool:
	return _intro != null and is_instance_valid(_intro) and not _intro.is_queued_for_deletion()


## Fade the level intro banner out now: something else needs the top of the view (a sign board the hero reads, a
## boss waking up). Nothing happens when no banner shows.
func dismiss_intro() -> void:
	if not is_intro_visible() or _intro.has_meta(&"dismissed"):
		return
	_intro.set_meta(&"dismissed", true)
	if _intro_tween != null and _intro_tween.is_valid():
		_intro_tween.kill()
	var holder: Control = _intro
	var tween: Tween = holder.create_tween()
	tween.tween_property(holder, "modulate:a", 0.0, INTRO_DISMISS_SECONDS)
	tween.tween_callback(holder.queue_free)
	_intro_tween = tween


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
	_hearts_row = row
	# 2.0: the belt icon right of the hearts (hidden while no special is owned); in co-op the "P1" tag left of them.
	_p1_belt = UiKit.picture(null)
	_p1_belt.position = Vector2(HEART_SPACING * float(Tuning.ENERGY_START - 1) + 32.0 + BELT_GAP, 2.0)
	_p1_belt.visible = false
	row.add_child(_p1_belt)
	_p1_tag = UiPlayers.tag_label(0)
	_p1_tag.position = Vector2(-P1_TAG_W, 7.0)
	_p1_tag.visible = false
	row.add_child(_p1_tag)


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


## The boss bar, centred under the hearts (the frame is centred; the skull hangs off its left end).
func _build_boss_bar(area: Control) -> void:
	_boss_bar = HudBossBar.new()
	_boss_bar.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_boss_bar.offset_left = -HudBossBar.FRAME_SIZE.x * 0.5
	_boss_bar.offset_right = HudBossBar.FRAME_SIZE.x * 0.5
	_boss_bar.offset_top = BOSS_TOP
	_boss_bar.offset_bottom = BOSS_TOP + HudBossBar.FRAME_SIZE.y
	area.add_child(_boss_bar)


## How far the intro banner and the hint panel move down while the boss bar is shown, or in co-op to clear P2's
## panel (art px).
func _boss_drop() -> float:
	var drop: float = 0.0
	if _p2_panel != null and _p2_panel.visible:
		drop = maxf(0.0, P2_TOP + _p2_panel.panel_height() + PARTY_GAP - HINT_TOP)
	if _boss_bar == null or not _boss_bar.visible:
		return drop
	return maxf(drop, BOSS_TOP + HudBossBar.FRAME_SIZE.y + BOSS_GAP - HINT_TOP)


## 2.0: P2's co-op panel (top-right under the letters), the edge arrows of a party and the versus HUD; which of them
## show is decided by [method _apply_layout_mode].
func _build_party(area: Control) -> void:
	_p2_panel = HudPlayerPanel.new(1, true)
	_p2_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_p2_panel.offset_left = -HudPlayerPanel.PANEL_W
	_p2_panel.offset_right = 0.0
	_p2_panel.offset_top = P2_TOP
	_p2_panel.offset_bottom = P2_TOP + HudPlayerPanel.PANEL_H
	_p2_panel.visible = false
	area.add_child(_p2_panel)
	_edge_arrows = HudEdgeArrows.new()
	_edge_arrows.visible = false
	add_child(_edge_arrows)


## Show the parts of the layout of the current run: single-player (the 1.0 HUD), co-op (P1 tag, P2's panel, edge
## arrows) or versus (the campaign rows hide; corner panels, sundial and banners).
func _apply_layout_mode() -> void:
	var wanted: int = Defs.GameMode.SINGLE
	if Game.mode == Defs.GameMode.VERSUS:
		wanted = Defs.GameMode.VERSUS
	elif Game.mode == Defs.GameMode.COOP and Game.party > 1:
		wanted = Defs.GameMode.COOP
	hud_layout = wanted
	var coop: bool = wanted == Defs.GameMode.COOP
	var versus: bool = wanted == Defs.GameMode.VERSUS
	if _p2_panel == null:
		return
	_p1_tag.visible = coop
	_p2_panel.visible = coop
	if coop:
		_p2_panel.refresh()
	_edge_arrows.visible = coop or versus
	_edge_arrows.set_process(coop or versus)
	rival_score = coop and Settings.get_bool(OptionsPanel.KEY_RIVAL_SCORE)
	_p2_panel.show_score(rival_score)
	_p2_panel.offset_bottom = P2_TOP + _p2_panel.panel_height()
	_on_score_changed(Game.score)
	for node: CanvasItem in _campaign_nodes:
		node.visible = not versus
	if versus and _versus != null and _versus.player_count() != HudVersus.players_wanted():
		# A new match with another number of players: new panels.
		remove_child(_versus)
		_versus.queue_free()
		_versus = null
	if versus and _versus == null:
		_versus = HudVersus.new()
		add_child(_versus)
	elif not versus and _versus != null:
		_versus.queue_free()
		_versus = null
	if _time_label != null and not versus:
		_time_label.visible = shown_time >= 0
	_place_below_boss_bar()


## True while the belt icon right of P1's hearts shows.
func is_belt_visible() -> bool:
	return _p1_belt != null and _p1_belt.visible


## P2's co-op panel (shown in co-op only).
func get_p2_panel() -> HudPlayerPanel:
	return _p2_panel


## Screen rectangle (viewport px) of the HUD panel of player slot `slot` while it shows: P2's co-op panel, or a versus
## corner panel; an empty Rect2 when that slot has none (P1's hearts are part of the HUD row, which ends at
## [constant ROW_HEIGHT]). Presentation in the world that must stay clear of a panel - a sign board (objects-A) - asks
## here instead of reading the HUD's nodes.
func get_party_panel_rect(slot: int) -> Rect2:
	if _versus != null and is_instance_valid(_versus):
		return _versus.get_panel_rect(slot)
	if slot == 1 and _p2_panel != null and _p2_panel.is_visible_in_tree():
		return _p2_panel.get_global_rect()
	return Rect2()


## The screen rectangles of every party panel that shows now (see [method get_party_panel_rect]).
func get_party_panel_rects() -> Array[Rect2]:
	var result: Array[Rect2] = []
	for slot: int in Defs.MAX_PLAYERS:
		var rect: Rect2 = get_party_panel_rect(slot)
		if rect.has_area():
			result.append(rect)
	return result


## `rect` (viewport px: a sign board with its tail, any world text that must stay readable) moved the shortest way
## clear of every party panel that shows, by at least `gap` px, and kept inside the view; the same rect when it covers
## none. A board that would sit over P2's co-op panel slides below it (or beside it, when that is the shorter way).
func clear_of_panels(rect: Rect2, gap: float = PANEL_CLEAR_GAP) -> Rect2:
	return clear_of(rect, get_party_panel_rects(), get_viewport_rect(), gap)


## [method clear_of_panels] for any list of panels and view (tests, previews).
static func clear_of(rect: Rect2, panels: Array[Rect2], view: Rect2, gap: float) -> Rect2:
	var result: Rect2 = rect
	# A move off one panel may land on another: a few passes settle it (four corner panels at most).
	for _pass: int in panels.size() + 1:
		var moved: bool = false
		for panel: Rect2 in panels:
			var keep: Rect2 = panel.grow(gap)
			if not result.intersects(keep):
				continue
			var best: Vector2 = Vector2.INF
			var fallback: Vector2 = Vector2.INF
			for shift: Vector2 in [Vector2(0.0, keep.end.y - result.position.y), Vector2(0.0, keep.position.y - result.end.y),
					Vector2(keep.position.x - result.end.x, 0.0), Vector2(keep.end.x - result.position.x, 0.0)]:
				if shift.length() < fallback.length():
					fallback = shift
				if view.encloses(Rect2(result.position + shift, result.size)) and shift.length() < best.length():
					best = shift
			result.position += best if best.is_finite() else fallback
			moved = true
		if not moved:
			break
	return result


## The edge arrows of a party.
func get_edge_arrows() -> HudEdgeArrows:
	return _edge_arrows


## The versus HUD (null outside versus).
func get_versus() -> HudVersus:
	return _versus


func _set_belt(belt: int) -> void:
	shown_belt = belt if belt >= 0 else PlayerRun.BELT_EMPTY
	if _p1_belt == null:
		return
	_p1_belt.visible = shown_belt != PlayerRun.BELT_EMPTY
	if _p1_belt.visible:
		_p1_belt.texture = UiPlayers.belt_icon(shown_belt)


func _on_run_belt_changed(slot: int, belt: int) -> void:
	if slot == 0:
		_set_belt(belt)


## Put the intro banner and the hint panel below the boss bar while it shows, back under the HUD row after.
func _place_below_boss_bar() -> void:
	var drop: float = _boss_drop()
	if _hint_holder != null:
		_hint_holder.offset_top = HINT_TOP + drop
		_hint_holder.offset_bottom = HINT_TOP + drop
	if _intro != null and is_instance_valid(_intro) and _intro_gap != null and is_instance_valid(_intro_gap):
		_intro_gap.custom_minimum_size = Vector2(0.0, INTRO_TOP + drop)


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
	var plate: StyleBoxFlat = _text_plate(COL_HINT_BACK)
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


## The reward notice: the fruit icon and "Unlocked: ..." in the focus colour on the hint panel's plate.
func _build_reward(area: Control) -> void:
	_reward_holder = CenterContainer.new()
	_reward_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reward_holder.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_reward_holder.visible = false
	var panel: PanelContainer = PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override(&"panel", _text_plate(COL_HINT_BACK))
	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override(&"separation", HINT_ICON_GAP)
	var icon: TextureRect = UiKit.picture(UiKit.icon(REWARD_ICON))
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)
	_reward_label = UiKit.label("", UiKit.Style.HUD, HORIZONTAL_ALIGNMENT_CENTER)
	_reward_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_reward_label.add_theme_color_override(&"font_color", UiKit.COL_FOCUS)
	_reward_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_reward_label)
	panel.add_child(row)
	_reward_holder.add_child(panel)
	area.add_child(_reward_holder)


## Show the notice of reward `reward` (UnlockTable.REWARDS id): "Unlocked: <its text>" for REWARD_SECONDS.
func show_reward(reward: StringName) -> void:
	var entry: Dictionary = UnlockTable.reward(reward)
	var what: String = tr(str(entry.get("text", ""))) if not entry.is_empty() else String(reward)
	reward_text = tr("UI_HUD_REWARD").format({"reward": what})
	_reward_label.text = reward_text
	_reward_left = REWARD_SECONDS
	_reward_holder.visible = true
	_reward_holder.modulate.a = 0.0
	_place_reward()
	Audio.play_sfx(Sfx.CODE_ACCEPT)


## True while the reward notice is on screen.
func is_reward_visible() -> bool:
	return _reward_holder != null and _reward_holder.visible


## Fade the reward notice in, hold it, fade it out.
func _fade_reward(delta: float) -> void:
	if not is_reward_visible():
		return
	_reward_left -= delta
	if _reward_left <= 0.0:
		_reward_holder.visible = false
		reward_text = ""
		return
	var fade: float = HINT_FADE_SECONDS
	_reward_holder.modulate.a = clampf(minf(_reward_left, REWARD_SECONDS - _reward_left) / fade, 0.0, 1.0)
	_place_reward()


## Under the HUD row (and the boss bar / P2's panel like the hint), below the hint panel while one shows.
func _place_reward() -> void:
	var top: float = HINT_TOP + _boss_drop()
	if _hint_holder != null and _hint_holder.visible and _hint_holder.get_child_count() > 0:
		top += (_hint_holder.get_child(0) as Control).size.y + BOSS_GAP
	_reward_holder.offset_top = top
	_reward_holder.offset_bottom = top


## The ink plate with a thin cream edge of the HUD's text panels (the level banner and the hint panel).
func _text_plate(color: Color) -> StyleBoxFlat:
	var plate: StyleBoxFlat = UiKit.plate(color, HINT_PAD_Y)
	plate.content_margin_left = float(HINT_PAD_X)
	plate.content_margin_right = float(HINT_PAD_X)
	plate.set_border_width_all(2)
	plate.border_color = COL_HINT_EDGE
	return plate


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
	var wanted: bool = not text.is_empty() and not is_intro_visible()
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
	var margins: Vector4i = UiKit.safe_margins(get_viewport())
	var view_w: float = get_viewport_rect().size.x - float(margins.x + margins.z)
	var room: float = view_w - float(2 * HINT_PAD_X + UiKit.ICON_CELL + HINT_ICON_GAP) - 8.0
	var limit: float = maxf(minf(HINT_MAX_TEXT_W, room), 64.0)
	UiKit.wrap_balanced(_hint_label, limit)


func _apply_margins() -> void:
	var margins: Vector4i = UiKit.safe_margins(get_viewport())
	_safe.add_theme_constant_override(&"margin_left", margins.x)
	_safe.add_theme_constant_override(&"margin_top", maxi(0, margins.y - 2))
	_safe.add_theme_constant_override(&"margin_right", margins.z)
	_safe.add_theme_constant_override(&"margin_bottom", margins.w)
	if not _hint_shown_text.is_empty():
		_layout_hint()


func _on_score_changed(score: int) -> void:
	if rival_score:
		# Rival score: P1's own share, in his colour; P2's share in his panel (collectibles credit PlayerRun.score
		# before Game.add_score emits this signal).
		_score_label.text = UiKit.score_text(Game.runs[0].score)
		_score_label.add_theme_color_override(&"font_color", UiPlayers.text_colour(0))
		if _p2_panel != null:
			_p2_panel.set_score(Game.runs[1].score)
		return
	_score_label.text = UiKit.score_text(score)
	_score_label.remove_theme_color_override(&"font_color")


func _on_setting_changed(key: String, _value: Variant) -> void:
	if key == OptionsPanel.KEY_RIVAL_SCORE:
		_apply_layout_mode()


func _on_lives_changed(lives: int) -> void:
	_lives_label.text = "x%d" % clampi(lives, 0, Tuning.LIVES_MAX)


func _on_time_left_changed(seconds: int) -> void:
	shown_time = seconds
	_time_label.visible = seconds >= 0 and hud_layout != Defs.GameMode.VERSUS
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


func _on_boss_started(boss: BossBase) -> void:
	var energy: Vector2i = _boss_energy(boss, Tuning.BOSS_BAR_MAX_PIPS, Tuning.BOSS_BAR_MAX_PIPS)
	boss_pips = Tuning.BOSS_BAR_MAX_PIPS
	boss_max_pips = Tuning.BOSS_BAR_MAX_PIPS
	boss_hp = energy.x
	boss_max_hp = energy.y
	_boss_bar.start(boss_hp, boss_max_hp)
	_place_below_boss_bar()
	# A short boss stage: the fight starts a few seconds in, the arena needs the whole view.
	dismiss_intro()


func _on_boss_energy_changed(boss: BossBase, pips: int, max_pips: int) -> void:
	boss_max_pips = clampi(max_pips, 0, Tuning.BOSS_BAR_MAX_PIPS)
	boss_pips = clampi(pips, 0, boss_max_pips)
	if boss_max_pips <= 0:
		_set_boss(0, 0)
		return
	var energy: Vector2i = _boss_energy(boss, pips, max_pips)
	boss_hp = energy.x
	boss_max_hp = energy.y
	_boss_bar.set_energy(boss_hp, boss_max_hp)
	_place_below_boss_bar()


func _on_boss_defeated(_boss: BossBase) -> void:
	boss_pips = 0
	boss_hp = 0
	_boss_bar.finish()


func _on_level_respawned() -> void:
	_set_boss(0, 0)


## The boss's own hit points (current, maximum) from the signal's boss; the pips stand in when there is no boss
## object (previews, tests): the bar shows the same fraction.
func _boss_energy(boss: BossBase, pips: int, max_pips: int) -> Vector2i:
	if boss != null and is_instance_valid(boss) and boss.max_hp > 0:
		var current: int = 0 if pips <= 0 else clampi(boss.hp, 0, boss.max_hp)
		return Vector2i(current, boss.max_hp)
	return Vector2i(maxi(pips, 0), maxi(max_pips, 1))


func _set_boss(pips: int, max_pips: int) -> void:
	boss_max_pips = clampi(max_pips, 0, Tuning.BOSS_BAR_MAX_PIPS)
	boss_pips = clampi(pips, 0, boss_max_pips)
	boss_hp = 0
	boss_max_hp = 0
	_boss_bar.clear()
	_place_below_boss_bar()


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
