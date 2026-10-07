extends "res://tests/test_enemies_case.gd"
## The catalogue of ARCHITECTURE.md 6.2 owned by the enemies module: every id has its scene with the right script,
## every sheet of ASSET_MANIFEST.md 4 / 5 is described correctly, every enemy id works with every enemy skin, and
## the module's test levels only name entities that exist.

const ENEMY_IDS: Dictionary[StringName, String] = {
	&"enemies/dropper": "Dropper", &"enemies/dangler": "Dangler", &"enemies/lurker": "Lurker",
	&"enemies/swinger": "Swinger", &"enemies/stinger": "Stinger", &"enemies/harrier": "Harrier",
	&"enemies/dart": "Dart", &"enemies/hopper": "Hopper", &"enemies/walker": "Walker", &"enemies/flyer": "Flyer",
	&"enemies/digger": "Digger", &"enemies/leaper": "Leaper", &"enemies/charger": "Charger",
	&"enemies/snapper": "Snapper", &"enemies/decoration": "Decoration",
	# 2.0 (DESIGN.md A.5 / D.7; PLAN.md P1.8 pulled forward from P2.1)
	&"enemies/roller": "Roller", &"enemies/guard": "Guard", &"enemies/shellback": "Shellback",
	# 2.0 phase 2 (PLAN.md P2.1): the Mimic and the co-op-only presets
	&"enemies/mimic": "Mimic", &"enemies/raptor": "Raptor", &"enemies/snatcher": "Snatcher",
	&"enemies/leech": "Leech", &"enemies/bull_rex": "BullRex", &"enemies/tar_splitter": "TarSplitter",
	&"enemies/shaman": "Shaman",
}
## Every enemy id of the DESIGN.md appendix ("Enemies": the three Book II archetypes and the seven co-op-only ones).
const DESIGN_ENEMY_IDS: Array[StringName] = [
	&"enemies/roller", &"enemies/guard", &"enemies/mimic", &"enemies/shellback", &"enemies/raptor",
	&"enemies/snatcher", &"enemies/leech", &"enemies/bull_rex", &"enemies/tar_splitter", &"enemies/shaman",
]
## The chest container's closed chest (objects-A's BonusContainer: sprites/objects/chest.png cell 0, pivot (24, 36)).
const CHEST_TEXTURE: String = "res://assets/sprites/objects/chest.png"
const CHEST_CELL: Vector2i = Vector2i(60, 36)
const CHEST_PIVOT: Vector2i = Vector2i(24, 36)
## The 15 Book I solo files (frozen: DESIGN.md A.5 "Book I never spawns them").
const BOOK1_SOLO_LEVELS: PackedStringArray = [
	"w1_l1", "w1_l2", "w2_l1", "w2_l2", "w2_l2b", "w3_l1", "w3_l1b", "w3_l2", "w4_l1", "w4_l2", "w4_l2b", "bonus_a",
	"bonus_b", "bonus_c", "ending",
]
## Default sheet and preset trait of every co-op-only enemy (DESIGN.md D.7).
const PRESETS: Dictionary[StringName, Array] = {
	&"enemies/shellback": ["shellback", Defs.CoopTrait.SHELL], &"enemies/raptor": ["mini_rex_b", Defs.CoopTrait.DAZE],
	&"enemies/snatcher": ["bat_b", Defs.CoopTrait.GRAB], &"enemies/leech": ["leech", Defs.CoopTrait.LEECH],
	&"enemies/bull_rex": ["rex_b", Defs.CoopTrait.HEAVY], &"enemies/tar_splitter": ["slime", Defs.CoopTrait.SPLIT],
	&"enemies/shaman": ["", Defs.CoopTrait.NONE],
}
const BOSS_IDS: Dictionary[StringName, String] = {&"bosses/brute": "Brute", &"bosses/colossus": "Colossus"}
const PROJECTILE_IDS: Dictionary[StringName, String] = {
	&"projectiles/boss_rock": "BossRock", &"projectiles/boss_stalactite": "BossStalactite",
	&"projectiles/enemy_ember": "EnemyEmber",
}
## Every enemy sheet of ASSET_MANIFEST.md 4 with its body box (logical w x h).
const ENEMY_SKINS: Dictionary[String, Vector2i] = {
	"bat": Vector2i(22, 23), "bat_b": Vector2i(22, 23), "dragon": Vector2i(35, 26), "dragon_b": Vector2i(35, 26),
	"egg_kid": Vector2i(26, 30), "egg_kid_b": Vector2i(26, 30), "insect": Vector2i(35, 18),
	"insect_b": Vector2i(35, 18), "lizard": Vector2i(32, 20), "lizard_b": Vector2i(32, 20),
	"mini_rex": Vector2i(29, 24), "mini_rex_b": Vector2i(29, 24), "plant": Vector2i(30, 28),
	"plant_b": Vector2i(30, 28), "pterodactyl": Vector2i(52, 22), "pterodactyl_b": Vector2i(52, 22),
	"rex": Vector2i(58, 35), "rex_b": Vector2i(58, 35), "rival": Vector2i(22, 26), "turtle": Vector2i(26, 15),
	"turtle_b": Vector2i(26, 15),
	# 2.0 world 5 sheets (art-B's hand-over, ASSET_MANIFEST.md 4 rows to add)
	"roller": Vector2i(54, 24), "roller_b": Vector2i(54, 24), "guard": Vector2i(76, 54),
	"shellback": Vector2i(76, 54), "snake": Vector2i(38, 30), "snake_b": Vector2i(38, 30),
	"cave_bat": Vector2i(55, 28), "cave_bat_b": Vector2i(55, 28), "eagle": Vector2i(34, 41),
	"bear": Vector2i(63, 51), "bear_b": Vector2i(63, 51),
	# 2.0 world 6 sheets (art-B, ahead of phase 2)
	"slime": Vector2i(36, 28), "slime_b": Vector2i(36, 28), "puffcap": Vector2i(51, 42),
	"puffcap_b": Vector2i(51, 42), "frog": Vector2i(26, 19), "larva": Vector2i(15, 13), "larva_b": Vector2i(15, 13),
	"leech": Vector2i(15, 13), "mosquito": Vector2i(35, 18),
	# 2.0 worlds 7-9 and the phase-2 enemies (art-B, PLAN.md P2.1 / P2.10)
	"gull": Vector2i(52, 22), "gull_b": Vector2i(52, 22), "storm_ptero": Vector2i(52, 22), "jelly": Vector2i(36, 28),
	"sea_snail": Vector2i(26, 15), "rival_tar": Vector2i(22, 26), "ghost": Vector2i(39, 41), "ghost_b": Vector2i(39, 41),
	"octopus": Vector2i(16, 15), "octopus_b": Vector2i(16, 15), "fish": Vector2i(15, 8), "fish_b": Vector2i(15, 8),
	"mimic": Vector2i(24, 18), "shaman": Vector2i(24, 32),
}
const BOSS_SKINS: PackedStringArray = [
	"brute", "brute_enraged", "colossus", "tusker", "tusker_rage", "mangrove", "mangrove_parts",
]
const MAX_TEXTURE_SIDE: int = 2048
const ROLES: Array[StringName] = [
	&"idle", &"walk", &"fly", &"air", &"hang", &"dive", &"leap", &"glide", &"roll", &"land", &"attack", &"windup",
	&"bite", &"recover", &"screech", &"hurt", &"dead", &"taunt", &"pound", &"crouch", &"spit", &"slam", &"rage",
	&"curl", &"uncurl", &"bump", &"dizzy", &"guard", &"rear", &"shudder", &"front", &"squash",
]


