extends "res://tools/autoplay/recorders/d9a/bot_w9_l2.gd"
## The two-stream Expert route of w9_l2_coop The Roc's Spire (D9a), recorded by probe_work.gd --bot --players=2:
## both heroes cross the gust gaps in the lulls (P2 a few cells behind), the drop clouds one at a time; the two Bull
## Rex halls by a Brace Wall (both crouch side by side at the hall's mouth, then both strike the dazed head); the
## levels (wf11) copy of D9a's bot: the final gap is 13 cells wide and begins at column 203 (its lip is column 202).
## final gap by a charged Batter Up line drive (P2 curls at the edge, P1 crouches to charge and strikes him across),
## P2 steps on the latch plate and the slab sinks into a bridge for P1.


func header() -> String:
	return "# route: level=w9_l2_coop difficulty=expert players=2 ends=exit after=level:w9_l2b_coop expect=wipes:0,x2_gates:2,min_checkpoints:5\n" \
		+ "# The two-stream Expert route of The Roc's Spire in co-op (designer D9a; recorded from closed-loop macros,\n" \
		+ "# build/d9a/bot_w9_l2_coop.gd, P1|P2): the gust gaps in the lulls, the drop clouds one hero at a time, gates\n" \
		+ "# 'brace' (both step into the sunken hall while its Bull Rex sleeps; a Brace Wall stops its charge and both\n" \
		+ "# strike its dazed head), the cloud hall's tribesman and Roller,\n" \
		+ "# gate 'drive' (P2 curls at the edge, P1 charges and bats him across; P2's latch plate sinks the slab bridge).\n"


var _brace_go: Dictionary = {}


func brace_fn(wait_x: int, stand_x: int, rex_hint: int) -> Callable:
	## The Brace Wall at a sunken hall's mouth: wait at wait_x on the higher floor outside the hall (the Bull Rex
	## turns at the step and cannot reach it), crouching while it runs about; once both heroes wait there and the Rex
	## runs away from the mouth (or turns at the far wall), drop in together to stand_x and crouch side by side until
	## it is dazed against them; then strike its open head until it falls.
	return func(lv: LevelBase, h: PlayerBase, n: int) -> int:
		if n > 2400:
			return -1
		var rex: EnemyBase = null
		for entity: SimEntity in lv.get_kind(Defs.Kind.ENEMY):
			var foe: EnemyBase = entity as EnemyBase
			if foe != null and not foe.dead and foe is BullRex and absi(foe.sim_pos.x - rex_hint) < 220:
				rex = foe
		if rex == null:
			return -1
		var st: Dictionary = _st[h.slot]
		var key: int = rex_hint
		var trs: CoopTraits = rex.get(&"_traits") as CoopTraits
		var dazed: bool = trs != null and trs.dazed > 0
		if not bool(_brace_go.get(key, false)):
			# waiting outside
			if absi(h.sim_pos.x - wait_x) > 3:
				return R if wait_x > h.sim_pos.x else L
			if not h.is_grounded():
				return 0
			if h.facing < 0:
				return R
			st["ready"] = key
			var both: bool = true
			for other: PlayerBase in lv.heroes:
				if int(_st[other.slot].get("ready", -1)) != key:
					both = false
			var away: bool = not rex.awake or (rex.facing > 0 and rex.sim_pos.x - stand_x > 60)
			if both and away:
				_brace_go[key] = true
				return R
			return D if n % 30 < 2 else 0
		if dazed:
			if not h.is_grounded():
				return 0
			if int(st.get("hold", 0)) > 0:
				st["hold"] = int(st["hold"]) - 1
				return F if int(st["hold"]) > 2 else 0
			if not h.is_striking():
				st["hold"] = 9
				return F
			return 0
		if absi(h.sim_pos.x - stand_x) > 3 and not bool(st.get("placed%d" % key, false)):
			return R if stand_x > h.sim_pos.x else L
		if not h.is_grounded():
			return 0
		st["placed%d" % key] = true
		if h.facing < 0:
			return R
		return D


