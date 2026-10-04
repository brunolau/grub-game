class_name Letter
extends CollectibleBase
## `items/letter`: one letter of the bonus word, `index` 0..4 = G R U B S. Letters are kept between levels;
## completing the word clears it and drops the jackpot chest from above the hero (GAMEPLAY.md 4.3).

const ID_JACKPOT: StringName = &"items/jackpot"


func _init() -> void:
	super()
	item_id = &"items/letter"
	expires = false
	pickup_sfx = Sfx.PICKUP_LETTER
	set_box(Vector3i(20, 20, 10))


func _apply(hero: PlayerBase) -> bool:
	if Game.collect_letter(index) and Game.level != null:
		var from: Vector2i = Vector2i(hero.sim_pos.x, ItemEffects.sky_drop_y(hero.sim_pos.x, hero.sim_pos.y))
		Game.level.spawn(ID_JACKPOT, from, {"dropped": true})
		Audio.play_sfx(Sfx.GIANT_BONUS)
	return true
