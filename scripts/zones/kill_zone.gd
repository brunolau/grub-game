class_name KillZone
extends ZoneBase
## `zones/kill` (PHYSICS.md 10.3): the hero's feet entering the rectangle is an instant death (cause &"pit"),
## for pits that are not at the bottom of the map. Owner: world. Parameters: `rect`.


func _on_hero_entered(_level: LevelBase, hero: PlayerBase) -> void:
	hero.kill(&"pit")
