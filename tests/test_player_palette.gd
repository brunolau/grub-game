extends PartyTestCase
## Hero colours (DESIGN.md D.1, E.9, F.1; PLAN.md P1.4 palette LUT shader): the 1.0 look keeps no material, the CPU
## twin of the shader reproduces every 1.0 hero sheet for yellow + spots and matches the art pipeline's executable
## reference (docs/art/expansion/pipeline/build_hero_palettes.py, Palettes.apply) texel for texel, the slot defaults,
## run choices and arena swaps, shared materials, and the party heroes' sprites. The GPU check of the shader itself
## is scenes/player/palette_check.tscn (a windowed dev run, see its script).

const SHEET_DIR: String = "res://assets/sprites/player/"
const SHEETS: Array[String] = ["hero", "hero_axe", "hero_boomerang", "hero_hammer", "hero_spear"]
const CELL: Vector2i = Vector2i(176, 112)
## Frames of the cross-check (idle, walk, crouch, roll, hit, air strike, climb, glide).
const FRAMES: Array[int] = [0, 8, 21, 24, 29, 35, 44, 50]
## sha256 of each frame (RGBA, transparent texels zeroed) of Palettes.apply(sheet, colour, pattern) - computed with the
## art pipeline's reference on the shipped PNGs (2026-10-07).
const REFERENCE: Array = [
	["hero", "blue", 2, [
		"98a08cb2f48a444f2f43aa9cccd8f7b7dd8cb364e8fee9f08023240c267a1cd0",
		"5125cd83e82589804e7b346f9bfc8e0b63413db65ef6330ef4ace2bb3d96e287",
		"a9c56040b401b99957152f4edbe356045ab76faf3ef76c9ed6ea955ded0c91fe",
		"10798082452a8320324102fcaa0eb32e974f23e67be821fec68b32391f190ec3",
		"586b6d2ed9400013e738fbc66dee7c96b16d3f43bc0ca8405270baf98c1a8c6f",
		"3acf44263550997a3066aaf457cc1ef3cfb10ca66d94c8906d6b49d50031acff",
		"59d7a5974696e24aca8daf2859f567fd9e5ab1abfe82a92ed4aa10c6dbd7b09e",
		"3cf27b27b1cedee0081f30aa6f5250ee8bf9c4775f46f81eb9f7dc817e63293d"]],
	["hero_axe", "pink", 3, [
		"d076ad9f3266f221575e935ccf070ee95234f2835a94b3f8974885b3b257210d",
		"38aa764d79a54b4c8427c7166b8a92ad73bff1b0a28220b46186775aeb89af1b",
		"ee0c21baeba96a78dc19c6953848db6d107f7ce79a89e22070aaaf90b9ef2b5f",
		"bc0aff16c08a74fc1f306474fa04687e7e1de8fd249eaa43629ab7926fbb0bb7",
		"95df96d4c08ffe077e8c7638072ba1f3ccfe04067af0d2e7d908bf5f977896a7",
		"0c49301168e295321a96368ab9c6445d4a5cacd896aaa45ccf8d1a4bba415447",
		"5e50d49fbe6cc167153ba62bdc842c28a948c124d56ab15c9868186246549266",
		"f02f736444c3b5cd4e8237327aacb21a1b9501fd2e57578b4b8dca391fce37ab"]],
	["hero_hammer", "green", 1, [
		"018eec0803cfd33288a2d5618cf6cf385a43ba259a03f3bdd1b5bcffcf0736ea",
		"4c750d6b7a21c568c488ad91c4b8709096bc740ce941429104da0754deb32740",
		"6e2521a2a69eb18ad3062b79adc764b1ddf8c994a0077929a088bdcfc0699132",
		"ef44535735dc102b9d04b76ff4d998c9e2a23b29602784d2bafd4fd60c3f781c",
		"fb7f11630474d9722e21306f2a9d8ab97e3d7a3397319844d32c97f27f8d182b",
		"2b5bb58ecfdff85c775bd8447bf041ce97917366ffb94967c58a7fbec6739854",
		"70bb08a29c5523c8b9786620b2fa976c141b86d0e061a29dc24b33c8ec04b2be",
		"3b0a7159c4904798190d0d863471d072db696cd84884860fbb26fa9789ea790f"]],
	["hero_spear", "white", 4, [
		"093c77ec292ffbd7acb2848728e7b28962044d90b3fe08c73d8f74cc89133f62",
		"1337ec1e60888d00203dfdd6b9666cb07049fb3f98cc5cc5fa670ea3f625dba4",
		"63bf9557fc8d475e5801c668ab461f9cb1adb1a5cf31b3c65a24ea5e1eb5a407",
		"0a435e79e460bf83fe392d0c8e895f926831f0501f752b7b5e3bf40ded77294f",
		"6ffa809d729407b55f16d49735267577047a4666945186074856dc95715806f9",
		"9d356c725af1d36624d9c86374efa1f297cd7bebb5e29fa23612096238868c70",
		"3da1a56803c84362a306c0725ea1c117ca2aebea316838978157f2178b07e2d1",
		"3c0a1deb129018803ea7a9b9309c701046b2793ff7d9d136f95ad9eadef911c3"]],
	["hero", "gold", 11, [
		"59a3bc263699f78cf8083a3a7c12068722774cb8b4b0b691457d7ec3a6c13677",
		"64182a6628c90613596d1ca4f845be066b7fbae392ab7e621fff048dc154ff2f",
		"68dcb0eb639cce9af48fc6724ad3e1121b127ccc0b134908c53aa3fd135e0fe4",
		"71ee29ae2b3f3c7432ea46e70b104449b3932fdb10804cee121818a9fc01d5f5",
		"5a493314ff65dda42b469518b5ef67c02871d8bb58abcc72c8b071a0ceceb316",
		"f94e8518a719727e49cc4a01af4e8bb145fd704a492f9b7b29a800f637db6552",
		"d91303858c22a851141ac9f428dd4275a68200bcbf7a07b42a4e4f651989cfdf",
		"c745c7b075ee17a6fe3f01a2f79074dfb9c06fc586d89350f82c043bec2d1448"]],
]
## The revive egg in blue with the pattern step off.
const EGG_BLUE: String = "ef981cb7a61226d3ede79c8c4eefa0a5c2f8e9d741a8026d180b862ecfefd2f1"


