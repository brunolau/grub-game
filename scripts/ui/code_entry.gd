class_name CodeEntryScreen
extends UiScreen
## "Continue": level select from the saved progress plus the four-character level code (GAMEPLAY.md 1.4, 12.4).
##
## Left panel: the mode (Beginner / Expert) and every campaign level of that mode; reached levels can be started
## (`Flow.continue_game`), the others are shown locked. Right panel: the code. A correct code selects level and
## mode at once; a wrong one shakes the slots. "Back" returns to the title.

const SHAKE_PX: float = 6.0
const START_DELAY: float = 0.7

var _mode_row: UiOptionRow = null
var _list: VBoxContainer = null
var _scroll: ScrollContainer = null
var _empty_note: Label = null
var _slots: Array[UiCodeSlot] = []
var _slot_row: HBoxContainer = null
var _enter_button: UiButton = null
var _message: Label = null
var _difficulty: int = Defs.Difficulty.BEGINNER


func _build_screen() -> void:
	add_child(UiBackdrop.new("cave", 18.0))
	var column: VBoxContainer = VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override(&"separation", 6)
	safe.add_child(column)
	column.add_child(UiKit.label("UI_CONTINUE_HEADING", UiKit.Style.TITLE, HORIZONTAL_ALIGNMENT_CENTER))

	var panels: HBoxContainer = HBoxContainer.new()
	panels.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panels.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panels.alignment = BoxContainer.ALIGNMENT_CENTER
	panels.add_theme_constant_override(&"separation", 16)
	column.add_child(panels)
	panels.add_child(_build_level_panel())
	panels.add_child(_build_code_panel())

	var prompts: UiPrompts = UiPrompts.new()
	prompts.add_hint(&"ui_accept", "UI_HINT_SELECT")
	prompts.add_hint(&"ui_cancel", "UI_HINT_BACK", _on_cancel)
	column.add_child(prompts)


func _screen_ready() -> void:
	Audio.play_music(Sfx.MUSIC_MENU)
	_difficulty = clampi(Settings.get_int("game/last_difficulty"), 0, 1)
	_mode_row.set_index(_difficulty)
	_fill_levels()
	var rows: Array[Node] = _list.get_children()
	var first_open: Control = _mode_row
	for i: int in range(rows.size() - 1, -1, -1):
		var row: UiOptionRow = rows[i] as UiOptionRow
		if row != null and not row.has_meta(&"locked"):
			first_open = row
			break
	UiKit.focus_silently(first_open)


func _unhandled_key_input(event: InputEvent) -> void:
	# A letter or digit typed while the focus is elsewhere goes into the first empty slot.
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo or key.unicode <= 0 or not is_accepting_input():
		return
	var typed_char: String = String.chr(key.unicode).to_upper()
	if not UiCodeSlot.CHARSET.contains(typed_char):
		return
	get_viewport().set_input_as_handled()
	if get_code().length() == _slots.size():
		set_code("")
	var index: int = 0
	while index < _slots.size() and _slots[index].get_character() != "":
		index += 1
	_slots[index].set_character(typed_char)
	_slots[index].grab_focus()
	Audio.play_sfx(Sfx.MENU_MOVE)
	_clear_message()
	_on_slot_typed(index)


func _on_cancel() -> void:
	if is_accepting_input():
		Audio.play_sfx(Sfx.MENU_BACK)
		go_to(Flow.SCREEN_TITLE)


func _on_tap() -> void:
	pass


## The four characters entered so far ("" for empty slots).
func get_code() -> String:
	var code: String = ""
	for slot: UiCodeSlot in _slots:
		code += slot.get_character()
	return code


## Fill the slots with `code` (missing characters stay empty).
func set_code(code: String) -> void:
	for i: int in _slots.size():
		_slots[i].set_character(code[i] if i < code.length() else "")


