extends PartyTestCase
## The hero's side of the rules that close a co-op gate to ONE hero (the orchestrator's rulings of wf11 after the G3b
## verification, build/engine_requests/wf10_g3b_verify_to_orchestrator.txt causes A, B and E). Each rule is measured
## both ways with the real hero: for a hero of a co-op party the way is closed, in single-player nothing changed.
##  R1 - a spring is a launch (PlayerBase.spring_bounce, objects/spring): no jump table on top of the pad.
##  R3 - the ward (objects/x2_tablet, LevelBase.in_ward, Player._ward_stomp): inside it no enemy gives lift, rest or
##       carry, a club hit on an enemy gives no pogo; the stomp counts, that enemy does not hurt him during the fall.
##  R5 - a closed door passes nobody (Player._hold_the_side): a hero whose feet got into a wall sideways is put back.
## (R6, the idle hero and the camera, is world-A's: tests/test_world_tribe.gd and tests/test_world_party.gd.)

const FLOOR_Y: int = GROUND_ROW * 16
## Where the co-op partner waits in these tests: far from everything, on the floor, his pad on the table.
const PARTNER_AT: Vector2i = Vector2i(START_X - 400, FLOOR_Y)

var _bounces: int = 0
var _coop: bool = false


func after_each() -> void:
	if Events.hero_bounced.is_connected(_on_bounced):
		Events.hero_bounced.disconnect(_on_bounced)
	if Events.hero_hurt.is_connected(_on_hurt):
		Events.hero_hurt.disconnect(_on_hurt)
	PlayerBase.ward_grace_ticks = PartyTuning.WARD_GRACE_TICKS
	GameInput.clear_scripted()
	super.after_each()


func _on_bounced(_hero: PlayerBase, _target: SimEntity, _multiplier: int) -> void:
	_bounces += 1


## The same world for one hero (single-player, `hero`) or for a co-op party of two (`hero` = P1; P2 waits far away).
func _world(coop: bool, rows: PackedStringArray, at: Vector2i = START) -> LevelBase:
	_coop = coop
	if coop:
		party(Defs.GameMode.COOP, at, PARTNER_AT, true, rows)
		driver.fence = false
		return Game.level
	if rows.is_empty():
		world_flat()
	else:
		world_rows(rows)
	spawn_hero(at)
	return level


## One tick per flag for the hero under test (P1's slot; the partner's pad is never touched).
func _play(flags: PackedInt32Array, each: Callable = Callable()) -> void:
	var first: int = Sim.tick + 1
	GameInput.set_scripted_slot(0, func(tick: int) -> int:
		var index: int = tick - first
		return flags[index] if index >= 0 and index < flags.size() else 0
	)
	for i: int in flags.size():
		Sim.step(1)
		if each.is_valid():
			each.call(i + 1)
	GameInput.clear_scripted()


## The static view of the co-op test level, put around `x` (single-player: the view follows the hero by itself). An
## enemy is touched only while it was drawn on the tick before (PHYSICS.md 10.1).
func _look_at(x: int) -> void:
	if _coop:
		party_level().view = Rect2i(x - Tuning.VIEW_W / 2, FLOOR_Y - 140, Tuning.VIEW_W, Tuning.VIEW_H)


func _flat_rows() -> PackedStringArray:
	var rows: PackedStringArray = PackedStringArray()
	for row: int in GROUND_ROW + WORLD_ROWS_BELOW:
		rows.append((TileGrid.CH_SOLID_A if row >= GROUND_ROW else TileGrid.CH_AIR).repeat(WORLD_COLS))
	return rows


## A plain enemy body (32 x 35) standing at `pos`, awake and drawn: its contact is the 1.0 head bounce.
func _body_at(pos: Vector2i, params: Dictionary = {"hp": 25}) -> EnemyBase:
	_look_at(pos.x)
	var enemy: EnemyBase = EnemyBase.new()
	place(Game.level, enemy, pos, params)
	enemy.set_box(Vector3i(32, 35, 16))
	enemy.wake()
	enemy.on_screen = true
	return enemy


func _falling(h: PlayerBase, pos: Vector2i, yvel: int) -> void:
	h.teleport(pos)
	h.xvel = 0
	h.yvel = yvel
	h.grounded = false
	h.on_platform = false
	h.fall_ticks = 8
	h.no_jump = Tuning.NO_JUMP_TICKS


func _tablet(col: int, far_col: int, extra: Dictionary = {}) -> X2Tablet:
	var params: Dictionary = {"gate": "gate", "far": "%d,%d" % [far_col, GROUND_ROW - 1]}
	params.merge(extra)
	return Game.level.spawn(&"objects/x2_tablet", Vector2i(col * 16 + 8, FLOOR_Y), params) as X2Tablet


# =================================================================================================================
# R1 - a spring is a launch
# =================================================================================================================

## The highest the hero's feet get over the floor with `flags`, starting at rest at `from`.
func _rise(from: Vector2i, flags: PackedInt32Array) -> int:
	hero.respawn_at(from)
	var top: Array[int] = [from.y]
	_play(flags, func(_t: int) -> void:
		top[0] = mini(top[0], hero.sim_pos.y))
	return from.y - top[0]


func _keys(runs: Array) -> PackedInt32Array:
	var flags: PackedInt32Array = PackedInt32Array()
	for run: Array in runs:
		flags.append_array(hold(str(run[1]), int(run[0])))
	return flags


## The stack's start offsets from the pad and Down + Fire ticks tried here (a cut of the G3b verifier's grid, which
## build/g3bv/spring.gd runs whole - 2 700 variants - in the search world).
const STACK_DX: Array[int] = [-14, -8, 0, 8, 14]
const STACK_LOW: Array[int] = [9, 11]


## What one hero gets out of the pad at `pad_x`: "plain" - a jump onto it with Up held; "stack" - the G3b verifier's
## move (build/g3bv/spring.gd): a low strike begun ON the pad, Up from its hop (with and without a side key, with and
## without a high strike in the rise).
func _spring_rises(pad_x: int) -> Dictionary:
	var plain: int = 0
	for dx: int in range(-110, -10, 8):
		plain = maxi(plain, _rise(Vector2i(pad_x + dx, FLOOR_Y), _keys([[30, "RU"], [50, "U"]])))
	var stack: int = 0
	for dx: int in STACK_DX:
		for low: int in STACK_LOW:
			for kind: int in 3:
				var runs: Array = [[low, "DF"], [16, "U" if kind == 0 else "RU"]]
				if kind == 2:
					runs.append([10, "UF"])
				runs.append([60, ""])
				stack = maxi(stack, _rise(Vector2i(pad_x + dx, FLOOR_Y), _keys(runs)))
	return {"plain": plain, "stack": stack}


