extends ObjectsTestCase
## What the objects module owes Book II's worlds 6-9 (DESIGN.md A.2-A.5, D.10; GAMEPLAY.md 13.3 / 13.5 / 13.6):
## the mushroom and floe see-saws (6-2 co-op, Floe Rink), the treasure chest among the Mimics (8-1), the drop clouds
## and driftwood floes (7-2, 9-1, 9-2), the mushroom-cap springs and drums (6-2), the Great Roast trophy (9-3) and the
## new biomes' debris. Skins are pictures only: every rule and box stays the 1.0 / phase-1 one.

const SPRING_PICTURE: Texture2D = preload("res://assets/sprites/objects/spring.png")
const DRUM_PICTURE: Texture2D = preload("res://assets/sprites/objects/drum.png")


func before_each() -> void:
	super.before_each()
	make_ground_level(60, 16, 10)
	add_hero(Vector2i(40, 160))


func picture(node: Node) -> Texture2D:
	var sprite: Sprite2D = node.get_node_or_null(^"Sprite") as Sprite2D
	return sprite.texture if sprite != null else null


## Warnings logged while `body` runs.
func warnings_of(body: Callable) -> int:
	var counter: LogCounter = LogCounter.new()
	OS.add_logger(counter)
	body.call()
	OS.remove_logger(counter)
	return counter.warnings


# =================================================================================================================
# See-saw skins (6-2 Spore Hollow co-op, the Floe Rink arena)
# =================================================================================================================

func test_seesaw_skins_change_the_plank_picture_only() -> void:
	var wood: Seesaw = spawn(&"objects/seesaw", Vector2i(200, 160), {"len": 5}) as Seesaw
	var cap: Seesaw = spawn(&"objects/seesaw", Vector2i(400, 160), {"len": 5, "skin": "mushroom"}) as Seesaw
	var floe: Seesaw = spawn(&"objects/seesaw", Vector2i(600, 160), {"len": 5, "skin": "floe"}) as Seesaw
	var planks: Array[Texture2D] = []
	for seesaw: Seesaw in [wood, cap, floe]:
		planks.append((seesaw.get_node("Plank") as Sprite2D).texture)
		assert_eq([seesaw.box_w, seesaw.box_h], [wood.box_w, wood.box_h], "the same plank box")
		assert_eq(seesaw.left_end.box_w, wood.left_end.box_w, "the same ends")
		assert_eq(seesaw.right_end.top() - seesaw.sim_pos.y, wood.right_end.top() - wood.sim_pos.y)
	assert_eq(planks[0].resource_path, "res://assets/sprites/objects/seesaw_plank.png")
	assert_eq(planks[1].resource_path, "res://assets/sprites/objects/seesaw_plank_mushroom.png")
	assert_eq(planks[2].resource_path, "res://assets/sprites/objects/seesaw_plank_floe.png")
	assert_eq([wood.skin, cap.skin, floe.skin], [0, 1, 2])
	var odd: Array = []
	assert_eq(warnings_of(func() -> void:
		odd.append(spawn(&"objects/seesaw", Vector2i(800, 160), {"skin": "glass"}))), 1, "an unknown skin is reported")
	assert_eq((odd[0] as Seesaw).skin, 0, "and drawn in wood")


# =================================================================================================================
# The treasure chest (8-1 Overgrown Steps: real chests among the Mimics)
# =================================================================================================================