func build() -> Array:
	var p1: Array = []
	var p2: Array = []
	for slot: int in 2:
		var p: Array = p1 if slot == 0 else p2
		var off: int = 0 if slot == 0 else -20
		if slot == 1:
			p.append(["wait", 24])
		# A: two gust gaps (P2 jumps the gap in the next lull after P1), the leaper, checkpoint 1
		gust_gap(p, 13, 18)
		if slot == 1:
			p.append(["until", partner_past(cx(30)), 0])
		gust_gap(p, 28, 33)
		p.append(["trek", cx(43) + off])
		# B: the tar lake: both at the edge, the same lull, P2 ten ticks behind on the same drop clouds (they crumble
		# after 24 ticks in co-op); both crouch on the slate stack through the gust
		p.append(["trek", cx(46) - 10 + off])
		p.append(["go", cx(46) + 1 + (0 if slot == 0 else -14), {"fight": true, "tol": 2}])
		p.append(["sync", "lake"])
		if slot == 1:
			# one hero at a time on the drop clouds (a hero landing on his partner's shoulders halves the carrier's
			# next jump): P2 crouches at the edge until P1 stands on the slate stack, then takes the next lull
			p.append(wait_until(partner_past(cx(60))))
		p.append(["lull", 70, LULL])
		p.append(["hop", cx(50), 9])
		p.append(["hop", cx(55), 9])
		p.append(["hop", cx(61) + (6 if slot == 0 else -8), 9])
		p.append(["sync", "stack"])
		if slot == 1:
			p.append(wait_until(partner_past(cx(78))))
		p.append(["lull", 70, LULL])
		p.append(["hop", cx(67), 9])
		p.append(["hop", cx(72), 9])
		p.append(["hop", cx(78) + off, 9])
		if slot == 0:
			p.append(["trek", cx(82)])
		p.append(["sync", "bank"])
		# C: the pocket, up onto the lower terrace; gate 'brace' at the mouth of the sunken hall
		p.append(["trek", cx(92) + off])
		if slot == 1:
			p.append(wait_until(partner_past(cx(95))))
		p.append(["hop", cx(93) + 4, 4])
		p.append(["hop", cx(96) if slot == 0 else cx(95), 9])
		p.append(["sync", "hall1_mouth"])
		p.append(["fn", brace_fn(cx(96) if slot == 0 else cx(95), cx(98) - 2 + (6 if slot == 0 else -6), cx(112))])
		p.append(["sync", "hall1_done"])
		p.append(["trek", cx(113) + (0 if slot == 0 else -10)])
		p.append(["hop", cx(117) + (off / 2), 9])
		p.append(["hop", cx(121) + off, 9])
		p.append(["trek", cx(128) + off])
		p.append(["sync", "cp3"])
		# D: the Roller valley, the cloud bridge between two gust gaps, checkpoint 4
		if slot == 1:
			p.append(["wait", 20])
		gust_gap(p, 154, 159)
		if slot == 1:
			p.append(["until", partner_past(cx(167)), 0])
		p.append(["go", cx(163), {"fight": true, "tol": 2}])
		p.append(["lull", 40, LULL])
		p.append(["hop", cx(168), 9])
		p.append(["trek", cx(171) + off])
		p.append(["sync", "cp4"])
		# E: the last gust gap, the painting's big spot (P1), gate 'hall'
		if slot == 1:
			p.append(["wait", 20])
		gust_gap(p, 178, 183)
		if slot == 0:
			p.append(["go", cx(186), {"fight": true, "tol": 1}])
			for i: int in 3:
				p.append(["keys", 8, U | F])
				p.append(["wait", 16])
			p.append(["wait", 50])
			p.append(["go", cx(182), {"tol": 2}])
			p.append(["hop", cx(185), 9])
			p.append(["go", cx(188), {"tol": 2}])
			p.append(["go", cx(191), {}])
		else:
			p.append(["until", partner_past(cx(191)), 0])
			p.append(["go", cx(190) - 4, {}])
		p.append(["sync", "hall2_mouth"])
		# the cloud hall: its tribesman and Roller, P1 ahead
		if slot == 1:
			p.append(["wait", 30])
		p.append(["trek", cx(199) + off])
	# gate 'drive': P2 curls at the edge, P1 charges and bats him across, P2 presses the latch plate, P1 crosses
	p2.append(["go", cx(202) + 4, {"tol": 1}])
	p2.append(["face", 1])
	p2.append(["sync", "curl_spot"])
	p2.append(["keys", 2, D | S])
	p2.append(["until", func(_lv: LevelBase, hh: PlayerBase) -> bool: return not hh.is_grounded(), D])
	p2.append(["until", func(_lv: LevelBase, hh: PlayerBase) -> bool: return hh.is_grounded() and hh.sim_pos.x >= 216 * 16, 0])
	p2.append(["trek", cx(223) + 2])
	p2.append(wait_until(partner_past(cx(222))))
	p2.append(["go", cx(228), {}])
	p2.append(["hold", R])
	p1.append(["go", cx(201) + 6, {"tol": 1}])
	p1.append(["face", 1])
	p1.append(["keys", 10, D])
	p1.append(["sync", "curl_spot"])
	p1.append(["keys", 3, D])
	p1.append(["keys", 8, F])
	p1.append(["wait", 6])
	# to the edge (clear of the slab, which never sinks into a hero), so that the shared view lets P2 reach the plate
	p1.append(["go", cx(202) - 4, {"tol": 1}])
	p1.append(wait_until(func(_lv: LevelBase, _hh: PlayerBase) -> bool:
		var other: PlayerBase = hero(1)
		return other.is_grounded() and other.sim_pos.x >= cx(223) - 6, 1500))
	p1.append(["wait", 40])
	p1.append(["go", cx(220), {}])
	p1.append(["go", cx(227), {}])
	p1.append(["hold", R])
	return [p1, p2]
