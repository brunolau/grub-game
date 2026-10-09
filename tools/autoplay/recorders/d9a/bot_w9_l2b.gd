extends "res://tools/autoplay/recorders/d9a/botlib.gd"
## The Expert club route of w9_l2b Storm Nest (D9a), recorded by probe_work.gd --bot: the approach with the painting
## hollow, the drop into the arena and a closed-loop fight against the solo Storm Roc (scripts/bosses/roc.gd):
##  - perched (REST / WINGS / GUST): stand on the nest beside its body and high-strike the head band whenever the hit
##    cooldown allows;
##  - circling / screeching: stand on the floor; at the end of the screech be running so its dive misses; while the
##    beak is buried, step in front of the head and strike it;
##  - storm: fetch the glider from the nest, pace near the wall opposite the cruise half (out of the lightning), and
##    once it cruises take off toward that half, climb on lift against the side wall and dive onto its back;
##  - the fire-starter on the nest, then the exit totem.

const AX: int = 30
const AY: int = 5
var FLOOR_Y: int = (AY + 10) * 16
var NEST_Y: int = (AY + 8) * 16
var LEFT_X: int = (AX + 1) * 16 + 8
var RIGHT_X: int = (AX + 18) * 16 + 8


func header() -> String:
	return "# route: level=w9_l2b difficulty=expert ends=exit after=tally expect=max_hurts:2,deaths:0,min_checkpoints:1,painting:15,unlocked:true\n" \
		+ "# The Expert club route of Storm Nest (designer D9a; recorded from a closed-loop bot, build/d9a/bot_w9_l2b.gd): the\n" \
		+ "# painting hollow under the breakable floor blocks, the checkpoint, the drop into the arena; the Storm Roc's head\n" \
		+ "# struck from the nest while it perches and on the buried beak after its dives, then three glider dives onto its\n" \
		+ "# back while it cruises (run-up, a climb on lift against the side wall, a dive); the fire-starter, the exit.\n"


func roc() -> Roc:
	if level == null:
		return null
	for entity: SimEntity in level.get_kind(Defs.Kind.BOSS):
		if entity is Roc:
			return entity as Roc
	return null


func _bolt_danger(h: PlayerBase) -> int:
	## The direction away from a bolt column that would strike near the hero soon (0 = none).
	for entity: SimEntity in level.get_kind(Defs.Kind.ENEMY_PROJECTILE):
		var bolt: BossBolt = entity as BossBolt
		if bolt == null or bolt.spent:
			continue
		if (bolt.is_marking() or bolt.is_striking()) and absi(bolt.sim_pos.x - h.sim_pos.x) < 30:
			return 1 if h.sim_pos.x >= bolt.sim_pos.x else -1
	return 0


func _key(dir: int) -> int:
	return R if dir > 0 else (L if dir < 0 else 0)


## Walk toward x (no stop precision needed); 0 when there.
func _toward(h: PlayerBase, x: int, tol: int = 3) -> int:
	if absi(x - h.sim_pos.x) <= tol:
		return 0
	return R if x > h.sim_pos.x else L


var _pilot: RefCounted = null


func pilot_fn() -> Callable:
	return func(lv: LevelBase, h: PlayerBase, n: int) -> int:
		var boss: Roc = roc()
		if boss == null or boss.dead or n > 12000:
			return -1
		if _pilot == null:
			_pilot = (load("res://tools/autoplay/recorders/d9a/roc_pilot.gd") as GDScript).new(AX * 16, AY * 16)
		return int(_pilot.call(&"flags", h, boss, lv))


func fight_fn() -> Callable:
	return func(lv: LevelBase, h: PlayerBase, n: int) -> int:
		var st: Dictionary = _st[h.slot]
		var boss: Roc = roc()
		if boss == null or boss.dead:
			return -1
		if n > 9000:
			return -1
		var state: int = boss.get_state()
		if state == Roc.State.DYING:
			return 0
		var gliding: bool = int(h.get(&"glide")) & 1 != 0
		if gliding or str(st.get("plan", "")) == "fly":
			return _fly(lv, h, boss, st)
		if boss.is_storm_phase():
			return _storm(lv, h, boss, st)
		match state:
			Roc.State.REST, Roc.State.WINGS, Roc.State.GUST:
				return _perched(h, boss, st)
			Roc.State.BURIED:
				return _buried(h, boss, st)
			Roc.State.SCREECH:
				# be running when the dive starts, away from under it (the dive then points the head ahead of him)
				var dir: int = int(st.get("flee", 0))
				if dir == 0:
					var dx: int = h.sim_pos.x - boss.sim_pos.x
					dir = signi(dx) if absi(dx) > 24 else (1 if h.sim_pos.x < (LEFT_X + RIGHT_X) / 2 else -1)
					if (dir > 0 and h.sim_pos.x > RIGHT_X - 80) or (dir < 0 and h.sim_pos.x < LEFT_X + 80):
						dir = -dir
					st["flee"] = dir
				if int(boss.get(&"_timer")) < 7:
					return 0
				return _key(dir)
			Roc.State.DIVE:
				var d2: int = int(st.get("flee", 1))
				if (d2 > 0 and h.sim_pos.x >= RIGHT_X - 4) or (d2 < 0 and h.sim_pos.x <= LEFT_X + 4):
					return 0
				return _key(d2)
			_:
				st["flee"] = 0
				# circling / rising: wait on the floor out from under the nest, near the middle
				if h.sim_pos.y < FLOOR_Y:
					return _toward(h, LEFT_X + 40)
				return _toward(h, (LEFT_X + RIGHT_X) / 2 + (60 if h.sim_pos.x > (LEFT_X + RIGHT_X) / 2 else -60), 8)


