extends "res://tools/autoplay/recorders/db2/botlib.gd"
## DB2 bot helpers on top of D6's bot library (development only; build/ is not versioned).


## True when the cell (c, r) is not air (a risen column, a door).
func solid(c: int, r: int) -> bool:
	return level != null and level.get_cell(c, r) != TileGrid.CH_AIR


func solid_fn(c: int, r: int) -> Callable:
	return func(lv: LevelBase, _h: PlayerBase) -> bool:
		return lv.get_cell(c, r) != TileGrid.CH_AIR


func air_fn(c: int, r: int) -> Callable:
	return func(lv: LevelBase, _h: PlayerBase) -> bool:
		return lv.get_cell(c, r) == TileGrid.CH_AIR


func grounded_fn() -> Callable:
	return func(_lv: LevelBase, h: PlayerBase) -> bool:
		return h.is_grounded()


## The hero stands (grounded) with his feet at most `y` (higher than or at y).
func stands_above_fn(y: int) -> Callable:
	return func(_lv: LevelBase, h: PlayerBase) -> bool:
		return h.is_grounded() and h.sim_pos.y <= y


func partner_fn(cond: Callable) -> Callable:
	return func(lv: LevelBase, h: PlayerBase) -> bool:
		return cond.call(lv, hero(1 - h.slot))


## The living enemy nearest to (x, y) within `reach` px, or null.
func enemy_near(x: int, y: int, reach: int = 48) -> EnemyBase:
	var best: EnemyBase = null
	var best_d: int = reach + 1
	for entity: SimEntity in level.get_kind(Defs.Kind.ENEMY):
		var foe: EnemyBase = entity as EnemyBase
		if foe == null or foe.dead:
			continue
		var d: int = absi(foe.sim_pos.x - x) + absi(foe.sim_pos.y - y)
		if d < best_d:
			best = foe
			best_d = d
	return best


## The trait state of an enemy (its CoopTraits), or null.
static func traits_of(foe: EnemyBase) -> Object:
	return foe.get("_traits") if foe != null else null


## Walk to x (go) then, from a standstill, jump straight up (with `dir` steering) - for a Shoulder Hop etc.
func until_dead_fn(x: int, y: int, reach: int = 64) -> Callable:
	return func(lv: LevelBase, _h: PlayerBase) -> bool:
		return enemy_near(x, y, reach) == null


## Climb a vine: Up until he stands with his feet on row `row` (the vine's top landing).
func climb_fn(row: int) -> Callable:
	return func(_lv: LevelBase, h: PlayerBase, n: int) -> int:
		if h.is_grounded() and h.sim_pos.y <= row * 16 and n > 2:
			return -1
		if n > 900:
			return -1
		return U


## Strike (with `extra`) until the rolled vine anchored in column `col` is unrolled.
func unroll_fn(col: int, extra: int = 0) -> Callable:
	return func(lv: LevelBase, h: PlayerBase, n: int) -> int:
		for kind: int in Defs.KIND_COUNT:
			for entity: SimEntity in lv.get_kind(kind):
				var vine: Vine = entity as Vine
				if vine != null and vine.vine_x >> 4 == col and vine.unrolled:
					return -1
		if n > 400:
			return -1
		var st: Dictionary = _st[h.slot]
		if bool(st.get("pressed", false)):
			st["pressed"] = false
			return 0
		if not h.is_grounded() or h.is_striking():
			return 0
		st["pressed"] = true
		return F | extra


## Jump onto a spring at `sx` (Up for the first ticks while walking to it), then steer to `tx` until he lands
## higher than he started.
func spring_fn(sx: int, tx: int) -> Callable:
	return func(_lv: LevelBase, h: PlayerBase, n: int) -> int:
		var st: Dictionary = _st[h.slot]
		if n == 0:
			st["y0"] = h.sim_pos.y
		if not bool(st.get("up", false)):
			if h.yvel < -150 and not h.is_grounded() and n > 3:
				st["up"] = true
			else:
				if n > 120:
					return -1
				var k: int = 0
				var dx0: int = sx - h.sim_pos.x
				if dx0 > 2:
					k = R
				elif dx0 < -2:
					k = L
				if n < 4:
					k |= U
				return k
		if h.is_grounded() and h.sim_pos.y < int(st["y0"]) - 8:
			return -1
		if n > 400:
			return -1
		var dx: int = tx - h.sim_pos.x
		if dx > 3:
			return R
		if dx < -3:
			return L
		return 0


