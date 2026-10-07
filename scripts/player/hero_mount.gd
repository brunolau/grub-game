class_name HeroMount
extends RefCounted
## Riding Chomper, the rex (docs/spec/PHYSICS.md C.9; DESIGN.md C.8): the driver's and the gunner's side of the
## mount - while seated the driver's own handlers do not run (his flags drive the mount), the gunner strikes and
## throws from his seat with his own hand weapon (LEFT / RIGHT turn him, the strike hop is skipped as on a platform)
## and may swap, and a hit on a seated rider is the mount's (the riders are thrown off, no heart is lost).
##
## Owner: player-B (docs/expansion/PLAN.md 4.1); the mount entity itself is objects-B's `objects/mount` (class Mount):
## it seats heroes (the stomp test, PlayerBase.sit_on_mount()), moves on the driver's flags of the tick
## (GameInput.get_flags(driver.slot)) with the MountTuning rules, places the riders every tick in PLATFORMS (driver
## at its feet - MountTuning.SADDLE_PX, gunner MountTuning.GUNNER_BEHIND_PX behind; facing, yvel 0 and grounded set
## by it), runs the bite, the DOWN + UP dismount with its remount lock, the ridden-box contact, bolting and taming.
## The mount is found by duck typing (a method `rider_hit(source)`), so this file never depends on objects-B's.
## A component of [Player], created with him; the calls below are the hooks of PLAN.md P0.8 and are made only while
## [member active] is true (a level with a mount). No Book I level has a mount.
##
## Hook order inside Player._hero_update: after the input is read (8b), after the party component and before the
## belt, [method update] runs the hero's whole PLAYER phase itself while he is seated (returns true): the state
## RIDING, the gunner's strike handler and swap, the 8i timers, the box. Player.hurt asks [method on_hurt] before the
## 1.0 hurt: a seated rider's hit is the mount's (C.9).

## The hero this component belongs to.
var hero: Player = null
## True while the hooks run (the level holds a mount). Default false.
var active: bool = false

## True while he was seated on the last tick this component ran (to notice the first seated tick).
var _seated: bool = false


func _init(p_hero: Player) -> void:
	hero = p_hero


## The hero entered a level (Player._ready): switch on when it holds a mount.
func setup(level: LevelBase) -> void:
	_seated = false
	refresh(level)


## Look for a mount in the level again (one placed after the hero, e.g. by a test) and switch on when there is one.
## Never switches off a component that is on.
func refresh(level: LevelBase) -> void:
	if level == null:
		return
	for kind: int in [Defs.Kind.OTHER, Defs.Kind.PLATFORM, Defs.Kind.ENEMY, Defs.Kind.HITTABLE]:
		for entity: SimEntity in level.get_kind(kind):
			if is_mount(entity):
				active = true
				return


## True when `entity` is a mount (duck typing: objects-B's Mount answers `rider_hit(source)`).
static func is_mount(entity: Object) -> bool:
	return entity != null and entity.has_method(&"rider_hit")


## PLAYER phase, after 8b: while seated (hero.is_mounted()) the driver's or the gunner's update. True = it ran the rest
## of the hero's PLAYER phase this tick.
func update(level: LevelBase) -> bool:
	if not hero.is_mounted():
		_seated = false
		return false
	var mount: SimEntity = hero.mount
	if not is_instance_valid(mount) or mount.is_queued_for_deletion():
		# The mount is gone (freed with its level part): he is simply off the seat.
		hero.leave_mount()
		_seated = false
		return false
	if not _seated:
		_seated = true
		# Sitting down ends what his own handlers had running: no strike, no glide, no fall. The saddle is a landing:
		# a hop from tar onto Chomper ends the tar rules (C.5, mounts ignore tar), so the dismount flies normally.
		hero.attack_gate = false
		hero.glide = 0
		if hero.hero_climb.active:
			hero.hero_climb.end_tar()
	hero.state = Defs.HeroState.RIDING
	hero.handler = Defs.HeroState.RIDING
	hero.fall_ticks = 0
	hero.jump_ticks = 0
	hero.looking = false
	if hero.mount_seat == PlayerBase.SEAT_GUNNER:
		_gunner_tick(level)
	else:
		# The driver: no strikes with his own weapon (the bite is the mount's), no swap (C.2 rule 2 lists the gunner's
		# seat only).
		hero.attack_gate = false
	# His x speed mirrors the mount's, so the camera pages with him (PHYSICS.md 12.1 reads the hero's xvel); the
	# mount sets yvel and grounded.
	if is_instance_valid(mount):
		hero.xvel = mount.xvel
	hero._tick_timers(level)
	hero.set_box(Tuning.HERO_BOX_STAND)
	return true


