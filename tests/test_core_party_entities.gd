extends ObjectsTestCase
## The entities of a party (docs/expansion/TECH_AUDIT.md 3.8-3.12, PLAN.md P0.6 part B): enemies, bosses, enemy shots,
## items, hazards, checkpoints, platforms, springs, gates and columns meet every hero of the party through the
## PlayerSet of LevelBase (target / every idioms), and each hero's pick-ups go to his own run. No party RULES are
## tested here (eggs, team exit, party travel): only that nothing is limited to P1 any more. That a party of one is
## the 1.0 game is proven by the route digests (tools/sp_identity.sh) and tests/test_core_player_set.gd.


func before_each() -> void:
	super.before_each()
	Game.start_run(Defs.Difficulty.BEGINNER, Defs.GameMode.COOP, 2)
	Game.begin_level(&"test_objects")


func after_each() -> void:
	super.after_each()
	Game.new_game(Defs.Difficulty.BEGINNER)
	Game.begin_level(&"")


## P2: a bare hero (no controller) of player slot 1 standing at `pos`.
func _add_p2(pos: Vector2i) -> PlayerBase:
	var p2: PlayerBase = PlayerBase.new()
	place(level, p2, pos, {"slot": 1})
	p2.respawn_at(pos)
	return p2


# =================================================================================================================
# Enemies and bosses
# =================================================================================================================

func test_enemies_target_sleep_and_feast_by_every_hero() -> void:
	make_ground_level(240, 16, 10)
	var p1: PlayerBase = add_hero(Vector2i(100, 160))
	var p2: PlayerBase = _add_p2(Vector2i(3000, 160))
	assert_eq(level.hero_count(), 2)
	var enemy: EnemyBase = EnemyBase.new()
	place(level, enemy, Vector2i(2900, 160))
	enemy.wake()
	enemy.on_screen = false
	assert_eq(enemy._target_hero(), p2, "the nearest hero")
	assert_false(enemy._should_sleep(), "P2 is near: it stays awake although P1 is far")
	p2.teleport(Vector2i(160, 160))
	assert_true(enemy._should_sleep(), "far from every hero")
	assert_eq(enemy._target_hero(), p2)
	p2.dead = true
	assert_eq(enemy._target_hero(), p1, "a dead hero is no target")
	p2.dead = false
	assert_false(enemy._shows_food())
	p2.feast = 10
	assert_true(enemy._shows_food(), "P2's feast makes it food")
	p2.feast = 0
	enemy.kill(&"weapon", p2)
	assert_eq(Game.runs[1].kills, 1, "the kill counts for P2")
	assert_eq(Game.runs[0].kills, 0)


func test_a_boss_takes_the_club_of_any_hero_and_shots_hit_any_hero() -> void:
	make_ground_level(48, 16, 10)
	var p1: PlayerBase = add_hero(Vector2i(40, 160))
	var p2: PlayerBase = _add_p2(Vector2i(300, 160))
	var boss: BossBase = BossBase.new()
	place(level, boss, Vector2i(320, 160))
	boss.fighting = true
	var weak: Rect2i = Rect2i(300, 120, 32, 16)
	p1.yvel = 10
	p2.yvel = 10
	p2.club_box_active = true
	p2.club_box = Rect2i(310, 124, 8, 8)
	p2.club_power = 9
	assert_eq(boss.poll_weapon_hit(weak), 9, "P2's club box counts")
	assert_eq(p2.yvel, Tuning.POGO_YVEL, "and he pogos")
	assert_eq(p1.yvel, 10, "P1 does not")
	var shot: ProjectileBase = ProjectileBase.new()
	place(level, shot, Vector2i(300, 160))
	var hearts: int = Game.runs[1].hearts
	Sim.step(1)
	assert_true(shot.spent, "an enemy shot hits P2 too")
	assert_true(p2.hit_timer > 0)
	assert_eq(Game.runs[1].hearts, hearts - 1, "from his own hearts")
	assert_eq(p1.hit_timer, 0)
	assert_eq(Game.hearts, Tuning.ENERGY_START, "P1's hearts stay")


# =================================================================================================================
# Items, hazards, checkpoints
# =================================================================================================================

func test_every_hero_collects_into_his_own_run() -> void:
	make_ground_level(48, 16, 10)
	add_hero(Vector2i(40, 160))
	_add_p2(Vector2i(300, 160))
	Game.runs[1].hearts = 1
	Game.runs[1].bones = 0
	spawn(&"items/heart", Vector2i(300, 160))
	Sim.step(1)
	assert_eq(Game.runs[1].hearts, 2, "P2 took the heart")
	assert_eq(Game.runs[1].picked, 1)
	assert_eq(Game.hearts, Tuning.ENERGY_START)
	assert_eq(Game.runs[0].picked, 0)
	spawn(&"items/weapon", Vector2i(300, 160), {"kind": "axe"})
	Sim.step(1)
	assert_eq(Game.runs[1].weapon, Defs.Weapon.AXE, "P2's weapon")
	assert_eq(Game.weapon, Defs.Weapon.CLUB, "not P1's")
	spawn(&"items/glider", Vector2i(300, 160))
	Sim.step(1)
	assert_true(Game.runs[1].has_glider)
	assert_false(Game.has_glider)