## Wait (pressing `wait_keys`) until launched upwards (a see-saw, a lift), then steer to `tx` until he lands higher.
func launch_fn(tx: int, wait_keys: int = 0) -> Callable:
	return func(_lv: LevelBase, h: PlayerBase, n: int) -> int:
		var st: Dictionary = _st[h.slot]
		if n == 0:
			st["y0"] = h.sim_pos.y
		if not bool(st.get("up", false)):
			if h.yvel < -100 and not h.is_grounded():
				st["up"] = true
			else:
				if n > 900:
					return -1
				return wait_keys
		if h.is_grounded() and h.sim_pos.y < int(st["y0"]) - 8:
			return -1
		if n > 600:
			return -1
		var dx: int = tx - h.sim_pos.x
		if dx > 3:
			return R
		if dx < -3:
			return L
		return 0


## Hold `keys` (e.g. a tap of D every few ticks) - a role holder that keeps giving input (the IDLE rule).
func hold_fn(cond: Callable, keys: int = D) -> Callable:
	return func(lv: LevelBase, h: PlayerBase, n: int) -> int:
		if cond.call(lv, h):
			return -1
		if n > 2000:
			return -1
		return keys if n % 40 == 0 else 0


## A sync point every slot must reach; slot programs append it themselves.
func both(progs: Array, cmd: Array) -> void:
	for p: Array in progs:
		p.append(cmd)


## A jump toward `tx` that first waits for the jump lock-out (grounded `settle` ticks), holds Up `up` ticks, steers in
## the air (within `lead` px) and ends on the first grounded tick after take-off.
func hop_fn(tx: int, up: int, settle: int = 7, lead: int = 3) -> Callable:
	return func(_lv: LevelBase, h: PlayerBase, n: int) -> int:
		var st: Dictionary = _st[h.slot]
		if n > 400:
			return -1
		if not bool(st.get("jumped", false)):
			if h.is_grounded() and h.xvel == 0:
				st["g"] = int(st.get("g", 0)) + 1
			else:
				st["g"] = 0
			if int(st["g"]) < settle:
				return 0
			st["jumped"] = true
			st["t0"] = n
		var k: int = n - int(st["t0"])
		var dx: int = tx - h.sim_pos.x
		var keys: int = 0
		if dx > lead:
			keys = R
		elif dx < -lead:
			keys = L
		if k < up:
			return U | keys
		if k > 2 and h.is_grounded():
			return -1
		return keys


## Stand and fight (strikes at enemies in reach, D6's _fight) until `cond` holds.
func guard_fn(cond: Callable) -> Callable:
	return func(lv: LevelBase, h: PlayerBase, n: int) -> int:
		if cond.call(lv, h):
			return -1
		if n > 3000:
			return -1
		var f: int = _fight(h, {"fight": true})
		return f if f >= 0 else 0


## Shoulder Hop: jump onto the partner's head (standing at `px`) holding Up, ride the -224 bounce and steer to `tx`,
## until he stands at most at `top_y` (the ledge). Starts from beside the partner.
func shoulder_fn(px: int, tx: int, top_y: int) -> Callable:
	return func(_lv: LevelBase, h: PlayerBase, n: int) -> int:
		var st: Dictionary = _st[h.slot]
		if n > 300:
			return -1
		if h.is_grounded() and h.sim_pos.y <= top_y and n > 4:
			return -1
		var phase: int = int(st.get("phase", 0))
		if phase == 0:
			if h.is_grounded() and h.xvel == 0:
				st["g"] = int(st.get("g", 0)) + 1
			else:
				st["g"] = 0
			if int(st["g"]) < 7:
				return 0
			st["phase"] = 1
			phase = 1
		if phase == 1:
			if h.yvel < -150 and n > 8:
				st["phase"] = 2
			else:
				var dx: int = px - h.sim_pos.x
				var k: int = U
				if dx > 2:
					k |= R
				elif dx < -2:
					k |= L
				return k
		var dx2: int = tx - h.sim_pos.x
		var k2: int = U
		if dx2 > 3:
			k2 |= R
		elif dx2 < -3:
			k2 |= L
		return k2
