extends "res://tools/autoplay/recorders/db1/p5/db1lib.gd"
## w1_l2_coop two-stream routes (DB1, wf10): closed-loop duo macros (P1 | P2), Beginner and Expert.

const FLOOR: int = 1696
const MOUND: int = 1600
const DECK93: int = 1504


func header() -> String:
	var d: String = "expert" if expert else "beginner"
	return "# route: level=w1_l2_coop difficulty=%s players=2 ends=exit after=tally expect=wipes:0,eggs:0,x2_gates:2\n" % d


func stop_at() -> String:
	return str(opts.get("stop", ""))


func build() -> Array:
	var fight: Dictionary = {"fight": true}
	var p1: Array = []
	var p2: Array = []
	# --- the forest floor: the inset spot, the clay pot; the Shellback by the hut (P2 baits, P1 strikes its back) ---
	p2.append(["keys", 2, R])
	p1.append(["go", 148, {"tol": 1, "fight": true}])
	p1.append(["face", 1])
	p1.append(["fn", strike_open_fn(Vector2i(9, 106), D)])
	p2.append(["go", 110, {"tol": 3}])
	p2.append(["sync", "inset"])
	p1.append(["sync", "inset"])
	p1.append(["go", 280, {"tol": 1, "fight": true}])
	p1.append(["face", 1])
	p1.append(["fn", strike_open_fn(Vector2i(19, 105), 0)])
	p2.append(["go", 240, {"tol": 3}])
	p1.append(["sync", "pot"])
	p2.append(["sync", "pot"])
	for p: Array in [p1, p2]:
		p.append(["fn", shell_pair_fn(340, 440, 0, int(opts.get("bait_x", "290")), 600,
				int(opts.get("jump_lo", "372")), int(opts.get("jump_hi", "410")))])
		p.append(["sync", "turtle"])
	# the crate, the checkpoint
	p1.append(["go", 434, {"tol": 2, "fight": true}])
	p1.append(["face", 1])
	p1.append(["fn", strike_open_fn(Vector2i(28, 105), 0)])
	p2.append(["go", 400, {"tol": 3}])
	p1.append(["sync", "crate"])
	p2.append(["sync", "crate"])
	# --- gate 'treehouse': P2 carries, P1 shoulder-hops onto the deck and clubs the vine down, P2 climbs it ---
	treehouse(p1, p2)
	if stop_at() == "treehouse":
		return [p1, p2]
	climb1(p1, p2)
	if stop_at() == "climb1":
		return [p1, p2]
	climb2(p1, p2)
	if stop_at() == "climb2":
		return [p1, p2]
	pulley(p1, p2)
	if stop_at() == "pulley":
		return [p1, p2]
	if opts.has("top_wait"):
		for p: Array in [p1, p2]:
			p.append(["wait", int(opts["top_wait"])])
			p.append(barrier("top_wait"))
	descent1(p1, p2)
	if stop_at() == "descent1":
		return [p1, p2]
	descent2(p1, p2)
	if stop_at() == "descent2":
		return [p1, p2]
	descent3(p1, p2)
	if stop_at() == "descent3":
		return [p1, p2]
	descent4(p1, p2)
	if stop_at() == "descent4":
		return [p1, p2]
	if opts.has("probe72"):
		for p: Array in [p1, p2]:
			p.append(guard_cmd(func(_lv: LevelBase, _h: PlayerBase) -> bool: return false, 400, "probe72"))
		return [p1, p2]
	return [p1, p2]


