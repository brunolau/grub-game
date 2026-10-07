class_name HeavyBoulder
extends SimEntity
## `objects/boulder_heavy` (DESIGN.md D.5, GAMEPLAY.md 13.9.7): a 2 x 2-cell solid tile mover, anchored at its
## bottom-left cell. Its four cells are invisible solid tiles (`;`) in the collision grid while it stands there, so
## heroes, enemies and items meet it as a wall and a floor; the picture is this entity's sprite.
##
## - **Heave**: it moves one tile away from a side once two hatched heroes (PartyTuning.BOULDER_PUSHERS) have pushed
##   that side on PartyTuning.BOULDER_STEP_TICKS ticks in a row: each grounded, holding the direction into it, his
##   feet on its bottom rows and at most ObjTuning.BOULDER_PUSH_REACH_PX from its face (the wall probe stops him
##   there). One hero alone only strains against it. A step into a cell that is not air, or onto a hero, is refused.
## - **Fall**: with no floor under either of its cells it falls one tile per ObjTuning.BOULDER_FALL_TICKS ticks
##   (into air or liquid cells: a boulder fills a gap or a pool), never onto a hero (it waits), and rests on the
##   bottom edge of the map at the latest.
## - It weighs PartyTuning.PLATE_WEIGHT_BOULDER on an objects/plate it rests on ([method rests_on_plate]) and plugs a
##   geyser vent it rests on (objects-B's objects/geyser asks [method plugs_vent]; [method cell_is_boulder] for
##   anything else).
## - A team wipe (the level reset) puts it back where the level file placed it.
## The cells it covers keep their original characters and get them back when it moves on.

## Sheet [M boulder_heavy]: idle 0; strain 1, 0, 2, 0 at 16 fps (one hero pushing alone).
const STRAIN_FRAMES: Array[int] = [1, 0, 2, 0]
const STRAIN_FPS: int = 16
const ID_DUST: StringName = &"fx/dust"

## The cells it occupies now: position = top-left cell, size 2 x 2.
var block: Rect2i = Rect2i(0, 0, ObjTuning.BOULDER_CELLS, ObjTuning.BOULDER_CELLS)
## Ticks in a row that two heroes have pushed [member push_side] (+1: they push it to the right, -1: to the left).
var push_ticks: int = 0
var push_side: int = 0
## Heroes pushing it on the last test, per side (bit `slot`): to the right / to the left.
var pushers_right: int = 0
var pushers_left: int = 0
## Tiles it moved by heaving / falling since the level start (statistics, tests).
var moves: int = 0
## True while it has no floor under it.
var falling: bool = false

var _home: Rect2i = Rect2i()
var _fall_timer: int = 0
## Cell -> the character it covered there (restored when it moves on).
var _covered: Dictionary = {}
var _placed: bool = false
var _sprite: Sprite2D = null
var _strain_anim: int = -1


func _init() -> void:
	z_index = Defs.Z_OBJECTS
	set_box(Vector3i(ObjTuning.BOULDER_CELLS * Tuning.TILE, ObjTuning.BOULDER_CELLS * Tuning.TILE,
			ObjTuning.BOULDER_CELLS * Tuning.TILE / 2))


func _sim_phases() -> PackedInt32Array:
	return PackedInt32Array([Defs.Phase.WORLD])


func _apply_params(_params: Dictionary) -> void:
	var col: int = sim_pos.x >> 4
	var row: int = (sim_pos.y - 1) >> 4
	block = Rect2i(col, row - ObjTuning.BOULDER_CELLS + 1, ObjTuning.BOULDER_CELLS, ObjTuning.BOULDER_CELLS)
	_home = block
	_sprite = get_node_or_null(^"Sprite") as Sprite2D
	teleport(_feet_of(block))


