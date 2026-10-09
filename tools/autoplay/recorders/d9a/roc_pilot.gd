extends RefCounted
## enemies-C's closed-loop club-and-glider pilot of the solo Storm Roc (tests/test_enemies_roc.gd RocClubPilot), copied
## for D9a's Storm Nest with the arena's offset (development only, build/d9a): the test room's coordinates shifted by
## (ox, oy) logical px.


func _init(ox: int = 0, oy: int = 0) -> void:
	FLOOR_Y += oy
	NEST_TOP += oy
	NEST_X0 += ox
	NEST_X1 += ox
	MID_X += ox
	X_MIN += ox
	X_MAX += ox


var FLOOR_Y: int = 160
var NEST_TOP: int = 128
var NEST_X0: int = 96
var NEST_X1: int = 224
var MID_X: int = 160
var X_MIN: int = 32
var X_MAX: int = 288
const PERCH_DX: int = 62
const BURIED_DX: int = 40
const HIGH_TICKS: int = 9
const STRIKE_TICKS: int = 7
const JUMP_TICKS: int = 8
const BOLT_CLEAR: int = 30
const REFILL_LIFT: int = 25

var plan: Array[int] = []
## What it is doing (traces).
var note: String = ""
var _dodge_dir: int = 0
## Storm: the cruise half it prepares for (1 right, 0 left), the run-up direction while it runs (0: none), true
## while the dive-to-refill lasts.
var _half: int = -1
var _run: int = 0
var _refill: bool = false
var _last_x: int = -100000
var _stuck: int = 0

func flags(hero: PlayerBase, roc: Roc, level: LevelBase) -> int:
	if not plan.is_empty():
		return plan.pop_front()
	if roc.dead or roc.get_state() == Roc.State.DYING:
		note = "won"
		return 0
	if hero.hit_timer >= Tuning.HIT_STUN_MIN:
		note = "hurt"
		return 0
	if roc.is_storm_phase():
		return _storm(hero, roc, level)
	match roc.get_state():
		Roc.State.REST, Roc.State.WINGS, Roc.State.GUST:
			_dodge_dir = 0
			return _perched(hero, roc)
		Roc.State.DIVE:
			return _dodge(hero, roc)
		Roc.State.BURIED:
			return _buried(hero, roc)
	_dodge_dir = 0
	note = "middle"
	return _to_floor_spot(hero, MID_X, null)

# --- Phase 1 ------------------------------------------------------------------------------------------------------

func _perched(hero: PlayerBase, roc: Roc) -> int:
	var rx: int = roc.sim_pos.x
	var inward: int = 1 if rx < MID_X else -1
	var spot: int = rx + inward * PERCH_DX
	if not hero.is_grounded():
		note = "air"
		return 0
	if hero.sim_pos.y >= FLOOR_Y:
		note = "to perch spot (floor)"
		if absi(hero.sim_pos.x - spot) <= 2 and absi(hero.xvel) < 16:
			for i: int in JUMP_TICKS - 1:
				plan.append(Defs.IN_UP)
			return Defs.IN_UP
		return _floor_walk(hero, spot, roc)
	note = "perch spot"
	var move: int = go_to(hero, spot)
	if move >= 0:
		return move
	var face: int = -inward
	if hero.facing != face:
		return key_of(face)
	if hero.attack_gate:
		return 0
	if roc.hit_cooldown == 0 and roc.hp > roc.get_storm_hp() \
			and Overlap.rects(high_box(hero.sim_pos, face), roc.get_head_rect()):
		note = "high strike"
		for i: int in HIGH_TICKS - 2:
			plan.append(Defs.IN_UP | Defs.IN_FIRE)
		plan.append(0)
		return Defs.IN_UP | Defs.IN_FIRE
	return 0

## On the floor towards `spot`; crawling (Down + the direction) where a perched Roc's body would touch a standing
## hero (its feet 3 px under his head: his feet x in (rx - 53, rx + 15), the body test of Overlap).
func _floor_walk(hero: PlayerBase, spot: int, roc: Roc) -> int:
	var move: int = go_to(hero, spot)
	if move < 0:
		return 0
	if roc != null and (roc.get_state() == Roc.State.REST or roc.get_state() == Roc.State.WINGS \
			or roc.get_state() == Roc.State.GUST):
		var rx: int = roc.sim_pos.x
		var x: int = hero.sim_pos.x
		var dir: int = 1 if spot > x else -1
		var ahead: int = x + dir * 8
		if (ahead > rx - 53 - 4 and ahead < rx + 15 + 4) or (x > rx - 53 - 4 and x < rx + 15 + 4):
			note = "crawl under the perch"
			return Defs.IN_DOWN | key_of(dir)
	return move

