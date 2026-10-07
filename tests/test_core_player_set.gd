extends TestCase
## The PlayerSet of LevelBase (docs/expansion/TECH_AUDIT.md 4.1, PLAN.md P0.6): heroes by slot, the target / every /
## P1 idioms, several views, the doze rectangles of a party, the once-per-tick shake guard, the party death routing,
## the per-hero platform guard, zone masks, shared music, party starts and the hero's own input slot - and that a
## party of one is exactly the 1.0 level (TECH_AUDIT.md 2; the route digests prove the rest, tools/sp_identity.sh).

const LEVEL_SCENE: String = "res://scenes/world/level.tscn"
const BASE_VIEW: Vector2i = Vector2i(640, 360)
## A small inline level: 24 x 12, ground from row 10, '@' at column 2 of row 9.
const SMALL_LEVEL: String = """[meta]
format = 1
id = test_core_party_inline
kind = test
biome = cave
terrain_a = cave/terrain
terrain_b = cave/terrain_stone
background = cave
music = level_cave
[legend]
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
..@.....................
########################
########################
[entities]
%s
"""


## A bare level drawn in two views side by side (a split-screen stand-in).
class TwoViewLevel:
	extends LevelBase

	var views: Array[Rect2i] = [
		Rect2i(0, 0, Tuning.VIEW_W, Tuning.VIEW_H), Rect2i(2000, 0, Tuning.VIEW_W, Tuning.VIEW_H),
	]

	func get_view_rect() -> Rect2i:
		return views[0]

	func get_view_count() -> int:
		return views.size()

	func get_view_rect_at(index: int) -> Rect2i:
		return views[index] if index >= 0 and index < views.size() else Rect2i()


var _was_manual: bool = false


func before_each() -> void:
	_was_manual = Sim.manual
	Game.new_game(Defs.Difficulty.BEGINNER)


func after_each() -> void:
	GameInput.clear_scripted()
	LevelBase.doze_enabled = true
	Sim.stop()
	Sim.manual = _was_manual
	Flow.pending_level_id = &""
	Game.new_game(Defs.Difficulty.BEGINNER)
	Game.begin_level(&"")
	Audio.stop_music(0.0)


func _hero(level: LevelBase, slot: int, pos: Vector2i) -> PlayerBase:
	var hero: PlayerBase = PlayerBase.new()
	place(level, hero, pos, {"slot": slot})
	return hero


func _entity(level: LevelBase, pos: Vector2i) -> SimEntity:
	var entity: SimEntity = SimEntity.new()
	place(level, entity, pos)
	return entity


## The inline level through the world module's loader (the party comes from Game.party).
func _load_level(entity_lines: String = "") -> Level:
	Sim.manual = true
	Game.begin_level(&"test_core_party_inline")
	var level: Level = (load(LEVEL_SCENE) as PackedScene).instantiate() as Level
	level.setup_from_text(&"test_core_party_inline", SMALL_LEVEL % entity_lines)
	add_node(level)
	level.set_view_size(BASE_VIEW)
	return level


# =================================================================================================================
# A party of one
# =================================================================================================================

