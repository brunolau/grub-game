extends "res://tools/autoplay/recorders/db2/botx.gd"
## The two-stream routes of w3_l1_coop "Frost Summit" (DB2): recorded by probe_work.gd --bot --players=2.
## Gate 'lake': both heroes step into the ice tunnel, crouch side by side as the Bull Rex charges (a Brace Wall), club
## it while it is dazed, and the ice door opens. Gate 'cliff': P2 stands under the clifftop, P1 hops off his head,
## clubs the coiled vine down and P2 climbs it. Both act all the way (the IDLE rule).

const START_Y: int = 864        ## feet y at the start and on the near shore (row 53)


func header() -> String:
	var mode: String = "expert" if expert else "beginner"
	return ("# route: level=w3_l1_coop difficulty=%s players=2 ends=exit after=level:w3_l1b_coop "
		+ "expect=wipes:0,eggs:0,x2_gates:2,min_checkpoints:3\n") % mode


## A jump toward tx (Up held `up` ticks, steering within 3 px), ending on the first grounded tick after take-off; waits
## until the hero has stood still on the ground for `settle` ticks first.
func leap(p: Array, tx: int, up: int, settle: int = 2) -> void:
	p.append(["fn", hop_fn(tx, up, settle)])


func build() -> Array:
	var fight: Dictionary = {"fight": true}
	var p1: Array = []
	var p2: Array = []
	# --- the foothills: up the ramp; the Shellback on the ramp top (a pincer: P2 hops over it and clubs its back while
	# P1 stands in front), down to the hopper, a running jump over the pond ---
	p1.append(["keys", 2, R])
	p2.append(["keys", 2, R])
	p1.append(["go", cx(18), fight])
	p2.append(["go", cx(20), fight])
	both([p1, p2], ["sync", "ramp"])
	pincer(p1, p2, cx(25), fy(49))
	p1.append(["go", cx(36), fight])
	p2.append(["go", cx(34), fight])
	p1.append(["fn", guard_fn(func(_lv: LevelBase, _h: PlayerBase) -> bool: return enemy_near(cx(39), fy(53), 96) == null)])
	p2.append(["fn", guard_fn(func(_lv: LevelBase, _h: PlayerBase) -> bool: return enemy_near(cx(39), fy(53), 96) == null)])
	both([p1, p2], ["sync", "pond"])
	p1.append(["fn", runjump_fn(cx(38.5), cx(45.5), 12)])
	p2.append(["wait", 16])
	p2.append(["fn", runjump_fn(cx(38.5), cx(45), 12)])
	p1.append(["go", cx(48), {"tol": 3}])
	p2.append(["go", cx(46.5), {"tol": 3}])
	both([p1, p2], ["sync", "lake"])
	p1.append(["mark", "at the lake"])
	if bool(opts.get("cave", "") != ""):
		ice_cave(p1, p2)
	# --- the frozen lake: floe to floe with a short run-up (P2 one floe behind) ---
	# [run-up start x, take-off x, landing x]
	var hops: Array = [[cx(48.5), 820, cx(56)], [cx(55), 914, cx(63)], [cx(61.2), 1042, cx(70)]]
	for i: int in hops.size():
		var hop: Array = hops[i]
		var land: int = int(hop[2])
		var after: int = int(hops[i + 1][2]) - 24 if i + 1 < hops.size() else cx(71.5)
		p1.append(["go", int(hop[0]), {"tol": 4}])
		p1.append(["fn", dash_leap_fn(int(hop[1]), land, 16)])
		p1.append(["mark", "floe %d" % i])
		p2.append(["fn", wait_partner_fn(func(hh: PlayerBase) -> bool: return hh.is_grounded() and hh.sim_pos.x >= after)])
		p2.append(["go", int(hop[0]), {"tol": 4}])
		p2.append(["fn", dash_leap_fn(int(hop[1]), land - 12, 16)])
	# Both on the last floe: P1 jumps onto the island's pocket and walks into the ice tunnel, P2 follows; the Bull Rex
	# sleeps at the tunnel's far end, out of view. Both stand side by side, P1 walks on until it wakes and charges, runs
	# back and both crouch: a Brace Wall (gate 'lake'), then they club it while it is dazed.
	p1.append(["go", cx(71.6), {"tol": 3}])
	p2.append(["go", cx(69.6), {"tol": 3}])
	both([p1, p2], ["sync", "last_floe"])
	p1.append(["fn", dash_leap_fn(1168, 1240, 16)])
	p1.append(["go", 1274, {"tol": 3}])
	p2.append(["fn", wait_partner_fn(func(hh: PlayerBase) -> bool: return hh.is_grounded() and hh.sim_pos.x >= 1256)])
	p2.append(["go", cx(71.6), {"tol": 3}])
	p2.append(["fn", dash_leap_fn(1160, 1220, 16)])
	p2.append(["go", 1262, {"tol": 3}])
	p1.append(["face", 1])
	p2.append(["face", 1])
	both([p1, p2], ["sync", "brace_spot"])
	p1.append(["mark", "in the ice tunnel"])
	p1.append(["fn", wake_rex_fn(1274)])
	for p: Array in [p1, p2]:
		p.append(["fn", brace_fight_fn()])
	both([p1, p2], ["sync", "rex_done"])
	p1.append(["mark", "the rex is dead"])
	p1.append(["until", air_fn(91, 50), D])
	p2.append(["until", air_fn(91, 50), D])
	p1.append(["go", cx(87), {"tol": 3}])
	p2.append(["go", cx(85), {"tol": 3}])
	p1.append(["fn", dash_leap_fn(1462, cx(97.5), 14)])
	p1.append(["go", cx(100), {"tol": 3}])
	p2.append(["fn", wait_partner_fn(func(hh: PlayerBase) -> bool: return hh.is_grounded() and hh.sim_pos.x >= cx(96.5))])
	p2.append(["go", cx(87), {"tol": 3}])
	p2.append(["fn", dash_leap_fn(1462, cx(97.5), 14)])
	p1.append(["go", cx(106), {"tol": 3}])
	p2.append(["go", cx(104), {"tol": 3}])
	both([p1, p2], ["sync", "far_shore"])
	p1.append(["mark", "on the far shore"])
	# --- the cliff face: up the zigzag of floating ledges (P2 one ledge behind) to the rock step ---
	# [take-off x, landing x, feet y of the landing]
	var ledges: Array = [[1760, 1800, fy(50)], [1784, 1744, fy(47)], [1752, 1792, fy(44)], [1784, 1744, fy(41)],
		[1752, 1792, fy(38)], [1848, 1900, fy(35)]]
	p1.append(["go", cx(109), {"tol": 3, "fight": true}])
	p2.append(["go", cx(107), {"tol": 3, "fight": true}])
	for i: int in ledges.size():
		var ld: Array = ledges[i]
		var ly: int = int(ld[2])
		var next_y: int = int(ledges[i + 1][2]) if i + 1 < ledges.size() else -1
		p1.append(["go", int(ld[0]), {"tol": 3}])
		p1.append(["fn", leap_to_fn(int(ld[1]), 14)])
		p1.append(["until", grounded_fn(), 0])
		p1.append(["mark", "ledge %d" % i])
		if i < ledges.size() - 1:
			p2.append(["fn", wait_partner_fn(func(hh: PlayerBase) -> bool: return hh.is_grounded() and hh.sim_pos.y <= next_y)])
		else:
			p2.append(["fn", wait_partner_fn(func(hh: PlayerBase) -> bool: return hh.is_grounded() and hh.sim_pos.y <= ly)])
		p2.append(["go", int(ld[0]), {"tol": 3}])
		p2.append(["fn", leap_to_fn(int(ld[1]) + (40 if i == ledges.size() - 1 else 0), 14)])
		p2.append(["until", grounded_fn(), 0])
	both([p1, p2], ["sync", "step"])
	p1.append(["mark", "on the step"])
	# --- gate 'cliff': P2 stands under the clifftop's edge, P1 hops off his head onto the clifftop, clubs the coiled vine
	# down and P2 climbs it ---
	p2.append(["go", cx(121.6), {"tol": 2}])
	p2.append(["face", 1])
	p1.append(["go", cx(118.5), {"tol": 2}])
	both([p1, p2], ["sync", "hop"])
	p1.append(["fn", shoulder_fn(cx(121.6), cx(124.5), fy(27))])
	p1.append(["mark", "on the clifftop"])
	p1.append(["go", cx(123.4), {"tol": 2}])
	p1.append(["face", -1])
	p1.append(["fn", unroll_fn(122, D)])
	p2.append(["fn", wait_partner_fn(func(hh: PlayerBase) -> bool: return hh.is_grounded() and hh.sim_pos.y <= fy(27))])
	p2.append(["fn", hold_fn(func(lv: LevelBase, _h: PlayerBase) -> bool:
		for entity: SimEntity in lv.get_kind(Defs.Kind.HITTABLE):
			var vine: Vine = entity as Vine
			if vine != null and vine.vine_x >> 4 == 122 and vine.unrolled:
				return true
		return false)])
	p2.append(["go", cx(122), {"tol": 2}])
	p2.append(["fn", climb_fn(28)])
	p2.append(["mark", "up the vine"])
	p1.append(["go", cx(128), {"tol": 3}])
	p2.append(["go", cx(126), {"tol": 3}])
	both([p1, p2], ["sync", "clifftop"])
	# --- the valley: the Shellback (a pincer), the chargers off the rock, the water pit ---
	p1.append(["go", cx(140), {"fight": true}])
	p2.append(["go", cx(138), {"fight": true}])
	both([p1, p2], ["sync", "valley"])
	pincer(p1, p2, cx(147), fy(30))
	p1.append(["go", cx(152), {"tol": 3, "fight": true}])
	p2.append(["go", cx(151), {"tol": 3, "fight": true}])
	both([p1, p2], ["sync", "pit"])
	# At the water pit the ridge chargers wake and run down the slope at the heroes: both wait on this side, facing
	# them (they club what comes over; a charger that runs on drowns in the pit).
	p1.append(["go", cx(164), {"tol": 3, "fight": true}])
	p2.append(["go", cx(162), {"tol": 3, "fight": true}])
	both([p1, p2], ["sync", "pit_wait"])
	p1.append(["fn", guard_quiet_fn(cx(168), 230, 150, 40, 230)])
	p2.append(["fn", guard_quiet_fn(cx(168), 230, 150, 40, 230)])
	both([p1, p2], ["sync", "pit_quiet"])
	p1.append(["go", cx(164), {"tol": 3, "fight": true}])
	p1.append(["fn", runjump_fn(cx(165.5), cx(170), 10)])
	p2.append(["wait", 12])
	p2.append(["go", cx(163), {"tol": 3, "fight": true}])
	p2.append(["fn", runjump_fn(cx(165.5), cx(169.5), 10)])
	# (the slope's foot is ice: whoever walks back toward the pit stops well clear of it - he slides)
	p1.append(["go", cx(171.5), {"tol": 4}])
	p2.append(["go", cx(170.5), {"tol": 4}])
	both([p1, p2], ["sync", "slope"])
	p1.append(["mark", "past the water pit"])
	p1.append(["fn", guard_quiet_fn(cx(171), 150, 20, 20, 120)])
	p2.append(["fn", guard_quiet_fn(cx(171), 150, 20, 20, 120)])
	both([p1, p2], ["sync", "slope_quiet"])
	# --- up the slope: the Shellback at its top (a pincer), the ridge: hoppers, the bonded chargers, the dangler ---
	p1.append(["go", cx(171), {"fight": true}])
	p2.append(["go", cx(170), {"fight": true}])
	slope_pincer(p2, p1)
	p1.append(["go", cx(205), {"tol": 3, "fight": true}])
	p2.append(["go", cx(203), {"tol": 3, "fight": true}])
	both([p1, p2], ["sync", "ridge"])
	p1.append(["mark", "at the ridge checkpoint"])
	# --- the summit: up the steps, the hoppers, into the exit ---
	p1.append(["go", cx(233), {"fight": true}])
	p2.append(["go", cx(233), {"fight": true}])
	p1.append(["hold", R])
	p2.append(["hold", R])
	return [p1, p2]


