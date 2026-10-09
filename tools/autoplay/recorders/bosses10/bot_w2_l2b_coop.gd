extends "res://tools/autoplay/recorders/db2/botx.gd"
## The two-stream routes of w2_l2b_coop "Brute's Den" (DB2): recorded by probe_work.gd --bot --players=2.
## Gate 'den': P1 waits by the upper lizard in the keeper hall, P2 drops down the shaft to the lower one in the bone
## pit; when both stand in reach they strike on the same tick (the bond), P2 climbs the vine back up and the door is
## open. The co-op Brute: both heroes fight side by side, P1 a few px nearer (so he is the first target and P2's
## first blow counts); after every counted blow the Brute targets the hitter and the other's blow counts.

const TUNNEL: int = 160         ## feet y in the bone tunnel (row 9)
const PIT: int = 304            ## feet y in the bone pit (row 18)
const DEN: int = 272            ## feet y on the den floor (row 16)
const LIZ_UP: Vector2i = Vector2i(424, 160)
const LIZ_LOW: Vector2i = Vector2i(328, 304)
const REACH: int = 38           ## hero x this far from a lizard's feet point: its club box covers the lizard

var _ready: Array = [false, false]
var _fire_at: int = -1
var _fst: Array = [{}, {}]


func header() -> String:
	var mode: String = "expert" if expert else "beginner"
	return ("# route: level=w2_l2b_coop difficulty=%s players=2 ends=exit after=tally "
		+ "expect=wipes:0,eggs:0,x2_gates:1,boss_hits:%d\n") % [mode, 4 if expert else 2]


func build() -> Array:
	var p1: Array = []
	var p2: Array = []
	# --- the bone tunnel: both walk to the keeper hall ---
	p1.append(["keys", 2, R])
	p2.append(["keys", 2, R])
	p1.append(["go", LIZ_UP.x - REACH, {"tol": 2}])
	p2.append(["go", 352, {"tol": 2}])
	p2.append(["fn", hop_over_fn(LIZ_UP)])
	p2.append(["go", 456, {"tol": 2}])
	p2.append(["mark", "at the shaft"])
	p2.append(["run", 470])
	p2.append(["until", stands_on_fn(PIT), R])
	p2.append(["go", LIZ_LOW.x + REACH, {"tol": 2}])
	p2.append(["face", -1])
	p1.append(["face", 1])
	both([p1, p2], ["sync", "bond"])
	p1.append(["fn", bond_fn(LIZ_UP, -1)])
	p2.append(["fn", bond_fn(LIZ_LOW, 1)])
	both([p1, p2], ["sync", "bond_done"])
	p1.append(["mark", "the bond is broken"])
	# --- P2 climbs back up the vine; the door is open ---
	p2.append(["go", 486, {"tol": 2}])
	p2.append(["fn", climb_fn(10)])
	p2.append(["mark", "up the vine"])
	p1.append(["fn", hold_fn(partner_fn(func(_lv: LevelBase, hh: PlayerBase) -> bool:
		return hh.is_grounded() and hh.sim_pos.y <= TUNNEL))])
	both([p1, p2], ["sync", "door"])
	p1.append(["until", air_fn(32, 9), 0])
	p2.append(["until", air_fn(32, 9), 0])
	p1.append(["go", 440, {"tol": 2}])
	p1.append(["fn", hop_fn(520, 8)])
	p1.append(["go", 600, {"tol": 2}])
	p2.append(["go", 580, {"tol": 2}])
	both([p1, p2], ["sync", "den"])
	# --- into the den: both drop together ---
	p1.append(["run", 664])
	p2.append(["wait", 2])
	p2.append(["run", 660])
	p1.append(["until", stands_on_fn(DEN), R])
	p2.append(["until", stands_on_fn(DEN), R])
	p1.append(["mark", "in the den"])
	p1.append(["fn", fight_fn(0)])
	p2.append(["fn", fight_fn(1)])
	both([p1, p2], ["sync", "won"])
	p1.append(["mark", "the Brute is beaten"])
	p1.append(["fn", exit_fn()])
	p2.append(["fn", exit_fn()])
	return [p1, p2]


func stands_on_fn(y: int) -> Callable:
	return func(_lv: LevelBase, h: PlayerBase) -> bool:
		return h.is_grounded() and h.sim_pos.y == y


func lizard(anchor: Vector2i) -> EnemyBase:
	return enemy_near(anchor.x, anchor.y, 64)


