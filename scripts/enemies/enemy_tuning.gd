class_name EnemyTuning
extends RefCounted
## Numbers of the enemies / bosses module that are not in [Tuning] yet (ARCHITECTURE.md 1.2: a module keeps private
## constants until core adopts them). Units as in Tuning: px = logical px, v16 = 1/16 px per tick, ticks.
##
## Marks: [G n] = GAMEPLAY.md section n, [P n] = PHYSICS.md section n, [M n] = ASSET_MANIFEST.md section n,
## [own] = a decision of this module (a rule the specs leave open, or cosmetic timing).

# =================================================================================================================
# Shared enemy rules [G 5.1]
# =================================================================================================================
const FLASH_TICKS: int = 4               ## survivors flash this long [own]
const FLASH_PERIOD_MASK: int = 1         ## bright on every second tick of the flash [own]
const DEATH_ARC_YVEL: int = -192         ## v16: a killed enemy is thrown up 12 px per tick ... [own]
const DEATH_ARC_XVEL: int = 96           ## ... and 6 px per tick away from whoever killed it [own]
const DEATH_ARC_MIN_TICKS: int = 4       ## the corpse is kept at least this long, even off screen [own]
const DEATH_ARC_MAX_TICKS: int = 66      ## and removed after this long at the latest [own]
const BURST_DY: int = -8                 ## bones / grenade items appear this far above the feet point
const LANDING_BOUNCE_MIN: int = 32       ## v16: a rebound slower than this ends the landing bounce [G 5.1]
const STEP_DOWN_PX: int = 8              ## a walker follows a floor up to this far below its feet (slope feet) [own]
const CLIMB_SPEED: int = 32              ## v16: climbers go up a wall 2 px per tick [G 5.1] [own]
const LEDGE_TICKS: int = 12              ## ticks a climber may cross a wall top without falling [own]
const DEFAULT_ZONE_TILES: int = 10       ## trigger zone of zone spawners without `zone=`: this many tiles around
## Food cell (sprites/items/food.png) an enemy turns into during the feast, by score index 0..11. [G 5.3] [M 7]
const FEAST_FOOD_CELLS: Array[int] = [0, 7, 13, 19, 24, 27, 29, 31, 35, 36, 40, 40]

# =================================================================================================================
# Default score index (Tuning.SCORE_LADDER) per enemy id [G 3.3] [own]
# =================================================================================================================
const SCORE_DROPPER: int = 1
const SCORE_DANGLER: int = 0
const SCORE_LURKER: int = 2
const SCORE_SWINGER: int = 1
const SCORE_STINGER: int = 3
const SCORE_HARRIER: int = 4
const SCORE_DART: int = 3
const SCORE_HOPPER: int = 2
const SCORE_WALKER: int = 0
const SCORE_FLYER: int = 1
const SCORE_DIGGER: int = 2
const SCORE_LEAPER: int = 3
const SCORE_CHARGER: int = 4
const SCORE_SNAPPER: int = 1

# =================================================================================================================
# Archetype 0, sky dropper [G 5.2]
# =================================================================================================================
const DROPPER_SIDE_PX: int = 192         ## appears this far left / right of the hero, alternating
const DROPPER_ABOVE_VIEW_PX: int = 8     ## feet this far above the top of the view [own]
const DROPPER_PAUSE: int = 44            ## default `pause`
const DROPPER_SPEED: int = 32            ## default `speed`, v16 (2 px per tick)
const DROPPER_MAX_ALIVE: int = 2         ## default `max`
const DROPPER_LAND_TICKS: int = 6        ## landing pose before it starts to walk [own]

