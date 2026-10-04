extends Control
## Boot scene (`res://scenes/main.tscn`). Owner: core.
##
## Hands over to the title screen as soon as the ui module provides `scenes/ui/title.tscn`. Until then (and
## whenever Flow falls back here because a screen is missing) it shows a plain status page from which the first
## level can be started, so the project is always bootable.

var _status: Label = null


func _ready() -> void:
	if Autoplay.active and not Autoplay.flow_mode:
		# The QA harness drives the run: show the status page, but do not redirect or play music.
		_build_placeholder()
		return
	if Flow.has_screen(Flow.SCREEN_TITLE) and not Flow.args.has("missing_screen"):
		Flow.goto_screen.call_deferred(Flow.SCREEN_TITLE, Defs.Transition.NONE)
		return
	_build_placeholder()
	Audio.play_music(Sfx.MUSIC_TITLE)


func _unhandled_input(event: InputEvent) -> void:
	if _status == null or Flow.busy:
		return
	if event.is_action_pressed(&"ui_accept") or event.is_action_pressed(Defs.ACT_ATTACK):
		accept_event()
		_start()
	elif event.is_action_pressed(&"ui_cancel"):
		accept_event()
		Flow.quit_game()


## Level the placeholder starts: the first campaign level, else the first test level, else none (also none when
## the build has no gameplay scene).
func get_start_level() -> StringName:
	if not Flow.has_gameplay():
		return &""
	var first: StringName = Levels.first_level()
	if first != &"":
		return first
	var ids: Array[StringName] = Levels.all_ids()
	return ids[0] if not ids.is_empty() else &""


func _start() -> void:
	var level_id: StringName = get_start_level()
	if level_id == &"":
		return
	Game.new_game(Settings.get_int("game/last_difficulty"))
	Flow.start_level(level_id)


func _build_placeholder() -> void:
	var background: ColorRect = ColorRect.new()
	background.color = Color("272018")
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var box: VBoxContainer = VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 12)
	add_child(box)
	var logo_path: String = "res://assets/ui/title_logo.png"
	if ResourceLoader.exists(logo_path):
		var logo: TextureRect = TextureRect.new()
		logo.texture = load(logo_path) as Texture2D
		logo.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		box.add_child(logo)
	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_font_size_override("font_size", 16)
	_status.text = _status_text()
	box.add_child(_status)


func _status_text() -> String:
	var lines: PackedStringArray = PackedStringArray()
	lines.append("%s  v%s" % [
		ProjectSettings.get_setting("application/config/name"),
		ProjectSettings.get_setting("application/config/version"),
	])
	if Flow.args.has("missing_screen"):
		lines.append("Screen '%s' is not built yet." % Flow.args["missing_screen"])
	else:
		lines.append("Title screen is not built yet.")
	var level_id: StringName = get_start_level()
	if not Flow.has_gameplay():
		lines.append("The gameplay scene is not built yet.")
	elif level_id == &"":
		lines.append("No level file found in %s." % Levels.LEVEL_DIR)
	else:
		lines.append("Press ATTACK / ENTER to play '%s'." % level_id)
	lines.append("%d level file(s) found." % Levels.all_ids().size())
	return "\n".join(lines)