func test_a_party_of_one_is_the_1_0_hero() -> void:
	var level: LevelBase = make_flat_level(40, 16, 10)
	assert_eq(level.hero_count(), 0)
	assert_true(level.contact_order().is_empty())
	assert_null(level.target_hero(null))
	assert_false(level.all_heroes_dead_or_down(), "no hero is no wipe")
	var hero: PlayerBase = _hero(level, 0, Vector2i(100, 160))
	var enemy: SimEntity = _entity(level, Vector2i(500, 160))
	assert_eq(level.player, hero)
	assert_eq(level.heroes, [hero] as Array[PlayerBase])
	assert_eq(level.hero_count(), 1)
	assert_eq(level.get_hero(0), hero)
	assert_null(level.get_hero(1))
	assert_null(level.get_hero(-1))
	assert_eq(level.contact_order(), [hero] as Array[PlayerBase])
	assert_eq(level.target_hero(enemy), hero, "1.0: the hero, however far")
	assert_eq(hero.slot, 0)
	assert_true(hero.run == Game.runs[0], "P1's run is behind Game.hearts")
	assert_false(level.any_hero_dead_or_down())
	assert_false(level.any_hero_feasting())
	hero.feast = 5
	assert_true(level.any_hero_feasting())
	hero.kill(&"spikes")
	assert_null(level.target_hero(enemy), "1.0: no target while the hero is dead")
	assert_true(level.any_hero_dead_or_down())
	assert_true(level.all_heroes_dead_or_down())
	assert_eq(level.get_start_pos_for(0), level.start_pos)
	assert_eq(level.get_respawn_pos_for(0), level.get_respawn_pos())
	Game.set_checkpoint(Vector2i(200, 160))
	assert_eq(level.get_respawn_pos_for(0), Vector2i(200, 160))
	assert_eq(level.get_view_count(), 1)
	assert_eq(level.get_view_rect_at(0), level.get_view_rect())
	assert_eq(level.get_view_rect_at(1), Rect2i())
	assert_eq(level.get_view_rect_of(hero), level.get_view_rect())
	assert_eq(level.get_views_bounds(), level.get_view_rect())
	# 1.0 read `level.player` directly: a test that clears it takes the hero out of every contact.
	level.player = null
	assert_true(level.contact_order().is_empty())
	assert_null(level.target_hero(enemy))


func test_one_hero_ticks_the_shake_counter_as_in_1_0() -> void:
	var level: LevelBase = make_flat_level(40, 16, 10)
	var hero: PlayerBase = _hero(level, 0, Vector2i(100, 160))
	Sim.step(1)
	level.shake = 7
	level.tick_shake_timer_by(hero)
	level.tick_shake_timer_by(hero)
	assert_eq(level.shake, 5, "his timer step and his death step in one tick: twice, as in 1.0")


func test_a_teleport_of_a_party_of_one_waits_for_the_next_tick() -> void:
	var level: LevelBase = make_flat_level(400, 24, 20)
	var hero: PlayerBase = _hero(level, 0, Vector2i(100, 320))
	var item: CollectibleBase = CollectibleBase.new()
	place(level, item, Vector2i(3000, 320))
	Sim.step(2)
	assert_true(item.is_dozing())
	hero.teleport(Vector2i(2900, 320))
	level.notify_hero_teleported(hero)
	assert_true(item.is_dozing(), "one hero: the tick start decides, exactly as in 1.0")
	Sim.step(1)
	assert_false(item.is_dozing())


# =================================================================================================================
# A party
# =================================================================================================================

func test_heroes_take_their_slots_and_their_runs() -> void:
	var level: LevelBase = make_flat_level(40, 16, 10)
	var p2: PlayerBase = _hero(level, 1, Vector2i(200, 160))
	assert_null(level.player, "P2 is not P1")
	assert_eq(level.heroes, [null, p2] as Array[PlayerBase])
	var p1: PlayerBase = _hero(level, 0, Vector2i(100, 160))
	assert_eq(level.player, p1)
	assert_eq(level.heroes, [p1, p2] as Array[PlayerBase])
	assert_eq(level.hero_count(), 2)
	assert_eq(level.contact_order(), [p1, p2] as Array[PlayerBase], "slot order in co-op")
	assert_true(p2.run == Game.runs[1])
	assert_eq(Defs.hitter_slot(p2), 1)
	assert_eq(Defs.hitter_slot(p1), 0)
	var shot: ProjectileBase = ProjectileBase.new()
	shot.spawn_setup(Vector2i(10, 10), {"from_hero": true, "owner": 1})
	assert_eq(shot.owner_slot, 1)
	assert_eq(Defs.hitter_slot(shot), 1, "a throw credits its owner")
	shot.free()
	var clamped: PlayerBase = PlayerBase.new()
	clamped.slot = 9
	assert_eq(clamped.slot, Defs.MAX_PLAYERS - 1)
	assert_true(clamped.run == Game.runs[Defs.MAX_PLAYERS - 1])
	clamped.free()
	p1.free()
	assert_null(level.player)
	assert_eq(level.hero_count(), 1)
	assert_eq(level.get_hero(1), p2)
	p2.free()
	assert_true(level.heroes.is_empty())
	assert_eq(level.hero_count(), 0)