## The x2 secret, the ice cave under the lake (painting 24): P1 breaks the shaft's ice blocks with low strikes, both
## drop down the shaft, P1 holds the plate (crouch taps: never idle) while P2 runs through the ice door to the nook
## (the U, the painting, the treasure) and back; both climb the vine out and stand where the lake section starts.
func ice_cave(p1: Array, p2: Array) -> void:
	var floor_y: int = fy(63)
	p1.append(["go", cx(49.5), {"tol": 3}])
	p1.append(["until", func(_lv: LevelBase, h: PlayerBase) -> bool: return h.sim_pos.y > fy(53) + 8, D])
	p1.append(["mark", "through the hatch"])
	p1.append(["until", func(_lv: LevelBase, h: PlayerBase) -> bool: return h.is_grounded() and h.sim_pos.y == floor_y, 0])
	p1.append(["go", cx(80.6), {"tol": 3}])
	p1.append(["mark", "on the plate"])
	p2.append(["fn", wait_partner_fn(func(hh: PlayerBase) -> bool: return hh.is_grounded() and hh.sim_pos.y == floor_y)])
	p2.append(["go", cx(49.5), {"tol": 3}])
	p2.append(["until", func(_lv: LevelBase, h: PlayerBase) -> bool: return h.sim_pos.y > fy(53) + 8, D])
	p2.append(["until", func(_lv: LevelBase, h: PlayerBase) -> bool: return h.is_grounded() and h.sim_pos.y == floor_y, 0])
	p2.append(["go", cx(86.5), {"tol": 3}])
	p2.append(["until", air_fn(89, 63), 0])
	p2.append(["go", cx(96.6), {"tol": 3}])
	p2.append(["mark", "in the nook"])
	p2.append(["go", cx(85.5), {"tol": 3}])
	p1.append(["fn", hold_fn(func(_lv: LevelBase, _h: PlayerBase) -> bool: return hero(1).sim_pos.x <= cx(86.5))])
	both([p1, p2], ["sync", "cave_done"])
	p2.append(["go", cx(51.5), {"tol": 3}])
	p1.append(["go", cx(49) + 1, {"tol": 2}])
	p1.append(["fn", climb_fn(54)])
	p1.append(["mark", "out of the cave"])
	p1.append(["go", cx(48), {"tol": 3}])
	p2.append(["fn", wait_partner_fn(func(hh: PlayerBase) -> bool: return hh.is_grounded() and hh.sim_pos.y <= fy(53))])
	p2.append(["go", cx(49) + 1, {"tol": 2}])
	p2.append(["fn", climb_fn(54)])
	p2.append(["go", cx(46.5), {"tol": 3}])
	both([p1, p2], ["sync", "lake2"])


