extends "res://tools/autoplay/recorders/db1/p5/db1lib.gd"
## w2_l1_coop two-stream routes (DB1, wf10): closed-loop duo macros (P1 | P2), Beginner and Expert.

const FLOOR18: int = 288
const PLATEAU: int = 256
const CH1: int = 400


func header() -> String:
	var d: String = "expert" if expert else "beginner"
	return "# route: level=w2_l1_coop difficulty=%s players=2 ends=exit after=tally expect=wipes:0,eggs:0,x2_gates:2\n" % d


func stop_at() -> String:
	return str(opts.get("stop", ""))


func build() -> Array:
	var p1: Array = []
	var p2: Array = []
	gallery(p1, p2)
	if stop_at() == "gallery":
		return [p1, p2]
	hatches(p1, p2)
	if stop_at() == "hatches":
		return [p1, p2]
	chambers(p1, p2)
	if stop_at() == "chambers":
		return [p1, p2]
	den(p1, p2)
	if stop_at() == "den":
		return [p1, p2]
	deep(p1, p2)
	if stop_at() == "deep":
		return [p1, p2]
	shaft(p1, p2)
	return [p1, p2]


## Echo Gallery: P1 the inset spot; over the hill onto the plateau; the Shellback (and on Expert its neighbour) by
## pincers (P2 baits at the plateau's foot, P1 jumps over it and clubs its back); down to the block before the hall.
func gallery(p1: Array, p2: Array) -> void:
	var fight: Dictionary = {"fight": true}
	p2.append(["keys", 2, R])
	p1.append(["go", 108, {"tol": 1}])
	p1.append(["face", 1])
	p1.append(["fn", strike_open_fn(Vector2i(7, 18), D)])
	p2.append(["go", 80, {"tol": 3}])
	p1.append(["sync", "inset"])
	p2.append(["sync", "inset"])
	# over the hill (cols 12-15) and up the plateau's slope (col 20)
	p1.append(["go", 330, fight])
	p2.append(["go", 300, fight])
	p1.append(["sync", "plateau"])
	p2.append(["sync", "plateau"])
	# the Shellback of the plateau (28, 15; beat 392-504) and on Expert its neighbour (36, 15; beat 536-616): both
	# jump over each when it walks towards them (a low hop: the row-13 ledge hangs over the first beat)
	if not expert:
		hop_over(p1, p2, "turtle1", 350, 256, 380, 520, int(opts.get("t1_run", "6")), int(opts.get("t1_up", "2")),
				int(opts.get("t1_glo", "84")), int(opts.get("t1_ghi", "100")))
	else:
		# Expert: P1 jumps over the Shellback alone and clubs the plain turtle beside it (36, 15; beat 536-616) twice
		# before the Shellback comes back along its beat; then P2 jumps over the Shellback and joins him
		p2.append(["go", 326, {"tol": 2}])
		p1.append(["sync", "t1_set"])
		p2.append(["sync", "t1_set"])
		hop_over_one(p1, "turtle1a", 350, 256, 380, 520, int(opts.get("t1_run", "6")), int(opts.get("t1_up", "2")))
		p1.append(["fn", chase_kill_fn(576, 256, 100, 26, 505, 660, 600)])
		p1.append(["go", 618, {"tol": 3}])
		p2.append(guard_cmd(func(_lv: LevelBase, _h: PlayerBase) -> bool: return hero(0).sim_pos.x >= 600 and hero(0).is_grounded() and enemy_near(576, 256, 100, true) == null, 900, "turtle2"))
		hop_over_one(p2, "turtle1b", 350, 256, 380, 520, int(opts.get("t1_run", "6")), int(opts.get("t1_up", "2")))
		p2.append(["go", 590, {"tol": 3}])
		p1.append(["sync", "turtle2"])
		p2.append(["sync", "turtle2"])
	# the bat on its thread at the plateau's end (39, 9): P1 clubs it high when it is down, P2 behind him
	p1.append(["go", 606, {"tol": 2}])
	p1.append(["face", 1])
	p1.append(["fn", kill_fn(632, 220, 50, 600)])
	p2.append(["go", 560, {"tol": 3}])
	p2.append(guard_cmd(func(_lv: LevelBase, _h: PlayerBase) -> bool: return enemy_near(632, 220, 50) == null, 600, "bat39", 70))
	p1.append(["sync", "bat39"])
	p2.append(["sync", "bat39"])
	# down the plateau's far slope and onto the block (cols 45-48, top 240) before the hall
	p1.append(["go", 700, fight])
	p1.append(["fn", hop_fn(744, 20)])
	p1.append(["go", 744, {"tol": 2}])
	p2.append(["go", 680, fight])
	p2.append(guard_cmd(partner_clear(728, 240, 12), 600, "block"))
	p2.append(["fn", hop_fn(726, 20)])
	p1.append(["sync", "block"])
	p2.append(["sync", "block"])
	if expert:
		# the Expert bat on its thread over plate pa (49, 9): P1 clubs it high from the block
		p1.append(["go", 768, {"tol": 1}])
		p1.append(["face", 1])
		p1.append(["fn", kill_fn(792, 190, 90, 600)])
		p2.append(guard_cmd(func(_lv: LevelBase, _h: PlayerBase) -> bool: return enemy_near(792, 190, 90) == null, 600, "bat49", 60))
		p1.append(["sync", "bat49"])
		p2.append(["sync", "bat49"])


