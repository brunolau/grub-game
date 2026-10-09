extends "res://tools/autoplay/recorders/d6/bot_w6_l2b_coop.gd"
## The two-stream route of w6_l2b_coop (D6), second fight plan: the climb and gate 'vent' of bot_w6_l2b_coop.gd, then
## the co-op Old Mangrove played from the root ledges and the pinned fist:
##  - P2 waits on the lower root ledge under the hand's resting place, crouched while the hand shakes and sweeps;
##  - P1 waits on the lower ledge's right part; when a long fist rest lines up with the hand's next rest, he jumps onto
##    the resting fist without Jump held (he PINS it: no punch while an active hero stands on it), walks to its right
##    end and, while the hand rests, hops and clubs the face; P2 high-strikes the resting hand on P1's hop - the twin;
##    P1 lands on the fist again (a new pin); hops reset the pin before it flings him; with the rest running out he
##    jumps back onto the lower ledge;
##  - stage 3: P2 baits the knuckle armour from the floor left of the stuck fist (the nearer hero), P1 drops from the
##    lower ledge on the wrist side and clubs the fist on the way down.

const P1_WAIT: int = 104
const P2_SPOT: int = 74
const HOP_X: int = 206
const FIST_Y: int = 128
const S3_P1: int = 138
const S3_P2: int = 85
const S3_P2_WAIT: int = 34
const SWEEP_TICKS: int = 21
const HATCH_X: int = 112      ## the lower ledge's hatch cells (cols 7-8): never crouch there unless dropping

var _fb: Dictionary = {"p1": "ledge", "k": 0, "hop_t": -1000, "p2": "ledge", "p2k": 0}


func header() -> String:
	var desc: String = """# The %s two-stream route of Heart of the Mangrove in co-op (designer D6; recorded from
# build/d6/bot_w6_l2b_coop2.gd, P1|P2; club only, never S): up the trunk ahead of the rising tar, P2 one ledge behind
# P1; gate 'vent' - both into the vent room, both heave the boulder four tiles onto the two deadly tar vents (one hero
# alone only strains), both up over it and the step; the climb to the landing; then the co-op Old Mangrove (%d twin
# hits, then %d on the stuck fist): P1 jumps from the lower root ledge onto the resting fist without Jump held and pins
# it, hops on it and clubs the face while P2, on the lower ledge under the hand's resting place (crouched while it
# sweeps), high-strikes the resting hand on his hop - the twin; in stage 3 P2 stands on the lower ledge just left of
# the stuck fist (the nearer hero: the knuckle armour turns to him) and P1 drops through the ledge's rotten hatch cells
# on the wrist side, clubbing the fist on the way down; the fire-starter and the team exit. No role waits 243 ticks
# without input (G33).
"""
	if expert:
		return "# route: level=w6_l2b_coop difficulty=expert players=2 ends=exit after=tally expect=wipes:0,x2_gates:1,unlocked:true\n" \
				+ desc % ["Expert", 4, 3]
	return "# route: level=w6_l2b_coop difficulty=beginner players=2 ends=exit after=tally expect=wipes:0,x2_gates:1,unlocked:true\n" \
			+ desc % ["Beginner", 3, 2]


# --- Reading the boss ---------------------------------------------------------------------------------------------

## Ticks until the upper hand rests (0 = resting now); 999 while it draws back. wf10: the co-op hand shakes only once
## the fist has rested MANGROVE_COOP_SHAKE_AFTER_REST ticks (and its pause ran out); a fist that is not resting: 999.
func _hand_eta(tree: Mangrove) -> int:
	var ht: int = tree._hand_timer
	match tree.get_hand_state():
		Mangrove.Hand.REST:
			return 0
		Mangrove.Hand.SWEEP:
			return maxi(SWEEP_TICKS - ht, 1)
		Mangrove.Hand.SHAKE:
			return Mangrove.MANGROVE_SHAKE_TICKS - ht + SWEEP_TICKS
		Mangrove.Hand.AWAY:
			if tree.get_fist_state() != Mangrove.Fist.REST:
				return 999
			var wait: int = maxi(Mangrove.MANGROVE_HAND_PAUSE - ht,
					Mangrove.MANGROVE_COOP_SHAKE_AFTER_REST - tree._fist_timer)
			return maxi(wait, 0) + Mangrove.MANGROVE_SHAKE_TICKS + SWEEP_TICKS
	return 999


