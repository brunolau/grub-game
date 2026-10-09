extends "res://tools/autoplay/recorders/d9b/botlib.gd"
## D9b: the club route of w9_l3 (Chieftains' Pyre): the climb (scripted commands), the fight against the Rival
## Chieftains on hero physics (enemies-C's ChiefClubPilot of tests/test_enemies_chieftain.gd, moved into the level),
## then the Great Roast on the altar.

const FLOOR_Y: int = 176
const ALTAR_X: int = 544
## The chimney into the hall (cols 38-40: a hero's box fits at x 624..640).
const CHIMNEY_X: int = 632

var trace: bool = false
## G35: the least distance (px) of a chieftain's weak point's top under the view's top during the fight.
var hud_min: int = 1 << 20
var hud_at: String = ""
var hud_problem: String = ""
var _plan: Array[int] = []
var _last_x: int = -100000
var _stuck: int = 0
var _last_y: int = -100000
var _air_still: int = 0


func report() -> void:
	print("HUD G35: weak point top at least %d px under the view top (%s) problem '%s'" % [hud_min, hud_at, hud_problem])


func header() -> String:
	return "# route: level=w9_l3 difficulty=expert ends=trophy after=level:ending_b expect=painting:16,secrets:1,min_checkpoints:2\n"


func chiefs(lv: LevelBase) -> Array[Chieftain]:
	var out: Array[Chieftain] = []
	for entity: SimEntity in lv.get_kind(Defs.Kind.BOSS):
		if entity is Chieftain:
			out.append(entity as Chieftain)
	return out


## The fight: -1 when both chieftains are out (the trophy then lies on the altar).
func chieftain_fight_fn() -> Callable:
	return func(lv: LevelBase, h: PlayerBase, n: int) -> int:
		var list: Array[Chieftain] = chiefs(lv)
		var alive: bool = false
		for c: Chieftain in list:
			if not c.dead and c.life != Chieftain.Life.OUT:
				alive = true
		if not alive or n > 12000:
			return -1
		_check_hud(lv, list)
		var f: int = pilot_flags(h, list)
		if trace and (t % 4 == 0):
			var s: String = ""
			for c: Chieftain in list:
				s += " | %s L%d hp%d (%d,%d) o%d a%d cd%d tg%d eg%d" % [c.spawn_params.get("name", "?"), c.life, c.hp,
					c.sim_pos.x, c.sim_pos.y, c.order_kind, c.get_act(), c.hit_cooldown, int(c.is_telegraphing()),
					c._egg_timer]
			print("F t=%d hero (%d,%d) g%d hp%d b%d f%d flags %d%s" % [t, h.sim_pos.x, h.sim_pos.y, int(h.is_grounded()),
				Game.hearts, Game.bones, h.facing, f, s])
		return f


func _check_hud(lv: LevelBase, list: Array[Chieftain]) -> void:
	var view: Rect2i = lv.get_view_rect()
	for c: Chieftain in list:
		var weak: Rect2i = c.get_weak_rect()
		if not weak.has_area():
			continue
		var top: int = weak.position.y - view.position.y
		if top < hud_min:
			hud_min = top
			hud_at = "t=%d %s weak %s view %s" % [t, c.spawn_params.get("name", "?"), weak, view]
		var art: Rect2 = Rect2(Vector2(weak.position - view.position) * 2, Vector2(weak.size) * 2)
		var problem: String = Hud.weak_point_problem(art, Vector2(view.size) * 2)
		if problem != "" and hud_problem == "":
			hud_problem = "t=%d %s: %s" % [t, c.spawn_params.get("name", "?"), problem]


## enemies-C's ChiefClubPilot (tests/test_enemies_chieftain.gd): an egg first, else the fighting chieftain; walk to
## him, strike when the forward box covers his body and his cooldown is over, jump where he stands higher.
func pilot_flags(hero: PlayerBase, list: Array[Chieftain]) -> int:
	if not _plan.is_empty():
		return _plan.pop_front()
	var target: Chieftain = _pick(list)
	if target == null:
		return 0
	if not hero.is_grounded():
		# Standing on a chieftain's head (his body is not solid but bounces us): step off towards the hall's middle.
		if hero.yvel >= 0 and hero.sim_pos.y == _last_y:
			_air_still += 1
		else:
			_air_still = 0
		_last_y = hero.sim_pos.y
		if _air_still >= 3:
			return R if hero.sim_pos.x < ALTAR_X else L
		return 0
	_air_still = 0
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
				_plan.append(F)
			_plan.append(0)
			return F
		if dx < 14:
			return away
		return toward if dx > 30 else 0
	if same_floor and dx < 10:
		return away
	var key: int = toward
	if x == _last_x:
		_stuck += 1
	else:
		_stuck = 0
	_last_x = x
	var higher: bool = target.sim_pos.y < hero.sim_pos.y - 6 and dx <= 40
	if higher or _stuck >= 2:
		_stuck = 0
		for i: int in 9:
			_plan.append(U | key)
		return U | key
	return key


