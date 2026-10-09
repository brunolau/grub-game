extends "res://tools/autoplay/recorders/db3/botlib.gd"
## The two-stream route of bonus_c_coop (DB3), recorded by probe_work.gd --bot --players=2. P1 runs the solo line and
## opens the spots; P2 trails him and crosses every gap, the big spring and the crumbling bridge after him, standing
## clear while P1 strikes - except at the two big spots of the giant treats, where P2 (on the far side of the spot)
## lands the last hit inside the window after P1's (a giant roast pays only for two, GAMEPLAY 13.9.8). The leader never runs more than a dozen columns ahead (the tribe camera stops paging when
## the rear hero is at its edge). Club only, no S (belt invariance).


func header() -> String:
	return "# route: level=bonus_c_coop difficulty=both players=2 source=w3_l2_coop ends=warp after=tally expect=no_enemies:true,eggs:0,wipes:0,min_spots:8\n" \
		+ "# The two-stream route of Feast Land C \"Candy Road\" in co-op (designer DB3; P1|P2, keys L R U D F K S; recorded from\n" \
		+ "# closed-loop duo macros, build/db3/bot_bonus_c_coop.gd) on both difficulties: P1 opens the spots, P2 trails him a\n" \
		+ "# few cells back - over every candy gap, the big spring (a moment after P1, so the tribe camera keeps both) and the\n" \
		+ "# crumbling biscuit bridge. At the two big spots of the giant treats P1 lands two hits and P2 the last one inside the\n" \
		+ "# window after P1's: a giant roast pays only for two (GAMEPLAY 13.9.8). Club only, never S (belt invariance).\n"


func past(slot: int, x: int) -> Callable:
	return func(_lv: LevelBase, _h: PlayerBase) -> bool:
		return hero(slot).sim_pos.x >= x


func landed_past(slot: int, x: int) -> Callable:
	return func(_lv: LevelBase, _h: PlayerBase) -> bool:
		return hero(slot).sim_pos.x >= x and hero(slot).is_grounded()


func flying_past(slot: int, x: int) -> Callable:
	return func(_lv: LevelBase, _h: PlayerBase) -> bool:
		return hero(slot).sim_pos.x >= x and not hero(slot).is_grounded()


func strikes(prog: Array, extra: int, count: int, pause: int = 4) -> void:
	for i: int in count:
		prog.append(["strike", extra])
		prog.append(["wait", pause])


func spring_land(x: int) -> Callable:
	return func(_lv: LevelBase, h: PlayerBase) -> bool:
		return h.is_grounded() and h.sim_pos.x > x


