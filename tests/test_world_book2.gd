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


func test_worlds_7_to_9_have_their_backdrops() -> void:
	var fills: Dictionary = {
		"coast": "77d9ff", "sea_cave": "0e1c22", "ruins": "feedc6", "temple": "1c1618", "sky": "bedafb",
		"storm": "525470", "pyre": "fb8d31",
	}
	for set_name: String in fills:
		assert_true(LevelData.BACKGROUNDS.has(set_name), set_name)
		assert_eq(ParallaxSets.fill_color(set_name), Color(fills[set_name]), set_name)
		var layers: Array = ParallaxSets.layers(set_name)
		assert_true(layers.size() >= 3, set_name)
		for layer: Dictionary in layers:
			var path: String = ParallaxSets.texture_path(layer)
			assert_true(ResourceLoader.exists(path), path)
			if ResourceLoader.exists(path):
				assert_eq((load(path) as Texture2D).get_height(), ParallaxSets.LAYER_HEIGHT, "%s: 360 px high" % path)
	for biome: String in ["coast", "ruins", "sky"]:
		var data: LevelData = LevelData.parse(&"w", "[meta]\nformat = 2\nbiome = %s\n[tiles]\n@.\n##\n" % biome)
		assert_eq(data.value("background"), biome, "the %s biome's own backdrop by default" % biome)


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


func test_current_streaks_run_over_the_water_in_the_flow_direction() -> void:
	var rows: PackedStringArray = PackedStringArray()
	for row: int in 12:
		rows.append("." .repeat(24) if row < 10 else "#".repeat(24))
	rows[9] = "..@" + ".".repeat(21)
	rows[10] = "######~~~~~~#~~~~#######"
	var level: Level = _load("", rows, "zones/current 8 10 rect=6,8,11,3 dir=r speed=2\n"
			+ "zones/current 8 10 rect=13,10,4,1 dir=u speed=1")
	var current: CurrentZone = CurrentZone.find_at(level, Vector2i(7 * 16, 10 * 16))
	var cells: Array[Vector2i] = current.water_cells()
	assert_eq(cells.size(), 10, "the '~' cells of the rectangle")
	assert_false(cells.has(Vector2i(12, 10)), "not the bank")
	assert_false(cells.has(Vector2i(7, 9)), "not the air over the water")
	assert_eq(current.z_index, CurrentZone.Z_STREAKS, "drawn in front of the liquid")
	var span: float = float(current.rect.size.x)
	var a: Rect2 = current.streak_rect(Vector2i(7, 10), 0, 0.0)
	var b: Rect2 = current.streak_rect(Vector2i(7, 10), 0, 0.25)
	assert_almost_eq(fposmod(b.position.x - a.position.x, span), 0.25 * 2.0 * Tuning.ANIM_TICKS_PER_SECOND, 0.01,
			"it drifts right at the current's 2 px per tick")
	assert_eq(a.size, Vector2(CurrentZone.STREAK_LENGTH_PX[1], 1.0), "a streak as long as the current is fast")
	assert_true(a.position.y >= 10 * 16 + 4 and a.position.y < 11 * 16, "under the surface of its row")
	assert_true(a.position.x >= current.rect.position.x and a.position.x < current.rect.end.x, "inside the rectangle")
	var up: CurrentZone = null
	for entity: SimEntity in level.get_kind(Defs.Kind.ZONE):
		if entity is CurrentZone and (entity as CurrentZone).dir == &"u":
			up = entity
	var c: Rect2 = up.streak_rect(Vector2i(14, 10), 1, 0.0)
	var d: Rect2 = up.streak_rect(Vector2i(14, 10), 1, 0.1)
	assert_eq(c.size, Vector2(1.0, CurrentZone.STREAK_LENGTH_PX[0]), "a vertical streak")
	assert_almost_eq(fposmod(c.position.y - d.position.y, float(up.rect.size.y)), 0.1 * Tuning.ANIM_TICKS_PER_SECOND,
			0.01, "rising")


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
# Lightning, food rain, alternating gusts, lights in the dark (C.6, R4, R5; DESIGN.md A.3)
# =================================================================================================================

## 24 x 12 cells, floor at row 10, the start at column 2.
func _room() -> PackedStringArray:
	var rows: PackedStringArray = PackedStringArray()
	for row: int in 12:
		rows.append("." .repeat(24) if row < 10 else "#".repeat(24))
	rows[9] = "..@" + ".".repeat(21)
	return rows


func _zone_of(level: Level, script_class: Variant) -> ZoneBase:
	for entity: SimEntity in level.get_kind(Defs.Kind.ZONE):
		if is_instance_of(entity, script_class):
			return entity as ZoneBase
	return null


