extends ObjectsTestCase
## Hidden spots (small / big), breakable blocks, containers and the flood fill of GAMEPLAY.md 4.4, and the
## dropped-item physics of GAMEPLAY.md 4.2 / 4.5.

const HERO_FEET: Vector2i = Vector2i(104, 160)


func before_each() -> void:
	super.before_each()
	make_recording_level(PackedStringArray([
		"........................................",
		"........................................",
		"........................................",
		"........................................",
		"........................................",
		"........................................",
		"........................................",
		"....................;...................",
		"....................;...................",
		"....................;...................",
		"########################################",
		"########################################",
		"########################################",
	]))
	add_hero(HERO_FEET)


## Feet point of an entity placed in cell (col, row) of the level file.
func cell_feet(col: int, row: int) -> Vector2i:
	return LevelText.cell_to_feet(col, row)


## A hidden spot placed in cell (col, row).
func add_spot(col: int, row: int, params: Dictionary) -> HiddenSpot:
	return spawn(&"objects/hidden_spot", cell_feet(col, row), params) as HiddenSpot


## A container standing at `pos`.
func add_container(pos: Vector2i, params: Dictionary) -> BonusContainer:
	return spawn(&"objects/container", pos, params) as BonusContainer


## Hit `target` like the hero's weapon pass does, then let the hit cooldown run out.
func hit(target: HittableBase) -> bool:
	var consumed: bool = target.take_hit(Tuning.WEAPON_POWER[Defs.Weapon.CLUB], hero)
	Sim.step(Tuning.HIDDEN_SPOT_HIT_COOLDOWN)
	return consumed


func test_small_spot_throws_one_item_per_hit_cycling_its_contents() -> void:
	Game.add_completion_totals(1, 0)
	var spot: HiddenSpot = add_spot(8, 10, {
		"kind": "small", "count": 3, "contents": "food:3,food:17",
	})
	assert_eq(spot.cell, Vector2i(8, 10))
	assert_true(spot.take_hit(25, hero))
	assert_eq(count_items(&"items/food"), 1)
	var first: CollectibleBase = items_of(&"items/food")[0]
	assert_eq(first.index, 3)
	assert_true(first.dropped)
	assert_eq(first.sim_pos, Vector2i(136, 160), "out of the top of the cell")
	assert_eq(first.xvel, ObjTuning.SPOT_THROW_XVEL, "away from the hero, who faces right")
	assert_eq(first.yvel, ObjTuning.SPOT_THROW_YVEL)
	assert_true(spot.take_hit(25, hero), "a hit during the cooldown is consumed ...")
	assert_eq(count_items(&"items/food"), 1, "... but throws nothing")
	Sim.step(Tuning.HIDDEN_SPOT_HIT_COOLDOWN)
	hit(spot)
	var indices: Array[int] = []
	for item: CollectibleBase in items_of(&"items/food"):
		indices.append(item.index)
	assert_true(indices.has(17), "the second token")
	assert_false(spot.opened)
	hit(spot)
	assert_true(spot.opened, "used up after `count` items")
	assert_eq(spot.thrown, 3)
	assert_eq(Game.spots_opened, 1)
	assert_eq(Game.completion_percent(), 100)
	assert_false(spot.take_hit(25, hero), "an opened spot lets the weapon through")


func test_a_thrown_weapon_throws_items_along_its_flight() -> void:
	var spot: HiddenSpot = add_spot(8, 10, {"count": 2, "contents": "food:4"})
	var axe: SimEntity = SimEntity.new()
	axe.xvel = -Tuning.THROW_XVEL
	add_node(axe)
	assert_true(spot.take_hit(Tuning.WEAPON_POWER[Defs.Weapon.AXE], axe))
	assert_eq(spot.strike_dir, -1)
	assert_eq(items_of(&"items/food")[0].xvel, -ObjTuning.SPOT_THROW_XVEL)


func test_small_spot_default_contents_are_random_bonuses() -> void:
	var spot: HiddenSpot = add_spot(8, 10, {"count": 1})
	hit(spot)
	var bonuses: int = 0
	for entity: SimEntity in level.get_kind(Defs.Kind.COLLECTIBLE):
		if entity is RandomBonus:
			bonuses += 1
	assert_eq(bonuses, 1)
	assert_true(spot.opened)


