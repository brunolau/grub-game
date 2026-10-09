class_name Mount
extends SimEntity
## `objects/mount` (`kind=rex`, `pen=<name>`, `wild`): Chomper, the rex you ride (DESIGN.md C.8, PHYSICS.md C.9,
## GAMEPLAY.md 13.4). Stage-local: a mount never travels between stages.
##
## - **Mounting**: a hero (alive, hatched, not hurt, yvel >= 0, not gliding, curled or already seated, his remount lock
##   run out) whose stomp test (Overlap.body + stomp flag, the hero against the mount box) succeeds on a tame, present
##   mount sits down: driver when that seat is free, else the gunner (co-op only). PlayerBase.sit_on_mount.
## - **Driving** (PLATFORMS, after the platforms; the driver's flags of this tick, GameInput.get_flags(slot)): ground:
##   LEFT / RIGHT ACCEL(64) with facing, none FRICTION; UP while grounded with no_jump == 0 hops (yvel -160, one
##   impulse); integrate x (commit rule; co-op edge walls), then y; tile collision on its feet point with a wall probe
##   20 px ahead (rows row - 1 and row - 2) and a head probe 4 rows up ridden / 3 unridden; floor spikes `^` count as
##   floor, tar `:` has no slowing effect, every landing is soft; airborne: ACCEL(64) while a direction is held, then
##   gravity; falling arms no_jump = 6. Deadly tiles, `~`, pits: every rider dies (an egg in co-op) and the mount bolts.
##   The riders are then placed: driver (x, y - 26), gunner (x - 14 * facing, y - 26).
## - **Dismount**: DOWN + UP (either seat): launch(0, -128) from the seat, remount lock 22 ticks for that hero. A
##   driver leaving hands the reins to the gunner.
## - **Bite**: the driver's FIRE runs an 8-tick bite (FIRE held repeats every 8); its box (x 0..+40, y -35..-6 from the
##   feet, mirrored) is made on bite ticks 5-6 and tested in the next tick's WEAPONS phase like a club box: the first
##   enemy (weapon test) is **eaten** when hp < 50 (its score plus the food bonus, no death arc) or takes 25; else the
##   first hittable (hidden-tile test); one target per bite (a bite that found its target makes no second box).
##   Bosses ignore bites.
## - **A hit** on the ridden mount (an enemy's body against the ridden box that is not the mount's stomp, tested here in
##   CONTACT_ENEMIES before the heroes' own pass; an enemy projectile, a hazard or a boss body reach the riders, whose
##   HeroMount.on_hurt calls [method rider_hit]): every rider is thrown off (xvel +/-64 away, yvel -128, hit_timer 44,
##   no heart lost) and the mount **bolts**: gone for 132 ticks, then waits tame in its pen. Its feet landing on an
##   enemy with the stomp flag: yvel -64, the enemy unharmed.
## - **Wild** (`wild`): paces +/-3 cells from home at 16 v16; its contact hurts (10.1); weapons glance (pass); a stomp
##   bounces the hero (-224 with UP, else -64) and counts: 3 bounces by one hero with no grounded tick and no hurt in
##   between tame it (it sits and waits).
## - A level reset (death, team wipe) and the stage start put the mount in its pen (its spawn point when it has none),
##   tame if it ever was; a wild rex never tamed stays wild where the level placed it. It dozes only unridden, still
##   and tame at home.
## - **Arena (Mesa Rodeo**, DESIGN.md E.5, GAMEPLAY.md 13.10.9; a `kind = arena` level): Chomper starts **penned** -
##   standing in his pen, nobody can sit on him. He leaves it on every VersusTuning.RODEO_CHOMPER_PERIOD_TICKS of the
##   round clock (the referee's `round_ticks` when the level's party driver has it, else his own tick count), after a
##   RODEO_RUMBLE_TICKS rumble (his picture shakes, the quake cue; [method is_rumbling]; no screen shake, which would
##   nudge the heroes) and a growl as he comes out; free, he waits at his pen for a
##   rider. His rider's bite also bites rival heroes (no teammate): the referee's `bite_hit(driver, victim, mount)`
##   when it has one, else the versus knock-back (Defs.HurtKind.RIVAL, the run's energy untouched) and, in Grub Stack,
##   the referee's `spill(victim, RODEO_BITE_SPILL, true)`. A rival landing on the rider's head (the stomp test, the
##   rider neither immune nor shielded) **unseats** him: he is thrown off (xvel +/-64 away, yvel -128, no stun) and
##   Chomper stays out for the next rider; the referee's own stomp rules apply to the stomp as usual (without a referee
##   the stomper bounces here). A hit on a rider (rider_hit) makes him bolt as everywhere; back home he is penned
##   again until the next release. A round clock that goes back (the referee's begin_round on the same level) is a
##   new round: his riders are put off and he is back in his pen, penned, as at a level start. In an arena he never
##   dozes.
##
## Owner: objects-B (docs/expansion/PLAN.md 4.1). The rider's side (no own handler for the driver, the gunner's strikes
## and swap, routing a rider's hurt to [method rider_hit]) is player-B's HeroMount (scripts/player/hero_mount.gd).
## The numbers are the C.9 table in MountTuning (player-B, scripts/player/mount_tuning.gd); the names below are
## aliases kept for readability and for the tests. One deliberate order: on the hop tick the ground x rule does not run
## (the hop is that tick's handler), so a hop from rest with a direction held covers 74 px and a full-speed hop 84 px,
## as PHYSICS.md C.9 and docs/spec/PARTY_REFERENCE.json ("mount") state. Marks: [P C.9] PHYSICS.md, [own] this module.

