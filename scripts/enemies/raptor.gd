class_name Raptor
extends Hopper
## `enemies/raptor` - the co-op Raptor (GAMEPLAY.md 13.9.6, DESIGN.md D.7): a Hopper with the `daze` trait in the
## temple-raptor skin. With two heroes it hops back out of reach when a hero within 48 px starts a strike and hops
## over a thrown weapon coming at it; a head bounce dazes it PartyTuning.daze_ticks (14 Beginner / 12 Expert, capped by
## its `window`) - showing the sheet's dizzy frames 16-19 - and only a dazed Raptor can be hurt. Only in co-op files; a
## party of one meets a plain Hopper (the trait collapses).
##
## Parameters: as `enemies/hopper` (`range`, `pause`, `jump_x`, `jump_y`), `window` ticks (the daze cap of
## LEVEL_DESIGN.md 15.7.6), `skin` [mini_rex_b], `hp` [25], `score` [2]; `coop=` overrides the preset's trait.


func _default_skin() -> String:
	return "mini_rex_b"


func _apply_params(params: Dictionary) -> void:
	if not params.has("coop"):
		coop_trait = Defs.CoopTrait.DAZE
	super._apply_params(params)