## Perched: stand on the nest beside its body (the free side of the nest) and high-strike the head band.
func _perched(h: PlayerBase, boss: Roc, st: Dictionary) -> int:
	var head: Rect2i = boss.get_head_rect()
	var left_rim: bool = boss.sim_pos.x < boss.get_nest_center().x
	var spot: int = boss.sim_pos.x + (66 if left_rim else -66)
	var face: int = -1 if left_rim else 1
	if int(st.get("striking", 0)) > 0:
		st["striking"] = int(st["striking"]) - 1
		return (F | U) if int(st["striking"]) > 2 else 0
	if not h.is_grounded():
		return _toward(h, spot)
	if h.sim_pos.y > NEST_Y:
		# on the floor: walk under the spot and jump up through the nest
		if absi(h.sim_pos.x - spot) > 4:
			return _toward(h, spot)
		return U if h.no_jump == 0 else 0
	if absi(h.sim_pos.x - spot) > 4:
		return _toward(h, spot)
	if h.xvel != 0:
		return 0
	if h.facing != face:
		return _key(face)
	if head.has_area() and boss.hit_cooldown == 0 and not h.is_striking():
		st["striking"] = 9
		return F | U
	return 0


## The beak is buried: stand in front of the head and strike it.
func _buried(h: PlayerBase, boss: Roc, st: Dictionary) -> int:
	if int(st.get("striking", 0)) > 0:
		st["striking"] = int(st["striking"]) - 1
		return F if int(st["striking"]) > 2 else 0
	var front: int = boss.facing
	var spot: int = clampi(boss.sim_pos.x + front * 70, LEFT_X, RIGHT_X)
	if not h.is_grounded():
		return 0
	if absi(h.sim_pos.x - spot) > 4:
		# never walk through its body: when behind it, wait
		if (h.sim_pos.x - boss.sim_pos.x) * front < 0:
			return 0
		return _toward(h, spot)
	if h.xvel != 0:
		return 0
	if h.facing != -front:
		return _key(-front)
	if boss.hit_cooldown == 0 and not h.is_striking():
		st["striking"] = 9
		return F
	return 0


## The storm phase on the ground: fetch the glider, then pace near the wall opposite the cruise half, building the
## run-up; take off toward the cruise half once it cruises.
func _storm(_lv: LevelBase, h: PlayerBase, boss: Roc, st: Dictionary) -> int:
	var run: PlayerRun = h.run
	if not run.has_glider:
		var c: int = boss.get_nest_center().x
		if h.sim_pos.y > NEST_Y and h.is_grounded():
			if absi(h.sim_pos.x - c) > 4:
				return _toward(h, c)
			return U if h.no_jump == 0 else 0
		if not h.is_grounded():
			return _toward(h, c)
		return _toward(h, c)
	# the half of the coming / current cruise: 1 right, 0 left
	var half: int = int(boss.get(&"_cruise_half"))
	var state: int = boss.get_state()
	if state == Roc.State.DESCEND or state == Roc.State.CRUISE or state == Roc.State.SWOOP_SCREECH:
		half = 1 if boss.sim_pos.x > boss.get_nest_center().x else 0
	var toward: int = 1 if half == 1 else -1
	# pace near the far wall: between the wall and 120 px out
	var wall: int = LEFT_X if toward > 0 else RIGHT_X
	var dir: int = int(st.get("pace", -toward))
	var danger: int = _bolt_danger(h)
	if h.sim_pos.y < FLOOR_Y and h.is_grounded():
		# still on the nest: walk off it toward the wall
		return _key(-toward)
	if danger != 0:
		dir = danger
	elif dir == -toward and absi(h.sim_pos.x - wall) <= 12:
		dir = toward
	elif dir == toward and absi(h.sim_pos.x - wall) >= 150:
		dir = -toward
	st["pace"] = dir
	var ready: bool = state == Roc.State.CRUISE and int(boss.get(&"_timer")) < 100
	if ready and int(h.get(&"glider_runup")) >= 24 and dir == toward and h.xvel * toward > 0 \
			and absi(h.sim_pos.x - wall) < 70:
		st["plan"] = "fly"
		st["fly_dir"] = toward
		st["fly_n"] = 0
		return _key(toward) | U
	return _key(dir)


