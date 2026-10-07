class_name TarSplitter
extends Walker
## `enemies/tar_splitter` - the co-op Tar Splitter (GAMEPLAY.md 13.9.6, DESIGN.md D.7): a Walker with the `split` trait
## in the fen's slime skin. With two heroes the first hit splits it without damage into two halves of 0 hit points
## (the half it spawns wears the other palette of its sheet - `slime` / `slime_b`, the two halves of art-B's
## hand-over - and shows `squash` as it splits off) that run apart for 22 ticks and then patrol; both must die within
## the window (capped by `window`), or the dead half regrows next to the living one and they merge back into the
## whole. Only in co-op files; a party of one meets a plain Walker. Tar blobs falling from the sky are
## `enemies/dropper coop=split skin=slime` (the trait on the archetype).
##
## Parameters: as `enemies/walker` (`left`, `right`, `speed`), `window` ticks (the cap of LEVEL_DESIGN.md 15.7.6),
## `skin` [slime; Expert slime_b; Feast Land D: a honey skin when it lands], `hp` [25], `score` [0]; `coop=` overrides
## the preset's trait.


func _default_skin() -> String:
	return "slime"


func _apply_params(params: Dictionary) -> void:
	if not params.has("coop"):
		coop_trait = Defs.CoopTrait.SPLIT
	super._apply_params(params)


## The half this splitter spawned: the other palette of the source's sheet (when the sheet has two).
func _on_coop_copy(source: EnemyBase) -> void:
	var other: String = other_palette(source.skin)
	if other != skin:
		_apply_skin(other)
	_play(&"squash", true)


## The other palette of sheet `sheet`: `x_b` <-> `x`; `sheet` itself when it has no second palette.
static func other_palette(sheet: String) -> String:
	if sheet.ends_with(EnemySkin.VARIANT_SUFFIX):
		return sheet.left(sheet.length() - EnemySkin.VARIANT_SUFFIX.length())
	var variant: String = sheet + EnemySkin.VARIANT_SUFFIX
	return variant if EnemySkin.find(variant) != null else sheet
