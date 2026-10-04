class_name SecretZone
extends ZoneBase
## `zones/secret` (ARCHITECTURE.md 7.7): a secret area, counted once when the hero's feet first enter it.
## Owner: world. Parameters: `rect`, `name`. The find survives deaths and respawns.

## True once the hero found this secret.
var found: bool = false


func _on_hero_entered(_level: LevelBase, _hero: PlayerBase) -> void:
	if found:
		return
	found = true
	Game.secrets_found += 1
	Audio.play_sfx(Sfx.SPOT_OPENED)
	Events.secret_found.emit(zone_name)
