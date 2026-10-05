extends TestCase
## project.godot: input map, display, rendering and autoload settings the architecture relies on.


func _has_event(action: StringName, kind: String) -> bool:
	for event: InputEvent in InputMap.action_get_events(action):
		if event.get_class() == kind:
			return true
	return false


func test_game_actions_are_bound_to_keyboard_and_gamepad() -> void:
	for action: StringName in Defs.GAME_ACTIONS:
		assert_true(InputMap.has_action(action), "action '%s' exists" % action)
		assert_true(_has_event(action, "InputEventKey"), "action '%s' has a key" % action)
		assert_true(_has_event(action, "InputEventJoypadButton"), "action '%s' has a gamepad button" % action)


func test_movement_is_also_on_the_left_stick_with_a_half_dead_zone() -> void:
	for action: StringName in [Defs.ACT_LEFT, Defs.ACT_RIGHT, Defs.ACT_UP, Defs.ACT_DOWN]:
		assert_true(_has_event(action, "InputEventJoypadMotion"), "action '%s' has a stick axis" % action)
		assert_almost_eq(InputMap.action_get_deadzone(action), 0.5, 0.001, "PHYSICS.md 15.4")


func test_ui_actions_are_bound_to_keyboard_and_gamepad() -> void:
	for action: StringName in [&"ui_accept", &"ui_cancel", &"ui_left", &"ui_right", &"ui_up", &"ui_down"]:
		assert_true(InputMap.has_action(action), "action '%s' exists" % action)
		assert_true(_has_event(action, "InputEventKey"), "action '%s' has a key" % action)
		assert_true(
			_has_event(action, "InputEventJoypadButton") or _has_event(action, "InputEventJoypadMotion"),
			"action '%s' has a gamepad binding" % action
		)


func test_gamepad_start_pauses_and_confirms_but_never_cancels() -> void:
	var start: InputEventJoypadButton = InputEventJoypadButton.new()
	start.button_index = JOY_BUTTON_START
	start.pressed = true
	assert_true(InputMap.event_is_action(start, Defs.ACT_PAUSE, true), "Start pauses the game")
	assert_true(InputMap.event_is_action(start, &"ui_accept", true), "Start confirms menu entries")
	assert_false(InputMap.event_is_action(start, &"ui_cancel", true), "Start is no 'back'")
	var a_button: InputEventJoypadButton = InputEventJoypadButton.new()
	a_button.button_index = JOY_BUTTON_A
	var accept_pad: Array[int] = []
	for event: InputEvent in InputMap.action_get_events(&"ui_accept"):
		if event is InputEventJoypadButton:
			accept_pad.append((event as InputEventJoypadButton).button_index)
	assert_eq(accept_pad[0], JOY_BUTTON_A, "A stays the first pad button of ui_accept (the prompts show it)")
	var escape: InputEventKey = InputEventKey.new()
	escape.physical_keycode = KEY_ESCAPE
	escape.pressed = true
	assert_true(InputMap.event_is_action(escape, &"ui_cancel", true), "Escape keeps 'back'")
	assert_false(InputMap.event_is_action(escape, &"ui_accept", true))


func test_display_settings() -> void:
	assert_eq(int(ProjectSettings.get_setting("display/window/size/viewport_width")), Tuning.VIEW_W * Tuning.ART_SCALE)
	assert_eq(int(ProjectSettings.get_setting("display/window/size/viewport_height")), Tuning.VIEW_H * Tuning.ART_SCALE)
	assert_eq(str(ProjectSettings.get_setting("display/window/stretch/mode")), "viewport")
	assert_eq(str(ProjectSettings.get_setting("display/window/stretch/aspect")), "expand")
	assert_eq(str(ProjectSettings.get_setting("display/window/stretch/scale_mode")), "integer")
	assert_eq(int(ProjectSettings.get_setting("rendering/textures/canvas_textures/default_texture_filter")), 0,
		"nearest filtering")
	assert_eq(str(ProjectSettings.get_setting("rendering/renderer/rendering_method")), "gl_compatibility")
	assert_eq(str(ProjectSettings.get_setting("rendering/renderer/rendering_method.mobile")), "gl_compatibility")
	assert_eq(int(ProjectSettings.get_setting("display/window/handheld/orientation")), 4, "sensor landscape")
	assert_true(bool(ProjectSettings.get_setting("rendering/2d/snap/snap_2d_transforms_to_pixel")))
	assert_eq(Tuning.TILE * Tuning.ART_SCALE, Tuning.TILE_ART)


func test_physics_layer_names() -> void:
	var expected: Array[String] = [
		"world", "player", "enemies", "items", "objects", "hazards", "platforms", "hero_weapons",
		"enemy_projectiles", "triggers",
	]
	for i: int in expected.size():
		assert_eq(str(ProjectSettings.get_setting("layer_names/2d_physics/layer_%d" % (i + 1))), expected[i])
	assert_eq(Defs.PHYS_PLAYER, 2)
	assert_eq(Defs.PHYS_TRIGGERS, 512)


func test_autoloads_and_buses_exist() -> void:
	var autoloads: PackedStringArray = [
		"Settings", "Save", "Events", "Game", "Levels", "GameInput", "Sim", "Audio", "Flow", "Autoplay",
	]
	for autoload: String in autoloads:
		assert_not_null(get_tree().root.get_node_or_null(autoload), "autoload " + autoload)
	for bus: String in ["Master", "Music", "SFX", "UI"]:
		assert_true(AudioServer.get_bus_index(bus) >= 0, "audio bus " + bus)
	assert_eq(str(ProjectSettings.get_setting("application/run/main_scene")), "res://scenes/main.tscn")
	assert_true(ResourceLoader.exists("res://scenes/main.tscn"))
	assert_true(ResourceLoader.exists(str(ProjectSettings.get_setting("application/config/icon"))))


func test_every_audio_event_points_at_an_existing_file() -> void:
	for event: StringName in AudioTable.SFX:
		var entry: Dictionary = AudioTable.SFX[event]
		var files: Array = entry["files"]
		var levels: Array = entry["db"]
		assert_eq(files.size(), levels.size(), "event '%s' has one volume per file" % event)
		for file: String in files:
			assert_true(ResourceLoader.exists(AudioTable.SFX_DIR + file), "sfx file %s" % file)
	for context: StringName in AudioTable.MUSIC:
		var file: String = AudioTable.MUSIC[context]["file"]
		assert_true(ResourceLoader.exists(AudioTable.MUSIC_DIR + file), "music file %s" % file)