## The gunner's seat: Swap, then the strike handler from the seat (state table with the swing_lock override; a
## strike in progress continues, PHYSICS.md 4.3 override 4), no movement.
func _gunner_tick(level: LevelBase) -> void:
	if hero.hero_belt.active:
		hero.hero_belt.update(level)
	var flags: int = 0 if hero.swing_lock != 0 else hero._raw_flags
	var selected: int = Tuning.STATE_LUT[flags & Defs.IN_STATE_MASK]
	var striking: bool = selected == Defs.HeroState.STRIKE or selected == Defs.HeroState.HIGH_STRIKE \
			or selected == Defs.HeroState.LOW_STRIKE
	hero.input_flags = flags
	if not striking and not hero.attack_gate:
		return
	var kind: int = selected if striking else hero._loaded_anim
	if kind != Defs.HeroState.STRIKE and kind != Defs.HeroState.HIGH_STRIKE and kind != Defs.HeroState.LOW_STRIKE:
		kind = Defs.HeroState.STRIKE
	# From the seat: no motion of his own, the strike hop skipped as on a platform.
	var on_platform: bool = hero.on_platform
	hero.xvel = 0
	hero.yvel = 0
	hero.on_platform = true
	hero._handle_strike(kind)
	hero.on_platform = on_platform
	hero.yvel = 0


## Step 8i: nothing of its own (the remount lock is the mount's, per slot).
func tick_timers() -> void:
	pass


## The hero was hurt (after the immunity checks of Player.hurt). True = the mount took the hit (C.9: the riders are
## thrown off, stunned, no heart lost) and Player.hurt returns true without the 1.0 hurt. A skull (TRAP) throws him off
## too, and then scatters his energy as in 1.0 (false).
func on_hurt(source: SimEntity, kind: int) -> bool:
	if not hero.is_mounted():
		return false
	var mount: SimEntity = hero.mount
	if is_instance_valid(mount) and mount.has_method(&"rider_hit"):
		mount.call(&"rider_hit", source)
	if hero.is_mounted():
		# A mount without the rule (or one that kept him): the C.9 throw-off for this rider.
		throw_off(hero, source)
	_seated = false
	return kind != Defs.HurtKind.TRAP


## The hero respawned (PlayerBase.respawn_at already left the seat).
func on_respawn() -> void:
	_seated = false


## The C.9 throw-off of one rider: off the seat, xvel +/-MountTuning.HIT_XVEL away from `source`, yvel
## MountTuning.HIT_YVEL, hit_timer MountTuning.HIT_TIMER (stunned and blinking as PHYSICS.md 10.1), no heart lost.
## For a mount entity that wants the rider's side done for it.
static func throw_off(rider: PlayerBase, source: SimEntity) -> void:
	if rider == null:
		return
	var away: int = 1
	if source != null and source.sim_pos.x > rider.sim_pos.x:
		away = -1
	rider.leave_mount()
	rider.xvel = MountTuning.HIT_XVEL * away
	rider.yvel = MountTuning.HIT_YVEL
	rider.hit_timer = MountTuning.HIT_TIMER
	rider.attack_gate = false
	rider.grounded = false
	rider.on_platform = false
	rider.fall_ticks = 0
