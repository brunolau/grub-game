extends "res://tests/test_enemies_case.gd"
## The world 5 enemies pulled into phase 1 (PLAN.md P1.8 / P2.1; GAMEPLAY.md 13.5, DESIGN.md A.5) on art-B's sheets:
## the Roller (archetype 13), the Guard (archetype 14) and its co-op preset the Shellback, and the rattler in a hole
## (`enemies/snapper skin=snake`); their EnemyTuning rows and skins, and the module's level levels/test_enemies_canyon.lvl.

const CANYON_LEVEL: String = "res://levels/test_enemies_canyon.lvl"


func after_each() -> void:
	Game.new_game(Defs.Difficulty.BEGINNER)
	Game.begin_level(&"")


# =================================================================================================================
# Roller
# =================================================================================================================

func test_roller_walks_then_curls_and_rolls_at_the_hero() -> void:
	_level.view = Rect2i(0, 0, 2 * Tuning.VIEW_W, Tuning.VIEW_H)
	var roller: Roller = _enemy(&"enemies/roller", Vector2i(300, 160)) as Roller
	assert_eq(roller.skin, "roller")
	assert_eq(roller.score_index, EnemyTuning.SCORE_ROLLER)
	assert_eq((_enemy(&"enemies/roller", Vector2i(600, 160), {"score": 7}) as Roller).score_index, 7, "a level's score")
	assert_eq(Vector2i(roller.box_w, roller.box_h), Vector2i(54, 24), "the walking body box of the sheet")
	assert_eq([roller.range_tiles, roller.roll_speed, roller.dizzy_ticks],
			[EnemyTuning.ROLLER_RANGE_TILES, EnemyTuning.ROLLER_SPEED, EnemyTuning.ROLLER_DIZZY_TICKS])
	var fastest: int = 0
	for tick: int in 60:
		Sim.step(1)
		fastest = maxi(fastest, absi(roller.xvel))
		assert_eq(roller.get_state(), Roller.State.WALK, "the hero is 16 tiles away")
		assert_true(roller.sim_pos.x >= 300 - 4 * 16 and roller.sim_pos.x <= 300 + 4 * 16, "between its limits")
	assert_eq(fastest, EnemyTuning.ROLLER_WALK_SPEED, "it patrols at 32 v16")
	_hero.teleport(Vector2i(roller.sim_pos.x - 5 * 16, 160))
	Sim.step(1)
	assert_eq(roller.get_state(), Roller.State.CURL, "the hero within 6 tiles: it curls")
	assert_eq(roller.facing, -1)
	assert_eq(Vector2i(roller.box_w, roller.box_h), Vector2i(29, 26), "the ball's box")
	var at: int = roller.sim_pos.x
	assert_true(roller.take_hit(25, _hero), "a hit on the ball is used up ...")
	assert_eq(roller.hp, 25, "... and glances")
	Sim.step(EnemyTuning.ROLLER_CURL_TICKS - 1)
	assert_eq(roller.get_state(), Roller.State.CURL, "a 14-tick tuck ...")
	assert_eq(roller.sim_pos.x, at, "... without motion")
	Sim.step(1)
	assert_eq(roller.get_state(), Roller.State.ROLL)
	assert_eq(roller.xvel, -EnemyTuning.ROLLER_SPEED, "it rolls at the hero")
	Sim.step(5)
	assert_eq(roller.sim_pos.x, at - 5 * 4, "4 px per tick")
	roller.take_hit(25, _hero)
	assert_eq(roller.hp, 25, "rolling, hits glance")


func test_roller_speeds_up_down_a_slope_and_is_dizzy_after_a_wall() -> void:
	var records: Dictionary = _load_canyon()
	var roller: Roller = records["R"]
	_hero.teleport(Vector2i(roller.sim_pos.x + 5 * 16, roller.sim_pos.y))
	var states: Array[int] = []
	var fastest: int = 0
	var dizzy_at: int = -1
	for tick: int in 200:
		Sim.step(1)
		fastest = maxi(fastest, absi(roller.xvel))
		if roller.get_state() == Roller.State.DIZZY and dizzy_at < 0:
			dizzy_at = tick
			assert_eq(roller.xvel, 0, "the wall stops it")
			assert_true(roller.sim_pos.x < 34 * 16, "in front of the wall")
		if states.is_empty() or states.back() != roller.get_state():
			states.append(roller.get_state())
		if roller.get_state() == Roller.State.WALK and dizzy_at >= 0:
			break
	assert_eq(states, [Roller.State.WALK, Roller.State.CURL, Roller.State.ROLL, Roller.State.DIZZY,
			Roller.State.UNCURL, Roller.State.WALK] as Array[int], "walk, curl, roll, dizzy, uncurl, walk")
	assert_true(fastest > EnemyTuning.ROLLER_SPEED, "faster down the slope (%d v16)" % fastest)
	assert_true(fastest <= EnemyTuning.ROLLER_SPEED_CAP, "at most 96 v16")
	assert_eq(roller.sim_pos.y, 192, "it followed the slope down to the floor")


