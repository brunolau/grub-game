extends "res://tools/autoplay/recorders/db2/bot_w3_l1_coop.gd"
## levels (wf11) copy of DB2's bot: the striker of each hut pincer stands 38 px behind the turtle (was 31: after his
## turn he stood 26 px from it, a pixel nearer than the bait at 27, and the shell turned to him).
## The two-stream routes of w3_l1b_coop "Blizzard Pass" (DB2): recorded by probe_work.gd --bot --players=2.
## Every jump waits for a lull (crouching through the gusts: crouching is input and braces). The Shellback at the cave
## mouth and the ones of the keeper hall before the hut fall to pincers: one hero baits it in front, the other clubs
## its back. Gate 'hut': P1 drops into the hall through the first hole (bait), P2 through the second (striker); for the
## second turtle P2 baits and P1 climbs the vine back out and drops through the third hole behind it.

const LULL: int = 16            ## wind at or under this: a lull (jump now; lulls blow 12 Beginner / 16 Expert)
const LOOK: int = 40            ## a jump starts only when the lull lasts at least this many more ticks


## True when the wind blows at most LULL now and on each of the next `ahead` ticks (the level's wind script).
func calm(lv: LevelBase, ahead: int = LOOK) -> bool:
	if absi(lv.wind) > LULL:
		return false
	var script: Array = lv.get("_wind_script")
	var now: int = int(lv.get("_play_ticks"))
	for point: Vector2i in script:
		if point.x > now + 1 and point.x <= now + 1 + ahead and absi(point.y) > LULL:
			return false
	return true


func header() -> String:
	var mode: String = "expert" if expert else "beginner"
	return ("# route: level=w3_l1b_coop difficulty=%s players=2 ends=exit after=tally "
		+ "expect=wipes:0,eggs:0,x2_gates:1\n") % mode


