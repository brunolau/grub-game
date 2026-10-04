extends TestCase
## The level scene and its loader (ARCHITECTURE.md 7, 8.5) on levels/test_example.lvl and on small inline levels:
## grid, header, visuals of every section, props, entities with difficulty flags, completion totals, camera,
## tile changes, darkness, wind, time limit, the respawn curtain and the music.

const LEVEL_SCENE: String = "res://scenes/world/level.tscn"
## The base viewport in art px (the headless window has another size).
const BASE_VIEW: Vector2i = Vector2i(640, 360)

## A small level used by the inline tests: 24 x 12, ground from row 10, hero start at column 2.
const SMALL_HEADER: String = """[meta]
format = 1
id = test_world_inline
kind = test
biome = cave
terrain_a = cave/terrain
terrain_b = cave/terrain_stone
background = cave
music = level_cave
%s
[legend]
E = objects/exit
%s
[tiles]
........................
........................
........................
........................
........................
........................
........................
........................
........................
..@...................E.
########################
########################
[entities]
%s
"""

var _was_manual: bool = false


func before_each() -> void:
	_was_manual = Sim.manual
	Sim.manual = true
	Game.new_game(Defs.Difficulty.BEGINNER)


func after_each() -> void:
	Sim.stop()
	Sim.manual = _was_manual
	Flow.pending_level_id = &""
	Game.begin_level(&"")


func _load_example() -> Level:
	Flow.pending_level_id = &"test_example"
	Game.begin_level(&"test_example")
	var level: Level = (load(LEVEL_SCENE) as PackedScene).instantiate() as Level
	add_node(level)
	level.set_view_size(BASE_VIEW)
	return level


func _load_text(meta_lines: String, legend_lines: String = "", entity_lines: String = "") -> Level:
	Game.begin_level(&"test_world_inline")
	var level: Level = (load(LEVEL_SCENE) as PackedScene).instantiate() as Level
	level.setup_from_text(&"test_world_inline", SMALL_HEADER % [meta_lines, legend_lines, entity_lines])
	add_node(level)
	level.set_view_size(BASE_VIEW)
	return level


func _add_hero(level: Level, pos: Vector2i) -> PlayerBase:
	var hero: PlayerBase = PlayerBase.new()
	hero.spawn_setup(pos, {})
	level.get_container("player").add_child(hero)
	hero.respawn_at(pos)
	return hero


func test_example_header_grid_and_start() -> void:
	var level: Level = _load_example()
	assert_eq(Game.level, level)
	assert_eq(level.level_id, &"test_example")
	assert_eq(str(level.meta["name"]), "Example Meadow")
	assert_eq(str(level.meta["terrain_a"]), "jungle/terrain_grass")
	assert_eq(int(level.meta["time"]), 0)
	assert_eq(level.grid.cols, 36)
	assert_eq(level.grid.rows, 14)
	assert_eq(level.start_pos, LevelText.cell_to_feet(1.0, 10.0), "feet at the bottom-centre of the '@' cell")
	assert_eq(level.grid.get_char(8, 11), TileGrid.CH_SOLID_A, "'?' stands on its tile=#")
	assert_eq(level.grid.get_char(30, 10), TileGrid.CH_SOLID_INVISIBLE, "'$' is invisible solid")
	assert_eq(level.grid.floor_at(18, 11), TileGrid.FLOOR_DEADLY, "liquid")
	assert_eq(level.scroll_flags, 0)
	assert_false(level.dark)
	assert_eq(level.wind, 0)
	assert_eq(level.time_left, -1, "time = 0: no limit")
	assert_eq(Audio.get_music_context(), Sfx.MUSIC_JUNGLE, "the level music starts")


