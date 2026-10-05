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

## Measurement switch (scripts/core/dev/sim_bench.gd --no-doze): false = no entity ever dozes. Dozing changes no
## outcome; the bench proves it by comparing both.
static var doze_enabled: bool = true

var _by_kind: Array[Array] = []
var _named: Dictionary = {}
var _camera_locked: bool = false
var _camera_lock_rect: Rect2i = Rect2i()
## Darkness a respawn restores: the state when the active checkpoint was touched, or at the start of play.
var _respawn_dark: bool = false
## Registered entities that tick (not dozing), any order: the on_screen pass runs over them.
var _awake: Array[SimEntity] = []
## Doze manager (ARCHITECTURE.md 11, SimEntity "Dozing"): the entities it looks after, their doze areas (4 ints per
## slot: left, top, right, bottom, right exclusive; right <= left = never dozes), whether an area is known, the
## entities whose state changed since the last decision, the bounds of the two doze rectangles of the last full
## pass (view and hero: left, top, right, bottom each), and the view and hero feet point the last decision was
## made for.
var _doze: Array[SimEntity] = []
var _doze_rects: PackedInt32Array = PackedInt32Array()
var _doze_known: PackedByteArray = PackedByteArray()
var _doze_notes: Array[SimEntity] = []
var _dz_view_left: int = 0
var _dz_view_top: int = 0
var _dz_view_right: int = 0
var _dz_view_bottom: int = 0
var _dz_hero_left: int = 0
var _dz_hero_top: int = 0
var _dz_hero_right: int = 0
var _dz_hero_bottom: int = 0
var _doze_full: bool = true
var _doze_view: Rect2i = Rect2i()
## True while the end-of-tick decision runs (right before the on_screen pass). An entity dozing off at any other
## moment keeps its on_screen until the next pass computes it once more (as it would have without dozing).
var _doze_at_tick_end: bool = false
var _doze_screen_pending: Array[SimEntity] = []
var _doze_hero: Vector2i = Vector2i(-1, -1)


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
			if not Sim.tick_started.is_connected(_on_tick_started):
				Sim.tick_started.connect(_on_tick_started)
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
			if Sim.tick_started.is_connected(_on_tick_started):
				Sim.tick_started.disconnect(_on_tick_started)
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
	if entity._level_awake_slot < 0 and not entity._sim_suspended:
		entity._level_awake_slot = _awake.size()
		_awake.append(entity)
	if doze_enabled and kind != Defs.Kind.PLAYER and kind != Defs.Kind.FX and entity._doze_slot < 0:
		entity._doze_slot = _doze.size()
		_doze.append(entity)
		_doze_rects.append_array([0, 0, 0, 0])
		_doze_known.append(0)


## Called by SimEntity when it leaves the tree.
func unregister_entity(entity: SimEntity) -> void:
	var list: Array = _by_kind[entity.get_kind()]
	list.erase(entity)
	if entity.spawn_params.has("name"):
		_named.erase(StringName(str(entity.spawn_params["name"])))
	if entity == player:
		player = null
	_awake_remove(entity)
	var slot: int = entity._doze_slot
	if slot >= 0 and slot < _doze.size() and _doze[slot] == entity:
		# Swap with the last slot (the order of the doze list does not matter).
		var last: int = _doze.size() - 1
		var moved: SimEntity = _doze[last]
		_doze[slot] = moved
		moved._doze_slot = slot
		for j: int in 4:
			_doze_rects[slot * 4 + j] = _doze_rects[last * 4 + j]
		_doze_known[slot] = _doze_known[last]
		_doze.resize(last)
		_doze_rects.resize(last * 4)
		_doze_known.resize(last)
	entity._doze_slot = -1


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
	# The reset moved entities back to their anchors and the hero far away: decide every doze area afresh.
	_doze_full = true
	_doze_known.fill(0)
	_doze_update()
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


