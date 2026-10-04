extends Node
## Autoload `Flow`: the only place that changes scenes (docs/ARCHITECTURE.md 3.10, GAMEPLAY.md 11.1).
##
## CONTRACT FILE. Owner: core. Public members are frozen.
##
## Screens are found by naming convention: screen "tally" is `res://scenes/ui/tally.tscn`. Gameplay is always
## `res://scenes/world/level.tscn` (or the collision-only debug level while that scene does not exist), which
## reads [member pending_level_id]. While a level runs, Flow owns the
## overlay CanvasLayers and fills them with `scenes/ui/hud.tscn`, `touch_controls.tscn` and `pause_menu.tscn`.
## A scene that does not exist yet is skipped (the flow continues with the next step) or replaced by the
## placeholder main scene, so the game stays runnable while modules are being built.
##
## Transitions (GAMEPLAY.md 11.1) are drawn by one [TransitionCover] on CanvasLayer Defs.LAYER_TRANSITION: FADE
## between menu screens, CURTAIN into gameplay (it opens from the centre), IRIS on the hero at the end of a level.
## While the cover hides a level the simulation clock stands still (Sim.frozen), so nothing happens unseen.
##
## Flow also reacts to the application losing focus or going to the background (every platform, most important
## on phones): gameplay is paused, all sound is suspended, and settings are written before the OS may kill the
## app. Sound resumes with the focus; gameplay stays paused until the player resumes it.

## A screen or the level became active. `screen` is one of the SCREEN_* names or SCREEN_LEVEL.
signal screen_changed(screen: StringName)
## The screen is fully covered by the transition (old scene still loaded).
signal transition_covered
## The transition finished uncovering the new scene.
signal transition_finished

const MAIN_SCENE: String = "res://scenes/main.tscn"
const LEVEL_SCENE: String = "res://scenes/world/level.tscn"
## Collision-only stand-in used while LEVEL_SCENE does not exist (core development tool).
const DEBUG_LEVEL_SCENE: String = "res://scenes/core/debug_level.tscn"
const SCREEN_DIR: String = "res://scenes/ui/"
const HUD_SCENE: String = "res://scenes/ui/hud.tscn"
const TOUCH_SCENE: String = "res://scenes/ui/touch_controls.tscn"
const PAUSE_SCENE: String = "res://scenes/ui/pause_menu.tscn"

# Transition timing in seconds at transition_speed 1.
const FADE_SECONDS: float = 0.25        ## fade to / from black
const CURTAIN_SECONDS: float = 0.4      ## the curtain panels cross half the screen
const IRIS_SECONDS: float = 0.55        ## the iris travels between "open" and the spotlight (or "shut")
const IRIS_HOLD_SECONDS: float = 0.25   ## a closing iris rests as a spotlight on the hero
const IRIS_SHUT_SECONDS: float = 0.15   ## then the spotlight closes completely
const IRIS_HOLD_RADIUS: float = 48.0    ## radius of that spotlight in art px (the hero is about 64 x 70)

# Screen names (each is a scene in SCREEN_DIR, owned by the ui module).
const SCREEN_TITLE: StringName = &"title"              ## title picture + main menu
const SCREEN_MODE_SELECT: StringName = &"mode_select"  ## BEGINNER / EXPERT
const SCREEN_CODE_ENTRY: StringName = &"code_entry"    ## password / continue screen
const SCREEN_OPTIONS: StringName = &"options"
const SCREEN_WORLD_MAP: StringName = &"world_map"      ## args: {"level_id": StringName}
const SCREEN_TALLY: StringName = &"tally"              ## args: {"level_id": StringName, "percent": int}
const SCREEN_GAME_OVER: StringName = &"game_over"
const SCREEN_EXPERT_WALL: StringName = &"expert_wall"  ## "you must be an expert" (GAMEPLAY.md 1.3)
const SCREEN_THE_END: StringName = &"the_end"
const SCREEN_CREDITS: StringName = &"credits"
const SCREEN_LEVEL: StringName = &"level"              ## gameplay (not in SCREEN_DIR)
const SCREEN_BOOT: StringName = &"boot"                ## placeholder main scene

## Active screen name.
var current_screen: StringName = SCREEN_BOOT
## Arguments of the active screen (read-only for the screen).
var args: Dictionary = {}
## Level the gameplay scene must load (set before LEVEL_SCENE is entered).
var pending_level_id: StringName = &""
## True while a transition runs; requests made meanwhile are ignored.
var busy: bool = false
## When true transitions take no time (tests, autoplay, headless smoke runs).
var instant_transitions: bool = false
## Speed factor of timed transitions: 1 = the durations above, 2 = twice as fast.
var transition_speed: float = 1.0
## When true (default) gameplay pauses and all sound is suspended while the application has no focus or is in
## the background. The autoplay harness switches it off: its windows rarely have the focus.
var pause_on_focus_loss: bool = true