## The deck of row 84: the two bats hanging under the deck above (high strikes when they are low) and the snapper
## between them (P1), P2 guarding behind; off the deck's right end onto the lowest deck (row 96), its hopper; off its
## left end onto the forest floor and left into the exit totem, both.
func descent4(p1: Array, p2: Array) -> void:
	var fight: Dictionary = {"fight": true}
	p1.append(["go", 972, {"tol": 2}])
	p1.append(["fn", kill_fn(1000, 1280, 40, 900)])
	p1.append(["go", 996, {"tol": 2}])
	p1.append(["fn", lunge_strike_fn(1064, 1344, int(opts.get("snap_at", "1016")))])
	p1.append(["go", 1068, {"tol": 2}])
	p1.append(["fn", kill_fn(1096, 1280, 40, 900)])
	p2.append(["go", 930, {"tol": 3}])
	p2.append(guard_cmd(func(_lv: LevelBase, _h: PlayerBase) -> bool: return enemy_near(1096, 1280, 40) == null, 2000, "row84", 70))
	p1.append(["sync", "row84"])
	p2.append(["sync", "row84"])
	# the barrel at the deck's end (80, 83), then off the end (col 82) onto the lowest deck, P2 right behind
	p1.append(["go", 1262, fight])
	p1.append(["face", 1])
	p1.append(["fn", strike_open_fn(Vector2i(80, 83), 0, 120)])
	p2.append(["go", 1200, fight])
	p1.append(["sync", "barrel84"])
	p2.append(["sync", "barrel84"])
	p1.append(["run", 1336, fight])
	p1.append(["until", func(_lv: LevelBase, h: PlayerBase) -> bool: return h.is_grounded() and h.sim_pos.y >= 1530, R])
	p1.append(["go", 1400, {"tol": 3}])
	p2.append(["run", 1336, fight])
	p2.append(["until", func(_lv: LevelBase, h: PlayerBase) -> bool: return h.is_grounded() and h.sim_pos.y >= 1530, 0])
	p1.append(["sync", "deck96"])
	p2.append(["sync", "deck96"])
	# the hopper of the lowest deck (76, 95): both club it as it comes
	p1.append(["go", 1300, fight])
	p2.append(["go", 1330, fight])
	for p: Array in [p1, p2]:
		p.append(["fn", kill_fn(1224, 1520, 160, 600, {"awake_only": true, "charge": opts.has("h96_charge")})])
		p.append(barrier("hopper96"))
	# off the lowest deck's left end (col 68) onto the forest floor, then left into the exit totem (56, 105)
	p1.append(["run", 1080, fight])
	p1.append(["until", func(_lv: LevelBase, h: PlayerBase) -> bool: return h.is_grounded() and h.sim_pos.y >= 1690, L])
	p2.append(guard_cmd(func(_lv: LevelBase, _h: PlayerBase) -> bool: return hero(0).sim_pos.y > 1560, 900, "drop96"))
	p2.append(["run", 1080, fight])
	p2.append(["until", func(_lv: LevelBase, h: PlayerBase) -> bool: return h.is_grounded() and h.sim_pos.y >= 1690, L])
	p1.append(["sync", "floor"])
	p2.append(["sync", "floor"])
	p1.append(["hold", L])
	p2.append(["wait", 6])
	p2.append(["hold", L])


## Walk / fall on towards x `tx` (steering in the air) until he stands at feet y >= `min_y` (a drop off a deck's end).
func fall_to_fn(tx: int, min_y: int, off_dir: int = 0, creep: bool = false) -> Callable:
	return func(_lv: LevelBase, h: PlayerBase, n: int) -> int:
		if h.is_grounded() and h.sim_pos.y >= min_y:
			return -1
		if n > 400:
			_problem("P%d drop to %d did not land (%s)" % [h.slot + 1, tx, h.sim_pos])
			return -1
		if h.is_grounded() and off_dir != 0:
			# still on the upper floor: walk on off its end (`creep`: at 2-3 px a tick)
			if creep and absi(h.xvel) >= int(opts.get("creep_v", "40")):
				return 0
			return R if off_dir > 0 else L
		var dx: int = tx - h.sim_pos.x
		return R if dx > 3 else (L if dx < -3 else 0)


## True when every leaper record near the given x ([x, ticks]) has no copy out and will not produce one for that many
## ticks, and no other enemy is awake within 110 px.
func pits_quiet(recs: Array) -> Callable:
	return func(lv: LevelBase, h: PlayerBase) -> bool:
		if not h.is_grounded() or h.is_striking():
			return false
		for pair: Array in recs:
			for entity: SimEntity in lv.get_kind(Defs.Kind.ENEMY):
				var r: SpawnerEnemy = entity as SpawnerEnemy
				if r != null and not r.is_copy() and r is Leaper and absi(r.sim_pos.x - int(pair[0])) < 40:
					if r.alive_copies() > 0 or r._cooldown < int(pair[1]):
						return false
		return true


## Walk towards the enemy at (ex, ey) and swing once his x passes `at` (the swing is live before a snapper's wind-up
## ends); again from where he stands until it is dead.
func lunge_strike_fn(ex: int, ey: int, at: int) -> Callable:
	return func(lv: LevelBase, h: PlayerBase, n: int) -> int:
		var st: Dictionary = _st[h.slot]
		if int(st.get("hold", 0)) > 0:
			st["hold"] = int(st["hold"]) - 1
			return F if int(st["hold"]) >= 2 else 0
		if enemy_near(ex, ey, 30) == null:
			return -1 if h.is_grounded() else 0
		if n > 300:
			_problem("P%d lunge strike at %d timed out" % [h.slot + 1, ex])
			return -1
		if not h.is_grounded() or h.is_striking():
			return 0
		var dir: int = 1 if ex > h.sim_pos.x else -1
		if (dir > 0 and h.sim_pos.x < at) or (dir < 0 and h.sim_pos.x > at):
			return R if dir > 0 else L
		st["hold"] = 9
		return F