func test_versus_rotates_the_contact_order_every_tick() -> void:
	var level: LevelBase = make_flat_level(40, 16, 10)
	var p1: PlayerBase = _hero(level, 0, Vector2i(100, 160))
	var p2: PlayerBase = _hero(level, 1, Vector2i(200, 160))
	Game.mode = Defs.GameMode.VERSUS
	for i: int in 4:
		Sim.step(1)
		var expected: Array[PlayerBase] = [p1, p2]
		if Sim.tick % 2 == 1:
			expected = [p2, p1]
		assert_eq(level.contact_order(), expected, "tick %d" % Sim.tick)
	Game.mode = Defs.GameMode.COOP
	assert_eq(level.contact_order(), [p1, p2] as Array[PlayerBase])


func test_enemies_target_the_nearest_targetable_hero() -> void:
	var level: LevelBase = make_flat_level(40, 16, 10)
	var p1: PlayerBase = _hero(level, 0, Vector2i(100, 160))
	var p2: PlayerBase = _hero(level, 1, Vector2i(500, 160))
	var enemy: SimEntity = _entity(level, Vector2i(400, 160))
	assert_eq(level.target_hero(enemy), p2, "the nearer one")
	enemy.sim_pos = Vector2i(300, 160)
	assert_eq(level.target_hero(enemy), p1, "a tie goes to the lower slot")
	p1.dead = true
	assert_eq(level.target_hero(enemy), p2, "a dead hero is no target")
	assert_true(level.any_hero_dead_or_down())
	assert_false(level.all_heroes_dead_or_down())
	p2.dead = true
	assert_null(level.target_hero(enemy))
	assert_true(level.all_heroes_dead_or_down())
	p1.dead = false
	p2.dead = false
	assert_eq(level.target_hero(null), p1, "without a position: the first in slot order")
	assert_false(level.any_hero_feasting())
	p2.feast = 3
	assert_true(level.any_hero_feasting(), "any hero's feast")


func test_the_shake_counter_runs_once_per_tick_for_a_party() -> void:
	var level: LevelBase = make_flat_level(40, 16, 10)
	var p1: PlayerBase = _hero(level, 0, Vector2i(100, 160))
	var p2: PlayerBase = _hero(level, 1, Vector2i(200, 160))
	Sim.step(1)
	level.shake = 9
	level.tick_shake_timer_by(p1)
	assert_eq(level.shake, 8)
	level.tick_shake_timer_by(p2)
	assert_eq(level.shake, 8, "another hero in the same tick changes nothing")
	level.tick_shake_timer_by(p1)
	assert_eq(level.shake, 7, "the same hero again (timer step and death step), as in 1.0")
	Sim.step(1)
	var before: int = level.shake
	level.tick_shake_timer_by(p2)
	assert_eq(level.shake, before - 1, "a new tick: the first caller owns it")
	level.tick_shake_timer_by(p1)
	assert_eq(level.shake, before - 1)