var _layer: CanvasLayer = null
var _cover: TransitionCover = null
var _cover_tween: Tween = null
var _overlay_hud: CanvasLayer = null
var _overlay_touch: CanvasLayer = null
var _overlay_menu: CanvasLayer = null
var _quitting: bool = false
## Counts transitions; lets play_covered() notice that its action started a scene change.
var _transition_serial: int = 0
var _app_focused: bool = true
var _app_resumed: bool = true
var _app_active: bool = true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# _process only keeps a closing iris on the hero.
	set_process(false)
	_layer = CanvasLayer.new()
	_layer.layer = Defs.LAYER_TRANSITION
	add_child(_layer)
	_cover = TransitionCover.new()
	_layer.add_child(_cover)
	_overlay_hud = _make_overlay(Defs.LAYER_HUD)
	_overlay_touch = _make_overlay(Defs.LAYER_TOUCH)
	_overlay_menu = _make_overlay(Defs.LAYER_MENU)
	if DisplayServer.get_name() == "headless":
		instant_transitions = true


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED:
			# Mobile: the app goes to the background, where the OS may kill it without another word.
			_app_resumed = false
			_update_app_active()
			Settings.save()
		NOTIFICATION_APPLICATION_RESUMED:
			_app_resumed = true
			_update_app_active()
		NOTIFICATION_APPLICATION_FOCUS_OUT:
			_app_focused = false
			_update_app_active()
		NOTIFICATION_APPLICATION_FOCUS_IN:
			_app_focused = true
			_update_app_active()
		NOTIFICATION_WM_CLOSE_REQUEST:
			# The window was closed (auto_accept_quit is off): leave cleanly.
			shutdown_and_quit(0)
		NOTIFICATION_WM_GO_BACK_REQUEST:
			# Android back button / gesture (quit_on_go_back is off): pause running gameplay; everywhere else
			# (menus, the pause menu) it is the "cancel" action, so screens need no Android-specific code.
			if current_screen == SCREEN_LEVEL and not get_tree().paused:
				if not busy:
					set_paused(true)
			else:
				_send_cancel_action()


func _process(_delta: float) -> void:
	_cover.focus = _transition_focus(Defs.Transition.IRIS)


func _unhandled_input(event: InputEvent) -> void:
	if current_screen == SCREEN_LEVEL and not busy and event.is_action_pressed(Defs.ACT_PAUSE):
		toggle_pause()
		get_viewport().set_input_as_handled()


## True when the scene of a screen exists.
func has_screen(screen: StringName) -> bool:
	return ResourceLoader.exists(SCREEN_DIR + String(screen) + ".tscn")


## True when this build can show gameplay: the world module's level scene exists, or (development only) the
## debug level. A release export without the level scene has none.
func has_gameplay() -> bool:
	return not _level_scene_path().is_empty()


## Show a screen of SCREEN_DIR. Falls back to the placeholder main scene when it does not exist.
func goto_screen(screen: StringName, transition: int = Defs.Transition.FADE, p_args: Dictionary = {}) -> void:
	if has_screen(screen):
		_change_scene(SCREEN_DIR + String(screen) + ".tscn", screen, transition, p_args)
	else:
		var notice: Dictionary = p_args.duplicate()
		notice["missing_screen"] = String(screen)
		_change_scene(MAIN_SCENE, SCREEN_BOOT, transition, notice)


## Title screen (also the target of "quit to title" and of the end of a run).
func goto_title() -> void:
	Audio.stop_all_sfx()
	goto_screen(SCREEN_TITLE)


## Start a new run at the first campaign level (GAMEPLAY.md 11.1 steps 5-7).
func start_new_game(difficulty: int) -> void:
	Game.new_game(difficulty)
	Settings.set_value("game/last_difficulty", difficulty)
	var first: StringName = Levels.first_level()
	if first == &"":
		push_warning("Flow: no campaign level found in %s" % Levels.LEVEL_DIR)
		goto_screen(SCREEN_TITLE)
		return
	show_world_map(first)


## Start a new run at a later level (level select / code entry). Score and lives start fresh.
func continue_game(level_id: StringName, difficulty: int) -> void:
	Game.new_game(difficulty)
	show_world_map(level_id)


