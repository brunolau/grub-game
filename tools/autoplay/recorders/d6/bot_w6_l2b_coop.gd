extends "res://tools/autoplay/recorders/d6/botlib_v4.gd"
## The two-stream route of w6_l2b_coop (D6): recorded by probe_work.gd --bot --players=2 (P1 | P2).
## The climb: P1 one step ahead, P2 repeating each step once P1 stands on its row (never under him in one column at
## the same time); gate 'vent': both into the vent room, both push the boulder right until it covers both vents, both
## up onto it and the step; the rest of the climb; the landing; then the co-op Old Mangrove (boss_part).

const JX: int = 168
const VR: int = 74
const OXP: int = 20 * 16
const OYP: int = 14 * 16


func header() -> String:
	var desc: String = """# The %s two-stream route of Heart of the Mangrove in co-op (designer D6; recorded from
# build/d6/bot_w6_l2b_coop.gd, P1|P2; club only, never S): up the trunk ahead of the rising tar, P2 one ledge behind
# P1 (each step once P1 stands three rows higher); gate 'vent' - both into the vent room, both heave the boulder four
# tiles onto the two deadly tar vents (one hero alone only strains), both up over it and the step; the climb to the
# landing; then the co-op Old Mangrove (%d twin hits, then %d on the stuck fist): P1 pins the resting fist (lands on it
# without Jump held), jumps off it and clubs the face while P2, crouched on the lower root ledge under the sweep,
# high-strikes the resting hand within the twin window; in stage 3 P2 draws the knuckle armour from the left and P1
# drops from the lower ledge onto the wrist side; the fire-starter and the team exit. No role waits 243 ticks
# without input (G33).
"""
	if expert:
		return "# route: level=w6_l2b_coop difficulty=expert players=2 ends=exit after=tally expect=wipes:0,x2_gates:1,unlocked:true
" 				+ desc % ["Expert", 7, 6]
	return "# route: level=w6_l2b_coop difficulty=beginner players=2 ends=exit after=tally expect=wipes:0,x2_gates:1,unlocked:true
" 			+ desc % ["Beginner", 5, 3]


## Jump straight up the ledges of the column until standing with the feet on row `row`.
func ladder_fn(row: int) -> Callable:
	return func(lv: LevelBase, h: PlayerBase, n: int) -> int:
		if h.is_grounded() and h.sim_pos.y <= row * 16:
			return -1
		if h.state == Defs.HeroState.CLIMB or n > 1200:
			return -1
		var st: Dictionary = _st[h.slot]
		if h.is_grounded():
			var k: int = int(st.get("hold", 0))
			st["hold"] = k + 1
			if k < 10:
				return U
			st["hold"] = 0
			return 0
		st["hold"] = 0
		return U


## Climb the vine above until standing with the feet on row `row`.
func vine_fn(row: int) -> Callable:
	return func(lv: LevelBase, h: PlayerBase, n: int) -> int:
		if h.is_grounded() and h.sim_pos.y <= row * 16 and n > 2:
			return -1
		if n > 1200:
			return -1
		return U


func boulder() -> HeavyBoulder:
	for kind: int in Defs.KIND_COUNT:
		for entity: SimEntity in level.get_kind(kind):
			if entity is HeavyBoulder:
				return entity as HeavyBoulder
	return null


## Both push: hold Right against the boulder until it covers both vents (its left cell at column 11).
func push_fn() -> Callable:
	return func(lv: LevelBase, h: PlayerBase, n: int) -> int:
		var b: HeavyBoulder = boulder()
		if opts.has("ptrace"):
			print("PUSH t=%d slot %d hero %s g%d boulder %s push %d side %d falling %s" % [t, h.slot, h.sim_pos,
				int(h.is_grounded()), b.block, b.push_ticks, b.push_side, b.falling])
		if b.block.position.x >= 11 or n > 600:
			return -1
		return R


