class_name FidelityCase
extends TestCase
## Shared harness of the physics-fidelity tests (it holds no tests itself).
##
## Every scenario runs in a REAL level: the level text is built here, loaded by the world module's loader
## (`scenes/world/level.tscn` + Level.setup_from_text: LevelData, TileGrid.from_rows, visuals, camera, the
## LevelDriver) and the hero is the real `player/player` scene the loader spawns at '@'. Input goes through
## GameInput's scripted source, ticks through Sim.step(), exactly as in the game. Nothing here reuses the player
## module's own test harness.

const LEVEL_SCENE: String = "res://scenes/world/level.tscn"
const LEVEL_ID: StringName = &"test_fidelity_bench"
## The view of a 1280 x 720 window (the original 20 x 11 tile screen plus a quarter row).
const VIEW_ART: Vector2i = Vector2i(640, 360)
const COLS: int = 128
## reference_sim.py GROUND_ROW / START_X: the hero starts at column 62 (8 px into the tile), feet on row 20.
const GROUND_ROW: int = 20
const START_X: int = 1000
const START: Vector2i = Vector2i(START_X, GROUND_ROW * 16)
const START_CELL: Vector2i = Vector2i(62, GROUND_ROW - 1)
## Club-frame names of PHYSICS_REFERENCE.json, indexed by Tuning.ClubFrame.
const CLUB_FRAME_NAMES: Array[String] = [
	"fwd_windup", "overhead", "fwd_front", "high_lowback", "high_backup", "high_front", "low_back", "low_front",
]
const STATE_NAMES: Array[String] = [
	"idle", "walk", "jump", "strike", "crawl", "crouch", "high_strike", "low_strike", "hurt",
]
const HEADER: String = """[meta]
format = 1
id = %s
name = "Fidelity bench"
kind = test
biome = cave
terrain_a = cave/terrain
terrain_b = cave/terrain_stone
background = cave
music = level_cave
ice_a = %d
%s
[tiles]
%s
"""

var level: Level = null
var hero: Player = null
## When true the screen shake is cancelled after the hero's timer step, before step 18 of the tick applies it:
## the reference model has no step 18, so a trace with a heavy landing is compared without the nudge (the nudge
## itself is tested separately against PHYSICS.md 13.3).
var cancel_shake: bool = false
## LevelBase.shake after the hero's timer step (before step 18), one entry per tick since the level was loaded
## (entry i = Sim.tick i + 1): the value reference_sim.py keeps in hero.shake.
var shake_log: PackedInt32Array = PackedInt32Array()
## Logs below are kept since the level was loaded; ticks are Sim.tick values (1 = the first tick played).
## Sim.tick and power of every Events.enemy_hit (weapon hits that did not kill).
var hit_log: Array[Vector2i] = []
## Sim.tick of every Events.player_hurt / player_bounced / player_died.
var hurt_ticks: PackedInt32Array = PackedInt32Array()
var bounce_ticks: PackedInt32Array = PackedInt32Array()
var death_ticks: PackedInt32Array = PackedInt32Array()
## Sim.tick of every Events.player_landed, and whether it was hard.
var landing_ticks: PackedInt32Array = PackedInt32Array()
var landing_hard: Array[bool] = []

var _was_manual: bool = false


func before_each() -> void:
	_was_manual = Sim.manual
	Sim.manual = true
	cancel_shake = false
	_clear_logs()
	Game.new_game(Defs.Difficulty.BEGINNER)
	Game.begin_level(LEVEL_ID)
	# Connected before any level exists, so this runs before the level's own step 18 on Sim.tick_finished.
	Sim.tick_finished.connect(_on_tick_finished)
	Events.enemy_hit.connect(_on_enemy_hit)
	Events.player_hurt.connect(_on_player_hurt)
	Events.player_bounced.connect(_on_player_bounced)
	Events.player_died.connect(_on_player_died)
	Events.player_landed.connect(_on_player_landed)


func after_each() -> void:
	Sim.tick_finished.disconnect(_on_tick_finished)
	Events.enemy_hit.disconnect(_on_enemy_hit)
	Events.player_hurt.disconnect(_on_player_hurt)
	Events.player_bounced.disconnect(_on_player_bounced)
	Events.player_died.disconnect(_on_player_died)
	Events.player_landed.disconnect(_on_player_landed)
	GameInput.clear_scripted()
	Sim.stop()
	Sim.manual = _was_manual
	if level != null and is_instance_valid(level):
		level.free()
	level = null
	hero = null
	Game.set_weapon(Defs.Weapon.CLUB)
	Game.begin_level(&"")