func test_big_spot_only_puffs_then_drops_a_giant_bonus_from_the_sky() -> void:
	var spot: HiddenSpot = add_spot(13, 10, {"kind": "big", "hits": 3})
	var hits: Array[bool] = []
	var on_hit: Callable = func(_target: HittableBase, used_up: bool) -> void: hits.append(used_up)
	Events.hittable_hit.connect(on_hit)
	hit(spot)
	hit(spot)
	assert_eq(count_items(), 0, "the first hits only puff")
	hit(spot)
	Events.hittable_hit.disconnect(on_hit)
	assert_eq(hits, [false, false, true] as Array[bool])
	assert_true(spot.opened)
	var giants: Array[CollectibleBase] = items_of(&"items/giant_bonus")
	assert_eq(giants.size(), 1)
	var sky: Vector2i = Vector2i(13 * Tuning.TILE + Tuning.TILE / 2, 10 * Tuning.TILE - Tuning.GIANT_BONUS_DROP_PX)
	assert_eq(giants[0].spawn_pos, sky, "falls from 112 px above the spot")
	assert_eq(giants[0].xvel, 0)
	assert_true(ItemTable.GIANT_POINTS.has(giants[0].points))


func test_big_spot_with_a_chosen_giant() -> void:
	var spot: HiddenSpot = add_spot(13, 10, {
		"kind": "big", "hits": 1, "contents": "giant:2",
	})
	hit(spot)
	var giants: Array[CollectibleBase] = items_of(&"items/giant_bonus")
	assert_eq(giants.size(), 1)
	assert_eq(giants[0].index, 2)
	assert_eq(giants[0].points, 30000)


func test_flood_fill_opens_every_touching_spot() -> void:
	Game.add_completion_totals(5, 0)
	var a: HiddenSpot = add_spot(8, 10, {"count": 1, "contents": "food:0"})
	var b: HiddenSpot = add_spot(9, 10, {"count": 5})
	var c: HiddenSpot = add_spot(10, 11, {"kind": "big", "hits": 9})
	var d: HiddenSpot = add_spot(11, 12, {"count": 2})
	var far: HiddenSpot = add_spot(14, 10, {"count": 1})
	var opened: Array[StringName] = []
	var on_open: Callable = func(_pos: Vector2i, kind: StringName) -> void: opened.append(kind)
	Events.hidden_spot_opened.connect(on_open)
	hit(a)
	Events.hidden_spot_opened.disconnect(on_open)
	assert_true(a.opened)
	assert_true(b.opened, "touching side by side")
	assert_true(c.opened, "touching corner to corner, through b")
	assert_true(d.opened, "and the chain goes on")
	assert_false(far.opened, "not touching")
	assert_false(a.opened_by_flood)
	assert_true(b.opened_by_flood and c.opened_by_flood and d.opened_by_flood)
	assert_eq(opened.size(), 4)
	assert_eq(Game.spots_opened, 4, "every opened spot counts for the completion percentage")
	assert_eq(count_items(), 1, "only the spot that was hit pays out")
	assert_eq(items_of(&"items/giant_bonus").size(), 0, "a big spot opened by the flood drops nothing")


func test_spot_looks_and_props() -> void:
	var inset: HiddenSpot = add_spot(8, 10, {"count": 1, "look": "inset"})
	assert_eq(level.looks.get(Vector2i(8, 10)), ObjTuning.ATLAS_INSET, "inset panel until opened")
	hit(inset)
	assert_eq(level.looks.get(Vector2i(8, 10)), ObjTuning.ATLAS_AUTO, "ordinary terrain once opened")
	var rock: HiddenSpot = add_spot(4, 9, {
		"count": 2, "prop": "jungle/rock_grass",
	})
	var sprite: Sprite2D = rock.get_node("Sprite") as Sprite2D
	assert_eq(sprite.texture.resource_path, "res://assets/tiles/jungle/props/rock_grass.png")
	assert_eq(sprite.offset, Vector2(-16, -30), "prop anchored bottom-centre (32 x 30 picture)")
	rock.take_hit(25, hero)
	Sim.step(1)
	assert_ne(sprite.position.x, 0.0, "the prop wobbles under the club")
	Sim.step(ObjTuning.HIT_WOBBLE_TICKS)
	assert_eq(sprite.position.x, 0.0)


