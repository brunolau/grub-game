extends Control
## QA harness of the ui module: shows one screen or overlay in a prepared state and plays scripted menu input,
## so that the autoplay harness (docs/ARCHITECTURE.md 9.2) can screenshot every ui state.
##
## Owner: ui. Development tool only: nothing in the game refers to this scene. Usage:
##
##   bash .tools/gd.sh play --autoplay-scene=res://scenes/ui/dev/ui_preview.tscn --ui=options \
##       --ui-keys=down,down,right,accept --inputs=120: --shots=12 --fast --out=ui_options
##
##   --ui=<name>          scene `res://scenes/ui/<name>.tscn` (screen or overlay)
##   --ui-args=k=v,k=v    Flow.args of the screen (integers are converted, "a|b|c" becomes a list)
##   --ui-state=<name>    prepared game state: progress | tally | hud | boss | paused | intro (_prepare_state); boss
##                        starts a fight of a boss with --ui-boss-hp=<n> hit points (default 150)
##   --ui-keys=a,b,...    input script, one step every --ui-step seconds after --ui-delay seconds:
##                        up down left right accept cancel pause   ui actions / the pause action
##                        wait                                     do nothing for one step
##                        kbd pad touch                            switch the active device family
##                        boss:<hp>                                the boss now has <hp> hit points (a hit)
##                        defeat                                   the boss is defeated
##                        intro                                    the HUD shows the level banner
##                        key:<name>                               press a key ("key:A", "key:Escape")
##                        tap:<x>:<y>                              click / tap at a view position (art px)
##                        press:<x>:<y> release:<x>:<y>            touch down / up (finger 0) for the touch overlay
##   --ui-step=<seconds>  time between input steps (default 0.35)
##   --ui-delay=<seconds> time before the first step (default 0.8)
##   --ui-view=<w>x<h>    view size in art px to test other aspect ratios (the window becomes twice that size)
##
## Saves and settings are redirected to `res://build/preview_user`, so previews never touch real user data.

const USER_DIR: String = "res://build/preview_user"
const OVERLAYS: PackedStringArray = ["hud", "touch_controls", "pause_menu"]

var _steps: PackedStringArray = PackedStringArray()
var _step_time: float = 0.35
var _wait: float = 0.8
var _next: int = 0
var _boss_hp: int = 150


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	var options: Dictionary = Autoplay.parse_args(OS.get_cmdline_user_args())
	_redirect_user_data()
	if options.has("ui-view"):
		_set_view(str(options["ui-view"]))
	var screen: String = str(options.get("ui", "title"))
	Flow.args = _parse_args(str(options.get("ui-args", "")))
	_prepare_state(str(options.get("ui-state", "")))
	_steps = str(options.get("ui-keys", "")).split(",", false)
	_step_time = maxf(str(options.get("ui-step", "0.35")).to_float(), 0.05)
	_wait = maxf(str(options.get("ui-delay", "0.8")).to_float(), 0.0)
	_boss_hp = maxi(str(options.get("ui-boss-hp", "150")).to_int(), 1)
	_show.call_deferred(screen, str(options.get("ui-state", "")))


func _process(delta: float) -> void:
	if _next >= _steps.size():
		return
	_wait -= delta
	if _wait > 0.0:
		return
	_wait = _step_time
	_play_step(_steps[_next].strip_edges())
	_next += 1


func _show(screen: String, state: String) -> void:
	var path: String = "res://scenes/ui/%s.tscn" % screen
	if not ResourceLoader.exists(path):
		push_error("ui_preview: scene '%s' does not exist" % path)
		return
	var scene: PackedScene = load(path) as PackedScene
	if OVERLAYS.has(screen):
		add_child(UiBackdrop.new("jungle", 0.0))
		var layer: CanvasLayer = CanvasLayer.new()
		layer.layer = Defs.LAYER_HUD
		add_child(layer)
		if screen != "hud" and ResourceLoader.exists(Flow.HUD_SCENE):
			layer.add_child((load(Flow.HUD_SCENE) as PackedScene).instantiate())
		layer.add_child(scene.instantiate())
		_after_overlay.call_deferred(state)
	else:
		add_child(scene.instantiate())


func _after_overlay(state: String) -> void:
	match state:
		"boss":
			# Without a boss object the HUD reads the energy as hit points of the maximum.
			Events.boss_started.emit(null)
			Events.boss_energy_changed.emit(null, _boss_hp, _boss_hp)
		"paused":
			Events.pause_changed.emit(true)
		"intro":
			var hud: Hud = get_tree().get_first_node_in_group(Defs.GROUP_HUD) as Hud
			if hud != null:
				hud.show_intro(Game.level_id)