## Low strikes (crouch, then Down + Fire) until the cell (c, r) is air.
func low_strike_fn(c: int, r: int) -> Callable:
	return func(lv: LevelBase, h: PlayerBase, n: int) -> int:
		if lv.get_cell(c, r) == TileGrid.CH_AIR or n > 300:
			return -1
		var k: int = n % 22
		if k < 6:
			return D
		if k < 15:
			return D | F
		return D


## Stand facing right and club whatever runs at him (D6's predictive _fight) until no moving enemy (walkers - the
## standing Shellbacks - excepted) came within `reach` px of x for `quiet` ticks, after at least `least` ticks; at most
## `cap` ticks. A crouch tap now and then keeps him active (the IDLE rule).
func guard_quiet_fn(x: int, reach: int, least: int, quiet: int, cap: int) -> Callable:
	return func(lv: LevelBase, h: PlayerBase, n: int) -> int:
		var st: Dictionary = _st[h.slot]
		if n > cap:
			return -1
		var danger: bool = false
		for entity: SimEntity in lv.get_kind(Defs.Kind.ENEMY):
			var foe: EnemyBase = entity as EnemyBase
			if foe == null or foe.dead or not foe.awake:
				continue
			if foe.get_script() != null and (foe.get_script() as Script).resource_path.get_file() == "walker.gd":
				continue
			if absi(foe.sim_pos.x - x) < reach and absi(foe.sim_pos.y - h.sim_pos.y) < 96:
				danger = true
		st["quiet"] = 0 if danger else int(st.get("quiet", 0)) + 1
		if n >= least and int(st["quiet"]) >= quiet:
			return -1
		var f: int = _fight(h, {"fight": true})
		if f >= 0:
			return f
		if h.is_grounded() and h.facing != 1:
			return R
		return D if n % 60 == 59 else 0


