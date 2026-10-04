class_name Spawner
extends RefCounted
## Entity spawning by naming convention (docs/ARCHITECTURE.md 6).
##
## CONTRACT FILE. Owner: core. An entity id is "<category>/<name>" and maps to the scene
## `res://scenes/<category>/<name>.tscn`. There is no registry file: a module adds an entity by adding its scene.
## Ids starting with "props/" are plain scenery images (`res://assets/tiles/<biome>/props/<name>.png`) and have
## no scene; the level loader draws them itself.

const SCENE_ROOT: String = "res://scenes/"
const PROP_PREFIX: String = "props/"
const PROP_ROOT: String = "res://assets/tiles/"
## Categories an entity id may use, and the module that owns the scenes (see the ownership table).
const CATEGORIES: Array[String] = [
	"player", "enemies", "bosses", "projectiles", "objects", "items", "zones", "fx", "props",
]

static var _cache: Dictionary = {}
static var _missing: Dictionary = {}


## Scene path of an entity id: "enemies/walker" -> "res://scenes/enemies/walker.tscn".
static func scene_path(id: StringName) -> String:
	return SCENE_ROOT + String(id) + ".tscn"


## Category of an entity id: "enemies/walker" -> "enemies" ("" when the id has no slash).
static func category(id: StringName) -> String:
	var text: String = String(id)
	var slash: int = text.find("/")
	return text.substr(0, slash) if slash > 0 else ""


## True for scenery ids ("props/<biome>/<name>").
static func is_prop(id: StringName) -> bool:
	return String(id).begins_with(PROP_PREFIX)


## Texture path of a scenery id: "props/jungle/bush_big" -> "res://assets/tiles/jungle/props/bush_big.png".
static func prop_texture_path(id: StringName) -> String:
	var parts: PackedStringArray = String(id).split("/")
	if parts.size() != 3:
		return ""
	return "%s%s/props/%s.png" % [PROP_ROOT, parts[1], parts[2]]


## True when the id is well formed and its scene (or prop texture) exists.
static func exists(id: StringName) -> bool:
	if is_prop(id):
		return ResourceLoader.exists(prop_texture_path(id))
	if not CATEGORIES.has(category(id)):
		return false
	return ResourceLoader.exists(scene_path(id))


## Load (and cache) the scene of an entity id. Returns null and reports the id ONCE when it does not exist.
static func load_scene(id: StringName) -> PackedScene:
	if _cache.has(id):
		return _cache[id]
	if _missing.has(id):
		return null
	var path: String = scene_path(id)
	if not CATEGORIES.has(category(id)) or not ResourceLoader.exists(path):
		_missing[id] = true
		push_warning("Spawner: no scene for entity id '%s' (expected %s)" % [id, path])
		return null
	var scene: PackedScene = load(path) as PackedScene
	if scene == null:
		_missing[id] = true
		push_error("Spawner: %s is not a PackedScene" % path)
		return null
	_cache[id] = scene
	return scene


## Instantiate an entity scene (not yet in the tree, not yet set up). Returns null when the scene is missing.
static func instantiate(id: StringName) -> Node:
	var scene: PackedScene = load_scene(id)
	if scene == null:
		return null
	return scene.instantiate()


## Load the scenes of several ids ahead of time (level loading screen) so that spawning never hitches.
static func preload_ids(ids: Array[StringName]) -> void:
	for id: StringName in ids:
		if not is_prop(id):
			load_scene(id)


## Drop the cache (level change, tests).
static func clear_cache() -> void:
	_cache.clear()
	_missing.clear()
