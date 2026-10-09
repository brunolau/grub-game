extends "res://tools/autoplay/recorders/d9a/botlib.gd"
## The two-stream Expert route of w9_l1_coop Cloudbreak Climb (D9a), recorded by probe_work.gd --bot --players=2.
## P1 rides the see-saw up to the high cloud T and unrolls its vine; P2 drops on the high end from the drop ledge D
## and climbs. At the pulley P1 rides lift B while P2 weighs down lift A, then P1 unrolls the shaft's vine from the slate
## block and P2 jumps to it. Elsewhere both climb the same way, P2 a little behind; drop clouds are taken one hero at a
## time (P2 waits until they are home again); no hero stands 243 ticks without input.


func header() -> String:
	return "# route: level=w9_l1_coop difficulty=expert players=2 ends=exit after=level:w9_l1b_coop expect=wipes:0,x2_gates:2,min_checkpoints:5\n" \
		+ "# The two-stream Expert route of Cloudbreak Climb in co-op (designer D9a; recorded from closed-loop macros,\n" \
		+ "# build/d9a/bot_w9_l1_coop.gd, P1|P2): the climb to shelf S side by side; gate 'seesaw' (P1 on the low end, P2\n" \
		+ "# off the drop ledge onto the high end: P1 flies up to the high cloud and strikes the coil, P2 climbs); gate\n" \
		+ "# 'pulley' (P2 on lift A, P1 hops lift B up and jumps onto the slate block, strikes the coil, P2 jumps to the\n" \
		+ "# vine); the drop clouds one hero at a time; the vine, the geyser and the stair to the exit totem.\n"


func on_ground() -> Callable:
	return func(_lv: LevelBase, hh: PlayerBase) -> bool: return hh.is_grounded()


## Strike (with `extra` keys) whenever grounded and not striking until the rolled vine at column `col` hangs.
func unroll_fn(col: int, extra: int = 0) -> Callable:
	return func(lv: LevelBase, h: PlayerBase, n: int) -> int:
		for entity: SimEntity in lv.get_kind(Defs.Kind.HITTABLE):
			var vine: Vine = entity as Vine
			if vine != null and vine.vine_x == cx(col) and vine.unrolled:
				return -1
		if n > 400:
			return -1
		var st: Dictionary = _st[h.slot]
		if int(st.get("hold", 0)) > 0:
			st["hold"] = int(st["hold"]) - 1
			return (F | extra) if int(st["hold"]) > 2 else 0
		if not h.is_grounded() or h.is_striking():
			return 0
		st["hold"] = 9
		return F | extra


func hop_ticks() -> int:
	return 8


func pause_ticks() -> int:
	return 0


## Pulley rider: on lift B, hop (in the air the loaded lift A sinks and B rises) until B is `rows` up, then -1.
func ride_lift_fn(lift_name: StringName, rows: int) -> Callable:
	return func(lv: LevelBase, h: PlayerBase, n: int) -> int:
		var lift: SimEntity = lv.find_named(lift_name)
		var st: Dictionary = _st[h.slot]
		if not st.has("y0"):
			st["y0"] = lift.sim_pos.y
		if h.is_grounded() and lift.sim_pos.y <= int(st["y0"]) - rows * 16 + 2:
			return -1
		if n > 900:
			return -1
		# hops (Up held hop_ticks()) after a pause of pause_ticks() on the lift: it rises under a hero in the air
		if int(st.get("hop", 0)) > 0:
			st["hop"] = int(st["hop"]) - 1
			return U
		if h.is_grounded():
			st["still"] = int(st.get("still", 0)) + 1
			if h.no_jump == 0 and int(st["still"]) > pause_ticks():
				st["still"] = 0
				st["hop"] = hop_ticks() - 1
				return U
			return 0
		st["still"] = 0
		return 0