# =================================================================================================================
# Archetypes 2, 3, 4: thread hangers [G 5.2]
# =================================================================================================================
const DANGLER_DEPTH: int = 48            ## default `depth`, px
const DANGLER_SPEED: int = 2             ## default `speed`, px per tick
const LURKER_RANGE_TILES: int = 4        ## default `range`
const LURKER_PAUSE: int = 22             ## default `pause`
const LURKER_DROP_YVEL: int = 32         ## v16: descends 2 px per tick
const LURKER_RUN_XVEL: int = 48          ## v16: runs 3 px per tick
const LURKER_TURN_PX: int = 48           ## turns round when the hero is this far behind it [own]
const SWINGER_RADIUS: int = 40           ## default `radius`, px
const SWINGER_LOWER_SPEED: int = 2       ## px per tick while lowering
const SWINGER_KICK: int = 8              ## first angular speed, 1/256 turn per tick (amplitude 36 = 51 degrees) [own]
const SWINGER_PULL: int = 1              ## angular speed change per tick toward the rest position [own]
const THREAD_SEARCH_ROWS: int = 12       ## the thread hangs from a ceiling up to this many rows above the anchor
const THREAD_OVERLAP_ART: int = 2        ## the thread ends this far inside the body (no gap), art px
const THREAD_WIDTH: float = 2.0          ## art px (cosmetic) [M 1]
const THREAD_COLOR: Color = Color("272018")  ## outline colour of the art kit [M 1]
## sin(i * 360 / 256 degrees) * 256 for i = 0..64 (integer pendulum, no floats in the simulation).
const SINE_QUARTER: Array[int] = [
	0, 6, 13, 19, 25, 31, 38, 44, 50, 56, 62, 68, 74, 80, 86, 92, 98, 104, 109, 115, 121, 126, 132, 137, 142, 147,
	152, 157, 162, 167, 172, 177, 181, 185, 190, 194, 198, 202, 206, 209, 213, 216, 220, 223, 226, 229, 231, 234,
	237, 239, 241, 243, 245, 247, 248, 250, 251, 252, 253, 254, 255, 255, 256, 256, 256,
]
const SINE_QUARTER_STEPS: int = 64       ## last index of SINE_QUARTER (a quarter turn)
const SINE_SHIFT: int = 8                ## SINE_QUARTER values are scaled by 1 << 8

# =================================================================================================================
# Archetypes 5, 6, 7: flyers [G 5.2]
# =================================================================================================================
const STINGER_RANGE_TILES: int = 6       ## default `range`
const STINGER_SPEED: int = 3             ## default `speed`, px per tick
const STINGER_LEVEL_PX: int = 8          ## levels out when within this many px of the hero's height
const HARRIER_RANGE_TILES: int = 8       ## default `range`
const HARRIER_SPEED: int = 3             ## px per tick per axis
const HARRIER_STRIKE_RISE: int = 5       ## flies this much higher while the hero is striking
## Way-points of the clever flyer relative to the hero: x offset, height above his feet (px). From his right
## and 40 px up, across 50-60 px above his head, to 32 px to his left, then a swoop through head height. [G 5.2]
const HARRIER_WAYPOINTS: Array[Vector2i] = [
	Vector2i(72, 40), Vector2i(80, 38), Vector2i(48, 48), Vector2i(16, 56), Vector2i(0, 60),
	Vector2i(-16, 52), Vector2i(-32, 40), Vector2i(0, 24), Vector2i(40, 30),
]
const HARRIER_SWOOP_HEIGHT: int = 30     ## way-points at or below this height are the swoop (screech pose) [own]
const HARRIER_WAYPOINT_TICKS: int = 22   ## heads for the next way-point after this long even when not reached [own]
const DART_RANGE_TILES: int = 8          ## default `range`
const DART_SPEED: int = 4                ## default `speed`, px per tick

