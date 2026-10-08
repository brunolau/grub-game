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


## G42 (wf9_lead_design_to_world_a.txt #2): while the band rises the view follows the hero's FOOTING - a jump in
## place drags nothing up (so it lands in view and he lives), a climb to a higher footing still raises the view.
func test_the_rising_view_follows_the_footing_not_a_jump() -> void:
	var rows: PackedStringArray = _shaft(40)
	# A ledge 9 rows over the floor on the left (columns 1-8): a higher footing to climb onto - above the footing room
	# (LevelCamera.FOOTING_ROOM_PX: every footing less than 72 px under the view's top raises the view).
	rows[30] = "#" + "#".repeat(8) + ".".repeat(14) + "#"
	var level: Level = _load("scroll = rising\nrise_speed = 4", rows)
	var hero: PlayerBase = level.player
	var camera: LevelCamera = level.get_camera()
	var tide: RisingTide = level.get_rising_tide()
	GameInput.set_scripted(func(_tick: int) -> int: return Defs.IN_LOOK)
	Sim.step(2)
	GameInput.clear_scripted()
	Sim.step(60)
	assert_true(tide.started and tide.is_rising())
	assert_true(camera.footing_mode, "the band rises: the view follows the footing")
	var top: int = camera.pos.y
	# Jump in place, Up held: the apex is far above the feet, the footing is not.
	GameInput.set_scripted(func(_tick: int) -> int: return Defs.IN_UP)
	var apex: int = hero.sim_pos.y
	for i: int in 40:
		Sim.step(1)
		apex = mini(apex, hero.sim_pos.y)
		var band_limit: int = tide.band_top + Tuning.TILE - camera.rows * Tuning.TILE
		assert_true(camera.pos.y >= maxi(mini(top, band_limit), camera.get_min().y),
				"tick %d: the view rose only with the band, never for the jump (%d, top %d, band %d)" % [i,
				camera.pos.y, top, band_limit])
	GameInput.clear_scripted()
	Sim.step(20)
	assert_true(level.start_pos.y - apex >= 2 * Tuning.TILE, "he jumped (%d px)" % (level.start_pos.y - apex))
	assert_eq(hero.sim_pos.y, level.start_pos.y, "landed back on the floor")
	assert_false(hero.dead, "the landing is in view: he lives")
	assert_true(hero.sim_pos.y <= camera.pos.y + camera.rows * Tuning.TILE, "his feet are in view")
	# A higher footing raises the view at once (the follow, not only the band).
	var before: int = camera.pos.y
	hero.teleport(Vector2i(5 * Tuning.TILE + 8, 30 * Tuning.TILE))
	Sim.step(12)
	var band_only: int = tide.band_top + Tuning.TILE - camera.rows * Tuning.TILE
	assert_true(camera.pos.y < mini(before, band_only), "climbing raised the view: %d (band alone: %d)" % [
		camera.pos.y, mini(before, band_only)])
	assert_false(hero.dead)


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


