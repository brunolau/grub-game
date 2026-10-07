class_name X2Tablet
extends SimEntity
## `objects/x2_tablet gate=<name> far=<col>,<row> [secret]` (DESIGN.md D.5, GAMEPLAY.md 13.9.7, LEVEL_DESIGN.md
## 15.7.4): the stone tablet carved with two cavemen holding hands that marks every co-op gate (frame 0) and every
## co-op secret (`secret`, frame 1: a gem above the joined hands) - diegetic, no HUD. It stands on the near side of its
## gate. `far` is the air cell beyond the gate that a hero reaches only through it: the goal of the solo-impossibility
## search (world-B's scripts/world/coop_search.gd, tests/test_coop_gates.gd read the level file, not this entity).
##
## In the game it only reacts once: when a hatched hero who is not IDLE (PlayerBase.counts_for_coop, the phase-3 IDLE
## rule) first stands in its `far` cell, the gate counts as solved and
## the carved marks light up (frame 2) for the rest of the stage (a team wipe does not darken them). The marks are a
## picture; nothing in the simulation reads [member solved].

const FRAME_GATE: int = 0
const FRAME_SECRET: int = 1
const FRAME_SOLVED: int = 2
const ID_STAR_PUFF: StringName = &"fx/star_puff"

## The gate (or secret) this tablet marks (`gate`).
var gate_name: StringName = &""
## The cell beyond the gate (`far=c,r`); (-1, -1) when the parameter is missing or malformed.
var far_cell: Vector2i = Vector2i(-1, -1)
## True for an x2 secret (`secret`).
var secret: bool = false
## True once a hatched hero stood in [member far_cell].
var solved: bool = false

var _sprite: Sprite2D = null


func _init() -> void:
	z_index = Defs.Z_OBJECTS
	# 56 x 40 art px = 28 x 20 logical px (ASSET_MANIFEST: x2_tablet), bottom-centred.
	set_box(Vector3i(28, 20, 14))


func _sim_phases() -> PackedInt32Array:
	return PackedInt32Array([Defs.Phase.WORLD])


func _apply_params(params: Dictionary) -> void:
	gate_name = StringName(str(params.get("gate", "")))
	secret = param_bool("secret")
	far_cell = parse_cell(params.get("far", ""))
	_sprite = get_node_or_null(^"Sprite") as Sprite2D
	_show()


## A `c,r` cell parameter as a Vector2i, (-1, -1) when it is not two integers.
static func parse_cell(value: Variant) -> Vector2i:
	var parts: PackedStringArray = str(value).replace(" ", "").split(",")
	if parts.size() != 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int():
		return Vector2i(-1, -1)
	return Vector2i(parts[0].to_int(), parts[1].to_int())


func _sim_tick(_phase: int) -> void:
	if solved or far_cell.x < 0:
		return
	var level: LevelBase = Game.level
	if level == null:
		return
	for hero: PlayerBase in level.contact_order():
		if hero.counts_for_coop() and stands_in_far_cell(hero):
			solved = true
			_show()
			level.spawn_fx(ID_STAR_PUFF, Vector2i(sim_pos.x, sim_pos.y - (box_h >> 1)))
			return


## True when `hero`'s feet point lies in the far cell (the cell he stands in: the point 1 px above his feet).
func stands_in_far_cell(hero: SimEntity) -> bool:
	return (hero.sim_pos.x >> 4) == far_cell.x and ((hero.sim_pos.y - 1) >> 4) == far_cell.y


## Dozing (SimEntity, ARCHITECTURE.md 11): its only test is a hero in the far cell, which fails while every hero is
## far from it and from the tablet.
func _doze_area() -> Rect2i:
	var area: Rect2i = _doze_box()
	if far_cell.x >= 0:
		area = area.merge(Rect2i(far_cell * Tuning.TILE, Vector2i(Tuning.TILE, Tuning.TILE)))
	return area


func _can_doze() -> bool:
	return true


func _show() -> void:
	if _sprite == null:
		return
	if solved:
		_sprite.frame = FRAME_SOLVED
	else:
		_sprite.frame = FRAME_SECRET if secret else FRAME_GATE
