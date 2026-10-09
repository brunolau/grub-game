extends "res://tools/autoplay/recorders/d8/coop_lib.gd"
## The two-stream co-op route of w8_l2b_coop (D8): the approach (P1 opens the painting crypt, P2 keeps up), the
## Raptor pincer (P2 bounces, P1 strikes), the drop into the Idol Court, then a duo pilot of the Twin Hit: P1 holds
## the Moon's half, P2 the Sun's; both stand at their strike spots and high-strike on the same tick (a twin crack),
## each dodging the rocks and masonry of his own half from the altar; then the fire-starter and the exit totem.

const PILOT: GDScript = preload("res://tools/autoplay/recorders/bosses10/d8/idols_pilot3.gd")

var pilots: Array = []
var _duo_tick: int = -1
var _duo_flags: Array[int] = [0, 0]


func header() -> String:
	return "# route: level=w8_l2b_coop difficulty=expert players=2 ends=exit after=tally expect=min_checkpoints:1,painting:11,boss_hits:16,unlocked:true\n"


func idols() -> Idols:
	for entity: SimEntity in level.get_kind(Defs.Kind.BOSS):
		if entity is Idols:
			return entity as Idols
	return null


func _pilot(slot: int) -> Object:
	while pilots.size() < 2:
		pilots.append(PILOT.new())
	return pilots[slot]


## Both heroes' flags for this tick (computed once per tick for the two slots).
func duo_fn(limit: int = 6000) -> Callable:
	return func(lv: LevelBase, h: PlayerBase, n: int) -> int:
		var b: Idols = idols()
		if b == null or b.dead or n > limit:
			return -1
		if _duo_tick != t:
			_duo_tick = t
			_duo_step(lv, b)
		return _duo_flags[h.slot]


func _duo_step(lv: LevelBase, b: Idols) -> void:
	var ready: Array[bool] = [false, false]
	# an egg: the partner walks to it and clubs it open first
	for slot: int in 2:
		var down: PlayerBase = hero(slot)
		var helper: PlayerBase = hero(1 - slot)
		if down != null and down.down and helper != null and not helper.down:
			_duo_flags[slot] = 0
			var p0: Object = _pilot(1 - slot)
			var plan: Array = p0.get("plan")
			if not plan.is_empty():
				_duo_flags[1 - slot] = int(plan.pop_front())
				return
			var dx: int = down.sim_pos.x - helper.sim_pos.x
			if absi(dx) > 22 or not helper.is_grounded():
				var f0: int = int(p0.call(&"go_to", helper, down.sim_pos.x - signi(dx) * 18))
				_duo_flags[1 - slot] = f0 if f0 >= 0 else 0
				return
			if helper.facing != signi(dx) and dx != 0:
				_duo_flags[1 - slot] = Defs.IN_RIGHT if dx > 0 else Defs.IN_LEFT
				return
			_duo_flags[1 - slot] = Defs.IN_FIRE if t % 12 < 6 else 0
			return
	for slot: int in 2:
		var hh: PlayerBase = hero(slot)
		var p: Object = _pilot(slot)
		var idol: int = Idols.MOON if slot == 0 else Idols.SUN
		var f: int = p.call(&"coop_flags", hh, b, lv, idol)
		_duo_flags[slot] = f
		ready[slot] = f == -2
	for slot: int in 2:
		if _duo_flags[slot] == -2:
			_duo_flags[slot] = 0
	if ready[0] and ready[1]:
		for slot: int in 2:
			var p2: Object = _pilot(slot)
			_duo_flags[slot] = p2.call(&"start_strike")
	# keep both awake: a tick of nothing is input-free; the pilots press keys often enough (checked by the route test)


