extends "res://tests/test_enemies_case.gd"
## Movement of every archetype of GAMEPLAY.md 5.2 over a scripted number of ticks (the hero is a still PlayerBase
## that the tests move by hand).


func test_walker_accelerates_patrols_and_turns_smoothly() -> void:
	var walker: Walker = _enemy(&"enemies/walker", Vector2i(200, 160)) as Walker
	assert_eq(walker.left_x, 200 - 3 * Tuning.TILE)
	assert_eq(walker.right_x, 200 + 3 * Tuning.TILE)
	Sim.step(6)
	assert_eq(walker.xvel, 12, "3 v16 per tick from a standstill (woke on tick 1, first step on tick 2)")
	Sim.step(14)
	assert_eq(walker.xvel, EnemyTuning.PATROL_SPEED, "capped at `speed`")
	var low: int = walker.sim_pos.x
	var high: int = walker.sim_pos.x
	var turns: int = 0
	var last_dir: int = signi(walker.xvel)
	for tick: int in 300:
		Sim.step(1)
		low = mini(low, walker.sim_pos.x)
		high = maxi(high, walker.sim_pos.x)
		assert_eq(walker.sim_pos.y, 160, "stays on the ground")
		if walker.xvel != 0 and signi(walker.xvel) != last_dir:
			turns += 1
			last_dir = signi(walker.xvel)
		assert_true(absi(walker.xvel) <= EnemyTuning.PATROL_SPEED)
	assert_true(turns >= 4, "patrols back and forth")
	assert_true(high > walker.right_x and high < walker.right_x + Tuning.TILE, "overshoots the limit a little")
	assert_true(low < walker.left_x and low > walker.left_x - 2 * Tuning.TILE, "leftward floor16 is 1 px faster")
	assert_eq(walker.facing, signi(walker.xvel) if walker.xvel != 0 else walker.facing)


func test_walker_follows_slopes() -> void:
	_rows_level(PackedStringArray([
		"................................",
		"................................",
		"................................",
		"................................",
		"................................",
		"................................",
		"................................",
		"................................",
		"................................",
		"........../##\\...12##34.........",
		"################################",
	]))
	_level.view = Rect2i(0, 0, 32 * Tuning.TILE, Tuning.VIEW_H)
	var walker: Walker = _enemy(&"enemies/walker", Vector2i(120, 160), {"left": -1, "right": 20, "speed": 32}) as Walker
	var top: int = 160
	var crossed_first: bool = false
	for tick: int in 260:
		Sim.step(1)
		top = mini(top, walker.sim_pos.y)
		var col: int = walker.cell_col()
		assert_true(walker.sim_pos.y <= 160, "never sinks into the ground")
		assert_true(walker.sim_pos.y >= 144, "never floats above the hill")
		if col == 11 or col == 12 or col == 19 or col == 20:
			assert_eq(walker.sim_pos.y, 144, "on the hill tops")
		if col == 15:
			crossed_first = true
			assert_eq(walker.sim_pos.y, 160, "back on the ground between the hills")
	assert_eq(top, 144)
	assert_true(crossed_first, "walked over the first hill")
	assert_true(walker.sim_pos.x > 22 * Tuning.TILE or walker.xvel < 0, "and over the second one")


func test_flyer_ignores_walls_and_gravity() -> void:
	_rows_level(PackedStringArray([
		"................................",
		"................................",
		"................................",
		"................................",
		"..............#.................",
		"..............#.................",
		"..............#.................",
		"................................",
		"................................",
		"................................",
		"################################",
	]))
	var flyer: Flyer = _enemy(&"enemies/flyer", Vector2i(200, 96), {"left": -4, "right": 4, "speed": 48}) as Flyer
	var high: int = 0
	for tick: int in 200:
		Sim.step(1)
		assert_eq(flyer.sim_pos.y, 96, "keeps its height")
		high = maxi(high, flyer.sim_pos.x)
	assert_true(high > 14 * Tuning.TILE + 16, "flies through the wall at column 14")


