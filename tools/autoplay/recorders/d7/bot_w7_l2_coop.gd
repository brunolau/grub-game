extends "res://tools/autoplay/recorders/d7/bot_w7_l1_coop.gd"
## The two-stream route of w7_l2_coop (D7): recorded by probe_work.gd --bot --players=2 (P1 | P2).
## P2 hops every floe line one floe behind P1 (a floe left within its 10-tick delay never sinks); gate 'seagate':
## P1 holds plate A (crouched), P2 hops the floes through the sea gate to plate B, P1 climbs the kelp vine to the
## driftwood bridge and passes its door; P1 fetches letter S up the blowhole while P2 waits; both drop down the shaft;
## floes to the islet; gate 'dark_gap': P1 curls at the islet's edge, P2 drives him over (Expert: a charged strike),
## P1 steps on the latch plate and the stepping stone rises for P2; checkpoint 4, the climb, the exit.


func header() -> String:
	var d: String = "expert" if expert else "beginner"
	return "# route: level=w7_l2_coop difficulty=%s players=2 ends=exit after=level:w7_l2b_coop expect=wipes:0,x2_gates:2,min_checkpoints:4,letters:4\n" % d


func build() -> Array:
	var fight: Dictionary = {"fight": true}
	var p1: Array = []
	var p2: Array = []
	p1.append(["mark", "cave mouth"])
	p1.append(["run", cx(30), fight])
	p2.append(["wait", 6])
	p2.append(["run", cx(27), fight])
	floes2(p1, p2, "c1", 35 * 16, [37, 42, 47, 52, 57], cx(62))
	# --- crossing 2 (both), then gate 'seagate': P1 holds plate A (crouched), P2 takes the lower tunnel to plate B,
	# P1 climbs the two shelves into the upper tunnel (letter S) and drops down beyond the wall ---
	floes2(p1, p2, "c2", 71 * 16, [73, 78, 83, 88], cx(92), 3)
	p1.append(["mark", "seagate"])
	# off the driftwood shelf the last hop may land on (cols 91-92, row 18) down to the floor, then back to plate A
	p1.append(["run", 94 * 16 + 4, {}])
	p1.append(["until", func(lv: LevelBase, h: PlayerBase) -> bool: return h.is_grounded() and h.sim_pos.y == 20 * 16, 0])
	# back to plate A only once P2 is off the floes (he hops when P1 is past the shelves)
	p1.append(["until", func(lv: LevelBase, h: PlayerBase) -> bool:
		var b: PlayerBase = hero(1)
		return b.is_grounded() and not b.on_platform and b.sim_pos.x >= 90 * 16, 0])
	p1.append(["go", 91 * 16 + 16, {"tol": 3}])
	p1.append(["sync", "on_a"])
	p1.append(["until", func(lv: LevelBase, h: PlayerBase) -> bool:
		var b: PlayerBase = hero(1)
		return b.is_grounded() and b.sim_pos.x >= 102 * 16 + 6 and b.sim_pos.y == 20 * 16, D])
	p1.append(["sync", "on_b"])
	p1.append(["fn", hop_fn(91 * 16 + 16, 7)])
	p1.append(["fn", hop_fn(93 * 16, 7)])
	p1.append(["until", column_risen(94, 2), 0])
	p1.append(["run", cx(101) + 2, {}])
	# down beyond the wall: on the floor or on the plate holder's head (he walks off it into the shaft next)
	p1.append(["until", func(lv: LevelBase, h: PlayerBase) -> bool: return h.is_grounded() and h.sim_pos.y >= 17 * 16, 0])
	p1.append(["sync", "seagate_done"])
	p2.append(["go", 93 * 16 + 8, {"tol": 3}])
	p2.append(["sync", "on_a"])
	p2.append(["until", column_risen(100, 2), 0])
	p2.append(["run", 102 * 16 + 4, {}])
	p2.append(["go", 102 * 16 + 16, {"tol": 3}])
	p2.append(["sync", "on_b"])
	p2.append(["until", func(lv: LevelBase, h: PlayerBase) -> bool:
		var a: PlayerBase = hero(0)
		return a.is_grounded() and a.sim_pos.x >= cx(101) and a.sim_pos.y >= 17 * 16, D])
	p2.append(["sync", "seagate_done"])
	# --- the shaft (P1 first, P2 when he landed) ---
	p1.append(["run", cx(106), {}])
	p1.append(["until", func(lv: LevelBase, h: PlayerBase) -> bool: return h.is_grounded() and h.sim_pos.y >= 46 * 16, 0])
	p1.append(["run", cx(112), fight])
	p2.append(["until", func(lv: LevelBase, h: PlayerBase) -> bool:
		var a: PlayerBase = hero(0)
		return a.is_grounded() and a.sim_pos.y >= 46 * 16 and a.sim_pos.x >= cx(109), 0])
	p2.append(["run", cx(106), {}])
	p2.append(["until", func(lv: LevelBase, h: PlayerBase) -> bool: return h.is_grounded() and h.sim_pos.y >= 46 * 16, 0])
	p2.append(["run", cx(110), fight])
	# P2 lands 12 px behind P1 (the islet is 4 cells; 24 px would put him on its left lip)
	floes2(p1, p2, "lake", 115 * 16, [117, 122, 127], cx(133) - 6, 7, 12)
	# --- gate 'dark_gap' ---
	var edge: int = 136 * 16 if not expert else 135 * 16
	p1.append(["mark", "dark gap"])
	p1.append(["go", edge - 8, {"tol": 1}])
	p1.append(["face", 1])
	p1.append(["sync", "bat_ready"])
	p1.append(["fn", curl_fn()])
	p1.append(["mark", "driven over"])
	p1.append(["go", 149 * 16 + 16, {"tol": 3}])
	p1.append(["wait", 30])
	p1.append(["sync", "stone_up"])
	p2.append(["until", func(lv: LevelBase, h: PlayerBase) -> bool:
		var a: PlayerBase = hero(0)
		return a.is_grounded() and absi(a.sim_pos.x - (edge - 8)) <= 1, 0])
	p2.append(["go", edge - 8 - 22, {"tol": 1}])
	p2.append(["face", 1])
	p2.append(["sync", "bat_ready"])
	p2.append(["wait", 3])
	p2.append(["fn", bat_fn(0, 20 if expert else 0)])
	p2.append(["sync", "stone_up"])
	p2.append(["until", column_risen(139, 3), 0])
	p2.append(["go", edge - 10, {"tol": 2}])
	p2.append(["fn", hop_fn(cx(139) + 8, 8)])
	p2.append(["fn", hop_fn(cx(145), 8)])
	# --- checkpoint 4, the climb (P2 a ledge behind), the exit ---
	p1.append(["run", cx(168), fight])
	p2.append(["run", cx(160), fight])
	for i: int in 8:
		var row: int = 43 - 3 * i
		var tx: int = cx(172) if i % 2 == 0 else cx(167)
		if row == 22:
			tx = cx(174)
		p1.append(["fn", wait_fight_fn(no_foe_near(56))])
		p1.append(["sync", "climb%d" % i])
		p1.append(["fn", hop_fn(tx, 10)])
		p2.append(["sync", "climb%d" % i])
		if i == 0:
			p2.append(["go", cx(168), fight])
		p2.append(["until", func(lv: LevelBase, h: PlayerBase) -> bool:
			var a: PlayerBase = hero(0)
			return a.is_grounded() and a.sim_pos.y <= row * 16, 0])
		var tx2: int = (cx(167) if i % 2 == 0 else cx(172)) if i > 0 else cx(168)
		if i > 0:
			p2.append(["fn", hop_fn(tx2, 10)])
	p2.append(["fn", hop_fn(cx(171), 10)])
	p1.append(["run", cx(190), fight])
	p1.append(["hold", R])
	p2.append(["run", cx(188), fight])
	p2.append(["hold", R])
	return [p1, p2]