## The deck of row 72: the bonded leapers jump from its two pits (cols 66-68 and 72-74): each hero crosses both pits in
## a pause of their spawners (P1 first, P2 after him), striking the copies that come; then both drop off the deck's
## left end onto the deck of row 84.
func descent3(p1: Array, p2: Array) -> void:
	var need: int = int(opts.get("pit_need", "30"))
	for slot: int in 2:
		var p: Array = p1 if slot == 0 else p2
		if slot == 1:
			p.append(guard_cmd(func(_lv: LevelBase, _h: PlayerBase) -> bool:
				var a: PlayerBase = hero(0)
				return a.is_grounded() and a.sim_pos.x < 1056, 1500, "pits_p1"))
		p.append(["go", 1210, {"tol": 3, "fight": true}])
		p.append(guard_cmd(pits_quiet([[1176, int(opts.get("need73", "40"))], [1080, int(opts.get("need67", "25"))]]), 1500, "pits%d" % slot, 80))
		p.append(["fn", hop_fn(1128, 8)])
		p.append(["fn", hop_fn(1030 - slot * 30, 10)])
		p.append(["go", 1000 - slot * 40, {"tol": 3, "fight": true}])
	p1.append(guard_cmd(func(_lv: LevelBase, _h: PlayerBase) -> bool:
		var b: PlayerBase = hero(1)
		return b.is_grounded() and b.sim_pos.x < 1056, 1500, "pits_p2"))
	p1.append(["sync", "deck72_left"])
	p2.append(["sync", "deck72_left"])
	# off the left end (col 58) onto the deck of row 84, P2 right behind
	p1.append(["run", 920, {"fight": true}])
	p1.append(["until", func(_lv: LevelBase, h: PlayerBase) -> bool: return h.is_grounded() and h.sim_pos.y >= 1340, L])
	p1.append(["go", 860, {"tol": 3}])
	p2.append(["run", 925, {"fight": true}])
	p2.append(["until", func(_lv: LevelBase, h: PlayerBase) -> bool: return h.is_grounded() and h.sim_pos.y >= 1340, 0])
	p2.append(["go", 900, {"tol": 3}])
	p1.append(["sync", "deck84"])
	p2.append(["sync", "deck84"])


## The deck of row 60: its hopper; both onto the down lift (82, 60) at once and off it to the left at its foot, onto
## the deck of row 72 (the fourth checkpoint).
func descent2(p1: Array, p2: Array) -> void:
	var fight: Dictionary = {"fight": true}
	p1.append(["go", 1100, fight])
	p2.append(["go", 1060, fight])
	for p: Array in [p1, p2]:
		p.append(["fn", kill_fn(1176, 940, 160, 600, {"awake_only": true})])
		p.append(barrier("hopper60"))
	var da: int = int(opts.get("dlift2_a", "1284"))
	p1.append(["go", da, {"tol": 0, "fight": true}])
	p2.append(["go", da - 24, {"tol": 0, "fight": true}])
	for p: Array in [p1, p2]:
		p.append(barrier("down_lift"))
		p.append(["keys", 2, U | R])
		p.append(["keys", 6, R])
		p.append(["until", func(_lv: LevelBase, h: PlayerBase) -> bool: return h.is_grounded(), 0])
		p.append(["until", func(_lv: LevelBase, h: PlayerBase) -> bool: return h.sim_pos.y >= int(opts.get("dlift2_bottom", "1146")), 0])
		p.append(barrier("down_lift_bottom"))
		p.append(["keys", 20, U | L])
		p.append(["until", func(_lv: LevelBase, h: PlayerBase) -> bool: return h.is_grounded(), 0])


