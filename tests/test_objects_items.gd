extends ObjectsTestCase
## Every item effect of ARCHITECTURE.md 6.2 / GAMEPLAY.md 4 and 8.3, the score values of the manifest tables and
## the random bonus.

const FEET: Vector2i = Vector2i(120, 160)


func before_each() -> void:
	super.before_each()
	make_ground_level()
	add_hero(FEET)


## Spawn an item on the hero and run one tick: returns the item (collected or not).
func touch(id: StringName, params: Dictionary = {}) -> CollectibleBase:
	var item: CollectibleBase = spawn(id, FEET, params) as CollectibleBase
	Sim.step(1)
	return item


func test_score_tables_follow_the_manifest() -> void:
	assert_eq(ItemTable.FOOD_POINTS.size(), 48)
	assert_eq(ItemTable.TREASURE_POINTS.size(), 16)
	assert_eq(ItemTable.GIANT_POINTS.size(), 7)
	assert_eq(ItemTable.food_points(0), 100, "apple")
	assert_eq(ItemTable.food_points(7), 200, "grapes")
	assert_eq(ItemTable.food_points(13), 300, "cheese")
	assert_eq(ItemTable.food_points(19), 500, "ice cream")
	assert_eq(ItemTable.food_points(29), 750, "pancakes")
	assert_eq(ItemTable.food_points(39), 1000, "pizza")
	assert_eq(ItemTable.food_points(41), 300, "dino egg")
	assert_eq(ItemTable.treasure_points(7), 2000)
	assert_eq(ItemTable.treasure_points(8), 5000)
	assert_eq(ItemTable.treasure_points(15), 8000)
	assert_eq(ItemTable.GIANT_POINTS, [60000, 20000, 30000, 10000, 10000, 20000, 30000] as Array[int])
	for value: int in ItemTable.FOOD_POINTS + ItemTable.TREASURE_POINTS + ItemTable.GIANT_POINTS:
		assert_true(Tuning.SCORE_LADDER.has(value), "%d is a step of the score ladder" % value)


func test_food_pays_its_table_value_and_counts_for_completion_and_tally() -> void:
	Game.add_completion_totals(0, 2)
	var popups: Array[int] = []
	var on_popup: Callable = func(_kind: StringName, value: int, _pos: Vector2i) -> void: popups.append(value)
	Events.popup_requested.connect(on_popup)
	var food: CollectibleBase = spawn(&"items/food", FEET, {"index": 27}) as CollectibleBase
	food.counts_for_completion = true
	assert_eq(food.points, 700, "burger")
	Sim.step(1)
	Events.popup_requested.disconnect(on_popup)
	assert_true(food.collected)
	assert_eq(Game.score, 700)
	assert_eq(Game.completion_percent(), 50)
	assert_eq(Game.tally_count(), 1)
	assert_eq(popups, [700] as Array[int], "a score pop-up at the pick-up")
	assert_eq(count_alive(Defs.Kind.FX), 2, "the pop-up and a sparkle")


func test_points_override_and_treasure_values() -> void:
	assert_eq((spawn(&"items/food", Vector2i(300, 160), {"index": 1, "points": 2000}) as CollectibleBase).points, 2000)
	touch(&"items/treasure", {"index": 13})
	assert_eq(Game.score, 8000)


func test_placed_items_bob_but_keep_their_contact_point() -> void:
	var food: CollectibleBase = spawn(&"items/food", Vector2i(200, 160), {"index": 2}) as CollectibleBase
	var sprite: Sprite2D = food.get_node("Sprite") as Sprite2D
	var heights: Dictionary = {}
	for i: int in ObjTuning.BOB_ART.size():
		Sim.step(1)
		heights[int(sprite.position.y)] = true
		assert_eq(food.sim_pos, Vector2i(200, 160))
	assert_eq(heights.size(), Tuning.ITEM_BOB_PX * Tuning.ART_SCALE + 1, "bobs over 3 logical px")


func test_giant_bonus_bounces_off_the_head_once_when_falling_fast() -> void:
	var giant: CollectibleBase = spawn(&"items/giant_bonus", FEET + Vector2i(0, -30), {
		"dropped": true, "index": 0, "yvel": 160,
	}) as CollectibleBase
	giant.age = Tuning.DROPPED_ITEM_NO_PICKUP + 1
	Sim.step(1)
	assert_false(giant.collected, "a fast falling giant bonus bounces off the hero first")
	assert_true(giant.yvel < 0)
	assert_eq(absi(giant.xvel), ObjTuning.GIANT_BOUNCE_XVEL)
	# Let it come straight down again: the second touch collects it although it falls just as fast.
	giant.xvel = 0
	for i: int in 60:
		Sim.step(1)
		if giant.collected:
			break
	assert_true(giant.collected, "then it is collected")
	assert_eq(Game.score, 60000)


