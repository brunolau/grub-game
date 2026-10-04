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
