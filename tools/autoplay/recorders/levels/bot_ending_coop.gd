extends "res://tools/autoplay/recorders/db3/botlib.gd"
## The two-stream route of ending_coop (DB3; Expert only), recorded by probe_work.gd --bot --players=2. The walk home
## for two: P1 opens the spots, P2 follows; at the barred village gate P1 stands under the lookout gallery's end and P2
## Shoulder-Hops off his head onto it, steps on the latch plate (the gate rises), takes Cave Painting 29 and drops
## back to the road; both walk through the gate, P1 clubs the barrels and pots of the village, and both reach the
## exit totem (the team exit). Club only, no S.


func header() -> String:
	return "# route: level=ending_coop difficulty=expert players=2 ends=exit after=the_end expect=hurts:0,eggs:0,wipes:0,x2_gates:1,painting:29,min_checkpoints:3\n"


func p_past(slot: int, x: int) -> Callable:
	return func(_lv: LevelBase, _h: PlayerBase) -> bool:
		return hero(slot).sim_pos.x >= x


func strikes(prog: Array, extra: int, count: int, pause: int = 4) -> void:
	for i: int in count:
		prog.append(["strike", extra])
		prog.append(["wait", pause])


## The Shoulder Hop: from standing beside the partner, jump holding Up, steer onto his head, keep Up held through
## the bounce and drift onto the gallery (Right) until standing on it.
func hop_fn(land_dir: int, top_y: int) -> Callable:
	return func(_lv: LevelBase, h: PlayerBase, n: int) -> int:
		var st: Dictionary = _st[h.slot]
		var other: PlayerBase = hero(1 - h.slot)
		if n > 200:
			return -1
		if h.is_grounded() and n > 4:
			if h.sim_pos.y <= top_y:
				return -1
			if bool(st.get("bounced", false)):
				return -1
		if not h.is_grounded() and h.yvel < -150 and n > 6:
			st["bounced"] = true
		if bool(st.get("bounced", false)):
			return U | (R if land_dir > 0 else L)
		var dx: int = other.sim_pos.x - h.sim_pos.x
		var k: int = U
		if n < 3:
			k |= R if dx > 0 else L
		elif absi(dx) > 3 and h.yvel > 0:
			k |= R if dx > 0 else L
		return k


func build() -> Array:
	var p1: Array = []
	var p2: Array = []
	var near: Callable = func(x: int) -> Callable:
		return func(_lv: LevelBase, _h: PlayerBase) -> bool:
			return hero(0).sim_pos.x >= x and hero(0).is_grounded() and hero(0).xvel == 0
	# --- the path home: the inset tile, the berry hill, the first campfire, the bush (P2 trails P1 40 px behind)
	p1.append(["wait", 4])
	p1.append(["go", 158, {"tol": 1}])
	strikes(p1, D, 3)
	# levels (wf11): the road's two hidden spots lie at columns 33-34 since G70 (they lay under the tablet): two low
	# strikes each, standing at their left edge
	p1.append(["go", 526, {"tol": 1}])
	p1.append(["face", 1])
	strikes(p1, D, 2)
	p1.append(["go", 542, {"tol": 1}])
	p1.append(["face", 1])
	strikes(p1, D, 2)
	p1.append(["go", 572, {"tol": 1}])
	p1.append(["face", 1])
	strikes(p1, 0, 3, 6)
	p2.append(["trail", 0, -40, near.call(720), {}])
	# --- the barred gate: P1 under the gallery's end, P2 hops onto it (the latch plate) and takes painting 29
	p1.append(["go", 726, {"tol": 1}])
	p1.append(["face", -1])
	p1.append(["sync", "under"])
	p2.append(["go", 698, {"tol": 1}])
	p2.append(["sync", "under"])
	p2.append(["wait", 4])
	p2.append(["fn", hop_fn(1, 180)])
	p2.append(["mark", "on the gallery"])
	p2.append(["go", 872, {"tol": 2}])
	p2.append(["mark", "painting"])
	# the gate is up: P1 walks through to the campfire and the barrel; P2 walks back along the gallery and drops off
	p1.append(["until", func(lv: LevelBase, _h: PlayerBase) -> bool: return lv.get_cell(56, 18) == TileGrid.CH_AIR, 0])
	p1.append(["go", 990, {"tol": 2}])
	p1.append(["face", 1])
	strikes(p1, 0, 1, 10)
	p1.append(["sync", "down"])
	p2.append(["until", func(_lv: LevelBase, _h: PlayerBase) -> bool: return hero(0).sim_pos.x > 900, 0])
	p2.append(["go", 700, {"tol": 3}])
	p2.append(["until", func(_lv: LevelBase, h: PlayerBase) -> bool: return h.is_grounded() and h.sim_pos.y > 280, L])
	p2.append(["go", 940, {"tol": 3}])
	p2.append(["sync", "down"])
	# --- the village: the clay pot, then on to the exit totem with P2 trailing
	p1.append(["go", 1080, {"tol": 2}])
	p1.append(["face", 1])
	strikes(p1, 0, 1, 10)
	p1.append(["go", 1640, {"tol": 2}])
	p1.append(["face", 1])
	strikes(p1, 0, 1, 10)
	p1.append(["hold", R])
	p2.append(["trail", 0, -40, func(_lv: LevelBase, _h: PlayerBase) -> bool: return hero(0).sim_pos.x > 2150, {}])
	p2.append(["hold", R])
	return [p1, p2]