func test_rising_tar_for_two_makes_an_egg_of_the_hero_left_behind() -> void:
	# 6-2b Heart of the Mangrove in co-op: `scroll = rising` + `liquid = tar`. P1 waits on a high ledge, P2 stays on the
	# floor; the tar takes P2 (his toss, then an egg while P1 plays on), never touches the egg, and no team wipe.
	var rows: PackedStringArray = _shaft(40)
	rows[10] = "#########" + ".".repeat(14) + "#"
	var level: Level = _load("scroll = rising\nrise_speed = 128\nliquid = tar", rows, "", 2)
	var tide: RisingTide = level.get_rising_tide()
	var p1: PlayerBase = level.player
	var p2: PlayerBase = level.get_hero(1)
	assert_true(level.party_driver is PartyDriver, "a co-op party")
	p1.teleport(Vector2i(5 * Tuning.TILE + 8, 10 * Tuning.TILE))
	GameInput.set_scripted(func(_tick: int) -> int: return Defs.IN_LOOK)
	Sim.step(1)
	GameInput.clear_scripted()
	assert_true(tide.started)
	for i: int in 30:
		Sim.step(1)
		if p2.dead:
			break
	assert_true(p2.dead, "the tar band passed P2's feet: his death toss")
	assert_false(p1.dead, "P1 on the ledge is above it")
	level.stop_rising()
	var band: int = tide.band_top
	for i: int in 80:
		Sim.step(1)
		if p2.is_down():
			break
	assert_true(p2.is_down() and not p2.dead, "after the toss: an egg (the partner plays on)")
	Sim.step(20)
	assert_true(p2.is_down() and not p2.dead, "the band never touches an egg")
	assert_eq(tide.band_top, band, "the rise stopped")
	assert_false((level.party_driver as PartyDriver).wipe_pending, "no team wipe while P1 stands")
	assert_false(p1.dead)


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


# =================================================================================================================
# The footing room on a real climb (LevelCamera._follow_footing and Level._head_peek; the wf10 follow-up of G42: "the
# hero must not climb under the HUD band or leave the top of the view")
# =================================================================================================================

## The HUD band on any device (logical px) and the hero's standing height.
const HUD_BAND_PX: int = 31
const HERO_HEIGHT_PX: int = 35


## The 6-2b climb in small: a shaft of `rows` rows with one-way ledges three rows apart, one over the other (columns
## 2-20), from three rows over the floor up to row 8.
func _ledge_shaft(rows: int) -> PackedStringArray:
	var lines: PackedStringArray = _shaft(rows)
	var row: int = rows - 1 - 3
	while row >= 8:
		lines[row] = "#." + "-".repeat(19) + "..#"
		row -= 3
	return lines


## What a climb looked like while the band rose. Per hero, px under the view's top: "feet" and "head" - the lowest of
## each on the SIMULATED view (the camera's position: the view of record); "settled" - the lowest head once he has
## stood 5 ticks or more (ground, platform or vine); "drawn" - the lowest head on the DRAWN view (the camera's position
## less the level's head peek, read from the Camera2D after a frame). And: "below" - the ticks his feet were under the
## view; "egg" / "leash" - the ticks he was an egg / leashed; "rising" - the rising ticks; "sank" - the ticks the view
## came down; "peek" - the largest look-up.
func _watch_climb(level: Level, ticks: int, flags_of: Callable) -> Dictionary:
	var out: Dictionary = {"head": [1 << 20, 1 << 20], "feet": [1 << 20, 1 << 20], "settled": [1 << 20, 1 << 20],
		"drawn": [1 << 20, 1 << 20], "rising": 0, "sank": 0, "below": [0, 0], "egg": [0, 0], "leash": [0, 0], "peek": 0.0}
	var last_top: int = 1 << 30
	var stood: Array[int] = [0, 0]
	for t: int in ticks:
		for slot: int in level.hero_count():
			GameInput.set_scripted_slot(slot, func(_tick: int) -> int: return int(flags_of.call(slot, t)))
		Sim.step(1)
		level._process(1.0 / Tuning.TICK_HZ)
		var camera: LevelCamera = level._frame_logic if level._tribe_on() else level.get_camera()
		if not camera.footing_mode:
			continue
		out["rising"] += 1
		if camera.pos.y > last_top:
			out["sank"] += 1
		last_top = camera.pos.y
		out["peek"] = maxf(out["peek"], level.get_head_peek())
		var drawn_top: float = level._camera.position.y / float(Tuning.ART_SCALE)
		for hero: PlayerBase in level.heroes:
			if hero != null and hero.down:
				out["egg"][hero.slot] += 1
			if hero == null or hero.dead or hero.down:
				continue
			if hero.leash > 0:
				out["leash"][hero.slot] += 1
			var feet: int = hero.sim_pos.y - camera.pos.y
			var head: int = feet - HERO_HEIGHT_PX
			out["head"][hero.slot] = mini(out["head"][hero.slot], head)
			out["feet"][hero.slot] = mini(out["feet"][hero.slot], feet)
			if feet > camera.rows * Tuning.TILE:
				out["below"][hero.slot] += 1
			var standing: bool = hero.grounded or hero.on_platform or hero.state == Defs.HeroState.CLIMB
			stood[hero.slot] = stood[hero.slot] + 1 if standing else 0
			if stood[hero.slot] >= 5:
				out["settled"][hero.slot] = mini(out["settled"][hero.slot], head)
			var drawn_y: float = lerpf(float(hero.sim_prev.y), float(hero.sim_pos.y), Sim.alpha)
			out["drawn"][hero.slot] = mini(out["drawn"][hero.slot], int(floorf(drawn_y - float(HERO_HEIGHT_PX) - drawn_top)))
	GameInput.clear_scripted()
	return out


