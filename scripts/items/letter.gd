class_name Letter
extends CollectibleBase
## `items/letter`: one letter of the bonus word, `index` 0..4 = G R U B S. Letters are kept between levels;
## completing the word clears it and drops the jackpot chest from above the hero (GAMEPLAY.md 4.3).

const ID_JACKPOT: StringName = &"items/jackpot"
## A world letter shimmers (brightness pulse, presentation only), so it never reads as one of the HUD's letter
## tiles when it lies near the top of the view.
const SHIMMER_SECONDS: float = 1.2
const SHIMMER_BOOST: float = 0.35

var _shimmer: float = 0.0


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


func _process(delta: float) -> void:
	var sprite: CanvasItem = get_node_or_null(^"Sprite") as CanvasItem
	if sprite == null or not sprite.is_visible_in_tree():
		return
	_shimmer = fmod(_shimmer + delta / SHIMMER_SECONDS, 1.0)
	var glow: float = 1.0 + SHIMMER_BOOST * (0.5 + 0.5 * sin(_shimmer * TAU))
	sprite.self_modulate = Color(glow, glow, glow * 0.85)
