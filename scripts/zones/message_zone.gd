class_name MessageZone
extends ZoneBase
## `zones/message`: a hint shown above the rectangle while the hero's feet are inside it. Owner: world.
## Parameters: `rect`, `text` (a translation key; shown through tr(), so plain text works as well).
##
## The text is a world-space label (it scrolls with the level), fading in and out over a few frames.

## Seconds of the fade in / out (cosmetic).
const FADE_SECONDS: float = 0.2
## Art px between the top of the rectangle and the bottom of the text.
const GAP: float = 8.0

## Translation key of the hint.
var text_key: String = ""

var _target: float = 0.0

@onready var _label: Label = $Text


func _apply_params(params: Dictionary) -> void:
	super._apply_params(params)
	text_key = param_str("text", "")


func _ready() -> void:
	_label.text = tr(text_key)
	_label.modulate.a = 0.0
	_label.visible = false
	_label.reset_size()
	# The label is placed relative to the feet point the node is drawn at.
	var top_centre: Vector2 = Tuning.to_art(Vector2(rect.get_center().x, rect.position.y) - Vector2(sim_pos))
	_label.position = (top_centre - Vector2(_label.size.x * 0.5, _label.size.y + GAP)).round()


func _process(delta: float) -> void:
	var alpha: float = move_toward(_label.modulate.a, _target, delta / FADE_SECONDS)
	_label.modulate.a = alpha
	_label.visible = alpha > 0.0


## True while the hint is shown (or fading in).
func is_shown() -> bool:
	return _target > 0.0


func _on_hero_entered(_level: LevelBase, _hero: PlayerBase) -> void:
	_target = 1.0


func _on_hero_exited(_level: LevelBase, _hero: PlayerBase) -> void:
	_target = 0.0


func _on_level_reset() -> void:
	super._on_level_reset()
	_target = 0.0