## End of every tick (after phase POST): the screen-shake step 18 of PHYSICS.md 3, the doze decisions for the next
## tick, and the on_screen flags ("drawn in the previous frame") of every entity. A dozing entity lies outside the
## doze region, which contains the view: its on_screen stays false (set when it dozed off).
func _on_tick_finished(tick: int) -> void:
	shake_offset = 0
	if shake > 1 and (tick & 1) == 1:
		shake += 1
		shake_offset = shake
		if player != null:
			player.apply_shake_nudge(Tuning.SHAKE_NUDGE)
	if doze_enabled:
		_doze_at_tick_end = true
		_doze_update()
		_doze_at_tick_end = false
	# Overlap.rects(entity.get_box(), view) for every entity, written out: this loop runs over every ticking
	# entity every tick, and the two calls per entity were a large share of the tick on slow devices. The doze
	# decision has just read the view.
	var view: Rect2i = _doze_view if doze_enabled else get_view_rect()
	var left: int = view.position.x
	var right: int = left + view.size.x
	var top: int = view.position.y
	var bottom: int = top + view.size.y
	for entity: SimEntity in _awake:
		var feet: Vector2i = entity.sim_pos
		var box_left: int = feet.x - entity.box_xo
		entity.on_screen = box_left < right and left < box_left + entity.box_w \
				and feet.y - entity.box_h < bottom and top < feet.y
	if not _doze_screen_pending.is_empty():
		for entity: SimEntity in _doze_screen_pending:
			if is_instance_valid(entity) and entity._sim_suspended:
				var feet: Vector2i = entity.sim_pos
				var box_left: int = feet.x - entity.box_xo
				entity.on_screen = box_left < right and left < box_left + entity.box_w \
						and feet.y - entity.box_h < bottom and top < feet.y
		_doze_screen_pending.clear()


## Start of every tick: when the view or the hero moved since the last doze decision (a respawn behind the curtain,
## a resized window), decide again before anything reads them.
func _on_tick_started(_tick: int) -> void:
	if not doze_enabled or _doze.is_empty():
		return
	var hero: Vector2i = player.sim_pos if player != null else Vector2i(-1, -1)
	if hero != _doze_hero or get_view_rect() != _doze_view:
		_doze_update()


# =================================================================================================================
# Doze manager (ARCHITECTURE.md 11; the contract is in SimEntity, "Dozing")
# =================================================================================================================

## An entity's state changed so that it may doze now (or its area moved): look at it at the next decision.
func doze_note(entity: SimEntity) -> void:
	var slot: int = entity._doze_slot
	if slot < 0 or slot >= _doze.size() or _doze[slot] != entity:
		return
	_doze_known[slot] = 0
	_doze_notes.append(entity)


## Wake a dozing entity at once (its ticks matter again; also in the middle of a tick).
func doze_wake(entity: SimEntity) -> void:
	if entity._sim_suspended and entity._doze_slot >= 0:
		_doze_known[entity._doze_slot] = 0
		_doze_wake_entity(entity)


## Number of entities dozing now (diagnostics: the performance probe and the bench).
func get_dozing_count() -> int:
	var count: int = 0
	for entity: SimEntity in _doze:
		if entity._sim_suspended:
			count += 1
	return count


## Decide which entities doze: a full pass when a doze rectangle crossed a grid line (or after a respawn), else
## only the entities whose state changed. The two rectangles: the view grown by Tuning.DOZE_VIEW_REACH_PX and the
## hero's box and feet point grown by Tuning.DOZE_HERO_REACH_PX, each rounded outwards to Tuning.DOZE_GRID_PX.
func _doze_update() -> void:
	var view: Rect2i = get_view_rect()
	_doze_view = view
	var grid: int = Tuning.DOZE_GRID_PX
	var mask: int = ~(grid - 1)
	var reach: int = Tuning.DOZE_VIEW_REACH_PX
	var view_left: int = (view.position.x - reach) & mask
	var view_top: int = (view.position.y - reach) & mask
	var view_right: int = (view.position.x + view.size.x + reach + grid - 1) & mask
	var view_bottom: int = (view.position.y + view.size.y + reach + grid - 1) & mask
	var hero_left: int = view_left
	var hero_top: int = view_top
	var hero_right: int = view_right
	var hero_bottom: int = view_bottom
	if player != null:
		# player._doze_box() written out (box and feet point together): this runs at the end of every tick.
		var feet: Vector2i = player.sim_pos
		_doze_hero = feet
		var box_left: int = feet.x - player.box_xo
		var box_top: int = feet.y - player.box_h
		reach = Tuning.DOZE_HERO_REACH_PX
		hero_left = (mini(feet.x, box_left) - reach) & mask
		hero_top = (mini(feet.y, box_top) - reach) & mask
		hero_right = (maxi(feet.x + 1, box_left + maxi(player.box_w, 1)) + reach + grid - 1) & mask
		hero_bottom = (maxi(feet.y + 1, box_top + maxi(player.box_h, 1)) + reach + grid - 1) & mask
	else:
		_doze_hero = Vector2i(-1, -1)
	if _doze_full or view_left != _dz_view_left or view_top != _dz_view_top or view_right != _dz_view_right \
			or view_bottom != _dz_view_bottom or hero_left != _dz_hero_left or hero_top != _dz_hero_top \
			or hero_right != _dz_hero_right or hero_bottom != _dz_hero_bottom:
		_doze_full = false
		_dz_view_left = view_left
		_dz_view_top = view_top
		_dz_view_right = view_right
		_dz_view_bottom = view_bottom
		_dz_hero_left = hero_left
		_dz_hero_top = hero_top
		_dz_hero_right = hero_right
		_dz_hero_bottom = hero_bottom
		_doze_notes.clear()
		for i: int in _doze.size():
			_doze_check(i)
		return
	if _doze_notes.is_empty():
		return
	var notes: Array[SimEntity] = _doze_notes.duplicate()
	_doze_notes.clear()
	for entity: SimEntity in notes:
		if is_instance_valid(entity) and entity._doze_slot >= 0:
			_doze_check(entity._doze_slot)


