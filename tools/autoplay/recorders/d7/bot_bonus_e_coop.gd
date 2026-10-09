extends "res://tools/autoplay/recorders/d7/bot_w7_l1_coop.gd"
## The two-stream route of bonus_e_coop (D7), both difficulties: both heroes cross every wafer reach on one raft
## (P1 paddles, P2 guards), P1 opens a few spots on the way, both walk to the warp home. The grotto is left out.


func header() -> String:
	return "# route: level=bonus_e_coop difficulty=both players=2 source=w7_l1_coop ends=warp after=tally expect=wipes:0,eggs:0,min_spots:4\n"


func spot_low(p: Array, stand_x: int, dir: int, cell: Vector2i, extra: int = D) -> void:
	p.append(["go", stand_x, {"tol": 2}])
	p.append(["face", dir])
	p.append(["fn", open_fn(cell, extra)])


func build() -> Array:
	var fight: Dictionary = {"fight": true}
	var p1: Array = []
	var p2: Array = []
	spot_low(p1, cx(3), 1, Vector2i(4, 20))
	p1.append(["run", cx(11), fight])
	p1.append(["leap", cx(14), 8])
	p1.append(["leap", cx(17) + 20, 3])
	p2.append(["wait", 40])
	p2.append(["run", cx(10), fight])
	p2.append(["leap", cx(14), 8])
	p2.append(["leap", cx(17), 3])
	cross2(p1, p2, "r1", 18 * 16, 336, cx(44))
	spot_low(p1, cx(49), 1, Vector2i(50, 20))
	p2.append(["go", cx(47), fight])
	p2.append(["until", func(lv: LevelBase, h: PlayerBase) -> bool:
		var a: PlayerBase = hero(0)
		return a.is_grounded() and a.sim_pos.y <= 16 * 16 and a.sim_pos.x >= cx(53), 0])
	for slot: int in 2:
		var p: Array = p1 if slot == 0 else p2
		p.append(["go", cx(51) - slot * 4, {"tol": 2}])
		p.append(["leap", cx(53) + slot * 16, 9])
		p.append(["leap", cx(54) + slot * 16, 4])
	# the giant roast spot for two (GAMEPLAY 13.9.8): P1 puffs it down to its last hit from the left, P2 strikes that
	# last hit from the right within the twin window - the giant bonus falls
	# (the strikes wait until the jelly over the hill is away from it: a hit's hop would lift the striker into it)
	p1.append(["go", cx(54) - 4, {"tol": 2}])
	p1.append(["face", 1])
	p1.append(["sync", "giant_ready"])
	p1.append(["fn", hits_down_fn(Vector2i(55, 16), 1, D)])
	p2.append(["go", cx(56) + 6, {"tol": 2}])
	p2.append(["face", -1])
	p2.append(["sync", "giant_ready"])
	p2.append(["until", func(lv: LevelBase, h: PlayerBase) -> bool: return _spot_hits(lv, Vector2i(55, 16)) <= 1, 0])
	p2.append(["wait", 2])
	p2.append(["fn", open_fn(Vector2i(55, 16), D)])
	for slot: int in 2:
		var p: Array = p1 if slot == 0 else p2
		p.append(["sync", "giant"])
		p.append(["wait", 30])
		p.append(["run", cx(60) - slot * 20, {"fight": true, "wait_px": 0}])
	cross2(p1, p2, "r2", 65 * 16, 1088, cx(95), true)
	spot_low(p1, cx(95), 1, Vector2i(96, 20))
	p2.append(["go", cx(93), fight])
	# P2 passes only once P1's spot is open (a strike's hop over a passing partner lands on his head)
	p1.append(["sync", "s96"])
	p2.append(["sync", "s96"])
	for slot: int in 2:
		var p: Array = p1 if slot == 0 else p2
		p.append(["go", cx(98) - slot * 2, {"tol": 2}])
		p.append(["leap", cx(102) + slot * 0, 9])
		p.append(["run", cx(107) - 8, fight])
		p.append(["leap", cx(110), 8])
		p.append(["run", cx(118) - slot * 20, fight])
	p1.append(["run", cx(135), fight])
	p2.append(["run", cx(132), fight])
	cross2(p1, p2, "r3", 141 * 16, 2304, cx(173), true)
	for slot: int in 2:
		var p: Array = p1 if slot == 0 else p2
		p.append(["run", cx(176) - slot * 20, fight])
		p.append(["leap", cx(180) - slot * 16, 8])
		p.append(["run", cx(196) - slot * 20, fight])
		p.append(["hold", R])
	return [p1, p2]


## Hits left of the hittable at `cell` (0 once opened, 99 when none is there).
func _spot_hits(lv: LevelBase, cell: Vector2i) -> int:
	for entity: SimEntity in lv.get_kind(Defs.Kind.HITTABLE):
		var spot: HittableBase = entity as HittableBase
		if spot != null and spot.cell == cell:
			return 0 if spot.opened else spot.hits_left
	return 99


## Strike (with `extra`) whenever grounded and not striking, until the hittable at `cell` has `left` hits left.
func hits_down_fn(cell: Vector2i, left: int, extra: int = 0) -> Callable:
	return func(lv: LevelBase, h: PlayerBase, n: int) -> int:
		if _spot_hits(lv, cell) <= left or n > 600:
			return -1
		if not _clear_above(lv, cell.x * 16 + 8, 72):
			return 0
		var st: Dictionary = _st[h.slot]
		if bool(st.get("pressed", false)):
			st["pressed"] = false
			return 0
		if not h.is_grounded() or h.is_striking():
			return 0
		st["pressed"] = true
		return F | extra


## True when no living enemy is within `px` of x (the spot's column) above the hill: a jelly that patrols there.
func _clear_above(lv: LevelBase, x: int, px: int) -> bool:
	for entity: SimEntity in lv.get_kind(Defs.Kind.ENEMY):
		var foe: EnemyBase = entity as EnemyBase
		if foe != null and not foe.dead and absi(foe.sim_pos.x - x) < px and foe.sim_pos.y < 17 * 16:
			return false
	return true
