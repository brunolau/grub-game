extends "res://tools/autoplay/recorders/d6/botlib_v4.gd"
## The two-stream route of w6_l1_coop (D6): recorded by probe_work.gd --bot --players=2 (P1 | P2).
## Shore and pit together; both board the raft (P1 paddles, P2 guards); gate 'sunk': P1 curls at the bank's edge, P2
## bats him over (Expert: a charged strike after a crouch), P1 stands on the latch plate, the sunken raft rises and P2
## walks over; the deck path; gate 'root': P2 stands at Old Root's face, P1 jumps on his head holding Jump (the
## Shoulder Hop), clubs the rolled vine down, P2 climbs it; both drop behind the root; P1 tames Chomper and drives,
## P2 jumps on behind as the gunner; the flats; both dismount and walk to the exit totem.

const F_ROW: int = 26
const FY: int = 26 * 16
const ROOT0: int = 166
const ROOT_TOP: int = 18
const EDGE_B: int = 93 * 16      # the near bank's edge on Beginner (the block fills column 92)
const EDGE_E: int = 92 * 16      # ... on Expert
const PLATE_X: int = 108 * 16 + 16


func header() -> String:
	var desc: String = """# The %s two-stream route of Bubbling Fen in co-op (designer D6; recorded from build/d6/bot_w6_l1_coop.gd,
# P1|P2; club only, never S): the shore and the tar pit together; the raft for two (both paddle it out of the jetty's
# eddy, then P1 paddles and P2 stands guard);
# gate 'sunk' - P1 curls up at the near bank (Down + Swap), P2 bats him over the %d cells of open tar%s,
# P1 stands on the latch plate and the sunken raft rises for P2; the root deck; gate 'root' - P2 stands at Old
# Root's face, P1
# lands on his head holding Jump (Shoulder Hop) onto the root and clubs the rolled vine down, P2 climbs it, both drop
# behind; P1 tames wild Chomper and drives, P2 jumps on behind as the gunner; the tar flats; both get off and walk
# into the exit totem. No role waits 243 ticks without input (a waiting hero taps Down after 150 quiet ticks, G33).
"""
	if expert:
		return "# route: level=w6_l1_coop difficulty=expert players=2 ends=exit after=tally expect=wipes:0,eggs:0,x2_gates:2,min_checkpoints:5
" 				+ desc % ["Expert", 9, " (charged)"]
	return "# route: level=w6_l1_coop difficulty=beginner players=2 ends=exit after=tally expect=wipes:0,eggs:0,x2_gates:2,min_checkpoints:5
" 			+ desc % ["Beginner", 8, ""]


func raft_near(x: int) -> Raft:
	var best: Raft = null
	for kind: int in Defs.KIND_COUNT:
		for entity: SimEntity in level.get_kind(kind):
			var raft: Raft = entity as Raft
			if raft != null and (best == null or absi(raft.sim_pos.x - x) < absi(best.sim_pos.x - x)):
				best = raft
	return best


func mount() -> Mount:
	for kind: int in Defs.KIND_COUNT:
		for entity: SimEntity in level.get_kind(kind):
			if entity is Mount:
				return entity as Mount
	return null


func paddle_fn(until_x: int) -> Callable:
	return func(lv: LevelBase, h: PlayerBase, n: int) -> int:
		var raft: Raft = raft_near(h.sim_pos.x)
		if raft.sim_pos.x >= until_x or n > 900:
			return -1
		var st: Dictionary = _st[h.slot]
		if bool(st.get("pressed", false)):
			st["pressed"] = false
			return 0
		if h.is_striking():
			return 0
		st["pressed"] = true
		return F


func drift_fn(until_x: int) -> Callable:
	return func(lv: LevelBase, h: PlayerBase, n: int) -> int:
		var raft: Raft = raft_near(h.sim_pos.x)
		if raft.sim_pos.x >= until_x or (n > 20 and raft.cd == 0 and raft.rx == 0) or n > 900:
			return -1
		return 0