# --- PHYSICS.md C.9 (MountTuning) -------------------------------------------------------------------------------------
const WALK_CAP: int = MountTuning.WALK_CAP
const ACCEL: int = MountTuning.ACCEL
const FRICTION: int = MountTuning.FRICTION
const HOP: int = MountTuning.HOP
const SADDLE_PX: int = MountTuning.SADDLE_PX
const GUNNER_BEHIND_PX: int = MountTuning.GUNNER_BEHIND_PX
const WALL_PROBE: int = MountTuning.WALL_PROBE
const HEAD_PROBE_ROWS_RIDDEN: int = MountTuning.HEAD_PROBE_ROWS_RIDDEN
const HEAD_PROBE_ROWS_UNRIDDEN: int = MountTuning.HEAD_PROBE_ROWS_UNRIDDEN
const BITE_TICKS: int = MountTuning.BITE_TICKS
const BITE_LIVE_FIRST: int = MountTuning.BITE_LIVE_FIRST
const BITE_LIVE_LAST: int = MountTuning.BITE_LIVE_LAST
const BITE_BOX: Rect2i = MountTuning.BITE_BOX
const EAT_HP: int = MountTuning.EAT_HP
const FOOD_BONUS: int = MountTuning.FOOD_BONUS
const BITE_POWER: int = MountTuning.BITE_POWER
const BOLT_TICKS: int = MountTuning.BOLT_TICKS
const REMOUNT_LOCK: int = MountTuning.REMOUNT_LOCK
const TAME_BOUNCES: int = MountTuning.TAME_BOUNCES
const BOX: Vector3i = MountTuning.BOX
const RIDDEN_BOX: Vector3i = MountTuning.RIDDEN_BOX
const WILD_PACE_CELLS: int = MountTuning.WILD_PACE_CELLS
const WILD_PACE_V16: int = MountTuning.WILD_PACE_V16
const DISMOUNT_YVEL: int = MountTuning.DISMOUNT_YVEL
const STOMP_YVEL: int = MountTuning.STOMP_YVEL
const RIDER_HIT_XVEL: int = MountTuning.HIT_XVEL
const RIDER_HIT_YVEL: int = MountTuning.HIT_YVEL

# --- Picture: sprites/enemies/rex.png (8 x 3 cells of 152 x 112 art px, pivot (76, 96), faces right) -----------------
const FRAME_IDLE: Vector2i = Vector2i(0, 6)     ## first frame, count
const FRAME_WALK: Vector2i = Vector2i(6, 8)
const FRAME_BITE: Vector2i = Vector2i(14, 5)
const FRAME_HIT: Vector2i = Vector2i(19, 2)
const IDLE_FPS: int = 8
const WALK_FPS: int = 12

## Species (only `rex`).
var kind: String = "rex"
## Name of its pen (`pen=`).
var pen_name: StringName = &""
## True while it is a wild rex that has not been tamed.
var wild: bool = false
## True once tame (placed tame, or tamed by three bounces).
var tame: bool = true
## False while it bolted (gone for BOLT_TICKS).
var present: bool = true
## The hero driving / riding behind (null = seat free).
var driver: PlayerBase = null
var gunner: PlayerBase = null
## True when its feet stood on a floor after the last tick's collision.
var grounded: bool = true
## Hop lock-out (as the hero's).
var no_jump: int = 0
## Tick of the running bite script (1..BITE_TICKS; 0 = not biting).
var bite_tick: int = 0
## Ticks until it is back in its pen after bolting.
var bolt_left: int = 0
## Unbroken head bounces of [member _tamer] (a wild rex).
var tame_count: int = 0
## Enemies eaten / bitten (statistics, tests).
var eaten: int = 0
var bites_landed: int = 0
## Arena (Mesa Rodeo): true in a `kind = arena` level; [member penned] while he waits shut in his pen.
var arena: bool = false
var penned: bool = false
## Arena: rival heroes bitten, riders unseated by a stomp (statistics, tests).
var bites_on_rivals: int = 0
var stomp_unseats: int = 0

## Arena: his own clock (ticks since the level started; used without a referee), the round clock of the last release
## and of the last rumble cue, and the rumble of this tick.
var _pen_ticks: int = 0
var _release_clock: int = -1
var _rumble_clock: int = -1
var _rumbling: bool = false
## Arena: the referee's round clock at the last pen step (-1 = none yet, or no referee); a smaller one is a new round.
var _seen_clock: int = -1

var _tamer: PlayerBase = null
var _home: Vector2i = Vector2i.ZERO
var _pace_dir: int = 1
var _bite_box_active: bool = false
var _bite_box: Rect2i = Rect2i()
## True once the running bite found its target: one target per bite, like a consumed club box.
var _bite_spent: bool = false
var _remount_until: PackedInt32Array = PackedInt32Array()
## wf11 R3 (co-op wards only; empty everywhere else): the enemies whose heads gave the ridden mount nothing - it came
## down on each inside a ward - until their boxes part ([method _ridden_contacts]).
var _ward_heads: Array[EnemyBase] = []
## Phase 4 ruling Q4 (DESIGN.md G87): the clock of each head of [member _ward_heads] (same index;
## PlayerBase.ward_grace_step) - the pass ends PartyTuning.WARD_GRACE_TICKS ticks after the mount has ground again.
var _ward_since: PackedInt32Array = PackedInt32Array()
var _anim_age: int = 0
var _sprite: Sprite2D = null
var _saddle: Sprite2D = null


