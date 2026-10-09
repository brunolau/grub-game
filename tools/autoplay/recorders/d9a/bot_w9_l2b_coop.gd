extends "res://tools/autoplay/recorders/d9a/bot_w9_l2b.gd"
## The two-stream Expert route of w9_l2b_coop Storm Nest (D9a), recorded by probe_work.gd --bot --players=2: the
## approach (P1 opens the painting hollow, P2 follows), the drop into the arena, and the co-op Storm Roc (DESIGN B.5):
##  - perched: P1 high-strikes the head band from the nest (62 px inward, the solo spot) while P2 stands on the floor
##    20 px outward of its feet: P2 is the nearer active hero, the wing shield turns to him, P1's hits count (a pincer);
##  - circling and diving: both dodge each dive (it buries its beak) and both strike the buried beak;
##  - the storm: P1 flies the glider dives onto its back (the solo pilot); P2 is the spotter on the nest, dodging the
##    bolts, and strikes the tail feathers of the tumbling Roc within its 24 ticks - only then a dive counts;
##  - the fire-starter (P1), the exit totem (both).


var _pilots: Array = [null, null]


func header() -> String:
	return "# route: level=w9_l2b_coop difficulty=expert players=2 ends=exit after=tally expect=wipes:0,min_checkpoints:1,painting:15,unlocked:true\n" \
		+ "# The two-stream Expert route of Storm Nest in co-op (designer D9a; recorded from closed-loop macros,\n" \
		+ "# build/d9a/bot_w9_l2b_coop.gd, P1|P2): the painting hollow (P1), the drop into the arena; the co-op Storm Roc:\n" \
		+ "# perched, P2 stands under its outer wing (the shield turns to him) while P1 high-strikes the head from the nest;\n" \
		+ "# both dodge its dives and strike the buried beak; in the storm P1 glides onto its back and P2 strikes the\n" \
		+ "# tumbling Roc's tail from the nest (Pilot and Spotter), three times; the fire-starter, the exit totem.\n"


func pilot(slot: int) -> RefCounted:
	if _pilots[slot] == null:
		_pilots[slot] = (load("res://tools/autoplay/recorders/d9a/roc_pilot.gd") as GDScript).new(AX * 16, AY * 16)
	return _pilots[slot]


func _rescue(h: PlayerBase, boss: Roc) -> int:
	## The partner hangs from the snatching Roc: under its head band and a high strike while it is in reach.
	var st: Dictionary = _st[h.slot]
	if int(st.get("hold", 0)) > 0:
		st["hold"] = int(st["hold"]) - 1
		return int(st.get("hold_keys", 0)) if int(st["hold"]) > 2 else 0
	if not h.is_grounded():
		return 0
	var band: Rect2i = boss.get_head_rect()
	if not band.has_area():
		return 0
	var face: int = 1 if band.get_center().x >= h.sim_pos.x else -1
	var box: Rect2i = Rect2i(h.sim_pos.x + (10 if face > 0 else -26), h.sim_pos.y - 43, 16, 16)
	if Overlap.rects(box, band) and boss.hit_cooldown == 0:
		if h.facing != face:
			return _key(face)
		st["hold"] = 8
		st["hold_keys"] = U | F
		return U | F
	# under the band's near edge, on the nest if he can get there
	var goal: int = clampi(h.sim_pos.x, band.position.x - 20, band.end.x + 20)
	if absi(goal - h.sim_pos.x) > 3:
		return _key(1 if goal > h.sim_pos.x else -1)
	return D


func coop_fn(slot: int) -> Callable:
	return func(lv: LevelBase, h: PlayerBase, n: int) -> int:
		var boss: Roc = roc()
		if boss == null or boss.dead or n > 12000:
			return -1
		if boss.get_state() == Roc.State.SNATCH and boss.get_held() != null and boss.get_held() != h:
			return _rescue(h, boss)
		var pl: RefCounted = pilot(slot)
		if slot == 1 and opts.has("gdbg") and h.run.has_glider != bool(_st[1].get("had_glider", false)):
			_st[1]["had_glider"] = h.run.has_glider
			print("GLIDER t=%d P2 has_glider=%s pos=%s roc_state=%d storm=%s note=%s" % [t, str(h.run.has_glider),
				h.sim_pos, boss.get_state(), str(boss.is_storm_phase()), str(pl.get(&"note"))])
		var k: int = int(pl.call(&"flags", h, boss, lv)) if slot == 0 else _partner(lv, h, boss, pl, n)
		if opts.has("dbg") and (t % 25 == 0 or (opts.has("dbg1") and slot == 1)) and t >= int(opts["dbg"]) 				and t <= int(opts.get("dbg_to", "999999")):
			if slot == 1:
				print("DBG2 t=%d tail=%s face=%d striking=%s cool=%d pend=%s" % [t, boss.get_head_rect(), h.facing,
					str(h.is_striking()), boss.hit_cooldown, str(boss._dive_pending)])
			print("DBG t=%d P%d st%d note=%s pos=%s glider=%s glide=%d runup=%d roc=%s half=%d k=%d" % [t, slot + 1,
				boss.get_state(), str(pl.get(&"note")), h.sim_pos, str(h.run.has_glider), int(h.get(&"glide")),
				int(h.get(&"glider_runup")), boss.sim_pos, boss._cruise_half, k])
		return k


