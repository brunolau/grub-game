class_name Tuning
extends RefCounted
## Single source of truth for game feel.
##
## Every number of docs/spec/PHYSICS.md (Appendix A and the sections cited on each line) and the shared numbers
## of docs/spec/GAMEPLAY.md, in ORIGINAL UNITS:
##   px   = logical pixel (the original 320-wide screen; 1 tile = 16 px)
##   v16  = velocity in 1/16 px per tick
##   tick = one simulation step (1 / TICK_HZ seconds)
## Never convert these to seconds or floats inside the simulation (ARCHITECTURE.md 4). No other script may
## hard-code a physics number: reference the constant here, or add one (core module owns this file; other
## modules request additions through their report).
##
## Marks: [P n] = PHYSICS.md section n, [G n] = GAMEPLAY.md section n, [M n] = ASSET_MANIFEST.md section n.

# =================================================================================================================
# Timebase [P 1]
# =================================================================================================================
## Simulation rate: 1193182 Hz / 16384 (timer reload) / 3 (timer ticks per frame) = 24.2753 Hz. [P 1.2]
## Tunable between 23.33 and 24.275 without touching any rule.
const TICK_HZ: float = 1193182.0 / 49152.0
## Seconds per tick (41.194 ms).
const TICK_DT: float = 49152.0 / 1193182.0
## Catch-up ticks allowed per rendered frame before the accumulator is dropped. [P 15.1 #2]
const MAX_CATCHUP_TICKS: int = 4
## "22 ticks = one designer second" (data timers are multiples of 22). [P 1.1 #6]
const DESIGNER_SECOND: int = 22

# =================================================================================================================
# Screen, world, art scale [P 2] [M 1]
# =================================================================================================================
const TILE: int = 16                 ## tile size in logical px [P 2]
const ART_SCALE: int = 2             ## art px per logical px [M 1] [P 15.3]
const TILE_ART: int = 32             ## tile size in art px (TileMapLayer cell) [M 1]
const VIEW_W: int = 320              ## base view width in logical px (640 art px) [M 1]
const VIEW_H: int = 180              ## base view height in logical px (360 art px) [M 1]
const VIEW_COLS: int = 20            ## visible tile columns of the original, camera rules are relative to it [P 12]
const VIEW_ROWS: int = 11            ## visible tile rows of the original [P 12]
const MAP_MAX_COLS: int = 256        ## maximum level width in tiles [P 2]
const MAP_MAX_ROWS: int = 192        ## maximum level height in tiles (original: 173) [G 1.1]
const X_MIN: int = 8                 ## hero x commit rule lower bound (inclusive) [P 2]
const X_MAX_EXCL: int = 4088         ## hero x commit rule upper bound (exclusive) [P 2]

# =================================================================================================================
# Horizontal movement [P 5.1]
# =================================================================================================================
const ACCEL: int = 16                ## v16 per tick, shifted right by ice [P 5.1]
const FRICTION: int = 12             ## v16 per tick, shifted right by ice [P 5.1]
const WALK_CAP: int = 80             ## v16 = 5 px/tick [P 5.1]
const CRAWL_CAP: int = 32            ## v16 = 2 px/tick [P 5.1]
const JUMP_HELD_CAP: int = 48        ## v16; jump handler accelerates only while 0 <= xvel < 48 (unsigned test) [P 6.1]
const LEFT_FLOOR: int = -96          ## v16; WIND clamps leftward speed to this [P 5.1]
const WIND_SHIFT: int = 3            ## WIND: xvel -= wind >> 3 [P 5.1]
const ICE_MAX: int = 3               ## ice level 0..3; ACCEL and FRICTION are shifted right by it [P 7]
const SKID_MIN_XVEL: int = 8         ## |xvel| >= 8 with no input: skid pose [P 5.5]
const SKID_DUST_PERIOD: int = 4      ## dust puff every 4th tick while skidding [P 5.5]
const BREATH_IDLE_MIN: int = 30      ## idle_timer >= 30: out-of-breath animation [P 5.5]
const BREATH_IDLE_DECAY: int = 3     ## idle_timer -= 3 per tick while panting [P 5.5]
const IDLE_TIMER_MAX: int = 255      ## [P 5.2]

# =================================================================================================================
# Jump, gravity, falling [P 6]
# =================================================================================================================
## yvel += JUMP_IMPULSES[n] on jump tick n (0-based) while n < 9; sum -189. [P 6.1]
const JUMP_IMPULSES: Array[int] = [-65, -51, -35, -20, -10, -5, -2, -1, 0]
const JUMP_IMPULSE_TICKS: int = 9    ## after this many jump ticks the handler applies gravity instead [P 6.1]
const GRAVITY: int = 16              ## v16 per tick [P 6.2]
const TERMINAL: int = 192            ## v16 = 12 px/tick [P 6.2]
const NO_JUMP_TICKS: int = 6         ## no_jump set while falling; counts down on grounded ticks [P 6.3 / 6.4]
const IDLE_AIR_SECOND_WIND_AFTER: int = 4  ## idle handler, airborne: second WIND when jump_ticks > 4 [P 5.2]
const FALL_WIDE_SPRITE_TICKS: int = 12     ## wider falling box once fall_ticks >= 12 [P 6.3]

