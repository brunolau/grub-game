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
## Auto-scrolling levels: the deadly top edge of the view is drawn as a band of smoke with glowing embers, so the
## threat that kills a hero who falls behind the descent is visible (presentation only).
const SMOKE_HEIGHT_ART: float = 22.0
const SMOKE_Z: int = Defs.Z_FRONT_TILES + 5
## Lava ambience loop: plays while lava lies within this many tiles of the view (checked a few times a second).
const LAVA_REACH_TILES: int = 3
const LAVA_CHECK_SECONDS: float = 0.25
## `objects/hero_start slot=<2..4>`: where P2..P4 start (DESIGN.md D.5). A marker the loader reads, never spawned
## (it takes no spawn serial; a single-player game ignores it).
const HERO_START_ID: StringName = &"objects/hero_start"


## The smoke band along the top edge of the view on an auto-scrolling level.
class TopSmoke:
	extends Node2D

	var width: float = 640.0
	var alpha: float = 1.0
	var _time: float = 0.0

	func advance(delta: float) -> void:
		_time += delta
		queue_redraw()

	func _draw() -> void:
		if alpha <= 0.0:
			return
		var rows: int = int(SMOKE_HEIGHT_ART / 2.0)
		for i: int in rows:
			var a: float = alpha * 0.92 * (1.0 - float(i) / float(rows))
			draw_rect(Rect2(0.0, float(i * 2), width, 2.0), Color(0.16, 0.09, 0.07, a))
		# A ragged lower edge (pixel teeth) with glowing embers that drift sideways.
		var step: float = 8.0
		var shift: float = fmod(_time * 6.0, step * 4.0)
		var x: float = -step * 4.0 + shift
		var k: int = 0
		while x < width:
			var tooth: float = float((k * 7) % 5 + 1) * 2.0
			draw_rect(Rect2(x, SMOKE_HEIGHT_ART, step, tooth), Color(0.16, 0.09, 0.07, alpha * 0.55))
			if (k + int(_time * 3.0)) % 3 == 0:
				draw_rect(Rect2(x + 2.0, SMOKE_HEIGHT_ART + tooth - 2.0, 2.0, 2.0), Color(1.0, 0.45, 0.12, alpha * 0.9))
			x += step
			k += 1

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
## Cells whose tile layers must be painted again (set_cell), as Vector2i -> true.
var _repaint: Dictionary = {}

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
var _top_smoke: TopSmoke = null
## Lava cells of the level (the lava ambience loop plays while one is near the view), and the seconds until the
## next look.
var _lava_cells: PackedVector2Array = PackedVector2Array()
var _lava_check: float = 0.0


## Load from this text instead of the level file of Flow.pending_level_id (tests, tools). Call before the node
## enters the tree.
func setup_from_text(p_level_id: StringName, text: String) -> void:
	_source_id = p_level_id
	_source_text = text


func _ready() -> void:
	# Sign texts are translated while the entities spawn: register the catalogues even when no menu screen ran
	# before this level (autoplay, debug starts).
	UiKit.ensure_locale()
	_driver = LevelDriver.new()
	_driver.setup(_world_step, _camera_step, _post_step)
	add_child(_driver)
	_load()
	start_play()
	Events.player_died.connect(_on_player_died)


func _process(delta: float) -> void:
	_flush_repaint()
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
	_lava_check -= delta
	if _lava_check <= 0.0:
		_lava_check = LAVA_CHECK_SECONDS
		_update_lava_loop(Rect2(top_left / float(Tuning.ART_SCALE), view_art / float(Tuning.ART_SCALE)))
	if _top_smoke != null:
		_top_smoke.position = top_left
		_top_smoke.width = view_art.x
		var smoke_on: bool = (scroll_flags & Defs.SCROLL_AUTO_DOWN) != 0
		_top_smoke.alpha = move_toward(_top_smoke.alpha, 1.0 if smoke_on else 0.0, delta * 2.0)
		_top_smoke.visible = _top_smoke.alpha > 0.0
		_top_smoke.advance(delta)
	var fade: float = lerpf(float(_dark_ticks_prev), float(_dark_ticks), alpha) / float(Tuning.DARKNESS_FADE_TICKS)
	_darkness.color = Color.WHITE.lerp(DARK_COLOR, clampf(fade, 0.0, 1.0))


