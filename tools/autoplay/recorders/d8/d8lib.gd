extends "res://tools/autoplay/recorders/d8/botlib.gd"
## D8 helpers over D6's bot library: Guards (jump over, strike the back), Mimics (jump over), waiting for columns.


func nearest_enemy(h: PlayerBase, cls: String, max_dx: int, max_dy: int = 40) -> EnemyBase:
	var best: EnemyBase = null
	for entity: SimEntity in level.get_kind(Defs.Kind.ENEMY):
		var foe: EnemyBase = entity as EnemyBase
		if foe == null or foe.dead or not foe.tangible:
			continue
		if cls == "guard" and not (foe is Guard):
			continue
		if cls == "mimic" and not (foe is Mimic):
			continue
		var dx: int = absi(foe.sim_pos.x - h.sim_pos.x)
		var dy: int = absi(foe.sim_pos.y - h.sim_pos.y)
		if dx > max_dx or dy > max_dy:
			continue
		if best == null or dx < absi(best.sim_pos.x - h.sim_pos.x):
			best = foe
	return best


## Beat the Guard ahead (within `reach` px): a running jump onto its head (Up held: the 105 px bounce) carries the
## hero over it; behind it, strike its back while the shield faces away. Ends when it is dead or far.
func guard_fn(reach: int = 160, limit: int = 600, jump_at: int = 100) -> Callable:
	return func(lv: LevelBase, h: PlayerBase, n: int) -> int:
		var st: Dictionary = _st[h.slot]
		if n > limit:
			return -1
		var g: EnemyBase = st.get("g") as EnemyBase if st.has("g") else null
		if g == null:
			g = nearest_enemy(h, "guard", reach)
			if g == null:
				return -1
			st["g"] = g
		if g.dead or absi(g.sim_pos.x - h.sim_pos.x) > reach + 60:
			return -1
		var rel: int = g.sim_pos.x - h.sim_pos.x
		var side: int = 1 if rel > 0 else -1
		var shield: int = (g as Guard).get_shield_dir()
		var exposed: bool = shield == side
		var toward: int = R if side > 0 else L
		var away: int = L if side > 0 else R
		if int(st.get("jumping", 0)) > 0:
			st["jumping"] = int(st["jumping"]) + 1
			var jd: int = int(st["jdir"])
			var jk: int = R if jd > 0 else L
			var past: bool = (h.sim_pos.x - g.sim_pos.x) * jd > int(st.get("past", 54))
			if h.is_grounded() and int(st["jumping"]) > 6 and h.yvel == 0:
				st["jumping"] = 0
				return 0
			return U | (0 if past else jk)
		if int(st.get("striking", 0)) > 0:
			st["striking"] = int(st["striking"]) - 1
			return F if int(st["striking"]) > 7 else 0
		if not h.is_grounded():
			return 0
		var adx: int = absi(rel)
		if exposed and adx <= 70:
			if h.facing != side:
				return toward
			st["striking"] = 10
			return F
		var fast: bool = absi(h.xvel) >= 64 and signi(h.xvel) == side
		if bool(st.get("retreat", false)):
			if adx >= jump_at + 30:
				st["retreat"] = false
			return away
		if fast and adx <= jump_at:
			st["jumping"] = 1
			st["jdir"] = side
			return U | toward
		if adx > jump_at:
			return toward
		st["retreat"] = true
		return away


## Wait until the columns around cell `cell` stopped rising (no hero needed): `ticks` of idle after the trigger.
func settle_fn(ticks: int) -> Callable:
	return func(lv: LevelBase, h: PlayerBase, n: int) -> int:
		return 0 if n < ticks else -1


