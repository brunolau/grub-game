class_name Sfx
extends RefCounted
## Names of every sound-effect event and music context (docs/ARCHITECTURE.md 3.9).
##
## CONTRACT FILE. Owner: core. Call `Audio.play_sfx(Sfx.CLUB_SWING)` / `Audio.play_music(Sfx.MUSIC_TITLE)` with
## these constants, never with string literals, so that a typo is a parse error. The files behind each name
## are listed in AudioTable (from ASSET_MANIFEST.md 13).

# --- Hero ------------------------------------------------------------------------------------------------------------
const CLUB_SWING: StringName = &"club_swing"            ## club strike, last tick
const HAMMER_SWING: StringName = &"hammer_swing"        ## hammer strike, last tick
const THROW: StringName = &"throw"                      ## axe / boomerang thrown
const CLUB_HIT: StringName = &"club_hit"                ## weapon connects with an enemy
const CLUB_HIT_HEAVY: StringName = &"club_hit_heavy"    ## hammer or charged (x4) hit connects
const CLUB_HIT_SCENERY: StringName = &"club_hit_scenery" ## weapon hits a hidden spot / scenery (star puff)
const JUMP: StringName = &"jump"
const LAND: StringName = &"land"                        ## landing after more than 10 fall ticks (dust puff)
const FOOTSTEP: StringName = &"footstep"
const SKID_ICE: StringName = &"skid_ice"
const BOUNCE: StringName = &"bounce"                    ## head bounce on an enemy or boss; spring pad
const PLAYER_HURT: StringName = &"player_hurt"          ## hurt by an enemy
const PLAYER_HURT_HEAVY: StringName = &"player_hurt_heavy" ## skull, boss hit, boss projectile, lights off
const PLAYER_DEATH: StringName = &"player_death"

# --- Enemies and bosses -----------------------------------------------------------------------------------------------
const ENEMY_HURT: StringName = &"enemy_hurt"            ## enemy survives a hit
const ENEMY_DEATH: StringName = &"enemy_death"          ## enemy killed by a weapon
const ENEMY_VOICE: StringName = &"enemy_voice"          ## alert / spawn voices
const FEAST_CHOMP: StringName = &"feast_chomp"          ## feast mode: enemy eaten on touch
const BOSS_HIT: StringName = &"boss_hit"                ## boss hit by a weapon
const BOSS_ROAR: StringName = &"boss_roar"              ## boss appears; Colossus roars when hit
const BOSS_CHEST_BEAT: StringName = &"boss_chest_beat"  ## Brute taunt
const BOSS_SPIT: StringName = &"boss_spit"              ## Colossus spits a rock
const BOSS_DEFEATED: StringName = &"boss_defeated"      ## boss bursts into bonus items
const EXPLOSION: StringName = &"explosion"              ## grenade / kill-all item
const IMPACT: StringName = &"impact"                    ## boss projectile impact, boulder smash
const QUAKE: StringName = &"quake"                      ## screen shake: columns, ground pound, feast-end warning

# --- Items and objects ------------------------------------------------------------------------------------------------
const PICKUP: StringName = &"pickup"                    ## food, bones, feast kit, weapons, glider
const PICKUP_BIG: StringName = &"pickup_big"            ## treasure, giant bonus
const PICKUP_LETTER: StringName = &"pickup_letter"      ## bonus letter, warp item
const HEART: StringName = &"heart"                      ## heart collected, sixth bone restores a heart
const ONE_UP: StringName = &"one_up"
const SPOT_OPENED: StringName = &"spot_opened"          ## hidden spot used up / secret opened
const GIANT_BONUS: StringName = &"giant_bonus"          ## giant bonus or jackpot chest appears
const BLOCK_BREAK: StringName = &"block_break"          ## breakable block destroyed (dirt, rock)
const BLOCK_BREAK_ICE: StringName = &"block_break_ice"
const CHECKPOINT: StringName = &"checkpoint"            ## restart point lit
const EXIT_OPEN: StringName = &"exit_open"              ## exit unlocked / exit touched
const SPLASH: StringName = &"splash"                    ## something falls into water or lava
const CODE_ACCEPT: StringName = &"code_accept"          ## code stone collected, code / save slot accepted
const CODE_REJECT: StringName = &"code_reject"          ## locked level, invalid action

# --- UI ---------------------------------------------------------------------------------------------------------------
const MENU_MOVE: StringName = &"menu_move"
const MENU_SELECT: StringName = &"menu_select"
const MENU_BACK: StringName = &"menu_back"
const PAUSE_IN: StringName = &"pause_in"
const PAUSE_OUT: StringName = &"pause_out"
const TALLY_TICK: StringName = &"tally_tick"            ## each item counted at the tally
const TALLY_END: StringName = &"tally_end"

