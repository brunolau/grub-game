class_name ParallaxSets
extends RefCounted
## The parallax background sets of ASSET_MANIFEST 11 as data. Owner: world.
##
## Every layer image is 360 art px high and drawn for a 360 px high view. The view height is not constant
## (ARCHITECTURE.md 2), so each layer says how it is placed when the view is taller or lower:
##   SKY    opaque sky: stuck to the top; the rest of the view is filled with its bottom-row colour (`fill`)
##   TILE   seamless wall pattern: repeated in both directions from the top-left corner
##   BOTTOM hills, forests, floor bands: stuck to the bottom edge of the view
##   TOP    ceiling bands: stuck to the top edge
##   SPLIT  one image holding a ceiling band (rows 0 .. split_top) and a floor band (rows split_bottom .. 360):
##          the two halves stick to the top and to the bottom edge
## `scroll` is the parallax factor: horizontally the picture moves `scroll` px per px of camera travel and
## repeats after its own width; vertically the edge-anchored bands drift by the same factor towards their edge
## as the view moves away from it (see [method layer_pieces]) and wall patterns scroll and wrap.

enum Anchor { SKY, TILE, BOTTOM, TOP, SPLIT }

const BACKGROUND_DIR: String = "res://assets/backgrounds/"
## Height every layer image is authored for, in art px.
const LAYER_HEIGHT: int = 360
## Colour behind everything when a level has no parallax set (`background = none`).
const NONE_FILL: Color = Color("17120e")

