class_name Vine
extends HittableBase
## `objects/vine` (`length` cells [4], `rolled` [false]): a vine hanging from the top edge of its anchor cell
## (DESIGN.md C.3, PHYSICS.md C.4, GAMEPLAY.md 13.3). `vine_x` = the cell centre, `top` = the cell top,
## `bottom = top + 16 * length`. Heroes grab it with UP while their feet column is within Tuning.VINE_GRAB_DX px and
## their hands (Tuning.VINE_HAND_REACH_PX over the feet) reach it, then climb in the CLIMB state - all of which is
## the hero's (player-B, scripts/player/hero_climb.gd, which asks [method find_grab]).
##
## A **rolled** vine lies coiled at its ledge: its coil (16 x 16 at the anchor point (vine_x, top)) is a hittable - any
## weapon box or thrown weapon (the normal hittable pass of the hero; the hidden-tile test of PHYSICS.md 8.3 #2 on the
## anchor cell or on the cell above it, so both a forward strike and a low strike from the ledge reach it), or a batted
## ball ([method unroll], player-A) unrolls it with an 8-tick animation; then it hangs like any vine and stays unrolled
## for the rest of the stage, through deaths and team wipes (like an opened spot). It is the solo shortcut opener and
## the co-op "way back" drop gift (DESIGN.md D.5).
##
## Owner: objects-B (docs/expansion/PLAN.md 4.1). Kind HITTABLE (so weapons find the coil); it never counts as a hidden
## spot (no completion count, no Events.hidden_spot_opened). Picture: sprites/objects/vine.png (ASSET_MANIFEST 17.3:
## 8 x 11 cells of 32 x 32 art px, one row per LevelData.BIOMES biome; columns 0 top, 1 / 2 segments, 3 tip, 4-6 the
## coil and its unroll, 7 the coil's wiggle), pivot (16, 0) = (vine_x, cell top).

## Ticks of the unroll animation; the vine can be grabbed once it ran.
const UNROLL_TICKS: int = 8
const SHEET: Texture2D = preload("res://assets/sprites/objects/vine.png")
const SHEET_COLUMNS: int = 8
const CELL_ART: int = 32
const COL_TOP: int = 0
const COL_SEGMENT_A: int = 1
const COL_SEGMENT_B: int = 2
const COL_TIP: int = 3
const COL_COIL: int = 4
const COL_COIL_WIGGLE: int = 7
## Coil frames of the unroll (4, 5, 6 over UNROLL_TICKS).
const UNROLL_COLUMNS: Array[int] = [4, 5, 6]
## The coil's idle wiggle: one frame change per this many seconds (cosmetic).
const WIGGLE_SECONDS: float = 0.6

## Hanging length in cells.
var length: int = 4
## True when the level placed it rolled up (`rolled`).
var rolled: bool = false
## True while it hangs (placed unrolled, or unrolled by a hit).
var unrolled: bool = true
## x of the vine (the anchor cell's centre), px.
var vine_x: int = 0
## y of its top (the anchor cell's top edge), px.
var top: int = 0
## y of its bottom end (top + 16 * length), px.
var bottom: int = 0
## Ticks left of the unroll animation (0 = still or done).
var unroll_left: int = 0

var _row: int = 0
var _wiggle: float = 0.0


func _init() -> void:
	super()
	z_index = Defs.Z_OBJECTS
	counts_for_completion = false
	spot_kind = &"vine"
	set_box(Vector3i(Tuning.TILE, Tuning.TILE, Tuning.TILE / 2))


func _apply_params(params: Dictionary) -> void:
	length = maxi(int(params.get("length", length)), 1)
	rolled = param_bool("rolled", false)
	# The loader's feet point is the bottom of the anchor cell; the vine's anchor point is the top of that cell.
	vine_x = sim_pos.x
	top = Tuning.tile_top(sim_pos.y - 1)
	bottom = top + Tuning.TILE * length
	teleport(Vector2i(vine_x, top))
	super._apply_params(params)
	hits_left = 1
	hits_total = 1
	var biome: String = str(Game.level.meta.get("biome", "jungle")) if Game.level != null else "jungle"
	_row = maxi(LevelData.BIOMES.find(biome), 0)
	_set_rolled(rolled)


func _set_rolled(is_rolled: bool) -> void:
	unrolled = not is_rolled
	opened = unrolled
	unroll_left = 0
	queue_redraw()


# --- Queries for the hero (player-B) ----------------------------------------------------------------------------------

## True when it hangs and can be grabbed (an unroll animation has finished).
func is_climbable() -> bool:
	return unrolled and unroll_left == 0


## The geometric part of the grab test of PHYSICS.md C.4 for a feet point (x, y): |x - vine_x| <= VINE_GRAB_DX,
## y > top and y - VINE_HAND_REACH_PX <= bottom. The hero's own conditions (UP, hurt, strike, glider, curl, mount,
## egg, re-grab lock) are his.
func reaches(x: int, y: int) -> bool:
	return absi(x - vine_x) <= Tuning.VINE_GRAB_DX and y > top and y - Tuning.VINE_HAND_REACH_PX <= bottom


## Where a rolled vine can be struck, logical px: its anchor cell and the cell above it (16 x 32).
func coil_rect() -> Rect2i:
	return Rect2i(vine_x - Tuning.TILE / 2, top - Tuning.TILE, Tuning.TILE, Tuning.TILE * 2)