## Gate 'hatches': P2 crouches on plate pa (49, 17) - trapdoor H1 (cols 58-59) rises and P1 drops into the first
## chamber; P1 clubs the lurker there and crouches on plate pb (50, 24) - H2 (cols 60-61) rises and P2 drops in.
func hatches(p1: Array, p2: Array) -> void:
	p2.append(["go", 792, {"tol": 2}])
	p2.append(["sync", "pa_on"])
	p1.append(["sync", "pa_on"])
	p2.append(["until", func(_lv: LevelBase, _h: PlayerBase) -> bool: return hero(0).sim_pos.y >= CH1 - 2 and hero(0).is_grounded(), D])
	p1.append(["until", func(_lv: LevelBase, _h: PlayerBase) -> bool: return column_risen_fn(58, 2), 0])
	p1.append(["go", 944, {"tol": 3}])
	p1.append(["until", func(_lv: LevelBase, h: PlayerBase) -> bool: return h.is_grounded() and h.sim_pos.y >= CH1 - 2, 0])
	# the lurker over plate pb (50, 20): let it come down and club it, then crouch on pb
	p1.append(["go", int(opts.get("lurk1_x", "940")), {"tol": 3}])
	p1.append(["face", -1])
	p1.append(["fn", kill_fn(808, 380, 160, 600, {"cls": "Lurker"})])
	p1.append(["go", 808, {"tol": 2}])
	p1.append(["until", func(_lv: LevelBase, _h: PlayerBase) -> bool: return hero(1).sim_pos.y >= CH1 - 2 and hero(1).is_grounded(), D])
	p2.append(["until", func(_lv: LevelBase, _h: PlayerBase) -> bool: return column_risen_fn(60, 2), D])
	p2.append(["go", 976, {"tol": 3}])
	p2.append(["until", func(_lv: LevelBase, h: PlayerBase) -> bool: return h.is_grounded() and h.sim_pos.y >= CH1 - 2, 0])
	p1.append(["sync", "chamber1"])
	p2.append(["sync", "chamber1"])