## From the trunk top down onto the big branch (its far cell 61,35 is gate 'shaft''s), the Snatcher bat, off the
## branch's end onto the village deck (row 48): its stinger, the Shellback (a pincer from the right), off the deck's
## left end onto the deck below (row 60).
func descent1(p1: Array, p2: Array) -> void:
	var fight: Dictionary = {"fight": true}
	# off the trunk top's right edge onto the branch, P2 right behind
	p1.append(["run", 880, {}])
	p1.append(["until", func(_lv: LevelBase, h: PlayerBase) -> bool: return h.is_grounded() and h.sim_pos.y == 576, 0])
	p1.append(["go", 940, {"tol": 3}])
	p2.append(guard_cmd(func(_lv: LevelBase, _h: PlayerBase) -> bool: return hero(0).sim_pos.y > 500, 300, "drop35"))
	p2.append(["run", 860, {}])
	p2.append(["until", func(_lv: LevelBase, h: PlayerBase) -> bool: return h.is_grounded() and h.sim_pos.y == 576, 0])
	p2.append(["go", 905, {"tol": 3}])
	p1.append(["sync", "branch"])
	p2.append(["sync", "branch"])
	# the Snatcher bat (63, 30): P1 clubs it from the far cell when it is low; P2 guards behind
	p1.append(["go", 986, {"tol": 2}])
	p1.append(["fn", kill_fn(1016, 530, 40, 900)])
	p2.append(guard_cmd(func(_lv: LevelBase, _h: PlayerBase) -> bool: return enemy_near(1016, 530, 40) == null, 900, "snatcher", 70))
	p1.append(["sync", "snatcher"])
	p2.append(["sync", "snatcher"])
	# off the branch's right end onto the village deck (row 48), one after the other (a landing on the partner's head
	# would be a Totem Ride). P1 first, steering left under the branch: the stinger over the hut (76, 45) dives at
	# him and he clubs it as it comes (or steps into its reach); P2 waits near the branch's end (the view's edges are
	# walls: 260 px behind he would hold P1 back) and drops once it is dead and P1 stepped aside
	var d1: int = int(opts.get("d48_p1", "1100"))
	var d2: int = int(opts.get("d48_p2", "1136"))
	if expert and not opts.has("drop_seq"):
		# Expert: the stinger is a loner (it keeps away while the two are within 64 px of each other) and the deck is 12
		# rows under the branch (off the view, a 73-tick leash): both walk off the end on the same tick, 24 px apart
		p1.append(["go", 1150, {"tol": 0, "fight": true}])
		p2.append(["go", 1126, {"tol": 0, "fight": true}])
		for p: Array in [p1, p2]:
			p.append(barrier("drop48"))
			p.append(["fn", fall_to_fn(d1 + 24 if p == p1 else d1, 760, 1)])
		p1.append(["sync", "deck48_land"])
		p2.append(["sync", "deck48_land"])
		p2.append(["go", int(opts.get("st48_p2", "1164")), {"tol": 2, "fight": true}])
		p2.append(["sync", "st48_p2"])
		p1.append(["sync", "st48_p2"])
		p1.append(["fn", kill_fn(1224, 736, 170, 600, {"approach": int(opts.get("st48_xe", "1206"))})])
		p2.append(guard_cmd(func(_lv: LevelBase, _h: PlayerBase) -> bool: return enemy_near(1224, 736, 170, false, "Stinger") == null, 600, "stinger48", 80))
		for p: Array in [p1, p2]:
			p.append(["sync", "deck48"])
		deck48_on(p1, p2)
		return
	p2.append(["go", 1120, {"tol": 3, "fight": true}])
	p1.append(["run", 1180, fight])
	p1.append(["fn", fall_to_fn(d1 + 16, 760, 1)])
	p1.append(["face", 1])
	if not expert:
		p1.append(["fn", kill_fn(1224, 736, 170, 600, {"approach": int(opts.get("st48_x", "1164"))})])
	p1.append(["go", d1, {"tol": 3, "fight": true}])
	# (Expert: the deck is 12 rows under the branch - off the view, and the leash is 73 ticks: P2 drops as soon as P1
	# stepped aside; the stinger is a loner there - together they walk under it, P2 within 64 px, and P1 clubs it high)
	p2.append(guard_cmd(func(_lv: LevelBase, _h: PlayerBase) -> bool:
		var a: PlayerBase = hero(0)
		return (expert or enemy_near(1224, 736, 170, false, "Stinger") == null) and a.is_grounded() 				and a.sim_pos.y >= 760 and a.sim_pos.x <= d1 + 8, 900, "drop48", 0))
	p2.append(["run", 1180, fight])
	p2.append(["fn", fall_to_fn(d2, 760, 1)])
	p2.append(["go", d2, {"tol": 3, "fight": true}])
	if expert:
		p1.append(["sync", "deck48_land"])
		p2.append(["sync", "deck48_land"])
		p2.append(["go", int(opts.get("st48_p2", "1164")), {"tol": 2, "fight": true}])
		p2.append(["sync", "st48_p2"])
		p1.append(["sync", "st48_p2"])
		p1.append(["fn", kill_fn(1224, 736, 170, 600, {"approach": int(opts.get("st48_xe", "1206"))})])
		p2.append(guard_cmd(func(_lv: LevelBase, _h: PlayerBase) -> bool: return enemy_near(1224, 736, 170, false, "Stinger") == null, 600, "stinger48", 80))
	for p: Array in [p1, p2]:
		p.append(["sync", "deck48"])
	deck48_on(p1, p2)


## The village deck from the Shellback on (see descent1).
func deck48_on(p1: Array, p2: Array) -> void:
	var fight: Dictionary = {"fight": true}
	# the Shellback of the deck (65, 47; a short beat, x 1016-1080, 24 px from the deck's left end - no room behind it
	# for a pincer): both jump over it on the same tick, 24 px apart, just after it turned at its left end and walks
	# right under them, land behind it and walk on off the deck's left end (col 62) onto the deck below (row 60)
	var tx_: int = int(opts.get("t48_x", "1150"))
	p1.append(["go", tx_, {"tol": 1}])
	p2.append(["go", tx_ + 24, {"tol": 1}])
	p1.append(["sync", "turtle48_set"])
	p2.append(["sync", "turtle48_set"])
	var t48: Callable = func(lv: LevelBase, _h: PlayerBase) -> bool:
		for entity: SimEntity in lv.get_kind(Defs.Kind.ENEMY):
			var foe: EnemyBase = entity as EnemyBase
			if foe != null and not foe.dead and foe.coop_trait == Defs.CoopTrait.SHELL and foe.sim_pos.x >= 980 					and foe.sim_pos.x <= 1110 and absi(foe.sim_pos.y - 768) < 24:
				return foe.xvel > 0 and foe.sim_pos.x >= int(opts.get("t48_lo", "1018")) 						and foe.sim_pos.x <= int(opts.get("t48_hi", "1030"))
		return true
	for p: Array in [p1, p2]:
		p.append(guard_cmd(t48, 900, "turtle48_wait", 0))
		p.append(barrier("turtle48_go"))
		p.append(["keys", int(opts.get("t48_run", "6")), L])
		p.append(["keys", 20, U | L])
		p.append(["until", func(_lv: LevelBase, h: PlayerBase) -> bool: return h.is_grounded(), L])
	p1.append(["fn", fall_to_fn(900, 950, -1)])
	p1.append(["go", 900, {"tol": 3}])
	p2.append(["fn", fall_to_fn(940, 950, -1)])
	p2.append(["go", 940, {"tol": 3}])
	p1.append(["sync", "deck60"])
	p2.append(["sync", "deck60"])


