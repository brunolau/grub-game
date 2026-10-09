extends "res://tools/autoplay/recorders/d7/d7lib.gd"
## The two-stream route of w7_l1_coop (D7): recorded by probe_work.gd --bot --players=2 (P1 | P2).
## Both cross every raft reach on one raft (P1 boards first and paddles, P2 boards behind him and guards); the
## blowholes one after the other; P1 fetches letter B while P2 waits on the plateau; gate 'dune': P1 holds plate A,
## P2 walks the lower corridor to plate B, P1 climbs to the upper corridor and through; gate 'stack': P1 curls on the
## rock, P2 lobs him onto the shoulder with a high strike, P1 clubs the rolled vine down, P2 climbs it; both walk
## through the sea arch to the exit totem.

const FY: int = 28 * 16


func header() -> String:
	var d: String = "expert" if expert else "beginner"
	return "# route: level=w7_l1_coop difficulty=%s players=2 ends=exit after=tally expect=wipes:0,x2_gates:2,min_checkpoints:4,letters:3\n" % d


func no_foe_near(px: int) -> Callable:
	return func(lv: LevelBase, h: PlayerBase) -> bool:
		for entity: SimEntity in lv.get_kind(Defs.Kind.ENEMY):
			var foe: EnemyBase = entity as EnemyBase
			if foe != null and not foe.dead and foe.awake and foe.tangible \
					and absi(foe.sim_pos.x - h.sim_pos.x) < px and absi(foe.sim_pos.y - h.sim_pos.y) < px:
				return false
		return true


func partner_past(x: int) -> Callable:
	return func(lv: LevelBase, hh: PlayerBase) -> bool:
		var other: PlayerBase = hero(1 - hh.slot)
		return other.sim_pos.x >= x and other.is_grounded()


func partner_settled_on_raft() -> Callable:
	return func(lv: LevelBase, hh: PlayerBase) -> bool:
		var other: PlayerBase = hero(1 - hh.slot)
		return other.on_platform and other.is_grounded() and other.xvel == 0


func hop_fn(tx: int, up: int) -> Callable:
	return func(lv: LevelBase, h: PlayerBase, n: int) -> int:
		var st: Dictionary = _st[h.slot]
		if not bool(st.get("go", false)):
			if h.is_grounded() and h.no_jump == 0 and not h.is_striking():
				st["go"] = true
				st["t"] = 0
			else:
				return 0
		var k: int = int(st["t"])
		st["t"] = k + 1
		var dx: int = tx - h.sim_pos.x
		var keys: int = 0
		if dx > 3:
			keys = R
		elif dx < -3:
			keys = L
		if k < up:
			return U | keys
		if k > 2 and h.is_grounded():
			return -1
		if k > 120:
			return -1
		return keys


## Guard on the raft (P2): fight, steer back over the raft after a hit hop, until the partner waits at sync `name`
## (the raft rests at the far bank).
func guard_fn(off: int, name: String = "") -> Callable:
	var ride: Callable = ride_fn(99999, {"off": off, "face": 1})
	return func(lv: LevelBase, h: PlayerBase, n: int) -> int:
		if name != "" and str(_syncs[1 - h.slot]) == name:
			return -1
		if n > 3000:
			return -1
		var f: int = int(ride.call(lv, h, 0 if n < 13 else 13))
		if f < 0 and name != "":
			return 0
		return f


## Curl up (Down + Swap, then Down held) until batted and landed again.
func curl_fn() -> Callable:
	return func(lv: LevelBase, h: PlayerBase, n: int) -> int:
		var st: Dictionary = _st[h.slot]
		if n == 0:
			return D | Defs.IN_SWAP
		if h.curl == PlayerBase.CURL_BALL:
			st["flying"] = true
		if bool(st.get("flying", false)) and h.curl == PlayerBase.CURL_NONE and h.is_grounded():
			return -1
		if n > 300:
			return -1
		return D if h.curl != PlayerBase.CURL_BALL else 0