# Landing [P 6.5]
const SOFT_LANDING_MAX_FALL_TICKS: int = 4       ## fall_ticks <= 4: soft landing, no dust
const DROP_MIN_PX: int = 32                      ## landed >= 32 px below last_ground_y ...
const DROP_MIN_YVEL: int = 80                    ## ... with yvel >= 80 counts as a drop
const HARD_LANDING_MIN_FALL_TICKS_EXCL: int = 10 ## drop with fall_ticks > 10: hard landing
const HARD_LANDING_HOP: int = -32                ## v16: 3 px hop, 4 airborne ticks
const SHAKE_MIN_FALL_TICKS: int = 20             ## drop with fall_ticks >= 20 ...
const SHAKE_MIN_YVEL_EXCL: int = 160             ## ... and yvel > 160: screen shake
const SHAKE_LANDING: int = 8                     ## shake value of a heavy landing

# =================================================================================================================
# Tile collision [P 11]
# =================================================================================================================
const WALL_PROBE: int = 9            ## px ahead of the feet point, in the row above the feet row [P 11.2 #7]
const HEAD_PROBE_ROWS: int = 2       ## ceiling tested at (col, row - 2) [P 11.2 #5]
const CORNER_SLIP: int = 2           ## px per tick out of a wall [P 11.2 #5]
const DROP_TIMER: int = 4            ## ticks set by crouch / crawl; hatches are open while > 0 [P 7]
const HERO_PROBE_H_STAND: int = 35   ## body-probe height standing: rows row-2, row-3 [P 11.2 #8]
const HERO_PROBE_H_CROUCH: int = 30  ## body-probe height crouching: row row-2 only [P 11.2 #8]
const DEATH_ROWS_FROM_CAMERA: int = 11  ## feet row further than this from the camera row: death [P 10.3]
const DEATH_COLS_FROM_CAMERA: int = 20  ## feet column further than this from the camera column: death [P 10.3]
const PIT_DEPTH_PX: int = 16         ## y more than one tile below the map bottom: death [P 10.3]

# =================================================================================================================
# Sprite-overlap test [P 2.2] and hero boxes [P 2.1]
# =================================================================================================================
const OVERLAP_MAX_DX: int = 64       ## reject when |A.x - B.x| >= 64
const OVERLAP_MAX_DY: int = 70       ## reject when |A.y - B.y| >= 70
const STOMP_MIN_YVEL: int = 128      ## hero.yvel >= 128 (8 px/tick): any contact is a stomp

# Hero sprite boxes: width, height, x_offset (left = x - x_offset, top = y - height). These are the ORIGINAL
# frame boxes and are authoritative for contacts; our art (stand 22 x 28) fits inside them. [P 2.1] [M 3]
const HERO_BOX_STAND: Vector3i = Vector3i(32, 35, 15)
const HERO_BOX_JUMP_UP: Vector3i = Vector3i(32, 38, 16)
const HERO_BOX_JUMP_TOP: Vector3i = Vector3i(40, 31, 20)
const HERO_BOX_FALL: Vector3i = Vector3i(40, 31, 20)
const HERO_BOX_FALL_LONG: Vector3i = Vector3i(48, 31, 24)   ## fall_ticks >= FALL_WIDE_SPRITE_TICKS
const HERO_BOX_CROUCH: Vector3i = Vector3i(40, 30, 20)
const HERO_BOX_HURT: Vector3i = Vector3i(48, 32, 24)
const HERO_BOX_RIDE: Vector3i = Vector3i(32, 35, 16)        ## platform ride test, always this box [P 11.4]
## Jump ticks shown with HERO_BOX_JUMP_UP (the tall rising frame) before HERO_BOX_JUMP_TOP. [P 2.1]
const HERO_JUMP_TALL_BOX_TICKS: int = 4
# Boxes measured from our art, for QA comparison only (do not ship both). [M 3]
const HERO_ART_BOX_STAND: Vector3i = Vector3i(22, 28, 11)
const HERO_ART_BOX_CROUCH: Vector3i = Vector3i(24, 22, 12)

# =================================================================================================================
# State table [P 4.3]
# =================================================================================================================
## Index = (RIGHT << 4) | (LEFT << 3) | (UP << 2) | (DOWN << 1) | FIRE = flags & Defs.IN_STATE_MASK.
## Value = Defs.HeroState. Byte-identical in both reference sources.
const STATE_LUT: Array[int] = [
	0, 3, 5, 7, 2, 6, 0, 0,
	1, 3, 4, 7, 2, 6, 1, 0,
	1, 3, 4, 7, 2, 6, 0, 0,
	0, 0, 0, 0, 0, 0, 0, 0,
]

