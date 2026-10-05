class_name LevelBase
extends Node2D
## Base class of the gameplay scene root: what every other module may ask the running level.
##
## CONTRACT FILE (docs/ARCHITECTURE.md 3.11). Owner: world (bodies may be extended; public signatures are frozen).
## `res://scenes/world/level.tscn` has a root script that extends this class. A bare LevelBase with a TileGrid is
## already a working, invisible level: tests build one in a few lines (see tests/test_core_level_base.gd).
##
## Everything positional is in logical px (feet points); the level node itself and all entity containers must
## stay at the canvas origin with identity transform, because SimEntity writes `position = sim_pos * ART_SCALE`.

## Gameplay is about to start: the grid is built, the hero is spawned, Sim is started.
signal play_started
## The whole seconds left on the level's time limit changed (only emitted by levels whose `time` is > 0).
signal time_left_changed(seconds: int)

## Id of the level file (name without extension).
var level_id: StringName = &""
## Parsed [meta] section of the level file.
var meta: Dictionary = {}
## Collision grid. Never null once the level is ready.
var grid: TileGrid = TileGrid.new(0, 0)
## The hero (null until spawned).
var player: PlayerBase = null
## Where the hero starts when no checkpoint is active (feet point, logical px).
var start_pos: Vector2i = Vector2i(Tuning.TILE * 2, Tuning.TILE * 2)
## Screen-shake counter of PHYSICS.md 13.3. Write it through request_shake(); the hero decrements it with
## tick_shake_timer() in his timer step.
var shake: int = 0
## Vertical view offset in logical px produced by the shake this tick (0 = none). The camera adds it when drawing.
var shake_offset: int = 0
## Current wind value of PHYSICS.md 13.1 (0 on normal levels). The hero's WIND primitive reads it.
var wind: int = 0
## Bit mask of Defs.SCROLL_* flags.
var scroll_flags: int = 0
## True while the level is dark (GAMEPLAY.md 7.10).
var dark: bool = false
## True once the hero reached an exit; the simulation keeps running for the exit animation only.
var completed: bool = false
## Number of enemies that are awake (EnemyBase keeps it up to date); capped at Tuning.MAX_ACTIVE_ENEMIES.
var active_enemies: int = 0
## Ticks left on the level's time limit (meta key `time`); -1 = the level has no limit. Running out costs a life.
var time_left: int = -1

var _by_kind: Array[Array] = []
var _named: Dictionary = {}
var _camera_locked: bool = false
var _camera_lock_rect: Rect2i = Rect2i()
## Darkness a respawn restores: the state when the active checkpoint was touched, or at the start of play.
var _respawn_dark: bool = false


func _init() -> void:
	for i: int in Defs.KIND_COUNT:
		var list: Array[SimEntity] = []
		_by_kind.append(list)


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_ENTER_TREE:
			add_to_group(Defs.GROUP_LEVEL)
			Game.level = self
			if not Sim.tick_finished.is_connected(_on_tick_finished):
				Sim.tick_finished.connect(_on_tick_finished)
			if not Events.shake_requested.is_connected(request_shake):
				Events.shake_requested.connect(request_shake)
			if not Events.player_death_finished.is_connected(_on_player_death_finished):
				Events.player_death_finished.connect(_on_player_death_finished)
			if not Events.popup_requested.is_connected(_on_popup_requested):
				Events.popup_requested.connect(_on_popup_requested)
			if not Game.checkpoint_changed.is_connected(_on_checkpoint_changed):
				Game.checkpoint_changed.connect(_on_checkpoint_changed)
		NOTIFICATION_EXIT_TREE:
			if Events.popup_requested.is_connected(_on_popup_requested):
				Events.popup_requested.disconnect(_on_popup_requested)
			if Game.checkpoint_changed.is_connected(_on_checkpoint_changed):
				Game.checkpoint_changed.disconnect(_on_checkpoint_changed)
			if Sim.tick_finished.is_connected(_on_tick_finished):
				Sim.tick_finished.disconnect(_on_tick_finished)
			if Events.shake_requested.is_connected(request_shake):
				Events.shake_requested.disconnect(request_shake)
			if Events.player_death_finished.is_connected(_on_player_death_finished):
				Events.player_death_finished.disconnect(_on_player_death_finished)
			if Game.level == self:
				Game.level = null


# =================================================================================================================
# Entity registry
# =================================================================================================================

## Called by SimEntity when it enters the tree. Adds it to the list of its kind and to the name index.
func register_entity(entity: SimEntity) -> void:
	var kind: int = entity.get_kind()
	var list: Array = _by_kind[kind]
	if not list.has(entity):
		list.append(entity)
	if entity.spawn_params.has("name"):
		_named[StringName(str(entity.spawn_params["name"]))] = entity
	if kind == Defs.Kind.PLAYER and entity is PlayerBase:
		player = entity