# --- Ambience loops (Audio.start_loop / stop_loop) --------------------------------------------------------------------
const LOOP_FIRE: StringName = &"loop_fire"              ## near a lit checkpoint
const LOOP_WIND: StringName = &"loop_wind"              ## blizzard
const LOOP_LAVA: StringName = &"loop_lava"              ## near lava

# --- Music contexts (Audio.play_music) --------------------------------------------------------------------------------
const MUSIC_TITLE: StringName = &"title"                ## title picture and main menu
const MUSIC_MENU: StringName = &"menu"                  ## mode select / code entry / level select
const MUSIC_MAP: StringName = &"map"                    ## world map between levels
const MUSIC_JUNGLE: StringName = &"level_jungle"        ## world 1
const MUSIC_CAVE: StringName = &"level_cave"            ## world 2
const MUSIC_ICE: StringName = &"level_ice"              ## world 3
const MUSIC_VOLCANO: StringName = &"level_volcano"      ## world 4
const MUSIC_SHAFT: StringName = &"level_shaft"          ## 4-1 auto-scroll descent
const MUSIC_GROTTO: StringName = &"level_grotto"        ## spare level theme (3-2)
const MUSIC_BONUS: StringName = &"bonus"                ## Feast Land bonus stages
const MUSIC_SECRET: StringName = &"secret"              ## secret rooms / alternate bonus loop
const MUSIC_BOSS: StringName = &"boss"                  ## starts when a boss energy bar appears
const MUSIC_BOSS_FINAL: StringName = &"boss_final"      ## the Wall Colossus
const MUSIC_FEAST: StringName = &"feast"                ## feast mode, replaces the level music
const MUSIC_LEVEL_COMPLETE: StringName = &"level_complete" ## jingle when the iris closes
const MUSIC_TALLY: StringName = &"tally"                ## tally loop after the jingle
const MUSIC_DEATH: StringName = &"death"                ## jingle before the respawn curtain
const MUSIC_GAME_OVER: StringName = &"game_over"        ## jingle, followed by MUSIC_GAME_OVER_LOOP
const MUSIC_GAME_OVER_LOOP: StringName = &"game_over_loop"
const MUSIC_ENDING: StringName = &"ending"              ## ending stage
const MUSIC_CREDITS: StringName = &"credits"            ## credits roll / The End

# =====================================================================================================================
# 2.0 expansion: one name per row of docs/expansion/DESIGN.md F.2 (plus the co-op count-in of D.4). NAMES ONLY:
# AudioTable gets their rows with the files (AudioTable batches, PLAN.md P1.1 / P2.6), and Audio.play_sfx /
# play_music of a name without a row is an error, so nothing plays these before their row exists. The staged pick
# of each name is in its comment.
# =====================================================================================================================

