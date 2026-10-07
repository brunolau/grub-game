extends TestCase
## The Book II world of world-A (docs/expansion/PLAN.md P1.6; docs/spec/PHYSICS.md C.5, C.7, C.8; LEVEL_DESIGN.md 15):
## the tar floor ':' drawn from its floor strip, the liquids tar / honey / syrup, the canyon backdrop and biome
## defaults, the rising tide (`scroll = rising`: wait, rise, kill, camera, respawn, stop) and `zones/current`; the ember
## rain stream per hero of a party.

const LEVEL_SCENE: String = "res://scenes/world/level.tscn"
const BASE_VIEW: Vector2i = Vector2i(640, 360)
const LEVEL_TEXT: String = """[meta]
format = 2
id = test_world_book2_inline
kind = test
biome = canyon
terrain_a = canyon/terrain
terrain_b = canyon/terrain_mesa
music = level_cave
%s
[legend]
[tiles]
%s
[entities]
%s
"""

var _was_manual: bool = false


func before_each() -> void:
	_was_manual = Sim.manual
	Game.new_game(Defs.Difficulty.BEGINNER)


func after_each() -> void:
	GameInput.clear_scripted()
	Sim.stop()
	Sim.manual = _was_manual
	Flow.pending_level_id = &""
	Game.new_game(Defs.Difficulty.BEGINNER)
	Game.begin_level(&"")
	Audio.stop_music(0.0)


func _load(meta_lines: String, rows: PackedStringArray, entity_lines: String = "", party: int = 1) -> Level:
	if party > 1:
		Game.start_run(Defs.Difficulty.BEGINNER, Defs.GameMode.COOP, party)
	Sim.manual = true
	Game.begin_level(&"test_world_book2_inline")
	var level: Level = (load(LEVEL_SCENE) as PackedScene).instantiate() as Level
	level.setup_from_text(&"test_world_book2_inline", LEVEL_TEXT % [meta_lines, "\n".join(rows), entity_lines])
	add_node(level)
	level.set_view_size(BASE_VIEW)
	return level


## A tall shaft for the rising tide: `rows` rows, 24 columns, solid floor at the bottom row, the start 2 rows above
## it and a ledge every 4 rows.
func _shaft(rows: int) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	for row: int in rows:
		var line: String = "#" + ".".repeat(22) + "#"
		if row == rows - 1:
			line = "#".repeat(24)
		elif row == rows - 2:
			line = "#...@" + ".".repeat(18) + "#"
		lines.append(line)
	return lines


# =================================================================================================================
# The tar floor and the new liquids
# =================================================================================================================

func test_the_tar_floor_picks_its_surface_tiles() -> void:
	var codes: PackedByteArray = LevelTiles.codes_from_rows(PackedStringArray([
		"........",
		"#::::.:#",
		"##:::###",
	]))
	var look: Callable = func(col: int, row: int) -> int: return LevelTiles.cell_look(codes, 8, col, row)
	assert_eq(look.call(1, 1), LevelTiles.look(LevelTiles.SET_LIQUID, LevelTiles.TAR_TOP_LEFT), "left end")
	assert_eq(look.call(2, 1), LevelTiles.look(LevelTiles.SET_LIQUID, LevelTiles.TAR_TOP))
	assert_eq(look.call(4, 1), LevelTiles.look(LevelTiles.SET_LIQUID, LevelTiles.TAR_TOP_RIGHT), "right end")
	assert_eq(look.call(6, 1), LevelTiles.look(LevelTiles.SET_LIQUID, LevelTiles.TAR_TOP), "a single cell")
	assert_eq(look.call(3, 2), LevelTiles.look(LevelTiles.SET_LIQUID, LevelTiles.TAR_FILL), "under the surface")
	assert_true(LevelTiles.is_tar_floor(look.call(3, 2)))
	assert_false(LevelTiles.is_front(look.call(3, 2)), "ground, not a liquid in front of the actors")
	assert_eq(look.call(0, 1), LevelTiles.look(LevelTiles.SET_A, LevelTiles.TOP),
			"ground next to tar continues its surface (no edge tile)")
	assert_eq(look.call(1, 2), LevelTiles.look(LevelTiles.SET_A, LevelTiles.FILL_B if LevelTiles.cell_hash(1, 2) % 8 == 0
			else LevelTiles.FILL), "ground under tar is fill")


