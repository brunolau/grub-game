class_name HeroSpear
extends ProjectileBase
## `projectiles/hero_spear`: the hero's thrown spear (docs/spec/PHYSICS.md C.3; DESIGN.md C.2), Defs.Weapon.SPEAR.
##
## Owner: player-B (docs/expansion/PLAN.md 4.1). Thrown by [method throw_from] on the strike's last tick (Player._throw
## calls it for the spear, like the axe: spawned at the weapon anchor plus one tick of its motion): xvel +/-192
## (12 px/tick) by facing, yvel 0, flat for Tuning.SPEAR_FLAT_TICKS moves, then +16 v16 per tick (cap 192). Box 24 x 6,
## x_offset 12. No tile collision (it passes walls like the axe), except:
##  - **bark boards** (objects-B's `objects/bark_board`): at its spawn position (on the first move, before moving) and
##    after each move the spear asks the boards for a catch
##    (`board.catches(spear)`: its cell overlaps the spear's box and xvel points into its face) and requests a spear
##    step (`board.stick(spear)`): a step means it stuck - the step (objects-B's `objects/spear_step`, a one-way sprite
##    platform drawn as the stuck spear) stands for this spear from then on and the flying spear is removed; null
##    means the board already holds a live step and the spear glances off (removed; the board plays the clank);
##  - versus arenas (C.14): its feet point entering a wall (SIDE 1) or a floor cell stops it, and it lies there as a
##    temporary pick-up (`items/weapon kind=spear temp=true`) - on that cell's top, or in front of a wall's face,
##    never inside the wall ([method lie_spot]).
## Weapon pass: the thrower's own pass (Player._weapon_pass) tests it like the axe - the first enemy it overlaps takes
## its power, else the first hidden spot; it is removed on a hit and never pogoes. Removed when it was on no view on
## the previous tick.
## Count (C.3): at most Tuning.SPEAR_MAX_PER_HERO spears per hero exist, in flight or stuck (as steps); a further throw
## pulls out his oldest first (a step collapses at once and a hero on it falls). Flying spears count toward
## Tuning.MAX_THROWN with his other throws. The per-hero list lives on the level (Object metadata HEROES_META).

const ID: StringName = &"projectiles/hero_spear"
## Object metadata of the running level: Array (index = player slot) of Arrays of this hero's spears and the steps
## they made, oldest first.
const HEROES_META: StringName = &"_hero_spears"
## Object metadata of the running level: [size of its OTHER list, its bark boards] (see [method boards_of]).
const BOARDS_META: StringName = &"_hero_spear_boards"
## The temporary versus pick-up a spear becomes when it hits a tile in an arena (C.14).
const ID_TEMP_PICKUP: StringName = &"items/weapon"
## Flight-angle frames of fx/projectile_spear.png (0 flat; 1-3 nose down 15 / 30 / 45 degrees): the yvel (v16) from
## which each of frames 1-3 shows (tan of the angle midway between two frames, times 192).
const DROP_FRAME_YVEL: Array[int] = [25, 80, 150]
## Versus: how many cells back from a wall's face [method lie_spot] looks for the open cell its pick-up lies in.
const WALL_BACK_OUT_CELLS: int = 3

## Set while it flies; false once it stuck, glanced or was pulled out.
var flying: bool = true
## Moves made since the spawn (the flat flight lasts Tuning.SPEAR_FLAT_TICKS of them).
var moves: int = 0

var _sprite: Sprite2D = null


func _init() -> void:
	super()
	from_hero = true
	set_box(Vector3i(Tuning.SPEAR_BOX_W, Tuning.SPEAR_BOX_H, Tuning.SPEAR_BOX_XO))


func _apply_params(params: Dictionary) -> void:
	super._apply_params(params)
	from_hero = true
	yacc = 0
	set_box(Vector3i(Tuning.SPEAR_BOX_W, Tuning.SPEAR_BOX_H, Tuning.SPEAR_BOX_XO))
	if xvel != 0:
		facing = 1 if xvel > 0 else -1


func _ready() -> void:
	_sprite = get_node_or_null(^"Sprite") as Sprite2D
	_refresh_sprite()


## One tick of flight (PROJECTILES phase): integrate (no tile collision), the drop after the flat part, then the bark
## boards (and the tiles in versus); removed once it was on no view on the previous tick.
func _move_tick() -> void:
	# The spawn position itself (anchor + one tick of motion) is a position of the flight too: a hero pressed against
	# the board's wall, or standing on a spear step under a second board of the same face, throws from inside the
	# board's reach (D5's report, G1 integration). Tested on the first move, before it moves on.
	if moves == 0 and Game.level != null and _try_board(Game.level):
		return
	sim_pos.x += Tuning.floor16(xvel)
	sim_pos.y += Tuning.floor16(yvel)
	moves += 1
	_age = moves
	if moves >= Tuning.SPEAR_FLAT_TICKS:
		yvel = mini(yvel + Tuning.SPEAR_YACC, Tuning.SPEAR_FALL_MAX)
	var level: LevelBase = Game.level
	if level != null and _try_board(level):
		return
	if level != null and Game.mode == Defs.GameMode.VERSUS and _hits_tile(level):
		_lie_down(level)
		return
	if (life > 0 and moves >= life) or (moves > 1 and not on_screen):
		_remove()
		return
	_refresh_sprite()


