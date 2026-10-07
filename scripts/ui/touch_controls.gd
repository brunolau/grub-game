class_name TouchControls
extends Control
## On-screen controls for touch screens (docs/ARCHITECTURE.md 8.6): a d-pad (left, down, right, up) and the
## jump, attack and look stones from `ui/touch_buttons.png`, plus the pause stone (`ui/touch_pause.png`).
##
## Owner: ui-B. Multi-touch: every finger is tracked on its own and may slide from one button to its neighbour.
## Buttons feed the game through `GameInput.set_touch_slot(slot, Defs.ACT_*, pressed)`; the pause stone calls
## `Flow.toggle_pause()`. Shown while `GameInput.wants_touch_controls()` (or a player slot reads touch) and the game is
## not paused; size, opacity and a mirrored (left-handed) layout come from the settings. Everything stays inside the
## safe area.
##
## 2.0 (DESIGN.md C.1 / D.11): the spare Y stone (cells 7 / 15) is Swap, shown wherever the belt counts (a Book II or
## co-op stage, versus; never in Book I solo, whose overlay stays the 1.0 one). Every player slot whose input is
## TOUCH (GameInput.slots, InputSlot.touch(region)) gets its own cluster inside its screen region, feeding its own
## slot; without a touch slot (single-player) the one overlay feeds slot 0 as in 1.0. **Table mode** (experimental,
## hidden: cut list 2 / G37 - offered only behind the developer switch of [method table_mode_switched_on]; the tablet
## prototype of D.11): two touch slots on one tablet lying between two players - P1's cluster along the
## bottom edge, P2's turned half a circle along the top edge (so it is upright for the player across the table), each
## tinted in its player's colour; one pause stone at the left edge. [method table_regions] gives the join panel the
## two regions to assign.

## One on-screen button.
class Pad:
	extends RefCounted
	## Game action (Defs.ACT_*), or Defs.ACT_PAUSE for the pause stone.
	var action: StringName = &""
	## Cell of touch_buttons.png (the pressed look is cell + 8); -1 = the pause stone.
	var cell: int = 0
	## Screen rectangle (art px).
	var rect: Rect2 = Rect2()
	## Group of buttons a finger may slide across (slot * 4 + 0 = d-pad, + 1 = action stones; PAUSE_CLUSTER).
	var cluster: int = 0
	## Player slot the button feeds.
	var slot: int = 0
	## Drawn turned half a circle (the far player of table mode).
	var flipped: bool = false
	## Tint of the stone (table mode: the player's colour).
	var tint: Color = Color.WHITE
	## Fingers currently on the button.
	var fingers: PackedInt32Array = PackedInt32Array()

	func _init(p_action: StringName, p_cell: int, p_cluster: int, p_slot: int = 0) -> void:
		action = p_action
		cell = p_cell
		cluster = p_cluster
		slot = p_slot

	func is_held() -> bool:
		return not fingers.is_empty()


const BUTTON_SIZE: float = 56.0
const GAP: float = 4.0
const HIT_GROW: float = 6.0
const PAUSE_TOP: float = 52.0        ## below the bonus letters of the HUD
const PRESSED_OFFSET: int = 8
const SHEET: String = "res://assets/ui/touch_buttons.png"
const PAUSE_TEXTURE: String = "res://assets/ui/touch_pause.png"
const CELL: Vector2i = Vector2i(56, 56)
const KEY_LAYOUT: String = "controls/touch_layout"
## The Y stone of touch_buttons.png: Swap (DESIGN.md C.1).
const SWAP_CELL: int = 7
## Cluster of the pause stone.
const PAUSE_CLUSTER: int = 99
## How strongly table mode tints a player's stones with his colour.
const TABLE_TINT: float = 0.45
## Smallest screen (inches across) that offers table mode (DESIGN.md D.11: tablets of 9 inches or more).
const TABLE_MIN_INCHES: float = 9.0
## Developer switch of the table-mode prototype (debug builds only; see [method table_mode_switched_on]).
static var experimental_table_mode: bool = false

