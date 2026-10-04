class_name OptionsScreen
extends UiScreen
## Options screen of the title menu: the shared [OptionsPanel] on a menu backdrop. "Back" leaves the current
## page; leaving the panel saves the settings and returns to the title.

var _panel: OptionsPanel = null


func _build_screen() -> void:
	add_child(UiBackdrop.new("ice", 16.0))
	var column: VBoxContainer = VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override(&"separation", 4)
	safe.add_child(column)
	var middle: CenterContainer = CenterContainer.new()
	middle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(middle)
	_panel = OptionsPanel.new()
	_panel.closed.connect(_on_closed)
	middle.add_child(UiKit.panel_box(_panel, 12))
	var prompts: UiPrompts = UiPrompts.new()
	prompts.add_hint(&"ui_left", "UI_HINT_CHANGE")
	prompts.add_hint(&"ui_accept", "UI_HINT_SELECT")
	prompts.add_hint(&"ui_cancel", "UI_HINT_BACK", _on_cancel)
	column.add_child(prompts)


func _screen_ready() -> void:
	Audio.play_music(Sfx.MUSIC_MENU)
	resized.connect(_fit_panel)
	_fit_panel()
	_panel.focus_first()


func _on_cancel() -> void:
	if is_accepting_input():
		_panel.go_back()


func _on_tap() -> void:
	pass


func _on_closed() -> void:
	go_to(Flow.SCREEN_TITLE)


func _fit_panel() -> void:
	_panel.fit_height(size.y - OptionsPanel.CHROME_HEIGHT)
