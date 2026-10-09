class_name VersusTuning
extends RefCounted
## Every number of 2.0 versus (same-device deathmatch for 2-4 players, docs/expansion/DESIGN.md E): the combat kit,
## the four launch modes and the second wave, arenas, sudden deaths, bots and the match flow. Same units as [Tuning]
## (px, v16 = 1/16 px per tick, ticks); seconds are converted the DESIGN.md way (Tuning.seconds_to_ticks).
##
## CONTRACT FILE (docs/expansion/PLAN.md P0.3, rule 2.5). Owner: core. Versus runs only in arena files
## (`kind = arena`); campaign values are untouched, and single-player and co-op never read this class. The referee,
## the versus objects, the bots, the round loop and the versus screens read these values and keep no copies.
## Marks: [D x] = DESIGN.md section x, [TA x] = TECH_AUDIT.md section x, [PL x] = PLAN.md section x; (tune) = a
## playtest starting value that is changed only through DESIGN.md.

# =================================================================================================================
# Players and rounds [D E.1] [D E.3] [TA 4.9]
# =================================================================================================================
const PLAYERS_MIN: int = 2
const PLAYERS_MAX: int = Defs.MAX_PLAYERS
## A round's Sim.rng seed is match_seed * ROUND_SEED_FACTOR + round index, so a round is a pure function of the
## inputs (see round_seed()). Bots never draw from Sim.rng. [TA 4.9]
const ROUND_SEED_FACTOR: int = 31

# =================================================================================================================
# Combat kit [D E.2]
# =================================================================================================================
const HIT_XVEL: int = 64                     ## a hit knocks the victim away from the attacker: +/-64, -128
const HIT_YVEL: int = -128
const CHARGED_XVEL: int = 128                ## a charged hit launches: +/-128 with ice-like sliding, -160
const CHARGED_YVEL: int = -160
const CHARGED_SLIDE_ICE: int = Tuning.ICE_MAX ## the launch slides like the boss knock-back (ice 3) (tune)
const HAMMER_KNOCK_NUM: int = 3              ## the hammer knocks x1.5 horizontally
const HAMMER_KNOCK_DEN: int = 2
const BOOMERANG_POP_YVEL: int = -160         ## the swirling axe pops the victim up
const CLANG_PUSH_PX: int = 16                ## two front boxes in the same tick end 16 px apart; a charged strike wins ...
const CLANG_PUSH_EACH_PX: int = CLANG_PUSH_PX / 2  ## ... each hero pushed 8 px away from the other (commit rule) [P C.14]
const DEFLECT_SPEEDUP: int = 32              ## a struck special flies back 2 px/tick faster, owned by the striker
const STOMP_SQUASH_TICKS: int = 8            ## a stomped hero cannot jump or strike this long (PlayerBase.squash) ...
const STOMP_IMMUNE_TICKS: int = 30           ## ... then is immune this long [P C.14]
const TEAMMATE_BUMP_XVEL: int = 32           ## 2v2: a teammate's hit only bumps (xvel +/-32) (tune) [P C.14]
const CURL_GLANCE_ABOVE_PX: int = 16         ## a box whose attacker's feet are 16+ px above a curled hero's glances [P C.14]
## The stomp ladder: the n-th stomp of a chain (the head-bounce ladder 1-2-3-4-6-8).
const STOMP_LADDER: Array[int] = [1, 2, 3, 4, 6, 8]
const STUN_TICKS: int = 12                   ## hurt timing: stunned ...
const IMMUNE_TICKS: int = 30                 ## ... then immune (ends when the victim strikes or throws)
## The versus hurt on the 1.0 hit_timer [R16]: hit_timer = 43 on a rival's hit (Defs.HurtKind.RIVAL), stunned
## (state 8) while hit_timer >= 31: 12 stunned ticks, then 30 immune ticks with control. [P C.14]
const HURT_TIMER_TICKS: int = STUN_TICKS + IMMUNE_TICKS + 1
const STUN_HIT_TIMER_MIN: int = IMMUNE_TICKS + 1
const HIT_STOP_TICKS: int = 2                ## attacker and victim skip their PLAYER phase (PlayerBase.hit_stop) ...
const HIT_STOP_BIG_TICKS: int = 4            ## ... 4 on a charged or deciding hit
const WRAP_SPECIAL_TICKS: int = 40           ## wrap arenas: a thrown special wraps once and vanishes after 40 ticks
const BODY_BUMP_PX: int = 1                  ## overlapping heroes are nudged apart 1 px/tick ...
const BODY_KNOCK_MIN_XVEL: int = 64          ## ... running into each other at 4+ px/tick knocks both back ...
const BODY_KNOCK_XVEL: int = 64              ## ... with xvel +/-64 apart and yvel -64 (a 10 px hop), no damage (tune) [P C.14]
const BODY_KNOCK_YVEL: int = -64
## Temporary specials (from crates, onto the belt): throws before one is gone, by Defs.Weapon (0 = only a
## knock-out removes it). Axe 3, swirling axe 2, spear 3.
const SPECIAL_THROWS: Array[int] = [0, 0, 3, 2, 3]
const SPAWN_SHIELD_TICKS: int = 48           ## spawn shield; it ends on the first strike or throw
const RESPAWN_TICKS: int = 48                ## a hazard costs a respawn after this long (no world reset) [TA 4.7]
const KO_CREDIT_TICKS: int = 73              ## a knock-out is credited to the last hitter within 3 s [TA 4.7]