func _exit_tree() -> void:
	Audio.stop_loop(Sfx.LOOP_WIND)
	Audio.stop_loop(Sfx.LOOP_LAVA)


## The death jingle (GAMEPLAY.md 10.1 slot 7) plays over the death toss before the respawn curtain; the level music
## starts again after it. On the last life the game-over screen brings its own music instead. A party: only for the
## death that takes the last hero (a team wipe); one hero's death leaves the music alone.
func _on_player_died(_cause: StringName) -> void:
	if hero_count() > 1 and not all_heroes_dead_or_down():
		return
	if Game.lives > 0 and _music != &"":
		Audio.play_jingle(Sfx.MUSIC_DEATH, _music)


## Lava ambience: the bubbling loop plays while a lava cell lies in the view or within LAVA_REACH_TILES of it.
func _update_lava_loop(view: Rect2) -> void:
	if _lava_cells.is_empty():
		return
	var reach: float = float(LAVA_REACH_TILES * Tuning.TILE)
	var area: Rect2 = view.grow(reach)
	var near: bool = false
	for cell: Vector2 in _lava_cells:
		if area.has_point(cell * float(Tuning.TILE)):
			near = true
			break
	if near:
		Audio.start_loop(Sfx.LOOP_LAVA)
	else:
		Audio.stop_loop(Sfx.LOOP_LAVA)


## The surface cells of the lava (liquid cells with no liquid above them), for the ambience loop.
func _find_lava_cells() -> void:
	_lava_cells.clear()
	if str(meta.get("liquid", "water")) != "lava":
		return
	for row: int in grid.rows:
		for col: int in grid.cols:
			if grid.get_char(col, row) == TileGrid.CH_LIQUID and (row == 0 or grid.get_char(col, row - 1) != TileGrid.CH_LIQUID):
				_lava_cells.append(Vector2(col, row))


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


## Snaps on P1 (a party too, until the tribe camera's snap exists: PLAN P1, world).
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


## Collision and the tile codes change at once; the three tile layers of the cell and its neighbours (auto-tiling)
## are painted again before the next frame is drawn ([method _flush_repaint]): a rising column changes many cells
## in one tick, and painting each neighbourhood at once painted most cells several times, inside the tick.
func set_cell(col: int, row: int, ch: String) -> void:
	super.set_cell(col, row, ch)
	if not grid.in_bounds(col, row):
		return
	_looks.set_code(col, row, grid.get_char(col, row))
	for r: int in range(row - 1, row + 2):
		for c: int in range(col - 1, col + 2):
			_repaint[Vector2i(c, r)] = true


func set_cell_look(col: int, row: int, atlas_index: int) -> void:
	if not grid.in_bounds(col, row):
		return
	_looks.set_look(col, row, atlas_index)
	_paint_cell(col, row)


## Paint the cells changed by [method set_cell] since the last frame (each cell once).
func _flush_repaint() -> void:
	if _repaint.is_empty():
		return
	for cell: Vector2i in _repaint:
		_paint_cell(cell.x, cell.y)
	_repaint.clear()


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
	# The tracks of the screens and levels before this one are released (they are loaded again when needed).
	Audio.retain_music(_level_music_contexts())


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
	_flush_repaint()
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
	_hold_autoscroll()
	_build_visuals()
	_place_start()
	_spawn_entities()
	_preload_music()
	_setup_world_state()
	_find_lava_cells()
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
	_place_party_starts()


## The start of every player slot (LevelBase.start_positions): P1 at '@', P2..P4 at their `objects/hero_start
## slot=<2..4>` marker (the slot parameter counts players from 1, as the level files write it), else spread from '@'
## (LevelBase.get_start_pos_for). Only read here: a single-player game never uses the markers.
func _place_party_starts() -> void:
	start_positions.clear()
	start_positions.append(start_pos)
	var markers: Dictionary = {}
	for record: Dictionary in _data.entity_records():
		if record["id"] != HERO_START_ID:
			continue
		var params: Dictionary = record["params"]
		var player_number: int = int(params.get("slot", 0))
		if player_number >= 2 and player_number <= Defs.MAX_PLAYERS and LevelText.applies_to(params, Game.difficulty):
			markers[player_number - 1] = LevelText.cell_to_feet(float(record["col"]), float(record["row"]), params)
	for slot: int in range(1, Defs.MAX_PLAYERS):
		start_positions.append(markers[slot] if markers.has(slot) else _spread_point(start_pos, slot))