## Down the hatches: chamber 1 -> the big chamber (its Shellback jumped over, the lurker over the next hatch) -> the
## third chamber (crawl under the pendulum bat) -> the fourth chamber.
func chambers(p1: Array, p2: Array) -> void:
	var fight: Dictionary = {"fight": true}
	# the hatch of chamber 1 (cols 45-49): crouch on it, P1 first, P2 right after
	p1.append(["go", 752, {"tol": 3}])
	p1.append(["until", func(_lv: LevelBase, h: PlayerBase) -> bool: return h.sim_pos.y >= 556 and h.is_grounded(), D])
	p1.append(["go", 820, {"tol": 3}])
	p2.append(["go", 840, {"tol": 3}])
	p2.append(guard_cmd(func(_lv: LevelBase, _h: PlayerBase) -> bool: return hero(0).sim_pos.y >= 556 and hero(0).is_grounded(), 400, "hatch1"))
	p2.append(["go", 744, {"tol": 3}])
	p2.append(["until", func(_lv: LevelBase, h: PlayerBase) -> bool: return h.sim_pos.y >= 556 and h.is_grounded(), D])
	p1.append(["sync", "big"])
	p2.append(["sync", "big"])
	# the Shellback of the big chamber (57, 34) patrols 869-990: both jump over it (the same keys, 24 px apart)
	hop_over(p1, p2, "turtle3", 850, 560, 860, 1000, int(opts.get("t3_run", "6")))
	if expert:
		# the Expert little rex (62, 34) comes as soon as we land: both club it (two strikes on Expert's hp)
		for p: Array in [p1, p2]:
			p.append(["fn", kill_fn(1000, 544, 160, 600, {"awake_only": true, "cls": "Hopper",
					"charge": opts.has("rex34_charge")})])
			p.append(barrier("hopper34"))
	# the lurker over the second hatch (71, 27): P1 steps into its reach and clubs it when it is down
	p2.append(["go", 1040, fight])
	p1.append(["go", int(opts.get("lurk_x", "1092")), fight])
	p1.append(["face", 1])
	p1.append(["fn", kill_fn(1144, 520, 70, int(opts.get("lurk_wait", "400")))])
	p2.append(guard_cmd(func(_lv: LevelBase, _h: PlayerBase) -> bool: return enemy_near(1144, 520, 70) == null, int(opts.get("lurk_wait", "400")) + 30, "lurker27", 90))
	p1.append(["sync", "lurker27"])
	p2.append(["sync", "lurker27"])
	# the second hatch (cols 66-71) into the third chamber, P1 first
	p1.append(["go", 1128, {"tol": 3}])
	p1.append(["until", func(_lv: LevelBase, h: PlayerBase) -> bool: return h.sim_pos.y >= 668 and h.is_grounded(), D])
	p1.append(["go", 1180, {"tol": 3, "fight": true}])
	p2.append(guard_cmd(func(_lv: LevelBase, _h: PlayerBase) -> bool: return hero(0).sim_pos.y >= 668 and hero(0).is_grounded(), 400, "hatch2"))
	p2.append(["go", 1132, {"tol": 3}])
	p2.append(["until", func(_lv: LevelBase, h: PlayerBase) -> bool: return h.sim_pos.y >= 668 and h.is_grounded(), D])
	p1.append(["sync", "third"])
	p2.append(["sync", "third"])
	if expert:
		# the Expert bat on its thread under the hatch (67, 37): P1 clubs it high
		p1.append(["go", 1104, {"tol": 1}])
		p1.append(["face", -1])
		p1.append(["fn", kill_fn(1080, 630, 60, 600)])
		p2.append(["go", 1150, {"tol": 3}])
		p2.append(guard_cmd(func(_lv: LevelBase, _h: PlayerBase) -> bool: return enemy_near(1080, 630, 60) == null, 600, "dangler37", 40))
		p1.append(["sync", "dangler37"])
		p2.append(["sync", "dangler37"])
	# the pendulum bat (60, 41) swings just over a crouching head: both crawl under it onto the third hatch (cols
	# 52-57), which drops a crouching hero - P1 first, P2 once P1 is down
	p1.append(["go", 1012, {"tol": 2}])
	p2.append(["go", 1060, {"tol": 3}])
	p1.append(["sync", "swinger"])
	p2.append(["sync", "swinger"])
	p1.append(["until", func(_lv: LevelBase, h: PlayerBase) -> bool: return h.sim_pos.y >= 812 and h.is_grounded(), D | L])
	p1.append(["go", 960, {"tol": 3, "fight": true}])
	p2.append(guard_cmd(func(_lv: LevelBase, _h: PlayerBase) -> bool: return hero(0).sim_pos.y >= 812 and hero(0).is_grounded(), 400, "hatch3"))
	p2.append(["go", 1012, {"tol": 3}])
	p2.append(["until", func(_lv: LevelBase, h: PlayerBase) -> bool: return h.sim_pos.y >= 812 and h.is_grounded(), D | L])
	p1.append(["sync", "fourth"])
	p2.append(["sync", "fourth"])