## True while the overlay shows two (or more) touch players: table mode.
var table_mode: bool = false

var _pads: Array[Pad] = []
var _finger_pad: Dictionary = {}     # finger index -> Pad
var _sheet: Texture2D = null
var _pause_texture: Texture2D = null
var _paused: bool = false
var _touch_slots: PackedInt32Array = PackedInt32Array()


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_sheet = UiKit.tex(SHEET)
	_pause_texture = UiKit.tex(PAUSE_TEXTURE)
	_build_pads()


func _ready() -> void:
	add_to_group(Defs.GROUP_TOUCH)
	GameInput.device_changed.connect(_on_device_changed)
	GameInput.slot_device_changed.connect(_on_slot_device_changed)
	Settings.changed.connect(_on_setting_changed)
	Events.pause_changed.connect(_on_pause_changed)
	Events.level_started.connect(_on_level_started)
	Game.run_started.connect(_on_run_started)
	resized.connect(layout)
	get_viewport().size_changed.connect(layout)
	_paused = get_tree().paused
	refresh_slots()


func _exit_tree() -> void:
	release_all()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	var touch: InputEventScreenTouch = event as InputEventScreenTouch
	if touch != null:
		if touch.pressed:
			var pad: Pad = _pad_at(touch.position, -1)
			if pad != null:
				_assign(touch.index, pad)
				get_viewport().set_input_as_handled()
		elif _finger_pad.has(touch.index):
			_assign(touch.index, null)
			get_viewport().set_input_as_handled()
		return
	var drag: InputEventScreenDrag = event as InputEventScreenDrag
	if drag != null and _finger_pad.has(drag.index):
		var current: Pad = _finger_pad[drag.index]
		if current.cluster == PAUSE_CLUSTER:
			return
		var target: Pad = _pad_at(drag.position, current.cluster)
		if target != current:
			_assign(drag.index, target)
		get_viewport().set_input_as_handled()


func _draw() -> void:
	var scale_factor: float = _scale()
	for pad: Pad in _pads:
		if pad.rect.size == Vector2.ZERO:
			continue
		if pad.cell < 0:
			if _pause_texture != null:
				draw_texture_rect(_pause_texture, pad.rect, false,
						Color(0.8, 0.8, 0.8) if pad.is_held() else Color.WHITE)
			_draw_pause_bars(pad.rect, scale_factor)
			continue
		if _sheet == null:
			continue
		var index: int = pad.cell + (PRESSED_OFFSET if pad.is_held() else 0)
		var source: Rect2 = Rect2(float((index % 8) * CELL.x), float((index / 8) * CELL.y), float(CELL.x),
				float(CELL.y))
		var target: Rect2 = pad.rect
		if pad.is_held():
			target.position.y += roundf(2.0 * scale_factor) * (-1.0 if pad.flipped else 1.0)
		if pad.flipped:
			# Turned half a circle about the stone's centre: upright for the player across the table.
			draw_set_transform(target.get_center(), PI, Vector2.ONE)
			draw_texture_rect_region(_sheet, Rect2(-target.size * 0.5, target.size), source, pad.tint)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		else:
			draw_texture_rect_region(_sheet, target, source, pad.tint)


## Read the player slots again (GameInput.slots): one cluster per touch slot, or the 1.0 overlay for slot 0.
func refresh_slots() -> void:
	var slots: PackedInt32Array = PackedInt32Array()
	for slot: int in Defs.MAX_PLAYERS:
		if GameInput.get_slot(slot).kind == Defs.InputSlotKind.TOUCH:
			slots.append(slot)
	if slots != _touch_slots or _pads.is_empty():
		release_all()
		_touch_slots = slots
		_build_pads()
	layout()
	_update_visibility()


