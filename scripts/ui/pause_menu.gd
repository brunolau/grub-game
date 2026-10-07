class_name PauseMenu
extends Control
## Pause menu overlay (docs/ARCHITECTURE.md 8.6, GAMEPLAY.md 12.4): resume, restart from the checkpoint (the
## documented give-up call), restart the level, options (the shared [OptionsPanel]) and quit to the title.
##
## Owner: ui-B. Instantiated by Flow into the menu CanvasLayer; it shows itself on `Events.pause_changed(true)`
## and hides on `false`. It runs while the tree is paused. "Back" leaves the current page, and on the main page
## resumes the game; the pause action itself is handled by Flow.
##
## Pause per slot (2.0, DESIGN.md D.11): in a party the menu belongs to the player who paused (`Flow.pause_slot`): the
## header names him in his colour ("P2 PAUSED"), he drives the menu from his own keys (UiPlayers.menu_action: move,
## Jump / Strike confirm, Look goes back; menu keys and pads work as always), "back to checkpoint" gives up his hero's
## life and Options opens on his binding profile.
## Joining and leaving (DESIGN.md D.1 / D.11, core-A's Flow): in a campaign a second player joins from here ("Second
## player joins", then he presses Jump on his keys or pad: Flow.join_player), a co-op player leaves (Flow.leave_player);
## a lost pad shows "reconnect it, or continue alone" (Flow.lost_pad_slots, Flow.continue_alone). These entries come
## after "Quit" so the 1.0 entries keep their places; mid-stage Flow restarts the stage at its checkpoint.

enum Page { MAIN, OPTIONS, CONFIRM, JOIN }

## Seconds the join page waits for the second player's Jump.
const JOIN_SECONDS: float = 10.0

## Page on screen (Page).
var page: int = Page.MAIN
## The player slot whose menu this is (Flow.pause_slot while it shows; 0 in single-player).
var slot: int = 0

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
var _header_slot: Label = null
var _resume: UiButton = null
var _checkpoint: UiButton = null
var _options_button: UiButton = null
var _join_button: UiButton = null
var _leave_button: UiButton = null
var _alone_button: UiButton = null
var _lost_label: Label = null
var _join_page: VBoxContainer = null
var _join_label: Label = null
var _join_left: float = 0.0
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
	_build_join(content)
	var prompts: UiPrompts = UiPrompts.new()
	prompts.add_hint(&"ui_accept", "UI_HINT_SELECT")
	prompts.add_hint(&"ui_cancel", "UI_HINT_BACK", go_back)
	column.add_child(prompts)
	Events.pause_changed.connect(_on_pause_changed)
	Flow.pad_lost.connect(_on_pad_changed)
	Flow.pad_reconnected.connect(_on_pad_changed)
	set_process(false)
	if get_tree().paused and Flow.current_screen == Flow.SCREEN_LEVEL:
		_on_pause_changed(true)


func _process(delta: float) -> void:
	if page != Page.JOIN:
		set_process(false)
		return
	_join_left -= delta
	if _join_left <= 0.0:
		_show_main(false)
		return
	_join_label.text = tr("UI_PAUSE_JOIN_PRESS").format({"seconds": ceili(_join_left)})


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and visible and Engine.get_process_frames() != _shown_frame:
		go_back()


func _input(event: InputEvent) -> void:
	if visible and page == Page.JOIN:
		_join_input(event)
		return
	if not visible or not GameInput.is_party_input():
		return
	if page == Page.OPTIONS and _options.listening_action != &"":
		return
	var ui: StringName = UiPlayers.menu_action(event, slot)
	if ui == &"":
		return
	# The key test page takes every key itself (it is a test of those keys).
	if page == Page.OPTIONS and _options.get_key_test().is_visible_in_tree() and ui != &"ui_cancel":
		return
	get_viewport().set_input_as_handled()
	UiPlayers.send_menu_action(ui)


func _unhandled_input(event: InputEvent) -> void:
	if visible and UiKit.is_cancel(event):
		get_viewport().set_input_as_handled()
		go_back()


## "Back": leave options / confirmation, or resume the game from the main page.
func go_back() -> void:
	match page:
		Page.OPTIONS:
			_options.go_back()
		Page.CONFIRM, Page.JOIN:
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


## Give up the current life: the hero dies and restarts at the last checkpoint (the documented give-up call). A party
## (2.0): the hero of the player who paused (Flow.pause_slot); what a co-op give-up means for the team is a rule of
## PLAN.md phase 1.
func restart_from_checkpoint() -> void:
	var hero: PlayerBase = _pausing_hero()
	if hero == null or hero.dead:
		Audio.play_sfx(Sfx.CODE_REJECT)
		return
	resume()
	hero.kill(&"give_up")