func test_a_party_loses_a_life_only_when_every_toss_is_over() -> void:
	var level: LevelBase = make_flat_level(40, 16, 10)
	level.start_pos = Vector2i(100, 160)
	var p1: PlayerBase = _hero(level, 0, Vector2i(100, 160))
	var p2: PlayerBase = _hero(level, 1, Vector2i(200, 160))
	var wipes: Array[int] = [0]
	var on_wipe: Callable = func() -> void: wipes[0] += 1
	Events.party_wiped.connect(on_wipe)
	p1.kill(&"spikes")
	Events.player_death_finished.emit()
	assert_eq(Game.lives, Tuning.LIVES_START, "a party does not go by the 1.0 signal")
	level.hero_death_finished(p1)
	assert_eq(Game.lives, Tuning.LIVES_START, "P2 still plays: P1 waits")
	assert_true(p1.dead)
	p2.kill(&"pit")
	assert_eq(wipes[0], 0, "P2's toss is still playing")
	level.hero_death_finished(p2)
	Events.party_wiped.disconnect(on_wipe)
	assert_eq(wipes[0], 1, "the last toss ended: team wipe")
	assert_eq(Game.lives, Tuning.LIVES_START - 1, "one life from the pool")
	assert_false(p1.dead)
	assert_false(p2.dead)
	assert_eq(p1.sim_pos, level.get_respawn_pos())
	assert_eq(p2.sim_pos, level.get_respawn_pos_for(1))
	assert_ne(p2.sim_pos, p1.sim_pos, "spread by slot")
	p2.kill(&"pit")
	level.respawn_hero(p2, Vector2i(150, 160))
	assert_false(p2.dead, "one hero back without a world reset")
	assert_eq(p2.sim_pos, Vector2i(150, 160))
	assert_eq(Game.lives, Tuning.LIVES_START - 1)


func test_slots_respawn_spread_towards_the_floor() -> void:
	var rows: PackedStringArray = PackedStringArray()
	for row: int in 12:
		rows.append((TileGrid.CH_SOLID_A if row >= 10 else TileGrid.CH_AIR).repeat(20))
	var level: LevelBase = make_level(rows)
	level.start_pos = Vector2i(88, 160)
	assert_eq(level.get_start_pos_for(1), Vector2i(112, 160), "24 px towards the side with floor (right first)")
	assert_eq(level.get_start_pos_for(2), Vector2i(136, 160))
	level.start_positions = [Vector2i(88, 160), Vector2i(60, 160)] as Array[Vector2i]
	assert_eq(level.get_start_pos_for(1), Vector2i(60, 160), "a start the loader placed")
	assert_eq(level.get_respawn_pos_for(1), Vector2i(60, 160), "no checkpoint: the slot's start")
	Game.set_checkpoint(Vector2i(88, 160))
	assert_eq(level.get_respawn_pos_for(1), Vector2i(112, 160))
	level.grid.set_char(7, 9, TileGrid.CH_SOLID_A)
	assert_eq(level.get_respawn_pos_for(1), Vector2i(64, 160), "a wall on the right: to the left")
	level.grid.set_char(4, 9, TileGrid.CH_SOLID_A)
	assert_eq(level.get_respawn_pos_for(1), Vector2i(88, 160), "both sides blocked: the checkpoint itself")


func test_a_party_keeps_everything_near_every_hero_awake() -> void:
	var level: LevelBase = make_flat_level(400, 24, 20)
	var p1: PlayerBase = _hero(level, 0, Vector2i(100, 320))
	var p2: PlayerBase = _hero(level, 1, Vector2i(3000, 320))
	var near_p2: CollectibleBase = CollectibleBase.new()
	var far: CollectibleBase = CollectibleBase.new()
	place(level, near_p2, Vector2i(3100, 320))
	place(level, far, Vector2i(6000, 320))
	Sim.step(2)
	assert_false(near_p2.is_dozing(), "within P2's reach")
	assert_true(far.is_dozing(), "far from both heroes and the view")
	assert_eq(level._dz_more_count, 1, "one more doze rectangle: P2's")
	p2.teleport(Vector2i(160, 320))
	level.notify_hero_teleported(p2)
	assert_true(near_p2.is_dozing(), "P2 jumped away: decided at once")
	p2.teleport(Vector2i(5950, 320))
	Sim.step(1)
	assert_false(far.is_dozing(), "a party re-decides at the tick start when any hero moved")
	assert_eq(p1.sim_pos, Vector2i(100, 320))


