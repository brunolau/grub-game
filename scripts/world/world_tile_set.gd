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
## 2.0: the tar-floor strip of ':' when neither the liquid nor the biome has its own (ASSET_MANIFEST 17.6).
const TAR_FLOOR_FALLBACK: String = "res://assets/tiles/canyon/mud_floor.png"
## 2.0 liquids drawn as a recolour of the water strip (dark, light) until art-A's strips exist (PLAN P1.6).
const RECOLOURED_LIQUIDS: Dictionary = {
	"tar": [Color("120c0a"), Color("6b5a4e")],
	"honey": [Color("7a3d06"), Color("ffd257")],
	"syrup": [Color("4a0718"), Color("e0476a")],
}


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
static func build(terrain_a: String, terrain_b: String, liquid: String, biome: String = "") -> TileSet:
	var tile_set: TileSet = TileSet.new()
	tile_set.tile_size = Vector2i(Tuning.TILE_ART, Tuning.TILE_ART)
	var textures: Array[Texture2D] = [
		load(LevelData.terrain_path(terrain_a if has_terrain(terrain_a) else FALLBACK_TERRAIN)) as Texture2D,
		load(LevelData.terrain_path(terrain_b if has_terrain(terrain_b) else FALLBACK_TERRAIN)) as Texture2D,
		liquid_texture(liquid, biome),
	]
	var offsets: Array[Vector2i] = [Vector2i.ZERO, Vector2i.ZERO, Vector2i.ZERO]
	var shared: Texture2D = shared_atlas(textures, offsets)
	for i: int in textures.size():
		var source: TileSetAtlasSource = _new_source(textures[i] if shared == null else shared, offsets[i])
		if i == LevelTiles.SET_LIQUID:
			_add_liquid_tiles(source, textures[i])
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


## True when the strip of a [meta] `liquid` value exists. The 2.0 liquids `tar` / `honey` / `syrup` always exist:
## until their strips are drawn (art-A) they are a recolour of the water strip ([method liquid_image]).
static func has_liquid(liquid: String) -> bool:
	return ResourceLoader.exists(LevelData.liquid_path(liquid)) or RECOLOURED_LIQUIDS.has(liquid)


## The liquid source of a level as one texture: the 8 x 1 liquid strip of `liquid` with the 4 x 1 tar-floor strip of
## the ':' tile appended on its right (LevelTiles.TAR_FLOOR_FIRST..). Null only when no strip can be loaded at all.
## When the pixels cannot be read the plain liquid strip is returned (the tar floor is then not drawn).
static func liquid_texture(liquid: String, biome: String = "") -> Texture2D:
	var strip: Image = liquid_image(liquid)
	var floor_strip: Image = tar_floor_image(liquid, biome)
	if strip == null:
		return load(LevelData.liquid_path(FALLBACK_LIQUID)) as Texture2D
	var tile: int = Tuning.TILE_ART
	var width: int = (LevelTiles.LIQUID_COLUMNS + LevelTiles.TAR_FLOOR_COLUMNS) * tile
	var image: Image = Image.create_empty(width, tile, false, Image.FORMAT_RGBA8)
	image.blit_rect(strip, Rect2i(0, 0, mini(strip.get_width(), LevelTiles.LIQUID_COLUMNS * tile), tile), Vector2i.ZERO)
	if floor_strip != null:
		image.blit_rect(floor_strip, Rect2i(0, 0, mini(floor_strip.get_width(), LevelTiles.TAR_FLOOR_COLUMNS * tile),
				tile), Vector2i(LevelTiles.LIQUID_COLUMNS * tile, 0))
	return ImageTexture.create_from_image(image)


## The pixels of the 8 x 1 strip of `liquid` (RGBA8), a recolour of the water strip for a 2.0 liquid whose strip is
## not drawn yet; null when nothing can be read.
static func liquid_image(liquid: String) -> Image:
	var path: String = LevelData.liquid_path(liquid)
	if ResourceLoader.exists(path):
		return _rgba(load(path) as Texture2D)
	var water: Image = _rgba(load(LevelData.liquid_path(FALLBACK_LIQUID)) as Texture2D)
	if water == null or not RECOLOURED_LIQUIDS.has(liquid):
		return water
	return recolour(water, RECOLOURED_LIQUIDS[liquid])


