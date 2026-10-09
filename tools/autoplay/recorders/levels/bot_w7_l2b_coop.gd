extends "res://tools/autoplay/recorders/bosses10/d7/bot_w7_l2b_coop.gd"
## levels (wf11): D7's / the bosses' w7_l2b_coop pilot with two changes on the floes, for a margin under the Expert
## route's max_hurts:6 (the old recording took three hurts on the way in and three in the fight):
##  - P1 strikes high as he hops under the Expert dangler (26,4) to cut its thread (DESIGN D.6) - in the recorded run
##    this did NOT spare P2, who still meets the dangler one floe behind (one of the route's two hurts);
##  - the hop ashore: over the lone tortoise that comes down the steps he strikes low (it fell to nobody, and both
##    heroes landed on it and then beside it).
## Every other macro is theirs. `--nocut` / `--nolow` switch a change off; `--lowdy=<px>` how far over the foe.


func hop2_fn(tx: int, up: int) -> Callable:
	return func(lv: LevelBase, h: PlayerBase, n: int) -> int:
		var st: Dictionary = _st[h.slot]
		if not bool(st.get("go", false)):
			if h.is_grounded() and h.no_jump == 0 and not h.is_striking():
				st["go"] = true
				st["t"] = 0
			else:
				return 0
		var k: int = int(st["t"])
		st["t"] = k + 1
		var dx: int = tx - h.sim_pos.x
		var keys: int = 0
		if dx > 3:
			keys = R
		elif dx < -3:
			keys = L
		if k < up:
			return U | keys
		if k > 2 and h.is_grounded():
			return -1
		if k > 120:
			return -1
		if not h.is_striking():
			for entity: SimEntity in lv.get_kind(Defs.Kind.ENEMY):
				var foe: EnemyBase = entity as EnemyBase
				if foe == null or foe.dead or not foe.awake or not foe.tangible:
					continue
				var ahead: int = foe.sim_pos.x - h.sim_pos.x
				var below: int = foe.sim_pos.y - h.sim_pos.y
				if foe is Dangler and not opts.has("nocut") and ahead > -6 and ahead < int(opts.get("cutdx", "26")) \
						and below < -30:
					return U | F | keys
				if not (foe is Dangler) and not opts.has("nolow") and absi(ahead) < int(opts.get("lowdx", "22")) \
						and below > 4 and below < int(opts.get("lowdy", "50")):
					return D | F | keys
		return keys


func floes2(p1: Array, p2: Array, tag: String, edge_x: int, centres: Array, land_x: int, last_up: int = 7,
		p2_land_off: int = 24) -> void:
	var fight: Dictionary = {"fight": true}
	p1.append(["go", edge_x - 2, fight])
	p1.append(["fn", wait_fight_fn(no_foe_near(90))])
	p1.append(["sync", tag])
	p2.append(["go", edge_x - 24, fight])
	p2.append(["sync", tag])
	var all: Array = centres.duplicate()
	all.append(-1)
	for i: int in all.size():
		var last: bool = int(all[i]) < 0
		var tx: int = land_x if last else cx(int(all[i]))
		p1.append(["fn", hop2_fn(tx + 6, last_up if last else 7)])
		var ahead: int = land_x - 4 if last else cx(int(all[i])) + 30
		p2.append(["until", partner_beyond(ahead), 0])
		p2.append(["fn", hop2_fn(land_x - p2_land_off if last else tx - 6, last_up if last else 7)])
