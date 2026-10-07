class_name CoopSearch
extends RefCounted
## The solo-impossibility search of co-op gates (docs/expansion/DESIGN.md D.8 #3-#4, LEVEL_DESIGN.md 15.7.6,
## PLAN.md 8 V3.c). Owner: world-B (PLAN.md P1.7 v1, P2.4 v2). Called by tests/test_coop_gates.gd for every
## `objects/x2_tablet gate=<name> far=c,r` of every co-op file and by `tools/validate_levels.gd -- --coop`.
##
## [method search_gate] proves (as far as a bounded search can) that ONE player cannot get from the gate's tablet (and
## from the last checkpoint before it) to the tablet's `far` cell:
##  1. Static rules first (LevelValidator, the content rules of co-op files): nothing to climb on within reach of a
##     ledge gate (enemies, springs, geysers, vines, bark boards, gliders, platforms, mounts, pogo ladders), no bark
##     board near any gate, keeper and Guard halls 4 rows high, plates 8+ tiles from their doors. A broken static rule
##     counts as "reached" (detail: the rule).
##  2. The search (v2): the REAL hero (scenes/player/player.tscn, the physics the route proofs replay) in a SEARCH
##     WORLD - the file's grid with the file's entities of the gate's columns (enemies with their traits, plates,
##     doors, drums, keepers, pots, boulders, see-saws, springs, vines, bark boards, platforms, Chomper and his pen,
##     weapons; not the props, signs, checkpoints, exits, team gates, food or the presentation zones), in a co-op game
##     of two: the second hero is the partner of a player who plays alone - an EGG that drifts after him (the
##     default), or an IDLE hatched hero that never presses anything (the `partner` macros: he stands where the egg
##     was walked and hatched). So the co-op rules run as in the game (traits, the egg bounce of -64, no Shoulder Hop
##     off an inactive partner, the Totem Ride on an idle one). Driven by input macros from every resting point it
##     reaches, breadth first, inside the gate's area (its tablet and far cell grown by one view): walks, jumps of
##     every kind, crawls, drops, waits, strikes (forward, low, in the air, the pogo), throws of every special (axe,
##     swirling axe, spear: drums, keepers, plates' doors, bark boards), the partner moves. Bounds: BOUND_TICKS of
##     game time per path, MAX_NODES resting points. The far cell is reached when the hero's feet point is in it on
##     any tick (mid-air too).
##     World state: every macro starts from the level-file state (Level.reset_entities: doors closed, plates up,
##     enemies at their posts and alive, the egg behind the hero) - unless the path so far CHANGED the world for good:
##     a resting point is a node of (place, world signature), where the signature lists what a reset would undo that
##     the player could use (a dead keeper, trait or bond enemy, a pushed pot or boulder, a sprung pot, a pressed
##     plate or a door still open, a see-saw tipped, a spear step or spring standing, Chomper ridden or moved, the
##     glider taken, changed cells - not a plain enemy's death, which a strike-walk repeats on its way, nor spots and
##     dropped items). A changed node replays its path from the last unchanged one (same seed, same inputs: the same
##     world; at most MAX_PREFIX_TICKS), so changes carry from move to move exactly. Where the partner stands is not
##     part of it: a `partner` move places him afresh where the hero stands (the player can walk his egg anywhere and
##     hatch it), a changed node made by one keeps him there for its replay.
##  3. Windows (D.8 #4): every twin window and daze near the gate with the solo minimum the search measures on the
##     bare grid (nothing in the way: the least a hero needs) - drum bonds and enemy bonds (the ticks one hero needs
##     from striking one member to the other: running between their strike spots, or 0 when a thrown special from
##     beside one crosses the other), `daze` records (the real hero's ticks from a head bounce to his first damaging
##     box on a still target), timed plates (the ticks from the plate to its door against the time the door stays
##     open). The window reported is the record's own: the difficulty's value capped by its `window=` (enemies-A's
##     CoopTraits.capped_window; a bond the smallest cap of its members). test_coop_gates demands window <= solo_min
##     - 4.
## The cheap flood of [method flood_reaches] (no chain of feet cells on the grid at rest) is kept as a diagnostic
## (result "flood"); it never decides a gate: the search runs on every gate.
## Limits (v2): the moving things (walking enemies, platforms, geysers) start every macro in their level-file phase,
## so a timing that needs a walker or a lift somewhere else than its post at the start of a move is only found when
## the path got there through changed nodes; macros start from rest (momentum between macros is not carried); the
## bound is per resting point, not a full input-space search; the hero holds one special per move (each special is
## tried), not two.

## Game ticks a single hero is allowed per path (LEVEL_DESIGN.md 15.7.6: 1 457 ticks *(tune)*).
const BOUND_TICKS: int = 1457
## Resting points explored at most per search (a compute bound).
const MAX_NODES: int = 220
## After a macro's inputs end the hero has this long to come to rest (else the macro is dropped).
const SETTLE_TICKS: int = 48
## Resting points closer than this (px, on the same y) are one node.
const KEY_PX: int = 8
## A ledge gate's area and the windows' reach: the tablet and far cell grown by one view (LEVEL_DESIGN.md 15.7.7).
const AREA_COLS: int = Tuning.VIEW_COLS
const AREA_ROWS: int = Tuning.VIEW_ROWS
## Error fragments of the validator that make a gate solvable alone (the static rules of LEVEL_DESIGN.md 15.7.6).
const STATIC_FRAGMENTS: Array[String] = [" hall of ", " tiles from its door", "pogo ladder"]
const PLAYER_ID: StringName = &"player/player"
const STRIKE_FRAMES: int = 9    ## a strike connects within one swing
## The slot of the partner hero of the search world (the player's absent friend).
const PARTNER_SLOT: int = 1
## The partner at the start of a macro: an egg drifting after the hero, or an idle hatched hero in front of him.
const PARTNER_EGG: int = 0
const PARTNER_IDLE: int = 1
## The idle partner stands this far in front of the hero when a `partner` macro starts (px; 0 = on his spot: heroes
## pass through each other, so a jump straight up lands on the partner's head).
const PARTNER_FRONT_PX: int = 0
## Sim.rng at the start of every run (a run and its replay draw the same numbers).
const SEARCH_SEED: int = 0x5EA2C4
## A changed node's replay is at most this long (ticks from its last unchanged ancestor); longer paths are dropped.
const MAX_PREFIX_TICKS: int = 360
## Record ids the search world leaves out: presentation, progress and flow (a checkpoint, an exit, a team gate travel
## through Flow), and the arena's (never in a co-op file).
const WORLD_SKIP_IDS: Array[String] = [
	"objects/checkpoint", "objects/sign", "objects/npc", "objects/hero_start", "objects/x2_tablet", "objects/exit",
	"objects/gate", "objects/marker", "objects/spawn_point", "objects/cookpot", "objects/crate_lane",
	"objects/coconut", "enemies/decoration",
]
## Items the search world keeps (they change what the hero can do); every other item is left out.
const WORLD_ITEMS: Array[String] = ["items/weapon", "items/glider"]
## Zones the search world leaves out (presentation and flow only).
const WORLD_SKIP_ZONES: Array[String] = [
	"zones/message", "zones/secret", "zones/camera_lock", "zones/autoscroll_stop", "zones/flies", "zones/dark",
	"zones/arena", "zones/food_rain",
]
## Columns beyond the gate's area (and its starts) whose entities the search world holds ([method world_columns_of]).
const WORLD_MARGIN_COLS: int = 6
## Strikes are tried where something to hit lies within this many cells (x, y) of the resting point, throws within
## the second.
const STRIKE_REACH_CELLS: Vector2i = Vector2i(6, 4)
const THROW_REACH_CELLS: Vector2i = Vector2i(18, 6)
## [method Searcher.partner_useful]: the rows over the hero's feet cell (inclusive) and the columns either side where a
## floor makes the idle partner worth a try.
const PARTNER_LEDGE_ROWS: Vector2i = Vector2i(4, 9)
const PARTNER_LEDGE_COLS: int = 5
## The fastest a hero crosses the floor (px per tick: the Hot Rock holder's 96 v16, above the walk cap of 80) and the
## columns a strike spot lies beside its target ([method strike_spots]): the lower bound of [method pair_lower_bound].
const HERO_MAX_PX_PER_TICK: int = 6
const STRIKE_REACH_SPOT_COLS: int = 2
## The specials a hero may hold for a throw (every belt special of the reference hero).
const THROW_WEAPONS: Array[int] = [Defs.Weapon.AXE, Defs.Weapon.BOOMERANG, Defs.Weapon.SPEAR]
## Properties of a record entity that the world signature reads (when it has them).
const PROBE_PROPS: Array[StringName] = [
	&"dead", &"collected", &"opened", &"state", &"pressed", &"risen", &"triggered", &"high_side", &"succeeded",
	&"present", &"tame", &"driver", &"gunner", &"offset", &"block", &"hits_left",
]