func test_every_view_counts_for_on_screen_and_is_in_view() -> void:
	var level: TwoViewLevel = TwoViewLevel.new()
	level.level_id = &"test"
	var rows: PackedStringArray = PackedStringArray()
	for row: int in 24:
		rows.append((TileGrid.CH_SOLID_A if row >= 20 else TileGrid.CH_AIR).repeat(200))
	level.grid = TileGrid.from_rows(rows, 0, 0)
	add_node(level)
	_hero(level, 0, Vector2i(100, 160))
	var in_second: SimEntity = _entity(level, Vector2i(2100, 100))
	var in_none: SimEntity = _entity(level, Vector2i(1000, 100))
	assert_true(level.is_in_view(in_second))
	assert_false(level.is_in_view(in_none))
	assert_true(level.is_in_view(in_none, 700), "the margin grows every view")
	assert_eq(level.get_view_rect_of(in_second), level.views[1])
	assert_eq(level.get_view_rect_of(in_none), level.views[0], "in no view: view 0")
	assert_eq(level.get_views_bounds(), level.views[0].merge(level.views[1]))
	Sim.step(1)
	assert_true(in_second.on_screen, "drawn in the second view")
	assert_false(in_none.on_screen)


func test_a_zone_tracks_every_hero_and_the_lock_follows_the_first_and_the_last() -> void:
	var level: LevelBase = make_flat_level(80, 24, 20)
	var p1: PlayerBase = _hero(level, 0, Vector2i(100, 320))
	var p2: PlayerBase = _hero(level, 1, Vector2i(120, 320))
	var zone: CameraLockZone = CameraLockZone.new()
	place(level, zone, Vector2i(40 * 16, 320), {"rect": "40,10,10,10"})
	Sim.step(1)
	assert_false(zone.inside)
	p2.teleport(Vector2i(700, 320))
	Sim.step(1)
	assert_eq(zone.inside_mask, 2)
	assert_true(zone.inside)
	assert_true(level.is_camera_locked(), "the first hero in locks the camera")
	p1.teleport(Vector2i(720, 320))
	Sim.step(1)
	assert_eq(zone.inside_mask, 3)
	p2.teleport(Vector2i(120, 320))
	Sim.step(1)
	assert_eq(zone.inside_mask, 1)
	assert_true(level.is_camera_locked(), "P1 is still inside")
	p1.dead = true
	p1.teleport(Vector2i(100, 320))
	Sim.step(1)
	assert_eq(zone.inside_mask, 1, "a dead hero is not tested")
	p1.dead = false
	Sim.step(1)
	assert_eq(zone.inside_mask, 0)
	assert_false(zone.inside)
	assert_false(level.is_camera_locked(), "the last hero out releases it")


func test_a_platform_carries_a_hero_once_per_tick() -> void:
	var level: LevelBase = make_flat_level(40, 16, 10)
	var hero: PlayerBase = _hero(level, 0, Vector2i(100, 160))
	var a: PlatformBase = PlatformBase.new()
	var b: PlatformBase = PlatformBase.new()
	place(level, a, Vector2i(100, 168))
	place(level, b, Vector2i(100, 168))
	Sim.step(1)
	assert_eq(hero.carried_on_tick, -1)
	hero.sim_pos = Vector2i(100, 163)
	Sim.step(1)
	assert_eq(hero.carried_on_tick, Sim.total_ticks, "his own guard")
	assert_true(a.ridden != b.ridden, "one platform per hero per tick")