## Pull the spear out (a third throw, a level reset): it vanishes at once.
func pull_out() -> void:
	_remove()


## A death or a team wipe resets the level: a spear still in the air is gone.
func _on_level_reset() -> void:
	pull_out()


# =================================================================================================================
# Throwing and the per-hero count
# =================================================================================================================

## Throw a spear for `hero` from the weapon anchor `anchor` (PHYSICS.md 8.4 / C.3) with the strike's power (x4 when
## charged): spawned at the anchor plus one tick of its motion, xvel Tuning.SPEAR_XVEL by his facing, yvel 0, owner =
## his slot. Pulls out his oldest spear or step first when he already has Tuning.SPEAR_MAX_PER_HERO. Returns false
## (nothing thrown, nothing pulled out) when Tuning.MAX_THROWN of his own throws are already in flight, when there is
## no level or no spear scene; the strike then makes its club box, as for the axe.
static func throw_from(hero: PlayerBase, anchor: Vector2i, power: int) -> bool:
	var level: LevelBase = Game.level
	if hero == null or level == null or not Spawner.exists(ID):
		return false
	var in_flight: int = 0
	for entity: SimEntity in level.get_kind(Defs.Kind.HERO_PROJECTILE):
		var projectile: ProjectileBase = entity as ProjectileBase
		if projectile != null and not projectile.spent and projectile.owner_slot == hero.slot:
			in_flight += 1
	var owned: Array = owned_by(level, hero.slot)
	var oldest: Object = null
	if owned.size() >= Tuning.SPEAR_MAX_PER_HERO:
		oldest = owned[0]
	if in_flight - (1 if oldest is HeroSpear else 0) >= Tuning.MAX_THROWN:
		return false
	if oldest != null:
		_pull(oldest)
		owned.erase(oldest)
	var throw_xvel: int = Tuning.SPEAR_XVEL * (1 if hero.facing >= 0 else -1)
	var pos: Vector2i = anchor + Vector2i(Tuning.floor16(throw_xvel), 0)
	var spear: Node = level.spawn(ID, pos, {
		"from_hero": true, "power": power, "xvel": throw_xvel, "yvel": 0, "yacc": 0,
		"facing": "l" if throw_xvel < 0 else "r", "owner": hero.slot,
	})
	if spear == null:
		return false
	owned.append(spear)
	return true


## The spears of player slot `slot` that exist in `level` - flying spears and the steps stuck spears made - oldest
## first. Stale entries (removed, collapsed or fallen steps) are dropped. The level's own list: do not keep it.
static func owned_by(level: LevelBase, slot: int) -> Array:
	var lists: Array = _lists(level)
	var owned: Array = lists[clampi(slot, 0, Defs.MAX_PLAYERS - 1)]
	var i: int = owned.size() - 1
	while i >= 0:
		if not _counts(owned[i]):
			owned.remove_at(i)
		i -= 1
	return owned


## Number of spears (flying or stuck) of player slot `slot` in `level`.
static func count_of(level: LevelBase, slot: int) -> int:
	return owned_by(level, slot).size()


# =================================================================================================================
# Internals
# =================================================================================================================

static func _lists(level: LevelBase) -> Array:
	if not level.has_meta(HEROES_META):
		var lists: Array = []
		for slot: int in Defs.MAX_PLAYERS:
			lists.append([])
		level.set_meta(HEROES_META, lists)
	return level.get_meta(HEROES_META)


## True while an entry still counts: a flying spear, or a step that still stands (objects-B's SpearStep.is_solid():
## false once it falls or collapsed; `is_live()` is accepted too; without either a step counts while it exists).
static func _counts(entry: Variant) -> bool:
	# Untyped: a step freed meanwhile (a level part removed, a reset) must not be passed as an Object (engine error).
	if not is_instance_valid(entry) or (entry is Node and (entry as Node).is_queued_for_deletion()):
		return false
	if entry is HeroSpear:
		return (entry as HeroSpear).flying and not (entry as HeroSpear).spent
	if entry.has_method(&"is_live"):
		return bool(entry.call(&"is_live"))
	if entry.has_method(&"is_solid"):
		return bool(entry.call(&"is_solid"))
	return true


## Pull out a spear or collapse a step (the oldest, on a third throw).
static func _pull(entry: Object) -> void:
	if entry is HeroSpear:
		(entry as HeroSpear).pull_out()
	elif entry.has_method(&"collapse"):
		entry.call(&"collapse")
	elif entry is Node:
		(entry as Node).queue_free()


