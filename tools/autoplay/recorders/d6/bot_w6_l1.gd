extends "res://tools/autoplay/recorders/d6/botlib_v1.gd"
## The club route of w6_l1 (D6): recorded by probe_work.gd --bot.

const F_ROW: int = 26
const FY: int = 26 * 16


func header() -> String:
	if expert:
		return "# route: level=w6_l1 difficulty=expert ends=exit after=tally expect=hurts:0,min_checkpoints:4,min_kills:10,letters:1\n"
	return "# route: level=w6_l1 difficulty=beginner ends=exit after=tally expect=hurts:0,min_checkpoints:4,min_kills:8,letters:1\n"


func raft_near(x: int) -> Raft:
	var best: Raft = null
	for kind: int in Defs.KIND_COUNT:
		for entity: SimEntity in level.get_kind(kind):
			var raft: Raft = entity as Raft
			if raft != null and (best == null or absi(raft.sim_pos.x - x) < absi(best.sim_pos.x - x)):
				best = raft
	return best


func mount() -> Mount:
	for kind: int in Defs.KIND_COUNT:
		for entity: SimEntity in level.get_kind(kind):
			if entity is Mount:
				return entity as Mount
	return null


## Paddle the raft under the hero (facing left: it goes right) until it rests at x >= `until_x` or stops at a bank.
func paddle_fn(until_x: int) -> Callable:
	return func(lv: LevelBase, h: PlayerBase, n: int) -> int:
		var raft: Raft = raft_near(h.sim_pos.x)
		if raft.sim_pos.x >= until_x:
			return -1
		var st: Dictionary = _st[h.slot]
		if bool(st.get("pressed", false)):
			st["pressed"] = false
			return 0
		if h.is_striking():
			return 0
		st["pressed"] = true
		return F


## Wait on the raft until it rests (no own speed, no drift) or `until_x` is reached.
func drift_fn(until_x: int) -> Callable:
	return func(lv: LevelBase, h: PlayerBase, n: int) -> int:
		var raft: Raft = raft_near(h.sim_pos.x)
		if raft.sim_pos.x >= until_x or (n > 20 and raft.cd == 0 and raft.rx == 0):
			return -1
		return 0


## Bounce on wild Chomper until he is tame and the hero sits on him (from the stump top).
func tame_fn() -> Callable:
	return func(lv: LevelBase, h: PlayerBase, n: int) -> int:
		if h.is_mounted():
			return -1
		if n > 900:
			return -1
		var rex: Mount = mount()
		var dx: int = rex.sim_pos.x - h.sim_pos.x
		if not h.is_grounded():
			var keys: int = U
			if dx > 2:
				keys |= R
			elif dx < -2:
				keys |= L
			return keys
		if dx < 56:
			return U | R
		return 0


## Ride Chomper right to `until_x`, hopping when a wall stops him. An enemy at his level ahead: stop, let it come (or
## creep up to a still one) and bite exactly when its near edge will be in the 11 px of the bite box that stick out of
## his body (29..40 px in front) on the bite's live ticks. An enemy above him close ahead: bite.
func ride_fn(until_x: int) -> Callable:
	return func(lv: LevelBase, h: PlayerBase, n: int) -> int:
		var rex: Mount = mount()
		if rex.sim_pos.x >= until_x or not h.is_mounted():
			return -1
		var st: Dictionary = _st[h.slot]
		var cool: int = int(st.get("bite_cool", 0))
		if cool > 0:
			st["bite_cool"] = cool - 1
		var vr: float = rex.xvel / 16.0
		var nearest: float = 9999.0
		var near_v: float = 0.0
		for entity: SimEntity in lv.get_kind(Defs.Kind.ENEMY):
			var foe: EnemyBase = entity as EnemyBase
			if foe == null or foe.dead or not foe.awake or not foe.tangible:
				continue
			var dy: float = foe.sim_pos.y - rex.sim_pos.y
			var left: float = foe.sim_pos.x - foe.box_xo - rex.sim_pos.x
			var vf: float = foe.xvel / 16.0
			if dy < -20.0 and dy > -60.0 and left > 0.0 and left < 60.0 and cool == 0:
				st["bite_cool"] = 8
				return R | F
			if dy < -20.0 or dy > 10.0 or left < 0.0:
				continue
			if left < nearest:
				nearest = left
				near_v = vf
		if nearest < 9000.0:
			var r4: float = nearest + (near_v - vr) * 4.0
			var r5: float = nearest + (near_v - vr) * 5.0
			if cool == 0 and ((r4 >= 20.0 and r4 < 40.0) or (r4 >= 40.0 and r5 >= 20.0 and r5 < 40.0)):
				st["bite_cool"] = 8
				return F
			if nearest < 90.0:
				# Wait for one that comes; creep up to one that does not (one tick of R in four).
				if near_v < -0.5:
					return 0
				if nearest > 60.0:
					return R
				return R if (n % 3 != 0 and nearest > 34.0) else 0
		var keys: int = R
		if rex.grounded and rex.xvel == 0 and n > 3 and n % 8 < 3:
			keys |= U
		return keys


func build() -> Array:
	var p: Array = []
	var fight: Dictionary = {"fight": true}
	p.append(["mark", "shore"])
	p.append(["run", cx(20), fight])
	p.append(["jump", 1, 8])
	p.append(["run", cx(40), fight])
	p.append(["mark", "pit"])
	p.append(["run", cx(46), fight])
	p.append(["go", cx(49), {"tol": 2}])
	p.append(["until", func(lv: LevelBase, h: PlayerBase) -> bool: return h.is_grounded() and h.sim_pos.y == FY - 16 \
			and h.sim_pos.x > 50 * 16, U])
	p.append(["run", cx(57), fight])
	p.append(["mark", "raft"])
	p.append(["run", 944])
	p.append(["keys", 2, R])
	p.append(["until", func(lv: LevelBase, h: PlayerBase) -> bool: return h.is_grounded() and h.xvel == 0, 0])
	p.append(["keys", 1, L])
	p.append(["fn", paddle_fn(1000)])
	p.append(["fn", drift_fn(99999)])
	p.append(["mark", "paddle"])
	p.append(["fn", paddle_fn(1318)])
	p.append(["run", cx(90)])
	p.append(["mark", "deck"])
	p.append(["run", cx(128), fight])
	p.append(["mark", "chomper"])
	p.append(["go", cx(135), fight])
	p.append(["leap", 2207, 10])
	p.append(["fn", tame_fn()])
	p.append(["mark", "riding"])
	p.append(["fn", ride_fn(cx(211))])
	p.append(["mark", "flats done"])
	p.append(["keys", 12, 0])
	p.append(["keys", 2, D | U])
	p.append(["until", func(lv: LevelBase, h: PlayerBase) -> bool: return h.is_grounded() and not h.is_mounted(), 0])
	p.append(["run", cx(229), fight])
	p.append(["hold", R])
	return [p]
