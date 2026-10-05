class_name SimEntity
extends Node2D
## Base class of everything that takes part in the simulation (hero, enemies, items, platforms, projectiles ...).
##
## CONTRACT FILE (docs/ARCHITECTURE.md 3.1). Owner: core. Public members are frozen.
##
## Model (PHYSICS.md 2, 15.1):
##  - `sim_pos` is the integer FEET POINT (bottom-centre) in logical px; +x right, +y down.
##  - `xvel` / `yvel` are v16 (1/16 px per tick); integrate with Tuning.floor16().
##  - The sprite box used by the overlap test is `box_w` x `box_h` with `box_xo`:
##    left = sim_pos.x - box_xo, top = sim_pos.y - box_h, bottom = sim_pos.y.
##  - `position` (canvas, art px) is written ONLY by this class: every rendered frame it becomes
##    lerp(sim_prev, sim_pos, Sim.alpha) * ART_SCALE, rounded to whole art px. Gameplay code never reads or
##    writes `position` / `global_position`.
##
## Subclass rules:
##  - Override `_sim_phases()` and `_sim_tick(phase)`; do all gameplay there (never in _process / _physics_process).
##  - Registration and interpolation run from `_notification`, which Godot calls on every script level, so
##    subclasses may freely override `_ready`, `_enter_tree`, `_exit_tree` and `_process` without calling super.
##  - Use `teleport()` for any discontinuous move (spawn, respawn, gates) so it is not interpolated.

## Feet point in logical px.
var sim_pos: Vector2i = Vector2i.ZERO
## Feet point at the end of the previous tick (written by Sim at the start of every tick).
var sim_prev: Vector2i = Vector2i.ZERO
## Horizontal velocity, v16.
var xvel: int = 0
## Vertical velocity, v16 (positive = down).
var yvel: int = 0
## +1 = right, -1 = left. Sprites face right in their sheets; flip_h when -1.
var facing: int = 1
## Sprite box width in logical px.
var box_w: int = 16
## Sprite box height in logical px.
var box_h: int = 16
## Distance from the feet point to the box's left edge in logical px (normally box_w / 2).
var box_xo: int = 8
## When false Sim skips `_sim_tick` for this entity (dormant / pooled). Interpolation still runs.
var sim_active: bool = true
## True when the box intersected the camera view at the end of the previous tick ("drawn in the previous
## frame", PHYSICS.md 10.1). Maintained by the level in the CAMERA phase.
var on_screen: bool = false
## Parameters from the level file (legend entry / entity line), exactly as parsed: String keys, Variant values.
var spawn_params: Dictionary = {}
## Where the level file placed this entity (feet point, logical px).
var spawn_pos: Vector2i = Vector2i.ZERO

var _sim_registered: bool = false
## Bookkeeping of Sim (registration order, phases, suspension) and of the level's doze manager. Never touch.
var _sim_serial: int = -1
var _sim_phase_list: PackedInt32Array = PackedInt32Array()
var _sim_suspended: bool = false
var _sim_awake_slot: int = -1
var _doze_slot: int = -1
var _level_awake_slot: int = -1


## Which typed list of the level this entity belongs to. Override in base classes.
func get_kind() -> int:
	return Defs.Kind.OTHER


## Phases (Defs.Phase values) in which `_sim_tick` must be called. Override. Read once, when entering the tree.
func _sim_phases() -> PackedInt32Array:
	return PackedInt32Array()


## One simulation step for `phase`. Override. Integer math only; randomness only from Sim.rng.
func _sim_tick(_phase: int) -> void:
	pass


## Called by the level right after instantiation and BEFORE the node enters the tree.
## Stores the parameters and places the entity. Subclasses override `_apply_params()` instead of this.
func spawn_setup(pos: Vector2i, params: Dictionary) -> void:
	spawn_pos = pos
	spawn_params = params
	if params.has("facing"):
		facing = -1 if str(params["facing"]).begins_with("l") else 1
	teleport(pos)
	_apply_params(params)


## Read level-file parameters into fields. Override; call super first when deriving from a base class.
func _apply_params(_params: Dictionary) -> void:
	pass


## Called by the level when the hero respawns after a death (PHYSICS.md 10.4): enemies and platforms reset,
## collected items and opened spots stay as they are. Override.
func _on_level_reset() -> void:
	pass


