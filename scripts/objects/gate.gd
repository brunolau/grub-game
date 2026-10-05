class_name Gate
extends SimEntity
## `objects/gate` (GAMEPLAY.md 7.5): a door, cave mouth or secret hole. Standing in front of it and pressing Down
## (the hero crouches, `drop_timer > 0`) starts a journey: Flow closes its curtain and stops the clock
## (Flow.play_covered, ARCHITECTURE.md 3.10), the hero is put at the destination while the screen is covered, then
## the curtain opens again. Not usable while carrying the hang-glider. Two-way travel needs two gates.
##
## Parameters: `name`; `dest=<name of a gate or marker>`; `lock=c,r` camera cell of a single-screen room (the lock
## of the DESTINATION applies on arrival; arriving somewhere without one releases the camera);
## `skin=arch|hole|none` [arch].

const SKINS: Array[String] = ["arch", "hole", "none"]
const TEXTURES: Array[Texture2D] = [
	preload("res://assets/sprites/objects/gate_arch.png"),
	preload("res://assets/sprites/objects/gate_hole.png"),
]
const PIVOTS: Array[Vector2] = [Vector2(40, 63), Vector2(22, 48)]

## Name of the gate or marker it leads to.
var dest: StringName = &""
## True from the hero's request until he stands at the destination (the curtain covers the screen meanwhile).
var travelling: bool = false

var _cell: Vector2i = Vector2i.ZERO
var _target: SimEntity = null
var _warned: bool = false

## Set after a journey until the hero lets go of Down, so that he does not travel straight back.
static var _wait_release: bool = false


func _init() -> void:
	z_index = Defs.Z_OBJECTS
	set_box(Vector3i(24, 32, 12))


func _sim_phases() -> PackedInt32Array:
	return PackedInt32Array([Defs.Phase.WORLD])


func _apply_params(params: Dictionary) -> void:
	dest = StringName(str(params.get("dest", "")))
	_cell = Vector2i(sim_pos.x >> 4, (sim_pos.y - 1) >> 4)
	var skin: int = SKINS.find(str(params.get("skin", SKINS[0])))
	if skin < 0:
		push_warning("objects/gate: unknown skin '%s'" % str(params.get("skin")))
		skin = 0
	var sprite: Sprite2D = get_node_or_null(^"Sprite") as Sprite2D
	if sprite != null:
		sprite.visible = skin < TEXTURES.size()
		if sprite.visible:
			sprite.texture = TEXTURES[skin]
			sprite.offset = -PIVOTS[skin]


func _enter_tree() -> void:
	# A freshly loaded level starts without a pending "let go of Down" from a previous level.
	_wait_release = false


func _sim_tick(_phase: int) -> void:
	var level: LevelBase = Game.level
	if level == null or travelling:
		return
	var hero: PlayerBase = level.player
	if hero != null and _wants_to_enter(hero):
		_begin(hero)


func _on_level_reset() -> void:
	travelling = false
	_wait_release = false


## Dozing (SimEntity, ARCHITECTURE.md 11): a gate that is not in use and does not wait for Down to be released only
## tests whether the hero's feet are in its cell, which they cannot be while he is far.
func _doze_area() -> Rect2i:
	return Rect2i(_cell * Tuning.TILE, Vector2i(Tuning.TILE, Tuning.TILE)).merge(_doze_box())


func _can_doze() -> bool:
	return not travelling and not _wait_release


## True when the hero stands in front of this gate pressing Down, on the ground, without the glider.
func _wants_to_enter(hero: PlayerBase) -> bool:
	if hero.dead or not hero.control_enabled:
		return false
	if hero.drop_timer == 0:
		_wait_release = false
		return false
	if _wait_release or Game.has_glider or not hero.is_grounded():
		return false
	return hero.cell_col() == _cell.x and ((hero.sim_pos.y - 1) >> 4) == _cell.y


func _begin(hero: PlayerBase) -> void:
	var level: LevelBase = Game.level
	_target = level.find_named(dest) if level != null and dest != &"" else null
	if _target == null:
		if not _warned:
			_warned = true
			push_warning("objects/gate '%s': destination '%s' not found" % [param_str("name"), dest])
		return
	_wait_release = true
	travelling = true
	hero.set_control_enabled(false)
	hero.xvel = 0
	if Flow.busy:
		# Another transition owns the cover and cannot wait for a curtain of its own: travel at once.
		_arrive()
	else:
		Flow.play_covered(_arrive, Defs.Transition.CURTAIN)


## Runs between two ticks while the curtain covers the screen.
func _arrive() -> void:
	travelling = false
	var level: LevelBase = Game.level
	var hero: PlayerBase = level.player if level != null else null
	if hero == null or hero.dead:
		return
	hero.set_control_enabled(true)
	if not is_instance_valid(_target):
		return
	var from: Vector2i = hero.sim_pos
	hero.xvel = 0
	hero.yvel = 0
	hero.teleport(_target.sim_pos)
	if _target.spawn_params.has("lock"):
		var lock: PackedInt32Array = LevelText.to_int_list(_target.spawn_params["lock"])
		if lock.size() == 2:
			level.lock_camera(Rect2i(
				lock[0] * Tuning.TILE, lock[1] * Tuning.TILE,
				Tuning.VIEW_COLS * Tuning.TILE, Tuning.VIEW_ROWS * Tuning.TILE
			))
	else:
		level.unlock_camera()
	level.snap_camera()
	Events.gate_used.emit(from, hero.sim_pos)