func test_a_spring_is_a_launch_for_a_coop_hero_and_the_1_0_pad_in_single_player() -> void:
	var pad_x: int = START_X + 120
	var rises: Array[Dictionary] = []
	for coop: bool in [false, true]:
		var world: LevelBase = _world(coop, _flat_rows())
		var pad: SpringPad = world.spawn(&"objects/spring", Vector2i(pad_x, FLOOR_Y)) as SpringPad
		assert_not_null(pad, "the pad stands")
		rises.append(_spring_rises(pad_x))
		assert_true(pad.launches > 10, "%s: the pad fired (%d launches)" % ["co-op" if coop else "solo", pad.launches])
	var solo: Dictionary = rises[0]
	var coop_rise: Dictionary = rises[1]
	print("    spring: solo plain %d, stack %d px; co-op plain %d, stack %d px" % [solo["plain"], solo["stack"],
		coop_rise["plain"], coop_rise["stack"]])
	# A plain jump onto the pad: -224 from the pad's top, 10 px over the floor - the same for everybody.
	assert_eq(solo["plain"], 115, "single-player: a plain jump onto the pad rises 105 px from its top (115 over the floor)")
	assert_eq(coop_rise["plain"], 115, "co-op: the plain jump is what it was")
	# The stack: 256 px in single-player (the 1.0 pad: the jump table on top of -224), a plain launch in co-op.
	assert_true(solo["stack"] >= 256, "single-player keeps the 1.0 pad: the jump table stacks on it (%d px, 16 rows and more)"
			% solo["stack"])
	assert_eq(coop_rise["stack"], 115, "co-op (R1): a low strike begun on the pad rises what a plain jump onto it does")


func test_the_coop_spring_arms_the_jump_lock_as_a_launch_does() -> void:
	for coop: bool in [false, true]:
		_world(coop, _flat_rows())
		hero.no_jump = 0
		hero.on_platform = true
		hero.spring_bounce(ObjTuning.SPRING_DEFAULT_POWER, 4)
		var label: String = "co-op" if coop else "solo"
		assert_eq(hero.yvel, ObjTuning.SPRING_DEFAULT_POWER, label + ": thrown with the pad's power")
		assert_eq(hero.sim_pos.y, FLOOR_Y - 4, label + ": lifted by the depth")
		assert_false(hero.grounded, label)
		assert_eq(hero.no_jump, Tuning.NO_JUMP_TICKS if coop else 0,
				label + (": no_jump armed (PlayerBase.launch)" if coop else ": the 1.0 bounce leaves no_jump alone"))
		assert_eq(hero.on_platform, not coop, label + ": the platform flag")
		assert_eq(hero.launch_hold, coop, label + ": the hold on his flight (PlayerBase.launch_hold)")
		assert_eq(hero.in_coop_party(), coop, label + ": in_coop_party")


func test_a_versus_hero_keeps_the_1_0_pad() -> void:
	party(Defs.GameMode.VERSUS, START, PARTNER_AT)
	hero.no_jump = 0
	hero.spring_bounce(ObjTuning.SPRING_DEFAULT_POWER, 0)
	assert_false(hero.in_coop_party(), "versus is no co-op party")
	assert_eq(hero.no_jump, 0, "the 1.0 bounce")


# =================================================================================================================
# R3 - the ward
# =================================================================================================================

func test_every_tablet_wards_its_columns_and_the_margin() -> void:
	assert_eq(PartyTuning.WARD_MARGIN_CELLS, 12, "the default margin (tune through DESIGN)")
	assert_eq(X2Tablet.ward_columns(40, 52), Vector2i(28, 64), "its own cell to its far cell, 12 cells wider each side")
	assert_eq(X2Tablet.ward_columns(52, 40), Vector2i(28, 64), "a far cell to the LEFT of the tablet: the same columns")
	assert_eq(X2Tablet.ward_columns(40, 52, "3,5"), Vector2i(37, 57), "ward=<left>,<right>: its own widths in cells")
	assert_eq(X2Tablet.ward_columns(40, 52, "0,0"), Vector2i(40, 52), "ward=0,0: the gate's own columns only")
	assert_eq(X2Tablet.ward_columns(40, -1), Vector2i(28, 52), "no far cell: the tablet's own column and the margin")
	assert_eq(X2Tablet.ward_columns(40, 52, "x"), Vector2i(28, 64), "a malformed override falls back to the default")
	assert_eq(X2Tablet.parse_ward("4, 7"), Vector2i(4, 7))
	assert_eq(X2Tablet.parse_ward("-1,3"), Vector2i(-1, -1), "widths are >= 0")
	assert_eq(X2Tablet.parse_ward("7"), Vector2i(-1, -1))
	var world: LevelBase = _world(true, _flat_rows())
	assert_false(world.in_ward(40 * 16), "a level without tablets has no ward")
	var tablet: X2Tablet = _tablet(40, 52)
	assert_eq(tablet.ward, Vector2i(28, 64))
	assert_eq(world.get_wards(), [Vector2i(28, 64)] as Array[Vector2i], "the tablet declared it to the level")
	assert_false(world.in_ward(28 * 16 - 1), "one px left of the ward")
	assert_true(world.in_ward(28 * 16), "its first px")
	assert_true(world.in_ward(64 * 16 + 15), "its last px")
	assert_false(world.in_ward(65 * 16), "one px right of it")
	var narrow: X2Tablet = _tablet(80, 84, {"ward": "2,90"})
	assert_eq(world.get_wards(), [Vector2i(28, 64), Vector2i(78, WORLD_COLS - 1)] as Array[Vector2i],
			"a second tablet with its own widths, clamped to the map")
	assert_false(world.in_ward(70 * 16), "between the two wards")
	assert_true(world.in_ward(90 * 16))
	world.remove_child(narrow)
	narrow.free()
	assert_eq(world.get_wards(), [Vector2i(28, 64)] as Array[Vector2i], "a tablet that leaves takes its ward along")
	world.remove_child(tablet)
	tablet.free()
	assert_false(world.in_ward(40 * 16), "no tablet, no ward")


## The hero falls from 80 px onto the head of a body at `body_x` with `keys` held (24 ticks, then nothing). Returns what
## happened up to his FIRST landing on the floor (or to the end of the 84 ticks when a head keeps him up): "trace" (feet
## point and velocity after every tick), "landed" (the tick, 0 = never), "rose" (how far his feet came back up after
## the contact: 0 when he never rose), "count" (the body's bounce count then), "hearts" lost, "bounced"
## (Events.hero_bounced fired).
func _stomp_run(body_x: int, keys: String, with_body: bool, body_params: Dictionary = {"hp": 25}) -> Dictionary:
	_look_at(body_x)
	var enemy: EnemyBase = _body_at(Vector2i(body_x, FLOOR_Y), body_params) if with_body else null
	hero.respawn_at(Vector2i(body_x - 4, FLOOR_Y - 80))
	_falling(hero, Vector2i(body_x - 4, FLOOR_Y - 80), 32)
	var hearts: int = hero.run.hearts
	_bounces = 0
	Events.hero_bounced.connect(_on_bounced)
	var trace: Array[Vector4i] = []
	var state: Dictionary = {"landed": 0, "low": hero.sim_pos.y, "rose": 0, "count": 0, "bounced": 0, "hearts": 0}
	var flags: PackedInt32Array = hold(keys, 24)
	flags.append_array(hold("", 60))
	_play(flags, func(t: int) -> void:
		if int(state["landed"]) != 0:
			return
		trace.append(Vector4i(hero.sim_pos.x, hero.sim_pos.y, hero.xvel, hero.yvel))
		state["low"] = maxi(int(state["low"]), hero.sim_pos.y)
		state["rose"] = maxi(int(state["rose"]), int(state["low"]) - hero.sim_pos.y)
		if hero.grounded and hero.sim_pos.y == FLOOR_Y:
			state["landed"] = t
			state["count"] = enemy.bounce_count if enemy != null else 0
			state["bounced"] = _bounces
			state["hearts"] = hearts - hero.run.hearts)
	Events.hero_bounced.disconnect(_on_bounced)
	if int(state["landed"]) == 0:
		# He never came down to the floor (a head that bounces him keeps him up): the counts at the end of the run.
		state["count"] = enemy.bounce_count if enemy != null else 0
		state["bounced"] = _bounces
		state["hearts"] = hearts - hero.run.hearts
	state["trace"] = trace
	if enemy != null:
		Game.level.remove_child(enemy)
		enemy.free()
	return state