## The Shellback at the top of the valley slope (cols 175-176 flat, a 45-degree slope below it on the left, a half
## slope above it on the right): the bait must be the NEARER hero by the trait's measure (|dx| + |dy|), so here the
## hopper is the bait - he jumps over it from the slope and waits on the half slope 26 px right of it (dy 1); the
## striker comes up the slope behind it to 22 px (dy 14: farther) and clubs its back.
func slope_pincer(bait: Array, striker: Array) -> void:
	var x: int = cx(175)
	var y: int = fy(26)
	striker.append(["go", 2745, {"tol": 4}])
	bait.append(["go", 2770, {"tol": 3}])
	bait.append(["fn", hop_fn(2850, 14)])
	bait.append(["go", x + 26, {"tol": 2}])
	bait.append(["face", -1])
	both([bait, striker], ["sync", "slope_behind"])
	striker.append(["go", x - 22, {"tol": 2}])
	striker.append(["face", 1])
	both([bait, striker], ["sync", "slope_pincer"])
	for k: int in 5:
		striker.append(["fn", strike_unless_dead_fn(x, y)])
	striker.append(["until", until_dead_fn(x, y), 0])
	bait.append(["fn", hold_fn(func(_lv: LevelBase, _h: PlayerBase) -> bool: return enemy_near(x, y, 64) == null)])
	both([bait, striker], ["sync", "slope_done"])


