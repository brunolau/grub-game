class_name Leech
extends Lurker
## `enemies/leech` - the co-op Leech (GAMEPLAY.md 13.9.6, DESIGN.md D.7): a Lurker with the `leech` trait. It hangs at
## its anchor, drops when a hero comes within `range` tiles and chases the nearest; with two heroes a hero it touches
## (except by landing on its head) gets it on his back instead of being hurt: it drains one bone per 44 ticks
## (PartyTuning.LEECH_DRAIN_TICKS) and only his partner's weapon reaches it (alone it falls off after 220 ticks).
## Shown with the sheet's `front` frames while it rides. Only in co-op files; a party of one meets a plain Lurker.
##
## Parameters: as `enemies/lurker` (`range`, `pause`), `skin` [leech], `hp` [25], `score` [2]; `coop=` overrides the
## preset's trait.


func _default_skin() -> String:
	return "leech"


func _apply_params(params: Dictionary) -> void:
	if not params.has("coop"):
		coop_trait = Defs.CoopTrait.LEECH
	super._apply_params(params)