func test_in_a_ward_a_head_gives_a_coop_hero_nothing_and_everything_in_single_player() -> void:
	var inside_x: int = 50 * 16 + 8    # in the ward of the tablet (columns 28 .. 64)
	var outside_x: int = 80 * 16 + 8   # well outside it
	for coop: bool in [false, true]:
		var label: String = "co-op" if coop else "solo"
		_world(coop, _flat_rows())
		_tablet(40, 52)
		assert_true(Game.level.in_ward(inside_x) and not Game.level.in_ward(outside_x), "the set-up")
		for keys: String in ["U", ""]:
			var what: String = "%s, %s" % [label, "Up held" if keys == "U" else "Up released"]
			var free_fall: Dictionary = _stomp_run(inside_x, keys, false)
			var inside: Dictionary = _stomp_run(inside_x, keys, true)
			var outside: Dictionary = _stomp_run(outside_x, keys, true)
			# The contact lifts him onto the head (the depth), then the bounce rises 105 px (Up) or 10 px from there.
			var rise: int = 105 if keys == "U" else 10
			assert_true(int(free_fall["landed"]) > 0 and int(free_fall["rose"]) == 0, what + ": the set-up - a plain fall")
			# Outside the ward a head is a head for everybody: the 1.0 bounce.
			assert_true(int(outside["bounced"]) >= 1, what + ": outside the ward he bounces")
			assert_true(int(outside["rose"]) >= rise, what + ": ... %d px and the lift onto the head (rose %d)"
					% [rise, int(outside["rose"])])
			assert_eq(outside["hearts"], 0, what + ": ... unhurt")
			if coop:
				# Inside: the fall with the body under him IS the fall without it, tick for tick, to the floor.
				assert_eq(inside["trace"], free_fall["trace"],
						what + ": in the ward the head changes neither his velocity nor his position")
				assert_eq(inside["bounced"], 0, what + ": no bounce")
				assert_eq(inside["rose"], 0, what + ": he never rises")
				assert_eq(inside["landed"], free_fall["landed"], what + ": he lands when a free fall lands")
				assert_eq(inside["count"], 1, what + ": the stomp still counts against the enemy - once for the whole fall")
				assert_eq(inside["hearts"], 0, what + ": that enemy did not hurt him during the fall")
			else:
				assert_eq(inside["trace"], outside["trace"].map(func(row: Vector4i) -> Vector4i:
					return row - Vector4i(outside_x - inside_x, 0, 0, 0)),
						what + ": single-player knows no ward - the bounce in it is the bounce outside it, tick for tick")
				assert_eq(inside["rose"], outside["rose"], what)
				assert_eq(inside["hearts"], 0, what)


func test_keepers_are_enemies_and_the_stomp_counts_once_a_fall() -> void:
	_world(true, _flat_rows())
	_tablet(40, 52)
	var x: int = 50 * 16 + 8
	var keeper: EnemyBase = _body_at(Vector2i(x, FLOOR_Y), {"hp": 25, "keeper": "door"})
	assert_eq(Game.level.get_tagged(&"keeper", &"door").size(), 1, "the set-up: a keeper")
	var hearts: int = hero.run.hearts
	for fall: int in 3:
		_falling(hero, Vector2i(x - 4, FLOOR_Y - 90), 32)
		var top: Array[int] = [hero.sim_pos.y]
		var inside: Array[int] = [0]
		# He comes down with Up held, lands inside its box and walks out of it to the left (the boxes part), then waits.
		_play(_keys([[12, "U"], [30, "L"], [10, ""]]), func(_t: int) -> void:
			top[0] = mini(top[0], hero.sim_pos.y)
			if hero._ward_heads.has(keeper):
				inside[0] += 1)
		assert_eq(keeper.bounce_count, fall + 1, "fall %d: one more stomp counted, however long he was in its box (%d ticks)"
				% [fall + 1, inside[0]])
		assert_true(inside[0] >= 4, "fall %d: he fell through the keeper (%d ticks in its box)" % [fall + 1, inside[0]])
		assert_true(hero._ward_heads.is_empty(), "fall %d: clear of it, the two are strangers again" % (fall + 1))
		assert_eq(top[0], FLOOR_Y - 90, "fall %d: never a px of lift from the head of the keeper" % (fall + 1))
		assert_eq(hero.sim_pos.y, FLOOR_Y, "on the floor")
	assert_eq(hero.run.hearts, hearts, "three falls through it, not one heart: it does not hurt him during a fall")
	# Walking into it on the floor is the contact it always was.
	hero.respawn_at(Vector2i(x - 60, FLOOR_Y))
	_play(hold("R", 30))
	assert_eq(hero.run.hearts, hearts - 1, "a keeper touched from the side hurts as everywhere")


## The hero falls beside a body with Fire held: the forward strike's front frame meets it in the air. Returns the
## per-tick (feet y, yvel) and how often the body was hit.
func _air_strike(at_x: int, with_body: bool) -> Dictionary:
	_look_at(at_x)
	var enemy: EnemyBase = _body_at(Vector2i(at_x + 30, FLOOR_Y), {"hp": 200}) if with_body else null
	hero.respawn_at(Vector2i(at_x, FLOOR_Y - 70))
	_falling(hero, Vector2i(at_x, FLOOR_Y - 70), 16)
	hero.facing = 1
	var trace: Array[Vector2i] = []
	var hit_tick: Array[int] = [0]
	_play(_keys([[14, "F"], [30, ""]]), func(t: int) -> void:
		trace.append(Vector2i(hero.sim_pos.y, hero.yvel))
		if hit_tick[0] == 0 and enemy != null and enemy.hp < 200:
			hit_tick[0] = t)
	var hits: int = (200 - enemy.hp) / Tuning.WEAPON_POWER[Defs.Weapon.CLUB] if enemy != null else 0
	if enemy != null:
		Game.level.remove_child(enemy)
		enemy.free()
	return {"trace": trace, "hits": hits, "hit_tick": hit_tick[0]}


func test_in_a_ward_a_club_hit_on_an_enemy_gives_a_coop_hero_no_pogo() -> void:
	for coop: bool in [false, true]:
		var label: String = "co-op" if coop else "solo"
		_world(coop, _flat_rows())
		_tablet(40, 52)
		for inside: bool in [true, false]:
			var at_x: int = (50 if inside else 82) * 16 + 8
			var free_fall: Dictionary = _air_strike(at_x, false)
			var struck: Dictionary = _air_strike(at_x, true)
			var what: String = "%s, %s the ward" % [label, "in" if inside else "outside"]
			var t: int = int(struck["hit_tick"])
			assert_true(t > 0, what + ": the club hit the enemy while he fell")
			if t <= 0:
				continue
			var falling_at: Vector2i = free_fall["trace"][t - 1]
			var struck_at: Vector2i = struck["trace"][t - 1]
			assert_true(falling_at.y != Tuning.POGO_YVEL + Tuning.GRAVITY and falling_at.y != 0,
					what + ": the set-up - in the air on that tick, by his own fall (yvel %d)" % falling_at.y)
			if coop and inside:
				assert_eq(struck["trace"], free_fall["trace"], what + ": no pogo - the hit left his fall alone, tick for tick")
			else:
				# The pogo: yvel = -80 on the hit (PHYSICS.md 9), one gravity step later at the end of that tick.
				assert_eq(struck_at.y, Tuning.POGO_YVEL + Tuning.GRAVITY, what + ": the 1.0 pogo")
				assert_true(struck_at.x < falling_at.x, what + ": ... lifts him over the plain fall")


