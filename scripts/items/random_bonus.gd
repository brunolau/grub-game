class_name RandomBonus
extends CollectibleBase
## `items/random_bonus`: becomes a random bonus item when it is spawned. `tier` 0..2 [level `bonus_tier`] selects
## the value table (ItemTable). Thrown-out (dropped) random bonuses can also be a skull or a kill-all item, as in
## the original (GAMEPLAY.md 4.4); placed ones are always food or treasure.
##
## Dropped ones roll with Sim.rng (inside the tick that throws them); placed ones roll with a generator seeded by
## their position, so a level looks the same every time it is loaded.

const TEX_FOOD: Texture2D = preload("res://assets/sprites/items/food.png")
const TEX_TREASURE: Texture2D = preload("res://assets/sprites/items/treasure.png")
const TEX_PICKUPS: Texture2D = preload("res://assets/sprites/items/pickups.png")
## Sheet layout per ItemTable.Roll: columns, rows, pivot (art px).
const SHEET_COLUMNS: Array[int] = [8, 8, 8, 8]
const SHEET_ROWS: Array[int] = [6, 2, 2, 2]
const SHEET_PIVOTS: Array[Vector2] = [Vector2(16, 32), Vector2(16, 32), Vector2(24, 40), Vector2(24, 40)]
const ROLL_IDS: Array[StringName] = [&"items/food", &"items/treasure", &"items/skull", &"items/kill_all"]
const POSITION_SEED_X: int = 73856093
const POSITION_SEED_Y: int = 19349663

## What it turned into (ItemTable.Roll).
var roll: int = ItemTable.Roll.FOOD


func _init() -> void:
	super()
	item_id = &"items/food"


func _apply_params(params: Dictionary) -> void:
	var is_dropped: bool = param_bool("dropped", false)
	var tier: int = int(params.get("tier", ItemTable.level_tier()))
	var rng: SimRng = Sim.rng
	if not is_dropped:
		rng = SimRng.new((sim_pos.x * POSITION_SEED_X) ^ (sim_pos.y * POSITION_SEED_Y))
	var result: Vector2i = ItemTable.roll_bonus(rng, tier, is_dropped)
	roll = result.x
	index = result.y
	item_id = ROLL_IDS[roll]
	match roll:
		ItemTable.Roll.FOOD:
			points = ItemTable.food_points(index)
			counts_for_tally = true
		ItemTable.Roll.TREASURE:
			points = ItemTable.treasure_points(index)
			counts_for_tally = true
			pickup_sfx = Sfx.PICKUP_BIG
		ItemTable.Roll.SKULL:
			pickup_sfx = Sfx.PLAYER_HURT_HEAVY
		ItemTable.Roll.KILL_ALL:
			pickup_sfx = Sfx.EXPLOSION
	super._apply_params(params)
	index = result.y


func _apply(hero: PlayerBase) -> bool:
	match roll:
		ItemTable.Roll.SKULL:
			return ItemEffects.skull(hero, self)
		ItemTable.Roll.KILL_ALL:
			ItemEffects.kill_all(hero)
	return true


func _update_look() -> void:
	var sprite: Sprite2D = get_sprite()
	if sprite == null:
		return
	match roll:
		ItemTable.Roll.FOOD:
			sprite.texture = TEX_FOOD
		ItemTable.Roll.TREASURE:
			sprite.texture = TEX_TREASURE
		_:
			sprite.texture = TEX_PICKUPS
	sprite.hframes = SHEET_COLUMNS[roll]
	sprite.vframes = SHEET_ROWS[roll]
	sprite.offset = -SHEET_PIVOTS[roll]
	show_cell(index)
