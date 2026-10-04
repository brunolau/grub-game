class_name KillAll
extends CollectibleBase
## `items/kill_all`: the chili. Every enemy on screen dies normally and pays its score; strong screen shake.
## Reappears when the hero respawns (GAMEPLAY.md 4.1, PHYSICS.md 10.4).


func _init() -> void:
	super()
	item_id = &"items/kill_all"
	reappears_on_respawn = true
	pickup_sfx = Sfx.EXPLOSION


func _apply(hero: PlayerBase) -> bool:
	ItemEffects.kill_all(hero)
	return true


func _update_look() -> void:
	show_cell(ItemTable.CELL_KILL_ALL)
