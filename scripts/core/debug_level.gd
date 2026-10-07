extends LevelBase
## Development stand-in for `res://scenes/world/level.tscn` (docs/ARCHITECTURE.md 9.3). Owner: core.
##
## Flow loads this scene while the world module's level scene does not exist yet. It reads a level file with the
## shared LevelText / TileGrid code, draws the COLLISION grid as flat coloured shapes, spawns every entity whose
## scene already exists (others are listed on screen) and follows the hero with a plain camera. It lets the
## player, enemies and objects modules run and screenshot their work before the real loader, tileset, camera and
## parallax exist. It is NOT the level loader: no art, no original camera rules, no back walls, no validation.

const COLOR_SOLID_A: Color = Color("5a8f3c")
const COLOR_SOLID_B: Color = Color("8a6a4a")
const COLOR_ONEWAY: Color = Color("c9a45c")
const COLOR_HATCH: Color = Color("d98b3a")
const COLOR_DEADLY: Color = Color("d43d3d")
const COLOR_LIQUID: Color = Color("3d7fd4")
const COLOR_INVISIBLE: Color = Color(1.0, 1.0, 1.0, 0.25)
const COLOR_BOX: Color = Color(1.0, 1.0, 0.2, 0.9)
const COLOR_HERO: Color = Color(0.3, 1.0, 0.4, 0.9)
const COLOR_SKY: Color = Color("27384d")

var _camera: Camera2D = null
var _legend: Dictionary = {}
var _skipped: PackedStringArray = PackedStringArray()
var _rows: PackedStringArray = PackedStringArray()


func _ready() -> void:
	level_id = Flow.pending_level_id
	_camera = Camera2D.new()
	add_child(_camera)
	_camera.make_current()
	_load(Levels.get_level_path(level_id))
	_follow()
	start_play()


func _process(_delta: float) -> void:
	_follow()
	queue_redraw()


func get_view_rect() -> Rect2i:
	var size: Vector2 = get_viewport_rect().size / float(Tuning.ART_SCALE)
	var centre: Vector2 = _camera.position / float(Tuning.ART_SCALE)
	return Rect2i(
		floori(centre.x - size.x * 0.5), floori(centre.y - size.y * 0.5) - shake_offset,
		ceili(size.x), ceili(size.y)
	)


func _load(path: String) -> void:
	if path.is_empty():
		push_error("DebugLevel: unknown level '%s'" % level_id)
		return
	var sections: Dictionary = LevelText.split_sections(FileAccess.get_file_as_string(path))
	meta = LevelText.parse_key_values(sections.get("meta", PackedStringArray()))
	_legend = LevelText.parse_legend(sections.get("legend", PackedStringArray()))
	_rows = sections.get("tiles", PackedStringArray())
	grid = TileGrid.from_rows(
		_rows, int(meta.get("ice_a", 0)), int(meta.get("ice_b", 0)), LevelText.legend_tiles(_legend)
	)
	var spots: int = 0
	var items: int = 0
	for row: int in _rows.size():
		var line: String = _rows[row]
		for col: int in line.length():
			var ch: String = line[col]
			if ch == TileGrid.CH_PLAYER_START:
				start_pos = LevelText.cell_to_feet(col, row)
			elif _legend.has(ch):
				var entry: Dictionary = _legend[ch]
				var node: Node = _spawn_entry(entry["id"], float(col), float(row), entry["params"])
				if node is HittableBase:
					spots += 1
				elif node is CollectibleBase:
					items += 1
	for entity_line: String in sections.get("entities", PackedStringArray()):
		var entity: Dictionary = LevelText.parse_entity_line(entity_line)
		if not entity.is_empty():
			_spawn_entry(entity["id"], entity["col"], entity["row"], entity["params"])
	Game.add_completion_totals(spots, items)
	if Spawner.exists(&"player/player"):
		var hero: Node = spawn(&"player/player", start_pos)
		if hero is PlayerBase:
			var hero_base: PlayerBase = hero
			hero_base.respawn_at(start_pos)
		# P2..P4 of a party after P1, spread from '@' (the camera follows P1); nothing in single-player.
		spawn_party_heroes()
	else:
		_note_skipped(&"player/player")


func _spawn_entry(id: StringName, col: float, row: float, params: Dictionary) -> Node:
	if not LevelText.applies_to(params, Game.difficulty):
		return null
	if Spawner.is_prop(id) or not Spawner.exists(id):
		_note_skipped(id)
		return null
	var node: Node = spawn(id, LevelText.cell_to_feet(col, row, params), params)
	if node is CollectibleBase and not params.has("dropped"):
		var item: CollectibleBase = node
		item.counts_for_completion = item.points > 0
	return node


func _note_skipped(id: StringName) -> void:
	if not _skipped.has(String(id)):
		_skipped.append(String(id))


