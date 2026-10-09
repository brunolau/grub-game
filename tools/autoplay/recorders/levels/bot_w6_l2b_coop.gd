extends "res://tools/autoplay/recorders/bosses10/bot_w6_l2b_coop3.gd"
## levels (wf11): D6's / the bosses' w6_l2b_coop pilot with one change in the climb - P1 takes a step only while P2
## stands still (or climbs) at most 4 rows under him, so the pair never parts by more than about six rows and the leash never
## takes P2 (the rising view keeps the highest footing 72 px under its top: 6 rows of view under the leader). Before,
## P1 climbed on while P2 waited for him to land, and on the vines P2 fell 9-10 rows behind (three leash eggs on
## Beginner). Every other macro is theirs.

const NEAR_ROWS: int = 4


func climb(p1: Array, p2: Array, steps: Array) -> void:
	for step: Array in steps:
		var kind: String = step[0]
		var gate_y: int = 0
		var rise_y: int = -1
		var cmd: Array = []
		if kind == "go":
			gate_y = (int(step[2]) - 3) * 16
			cmd = ["go", int(step[1]), {"tol": 1}]
		elif kind == "ladder":
			gate_y = (int(step[1]) - 3) * 16
			rise_y = int(step[1]) * 16
			cmd = ["fn", ladder_fn(int(step[1]))]
			if step.size() > 2 and str(step[2]) == "top":
				p1.append(_wait_partner())
				p1.append(cmd)
				var top_y: int = int(step[1]) * 16
				p2.append(["until", func(lv: LevelBase, hh: PlayerBase) -> bool:
					var a: PlayerBase = hero(0)
					return a.is_grounded() and a.sim_pos.y <= top_y and a.sim_pos.x >= 230, 0])
				p2.append(cmd.duplicate())
				continue
		elif kind == "vine":
			gate_y = (int(step[2]) - 3) * 16
			cmd = ["fn", vine_fn(int(step[1]))]
		if kind != "go":
			p1.append(_wait_partner())
		p1.append(cmd)
		var gy: int = gate_y
		var ry: int = rise_y
		p2.append(["until", func(lv: LevelBase, hh: PlayerBase) -> bool:
			var a: PlayerBase = hero(0)
			var placed: bool = a.is_grounded() or a.state == Defs.HeroState.CLIMB
			if placed and a.sim_pos.y <= gy:
				return true
			return ry >= 0 and not placed and a.yvel < 0 and a.sim_pos.y < ry - 2, 0])
		p2.append(cmd.duplicate())


## P1 waits (no key; a crouch tap now and then keeps him from going idle) until P2 stands or climbs at most NEAR_ROWS
## under him - or is an egg, which follows by itself.
func _wait_partner() -> Array:
	return ["fn", func(_lv: LevelBase, hh: PlayerBase, n: int) -> int:
		var b: PlayerBase = hero(1)
		if b == null or b.down or n > 400:
			return -1
		var placed: bool = (b.is_grounded() and b.xvel == 0) or b.state == Defs.HeroState.CLIMB
		if placed and b.sim_pos.y - hh.sim_pos.y <= NEAR_ROWS * 16:
			return -1
		return 0]