func test_hazards_and_checkpoints_meet_every_hero() -> void:
	make_ground_level(48, 16, 10)
	var p1: PlayerBase = add_hero(Vector2i(40, 160))
	var p2: PlayerBase = _add_p2(Vector2i(300, 160))
	var thorn: HazardBase = HazardBase.new()
	place(level, thorn, Vector2i(300, 160))
	Sim.step(1)
	assert_true(p2.hit_timer > 0, "the hazard hurts P2")
	assert_eq(p1.hit_timer, 0)
	thorn.armed = false
	var checkpoint: Checkpoint = spawn(&"objects/checkpoint", Vector2i(300, 160)) as Checkpoint
	Sim.step(1)
	assert_true(checkpoint.active, "P2 lights the team's checkpoint")
	assert_eq(Game.checkpoint_pos, p2.sim_pos)


# =================================================================================================================
# Platforms, springs, gates, columns
# =================================================================================================================

func test_platforms_and_springs_carry_and_launch_every_hero() -> void:
	make_ground_level(48, 16, 10)
	var p1: PlayerBase = add_hero(Vector2i(92, 160))
	var p2: PlayerBase = _add_p2(Vector2i(108, 160))
	var platform: PlatformBase = PlatformBase.new()
	place(level, platform, Vector2i(100, 168))
	Sim.step(1)
	p1.sim_pos = Vector2i(92, 163)
	p2.sim_pos = Vector2i(108, 163)
	Sim.step(1)
	assert_true(platform.ridden)
	assert_eq(p1.carried_on_tick, Sim.total_ticks, "both heroes ride it")
	assert_eq(p2.carried_on_tick, Sim.total_ticks)
	var spring: SpringPad = spawn(&"objects/spring", Vector2i(400, 160)) as SpringPad
	p2.teleport(Vector2i(400, 152))
	p2.yvel = 32
	Sim.step(1)
	assert_eq(spring.launches, 1, "P2 is launched")
	assert_eq(p2.yvel, ObjTuning.SPRING_DEFAULT_POWER)


func test_a_gate_takes_the_hero_who_entered_and_a_column_lifts_every_hero() -> void:
	make_ground_level(48, 16, 10)
	var p1: PlayerBase = add_hero(Vector2i(40, 160))
	var p2: PlayerBase = _add_p2(Vector2i(88, 160))
	spawn(&"objects/gate", LevelText.cell_to_feet(5, 9), {"name": "in", "dest": "out", "skin": "none"})
	spawn(&"objects/marker", Vector2i(600, 96), {"name": "out"})
	Game.runs[1].has_glider = true
	p2.drop_timer = Tuning.DROP_TIMER
	Sim.step(2)
	assert_eq(p2.sim_pos, Vector2i(88, 160), "P2's own glider keeps him out")
	Game.runs[1].has_glider = false
	Sim.step(1)
	assert_eq(p2.sim_pos, Vector2i(600, 96), "P2 travels")
	assert_true(p2.control_enabled)
	# A co-op gate takes the whole party (DESIGN.md D.1, objects-A P1.9): without a PartyDriver P1 arrives at the
	# gate's partner spot behind P2.
	assert_ne(p1.sim_pos, Vector2i(40, 160), "P1 travels with him")
	assert_eq(p1.sim_pos, Gate.partner_spot(Game.level, Vector2i(600, 96), p2.facing), "P1 arrives behind him")
	# A two-cell block of the ground (row 10) rises one row; both heroes stand on it (bare heroes have no gravity,
	# and no shake nudges them).
	var column: RisingColumn = spawn(&"objects/column", LevelText.cell_to_feet(20, 10), {
		"size": "2,1", "rise": 1, "shake": 0,
	}) as RisingColumn
	p1.teleport(LevelText.cell_to_feet(20, 9))
	p2.teleport(LevelText.cell_to_feet(21, 9))
	Sim.step(Tuning.COLUMN_RISE_PERIOD + 1)
	assert_eq(column.risen, 1)
	assert_eq(p1.sim_pos.y, 160 - Tuning.TILE, "P1 rides up")
	assert_eq(p2.sim_pos.y, 160 - Tuning.TILE, "and so does P2")
