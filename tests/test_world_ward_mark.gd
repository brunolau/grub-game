extends TestCase
## THE WARD MARK (phase 4 ruling Q2, docs/expansion/DESIGN.md G85) on real enemies in levels loaded by the world module:
## in a level a co-op party plays, every enemy a hero could come down on wears chalk war paint while its FEET column is
## in the ward of an x2 tablet (LevelBase.ward_marks, EnemyBase.is_ward_marked, fx/WardMark) - and never in solo play.
## It is a picture: the same world played with the mark and without it is the same world on every tick.

const LEVEL_SCENE: String = "res://scenes/world/level.tscn"
const BASE_VIEW: Vector2i = Vector2i(640, 360)
## 64 x 14 cells, ground from row 12: '@' at column 4, P2's start at column 6. The tablet at column 12 wards the
## columns 10 .. 15 (`far` one cell on, 2 cells of margin): all inside the first view.
const LEVEL_TEXT: String = """[meta]
format = 2
id = test_world_ward_mark_inline
kind = test
biome = canyon
terrain_a = canyon/terrain
terrain_b = canyon/terrain_mesa
background = canyon
music = level_cave
[legend]
[tiles]
%s
[entities]
objects/hero_start 6 11 slot=2
objects/x2_tablet 12 11 gate=mark far=13,11 ward=2,2
%s
"""
const COLS: int = 64
const ROWS: int = 14
const FLOOR_Y: int = 12 * 16
const WARD_FIRST_X: int = 10 * 16
const WARD_LAST_X: int = 15 * 16 + 15
## A walker that stands still inside the ward (column 13) and one outside it (column 18), both on the first view.
const TWO_WALKERS: String = "enemies/walker 13 11 speed=0\nenemies/walker 18 11 speed=0"

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


func _load(party: int, entity_lines: String = TWO_WALKERS) -> Level:
	if party > 1:
		Game.start_run(Defs.Difficulty.BEGINNER, Defs.GameMode.COOP, party)
	else:
		Game.start_run(Defs.Difficulty.BEGINNER)
	Sim.manual = true
	Game.begin_level(&"test_world_ward_mark_inline")
	var lines: PackedStringArray = PackedStringArray()
	for row: int in ROWS:
		var line: String = (TileGrid.CH_SOLID_A if row >= 12 else TileGrid.CH_AIR).repeat(COLS)
		if row == 11:
			line = line.substr(0, 4) + TileGrid.CH_PLAYER_START + line.substr(5)
		lines.append(line)
	var level: Level = (load(LEVEL_SCENE) as PackedScene).instantiate() as Level
	level.setup_from_text(&"test_world_ward_mark_inline", LEVEL_TEXT % ["\n".join(lines), entity_lines])
	add_node(level)
	level.set_view_size(BASE_VIEW)
	Sim.tick = 0
	Sim.rng.reseed(7)
	return level


func _unload(level: Level) -> void:
	GameInput.clear_scripted()
	Sim.stop()
	level.free()


## The awake enemies of `level`, left to right.
func _enemies(level: Level) -> Array[EnemyBase]:
	var found: Array[EnemyBase] = []
	for entity: SimEntity in level.get_kind(Defs.Kind.ENEMY):
		var enemy: EnemyBase = entity as EnemyBase
		if enemy != null and enemy.awake:
			found.append(enemy)
	found.sort_custom(func(a: EnemyBase, b: EnemyBase) -> bool: return a.sim_pos.x < b.sim_pos.x)
	return found


func _sprite_of(enemy: EnemyBase) -> Sprite2D:
	return enemy.get_node_or_null(^"Sprite") as Sprite2D


# =================================================================================================================
# Who wears it, and when
# =================================================================================================================

func test_enemies_in_a_ward_wear_the_mark_for_a_coop_party_and_never_in_solo_play() -> void:
	for party: int in [2, 1]:
		var what: String = "a co-op party" if party > 1 else "solo"
		var level: Level = _load(party)
		Sim.step(3)
		assert_eq(level.get_wards(), [Vector2i(10, 15)] as Array[Vector2i], what + ": the set-up - the tablet's ward")
		assert_eq(level.ward_marks, party > 1, what + ": only the level of a co-op party shows ward marks")
		var enemies: Array[EnemyBase] = _enemies(level)
		assert_eq(enemies.size(), 2, what + ": the set-up - both walkers are awake on the view")
		if enemies.size() == 2:
			var inside: EnemyBase = enemies[0]
			var outside: EnemyBase = enemies[1]
			assert_true(level.in_ward(inside.sim_pos.x) and not level.in_ward(outside.sim_pos.x), what + ": the set-up")
			assert_true(inside.wears_ward_mark() and outside.wears_ward_mark(), what + ": both are enemies a hero could stomp")
			assert_eq(inside.is_ward_marked(), party > 1, what + ": the enemy in the ward")
			assert_false(outside.is_ward_marked(), what + ": the enemy outside the ward is never marked")
			if party > 1:
				assert_true(_sprite_of(inside).material == WardMark.material(),
						what + ": the mark is the one shared material on its own sprite")
			else:
				assert_null(_sprite_of(inside).material, what + ": its sprite is the 1.0 sprite - no material")
			assert_null(_sprite_of(outside).material, what + ": no material on an unmarked enemy")
		_unload(level)


