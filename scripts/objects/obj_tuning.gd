class_name ObjTuning
extends RefCounted
## Numbers of the objects / items / fx module that are not in [Tuning] yet (ARCHITECTURE.md 1.2: a module keeps
## private constants until core adopts them). Units as in Tuning: px = logical px, v16 = 1/16 px per tick, ticks.
##
## Marks: [G n] = GAMEPLAY.md section n, [P n] = PHYSICS.md section n, [M n] = ASSET_MANIFEST.md section n,
## [own] = a decision of this module (cosmetic timing, or a rule the specs leave open).

# =================================================================================================================
# Dropped items and bones [G 4.2] [G 4.5]
# =================================================================================================================
const DROP_GRAVITY: int = 9          ## v16 per tick; dropped items are lighter than the hero
const DROP_TERMINAL: int = 256       ## v16; the fall speed stays below this value
const DROP_BOUNCE_SHIFT: int = 1     ## a bounce keeps half of the impact speed (speed >> 1): about half the height
const DROP_GROUND_FRICTION: int = 8  ## v16 taken from |xvel| on every bounce
## An impact slower than this ends the bouncing and the item lies still. Without it the whole-pixel integration
## settles into an endless 6 px hop (landing speed 60). [own]
const DROP_REST_MAX_YVEL: int = 64
## Dropped bonus items alive at once; further ones are not created. The original has 32 slots for them, so a boss
## burst of Tuning.BOSS_BURST_ITEMS shows as many as fit (performance budget: ARCHITECTURE.md 11).
const MAX_DROPPED_ITEMS: int = 32
const BURST_XVEL: int = 48           ## first item of a fan burst (bones, grenade, boss), v16
const BURST_YVEL: int = -128         ## v16
const FAN_STEP: int = 16             ## every second item of a fan: 16 v16 narrower and 16 v16 higher
const FAN_CYCLE: int = 16            ## a fan repeats after this many items [own]
const BONE_SCATTER_DY: int = -48     ## scattered energy starts this far above the hero's feet
const SPOT_THROW_XVEL: int = 48      ## item thrown out of a small hidden spot, v16
const SPOT_THROW_YVEL: int = -112    ## v16
const SPOT_FACE_YVEL: int = -64      ## item pushed out of a wall or ceiling spot, v16 [own]
const SKY_DROP_XVEL_STEP: int = 16   ## several sky drops of one spot spread by this much, v16 [own]
const GIANT_BOUNCE_MIN_YVEL: int = 128  ## a giant bonus falling at least this fast bounces off the hero once
const GIANT_BOUNCE_XVEL: int = 32    ## sideways speed after that bounce, v16, random sign
const BONE_SPIN_FPS: int = 10        ## [M 7]

# =================================================================================================================
# Item values that have no table in the manifest [G 3.2] [G 4.1]
# =================================================================================================================
const WATER_BUCKET_POINTS: int = 500     ## "scores like food"
const RANDOM_SKULL_PER_95: int = 2       ## a thrown random bonus is a skull 2 times in 95 ...
const RANDOM_KILL_ALL_PER_95: int = 1    ## ... and a kill-all item once in 95
const RANDOM_ROLL: int = 95

# =================================================================================================================
# Screen shakes started by this module [P 13.3]
# =================================================================================================================
const SHAKE_SKULL: int = 7
const SHAKE_GIANT_BOUNCE: int = 7
const SHAKE_KILL_ALL: int = 9
const SHAKE_COLUMN: int = 7

# =================================================================================================================
# Objects
# =================================================================================================================
const PLATFORM_DEFAULT_DIR: int = 2      ## right [P 11.4]
const PLATFORM_DEFAULT_SPEED: int = 2    ## px per tick
const PLATFORM_DEFAULT_TRAVEL: int = 44  ## ticks at full speed before reversing
const DROPPER_BELOW_MAP_ROWS: int = 3    ## a dropper stops this many rows below the map [P 11.4]
const COLUMN_DEFAULT_RISE: int = 2       ## tiles
const COLUMN_TRIGGER_MARGIN: int = 4     ## default trigger: this many tiles around the block [own]
const SPRING_DEFAULT_POWER: int = -224   ## v16, the big enemy bounce [P 9]
const HIT_WOBBLE_TICKS: int = 6          ## scenery wobbles this long after a hit [own]
const BLOCK_HIT_DEBRIS: int = 4          ## debris bits per hit on a breakable block [G 4.4]
const BLOCK_BREAK_DEBRIS: int = 8        ## bits of the final hit
const SPOT_HIT_DEBRIS: int = 3           ## crumbs per hit on a hidden spot [own]
const SPOT_OPEN_DEBRIS: int = 6
const CONTAINER_DEBRIS: int = 6

# Terrain-atlas tiles used as hidden-spot looks [M 10.1]
const ATLAS_AUTO: int = -1
const ATLAS_BLOCK: int = 7
const ATLAS_INSET: int = 15

# =================================================================================================================
# Effects (cosmetic) [M 9]
# =================================================================================================================
const MAX_POPUPS: int = 16           ## score pop-ups alive at once [G 2]
const POPUP_BLINK_TICKS: int = 8     ## a pop-up blinks during its last ticks [own]
const DEBRIS_DEFAULT_COUNT: int = 4
const DEBRIS_MAX_COUNT: int = 12
const DEBRIS_LIFE: int = 22
const DEBRIS_GRAVITY: int = 14       ## v16 per tick
const DEBRIS_XVEL: int = 56          ## fastest sideways speed of a piece, v16
const DEBRIS_YVEL: int = -96         ## base upward speed of a piece, v16
const DUST_LIFE: int = 8
## Vertical bob of a placed item in ART px over one cycle of 24 ticks (peak = Tuning.ITEM_BOB_PX logical px).
const BOB_ART: Array[int] = [0, 0, 1, 1, 2, 3, 4, 5, 5, 6, 6, 6, 6, 6, 5, 5, 4, 3, 2, 1, 1, 0, 0, 0]


## Start velocity (xvel, yvel) of item number `index` (0-based) of a fan burst whose first item starts with
## (`base_xvel`, `base_yvel`): items leave in pairs to both sides, every pair FAN_STEP narrower (crossing over to
## the other side once the speed passes zero) and FAN_STEP faster upward than the pair before. Bursts larger than
## FAN_CYCLE repeat the fan, every repeat a little wider, so that big bursts do not fly out of sight.
static func fan_velocity(index: int, base_xvel: int, base_yvel: int) -> Vector2i:
	var cycle: int = index / FAN_CYCLE
	var pair: int = (index % FAN_CYCLE) >> 1
	var side: int = 1 if base_xvel >= 0 else -1
	if (index & 1) == 1:
		side = -side
	var spread: int = absi(base_xvel) - pair * FAN_STEP + cycle * (FAN_STEP >> 1)
	return Vector2i(side * spread, base_yvel - pair * FAN_STEP)


## Frame of a one-shot or looping sheet animation after `age` ticks at `fps` frames per second.
static func anim_frame(age: int, fps: int) -> int:
	return age * fps / Tuning.ANIM_TICKS_PER_SECOND


## Ticks a one-shot animation of `frames` frames at `fps` lasts (rounded up).
static func anim_ticks(frames: int, fps: int) -> int:
	return (frames * Tuning.ANIM_TICKS_PER_SECOND + fps - 1) / fps