func test_a_rising_climb_keeps_the_hero_under_the_hud_band_and_his_jumps_in_view() -> void:
	var level: Level = _load("scroll = rising\nrise_speed = 16", _ledge_shaft(70))
	var hero: PlayerBase = level.player
	var camera: LevelCamera = level.get_camera()
	var start_y: int = hero.sim_pos.y
	# Up held all the way: he jumps to the next ledge as soon as he may - the fastest climb there is (a ledge every 20
	# ticks, 2.4 px per tick against the band's 1).
	var seen: Dictionary = _watch_climb(level, 420, func(_slot: int, _t: int) -> int: return Defs.IN_UP)
	assert_false(hero.dead, "he outclimbs the band")
	assert_true(start_y - hero.sim_pos.y >= 12 * 3 * Tuning.TILE, "a dozen ledges up (%d px)" % (start_y - hero.sim_pos.y))
	assert_true(seen["rising"] > 400, "the band rose all the while")
	assert_eq(seen["sank"], 0, "the view never came down")
	# The view of record: his feet never leave it, and once he has stood 5 ticks his head is under the band.
	assert_true(seen["feet"][0] >= 8, "his feet stay inside the view at every apex (%d px)" % seen["feet"][0])
	assert_true(seen["settled"][0] >= HUD_BAND_PX, "standing, his head is under the HUD band (%d px under the top)"
			% seen["settled"][0])
	# The drawn view: his head never passes the band - not at a jump's apex, not on the tick he lands a ledge higher.
	assert_true(seen["drawn"][0] >= HUD_BAND_PX, "drawn, his head is under the band on every tick (%d px at least)"
			% seen["drawn"][0])
	assert_true(seen["peek"] > 40.0 and seen["peek"] <= float(LevelCamera.HEAD_PEEK_MAX_PX), "the drawn view looked up %d px"
			% int(seen["peek"]))
	# He stops: the view rests with his ledge 72 px under its top and the look-up is gone.
	GameInput.set_scripted(func(_tick: int) -> int: return 0)
	for i: int in 30:
		Sim.step(1)
		level._process(1.0 / Tuning.TICK_HZ)
	GameInput.clear_scripted()
	assert_true(hero.grounded)
	assert_eq(hero.sim_pos.y - camera.pos.y, LevelCamera.FOOTING_ROOM_PX, "at rest: the footing 72 px under the top")
	assert_eq(level.get_head_peek(), 0.0, "at rest the drawn view is the camera's")
	assert_eq(level._camera.position.y, float(camera.pos.y * Tuning.ART_SCALE))


