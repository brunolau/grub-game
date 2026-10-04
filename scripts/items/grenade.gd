class_name Grenade
extends CollectibleBase
## `items/grenade`: the coconut bomb. Every enemy on screen vanishes into 16 random bonus items.
## Reappears when the hero respawns (GAMEPLAY.md 4.1, 8.3).


func _init() -> void:
	super()
	item_id = &"items/grenade"
	reappears_on_respawn = true
	pickup_sfx = Sfx.EXPLOSION


func _apply(_hero: PlayerBase) -> bool:
	ItemEffects.grenade()
	if Game.level != null:
		Game.level.spawn_fx(ItemEffects.ID_EXPLOSION, Vector2i(sim_pos.x, sim_pos.y - (box_h >> 1)))
	return true


func _update_look() -> void:
	show_cell(ItemTable.CELL_GRENADE)