## The hero of the player who opened the menu: P1 (1.0: the hero); a party: the hero of Flow.pause_slot, else P1.
func _pausing_hero() -> PlayerBase:
	var level: LevelBase = Game.level
	if level == null:
		return null
	if level.hero_count() > 1:
		var hero: PlayerBase = level.get_hero(Flow.pause_slot)
		if hero != null:
			return hero
	return level.player


## Wait for a second player's Jump (the join page; back cancels).
func open_join() -> void:
	_confirm_origin = _join_button
	page = Page.JOIN
	_main.visible = false
	_options.visible = false
	_confirm.visible = false
	_join_page.visible = true
	_join_left = JOIN_SECONDS
	set_process(true)
	_process(0.0)
	var focus: Control = get_viewport().gui_get_focus_owner()
	if focus != null and is_ancestor_of(focus):
		focus.release_focus()


## The player who paused leaves the game (co-op): Flow.leave_player; the stage restarts for the others.
func leave_game() -> void:
	var leaving: int = slot
	_hide_menu()
	if not Flow.leave_player(leaving):
		Audio.play_sfx(Sfx.CODE_REJECT)


## "Continue alone" for the oldest seat whose pad was lost (Flow.continue_alone).
func continue_alone() -> void:
	var lost: PackedInt32Array = Flow.lost_pad_slots()
	if lost.is_empty():
		return
	Flow.continue_alone(lost[0])
	_refresh_party_entries()
	_show_main(false)


## Text of the lost-pad line ("" when no pad is lost).
func get_lost_pad_text() -> String:
	return _lost_label.text if _lost_label.visible else ""


## The entries of 2.0 that show now: "join", "leave", "continue alone" (for tests and previews).
func get_party_entries() -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for pair: Array in [["join", _join_button], ["leave", _leave_button], ["alone", _alone_button]]:
		if (pair[1] as Control).visible:
			result.append(str(pair[0]))
	return result


## Start the level again from its beginning.
func restart_level() -> void:
	_hide_menu()
	Flow.restart_level()


## Leave the run and return to the title screen.
func quit_to_title() -> void:
	_hide_menu()
	Flow.goto_title()


## Open the options page (a party: on the binding profile of the player who paused).
func open_options() -> void:
	_options.fit_height(size.y - OptionsPanel.CHROME_HEIGHT)
	_options.set_bind_profile(slot if _is_party() else OptionsPanel.PROFILE_SOLO)
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
	_header_slot = UiKit.label("", UiKit.Style.HUD, HORIZONTAL_ALIGNMENT_CENTER)
	_header_slot.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_header_slot.visible = false
	_main.add_child(_header_slot)
	var gap: Control = Control.new()
	gap.custom_minimum_size = Vector2(0.0, 6.0)
	_main.add_child(gap)
	_resume = _add_button("UI_PAUSE_RESUME", resume)
	_checkpoint = _add_button("UI_PAUSE_CHECKPOINT", _ask.bind("UI_CONFIRM_CHECKPOINT", restart_from_checkpoint))
	_add_button("UI_PAUSE_RESTART", _ask.bind("UI_CONFIRM_RESTART", restart_level))
	_options_button = _add_button("UI_PAUSE_OPTIONS", open_options)
	_add_button("UI_PAUSE_QUIT", _ask.bind("UI_CONFIRM_QUIT", quit_to_title))
	# 2.0 entries, after the 1.0 ones (flows count the entries from the top).
	_join_button = _add_button("UI_PAUSE_JOIN", open_join)
	_leave_button = _add_button("UI_PAUSE_LEAVE", _ask_leave)
	_alone_button = _add_button("UI_PAUSE_ALONE", continue_alone)
	_lost_label = UiKit.label("", UiKit.Style.SMALL, HORIZONTAL_ALIGNMENT_CENTER)
	_lost_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_lost_label.add_theme_color_override(&"font_color", UiKit.COL_BAD)
	_lost_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lost_label.custom_minimum_size = Vector2(260.0, 0.0)
	_main.add_child(_lost_label)
	_main.move_child(_lost_label, _main.get_children().find(_resume))
	for button: UiButton in [_join_button, _leave_button, _alone_button]:
		button.visible = false
	_lost_label.visible = false