## Check the code in the slots: a known code starts its level (returns true), anything else is rejected.
func submit_code() -> bool:
	if not is_accepting_input():
		return false
	var code: String = get_code()
	var found: Dictionary = Levels.find_by_password(code) if code.length() == _slots.size() else {}
	# A code only opens a level its mode can play (an Expert-only stage never starts in Beginner).
	if not found.is_empty() and not Levels.is_available(found["level_id"], int(found["difficulty"])):
		found = {}
	if found.is_empty():
		Audio.play_sfx(Sfx.CODE_REJECT)
		_show_message("UI_CODE_WRONG", UiKit.COL_BAD)
		# The next attempt starts at the first character: typing again overwrites the code from the left (with the
		# focus left on the last slot every key would only replace the fourth character).
		if code.length() == _slots.size():
			UiKit.focus_silently(_slots[0])
		var shake: Tween = create_tween()
		for offset: float in [SHAKE_PX, -SHAKE_PX, SHAKE_PX * 0.5, -SHAKE_PX * 0.5, 0.0]:
			shake.tween_property(_slot_row, "position:x", offset, 0.04)
		return false
	var level_id: StringName = found["level_id"]
	var difficulty: int = int(found["difficulty"])
	Audio.play_sfx(Sfx.CODE_ACCEPT)
	var name_text: String = UiKit.level_name(level_id)
	var number: String = UiKit.level_number(level_id)
	_show_message("%s %s" % [number, name_text] if number != "" else name_text, UiKit.COL_GOOD)
	_start_after_delay(level_id, difficulty)
	return true


## Start a reached level of the selected mode (level select). Locked levels are rejected.
func start_level(level_id: StringName) -> void:
	if not is_accepting_input():
		return
	if not _is_reached(level_id, _difficulty):
		Audio.play_sfx(Sfx.CODE_REJECT)
		_show_message("UI_LEVEL_LOCKED", UiKit.COL_BAD)
		return
	_start_after_delay(level_id, _difficulty)


func _start_after_delay(level_id: StringName, difficulty: int) -> void:
	if not begin_leave():
		return
	# The slots take keys themselves: without the focus nothing can change the accepted code (or clear its
	# message) during the delay.
	get_viewport().gui_release_focus()
	Settings.set_value("game/last_difficulty", difficulty)
	var timer: SceneTreeTimer = get_tree().create_timer(START_DELAY)
	timer.timeout.connect(Flow.continue_game.bind(level_id, difficulty))


func _build_level_panel() -> Control:
	var content: VBoxContainer = VBoxContainer.new()
	content.add_theme_constant_override(&"separation", 4)
	content.custom_minimum_size = Vector2(330.0, 0.0)
	_mode_row = UiOptionRow.choice("UI_MODE", PackedStringArray(["UI_MODE_BEGINNER", "UI_MODE_EXPERT"]), 0)
	_mode_row.changed.connect(_on_mode_changed)
	content.add_child(_mode_row)
	var line: ColorRect = ColorRect.new()
	line.color = Color(UiKit.COL_INK, 0.5)
	line.custom_minimum_size = Vector2(0.0, 2.0)
	content.add_child(line)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.custom_minimum_size = Vector2(0.0, 150.0)
	content.add_child(_scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override(&"separation", 0)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_list)
	_empty_note = UiKit.label("UI_CONTINUE_NONE", UiKit.Style.BODY, HORIZONTAL_ALIGNMENT_CENTER)
	_empty_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_empty_note.visible = false
	content.add_child(_empty_note)
	var box: PanelContainer = UiKit.panel_box(content, 12)
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return box


