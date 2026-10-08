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
##     - 4, except for a record marked "slot_bound" (G34 / G47): the daze, once [method daze_slot_bound] finds the
##     engine glancing the bouncer's own hits (one player never meets it, whatever its window).
##  The partner model of G33 (orchestrator, IDLE-PARTNER RULE): the idle hatched partner is part of the lone player's
##  toolkit - parked anywhere his egg could be clubbed open (a `place partner` node at every resting point near a co-op
##  mechanism or trait enemy) - but counts for no co-op rule (the engine's PlayerBase.is_idle / counts_for_coop, which
##  the search world forces on him at every placement); the ride macros on his head run only while
##  [method idle_partner_carries] finds the engine still giving a ride on an idle head (since G33 it does not).
## The cheap flood of [method flood_reaches] (no chain of feet cells on the grid at rest) is kept as a diagnostic
## (result "flood"); it never decides a gate: the search runs on every gate.
## Limits (v2): the moving things (walking enemies, platforms, geysers) start every macro in their level-file phase,
## so a timing that needs a walker or a lift somewhere else than its post at the start of a move is only found when
## the path got there through changed nodes; macros start from rest (momentum between macros is not carried); the
## bound is per resting point, not a full input-space search; the hero holds one special per move (each special is
## tried), not two.

## Game ticks a single hero is allowed per path (LEVEL_DESIGN.md 15.7.6: 1 457 ticks *(tune)*).
const BOUND_TICKS: int = 1457
## Resting points explored at most per search (a compute bound; with MAX_TICKS, see there).
const MAX_NODES: int = 1500
## Resting points of a window's travel search on the bare grid ([method travel_ticks]: the least ticks between two
## spots; it stops at the first arrival, so the bound only matters for a spot it cannot reach).
const WINDOW_NODES: int = 220
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
## No spot (no partner placed, no position to check).
const NOWHERE: Vector2i = Vector2i(-1, -1)
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
## [method Searcher.bait_spots]: the idle partner's feet this far (px) clear of a keeper's or shell enemy's box, in
## front of it and behind it - within the reach of a club swung at it from there.
const BAIT_GAP_PX: int = 10
## A strike or throw macro faces one way: a target counts for it when it lies on that side or at most this far (px)
## behind the hero's feet point (a target overlapping him, a walker coming round him during the move).
const BEHIND_REACH_PX: int = 2 * Tuning.TILE
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
## The continuous-play probe families (orchestrator's SEARCH decision, wf10; [method Searcher.probe_battery]).
const PROBE_HOP_OVER: String = "hop-over"
const PROBE_CHARGE_UNDER: String = "charge-under"
const PROBE_IDLE_BAIT: String = "idle-bait"
const PROBE_THROWN: String = "thrown-special"
const PROBE_PLATES: String = "plates"
const PROBE_EGG: String = "egg placement"
const PROBE_FAMILIES: Array[String] = [PROBE_HOP_OVER, PROBE_CHARGE_UNDER, PROBE_IDLE_BAIT, PROBE_THROWN,
	PROBE_PLATES, PROBE_EGG]
## Plate races: ticks on the plate before the run for the door, and the px before the door where he jumps or crawls.
const PROBE_RACE_WAITS: Array[int] = [0, 40, 120]
const PROBE_RACE_PX: Array[int] = [16, 48]
## Ticks a probe's policy plays (then the hero lets go and comes to rest within SETTLE_TICKS).
const PROBE_TICKS: int = 420
## A probe's end (a changed world) replays this long a prefix at most, and so may its descendants.
const PROBE_PREFIX_TICKS: int = 1100
## Nodes per probe target that run its battery (the partner still an egg; the starts first).
const PROBE_SITES: int = 2
## Changed worlds a site's probes hand to the BFS at most (each costs a replay per later move).
const PROBE_SEEDS_PER_SITE: int = 6
## A probe target is in reach of a node within this many cells (x, y).
const PROBE_REACH_CELLS: Vector2i = Vector2i(20, 6)
## Duels: the gap (px, hero feet to the enemy's box) at which he jumps, and the UP holds.
const PROBE_TRIGGERS_PX: Array[int] = [4, 24, 44, 72]
const PROBE_HOLDS: Array[int] = [4, 9, 12]
## Idle-bait: ticks the hero stands first (the enemy goes for the parked partner), and how much farther than the bait
## gap the lure spots lie.
const PROBE_LURE_WAITS: Array[int] = [0, 60]
const PROBE_LURE_EXTRA_PX: Array[int] = [0, 48, 112]
## Thrown specials: px from the plate's centre where he throws.
const PROBE_THROW_PX: Array[int] = [24, 64, 128]
## Leaps at the far cell: run-up ticks away from it first, and the px before its column where he jumps.
const PROBE_LEAP_RUNUPS: Array[int] = [0, 24]
const PROBE_LEAP_PX: Array[int] = [16, 48, 80]
## The search's default compute bounds (wf10: raised from 220 resting points): resting points expanded and ticks
## simulated per gate, whichever comes first; a search whose queue runs dry first is EXHAUSTIVE.
const MAX_TICKS: int = 1500000
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


## The wind of a search world: the level's script (meta `wind`, `wind_loop`, PHYSICS.md 13.1 / C.6) exactly as
## Level._apply_wind_script runs it, restarted at every run (from play tick 0, like every moving thing of the search
## world: a gust's phase at the start of a move is the level start's - the `wait-walk` moves wait 40 ticks).
class SearchWind:
	extends RefCounted

	var _level: LevelBase = null
	var _script: Array[Vector2i] = []
	var _loop: int = 0
	var _index: int = 0
	var _base: int = 0
	var _play: int = 0

	func _init(level: LevelBase, script: Array[Vector2i], loop: int) -> void:
		_level = level
		_script = script
		_loop = loop

	## The level start: no wind, then the entries of tick 0 and 1 (Level._setup_world_state).
	func restart() -> void:
		_index = 0
		_base = 0
		_play = 0
		_level.set_wind(0)
		_apply()

	## Phase WORLD (Level._world_step).
	func step() -> void:
		_play += 1
		_apply()

	func _apply() -> void:
		if _loop > 0 and not _script.is_empty() and _play + 1 - _base >= _loop:
			_base += _loop
			_index = 0
		while _index < _script.size() and _script[_index].x <= _play + 1 - _base:
			_level.set_wind(_script[_index].y)
			_index += 1


## A continuous-play probe's input policy ([method Searcher.probe_run]): the hero's flags tick by tick, decided from
## the world it reads. [member family] names the gate kind it probes (PROBE_FAMILIES), [member label] its parameters.
class ProbePolicy:
	extends RefCounted

	var family: String = ""
	var label: String = ""
	## The far cell's centre x (px): where the GO phase heads.
	var far_x: int = 0
	var _hops: int = 0
	var _blocked: int = 0
	var _go_jump: int = 0

	func begin(_searcher: Searcher) -> void:
		pass

	## The flags of tick `t` (from 0), or -1 when the probe is over (the hero lets go and comes to rest).
	func next(_searcher: Searcher, _t: int) -> int:
		return -1

	static func dir_flag(dir: int) -> int:
		return Defs.IN_RIGHT if dir > 0 else (Defs.IN_LEFT if dir < 0 else 0)

	## True after the hero pressed a side for a few ticks without moving (a step, a wall): time for a hop.
	func blocked(hero: PlayerBase, pressing: bool) -> bool:
		_blocked = _blocked + 1 if pressing and hero.is_grounded() and hero.xvel == 0 else 0
		return _blocked >= 4

	## The GO phase: on toward the far cell, a full jump whenever a step or wall stops him (a crude navigator - its
	## rest point goes to the BFS, which does the real navigation from there).
	func go(hero: PlayerBase) -> int:
		var dir: int = signi(far_x - hero.sim_pos.x)
		if _go_jump > 0:
			_go_jump -= 1
			return Defs.IN_UP | dir_flag(dir)
		if blocked(hero, dir != 0):
			_blocked = 0
			_go_jump = 9
			return Defs.IN_UP | dir_flag(dir)
		return dir_flag(dir)


## HOP-OVER / CHARGE-UNDER / IDLE-BAIT: walk at a role enemy (a keeper, a shell, a heavy, any trait or bond enemy);
## jump when it is `trigger_px` away (on over it, `steer` 1; straight up so that a charging heavy runs under, 0); land
## behind it, turn and strike its back (forward or low, `low` also pogo-strikes on the way down) while it is in reach,
## jumping again (at most 3 times) when it comes at him; once it is dead, GO for the far cell. `wait` ticks standing
## first: the lure (an idle partner parked beside it draws it - plain targeting still picks him).
class DuelPolicy:
	extends ProbePolicy

	enum Phase { WAIT, APPROACH, JUMP, STRIKE, GO }
	const STRIKE_CYCLE: int = 14
	const STRIKE_CYCLES_MAX: int = 18
	const HOPS_MAX: int = 3

	var target_index: int = -1
	var trigger_px: int = 24
	var hold: int = 9
	var steer: int = 1
	var low: bool = false
	var wait: int = 0
	var _target: EnemyBase = null
	var _phase: int = Phase.WAIT
	var _since: int = 0
	var _dir: int = 1
	var _cycles: int = 0
	var _cycle_tick: int = 0

	func begin(searcher: Searcher) -> void:
		_target = searcher.entity_at(target_index) as EnemyBase
		_phase = Phase.WAIT
		_since = 0
		_hops = 0
		_cycles = 0
		_cycle_tick = 0
		_blocked = 0
		_go_jump = 0

	func _enter(phase: int) -> void:
		_phase = phase
		_since = 0
		_cycle_tick = 0

	func _gone() -> bool:
		return _target == null or not is_instance_valid(_target) or _target.dead

	## Px between the hero's feet point and the target's near box edge.
	func _gap(hero: PlayerBase) -> int:
		return maxi(absi(_target.sim_pos.x - hero.sim_pos.x) - _target.box_w / 2, 0)

	func _coming(hero: PlayerBase) -> bool:
		return _target.xvel != 0 and signi(_target.xvel) == signi(hero.sim_pos.x - _target.sim_pos.x)

	func next(searcher: Searcher, _t: int) -> int:
		var hero: PlayerBase = searcher.hero
		_since += 1
		if _phase != Phase.GO and _gone():
			_enter(Phase.GO)
		match _phase:
			Phase.WAIT:
				if _since > wait:
					_enter(Phase.APPROACH)
				return 0
			Phase.APPROACH:
				_dir = signi(_target.sim_pos.x - hero.sim_pos.x)
				if _dir == 0:
					_dir = hero.facing
				if _gap(hero) <= trigger_px:
					_enter(Phase.JUMP)
					return Defs.IN_UP | dir_flag(_dir * steer)
				if blocked(hero, true):
					_blocked = 0
					return Defs.IN_UP | dir_flag(_dir)
				return dir_flag(_dir)
			Phase.JUMP:
				var air: int = dir_flag(_dir * steer)
				if _since <= hold:
					return Defs.IN_UP | air
				if hero.is_grounded() and _since > hold + 1:
					_enter(Phase.STRIKE)
					return 0
				return air | (Defs.IN_DOWN | Defs.IN_FIRE if low else 0)
			Phase.STRIKE:
				var toward: int = signi(_target.sim_pos.x - hero.sim_pos.x)
				if toward == 0:
					toward = hero.facing
				if _hops < HOPS_MAX and _coming(hero) and _gap(hero) <= trigger_px and hero.is_grounded():
					_hops += 1
					_dir = toward
					_enter(Phase.JUMP)
					return Defs.IN_UP | dir_flag(_dir * steer)
				if _gap(hero) > 20 and _cycle_tick == 0:
					return dir_flag(toward)
				var step: int = _cycle_tick
				_cycle_tick = (_cycle_tick + 1) % STRIKE_CYCLE
				if step == 0:
					_cycles += 1
					if _cycles > STRIKE_CYCLES_MAX:
						_enter(Phase.GO)
						return 0
					return dir_flag(toward) if hero.facing != toward else 0
				if step <= 10:
					return Defs.IN_FIRE | (Defs.IN_DOWN if low and (_cycles & 1) == 0 else 0)
				return 0
		return go(hero)


## THROWN-SPECIAL PLATES: walk toward a plate until `distance` px from its centre, throw the special in his hand at it
## (or a jump-throw), then GO through its door for the far cell - a plate weighs only active heroes (and a boulder),
## so the door must stay shut; the probe asks the engine, continuous with the run for the door.
class ThrowPolicy:
	extends ProbePolicy

	enum Phase { APPROACH, THROW, FOLLOW, GO }

	var spot_x: int = 0
	var distance: int = 32
	var jump: bool = false
	## After the throw: a duel with this target (a keeper struck from behind after a throw), or -1.
	var duel: DuelPolicy = null
	## After the throw: walk to this x and strike there (the other drum of a bond), or -1.
	var strike_x: int = -1
	var _phase: int = Phase.APPROACH
	var _since: int = 0
	var _toward: int = 1

	func begin(searcher: Searcher) -> void:
		_phase = Phase.APPROACH
		_since = 0
		_blocked = 0
		_go_jump = 0
		if duel != null:
			duel.far_x = far_x
			duel.begin(searcher)

	func next(searcher: Searcher, _t: int) -> int:
		var hero: PlayerBase = searcher.hero
		_since += 1
		match _phase:
			Phase.APPROACH:
				_toward = signi(spot_x - hero.sim_pos.x)
				if _toward == 0:
					_toward = hero.facing
				if absi(spot_x - hero.sim_pos.x) <= distance or _since > 240 or blocked(hero, true):
					_phase = Phase.THROW
					_since = 0
					return dir_flag(_toward)
				return dir_flag(_toward)
			Phase.THROW:
				if _since > 30:
					_phase = Phase.FOLLOW if duel != null or strike_x >= 0 else Phase.GO
					_since = 0
					return 0
				if jump:
					if _since <= 6:
						return Defs.IN_UP | dir_flag(_toward)
					return (dir_flag(_toward) | Defs.IN_FIRE) if _since <= 12 else 0
				return Defs.IN_FIRE if _since <= 6 else 0
			Phase.FOLLOW:
				if duel != null:
					return duel.next(searcher, _t)
				var dir: int = signi(strike_x - hero.sim_pos.x)
				if absi(strike_x - hero.sim_pos.x) > 20 and _since < 200:
					if blocked(hero, true):
						_blocked = 0
						return Defs.IN_UP | dir_flag(dir)
					return dir_flag(dir)
				var step: int = _since % 14
				if _since > 260:
					_phase = Phase.GO
				return Defs.IN_FIRE if step >= 1 and step <= 10 else 0
		return go(hero)