## Called by SimEntity when it leaves the tree.
func unregister_entity(entity: SimEntity) -> void:
	var list: Array = _by_kind[entity.get_kind()]
	list.erase(entity)
	if entity.spawn_params.has("name"):
		_named.erase(StringName(str(entity.spawn_params["name"])))
	if entity == player:
		player = null


## Live list of the entities of one Defs.Kind, in spawn (slot) order. Do NOT modify it and do not keep it
## across ticks. Iterate by index when the loop body may spawn or free entities.
func get_kind(kind: int) -> Array[SimEntity]:
	return _by_kind[kind]


## Entity whose level-file parameter `name=` equals `entity_name` (null when there is none).
func find_named(entity_name: StringName) -> SimEntity:
	var entity: SimEntity = _named.get(entity_name)
	return entity if is_instance_valid(entity) else null


# =================================================================================================================
# View
# =================================================================================================================

## Visible rectangle of the level in logical px. The world module overrides it with the camera rectangle.
func get_view_rect() -> Rect2i:
	return Rect2i(0, 0, Tuning.VIEW_W, Tuning.VIEW_H)


## Camera cell (column, row) of PHYSICS.md 12: top-left visible tile.
func get_camera_cell() -> Vector2i:
	var view: Rect2i = get_view_rect()
	return Vector2i(view.position.x >> 4, view.position.y >> 4)


## True when the sprite box of `entity`, grown by `margin` px, intersects the view.
func is_in_view(entity: SimEntity, margin: int = 0) -> bool:
	var view: Rect2i = get_view_rect().grow(margin)
	return Overlap.rects(entity.get_box(), view)


## Lock the camera so that it shows exactly `view_px` (boss rooms, single-screen rooms; PHYSICS.md 12.4).
func lock_camera(view_px: Rect2i) -> void:
	_camera_locked = true
	_camera_lock_rect = view_px


## Release a camera lock.
func unlock_camera() -> void:
	_camera_locked = false


## Re-initialise the camera around the hero without scrolling (after a gate, a warp or a respawn; PHYSICS.md 12.5).
## The base implementation has no camera and does nothing.
func snap_camera() -> void:
	pass


## True while the camera is locked; [method get_camera_lock] gives the rectangle.
func is_camera_locked() -> bool:
	return _camera_locked


func get_camera_lock() -> Rect2i:
	return _camera_lock_rect


# =================================================================================================================
# Spawning
# =================================================================================================================

## Spawn an entity by id ("<category>/<name>", see Spawner) with its feet point at `pos` (logical px).
## Returns the node (already in the tree) or null when the scene does not exist.
func spawn(id: StringName, pos: Vector2i, params: Dictionary = {}) -> Node:
	var node: Node = Spawner.instantiate(id)
	if node == null:
		return null
	if node is SimEntity:
		var entity: SimEntity = node
		entity.spawn_setup(pos, params)
	elif node is Node2D:
		var node_2d: Node2D = node
		node_2d.position = Tuning.to_art(Vector2(pos))
	get_container(Spawner.category(id)).add_child(node)
	return node


## Spawn a cosmetic effect ("fx/<name>"). Same as spawn(); exists so call sites read clearly.
func spawn_fx(id: StringName, pos: Vector2i, params: Dictionary = {}) -> Node:
	return spawn(id, pos, params)


## Parent node for a spawned entity of an id category ("enemies", "items", "fx" ...). The world module returns
## its layer containers (ARCHITECTURE.md 5.2); the base implementation returns the level node itself.
func get_container(_category: String) -> Node:
	return self


# =================================================================================================================
# Tiles
# =================================================================================================================

## Replace the tile at a cell by a fixed legend character (TileGrid.CH_*): collision changes at once. The world
## module also updates the visuals (and re-autotiles the neighbours). Used by breakable blocks, rising columns.
func set_cell(col: int, row: int, ch: String) -> void:
	grid.set_char(col, row, ch)


## Fixed legend character at a cell.
func get_cell(col: int, row: int) -> String:
	return grid.get_char(col, row)


## Draw another terrain-atlas tile at a cell without touching collision (-1 = back to the automatic tile).
## Used by hidden spots for their "unopened" / "opened" look. Visual only: the base implementation does nothing.
func set_cell_look(_col: int, _row: int, _atlas_index: int) -> void:
	pass


# =================================================================================================================
# Level-wide effects
# =================================================================================================================

## Start (or strengthen) a screen shake: 4, 7, 8 or 9 (PHYSICS.md 13.3).
func request_shake(amount: int) -> void:
	shake = maxi(shake, amount)


## Step 8i of the hero update: the shake counter decreases by 1 per tick. Called by the hero only.
func tick_shake_timer() -> void:
	if shake > 0:
		shake -= 1


## Switch darkness on or off (fades over Tuning.DARKNESS_FADE_TICKS in the world module).
func set_darkness(p_dark: bool) -> void:
	if dark == p_dark:
		return
	dark = p_dark
	Events.darkness_changed.emit(dark)