# --- Worlds as level-file rows -----------------------------------------------------------------------------------

## `rows` rows of COLS cells: air above `ground_row`, solid ground ('#') from it down. rows < 0: ground + 4.
func flat_rows(ground_row: int = GROUND_ROW, rows: int = -1) -> PackedStringArray:
	var count: int = ground_row + 4 if rows < 0 else rows
	var lines: PackedStringArray = PackedStringArray()
	for row: int in count:
		lines.append(("#" if row >= ground_row else ".").repeat(COLS))
	return lines


## reference_sim.ledge_world as level rows: ground from `upper_row` left of `edge_col`, `drop` tiles lower from
## it on; the cliff face is solid ground (a wall).
func ledge_rows(edge_col: int, drop: int, upper_row: int = GROUND_ROW) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	for row: int in upper_row + drop + 4:
		var line: String = ""
		for col: int in COLS:
			line += "#" if row >= (upper_row if col < edge_col else upper_row + drop) else "."
		lines.append(line)
	return lines


## Write `text` into the rows from (col, row) on.
func put(lines: PackedStringArray, col: int, row: int, text: String) -> void:
	var line: String = lines[row]
	lines[row] = line.substr(0, col) + text + line.substr(col + text.length())


## Load the rows (with '@' at `start_cell`) through the world loader as a fresh level and return its hero.
## `meta` holds extra [meta] lines (e.g. a wind script).
func load_world(
		lines: PackedStringArray, start_cell: Vector2i = START_CELL, ice: int = 0, meta: String = ""
) -> Player:
	if level != null and is_instance_valid(level):
		level.free()
	hero = null
	var rows: PackedStringArray = lines.duplicate()
	put(rows, start_cell.x, start_cell.y, "@")
	level = (load(LEVEL_SCENE) as PackedScene).instantiate() as Level
	level.setup_from_text(LEVEL_ID, HEADER % [LEVEL_ID, ice, meta, "\n".join(rows)])
	add_node(level)
	level.set_view_size(VIEW_ART)
	hero = level.player as Player
	assert_not_null(hero, "the loader spawned the hero scene at '@'")
	_clear_logs()
	return hero


## Put the hero somewhere else (the respawn call the world uses) and centre the camera on him again.
func place_hero(pos: Vector2i) -> void:
	hero.respawn_at(pos)
	level.snap_camera()


## reference_sim.running_hero: facing `direction` at full walking speed.
func set_running(direction: int) -> void:
	hero.facing = direction
	hero.xvel = direction * Tuning.WALK_CAP


## A stationary enemy (the shared EnemyBase rules, no archetype AI) with a box of `size` (w, h) whose feet are
## at `pos`. `hp` large = it survives every hit; `hurts` = it hurts the hero on contact.
func add_dummy(pos: Vector2i, size: Vector2i, hp: int = 1000, hurts: bool = true) -> EnemyBase:
	var enemy: EnemyBase = EnemyBase.new()
	enemy.spawn_setup(pos, {"hp": hp})
	level.get_container("enemies").add_child(enemy)
	enemy.set_box(Vector3i(size.x, size.y, size.x / 2))
	enemy.contact_hurts = hurts
	return enemy


# --- Input and recording -------------------------------------------------------------------------------------------

## Run-length keys ([[ticks, "LRUDF"], ...], the reference format) to one flags value per tick. Own parser: the
## letters are the flags of PHYSICS.md 4.1.
func flags_of(runs: Array) -> PackedInt32Array:
	var result: PackedInt32Array = PackedInt32Array()
	for entry: Variant in runs:
		var pair: Array = entry
		var value: int = 0
		var keys: String = str(pair[1])
		for i: int in keys.length():
			match keys[i]:
				"L":
					value |= Defs.IN_LEFT
				"R":
					value |= Defs.IN_RIGHT
				"U":
					value |= Defs.IN_UP
				"D":
					value |= Defs.IN_DOWN
				"F":
					value |= Defs.IN_FIRE
				"K":
					value |= Defs.IN_LOOK
		for t: int in int(pair[0]):
			result.append(value)
	return result


