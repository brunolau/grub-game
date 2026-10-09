extends "res://tools/autoplay/recorders/d8/coop_lib.gd"
## The two-stream co-op route of w8_l1_coop (D8), recorded by probe_work.gd --bot --players=2 (Expert only: one
## route, w8_l1_coop.inputs). P1 leads and fights; P2 follows. Gate 'hall': P1 baits the Shellbacks from the front,
## P2 walks the lintel and drops in behind each through its hole. Gate 'stairs': both heave the boulder onto plate A,
## P2 holds plate B while P1 climbs the rising stair, P1 holds plate C on the summit while P2 climbs the vine shaft.


func header() -> String:
	return "# route: level=w8_l1_coop difficulty=expert players=2 ends=exit after=tally expect=x2_gates:2,min_checkpoints:4\n"


func y_feet(row: int) -> int:
	return row * 16


func build() -> Array:
	var fight: Dictionary = {"fight": true}
	var p1: Array = []
	var p2: Array = []
	# --- (A) the outskirts: P1 clears the raptor, both take stair 1
	p2.append(["keys", 2, R])
	p1.append(["mark", "start"])
	p1.append(["go", cx(20.5), fight])
	p1.append(["fn", hopper_fn()])
	p1.append(["go", cx(20.5), fight])
	p1.append(["wait", 20])
	p2.append(["fn", follow_fn(cx(12), 40)])
	p2.append(["sync", "stair1"])
	p1.append(["sync", "stair1"])
	for col: float in [23.0, 25.0, 27.0, 29.0]:
		p1.append(["wait", 7])
		p1.append(["leap", cx(col), 8])
	p2.append(["go", cx(20.5), {}])
	p2.append(["wait", 30])
	for col: float in [23.0, 25.0, 27.0]:
		p2.append(["wait", 7])
		p2.append(["leap", cx(col), 8])
	p2.append(["wait", 7])
	p2.append(["leap", cx(31), 8])
	# --- (B) terrace T1: the ghost, then the 'hall' gate
	p1.append(["go", cx(32), fight])
	p1.append(["sync", "hall"])
	p2.append(["sync", "hall"])
	# P2 onto the jade step, onto the lintel, to the first hole; P1 into the hall in front of Shellback 1
	p2.append(["go", cx(34.5), {}])
	p2.append(["wait", 6])
	p2.append(["leap", cx(36.5), 6])
	p2.append(["wait", 6])
	p2.append(["fn", vleap_fn(cx(41), 14, 4)])
	p2.append(["go", cx(45.5), {}])
	p2.append(["go", cx(48), {"tol": 1}])
	p2.append(["until", func(lv: LevelBase, hh: PlayerBase) -> bool: return hh.is_grounded() and hh.sim_pos.y >= y_feet(42), 0])
	p2.append(["sync", "sb1"])
	p1.append(["fn", wait_for(func(lv: LevelBase, hh: PlayerBase) -> bool: return hero(1).sim_pos.y <= y_feet(39), 300)])
	p1.append(["go", cx(34.5), {}])
	p1.append(["wait", 6])
	p1.append(["leap", cx(39), 8])
	p1.append(["go", 644, {"tol": 2}])
	p1.append(["face", 1])
	p1.append(["sync", "sb1"])
	# P2 drops behind Shellback 1 and strikes its back while P1 baits
	p2.append(["keys", 6, D])
	p2.append(["until", func(lv: LevelBase, hh: PlayerBase) -> bool: return hh.is_grounded() and hh.sim_pos.y >= y_feet(45), 0])
	p2.append(["go", 760, {"tol": 2}])
	p2.append(["face", -1])
	p2.append(["fn", strike_until_dead_fn(Vector2i(43, 44))])
	p1.append(["fn", wait_for(func(lv: LevelBase, hh: PlayerBase) -> bool: return keeper_dead(lv, 43), 400)])
	p2.append(["sync", "sb2"])
	p1.append(["sync", "sb2"])
	# Shellback 2: P1 baits from the front, P2 climbs out through the first hole and drops in through the second
	p1.append(["go", 772, {"tol": 2}])
	p1.append(["face", 1])
	p2.append(["go", 752, {"tol": 2}])
	p2.append(["wait", 4])
	p2.append(["leap", cx(48), 10])
	p2.append(["wait", 4])
	p2.append(["leap", cx(50.5), 12])
	p2.append(["go", cx(53), {}])
	p2.append(["go", cx(55), {"tol": 1}])
	p2.append(["until", func(lv: LevelBase, hh: PlayerBase) -> bool: return hh.is_grounded() and hh.sim_pos.y >= y_feet(42), 0])
	p2.append(["keys", 6, D])
	p2.append(["until", func(lv: LevelBase, hh: PlayerBase) -> bool: return hh.is_grounded() and hh.sim_pos.y >= y_feet(45), 0])
	p2.append(["go", 888, {"tol": 2}])
	p2.append(["face", -1])
	p2.append(["fn", strike_until_dead_fn(Vector2i(51, 44))])
	p1.append(["fn", wait_for(func(lv: LevelBase, hh: PlayerBase) -> bool: return keeper_dead(lv, 51), 900)])
	p1.append(["sync", "door"])
	p2.append(["sync", "door"])
	p1.append(["wait", 24])
	p2.append(["wait", 24])
	# --- (C) stair 2: P1 on the plinth's trigger, the pillars; P2 after him
	p1.append(["go", cx(59), {}])
	p1.append(["wait", 6])
	p1.append(["leap", cx(61.5), 8])
	p1.append(["wait", 24])
	p1.append(["go", cx(62.5), {"tol": 3}])
	p1.append(["go", cx(66), {"tol": 3}])
	for col: float in [69.0, 72.0, 75.0]:
		p1.append(["wait", 7])
		p1.append(["leap", cx(col), 8])
	p1.append(["wait", 7])
	p1.append(["leap", cx(78), 12])
	p1.append(["go", cx(81), {}])
	p2.append(["go", cx(58.5), {}])
	p2.append(["fn", wait_for(func(lv: LevelBase, hh: PlayerBase) -> bool: return hero(0).sim_pos.x >= cx(71), 400)])
	p2.append(["wait", 6])
	p2.append(["leap", cx(61.5), 8])
	p2.append(["go", cx(62.5), {"tol": 3}])
	p2.append(["go", cx(66), {"tol": 3}])
	for col: float in [69.0, 72.0, 75.0]:
		p2.append(["wait", 7])
		p2.append(["leap", cx(col), 8])
	p2.append(["wait", 7])
	p2.append(["leap", cx(78), 12])
	p1.append(["sync", "t2"])
	p2.append(["sync", "t2"])
	# --- (D) terrace T2: P2 keeps close behind P1 (the `lone` ghost keeps away from a pair); P1 kills the raptor;
	# the Mimic pincer: P1 jumps over it, P2 baits it from the near side (it bites the nearer hero and turns its back
	# to the far one), P1 strikes its back
	p2.append(["fn", shadow_fn(func(lv: LevelBase, hh: PlayerBase) -> bool: return hero(0).sim_pos.x >= cx(93), 36, 900)])
	p1.append(["go", cx(86.5), {}])
	p1.append(["fn", hopper_fn(160, 400, cx(86) + 4)])
	p1.append(["go", cx(94), fight])
	p1.append(["sync", "mimic"])
	p2.append(["sync", "mimic"])
	p1.append(["fn", mimic_fn(1, false)])
	p1.append(["go", 1664, {"tol": 2}])
	p1.append(["face", -1])
	p2.append(["fn", wait_for(func(lv: LevelBase, hh: PlayerBase) -> bool: return hero(0).sim_pos.x >= 1655 and hero(0).is_grounded(), 300)])
	p2.append(["go", 1556, {"tol": 2}])
	p2.append(["face", 1])
	p1.append(["fn", wait_for(func(lv: LevelBase, hh: PlayerBase) -> bool: return hero(1).sim_pos.x >= 1548 and hero(1).is_grounded(), 300)])
	p1.append(["go", 1630, {"tol": 3}])
	p1.append(["face", -1])
	p1.append(["fn", strike_until_dead_fn(Vector2i(99, 38))])
	p2.append(["fn", wait_for(func(lv: LevelBase, hh: PlayerBase) -> bool: return enemy_gone(lv, 99), 400)])
	p1.append(["sync", "hall"])
	p2.append(["sync", "hall"])
	p1.append(["go", cx(107), fight])
	p2.append(["fn", shadow_fn(func(lv: LevelBase, hh: PlayerBase) -> bool: return hero(0).sim_pos.x >= cx(106) and hero(0).xvel == 0, 36, 600)])
	p1.append(["sync", "stairs"])
	p2.append(["sync", "stairs"])
	# --- (E) the 'stairs' gate: both onto the dais behind the boulder and heave it onto plate A
	p1.append(["go", cx(116), {}])
	p1.append(["wait", 6])
	p1.append(["leap", cx(120), 10])
	p1.append(["go", cx(121), {}])
	p2.append(["go", cx(115), {}])
	p2.append(["fn", wait_for(func(lv: LevelBase, hh: PlayerBase) -> bool: return hero(0).sim_pos.y <= 35 * 16 and hero(0).is_grounded(), 300)])
	p2.append(["wait", 6])
	p2.append(["leap", cx(120), 10])
	p2.append(["go", cx(120.5), {}])
	p1.append(["sync", "heave"])
	p2.append(["sync", "heave"])
	p1.append(["fn", push_fn(127)])
	p2.append(["fn", push_fn(127)])
	p1.append(["sync", "heaved"])
	p2.append(["sync", "heaved"])
	# P2 to plate B (over the boulder) and crouches; P1 over the boulder to the stair's foot
	p2.append(["wait", 4])
	p2.append(["leap", cx(130), 10])
	p2.append(["go", cx(133), {"tol": 2}])
	p2.append(["fn", crouch_until(func(lv: LevelBase, hh: PlayerBase) -> bool: return hero(0).is_grounded() and hero(0).sim_pos.y <= 27 * 16 and hero(0).sim_pos.x >= cx(148))])
	p1.append(["wait", 30])
	p1.append(["leap", cx(130), 10])
	p1.append(["go", cx(139), {}])
	p1.append(["wait", 50])
	for col: float in [142.0, 144.0, 146.0]:
		p1.append(["wait", 7])
		p1.append(["leap", cx(col), 8])
	p1.append(["go", cx(148.5), {}])
	p1.append(["wait", 6])
	p1.append(["leap", cx(152), 6])
	p1.append(["go", cx(157), {"tol": 2}])
	p1.append(["fn", crouch_until(func(lv: LevelBase, hh: PlayerBase) -> bool: return hero(1).is_grounded() and hero(1).sim_pos.y <= 27 * 16 and hero(1).sim_pos.x >= cx(151))])
	# P2 off plate B to the shaft's door, then up the vine when it opened
	p2.append(["go", cx(146), {}])
	p2.append(["fn", wait_for(func(lv: LevelBase, hh: PlayerBase) -> bool: return door_open(lv, 147, 35), 600)])
	p2.append(["go", cx(150), {"tol": 2}])
	p2.append(["until", func(lv: LevelBase, hh: PlayerBase) -> bool: return hh.is_grounded() and hh.sim_pos.y <= 27 * 16, U])
	p2.append(["go", cx(153), {}])
	p1.append(["sync", "summit"])
	p2.append(["sync", "summit"])
	# --- (G) the summit: the far cell, the ghosts, the raptor pincer, the exit
	p1.append(["go", cx(161), fight])
	p2.append(["fn", follow_fn(cx(159), 40, 400)])
	p1.append(["fn", clear_fn(200, 400, "harrier")])
	p2.append(["fn", clear_fn(200, 400, "harrier")])
	p1.append(["go", cx(170), fight])
	p1.append(["fn", hopper_fn()])
	p2.append(["fn", follow_fn(cx(166), 40, 600)])
	p1.append(["go", cx(176), fight])
	p1.append(["fn", clear_fn(160, 300)])
	p2.append(["fn", follow_fn(cx(172), 40, 600)])
	p1.append(["sync", "raptor"])
	p2.append(["sync", "raptor"])
	p1.append(["go", cx(183), fight])
	p2.append(["go", cx(181), fight])
	p2.append(["fn", raptor_fn(true)])
	p1.append(["fn", raptor_fn(false)])
	p1.append(["sync", "exit"])
	p2.append(["sync", "exit"])
	p1.append(["go", cx(190), fight])
	p1.append(["fn", hopper_fn()])
	p1.append(["hold", R])
	p2.append(["wait", 30])
	p2.append(["hold", R])
	return [p1, p2]