func test_spots_in_walls_and_ceilings_throw_out_of_their_open_side() -> void:
	# A wall: columns 3-4 solid from row 4 down; a ceiling: row 2-3 solid over columns 10-14.
	for row: int in range(4, 10):
		level.grid.set_char(3, row, TileGrid.CH_SOLID_A)
		level.grid.set_char(4, row, TileGrid.CH_SOLID_A)
	for col: int in range(10, 15):
		level.grid.set_char(col, 2, TileGrid.CH_SOLID_A)
		level.grid.set_char(col, 3, TileGrid.CH_SOLID_A)
	var wall: HiddenSpot = add_spot(4, 7, {"count": 1, "contents": "food:0"})
	hero.facing = -1
	wall.take_hit(25, hero)
	var items: Array[CollectibleBase] = items_of(&"items/food")
	assert_eq(items.size(), 1)
	assert_eq(items[0].sim_pos, Vector2i(5 * 16 + 8, 8 * 16), "out of the open side, toward the hero")
	assert_eq(items[0].xvel, ObjTuning.SPOT_THROW_XVEL)
	assert_eq(items[0].yvel, ObjTuning.SPOT_FACE_YVEL)
	var ceiling: HiddenSpot = add_spot(12, 3, {"count": 1, "contents": "food:1"})
	hero.facing = 1
	ceiling.take_hit(25, hero)
	var dropped: CollectibleBase = null
	for item: CollectibleBase in items_of(&"items/food"):
		if item.index == 1:
			dropped = item
	assert_not_null(dropped)
	assert_eq(dropped.sim_pos, Vector2i(12 * 16 + 8, 5 * 16), "out of the bottom of a ceiling cell")
	assert_eq(dropped.yvel, 0, "it just falls")


func test_breakable_block_cracks_then_opens_the_cell() -> void:
	Game.add_completion_totals(1, 0)
	var block: BreakableBlock = spawn(&"objects/breakable_block", cell_feet(20, 9), {"hits": 3}) as BreakableBlock
	var sprite: Sprite2D = block.get_node("Sprite") as Sprite2D
	assert_eq(sprite.texture.resource_path, "res://assets/sprites/objects/breakable_block.png", "jungle: dirt look")
	assert_eq(sprite.frame, 0)
	hit(block)
	assert_eq(sprite.frame, 1, "first crack")
	hit(block)
	assert_eq(sprite.frame, 3, "deep crack before the last hit")
	assert_eq(level.grid.side_at(20, 9), TileGrid.SIDE_WALL)
	hit(block)
	assert_true(block.opened)
	assert_eq(level.get_cell(20, 9), TileGrid.CH_AIR)
	assert_eq(level.grid.side_at(20, 9), TileGrid.SIDE_OPEN, "the way is open")
	assert_eq(level.grid.floor_at(20, 9), TileGrid.FLOOR_EMPTY)
	assert_eq(Game.spots_opened, 1)
	assert_true(count_alive(Defs.Kind.FX) > 0, "debris")
	Sim.step(ObjTuning.anim_ticks(4, 14) + 1)
	assert_false(sprite.visible, "the break animation ends")


func test_a_column_of_blocks_breaks_together() -> void:
	var blocks: Array[BreakableBlock] = []
	for row: int in [7, 8, 9]:
		blocks.append(spawn(&"objects/breakable_block", cell_feet(20, row), {"hits": 1}) as BreakableBlock)
	hit(blocks[2])
	for row: int in [7, 8, 9]:
		assert_eq(level.get_cell(20, row), TileGrid.CH_AIR, "row %d opened" % row)
	assert_true(blocks[0].opened_by_flood)


func test_block_skins() -> void:
	var ice: BreakableBlock = spawn(&"objects/breakable_block", cell_feet(20, 9), {"skin": "ice"}) as BreakableBlock
	assert_eq(ice.skin, 2)
	level.meta["biome"] = "cave"
	var cave: BreakableBlock = spawn(&"objects/breakable_block", cell_feet(20, 8)) as BreakableBlock
	assert_eq(cave.skin, 1, "auto: by biome")
	assert_eq(cave.hits_left, 2, "two hits by default")


