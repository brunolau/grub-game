class_name Level
extends LevelBase
## The gameplay scene `res://scenes/world/level.tscn` (ARCHITECTURE.md 5.2, 7, 8.5). Owner: world.
##
## Loads the level named by Flow.pending_level_id: collision through TileGrid, visuals by the auto-tiling table
## of section 7.4 (terrain, one-way floors, slopes, spikes, liquids, back walls, overrides, props, parallax), the
## entities of the legend and of [entities] with their difficulty flags, the hero at '@', the completion totals,
## the wind script, darkness, the time limit and the level music. While playing it runs the camera of
## PHYSICS.md 12 on tile cells (rendered with interpolation) and the darkness fade; a respawn happens behind
## Flow's curtain (Flow.play_covered).
##
## Everything positional is in logical px; the TileMapLayers, props and camera work in art px (x Tuning.ART_SCALE),
## the only other place besides SimEntity where positions are scaled.

## Colour of the "night" palette of GAMEPLAY.md 7.10 (CanvasModulate of the whole level).
const DARK_COLOR: Color = Color(0.30, 0.28, 0.45)
## Extra tile columns / rows painted around the map when the view is larger than the level (section 7.4: the
## ground continues beyond the edges), beyond the strictly visible overflow.
const APRON_EXTRA: int = 2

var _data: LevelData = null
var _source_text: String = ""
var _source_id: StringName = &""
var _looks: LevelLooks = LevelLooks.new()
var _camera_logic: LevelCamera = LevelCamera.new()
var _driver: LevelDriver = null
var _base_scroll_flags: int = 0
var _music: StringName = &""
var _apron: Rect2i = Rect2i()          # tile rectangle painted so far, including the map
var _wind_script: Array[Vector2i] = []
var _wind_index: int = 0
var _play_ticks: int = 0
var _dark_ticks: int = 0
var _dark_ticks_prev: int = 0
var _respawn_pending: bool = false
var _reported: Dictionary = {}

@onready var _parallax: WorldParallax = $Parallax
@onready var _back_tiles: TileMapLayer = $BackTiles
@onready var _props_back: Node2D = $PropsBack
@onready var _tiles: TileMapLayer = $Tiles
@onready var _objects: Node2D = $Objects
@onready var _items: Node2D = $Items
@onready var _enemies: Node2D = $Enemies
@onready var _player_layer: Node2D = $PlayerLayer
@onready var _projectiles: Node2D = $Projectiles
@onready var _fx: Node2D = $Fx
@onready var _props_front: Node2D = $PropsFront
@onready var _front_tiles: TileMapLayer = $FrontTiles
@onready var _weather: WorldWeather = $Weather
@onready var _flies: FlySwarm = $Flies
@onready var _camera: Camera2D = $Camera
@onready var _darkness: CanvasModulate = $Darkness


## Load from this text instead of the level file of Flow.pending_level_id (tests, tools). Call before the node
## enters the tree.
func setup_from_text(p_level_id: StringName, text: String) -> void:
	_source_id = p_level_id
	_source_text = text


func _ready() -> void:
	_driver = LevelDriver.new()
	_driver.setup(_world_step, _camera_step, _post_step)
	add_child(_driver)
	_load()
	start_play()


func _process(delta: float) -> void:
	var alpha: float = Sim.alpha
	var view_art: Vector2 = Vector2(_camera_logic.view * Tuning.ART_SCALE)
	var x: float = lerpf(float(_camera_logic.prev.x), float(_camera_logic.pos.x), alpha) * Tuning.ART_SCALE
	var y: float = lerpf(float(_camera_logic.prev.y), float(_camera_logic.pos.y), alpha) * Tuning.ART_SCALE
	if Settings.get_bool("video/screen_shake"):
		y += float(shake_offset * Tuning.ART_SCALE)
	var top_left: Vector2 = Vector2(roundf(x), roundf(y))
	_camera.position = top_left
	_camera.force_update_scroll()
	var sink: float = maxf(float(_camera_logic.get_max().y * Tuning.ART_SCALE) - top_left.y, 0.0)
	var rise: float = maxf(top_left.y - float(_camera_logic.get_min().y * Tuning.ART_SCALE), 0.0)
	_parallax.set_view(top_left, view_art, sink, rise)
	_weather.advance(top_left, view_art, delta)
	var fade: float = lerpf(float(_dark_ticks_prev), float(_dark_ticks), alpha) / float(Tuning.DARKNESS_FADE_TICKS)
	_darkness.color = Color.WHITE.lerp(DARK_COLOR, clampf(fade, 0.0, 1.0))