## The level of a search: the grid at rest, a view as large as the map (nothing dies "off screen", nothing dozes, the
## co-op frame is the whole map: no edge walls, no leash). Cell changes are recorded so a reset can undo them.
class SearchLevel:
	extends LevelBase

	## Cell -> its character before the first change since the last [method restore_cells].
	var changed: Dictionary = {}

	## A search world: the view is one screen around P1 (as the camera shows him: what lies off it dozes and wakes
	## as in the game); a bare search: the whole map.
	var follow: bool = false

	func whole_rect() -> Rect2i:
		return Rect2i(0, 0, maxi(grid.width_px(), Tuning.VIEW_W), maxi(grid.height_px(), Tuning.VIEW_H))

	func get_view_rect() -> Rect2i:
		var whole: Rect2i = whole_rect()
		var hero: PlayerBase = get_hero(0) if follow else null
		if hero == null:
			return whole
		var x: int = clampi(hero.sim_pos.x - Tuning.VIEW_W / 2, 0, maxi(whole.size.x - Tuning.VIEW_W, 0))
		var y: int = clampi(hero.sim_pos.y - Tuning.VIEW_H * 2 / 3, 0, maxi(whole.size.y - Tuning.VIEW_H, 0))
		return Rect2i(x, y, Tuning.VIEW_W, Tuning.VIEW_H)

	## The co-op frame is the whole map: no edge walls, no leash (the partner is never left behind).
	func get_party_frame() -> Rect2i:
		return whole_rect()

	## Decide every doze area afresh (after a reset moved the entities home and the heroes were placed), as
	## LevelBase.respawn_player does.
	func refresh_doze() -> void:
		_doze_full = true
		_doze_known.fill(0)
		_doze_update()

	func set_cell(col: int, row: int, ch: String) -> void:
		var cell: Vector2i = Vector2i(col, row)
		if not changed.has(cell) and grid.in_bounds(col, row):
			changed[cell] = grid.get_char(col, row)
		super.set_cell(col, row, ch)

	## Cells whose character differs from the one before the changes ("" when none), sorted.
	func changed_cells() -> String:
		var parts: PackedStringArray = PackedStringArray()
		for cell: Vector2i in changed:
			if grid.get_char(cell.x, cell.y) != str(changed[cell]):
				parts.append("%d,%d=%s" % [cell.x, cell.y, grid.get_char(cell.x, cell.y)])
		parts.sort()
		return ";".join(parts)

	func restore_cells() -> void:
		for cell: Vector2i in changed:
			grid.set_char(cell.x, cell.y, str(changed[cell]))
		changed.clear()


