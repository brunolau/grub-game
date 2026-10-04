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
}
const BOSS_SKINS: PackedStringArray = ["brute", "brute_enraged", "colossus"]
const MAX_TEXTURE_SIDE: int = 2048
const ROLES: Array[StringName] = [
	&"idle", &"walk", &"fly", &"air", &"hang", &"dive", &"leap", &"glide", &"roll", &"land", &"attack", &"windup",
	&"bite", &"recover", &"screech", &"hurt", &"dead", &"taunt", &"pound", &"crouch", &"spit", &"slam", &"rage",
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