## The climb for two, one ledge at a time: P1 does each step; P2 does the same step once P1 stands (or climbs) at
## least 3 rows above that step's target row, so P2 follows one ledge behind - never under P1 in mid-jump, and
## close enough to stay in the view (the rising view follows the footing; a hero more than 3 rows under the leader's
## footing would leave its bottom row). A vine step: P2 grabs the vine once P1 has climbed 3 rows of it.
## steps: ["go", x, row] | ["ladder", row] | ["vine", top_row, bottom_row]
func climb(p1: Array, p2: Array, steps: Array) -> void:
	for step: Array in steps:
		var kind: String = step[0]
		var gate_y: int = 0
		var rise_y: int = -1
		var cmd: Array = []
		if kind == "go":
			gate_y = (int(step[2]) - 3) * 16
			cmd = ["go", int(step[1]), {"tol": 1}]
		elif kind == "ladder":
			gate_y = (int(step[1]) - 3) * 16
			rise_y = int(step[1]) * 16
			cmd = ["fn", ladder_fn(int(step[1]))]
			if step.size() > 2 and str(step[2]) == "top":
				# the landing at the top: P1 has walked off the column along it
				p1.append(cmd)
				var top_y: int = int(step[1]) * 16
				p2.append(["until", func(lv: LevelBase, hh: PlayerBase) -> bool:
					var a: PlayerBase = hero(0)
					return a.is_grounded() and a.sim_pos.y <= top_y and a.sim_pos.x >= 230, 0])
				p2.append(cmd.duplicate())
				continue
		elif kind == "vine":
			gate_y = (int(step[2]) - 3) * 16
			cmd = ["fn", vine_fn(int(step[1]))]
		p1.append(cmd)
		var gy: int = gate_y
		var ry: int = rise_y
		p2.append(["until", func(lv: LevelBase, hh: PlayerBase) -> bool:
			var a: PlayerBase = hero(0)
			var placed: bool = a.is_grounded() or a.state == Defs.HeroState.CLIMB
			if placed and a.sim_pos.y <= gy:
				return true
			# P1 has just jumped off the ledge P2 aims for: go now, one ledge behind him
			return ry >= 0 and not placed and a.yvel < 0 and a.sim_pos.y < ry - 2, 0])
		p2.append(cmd.duplicate())


## A ladder of ledges from `from_row` (exclusive) up to `to_row`, three rows apart.
func ladder(from_row: int, to_row: int) -> Array:
	var out: Array = []
	var r: int = from_row - 3
	while r >= to_row:
		out.append(["ladder", r])
		r -= 3
	return out


func build() -> Array:
	var p1: Array = []
	var p2: Array = []
	p1.append(["mark", "the climb"])
	p2.append(["keys", 2, R])
	var steps: Array = [["go", JX, 118]]
	steps.append_array(ladder(118, 103))
	steps.append(["vine", 95, 103])
	steps.append_array(ladder(95, 83))
	# ledges 80 and 77 (3..8) left of the vent room's solid floor; into the room through its one-way floor (2..6)
	steps.append_array([["go", 104, 83], ["ladder", 80], ["go", 88, 80], ["ladder", 77]])
	climb(p1, p2, steps)
	p1.append(["until", func(lv: LevelBase, hh: PlayerBase) -> bool:
		var b: PlayerBase = hero(1)
		return b.is_grounded() and b.sim_pos.y <= 80 * 16, 0])
	# P1 waits at the room's left wall, so P2 comes up through the one-way floor beside him, not under his feet (a
	# hero rising into his partner's feet becomes his carrier)
	p1.append(["fn", ladder_fn(VR)])
	p1.append(["mark", "vent room"])
	p1.append(["go", 40, {"tol": 2}])
	p1.append(["sync", "in_room"])
	p1.append(["go", 95, {"tol": 2}])
	p2.append(["fn", ladder_fn(VR)])
	p2.append(["sync", "in_room"])
	p2.append(["go", 92, {"tol": 2}])
	p1.append(["sync", "push"])
	p2.append(["sync", "push"])
	p2.append(["mark", "push"])
	p1.append(["fn", push_fn()])
	p2.append(["fn", push_fn()])
	p1.append(["sync", "plugged"])
	p2.append(["sync", "plugged"])
	p1.append(["mark", "plugged"])
	# up onto the boulder and the step, then the ledge over the step
	p1.append(["leap", 196, 8])
	p1.append(["go", 280, {"tol": 2}])
	p1.append(["fn", ladder_fn(69)])
	p2.append(["wait", 10])
	p2.append(["leap", 190, 8])
	p2.append(["go", 266, {"tol": 2}])
	p2.append(["until", func(lv: LevelBase, hh: PlayerBase) -> bool:
		var a: PlayerBase = hero(0)
		return a.is_grounded() and a.sim_pos.y <= 66 * 16, 0])
	p2.append(["go", 280, {"tol": 2}])
	p2.append(["fn", ladder_fn(69)])
	# from ledge 69 (16..18) up to 66 (12..17), the cp ledge 63 and the column again
	var steps2: Array = [["go", 264, 69], ["ladder", 66], ["go", 200, 66], ["ladder", 63], ["go", JX, 63]]
	steps2.append_array(ladder(63, 54))
	# the last jump onto ledge 54 may already catch the vine over it: the vine step climbs on from either
	steps2.append(["vine", 46, 54])
	steps2.append_array(ladder(46, 16))
	steps2.append(["ladder", 13, "top"])
	climb(p1, p2, steps2)
	p1.append(["mark", "the landing"])
	p1.append(["run", 320])
	p1.append(["go", 334, {"tol": 2}])
	p2.append(["run", 296])
	p2.append(["go", 310, {"tol": 2}])
	p1.append(["sync", "landing"])
	p2.append(["sync", "landing"])
	boss_part(p1, p2)
	return [p1, p2]