## Hop over the walker standing near `anchor` (dir 1: from its left): wait until it is 40-60 px ahead, jump with the
## direction held until he lands at least 30 px beyond it.
func over_fn(anchor: Vector2i, dir: int) -> Callable:
	return func(_lv: LevelBase, h: PlayerBase, n: int) -> int:
		var st: Dictionary = _st[h.slot]
		var foe: EnemyBase = enemy_near(anchor.x, anchor.y, 96)
		var key: int = R if dir > 0 else L
		var back: int = L if dir > 0 else R
		if n > 600:
			return -1
		if not bool(st.get("jumped", false)):
			if foe == null or foe.dead:
				return -1
			var dx: int = (foe.sim_pos.x - h.sim_pos.x) * dir
			if dx < 0:
				return -1
			if dx < 34:
				return back
			if dx > 54:
				return key
			if not h.is_grounded():
				return 0
			st["jumped"] = true
			st["t0"] = n
		var k: int = n - int(st["t0"])
		if k < 14:
			return U | key
		if k > 2 and h.is_grounded():
			return -1
		return key


## Run right (from where he stands) and jump once past `take` (Up `up` ticks, Right held), until he lands past `land`.
func runjump_fn(take: int, land: int, up: int) -> Callable:
	return func(_lv: LevelBase, h: PlayerBase, n: int) -> int:
		var st: Dictionary = _st[h.slot]
		if n > 400:
			return -1
		if not bool(st.get("jumped", false)):
			if h.sim_pos.x >= take and h.is_grounded():
				st["jumped"] = true
				st["t0"] = n
				return U | R
			return R
		var k: int = n - int(st["t0"])
		if k < up:
			return U | R
		if h.is_grounded() and h.sim_pos.x >= land:
			return -1
		if h.is_grounded() and k > 4:
			return -1
		return R


