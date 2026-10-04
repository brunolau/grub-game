class_name PlayerTestCase
extends TestCase
## Shared harness of the player tests (it holds no tests itself): the worlds of docs/spec/reference_sim.py built
## property by property, a level whose view follows the hero, the hero scene, and per-tick input playback.

const PLAYER_SCENE: String = "res://scenes/player/player.tscn"
## reference_sim.py START_X / GROUND_ROW.
const START_X: int = 1000
const GROUND_ROW: int = 20
const START: Vector2i = Vector2i(START_X, GROUND_ROW * 16)
const WORLD_COLS: int = 96
const WORLD_ROWS_BELOW: int = 4
## Names of the club frames in PHYSICS_REFERENCE.json, indexed by Tuning.ClubFrame.
const CLUB_FRAME_NAMES: Array[String] = [
	"fwd_windup", "overhead", "fwd_front", "high_lowback", "high_backup", "high_front", "low_back", "low_front",
]
const STATE_NAMES: Array[String] = [
	"idle", "walk", "jump", "strike", "crawl", "crouch", "high_strike", "low_strike", "hurt",
]


## A bare level whose view (320 x 180 logical px) is centred on the hero, like a camera that always follows
## him. The reference model has no screen-shake step, so shakes are recorded instead of applied unless
## `apply_shakes` is set.
class FollowLevel:
	extends LevelBase

	var apply_shakes: bool = false
	var shake_requests: PackedInt32Array = PackedInt32Array()

	func get_view_rect() -> Rect2i:
		if player == null:
			return Rect2i(0, 0, Tuning.VIEW_W, Tuning.VIEW_H)
		return Rect2i(
			player.sim_pos.x - Tuning.VIEW_W / 2, player.sim_pos.y - Tuning.VIEW_H / 2, Tuning.VIEW_W, Tuning.VIEW_H
		)

	func request_shake(amount: int) -> void:
		shake_requests.append(amount)
		if apply_shakes:
			super.request_shake(amount)


var level: FollowLevel = null
var hero: Player = null
## Ticks (1-based within the last play() call) on which Events.player_landed fired, and whether it was hard.
var landing_ticks: PackedInt32Array = PackedInt32Array()
var landing_hard: Array[bool] = []
## 1-based index (within the running play() call) of the tick being simulated; valid inside signal handlers.
var current_tick: int = 0


func before_each() -> void:
	Game.new_game(Defs.Difficulty.BEGINNER)
	Game.begin_level(&"test_player")
	landing_ticks = PackedInt32Array()
	landing_hard = []
	if not Events.player_landed.is_connected(_on_landed):
		Events.player_landed.connect(_on_landed)


func after_each() -> void:
	if Events.player_landed.is_connected(_on_landed):
		Events.player_landed.disconnect(_on_landed)
	level = null
	hero = null


# --- Worlds (PHYSICS.md 11.1 property tables, exactly as reference_sim.py builds them) --------------------------------

## A world from property callables: floor(col, row) -> FLOOR, side(col, row) -> SIDE, ceiling(col, row) -> FLAGS.
func make_world(rows: int, floor_of: Callable, side_of: Callable, ceiling_of: Callable, ice: int = 0) -> FollowLevel:
	var grid: TileGrid = TileGrid.new(WORLD_COLS, rows)
	grid.ice_a = ice
	for row: int in rows:
		for col: int in WORLD_COLS:
			grid.set_props(
				col, row, int(floor_of.call(col, row)), int(side_of.call(col, row)), int(ceiling_of.call(col, row)),
				TileGrid.PROFILE_NONE
			)
	return _new_level(grid)


## reference_sim.flat_world: FLOOR `floor_value` and SIDE 1 on every tile with row >= ground_row.
func world_flat(ground_row: int = GROUND_ROW, floor_value: int = TileGrid.FLOOR_SOLID) -> FollowLevel:
	return make_world(
		ground_row + WORLD_ROWS_BELOW,
		func(_c: int, r: int) -> int: return floor_value if r >= ground_row else 0,
		func(_c: int, r: int) -> int: return 1 if r >= ground_row else 0,
		func(_c: int, _r: int) -> int: return 0,
		maxi(floor_value - TileGrid.FLOOR_SOLID, 0)
	)


## reference_sim.ledge_world: solid from `upper_row` left of `edge_col`, `drop_tiles` lower from it on.
func world_ledge(edge_col: int, drop_tiles: int, upper_row: int = GROUND_ROW) -> FollowLevel:
	var top_of: Callable = func(c: int) -> int: return upper_row if c < edge_col else upper_row + drop_tiles
	return make_world(
		upper_row + drop_tiles + WORLD_ROWS_BELOW,
		func(c: int, r: int) -> int: return 1 if r >= int(top_of.call(c)) else 0,
		func(c: int, r: int) -> int: return 1 if r >= int(top_of.call(c)) else 0,
		func(_c: int, _r: int) -> int: return 0
	)


## Flat floor plus a wall (SIDE only) on every column from `first_col` to `last_col`, above the floor.
func world_wall(first_col: int, last_col: int) -> FollowLevel:
	return make_world(
		GROUND_ROW + WORLD_ROWS_BELOW,
		func(_c: int, r: int) -> int: return 1 if r >= GROUND_ROW else 0,
		func(c: int, r: int) -> int: return 1 if c >= first_col and c <= last_col and r < GROUND_ROW else 0,
		func(_c: int, _r: int) -> int: return 0
	)


