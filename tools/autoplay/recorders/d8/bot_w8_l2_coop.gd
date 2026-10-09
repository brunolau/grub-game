extends "res://tools/autoplay/recorders/d8/coop_lib.gd"
## The two-stream co-op route of w8_l2_coop (D8), recorded by probe_work.gd --bot --players=2 (Expert only: one
## route, w8_l2_coop.inputs). P1 leads and fights; P2 follows; arches are taken by P1 (the team gate brings P2).
## Gate 'rooms': P1 holds plate A while P2 goes through the lower door; P2 holds plate B on the spike room's step while
## P1 takes the upper corridor. Gate 'shamans': both drop in beside the Shaman and pin him; P1 baits Guard 1 while P2
## climbs out and drops in behind it; P2 baits Guard 2 while P1 climbs out and drops in behind it; out over the hall
## through the open keeper door.


func header() -> String:
	return "# route: level=w8_l2_coop difficulty=expert players=2 ends=exit after=level:w8_l2b_coop expect=x2_gates:2,min_checkpoints:4,painting:10\n"


func feet(row: int) -> int:
	return row * 16


func on_floor(row: int) -> Callable:
	return func(lv: LevelBase, hh: PlayerBase) -> bool: return hh.is_grounded() and hh.sim_pos.y == feet(row)