## A Shellback pincer at x (feet y): `bait` stands 26 px in front (left), `striker` hops over and strikes its back from
## 31 px behind (D6 / DB2's w2_l2 pincer).
func pincer(bait: Array, striker: Array, x: int, y: int) -> void:
	bait.append(["go", x - 90, {"tol": 3}])
	striker.append(["go", x - 60, {"tol": 3}])
	striker.append(["fn", hop_fn(x + 34, 12)])
	striker.append(["go", x + 31, {"tol": 2}])
	striker.append(["face", -1])
	striker.append(["sync", "behind%d" % x])
	bait.append(["sync", "behind%d" % x])
	bait.append(["go", x - 26, {"tol": 2}])
	bait.append(["face", 1])
	striker.append(["sync", "pincer%d" % x])
	bait.append(["sync", "pincer%d" % x])
	for k: int in 4:
		striker.append(["fn", strike_unless_dead_fn(x, y)])
	striker.append(["until", until_dead_fn(x, y), 0])
	bait.append(["fn", hold_fn(func(_lv: LevelBase, _h: PlayerBase) -> bool: return enemy_near(x, y, 64) == null)])
	both([bait, striker], ["sync", "pincer_done%d" % x])


func strike_unless_dead_fn(x: int, y: int) -> Callable:
	return func(_lv: LevelBase, _h: PlayerBase, n: int) -> int:
		if enemy_near(x, y, 64) == null or n >= 12:
			return -1
		return F if n < 8 else 0


## Idle with a crouch tap every 40 ticks (input: never idle) until `cond(partner)` holds.
func wait_partner_fn(cond: Callable) -> Callable:
	return func(_lv: LevelBase, h: PlayerBase, n: int) -> int:
		if cond.call(hero(1 - h.slot)):
			return -1
		if n > 3000:
			return -1
		return D if n % 40 == 0 else 0


## A jump to land at `tx` (Up `up` ticks, steering within 4 px all the way), from a standstill or a run; ends on the
## first grounded tick after take-off.
func leap_to_fn(tx: int, up: int) -> Callable:
	return func(_lv: LevelBase, h: PlayerBase, n: int) -> int:
		var st: Dictionary = _st[h.slot]
		if n > 300:
			return -1
		if not bool(st.get("jumped", false)):
			if not h.is_grounded():
				return 0
			st["jumped"] = true
			st["t0"] = n
		var k: int = n - int(st["t0"])
		var dx: int = tx - h.sim_pos.x
		var keys: int = 0
		if dx > 4:
			keys = R
		elif dx < -4:
			keys = L
		if k < up:
			return U | keys
		if k > 2 and h.is_grounded():
			return -1
		return keys


func rex() -> EnemyBase:
	for entity: SimEntity in level.get_kind(Defs.Kind.ENEMY):
		var foe: EnemyBase = entity as EnemyBase
		if foe != null and foe is BullRex and not foe.dead:
			return foe
	return null


## The Brace Wall and the fight: crouch until the rex is dazed, then club it (forward strikes) while it is dazed;
## crouch again when the daze is over; done when it is dead.
func brace_fight_fn() -> Callable:
	return func(_lv: LevelBase, h: PlayerBase, n: int) -> int:
		var st: Dictionary = _st[h.slot]
		var r: EnemyBase = rex()
		if r == null:
			return -1
		if n > 3000:
			return -1
		var tr: Object = traits_of(r)
		var dazed: int = int(tr.get("dazed")) if tr != null else 0
		if h.slot == 0 and t % 2 == 0:
			print("REX t=%d x=%d y=%d xv=%d face=%d dazed=%d hp=%d doze=%s g=%s box=%s tgt=%s | P1 %s st=%d | P2 %s st=%d" % [t,
				r.sim_pos.x, r.sim_pos.y, r.xvel, r.facing, dazed, r.hp, str(r.is_dozing()), str(r.get("_grounded")),
				str(r.get_box()), str(r._target_hero().slot if r._target_hero() != null else -1), hero(0).sim_pos,
				hero(0).state, hero(1).sim_pos, hero(1).state])
		if int(st.get("swing", 0)) > 0:
			st["swing"] = int(st["swing"]) - 1
			return F if int(st["swing"]) > 2 else 0
		if dazed > 6:
			var dx: int = r.sim_pos.x - h.sim_pos.x
			var dir: int = 1 if dx >= 0 else -1
			if h.facing != dir:
				return R if dir > 0 else L
			if absi(dx) > 44:
				return R if dir > 0 else L
			st["swing"] = 10
			return F
		return D