func _enter_tree() -> void:
	# Its cells become solid once the level exists (the loader built the grid and the tile visuals before it spawns
	# entities; LevelBase.set_cell keeps the visuals in step).
	if not _placed and Game.level != null:
		_placed = true
		_cover(Game.level, block)


## Feet point (bottom-centre) of a block.
static func _feet_of(cells: Rect2i) -> Vector2i:
	return Vector2i(cells.position.x * Tuning.TILE + cells.size.x * Tuning.TILE / 2, cells.end.y * Tuning.TILE)


func _sim_tick(_phase: int) -> void:
	var level: LevelBase = Game.level
	if level == null:
		return
	if not _placed:
		_placed = true
		_cover(level, block)
	falling = not _supported(level)
	if falling:
		push_ticks = 0
		push_side = 0
		pushers_right = 0
		pushers_left = 0
		_fall_timer += 1
		if _fall_timer >= ObjTuning.BOULDER_FALL_TICKS and _try_move(level, Vector2i(0, 1)):
			_fall_timer = 0
		_animate(false)
		return
	_fall_timer = 0
	_count_pushers(level)
	var right: int = ObjTuning.bit_count(pushers_right)
	var left: int = ObjTuning.bit_count(pushers_left)
	var side: int = 0
	if right >= PartyTuning.BOULDER_PUSHERS:
		side = 1
	elif left >= PartyTuning.BOULDER_PUSHERS:
		side = -1
	if side == 0:
		push_ticks = 0
	elif side == push_side:
		push_ticks += 1
	else:
		push_ticks = 1
	push_side = side
	if side != 0 and push_ticks >= PartyTuning.BOULDER_STEP_TICKS:
		push_ticks = 0
		if _try_move(level, Vector2i(side, 0)):
			ObjTuning.play_cue(Sfx.BOULDER_PUSH, Sfx.IMPACT)
			level.spawn_fx(ID_DUST, Vector2i(sim_pos.x - side * Tuning.TILE, sim_pos.y))
	_animate(side == 0 and (right == 1 or left == 1))


## The heroes pushing it this tick (see the class comment), as slot bits per side.
func _count_pushers(level: LevelBase) -> void:
	pushers_right = 0
	pushers_left = 0
	var left_face: int = block.position.x * Tuning.TILE
	var right_face: int = block.end.x * Tuning.TILE
	var top: int = block.position.y * Tuning.TILE
	var bottom: int = block.end.y * Tuning.TILE
	for hero: PlayerBase in level.contact_order():
		# 2.0 IDLE rule: a dozing hero (PlayerBase.counts_for_coop) pushes nothing.
		if not hero.counts_for_coop() or hero.is_mounted() or not hero.is_grounded():
			continue
		var y: int = hero.sim_pos.y
		if y <= top or y > bottom:
			continue
		var x: int = hero.sim_pos.x
		var flags: int = hero.input_flags
		var wants_right: bool = (flags & Defs.IN_RIGHT) != 0 and (flags & Defs.IN_LEFT) == 0
		var wants_left: bool = (flags & Defs.IN_LEFT) != 0 and (flags & Defs.IN_RIGHT) == 0
		if wants_right and x < left_face and left_face - x <= ObjTuning.BOULDER_PUSH_REACH_PX:
			pushers_right |= 1 << hero.slot
		elif wants_left and x >= right_face and x - right_face <= ObjTuning.BOULDER_PUSH_REACH_PX:
			pushers_left |= 1 << hero.slot


## True when a floor (or the map's bottom edge) lies under one of its cells.
func _supported(level: LevelBase) -> bool:
	var grid: TileGrid = level.grid
	var below: int = block.end.y
	if grid.rows > 0 and below >= grid.rows:
		return true
	for col: int in range(block.position.x, block.end.x):
		if TileGrid.is_ground(grid.floor_at(col, below)):
			return true
	return false


