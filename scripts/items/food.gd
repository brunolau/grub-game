class_name Food
extends CollectibleBase
## `items/food`: the common bonus item. `index` 0..47 selects the cell of `sprites/items/food.png`; the score
## (100 - 1 000) comes from the manifest table (GAMEPLAY.md 3.2).


func _init() -> void:
	super()
	item_id = &"items/food"
	counts_for_tally = true


func _apply_params(params: Dictionary) -> void:
	super._apply_params(params)
	if not params.has("points"):
		points = ItemTable.food_points(index)
