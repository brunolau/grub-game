class_name GliderPickup
extends CollectibleBase
## `items/glider`: the hang-glider pick-up (GAMEPLAY.md 8.4). It stays in place while the hero already carries a
## glider and reappears when he respawns.


func _init() -> void:
	super()
	item_id = &"items/glider"
	expires = false
	reappears_on_respawn = true
	set_box(Vector3i(20, 20, 10))


func _apply(hero: PlayerBase) -> bool:
	# The collector's own glider (2.0: his PlayerRun; P1's run is Game's, so Game.has_glider in 1.0).
	if hero.run.has_glider:
		return false
	hero.set_glider(true)
	return true


func _update_look() -> void:
	show_cell(0)