func test_a_glider_dive_in_a_ward_counts_and_gives_no_bump() -> void:
	_world(true, _flat_rows())
	_tablet(40, 52)
	for inside: bool in [true, false]:
		var x: int = (50 if inside else 82) * 16 + 8
		var enemy: EnemyBase = _body_at(Vector2i(x, FLOOR_Y), {"hp": 25})
		hero.respawn_at(Vector2i(x - 4, FLOOR_Y - 60))
		hero.set_glider(true)
		_falling(hero, Vector2i(x - 4, FLOOR_Y - 60), 64)
		hero.glide = 1
		var rose: Array[int] = [0]
		var down: Array[bool] = [false]
		_play(hold("D", 30), func(_t: int) -> void:
			if hero.sim_pos.y >= FLOOR_Y:
				down[0] = true  # on the floor (a long fall ends in the landing hop: not counted)
			if hero.yvel < 0 and not down[0]:
				rose[0] += 1)
		var what: String = "in the ward" if inside else "outside the ward"
		if inside:
			assert_eq(enemy.dive_count, 1, what + ": the dive stomp counts against the enemy, once (EnemyBase.on_glider_stomp)")
			assert_eq(rose[0], 0, what + ": no glider bump - he never rose before the floor")
		else:
			assert_true(enemy.dive_count >= 1, what + ": the dive stomp counts")
			assert_true(rose[0] > 0, what + ": the 1.0 glider bump (-96)")
		hero.set_glider(false)
		Game.level.remove_child(enemy)
		enemy.free()


# =================================================================================================================
# R5 - a closed door passes nobody
# =================================================================================================================

## A mover that shoves the hero sideways on one tick, after his own step (as a platform, a carry or a head's slide do).
class Shove:
	extends SimEntity

	var target: PlayerBase = null
	var dx: int = 0
	var at_tick: int = -1

	func _sim_phases() -> PackedInt32Array:
		return PackedInt32Array([Defs.Phase.CONTACT_ENEMIES])

	func _sim_tick(_phase: int) -> void:
		if target != null and Sim.tick == at_tick:
			target.sim_pos.x += dx


## A free-standing door: one column of wall at `door_col` from the floor up, five rows high, under a ceiling.
func _door_rows(door_col: int) -> PackedStringArray:
	var rows: PackedStringArray = PackedStringArray()
	for row: int in GROUND_ROW + WORLD_ROWS_BELOW:
		var line: String = ""
		for col: int in WORLD_COLS:
			var rock: bool = row >= GROUND_ROW or row <= GROUND_ROW - 6 or (col == door_col and row < GROUND_ROW)
			line += TileGrid.CH_SOLID_A if rock else TileGrid.CH_AIR
		rows.append(line)
	return rows


func test_a_hero_shoved_into_a_one_cell_door_is_put_back_in_coop_and_slips_through_in_single_player() -> void:
	var door_col: int = 66
	var face: int = door_col * 16
	for coop: bool in [false, true]:
		var label: String = "co-op" if coop else "solo"
		for shove: int in [11, 14, 17, 21]:
			var world: LevelBase = _world(coop, _door_rows(door_col), Vector2i(face - 10, FLOOR_Y))
			assert_eq(world.grid.side_at(door_col, GROUND_ROW - 1), TileGrid.SIDE_WALL, "the set-up: a door")
			var mover: Shove = Shove.new()
			mover.target = hero
			mover.dx = shove
			mover.at_tick = Sim.tick + 3
			place(world, mover, Vector2i(face, FLOOR_Y))
			var deepest: Array[int] = [hero.sim_pos.x]
			# He touches no key: the 1.0 corner slip carries a hero who is in a wall with no speed to the right, 2 px a
			# tick - through the door.
			_play(hold("", 60), func(_t: int) -> void:
				deepest[0] = maxi(deepest[0], hero.sim_pos.x))
			var what: String = "%s, shoved %d px into the door" % [label, shove]
			if coop:
				assert_true(hero.sim_pos.x < face, what + ": he is on the side he came from (x %d, the door at %d)"
						% [hero.sim_pos.x, face])
				assert_true(deepest[0] < face, what + ": no tick ended with him in the door (deepest %d)" % deepest[0])
			else:
				assert_true(hero.sim_pos.x >= face + 16, what + ": the 1.0 corner slip put him out on the far side (x %d)"
						% hero.sim_pos.x)
			assert_false(hero.dead, what)


func test_a_knock_across_a_door_is_no_way_through() -> void:
	var door_col: int = 66
	var face: int = door_col * 16
	for coop: bool in [false, true]:
		var world: LevelBase = _world(coop, _door_rows(door_col), Vector2i(face - 3, FLOOR_Y))
		var mover: Shove = Shove.new()
		mover.target = hero
		mover.dx = 22  # from 3 px before the door to 3 px beyond it: he is never IN the door at the end of a tick
		mover.at_tick = Sim.tick + 3
		place(world, mover, Vector2i(face, FLOOR_Y))
		_play(hold("", 20))
		if coop:
			assert_eq(hero.sim_pos.x, face - 3, "co-op: thrown across the door, he is put back where he stood")
		else:
			assert_true(hero.sim_pos.x >= face + 16, "solo: beyond the door (1.0 has no such rule; x %d)" % hero.sim_pos.x)


func test_walking_jumping_and_ledges_are_untouched_by_the_door_rule() -> void:
	# The rule acts only when his feet column is a wall in his body row and he came into it sideways. Ordinary play
	# never gets there: the same inputs give the same path with the rule (co-op) and without it (solo).
	var door_col: int = 66
	var face: int = door_col * 16
	var script: Array = [[40, "R"], [12, "RU"], [30, "R"], [20, "L"], [10, "LU"], [30, "R"], [8, "U"], [40, ""]]
	var paths: Array = []
	for coop: bool in [false, true]:
		_world(coop, _door_rows(door_col), Vector2i(face - 120, FLOOR_Y))
		var path: Array[Vector2i] = []
		_play(_keys(script), func(_t: int) -> void:
			path.append(hero.sim_pos))
		paths.append(path)
		assert_true(hero.sim_pos.x <= face - 10, "he was stopped 10 px before the door, as the wall probe stops him")
	assert_eq(paths[1], paths[0], "the door rule changed nothing on the way (190 ticks at a wall)")
	# A ledge he lands on from the side (his feet inside its top cell) is no wall in his body row: he steps up.
	var rows: PackedStringArray = _flat_rows()
	for col: int in range(70, WORLD_COLS):
		rows[GROUND_ROW - 1] = rows[GROUND_ROW - 1].substr(0, col) + TileGrid.CH_SOLID_A + rows[GROUND_ROW - 1].substr(col + 1)
	paths.clear()
	for coop: bool in [false, true]:
		_world(coop, rows, Vector2i(70 * 16 - 60, FLOOR_Y))
		var path: Array[Vector2i] = []
		_play(_keys([[4, "R"], [10, "RU"], [40, "R"]]), func(_t: int) -> void:
			path.append(hero.sim_pos))
		paths.append(path)
		assert_eq(hero.sim_pos.y, FLOOR_Y - 16, "he stands on the step")
		assert_true(hero.sim_pos.x > 70 * 16 + 40)
	assert_eq(paths[1], paths[0], "the same jump onto a step, with and without the rule")