## Flat floor (no SIDE) plus a ceiling-only row `ceiling_row` with flag `ceiling_value`.
func world_ceiling(ceiling_row: int, ceiling_value: int = TileGrid.CEILING_SOLID) -> FollowLevel:
	return make_world(
		GROUND_ROW + WORLD_ROWS_BELOW,
		func(_c: int, r: int) -> int: return 1 if r >= GROUND_ROW else 0,
		func(_c: int, _r: int) -> int: return 0,
		func(_c: int, r: int) -> int: return ceiling_value if r == ceiling_row else 0
	)


## A level from level-file rows (slopes, hazards ...), with the follow view.
func world_rows(rows: PackedStringArray, ice_a: int = 0) -> FollowLevel:
	return _new_level(TileGrid.from_rows(rows, ice_a))


## Replace the current world (one level and one hero at a time: a leftover hero would keep ticking).
func _new_level(grid: TileGrid) -> FollowLevel:
	if level != null and is_instance_valid(level):
		level.free()
	hero = null
	level = FollowLevel.new()
	level.level_id = &"test_player"
	level.grid = grid
	add_node(level)
	return level


# --- Hero -------------------------------------------------------------------------------------------------------------

## The hero scene, placed and spawned at `pos` (feet point).
func spawn_hero(pos: Vector2i = START) -> Player:
	var scene: PackedScene = load(PLAYER_SCENE) as PackedScene
	hero = scene.instantiate() as Player
	place(level, hero, pos)
	hero.respawn_at(pos)
	return hero


## reference_sim.running_hero: facing `direction` at full walking speed.
func spawn_running_hero(direction: int, pos: Vector2i = START) -> Player:
	spawn_hero(pos)
	hero.facing = direction
	hero.xvel = direction * Tuning.WALK_CAP
	return hero


## reference_sim.airborne_hero: already falling (yvel 16, no_jump armed) `above_px` over the floor.
func spawn_airborne_hero(xvel: int, direction: int, above_px: int = 400) -> Player:
	spawn_hero(START - Vector2i(0, above_px))
	hero.facing = direction
	hero.xvel = xvel
	hero.yvel = Tuning.GRAVITY
	hero.no_jump = Tuning.NO_JUMP_TICKS
	hero.fall_ticks = 1
	hero.grounded = false
	return hero


# --- Input playback ---------------------------------------------------------------------------------------------------

## Run one tick per entry of `flags` (Defs.IN_* masks). After every tick `each` is called with the 1-based tick.
func play(flags: PackedInt32Array, each: Callable = Callable()) -> void:
	var first: int = Sim.tick + 1
	landing_ticks = PackedInt32Array()
	landing_hard = []
	GameInput.set_scripted(func(tick: int) -> int:
		var index: int = tick - first
		return flags[index] if index >= 0 and index < flags.size() else 0
	)
	for i: int in flags.size():
		current_tick = i + 1
		Sim.step(1)
		if each.is_valid():
			each.call(i + 1)
	GameInput.clear_scripted()


## `count` ticks of the same input keys ("RU", "" = nothing held).
func hold(keys: String, count: int) -> PackedInt32Array:
	var flags: PackedInt32Array = PackedInt32Array()
	var value: int = GameInput.keys_to_flags(keys)
	for i: int in count:
		flags.append(value)
	return flags


## Inputs for "UP held for the first k ticks (k < 0: always), `direction` held throughout".
func jump_flags(k: int, ticks: int, direction: String = "") -> PackedInt32Array:
	var flags: PackedInt32Array = PackedInt32Array()
	for t: int in range(1, ticks + 1):
		flags.append(GameInput.keys_to_flags(direction + ("U" if k < 0 or t <= k else "")))
	return flags


## Per-tick rows like reference_sim.run(): x relative to the start, height above the start (positive up).
func run_rows(flags: PackedInt32Array) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var origin: Vector2i = hero.sim_pos
	play(flags, func(_tick: int) -> void:
		rows.append({
			"x": hero.sim_pos.x - origin.x, "height": origin.y - hero.sim_pos.y, "xvel": hero.xvel,
			"yvel": hero.yvel, "state": hero.state, "handler": hero.handler, "grounded": hero.grounded,
			"fall_ticks": hero.fall_ticks, "no_jump": hero.no_jump, "charge": hero.charge,
			"club_frame": hero.club_frame, "club_box": hero.club_box, "club_power": hero.club_power,
		})
	)
	return rows


## One column of run_rows() output.
func column(rows: Array[Dictionary], key: String, count: int = -1) -> Array:
	var values: Array = []
	var size: int = rows.size() if count < 0 else mini(count, rows.size())
	for i: int in size:
		values.append(rows[i][key])
	return values


## First landing on tick 2 or later (reference_sim.first_landing), 0 when there was none.
func first_landing() -> int:
	for tick: int in landing_ticks:
		if tick >= 2:
			return tick
	return 0


## True when the landing on `tick` was a hard landing.
func landed_hard(tick: int) -> bool:
	for i: int in landing_ticks.size():
		if landing_ticks[i] == tick:
			return landing_hard[i]
	return false


## Apex of a run: the highest height before the landing tick.
func apex(rows: Array[Dictionary], landing: int) -> int:
	var best: int = 0
	for i: int in mini(landing, rows.size()):
		best = maxi(best, int(rows[i]["height"]))
	return best


func _on_landed(hard: bool, _shake: bool) -> void:
	landing_ticks.append(current_tick)
	landing_hard.append(hard)
