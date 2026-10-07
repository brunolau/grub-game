class_name FoodRainZone
extends EmberRainZone
## `zones/food_rain rect=c,r,w,h period=<ticks> [skin=food|fruit]` (GAMEPLAY.md 13.3, DESIGN.md R5; Feast Land E's
## fruit rain, the Long Raft Home's broken hoard): the ember rain of 4-1 dropping collectable food instead of embers -
## it never hurts. Owner: world-A.
##
## While a hero's feet are inside, every `period` ticks one food item (`items/food`, dropped: it falls with the
## dropped-item physics, bounces, can be picked up after Tuning.DROPPED_ITEM_NO_PICKUP ticks and blinks away after
## Tuning.DROPPED_ITEM_LIFE) appears FOOD_DROP_ABOVE_PX over him, up to FOOD_DROP_SPREAD_PX to either side. A party:
## one stream per hero inside, as the ember rain (EmberRainZone). `skin=food` takes the cell from the level's bonus
## tier (ItemTable: the cells a random food of that tier may be), `skin=fruit` from the fruit cells of
## sprites/items/food.png. Where and what is a fixed integer hash of the zone's count of releases and the hero's slot,
## so the rain never draws from Sim.rng (the enemies' rolls stay where they were) and replays tick for tick.

const FOOD_ID: StringName = &"items/food"
const FOOD_SKINS: Array[String] = ["food", "fruit"]
## Cells of sprites/items/food.png that are fruit (apple, banana, cherries, strawberry, tomato, grapes, pear,
## pineapple, watermelon, lime).
const FRUIT_CELLS: Array[int] = [0, 1, 2, 3, 4, 7, 8, 9, 10, 11]
## Where a piece appears: this far over the hero's feet (above the authentic view's top when he stands in its
## comfort rows), and up to this far to either side.
const FOOD_DROP_ABOVE_PX: int = 150
const FOOD_DROP_SPREAD_PX: int = 64


func _skins() -> Array[String]:
	return FOOD_SKINS


func _release(level: LevelBase, hero: PlayerBase) -> bool:
	if not Spawner.exists(FOOD_ID):
		return false
	var h: int = LevelTiles.cell_hash(released * 7 + hero.slot, hero.slot * 13 + 5)
	var dx: int = h % (FOOD_DROP_SPREAD_PX * 2 + 1) - FOOD_DROP_SPREAD_PX
	var at: Vector2i = Vector2i(clampi(hero.sim_pos.x + dx, Tuning.X_MIN, level.grid.x_max_excl() - 1),
			hero.sim_pos.y - FOOD_DROP_ABOVE_PX)
	level.spawn(FOOD_ID, at, {"dropped": true, "xvel": 0, "yvel": 0, "index": food_cell(skin, h / 7)})
	return true


## The food cell of a release: `pick` (any non-negative number) chooses among the cells of `rain_skin`.
static func food_cell(rain_skin: String, pick: int) -> int:
	if rain_skin == "fruit":
		return FRUIT_CELLS[posmod(pick, FRUIT_CELLS.size())]
	var tier: int = ItemTable.level_tier()
	var first: int = ItemTable.TIER_FOOD_FROM[tier]
	var last: int = ItemTable.TIER_FOOD_TO[tier]
	return first + posmod(pick, last - first + 1)