func test_dangler_yo_yo() -> void:
	_rows_level(_ceiling_rows(32))
	var dangler: Dangler = _enemy(&"enemies/dangler", Vector2i(200, 64), {"depth": 48, "speed": 2}) as Dangler
	Sim.step(1)
	assert_true(dangler.awake)
	assert_eq(dangler._thread_top, Vector2i(200, 32), "the thread hangs from the ceiling above the anchor")
	assert_true(dangler._thread_on)
	var low: int = 0
	var high: int = 1000
	var path: Array[int] = []
	for tick: int in 60:
		Sim.step(1)
		low = maxi(low, dangler.sim_pos.y)
		high = mini(high, dangler.sim_pos.y)
		path.append(dangler.sim_pos.y)
	assert_eq(low, 64 + 48, "lowers `depth` px")
	assert_eq(high, 64, "and climbs back to its anchor")
	assert_eq(path[0], 66, "`speed` px per tick")
	assert_eq(path[1], 68)
	assert_eq(path[24], 110, "turns at the bottom")


func test_lurker_hangs_drops_runs_and_climbs() -> void:
	var rows: PackedStringArray = _ceiling_rows(32)
	rows[8] = "........#..............................."
	rows[9] = "........#..............................."
	_rows_level(rows)
	var lurker: Lurker = _enemy(&"enemies/lurker", Vector2i(200, 48)) as Lurker
	Sim.step(30)
	assert_true(lurker.awake)
	assert_false(lurker.tangible, "hangs intangible")
	assert_eq(lurker.sim_pos.y, 48, "the hero is too far away")
	_hero.teleport(Vector2i(170, 160))
	Sim.step(1)
	assert_true(lurker.tangible, "drops once the hero is within `range` tiles")
	var y: int = lurker.sim_pos.y
	Sim.step(1)
	assert_eq(lurker.sim_pos.y, y + 2, "2 px per tick on its thread")
	Sim.step(60)
	assert_eq(lurker.sim_pos.y, 160, "down to the floor")
	assert_false(lurker._thread_on)
	assert_eq(lurker.xvel, -EnemyTuning.LURKER_RUN_XVEL, "runs toward the hero")
	_hero.teleport(Vector2i(24, 160))
	var x: int = lurker.sim_pos.x
	Sim.step(1)
	assert_eq(lurker.sim_pos.x, x - 3, "3 px per tick")
	var top: int = 160
	for tick: int in 60:
		Sim.step(1)
		top = mini(top, lurker.sim_pos.y)
	assert_eq(top, 128, "climbed the wall onto its top")
	assert_true(lurker.sim_pos.x < 8 * Tuning.TILE, "and went on past it")
	assert_eq(lurker.sim_pos.y, 160)


func test_swinger_lowers_then_swings() -> void:
	_rows_level(_ceiling_rows(32))
	var swinger: Swinger = _enemy(&"enemies/swinger", Vector2i(200, 64), {"radius": 40}) as Swinger
	Sim.step(1)
	var hang: int = 27 / Tuning.ART_SCALE
	assert_eq(swinger.sim_pos, Vector2i(200, 32 + hang), "starts at the ceiling")
	Sim.step(20)
	assert_eq(swinger.sim_pos, Vector2i(200, 32 + 40 + hang), "lowered by `radius` at 2 px per tick")
	var high: int = 0
	var low: int = 0
	var zero_crossings: int = 0
	var last: int = 0
	for tick: int in 136:
		Sim.step(1)
		var angle: int = swinger.get_angle()
		high = maxi(high, angle)
		low = mini(low, angle)
		if last > 0 and angle <= 0 or last < 0 and angle >= 0:
			zero_crossings += 1
		last = angle
		var dx: int = swinger.sim_pos.x - 200
		var dy: int = swinger.sim_pos.y - hang - 32
		assert_true(absi(dx * dx + dy * dy - 1600) <= 160, "stays on the circle of the thread")
	assert_eq(high, 36, "about 51 degrees to the right")
	assert_eq(low, -36, "and as far to the left")
	assert_eq(zero_crossings, 8, "a period of 34 ticks")


func test_stinger_dives_diagonally_then_levels_out() -> void:
	var stinger: Stinger = _enemy(&"enemies/stinger", Vector2i(200, 80)) as Stinger
	Sim.step(20)
	assert_eq(stinger.sim_pos, Vector2i(200, 80), "hovers while the hero is outside its box")
	assert_eq(stinger.facing, -1, "facing the hero")
	_hero.teleport(Vector2i(130, 160))
	Sim.step(1)
	Sim.step(1)
	assert_eq(stinger.sim_pos, Vector2i(194, 86), "3 px per tick on both axes")
	Sim.step(22)
	assert_eq(stinger.sim_pos.y, 152, "levels out within 8 px of the hero's height")
	var y: int = stinger.sim_pos.y
	var x: int = stinger.sim_pos.x
	Sim.step(5)
	assert_eq(stinger.sim_pos.y, y, "continues horizontally")
	assert_eq(stinger.sim_pos.x, x - 15)