## Ticks left of the fist's rest (-1 while it is not resting). wf10: in stage 1 a resting fist waits for the hand's
## whole cycle - as long as the bot needs.
func _rest_left(tree: Mangrove) -> int:
	if tree.get_fist_state() != Mangrove.Fist.REST:
		return -1
	if tree.get_stage() == 1 and not tree._rest_saw_hand:
		return 9999
	return tree._fist_len - tree._fist_timer


## The hand is shaking (late) or sweeping: anything that rises over the lower ledge now meets it.
func _sweep_danger(tree: Mangrove) -> bool:
	var hand: int = tree.get_hand_state()
	if hand == Mangrove.Hand.SWEEP:
		return true
	if hand == Mangrove.Hand.SHAKE:
		return true
	return hand == Mangrove.Hand.AWAY and _shake_in(tree) <= 6


## wf10: ticks until the hand's ledge shake (the co-op shake waits for a fist that rested 44 ticks); 999 = unknown.
func _shake_in(tree: Mangrove) -> int:
	if tree.get_hand_state() != Mangrove.Hand.AWAY:
		return 0
	var eta: int = _hand_eta(tree)
	return 999 if eta >= 999 else eta - Mangrove.MANGROVE_SHAKE_TICKS - SWEEP_TICKS


## A leaf falling over the hero (within 110 px, 26 px aside): the direction away from it, else 0.
func _dodge(h: PlayerBase, lo: int, hi: int) -> int:
	for entity: SimEntity in level.get_kind(Defs.Kind.ENEMY_PROJECTILE):
		if entity.get("spent") == true:
			continue
		var dx: int = entity.sim_pos.x - h.sim_pos.x
		var dy: int = h.sim_pos.y - entity.sim_pos.y
		if absi(dx) < 26 and dy > -2 and dy < 110:
			var away: int = -1 if dx >= 0 else 1
			var x: int = _cx(h)
			if away < 0 and x - 30 < lo:
				away = 1
			elif away > 0 and x + 30 > hi:
				away = -1
			return R if away > 0 else L
	return 0


## Where the hero stands (chamber px): "upper" root ledge, "lower" root ledge, the resting "fist", the "floor", or "air".
func _where(h: PlayerBase) -> String:
	if not h.is_grounded():
		return "air"
	var x: int = _cx(h)
	var y: int = _cy(h)
	if y <= UPPER_Y + 4:
		return "upper"
	if y >= LEDGE_Y - 4 and y <= LEDGE_Y + 4 and x < 150:
		return "lower"
	if y >= FIST_Y - 6 and y <= FIST_Y + 10 and x >= 156:
		return "fist"
	if y >= FLOOR_Y - 4:
		return "floor"
	return "air"


## On the upper root ledge (where both drop in): wait at its far end while the hand shakes or sweeps along it, else
## walk off its right end onto the lower ledge.
func _upper(h: PlayerBase, tree: Mangrove) -> int:
	if tree.get_stage() == 3:
		return R
	var hand: int = tree.get_hand_state()
	if hand == Mangrove.Hand.SHAKE or hand == Mangrove.Hand.SWEEP 			or (hand == Mangrove.Hand.AWAY and _shake_in(tree) <= 24):
		return L if _cx(h) > 26 else 0
	return R