func build() -> Array:
	var fight: Dictionary = {"fight": true}
	var p1: Array = []
	var p2: Array = []
	# --- the approach: the leech scarab (whoever it rides, the other clubs it off), P1 opens the painting crypt
	# while P2 waits beside it, P1 kills the raptor
	p2.append(["keys", 2, R])
	p1.append(["mark", "approach"])
	p1.append(["go", cx(7), fight])
	p2.append(["go", cx(5), {}])
	p1.append(["fn", leech_fn(300)])
	p2.append(["fn", leech_fn(300)])
	p1.append(["sync", "crypt"])
	p2.append(["sync", "crypt"])
	p1.append(["go", cx(12), fight])
	p1.append(["face", 1])
	p1.append(["fn", open_fn(Vector2i(13, 5), D)])
	p1.append(["go", cx(15), {"tol": 2}])
	p1.append(["face", -1])
	p1.append(["fn", open_fn(Vector2i(14, 5), D)])
	p1.append(["go", cx(13.5), {"tol": 2}])
	p1.append(["until", func(lv: LevelBase, hh: PlayerBase) -> bool: return hh.is_grounded() and hh.sim_pos.y == 8 * 16, 0])
	p1.append(["go", cx(12), {"tol": 2}])
	p1.append(["go", cx(15), {"tol": 2}])
	p1.append(["go", cx(13.5), {"tol": 2}])
	p1.append(["wait", 7])
	p1.append(["leap", cx(15.5), 12])
	p1.append(["mark", "out of the crypt"])
	p2.append(["go", cx(9), {}])
	p2.append(["fn", wait_for(func(lv: LevelBase, hh: PlayerBase) -> bool: return hero(0).sim_pos.y <= 80 and hero(0).sim_pos.x >= cx(15), 900)])
	p1.append(["sync", "raptor"])
	p2.append(["sync", "raptor"])
	p1.append(["go", cx(18), fight])
	p1.append(["wait", 20])
	p1.append(["fn", hopper_fn(200, 400)])
	p1.append(["fn", clear_fn(120, 300)])
	p1.append(["go", cx(20), fight])
	p2.append(["go", cx(11), {}])
	p2.append(["wait", 6])
	p2.append(["leap", cx(16), 8])
	p2.append(["fn", wait_for(func(lv: LevelBase, hh: PlayerBase) -> bool: return hero(0).sim_pos.x >= cx(19) and hero(0).is_grounded(), 600)])
	p1.append(["sync", "court"])
	p2.append(["sync", "court"])
	p1.append(["go", cx(25), fight])
	p2.append(["go", cx(23), fight])
	p1.append(["go", cx(38.5), {"tol": 3}])
	p1.append(["until", func(lv: LevelBase, hh: PlayerBase) -> bool: return hh.is_grounded() and hh.sim_pos.y >= 14 * 16, 0])
	p1.append(["go", 604, {"tol": 3}])
	p2.append(["go", cx(36), {"tol": 3}])
	p2.append(["fn", wait_for(func(lv: LevelBase, hh: PlayerBase) -> bool: return hero(0).sim_pos.y >= 14 * 16 and hero(0).is_grounded() and hero(0).sim_pos.x <= 610, 300)])
	p2.append(["go", cx(39), {"tol": 2}])
	p2.append(["until", func(lv: LevelBase, hh: PlayerBase) -> bool: return hh.is_grounded() and hh.sim_pos.y >= 14 * 16, R])
	p2.append(["go", 642, {"tol": 3}])
	p1.append(["mark", "court"])
	p1.append(["sync", "fight"])
	p2.append(["sync", "fight"])
	p1.append(["fn", duo_fn()])
	p2.append(["fn", duo_fn()])
	p1.append(["mark", "beaten"])
	p1.append(["wait", 20])
	p2.append(["wait", 20])
	p1.append(["fn", fetch_any_fn(&"items/fire_starter")])
	p2.append(["fn", fidget_fn(200)])
	p1.append(["fn", walk_to_fn(cx(38.5))])
	p2.append(["fn", walk_to_fn(cx(38.5))])
	p1.append(["wait", 40])
	p2.append(["fn", fidget_fn(900)])
	return [p1, p2]


## The leech: while it rides a hero, the other walks to him and strikes it off; ends when it is dead (or never came).
func leech_fn(limit: int = 300) -> Callable:
	return func(lv: LevelBase, h: PlayerBase, n: int) -> int:
		var st: Dictionary = _st[h.slot]
		if n > limit:
			return -1
		var leech: EnemyBase = null
		for entity: SimEntity in lv.get_kind(Defs.Kind.ENEMY):
			var foe: EnemyBase = entity as EnemyBase
			if foe != null and not foe.dead and foe._traits != null and foe._traits.kind == Defs.CoopTrait.LEECH:
				leech = foe
		if leech == null:
			return -1
		if int(st.get("striking", 0)) > 0:
			st["striking"] = int(st["striking"]) - 1
			return F if int(st["striking"]) > 7 else 0
		var host: PlayerBase = leech._traits.host
		if host == h:
			return 0
		var tx: int = leech.sim_pos.x
		var rel: int = tx - h.sim_pos.x
		var side: int = 1 if rel > 0 else -1
		if not h.is_grounded():
			return 0
		if absi(rel) > 26:
			return R if side > 0 else L
		if absi(rel) < 10:
			return L if side > 0 else R
		if h.facing != side:
			return R if side > 0 else L
		st["striking"] = 10
		return F


## Walk to the collectible `id` until it is gone.
func fetch_any_fn(id: StringName, limit: int = 600) -> Callable:
	return func(lv: LevelBase, h: PlayerBase, n: int) -> int:
		if n > limit:
			return -1
		var target: SimEntity = null
		for entity: SimEntity in lv.get_kind(Defs.Kind.COLLECTIBLE):
			if entity.scene_file_path.get_file().get_basename() == String(id).get_file() and is_instance_valid(entity):
				target = entity
		if target == null:
			return -1
		var p: Object = _pilot(h.slot)
		var plan: Array = p.get("plan")
		if not plan.is_empty():
			return int(plan.pop_front())
		var f: int = int(p.call(&"go_to", h, target.sim_pos.x))
		return f if f >= 0 else 0


func walk_to_fn(x: int, limit: int = 400) -> Callable:
	return func(lv: LevelBase, h: PlayerBase, n: int) -> int:
		if n > limit:
			return -1
		var p: Object = _pilot(h.slot)
		var plan: Array = p.get("plan")
		if not plan.is_empty():
			return int(plan.pop_front())
		return int(p.call(&"go_to", h, x))
