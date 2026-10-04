class_name Walker
extends Patroller
## `enemies/walker` - archetype 9, ground patroller (GAMEPLAY.md 5.2): patrols between its limits on the ground,
## following floors and slopes, with gravity and a turn at walls.
##
## Parameters: `left` [-3], `right` [3] tiles relative to the anchor, `speed` v16 [32], `skin` [turtle], `hp` [25],
## `score` [0].


func _default_skin() -> String:
	return "turtle"


func _apply_params(params: Dictionary) -> void:
	score_index = EnemyTuning.SCORE_WALKER
	super._apply_params(params)


func _move() -> void:
	var before: int = xvel
	_ground_step(false, true)
	if before != 0 and signi(xvel) != signi(before):
		_bounced(xvel)


func _move_role() -> StringName:
	return &"walk" if Tuning.floor16(absi(xvel)) != 0 else &"idle"