func build() -> Array:
	var fight: Dictionary = {"fight": true}
	var p1: Array = []
	var p2: Array = []
	# --- M1: the scarabs and the raptor; then the 'rooms' gate
	p2.append(["keys", 2, L])
	p1.append(["mark", "M1"])
	p1.append(["go", cx(14), fight])
	p1.append(["fn", clear_fn(90, 200)])
	p1.append(["fn", hopper_fn(160, 400)])
	p1.append(["go", cx(20.5), fight])
	p1.append(["wait", 7])
	p1.append(["leap", cx(26), 10])
	p1.append(["fn", clear_fn(90, 200)])
	p1.append(["fn", unleech_fn()])
	p2.append(["fn", unleech_fn()])
	p2.append(["fn", wait_for(func(lv: LevelBase, hh: PlayerBase) -> bool: return hero(0).sim_pos.x >= cx(19), 600)])
	p2.append(["fn", follow_fn(cx(20.5), 40, 400)])
	p2.append(["fn", wait_for(func(lv: LevelBase, hh: PlayerBase) -> bool: return hero(0).sim_pos.x >= cx(25), 400)])
	p2.append(["wait", 7])
	p2.append(["leap", cx(25), 10])
	p1.append(["sync", "rooms"])
	p2.append(["sync", "rooms"])
	p1.append(["go", cx(29), {"tol": 2}])
	p1.append(["fn", crouch_until(func(lv: LevelBase, hh: PlayerBase) -> bool: return hero(1).sim_pos.x >= cx(44))])
	p2.append(["wait", 16])
	p2.append(["go", cx(30.5), {}])
	p2.append(["wait", 6])
	p2.append(["leap", cx(33), 6])
	p2.append(["go", cx(45.5), {}])
	p2.append(["sync", "pb"])
	p1.append(["sync", "pb"])
	# P2 over the first pit onto the step (plate B); P1 up the step and the ledge to the upper corridor
	p2.append(["fn", swing_clear_fn(cx(48.5), 1)])
	p2.append(["leap", cx(51), 3])
	p2.append(["go", cx(51), {"tol": 2}])
	p2.append(["fn", crouch_until(func(lv: LevelBase, hh: PlayerBase) -> bool: return hero(0).sim_pos.x >= cx(42) and hero(0).sim_pos.y == feet(38))])
	p1.append(["go", cx(31), {}])
	p1.append(["wait", 6])
	p1.append(["leap", cx(33), 8])
	p1.append(["wait", 6])
	p1.append(["leap", cx(36.5), 10])
	p1.append(["fn", wait_for(func(lv: LevelBase, hh: PlayerBase) -> bool: return door_risen(lv, 39, 32, 2), 300)])
	p1.append(["go", cx(42), {}])
	p1.append(["keys", 7, R])
	p1.append(["until", on_floor(38), 0])
	p1.append(["go", cx(45), {"tol": 3}])
	p1.append(["sync", "M2"])
	p2.append(["sync", "M2"])
	# --- M2: P2 (on the step) over the second pit first and kills the raptor by the arch; P1 follows over both pits
	p2.append(["fn", swing_clear_fn(cx(54.5), 1)])
	p2.append(["leap", cx(56.5), 3])
	p1.append(["fn", wait_for(func(lv: LevelBase, hh: PlayerBase) -> bool: return hero(1).sim_pos.x >= cx(56) and hero(1).is_grounded(), 700)])
	p1.append(["go", cx(45.5), {}])
	p1.append(["fn", swing_clear_fn(cx(48.5), 1)])
	p1.append(["leap", cx(51), 3])
	p1.append(["wait", 6])
	p1.append(["fn", swing_clear_fn(cx(54.5), 1)])
	p1.append(["leap", cx(56.5), 4])
	p2.append(["go", cx(58), {"tol": 3}])
	p1.append(["sync", "g_b"])
	p2.append(["sync", "g_b"])
	p1.append(["go", cx(57), {"tol": 3}])
	p1.append(["fn", gate_fn()])
	p2.append(["fn", wait_for(func(lv: LevelBase, hh: PlayerBase) -> bool: return hh.sim_pos.y <= feet(20), 200)])
	# --- M3: both drop through the hatch; the raptor pincer; P1 takes the arch
	p1.append(["mark", "M3"])
	p1.append(["sync", "M3"])
	p2.append(["sync", "M3"])
	p1.append(["go", cx(67.5), {"tol": 2}])
	p2.append(["go", cx(65), {"tol": 3}])
	p1.append(["keys", 6, D])
	p1.append(["until", on_floor(26), 0])
	p1.append(["go", cx(72), {"tol": 3}])
	# P2 drops once P1 cleared the spot (landing on his head, P2 would ride there without input)
	p2.append(["fn", wait_for(func(lv: LevelBase, hh: PlayerBase) -> bool: return hero(0).sim_pos.x >= cx(71), 200)])
	p2.append(["go", cx(68.5), {"tol": 2}])
	p2.append(["keys", 6, D])
	p2.append(["until", on_floor(26), 0])
	p1.append(["sync", "g_c"])
	p2.append(["sync", "g_c"])
	p1.append(["go", cx(77), {"tol": 3}])
	p1.append(["fn", gate_fn()])
	p2.append(["fn", wait_for(func(lv: LevelBase, hh: PlayerBase) -> bool: return hh.sim_pos.y >= feet(40), 200)])
	# --- M4: the painting room first (P1 breaks the blocks, takes the hole), then the crypt
	p1.append(["mark", "M4"])
	p1.append(["sync", "M4"])
	p2.append(["sync", "M4"])
	p1.append(["go", cx(85.5), {"tol": 2}])
	p1.append(["face", -1])
	p1.append(["fn", open_fn(Vector2i(84, 47))])
	p1.append(["fn", open_fn(Vector2i(84, 46), U)])
	p1.append(["go", cx(82), {"tol": 3}])
	p1.append(["fn", gate_fn()])
	p2.append(["fn", wait_for(func(lv: LevelBase, hh: PlayerBase) -> bool: return hh.sim_pos.y <= feet(14), 500)])
	p1.append(["mark", "S2"])
	p1.append(["sync", "S2"])
	p2.append(["sync", "S2"])
	p1.append(["go", cx(86), {}])
	p1.append(["wait", 7])
	p1.append(["leap", cx(89.5), 12])
	p1.append(["wait", 10])
	p1.append(["go", cx(87.5), {}])
	p1.append(["leap", cx(84), 4])
	p1.append(["go", cx(83), {"tol": 3}])
	p1.append(["fn", gate_fn()])
	p2.append(["fn", wait_for(func(lv: LevelBase, hh: PlayerBase) -> bool: return hh.sim_pos.y >= feet(40), 600)])
	p1.append(["sync", "M4b"])
	p2.append(["sync", "M4b"])
	p1.append(["go", cx(89), fight])
	p1.append(["fn", clear_fn(90, 200)])
	p1.append(["fn", swing_clear_fn(cx(92.5), 1)])
	p1.append(["leap", cx(95), 8])
	p1.append(["fn", hopper_fn()])
	p1.append(["fn", clear_fn(120, 300)])
	p1.append(["fn", unleech_fn()])
	p2.append(["fn", follow_fn(cx(86), 40, 600)])
	p2.append(["fn", wait_for(func(lv: LevelBase, hh: PlayerBase) -> bool: return hero(0).sim_pos.x >= cx(95) and hero(0).is_grounded(), 900)])
	p2.append(["go", cx(89), {}])
	p2.append(["fn", swing_clear_fn(cx(92.5), 1)])
	p2.append(["leap", cx(94.5), 8])
	p1.append(["sync", "g_d"])
	p2.append(["sync", "g_d"])
	p1.append(["go", cx(97), {"tol": 3}])
	p1.append(["fn", gate_fn()])
	p2.append(["fn", wait_for(func(lv: LevelBase, hh: PlayerBase) -> bool: return hh.sim_pos.y <= feet(38), 200)])
	# --- M5: the raptor pincer, the raptor and the ghost, the arch
	p1.append(["mark", "M5"])
	p1.append(["sync", "M5"])
	p2.append(["sync", "M5"])
	p1.append(["go", cx(104), fight])
	p2.append(["go", cx(103), {}])
	p1.append(["fn", hopper_fn()])
	p1.append(["fn", hopper_fn()])
	p1.append(["fn", clear_fn(120, 300)])
	p2.append(["fn", clear_fn(120, 300)])
	p1.append(["fn", unleech_fn()])
	p2.append(["fn", unleech_fn()])
	p1.append(["sync", "g_e"])
	p2.append(["sync", "g_e"])
	p1.append(["go", cx(117), {"tol": 3}])
	p1.append(["fn", gate_fn()])
	p2.append(["fn", wait_for(func(lv: LevelBase, hh: PlayerBase) -> bool: return hh.sim_pos.y <= feet(27), 200)])
	# --- M6: the ghost, the pit, up to the gallery; the 'shamans' gate
	p1.append(["mark", "M6"])
	p1.append(["sync", "M6"])
	p2.append(["sync", "M6"])
	p1.append(["go", cx(122.5), fight])
	p1.append(["wait", 6])
	p1.append(["leap", cx(124), 8])
	p1.append(["wait", 6])
	p1.append(["leap", cx(129), 10])
	p1.append(["go", cx(130), {}])
	p2.append(["fn", wait_for(func(lv: LevelBase, hh: PlayerBase) -> bool: return hero(0).sim_pos.y <= feet(20) and hero(0).is_grounded(), 400)])
	p2.append(["go", cx(122.5), {}])
	p2.append(["wait", 6])
	p2.append(["leap", cx(124), 8])
	p2.append(["wait", 6])
	p2.append(["leap", cx(128.5), 10])
	p1.append(["sync", "gallery"])
	p2.append(["sync", "gallery"])
	# both drop in beside the Shaman: P2 through hatch N0 (left of him), P1 through hatch N1 (right of him)
	p1.append(["go", cx(137.5), {"tol": 2}])
	p2.append(["go", cx(131.5), {"tol": 2}])
	p1.append(["sync", "drop1"])
	p2.append(["sync", "drop1"])
	p1.append(["fn", drop_floor_fn()])
	p2.append(["fn", drop_floor_fn()])
	p1.append(["fn", pin_fn(1300)])
	p2.append(["fn", pin_fn(1300)])
	p1.append(["sync", "g1"])
	p2.append(["sync", "g1"])
	# Guard 1: P1 baits from the front (left, 50 px); P2 climbs out by the perch of N0, walks the gallery and drops in
	# through N2 behind it (60 px)
	p1.append(["go", 2214, {"tol": 2}])
	p1.append(["face", 1])
	p2.append(["go", cx(131.5), {"tol": 1}])
	p2.append(["fn", climb_fn()])
	p2.append(["go", cx(144.5), {"tol": 1}])
	p2.append(["fn", drop_floor_fn()])
	p2.append(["go", 2324, {"tol": 2}])
	p2.append(["face", -1])
	p2.append(["fn", strike_until_dead_fn(Vector2i(141, 25))])
	p1.append(["fn", wait_for(func(lv: LevelBase, hh: PlayerBase) -> bool: return enemy_dead(lv, 141), 900)])
	p1.append(["sync", "g2"])
	p2.append(["sync", "g2"])
	# Guard 2: P2 baits from the front; P1 climbs out by the perch of N1 and drops in through N3 behind it
	p2.append(["go", 2326, {"tol": 2}])
	p2.append(["face", 1])
	p1.append(["go", cx(137.5), {"tol": 1}])
	p1.append(["fn", climb_fn()])
	p1.append(["go", cx(151.5), {"tol": 1}])
	p1.append(["fn", drop_floor_fn()])
	p1.append(["go", 2432, {"tol": 2}])
	p1.append(["face", -1])
	p1.append(["fn", strike_until_dead_fn(Vector2i(148, 25))])
	p2.append(["fn", wait_for(func(lv: LevelBase, hh: PlayerBase) -> bool: return enemy_dead(lv, 148), 900)])
	p1.append(["sync", "out"])
	p2.append(["sync", "out"])
	# out: the keeper door at the hall's end rises; both walk through it to the arch
	p1.append(["fn", wait_for(func(lv: LevelBase, hh: PlayerBase) -> bool: return door_risen(lv, 153, 25, 4), 200)])
	p2.append(["fn", wait_for(func(lv: LevelBase, hh: PlayerBase) -> bool: return door_risen(lv, 153, 25, 4), 200)])
	p1.append(["go", cx(157), {"tol": 3}])
	p2.append(["fn", follow_fn(cx(155.5), 24, 300)])
	p1.append(["sync", "door"])
	p2.append(["sync", "door"])
	p1.append(["fn", gate_fn()])
	p2.append(["fn", wait_for(func(lv: LevelBase, hh: PlayerBase) -> bool: return hh.sim_pos.y >= feet(30), 300)])
	# --- M7: the scarabs, the raptor pincer, the exit
	p1.append(["mark", "M7"])
	p1.append(["sync", "M7"])
	p2.append(["sync", "M7"])
	p1.append(["go", cx(167), fight])
	p1.append(["fn", clear_fn(90, 300)])
	p2.append(["fn", follow_fn(cx(165), 40, 400)])
	p2.append(["fn", clear_fn(90, 300)])
	p1.append(["sync", "r7"])
	p2.append(["sync", "r7"])
	p1.append(["fn", hopper_fn(200, 400)])
	p1.append(["fn", unleech_fn()])
	p2.append(["fn", unleech_fn()])
	p1.append(["sync", "exit"])
	p2.append(["sync", "exit"])
	p1.append(["hold", R])
	p2.append(["hold", R])
	return [p1, p2]