## PLATES: onto a plate, `wait` ticks on it (the door rises; a `timed:` clock starts when he leaves), then a race for its
## door at full speed - straight, or a jump / a crawl `trigger_px` before the door (under a closing column) - and on
## for the far cell. With the idle partner parked on the plate or in the door's way (IDLE-BAIT: the doorstop of G53).
class RacePolicy:
	extends ProbePolicy

	enum Phase { TO_PLATE, WAIT, RUN, MOVE, GO }
	enum Mode { RUN, JUMP, CRAWL }

	var plate_x: int = 0
	var door_x: int = 0
	var wait: int = 0
	var mode: int = Mode.RUN
	var trigger_px: int = 32
	var _phase: int = Phase.TO_PLATE
	var _since: int = 0
	var _dir: int = 1

	func begin(_searcher: Searcher) -> void:
		_phase = Phase.TO_PLATE
		_since = 0
		_blocked = 0
		_go_jump = 0

	func next(searcher: Searcher, _t: int) -> int:
		var hero: PlayerBase = searcher.hero
		_since += 1
		match _phase:
			Phase.TO_PLATE:
				var dir: int = signi(plate_x - hero.sim_pos.x)
				if absi(plate_x - hero.sim_pos.x) <= 4 or _since > 240:
					_phase = Phase.WAIT
					_since = 0
					return 0
				if blocked(hero, dir != 0):
					_blocked = 0
					return Defs.IN_UP | dir_flag(dir)
				return dir_flag(dir)
			Phase.WAIT:
				if _since > wait:
					_phase = Phase.RUN
					_since = 0
					_dir = signi(door_x - hero.sim_pos.x)
					if _dir == 0:
						_dir = hero.facing
				return 0
			Phase.RUN:
				if mode != Mode.RUN and absi(door_x - hero.sim_pos.x) <= trigger_px:
					_phase = Phase.MOVE
					_since = 0
				elif (hero.sim_pos.x - door_x) * _dir > Tuning.TILE or _since > 160:
					_phase = Phase.GO
				else:
					return dir_flag(_dir)
				return Defs.IN_UP | dir_flag(_dir) if _phase == Phase.MOVE and mode == Mode.JUMP else dir_flag(_dir)
			Phase.MOVE:
				if _since > 40:
					_phase = Phase.GO
					return 0
				if mode == Mode.JUMP:
					return Defs.IN_UP | dir_flag(_dir) if _since <= 9 else dir_flag(_dir)
				return Defs.IN_DOWN | dir_flag(_dir)
		return go(hero)


## HOP-OVER of a ledge or gap gate: `back_up` ticks away from the far cell (a run-up), then at full speed toward it and
## a jump `trigger_px` before its column (UP held `hold` ticks, on toward it in the air), then GO - momentum the macros
## (each from rest, a 6-tick run-up at most) never carry.
class LeapPolicy:
	extends ProbePolicy

	enum Phase { BACK, RUN, JUMP, GO }

	var trigger_px: int = 32
	var hold: int = 9
	var back_up: int = 0
	var _phase: int = Phase.BACK
	var _since: int = 0
	var _dir: int = 1

	func begin(searcher: Searcher) -> void:
		_phase = Phase.BACK
		_since = 0
		_blocked = 0
		_go_jump = 0
		_dir = signi(far_x - searcher.hero.sim_pos.x)
		if _dir == 0:
			_dir = searcher.hero.facing

	func next(searcher: Searcher, _t: int) -> int:
		var hero: PlayerBase = searcher.hero
		_since += 1
		match _phase:
			Phase.BACK:
				if _since > back_up:
					_phase = Phase.RUN
					_since = 0
				else:
					return dir_flag(-_dir)
				return dir_flag(_dir)
			Phase.RUN:
				if absi(far_x - hero.sim_pos.x) <= trigger_px or _since > 200:
					_phase = Phase.JUMP
					_since = 0
					return Defs.IN_UP | dir_flag(_dir)
				return dir_flag(_dir)
			Phase.JUMP:
				if _since <= hold:
					return Defs.IN_UP | dir_flag(_dir)
				if hero.is_grounded() and _since > hold + 1:
					_phase = Phase.GO
					return 0
				return dir_flag(_dir)
		return go(hero)