## The fourth chamber: its Shellback (70, 50) jumped over; gate 'den' - the two keeper Shellbacks of the low hall
## (79, 50) and (84, 50) stand still and face the nearer caveman: P1 hops over each and stands close behind it, P2
## clubs its back from the other side; their door (col 88) rises and both walk through to the far cell (89, 50).
func den(p1: Array, p2: Array) -> void:
	# the Shellback of the fourth chamber (70, 50) patrols 1072-1176: both jump over it
	hop_over(p1, p2, "turtle4", 1030, 816, 1040, 1200, int(opts.get("t4_run", "6")))
	for kx: int in [1272, 1352]:
		var tag: String = "keeper%d" % kx
		p1.append(["go", kx - 40, {"tol": 2}])
		p2.append(["go", kx - 70, {"tol": 2}])
		p1.append(["sync", tag])
		p2.append(["sync", tag])
		p1.append(["fn", hop_fn(kx + int(opts.get("keep_behind", "30")), int(opts.get("keep_up", "6")))])
		p1.append(["go", kx + int(opts.get("keep_behind", "30")), {"tol": 1}])
		p1.append(["face", -1])
		p1.append(["sync", tag + "_set"])
		p2.append(["sync", tag + "_set"])
		p2.append(["go", kx - int(opts.get("keep_strike", "32")), {"tol": 1}])
		p2.append(["face", 1])
		p2.append(["fn", kill_fn(kx, 816, 20, 300, {"keep_face": true})])
		p1.append(guard_cmd(func(_lv: LevelBase, _h: PlayerBase) -> bool: return enemy_near(kx, 816, 20) == null, 400, tag + "_wait", 0))
		p1.append(["sync", tag + "_done"])
		p2.append(["sync", tag + "_done"])
	p1.append(["until", func(_lv: LevelBase, _h: PlayerBase) -> bool: return column_risen_fn(88, 4), 0])
	p1.append(["go", 1440, {"tol": 3}])
	p2.append(["go", 1410, {"tol": 3}])
	p1.append(["sync", "den_done"])
	p2.append(["sync", "den_done"])


## Both jump over a patrolling Shellback: they stand 24 px apart (P1 in front at `x`), wait until it walks towards
## them at the right distance, run `run` ticks and jump with the same keys (U+R 20 ticks), then walk on.
func hop_over(p1: Array, p2: Array, tag: String, x: int, fy: int, lo: int, hi: int, run: int, up: int = 20,
		glo: int = -1, ghi: int = -1) -> void:
	p1.append(["go", x, {"tol": 1}])
	p2.append(["go", x - 24, {"tol": 1}])
	p1.append(["sync", tag])
	p2.append(["sync", tag])
	var cond: Callable = func(lv: LevelBase, _h: PlayerBase) -> bool:
		for entity: SimEntity in lv.get_kind(Defs.Kind.ENEMY):
			var foe: EnemyBase = entity as EnemyBase
			if foe != null and not foe.dead and foe.coop_trait == Defs.CoopTrait.SHELL and foe.sim_pos.x >= lo - 40 and foe.sim_pos.x <= hi + 40 and absi(foe.sim_pos.y - fy) < 24:
				var gap: int = foe.sim_pos.x - x
				return foe.xvel < 0 and gap >= (glo if glo >= 0 else int(opts.get("over_lo", "84"))) 						and gap <= (ghi if ghi >= 0 else int(opts.get("over_hi", "100")))
		return true
	for p: Array in [p1, p2]:
		p.append(guard_cmd(cond, 900, tag + "_wait"))
		p.append(barrier(tag + "_go"))
		p.append(["keys", run, R])
		p.append(["keys", up, U | R])
		p.append(["keys", maxi(20 - up, 0), R])
		p.append(["until", func(_lv: LevelBase, h: PlayerBase) -> bool: return h.is_grounded(), R])


## One hero jumps over a patrolling Shellback (standing at `x`, when it walks towards him at the right distance).
func hop_over_one(p: Array, tag: String, x: int, fy: int, lo: int, hi: int, run: int, up: int = 20) -> void:
	p.append(["go", x, {"tol": 1}])
	p.append(guard_cmd(func(lv: LevelBase, _h: PlayerBase) -> bool:
		for entity: SimEntity in lv.get_kind(Defs.Kind.ENEMY):
			var foe: EnemyBase = entity as EnemyBase
			if foe != null and not foe.dead and foe.coop_trait == Defs.CoopTrait.SHELL and foe.sim_pos.x >= lo - 40 and foe.sim_pos.x <= hi + 40 and absi(foe.sim_pos.y - fy) < 24:
				var gap: int = foe.sim_pos.x - x
				return foe.xvel < 0 and gap >= int(opts.get("over_lo", "84")) and gap <= int(opts.get("over_hi", "100"))
		return true, 900, tag + "_wait"))
	p.append(["keys", run, R])
	p.append(["keys", up, U | R])
	p.append(["keys", maxi(20 - up, 0), R])
	p.append(["until", func(_lv: LevelBase, h: PlayerBase) -> bool: return h.is_grounded(), R])