func climb_to_s5(p: Array, slot: int) -> void:
	var f: Dictionary = {"fight": true}
	var hs: Dictionary = {"fight": true, "safe": [110, 120]}
	# S1: the geyser, the ledge, the drop clouds (one hero at a time), the shelf
	if slot == 1:
		p.append(["wait", 20])
	p.append(["go", cx(27) + (6 if slot == 0 else -6), f])
	p.append(["clear", 140, 300])
	p.append(["ride", cx(27) + (6 if slot == 0 else -6), cx(31) + (4 if slot == 0 else -6), f])
	p.append(["go", cx(35) + (4 if slot == 0 else -6), f])
	p.append(["clear", 140, 300])
	p.append(["sync", "s1_ledge"])
	if slot == 1:
		p.append(["wait", 10])
	p.append(["hop", cx(39), 9])
	p.append(["hop", cx(44), 9])
	p.append(["hop", cx(50) + (0 if slot == 0 else -6), 9])
	p.append(["go", cx(51) if slot == 0 else cx(49), f])
	p.append(["sync", "s1_shelf"])
	# S2: the vine through B2 (P1 first)
	if slot == 0:
		p.append(["go", cx(52), f])
		p.append(["face", -1])
		p.append(["climb", 119])
		p.append(["go", cx(46), f])
		p.append(["sync", "b2"])
	else:
		p.append(["wait", 40])
		p.append(["go", cx(52), f])
		p.append(["face", -1])
		p.append(["climb", 119])
		p.append(["go", cx(48), f])
		p.append(["sync", "b2"])
	# B2 -> the stair -> B3
	p.append(["wait", 0 if slot == 0 else 30])
	p.append(["go", cx(30) + (0 if slot == 0 else 2), f])
	p.append(["clear", 140, 300])
	p.append(["hop", cx(27), 9, hs])
	p.append(["clear", 140, 300])
	p.append(["hop", cx(31), 9, hs])
	p.append(["clear", 140, 300])
	p.append(["hop", cx(27), 9, hs])
	p.append(["clear", 140, 300])
	p.append(["hop", cx(31), 9, hs])
	p.append(["go", cx(33), f])
	p.append(["clear", 140, 300])
	p.append(["hop", cx(38) + (0 if slot == 0 else -4), 9, hs])
	# B3 -> the vine to S (P1 first)
	p.append(["go", cx(53) + (0 if slot == 0 else -2), f])
	p.append(["clear", 140, 300])
	p.append(["sync", "b3"])
	if slot == 1:
		p.append(["wait", 40])
	p.append(["go", cx(57), f])
	p.append(["face", -1])
	p.append(["climb", 93])


