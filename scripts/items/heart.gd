class_name Heart
extends CollectibleBase
## `items/heart`: +1 heart. At full energy it stays where it is (GAMEPLAY.md 4.1).


func _init() -> void:
	super()
	item_id = &"items/heart"
	pickup_sfx = Sfx.HEART


func _apply(_hero: PlayerBase) -> bool:
	if not Game.add_heart():
		return false
	Events.popup_requested.emit(&"heart", 1, Vector2i(sim_pos.x, sim_pos.y - box_h))
	return true


func _update_look() -> void:
	show_cell(ItemTable.CELL_HEART)
