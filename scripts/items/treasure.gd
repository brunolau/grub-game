class_name Treasure
extends CollectibleBase
## `items/treasure`: gems and jewellery worth 2 000 / 5 000 / 8 000. `index` 0..15 selects the cell of
## `sprites/items/treasure.png` (GAMEPLAY.md 3.2).


func _init() -> void:
	super()
	item_id = &"items/treasure"
	counts_for_tally = true
	pickup_sfx = Sfx.PICKUP_BIG


func _apply_params(params: Dictionary) -> void:
	super._apply_params(params)
	if not params.has("points"):
		points = ItemTable.treasure_points(index)
