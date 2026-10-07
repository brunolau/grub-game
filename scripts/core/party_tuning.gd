class_name PartyTuning
extends RefCounted
## Every number of the 2.0 co-op game ("the tribe", docs/expansion/DESIGN.md D, plus the co-op rules of B.0 / B.7):
## the two-hero rules, the tribe camera, the Egg Hatch, the duo moves, the co-op objects, the enemy traits and the
## proofs that make cooperation required. Same units as [Tuning] (px, v16 = 1/16 px per tick, ticks).
##
## CONTRACT FILE (docs/expansion/PLAN.md P0.3, rule 2.5). Owner: core. Single-player never reads it: a party of one
## plays exactly 1.0. The modules that build the co-op systems (player, world, objects, enemies, the validator and
## the solo search) read these values and never keep their own copies; a boss's own co-op numbers (B.1-B.6) live in
## EnemyTuning, mount numbers in MountTuning.
## Marks: [D x] = DESIGN.md section x, [TA x] = TECH_AUDIT.md section x; (tune) = a playtest starting value that is
## changed only through DESIGN.md.

# =================================================================================================================
# Party [D D.1]
# =================================================================================================================
const COOP_PLAYERS: int = 2                  ## co-op is exactly two heroes (the engine holds Defs.MAX_PLAYERS)
## A gate takes both heroes; a partner farther away than one screen arrives as an egg. [D D.1]
const GATE_PARTNER_RANGE_PX: int = Tuning.VIEW_W

# =================================================================================================================
# Tribe camera [D D.2] [TA 4.5]
# =================================================================================================================
## Paging starts when the front hero reaches these screen columns (right / left), as for one hero ...
const CAM_FRONT_START_COL: int = Tuning.CAM_RIGHT_START
const CAM_FRONT_START_COL_LEFT: int = Tuning.CAM_LEFT_START
## ... and stops when the front hero is back at these columns ...
const CAM_FRONT_STOP_COL: int = Tuning.CAM_RIGHT_STOP
const CAM_FRONT_STOP_COL_LEFT: int = Tuning.CAM_LEFT_STOP
## ... or the rear hero reaches the margin column (it never pages while the rear hero stands there).
const CAM_REAR_MARGIN_COL: int = 1
const CAM_REAR_MARGIN_COL_LEFT: int = Tuning.VIEW_COLS - 1 - CAM_REAR_MARGIN_COL
## The view edges are walls: a hero's x commit is clamped to the view edges +/- this many px. [TA 4.5]
const VIEW_EDGE_WALL_PX: int = 8
## A hero off the view becomes an egg after this long (an edge arrow with a stone countdown meanwhile). [D D.2]
const LEASH_EGG_TICKS_BEGINNER: int = 121    ## 5 s
const LEASH_EGG_TICKS_EXPERT: int = 73       ## 3 s

# =================================================================================================================
# Tribe lives and the Egg Hatch [D D.3]
# =================================================================================================================
const TRIBE_LIVES_START: int = Tuning.LIVES_START  ## one pool, starting like solo; a life is lost on a team wipe only
## Hearts of a hatched hero.
const HATCH_HEARTS_BEGINNER: int = 2
const HATCH_HEARTS_EXPERT: int = 1
const HATCH_BLINK_TICKS: int = 44            ## blinking (contact immunity) after a hatch
## Expert: an egg not hatched within this long flies to the checkpoint and waits there (Beginner: it follows forever).
const EGG_RETURN_TICKS_EXPERT: int = 243     ## 10 s
const EGG_SCOUT_RADIUS_PX: int = 32          ## hidden spots within 2 tiles of an egg glint
const VOLUNTARY_EGG_HOLD_TICKS: int = 24     ## Down + Look held 1 s turns a hero into an egg on purpose
## After a team wipe slot s respawns s * this many px from the checkpoint towards the side where the floor continues;
## a slot without an `objects/hero_start` marker starts the same way from '@' (LevelBase.get_respawn_pos_for,
## get_start_pos_for; PHYSICS.md C.12).
const RESPAWN_SPREAD_PX: int = 24

