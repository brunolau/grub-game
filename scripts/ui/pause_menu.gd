class_name PauseMenu
extends Control
## Pause menu overlay (docs/ARCHITECTURE.md 8.6, GAMEPLAY.md 12.4): resume, restart from the checkpoint (the
## documented give-up call), restart the level, options (the shared [OptionsPanel]) and quit to the title.
##
## Owner: ui. Instantiated by Flow into the menu CanvasLayer; it shows itself on `Events.pause_changed(true)`
## and hides on `false`. It runs while the tree is paused. "Back" leaves the current page, and on the main page
## resumes the game; the pause action itself is handled by Flow.

enum Page { MAIN, OPTIONS, CONFIRM }

## Page on screen (Page).
var page: int = Page.MAIN

var _box: PanelContainer = null
var _main: VBoxContainer = null
var _options: OptionsPanel = null
var _confirm: VBoxContainer = null
var _confirm_text: Label = null
var _confirm_yes: UiButton = null
var _confirm_action: Callable = Callable()
var _confirm_origin: Control = null
var _header_name: Label = null
var _header_info: Label = null
var _resume: UiButton = null
var _checkpoint: UiButton = null
var _options_button: UiButton = null
var _shown_frame: int = -1


func _init() -> void:
	UiKit.ensure_locale()
	theme = UiKit.theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false


func _ready() -> void:
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(UiKit.COL_INK, 0.62)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var safe: MarginContainer = MarginContainer.new()
	safe.set_anchors_preset(Control.PRESET_FULL_RECT)
	safe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(safe)
	UiKit.apply_safe_margins(safe)
	var column: VBoxContainer = VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	safe.add_child(column)
	var middle: CenterContainer = CenterContainer.new()
	middle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(middle)
	var content: VBoxContainer = VBoxContainer.new()
	content.add_theme_constant_override(&"separation", 4)
	_box = UiKit.panel_box(content, 12)
	middle.add_child(_box)
	_build_main(content)
	_options = OptionsPanel.new()
	_options.closed.connect(_show_main.bind(true))
	_options.visible = false
	content.add_child(_options)
	_build_confirm(content)
	var prompts: UiPrompts = UiPrompts.new()
	prompts.add_hint(&"ui_accept", "UI_HINT_SELECT")
	prompts.add_hint(&"ui_cancel", "UI_HINT_BACK", go_back)
	column.add_child(prompts)
	Events.pause_changed.connect(_on_pause_changed)
	if get_tree().paused and Flow.current_screen == Flow.SCREEN_LEVEL:
		_on_pause_changed(true)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and visible and Engine.get_process_frames() != _shown_frame:
		go_back()


func _unhandled_input(event: InputEvent) -> void:
	if visible and UiKit.is_cancel(event):
		get_viewport().set_input_as_handled()
		go_back()


## "Back": leave options / confirmation, or resume the game from the main page.
func go_back() -> void:
	match page:
		Page.OPTIONS:
			_options.go_back()
		Page.CONFIRM:
			Audio.play_sfx(Sfx.MENU_BACK)
			_show_main(false)
		_:
			resume()


## Close the menu and continue playing.
func resume() -> void:
	if Flow.is_paused():
		Flow.set_paused(false)
	else:
		_hide_menu()


## Give up the current life: the hero dies and restarts at the last checkpoint (the documented give-up call).
func restart_from_checkpoint() -> void:
	var level: LevelBase = Game.level
	if level == null or level.player == null or level.player.dead:
		Audio.play_sfx(Sfx.CODE_REJECT)
		return
	var hero: PlayerBase = level.player
	resume()
	hero.kill(&"give_up")


## Start the level again from its beginning.
func restart_level() -> void:
	_hide_menu()
	Flow.restart_level()


## Leave the run and return to the title screen.
func quit_to_title() -> void:
	_hide_menu()
	Flow.goto_title()


## Open the options page.
func open_options() -> void:
	_options.fit_height(size.y - OptionsPanel.CHROME_HEIGHT)
	page = Page.OPTIONS
	_main.visible = false
	_confirm.visible = false
	_options.visible = true
	_options.focus_first()


