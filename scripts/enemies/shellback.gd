class_name Shellback
extends Guard
## `enemies/shellback` - the co-op Shellback (GAMEPLAY.md 13.9.6, DESIGN.md D.7): a Guard with the `shell` trait (the
## shield faces the nearer hatched hero every tick, so one hero is always in front and only his partner can hit its
## back) in bone-armour skin. Only in co-op files; a party of one meets a plain Guard (the trait collapses). The keeper
## of 5-1's gully and of the ruins' halls (4 rows high).
## Book I variant (DESIGN.md D.7: `skin=turtle_b`, "walker + shell"): on a Walker sheet (`turtle`, `turtle_b`) it is
## a Walker with the `shell` trait - no shield of its own and no Guard clock, the walker's speed and score - so a party
## of one meets a plain walker there, and in a co-op party the trait turns its front to the nearer hero every tick.
##
## Parameters: as `enemies/guard` (`turn`, `left`, `right`, `speed`), `skin` [shellback; turtle / turtle_b: the walker
## form], `hp` [25], `score` [4; walker form 0]; `coop=` overrides the preset's trait.

## True for the Book I variant on a turtle sheet (the walker form).
var walker_form: bool = false


func _default_skin() -> String:
	return "shellback"


func _apply_params(params: Dictionary) -> void:
	if not params.has("coop"):
		coop_trait = Defs.CoopTrait.SHELL
	super._apply_params(params)
	walker_form = EnemyTuning.SHELLBACK_WALKER_SKINS.has(skin)
	if walker_form:
		score_index = clampi(int(params.get("score", EnemyTuning.SCORE_WALKER)), 0, Tuning.SCORE_LADDER.size() - 1)
		speed = absi(int(params.get("speed", EnemyTuning.PATROL_SPEED)))


func _bears_shield() -> bool:
	return not walker_form