func _exit_tree() -> void:
	Audio.stop_loop(Sfx.LOOP_WIND)


# =================================================================================================================
# LevelBase overrides
# =================================================================================================================

func get_view_rect() -> Rect2i:
	return _camera_logic.get_rect()


func get_camera_cell() -> Vector2i:
	return _camera_logic.get_cell()


func lock_camera(view_px: Rect2i) -> void:
	super.lock_camera(view_px)
	_camera_logic.lock(view_px)


func unlock_camera() -> void:
	super.unlock_camera()
	_camera_logic.unlock()


func snap_camera() -> void:
	_camera_logic.scroll_flags = scroll_flags
	_camera_logic.snap(player)


func get_container(category: String) -> Node:
	match category:
		"objects", "zones":
			return _objects
		"items":
			return _items
		"enemies", "bosses":
			return _enemies
		"player":
			return _player_layer
		"projectiles":
			return _projectiles
		"fx":
			return _fx
	return _objects


func set_cell(col: int, row: int, ch: String) -> void:
	super.set_cell(col, row, ch)
	if not grid.in_bounds(col, row):
		return
	_looks.set_code(col, row, grid.get_char(col, row))
	for r: int in range(row - 1, row + 2):
		for c: int in range(col - 1, col + 2):
			_paint_cell(c, r)


func set_cell_look(col: int, row: int, atlas_index: int) -> void:
	if not grid.in_bounds(col, row):
		return
	_looks.set_look(col, row, atlas_index)
	_paint_cell(col, row)


## Switch darkness on or off; the palette fades over Tuning.DARKNESS_FADE_TICKS ticks (phase WORLD). Lights going
## out play the heavy-hurt cue, as in the original (GAMEPLAY.md 10.1 slot 1).
func set_darkness(p_dark: bool) -> void:
	if p_dark and not dark:
		Audio.play_sfx(Sfx.PLAYER_HURT_HEAVY)
	super.set_darkness(p_dark)


func set_wind(value: int) -> void:
	super.set_wind(value)
	_weather.set_wind(wind)
	if wind != 0:
		Audio.start_loop(Sfx.LOOP_WIND)
	else:
		Audio.stop_loop(Sfx.LOOP_WIND)


func start_play(seed_value: int = 1) -> void:
	set_time_limit(int(meta.get("time", 0)))
	super.start_play(seed_value)
	_start_music()


## Respawn after a death with the curtain of GAMEPLAY.md 11.1 step 9 (ARCHITECTURE.md 3.10): Flow closes the
## curtain and stops the clock, the level is reset and the hero put back while the screen is covered, then the
## curtain opens. May be called inside a tick. A request while a respawn is pending is ignored.
func respawn_player() -> void:
	if _respawn_pending:
		return
	_respawn_pending = true
	if Flow.busy:
		# Another transition owns the cover and cannot wait for a curtain of its own: respawn at once.
		_respawn_now()
	else:
		Flow.play_covered(_respawn_now, Defs.Transition.CURTAIN)


# =================================================================================================================
# Queries for tests and tools
# =================================================================================================================

## The parsed level file (null before loading).
func get_data() -> LevelData:
	return _data


## The camera state of PHYSICS.md 12.
func get_camera() -> LevelCamera:
	return _camera_logic


## Flies join the cosmetic swarm around the hero (`zones/flies`, GAMEPLAY.md 7.9).
func attract_flies(amount: int) -> void:
	_flies.attract(amount)


## Flies around the hero now (0 = none).
func get_fly_count() -> int:
	return _flies.count


## True from a respawn request until the hero is back (the curtain is closing meanwhile).
func is_respawn_pending() -> bool:
	return _respawn_pending


## Use a view of `size_art` art px instead of the viewport's size until the viewport is resized (tests and
## tools that need a known view); the camera is placed again around the hero.
func set_view_size(size_art: Vector2i) -> void:
	if _camera_logic.set_view_art(size_art):
		_paint_apron()
	snap_camera()


