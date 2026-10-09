extends "res://tools/autoplay/recorders/d6/botlib_v4.gd"
## The two-stream route of w6_l2_coop (D6): recorded by probe_work.gd --bot --players=2.
## P1 is launched by the see-saw and unrolls the vine; P2 drops on the high end from the cap ledge and climbs the vine;
## at the drums P1 takes the floor drum and P2 the ledge drum; otherwise P2 follows P1's commands.


func header() -> String:
	if expert:
		return "# route: level=w6_l2_coop difficulty=expert players=2 ends=exit after=level:w6_l2b expect=wipes:0,x2_gates:2,min_checkpoints:4\n"
	return "# route: level=w6_l2_coop difficulty=beginner players=2 ends=exit after=level:w6_l2b expect=wipes:0,x2_gates:2,min_checkpoints:4\n"


func launch_fn(tx: int, wait_keys: int = 0) -> Callable:
	return func(lv: LevelBase, h: PlayerBase, n: int) -> int:
		var st: Dictionary = _st[h.slot]
		if n == 0:
			st["y0"] = h.sim_pos.y
		if not bool(st.get("up", false)):
			if h.yvel < -100 and not h.is_grounded():
				st["up"] = true
			else:
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


func spring_fn(sx: int, tx: int) -> Callable:
	return func(lv: LevelBase, h: PlayerBase, n: int) -> int:
		var st: Dictionary = _st[h.slot]
		if n == 0:
			st["y0"] = h.sim_pos.y
		if not bool(st.get("up", false)):
			if h.yvel < -150 and not h.is_grounded() and n > 3:
				st["up"] = true
			else:
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


## Strike the drum at `cell` (facing `dir`) when the partner is in place: a sync, then the same tick for both.
func vine_up(row: int) -> Callable:
	return func(lv: LevelBase, h: PlayerBase, n: int) -> int:
		if h.is_grounded() and h.sim_pos.y == row * 16 and n > 2:
			return -1
		if n > 800:
			return -1
		return U


## Cross the vent of a geyser (period, delay) at `vx` without being thrown up: wait short of it while it bubbles or
## is about to, then walk on to `to_x`.
func cross_vent_fn(vx: int, period: int, delay: int, to_x: int) -> Callable:
	return func(lv: LevelBase, h: PlayerBase, n: int) -> int:
		if h.sim_pos.x >= to_x:
			return -1
		if n > 600:
			return -1
		var p: int = posmod(Sim.tick - delay, period)
		var near: bool = h.sim_pos.x >= vx - 44 and h.sim_pos.x < vx - 16
		if near and p >= period - 34 - 14:
			return 0
		return R


func build() -> Array:
	var fight: Dictionary = {"fight": true}
	var p1: Array = []
	var p2: Array = []
	# --- gate 'seesaw' ---
	p1.append(["mark", "hall"])
	p1.append(["go", 476, fight])
	p1.append(["sync", "on_plank"])
	p1.append(["fn", launch_fn(566)])
	p1.append(["mark", "launched up"])
	p1.append(["go", 540, {"tol": 2}])
	p1.append(["face", -1])
	p1.append(["fn", open_vine_fn(Vector2i(32, 43), D)])
	p1.append(["sync", "vine_open"])
	p1.append(["sync", "both_up"])
	p2.append(["wait", 12])
	p2.append(["go", 280, fight])
	p2.append(["sync", "on_plank"])
	p2.append(["fn", spring_fn(312, 370)])
	p2.append(["go", 400, {"tol": 2}])
	p2.append(["run", 418])
	p2.append(["until", func(lv: LevelBase, hh: PlayerBase) -> bool: return hh.is_grounded() and hh.sim_pos.y >= 51 * 16, 0])
	p2.append(["sync", "vine_open"])
	p2.append(["go", 520, {"tol": 1}])
	p2.append(["fn", vine_up(43)])
	p2.append(["sync", "both_up"])
	# --- on to the drums (P2 follows P1 on the main path) ---
	var partner_past: Callable = func(x: int) -> Callable:
		return func(lv: LevelBase, hh: PlayerBase) -> bool:
			var other: PlayerBase = hero(1 - hh.slot)
			return other.sim_pos.x >= x and other.is_grounded()
	for slot: int in 2:
		var main: Array = []
		main.append(["mark", "upper passage"])
		main.append(["run", 950 - slot * 24, fight])
		if slot == 1:
			main.append(["until", partner_past.call(1150), 0])
		main.append(["go", 1096, fight])
		main.append(["fn", launch_fn(1150)])
		main.append(["run", 1340 - slot * 30, fight])
		main.append(["fn", cross_vent_fn(87 * 16 + 8, 88, 44, 1420)])
		main.append(["run", 1600, fight])
		if slot == 1:
			main.append(["until", partner_past.call(1760), 0])
		main.append(["go", 1620, {"tol": 3}])
		main.append(["leap", 1730, 6])
		main.append(["run", 2330 - slot * 30, fight])
		main.append(["mark", "lower hall"])
		if slot == 0:
			p1.append_array(main)
		else:
			p2.append(["wait", 30])
			p2.append_array(main)
	# --- gate 'caps' ---
	p1.append(["go", 2400, fight])
	p1.append(["face", 1])
	p1.append(["sync", "drums"])
	p1.append(["strike", 0])
	p1.append(["wait", 60])
	p1.append(["run", 2720, fight])
	p1.append(["hold", R])
	p2.append(["go", 2530, fight])
	p2.append(["fn", spring_fn(2568, 2640)])
	p2.append(["go", 2656, {"tol": 2}])
	p2.append(["face", 1])
	p2.append(["sync", "drums"])
	p2.append(["strike", 0])
	p2.append(["wait", 60])
	p2.append(["run", 2760, fight])
	p2.append(["hold", R])
	return [p1, p2]


## Strike (with `extra`, e.g. D for a low strike) until the rolled vine anchored in `cell` is unrolled.
func open_vine_fn(cell: Vector2i, extra: int = 0) -> Callable:
	return func(lv: LevelBase, h: PlayerBase, n: int) -> int:
		for kind: int in Defs.KIND_COUNT:
			for entity: SimEntity in lv.get_kind(kind):
				var vine: Vine = entity as Vine
				if vine != null and vine.vine_x >> 4 == cell.x and not vine.rolled:
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