## In the air under the glider: climb toward the cruise half against the wall, then dive onto its back.
func _fly(_lv: LevelBase, h: PlayerBase, boss: Roc, st: Dictionary) -> int:
	var dir: int = int(st.get("fly_dir", 1))
	st["fly_n"] = int(st.get("fly_n", 0)) + 1
	var gliding: bool = int(h.get(&"glide")) & 1 != 0
	if not gliding:
		if int(st["fly_n"]) > 3:
			st["plan"] = ""
			st["pace"] = 0
			return 0
		return _key(dir) | U
	var lift: int = int(h.get(&"glider_lift"))
	var back: Rect2i = boss.get_back_rect()
	var over: bool = back.has_area() and h.sim_pos.x >= back.position.x + 6 and h.sim_pos.x <= back.end.x - 6 \
			and h.sim_pos.y < back.position.y - 2
	var phase: String = str(st.get("fly", "climb"))
	if phase == "climb":
		if lift > 0:
			return _key(dir) | U
		phase = "coast"
	if phase == "coast":
		if h.yvel < 0:
			st["fly"] = phase
			return _key(dir)
		phase = "dive"
	st["fly"] = phase
	if phase == "dive":
		if not back.has_area():
			# it left the cruise (or was hit): come down
			return D
		return (_key(dir) if not over else 0) | D
	return D


func build() -> Array:
	var f: Dictionary = {"fight": true}
	var p: Array = []
	# the approach: hop the tuft, break the two floor blocks, the painting in the hollow
	p.append(["go", cx(3), f])
	p.append(["hop", cx(7), 9])
	p.append(["go", cx(10), f])
	p.append(["face", 1])
	p.append(["keys", 8, D | F])
	p.append(["wait", 6])
	p.append(["keys", 8, D | F])
	p.append(["wait", 6])
	p.append(["go", cx(11), {"tol": 1, "max": 80}])
	p.append(["until", func(_l: LevelBase, hh: PlayerBase) -> bool: return hh.is_grounded() and hh.sim_pos.y >= (AY + 3) * 16, 0])
	p.append(["go", cx(15), {}])
	p.append(["go", cx(11) + 2, {}])
	p.append(["hop", cx(9), 9, {"lead": 2}])
	p.append(["go", cx(9), {}])
	p.append(["hop", cx(14), 9, {"lead": 2}])
	# the boulder, the checkpoint, the drop into the arena
	p.append(["go", cx(16), f])
	p.append(["clear", 140, 200])
	p.append(["hop", cx(19), 9])
	p.append(["hop", cx(23), 9])
	p.append(["go", cx(26), f])
	p.append(["run", cx(31)])
	p.append(["until", func(_l: LevelBase, hh: PlayerBase) -> bool: return hh.is_grounded(), R])
	# the fight: enemies-C's closed-loop pilot (tests/test_enemies_roc.gd RocClubPilot) shifted onto this arena
	p.append(["fn", pilot_fn()])
	# the fire-starter (thrown out over the nest), the exit; the bonus burst may hold a skull: step over it
	p.append(["wait", 110])
	p.append(["fn", func(lv: LevelBase, h: PlayerBase, n: int) -> int:
		if n > 600:
			return -1
		for entity: SimEntity in lv.get_kind(Defs.Kind.COLLECTIBLE):
			var item: CollectibleBase = entity as CollectibleBase
			if item != null and item.item_id == &"items/fire_starter" and not item.collected:
				if item.sim_pos.y > h.sim_pos.y + 8 and h.sim_pos.y <= NEST_Y:
					# it lies on the floor under the nest: walk off the nest's nearer end first
					var mid: int = (AX + 10) * 16
					return _skull_safe(lv, h, R if h.sim_pos.x >= mid else L)
				if h.sim_pos.y > NEST_Y and h.is_grounded() and absi(h.sim_pos.x - item.sim_pos.x) <= 6 \
						and item.sim_pos.y < h.sim_pos.y - 8:
					return U if h.no_jump == 0 else 0
				return _skull_safe(lv, h, _toward(h, item.sim_pos.x, 2))
		return -1])
	p.append(["fn", func(lv: LevelBase, h: PlayerBase, _n: int) -> int:
		return _skull_safe(lv, h, R)])
	return [p]


## dir_keys (L / R / 0) unchanged, or a hop over a skull lying just ahead on the hero's floor.
func _skull_safe(lv: LevelBase, h: PlayerBase, dir_keys: int) -> int:
	if dir_keys == 0:
		return 0
	var dir: int = 1 if dir_keys & R else -1
	if not h.is_grounded():
		return dir_keys
	for entity: SimEntity in lv.get_kind(Defs.Kind.COLLECTIBLE):
		var item: CollectibleBase = entity as CollectibleBase
		if item == null or item.collected or item.item_id != &"items/skull":
			continue
		var ahead: int = (item.sim_pos.x - h.sim_pos.x) * dir
		if ahead > 0 and ahead < 34 and absi(item.sim_pos.y - h.sim_pos.y) < 20:
			return (U | dir_keys) if h.no_jump == 0 else 0
	return dir_keys