# =================================================================================================================
# Club attack [P 8]
# =================================================================================================================
## Club-box frames. NONE = no box this tick.
enum ClubFrame {
	NONE = -1, FWD_WINDUP = 0, OVERHEAD = 1, FWD_FRONT = 2, HIGH_LOWBACK = 3, HIGH_BACKUP = 4, HIGH_FRONT = 5,
	LOW_BACK = 6, LOW_FRONT = 7,
}
## Strike scripts: one ClubFrame per tick. [P 8.1]
const STRIKE_SCRIPT_FORWARD: Array[int] = [0, 0, 1, 1, 2, 2, 2]
const STRIKE_SCRIPT_HIGH: Array[int] = [3, 3, 3, 4, 4, 4, 5, 5, 5]
const STRIKE_SCRIPT_LOW: Array[int] = [6, 6, 6, 1, 1, 1, 7, 7, 7]
## Hop applied on the last strike tick (skipped on a platform): forward, high, low. [P 8.1]
const STRIKE_HOP_FORWARD: int = -32
const STRIKE_HOP_HIGH: int = 0
const STRIKE_HOP_LOW: int = -48
## Default club boxes by ClubFrame, facing right, relative to the feet point: Rect2i(x0, y0, w, h). [P 8.2]
## Facing left: mirror the ORIGIN's x and keep the same x_offset (origin.x - x0), see [P 8.2].
const CLUB_BOX: Array[Rect2i] = [
	Rect2i(-19, -35, 16, 19),  # FWD_WINDUP   x -19..-3,  y -35..-16
	Rect2i(-19, -43, 24, 18),  # OVERHEAD     x -19..+5,  y -43..-25
	Rect2i(11, -15, 24, 13),   # FWD_FRONT    x +11..+35, y -15..-2
	Rect2i(-19, -19, 16, 16),  # HIGH_LOWBACK x -19..-3,  y -19..-3
	Rect2i(-16, -37, 16, 16),  # HIGH_BACKUP  x -16..0,   y -37..-21
	Rect2i(10, -43, 16, 16),   # HIGH_FRONT   x +10..+26, y -43..-27
	Rect2i(-16, -33, 16, 15),  # LOW_BACK     x -16..0,   y -33..-18
	Rect2i(-3, -5, 24, 15),    # LOW_FRONT    x -3..+21,  y -5..+10
]
## Box origin (bottom anchor of the club sprite) by ClubFrame; used by the hidden-tile test. [P 8.2 / 8.3]
const CLUB_ORIGIN: Array[Vector2i] = [
	Vector2i(-11, -16), Vector2i(-7, -25), Vector2i(23, -2), Vector2i(-11, -3),
	Vector2i(-8, -21), Vector2i(18, -27), Vector2i(-8, -18), Vector2i(9, 10),
]
## Hammer front box (reference extent, re-author for our art): x +2..+50, y -16..+10, origin (+26, +10). [P 8.2]
const HAMMER_FRONT_BOX: Rect2i = Rect2i(2, -16, 48, 26)
const HAMMER_FRONT_ORIGIN: Vector2i = Vector2i(26, 10)

## Per weapon (index = Defs.Weapon): power, swing_lock, thrown. [P 8.1] The fifth entry is the 2.0 spear
## (SPEAR_POWER, SPEAR_LOCK below, DESIGN.md C.2).
const WEAPON_POWER: Array[int] = [25, 30, 20, 30, 25]
const WEAPON_LOCK: Array[int] = [2, 6, 6, 12, 6]
const WEAPON_THROWN: Array[bool] = [false, false, true, true, true]
const CHARGE_STEP: int = 2           ## per crouch / crawl tick while charge <= CHARGE_STEP_MAX_AT [P 8.5]
const CHARGE_STEP_MAX_AT: int = 48
const CHARGE_MULTIPLIER: int = 4     ## power x4 while charge > 0 [P 8.5]

# Thrown weapons [P 8.4]
const THROW_XVEL: int = 208          ## v16 = 13 px/tick, signed by facing
const AXE_YVEL: int = -64            ## v16 at spawn
const AXE_YACC: int = 32             ## v16 per tick (arc)
const BOOMERANG_YVEL: int = -32      ## v16 at spawn (the original "swirling axe")
const BOOMERANG_YACC: int = -16      ## v16 per tick (curves upward)
const MAX_THROWN: int = 4            ## in flight at once

# Hidden-tile test of the weapon pass [P 8.3 #2]
const HIDDEN_HIT_COLS: int = 1       ## |tile_col - (origin.x >> 4)| <= 1
const HIDDEN_HIT_PX: int = 16        ## |tile_row * 16 - (origin.y - 16)| < 16