# --- Book II, co-op and versus effects -------------------------------------------------------------------------------
const SWAP: StringName = &"swap"                        ## hand and belt swapped (Junkala interaction6)
const SPEAR_STICK: StringName = &"spear_stick"          ## a spear sticks in a bark board (Spring Spring snd_enemyland)
const VINE_CLIMB: StringName = &"vine_climb"            ## climbing a vine (Junkala ladder1loop)
const RAFT_SPLASH: StringName = &"raft_splash"          ## a raft dips or is paddled (Skippy Fish water, waterReentry)
const SPLASH_HEAVY: StringName = &"splash_heavy"        ## something heavy lands in water (Basto heavy_splash)
const GEYSER_BUBBLE: StringName = &"geyser_bubble"      ## the 22-tick geyser telegraph (BMacZero bubbles-single2)
const GEYSER_SPOUT: StringName = &"geyser_spout"        ## the spout (Basto heavy_splash)
const TAR_GLUG: StringName = &"tar_glug"                ## stepping into tar / honey / syrup (Spring Spring glug)
const EGG_DOWN: StringName = &"egg_down"                ## a co-op hero becomes an egg (Junkala neutral2)
const EGG_HATCH: StringName = &"egg_hatch"              ## an egg hatches (Junkala powerup2)
const DUO_HOP: StringName = &"duo_hop"                  ## Shoulder Hop / Totem Ride landing (Junkala interaction16)
const CURL: StringName = &"curl"                        ## curling into a ball (MoxieCat dashcharge)
const BAT_HIT: StringName = &"bat_hit"                  ## a curled hero batted (artisticdude swish-7..9, dashwoosh)
const BRACE: StringName = &"brace"                      ## a Brace Wall stops a heavy (Spring Spring snd_enemyland)
const PLATE: StringName = &"plate"                      ## a pressure plate pressed / released (Kenney switch_002)
const DRUM: StringName = &"drum"                        ## a twin drum struck (Junkala Blip5)
const COUNT_IN: StringName = &"count_in"                ## one beep of a co-op window's count-in (Junkala Blip5) [D D.4]
const SEESAW: StringName = &"seesaw"                    ## a see-saw launch (Spring Spring snd_sproing)
const BOULDER_PUSH: StringName = &"boulder_push"        ## a heave boulder moves (Kenney creak1)
const PULLEY: StringName = &"pulley"                    ## a pulley moves (Kenney creak3)
const DAZE: StringName = &"daze"                        ## an enemy is dazed (Junkala nagger2)
const CHOMPER_BITE: StringName = &"chomper_bite"        ## Chomper bites / eats (shipped dino_voice + food_chomp)
const COOKPOT_BANK: StringName = &"cookpot_bank"        ## a piece banked in the cookpot (Junkala powerup8)
const CRATE_DROP: StringName = &"crate_drop"            ## a pterodactyl crate drops (Kronbits Retro Swooosh 02)
const HOT_ROCK_FUSE: StringName = &"hot_rock_fuse"      ## the Hot Rock's fuse ticks (Junkala Blip5)
const LOOP_HOT_ROCK_HURRY: StringName = &"loop_hot_rock_hurry" ## its last 3 s (Junkala alarm_loop1)
const CROWD_APPLAUSE: StringName = &"crowd_applause"    ## results applause bed (eXpl0it3r applause)
const CROWD_CHEER: StringName = &"crowd_cheer"          ## a cheer (qubodup Well Done)
const PARTY_JOIN: StringName = &"party_join"            ## a player takes a slot (ctske square_partyjoin)
const COUNTDOWN_BEEP: StringName = &"countdown_beep"    ## round intro "3, 2, 1" (kheetor countdown, Junkala Blip5)
const COUNTDOWN_GO: StringName = &"countdown_go"        ## round intro "GRUB!" (Junkala fanfare2)
const SUDDEN_DEATH: StringName = &"sudden_death"        ## sudden death starts (Junkala alarm_loop1 + refereewhistle)
const CLANG: StringName = &"clang"                      ## versus: two front boxes meet (the Colossus clank, D E.2)

# --- Book II level music (Audio.play_music) ---------------------------------------------------------------------------
const MUSIC_CANYON: StringName = &"level_canyon"        ## 5-1 Red Mesa Trail (Wolfgang_ "Desert Theme")
const MUSIC_GULCH: StringName = &"level_gulch"          ## 5-2 Rattlesnake Gulch (Spring Spring "Suez Crisis Remade")
const MUSIC_FEN: StringName = &"level_fen"              ## 6-1 Bubbling Fen (Junkala Super Action stage_7)
const MUSIC_SPORE: StringName = &"level_spore"          ## 6-2 Spore Hollow (Wolfgang_ "Haunted House")
const MUSIC_MANGROVE_CLIMB: StringName = &"level_mangrove_climb" ## 6-2b tar climb (Tallbeard "Pixel War 1")
const MUSIC_COAST: StringName = &"level_coast"          ## 7-1 Shell Beach (Spring Spring "Sandy Seaside")
const MUSIC_SEA_CAVES: StringName = &"level_sea_caves"  ## 7-2 Sea Caves (Tallbeard "Deep Blue")
const MUSIC_RUINS: StringName = &"level_ruins"          ## 8-1 Overgrown Steps (Junkala Super Action stage_9)
const MUSIC_IDOL_HALL: StringName = &"level_idol_hall"  ## 8-2 Hall of Idols (Tallbeard "Penultimate")
const MUSIC_SKY_CLIMB: StringName = &"level_sky_climb"  ## 9-1 Cloudbreak Climb (Wolfgang_ "Upbeat Overworld")
const MUSIC_STORM_GLIDE: StringName = &"level_storm_glide" ## 9-1b (Spring Spring "Typhoon's Theme" v3)
const MUSIC_SPIRE: StringName = &"level_spire"          ## 9-2 The Roc's Spire (Junkala Retro Sports stage_final)
const MUSIC_PYRE: StringName = &"level_pyre"            ## 9-3 approach (Junkala Super Action stage_6)
const MUSIC_BONUS_LAGOON: StringName = &"bonus_lagoon"  ## Feast Land E (Tallbeard "Box Jump"); D plays MUSIC_BONUS
const MUSIC_ENDING_RAFT: StringName = &"ending_raft"    ## The Long Raft Home (Spring Spring "Tropical Fantasy")
# Boss music (pushed like MUSIC_BOSS while the boss bar shows).
const MUSIC_BOSS_TUSKER: StringName = &"boss_tusker"    ## nene "Boss Battle #1"
const MUSIC_BOSS_MANGROVE: StringName = &"boss_mangrove" ## nene "Boss Battle #2"
const MUSIC_BOSS_INKJAW: StringName = &"boss_inkjaw"    ## nene "Boss Battle #4"
const MUSIC_BOSS_IDOLS: StringName = &"boss_idols"      ## Spring Spring "Egyptian Fortress Boss"
const MUSIC_BOSS_ROC: StringName = &"boss_roc"          ## nene "Boss Battle #6"
const MUSIC_BOSS_CHIEFTAINS: StringName = &"boss_chieftains" ## nene "Boss Battle #3"

