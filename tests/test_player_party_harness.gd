class_name PartyTestCase
extends PlayerTestCase
## Shared harness of the hero's party tests (it holds no tests itself): two heroes of a co-op or versus run on a flat
## world whose view the test sets, per-slot input playback, and a minimal stand-in of world-A's PartyDriver that runs
## exactly the steps the hero side offers it (PHYSICS.md C.0 table): the edge-wall fence in WEAPONS, (a) the Totem
## carry and (b) the head contacts in PLAYER after both heroes moved, and a death toss that ends in an egg while a
## partner plays. The real driver (scripts/world/party_driver.gd) is world-A's and has its own tests; these tests pin
## the hero's side of every rule.

const P1_START: Vector2i = Vector2i(START_X, GROUND_ROW * 16)
const P2_START: Vector2i = Vector2i(START_X + 64, GROUND_ROW * 16)


## A level whose view stays where the test puts it (the tribe camera is world-A's): [member view] in logical px.
class PartyLevel:
	extends LevelBase

	var view: Rect2i = Rect2i(0, 0, Tuning.VIEW_W, Tuning.VIEW_H)

	func get_view_rect() -> Rect2i:
		return view


## The hero-side steps of the PartyDriver, in their phases, registered after the heroes.
class DuoDriver:
	extends SimEntity

	## Head contacts made on the last PLAYER step: [hero slot, partner slot, PlayerBase.HEAD_*].
	var contacts: Array[Vector3i] = []
	## False = no edge walls (a test of something else that crosses the view).
	var fence: bool = true

	func _sim_phases() -> PackedInt32Array:
		return PackedInt32Array([Defs.Phase.WEAPONS, Defs.Phase.PLAYER])

	func _sim_tick(phase: int) -> void:
		var level: LevelBase = Game.level
		if level == null:
			return
		if phase == Defs.Phase.WEAPONS:
			var walls: Vector2i = level.get_edge_walls()
			if not fence or walls == Vector2i.ZERO:
				return
			for hero: PlayerBase in level.contact_order():
				if not hero.dead and not hero.is_down():
					hero.clear_fence()
					hero.fence_x(walls.x, walls.y)
			return
		contacts.clear()
		if Game.mode != Defs.GameMode.COOP:
			return  # versus heads are the referee's stomps
		for hero: PlayerBase in level.contact_order():
			if hero.totem_carrier != null:
				hero.carry_totem()
		for hero: PlayerBase in level.contact_order():
			if not hero.can_land_on_partner():
				continue
			for other: PlayerBase in level.contact_order():
				if other == hero or other.dead:
					continue
				var result: int = hero.land_on_partner(other)
				if result != PlayerBase.HEAD_NONE:
					contacts.append(Vector3i(hero.slot, other.slot, result))
					break

	## LevelBase.hero_death_finished asks it: an egg where the toss started while a partner plays.
	func handle_hero_death(hero: PlayerBase) -> bool:
		var level: LevelBase = Game.level
		for other: PlayerBase in level.contact_order():
			if other != hero and not other.dead and not other.is_down():
				hero.go_down(hero.death_cause)
				hero.teleport(hero.death_origin)
				return true
		return false


var p1: Player = null
var p2: Player = null
var driver: DuoDriver = null
var _party_level: PartyLevel = null


func after_each() -> void:
	super.after_each()
	p1 = null
	p2 = null
	driver = null
	_party_level = null
	Game.new_game(Defs.Difficulty.BEGINNER)


## A two-hero run of `mode` (Defs.GameMode) on a flat world (or `rows` level-file rows), P1 at `p1_at`, P2 at `p2_at`,
## the view at the left of the world around the heroes, and the stand-in driver when `with_driver`.
func party(mode: int = Defs.GameMode.COOP, p1_at: Vector2i = P1_START, p2_at: Vector2i = P2_START,
		with_driver: bool = true, rows: PackedStringArray = PackedStringArray()) -> void:
	Game.start_run(Defs.Difficulty.BEGINNER, mode, 2)
	Game.begin_level(&"test_player_party")
	if level != null and is_instance_valid(level):
		level.free()
	level = null
	if _party_level != null and is_instance_valid(_party_level):
		_party_level.free()
	var party_level: PartyLevel = PartyLevel.new()
	_party_level = party_level
	party_level.level_id = &"test_player_party"
	if rows.is_empty():
		party_level.grid = _flat_grid()
	else:
		party_level.grid = TileGrid.from_rows(rows)
	add_node(party_level)
	party_level.view = Rect2i((p1_at.x / 16 - 8) * 16, (GROUND_ROW - 9) * 16, Tuning.VIEW_W, Tuning.VIEW_H)
	p1 = _hero_at(party_level, p1_at, 0)
	p2 = _hero_at(party_level, p2_at, 1)
	hero = p1
	if with_driver:
		driver = DuoDriver.new()
		party_level.register_party_driver(driver)


## The party level (typed).
func party_level() -> PartyLevel:
	return Game.level as PartyLevel


func _flat_grid() -> TileGrid:
	var rows: int = GROUND_ROW + WORLD_ROWS_BELOW
	var grid: TileGrid = TileGrid.new(WORLD_COLS, rows)
	for row: int in rows:
		for col: int in WORLD_COLS:
			var solid: bool = row >= GROUND_ROW
			grid.set_props(col, row, TileGrid.FLOOR_SOLID if solid else 0, 1 if solid else 0, 0, TileGrid.PROFILE_NONE)
	return grid


func _hero_at(party_level: LevelBase, pos: Vector2i, slot: int) -> Player:
	var scene: PackedScene = load(PLAYER_SCENE) as PackedScene
	var p: Player = scene.instantiate() as Player
	place(party_level, p, pos, {"slot": slot})
	p.respawn_at(pos)
	return p


## Run one tick per entry: `entries` like [[ticks, "P1KEYS|P2KEYS"], ...]; `each` gets the 1-based tick after every
## tick.
func play_party(entries: Array, each: Callable = Callable()) -> void:
	var streams: Array[PackedInt32Array] = [PackedInt32Array(), PackedInt32Array()]
	for entry: Variant in entries:
		var parts: PackedStringArray = str(entry[1]).split("|")
		for slot: int in 2:
			var flags: int = GameInput.keys_to_flags(parts[slot] if slot < parts.size() else "")
			for i: int in int(entry[0]):
				streams[slot].append(flags)
	var first: int = Sim.tick + 1
	for slot: int in 2:
		var flags: PackedInt32Array = streams[slot]
		GameInput.set_scripted_slot(slot, func(tick: int) -> int:
			var index: int = tick - first
			return flags[index] if index >= 0 and index < flags.size() else 0
		)
	for i: int in streams[0].size():
		Sim.step(1)
		if each.is_valid():
			each.call(i + 1)
	GameInput.clear_scripted()


## PARTY_REFERENCE.json (docs/spec/reference_party.py), cached.
static var _party_ref: Dictionary = {}


static func party_reference() -> Dictionary:
	if _party_ref.is_empty():
		var text: String = FileAccess.get_file_as_string("res://docs/spec/PARTY_REFERENCE.json")
		var parsed: Variant = JSON.parse_string(text)
		if parsed is Dictionary:
			_party_ref = parsed
	return _party_ref
