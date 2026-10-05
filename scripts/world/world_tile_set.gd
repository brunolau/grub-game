class_name WorldTileSet
extends RefCounted
## Builds the TileSet of a level from its two terrain atlases and its liquid strip (ARCHITECTURE.md 8.5,
## ASSET_MANIFEST 10.1 / 10.2). Owner: world.
##
## Source ids are the LevelTiles sets: 0 = terrain set A, 1 = terrain set B, 2 = liquid. Every terrain atlas has
## the same 8 x 5 layout, so one builder serves all biomes. The TileSet carries no collision: gameplay collision
## is TileGrid.

## Fallback atlas when a level names a terrain that does not exist.
const FALLBACK_TERRAIN: String = "jungle/terrain_grass"
const FALLBACK_LIQUID: String = "water"


## Largest side of the shared atlas (ARCHITECTURE.md 11: no texture over 2048 px).
const MAX_SHARED_SIDE: int = 2048


## Build the TileSet. Unknown atlas names fall back to the jungle set so the level stays playable; the caller
## reports them (see [method has_terrain] / [method has_liquid]).
##
## The three sources share ONE texture: the two terrain atlases and the liquid strip are stacked into one image when
## the level loads, and each source addresses its part with `margins`. Cells of terrain A, terrain B and liquid
## alternate all over a map, and with three textures every switch inside a rendering quadrant started a new draw
## call (up to 93 per frame for the main layer alone); with one texture a quadrant is one batch. When the pixels of
## an atlas cannot be read, every source keeps its own texture (same picture, more draw calls).
static func build(terrain_a: String, terrain_b: String, liquid: String) -> TileSet:
	var tile_set: TileSet = TileSet.new()
	tile_set.tile_size = Vector2i(Tuning.TILE_ART, Tuning.TILE_ART)
	var textures: Array[Texture2D] = [
		load(LevelData.terrain_path(terrain_a if has_terrain(terrain_a) else FALLBACK_TERRAIN)) as Texture2D,
		load(LevelData.terrain_path(terrain_b if has_terrain(terrain_b) else FALLBACK_TERRAIN)) as Texture2D,
		load(LevelData.liquid_path(liquid if has_liquid(liquid) else FALLBACK_LIQUID)) as Texture2D,
	]
	var offsets: Array[Vector2i] = [Vector2i.ZERO, Vector2i.ZERO, Vector2i.ZERO]
	var shared: Texture2D = shared_atlas(textures, offsets)
	for i: int in textures.size():
		var source: TileSetAtlasSource = _new_source(textures[i] if shared == null else shared, offsets[i])
		if i == LevelTiles.SET_LIQUID:
			_add_liquid_tiles(source)
		else:
			for index: int in LevelTiles.ATLAS_TILES:
				source.create_tile(LevelTiles.atlas_coords(index))
		tile_set.add_source(source, i)
	return tile_set


## One texture holding `textures` stacked from top to bottom; `offsets` receives where each one starts. Null (and
## `offsets` all zero) when a texture is missing, its pixels cannot be read or the result would be too large.
static func shared_atlas(textures: Array[Texture2D], offsets: Array[Vector2i]) -> Texture2D:
	var images: Array[Image] = []
	var width: int = 0
	var height: int = 0
	for texture: Texture2D in textures:
		var image: Image = texture.get_image() if texture != null else null
		if image == null or image.is_empty() or image.is_compressed():
			return null
		image = image.duplicate() as Image
		image.convert(Image.FORMAT_RGBA8)
		images.append(image)
		width = maxi(width, image.get_width())
		height += image.get_height()
	if width > MAX_SHARED_SIDE or height > MAX_SHARED_SIDE:
		return null
	var atlas: Image = Image.create_empty(width, height, false, Image.FORMAT_RGBA8)
	var y: int = 0
	for i: int in images.size():
		atlas.blit_rect(images[i], Rect2i(Vector2i.ZERO, images[i].get_size()), Vector2i(0, y))
		offsets[i] = Vector2i(0, y)
		y += images[i].get_height()
	return ImageTexture.create_from_image(atlas)


## True when the terrain atlas of a [meta] `terrain_a` / `terrain_b` value exists.
static func has_terrain(atlas: String) -> bool:
	return ResourceLoader.exists(LevelData.terrain_path(atlas))


## True when the strip of a [meta] `liquid` value exists.
static func has_liquid(liquid: String) -> bool:
	return ResourceLoader.exists(LevelData.liquid_path(liquid))


static func _add_liquid_tiles(source: TileSetAtlasSource) -> void:
	var surface: Vector2i = Vector2i(LevelTiles.LIQUID_SURFACE, 0)
	source.create_tile(surface)
	source.set_tile_animation_frames_count(surface, LevelTiles.LIQUID_SURFACE_FRAMES)
	var frame_seconds: float = Tuning.ticks_to_seconds(Tuning.TILE_ANIM_TICKS)
	for frame: int in LevelTiles.LIQUID_SURFACE_FRAMES:
		source.set_tile_animation_frame_duration(surface, frame, frame_seconds)
	# Neighbouring cells start at different frames: a row of liquid ripples instead of pumping in step.
	source.set_tile_animation_mode(surface, TileSetAtlasSource.TILE_ANIMATION_MODE_RANDOM_START_TIMES)
	source.create_tile(Vector2i(LevelTiles.LIQUID_BODY, 0))
	source.create_tile(Vector2i(LevelTiles.LIQUID_BODY_BUBBLES, 0))


static func _new_source(texture: Texture2D, margins: Vector2i) -> TileSetAtlasSource:
	var source: TileSetAtlasSource = TileSetAtlasSource.new()
	source.texture = texture
	source.margins = margins
	source.texture_region_size = Vector2i(Tuning.TILE_ART, Tuning.TILE_ART)
	# Pixels map 1:1 to the screen (nearest filter, integer scale, whole-pixel camera): no bleeding to guard
	# against, so the extra padded copy of every atlas is not needed.
	source.use_texture_padding = false
	return source