# =================================================================================================================
# Grub Stack (flagship) [D E.3]
# =================================================================================================================
const STACK_ROUND_TICKS: int = 2185          ## 90 s ...
const STACK_ROUND_TICKS_2P: int = 1457       ## ... 60 s with two players
const STACK_ROUND_WINS: int = 3              ## first to 3 round wins; a tie drops the Golden Drumstick
# Food values on the stack.
const FOOD_SMALL: int = 1
const FOOD_BIG: int = 2
const FOOD_TREASURE: int = 5
const FOOD_GIANT: int = 10
const STACK_PICTURES_MAX: int = 8            ## above 8 pictures the tower shows 5s and 10s
# Weight (tune).
const STACK_HEAVY: int = 10                  ## 10+ on the head caps walking at 64 v16 ...
const STACK_HEAVY_WALK_CAP: int = 64
const STACK_HEAVIER: int = 20                ## ... 20+ at 48 v16 and jump impulses at 3 / 4
const STACK_HEAVIER_WALK_CAP: int = 48
const STACK_HEAVIER_JUMP_NUM: int = 3
const STACK_HEAVIER_JUMP_DEN: int = 4
# Losing food: 1 + stack / divisor pieces fly off the top (see spill()).
const SPILL_HIT_DIV: int = 5
const SPILL_CHARGED_DIV: int = 2             ## plus a launch
const SPILL_THROWN_DIV: int = 8
const SPILL_LIFE_TICKS: int = Tuning.DROPPED_ITEM_LIFE  ## spilled pieces use the dropped-item physics, blinking
const HAZARD_BURST_DIV: int = 2              ## a hazard spills everything: half bursts out, half is lost
# The cookpot.
const COOKPOT_BANK_TICKS: int = 4            ## crouched inside: one piece banked per 4 ticks
const COOKPOT_STOMP_STEAL_MULT: int = 2      ## a stomp on a banking hero steals double
const COOKPOTS: int = 1                      ## one per arena ...
const COOKPOTS_4P: int = 2                   ## ... two on 4-player arenas
# Food sources.
const SPOT_REFILL_TICKS: int = 364           ## visible spots refill 15 s after they are emptied ...
const SPOT_SPARKLE_TICKS: int = 49           ## ... sparkling 2 s before
const BIG_SPOT_HITS: int = 3                 ## by anyone; its giant bonus falls from 7 rows up and bonks a head
const GIANT_DROP_ROWS: int = 7
const GIANT_BONK_DAZE_TICKS: int = 12        ## the giant bonus bonks the head it lands on: the bounce plus this daze (tune)
const CRATE_PERIOD_TICKS: int = 486          ## pterodactyl crates every 20 s ...
const CRATE_SHADOW_TICKS: int = 22           ## ... their shadow 22 ticks ahead
# Items.
const FEAST_TICKS: int = 194                 ## the versus feast: 8 s ...
const FEAST_TOUCH_SPILL: int = 3             ## ... a touch knocks 3 pieces off anyone, hits cannot touch the feaster
const FEAST_WARN_TICKS: int = Tuning.FEAST_WARN_TICKS_BEFORE_END  ## the shake warns 7 ticks before the end
const GRENADE_SPILL: int = 5                 ## every rival spills 5
const FEAST_RUSH_TICKS: int = 364            ## the last 15 s: spots refill, a second giant falls, the pot lids close

