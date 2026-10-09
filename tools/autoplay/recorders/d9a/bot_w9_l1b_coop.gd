extends "res://tools/autoplay/recorders/d9a/bot_w9_l1b.gd"
## The two-stream Expert route of w9_l1b_coop Thunderhead Glide (D9a), recorded by probe_work.gd --bot --players=2:
## two gliders from the runway, the first crossing side by side (P2 a little behind and lower), both land on the
## landing cloud; P1 climbs to the high cloud of the painting while P2 flies under it; both land on the last cloud on
## either side of the first perched storm pterodactyl, stand 20 px beside one keeper each and strike on the same tick
## (gate 'stormwall'); through the risen door to the exit totem.


func header() -> String:
	return "# route: level=w9_l1b_coop difficulty=expert players=2 ends=exit after=tally expect=wipes:0,x2_gates:1,min_checkpoints:2\n" \
		+ "# The two-stream Expert route of Thunderhead Glide in co-op (designer D9a; recorded from closed-loop macros,\n" \
		+ "# build/d9a/bot_w9_l1b_coop.gd, P1|P2): two gliders off the runway and over the storm, both on the landing\n" \
		+ "# cloud; P1 by the high cloud of the painting, P2 under it; on the last cloud gate 'stormwall' (each hero\n" \
		+ "# high-strikes one perched keeper on the same tick), the door rises, the exit totem.\n"


func strike_keeper_fn(spot_x: int, face: int) -> Callable:
	return func(_lv: LevelBase, h: PlayerBase, n: int) -> int:
		var st: Dictionary = _st[h.slot]
		if n > 200:
			return -1
		if int(st.get("hold", 0)) > 0:
			st["hold"] = int(st["hold"]) - 1
			return (F | U) if int(st["hold"]) > 2 else 0
		if int(st.get("done", 0)) > 0:
			return -1
		if h.facing != face:
			return R if face > 0 else L
		st["hold"] = 9
		st["done"] = 1
		return F | U


func build() -> Array:
	var f: Dictionary = {"fight": true}
	var p1: Array = []
	var p2: Array = []
	# the runway: each takes a glider; P1 takes off first
	p1.append(["go", cx(10), f])
	p1.append(["go", cx(3), f])
	p1.append(["sync", "runway"])
	p1.append(["fn", takeoff_fn()])
	p1.append(["fn", fly_fn([[300, 120], [1300, 110], [1450, 130], [1560, 150]], 1, Vector2i(1640, 1860))])
	p1.append(["sync", "landing"])
	p2.append(["go", cx(12), f])
	p2.append(["go", cx(2), f])
	p2.append(["sync", "runway"])
	p2.append(["wait", 6])
	p2.append(["fn", takeoff_fn()])
	p2.append(["fn", fly_fn([[300, 140], [1300, 130], [1450, 140], [1560, 150]], 1, Vector2i(1570, 1620))])
	p2.append(["sync", "landing"])
	# the landing cloud: both run up and climb to the high cloud of the painting (P2 a few ticks behind), both run off
	# its edge at once (a hero standing in the storm is the next bolt's column) and fly on together; P1 lands left of
	# the first keeper and takes it, P2 flies high over it (P1 is then the nearer hero: it stays perched) to the second
	p1.append(["go", cx(98), f])
	p2.append(["go", cx(96), f])
	for p: Array in [p1, p2]:
		p.append(["sync", "runup2"])
	p2.append(["wait", 6])
	p1.append(["fn", takeoff_fn()])
	p1.append(["fn", fly_fn([[1750, 100], [2000, 10], [2170, 10]], 1, Vector2i(2186, 2250))])
	p1.append(["run", cx(143)])
	p1.append(["fn", fly_fn([[2300, 110], [2900, 120], [3050, 140]], 1, Vector2i(3070, 3150))])
	p1.append(["go", cx(197) - 4, {"tol": 2}])
	p1.append(["sync", "keepers"])
	p1.append(["fn", strike_keeper_fn(cx(197) - 4, 1)])
	p2.append(["fn", takeoff_fn()])
	p2.append(["fn", fly_fn([[1750, 100], [2000, 10], [2170, 10]], 1, Vector2i(2186, 2250))])
	p2.append(["run", cx(143)])
	p2.append(["fn", fly_fn([[2300, 110], [2900, 90], [3250, 80]], 1, Vector2i(3270, 3700))])
	p2.append(["go", cx(211) - 4, {"tol": 2}])
	p2.append(["sync", "keepers"])
	p2.append(["fn", strike_keeper_fn(cx(211) - 4, 1)])
	# through the door to the exit
	for p: Array in [p1, p2]:
		p.append(["wait", 40])
		p.append(["sync", "door"])
	p1.append(["go", cx(226), f])
	p1.append(["go", cx(239), f])
	p1.append(["hold", R])
	p2.append(["wait", 10])
	p2.append(["go", cx(236), f])
	p2.append(["hold", R])
	return [p1, p2]
