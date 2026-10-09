extends "res://tools/autoplay/recorders/db1/p5/db1lib.gd"
## bonus_b_coop two-stream route (DB1, wf10): closed-loop duo macros. Both climb the cake tower storey by storey, P1
## a hop ahead of P2 (P2 hops only once P1 left his landing spot); P1 opens the inset tile, the wall tile and the
## floor tiles, P2 the far floor tile and the right wall tile; both strike the two giant roasts (the twin rule:
## P1 strikes, P2 answers within the window); both ride the elevator together and reach the spiral staff.

const FLOOR: int = 1376
const BISCUIT: int = 1280
const CHOC: int = 1088
const ST57: int = 912
const SPIRAL: int = 672
const LEDGE36: int = 576
const CROWN: int = 480
const TIER: int = 288
const TOP: int = 240


func header() -> String:
	return "# route: level=bonus_b_coop difficulty=both players=2 source=w2_l1_coop ends=warp after=tally expect=no_enemies:true,eggs:0,wipes:0,min_spots:%s
" % str(opts.get("min_spots", "10")) 		+ "# Feast Land B \"Tower of Treats\" for two - the two-stream route on both difficulties (designer DB1, wf10; ticks:P1|P2,
" 		+ "# keys L R U D F K S; recorded from closed-loop duo macros, build/db1/p5/bot_bonus_b.gd). Both climb the cake tower
" 		+ "# storey by storey, P2 a hop behind P1 (he hops only once P1 left his landing spot). P1 opens the inset tile, the
" 		+ "# wall tile, the barrel and the floor tiles; P2 the plain floor tiles by the right spring and the wall tile of the
" 		+ "# spiral room's ledge; both board the elevator on the same tick and ride it up together; both strike the two giant
" 		+ "# roasts (the twin rule: P1 strikes, P2 answers 3 ticks later); both reach the spiral staff. Club only, no S.
"


