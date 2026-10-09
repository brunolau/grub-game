extends "res://tools/autoplay/recorders/d9a/botlib.gd"
## The Expert club route of w9_l2 The Roc's Spire (D9a), recorded by probe_work.gd --bot. Every gust gap is jumped in
## a lull with ticks to spare; the hero crouches through the gusts.

const LULL: int = 110


func header() -> String:
	return "# route: level=w9_l2 difficulty=expert ends=exit after=level:w9_l2b expect=max_hurts:3,deaths:0,min_checkpoints:5,painting:14\n" \
		+ "# The Expert club route of The Roc's Spire (designer D9; recorded from closed-loop macros, build/d9a): every gust\n" \
		+ "# gap jumped in a lull (the hero crouches through the gusts), the drop clouds over the tar lake with a crouch on\n" \
		+ "# the slate stack, the tar pockets and the Guards of the terraces, the Roller valley and the cloud bridge, the Cave\n" \
		+ "# Painting (index 14) out of the big spot in the cloud over the path, the cloud hall and the final drop clouds.\n"


func gust_gap(p: Array, edge_col: int, land_col: int, need: int = 40) -> void:
	p.append(["trek", cx(edge_col) - 10])
	p.append(["go", cx(edge_col) + 1, {"fight": true, "tol": 2}])
	p.append(["lull", need, LULL])
	p.append(["hop", cx(land_col), 9])


func build() -> Array:
	opts["lull_fight"] = true
	var p: Array = []
	# A: two gust gaps, the Guard between them, checkpoint 1
	gust_gap(p, 13, 18)
	p.append(["guard", 1, 200])
	gust_gap(p, 28, 33)
	p.append(["trek", cx(43)])
	# B: the tar lake: two drop clouds, the slate stack, two drop clouds, the bank
	p.append(["trek", cx(46) - 10])
	p.append(["go", cx(46) + 1, {"fight": true, "tol": 2}])
	p.append(["lull", 70, LULL])
	p.append(["hop", cx(50), 9])
	p.append(["hop", cx(55), 9])
	p.append(["hop", cx(61), 9])
	p.append(["lull", 70, LULL])
	p.append(["hop", cx(67), 9])
	p.append(["hop", cx(72), 9])
	p.append(["hop", cx(78), 9])
	# C: the tar pocket, the lower terrace and its pocket, the upper terrace, checkpoint 3
	p.append(["trek", cx(92)])
	p.append(["hop", cx(93) + 4, 4])
	p.append(["hop", cx(97), 9])
	p.append(["guard", 1, 200])
	p.append(["trek", cx(108) + 4])
	p.append(["hop", cx(115), 9])
	p.append(["trek", cx(117)])
	p.append(["hop", cx(121), 9])
	p.append(["guard", 1, 200])
	p.append(["trek", cx(128)])
	# D: the Roller valley, the cloud bridge between two gust gaps, checkpoint 4
	gust_gap(p, 154, 159)
	p.append(["go", cx(163), {"fight": true, "tol": 2}])
	p.append(["lull", 40, LULL])
	p.append(["hop", cx(168), 9])
	p.append(["trek", cx(171)])
	p.append(["guard", 1, 200])
	# E: the last gust gap, the painting's big spot, the hall, the final drop clouds
	gust_gap(p, 178, 183)
	p.append(["go", cx(186), {"fight": true, "tol": 1}])
	for i: int in 3:
		p.append(["keys", 8, U | F])
		p.append(["wait", 16])
	p.append(["wait", 50])
	p.append(["go", cx(182), {"tol": 2}])
	p.append(["hop", cx(185), 9])
	p.append(["go", cx(188), {"tol": 2}])
	p.append(["go", cx(191), {}])
	p.append(["trek", cx(206) - 10])
	p.append(["go", cx(206) + 1, {"fight": true, "tol": 2}])
	p.append(["lull", 70, LULL])
	p.append(["hop", cx(209), 9])
	p.append(["hop", cx(213), 9])
	p.append(["hop", cx(217), 9])
	p.append(["trek", cx(228)])
	p.append(["hold", R])
	return [p]