func test_the_level_paints_the_tar_floor_on_the_main_layer() -> void:
	var rows: PackedStringArray = PackedStringArray()
	for row: int in 12:
		rows.append("." .repeat(24) if row < 10 else ("##:::::#################" if row == 10 else "#".repeat(24)))
	rows[9] = "..@" + ".".repeat(21)
	var level: Level = _load("liquid = tar", rows)
	assert_eq(level.get_painted_look(3, 10), LevelTiles.look(LevelTiles.SET_LIQUID, LevelTiles.TAR_TOP),
			"the ':' cells are drawn from the floor strip")
	assert_eq(level.get_painted_look(3, 10, "front"), LevelTiles.LOOK_NONE, "nothing in front")
	assert_true(level.grid.is_tar(3, 10), "collision is TileGrid's: tar")


func test_the_new_liquids_have_strips_and_a_floor() -> void:
	for liquid: String in ["tar", "honey", "syrup"]:
		assert_true(WorldTileSet.has_liquid(liquid), liquid)
		var strip: Image = WorldTileSet.liquid_image(liquid)
		assert_not_null(strip, liquid)
		assert_eq(strip.get_size(), Vector2i(256, 32), "%s: 8 x 1 cells" % liquid)
		var texture: Texture2D = WorldTileSet.liquid_texture(liquid)
		assert_eq(texture.get_width(), (LevelTiles.LIQUID_COLUMNS + LevelTiles.TAR_FLOOR_COLUMNS) * Tuning.TILE_ART,
				"%s: the liquid strip and the tar-floor strip side by side" % liquid)
		assert_not_null(WorldTileSet.tar_floor_image(liquid), "%s floor" % liquid)
	assert_not_null(WorldTileSet.tar_floor_image("water", "canyon"), "the canyon's mud floor for ordinary water")
	var tile_set: TileSet = WorldTileSet.build("canyon/terrain", "canyon/terrain_mesa", "tar", "canyon")
	var source: TileSetAtlasSource = tile_set.get_source(LevelTiles.SET_LIQUID) as TileSetAtlasSource
	assert_true(source.has_tile(Vector2i(LevelTiles.TAR_FILL, 0)), "the floor tiles are part of the liquid source")
	assert_true(source.has_tile(Vector2i(LevelTiles.LIQUID_BODY, 0)))
	var recoloured: Image = WorldTileSet.recolour(Image.create_empty(2, 1, false, Image.FORMAT_RGBA8),
			[Color.BLACK, Color.WHITE])
	assert_eq(recoloured.get_pixel(0, 0).a, 0.0, "transparent pixels stay transparent")


func test_the_canyon_has_its_backdrop_and_its_defaults() -> void:
	assert_true(ParallaxSets.has_set("canyon"))
	assert_eq(ParallaxSets.layers("canyon").size(), 4)
	for layer: Dictionary in ParallaxSets.layers("canyon"):
		assert_true(ResourceLoader.exists(ParallaxSets.texture_path(layer)), ParallaxSets.texture_path(layer))
	assert_eq(ParallaxSets.fill_color("canyon"), Color("fff1d6"), "the cream horizon of the sky layer")
	assert_true(LevelData.BACKGROUNDS.has("canyon"))
	var data: LevelData = LevelData.parse(&"x", "[meta]\nformat = 2\nbiome = canyon\n[tiles]\n@.\n##\n")
	assert_eq(data.value("background"), "canyon")
	assert_eq(data.value("music"), String(Sfx.MUSIC_CANYON))
	assert_eq(data.value("terrain_a"), "canyon/terrain")
	for set_name: String in ["swamp", "mushroom", "mangrove"]:
		assert_true(LevelData.BACKGROUNDS.has(set_name), set_name)
		for layer: Dictionary in ParallaxSets.layers(set_name):
			assert_true(ResourceLoader.exists(ParallaxSets.texture_path(layer)), ParallaxSets.texture_path(layer))
	var fen: LevelData = LevelData.parse(&"y", "[meta]\nformat = 2\nbiome = swamp\n[tiles]\n@.\n##\n")
	assert_eq(fen.value("background"), "swamp")
	assert_eq(fen.value("music"), String(Sfx.MUSIC_FEN))