func _set1(state: String) -> void:
	if opts.has("p1trace"):
		var tree: Mangrove = mangrove()
		var h: PlayerBase = hero(0)
		print("P1 t=%d %s -> %s at %s g%d rest %d hand %d/%d pin %d cd %d" % [t, _fb["p1"], state,
			Vector2i(_cx(h), _cy(h)), int(h.is_grounded()), _rest_left(tree), tree.get_hand_state(), tree._hand_timer,
			tree._pinned, tree.hit_cooldown])
	_fb["p1"] = state
	_fb["k"] = 0


func p1_boss_fn() -> Callable:
	return func(lv: LevelBase, h: PlayerBase, n: int) -> int:
		var tree: Mangrove = mangrove()
		if tree == null or tree.dead or n > 14000:
			return -1
		var key: String = "%d/%d" % [tree.get_stage(), tree.hp]
		if key != str(_fb.get("key", "")):
			_fb["key"] = key
			print("BOSS t=%d stage %d hp %d P1 %s P2 %s twins %d" % [t, tree.get_stage(), tree.hp,
				Vector2i(_cx(h), _cy(h)), Vector2i(_cx(hero(1)), _cy(hero(1))), tree.twins])
		if opts.has("btrace") and n % 4 == 0:
			print("B t=%d P1 %s %s g%d | P2 %s %s | fist %d rest %d hand %d/%d pin %d cd %d ft %d ht %d" % [t,
				_fb["p1"], Vector2i(_cx(h), _cy(h)), int(h.is_grounded()), _fb["p2"],
				Vector2i(_cx(hero(1)), _cy(hero(1))), tree.get_fist_state(), _rest_left(tree), tree.get_hand_state(),
				tree._hand_timer, tree._pinned, tree.hit_cooldown, tree._face_tick, tree._hand_tick])
		_fb["k"] = int(_fb["k"]) + 1
		if tree._dying >= 0:
			return 0
		if tree.get_stage() == 3:
			return _p1_stage3(h, tree)
		return _p1_stage1(h, tree)


## On the floor in stage 1 (knocked down, or a missed jump): back up onto the lower ledge at once.
func _from_floor(h: PlayerBase) -> int:
	var x: int = _cx(h)
	if x > 150:
		return L | U
	if x > 136:
		return L
	return U


func _p1_stage1(h: PlayerBase, tree: Mangrove) -> int:
	var x: int = _cx(h)
	var where: String = _where(h)
	var k: int = int(_fb["k"])
	var state: String = str(_fb["p1"])
	match state:
		"ledge":
			match where:
				"air":
					return 0
				"upper":
					return _upper(h, tree)
				"floor":
					return _from_floor(h)
				"fist":
					_set1("pinned")
					return 0
			# on the lower ledge
			if _sweep_danger(tree):
				return D if x < HATCH_X - 4 else L
			var dodge: int = _dodge(h, 86, 140)
			if dodge != 0:
				return dodge
			var eta: int = _hand_eta(tree)
			var rest: int = _rest_left(tree)
			var board: bool = tree.get_hand_state() == Mangrove.Hand.AWAY and eta >= int(opts.get("eta_lo", "50")) \
					and eta <= int(opts.get("eta_hi", "84")) and rest >= eta + int(opts.get("rest_margin", "36"))
			if board and absi(x - P1_WAIT) <= 4 and h.facing > 0:
				_set1("board")
				_fb["bj"] = -1
				return R
			var w: int = _walk(h, x, P1_WAIT)
			if w != 0:
				return w
			return R if h.facing < 0 else 0
		"board":
			# along the lower ledge to its end, then a jump onto the resting fist: Jump held 7 ticks, then released (no
			# Up on the landing: a pin)
			var bj: int = int(_fb.get("bj", -1))
			if bj < 0:
				if where == "lower" and x < 128:
					return R
				if where == "lower":
					_fb["bj"] = t
					return U | R
				_set1("ledge")
				return 0
			if where != "air" and t - bj > 2:
				_set1("pinned" if where == "fist" else "ledge")
				return 0
			var keys: int = U if t - bj < 7 else 0
			if x < HOP_X - 10:
				keys |= R
			elif x > HOP_X - 2:
				keys |= L
			return keys
		"pinned":
			if where == "air":
				return 0
			if where != "fist":
				_set1("ledge")
				return 0
			var rest2: int = _rest_left(tree)
			var hand: int = tree.get_hand_state()
			var danger: bool = _sweep_danger(tree)
			if rest2 < 30 or tree._pinned >= 56:
				if not danger or tree._pinned >= 60:
					_set1("retreat")
					return L
				return 0
			var w2: int = _walk(h, x, HOP_X)
			if w2 != 0:
				return w2
			if h.facing < 0:
				return R
			var twin_hop: bool = hand == Mangrove.Hand.REST and tree._hand_timer <= 30 \
					and tree.hit_cooldown <= 4 and t - int(_fb["hop_t"]) > 24
			var reset_hop: bool = tree._pinned >= 46 and not danger and hand != Mangrove.Hand.REST
			if twin_hop or reset_hop:
				_set1("hop")
				_fb["hop_t"] = t
				_fb["twin_hop"] = twin_hop
				return U
			return 0
		"hop":
			if k <= 1:
				return U
			if k <= 6:
				return F
			if where != "air" and k > 8:
				_set1("pinned" if where == "fist" else "ledge")
				return 0
			return 0
		"retreat":
			# along the fist's top to its left part, then a jump back onto the lower ledge
			if where == "fist" and k < 40:
				if x > 190:
					return L
				_fb["rj"] = t
				return L | U
			if where != "air":
				_set1("ledge")
				return 0
			var air: int = 0
			if t - int(_fb.get("rj", -100)) < 7:
				air |= U
			if x > 120:
				air |= L
			return air
	_set1("ledge")
	return 0


