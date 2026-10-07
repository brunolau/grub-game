class_name Painting
extends CollectibleBase
## `items/painting` (`index` 0..29): a Cave Painting fragment, the 2.0 meta-goal (DESIGN.md C.9, GAMEPLAY.md 13.7).
## Indices 0-19 are the Book II levels (one per level, the same index in its solo and co-op file), 20-29 lie behind an
## x2 secret in ten Book I co-op files. Each pays Tuning.PAINTING_POINTS and counts for completion like any placed
## bonus item; the find is recorded profile-wide across modes (Save.add_painting) and announced with
## Events.painting_found(index). A fragment found before (in any run or mode) shows as an outline and pays its points
## again without counting twice (Save.add_painting returns false for it).
##
## Owner: objects-B (docs/expansion/PLAN.md 4.1). A key item: a dropped copy (out of a big spot, content token
## `painting:<index>`) never blinks away and comes back when it falls into a pit. Picture: sprites/items/painting.png
## (ASSET_MANIFEST 17.4: 6 x 2 cells of 32 x 32 art px; column = index % 6, row 1 = the "found before" outline).

## Columns of the sheet (one glyph per column; the index picks one).
const SHEET_COLUMNS: int = 6

## True when this fragment was already in the save when the level spawned it (drawn as an outline).
var found_before: bool = false
## True when collecting it added a new painting to the save (false for a fragment found before).
var was_new: bool = false


func _init() -> void:
	super()
	item_id = &"items/painting"
	expires = false
	pickup_sfx = Sfx.PICKUP_BIG
	points = Tuning.PAINTING_POINTS
	set_box(Vector3i(16, 16, 8))


func _apply_params(params: Dictionary) -> void:
	super._apply_params(params)
	if index < 0 or index >= Tuning.PAINTING_COUNT:
		push_warning("items/painting: index %d is outside 0..%d" % [index, Tuning.PAINTING_COUNT - 1])
		index = clampi(index, 0, Tuning.PAINTING_COUNT - 1)
	found_before = Save.has_painting(index)
	_update_look()


func _apply(_hero: PlayerBase) -> bool:
	was_new = Save.add_painting(index)
	Events.painting_found.emit(index)
	return true


## The glyph of its index, the outline row when it was found before.
func _update_look() -> void:
	show_cell(index % SHEET_COLUMNS + (SHEET_COLUMNS if found_before else 0))