## One search: a level with the real hero, scripted from macros; with [method build_world] the file's entities and
## the partner (an egg or an idle hero) in a co-op game of two.
class Searcher:
	extends RefCounted

	var level: SearchLevel = null
	var hero: PlayerBase = null
	## The partner hero (slot PARTNER_SLOT) of a search world; null on a bare grid.
	var partner: PlayerBase = null
	var driver: SimEntity = null
	var macros: Array[Dictionary] = []
	var simulated: int = 0
	## Macro runs made (each from a reset world).
	var runs: int = 0
	## Ticks replayed to bring a changed node back (part of [member simulated]).
	var replayed: int = 0
	## True when the level holds the file's entities ([method build_world]).
	var world: bool = false
	var _saved_level: LevelBase = null
	var _saved_mode: int = Defs.GameMode.SINGLE
	var _saved_party: int = 1
	var _saved_difficulty: int = 0
	var _game_saved: bool = false
	## A search world starts every run on the same Sim.tick (the one it was built on), so whatever counts on the clock
	## (a geyser's period, a lift's phase) is in the same phase in a run and in its replay; [method close] puts the
	## clock at the latest tick reached.
	var _tick_base: int = -1
	var _tick_max: int = 0
	var _flags: PackedInt32Array = PackedInt32Array()
	var _first_tick: int = 0
	## The records spawned into the world and their entities (same index).
	var _records: Array[Dictionary] = []
	var _entities: Array[SimEntity] = []
	## Instance ids of everything that belongs to the world (records, heroes, the driver): the rest is runtime.
	var _kept: Dictionary = {}
	## The signature of the world right after a reset.
	var _baseline: String = ""
	## Feet points (logical px) of what strikes and throws can act on.
	var _targets: Array[Vector2i] = []
	## Feet points of what an idle partner can be used on (plates to weigh, keepers and trait enemies to bait).
	var _partner_targets: Array[Vector2i] = []

	## Build a bare level from `grid` (no entity but the hero). False when the hero scene does not exist.
	func build(level_id: StringName, meta: Dictionary, grid: TileGrid) -> bool:
		if not Spawner.exists(PLAYER_ID):
			return false
		_saved_level = Game.level
		level = SearchLevel.new()
		level.name = "CoopSearchLevel"
		level.level_id = level_id
		level.meta = meta
		level.grid = grid
		(Engine.get_main_loop() as SceneTree).root.add_child(level)
		hero = Spawner.instantiate(PLAYER_ID) as PlayerBase
		if hero == null:
			close()
			return false
		hero.spawn_setup(Vector2i(Tuning.TILE * 2, Tuning.TILE * 2), {})
		level.add_child(hero)
		GameInput.set_scripted(_flag_at)
		macros = CoopSearch.make_macros()
		return true

	## Build the search world of `data` in `difficulty`: `grid` (the grid at rest) with the file's entities whose
	## column lies in `columns` ([first, end)), then the hero and the partner, in a co-op game of two (Game.mode,
	## party and difficulty are put back by [method close]). False when the hero scene does not exist.
	func build_world(data: LevelData, difficulty: int, grid: TileGrid, columns: Vector2i) -> bool:
		if not Spawner.exists(PLAYER_ID):
			return false
		_saved_level = Game.level
		_tick_base = Sim.tick
		_tick_max = Sim.tick
		_saved_mode = Game.mode
		_saved_party = Game.party
		_saved_difficulty = Game.difficulty
		_game_saved = true
		Game.mode = Defs.GameMode.COOP
		Game.party = 2
		Game.difficulty = difficulty
		world = true
		level = SearchLevel.new()
		level.name = "CoopSearchLevel"
		level.level_id = data.id
		level.meta = data.resolved_meta(difficulty)
		level.grid = grid
		level.follow = true
		(Engine.get_main_loop() as SceneTree).root.add_child(level)
		for record: Dictionary in CoopSearch.world_record_list(data, difficulty, columns):
			var id: String = String(record["id"])
			var col: int = int(record["col"])
			var params: Dictionary = (record["params"] as Dictionary).duplicate()
			var node: SimEntity = level.spawn(StringName(id), LevelText.cell_to_feet(float(col),
					float(int(record["row"])), params), params) as SimEntity
			if node == null:
				continue
			_records.append(record)
			_entities.append(node)
			_kept[node.get_instance_id()] = true
			if CoopSearch.is_target(id):
				_targets.append(node.sim_pos)
			if id == "objects/plate" or (record["params"] as Dictionary).has("keeper") \
					or (record["params"] as Dictionary).has("coop"):
				_partner_targets.append(node.sim_pos)
		hero = level.spawn(PLAYER_ID, Vector2i(Tuning.TILE * 2, Tuning.TILE * 2), {}) as PlayerBase
		partner = level.spawn(PLAYER_ID, Vector2i(Tuning.TILE * 3, Tuning.TILE * 2), {"slot": PARTNER_SLOT}) \
				as PlayerBase
		if hero == null or partner == null:
			close()
			return false
		_kept[hero.get_instance_id()] = true
		_kept[partner.get_instance_id()] = true
		driver = PartyDriver.new()
		level.register_party_driver(driver)
		_kept[driver.get_instance_id()] = true
		# The cells the entities wrote while entering (boulders, static columns) are the world's own.
		level.changed.clear()
		GameInput.set_scripted(_flag_at)
		GameInput.set_scripted_slot(PARTNER_SLOT, CoopSearch._no_input)
		macros = CoopSearch.make_macros(true)
		reset_world()
		_baseline = signature()
		return true

	func close() -> void:
		GameInput.clear_scripted()
		if world:
			GameInput.clear_scripted_slot(PARTNER_SLOT)
		if level != null and is_instance_valid(level):
			level.get_parent().remove_child(level)
			level.free()
		level = null
		hero = null
		partner = null
		driver = null
		_entities.clear()
		if _tick_base >= 0:
			Sim.tick = maxi(Sim.tick, _tick_max)
			_tick_base = -1
		if _game_saved:
			Game.mode = _saved_mode
			Game.party = _saved_party
			Game.difficulty = _saved_difficulty
			_game_saved = false
		Game.level = _saved_level if is_instance_valid(_saved_level) else null

	func _flag_at(tick: int) -> int:
		var index: int = tick - _first_tick
		return _flags[index] if index >= 0 and index < _flags.size() else 0

	## Back to the level-file state: runtime entities (shots, effects, dropped items, spear steps, springs) freed,
	## every entity reset (LevelBase.reset_entities), the cells changed since put back; an entity a reset does not
	## bring back (a sprung pot, a collected item, an opened spot, a moved boulder) is spawned again from its record,
	## and then the heroes and the driver are registered again after it (the level's order: entities, P1, P2, driver).
	func reset_world() -> void:
		var stale: Array[Node] = []
		for child: Node in level.get_children():
			if not _kept.has(child.get_instance_id()):
				stale.append(child)
		for node: Node in stale:
			if node is SimEntity:
				(node as SimEntity).sim_active = false
			level.remove_child(node)
			node.free()
		level.reset_entities()
		level.restore_cells()
		var respawned: bool = false
		for i: int in _entities.size():
			if CoopSearch.reset_keeps(_entities[i]):
				continue
			var record: Dictionary = _records[i]
			var old: SimEntity = _entities[i]
			if old != null and is_instance_valid(old):
				_kept.erase(old.get_instance_id())
				level.remove_child(old)
				old.free()
			var params: Dictionary = (record["params"] as Dictionary).duplicate()
			var node: SimEntity = level.spawn(StringName(String(record["id"])), LevelText.cell_to_feet(
					float(int(record["col"])), float(int(record["row"])), params), params) as SimEntity
			_entities[i] = node
			if node != null:
				_kept[node.get_instance_id()] = true
			respawned = true
		level.restore_cells()
		if respawned:
			for node: SimEntity in [hero, partner, driver]:
				level.remove_child(node)
				level.add_child(node)
		Sim.rng.reseed(SEARCH_SEED)

	## What a reset would undo that a player could use (see the class header): "" parts for an untouched world.
	func signature() -> String:
		var parts: PackedStringArray = PackedStringArray()
		for i: int in _entities.size():
			var entity: SimEntity = _entities[i]
			if entity == null or not is_instance_valid(entity):
				parts.append("%d:gone" % i)
				continue
			parts.append("%d:%s" % [i, CoopSearch.probe(entity)])
		for child: Node in level.get_children():
			if _kept.has(child.get_instance_id()):
				continue
			var extra: String = CoopSearch.probe_runtime(child)
			if extra != "":
				parts.append(extra)
		parts.append("cells:" + level.changed_cells())
		parts.append("hand:%d,%d" % [hero.run.weapon, hero.run.belt])
		return "|".join(parts)

	## Play `flags` from `start` (facing `facing`) on a reset world with the hand weapon `hand` (-1: the club) and the
	## partner `partner_mode` (a search world). The first `skip` ticks are a replay (no goal test; after them the hero
	## stands at `expect` unless it is (-1, -1)). {"goal": true,
	## "ticks"} when the feet point entered a cell of `goals`; at rest {"pos", "ticks" (after the replay), "played"
	## (every flag of the run up to the rest), "sig"}; {} when he died, went down or did not come to rest.
	func run(start: Vector2i, facing: int, flags: PackedInt32Array, goals: Dictionary, hand: int = -1,
			partner_mode: int = PARTNER_EGG, skip: int = 0, expect: Vector2i = Vector2i(-1, -1)) -> Dictionary:
		runs += 1
		if world:
			_tick_max = maxi(_tick_max, Sim.tick)
			Sim.tick = _tick_base
			reset_world()
		hero.run.reset_energy()
		hero.run.set_weapon(hand if hand >= 0 else Defs.Weapon.CLUB)
		hero.run.set_belt(Defs.Weapon.CLUB if hand > Defs.Weapon.CLUB else PlayerRun.BELT_EMPTY)
		hero.respawn_at(start)
		hero.facing = facing
		if world:
			_place_partner(partner_mode, start, facing)
			level.refresh_doze()
		_flags = flags
		_first_tick = Sim.tick + 1
		var still: int = 0
		var t: int = 0
		while t < flags.size() + SETTLE_TICKS:
			Sim.step(1)
			t += 1
			simulated += 1
			if hero.dead or hero.is_down():
				return {}
			if t < skip:
				replayed += 1
				continue
			if t == skip and expect != Vector2i(-1, -1) and hero.sim_pos != expect:
				return {}  # the replay did not come back to its node (a world that is not reset exactly): dropped
			if t == skip:
				continue
			var cell: Vector2i = Vector2i(Tuning.to_cell(hero.sim_pos.x), Tuning.to_cell(hero.sim_pos.y - 1))
			if goals.has(cell):
				return {"goal": true, "ticks": t - skip, "cell": cell}
			if t >= flags.size():
				if hero.is_grounded() and hero.yvel == 0 and hero.xvel == 0:
					still += 1
					if still >= 2:
						var played: PackedInt32Array = flags.duplicate()
						played.resize(t)
						return {"pos": hero.sim_pos, "ticks": t - skip, "played": played,
							"sig": signature() if world else ""}
				else:
					still = 0
		return {}

	## The partner at the start of a run: an egg at its drift point behind the hero, or an idle hatched hero
	## PARTNER_FRONT_PX in front of him (on the same feet line; he falls when there is no floor).
	func _place_partner(mode: int, start: Vector2i, facing: int) -> void:
		partner.run.reset_energy()
		if mode == PARTNER_IDLE:
			partner.respawn_at(start + Vector2i(PARTNER_FRONT_PX * facing, 0))
			partner.facing = -facing
		else:
			partner.respawn_at(start)
			partner.go_down(&"search")
			partner.teleport(start + Vector2i(PartyTuning.EGG_OFFSET_X * facing, PartyTuning.EGG_OFFSET_Y))
		driver.set(&"active_mask", 0)

	## True when an idle partner may help at `pos`: a plate or a keeper / trait enemy within THROW_REACH_CELLS, or
	## a floor PARTNER_LEDGE_ROWS over the hero's feet within PARTNER_LEDGE_COLS columns (higher than his own jump
	## with its corner catch, low enough for a ride off a still carrier).
	func partner_useful(pos: Vector2i) -> bool:
		for target: Vector2i in _partner_targets:
			if absi(target.x - pos.x) <= THROW_REACH_CELLS.x * Tuning.TILE \
					and absi(target.y - pos.y) <= THROW_REACH_CELLS.y * Tuning.TILE:
				return true
		var grid: TileGrid = level.grid
		var col: int = Tuning.to_cell(pos.x)
		var row: int = Tuning.to_cell(pos.y - 1)
		for dc: int in range(-PARTNER_LEDGE_COLS, PARTNER_LEDGE_COLS + 1):
			for up: int in range(PARTNER_LEDGE_ROWS.x, PARTNER_LEDGE_ROWS.y + 1):
				var cell: Vector2i = Vector2i(col + dc, row - up)
				if grid.in_bounds(cell.x, cell.y + 1) and TileGrid.is_ground(grid.floor_at(cell.x, cell.y + 1)) \
						and grid.side_at(cell.x, cell.y) != TileGrid.SIDE_WALL:
					return true
		return false

	## True when something a strike (`reach` = STRIKE_REACH_CELLS) or a throw can act on lies near `pos`.
	func target_near(pos: Vector2i, reach: Vector2i) -> bool:
		for target: Vector2i in _targets:
			if absi(target.x - pos.x) <= reach.x * Tuning.TILE and absi(target.y - pos.y) <= reach.y * Tuning.TILE:
				return true
		return false

	## Breadth-first over resting points from `starts` (feet points) inside `area` (cells) until a cell of `goals` is
	## entered. Returns {"reached", "ticks", "detail", "nodes", "runs"}.
	func explore(starts: Array[Vector2i], goals: Dictionary, area: Rect2i, bound: int, max_nodes: int) -> Dictionary:
		var queue: Array[Dictionary] = []
		var seen: Dictionary = {}
		for start: Vector2i in starts:
			var key: String = CoopSearch.state_key(start, _baseline)
			if not seen.has(key):
				seen[key] = 0
				queue.append({"pos": start, "ticks": 0, "path": "start %d,%d" % [start.x, start.y], "anchor": start,
					"facing": 1, "hand": -1, "partner": PARTNER_EGG, "prefix": PackedInt32Array()})
		var head: int = 0
		while head < queue.size() and head < max_nodes:
			var node: Dictionary = queue[head]
			head += 1
			var pos: Vector2i = node["pos"]
			var start_cell: Vector2i = Vector2i(Tuning.to_cell(pos.x), Tuning.to_cell(pos.y - 1))
			if goals.has(start_cell):
				return {"reached": true, "ticks": node["ticks"], "detail": node["path"], "nodes": head, "runs": runs,
					"simulated": simulated, "replayed": replayed}
			var prefix: PackedInt32Array = node["prefix"]
			var changed: bool = not prefix.is_empty()
			for macro: Dictionary in macros:
				if not _macro_fits(macro, node):
					continue
				var hand: int = int(node["hand"]) if changed else int(macro.get("hand", -1))
				var partner_mode: int = int(node["partner"]) if changed else int(macro.get("partner", PARTNER_EGG))
				var facing: int = int(node["facing"]) if changed else int(macro["facing"])
				var start: Vector2i = node["anchor"] if changed else pos
				var outcome: Dictionary = run(start, facing, prefix + (macro["flags"] as PackedInt32Array), goals, hand,
						partner_mode, prefix.size(), pos if changed else Vector2i(-1, -1))
				if outcome.is_empty():
					continue
				var ticks: int = int(node["ticks"]) + int(outcome["ticks"])
				if ticks > bound:
					continue
				var path: String = "%s > %s" % [node["path"], macro["name"]]
				if outcome.has("goal"):
					return {"reached": true, "ticks": ticks, "detail": path, "nodes": head, "runs": runs,
						"simulated": simulated, "replayed": replayed}
				var rest: Vector2i = outcome["pos"]
				var sig: String = outcome["sig"]
				var key: String = CoopSearch.state_key(rest, sig)
				if seen.has(key) and int(seen[key]) <= ticks:
					continue
				var fresh: bool = not seen.has(key)
				seen[key] = ticks
				var child: Dictionary = {"pos": rest, "ticks": ticks, "path": path, "anchor": rest, "facing": 1,
					"hand": -1, "partner": PARTNER_EGG, "prefix": PackedInt32Array()}
				if sig != _baseline:
					# The world changed for good: the child replays the run from its last unchanged ancestor.
					var played: PackedInt32Array = outcome["played"]
					if played.size() > MAX_PREFIX_TICKS:
						continue
					child["anchor"] = start
					child["facing"] = facing
					child["hand"] = hand
					child["partner"] = partner_mode
					child["prefix"] = played
				var cell: Vector2i = Vector2i(Tuning.to_cell(rest.x), Tuning.to_cell(rest.y - 1))
				if fresh and area.has_point(cell):
					queue.append(child)
		return {"reached": false, "ticks": -1, "detail": "", "nodes": head, "runs": runs, "simulated": simulated, "replayed": replayed}

	## Whether `macro` is worth a run from `node`: strikes where something to hit is near, throws where something to
	## throw at is in range, the partner moves only from an unchanged node (they place him).
	func _macro_fits(macro: Dictionary, node: Dictionary) -> bool:
		match str(macro.get("kind", "move")):
			"strike":
				return target_near(node["pos"], STRIKE_REACH_CELLS)
			"throw":
				return target_near(node["pos"], THROW_REACH_CELLS)
			"partner":
				return CoopSearch.idle_partner and (node["prefix"] as PackedInt32Array).is_empty() \
						and partner_useful(node["pos"])
		return true