func _init() -> void:
	z_index = Defs.Z_ENEMIES
	set_box(BOX)
	_remount_until.resize(Defs.MAX_PLAYERS)
	_remount_until.fill(-1)


func _ready() -> void:
	_sprite = get_node_or_null(^"Sprite") as Sprite2D
	_saddle = get_node_or_null(^"Saddle") as Sprite2D
	_resolve_home()
	arena = Mount.is_arena_level(Game.level)
	penned = arena and tame
	if penned:
		teleport(_home)  # a round starts with Chomper shut in his pen
	_refresh_visual()


## True for a versus arena (`kind = arena`): Chomper keeps the pen timer of Mesa Rodeo there.
static func is_arena_level(level: LevelBase) -> bool:
	return level != null and str(level.meta.get("kind", "")) == LevelText.KIND_ARENA


func _sim_phases() -> PackedInt32Array:
	return PackedInt32Array([Defs.Phase.WEAPONS, Defs.Phase.PLATFORMS, Defs.Phase.CONTACT_ENEMIES])


func _apply_params(params: Dictionary) -> void:
	kind = str(params.get("kind", kind))
	pen_name = StringName(str(params.get("pen", "")))
	wild = param_bool("wild", false)
	tame = not wild
	_home = sim_pos


## Home = its pen's feet point when the pen exists, else where the level placed it.
func _resolve_home() -> void:
	var pen: RexPen = RexPen.find(Game.level, pen_name)
	if pen != null:
		_home = pen.sim_pos


# --- Queries ----------------------------------------------------------------------------------------------------------

## True while a hero sits on it.
func is_ridden() -> bool:
	return driver != null or gunner != null


## True while the bite script runs.
func is_biting() -> bool:
	return bite_tick > 0


## Where it waits tame (its pen).
func get_home() -> Vector2i:
	return _home


## True while `hero` may not sit down again (remount lock after leaving the saddle).
func is_remount_locked(hero: PlayerBase) -> bool:
	return Sim.total_ticks < _remount_until[hero.slot]


## Arena: true while he waits shut in his pen (nobody can sit on him).
func is_penned() -> bool:
	return penned


## Arena: true during the RODEO_RUMBLE_TICKS before he leaves his pen (the telegraph).
func is_rumbling() -> bool:
	return _rumbling


## Arena: ticks of the round clock until he leaves his pen (0 = free now; -1 outside an arena or while he is away).
func ticks_to_release(level: LevelBase = Game.level) -> int:
	if not arena or not present:
		return -1
	if not penned:
		return 0
	var period: int = VersusTuning.RODEO_CHOMPER_PERIOD_TICKS
	return period - posmod(arena_clock(level), period)


## Arena: the round clock of the pen: the referee's `round_ticks` (the level's party driver) when it has one, else
## his own count of ticks since the level started.
func arena_clock(level: LevelBase) -> int:
	if _has_round_clock(level):
		return int(level.party_driver.get(&"round_ticks"))
	return _pen_ticks


## True when the level's party driver (the referee) keeps a round clock (`round_ticks`).
static func _has_round_clock(level: LevelBase) -> bool:
	var referee: SimEntity = level.party_driver if level != null else null
	return referee != null and &"round_ticks" in referee


## Arena: out of the pen now (the referee may call it too).
func release() -> void:
	if not penned:
		return
	penned = false
	_rumbling = false
	_doze_wake_now()
	ObjTuning.play_cue(Sfx.CHOMPER_BITE, Sfx.FEAST_CHOMP)
	_refresh_visual()


# --- Calls ------------------------------------------------------------------------------------------------------------

## A seated rider was hurt (HeroMount.on_hurt, PHYSICS.md C.9): every rider is thrown off away from `source`
## (xvel +/-64, yvel -128, hit_timer 44, no heart lost) and the mount bolts.
func rider_hit(source: SimEntity) -> void:
	for hero: PlayerBase in [driver, gunner]:
		if hero == null:
			continue
		_unseat(hero)
		var away: int = -1 if source != null and source.sim_pos.x > hero.sim_pos.x else 1
		hero.xvel = RIDER_HIT_XVEL * away
		hero.yvel = RIDER_HIT_YVEL
		hero.hit_timer = MountTuning.HIT_TIMER
		hero.attack_gate = false
		hero.grounded = false
		hero.on_platform = false
	Audio.play_sfx(Sfx.PLAYER_HURT)
	bolt()


## Vanish for BOLT_TICKS, then wait tame in the pen (also after the riders died on a deadly tile).
func bolt() -> void:
	for hero: PlayerBase in [driver, gunner]:
		if hero != null:
			_unseat(hero)
	_doze_wake_now()
	present = false
	bolt_left = BOLT_TICKS
	bite_tick = 0
	_bite_box_active = false
	xvel = 0
	yvel = 0
	visible = false
	set_box(BOX)