func test_example_visual_sections() -> void:
	var level: Level = _load_example()
	var a: int = LevelTiles.SET_A
	assert_eq(level.get_painted_look(0, 11), LevelTiles.look(a, LevelTiles.TOP))
	assert_eq(level.get_painted_look(17, 11), LevelTiles.look(a, LevelTiles.TOP_RIGHT), "bank of the pool")
	assert_eq(level.get_painted_look(18, 11), LevelTiles.LOOK_NONE, "no terrain in a liquid cell")
	var surface: int = LevelTiles.look(LevelTiles.SET_LIQUID, LevelTiles.LIQUID_SURFACE)
	assert_eq(level.get_painted_look(18, 11, "front"), surface)
	var body: int = LevelTiles.look_index(level.get_painted_look(18, 12, "front"))
	assert_true(body == LevelTiles.LIQUID_BODY or body == LevelTiles.LIQUID_BODY_BUBBLES)
	assert_eq(level.get_painted_look(20, 10), LevelTiles.look(a, LevelTiles.SLOPE_UP_RIGHT))
	assert_eq(level.get_painted_look(20, 11), LevelTiles.look(a, LevelTiles.UNDER_SLOPE_UP_RIGHT))
	assert_eq(level.get_painted_look(24, 9), LevelTiles.look(a, LevelTiles.SLOPE_UP_LEFT))
	assert_eq(level.get_painted_look(22, 9), LevelTiles.look(a, LevelTiles.CAP_LEFT), "[overrides] 22 9 a 3")
	assert_eq(level.get_painted_look(23, 9), LevelTiles.look(a, LevelTiles.CAP_RIGHT), "[overrides] 23 9 a 4")
	assert_eq(level.get_painted_look(17, 4), LevelTiles.look(a, LevelTiles.ONEWAY_LEFT))
	assert_eq(level.get_painted_look(20, 4), LevelTiles.look(a, LevelTiles.ONEWAY_MID), "hatch")
	assert_eq(level.get_painted_look(26, 7), LevelTiles.look(LevelTiles.SET_B, LevelTiles.ONEWAY_LEFT), "'=' set B")
	assert_eq(level.get_painted_look(30, 10), LevelTiles.LOOK_NONE, "'$' draws nothing (the block is a sprite)")
	var wall: int = LevelTiles.look_index(level.get_painted_look(21, 9, "back"))
	assert_true(wall >= LevelTiles.BACK_FILL and wall <= LevelTiles.BACK_DECO_B, "[backwall] behind the slope")
	assert_eq(level.get_painted_look(22, 10, "back"), LevelTiles.LOOK_NONE, "no back wall behind solid ground")
	assert_eq(level.get_painted_look(20, 9, "back"), LevelTiles.LOOK_NONE, "outside the back-wall rectangle")
	var parallax: WorldParallax = level.get_node("Parallax")
	assert_eq(parallax.get_set_name(), "jungle")
	assert_eq(parallax.get_layer_count(), 4)


func test_example_props_and_entities() -> void:
	var level: Level = _load_example()
	var back: Node2D = level.get_node("PropsBack")
	var front: Node2D = level.get_node("PropsFront")
	assert_eq(back.get_child_count(), 3, "bush (legend), trunk and canopy ([entities])")
	assert_eq(front.get_child_count(), 1, "vine (layer=front)")
	var vine: Sprite2D = front.get_child(0) as Sprite2D
	assert_eq(vine.position + vine.offset, Vector2(27 * 32 + 16 - 9, 8 * 32),
			"ceiling prop (18 px wide): top-centre at the top of its cell")
	var bush: Sprite2D = back.get_child(0) as Sprite2D
	assert_eq(bush.position + bush.offset, Vector2(4 * 32 + 16 - 31, 11 * 32 - 26),
			"ground prop (62 x 26): bottom-centre of its cell")
	assert_eq(bush.position, Vector2(4 * 32 + 16, 11 * 32), "the node sits at the feet point")
	var secret: SimEntity = level.find_named(&"sky_ledge")
	assert_true(secret is SecretZone, "zones/secret from [entities]")
	assert_eq((secret as SecretZone).rect, Rect2i(16 * 16, 2 * 16, 6 * 16, 3 * 16))
	assert_eq(secret.get_parent(), level.get_container("zones"))
	assert_eq(level.get_container("enemies"), level.get_node("Enemies"))
	assert_eq(level.get_container("bosses"), level.get_node("Enemies"))
	assert_eq(level.get_container("items"), level.get_node("Items"))
	assert_eq(level.get_container("fx"), level.get_node("Fx"))
	assert_eq(level.get_container("projectiles"), level.get_node("Projectiles"))
	assert_eq(level.get_container("player"), level.get_node("PlayerLayer"))