## The pixels of the 4 x 1 tar-floor strip of the ':' tile (top_left, top, top_right, fill; RGBA8) for a level's
## liquid skin and biome, the first that exists of: `tiles/<biome>/<liquid>_floor.png` (the fen's tar),
## `tiles/<biome>/mud_floor.png` (the canyon wallow), `tiles/common/<liquid>_floor.png` (art-A's skin of every
## liquid), `tiles/canyon/mud_floor.png` (recoloured like the liquid for tar, honey and syrup). Null when none exists.
static func tar_floor_image(liquid: String, biome: String = "") -> Image:
	var candidates: PackedStringArray = PackedStringArray()
	if not biome.is_empty():
		candidates.append("%s%s/%s_floor.png" % [LevelData.TERRAIN_DIR, biome, liquid])
		candidates.append("%s%s/mud_floor.png" % [LevelData.TERRAIN_DIR, biome])
	candidates.append("%scommon/%s_floor.png" % [LevelData.TERRAIN_DIR, liquid])
	for path: String in candidates:
		if ResourceLoader.exists(path):
			return _rgba(load(path) as Texture2D)
	if not ResourceLoader.exists(TAR_FLOOR_FALLBACK):
		return null
	var image: Image = _rgba(load(TAR_FLOOR_FALLBACK) as Texture2D)
	if image != null and RECOLOURED_LIQUIDS.has(liquid):
		return recolour(image, RECOLOURED_LIQUIDS[liquid])
	return image


## A copy of `image` mapped onto a two-colour ramp by luminance (dark -> ramp[0], light -> ramp[1]), alpha kept: the
## stand-in look of the 2.0 liquids until their own strips exist.
static func recolour(image: Image, ramp: Array) -> Image:
	var result: Image = image.duplicate() as Image
	var dark: Color = ramp[0]
	var light: Color = ramp[1]
	for y: int in result.get_height():
		for x: int in result.get_width():
			var c: Color = result.get_pixel(x, y)
			if c.a <= 0.0:
				continue
			var mapped: Color = dark.lerp(light, clampf(c.get_luminance() * 1.25, 0.0, 1.0))
			mapped.a = c.a
			result.set_pixel(x, y, mapped)
	return result


static func _rgba(texture: Texture2D) -> Image:
	if texture == null:
		return null
	var image: Image = texture.get_image()
	if image == null or image.is_empty():
		return null
	if image.is_compressed():
		if image.decompress() != OK:
			return null
	image = image.duplicate() as Image
	image.convert(Image.FORMAT_RGBA8)
	return image


static func _add_liquid_tiles(source: TileSetAtlasSource, texture: Texture2D) -> void:
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
	# 2.0: the tar-floor tiles of ':' sit to the right of the liquid strip (liquid_texture).
	if texture == null or texture.get_width() < (LevelTiles.LIQUID_COLUMNS + LevelTiles.TAR_FLOOR_COLUMNS) * Tuning.TILE_ART:
		return
	for i: int in LevelTiles.TAR_FLOOR_COLUMNS:
		source.create_tile(Vector2i(LevelTiles.TAR_FLOOR_FIRST + i, 0))


static func _new_source(texture: Texture2D, margins: Vector2i) -> TileSetAtlasSource:
	var source: TileSetAtlasSource = TileSetAtlasSource.new()
	source.texture = texture
	source.margins = margins
	source.texture_region_size = Vector2i(Tuning.TILE_ART, Tuning.TILE_ART)
	# Pixels map 1:1 to the screen (nearest filter, integer scale, whole-pixel camera): no bleeding to guard
	# against, so the extra padded copy of every atlas is not needed.
	source.use_texture_padding = false
	return source