## Get past the Guard ahead without fighting it: a running jump onto its head with Up held (the 105 px bounce) and on
## over it; ends once grounded beyond it by `clear` px.
func guard_pass_fn(dir: int, reach: int = 170, clear: int = 56, jump_at: int = 100, limit: int = 600) -> Callable:
	return func(lv: LevelBase, h: PlayerBase, n: int) -> int:
		var st: Dictionary = _st[h.slot]
		if n > limit:
			return -1
		var g: EnemyBase = st.get("g") as EnemyBase if st.has("g") else null
		if g == null:
			g = nearest_enemy(h, "guard", reach)
			if g == null:
				return -1
			st["g"] = g
		var rel: int = (g.sim_pos.x - h.sim_pos.x) * dir
		var toward: int = R if dir > 0 else L
		var away: int = L if dir > 0 else R
		if g.dead or (rel < -clear and h.is_grounded()):
			return -1
		if int(st.get("jumping", 0)) > 0:
			st["jumping"] = int(st["jumping"]) + 1
			if h.is_grounded() and int(st["jumping"]) > 6 and h.yvel == 0:
				st["jumping"] = 0
				return toward
			return U | toward
		if not h.is_grounded():
			return toward
		if rel < 0:
			return toward
		var fast: bool = absi(h.xvel) >= 64 and signi(h.xvel) == dir
		if bool(st.get("retreat", false)):
			if rel >= jump_at + 30:
				st["retreat"] = false
			return away
		if fast and rel <= jump_at:
			st["jumping"] = 1
			return U | toward
		if rel > jump_at:
			return toward
		st["retreat"] = true
		return away


## The Mimic ahead (dir): a running jump onto its lid (a small bounce: Up released before the contact) dazes it; on
## past it, turn and strike its back while it is dazed. With `kill` false the hero only jumps over it (no contact).
func mimic_fn(dir: int, kill: bool = true, reach: int = 220, limit: int = 300) -> Callable:
	return func(lv: LevelBase, h: PlayerBase, n: int) -> int:
		var st: Dictionary = _st[h.slot]
		if n > limit:
			return -1
		var m: EnemyBase = st.get("m") as EnemyBase if st.has("m") else null
		if m == null:
			m = nearest_enemy(h, "mimic", reach, 20)
			if m == null:
				return -1
			st["m"] = m
		var rel: int = (m.sim_pos.x - h.sim_pos.x) * dir
		var toward: int = R if dir > 0 else L
		var back: int = L if dir > 0 else R
		if m.dead:
			return -1
		if int(st.get("jumping", 0)) > 0:
			st["jumping"] = int(st["jumping"]) + 1
			var j: int = int(st["jumping"])
			if h.is_grounded() and j > 6 and h.yvel == 0 and rel < -4:
				st["jumping"] = 0
				st["phase"] = 1
				return 0
			if j <= int(st.get("jup", 6)):
				return U | toward
			return toward if rel > -24 else 0
		if int(st.get("phase", 0)) == 1:
			if not kill:
				return -1
			if int(st.get("striking", 0)) > 0:
				st["striking"] = int(st["striking"]) - 1
				return F if int(st["striking"]) > 7 else 0
			if h.facing == dir:
				return back
			if int(st.get("strikes", 0)) >= 4:
				return -1
			st["strikes"] = int(st.get("strikes", 0)) + 1
			st["striking"] = 10
			return F
		if not h.is_grounded():
			return toward
		var fast: bool = absi(h.xvel) >= 64 and signi(h.xvel) == dir
		if fast and rel <= (int(st.get("ja", 98)) if kill else 66):
			st["jumping"] = 1
			st["jup"] = 6 if kill else 12
			return U | toward
		if rel > (110 if kill else 66) or (fast and rel > 0):
			return toward
		# too close for a run-up: back off
		return back