# =================================================================================================================
# The other launch modes [D E.4] [D E.6]
# =================================================================================================================
# Last Caveman Standing.
const LCS_HEARTS: int = 3                    ## hit = 1 heart, charged = 2 + launch, stomp = 1 + squash, hazard = out
const LCS_CHARGED_HEARTS: int = 2
const LCS_HEART_BONES: int = Tuning.BONES_PER_HEART  ## a lost heart bursts into 6 bones; 6 bones heal a heart
const LCS_ROUND_WINS: int = 5
const LCS_STOCKS: int = 3                    ## option Stock: 3 lives with respawn
const SUDDEN_DEATH_AT_TICKS: int = 1457      ## the arena's themed sudden death starts at 60 s
## The hard cap (ruling R8): a Last Caveman Standing round ends this long after its sudden death started, whoever
## still stands - fewest hurts taken in the round wins, else a draw (VersusReferee.cap_winners). 60 s (tune); 0 = no cap.
const SUDDEN_DEATH_CAP_TICKS: int = 1457
const GRUDGE_ROCK_PERIOD_TICKS: int = 73     ## Grudge Pterodactyls: one rock per 3 s ...
const GRUDGE_SQUAWK_TICKS: int = 10          ## ... after a 10-tick squawk ...
const GRUDGE_ROCK_DAZE_TICKS: int = 12       ## ... a rock dazes, costs no heart
# Hot Rock.
const HOT_ROCK_PASS_IMMUNE_TICKS: int = 44   ## whoever passed it is immune to it this long
const HOT_ROCK_HOLDER_WALK_CAP: int = 96
const HOT_ROCK_FUSE_MIN_TICKS: int = 291     ## the fuse: 12-20 s, drawn from Sim.rng with the round seed
const HOT_ROCK_FUSE_MAX_TICKS: int = 486
const HOT_ROCK_HURRY_TICKS: int = 73         ## it bubbles faster in the last 3 s
const HOT_ROCK_ROUND_WINS: int = 3
const HOT_ROCK_FIRST_PICK_TICKS: int = 66    ## Sim.rng picks the first holder this long after the round starts (tune) ...
const HOT_ROCK_REPICK_TICKS: int = 66        ## ... and a new one this long after a holder popped (tune) [G 13.10.5]
# Clubball (Coconut Cove).
const BALL_GRAVITY: int = 16
const BALL_ROLL_LOSS: int = 2                ## v16 per tick a rolling coconut loses on the ground (tune) [G 13.11]
const BALL_BOUNCE_NUM: int = 3               ## bounces at 3 / 4
const BALL_BOUNCE_DEN: int = 4
const GOAL_ROWS: int = 3                     ## a goal mouth is 3 rows high
const BALL_SMASH_NUM: int = 3                ## a charged strike smashes x1.5
const BALL_SMASH_DEN: int = 2
const RALLY_WINDOW_TICKS: int = 44           ## every strike within 44 ticks of the last adds 16 v16 ...
const RALLY_STEP: int = 16
const BALL_MAX_SPEED: int = 192              ## ... up to 12 px/tick
const BALL_KNOCKDOWN_SPEED_EXCL: int = 128   ## a coconut faster than 8 px/tick knocks a hero down (STUN_TICKS)
const CLUBBALL_GOALS: int = 5                ## first to 5 goals ...
const CLUBBALL_MATCH_TICKS: int = 4370       ## ... or most after 3 min; then the golden coconut
const BALL_RESET_TICKS: int = 66             ## the ball resets to the middle 66 ticks after a goal
# The shots: a front box touching the coconut sets its velocity by the strike (xvel signed by the striker's facing;
# every component capped at PartyTuning.LAUNCH_AXIS_CAP). P2.7 (objects-B's objects/coconut). [G 13.10.6]
const BALL_DRIVE_XVEL: int = 144             ## forward front box: the drive ...
const BALL_DRIVE_YVEL: int = -128
const BALL_LOB_XVEL: int = 32                ## high front box: the lob ...
const BALL_LOB_YVEL: int = -240
const BALL_GROUNDER_XVEL: int = 96           ## low front box: the grounder (yvel 0, along the floor)
const BALL_BOUNCE_MIN_YVEL: int = 32         ## a floor bounces it while yvel >= 32, else it rests and rolls
const BALL_HEAD_BOUNCE_MIN_YVEL: int = -96   ## a coconut landing on a head bounces up at 3/4, at least -96
# Second wave (not at launch).
const KING_COUNTS: int = 20                  ## King of the Feast: fill 20 counts ...
const KING_COUNT_TICKS: int = 22             ## ... of 22 ticks carrying the giant roast
const KING_CARRIER_WALK_CAP: int = 64
const KING_COUNT_KEEP_LEFT: int = 5          ## "your count never falls back below 5 left"
const LETTER_SPOTS_MIN: int = 8              ## Letter Snatch: 8-12 visible spots, five hold G-R-U-B-S
const LETTER_SPOTS_MAX: int = 12
const LETTER_HOLD_TICKS: int = 44            ## hold all five this long = round won
const EGG_CRACK_FALL_ROWS: int = 6           ## Egg Heist: the egg cracks after a fall of 6+ rows ...
const EGG_MOTHER_CHASE_TICKS: int = 194      ## ... a mother rex chases a carrier who holds it 8 s