## `count` ticks of the same keys.
func hold(keys: String, count: int) -> PackedInt32Array:
	return flags_of([[count, keys]])


## Play one tick per flags value through GameInput's scripted source and Sim.step(); one snapshot per tick.
func run(flags: PackedInt32Array) -> Array[Dictionary]:
	var first: int = Sim.tick + 1
	GameInput.set_scripted(func(tick: int) -> int:
		var index: int = tick - first
		return flags[index] if index >= 0 and index < flags.size() else 0
	)
	var rows: Array[Dictionary] = []
	for i: int in flags.size():
		Sim.step(1)
		rows.append(snapshot())
	GameInput.clear_scripted()
	return rows


## The hero's state at the end of the current tick.
func snapshot() -> Dictionary:
	var club: String = ""
	var rel: Array = []
	if hero.club_box_active and hero.club_frame >= 0:
		club = CLUB_FRAME_NAMES[hero.club_frame]
		var box: Rect2i = hero.club_box
		rel = [box.position.x - hero.sim_pos.x, box.end.x - hero.sim_pos.x,
				box.position.y - hero.sim_pos.y, box.end.y - hero.sim_pos.y]
	return {
		"tick": Sim.tick, "x": hero.sim_pos.x, "y": hero.sim_pos.y, "xvel": hero.xvel, "yvel": hero.yvel,
		"state": hero.state, "handler": hero.handler, "facing": hero.facing, "fall_ticks": hero.fall_ticks,
		"no_jump": hero.no_jump, "jump_ticks": hero.jump_ticks, "swing_lock": hero.swing_lock,
		"charge": hero.charge, "grounded": 1 if hero.grounded else 0, "club": club, "club_rel": rel,
		"club_power": hero.club_power if club != "" else -1, "hit_timer": hero.hit_timer,
		"dead": 1 if hero.dead else 0,
	}


## One field of every row (optionally only the first `count`).
func column(rows: Array[Dictionary], key: String, count: int = -1) -> Array:
	var values: Array = []
	var size: int = rows.size() if count < 0 else mini(count, rows.size())
	for i: int in size:
		values.append(rows[i][key])
	return values


## x of every row relative to `origin_x` (reference "x"), first `count` rows.
func rel_x(rows: Array[Dictionary], origin_x: int, count: int = -1) -> Array:
	var values: Array = []
	for value: Variant in column(rows, "x", count):
		values.append(int(value) - origin_x)
	return values


## Height above `origin_y`, positive up (reference "height"), first `count` rows.
func heights(rows: Array[Dictionary], origin_y: int, count: int = -1) -> Array:
	var values: Array = []
	for value: Variant in column(rows, "y", count):
		values.append(origin_y - int(value))
	return values


## reference_sim.first_landing from the hero's own state: the first tick >= 2 that ends grounded after a tick
## that ended in the air (1-based within the rows; 0 = none).
func landing_tick(rows: Array[Dictionary]) -> int:
	for i: int in range(1, rows.size()):
		if int(rows[i]["grounded"]) == 1 and int(rows[i - 1]["grounded"]) == 0:
			return i + 1
	return 0


## Integer copy of a JSON array (JSON numbers are floats).
func ints(values: Variant) -> Array:
	var result: Array = []
	for value: Variant in values:
		result.append(int(value))
	return result


func _clear_logs() -> void:
	shake_log = PackedInt32Array()
	hit_log = []
	hurt_ticks = PackedInt32Array()
	bounce_ticks = PackedInt32Array()
	death_ticks = PackedInt32Array()
	landing_ticks = PackedInt32Array()
	landing_hard = []


func _on_tick_finished(_tick: int) -> void:
	if level == null or not is_instance_valid(level):
		return
	shake_log.append(level.shake)
	if cancel_shake:
		level.shake = 0


func _on_enemy_hit(_enemy: EnemyBase, power: int) -> void:
	hit_log.append(Vector2i(Sim.tick, power))


func _on_player_hurt(_kind: int, _source: SimEntity) -> void:
	hurt_ticks.append(Sim.tick)


func _on_player_bounced(_target: SimEntity, _multiplier: int) -> void:
	bounce_ticks.append(Sim.tick)


func _on_player_died(_cause: StringName) -> void:
	death_ticks.append(Sim.tick)


func _on_player_landed(hard: bool, _shake: bool) -> void:
	landing_ticks.append(Sim.tick)
	landing_hard.append(hard)
