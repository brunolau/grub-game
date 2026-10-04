class_name SceneryHittable
extends HittableBase
## Shared look and juice of the hittables of this module (hidden spots, breakable blocks, containers): the
## biome-dependent debris, the wobble of a hit picture, and the point where thrown-out things appear.

## Debris kind of fx/debris per level biome.
const BIOME_DEBRIS: Dictionary = {
	"jungle": "leaf", "cave": "rock", "ice": "ice", "volcano": "rock", "feast": "wood", "village": "wood",
}
## Sideways wobble of a hit picture in art px, one entry per tick after the hit.
const WOBBLE_ART: Array[int] = [3, -3, 2, -2, 1, -1]
const ID_DEBRIS: StringName = &"fx/debris"
const ID_POOF: StringName = &"fx/poof"

var _wobble: int = 0
var _wobble_node: Node2D = null
var _wobble_rest_x: float = 0.0


func _sim_tick(phase: int) -> void:
	super._sim_tick(phase)
	if phase == Defs.Phase.WORLD and _wobble > 0:
		_wobble -= 1
		if _wobble_node != null:
			var step: int = WOBBLE_ART.size() - 1 - _wobble
			_wobble_node.position.x = _wobble_rest_x + (0.0 if _wobble == 0 else float(WOBBLE_ART[step]))


## Debris kind of the running level ("rock" outside a level).
static func level_debris_kind() -> String:
	var level: LevelBase = Game.level
	if level == null:
		return "rock"
	return str(BIOME_DEBRIS.get(str(level.meta.get("biome", "jungle")), "rock"))


## Let `node` (a picture of this hittable) wobble sideways for a few ticks.
func wobble(node: Node2D) -> void:
	if node == null:
		return
	if _wobble_node != node:
		_wobble_node = node
		_wobble_rest_x = node.position.x
	_wobble = ObjTuning.HIT_WOBBLE_TICKS


## Spray `count` bits of debris of `kind` from `pos`.
func spray(kind: String, count: int, pos: Vector2i) -> void:
	if Game.level != null:
		Game.level.spawn_fx(ID_DEBRIS, pos, {"kind": kind, "count": count})


## Where something thrown out of this cell appears, and the speed it leaves with: Vector4i(x, y, xvel, yvel).
## Out of the top when the cell above is open (the usual case: a spot in the floor or a free-standing thing);
## otherwise out of the open side the strike came from; otherwise out of the bottom (a spot in a ceiling).
## `xvel` / `yvel` is the speed of a throw out of the top.
func emerge(xvel: int, yvel: int) -> Vector4i:
	var level: LevelBase = Game.level
	var feet: Vector2i = Vector2i(cell.x * Tuning.TILE + Tuning.TILE / 2, cell.y * Tuning.TILE + Tuning.TILE)
	if level == null or not _is_solid(level.grid, cell.x, cell.y):
		return Vector4i(feet.x, feet.y, xvel, yvel)
	var grid: TileGrid = level.grid
	if not _is_solid(grid, cell.x, cell.y - 1):
		return Vector4i(feet.x, cell.y * Tuning.TILE, xvel, yvel)
	var back: int = -strike_dir
	if not _is_solid(grid, cell.x + back, cell.y):
		return Vector4i(feet.x + back * Tuning.TILE, feet.y, back * absi(xvel), ObjTuning.SPOT_FACE_YVEL)
	if not _is_solid(grid, cell.x - back, cell.y):
		return Vector4i(feet.x - back * Tuning.TILE, feet.y, -back * absi(xvel), ObjTuning.SPOT_FACE_YVEL)
	return Vector4i(feet.x, feet.y + Tuning.TILE, Tuning.shr(back * absi(xvel), 1), 0)


func _is_solid(grid: TileGrid, col: int, row: int) -> bool:
	return grid.side_at(col, row) == TileGrid.SIDE_WALL or grid.ceiling_at(col, row) == TileGrid.CEILING_SOLID