func _build_join(content: VBoxContainer) -> void:
	_join_page = VBoxContainer.new()
	_join_page.visible = false
	_join_page.custom_minimum_size = Vector2(300.0, 0.0)
	_join_page.add_theme_constant_override(&"separation", 6)
	content.add_child(_join_page)
	var heading: Label = UiKit.label("UI_PAUSE_JOIN", UiKit.Style.HUD, HORIZONTAL_ALIGNMENT_CENTER)
	heading.add_theme_color_override(&"font_color", UiKit.COL_FOCUS)
	_join_page.add_child(heading)
	_join_label = UiKit.label("", UiKit.Style.BODY, HORIZONTAL_ALIGNMENT_CENTER)
	_join_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_join_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_join_page.add_child(_join_label)


## While the join page shows: a Jump on keys or a pad that nobody plays with joins (Flow.join_player); a press of an
## input that already plays (the first player's own confirm) is no join.
func _join_input(event: InputEvent) -> void:
	var input: InputSlot = GameInput.join_input_for_event(event)
	if input == null or GameInput.find_input(input) >= 0:
		return
	get_viewport().set_input_as_handled()
	var joined: int = Flow.join_player(input)
	if joined < 0:
		Audio.play_sfx(Sfx.CODE_REJECT)
		return
	# Mid-stage Flow restarts the stage for the party (its scene change ends the pause).
	_hide_menu()


func _ask_leave() -> void:
	_ask(tr("UI_CONFIRM_LEAVE").format({"player": UiPlayers.tag(slot)}), leave_game)


## Show the 2.0 entries that apply now: join (a campaign run below the co-op party size), leave (co-op, a party), the
## lost-pad line and "continue alone".
func _refresh_party_entries() -> void:
	var versus: bool = Game.mode == Defs.GameMode.VERSUS
	var size: int = Flow.party_size()
	_join_button.visible = not versus and size < PartyTuning.COOP_PLAYERS
	var lost: PackedInt32Array = Flow.lost_pad_slots()
	# While a pad is lost "continue alone" is that player's way out (and the panel keeps its height on 640 x 360).
	_leave_button.visible = not versus and Game.mode == Defs.GameMode.COOP and size > 1 and lost.is_empty()
	if _leave_button.visible:
		_leave_button.text = tr("UI_PAUSE_LEAVE").format({"player": UiPlayers.tag(slot)})
	_alone_button.visible = not lost.is_empty()
	_lost_label.visible = not lost.is_empty()
	if not lost.is_empty():
		var tag: String = UiPlayers.tag(lost[0])
		_lost_label.text = tr("UI_PAUSE_PAD_LOST").format({"player": tag})
		_alone_button.text = tr("UI_PAUSE_ALONE").format({"player": tag})


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
	_join_page.visible = false
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
	set_process(false)
	_options.visible = false
	_confirm.visible = false
	_join_page.visible = false
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


## True when the run is a party (co-op or versus with two or more heroes).
func _is_party() -> bool:
	return Game.party > 1 and Game.mode != Defs.GameMode.SINGLE


## Text of the header line that names the player who paused ("" outside a party).
func get_slot_text() -> String:
	return _header_slot.text if _header_slot.visible else ""


func _show_menu() -> void:
	_shown_frame = Engine.get_process_frames()
	slot = clampi(Flow.pause_slot, 0, Defs.MAX_PLAYERS - 1) if _is_party() else 0
	_header_slot.visible = _is_party()
	if _header_slot.visible:
		_header_slot.text = tr("UI_PAUSE_BY").format({"player": UiPlayers.tag(slot)})
		_header_slot.add_theme_color_override(&"font_color", UiPlayers.text_colour(slot))
	var level_id: StringName = Game.level_id
	var number: String = UiKit.level_number(level_id)
	var level_name: String = UiKit.level_name(level_id) if level_id != &"" else ""
	_header_name.text = "%s  %s" % [number, level_name] if number != "" else level_name
	_header_info.text = "%s %s   %s" % [tr("UI_TALLY_SCORE"), UiKit.score_text(Game.score),
			tr("UI_TALLY_COMPLETED").format({"percent": Game.completion_percent()})]
	_header_info.visible = Game.mode != Defs.GameMode.VERSUS
	_refresh_party_entries()
	var hero: PlayerBase = _pausing_hero()
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
	set_process(false)
	_join_page.visible = false
	_confirm.visible = false
	_options.visible = false
	_main.visible = true
	var focus: Control = get_viewport().gui_get_focus_owner()
	if focus != null and is_ancestor_of(focus):
		focus.release_focus()


func _on_pad_changed(_slot: int) -> void:
	if visible:
		_refresh_party_entries()