## The co-op Old Mangrove (DESIGN.md B.2, enemies-B's co-op form): stages 1 and 2 merged into twin hits - P1 pins
## the resting fist (lands on it without Jump held), and when the upper hand rests on the upper root ledge he jumps
## off the fist and clubs the face while P2, crouched on the lower ledge under the sweep, high-strikes the hand; then
## stage 3 - P2 baits the knuckle armour from the left (the nearer hero), P1 drops from the lower ledge on the wrist
## side and clubs the stuck fist in the air. Then the fire-starter and the team exit.
const FLOOR_Y: int = 160
const LEDGE_Y: int = 112
const UPPER_Y: int = 80
const LEDGE_SPOT: int = 112
const P1_HOME: int = 128
const FIST_SPOT: int = 204
const BAIT_WAIT: int = 40
const BAIT_SPOT: int = 62
const STRIKE_X: int = 124

var _boss: Dictionary = {"p1": "home", "p1_t": 0, "jump_tick": -1, "p2_t": 0}


func mangrove() -> Mangrove:
	for entity: SimEntity in level.get_kind(Defs.Kind.BOSS):
		if entity is Mangrove:
			return entity as Mangrove
	return null


func _cx(h: PlayerBase) -> int:
	return h.sim_pos.x - OXP


func _cy(h: PlayerBase) -> int:
	return h.sim_pos.y - OYP


func _walk_to(h: PlayerBase, x: int, tol: int = 3) -> int:
	var dx: int = x - _cx(h)
	if absi(dx) <= tol:
		return 0
	if absi(dx) < 12 and h.xvel != 0:
		return 0
	return R if dx > 0 else L


## Bugs on the floor next to a hero: turn and club (the solo bot's _bug_flags); -1 when none.
func _bugs(h: PlayerBase) -> int:
	var best: EnemyBase = null
	for entity: SimEntity in level.get_kind(Defs.Kind.ENEMY):
		var bug: Digger = entity as Digger
		if bug == null or not bug.is_copy() or not bug.awake or bug.dead:
			continue
		if absi(bug.sim_pos.y - h.sim_pos.y) > 20 or absi(bug.sim_pos.x - h.sim_pos.x) > 60:
			continue
		if best == null or absi(bug.sim_pos.x - h.sim_pos.x) < absi(best.sim_pos.x - h.sim_pos.x):
			best = bug
	if best == null:
		return -1
	var dir: int = 1 if best.sim_pos.x >= h.sim_pos.x else -1
	if h.facing != dir and not h.is_striking():
		return R if dir > 0 else L
	if best.tangible and absi(best.sim_pos.x - h.sim_pos.x) <= 44:
		return F
	return 0