func test_the_mark_goes_on_and_off_at_the_edge_of_the_ward_and_needs_no_hero_near() -> void:
	var level: Level = _load(2)
	Sim.step(3)
	var enemy: EnemyBase = _enemies(level)[0]
	var heroes_at: Array[Vector2i] = [level.player.sim_pos, level.get_hero(1).sim_pos]
	for step: Array in [[WARD_FIRST_X - 1, false, "one px left of the ward"], [WARD_FIRST_X, true, "its first px"],
			[WARD_LAST_X, true, "its last px"], [WARD_LAST_X + 1, false, "one px right of it"],
			[13 * 16 + 8, true, "back in the middle"]]:
		enemy.teleport(Vector2i(int(step[0]), FLOOR_Y))
		Sim.step(1)
		assert_eq(enemy.is_ward_marked(), bool(step[1]), "its feet point at x %d (%s)" % [int(step[0]), str(step[2])])
		assert_eq(_sprite_of(enemy).material != null, bool(step[1]), "... and the material follows")
	assert_eq([level.player.sim_pos, level.get_hero(1).sim_pos], heroes_at, "the heroes stood 100 px away the whole time")
	assert_false(level.in_ward(level.player.sim_pos.x) or level.in_ward(level.get_hero(1).sim_pos.x),
			"... outside the ward: the mark is the ENEMY's column, whatever the heroes do")


func test_only_an_enemy_a_hero_could_stomp_wears_it() -> void:
	var level: Level = _load(2, TWO_WALKERS + "\nenemies/decoration 11 11 prop=jungle/fern")
	Sim.step(3)
	var enemy: EnemyBase = _enemies(level)[0]
	assert_true(enemy.is_ward_marked(), "the set-up: marked")
	for entity: SimEntity in level.get_kind(Defs.Kind.ENEMY):
		var prop: EnemyBase = entity as EnemyBase
		if prop != null and not prop.contact_hurts:
			assert_true(level.in_ward(prop.sim_pos.x), "the set-up: a decoration inside the ward")
			assert_false(prop.wears_ward_mark() or prop.is_ward_marked(), "a decoration is no beast: never marked")
	# Not touchable now (a hanging lurker, a digger under the ground): nothing to come down on, no mark.
	enemy.tangible = false
	Sim.step(1)
	assert_false(enemy.is_ward_marked(), "an enemy that cannot be touched now wears none")
	enemy.tangible = true
	Sim.step(1)
	assert_true(enemy.is_ward_marked(), "... and wears it again when it can")
	# A feasting hero turns it into food: the food is no marked beast.
	level.player.start_feast(40)
	Sim.step(1)
	assert_false(enemy.is_ward_marked(), "drawn as feast food: no mark")
	level.player.start_feast(0)
	Sim.step(2)
	assert_true(enemy.is_ward_marked(), "the feast over: marked again")
	# Killed: the corpse that flies off the screen is no stepping stone and wears nothing.
	enemy.kill(&"club", level.player)
	Sim.step(1)
	assert_false(enemy.is_ward_marked(), "a dead enemy wears none")
	assert_null(_sprite_of(enemy).material, "... its corpse is drawn plain")
	# A boss's body is covered by no ward (G73): the query says no whatever its place.
	var boss: BossBase = BossBase.new()
	boss.awake = true
	assert_false(boss.wears_ward_mark(), "a boss is not an enemy of the contact pass: never marked")
	boss.free()
	# The search's and the validator's world never set the switch.
	var bare: LevelBase = LevelBase.new()
	assert_false(bare.ward_marks, "a level is marked only when the game's Level says so (a co-op party)")
	bare.free()


# =================================================================================================================
# It is a picture
# =================================================================================================================

## What the simulation holds after a tick: every hero and every enemy record, the score and the random state.
func _state(level: Level) -> Array:
	var row: Array = [Sim.rng.get_state(), Game.score, Game.lives]
	for hero: PlayerBase in level.contact_order():
		row.append([hero.sim_pos, hero.xvel, hero.yvel, hero.state, hero.hit_timer, hero.run.hearts, hero.grounded,
				hero.dead, hero.down])
	for entity: SimEntity in level.get_kind(Defs.Kind.ENEMY):
		var enemy: EnemyBase = entity as EnemyBase
		if enemy != null:
			row.append([enemy.sim_pos, enemy.xvel, enemy.yvel, enemy.hp, enemy.awake, enemy.dead, enemy.bounce_count,
					enemy.facing, enemy.flash, enemy.on_screen])
	return row