# =================================================================================================================
# Dozing (ARCHITECTURE.md 11): far from the hero and the view, an idle entity costs nothing per tick
# =================================================================================================================
# The level's doze manager takes an entity out of the tick (Sim.suspend) while `_can_doze()` holds and its
# `_doze_area()` touches neither the hero's box and feet point grown by Tuning.DOZE_HERO_REACH_PX nor the view
# grown by Tuning.DOZE_VIEW_REACH_PX (decided at the end of every tick, and between ticks when the view or the hero
# moved). It is put back as soon as one of them reaches the area again. The contract an entity signs by overriding
# the two:
#   while `_can_doze()` is true and the area stays that far from the hero and the view, every `_sim_tick` call
#   would change nothing but counters that `_on_doze_wake()` restores; whatever makes that false later (a hit, a
#   reset) calls `_doze_wake_now()` first.
# A dozing entity is never drawn (its on_screen is false), keeps its feet point, and has no interpolation.

## True while the doze manager has this entity out of the tick.
func is_dozing() -> bool:
	return _sim_suspended


## Area (logical px) whose distance to the view and to the hero decides whether this entity may doze; an empty
## rectangle (the default) = it never dozes. Override together with `_can_doze()`.
func _doze_area() -> Rect2i:
	return Rect2i()


## True while this entity is idle in the sense of the doze contract above. Override.
func _can_doze() -> bool:
	return false


## Called right before the entity dozes off (record counters to restore). Override.
func _on_doze() -> void:
	pass


## Called right after the entity woke up (restore counters, refresh the picture). Override.
func _on_doze_wake() -> void:
	pass


## The entity's state changed in a way that may let it doze: the level looks at it again at the next decision.
func _doze_note() -> void:
	if Game.level != null and _sim_registered:
		Game.level.doze_note(self)


## The entity's ticks matter again right now (it was hit, opened, reset): wake it at once, also in the middle of
## a tick (it then runs in every later phase of this tick, as if it had never dozed).
func _doze_wake_now() -> void:
	if _sim_suspended and Game.level != null:
		Game.level.doze_wake(self)


## Box grown to contain the feet point (the overlap test of PHYSICS.md 2.2 compares feet points).
func _doze_box() -> Rect2i:
	return Rect2i(sim_pos, Vector2i.ONE).merge(Rect2i(sim_pos.x - box_xo, sim_pos.y - box_h, maxi(box_w, 1),
			maxi(box_h, 1)))


## Move without interpolation (spawn, respawn, gate travel).
func teleport(pos: Vector2i) -> void:
	sim_pos = pos
	sim_prev = pos
	_update_visual(1.0)


## Left edge of the sprite box.
func box_left() -> int:
	return sim_pos.x - box_xo


## Top edge of the sprite box.
func box_top() -> int:
	return sim_pos.y - box_h


## Sprite box as a rectangle in logical px.
func get_box() -> Rect2i:
	return Rect2i(sim_pos.x - box_xo, sim_pos.y - box_h, box_w, box_h)


## Set the sprite box from a Vector3i(width, height, x_offset), e.g. Tuning.HERO_BOX_STAND.
func set_box(box: Vector3i) -> void:
	box_w = box.x
	box_h = box.y
	box_xo = box.z


## Tile column of the feet point.
func cell_col() -> int:
	return sim_pos.x >> 4


## Tile row of the feet point.
func cell_row() -> int:
	return sim_pos.y >> 4


## Integer parameter from the level file, or `default`.
func param_int(key: String, default: int = 0) -> int:
	return int(spawn_params.get(key, default))


## Boolean parameter (flags written without a value are true).
func param_bool(key: String, default: bool = false) -> bool:
	var value: Variant = spawn_params.get(key, default)
	if value is String:
		return value != "false" and value != "0" and value != ""
	return bool(value)


## String parameter, or `default`.
func param_str(key: String, default: String = "") -> String:
	return str(spawn_params.get(key, default))


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_ENTER_TREE:
			add_to_group(Defs.GROUP_SIM)
			set_process_internal(true)
			if not _sim_registered:
				_sim_registered = true
				Sim.register(self)
				if Game.level != null:
					Game.level.register_entity(self)
			_update_visual(1.0)
		NOTIFICATION_EXIT_TREE:
			if _sim_registered:
				_sim_registered = false
				Sim.unregister(self)
				if Game.level != null:
					Game.level.unregister_entity(self)
		NOTIFICATION_INTERNAL_PROCESS:
			_update_visual(Sim.alpha)


## Place the canvas node between the previous and the current tick position, snapped to whole art px.
func _update_visual(alpha: float) -> void:
	var x: float = lerpf(float(sim_prev.x), float(sim_pos.x), alpha) * Tuning.ART_SCALE
	var y: float = lerpf(float(sim_prev.y), float(sim_pos.y), alpha) * Tuning.ART_SCALE
	position = Vector2(roundf(x), roundf(y))
