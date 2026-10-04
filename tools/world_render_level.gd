extends SceneTree
## Renders a whole level into one PNG for level designers (docs/LEVEL_DESIGN.md "Preview"). Owner: world.
##
## Usage (from the project root; works headless, everything is drawn on the CPU):
##   bash .tools/gd.sh script res://tools/world_render_level.gd -- w1_l1
##   bash .tools/gd.sh script res://tools/world_render_level.gd -- levels/w1_l1.lvl --collision
##   bash .tools/gd.sh script res://tools/world_render_level.gd -- --all --scale=0.5
## Options:
##   <id or path> ...   levels to render (ids are looked up in res://levels)
##   --all              every level in res://levels
##   --collision        also write <id>_collision.png: collision colours, entity boxes, zones, camera locks
##   --difficulty=expert   spawn set of Expert (default beginner)
##   --scale=<f>        scale the picture (0.5 = half size), default 1 (one art pixel per pixel)
##   --out=<dir>        output folder, default res://build/level_previews
##
## The picture is what the level scene shows, laid out flat: the parallax set as if the whole level were one
## view, back walls, back props, terrain, entities at their spawn points (their scene's `Sprite` frame when the
## scene exists, a labelled marker otherwise), front props and liquids. Exit code 0 = written, 1 = a level could
## not be read, 2 = bad arguments.
##
## This script is compiled before the autoloads exist: it must not name classes that use them (SimEntity and the
## entity scripts); entity scenes are only touched through Spawner and duck typing.

const LEVEL_DIR: String = "res://levels"
const DEFAULT_OUT: String = "res://build/level_previews"
const FONT_PATH: String = "res://assets/fonts/font_hud.png"
const FONT_CELL: int = 20
const FONT_COLUMNS: int = 15
const MARKER_SIZE: int = 28

## Collision overlay colours.
const C_SOLID: Color = Color(0.9, 0.15, 0.15, 0.35)
const C_ONEWAY: Color = Color(1.0, 0.85, 0.1, 0.85)
const C_HATCH: Color = Color(1.0, 0.5, 0.1, 0.85)
const C_SLOPE: Color = Color(0.9, 0.35, 0.1, 0.45)
const C_DEADLY: Color = Color(1.0, 0.0, 0.9, 0.55)
const C_WALL: Color = Color(0.2, 0.5, 1.0, 0.5)
const C_ICE: Color = Color(0.4, 0.9, 1.0, 0.5)
const C_GRID: Color = Color(1.0, 1.0, 1.0, 0.08)
const C_BOX: Color = Color(1.0, 1.0, 0.2, 0.95)
const C_HERO: Color = Color(0.3, 1.0, 0.4, 0.95)
const C_ZONE: Color = Color(0.2, 1.0, 1.0, 0.9)
const C_MARKER: Color = Color(0.15, 0.12, 0.1, 0.8)

var _images: Dictionary = {}   # path -> Image (RGBA8)
var _font: Image = null


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var targets: PackedStringArray = PackedStringArray()
	var collision: bool = false
	var difficulty: int = Defs.Difficulty.BEGINNER
	var scale: float = 1.0
	var out_dir: String = DEFAULT_OUT
	for argument: String in OS.get_cmdline_user_args():
		if argument == "--all":
			for file: String in _level_files():
				targets.append(file)
		elif argument == "--collision":
			collision = true
		elif argument.begins_with("--difficulty="):
			difficulty = Defs.Difficulty.EXPERT if argument.ends_with("expert") else Defs.Difficulty.BEGINNER
		elif argument.begins_with("--scale="):
			scale = clampf(argument.get_slice("=", 1).to_float(), 0.05, 4.0)
		elif argument.begins_with("--out="):
			out_dir = argument.get_slice("=", 1)
		elif argument.begins_with("--"):
			print("world_render_level: unknown option %s" % argument)
			_finish(2)
			return
		else:
			targets.append(_level_path(argument))
	if targets.is_empty():
		print("world_render_level: name at least one level (id or path) or --all")
		_finish(2)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	_font = _image(FONT_PATH)
	var failed: bool = false
	for path: String in targets:
		var data: LevelData = LevelData.load_file(path)
		if data == null:
			print("world_render_level: cannot read %s" % path)
			failed = true
			continue
		var picture: Image = _render(data, difficulty, false)
		_save(picture, scale, "%s/%s.png" % [out_dir, data.id])
		if collision:
			_save(_render(data, difficulty, true), scale, "%s/%s_collision.png" % [out_dir, data.id])
	_finish(1 if failed else 0)


