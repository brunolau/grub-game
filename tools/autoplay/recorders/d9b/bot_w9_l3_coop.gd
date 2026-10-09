extends "res://tools/autoplay/recorders/d9b/bot_w9_l3.gd"
## D9b: the two-stream route of w9_l3_coop (Expert): both heroes climb (P2 a step behind P1), P1 opens the chieftains'
## tent (Cave Painting 16) while P2 keeps watch, both go up the chimney into the pyre hall and fight the co-op Rival
## Chieftains with enemies-C's club pilot each: when one chieftain is an egg, the hero nearer to it smashes it while
## the other keeps the surviving chieftain busy within 64 px (the hold-off rule of B.6); when both are eggs each
## smashes his own; then P1 takes the Great Roast. Both heroes give input all the time (no 243-tick wait).

var _plans: Array = [[], []]
var _lx: Array[int] = [-100000, -100000]
var _st_n: Array[int] = [0, 0]
var _ly: Array[int] = [-100000, -100000]
var _ast: Array[int] = [0, 0]


func header() -> String:
	return "# route: level=w9_l3_coop difficulty=expert players=2 ends=trophy after=level:ending_b_coop expect=wipes:0,eggs:0,painting:16,secrets:1,min_checkpoints:2\n"


func duo_fight_fn() -> Callable:
	return func(lv: LevelBase, h: PlayerBase, n: int) -> int:
		var list: Array[Chieftain] = chiefs(lv)
		var alive: bool = false
		for c: Chieftain in list:
			if not c.dead and c.life != Chieftain.Life.OUT:
				alive = true
		if not alive or n > 12000:
			return -1
		if h.slot == 0:
			_check_hud(lv, list)
		var f: int = _duo(h, list)
		if trace and t % 4 == 0 and h.slot == 1:
			var s: String = ""
			for c: Chieftain in list:
				s += " | %s L%d hp%d (%d,%d) o%d a%d cd%d eg%d eh%d" % [c.spawn_params.get("name", "?"), c.life, c.hp,
					c.sim_pos.x, c.sim_pos.y, c.order_kind, c.get_act(), c.hit_cooldown, c._egg_timer, c._egg_hits]
			var p1: PlayerBase = hero(0)
			print("D t=%d P1 (%d,%d)%s%s P2 (%d,%d)%s%s%s" % [t, p1.sim_pos.x, p1.sim_pos.y, "E" if p1.is_down() else "",
				"" if p1.counts_for_coop() else "z", h.sim_pos.x, h.sim_pos.y, "E" if h.is_down() else "",
				"" if h.counts_for_coop() else "z", s])
		return f


func _duo(h: PlayerBase, list: Array[Chieftain]) -> int:
	var slot: int = h.slot
	var plan: Array = _plans[slot]
	if not plan.is_empty():
		return int(plan.pop_front())
	if h.is_down():
		# An egg: wriggle (input of his own) until the partner hatches him.
		return L if t % 8 < 4 else R
	var other: PlayerBase = hero(1 - slot)
	var eggs: Array[Chieftain] = []
	var fighters: Array[Chieftain] = []
	for c: Chieftain in list:
		if c.dead:
			continue
		if c.life == Chieftain.Life.EGG:
			eggs.append(c)
		elif c.life == Chieftain.Life.FIGHT:
			fighters.append(c)
	var target: Chieftain = null
	if eggs.size() == 2:
		# Each takes the egg nearer to P1 / the other one.
		var near0: bool = absi(eggs[0].sim_pos.x - hero(0).sim_pos.x) <= absi(eggs[1].sim_pos.x - hero(0).sim_pos.x)
		target = (eggs[0] if near0 else eggs[1]) if slot == 0 else (eggs[1] if near0 else eggs[0])
	elif eggs.size() == 1:
		var egg: Chieftain = eggs[0]
		var mine: int = absi(egg.sim_pos.x - h.sim_pos.x) + absi(egg.sim_pos.y - h.sim_pos.y)
		var theirs: int = absi(egg.sim_pos.x - other.sim_pos.x) + absi(egg.sim_pos.y - other.sim_pos.y)
		var smasher: bool = mine < theirs or (mine == theirs and slot == 0)
		if other.is_down() or not other.counts_for_coop():
			smasher = false
		if smasher:
			target = egg
		elif egg.mate != null and not egg.mate.dead and egg.mate.life == Chieftain.Life.FIGHT:
			target = egg.mate
		else:
			target = egg
	elif fighters.size() == 2:
		var near0: bool = absi(fighters[0].sim_pos.x - hero(0).sim_pos.x) <= absi(fighters[1].sim_pos.x - hero(0).sim_pos.x)
		target = (fighters[0] if near0 else fighters[1]) if slot == 0 else (fighters[1] if near0 else fighters[0])
	elif fighters.size() == 1:
		target = fighters[0]
	if target == null:
		return D if t % 40 == slot * 20 else 0
	return _pilot(h, target)