func test_roller_is_hittable_while_dizzy_and_walks_again() -> void:
	var records: Dictionary = _load_canyon()
	var roller: Roller = records["R"]
	_hero.teleport(Vector2i(roller.sim_pos.x + 5 * 16, roller.sim_pos.y))
	var waited: int = 0
	while roller.get_state() != Roller.State.DIZZY and waited < 200:
		Sim.step(1)
		waited += 1
	assert_eq(roller.get_state(), Roller.State.DIZZY)
	_hero.teleport(roller.sim_pos + Vector2i(-20, 0))
	assert_true(roller.take_hit(25, _hero))
	assert_eq(roller.hp, 0, "dizzy, it can be hurt")
	var dizzy: int = 0
	while roller.get_state() == Roller.State.DIZZY and dizzy < 100:
		Sim.step(1)
		dizzy += 1
	assert_eq(dizzy, EnemyTuning.ROLLER_DIZZY_TICKS, "dizzy for 33 ticks")
	assert_eq(roller.get_state(), Roller.State.UNCURL)
	Sim.step(EnemyTuning.ROLLER_UNCURL_TICKS)
	assert_eq(roller.get_state(), Roller.State.WALK, "then it uncurls in 8 ticks and walks")
	assert_eq(Vector2i(roller.box_w, roller.box_h), Vector2i(54, 24))


func test_roller_uncurls_by_itself_and_sinks_in_a_liquid() -> void:
	var roller: Roller = _enemy(&"enemies/roller", Vector2i(100, 160)) as Roller
	_hero.teleport(Vector2i(180, 160))
	var rolled: int = 0
	for tick: int in 400:
		Sim.step(1)
		_level.view = Rect2i(roller.sim_pos.x - 160, 0, Tuning.VIEW_W, Tuning.VIEW_H)
		_hero.teleport(Vector2i(roller.sim_pos.x + 40, 160))
		if roller.get_state() == Roller.State.ROLL:
			rolled += 1
		elif rolled > 0:
			break
	assert_eq(rolled, EnemyTuning.ROLLER_ROLL_MAX_TICKS, "after 154 ticks of rolling it uncurls by itself")
	assert_eq(roller.get_state(), Roller.State.UNCURL)
	var rows: PackedStringArray = PackedStringArray()
	for row: int in 16:
		rows.append(".".repeat(60) if row < 10 else "#".repeat(20) + "~~~~" + "#".repeat(36))
	_rows_level(rows)
	var diver: Roller = _enemy(&"enemies/roller", Vector2i(250, 160)) as Roller
	_hero.teleport(Vector2i(330, 160))
	var gone: int = -1
	for tick: int in 120:
		Sim.step(1)
		if not diver.awake:
			gone = tick
			break
	assert_true(gone > 0, "it rolled into the liquid and is gone")
	assert_eq(diver.sim_pos, Vector2i(250, 160), "back at its anchor, asleep")
	assert_false(diver.dead, "without points: it returns later")


# =================================================================================================================
# Guard and Shellback
# =================================================================================================================

