extends PlayerTestCase
## Chomper (docs/spec/PHYSICS.md C.9): MountTuning against the reference jump table of
## docs/spec/PARTY_REFERENCE.json ("mount": walk from rest, stop from full speed, the hop from full speed and from rest),
## the helpers the mount entity uses, and the rider's side with the real hero on a stand-in mount: the driver's own
## handlers do not run, the gunner strikes, throws, turns and swaps from his seat, a hit on a seated rider is the
## mount's (thrown off, stunned, no heart lost).

const PARTY_REFERENCE_PATH: String = "res://docs/spec/PARTY_REFERENCE.json"


## Stands in for objects-B's Mount: moves by its own xvel in PLATFORMS and places its riders there (driver at the
## saddle, gunner behind), answers rider_hit (C.9: every rider thrown off, the mount bolts).
class FakeMount:
	extends SimEntity

	var hits: Array = []
	var bolted: int = 0

	func _init() -> void:
		set_box(MountTuning.BOX)

	func _sim_phases() -> PackedInt32Array:
		return PackedInt32Array([Defs.Phase.PLATFORMS])

	func _sim_tick(_phase: int) -> void:
		sim_pos.x += Tuning.floor16(xvel)
		for hero: PlayerBase in Game.level.contact_order():
			if hero.mount == self:
				hero.sim_pos = MountTuning.seat_point(sim_pos, facing, hero.mount_seat)
				hero.yvel = 0
				hero.grounded = true

	func rider_hit(source: SimEntity) -> void:
		hits.append(source)
		for hero: PlayerBase in Game.level.contact_order().duplicate():
			if hero.mount == self:
				HeroMount.throw_off(hero, source)
		bolted += 1


static var _party_reference: Dictionary = {}

var mount: FakeMount = null


static func party_reference() -> Dictionary:
	if _party_reference.is_empty():
		var json: JSON = JSON.new()
		if json.parse(FileAccess.get_file_as_string(PARTY_REFERENCE_PATH)) == OK and json.data is Dictionary:
			_party_reference = json.data
	return _party_reference


func after_each() -> void:
	mount = null
	super.after_each()


## A flat world with a stand-in mount at `x` (placed before the hero, so his setup finds it) and the hero.
func mount_world(x: int = START_X + 40, fresh: bool = false) -> void:
	world_flat()
	if fresh:
		level.meta = {"book": 2, "belt": LevelText.BELT_FRESH}
	mount = FakeMount.new()
	place(level, mount, Vector2i(x, START.y))
	spawn_hero()


# =================================================================================================================
# MountTuning against the reference
# =================================================================================================================

func test_constants_match_the_reference_and_the_spec() -> void:
	var constants: Dictionary = party_reference().get("constants", {})
	assert_false(constants.is_empty(), "PARTY_REFERENCE.json constants")
	assert_eq(MountTuning.WALK_CAP, int(constants.get("mount_walk_cap", 0)))
	assert_eq(MountTuning.ACCEL, int(constants.get("mount_accel", 0)))
	assert_eq(MountTuning.FRICTION, int(constants.get("mount_friction", 0)))
	assert_eq(MountTuning.HOP, int(constants.get("mount_hop", 0)))
	# PHYSICS.md C.9 table.
	assert_eq(MountTuning.BOX, Vector3i(58, 35, 29))
	assert_eq(MountTuning.RIDDEN_BOX, Vector3i(58, 56, 29))
	assert_eq([MountTuning.SADDLE_PX, MountTuning.GUNNER_BEHIND_PX], [26, 14])
	assert_eq([MountTuning.GRAVITY, MountTuning.TERMINAL, MountTuning.NO_JUMP], [16, 192, 6], "the hero's values")
	assert_eq(MountTuning.WALL_PROBE, 20)
	assert_eq([MountTuning.HEAD_PROBE_ROWS_RIDDEN, MountTuning.HEAD_PROBE_ROWS_UNRIDDEN], [4, 3])
	assert_eq([MountTuning.BITE_TICKS, MountTuning.BITE_LIVE_FIRST, MountTuning.BITE_LIVE_LAST], [8, 5, 6])
	assert_eq(MountTuning.BITE_BOX, Rect2i(0, -35, 40, 29), "x +0 .. +40, y -35 .. -6")
	assert_eq([MountTuning.EAT_HP, MountTuning.FOOD_BONUS, MountTuning.BITE_POWER], [50, 500, 25])
	assert_eq([MountTuning.BOLT_TICKS, MountTuning.REMOUNT_LOCK, MountTuning.TAME_BOUNCES], [132, 22, 3])
	assert_eq([MountTuning.HIT_XVEL, MountTuning.HIT_YVEL, MountTuning.HIT_TIMER], [64, -128, 44])
	assert_eq([MountTuning.DISMOUNT_YVEL, MountTuning.STOMP_YVEL], [-128, -64])