func test_container_bursts_into_its_contents() -> void:
	# The hero stands far away so that nothing thrown out is picked up during the test.
	hero.teleport(Vector2i(600, 160))
	var crate: BonusContainer = add_container(Vector2i(140, 160), {"contents": "heart,food:5"})
	assert_eq(crate.cell, Vector2i(8, 9))
	assert_true(crate.is_hit_by(Vector2i(127, 158)), "a forward club strike of the hero reaches it")
	hit(crate)
	assert_true(crate.opened)
	assert_false((crate.get_node("Sprite") as Sprite2D).visible)
	assert_eq(count_items(&"items/heart"), 1)
	assert_eq(count_items(&"items/food"), 1)
	var barrel: BonusContainer = add_container(Vector2i(200, 160), {"skin": "barrel", "hits": 2})
	hit(barrel)
	assert_false(barrel.opened)
	hit(barrel)
	assert_eq(count_items(), 2 + 3, "random = three random bonus items")


func test_dropped_items_bounce_rest_blink_and_expire() -> void:
	var food: CollectibleBase = spawn(&"items/food", Vector2i(200, 100), {"dropped": true}) as CollectibleBase
	assert_eq(food.life, Tuning.DROPPED_ITEM_LIFE)
	assert_false(food.counts_for_completion)
	var peak_after_bounce: int = 999
	var bounced: bool = false
	for i: int in 80:
		Sim.step(1)
		if food.yvel < 0:
			bounced = true
		if bounced:
			peak_after_bounce = mini(peak_after_bounce, food.sim_pos.y)
	assert_true(bounced, "it bounces on the floor")
	var height: int = 160 - peak_after_bounce
	assert_true(height >= 15 and height <= 35, "the first bounce reaches about half the fall height (%d)" % height)
	assert_true(food.resting, "and comes to rest")
	assert_eq(food.sim_pos.y, 160, "on the floor surface")
	Sim.step(Tuning.DROPPED_ITEM_LIFE - 80 - Tuning.DROPPED_ITEM_BLINK + 1)
	var blinks: int = 0
	for i: int in Tuning.DROPPED_ITEM_BLINK - 2:
		Sim.step(1)
		if not food.visible:
			blinks += 1
	assert_true(blinks > 3, "it blinks before it vanishes")
	Sim.step(2)
	assert_true(food.is_queued_for_deletion(), "gone after 198 ticks")


func test_dropped_items_cannot_be_taken_at_once() -> void:
	var food: CollectibleBase = spawn(&"items/food", HERO_FEET, {"dropped": true, "index": 0}) as CollectibleBase
	Sim.step(Tuning.DROPPED_ITEM_NO_PICKUP)
	assert_false(food.collected, "not during the first 10 ticks")
	Sim.step(2)
	assert_true(food.collected)
	assert_eq(Game.tally_count(), 1, "dropped bonuses are paid again at the tally too")
	assert_eq(Game.items_collected, 0, "but they never count for the completion percentage")


func test_dropped_items_are_limited_and_cleared_on_respawn() -> void:
	for i: int in ObjTuning.MAX_DROPPED_ITEMS + 8:
		spawn(&"items/food", Vector2i(200, 100), {"dropped": true, "fan": i})
	assert_eq(count_items(), ObjTuning.MAX_DROPPED_ITEMS)
	var key: CollectibleBase = spawn(&"items/fire_starter", Vector2i(220, 100), {"dropped": true}) as CollectibleBase
	assert_false(key.collected, "key items never hit the limit")
	assert_eq(key.life, 0, "and never expire")
	level.reset_entities()
	Sim.step(1)
	assert_eq(count_items(&"items/food"), 0, "dropped bonuses vanish when the hero respawns")
	assert_eq(count_items(&"items/fire_starter"), 1)