func test_a_jump_in_place_on_a_climb_ledge_still_lands_in_view() -> void:
	# G42's promise: from a ledge the view follows only the footing; jumping in place costs nothing but the band's own
	# rise - the drawn view looks up for the jump and comes back.
	var level: Level = _load("scroll = rising\nrise_speed = 4", _ledge_shaft(70))
	var hero: PlayerBase = level.player
	var camera: LevelCamera = level.get_camera()
	_watch_climb(level, 70, func(_slot: int, _t: int) -> int: return Defs.IN_UP)  # some ledges up
	GameInput.set_scripted(func(_tick: int) -> int: return 0)
	Sim.step(20)
	var ledge_y: int = hero.sim_pos.y
	assert_true(hero.grounded)
	assert_eq(ledge_y - camera.pos.y, LevelCamera.FOOTING_ROOM_PX)
	var top: int = camera.pos.y
	# Up for one tick, then let go: a short hop that comes down on the same ledge (a full jump would pass the one-way
	# ledge three rows up and land on it; the 64 px apex is the camera's own test, tests/test_world_tribe.gd).
	var apex: int = ledge_y
	var keys: Array[int] = [Defs.IN_UP]
	for i: int in 40:
		keys.append(0)
	var peeked: float = 0.0
	for i: int in keys.size():
		var flags: int = keys[i]
		GameInput.set_scripted(func(_tick: int) -> int: return flags)
		Sim.step(1)
		level._process(1.0 / Tuning.TICK_HZ)
		apex = mini(apex, hero.sim_pos.y)
		peeked = maxf(peeked, level.get_head_peek())
		var band_limit: int = level.get_rising_tide().band_top + Tuning.TILE - camera.rows * Tuning.TILE
		assert_true(camera.pos.y >= mini(top, band_limit), "tick %d: the view rose only with the band" % i)
	GameInput.clear_scripted()
	assert_false(hero.dead)
	assert_true(ledge_y - apex >= 10 and ledge_y - apex < 3 * Tuning.TILE, "a hop (%d px)" % (ledge_y - apex))
	assert_eq(hero.sim_pos.y, ledge_y, "back on his ledge")
	assert_true(hero.sim_pos.y - camera.pos.y <= camera.rows * Tuning.TILE, "he is in view where he came down")
	assert_true(peeked > 0.0, "the drawn view looked up for the hop (%d px)" % int(peeked))
	assert_eq(level.get_head_peek(), 0.0, "and came back")


func test_six_rows_down_from_the_highest_footing_is_still_in_view() -> void:
	# The Cave Painting nook of 6-2b in small: a block six rows over a climb ledge. The hero stands on it (the view
	# rises for that footing and never comes down), then walks off and drops back to the ledge: he must land in view -
	# the 1.0 off-screen rule kills 12 rows under the camera row. (An 8-row footing room would put the ledge there.)
	var rows: PackedStringArray = _ledge_shaft(70)
	var ledge_row: int = 69 - 3 * 4      # the fourth ledge
	# The nook: a block of columns 2-4, rows -6 and -5 over the ledge; no ledge beside it or between it and the ledge.
	rows[ledge_row - 6] = "#.###" + ".".repeat(18) + "#"
	rows[ledge_row - 5] = "#.###" + ".".repeat(18) + "#"
	rows[ledge_row - 3] = "#" + ".".repeat(22) + "#"
	var level: Level = _load("scroll = rising\nrise_speed = 4", rows)
	var hero: PlayerBase = level.player
	var camera: LevelCamera = level.get_camera()
	GameInput.set_scripted(func(_tick: int) -> int: return Defs.IN_LOOK)
	Sim.step(2)
	GameInput.clear_scripted()
	var nook_y: int = (ledge_row - 6) * Tuning.TILE
	hero.teleport(Vector2i(3 * Tuning.TILE + 8, ledge_row * Tuning.TILE))
	Sim.step(30)
	assert_true(hero.grounded, "on the ledge")
	hero.teleport(Vector2i(3 * Tuning.TILE + 8, nook_y))
	Sim.step(30)
	assert_true(hero.grounded, "on the nook")
	assert_eq(hero.sim_pos.y, nook_y)
	assert_eq(nook_y - camera.pos.y, LevelCamera.FOOTING_ROOM_PX, "the view rests on the nook")
	GameInput.set_scripted(func(_tick: int) -> int: return Defs.IN_RIGHT)
	Sim.step(50)
	GameInput.clear_scripted()
	assert_false(hero.dead, "he walked off the nook and lives")
	assert_true(hero.grounded)
	assert_eq(hero.sim_pos.y, ledge_row * Tuning.TILE, "back on the ledge, six rows down")
	var feet: int = hero.sim_pos.y - camera.pos.y
	assert_true(feet <= camera.rows * Tuning.TILE, "his feet are in view (%d px under the top of %d)" % [feet,
			camera.rows * Tuning.TILE])