## Gate 'shaft' (the wf10 redesign of the pulley): P1 breaks the cracked bark; P2 stands under the ledge (row 38, 8
## rows over the shaft floor), P1 lands on his head holding Up (the Shoulder Hop) and steers onto the ledge's left
## cell; P2 walks onto the lift stone (cols 49-50); P1 steps onto the plate of the ledge's right cell and crouches -
## the stone lifts P2 to the ledge; P2 steps onto the ledge; both climb the hanging vine (47, 30) out through the
## shaft's mouth onto the trunk top, P1 first.
func pulley(p1: Array, p2: Array) -> void:
	p2.append(["go", 640, {"tol": 3}])
	p1.append(["go", 690, {"tol": 1}])
	p1.append(["face", 1])
	p1.append(["fn", strike_open_fn(Vector2i(44, 45), 0)])
	p1.append(["fn", strike_open_fn(Vector2i(44, 44), U)])
	p1.append(["go", 762, {"tol": 2}])
	p1.append(["sync", "trunk_open"])
	p2.append(["sync", "trunk_open"])
	var cx_: int = int(opts.get("shaft_carrier", "736"))
	p2.append(["go", cx_, {"tol": 1}])
	p2.append(["face", 1])
	p2.append(["sync", "shaft_carrier"])
	p1.append(["sync", "shaft_carrier"])
	p1.append(["go", int(opts.get("shaft_from", "770")), {"tol": 1}])
	p1.append(["fn", shoulder2_fn(cx_, 608, 768)])
	# P1 on the ledge's left cell (off the plate) until P2 stands on the lift stone
	p1.append(["go", int(opts.get("ledge_wait", "758")), {"tol": 1}])
	p1.append(["sync", "p1_up"])
	p2.append(["sync", "p1_up"])
	p2.append(["go", int(opts.get("stone_x", "800")), {"tol": 2}])
	p2.append(["sync", "on_stone"])
	p1.append(["sync", "on_stone"])
	# P1 onto the plate (the ledge's right cell, x 768-783), crouching until P2 stands on the ledge
	p1.append(["go", int(opts.get("plate_x", "776")), {"tol": 1}])
	p1.append(["until", func(_lv: LevelBase, _h: PlayerBase) -> bool:
		var b: PlayerBase = hero(1)
		return b.is_grounded() and b.sim_pos.y == 608 and b.sim_pos.x <= 781 and b.xvel == 0, D])
	# P2 rides the stone up (a crouch tap now and then keeps him awake) and steps left onto the ledge
	p2.append(["until", func(_lv: LevelBase, h: PlayerBase) -> bool: return h.is_grounded() and h.sim_pos.y <= 608, 0])
	p2.append(["go", int(opts.get("ledge_p2", "778")), {"tol": 1}])
	p1.append(["sync", "shaft_up"])
	p2.append(["sync", "shaft_up"])
	# both up the hanging vine (47, 30) to the trunk top: P1, then P2
	p1.append(["go", 760, {"tol": 0}])
	p1.append(["face", 1])
	p1.append(["fn", climb_fn(480)])
	p1.append(["go", 812, {"tol": 2}])
	p2.append(guard_cmd(func(_lv: LevelBase, _h: PlayerBase) -> bool: return hero(0).is_grounded() and hero(0).sim_pos.y <= 480, 600, "vine2"))
	p2.append(["go", 760, {"tol": 0}])
	p2.append(["face", 1])
	p2.append(["fn", climb_fn(480)])
	p2.append(["go", 784, {"tol": 2}])
	p1.append(["sync", "trunk_top"])
	p2.append(["sync", "trunk_top"])


## The Shoulder Hop onto a ledge on the RIGHT: jump onto the partner's head holding Up, rise, and steer right onto the
## ledge (feet `ledge_y`, its left edge `ledge_x`) once the feet are above it.
func shoulder2_fn(carrier_x: int, ledge_y: int, ledge_x: int) -> Callable:
	return func(lv: LevelBase, h: PlayerBase, n: int) -> int:
		var st: Dictionary = _st[h.slot]
		var k: int = int(st.get("k", -1))
		if k < 0:
			if h.is_grounded() and h.no_jump == 0 and not h.is_striking() and h.xvel == 0:
				st["k"] = 0
				k = 0
			else:
				return 0
		st["k"] = k + 1
		if n > 300:
			_problem("P%d shoulder hop failed at %s" % [h.slot + 1, h.sim_pos])
			return -1
		if k > 3 and h.is_grounded() and h.sim_pos.y <= ledge_y:
			return -1
		if bool(st.get("bounced", false)) or h.yvel < -150:
			st["bounced"] = true
			if h.sim_pos.y < ledge_y - 4:
				return R
			return 0
		var dx: int = carrier_x - h.sim_pos.x
		var keys: int = R if dx > 2 else (L if dx < -2 else 0)
		return U | keys