## Bat the curled partner with a strike (`keys`: U for a lob, 0 for a line drive; `charge` ticks crouched first).
func bat_fn(keys: int, charge: int = 0) -> Callable:
	return func(lv: LevelBase, h: PlayerBase, n: int) -> int:
		var other: PlayerBase = hero(1 - h.slot)
		if other.curl == PlayerBase.CURL_BALL or n > 160:
			return -1
		if other.curl != PlayerBase.CURL_CURLED:
			return 0
		var st: Dictionary = _st[h.slot]
		if not st.has("t0"):
			st["t0"] = n
		var k: int = n - int(st["t0"])
		if k < charge:
			return D
		return (F | keys) if (k - charge) < 9 else 0


## Strike (with `extra`) until the rolled vine anchored in column `col` is unrolled.
func open_vine_fn(col: int, extra: int = 0) -> Callable:
	return func(lv: LevelBase, h: PlayerBase, n: int) -> int:
		for kind: int in Defs.KIND_COUNT:
			for entity: SimEntity in lv.get_kind(kind):
				var vine: Vine = entity as Vine
				if vine != null and vine.vine_x >> 4 == col and vine.unrolled:
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


## A raft reach for two: P1 boards and paddles, P2 boards behind him and guards; both leap onto the far bank.
func cross2(p1: Array, p2: Array, tag: String, bank_x: int, raft_in: int, land_x: int, both_paddle: bool = false) -> void:
	var fight: Dictionary = {"fight": true}
	p1.append(["go", bank_x - 6, fight])
	p1.append(["fn", board_fn(1)])
	p1.append(["fn", center_fn(10)])
	p1.append(["sync", tag + "_p1on"])
	p1.append(["sync", tag + "_p2on"])
	p1.append(["fn", paddle_fn(raft_in)])
	p1.append(["fn", ride_fn(99999, {"off": 8})])
	p1.append(["sync", tag + "_rest"])
	p1.append(["leap", land_x + 24, 8])
	p2.append(["go", bank_x - 40, fight])
	p2.append(["sync", tag + "_p1on"])
	p2.append(["go", bank_x - 6, {"tol": 2}])
	p2.append(["fn", board_fn(1)])
	p2.append(["fn", center_fn(-2)])
	p2.append(["sync", tag + "_p2on"])
	if both_paddle:
		# out of the eddy at the raft's home: both paddle (one paddler's strokes die in its drag)
		p2.append(["fn", paddle_fn(raft_in)])
	p2.append(["fn", guard_fn(-4, tag + "_rest")])
	p2.append(["sync", tag + "_rest"])
	p2.append(["wait", 8])
	p2.append(["leap", land_x, 8])


## A floe line for two (the co-op files give a floe a 24-tick delay): P1 hops floe after floe; P2 follows one floe
## behind - he hops onto floe k once P1 has left it (P1 past its centre by 30 px), so each floe carries each hero for a
## few ticks and nobody lands on the other's head.
func floes2(p1: Array, p2: Array, tag: String, edge_x: int, centres: Array, land_x: int, last_up: int = 7,
		p2_land_off: int = 24) -> void:
	var fight: Dictionary = {"fight": true}
	p1.append(["go", edge_x - 2, fight])
	p1.append(["fn", wait_fight_fn(no_foe_near(90))])
	p1.append(["sync", tag])
	p2.append(["go", edge_x - 24, fight])
	p2.append(["sync", tag])
	var all: Array = centres.duplicate()
	all.append(-1)
	for i: int in all.size():
		var tx: int = cx(int(all[i])) if int(all[i]) >= 0 else land_x
		p1.append(["fn", hop_fn(tx + 6, 7 if int(all[i]) >= 0 else last_up)])
		var ahead: int = cx(int(all[i])) + 30 if int(all[i]) >= 0 else land_x - 4
		p2.append(["until", partner_beyond(ahead), 0])
		p2.append(["fn", hop_fn((tx - 6) if int(all[i]) >= 0 else land_x - p2_land_off, 7 if int(all[i]) >= 0 else last_up)])


## True when the partner's x is at least `x` (on the ground or in the air).
func partner_beyond(x: int) -> Callable:
	return func(lv: LevelBase, hh: PlayerBase) -> bool:
		return hero(1 - hh.slot).sim_pos.x >= x


