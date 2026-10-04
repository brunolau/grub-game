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