static func _pick(list: Array[Chieftain]) -> Chieftain:
	for c: Chieftain in list:
		if not c.dead and c.life == Chieftain.Life.EGG:
			return c
	for c: Chieftain in list:
		if not c.dead and c.life == Chieftain.Life.FIGHT:
			return c
	return null


static func _front_box(feet: Vector2i, facing: int) -> Rect2i:
	var rect: Rect2i = Tuning.CLUB_BOX[Tuning.ClubFrame.FWD_FRONT]
	var origin: Vector2i = Tuning.CLUB_ORIGIN[Tuning.ClubFrame.FWD_FRONT]
	var xo: int = origin.x - rect.position.x
	var ox: int = feet.x + facing * origin.x
	return Rect2i(ox - xo, feet.y + rect.position.y, rect.size.x, rect.size.y)


## Collect the Great Roast wherever it lies (on the altar: jump up from the floor beside it).
func trophy_fn() -> Callable:
	return func(lv: LevelBase, h: PlayerBase, n: int) -> int:
		if n > 3000 or Game.level == null or Game.level.completed:
			return -1
		if not _plan.is_empty():
			return _plan.pop_front()
		var trophy: SimEntity = null
		for entity: SimEntity in lv.get_kind(Defs.Kind.COLLECTIBLE):
			if entity is Trophy:
				trophy = entity
		if trophy == null or not h.is_grounded():
			return 0
		var tx: int = trophy.sim_pos.x
		var ty: int = trophy.sim_pos.y
		if absi(h.sim_pos.y - ty) < 8:
			var dx: int = tx - h.sim_pos.x
			if absi(dx) <= 2:
				return 0
			return R if dx > 0 else L
		# Below it: jump up from 30 px to its left.
		var spot: int = tx - 30
		if absi(h.sim_pos.x - spot) > 3:
			return R if spot > h.sim_pos.x else L
		if h.xvel != 0:
			return 0
		for i: int in 9:
			_plan.append(U | R)
		for i: int in 8:
			_plan.append(R)
		return U | R


## Pass the Guard walking left: run at it, jump onto its head (the bounce carries him over), land behind it.
func pass_guard_fn() -> Callable:
	return func(lv: LevelBase, h: PlayerBase, n: int) -> int:
		var guard: EnemyBase = null
		for entity: SimEntity in lv.get_kind(Defs.Kind.ENEMY):
			if entity is Guard and not (entity as EnemyBase).dead:
				guard = entity as EnemyBase
		if guard == null or h.sim_pos.x < guard.sim_pos.x - 40 or n > 600:
			return -1
		if not _plan.is_empty():
			return _plan.pop_front()
		if not h.is_grounded():
			return L
		var dx: int = h.sim_pos.x - guard.sim_pos.x
		if dx <= 52 and dx > 0:
			for i: int in 13:
				_plan.append(L | U)
			return L | U
		return L


## From the upper terrace: under the chimney, up its two grates into the pyre hall.
func hall_entry() -> Array:
	var p: Array = []
	p.append(["mark", "the chimney"])
	p.append(["go", CHIMNEY_X, {"tol": 2}])
	p.append(["jump", 0, 12, {"min": 4}])
	p.append(["mark", "on the lower grate"])
	p.append(["wait", 7])
	p.append(["jump", 0, 12, {"min": 4}])
	p.append(["mark", "in the hall"])
	return p


func build() -> Array:
	var p: Array = []
	trace = opts.has("trace")
	if opts.has("at"):
		p.append(["mark", "dev start at %s" % str(opts["at"])])
	else:
		p.append(["mark", "the bottom terrace"])
		p.append(["run", 700, {"fight": true}])
		p.append(["go", 700, {"tol": 3, "fight": true}])
		p.append(["mark", "over the tar pit"])
		p.append(["jump", -1, 12, {"min": 6}])
		p.append(["run", 360, {"fight": true}])
		p.append(["go", 40, {"tol": 1, "fight": true}])
		p.append(["mark", "up the vine"])
		p.append(["until", func(lv: LevelBase, hh: PlayerBase) -> bool:
			return hh.is_grounded() and hh.sim_pos.y == 416, U])
		p.append(["mark", "the middle terrace"])
		p.append(["run", 900, {"fight": true}])
		p.append(["go", 936, {"tol": 1, "fight": true}])
		p.append(["mark", "up the vine"])
		p.append(["until", func(lv: LevelBase, hh: PlayerBase) -> bool:
			return hh.is_grounded() and hh.sim_pos.y == 272, U])
		p.append(["mark", "the chieftains' tent"])
		p.append(["go", 908, {"tol": 2}])
		p.append(["face", -1])
		p.append(["fn", open_fn(Vector2i(55, 16))])
		p.append(["wait", 30])
		p.append(["go", 888, {"tol": 3}])
		p.append(["wait", 10])
		p.append(["mark", "checkpoint 2 and the Guard"])
		p.append(["go", 800, {"tol": 3}])
		p.append(["fn", pass_guard_fn()])
		p.append_array(hall_entry())
	p.append(["mark", "the fight"])
	p.append(["fn", chieftain_fight_fn()])
	p.append(["mark", "the roast"])
	p.append(["fn", trophy_fn()])
	return [p]
