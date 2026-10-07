class_name MessageZone
extends ZoneBase
## `zones/message`: a hint shown while the hero's feet are inside the rectangle. Owner: world.
## Parameters: `rect`, `text` (a translation key; shown through tr(), so plain text works as well).
##
## The zone draws nothing itself: it asks for its hint through Events.message_requested and the HUD shows it on
## a readable panel in screen space (inside the safe area), so the text never disappears into a busy scene.

## Translation key of the hint.
var text_key: String = ""

var _shown: bool = false


func _apply_params(params: Dictionary) -> void:
	super._apply_params(params)
	text_key = param_str("text", "")


func _exit_tree() -> void:
	_set_shown(false)


## True while the hint is requested (the hero's feet are inside; a party: any hero's).
func is_shown() -> bool:
	return _shown


func _on_first_entered(_level: LevelBase, _hero: PlayerBase) -> void:
	_set_shown(true)


func _on_last_exited(_level: LevelBase, _hero: PlayerBase) -> void:
	_set_shown(false)


func _on_level_reset() -> void:
	super._on_level_reset()
	_set_shown(false)


func _set_shown(shown: bool) -> void:
	if shown == _shown or text_key.is_empty():
		return
	_shown = shown
	Events.message_requested.emit(self, text_key if shown else "")