## The watchtower deck (row 70): the arc leaper's copies (both strike them as they pass); over the leaper's gap, up the
## branches to the long deck (row 58), its bats and hopper; both onto the trunk lift together and off at its top.
func climb2(p1: Array, p2: Array) -> void:
	var fight: Dictionary = {"fight": true}
	# the arc leaper of the gap (24, 71) springs from deck end to deck end over us: both strike it as it passes
	p1.append(["go", int(opts.get("lp_a", "470")), {"tol": 2}])
	p2.append(["go", int(opts.get("lp_b", "530")), {"tol": 2}])
	for p: Array in [p1, p2]:
		p.append(["fn", kill_fn(470, 1100, 140, int(opts.get("leaper_wait", "600")), {"awake_only": true})])
		p.append(barrier("leaper70"))
	p1.append(["go", 427, {"tol": 2}])
	p1.append(["fn", hop_fn(340, 20)])
	p1.append(["go", 285, {"tol": 2}])
	p2.append(guard_cmd(partner_clear(340, 1120, 40), 900, "gap70"))
	p2.append(["go", 427, {"tol": 2}])
	p2.append(["fn", hop_fn(340, 20)])
	# the branches up (rows 67, 64, 61), P2 a branch behind
	ledges(p1, p2, "b2", [[285, 210, 20, 1072, 210], [192, 192, 20, 1024, 192], [192, 192, 20, 976, 192]], 34)
	# onto the long deck (row 58) while the near bat is high; P1 clubs the far bat, P2 the near one (high strikes)
	p1.append(["go", 248, {"tol": 2}])
	p1.append(guard_cmd(dangler_high(264, 850, 60), 900, "bat58"))
	p1.append(["fn", hop_fn(314, 20)])
	p1.append(["go", 334, {"tol": 1}])
	p1.append(["fn", kill_fn(360, 880, 50, 600)])
	p2.append(["go", 214, {"tol": 2}])
	p2.append(guard_cmd(func(_lv: LevelBase, _h: PlayerBase) -> bool:
		var a: PlayerBase = hero(0)
		return a.is_grounded() and a.sim_pos.y == 928 and a.sim_pos.x >= 326, 900, "deck58"))
	p2.append(["go", 248, {"tol": 2}])
	p2.append(guard_cmd(dangler_high(264, 850, 60), 900, "bat58b"))
	p2.append(["fn", hop_fn(298, 20)])
	p2.append(["go", 290, {"tol": 1}])
	p2.append(["fn", kill_fn(264, 880, 50, 600)])
	p1.append(["sync", "deck58"])
	p2.append(["sync", "deck58"])
	# the hopper of the deck (28, 57): both wait for it and club it as it comes
	p1.append(["go", 380, fight])
	p2.append(["go", 350, fight])
	for p: Array in [p1, p2]:
		p.append(["fn", kill_fn(456, 900, 140, 600, {"awake_only": true})])
		p.append(barrier("hopper58"))
	# both onto the trunk lift (cx 552) with the same keys on the same tick, off at its top to the right
	var ta: int = int(opts.get("tlift_a", "514"))
	p1.append(["go", ta, {"tol": 0}])
	p2.append(["go", ta - 24, {"tol": 0}])
	for p: Array in [p1, p2]:
		p.append(barrier("tlift"))
		p.append(["keys", 2, U | R])
		p.append(["keys", 6, R])
		p.append(["until", func(_lv: LevelBase, h: PlayerBase) -> bool: return h.is_grounded(), 0])
		p.append(["until", func(_lv: LevelBase, h: PlayerBase) -> bool: return h.sim_pos.y <= 770, 0])
		p.append(["until", func(_lv: LevelBase, h: PlayerBase) -> bool: return h.is_grounded() and h.sim_pos.y == 736 and not h.on_platform, R])
		p.append(barrier("tlift_top"))


## True once the dangler hanging at x `dx` is above `y` (its feet) or dead / gone.
func dangler_high(dx: int, y: int, r: int) -> Callable:
	return func(_lv: LevelBase, _h: PlayerBase) -> bool:
		var foe: EnemyBase = enemy_near(dx, 880, r)
		return foe == null or foe.sim_pos.y <= y