func test_example_completion_totals_match_what_was_spawned() -> void:
	var level: Level = _load_example()
	var spots: int = 0
	var items: int = 0
	for entity: SimEntity in level.get_kind(Defs.Kind.HITTABLE):
		if (entity as HittableBase).counts_for_completion:
			spots += 1
	for entity: SimEntity in level.get_kind(Defs.Kind.COLLECTIBLE):
		var item: CollectibleBase = entity as CollectibleBase
		assert_eq(item.counts_for_completion, item.points > 0, "map-placed items with points count")
		if item.counts_for_completion:
			items += 1
	assert_eq(Game.spots_total, spots)
	assert_eq(Game.items_total, items)


func test_example_camera_starts_settled() -> void:
	var level: Level = _load_example()
	var view: Rect2i = level.get_view_rect()
	assert_eq(view.size, Vector2i(Tuning.VIEW_W, Tuning.VIEW_H))
	assert_eq(view.position, Vector2i(0, 2 * Tuning.TILE), "spawn: feet settled in screen row 9")
	assert_eq(level.get_camera_cell(), Vector2i(0, 2))
	level.request_shake(Tuning.SHAKE_LANDING)
	Sim.start(1)
	Sim.step(1)
	assert_true(level.shake_offset > 0, "odd tick: the view is offset")
	assert_eq(level.get_view_rect(), view, "the shake moves the picture, not the gameplay view")


func test_set_cell_and_set_cell_look_retile() -> void:
	var level: Level = _load_example()
	var a: int = LevelTiles.SET_A
	level.set_cell(30, 11, TileGrid.CH_AIR)
	assert_eq(level.grid.get_char(30, 11), TileGrid.CH_AIR)
	assert_eq(level.get_painted_look(30, 11), LevelTiles.LOOK_NONE)
	assert_eq(level.get_painted_look(29, 11), LevelTiles.look(a, LevelTiles.TOP_RIGHT), "left neighbour re-tiled")
	assert_eq(level.get_painted_look(31, 11), LevelTiles.look(a, LevelTiles.TOP_LEFT), "right neighbour re-tiled")
	assert_eq(level.get_painted_look(30, 12), LevelTiles.look(a, LevelTiles.TOP), "the cell below is now a surface")
	level.set_cell(30, 11, TileGrid.CH_SOLID_A)
	assert_eq(level.get_painted_look(30, 11), LevelTiles.look(a, LevelTiles.TOP))
	level.set_cell_look(8, 11, LevelTiles.FILL_INSET)
	assert_eq(level.get_painted_look(8, 11), LevelTiles.look(a, LevelTiles.FILL_INSET))
	assert_eq(level.grid.get_char(8, 11), TileGrid.CH_SOLID_A, "visual only")
	level.set_cell_look(8, 11, -1)
	assert_eq(level.get_painted_look(8, 11), LevelTiles.look(a, LevelTiles.TOP), "-1: back to the automatic tile")
	level.set_cell(21, 10, TileGrid.CH_AIR)
	assert_true(LevelTiles.look_index(level.get_painted_look(21, 10, "back")) >= LevelTiles.BACK_FILL,
			"a removed ground cell inside a back-wall rectangle shows the back wall")


func test_difficulty_flags_select_entities() -> void:
	var entities: String = "zones/dark 3 3 rect=3,3,1,1 name=only_expert expert\n" \
			+ "zones/kill 4 3 rect=4,3,1,1 name=only_beginner beginner\n" \
			+ "zones/secret 5 3 rect=5,3,1,1 name=always"
	var level: Level = _load_text("", "", entities)
	assert_null(level.find_named(&"only_expert"), "expert entities are skipped in Beginner")
	assert_not_null(level.find_named(&"only_beginner"))
	assert_not_null(level.find_named(&"always"))
	Game.difficulty = Defs.Difficulty.EXPERT
	var expert: Level = _load_text("", "", entities)
	assert_not_null(expert.find_named(&"only_expert"))
	assert_null(expert.find_named(&"only_beginner"))