func build() -> Array:
	var p1: Array = []
	var p2: Array = []
	# --- ground floor: P1 the inset tile, P2 the plain tiles by the right spring ---
	p2.append(["keys", 2, R])
	p1.append(["go", 119, {"tol": 1}])
	p1.append(["face", 1])
	p1.append(["fn", strike_open_fn(Vector2i(8, 86), D)])
	p2.append(["go", 90, {"tol": 2}])
	p2.append(wait_cmd(func(_lv: LevelBase, _h: PlayerBase) -> bool: return spot_at(Vector2i(8, 86)).opened, 600, "inset"))
	# P2 walks past P1 to the plain tiles (22-23, 86), P1 takes the middle spring first
	p2.append(["go", 343, {"tol": 1}])
	p2.append(["face", 1])
	p2.append(["fn", strike_open_fn(Vector2i(22, 86), D)])
	p2.append(["sync", "floor_done"])
	p1.append(["go", 200, {"tol": 2}])
	p1.append(["sync", "floor_done"])
	# the middle spring (19, 85): P1, then P2 once P1 walked off the landing spot
	p1.append(["go", 232, {"tol": 2}])
	p1.append(["fn", hop_fn(312, 20)])
	p1.append(["go", 42, {"tol": 1}])
	p1.append(["face", -1])
	p1.append(["fn", strike_open_fn(Vector2i(1, 79), 0)])
	p1.append(["sync", "wall_done"])
	p2.append(wait_cmd(partner_clear(320, BISCUIT, 60), 900, "spring1"))
	p2.append(["go", 232, {"tol": 2}])
	p2.append(["fn", hop_fn(312, 20)])
	p2.append(["go", 120, {"tol": 3}])
	p2.append(["sync", "wall_done"])
	# --- the icing stair: rows 77, 74, 71, then up through the chocolate room's floor ---
	stair(p1, p2)
	# --- chocolate room: P1 the barrel and the plain tiles; then both onto the elevator ---
	p1.append(["go", 376, {"tol": 2}])
	p1.append(["face", 1])
	p1.append(["fn", strike_open_fn(Vector2i(25, 67), 0)])
	p1.append(["go", 201, {"tol": 1}])
	p1.append(["face", -1])
	p1.append(["fn", strike_open_fn(Vector2i(11, 68), D)])
	p1.append(["fn", strike_open_fn(Vector2i(10, 68), D)])
	p2.append(["go", 300, {"tol": 3}])
	p2.append(wait_cmd(func(_lv: LevelBase, _h: PlayerBase) -> bool: return spot_at(Vector2i(10, 68)).opened, 1500, "floor tiles"))
	elevator(p1, p2)
	# --- storey 57: the giant roast (twin strike), the flower pot ---
	p1.append(["go", 196, {"tol": 0}])
	p1.append(["face", 1])
	p2.append(["go", 236, {"tol": 0}])
	p2.append(["face", -1])
	p1.append(["sync", "roast1"])
	p2.append(["sync", "roast1"])
	p1.append(["fn", twin_fn(Vector2i(13, 57), "a", D)])
	p2.append(["fn", twin_fn(Vector2i(13, 57), "b", D)])
	# step back while the giant cake falls (P1 left, P2 right), then catch it
	p1.append(["go", 150, {"tol": 3}])
	p2.append(["go", 280, {"tol": 3}])
	p1.append(["sync", "roast1_off"])
	p2.append(["sync", "roast1_off"])
	p1.append(["wait", 40])
	p2.append(["wait", 40])
	p1.append(["go", 216, {"tol": 3}])
	p1.append(["go", 257, {"tol": 1}])
	p1.append(["face", 1])
	p1.append(["fn", strike_open_fn(Vector2i(18, 56), 0)])
	p2.append(["go", 330, {"tol": 3}])
	p2.append(["sync", "pot"])
	p1.append(["sync", "pot"])
	# the treats along the floor to the right wall, the spring by the wall onto the icing ledge (row 51)
	p1.append(["go", 459, {"tol": 3}])
	p1.append(["go", 418, {"tol": 1}])
	p1.append(["fn", hop_fn(417, 20)])
	p2.append(["go", 380, {"tol": 3}])
	# P2 follows a ledge behind: the right-wall spring onto row 51, then rows 48 and 45, up into the spiral room
	var climb: Array = [[418, 417, 20, 816, 417], [392, 317, 20, 768, 317], [291, 219, 20, 720, 219],
			[207, 207, 20, SPIRAL, 207]]
	ledges(p1, p2, "c", climb)
	# --- spiral room: P1 bounces through the candy spiral (the giant cake), both take the left spring onto the ledge ---
	p1.append(["go", 208, {"tol": 0}])
	p1.append(["keys", 20, R | U])
	p1.append(["keys", 30, L])
	p1.append(["until", func(_lv: LevelBase, h: PlayerBase) -> bool: return h.is_grounded(), 0])
	p1.append(["go", 150, {"tol": 3}])
	p2.append(["go", 40, {"tol": 3}])
	p2.append(wait_cmd(func(_lv: LevelBase, _h: PlayerBase) -> bool:
		var a: PlayerBase = hero(0)
		return a.is_grounded() and a.sim_pos.y == SPIRAL and a.sim_pos.x < 200, 900, "spiral"))
	p1.append(["sync", "spiral_done"])
	p2.append(["sync", "spiral_done"])
	# the left spring (5, 41) onto the ledge (row 36): P1 first, then P2; P2 opens the wall tile Y (1, 35)
	p1.append(["go", 125, {"tol": 2}])
	p1.append(["fn", hop_fn(99, 8)])
	p1.append(["go", 100, {"tol": 2}])
	p1.append(["sync", "ledge36"])
	p2.append(["sync", "ledge36"])
	p1.append(["fn", hop_fn(126, 8)])
	p1.append(["go", 96, {"tol": 3}])
	p2.append(["fn", hop_fn(99, 8)])
	p2.append(["go", 42, {"tol": 1}])
	p2.append(["face", -1])
	p2.append(["fn", strike_open_fn(Vector2i(1, 35), 0)])
	p2.append(["go", 100, {"tol": 2}])
	p2.append(wait_cmd(partner_clear(126, CROWN, 24), 900, "crown"))
	p2.append(["fn", hop_fn(126, 8)])
	p1.append(["sync", "crown"])
	p2.append(["sync", "crown"])
	# --- crown hall: three icing ledges up the left side, then the crown's first tier ---
	var crown: Array = [[126, 126, 20, 432, 126], [117, 114, 20, 384, 114], [114, 114, 20, 336, 114],
			[148, 188, 20, TIER, 198]]
	opts["aside_k"] = "-20"
	ledges(p1, p2, "k", crown)
	# the giant roast under the doughnut (12, 18): P1 left of it, P2 right of it, the twin strike
	p1.append(["go", 180, {"tol": 0}])
	p1.append(["face", 1])
	p2.append(["go", 210, {"tol": 0}])
	p2.append(["face", -1])
	p1.append(["sync", "roast2"])
	p2.append(["sync", "roast2"])
	p1.append(["fn", twin_fn(Vector2i(12, 18), "a", D)])
	p2.append(["fn", twin_fn(Vector2i(12, 18), "b", D)])
	p1.append(["go", 168, {"tol": 2}])
	p2.append(["go", 208, {"tol": 3}])
	p1.append(["sync", "roast2_off"])
	p2.append(["sync", "roast2_off"])
	p1.append(["wait", 30])
	p1.append(["go", 204, {"tol": 3}])
	p1.append(["go", 173, {"tol": 2}])
	# --- the top tier and the spiral staff: P1 first, P2 after him ---
	p1.append(["fn", hop_fn(231, 20)])
	p1.append(["hold", R])
	p2.append(["wait", 40])
	p2.append(["go", 173, {"tol": 2}])
	p2.append(["fn", hop_fn(231, 20)])
	p2.append(["hold", R])
	return [p1, p2]