func test_letters_complete_the_word_and_drop_the_jackpot() -> void:
	for i: int in Tuning.LETTER_COUNT - 1:
		touch(&"items/letter", {"index": i})
	assert_eq(Game.letters, 15)
	assert_eq(count_items(&"items/jackpot"), 0)
	touch(&"items/letter", {"index": 4})
	assert_eq(Game.letters, 0, "the word is cleared")
	var chests: Array[CollectibleBase] = items_of(&"items/jackpot")
	assert_eq(chests.size(), 1)
	assert_eq(chests[0].sim_pos, FEET - Vector2i(0, Tuning.GIANT_BONUS_DROP_PX), "dropped from 112 px above")
	assert_eq(chests[0].points, Tuning.LETTERS_JACKPOT)
	assert_true(chests[0].dropped)
	assert_eq(chests[0].life, 0, "the chest never blinks away")
	assert_true(chests[0].collect(hero))
	assert_eq(Game.score, Tuning.LETTERS_JACKPOT)


func test_feast_kit_starts_the_feast() -> void:
	touch(&"items/feast_piece", {"index": 0})
	touch(&"items/feast_piece", {"index": 2})
	assert_eq(hero.feast, 0)
	assert_eq(Game.feast_kit, 5)
	touch(&"items/feast_piece", {"index": 1})
	assert_eq(hero.feast, Tuning.FEAST_TICKS)
	assert_eq(Game.feast_kit, 0)


func test_fire_starter_unlocks_the_exit() -> void:
	assert_false(Game.exit_unlocked)
	touch(&"items/fire_starter")
	assert_true(Game.exit_unlocked)


func test_heart_stays_at_full_energy() -> void:
	var heart: CollectibleBase = touch(&"items/heart")
	assert_false(heart.collected, "full energy: the heart stays")
	Game.lose_heart()
	Sim.step(1)
	assert_true(heart.collected)
	assert_eq(Game.hearts, Tuning.ENERGY_START)


func test_one_up_and_bones() -> void:
	touch(&"items/one_up")
	assert_eq(Game.lives, Tuning.LIVES_START + 1)
	Game.lose_heart()
	for i: int in Tuning.BONES_PER_HEART - 1:
		touch(&"items/bone")
	assert_eq(Game.hearts, Tuning.ENERGY_START - 1)
	assert_eq(Game.bones, Tuning.BONES_PER_HEART - 1)
	touch(&"items/bone")
	assert_eq(Game.hearts, Tuning.ENERGY_START, "the sixth bone restores a heart")
	assert_eq(Game.bones, 0)


func test_skull_scatters_all_energy_as_bones() -> void:
	Game.add_bones(2)
	var skull: CollectibleBase = touch(&"items/skull")
	assert_true(skull.collected)
	assert_eq(Game.hearts, 0, "all hearts thrown out")
	assert_false(hero.dead, "but the hero is not dead yet")
	assert_eq(hero.hit_timer, Tuning.HIT_TIMER, "hurt pose")
	assert_true(level.shake >= ObjTuning.SHAKE_SKULL, "screen shake")
	assert_eq(count_items(&"items/bone"), Tuning.ENERGY_START * Tuning.BONES_PER_HEART + 2)
	for bone: CollectibleBase in items_of(&"items/bone"):
		assert_true(bone.dropped)


func test_kill_all_kills_on_screen_enemies_and_reappears() -> void:
	var near: EnemyBase = EnemyBase.new()
	place(level, near, Vector2i(200, 160), {"score": 3})
	var far: EnemyBase = EnemyBase.new()
	place(level, far, Vector2i(600, 160), {"score": 3})
	Sim.step(2)
	assert_true(near.awake)
	var item: CollectibleBase = touch(&"items/kill_all")
	assert_true(near.dead)
	assert_false(far.dead, "off screen")
	assert_eq(Game.score, 500)
	assert_true(level.shake >= ObjTuning.SHAKE_KILL_ALL, "strong shake")
	assert_false(item.visible)
	level.reset_entities()
	assert_false(item.collected, "reappears when the hero respawns")
	assert_true(item.visible)


func test_grenade_turns_enemies_into_bonus_items() -> void:
	var enemy: EnemyBase = EnemyBase.new()
	place(level, enemy, Vector2i(200, 160))
	Sim.step(2)
	var item: CollectibleBase = touch(&"items/grenade")
	assert_true(item.collected)
	assert_true(enemy.dead)
	assert_eq(Game.score, 0, "no score for the enemy")
	var bonuses: int = 0
	for entity: SimEntity in level.get_kind(Defs.Kind.COLLECTIBLE):
		if entity is RandomBonus:
			bonuses += 1
	assert_eq(bonuses, Tuning.GRENADE_ITEMS_PER_ENEMY)
	assert_true(item.reappears_on_respawn)