# =================================================================================================================
# Archetypes 8, 9: hopper and patroller [G 5.2]
# =================================================================================================================
const HOPPER_RANGE_TILES: int = 6        ## default `range`
const HOPPER_PAUSE: int = 22             ## default `pause`
const HOPPER_JUMP_X: int = 3             ## default `jump_x`, px per tick
const HOPPER_JUMP_Y: int = 8             ## default `jump_y`, px per tick (height v (v + 1) / 2 = 36 px)
const PATROL_LEFT_TILES: int = -3        ## default `left`
const PATROL_RIGHT_TILES: int = 3        ## default `right`
const PATROL_SPEED: int = 32             ## default `speed`, v16
const PATROL_ACCEL: int = 3              ## v16 per tick: smooth turn-arounds

# =================================================================================================================
# Archetypes 10, 11, 12: burrower, arc leaper, edge rusher [G 5.2]
# =================================================================================================================
const DIGGER_PAUSE: int = 44             ## default `pause`
const DIGGER_SPEED: int = 32             ## default `speed`, v16
## The eight emergence offsets around the hero, used in turn (-120 .. +120 px).
const DIGGER_OFFSETS: Array[int] = [120, -96, 72, -120, 104, -56, 88, -80]
const DIGGER_SCAN_BELOW_ROWS: int = 4    ## floor search starts this many rows below the hero ...
const DIGGER_SCAN_ROWS: int = 10         ## ... and goes up this many rows
const DIGGER_RISE_TICKS: int = 12        ## intangible while rising / sinking [own]
const DIGGER_WALK_TICKS: int = 120       ## walks for about 120 ticks
const LEAPER_SPEED: int = 48             ## default `speed`, v16 (horizontal)
const LEAPER_PAUSE: int = 66             ## default `pause`
const LEAPER_RISE_FACTOR: int = 2        ## default `rise` (upward launch speed) = speed x 2 [own]
const LEAPER_SINK_SHIFT: int = 1         ## default `sink` (glide cap) = speed >> 1 [own]
const LEAPER_HEIGHT_RANDOM: int = 64     ## appears 0..63 px above its anchor
const LEAPER_POISE_TICKS: int = 6        ## intangible wind-up before the leap [own]
const LEAPER_MIN_FLIGHT_TICKS: int = 22  ## not removed for leaving the view before this many ticks [own]
const LEAPER_REST_TICKS: int = 22       ## rests this long after landing before the next leap [own]
const CHARGER_SPEED: int = 64            ## default `speed`, v16

# =================================================================================================================
# Stationary biter [M 2] [own]
# =================================================================================================================
const SNAPPER_RANGE: int = 42            ## default `range`, px: the bite reaches 84 art px forward [M 4]
const SNAPPER_REST_TICKS: int = 22       ## pause between two bites
const SNAPPER_SENSE_DY: int = 40         ## the hero must be within this many px vertically ...
const SNAPPER_SENSE_EXTRA: int = 8       ## ... and within `range` + this many px in front
const SNAPPER_BITE_HEIGHT: int = 20      ## the lunge strip covers the lowest 20 px (bite frames, ASSET_MANIFEST.md 4)

# =================================================================================================================
# Bosses, shared [G 6]
# =================================================================================================================
const BOSS_DROP_DY: int = -16            ## burst items and drops appear this far above the feet point
const BOSS_BOB_SHAKE: int = 4            ## weakest shake of PHYSICS.md 13.3
const BOSS_STOMP_SHAKE: int = 7          ## shake of a heavy boss landing [G 6.1]