func test_harrier_circles_the_hero() -> void:
	var harrier: Harrier = _enemy(&"enemies/harrier", Vector2i(200, 100)) as Harrier
	Sim.step(20)
	assert_eq(harrier.sim_pos, Vector2i(200, 100), "perches while the hero is beyond `range`")
	_hero.teleport(Vector2i(120, 160))
	var seen: Dictionary[int, bool] = {}
	var prev: Vector2i = harrier.sim_pos
	for tick: int in 300:
		Sim.step(1)
		var step: Vector2i = (harrier.sim_pos - prev).abs()
		assert_true(step.x <= EnemyTuning.HARRIER_SPEED and step.y <= EnemyTuning.HARRIER_SPEED, "3 px per axis")
		prev = harrier.sim_pos
		seen[harrier.get_waypoint()] = true
		if tick > 60:
			assert_true(absi(harrier.sim_pos.x - 120) <= 96, "stays around the hero")
			assert_true(harrier.sim_pos.y < 160 and harrier.sim_pos.y >= 160 - 70, "above his feet")
	assert_eq(seen.size(), EnemyTuning.HARRIER_WAYPOINTS.size(), "loops through every way-point")


func test_harrier_rises_while_the_hero_strikes() -> void:
	var harrier: Harrier = _enemy(&"enemies/harrier", Vector2i(120, 100)) as Harrier
	_hero.teleport(Vector2i(120, 160))
	Sim.step(3)
	var point: Vector2i = EnemyTuning.HARRIER_WAYPOINTS[4]
	harrier._waypoint = 4
	harrier._waypoint_ticks = 0
	harrier.teleport(Vector2i(120 + point.x, 160 - point.y))
	_hero.attack_gate = true
	Sim.step(1)
	assert_eq(harrier.get_waypoint(), 4, "the way-point moved up by 5 px: not reached yet")
	assert_eq(harrier.sim_pos.y, 160 - point.y - EnemyTuning.HARRIER_SPEED, "climbs toward it")
	_hero.attack_gate = false
	Sim.step(1)
	assert_eq(harrier.sim_pos.y, 160 - point.y, "back down when he stops striking")


func test_dart_launches_once_and_never_returns() -> void:
	var dart: Dart = _enemy(&"enemies/dart", Vector2i(200, 80)) as Dart
	Sim.step(20)
	assert_false(dart.is_launched(), "waits while the hero is beyond `range`")
	assert_false(dart.one_shot)
	_hero.teleport(Vector2i(100, 160))
	Sim.step(1)
	assert_true(dart.is_launched())
	assert_true(dart.one_shot, "one-shot once launched")
	assert_eq(dart.sim_pos, Vector2i(196, 84), "4 px per tick on both axes toward the hero")
	Sim.step(200)
	assert_true(dart.dead, "gone for good after it left")
	assert_false(dart.visible)
	assert_eq(_level.active_enemies, 0)
	_level.reset_entities()
	assert_false(dart.dead, "until the level resets")
	assert_false(dart.one_shot)


func test_hopper_jumps_toward_the_hero() -> void:
	var hopper: Hopper = _enemy(&"enemies/hopper", Vector2i(200, 160)) as Hopper
	_hero.teleport(Vector2i(140, 160))
	Sim.step(23)
	assert_eq(hopper.sim_pos, Vector2i(200, 160), "waits `pause` ticks")
	Sim.step(1)
	assert_eq(hopper.yvel, -8 * Tuning.V16_PER_PX, "take-off speed `jump_y` px per tick")
	assert_eq(hopper.xvel, -3 * Tuning.V16_PER_PX)
	var top: int = 160
	var air: int = 0
	while hopper.sim_pos.y < 160 or air == 0:
		Sim.step(1)
		air += 1
		top = mini(top, hopper.sim_pos.y)
		assert_true(air < 40, "lands again")
		if air >= 40:
			break
	assert_eq(top, 160 - 36, "height v (v + 1) / 2 = 36 px")
	assert_eq(hopper.sim_pos.x, 200 - 3 * air, "3 px per tick forward")
	Sim.step(1)
	assert_eq(hopper.yvel, 0, "no landing bounce")
	assert_eq(hopper.xvel, 0, "pauses")
	var x: int = hopper.sim_pos.x
	Sim.step(EnemyTuning.HOPPER_PAUSE - 1)
	assert_eq(hopper.sim_pos.x, x)
	Sim.step(3)
	assert_true(hopper.sim_pos.y < 160, "and jumps again")


