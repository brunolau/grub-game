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
##
## THE WARD (wf11 ruling R3; `ward=<left>,<right>` optional): every tablet wards the tile columns from its own cell to
## its `far` cell, widened by PartyTuning.WARD_MARGIN_CELLS cells on both sides - or by `ward=<left>,<right>` cells
## (two whole numbers >= 0: the width added left of the leftmost and right of the rightmost of the two cells) - over
## all rows of the map ([method ward_columns]; the tablet declares it to the level, LevelBase.set_ward). Inside a ward
## no enemy gives a hero of a co-op party lift, rest or carry: coming down on a head changes neither his velocity nor
## his position, a club hit on an enemy gives no pogo, the stomp counts against the enemy as elsewhere and that enemy
## does not hurt him during that fall (Player, PHYSICS.md C.10). Partners' shoulders, mounts, rafts, lifts, springs and
## bosses are untouched. Tools that read the level file (the validator, the solo search, the explorer) get the same
## columns from the static [method ward_columns].

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
## The ward's first and last tile column ([method ward_columns]; not clamped to the map - the level does that).
var ward: Vector2i = Vector2i.ZERO

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
	if params.has("ward") and parse_ward(params["ward"]).x < 0:
		push_warning("objects/x2_tablet '%s': ward='%s' is not two whole numbers >= 0 (left,right cells) - the default %d is used"
				% [gate_name, str(params["ward"]), PartyTuning.WARD_MARGIN_CELLS])
	ward = ward_columns(sim_pos.x >> 4, far_cell.x, params.get("ward", ""))
	_sprite = get_node_or_null(^"Sprite") as Sprite2D
	_show()


## The ward is the level's to keep (LevelBase.set_ward): declared when the tablet enters the level, forgotten when it
## leaves.
func _enter_tree() -> void:
	if Game.level != null:
		Game.level.set_ward(self, ward.x, ward.y)


func _exit_tree() -> void:
	if Game.level != null:
		Game.level.clear_ward(self)


## A `ward=<left>,<right>` parameter as Vector2i(left, right) cells; (-1, -1) when it is not two whole numbers >= 0.
static func parse_ward(value: Variant) -> Vector2i:
	var widths: Vector2i = parse_cell(value)
	return widths if widths.x >= 0 and widths.y >= 0 else Vector2i(-1, -1)


## The ward of a tablet standing in tile column `tablet_col` whose `far` cell is in column `far_col` (< 0: no far
## cell - the tablet's own column alone), as Vector2i(first column, last column): the columns between the two cells,
## widened on each side by PartyTuning.WARD_MARGIN_CELLS, or by the two widths of `ward_param` (the tablet's
## `ward=<left>,<right>` text; anything else - "" for a tablet without one - means the default). Not clamped to the
## map. The same answer for the entity and for a tool that only read the level file.
static func ward_columns(tablet_col: int, far_col: int, ward_param: Variant = "") -> Vector2i:
	var widths: Vector2i = parse_ward(ward_param)
	if widths.x < 0:
		widths = Vector2i(PartyTuning.WARD_MARGIN_CELLS, PartyTuning.WARD_MARGIN_CELLS)
	var low: int = tablet_col if far_col < 0 else mini(tablet_col, far_col)
	var high: int = tablet_col if far_col < 0 else maxi(tablet_col, far_col)
	return Vector2i(low - widths.x, high + widths.y)


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
