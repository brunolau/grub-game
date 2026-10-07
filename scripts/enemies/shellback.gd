class_name Shellback
extends Guard
## `enemies/shellback` - the co-op Shellback (GAMEPLAY.md 13.9.6, DESIGN.md D.7): a Guard with the `shell` trait (the
## shield faces the nearer hatched hero every tick, so one hero is always in front and only his partner can hit its
## back) in bone-armour skin. Only in co-op files; a party of one meets a plain Guard (the trait collapses). The keeper
## of 5-1's gully and of the ruins' halls (4 rows high).
##
## Parameters: as `enemies/guard` (`turn`, `left`, `right`, `speed`), `skin` [shellback], `hp` [25], `score` [4];
## `coop=` overrides the preset's trait.


func _default_skin() -> String:
	return "shellback"


func _apply_params(params: Dictionary) -> void:
	if not params.has("coop"):
		coop_trait = Defs.CoopTrait.SHELL
	super._apply_params(params)
