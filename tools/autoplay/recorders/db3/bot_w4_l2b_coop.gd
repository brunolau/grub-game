extends "res://tools/autoplay/recorders/db3/botlib.gd"
## The two-stream route of w4_l2b_coop (DB3; Expert only), recorded by probe_work.gd --bot --players=2. Both heroes
## take an axe at the checkpoint (P2 walks over the one on the floor, P1 jumps for the one three rows up) and drop into
## the hall. One holds the plate whose chain glows (the visor lifts), the other throws high axes at the head; rocks
## come for the holder (he hops them on his plate), drops rattle over the thrower (he steps aside). Each rage moves the
## live chain: the hero nearer to the new live plate takes it over and the other goes to the throwing spot - the roles
## swap. Dodges come from a predictor (the rock's own motion code, the hero's measured hop heights). Both give input.

const S: int = Defs.IN_SWAP
## The thrower's spot (the floor left of the slab) and the heights of a hop of 2 / 3 Up ticks per tick (measured).
var throw_x: int = 512
## The thrower's ledge (cols 30-33, top row 10).
const LEDGE_L: int = 480
const LEDGE_R: int = 543
const LEDGE_Y: int = 160
const HOP2: Array[int] = [0, 7, 13, 18, 22, 25, 27, 28, 28, 27, 25, 22, 18, 13, 7, 0]
const HOP3: Array[int] = [0, 7, 15, 22, 28, 33, 37, 40, 42, 43, 43, 42, 40, 37, 33, 28, 22, 15, 7, 0]
const LOOK: int = 40

var _holder_slot: int = -1
var _live: Object = null
var _last_hp: int = -1


func header() -> String:
	return "# route: level=w4_l2b_coop difficulty=expert players=2 ends=trophy after=level:ending_coop expect=eggs:0,wipes:0\n"


func colossus(lv: LevelBase) -> Colossus:
	for entity: SimEntity in lv.get_kind(Defs.Kind.BOSS):
		var c: Colossus = entity as Colossus
		if c != null:
			return c
	return null


# --- prediction ----------------------------------------------------------------------------------------------------