## From the tree house deck (row 93) over the two bat gaps to the branches, up to the second deck (row 82), its
## stingers, and both onto the diagonal lift together; off at its top onto the watchtower deck (row 70).
func climb1(p1: Array, p2: Array) -> void:
	var fight: Dictionary = {"fight": true}
	# both over the axe (col 25) by a hop - the route keeps the club
	p1.append(["go", 446, {"tol": 2}])
	p1.append(["fn", hop_fn(372, 10)])
	p1.append(["go", 358, {"tol": 1}])
	p1.append(["fn", kill_fn(328, 1450, 60)])
	p2.append(["go", 470, {"tol": 3}])
	p1.append(["fn", hop_fn(282, 12)])
	p1.append(["go", 262, {"tol": 1}])
	# P2 follows only once P1 stands beyond the first gap (a hop onto his head would make P1 a Totem carrier, whose
	# jump is halved)
	p2.append(wait_cmd(partner_at(240, 300, DECK93), 900, "p1 beyond gap 1"))
	p1.append(["fn", kill_fn(232, 1450, 60)])
	p1.append(["sync", "bats93"])
	p2.append(["go", 446, {"tol": 2}])
	p2.append(["fn", hop_fn(372, 10)])
	p2.append(["go", 358, {"tol": 2}])
	p2.append(["sync", "bats93"])
	p1.append(["fn", hop_fn(170, 12)])
	p1.append(["go", 88, {"tol": 2}])
	p2.append(wait_cmd(partner_clear(282, DECK93, 40), 900, "gap2"))
	p2.append(["fn", hop_fn(282, 12)])
	p2.append(wait_cmd(partner_clear(170, DECK93, 40), 900, "gap3"))
	p2.append(["fn", hop_fn(170, 12)])
	p2.append(["go", 140, {"tol": 3}])
	# the three branches up (rows 91, 88, 85), P2 a branch behind
	ledges(p1, p2, "br", [[88, 88, 20, 1456, 88], [88, 88, 20, 1408, 88], [88, 88, 20, 1360, 88]], 34)
	# onto the second deck (row 82), the stingers
	p1.append(["go", 122, {"tol": 2}])
	p1.append(["fn", hop_fn(182, 20)])
	p1.append(["go", 214, {"tol": 2}])
	p1.append(["sync", "deck82"])
	p2.append(["go", 122, {"tol": 2}])
	p2.append(guard_cmd(partner_clear(182, 1312, 28), 900, "deck82"))
	p2.append(["fn", hop_fn(182, 20)])
	p2.append(["go", 188, {"tol": 2}])
	p2.append(["sync", "deck82"])
	# the stingers over the deck: P1 steps into the first one's reach and clubs it as it dives; then the second
	# (Expert: the stingers are loners - they never dive while we keep together, so P1 walks under one and clubs it
	# high, P2 within 64 px of him)
	if expert:
		p2.append(["go", 236, {"tol": 2}])
	p1.append(["fn", kill_fn(296, 1290, 80, 600, {"approach": int(opts.get("st1_x", "278" if expert else "236"))})])
	p2.append(guard_cmd(func(_lv: LevelBase, _h: PlayerBase) -> bool: return enemy_near(296, 1290, 80) == null, 600, "st1", 80))
	p1.append(["sync", "st1"])
	p2.append(["sync", "st1"])
	p2.append(["go", 330 if expert else 300, {"tol": 2}])
	p2.append(["sync", "st2_p2"])
	p1.append(["sync", "st2_p2"])
	p1.append(["fn", kill_fn(392, 1290, 80, 600, {"approach": int(opts.get("st2_x", "374" if expert else "332"))})])
	p2.append(guard_cmd(func(_lv: LevelBase, _h: PlayerBase) -> bool: return enemy_near(392, 1290, 80) == null, 600, "st2", 80))
	p1.append(["sync", "st2"])
	p2.append(["sync", "st2"])
	# both onto the diagonal lift at once (a hop each from a stand), off at its top onto the row 70 deck
	# both stand still 26 px apart at the deck's end and hop onto the lift with the same keys on the same tick
	var la: int = int(opts.get("dlift_a", "402"))
	p1.append(["go", la, {"tol": 0}])
	p2.append(["go", la - 24, {"tol": 0}])
	for p: Array in [p1, p2]:
		p.append(barrier("dlift"))
		p.append(["keys", int(opts.get("dlift_up", "2")), U | R])
		p.append(["keys", int(opts.get("dlift_r", "6")), R])
		p.append(["until", func(_lv: LevelBase, h: PlayerBase) -> bool: return h.is_grounded(), 0])
		p.append(["until", func(_lv: LevelBase, h: PlayerBase) -> bool: return h.sim_pos.y <= int(opts.get("dlift_top", "1124")), 0])
		p.append(barrier("dlift_top"))
		p.append(["keys", 20, U | L])
		p.append(["until", func(_lv: LevelBase, h: PlayerBase) -> bool: return h.is_grounded(), 0])


## True once the platform under the hero has stopped (or he is not on one).
func lift_stopped_fn() -> Callable:
	return func(_lv: LevelBase, h: PlayerBase) -> bool:
		var st: Dictionary = _st[h.slot]
		var key: String = "%d,%d" % [h.sim_pos.x, h.sim_pos.y]
		if str(st.get("last", "")) == key:
			st["same"] = int(st.get("same", 0)) + 1
		else:
			st["same"] = 0
		st["last"] = key
		return h.is_grounded() and int(st["same"]) >= 3 and h.sim_pos.y < 1300