# =================================================================================================================
# R1 again - every start named by the lead designer (wf11_lead_design_to_party.txt #1), and the geyser's launch
# =================================================================================================================

func test_every_start_onto_a_coop_spring_rises_the_plain_launch() -> void:
	# "Feet apex 105 px over the pad's top = at most 115 px over the floor the pad stands on, from EVERY start": walk
	# on (off a ledge), fall on, jump on with Up held, a low / high / forward strike begun on it or a step beside it
	# with Up held from any tick, the hop jump beside it, a strike begun in the flight, a pogo off a hittable in the
	# flight, a glider carrier's jump.
	var pad_x: int = START_X + 120
	var rows: PackedStringArray = _flat_rows()
	# A ledge two rows high left of the pad (to walk and to fall off), its edge 30 px from the pad's middle.
	var ledge_end: int = (pad_x - 30) / 16
	for row: int in [GROUND_ROW - 2, GROUND_ROW - 1]:
		rows[row] = TileGrid.CH_SOLID_A.repeat(ledge_end - 55) .lpad(ledge_end, TileGrid.CH_AIR) + rows[row].substr(ledge_end)
	var ledge_y: int = FLOOR_Y - 32
	var world: LevelBase = _world(true, rows)
	var pad: SpringPad = world.spawn(&"objects/spring", Vector2i(pad_x, FLOOR_Y)) as SpringPad
	var spot: SimEntity = world.spawn(&"objects/hidden_spot", Vector2i(pad_x + 40, FLOOR_Y - 96), {"hits": 50}) as SimEntity
	var worst: Dictionary = {}
	var starts: Dictionary = {
		"walk off a ledge onto it": [[Vector2i(pad_x - 60, ledge_y)], [[[40, "R"], [60, ""]], [[40, "R"], [60, "U"]],
			[[12, "R"], [80, "U"]]]],
		"fall onto it": [[Vector2i(pad_x - 34, ledge_y), Vector2i(pad_x - 40, ledge_y)], [[[8, "R"], [70, "U"]],
			[[8, "R"], [70, ""]], [[8, "R"], [6, "RF"], [70, "U"]], [[8, "R"], [70, "UF"]]]],
		"jump onto it, Up held": [[Vector2i(pad_x - 96, FLOOR_Y), Vector2i(pad_x - 88, FLOOR_Y), Vector2i(pad_x - 80, FLOOR_Y),
			Vector2i(pad_x - 72, FLOOR_Y)], [[[30, "RU"], [60, "U"]], [[30, "RU"], [60, "UF"]], [[30, "RU"], [60, "DF"]]]],
		"a strike begun on it, Up from any tick": [[Vector2i(pad_x - 14, FLOOR_Y), Vector2i(pad_x - 6, FLOOR_Y),
			Vector2i(pad_x, FLOOR_Y), Vector2i(pad_x + 8, FLOOR_Y), Vector2i(pad_x + 14, FLOOR_Y)],
			[[[7, "DF"], [16, "U"], [60, ""]], [[9, "DF"], [16, "U"], [60, ""]], [[11, "DF"], [4, "U"], [70, ""]],
			[[11, "DF"], [16, "RU"], [60, ""]], [[9, "UF"], [16, "U"], [60, ""]], [[9, "F"], [16, "U"], [60, ""]],
			[[2, "DF"], [80, "UF"]], [[30, "DF"], [60, "U"]], [[9, "DF"], [70, "UDF"]]]],
		"a strike begun a step beside it": [[Vector2i(pad_x - 30, FLOOR_Y), Vector2i(pad_x - 22, FLOOR_Y),
			Vector2i(pad_x + 22, FLOOR_Y)], [[[9, "DF"], [20, "RU"], [60, "U"]], [[9, "DF"], [20, "LU"], [60, "U"]],
			[[11, "RDF"], [16, "RU"], [60, ""]], [[9, "F"], [20, "RU"], [60, "U"]]]],
		"the hop jump beside it": [[Vector2i(pad_x - 48, FLOOR_Y), Vector2i(pad_x - 40, FLOOR_Y)],
			[[[9, "DF"], [12, "RU"], [70, "U"]], [[9, "RDF"], [12, "RU"], [70, "U"]]]],
		"a strike in the flight": [[Vector2i(pad_x - 88, FLOOR_Y), Vector2i(pad_x - 80, FLOOR_Y)],
			[[[30, "RU"], [4, "U"], [12, "DF"], [50, ""]], [[30, "RU"], [10, "U"], [12, "F"], [50, ""]],
			[[30, "RU"], [14, "U"], [40, "DF"]], [[30, "RU"], [60, "F"]]]],
		"a pogo off a hittable in the flight": [[Vector2i(pad_x - 88, FLOOR_Y), Vector2i(pad_x - 80, FLOOR_Y)],
			[[[30, "RU"], [6, "R"], [40, "RF"], [30, ""]], [[30, "RU"], [12, "R"], [40, "RF"], [30, ""]],
			[[30, "RU"], [18, "R"], [40, "RF"], [30, ""]]]],
	}
	for name: String in starts:
		var best: int = 0
		for from: Vector2i in starts[name][0]:
			for runs: Array in starts[name][1]:
				best = maxi(best, FLOOR_Y - (from.y - _rise(from, _keys(runs))))
		worst[name] = best
		assert_true(best <= 115, "co-op, %s: at most 115 px over the pad's floor (got %d)" % [name, best])
	# A glider carrier: his jump ignores the jump lock-out (PHYSICS.md 13.2) - not in a spring's flight.
	var glider_best: int = 0
	for from_x: int in [pad_x - 96, pad_x - 88, pad_x - 80, pad_x - 72, pad_x - 64]:
		hero.respawn_at(Vector2i(from_x, FLOOR_Y))
		hero.set_glider(true)
		var top: Array[int] = [FLOOR_Y]
		_play(_keys([[30, "RU"], [60, "U"]]), func(_t: int) -> void:
			top[0] = mini(top[0], hero.sim_pos.y))
		glider_best = maxi(glider_best, FLOOR_Y - top[0])
	hero.set_glider(false)
	# (A folded glider opens in a fall and a gliding hero is no pad's business - this row mostly shows his halved jump.)
	worst["a glider carrier's jump onto it"] = glider_best
	assert_true(glider_best <= 115, "co-op, a glider carrier jumping onto it: at most 115 px (got %d)" % glider_best)
	assert_true(pad.launches > 40, "the pad fired throughout (%d launches)" % pad.launches)
	assert_not_null(spot, "the hittable beside the pad stood there")
	print("    co-op spring, highest feet over the pad's floor by start: %s" % str(worst))