func test_dropped_item_slots_free_without_rendering_frames() -> void:
	# A replay that steps ticks without frames (no queue_free ever completes) must count like the game.
	var first: Array[CollectibleBase] = []
	for i: int in ObjTuning.MAX_DROPPED_ITEMS:
		first.append(spawn(&"items/food", Vector2i(200, 100), {"dropped": true, "fan": i}) as CollectibleBase)
	assert_eq(count_items(), ObjTuning.MAX_DROPPED_ITEMS, "every slot is taken")
	Sim.step(Tuning.DROPPED_ITEM_LIFE)
	for item: CollectibleBase in first:
		assert_true(item.collected and not item.sim_active, "an expired item has left the simulation")
	assert_eq(count_items(), 0)
	var later: CollectibleBase = spawn(&"items/food", Vector2i(220, 100), {"dropped": true}) as CollectibleBase
	assert_false(later.collected, "the slots of expired items are free again before the next frame")
	# Collected and respawn-cleared items give their slot back too.
	var picked: CollectibleBase = spawn(&"items/food", HERO_FEET, {"dropped": true}) as CollectibleBase
	Sim.step(Tuning.DROPPED_ITEM_NO_PICKUP + 2)
	assert_true(picked.collected)
	assert_false(picked.sim_active)
	level.reset_entities()
	assert_false(later.sim_active, "a respawn clears dropped items at once")
	for i: int in ObjTuning.MAX_DROPPED_ITEMS:
		var item: CollectibleBase = spawn(&"items/food", Vector2i(200, 100), {"dropped": true, "fan": i}) as CollectibleBase
		assert_false(item.collected, "slot %d is free" % i)


func test_dropped_key_item_comes_back_from_a_pit() -> void:
	var key: CollectibleBase = spawn(&"items/fire_starter", Vector2i(300, 30), {"dropped": true}) as CollectibleBase
	level.grid.set_char(18, 10, TileGrid.CH_AIR)
	level.grid.set_char(18, 11, TileGrid.CH_AIR)
	level.grid.set_char(18, 12, TileGrid.CH_AIR)
	var fell: bool = false
	var returned: bool = false
	for i: int in 80:
		Sim.step(1)
		if key.sim_pos.y > level.grid.height_px():
			fell = true
		elif fell and key.sim_pos == Vector2i(300, 30):
			returned = true
	assert_true(fell, "it fell into the pit")
	assert_true(returned, "and started again where it was spawned instead of being lost")
	assert_false(key.collected or key.is_queued_for_deletion())


func test_fan_bursts_spread_to_both_sides() -> void:
	var left: int = 0
	var right: int = 0
	for i: int in Tuning.BONES_PER_HEART:
		var v: Vector2i = ObjTuning.fan_velocity(i, ObjTuning.BURST_XVEL, ObjTuning.BURST_YVEL)
		if v.x < 0:
			left += 1
		elif v.x > 0:
			right += 1
		assert_true(v.y <= ObjTuning.BURST_YVEL)
	assert_eq(left, 3)
	assert_eq(right, 3)
	assert_eq(ObjTuning.fan_velocity(0, 48, -128), Vector2i(48, -128))
	assert_eq(ObjTuning.fan_velocity(1, 48, -128), Vector2i(-48, -128))
	assert_eq(ObjTuning.fan_velocity(2, 48, -128), Vector2i(32, -144))


func test_a_broken_block_regrows_whole_for_the_versus_signature() -> void:
	var block: BreakableBlock = spawn(&"objects/breakable_block", cell_feet(20, 9), {"hits": 2}) as BreakableBlock
	var sprite: Sprite2D = block.get_node("Sprite") as Sprite2D
	block.open()
	Sim.step(12)
	assert_true(block.opened)
	assert_eq(level.get_cell(20, 9), TileGrid.CH_AIR, "broken: the cell is air")
	assert_false(sprite.visible, "the break animation ended")
	block.regrow()
	assert_eq(level.get_cell(20, 9), TileGrid.CH_SOLID_INVISIBLE, "regrown: solid again (wf9 world-B #1)")
	assert_false(block.opened)
	assert_false(block.opened_by_flood)
	assert_eq(block.hits_left, block.hits_total)
	assert_eq(block.hits_left, 2)
	assert_eq(block.cooldown, 0)
	assert_true(sprite.visible)
	assert_eq(sprite.frame, BreakableBlock.FRAME_IDLE)
	assert_eq(sprite.modulate.a, 1.0)
