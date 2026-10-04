class_name CodeStone
extends CollectibleBase
## `items/code_stone`: collectible lore (GAMEPLAY.md 12.4). Stone number `index` 0..3 shows character `index` of
## the level's password for the current mode, carved into the stone; collecting it records "<level>:<index>" in
## the save.

## Number of characters of a password.
const CODE_LENGTH: int = 4
const GLYPH_PLACEHOLDER: String = "?"
## Carved look: dark brown capitals, baseline in the middle of the stone (art px above the feet point).
const GLYPH_COLOR: Color = Color(0.42, 0.29, 0.18, 1.0)
const GLYPH_BASELINE_ART: int = -4

## The character shown on the stone ("?" when the level has no password).
var glyph: String = GLYPH_PLACEHOLDER

var _level_id: StringName = &""


func _init() -> void:
	super()
	item_id = &"items/code_stone"
	expires = false
	pickup_sfx = Sfx.CODE_ACCEPT
	set_box(Vector3i(16, 12, 8))


func _apply_params(params: Dictionary) -> void:
	super._apply_params(params)
	index = clampi(index, 0, CODE_LENGTH - 1)
	_level_id = Game.level.level_id if Game.level != null else Game.level_id
	var code: String = Levels.get_password(_level_id, Game.difficulty) if _level_id != &"" else ""
	glyph = code[index] if index < code.length() else GLYPH_PLACEHOLDER
	queue_redraw()


func _apply(_hero: PlayerBase) -> bool:
	if _level_id != &"":
		Save.add_code_stone("%s:%d" % [_level_id, index])
	return true


func _update_look() -> void:
	show_cell(0)


func _bob_tick() -> void:
	super._bob_tick()
	queue_redraw()


func _draw() -> void:
	var sprite: Sprite2D = get_sprite()
	var lift: int = int(sprite.position.y) if sprite != null else 0
	FxFont.draw_centered(self, glyph, 0, GLYPH_BASELINE_ART + lift, GLYPH_COLOR)