## The bond: stand REACH px beside the lizard (on `side`: -1 = left of it), both heroes ready -> both strike on the
## same tick; done when the lizard is dead.
func bond_fn(anchor: Vector2i, side: int) -> Callable:
	return func(_lv: LevelBase, h: PlayerBase, n: int) -> int:
		var s: int = h.slot
		var liz: EnemyBase = lizard(anchor)
		if liz == null or liz.dead:
			return -1
		if n > 1500:
			return -1
		if _fire_at >= 0 and t >= _fire_at:
			var k: int = t - _fire_at
			if k < 8:
				return F
			if k < 12:
				return 0
			return -1 if liz == null or liz.dead else 0
		var want: int = liz.sim_pos.x + side * REACH
		var dx: int = want - h.sim_pos.x
		var face: int = -side
		_ready[s] = absi(dx) <= 6 and h.is_grounded() and h.facing == face
		if _ready[0] and _ready[1] and _fire_at < 0:
			_fire_at = t + 1
		if absi(dx) > 4:
			return R if dx > 0 else L
		if h.facing != face:
			return R if face > 0 else L
		return 0


func brute() -> Brute:
	for entity: SimEntity in level.get_kind(Defs.Kind.BOSS):
		var b: Brute = entity as Brute
		if b != null:
			return b
	return null


## The fight, per hero. Both stand left of the Brute, P1 37 px and P2 42 px from its feet point (P1 nearer: the first
## target, so P2's first blow counts). While it watches, the hero it does NOT target (the striker) charges by crouching
## and strikes high; the target crouches at his spot (charging for his turn, never idle). Anything else (chest beat,
## jump, attack, pound, back hop, grab): keep 100 px away and crouch.
func fight_fn(slot: int) -> Callable:
	return func(_lv: LevelBase, h: PlayerBase, n: int) -> int:
		var st: Dictionary = _fst[h.slot]
		var b: Brute = brute()
		if b == null or b.dead or b.get_state() == Brute.State.DYING:
			return -1
		if n > 6000:
			return -1
		if int(st.get("strike", 0)) > 0:
			st["strike"] = int(st["strike"]) - 1
			return (F | U) if int(st["strike"]) > 1 else 0
		var state: int = b.get_state()
		var tgt: PlayerBase = b._target_hero()
		if h.slot == 0 and t % 4 == 0:
			print("BRUTE t=%d st=%d hp=%d pos=%s v=%d,%d g=%s face=%d tgt=P%d cd=%d | P1 x=%d ch=%d | P2 x=%d ch=%d" % [t,
				state, b.hp, b.sim_pos, b.xvel, b.yvel, str(b.get("_grounded")), b.facing,
				(tgt.slot + 1) if tgt != null else 0, b.hit_cooldown, hero(0).sim_pos.x, hero(0).charge,
				hero(1).sim_pos.x, hero(1).charge])
		var striker: bool = tgt != null and tgt != h
		var dir: int = 1 if b.sim_pos.x >= h.sim_pos.x else -1
		var dist: int = absi(b.sim_pos.x - h.sim_pos.x)
		var spot: int = 37 if slot == 0 else 42
		var toward: int = R if dir > 0 else L
		var away: int = L if dir > 0 else R
		var grounded: bool = bool(b.get("_grounded"))
		var counter: int = int(b.get("_counter"))
		var high: bool = state == Brute.State.JUMP or state == Brute.State.ATTACK
		var falling: bool = high and not grounded and b.yvel > 0 and absi(b.xvel) < 8
		var first: bool = b.last_hitter == null
		var cornered: bool = (away == L and h.sim_pos.x < 672) or (away == R and h.sim_pos.x > 960)
		# Before the first blow: both at their spots side by side (P1 nearer, the target); P2 strikes when charged.
		if first and grounded and state == Brute.State.WATCH:
			var mv: int = _approach(h, dist, spot, toward, away)
			if mv >= 0:
				return mv
			if h.facing != dir:
				return toward
			if striker and h.charge >= 20 and b.hit_cooldown == 0:
				st["strike"] = 10
				return F | U
			return D
		# The target keeps out of the rush range (75 px) and charges for his next turn.
		if not striker:
			if dist < 88 and not cornered:
				return away
			return D
		# The striker: while it watches, staggers back to its feet, beats its chest or opens its hands, step in and
		# strike high; charge first when the blow needs it.
		var calm: bool = grounded and (state == Brute.State.WATCH or state == Brute.State.GRAB_BEAT
			or (state == Brute.State.JUMP and counter < 40)) and not bool(b.get("_cover"))
		if calm:
			if b.hp > 25 and h.charge < 20:
				if dist < 60 and not cornered:
					return away
				return D
			var mv2: int = _approach(h, dist, 38, toward, away)
			if mv2 >= 0:
				return mv2
			if h.facing != dir:
				return toward
			if b.hit_cooldown == 0:
				st["strike"] = 10
				return F | U
			return D
		if state == Brute.State.STAGGER:
			if dist < 60 and not cornered:
				return away
			return D
		# Under its very high jump: at the spot as it comes down (the club's high front box is out 6-8 ticks after the
		# press), before its first punch.
		if (h.charge > 8 or b.hp <= 25) and high and not grounded and int(b.get("_air_ticks")) > 6 and not bool(b.get("_cover")) 				and absi(b.xvel) < 8:
			var mv3: int = _approach(h, dist, 38, toward, away)
			if mv3 >= 0:
				return mv3
			if h.facing != dir:
				return toward
			var height: int = DEN - b.sim_pos.y
			var vy: float = float(b.yvel) / 16.0
			if falling and float(height) <= 6.0 * vy + 21.0 and b.hit_cooldown == 0:
				st["strike"] = 10
				return F | U
			return D
		# keep away (attack, pound, back hop, a hop or leap) and charge
		if dist < 96 and not cornered:
			return away
		return D


