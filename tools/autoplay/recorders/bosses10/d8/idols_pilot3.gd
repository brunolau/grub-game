extends RefCounted
## The Idols club pilot (enemies-C's IdolsClubPilot of tests/test_enemies_idols.gd, offset to the court of w8_l2b:
## 29 cells right, 5 rows down) with D8's additions: a stall breaker (rocks ignored after 120 ticks at home) and the
## co-op form - coop_flags() keeps one hero on his idol's half and reports when he could strike (-2).


const SPOT_DX: int = 74
const HOME_DX: int = 16          ## home: this far from the altar's middle (cols 8-11), away from the spitting idol
const ALTAR_MID: int = 160 + 29 * 16
const ALTAR_HALF: int = 26       ## the hero's feet stay this close to the altar's middle (its top: 128..192)
const DODGE_PX: int = 24         ## aside from a falling block (his box -15..+17 clears its 10 px)
const FLOOR_Y: int = 176 + 5 * 16
const SPIT_MARGIN: int = 34
const HIGH_TICKS: int = 9
const JUMP_TICKS: int = 8

var plan: Array[int] = []
var _home_ticks: int = 0
var _last_x: int = -100000
var _stuck: int = 0

func flags(hero: PlayerBase, idols: Idols, level: LevelBase) -> int:
	if not plan.is_empty() and not (block_over(hero, level) and not hero.attack_gate):
		return plan.pop_front()
	plan.clear()
	var idol: int = target(idols)
	var dir: int = 1 if idol == Idols.SUN else -1
	var toward: int = Defs.IN_RIGHT if dir > 0 else Defs.IN_LEFT
	var x: int = hero.sim_pos.x
	var jump: int = rock_jump(hero, level)
	if jump >= 0:
		return jump
	for entity: SimEntity in level.get_kind(Defs.Kind.ENEMY_PROJECTILE):
		# (A spent projectile stays listed until the frame ends - the Lab steps without frames.)
		var block: BossStalactite = entity as BossStalactite
		if block != null and not block.spent and absi(block.sim_pos.x - x) < DODGE_PX - 2 \
				and block.sim_pos.y < hero.sim_pos.y:
			# Aside by DODGE_PX (clear of its box), away from it - on the altar never off it (rocks roll below).
			var away: int = -1 if block.sim_pos.x >= x else 1
			var dest: int = block.sim_pos.x + away * DODGE_PX
			if hero.sim_pos.y < FLOOR_Y and absi(dest - ALTAR_MID) > ALTAR_HALF:
				dest = block.sim_pos.x - away * DODGE_PX
			var dodge: int = go_to(hero, dest)
			return dodge if dodge >= 0 else 0
	var spot: int = idols.get_idol_pos(idol).x - dir * SPOT_DX
	var at_spot: bool = absi(x - spot) <= 12 and hero.sim_pos.y >= FLOOR_Y
	# At the spot he stays (a spat rock leaves over his head; one that comes back is jumped); the way out from the
	# altar is taken only with no rock about and no spit due before he gets there; a rage sends him home.
	var travel: int = absi(x - spot) / 4 + SPIT_MARGIN / 2
	var rocks: bool = rock_alive(level) and _home_ticks < 120
	var danger: bool = idols._rage_due or idols.get_state() == Idols.State.RAGE \
			or (not at_spot and (rocks or release_in(idols) <= travel))
	if danger and not at_spot:
		_home_ticks += 1
	else:
		_home_ticks = 0
	var goal: int = ALTAR_MID - dir * HOME_DX if danger else spot
	var move: int = go_to(hero, goal)
	if move >= 0:
		return move
	if danger or not hero.is_grounded() or hero.attack_gate:
		return 0
	if hero.facing != dir:
		return toward
	if idols.is_open(idol) and idols._cooldown[idol] == 0 \
			and Overlap.rects(high_box(hero.sim_pos, dir), idols.get_head_rect(idol)):
		for i: int in HIGH_TICKS - 1:
			plan.append(Defs.IN_UP | Defs.IN_FIRE)
		plan.append(0)
		return Defs.IN_UP | Defs.IN_FIRE
	return 0

