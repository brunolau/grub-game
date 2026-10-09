extends "res://tools/autoplay/recorders/db3/bot_w3_l2_coop.gd"
## The two-stream route of w4_l2_coop (DB3; Expert only), recorded by probe_work.gd --bot --players=2. Both heroes
## cross the ash road and the gatehouse together (the loners keep away from a pair); in the great hall P1 holds plate
## pa while P2 walks the lower corridor to plate pb, then P1 climbs the slabs into the upper corridor; both climb the
## column staircase one column apart; on the rampart P1 stands by the keep tower and P2 Shoulder-Hops onto it for
## Cave Painting 28; P1 at drum B, P2 at drum A strike on the count of three; through the portcullis to the exit.


func header() -> String:
	return "# route: level=w4_l2_coop difficulty=expert players=2 ends=exit after=level:w4_l2b_coop expect=eggs:0,wipes:0,x2_gates:2,painting:28,min_checkpoints:3\n" \
		+ "# The Expert two-stream route of Obsidian Keep in co-op (designer DB3; P1|P2, keys L R U D F K S; recorded from\n" \
		+ "# closed-loop duo macros, build/db3/bot_w4_l2_coop.gd). Both cross the lava pits and the gatehouse column one\n" \
		+ "# after the other; in the great hall P1 holds plate pa under the slabs while P2 walks the lower corridor to plate\n" \
		+ "# pb behind the wall, then P1 climbs the slabs through the upper corridor (gate 'plates'); both climb the column\n" \
		+ "# staircase one column apart, waiting out each column's quake; on the rampart P2 Shoulder-Hops off P1's head onto\n" \
		+ "# the keep tower for Cave Painting 28; P1 waits at drum B by the tower while P2 jumps the spike well and climbs\n" \
		+ "# onto the drum ledge: both strike on the count of three and the portcullis rises for good (gate 'drums'); both\n" \
		+ "# reach the exit (the team exit). Club only, no S; nobody stands 243 ticks without input.\n"


## Raw keys of a run-length text ("4:R,15:,14:RU") as one command list entry per run.
func raw(prog: Array, text: String) -> void:
	for entry: String in text.split(",", false):
		var parts: PackedStringArray = entry.split(":")
		var k: int = 0
		for ch: String in parts[1]:
			match ch:
				"L": k |= L
				"R": k |= R
				"U": k |= U
				"D": k |= D
				"F": k |= F
		prog.append(["keys", int(parts[0]), k])