## EGG PLACEMENT: walk past a spot so that the drifting egg (PartyTuning.EGG_OFFSET_X / _Y behind and over his feet)
## comes over it, wait for the drift, turn and hatch it there with a strike (or a jump-strike) - the REAL egg and hatch
## (pop, landing), not a placement - then duel the nearest role enemy with the hatched idle partner where he fell
## (the lure), else GO.
class EggPolicy:
	extends ProbePolicy

	enum Phase { APPROACH, SETTLE, HATCH, AFTER }

	var spot_x: int = 0
	var jump_strike: bool = false
	var duel: DuelPolicy = null
	var _phase: int = Phase.APPROACH
	var _since: int = 0
	var _dir: int = 1

	func begin(searcher: Searcher) -> void:
		_phase = Phase.APPROACH
		_since = 0
		_blocked = 0
		_go_jump = 0
		if duel != null:
			duel.far_x = far_x
			duel.begin(searcher)

	func next(searcher: Searcher, t: int) -> int:
		var hero: PlayerBase = searcher.hero
		_since += 1
		match _phase:
			Phase.APPROACH:
				if _since == 1:
					_dir = signi(spot_x - hero.sim_pos.x)
					if _dir == 0:
						_dir = hero.facing
				# The egg trails EGG_OFFSET_X behind him: he stops that far past the spot.
				if (hero.sim_pos.x - spot_x) * _dir >= -PartyTuning.EGG_OFFSET_X or _since > 240 \
						or blocked(hero, true):
					_phase = Phase.SETTLE
					_since = 0
					return 0
				return dir_flag(_dir)
			Phase.SETTLE:
				if _since >= 30:
					_phase = Phase.HATCH
					_since = 0
				return 0
			Phase.HATCH:
				var back: int = dir_flag(-_dir)
				if _since > 24 or not searcher.partner.is_down():
					_phase = Phase.AFTER
					_since = 0
					return 0
				if _since == 1:
					return back
				if jump_strike:
					return Defs.IN_UP | back if _since <= 5 else (back | Defs.IN_FIRE if _since <= 14 else 0)
				return Defs.IN_FIRE if _since <= 12 else 0
			Phase.AFTER:
				if duel != null:
					return duel.next(searcher, t)
		return go(hero)


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
	## Nodes of the last [method explore] that parked the idle partner (G33's "placed anywhere").
	var placements: int = 0
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
	## Feet points of the keeper / trait / bond enemies where parking the idle partner is tried
	## ([method placement_useful]).
	var _partner_targets: Array[Vector2i] = []
	## Feet points of the co-op mechanisms (plates, see-saws, pulleys and their lifts, heave boulders, drums): parking
	## the idle partner there is tried only while the engine counts an idle hero on a plate
	## ([method CoopSearch.idle_partner_weighs]).
	var _mechanism_targets: Array[Vector2i] = []
	## Spots beside every keeper and `shell` enemy of the world, in front of it and behind it within club reach
	## ([method bait_spots]): the idle partner is parked there from every start (lead designer's wf9 #5).
	var _bait_spots: Array[Vector2i] = []
	## The level's wind script, when the file has one ([class SearchWind]).
	var _wind: SearchWind = null
	## Indices into the world's entities of the role enemies (keeper, trait, bond) and of the plates: the targets of
	## the continuous-play probes ([method probe_battery]).
	var _probe_enemies: Array[int] = []
	var _probe_plates: Array[int] = []
	## ... of the drums, of the door columns (rise_while / sink_while / trigger) and of the other co-op mechanisms
	## (see-saws, heave boulders, pulleys and named platforms - a pulley's lifts).
	var _probe_drums: Array[int] = []
	var _probe_doors: Array[int] = []
	var _probe_mechs: Array[int] = []
	## The probes of the last [method explore] per family (PROBE_FAMILIES): {"runs", "sites", "kills" (runs in which a
	## role enemy died), "seeds" (their end states handed to the BFS), "dead" (runs in which the hero died or went
	## down), "reached"}.
	var probe_stats: Dictionary = {}

	## The world entity at `index` (null when there is none any more).
	func entity_at(index: int) -> SimEntity:
		if index < 0 or index >= _entities.size():
			return null
		var entity: SimEntity = _entities[index]
		return entity if entity != null and is_instance_valid(entity) else null

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
		# The level's wind (meta `wind`, `wind_loop`), stepped first in the WORLD phase as the level's own driver does.
		var script: Array[Vector2i] = data.wind_script(difficulty)
		if not script.is_empty():
			_wind = SearchWind.new(level, script, int(level.meta.get("wind_loop", 0)))
			var wind_driver: LevelDriver = LevelDriver.new()
			wind_driver.setup(_wind.step, Callable(), Callable())
			level.add_child(wind_driver)
			_kept[wind_driver.get_instance_id()] = true
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
			if CoopSearch.is_mechanism_target(record):
				_mechanism_targets.append(node.sim_pos)
			elif CoopSearch.is_partner_target(record) \
					or node is EnemyBase and CoopSearch.has_coop_role(node as EnemyBase):
				_partner_targets.append(node.sim_pos)
			if node is EnemyBase:
				_bait_spots.append_array(bait_spots(node as EnemyBase))
				if CoopSearch.has_coop_role(node as EnemyBase):
					_probe_enemies.append(_entities.size() - 1)
			elif node is Plate:
				_probe_plates.append(_entities.size() - 1)
			elif id == "objects/drum":
				_probe_drums.append(_entities.size() - 1)
			elif id == "objects/column" and (params.has("rise_while") or params.has("sink_while")
					or params.has("trigger")):
				_probe_doors.append(_entities.size() - 1)
			elif CoopSearch.is_mechanism_target(record) or id == "objects/platform" and params.has("name"):
				_probe_mechs.append(_entities.size() - 1)
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
		return "|".join(parts)

	## Play `flags` on a reset world from the run configuration `config` ([method _config]: "start", "facing", "hand"
	## (-1: the club), "partner" (PARTNER_EGG / PARTNER_IDLE: an idle hero on the start spot), "partner_at" (an idle hero
	## placed there; NOWHERE: none)). `events` ([tick, kind, value], sorted by tick) are applied after `tick` ticks were
	## played: "hand" (value: the special in his hand from then on), "place" (value: the spot - the idle partner is put
	## where the hero stands, which a replay has checked is that spot). The first `skip` ticks are a replay (no goal
	## test; after them the hero stands at `expect` unless it is NOWHERE). {"goal": true, "ticks"} when the feet point
	## entered a cell of `goals`; at rest {"pos", "ticks" (after the replay), "played" (every flag of the run up to the
	## rest), "sig"}; {} when he died, went down or did not come to rest.
	func run(config: Dictionary, flags: PackedInt32Array, goals: Dictionary, skip: int = 0,
			expect: Vector2i = NOWHERE, events: Array = []) -> Dictionary:
		_begin(config)
		_flags = flags
		var clock: int = Time.get_ticks_usec()
		var outcome: Dictionary = _play(flags, goals, skip, expect, events)
		CoopSearch.profile_add(&"step", clock)
		return _at_rest(outcome)

	## The start of a run: the world reset (a search world), the hero at config's start with its facing and hand, the
	## partner placed, the wind restarted; the input clock starts on the next tick.
	func _begin(config: Dictionary) -> void:
		runs += 1
		var clock: int = Time.get_ticks_usec()
		if world:
			_tick_max = maxi(_tick_max, Sim.tick)
			Sim.tick = _tick_base
			reset_world()
		CoopSearch.profile_add(&"reset", clock)
		clock = Time.get_ticks_usec()
		var start: Vector2i = config["start"]
		var facing: int = int(config["facing"])
		hero.run.reset_energy()
		_set_hand(int(config["hand"]))
		hero.respawn_at(start)
		hero.facing = facing
		_mark_active(hero)
		if world:
			var at: Vector2i = config["partner_at"]
			if at != NOWHERE:
				_place_idle(at, facing)
			else:
				_place_partner(int(config["partner"]), start, facing)
			level.refresh_doze()
			if _wind != null:
				_wind.restart()
		_first_tick = Sim.tick + 1
		CoopSearch.profile_add(&"place", clock)

	## A run's outcome at rest completed: its world signature (a search world); {} when he rests where a fresh run
	## cannot put him back (on the idle partner's head); a rest on a platform is a changed node.
	func _at_rest(outcome: Dictionary) -> Dictionary:
		if outcome.has("pos") and world:
			var clock: int = Time.get_ticks_usec()
			outcome["sig"] = signature()
			CoopSearch.profile_add(&"sig", clock)
		if outcome.has("pos") and hero.is_riding_totem():
			# At rest on the idle partner's head: no node. A fresh run cannot put him back there (respawn_at would
			# stand him on the air - the search's own bug before phase 3), and the ride macros already play the ride
			# and the jump off it in one move (since G33 an idle head carries no ride at all: a regression check).
			return {}
		if outcome.has("pos") and hero.on_platform:
			# He rests on something that moves or is reset (a lift, a raft), not on the grid: a fresh run cannot put
			# him back there, so the node is a changed one - its replay brings back exactly that platform and him on it.
			outcome["sig"] = "%s|support@%d,%d" % [str(outcome["sig"]), hero.sim_pos.x, hero.sim_pos.y]
		return outcome

	## The tick loop of [method run].
	func _play(flags: PackedInt32Array, goals: Dictionary, skip: int, expect: Vector2i, events: Array) -> Dictionary:
		var still: int = 0
		var t: int = 0
		var next_event: int = 0
		while t < flags.size() + SETTLE_TICKS:
			while next_event < events.size() and int(events[next_event][0]) <= t:
				_apply_event(events[next_event])
				next_event += 1
			Sim.step(1)
			t += 1
			simulated += 1
			if hero.dead or hero.is_down():
				return {}
			if t < skip:
				replayed += 1
				continue
			if t == skip and expect != NOWHERE and hero.sim_pos != expect:
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
						return {"pos": hero.sim_pos, "ticks": t - skip, "played": played, "sig": ""}
				else:
					still = 0
		return {}

	## A CONTINUOUS-PLAY PROBE (orchestrator's SEARCH decision, wf10): one run from a reset world whose inputs `policy`
	## decides tick by tick from what it reads in the world (a charging heavy, a keeper's back, a plate, the egg) for at
	## most PROBE_TICKS ticks, then the hero lets go and comes to rest. No world reset between its phases, momentum
	## carried - what the macros (each from rest, in a world reset to the level file) cannot express. The inputs it
	## played are deterministic, so its end is a node like a macro's: the BFS replays them as the node's prefix.
	## {"goal": true, "ticks", "played"} when the feet point entered a cell of `goals`; at rest {"pos", "ticks",
	## "played", "sig"}; {"dead": true} when he died or went down; {} when he did not come to rest. "kills" counts the
	## role enemies of the world that died in it (the probe's diagnostic).
	func probe_run(config: Dictionary, policy: ProbePolicy, goals: Dictionary) -> Dictionary:
		_begin(config)
		_flags = PackedInt32Array()
		var clock: int = Time.get_ticks_usec()
		var alive_before: int = _role_enemies_alive()
		policy.begin(self)
		var still: int = 0
		var done: bool = false
		var t: int = 0
		var outcome: Dictionary = {}
		while t < PROBE_TICKS + SETTLE_TICKS:
			var flag: int = 0
			if not done and t < PROBE_TICKS:
				flag = policy.next(self, t)
				if flag < 0:
					done = true
					flag = 0
			else:
				done = true
			_flags.append(flag)
			Sim.step(1)
			t += 1
			simulated += 1
			if hero.dead or hero.is_down():
				outcome = {"dead": true, "ticks": t}
				break
			var cell: Vector2i = Vector2i(Tuning.to_cell(hero.sim_pos.x), Tuning.to_cell(hero.sim_pos.y - 1))
			if goals.has(cell):
				outcome = {"goal": true, "ticks": t, "cell": cell, "played": _flags.duplicate()}
				break
			if done:
				if hero.is_grounded() and hero.yvel == 0 and hero.xvel == 0:
					still += 1
					if still >= 2:
						outcome = {"pos": hero.sim_pos, "ticks": t, "played": _flags.duplicate(), "sig": ""}
						break
				else:
					still = 0
		CoopSearch.profile_add(&"probe", clock)
		outcome["kills"] = maxi(alive_before - _role_enemies_alive(), 0)
		if outcome.has("pos"):
			outcome = _at_rest(outcome)
			if not outcome.is_empty():
				outcome["kills"] = maxi(alive_before - _role_enemies_alive(), 0)
		return outcome

	## The role enemies of the world that are dead now ("<id> at c,r" each; for the probe report).
	func dead_role_enemies() -> String:
		var parts: PackedStringArray = PackedStringArray()
		for i: int in _entities.size():
			var entity: SimEntity = entity_at(i)
			if entity is EnemyBase and CoopSearch.has_coop_role(entity as EnemyBase) and (entity as EnemyBase).dead:
				parts.append("%s at %d,%d (%s)" % [_records[i]["id"], int(_records[i]["col"]), int(_records[i]["row"]),
					String((entity as EnemyBase).death_cause) if &"death_cause" in entity else "?"])
		return ", ".join(parts)

	## Role enemies (keeper, trait, bond) of the world alive now.
	func _role_enemies_alive() -> int:
		var count: int = 0
		for entity: SimEntity in _entities:
			if entity is EnemyBase and is_instance_valid(entity) and CoopSearch.has_coop_role(entity as EnemyBase) \
					and not (entity as EnemyBase).dead:
				count += 1
		return count

	func _apply_event(event: Array) -> void:
		match str(event[1]):
			"hand":
				_set_hand(int(event[2]))
			"place":
				_place_idle(hero.sim_pos, hero.facing)

	## The weapon in his hand (-1: the club); a special in the hand puts the club on the belt (the reference hero).
	func _set_hand(hand: int) -> void:
		hero.run.set_weapon(hand if hand >= 0 else Defs.Weapon.CLUB)
		hero.run.set_belt(Defs.Weapon.CLUB if hand > Defs.Weapon.CLUB else PlayerRun.BELT_EMPTY)

	## The lone player is never IDLE (G33): he pressed something long before the gate.
	func _mark_active(who: PlayerBase) -> void:
		who.gave_input = true
		who.input_idle_ticks = 0
		who.idle = false

	## The partner at the start of a run: an egg at its drift point behind the hero, or an idle hatched hero
	## PARTNER_FRONT_PX in front of him (on the same feet line; he falls when there is no floor).
	func _place_partner(mode: int, start: Vector2i, facing: int) -> void:
		if mode == PARTNER_IDLE:
			_place_idle(start + Vector2i(PARTNER_FRONT_PX * facing, 0), facing)
			return
		partner.run.reset_energy()
		partner.respawn_at(start)
		partner.go_down(&"search")
		partner.teleport(start + Vector2i(PartyTuning.EGG_OFFSET_X * facing, PartyTuning.EGG_OFFSET_Y))
		_mark_idle(partner)
		driver.set(&"active_mask", 0)

	## The partner hatched and IDLE at `at` (G33: his player is away - he never pressed anything, so he counts for no
	## co-op rule; PlayerBase.is_idle holds from his first tick anyway, set here explicitly).
	func _place_idle(at: Vector2i, facing: int) -> void:
		partner.run.reset_energy()
		partner.respawn_at(at)
		partner.facing = -facing
		_mark_idle(partner)
		driver.set(&"active_mask", 0)

	func _mark_idle(who: PlayerBase) -> void:
		who.gave_input = false
		who.input_idle_ticks = PlayerBase.IDLE_TICKS
		who.idle = true

	## True when an idle partner may carry a ride here (the `partner` ride macros - a regression check since G33: an
	## idle head is no carrier): a floor PARTNER_LEDGE_ROWS over the hero's feet within PARTNER_LEDGE_COLS columns
	## (higher than his own jump with its corner catch, low enough for a ride off a still carrier).
	func partner_useful(pos: Vector2i) -> bool:
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

	## True when parking the idle partner at `pos` is worth a node of its own: a keeper / trait / bond enemy within
	## THROW_REACH_CELLS (enemies still pick an idle hero as their target - G33's "plain enemy targeting may pick him" -
	## so he can lure one), or a co-op mechanism (plate, see-saw, pulley lift, heave boulder, drum) there while
	## [method CoopSearch.idle_partner_weighs] finds the engine counting an idle hero on a plate. Since G33 the
	## mechanisms do not count him (objects-A), so those placements would only copy the graph (w7_l2_coop 'seagate':
	## 652 of 682 nodes were parked copies); the probe is their regression check - should a plate ever weigh an idle
	## hero again, the search parks him at the mechanisms at once.
	func placement_useful(pos: Vector2i) -> bool:
		if _near_any(_partner_targets, pos):
			return true
		return CoopSearch.idle_partner_weighs() and _near_any(_mechanism_targets, pos)

	func _near_any(targets: Array[Vector2i], pos: Vector2i) -> bool:
		for target: Vector2i in targets:
			if absi(target.x - pos.x) <= THROW_REACH_CELLS.x * Tuning.TILE \
					and absi(target.y - pos.y) <= THROW_REACH_CELLS.y * Tuning.TILE:
				return true
		return false

	## True when something a strike (`reach` = STRIKE_REACH_CELLS) or a throw can act on lies near `pos` - with
	## `facing` (+1 / -1) only on that side of him (or at most BEHIND_REACH_PX behind his feet point: a walker may come
	## round him during the move); every strike and throw macro acts in the direction he faces.
	func target_near(pos: Vector2i, reach: Vector2i, facing: int = 0) -> bool:
		for target: Vector2i in _targets:
			var dx: int = target.x - pos.x
			if absi(dx) <= reach.x * Tuning.TILE and absi(target.y - pos.y) <= reach.y * Tuning.TILE \
					and (facing == 0 or dx * facing >= -CoopSearch.BEHIND_REACH_PX):
				return true
		return false

	## The spots beside `enemy` where an idle partner baits it, when it is a keeper or a `shell` enemy (G33's "the
	## nearer hero" rules - the shell's facing, the keeper's bait): one in front of it and one behind it, his feet
	## CoopSearch.BAIT_GAP_PX clear of its box (within club reach of it), on a floor and not in a wall; none for any
	## other enemy.
	func bait_spots(enemy: EnemyBase) -> Array[Vector2i]:
		var result: Array[Vector2i] = []
		if enemy.keeper == &"" and enemy.coop_trait != Defs.CoopTrait.SHELL:
			return result
		var grid: TileGrid = level.grid
		for side: int in [-1, 1]:
			var spot: Vector2i = enemy.sim_pos + Vector2i(side * (enemy.box_w / 2 + CoopSearch.BAIT_GAP_PX), 0)
			var col: int = Tuning.to_cell(spot.x)
			var body_row: int = Tuning.to_cell(spot.y - 1)
			if grid.in_bounds(col, body_row) and grid.side_at(col, body_row) != TileGrid.SIDE_WALL \
					and TileGrid.is_ground(grid.floor_at(col, Tuning.to_cell(spot.y))):
				result.append(spot)
		return result

	## Breadth-first over resting points from `starts` (feet points) inside `area` (cells) until a cell of `goals` is
	## entered. A node ([method _node]) is a resting point, the world's signature and where the idle partner was left
	## ("partner_at"; G33: he may be placed anywhere his egg reaches - the egg drifts after the lone hero and is clubbed
	## open where he stands - so a `place partner` step parks him at the node, and every later move starts with him
	## there). From every start the partner is also parked at each bait spot inside the area ([method bait_spots]: in
	## front of and behind every keeper and shell enemy, within club reach) before the hero moves.
	## With `probes` (the gate search) the CONTINUOUS-PLAY PROBES run too ([method _run_probes]): from the first
	## PROBE_SITES nodes (with the partner still an egg, the starts first) within reach of each role enemy, plate and the
	## far cell, every policy of its families; a probe that enters the far cell reaches it, and its end at rest joins the
	## queue as a node (a changed world right after the node being expanded, so a dead keeper's open door is searched on
	## at once). The search stops at `max_nodes` expanded nodes or `tick_budget` simulated ticks; "exhausted" says the
	## queue ran dry first: every resting point the macros and probes reach inside the area within `bound` ticks was
	## expanded - the refusal is exhaustive over the search's moves, not bounded.
	## Returns {"reached", "ticks", "detail", "nodes", "runs", "simulated", "replayed", "placements", "queued",
	## "exhausted", "stopped" ("" / "nodes" / "ticks"), "parked", "changed"}.
	func explore(starts: Array[Vector2i], goals: Dictionary, area: Rect2i, bound: int, max_nodes: int,
			tick_budget: int = 1 << 40, probes: bool = false) -> Dictionary:
		var queue: Array[Dictionary] = []
		var seen: Dictionary = {}
		var sites: Dictionary = {}
		var simulated_start: int = simulated
		placements = 0
		probe_stats = {}
		if probes:
			for family: String in PROBE_FAMILIES:
				probe_stats[family] = {"runs": 0, "sites": 0, "kills": 0, "seeds": 0, "dead": 0, "reached": false}
		for start: Vector2i in starts:
			var first: Dictionary = _node(start, 0, "start %d,%d" % [start.x, start.y], _baseline, NOWHERE)
			if not seen.has(_key_of(first)):
				seen[_key_of(first)] = 0
				queue.append(first)
		if world and CoopSearch.idle_partner:
			for start: Vector2i in starts:
				for spot: Vector2i in _bait_spots:
					if not area.has_point(Vector2i(Tuning.to_cell(spot.x), Tuning.to_cell(spot.y - 1))):
						continue
					var baited: Dictionary = _node(start, 0, "start %d,%d > place partner at %d,%d" % [start.x,
						start.y, spot.x, spot.y], _baseline, spot)
					if not seen.has(_key_of(baited)):
						seen[_key_of(baited)] = 0
						queue.append(baited)
						placements += 1
		var head: int = 0
		var stopped: String = ""
		while head < queue.size():
			if head >= max_nodes:
				stopped = "nodes"
				break
			if simulated - simulated_start >= tick_budget:
				stopped = "ticks"
				break
			var node: Dictionary = queue[head]
			head += 1
			var pos: Vector2i = node["pos"]
			var start_cell: Vector2i = Vector2i(Tuning.to_cell(pos.x), Tuning.to_cell(pos.y - 1))
			if goals.has(start_cell):
				return _found(int(node["ticks"]), str(node["path"]), head)
			var prefix: PackedInt32Array = node["prefix"]
			var changed: bool = not prefix.is_empty()
			if probes and not changed and node["partner_at"] == NOWHERE:
				var hit: Dictionary = _run_probes(node, queue, seen, sites, goals, area, bound, head)
				if not hit.is_empty():
					return hit
			if CoopSearch.debug_nodes:
				print("  node %d at %s t%d prefix %d partner %s: %s%s" % [head - 1, str(pos), int(node["ticks"]),
					prefix.size(), str(node["partner_at"]), str(node["path"]).right(90), "" if not changed else " | "
					+ CoopSearch.sig_diff(_baseline, str(node["sig"]))])
			# Park the idle partner here (G33): a node of its own, no move played - so it costs no depth either: it is
			# expanded right after this node (its moves join this node's at the same breadth-first level), not after
			# every node already queued (w2_l1_coop 'hatches': a 3-move route through a parked partner fell behind
			# the node bound on Beginner).
			if CoopSearch.idle_partner and placement_useful(pos) \
					and CoopSearch.node_key(node["partner_at"]) != CoopSearch.node_key(pos):
				var parked: Dictionary = node.duplicate()
				parked["partner_at"] = pos
				parked["path"] = "%s > place partner" % node["path"]
				if changed:
					parked["events"] = (node["events"] as Array) + [[prefix.size(), "place", pos]]
				var parked_key: String = _key_of(parked)
				if not seen.has(parked_key):
					seen[parked_key] = int(node["ticks"])
					queue.insert(head, parked)
					placements += 1
			for macro: Dictionary in macros:
				if not _macro_fits(macro, node):
					continue
				var config: Dictionary
				var events: Array = []
				var macro_hand: int = int(macro.get("hand", -1))
				var ride: bool = int(macro.get("partner", PARTNER_EGG)) == PARTNER_IDLE
				if changed:
					config = node["config"]
					events = (node["events"] as Array).duplicate()
					if macro_hand >= 0 and macro_hand != int(node["hand_now"]):
						events.append([prefix.size(), "hand", macro_hand])
					if ride:
						events.append([prefix.size(), "place", pos])
				else:
					config = _config(pos, int(macro["facing"]), macro_hand, PARTNER_IDLE if ride else PARTNER_EGG,
						NOWHERE if ride else node["partner_at"])
				var simulated_before: int = simulated
				var outcome: Dictionary = run(config, prefix + (macro["flags"] as PackedInt32Array), goals, prefix.size(),
						pos if changed else NOWHERE, events)
				if CoopSearch.collect_stats:
					CoopSearch.stat_run(macro, simulated - simulated_before, changed, outcome.is_empty())
				if outcome.is_empty():
					continue
				var ticks: int = int(node["ticks"]) + int(outcome["ticks"])
				if ticks > bound:
					continue
				var path: String = "%s > %s" % [node["path"], macro["name"]]
				if outcome.has("goal"):
					return _found(ticks, path, head)
				if _offer(queue, seen, area, node, outcome, ticks, path, config, events,
						node["partner_at"] if str(outcome["sig"]) == _baseline else _partner_spot(config, events),
						int(node.get("cap", MAX_PREFIX_TICKS)), -1) and CoopSearch.collect_stats:
					CoopSearch.stat_new(macro)
		return {"reached": false, "ticks": -1, "detail": "", "nodes": head, "runs": runs, "simulated": simulated,
			"replayed": replayed, "placements": placements, "queued": queue.size() - head,
			"exhausted": head >= queue.size(), "stopped": stopped, "parked": _count_parked(queue, head),
			"changed": _count_changed(queue, head)}

	## A child of `node` from a run's `outcome` at rest (`ticks` on the path so far, `path` its text, played with
	## `config` and `events`; `partner_at` where the idle partner stands for its later moves): queued when its key is
	## new and it rests inside `area`. An unchanged world (the level file's) makes a plain node; a changed one replays
	## the run as its prefix - at most `cap` ticks of it (MAX_PREFIX_TICKS; a probe's end and its descendants
	## PROBE_PREFIX_TICKS). `at` >= 0 inserts it there in the queue (a probe's changed world: searched on at once),
	## else it is appended. True when it was queued.
	func _offer(queue: Array[Dictionary], seen: Dictionary, area: Rect2i, node: Dictionary, outcome: Dictionary,
			ticks: int, path: String, config: Dictionary, events: Array, partner_at: Vector2i, cap: int,
			at: int) -> bool:
		var rest: Vector2i = outcome["pos"]
		var sig: String = outcome["sig"]
		var child: Dictionary
		if sig == _baseline:
			# Back in the level-file world: the next moves start from a reset world (the partner stays parked).
			child = _node(rest, ticks, path, sig, partner_at)
		else:
			# The world changed for good: the child replays the run from its last unchanged ancestor.
			var played: PackedInt32Array = outcome["played"]
			if played.size() > cap:
				return false
			child = _node(rest, ticks, path, sig, partner_at)
			child["config"] = config
			child["events"] = events
			child["prefix"] = played
			child["hand_now"] = _hand_after(config, events)
			child["cap"] = cap
		var key: String = _key_of(child)
		if seen.has(key) and int(seen[key]) <= ticks:
			return false
		var fresh: bool = not seen.has(key)
		seen[key] = ticks
		var cell: Vector2i = Vector2i(Tuning.to_cell(rest.x), Tuning.to_cell(rest.y - 1))
		if not fresh or not area.has_point(cell):
			return false
		if at >= 0 and at <= queue.size():
			queue.insert(at, child)
		else:
			queue.append(child)
		return true

	## The continuous-play probes from `node` (an unchanged node, the partner still an egg): for every probe target in
	## reach of it ([method probe_targets] inside `area`, within PROBE_REACH_CELLS) that has had fewer than PROBE_SITES
	## sites, every policy of [method probe_battery]. Each run is counted for its family and target (the coverage
	## [method CoopSearch.gate_verdict] checks: a bounded refusal needs every probe of its gate kind at every target).
	## A probe entering a cell of `goals` is the search's answer (returned, "probe <family> ..." in the path); its end
	## at rest is offered as a child of `node` (a changed world inserted right after the node, at most
	## PROBE_SEEDS_PER_SITE of them per site). {} when none reached.
	func _run_probes(node: Dictionary, queue: Array[Dictionary], seen: Dictionary, sites: Dictionary,
			goals: Dictionary, area: Rect2i, bound: int, head: int) -> Dictionary:
		var pos: Vector2i = node["pos"]
		var far: Vector2i = goals.keys()[0] if goals.size() == 1 else NOWHERE
		for target: String in probe_targets(area, far):
			var at: Vector2i = probe_target_point(target, far)
			if at == NOWHERE or absi(at.x - pos.x) > PROBE_REACH_CELLS.x * Tuning.TILE \
					or absi(at.y - pos.y) > PROBE_REACH_CELLS.y * Tuning.TILE:
				continue
			if int(sites.get(target, 0)) >= PROBE_SITES:
				continue
			sites[target] = int(sites.get(target, 0)) + 1
			var seeds: int = 0
			var counted: Dictionary = {}
			for item: Array in probe_battery(target, pos, far):
				var config: Dictionary = item[0]
				var policy: ProbePolicy = item[1]
				var stats: Dictionary = probe_stats[policy.family]
				if not counted.has(policy.family):
					counted[policy.family] = true
					stats["sites"] = int(stats["sites"]) + 1
				var covered: Dictionary = stats.get("targets", {})
				covered[target] = int(covered.get(target, 0)) + 1
				stats["targets"] = covered
				var outcome: Dictionary = probe_run(config, policy, goals)
				stats["runs"] = int(stats["runs"]) + 1
				stats["kills"] = int(stats["kills"]) + (1 if int(outcome.get("kills", 0)) > 0 else 0)
				if int(outcome.get("kills", 0)) > 0 and not stats.has("kill"):
					stats["kill"] = "%s from %d,%d: %s dead%s" % [policy.label, pos.x, pos.y, dead_role_enemies(),
						"" if not outcome.has("dead") else " (and the hero)"]
				if CoopSearch.debug_nodes:
					print("    probe %s (%s) from %s: %s" % [policy.family, policy.label, str(pos),
						"GOAL" if outcome.has("goal") else ("dead" if outcome.has("dead") else ("rest %s%s" % [
						str(outcome.get("pos", "-")), " changed" if str(outcome.get("sig", _baseline)) != _baseline
						else "" ]) if outcome.has("pos") else "no rest")])
				if outcome.has("dead"):
					stats["dead"] = int(stats["dead"]) + 1
				if outcome.has("goal"):
					stats["reached"] = true
					var reach_ticks: int = int(node["ticks"]) + int(outcome["ticks"])
					return _found(reach_ticks, "%s > probe %s (%s): far cell in %d ticks of continuous play" % [
						node["path"], policy.family, policy.label, int(outcome["ticks"])], head)
				if not outcome.has("pos"):
					continue
				var ticks: int = int(node["ticks"]) + int(outcome["ticks"])
				if ticks > bound:
					continue
				var changed_world: bool = str(outcome["sig"]) != _baseline
				if changed_world and seeds >= PROBE_SEEDS_PER_SITE:
					continue
				if not changed_world and _partner_spot(config, []) != NOWHERE:
					continue   # a plain resting point with the partner parked: the bait starts' copies cover those
				var path: String = "%s > probe %s (%s)" % [node["path"], policy.family, policy.label]
				if _offer(queue, seen, area, node, outcome, ticks, path, config, [], _partner_spot(config, []),
						PROBE_PREFIX_TICKS, head if changed_world else -1):
					stats["seeds"] = int(stats["seeds"]) + 1
					seeds += 1 if changed_world else 0
		return {}

	## The probe targets of the world inside `area` (by the cell of their feet point): "e<index>" every role enemy,
	## "p<index>" every plate, "o<index>" every door column, "d<index>" every drum, "m<index>" every other co-op
	## mechanism (see-saw, heave boulder, pulley, named platform), "f" the far cell (leaps).
	func probe_targets(area: Rect2i, far: Vector2i) -> PackedStringArray:
		var result: PackedStringArray = PackedStringArray()
		for group: Array in [["e", _probe_enemies], ["p", _probe_plates], ["o", _probe_doors], ["d", _probe_drums],
				["m", _probe_mechs]]:
			for index: int in group[1]:
				var entity: SimEntity = entity_at(index)
				if entity != null and area.has_point(Vector2i(Tuning.to_cell(entity.sim_pos.x),
						Tuning.to_cell(entity.sim_pos.y - 1))):
					result.append("%s%d" % [group[0], index])
		if far != NOWHERE:
			result.append("f")
		return result

	## The feet point of probe target `target` ([method probe_targets]; a plate's centre; the far cell's bottom
	## centre for "f"); NOWHERE when it is gone.
	func probe_target_point(target: String, far: Vector2i) -> Vector2i:
		if target == "f":
			return Vector2i(far.x * Tuning.TILE + Tuning.TILE / 2, (far.y + 1) * Tuning.TILE)
		var entity: SimEntity = entity_at(target.substr(1).to_int())
		if entity is Plate:
			var plate: Plate = entity
			return Vector2i((plate.left_px() + plate.right_px()) / 2, plate.floor_y())
		return entity.sim_pos if entity != null else NOWHERE

	## The gate kinds of the G59 table (LEVEL_DESIGN 15.7.6) that the targets in `area` make, and per probe family the
	## targets a bounded refusal needs it to have run at: {"kinds": PackedStringArray, "required": {family:
	## PackedStringArray of targets}}. A role enemy makes a keeper door (hop-over, idle-bait, thrown-special at it) or,
	## a `heavy`, a Brace corridor (hop-over, charge-under, idle-bait); a plate, see-saw, heave boulder or pulley a
	## plate-door kind (idle-bait and thrown-special at it, plates races from every plate, thrown-special through every
	## door); a drum twin drums (thrown-special); nothing of these a ledge or gap (hop-over and idle-bait leaps at the far
	## cell).
	func probe_requirements(area: Rect2i, far: Vector2i) -> Dictionary:
		var kinds: PackedStringArray = PackedStringArray()
		var required: Dictionary = {}
		for family: String in PROBE_FAMILIES:
			required[family] = []
		var targets: PackedStringArray = probe_targets(area, far)
		var mechanism: bool = false
		for target: String in targets:
			var kind: String = target.substr(0, 1)
			var entity: SimEntity = entity_at(target.substr(1).to_int()) if target != "f" else null
			match kind:
				"e":
					var heavy: bool = entity is EnemyBase and (entity as EnemyBase).coop_trait == Defs.CoopTrait.HEAVY
					var name: String = "brace corridor" if heavy else "keeper door"
					if not kinds.has(name):
						kinds.append(name)
					(required[PROBE_HOP_OVER] as Array).append(target)
					(required[PROBE_IDLE_BAIT] as Array).append(target)
					if heavy:
						(required[PROBE_CHARGE_UNDER] as Array).append(target)
					else:
						(required[PROBE_THROWN] as Array).append(target)
				"p", "m":
					mechanism = true
					(required[PROBE_IDLE_BAIT] as Array).append(target)
					(required[PROBE_THROWN] as Array).append(target)
					if kind == "p":
						(required[PROBE_PLATES] as Array).append(target)
				"o":
					(required[PROBE_THROWN] as Array).append(target)
				"d":
					if not kinds.has("twin drums"):
						kinds.append("twin drums")
					(required[PROBE_THROWN] as Array).append(target)
		if mechanism:
			kinds.append("plate door / pulley / see-saw / boulder")
		if kinds.is_empty():
			kinds.append("ledge or gap")
			(required[PROBE_HOP_OVER] as Array).append("f")
			(required[PROBE_IDLE_BAIT] as Array).append("f")
		return {"kinds": kinds, "required": required}

	## The door columns (feet points) a plate at entity `index` drives (rise_while= / sink_while= name it).
	func plate_doors(index: int) -> Array[Vector2i]:
		var result: Array[Vector2i] = []
		var name: String = str((_records[index]["params"] as Dictionary).get("name", ""))
		if name == "":
			return result
		for door: int in _probe_doors:
			var params: Dictionary = _records[door]["params"]
			var names: PackedStringArray = LevelText.to_list(str(params.get("rise_while", ""))) \
					+ LevelText.to_list(str(params.get("sink_while", "")))
			var entity: SimEntity = entity_at(door)
			if names.has(name) and entity != null:
				result.append(entity.sim_pos)
		return result

	## Every probe of target `target` from the resting point `pos` (the far cell `far`): [config, policy] pairs, by
	## the G59 table (LEVEL_DESIGN 15.7.6):
	##  - a role enemy: HOP-OVER duels (CHARGE-UNDER - straight up - for a `heavy`) over PROBE_TRIGGERS_PX x
	##    PROBE_HOLDS x on-over / straight-up x forward / low (pogo) strikes; IDLE-BAIT duels with the idle partner
	##    parked at each of [method lure_spots] (in front of and behind it, near and far: the bait, the second
	##    croucher), standing PROBE_LURE_WAITS first; THROWN-SPECIAL: every special from PROBE_THROW_PX, standing and
	##    jumping, then the duel; EGG PLACEMENT: the egg hatched for real in front of and behind it, then the duel;
	##  - a plate: PLATES races to each door it drives (PROBE_RACE_WAITS on the plate, then straight / a jump / a
	##    crawl at the door) - with the idle partner on the plate or in the door's way (IDLE-BAIT, the doorstop);
	##    THROWN-SPECIAL throws at it; EGG PLACEMENT over it;
	##  - a door: THROWN-SPECIAL throws through its gap, then GO;
	##  - a drum: THROWN-SPECIAL throws at it, then the other drums of its bond struck with the club;
	##  - another mechanism: THROWN-SPECIAL throws at it; IDLE-BAIT leaps with the idle partner on it / beside it;
	##  - the far cell: HOP-OVER leaps (PROBE_LEAP_RUNUPS run-ups, a jump PROBE_LEAP_PX before its column) and IDLE-BAIT
	##    leaps with the idle partner at the take-off spot (under the ledge, at the gap's lip).
	func probe_battery(target: String, pos: Vector2i, far: Vector2i) -> Array:
		var items: Array = []
		var far_x: int = far.x * Tuning.TILE + Tuning.TILE / 2
		var at: Vector2i = probe_target_point(target, far)
		var dir: int = signi(at.x - pos.x)
		if dir == 0:
			dir = 1
		var bait: bool = CoopSearch.idle_partner
		if target == "f":
			for back_up: int in PROBE_LEAP_RUNUPS:
				for trigger: int in PROBE_LEAP_PX:
					for hold: int in PROBE_HOLDS:
						items.append([_config(pos, dir, -1, PARTNER_EGG, NOWHERE),
							_leap(PROBE_HOP_OVER, far_x, trigger, hold, back_up)])
			if bait:
				for trigger: int in PROBE_LEAP_PX:
					var spot: Vector2i = _floor_spot(Vector2i(far_x - dir * trigger, pos.y))
					if spot == NOWHERE:
						continue
					for hold: int in PROBE_HOLDS:
						var leap: LeapPolicy = _leap(PROBE_IDLE_BAIT, far_x, trigger, hold, 0)
						leap.label += " partner at %d,%d" % [spot.x, spot.y]
						items.append([_config(pos, dir, -1, PARTNER_EGG, spot), leap])
			return items
		var index: int = target.substr(1).to_int()
		var kind: String = target.substr(0, 1)
		var enemy: EnemyBase = entity_at(index) as EnemyBase if kind == "e" else null
		# THROWN-SPECIAL at every target (a keeper then dueled, a drum's bond mates then clubbed).
		for weapon: int in THROW_WEAPONS:
			for distance: int in PROBE_THROW_PX:
				for jump: bool in [false, true]:
					var throw: ThrowPolicy = ThrowPolicy.new()
					throw.family = PROBE_THROWN
					throw.far_x = far_x
					throw.spot_x = at.x
					throw.distance = distance
					throw.jump = jump
					if enemy != null:
						throw.duel = _duel(PROBE_THROWN, index, far_x, PROBE_TRIGGERS_PX[1], 9, 1, false, 0)
					elif kind == "d":
						throw.strike_x = _bond_mate_x(index)
					throw.label = "%s %sthrow from %d px at %s" % [["club", "hammer", "axe", "swirl", "spear"][weapon],
						"jump-" if jump else "", distance, _target_name(index)]
					items.append([_config(pos, dir, weapon, PARTNER_EGG, NOWHERE), throw])
		match kind:
			"e":
				if enemy == null:
					return items
				var heavy: bool = enemy.coop_trait == Defs.CoopTrait.HEAVY
				for trigger: int in PROBE_TRIGGERS_PX:
					for hold: int in PROBE_HOLDS:
						for steer: int in [1, 0]:
							for low: bool in [false, true]:
								items.append([_config(pos, dir, -1, PARTNER_EGG, NOWHERE), _duel(PROBE_CHARGE_UNDER
									if heavy and steer == 0 else PROBE_HOP_OVER, index, far_x, trigger, hold, steer, low,
									0)])
				if not bait:
					return items
				for spot: Vector2i in lure_spots(enemy):
					for wait: int in PROBE_LURE_WAITS:
						for trigger: int in [PROBE_TRIGGERS_PX[0], PROBE_TRIGGERS_PX[PROBE_TRIGGERS_PX.size() - 1]]:
							for steer: int in [1, 0]:
								var duel: DuelPolicy = _duel(PROBE_IDLE_BAIT, index, far_x, trigger, 9, steer, false,
									wait)
								duel.label += " partner at %d,%d" % [spot.x, spot.y]
								items.append([_config(pos, dir, -1, PARTNER_EGG, spot), duel])
				for side: int in [-1, 1]:
					var spot_x: int = enemy.sim_pos.x + side * (enemy.box_w / 2 + BAIT_GAP_PX)
					for jump_strike: bool in [false, true]:
						items.append([_config(pos, dir, -1, PARTNER_EGG, NOWHERE), _egg_policy(spot_x, far_x,
							jump_strike, index)])
			"p":
				var doors: Array[Vector2i] = plate_doors(index)
				if doors.is_empty():
					doors.append(Vector2i(far_x, at.y))
				for door: Vector2i in doors:
					for wait: int in PROBE_RACE_WAITS:
						for mode: int in [RacePolicy.Mode.RUN, RacePolicy.Mode.JUMP, RacePolicy.Mode.CRAWL]:
							for trigger: int in ([0] if mode == RacePolicy.Mode.RUN else PROBE_RACE_PX):
								items.append([_config(pos, dir, -1, PARTNER_EGG, NOWHERE),
									_race(PROBE_PLATES, at.x, door.x, far_x, wait, mode, trigger)])
					if bait:
						# The idle partner on the plate, and in the door's way on both sides (the doorstop, G53).
						var spots: Array[Vector2i] = [at]
						for side: int in [-1, 1]:
							var by_door: Vector2i = _floor_spot(door + Vector2i(side * Tuning.TILE, 0))
							if by_door != NOWHERE:
								spots.append(by_door)
						spots.append(door)
						for spot: Vector2i in spots:
							for wait: int in [PROBE_RACE_WAITS[0], PROBE_RACE_WAITS[PROBE_RACE_WAITS.size() - 1]]:
								var race: RacePolicy = _race(PROBE_IDLE_BAIT, at.x, door.x, far_x, wait,
									RacePolicy.Mode.RUN, 0)
								race.label += " partner at %d,%d" % [spot.x, spot.y]
								items.append([_config(pos, dir, -1, PARTNER_EGG, spot), race])
				if bait:
					for jump_strike: bool in [false, true]:
						items.append([_config(pos, dir, -1, PARTNER_EGG, NOWHERE), _egg_policy(at.x, far_x,
							jump_strike, -1)])
			"m":
				if bait:
					for offset: int in [0, -Tuning.TILE, Tuning.TILE]:
						var spot: Vector2i = at + Vector2i(offset, 0)
						for trigger: int in PROBE_LEAP_PX:
							var leap: LeapPolicy = _leap(PROBE_IDLE_BAIT, far_x, trigger, 9, 0)
							leap.label += " partner at %d,%d (%s)" % [spot.x, spot.y, _target_name(index)]
							items.append([_config(pos, dir, -1, PARTNER_EGG, spot), leap])
		return items

	## A feet point on the floor at or just under `spot` (its cell or the 3 rows below), not inside a wall; NOWHERE
	## when there is none.
	func _floor_spot(spot: Vector2i) -> Vector2i:
		var grid: TileGrid = level.grid
		var col: int = Tuning.to_cell(spot.x)
		var row: int = Tuning.to_cell(spot.y - 1)
		for down: int in 4:
			var r: int = row + down
			if not grid.in_bounds(col, r + 1) or grid.side_at(col, r) == TileGrid.SIDE_WALL:
				return NOWHERE
			if TileGrid.is_ground(grid.floor_at(col, r + 1)):
				return Vector2i(spot.x, (r + 1) * Tuning.TILE)
		return NOWHERE

	## The x of the nearest other drum of the drum at entity `index`'s bond (-1 when it has none).
	func _bond_mate_x(index: int) -> int:
		var bond: String = str((_records[index]["params"] as Dictionary).get("bond", ""))
		var me: SimEntity = entity_at(index)
		var best: int = -1
		for other: int in _probe_drums:
			var entity: SimEntity = entity_at(other)
			if other == index or entity == null or me == null:
				continue
			if str((_records[other]["params"] as Dictionary).get("bond", "")) != bond:
				continue
			if best < 0 or absi(entity.sim_pos.x - me.sim_pos.x) < absi(best - me.sim_pos.x):
				best = entity.sim_pos.x
		return best

	func _target_name(index: int) -> String:
		if index < 0 or index >= _records.size():
			return "?"
		return "%s %d,%d" % [String(_records[index]["id"]).get_file(), int(_records[index]["col"]),
			int(_records[index]["row"])]

	func _leap(family: String, far_x: int, trigger: int, hold: int, back_up: int) -> LeapPolicy:
		var leap: LeapPolicy = LeapPolicy.new()
		leap.family = family
		leap.far_x = far_x
		leap.trigger_px = trigger
		leap.hold = hold
		leap.back_up = back_up
		leap.label = "leap run-up %d, jump %d px before the far column, hold %d" % [back_up, trigger, hold]
		return leap

	func _race(family: String, plate_x: int, door_x: int, far_x: int, wait: int, mode: int,
			trigger: int) -> RacePolicy:
		var race: RacePolicy = RacePolicy.new()
		race.family = family
		race.far_x = far_x
		race.plate_x = plate_x
		race.door_x = door_x
		race.wait = wait
		race.mode = mode
		race.trigger_px = trigger
		race.label = "race plate %d -> door %d, %d ticks on it, %s" % [plate_x, door_x, wait,
			["straight", "jump %d px before the door" % trigger, "crawl %d px before the door" % trigger][mode]]
		return race

	func _duel(family: String, index: int, far_x: int, trigger: int, hold: int, steer: int, low: bool,
			wait: int) -> DuelPolicy:
		var duel: DuelPolicy = DuelPolicy.new()
		duel.family = family
		duel.target_index = index
		duel.far_x = far_x
		duel.trigger_px = trigger
		duel.hold = hold
		duel.steer = steer
		duel.low = low
		duel.wait = wait
		duel.label = "%s at %d px hold %d%s%s%s" % ["jump on over it" if steer == 1 else "jump straight up", trigger,
			hold, ", low / pogo strikes" if low else "", ", wait %d" % wait if wait > 0 else "",
			" vs %s" % String(_records[index]["id"]) if index >= 0 and index < _records.size() else ""]
		return duel

	## An EGG-PLACEMENT probe: the egg hatched over `spot_x`, then a duel with the role enemy `index` (-1: GO).
	func _egg_policy(spot_x: int, far_x: int, jump_strike: bool, index: int) -> EggPolicy:
		var egg: EggPolicy = EggPolicy.new()
		egg.family = PROBE_EGG
		egg.far_x = far_x
		egg.spot_x = spot_x
		egg.jump_strike = jump_strike
		if index >= 0:
			egg.duel = _duel(PROBE_EGG, index, far_x, 24, 9, 1, false, 30)
		egg.label = "egg hatched over x %d by a %s%s" % [spot_x, "jump-strike" if jump_strike else "strike",
			", then a duel" if index >= 0 else ""]
		return egg

	## Where the idle partner is parked for an IDLE-BAIT probe of `enemy`: on its floor in front of it and behind it,
	## BAIT_GAP_PX clear of its box and PROBE_LURE_EXTRA_PX farther (a lure the enemy turns to or runs at), on a floor
	## and not in a wall.
	func lure_spots(enemy: EnemyBase) -> Array[Vector2i]:
		var result: Array[Vector2i] = []
		var grid: TileGrid = level.grid
		for side: int in [-1, 1]:
			for extra: int in PROBE_LURE_EXTRA_PX:
				var spot: Vector2i = enemy.sim_pos + Vector2i(side * (enemy.box_w / 2 + BAIT_GAP_PX + extra), 0)
				var col: int = Tuning.to_cell(spot.x)
				var body_row: int = Tuning.to_cell(spot.y - 1)
				if grid.in_bounds(col, body_row) and grid.side_at(col, body_row) != TileGrid.SIDE_WALL \
						and TileGrid.is_ground(grid.floor_at(col, Tuning.to_cell(spot.y))):
					result.append(spot)
		return result

	func _found(ticks: int, path: String, nodes: int) -> Dictionary:
		return {"reached": true, "ticks": ticks, "detail": path, "nodes": nodes, "runs": runs, "simulated": simulated,
			"replayed": replayed, "placements": placements, "queued": 0, "exhausted": false, "stopped": "found",
			"parked": 0, "changed": 0}

	## Nodes among the first `head` of `queue` that start with the idle partner parked.
	func _count_parked(queue: Array[Dictionary], head: int) -> int:
		var count: int = 0
		for i: int in mini(head, queue.size()):
			count += 1 if queue[i]["partner_at"] != NOWHERE else 0
		return count

	## Nodes among the first `head` of `queue` whose world differs from the level file's (a replayed prefix).
	func _count_changed(queue: Array[Dictionary], head: int) -> int:
		var count: int = 0
		for i: int in mini(head, queue.size()):
			count += 0 if (queue[i]["prefix"] as PackedInt32Array).is_empty() else 1
		return count

	## A node of [method explore]: an unchanged one (no prefix) unless "config" / "events" / "prefix" are filled in.
	func _node(pos: Vector2i, ticks: int, path: String, sig: String, partner_at: Vector2i) -> Dictionary:
		return {"pos": pos, "ticks": ticks, "path": path, "sig": sig, "partner_at": partner_at, "config": {},
			"events": [], "prefix": PackedInt32Array(), "hand_now": -1}

	func _key_of(node: Dictionary) -> String:
		var key: String = CoopSearch.state_key(node["pos"], str(node["sig"]))
		var at: Vector2i = node["partner_at"]
		return key if at == NOWHERE else "%s|p%s" % [key, str(CoopSearch.node_key(at))]

	## A run configuration for [method run].
	func _config(start: Vector2i, facing: int, hand: int, partner_mode: int, partner_at: Vector2i) -> Dictionary:
		return {"start": start, "facing": facing, "hand": hand, "partner": partner_mode, "partner_at": partner_at}

	## Where the idle partner was put last in a run of `config` with `events` (NOWHERE: he is an egg).
	func _partner_spot(config: Dictionary, events: Array) -> Vector2i:
		for i: int in range(events.size() - 1, -1, -1):
			if str(events[i][1]) == "place":
				return events[i][2]
		if config["partner_at"] != NOWHERE:
			return config["partner_at"]
		return config["start"] if int(config["partner"]) == PARTNER_IDLE else NOWHERE

	## The hand after `config` and its `events`.
	func _hand_after(config: Dictionary, events: Array) -> int:
		var hand: int = int(config["hand"])
		for event: Array in events:
			if str(event[1]) == "hand":
				hand = int(event[2])
		return hand

	## Whether `macro` is worth a run from `node`: strikes where something to hit is near on the side he strikes,
	## throws where something to throw at is in range on the side he throws, the partner ride moves (a regression check
	## since G33) only from an unchanged node under a ledge while the engine allows a ride on an idle head.
	func _macro_fits(macro: Dictionary, node: Dictionary) -> bool:
		match str(macro.get("kind", "move")):
			"strike":
				return target_near(node["pos"], STRIKE_REACH_CELLS, int(macro["facing"]))
			"throw":
				return target_near(node["pos"], THROW_REACH_CELLS, int(macro["facing"]))
			"partner":
				# Only while the engine still lets a hero ride an idle head (CoopSearch.idle_partner_carries; not yet
				# probed in this process: tried) - since G33 it does not, so they would reach nothing.
				return CoopSearch.idle_partner and CoopSearch._ride_probe != 0 \
						and (node["prefix"] as PackedInt32Array).is_empty() and partner_useful(node["pos"])
		return true