## Seat `hero` (driver when free, else gunner when `allow_gunner`). False when no seat is free (or he is penned).
func seat(hero: PlayerBase, allow_gunner: bool = true) -> bool:
	if hero == null or hero.is_mounted() or penned:
		return false
	var seat_kind: int = PlayerBase.SEAT_DRIVER
	if driver == null:
		driver = hero
	elif gunner == null and allow_gunner:
		gunner = hero
		seat_kind = PlayerBase.SEAT_GUNNER
	else:
		return false
	_doze_wake_now()
	hero.sit_on_mount(self, seat_kind)
	hero.xvel = 0
	set_box(RIDDEN_BOX)
	_place_riders()
	return true


## `hero` leaves his seat with the dismount launch (DOWN + UP).
func dismount(hero: PlayerBase) -> void:
	if hero == null or (hero != driver and hero != gunner):
		return
	_unseat(hero)
	hero.launch(0, DISMOUNT_YVEL)


func _unseat(hero: PlayerBase) -> void:
	if hero == driver:
		driver = gunner
		gunner = null
		if driver != null:
			driver.mount_seat = PlayerBase.SEAT_DRIVER
	elif hero == gunner:
		gunner = null
	if hero.mount == self:
		hero.leave_mount()
	_remount_until[hero.slot] = Sim.total_ticks + REMOUNT_LOCK
	if not is_ridden():
		set_box(BOX)
		bite_tick = 0


# --- Simulation -------------------------------------------------------------------------------------------------------

func _sim_tick(phase: int) -> void:
	var level: LevelBase = Game.level
	if level == null:
		return
	match phase:
		Defs.Phase.WEAPONS:
			_bite_pass(level)
		Defs.Phase.PLATFORMS:
			_update(level)
		Defs.Phase.CONTACT_ENEMIES:
			_contacts(level)


func _update(level: LevelBase) -> void:
	if arena:
		_pen_step(level)
	if not present:
		bolt_left -= 1
		if bolt_left <= 0:
			_return_home()
		return
	if penned:
		_anim_age += 1
		_refresh_visual()
		return
	_check_seats()
	_dismounts()
	var flags: int = 0
	if driver != null:
		flags = GameInput.get_flags(driver.slot) if driver.control_enabled else 0
		var left: bool = (flags & Defs.IN_LEFT) != 0
		var right: bool = (flags & Defs.IN_RIGHT) != 0
		if right and not left:
			facing = 1
		elif left and not right:
			facing = -1
		_bite_step(flags)
	elif wild and not tame:
		flags = _pace_flags()
	if not _physics(level, flags):
		return
	_place_riders()
	_make_bite_box()
	_anim_age += 1
	_refresh_visual()


## Arena: the pen clock - the rumble over the last RODEO_RUMBLE_TICKS of every period, the release on each multiple of
## RODEO_CHOMPER_PERIOD_TICKS (once per clock value; only while he waits penned at home).
func _pen_step(level: LevelBase) -> void:
	_pen_ticks += 1
	var clock: int = arena_clock(level)
	var referee_clock: int = clock if _has_round_clock(level) else -1
	if referee_clock >= 0 and referee_clock < _seen_clock:
		# A new round on the same level: riders off, back in the pen (_return_home pens him), the timer starts over.
		_on_level_reset()
		_release_clock = -1
		_rumble_clock = -1
	_seen_clock = referee_clock
	var period: int = VersusTuning.RODEO_CHOMPER_PERIOD_TICKS
	var into: int = posmod(clock, period)
	var waiting: bool = penned and present and clock > 0
	var was_rumbling: bool = _rumbling
	_rumbling = waiting and into >= period - VersusTuning.RODEO_RUMBLE_TICKS
	if _rumbling and not was_rumbling and clock != _rumble_clock:
		_rumble_clock = clock
		ObjTuning.play_cue(Sfx.QUAKE)
	if waiting and into == 0 and clock != _release_clock:
		_release_clock = clock
		release()


## Seats whose hero left on his own (respawn, egg, death) are freed.
func _check_seats() -> void:
	if driver != null and not is_instance_valid(driver):
		driver = null
	if gunner != null and not is_instance_valid(gunner):
		gunner = null
	for hero: PlayerBase in [driver, gunner]:
		if hero != null and (hero.mount != self or hero.dead or hero.is_down()):
			_unseat(hero)


func _dismounts() -> void:
	for hero: PlayerBase in [driver, gunner]:
		if hero == null or not hero.control_enabled:
			continue
		var flags: int = GameInput.get_flags(hero.slot)
		if (flags & Defs.IN_DOWN) != 0 and (flags & Defs.IN_UP) != 0:
			dismount(hero)


## The driver's FIRE: start or advance the 8-tick bite (FIRE held repeats every 8).
func _bite_step(flags: int) -> void:
	if bite_tick > 0:
		bite_tick += 1
		if bite_tick > BITE_TICKS:
			bite_tick = 0
	if bite_tick == 0 and (flags & Defs.IN_FIRE) != 0:
		bite_tick = 1
		_bite_spent = false
		Audio.play_sfx(Sfx.CHOMPER_BITE if AudioTable.SFX.has(Sfx.CHOMPER_BITE) else Sfx.FEAST_CHOMP)


func _make_bite_box() -> void:
	var live: bool = bite_tick >= BITE_LIVE_FIRST and bite_tick <= BITE_LIVE_LAST
	_bite_box_active = driver != null and not _bite_spent and live
	if not _bite_box_active:
		return
	var left: int = sim_pos.x + BITE_BOX.position.x if facing > 0 else sim_pos.x - BITE_BOX.end.x
	_bite_box = Rect2i(left, sim_pos.y + BITE_BOX.position.y, BITE_BOX.size.x, BITE_BOX.size.y)