func test_lightning_marks_the_column_22_ticks_ahead_then_strikes_it() -> void:
	var level: Level = _load("", _room(), "zones/lightning 4 9 rect=0,0,24,10 period=30")
	var zone: LightningZone = _zone_of(level, LightningZone) as LightningZone
	var hero: PlayerBase = level.player
	var hearts: int = hero.run.hearts
	Sim.step(29)
	assert_eq(zone.marked, 0, "every period ticks while a hero is inside")
	Sim.step(1)
	assert_eq(zone.marked, 1, "the 30th tick inside marks a strike")
	assert_eq(zone.strikes[0].x, Tuning.to_cell(hero.sim_pos.x), "the column of his feet")
	Sim.step(LightningZone.MARK_TICKS - 1)
	assert_eq(hero.hit_timer, 0, "the cloud warns for 22 ticks")
	assert_false(zone.is_bolt(zone.strikes[0].x))
	Sim.step(1)
	assert_true(zone.is_bolt(Tuning.to_cell(hero.sim_pos.x)), "then the bolt")
	assert_true(hero.hit_timer > 0, "it hurts like an enemy contact")
	assert_eq(hero.run.hearts, hearts - 1)
	Sim.step(LightningZone.BOLT_TICKS)
	assert_true(zone.strikes.is_empty(), "a bolt lasts 4 ticks")
	assert_eq(zone.column_rect(3), Rect2i(48, 0, 16, 160), "the 16 px column inside the rectangle")


func test_lightning_misses_a_hero_who_left_the_column_and_alternates_in_a_party() -> void:
	var level: Level = _load("", _room(), "objects/hero_start 12 9 slot=2\n"
			+ "zones/lightning 4 9 rect=0,0,24,10 period=10 delay=5", 2)
	var zone: LightningZone = _zone_of(level, LightningZone) as LightningZone
	var p1: PlayerBase = level.player
	var p2: PlayerBase = level.get_hero(1)
	Sim.step(14)
	assert_eq(zone.marked, 0, "the delay comes first")
	Sim.step(1)
	assert_eq(zone.marked, 1)
	assert_eq(zone.strikes[0].x, Tuning.to_cell(p1.sim_pos.x), "first P1")
	Sim.step(10)
	assert_eq(zone.marked, 2)
	assert_eq(zone.strikes[1].x, Tuning.to_cell(p2.sim_pos.x), "then P2: the heroes inside take turns")
	p1.teleport(Vector2i(p1.sim_pos.x + 64, p1.sim_pos.y))
	level.notify_hero_teleported(p1)
	Sim.step(LightningZone.MARK_TICKS)
	assert_eq(p1.hit_timer, 0, "he walked out of the marked column: missed")
	p2.go_down(&"voluntary")
	var marked: int = zone.marked
	Sim.step(40)
	for strike: Vector2i in zone.strikes:
		assert_ne(strike.x, Tuning.to_cell(p2.sim_pos.x) if absi(p2.sim_pos.x - p1.sim_pos.x) > 16 else -1,
				"an egg is never the target")
	assert_true(zone.marked > marked, "P1 alone is still struck at")
	zone._on_level_reset()
	assert_true(zone.strikes.is_empty(), "a reset clears the sky")


func test_food_rain_drops_food_on_every_hero_and_never_hurts() -> void:
	var level: Level = _load("", _room(), "objects/hero_start 12 9 slot=2\n"
			+ "zones/food_rain 4 9 rect=0,0,24,10 period=10 skin=fruit", 2)
	var zone: FoodRainZone = _zone_of(level, FoodRainZone) as FoodRainZone
	assert_eq(zone.skin, "fruit")
	Sim.step(10)
	assert_eq(zone.released, 2, "one piece per hero inside")
	var foods: Array[CollectibleBase] = []
	for entity: SimEntity in level.get_kind(Defs.Kind.COLLECTIBLE):
		var item: CollectibleBase = entity as CollectibleBase
		if item != null and item.dropped:
			foods.append(item)
	assert_eq(foods.size(), 2)
	for item: CollectibleBase in foods:
		assert_eq(item.item_id, &"items/food")
		assert_true(FoodRainZone.FRUIT_CELLS.has(item.index), "fruit cells only: %d" % item.index)
		assert_true(item.sim_pos.y < level.player.sim_pos.y - 100, "it appears high above the heroes")
	Sim.step(120)
	assert_eq(level.player.hit_timer, 0, "food never hurts")
	assert_true(FoodRainZone.food_cell("food", 5) >= ItemTable.TIER_FOOD_FROM[ItemTable.level_tier()])
	assert_true(FoodRainZone.food_cell("food", 999) <= ItemTable.TIER_FOOD_TO[ItemTable.level_tier()])


func test_the_ember_rain_keeps_its_skins() -> void:
	var level: Level = _load("", _room(), "zones/ember_rain 4 9 rect=0,0,24,10 period=10 skin=leaf")
	var zone: EmberRainZone = _zone_of(level, EmberRainZone) as EmberRainZone
	assert_eq(zone.skin, "leaf")
	Sim.step(10)
	assert_eq(zone.released, 1)
	assert_eq(level.get_kind(Defs.Kind.ENEMY_PROJECTILE).size(), 1, "an ember (a leaf), not food")