## Show the world map with the marker on `level_id`; the map screen calls start_level(args["level_id"]) when
## it is done. Without a map screen the level starts directly.
func show_world_map(level_id: StringName) -> void:
	if has_screen(SCREEN_WORLD_MAP):
		goto_screen(SCREEN_WORLD_MAP, Defs.Transition.FADE, {"level_id": level_id})
	else:
		start_level(level_id)


## Load a level. `carry_progress` keeps completion counters and the tally list (linked sub-stage, bonus stage).
func start_level(level_id: StringName, transition: int = Defs.Transition.CURTAIN, carry_progress: bool = false) -> void:
	if busy:
		return
	if not Levels.has_level(level_id):
		push_error("Flow.start_level: unknown level '%s'" % level_id)
		return
	var scene: String = _level_scene_path()
	if scene.is_empty():
		push_error("Flow.start_level: this build has no gameplay scene (%s)" % LEVEL_SCENE)
		return
	pending_level_id = level_id
	Game.begin_level(level_id, carry_progress)
	_change_scene(scene, SCREEN_LEVEL, transition, {"level_id": level_id})


## Reload the current level from its start (pause menu "restart level"). The run goes back to its state at the
## level entry (Game.restore_level_entry): the restart costs nothing and earns nothing, so the level's items, which
## all reappear, cannot be collected twice. A hero whose death toss is still playing has lost that life: it is
## paid first, and on the last life the run ends (game over) instead. Ignored while a transition runs.
func restart_level() -> void:
	if Game.level_id == &"" or busy:
		return
	var level: LevelBase = Game.level
	if level != null and level.player != null and level.player.dead and not level.completed:
		if not Game.lose_life():
			Sim.stop()
			game_over()
			return
	# A restored entry state already holds the counters the level started with (a linked sub-stage or bonus stage
	# carries its source level's progress): keep them.
	var restored: bool = Game.restore_level_entry()
	start_level(Game.level_id, Defs.Transition.CURTAIN, restored)


## Called by the level when the hero reaches an exit. `exit_kind`: &"exit", &"warp" or &"trophy"
## (route logic of GAMEPLAY.md 1.1).
func complete_level(exit_kind: StringName) -> void:
	if busy:
		return
	var level_id: StringName = Game.level_id
	var difficulty: int = Game.difficulty
	Events.level_completed.emit(level_id, exit_kind)
	var kind: String = str(Levels.get_value(level_id, "kind", Levels.KIND_MAIN))
	if exit_kind == &"warp" and kind != Levels.KIND_BONUS:
		# Warp item in a main level: straight into its bonus stage, no tally, progress carried over.
		var bonus: StringName = StringName(str(Levels.get_value(level_id, "bonus", "", difficulty)))
		if bonus != &"" and Levels.has_level(bonus):
			Game.warp_return_level = level_id
			start_level(bonus, Defs.Transition.CURTAIN, true)
			return
	if exit_kind == &"exit" and not bool(Levels.get_value(level_id, "tally", true, difficulty)):
		# First half of a linked pair: continue in the sub-stage without a tally.
		var linked: StringName = Levels.next_level(level_id, difficulty)
		if linked != &"":
			start_level(linked, Defs.Transition.CURTAIN, true)
			return
	if exit_kind == &"trophy":
		var epilogue: StringName = Levels.next_level(level_id, difficulty)
		if epilogue != &"":
			start_level(epilogue, Defs.Transition.CURTAIN, false)
			return
	if has_screen(SCREEN_TALLY):
		goto_screen(SCREEN_TALLY, Defs.Transition.IRIS, {
			"level_id": level_id, "percent": Game.completion_percent(),
		})
	else:
		finish_tally()


## Called by the tally screen when it is done: records the result, unlocks and enters the next level.
func finish_tally() -> void:
	var finished: StringName = Game.level_id
	var difficulty: int = Game.difficulty
	# A bonus stage ends its SOURCE level (GAMEPLAY.md 1.1).
	if Game.warp_return_level != &"":
		finished = Game.warp_return_level
		Game.warp_return_level = &""
	Save.record_level_result(finished, difficulty, Game.score, Game.completion_percent())
	Game.clear_tally()
	var kind: String = str(Levels.get_value(finished, "kind", Levels.KIND_MAIN))
	var next: StringName = Levels.next_level(finished, difficulty)
	if kind == Levels.KIND_ENDING or (next == &"" and not Levels.has_locked_successor(finished, difficulty)):
		Save.set_game_completed(difficulty)
		Save.submit_score(Game.score)
		Save.save_game()
		goto_screen(SCREEN_THE_END)
		return
	if next == &"":
		Save.submit_score(Game.score)
		Save.save_game()
		goto_screen(SCREEN_EXPERT_WALL)
		return
	Save.unlock_level(next, difficulty)
	Save.save_game()
	show_world_map(next)


