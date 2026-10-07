class_name FeastPiece
extends CollectibleBase
## `items/feast_piece`: one of the three pieces of the feast kit, `index` 0..2 = bowl, flint, log. The third
## piece starts the feast: enemies are food and die on touch for Tuning.FEAST_TICKS (GAMEPLAY.md 8.3).


func _init() -> void:
	super()
	item_id = &"items/feast_piece"
	expires = false


## The kit is the team's (Game); the collector feasts. (A full kit feeding every living hero of a party is the co-op
## rule of DESIGN.md D / PLAN.md phase 1, not built here.)
func _apply(hero: PlayerBase) -> bool:
	if Game.collect_feast_piece(index):
		hero.start_feast()
	return true


func _update_look() -> void:
	show_cell(ItemTable.CELL_FEAST_FIRST + clampi(index, 0, Tuning.FEAST_PIECES - 1))