func _p1_stage3(h: PlayerBase, tree: Mangrove) -> int:
	var x: int = _cx(h)
	var where: String = _where(h)
	var k: int = int(_fb["k"])
	var state: String = str(_fb["p1"])
	var fist: int = tree.get_fist_state()
	if not state.begins_with("s3"):
		if where == "air":
			if state != "retreat":
				return 0
			return (L if x > 120 else 0) | (U if t - int(_fb.get("rj", -100)) < 7 else 0)
		if where == "fist":
			# still on the fist when stage 3 began: back onto the lower ledge
			if x > 190:
				return L
			_set1("retreat")
			_fb["rj"] = t
			return L | U
		_set1("s3")
		state = "s3"
	if state == "s3_drop":
		# crouch on the hatch (it gives way) and keep Down held until under it, then a forward strike at the stuck
		# fist's wrist side (on the way down or from the floor)
		var sk: int = int(_fb.get("sk", -1))
		if where == "lower" and k <= 12:
			return D
		if where == "air":
			if sk < 0 and _cy(h) >= int(opts.get("drop_fy", "116")):
				_fb["sk"] = t
				return F
			if sk >= 0 and t - sk < 6:
				return F
			return D if sk < 0 else 0
		if where == "floor" and sk < 0 and fist == Mangrove.Fist.STUCK:
			_fb["sk"] = t
			return F
		if where == "floor" and sk >= 0 and t - sk < 6:
			return F
		_fb["sk"] = -1
		_set1("s3")
		return 0
	if where == "air":
		return 0
	if where == "upper":
		return _upper(h, tree)
	var bug: int = _bug_flags(h, level, tree)
	if where == "fist":
		return L | U
	if where == "floor":
		# back up onto the lower ledge (straight up through the hatch): a fresh press of Jump every other tick
		if h.is_striking():
			return 0
		if x > 140:
			return L
		return U if t % 2 == 0 else 0
	# on the lower ledge's hatch: wait over the wrist side, facing left; drop when the fist sticks and the partner holds
	# the bait spot (the nearer hero: the knuckle armour faces him)
	var p2: PlayerBase = hero(1)
	var bait: bool = _where(p2) == "lower" and absi(_cx(p2) - S3_P2) <= 2
	if fist == Mangrove.Fist.STUCK and tree._fist_timer <= 4 and absi(x - S3_P1) <= 2 and h.facing < 0 \
			and tree.hit_cooldown == 0 and bait:
		_set1("s3_drop")
		_fb["sk"] = -1
		return D
	if bug >= 0:
		return bug
	var dodge: int = _dodge(h, 116, 142)
	if dodge != 0:
		return dodge
	var w: int = _walk(h, x, S3_P1)
	if w != 0:
		return w
	if h.facing > 0:
		return L
	return 0


