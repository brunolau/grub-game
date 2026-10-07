class_name AutoscrollStopZone
extends ZoneBase
## `zones/autoscroll_stop` (GAMEPLAY.md 7.11): on an auto-scrolling level, the hero's feet entering the
## rectangle stop the 1 px per tick descent; the normal vertical follow takes over. A respawn restores the
## level's scroll mode (the zone stops it again when the hero comes back). Owner: world. Parameters: `rect`.
## 2.0 `scroll = rising` (PHYSICS.md C.8): the first hero to enter stops the rise for the rest of the stage (the
## band stays, and stays deadly) and the camera returns to the normal follow.


func _on_hero_entered(level: LevelBase, _hero: PlayerBase) -> void:
	level.scroll_flags &= ~Defs.SCROLL_AUTO_DOWN
	if (level.scroll_flags & Defs.SCROLL_RISING) != 0:
		level.scroll_flags &= ~Defs.SCROLL_RISING
		if level.has_method(&"stop_rising"):
			level.call(&"stop_rising")