func test_every_id_has_its_scene() -> void:
	var all: Dictionary = {}
	all.merge(ENEMY_IDS)
	all.merge(BOSS_IDS)
	all.merge(PROJECTILE_IDS)
	for id: StringName in all:
		assert_true(Spawner.exists(id), "%s has a scene" % id)
		var node: Node = Spawner.instantiate(id)
		assert_not_null(node, String(id))
		if node == null:
			continue
		var script: Script = node.get_script()
		assert_eq(script.get_global_name(), StringName(all[id]), "%s script class" % id)
		assert_eq(String(node.name), all[id], "%s root name" % id)
		var sprite: Sprite2D = node.get_node_or_null(^"Sprite") as Sprite2D
		assert_not_null(sprite, "%s has a Sprite" % id)
		if sprite != null:
			assert_false(sprite.centered, "%s sprite is not centred" % id)
			assert_not_null(sprite.texture, "%s sprite has a texture" % id)
		assert_true(node is EnemyBase or node is ProjectileBase)
		node.free()


func test_every_sheet_matches_the_manifest() -> void:
	var names: PackedStringArray = PackedStringArray(ENEMY_SKINS.keys())
	names.append_array(BOSS_SKINS)
	for skin_name: String in names:
		var skin: EnemySkin = EnemySkin.find(skin_name)
		assert_not_null(skin, skin_name)
		if skin == null:
			continue
		var texture: Texture2D = load(skin.texture_path) as Texture2D
		assert_not_null(texture, skin.texture_path)
		assert_eq(Vector2i(texture.get_size()), Vector2i(skin.cell.x * skin.columns, skin.cell.y * skin.rows),
				"%s: grid x cell = sheet size" % skin_name)
		assert_true(texture.get_width() <= MAX_TEXTURE_SIDE and texture.get_height() <= MAX_TEXTURE_SIDE,
				"%s fits the 2048 px texture limit of weak devices" % skin_name)
		if ENEMY_SKINS.has(skin_name):
			assert_eq(skin.box, ENEMY_SKINS[skin_name], "%s body box" % skin_name)
		for role: StringName in ROLES:
			var anim: Vector4i = skin.anim(role)
			assert_true(anim.x >= 0 and anim.x + anim.y <= skin.columns * skin.rows,
					"%s %s frames inside the sheet" % [skin_name, role])
			assert_true(anim.y >= 1 and anim.z >= 1)
	assert_null(EnemySkin.find("no_such_sheet"))