## True once the keeper standing in cell `col` (any row) is dead.
func keeper_dead(lv: LevelBase, col: int) -> bool:
	for entity: SimEntity in lv.get_kind(Defs.Kind.ENEMY):
		var foe: EnemyBase = entity as EnemyBase
		if foe != null and (foe.spawn_pos.x >> 4) == col and foe.keeper != &"":
			return foe.dead
	return true


## Strike forward (8 ticks of Fire, then a pause) until the enemy spawned in `cell` is dead.
func strike_until_dead_fn(cell: Vector2i, limit: int = 400) -> Callable:
	return func(lv: LevelBase, h: PlayerBase, n: int) -> int:
		if n > limit or enemy_gone(lv, cell.x):
			return -1
		var k: int = n % 16
		return F if k < 8 else 0


## True once the plate door anchored at (col, row) rose at least 2 rows.
func door_open(lv: LevelBase, col: int, row: int) -> bool:
	for node: Node in lv.find_children("*", "", true, false):
		var column: RisingColumn = node as RisingColumn
		if column != null and column.block.position.x == col and column.block.end.y - 1 == row:
			return column.risen >= 3
	return false


## True once the enemy spawned in column `col` is dead or gone.
func enemy_gone(lv: LevelBase, col: int) -> bool:
	for entity: SimEntity in lv.get_kind(Defs.Kind.ENEMY):
		var foe: EnemyBase = entity as EnemyBase
		if foe != null and (foe.spawn_pos.x >> 4) == col:
			return foe.dead
	return true


## Keep `gap` px behind P1 (on his left) until `cond` holds: walk when farther, stand when nearer.
func shadow_fn(cond: Callable, gap: int = 36, limit: int = 900) -> Callable:
	return func(lv: LevelBase, h: PlayerBase, n: int) -> int:
		if cond.call(lv, h) or n > limit:
			return -1
		var lead: PlayerBase = hero(0)
		var want: int = lead.sim_pos.x - gap
		var dx: int = want - h.sim_pos.x
		if not h.is_grounded():
			return R if dx > 0 else 0
		if dx > 6:
			return R
		if dx < -10:
			return L
		return K if n % 60 == 30 else 0