# =================================================================================================================
# Presets, variants, handicaps [D E.4]
# =================================================================================================================
const MAYHEM_CRATE_PERIOD_TICKS: int = 194   ## preset Mayhem: crates every 8 s
const HANDICAP_HEARTS_MIN: int = 1           ## Last Caveman Standing hearts 1-5
const HANDICAP_HEARTS_MAX: int = 5
## Grub Stack stack guard, percent of the spill.
const STACK_GUARD_PERCENT: Array[int] = [50, 100, 150]
const AUTO_HANDICAP_ROUNDS_BEHIND: int = 2   ## Auto: two rounds behind -> a leaf shield that absorbs one hit

# =================================================================================================================
# Arenas and their sudden deaths [D E.5] [D E.6]
# =================================================================================================================
const ARENA_COLS: int = 20                   ## every arena is one 20 x 11 screen, camera locked ...
const ARENA_ROWS: int = 11
const ARENA_FILE_ROWS: int = 12              ## ... in a 20 x 12 file (fill row 11 under the view) [LEVEL_DESIGN 15.8]
const ARENA_FLOOR_ROW: int = 10              ## ... floor row 10; row 0 holds nothing to stand on
const ARENA_TIER_ROWS: int = 3               ## tiers 3 rows apart ...
const ARENA_HIGH_STEP_ROWS: int = 5          ## ... 5+ rows only by spring, geyser, see-saw or a head
const ARENA_GAP_MAX_CELLS: int = 5
const ARENA_SPOTS_MIN: int = 4
const ARENA_SPOTS_MAX: int = 8
const ARENAS: int = 10                       ## 8 at launch, 2 unlocked by paintings
const ARENAS_AT_LAUNCH: int = 8
const STAMPEDE_PERIOD_TICKS: int = 73        ## Totem Ring: chargers every 3 s, dust 22 ticks ahead
const STAMPEDE_DUST_TICKS: int = 22
const CAVE_IN_PERIOD_TICKS: int = 11         ## Echo Hollow: one block per 11 ticks
const ECHO_DARK_PERIOD_TICKS: int = 486      ## Echo Hollow: a darkness pulse every 20 s ...
const ECHO_DARK_TICKS: int = 73              ## ... of 3 s
const ECHO_WALL_REGROW_TICKS: int = 364      ## `$` walls grow back after 15 s
const WHITEOUT_STEP_TICKS: int = 121         ## Floe Rink: gusts grow every 5 s
const LAVA_RISE_ROW_TICKS: int = 44          ## Cinder Pit (and Tar Pulleys' tar rise): 1 row per 44 ticks
const COLOSSUS_SPIT_PERIOD_TICKS: int = 243  ## Colossus Hall: spits at the crowned leader every 10 s ...
const COLOSSUS_JAWS_TICKS: int = 10          ## ... jaws open 10 ticks ahead
const RODEO_CHOMPER_PERIOD_TICKS: int = 728  ## Mesa Rodeo: Chomper leaves his pen every 30 s ...
const RODEO_RUMBLE_TICKS: int = 22           ## ... with a 22-tick rumble; his rider's bite spills 3
const RODEO_BITE_SPILL: int = 3
const LIGHTNING_MARK_TICKS: int = 22         ## Cloud Top: marked cells, 22 ticks ahead