## True once the enemy spawned in column `col` is dead (or gone).
func enemy_dead(lv: LevelBase, col: int) -> bool:
	for entity: SimEntity in lv.get_kind(Defs.Kind.ENEMY):
		var foe: EnemyBase = entity as EnemyBase
		if foe != null and (foe.spawn_pos.x >> 4) == col:
			return foe.dead
	return true


## Strike (8 ticks of Fire, then a pause) until the enemy spawned in `cell` is dead.
func strike_until_dead_fn(cell: Vector2i, limit: int = 500) -> Callable:
	return func(lv: LevelBase, h: PlayerBase, n: int) -> int:
		if n > limit or enemy_dead(lv, cell.x):
			return -1
		return F if n % 16 < 8 else 0


## Out of the keeper hall under a hatch: a jump straight up onto the perch (48 px), released, and a second one through
## the hole onto the hatch in the gallery floor (48 px more); ends standing in the gallery (feet on row 20).
func climb_fn(limit: int = 240) -> Callable:
	return func(lv: LevelBase, h: PlayerBase, n: int) -> int:
		var st: Dictionary = _st[h.slot]
		if n > limit or (h.is_grounded() and h.sim_pos.y == feet(20)):
			return -1
		if h.is_grounded():
			# a fresh press for every jump: one tick released after landing
			if bool(st.get("held", false)):
				st["held"] = false
				return 0
			st["held"] = true
			return U
		st["held"] = true
		return U if h.yvel < 0 else 0


