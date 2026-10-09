extends "res://tools/autoplay/recorders/d8/d8lib.gd"
## D8's co-op helpers over d8lib (development only): fidgeting so no hero dozes, the Raptor pincer, the heave boulder,
## crouching on a plate, leaving the other hero room.

## Stay put for `ticks`, tapping Down every 60 ticks (input: an idle hero stops counting after 243 quiet ticks).
func fidget_fn(ticks: int) -> Callable:
	return func(lv: LevelBase, h: PlayerBase, n: int) -> int:
		if n >= ticks:
			return -1
		return K if n % 60 == 30 else 0


## Idle (tapping Down every 60 ticks) until `cond(level, hero)` holds, at most `limit` ticks.
func wait_for(cond: Callable, limit: int = 2000) -> Callable:
	return func(lv: LevelBase, h: PlayerBase, n: int) -> int:
		if cond.call(lv, h) or n > limit:
			return -1
		return K if n % 60 == 30 else 0


## Crouch (Down held: the plate counts him, and Down is input) until `cond(level, hero)` holds.
func crouch_until(cond: Callable, limit: int = 3000) -> Callable:
	return func(lv: LevelBase, h: PlayerBase, n: int) -> int:
		if cond.call(lv, h) or n > limit:
			return -1
		return D


## The other hero (two-hero party).
func other(h: PlayerBase) -> PlayerBase:
	return hero(1 - h.slot)


## The Raptor nearest (within 240 px across, 64 px up or down): the bouncer runs at it and lands on its head; the
## striker keeps 40-60 px off and strikes while it is dazed (only a hero other than the bouncer hurts it). Ends when
## it is dead.
func raptor_fn(bouncer: bool, limit: int = 1200) -> Callable:
	return func(lv: LevelBase, h: PlayerBase, n: int) -> int:
		var st: Dictionary = _st[h.slot]
		if n > limit:
			return -1
		var r: EnemyBase = null
		for entity: SimEntity in lv.get_kind(Defs.Kind.ENEMY):
			var foe: EnemyBase = entity as EnemyBase
			if foe != null and not foe.dead and foe is Raptor and absi(foe.sim_pos.x - h.sim_pos.x) < 240 \
					and absi(foe.sim_pos.y - h.sim_pos.y) < 64:
				if r == null or absi(foe.sim_pos.x - h.sim_pos.x) < absi(r.sim_pos.x - h.sim_pos.x):
					r = foe
		if r == null:
			return -1
		var dazed: bool = r._traits != null and r._traits.dazed > 0
		var rel: int = r.sim_pos.x - h.sim_pos.x
		var side: int = 1 if rel > 0 else -1
		var toward: int = R if side > 0 else L
		var away: int = L if side > 0 else R
		if int(st.get("striking", 0)) > 0:
			st["striking"] = int(st["striking"]) - 1
			return F if int(st["striking"]) > 7 else 0
		if bouncer:
			if int(st.get("jumping", 0)) > 0:
				st["jumping"] = int(st["jumping"]) + 1
				if h.is_grounded() and int(st["jumping"]) > 4:
					st["jumping"] = 0
					return 0
				var steer: int = toward if absi(rel) > 3 else 0
				return (U | steer) if int(st["jumping"]) <= 6 else (U | steer if h.yvel > 0 else steer)
			if not h.is_grounded():
				return 0
			if dazed:
				return away if absi(rel) < 36 else 0
			var airborne: bool = r.yvel != 0
			if not airborne and absi(rel) <= 44 and absi(rel) >= 18:
				st["jumping"] = 1
				return U | toward
			if absi(rel) < 18:
				return away
			return toward if n % 2 == 0 else 0
		if not h.is_grounded():
			return 0
		if dazed:
			if absi(rel) > 34:
				return toward
			if h.facing != side:
				return toward
			st["striking"] = 10
			return F
		if absi(rel) < 50:
			return away
		if absi(rel) > 58:
			return toward if n % 2 == 0 else 0
		return K if n % 60 == 30 else 0


var _boulder: HeavyBoulder = null


## Push the heave boulder to the right (dir 1) or left until its left cell reaches column `col`.
func push_fn(col: int, dir: int = 1, limit: int = 600) -> Callable:
	return func(lv: LevelBase, h: PlayerBase, n: int) -> int:
		if n > limit:
			return -1
		if _boulder == null or not is_instance_valid(_boulder):
			for node: Node in lv.find_children("*", "", true, false):
				if node is HeavyBoulder:
					_boulder = node as HeavyBoulder
		if _boulder == null:
			return -1
		if (dir > 0 and _boulder.block.position.x >= col) or (dir < 0 and _boulder.block.position.x <= col):
			return -1
		return R if dir > 0 else L


## Walk to x with `go`, but never closer than `gap` px behind the other hero in the walking direction.
func follow_fn(x: int, gap: int = 28, limit: int = 1500) -> Callable:
	return func(lv: LevelBase, h: PlayerBase, n: int) -> int:
		if n > limit:
			return -1
		var o: PlayerBase = other(h)
		var dx: int = x - h.sim_pos.x
		if absi(dx) <= 3 and h.xvel == 0 and h.is_grounded():
			return -1
		var dir: int = signi(dx)
		if o != null and (o.sim_pos.x - h.sim_pos.x) * dir > 0 and absi(o.sim_pos.x - h.sim_pos.x) < gap \
				and absi(o.sim_pos.y - h.sim_pos.y) < 24:
			return 0
		var speed: int = absi(h.xvel)
		var stop: int = (speed * speed) / (2 * 12 * 16) + 2
		if h.xvel != 0 and signi(h.xvel) == dir and absi(dx) <= stop:
			return 0
		return R if dir > 0 else L


## A leech riding a hero: the other walks to it and strikes it off. -1 at once when no leech rides anybody.
func unleech_fn(limit: int = 300) -> Callable:
	return func(lv: LevelBase, h: PlayerBase, n: int) -> int:
		var st: Dictionary = _st[h.slot]
		if n > limit:
			return -1
		if int(st.get("striking", 0)) > 0:
			st["striking"] = int(st["striking"]) - 1
			return F if int(st["striking"]) > 7 else 0
		var leech: EnemyBase = null
		for entity: SimEntity in lv.get_kind(Defs.Kind.ENEMY):
			var foe: EnemyBase = entity as EnemyBase
			if foe != null and not foe.dead and foe._traits != null and foe._traits.host != null:
				leech = foe
		if leech == null:
			return -1
		if leech._traits.host == h:
			return K if n % 30 == 15 else 0
		var rel: int = leech.sim_pos.x - h.sim_pos.x
		var side: int = 1 if rel > 0 else -1
		if not h.is_grounded():
			return 0
		if absi(rel) > 26:
			return R if side > 0 else L
		if absi(rel) < 10:
			return L if side > 0 else R
		if h.facing != side:
			return R if side > 0 else L
		st["striking"] = 10
		return F
