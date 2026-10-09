extends "res://tools/autoplay/recorders/db1/p4/botlib.gd"
## bonus_a_coop two-stream route (DB1, protocol follow3): P1 plays the solo club route's sections; P2 waits where P1
## starts each one and replays it once P1 finished it and stepped aside (the pair climbs, leaps and lands one after the
## other on one view); the small spots are P1's, the three giant roasts are struck by both (the twin rule of GAMEPLAY.md
## 13.9.8: P1 strikes, P2 answers within the window); both ride the waffle lift together (P2 presses P1's keys) and both
## reach the spiral staff (the team exit).

const SOLO: String = "res://tools/autoplay/routes/bonus_a.inputs"


func header() -> String:
	return "# route: level=bonus_a_coop difficulty=both players=2 source=w1_l2_coop ends=warp after=tally expect=no_enemies:true,eggs:0,wipes:0,min_spots:10\n"


func build() -> Array:
	var sec: Array = route_sections(SOLO)
	for i: int in sec.size():
		print("SECTION %d (%d ticks) %s" % [i, (sec[i][1] as PackedInt32Array).size(), str(sec[i][0]).substr(0, 80)])
	var delay: int = int(opts.get("delay", "3"))
	var c1: Dictionary = {}
	var c2: Dictionary = {}
	for pair: Array in [[2, Vector2i(18, 25)], [6, Vector2i(55, 9)], [11, Vector2i(109, 25)]]:
		var both: Array = spot_section(int(pair[0]), sec[int(pair[0])][1], pair[1], D, delay)
		c1[int(pair[0])] = both[0]
		c2[int(pair[0])] = both[1]
	var mirror: Array = []
	for k: String in str(opts.get("mirror", "7")).split(",", false):
		mirror.append(int(k))
	return follow4(sec, {"p1": c1, "p2": c2, "mirror": mirror, "mirror_on": mirror})