# =================================================================================================================
# Bounces and damage [P 9] [P 10]
# =================================================================================================================
const BOUNCE_YVEL: int = -64         ## enemy bounce, UP not held (rise 10 px) [P 9]
const BOUNCE_YVEL_UP: int = -224     ## enemy bounce, UP held (rise 105 px) [P 9]
const POGO_YVEL: int = -80           ## club hit while yvel != 0 (rise 15 px) [P 9]
const GLIDER_BUMP_YVEL: int = -96    ## glider bump / dive stomp [P 9]
const GLIDER_DIVE_MIN_YVEL_EXCL: int = 32  ## gliding with yvel > 32 = dive stomp [P 9]
const GLIDER_DIVE_KILLS_ON: int = 3  ## the 3rd dive stomp kills [P 9]
const BOSS_BOUNCE_YVEL: int = -64    ## boss head [P 9]
const BOSS_BOUNCE_YVEL_UP: int = -128
const BOSS_LAUNCH_YVEL: int = -160   ## boss fist launch [P 9]
const BARRIER_YVEL: int = -144       ## invisible arena barrier knock-back [P 12.4]
const BARRIER_XVEL: int = -160

const HURT_YVEL: int = -128          ## knock-up (rise 36 px) [P 10.1]
const HURT_XVEL_FACTOR: int = -4     ## xvel = -(xvel * 4) [P 10.1]
const BOSS_KNOCK_XVEL: int = 128     ## boss body hit: xvel = +/-128 with ice = 3 [P 10.1]
const HIT_TIMER: int = 44            ## set on a hit; contact immunity while > 0 [P 10.1]
const HIT_STUN_MIN: int = 22         ## hurt state (no control) while hit_timer >= 22 [P 10.1]
const BLINK_PERIOD: int = 4          ## drawn 1 tick in 4 while hit_timer > 0 [P 10.1]
const ENERGY_START: int = 3          ## hearts on every (re)spawn; also the maximum [P 10.2]
const BONES_PER_HEART: int = 6       ## [P 10.2] [G 4.2]
const LIVES_START: int = 2           ## spare lives at game start [P 10.2]
const LIVES_MAX: int = 99            ## [P 10.2]
const EXTRA_LIFE_EVERY: int = 250000 ## displayed points [G 3.6]

# Death sequence [P 10.4]
const DEATH_ANIM_TICKS: int = 60
const DEATH_DX: int = 5              ## px per tick toward the screen centre
const DEATH_VY_START: int = -14      ## px per tick (not v16), +1 per tick ...
const DEATH_VY_MAX: int = 16         ## ... up to 16 px per tick downward

# =================================================================================================================
# Hang-glider [P 13.2]
# =================================================================================================================
const GLIDE_GRAVITY: int = 4         ## v16 per tick while gliding
const GLIDE_CAP: int = 24            ## v16 sink cap (1 px/tick)
const GLIDER_RUNUP_MIN_XVEL: int = 64
const GLIDER_RUNUP_TICKS: int = 24
const GLIDER_TAKEOFF_DY: int = -3    ## px
const GLIDER_LIFT_START: int = 24
const GLIDER_CLIMB_YVEL: int = -64   ## while lift > 0 and tilt >= GLIDER_CLIMB_MIN_TILT
const GLIDER_CLIMB_MIN_TILT: int = 4
const GLIDER_TILT_MAX: int = 6
const GLIDER_AUTO_OPEN_YVEL_EXCL: int = 160  ## falling faster than this opens the glider
const GLIDER_LIFT_REFILL_MAX_FACTOR: int = 5 ## lift refills up to 5 x |floor16(xvel)| [P 13.2, INFERRED]
## Nose at rest; the tilt returns to it by 1 per tick while neither UP nor DOWN is held. [P 13.2]
const GLIDER_TILT_NEUTRAL: int = 3
const GLIDER_STALL_MIN_YVEL_EXCL: int = 16  ## nose fully up and sinking faster than this: full gravity (stall) [P 13.2]

# =================================================================================================================
# Screen shake, feast, wind [P 13]
# =================================================================================================================
const SHAKE_NUDGE: int = 3           ## hero lifted this many px on odd ticks while shake > 1 [P 13.3]
const SHAKE_VALUES: Array[int] = [4, 7, 8, 9]  ## values used by landings, traps, columns, bosses [P 13.3]
const FEAST_TICKS: int = 660         ## [P 13.4] [G 8.3]
const FEAST_WARN_TICKS_BEFORE_END: int = 7     ## a shake warns before the feast ends [G 8.3]
const FEAST_WARN_SHAKE: int = 9                ## strength of that warning shake [G 8.3]

# =================================================================================================================
# Platforms [P 11.4]
# =================================================================================================================
const PLATFORM_RIDE_MIN_YVEL_EXCL: int = -16   ## ride test only while hero.yvel > -16
## Fast landings on sprite platforms (our fix, not in the original): from this fall speed (8 px/tick) the ride test's
## contact band reaches PLATFORM_CATCH_DEPTH px below the surface instead of the platform's 8 px, so a hero who
## steps across the 8 px band in one tick (up to the 12 px/tick terminal speed) still lands.
const PLATFORM_CATCH_YVEL: int = 128
const PLATFORM_CATCH_DEPTH: int = 16
const PLATFORM_ACCEL: int = 1        ## px/tick per tick toward the target speed (movers)
const DROPPER_ACCEL: int = 8         ## v16 per tick
const DROPPER_MAX: int = 192         ## v16
const DROPPER_REST_TICKS: int = 22   ## hero off the platform this long before it returns
const DROPPER_RETURN_SPEED: int = 8  ## px per tick upward
const MAX_PLATFORMS: int = 16
const MAX_PLATFORMS_ON_SCREEN: int = 7