func _build_code_panel() -> Control:
	var content: VBoxContainer = VBoxContainer.new()
	content.add_theme_constant_override(&"separation", 6)
	content.custom_minimum_size = Vector2(216.0, 0.0)
	content.add_child(UiKit.label("UI_CODE_HEADING", UiKit.Style.HUD, HORIZONTAL_ALIGNMENT_CENTER))
	_slot_row = HBoxContainer.new()
	_slot_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_slot_row.add_theme_constant_override(&"separation", 8)
	var holder: Control = Control.new()
	holder.custom_minimum_size = Vector2(0.0, UiCodeSlot.SLOT_SIZE.y)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(holder)
	_slot_row.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.add_child(_slot_row)
	for i: int in 4:
		var slot: UiCodeSlot = UiCodeSlot.new()
		slot.typed.connect(_on_slot_typed.bind(i))
		slot.erased.connect(_on_slot_erased.bind(i))
		slot.character_changed.connect(_clear_message)
		_slot_row.add_child(slot)
		_slots.append(slot)
	_enter_button = UiButton.new("UI_CODE_ENTER")
	_enter_button.press_sound = &""
	_enter_button.pressed.connect(submit_code)
	content.add_child(_enter_button)
	_message = UiKit.label("", UiKit.Style.BODY, HORIZONTAL_ALIGNMENT_CENTER)
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.custom_minimum_size = Vector2(0.0, 44.0)
	content.add_child(_message)
	for i: int in _slots.size():
		var slot: UiCodeSlot = _slots[i]
		slot.gui_input.connect(_on_slot_input)
		if i > 0:
			slot.focus_neighbor_left = slot.get_path_to(_slots[i - 1])
		if i < _slots.size() - 1:
			slot.focus_neighbor_right = slot.get_path_to(_slots[i + 1])
		slot.focus_neighbor_bottom = slot.get_path_to(_enter_button)
	var box: PanelContainer = UiKit.panel_box(content, 12)
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return box


func _fill_levels() -> void:
	for child: Node in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	var campaign: Array[StringName] = Levels.get_campaign(_difficulty)
	_empty_note.visible = campaign.is_empty()
	_scroll.visible = not campaign.is_empty()
	var previous: Control = _mode_row
	for level_id: StringName in campaign:
		var row: UiOptionRow = UiOptionRow.action("")
		var number: String = UiKit.level_number(level_id)
		row.caption = "%s  %s" % [number, UiKit.level_name(level_id)] if number != "" else UiKit.level_name(level_id)
		row.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		if _is_reached(level_id, _difficulty):
			var result: Dictionary = Save.get_level_result(level_id, _difficulty)
			row.value_text = "%d%%" % int(result["percent"]) if int(result["clears"]) > 0 else ""
		else:
			row.set_meta(&"locked", true)
			row.modulate = UiKit.COL_DIM
			row.value_text = "---"
		row.activated.connect(start_level.bind(level_id))
		_list.add_child(row)
		previous.focus_neighbor_bottom = previous.get_path_to(row)
		row.focus_neighbor_top = row.get_path_to(previous)
		row.focus_neighbor_right = row.get_path_to(_slots[0])
		previous = row
	# The mode row uses Left / Right for its value: Down leads on (to the slots when there is no list).
	if campaign.is_empty():
		_mode_row.focus_neighbor_bottom = _mode_row.get_path_to(_slots[0])
	else:
		previous.focus_neighbor_bottom = previous.get_path_to(_enter_button)
	for slot: UiCodeSlot in _slots:
		slot.focus_neighbor_top = slot.get_path_to(_mode_row)
	_slots[0].focus_neighbor_left = _slots[0].get_path_to(_mode_row)
	_enter_button.focus_neighbor_left = _enter_button.get_path_to(_mode_row)
	_enter_button.focus_neighbor_top = _enter_button.get_path_to(_slots[0])


func _is_reached(level_id: StringName, difficulty: int) -> bool:
	return level_id == Levels.get_campaign(difficulty).front() or Save.is_level_unlocked(level_id, difficulty)


func _on_mode_changed(index: int) -> void:
	_difficulty = index
	_fill_levels()


func _on_slot_typed(index: int) -> void:
	if index + 1 < _slots.size():
		_slots[index + 1].grab_focus()
	elif get_code().length() == _slots.size():
		submit_code()


func _on_slot_erased(index: int) -> void:
	if index > 0:
		_slots[index - 1].grab_focus()
		_slots[index - 1].set_character("")


func _on_slot_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_accept") and not event.is_echo():
		get_viewport().set_input_as_handled()
		submit_code()


func _show_message(key: String, color: Color) -> void:
	_message.text = key
	_message.add_theme_color_override(&"font_color", color)


func _clear_message() -> void:
	_message.text = ""