## The look painted at a cell of a layer ("back", "main" or "front"): LevelTiles look value, -1 = nothing.
func get_painted_look(col: int, row: int, layer: String = "main") -> int:
	var map: TileMapLayer = _tiles
	if layer == "back":
		map = _back_tiles
	elif layer == "front":
		map = _front_tiles
	var source: int = map.get_cell_source_id(Vector2i(col, row))
	if source < 0:
		return LevelTiles.LOOK_NONE
	var coords: Vector2i = map.get_cell_atlas_coords(Vector2i(col, row))
	if source == LevelTiles.SET_LIQUID:
		return LevelTiles.look(source, coords.x)
	return LevelTiles.look(source, coords.y * LevelTiles.ATLAS_COLUMNS + coords.x)


# =================================================================================================================
# Loading
# =================================================================================================================

func _load() -> void:
	_data = _read_data()
	if _data == null:
		return
	for issue: Dictionary in _data.issues:
		_report_line(int(issue["line"]), str(issue["message"]))
	var difficulty: int = Game.difficulty
	level_id = _data.id
	meta = _data.resolved_meta(difficulty)
	grid = _data.build_grid(difficulty)
	_base_scroll_flags = _scroll_flags_from_meta()
	scroll_flags = _base_scroll_flags
	_build_visuals()
	_place_start()
	_spawn_entities()
	_setup_world_state()
	_setup_camera()


func _read_data() -> LevelData:
	if _source_text != "":
		return LevelData.parse(_source_id, _source_text, "%s.lvl" % _source_id)
	var id: StringName = Flow.pending_level_id
	if id == &"":
		id = Game.level_id
	var path: String = Levels.get_level_path(id)
	if path.is_empty():
		push_error("Level: unknown level '%s'" % id)
		return null
	var data: LevelData = LevelData.load_file(path)
	if data == null:
		push_error("Level: cannot read %s" % path)
	return data


func _scroll_flags_from_meta() -> int:
	var flags: int = 0
	if bool(meta.get("low_band", false)):
		flags |= Defs.SCROLL_LOW_BAND
	match str(meta.get("scroll", "normal")):
		"vertical":
			flags |= Defs.SCROLL_NO_HORIZONTAL
		"autoscroll":
			flags |= Defs.SCROLL_NO_HORIZONTAL | Defs.SCROLL_AUTO_DOWN
	return flags


func _build_visuals() -> void:
	var terrain_a: String = str(meta.get("terrain_a", ""))
	var terrain_b: String = str(meta.get("terrain_b", terrain_a))
	var liquid: String = str(meta.get("liquid", "water"))
	for atlas: String in [terrain_a, terrain_b]:
		if not WorldTileSet.has_terrain(atlas):
			_report_key("terrain_a" if atlas == terrain_a else "terrain_b",
					"terrain atlas '%s' does not exist" % atlas)
	if not WorldTileSet.has_liquid(liquid):
		_report_key("liquid", "liquid '%s' does not exist" % liquid)
	var tile_set: TileSet = WorldTileSet.build(terrain_a, terrain_b, liquid)
	for map: TileMapLayer in [_back_tiles, _tiles, _front_tiles]:
		map.tile_set = tile_set
		map.clear()
	_back_tiles.self_modulate = LevelLooks.BACK_TINT
	var background: String = str(meta.get("background", "none"))
	if not _parallax.setup(background):
		_report_key("background", "parallax set '%s' does not exist" % background)
	_looks.setup(_data, grid)
	for issue: Dictionary in _looks.issues:
		_report_line(int(issue["line"]), str(issue["message"]))
	_apron = Rect2i(0, 0, grid.cols, grid.rows)
	for row: int in grid.rows:
		for col: int in grid.cols:
			_paint_cell(col, row, true)


## Repaint the three tile layers at one cell of the map. `fresh` = the layers are empty there (initial paint).
func _paint_cell(col: int, row: int, fresh: bool = false) -> void:
	if not grid.in_bounds(col, row):
		return
	var cell: Vector2i = Vector2i(col, row)
	_put(_back_tiles, cell, _looks.look_at(col, row, LevelLooks.Layer.BACK), fresh)
	_put(_tiles, cell, _looks.look_at(col, row, LevelLooks.Layer.MAIN), fresh)
	_put(_front_tiles, cell, _looks.look_at(col, row, LevelLooks.Layer.FRONT), fresh)