func _set2(state: String) -> void:
	_fb["p2"] = state
	_fb["p2k"] = 0


func p2_boss_fn() -> Callable:
	return func(lv: LevelBase, h: PlayerBase, n: int) -> int:
		var tree: Mangrove = mangrove()
		if tree == null or tree.dead or n > 14000:
			return -1
		_fb["p2k"] = int(_fb["p2k"]) + 1
		if tree._dying >= 0:
			return 0
		if tree.get_stage() == 3:
			return _p2_stage3(h, tree)
		return _p2_stage1(h, tree)


func _p2_stage1(h: PlayerBase, tree: Mangrove) -> int:
	var x: int = _cx(h)
	var where: String = _where(h)
	if str(_fb["p2"]) == "strike":
		var k: int = int(_fb["p2k"])
		if k <= 6:
			return U | F
		if k <= 9:
			return 0
		_set2("ledge")
	match where:
		"air":
			return 0
		"upper":
			return _upper(h, tree)
		"floor":
			return _from_floor(h)
		"fist":
			return L | U
	var hand: int = tree.get_hand_state()
	var window: int = tree.twin_window()
	var face_lit: bool = tree._face_tick >= 0 and tree._face_slot == 0 \
			and Sim.total_ticks - tree._face_tick <= window - 9
	var on_hop: bool = t - int(_fb["hop_t"]) == 2 and bool(_fb.get("twin_hop", false))
	if hand == Mangrove.Hand.REST and (on_hop or face_lit) and h.facing < 0 and absi(x - P2_SPOT) <= 6 \
			and not h.is_striking() and tree._hand_timer <= Mangrove.MANGROVE_HAND_REST_TICKS - 9:
		_set2("strike")
		return U | F
	if _sweep_danger(tree):
		return D
	var dodge: int = _dodge(h, 64, 124)
	if dodge != 0:
		return dodge
	var w: int = _walk(h, x, P2_SPOT)
	if w != 0:
		return w
	if h.facing > 0:
		return L
	return 0


func _p2_stage3(h: PlayerBase, tree: Mangrove) -> int:
	# the bait: on the lower ledge just left of the stuck fist's centre (about 51 px from it; the striker, in the air on
	# its right, 53 or more): the
	# knuckle armour faces him, the partner strikes the wrist side
	var x: int = _cx(h)
	var where: String = _where(h)
	if where == "air":
		return 0
	if where == "upper":
		return _upper(h, tree)
	if where == "fist":
		return L | U
	if where == "floor":
		if h.is_striking():
			return 0
		if x > 136:
			return L
		return U if t % 2 == 0 else 0
	var stuck: bool = tree.get_fist_state() == Mangrove.Fist.STUCK
	var bug: int = _bug_flags(h, level, tree)
	if bug >= 0 and not stuck:
		return bug
	if not stuck:
		var dodge: int = _dodge(h, 60, 110)
		if dodge != 0:
			return dodge
	var w: int = _walk(h, x, S3_P2)
	if w != 0:
		return w
	return R if h.facing < 0 else 0


## A braking walk to x `goal` (chamber px): 0 when there or coasting to it (the solo bot's _walk).
func _walk(h: PlayerBase, x: int, goal: int) -> int:
	var dx: int = goal - x
	if absi(dx) <= 2:
		return 0
	var v: int = absi(h.xvel) / 16
	var stop: int = 0
	var j: int = v - 1
	while j > 0:
		stop += j
		j -= 1
	if signi(h.xvel) == signi(dx) and absi(dx) <= stop + 1:
		return 0
	return R if dx > 0 else L