func test_every_enemy_works_with_every_enemy_skin() -> void:
	for id: StringName in ENEMY_IDS:
		if id == &"enemies/decoration":
			continue
		for skin_name: String in ENEMY_SKINS:
			_flat_level(60, 16, 10)
			_hero.teleport(Vector2i(120, 160))
			var enemy: EnemyBase = _enemy(id, Vector2i(160, 160), {"skin": skin_name})
			assert_eq(enemy.skin, skin_name, "%s with %s" % [id, skin_name])
			assert_eq(Vector2i(enemy.box_w, enemy.box_h), ENEMY_SKINS[skin_name])
			var sprite: Sprite2D = enemy.get_node(^"Sprite")
			assert_eq(sprite.texture.resource_path, EnemySkin.ENEMY_DIR + skin_name + ".png")
			Sim.step(30)
			assert_true(sprite.frame < sprite.hframes * sprite.vframes)


func test_every_design_enemy_id_exists_and_the_presets_carry_their_trait() -> void:
	for id: StringName in DESIGN_ENEMY_IDS:
		assert_true(ENEMY_IDS.has(id), "%s is catalogued" % id)
		assert_true(Spawner.exists(id), "%s has a scene" % id)
	for id: StringName in PRESETS:
		_flat_level(60, 16, 10)
		var enemy: EnemyBase = _enemy(id, Vector2i(160, 160))
		var sheet: String = PRESETS[id][0]
		if not sheet.is_empty():
			assert_eq(enemy.skin, sheet, "%s wears its preset sheet" % id)
		var expected: int = PRESETS[id][1]
		if expected == Defs.CoopTrait.NONE:
			assert_null(enemy.coop_traits(), "%s has no trait" % id)
		else:
			assert_eq(enemy.coop_traits().kind, expected, "%s carries its trait" % id)
			var plain: EnemyBase = _enemy(id, Vector2i(300, 160), {"coop": "bond", "bond": "x"})
			assert_eq(plain.coop_traits().kind, Defs.CoopTrait.BOND, "%s: the level's coop= wins" % id)