func test_alternating_gusts_repeat_the_wind_script() -> void:
	var level: Level = _load("wind = 0:-24,40:24\nwind_loop = 80", _room())
	assert_eq(level.wind, -24, "a negative wind blows right")
	var seen: Array[int] = []
	Sim.step(20)
	seen.append(level.wind)
	Sim.step(40)
	seen.append(level.wind)
	Sim.step(40)
	seen.append(level.wind)
	Sim.step(40)
	seen.append(level.wind)
	assert_eq(seen, [-24, 24, -24, 24] as Array[int], "every 80 ticks the script starts again")
	level.free()
	var plain: Level = _load("wind = 0:-24,40:24", _room())
	Sim.step(120)
	assert_eq(plain.wind, 24, "without wind_loop the 1.0 script: the last entry stays")


func test_gusts_show_as_streaks_outside_the_ice() -> void:
	assert_eq(WorldWeather.style_for_biome("ice"), WorldWeather.STYLE_SNOW, "the 1.0 blizzard keeps its snow")
	for biome: String in ["sky", "canyon", "coast", "jungle"]:
		assert_eq(WorldWeather.style_for_biome(biome), WorldWeather.STYLE_GUST, biome)
	var view: Vector2 = Vector2(640, 360)
	var a: Rect2 = WorldWeather.gust_streak(3, 0.0, 40, view)
	var b: Rect2 = WorldWeather.gust_streak(3, 0.01, 40, view)
	assert_true(b.position.x < a.position.x, "a positive wind blows left")
	var c: Rect2 = WorldWeather.gust_streak(3, 0.01, -40, view)
	assert_true(c.position.x > a.position.x, "a negative one right")
	var level: Level = _load("wind = 0:-32", _room())
	var weather: WorldWeather = level.get_node("Weather") as WorldWeather
	assert_eq(weather.style, WorldWeather.STYLE_GUST, "the canyon test level: streaks")
	assert_true(weather.visible, "visible while the wind blows")


func test_lights_in_the_dark_follow_the_palette() -> void:
	var rows: PackedStringArray = _room()
	var level: Level = _load("book = 2\ndark = true", rows, "props/swamp/glowcaps 10 9\nprops/swamp/fern 14 9")
	var lights: LevelLights = level.get_lights()
	assert_not_null(lights, "Book II: lights in the dark")
	assert_eq(lights.prop_lights.size(), 1, "the glowing caps light up, the fern does not")
	level._process(0.016)
	assert_eq(lights.hero_lights.size(), 1)
	assert_true(lights.hero_lights[0].enabled, "dark from the start: the hero glows")
	assert_almost_eq(lights.hero_lights[0].energy, LevelLights.HERO_ENERGY, 0.001)
	assert_true(lights.prop_lights[0].enabled, "the caps in view glow")
	level.set_darkness(false)
	Sim.step(Tuning.DARKNESS_FADE_TICKS)
	level._process(0.016)
	assert_false(lights.hero_lights[0].enabled, "daylight: every light off")
	assert_false(lights.prop_lights[0].enabled)
	assert_true(LevelLights.is_glow_prop("res://assets/tiles/swamp/props/glowcap_big.png"))
	assert_eq(LevelLights.prop_color("res://assets/tiles/ruins/props/brazier_glow.png"), Color("ffb050"), "warm")
	assert_eq(LevelLights.prop_color("res://assets/tiles/swamp/props/glowcaps.png"), LevelLights.PROP_COLOR, "teal")
	assert_false(LevelLights.wanted({"book": 1}, 1), "a Book I level played solo keeps the 1.0 look")
	assert_true(LevelLights.wanted({"book": 1}, 2), "a party")
	assert_true(LevelLights.wanted({"book": 1, "kind": "arena"}, 1), "an arena")
	level.free()
	var classic: Level = _load("dark = true", rows)
	assert_null(classic.get_lights())


func test_the_book_ii_biomes_have_their_music() -> void:
	for pair: Array in [["coast", Sfx.MUSIC_COAST], ["ruins", Sfx.MUSIC_RUINS], ["sky", Sfx.MUSIC_SKY_CLIMB]]:
		var data: LevelData = LevelData.parse(&"z", "[meta]\nformat = 2\nbiome = %s\n[tiles]\n@.\n##\n" % pair[0])
		assert_eq(data.value("music"), String(pair[1]), pair[0])
		assert_true(AudioTable.MUSIC.has(pair[1]), "an AudioTable row for %s" % pair[1])


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
	var storm: Level = _load_file(&"test_world_storm")
	assert_not_null(storm.get_lights(), "Book II: lights in the dark")
	assert_eq(storm.get_lights().prop_lights.size(), 3, "three glowing cap props")
	assert_eq(storm.wind, -24, "the gust script")
	Sim.step(120)
	assert_eq(storm.wind, 24, "the other way after 110 ticks")
	Sim.step(110)
	assert_eq(storm.wind, -24, "wind_loop = 220: the script again")
	storm.free()
	var coop: Level = _load_file(&"test_world_coop", 2)
	assert_eq(coop.hero_count(), 2)
	assert_true(coop.party_driver is PartyDriver)
	Sim.step(30)
	assert_false(coop.get_hero(1).is_down(), "both start on the view")
	coop.free()
