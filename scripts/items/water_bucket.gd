class_name WaterBucket
extends CollectibleBase
## `items/water_bucket`: scores like food and washes off the flies that circle the hero (GAMEPLAY.md 4.1, 7.9).
## The flies are cosmetic and drawn by another module, which reacts to Events.item_collected with this id.


func _init() -> void:
	super()
	item_id = &"items/water_bucket"
	counts_for_tally = true


func _apply_params(params: Dictionary) -> void:
	super._apply_params(params)
	if not params.has("points"):
		points = ObjTuning.WATER_BUCKET_POINTS


func _update_look() -> void:
	show_cell(ItemTable.CELL_WATER_BUCKET)
