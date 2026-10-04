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


## Build the TileSet. Unknown atlas names fall back to the jungle set so the level stays playable; the caller
## reports them (see [method has_terrain] / [method has_liquid]).
static func build(terrain_a: String, terrain_b: String, liquid: String) -> TileSet:
	var tile_set: TileSet = TileSet.new()
	tile_set.tile_size = Vector2i(Tuning.TILE_ART, Tuning.TILE_ART)
	tile_set.add_source(_terrain_source(terrain_a), LevelTiles.SET_A)
	tile_set.add_source(_terrain_source(terrain_b), LevelTiles.SET_B)
	tile_set.add_source(_liquid_source(liquid), LevelTiles.SET_LIQUID)
	return tile_set


## True when the terrain atlas of a [meta] `terrain_a` / `terrain_b` value exists.
static func has_terrain(atlas: String) -> bool:
	return ResourceLoader.exists(LevelData.terrain_path(atlas))


## True when the strip of a [meta] `liquid` value exists.
static func has_liquid(liquid: String) -> bool:
	return ResourceLoader.exists(LevelData.liquid_path(liquid))


static func _terrain_source(atlas: String) -> TileSetAtlasSource:
	var name: String = atlas if has_terrain(atlas) else FALLBACK_TERRAIN
	var source: TileSetAtlasSource = _new_source(LevelData.terrain_path(name))
	for index: int in LevelTiles.ATLAS_TILES:
		source.create_tile(LevelTiles.atlas_coords(index))
	return source


static func _liquid_source(liquid: String) -> TileSetAtlasSource:
	var name: String = liquid if has_liquid(liquid) else FALLBACK_LIQUID
	var source: TileSetAtlasSource = _new_source(LevelData.liquid_path(name))
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
	return source


static func _new_source(texture_path: String) -> TileSetAtlasSource:
	var source: TileSetAtlasSource = TileSetAtlasSource.new()
	source.texture = load(texture_path) as Texture2D
	source.texture_region_size = Vector2i(Tuning.TILE_ART, Tuning.TILE_ART)
	# Pixels map 1:1 to the screen (nearest filter, integer scale, whole-pixel camera): no bleeding to guard
	# against, so the extra padded copy of every atlas is not needed.
	source.use_texture_padding = false
	return source
