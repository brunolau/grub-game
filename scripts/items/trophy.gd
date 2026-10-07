class_name Trophy
extends CollectibleBase
## `items/trophy`: dropped by the final boss; touching one starts the ending (GAMEPLAY.md 6.3).
##
## 2.0 `skin=cup|roast` [cup in Book I, roast in a `book = 2` level]: Book II's trophy is the Great Roast the Rival
## Chieftains hand back in 9-3 (DESIGN.md A.1 / A.2, GAMEPLAY.md 13.1; it leads to `ending_b`), drawn as the giant
## roast (cell ROAST_CELL of sprites/items/giant_bonus.png). A picture only: the rule and the box are the cup's.

const SKINS: Array[String] = ["cup", "roast"]
const ROAST_TEXTURE: Texture2D = preload("res://assets/sprites/items/giant_bonus.png")
## The giant roast's cell of giant_bonus.png [M giant_bonus], its sheet columns and pivot.
const ROAST_CELL: int = 0
const ROAST_HFRAMES: int = 7
const ROAST_PIVOT: Vector2 = Vector2(36, 72)

## Index into SKINS.
var skin: int = 0


func _init() -> void:
	super()
	item_id = &"items/trophy"
	expires = false
	pickup_sfx = Sfx.PICKUP_BIG


func _apply_params(params: Dictionary) -> void:
	var book: int = LevelText.meta_book(Game.level.meta) if Game.level != null else LevelText.BOOK_1
	skin = 1 if book == LevelText.BOOK_2 else 0
	if params.has("skin"):
		var wanted: int = SKINS.find(str(params["skin"]))
		if wanted < 0:
			push_warning("items/trophy: unknown skin '%s'" % str(params["skin"]))
		else:
			skin = wanted
	if skin == 1:
		var sprite: Sprite2D = get_node_or_null(^"Sprite") as Sprite2D
		if sprite != null:
			sprite.texture = ROAST_TEXTURE
			sprite.hframes = ROAST_HFRAMES
			sprite.vframes = 1
			sprite.offset = -ROAST_PIVOT
	super._apply_params(params)


func _apply(hero: PlayerBase) -> bool:
	if Game.level == null or Game.level.completed:
		return false
	hero.set_control_enabled(false)
	Game.level.complete(&"trophy")
	return true


func _update_look() -> void:
	show_cell(ROAST_CELL if skin == 1 else ItemTable.CELL_TROPHY)