## What the geyser's own launch gives (PlayerBase.launch arms no_jump; the vent takes a hero whose feet are anywhere in
## its 16 px box): "plain" - he stands on the vent; "stack" - a strike begun on it, Up held around the spout tick.
func _geyser_rises(vent: Vector2i, period: int) -> Dictionary:
	var plain: int = 0
	var stack: int = 0
	for phase: int in [0, 3, 6, 9]:
		for runs: Array in [[[period + 40, ""]], [[period + 40, "U"]]]:
			Sim.tick = Sim.tick - (Sim.tick % period) + period + phase
			plain = maxi(plain, _rise(vent, _keys(runs)))
	for lead: int in range(0, 22, 2):
		for runs: Array in [[[9, "DF"], [30, "U"], [60, ""]], [[11, "DF"], [30, "U"], [60, ""]], [[9, "DF"], [9, "DF"], [60, "U"]],
				[[9, "F"], [30, "U"], [60, ""]], [[4, "U"], [9, "DF"], [70, "U"]]]:
			# The spout starts at cycle position period - 12: the strike begins `lead` ticks before it.
			var wait: int = period - 12 - lead
			Sim.tick = Sim.tick - (Sim.tick % period) + period
			var all: Array = [[wait, ""]]
			all.append_array(runs)
			stack = maxi(stack, _rise(vent, _keys(all)))
	return {"plain": plain, "stack": stack}


func test_what_a_geyser_gives_a_hero_who_strikes_on_it() -> void:
	# The lead designer's question (R1): does a strike begun on a blowhole with Up held at its spout tick rise more
	# than the launch's own 105 px? It did - 180 px, for one hero - so PlayerBase.launch holds the flight in a co-op
	# party as a spring does, and a vent launches a co-op hero from its floor.
	var vent: Vector2i = Vector2i(START_X + 120, FLOOR_Y)
	var rises: Array[Dictionary] = []
	for coop: bool in [false, true]:
		var world: LevelBase = _world(coop, _flat_rows())
		var geyser: Geyser = world.spawn(&"objects/geyser", vent, {"period": 60}) as Geyser
		assert_not_null(geyser)
		rises.append(_geyser_rises(vent, 60))
		assert_true(geyser.launches > 5, "the vent launched him (%d)" % geyser.launches)
	print("    geyser (-224): solo plain %d, strike-stack %d px; co-op plain %d, strike-stack %d px" % [rises[0]["plain"],
		rises[0]["stack"], rises[1]["plain"], rises[1]["stack"]])
	# Single-player (Book II solo) is what it was: a hop in the vent box rides on the spout (120 px), strikes begun on
	# the vent add their hops (180 px, eleven rows).
	assert_eq(rises[0]["plain"], 120, "solo: the vent takes him up to 15 px over its floor - 120 px")
	assert_eq(rises[0]["stack"], 180, "solo: the strike hops stack on the launch - 180 px (unchanged)")
	# A hero of a co-op party: the launch starts from the vent's floor and his flight is held - 105 px from every start.
	assert_eq(rises[1]["plain"], 105, "co-op (R1): the launch's own 105 px, hop or no hop")
	assert_eq(rises[1]["stack"], 105, "co-op (R1): a strike begun on the vent adds nothing")


# =================================================================================================================
# R3 again - two bodies at once, and the mount
# =================================================================================================================

func test_falling_through_two_bodies_counts_each_once() -> void:
	_world(true, _flat_rows())
	_tablet(40, 52)
	var x: int = 50 * 16 + 8
	var first: EnemyBase = _body_at(Vector2i(x - 6, FLOOR_Y))
	var second: EnemyBase = _body_at(Vector2i(x + 6, FLOOR_Y))
	_falling(hero, Vector2i(x, FLOOR_Y - 90), 32)
	var hearts: int = hero.run.hearts
	var both: Array[int] = [0]
	var landed: Array[int] = [0]
	var at_grace_end: Array[int] = [hearts]
	_play(hold("", 40), func(t: int) -> void:
		if hero._ward_heads.size() == 2:
			both[0] += 1
		if landed[0] == 0 and hero.grounded and hero.sim_pos.y == FLOOR_Y:
			landed[0] = t
		if landed[0] != 0 and t == landed[0] + PartyTuning.WARD_GRACE_TICKS:
			at_grace_end[0] = hero.run.hearts)
	assert_true(both[0] >= 4, "he fell through both at once (%d ticks in both boxes)" % both[0])
	assert_eq([first.bounce_count, second.bounce_count], [1, 1], "each stomp counted once - no chain climbing a tick at a time")
	assert_true(landed[0] > 0 and landed[0] + PartyTuning.WARD_GRACE_TICKS < 40, "the set-up: he landed between the two and stayed")
	assert_eq(at_grace_end[0], hearts, "neither hurt him during the fall nor in the grace after the landing")
	assert_eq(hero.run.hearts, hearts - 1, "... and staying inside the two bodies costs a heart then (phase 4 Q4: no shelter)")


func test_a_ridden_mount_gets_no_lift_from_a_head_in_a_ward() -> void:
	_world(true, _flat_rows())
	_tablet(40, 52)
	for inside: bool in [true, false]:
		var x: int = (50 if inside else 82) * 16 + 8
		_look_at(x)
		var mount: Mount = Game.level.spawn(&"objects/mount", Vector2i(x - 4, FLOOR_Y - 70)) as Mount
		assert_not_null(mount, "the set-up: a mount")
		hero.respawn_at(Vector2i(x - 4, FLOOR_Y - 70))
		assert_true(mount.seat(hero), "the hero sits on it")
		var enemy: EnemyBase = _body_at(Vector2i(x, FLOOR_Y), {"hp": 200})
		mount.yvel = 48
		mount.grounded = false
		var hearts: int = hero.run.hearts
		var rose: Array[int] = [0]
		var landed: Array[bool] = [false]
		var landed_at: Array[int] = [0]
		var sat_through_grace: Array[bool] = [false]
		_play(hold("", 40), func(t: int) -> void:
			if mount.grounded and not landed[0]:
				landed[0] = true
				landed_at[0] = t
			if landed[0] and t == landed_at[0] + PartyTuning.WARD_GRACE_TICKS:
				sat_through_grace[0] = hero.is_mounted()
			if mount.yvel < 0 and not landed[0]:
				rose[0] += 1)
		var what: String = "in the ward" if inside else "outside the ward"
		if inside:
			assert_eq(rose[0], 0, what + ": the head gave the mount nothing - it fell through")
			assert_eq(hero.run.hearts, hearts, what + ": and the body did not hit its rider during the fall")
			assert_true(sat_through_grace[0], what + ": he still sits when the grace after the landing ends (phase 4 Q4: "
					+ "the mount that stays in the body is hit after it - test_a_mount_standing_in_a_keeper_is_no_shelter_either)")
		else:
			assert_true(rose[0] > 0, what + ": the mount's stomp bounce (MountTuning.STOMP_YVEL)")
		if hero.is_mounted():
			mount.dismount(hero)
		Game.level.remove_child(enemy)
		enemy.free()
		Game.level.remove_child(mount)
		mount.free()


# =================================================================================================================
# Phase 4, Q4 (DESIGN.md G87) - the ward's grace is short: standing inside a keeper is no shelter
# =================================================================================================================

var _hurts: int = 0


func _on_hurt(_hero: PlayerBase, _kind: int, _source: SimEntity) -> void:
	_hurts += 1


