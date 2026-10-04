class_name HeroAnim
extends RefCounted
## Chooses the hero's sheet frame for one tick (docs/ASSET_MANIFEST.md 3: 8 x 7 cells of 176 x 112 art px).
##
## Purely cosmetic: it reads the simulation state of a [Player] and never writes it. The frame is a function of
## tick counters only (docs/ARCHITECTURE.md 4.5), so the same inputs always show the same pictures.

## Animations of the hero. Several share sheet frames (the sheet has no skid or panting drawings).
enum Anim {
	IDLE, PANT, SKID, WALK, JUMP, FALL, LAND, CROUCH, CRAWL,
	STRIKE, STRIKE_UP, STRIKE_LOW, STRIKE_AIR, HURT, DEATH, GLIDE, VICTORY,
}

# --- Sheet frames, row-major (ASSET_MANIFEST 3) ---------------------------------------------------------------------
const IDLE_FIRST: int = 0
const IDLE_COUNT: int = 6
const WALK_FIRST: int = 6
const WALK_COUNT: int = 8
const JUMP_FIRST: int = 14
const JUMP_COUNT: int = 3
const FALL_FIRST: int = 17
const FALL_COUNT: int = 3
const LAND: int = 20             ## landing squash; also the skid pose
const CROUCH: int = 21
const CRAWL_FIRST: int = 22
const CRAWL_COUNT: int = 2
const ATTACK_WINDUP: int = 27    ## club behind the back
const ATTACK_OVERHEAD: int = 28  ## club above the head
const ATTACK_HIT: int = 29       ## the hit frame (slash arc drawn in)
const ATTACK_FOLLOW: int = 30    ## follow-through
const ATTACK_UP_WINDUP: int = 31
const ATTACK_UP_HIT: int = 32
const ATTACK_LOW_WINDUP: int = 33
const ATTACK_LOW_HIT: int = 34
const ATTACK_AIR_WINDUP: int = 35
const ATTACK_AIR_HIT: int = 36
const HURT_FIRST: int = 37
const HURT_COUNT: int = 2
const DEATH_FIRST: int = 39
const DEATH_AIR_COUNT: int = 2   ## 39-40 while he is tossed through the air
const VICTORY_FIRST: int = 48
const VICTORY_COUNT: int = 2
const GLIDE_FIRST: int = 50
const GLIDE_COUNT: int = 2

# --- Cadence: manifest fps converted with Tuning.ANIM_TICKS_PER_SECOND (cosmetic only) -------------------------------
const IDLE_FPS: int = 8
const PANT_FPS: int = 16         ## "idle at double speed" (manifest 16)
const WALK_FPS: int = 12
const WALK_FPS_FAST: int = 16    ## at full walking speed
const JUMP_FPS: int = 10
const FALL_FPS: int = 10
const CRAWL_FPS: int = 6
const HURT_FPS: int = 8
const DEATH_FPS: int = 8
const VICTORY_FPS: int = 4
const GLIDE_FPS: int = 4

## A rise slower than this that did not come from the jump handler is a hop (strike, hard landing, shake
## nudge): the pose is kept instead of switching to the jump frames.
const HOP_MAX_RISE_YVEL: int = -48
## Falling for fewer ticks than this keeps the pose (hops, the first ticks after walking off a ledge).
const FALL_POSE_TICKS: int = 3
## Strike script entries (1-based) at which the forward and the 9-tick strikes show their hit frames.
const FORWARD_OVERHEAD_TICK: int = 3
const FORWARD_HIT_TICK: int = 5
const FORWARD_FOLLOW_TICK: int = 7
const LONG_HIT_TICK: int = 7

## Animation playing now (an [enum Anim]).
var anim: int = Anim.IDLE
## Ticks since [member anim] started.
var clock: int = 0
## Sheet frame of this tick.
var frame: int = IDLE_FIRST
## True on a tick on which a foot touches the ground in the walk cycle (footstep sound).
var footstep: bool = false

var _walk_phase: int = 0
var _strike_airborne: bool = false


## Back to the standing pose (spawn, respawn).
func reset() -> void:
	anim = Anim.IDLE
	clock = 0
	frame = IDLE_FIRST
	footstep = false
	_walk_phase = 0
	_strike_airborne = false


## Advance one tick and return the sheet frame to show. Call once per tick, after the hero's state is final.
func update(hero: Player) -> int:
	footstep = false
	var next: int = _choose(hero)
	if next == anim:
		clock += 1
	else:
		anim = next
		clock = 0
		_walk_phase = 0
	frame = _frame(hero)
	return frame


## True when `hero` is in the air for real: a jump, a bounce or a fall, not one of the small hops.
static func is_airborne_pose(hero: Player) -> bool:
	if hero.grounded:
		return false
	return hero.jump_ticks > 0 or hero.fall_ticks >= FALL_POSE_TICKS or hero.yvel <= HOP_MAX_RISE_YVEL