func build() -> Array:
	var fight: Dictionary = {"fight": true}
	var p1: Array = []
	var p2: Array = []
	# === The ash road: over the hill; the two lava pits one hero after the other (the solo's jumps) ===========
	p1.append(["go", 306, {"tol": 1}])
	p1.append(["sync", "pits"])
	raw(p1, "14:R,8:RU,6:R,12:,10:RU,10:R,13:")
	p1.append(["go", 560, {"tol": 3, "fight": true}])
	p1.append(["sync", "pits_done"])
	p2.append(["go", 262, {"tol": 2}])
	p2.append(["sync", "pits"])
	p2.append(["until", grounded_past(0, 520), 0])
	p2.append(["go", 306, {"tol": 1}])
	raw(p2, "14:R,8:RU,6:R,12:,10:RU,10:R,13:")
	p2.append(["go", 532, {"tol": 3, "fight": true}])
	p2.append(["sync", "pits_done"])
	# === The gatehouse: the column rises out of the spike pit; onto it and off its far side, one after the other ==
	p1.append(["go", 787, {"tol": 2}])
	p1.append(["until", func(lv: LevelBase, _h: PlayerBase) -> bool: return lv.get_cell(53, 38) != TileGrid.CH_AIR, 0])
	p1.append(["sync", "gatehouse"])
	p1.append(["wait", 6])
	p1.append(["leap", 864, 10, {"lead": 2}])
	p1.append(["go", 868, {"tol": 3}])
	p1.append(["leap", 944, 10, {"lead": 2}])
	p1.append(["go", 940, {"tol": 2}])
	p2.append(["go", 740, {"tol": 3}])
	p2.append(["sync", "gatehouse"])
	p2.append(["until", grounded_past(0, 900), 0])
	p2.append(["go", 787, {"tol": 2}])
	p2.append(["leap", 864, 10, {"lead": 2}])
	p2.append(["go", 868, {"tol": 3}])
	p2.append(["leap", 944, 10, {"lead": 2}])
	# === Gate "plates": over the spike strip; P1 holds pa (under the slabs), P2 walks the lower corridor to pb behind
	# the wall; then P1 climbs the slabs into the upper corridor (its door open while P2 holds pb) =================
	p1.append(["go", 1000, {"tol": 2}])
	p1.append(["leap", 1080, 12, {"lead": 2}])
	# off the slab over the plate (the leap lands on it) and back under it, onto pa
	p1.append(["until", func(_lv: LevelBase, h: PlayerBase) -> bool: return h.is_grounded() and h.sim_pos.y >= 600, R])
	p1.append(["go", 1080, {"tol": 2}])
	p1.append(["mark", "on pa"])
	p1.append(["until", func(lv: LevelBase, _h: PlayerBase) -> bool: return lv.get_cell(71, 31) == TileGrid.CH_AIR 			and hero(1).is_grounded() and hero(1).sim_pos.x >= 1296, 0])
	p2.append(["until", func(lv: LevelBase, _h: PlayerBase) -> bool: return lv.get_cell(78, 37) == TileGrid.CH_AIR, 0])
	p2.append(["go", 1000, {"tol": 2}])
	p2.append(["leap", 1112, 12, {"lead": 2}])
	p2.append(["until", func(_lv: LevelBase, h: PlayerBase) -> bool: return h.is_grounded() and h.sim_pos.y >= 600, R])
	p2.append(["go", 1304, {"tol": 2}])
	p2.append(["mark", "on pb"])
	p2.append(["until", func(_lv: LevelBase, _h: PlayerBase) -> bool: return hero(0).sim_pos.x >= 1180 and hero(0).sim_pos.y <= 512, 0])
	p2.append(["wait", 6])
	# P1: straight up onto the slab over pa, onto the upper slab, through door D2 and along the corridor
	p1.append(["jump", 0, 10, {"air": 0}])
	p1.append(["leap", 1104, 12, {"lead": 2}])
	p1.append(["go", 1240, {"tol": 3}])
	p1.append(["mark", "through the upper corridor"])
	p1.append(["go", 1300, {"tol": 3}])
	p1.append(["go", 1420, {"tol": 3}])
	p2.append(["go", 1380, {"tol": 3}])
	p1.append(["sync", "stairs"])
	p2.append(["sync", "stairs"])
	# === The column staircase over the spike floor: each column rises once when a hero stands before it (the one
	# before it); P1 leaps from column to column as each one tops out, P2 one column behind =======================
	# [centre x, the top cell once risen, the x to jump on from (by its right edge)]
	var cols: Array = [[1536, Vector2i(94, 36), 1556], [1624, Vector2i(100, 33), 1638], [1704, Vector2i(105, 30), 1718],
		[1784, Vector2i(110, 27), 1798]]
	p1.append(["go", 1440, {"tol": 2}])
	for i: int in cols.size():
		var cell: Vector2i = cols[i][1]
		p1.append(["until", func(lv: LevelBase, _h: PlayerBase) -> bool: return lv.get_cell(cell.x, cell.y) != TileGrid.CH_AIR, 0])
		p1.append(["wait", 4])
		if i > 0:
			p1.append(["go", int(cols[i - 1][2]), {"tol": 2}])
		p1.append(["leap", int(cols[i][0]), 14, {"lead": 3, "delay": 0 if i == 0 else 4}])
		p1.append(["go", int(cols[i][0]), {"tol": 4}])
		p1.append(["sync", "col%d" % i])
		p2.append(["sync", "col%d" % i])
		if i == 0:
			p2.append(["go", 1440, {"tol": 2}])
		else:
			# P1 on column i set column i + 1 rising: its quake lifts every hero off his feet (no jump) until it tops out
			if i + 1 < cols.size():
				var next_cell: Vector2i = cols[i + 1][1]
				p2.append(["until", func(lv: LevelBase, h: PlayerBase) -> bool: return lv.get_cell(next_cell.x, next_cell.y) != TileGrid.CH_AIR and h.is_grounded(), 0])
				p2.append(["wait", 4])
			if i > 1:
				p2.append(["go", int(cols[i - 2][2]), {"tol": 2}])
			p2.append(["leap", int(cols[i - 1][0]), 14, {"lead": 3, "delay": 0 if i == 1 else 4}])
			p2.append(["go", int(cols[i - 1][0]), {"tol": 4}])
	p1.append(["go", 1860, {"tol": 3}])
	p1.append(["sync", "ledge"])
	p2.append(["sync", "ledge"])
	p2.append(["go", int(cols[2][2]), {"tol": 2}])
	p2.append(["leap", int(cols[3][0]), 14, {"lead": 3, "delay": 4}])
	p2.append(["go", 1830, {"tol": 3}])
	# === The rampart: P1 under the keep tower's east side, P2 hops onto it for Cave Painting 28 =================
	p1.append(["go", 2262, {"tol": 2}])
	p1.append(["face", -1])
	p1.append(["sync", "tower"])
	p2.append(["go", 2290, {"tol": 2}])
	p2.append(["face", -1])
	p2.append(["sync", "tower"])
	p2.append(["wait", 4])
	p2.append(["fn", hop_fn(-1, 308)])
	p2.append(["mark", "on the keep tower"])
	p2.append(["go", 2216, {"tol": 3}])
	p2.append(["mark", "painting"])
	p2.append(["sync", "painted"])
	# === Gate "drums": P1 at drum B by the keep tower (right of it, facing it); P2 off the tower, over the spike well
	# and up onto the drum ledge by the portcullis (drum A); both strike on the count of three ==================
	p1.append(["sync", "painted"])
	p1.append(["go", 2290, {"tol": 1}])
	p1.append(["face", -1])
	p1.append(["sync", "drums"])
	p1.append(["wait", 2])
	p1.append(["strike", 0])
	p2.append(["go", 2252, {"tol": 3}])
	p2.append(["until", func(_lv: LevelBase, h: PlayerBase) -> bool: return h.is_grounded() and h.sim_pos.y >= 430, R])
	p2.append(["go", 2200, {"tol": 3}])
	p2.append(["run", 2260])
	p2.append(["jump", 1, 10, {"air": R}])
	p2.append(["go", 2428, {"tol": 2}])
	p2.append(["leap", 2466, 16, {"lead": 2, "delay": 7}])
	p2.append(["go", 2462, {"tol": 2}])
	p2.append(["face", 1])
	p2.append(["sync", "drums"])
	p2.append(["wait", 2])
	p2.append(["strike", 0])
	# the portcullis rises: P2 drops off the ledge, P1 jumps the well; both through the gate
	p1.append(["until", func(lv: LevelBase, _h: PlayerBase) -> bool: return lv.get_cell(156, 26) == TileGrid.CH_AIR, 0])
	p1.append(["go", 2200, {"tol": 3}])
	p1.append(["run", 2260])
	p1.append(["jump", 1, 10, {"air": R}])
	p1.append(["go", 2500, {"tol": 3}])
	p1.append(["sync", "gate_up"])
	p2.append(["until", func(lv: LevelBase, _h: PlayerBase) -> bool: return lv.get_cell(156, 26) == TileGrid.CH_AIR, 0])
	p2.append(["until", func(_lv: LevelBase, h: PlayerBase) -> bool: return h.is_grounded() and h.sim_pos.y >= 430, L])
	p2.append(["go", 2440, {"tol": 3}])
	p2.append(["sync", "gate_up"])
	# === Through the portcullis, over the hill, past the guarded turtle to the exit (both, together) ===========
	p1.append(["go", 2600, fight.merged({"tol": 3})])
	p1.append(["sync", "hill"])
	p1.append(["run", 2856, fight])
	p1.append(["jump", 1, 12, {"air": R}])
	p1.append(["hold", R])
	p2.append(["go", 2570, fight.merged({"tol": 3})])
	p2.append(["sync", "hill"])
	p2.append(["wait", 8])
	p2.append(["run", 2856, fight])
	p2.append(["jump", 1, 12, {"air": R}])
	p2.append(["hold", R])
	return [p1, p2]