## A climb of hops for two, P2 a hop behind: hops [start x, target x, up ticks, landing feet y, P2's target x].
func ledges(p1: Array, p2: Array, tag: String, hops: Array) -> void:
	for i: int in hops.size():
		var hp: Array = hops[i]
		p1.append(["go", int(hp[0]), {"tol": 2}])
		p1.append(["fn", hop_fn(int(hp[1]), int(hp[2]))])
		p1.append(["sync", "%s%d" % [tag, i]])
		p2.append(["sync", "%s%d" % [tag, i]])
		p2.append(wait_cmd(partner_clear(int(hp[4]), int(hp[3]), 30), 900, "%s%d" % [tag, i]))
		p2.append(["go", int(hp[0]), {"tol": 2}])
		p2.append(["fn", hop_fn(int(hp[4]), int(hp[2]))])
	var last: Array = hops[hops.size() - 1]
	p1.append(["go", int(last[1]) + int(opts.get("aside_" + tag, "-40")), {"tol": 3}])


## The icing stair from the biscuit floor to the chocolate room (P1 a hop ahead).
func stair(p1: Array, p2: Array) -> void:
	# row 77 (x 80-191, feet 1232), row 74 (192-303, 1184), row 71 (320-447, 1136), the chocolate floor (1088)
	var hops: Array = [[164, 164, 20, 1232, 164], [155, 203, 20, 1184, 210], [270, 336, 20, 1136, 340], [334, 334, 20, CHOC, 334]]
	for i: int in hops.size():
		var hp: Array = hops[i]
		p1.append(["go", int(hp[0]), {"tol": 2}])
		p1.append(["fn", hop_fn(int(hp[1]), int(hp[2]))])
		p1.append(["sync", "stair%d" % i])
		p2.append(["sync", "stair%d" % i])
		# P2 waits until P1 moved on (or is the next hop away), then the same hop
		p2.append(wait_cmd(partner_clear(int(hp[1]), int(hp[3]), 30), 900, "stair%d" % i))
		p2.append(["go", int(hp[0]) - (12 if i == 0 else 0), {"tol": 2}])
		p2.append(["fn", hop_fn(int(hp[4]), int(hp[2]))])
	# off the landing spot: P1 waits on the chocolate floor to the right
	p1.append(["go", 360, {"tol": 3}])


## Both onto the elevator (col 4) at once, ride it up to storey 57 and walk off.
func elevator(p1: Array, p2: Array) -> void:
	var la: int = int(opts.get("lift_a", "82"))
	var lb: int = int(opts.get("lift_b", "60"))
	p2.append(["go", lb, {"tol": 0}])
	p1.append(["go", la, {"tol": 0}])
	p1.append(["sync", "lift"])
	p2.append(["sync", "lift"])
	p1.append(["fn", hop_fn(la, 6)])
	p2.append(["fn", hop_fn(lb, 6)])
	for p: Array in [p1, p2]:
		p.append(["until", func(_lv: LevelBase, h: PlayerBase) -> bool: return h.sim_pos.y <= 920 and h.is_grounded(), 0])
		p.append(["sync", "lift_top"])
	p1.append(["go", 140, {"tol": 3}])
	p2.append(["go", 110, {"tol": 3}])