func column_risen_fn(col: int, rows: int) -> bool:
	for kind: int in Defs.KIND_COUNT:
		for entity: SimEntity in level.get_kind(kind):
			var c: RisingColumn = entity as RisingColumn
			if c != null and c.sim_pos.x >> 4 == col and c.risen >= rows:
				return true
	return false


## The Echo Shaft: up its first ledges to the shelf with the checkpoint (P2 a ledge behind P1); both onto the stone
## lift on the same tick (clubbing the bat that flies across its run), across to the right shelf at its top; the
## zigzag of ledges to the top (the bat on its thread clubbed from the ledge below it); the exit gallery: over the
## Shellback, the little rex, into the exit totem, both.
func shaft(p1: Array, p2: Array) -> void:
	var fight: Dictionary = {"fight": true}
	ledges(p1, p2, "s", [[2844, 2868, 20, 944, 2868], [2842, 2790, 20, 896, 2790], [2728, 2672, 20, 848, 2672]], 30)
	p1.append(["go", 2640, {"tol": 3}])
	# both onto the stone lift (169.5, 54): the same keys on the same tick from the shelf's end, 24 px apart
	p1.append(["go", 2680, {"tol": 0}])
	p2.append(["go", 2656, {"tol": 0}])
	# board when the bat that flies across the lift's run (176, 47; x 2760-2888) is about to turn at its left end: it
	# is then at the right end of its round while the lift carries us through its height
	for p: Array in [p1, p2]:
		p.append(guard_cmd(flyer_phase(int(opts.get("fly_lo", "2790")), int(opts.get("fly_hi", "2802"))), 400, "flyer_phase", 60))
		p.append(barrier("stone_lift"))
		p.append(["keys", 2, U | R])
		p.append(["keys", 6, R])
		p.append(["until", func(_lv: LevelBase, h: PlayerBase) -> bool: return h.is_grounded(), 0])
		# the bat that flies across the run: P1 (at the lift's front) clubs it high or forward, P2 forward only - a
		# high strike's hop would leave him behind the moving lift
		p.append(guard_cmd(func(_lv: LevelBase, h: PlayerBase) -> bool: return h.sim_pos.y <= int(opts.get("slift_top", "708")), 400, "stone_lift_ride", 70, {} if p == p1 else {"no_high": true}))
		p.append(barrier("stone_lift_top"))
		p.append(["keys", 20, U | R])
		p.append(["until", func(_lv: LevelBase, h: PlayerBase) -> bool: return h.is_grounded(), int(opts.get("slift_air", "16"))])
	p1.append(["go", 2952, {"tol": 3}])
	p2.append(["go", 2926, {"tol": 3}])
	p1.append(["sync", "right_shelf"])
	p2.append(["sync", "right_shelf"])
	if stop_at() == "right_shelf":
		return
	# the zigzag: left, left, right, right, left, left (the bat on its thread at 170, 26 first), right, right
	# (Expert: the stinger at 168, 30 is a loner - it dives only at a straggler inside its reach, which here is the left
	# part of the row-28 ledge and the hop from it to row 25: whoever is there has his partner within 64 px)
	if expert:
		# Expert: the stinger (168, 30) is a loner - it dives at a straggler inside its reach (row 37, the left part of
		# row 28 and the hops through them), so there the two hop side by side, the same keys on the same tick
		ledges(p1, p2, "z1", [[2916, 2832, 20, 640, 2880]], 30)
		p1.append(["go", int(opts.get("r40_p1", "2840")), {"tol": 2}])
		p1.append(["sync", "row40_both"])
		p2.append(["sync", "row40_both"])
		pair_hop(p1, p2, "r37", int(opts.get("r37_x", "2860")), int(opts.get("r37_x", "2860")) + 24, L, int(opts.get("r37_run", "12")))
		pair_hop(p1, p2, "r34", int(opts.get("r34_x", "2683")), int(opts.get("r34_x", "2683")) + 24, R, int(opts.get("r34_run", "12")))
		p1.append(["go", 2850, {"tol": 2}])
		p2.append(["go", 2826, {"tol": 2}])
		p1.append(["sync", "r34_ok"])
		p2.append(["sync", "r34_ok"])
		ledges(p1, p2, "z1b", [[2891, 2935, 20, 496, 2935], [2884, 2830, 20, 448, 2780]], 30)
	else:
		ledges(p1, p2, "z1", [[2916, 2862, 20, 640, 2862], [2804, 2745, 20, 592, 2745], [2763, 2820, 20, 544, 2820],
				[2891, 2935, 20, 496, 2935], [2884, 2830, 20, 448, 2776]], 30)
	p1.append(["sync", "row28"])
	p2.append(["sync", "row28"])
	# the bat on its thread (170, 26), clubbed high by P1 from the row-28 ledge, P2 beside him
	p1.append(["go", 2762, {"tol": 0}])
	p1.append(["face", -1])
	p1.append(["fn", kill_fn(2728, 440, 60, 600, {"cls": "Dangler"})])
	p2.append(["go", 2790, {"tol": 2}])
	p2.append(guard_cmd(func(_lv: LevelBase, _h: PlayerBase) -> bool: return enemy_near(2728, 440, 60, false, "Dangler") == null, 600, "bat170", 0))
	p1.append(["sync", "bat170"])
	p2.append(["sync", "bat170"])
	if expert:
		pair_hop(p1, p2, "r25", int(opts.get("r25_x", "2810")), int(opts.get("r25_x", "2810")) + 24, L, int(opts.get("r25_run", "12")))
	else:
		# up to row 25: P1 hops while P2 walks along to the ledge's left end; P1 steps aside; P2 hops
		p1.append(["go", 2756, {"tol": 2}])
		p1.append(["fn", hop_fn(2700, 20)])
		p1.append(["go", 2662, {"tol": 2}])
		p2.append(["go", 2780, {"tol": 2}])
		p2.append(guard_cmd(func(_lv: LevelBase, _h: PlayerBase) -> bool: return hero(0).is_grounded() and hero(0).sim_pos.y == 400, 300, "row25"))
		p2.append(["go", 2756, {"tol": 2}])
		p2.append(guard_cmd(partner_clear(2700, 400, 30), 300, "row25b"))
		p2.append(["fn", hop_fn(2700, 20)])
	p1.append(["sync", "row25"])
	p2.append(["sync", "row25"])
	ledges(p1, p2, "z2", [[2715, 2770, 20, 352, 2770], [2843, 2900, 20, 304, 2900]], 30)
	p1.append(["go", 2990, fight])
	p2.append(guard_cmd(partner_clear(2898, 304, 30), 600, "gallery"))
	p2.append(["go", 2966, fight])
	p1.append(["sync", "gallery"])
	p2.append(["sync", "gallery"])
	# the exit gallery: over the Shellback (193, 18), the little rex (199, 18), into the exit totem (204, 18)
	# P1 jumps over the Shellback (when it walks towards him), walks on past its beat (it turns at 3048 and patrols
	# up to 3144) and clubs the little rex as it comes; then P2 the same jump, P1 guarding beyond the beat
	hop_over_one(p1, "turtle5a", 2990, 304, 3040, 3160, int(opts.get("t5_run", "6")))
	# P1 runs on past the little rex (199, 18) to the gallery's end and clubs it there as it hops after him
	if opts.get("rex_mode", "stand") == "run":
		p1.append(["run", int(opts.get("rex_run", "3230")), {}])
		p1.append(["go", int(opts.get("rex_stand", "3250")), {"tol": 3}])
		p1.append(["face", -1])
		p1.append(["fn", kill_fn(3192, 290, 160, 600, {"awake_only": true, "cls": "Hopper"})])
	else:
		# walk on towards the stand point, striking whenever a strike would hit the rex on its way
		var ks: Array = []
		for k: String in str(opts.get("rex_ks", "4,5,6,7")).split(","):
			ks.append(int(k))
		var rex: Dictionary = {"awake_only": true, "cls": "Hopper",
				"approach": int(opts.get("rex_stand", "3178")), "ks": ks}
		if opts.has("rex_crawl"):
			rex["crawl_from"] = int(opts["rex_crawl"])
		p1.append(["fn", kill_fn(3192, 290, 200, 600, rex)])
	p1.append(["go", 3240, {"tol": 3}])
	p2.append(guard_cmd(func(_lv: LevelBase, _h: PlayerBase) -> bool: return hero(0).sim_pos.x >= 3180 and enemy_near(3192, 290, 120, true) == null, 900, "rex_p1"))
	hop_over_one(p2, "turtle5b", 2990, 304, 3040, 3160, int(opts.get("t5_run", "6")))
	p2.append(["go", 3214, {"tol": 3}])
	p1.append(["sync", "gallery_done"])
	p2.append(["sync", "gallery_done"])
	p1.append(["hold", R])
	p2.append(["wait", 4])
	p2.append(["hold", R])