# --- Co-op and versus music and jingles -------------------------------------------------------------------------------
const MUSIC_COOP_MENU: StringName = &"coop_menu"        ## co-op join panel (Tallbeard "Connected")
const MUSIC_VERSUS_LOBBY: StringName = &"versus_lobby"  ## lobby, rules, arena select (Spring Spring melon charselect)
const MUSIC_VERSUS_BATTLE_A: StringName = &"versus_battle_a" ## a round (Junkala Retro Sports stage_3)
const MUSIC_VERSUS_BATTLE_B: StringName = &"versus_battle_b" ## a round (Tallbeard "Out of Time")
const MUSIC_VERSUS_BATTLE_C: StringName = &"versus_battle_c" ## a round (Tallbeard "Go (No Vocal)")
const MUSIC_VERSUS_SUDDEN_DEATH: StringName = &"versus_sudden_death" ## sudden death (Wolfgang_ "8-Bit Battle Loop")
const MUSIC_ROUND_WIN: StringName = &"round_win"        ## jingle: round over (Junkala fanfare1 / MintoDog)
const MUSIC_MATCH_WIN: StringName = &"match_win"        ## jingle: the match winner (celestialghost8 "Victory")
const MUSIC_VERSUS_RESULTS: StringName = &"versus_results" ## results screen loop (Spring Spring melon win)

## Every 2.0 effect / loop name above (for the AudioTable batches and their tests).
const EXPANSION_SFX: Array[StringName] = [
	SWAP, SPEAR_STICK, VINE_CLIMB, RAFT_SPLASH, SPLASH_HEAVY, GEYSER_BUBBLE, GEYSER_SPOUT, TAR_GLUG, EGG_DOWN,
	EGG_HATCH, DUO_HOP, CURL, BAT_HIT, BRACE, PLATE, DRUM, COUNT_IN, SEESAW, BOULDER_PUSH, PULLEY, DAZE,
	CHOMPER_BITE, COOKPOT_BANK, CRATE_DROP, HOT_ROCK_FUSE, LOOP_HOT_ROCK_HURRY, CROWD_APPLAUSE, CROWD_CHEER,
	PARTY_JOIN, COUNTDOWN_BEEP, COUNTDOWN_GO, SUDDEN_DEATH, CLANG,
]
## Every 2.0 music context above.
const EXPANSION_MUSIC: Array[StringName] = [
	MUSIC_CANYON, MUSIC_GULCH, MUSIC_FEN, MUSIC_SPORE, MUSIC_MANGROVE_CLIMB, MUSIC_COAST, MUSIC_SEA_CAVES,
	MUSIC_RUINS, MUSIC_IDOL_HALL, MUSIC_SKY_CLIMB, MUSIC_STORM_GLIDE, MUSIC_SPIRE, MUSIC_PYRE, MUSIC_BONUS_LAGOON,
	MUSIC_ENDING_RAFT, MUSIC_BOSS_TUSKER, MUSIC_BOSS_MANGROVE, MUSIC_BOSS_INKJAW, MUSIC_BOSS_IDOLS, MUSIC_BOSS_ROC,
	MUSIC_BOSS_CHIEFTAINS, MUSIC_COOP_MENU, MUSIC_VERSUS_LOBBY, MUSIC_VERSUS_BATTLE_A, MUSIC_VERSUS_BATTLE_B,
	MUSIC_VERSUS_BATTLE_C, MUSIC_VERSUS_SUDDEN_DEATH, MUSIC_ROUND_WIN, MUSIC_MATCH_WIN, MUSIC_VERSUS_RESULTS,
]