## A step toward the spot `spot` px from the Brute (with braking, so he never runs into its body), a step back when
## he stands too close; -1 when he stands on the spot.
func _approach(h: PlayerBase, dist: int, spot: int, toward: int, away: int) -> int:
	var err: int = dist - spot
	var speed: int = absi(h.xvel)
	var stop: int = (speed * speed) / (2 * (12 >> h.ice) * 16) + 1
	var moving_in: bool = h.xvel != 0 and ((toward == R and h.xvel > 0) or (toward == L and h.xvel < 0))
	if err > 2:
		if moving_in and err <= stop + 2:
			return 0
		return toward
	if err < -2:
		return away
	if h.xvel != 0:
		return 0
	return -1


## After the fight: step back from the shower of bonuses, let the fire-starter come down, then walk into the exit
## totem (col 59), hopping over any skull on the way.
func exit_fn() -> Callable:
	return func(lv: LevelBase, h: PlayerBase, n: int) -> int:
		var st: Dictionary = _fst[h.slot]
		if n < 60:
			var x0: int = 712 + h.slot * 20
			if h.sim_pos.x > x0 + 3:
				return L
			return D if n % 20 == 0 else 0
		var waiting: bool = false
		for entity: SimEntity in lv.get_kind(Defs.Kind.COLLECTIBLE):
			if entity is FireStarter:
				waiting = true
		if waiting and n < 400:
			return D if n % 20 == 0 else 0
		if int(st.get("hop", 0)) > 0:
			st["hop"] = int(st["hop"]) - 1
			return (U | R) if int(st["hop"]) > 6 else R
		for entity: SimEntity in lv.get_kind(Defs.Kind.COLLECTIBLE):
			if entity is Skull:
				var dx: int = entity.sim_pos.x - h.sim_pos.x
				if dx > 8 and dx < 40 and absi(entity.sim_pos.y - h.sim_pos.y) < 24 and h.is_grounded():
					st["hop"] = 18
					return U | R
		return R


## Hop over the upper lizard (the hall is 4 rows high: a short jump clears its 20 px): wait until it stands 56-66 px
## ahead, then jump with Right held until he lands beyond it.
func hop_over_fn(anchor: Vector2i) -> Callable:
	return func(_lv: LevelBase, h: PlayerBase, n: int) -> int:
		var st: Dictionary = _st[h.slot]
		var liz: EnemyBase = lizard(anchor)
		if n > 400:
			return -1
		if not bool(st.get("jumped", false)):
			if liz == null or liz.dead:
				return -1
			var dx: int = liz.sim_pos.x - h.sim_pos.x
			if dx < 56:
				return L
			if dx > 66:
				return R
			if not h.is_grounded():
				return 0
			st["jumped"] = true
			st["t0"] = n
		var k: int = n - int(st["t0"])
		if k < 10:
			return U | R
		if k > 2 and h.is_grounded():
			return -1
		return R