func test_a_pair_climbing_side_by_side_both_stay_under_the_band() -> void:
	var rows: PackedStringArray = _ledge_shaft(70)
	var level: Level = _load("scroll = rising\nrise_speed = 16", rows, "objects/hero_start 14 68 slot=2", 2)
	var p1: PlayerBase = level.player
	var p2: PlayerBase = level.get_hero(1)
	assert_true(absi(p1.sim_pos.x - p2.sim_pos.x) >= 8 * Tuning.TILE, "ten columns apart: no head contacts")
	var seen: Dictionary = _watch_climb(level, 420, func(_slot: int, _t: int) -> int: return Defs.IN_UP)
	for hero: PlayerBase in [p1, p2]:
		var who: String = "P%d" % (hero.slot + 1)
		assert_false(hero.dead or hero.down, who + " climbs on")
		assert_true(seen["feet"][hero.slot] >= 8, who + ": feet in view at every apex (%d)" % seen["feet"][hero.slot])
		assert_true(seen["settled"][hero.slot] >= HUD_BAND_PX, who + ": standing, his head under the band (%d)"
				% seen["settled"][hero.slot])
		assert_true(seen["drawn"][hero.slot] >= HUD_BAND_PX, who + ": drawn, never with his head in the band (%d)"
				% seen["drawn"][hero.slot])
		assert_eq(seen["below"][hero.slot], 0, who + ": never under the view")
		assert_eq(seen["leash"][hero.slot], 0, who + ": never leashed")
	assert_eq(seen["sank"], 0)


func test_a_pair_two_ledges_apart_shares_the_rising_view() -> void:
	# One hero climbs as fast as he can; the other does the same 40 ticks later - one or two ledges (up to six rows)
	# behind all the way. G65's co-op clause: the view rises for the LEADER's footing - whichever slot he is - but holds
	# the trailing footing at most 10 rows under its top; the leader's room shrinks instead, to four rows at six apart.
	for leader_slot: int in 2:
		var rows: PackedStringArray = _ledge_shaft(70)
		var level: Level = _load("scroll = rising\nrise_speed = 4", rows, "objects/hero_start 14 68 slot=2", 2)
		var lead: PlayerBase = level.get_hero(leader_slot)
		var trail: PlayerBase = level.get_hero(1 - leader_slot)
		var frame: LevelCamera = level._frame_logic
		var who: String = "P%d leads: " % (leader_slot + 1)
		var seen: Dictionary = _watch_climb(level, 400, func(slot: int, t: int) -> int:
			return Defs.IN_UP if slot == leader_slot or t >= 40 else Defs.IN_LOOK
		)
		for hero: PlayerBase in [lead, trail]:
			assert_false(hero.dead or hero.down, who + "P%d is still climbing" % (hero.slot + 1))
			assert_eq(seen["below"][hero.slot], 0, who + "P%d was never under the view" % (hero.slot + 1))
			assert_eq(seen["egg"][hero.slot], 0, who + "P%d was never an egg" % (hero.slot + 1))
		assert_eq(seen["leash"][1 - leader_slot], 0, who + "the trailing hero was never leashed")
		assert_true(seen["settled"][1 - leader_slot] >= HUD_BAND_PX, who + "the trailing hero stands under the band")
		assert_eq(seen["sank"], 0)
		# Both stop.
		for slot: int in 2:
			GameInput.set_scripted_slot(slot, func(_tick: int) -> int: return Defs.IN_LOOK)
		Sim.step(40)
		GameInput.clear_scripted()
		assert_true(lead.grounded and trail.grounded)
		var apart: int = trail.sim_pos.y - lead.sim_pos.y
		assert_true(apart == 3 * Tuning.TILE or apart == 6 * Tuning.TILE, who + "one or two ledges apart at rest (%d px)" % apart)
		assert_true(trail.sim_pos.y - frame.pos.y <= LevelCamera.FOOTING_KEEP_LOW_PX, who + "his partner at most 10 rows under the top")
		assert_true(lead.sim_pos.y - frame.pos.y >= LevelCamera.FOOTING_LEAD_MIN_PX, who + "he keeps four rows of room (%d px)"
				% (lead.sim_pos.y - frame.pos.y))
		level.free()
		Sim.stop()
		Game.new_game(Defs.Difficulty.BEGINNER)