## A climb of hops for two, P2 a hop behind: hops [start x, target x, up ticks, landing feet y, P2's target x].
func ledges(p1: Array, p2: Array, tag: String, hops: Array, clear: int = 30) -> void:
	for i: int in hops.size():
		var hp: Array = hops[i]
		p1.append(["go", int(hp[0]), {"tol": 2}])
		p1.append(["fn", hop_fn(int(hp[1]), int(hp[2]))])
		p1.append(["sync", "%s%d" % [tag, i]])
		p2.append(["sync", "%s%d" % [tag, i]])
		p2.append(guard_cmd(partner_clear(int(hp[4]), int(hp[3]), clear), 900, "%s%d" % [tag, i]))
		p2.append(["go", int(hp[0]), {"tol": 2}])
		p2.append(["fn", hop_fn(int(hp[4]), int(hp[2]))])


func treehouse(p1: Array, p2: Array) -> void:
	# P2 up the mound's steps (rows 104, 102) to its top (y 1632, cols 38-43), stands 16 px right of the deck's edge
	var cx_: int = int(opts.get("carrier_x", "656"))
	p2.append(["go", 560, {"tol": 3}])
	p2.append(["fn", hop_fn(596, 8)])
	p2.append(["fn", hop_fn(628, 8)])
	p2.append(["go", cx_, {"tol": 1}])
	p2.append(["face", -1])
	p2.append(["sync", "carrier_set"])
	p1.append(["go", 540, {"tol": 3}])
	p1.append(["sync", "carrier_set"])
	p1.append(["fn", hop_fn(596, 8)])
	p1.append(["fn", hop_fn(628, 8)])
	p1.append(["go", int(opts.get("hop_from", "690")), {"tol": 1}])
	# onto P2's head holding Up (Shoulder Hop), up past the deck's edge (8 rows up), then left onto the deck
	p1.append(["fn", shoulder_fn(cx_, 600)])
	p1.append(["go", 622, {"tol": 2}])
	p1.append(["face", 1])
	p1.append(["fn", open_vine_fn(40, int(opts.get("vine_keys", str(D))))])
	p1.append(["go", 560, {"tol": 3}])
	p2.append(wait_cmd(func(_lv: LevelBase, _h: PlayerBase) -> bool: return vine_open(40), 1500, "vine"))
	p2.append(["go", 648, {"tol": 2}])
	p2.append(["face", -1])
	p2.append(["fn", climb_fn(DECK93)])
	p2.append(["go", 600, {"tol": 3}])
	p1.append(["sync", "treehouse_done"])
	p2.append(["sync", "treehouse_done"])


func vine_open(col: int) -> bool:
	for kind: int in Defs.KIND_COUNT:
		for entity: SimEntity in level.get_kind(kind):
			var vine: Vine = entity as Vine
			if vine != null and vine.vine_x >> 4 == col:
				return vine.unrolled
	return false


## Strike (with `extra`) until the rolled vine anchored in column `col` is unrolled.
func open_vine_fn(col: int, extra: int = 0) -> Callable:
	return func(lv: LevelBase, h: PlayerBase, n: int) -> int:
		if vine_open(col):
			return -1
		if n > 400:
			_problem("P%d vine %d did not open" % [h.slot + 1, col])
			return -1
		var st: Dictionary = _st[h.slot]
		if int(st.get("hold", 0)) > 0:
			st["hold"] = int(st["hold"]) - 1
			return (F | extra) if int(st["hold"]) >= 2 else 0
		if not h.is_grounded() or h.is_striking():
			return 0
		st["hold"] = 9
		return F | extra


## Climb the vine he stands at to its top (Up held), done once he stands on the ledge.
func climb_fn(top_y: int) -> Callable:
	return func(lv: LevelBase, h: PlayerBase, n: int) -> int:
		if h.is_grounded() and h.sim_pos.y <= top_y and n > 2:
			return -1
		if n > 600:
			_problem("P%d climb did not reach %d (%s)" % [h.slot + 1, top_y, h.sim_pos])
			return -1
		return U


## A jump onto the partner's head with Up held (the Shoulder Hop, PHYSICS C.10), then left onto the ledge whose
## right end is `ledge_x` once the feet are above it.
func shoulder_fn(carrier_x: int, ledge_x: int) -> Callable:
	return func(lv: LevelBase, h: PlayerBase, n: int) -> int:
		var st: Dictionary = _st[h.slot]
		var k: int = int(st.get("k", -1))
		if k < 0:
			if h.is_grounded() and h.no_jump == 0 and not h.is_striking() and h.xvel == 0:
				st["k"] = 0
				k = 0
			else:
				return 0
		st["k"] = k + 1
		if n > 300:
			_problem("P%d shoulder hop failed at %s" % [h.slot + 1, h.sim_pos])
			return -1
		if k > 3 and h.is_grounded() and h.sim_pos.y <= DECK93:
			return -1
		if bool(st.get("bounced", false)) or h.yvel < -150:
			st["bounced"] = true
			if h.sim_pos.y < DECK93 - 4:
				return U | L
			return U
		var dx: int = carrier_x - h.sim_pos.x
		var keys: int = R if dx > 2 else (L if dx < -2 else 0)
		return U | keys
