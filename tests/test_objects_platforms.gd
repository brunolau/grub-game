extends ObjectsTestCase
## Movers, droppers and rising columns (PHYSICS.md 11.4, GAMEPLAY.md 7.3 / 7.4).


func before_each() -> void:
	super.before_each()
	make_ground_level()
	add_hero(Vector2i(40, 160))


## The hero standing on the surface of `platform` (feet 1 px inside its top, as after a ride test).
func stand_on(platform: PlatformBase) -> void:
	hero.teleport(Vector2i(platform.sim_pos.x, platform.sim_pos.y - platform.box_h + 1))
	hero.yvel = 0


func test_mover_ramps_travels_and_turns_back() -> void:
	var platform: MovingPlatform = spawn(&"objects/platform", LevelText.cell_to_feet(9.5, 5), {
		"dir": 2, "speed": 2, "travel": 4,
	}) as MovingPlatform
	assert_eq(platform.sim_pos, Vector2i(160, 88), "standing surface = top of its cell (y 80)")
	assert_eq(platform.sim_pos.y - platform.box_h, 5 * Tuning.TILE)
	var xs: Array[int] = []
	for i: int in 9:
		Sim.step(1)
		xs.append(platform.sim_pos.x)
	assert_eq(xs, [161, 163, 165, 167, 169, 170, 170, 169, 167] as Array[int], "speed changes 1 px/tick per tick")
	assert_eq(platform.target, -2)


func test_mover_directions() -> void:
	var up_left: MovingPlatform = spawn(&"objects/platform", Vector2i(160, 96), {
		"dir": 7, "speed": 1, "travel": 10,
	}) as MovingPlatform
	var down: MovingPlatform = spawn(&"objects/platform", Vector2i(260, 64), {"dir": 4, "speed": 1}) as MovingPlatform
	Sim.step(3)
	assert_eq(up_left.sim_pos, Vector2i(157, 85), "the same px/tick on both axes")
	assert_eq(down.sim_pos, Vector2i(260, 59))


func test_ride_mode_waits_for_the_hero_and_carries_him() -> void:
	var platform: MovingPlatform = spawn(&"objects/platform", Vector2i(160, 96), {
		"dir": 2, "speed": 2, "travel": 3, "mode": "ride",
	}) as MovingPlatform
	Sim.step(5)
	assert_eq(platform.sim_pos.x, 160, "a ride platform waits")
	stand_on(platform)
	Sim.step(1)
	assert_true(platform.ridden, "the ride test found the hero")
	assert_true(hero.on_platform)
	assert_eq(platform.sim_pos.x, 160)
	Sim.step(1)
	assert_eq(platform.sim_pos.x, 161, "it starts on the tick after he landed")
	assert_eq(hero.sim_pos.x, 161, "and carries him")
	hero.teleport(Vector2i(40, 160))
	for i: int in 40:
		Sim.step(1)
	assert_eq(platform.velocity, 0, "after he stepped off it stops at the end of its cycle")
	var resting_x: int = platform.sim_pos.x
	Sim.step(10)
	assert_eq(platform.sim_pos.x, resting_x)
	assert_true(absi(resting_x - 160) <= 2, "back home")


func test_platform_skins_by_biome_and_parameter() -> void:
	var small: MovingPlatform = spawn(&"objects/platform", Vector2i(160, 96), {"skin": "small"}) as MovingPlatform
	assert_eq(small.box_w, 32)
	var sprite: Sprite2D = small.get_node("Sprite") as Sprite2D
	assert_eq(sprite.texture.resource_path, "res://assets/sprites/objects/platform_small.png")
	assert_eq(sprite.offset, Vector2(-32, -16), "the top edge of the picture is the standing surface")
	level.meta["biome"] = "volcano"
	var stone: DropPlatform = spawn(&"objects/drop_platform", Vector2i(260, 96)) as DropPlatform
	assert_eq((stone.get_node("Sprite") as Sprite2D).texture.resource_path,
			"res://assets/sprites/objects/platform_stone.png")