## WEAPONS: the bite box of the previous tick against enemies (eat or 25), then hittables; one target.
func _bite_pass(level: LevelBase) -> void:
	if not _bite_box_active:
		return
	_bite_box_active = false
	if driver == null or not present:
		return
	var box: Rect2i = _bite_box
	var enemies: Array[SimEntity] = level.get_kind(Defs.Kind.ENEMY)
	for i: int in enemies.size():
		var enemy: EnemyBase = enemies[i] as EnemyBase
		if enemy == null or not enemy.awake or not enemy.is_targetable():
			continue
		if not Overlap.weapon(box, box.size.x / 2, enemy):
			continue
		if enemy.hp < EAT_HP and enemy.accepts_hit_from(driver):
			_bite_spent = true
			_eat(level, enemy)
			return
		if enemy.take_hit(BITE_POWER, driver):
			_bite_spent = true
			bites_landed += 1
			return
	if arena:
		# Mesa Rodeo: the bite bites rival heroes (no teammate, not his own riders).
		for hero: PlayerBase in level.contact_order():
			if hero == driver or hero.mount == self or hero.dead or hero.is_down() or _teammates(level, driver, hero):
				continue
			if Overlap.weapon(box, box.size.x / 2, hero) and _bite_rival(level, hero):
				_bite_spent = true
				return
	var origin: Vector2i = Vector2i(box.position.x + box.size.x / 2, box.end.y)
	var hittables: Array[SimEntity] = level.get_kind(Defs.Kind.HITTABLE)
	for i: int in hittables.size():
		var hittable: HittableBase = hittables[i] as HittableBase
		if hittable != null and hittable.is_hit_by(origin) and hittable.take_hit(BITE_POWER, driver):
			_bite_spent = true
			bites_landed += 1
			return


## Arena: the bite on a rival hero. The referee's `bite_hit(driver, victim, mount) -> bool` when the level's party
## driver has it (its currency and knock-back rules); else the versus knock-back (Defs.HurtKind.RIVAL; the run's
## hearts, bones and glider are put back: the currency is the referee's) and, in Grub Stack, the referee's
## `spill(victim, RODEO_BITE_SPILL, true)`. False when the bite did not land (immune, shielded).
func _bite_rival(level: LevelBase, victim: PlayerBase) -> bool:
	var referee: SimEntity = level.party_driver
	if referee != null and referee.has_method(&"bite_hit"):
		if not bool(referee.call(&"bite_hit", driver, victim, self)):
			return false
		bites_on_rivals += 1
		return true
	if victim.is_immune() or victim.shield > 0:
		return false
	var run: PlayerRun = victim.run
	var hearts: int = run.hearts
	var bones: int = run.bones
	var glider: bool = run.has_glider
	if run.hearts < 2:
		run.hearts = 2  # the 1.0 hurt path must never kill: the bite's currency is the referee's
	var applied: bool = victim.hurt(self, Defs.HurtKind.RIVAL)
	run.hearts = hearts
	run.bones = bones
	if run.has_glider != glider:
		run.set_glider(glider)
	run.emit_energy()
	if not applied:
		return false
	if referee != null and referee.has_method(&"spill") and &"mode" in referee \
			and int(referee.get(&"mode")) == Defs.VersusMode.GRUB_STACK:
		referee.call(&"spill", victim, VersusTuning.RODEO_BITE_SPILL, true)
	bites_on_rivals += 1
	return true


## Arena: true when `a` and `b` play in the same 2v2 team (the referee's team_of; free for all without one).
static func _teammates(level: LevelBase, a: PlayerBase, b: PlayerBase) -> bool:
	var referee: SimEntity = level.party_driver if level != null else null
	if a == null or b == null or referee == null or not referee.has_method(&"team_of"):
		return false
	var team: int = int(referee.call(&"team_of", a.slot))
	return team >= 0 and team == int(referee.call(&"team_of", b.slot))


func _eat(level: LevelBase, enemy: EnemyBase) -> void:
	eaten += 1
	enemy.last_hit_slot = driver.slot
	enemy.last_hit_tick = Sim.total_ticks
	# "Eaten enemies vanish into the jaws (no death arc)": the feast death pays its score and leaves no corpse.
	enemy.kill(&"feast", driver)
	Game.add_score(FOOD_BONUS)
	Events.popup_requested.emit(&"score", FOOD_BONUS, Vector2i(enemy.sim_pos.x, enemy.sim_pos.y - enemy.box_h))
	level.spawn_fx(&"fx/star_puff", Vector2i(enemy.sim_pos.x, enemy.sim_pos.y - (enemy.box_h >> 1)))


## A wild rex's virtual flags: pace towards the end of its range, turn there.
func _pace_flags() -> int:
	var reach: int = WILD_PACE_CELLS * Tuning.TILE
	if sim_pos.x >= _home.x + reach:
		_pace_dir = -1
	elif sim_pos.x <= _home.x - reach:
		_pace_dir = 1
	facing = _pace_dir
	return Defs.IN_RIGHT if _pace_dir > 0 else Defs.IN_LEFT