# =================================================================================================================
# The Brute [G 6.1] [M 5]
# =================================================================================================================
const BRUTE_HP: int = 64                 ## default `hp`: 8 pips
const BRUTE_HP_PER_PIP: int = 8
const BRUTE_SPEED_CLASS: int = 2         ## default `speed` class 0..4
const BRUTE_SPEED_CLASS_MAX: int = 4
const BRUTE_DEFAULT_REACH_TILES: int = 10  ## arena half width when `left` / `right` are missing [own]
const BRUTE_WAKE_RANGE: int = 250        ## asleep until the hero is within this many px
const BRUTE_ACTIVE_DX: int = 400         ## acts only while the hero is within these distances
const BRUTE_ACTIVE_DY: int = 250
const BRUTE_WATCH_TICKS: int = 110
const BRUTE_SKIP_WATCH_HP: int = 60      ## under this many hit points it stops watching (and turns red)
const BRUTE_POUND_HP: int = 40           ## under this many hit points the high jump becomes a ground pound
const BRUTE_ANGER_PERIOD_MASK: int = 7   ## a swinging hero raises the anger every 8th tick
const BRUTE_ANGER_JUMP: int = 3          ## anger above this: jump routine
const BRUTE_ANGER_ATTACK: int = 10       ## anger at or above this: attack routine
const BRUTE_ANGER_AFTER_JUMP: int = 3
const BRUTE_ANGER_RUSH: int = 11
const BRUTE_ANGER_MAX: int = 255
const BRUTE_ANGER_CALM_BASE: int = 4     ## hitting the hero lowers the anger by (4 - speed class)
const BRUTE_TAUNT_TICKS: int = 44        ## chest-beating
const BRUTE_RUSH_RANGE: int = 75         ## rushes when the hero comes this close while it beats its chest
const BRUTE_HIGH_JUMP_YVEL: int = -224   ## v16: the very high vertical jump (105 px)
const BRUTE_LEAP_DELAY: int = 44         ## ticks between the high jump and the aimed leap (tick 88 of the routine)
const BRUTE_CLOSE_RANGE: int = 80        ## attack / pound instead of leaping when the hero is this close
const BRUTE_LEAP_FAR_PER_CLASS: int = 80 ## farther than speed class x this: long flat leap
const BRUTE_LEAP_YVEL: int = -96         ## v16: flat leap (12 ticks in the air)
const BRUTE_HOP_YVEL: int = -64          ## v16: short hop (about 9 ticks in the air) ...
const BRUTE_HOP_XVEL_PER_PX: int = 2     ## ... aimed: 2 v16 per px of distance (lands near the hero) ...
const BRUTE_HOP_XVEL_MIN: int = 16       ## ... at least 1 px per tick ...
const BRUTE_HOP_XVEL_MAX: int = 128      ## ... at most 8 px per tick
const BRUTE_LEAP_XVEL_BASE: int = 64     ## v16: fastest leap of speed class 0 ...
const BRUTE_LEAP_XVEL_STEP: int = 16     ## ... plus this per speed class
const BRUTE_ATTACK_TICKS: int = 66
const BRUTE_ATTACK_LONG_TICKS: int = 154 ## while the hit points are within 25 of 50
const BRUTE_ATTACK_LONG_HP: int = 50
const BRUTE_ATTACK_LONG_BAND: int = 25
const BRUTE_HOP_RANGE: int = 100         ## farther than this: hops toward the hero
const BRUTE_ATTACK_HOP_YVEL: int = -80   ## v16
const BRUTE_ATTACK_HOP_XVEL_BASE: int = 48   ## v16: hop speed of speed class 0 ...
const BRUTE_ATTACK_HOP_XVEL_STEP: int = 16   ## ... plus this per speed class (class 2 = the hero's 5 px per tick)
const BRUTE_POUND_RANGE: int = 35        ## 25..35 px: ground pound
const BRUTE_PUNCH_RANGE: int = 25
const BRUTE_PUNCH_REST_TICKS: int = 10   ## pause between two punches [own]
const BRUTE_POUND_TICKS: int = 66
const BRUTE_POUND_SOUND_PERIOD: int = 22 ## one quake sound per designer second while pounding [own]
const BRUTE_BACK_HOP_TICKS: int = 44
const BRUTE_BACK_HOP_YVEL: int = -96     ## v16
const BRUTE_BACK_HOP_XVEL: int = 48      ## v16, away from the hero
const BRUTE_STAGGER_MIN_POWER: int = 20  ## a hit stronger than this staggers it
const BRUTE_STAGGER_TICKS: int = 19
const BRUTE_STAGGER_XVEL: int = 48       ## v16, away from the hero
const BRUTE_STAGGER_YVEL: int = -64      ## v16 (-128 when it was falling)
const BRUTE_STAGGER_YVEL_FALLING: int = -128
const BRUTE_DEFEAT_YVEL: int = -240      ## v16: leaps up, then vanishes
const BRUTE_SHAKE_MIN_AIR_TICKS: int = 12  ## only landings after the high jump or a long leap shake [own]
## Sprite boxes (width, height, x_offset) by pose. [M 5]
const BRUTE_BOX_STAND: Vector3i = Vector3i(55, 61, 27)
const BRUTE_BOX_LOW: Vector3i = Vector3i(55, 52, 27)     ## crouch, land, pound
const BRUTE_BOX_BALL: Vector3i = Vector3i(48, 40, 24)    ## roll (leap)
const BRUTE_HEAD_HEIGHT: int = 30        ## the head is the top 30 px of the body box
const BRUTE_HEAD_BACK: int = 29          ## head from 29 px behind ...
const BRUTE_HEAD_FRONT: int = 18         ## ... to 18 px in front of the feet point
const BRUTE_FIST_NEAR: int = 40          ## punching fist: 40..70 px in front ...
const BRUTE_FIST_FAR: int = 70
const BRUTE_FIST_TOP: int = 34           ## ... and 34..20 px above the ground
const BRUTE_FIST_BOTTOM: int = 20
const BRUTE_FIST_FIRST_FRAME: int = 1    ## the fist is out on frames 1..3 of the attack animation (sheet 23..25)
const BRUTE_POUND_NEAR: int = 18         ## pounding fists on the floor: 18..37 px in front ...
const BRUTE_POUND_FAR: int = 37
const BRUTE_POUND_TOP: int = 16          ## ... in the lowest 16 px (pound frames 37 and 39 of the sheet)