## No lives left (GAMEPLAY.md 11.1 step 9: after the death toss the curtain closes on the level).
func game_over() -> void:
	Save.submit_score(Game.score)
	Save.save_game()
	Events.game_over.emit()
	goto_screen(SCREEN_GAME_OVER, Defs.Transition.CURTAIN)


## Pause or resume gameplay. Only has an effect while a level is active.
func set_paused(paused: bool) -> void:
	if current_screen != SCREEN_LEVEL or get_tree().paused == paused:
		return
	get_tree().paused = paused
	Audio.play_sfx(Sfx.PAUSE_IN if paused else Sfx.PAUSE_OUT)
	Events.pause_changed.emit(paused)


func toggle_pause() -> void:
	set_paused(not get_tree().paused)


func is_paused() -> bool:
	return get_tree().paused


## Hide the screen with a transition, call `action` while nothing is visible, then uncover again - without
## changing the scene. For everything that moves the hero behind a curtain: gates, the respawn after a death,
## warps inside a level. Await it to continue after the screen is uncovered.
##
## The simulation stands still (Sim.frozen) from the end of the current tick until the screen is uncovered, and
## device input is ignored meanwhile, so the call may come from inside a tick and `action` always runs between
## two ticks. `action` may start a scene change itself (Flow.game_over(), Flow.start_level()): that transition
## then takes over the cover. The request is ignored while [member busy].
func play_covered(action: Callable, transition: int = Defs.Transition.CURTAIN) -> void:
	if busy:
		return
	busy = true
	_transition_serial += 1
	var serial: int = _transition_serial
	GameInput.enabled = false
	if Sim.is_in_tick():
		await Sim.tick_finished
	Sim.frozen = true
	await _animate_cover(1.0, transition)
	# A scene change requested by the action must not be refused as "busy".
	busy = false
	if action.is_valid():
		action.call()
	if serial != _transition_serial:
		# The action started a scene change: it owns the cover, the clock and the input from here on.
		return
	busy = true
	await _animate_cover(0.0, transition)
	Sim.frozen = false
	GameInput.enabled = true
	busy = false
	_pause_if_inactive()


## The node that draws the transitions (read-only for everybody but Flow; tests and debug overlays look at it).
func get_transition_cover() -> TransitionCover:
	return _cover


## Leave the application (desktop). On mobile the OS decides; this only returns to the title.
func quit_game() -> void:
	if OS.has_feature("mobile") or OS.has_feature("web"):
		Settings.save()
		goto_title()
		return
	shutdown_and_quit(0)


## Leave the application cleanly: save settings, stop the simulation, release audio (the audio thread needs a
## moment to let go of its playbacks), then quit with `exit_code`. Every code path that quits goes through here.
func shutdown_and_quit(exit_code: int = 0) -> void:
	if _quitting:
		return
	_quitting = true
	busy = true
	Settings.save()
	Sim.stop()
	Audio.shutdown()
	await get_tree().create_timer(0.25, true, false, true).timeout
	get_tree().quit(exit_code)


## CanvasLayer for HUD (Defs.LAYER_HUD), touch controls (LAYER_TOUCH) or menus (LAYER_MENU).
func get_overlay(layer: int) -> CanvasLayer:
	match layer:
		Defs.LAYER_HUD:
			return _overlay_hud
		Defs.LAYER_TOUCH:
			return _overlay_touch
		_:
			return _overlay_menu


func _make_overlay(layer: int) -> CanvasLayer:
	var overlay: CanvasLayer = CanvasLayer.new()
	overlay.layer = layer
	add_child(overlay)
	return overlay


func _clear_overlays() -> void:
	for overlay: CanvasLayer in [_overlay_hud, _overlay_touch, _overlay_menu]:
		for child: Node in overlay.get_children():
			child.queue_free()


func _fill_overlays() -> void:
	_add_overlay_scene(HUD_SCENE, _overlay_hud)
	_add_overlay_scene(TOUCH_SCENE, _overlay_touch)
	_add_overlay_scene(PAUSE_SCENE, _overlay_menu)


func _add_overlay_scene(path: String, overlay: CanvasLayer) -> void:
	if not ResourceLoader.exists(path):
		return
	var scene: PackedScene = load(path) as PackedScene
	if scene != null:
		overlay.add_child(scene.instantiate())