func _level_files() -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	var dir: DirAccess = DirAccess.open(LEVEL_DIR)
	if dir == null:
		return result
	var names: PackedStringArray = dir.get_files()
	names.sort()
	for file_name: String in names:
		if file_name.get_extension() == "lvl":
			result.append(LEVEL_DIR.path_join(file_name))
	return result


func _level_path(argument: String) -> String:
	var text: String = argument.replace("\\", "/")
	if not text.ends_with(".lvl"):
		return "%s/%s.lvl" % [LEVEL_DIR, text]
	if text.begins_with("res://"):
		return text
	return "res://" + text.trim_prefix("./")


func _save(picture: Image, scale: float, path: String) -> void:
	if not is_equal_approx(scale, 1.0):
		var size: Vector2i = Vector2i(maxi(roundi(picture.get_width() * scale), 1),
				maxi(roundi(picture.get_height() * scale), 1))
		picture.resize(size.x, size.y, Image.INTERPOLATE_NEAREST if scale >= 1.0 else Image.INTERPOLATE_BILINEAR)
	var absolute: String = ProjectSettings.globalize_path(path)
	var err: Error = picture.save_png(absolute)
	if err == OK:
		print("world_render_level: wrote %s (%d x %d)" % [absolute, picture.get_width(), picture.get_height()])
	else:
		print("world_render_level: cannot write %s (error %d)" % [absolute, err])


# =================================================================================================================
# Rendering
# =================================================================================================================

func _render(data: LevelData, difficulty: int, collision: bool) -> Image:
	var grid: TileGrid = data.build_grid(difficulty)
	var looks: LevelLooks = LevelLooks.new()
	looks.setup(data, grid)
	var size: Vector2i = Vector2i(maxi(grid.cols, 1), maxi(grid.rows, 1)) * Tuning.TILE_ART
	var picture: Image = Image.create_empty(size.x, size.y, false, Image.FORMAT_RGBA8)
	var meta: Dictionary = data.resolved_meta(difficulty)
	_draw_background(picture, str(meta.get("background", "none")))
	var sets: Array[Image] = [
		_image(LevelData.terrain_path(str(meta.get("terrain_a", WorldTileSet.FALLBACK_TERRAIN)))),
		_image(LevelData.terrain_path(str(meta.get("terrain_b", WorldTileSet.FALLBACK_TERRAIN)))),
		_image(LevelData.liquid_path(str(meta.get("liquid", WorldTileSet.FALLBACK_LIQUID)))),
	]
	var records: Array[Dictionary] = []
	for record: Dictionary in data.entity_records():
		if LevelText.applies_to(record["params"], difficulty):
			records.append(record)
	var back_sets: Array[Image] = []
	for atlas: Image in sets:
		back_sets.append(_tinted(atlas, LevelLooks.BACK_TINT))
	_draw_layer(picture, looks, back_sets, LevelLooks.Layer.BACK)
	_draw_props(picture, records, "back")
	_draw_layer(picture, looks, sets, LevelLooks.Layer.MAIN)
	var boxes: Array[Rect2i] = []
	for z: int in [Defs.Z_OBJECTS, Defs.Z_ITEMS, Defs.Z_ENEMIES]:
		_draw_entities(picture, records, z, boxes)
	var starts: Array[Vector2i] = data.find_starts()
	for start: Vector2i in starts:
		var feet: Vector2i = LevelText.cell_to_feet(float(start.x), float(start.y))
		if not _draw_entity_sprite(picture, &"player/player", feet, {}, boxes):
			_draw_marker(picture, feet, "@", C_HERO)
	_draw_props(picture, records, "front")
	_draw_layer(picture, looks, sets, LevelLooks.Layer.FRONT)
	if collision:
		_draw_collision(picture, grid, records, boxes, starts)
	return picture


## The parallax set as if the whole level were one view (ParallaxSets placement rules, no scrolling).
func _draw_background(picture: Image, set_name: String) -> void:
	var view: Vector2 = Vector2(picture.get_width(), picture.get_height())
	picture.fill(ParallaxSets.fill_color(set_name))
	for layer: Dictionary in ParallaxSets.layers(set_name):
		var source: Image = _image(ParallaxSets.texture_path(layer))
		if source == null:
			continue
		for piece: Array in ParallaxSets.layer_pieces(layer, source.get_size(), view, 0):
			_blend_repeat(picture, source, Rect2i(piece[0]), Rect2i(piece[1]))