# =================================================================================================================
# Camera [P 12]
# =================================================================================================================
const CAM_RIGHT_START: int = 16      ## page right when the hero's screen column >= 16 (of 20) [P 12.1]
const CAM_LEFT_START: int = 4        ## page left when <= 4
const CAM_RIGHT_STOP: int = 5        ## paging right stops when the hero is in column <= 5
const CAM_LEFT_STOP: int = 15        ## paging left stops when >= 15
const CAM_IDLE_SPLIT: int = 10       ## xvel == 0 on a platform: candidate right if sc >= 10
const CAM_STEP_PX: int = 16          ## one tile per tick
const CAM_LOOK_MIN_SC: int = 2       ## look-around right continues while sc > 2 [P 12.3]
const CAM_LOOK_MAX_SC: int = 17      ## look-around left continues while sc < 17
const CAM_SPAWN_SHIFT_MIN_SC: int = 12   ## at spawn: if sc >= 12, move right up to ... [P 12.5]
const CAM_SPAWN_SHIFT_MAX_COLS: int = 10 ## ... 10 columns
const CAM_SPAWN_V_STEP: int = 16     ## fixed vertical step while settling at spawn [P 12.5]
# Vertical targets (hero screen row sr, of 11) [P 12.2]
const CAM_V_AIR_LOW_SR: int = 9      ## airborne, sr >= 9  -> target row 3
const CAM_V_AIR_LOW_TARGET: int = 3
const CAM_V_AIR_HIGH_SR: int = 2     ## airborne, sr <= 2  -> target row 8
const CAM_V_AIR_HIGH_TARGET: int = 8
const CAM_V_GROUND_LOW_SR: int = 10  ## grounded, sr >= 10 -> target row 9
const CAM_V_GROUND_LOW_TARGET: int = 9
const CAM_V_GROUND_HIGH_SR: int = 3  ## grounded, sr <= 3  -> target row 8
const CAM_V_GROUND_HIGH_TARGET: int = 8
const CAM_V_ALT_LOW_SR: int = 8      ## levels with Defs.SCROLL_LOW_BAND: sr >= 8 -> 7
const CAM_V_ALT_LOW_TARGET: int = 7
const CAM_V_ALT_HIGH_SR: int = 5     ## sr <= 5 -> 6
const CAM_V_ALT_HIGH_TARGET: int = 6
const CAM_V_MAX_DISTANCE: int = 131  ## no vertical step outside 0..131 px [P 12.2 #5]
const CAM_AUTOSCROLL_PX: int = 1     ## auto-scroll levels: 1 px per tick [P 12.2 #1]
## Vertical speed curves as (inclusive upper distance, px per tick) runs. [P 12.2 #5]
## SLOW = all visible tiles opaque; FAST = a backdrop shows through the tile layer.
const CAM_V_SLOW_LIMITS: Array[int] = [5, 23, 50, 63, 72, 79, 85, 88, 91, 93, 95, 96, 97, 98, 131]
const CAM_V_SLOW_SPEEDS: Array[int] = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 16]
const CAM_V_FAST_LIMITS: Array[int] = [3, 7, 9, 11, 12, 13, 14, 15, 19, 26, 35, 48, 65, 89, 99, 131]
const CAM_V_FAST_SPEEDS: Array[int] = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
## Non-original smooth follow (accessibility option only): hero kept between these view px. [P 12.6]
const CAM_SMOOTH_MARGIN: int = 128
## Dozing (ARCHITECTURE.md 11, not original - it changes no outcome): an idle entity whose area lies farther than
## DOZE_HERO_REACH_PX from the hero's box and feet point and farther than DOZE_VIEW_REACH_PX from the view is taken
## out of the tick. The hero reach covers the body-overlap reach (OVERLAP_MAX_DY = 70 px between feet points) plus
## the most the hero can move between a decision and a contact test: 18 px per tick measured over every route, and a
## spring's or a head's bounce lift (up to a hero box height) earlier in the same phase; teleports decide again at
## once. The view reach is the enemy activation margin: the view is read only by the wake rule of asleep enemies
## (ENEMY_SPAWN_MARGIN_PX), in phase ENEMIES, with the view of the last decision. [own]
## A party (2.0): the reach applies to every hero; a party move faster than 18 px per tick (a throw, a launch, an
## egg's return, a leash pull) calls LevelBase.notify_hero_teleported (PartyTuning.MOVE_MAX_PX_PER_TICK).
const DOZE_HERO_REACH_PX: int = 128
const DOZE_VIEW_REACH_PX: int = ENEMY_SPAWN_MARGIN_PX
## Both doze rectangles are rounded outwards to this grid, so they are only looked at again when they cross a line.
const DOZE_GRID_PX: int = 64