# =================================================================================================================
# The Wall Colossus [G 6.3] [M 5]
# =================================================================================================================
const COLOSSUS_HP: int = 24              ## default `hp`: 6 pips of 4 hits
const COLOSSUS_HP_PER_PIP: int = 4
const COLOSSUS_BOX: Vector3i = Vector3i(104, 95, 104)  ## the feet point is the bottom-RIGHT corner [M 5]
const COLOSSUS_RIM_PX: int = 32          ## the stone rim (last 64 art px of a frame) overlaps the wall face [M 5]
const COLOSSUS_WAKE_RANGE: int = 160     ## starts the fight by itself when the hero is this close to its body [own]
## Fairness tuning (wf4 arms_w4): every attack shows its pose at least 10 ticks before anything can touch the hero,
## a hit never cancels or postpones an attack beyond its hurt pose (no stun-lock), the loop opens with a long breath,
## the red rage pose is armoured.
const COLOSSUS_HURT_TICKS: int = 26      ## hurt pose after every hit; also its hit cooldown (was 22 = BOSS_HIT_COOLDOWN)
const COLOSSUS_RAGE_TICKS: int = 40
const COLOSSUS_RAGE_EVERY: int = 4       ## the 1st hit and every 4th hit after it start a rage
const COLOSSUS_RAGE_ROCK_TICK: int = 10  ## one rock (the red open-jaw pose shows for 10 ticks first) ...
const COLOSSUS_RAGE_DROP_TICK_A: int = 18  ## ... and two ceiling drops in quick succession
const COLOSSUS_RAGE_DROP_TICK_B: int = 28
const COLOSSUS_SPIT_TICKS: int = 20      ## length of the spit step
const COLOSSUS_SPIT_RELEASE_TICK: int = 10  ## the rearing open-jaw pose shows 10 ticks before the rock leaves
const COLOSSUS_SLAM_TICKS: int = 16      ## length of the slam step
const COLOSSUS_SLAM_RELEASE_TICK: int = 4  ## the fist meets the wall; the stalactite then rattles (STALACTITE_WARN_TICKS)
## Idle ticks between two attacks, by step of the attack loop (spit, slam, spit, slam, slam). The first one is the
## long breath that opens every loop (and the fight: the first rock leaves 94 ticks after the Colossus wakes). The
## idle clock runs on through hurt poses: hits shorten the breathing, they never stop the attacks.
const COLOSSUS_IDLE_TICKS: Array[int] = [84, 30, 30, 20, 20]
## Idle length in percent by phase: above 16 hit points, above 8, last 8. [own]
const COLOSSUS_PHASE_PERCENT: Array[int] = [100, 75, 50]
const COLOSSUS_PHASE_HP: Array[int] = [16, 8]
## Head rectangles by pose, relative to the feet point (x, y, w, h). [M 5]
const COLOSSUS_HEAD_IDLE: Rect2i = Rect2i(-106, -70, 46, 31)
const COLOSSUS_HEAD_SPIT: Rect2i = Rect2i(-86, -95, 51, 46)
const COLOSSUS_HEAD_SLAM: Rect2i = Rect2i(-123, -60, 48, 36)
const COLOSSUS_HEAD_HURT: Rect2i = Rect2i(-90, -95, 55, 41)
const COLOSSUS_MOUTH: Vector2i = Vector2i(-84, -69)  ## rock spawn point (open jaws) [M 5]
const COLOSSUS_DROP_MARGIN: int = 16     ## ceiling drops keep this distance from the walls and the statue [own]
const COLOSSUS_CEILING_SCAN_ROWS: int = 4