func test_walk_from_rest_and_stop_match_the_reference() -> void:
	var reference: Dictionary = party_reference().get("mount", {})
	var walk: Array = []
	var xv: int = 0
	var x: int = 0
	for t: int in range(1, 9):
		xv = MountTuning.ground_xvel(xv, 1)
		x += Tuning.floor16(xv)
		walk.append([t, xv, x])
	_assert_rows(walk, reference.get("walk_from_rest", []), "walk from rest (x 1, 3, 6, 10, then 4 px/tick)")
	var stop: Array = []
	xv = MountTuning.WALK_CAP
	x = 0
	for t: int in range(1, 8):
		xv = MountTuning.ground_xvel(xv, 0)
		x += Tuning.floor16(xv)
		stop.append([t, xv, x])
	_assert_rows(stop, reference.get("stop_from_full_speed", []), "release at full speed: 7 px, at rest on tick 6")
	assert_eq(MountTuning.ground_xvel(-64, 0), -52, "FRICTION towards 0 from the left too")
	assert_eq(MountTuning.ground_xvel(-60, -1), -64, "the clamp")
	assert_eq(MountTuning.ground_xvel(0, 1, 2), 4, "ACCEL >> ice")


func test_the_hop_matches_the_reference_jump_table() -> void:
	var reference: Dictionary = party_reference().get("mount", {})
	var full: Array = _hop(MountTuning.WALK_CAP, 1)
	var rest: Array = _hop(0, 1)
	_assert_rows(full, reference.get("hop_from_full_speed", []), "hop from full speed")
	_assert_rows(rest, reference.get("hop_from_rest_direction_held", []), "hop from rest, a direction held")
	var apex: int = 0
	for row: Array in full:
		apex = maxi(apex, int(row[2]))
	assert_eq(apex, int(reference.get("hop_apex_px", -1)), "apex 55 px")
	assert_eq(int(full[-1][0]), int(reference.get("hop_landing_tick", -1)), "lands on tick 21")
	assert_eq(int(full[-1][1]), int(reference.get("hop_dx_full_speed", -1)), "84 px at full speed")
	assert_eq(int(rest[-1][1]), int(reference.get("hop_dx_from_rest", -1)), "74 px from rest")
	assert_eq(MountTuning.air_xvel(30, 0), 30, "no air friction")
	assert_eq(MountTuning.fall_yvel(190), MountTuning.TERMINAL)