## Stand and strike at whatever comes close (no walking: a raft is narrow) until `done` is true.
func guard_fn(done: Callable) -> Callable:
	return func(lv: LevelBase, h: PlayerBase, n: int) -> int:
		if done.call(lv, h) or n > 2400:
			return -1
		var st: Dictionary = _st[h.slot]
		if int(st.get("striking", 0)) > 0:
			st["striking"] = int(st["striking"]) - 1
			return F if int(st["striking"]) > 3 else 0
		if not h.is_grounded():
			return 0
		for entity: SimEntity in lv.get_kind(Defs.Kind.ENEMY):
			var foe: EnemyBase = entity as EnemyBase
			if foe == null or foe.dead or not foe.awake or not foe.tangible:
				continue
			var dx: int = foe.sim_pos.x - h.sim_pos.x
			var dy: int = foe.sim_pos.y - h.sim_pos.y
			if absi(dy) > 30 or absi(dx) > 40:
				continue
			if signi(dx) != h.facing and dx != 0:
				return R if dx > 0 else L
			if absi(dx) >= 12 and absi(dx) <= 36:
				st["striking"] = 9
				return F
		return 0


## Bounce on wild Chomper until he is tame and the hero sits on him (from the stump top).
func tame_fn() -> Callable:
	return func(lv: LevelBase, h: PlayerBase, n: int) -> int:
		if h.is_mounted() or n > 900:
			return -1
		var rex: Mount = mount()
		var dx: int = rex.sim_pos.x - h.sim_pos.x
		if not h.is_grounded():
			var keys: int = U
			if dx > 2:
				keys |= R
			elif dx < -2:
				keys |= L
			return keys
		if dx < 56:
			return U | R
		return 0


## Ride Chomper right to `until_x` (bot_w6_l1.gd's ride_fn: bite what comes, hop where a wall stops him).
func ride_fn(until_x: int) -> Callable:
	return func(lv: LevelBase, h: PlayerBase, n: int) -> int:
		var rex: Mount = mount()
		if rex.sim_pos.x >= until_x or not h.is_mounted() or n > 2400:
			return -1
		var st: Dictionary = _st[h.slot]
		var cool: int = int(st.get("bite_cool", 0))
		if cool > 0:
			st["bite_cool"] = cool - 1
		var vr: float = rex.xvel / 16.0
		var nearest: float = 9999.0
		var near_v: float = 0.0
		for entity: SimEntity in lv.get_kind(Defs.Kind.ENEMY):
			var foe: EnemyBase = entity as EnemyBase
			if foe == null or foe.dead or not foe.awake or not foe.tangible:
				continue
			var dy: float = foe.sim_pos.y - rex.sim_pos.y
			var left: float = foe.sim_pos.x - foe.box_xo - rex.sim_pos.x
			var vf: float = foe.xvel / 16.0
			if dy < -20.0 and dy > -60.0 and left > 0.0 and left < 60.0 and cool == 0:
				st["bite_cool"] = 8
				return R | F
			if dy < -20.0 or dy > 10.0 or left < 0.0:
				continue
			if left < nearest:
				nearest = left
				near_v = vf
		if nearest < 9000.0:
			var r4: float = nearest + (near_v - vr) * 4.0
			var r5: float = nearest + (near_v - vr) * 5.0
			if cool == 0 and ((r4 >= 20.0 and r4 < 40.0) or (r4 >= 40.0 and r5 >= 20.0 and r5 < 40.0)):
				st["bite_cool"] = 8
				return F
			if nearest < 90.0:
				if near_v < -0.5:
					return 0
				if nearest > 60.0:
					return R
				return R if (n % 3 != 0 and nearest > 34.0) else 0
		var keys: int = R
		if rex.grounded and rex.xvel == 0 and n > 3 and n % 8 < 3:
			keys |= U
		return keys