func test_a_chest_opens_its_lid_throws_its_contents_and_stays() -> void:
	var chest: BonusContainer = spawn(&"objects/container", Vector2i(200, 160),
			{"skin": "chest", "contents": "food:1,treasure:2", "hits": 2}) as BonusContainer
	var sprite: Sprite2D = chest.get_node("Sprite") as Sprite2D
	assert_eq(chest.skin, BonusContainer.SKIN_CHEST)
	assert_eq(sprite.texture.resource_path, BonusContainer.CHEST_TEXTURE, "the shipped treasure chest")
	assert_eq(sprite.hframes, 4)
	assert_eq(sprite.frame, BonusContainer.CHEST_FRAME_CLOSED, "closed: the look a Mimic copies")
	assert_eq(sprite.offset, -BonusContainer.CHEST_PIVOT)
	assert_eq([chest.box_w, chest.box_h], [24, 18])
	var items: int = count_items()
	assert_true(chest.take_hit(25, hero))
	assert_false(chest.opened, "two hits")
	Sim.step(Tuning.HIDDEN_SPOT_HIT_COOLDOWN)
	assert_true(chest.take_hit(25, hero))
	assert_true(chest.opened)
	assert_eq(count_items(), items + 2, "its contents fan out")
	assert_true(sprite.visible, "it does not burst")
	var seen: Dictionary = {}
	for i: int in 20:
		Sim.step(1)
		seen[sprite.frame] = true
	assert_true(seen.has(2) and seen.has(3), "the lid flips open: %s" % [seen.keys()])
	assert_eq(sprite.frame, BonusContainer.CHEST_OPEN_FRAMES[-1], "and stays open")
	assert_true(sprite.visible)
	chest.refill()
	assert_eq(sprite.frame, BonusContainer.CHEST_FRAME_CLOSED, "a versus refill closes it")


func test_the_old_containers_are_unchanged() -> void:
	var crate: BonusContainer = spawn(&"objects/container", Vector2i(200, 160), {"contents": "food:1"}) as BonusContainer
	var sprite: Sprite2D = crate.get_node("Sprite") as Sprite2D
	assert_eq(crate.skin, BonusContainer.DEFAULT_SKIN)
	assert_eq([crate.box_w, crate.box_h, crate.box_xo], [16, 11, 8])
	assert_eq(sprite.hframes, 1)
	assert_true(crate.take_hit(25, hero))
	assert_true(crate.opened)
	assert_false(sprite.visible, "a crate bursts")
	Sim.step(10)
	assert_false(sprite.visible)


# =================================================================================================================
# Drop clouds and driftwood floes (7-2, 9-1, 9-2), the biome defaults
# =================================================================================================================

func test_cloud_and_driftwood_platforms_are_skins_with_the_wood_box() -> void:
	var cloud: DropPlatform = spawn(&"objects/drop_platform", Vector2i(200, 96), {"skin": "cloud"}) as DropPlatform
	var drift: DropPlatform = spawn(&"objects/drop_platform", Vector2i(300, 96), {"skin": "driftwood"}) as DropPlatform
	var wood: DropPlatform = spawn(&"objects/drop_platform", Vector2i(400, 96), {"skin": "wood"}) as DropPlatform
	for platform: DropPlatform in [cloud, drift]:
		assert_eq([platform.box_w, platform.box_h, platform.box_xo], [wood.box_w, wood.box_h, wood.box_xo],
				"the wood platform's box")
		assert_eq(platform.home, Vector2i(platform.sim_pos.x, wood.home.y))
	assert_eq(picture(cloud), PlatformSkin.texture(PlatformSkin.SKIN_CLOUD))
	assert_eq(picture(drift), PlatformSkin.texture(PlatformSkin.SKIN_DRIFTWOOD))
	for skin: int in [PlatformSkin.SKIN_CLOUD, PlatformSkin.SKIN_DRIFTWOOD]:
		var path: String = PlatformSkin.PATHS[skin - PlatformSkin.TEXTURES.size()]
		var expected: Texture2D = PlatformSkin.TEXTURES[PlatformSkin.STAND_INS[skin - PlatformSkin.TEXTURES.size()]]
		if ResourceLoader.exists(path):
			expected = load(path) as Texture2D
		assert_eq(PlatformSkin.texture(skin), expected, "%s: its file, or its stand-in until art-A delivers it" % path)
	var mover: MovingPlatform = spawn(&"objects/platform", Vector2i(500, 96), {"skin": "cloud"}) as MovingPlatform
	assert_eq(picture(mover), PlatformSkin.texture(PlatformSkin.SKIN_CLOUD), "moving platforms take them too")


func test_the_book_two_biomes_pick_their_platform_skin() -> void:
	var expected: Dictionary = {"sky": "cloud", "coast": "driftwood", "ruins": "stone", "canyon": "wood",
			"swamp": "wood", "jungle": "wood", "ice": "ice", "volcano": "stone"}
	for biome: String in expected:
		level.meta["biome"] = biome
		assert_eq(PlatformSkin.resolve(""), PlatformSkin.NAMES.find(str(expected[biome])), biome)
	level.meta["biome"] = "jungle"