func build() -> Array:
	var fight: Dictionary = {"fight": true}
	var p1: Array = []
	var p2: Array = []
	# --- the cave mouth: the Shellback (a pincer), up the slope, the hopper ---
	p1.append(["keys", 2, R])
	p2.append(["keys", 2, R])
	pincer(p1, p2, cx(19), fy(29))
	p1.append(["go", cx(40), fight])
	p2.append(["go", cx(38), fight])
	both([p1, p2], ["sync", "crevasse"])
	p1.append(["mark", "at the crevasse"])
	# --- the crevasse of rock pillars, then the pond's floes: jump only in a lull (P2 one pillar behind) ---
	# [take-off x (the edge), landing x]: the ramp top, four pillars, the near shore, two floes, the far shore.
	var stones: Array = [[651, 716], [747, 812], [843, 908], [939, 1004], [1035, 1100], [1147, 1214], [1259, 1326],
		[1371, 1438]]
	for i: int in stones.size():
		var take: int = int(stones[i][0])
		var land: int = int(stones[i][1])
		var next_land: int = int(stones[i + 1][1]) if i + 1 < stones.size() else 1460
		# (Beginner: walk to the edge crouching through the gusts - a gust blows a walking hero back into the gap)
		p1.append(["go", take - 14, {"tol": 3}] if expert else ["fn", lull_go_fn(take - 14)])
		if i == stones.size() - 1:
			# The ridge charger runs down onto the far shore: wait on the last floe (crouching) until it is gone.
			p1.append(["fn", wait_clear_fn(1690, 340, 320, 500)])
		p1.append(["fn", lull_leap_fn(land, 14, take)])
		p1.append(["mark", "stone %d" % i])
		p2.append(["fn", wait_partner_fn(func(hh: PlayerBase) -> bool: return hh.is_grounded() and hh.sim_pos.x >= next_land - 16)])
		p2.append(["go", take - 14, {"tol": 3}] if expert else ["fn", lull_go_fn(take - 14)])
		p2.append(["fn", lull_leap_fn(land, 14, take)])
	p1.append(["go", 1520, {"tol": 3}])
	both([p1, p2], ["sync", "far_shore"])
	p1.append(["mark", "on the far shore"])
	# --- the climb to the shelter ridge (past the hatch: never crouch on it) ---
	p1.append(["go", cx(95.5), {"tol": 3}])
	p2.append(["go", cx(94.5), {"tol": 3}])
	p1.append(["fn", lull_leap_fn(cx(98.5), 14)])
	p2.append(["fn", wait_partner_fn(func(hh: PlayerBase) -> bool: return hh.is_grounded() and hh.sim_pos.x >= cx(97))])
	p2.append(["fn", lull_leap_fn(cx(97.6), 14)])
	p1.append(["go", cx(102), {"tol": 3}])
	p2.append(["go", cx(100), {"tol": 3}])
	both([p1, p2], ["sync", "slope"])
	p1.append(["fn", lull_go_fn(cx(103.5))])
	p2.append(["fn", lull_go_fn(cx(102.5))])
	# The slope's Shellback stands still at the top: both hop over it in a lull (a running jump), P2 after P1.
	p1.append(["go", cx(106) - 70, {"tol": 3}])
	p2.append(["go", cx(106) - 100, {"tol": 3}])
	p1.append(["fn", lull_dash_fn(cx(106) - 40, cx(106) + 50)])
	p2.append(["fn", wait_partner_fn(func(hh: PlayerBase) -> bool: return hh.is_grounded() and hh.sim_pos.x >= cx(106) + 30)])
	p2.append(["go", cx(106) - 70, {"tol": 3}])
	p2.append(["fn", lull_dash_fn(cx(106) - 40, cx(106) + 40)])
	p1.append(["fn", lull_go_fn(cx(116.5))])
	p2.append(["fn", lull_go_fn(cx(115))])
	both([p1, p2], ["sync", "ridge"])
	p1.append(["mark", "on the shelter ridge"])
	if str(opts.get("ledge", "")) != "":
		lee_ledge(p1, p2)
	# --- the shelter ridge (its chargers), the ice bridge ---
	p1.append(["fn", lull_go_fn(cx(125), true)])
	p2.append(["fn", lull_go_fn(cx(123.5), true)])
	both([p1, p2], ["sync", "bridge"])
	p1.append(["fn", lull_leap_fn(cx(131.5), 14, 2036)])
	p2.append(["fn", wait_partner_fn(func(hh: PlayerBase) -> bool: return hh.is_grounded() and hh.sim_pos.x >= cx(130.5))])
	p2.append(["fn", lull_go_fn(cx(125))])
	p2.append(["fn", lull_leap_fn(cx(130.5), 14, 2036)])
	p1.append(["go", cx(133.2), {"tol": 2}])
	# (the far half of the ice bridge is ice: P1 waits crouching, or a gust blows him back into the gap)
	p1.append(["fn", wait_partner_fn(func(hh: PlayerBase) -> bool: return hh.is_grounded() and hh.sim_pos.x >= cx(130.5))])
	p2.append(["go", cx(131.5), {"tol": 2}])
	both([p1, p2], ["sync", "hut"])
	p1.append(["mark", "at the keeper hall"])
	# --- gate 'hut': P1 drops through hole 1, P2 walks on to hole 2: the first pincer ---
	p1.append(["fn", lull_go_fn(cx(136.2))])
	p1.append(["until", stands_fn(fy(22)), 0])
	p1.append(["go", cx(139) - 26, {"tol": 2}])
	p1.append(["face", 1])
	p2.append(["fn", wait_partner_fn(func(hh: PlayerBase) -> bool: return hh.is_grounded() and hh.sim_pos.y == fy(22))])
	p2.append(["go", cx(134.3), {"tol": 2}])
	p2.append(["fn", lull_leap_fn(cx(138.5), 10)])
	p2.append(["fn", lull_go_fn(cx(142))])
	p2.append(["until", stands_fn(fy(22)), 0])
	p2.append(["go", cx(139) + 38, {"tol": 2}])
	p2.append(["face", -1])
	both([p1, p2], ["sync", "t1"])
	for k: int in 4:
		p2.append(["fn", strike_unless_dead_fn(cx(139), fy(22))])
	p2.append(["until", until_dead_fn(cx(139), fy(22)), 0])
	p1.append(["fn", hold_fn(func(_lv: LevelBase, _h: PlayerBase) -> bool: return enemy_near(cx(139), fy(22), 40) == null)])
	both([p1, p2], ["sync", "t1_done"])
	# --- the second turtle: P2 baits it from the left; P1 climbs the vine, crosses the crust and drops through hole 3 ---
	p2.append(["go", cx(145) - 26, {"tol": 2}])
	p2.append(["face", 1])
	p1.append(["go", cx(135.5), {"tol": 2}])
	p1.append(["fn", climb_fn(17)])
	p1.append(["mark", "back on the crust"])
	p1.append(["fn", lull_leap_fn(cx(138.5), 10)])
	p1.append(["fn", lull_go_fn(cx(139.6))])
	p1.append(["fn", lull_leap_fn(cx(143.5), 10)])
	p1.append(["fn", lull_go_fn(cx(148))])
	p1.append(["until", stands_fn(fy(22)), 0])
	p1.append(["go", cx(145) + 38, {"tol": 2}])
	p1.append(["face", -1])
	both([p1, p2], ["sync", "t2"])
	for k: int in 4:
		p1.append(["fn", strike_unless_dead_fn(cx(145), fy(22))])
	p1.append(["until", until_dead_fn(cx(145), fy(22)), 0])
	p2.append(["fn", hold_fn(func(_lv: LevelBase, _h: PlayerBase) -> bool: return enemy_near(cx(145), fy(22), 40) == null)])
	both([p1, p2], ["sync", "t2_done"])
	p1.append(["mark", "the keepers are dead"])
	# --- the door opens: into the hut's hollow and the exit ---
	p1.append(["until", air_fn(149, 22), D])
	p2.append(["until", air_fn(149, 22), D])
	p1.append(["hold", R])
	p2.append(["hold", R])
	return [p1, p2]