## Place the buttons for the current view, safe area, size setting and layout.
func layout() -> void:
	var margins: Vector4i = UiKit.safe_margins(get_viewport())
	var view: Vector2 = size
	var safe: Rect2 = Rect2(float(margins.x), float(margins.y), view.x - float(margins.x + margins.z),
			view.y - float(margins.y + margins.w))
	var unit: float = roundf(BUTTON_SIZE * _scale())
	var swap_shown: bool = swap_wanted()
	table_mode = _touch_slots.size() >= 2
	if _touch_slots.size() <= 1:
		var slot: int = _touch_slots[0] if _touch_slots.size() == 1 else 0
		var region: Rect2 = _region_of(slot, safe)
		_layout_cluster(slot, region, false, unit, swap_shown, Color.WHITE)
		var swapped: bool = str(Settings.get_value(KEY_LAYOUT, "standard")) == "swapped"
		var pause_x: float = safe.position.x if swapped else safe.end.x - unit
		_place(_pause_pad(), Vector2(pause_x, safe.position.y + roundf(PAUSE_TOP * _scale())), unit)
	else:
		for i: int in _touch_slots.size():
			var slot: int = _touch_slots[i]
			var tint: Color = Color.WHITE.lerp(UiPlayers.colour(slot), TABLE_TINT)
			_layout_cluster(slot, _region_of(slot, safe), i % 2 == 1, unit, swap_shown, tint)
		_place(_pause_pad(), Vector2(safe.position.x, roundf(safe.get_center().y - unit * 0.5)), unit)
	modulate.a = clampf(Settings.get_float("controls/touch_opacity"), 0.1, 1.0)
	queue_redraw()


## True when the Swap stone belongs on the overlay: the belt counts in the level being played (`belt = fresh`: Book II
## and co-op stages) or the run is a party (co-op, versus). Book I solo ignores Swap (DESIGN.md C.1 rule 7).
static func swap_wanted() -> bool:
	if Game.mode != Defs.GameMode.SINGLE:
		return true
	if Game.level_id == &"" or not Levels.has_level(Game.level_id):
		return false
	return Levels.get_belt_rule(Game.level_id, Game.difficulty) == LevelText.BELT_FRESH


## The two screen regions (fractions of the view) of table mode, for InputSlot.touch(): P1 the bottom half, P2 the
## top half.
static func table_regions() -> Array[Rect2]:
	return [Rect2(0.0, 0.5, 1.0, 0.5), Rect2(0.0, 0.0, 1.0, 0.5)]


## True when the join panel and the versus lobby offer table mode: only behind the developer switch (cut list 2 APPLIED,
## DESIGN.md G37: the tablet table mode stays an experimental, hidden prototype - touch play is one touch player plus
## pads) and then on a screen large enough for it (DESIGN.md D.11: 9 inches or more across).
static func table_mode_available() -> bool:
	if not table_mode_switched_on():
		return false
	if not DisplayServer.is_touchscreen_available():
		return false
	var dpi: int = DisplayServer.screen_get_dpi()
	if dpi <= 0:
		return false
	var pixels: Vector2 = Vector2(DisplayServer.screen_get_size())
	return pixels.length() / float(dpi) >= TABLE_MIN_INCHES


## The developer switch of the table-mode prototype: [member experimental_table_mode] (tests, previews), or the user
## argument `--table-mode` of a debug build. Never on in a release build.
static func table_mode_switched_on() -> bool:
	if not OS.is_debug_build():
		return false
	return experimental_table_mode or OS.get_cmdline_user_args().has("--table-mode")


## Screen rectangle of the button of `action` of player slot `slot` (empty when there is none or it is hidden). The
## pause stone answers for every slot.
func get_button_rect(action: StringName, slot: int = -1) -> Rect2:
	var pad: Pad = _find(action, slot)
	return pad.rect if pad != null else Rect2()


## True while at least one finger holds the button of `action` (of player slot `slot`; -1 = any).
func is_button_held(action: StringName, slot: int = -1) -> bool:
	var pad: Pad = _find(action, slot)
	return pad != null and pad.is_held()


## True when the button of `action` of `slot` is drawn turned for the player across the table.
func is_button_flipped(action: StringName, slot: int = -1) -> bool:
	var pad: Pad = _find(action, slot)
	return pad != null and pad.flipped