## Blend `dest` with the picture `source`, repeating it from `src_origin` in both directions.
func _blend_repeat(picture: Image, source: Image, dest: Rect2i, src: Rect2i) -> void:
	var size: Vector2i = source.get_size()
	var y: int = 0
	while y < dest.size.y:
		var sy: int = posmod(src.position.y + y, size.y)
		var h: int = mini(size.y - sy, dest.size.y - y)
		var x: int = 0
		while x < dest.size.x:
			var sx: int = posmod(src.position.x + x, size.x)
			var w: int = mini(size.x - sx, dest.size.x - x)
			picture.blend_rect(source, Rect2i(sx, sy, w, h), dest.position + Vector2i(x, y))
			x += w
		y += h


func _draw_layer(picture: Image, looks: LevelLooks, sets: Array[Image], layer: LevelLooks.Layer) -> void:
	for row: int in looks.rows:
		for col: int in looks.cols:
			var look: int = looks.look_at(col, row, layer)
			if look < 0:
				continue
			var set_id: int = LevelTiles.look_set(look)
			var atlas: Image = sets[set_id]
			if atlas == null:
				continue
			var index: int = LevelTiles.look_index(look)
			var cell: Vector2i = Vector2i(index, 0) if set_id == LevelTiles.SET_LIQUID \
					else LevelTiles.atlas_coords(index)
			picture.blend_rect(atlas, Rect2i(cell * Tuning.TILE_ART, Vector2i(Tuning.TILE_ART, Tuning.TILE_ART)),
					Vector2i(col, row) * Tuning.TILE_ART)


func _draw_props(picture: Image, records: Array[Dictionary], layer: String) -> void:
	for record: Dictionary in records:
		var id: StringName = record["id"]
		var params: Dictionary = record["params"]
		if not Spawner.is_prop(id) or str(params.get("layer", "back")) != layer:
			continue
		var texture: Image = _image(Spawner.prop_texture_path(id))
		if texture == null:
			continue
		if params.has("flip") and bool(params["flip"]):
			texture = texture.duplicate() as Image
			texture.flip_x()
		var feet: Vector2i = LevelText.cell_to_feet(float(record["col"]), float(record["row"]), params)
		var at: Vector2i = LevelLooks.prop_top_left(id, feet, texture.get_size())
		picture.blend_rect(texture, Rect2i(Vector2i.ZERO, texture.get_size()), at)


func _draw_entities(picture: Image, records: Array[Dictionary], z: int, boxes: Array[Rect2i]) -> void:
	for record: Dictionary in records:
		var id: StringName = record["id"]
		var category: String = Spawner.category(id)
		if Spawner.is_prop(id) or category == "zones" or _z_of(category) != z:
			continue
		var params: Dictionary = record["params"]
		var feet: Vector2i = LevelText.cell_to_feet(float(record["col"]), float(record["row"]), params)
		if not _draw_entity_sprite(picture, id, feet, params, boxes):
			_draw_marker(picture, feet, String(id).get_file(), C_MARKER)


func _z_of(category: String) -> int:
	match category:
		"items":
			return Defs.Z_ITEMS
		"enemies", "bosses":
			return Defs.Z_ENEMIES
	return Defs.Z_OBJECTS


## Draw the current frame of the entity scene's `Sprite` with its feet point at `feet`. False when the scene or
## its sprite does not exist.
func _draw_entity_sprite(picture: Image, id: StringName, feet: Vector2i, params: Dictionary,
		boxes: Array[Rect2i]) -> bool:
	if not Spawner.exists(id):
		return false
	var node: Node = Spawner.instantiate(id)
	if node == null:
		return false
	# Duck-typed on purpose: naming SimEntity here would compile it before the autoloads it uses exist.
	if node.has_method("spawn_setup") and node.has_method("get_box"):
		node.call("spawn_setup", feet, params.duplicate())
		var box: Rect2i = node.call("get_box")
		boxes.append(box)
	var sprite: Sprite2D = node.get_node_or_null("Sprite") as Sprite2D
	var drawn: bool = false
	if sprite != null and sprite.texture != null:
		var source: Image = _image(sprite.texture.resource_path)
		if source != null:
			var frame_size: Vector2i = Vector2i(source.get_width() / maxi(sprite.hframes, 1),
					source.get_height() / maxi(sprite.vframes, 1))
			var columns: int = maxi(sprite.hframes, 1)
			var cell: Vector2i = Vector2i(sprite.frame % columns, sprite.frame / columns)
			var region: Rect2i = Rect2i(cell * frame_size, frame_size)
			if sprite.region_enabled:
				region = Rect2i(sprite.region_rect)
			var frame: Image = source.get_region(region)
			if sprite.flip_h:
				frame.flip_x()
			var offset: Vector2 = sprite.offset - (Vector2(frame_size) * 0.5 if sprite.centered else Vector2.ZERO)
			var at: Vector2i = feet * Tuning.ART_SCALE + Vector2i(sprite.position + offset)
			picture.blend_rect(frame, Rect2i(Vector2i.ZERO, frame.get_size()), at)
			drawn = true
	node.free()
	return drawn


