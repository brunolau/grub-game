class_name Skull
extends CollectibleBase
## `items/skull`: the bad item. Touching it throws the hero into the hurt pose and scatters ALL his energy as
## bones (hearts drop to 0, he is not dead yet), with a screen shake (GAMEPLAY.md 4.1).


func _init() -> void:
	super()
	item_id = &"items/skull"
	pickup_sfx = Sfx.PLAYER_HURT_HEAVY


func _apply(hero: PlayerBase) -> bool:
	return ItemEffects.skull(hero, self)


func _update_look() -> void:
	show_cell(ItemTable.CELL_SKULL)