## True while a masonry block hangs or falls within reach over him.
static func block_over(hero: PlayerBase, level: LevelBase) -> bool:
	for entity: SimEntity in level.get_kind(Defs.Kind.ENEMY_PROJECTILE):
		var block: BossStalactite = entity as BossStalactite
		if block != null and not block.spent and absi(block.sim_pos.x - hero.sim_pos.x) < DODGE_PX - 2 \
				and block.sim_pos.y < hero.sim_pos.y:
			return true
	return false

## True while a spat rock is still about (flying, hopping or rolling out).
static func rock_alive(level: LevelBase) -> bool:
	for entity: SimEntity in level.get_kind(Defs.Kind.ENEMY_PROJECTILE):
		var rock: BossRock = entity as BossRock
		if rock != null and not rock.spent:
			return true
	return false

## Ticks until the next rock leaves the jaws (the shared loop of idols.gd: idle pauses, then LOOP's steps).
static func release_in(idols: Idols) -> int:
	var step: int = idols._step
	var t: int = 0
	match idols.get_state():
		Idols.State.SPIT:
			if idols._timer < EnemyTuning.COLOSSUS_SPIT_RELEASE_TICK:
				return EnemyTuning.COLOSSUS_SPIT_RELEASE_TICK - idols._timer
			t = EnemyTuning.COLOSSUS_SPIT_TICKS - idols._timer
			step = (step + 1) % Idols.LOOP.size()
		Idols.State.SLAM:
			t = EnemyTuning.COLOSSUS_SLAM_TICKS - idols._timer
			step = (step + 1) % Idols.LOOP.size()
		Idols.State.IDLE:
			t = idols._idle_length() - idols._clock
			if Idols.LOOP[step] == Idols.Attack.SPIT:
				return t + EnemyTuning.COLOSSUS_SPIT_RELEASE_TICK
			t += EnemyTuning.COLOSSUS_SLAM_TICKS
			step = (step + 1) % Idols.LOOP.size()
		_:
			return 0
	for i: int in Idols.LOOP.size():
		t += EnemyTuning.COLOSSUS_IDLE_TICKS[step] * 50 / 100
		if Idols.LOOP[step] == Idols.Attack.SPIT:
			return t + EnemyTuning.COLOSSUS_SPIT_RELEASE_TICK
		t += EnemyTuning.COLOSSUS_SLAM_TICKS
		step = (step + 1) % Idols.LOOP.size()
	return t

## A rock rolling or hopping at him low (one that came back off the altar's face, or a fresh one across the court):
## jump it in time (JUMP_TICKS of Up with his current direction); -1 when none is coming.
func rock_jump(hero: PlayerBase, level: LevelBase) -> int:
	if not hero.is_grounded() or hero.attack_gate:
		return -1
	var x: int = hero.sim_pos.x
	for entity: SimEntity in level.get_kind(Defs.Kind.ENEMY_PROJECTILE):
		var rock: BossRock = entity as BossRock
		if rock == null or rock.spent or rock.sim_pos.y < hero.sim_pos.y - 30 or rock.sim_pos.y > hero.sim_pos.y + 4:
			continue
		if hero.sim_pos.y < FLOOR_Y and absi(rock.sim_pos.x - ALTAR_MID) > 37:
			continue  # on the altar: a rock beside it never reaches him
		var gap: int = rock.sim_pos.x - x
		var closing: int = -signi(gap) * (rock.xvel - hero.xvel)
		if closing <= 0 or absi(gap) > 28 + closing * 6 / 16 or absi(gap) < 4:
			continue
		var key: int = hero.input_flags & (Defs.IN_LEFT | Defs.IN_RIGHT)
		for i: int in JUMP_TICKS - 1:
			plan.append(Defs.IN_UP | key)
		return Defs.IN_UP | key
	return -1

## The flags that bring the hero to `spot` (braking in time: no friction in the air, so he steers back there), -1
## when he stands there. A wall face in the way (the altar) is jumped: JUMP_TICKS of Up with the direction.
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
	if hero.is_grounded() and x == _last_x:
		_stuck += 1
	else:
		_stuck = 0
	_last_x = x
	if _stuck >= 2:
		_stuck = 0
		for i: int in JUMP_TICKS - 1:
			plan.append(Defs.IN_UP | key)
		return Defs.IN_UP | key
	return key