## Both hop to the next ledge side by side: P1 from x1, P2 from x2, the same keys on the same tick (a run of `run`
## ticks towards `dir`, then Up + `dir` 20 ticks), so they land as far apart as they stood.
func pair_hop(p1: Array, p2: Array, tag: String, x1: int, x2: int, dir: int, run: int = 0) -> void:
	p1.append(["go", x1, {"tol": 0}])
	p2.append(["go", x2, {"tol": 0}])
	for p: Array in [p1, p2]:
		p.append(barrier(tag))
		if run > 0:
			p.append(["keys", run, dir])
		p.append(["keys", 20, U | dir])
		p.append(["until", func(_lv: LevelBase, h: PlayerBase) -> bool: return h.is_grounded(), 0])
		p.append(barrier(tag + "_down"))


## True when the flyer of the shaft is dead or flies left with x in [lo, hi].
func flyer_phase(lo: int, hi: int) -> Callable:
	return func(lv: LevelBase, _h: PlayerBase) -> bool:
		for entity: SimEntity in lv.get_kind(Defs.Kind.ENEMY):
			var f: EnemyBase = entity as EnemyBase
			if f != null and f is Flyer and not f.dead and absi(f.sim_pos.x - 2824) < 100 and absi(f.sim_pos.y - 768) < 40:
				var dir_ok: bool = f.xvel < 0 if str(opts.get("fly_dir", "R")) == "L" else f.xvel > 0
				return dir_ok and f.sim_pos.x >= lo and f.sim_pos.x <= hi
		return true