# =================================================================================================================
# Boss projectiles and falling embers [G 6.2] [G 6.3]
# =================================================================================================================
const ROCK_LIFE: int = 132
const ROCK_XVEL_MIN: int = 32            ## v16: spat to the left with a random speed of 32 ...
const ROCK_XVEL_STEP: int = 8            ## ... plus 0..8 steps of 8 (up to 96: 6 px per tick) [own, wf4]
const ROCK_XVEL_STEPS: int = 9
const ROCK_BOX: Vector3i = Vector3i(10, 10, 5)
const ROCK_FRICTION_SHIFT: int = 3       ## every floor bounce takes an eighth of the horizontal speed [own]
const ROCK_SETTLE_REBOUND: int = 48      ## v16: a smaller rebound ends the bouncing (two hops after the arc) [own, wf4]
const ROCK_REST_TICKS: int = 10          ## once it stops bouncing it rolls on this long, then crumbles [own, wf4]
const ROCK_ANIM_TICKS: int = 2           ## spin, 12 fps [M 9]
const ROCK_FRAMES: int = 4
const STALACTITE_LIFE: int = 66
const STALACTITE_WARN_TICKS: int = 14    ## rattles at the ceiling before it falls [own, wf4: was 10]
const STALACTITE_BOX: Vector3i = Vector3i(10, 20, 5)
const STALACTITE_SHAKE_ART_PX: int = 2   ## cosmetic rattle amplitude, art px
const EMBER_DROP_ABOVE_HERO: int = 150   ## falls from 150 px above the hero ...
const EMBER_DROP_SPREAD: int = 124       ## ... with a random x offset of up to 124 px
const EMBER_SPEED_MIN: int = 1           ## px per tick
const EMBER_SPEED_MAX: int = 4
const EMBER_MAX_ALIVE: int = 5
const EMBER_PERIOD: int = 22             ## default `period` of an ember rain emitter [own]
const EMBER_SWAY_PX: int = 6             ## sways this far to each side [own]
const EMBER_SWAY_STEP_TICKS: int = 2     ## one px of sway every 2 ticks [own]
const EMBER_LIFE: int = 198
const EMBER_BOX: Vector3i = Vector3i(10, 8, 5)
const EMBER_ANIM_TICKS: int = 4          ## sway, 6 fps [M 9]
const LEAF_ANIM_TICKS: int = 6           ## sway, 4 fps [M 9]