func test_the_rising_view_goes_with_the_leader_when_his_partner_stays_behind() -> void:
	# P2 never climbs (he taps Look: awake, but he stays on the floor). Up to six rows the pair shares the view; from
	# there it goes with P1 and P2 sinks under it: the leash makes him an egg while P1 climbs on. The leader is never
	# the one who pays.
	var rows: PackedStringArray = _ledge_shaft(70)
	var level: Level = _load("scroll = rising\nrise_speed = 4", rows, "objects/hero_start 14 68 slot=2", 2)
	var p1: PlayerBase = level.player
	var frame: LevelCamera = level._frame_logic
	var seen: Dictionary = _watch_climb(level, 200, func(slot: int, t: int) -> int:
		return Defs.IN_UP if slot == 0 else (Defs.IN_LOOK if t % 50 == 0 else 0)
	)
	assert_false(p1.dead or p1.down, "the leader climbs on")
	assert_eq(seen["egg"][0], 0, "and was never an egg")
	assert_true(seen["feet"][0] >= 0, "his feet never over the view's top (%d)" % seen["feet"][0])
	assert_true(seen["settled"][0] >= LevelCamera.FOOTING_LEAD_MIN_PX - HERO_HEIGHT_PX, "standing, his head is %d px under the top at least"
			% seen["settled"][0])
	assert_true(seen["leash"][1] >= PartyTuning.leash_egg_ticks(Game.difficulty) - 1, "the hero left behind was leashed ...")
	assert_true(seen["egg"][1] > 0, "... and became an egg (his partner plays on)")
	assert_false((level.party_driver as PartyDriver).wipe_pending, "no team wipe")
	# The leader stops: the view rests on his footing.
	for slot: int in 2:
		GameInput.set_scripted_slot(slot, func(_tick: int) -> int: return Defs.IN_LOOK if slot == 0 else 0)
	Sim.step(40)
	GameInput.clear_scripted()
	assert_true(p1.grounded)
	assert_eq(p1.sim_pos.y - frame.pos.y, LevelCamera.FOOTING_ROOM_PX, "the view rests on the leader's footing")


# =================================================================================================================
# Rafts: the drag clock across a doze, the whole deck of a docked railed raft (raft.gd, PHYSICS.md C.7)
# =================================================================================================================

## A long water level: banks at columns 0-9 and from 90 on (ground from row 12), water between, the start on the left
## bank; 100 columns x 14 rows.
func _lake() -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	for row: int in 14:
		var line: String = ".".repeat(100)
		if row >= 12:
			line = "#".repeat(10) + "~".repeat(80) + "#".repeat(10)
		elif row == 11:
			line = "....@" + ".".repeat(95)
		lines.append(line)
	return lines


