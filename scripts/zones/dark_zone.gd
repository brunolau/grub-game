class_name DarkZone
extends ZoneBase
## `zones/dark` (GAMEPLAY.md 7.10): entering switches the level's darkness on (`on=true`, the default) or off
## (`on=false`); the palette fades over Tuning.DARKNESS_FADE_TICKS. Owner: world. Parameters: `rect`, `on`.

## Darkness this zone switches to.
var switch_on: bool = true


func _apply_params(params: Dictionary) -> void:
	super._apply_params(params)
	switch_on = param_bool("on", true)


func _on_hero_entered(level: LevelBase, _hero: PlayerBase) -> void:
	level.set_darkness(switch_on)