## Solo-impossibility search of gate `gate` of the co-op level `level_id` in `difficulty` (the contract of
## tests/test_coop_gates.gd): {"reached": bool (true = one hero got to the far cell, or a static rule is broken, or
## the gate cannot be searched), "bound": BOUND_TICKS, "windows": [{"what", "window", "solo_min"[, "slot_bound": true]}]
## ("slot_bound": a rule one player can never meet - the daze once the engine binds it to the other slot, G47 - exempt
## from the solo_min - 4 cap), "detail": String,
## "starts": Array of start cells, "explored": resting points searched, "runs": macro runs, "flood": bool (the
## diagnostic of [method flood_reaches])}.
## With [member use_file_cache] (and [member use_cache]) a result is kept in FILE_CACHE_DIR under a key of everything
## it depends on ([method file_cache_key]: the level file and its solo base, the gate and difficulty, and the
## fingerprint of every script, scene and resource of the simulation), so a rerun with nothing changed reads it back
## instead of searching again ("cached": true in the result).
static func search_gate(level_id: StringName, difficulty: int, gate: String) -> Dictionary:
	var path: String = level_path(level_id)
	var data: LevelData = LevelData.load_file(path)
	if data == null:
		return _unproven(_fresh_result(), "cannot read the level %s" % level_id)
	var key: String = ""
	if use_cache and use_file_cache:
		key = file_cache_key(path, data, difficulty, gate)
		var cached: Dictionary = _file_cache_read(key)
		if not cached.is_empty():
			return cached
	var started: int = Time.get_ticks_msec()
	var result: Dictionary = search_data(data, difficulty, gate)
	var seconds: float = (Time.get_ticks_msec() - started) / 1000.0
	if not str(result.get("detail", "")).begins_with("unproven"):
		record_cost(level_id, difficulty, gate, seconds, int(result.get("simulated", 0)))
	if key != "" and not str(result.get("detail", "")).begins_with("unproven"):
		result["seconds"] = seconds
		_file_cache_write(key, result)
	return result