func test_yellow_with_spots_is_every_1_0_sheet_and_needs_no_material() -> void:
	assert_true(HeroPalette.is_identity(&"yellow", 0))
	assert_null(HeroPalette.material_for(&"yellow", 0), "the 1.0 look keeps no material")
	assert_null(HeroPalette.material_for(&"yellow", 7, false), "the egg in yellow: the key colours, no material")
	assert_not_null(HeroPalette.material_for(&"yellow", 2), "yellow with stripes is a material")
	for sheet: String in SHEETS:
		var image: Image = _sheet(sheet)
		var out: Image = HeroPalette.apply_image(image, &"yellow", 0)
		assert_not_null(out)
		assert_true(out.get_data() == image.get_data(), "%s: yellow + spots is the 1.0 sheet, texel for texel" % sheet)


func test_the_cpu_twin_matches_the_art_pipeline_reference() -> void:
	for case: Array in REFERENCE:
		var out: Image = HeroPalette.apply_image(_sheet(str(case[0])), StringName(case[1]), int(case[2]))
		var hashes: Array = case[3]
		for i: int in FRAMES.size():
			var frame: int = FRAMES[i]
			var cell: Image = out.get_region(Rect2i(Vector2i(frame % 8, frame / 8) * CELL, CELL))
			assert_eq(_digest(cell), str(hashes[i]), "%s %s pattern %d frame %d" % [case[0], case[1], case[2], frame])
	var egg: Image = _sheet("hero_egg")
	assert_eq(_digest(HeroPalette.apply_image(egg, &"blue", 0, false)), EGG_BLUE, "the egg, LUT only")