func test_dropper_falls_rests_and_returns() -> void:
	var platform: DropPlatform = spawn(&"objects/drop_platform", Vector2i(160, 96), {"delay": 2}) as DropPlatform
	Sim.step(1)
	stand_on(platform)
	Sim.step(1)
	assert_true(platform.ridden)
	Sim.step(2)
	assert_eq(platform.state, DropPlatform.State.WAIT, "the delay counts down while he stands on it")
	Sim.step(1)
	assert_eq(platform.state, DropPlatform.State.FALL)
	hero.teleport(Vector2i(40, 160))
	var speeds: Array[int] = []
	for i: int in 60:
		Sim.step(1)
		speeds.append(platform.fall_speed)
		if platform.state != DropPlatform.State.FALL:
			break
	assert_eq(platform.state, DropPlatform.State.REST)
	assert_eq(platform.sim_pos.y, 10 * Tuning.TILE, "rests on the floor it ran into")
	assert_eq(speeds[0], Tuning.DROPPER_ACCEL)
	assert_true(speeds.max() <= Tuning.DROPPER_MAX)
	Sim.step(Tuning.DROPPER_REST_TICKS)
	assert_eq(platform.state, DropPlatform.State.WAIT, "returns once the hero was off it for 22 ticks")
	var y: int = platform.sim_pos.y
	Sim.step(1)
	assert_eq(platform.sim_pos.y, y - Tuning.DROPPER_RETURN_SPEED)
	Sim.step(20)
	assert_eq(platform.sim_pos, platform.home)


func test_platforms_reset_on_respawn() -> void:
	var mover: MovingPlatform = spawn(&"objects/platform", Vector2i(160, 96)) as MovingPlatform
	Sim.step(10)
	assert_ne(mover.sim_pos, mover.home)
	level.reset_entities()
	assert_eq(mover.sim_pos, mover.home)
	assert_eq(mover.velocity, 0)


func test_column_rises_carries_the_hero_and_resets() -> void:
	var column: RisingColumn = spawn(&"objects/column", LevelText.cell_to_feet(20, 10), {
		"size": "2,1", "rise": 2,
	}) as RisingColumn
	assert_eq(column.block, Rect2i(20, 10, 2, 1))
	hero.teleport(Vector2i(21 * 16 + 4, 160))
	# Crouching: the bare test hero has no gravity, so he must not be lifted by the earthquake nudge.
	hero.state = Defs.HeroState.CROUCH
	Sim.step(1)
	assert_true(column.triggered, "the hero's feet entered the trigger")
	Sim.step(Tuning.COLUMN_RISE_PERIOD)
	assert_eq(column.risen, 1)
	assert_eq(level.get_cell(20, 9), TileGrid.CH_SOLID_A)
	assert_eq(level.get_cell(21, 9), TileGrid.CH_SOLID_A)
	assert_eq(level.get_cell(20, 10), TileGrid.CH_SOLID_A, "the ground under the pillar stays ground")
	assert_eq(hero.sim_pos.y, 9 * Tuning.TILE, "the hero rides up on it")
	assert_true(level.shake > 0, "the screen shakes while it rises")
	Sim.step(Tuning.COLUMN_RISE_PERIOD)
	assert_eq(column.risen, 2)
	assert_eq(level.get_cell(20, 8), TileGrid.CH_SOLID_A)
	assert_eq(hero.sim_pos.y, 8 * Tuning.TILE)
	Sim.step(Tuning.COLUMN_RISE_PERIOD * 2)
	assert_eq(column.risen, 2, "it stops after `rise` rows")
	assert_eq(level.get_cell(20, 7), TileGrid.CH_AIR)
	level.reset_entities()
	assert_eq(level.get_cell(20, 8), TileGrid.CH_AIR, "a respawn puts the cells back")
	assert_eq(level.get_cell(20, 9), TileGrid.CH_AIR)
	assert_eq(level.get_cell(20, 10), TileGrid.CH_SOLID_A)
	assert_false(column.triggered, "and re-arms it")


func test_column_bridge_rises_and_leaves_air_behind() -> void:
	for col: int in range(5, 8):
		level.set_cell(col, 6, TileGrid.CH_ONEWAY_A)
	var bridge: RisingColumn = spawn(&"objects/column", LevelText.cell_to_feet(5, 6), {
		"size": "3,1", "rise": 2, "trigger": "0,7,4,2", "shake": 4,
	}) as RisingColumn
	Sim.step(10)
	assert_false(bridge.triggered, "the hero stands in row 9, below the trigger rectangle (rows 7-8)")
	hero.teleport(Vector2i(24, 144))
	Sim.step(1 + Tuning.COLUMN_RISE_PERIOD * 2)
	assert_eq(bridge.risen, 2)
	for col: int in range(5, 8):
		assert_eq(level.get_cell(col, 4), TileGrid.CH_ONEWAY_A)
		assert_eq(level.get_cell(col, 5), TileGrid.CH_AIR)
		assert_eq(level.get_cell(col, 6), TileGrid.CH_AIR)
	assert_eq(level.grid.floor_at(6, 4), TileGrid.FLOOR_SOLID, "collision follows the tiles")
