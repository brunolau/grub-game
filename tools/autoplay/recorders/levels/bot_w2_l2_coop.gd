extends "res://tools/autoplay/recorders/enemies_a10/bot_w2_l2_coop_ea.gd"
## levels (wf11): DB2's / enemies-A's w2_l2_coop bot with one change - on the glowing cap the hero stays over the pad
## until his feet are above the bone shelf's top (y 224) and only then steers onto it. Since the spring is a launch
## (DESIGN G71: 105 px over the pad, no jump on top of it) a launch from the pad's right half that steered at once
## came under the shelf's corner and bumped its head. Every other macro is theirs.

const SHELF_TOP: int = 224


func spring_fn(sx: int, tx: int) -> Callable:
	return func(_lv: LevelBase, h: PlayerBase, n: int) -> int:
		var st: Dictionary = _st[h.slot]
		if n == 0:
			st["y0"] = h.sim_pos.y
		if not bool(st.get("up", false)):
			if h.yvel < -150 and not h.is_grounded() and n > 3:
				st["up"] = true
			else:
				if n > 120:
					return -1
				var k: int = 0
				var dx0: int = sx - h.sim_pos.x
				if dx0 > 2:
					k = R
				elif dx0 < -2:
					k = L
				if n < 4:
					k |= U
				return k
		if h.is_grounded() and h.sim_pos.y < int(st["y0"]) - 8:
			return -1
		if n > 400:
			return -1
		# Below the shelf's top: keep over the pad's left half (the shelf's corner is at x 752).
		var goal: int = tx if h.sim_pos.y < SHELF_TOP - 2 else sx - 4
		var dx: int = goal - h.sim_pos.x
		if dx > 3:
			return R
		if dx < -3:
			return L
		return 0