func _follow() -> void:
	var target: Vector2 = Tuning.to_art(Vector2(start_pos))
	if player != null:
		target = player.position
	var half: Vector2 = get_viewport_rect().size * 0.5
	var limit: Vector2 = Vector2(grid.width_px(), grid.height_px()) * float(Tuning.ART_SCALE)
	var x: float = clampf(target.x, minf(half.x, limit.x * 0.5), maxf(limit.x - half.x, limit.x * 0.5))
	var y: float = clampf(target.y - 32.0, minf(half.y, limit.y * 0.5), maxf(limit.y - half.y, limit.y * 0.5))
	_camera.position = Vector2(roundf(x), roundf(y))
	_camera.offset = Vector2(0.0, float(shake_offset * Tuning.ART_SCALE))


func _draw() -> void:
	var cell: float = float(Tuning.TILE_ART)
	var view: Rect2i = get_view_rect()
	var screen: Vector2 = get_viewport_rect().size
	draw_rect(Rect2(_camera.position - screen, screen * 2.0), COLOR_SKY)
	var col_from: int = maxi((view.position.x >> 4) - 1, 0)
	var col_to: int = mini(((view.position.x + view.size.x) >> 4) + 1, grid.cols - 1)
	var row_from: int = maxi((view.position.y >> 4) - 1, 0)
	var row_to: int = mini(((view.position.y + view.size.y) >> 4) + 1, grid.rows - 1)
	for row: int in range(row_from, row_to + 1):
		for col: int in range(col_from, col_to + 1):
			_draw_cell(col, row, Vector2(col * cell, row * cell), cell)
	var scale_px: float = float(Tuning.ART_SCALE)
	for kind: int in Defs.KIND_COUNT:
		for entity: SimEntity in get_kind(kind):
			var box: Rect2i = entity.get_box()
			var rect: Rect2 = Rect2(Vector2(box.position) * scale_px, Vector2(box.size) * scale_px)
			draw_rect(rect, COLOR_HERO if kind == Defs.Kind.PLAYER else COLOR_BOX, false, 2.0)
	if player != null and player.club_box_active:
		var club: Rect2 = Rect2(Vector2(player.club_box.position) * scale_px, Vector2(player.club_box.size) * scale_px)
		draw_rect(club, Color.WHITE, false, 2.0)
	var font: Font = ThemeDB.fallback_font
	var origin: Vector2 = _camera.position - get_viewport_rect().size * 0.5 + Vector2(8.0, 16.0)
	draw_string(font, origin, "DEBUG LEVEL  %s  (collision view)" % level_id, HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
	if not _skipped.is_empty():
		draw_string(
			font, origin + Vector2(0.0, 18.0), "scenes not built yet: " + ", ".join(_skipped),
			HORIZONTAL_ALIGNMENT_LEFT, get_viewport_rect().size.x - 16.0, 8
		)


func _draw_cell(col: int, row: int, at: Vector2, cell: float) -> void:
	var ch: String = grid.get_char(col, row)
	var profile: int = grid.profile_at(col, row)
	if profile >= TileGrid.PROFILE_UP_RIGHT_45 and profile <= TileGrid.PROFILE_UP_LEFT_LOW:
		var left: float = float(TileGrid.profile_offset(profile, 0)) * Tuning.ART_SCALE
		var right: float = float(TileGrid.profile_offset(profile, 15)) * Tuning.ART_SCALE
		draw_colored_polygon(PackedVector2Array([
			at + Vector2(0.0, left), at + Vector2(cell, right), at + Vector2(cell, cell), at + Vector2(0.0, cell),
		]), COLOR_SOLID_A)
		return
	match ch:
		TileGrid.CH_SOLID_A:
			draw_rect(Rect2(at, Vector2(cell, cell)), COLOR_SOLID_A)
		TileGrid.CH_SOLID_B:
			draw_rect(Rect2(at, Vector2(cell, cell)), COLOR_SOLID_B)
		TileGrid.CH_SOLID_INVISIBLE, TileGrid.CH_WALL_INVISIBLE:
			draw_rect(Rect2(at, Vector2(cell, cell)), COLOR_INVISIBLE)
		TileGrid.CH_ONEWAY_A, TileGrid.CH_ONEWAY_B:
			draw_rect(Rect2(at, Vector2(cell, cell * 0.25)), COLOR_ONEWAY)
		TileGrid.CH_HATCH:
			draw_rect(Rect2(at, Vector2(cell, cell * 0.25)), COLOR_HATCH)
		TileGrid.CH_SPIKES_FLOOR:
			draw_rect(Rect2(at + Vector2(0.0, cell * 0.5), Vector2(cell, cell * 0.5)), COLOR_DEADLY)
		TileGrid.CH_SPIKES_CEILING:
			draw_rect(Rect2(at, Vector2(cell, cell * 0.5)), COLOR_DEADLY)
		TileGrid.CH_KILL:
			draw_rect(Rect2(at, Vector2(cell, cell)), COLOR_DEADLY, false, 2.0)
		TileGrid.CH_LIQUID:
			var surface: float = 0.0 if grid.get_char(col, row - 1) == TileGrid.CH_LIQUID else 4.0
			draw_rect(Rect2(at + Vector2(0.0, surface), Vector2(cell, cell - surface)), COLOR_LIQUID)