## Down through the hatch underfoot, onto the perch under it and down through that too; ends on the hall floor.
func drop_floor_fn(limit: int = 120) -> Callable:
	return func(lv: LevelBase, h: PlayerBase, n: int) -> int:
		if n > limit or (n > 0 and h.is_grounded() and h.sim_pos.y == feet(26)):
			return -1
		# Down held in the air too: released inside the hatch cell he would land on it again
		return D


## The Shaman pin: each hero closes in on him from his side (they dropped in on both sides) and strikes when he is
## in reach; ends when he is dead.
func pin_fn(limit: int = 1300) -> Callable:
	return func(lv: LevelBase, h: PlayerBase, n: int) -> int:
		if n > limit:
			return -1
		var s: EnemyBase = null
		for entity: SimEntity in lv.get_kind(Defs.Kind.ENEMY):
			if entity is Shaman and not (entity as EnemyBase).dead:
				s = entity as EnemyBase
		if s == null:
			return -1
		var st: Dictionary = _st[h.slot]
		if int(st.get("striking", 0)) > 0:
			st["striking"] = int(st["striking"]) - 1
			return F if int(st["striking"]) > 7 else 0
		if not h.is_grounded():
			return 0
		var rel: int = s.sim_pos.x - h.sim_pos.x
		var side: int = 1 if rel > 0 else -1
		if h.facing != side:
			return R if side > 0 else L
		if absi(rel) <= 30:
			st["striking"] = 10
			return F
		return (R if side > 0 else L) if n % 2 == 0 else 0


## True once the plate door anchored at (col, row) rose at least `rows` rows.
func door_risen(lv: LevelBase, col: int, row: int, rows: int) -> bool:
	for node: Node in lv.find_children("*", "", true, false):
		var column: RisingColumn = node as RisingColumn
		if column != null and column.block.position.x == col and column.block.end.y - 1 == row:
			return column.risen >= rows
	return false