func test_a_rafts_drag_clock_counts_the_ticks_it_dozed() -> void:
	# One raft beside the hero (awake all the time), one far down the lake (it dozes). D6's report: the far one's drag
	# clock stood still while it slept, so a raft paddled after a doze lost its speed on other ticks than with dozing
	# off - the per-tick digests of a co-op route parted (wf9_d6_to_objects-B.txt).
	var level: Level = _load("", _lake(), "objects/raft 14 12\nobjects/raft 70 12")
	var near: Raft = null
	var far: Raft = null
	for entity: SimEntity in level.get_kind(Defs.Kind.PLATFORM):
		var raft: Raft = entity as Raft
		if raft != null and raft.sim_pos.x < 400:
			near = raft
		elif raft != null:
			far = raft
	assert_not_null(near)
	assert_not_null(far)
	if near == null or far == null:
		return
	Sim.step(37)
	assert_false(near.is_dozing(), "the raft in view ticks")
	assert_true(far.is_dozing(), "the raft far down the lake dozes")
	assert_eq(near._moves, 37, "the drag clock: one per floating tick")
	level.doze_wake(far)
	assert_eq(far._moves, near._moves, "awake again: the slept ticks are on its clock")
	# The same strokes on both: the same speed on every tick until both rest.
	var problems: PackedStringArray = PackedStringArray()
	var x_near: int = near.sim_pos.x
	var x_far: int = far.sim_pos.x
	for stroke: int in 3:
		near.paddle(-1)
		far.paddle(-1)
	assert_eq(near.rx, Tuning.RAFT_SPEED_CAP)
	for t: int in 40:
		Sim.step(1)
		if near.rx != far.rx or near.sim_pos.x - x_near != far.sim_pos.x - x_far:
			problems.append("tick %d: rx %d / %d, moved %d / %d" % [t + 1, near.rx, far.rx, near.sim_pos.x - x_near,
					far.sim_pos.x - x_far])
	assert_eq(problems, PackedStringArray(), "paddled after its doze, it drags on the same ticks as its twin")
	assert_eq(near.rx, 0, "both at rest")
	assert_true(near.sim_pos.x > x_near)
	# It dozes off again at rest (the level looks at an awake entity again when a doze rectangle crosses a grid line, or
	# when it is noted); a second sleep is counted too.
	Sim.step(8)
	far._doze_note()
	Sim.step(13)
	assert_true(far.is_dozing(), "at rest again: asleep")
	level.doze_wake(far)
	assert_eq(far._moves, near._moves, "the second doze")
	# A team wipe / respawn resets both clocks - also the sleeper's.
	Sim.step(5)
	far._doze_note()
	Sim.step(2)
	assert_true(far.is_dozing())
	level.respawn_player()
	Sim.step(13)
	level.doze_wake(far)
	assert_eq(far._moves, near._moves, "reset while asleep: both count from the reset")
	assert_true(near._moves <= 14, "a fresh clock (%d)" % near._moves)


func test_a_beached_rafts_clock_stands_still_asleep_as_awake() -> void:
	var level: Level = _load("", _lake(), "objects/raft 70 12")
	var raft: Raft = null
	for entity: SimEntity in level.get_kind(Defs.Kind.PLATFORM):
		raft = entity as Raft
	assert_not_null(raft)
	if raft == null:
		return
	Sim.step(3)
	level.doze_wake(raft)
	raft.beached = true
	raft._doze_note()
	var moves: int = raft._moves
	Sim.step(30)
	assert_true(raft.is_dozing(), "a beached raft far away dozes")
	level.doze_wake(raft)
	assert_eq(raft._moves, moves, "beached: no drag clock, with or without a doze")