# =================================================================================================================
# Enemies, items, scoring (shared numbers) [G 3] [G 4] [G 5] [G 6]
# =================================================================================================================
const MAX_ACTIVE_ENEMIES: int = 12   ## [G 5.1]
const MAX_ENEMY_RECORDS: int = 150   ## per level [G 5.1]
const ENEMY_SPAWN_MARGIN_PX: int = 32  ## activates within about 2 tiles of the visible area [G 5.1]
const ENEMY_DESPAWN_EXTRA_Y: int = 124 ## despawn beyond one screen horizontally or screen + 124 px vertically [G 5.1]
const ENEMY_GRAVITY: int = 16        ## v16 per tick [G 5.1]
const ENEMY_TERMINAL: int = 256      ## v16 [G 5.1]
const ENEMY_KNOCKBACK_SHIFT: int = 2 ## survivor pushed back by its own xvel >> 2 px [P 8.3]
const ENEMY_SOFT_GRAVITY: int = 8    ## arc leaper glide [G 5.2]
const EDGE_RUSHER_OFFSCREEN_TICKS: int = 154  ## [G 5.2]
const BOUNCE_COUNT_MAX: int = 11     ## [G 3.3]
## Score multiplier by head-bounce count 0..11. [G 3.3]
const BOUNCE_MULTIPLIER: Array[int] = [1, 1, 2, 2, 3, 3, 4, 4, 6, 6, 8, 8]
## Displayed-score ladder; enemy records and items store an index into it. [G 3.1]
const SCORE_LADDER: Array[int] = [
	100, 200, 300, 500, 600, 700, 750, 800, 1000, 2000, 5000, 8000, 10000, 20000, 30000, 60000, 100000,
]
const GLIDER_DIVE_SCORES: Array[int] = [1000, 5000, 10000]  ## [G 3.3]
const LETTER_COUNT: int = 5          ## G-R-U-B-S [G 12.3]
const LETTERS_JACKPOT: int = 100000  ## [G 4.3]
const LETTERS_BLINK_TICKS: int = 44  ## [G 2]
const FEAST_PIECES: int = 3          ## bowl, flint, log [M 7]
const MAX_PLACED_ITEMS: int = 70     ## per level [G 4.1]
const MAX_ACTIVE_ITEMS: int = 20     ## on screen at once [G 4.1]
const ITEM_BOB_PX: int = 3           ## placed items bob about 3 px [G 4.1]
const DROPPED_ITEM_LIFE: int = 198   ## ticks [G 4.2]
const DROPPED_ITEM_BLINK: int = 15   ## blinks for the last 15 ticks [G 4.2]
const DROPPED_ITEM_NO_PICKUP: int = 10  ## cannot be picked up during its first 10 ticks [G 4.2]
const SCORE_POPUP_TICKS: int = 44    ## rises 1 px per tick [G 2]
const MAX_HIDDEN_SPOTS: int = 80     ## per level [G 4.4]
const HIDDEN_SPOT_HIT_COOLDOWN: int = 6 ## at most one item per 6 ticks [G 4.4]
const GIANT_BONUS_DROP_PX: int = 112 ## falls from this far above the spot / hero [G 4.3 / 4.4]
const GRENADE_ITEMS_PER_ENEMY: int = 16 ## [G 3.4]
const BOSS_BURST_ITEMS: int = 64     ## [G 6]
const BOSS_HIT_COOLDOWN: int = 22    ## boss hits count at most once per 22 ticks [G 6.1]
const BOSS_BAR_MAX_PIPS: int = 8     ## [G 2]
const TALLY_ITEM_PERIOD: int = 8     ## one item every 8 ticks at the tally [G 3.7]
const DARKNESS_FADE_TICKS: int = 22  ## palette fade length (one designer second) [G 7.10, INFERRED]
const COLUMN_RISE_PERIOD: int = 4    ## rising columns: one tile every 4 ticks [G 7.4]
const TILE_ANIM_TICKS: int = 4       ## animated tiles: 4 ticks per frame [G 7.1]
const MAX_FLIES: int = 20            ## cosmetic flies around a hero who walked over dirty ground [G 7.9]
## Sprite animation speeds of the manifest (frames per second) are converted to tick counts with this rate (the
## tick rate rounded to whole frames; cosmetic only). [M 1]
const ANIM_TICKS_PER_SECOND: int = 24
## v16 of a speed of 1 px per tick: converts level parameters given in px per tick (enemy catalogue). [P 2]
const V16_PER_PX: int = 16