## One tick of mount physics with `flags`. False when it died (bolted) on a deadly tile or in a pit.
func _physics(level: LevelBase, flags: int) -> bool:
	var grid: TileGrid = level.grid
	var held: bool = (flags & (Defs.IN_LEFT | Defs.IN_RIGHT)) != 0
	var cap: int = WILD_PACE_V16 if (wild and not tame and driver == null) else WALK_CAP
	var hopped: bool = false
	if grounded:
		if driver != null and (flags & Defs.IN_UP) != 0 and (flags & Defs.IN_DOWN) == 0 and no_jump == 0:
			yvel = HOP
			hopped = true
		elif held:
			xvel = clampi(xvel + facing * ACCEL, -cap, cap)
		else:
			var magnitude: int = maxi(absi(xvel) - FRICTION, 0)
			xvel = -magnitude if xvel < 0 else magnitude
	# x step (commit rule; co-op: the authentic view's edge walls), then y.
	var next_x: int = sim_pos.x + Tuning.floor16(xvel)
	if next_x >= Tuning.X_MIN and next_x < grid.x_max_excl() and _inside_edge_walls(level, next_x):
		sim_pos.x = next_x
	elif not hopped and grounded:
		xvel = 0
	sim_pos.y += Tuning.floor16(yvel)
	# Pit / below the map.
	if sim_pos.y > grid.height_px() + Tuning.PIT_DEPTH_PX:
		_die(&"pit")
		return false
	var col: int = Tuning.to_cell(sim_pos.x)
	var row: int = Tuning.to_cell(sim_pos.y)
	var airborne: bool = true
	if sim_pos.y > 0:
		var floor_value: int = grid.floor_at(col, row)
		var ch: String = grid.get_char(col, row)
		if floor_value == TileGrid.FLOOR_DEADLY and ch != TileGrid.CH_SPIKES_FLOOR:
			_die(&"liquid" if ch == TileGrid.CH_LIQUID else &"pit")
			return false
		if floor_value != TileGrid.FLOOR_EMPTY and floor_value != TileGrid.FLOOR_NOTHING and yvel >= 0:
			# Every landing is soft (spikes count as floor 1).
			sim_pos.y = Tuning.tile_top(sim_pos.y) + grid.surface_offset(col, row, sim_pos.x)
			yvel = 0
			airborne = false
		elif floor_value == TileGrid.FLOOR_EMPTY and yvel == 0 and grid.has_profile(col, row + 1) \
				and grid.surface_offset(col, row + 1, sim_pos.x) < Tuning.TILE:
			# Glued to descending ground, as the hero.
			sim_pos.y = Tuning.tile_top(sim_pos.y) + Tuning.TILE + grid.surface_offset(col, row + 1, sim_pos.x)
			row += 1
			airborne = false
		# Head probe (rising or grounded, never while falling).
		var head_rows: int = HEAD_PROBE_ROWS_RIDDEN if is_ridden() else HEAD_PROBE_ROWS_UNRIDDEN
		if yvel < 0 and row >= head_rows:
			var ceiling: int = grid.ceiling_at(col, row - head_rows)
			if ceiling == TileGrid.CEILING_SOLID:
				yvel = 0
				sim_pos.y = Tuning.tile_top(sim_pos.y) + Tuning.TILE
			elif ceiling == TileGrid.CEILING_DEADLY and is_ridden():
				_die(&"spikes")
				return false
		# Wall probe 20 px ahead, rows row - 1 and row - 2.
		if xvel != 0:
			var probe_col: int = Tuning.to_cell(sim_pos.x + (WALL_PROBE if xvel > 0 else -WALL_PROBE))
			for probe_row: int in [row - 1, row - 2]:
				var side: int = grid.side_at(probe_col, probe_row)
				if side == TileGrid.SIDE_WALL:
					sim_pos.x -= Tuning.floor16(xvel)
					xvel = 0
					if wild and not tame and driver == null:
						_pace_dir = -_pace_dir
					break
				if side == TileGrid.SIDE_DEADLY:
					_die(&"liquid" if grid.get_char(probe_col, probe_row) == TileGrid.CH_LIQUID else &"spikes")
					return false
	if airborne:
		# The airborne step after the integration (as the hero's, PHYSICS.md 5.2).
		if held:
			xvel = clampi(xvel + facing * ACCEL, -cap, cap)
		yvel = mini(yvel + Tuning.GRAVITY, Tuning.TERMINAL)
		if yvel > 0:
			no_jump = Tuning.NO_JUMP_TICKS
	else:
		no_jump = maxi(no_jump - 1, 0)
	grounded = not airborne
	return true


## Co-op edge walls (PHYSICS.md C.13): the x range the tribe camera allows this tick (world-A's
## LevelBase.get_edge_walls(); Vector2i.ZERO = no walls), else the authentic 20-column view 8 px inside each edge.
func _inside_edge_walls(level: LevelBase, x: int) -> bool:
	if driver == null or level.hero_count() <= 1 or Game.mode != Defs.GameMode.COOP:
		return true
	if level.has_method(&"get_edge_walls"):
		var walls: Vector2i = level.call(&"get_edge_walls")
		return walls == Vector2i.ZERO or (x >= walls.x and x < walls.y)
	var left: int = level.get_camera_cell().x * Tuning.TILE
	return x >= left + 8 and x < left + 312


## Every rider dies (an egg in co-op: the party layer turns the death into one) and the mount bolts.
func _die(cause: StringName) -> void:
	var riders: Array[PlayerBase] = []
	for hero: PlayerBase in [driver, gunner]:
		if hero != null:
			riders.append(hero)
	bolt()
	if cause == &"liquid":
		Audio.play_sfx(Sfx.SPLASH_HEAVY if AudioTable.SFX.has(Sfx.SPLASH_HEAVY) else Sfx.SPLASH)
	for hero: PlayerBase in riders:
		hero.kill(cause)