## Run right until past `take` (grounded), then jump (Up `up` ticks) steering to land at `tx`; ends on the first
## grounded tick after take-off.
func dash_leap_fn(take: int, tx: int, up: int) -> Callable:
	return func(_lv: LevelBase, h: PlayerBase, n: int) -> int:
		var st: Dictionary = _st[h.slot]
		if n > 300:
			return -1
		if not bool(st.get("jumped", false)):
			if h.sim_pos.x < take or not h.is_grounded():
				return R
			st["jumped"] = true
			st["t0"] = n
		var k: int = n - int(st["t0"])
		var dx: int = tx - h.sim_pos.x
		var keys: int = 0
		if dx > 4:
			keys = R
		elif dx < -4:
			keys = L
		if k < up:
			return U | keys
		if k > 2 and h.is_grounded():
			return -1
		return keys


## No living enemy within 80 px of the valley floor between the rock and the water pit (the chargers came down).
func _quiet_valley() -> bool:
	return _quiet_near(cx(160), 96)


func _quiet_near(x: int, reach: int) -> bool:
	for entity: SimEntity in level.get_kind(Defs.Kind.ENEMY):
		var foe: EnemyBase = entity as EnemyBase
		if foe != null and not foe.dead and foe.awake and absi(foe.sim_pos.x - x) < reach:
			return false
	return true


## Crouch-wait (input) until the Bull Rex runs away from the tunnel mouth (rightwards, past x 1296), or is dead.
func rex_away_fn() -> Callable:
	return func(_lv: LevelBase, h: PlayerBase, n: int) -> int:
		var r: EnemyBase = rex()
		if r != null and h.slot == 0 and t % 4 == 0:
			var trs: Object = traits_of(r)
			print("REX t=%d x=%d y=%d xv=%d face=%d awake=%s dazed=%d" % [t, r.sim_pos.x, r.sim_pos.y, r.xvel, r.facing,
				str(r.awake), int(trs.get("dazed")) if trs != null else -1])
		if r == null or n > 1500:
			return -1
		if r.xvel > 0 and r.sim_pos.x > 1296:
			return -1
		return D if n % 30 == 0 else 0


## Crawl right (Down + Right) off the pocket's step until he lands crouching on the tunnel floor (feet y 816).
func crawl_in_fn() -> Callable:
	return func(_lv: LevelBase, h: PlayerBase, n: int) -> int:
		if n > 60:
			return -1
		if n > 2 and h.is_grounded() and h.sim_pos.y >= 816:
			return -1
		return D | R


## P1 walks on along the tunnel until the Bull Rex is awake and running at him, then runs back to `spot`; done there.
func wake_rex_fn(spot: int) -> Callable:
	return func(_lv: LevelBase, h: PlayerBase, n: int) -> int:
		var st: Dictionary = _st[h.slot]
		var r: EnemyBase = rex()
		if r == null or n > 600:
			return -1
		if not bool(st.get("woken", false)):
			if r.awake:
				st["woken"] = true
			elif h.sim_pos.x < 1400:
				return R
			else:
				return 0
		if h.sim_pos.x > spot + 4:
			return L
		if h.xvel < -8:
			return R
		return -1