## G59 (orchestrator, LEVEL_DESIGN 15.7.6): a bounded refusal counts only with at least this many resting points
## expanded (the raised bound of the G3 verifier).
const BOUNDED_MIN_NODES: int = 660


## The G59 verdict of a [method search_gate] result: {"verdict": "open" | "refused (exhaustive)" |
## "refused (bounded)" | "unproven", "evidence": String, "missing": PackedStringArray ("<family> at <target>" for
## every probe its gate kind needs that did not run)}.
##  - open: the search or a probe reached the far cell, or a static rule is broken (red, the cause named);
##  - refused (exhaustive): the frontier emptied below the bound - every resting point the macros and probes reach
##    inside the gate's area within BOUND_TICKS was expanded;
##  - refused (bounded): stopped at the bound after at least BOUNDED_MIN_NODES resting points AND every probe family
##    its gate kinds need ran at every target that needs it (probe_requirements) and none reached the far cell;
##  - unproven: bounded below BOUNDED_MIN_NODES, or a needed probe did not run (its target never in reach of a probe
##    site), or the gate could not be searched.
## A cached result is the stored result of exactly this search (the cache key holds the level file, its base file,
## the simulation's code, the bounds and the probe switch), so it carries the same evidence as an uncached run.
static func gate_verdict(result: Dictionary) -> Dictionary:
	var detail: String = str(result.get("detail", ""))
	var missing: PackedStringArray = PackedStringArray()
	if detail.begins_with("unproven"):
		return {"verdict": "unproven", "evidence": detail, "missing": missing}
	if bool(result.get("reached", true)):
		return {"verdict": "open", "evidence": detail, "missing": missing}
	var explored: int = int(result.get("explored", 0))
	if bool(result.get("exhausted", false)):
		return {"verdict": "refused (exhaustive)", "evidence": "the frontier emptied after %d resting points" % explored,
			"missing": missing}
	var probes_found: Dictionary = result.get("probes", {})
	var required: Dictionary = result.get("probes_required", {})
	var counts: PackedStringArray = PackedStringArray()
	for family: String in PROBE_FAMILIES:
		var stats: Dictionary = probes_found.get(family, {})
		var covered: Dictionary = stats.get("targets", {})
		var needed: Array = required.get(family, [])
		for target: Variant in needed:
			if int(covered.get(str(target), 0)) == 0:
				missing.append("%s at %s" % [family, str(target)])
		if not needed.is_empty() or int(stats.get("runs", 0)) > 0:
			counts.append("%s 0/%d" % [family, int(stats.get("runs", 0))])
	if not bool(result.get("probes_on", true)):
		missing.append("every probe (the search ran without probes)")
	var bound: String = "bounded at %d resting points (%s bound%s)" % [explored, str(result.get("stopped", "node")),
		", %d queued" % int(result.get("queued", 0))]
	if explored < BOUNDED_MIN_NODES:
		return {"verdict": "unproven", "evidence": "%s, below the %d G59 asks; probes %s" % [bound, BOUNDED_MIN_NODES,
			", ".join(counts)], "missing": missing}
	if not missing.is_empty():
		return {"verdict": "unproven", "evidence": "%s; probes missing: %s" % [bound, ", ".join(missing)],
			"missing": missing}
	return {"verdict": "refused (bounded)", "evidence": "%s; probes %s" % [bound, ", ".join(counts)],
		"missing": missing}