# --- Phase 2 ------------------------------------------------------------------------------------------------------

func _dodge(hero: PlayerBase, roc: Roc) -> int:
	if _dodge_dir == 0:
		_dodge_dir = signi(roc._aim.x - roc.sim_pos.x)
		if _dodge_dir == 0:
			_dodge_dir = 1 if hero.sim_pos.x < MID_X else -1
	note = "dodge %d" % _dodge_dir
	return key_of(_dodge_dir)

func _buried(hero: PlayerBase, roc: Roc) -> int:
	var f: int = roc.facing
	var spot: int = roc.sim_pos.x + f * BURIED_DX
	note = "to the beak"
	if not hero.is_grounded():
		return 0
	if absi(hero.sim_pos.y - roc.sim_pos.y) > 4:
		return 0
	var move: int = go_to(hero, spot)
	if move >= 0:
		return move
	if hero.facing != -f:
		return key_of(-f)
	if hero.attack_gate:
		return 0
	if roc.hit_cooldown == 0 and roc.hp > roc.get_storm_hp() \
			and Overlap.rects(front_box(hero.sim_pos, -f), roc.get_head_rect()):
		note = "strike the beak"
		for i: int in STRIKE_TICKS - 2:
			plan.append(Defs.IN_FIRE)
		plan.append(0)
		return Defs.IN_FIRE
	return 0

## To feet x `x` on the floor (walking off the nest's nearer end first when he stands on it).
func _to_floor_spot(hero: PlayerBase, x: int, roc: Roc) -> int:
	if not hero.is_grounded():
		return 0
	if hero.sim_pos.y < FLOOR_Y:
		var off: int = NEST_X0 - 24 if absi(hero.sim_pos.x - NEST_X0) < absi(hero.sim_pos.x - NEST_X1) else NEST_X1 + 24
		if hero.sim_pos.y != NEST_TOP:
			off = x
		return key_of(1 if off > hero.sim_pos.x else -1)
	var move: int = _floor_walk(hero, x, roc)
	return move

# --- Phase 3 ------------------------------------------------------------------------------------------------------

func _storm(hero: PlayerBase, roc: Roc, level: LevelBase) -> int:
	var state: int = roc.get_state()
	if (hero.glide & 1) != 0:
		return _glide(hero, roc, level)
	_refill = false
	if not hero.is_grounded():
		note = "air"
		return 0
	if not hero.run.has_glider:
		_run = 0
		return _fetch_glider(hero, level)
	var half: int = roc._cruise_half
	if state == Roc.State.DESCEND or state == Roc.State.CRUISE or state == Roc.State.SWOOP_SCREECH:
		half = 1 if roc._cruise_x0 >= MID_X else 0
	var start: int = X_MAX if half == 1 else X_MIN
	var run_dir: int = -1 if half == 1 else 1
	if hero.sim_pos.y < FLOOR_Y:
		note = "off the nest"
		return _to_floor_spot(hero, bolt_safe(hero, level, start), null)
	if state == Roc.State.SWOOP:
		_run = 0
		note = "swoop dodge"
		var away: int = -1 if roc._aim.x >= roc.sim_pos.x else 1
		return key_of(-away)
	var cruising: bool = state == Roc.State.DESCEND or state == Roc.State.CRUISE
	if _run != 0 or (cruising and absi(hero.sim_pos.x - start) <= 4):
		_run = run_dir
		if (hero as Player).glider_runup >= Tuning.GLIDER_RUNUP_TICKS:
			note = "take off"
			_run = 0
			return Defs.IN_UP | key_of(run_dir)
		note = "run-up %d" % (hero as Player).glider_runup
		return key_of(run_dir)
	var safe: int = bolt_safe(hero, level, start)
	note = "wait at %d" % safe
	return maxi(go_to(hero, safe), 0)