func _draw_marker(picture: Image, feet: Vector2i, label: String, color: Color) -> void:
	var anchor: Vector2i = feet * Tuning.ART_SCALE
	var box: Rect2i = Rect2i(anchor.x - MARKER_SIZE / 2, anchor.y - MARKER_SIZE, MARKER_SIZE, MARKER_SIZE)
	_fill(picture, box, color)
	_outline(picture, box, Color.WHITE)
	_text(picture, label.substr(0, 10), Vector2i(anchor.x - MARKER_SIZE / 2, anchor.y - MARKER_SIZE - FONT_CELL))


func _draw_collision(picture: Image, grid: TileGrid, records: Array[Dictionary], boxes: Array[Rect2i],
		starts: Array[Vector2i]) -> void:
	var cell_size: int = Tuning.TILE_ART
	for row: int in grid.rows:
		for col: int in grid.cols:
			var at: Vector2i = Vector2i(col, row) * cell_size
			_outline(picture, Rect2i(at, Vector2i(cell_size, cell_size)), C_GRID)
			var floor_value: int = grid.floor_at(col, row)
			var side: int = grid.side_at(col, row)
			var profile: int = grid.profile_at(col, row)
			if profile >= TileGrid.PROFILE_UP_RIGHT_45 and profile <= TileGrid.PROFILE_UP_LEFT_LOW:
				for x: int in Tuning.TILE:
					var top: int = TileGrid.profile_offset(profile, x) * Tuning.ART_SCALE
					_fill(picture, Rect2i(at.x + x * Tuning.ART_SCALE, at.y + top, Tuning.ART_SCALE, cell_size - top),
							C_SLOPE)
			elif side == TileGrid.SIDE_WALL and grid.ceiling_at(col, row) == TileGrid.CEILING_SOLID:
				_fill(picture, Rect2i(at, Vector2i(cell_size, cell_size)), C_SOLID)
			elif side == TileGrid.SIDE_WALL:
				_fill(picture, Rect2i(at, Vector2i(cell_size, cell_size)), C_WALL)
			if side == TileGrid.SIDE_DEADLY or floor_value == TileGrid.FLOOR_DEADLY \
					or grid.ceiling_at(col, row) == TileGrid.CEILING_DEADLY:
				_fill(picture, Rect2i(at, Vector2i(cell_size, cell_size)), C_DEADLY)
			elif floor_value == TileGrid.FLOOR_HATCH:
				_fill(picture, Rect2i(at, Vector2i(cell_size, 6)), C_HATCH)
			elif floor_value >= TileGrid.FLOOR_SOLID and floor_value <= TileGrid.FLOOR_ICE_3 and side == 0 \
					and profile <= TileGrid.PROFILE_FLAT_GLUE:
				_fill(picture, Rect2i(at, Vector2i(cell_size, 6)), C_ONEWAY)
			if TileGrid.floor_ice(floor_value) > 0:
				_fill(picture, Rect2i(at + Vector2i(0, 6), Vector2i(cell_size, 4)), C_ICE)
	for box: Rect2i in boxes:
		_outline(picture, Rect2i(box.position * Tuning.ART_SCALE, box.size * Tuning.ART_SCALE), C_BOX)
	for start: Vector2i in starts:
		var feet: Vector2i = LevelText.cell_to_feet(float(start.x), float(start.y))
		var hero: Vector3i = Tuning.HERO_BOX_STAND
		_outline(picture, Rect2i((feet - Vector2i(hero.z, hero.y)) * Tuning.ART_SCALE,
				Vector2i(hero.x, hero.y) * Tuning.ART_SCALE), C_HERO)
	for record: Dictionary in records:
		var params: Dictionary = record["params"]
		var id: StringName = record["id"]
		if Spawner.category(id) == "zones" or params.has("zone") or params.has("trigger"):
			var key: String = "rect" if params.has("rect") else ("zone" if params.has("zone") else "trigger")
			var parts: PackedInt32Array = LevelText.to_int_list(params.get(key, ""))
			if parts.size() == 4:
				var rect: Rect2i = Rect2i(parts[0], parts[1], parts[2], parts[3])
				var art: Rect2i = Rect2i(rect.position * Tuning.TILE_ART, rect.size * Tuning.TILE_ART)
				_outline(picture, art, C_ZONE)
				_outline(picture, art.grow(-1), C_ZONE)
				_text(picture, "%s %s" % [String(id).get_file(), str(params.get("name", ""))],
						art.position + Vector2i(4, 4))
		if params.has("lock"):
			var cell: PackedInt32Array = LevelText.to_int_list(params["lock"])
			if cell.size() == 2:
				var view: Rect2i = Rect2i(Vector2i(cell[0], cell[1]) * Tuning.TILE_ART,
						Vector2i(Tuning.VIEW_W, Tuning.VIEW_H) * Tuning.ART_SCALE)
				_outline(picture, view, C_ZONE)
				_text(picture, "lock %s" % str(params.get("name", "")), view.position + Vector2i(4, 4))