# =================================================================================================================
# Bots [D E.7] [PL 8 V4.b]
# =================================================================================================================
const BOT_GOAL_PERIOD_TICKS: int = 6         ## goals are chosen every 6 ticks by utility
## Reaction time by Defs.BotLevel (Rookie, Hunter, Chief): difficulty is reaction and decisions, never cheating.
const BOT_REACTION_TICKS: Array[int] = [10, 6, 3]
const BOT_ANTI_AIR_PX: int = 26              ## high strike against a jumper above within 26 px
const BOT_CHIEF_DEFLECT_PERCENT: int = 50    ## the Chief deflects specials half the time
const BOT_IDLE_MAX_TICKS: int = 243          ## test: no bot idle more than 10 s
const BOT_WIN_RATE_SPREAD_PERCENT: int = 15  ## test: win rates per spawn point within +/-15 %

# =================================================================================================================
# Match flow [D E.8]
# =================================================================================================================
const READY_HOLD_TICKS: int = 24             ## lobby: hold Strike 1 s = ready
const COUNTDOWN_STEPS: int = 3               ## "3, 2, 1, GRUB!"
const DECIDING_REPLAY_TICKS: int = 73        ## the last 3 s replayed ...
const DECIDING_REPLAY_SPEED_DIV: int = 2     ## ... at half speed
const SCOREBOARD_TICKS: int = 121            ## about 5 s
const AWARDS_MIN: int = 1                    ## the tally companion hands out 1-3 awards each
const AWARDS_MAX: int = 3


# =================================================================================================================
# Helpers
# =================================================================================================================

## The Sim.rng seed of round `round_index` of a match. [TA 4.9]
static func round_seed(match_seed: int, round_index: int) -> int:
	return match_seed * ROUND_SEED_FACTOR + round_index


## Round length of Grub Stack for `players` heroes.
static func stack_round_ticks(players: int) -> int:
	return STACK_ROUND_TICKS_2P if players <= 2 else STACK_ROUND_TICKS


## Pieces knocked off a stack of `stack` by a hit of the given divisor (SPILL_HIT_DIV, SPILL_CHARGED_DIV,
## SPILL_THROWN_DIV): 1 + stack / divisor, never more than the stack.
static func spill(stack: int, divisor: int) -> int:
	if stack <= 0:
		return 0
	return mini(stack, 1 + stack / maxi(divisor, 1))


## Pieces a stomp steals: the ladder count of the `chain`-th stomp (1-based; past the end the ladder's top),
## doubled when the victim was banking in a cookpot.
static func stomp_steal(chain: int, banking: bool) -> int:
	var steal: int = STOMP_LADDER[clampi(chain - 1, 0, STOMP_LADDER.size() - 1)]
	return steal * COOKPOT_STOMP_STEAL_MULT if banking else steal


## Walking cap (v16) of a hero carrying `stack` pieces (Tuning.WALK_CAP when light).
static func stack_walk_cap(stack: int) -> int:
	if stack >= STACK_HEAVIER:
		return STACK_HEAVIER_WALK_CAP
	if stack >= STACK_HEAVY:
		return STACK_HEAVY_WALK_CAP
	return Tuning.WALK_CAP


## Reaction time of a bot level (Defs.BotLevel).
static func bot_reaction_ticks(level: int) -> int:
	return BOT_REACTION_TICKS[clampi(level, 0, BOT_REACTION_TICKS.size() - 1)]