## Stand and fight (the `fight` strikes) until no living, awake enemy of `cls` ("" = any) is within `radius` px, or
## `limit` ticks passed. Faces an enemy that is behind.
func clear_fn(radius: int, limit: int = 300, cls: String = "") -> Callable:
	return func(lv: LevelBase, h: PlayerBase, n: int) -> int:
		if n > limit:
			return -1
		var any: bool = false
		for entity: SimEntity in lv.get_kind(Defs.Kind.ENEMY):
			var foe: EnemyBase = entity as EnemyBase
			if foe == null or foe.dead or not foe.awake or not foe.tangible:
				continue
			if cls == "harrier" and not (foe is Harrier):
				continue
			if absi(foe.sim_pos.x - h.sim_pos.x) <= radius and absi(foe.sim_pos.y - h.sim_pos.y) <= radius:
				any = true
				if n % 20 == 0 and signi(foe.sim_pos.x - h.sim_pos.x) != h.facing and absi(foe.sim_pos.x - h.sim_pos.x) > 12:
					return R if foe.sim_pos.x > h.sim_pos.x else L
		if not any:
			return -1
		var f: int = _fight(h, {"fight": true, "wait_px": 0})
		return f if f >= 0 else 0


## Kill the hopper (raptor) nearest within `reach` px: keep out of its hop (it covers about 51 px) while it is in the
## air, then run in and strike while it rests after landing.
func hopper_fn(reach: int = 160, limit: int = 400, lo: int = -1, hi: int = 1048576) -> Callable:
	return func(lv: LevelBase, h: PlayerBase, n: int) -> int:
		var f0: int = _hopper_step(lv, h, n, reach, limit)
		if f0 > 0 and (f0 & L) != 0 and h.sim_pos.x <= lo:
			return f0 & ~L
		if f0 > 0 and (f0 & R) != 0 and h.sim_pos.x >= hi:
			return f0 & ~R
		return f0


func _hopper_step(lv: LevelBase, h: PlayerBase, n: int, reach: int, limit: int) -> int:
	var st: Dictionary = _st[h.slot]
	if n > limit:
		return -1
	var e: EnemyBase = st.get("e") as EnemyBase if st.has("e") else null
	if e == null:
		for entity: SimEntity in lv.get_kind(Defs.Kind.ENEMY):
			var foe: EnemyBase = entity as EnemyBase
			if foe == null or foe.dead or not (foe is Hopper):
				continue
			var d: int = absi(foe.sim_pos.x - h.sim_pos.x)
			if d <= reach and absi(foe.sim_pos.y - h.sim_pos.y) < 48 and (e == null or d < absi(e.sim_pos.x - h.sim_pos.x)):
				e = foe
		if e == null:
			return -1
		st["e"] = e
	if e.dead:
		return -1
	if int(st.get("striking", 0)) > 0:
		st["striking"] = int(st["striking"]) - 1
		return F if int(st["striking"]) > 7 else 0
	if not h.is_grounded():
		return 0
	var rel: int = e.sim_pos.x - h.sim_pos.x
	var side: int = 1 if rel > 0 else -1
	var adx: int = absi(rel)
	var toward: int = R if side > 0 else L
	var away: int = L if side > 0 else R
	var airborne: bool = e.yvel != 0 or int(e.get("_state")) == 1
	if airborne:
		var coming: bool = signi(e.xvel) == -side
		if coming and adx < 84:
			return away
		return 0
	var est: int = int(e.get("_state"))
	var resting: bool = est == 2 and int(e.get("_timer")) > 6
	if est == 0:
		# still watching: step closer until it takes off (its trigger box is `range` tiles)
		if n % 3 == 0:
			return toward
		return 0
	if not resting and adx < 60:
		return away
	if not resting:
		return 0 if adx < 90 else toward
	if adx > 38:
		return toward
	if h.facing != side:
		return toward
	st["striking"] = 10
	return F


## Use the arch the hero stands on: hold Down until he was carried away (more than 64 px), then release.
func gate_fn() -> Callable:
	return func(lv: LevelBase, h: PlayerBase, n: int) -> int:
		var st: Dictionary = _st[h.slot]
		if n == 0:
			st["x0"] = h.sim_pos.x
			st["y0"] = h.sim_pos.y
		if int(st.get("after", -1)) >= 0:
			st["after"] = int(st["after"]) + 1
			return 0 if int(st["after"]) < 4 else -1
		if absi(h.sim_pos.x - int(st["x0"])) > 64 or absi(h.sim_pos.y - int(st["y0"])) > 64:
			st["after"] = 0
			return 0
		if n > 60:
			return -1
		return D