func test_driver_input_helpers() -> void:
	var keys: Callable = func(text: String) -> int: return GameInput.keys_to_flags(text)
	assert_eq(MountTuning.steer(keys.call("R")), 1)
	assert_eq(MountTuning.steer(keys.call("LF")), -1)
	assert_eq(MountTuning.steer(keys.call("LR")), 0, "both directions: none")
	assert_true(MountTuning.wants_hop(keys.call("RU"), 0))
	assert_false(MountTuning.wants_hop(keys.call("U"), 2), "no_jump blocks the hop")
	assert_false(MountTuning.wants_hop(keys.call("DU"), 0), "DOWN + UP is the dismount, not a hop")
	assert_true(MountTuning.is_dismount(keys.call("DUR")))
	assert_false(MountTuning.is_dismount(keys.call("D")))
	assert_eq(MountTuning.bite_rect(Vector2i(100, 200), 1), Rect2i(100, 165, 40, 29), "0..40 in front, knee to head")
	assert_eq(MountTuning.bite_rect(Vector2i(100, 200), -1), Rect2i(60, 165, 40, 29), "mirrored")
	assert_eq(MountTuning.seat_point(Vector2i(100, 200), 1, PlayerBase.SEAT_DRIVER), Vector2i(100, 174))
	assert_eq(MountTuning.seat_point(Vector2i(100, 200), 1, PlayerBase.SEAT_GUNNER), Vector2i(86, 174))
	assert_eq(MountTuning.seat_point(Vector2i(100, 200), -1, PlayerBase.SEAT_GUNNER), Vector2i(114, 174))


# =================================================================================================================
# The rider's side
# =================================================================================================================

func test_the_component_is_on_only_with_a_mount() -> void:
	world_flat()
	spawn_hero()
	assert_false(hero.hero_mount.active)
	mount_world()
	assert_true(hero.hero_mount.active)
	assert_true(HeroMount.is_mount(mount))
	assert_false(HeroMount.is_mount(hero))


func test_the_driver_does_not_run_his_own_handlers() -> void:
	mount_world()
	hero.sit_on_mount(mount, PlayerBase.SEAT_DRIVER)
	mount.xvel = 48
	var xs: Array[int] = []
	play(hold("RU", 4) + hold("F", 6), func(_t: int) -> void:
		xs.append(hero.sim_pos.x - mount.sim_pos.x)
		assert_eq(hero.state, Defs.HeroState.RIDING)
		assert_eq(hero.yvel, 0, "no jump of his own")
		assert_false(hero.club_box_active, "no strikes with his own weapon while driving")
		assert_eq(hero.xvel, mount.xvel, "his xvel mirrors the mount's (the camera pages with him)")
	)
	assert_ints_eq(xs, [0, 0, 0, 0, 0, 0, 0, 0, 0, 0], "the mount places him at its saddle every tick")
	assert_eq(hero.sim_pos.y, START.y - MountTuning.SADDLE_PX)
	assert_eq(hero.handler, Defs.HeroState.RIDING)
	hero.leave_mount()
	mount.xvel = 0
	play(hold("", 1))
	assert_ne(hero.state, Defs.HeroState.RIDING, "off the seat his own update runs again")


func test_the_gunner_strikes_turns_and_swaps_from_his_seat() -> void:
	mount_world(START_X + 40, true)
	hero.run.set_belt(Defs.Weapon.HAMMER)
	hero.sit_on_mount(mount, PlayerBase.SEAT_GUNNER)
	play(hold("", 1))
	var seat: Vector2i = MountTuning.seat_point(mount.sim_pos, mount.facing, PlayerBase.SEAT_GUNNER)
	assert_eq(hero.sim_pos, seat, "14 px behind the driver's place")
	var boxes: Array[int] = [0]
	play(hold("F", 10), func(_t: int) -> void:
		if hero.club_box_active:
			boxes[0] += 1
		assert_eq(hero.sim_pos, seat, "he cannot move")
		assert_eq(hero.yvel, 0, "the strike hop is skipped as on a platform")
	)
	assert_true(boxes[0] > 0, "his strike makes club boxes")
	play(hold("L", 1))
	assert_eq(hero.facing, -1, "LEFT turns him")
	play(hold("", 12) + hold("S", 1))
	assert_eq(hero.run.weapon, Defs.Weapon.HAMMER, "and he may swap")
	assert_eq(hero.state, Defs.HeroState.RIDING)