## The gunner: sit on Chomper behind the driver and strike whatever comes near, until the driver gets off.
func gunner_fn() -> Callable:
	return func(lv: LevelBase, h: PlayerBase, n: int) -> int:
		var driver: PlayerBase = hero(0)
		if not h.is_mounted() or not driver.is_mounted() or n > 3000:
			return -1
		var st: Dictionary = _st[h.slot]
		# G33: the gunner keeps giving input (a strike every 120 quiet ticks) so he never dozes on Chomper's back.
		st["quiet"] = int(st.get("quiet", 0)) + 1
		if int(st["quiet"]) >= 120 and int(st.get("striking", 0)) == 0:
			st["striking"] = 9
		if int(st.get("striking", 0)) > 0:
			st["striking"] = int(st["striking"]) - 1
			st["quiet"] = 0
			return F if int(st["striking"]) > 3 else 0
		for entity: SimEntity in lv.get_kind(Defs.Kind.ENEMY):
			var foe: EnemyBase = entity as EnemyBase
			if foe == null or foe.dead or not foe.awake or not foe.tangible:
				continue
			var dx: int = foe.sim_pos.x - h.sim_pos.x
			var dy: int = foe.sim_pos.y - h.sim_pos.y
			if dy > 10 or dy < -60 or absi(dx) > 44:
				continue
			if signi(dx) != h.facing and dx != 0:
				return R if dx > 0 else L
			if absi(dx) >= 10:
				st["striking"] = 9
				return F
		return 0


## Jump on Chomper's back behind the driver (the gunner's seat).
func board_fn() -> Callable:
	return func(lv: LevelBase, h: PlayerBase, n: int) -> int:
		if h.is_mounted() or n > 600:
			return -1
		var rex: Mount = mount()
		var target: int = rex.sim_pos.x - 14 * rex.facing
		var dx: int = target - h.sim_pos.x
		if not h.is_grounded():
			if dx > 2:
				return R | U
			if dx < -2:
				return L | U
			return U
		if absi(dx) < 70:
			return U | (R if dx > 0 else L)
		return R if dx > 0 else L


## The Shoulder Hop: straight up from the partner's spot, land on his head with Jump held, then right onto the ledge.
func hop_fn(top_row: int) -> Callable:
	return func(lv: LevelBase, h: PlayerBase, n: int) -> int:
		if (h.is_grounded() and h.sim_pos.y == top_row * 16 and n > 4) or n > 200:
			return -1
		var st: Dictionary = _st[h.slot]
		if not bool(st.get("bounced", false)):
			if n > 6 and h.yvel <= -150:
				st["bounced"] = true
			else:
				return U
		return U | R


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


## Bat the curled partner: (Expert) crouch to charge, then a forward strike.
func bat_fn() -> Callable:
	return func(lv: LevelBase, h: PlayerBase, n: int) -> int:
		var other: PlayerBase = hero(0)
		if other.curl == PlayerBase.CURL_BALL or n > 120:
			return -1
		if other.curl != PlayerBase.CURL_CURLED:
			return 0
		var crouch: int = 20 if expert else 0
		var st: Dictionary = _st[h.slot]
		if not st.has("t0"):
			st["t0"] = n
		var k: int = n - int(st["t0"])
		if k < crouch:
			return D
		return F if (k - crouch) < 9 else 0


func vine_up(row: int) -> Callable:
	return func(lv: LevelBase, h: PlayerBase, n: int) -> int:
		if h.is_grounded() and h.sim_pos.y == row * 16 and n > 2:
			return -1
		if n > 800:
			return -1
		return U


## Strike (with `extra`) until the rolled vine anchored in `cell` is unrolled.
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


func both_grounded_past(x: int) -> Callable:
	return func(lv: LevelBase, hh: PlayerBase) -> bool:
		var a: PlayerBase = hero(0)
		var b: PlayerBase = hero(1)
		return a.sim_pos.x >= x and b.sim_pos.x >= x and a.is_grounded() and b.is_grounded()


func partner_past(x: int) -> Callable:
	return func(lv: LevelBase, hh: PlayerBase) -> bool:
		var other: PlayerBase = hero(1 - hh.slot)
		return other.sim_pos.x >= x and other.is_grounded()