## The hero comes down on the head of a keeper (40 px wide, `height` px tall) inside the ward and then does nothing: he
## lands inside its body and stays. With `fall_px` > 0 he is held at that many px a tick while he is in the air (a
## slow fall: many ticks inside the body before the floor). Returns "landed" (the tick he first had the floor under
## him; 0 = never), "air" (ticks in the air with the two boxes overlapping), "air_hurts" (hurts during the fall),
## "hurt_after" (for the tick of the landing and every tick after it: how often that keeper had hurt him by its end),
## "overlap" (the same ticks: whether the boxes overlapped at its end), "count" (the keeper's bounce count at the end).
func _stand_inside(height: int, ticks: int, fall_px: int = 0) -> Dictionary:
	var x: int = 50 * 16 + 8
	var keeper: EnemyBase = _body_at(Vector2i(x, FLOOR_Y), {"hp": 25, "keeper": "door"})
	keeper.set_box(Vector3i(40, height, 20))
	hero.respawn_at(Vector2i(x, FLOOR_Y - height - 24))
	_falling(hero, Vector2i(x, FLOOR_Y - height - 24), 32)
	_hurts = 0
	Events.hero_hurt.connect(_on_hurt)
	var state: Dictionary = {"landed": 0, "air": 0, "air_hurts": 0, "hurt_after": [], "overlap": [], "count": 0}
	_play(hold("", ticks), func(t: int) -> void:
		var touching: bool = Overlap.body(hero, keeper, hero)
		if int(state["landed"]) == 0:
			if hero.grounded and hero.sim_pos.y == FLOOR_Y:
				state["landed"] = t
			else:
				if touching:
					state["air"] = int(state["air"]) + 1
				state["air_hurts"] = _hurts
				if fall_px > 0:
					hero.yvel = fall_px * 16
		if int(state["landed"]) != 0:
			(state["hurt_after"] as Array).append(_hurts)
			(state["overlap"] as Array).append(touching))
	Events.hero_hurt.disconnect(_on_hurt)
	state["count"] = keeper.bounce_count
	Game.level.remove_child(keeper)
	keeper.free()
	return state


func test_the_wards_grace_ends_twelve_ticks_after_the_landing() -> void:
	assert_eq(PartyTuning.WARD_GRACE_TICKS, 12, "the grace (tune through DESIGN)")
	assert_eq(PlayerBase.ward_grace_ticks, PartyTuning.WARD_GRACE_TICKS, "the hero reads the table's value")
	_world(true, _flat_rows())
	_tablet(40, 52)
	var grace: int = PartyTuning.WARD_GRACE_TICKS
	for height: int in [35, 60]:
		var what: String = "a keeper %d px tall" % height
		var run: Dictionary = _stand_inside(height, 90)
		var after: Array = run["hurt_after"]
		assert_true(int(run["landed"]) > 0 and after.size() > grace + 50, what + ": the set-up - he landed inside it and stayed")
		assert_true(int(run["air"]) >= 3, what + ": he fell through its body (%d ticks in its box in the air)" % int(run["air"]))
		assert_eq(run["air_hurts"], 0, what + ": not hurt during the fall")
		assert_eq(after.slice(0, grace + 1), _zeros(grace + 1),
				what + ": no hurt on the tick of the landing and the %d ticks after it" % grace)
		assert_true(bool((run["overlap"] as Array)[grace]), what + ": the set-up - still inside its box on tick %d" % grace)
		assert_eq(after[grace + 1], 1, what + ": tick %d after the landing - the body hurts him as anywhere" % (grace + 1))
		assert_eq(run["count"], 1, what + ": one stomp counted for the fall; standing in it stomps nothing")
		assert_true(int(after[after.size() - 1]) >= 2,
				what + ": and again once his hurt's immunity is over - standing inside a keeper is no shelter (%d hurts in %d ticks)"
				% [int(after[after.size() - 1]), after.size()])
	# The fall itself is covered however long it lasts: 1 px a tick through a 60 px body.
	var slow: Dictionary = _stand_inside(60, 110, 1)
	var slow_after: Array = slow["hurt_after"]
	assert_true(int(slow["air"]) > 3 * grace, "a slow fall: %d ticks in its box before the floor" % int(slow["air"]))
	assert_eq(slow["air_hurts"], 0, "a slow fall: not hurt in the air, whatever the body's height")
	assert_true(int(slow["landed"]) > 0 and slow_after.size() > grace + 1, "a slow fall: the set-up - he landed and stayed")
	if slow_after.size() > grace + 1:
		assert_eq(slow_after.slice(0, grace + 1), _zeros(grace + 1), "a slow fall: the %d ticks count from the landing" % grace)
		assert_eq(slow_after[grace + 1], 1, "a slow fall: and end as after any landing")
	# The rule before G87 ("until the boxes part"): the same stand costs nothing, for as long as he likes - the shelter.
	PlayerBase.ward_grace_ticks = -1
	var before: Dictionary = _stand_inside(35, 90)
	PlayerBase.ward_grace_ticks = PartyTuning.WARD_GRACE_TICKS
	var before_after: Array = before["hurt_after"]
	assert_true(before_after.size() > grace + 50 and bool((before["overlap"] as Array)[before_after.size() - 1]),
			"the old rule: the set-up - he stood inside it to the end")
	assert_eq(before_after[before_after.size() - 1], 0,
			"the old rule sheltered him for ever (this test is red without G87: 0 hurts in %d ticks)" % before_after.size())


func _zeros(count: int) -> Array:
	var zeros: Array = []
	zeros.resize(count)
	zeros.fill(0)
	return zeros


func test_a_hero_who_lands_in_a_keeper_and_walks_on_never_pays() -> void:
	# G87 #3: 12 ticks at the walk cap are 60 px - out of the widest keeper's body (54 px art, 27 px of box here: 54).
	_world(true, _flat_rows())
	_tablet(40, 52)
	var x: int = 50 * 16 + 8
	for keys: String in ["R", "L"]:
		var keeper: EnemyBase = _body_at(Vector2i(x, FLOOR_Y), {"hp": 25, "keeper": "door"})
		keeper.set_box(Vector3i(54, 40, 27))
		hero.respawn_at(Vector2i(x, FLOOR_Y - 70))
		_falling(hero, Vector2i(x, FLOOR_Y - 70), 32)
		_hurts = 0
		Events.hero_hurt.connect(_on_hurt)
		var landed: Array[int] = [0]
		var out: Array[int] = [0]
		_play(hold(keys, 60), func(t: int) -> void:
			if landed[0] == 0 and hero.grounded and hero.sim_pos.y == FLOOR_Y:
				landed[0] = t
			if landed[0] != 0 and out[0] == 0 and not Overlap.body(hero, keeper, hero):
				out[0] = t)
		Events.hero_hurt.disconnect(_on_hurt)
		assert_true(landed[0] > 0 and out[0] > 0, "%s: the set-up - he landed in the middle of it and walked out" % keys)
		assert_true(out[0] - landed[0] <= PartyTuning.WARD_GRACE_TICKS,
				"%s: clear of a 54 px body %d ticks after the landing (the grace is %d)" % [keys, out[0] - landed[0],
				PartyTuning.WARD_GRACE_TICKS])
		assert_eq(_hurts, 0, "%s: a stomp in good faith costs no heart" % keys)
		assert_true(hero._ward_heads.is_empty(), "%s: and the two are strangers again" % keys)
		Game.level.remove_child(keeper)
		keeper.free()