## The x2 secret over the shelter ridge (painting 25): P2 stands right of the ledge (8 rows up), P1 hops off his head
## in a lull onto it, walks over the painting and drops back off its left end; P2 crouches through the gusts meanwhile.
func lee_ledge(p1: Array, p2: Array) -> void:
	var top: int = fy(8)
	var ridge: int = fy(16)
	p2.append(["go", 1932, {"tol": 2}])
	p1.append(["go", 1962, {"tol": 2}])
	both([p1, p2], ["sync", "ledge_hop"])
	p2.append(["fn", func(lv: LevelBase, _h: PlayerBase, n: int) -> int:
		var other: PlayerBase = hero(0)
		if (other.is_grounded() and other.sim_pos.y <= top) or n > 900:
			return -1
		return D if not calm(lv, 70) else 0])
	p1.append(["fn", func(lv: LevelBase, _h: PlayerBase, n: int) -> int:
		if calm(lv, 70) and n > 8 or n > 900:
			return -1
		return D])
	p1.append(["fn", ledge_hop_fn(1932, 1924, 1886, top)])
	p1.append(["mark", "on the lee ledge"])
	# Over the food to the ledge's left end, then off its right end onto the flat ridge (the slope left of the ridge
	# is ice: a hero landing there slides down onto the Shellback); P2 has stepped aside meanwhile.
	p1.append(["go", cx(116.3), {"tol": 3}])
	p1.append(["fn", wait_partner_fn(func(hh: PlayerBase) -> bool: return hh.is_grounded() and hh.sim_pos.x >= cx(121.5))])
	p1.append(["run", 1912])
	p1.append(["until", func(_lv: LevelBase, h: PlayerBase) -> bool: return h.is_grounded() and h.sim_pos.y == ridge, 0])
	p2.append(["go", cx(122), {"tol": 3}])
	p2.append(["fn", wait_partner_fn(func(hh: PlayerBase) -> bool: return hh.is_grounded() and hh.sim_pos.y == ridge)])
	both([p1, p2], ["sync", "ledge_done"])


## Shoulder Hop onto a ledge whose right edge is near the partner: jump onto his head (steering to px), ride the
## bounce straight up at hold_x (clear of the ledge's underside) until the feet are over the ledge's top, then steer
## onto it (tx); done when he stands at most at `top`.
func ledge_hop_fn(px: int, hold_x: int, tx: int, top: int) -> Callable:
	return func(_lv: LevelBase, h: PlayerBase, n: int) -> int:
		var st: Dictionary = _st[h.slot]
		if n > 300 or (h.is_grounded() and h.sim_pos.y <= top and n > 4):
			return -1
		var phase: int = int(st.get("phase", 0))
		if phase == 0:
			st["g"] = int(st.get("g", 0)) + 1 if h.is_grounded() and h.xvel == 0 else 0
			if int(st["g"]) < 7:
				return 0
			st["phase"] = 1
			phase = 1
		var aim: int = px
		if phase == 1:
			if h.yvel < -150 and n > 8:
				st["phase"] = 2
				phase = 2
		if phase == 2:
			aim = hold_x if h.sim_pos.y > top - 2 else tx
		var dx: int = aim - h.sim_pos.x
		var k: int = U
		if dx > 2:
			k |= R
		elif dx < -2:
			k |= L
		return k