# =================================================================================================================
# Duo moves [D D.4]
# =================================================================================================================
## Every launch moves a hero at most this far per tick on each axis, or calls LevelBase.notify_hero_teleported
## (the doze reach of Tuning.DOZE_HERO_REACH_PX assumes it). [D D.4] [TA 4.6]
const MOVE_MAX_PX_PER_TICK: int = 18
# Shoulder Hop: landing on the partner's head with Up held bounces as on an enemy.
const SHOULDER_HOP_YVEL: int = Tuning.BOUNCE_YVEL_UP  ## -224 v16: rises 105 px from his head
const SHOULDER_HOP_RISE_PX: int = 105
const SHOULDER_HOP_FEET_REACH_PX: int = 140  ## feet over the floor at the top (about 8.7 tiles)
# Totem Ride: the rider stands on the carrier's head (the carrier is a moving platform, PHYSICS 11.4).
const TOTEM_CARRIER_JUMP_SHIFT: int = 1      ## the carrier's jump impulses are halved (shift right by 1)
# Batter Up: Down + Swap curls a hero into a ball; the partner's strike in contact launches him. (tune all)
const CURL_MAX_TICKS: int = 66
const BAT_LINE_DRIVE_XVEL: int = 144         ## forward strike: +/-144, -128 (9 tiles to the same height)
const BAT_LINE_DRIVE_YVEL: int = -128
const BAT_LOB_XVEL: int = 32                 ## high strike: +/-32, -240 (about 7 tiles up, 4 across)
const BAT_LOB_YVEL: int = -240
const BAT_GROUNDER_XVEL: int = 96            ## low strike: rolls at 6 px/tick ...
const BAT_GROUNDER_TICKS: int = 32           ## ... for 32 ticks (12 tiles)
const BAT_CHARGED_NUM: int = 3               ## a charged strike launches x1.5 (velocity * 3 / 2)
const BAT_CHARGED_DEN: int = 2
const BALL_POWER: int = 25                   ## the ball breaks `$` blocks (one hit), opens spots, knocks small enemies
const BALL_KNOCK_HP_EXCL: int = 50           ## "small" = hp below this
const CURL_LANDING_TICKS: int = Tuning.NO_JUMP_TICKS  ## it uncurls on landing by the 6-tick landing rule, or at a wall
# Brace Wall: two crouching heroes stop a heavy.
const BRACE_GAP_PX: int = 16                 ## the two crouchers stand within this many px of each other
const BRACE_DAZE_TICKS: int = 44             ## a heavy (or Tusker's phase 3) stopped dead is dazed this long, head open
# Windows: twin drums, bonds, splits, twin hits. Never longer than the measured solo minimum minus the margin. [D D.8]
const WINDOW_TICKS_BEGINNER: int = 24
const WINDOW_TICKS_EXPERT: int = 12
const WINDOW_SOLO_MARGIN_TICKS: int = 4
const COUNT_IN_BEEPS: int = 3                ## every window has an audible count-in (Sfx.COUNT_IN x3)

# =================================================================================================================
# Co-op objects [D D.5]
# =================================================================================================================
const PLATE_COUNT_MAX: int = 2               ## objects/plate count=1|2
const PLATE_WEIGHT_HERO: int = 1             ## weight on a plate per hero ...
const PLATE_WEIGHT_CHOMPER: int = 2          ## ... and of Chomper
const PLATE_DOOR_MIN_TILES: int = 8          ## a plate stands at least this far from its door
const PLATE_COLUMN_PERIOD: int = Tuning.COLUMN_RISE_PERIOD  ## a plate column rises / sinks 1 tile per 4 ticks
const KEEPER_HALL_ROWS: int = 3              ## keeper and Guard halls are 3 rows high: nobody bounces over them
# See-saw: a hard landing on the high end launches whoever stands on the low end.
const SEESAW_HARD_FALL_TILES: int = 4        ## a fall of 4+ tiles is a hard landing
const SEESAW_LAUNCH_EXTRA: int = 32          ## launch = -(landing yvel + 32) ...
const SEESAW_HARD_BONUS: int = 64            ## ... -64 more on a hard landing ...
const SEESAW_LAUNCH_CAP: int = -288          ## ... capped here (about 10 tiles)
# Heave boulder, pulley.
const BOULDER_STEP_TICKS: int = 6            ## moves 1 tile per 6 ticks ...
const BOULDER_PUSHERS: int = 2               ## ... only while two heroes push the same side
const PULLEY_SPEED_PX: int = 2               ## the heavier side sinks 2 px/tick, the other rises

# =================================================================================================================
# Enemies in co-op and their traits [D D.6] [D D.7]
# =================================================================================================================
const TRAIT_SHARE_DEN: int = 3               ## at least 1 / 3 of the enemy records of a co-op stage carry a trait
const SPAWNER_MAX_NUM: int = 3               ## zone spawners: `max` x1.5 in co-op
const SPAWNER_MAX_DEN: int = 2
const DAZE_ALERT_PX: int = 48                ## `daze`: hops back when a hero within 48 px starts a strike ...
const DAZE_TICKS_BEGINNER: int = 14          ## ... and a head bounce dazes it this long (only then can it be hurt)
const DAZE_TICKS_EXPERT: int = 12
const GRAB_REEL_PX: int = 1                  ## `grab`: carries the hero toward its perch at 1 px/tick
const LEECH_DRAIN_TICKS: int = 44            ## `leech`: one bone per 44 ticks ...
const LEECH_FALL_OFF_TICKS: int = 220        ## ... until the partner clubs it off (alone it falls off after this)
const SNAPPER_STEM_OPEN_TICKS: int = 20      ## a snapper's stem is open this long after a lunge
const SHAMAN_SHIELD_TILES: int = 4           ## the Shaman shields enemies within 4 tiles
## A boss's co-op form has at most 5 / 4 of its solo hit points. [D B.0]
const BOSS_HP_MAX_NUM: int = 5
const BOSS_HP_MAX_DEN: int = 4

