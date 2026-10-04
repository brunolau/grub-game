class_name UiScreen
extends Control
## Base class of the ten full-screen ui scenes (docs/ARCHITECTURE.md 3.10, 8.6).
##
## Owner: ui. A screen fills the root viewport whatever its size, keeps everything interactive inside
## [member safe] (display safe area + base margin) and talks to the rest of the game only through `Flow`.
## Subclasses override [method _build_screen] (create the nodes), [method _on_accept], [method _on_cancel] and
## [method _on_tap]; they never override `_ready`.
##
## Input: focusable buttons handle keyboard, gamepad, mouse and touch themselves. Everything they do not consume
## arrives here: "back" (ui_cancel, Android back) calls _on_cancel(), a confirm button calls _on_accept(), a tap
## or click on the backdrop calls _on_tap(). Nothing is accepted while a Flow transition runs or after the
## screen asked to be left.

## Content root inside the safe area: add everything interactive below this node.
var safe: MarginContainer = null
## True once the screen asked Flow to go somewhere else; further input is ignored.
var leaving: bool = false


func _init() -> void:
	UiKit.ensure_locale()
	theme = UiKit.theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE


func _ready() -> void:
	safe = MarginContainer.new()
	safe.name = "Safe"
	safe.set_anchors_preset(Control.PRESET_FULL_RECT)
	safe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_screen()
	# Backdrops are added by _build_screen; the safe-area content always sits on top of them.
	add_child(safe)
	UiKit.apply_safe_margins(safe)
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	_screen_ready()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and is_accepting_input():
		_on_cancel()


func _unhandled_input(event: InputEvent) -> void:
	if not is_accepting_input():
		return
	if UiKit.is_cancel(event):
		get_viewport().set_input_as_handled()
		_on_cancel()
	elif UiKit.is_accept(event) and not UiKit.is_tap(event):
		get_viewport().set_input_as_handled()
		_on_accept()


func _gui_input(event: InputEvent) -> void:
	if UiKit.is_tap(event) and is_accepting_input():
		accept_event()
		_on_tap()


## True while the screen reacts to input: no transition running, not already leaving.
func is_accepting_input() -> bool:
	return not leaving and not Flow.busy and is_inside_tree()


## Leave for another screen (marks the screen as leaving; the request is ignored while Flow is busy).
func go_to(screen: StringName, transition: int = Defs.Transition.FADE, p_args: Dictionary = {}) -> void:
	if not is_accepting_input():
		return
	leaving = true
	Flow.goto_screen(screen, transition, p_args)


## Mark the screen as leaving before calling another Flow method (start_level, finish_tally, ...).
## Returns false when the screen may not leave right now.
func begin_leave() -> bool:
	if not is_accepting_input():
		return false
	leaving = true
	return true


## Create the nodes of the screen. Backdrops go below `self`, interactive content below [member safe].
func _build_screen() -> void:
	pass


## Called once after the tree is complete: start music, take the focus, start animations.
func _screen_ready() -> void:
	pass


## A confirm button was pressed and no control consumed it.
func _on_accept() -> void:
	pass


## "Back" was pressed.
func _on_cancel() -> void:
	pass


## The backdrop was tapped or clicked. By default the same as a confirm button.
func _on_tap() -> void:
	_on_accept()


func _on_viewport_size_changed() -> void:
	UiKit.apply_safe_margins(safe)