func _put(map: TileMapLayer, cell: Vector2i, look: int, fresh: bool = false) -> void:
	if look < 0:
		if not fresh:
			map.erase_cell(cell)
		return
	var set_id: int = LevelTiles.look_set(look)
	var index: int = LevelTiles.look_index(look)
	var coords: Vector2i = Vector2i(index, 0) if set_id == LevelTiles.SET_LIQUID else LevelTiles.atlas_coords(index)
	map.set_cell(cell, set_id, coords)


## Paint the ground beyond the map edges when the view is larger than the level in an axis (the camera is then
## centred and shows the outside).
func _paint_apron() -> void:
	var view: Vector2i = _camera_logic.view
	var extra_x: int = 0
	var extra_y: int = 0
	if view.x > grid.width_px():
		extra_x = (view.x - grid.width_px()) / (2 * Tuning.TILE) + APRON_EXTRA
	if view.y > grid.height_px():
		extra_y = (view.y - grid.height_px()) / (2 * Tuning.TILE) + APRON_EXTRA
	var wanted: Rect2i = Rect2i(-extra_x, -extra_y, grid.cols + extra_x * 2, grid.rows + extra_y * 2)
	if _apron.encloses(wanted):
		return
	var apron: Dictionary = _looks.apron_looks(_apron.merge(wanted))
	_apron = _apron.merge(wanted)
	for cell: Vector2i in apron:
		var look: int = apron[cell]
		_put(_front_tiles if LevelTiles.is_front(look) else _tiles, cell, look)


func _place_start() -> void:
	var starts: Array[Vector2i] = _data.find_starts()
	if starts.is_empty():
		_report_line(int(_data.section_lines.get(LevelData.SECTION_TILES, 0)), "the level has no hero start '@'")
		return
	start_pos = LevelText.cell_to_feet(float(starts[0].x), float(starts[0].y))


func _spawn_entities() -> void:
	var records: Array[Dictionary] = _data.entity_records()
	var ids: Array[StringName] = []
	for record: Dictionary in records:
		var id: StringName = record["id"]
		if not Spawner.is_prop(id) and not ids.has(id) and LevelText.applies_to(record["params"], Game.difficulty):
			ids.append(id)
	Spawner.preload_ids(ids)
	var spots: int = 0
	var items: int = 0
	for record: Dictionary in records:
		var id: StringName = record["id"]
		var params: Dictionary = (record["params"] as Dictionary).duplicate()
		if not LevelText.applies_to(params, Game.difficulty):
			continue
		if Spawner.is_prop(id):
			_add_prop(id, float(record["col"]), float(record["row"]), params, int(record["line"]))
			continue
		var category: String = Spawner.category(id)
		if category == "player" or category == "projectiles":
			_report_line(int(record["line"]), "'%s' is spawned by code and cannot be placed in a level" % id)
			continue
		var node: Node = spawn(id, LevelText.cell_to_feet(float(record["col"]), float(record["row"]), params), params)
		if node is CollectibleBase:
			var item: CollectibleBase = node
			if not item.dropped:
				item.counts_for_completion = item.points > 0
				if item.counts_for_completion:
					items += 1
		elif node is HittableBase:
			var hittable: HittableBase = node
			if hittable.counts_for_completion:
				spots += 1
	Game.add_completion_totals(spots, items)
	if Spawner.exists(&"player/player"):
		var hero: Node = spawn(&"player/player", start_pos)
		if hero is PlayerBase:
			var hero_base: PlayerBase = hero
			hero_base.respawn_at(start_pos)


func _add_prop(id: StringName, col: float, row: float, params: Dictionary, line: int) -> void:
	var path: String = Spawner.prop_texture_path(id)
	if path.is_empty() or not ResourceLoader.exists(path):
		_report_line(line, "prop '%s' does not exist (%s)" % [id, path])
		return
	var texture: Texture2D = load(path) as Texture2D
	var sprite: Sprite2D = Sprite2D.new()
	sprite.name = "%s_%d" % [String(id).get_file(), (_props_back.get_child_count() + _props_front.get_child_count())]
	sprite.texture = texture
	sprite.centered = false
	sprite.flip_h = params.has("flip") and bool(params["flip"])
	var feet: Vector2i = LevelText.cell_to_feet(col, row, params)
	var top_left: Vector2i = LevelLooks.prop_top_left(id, feet, Vector2i(texture.get_width(), texture.get_height()))
	sprite.position = Tuning.to_art(Vector2(feet))
	sprite.offset = Vector2(top_left) - sprite.position
	if str(params.get("layer", "back")) == "front":
		_props_front.add_child(sprite)
	else:
		_props_back.add_child(sprite)


