class_name VersusArena
extends RefCounted
## Versus arenas (`kind = arena`, docs/expansion/DESIGN.md E.5, LEVEL_DESIGN.md 15.8): the static facts of an arena
## file and the one call that turns a loaded level into a versus stage. Owner: world-B (docs/expansion/PLAN.md P1.7).
##
## An arena is one 20 x 11 screen (a 20 x 12 file: floor row 10, fill row 11). [method setup] is called by the level
## loader right after the heroes are spawned (Level._spawn_entities, after LevelBase.spawn_party_heroes): it locks the
## camera to the arena view and registers the [VersusReferee] as the level's party driver, so the referee ticks after
## every hero (LevelBase.register_party_driver) - the PvP rules of PHYSICS.md C.14, the wrap edges, the round. A
## non-arena level is left alone, so a single-player or co-op level never meets any of this.

## Arena edges (meta `wrap`).
const WRAP_NONE: int = 0
const WRAP_LR: int = 1
const WRAP_TB: int = 2
const WRAP_NAMES: Array[String] = ["none", "lr", "tb"]


## True for the [meta] of an arena file (`kind = arena`; the loader's resolved meta or a parsed one).
static func is_arena_meta(meta: Dictionary) -> bool:
	return str(meta.get("kind", "")) == LevelText.KIND_ARENA


## True when `level` is an arena (null: false).
static func is_arena(level: LevelBase) -> bool:
	return level != null and is_arena_meta(level.meta)


## The arena view in logical px: the authentic 20 x 11 screen at the map origin (VersusTuning.ARENA_COLS / ROWS).
static func view_rect() -> Rect2i:
	return Rect2i(0, 0, VersusTuning.ARENA_COLS * Tuning.TILE, VersusTuning.ARENA_ROWS * Tuning.TILE)


## The arena's edges from its meta `wrap` (WRAP_NONE for anything else).
static func wrap_mode(meta: Dictionary) -> int:
	return maxi(WRAP_NAMES.find(str(meta.get("wrap", "none"))), WRAP_NONE)


## The versus modes the arena lists in `modes` (Defs.VersusMode values, unknown names skipped, file order).
static func modes_of(meta: Dictionary) -> PackedInt32Array:
	var result: PackedInt32Array = PackedInt32Array()
	for mode_name: String in LevelText.to_list(meta.get("modes", "")):
		var mode: int = Defs.versus_mode_from_name(StringName(mode_name.strip_edges()))
		if mode >= 0 and not result.has(mode):
			result.append(mode)
	return result


## The default mode of an arena: its first `modes` entry, Grub Stack when it names none.
static func default_mode(meta: Dictionary) -> int:
	var modes: PackedInt32Array = modes_of(meta)
	return modes[0] if not modes.is_empty() else Defs.VersusMode.GRUB_STACK


## Most players the arena is built for (meta `players`, at least 2).
static func players_of(meta: Dictionary) -> int:
	return clampi(int(meta.get("players", VersusTuning.PLAYERS_MIN)), VersusTuning.PLAYERS_MIN, VersusTuning.PLAYERS_MAX)


## The spawn points of the level (feet points): '@' and every `objects/spawn_point index=2..4` the loader put into
## LevelBase.start_positions, as many as the arena's `players` (or the heroes present, whichever is more).
static func spawn_points(level: LevelBase) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if level == null:
		return result
	var count: int = maxi(players_of(level.meta), level.hero_count())
	for slot: int in mini(count, Defs.MAX_PLAYERS):
		result.append(level.get_start_pos_for(slot))
	return result


## Parsed arena files by level id (file_records reads each file once per run).
static var _file_cache: Dictionary = {}


## The entity records with id `id` of the file behind `level` (its level_id through the Levels registry) that apply
## to Game.difficulty: the arena's markers that are data for the referee rather than entities of their own
## (`zones/goal`, `objects/crate_lane`). Empty for a level without a file (a test level) or without such records.
static func file_records(level: LevelBase, id: StringName) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if level == null or level.level_id == &"":
		return result
	var data: LevelData = null
	if _file_cache.has(level.level_id):
		data = _file_cache[level.level_id]
	else:
		var tree: SceneTree = Engine.get_main_loop() as SceneTree
		var registry: Node = tree.root.get_node_or_null(^"Levels") if tree != null else null
		var path: String = str(registry.call(&"get_level_path", level.level_id)) \
				if registry != null and registry.has_method(&"get_level_path") else ""
		if path != "" and FileAccess.file_exists(path):
			data = LevelData.load_file(path)
		_file_cache[level.level_id] = data
	if data == null:
		return result
	for record: Dictionary in data.entity_records():
		if StringName(str(record["id"])) == id and LevelText.applies_to(record["params"], Game.difficulty):
			result.append(record)
	return result


## The wrap step of an arena (DESIGN.md E.5) for one hero, made once per tick after the PLAYER phase of every hero
## (the referee runs it first thing in its own PLAYER step; the bot baker of core-B calls it the same way on a bare
## level): `wrap = lr` - a hero whose x step was refused at a side edge (x + xvel / 16 outside the commit range)
## comes in at the other side with that step; `wrap = tb` - a hero whose feet passed the view's bottom (y >= 176)
## comes in at the top, and one rising past the top (y < 0) comes in at the bottom. True when he was moved (a
## teleport, LevelBase.notify_hero_teleported).
static func wrap_hero(level: LevelBase, hero: PlayerBase) -> bool:
	if level == null:
		return false
	return wrap_step(level, hero, wrap_mode(level.meta))


## [method wrap_hero] with the wrap mode given (VersusArena.WRAP_*).
static func wrap_step(level: LevelBase, hero: PlayerBase, mode: int) -> bool:
	if level == null or hero == null or hero.dead:
		return false
	var to: Vector2i = hero.sim_pos
	if mode == WRAP_LR:
		var left: int = Tuning.X_MIN
		var right: int = level.grid.x_max_excl()
		var span: int = right - left
		var next_x: int = hero.sim_pos.x + Tuning.floor16(hero.xvel)
		if hero.xvel < 0 and next_x < left:
			to.x = clampi(next_x + span, left, right - 1)
		elif hero.xvel > 0 and next_x >= right:
			to.x = clampi(next_x - span, left, right - 1)
	elif mode == WRAP_TB:
		var height: int = view_rect().size.y
		if hero.sim_pos.y >= height:
			to.y = hero.sim_pos.y - height
		elif hero.sim_pos.y < 0 and hero.yvel < 0:
			to.y = hero.sim_pos.y + height
	if to == hero.sim_pos:
		return false
	hero.teleport(to)
	level.notify_hero_teleported(hero)
	return true


## Make `level` a versus stage when it is an arena: lock the camera to [method view_rect] and register the referee
## as the party driver (after the heroes: call it right after LevelBase.spawn_party_heroes). Returns the referee
## (the existing one on a second call), or null for a level that is not an arena. When another party driver is
## registered already, the referee is still added to the level (it ticks after the heroes) and keeps every rule but
## the death routing of LevelBase.hero_death_finished.
static func setup(level: LevelBase) -> VersusReferee:
	if not is_arena(level):
		return null
	var existing: VersusReferee = VersusReferee.find(level)
	if existing != null:
		return existing
	level.lock_camera(view_rect())
	var referee: VersusReferee = VersusReferee.new()
	referee.name = "VersusReferee"
	level.register_party_driver(referee)
	if referee.get_parent() == null:
		level.get_container("player").add_child(referee)
	return referee