## enemies-C's ChiefClubPilot for one hero and one target (an egg or a fighting chieftain).
func _pilot(hero: PlayerBase, target: Chieftain) -> int:
	var slot: int = hero.slot
	var plan: Array = _plans[slot]
	if not hero.is_grounded():
		if hero.yvel >= 0 and hero.sim_pos.y == _ly[slot]:
			_ast[slot] += 1
		else:
			_ast[slot] = 0
		_ly[slot] = hero.sim_pos.y
		if _ast[slot] >= 3:
			return R if hero.sim_pos.x < ALTAR_X else L
		return 0
	_ast[slot] = 0
	var weak: Rect2i = target.get_weak_rect()
	var x: int = hero.sim_pos.x
	var tx: int = target.sim_pos.x
	var dir: int = 1 if tx >= x else -1
	var toward: int = R if dir > 0 else L
	var away: int = L if dir > 0 else R
	var dx: int = absi(tx - x)
	var same_floor: bool = absi(target.sim_pos.y - hero.sim_pos.y) <= 6
	if same_floor and dx >= 10 and dx <= 36:
		if hero.facing != dir:
			return toward
		var ready: bool = target.hit_cooldown == 0 if target.life == Chieftain.Life.FIGHT else target._egg_gap == 0
		if ready and Overlap.rects(_front_box(hero.sim_pos, dir), weak):
			for i: int in 5:
				plan.append(F)
			plan.append(0)
			return F
		if dx < 14:
			return away
		return toward if dx > 30 else (D if t % 30 == slot * 15 else 0)
	if same_floor and dx < 10:
		return away
	var key: int = toward
	if x == _lx[slot]:
		_st_n[slot] += 1
	else:
		_st_n[slot] = 0
	_lx[slot] = x
	var higher: bool = target.sim_pos.y < hero.sim_pos.y - 6
	var partner: PlayerBase = hero(1 - slot)
	var partner_near: bool = partner != null and absi(partner.sim_pos.x - x) < 40
	if higher and target.life == Chieftain.Life.FIGHT:
		# A chieftain up on a ledge or the altar: never jump at him (a hero on his head would have his own head in the
		# crown); wait 44 px aside until he comes down.
		var spot: int = tx - dir * 44
		if absi(spot - x) <= 4:
			return D if t % 40 == slot * 20 else 0
		return R if spot > x else L
	if (higher and dx <= 40) or (_st_n[slot] >= 2 and not partner_near):
		_st_n[slot] = 0
		for i: int in 9:
			plan.append(U | key)
		return U | key
	return key


## P1 takes the roast; P2 walks to the altar's foot and back (input of his own).
func duo_trophy_fn() -> Callable:
	var single: Callable = trophy_fn()
	return func(lv: LevelBase, h: PlayerBase, n: int) -> int:
		if h.slot == 1:
			if Game.level == null or Game.level.completed or n > 3000:
				return -1
			return D if n % 60 == 30 else 0
		return single.call(lv, h, n)


## Wait for the partner with a crouch every 100 ticks (the idle rule: no 243 quiet ticks).
func keep_awake(sync_name: String) -> Array:
	return [["sync", sync_name]]


func build() -> Array:
	trace = opts.has("trace")
	var progs: Array = []
	for slot: int in 2:
		var p: Array = []
		var fight: Dictionary = {"fight": true}
		var o: int = slot * 24
		if opts.has("at"):
			p.append(["mark", "dev start"])
			p.append(["fn", duo_fight_fn()])
			p.append(["fn", duo_trophy_fn()])
			progs.append(p)
			continue
		p.append(["mark", "the bottom terrace"])
		p.append(["run", 700 + o, fight])
		p.append(["go", 700 + o, {"tol": 3, "fight": true}])
		p.append(["sync", "pit"])
		if slot == 1:
			p.append(["wait", 10])
			p.append(["go", 700, {"tol": 3}])
		p.append(["jump", -1, 12, {"min": 6}])
		p.append(["run", 360 + o, fight])
		p.append(["go", 40 + o, {"tol": 1, "fight": true}])
		if slot == 1:
			p.append(["sync", "vine1"])
			p.append(["go", 40, {"tol": 1}])
		p.append(["until", func(lv: LevelBase, hh: PlayerBase) -> bool:
			return hh.is_grounded() and hh.sim_pos.y == 416, U])
		if slot == 0:
			p.append(["sync", "vine1"])
			p.append(["go", 76, {"tol": 2, "fight": true}])
		p.append(["sync", "middle"])
		p.append(["mark", "the middle terrace"])
		p.append(["run", 900 - o, fight])
		p.append(["go", 936 - o, {"tol": 1, "fight": true}])
		if slot == 1:
			p.append(["sync", "vine2"])
			p.append(["go", 936, {"tol": 1}])
		p.append(["until", func(lv: LevelBase, hh: PlayerBase) -> bool:
			return hh.is_grounded() and hh.sim_pos.y == 272, U])
		if slot == 0:
			p.append(["sync", "vine2"])
			p.append(["go", 912, {"tol": 3}])
		p.append(["sync", "upper"])
		if slot == 0:
			p.append(["mark", "the chieftains' tent"])
			p.append(["go", 908, {"tol": 2}])
			p.append(["face", -1])
			p.append(["fn", open_fn(Vector2i(55, 16))])
			p.append(["wait", 30])
			p.append(["go", 888, {"tol": 3}])
			p.append(["wait", 10])
			p.append(["sync", "tent"])
			p.append(["go", 800, {"tol": 3}])
			p.append(["sync", "gallery"])
			p.append_array(hall_entry())
		else:
			p.append(["go", 936, {"tol": 3}])
			p.append(["fn", func(lv: LevelBase, hh: PlayerBase, n: int) -> int:
				if _released.has("tent") or _syncs[0] == "tent":
					return -1
				return D if n % 80 == 40 else 0])
			p.append(["sync", "tent"])
			p.append(["go", 840, {"tol": 3}])
			p.append(["sync", "gallery"])
			p.append(["go", 664, {"tol": 3}])
			p.append(["fn", func(lv: LevelBase, hh: PlayerBase, n: int) -> int:
				if hh.sim_pos.y <= 176 or n > 600:
					return -1
				return D if n % 80 == 40 else 0])
		p.append(["mark", "the fight"])
		p.append(["fn", duo_fight_fn()])
		p.append(["mark", "the roast"])
		p.append(["fn", duo_trophy_fn()])
		progs.append(p)
	return progs