func p1_boss_fn() -> Callable:
	return func(lv: LevelBase, h: PlayerBase, n: int) -> int:
		var tree: Mangrove = mangrove()
		if tree == null or tree.dead or n > 12000:
			return -1
		var before: String = str(_boss["p1"])
		var jt0: int = int(_boss.get("jump_tick", -1))
		if opts.has("twintrace") and jt0 >= 0 and t >= jt0 - 2 and t <= jt0 + 24:
			var b: PlayerBase = hero(1)
			var o: Vector2i = Vector2i(OXP, OYP)
			print("TW t=%d P1 %s st%d strk %s club %s | P2 %s st%d strk %s club %s f%d | face %s hand %s hs%d | ft %d ht %d" % [
				t, h.sim_pos - o, h.state, h.is_striking(), Rect2i(h.club_box.position - o, h.club_box.size),
				b.sim_pos - o, b.state, b.is_striking(), Rect2i(b.club_box.position - o, b.club_box.size), b.facing,
				Rect2i(tree.get_face_box().position - o, tree.get_face_box().size),
				Rect2i(tree.get_hand_rect().position - o, tree.get_hand_rect().size), tree.get_hand_state(),
				tree._face_tick, tree._hand_tick])
		var f: int = _p1_flags(h, tree)
		if str(_boss["p1"]) != before and opts.has("p1trace"):
			print("P1 t=%d %s -> %s at %s fist %d len %d tim %d hand %d pin %d" % [t, before, _boss["p1"],
				Vector2i(_cx(h), _cy(h)), tree.get_fist_state(), tree._fist_len, tree._fist_timer,
				tree.get_hand_state(), tree._pinned])
		var key: String = "%d/%d" % [tree.get_stage(), tree.hp]
		if key != str(_boss.get("key", "")):
			_boss["key"] = key
			print("BOSS t=%d stage %d hp %d P1 %s P2 %s" % [t, tree.get_stage(), tree.hp, Vector2i(_cx(h), _cy(h)),
				Vector2i(_cx(hero(1)), _cy(hero(1)))])
		if opts.has("btrace") and n % 4 == 0:
			print("B t=%d P1 %s %s g%d st %d fist %d@%d len %d tim %d hand %d hp %d pin %d" % [t, _boss["p1"],
				Vector2i(_cx(h), _cy(h)), int(h.is_grounded()), tree.get_stage(), tree.get_fist_state(),
				tree._fist_x - OXP, tree._fist_len, tree._fist_timer, tree.get_hand_state(), tree.hp, tree._pinned])
		return f


func _p1_flags(h: PlayerBase, tree: Mangrove) -> int:
	var x: int = _cx(h)
	var y: int = _cy(h)
	var grounded: bool = h.is_grounded()
	var state: String = str(_boss["p1"])
	_boss["p1_t"] = int(_boss["p1_t"]) + 1
	var k: int = int(_boss["p1_t"])
	var stage: int = tree.get_stage()
	if stage == 3 and state in ["home", "to_fist", "pinned", "back", "jump"]:
		state = "s3_ledge"
		_boss["p1"] = state
		_boss["p1_t"] = 0
		k = 0
	match state:
		"home":
			# On the lower ledge's right part; from the floor, up onto it.
			if grounded and y == FLOOR_Y:
				if x < 140:
					return U
				return (L | U) if x < 170 else L
			if not grounded:
				return 0
			if y == UPPER_Y:
				return _upper_flags(h, tree)
			var hand: int = tree.get_hand_state()
			var soon: bool = hand == Mangrove.Hand.SHAKE or (hand == Mangrove.Hand.AWAY \
					and tree._hand_timer >= Mangrove.MANGROVE_HAND_PAUSE - 20)
			var fist_ok: bool = tree.fist_is_springboard() and tree._fist_len - tree._fist_timer >= 45
			if soon and fist_ok and y == LEDGE_Y:
				_boss["p1"] = "to_fist"
				_boss["p1_t"] = 0
				return R
			return _walk_to(h, P1_HOME)
		"to_fist":
			if tree._pinned > 0:
				_boss["p1"] = "pinned"
				_boss["p1_t"] = 0
				return 0
			if not tree.fist_is_springboard() and grounded and y == FLOOR_Y:
				_boss["p1"] = "back"
				_boss["p1_t"] = 0
				return L
			if grounded and y == LEDGE_Y:
				return R
			if grounded and y == FLOOR_Y:
				if absi(x - FIST_SPOT) > 3:
					return _walk_to(h, FIST_SPOT, 3)
				_boss["hop"] = t
				return U
			# in the air: Jump held for 7 ticks (a hop well over the fist's 32 px top), then released so he lands
			# on it without Jump held (a pin, not a launch)
			if t - int(_boss.get("hop", -100)) < 7:
				return U
			return 0
		"pinned":
			if tree._pinned == 0 and grounded and y == FLOOR_Y:
				_boss["p1"] = "back"
				_boss["p1_t"] = 0
				return L
			if grounded and x < 212 and tree._pinned < Mangrove.MANGROVE_PIN_TICKS - 12:
				# along the fist's top towards the trunk: the forward strike then reaches well into the face
				return R
			if tree.get_hand_state() == Mangrove.Hand.REST and h.facing > 0 and grounded:
				_boss["p1"] = "jump"
				_boss["p1_t"] = 0
				_boss["jump_tick"] = t
				return U
			if h.facing < 0:
				return R
			if tree._pinned >= Mangrove.MANGROVE_PIN_TICKS - 6:
				_boss["p1"] = "back"
				_boss["p1_t"] = 0
				return L | U
			return 0
		"jump":
			# a jump off the fist, Jump held 2 ticks, then a forward strike (no Up: Up + Fire is the high strike)
			# while his body rises past the face (feet 100-115 px over the floor... the club box over its rect)
			if k <= 1:
				return U
			if k <= 6:
				return F
			if k <= 9:
				return 0
			if grounded:
				_boss["p1"] = "back"
				_boss["p1_t"] = 0
				return L | U
			return 0
		"back":
			# Off the fist / the floor onto the lower ledge, out of the punches' row.
			if grounded and y == LEDGE_Y:
				_boss["p1"] = "home"
				_boss["p1_t"] = 0
				return 0
			if grounded:
				if x > 150:
					return (L | U) if x < 215 else L
				return U
			return L if x > 136 else 0
		"s3_ledge":
			if grounded and y == FLOOR_Y:
				var bug: int = _bugs(h)
				if bug >= 0:
					return bug
				if x < 140:
					return U
				return (L | U) if x < 170 else L
			if not grounded:
				return 0
			if y == UPPER_Y:
				return R
			if tree.get_fist_state() == Mangrove.Fist.STUCK and tree._fist_timer < Mangrove.MANGROVE_STUCK_TICKS - 12 \
					and absi(x - STRIKE_X) <= 3:
				_boss["p1"] = "s3_drop"
				_boss["p1_t"] = 0
				return D | U
			var g: int = _walk_to(h, STRIKE_X, 2)
			if g != 0:
				return g
			return L if h.facing > 0 else 0
		"s3_drop":
			if k <= 2:
				return D | U
			if not grounded:
				return F if k >= 3 and k <= 5 else 0
			_boss["p1"] = "s3_ledge"
			_boss["p1_t"] = 0
			return 0
	return 0