## The bark boards of `level` (objects-B's `objects/bark_board`, found by duck typing among its OTHER entities: methods
## `catches(spear) -> bool` and `stick(spear)`), in spawn order. Kept on the level (Object metadata BOARDS_META =
## [size of the OTHER list, boards]) and found again when that list changed size or a kept board is gone
## ([method _try_board] drops the list then), so a flying spear asks only the boards each tick instead of testing every
## sign, tablet and checkpoint for the two methods. Boards come only from the level file (a restart builds a new
## level), so a board appearing while another OTHER entity vanished in the same tick does not happen.
static func boards_of(level: LevelBase) -> Array:
	var others: Array[SimEntity] = level.get_kind(Defs.Kind.OTHER)
	if level.has_meta(BOARDS_META):
		var cached: Array = level.get_meta(BOARDS_META)
		if cached.size() == 2 and int(cached[0]) == others.size():
			return cached[1]
	var boards: Array = []
	for i: int in others.size():
		var entity: SimEntity = others[i]
		if entity != null and entity.has_method(&"catches") and entity.has_method(&"stick"):
			boards.append(entity)
	level.set_meta(BOARDS_META, [others.size(), boards])
	return boards


## The first bark board ([method boards_of]) that catches this spear - its 16 x 16 cell overlaps this box and xvel
## points into its face - is asked for a step. True when the spear is gone (stuck or glanced).
func _try_board(level: LevelBase) -> bool:
	var boards: Array = boards_of(level)
	for i: int in boards.size():
		# Read untyped first: assigning a freed board to an Object variable is an engine error.
		var entry: Variant = boards[i]
		if not is_instance_valid(entry) or (entry is Node and (entry as Node).is_queued_for_deletion()):
			level.remove_meta(BOARDS_META)  # a kept board is gone: the next call looks again
			continue
		var board: Object = entry
		if not bool(board.call(&"catches", self)):
			continue
		var step: Variant = board.call(&"stick", self)
		flying = false
		if step is Object and step != null:
			# The step stands for this spear from now on (it counts and is pulled out in its place).
			var owned: Array = _lists(level)[owner_slot]
			var index: int = owned.find(self)
			if index >= 0:
				owned[index] = step
			else:
				owned.append(step)
		_remove()
		return true
	return false


## Versus (C.14): the feet point entered a wall (SIDE 1) or a floor cell.
func _hits_tile(level: LevelBase) -> bool:
	return _solid_cell(level.grid, Tuning.to_cell(sim_pos.x), Tuning.to_cell(sim_pos.y))


## Versus: lie there as a temporary pick-up, at [method lie_spot].
func _lie_down(level: LevelBase) -> void:
	flying = false
	if Spawner.exists(ID_TEMP_PICKUP):
		level.spawn(ID_TEMP_PICKUP, lie_spot(level.grid, sim_pos, xvel),
				{"kind": "spear", "temp": true, "dropped": true})
	_remove()


## Where a versus spear whose point entered the solid cell under `point` lies down (C.14 "stops and lies there"), as
## the feet point of its pick-up (a dropped item: it falls to the floor below it): on the top of that cell when the
## cell above it is open (it came down onto a floor or flew into the top row of a wall); else it flew into a wall's
## face, and it lies in the first open cell of that row back towards the thrower (at most WALL_BACK_OUT_CELLS back,
## also when it was thrown from inside the wall's reach), from where it drops to the floor in front of the face -
## never inside the wall, where no hero could reach it.
static func lie_spot(grid: TileGrid, point: Vector2i, p_xvel: int) -> Vector2i:
	var col: int = Tuning.to_cell(point.x)
	var row: int = Tuning.to_cell(point.y)
	var cell_top: int = row * Tuning.TILE
	if not _solid_cell(grid, col, row - 1):
		return Vector2i(point.x, cell_top)
	var back: int = -1 if p_xvel > 0 else 1
	var c: int = col
	for i: int in WALL_BACK_OUT_CELLS:
		c += back
		if not _solid_cell(grid, c, row):
			return Vector2i(c * Tuning.TILE + Tuning.TILE / 2, cell_top)
	return Vector2i(point.x, cell_top)


## A cell a versus spear stops in (C.14): a wall (SIDE 1) or any floor.
static func _solid_cell(grid: TileGrid, col: int, row: int) -> bool:
	var floor_value: int = grid.floor_at(col, row)
	return grid.side_at(col, row) == TileGrid.SIDE_WALL \
			or (floor_value != TileGrid.FLOOR_EMPTY and floor_value != TileGrid.FLOOR_NOTHING)


func _remove() -> void:
	flying = false
	consume()


func _refresh_sprite() -> void:
	if _sprite == null:
		return
	var frame: int = 0
	for i: int in DROP_FRAME_YVEL.size():
		if yvel >= DROP_FRAME_YVEL[i]:
			frame = i + 1
	if _sprite.frame != frame:
		_sprite.frame = frame
	var flip: bool = facing < 0
	if _sprite.flip_h != flip:
		_sprite.flip_h = flip