func _prepare_state(state: String) -> void:
	Game.new_game(Defs.Difficulty.BEGINNER)
	var level_id: StringName = StringName(str(Flow.args.get("level_id", "")))
	if level_id == &"" or not Levels.has_level(level_id):
		var ids: Array[StringName] = Levels.all_ids()
		level_id = Levels.first_level() if Levels.first_level() != &"" else (ids[0] if not ids.is_empty() else &"")
	if level_id != &"":
		Game.begin_level(level_id)
	match state:
		"progress":
			for difficulty: int in [Defs.Difficulty.BEGINNER, Defs.Difficulty.EXPERT]:
				var campaign: Array[StringName] = Levels.get_campaign(difficulty)
				if Flow.args.get("campaign") is Array:
					var ids: Array = Flow.args["campaign"]
					campaign.assign(ids.map(func(id: Variant) -> StringName: return StringName(str(id))))
				for i: int in mini(campaign.size(), 2 + difficulty * 2):
					Save.unlock_level(campaign[i], difficulty)
					Save.record_level_result(campaign[i], difficulty, 12340 * (i + 1), 55 + i * 9)
			Save.submit_score(123400)
		"tally":
			Game.add_score(48200)
			for i: int in 14:
				Game.add_tally_item(&"items/food", (i * 7) % 48, 100 + 100 * (i % 5))
			Game.add_tally_item(&"items/treasure", 8, 5000)
			Game.add_tally_item(&"items/giant_bonus", 2, 30000)
			Game.add_tally_item(&"items/letter", 1, 0)
		"hud", "boss", "paused", "intro":
			Game.add_score(12340)
			Game.lose_heart()
			Game.add_bones(3)
			Game.collect_letter(0)
			Game.collect_letter(1)
			Game.collect_letter(4)
			Game.collect_feast_piece(0)


func _play_step(step: String) -> void:
	var parts: PackedStringArray = step.split(":")
	match parts[0]:
		"wait", "":
			pass
		"up", "down", "left", "right", "accept", "cancel":
			_send_action(StringName("ui_" + parts[0]))
		"pause":
			Events.pause_changed.emit(true)
		"boss":
			if parts.size() > 1:
				Events.boss_energy_changed.emit(null, parts[1].to_int(), _boss_hp)
		"defeat":
			Events.boss_energy_changed.emit(null, 0, _boss_hp)
			Events.boss_defeated.emit(null)
		"intro":
			var hud: Hud = get_tree().get_first_node_in_group(Defs.GROUP_HUD) as Hud
			if hud != null:
				hud.show_intro(Game.level_id)
		"kbd":
			_send_key(KEY_SHIFT)
		"pad":
			var button: InputEventJoypadButton = InputEventJoypadButton.new()
			button.button_index = JOY_BUTTON_LEFT_STICK
			button.pressed = true
			get_viewport().push_input(button)
		"touch":
			var touch: InputEventScreenTouch = InputEventScreenTouch.new()
			touch.index = 9
			touch.position = Vector2(-10.0, -10.0)
			touch.pressed = true
			get_viewport().push_input(touch)
			touch = touch.duplicate() as InputEventScreenTouch
			touch.pressed = false
			get_viewport().push_input(touch)
		"key":
			if parts.size() > 1:
				_send_key(OS.find_keycode_from_string(parts[1]))
		"tap", "press", "release":
			if parts.size() > 2:
				_send_pointer(parts[0], Vector2(parts[1].to_float(), parts[2].to_float()))


func _send_action(action: StringName) -> void:
	for pressed: bool in [true, false]:
		var event: InputEventAction = InputEventAction.new()
		event.action = action
		event.pressed = pressed
		get_viewport().push_input(event)


func _send_key(code: Key) -> void:
	for pressed: bool in [true, false]:
		var event: InputEventKey = InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.unicode = int(code) if code >= KEY_SPACE and code <= KEY_Z else 0
		event.pressed = pressed
		get_viewport().push_input(event)


func _send_pointer(kind: String, pos: Vector2) -> void:
	if kind == "tap":
		for pressed: bool in [true, false]:
			var click: InputEventMouseButton = InputEventMouseButton.new()
			click.button_index = MOUSE_BUTTON_LEFT
			click.position = pos
			click.global_position = pos
			click.pressed = pressed
			get_viewport().push_input(click)
		return
	var touch: InputEventScreenTouch = InputEventScreenTouch.new()
	touch.index = 0
	touch.position = pos
	touch.pressed = kind == "press"
	get_viewport().push_input(touch)


func _parse_args(text: String) -> Dictionary:
	var result: Dictionary = {}
	for pair: String in text.split(",", false):
		var eq: int = pair.find("=")
		if eq < 0:
			continue
		var value: String = pair.substr(eq + 1)
		var key: String = pair.substr(0, eq)
		if value.contains("|"):
			result[key] = Array(value.split("|"))
		elif value.is_valid_int():
			result[key] = value.to_int()
		elif key == "level_id":
			result[key] = StringName(value)
		else:
			result[key] = value
	return result


func _set_view(text: String) -> void:
	var parts: PackedStringArray = text.split("x")
	if parts.size() != 2:
		return
	var view: Vector2i = Vector2i(parts[0].to_int(), parts[1].to_int())
	if view.x > 0 and view.y > 0:
		DisplayServer.window_set_size(view * 2)


func _redirect_user_data() -> void:
	var absolute: String = ProjectSettings.globalize_path(USER_DIR)
	DirAccess.make_dir_recursive_absolute(absolute)
	for file: String in ["save.json", "save.json.bak", "save.json.tmp", "settings.cfg"]:
		if FileAccess.file_exists(absolute + "/" + file):
			DirAccess.remove_absolute(absolute + "/" + file)
	Save.set_storage_dir(USER_DIR)
	Settings.set_storage_dir(USER_DIR)