## The first climbable vine of the level (spawn order) whose [method reaches] holds for the feet point (x, y);
## `skip` (the vine of a running re-grab lock) is passed over. Null when none.
static func find_grab(level: LevelBase, x: int, y: int, skip: Vine = null) -> Vine:
	if level == null:
		return null
	var hittables: Array[SimEntity] = level.get_kind(Defs.Kind.HITTABLE)
	for i: int in hittables.size():
		var vine: Vine = hittables[i] as Vine
		if vine != null and vine != skip and vine.is_climbable() and vine.reaches(x, y):
			return vine
	return null


## True when the level holds at least one vine, rolled or not (HeroClimb.setup switches on for it).
static func level_has_vines(level: LevelBase) -> bool:
	if level == null:
		return false
	for entity: SimEntity in level.get_kind(Defs.Kind.HITTABLE):
		if entity is Vine:
			return true
	return false


# --- Unrolling --------------------------------------------------------------------------------------------------------

## Unroll a rolled vine (a weapon hit or a batted ball, `source` the hero or his weapon). True when it unrolled now;
## false when it already hangs.
func unroll(source: SimEntity = null) -> bool:
	if unrolled:
		return false
	_doze_wake_now()
	unrolled = true
	opened = true
	unroll_left = UNROLL_TICKS
	if source is PlayerBase:
		strike_dir = source.facing
	Audio.play_sfx(Sfx.VINE_CLIMB if AudioTable.SFX.has(Sfx.VINE_CLIMB) else Sfx.SPOT_OPENED)
	if Game.level != null:
		Game.level.spawn_fx(&"fx/star_puff", Vector2i(vine_x, top - Tuning.TILE / 2))
	Events.hittable_hit.emit(self, true)
	queue_redraw()
	return true


## The hidden-tile test of PHYSICS.md 8.3 #2 on the coil: the cell above the anchor (`cell`, level with a hero on the
## ledge) or the anchor cell below it. False once it hangs: weapons pass a hanging vine.
func is_hit_by(origin: Vector2i) -> bool:
	if unrolled:
		return false
	if absi(cell.x - (origin.x >> 4)) > Tuning.HIDDEN_HIT_COLS:
		return false
	for row: int in [cell.y, cell.y + 1]:
		if absi(row * Tuning.TILE - (origin.y - Tuning.TILE)) < Tuning.HIDDEN_HIT_PX:
			return true
	return false


## A weapon reached the coil: it unrolls (the box is consumed). Never a hidden spot: no completion count, no
## Events.hidden_spot_opened, no flood fill.
func take_hit(_power: int, source: SimEntity) -> bool:
	return unroll(source)


func _sim_tick(phase: int) -> void:
	super._sim_tick(phase)
	if phase == Defs.Phase.WORLD and unroll_left > 0:
		unroll_left -= 1
		queue_redraw()
		if unroll_left == 0:
			_doze_note()


func _is_idle() -> bool:
	return unroll_left == 0


## Dozing: the whole hanging length counts (a hero may reach its bottom from far below the anchor).
func _doze_area() -> Rect2i:
	return Rect2i(vine_x - Tuning.TILE / 2, top - Tuning.TILE, Tuning.TILE, bottom - top + Tuning.TILE)


## Unrolled vines stay unrolled through deaths and team wipes; nothing to reset.
func _on_level_reset() -> void:
	unroll_left = 0


# --- Picture ----------------------------------------------------------------------------------------------------------

func _process(delta: float) -> void:
	if unrolled or not is_visible_in_tree():
		return
	var before: int = int(_wiggle / WIGGLE_SECONDS)
	_wiggle += delta
	if int(_wiggle / WIGGLE_SECONDS) != before:
		queue_redraw()


func _draw() -> void:
	if not unrolled:
		var wiggle: bool = (int(_wiggle / WIGGLE_SECONDS) & 1) == 1
		_draw_piece(COL_COIL_WIGGLE if wiggle else COL_COIL, 0)
		return
	var shown: int = length
	if unroll_left > 0:
		shown = maxi(1, length * (UNROLL_TICKS - unroll_left) / UNROLL_TICKS)
	for i: int in shown:
		var column: int = COL_SEGMENT_A if (i & 1) == 1 else COL_SEGMENT_B
		if i == 0:
			column = COL_TOP
		elif i == length - 1:
			column = COL_TIP
		_draw_piece(column, i)
	if unroll_left > 0:
		var step: int = (UNROLL_TICKS - unroll_left) * UNROLL_COLUMNS.size() / UNROLL_TICKS
		_draw_piece(UNROLL_COLUMNS[mini(step, UNROLL_COLUMNS.size() - 1)], shown - 1)


## One 32 x 32 art px piece of the sheet, its top `cells` cells below the anchor point.
func _draw_piece(column: int, cells: int) -> void:
	var rows: int = maxi(SHEET.get_height() / CELL_ART, 1)
	var source: Rect2 = Rect2(column * CELL_ART, clampi(_row, 0, rows - 1) * CELL_ART, CELL_ART, CELL_ART)
	draw_texture_rect_region(SHEET, Rect2(-CELL_ART / 2, cells * CELL_ART, CELL_ART, CELL_ART), source)