func _spawn_entities() -> void:
	var records: Array[Dictionary] = _data.entity_records()
	var ids: Array[StringName] = []
	for record: Dictionary in records:
		var id: StringName = record["id"]
		if id == HERO_START_ID:
			continue  # a start marker of the loader (_place_party_starts), not an entity
		if not Spawner.is_prop(id) and not ids.has(id) and LevelText.applies_to(record["params"], Game.difficulty):
			ids.append(id)
	# Scenes of the previous level that this one does not use are released with their textures.
	Spawner.retain_only(ids)
	Spawner.preload_ids(ids)
	# Effects, revealed or dropped items and shots are spawned by code in the middle of a tick: load them now.
	Spawner.preload_runtime()
	var spots: int = 0
	var items: int = 0
	for record: Dictionary in records:
		var id: StringName = record["id"]
		if id == HERO_START_ID:
			continue
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
	# P2..P4 of a party, after P1 (TECH_AUDIT.md 4.4); nothing in single-player.
	spawn_party_heroes()


## Music that starts in the middle of a tick (feast mode, a boss fight) is loaded with the level, not on its tick.
func _preload_music() -> void:
	for context: StringName in _level_music_contexts():
		Audio.preload_music(context)


## The music contexts this level may play: its own, feast mode, its bosses'.
func _level_music_contexts() -> Array[StringName]:
	var contexts: Array[StringName] = [Sfx.MUSIC_FEAST]
	if _music != &"":
		contexts.append(_music)
	for entity: SimEntity in get_kind(Defs.Kind.BOSS):
		var boss: BossBase = entity as BossBase
		if boss != null:
			contexts.append(boss.music)
	return contexts


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


## Phase CAMERA: PHYSICS.md 12. The camera follows P1 (a party's tribe camera, PHYSICS.md C.13, is world's PLAN P1
## work: until then every party is framed by P1).
func _camera_step() -> void:
	if _camera_logic.autoscroll_held and _any_hero_input():
		_camera_logic.autoscroll_held = false
	_camera_logic.scroll_flags = scroll_flags
	_camera_logic.tick(player)


## True when a hero's input of this tick is held (the auto-scroll waits for the first one). Swap is no movement input
## (DESIGN.md C.1): a Book I solo hero ignores it, so it does not end the wait either. A party: any hero's slot.
func _any_hero_input() -> bool:
	if (GameInput.flags & ~Defs.IN_SWAP) != 0:
		return true
	if hero_count() <= 1:
		return false
	for hero: PlayerBase in contact_order():
		if (GameInput.get_flags(hero.slot) & ~Defs.IN_SWAP) != 0:
			return true
	return false


## An auto-scrolling level does not sink before the player's first input (at the start and after a respawn), so
## nobody is carried off the top edge while reading the start sign or the stage banner. A route that moves on its
## first tick sinks exactly as without the wait.
func _hold_autoscroll() -> void:
	_camera_logic.autoscroll_held = (_base_scroll_flags & Defs.SCROLL_AUTO_DOWN) != 0
	if _camera_logic.autoscroll_held and _top_smoke == null:
		_top_smoke = TopSmoke.new()
		_top_smoke.name = "TopSmoke"
		_top_smoke.z_index = SMOKE_Z
		add_child(_top_smoke)


## True while an auto-scrolling level waits for the player's first input.
func is_autoscroll_held() -> bool:
	return _camera_logic.autoscroll_held


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
	_hold_autoscroll()
	set_time_limit(int(meta.get("time", 0)))
	super.respawn_player()
	# The darkness of the checkpoint is back at once (the curtain hid the change): no fade.
	_dark_ticks = Tuning.DARKNESS_FADE_TICKS if dark else 0
	_dark_ticks_prev = _dark_ticks
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