# =================================================================================================================
# Mushroom-cap springs and drums (6-2 Spore Hollow)
# =================================================================================================================

func test_cap_springs_launch_like_flowers() -> void:
	var flower: SpringPad = spawn(&"objects/spring", Vector2i(200, 160)) as SpringPad
	var cap: SpringPad = spawn(&"objects/spring", Vector2i(400, 160), {"skin": "cap"}) as SpringPad
	assert_eq([flower.skin, cap.skin], [0, 1])
	assert_eq(picture(flower), SPRING_PICTURE)
	assert_eq(picture(cap), ObjTuning.picture(SpringPad.CAP_TEXTURE, SPRING_PICTURE), "the cap (or the flower)")
	assert_eq(cap.power, flower.power)
	assert_eq([cap.box_w, cap.box_h], [flower.box_w, flower.box_h])
	hero.teleport(Vector2i(400, 155))
	hero.yvel = 32
	Sim.step(1)
	assert_eq(cap.launches, 1)
	assert_eq(hero.yvel, ObjTuning.SPRING_DEFAULT_POWER, "the same -224 throw")


func test_cap_drums_keep_the_drum_rules() -> void:
	Game.start_run(Defs.Difficulty.BEGINNER, Defs.GameMode.COOP, 2)
	var plain: Drum = spawn(&"objects/drum", Vector2i(200, 160), {"bond": "caps"}) as Drum
	var cap: Drum = spawn(&"objects/drum", Vector2i(500, 160), {"bond": "caps", "skin": "cap"}) as Drum
	assert_eq([plain.skin, cap.skin], [0, 1])
	assert_eq(picture(plain), DRUM_PICTURE)
	assert_eq(picture(cap), ObjTuning.picture(Drum.CAP_TEXTURE, DRUM_PICTURE))
	assert_eq([cap.box_w, cap.box_h], [plain.box_w, plain.box_h])
	assert_eq(cap.bond_drums(level).size(), 2, "one bond, whatever the skin")


# =================================================================================================================
# The Great Roast (9-3 Chieftains' Pyre) and the new biomes' debris
# =================================================================================================================

func test_the_book_two_trophy_is_the_great_roast() -> void:
	var cup: Trophy = spawn(&"items/trophy", Vector2i(200, 160)) as Trophy
	assert_eq(cup.skin, 0, "Book I: the cup")
	assert_eq((cup.get_node("Sprite") as Sprite2D).frame, ItemTable.CELL_TROPHY)
	level.meta["book"] = LevelText.BOOK_2
	var roast: Trophy = spawn(&"items/trophy", Vector2i(300, 160)) as Trophy
	var sprite: Sprite2D = roast.get_node("Sprite") as Sprite2D
	assert_eq(roast.skin, 1, "Book II: the Great Roast")
	assert_eq(sprite.texture, Trophy.ROAST_TEXTURE)
	assert_eq(sprite.frame, Trophy.ROAST_CELL, "the giant roast's cell")
	assert_eq([roast.box_w, roast.box_h], [cup.box_w, cup.box_h], "the same box")
	var forced: Trophy = spawn(&"items/trophy", Vector2i(400, 160), {"skin": "cup"}) as Trophy
	assert_eq(forced.skin, 0, "skin=cup overrides the book")
	hero.teleport(roast.sim_pos)
	Sim.step(1)
	assert_true(roast.collected)
	assert_eq(level.completed_kinds, [&"trophy"] as Array[StringName], "it ends the stage like the cup")
	level.meta.erase("book")


func test_the_book_two_biomes_have_their_debris() -> void:
	var expected: Dictionary = {"canyon": "rock", "swamp": "leaf", "coast": "rock", "ruins": "rock", "sky": "rock",
			"jungle": "leaf", "ice": "ice"}
	for biome: String in expected:
		level.meta["biome"] = biome
		assert_eq(SceneryHittable.level_debris_kind(), expected[biome], biome)
	level.meta["biome"] = "jungle"