## The rock's next `n` positions (BossRock._move_tick / _turn_at_wall / _collide); Vector2i(-99999, 0) once gone.
func rock_path(lv: LevelBase, rock: SimEntity, n: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var x: int = rock.sim_pos.x
	var y: int = rock.sim_pos.y
	var xv: int = int(rock.get(&"xvel"))
	var yv: int = int(rock.get(&"yvel"))
	var resting: int = int(rock.get(&"_resting"))
	var grid: TileGrid = lv.grid
	var gone: bool = false
	for i: int in n:
		if gone:
			out.append(Vector2i(-99999, 0))
			continue
		x += Tuning.floor16(xv)
		var dir: int = signi(xv)
		if dir != 0:
			var probe: int = x + dir * 5
			if grid.side_at(Tuning.to_cell(probe), Tuning.to_cell(y - 1)) == TileGrid.SIDE_WALL:
				x -= Tuning.floor16(xv)
				xv = -xv
		y += Tuning.floor16(yv)
		yv = mini(yv + Tuning.ENEMY_GRAVITY, Tuning.ENEMY_TERMINAL)
		if yv > 0:
			var col: int = Tuning.to_cell(x)
			var row: int = Tuning.to_cell(y)
			if TileGrid.is_ground(grid.floor_at(col, row)):
				var surface: int = row * Tuning.TILE + grid.surface_offset(col, row, x)
				if y >= surface:
					y = surface
					var rebound: int = Tuning.shr(yv, 1)
					yv = -rebound if rebound > EnemyTuning.ROCK_SETTLE_REBOUND else 0
					xv -= Tuning.shr(xv, EnemyTuning.ROCK_FRICTION_SHIFT)
					if yv == 0 and resting == 0:
						resting = 1
		if resting > 0:
			resting += 1
			if resting > EnemyTuning.ROCK_REST_TICKS:
				gone = true
		out.append(Vector2i(x, y))
	return out


func _hits(hx: int, hy: int, rise: int, r: Vector3i, wide: bool) -> bool:
	if r.x < -9000:
		return false
	var half: int = 21 if wide else 17
	var feet: int = hy - rise
	var top: int = feet - 38
	var oh: int = r.z
	return r.x + 5 > hx - half and r.x - 5 < hx + half and r.y > top and r.y - oh < feet


## A stalactite's next `n` positions (BossStalactite._move_tick): hangs while it rattles, then falls.
func drop_path(lv: LevelBase, drop: SimEntity, n: int) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	var y: int = drop.sim_pos.y
	var yv: int = int(drop.get(&"yvel"))
	var age: int = int(drop.get(&"_age"))
	var gone: bool = false
	for i: int in n:
		if gone:
			out.append(Vector3i(-99999, 0, 20))
			continue
		age += 1
		if age >= EnemyTuning.STALACTITE_WARN_TICKS:
			y += Tuning.floor16(yv)
			yv = mini(yv + Tuning.ENEMY_GRAVITY, Tuning.ENEMY_TERMINAL)
			if TileGrid.is_ground(lv.grid.floor_at(Tuning.to_cell(drop.sim_pos.x), Tuning.to_cell(y))):
				gone = true
		out.append(Vector3i(drop.sim_pos.x, y, 20))
	return out


## All rock and drop paths of the level now (Vector3i: x, y, box height).
func rock_paths(lv: LevelBase) -> Array:
	var paths: Array = []
	for entity: SimEntity in lv.get_kind(Defs.Kind.ENEMY_PROJECTILE):
		if (entity as ProjectileBase).spent:
			continue
		if entity is BossRock:
			var p: Array[Vector3i] = []
			for v: Vector2i in rock_path(lv, entity, LOOK):
				p.append(Vector3i(v.x, v.y, 10))
			paths.append(p)
		elif entity is BossStalactite:
			paths.append(drop_path(lv, entity, LOOK))
	return paths


const HOP5: Array[int] = [0, 7, 15, 23, 31, 38, 44, 49, 53, 56, 58, 59, 59, 58, 56, 53, 49, 44, 38, 31, 23, 14, 4, 0]
## A walk from standing (px per tick from the start, measured).
const WALK: Array[int] = [0, 3, 8, 13, 18, 23, 28, 33, 38, 43, 48, 53, 58, 63, 68, 73, 78, 83, 88, 93, 98, 103, 108,
	113, 118, 123, 128, 133, 138, 143, 148, 153, 158, 163, 168, 173, 178, 183, 188, 193, 198]
## The hall's floor between its walls and the statue's body (feet x).
const LO_X: int = 424
const HI_X: int = 612


## First tick (1..LOOK) a rock touches the hero standing still at (hx, hy), else 0.
func stand_hit(paths: Array, hx: int, hy: int) -> int:
	for t: int in LOOK:
		for p: Array in paths:
			if _hits(hx, hy, 0, p[t], false):
				return t + 1
	return 0


## True when a hop with table `hop` started after `d` ticks of standing clears every rock.
func hop_safe(paths: Array, hx: int, hy: int, hop: Array[int], d: int) -> bool:
	for t: int in LOOK:
		var k: int = t + 1 - d
		var rise: int = hop[k] if k >= 0 and k < hop.size() else 0
		for p: Array in paths:
			if _hits(hx, hy, rise, p[t], k > 0 and k < hop.size()):
				return false
	return true


## True when walking in `dir` from now on (for `ticks` ticks, then standing) clears every rock and stays on the floor.
func walk_safe(paths: Array, hx: int, hy: int, dir: int, ticks: int) -> bool:
	for t: int in LOOK:
		var step: int = WALK[mini(t + 1, mini(ticks, WALK.size() - 1))]
		var x: int = hx + dir * step
		if x < LO_X or x > HI_X:
			return false
		for p: Array in paths:
			if _hits(x, hy, 0, p[t], false):
				return false
	return true


var _hop_ticks: int = 0


## The dodge for a grounded hero who wants to walk in `want` (-1 / 0 / 1): 0 = do as wanted, -2 = stand this tick (a
## later hop is safe), else the flags to press now (U = start a hop of _hop_ticks Up ticks, L / R = walk away).
func dodge(paths: Array, h: PlayerBase, want: int) -> int:
	var hx: int = h.sim_pos.x
	var hy: int = h.sim_pos.y
	if paths.is_empty():
		return 0
	if want != 0 and walk_safe(paths, hx, hy, want, LOOK):
		return 0
	var tau: int = stand_hit(paths, hx, hy)
	if tau == 0:
		return 0 if want == 0 else -2
	var best_d: int = -1
	var best_k: int = 0
	for d: int in range(0, tau):
		for k: int in [3, 2]:
			var table: Array[int] = HOP3 if k == 3 else (HOP2 if k == 2 else HOP5)
			if d > best_d and hop_safe(paths, hx, hy, table, d):
				best_d = d
				best_k = k
	if best_d > 1:
		return -2
	if best_d >= 0:
		_hop_ticks = best_k
		return U
	for ticks: int in [8, 14, 24, LOOK]:
		for dir: int in [-1, 1]:
			if walk_safe(paths, hx, hy, dir, ticks):
				_walk_ticks = ticks
				return L if dir < 0 else R
	_hop_ticks = 3
	return U


var _walk_ticks: int = 0


## A drop over the hero (rattling or falling) within `reach` px: its x, else -99999.
func drop_over(lv: LevelBase, h: PlayerBase, reach: int) -> int:
	for entity: SimEntity in lv.get_kind(Defs.Kind.ENEMY_PROJECTILE):
		if entity is BossStalactite and not (entity as ProjectileBase).spent:
			if absi(entity.sim_pos.x - h.sim_pos.x) < reach and entity.sim_pos.y < h.sim_pos.y:
				return entity.sim_pos.x
	return -99999


func axe_in_flight(lv: LevelBase, slot: int) -> bool:
	for entity: SimEntity in lv.get_kind(Defs.Kind.HERO_PROJECTILE):
		var p: ProjectileBase = entity as ProjectileBase
		if p != null and not p.spent and p.owner_slot == slot:
			return true
	return false


# --- the fight -----------------------------------------------------------------------------------------------------

func fight_fn() -> Callable:
	return func(lv: LevelBase, h: PlayerBase, n: int) -> int:
		var c: Colossus = colossus(lv)
		if c == null or c.dead or n > 8000:
			return -1
		if h.slot == 0 and c.hp != _last_hp:
			print("FIGHT t=%d hp %d live %d state %d" % [t, c.hp, c._live, c._state])
			_last_hp = c.hp
		if h.slot == 0 and t >= int(opts.get("dbg_from", "999999")) and t <= int(opts.get("dbg_to", "0")):
			var line: String = "DBG t=%d st%d vis%d cd%d" % [t, c._state, int(c.is_visor_up()), c.hit_cooldown]
			for hh: PlayerBase in lv.heroes:
				line += " | P%d (%d,%d) g%d" % [hh.slot + 1, hh.sim_pos.x, hh.sim_pos.y, int(hh.is_grounded())]
			for e: SimEntity in lv.get_kind(Defs.Kind.ENEMY_PROJECTILE):
				line += " | %s (%d,%d) v%d,%d" % ["R" if e is BossRock else "S", e.sim_pos.x, e.sim_pos.y,
					int(e.get(&"xvel")), int(e.get(&"yvel"))]
			for e: SimEntity in lv.get_kind(Defs.Kind.HERO_PROJECTILE):
				line += " | axe (%d,%d)" % [e.sim_pos.x, e.sim_pos.y]
			print(line)
		var plate: Plate = c.get_live_plate()
		if plate != _live:
			_live = plate
			if plate != null:
				var px: int = plate.sim_pos.x + 8
				_holder_slot = 0 if absi(hero(0).sim_pos.x - px) <= absi(hero(1).sim_pos.x - px) else 1
				print("FIGHT t=%d live plate at %d: holder P%d" % [t, px, _holder_slot + 1])
		var st: Dictionary = _st[h.slot]
		if int(st.get("busy", 0)) > 0:
			st["busy"] = int(st["busy"]) - 1
			return int(st.get("busy_keys", 0))
		if not h.is_grounded():
			return int(st.get("air", 0))
		st["air"] = 0
		var holder: bool = h.slot == _holder_slot
		# where the role wants him: the live plate, or the throwing spot on the ledge; out from under a drop first
		var tx: int = throw_x
		if holder and plate != null:
			tx = plate.sim_pos.x + 8
		var on_ledge: bool = h.sim_pos.y <= LEDGE_Y + 2
		if not holder and not on_ledge:
			# onto the ledge: a jump from beside its face
			var side: int = -1 if h.sim_pos.x < throw_x else 1
			var spot: int = LEDGE_L - 22 if side < 0 else LEDGE_R + 22
			if absi(h.sim_pos.x - spot) <= 6 and drop_over(lv, h, 26) == -99999:
				st["busy"] = 7
				st["busy_keys"] = U | (R if side < 0 else L)
				st["air"] = R if side < 0 else L
				return int(st["busy_keys"])
			tx = spot
		var drop: int = drop_over(lv, h, 26)
		if drop > -99999:
			tx = drop + (-34 if drop > (throw_x if on_ledge else 470) else 34)
			if on_ledge and not holder:
				tx = clampi(tx, LEDGE_L + 4, LEDGE_R - 3)
		var want: int = 0
		if absi(tx - h.sim_pos.x) > 3:
			want = 1 if tx > h.sim_pos.x else -1
		var paths: Array = rock_paths(lv)
		var dz: int = dodge(paths, h, want)
		if dz == U:
			st["busy"] = _hop_ticks - 1
			st["busy_keys"] = U
			return U
		if dz == L or dz == R:
			st["busy"] = _walk_ticks - 1
			st["busy_keys"] = dz
			return dz
		if dz == -2:
			return 0
		if want != 0:
			return _walk(h, tx)
		if holder:
			return D if n % 40 == 0 else 0
		if h.facing < 0:
			return R
		# the thrower: a high throw when the visor is up and the holder stays put while the axe flies
		var holder_hero: PlayerBase = hero(_holder_slot)
		var holder_safe: bool = holder_hero != null and stand_hit(paths, holder_hero.sim_pos.x, holder_hero.sim_pos.y) == 0
		var me_safe: bool = stand_hit(paths, h.sim_pos.x, h.sim_pos.y) == 0
		if c.is_visor_up() and c._state != Colossus.State.RAGE and c.hit_cooldown <= 6 and holder_safe and me_safe 				and not axe_in_flight(lv, h.slot) and drop_over(lv, h, 30) == -99999:
			st["busy"] = 8
			st["busy_keys"] = U | F
			return U | F
		return 0


## After the fight: walk to the nearest trophy (one of them ends the stage).
func trophy_fn() -> Callable:
	return func(lv: LevelBase, h: PlayerBase, n: int) -> int:
		if n > 900:
			return -1
		var best: SimEntity = null
		for entity: SimEntity in lv.get_kind(Defs.Kind.COLLECTIBLE):
			var item: CollectibleBase = entity as CollectibleBase
			if item != null and item.item_id == &"items/trophy":
				if best == null or absi(item.sim_pos.x - h.sim_pos.x) < absi(best.sim_pos.x - h.sim_pos.x):
					best = item
		if best == null or not h.is_grounded():
			return 0
		var dx: int = best.sim_pos.x - h.sim_pos.x
		if absi(dx) <= 4:
			return U if best.sim_pos.y < h.sim_pos.y - 40 and n % 30 == 0 else 0
		return R if dx > 0 else L


func _walk(h: PlayerBase, x: int) -> int:
	var dx: int = x - h.sim_pos.x
	var speed: int = absi(h.xvel)
	if h.xvel != 0 and signi(h.xvel) == signi(dx) and absi(dx) <= (speed * speed) / (2 * 12 * 16) + 2:
		return 0
	if speed == 0 and absi(dx) < 8 and t % 3 != 0:
		return 0
	return R if dx > 0 else L


func build() -> Array:
	if opts.has("throw_x"):
		throw_x = int(opts["throw_x"])
	var p1: Array = []
	var p2: Array = []
	# The antechamber: P2 (in front) walks over the axe on the floor, P1 jumps for the one three rows up
	p2.append(["go", 232, {"tol": 3}])
	p1.append(["wait", 4])
	p1.append(["go", 184, {"tol": 2}])
	p1.append(["jump", 0, 14, {}])
	p1.append(["mark", "axe"])
	p1.append(["sync", "hall"])
	p2.append(["sync", "hall"])
	p2.append(["run", 440])
	p2.append(["until", func(_lv: LevelBase, h: PlayerBase) -> bool: return h.is_grounded() and h.sim_pos.y > 180, R])
	p1.append(["wait", 12])
	p1.append(["run", 420])
	p1.append(["until", func(_lv: LevelBase, h: PlayerBase) -> bool: return h.is_grounded() and h.sim_pos.y > 180, R])
	p1.append(["fn", fight_fn()])
	p2.append(["fn", fight_fn()])
	p1.append(["mark", "fight over"])
	p2.append(["mark", "fight over"])
	p1.append(["fn", trophy_fn()])
	p2.append(["fn", trophy_fn()])
	return [p1, p2]