func build() -> Array:
	var fight: Dictionary = {"fight": true}
	var p1: Array = []
	var p2: Array = []
	var edge: int = EDGE_E if expert else EDGE_B
	# --- the shore and the pit (P2 a little behind) ---
	for slot: int in 2:
		var p: Array = p1 if slot == 0 else p2
		if slot == 1:
			p.append(["wait", 10])
		p.append(["mark", "shore"])
		p.append(["run", cx(20), fight])
		p.append(["jump", 1, 8])
		p.append(["run", cx(40) - slot * 20, fight])
		p.append(["mark", "pit"])
		if slot == 1:
			p.append(["until", partner_past(cx(50)), 0])
		p.append(["run", cx(46), fight])
		p.append(["go", cx(49), {"tol": 2}])
		p.append(["until", func(lv: LevelBase, h: PlayerBase) -> bool: return h.is_grounded() and h.sim_pos.y == FY - 16 \
				and h.sim_pos.x > 50 * 16, U])
		p.append(["go", cx(57) - slot * 20, fight])
	# --- the raft: P1 boards first and paddles, P2 boards and guards ---
	p1.append(["mark", "raft"])
	p1.append(["run", 944])
	p1.append(["keys", 2, R])
	p1.append(["until", func(lv: LevelBase, h: PlayerBase) -> bool: return h.is_grounded() and h.xvel == 0, 0])
	p1.append(["keys", 1, L])
	p1.append(["sync", "aboard"])
	p1.append(["fn", paddle_fn(1000)])
	p1.append(["fn", drift_fn(99999)])
	p1.append(["fn", paddle_fn(1318)])
	p1.append(["sync", "landed"])
	p2.append(["until", func(lv: LevelBase, h: PlayerBase) -> bool:
		var a: PlayerBase = hero(0)
		return a.sim_pos.x > 950 and a.is_grounded() and a.xvel == 0, 0])
	p2.append(["run", 940])
	p2.append(["keys", 2, R])
	p2.append(["until", func(lv: LevelBase, h: PlayerBase) -> bool: return h.is_grounded() and h.xvel == 0, 0])
	p2.append(["sync", "aboard"])
	# both heave the raft out of the jetty's eddy (one paddler alone cannot beat the eddy and the drag), then P2 guards
	p2.append(["face", -1])
	p2.append(["fn", paddle_fn(978)])
	p2.append(["fn", guard_fn(func(lv: LevelBase, h: PlayerBase) -> bool:
		return raft_near(h.sim_pos.x).sim_pos.x >= 1318)])
	p2.append(["sync", "landed"])
	# --- gate 'sunk' ---
	p1.append(["mark", "sunk"])
	p1.append(["go", edge - 7, {"tol": 1}])
	p1.append(["face", 1])
	p1.append(["sync", "bat_ready"])
	p1.append(["fn", curl_fn()])
	p1.append(["mark", "batted over"])
	p1.append(["go", PLATE_X, {"tol": 3, "max": 60}])
	p1.append(["fn", func(lv: LevelBase, h: PlayerBase, n: int) -> int:
		for kind: int in Defs.KIND_COUNT:
			for entity: SimEntity in lv.get_kind(kind):
				if entity is Plate and (entity as Plate).presses > 0:
					return -1
		if n > 200:
			return -1
		if PLATE_X > h.sim_pos.x + 8:
			return R
		if PLATE_X < h.sim_pos.x - 8:
			return L
		return 0])
	p1.append(["wait", 12])
	p1.append(["sync", "bridge"])
	p2.append(["go", edge - 7 - 24, {"tol": 1}])
	p2.append(["face", 1])
	p2.append(["sync", "bat_ready"])
	p2.append(["wait", 3])
	p2.append(["fn", bat_fn()])
	p2.append(["sync", "bridge"])
	p2.append(["mark", "crossing"])
	if expert:
		p2.append(["go", EDGE_E - 18, {"tol": 2}])
		p2.append(["leap", EDGE_E + 40, 6])
	p2.append(["run", PLATE_X - 30])
	# --- the deck path (P2 follows P1) ---
	for slot: int in 2:
		var p: Array = p1 if slot == 0 else p2
		p.append(["mark", "deck"])
		p.append(["wait", int(opts.get("deck_wait", "0"))])
		p.append(["run", cx(155) - slot * 30, fight])
	# --- gate 'root' ---
	p2.append(["mark", "root"])
	p2.append(["run", ROOT0 * 16 - 14, fight])
	p2.append(["until", func(lv: LevelBase, h: PlayerBase) -> bool: return h.is_grounded() and h.xvel == 0, R])
	p2.append(["sync", "hop"])
	p2.append(["wait", 6])
	p2.append(["until", func(lv: LevelBase, h: PlayerBase) -> bool:
		var a: PlayerBase = hero(0)
		return a.is_grounded() and a.sim_pos.y == ROOT_TOP * 16, 0])
	p2.append(["sync", "vine_open"])
	p2.append(["fn", vine_up(ROOT_TOP)])
	p2.append(["sync", "both_up"])
	p1.append(["go", ROOT0 * 16 - 60, fight])
	p1.append(["until", func(lv: LevelBase, h: PlayerBase) -> bool:
		var b: PlayerBase = hero(1)
		return b.is_grounded() and b.xvel == 0 and b.sim_pos.x >= ROOT0 * 16 - 20, 0])
	p1.append(["fn", func(lv: LevelBase, h: PlayerBase, n: int) -> int:
		var b: PlayerBase = hero(1)
		if absi(h.sim_pos.x - b.sim_pos.x) <= 1 and h.xvel == 0:
			return -1
		if n > 300:
			return -1
		var dx: int = b.sim_pos.x - h.sim_pos.x
		if absi(dx) <= 1:
			return 0
		if absi(h.xvel) > 0 and absi(dx) < 6:
			return 0
		return R if dx > 0 else L])
	p1.append(["sync", "hop"])
	p1.append(["fn", hop_fn(ROOT_TOP)])
	p1.append(["mark", "on the root"])
	p1.append(["go", ROOT0 * 16 + 12, {"tol": 2}])
	p1.append(["face", -1])
	p1.append(["fn", open_vine_fn(Vector2i(ROOT0 - 1, ROOT_TOP), D)])
	p1.append(["sync", "vine_open"])
	p1.append(["go", ROOT0 * 16 + 40, {"tol": 3}])
	p1.append(["sync", "both_up"])
	# --- behind the root, checkpoint 3, Chomper ---
	p1.append(["run", cx(183), fight])
	p1.append(["mark", "chomper"])
	p1.append(["go", cx(184), fight])
	p1.append(["leap", 2991, 10])
	p1.append(["fn", tame_fn()])
	p1.append(["mark", "riding"])
	p1.append(["sync", "gunner"])
	p1.append(["fn", ride_fn(cx(238))])
	p1.append(["mark", "flats done"])
	p1.append(["keys", 12, 0])
	p1.append(["keys", 2, D | U])
	p1.append(["until", func(lv: LevelBase, h: PlayerBase) -> bool: return h.is_grounded() and not h.is_mounted(), 0])
	p1.append(["run", cx(251), fight])
	p1.append(["hold", R])
	p2.append(["run", cx(180), fight])
	p2.append(["until", func(lv: LevelBase, h: PlayerBase) -> bool: return hero(0).is_mounted(), 0])
	p2.append(["go", cx(184), fight])
	p2.append(["leap", 2991, 10])
	p2.append(["fn", board_fn()])
	p2.append(["mark", "gunner"])
	p2.append(["sync", "gunner"])
	p2.append(["fn", gunner_fn()])
	p2.append(["until", func(lv: LevelBase, h: PlayerBase) -> bool: return h.is_grounded() and not h.is_mounted(), D | U])
	p2.append(["run", cx(250), fight])
	p2.append(["hold", R])
	return [p1, p2]