## A climb of hops for two, P2 a hop behind: hops [start x, target x, up ticks, landing feet y, P2's target x].
func ledges(p1: Array, p2: Array, tag: String, hops: Array, clear: int = 30) -> void:
	for i: int in hops.size():
		var hp: Array = hops[i]
		p1.append(["go", int(hp[0]), {"tol": 2, "fight": true}])
		p1.append(["fn", hop_fn(int(hp[1]), int(hp[2]))])
		p1.append(["sync", "%s%d" % [tag, i]])
		p2.append(["sync", "%s%d" % [tag, i]])
		p2.append(guard_cmd(partner_clear(int(hp[4]), int(hp[3]), clear), 900, "%s%d" % [tag, i]))
		p2.append(["go", int(hp[0]), {"tol": 2}])
		p2.append(["fn", hop_fn(int(hp[4]), int(hp[2]))])


## The Dark Deep: the two leeches drop from the dark (P1 provokes each and clubs it as it comes, P2 behind him); down
## the cascade; over the pools, crawling under the two pendulum bats; the shore's bats on their threads; up the slope
## to the arch and down into the Echo Shaft.
func deep(p1: Array, p2: Array) -> void:
	var fight: Dictionary = {"fight": true}
	# the leeches (93, 48) and (101, 50) drop from the dark and come: both stand side by side facing them and club each
	# together (two strikes kill it before it can latch on - a leech on one's back only the partner reaches)
	p1.append(["go", 1455, {"tol": 2}])
	p1.append(["face", 1])
	p2.append(["go", 1441, {"tol": 2}])
	p2.append(["face", 1])
	p1.append(["sync", "leech1_set"])
	p2.append(["sync", "leech1_set"])
	for p: Array in [p1, p2]:
		p.append(["fn", kill_fn(1496, 830, 90, 600, {"cls": "Leech"})])
		p.append(["sync", "leech1"])
	p1.append(["go", 1572, {"tol": 2, "fight": true}])
	p1.append(["face", 1])
	p2.append(["go", 1556, {"tol": 2, "fight": true}])
	p2.append(["face", 1])
	p1.append(["sync", "leech2_set"])
	p2.append(["sync", "leech2_set"])
	for p: Array in [p1, p2]:
		p.append(["fn", kill_fn(1624, 880, 90, 600, {"cls": "Leech"})])
		p.append(["sync", "leech2"])
	# down the cascade to the first pool (cols 108-111)
	pool(p1, p2, "pool1", 1713, 1806, 1700)
	crawl(p1, p2, "swing1", 1812, 1938)
	pool(p1, p2, "pool2", 1942, 2040, 1930)
	pool(p1, p2, "pool3", 2087, 2173, 2070)
	crawl(p1, p2, "swing2", 2180, 2304)
	pool(p1, p2, "pool4", 2311, 2393, 2296)
	# the shore: the bat on its thread (152, 52) (and on Expert its neighbour (156, 52)): P1 clubs it high
	p1.append(["go", 2414, {"tol": 2}])
	p1.append(["face", 1])
	p1.append(["fn", kill_fn(2440, 900, 60, 900)])
	p2.append(["go", 2393, {"tol": 2}])
	p2.append(guard_cmd(func(_lv: LevelBase, _h: PlayerBase) -> bool: return enemy_near(2440, 900, 60) == null, 900, "bat152", 70))
	if expert:
		# the Expert bat on its thread over the slope (156, 52): both pass under it while it is up
		p1.append(guard_cmd(func(_lv: LevelBase, _h: PlayerBase) -> bool:
			var b: EnemyBase = enemy_near(2504, 870, 70)
			return b == null or (b.sim_pos.y <= int(opts.get("b156_y", "858")) and b.yvel <= 0), 900, "bat156"))
	p1.append(["sync", "shore"])
	p2.append(["sync", "shore"])
	# up the slope to the arch (row 58) and down into the Echo Shaft (col 164), P2 right behind
	p1.append(["run", 2630, fight])
	p1.append(["until", func(_lv: LevelBase, h: PlayerBase) -> bool: return h.is_grounded() and h.sim_pos.y >= 990, R])
	p1.append(["go", 2730, {"tol": 3}])
	p2.append(["run", 2630, fight])
	p2.append(["until", func(_lv: LevelBase, h: PlayerBase) -> bool: return h.is_grounded() and h.sim_pos.y >= 990, R])
	p2.append(["go", 2700, {"tol": 3}])
	p1.append(["sync", "shaft"])
	p2.append(["sync", "shaft"])