func test_slot_defaults_run_choices_and_arena_swaps() -> void:
	var defaults: Array = []
	for slot: int in Defs.MAX_PLAYERS:
		defaults.append(HeroPalette.resolve(slot))
	assert_eq(defaults, [[&"yellow", 0], [&"blue", 2], [&"pink", 3], [&"green", 1]], "P1 yellow spots ... P4 green")
	var run: PlayerRun = PlayerRun.new(1)
	run.palette = &"gold"
	run.pattern = 10
	assert_eq(HeroPalette.resolve(1, run), [&"gold", 10], "the join panel's choice")
	run.palette = &"purple"
	run.pattern = 99
	assert_eq(HeroPalette.resolve(1, run), [&"blue", 2], "unknown choices fall back to the slot default")
	assert_eq(HeroPalette.resolve(3, null, "jungle", true)[0], &"white", "green turns white on jungle arenas")
	assert_eq(HeroPalette.resolve(3, null, "jungle", false)[0], &"green", "only in versus")
	assert_eq(HeroPalette.resolve(3, null, "canyon", true)[0], &"green")
	assert_eq(HeroPalette.pattern_index("stripes"), 2)
	assert_eq(HeroPalette.pattern_count(), 12)
	assert_eq(HeroPalette.colour_names().size(), 6)
	assert_eq(HeroPalette.ui_colour(&"blue"), Color.html("#8ae6ff"))


func test_materials_are_shared_and_carry_the_contract() -> void:
	var blue: ShaderMaterial = HeroPalette.material_for(&"blue", 2)
	assert_not_null(blue)
	assert_true(blue == HeroPalette.material_for(&"blue", 2), "one material per colour and pattern")
	assert_false(blue == HeroPalette.material_for(&"blue", 3))
	var egg: ShaderMaterial = HeroPalette.material_for(&"blue", 2, false)
	assert_false(egg == blue, "the egg's material has the pattern step off")
	assert_eq(egg.get_shader_parameter(&"use_cloth"), false)
	assert_eq(blue.get_shader_parameter(&"pattern"), 2)
	assert_eq(blue.get_shader_parameter(&"cloth_window"), Vector4i(69, 62, 42, 36), "hero_palettes.json cloth_window")
	assert_eq(blue.get_shader_parameter(&"cell_size"), CELL)
	assert_true(blue.shader == HeroPalette.shader(), "one shader")
	assert_true(blue.shader.code.contains("texelFetch(key_lut"))
	assert_null(HeroPalette.material_for(&"purple", 2), "an unknown colour keeps the 1.0 look")


func test_party_heroes_wear_their_colours() -> void:
	party(Defs.GameMode.COOP)
	assert_null(p1.get_node(^"Sprite").material, "P1 is yellow with the spots: no material")
	assert_true(p2.get_node(^"Sprite").material == HeroPalette.material_for(&"blue", 2), "P2 blue with stripes")
	p2.go_down(&"leash")
	var egg: Sprite2D = p2.get_node(^"EggSprite") as Sprite2D
	assert_true(egg.material == HeroPalette.material_for(&"blue", 2, false), "his egg in blue, LUT only")
	Game.runs[0].palette = &"pink"
	party(Defs.GameMode.VERSUS)
	assert_true(p1.get_node(^"Sprite").material == HeroPalette.material_for(&"pink", 0), "a chosen colour")
	Game.runs[0].palette = &""


func _sheet(sheet_name: String) -> Image:
	var texture: Texture2D = load(SHEET_DIR + sheet_name + ".png") as Texture2D
	var image: Image = texture.get_image()
	if image.get_format() != Image.FORMAT_RGBA8:
		image.convert(Image.FORMAT_RGBA8)
	return image


## sha256 of the RGBA bytes with every transparent texel zeroed (the import may change their colour).
static func _digest(image: Image) -> String:
	var copy: Image = image.duplicate() as Image
	if copy.get_format() != Image.FORMAT_RGBA8:
		copy.convert(Image.FORMAT_RGBA8)
	var data: PackedByteArray = copy.get_data()
	for o: int in range(0, data.size(), 4):
		if data[o + 3] == 0:
			data[o] = 0
			data[o + 1] = 0
			data[o + 2] = 0
	var context: HashingContext = HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(data)
	return context.finish().hex_encode()