## On the upper root ledge (where both drop in through the hole): off its end onto the lower ledge while the hand
## stays in the wall; while it shakes, sweeps or rests, wait at the ledge's far end (the solo bot's UPPER_SAFE).
func _upper_flags(h: PlayerBase, tree: Mangrove) -> int:
	var hand: int = tree.get_hand_state()
	if hand == Mangrove.Hand.RETRACT:
		_boss["seen_sweep"] = true
	var out: bool = hand != Mangrove.Hand.AWAY
	var soon: bool = hand == Mangrove.Hand.AWAY and tree._hand_timer >= Mangrove.MANGROVE_HAND_PAUSE - 30
	if bool(_boss.get("seen_sweep", false)) and not out and not soon:
		return R
	if _cx(h) > 29:
		return L
	return 0


func p2_boss_fn() -> Callable:
	return func(lv: LevelBase, h: PlayerBase, n: int) -> int:
		var tree: Mangrove = mangrove()
		if tree == null or tree.dead or n > 12000:
			return -1
		return _p2_flags(h, tree)


func _p2_flags(h: PlayerBase, tree: Mangrove) -> int:
	var x: int = _cx(h)
	var y: int = _cy(h)
	var grounded: bool = h.is_grounded()
	var stage: int = tree.get_stage()
	if stage == 3:
		if grounded and y < FLOOR_Y:
			return R if x < 150 else 0
		if not grounded:
			return 0
		var bug: int = _bugs(h)
		if bug >= 0:
			return bug
		var stuck: bool = tree.get_fist_state() == Mangrove.Fist.STUCK and tree._fist_timer < Mangrove.MANGROVE_STUCK_TICKS - 2
		var spot: int = BAIT_SPOT if stuck else BAIT_WAIT
		var g: int = _walk_to(h, spot, 2)
		if g != 0:
			return g
		return R if h.facing < 0 else 0
	# Twin phase: the lower ledge at LEDGE_SPOT, facing left; crouched while the hand is out; a high strike at the
	# resting hand a few ticks after P1 jumps off the fist.
	if not grounded:
		return 0
	if y == UPPER_Y:
		return _upper_flags(h, tree)
	if y == FLOOR_Y:
		if x > 150:
			return L
		if x < LEDGE_SPOT - 40:
			return R
		return U
	var hand: int = tree.get_hand_state()
	var jt: int = int(_boss["jump_tick"])
	if hand == Mangrove.Hand.REST and jt >= 0 and t >= jt + 2 and t <= jt + 12:
		if h.facing > 0 and not h.is_striking():
			return L
		return U | F
	if hand == Mangrove.Hand.SHAKE or hand == Mangrove.Hand.SWEEP or hand == Mangrove.Hand.RETRACT:
		if absi(x - LEDGE_SPOT) > 3 and hand == Mangrove.Hand.SHAKE:
			return _walk_to(h, LEDGE_SPOT, 3)
		return D
	var g2: int = _walk_to(h, LEDGE_SPOT, 3)
	if g2 != 0:
		return g2
	return L if h.facing > 0 else 0