## Move one cell by `step` when every newly covered cell is free (air; a falling boulder also sinks into liquid) and
## no hatched hero stands there. Returns true when it moved.
func _try_move(level: LevelBase, step: Vector2i) -> bool:
	var target: Rect2i = Rect2i(block.position + step, block.size)
	var grid: TileGrid = level.grid
	for row: int in range(target.position.y, target.end.y):
		for col: int in range(target.position.x, target.end.x):
			if block.has_point(Vector2i(col, row)):
				continue
			if not grid.in_bounds(col, row):
				return false
			var ch: String = level.get_cell(col, row)
			if ch != TileGrid.CH_AIR and not (step.y > 0 and ch == TileGrid.CH_LIQUID):
				return false
			if ObjTuning.hero_in_cell(level, col, row):
				return false
	_uncover(level, block)
	block = target
	_cover(level, block)
	sim_pos = _feet_of(block)
	moves += 1
	return true


func _cover(level: LevelBase, cells: Rect2i) -> void:
	for row: int in range(cells.position.y, cells.end.y):
		for col: int in range(cells.position.x, cells.end.x):
			var cell: Vector2i = Vector2i(col, row)
			if not level.grid.in_bounds(col, row) or _covered.has(cell):
				continue
			_covered[cell] = level.get_cell(col, row)
			level.set_cell(col, row, TileGrid.CH_SOLID_INVISIBLE)


func _uncover(level: LevelBase, cells: Rect2i) -> void:
	for row: int in range(cells.position.y, cells.end.y):
		for col: int in range(cells.position.x, cells.end.x):
			var cell: Vector2i = Vector2i(col, row)
			if _covered.has(cell):
				level.set_cell(col, row, str(_covered[cell]))
				_covered.erase(cell)


## True when it rests (not falling) on the floor under `plate`: its bottom row is the plate's row and its cells
## overlap the plate's cells.
func rests_on_plate(plate: Plate) -> bool:
	if falling:
		return false
	var plate_row: int = (plate.sim_pos.y - 1) >> 4
	if block.end.y - 1 != plate_row:
		return false
	return block.position.x * Tuning.TILE < plate.right_px() and block.end.x * Tuning.TILE > plate.left_px()


## True when it occupies tile (col, row).
func occupies(col: int, row: int) -> bool:
	return block.has_point(Vector2i(col, row))


## objects/geyser (objects-B, PHYSICS.md C.6 [R3]): true while it rests (not falling) on the vent `vent` (logical px,
## the 24 x 16 box above the vent's floor): its cells hold the point 1 px above the vent's floor centre.
func plugs_vent(vent: Rect2i) -> bool:
	if falling:
		return false
	var x: int = vent.position.x + vent.size.x / 2
	var y: int = vent.end.y - 1
	return occupies(x >> 4, y >> 4)


## True when some heave boulder of `level` occupies tile (col, row) (a geyser vent it covers is plugged).
static func cell_is_boulder(level: LevelBase, col: int, row: int) -> bool:
	if level == null:
		return false
	for entity: SimEntity in level.get_kind(Defs.Kind.OTHER):
		var boulder: HeavyBoulder = entity as HeavyBoulder
		if boulder != null and boulder.occupies(col, row):
			return true
	return false


func _on_level_reset() -> void:
	var level: LevelBase = Game.level
	if level != null and block != _home:
		_uncover(level, block)
		block = _home
		_cover(level, block)
	teleport(_feet_of(block))
	push_ticks = 0
	push_side = 0
	pushers_right = 0
	pushers_left = 0
	_fall_timer = 0
	falling = false
	_strain_anim = -1
	_animate(false)


func _animate(strain: bool) -> void:
	if strain:
		_strain_anim += 1
	else:
		_strain_anim = -1
	if _sprite == null:
		return
	if _strain_anim < 0:
		_sprite.frame = 0
	else:
		_sprite.frame = STRAIN_FRAMES[ObjTuning.anim_frame(_strain_anim, STRAIN_FPS) % STRAIN_FRAMES.size()]