func test_a_docked_railed_raft_carries_its_rider_over_the_whole_deck() -> void:
	# G45's open sentence (content's wf10 report): docked at a bank the fence opens, but the ride test carried a railed
	# rider only inside the closed fence - on the deck's last 7 px he stood carried by nobody, dropped 3 px and died in
	# the last water column ("no failure state" on the Long Raft Home). Now the whole deck carries him.
	var level: Level = _load("", _lake(), "objects/raft 60 12 rails width=4")
	var hero: PlayerBase = level.player
	var raft: Raft = null
	for entity: SimEntity in level.get_kind(Defs.Kind.PLATFORM):
		raft = entity as Raft
	assert_not_null(raft)
	if raft == null:
		return
	var half: int = 8 * raft.width
	var deck_y: int = raft.sim_pos.y - raft.box_h
	for side: int in [1, -1]:
		# Docked: its edge against the bank's first cell (column 90 on the right, column 9 on the left).
		var bank_x: int = 90 * Tuning.TILE if side > 0 else 10 * Tuning.TILE
		raft.teleport(Vector2i(bank_x - side * half, raft.sim_pos.y))
		raft.rx = 0
		hero.teleport(Vector2i(raft.sim_pos.x, deck_y))
		hero.xvel = 0
		hero.yvel = 0
		level.snap_camera()
		Sim.step(3)
		var label: String = "right bank" if side > 0 else "left bank"
		assert_eq(raft.rider_count(), 1, label + ": aboard")
		assert_true(raft._docked_at(level, side), label + ": docked, the fence is open")
		# Every pixel of the strip between the closed fence and the bank: he stands there, carried, for 30 ticks.
		var strip: Array[int] = []
		if side > 0:
			for x: int in range(raft.rail_right_excl(), raft.sim_pos.x + half):
				strip.append(x)
		else:
			for x: int in range(raft.sim_pos.x - half, raft.rail_left()):
				strip.append(x)
		assert_eq(strip.size(), 7 if side > 0 else 8, label + ": the strip between the closed fence and the bank")
		for x: int in strip:
			hero.teleport(Vector2i(x, deck_y))
			hero.xvel = 0
			hero.yvel = 0
			var carried: int = 0
			for t: int in 30:
				Sim.step(1)
				if raft.rider_count() == 1 and hero.on_platform:
					carried += 1
			assert_false(hero.dead, "%s, x %d (centre %+d): he does not drown" % [label, x, x - raft.sim_pos.x])
			assert_eq(carried, 30, "%s, x %d: carried on every tick" % [label, x])
			if hero.dead:
				return
		# One step further is the bank: he walks off onto its floor and the raft lets him go.
		GameInput.set_scripted(func(_tick: int) -> int: return Defs.IN_RIGHT if side > 0 else Defs.IN_LEFT)
		Sim.step(40)
		GameInput.clear_scripted()
		assert_false(hero.dead, label + ": ashore alive")
		assert_true(hero.grounded and not hero.on_platform, label + ": on the bank's floor")
		assert_eq(hero.sim_pos.y, 12 * Tuning.TILE, label + ": the floor of row 12")
		assert_true((hero.sim_pos.x - bank_x) * side > 4 * Tuning.TILE, label + ": past the open fence - unrailed by the floor")
		assert_eq(raft.rider_count(), 0)
	# Afloat (not docked) the closed fence is unchanged: he cannot reach the strip.
	raft.teleport(Vector2i(50 * Tuning.TILE, raft.sim_pos.y))
	hero.teleport(Vector2i(raft.sim_pos.x, deck_y))
	hero.xvel = 0
	hero.yvel = 0
	level.snap_camera()
	Sim.step(3)
	GameInput.set_scripted(func(_tick: int) -> int: return Defs.IN_RIGHT)
	Sim.step(40)
	GameInput.clear_scripted()
	assert_false(hero.dead)
	assert_eq(hero.sim_pos.x, raft.rail_right_excl() - 1, "afloat: the rail holds him at its last pixel")
	assert_eq(raft.rider_count(), 1)
