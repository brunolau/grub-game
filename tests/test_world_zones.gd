extends TestCase
## The zone entities (ARCHITECTURE.md 6.2 "Zones"): secret, arena, camera_lock, dark, kill, autoscroll_stop,
## message, ember_rain, flies. Each is spawned by id into a bare LevelBase and reacts to the hero's feet point.

var _level: LevelBase = null
var _hero: PlayerBase = null


func before_each() -> void:
	Game.new_game(Defs.Difficulty.BEGINNER)
	Game.begin_level(&"test")
	_level = make_flat_level(60, 20, 15)
	_hero = PlayerBase.new()
	place(_level, _hero, Vector2i(40, 240))


func after_each() -> void:
	Sim.stop()


func _zone(id: StringName, params: Dictionary) -> ZoneBase:
	var node: Node = _level.spawn(id, Vector2i(8, 16), params)
	assert_true(node is ZoneBase, "%s spawns a zone" % id)
	return node as ZoneBase


func _walk_to(x: int, y: int = 240) -> void:
	_hero.sim_pos = Vector2i(x, y)
	Sim.step(1)


func test_every_zone_id_has_a_scene() -> void:
	for id: StringName in [&"zones/secret", &"zones/arena", &"zones/camera_lock", &"zones/dark", &"zones/kill",
			&"zones/autoscroll_stop", &"zones/message", &"zones/ember_rain", &"zones/flies"]:
		assert_true(Spawner.exists(id), "%s exists" % id)
		var zone: ZoneBase = _zone(id, {"rect": "1,1,2,2", "name": String(id).get_file()})
		assert_eq(zone.get_kind(), Defs.Kind.ZONE)
		assert_eq(zone.rect, Rect2i(16, 16, 32, 32), "rect is given in tiles")
		assert_eq(_level.find_named(StringName(String(id).get_file())), zone)


func test_secret_counts_once() -> void:
	var zone: SecretZone = _zone(&"zones/secret", {"rect": "10,13,4,2", "name": "cellar"}) as SecretZone
	var found: Array[StringName] = []
	var on_found: Callable = func(zone_name: StringName) -> void: found.append(zone_name)
	Events.secret_found.connect(on_found)
	_walk_to(100)
	assert_eq(Game.secrets_found, 0)
	_walk_to(10 * 16 + 4)
	assert_eq(Game.secrets_found, 1, "feet inside the rectangle")
	_walk_to(100)
	_walk_to(12 * 16)
	_level.reset_entities()
	_walk_to(100)
	_walk_to(12 * 16)
	Events.secret_found.disconnect(on_found)
	assert_eq(Game.secrets_found, 1, "counted once per level, deaths included")
	assert_eq(found, [&"cellar"] as Array[StringName])
	assert_true(zone.found)


func test_the_cell_above_the_feet_point_decides() -> void:
	_zone(&"zones/secret", {"rect": "10,10,4,4", "name": "x"})
	_walk_to(10 * 16 - 1, 12 * 16)
	assert_eq(Game.secrets_found, 0, "one pixel left of the rectangle")
	_walk_to(10 * 16, 14 * 16 + 1)
	assert_eq(Game.secrets_found, 0, "feet below the bottom edge")
	_walk_to(10 * 16, 14 * 16)
	assert_eq(Game.secrets_found, 1, "feet on the bottom edge: he stands in the last row of the rectangle")


func test_dead_hero_triggers_nothing() -> void:
	_zone(&"zones/secret", {"rect": "10,13,4,2", "name": "x"})
	_hero.kill(&"pit")
	_walk_to(11 * 16)
	assert_eq(Game.secrets_found, 0)


func test_arena_locks_the_camera_and_starts_its_boss() -> void:
	var arena: ArenaZone = _zone(&"zones/arena", {"rect": "20,5,24,10", "name": "pit", "music": "boss_final"}) \
			as ArenaZone
	var other: BossBase = BossBase.new()
	place(_level, other, Vector2i(30 * 16, 240), {"arena": "elsewhere"})
	var boss: BossBase = BossBase.new()
	place(_level, boss, Vector2i(40 * 16, 240), {"arena": "pit", "hp": 64})
	_walk_to(100)
	assert_false(_level.is_camera_locked())
	_walk_to(22 * 16)
	assert_true(_level.is_camera_locked(), "the hero entered the arena")
	assert_eq(_level.get_camera_lock(), arena.rect)
	assert_true(boss.fighting, "its boss starts the fight")
	assert_eq(boss.music, Sfx.MUSIC_BOSS_FINAL, "music= replaces the boss's fight music")
	assert_false(other.fighting, "a boss of another arena stays asleep")
	_level.respawn_player()
	assert_false(_level.is_camera_locked(), "a respawn releases the lock")
	assert_false(boss.fighting)
	_walk_to(100)
	_walk_to(22 * 16)
	assert_true(boss.fighting, "and the fight starts again on the way back")


func test_arena_without_a_living_boss_does_nothing() -> void:
	_zone(&"zones/arena", {"rect": "20,5,24,10", "name": "empty"})
	_walk_to(22 * 16)
	assert_false(_level.is_camera_locked())


func test_camera_lock_holds_while_inside() -> void:
	var zone: ZoneBase = _zone(&"zones/camera_lock", {"rect": "20,0,20,15"})
	_walk_to(25 * 16)
	assert_true(_level.is_camera_locked())
	assert_eq(_level.get_camera_lock(), zone.rect)
	_walk_to(45 * 16)
	assert_false(_level.is_camera_locked(), "leaving releases it")
	_walk_to(25 * 16)
	_level.lock_camera(Rect2i(0, 0, 320, 180))
	_walk_to(45 * 16)
	assert_true(_level.is_camera_locked(), "a lock set by someone else meanwhile is kept")