func test_weapon_pick_up_and_respawn() -> void:
	var axe: CollectibleBase = touch(&"items/weapon", {"kind": "axe"})
	assert_eq(Game.weapon, Defs.Weapon.AXE)
	assert_eq((axe.get_node("Sprite") as Sprite2D).texture.resource_path, "res://assets/sprites/items/weapon_axe.png")
	touch(&"items/weapon", {"kind": "boomerang"})
	assert_eq(Game.weapon, Defs.Weapon.BOOMERANG)
	level.reset_entities()
	assert_false(axe.collected, "weapon pick-ups reappear after a death")


func test_glider_pick_up() -> void:
	var glider: CollectibleBase = touch(&"items/glider")
	assert_true(Game.has_glider)
	assert_true(glider.collected)
	var second: CollectibleBase = touch(&"items/glider")
	assert_false(second.collected, "only one glider at a time")


func test_water_bucket_scores_like_food() -> void:
	var events: Array[StringName] = []
	var on_item: Callable = func(id: StringName, _i: int, _p: int, _pos: Vector2i) -> void: events.append(id)
	Events.item_collected.connect(on_item)
	touch(&"items/water_bucket")
	Events.item_collected.disconnect(on_item)
	assert_eq(Game.score, ObjTuning.WATER_BUCKET_POINTS)
	assert_eq(events, [&"items/water_bucket"] as Array[StringName], "the fly swarm listens to this event")


func test_warp_and_trophy_complete_the_level() -> void:
	touch(&"items/warp")
	assert_eq(level.completed_kinds, [&"warp"] as Array[StringName])
	assert_false(hero.control_enabled)
	level.completed = false
	touch(&"items/trophy")
	assert_eq(level.completed_kinds, [&"warp", &"trophy"] as Array[StringName])


func test_code_stone_shows_its_password_character() -> void:
	level.level_id = &"test_example"
	var stone: CodeStone = spawn(&"items/code_stone", FEET, {"index": 1}) as CodeStone
	assert_eq(stone.glyph, "1", "second character of C1UB")
	var last: CodeStone = spawn(&"items/code_stone", Vector2i(300, 160), {"index": 3}) as CodeStone
	assert_eq(last.glyph, "B")
	level.level_id = &"test_objects"
	var none: CodeStone = spawn(&"items/code_stone", Vector2i(400, 160), {"index": 0}) as CodeStone
	assert_eq(none.glyph, CodeStone.GLYPH_PLACEHOLDER, "a level without a password")
	Sim.step(1)
	assert_true(stone.collected)
	assert_true(Save.has_code_stone("test_example:1"))


func test_random_bonus_rolls_deterministically() -> void:
	var a: RandomBonus = spawn(&"items/random_bonus", Vector2i(300, 160)) as RandomBonus
	var b: RandomBonus = spawn(&"items/random_bonus", Vector2i(300, 160)) as RandomBonus
	assert_eq(a.index, b.index, "a placed random bonus depends on its position only")
	assert_eq(a.roll, b.roll)
	assert_true(a.roll == ItemTable.Roll.FOOD or a.roll == ItemTable.Roll.TREASURE, "placed: never a trap")
	Sim.rng.reseed(77)
	var first: RandomBonus = spawn(&"items/random_bonus", Vector2i(300, 160), {"dropped": true}) as RandomBonus
	Sim.rng.reseed(77)
	var again: RandomBonus = spawn(&"items/random_bonus", Vector2i(300, 160), {"dropped": true}) as RandomBonus
	assert_eq(first.index, again.index, "dropped ones roll with Sim.rng")
	assert_eq(first.item_id, again.item_id)
	if first.roll == ItemTable.Roll.FOOD:
		assert_eq(first.points, ItemTable.food_points(first.index))


func test_random_bonus_tables() -> void:
	var rng: SimRng = SimRng.new(5)
	var traps: int = 0
	var treasures: int = 0
	for i: int in 9500:
		var roll: Vector2i = ItemTable.roll_bonus(rng, 2, true)
		if roll.x == ItemTable.Roll.SKULL or roll.x == ItemTable.Roll.KILL_ALL:
			traps += 1
		elif roll.x == ItemTable.Roll.TREASURE:
			treasures += 1
			assert_true(roll.y >= 0 and roll.y <= 15)
		else:
			assert_true(roll.y >= ItemTable.TIER_FOOD_FROM[2] and roll.y <= ItemTable.TIER_FOOD_TO[2])
	assert_true(traps > 200 and traps < 400, "about 3 in 95 thrown bonuses are traps (%d)" % traps)
	assert_true(treasures > 1500, "tier 2 is rich in treasures (%d)" % treasures)
	for i: int in 200:
		var calm: Vector2i = ItemTable.roll_bonus(rng, 0, false)
		assert_eq(calm.x, ItemTable.Roll.FOOD, "tier 0, no traps: food only")
		assert_true(ItemTable.food_points(calm.y) <= 500)