## Driver at (x, y - 26), gunner 14 px behind him; both stand still in the saddle.
func _place_riders() -> void:
	if driver != null:
		driver.sim_pos = Vector2i(sim_pos.x, sim_pos.y - SADDLE_PX)
		driver.facing = facing
		_hold_in_saddle(driver)
	if gunner != null:
		gunner.sim_pos = Vector2i(sim_pos.x - GUNNER_BEHIND_PX * facing, sim_pos.y - SADDLE_PX)
		_hold_in_saddle(gunner)


func _hold_in_saddle(hero: PlayerBase) -> void:
	hero.xvel = 0
	hero.yvel = 0
	hero.grounded = grounded
	hero.fall_ticks = 0
	hero.last_ground_y = hero.sim_pos.y


## CONTACT_ENEMIES: seating, a wild rex's bounces and hurts, enemies against the ridden box.
func _contacts(level: LevelBase) -> void:
	if not present or penned:
		return
	if wild and not tame:
		_wild_contacts(level)
		return
	if driver == null or gunner == null:
		_seating(level)
	if arena and driver != null and _stomp_unseat(level):
		return
	if is_ridden():
		_ridden_contacts(level)


## Arena: a rival (no teammate) landing on the driver's head with the stomp flag throws him off (xvel +/-64 away from
## the stomper, yvel -128, no stun; his remount lock runs); Chomper stays out for the next rider. An immune or
## shielded rider is a free springboard (the referee's rule), so he stays seated. The stomp itself stays the
## referee's (squash, steal, heart); without a referee the stomper bounces here. True when he was unseated.
func _stomp_unseat(level: LevelBase) -> bool:
	var rider: PlayerBase = driver
	if rider.is_immune() or rider.shield > 0:
		return false
	for hero: PlayerBase in level.contact_order():
		if hero == rider or hero.dead or hero.is_down() or hero.is_mounted() or hero.yvel < 0:
			continue
		if hero.is_curled() or hero.is_gliding() or _teammates(level, hero, rider):
			continue
		if not (Overlap.body(hero, rider, hero) and Overlap.stomp):
			continue
		var depth: int = Overlap.depth
		var away: int = 1 if rider.sim_pos.x >= hero.sim_pos.x else -1
		_unseat(rider)
		rider.launch(RIDER_HIT_XVEL * away, RIDER_HIT_YVEL)
		stomp_unseats += 1
		var referee: SimEntity = level.party_driver
		if referee == null or not (&"round_ticks" in referee):
			var up: bool = hero.control_enabled and (GameInput.get_flags(hero.slot) & Defs.IN_UP) != 0
			hero.bounce(Tuning.BOUNCE_YVEL_UP if up else Tuning.BOUNCE_YVEL, depth)
			Audio.play_sfx(Sfx.BOUNCE)
		return true
	return false


func _seating(level: LevelBase) -> void:
	var allow_gunner: bool = level.hero_count() > 1 and Game.mode == Defs.GameMode.COOP
	# "Not hurt": the stunned part of the hit timer - in an arena the versus one (PHYSICS.md C.14: 12 stunned ticks,
	# then 30 immune ticks with full control, in which he may sit down).
	var stun_min: int = VersusTuning.STUN_HIT_TIMER_MIN if arena else Tuning.HIT_STUN_MIN
	for hero: PlayerBase in level.contact_order():
		if hero.dead or hero.is_down() or hero.is_mounted() or hero.is_gliding() or hero.is_curled():
			continue
		if hero.yvel < 0 or hero.hit_timer >= stun_min or is_remount_locked(hero):
			continue
		if driver != null and (gunner != null or not allow_gunner):
			return
		if Overlap.body(hero, self, hero) and Overlap.stomp:
			seat(hero, allow_gunner)


func _wild_contacts(level: LevelBase) -> void:
	if _tamer != null and (_tamer.dead or _tamer.is_down() or _tamer.is_grounded() or _tamer.hit_timer > 0):
		tame_count = 0
		_tamer = null
	for hero: PlayerBase in level.contact_order():
		if hero.dead or hero.is_down() or hero.is_immune():
			continue
		if not Overlap.body(hero, self, hero):
			continue
		if Overlap.stomp and hero.yvel >= 0:
			var up: bool = hero.control_enabled and (GameInput.get_flags(hero.slot) & Defs.IN_UP) != 0
			hero.bounce(Tuning.BOUNCE_YVEL_UP if up else Tuning.BOUNCE_YVEL, Overlap.depth)
			Audio.play_sfx(Sfx.BOUNCE)
			if hero != _tamer:
				_tamer = hero
				tame_count = 0
			tame_count += 1
			if tame_count >= TAME_BOUNCES:
				_tame_now()
				return
		elif hero.hurt(self):
			if hero == _tamer:
				tame_count = 0
				_tamer = null


func _tame_now() -> void:
	tame = true
	tame_count = 0
	_tamer = null
	xvel = 0
	_doze_note()
	Audio.play_sfx(Sfx.SPOT_OPENED)


