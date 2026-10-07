class_name FliesZone
extends ZoneBase
## `zones/flies` (GAMEPLAY.md 7.9): dirty ground. Every time a hero's feet enter the rectangle, `count` flies join
## the cosmetic swarm around HIM (at most Tuning.MAX_FLIES; 2.0: every hero of a party has his own swarm);
## `items/water_bucket` washes them off. Owner: world. Parameters: `rect`, `count` [Tuning.MAX_FLIES / 4].

## Flies gained per visit.
var count: int = Tuning.MAX_FLIES / 4


func _apply_params(params: Dictionary) -> void:
	super._apply_params(params)
	count = clampi(param_int("count", count), 1, Tuning.MAX_FLIES)


func _on_hero_entered(level: LevelBase, hero: PlayerBase) -> void:
	var world_level: Level = level as Level
	if world_level != null:
		world_level.attract_flies(count, hero)
