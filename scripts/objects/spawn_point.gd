class_name SpawnPoint
extends SimEntity
## `objects/spawn_point` (`index` 2..4): where player `index` of a versus arena starts (LEVEL_DESIGN.md 15.8: `@` is
## spawn 1; ARCHITECTURE.md 6.2.1). Arenas only. The level loader also reads its cell as that slot's start
## (LevelBase.start_positions, Level._place_party_starts) unless an `objects/hero_start` names the slot; this entity
## exists so that the round loop and the referee can ask for the arena's spawns during play (rotation every round,
## the respawn after a hazard).
##
## Owner: objects-B (docs/expansion/PLAN.md 4.1). It takes no tick and never dozes. Picture: the pad of
## sprites/objects/spawn_point.png (ASSET_MANIFEST 17.11: 6 frames; 0 idle, 1-4 lit in P1-P4's colour, 5 neutral);
## the referee may light it with [method show_player] while a player waits to respawn there.
##
## For the referee (world-B) and the bots (core-B), all static and allocation-light:
## - [method spawn_list]: '@' first, then every spawn point by `index` (ties: spawn order);
## - [method round_spawn]: DESIGN.md E.2 "spawns rotate every round" (the physics is left-right asymmetric);
## - [method farthest_free]: PHYSICS.md C.14 "Respawn ... at the free spawn point farthest from the rivals".

## A spawn counts as taken while another living, hatched hero's feet point is this close to it (Manhattan px). [own]
const FREE_RADIUS_PX: int = 24
## Distance used when nobody else is in the arena.
const FAR_AWAY: int = 1 << 30

## Sheet frames: idle pad, P1..P4 lit (1 + slot), neutral (round start).
const FRAME_IDLE: int = 0
const FRAME_NEUTRAL: int = 5
## The pad lit in any colour a player may wear (art-A, ASSET_MANIFEST 17.11): the same 48 x 16 pad and pivot, 6 cells
## in UiPlayers.PALETTE_ORDER (yellow, blue, pink, green, white, gold). Optional: without it the slot defaults show.
const LIT_SHEET_PATH: String = "res://assets/sprites/objects/spawn_point_lit.png"
const LIT_SHEET_CELLS: int = 6

## Player number of this spawn (2..Defs.MAX_PLAYERS; `@` is player 1).
var index: int = 2

var _pad_sheet: Texture2D = null
var _lit_sheet: Texture2D = null


func _init() -> void:
	z_index = Defs.Z_OBJECTS
	set_box(Vector3i(16, 16, 8))


func _apply_params(params: Dictionary) -> void:
	index = clampi(int(params.get("index", index)), 2, Defs.MAX_PLAYERS)


## Cosmetic: light the pad for player slot `slot` (0..3), -1 = idle, Defs.MAX_PLAYERS = neutral. `colour` >= 0 is
## the colour that player wears (UiPlayers.colour_index(slot): his lobby choice, white for green on a jungle arena),
## drawn from [constant LIT_SHEET_PATH]; the caller passes it, so this object never reads the UI tables. Without it
## (or without that sheet) the pad shows the slot's default colour.
func show_player(slot: int, colour: int = -1) -> void:
	var sprite: Sprite2D = get_node_or_null(^"Sprite") as Sprite2D
	if sprite == null:
		return
	if _pad_sheet == null:
		_pad_sheet = sprite.texture
	var lit: bool = slot >= 0 and slot < Defs.MAX_PLAYERS and colour >= 0 and _lit_texture() != null
	sprite.texture = _lit_sheet if lit else _pad_sheet
	if lit:
		sprite.frame = clampi(colour, 0, LIT_SHEET_CELLS - 1)
	elif slot < 0:
		sprite.frame = FRAME_IDLE
	elif slot >= Defs.MAX_PLAYERS:
		sprite.frame = FRAME_NEUTRAL
	else:
		sprite.frame = 1 + slot


## art-A's lit sheet (loaded once), null when it is not there.
func _lit_texture() -> Texture2D:
	if _lit_sheet == null and ResourceLoader.exists(LIT_SHEET_PATH):
		_lit_sheet = load(LIT_SHEET_PATH) as Texture2D
	return _lit_sheet


## Every spawn of the level's arena as feet points: index 0 is `@` ([member LevelBase.start_pos], player 1), then the
## spawned `objects/spawn_point` entities by `index` (2, 3, 4; equal indices in spawn order).
static func spawn_list(level: LevelBase) -> Array[Vector2i]:
	var list: Array[Vector2i] = []
	if level == null:
		return list
	list.append(level.start_pos)
	var others: Array[SimEntity] = level.get_kind(Defs.Kind.OTHER)
	for wanted: int in range(2, Defs.MAX_PLAYERS + 1):
		for i: int in others.size():
			var point: SpawnPoint = others[i] as SpawnPoint
			if point != null and point.index == wanted and not point.is_queued_for_deletion():
				list.append(point.sim_pos)
	return list


## The spawn of player slot `slot` (0 = P1) in round `round_index` (0-based): spawn (slot + round_index) modulo the
## number of spawns, so every round moves each player one spawn on. `@` when the arena has no spawn list.
static func round_spawn(level: LevelBase, slot: int, round_index: int) -> Vector2i:
	var list: Array[Vector2i] = spawn_list(level)
	if list.is_empty():
		return Vector2i.ZERO
	return list[posmod(slot + round_index, list.size())]


## Where `hero` respawns after a hazard (PHYSICS.md C.14): among the spawns that no other living, hatched hero stands
## on (feet within FREE_RADIUS_PX), the one whose nearest such rival is farthest away (Manhattan distance between
## feet points); when every spawn is taken, the same choice over all of them. Ties go to the lower spawn index.
static func farthest_free(level: LevelBase, hero: PlayerBase) -> Vector2i:
	var list: Array[Vector2i] = spawn_list(level)
	if list.is_empty():
		return hero.sim_pos if hero != null else Vector2i.ZERO
	var best: int = _best_spawn(level, hero, list, true)
	if best < 0:
		best = _best_spawn(level, hero, list, false)
	return list[maxi(best, 0)]


## Index into `list` of the spawn farthest from the rivals of `hero` (-1 when `only_free` and none is free).
static func _best_spawn(level: LevelBase, hero: PlayerBase, list: Array[Vector2i], only_free: bool) -> int:
	var best: int = -1
	var best_distance: int = -1
	for i: int in list.size():
		var pos: Vector2i = list[i]
		var nearest: int = FAR_AWAY
		for other: PlayerBase in level.heroes:
			if other == null or other == hero or other.dead or other.is_down():
				continue
			var distance: int = absi(other.sim_pos.x - pos.x) + absi(other.sim_pos.y - pos.y)
			nearest = mini(nearest, distance)
		if only_free and nearest <= FREE_RADIUS_PX:
			continue
		if nearest > best_distance:
			best = i
			best_distance = nearest
	return best