func _ridden_contacts(level: LevelBase) -> void:
	var enemies: Array[SimEntity] = level.get_kind(Defs.Kind.ENEMY)
	if not _ward_heads.is_empty():
		_ward_heads_check()  # wf11 R3 (co-op wards only): a head that gave nothing is forgotten once the boxes part
	for i: int in enemies.size():
		var enemy: EnemyBase = enemies[i] as EnemyBase
		if enemy == null or not enemy.awake or not enemy.contact_hurts or not enemy.is_targetable():
			continue
		if not Overlap.body(self, enemy, self):
			continue
		if not _ward_heads.is_empty() and _ward_heads.has(enemy):
			continue  # wf11 R3: still falling through the head that gave nothing - it does not hit the riders either
		if Overlap.stomp and yvel >= 0:
			if _in_ward(level):
				# wf11 R3 (the mount's stomp is its rider's): inside a ward an enemy's head gives a co-op party's mount
				# no lift - its velocity stays, it falls on through the body - and that enemy is passed until they part.
				_ward_heads.append(enemy)
				_ward_since.append(PlayerBase.WARD_FALLING)
				Audio.play_sfx(Sfx.LAND)
				level.spawn_fx(&"fx/dust", Vector2i(sim_pos.x, enemy.sim_pos.y - enemy.box_h))
				continue
			yvel = STOMP_YVEL
			grounded = false
			continue
		var riders_immune: bool = true
		for hero: PlayerBase in [driver, gunner]:
			if hero != null and not hero.is_immune():
				riders_immune = false
		if riders_immune:
			continue
		rider_hit(enemy)
		return


## wf11 ruling R3, the ward (LevelBase.in_ward; DESIGN.md G-rulings): true when this mount carries a hero of a co-op
## party and its driver's feet column lies in a ward - an enemy's head then gives it nothing.
func _in_ward(level: LevelBase) -> bool:
	return driver != null and driver.gate_rule(PlayerBase.GATE_R3) and level.in_ward(driver.sim_pos.x)


## R3: an enemy stays in [member _ward_heads] while it is there to touch and its box still overlaps the mount's.
## Phase 4 ruling Q4 (DESIGN.md G87; the mount's stomp is its rider's, so is its grace): the pass holds while the mount
## is in the air and for PartyTuning.WARD_GRACE_TICKS ticks after the first tick it has ground again - then that
## enemy's body meets the riders as any body does ([method rider_hit]). A mount standing in a keeper is no shelter.
func _ward_heads_check() -> void:
	for i: int in range(_ward_heads.size() - 1, -1, -1):
		var enemy: EnemyBase = _ward_heads[i]
		var forget: bool = not is_instance_valid(enemy) or enemy.dead or not enemy.awake or not enemy.contact_hurts \
				or not enemy.is_targetable() or not Overlap.body(self, enemy, self)
		if not forget:
			var since: int = PlayerBase.ward_grace_step(_ward_since[i], grounded)
			_ward_since[i] = since
			forget = PlayerBase.ward_grace_over(since)
		if forget:
			_ward_heads.remove_at(i)
			_ward_since.remove_at(i)


func _return_home() -> void:
	present = true
	visible = true
	bolt_left = 0
	xvel = 0
	yvel = 0
	grounded = true
	no_jump = 0
	if wild and not tame:
		teleport(spawn_pos)
	else:
		tame = true
		teleport(_home)
	# Arena: home again, he waits in his pen for the next release.
	penned = arena and tame
	_rumbling = false
	set_box(BOX)
	_refresh_visual()


func _on_level_reset() -> void:
	_ward_heads.clear()
	_ward_since.clear()
	for hero: PlayerBase in [driver, gunner]:
		if hero != null:
			_unseat(hero)
	_remount_until.fill(-1)
	bite_tick = 0
	_bite_box_active = false
	tame_count = 0
	_tamer = null
	_pace_dir = 1
	_return_home()


## Dozing: only unridden, still and tame at home (PHYSICS.md C.9).
func _doze_area() -> Rect2i:
	return _doze_box()


func _can_doze() -> bool:
	if arena:
		return false  # the pen clock runs every tick (an arena is one screen: nothing dozes there anyway)
	return present and not is_ridden() and tame and grounded and xvel == 0 and yvel == 0 and sim_pos == _home


func _on_doze_wake() -> void:
	_refresh_visual()


# --- Picture ----------------------------------------------------------------------------------------------------------

## The rex's frame (idle, walk, bite) and, on a tame rex, the saddle overlay of sprites/objects/rex_saddle.png on the
## same cell (ASSET_MANIFEST 17.3); in an arena the rumble shakes him 1 art px side to side. Cosmetic.
func _refresh_visual() -> void:
	if _sprite == null:
		return
	visible = present
	_sprite.flip_h = facing < 0
	var shake_x: float = (1.0 if _anim_age % 2 == 0 else -1.0) if _rumbling else 0.0
	_sprite.position.x = shake_x
	if _saddle != null:
		_saddle.position.x = shake_x
	var anim: Vector2i = FRAME_IDLE
	var fps: int = IDLE_FPS
	if bite_tick > 0:
		_sprite.frame = FRAME_BITE.x + mini((bite_tick - 1) * FRAME_BITE.y / BITE_TICKS, FRAME_BITE.y - 1)
	else:
		if xvel != 0 or not grounded:
			anim = FRAME_WALK
			fps = WALK_FPS
		_sprite.frame = anim.x + ObjTuning.anim_frame(_anim_age, fps) % anim.y
	if _saddle != null:
		_saddle.visible = tame
		_saddle.flip_h = _sprite.flip_h
		_saddle.frame = _sprite.frame