## Solo-impossibility search of gate `gate` of the co-op level `level_id` in `difficulty` (the contract of
## tests/test_coop_gates.gd): {"reached": bool (true = one hero got to the far cell, or a static rule is broken, or
## the gate cannot be searched), "bound": BOUND_TICKS, "windows": [{"what", "window", "solo_min"}], "detail": String,
## "starts": Array of start cells, "explored": resting points searched, "runs": macro runs, "flood": bool (the
## diagnostic of [method flood_reaches])}.
static func search_gate(level_id: StringName, difficulty: int, gate: String) -> Dictionary:
	var data: LevelData = LevelData.load_file(level_path(level_id))
	if data == null:
		return _unproven(_fresh_result(), "cannot read the level %s" % level_id)
	return search_data(data, difficulty, gate)


## [method search_gate] on a parsed level (tests, tools).
static func search_data(data: LevelData, difficulty: int, gate: String) -> Dictionary:
	var result: Dictionary = _fresh_result()
	var tablet: Dictionary = find_tablet(data, difficulty, gate)
	if tablet.is_empty():
		return _unproven(result, "no objects/x2_tablet gate=%s in %s" % [gate, Defs.difficulty_name(difficulty)])
	var far: Vector2i = tablet["far"]
	if far == Vector2i(-1, -1):
		return _unproven(result, "the tablet of gate %s names no far cell" % gate)
	# 1. Static rules.
	var broken: String = static_problem(data, gate)
	if broken != "":
		result["reached"] = true
		result["detail"] = "static rule: " + broken
		return result
	# 2. The search in the search world.
	var grid: TileGrid = grid_at_rest(data, difficulty)
	var area: Rect2i = gate_area(tablet, grid)
	# The daze measurements build a search level of their own: before this one (they never nest).
	for record: Dictionary in data.entity_records():
		var id: String = String(record["id"])
		var daze: bool = str(record["params"].get("coop", "")) == "daze" or id == "enemies/raptor"
		if daze and Spawner.category(StringName(id)) == "enemies" and LevelText.applies_to(record["params"], difficulty):
			measure_daze_solo_min(id)
	var starts: Array[Vector2i] = start_points(data, difficulty, tablet, grid)
	for start: Vector2i in starts:
		(result["starts"] as Array).append(Vector2i(Tuning.to_cell(start.x), Tuning.to_cell(start.y - 1)))
	var columns: Vector2i = search_columns(area, starts, grid)
	result["flood"] = flood_reaches(grid, starts, far, columns)
	var world_columns: Vector2i = world_columns_of(area, starts, grid)
	var key: String = _explore_key(grid, data.resolved_meta(difficulty), starts, far, area) + "|" \
			+ str(world_records(data, difficulty, world_columns).hash()) + ("|idle" if idle_partner else "|egg")
	var found: Dictionary = {}
	if use_cache and _explore_cache.has(key):
		found = _explore_cache[key]
	else:
		var searcher: Searcher = Searcher.new()
		if not searcher.build_world(data, difficulty, grid_at_rest(data, difficulty), world_columns):
			return _unproven(result, "the hero scene %s does not exist" % PLAYER_ID)
		found = searcher.explore(starts, {far: true}, area, BOUND_TICKS, MAX_NODES)
		searcher.close()
		_explore_cache[key] = found
	result["reached"] = bool(found["reached"])
	result["explored"] = int(found["nodes"])
	result["runs"] = int(found.get("runs", 0))
	result["simulated"] = int(found.get("simulated", 0))
	result["replayed"] = int(found.get("replayed", 0))
	if result["reached"]:
		result["detail"] = "one hero reached %d,%d in %d ticks: %s" % [far.x, far.y, int(found["ticks"]),
			found["detail"]]
	# 3. Windows near the gate, on the bare grid at rest (nothing in the hero's way: the least he needs).
	var bare: Searcher = Searcher.new()
	if bare.build(data.id, data.resolved_meta(difficulty), grid):
		result["windows"] = measure_windows(data, difficulty, area, bare)
		bare.close()
	return result


## The columns whose entities the search world holds, [first, end): the gate's area and its starts, widened by
## WORLD_MARGIN_COLS (the search expands only resting points inside the area; a walker that wanders in from farther
## away is not modelled).
static func world_columns_of(area: Rect2i, starts: Array[Vector2i], grid: TileGrid) -> Vector2i:
	var first: int = area.position.x
	var end: int = area.end.x
	for start: Vector2i in starts:
		first = mini(first, Tuning.to_cell(start.x))
		end = maxi(end, Tuning.to_cell(start.x) + 1)
	return Vector2i(maxi(first - WORLD_MARGIN_COLS, 0), mini(end + WORLD_MARGIN_COLS, grid.cols))


## The records of `data` the search world of `difficulty` spawns in `columns` (the cache key's part), as text.
static func world_records(data: LevelData, difficulty: int, columns: Vector2i) -> String:
	var lines: PackedStringArray = PackedStringArray()
	for record: Dictionary in world_record_list(data, difficulty, columns):
		lines.append("%s %d %d %s" % [record["id"], int(record["col"]), int(record["row"]), str(record["params"])])
	return "\n".join(lines)


## The records of `data` the search world of `difficulty` spawns, in file order: those in `columns` that
## [method world_keeps], and every record linked by a name to one of them wherever it lies - the plates of a door's
## `rise_while` / `sink_while`, the keepers of a `trigger=keepers:<group>` door, the drums of a `trigger=drums:<bond>`
## door and the other members of a bond (and the doors of such plates, keepers and drums) - so a mechanism is never
## cut in half by the columns.
static func world_record_list(data: LevelData, difficulty: int, columns: Vector2i) -> Array[Dictionary]:
	var usable: Array[Dictionary] = []
	for record: Dictionary in data.entity_records():
		if world_keeps(String(record["id"])) and LevelText.applies_to(record["params"], difficulty):
			usable.append(record)
	var names: Dictionary = {}
	var chosen: Dictionary = {}
	for i: int in usable.size():
		var col: int = int(usable[i]["col"])
		if col >= columns.x and col < columns.y:
			chosen[i] = true
			for name: String in _link_names(usable[i]):
				names[name] = true
	for i: int in usable.size():
		if chosen.has(i):
			continue
		for name: String in _link_names(usable[i]):
			if names.has(name):
				chosen[i] = true
				break
	var result: Array[Dictionary] = []
	for i: int in usable.size():
		if chosen.has(i):
			result.append(usable[i])
	return result


## The mechanism names a record takes part in ("plate:<n>", "keepers:<g>", "drums:<b>", "bond:<b>").
static func _link_names(record: Dictionary) -> PackedStringArray:
	var params: Dictionary = record["params"]
	var id: String = String(record["id"])
	var result: PackedStringArray = PackedStringArray()
	if id == "objects/plate" and params.has("name"):
		result.append("plate:" + str(params["name"]))
	for key: String in ["rise_while", "sink_while"]:
		for name: String in LevelText.to_list(str(params.get(key, ""))):
			result.append("plate:" + name)
	var trigger: String = str(params.get("trigger", ""))
	if trigger.begins_with("keepers:") or trigger.begins_with("drums:"):
		result.append(trigger)
	if params.has("keeper"):
		result.append("keepers:" + str(params["keeper"]))
	if id == "objects/drum" and params.has("bond"):
		result.append("drums:" + str(params["bond"]))
	elif params.has("bond"):
		result.append("bond:" + str(params["bond"]))
	if params.has("needs"):
		result.append("drums:" + str(params["needs"]))
	return result