## The glider lies on the nest's middle: under it on the floor, then straight up onto the nest.
func _fetch_glider(hero: PlayerBase, level: LevelBase) -> int:
	var glider_x: int = MID_X
	for entity: SimEntity in level.get_kind(Defs.Kind.COLLECTIBLE):
		var item: CollectibleBase = entity as CollectibleBase
		if item != null and item.item_id == &"items/glider" and not item.collected:
			glider_x = item.sim_pos.x
	var goal: int = bolt_safe(hero, level, glider_x)
	note = "fetch the glider at %d (goal %d)" % [glider_x, goal]
	if goal != glider_x:
		return maxi(go_to(hero, goal), 0)
	if hero.sim_pos.y >= FLOOR_Y:
		if absi(hero.sim_pos.x - glider_x) <= 3 and absi(hero.xvel) < 16:
			for i: int in JUMP_TICKS - 1:
				plan.append(Defs.IN_UP)
			return Defs.IN_UP
		return maxi(go_to(hero, glider_x), 0)
	return maxi(go_to(hero, glider_x), 0)

## The feet x a hero heading for `goal` may go to: a marked or striking bolt column (the burning sticks, for a hero
## on the nest) keeps him BOLT_CLEAR px away on his own side of it (the other side when a wall is too near); a hero
## beneath the struck floor is sheltered.
func bolt_safe(hero: PlayerBase, level: LevelBase, goal: int) -> int:
	for entity: SimEntity in level.get_kind(Defs.Kind.ENEMY_PROJECTILE):
		var bolt: BossBolt = entity as BossBolt
		if bolt == null or bolt.spent:
			continue
		if bolt.is_burning() and hero.sim_pos.y != bolt.strike_y:
			continue
		if hero.sim_pos.y > bolt.strike_y:
			continue
		var bx: int = bolt.sim_pos.x
		var side: int = 1 if hero.sim_pos.x >= bx else -1
		if bx + side * BOLT_CLEAR > X_MAX or bx + side * BOLT_CLEAR < X_MIN:
			side = -side
		if absi(goal - bx) < BOLT_CLEAR or signi(goal - bx) != side:
			goal = bx + side * BOLT_CLEAR
	return clampi(goal, X_MIN, X_MAX)

## Gliding: away from a marked bolt column within reach (the direction), else 0.
func bolt_steer(hero: PlayerBase, level: LevelBase) -> int:
	for entity: SimEntity in level.get_kind(Defs.Kind.ENEMY_PROJECTILE):
		var bolt: BossBolt = entity as BossBolt
		if bolt == null or bolt.spent or bolt.is_burning() or hero.sim_pos.y > bolt.strike_y:
			continue
		var dx: int = hero.sim_pos.x - bolt.sim_pos.x
		if absi(dx) < BOLT_CLEAR + 8:
			var away: int = 1 if dx >= 0 else -1
			if hero.sim_pos.x + away * BOLT_CLEAR > X_MAX or hero.sim_pos.x + away * BOLT_CLEAR < X_MIN:
				away = -away
			return away
	return 0