# =================================================================================================================
# The rising tide (C.8)
# =================================================================================================================

func test_the_band_waits_for_the_first_input_then_rises_and_kills() -> void:
	var level: Level = _load("scroll = rising\nrise_speed = 16", _shaft(40))
	var tide: RisingTide = level.get_rising_tide()
	assert_not_null(tide)
	var start_y: int = level.start_pos.y
	assert_eq(tide.band_top, start_y + Tuning.RISE_CHECKPOINT_ROWS * Tuning.TILE, "6 rows under the start")
	Sim.step(20)
	assert_false(tide.started, "it waits for the first input")
	assert_eq(tide.band_top, start_y + 96)
	GameInput.set_scripted(func(_tick: int) -> int: return Defs.IN_LOOK)
	Sim.step(1)
	assert_true(tide.started)
	assert_eq(tide.band_top, start_y + 95, "1 px per tick")
	GameInput.clear_scripted()
	Sim.step(15)
	assert_eq(tide.band_top, start_y + 80, "it keeps rising without input")
	var camera: LevelCamera = level.get_camera()
	var top: int = camera.pos.y
	assert_true(top <= tide.band_top + Tuning.TILE - camera.rows * Tuning.TILE, "the band is in view")
	Sim.step(90)
	assert_true(level.player.dead, "the band passed the hero's feet: he died")
	assert_true(camera.pos.y <= top, "the view never sank")


func test_a_respawn_puts_the_band_under_the_checkpoint_and_a_stop_zone_ends_the_rise() -> void:
	var level: Level = _load("scroll = rising", _shaft(40), "zones/autoscroll_stop 4 30 rect=1,28,22,3")
	var tide: RisingTide = level.get_rising_tide()
	GameInput.set_scripted(func(_tick: int) -> int: return Defs.IN_LOOK)
	Sim.step(10)
	GameInput.clear_scripted()
	assert_true(tide.started)
	Game.set_checkpoint(Vector2i(100, 20 * Tuning.TILE))
	level.player.kill(&"spikes")
	level._respawn_now()
	assert_false(tide.started, "after a respawn it waits again ...")
	assert_eq(tide.band_top, 20 * Tuning.TILE + 96, "... 6 rows under the checkpoint used")
	level.player.teleport(Vector2i(100, 30 * Tuning.TILE))
	level.snap_camera()
	GameInput.set_scripted(func(_tick: int) -> int: return Defs.IN_LOOK)
	Sim.step(3)
	GameInput.clear_scripted()
	assert_true(tide.stopped, "the hero entered the stop zone: the rise ends")
	var band: int = tide.band_top
	Sim.step(10)
	assert_eq(tide.band_top, band, "the band stays")
	assert_eq(level.scroll_flags & Defs.SCROLL_RISING, 0)
	level._respawn_now()
	assert_eq(level.scroll_flags & Defs.SCROLL_RISING, 0, "for the rest of the stage")


func test_a_level_without_the_rise_has_no_band() -> void:
	var level: Level = _load("", _shaft(20))
	assert_null(level.get_rising_tide())


# =================================================================================================================
# Currents (C.7) and the ember rain per hero
# =================================================================================================================