## After the fight: let the defeat's bonus burst land (some random bonuses roll a skull), then P1 fetches the
## fire-starter (it arcs onto the lower root ledge: jump up through the one-way ledge under it), hopping over skulls on
## the floor, and both walk into the exit totem in the corner. Bugs that are out are clubbed.
var _loot_jump: PackedInt32Array = PackedInt32Array([0, 0])


func loot_fn() -> Callable:
	return func(lv: LevelBase, h: PlayerBase, n: int) -> int:
		if n > 2000:
			return -1
		var s: int = h.slot
		if _loot_jump[s] > 0:
			_loot_jump[s] += 1
			if h.is_grounded() and _loot_jump[s] > 3:
				_loot_jump[s] = 0
			else:
				return U if _loot_jump[s] <= 12 else 0
		if n < 70:
			if not h.is_grounded():
				return 0
			var b0: int = _bugs(h)
			return b0 if b0 >= 0 else 0
		var bug: int = _bugs(h)
		if bug >= 0 and h.is_grounded():
			return bug
		var target: int = 1 * 16 + 8
		var target_y: int = FLOOR_Y
		if s == 0:
			for entity: SimEntity in lv.get_kind(Defs.Kind.COLLECTIBLE):
				if entity is FireStarter and not (entity as FireStarter).collected:
					target = entity.sim_pos.x - OXP
					target_y = entity.sim_pos.y - OYP
		var dx: int = target - _cx(h)
		if not h.is_grounded():
			return R if dx > 2 else (L if dx < -2 else 0)
		if target_y < _cy(h) - 8 and absi(dx) <= 20:
			_loot_jump[s] = 1
			return U
		if _cy(h) < FLOOR_Y - 8 and target_y > _cy(h) + 8:
			return R if _cx(h) < 150 else L
		var dir: int = signi(dx)
		for entity: SimEntity in lv.get_kind(Defs.Kind.COLLECTIBLE):
			var bonus: RandomBonus = entity as RandomBonus
			if bonus == null or bonus.collected or bonus.roll != ItemTable.Roll.SKULL:
				continue
			var sdx: int = bonus.sim_pos.x - h.sim_pos.x
			if absi(bonus.sim_pos.y - h.sim_pos.y) < 24 and signi(sdx) == dir and absi(sdx) <= 34 and absi(sdx) >= 18:
				_loot_jump[s] = 1
				return (R if dir > 0 else L) | U
		if absi(dx) <= 2:
			return L
		return R if dx > 0 else L


func boss_part(p1: Array, p2: Array) -> void:
	p1.append(["mark", "into the chamber"])
	p1.append(["keys", 4, R])
	p1.append(["until", func(lv: LevelBase, hh: PlayerBase) -> bool: return hh.is_grounded() and hh.sim_pos.y > 14 * 16, 0])
	p2.append(["wait", 12])
	p2.append(["run", 360])
	p2.append(["until", func(lv: LevelBase, hh: PlayerBase) -> bool: return hh.is_grounded() and hh.sim_pos.y > 14 * 16, R])
	p1.append(["fn", p1_boss_fn()])
	p2.append(["fn", p2_boss_fn()])
	p1.append(["mark", "beaten"])
	p1.append(["fn", loot_fn()])
	p2.append(["fn", loot_fn()])