func _setup_world_state() -> void:
	dark = bool(meta.get("dark", false))
	_dark_ticks = Tuning.DARKNESS_FADE_TICKS if dark else 0
	_dark_ticks_prev = _dark_ticks
	for entry: String in _data.wind_problems(Game.difficulty):
		_report_key("wind", "wind entry '%s' is not tick:value" % entry)
	_wind_script = _data.wind_script(Game.difficulty)
	_wind_index = 0
	_play_ticks = 0
	_apply_wind_script()
	_music = StringName(str(meta.get("music", "")))
	if _music != &"" and not AudioTable.MUSIC.has(_music):
		_report_key("music", "unknown music context '%s'" % _music)
		_music = &""


func _setup_camera() -> void:
	_camera_logic.set_bounds(Rect2i(0, 0, grid.width_px(), grid.height_px()))
	_camera_logic.home_row = int(meta.get("home_row", -1))
	_camera_logic.fast = bool(meta.get("fast_vscroll", true))
	_camera_logic.smooth = Settings.get_bool("camera/smooth_follow")
	_camera_logic.set_view_art(_viewport_size())
	_paint_apron()
	_camera.anchor_mode = Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT
	_camera.make_current()
	snap_camera()
	if not get_viewport().size_changed.is_connected(_on_viewport_resized):
		get_viewport().size_changed.connect(_on_viewport_resized)
	if not Settings.changed.is_connected(_on_setting_changed):
		Settings.changed.connect(_on_setting_changed)


func _viewport_size() -> Vector2i:
	var size: Vector2 = get_viewport().get_visible_rect().size
	return Vector2i(roundi(size.x), roundi(size.y))


func _start_music() -> void:
	if _music != &"":
		Audio.play_music(_music)


# =================================================================================================================
# Simulation steps (called by the LevelDriver)
# =================================================================================================================

## Phase WORLD: wind script, darkness fade.
func _world_step() -> void:
	_play_ticks += 1
	_apply_wind_script()
	_dark_ticks_prev = _dark_ticks
	if dark and _dark_ticks < Tuning.DARKNESS_FADE_TICKS:
		_dark_ticks += 1
	elif not dark and _dark_ticks > 0:
		_dark_ticks -= 1


## Phase CAMERA: PHYSICS.md 12.
func _camera_step() -> void:
	_camera_logic.scroll_flags = scroll_flags
	_camera_logic.tick(player)


## Phase POST: time limit.
func _post_step() -> void:
	tick_time_limit()


## The wind script of PHYSICS.md 13.1: an entry `t:v` is the wind of tick t on (applied at the end of tick t - 1).
func _apply_wind_script() -> void:
	while _wind_index < _wind_script.size() and _wind_script[_wind_index].x <= _play_ticks + 1:
		set_wind(_wind_script[_wind_index].y)
		_wind_index += 1


func _respawn_now() -> void:
	_respawn_pending = false
	scroll_flags = _base_scroll_flags
	_camera_logic.scroll_flags = scroll_flags
	set_time_limit(int(meta.get("time", 0)))
	super.respawn_player()
	_start_music()


# =================================================================================================================
# Reactions
# =================================================================================================================

func _on_viewport_resized() -> void:
	if _camera_logic.set_view_art(_viewport_size()):
		_paint_apron()


func _on_setting_changed(key: String, value: Variant) -> void:
	if key == "camera/smooth_follow":
		_camera_logic.smooth = bool(value)


## Report a content problem of the level file once (ARCHITECTURE.md 10.2): file and line, then carry on.
func _report_line(line: int, message: String) -> void:
	var text: String = "%s:%d: %s" % [_data.path if _data != null else String(level_id), line, message]
	if _reported.has(text):
		return
	_reported[text] = true
	push_warning("Level: " + text)


func _report_key(key: String, message: String) -> void:
	_report_line(int(_data.meta_lines.get(key, 0)) if _data != null else 0, message)