## Ambush a Guard from a hatch over its hall: wait (crouch-free, a tap of Down drops) until the Guard has just
## decided its facing and walks past under the hero with its back to him, then drop, turn to it and strike.
func ambush_fn(limit: int = 1500) -> Callable:
	return func(lv: LevelBase, h: PlayerBase, n: int) -> int:
		var st: Dictionary = _st[h.slot]
		if n > limit:
			return -1
		var g: Guard = st.get("g") as Guard if st.has("g") else null
		if g == null:
			g = nearest_enemy(h, "guard", 200, 120) as Guard
			if g == null:
				return -1
			st["g"] = g
		if g.dead:
			return -1
		var phase: int = int(st.get("phase", 0))
		var rel: int = g.sim_pos.x - h.sim_pos.x
		var side: int = 1 if rel > 0 else -1
		if phase == 0:
			# on the hatch: drop when its back faces us and its clock is young
			var clock: int = int(g.get("_turn_clock"))
			var shield: int = g.get_shield_dir()
			if shield == side and absi(rel) >= int(st.get("dmin", 6)) and absi(rel) <= 28 and clock <= int(st.get("cmax", 30)):
				st["phase"] = 1
				return D
			return 0
		if phase == 1:
			if not st.has("y0"):
				st["y0"] = h.sim_pos.y
			if h.sim_pos.y < int(st["y0"]) + 20:
				return D
			if not h.is_grounded():
				return 0
			st["phase"] = 2
		if int(st.get("striking", 0)) > 0:
			st["striking"] = int(st["striking"]) - 1
			return F if int(st["striking"]) > 7 else 0
		if not h.is_grounded():
			return 0
		var toward: int = R if side > 0 else L
		if h.facing != side:
			return toward
		if absi(rel) > 60:
			return toward
		st["striking"] = 10
		return F


## Wait until the swinger nearest to x `ax` is on the far side of its swing (its x beyond ax + `dx` * side, moving
## away), then end.
func swing_clear_fn(ax: int, side: int, dx: int = 24, limit: int = 200) -> Callable:
	return func(lv: LevelBase, h: PlayerBase, n: int) -> int:
		if n > limit:
			return -1
		var best: EnemyBase = null
		for entity: SimEntity in lv.get_kind(Defs.Kind.ENEMY):
			var foe: EnemyBase = entity as EnemyBase
			if foe == null or foe.dead or not (foe is Swinger):
				continue
			if best == null or absi(foe.sim_pos.x - ax) < absi(best.sim_pos.x - ax):
				best = foe
		if best == null or absi(best.sim_pos.x - ax) > 80:
			return -1
		var st: Dictionary = _st[h.slot]
		var px: int = int(st.get("px", best.sim_pos.x))
		st["px"] = best.sim_pos.x
		var moving: int = signi(best.sim_pos.x - px)
		if (best.sim_pos.x - ax) * side >= dx and moving == side:
			return -1
		return 0


## A vertical leap: Up alone for `straight` ticks (clear of a ledge's face overhead), then Up and the direction to
## `tx` until `up` ticks, then steering to `tx` until grounded.
func vleap_fn(tx: int, up: int = 12, straight: int = 6, limit: int = 120) -> Callable:
	return func(lv: LevelBase, h: PlayerBase, n: int) -> int:
		if n > limit or (n > 2 and h.is_grounded()):
			return -1
		var dx: int = tx - h.sim_pos.x
		var key: int = (R if dx > 3 else (L if dx < -3 else 0))
		if n < straight:
			return U
		if n < up:
			return U | key
		return key