## Wait for the partner crouching (braced: a gust never blows a crouching hero back down the slopes; Down is input).
func wait_partner_fn(cond: Callable) -> Callable:
	return func(_lv: LevelBase, h: PlayerBase, n: int) -> int:
		if cond.call(hero(1 - h.slot)):
			return -1
		if n > 3000:
			return -1
		return D if h.is_grounded() else 0


## Crouch until no awake enemy is within `reach` px (x) of (x, y) on rows near y, or `cap` ticks passed.
func wait_clear_fn(x: int, y: int, reach: int, cap: int) -> Callable:
	return func(lv: LevelBase, h: PlayerBase, n: int) -> int:
		if n > cap:
			return -1
		for entity: SimEntity in lv.get_kind(Defs.Kind.ENEMY):
			var foe: EnemyBase = entity as EnemyBase
			if foe != null and not foe.dead and foe.awake and absi(foe.sim_pos.x - x) < reach 					and absi(foe.sim_pos.y - y) < 100:
				return D
		if n < 12:
			return D
		return -1


func stands_fn(y: int) -> Callable:
	return func(_lv: LevelBase, h: PlayerBase) -> bool:
		return h.is_grounded() and h.sim_pos.y == y


## Crouch through the gusts; in a lull (and standing still on the ground) jump toward `tx`, steering all the way.
func lull_leap_fn(tx: int, up: int, take: int = -1) -> Callable:
	return func(lv: LevelBase, h: PlayerBase, n: int) -> int:
		var st: Dictionary = _st[h.slot]
		if n > 2500:
			return -1
		if not bool(st.get("jumped", false)):
			if not h.is_grounded():
				return 0
			if not calm(lv):
				# On ice a crouching hero keeps sliding: brake against his motion first, then brace (Expert).
				if h.xvel > 8:
					return L
				if h.xvel < -8:
					return R
				return D
			if take >= 0 and h.sim_pos.x < take:
				return R
			if take < 0 and absi(h.xvel) > 8:
				return L if h.xvel > 0 else R
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


## Walk to x (right), crouching whenever a gust blows (braced, he is not pushed back); fights on the way when asked.
func lull_go_fn(x: int, fighting: bool = false) -> Callable:
	return func(lv: LevelBase, h: PlayerBase, n: int) -> int:
		if n > 2500:
			return -1
		if h.is_grounded() and h.sim_pos.x >= x - 2:
			return -1
		if fighting:
			var f: int = _fight(h, {"fight": true})
			if f >= 0:
				return f
		if absi(lv.wind) > LULL and h.is_grounded():
			if h.xvel > 8:
				return L
			if h.xvel < -8:
				return R
			return D
		return R


## The pincer of the slope's Shellback: the striker takes a running jump over it (it stands at the top of a slope).
func pincer_run(bait: Array, striker: Array, x: int, y: int) -> void:
	bait.append(["go", x - 100, {"tol": 3}])
	striker.append(["go", x - 76, {"tol": 3}])
	striker.append(["fn", dash_leap_fn(x - 44, x + 36, 14)])
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


## In a lull: run right and jump once past `take`, steering to land at `tx`; crouch through the gusts before that.
func lull_dash_fn(take: int, tx: int) -> Callable:
	return func(lv: LevelBase, h: PlayerBase, n: int) -> int:
		var st: Dictionary = _st[h.slot]
		if n > 2500:
			return -1
		if not bool(st.get("jumped", false)):
			if not h.is_grounded():
				return 0
			if not calm(lv, 40):
				return D
			if h.sim_pos.x < take:
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
		if k < 14:
			return U | keys
		if k > 2 and h.is_grounded():
			return -1
		return keys