## True when the search world spawns records of `id` (WORLD_SKIP_IDS, WORLD_ITEMS, WORLD_SKIP_ZONES; props never).
static func world_keeps(id: String) -> bool:
	if WORLD_SKIP_IDS.has(id) or WORLD_SKIP_ZONES.has(id) or Spawner.is_prop(StringName(id)):
		return false
	var category: String = Spawner.category(StringName(id))
	if category == "items":
		return WORLD_ITEMS.has(id)
	if category == "player" or category == "projectiles" or category == "fx":
		return false
	return Spawner.exists(StringName(id))


## True when a strike or a throw can act on a record of `id` (enemies, every hittable object, bark boards, boulders,
## Chomper).
static func is_target(id: String) -> bool:
	var category: String = Spawner.category(StringName(id))
	if category == "enemies" or category == "bosses":
		return true
	return id in ["objects/hidden_spot", "objects/container", "objects/breakable_block", "objects/drum",
		"objects/flower_pot", "objects/vine", "objects/bark_board", "objects/boulder_heavy", "objects/mount",
		"objects/scenery_hittable"]


## The world-signature part of one record entity: what a reset would undo. Enemies with a co-op role (a keeper, a
## trait, a bond): alive or dead (where they walk and the hits short of a kill are not carried; a plain enemy is not
## carried at all - a move kills him again on its way, see the strike-walk macros); spots and dropped or placed
## items: nothing (the reference hero holds every special; only the glider counts); platforms and zones: nothing
## (their motion is momentary, a reset only adds back what fell);
## everything else: its feet point and the PROBE_PROPS it has.
static func probe(entity: SimEntity) -> String:
	if entity is EnemyBase:
		var enemy: EnemyBase = entity
		if enemy.keeper == &"" and enemy.coop_trait == Defs.CoopTrait.NONE and not enemy.spawn_params.has("bond"):
			return ""   # a plain enemy is killed again in the move that needs him gone
		return "e1" if enemy.dead else "e0"
	if entity is PlatformBase or entity is ZoneBase or entity is SceneryHittable:
		return ""
	if entity is CollectibleBase:
		# The reference hero holds every special anyway: only the glider changes what he can do.
		var item: CollectibleBase = entity
		return "c%d" % (1 if item.collected else 0) if item.item_id == &"items/glider" else ""
	var parts: PackedStringArray = PackedStringArray(["%d,%d" % [entity.sim_pos.x, entity.sim_pos.y]])
	for prop: StringName in PROBE_PROPS:
		if not prop in entity:
			continue
		var value: Variant = entity.get(prop)
		if value is Object:
			parts.append("%s=%d" % [prop, 0 if value == null else 1])
		else:
			parts.append("%s=%s" % [prop, str(value)])
	return ",".join(parts)


## The world-signature part of a runtime entity still standing at a rest (a spear step, a pot's spring): "" for
## everything that changes nothing (shots, effects, dropped items).
static func probe_runtime(node: Node) -> String:
	if node is PlatformBase or node is SpringPad:
		var entity: SimEntity = node
		return "%s@%d,%d" % [String((entity.get_script() as Script).resource_path).get_file(), entity.sim_pos.x,
			entity.sim_pos.y]
	return ""


## True when a level reset brings `entity` back to its level-file state by itself (enemies, plates, doors, drums,
## platforms, see-saws, the mount, zones); false for a sprung or pushed pot, a moved boulder, a collected item, an
## opened spot - those are spawned again from the record.
static func reset_keeps(entity: SimEntity) -> bool:
	if entity == null or not is_instance_valid(entity):
		return false
	if entity is FlowerPot:
		var pot: FlowerPot = entity
		return pot.state == FlowerPot.State.IDLE and pot.sim_pos == pot.spawn_pos
	if entity is HeavyBoulder:
		return entity.sim_pos == entity.spawn_pos
	if entity is CollectibleBase:
		return not (entity as CollectibleBase).collected
	if entity is SceneryHittable:
		var spot: SceneryHittable = entity
		return not spot.opened and spot.hits_left == spot.hits_total
	return true


## The key of a node: the resting point (KEY_PX wide) and the world signature.
static func state_key(pos: Vector2i, sig: String) -> String:
	var key: Vector2i = node_key(pos)
	return "%d,%d|%s" % [key.x, key.y, sig.md5_text() if sig != "" else ""]


## No input (the partner's slot: he never presses anything, so he never becomes ACTIVE).
static func _no_input(_tick: int) -> int:
	return 0


## Explore results of [method search_data] (see [method _explore_key] and [method world_records]): the same grid at
## rest, records, starts, area and meta give the same search (Beginner and Expert often do).
static var _explore_cache: Dictionary = {}
## False: [method search_data] always runs the search (no cached explore) - for tests that prove the search itself.
static var use_cache: bool = true
## False: the search world's partner is only ever an egg (no `partner` macros) - to tell a gate that one player opens
## with an idle partner from one he opens alone (tests, tools).
static var idle_partner: bool = true


## Rows a feet cell may rise above the cell it last stood in, for [method flood_reaches]: the hero's highest jump
## (UP released after 5-9 ticks, PHYSICS.md 6.4) peaks 64 px over the take-off, which moves the feet cell up exactly 4
## rows from a floor, and at most 4 from feet inside a slope or tar cell - on the bare grid, with no spring, enemy,
## partner or carrier that could lift him higher.
const FLOOD_RISE_ROWS: int = 4


## The flood diagnostic of [method search_data] (result "flood"; v1's prefilter, asked for by D5 and DB1): false
## when no chain of cells a hero's feet point can occupy joins a start to the `far` cell ON THE BARE GRID AT REST. Feet
## cells are the cells of the grid at rest that are not side walls (slopes, one-way floors, hatches, liquids and spikes
## included; a tar floor too, whose surface lies inside its cell), plus one open row above the map, joined
## 8-connected. A chain may rise at most FLOOD_RISE_ROWS rows above the last cell with ground under it and may not
## rise again once it went down, except for one row into a cell with ground under it (an airborne hero whose feet
## enter a one-cell wall lands on top of it: the side probe tests the row above an airborne feet cell). It knows no
## entity - a door that opens, a spring, an enemy's head, the partner - so since v2 it decides nothing: a gate it
## refuses still goes through the search world. `columns` ([first, end)) keeps the chains to the columns the search
## can touch ([method search_columns]).
static func flood_reaches(grid: TileGrid, starts: Array[Vector2i], far: Vector2i,
		columns: Vector2i = Vector2i(0, 1 << 30)) -> bool:
	if far.x < 0 or far.x >= grid.cols or far.y < -1 or far.y >= grid.rows:
		return false
	var cols: int = grid.cols
	var cells: int = cols * (grid.rows + 1)    # row -1 is index row 0
	var passable: PackedByteArray = PackedByteArray()
	var grounded: PackedByteArray = PackedByteArray()
	passable.resize(cells)
	grounded.resize(cells)
	for row: int in range(-1, grid.rows):
		for col: int in cols:
			var i: int = (row + 1) * cols + col
			if row < 0:
				passable[i] = 1
				continue
			var inside: bool = grid.has_profile(col, row) or grid.is_tar(col, row)
			passable[i] = 1 if grid.side_at(col, row) != TileGrid.SIDE_WALL or inside else 0
			grounded[i] = 1 if inside or TileGrid.is_ground(grid.floor_at(col, row + 1)) else 0
	if passable[(far.y + 1) * cols + far.x] == 0:
		return false
	# State: cell index * STATES + rise * 2 + descended.
	var states: int = (FLOOD_RISE_ROWS + 1) * 2
	var seen: PackedByteArray = PackedByteArray()
	seen.resize(cells * states)
	var stack: PackedInt32Array = PackedInt32Array()
	for start: Vector2i in starts:
		var cell: Vector2i = Vector2i(Tuning.to_cell(start.x), Tuning.to_cell(start.y - 1))
		if cell.x < 0 or cell.x >= cols or cell.y < -1 or cell.y >= grid.rows:
			continue
		var state: int = ((cell.y + 1) * cols + cell.x) * states
		if seen[state] == 0:
			seen[state] = 1
			stack.append(state)
	var far_index: int = (far.y + 1) * cols + far.x
	while not stack.is_empty():
		var state: int = stack[stack.size() - 1]
		stack.resize(stack.size() - 1)
		var index: int = state / states
		if index == far_index:
			return true
		var rise: int = (state % states) >> 1
		var descended: int = state & 1
		var col: int = index % cols
		var row: int = index / cols - 1
		for dy: int in [-1, 0, 1]:
			var next_row: int = row + dy
			if next_row < -1 or next_row >= grid.rows:
				continue
			for dx: int in [-1, 0, 1]:
				var next_col: int = col + dx
				if (dx == 0 and dy == 0) or next_col < maxi(columns.x, 0) or next_col >= mini(columns.y, cols):
					continue
				var next: int = (next_row + 1) * cols + next_col
				if passable[next] == 0:
					continue
				var next_state: int = -1
				if grounded[next] == 1:
					# Ground under the feet (a landing, a walk, or the one-row catch onto a wall top): rise resets.
					next_state = next * states
				elif dy < 0:
					if descended == 0 and rise + 1 <= FLOOD_RISE_ROWS:
						next_state = next * states + ((rise + 1) << 1)
				elif dy > 0:
					next_state = next * states + (rise << 1) + 1
				else:
					next_state = next * states + (rise << 1) + descended
				if next_state >= 0 and seen[next_state] == 0:
					seen[next_state] = 1
					stack.append(next_state)
	return false