func test_guard_patrols_and_turns_its_shield_only_on_its_own_clock() -> void:
	var guard: Guard = _enemy(&"enemies/guard", Vector2i(200, 160), {"left": -4, "right": 4}) as Guard
	assert_eq(Vector2i(guard.box_w, guard.box_h), Vector2i(76, 54), "54 px tall: Guard halls are 4 rows high")
	assert_eq(guard.turn, EnemyTuning.GUARD_TURN_TICKS)
	_hero.teleport(Vector2i(100, 160))
	Sim.step(1)
	assert_eq(guard.get_shield_dir(), -1, "it wakes facing the hero")
	_hero.teleport(Vector2i(320, 160))
	var turned: int = -1
	var fastest: int = 0
	for tick: int in 2 * EnemyTuning.GUARD_TURN_TICKS:
		Sim.step(1)
		fastest = maxi(fastest, absi(guard.xvel))
		assert_eq(guard.facing, guard.get_shield_dir(), "the picture faces the shield, not the walk")
		if guard.get_shield_dir() == 1:
			turned = tick + 1
			break
	assert_eq(turned, EnemyTuning.GUARD_TURN_TICKS, "it turns only when its 33-tick clock comes round")
	assert_true(fastest <= EnemyTuning.GUARD_SPEED and fastest > 0, "it patrols at 24 v16 (%d)" % fastest)


func test_guard_front_hits_glance_and_hits_from_behind_count() -> void:
	var guard: Guard = _enemy(&"enemies/guard", Vector2i(200, 160), {"speed": 0, "hp": 100}) as Guard
	_hero.teleport(Vector2i(140, 160))
	Sim.step(2)
	assert_eq(guard.facing, -1)
	var sparks: int = _count_fx(&"fx/hit_stars")
	assert_true(guard.take_hit(25, _hero))
	assert_eq(guard.hp, 100, "a strike into the shield glances")
	assert_eq(_count_fx(&"fx/hit_stars"), sparks + 1, "with a spark")
	Sim.step(1)
	assert_eq(guard._anim_role, &"guard", "and the raised shield")
	_hero.teleport(Vector2i(250, 160))
	guard.take_hit(25, _hero)
	assert_eq(guard.hp, 75, "the hero behind it (before it turns) hits")
	_hero.teleport(Vector2i(203, 160))
	guard.take_hit(25, _hero)
	assert_eq(guard.hp, 75, "within 4 px of its feet is the front")
	var into_face: ProjectileBase = _shot(Vector2i(150, 150), 208)
	guard.take_hit(20, into_face)
	assert_eq(guard.hp, 75, "a throw into its face glances")
	var at_back: ProjectileBase = _shot(Vector2i(250, 150), -208)
	guard.take_hit(20, at_back)
	assert_eq(guard.hp, 55, "a throw from behind counts")
	assert_eq(guard.score_index, EnemyTuning.SCORE_GUARD)


func test_a_shellback_is_a_guard_alone_and_turns_every_tick_in_a_coop_party() -> void:
	var alone: Guard = _enemy(&"enemies/shellback", Vector2i(200, 160), {"speed": 0}) as Guard
	assert_eq(alone.skin, "shellback")
	assert_eq(alone.coop_traits().kind, Defs.CoopTrait.SHELL, "the preset carries the shell trait")
	_hero.teleport(Vector2i(140, 160))
	Sim.step(2)
	_hero.teleport(Vector2i(260, 160))
	Sim.step(3)
	assert_eq(alone.facing, -1, "single-player: it turns on its 33-tick clock like any Guard")
	Game.start_run(Defs.Difficulty.BEGINNER, Defs.GameMode.COOP, 2)
	Game.begin_level(&"test")
	_flat_level(60, 16, 10)
	var shellback: Guard = _enemy(&"enemies/shellback", Vector2i(200, 160), {"speed": 0}) as Guard
	var p2: PlayerBase = PlayerBase.new()
	place(_level, p2, Vector2i(300, 160), {"slot": 1})
	_hero.teleport(Vector2i(140, 160))
	Sim.step(2)
	assert_eq(shellback.facing, -1, "the shield faces the nearer hero")
	_hero.teleport(Vector2i(60, 160))
	Sim.step(1)
	assert_eq(shellback.facing, 1, "and turns to the other one on the very next tick")
	shellback.take_hit(25, p2)
	assert_eq(shellback.hp, 25, "P2 is in front")
	shellback.take_hit(25, _hero)
	assert_eq(shellback.hp, 0, "P1 hits its back")
	var plain: Guard = _enemy(&"enemies/shellback", Vector2i(400, 160), {"coop": "bond", "bond": "x"}) as Guard
	assert_eq(plain.coop_traits().kind, Defs.CoopTrait.BOND, "a level's coop= replaces the preset's trait")