# =================================================================================================================
# Image helpers
# =================================================================================================================

func _image(path: String) -> Image:
	if _images.has(path):
		return _images[path]
	var image: Image = null
	var absolute: String = ProjectSettings.globalize_path(path)
	if path != "" and FileAccess.file_exists(absolute):
		image = Image.load_from_file(absolute)
		if image != null:
			image.convert(Image.FORMAT_RGBA8)
	_images[path] = image
	return image


## A copy of `image` multiplied by `tint` (null stays null).
func _tinted(image: Image, tint: Color) -> Image:
	if image == null:
		return null
	var copy: Image = image.duplicate() as Image
	for y: int in copy.get_height():
		for x: int in copy.get_width():
			copy.set_pixel(x, y, copy.get_pixel(x, y) * tint)
	return copy


func _fill(picture: Image, rect: Rect2i, color: Color) -> void:
	var clipped: Rect2i = rect.intersection(Rect2i(Vector2i.ZERO, picture.get_size()))
	if clipped.size.x <= 0 or clipped.size.y <= 0:
		return
	var patch: Image = Image.create_empty(clipped.size.x, clipped.size.y, false, Image.FORMAT_RGBA8)
	patch.fill(color)
	picture.blend_rect(patch, Rect2i(Vector2i.ZERO, clipped.size), clipped.position)


func _outline(picture: Image, rect: Rect2i, color: Color) -> void:
	_fill(picture, Rect2i(rect.position, Vector2i(rect.size.x, 1)), color)
	_fill(picture, Rect2i(rect.position + Vector2i(0, rect.size.y - 1), Vector2i(rect.size.x, 1)), color)
	_fill(picture, Rect2i(rect.position, Vector2i(1, rect.size.y)), color)
	_fill(picture, Rect2i(rect.position + Vector2i(rect.size.x - 1, 0), Vector2i(1, rect.size.y)), color)


## Text with the HUD bitmap font (upper case, 16 px advance).
func _text(picture: Image, text: String, at: Vector2i) -> void:
	if _font == null:
		return
	var x: int = at.x
	for i: int in text.length():
		var code: int = text.to_upper().unicode_at(i) - 32
		if code >= 0 and code < FONT_COLUMNS * 8:
			var cell: Vector2i = Vector2i(code % FONT_COLUMNS, code / FONT_COLUMNS) * FONT_CELL
			picture.blend_rect(_font, Rect2i(cell, Vector2i(FONT_CELL, FONT_CELL)), Vector2i(x, at.y))
		x += FONT_CELL - 4


func _finish(code: int) -> void:
	# Release the cached entity scenes and pictures before the engine shuts down (no leak reports).
	Spawner.clear_cache()
	_images.clear()
	_font = null
	var audio: Node = root.get_node_or_null("Audio")
	if audio != null and audio.has_method("shutdown"):
		audio.call("shutdown")
	await create_timer(0.1).timeout
	quit(code)