## A bug that is out of the ground and near on the hero's floor: turn and club it (the solo bot's _bug_flags); never
## chase one to the right into the punches' reach while the fist is not stuck. -1 when there is none.
func _bug_flags(h: PlayerBase, lv: LevelBase, tree: Mangrove = null) -> int:
	var best: EnemyBase = null
	for entity: SimEntity in lv.get_kind(Defs.Kind.ENEMY):
		var bug: Digger = entity as Digger
		if bug == null or not bug.is_copy() or not bug.awake or bug.dead or not bug.tangible:
			continue
		if absi(bug.sim_pos.y - h.sim_pos.y) > 20 or absi(bug.sim_pos.x - h.sim_pos.x) > 60:
			continue
		if best == null or absi(bug.sim_pos.x - h.sim_pos.x) < absi(best.sim_pos.x - h.sim_pos.x):
			best = bug
	if best == null:
		return -1
	var dir: int = 1 if best.sim_pos.x >= h.sim_pos.x else -1
	var stuck: bool = tree != null and tree.get_fist_state() == Mangrove.Fist.STUCK
	if dir > 0 and not stuck and h.sim_pos.x - OXP > 56 and h.sim_pos.y - OYP == FLOOR_Y \
			and absi(best.sim_pos.x - h.sim_pos.x) > 30:
		return -1
	if h.facing != dir and not h.is_striking():
		return R if dir > 0 else L
	if absi(best.sim_pos.x - h.sim_pos.x) <= 44:
		return F
	return 0


## G33 keep-alive (botlib): a hero quiet for KEEPALIVE_TICKS taps Down - except on the lower root ledge's hatch cells,
## where a crouch drops him through: there he swings the club instead (input too, harmless).
func _keepalive(s: int, f: int) -> int:
	if players < 2 or f != 0:
		_quiet[s] = 0
		return f
	_quiet[s] += 1
	var h: PlayerBase = hero(s)
	if _quiet[s] >= KEEPALIVE_TICKS and h != null and h.is_grounded() and not h.is_mounted() \
			and h.state != Defs.HeroState.CLIMB and not h.dead and not h.down:
		_quiet[s] = 0
		var cx: int = h.sim_pos.x - OXP
		var cy: int = h.sim_pos.y - OYP
		if cx >= HATCH_X - 16 and cx < 160 and absi(cy - LEDGE_Y) <= 4:
			return F
		return D
	return 0


## The leader waits for the partner on the climb (option lead_rows, used for the Expert recording): P1 holds still -
## standing on his ledge or hanging on the vine - while P2 is more than lead_rows rows under him, so the rising view
## (which follows the footing of the tribe) never leaves either of them behind (the leash).
func _leader_waits(h: PlayerBase) -> bool:
	if h.slot != 0 or not opts.has("lead_rows"):
		return false
	var b: PlayerBase = hero(1)
	if b == null or b.dead or b.is_down():
		return false
	return b.sim_pos.y - h.sim_pos.y > int(opts["lead_rows"]) * 16


func vine_fn(row: int) -> Callable:
	var base: Callable = super.vine_fn(row)
	return func(lv: LevelBase, h: PlayerBase, n: int) -> int:
		if _leader_waits(h) and (h.state == Defs.HeroState.CLIMB or h.is_grounded()) and not (h.is_grounded() \
				and h.sim_pos.y <= row * 16 and n > 2):
			return 0
		return base.call(lv, h, n)


func ladder_fn(row: int) -> Callable:
	var base: Callable = super.ladder_fn(row)
	return func(lv: LevelBase, h: PlayerBase, n: int) -> int:
		if _leader_waits(h) and h.is_grounded() and h.sim_pos.y > row * 16:
			return 0
		return base.call(lv, h, n)