# =================================================================================================================
# Requiredness and stage rules [D D.8] [D D.9] [D D.11]
# =================================================================================================================
const MAIN_MIN_GATES: int = 2                ## co-op gates on the main path of every co-op `main` file
const SUB_MIN_GATES: int = 1                 ## every co-op `sub` file: a gate or its boss's co-op form
## Boost ledges (Shoulder Hop / Totem Ride), tiles over the floor.
const BOOST_LEDGE_TILES_BEGINNER: int = 7
const BOOST_LEDGE_TILES_EXPERT: int = 8
const BATTER_GAP_TILES_MIN: int = 8          ## a Batter Up gap: 8-9 tiles of deadly liquid ...
const BATTER_GAP_TILES_MAX: int = 9
const LOB_LEDGE_TILES: int = 7               ## ... or a 7-tile lob ledge
const GATE_SOLVE_TICKS: int = 728            ## each gate takes under about 30 s once understood
## Relay Bounce (Feast Lands): alternate bounces by both heroes on one enemy extend the ladder by these multipliers.
const RELAY_BOUNCE_MULTIPLIERS: Array[int] = [10, 12]
const JOIN_READY_HOLD_TICKS: int = 24        ## join panel: hold Strike 1 s = ready
const LONE_TRAIT_BEGINNER: bool = false      ## Beginner: `lone` acts as plain targeting
const BOSS_GRABS_BEGINNER: bool = false      ## Beginner: no boss grabs


# =================================================================================================================
# Helpers (per difficulty, DESIGN.md D.11)
# =================================================================================================================

## The co-op window of a difficulty: 24 ticks (Beginner) / 12 (Expert), and never more than the measured solo
## minimum minus WINDOW_SOLO_MARGIN_TICKS (`solo_minimum` < 0 = not measured yet). [D D.4] [D D.8]
static func window_ticks(difficulty: int, solo_minimum: int = -1) -> int:
	var base: int = WINDOW_TICKS_EXPERT if difficulty == Defs.Difficulty.EXPERT else WINDOW_TICKS_BEGINNER
	if solo_minimum < 0:
		return base
	return maxi(mini(base, solo_minimum - WINDOW_SOLO_MARGIN_TICKS), 0)


## Ticks off the view before a hero becomes an egg.
static func leash_egg_ticks(difficulty: int) -> int:
	return LEASH_EGG_TICKS_EXPERT if difficulty == Defs.Difficulty.EXPERT else LEASH_EGG_TICKS_BEGINNER


## Hearts of a hatched hero.
static func hatch_hearts(difficulty: int) -> int:
	return HATCH_HEARTS_EXPERT if difficulty == Defs.Difficulty.EXPERT else HATCH_HEARTS_BEGINNER


## Ticks before an unhatched egg returns to the checkpoint; -1 = never (Beginner: it follows forever).
static func egg_return_ticks(difficulty: int) -> int:
	return EGG_RETURN_TICKS_EXPERT if difficulty == Defs.Difficulty.EXPERT else -1


## Daze time of the `daze` trait (the Raptor).
static func daze_ticks(difficulty: int) -> int:
	return DAZE_TICKS_EXPERT if difficulty == Defs.Difficulty.EXPERT else DAZE_TICKS_BEGINNER


## Height of a boost ledge in tiles.
static func boost_ledge_tiles(difficulty: int) -> int:
	return BOOST_LEDGE_TILES_EXPERT if difficulty == Defs.Difficulty.EXPERT else BOOST_LEDGE_TILES_BEGINNER


## Whether the `lone` trait targets the hero farther from his partner (Expert) or acts as plain targeting.
static func lone_trait_on(difficulty: int) -> bool:
	return difficulty == Defs.Difficulty.EXPERT or LONE_TRAIT_BEGINNER


## Whether bosses grab heroes (the Brute's Grab, the Roc's Snatch).
static func boss_grabs_on(difficulty: int) -> bool:
	return difficulty == Defs.Difficulty.EXPERT or BOSS_GRABS_BEGINNER


## Launch velocity (v16, negative = up) of a see-saw for a landing at `landing_yvel` on the high end. [D D.5]
static func seesaw_launch(landing_yvel: int, hard: bool) -> int:
	var launch: int = -(landing_yvel + SEESAW_LAUNCH_EXTRA)
	if hard:
		launch -= SEESAW_HARD_BONUS
	return maxi(launch, SEESAW_LAUNCH_CAP)


## A Batter Up launch velocity component after the charged-strike factor (x1.5, truncated toward zero).
static func bat_charged(velocity: int) -> int:
	return velocity * BAT_CHARGED_NUM / BAT_CHARGED_DEN


## The most hit points a boss's co-op form may have for `solo_hp`. [D B.0]
static func boss_coop_hp_max(solo_hp: int) -> int:
	return solo_hp * BOSS_HP_MAX_NUM / BOSS_HP_MAX_DEN
