class_name Trophy
extends CollectibleBase
## `items/trophy`: dropped by the final boss; touching one starts the ending (GAMEPLAY.md 6.3).


func _init() -> void:
	super()
	item_id = &"items/trophy"
	expires = false
	pickup_sfx = Sfx.PICKUP_BIG


func _apply(hero: PlayerBase) -> bool:
	if Game.level == null or Game.level.completed:
		return false
	hero.set_control_enabled(false)
	Game.level.complete(&"trophy")
	return true


func _update_look() -> void:
	show_cell(ItemTable.CELL_TROPHY)