func _change_scene(path: String, screen: StringName, transition: int, p_args: Dictionary) -> void:
	if busy:
		return
	busy = true
	_transition_serial += 1
	GameInput.enabled = false
	# The old scene stays alive while the cover closes (the exit animation plays under the iris).
	await _animate_cover(1.0, transition)
	transition_covered.emit()
	get_tree().paused = false
	Sim.stop()
	# A new level starts its clock in _ready, but its first tick waits until the player can see it.
	Sim.frozen = true
	Audio.stop_all_loops()
	_clear_overlays()
	args = p_args
	current_screen = screen
	var err: Error = get_tree().change_scene_to_file(path)
	if err != OK:
		push_error("Flow: cannot change to %s (error %d)" % [path, err])
	# The new scene is attached at the end of this frame.
	await get_tree().process_frame
	await get_tree().process_frame
	if screen == SCREEN_LEVEL:
		_fill_overlays()
	GameInput.enabled = true
	screen_changed.emit(screen)
	await _animate_cover(0.0, transition)
	Sim.frozen = false
	busy = false
	_pause_if_inactive()
	transition_finished.emit()


## Gameplay scene of this build: the world module's level, else the debug level (development only: exports do
## not contain it), else "".
func _level_scene_path() -> String:
	if ResourceLoader.exists(LEVEL_SCENE):
		return LEVEL_SCENE
	if ResourceLoader.exists(DEBUG_LEVEL_SCENE):
		return DEBUG_LEVEL_SCENE
	return ""


## Move the cover to `target` (1 = everything hidden, 0 = everything visible) with the shape of `transition`.
func _animate_cover(target: float, transition: int) -> void:
	if _cover_tween != null and _cover_tween.is_valid():
		_cover_tween.kill()
	set_process(false)
	var shape: int = Defs.Transition.FADE if transition == Defs.Transition.NONE else transition
	var closing: bool = target > _cover.amount
	_cover.shape = shape
	if is_equal_approx(_cover.amount, target):
		# Already there: a covered action handed its fully covered screen over to a scene change.
		return
	_cover.focus = _transition_focus(shape)
	if instant_transitions or transition == Defs.Transition.NONE:
		_cover.amount = target
		return
	var speed: float = maxf(transition_speed, 0.01)
	_cover_tween = create_tween()
	_cover_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	match shape:
		Defs.Transition.CURTAIN:
			_cover_tween.tween_property(_cover, "amount", target, CURTAIN_SECONDS / speed)
		Defs.Transition.IRIS:
			if closing:
				# Close in on the hero, rest as a spotlight, then shut. The hero may still move: follow him.
				set_process(true)
				var spotlight: float = maxf(_cover.amount_for_opening(IRIS_HOLD_RADIUS), _cover.amount)
				_cover_tween.tween_property(_cover, "amount", spotlight, IRIS_SECONDS / speed)
				_cover_tween.tween_interval(IRIS_HOLD_SECONDS / speed)
				_cover_tween.tween_property(_cover, "amount", target, IRIS_SHUT_SECONDS / speed)
			else:
				_cover_tween.tween_property(_cover, "amount", target, IRIS_SECONDS / speed)
		_:
			_cover_tween.tween_property(_cover, "amount", target, FADE_SECONDS / speed)
	await _cover_tween.finished
	set_process(false)


## Where a transition is centred, in viewport px: the middle of the hero for the iris (when a level with a hero
## is on screen), otherwise the middle of the screen.
func _transition_focus(shape: int) -> Vector2:
	var centre: Vector2 = _cover.size * 0.5
	if shape != Defs.Transition.IRIS:
		return centre
	var level: LevelBase = Game.level
	if level == null or level.player == null or not level.player.is_inside_tree():
		return centre
	var hero: PlayerBase = level.player
	var at: Vector2 = hero.get_global_transform_with_canvas().origin
	at.y -= float(hero.box_h * Tuning.ART_SCALE) * 0.5
	return at.clamp(Vector2.ZERO, _cover.size)


## The application gained or lost the foreground (window focus and "resumed" state together).
func _update_app_active() -> void:
	var active: bool = _app_focused and _app_resumed
	if active == _app_active:
		return
	_app_active = active
	if not pause_on_focus_loss:
		return
	# Suspend first: the pause cue must not wait in a paused voice for the player to come back.
	Audio.set_suspended(not active)
	_pause_if_inactive()


## Gameplay never runs while the player cannot see it. Resuming is the player's decision (pause menu).
func _pause_if_inactive() -> void:
	if pause_on_focus_loss and not _app_active and not busy:
		set_paused(true)


## Deliver one press and release of `ui_cancel` to the focused screen.
func _send_cancel_action() -> void:
	for pressed: bool in [true, false]:
		var event: InputEventAction = InputEventAction.new()
		event.action = &"ui_cancel"
		event.pressed = pressed
		Input.parse_input_event(event)