## Set the wind value (blizzard script) and tell listeners.
func set_wind(value: int) -> void:
	if wind == value:
		return
	wind = value
	Events.wind_changed.emit(wind)


## Arm the time limit of the level (meta key `time`, in seconds; 0 or less = no limit) and tell listeners
## (Events.time_left_changed always; [signal time_left_changed] only for a real limit). The limit is the whole
## number of ticks that fits into `seconds`, so the display starts at exactly `seconds`.
func set_time_limit(seconds: int) -> void:
	if seconds <= 0:
		time_left = -1
		Events.time_left_changed.emit(-1)
		return
	time_left = floori(float(seconds) * Tuning.TICK_HZ)
	time_left_changed.emit(get_time_left_seconds())
	Events.time_left_changed.emit(get_time_left_seconds())


## One tick of the time limit (phase POST; called by the world module's level). Counts down while the hero is
## alive and the level is not completed, tells listeners when the displayed second changes and kills the hero
## with cause &"time" when it reaches zero.
func tick_time_limit() -> void:
	if time_left <= 0 or completed or player == null or player.dead:
		return
	var before: int = get_time_left_seconds()
	time_left -= 1
	var after: int = get_time_left_seconds()
	if after != before:
		time_left_changed.emit(after)
		Events.time_left_changed.emit(after)
	if time_left == 0:
		player.kill(&"time")


## Whole seconds left on the time limit, rounded up (-1 = the level has no limit). For the HUD.
func get_time_left_seconds() -> int:
	if time_left < 0:
		return -1
	return ceili(Tuning.ticks_to_seconds(time_left))


# =================================================================================================================
# Flow
# =================================================================================================================

## Begin gameplay: start the simulation clock and announce the level.
func start_play(seed_value: int = 1) -> void:
	completed = false
	_respawn_dark = dark
	Sim.start(seed_value)
	Events.level_started.emit(level_id)
	play_started.emit()


## The hero reached an exit (`exit_kind`: &"exit", &"warp", &"trophy"). Hands over to Flow once.
func complete(exit_kind: StringName) -> void:
	if completed:
		return
	completed = true
	Events.exit_reached.emit(exit_kind)
	Flow.complete_level(exit_kind)


## Feet point where the hero (re)appears: the active checkpoint, else the level start.
func get_respawn_pos() -> Vector2i:
	return Game.checkpoint_pos if Game.has_checkpoint else start_pos


## Respawn after a death (PHYSICS.md 10.4 step 3): reset enemies / platforms / columns, put the hero at the
## respawn point with full energy. Collected items and opened spots stay as they are. The darkness goes back to
## what it was when the active checkpoint was touched (at the level start without one), so a checkpoint before a
## `zones/dark` trigger is lit again.
func respawn_player() -> void:
	Game.on_respawn()
	shake = 0
	shake_offset = 0
	unlock_camera()
	if dark != _respawn_dark:
		# Directly, not through set_darkness(): a respawn behind the curtain plays no "lights out" cue.
		dark = _respawn_dark
		Events.darkness_changed.emit(dark)
	reset_entities()
	if player != null:
		player.respawn_at(get_respawn_pos())
	snap_camera()
	Events.level_respawned.emit()


## Call `_on_level_reset()` on every registered entity.
func reset_entities() -> void:
	for list: Array in _by_kind:
		for i: int in range(list.size() - 1, -1, -1):
			var entity: SimEntity = list[i]
			if is_instance_valid(entity):
				entity._on_level_reset()


## Score / multiplier / 1UP / heart pop-ups requested through the event bus become "fx/popup" entities.
func _on_popup_requested(kind: StringName, value: int, pos: Vector2i) -> void:
	if Spawner.exists(&"fx/popup"):
		spawn_fx(&"fx/popup", pos, {"kind": String(kind), "value": value})


## A checkpoint was touched: a respawn there brings back the darkness of this moment.
func _on_checkpoint_changed(_pos: Vector2i) -> void:
	_respawn_dark = dark


## Darkness a respawn would restore now (tests, tools).
func get_respawn_darkness() -> bool:
	return _respawn_dark


func _on_player_death_finished() -> void:
	if Game.lose_life():
		respawn_player()
	else:
		Sim.stop()
		Flow.game_over()


## End of every tick (after phase POST): the screen-shake step 18 of PHYSICS.md 3 and the on_screen flags
## ("drawn in the previous frame") of every entity.
func _on_tick_finished(tick: int) -> void:
	shake_offset = 0
	if shake > 1 and (tick & 1) == 1:
		shake += 1
		shake_offset = shake
		if player != null:
			player.apply_shake_nudge(Tuning.SHAKE_NUDGE)
	var view: Rect2i = get_view_rect()
	for list: Array in _by_kind:
		for entity: SimEntity in list:
			entity.on_screen = Overlap.rects(entity.get_box(), view)