## Gliding: climb out of the run-up, turn to the Roc, refill the lift with a dive at speed while too low, climb
## again; above its back and where a dive meets it, dive.
func _glide(hero: PlayerBase, roc: Roc, level: LevelBase) -> int:
	var lift: int = (hero as Player).glider_lift
	var state: int = roc.get_state()
	if state != Roc.State.DESCEND and state != Roc.State.CRUISE and state != Roc.State.SWOOP_SCREECH:
		# No dive to make now (it tumbles, climbs, storms or swoops): down to the floor fast, clear of the bolts.
		_refill = false
		var steer: int = bolt_steer(hero, level)
		note = "land"
		return Defs.IN_DOWN | (key_of(steer) if steer != 0 else 0)
	var cx: int = roc.sim_pos.x
	var top: int = roc._cruise_y - Roc.BOX.y
	if roc.get_state() == Roc.State.CRUISE or roc.get_state() == Roc.State.SWOOP_SCREECH:
		top = roc.get_box().position.y
	else:
		cx = (roc._cruise_x0 + roc._cruise_x1) >> 1
	var x: int = hero.sim_pos.x
	var y: int = hero.sim_pos.y
	# The contact range of a landing on its back (Overlap.body: his feet x in (cx - 53, cx + 15)).
	var lo: int = cx - 53 + 4
	var hi: int = cx + 15 - 4
	var goal: int = clampi((lo + hi) >> 1, X_MIN, X_MAX)
	var toward: int = 1 if goal > x else -1
	var target_ready: bool = roc.get_state() == Roc.State.CRUISE or roc.get_state() == Roc.State.SWOOP_SCREECH
	if y < top - 2:
		# Above its back: dive when the fall meets it, else glide on towards it.
		var t: int = 0
		var v: int = hero.yvel
		var yy: int = y
		while yy < top + 6 and t < 40:
			v = mini(v + Tuning.GRAVITY, Tuning.TERMINAL)
			yy += Tuning.floor16(v)
			t += 1
		var land_x: int = x + Tuning.floor16(hero.xvel) * t
		if target_ready and land_x > lo and land_x < hi:
			note = "dive onto the back (t %d at %d)" % [t, land_x]
			return Defs.IN_DOWN | (key_of(toward) if absi(goal - land_x) > 8 else 0)
		if lift > 0 and y > 24 and absi(goal - x) > 60:
			note = "climb over"
			return Defs.IN_UP | key_of(toward)
		note = "glide over"
		return key_of(toward)
	# Below its back's top: climb while lift lasts, else dive at speed to refill it.
	if _refill:
		if lift >= REFILL_LIFT or y > FLOOR_Y - 40:
			_refill = false
		else:
			note = "refill %d" % lift
			return Defs.IN_DOWN | key_of(signi(hero.xvel) if hero.xvel != 0 else toward)
	if lift > 0:
		note = "climb %d" % lift
		var dir: int = signi(hero.xvel) if absi(hero.xvel) >= 64 else toward
		# Climbing out of the run-up away from it: keep the direction until the lift is spent.
		return Defs.IN_UP | key_of(dir)
	if signi(hero.xvel) != toward or absi(hero.xvel) < 64:
		note = "turn"
		return key_of(toward)
	if y < FLOOR_Y - 70:
		_refill = true
		note = "refill start"
		return Defs.IN_DOWN | key_of(toward)
	note = "too low"
	return key_of(toward)

# --- Helpers ------------------------------------------------------------------------------------------------------

static func key_of(dir: int) -> int:
	return Defs.IN_RIGHT if dir > 0 else Defs.IN_LEFT

## The flags that bring the hero to `spot` (braking in time), -1 when he stands there.
func go_to(hero: PlayerBase, spot: int) -> int:
	var x: int = hero.sim_pos.x
	var dx: int = spot - x
	var v: int = hero.xvel
	if absi(dx) <= 2 and absi(v) < 16:
		_last_x = x
		_stuck = 0
		return -1
	var key: int = Defs.IN_RIGHT if dx > 0 else Defs.IN_LEFT
	var back: int = Defs.IN_LEFT if dx > 0 else Defs.IN_RIGHT
	var brake: int = v * v / 384 + absi(v) / 32
	if signi(v) == signi(dx) and absi(dx) <= brake + 1:
		return back if not hero.is_grounded() else 0
	if absi(dx) <= 2:
		return back if not hero.is_grounded() else 0
	return key

## The high-front club box of a hero standing at `feet` facing `facing` (PHYSICS.md 8.2).
static func high_box(feet: Vector2i, facing: int) -> Rect2i:
	var rect: Rect2i = Tuning.CLUB_BOX[Tuning.ClubFrame.HIGH_FRONT]
	var origin: Vector2i = Tuning.CLUB_ORIGIN[Tuning.ClubFrame.HIGH_FRONT]
	var xo: int = origin.x - rect.position.x
	var ox: int = feet.x + facing * origin.x
	return Rect2i(ox - xo, feet.y + rect.position.y, rect.size.x, rect.size.y)

## The forward strike's front box (PHYSICS.md 8.2) of a hero at `feet` facing `facing`.
static func front_box(feet: Vector2i, facing: int) -> Rect2i:
	var rect: Rect2i = Tuning.CLUB_BOX[Tuning.ClubFrame.FWD_FRONT]
	var origin: Vector2i = Tuning.CLUB_ORIGIN[Tuning.ClubFrame.FWD_FRONT]
	var xo: int = origin.x - rect.position.x
	var ox: int = feet.x + facing * origin.x
	return Rect2i(ox - xo, feet.y + rect.position.y, rect.size.x, rect.size.y)


# =================================================================================================================
# The nest and phase 1
# =================================================================================================================