# =================================================================================================================
# 2.0 expansion: Book II hero and world rules (docs/expansion/DESIGN.md C; the PHYSICS.md appendix "Party and
# Book II rules" of PLAN.md P0.2 takes them over). Appended only: Book I never reads them. Co-op numbers live in
# [PartyTuning], versus numbers in [VersusTuning], mount numbers in MountTuning (player), Book II enemy and boss
# numbers in EnemyTuning (enemies). [D x] = DESIGN.md section x; (tune) = a playtest starting value, changed only
# through DESIGN.md.
# =================================================================================================================
# Weapon belt and Swap [D C.1]
const SWAP_LOCKOUT_TICKS: int = 8        ## after a swap the next one waits this long (tune)
# Spear and bark boards [D C.2]
const SPEAR_XVEL: int = 192              ## v16: thrown flat at 12 px/tick, signed by facing ...
const SPEAR_FLAT_TICKS: int = 8          ## ... for this many ticks, then it drops ...
const SPEAR_YACC: int = 16               ## ... gaining this many v16 per tick
const SPEAR_POWER: int = 25
const SPEAR_LOCK: int = 6                ## recovery ticks after a throw
const SPEAR_MAX_PER_HERO: int = 2        ## in flight or stuck; a third throw pulls out the oldest
const SPEAR_FALL_MAX: int = 192          ## v16: the drop gains SPEAR_YACC per tick up to this [P C.3]
const SPEAR_BOX_W: int = 24              ## the flying spear's box 24 x 6, x_offset 12 (tune with the art) [P C.3]
const SPEAR_BOX_H: int = 6
const SPEAR_BOX_XO: int = 12
const BARK_BOARD_STEP_TICKS: int = 220   ## a spear stuck in a bark board is a one-way step this long ...
const BARK_BOARD_BLINK_TICKS: int = 22   ## ... blinking for its last 22 ticks, then it falls
const BARK_BOARD_STEP_W: int = 16        ## px: width of that one-way step
# Vines [D C.3]
const VINE_GRAB_DX: int = 6              ## px: Up grabs a vine while the feet column is this close to it
const VINE_HAND_REACH_PX: int = 32       ## px: the hands reach a vine whose bottom is at most this far above the feet [P C.4]
const VINE_CLIMB_UP_PX: int = 2          ## px per tick
const VINE_CLIMB_DOWN_PX: int = 3        ## px per tick
const VINE_JUMP_YVEL: int = -128         ## v16: a direction + Up leaps off with launch(+/-VINE_JUMP_XVEL, this) [R14] ...
const VINE_JUMP_XVEL: int = 32           ## ... toward the held direction
const VINE_REGRAB_LOCK_TICKS: int = 12   ## after a leap or a drop the same vine cannot be grabbed this long (tune) [P C.4]
const VINE_TOP_STEP_PX: int = 12         ## px: climbing over the top steps this far onto the ledge beside it [P C.4]
# Tar floor `:` (honey / syrup are its Feast Land skins) [D C.4]
const TAR_SURFACE_DROP_PX: int = 6       ## the surface lies this much lower (TileGrid lowered-surface profile)
const TAR_WALK_CAP: int = 32             ## v16 = 2 px/tick for heroes and ground enemies (Chomper excepted)
const TAR_JUMP_IMPULSE_TICKS: int = 2    ## jump thrust only on the first 2 jump ticks: a 33 px hop (tune) [R2] [P C.5]
const TAR_AIR_CAP: int = 32              ## v16: ACCEL limit of the airborne step after a take-off from tar (tune) [R2]
# Geysers [D C.4]
const GEYSER_BUBBLE_TICKS: int = 22      ## the telegraph (with sound) before every spout
const GEYSER_SPOUT_TICKS: int = 12
const GEYSER_POWER: int = -224           ## v16: default launch of heroes, enemies, rafts and drop platforms
const GEYSER_PERIOD: int = 88            ## ticks: default cycle of objects/geyser `period` (tune) [P C.6] ...
const GEYSER_PERIOD_MIN: int = GEYSER_BUBBLE_TICKS + GEYSER_SPOUT_TICKS  ## ... never shorter than its telegraph + spout
const GEYSER_VENT_W: int = 24            ## px: the vent box above the anchor floor (24 x 16) [P C.6]
const GEYSER_VENT_H: int = 16
const GEYSER_DEADLY_H: int = 64          ## px: a `deadly` vent's spout box is 24 x 64 above the vent (tune) [P C.6]
# Rafts and currents [D C.5]
const RAFT_WIDTHS: Array[int] = [3, 4]   ## cells (objects/raft width=)
const CURRENT_SPEED_MIN_PX: int = 1      ## zones/current speed range, px per tick
const CURRENT_SPEED_MAX_PX: int = 3
const RAFT_DRAG_PERIOD: int = 8          ## outside a current a raft loses 1 px/tick of speed every 8 ticks
const RAFT_PADDLE_V16: int = 16          ## a forward strike on a raft pushes it backward by this ...
const RAFT_PADDLE_MAX_PX: int = 3        ## ... up to 3 px/tick
const RAFT_DIP_PX: int = 2               ## a raft dips this much under each rider (visual only)
const RAFT_SPEED_CAP: int = RAFT_PADDLE_MAX_PX * V16_PER_PX  ## v16: the raft's own speed `rx` stays within +/-48 [P C.7]
const RAFT_HEIGHT_PX: int = 8            ## px: a raft is 16 * width x 8 (tune) [P C.7] ...
const RAFT_FLOAT_DEPTH_PX: int = 4       ## ... floating with its bottom this far below the top of its `~` cell
# Rising tide [D C.6]
const RISE_SPEED: int = 16               ## v16: default `rise_speed` of `scroll = rising` (1 px/tick)
const RISE_CHECKPOINT_ROWS: int = 6      ## a checkpoint resets the deadly band to this many rows under itself
# Rules shared by several modules [D B.0] [D C.9]
const TELEGRAPH_MIN_TICKS: int = 10      ## every boss attack and versus hazard shows itself at least this early
const PAINTING_COUNT: int = 30           ## items/painting index 0..29: 0-19 Book II levels, 20-29 Book I co-op
const PAINTING_BOOK2_COUNT: int = 20
const PAINTING_POINTS: int = 5000        ## displayed points per painting
## Paintings found (per profile, across modes) that unlock each reward. [D C.9] The ladder after cut 3 (DESIGN.md
## G60: Mesa Rodeo and Cloud Top are not in 2.0, so no arena is a reward).
const PAINTING_UNLOCK_PATTERNS: int = 5       ## four loincloth patterns for P1-P4 (checks, dots, tiger, pinstripes)
const PAINTING_UNLOCK_LOINCLOTHS: int = 10    ## four more (diamonds, waves, sash, trim)
const PAINTING_UNLOCK_VARIANTS: int = 15      ## Big Bounce, Lights Out, Giant Rain
const PAINTING_UNLOCK_SPEAR_PARTY: int = 20   ## the Spear Party variant
const PAINTING_UNLOCK_GOLD: int = 25          ## the golden loincloth palette
const PAINTING_UNLOCK_MURAL: int = 30         ## the mural at the end of The Long Raft Home