func test_the_bench_digest_hashes_a_party_but_keeps_a_party_of_one() -> void:
	var runner: Node = (load("res://scripts/core/dev/sim_bench_runner.gd") as GDScript).new()
	var level: LevelBase = make_flat_level(40, 16, 10)
	var p1: PlayerBase = _hero(level, 0, Vector2i(100, 160))
	var solo: String = runner.call("_digest_line", level)
	assert_eq(runner.call("_digest_line", level), solo, "the same state, the same line")
	var p2: PlayerBase = _hero(level, 1, Vector2i(200, 160))
	var party: String = runner.call("_digest_line", level)
	assert_ne(party, solo, "a second hero is hashed")
	p2.sim_pos.x += 1
	assert_ne(runner.call("_digest_line", level), party, "and so is every move of his")
	p2.free()
	assert_eq(runner.call("_digest_line", level), solo, "back to one hero: the 1.0 line")
	assert_eq(p1.slot, 0)
	runner.free()


func test_shared_music_plays_while_any_holder_holds_it() -> void:
	Audio.play_music(Sfx.MUSIC_CAVE, 0.0)
	var a: Node = Node.new()
	var b: Node = Node.new()
	var c: Node = Node.new()
	Audio.hold_music(Sfx.MUSIC_FEAST, a)
	assert_eq(Audio.get_music_context(), Sfx.MUSIC_FEAST)
	Audio.hold_music(Sfx.MUSIC_FEAST, b)
	Audio.hold_music(Sfx.MUSIC_FEAST, a)
	Audio.release_music(Sfx.MUSIC_FEAST, a)
	assert_eq(Audio.get_music_context(), Sfx.MUSIC_FEAST, "b still holds it")
	assert_true(Audio.is_music_held_by(Sfx.MUSIC_FEAST, b))
	assert_false(Audio.is_music_held_by(Sfx.MUSIC_FEAST, a), "holding twice is holding once")
	Audio.release_music(Sfx.MUSIC_FEAST, a)
	assert_eq(Audio.get_music_context(), Sfx.MUSIC_FEAST, "releasing what one does not hold does nothing")
	Audio.release_music(Sfx.MUSIC_FEAST, b)
	assert_eq(Audio.get_music_context(), Sfx.MUSIC_CAVE, "the last holder let go: the level music is back")
	Audio.hold_music(Sfx.MUSIC_FEAST, a)
	Audio.hold_music(Sfx.MUSIC_FEAST, c)
	c.free()
	Audio.release_music(Sfx.MUSIC_FEAST, a)
	assert_eq(Audio.get_music_context(), Sfx.MUSIC_CAVE, "a freed holder holds nothing")
	Audio.hold_music(Sfx.MUSIC_FEAST, a)
	Audio.play_music(Sfx.MUSIC_CAVE, 0.0)
	assert_false(Audio.is_music_held_by(Sfx.MUSIC_FEAST, a), "a new track forgets the holders")
	a.free()
	b.free()


# =================================================================================================================
# Real heroes in a loaded level
# =================================================================================================================

func test_single_player_ignores_the_party_starts() -> void:
	var level: Level = _load_level("objects/hero_start 6 9 slot=2")
	assert_eq(level.hero_count(), 1)
	assert_eq(level.get_kind(Defs.Kind.PLAYER).size(), 1, "no second hero")
	assert_eq(level.player.sim_pos, level.start_pos)
	assert_eq(level.start_positions[0], level.start_pos)
	assert_eq(level.get_start_pos_for(1), LevelText.cell_to_feet(6.0, 9.0), "read, but nobody uses it")


