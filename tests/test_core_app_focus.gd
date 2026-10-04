extends TestCase
## Application focus / background handling: gameplay pauses, sound is suspended, touch is released, settings are
## written; the Android back gesture pauses or cancels. The notifications are delivered by hand.


## Records ui_cancel presses that reach the scene tree.
class CancelProbe:
	extends Node

	var presses: int = 0

	func _init() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS

	func _input(event: InputEvent) -> void:
		if event.is_action_pressed(&"ui_cancel"):
			presses += 1


var _pauses: Array[bool] = []


func before_each() -> void:
	_pauses.clear()
	Events.pause_changed.connect(_on_pause_changed)


func after_each() -> void:
	Events.pause_changed.disconnect(_on_pause_changed)
	_deliver(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	_deliver(Node.NOTIFICATION_APPLICATION_RESUMED)
	Flow.pause_on_focus_loss = true
	get_tree().paused = false
	Audio.set_suspended(false)


func _on_pause_changed(paused: bool) -> void:
	_pauses.append(paused)


## Deliver an application notification the way the engine does: to every node that cares.
func _deliver(what: int) -> void:
	for node: Node in [Flow, GameInput, Sim]:
		node.notification(what)


func _enter_level() -> void:
	Game.new_game(Defs.Difficulty.BEGINNER)
	Flow.start_level(&"test_example", Defs.Transition.NONE)
	await Flow.transition_finished


func _leave_level() -> void:
	get_tree().paused = false
	Sim.stop()
	if get_tree().current_scene != null:
		get_tree().current_scene.queue_free()
		get_tree().current_scene = null
	Flow.current_screen = Flow.SCREEN_BOOT
	await get_tree().process_frame


func test_losing_focus_pauses_gameplay_and_suspends_sound() -> void:
	await _enter_level()
	GameInput.set_touch(Defs.ACT_RIGHT, true)
	_deliver(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	assert_true(Flow.is_paused(), "gameplay never runs unseen")
	assert_eq(_pauses, [true] as Array[bool], "the pause menu is told")
	assert_true(Audio.is_suspended())
	Sim.step(1)
	assert_eq(GameInput.flags, 0, "a finger that was down when the app lost focus is released")
	_deliver(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	assert_false(Audio.is_suspended(), "sound comes back with the focus")
	assert_true(Flow.is_paused(), "resuming the game is the player's decision")
	await _leave_level()


func test_background_needs_both_resume_and_focus() -> void:
	await _enter_level()
	if FileAccess.file_exists(Settings.storage_dir + Settings.FILE_NAME):
		DirAccess.remove_absolute(Settings.storage_dir + Settings.FILE_NAME)
	_deliver(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	_deliver(Node.NOTIFICATION_APPLICATION_PAUSED)
	assert_true(FileAccess.file_exists(Settings.storage_dir + Settings.FILE_NAME),
		"settings are written before the OS may kill the app")
	_deliver(Node.NOTIFICATION_APPLICATION_RESUMED)
	assert_true(Audio.is_suspended(), "resumed but not focused yet")
	_deliver(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	assert_false(Audio.is_suspended())
	assert_eq(_pauses, [true] as Array[bool], "one pause, no automatic resume")
	await _leave_level()


func test_focus_loss_outside_gameplay_only_suspends_sound() -> void:
	assert_ne(Flow.current_screen, Flow.SCREEN_LEVEL)
	_deliver(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	assert_true(Audio.is_suspended())
	assert_false(get_tree().paused, "menus are not paused")
	assert_true(_pauses.is_empty())
	_deliver(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	assert_false(Audio.is_suspended())


func test_focus_handling_can_be_switched_off() -> void:
	Flow.pause_on_focus_loss = false
	await _enter_level()
	_deliver(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	assert_false(Flow.is_paused(), "the autoplay harness keeps running without focus")
	assert_false(Audio.is_suspended())
	_deliver(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	await _leave_level()


func test_back_gesture_pauses_then_cancels() -> void:
	var probe: CancelProbe = CancelProbe.new()
	add_node(probe)
	await _enter_level()
	Flow.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	assert_true(Flow.is_paused(), "back pauses running gameplay")
	Input.flush_buffered_events()
	assert_eq(probe.presses, 0)
	Flow.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	Input.flush_buffered_events()
	# The pause menu (ui module) may take that cancel as "resume"; Flow itself does not unpause.
	assert_eq(probe.presses, 1, "while paused, back is 'cancel' for the pause menu")
	await _leave_level()
	Flow.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	Input.flush_buffered_events()
	assert_eq(probe.presses, 2, "in menus, back is 'cancel'")