# =================================================================================================================
# Helpers
# =================================================================================================================

## v16 -> whole px moved this tick, rounded toward minus infinity (arithmetic shift right by 4). [P 2] [P 15.1 #3]
## ALWAYS integrate through this helper: `/ 16` and `int(v / 16.0)` truncate toward zero and change the feel,
## and a shift with a negative CONSTANT operand is a parse error in Godot 4.7.
static func floor16(v16: int) -> int:
	return v16 >> 4


## Arithmetic shift right of a possibly negative value (floors). Use instead of `>>` on literals.
static func shr(value: int, bits: int) -> int:
	return value >> bits


## Top pixel row of the tile containing y (works for negative y, unlike `%`). [P 15.1 #3]
static func tile_top(y: int) -> int:
	return y & ~15


## Tile column / row containing a logical px coordinate (floors for negatives).
static func to_cell(px: int) -> int:
	return px >> 4


## Offset 0..15 of a logical px coordinate inside its tile (works for negatives).
static func in_cell(px: int) -> int:
	return px & 15


## The "unsigned 16-bit" comparison of the jump handler: true when 0 <= xvel < limit. [P 6.1] [P 15.1 #4]
static func unsigned_below(xvel: int, limit: int) -> bool:
	return (xvel & 0xFFFF) < limit


## ACCEL step for an ice level 0..3.
static func accel_step(ice: int) -> int:
	return ACCEL >> ice


## FRICTION step for an ice level 0..3.
static func friction_step(ice: int) -> int:
	return FRICTION >> ice


## Vertical camera step in px for a distance d (px) between the hero and the target row line.
## Returns 0 outside 0..CAM_V_MAX_DISTANCE. [P 12.2 #5]
static func cam_v_speed(distance: int, fast: bool) -> int:
	if distance < 0 or distance > CAM_V_MAX_DISTANCE:
		return 0
	var limits: Array[int] = CAM_V_FAST_LIMITS if fast else CAM_V_SLOW_LIMITS
	var speeds: Array[int] = CAM_V_FAST_SPEEDS if fast else CAM_V_SLOW_SPEEDS
	for i: int in limits.size():
		if distance <= limits[i]:
			return speeds[i]
	return 0


## Score multiplier for a head-bounce count. [G 3.3]
static func bounce_multiplier(bounce_count: int) -> int:
	return BOUNCE_MULTIPLIER[clampi(bounce_count, 0, BOUNCE_COUNT_MAX)]


## Ticks -> seconds. For UI, audio and tweens only; never inside the simulation.
static func ticks_to_seconds(ticks: int) -> float:
	return float(ticks) * TICK_DT


## Seconds -> ticks (rounded to nearest). For authoring conversions only.
static func seconds_to_ticks(seconds: float) -> int:
	return roundi(seconds * TICK_HZ)


## v16 -> px per second. For orientation, particle speeds and audio only.
static func v16_to_px_per_second(v16: int) -> float:
	return float(v16) / 16.0 * TICK_HZ


## Logical px -> art px (canvas units). The only place where ART_SCALE is applied to positions.
static func to_art(logical: Vector2) -> Vector2:
	return logical * float(ART_SCALE)


## Art px (canvas units) -> logical px, floored.
static func to_logical(art: Vector2) -> Vector2i:
	return Vector2i(floori(art.x / float(ART_SCALE)), floori(art.y / float(ART_SCALE)))