## True when the area in slot `slot` touches neither doze rectangle.
func _doze_far(slot: int) -> bool:
	var k: int = slot * 4
	var left: int = _doze_rects[k]
	var top: int = _doze_rects[k + 1]
	var right: int = _doze_rects[k + 2]
	var bottom: int = _doze_rects[k + 3]
	return (right <= _dz_view_left or left >= _dz_view_right or bottom <= _dz_view_top or top >= _dz_view_bottom) \
			and (right <= _dz_hero_left or left >= _dz_hero_right or bottom <= _dz_hero_top or top >= _dz_hero_bottom)


## One entity against the doze rectangles.
func _doze_check(slot: int) -> void:
	var entity: SimEntity = _doze[slot]
	var k: int = slot * 4
	if _doze_known[slot] == 0:
		_doze_store_area(slot, entity._doze_area())
	if _doze_rects[k + 2] <= _doze_rects[k]:
		if entity._sim_suspended:
			_doze_wake_entity(entity)
		return
	if entity._sim_suspended:
		if not _doze_far(slot):
			_doze_wake_entity(entity)
		return
	if not _doze_far(slot) or not entity._can_doze():
		return
	# The area the entity has right now (a cached one may be old), then off it goes.
	_doze_store_area(slot, entity._doze_area())
	if _doze_rects[k + 2] <= _doze_rects[k] or not _doze_far(slot):
		return
	entity._on_doze()
	if _doze_at_tick_end:
		# What the pass that follows would compute: the area is off the view.
		entity.on_screen = false
	elif entity.on_screen:
		_doze_screen_pending.append(entity)
	entity.sim_prev = entity.sim_pos
	Sim.suspend(entity)
	entity.set_process_internal(false)
	_awake_remove(entity)


func _doze_store_area(slot: int, area: Rect2i) -> void:
	var k: int = slot * 4
	_doze_known[slot] = 1
	if area.size.x <= 0 or area.size.y <= 0:
		_doze_rects[k] = 0
		_doze_rects[k + 1] = 0
		_doze_rects[k + 2] = 0
		_doze_rects[k + 3] = 0
		return
	_doze_rects[k] = area.position.x
	_doze_rects[k + 1] = area.position.y
	_doze_rects[k + 2] = area.end.x
	_doze_rects[k + 3] = area.end.y


func _doze_wake_entity(entity: SimEntity) -> void:
	Sim.resume(entity)
	entity.set_process_internal(true)
	if entity._level_awake_slot < 0:
		entity._level_awake_slot = _awake.size()
		_awake.append(entity)
	entity._on_doze_wake()


func _awake_remove(entity: SimEntity) -> void:
	var slot: int = entity._level_awake_slot
	if slot >= 0 and slot < _awake.size() and _awake[slot] == entity:
		var last: SimEntity = _awake[_awake.size() - 1]
		_awake[slot] = last
		last._level_awake_slot = slot
		_awake.resize(_awake.size() - 1)
	entity._level_awake_slot = -1