func build() -> Array:
	var p1: Array = []
	var p2: Array = []
	# --- A: the inset tile at the start
	p1.append(["go", 128, {"tol": 1}])
	strikes(p1, D, 3)
	p2.append(["wait", 8])
	p2.append(["go", 84, {"tol": 2}])
	# --- B: P1 over the first gap (ice-cream arc), the framed block, the giant cake; P2 waits before the gap
	p1.append(["run", 352])
	p1.append(["jump", 1, 16, {"air": R}])
	p1.append(["go", 472, {"tol": 1}])
	p1.append(["face", 1])
	# the giant cake's big spot pays its giant roast only for two (GAMEPLAY 13.9.8): P1 lands two hits, P2 the
	# last one inside the window after P1's second
	p1.append(["sync", "cake"])
	strikes(p1, D, 2, 6)
	p1.append(["go", 446, {"tol": 2}])
	p1.append(["wait", 20])
	p2.append(["until", past(0, 200), 0])
	p2.append(["go", 296, {"tol": 2}])
	p2.append(["until", landed_past(0, 440), 0])
	p2.append(["run", 352])
	p2.append(["jump", 1, 16, {"air": R}])
	p2.append(["go", 528, {"tol": 2}])
	p2.append(["face", -1])
	p2.append(["sync", "cake"])
	p2.append(["wait", 24])
	p2.append(["strike", D])
	# --- C: P1 moves on
	p1.append(["go", 560, {"tol": 2}])
	p2.append(["until", past(0, 540), 0])
	p2.append(["go", 690, {"tol": 2}])
	# --- D: the second gap (cupcake arc), the flower pot, its treats, back for the spring
	p1.append(["run", 720])
	p1.append(["jump", 1, 16, {"air": R}])
	p1.append(["go", 827, {"tol": 1}])
	p1.append(["face", 1])
	strikes(p1, 0, 3, 6)
	p1.append(["go", 945, {"tol": 1}])
	p1.append(["sync", "spring"])
	p2.append(["until", past(0, 900), 0])
	p2.append(["run", 720])
	p2.append(["jump", 1, 16, {"air": R}])
	p2.append(["go", 905, {"tol": 2}])
	p2.append(["sync", "spring"])
	# --- E: the big spring over the wide gap, P2 a moment after P1 (so the view keeps both)
	p1.append(["keys", 20, R | U])
	p1.append(["until", spring_land(1100), R])
	p1.append(["mark", "over the spring"])
	p1.append(["go", 1319, {"tol": 3}])
	p1.append(["face", 1])
	strikes(p1, 0, 3, 6)
	p2.append(["until", flying_past(0, 990), 0])
	p2.append(["go", 945, {"tol": 1}])
	p2.append(["keys", 20, R | U])
	p2.append(["until", spring_land(1100), R])
	p2.append(["mark", "over the spring"])
	p2.append(["go", 1262, {"tol": 5}])
	# --- F: the icing hills: the inset tiles
	p1.append(["go", 1438, {"tol": 4}])
	strikes(p1, D, 2, 6)
	p1.append(["go", 1644, {"tol": 3}])
	p1.append(["sync", "bridge"])
	p2.append(["until", past(0, 1420), 0])
	p2.append(["go", 1392, {"tol": 5}])
	p2.append(["until", past(0, 1600), 0])
	p2.append(["go", 1596, {"tol": 3}])
	p2.append(["sync", "bridge"])
	# --- G: the last gap and the crumbling biscuit bridge, the candy fountain
	p1.append(["run", 1692])
	p1.append(["jump", 1, 16, {"air": R}])
	p1.append(["run", 2300])
	p1.append(["go", 2389, {"tol": 1}])
	strikes(p1, D, 6, 6)
	p2.append(["until", past(0, 1790), 0])
	p2.append(["run", 1692])
	p2.append(["jump", 1, 16, {"air": R}])
	p2.append(["run", 2250])
	p2.append(["go", 2336, {"tol": 2}])
	# --- H: the final sprint: the strawberry line, three giant treats, the last framed block
	p1.append(["until", landed_past(1, 2300), 0])
	p1.append(["run", 3150])
	p1.append(["go", 3191, {"tol": 1}])
	p1.append(["face", 1])
	p1.append(["sync", "cake2"])
	strikes(p1, D, 2, 6)
	p1.append(["go", 3165, {"tol": 2}])
	p1.append(["wait", 20])
	p1.append(["go", 3440, {"tol": 2}])
	p1.append(["sync", "end"])
	p2.append(["until", past(0, 2460), 0])
	p2.append(["run", 3060])
	p2.append(["go", 3232, {"tol": 2}])
	p2.append(["face", -1])
	p2.append(["sync", "cake2"])
	p2.append(["wait", 24])
	p2.append(["strike", D])
	p2.append(["go", 3112, {"tol": 2}])
	p2.append(["until", past(0, 3300), 0])
	p2.append(["go", 3396, {"tol": 2}])
	p2.append(["sync", "end"])
	# --- I: the cellar's exit gap and the podium with the spiral staff
	p1.append(["run", 3474])
	p1.append(["jump", 1, 16, {"air": R}])
	p1.append(["go", 3574, {"tol": 1}])
	p1.append(["keys", 4, R])
	p1.append(["keys", 20, R | U])
	p1.append(["hold", R])
	p2.append(["until", past(0, 3570), 0])
	p2.append(["run", 3474])
	p2.append(["jump", 1, 16, {"air": R}])
	p2.append(["go", 3540, {"tol": 2}])
	p2.append(["hold", 0])
	return [p1, p2]