func test_the_gunner_throws_from_his_seat() -> void:
	mount_world()
	hero.run.set_weapon(Defs.Weapon.AXE)
	hero.sit_on_mount(mount, PlayerBase.SEAT_GUNNER)
	var thrown: Array[int] = [0]
	play(hold("F", 12), func(_t: int) -> void:
		thrown[0] = maxi(thrown[0], level.get_kind(Defs.Kind.HERO_PROJECTILE).size())
	)
	assert_true(thrown[0] > 0, "the axe leaves his hand from the seat")
	hero.run.set_weapon(Defs.Weapon.CLUB)


func test_a_hit_on_a_seated_rider_is_the_mounts() -> void:
	mount_world()
	hero.sit_on_mount(mount, PlayerBase.SEAT_DRIVER)
	play(hold("", 2))
	var enemy: SimEntity = SimEntity.new()
	enemy.sim_pos = hero.sim_pos + Vector2i(20, 0)
	var hearts: int = hero.run.hearts
	assert_true(hero.hurt(enemy), "the hit is taken ...")
	assert_eq(hero.run.hearts, hearts, "... without a heart")
	assert_eq(mount.hits, [enemy], "by the mount (rider_hit)")
	assert_false(hero.is_mounted(), "the rider is thrown off")
	assert_eq([hero.xvel, hero.yvel, hero.hit_timer], [-MountTuning.HIT_XVEL, MountTuning.HIT_YVEL,
			MountTuning.HIT_TIMER], "away from the source, stunned")
	play(hold("R", 3))
	assert_eq(hero.state, Defs.HeroState.HURT, "stunned as by a 1.0 hit")
	enemy.free()
	# A skull while seated: thrown off, then the 1.0 skull rule scatters his energy.
	mount_world()
	hero.sit_on_mount(mount, PlayerBase.SEAT_DRIVER)
	play(hold("", 1))
	assert_true(hero.hurt(null, Defs.HurtKind.TRAP))
	assert_false(hero.is_mounted())
	assert_eq(hero.run.hearts, 0, "TRAP: all energy scattered")
	hero.run.reset_energy()


func test_the_saddle_ends_the_tar_rules_and_the_dismount_flies_normally() -> void:
	# 6-1 Bubbling Fen: a hero hops from the tar onto Chomper, rides the tar flats (mounts ignore tar, C.9) and gets off.
	var rows: PackedStringArray = PackedStringArray()
	for row: int in GROUND_ROW + WORLD_ROWS_BELOW:
		var line: String = ""
		for col: int in WORLD_COLS:
			if row == GROUND_ROW and col >= 50 and col <= 80:
				line += TileGrid.CH_TAR
			elif row >= GROUND_ROW:
				line += TileGrid.CH_SOLID_A
			else:
				line += TileGrid.CH_AIR
		rows.append(line)
	world_rows(rows)
	var surface: int = START.y + Tuning.TAR_SURFACE_DROP_PX
	mount = FakeMount.new()
	place(level, mount, Vector2i(START_X + 40, surface))
	spawn_hero(Vector2i(START_X, surface))
	play(hold("R", 3))
	assert_true(hero.hero_climb.on_tar, "wading")
	assert_eq(hero.walk_cap, Tuning.TAR_WALK_CAP)
	hero.sit_on_mount(mount, PlayerBase.SEAT_DRIVER)
	play(hold("", 2))
	assert_true(hero.is_mounted())
	assert_false(hero.hero_climb.on_tar, "the saddle is a landing")
	assert_eq([hero.walk_cap, hero.air_cap, hero.jump_impulse_ticks],
			[Tuning.WALK_CAP, Tuning.WALK_CAP, Tuning.JUMP_IMPULSE_TICKS], "the 1.0 limits in the saddle")
	# The dismount over the tar (objects-B's Mount: leave the seat, launch(0, -128)) has full air control ...
	hero.leave_mount()
	hero.launch(0, MountTuning.DISMOUNT_YVEL)
	var fastest: Array[int] = [0]
	play(hold("R", 8), func(_t: int) -> void: fastest[0] = maxi(fastest[0], hero.xvel))
	assert_eq(fastest[0], Tuning.WALK_CAP, "a dismount is no tar hop")
	# ... and the landing in the tar is wading again.
	play(hold("", 30))
	assert_true(hero.grounded)
	assert_true(hero.hero_climb.on_tar, "back in the tar")