## The columns the search can touch, [first, end): its area and its starts, each widened by CACHE_MARGIN_COLS (the
## search expands only resting points inside the area or at a start, and one macro run moves the hero at most 30
## columns). [method flood_reaches] keeps to them, so its refusal speaks for the search.
static func search_columns(area: Rect2i, starts: Array[Vector2i], grid: TileGrid) -> Vector2i:
	var first: int = area.position.x
	var end: int = area.end.x
	for start: Vector2i in starts:
		first = mini(first, Tuning.to_cell(start.x))
		end = maxi(end, Tuning.to_cell(start.x) + 1)
	return Vector2i(maxi(first - CACHE_MARGIN_COLS, 0), mini(end + CACHE_MARGIN_COLS, grid.cols))


## Columns beyond the gate's area that one macro run can still touch: a run lasts at most 48 + SETTLE_TICKS ticks at
## no more than 5 px per tick (30 columns); 40 leaves room for a slide.
const CACHE_MARGIN_COLS: int = 40


## The cache key of an explore: everything the search's outcome depends on - the grid's cells in every row of the
## columns a run from a node of `area` can reach, the meta (ice, liquids ...), the starts, the far cell and the area.
static func _explore_key(grid: TileGrid, meta: Dictionary, starts: Array[Vector2i], far: Vector2i,
		area: Rect2i) -> String:
	var first: int = maxi(area.position.x - CACHE_MARGIN_COLS, 0)
	var last: int = mini(area.end.x + CACHE_MARGIN_COLS, grid.cols)
	var rows: PackedStringArray = PackedStringArray()
	for row: int in grid.rows:
		var line: String = ""
		for col: int in range(first, last):
			line += grid.get_char(col, row)
		rows.append(line)
	return "%d|%d|%d|%d|%s|%s|%s" % [first, grid.rows, "\n".join(rows).hash(), str(meta).hash(), str(starts),
		str(far), str(area)]


static func _fresh_result() -> Dictionary:
	return {"reached": false, "bound": BOUND_TICKS, "windows": [], "detail": "", "starts": [], "explored": 0}


static func _unproven(result: Dictionary, why: String) -> Dictionary:
	result["reached"] = true
	result["detail"] = "unproven: " + why
	return result


## The file of a level id (the registry's path when the Levels autoload knows it, else res://levels/<id>.lvl).
static func level_path(level_id: StringName) -> String:
	var registry: Object = (Engine.get_main_loop() as SceneTree).root.get_node_or_null(^"Levels") \
			if Engine.get_main_loop() is SceneTree else null
	if registry != null and registry.has_method(&"get_level_path"):
		var path: String = str(registry.call(&"get_level_path", level_id))
		if path != "":
			return path
	return "res://levels/%s.lvl" % level_id


## The tablet of `gate` in `difficulty` (LevelValidator.parse_tablet), {} when there is none.
static func find_tablet(data: LevelData, difficulty: int, gate: String) -> Dictionary:
	for record: Dictionary in data.entity_records():
		if String(record["id"]) != "objects/x2_tablet" or not LevelText.applies_to(record["params"], difficulty):
			continue
		var tablet: Dictionary = LevelValidator.parse_tablet(record)
		if tablet["gate"] == gate:
			return tablet
	return {}


## The first static rule of the validator this file breaks for `gate` ("" when none).
static func static_problem(data: LevelData, gate: String) -> String:
	var validator: LevelValidator = LevelValidator.new()
	validator.add_data(data)
	validator.run()
	for problem: Dictionary in validator.problems:
		if int(problem["severity"]) != LevelValidator.ERROR:
			continue
		var message: String = str(problem["message"])
		if message.contains("gate '%s'" % gate):
			return message
		for fragment: String in STATIC_FRAGMENTS:
			if message.contains(fragment):
				return message
	return ""


## The grid of `data` in `difficulty` at rest, with the static blocks (`objects/column rise=0`, e.g. the Expert row
## of a boost ledge [R18]) filled in.
static func grid_at_rest(data: LevelData, difficulty: int) -> TileGrid:
	var grid: TileGrid = data.build_grid(difficulty)
	for record: Dictionary in data.entity_records():
		var params: Dictionary = record["params"]
		if String(record["id"]) != "objects/column" or not LevelText.applies_to(params, difficulty):
			continue
		if int(params.get("rise", 2)) != 0 or params.has("rise_while") or params.has("sink_while") \
				or params.has("trigger"):
			continue
		var size: PackedInt32Array = LevelText.to_int_list(params.get("size", "1,1"))
		var w: int = maxi(size[0], 1) if size.size() >= 1 else 1
		var h: int = maxi(size[1], 1) if size.size() >= 2 else 1
		var col: int = int(record["col"])
		var row: int = int(record["row"])
		for r: int in range(row - h + 1, row + 1):
			for c: int in range(col, col + w):
				if grid.in_bounds(c, r) and grid.get_char(c, r) == TileGrid.CH_AIR:
					grid.set_char(c, r, TileGrid.CH_SOLID_A)
	return grid


## The gate's area in cells: its tablet and far cell grown by one view, inside the map.
static func gate_area(tablet: Dictionary, grid: TileGrid) -> Rect2i:
	var area: Rect2i = Rect2i(tablet["cell"], Vector2i.ONE).merge(Rect2i(tablet["far"], Vector2i.ONE))
	area = area.grow_individual(AREA_COLS, AREA_ROWS, AREA_COLS, AREA_ROWS)
	return area.intersection(Rect2i(0, 0, grid.cols, grid.rows))


## Where the search starts: the tablet's cell and the last checkpoint before it (by column; '@' when there is none),
## each as a feet point on the floor below.
static func start_points(data: LevelData, difficulty: int, tablet: Dictionary, grid: TileGrid) -> Array[Vector2i]:
	var cell: Vector2i = tablet["cell"]
	var points: Array[Vector2i] = [_ground_below(grid, cell)]
	var best: Vector2i = Vector2i(-1, -1)
	for record: Dictionary in data.entity_records():
		if String(record["id"]) != "objects/checkpoint" or not LevelText.applies_to(record["params"], difficulty):
			continue
		var at: Vector2i = Vector2i(int(record["col"]), int(record["row"]))
		if at.x <= cell.x and at.x > best.x:
			best = at
	if best == Vector2i(-1, -1):
		var starts: Array[Vector2i] = data.find_starts()
		if not starts.is_empty() and starts[0].x <= cell.x:
			best = starts[0]
	if best != Vector2i(-1, -1):
		var point: Vector2i = _ground_below(grid, best)
		if not points.has(point):
			points.append(point)
	return points


## Feet point on the first floor at or below `cell` (the cell's own bottom when there is none).
static func _ground_below(grid: TileGrid, cell: Vector2i) -> Vector2i:
	var row: int = cell.y
	while row < grid.rows - 1 and not TileGrid.is_ground(grid.floor_at(cell.x, row + 1)):
		row += 1
	return LevelText.cell_to_feet(float(cell.x), float(row))


static func node_key(pos: Vector2i) -> Vector2i:
	return Vector2i(pos.x / KEY_PX, pos.y)