## P2: the bait while it perches, the solo dodger in the dives, the spotter in the storm.
func _partner(lv: LevelBase, h: PlayerBase, boss: Roc, pl: RefCounted, n: int) -> int:
	var st: Dictionary = _st[h.slot]
	if int(st.get("hold", 0)) > 0:
		st["hold"] = int(st["hold"]) - 1
		return int(st.get("hold_keys", 0)) if int(st["hold"]) > 2 else 0
	var state: int = boss.get_state()
	if state == Roc.State.DYING:
		return 0
	if h.hit_timer >= Tuning.HIT_STUN_MIN:
		return 0
	if boss.is_storm_phase():
		return _spotter(lv, h, boss, pl, st, n)
	if state == Roc.State.REST or state == Roc.State.WINGS or state == Roc.State.GUST:
		return _bait(lv, h, boss, pl, n)
	return int(pl.call(&"flags", h, boss, lv))


## Perched: on the floor 20 px outward of its feet (under the outer wing tip: the body is over a standing hero's head).
func _bait(_lv: LevelBase, h: PlayerBase, boss: Roc, pl: RefCounted, n: int) -> int:
	var mid: int = int(pl.get(&"MID_X"))
	var floor_y: int = int(pl.get(&"FLOOR_Y"))
	var rx: int = boss.sim_pos.x
	var outward: int = 1 if rx >= mid else -1
	var spot: int = rx + outward * 20
	if not h.is_grounded():
		return 0
	if h.sim_pos.y < floor_y:
		# on the nest: off its inward end (never through the perched body), the floor walk does the rest
		var inner_end: int = int(pl.get(&"NEST_X0")) - 24 if outward > 0 else int(pl.get(&"NEST_X1")) + 24
		return _key(1 if inner_end > h.sim_pos.x else -1)
	var move: int = int(pl.call(&"_floor_walk", h, spot, boss))
	if absi(h.sim_pos.x - spot) > 3:
		return move
	# in place: crouched under the wing tip (a standing hero there touches the body)
	return D


## The storm: the spotter waits on the floor under the nest's end opposite the half the Roc cruises over - after a
## dive it tumbles over the nest's middle with its tail on that side (cruising left it tumbles tail right). There he is
## clear of the two gliders at the middle +-24 px (a hero carrying one cannot strike; he crawls past them, too low to
## pick one up) and of the bolts (the floor under a struck nest is sheltered). When it tumbles he jumps straight up,
## strikes the tail from the nest's end and walks off it again.
func _spotter(lv: LevelBase, h: PlayerBase, boss: Roc, pl: RefCounted, st: Dictionary, n: int) -> int:
	var state: int = boss.get_state()
	var nest_y: int = int(pl.get(&"NEST_TOP"))
	var x0: int = int(pl.get(&"NEST_X0"))
	var x1: int = int(pl.get(&"NEST_X1"))
	var center: int = boss.get_nest_center().x
	var on_nest: bool = h.sim_pos.y <= nest_y + 1
	var tail: Rect2i = boss.get_head_rect() if state == Roc.State.TUMBLE else Rect2i()
	if not h.is_grounded():
		# rising past the tail: strike as soon as the forward club box meets it
		if tail.has_area() and not h.is_striking() and not h.attack_gate and boss.hit_cooldown == 0:
			var f: int = 1 if tail.get_center().x > h.sim_pos.x else -1
			var box: Rect2i = Rect2i(h.sim_pos.x + (11 if f > 0 else -35), h.sim_pos.y - 15, 24, 13)
			if Overlap.rects(box, tail):
				st["hold"] = 6
				st["hold_keys"] = F | _key(f)
				return F | _key(f)
		return 0
	if tail.has_area() and on_nest:
		var face: int = 1 if tail.get_center().x > h.sim_pos.x else -1
		if h.facing != face:
			return _key(face)
		if not h.is_striking() and boss.hit_cooldown == 0 and not h.attack_gate:
			st["hold"] = 7
			st["hold_keys"] = F
			return F
		return 0
	if on_nest:
		# off the nest's nearer end (a one-way nest has no drop-through)
		var off: int = (x0 - 14) if h.sim_pos.x < center else (x1 + 14)
		return _key(1 if off > h.sim_pos.x else -1)
	var spot: int = (x1 - 4) if boss._cruise_half == 0 else (x0 + 4)
	if tail.has_area():
		spot = (x1 - 4) if tail.get_center().x > center else (x0 + 4)
	if absi(h.sim_pos.x - spot) > 3:
		return _crawl_to(lv, h, spot)
	if tail.has_area():
		if h.no_jump != 0:
			return 0
		# a short hop (Up held 6 ticks): it clears the nest's 2 rows and lands soon
		st["hold"] = 7
		st["hold_keys"] = U
		var face2: int = 1 if tail.get_center().x > h.sim_pos.x else -1
		if h.facing != face2:
			return _key(face2)
		return U
	return D if n % 50 < 3 else 0