## The idol to strike: the awake one (solo), the survivor when one broke.
static func target(idols: Idols) -> int:
	if idols.get_role(Idols.SUN) == Idols.Role.BROKEN:
		return Idols.MOON
	if idols.get_role(Idols.MOON) == Idols.Role.BROKEN:
		return Idols.SUN
	return Idols.SUN if idols.get_role(Idols.SUN) == Idols.Role.AWAKE else Idols.MOON

## The high-front club box of a hero standing at `feet` facing `facing` (PHYSICS.md 8.2).
static func high_box(feet: Vector2i, facing: int) -> Rect2i:
	var rect: Rect2i = Tuning.CLUB_BOX[Tuning.ClubFrame.HIGH_FRONT]
	var origin: Vector2i = Tuning.CLUB_ORIGIN[Tuning.ClubFrame.HIGH_FRONT]
	var xo: int = origin.x - rect.position.x
	var ox: int = feet.x + facing * origin.x
	return Rect2i(ox - xo, feet.y + rect.position.y, rect.size.x, rect.size.y)

## Co-op: this hero holds the half of `idol` (Idols.MOON / SUN). Returns the flags, or -2 when he stands at his
## strike spot ready to strike the open jaws (the duo coordinator starts both strikes on the same tick).
var _quiet: int = 0


func coop_flags(hero: PlayerBase, idols: Idols, level: LevelBase, idol: int) -> int:
	var f: int = _coop_flags(hero, idols, level, idol)
	if f > 0:
		_quiet = 0
	else:
		_quiet += 1
		if _quiet > 200 and f == 0 and hero.is_grounded() and not hero.attack_gate:
			_quiet = 0
			return Defs.IN_DOWN
	return f


func start_strike() -> int:
	_quiet = 0
	for i: int in HIGH_TICKS - 1:
		plan.append(Defs.IN_UP | Defs.IN_FIRE)
	plan.append(0)
	return Defs.IN_UP | Defs.IN_FIRE


func _coop_flags(hero: PlayerBase, idols: Idols, level: LevelBase, idol: int) -> int:
	if not plan.is_empty() and not (block_over(hero, level) and not hero.attack_gate):
		return plan.pop_front()
	plan.clear()
	var dir: int = 1 if idol == Idols.SUN else -1
	var toward: int = Defs.IN_RIGHT if dir > 0 else Defs.IN_LEFT
	var x: int = hero.sim_pos.x
	var jump: int = rock_jump(hero, level)
	if jump >= 0:
		return jump
	for entity: SimEntity in level.get_kind(Defs.Kind.ENEMY_PROJECTILE):
		var block: BossStalactite = entity as BossStalactite
		if block != null and not block.spent and absi(block.sim_pos.x - x) < DODGE_PX - 2 				and block.sim_pos.y < hero.sim_pos.y:
			var away: int = -1 if block.sim_pos.x >= x else 1
			var dest: int = block.sim_pos.x + away * DODGE_PX
			if hero.sim_pos.y < FLOOR_Y and absi(dest - ALTAR_MID) > ALTAR_HALF:
				dest = block.sim_pos.x - away * DODGE_PX
			if (dest - ALTAR_MID) * dir < 4:
				dest = ALTAR_MID + dir * 6
			var dodge: int = go_to(hero, dest)
			return dodge if dodge >= 0 else 0
	var spot: int = idols.get_idol_pos(idol).x - dir * SPOT_DX
	var danger: bool = idols.get_state() == Idols.State.RAGE
	var move: int = go_to(hero, spot)
	if move >= 0:
		return move
	if danger or not hero.is_grounded() or hero.attack_gate:
		return 0
	if hero.facing != dir:
		return toward
	if rock_near(hero, level):
		return 0
	if idols.jaws_open(idol) and idols._cooldown[idol] == 0 			and Overlap.rects(high_box(hero.sim_pos, dir), idols.get_head_rect(idol)):
		return -2
	return 0


## wf10 (bosses): a live rock on the hero's level within 72 px that still closes on him - no jump strike now (the co-op
## jaws open as the spat rocks arrive; striking into one cost a heart each time).
func rock_near(hero: PlayerBase, level: LevelBase) -> bool:
	for entity: SimEntity in level.get_kind(Defs.Kind.ENEMY_PROJECTILE):
		var rock: BossRock = entity as BossRock
		if rock == null or rock.spent or rock.sim_pos.y < hero.sim_pos.y - 90:
			continue
		if absi(rock.sim_pos.x - hero.sim_pos.x) < 60:
			return true
	return false