## Lift every finger (overlay hidden, game paused, scene left).
func release_all() -> void:
	for finger: int in _finger_pad.keys():
		_assign(finger, null)
	_finger_pad.clear()
	GameInput.clear_touch()


func _build_pads() -> void:
	_pads.clear()
	var slots: PackedInt32Array = _touch_slots if not _touch_slots.is_empty() else PackedInt32Array([0])
	for slot: int in slots:
		var dpad: int = slot * 4
		_pads.append(Pad.new(Defs.ACT_LEFT, 0, dpad, slot))
		_pads.append(Pad.new(Defs.ACT_DOWN, 3, dpad, slot))
		_pads.append(Pad.new(Defs.ACT_RIGHT, 1, dpad, slot))
		_pads.append(Pad.new(Defs.ACT_UP, 2, dpad, slot))
		_pads.append(Pad.new(Defs.ACT_ATTACK, 5, dpad + 1, slot))
		_pads.append(Pad.new(Defs.ACT_JUMP, 4, dpad + 1, slot))
		_pads.append(Pad.new(Defs.ACT_LOOK, 6, dpad + 1, slot))
		_pads.append(Pad.new(Defs.ACT_SWAP, SWAP_CELL, dpad + 1, slot))
	_pads.append(Pad.new(Defs.ACT_PAUSE, -1, PAUSE_CLUSTER, slots[0]))


## One player's cluster inside `region`: the 1.0 arrangement (d-pad an inverted T on one side, the stones on the
## other, mirrored for the left-handed layout), the Swap stone above Jump; `flipped` turns it half a circle about the
## region's centre (the far player of table mode).
func _layout_cluster(slot: int, region: Rect2, flipped: bool, unit: float, swap_shown: bool, tint: Color) -> void:
	var gap: float = roundf(GAP * _scale())
	var left: float = region.position.x
	var right: float = region.end.x
	var bottom: float = region.end.y
	var swapped: bool = not flipped and str(Settings.get_value(KEY_LAYOUT, "standard")) == "swapped"
	var pad_left: float = right - unit * 3.0 - gap * 2.0 if swapped else left
	var jump_x: float = left if swapped else right - unit
	var attack_x: float = left + unit + gap if swapped else jump_x - unit - gap
	var row: float = bottom - unit
	var jump_y: float = row - roundf(unit * 0.4)
	var spots: Dictionary = {
		Defs.ACT_LEFT: Vector2(pad_left, row),
		Defs.ACT_DOWN: Vector2(pad_left + unit + gap, row),
		Defs.ACT_RIGHT: Vector2(pad_left + (unit + gap) * 2.0, row),
		Defs.ACT_UP: Vector2(pad_left + unit + gap, row - unit - gap),
		Defs.ACT_JUMP: Vector2(jump_x, jump_y),
		Defs.ACT_ATTACK: Vector2(attack_x, row),
		Defs.ACT_LOOK: Vector2(attack_x, row - unit - gap),
		Defs.ACT_SWAP: Vector2(jump_x, jump_y - unit - gap),
	}
	for action: StringName in spots:
		var pad: Pad = _find(action, slot)
		if pad == null:
			continue
		pad.flipped = flipped
		pad.tint = tint
		if action == Defs.ACT_SWAP and not swap_shown:
			pad.rect = Rect2()
			continue
		var pos: Vector2 = spots[action]
		if flipped:
			# Point reflection through the region's centre (the cluster turned half a circle).
			pos = region.position + region.end - pos - Vector2(unit, unit)
		_place(pad, pos, unit)


## The screen rectangle of a touch slot's region inside the safe area (the whole safe area for none).
func _region_of(slot: int, safe: Rect2) -> Rect2:
	var region: Rect2 = GameInput.get_slot(slot).region if slot >= 0 and slot < Defs.MAX_PLAYERS else Rect2()
	if region.size.x <= 0.0 or region.size.y <= 0.0:
		return safe
	return Rect2(safe.position + region.position * safe.size, region.size * safe.size)