## The one-line G59 verdict of a gate: "GATE <level> <difficulty> <gate>: <verdict> (<evidence>)".
static func verdict_line(level_id: StringName, difficulty: int, gate: String, result: Dictionary) -> String:
	var verdict: Dictionary = gate_verdict(result)
	return "GATE %s %s %s: %s (%s)%s" % [level_id, Defs.difficulty_name(difficulty).to_lower(), gate,
		verdict["verdict"], verdict["evidence"], " [cached]" if bool(result.get("cached", false)) else ""]


## The per-gate report of a [method search_gate] result (orchestrator's SEARCH decision, wf10; G59): the verdict, how
## far the search went (EXHAUSTIVE: the queue ran dry - every resting point the macros and probes reach inside the
## gate's area within BOUND_TICKS was expanded; BOUNDED: stopped at the node or tick bound with nodes still queued),
## the gate kinds, and one line per probe family: the runs, the sites (nodes it ran from), the runs in which a role
## enemy died, the end states handed to the search, the runs in which the hero died - or "no target".
static func report_lines(result: Dictionary) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	var verdict: Dictionary = gate_verdict(result)
	lines.append("verdict: %s - %s" % [verdict["verdict"], verdict["evidence"]])
	var detail: String = str(result.get("detail", ""))
	if detail.begins_with("static rule") or detail.begins_with("unproven"):
		lines.append("search: not run (%s)" % detail)
		return lines
	if bool(result.get("exhausted", false)):
		lines.append("search: EXHAUSTIVE - the queue ran dry after %d resting points (%d runs, %d ticks; %d parked-partner, %d changed-world nodes)" 				% [int(result.get("explored", 0)), int(result.get("runs", 0)), int(result.get("simulated", 0)),
				int(result.get("parked", 0)), int(result.get("changed", 0))])
	elif not bool(result.get("reached", false)):
		lines.append("search: BOUNDED - stopped at the %s bound after %d resting points (%d still queued; limits %d nodes / %d ticks; %d runs, %d ticks)" 				% [str(result.get("stopped", "node")), int(result.get("explored", 0)), int(result.get("queued", 0)),
				int(result.get("node_limit", node_limit)), int(result.get("tick_limit", tick_limit)),
				int(result.get("runs", 0)), int(result.get("simulated", 0))])
	lines.append("gate kinds: %s" % ", ".join(PackedStringArray(result.get("gate_kinds", []))))
	var probes_found: Dictionary = result.get("probes", {})
	var required: Dictionary = result.get("probes_required", {})
	for family: String in PROBE_FAMILIES:
		var stats: Dictionary = probes_found.get(family, {})
		var needed: int = (required.get(family, []) as Array).size()
		if stats.is_empty() or int(stats.get("runs", 0)) == 0:
			lines.append("probe %s: %s" % [family, "no target in the gate's area" if needed == 0
				else "NOT RUN (%d targets need it)" % needed])
			continue
		lines.append("probe %s: %d runs at %d targets from %d sites (%d needed), %d with a role enemy killed, %d ends searched on, %d hero deaths%s" 				% [family, int(stats.get("runs", 0)), (stats.get("targets", {}) as Dictionary).size(),
				int(stats.get("sites", 0)), needed, int(stats.get("kills", 0)), int(stats.get("seeds", 0)),
				int(stats.get("dead", 0)), ", REACHED the far cell" if bool(stats.get("reached", false)) else ""])
		if stats.has("kill"):
			lines.append("    first kill: %s" % str(stats["kill"]))
	return lines


# --- Spreading the gate table over processes (tools/world_coop_gates.sh) ------------------------------------------------

## Where [method record_cost] keeps the last measured cost of every gate (one small file per gate; build/ is not
## versioned).
const COST_DIR: String = "res://build/coop_search_cache/costs"
## The cost a gate without a measurement is given in [method order_by_cost] (seconds: about the dearest gates of
## phase 3, so a new gate is searched among the first and the cheap known ones fill the end).
const UNKNOWN_COST_SECONDS: float = 120.0


static func _gate_label(level_id: StringName, difficulty: int, gate: String) -> String:
	return "%s__%s__%d" % [level_id, gate.validate_filename(), difficulty]


## Keep the cost of the latest real search of a gate ([method search_gate]; a cached read does not count): seconds of
## wall time and ticks simulated (the ticks do not depend on the load of the machine).
static func record_cost(level_id: StringName, difficulty: int, gate: String, seconds: float, ticks: int) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(COST_DIR))
	var file: FileAccess = FileAccess.open(COST_DIR.path_join(_gate_label(level_id, difficulty, gate) + ".txt"),
			FileAccess.WRITE)
	if file != null:
		file.store_string("%.1f %d\n" % [seconds, ticks])
		file.close()


## The last recorded cost of a gate in seconds (-1 when it was never searched here).
static func gate_cost(level_id: StringName, difficulty: int, gate: String) -> float:
	var path: String = COST_DIR.path_join(_gate_label(level_id, difficulty, gate) + ".txt")
	if not FileAccess.file_exists(path):
		return -1.0
	var parts: PackedStringArray = FileAccess.get_file_as_string(path).strip_edges().split(" ")
	return parts[0].to_float() if not parts.is_empty() and parts[0].is_valid_float() else -1.0


## The entries of `table` ([method gate_table]) dearest first (by [method gate_cost]; a gate never searched counts
## UNKNOWN_COST_SECONDS; ties keep the table order): the order in which queue workers take them, so the long searches
## start first and the short ones fill the gaps at the end (the wall time of N workers is then close to the total over
## N).
static func order_by_cost(table: Array) -> Array:
	var keyed: Array = []
	for i: int in table.size():
		var entry: Dictionary = table[i]
		var cost: float = gate_cost(entry["level"], int(entry["difficulty"]), str(entry["gate"]))
		keyed.append([UNKNOWN_COST_SECONDS if cost < 0.0 else cost, i])
	keyed.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0] or (a[0] == b[0] and a[1] < b[1]))
	var result: Array = []
	for pair: Array in keyed:
		result.append(table[int(pair[1])])
	return result


## Claim a gate for this process in the work queue `queue_dir` (an OS or res:// folder shared by the workers of one
## run): true for exactly one caller per gate and queue - the claim is the creation of a folder named after the gate,
## which the file system makes atomic. A worker searches only what it claimed, so N workers share the table without a
## fixed split (tools/world_coop_gates.sh; any program that loops over the table can use it the same way).
static func claim_gate(queue_dir: String, level_id: StringName, difficulty: int, gate: String) -> bool:
	var root: String = ProjectSettings.globalize_path(queue_dir) if queue_dir.begins_with("res://") else queue_dir
	DirAccess.make_dir_recursive_absolute(root)
	return DirAccess.make_dir_absolute(root.path_join(_gate_label(level_id, difficulty, gate))) == OK


## Where [method search_gate] keeps its results (one JSON file per key; build/ is not versioned).
const FILE_CACHE_DIR: String = "res://build/coop_search_cache"
## The search's own version in the cache key (bump it when a result's meaning changes without a code change).
const FILE_CACHE_VERSION: String = "v4.0"
## The folders whose files make the simulation (their contents are the code fingerprint).
const FINGERPRINT_DIRS: Array[String] = ["res://scripts", "res://scenes", "res://resources"]
const FINGERPRINT_EXTENSIONS: Array[String] = ["gd", "tscn", "tres", "json", "cfg"]
## Folders of FINGERPRINT_DIRS that no gate's search world runs - the screens and the HUD, the versus referee, the bots
## and their baked arena graphs, the development tools - left out of the fingerprint so that their frequent edits
## (a bot re-bake, a HUD change) do not throw every cached gate away. The sim code names a few of their classes in
## comments and presentation only (Hud's G35 contract, UiKit on sign boards - not in a search world -, UiPlayers'
## colours of effects); the bosses are the exception (the Chieftains drive themselves with the bots' code and graphs,
## the weak points answer the HUD): a gate whose search world spawns a boss ([method world_has_boss]) keys on the full
## fingerprint - only such a gate (a boss stage's other gates do not: their search worlds hold no boss, and the edits of
## the screens and bots that other owners make all day no longer throw them away).
const FINGERPRINT_SKIP: Array[String] = [
	"res://scripts/ui", "res://scenes/ui", "res://resources/ui", "res://scripts/world/versus", "res://scripts/core/bots",
	"res://resources/bots", "res://scripts/core/dev",
]