func _build_main(content: VBoxContainer) -> void:
	_main = VBoxContainer.new()
	_main.add_theme_constant_override(&"separation", 0)
	_main.custom_minimum_size = Vector2(260.0, 0.0)
	content.add_child(_main)
	var heading: Label = UiKit.label("UI_PAUSE_HEADING", UiKit.Style.TITLE, HORIZONTAL_ALIGNMENT_CENTER)
	_main.add_child(heading)
	_header_name = UiKit.label("", UiKit.Style.HUD, HORIZONTAL_ALIGNMENT_CENTER)
	_header_name.add_theme_color_override(&"font_color", UiKit.COL_FOCUS)
	_header_name.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_main.add_child(_header_name)
	_header_info = UiKit.label("", UiKit.Style.SMALL, HORIZONTAL_ALIGNMENT_CENTER)
	_header_info.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_main.add_child(_header_info)
	var gap: Control = Control.new()
	gap.custom_minimum_size = Vector2(0.0, 6.0)
	_main.add_child(gap)
	_resume = _add_button("UI_PAUSE_RESUME", resume)
	_checkpoint = _add_button("UI_PAUSE_CHECKPOINT", _ask.bind("UI_CONFIRM_CHECKPOINT", restart_from_checkpoint))
	_add_button("UI_PAUSE_RESTART", _ask.bind("UI_CONFIRM_RESTART", restart_level))
	_options_button = _add_button("UI_PAUSE_OPTIONS", open_options)
	_add_button("UI_PAUSE_QUIT", _ask.bind("UI_CONFIRM_QUIT", quit_to_title))


func _build_confirm(content: VBoxContainer) -> void:
	_confirm = VBoxContainer.new()
	_confirm.visible = false
	_confirm.custom_minimum_size = Vector2(300.0, 0.0)
	_confirm.add_theme_constant_override(&"separation", 6)
	content.add_child(_confirm)
	_confirm_text = UiKit.label("", UiKit.Style.BODY, HORIZONTAL_ALIGNMENT_CENTER)
	_confirm_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_confirm.add_child(_confirm_text)
	_confirm_yes = UiButton.new("UI_YES")
	_confirm_yes.pressed.connect(_on_confirm_yes)
	_confirm.add_child(_confirm_yes)
	var no: UiButton = UiButton.new("UI_NO")
	no.press_sound = Sfx.MENU_BACK
	no.pressed.connect(_show_main.bind(false))
	_confirm.add_child(no)


func _add_button(key: String, callback: Callable) -> UiButton:
	var button: UiButton = UiButton.new(key)
	button.pressed.connect(callback)
	_main.add_child(button)
	return button


func _ask(question: String, action: Callable) -> void:
	_confirm_origin = get_viewport().gui_get_focus_owner()
	_confirm_text.text = question
	_confirm_action = action
	page = Page.CONFIRM
	_main.visible = false
	_options.visible = false
	_confirm.visible = true
	UiKit.focus_silently(_confirm_yes)


func _on_confirm_yes() -> void:
	var action: Callable = _confirm_action
	_confirm_action = Callable()
	_show_main(false)
	if action.is_valid():
		action.call()


func _show_main(from_options: bool) -> void:
	page = Page.MAIN
	_options.visible = false
	_confirm.visible = false
	_main.visible = true
	var target: Control = _options_button if from_options else _confirm_origin
	# The entry that opened the confirmation may be disabled now ("back to checkpoint" while the hero is dead).
	if target == null or not target.is_visible_in_tree() or target.focus_mode == Control.FOCUS_NONE:
		target = _resume
	UiKit.focus_silently(target)


func _on_pause_changed(paused: bool) -> void:
	if paused:
		_show_menu()
	else:
		_hide_menu()


func _show_menu() -> void:
	_shown_frame = Engine.get_process_frames()
	var level_id: StringName = Game.level_id
	var number: String = UiKit.level_number(level_id)
	var level_name: String = UiKit.level_name(level_id) if level_id != &"" else ""
	_header_name.text = "%s  %s" % [number, level_name] if number != "" else level_name
	_header_info.text = "%s %s   %s" % [tr("UI_TALLY_SCORE"), UiKit.score_text(Game.score),
			tr("UI_TALLY_COMPLETED").format({"percent": Game.completion_percent()})]
	var hero: PlayerBase = Game.level.player if Game.level != null else null
	_checkpoint.disabled = hero == null or hero.dead
	_checkpoint.focus_mode = Control.FOCUS_NONE if _checkpoint.disabled else Control.FOCUS_ALL
	visible = true
	_show_main(false)
	UiKit.focus_silently(_resume)
	_box.modulate.a = 0.0
	_box.pivot_offset = _box.size * 0.5
	_box.scale = Vector2(0.9, 0.9)
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(_box, "modulate:a", 1.0, 0.12)
	tween.tween_property(_box, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _hide_menu() -> void:
	if not visible:
		return
	if page == Page.OPTIONS:
		_options.close()
	visible = false
	page = Page.MAIN
	var focus: Control = get_viewport().gui_get_focus_owner()
	if focus != null and is_ancestor_of(focus):
		focus.release_focus()
