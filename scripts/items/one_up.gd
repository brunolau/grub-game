class_name OneUp
extends CollectibleBase
## `items/one_up`: +1 life, up to Tuning.LIVES_MAX (GAMEPLAY.md 3.6).


func _init() -> void:
	super()
	item_id = &"items/one_up"
	pickup_sfx = Sfx.ONE_UP


func _apply(_hero: PlayerBase) -> bool:
	Game.add_lives(1)
	Events.popup_requested.emit(&"one_up", 1, Vector2i(sim_pos.x, sim_pos.y - box_h))
	return true


func _update_look() -> void:
	show_cell(ItemTable.CELL_ONE_UP)