func test_charger_triggers_from_above_and_rushes_once() -> void:
	var rows: PackedStringArray = PackedStringArray()
	for row: int in 10:
		rows.append(".".repeat(80))
	rows[4] = ".".repeat(20) + "#".repeat(20) + ".".repeat(40)
	rows.append("#".repeat(80))
	_rows_level(rows)
	var charger: Charger = _enemy(&"enemies/charger", Vector2i(400, 64)) as Charger
	_hero.teleport(Vector2i(380, 160))
	Sim.step(5)
	assert_false(charger.awake, "the hero is below but within one screen and less than a screen lower")
	_hero.teleport(Vector2i(40, 32))
	Sim.step(5)
	assert_false(charger.awake, "the hero is above its anchor")
	_hero.teleport(Vector2i(40, 160))
	Sim.step(1)
	assert_true(charger.awake, "below and about a screen away")
	assert_eq(charger.xvel, -EnemyTuning.CHARGER_SPEED, "rushes toward him")
	var x: int = charger.sim_pos.x
	Sim.step(1)
	assert_eq(charger.sim_pos.x, x - 4)
	var settled: int = 0
	for tick: int in 120:
		Sim.step(1)
		settled = settled + 1 if charger.sim_pos.y == 160 and charger.yvel == 0 else 0
		if settled >= 5:
			break
	assert_eq(settled, 5, "fell off the ledge and goes on along the ground")
	assert_eq(absi(charger.xvel), EnemyTuning.CHARGER_SPEED)
	_level.view = Rect2i(2000, 0, Tuning.VIEW_W, Tuning.VIEW_H)
	Sim.step(Tuning.EDGE_RUSHER_OFFSCREEN_TICKS)
	assert_true(charger.awake)
	Sim.step(2)
	assert_true(charger.dead, "gone after 154 ticks off screen")
	_level.view = Rect2i(0, 0, Tuning.VIEW_W, Tuning.VIEW_H)
	Sim.step(5)
	assert_false(charger.awake, "one-shot")


func test_snapper_bites_in_front() -> void:
	var snapper: Snapper = _enemy(&"enemies/snapper", Vector2i(200, 160)) as Snapper
	Sim.step(10)
	assert_eq(snapper.facing, -1, "faces the hero")
	_hero.teleport(Vector2i(300, 160))
	Sim.step(20)
	assert_eq(Game.hearts, Tuning.ENERGY_START, "too far for a bite")
	assert_eq(snapper.facing, 1)
	_hero.teleport(Vector2i(232, 160))
	var bitten: bool = false
	for tick: int in 20:
		Sim.step(1)
		if snapper.get_bite_rect().size.x > 0:
			bitten = true
	assert_true(bitten, "lunges")
	assert_eq(Game.hearts, Tuning.ENERGY_START - 1, "the bite hurts once")
	assert_true(snapper.stole_heart)
	assert_eq(snapper.sim_pos, Vector2i(200, 160), "rooted")


func test_decoration_is_static_and_intangible() -> void:
	var deco: EnemyBase = _enemy(&"enemies/decoration", Vector2i(200, 160), {"prop": "jungle/fern"})
	var hanging: EnemyBase = _enemy(&"enemies/decoration", Vector2i(240, 64), {"prop": "jungle/vine_a"})
	Sim.step(10)
	assert_false(deco.awake, "takes no slot")
	assert_true(deco.visible)
	assert_false(deco.contact_hurts)
	assert_false(deco.is_targetable())
	assert_false(deco.take_hit(25, _hero))
	assert_eq(_level.active_enemies, 0)
	assert_eq(deco.sim_pos, Vector2i(200, 160), "stands on its cell")
	assert_eq(hanging.box_top(), 64 - Tuning.TILE, "ceiling pieces hang from the top of their cell")
	var sprite: Sprite2D = hanging.get_node(^"Sprite")
	assert_eq(sprite.texture.resource_path, "res://assets/tiles/jungle/props/vine_a.png")


## Rows of a 40-column level with a ceiling row ending at y = `ceiling_bottom` and the ground at row 10.
func _ceiling_rows(ceiling_bottom: int) -> PackedStringArray:
	var rows: PackedStringArray = PackedStringArray()
	for row: int in 11:
		var solid: bool = row < Tuning.to_cell(ceiling_bottom) or row == 10
		rows.append(("#" if solid else ".").repeat(40))
	return rows