## The input macros of the search (one hero, from rest): `name`, `facing`, `flags` (one Defs.IN_* mask per tick),
## `kind` (move / strike / throw / partner), `hand` (the special held for a throw, -1 = the club) and `partner`
## (PARTNER_EGG or PARTNER_IDLE). The moves always; with `world` (a search world) also the waits, the strikes, the
## throws of every special and the partner moves.
static func make_macros(world: bool = false) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var up: int = Defs.IN_UP
	var fire: int = Defs.IN_FIRE
	for dir: int in [Defs.IN_RIGHT, Defs.IN_LEFT]:
		var facing: int = 1 if dir == Defs.IN_RIGHT else -1
		var side: String = "R" if dir == Defs.IN_RIGHT else "L"
		var back: int = Defs.IN_LEFT if dir == Defs.IN_RIGHT else Defs.IN_RIGHT
		for steps: int in [4, 10, 24, 48]:
			result.append(_macro("walk %s%d" % [side, steps], facing, _repeat(dir, steps)))
		result.append(_macro("jump %s" % side, facing, _repeat(up | dir, 9) + _repeat(dir, 16)))
		result.append(_macro("hop %s" % side, facing, _repeat(up | dir, 4) + _repeat(dir, 10)))
		result.append(_macro("run-jump %s" % side, facing, _repeat(dir, 6) + _repeat(up | dir, 9) + _repeat(dir, 18)))
		result.append(_macro("jump-back %s" % side, facing, _repeat(up | dir, 9) + _repeat(back, 12)))
		result.append(_macro("rise-then-%s" % side, facing, _repeat(up, 6) + _repeat(up | dir, 4) + _repeat(dir, 14)))
		result.append(_macro("crawl %s" % side, facing, _repeat(Defs.IN_DOWN | dir, 24)))
		if not world:
			continue
		# Waits (a door opening while he stands on its plate, a lift coming), then a move.
		result.append(_macro("wait-walk %s" % side, facing, _repeat(0, 40) + _repeat(dir, 40)))
		# Strikes with the club: forward, low, in the air, the pogo (a low strike falling onto a head or a spot).
		result.append(_macro("strike %s" % side, facing, _repeat(dir, 1) + _repeat(fire, 12) + _repeat(0, 4),
				"strike"))
		result.append(_macro("low-strike %s" % side, facing, _repeat(dir, 1) + _repeat(Defs.IN_DOWN | fire, 12),
				"strike"))
		result.append(_macro("jump-strike %s" % side, facing, _repeat(up | dir, 9) + _repeat(dir | fire, 12)
				+ _repeat(dir, 8), "strike"))
		result.append(_macro("pogo %s" % side, facing, _repeat(up | dir, 9) + _repeat(dir | Defs.IN_DOWN | fire, 16),
				"strike"))
		result.append(_macro("strike-walk %s" % side, facing, _repeat(dir, 1) + _repeat(fire, 12) + _repeat(dir, 36),
				"strike"))
		# Throws of every special (each held in the hand for the move, the club on the belt).
		for weapon: int in THROW_WEAPONS:
			var label: String = ["club", "hammer", "axe", "swirl", "spear"][weapon]
			result.append(_macro("throw %s %s" % [label, side], facing, _repeat(dir, 1) + _repeat(fire, 6)
					+ _repeat(0, 24), "throw", weapon))
		result.append(_macro("jump-throw axe %s" % side, facing, _repeat(up | dir, 9) + _repeat(dir | fire, 6)
				+ _repeat(dir, 12), "throw", Defs.Weapon.AXE))
		# The idle partner where the hero stands (heroes pass through each other): a jump straight up lands on his
		# head (a Totem Ride - he never jumps, so it is the still carrier's; UP released before the landing, else he
		# passes through an inactive partner: no Shoulder Hop), then a jump off it forward or a run and a jump.
		var onto: PackedInt32Array = _repeat(up, 9) + _repeat(0, 16)
		result.append(_macro("partner-jump %s" % side, facing, onto + _repeat(up | dir, 9) + _repeat(dir, 16),
				"partner", -1, PARTNER_IDLE))
		result.append(_macro("partner-run-jump %s" % side, facing, onto + _repeat(dir, 3) + _repeat(up | dir, 9)
				+ _repeat(dir, 16), "partner", -1, PARTNER_IDLE))
		# Leave him standing where he is (on a plate, as bait before a keeper) and go on.
		result.append(_macro("partner-leave-walk %s" % side, facing, _repeat(dir, 48), "partner", -1, PARTNER_IDLE))
	result.append(_macro("jump up", 1, _repeat(up, 12)))
	result.append(_macro("drop", 1, _repeat(Defs.IN_DOWN, 10)))
	if world:
		result.append(_macro("partner-up", 1, _repeat(up, 9) + _repeat(0, 16) + _repeat(up, 12), "partner", -1,
				PARTNER_IDLE))
	return result


static func _macro(name: String, facing: int, flags: PackedInt32Array, kind: String = "move", hand: int = -1,
		partner: int = PARTNER_EGG) -> Dictionary:
	return {"name": name, "facing": facing, "flags": flags, "kind": kind, "hand": hand, "partner": partner}


static func _repeat(flags: int, count: int) -> PackedInt32Array:
	var result: PackedInt32Array = PackedInt32Array()
	result.resize(count)
	result.fill(flags)
	return result


# =================================================================================================================
# Windows (DESIGN.md D.8 #4)
# =================================================================================================================

## Every twin window and daze record inside `area` with the solo minimum measured: drum bonds, enemy bonds, `daze`
## enemies, timed plates.
static func measure_windows(data: LevelData, difficulty: int, area: Rect2i, searcher: Searcher) -> Array:
	var windows: Array = []
	var groups: Dictionary = {}   # "drums:<bond>" / "bond:<bond>" -> Array of cells
	var caps: Dictionary = {}     # "bond:<bond>" -> the group's window (the smallest `window=` cap of its members)
	var plates: Dictionary = {}
	var columns: Array[Dictionary] = []
	var grid: TileGrid = searcher.level.grid
	for record: Dictionary in data.entity_records():
		var params: Dictionary = record["params"]
		if not LevelText.applies_to(params, difficulty):
			continue
		var id: String = String(record["id"])
		var cell: Vector2i = Vector2i(int(record["col"]), int(record["row"]))
		if id == "objects/drum" and params.has("bond"):
			_append_cell(groups, "drums:" + str(params["bond"]), cell)
		elif Spawner.category(StringName(id)) == "enemies" and str(params.get("coop", "")) == "bond" \
				and params.has("bond"):
			var key: String = "bond:" + str(params["bond"])
			_append_cell(groups, key, cell)
			var capped: int = CoopTraits.capped_window(PartyTuning.window_ticks(difficulty), params)
			caps[key] = mini(int(caps.get(key, capped)), capped)
		if Spawner.category(StringName(id)) == "enemies" and area.has_point(cell) \
				and (str(params.get("coop", "")) == "daze" or id == "enemies/raptor"):
			windows.append({"what": "daze %s at %d,%d" % [id, cell.x, cell.y],
				"window": CoopTraits.capped_window(PartyTuning.daze_ticks(difficulty), params),
				"solo_min": measure_daze_solo_min(id)})
		if id == "objects/plate" and params.has("name") and str(params.get("mode", "")).begins_with("timed:"):
			plates[str(params["name"])] = record
		if id == "objects/column" and (params.has("rise_while") or params.has("sink_while")):
			columns.append(record)
	for key: String in groups:
		var cells: Array = groups[key]
		var inside: bool = false
		for cell: Vector2i in cells:
			inside = inside or area.has_point(cell)
		if not inside or cells.size() < 2:
			continue
		var solo_min: int = 0
		for i: int in cells.size():
			for j: int in range(i + 1, cells.size()):
				solo_min = maxi(solo_min, pair_solo_min(cells[i], cells[j], grid, area, searcher))
		windows.append({"what": key.replace(":", " "),
			"window": int(caps.get(key, PartyTuning.window_ticks(difficulty))), "solo_min": solo_min})
	for plate_name: String in plates:
		var plate: Dictionary = plates[plate_name]
		var plate_cell: Vector2i = Vector2i(int(plate["col"]), int(plate["row"]))
		if not area.has_point(plate_cell):
			continue
		var timer: int = str(plate["params"]["mode"]).substr(6).to_int()
		for column: Dictionary in columns:
			var names: String = str(column["params"].get("rise_while", column["params"].get("sink_while", "")))
			if not LevelText.to_list(names).has(plate_name):
				continue
			var rise: int = int(column["params"].get("rise", 2))
			var door: Vector2i = Vector2i(int(column["col"]), int(column["row"]))
			var travel: int = travel_ticks([_ground_below(grid, plate_cell)], _door_spots(grid, door), area, searcher)
			windows.append({"what": "timed plate %s" % plate_name,
				"window": timer + rise * PartyTuning.PLATE_COLUMN_PERIOD, "solo_min": travel})
	return windows


## The least ticks one hero needs between striking the member at `a` and the member at `b` (either order): 0 when a
## thrown special from a strike spot of one crosses the other; else, for members so far apart that even the fastest
## hero (HERO_MAX_PX_PER_TICK, nothing in his way) needs more than the largest window plus its margin to go from one
## strike spot to the other, that lower bound (no search: D5's 731-second bond of members 60-80 columns apart);
## else the run between their strike spots (BOUND_TICKS when he cannot get there).
static func pair_solo_min(a: Vector2i, b: Vector2i, grid: TileGrid, area: Rect2i, searcher: Searcher) -> int:
	var spots_a: Array[Vector2i] = strike_spots(grid, a)
	var spots_b: Array[Vector2i] = strike_spots(grid, b)
	if throw_crosses(spots_a, b) or throw_crosses(spots_b, a):
		return 0
	var bound: int = pair_lower_bound(a, b)
	if bound > PartyTuning.WINDOW_TICKS_BEGINNER + PartyTuning.WINDOW_SOLO_MARGIN_TICKS:
		return bound
	var goals: Dictionary = {}
	for spot: Vector2i in spots_b:
		goals[Vector2i(Tuning.to_cell(spot.x), Tuning.to_cell(spot.y - 1))] = true
	return travel_ticks(spots_a, goals, area, searcher)


## The fewest ticks any hero needs between strike spots of members at the cells `a` and `b`: their columns less the
## strike reach on both sides (2 cells each), at HERO_MAX_PX_PER_TICK.
static func pair_lower_bound(a: Vector2i, b: Vector2i) -> int:
	var gap_px: int = maxi(absi(a.x - b.x) - 2 * STRIKE_REACH_SPOT_COLS, 0) * Tuning.TILE
	return gap_px / HERO_MAX_PX_PER_TICK


