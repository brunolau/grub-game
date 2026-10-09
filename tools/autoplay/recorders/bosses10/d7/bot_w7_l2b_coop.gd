extends "res://tools/autoplay/recorders/d7/bot_w7_l1_coop.gd"
## The two-stream route of w7_l2b_coop (D7): recorded by probe_work.gd --bot --players=2 (P1 | P2).
## P1 breaks into the painting nook while P2 waits; the floes (P2 one floe behind); both up the steps and down the
## roof hole; the Tentacle Lock: P1 takes the flank left of the gap Inkjaw comes up in, P2 the right one
## (build/d7/squid_duo.gd), both strike high together, then the open head; phase 3 by the solo rule; P1 fetches the
## fire-starter and both walk to the exit totem.

const DUO = preload("res://tools/autoplay/recorders/bosses10/d7/squid_duo3.gd")
var _duo: Array = [null, null]


func header() -> String:
	var d: String = "expert" if expert else "beginner"
	var after: String = "tally" if expert else "expert_wall"
	return "# route: level=w7_l2b_coop difficulty=%s players=2 ends=exit after=%s expect=wipes:0,painting:8,unlocked:true\n" % [d, after]


func squid() -> Squid:
	for kind: int in Defs.KIND_COUNT:
		for entity: SimEntity in level.get_kind(kind):
			if entity is Squid:
				return entity as Squid
	return null


func duo_fn() -> Callable:
	return func(lv: LevelBase, h: PlayerBase, n: int) -> int:
		var sq: Squid = squid()
		if sq == null or sq.dead:
			return -1
		if _duo[h.slot] == null:
			var d: RefCounted = DUO.new()
			d.set("SURFACE_Y", 17 * 16)
			d.set("side", -1 if h.slot == 0 else 1)
			d.set("mid_x", 50 * 16)
			_duo[h.slot] = d
		return int(_duo[h.slot].call("flags", h, sq, lv))


func fetch_fn() -> Callable:
	return func(lv: LevelBase, h: PlayerBase, n: int) -> int:
		if n > 1500:
			return -1
		var key: SimEntity = null
		for entity: SimEntity in lv.get_kind(Defs.Kind.COLLECTIBLE):
			if String(entity.get("item_id")) == "items/fire_starter" or str(entity.name).contains("FireStarter"):
				key = entity
		if key == null:
			return -1
		if not bool(key.get("resting")) and h.is_grounded():
			return 0
		if absi(key.sim_pos.x - h.sim_pos.x) <= 3:
			return 0
		return int(_duo[h.slot].call("walk_to", lv, squid(), h, key.sim_pos.x))


func walk_to_fn(x: int) -> Callable:
	return func(lv: LevelBase, h: PlayerBase, n: int) -> int:
		if n > 2000 or (absi(h.sim_pos.x - x) <= 3 and h.is_grounded()):
			return -1
		return int(_duo[h.slot].call("walk_to", lv, squid(), h, x))


func build() -> Array:
	var fight: Dictionary = {"fight": true}
	var p1: Array = []
	var p2: Array = []
	p1.append(["go", cx(8) + 4, {"tol": 2}])
	p1.append(["face", -1])
	p1.append(["fn", open_fn(Vector2i(7, 13))])
	p1.append(["fn", open_fn(Vector2i(7, 12), U)])
	p1.append(["run", cx(4), {}])
	p1.append(["wait", 4])
	p1.append(["run", cx(11), {}])
	p1.append(["sync", "nook"])
	p2.append(["go", cx(13), {"tol": 2}])
	p2.append(["sync", "nook"])
	floes2(p1, p2, "floes", 14 * 16, [16, 20, 24, 28], cx(32))
	for slot: int in 2:
		var p: Array = p1 if slot == 0 else p2
		p.append(["go", cx(33) - slot * 18, fight])
		p.append(["fn", wait_fight_fn(no_foe_near(70))])
		p.append(["fn", hop_fn(cx(35) - slot * 14, 10)])
		p.append(["fn", wait_fight_fn(no_foe_near(56))])
		p.append(["fn", hop_fn(cx(38) - slot * 14, 10)])
		p.append(["fn", wait_fight_fn(no_foe_near(56))])
		p.append(["sync", "roof"])
		if slot == 1:
			p.append(["wait", 20])
		p.append(["run", cx(42), {}])
		p.append(["until", func(lv: LevelBase, h: PlayerBase) -> bool: return h.is_grounded() and h.sim_pos.y >= 17 * 16, 0])
		p.append(["mark", "inkjaw"])
		p.append(["fn", duo_fn()])
	# both over the root ledges to the right island (phase 3's rafts lie still once it is beaten), P2 30 ticks later
	p1.append(["wait", 30])
	# not with the partner on his head (he steps off first)
	p1.append(["until", func(lv: LevelBase, h: PlayerBase) -> bool:
		var b: PlayerBase = hero(1)
		return not b.is_riding_totem() and (b.is_grounded() or b.dead or b.down), 0])
	p1.append(["wait", 10])
	p1.append(["fn", ledges_cross_fn()])
	p1.append(["fn", fetch_fn()])
	p1.append(["fn", walk_to_fn(cx(56))])
	p2.append(["fn", func(lv: LevelBase, h: PlayerBase, n: int) -> int:
		# off the partner's head (the fight may end with him standing on it)
		if n > 120 or (not h.is_riding_totem() and h.is_grounded() and n > 2):
			return -1
		return L if h.is_riding_totem() or not h.is_grounded() else 0])
	p2.append(["wait", 60])
	p2.append(["fn", ledges_cross_fn()])
	p2.append(["fn", walk_to_fn(cx(55))])
	p1.append(["hold", R])
	p2.append(["hold", R])
	return [p1, p2]