## Along the floor to x, crawling where a glider lies on the nest above (a standing hero there picks it up).
func _crawl_to(lv: LevelBase, h: PlayerBase, x: int) -> int:
	var dir: int = 1 if x > h.sim_pos.x else -1
	for entity: SimEntity in lv.get_kind(Defs.Kind.COLLECTIBLE):
		var item: CollectibleBase = entity as CollectibleBase
		if item != null and item.item_id == &"items/glider" and not item.collected 				and absi(item.sim_pos.x - (h.sim_pos.x + dir * 6)) < 28:
			return D | _key(dir)
	return _key(dir)


func build() -> Array:
	var f: Dictionary = {"fight": true}
	var p1: Array = []
	var p2: Array = []
	# --- the approach: P1 the solo way (the painting hollow); P2 waits on the cloud tuft and follows over the hole
	p1.append(["go", cx(3), f])
	p1.append(["hop", cx(7), 9])
	p1.append(["go", cx(10), f])
	p1.append(["face", 1])
	p1.append(["keys", 8, D | F])
	p1.append(["wait", 6])
	p1.append(["keys", 8, D | F])
	p1.append(["wait", 6])
	p1.append(["go", cx(11), {"tol": 1, "max": 80}])
	p1.append(["until", func(_l: LevelBase, hh: PlayerBase) -> bool: return hh.is_grounded() and hh.sim_pos.y >= (AY + 3) * 16, 0])
	p1.append(["go", cx(15), {}])
	p1.append(["go", cx(11) + 2, {}])
	p1.append(["hop", cx(9), 9, {"lead": 2}])
	p1.append(["go", cx(9), {}])
	p1.append(["hop", cx(14), 9, {"lead": 2}])
	p1.append(["go", cx(16), f])
	p1.append(["clear", 140, 200])
	p1.append(["hop", cx(19), 9])
	p1.append(["hop", cx(23), 9])
	p1.append(["go", cx(26), f])
	p1.append(["sync", "drop"])
	p2.append(["wait", 20])
	p2.append(["go", cx(3), f])
	p2.append(["hop", cx(7), 9])
	p2.append(["go", cx(8), f])
	p2.append(wait_until(partner_past(cx(16))))
	p2.append(["go", cx(9), {}])
	p2.append(["hop", cx(14), 9, {"lead": 2}])
	p2.append(["go", cx(16), f])
	p2.append(["clear", 140, 200])
	p2.append(["hop", cx(19), 9])
	p2.append(["hop", cx(23), 9])
	p2.append(["go", cx(25), f])
	p2.append(["sync", "drop"])
	# --- the drop into the arena (P1 first; P2 a moment later), the fight
	for slot: int in 2:
		var p: Array = p1 if slot == 0 else p2
		if slot == 1:
			p.append(["wait", 12])
		p.append(["run", cx(31)])
		p.append(["until", func(_l: LevelBase, hh: PlayerBase) -> bool: return hh.is_grounded(), R])
		p.append(["fn", coop_fn(slot)])
		p.append(["wait", 110 if slot == 0 else 120])
	# --- the fire-starter (P1), then both to the exit totem, stepping over a skull of the bonus burst
	p1.append(["fn", func(lv: LevelBase, h: PlayerBase, n: int) -> int:
		if n > 600:
			return -1
		for entity: SimEntity in lv.get_kind(Defs.Kind.COLLECTIBLE):
			var item: CollectibleBase = entity as CollectibleBase
			if item != null and item.item_id == &"items/fire_starter" and not item.collected:
				if item.sim_pos.y > h.sim_pos.y + 8 and h.sim_pos.y <= NEST_Y:
					var mid: int = (AX + 10) * 16
					return _skull_safe(lv, h, R if h.sim_pos.x >= mid else L)
				if h.sim_pos.y > NEST_Y and h.is_grounded() and absi(h.sim_pos.x - item.sim_pos.x) <= 6 \
						and item.sim_pos.y < h.sim_pos.y - 8:
					return U if h.no_jump == 0 else 0
				return _skull_safe(lv, h, _toward(h, item.sim_pos.x, 2))
		return -1])
	for p: Array in [p1, p2]:
		p.append(["fn", func(lv: LevelBase, h: PlayerBase, _n: int) -> int:
			if h.sim_pos.y <= NEST_Y and h.is_grounded():
				# off the nest's right end first
				return R
			return _skull_safe(lv, h, R)])
	return [p1, p2]