## A pool for two: P1 jumps from `from_x` to `to_x`; P2 waits where he stands (fighting) until P1 left the landing
## spot, then the same jump.
func pool(p1: Array, p2: Array, tag: String, from_x: int, to_x: int, _wait_x: int = 0) -> void:
	p1.append(["go", from_x, {"tol": 2, "fight": true}])
	p1.append(["fn", hop_fn(to_x, 20)])
	p1.append(["go", to_x + 24, {"tol": 3}])
	p2.append(guard_cmd(func(_lv: LevelBase, _h: PlayerBase) -> bool:
		var a: PlayerBase = hero(0)
		return a.is_grounded() and a.sim_pos.x >= to_x + 20, 900, tag))
	p2.append(["go", from_x, {"tol": 2}])
	p2.append(["fn", hop_fn(to_x, 20)])
	p1.append(["sync", tag])
	p2.append(["sync", tag])


## Both crawl (Down + Right) under a pendulum bat from `from_x` to `to_x`: P1 first; P2 from the same point once P1
## crawled 30 px on, to 8 px short of `to_x` (both stand up out of the bat's reach).
func crawl(p1: Array, p2: Array, tag: String, from_x: int, to_x: int) -> void:
	p1.append(["go", from_x, {"tol": 2}])
	p1.append(["sync", tag])
	p2.append(["sync", tag])
	p1.append(["until", func(_lv: LevelBase, h: PlayerBase) -> bool: return h.sim_pos.x >= to_x, D | R])
	p2.append(guard_cmd(partner_beyond_x(from_x + 30), 600, tag + "_p2"))
	p2.append(["go", from_x, {"tol": 2}])
	p2.append(["until", func(_lv: LevelBase, h: PlayerBase) -> bool: return h.sim_pos.x >= to_x - 8, D | R])