static var _fingerprint: String = ""
static var _fingerprint_full: String = ""


## The key of a search result: md5 over the search version, the code fingerprint ([method code_fingerprint]; the full
## one when the gate's search world holds a boss, [method world_has_boss]), the level file's text, its `coop_of` base
## file's text (the static rules read its kind), the difficulty, the gate, and the partner model.
static func file_cache_key(path: String, data: LevelData, difficulty: int, gate: String) -> String:
	var parts: PackedStringArray = PackedStringArray([FILE_CACHE_VERSION,
		code_fingerprint(world_has_boss(data, difficulty, gate)), FileAccess.get_file_as_string(path)])
	var base: String = str(data.value("coop_of"))
	if base != "":
		var base_path: String = level_path(StringName(base))
		parts.append(FileAccess.get_file_as_string(base_path) if FileAccess.file_exists(base_path) else "")
	parts.append("%d|%s|%s|%s" % [difficulty, gate, "idle" if idle_partner else "egg", bounds_text()])
	return "|".join(parts).md5_text()


## The search's compute bounds and probe switch as text (part of both cache keys: a result found under other bounds is
## never read back as this one).
static func bounds_text() -> String:
	return "n%d t%d %s" % [node_limit, tick_limit, "probes" if probes else "no-probes"]


## True when the search world of `gate` in `difficulty` spawns a boss: a `bosses/` record among
## [method world_record_list] of the gate's columns (exactly the records [method search_data] builds the world from) -
## or when the gate cannot be laid out (no tablet, no far cell: the cautious answer). Only then can a result depend on
## the code FINGERPRINT_SKIP leaves out.
static func world_has_boss(data: LevelData, difficulty: int, gate: String) -> bool:
	var tablet: Dictionary = find_tablet(data, difficulty, gate)
	if tablet.is_empty() or tablet["far"] == Vector2i(-1, -1):
		return true
	var grid: TileGrid = grid_at_rest(data, difficulty)
	var columns: Vector2i = world_columns_of(gate_area(tablet, grid), start_points(data, difficulty, tablet, grid), grid)
	for record: Dictionary in world_record_list(data, difficulty, columns):
		if String(record["id"]).begins_with("bosses/"):
			return true
	return false


## The md5 of every script, scene and resource file of the simulation (FINGERPRINT_DIRS without FINGERPRINT_SKIP;
## with `full` every file of FINGERPRINT_DIRS) and project.godot, taken once per run: any change in them makes every
## cached result stale.
static func code_fingerprint(full: bool = false) -> String:
	if full and _fingerprint_full != "":
		return _fingerprint_full
	if not full and _fingerprint != "":
		return _fingerprint
	var files: PackedStringArray = PackedStringArray(["res://project.godot"])
	for dir_path: String in FINGERPRINT_DIRS:
		_collect_files(dir_path, files, full)
	files.sort()
	var parts: PackedStringArray = PackedStringArray()
	for file: String in files:
		parts.append("%s=%s" % [file, FileAccess.get_md5(file)])
	var md5: String = ";".join(parts).md5_text()
	if full:
		_fingerprint_full = md5
	else:
		_fingerprint = md5
	return md5


static func _collect_files(dir_path: String, into: PackedStringArray, full: bool = true) -> void:
	if not full and FINGERPRINT_SKIP.has(dir_path):
		return
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return
	for file_name: String in dir.get_files():
		if FINGERPRINT_EXTENSIONS.has(file_name.get_extension()):
			into.append(dir_path.path_join(file_name))
	for sub: String in dir.get_directories():
		_collect_files(dir_path.path_join(sub), into, full)


static func _file_cache_read(key: String) -> Dictionary:
	var file_path: String = FILE_CACHE_DIR.path_join(key + ".json")
	if not FileAccess.file_exists(file_path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(file_path))
	if not parsed is Dictionary or not (parsed as Dictionary).has("reached"):
		return {}
	var result: Dictionary = parsed
	var starts: Array = []
	for cell: Variant in result.get("starts", []):
		if cell is Array and (cell as Array).size() == 2:
			starts.append(Vector2i(int(cell[0]), int(cell[1])))
	result["starts"] = starts
	for key_name: String in ["explored", "runs", "simulated", "replayed", "bound"]:
		result[key_name] = int(result.get(key_name, 0))
	var windows: Array = []
	for window: Variant in result.get("windows", []):
		if window is Dictionary:
			var record: Dictionary = {"what": str(window.get("what", "")), "window": int(window.get("window", 0)),
				"solo_min": int(window.get("solo_min", 0))}
			if bool(window.get("slot_bound", false)):
				record["slot_bound"] = true
			windows.append(record)
	result["windows"] = windows
	result["cached"] = true
	return result


static func _file_cache_write(key: String, result: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(FILE_CACHE_DIR))
	var copy: Dictionary = result.duplicate(true)
	var starts: Array = []
	for cell: Variant in result.get("starts", []):
		if cell is Vector2i:
			starts.append([(cell as Vector2i).x, (cell as Vector2i).y])
	copy["starts"] = starts
	copy.erase("cached")
	var final_path: String = FILE_CACHE_DIR.path_join(key + ".json")
	var temp_path: String = "%s.%d.tmp" % [final_path, OS.get_process_id()]
	var file: FileAccess = FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(copy))
	file.close()
	DirAccess.rename_absolute(ProjectSettings.globalize_path(temp_path), ProjectSettings.globalize_path(final_path))


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
	var clock: int = Time.get_ticks_usec()
	var broken: String = static_problem(data, gate)
	profile_add(&"static", clock)
	if broken != "":
		result["reached"] = true
		result["detail"] = "static rule: " + broken
		return result
	# 2. The search in the search world.
	var grid: TileGrid = grid_at_rest(data, difficulty)
	var area: Rect2i = gate_area(tablet, grid)
	# The daze measurements and the engine probes build a search level of their own: before this one (they never
	# nest; each is measured once per process).
	clock = Time.get_ticks_usec()
	for record: Dictionary in data.entity_records():
		var id: String = String(record["id"])
		var daze: bool = str(record["params"].get("coop", "")) == "daze" or id == "enemies/raptor"
		if daze and Spawner.category(StringName(id)) == "enemies" and LevelText.applies_to(record["params"], difficulty):
			measure_daze_solo_min(id)
			daze_slot_bound()
	if idle_partner:
		idle_partner_carries()
		idle_partner_weighs()
	profile_add(&"daze", clock)
	var starts: Array[Vector2i] = start_points(data, difficulty, tablet, grid)
	for start: Vector2i in starts:
		(result["starts"] as Array).append(Vector2i(Tuning.to_cell(start.x), Tuning.to_cell(start.y - 1)))
	var columns: Vector2i = search_columns(area, starts, grid)
	result["flood"] = flood_reaches(grid, starts, far, columns)
	var world_columns: Vector2i = world_columns_of(area, starts, grid)
	var key: String = _explore_key(grid, data.resolved_meta(difficulty), starts, far, area) + "|" \
			+ str(world_records(data, difficulty, world_columns).hash()) + ("|idle" if idle_partner else "|egg") \
			+ "|d%d" % difficulty + "|%s" % bounds_text()
	var found: Dictionary = {}
	if use_cache and _explore_cache.has(key):
		found = _explore_cache[key]
	else:
		var searcher: Searcher = Searcher.new()
		clock = Time.get_ticks_usec()
		if not searcher.build_world(data, difficulty, grid_at_rest(data, difficulty), world_columns):
			return _unproven(result, "the hero scene %s does not exist" % PLAYER_ID)
		profile_add(&"build", clock)
		clock = Time.get_ticks_usec()
		found = searcher.explore(starts, {far: true}, area, BOUND_TICKS, node_limit, tick_limit, probes)
		found["probes"] = searcher.probe_stats.duplicate(true)
		var needs: Dictionary = searcher.probe_requirements(area, far)
		found["gate_kinds"] = Array(needs["kinds"] as PackedStringArray)
		var required: Dictionary = {}
		for family: String in needs["required"]:
			required[family] = (needs["required"][family] as Array).duplicate()
		found["probes_required"] = required
		profile_add(&"explore", clock)
		searcher.close()
		_explore_cache[key] = found
	result["reached"] = bool(found["reached"])
	result["explored"] = int(found["nodes"])
	result["runs"] = int(found.get("runs", 0))
	result["simulated"] = int(found.get("simulated", 0))
	result["replayed"] = int(found.get("replayed", 0))
	result["placements"] = int(found.get("placements", 0))
	result["queued"] = int(found.get("queued", 0))
	result["exhausted"] = bool(found.get("exhausted", false))
	result["stopped"] = str(found.get("stopped", ""))
	result["parked"] = int(found.get("parked", 0))
	result["changed"] = int(found.get("changed", 0))
	result["probes"] = found.get("probes", {})
	result["gate_kinds"] = found.get("gate_kinds", [])
	result["probes_required"] = found.get("probes_required", {})
	result["probes_on"] = probes
	result["node_limit"] = node_limit
	result["tick_limit"] = tick_limit
	if result["reached"]:
		result["detail"] = "one hero reached %d,%d in %d ticks: %s" % [far.x, far.y, int(found["ticks"]),
			found["detail"]]
	# 3. Windows near the gate, on the bare grid at rest (nothing in the hero's way: the least he needs).
	var bare: Searcher = Searcher.new()
	clock = Time.get_ticks_usec()
	if bare.build(data.id, data.resolved_meta(difficulty), grid):
		result["windows"] = measure_windows(data, difficulty, area, bare)
		bare.close()
	profile_add(&"windows", clock)
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
	# A pulley and its two lifts (`a=` / `b=` name `objects/platform name=`).
	if id == "objects/pulley":
		for key: String in ["a", "b"]:
			if params.has(key):
				result.append("platform:" + str(params[key]))
	elif id == "objects/platform" and params.has("name"):
		result.append("platform:" + str(params["name"]))
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


## True when parking the idle partner near a record is worth a node of the search (G33: none of these counts him,
## the nodes are the regression check of the IDLE rule): plates, see-saws, pulleys and their lifts, heave boulders,
## drums, and keeper, trait or bond enemies.
static func is_partner_target(record: Dictionary) -> bool:
	if is_mechanism_target(record):
		return true
	var params: Dictionary = record["params"]
	return params.has("keeper") or params.has("coop") or params.has("bond")


## True when `enemy` (spawned in a search world) has a co-op role: a keeper, a trait (also one its archetype gives it
## without a `coop=` parameter, as the Bull Rex's `heavy`) or a bond.
static func has_coop_role(enemy: EnemyBase) -> bool:
	return enemy.keeper != &"" or enemy.coop_trait != Defs.CoopTrait.NONE or enemy.spawn_params.has("bond")


## The co-op mechanisms among [method is_partner_target]: plates, see-saws, pulleys and their lifts, heave boulders,
## drums (parking the idle partner there matters only while the engine counts an idle hero on a plate,
## [method idle_partner_weighs]).
static func is_mechanism_target(record: Dictionary) -> bool:
	var id: String = String(record["id"])
	if id in ["objects/plate", "objects/seesaw", "objects/pulley", "objects/boulder_heavy", "objects/drum"]:
		return true
	return id == "objects/platform" and (record["params"] as Dictionary).has("pulley")


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


## Debugging: print every node the search expands (with what its world changed against the baseline).
static var debug_nodes: bool = false


## The parts of world signature `b` that differ from `a` (for [member debug_nodes]).
static func sig_diff(a: String, b: String) -> String:
	var left: PackedStringArray = a.split("|")
	var parts: PackedStringArray = PackedStringArray()
	for part: String in b.split("|"):
		if not left.has(part):
			parts.append(part)
	return " ".join(parts)


## Microseconds spent per part of the search since [method profile_reset] (tools/coop_search.gd --profile).
static var profile: Dictionary = {}


static func profile_add(part: StringName, since_usec: int) -> void:
	profile[part] = int(profile.get(part, 0)) + Time.get_ticks_usec() - since_usec


static func profile_reset() -> void:
	profile = {}
	stats = {}


## tools/coop_search.gd --stats: per macro group (its name without the side) the runs, ticks, runs from changed nodes
## (with a replay), runs that ended in nothing (died, down, no rest) and the new resting points they found.
static var collect_stats: bool = false
static var stats: Dictionary = {}


static func _stat_row(macro: Dictionary) -> Array:
	var group: String = str(macro["name"]).trim_suffix(" R").trim_suffix(" L")
	for side: String in ["R", "L"]:
		for steps: String in ["4", "10", "24", "48"]:
			if group == "walk %s%s" % [side, steps]:
				group = "walk %s" % steps
	if not stats.has(group):
		stats[group] = [0, 0, 0, 0, 0]
	return stats[group]


static func stat_run(macro: Dictionary, ticks: int, from_changed: bool, empty: bool) -> void:
	var row: Array = _stat_row(macro)
	row[0] += 1
	row[1] += ticks
	row[2] += 1 if from_changed else 0
	row[3] += 1 if empty else 0


static func stat_new(macro: Dictionary) -> void:
	_stat_row(macro)[4] += 1


## The [member stats] as text lines, the costliest group first.
static func stats_report() -> PackedStringArray:
	var rows: Array = []
	for group: String in stats:
		rows.append([group] + (stats[group] as Array))
	rows.sort_custom(func(a: Array, b: Array) -> bool: return int(a[2]) > int(b[2]))
	var lines: PackedStringArray = PackedStringArray()
	for row: Array in rows:
		lines.append("%-18s runs %5d  ticks %7d  changed %5d  empty %5d  new %4d" % row)
	return lines