func test_riding_objects_b_mount() -> void:
	world_flat()
	if not Spawner.exists(&"objects/mount") or not Spawner.exists(&"objects/rex_pen"):
		print("    PENDING objects-B objects/mount")
		assert_true(true)
		return
	var pen_at: Vector2i = START + Vector2i(40, 0)
	level.spawn(&"objects/rex_pen", pen_at, {"name": "pen"})
	var rex: SimEntity = level.spawn(&"objects/mount", pen_at, {"kind": "rex", "pen": "pen"})
	assert_not_null(rex)
	spawn_hero(pen_at - Vector2i(0, 90))
	hero.grounded = false
	assert_true(hero.hero_mount.active, "the level's mount switches the component on")
	var ticks: int = 0
	while not hero.is_mounted() and ticks < 30:
		play(hold("", 1))
		ticks += 1
	assert_true(hero.is_mounted(), "landing on the saddle seats him")
	if not hero.is_mounted():
		return
	assert_eq(hero.mount, rex)
	assert_eq(hero.mount_seat, PlayerBase.SEAT_DRIVER)
	var x0: int = rex.sim_pos.x
	var hearts: int = hero.run.hearts
	play(hold("R", 10), func(_t: int) -> void:
		assert_eq(hero.state, Defs.HeroState.RIDING)
		assert_eq(hero.sim_pos, rex.sim_pos - Vector2i(0, MountTuning.SADDLE_PX), "in the saddle")
		assert_eq(hero.xvel, rex.xvel, "his xvel follows the mount's")
	)
	assert_true(rex.sim_pos.x > x0 + 20, "his RIGHT drives the mount (%d px)" % (rex.sim_pos.x - x0))
	assert_eq(rex.xvel, MountTuning.WALK_CAP, "at 4 px per tick")
	var source: SimEntity = SimEntity.new()
	source.sim_pos = hero.sim_pos + Vector2i(30, 0)
	assert_true(hero.hurt(source))
	source.free()
	assert_false(hero.is_mounted(), "a hit throws him off")
	assert_eq(hero.run.hearts, hearts, "no heart lost")
	assert_eq(hero.hit_timer, MountTuning.HIT_TIMER)
	assert_eq(hero.xvel, -MountTuning.HIT_XVEL, "away from the hit")


