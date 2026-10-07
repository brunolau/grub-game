class_name BarkBoard
extends SimEntity
## `objects/bark_board` (`face=l|r`, the side with air; found from the tiles when omitted): one wall cell of bark
## (trees, palisades, drift-logs, cloud-rock) that catches spears (DESIGN.md C.2, PHYSICS.md C.3, GAMEPLAY.md 13.3).
## Placed IN the wall cell (`tile=#` in its legend entry). A flying spear whose box overlaps the board's 16 x 16 cell
## while its xvel points into the face (`face=r` takes spears flying left) sticks, and the board spawns an
## `objects/spear_step`: a 16 px one-way step in the air cell in front of the face, its top on the top edge of the
## board's cell, for Tuning.BARK_BOARD_STEP_TICKS. One step per board: a spear that meets a board whose step still
## stands glances off (the spear is removed, clank).
##
## Owner: objects-B (docs/expansion/PLAN.md 4.1). The spear is player-B's (projectiles/hero_spear); in its PROJECTILES
## move it asks [method find_catching] and then [method stick] (build/engine_requests/wf7_objects-B_to_player-B.txt):
##   var board: BarkBoard = BarkBoard.find_catching(level, self)
##   if board != null:
##       var step: SpearStep = board.stick(self)   # null = glanced: remove the spear
## The board itself takes no tick and never dozes. Picture: sprites/objects/bark_board.png (ASSET_MANIFEST 17.3: 3 x 11
## cells of 32 x 32 art px, one row per LevelData.BIOMES biome, drawn for face=r and flipped for face=l; 0 idle, 1 hit,
## 2 busy while a step stands in it).

const STEP_ID: StringName = &"objects/spear_step"
const SHEET: Texture2D = preload("res://assets/sprites/objects/bark_board.png")
const SHEET_COLUMNS: int = 3
const FRAME_IDLE: int = 0
const FRAME_HIT: int = 1
const FRAME_BUSY: int = 2
## Seconds the "hit" frame shows after a spear stuck (cosmetic).
const HIT_FLASH_SECONDS: float = 0.15

## +1 when the air is on the right of the board (`face=r`: it catches spears flying left), -1 on the left; 0 until
## found from the tiles.
var face: int = 0
## The wall cell this board occupies.
var cell: Vector2i = Vector2i.ZERO
## The step a spear made here (null when none stands).
var step: SpearStep = null
## Spears that stuck here / glanced off a standing step (statistics, tests).
var sticks: int = 0
var glances: int = 0

var _sprite: Sprite2D = null
var _row: int = 0
var _flash: float = 0.0


func _init() -> void:
	z_index = Defs.Z_OBJECTS
	set_box(Vector3i(Tuning.TILE, Tuning.TILE, Tuning.TILE / 2))


func _apply_params(params: Dictionary) -> void:
	cell = Vector2i(sim_pos.x >> 4, (sim_pos.y - 1) >> 4)
	var side: String = str(params.get("face", ""))
	if side.begins_with("r"):
		face = 1
	elif side.begins_with("l"):
		face = -1
	# A stuck spear spawns the step in the middle of play: load its scene now, never inside a tick.
	Spawner.load_scene(STEP_ID)


func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.texture = SHEET
	_sprite.centered = false
	_sprite.offset = Vector2(-Tuning.TILE, -Tuning.TILE * Tuning.ART_SCALE)
	_sprite.hframes = SHEET_COLUMNS
	_sprite.vframes = maxi(SHEET.get_height() / (Tuning.TILE * Tuning.ART_SCALE), 1)
	_sprite.flip_h = get_face() < 0
	add_child(_sprite)
	var biome: String = str(Game.level.meta.get("biome", "jungle")) if Game.level != null else "jungle"
	_row = clampi(LevelData.BIOMES.find(biome), 0, _sprite.vframes - 1)
	_refresh_look()


## +1 (air on the right) or -1 (air on the left). Without `face` the side whose neighbour cell is not a wall wins
## (right when both or neither are).
func get_face() -> int:
	if face == 0:
		face = 1
		var level: LevelBase = Game.level
		if level != null:
			var right_open: bool = level.grid.side_at(cell.x + 1, cell.y) != TileGrid.SIDE_WALL
			var left_open: bool = level.grid.side_at(cell.x - 1, cell.y) != TileGrid.SIDE_WALL
			if left_open and not right_open:
				face = -1
	return face


## The board's cell in logical px.
func cell_rect() -> Rect2i:
	return Rect2i(cell * Tuning.TILE, Vector2i(Tuning.TILE, Tuning.TILE))


## True while a step made here still stands.
func has_step() -> bool:
	return step != null and is_instance_valid(step) and step.is_solid()


## True when `spear` (a flying spear) sticks or glances here this tick: its box overlaps the board's cell and its xvel
## points into the face.
func catches(spear: SimEntity) -> bool:
	if spear == null or spear.xvel * get_face() >= 0:
		return false
	return Overlap.rects(spear.get_box(), cell_rect())


## A spear that [method catches] arrived: spawns and returns the step (the spear stops and keeps it), or returns null
## when a step still stands here (the spear glances off: the caller removes it).
func stick(spear: SimEntity) -> SpearStep:
	var level: LevelBase = Game.level
	if has_step() or level == null:
		glances += 1
		Audio.play_sfx(Sfx.CLUB_HIT_SCENERY)
		return null
	var params: Dictionary = {"face": "r" if get_face() > 0 else "l", "board": self}
	var owner: Variant = spear.get(&"owner_slot") if spear != null else null
	if owner != null:
		params["owner"] = int(owner)
	step = level.spawn(STEP_ID, step_feet(), params) as SpearStep
	if step == null:
		return null
	sticks += 1
	_flash = HIT_FLASH_SECONDS
	Audio.play_sfx(Sfx.SPEAR_STICK if AudioTable.SFX.has(Sfx.SPEAR_STICK) else Sfx.CLUB_HIT_SCENERY)
	return step


## Feet point of the step this board makes: the middle of the air cell in front of the face, the step's top on the top
## edge of the board's cell (SpearStep's box is 8 px high).
func step_feet() -> Vector2i:
	var x: int = (cell.x + get_face()) * Tuning.TILE + Tuning.TILE / 2
	return Vector2i(x, cell.y * Tuning.TILE + SpearStep.STEP_H)


## The first bark board of the level that catches `spear` this tick (spawn order), or null.
static func find_catching(level: LevelBase, spear: SimEntity) -> BarkBoard:
	if level == null or spear == null:
		return null
	var others: Array[SimEntity] = level.get_kind(Defs.Kind.OTHER)
	for i: int in others.size():
		var board: BarkBoard = others[i] as BarkBoard
		if board != null and board.catches(spear):
			return board
	return null


func _on_level_reset() -> void:
	step = null


func _process(delta: float) -> void:
	if _flash > 0.0:
		_flash -= delta
	_refresh_look()


## Busy while a step stands in it, the lit frame just after a spear stuck, else idle (cosmetic).
func _refresh_look() -> void:
	if _sprite == null:
		return
	var column: int = FRAME_IDLE
	if _flash > 0.0:
		column = FRAME_HIT
	elif has_step():
		column = FRAME_BUSY
	_sprite.frame = _row * SHEET_COLUMNS + column