## Ticks of the shortest search path from `starts` into a cell of `goals` (BOUND_TICKS when none within the bound).
static func travel_ticks(starts: Array[Vector2i], goals: Dictionary, area: Rect2i, searcher: Searcher) -> int:
	if starts.is_empty() or goals.is_empty():
		return BOUND_TICKS
	var found: Dictionary = searcher.explore(starts, goals, area, BOUND_TICKS, MAX_NODES)
	return int(found["ticks"]) if found["reached"] else BOUND_TICKS


## Feet points from which a strike reaches the cell `target`: standing cells one or two columns beside it, with the
## target up to two rows above the feet row (forward, high and low boxes, PHYSICS.md 8.2).
static func strike_spots(grid: TileGrid, target: Vector2i) -> Array[Vector2i]:
	var spots: Array[Vector2i] = []
	for dc: int in [-2, -1, 1, 2]:
		for dr: int in [0, 1, 2]:
			var cell: Vector2i = Vector2i(target.x + dc, target.y + dr)
			if not grid.in_bounds(cell.x, cell.y + 1) or grid.side_at(cell.x, cell.y) == TileGrid.SIDE_WALL:
				continue
			if TileGrid.is_ground(grid.floor_at(cell.x, cell.y + 1)):
				spots.append(LevelText.cell_to_feet(float(cell.x), float(cell.y)))
	return spots


## Standing spots beside a door block (one or two columns either side of its anchor).
static func _door_spots(grid: TileGrid, door: Vector2i) -> Dictionary:
	var goals: Dictionary = {}
	for spot: Vector2i in strike_spots(grid, door):
		goals[Vector2i(Tuning.to_cell(spot.x), Tuning.to_cell(spot.y - 1))] = true
	return goals


## True when an axe, a swirling axe or a spear thrown either way from one of `spots` (no tile collision: they pass
## walls, PHYSICS.md 8.4 / C.3) crosses the cell `target` within 40 ticks.
static func throw_crosses(spots: Array[Vector2i], target: Vector2i) -> bool:
	var box: Rect2i = Rect2i(target.x * Tuning.TILE, target.y * Tuning.TILE, Tuning.TILE, Tuning.TILE)
	for spot: Vector2i in spots:
		for facing: int in [1, -1]:
			for kind: int in [Defs.Weapon.AXE, Defs.Weapon.BOOMERANG, Defs.Weapon.SPEAR]:
				var pos: Vector2i = spot + Vector2i(facing * 20, -16)
				var xvel: int = (Tuning.SPEAR_XVEL if kind == Defs.Weapon.SPEAR else Tuning.THROW_XVEL) * facing
				var yvel: int = Tuning.AXE_YVEL if kind == Defs.Weapon.AXE else (Tuning.BOOMERANG_YVEL
						if kind == Defs.Weapon.BOOMERANG else 0)
				for t: int in 40:
					pos += Vector2i(Tuning.floor16(xvel), Tuning.floor16(yvel))
					match kind:
						Defs.Weapon.AXE:
							yvel += Tuning.AXE_YACC
						Defs.Weapon.BOOMERANG:
							yvel += Tuning.BOOMERANG_YACC
						_:
							if t >= Tuning.SPEAR_FLAT_TICKS:
								yvel = mini(yvel + 16, Tuning.SPEAR_FALL_MAX)
					if Overlap.rects(Rect2i(pos.x - 8, pos.y - 16, 16, 16), box):
						return true
	return false


static func _append_cell(groups: Dictionary, key: String, cell: Vector2i) -> void:
	if not groups.has(key):
		groups[key] = []
	(groups[key] as Array).append(cell)


# --- The daze: ticks from a head bounce to the first damaging box -------------------------------------------------------

static var _daze_cache: Dictionary = {}


## The solo minimum of a `daze` record (DESIGN.md D.6, R12): the least ticks the real hero needs from his head bounce
## on a still target the size of `enemy_id` (its scene's box; 32 x 32 without one) to the first strike that hits it,
## over approaches from both sides with forward, low and high strikes started 0-12 ticks after the bounce. Measured
## once per box.
static func measure_daze_solo_min(enemy_id: String) -> int:
	var box: Vector3i = Vector3i(32, 32, 16)
	if Spawner.exists(StringName(enemy_id)):
		var probe: SimEntity = Spawner.instantiate(StringName(enemy_id)) as SimEntity
		if probe != null:
			box = Vector3i(probe.box_w, probe.box_h, probe.box_xo)
			probe.free()
	if _daze_cache.has(box):
		return int(_daze_cache[box])
	var rows: PackedStringArray = PackedStringArray()
	for row: int in 16:
		rows.append((TileGrid.CH_SOLID_A if row >= 14 else TileGrid.CH_AIR).repeat(30))
	var searcher: Searcher = Searcher.new()
	if not searcher.build(&"coop_search_daze", {}, TileGrid.from_rows(rows)):
		return BOUND_TICKS
	var target: EnemyBase = EnemyBase.new()
	target.set_box(box)
	target.spawn_setup(Vector2i(240, 224), {})
	searcher.level.add_child(target)
	target.max_hp = 99999
	target.hp = 99999
	var best: int = BOUND_TICKS
	var strikes: Array[int] = [Defs.IN_FIRE, Defs.IN_DOWN | Defs.IN_FIRE, Defs.IN_UP | Defs.IN_FIRE]
	for side: int in [-1, 1]:
		var dir: int = Defs.IN_RIGHT if side < 0 else Defs.IN_LEFT
		var back: int = Defs.IN_LEFT if side < 0 else Defs.IN_RIGHT
		# 1. The approaches that land on the head: every distance and UP hold (a box of any size, any jump arc).
		var approaches: Array[Vector2i] = []
		for distance: int in range(box.x / 2 + DAZE_MIN_GAP_PX, DAZE_MAX_DISTANCE_PX, DAZE_DISTANCE_STEP_PX):
			for hold: int in DAZE_HOLDS:
				if approaches.size() < DAZE_APPROACHES_PER_SIDE and _daze_run(searcher, target,
						Vector2i(240 + side * distance, 224), -side, dir, hold, 0, 0, 0) != DAZE_NO_BOUNCE:
					approaches.append(Vector2i(distance, hold))
		# 2. From each: a forward, low or high strike `delay` ticks after the bounce, holding nothing, on or back.
		for approach: Vector2i in approaches:
			for steer: int in [0, dir, back]:
				for strike: int in strikes:
					for delay: int in 13:
						if delay >= best:
							break  # a hit comes at least `delay` ticks after the bounce
						var ticks: int = _daze_run(searcher, target, Vector2i(240 + side * approach.x, 224), -side, dir,
								approach.y, strike, delay, steer)
						if ticks >= 0:
							best = mini(best, ticks)
	target.free()
	searcher.close()
	_daze_cache[box] = best
	return best


## [method measure_daze_solo_min]'s approaches: start gaps from the target's edge (px), the farthest start, the step,
## the UP holds of the jump, and how many landing approaches per side are tried with every strike.
const DAZE_MIN_GAP_PX: int = 12
const DAZE_MAX_DISTANCE_PX: int = 160
const DAZE_DISTANCE_STEP_PX: int = 4
const DAZE_HOLDS: Array[int] = [1, 3, 5, 7, 9]
const DAZE_APPROACHES_PER_SIDE: int = 3
## [method _daze_run]: no head bounce at all (else -1 = a bounce but no hit, or the ticks from the bounce to the hit).
const DAZE_NO_BOUNCE: int = -2


## One approach of [method measure_daze_solo_min]: jump at the target, then strike `delay` ticks after the bounce
## (holding `steer` from the bounce on; `strike` 0 = no strike). Ticks from the bounce to the first hit, -1 when there
## was none, DAZE_NO_BOUNCE when he never landed on the head.
static func _daze_run(searcher: Searcher, target: EnemyBase, start: Vector2i, facing: int, dir: int, hold: int,
		strike: int, delay: int, steer: int = 0) -> int:
	var hero: PlayerBase = searcher.hero
	target.teleport(Vector2i(240, 224))
	target.wake()
	target.bounce_count = 0
	target.last_hit_tick = -1
	hero.run.reset_energy()
	hero.respawn_at(start)
	hero.facing = facing
	var flags: PackedInt32Array = _repeat(Defs.IN_UP | dir, hold) + _repeat(dir, 30)
	searcher._flags = flags
	searcher._first_tick = Sim.tick + 1
	var bounce_tick: int = -1
	for t: int in 60:
		Sim.step(1)
		if hero.dead:
			return -1 if bounce_tick >= 0 else DAZE_NO_BOUNCE
		if bounce_tick < 0 and target.bounce_count > 0:
			bounce_tick = Sim.total_ticks
			if strike == 0:
				return -1
			# From the bounce on: `steer` alone for `delay` ticks, then the strike held for a swing.
			var index: int = Sim.tick + 1 - searcher._first_tick
			var rest: PackedInt32Array = _repeat(steer, delay) + _repeat(strike | steer, STRIKE_FRAMES + 4)
			searcher._flags = flags.slice(0, index) + rest
		if bounce_tick >= 0 and target.last_hit_tick >= bounce_tick:
			return target.last_hit_tick - bounce_tick
	return -1 if bounce_tick >= 0 else DAZE_NO_BOUNCE