func test_objects_b_mount_over_the_tar_flats_and_into_the_sea() -> void:
	# Worlds 6-7 (P2.12): Chomper crosses a tar floor at his full 4 px/tick (mounts ignore tar, C.9) and the rider never
	# wades (no tar rules, the 1.0 limits); walked into `~` every rider dies and the mount bolts (C.9), and the hero is
	# off the seat for good.
	var rows: PackedStringArray = PackedStringArray()
	for row: int in GROUND_ROW + WORLD_ROWS_BELOW:
		var line: String = ""
		for col: int in WORLD_COLS:
			if row == GROUND_ROW and col >= 67 and col <= 80:
				line += TileGrid.CH_TAR
			elif row >= GROUND_ROW and col >= 84 and col <= 90:
				line += TileGrid.CH_LIQUID
			elif row >= GROUND_ROW:
				line += TileGrid.CH_SOLID_A
			else:
				line += TileGrid.CH_AIR
		rows.append(line)
	world_rows(rows)
	if not Spawner.exists(&"objects/mount") or not Spawner.exists(&"objects/rex_pen"):
		print("    PENDING objects-B objects/mount")
		assert_true(true)
		return
	var pen_at: Vector2i = START + Vector2i(40, 0)
	level.spawn(&"objects/rex_pen", pen_at, {"name": "pen"})
	var rex: SimEntity = level.spawn(&"objects/mount", pen_at, {"kind": "rex", "pen": "pen"})
	spawn_hero(pen_at - Vector2i(0, 90))
	hero.grounded = false
	var ticks: int = 0
	while not hero.is_mounted() and ticks < 30:
		play(hold("", 1))
		ticks += 1
	assert_true(hero.is_mounted(), "seated")
	if not hero.is_mounted():
		return
	assert_true(hero.hero_climb.active, "a tar level: the climb component runs")
	var fastest_on_tar: Array[int] = [0]
	var died: Array[bool] = [false]
	ticks = 0
	while not died[0] and ticks < 160:
		play(hold("R", 1), func(_t: int) -> void:
			if hero.dead:
				died[0] = true
				return
			if hero.is_mounted() and level.grid.is_tar(Tuning.to_cell(rex.sim_pos.x), GROUND_ROW):
				fastest_on_tar[0] = maxi(fastest_on_tar[0], rex.xvel)
				assert_false(hero.hero_climb.on_tar, "a rider never wades")
				assert_eq([hero.walk_cap, hero.air_cap, hero.jump_impulse_ticks],
						[Tuning.WALK_CAP, Tuning.WALK_CAP, Tuning.JUMP_IMPULSE_TICKS], "the 1.0 limits in the saddle")
		)
		ticks += 1
	assert_eq(fastest_on_tar[0], MountTuning.WALK_CAP, "full speed over the tar")
	assert_true(died[0], "the sea killed the rider")
	assert_false(hero.is_mounted(), "and he is off the seat")
	assert_false(bool(rex.get(&"present")), "the mount bolted")


func test_throw_off_and_respawn() -> void:
	mount_world()
	hero.sit_on_mount(mount, PlayerBase.SEAT_GUNNER)
	var left_of_him: SimEntity = SimEntity.new()
	left_of_him.sim_pos = hero.sim_pos - Vector2i(30, 0)
	HeroMount.throw_off(hero, left_of_him)
	assert_eq(hero.xvel, MountTuning.HIT_XVEL, "thrown away from the source")
	assert_false(hero.is_mounted())
	left_of_him.free()
	HeroMount.throw_off(null, null)
	hero.sit_on_mount(mount, PlayerBase.SEAT_DRIVER)
	play(hold("", 1))
	hero.respawn_at(START)
	assert_false(hero.is_mounted(), "a respawn leaves the seat")
	play(hold("R", 3))
	assert_eq(hero.state, Defs.HeroState.WALK)


# =================================================================================================================
# Helpers
# =================================================================================================================

## The reference model of a hop (reference_party.py mount().hop): start velocities given, then per tick integrate x
## and y, then the air x rule (a direction held) and gravity, until it is back at the take-off height.
func _hop(start_xvel: int, dir: int) -> Array:
	var rows: Array = []
	var x: int = 0
	var y: int = 0
	var xv: int = start_xvel
	var yv: int = MountTuning.HOP
	for t: int in range(1, 100):
		x += Tuning.floor16(xv)
		y += Tuning.floor16(yv)
		xv = MountTuning.air_xvel(xv, dir)
		yv = MountTuning.fall_yvel(yv)
		rows.append([t, x, -y])
		if t > 1 and y >= 0:
			break
	return rows


func _assert_rows(got: Array, want: Array, message: String) -> void:
	assert_eq(got.size(), want.size(), "%s: rows" % message)
	for i: int in mini(got.size(), want.size()):
		assert_ints_eq(got[i], want[i], "%s, row %d" % [message, i + 1])