func _choose(hero: Player) -> int:
	if hero.dead:
		return Anim.DEATH
	if hero.is_gliding():
		return Anim.GLIDE
	if hero.state == Defs.HeroState.HURT:
		return Anim.HURT
	match hero.handler:
		Defs.HeroState.STRIKE:
			if hero.strike_tick == 1:
				_strike_airborne = is_airborne_pose(hero)
			return Anim.STRIKE_AIR if _strike_airborne else Anim.STRIKE
		Defs.HeroState.HIGH_STRIKE:
			return Anim.STRIKE_UP
		Defs.HeroState.LOW_STRIKE:
			return Anim.STRIKE_LOW
	if not hero.grounded:
		if hero.land_pose > 0 and not is_airborne_pose(hero):
			return Anim.LAND  # the hop of a hard landing keeps the squash
		return _choose_airborne(hero)
	return _choose_grounded(hero)


func _choose_airborne(hero: Player) -> int:
	if hero.yvel < 0:
		if hero.jump_ticks > 0 or hero.yvel <= HOP_MAX_RISE_YVEL:
			return Anim.JUMP
		return anim
	if hero.fall_ticks >= FALL_POSE_TICKS:
		return Anim.FALL
	return anim


func _choose_grounded(hero: Player) -> int:
	if hero.victorious:
		return Anim.VICTORY
	# With the hang-glider every ground state except walking runs the crouch handler: show what is held instead.
	var pose: int = hero.state if hero.is_carrying_glider() else hero.handler
	match pose:
		Defs.HeroState.WALK:
			return Anim.WALK
		Defs.HeroState.CROUCH:
			return Anim.CROUCH
		Defs.HeroState.CRAWL:
			return Anim.CROUCH if hero.is_carrying_glider() else Anim.CRAWL
	if hero.state == Defs.HeroState.CRAWL:
		return Anim.CROUCH  # entered a crawl too fast: he slides on his knees until slow enough
	if hero.land_pose > 0:
		return Anim.LAND
	if hero.skidding:
		return Anim.SKID
	if hero.panting:
		return Anim.PANT
	return Anim.IDLE


func _frame(hero: Player) -> int:
	match anim:
		Anim.IDLE:
			return IDLE_FIRST + _cycle(IDLE_FPS, IDLE_COUNT)
		Anim.PANT:
			return IDLE_FIRST + _cycle(PANT_FPS, IDLE_COUNT)
		Anim.SKID, Anim.LAND:
			return LAND
		Anim.WALK:
			return WALK_FIRST + _walk_step(hero)
		Anim.JUMP:
			return JUMP_FIRST + mini(clock * JUMP_FPS / Tuning.ANIM_TICKS_PER_SECOND, JUMP_COUNT - 1)
		Anim.FALL:
			return FALL_FIRST + _cycle(FALL_FPS, FALL_COUNT)
		Anim.CROUCH:
			return CROUCH
		Anim.CRAWL:
			return CRAWL_FIRST + _cycle(CRAWL_FPS, CRAWL_COUNT)
		Anim.STRIKE:
			if hero.strike_tick >= FORWARD_FOLLOW_TICK:
				return ATTACK_FOLLOW
			if hero.strike_tick >= FORWARD_HIT_TICK:
				return ATTACK_HIT
			return ATTACK_OVERHEAD if hero.strike_tick >= FORWARD_OVERHEAD_TICK else ATTACK_WINDUP
		Anim.STRIKE_AIR:
			return ATTACK_AIR_HIT if hero.strike_tick >= FORWARD_HIT_TICK else ATTACK_AIR_WINDUP
		Anim.STRIKE_UP:
			return ATTACK_UP_HIT if hero.strike_tick >= LONG_HIT_TICK else ATTACK_UP_WINDUP
		Anim.STRIKE_LOW:
			return ATTACK_LOW_HIT if hero.strike_tick >= LONG_HIT_TICK else ATTACK_LOW_WINDUP
		Anim.HURT:
			return HURT_FIRST + _cycle(HURT_FPS, HURT_COUNT)
		Anim.DEATH:
			return DEATH_FIRST + _cycle(DEATH_FPS, DEATH_AIR_COUNT)
		Anim.GLIDE:
			return GLIDE_FIRST + _cycle(GLIDE_FPS, GLIDE_COUNT)
		Anim.VICTORY:
			return VICTORY_FIRST + _cycle(VICTORY_FPS, VICTORY_COUNT)
	return IDLE_FIRST


## Looping frame index of the current animation at `fps`.
func _cycle(fps: int, count: int) -> int:
	return (clock * fps / Tuning.ANIM_TICKS_PER_SECOND) % count


## Walk cycle: 12 fps, 16 fps at full speed; reports the two ticks per cycle on which a foot comes down.
func _walk_step(hero: Player) -> int:
	var before: int = _walk_phase / Tuning.ANIM_TICKS_PER_SECOND
	if clock > 0:
		_walk_phase += WALK_FPS_FAST if absi(hero.xvel) >= Tuning.WALK_CAP else WALK_FPS
	var step: int = _walk_phase / Tuning.ANIM_TICKS_PER_SECOND
	var half: int = WALK_COUNT / 2
	footstep = hero.grounded and step != before and step % half == 0
	return step % WALK_COUNT