## set name (meta key `background`) -> { "fill": Color, "layers": [ { "file", "scroll", "anchor" [, split] } ] }.
const SETS: Dictionary = {
	"jungle": {
		"fill": Color("bdecff"),
		"layers": [
			{"file": "jungle/layer0_sky", "scroll": 0.0, "anchor": Anchor.SKY},
			{"file": "jungle/layer1_far_hills", "scroll": 0.1, "anchor": Anchor.BOTTOM},
			{"file": "jungle/layer2_hills", "scroll": 0.25, "anchor": Anchor.BOTTOM},
			{"file": "jungle/layer3_forest", "scroll": 0.5, "anchor": Anchor.BOTTOM},
		],
	},
	"cave": {
		"fill": Color("2d2541"),
		"layers": [
			{"file": "cave/layer0_wall", "scroll": 0.1, "anchor": Anchor.TILE},
			{
				"file": "cave/layer1_rocks_far", "scroll": 0.3, "anchor": Anchor.SPLIT,
				"split_top": 113, "split_bottom": 267,
			},
			{"file": "cave/layer2_ceiling_near", "scroll": 0.6, "anchor": Anchor.TOP},
		],
	},
	"ice": {
		"fill": Color("dbf0ff"),
		"layers": [
			{"file": "ice/layer0_sky", "scroll": 0.0, "anchor": Anchor.SKY},
			{"file": "ice/layer1_far_peaks", "scroll": 0.1, "anchor": Anchor.BOTTOM},
			{"file": "ice/layer2_ridges", "scroll": 0.25, "anchor": Anchor.BOTTOM},
			{"file": "ice/layer3_snow_forest", "scroll": 0.5, "anchor": Anchor.BOTTOM},
		],
	},
	"volcano": {
		"fill": Color("ce5520"),
		"layers": [
			{"file": "volcano/layer0_sky", "scroll": 0.0, "anchor": Anchor.SKY},
			{"file": "volcano/layer1_far_cones", "scroll": 0.1, "anchor": Anchor.BOTTOM},
			{"file": "volcano/layer2_basalt", "scroll": 0.25, "anchor": Anchor.BOTTOM},
			{"file": "volcano/layer3_burnt_forest", "scroll": 0.5, "anchor": Anchor.BOTTOM},
		],
	},
	"volcano_shaft": {
		"fill": Color("3f1818"),
		"layers": [
			{"file": "volcano/shaft_layer0_wall", "scroll": 0.1, "anchor": Anchor.TILE},
			{
				"file": "volcano/shaft_layer1_rocks", "scroll": 0.3, "anchor": Anchor.SPLIT,
				"split_top": 113, "split_bottom": 267,
			},
			{"file": "volcano/shaft_layer2_ceiling_near", "scroll": 0.6, "anchor": Anchor.TOP},
		],
	},
	# 2.0 (world 5, Sunbaked Canyon; ASSET_MANIFEST 17.6): blue sky turning cream at the horizon, rose spires and
	# mesas, a dark red-brown ridge in front.
	"canyon": {
		"fill": Color("fff1d6"),
		"layers": [
			{"file": "canyon/layer0_sky", "scroll": 0.0, "anchor": Anchor.SKY},
			{"file": "canyon/layer1_far_spires", "scroll": 0.1, "anchor": Anchor.BOTTOM},
			{"file": "canyon/layer2_mesas", "scroll": 0.25, "anchor": Anchor.BOTTOM},
			{"file": "canyon/layer3_ridge", "scroll": 0.5, "anchor": Anchor.BOTTOM},
		],
	},
	# 2.0 (world 6, Tar Fen; art-B's hand-over): the open fen, Spore Hollow's cave of caps, the hollow mangrove.
	"swamp": {
		"fill": Color("41605a"),
		"layers": [
			{"file": "swamp/layer0_sky", "scroll": 0.0, "anchor": Anchor.SKY},
			{"file": "swamp/layer1_far_isles", "scroll": 0.1, "anchor": Anchor.BOTTOM},
			{"file": "swamp/layer2_banks", "scroll": 0.25, "anchor": Anchor.BOTTOM},
			{"file": "swamp/layer3_reeds", "scroll": 0.5, "anchor": Anchor.BOTTOM},
		],
	},
	"mushroom": {
		"fill": Color("1c1028"),
		"layers": [
			{"file": "swamp/mushroom_layer0_wall", "scroll": 0.1, "anchor": Anchor.TILE},
			{
				"file": "swamp/mushroom_layer1_rocks_far", "scroll": 0.3, "anchor": Anchor.SPLIT,
				"split_top": 113, "split_bottom": 267,
			},
			{"file": "swamp/mushroom_layer2_ceiling_near", "scroll": 0.6, "anchor": Anchor.TOP},
		],
	},
	"mangrove": {
		"fill": Color("1e1610"),
		"layers": [
			{"file": "swamp/trunk_layer0_wall", "scroll": 0.1, "anchor": Anchor.TILE},
			{
				"file": "swamp/trunk_layer1_roots_far", "scroll": 0.3, "anchor": Anchor.SPLIT,
				"split_top": 113, "split_bottom": 267,
			},
			{"file": "swamp/trunk_layer2_ceiling_near", "scroll": 0.6, "anchor": Anchor.TOP},
		],
	},
	# 2.0 (worlds 7-9; art-B's hand-over wf8_art-B_to_world-A.txt): Shell Beach's coast and the sea caves of 7-2 / 7-2b;
	# the Idol Ruins outside (8-1) and the temple halls inside (8-2 / 8-2b); the Sky Spire by day (9-1), in the storm
	# (9-1b, 9-2, 9-2b) and at the sunset pyre (9-3).
	"coast": {
		"fill": Color("77d9ff"),
		"layers": [
			{"file": "coast/layer0_sky", "scroll": 0.0, "anchor": Anchor.SKY},
			{"file": "coast/layer1_far_isles", "scroll": 0.1, "anchor": Anchor.BOTTOM},
			{"file": "coast/layer2_cliffs", "scroll": 0.25, "anchor": Anchor.BOTTOM},
			{"file": "coast/layer3_dunes", "scroll": 0.5, "anchor": Anchor.BOTTOM},
		],
	},
	"sea_cave": {
		"fill": Color("0e1c22"),
		"layers": [
			{"file": "coast/cave_layer0_wall", "scroll": 0.1, "anchor": Anchor.TILE},
			{
				"file": "coast/cave_layer1_rocks_far", "scroll": 0.3, "anchor": Anchor.SPLIT,
				"split_top": 113, "split_bottom": 267,
			},
			{"file": "coast/cave_layer2_ceiling_near", "scroll": 0.6, "anchor": Anchor.TOP},
		],
	},
	"ruins": {
		"fill": Color("feedc6"),
		"layers": [
			{"file": "ruins/layer0_sky", "scroll": 0.0, "anchor": Anchor.SKY},
			{"file": "ruins/layer1_far_temples", "scroll": 0.1, "anchor": Anchor.BOTTOM},
			{"file": "ruins/layer2_hills", "scroll": 0.25, "anchor": Anchor.BOTTOM},
			{"file": "ruins/layer3_canopy", "scroll": 0.5, "anchor": Anchor.BOTTOM},
		],
	},
	"temple": {
		"fill": Color("1c1618"),
		"layers": [
			{"file": "ruins/temple_layer0_wall", "scroll": 0.1, "anchor": Anchor.TILE},
			{
				"file": "ruins/temple_layer1_pillars", "scroll": 0.3, "anchor": Anchor.SPLIT,
				"split_top": 113, "split_bottom": 267,
			},
			{"file": "ruins/temple_layer2_ceiling_near", "scroll": 0.6, "anchor": Anchor.TOP},
		],
	},
	"sky": {
		"fill": Color("bedafb"),
		"layers": [
			{"file": "sky/layer0_sky", "scroll": 0.0, "anchor": Anchor.SKY},
			{"file": "sky/layer1_far_isles", "scroll": 0.06, "anchor": Anchor.BOTTOM},
			{"file": "sky/layer2_clouds", "scroll": 0.2, "anchor": Anchor.BOTTOM},
			{"file": "sky/layer3_cloud_sea", "scroll": 0.45, "anchor": Anchor.BOTTOM},
		],
	},
	"storm": {
		"fill": Color("525470"),
		"layers": [
			{"file": "sky/storm_layer0_sky", "scroll": 0.0, "anchor": Anchor.SKY},
			{"file": "sky/storm_layer1_far_isles", "scroll": 0.06, "anchor": Anchor.BOTTOM},
			{"file": "sky/storm_layer2_clouds", "scroll": 0.2, "anchor": Anchor.BOTTOM},
			{"file": "sky/storm_layer3_cloud_sea", "scroll": 0.45, "anchor": Anchor.BOTTOM},
		],
	},
	"pyre": {
		"fill": Color("fb8d31"),
		"layers": [
			{"file": "sky/pyre_layer0_sky", "scroll": 0.0, "anchor": Anchor.SKY},
			{"file": "sky/pyre_layer1_far_isles", "scroll": 0.06, "anchor": Anchor.BOTTOM},
			{"file": "sky/pyre_layer2_clouds", "scroll": 0.2, "anchor": Anchor.BOTTOM},
			{"file": "sky/pyre_layer3_cloud_sea", "scroll": 0.45, "anchor": Anchor.BOTTOM},
		],
	},
	"feast": {
		"fill": Color("feb0d1"),
		"layers": [
			{"file": "feast/layer0_sky", "scroll": 0.0, "anchor": Anchor.SKY},
			{"file": "feast/layer1_clouds", "scroll": 0.08, "anchor": Anchor.BOTTOM},
			{"file": "feast/layer2_scoops", "scroll": 0.25, "anchor": Anchor.BOTTOM},
			{"file": "feast/layer3_meadow", "scroll": 0.5, "anchor": Anchor.BOTTOM},
		],
	},
}


