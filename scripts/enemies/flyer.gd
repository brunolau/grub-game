class_name Flyer
extends Patroller
## `enemies/flyer` - archetype 9, air patroller (GAMEPLAY.md 5.2): patrols between its limits at its anchor height,
## ignoring walls and gravity.
##
## Parameters: `left` [-3], `right` [3] tiles relative to the anchor, `speed` v16 [32], `skin` [bat], `hp` [25],
## `score` [1].


func _default_skin() -> String:
	return "bat"


func _apply_params(params: Dictionary) -> void:
	score_index = EnemyTuning.SCORE_FLYER
	super._apply_params(params)


func _move_role() -> StringName:
	return &"fly"