func build() -> Array:
	var f: Dictionary = {"fight": true}
	var hs: Dictionary = {"fight": true, "safe": [110, 120]}
	var p1: Array = []
	var p2: Array = []
	climb_to_s5(p1, 0)
	climb_to_s5(p2, 1)
	# --- gate 'seesaw': P1 on the low end, P2 up the geyser to D and off its left edge onto the high end ---
	p1.append(["go", cx(45), f])
	p1.append(["go", cx(40) + 4, {"tol": 2}])
	p1.append(["sync", "seesaw_ready"])
	p1.append(["fn", func(_lv: LevelBase, h: PlayerBase, n: int) -> int:
		var st: Dictionary = _st[h.slot]
		if not bool(st.get("up", false)):
			if h.yvel < -120 and not h.is_grounded():
				st["up"] = true
			else:
				return D if n % 80 == 79 else 0
		if h.is_grounded() and h.sim_pos.y <= 84 * 16:
			return -1
		if n > 800:
			return -1
		return L if h.sim_pos.x > cx(31) else 0])
	p1.append(["go", cx(11), f])
	p1.append(["face", -1])
	p1.append(["fn", unroll_fn(10)])
	p1.append(["sync", "seesaw_vine"])
	p1.append(["go", cx(14), f])
	p1.append(["sync", "seesaw_done"])
	p2.append(["go", cx(53), f])
	p2.append(["sync", "seesaw_ready"])
	p2.append(["go", cx(55), {"tol": 2}])
	p2.append(["ride", cx(55), cx(52), f])
	p2.append(["go", cx(46), {"tol": 2}])
	p2.append(["until", func(_lv: LevelBase, hh: PlayerBase) -> bool:
		return not hh.is_grounded() and hh.sim_pos.y > 87 * 16 + 8, L])
	p2.append(["until", on_ground(), 0])
	# under the rolled vine while P1 crosses T (the shared view keeps the two within one screen)
	p2.append(["go", cx(13), f])
	p2.append(["sync", "seesaw_vine"])
	p2.append(["go", cx(10), f])
	p2.append(["climb", 84])
	p2.append(["go", cx(9), f])
	p2.append(["sync", "seesaw_done"])
	# --- T -> the geyser -> two ledges -> shelf F (P1 first, P2 on the next spout) ---
	for slot: int in 2:
		var p: Array = p1 if slot == 0 else p2
		if slot == 1:
			p.append(["until", partner_up(78), 0])
		p.append(["go", cx(13), f])
		p.append(["clear", 140, 300])
		p.append(["ride", cx(13), cx(15), f])
		p.append(["go", cx(16), f])
		p.append(["clear", 140, 300])
		p.append(["hop", cx(21), 9, hs])
		p.append(["go", cx(22), f])
		p.append(["clear", 140, 300])
		p.append(["hop", cx(27) + (0 if slot == 0 else 6), 9, hs])
	# --- gate 'pulley': P1 onto lift B at the shaft, P2 onto lift A; P1 hops B up 6 rows, jumps onto the slate block,
	# strikes the coil; P2 jumps to the vine ---
	# both stand one step from their lift and step on together (a lone load would send the other lift away)
	p1.append(["hop", cx(34), 9, {"lead": 2}])
	p1.append(["go", cx(44), f])
	p1.append(["go", cx(47), {"tol": 2}])
	p1.append(["face", 1])
	p1.append(["sync", "lifts"])
	p1.append(["go", cx(49), {"tol": 2}])
	p1.append(["sync", "on_lifts"])
	p1.append(["fn", ride_lift_fn(&"lift_b", 3)])
	# straight up onto the cloud ledge in the shaft, then up-left onto the slate block
	p1.append(["hop", cx(49) + 8, 9])
	p1.append(["until", func(_lv: LevelBase, hh: PlayerBase) -> bool: return hh.is_grounded(), 0])
	p1.append(["hop", cx(46), 9, {"lead": 2}])
	p1.append(["go", cx(47), {"tol": 2}])
	p1.append(["face", 1])
	p1.append(["fn", unroll_fn(48)])
	p1.append(["go", cx(44), f])
	p1.append(["sync", "pulley_vine"])
	p1.append(["sync", "pulley_done"])
	# over lift A's slot (a lone hero on A sinks with it through the shelf), then one step right of it
	p2.append(["hop", cx(34), 9, {"lead": 2}])
	p2.append(["go", cx(32), {"tol": 2}])
	p2.append(["face", -1])
	p2.append(["sync", "lifts"])
	p2.append(["go", cx(30), {"tol": 2}])
	p2.append(["sync", "on_lifts"])
	# P1 on the ledge: out of the slot onto the shelf at once (the view must hold both)
	p2.append(wait_until(func(_lv: LevelBase, _hh: PlayerBase) -> bool:
		var other: PlayerBase = hero(0)
		return other.is_grounded() and other.sim_pos.y <= 66 * 16 + 1, 600))
	p2.append(["until", func(_lv: LevelBase, hh: PlayerBase) -> bool: return hh.is_grounded(), 0])
	p2.append(["hop", cx(33), 9])
	p2.append(wait_until(func(lv: LevelBase, _hh: PlayerBase) -> bool:
		for entity: SimEntity in lv.get_kind(Defs.Kind.HITTABLE):
			var vine: Vine = entity as Vine
			if vine != null and vine.vine_x == cx(48) and vine.unrolled:
				return true
		return false))
	p2.append(["sync", "pulley_vine"])
	p2.append(["go", cx(46), f])
	p2.append(["until", func(_lv: LevelBase, hh: PlayerBase) -> bool: return hh.state == Defs.HeroState.CLIMB, R | U])
	p2.append(["climb", 63])
	p2.append(["go", cx(46), f])
	p2.append(["sync", "pulley_done"])
	# --- the ledges to CP4, the drop clouds (P1 first, P2 once they are home), the vine, the geyser, the exit ---
	for slot: int in 2:
		var p: Array = p1 if slot == 0 else p2
		if slot == 1:
			p.append(["wait", 30])
		p.append(["go", cx(45), f])
		p.append(["clear", 140, 300])
		p.append(["hop", cx(44), 9, hs])
		p.append(["go", cx(43) + 2, f])
		p.append(["clear", 140, 300])
		p.append(["hop", cx(40), 9, hs])
		p.append(["go", cx(38) + 4, f])
		p.append(["clear", 140, 300])
		p.append(["hop", cx(35), 9, hs])
		p.append(["go", cx(20) + (0 if slot == 0 else 20), f])
		p.append(["clear", 140, 300])
		# side by side up the drop clouds and their co-op twins (P1 the left one of each pair)
		if slot == 1:
			p.append(["go", cx(21), f])
		p.append(["sync", "s9"])
		var twin: int = 0 if slot == 0 else 2
		p.append(["hop", cx(17 + twin), 9])
		p.append(["sync", "s9a"])
		p.append(["hop", cx(13 + twin), 9])
		p.append(["sync", "s9b"])
		p.append(["hop", cx(9 + twin), 9])
		p.append(["sync", "s9c"])
		p.append(["hop", cx(5 + twin / 2), 9])
		if slot == 0:
			p.append(["go", cx(6), f])
			p.append(["sync", "b5"])
		else:
			p.append(["go", cx(5), f])
			p.append(["sync", "b5"])
			p.append(["wait", 40])
		p.append(["go", cx(4), f])
		p.append(["face", 1])
		p.append(["climb", 30])
		p.append(["go", cx(26) + (6 if slot == 0 else -6), f])
		p.append(["clear", 140, 300])
		if slot == 0:
			p.append(["sync", "cp5"])
		else:
			p.append(["sync", "cp5"])
		p.append(["ride", cx(26) + (6 if slot == 0 else -6), cx(30) + (2 if slot == 0 else -2), f])
		p.append(["go", cx(33) - (0 if slot == 0 else 4), f])
		p.append(["clear", 140, 300])
		p.append(["hop", cx(37), 9, hs])
		p.append(["go", cx(38), f])
		p.append(["clear", 140, 300])
		p.append(["hop", cx(42), 9, hs])
		p.append(["go", cx(43), f])
		p.append(["clear", 140, 300])
		p.append(["hop", cx(47), 9, hs])
		p.append(["go", cx(54), f])
		p.append(["hold", R])
	return [p1, p2]
