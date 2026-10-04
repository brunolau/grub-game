class_name GiantBonus
extends CollectibleBase
## `items/giant_bonus`: the big food that falls from the sky when a big hidden spot is used up, 10 000 - 60 000
## points. `index` 0..6 selects the cell of `sprites/items/giant_bonus.png`.
##
## A dropped one that is still falling fast when it touches the hero bounces off his head once, to a random
## side and sometimes with a screen shake, before it can be collected (GAMEPLAY.md 4.5).

var _bounced: bool = false


func _init() -> void:
	super()
	item_id = &"items/giant_bonus"
	counts_for_tally = true
	pickup_sfx = Sfx.PICKUP_BIG
	set_box(Vector3i(28, 28, 14))


func _apply_params(params: Dictionary) -> void:
	super._apply_params(params)
	if not params.has("points"):
		points = ItemTable.giant_points(index)


func _apply(_hero: PlayerBase) -> bool:
	if not dropped or _bounced or yvel < ObjTuning.GIANT_BOUNCE_MIN_YVEL:
		return true
	_bounced = true
	yvel = -yvel
	xvel = ObjTuning.GIANT_BOUNCE_XVEL
	if Sim.rng.chance(1, 2):
		xvel = -xvel
		if Game.level != null:
			Game.level.request_shake(ObjTuning.SHAKE_GIANT_BOUNCE)
	Audio.play_sfx(Sfx.BOUNCE)
	return false
