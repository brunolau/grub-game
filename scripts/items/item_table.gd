class_name ItemTable
extends RefCounted
## Data of the collectibles: score values per sprite cell (ASSET_MANIFEST.md 7, every value is a step of the
## score ladder of GAMEPLAY.md 3.1), the cells of the special pick-up sheet, and the random bonus roll.

## Points of `sprites/items/food.png` by cell (8 x 6).
const FOOD_POINTS: Array[int] = [
	100, 100, 100, 100, 100, 100, 100, 200,
	200, 200, 200, 200, 200, 300, 300, 300,
	300, 300, 300, 500, 500, 500, 500, 500,
	600, 600, 600, 700, 700, 750, 750, 800,
	800, 800, 800, 1000, 1000, 1000, 1000, 1000,
	1000, 300, 200, 800, 800, 600, 600, 200,
]
## Points of `sprites/items/treasure.png` by cell (8 x 2).
const TREASURE_POINTS: Array[int] = [
	2000, 2000, 2000, 2000, 2000, 2000, 2000, 2000,
	5000, 5000, 5000, 5000, 5000, 8000, 8000, 8000,
]
## Points of `sprites/items/giant_bonus.png` by cell (7 x 1).
const GIANT_POINTS: Array[int] = [60000, 20000, 30000, 10000, 10000, 20000, 30000]

# Cells of `sprites/items/pickups.png` (8 x 2).
const CELL_HEART: int = 0
const CELL_ONE_UP: int = 1
const CELL_SKULL: int = 2
const CELL_KILL_ALL: int = 3
const CELL_GRENADE: int = 4
const CELL_FIRE_STARTER: int = 5
const CELL_FEAST_FIRST: int = 6   ## bowl, flint, log = 6, 7, 8
const CELL_TROPHY: int = 9
const CELL_WARP: int = 10
const CELL_WATER_BUCKET: int = 11

## What a random bonus turns into.
enum Roll { FOOD = 0, TREASURE = 1, SKULL = 2, KILL_ALL = 3 }

## Random bonus tiers 0..2 (level key `bonus_tier`): food cells from .. to, treasure chance in sixteenths,
## highest treasure cell.
const TIER_FOOD_FROM: Array[int] = [0, 0, 19]
const TIER_FOOD_TO: Array[int] = [23, 47, 40]
const TIER_TREASURE_PER_16: Array[int] = [0, 2, 4]
const TIER_TREASURE_TO: Array[int] = [0, 7, 15]
const TIER_COUNT: int = 3


## Points of a food cell (0 for a cell that does not exist).
static func food_points(index: int) -> int:
	return FOOD_POINTS[index] if index >= 0 and index < FOOD_POINTS.size() else 0


## Points of a treasure cell.
static func treasure_points(index: int) -> int:
	return TREASURE_POINTS[index] if index >= 0 and index < TREASURE_POINTS.size() else 0


## Points of a giant bonus cell.
static func giant_points(index: int) -> int:
	return GIANT_POINTS[index] if index >= 0 and index < GIANT_POINTS.size() else 0


## Bonus tier of the running level: its `bonus_tier` key, otherwise by world (1 -> 0, 2 -> 1, 3 and 4 -> 2).
static func level_tier() -> int:
	var level: LevelBase = Game.level
	if level == null:
		return 0
	if level.meta.has("bonus_tier"):
		return clampi(int(level.meta["bonus_tier"]), 0, TIER_COUNT - 1)
	return clampi(int(level.meta.get("world", 1)) - 1, 0, TIER_COUNT - 1)


## Roll a random bonus of `tier` with `rng`: Vector2i(Roll kind, sprite cell). With `allow_traps` the roll can
## also be a skull or a kill-all item, as often as in the original (GAMEPLAY.md 4.4).
static func roll_bonus(rng: SimRng, tier: int, allow_traps: bool) -> Vector2i:
	var t: int = clampi(tier, 0, TIER_COUNT - 1)
	if allow_traps:
		var trap: int = rng.next_int(ObjTuning.RANDOM_ROLL)
		if trap < ObjTuning.RANDOM_SKULL_PER_95:
			return Vector2i(Roll.SKULL, CELL_SKULL)
		if trap < ObjTuning.RANDOM_SKULL_PER_95 + ObjTuning.RANDOM_KILL_ALL_PER_95:
			return Vector2i(Roll.KILL_ALL, CELL_KILL_ALL)
	if rng.next_int(16) < TIER_TREASURE_PER_16[t]:
		return Vector2i(Roll.TREASURE, rng.range_int(0, TIER_TREASURE_TO[t]))
	return Vector2i(Roll.FOOD, rng.range_int(TIER_FOOD_FROM[t], TIER_FOOD_TO[t]))
