extends "res://tools/autoplay/recorders/levels/bot_w9_l2_d9a.gd"
## levels (wf11) copy: the final gap is 13 cells wide from column 203 (the lip is column 202; DESIGN G79).
## enemies-A (wf10): D9a's w9_l2_coop bot, re-recorded for the heavy-keeper ruling (a `heavy` is hurt only while a
## Brace Wall staggers it, one hit per strike). D9a's brace step let go of the Bull Rex once it ran more than 220 px
## from its anchor (it turns at the hall's step, 222 px away), so the pair walked into the hall behind it and clubbed its
## back (a hit that counted before the ruling). Here the step keeps the Rex whatever its place in the hall; each hero
## steps down into the hall while it is 100 px or more from the mouth (it shuttles at the step once a hero waits on the
## mouth floor, so it never "runs away"), the pair crouches 8 px apart until it is stopped dead, then both strike its
## head (hp 25: two strikes) - and braces again if the daze ran out. Section D: P2 jumps the first valley gap only
## once P1 left its landing (a hero on his partner's shoulders halves the carrier's next jump: P1 fell into the tar).

const TRACE: bool = false


func header() -> String:
	return "# route: level=w9_l2_coop difficulty=expert players=2 ends=exit after=level:w9_l2b_coop expect=wipes:0,x2_gates:2,min_checkpoints:5\n" \
		+ "# The two-stream Expert route of The Roc's Spire in co-op (designer D9a; recorded from closed-loop macros,\n" \
		+ "# build/d9a/bot_w9_l2_coop.gd; re-recorded by enemies-A for the heavy-keeper ruling of G3 with\n" \
		+ "# build/enemies_a10/bot_w9_l2_coop_ea.gd, P1|P2): the gust gaps in the lulls, the drop clouds one hero at a time,\n" \
		+ "# gate 'brace' (the Bull Rex wakes and charges; while it is still 100 px off both step down from the mouth into\n" \
		+ "# the sunken hall and crouch side by side 8 px apart: the Brace Wall stops it dead, and both strike its dazed\n" \
		+ "# head - the first strike, charged by the crouch, takes its 25 hp; its back counts for nobody), the cloud\n" \
		+ "# hall's tribesman and Roller (P2 jumps the first valley gap once P1 left its landing), gate 'drive' (P2 curls\n" \
		+ "# at the edge, P1 charges and bats him across; P2's latch plate sinks the slab bridge).\n"


func brace_fn(wait_x: int, stand_x: int, rex_hint: int) -> Callable:
	return func(lv: LevelBase, h: PlayerBase, n: int) -> int:
		if n > 2400:
			return -1
		var rex: EnemyBase = null
		for entity: SimEntity in lv.get_kind(Defs.Kind.ENEMY):
			var foe: EnemyBase = entity as EnemyBase
			if foe != null and not foe.dead and foe is BullRex and absi(foe.spawn_pos.x - rex_hint) < 64:
				rex = foe
		if rex == null:
			return -1
		var st: Dictionary = _st[h.slot]
		var key: int = rex_hint
		var trs: CoopTraits = rex.coop_traits()
		var dazed: bool = trs != null and trs.dazed > 0
		if TRACE and rex.awake:
			print("BRACE t=%d P%d %s st %d | rex %s hp %d dazed %d f %d" % [Sim.total_ticks, h.slot + 1, h.sim_pos,
				h.state, rex.sim_pos, rex.hp, trs.dazed if trs != null else -1, rex.facing])
		if not bool(_brace_go.get(key, false)):
			# waiting outside, on the mouth floor (the Rex cannot climb the step)
			if absi(h.sim_pos.x - wait_x) > 3:
				return R if wait_x > h.sim_pos.x else L
			if not h.is_grounded():
				return 0
			if h.facing < 0:
				return R
			st["ready"] = key
			# far enough to be in place and crouched before it arrives, whichever way it runs (it shuttles at the
			# step while a hero waits on the mouth floor - so do not wait for it to run away)
			var away: bool = not rex.awake or rex.sim_pos.x - stand_x > 100
			if away:
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
		st["hold"] = 0
		# 8 px apart (D9a's 12 plus the front hero's slide after his crouch broke the 16 px of the Brace Wall)
		var spot: int = stand_x - (6 if h.slot == 0 else 2)
		if absi(h.sim_pos.x - spot) > 3 and not bool(st.get("placed%d" % key, false)):
			return R if spot > h.sim_pos.x else L
		if not h.is_grounded():
			return 0
		st["placed%d" % key] = true
		if h.facing < 0:
			return R
		return D


## D9a's macros (build/d9a/bot_w9_l2_coop.gd) with one change in section D (P2 waits for P1 to leave the landing).
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
			# enemies-A: P2 jumps this gap only once P1 left its landing (P2 landing on his shoulders there halved
			# P1's jump over the next gap: he fell into the tar)
			p.append(["trek", cx(154) - 10])
			p.append(["go", cx(154) + 1, {"fight": true, "tol": 2}])
			p.append(["until", partner_past(cx(161)), 0])
			p.append(["lull", 40, LULL])
			p.append(["hop", cx(159), 9])
		else:
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
	# the latch plate (columns 219-220)
	p2.append(["trek", cx(219) + 8])
	p2.append(wait_until(partner_past(cx(217))))
	p2.append(["go", cx(228), {}])
	p2.append(["hold", R])
	p1.append(["go", cx(201) + 6, {"tol": 1}])
	p1.append(["face", 1])
	p1.append(["keys", 10, D])
	p1.append(["sync", "curl_spot"])
	# a full crouch charge right before the strike: the 13-cell gap needs the CHARGED line drive (325 px)
	p1.append(["keys", 44, D])
	p1.append(["keys", 8, F])
	p1.append(["wait", 6])
	# to the edge (clear of the slab, which never sinks into a hero), so that the shared view lets P2 reach the plate
	p1.append(["go", cx(202) - 4, {"tol": 1}])
	p1.append(wait_until(func(_lv: LevelBase, _hh: PlayerBase) -> bool:
		var other: PlayerBase = hero(1)
		return other.is_grounded() and other.sim_pos.x >= cx(219), 1500))
	# the slab sinks 7 rows into a bridge over columns 203-211; the last 4 cells of tar are hopped in a lull
	p1.append(wait_until(func(lv: LevelBase, _hh: PlayerBase) -> bool:
		return TileGrid.is_ground(lv.grid.floor_at(207, 35)) and lv.grid.floor_at(207, 35) != TileGrid.FLOOR_DEADLY, 600))
	p1.append(["wait", 6])
	p1.append(["go", cx(211) - 10, {}])
	p1.append(["go", cx(211) + 1, {"tol": 2}])
	p1.append(["lull", 40, LULL])
	p1.append(["hop", cx(216) + 4, 9])
	p1.append(["go", cx(220), {}])
	p1.append(["go", cx(227), {}])
	p1.append(["hold", R])
	return [p1, p2]
