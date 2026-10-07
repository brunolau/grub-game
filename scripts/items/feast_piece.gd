class_name FeastPiece
extends CollectibleBase
## `items/feast_piece`: one of the three pieces of the feast kit, `index` 0..2 = bowl, flint, log. The third
## piece starts the feast: enemies are food and die on touch for Tuning.FEAST_TICKS (GAMEPLAY.md 8.3).


func _init() -> void:
	super()
	item_id = &"items/feast_piece"
	expires = false


## The kit is the team's (Game); the collector feasts. 2.0 co-op (DESIGN.md D.1, GAMEPLAY.md 13.9.2): any hero's
## three pieces feast every hatched hero of the party (the collector first, then the others in slot order).
func _apply(hero: PlayerBase) -> bool:
	if Game.collect_feast_piece(index):
		hero.start_feast()
		var level: LevelBase = Game.level
		if ObjTuning.coop_rules(level):
			for other: PlayerBase in level.contact_order():
				if other != hero and other.is_party_targetable():
					other.start_feast()
	return true


func _update_look() -> void:
	show_cell(ItemTable.CELL_FEAST_FIRST + clampi(index, 0, Tuning.FEAST_PIECES - 1))
