class_name FireStarter
extends CollectibleBase
## `items/fire_starter`: the torch that lights every locked exit totem of the level (GAMEPLAY.md 7.6). It lies in
## the level or is dropped by a boss.


func _init() -> void:
	super()
	item_id = &"items/fire_starter"
	expires = false


func _apply(_hero: PlayerBase) -> bool:
	Game.unlock_exit()
	return true


func _update_look() -> void:
	show_cell(ItemTable.CELL_FIRE_STARTER)