func test_meta_variants_scroll_modes_and_darkness() -> void:
	Game.difficulty = Defs.Difficulty.EXPERT
	var level: Level = _load_text("scroll = autoscroll\nlow_band = true\ndark = true\ntime = 0\ntime.expert = 30")
	assert_eq(level.scroll_flags,
			Defs.SCROLL_AUTO_DOWN | Defs.SCROLL_NO_HORIZONTAL | Defs.SCROLL_LOW_BAND)
	assert_true(level.dark, "dark = true: the level starts dark")
	assert_eq(int(level.meta["time"]), 30, "time.expert overrides time in Expert")
	assert_eq(level.get_time_left_seconds(), 30)
	var modulate: CanvasModulate = level.get_node("Darkness")
	await get_tree().process_frame
	assert_true(modulate.color.is_equal_approx(Level.DARK_COLOR), "no fade at the start: already dark")


func test_darkness_fades_over_the_fade_ticks() -> void:
	var level: Level = _load_text("")
	var modulate: CanvasModulate = level.get_node("Darkness")
	var events: Array[bool] = []
	var on_dark: Callable = func(is_dark: bool) -> void: events.append(is_dark)
	Events.darkness_changed.connect(on_dark)
	level.set_darkness(true)
	Events.darkness_changed.disconnect(on_dark)
	assert_eq(events, [true] as Array[bool])
	Sim.start(1)
	Sim.step(Tuning.DARKNESS_FADE_TICKS / 2)
	await get_tree().process_frame
	assert_true(modulate.color.r < 1.0 and modulate.color.r > Level.DARK_COLOR.r, "half way through the fade")
	Sim.step(Tuning.DARKNESS_FADE_TICKS)
	await get_tree().process_frame
	assert_true(modulate.color.is_equal_approx(Level.DARK_COLOR))


func test_wind_script_applies_from_its_tick_on() -> void:
	var level: Level = _load_text("wind = 0:8,5:24,10:48")
	assert_eq(level.wind, 8, "an entry at tick 0 is in force from the start")
	Sim.start(1)
	Sim.step(3)
	assert_eq(level.wind, 8)
	Sim.step(1)
	assert_eq(level.wind, 24, "set at the end of tick 4: in force for tick 5")
	Sim.step(5)
	assert_eq(level.wind, 48)
	assert_true((level.get_node("Weather") as WorldWeather).visible, "snow shows the wind")


func test_time_limit_counts_down_and_kills() -> void:
	var level: Level = _load_text("time = 2")
	var hero: PlayerBase = _add_hero(level, level.start_pos)
	var seconds: Array[int] = []
	level.time_left_changed.connect(func(value: int) -> void: seconds.append(value))
	Sim.start(1)
	var ticks: int = floori(2.0 * Tuning.TICK_HZ)
	assert_eq(level.time_left, ticks, "the whole ticks that fit into 2 seconds")
	assert_eq(level.get_time_left_seconds(), 2)
	Sim.step(ticks - 1)
	assert_false(hero.dead)
	assert_eq(seconds, [1] as Array[int], "the displayed second changed once")
	Sim.step(1)
	assert_true(hero.dead, "time out costs a life")
	assert_eq(level.time_left, 0)
	assert_eq(seconds, [1, 0] as Array[int])