func test_the_loader_spawns_the_party_after_p1_at_its_starts() -> void:
	Game.start_run(Defs.Difficulty.BEGINNER, Defs.GameMode.COOP, 2)
	var level: Level = _load_level("objects/hero_start 6 9 slot=2")
	assert_eq(level.hero_count(), 2)
	var p1: Player = level.player as Player
	var p2: Player = level.get_hero(1) as Player
	assert_not_null(p1)
	assert_not_null(p2)
	assert_eq(level.get_kind(Defs.Kind.PLAYER), [p1, p2] as Array[SimEntity], "P2 registers after P1")
	assert_true(p1._sim_serial < p2._sim_serial, "and ticks after him")
	assert_eq(p2.slot, 1)
	assert_true(p2.run == Game.runs[1])
	assert_eq(p1.sim_pos, level.start_pos)
	assert_eq(p2.sim_pos, LevelText.cell_to_feet(6.0, 9.0), "P2 at his `objects/hero_start slot=2`")
	assert_eq(level.start_positions.size(), Defs.MAX_PLAYERS)
	assert_eq(level.get_start_pos_for(2), level.start_pos + Vector2i(2 * PartyTuning.RESPAWN_SPREAD_PX, 0),
			"no marker: spread from '@'")


func test_two_heroes_play_from_their_own_input_slots() -> void:
	Game.start_run(Defs.Difficulty.BEGINNER, Defs.GameMode.COOP, 2)
	var level: Level = _load_level("objects/hero_start 12 9 slot=2")
	var p1: Player = level.player as Player
	var p2: Player = level.get_hero(1) as Player
	Game.runs[1].set_weapon(Defs.Weapon.AXE)
	var x1: int = p1.sim_pos.x
	var x2: int = p2.sim_pos.x
	GameInput.set_scripted_slot(0, func(_tick: int) -> int: return Defs.IN_RIGHT)
	GameInput.set_scripted_slot(1, func(_tick: int) -> int: return Defs.IN_LEFT)
	Sim.step(10)
	assert_true(p1.sim_pos.x > x1, "P1 walked right on slot 0")
	assert_true(p2.sim_pos.x < x2, "P2 walked left on slot 1")
	assert_eq(p1.facing, 1)
	assert_eq(p2.facing, -1)
	GameInput.set_scripted_slot(0, func(_tick: int) -> int: return 0)
	GameInput.set_scripted_slot(1, func(_tick: int) -> int: return Defs.IN_FIRE)
	var owners: Array[int] = []
	for i: int in 16:
		Sim.step(1)
		for entity: SimEntity in level.get_kind(Defs.Kind.HERO_PROJECTILE):
			var shot: ProjectileBase = entity as ProjectileBase
			if not owners.has(shot.owner_slot):
				owners.append(shot.owner_slot)
	assert_eq(owners, [1] as Array[int], "P2 threw his own axe; P1 has the club and threw nothing")
	assert_eq(Game.weapon, Defs.Weapon.CLUB, "P1's hand is his own")


func test_party_feasts_share_the_music_and_deaths_wait_for_the_team() -> void:
	Game.start_run(Defs.Difficulty.BEGINNER, Defs.GameMode.COOP, 2)
	var level: Level = _load_level("objects/hero_start 12 9 slot=2")
	var p1: Player = level.player as Player
	var p2: Player = level.get_hero(1) as Player
	var music: StringName = Audio.get_music_context()
	p2.start_feast(40)
	assert_eq(Audio.get_music_context(), Sfx.MUSIC_FEAST)
	p1.start_feast(40)
	p2.start_feast(0)
	assert_eq(Audio.get_music_context(), Sfx.MUSIC_FEAST, "P1 still feasts")
	p1.start_feast(0)
	assert_eq(Audio.get_music_context(), music, "the level music is back")
	p2.kill(&"pit")
	Sim.step(Tuning.DEATH_ANIM_TICKS + 2)
	assert_true(p2.dead, "his toss is over; he waits while P1 plays")
	assert_eq(Game.lives, Tuning.LIVES_START)
	p1.kill(&"pit")
	Sim.step(Tuning.DEATH_ANIM_TICKS + 2)
	assert_eq(Game.lives, Tuning.LIVES_START - 1, "the team wipe costs one life")
	assert_false(p1.dead)
	assert_false(p2.dead)
	assert_eq(p1.sim_pos, level.start_pos)
	assert_eq(p2.sim_pos, level.get_respawn_pos_for(1))