func test_the_mimic_sheet_starts_with_the_chest_pixel_for_pixel() -> void:
	var skin: EnemySkin = EnemySkin.find("mimic")
	assert_not_null(skin)
	assert_eq(skin.box, EnemyTuning.MIMIC_BOX, "the chest container's box")
	assert_null(EnemySkin.find("mimic_b"), "one palette")
	var sheet: Image = (load(skin.texture_path) as Texture2D).get_image()
	var chest: Image = (load(CHEST_TEXTURE) as Texture2D).get_image()
	sheet.decompress()
	chest.decompress()
	# Both drawn with their pivot on the same feet point: chest (x, y) <-> mimic frame 0 (x, y) + (pivot - CHEST_PIVOT).
	var shift: Vector2i = skin.pivot - CHEST_PIVOT
	var differing: int = 0
	for y: int in skin.cell.y:
		for x: int in skin.cell.x:
			var c: Vector2i = Vector2i(x, y) - shift
			var inside: bool = c.x >= 0 and c.y >= 0 and c.x < CHEST_CELL.x and c.y < CHEST_CELL.y
			var want: Color = chest.get_pixel(c.x, c.y) if inside else Color(0, 0, 0, 0)
			var got: Color = sheet.get_pixel(x, y)
			if (want.a8 == 0 and got.a8 != 0) or (want.a8 != 0 and got.to_rgba32() != want.to_rgba32()):
				differing += 1
	assert_eq(differing, 0, "frame 0 is the closed chest container at the same feet point")


func test_book_one_never_spawns_the_new_enemies() -> void:
	var checked: int = 0
	for level_id: String in BOOK1_SOLO_LEVELS:
		var path: String = "res://levels/%s.lvl" % level_id
		if not FileAccess.file_exists(path):
			continue
		checked += 1
		var text: String = FileAccess.get_file_as_string(path)
		for id: StringName in DESIGN_ENEMY_IDS:
			assert_false(text.contains(String(id) + " ") or text.contains(String(id) + "\n"),
					"%s names %s (Book I never spawns the new enemies)" % [level_id, id])
	assert_eq(checked, BOOK1_SOLO_LEVELS.size(), "the 15 Book I solo files")


func test_module_levels_name_existing_entities() -> void:
	var dir: DirAccess = DirAccess.open("res://levels")
	assert_not_null(dir)
	var checked: int = 0
	for file: String in dir.get_files():
		if not file.begins_with("test_enemies_") or file.get_extension() != "lvl":
			continue
		checked += 1
		var sections: Dictionary = LevelText.split_sections(FileAccess.get_file_as_string("res://levels/" + file))
		var legend: Dictionary = LevelText.parse_legend(sections.get("legend", PackedStringArray()))
		for key: String in legend:
			var entry: Dictionary = legend[key]
			var id: StringName = entry["id"]
			if not Spawner.is_prop(id) and Spawner.category(id) in ["enemies", "bosses", "projectiles"]:
				assert_true(Spawner.exists(id), "%s: %s" % [file, id])
		for line: String in sections.get("entities", PackedStringArray()):
			var entity: Dictionary = LevelText.parse_entity_line(line)
			if entity.is_empty():
				continue
			var id: StringName = entity["id"]
			if Spawner.category(id) in ["enemies", "bosses", "projectiles"]:
				assert_true(Spawner.exists(id), "%s: %s" % [file, id])
	assert_true(checked >= 1, "the module has its own test levels")