func test_respawn_curtain_puts_the_hero_back() -> void:
	var level: Level = _load_text("")
	var hero: PlayerBase = _add_hero(level, level.start_pos)
	Sim.start(1)
	hero.teleport(Vector2i(300, 100))
	var seen: Array = []
	var on_respawned: Callable = func() -> void:
		var cover: TransitionCover = Flow.get_transition_cover()
		seen.append_array([cover.amount, cover.shape, Sim.frozen, hero.dead])
	Events.level_respawned.connect(on_respawned)
	hero.kill(&"pit")
	Events.player_death_finished.emit()
	Events.level_respawned.disconnect(on_respawned)
	assert_eq(Game.lives, Tuning.LIVES_START - 1)
	assert_eq(seen, [1.0, Defs.Transition.CURTAIN, true, false],
			"put back while Flow's curtain covers the screen and the clock stands still")
	assert_false(hero.dead)
	assert_eq(hero.sim_pos, level.start_pos)
	assert_false(level.is_respawn_pending())
	assert_eq(Flow.get_transition_cover().amount, 0.0, "the curtain opened again")
	assert_false(Sim.frozen)


func test_dirty_ground_attracts_flies_and_water_washes_them_off() -> void:
	var level: Level = _load_text("", "", "zones/flies 6 9 rect=5,8,3,2 count=7")
	var hero: PlayerBase = _add_hero(level, level.start_pos)
	Sim.start(1)
	Sim.step(2)
	assert_eq(level.get_fly_count(), 0)
	hero.teleport(Vector2i(6 * 16 + 8, 160))
	Sim.step(1)
	assert_eq(level.get_fly_count(), 7, "walking over dirty ground")
	for visit: int in 2:
		hero.teleport(level.start_pos)
		Sim.step(1)
		hero.teleport(Vector2i(6 * 16 + 8, 160))
		Sim.step(1)
	assert_eq(level.get_fly_count(), Tuning.MAX_FLIES, "every visit adds flies, at most MAX_FLIES")
	var swarm: FlySwarm = level.get_node("Flies") as FlySwarm
	await get_tree().process_frame
	assert_true(swarm.is_visible_in_tree())
	Events.item_collected.emit(&"items/food", 3, 100, hero.sim_pos)
	assert_eq(level.get_fly_count(), Tuning.MAX_FLIES, "food does not wash")
	Events.item_collected.emit(&"items/water_bucket", 0, 500, hero.sim_pos)
	assert_eq(level.get_fly_count(), 0, "the water bucket clears them")
	level.attract_flies(3)
	Events.level_respawned.emit()
	assert_eq(level.get_fly_count(), 0, "a respawn starts clean")


func test_level_smaller_than_the_view_is_centred() -> void:
	var tiny: String = """[meta]
format = 1
id = test_world_tiny
kind = test
terrain_a = ice/terrain
background = ice
[tiles]
....................
....................
.@................|.
####################
"""
	var level: Level = (load(LEVEL_SCENE) as PackedScene).instantiate() as Level
	level.setup_from_text(&"test_world_tiny", tiny)
	add_node(level)
	level.set_view_size(BASE_VIEW)
	assert_eq(level.get_view_rect().position, Vector2i(0, -48),
			"a 4-row level is centred in the 180 px view (the margin above it in whole tiles)")
	assert_eq(level.get_painted_look(0, 4), LevelTiles.look(LevelTiles.SET_A, LevelTiles.FILL),
			"the ground continues below the map")
	assert_eq(level.get_painted_look(0, -1), LevelTiles.LOOK_NONE, "open sky above it")


func test_zone_level_spawns_every_zone_id() -> void:
	Flow.pending_level_id = &"test_world_zones"
	Game.begin_level(&"test_world_zones")
	var level: Level = (load(LEVEL_SCENE) as PackedScene).instantiate() as Level
	add_node(level)
	var kinds: Dictionary = {}
	for entity: SimEntity in level.get_kind(Defs.Kind.ZONE):
		kinds[entity.get_script().get_global_name()] = true
	for zone_class: String in ["MessageZone", "CameraLockZone", "SecretZone", "DarkZone", "KillZone",
			"AutoscrollStopZone", "ArenaZone"]:
		assert_true(kinds.has(zone_class), "%s is placed in test_world_zones.lvl" % zone_class)
	assert_eq(level.get_kind(Defs.Kind.ZONE).size(), 8, "two dark zones")