func _place(pad: Pad, pos: Vector2, unit: float) -> void:
	if pad != null:
		pad.rect = Rect2(pos.round(), Vector2(unit, unit))


func _pause_pad() -> Pad:
	for pad: Pad in _pads:
		if pad.cluster == PAUSE_CLUSTER:
			return pad
	return null


## The button of `action` (of `slot`; -1 = the first one found); the pause stone for ACT_PAUSE.
func _find(action: StringName, slot: int = -1) -> Pad:
	for pad: Pad in _pads:
		if pad.action == action and (slot < 0 or pad.slot == slot or pad.cluster == PAUSE_CLUSTER):
			return pad
	return null


## Button under `pos` (grown hit boxes); with `cluster` >= 0 only buttons of that cluster count.
func _pad_at(pos: Vector2, cluster: int) -> Pad:
	var best: Pad = null
	var best_distance: float = INF
	for pad: Pad in _pads:
		if cluster >= 0 and pad.cluster != cluster:
			continue
		if pad.rect.size == Vector2.ZERO or not pad.rect.grow(HIT_GROW * _scale()).has_point(pos):
			continue
		var distance: float = pad.rect.get_center().distance_squared_to(pos)
		if distance < best_distance:
			best = pad
			best_distance = distance
	return best


func _assign(finger: int, pad: Pad) -> void:
	var previous: Pad = _finger_pad.get(finger) as Pad
	if previous == pad:
		return
	if previous != null:
		var at: int = previous.fingers.find(finger)
		if at >= 0:
			previous.fingers.remove_at(at)
		if not previous.is_held() and previous.cell >= 0:
			GameInput.set_touch_slot(previous.slot, previous.action, false)
		_finger_pad.erase(finger)
	if pad != null:
		var was_held: bool = pad.is_held()
		pad.fingers.append(finger)
		_finger_pad[finger] = pad
		if not was_held:
			if pad.cell < 0:
				Flow.toggle_pause()
			else:
				GameInput.set_touch_slot(pad.slot, pad.action, true)
				if _touch_slots.is_empty():
					GameInput.vibrate(12, 0.3)
				else:
					GameInput.vibrate_slot(pad.slot, 12, 0.3)
	queue_redraw()


func _scale() -> float:
	return clampf(Settings.get_float("controls/touch_scale"), 0.75, 2.0)


func _update_visibility() -> void:
	var wanted: bool = (GameInput.wants_touch_controls() or not _touch_slots.is_empty()) and not _paused
	if not wanted:
		release_all()
	visible = wanted


func _on_device_changed(_device: int) -> void:
	_update_visibility()


func _on_slot_device_changed(_slot: int, _device: int) -> void:
	refresh_slots()


func _on_pause_changed(paused: bool) -> void:
	_paused = paused
	_update_visibility()


func _on_level_started(_level_id: StringName) -> void:
	refresh_slots()


func _on_run_started(_difficulty: int) -> void:
	refresh_slots()


func _on_setting_changed(key: String, _value: Variant) -> void:
	if key == "controls/touch_always":
		_update_visibility()
	elif key.begins_with("controls/touch_"):
		layout()


## Two bars on the pause stone, so that it reads as "pause" and not as the look button.
func _draw_pause_bars(rect: Rect2, scale_factor: float) -> void:
	var bar: Vector2 = Vector2(roundf(6.0 * scale_factor), roundf(20.0 * scale_factor))
	var gap: float = roundf(6.0 * scale_factor)
	var top: float = roundf(rect.get_center().y - bar.y * 0.5)
	var left: float = roundf(rect.get_center().x - bar.x - gap * 0.5)
	for x: float in [left, left + bar.x + gap]:
		draw_rect(Rect2(Vector2(x, top), bar).grow(2.0), UiKit.COL_INK)
		draw_rect(Rect2(Vector2(x, top), bar), UiKit.COL_CREAM)