func test_currents_tell_what_floats_where_to_drift() -> void:
	var rows: PackedStringArray = PackedStringArray()
	for row: int in 12:
		rows.append("." .repeat(24) if row < 10 else "#".repeat(24))
	rows[9] = "..@" + ".".repeat(21)
	var level: Level = _load("", rows, "zones/current 10 9 rect=8,6,6,4 dir=l speed=3\n"
			+ "zones/current 16 9 rect=14,6,4,4 dir=u speed=9\nzones/current 20 9 rect=18,6,4,4 dir=x")
	var left: CurrentZone = CurrentZone.find_at(level, Vector2i(9 * 16, 7 * 16))
	assert_not_null(left)
	assert_eq(left.drift(), Vector2i(-3, 0))
	assert_eq(CurrentZone.drift_at(level, Vector2i(15 * 16, 7 * 16)), Vector2i(0, -Tuning.CURRENT_SPEED_MAX_PX),
			"speed clamped to 1..3")
	assert_eq(CurrentZone.drift_at(level, Vector2i(19 * 16, 7 * 16)), Vector2i(Tuning.CURRENT_SPEED_MIN_PX, 0),
			"an unknown dir flows right")
	assert_eq(CurrentZone.drift_at(level, Vector2i(2 * 16, 7 * 16)), Vector2i.ZERO, "outside every current")
	assert_true(left.spawn_params.has("dir") and left.spawn_params.has("speed"), "rafts read the parameters")
	assert_eq(left.get_kind(), Defs.Kind.ZONE)


func test_the_ember_rain_falls_on_every_hero_inside() -> void:
	var rows: PackedStringArray = PackedStringArray()
	for row: int in 12:
		rows.append("." .repeat(24) if row < 10 else "#".repeat(24))
	rows[9] = "..@" + ".".repeat(21)
	var level: Level = _load("", rows, "objects/hero_start 6 9 slot=2\nzones/ember_rain 4 9 rect=0,0,24,10 period=10",
			2)
	var zone: EmberRainZone = null
	for entity: SimEntity in level.get_kind(Defs.Kind.ZONE):
		if entity is EmberRainZone:
			zone = entity
	Sim.step(10)
	assert_eq(zone.released, 2, "one ember per hero inside")
	var slots: Array[int] = []
	for entity: SimEntity in level.get_kind(Defs.Kind.ENEMY_PROJECTILE):
		var slot: int = int(entity.spawn_params.get("rain_slot", -1))
		if not slots.has(slot):
			slots.append(slot)
	slots.sort()
	assert_eq(slots, [0, 1] as Array[int], "each stream falls on its hero")


# =================================================================================================================
# The developer levels of world-A
# =================================================================================================================

func _load_file(id: StringName, party: int = 1) -> Level:
	if party > 1:
		Game.start_run(Defs.Difficulty.BEGINNER, Defs.GameMode.COOP, party)
	Sim.manual = true
	Flow.pending_level_id = id
	Game.begin_level(id)
	var level: Level = (load(LEVEL_SCENE) as PackedScene).instantiate() as Level
	add_node(level)
	level.set_view_size(BASE_VIEW)
	return level


func test_the_world_a_levels_load_and_run() -> void:
	var canyon: Level = _load_file(&"test_world_canyon")
	assert_eq(canyon.level_id, &"test_world_canyon")
	assert_true(canyon.grid.is_tar(16, 11), "the wallow is tar")
	assert_not_null(CurrentZone.find_at(canyon, Vector2i(33 * 16, 12 * 16)), "the pool flows")
	Sim.step(30)
	assert_false(canyon.player.dead)
	canyon.free()
	var rising: Level = _load_file(&"test_world_rising")
	assert_not_null(rising.get_rising_tide())
	GameInput.set_scripted(func(_tick: int) -> int: return Defs.IN_LOOK)
	Sim.step(30)
	GameInput.clear_scripted()
	assert_true(rising.get_rising_tide().started)
	rising.free()
	var coop: Level = _load_file(&"test_world_coop", 2)
	assert_eq(coop.hero_count(), 2)
	assert_true(coop.party_driver is PartyDriver)
	Sim.step(30)
	assert_false(coop.get_hero(1).is_down(), "both start on the view")
	coop.free()