## True when every drop platform whose cell column is in `cols` waits at its home, unridden.
func floes_home(cols: Array) -> Callable:
	return func(lv: LevelBase, h: PlayerBase) -> bool:
		for kind: int in Defs.KIND_COUNT:
			for entity: SimEntity in lv.get_kind(kind):
				var d: DropPlatform = entity as DropPlatform
				if d != null and cols.has(d.sim_pos.x >> 4):
					if d.state != DropPlatform.State.WAIT or d.sim_pos.y != d.home.y or d.ridden:
						return false
		return true


func column_risen(col: int, rows: int) -> Callable:
	return func(lv: LevelBase, h: PlayerBase) -> bool:
		for kind: int in Defs.KIND_COUNT:
			for entity: SimEntity in lv.get_kind(kind):
				var c: RisingColumn = entity as RisingColumn
				if c != null and c.sim_pos.x >> 4 == col and c.risen >= rows:
					return true
		return false


func build() -> Array:
	var fight: Dictionary = {"fight": true}
	var p1: Array = []
	var p2: Array = []
	p1.append(["mark", "beach A"])
	p1.append(["run", cx(18), fight])
	p2.append(["wait", 6])
	p2.append(["run", cx(15), fight])
	cross2(p1, p2, "r1", 23 * 16, 424, cx(41))
	p1.append(["run", cx(48), fight])
	p2.append(["run", cx(45), fight])
	cross2(p1, p2, "r2", 51 * 16, 872, cx(72), true)
	# --- the blowholes: P1 first, then P2; P1 fetches letter B while P2 waits on the plateau ---
	p1.append(["mark", "beach B"])
	p1.append(["run", cx(79), fight])
	p1.append(["fn", launch_fn(cx(82), cx(86))])
	p1.append(["sync", "p1_plateau"])
	p1.append(["sync", "p2_plateau"])
	p1.append(["fn", launch_fn(cx(88), cx(91))])
	p1.append(["fn", wait_fight_fn(no_foe_near(110))])
	p1.append(["go", cx(91), {"tol": 2}])
	p1.append(["leap", cx(95), 4])
	p1.append(["sync", "letter_done"])
	p2.append(["run", cx(76), fight])
	p2.append(["sync", "p1_plateau"])
	p2.append(["fn", launch_fn(cx(82), cx(85))])
	p2.append(["sync", "p2_plateau"])
	p2.append(["go", cx(84) + 4, {"tol": 3}])
	p2.append(["fn", wait_fight_fn(func(lv: LevelBase, h: PlayerBase) -> bool:
		var a: PlayerBase = hero(0)
		return a.is_grounded() and a.sim_pos.x >= cx(94) and a.sim_pos.y >= 22 * 16 - 2)])
	p2.append(["sync", "letter_done"])
	p1.append(["run", cx(108), fight])
	p2.append(["run", cx(105), fight])
	cross2(p1, p2, "r3", 113 * 16, 1864, cx(140), true)
	# --- the Shellback of beach D (cols 143-147): P2 baits in front of it, P1 jumps over and strikes its back ---
	for p: Array in [p1, p2]:
		p.append(["fn", shell_pair_fn(141 * 16, 150 * 16, 0, 140 * 16 + 4, 2372, 2300, 2345)])
		p.append(["sync", "shell_d"])
	# --- the fish pools ---
	for slot: int in 2:
		var p: Array = p1 if slot == 0 else p2
		for pool: int in [149, 156, 163]:
			p.append(["go", pool * 16 - 20 - slot * 22, fight])
			p.append(["sync", "pool%d" % pool])
			if slot == 1:
				# fighting while the partner jumps ahead (the leaping fish go for the hero who stands still)
				p.append(["fn", wait_fight_fn(partner_past(pool * 16 + 70))])
				p.append(["go", pool * 16 - 20, {"tol": 3}])
			p.append(["fn", pool_fn(pool * 16 + 24, 45)])
			p.append(["leap", (pool + 3) * 16 + 20 + (1 - slot) * 24, 8])
	# --- gate 'dune': P1 holds plate A, P2 to plate B through the lower corridor, P1 through the upper one ---
	p1.append(["mark", "dune"])
	p1.append(["run", cx(176), fight])
	p1.append(["go", 181 * 16 + 16, {"tol": 3}])
	p1.append(["sync", "on_a"])
	p1.append(["until", func(lv: LevelBase, h: PlayerBase) -> bool:
		var b: PlayerBase = hero(1)
		return b.is_grounded() and b.sim_pos.x >= 194 * 16 + 4, D])
	p1.append(["sync", "on_b"])
	p1.append(["fn", hop_fn(cx(183) + 8, 6)])
	p1.append(["fn", hop_fn(cx(184) + 10, 6)])
	p1.append(["until", column_risen(186, 2), 0])
	p1.append(["run", cx(193), {}])
	p1.append(["until", func(lv: LevelBase, h: PlayerBase) -> bool: return h.is_grounded() and h.sim_pos.y == FY, R])
	p1.append(["sync", "dune_done"])
	p2.append(["go", cx(174), fight])
	p2.append(["sync", "on_a"])
	p2.append(["until", func(lv: LevelBase, h: PlayerBase) -> bool:
		for kind: int in Defs.KIND_COUNT:
			for entity: SimEntity in lv.get_kind(kind):
				if entity is RisingColumn and (entity as RisingColumn).sim_pos.x >> 4 == 190:
					return (entity as RisingColumn).risen >= 2
		return false, 0])
	p2.append(["run", 194 * 16 + 4, {}])
	p2.append(["go", 194 * 16 + 16, {"tol": 3}])
	p2.append(["sync", "on_b"])
	p2.append(["until", func(lv: LevelBase, h: PlayerBase) -> bool:
		var a: PlayerBase = hero(0)
		return a.sim_pos.x >= cx(192), D])
	p2.append(["sync", "dune_done"])
	# --- checkpoint 4, the feast kit, gate 'stack' ---
	p1.append(["run", cx(211), fight])
	p1.append(["go", cx(212), {"tol": 3}])
	p1.append(["fn", hop_fn(3432, 9)])
	p1.append(["fn", hop_fn(3470, 5)])
	p1.append(["go", 3470, {"tol": 1}])
	p1.append(["face", 1])
	p1.append(["sync", "bat_ready"])
	p1.append(["fn", curl_fn()])
	p1.append(["mark", "lobbed"])
	p1.append(["go", 219 * 16 + 10, {"tol": 2}])
	p1.append(["face", -1])
	p1.append(["fn", open_vine_fn(218, D)])
	p1.append(["go", 222 * 16, {"tol": 3}])
	p1.append(["sync", "both_up"])
	p2.append(["run", cx(208), fight])
	p2.append(["go", cx(212) - 20, {"tol": 3}])
	p2.append(["until", func(lv: LevelBase, h: PlayerBase) -> bool:
		var a: PlayerBase = hero(0)
		return a.is_grounded() and a.sim_pos.y == 25 * 16 and absi(a.sim_pos.x - 3470) <= 1, 0])
	p2.append(["fn", hop_fn(3440, 9)])
	# against the step's face (his box stops at x 3449)
	p2.append(["go", 3448, {"tol": 2}])
	p2.append(["face", 1])
	p2.append(["sync", "bat_ready"])
	p2.append(["wait", 3])
	p2.append(["fn", bat_fn(U)])
	p2.append(["until", func(lv: LevelBase, h: PlayerBase) -> bool:
		for kind: int in Defs.KIND_COUNT:
			for entity: SimEntity in lv.get_kind(kind):
				var vine: Vine = entity as Vine
				if vine != null and vine.vine_x >> 4 == 218:
					return vine.unrolled
		return false, 0])
	p2.append(["wait", 10])
	p2.append(["go", cx(218) - 2, {"tol": 3}])
	p2.append(["fn", climb_fn(18 * 16)])
	p2.append(["run", cx(220), {}])
	p2.append(["sync", "both_up"])
	p1.append(["run", cx(235), fight])
	p1.append(["hold", R])
	p2.append(["wait", 10])
	p2.append(["run", cx(234), fight])
	p2.append(["hold", R])
	return [p1, p2]