## Explore results of [method search_data] (see [method _explore_key] and [method world_records]): the same grid at
## rest, records, starts, area, meta and difficulty give the same search (the difficulty is part of the key since
## phase 3: entities read Game.difficulty - windows, the egg's return, Expert behaviours - so a Beginner explore never
## stands in for the Expert one).
static var _explore_cache: Dictionary = {}
## False: [method search_data] always runs the search (no cached explore) - for tests that prove the search itself.
static var use_cache: bool = true
## False: no result file cache (see [method file_cache_key]).
static var use_file_cache: bool = true
## Resting points a gate search may expand (MAX_NODES; unit tests of the search's mechanics lower it to stay quick -
## a refusal under a smaller bound proves less, never more).
static var node_limit: int = MAX_NODES
## Ticks a gate search may simulate (MAX_TICKS; the macros, their replays and the probes) - a deterministic work bound
## (the same code and file stop at the same node on any machine).
static var tick_limit: int = MAX_TICKS
## False: no continuous-play probes in [method search_data] (unit tests of the macros alone).
static var probes: bool = true
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


## Every co-op gate the registry knows, in the order of tests/test_coop_gates.gd: per co-op level (Levels.all_ids
## order), per difficulty it is available in (Beginner, Expert), every `objects/x2_tablet gate=` of that difficulty in
## file order: {"level": StringName, "difficulty": int, "gate": String, "far": Vector2i ((-1, -1) when its tablet
## names none), "cell": Vector2i (the tablet's cell)}. Empty without the Levels autoload.
static func gate_table() -> Array[Dictionary]:
	var table: Array[Dictionary] = []
	var registry: Object = (Engine.get_main_loop() as SceneTree).root.get_node_or_null(^"Levels") \
			if Engine.get_main_loop() is SceneTree else null
	if registry == null:
		return table
	for level_id: StringName in registry.call(&"all_ids"):
		if not bool(registry.call(&"is_coop_level", level_id)):
			continue
		var data: LevelData = LevelData.load_file(str(registry.call(&"get_level_path", level_id)))
		if data == null:
			continue
		for difficulty: int in [Defs.Difficulty.BEGINNER, Defs.Difficulty.EXPERT]:
			if not bool(registry.call(&"is_available", level_id, difficulty)):
				continue
			for record: Dictionary in data.entity_records():
				var params: Dictionary = record["params"]
				if String(record["id"]) != "objects/x2_tablet" or not params.has("gate") \
						or not LevelText.applies_to(params, difficulty):
					continue
				var far: PackedStringArray = str(params.get("far", "")).replace(" ", "").split(",")
				var far_cell: Vector2i = Vector2i(-1, -1)
				if far.size() == 2 and far[0].is_valid_int() and far[1].is_valid_int():
					far_cell = Vector2i(far[0].to_int(), far[1].to_int())
				table.append({"level": level_id, "difficulty": difficulty, "gate": str(params["gate"]),
					"far": far_cell, "cell": Vector2i(int(record["col"]), int(record["row"]))})
	return table


## The entries of `table` ([method gate_table]) that shard `index` of `count` runs: every count-th entry from
## `index` on (the rule of test_coop_gates' COOP_GATES_SHARD=<index>/<count>), so `count` processes share the table.
static func shard_gates(table: Array, index: int, count: int) -> Array:
	var result: Array = []
	var n: int = maxi(count, 1)
	for i: int in table.size():
		if i % n == clampi(index, 0, n - 1):
			result.append(table[i])
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
				"strike", Defs.Weapon.CLUB))
		result.append(_macro("low-strike %s" % side, facing, _repeat(dir, 1) + _repeat(Defs.IN_DOWN | fire, 12),
				"strike", Defs.Weapon.CLUB))
		result.append(_macro("jump-strike %s" % side, facing, _repeat(up | dir, 9) + _repeat(dir | fire, 12)
				+ _repeat(dir, 8), "strike", Defs.Weapon.CLUB))
		result.append(_macro("pogo %s" % side, facing, _repeat(up | dir, 9) + _repeat(dir | Defs.IN_DOWN | fire, 16),
				"strike", Defs.Weapon.CLUB))
		result.append(_macro("strike-walk %s" % side, facing, _repeat(dir, 1) + _repeat(fire, 12) + _repeat(dir, 36),
				"strike", Defs.Weapon.CLUB))
		# Throws of every special (each held in the hand for the move, the club on the belt).
		for weapon: int in THROW_WEAPONS:
			var label: String = ["club", "hammer", "axe", "swirl", "spear"][weapon]
			result.append(_macro("throw %s %s" % [label, side], facing, _repeat(dir, 1) + _repeat(fire, 6)
					+ _repeat(0, 24), "throw", weapon))
		result.append(_macro("jump-throw axe %s" % side, facing, _repeat(up | dir, 9) + _repeat(dir | fire, 6)
				+ _repeat(dir, 12), "throw", Defs.Weapon.AXE))
		# The idle partner where the hero stands (heroes pass through each other): a jump straight up onto his head,
		# then a jump off it forward or a run and a jump. Since G33 an idle head carries no Totem Ride (the hero passes
		# through it, UP held or not): these stay as the regression check that nothing is reached through them.
		var onto: PackedInt32Array = _repeat(up, 9) + _repeat(0, 16)
		result.append(_macro("partner-jump %s" % side, facing, onto + _repeat(up | dir, 9) + _repeat(dir, 16),
				"partner", -1, PARTNER_IDLE))
		result.append(_macro("partner-run-jump %s" % side, facing, onto + _repeat(dir, 3) + _repeat(up | dir, 9)
				+ _repeat(dir, 16), "partner", -1, PARTNER_IDLE))
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
			# G47: once the engine makes the daze slot-bound (only another slot than the bouncer's hurts it), one player
			# can never use it, whatever its window: the record is "slot_bound" (exempt from the solo_min - 4 cap).
			var bound: bool = daze_slot_bound()
			var daze_window: Dictionary = {"what": "daze %s at %d,%d%s" % [id, cell.x, cell.y,
				" (slot-bound, G47)" if bound else ""],
				"window": CoopTraits.capped_window(PartyTuning.daze_ticks(difficulty), params),
				"solo_min": measure_daze_solo_min(id)}
			if bound:
				daze_window["slot_bound"] = true
			windows.append(daze_window)
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
		var what: String = key.replace(":", " ")
		if solo_min == 0:
			# G36: a bonded pair one thrown special hits together is a build error (the validator names it too).
			what += " (one thrown special hits two members: a build error, G36)"
		windows.append({"what": what, "window": int(caps.get(key, PartyTuning.window_ticks(difficulty))),
			"solo_min": solo_min})
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
	var found: Dictionary = searcher.explore(starts, goals, area, BOUND_TICKS, WINDOW_NODES)
	return int(found["ticks"]) if found["reached"] else BOUND_TICKS


## Feet points from which a strike reaches the cell `target` (LevelValidator.strike_spots, shared with the bonded-pair
## rule of G36).
static func strike_spots(grid: TileGrid, target: Vector2i) -> Array[Vector2i]:
	return LevelValidator.strike_spots(grid, target)


## Standing spots beside a door block (one or two columns either side of its anchor).
static func _door_spots(grid: TileGrid, door: Vector2i) -> Dictionary:
	var goals: Dictionary = {}
	for spot: Vector2i in strike_spots(grid, door):
		goals[Vector2i(Tuning.to_cell(spot.x), Tuning.to_cell(spot.y - 1))] = true
	return goals


## True when an axe, a swirling axe or a spear thrown either way from one of `spots` crosses the cell `target`
## (LevelValidator.throw_crosses, shared with the bonded-pair rule of G36).
static func throw_crosses(spots: Array[Vector2i], target: Vector2i) -> bool:
	return LevelValidator.throw_crosses(spots, target)


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


# =================================================================================================================
# Engine probes: what the co-op rules of this build allow (measured once per process, before any gate's world is built;
# the code they measure is part of the result cache's fingerprint, so a cached result never outlives a rule change)
# =================================================================================================================

## The probes' map: 30 x 16 cells, floor rows 14-15 (with the entity lines `entities`).
static func _probe_data(id: String, entities: String = "") -> LevelData:
	var rows: PackedStringArray = PackedStringArray()
	for row: int in 16:
		rows.append((TileGrid.CH_SOLID_A if row >= 14 else TileGrid.CH_AIR).repeat(30))
	var text: String = "[meta]\nformat = 2\nid = %s\nkind = coop\nbook = 2\nterrain_a = jungle/terrain_grass\n" % id \
			+ "music = level_jungle\n[tiles]\n%s\n[entities]\n%s\n" % ["\n".join(rows), entities]
	return LevelData.parse(StringName(id), text, "%s.lvl" % id)


## A search world of the probes' map (null when the hero scene does not exist).
static func _probe_world(id: String, entities: String = "") -> Searcher:
	var data: LevelData = _probe_data(id, entities)
	var searcher: Searcher = Searcher.new()
	if not searcher.build_world(data, Defs.Difficulty.BEGINNER, grid_at_rest(data, Defs.Difficulty.BEGINNER),
			Vector2i(0, data.cols)):
		return null
	return searcher


## 1 / 0 once probed, -1 before ([method idle_partner_carries]).
static var _ride_probe: int = -1


## G33 as built: true when a hero can still ride an idle partner's head - the jump straight up from the spot the idle
## partner stands on ends in a Totem Ride on him. The `partner` ride macros run only then: since G33 an idle head is
## passed through (party, PartyDriver._head_contacts), so they could reach nothing; this probe is their regression
## check - should a ride on an idle head ever come back, the search uses them again at once.
static func idle_partner_carries() -> bool:
	if _ride_probe < 0:
		_ride_probe = 1 if _probe_idle_ride() else 0
	return _ride_probe == 1


static func _probe_idle_ride() -> bool:
	var searcher: Searcher = _probe_world("coop_search_ride_probe")
	if searcher == null:
		return true   # nothing to probe with: keep the macros
	var start: Vector2i = Vector2i(10 * Tuning.TILE + Tuning.TILE / 2, 14 * Tuning.TILE)
	searcher.run(searcher._config(start, 1, -1, PARTNER_IDLE, NOWHERE), _repeat(Defs.IN_UP, 9) + _repeat(0, 16), {})
	var rides: bool = searcher.hero.is_riding_totem()
	searcher.close()
	return rides


## 1 / 0 once probed, -1 before ([method idle_partner_weighs]).
static var _weigh_probe: int = -1


## G33 as built in the objects: true when an IDLE hero standing on a plate weighs on it (the plate's weight or press
## while only the idle partner stands there, the lone hero far away). The search parks the idle partner at the co-op
## mechanisms only then ([method Searcher.placement_useful]); since G33 the plates (and the pulleys, see-saws, boulders
## and drums, built together by objects-A) count no idle hero, so those parked copies of the graph could reach
## nothing - this probe is their regression check.
static func idle_partner_weighs() -> bool:
	if _weigh_probe < 0:
		_weigh_probe = 1 if _probe_idle_weight() else 0
	return _weigh_probe == 1


static func _probe_idle_weight() -> bool:
	var searcher: Searcher = _probe_world("coop_search_weight_probe", "objects/plate 20 13 name=probe mode=hold")
	if searcher == null:
		return true   # nothing to probe with: keep the placements
	var plate: Plate = null
	for entity: SimEntity in searcher._entities:
		if entity is Plate:
			plate = entity as Plate
	if plate == null:
		searcher.close()
		return true
	var on_plate: Vector2i = Vector2i(plate.left_px() + Tuning.TILE, plate.floor_y())
	searcher.run(searcher._config(Vector2i(3 * Tuning.TILE, 14 * Tuning.TILE), 1, -1, PARTNER_IDLE, on_plate),
			_repeat(0, 24), {})
	var weighs: bool = plate.weight > 0 or plate.pressed or plate.presses > 0
	searcher.close()
	return weighs


## The daze probe ([method probe_daze]); empty before.
static var _daze_probe: Dictionary = {}


## G47 as built: true when a `daze` record dazed by a hero's head bounce glances that hero's own hits while another
## slot's hero hurts it (enemies-A's slot-bound daze). Then one player can never use a daze, whatever its window, and
## the search's daze records are "slot_bound" (exempt from test_coop_gates' solo_min - 4 cap); until then the cap holds.
static func daze_slot_bound() -> bool:
	var probe: Dictionary = probe_daze()
	return bool(probe["dazed"]) and bool(probe["other"]) and not bool(probe["own"])


## The daze rule of this build, on a still `coop=daze` target in a co-op search world of two (the bouncer slot 0, an
## ACTIVE hero of slot 1 beside the target as the control): {"dazed": a head bounce dazed it, "own": the bouncer's own
## hit is accepted right after his bounce (EnemyBase.accepts_hit_from), "other": slot 1's is}.
static func probe_daze() -> Dictionary:
	if not _daze_probe.is_empty():
		return _daze_probe
	var result: Dictionary = {"dazed": false, "own": true, "other": false}
	var searcher: Searcher = _probe_world("coop_search_daze_probe")
	if searcher == null:
		_daze_probe = result
		return result
	var target: EnemyBase = EnemyBase.new()
	target.set_box(Vector3i(32, 32, 16))
	target.spawn_setup(Vector2i(240, 224), {"coop": "daze"})
	searcher.level.add_child(target)
	searcher._kept[target.get_instance_id()] = true
	target.max_hp = 99999
	target.hp = 99999
	var hero: PlayerBase = searcher.hero
	var other: PlayerBase = searcher.partner
	other.run.reset_energy()
	other.respawn_at(Vector2i(400, 224))
	searcher._mark_active(other)
	hero.run.reset_energy()
	searcher._mark_active(hero)
	searcher.driver.set(&"active_mask", 3)
	searcher.level.refresh_doze()
	for side: int in [-1, 1]:
		var dir: int = Defs.IN_RIGHT if side < 0 else Defs.IN_LEFT
		for distance: int in range(16 + DAZE_MIN_GAP_PX, DAZE_MAX_DISTANCE_PX, DAZE_DISTANCE_STEP_PX):
			for hold: int in DAZE_HOLDS:
				searcher._mark_active(other)
				if _daze_run(searcher, target, Vector2i(240 + side * distance, 224), -side, dir, hold, 0, 0, 0) \
						== DAZE_NO_BOUNCE:
					continue
				var traits: CoopTraits = target.coop_traits()
				result["dazed"] = traits != null and (not (&"dazed" in traits) or int(traits.get(&"dazed")) > 0)
				result["own"] = target.accepts_hit_from(hero)
				result["other"] = target.accepts_hit_from(other)
				if bool(result["dazed"]):
					break
			if bool(result["dazed"]):
				break
		if bool(result["dazed"]):
			break
	searcher.close()
	_daze_probe = result
	return result