## 200 ticks of a pair in the ward: P1 walks into the ward, jumps on the heads of two walkers there and strikes; P2
## follows and jumps. Returns the state after every tick and how many enemy-ticks were drawn marked.
func _play(marks: bool) -> Dictionary:
	var level: Level = _load(2, "enemies/walker 11 11\nenemies/walker 14 11 hp=200\nenemies/walker 18 11\nenemies/hopper 22 11")
	level.ward_marks = marks
	var p1: PackedInt32Array = PackedInt32Array()
	var p2: PackedInt32Array = PackedInt32Array()
	for run: Array in [[30, "R", ""], [8, "RU", "R"], [20, "R", "R"], [10, "F", "RU"], [12, "RU", "R"], [20, "R", "F"],
			[14, "LU", "R"], [20, "L", "RU"], [16, "F", "R"], [50, "R", "L"]]:
		for i: int in int(run[0]):
			p1.append(GameInput.keys_to_flags(str(run[1])))
			p2.append(GameInput.keys_to_flags(str(run[2])))
	var first: int = Sim.tick + 1
	GameInput.set_scripted_slot(0, func(tick: int) -> int:
		return p1[tick - first] if tick >= first and tick - first < p1.size() else 0)
	GameInput.set_scripted_slot(1, func(tick: int) -> int:
		return p2[tick - first] if tick >= first and tick - first < p2.size() else 0)
	var states: Array = []
	var marked: int = 0
	var stomps: int = 0
	for i: int in p1.size():
		Sim.step(1)
		states.append(_state(level))
		for entity: SimEntity in level.get_kind(Defs.Kind.ENEMY):
			var enemy: EnemyBase = entity as EnemyBase
			if enemy != null:
				marked += 1 if enemy.is_ward_marked() else 0
				stomps = maxi(stomps, enemy.bounce_count)
	_unload(level)
	return {"states": states, "marked": marked, "stomps": stomps}


func test_the_mark_changes_no_tick() -> void:
	var with_marks: Dictionary = _play(true)
	var without: Dictionary = _play(false)
	assert_true(int(with_marks["marked"]) > 100, "the set-up: enemies were drawn marked on %d enemy-ticks" % int(with_marks["marked"]))
	assert_eq(without["marked"], 0, "the set-up: the second run drew no mark")
	assert_true(int(with_marks["stomps"]) >= 1, "the set-up: a head in the ward was stomped (the rule the mark shows ran)")
	var states: Array = with_marks["states"]
	var plain: Array = without["states"]
	assert_eq(states.size(), plain.size())
	var first_difference: int = -1
	for i: int in mini(states.size(), plain.size()):
		if states[i] != plain[i]:
			first_difference = i + 1
			break
	assert_eq(first_difference, -1, "heroes, enemies, score and random state are the same on every one of %d ticks" % states.size())


func test_every_marked_enemy_shares_one_material_and_the_bands_are_chalk_between_ink() -> void:
	assert_true(WardMark.material() == WardMark.material(), "one material, made once")
	var level: Level = _load(2, "enemies/walker 11 11 speed=0\nenemies/walker 14 11 speed=0 skin=mini_rex")
	Sim.step(3)
	var enemies: Array[EnemyBase] = _enemies(level)
	assert_eq(enemies.size(), 2)
	if enemies.size() == 2:
		assert_true(enemies[0].is_ward_marked() and enemies[1].is_ward_marked(), "the set-up: two marked enemies of two sheets")
		assert_true(_sprite_of(enemies[0]).material == _sprite_of(enemies[1]).material,
				"they share the material (no per-entity material, ARCHITECTURE.md 11)")
		assert_eq(enemies[0].get_child_count(), enemies[1].get_child_count(), "the mark adds no node")
	# The CPU twin of the shader: along a row a band is ink, chalk, ink, then the sheet's own colour up to the next band.
	var row: Array[int] = []
	for x: int in WardMark.BAND_PERIOD * 2:
		row.append(WardMark.paint_at(Vector2i(x - WardMark.BAND_SHIFT, 0)))
	var band: Array[int] = []
	for i: int in WardMark.EDGE_PX:
		band.append(1)
	for i: int in WardMark.CHALK_PX:
		band.append(2)
	for i: int in WardMark.EDGE_PX:
		band.append(1)
	while band.size() < WardMark.BAND_PERIOD:
		band.append(0)
	assert_eq(row, band + band, "one band per BAND_PERIOD art px: ink, chalk, ink")
	assert_true(WardMark.CHALK_PX >= 4 and WardMark.EDGE_PX >= 1, "wide enough to be seen at 640 x 360: %d px of chalk, %d of ink"
			% [WardMark.CHALK_PX, WardMark.EDGE_PX])
	for at: Vector2i in [Vector2i(0, 0), Vector2i(5, -9), Vector2i(-17, -40), Vector2i(23, -3)]:
		assert_eq(WardMark.paint_at(at + Vector2i(1, -1)), WardMark.paint_at(at), "the bands are slanted: one px up per px right")