func test_a_mount_standing_in_a_keeper_is_no_shelter_either() -> void:
	_world(true, _flat_rows())
	_tablet(40, 52)
	var x: int = 50 * 16 + 8
	for old_rule: bool in [false, true]:
		PlayerBase.ward_grace_ticks = -1 if old_rule else PartyTuning.WARD_GRACE_TICKS
		_look_at(x)
		var mount: Mount = Game.level.spawn(&"objects/mount", Vector2i(x - 4, FLOOR_Y - 70)) as Mount
		hero.respawn_at(Vector2i(x - 4, FLOOR_Y - 70))
		assert_true(mount != null and mount.seat(hero), "the set-up: the hero sits on a mount")
		var enemy: EnemyBase = _body_at(Vector2i(x, FLOOR_Y), {"hp": 200, "keeper": "door"})
		mount.yvel = 48
		mount.grounded = false
		_hurts = 0
		var hits: Array[int] = [0]
		var landed: Array[int] = [0]
		var first_hit: Array[int] = [0]
		var seated: Array[bool] = [true]
		_play(hold("", 70), func(t: int) -> void:
			if landed[0] == 0 and mount.grounded:
				landed[0] = t
			if seated[0] and not hero.is_mounted():
				seated[0] = false
				hits[0] += 1
				if first_hit[0] == 0:
					first_hit[0] = t)
		var what: String = "the rule before G87" if old_rule else "G87"
		assert_true(landed[0] > 0, what + ": the set-up - the mount came down through the keeper and stands in it")
		if old_rule:
			assert_eq(hits[0], 0, what + ": a rider was sheltered inside the keeper for as long as the mount stood there")
		else:
			assert_true(first_hit[0] > landed[0] + PartyTuning.WARD_GRACE_TICKS,
					what + ": not hit during the fall nor in the %d ticks after the landing (landed %d, hit %d)"
					% [PartyTuning.WARD_GRACE_TICKS, landed[0], first_hit[0]])
			assert_eq(first_hit[0], landed[0] + PartyTuning.WARD_GRACE_TICKS + 1,
					what + ": the keeper's body knocks the rider off on tick %d after the landing" % (PartyTuning.WARD_GRACE_TICKS + 1))
		if hero.is_mounted():
			mount.dismount(hero)
		Game.level.remove_child(enemy)
		enemy.free()
		Game.level.remove_child(mount)
		mount.free()
	PlayerBase.ward_grace_ticks = PartyTuning.WARD_GRACE_TICKS


# =================================================================================================================
# R5 again - from both sides, shoved and carried (the lead designer's 20+ approach variants)
# =================================================================================================================

## A mover that carries the hero sideways for some ticks (a platform, a carrier, an enemy's back).
class Carry:
	extends SimEntity

	var target: PlayerBase = null
	var dx: int = 0
	var from_tick: int = -1
	var ticks: int = 0

	func _sim_phases() -> PackedInt32Array:
		return PackedInt32Array([Defs.Phase.CONTACT_ENEMIES])

	func _sim_tick(_phase: int) -> void:
		if target != null and Sim.tick >= from_tick and Sim.tick < from_tick + ticks:
			target.sim_pos.x += dx


func test_a_hero_carried_into_a_one_cell_column_comes_out_on_the_side_he_came_from() -> void:
	var door_col: int = 66
	var left_face: int = door_col * 16
	var right_face: int = left_face + 16
	var variants: int = 0
	var solo_through: int = 0
	for coop: bool in [false, true]:
		for side: int in [-1, 1]:  # the side he comes from: -1 = from the left
			for speed: int in [2, 3, 5, 9, 13]:
				for keys: String in ["", "L", "R", "U", "D"]:
					var start: int = (left_face - 10) if side < 0 else (right_face + 9)
					var world: LevelBase = _world(coop, _door_rows(door_col), Vector2i(start, FLOOR_Y))
					var mover: Carry = Carry.new()
					mover.target = hero
					mover.dx = -side * speed
					mover.from_tick = Sim.tick + 2
					mover.ticks = 30 / speed + 2
					place(world, mover, Vector2i(left_face, FLOOR_Y))
					var wrong_side: Array[int] = [0]
					_play(hold(keys, 70), func(_t: int) -> void:
						var col: int = hero.sim_pos.x >> 4
						if (side < 0 and col >= door_col) or (side > 0 and col <= door_col):
							wrong_side[0] += 1)
					var came_through: bool = hero.sim_pos.x >= right_face if side < 0 else hero.sim_pos.x < left_face
					if coop:
						variants += 1
						assert_false(came_through, "co-op, from the %s, carried %d px a tick, keys '%s': not through (x %d)"
								% ["left" if side < 0 else "right", speed, keys, hero.sim_pos.x])
						assert_eq(wrong_side[0], 0, "co-op, from the %s, %d px a tick, keys '%s': no tick ended in or beyond the column"
								% ["left" if side < 0 else "right", speed, keys])
					elif came_through:
						solo_through += 1
					assert_false(hero.dead)
	assert_eq(variants, 50, "fifty approaches in co-op: both sides, five speeds, five key states")
	assert_true(solo_through >= 10, "single-player: the 1.0 collision lets a carried hero through the column (%d of 50)" % solo_through)
	print("    one-cell column, carried in: co-op 0 of 50 through; solo %d of 50 through (1.0, unchanged)" % solo_through)


## The keeper door of w9_l2_coop 'brace' as the evidence route met it (build/g3bv/evidence/w9_l2_coop.brace.expert.txt,
## its last 61 ticks): a sunken hall four rows high, at its end a door one cell wide that stands on a step one row
## over the hall's floor, a wind blowing at the door (-112) that dies on the route's tick 703.
func _brace_rows(door_col: int) -> PackedStringArray:
	var rows: PackedStringArray = PackedStringArray()
	for row: int in GROUND_ROW + WORLD_ROWS_BELOW:
		var line: String = ""
		for col: int in WORLD_COLS:
			var rock: bool = row >= GROUND_ROW
			if col <= door_col and row >= GROUND_ROW - 8 and row <= GROUND_ROW - 5:
				rock = true  # the hall's ceiling, down to the door's top cell
			if col == door_col and row >= GROUND_ROW - 4 and row <= GROUND_ROW - 2:
				rock = true  # the door
			if col >= door_col and row == GROUND_ROW - 1:
				rock = true  # the step it stands on, and the floor beyond
			line += TileGrid.CH_SOLID_A if rock else TileGrid.CH_AIR
		rows.append(line)
	return rows


func test_the_brace_door_of_9_2_passes_nobody_in_coop() -> void:
	var door_col: int = 66
	var face: int = door_col * 16
	# The route's ticks 661-721 (keys), from the spot it stood on: 10 px before the door.
	var script: Array = [[1, "R"], [9, "RU"], [13, "R"], [27, "LU"], [3, "D"], [2, "UD"], [4, "R"], [1, "L"], [1, "DF"],
		[30, "R"]]
	var ends: Array[int] = []
	for coop: bool in [false, true]:
		var world: LevelBase = _world(coop, _brace_rows(door_col), Vector2i(face - 10, FLOOR_Y))
		world.wind = -112
		var deepest: Array[int] = [hero.sim_pos.x]
		_play(_keys(script), func(t: int) -> void:
			if t == 43:
				world.wind = 0
			deepest[0] = maxi(deepest[0], hero.sim_pos.x))
		ends.append(hero.sim_pos.x)
		if coop:
			assert_true(hero.sim_pos.x < face, "co-op: he is still in the hall (x %d, the door at %d)" % [hero.sim_pos.x, face])
			assert_true(deepest[0] < face, "co-op: no tick ended with his feet in the door's column (deepest x %d)" % deepest[0])
		else:
			assert_true(hero.sim_pos.x >= face + 16,
					"solo: the 1.0 leak is what it was - the wind's creep, the step's edge and the corner slip carry him through (x %d)"
					% hero.sim_pos.x)
	print("    brace door: solo ends at x %d (door %d..%d), co-op at x %d" % [ends[0], face, face + 15, ends[1]])
