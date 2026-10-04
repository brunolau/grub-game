class_name Warp
extends CollectibleBase
## `items/warp`: the spiral staff. Touching it leaves the level through the warp route: into the bonus stage of a
## main level, or out of a bonus stage (GAMEPLAY.md 1.1).


func _init() -> void:
	super()
	item_id = &"items/warp"
	expires = false
	pickup_sfx = Sfx.PICKUP_LETTER


func _apply(hero: PlayerBase) -> bool:
	if Game.level == null or Game.level.completed:
		return false
	hero.set_control_enabled(false)
	Game.level.complete(&"warp")
	return true


func _update_look() -> void:
	show_cell(ItemTable.CELL_WARP)