func test_dark_zones_switch_the_light() -> void:
	_zone(&"zones/dark", {"rect": "10,13,2,2"})
	_zone(&"zones/dark", {"rect": "20,13,2,2", "on": false})
	_walk_to(10 * 16 + 8)
	assert_true(_level.dark)
	_walk_to(15 * 16)
	assert_true(_level.dark, "stays dark after leaving")
	_walk_to(20 * 16 + 8)
	assert_false(_level.dark, "on=false switches the light back on")


func test_a_respawn_restores_the_darkness_of_the_checkpoint() -> void:
	_zone(&"zones/dark", {"rect": "10,13,2,2"})
	_level.start_play()
	var changes: Array[bool] = []
	var on_change: Callable = func(dark: bool) -> void: changes.append(dark)
	Events.darkness_changed.connect(on_change)
	# No checkpoint: back to the level start (lit).
	_walk_to(10 * 16 + 8)
	assert_true(_level.dark)
	_level.respawn_player()
	assert_false(_level.dark, "a respawn at the start is lit again")
	# Checkpoint before the trigger: lit on respawn.
	Game.set_checkpoint(Vector2i(5 * 16, 240))
	_walk_to(10 * 16 + 8)
	assert_true(_level.dark)
	_level.respawn_player()
	assert_false(_level.dark, "a checkpoint touched in the light respawns in the light")
	# Checkpoint after the trigger: dark on respawn.
	_walk_to(10 * 16 + 8)
	Game.set_checkpoint(Vector2i(12 * 16, 240))
	assert_true(_level.get_respawn_darkness())
	_level.respawn_player()
	assert_true(_level.dark, "a checkpoint touched in the dark respawns in the dark")
	Events.darkness_changed.disconnect(on_change)
	assert_eq(changes, [true, false, true, false, true] as Array[bool], "listeners hear every switch")
	Sim.stop()


func test_kill_zone() -> void:
	_zone(&"zones/kill", {"rect": "30,0,2,15"})
	_walk_to(29 * 16)
	assert_false(_hero.dead)
	_walk_to(30 * 16 + 2)
	assert_true(_hero.dead)


func test_autoscroll_stop() -> void:
	_level.scroll_flags = Defs.SCROLL_AUTO_DOWN | Defs.SCROLL_NO_HORIZONTAL
	_zone(&"zones/autoscroll_stop", {"rect": "0,10,60,5"})
	_walk_to(100, 9 * 16)
	assert_eq(_level.scroll_flags, Defs.SCROLL_AUTO_DOWN | Defs.SCROLL_NO_HORIZONTAL)
	_walk_to(100, 12 * 16)
	assert_eq(_level.scroll_flags, Defs.SCROLL_NO_HORIZONTAL, "the descent stops, vertical-only stays")


func test_message_asks_for_its_hint_while_inside() -> void:
	var zone: MessageZone = _zone(&"zones/message", {"rect": "10,12,4,3", "text": "Hit_the_ground!"}) as MessageZone
	var id: int = zone.get_instance_id()
	var requests: Array = []
	var on_request: Callable = func(source: Node, text: String) -> void:
		requests.append([source.get_instance_id(), text])
	Events.message_requested.connect(on_request)
	assert_false(zone.is_shown())
	_walk_to(11 * 16)
	assert_true(zone.is_shown())
	_walk_to(12 * 16)
	assert_eq(requests, [[id, "Hit_the_ground!"]], "asked once on entering, with the key as written")
	_walk_to(20 * 16)
	assert_false(zone.is_shown())
	assert_eq(requests.back(), [id, ""], "withdrawn on leaving")
	_walk_to(11 * 16)
	_level.reset_entities()
	assert_eq(requests.back(), [id, ""], "a respawn withdraws it")
	_walk_to(11 * 16)
	zone.free()
	assert_eq(requests.back(), [id, ""], "a zone that leaves the level withdraws it")
	Events.message_requested.disconnect(on_request)
	assert_eq(requests.size(), 6)


func test_ember_rain_drops_embers_while_the_hero_is_inside() -> void:
	var params: Dictionary = {"rect": "10,10,6,5", "period": 5, "skin": "leaf"}
	var zone: EmberRainZone = _zone(&"zones/ember_rain", params) as EmberRainZone
	Sim.start(3)
	_walk_to(100)
	Sim.step(12)
	assert_eq(zone.released, 0, "nothing falls while the hero is outside")
	_walk_to(12 * 16)
	Sim.step(9)
	assert_eq(zone.released, 2, "one every `period` ticks inside")
	var embers: Array[SimEntity] = _level.get_kind(Defs.Kind.ENEMY_PROJECTILE)
	assert_eq(embers.size(), 2)
	var ember: EnemyEmber = embers[0] as EnemyEmber
	assert_not_null(ember)
	assert_eq(ember.skin, "leaf")
	assert_true(ember.sim_pos.y < _hero.sim_pos.y - 100, "it starts high above the hero")
	_walk_to(100)
	Sim.step(12)
	assert_eq(zone.released, 2, "and stops when he leaves")


func test_zone_without_rect_covers_its_anchor_cell() -> void:
	var node: Node = _level.spawn(&"zones/kill", Vector2i(5 * 16 + 8, 14 * 16), {})
	var zone: ZoneBase = node as ZoneBase
	assert_eq(zone.rect, Rect2i(5 * 16, 13 * 16, 16, 16))
	_walk_to(5 * 16 + 3, 14 * 16 - 1)
	assert_true(_hero.dead)