# =================================================================================================================
# The rattler
# =================================================================================================================

func test_the_rattler_is_the_snapper_on_the_snake_sheet() -> void:
	var rattler: Snapper = _enemy(&"enemies/snapper", Vector2i(200, 160), {"skin": "snake"}) as Snapper
	assert_eq(rattler.skin, "snake")
	assert_eq(rattler.reach, EnemyTuning.RATTLER_RANGE, "its shorter bite")
	assert_eq(Vector2i(rattler.box_w, rattler.box_h), Vector2i(38, 30))
	var explicit: Snapper = _enemy(&"enemies/snapper", Vector2i(400, 160), {"skin": "snake_b", "range": 50}) as Snapper
	assert_eq(explicit.reach, 50, "a level's range wins")
	var plant: Snapper = _enemy(&"enemies/snapper", Vector2i(600, 160)) as Snapper
	assert_eq(plant.reach, EnemyTuning.SNAPPER_RANGE, "the plant keeps its reach")
	_hero.teleport(Vector2i(200 - EnemyTuning.RATTLER_RANGE + 4, 160))
	var bitten: int = -1
	var widest: int = 0
	for tick: int in 40:
		Sim.step(1)
		widest = maxi(widest, rattler.get_bite_rect().size.x)
		if Game.hearts < Tuning.ENERGY_START:
			bitten = tick
			break
	assert_true(bitten > 0, "it bites the hero in front of its hole")
	assert_eq(widest, EnemyTuning.RATTLER_RANGE)
	var sprite: Sprite2D = rattler.get_node(^"Sprite")
	assert_eq(sprite.texture.resource_path, EnemySkin.ENEMY_DIR + "snake.png")
	assert_true(sprite.frame >= 7 and sprite.frame <= 9, "on its bite frames (%d)" % sprite.frame)


func test_the_canyon_level_names_the_world_5_enemies() -> void:
	var records: Dictionary = _load_canyon()
	assert_true(records["R"] is Roller)
	assert_true(records["G"] is Guard)
	assert_true(records["K"] is Shellback)
	assert_eq((records["N"] as EnemyBase).skin, "snake")
	assert_eq(_level.grid.get_char(48, 7), TileGrid.CH_SOLID_A, "the Guard's hall has a roof ...")
	for row: int in range(8, 12):
		assert_eq(_level.grid.get_char(48, row), TileGrid.CH_AIR, "... over 4 rows of air (row %d)" % row)
	Sim.step(60)
	for key: String in records:
		assert_false((records[key] as EnemyBase).dead, "%s lives" % key)


# =================================================================================================================
# Helpers
# =================================================================================================================

## The records of levels/test_enemies_canyon.lvl by legend letter, spawned into a bare level of its tiles (the whole
## level in view); P1 at '@'.
func _load_canyon() -> Dictionary:
	var sections: Dictionary = LevelText.split_sections(FileAccess.get_file_as_string(CANYON_LEVEL))
	var legend: Dictionary = LevelText.parse_legend(sections.get("legend", PackedStringArray()))
	var rows: PackedStringArray = sections.get("tiles", PackedStringArray())
	_rows_level(rows)
	_level.view = Rect2i(0, 0, rows[0].length() * Tuning.TILE, rows.size() * Tuning.TILE)
	var records: Dictionary = {}
	for row: int in rows.size():
		for col: int in rows[row].length():
			var key: String = rows[row][col]
			if key == TileGrid.CH_PLAYER_START:
				_hero.teleport(LevelText.cell_to_feet(col, row))
			if not legend.has(key) or Spawner.category(legend[key]["id"]) != "enemies":
				continue
			var params: Dictionary = (legend[key]["params"] as Dictionary).duplicate()
			records[key] = _enemy(legend[key]["id"], LevelText.cell_to_feet(col, row, params), params)
	return records


func _shot(pos: Vector2i, p_xvel: int) -> ProjectileBase:
	var shot: ProjectileBase = ProjectileBase.new()
	place(_level, shot, pos, {"from_hero": true, "power": 20, "xvel": p_xvel})
	return shot


func _count_fx(id: StringName) -> int:
	var count: int = 0
	for entity: SimEntity in _level.get_kind(Defs.Kind.FX):
		if entity.scene_file_path.get_file().get_basename() == String(id).get_file():
			count += 1
	return count