## True when `set_name` is a set that has layers ("none" and unknown names have none).
static func has_set(set_name: String) -> bool:
	return SETS.has(set_name)


## Layers of a set, back to front ([] for "none" / unknown names).
static func layers(set_name: String) -> Array:
	if not SETS.has(set_name):
		return []
	return SETS[set_name]["layers"]


## Colour that fills the view behind the layers of a set.
static func fill_color(set_name: String) -> Color:
	if not SETS.has(set_name):
		return NONE_FILL
	return SETS[set_name]["fill"]


## Resource path of a layer image.
static func texture_path(layer: Dictionary) -> String:
	return "%s%s.png" % [BACKGROUND_DIR, layer["file"]]


## Horizontal offset into a layer image for a camera whose left edge is at `camera_x` art px: whole pixels,
## wrapped to the image width (the loop length).
static func scroll_offset(camera_x: float, scroll: float, width: int) -> int:
	if width <= 0:
		return 0
	return posmod(floori(camera_x * scroll), width)


## The pieces of one layer for a view of `view_size` art px: an Array of [destination Rect2 in view coordinates,
## source Rect2 in image coordinates]. The source may run past the image width (the image repeats).
## Vertical parallax: `sink` is how far (art px) the view is above its lowest position and `rise` how far it is
## below its highest; bands anchored to the bottom sink by `sink * scroll`, bands anchored to the top rise by
## `rise * scroll` (at most their own height), so climbing lets the near hills drop away while the sky stays.
static func layer_pieces(layer: Dictionary, image_size: Vector2i, view_size: Vector2, offset_x: int,
		sink: float = 0.0, rise: float = 0.0) -> Array:
	var pieces: Array = []
	var w: float = view_size.x
	var h: float = view_size.y
	var image_h: float = float(image_size.y)
	var scroll: float = float(layer["scroll"])
	var down: float = clampf(floorf(sink * scroll), 0.0, image_h)
	var up: float = clampf(floorf(rise * scroll), 0.0, image_h)
	match int(layer["anchor"]):
		Anchor.SKY:
			pieces.append([Rect2(0.0, 0.0, w, image_h), Rect2(offset_x, 0.0, w, image_h)])
		Anchor.TOP:
			pieces.append([Rect2(0.0, -up, w, image_h), Rect2(offset_x, 0.0, w, image_h)])
		Anchor.TILE:
			pieces.append([Rect2(0.0, 0.0, w, h), Rect2(offset_x, 0.0, w, h)])
		Anchor.BOTTOM:
			pieces.append([Rect2(0.0, h - image_h + down, w, image_h), Rect2(offset_x, 0.0, w, image_h)])
		Anchor.SPLIT:
			var top: float = float(layer["split_top"])
			var bottom: float = float(layer["split_bottom"])
			pieces.append([Rect2(0.0, -minf(up, top), w, top), Rect2(offset_x, 0.0, w, top)])
			pieces.append([
				Rect2(0.0, h - (image_h - bottom) + minf(down, image_h - bottom), w, image_h - bottom),
				Rect2(offset_x, bottom, w, image_h - bottom),
			])
	return pieces
