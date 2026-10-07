class_name AudioTable
extends RefCounted
## Event name -> audio files, from docs/ASSET_MANIFEST.md section 13. Owner: core. Other modules never reference
## audio files directly.
##
## Volumes: every file's volume_db comes from its measured loudness (tools/audio_loudness.py, numbers in
## ASSET_MANIFEST 13.4): music plays at -18 LUFS integrated, effects at -14 LUFS over their loudest 200 ms (footsteps,
## ambience loops and the UI cursor lower, the biggest events higher), and no file's true peak exceeds -1 dBTP.
## Run `tools/audio_loudness.py --write` after adding or replacing a file instead of editing the numbers by ear.

const SFX_DIR: String = "res://assets/audio/sfx/"
const MUSIC_DIR: String = "res://assets/audio/music/"

## event -> { "files": [variants], "db": [volume_db per variant], "bus": bus name (default "SFX") }.
## Several variants are cycled (or picked with the `variant` argument of Audio.play_sfx).
const SFX: Dictionary = {
	Sfx.CLUB_SWING: {"files": ["club_swing_a.wav"], "db": [-3.4]},
	Sfx.HAMMER_SWING: {"files": ["club_swing_b.wav"], "db": [-3.7]},
	Sfx.THROW: {"files": ["projectile_throw_b.wav"], "db": [-1.6]},
	Sfx.CLUB_HIT: {"files": ["club_hit_a.wav"], "db": [4.5]},
	Sfx.CLUB_HIT_HEAVY: {"files": ["club_hit_b.wav"], "db": [-6.2]},
	Sfx.CLUB_HIT_SCENERY: {"files": ["club_hit_wood_a.wav"], "db": [-5.3]},
	Sfx.JUMP: {"files": ["jump_a.wav"], "db": [-6.4]},
	Sfx.LAND: {"files": ["land_a.wav"], "db": [10.9]},
	Sfx.FOOTSTEP: {"files": ["footstep_a.wav", "footstep_b.wav"], "db": [-4.6, -5.0]},
	Sfx.SKID_ICE: {"files": ["ice_slide_a.wav"], "db": [-7.6]},
	Sfx.BOUNCE: {"files": ["spring_bounce_a.wav"], "db": [5.0]},
	Sfx.PLAYER_HURT: {"files": ["player_hurt_a.wav"], "db": [-0.5]},
	Sfx.PLAYER_HURT_HEAVY: {"files": ["player_hurt_b.wav"], "db": [-2.0]},
	Sfx.PLAYER_DEATH: {"files": ["player_death_a.wav"], "db": [-7.3]},
	Sfx.ENEMY_HURT: {"files": ["enemy_hurt_a.wav"], "db": [-1.0]},
	Sfx.ENEMY_DEATH: {"files": ["enemy_death_a.wav", "enemy_death_b.wav"], "db": [-0.4, -5.7]},
	Sfx.ENEMY_VOICE: {
		"files": ["dino_voice_a.wav", "dino_voice_b.wav", "dino_voice_c.wav", "dino_voice_d.wav"],
		"db": [4.2, 0.3, -7.4, -0.1],
	},
	Sfx.FEAST_CHOMP: {"files": ["food_chomp_a.ogg"], "db": [-2.3]},
	Sfx.BOSS_HIT: {"files": ["boss_hit_a.wav"], "db": [-3.1]},
	Sfx.BOSS_ROAR: {"files": ["boss_roar_a.wav"], "db": [2.8]},
	Sfx.BOSS_CHEST_BEAT: {"files": ["boss_roar_b.wav"], "db": [-8.1]},
	Sfx.BOSS_SPIT: {"files": ["fireball_b.wav"], "db": [-0.5]},
	Sfx.BOSS_DEFEATED: {"files": ["explosion_big_a.wav"], "db": [-5.8]},
	Sfx.EXPLOSION: {"files": ["explosion_a.wav"], "db": [-6.8]},
	Sfx.IMPACT: {"files": ["explosion_b.wav"], "db": [-8.4]},
	Sfx.QUAKE: {"files": ["quake_a.wav"], "db": [-8.0]},
	Sfx.PICKUP: {
		"files": ["food_pickup_a.wav", "food_pickup_b.wav", "food_pickup_c.wav", "food_pickup_d.wav"],
		"db": [-0.8, -1.0, -0.4, -0.7],
	},
	Sfx.PICKUP_BIG: {"files": ["gem_pickup_a.wav"], "db": [-5.2]},
	Sfx.PICKUP_LETTER: {"files": ["gem_pickup_b.wav"], "db": [-7.3]},
	Sfx.HEART: {"files": ["energy_refill_a.wav"], "db": [-8.1]},
	Sfx.ONE_UP: {"files": ["one_up_a.wav"], "db": [-10.2]},
	Sfx.SPOT_OPENED: {"files": ["bonus_reveal_a.wav"], "db": [-8.7]},
	Sfx.GIANT_BONUS: {"files": ["bonus_reveal_b.wav"], "db": [-8.9]},
	Sfx.BLOCK_BREAK: {"files": ["breakable_smash_a.wav"], "db": [-3.9]},
	Sfx.BLOCK_BREAK_ICE: {"files": ["breakable_smash_ice_a.ogg"], "db": [-0.2]},
	Sfx.CHECKPOINT: {"files": ["checkpoint_a.wav"], "db": [-2.1]},
	Sfx.EXIT_OPEN: {"files": ["checkpoint_b.ogg"], "db": [3.1]},
	Sfx.SPLASH: {"files": ["splash_a.ogg"], "db": [2.7]},
	Sfx.CODE_ACCEPT: {"files": ["password_accept_a.wav"], "db": [-9.1], "bus": "UI"},
	Sfx.CODE_REJECT: {"files": ["password_reject_a.wav"], "db": [-4.4], "bus": "UI"},
	Sfx.MENU_MOVE: {"files": ["menu_move_a.wav"], "db": [4.9], "bus": "UI"},
	Sfx.MENU_SELECT: {"files": ["menu_select_a.wav"], "db": [-4.0], "bus": "UI"},
	Sfx.MENU_BACK: {"files": ["menu_back_a.wav"], "db": [-4.1], "bus": "UI"},
	Sfx.PAUSE_IN: {"files": ["pause_in_a.wav"], "db": [-4.6], "bus": "UI"},
	Sfx.PAUSE_OUT: {"files": ["pause_out_a.wav"], "db": [-4.2], "bus": "UI"},
	Sfx.TALLY_TICK: {"files": ["tally_tick_a.wav"], "db": [-7.2], "bus": "UI"},
	Sfx.TALLY_END: {"files": ["tally_end_a.wav"], "db": [-6.3], "bus": "UI"},
	Sfx.LOOP_FIRE: {"files": ["fire_loop_a.ogg"], "db": [4.3], "loop": true},
	Sfx.LOOP_WIND: {"files": ["ice_wind_loop_a.ogg"], "db": [0.7], "loop": true},
	Sfx.LOOP_LAVA: {"files": ["lava_bubble_loop_a.ogg"], "db": [1.9], "loop": true},
	# --- 2.0 batch 1: every effect of Sfx.EXPANSION_SFX (DESIGN.md F.2; PLAN.md P1.1) ------------------------------
	# "temp": true = the DESIGN F.2 pick (named in Sfx) is not imported yet; the row plays a fitting 1.0 file at that
	# file's measured volume. The audio owner's file replaces it (file + measured db, "temp" removed) - callers never
	# change. A file keeps one loop flag everywhere (Audio caches one stream per file).
	Sfx.SWAP: {"files": ["menu_select_a.wav"], "db": [-4.0], "temp": true},
	Sfx.SPEAR_STICK: {"files": ["club_hit_wood_a.wav"], "db": [-5.3], "temp": true},
	Sfx.VINE_CLIMB: {"files": ["footstep_b.wav"], "db": [-5.0], "temp": true},
	Sfx.RAFT_SPLASH: {"files": ["splash_a.ogg"], "db": [-0.3], "temp": true},
	Sfx.SPLASH_HEAVY: {"files": ["splash_a.ogg"], "db": [2.7], "temp": true},
	Sfx.GEYSER_BUBBLE: {"files": ["splash_a.ogg"], "db": [-3.3], "temp": true},
	Sfx.GEYSER_SPOUT: {"files": ["splash_a.ogg"], "db": [2.7], "temp": true},
	Sfx.TAR_GLUG: {"files": ["food_chomp_a.ogg"], "db": [-5.3], "temp": true},
	Sfx.EGG_DOWN: {"files": ["player_death_a.wav"], "db": [-7.3], "temp": true},
	Sfx.EGG_HATCH: {"files": ["energy_refill_a.wav"], "db": [-8.1], "temp": true},
	Sfx.DUO_HOP: {"files": ["spring_bounce_a.wav"], "db": [5.0], "temp": true},
	Sfx.CURL: {"files": ["club_swing_b.wav"], "db": [-3.7], "temp": true},
	Sfx.BAT_HIT: {"files": ["club_hit_b.wav"], "db": [-6.2], "temp": true},
	Sfx.BRACE: {"files": ["land_a.wav"], "db": [10.9], "temp": true},
	Sfx.PLATE: {"files": ["menu_select_a.wav"], "db": [-4.0], "temp": true},
	Sfx.DRUM: {"files": ["tally_tick_a.wav"], "db": [-7.2], "temp": true},
	Sfx.COUNT_IN: {"files": ["tally_tick_a.wav"], "db": [-7.2], "temp": true},
	Sfx.SEESAW: {"files": ["spring_bounce_a.wav"], "db": [5.0], "temp": true},
	Sfx.BOULDER_PUSH: {"files": ["quake_a.wav"], "db": [-8.0], "temp": true},
	Sfx.PULLEY: {"files": ["quake_a.wav"], "db": [-11.0], "temp": true},
	Sfx.DAZE: {"files": ["enemy_hurt_a.wav"], "db": [-1.0], "temp": true},
	# The DESIGN F.2 pick of the Chomper bite IS a shipped file (food_chomp; the caller adds Sfx.ENEMY_VOICE).
	Sfx.CHOMPER_BITE: {"files": ["food_chomp_a.ogg"], "db": [-2.3]},
	Sfx.COOKPOT_BANK: {"files": ["food_pickup_c.wav"], "db": [-0.4], "temp": true},
	Sfx.CRATE_DROP: {"files": ["club_swing_a.wav"], "db": [-3.4], "temp": true},
	Sfx.HOT_ROCK_FUSE: {"files": ["tally_tick_a.wav"], "db": [-7.2], "temp": true},
	Sfx.LOOP_HOT_ROCK_HURRY: {"files": ["fire_loop_a.ogg"], "db": [4.3], "loop": true, "temp": true},
	Sfx.CROWD_APPLAUSE: {"files": ["tally_end_a.wav"], "db": [-6.3], "bus": "UI", "temp": true},
	Sfx.CROWD_CHEER: {"files": ["one_up_a.wav"], "db": [-10.2], "bus": "UI", "temp": true},
	Sfx.PARTY_JOIN: {"files": ["checkpoint_a.wav"], "db": [-2.1], "bus": "UI", "temp": true},
	Sfx.COUNTDOWN_BEEP: {"files": ["tally_tick_a.wav"], "db": [-7.2], "temp": true},
	Sfx.COUNTDOWN_GO: {"files": ["bonus_reveal_b.wav"], "db": [-8.9], "temp": true},
	Sfx.SUDDEN_DEATH: {"files": ["password_reject_a.wav"], "db": [-4.4], "temp": true},
}

## context -> { "file", "db", "loop" }.
const MUSIC: Dictionary = {
	Sfx.MUSIC_TITLE: {"file": "title_a.ogg", "db": -9.7, "loop": true},
	Sfx.MUSIC_MENU: {"file": "password_screen_a.ogg", "db": -9.5, "loop": true},
	Sfx.MUSIC_MAP: {"file": "title_b.ogg", "db": -7.0, "loop": true},
	Sfx.MUSIC_JUNGLE: {"file": "level_jungle_a.ogg", "db": -6.2, "loop": true},
	Sfx.MUSIC_CAVE: {"file": "level_cave_a.ogg", "db": -10.9, "loop": true},
	Sfx.MUSIC_ICE: {"file": "level_ice_a.ogg", "db": -10.8, "loop": true},
	Sfx.MUSIC_VOLCANO: {"file": "level_volcano_a.ogg", "db": -6.7, "loop": true},
	Sfx.MUSIC_SHAFT: {"file": "level_extra_a.ogg", "db": -11.1, "loop": true},
	Sfx.MUSIC_GROTTO: {"file": "level_extra_b.ogg", "db": -8.2, "loop": true},
	Sfx.MUSIC_BONUS: {"file": "bonus_room_a.ogg", "db": -4.7, "loop": true},
	Sfx.MUSIC_SECRET: {"file": "bonus_room_b.ogg", "db": 2.4, "loop": true},
	Sfx.MUSIC_BOSS: {"file": "boss_a.ogg", "db": -6.6, "loop": true},
	Sfx.MUSIC_BOSS_FINAL: {"file": "boss_final_a.ogg", "db": -6.9, "loop": true},
	Sfx.MUSIC_FEAST: {"file": "invincible_loop_a.ogg", "db": -6.8, "loop": true},
	Sfx.MUSIC_LEVEL_COMPLETE: {"file": "level_complete_a.ogg", "db": -7.2, "loop": false},
	Sfx.MUSIC_TALLY: {"file": "tally_loop_a.ogg", "db": -2.2, "loop": true},
	Sfx.MUSIC_DEATH: {"file": "player_death_a.ogg", "db": -7.9, "loop": false},
	Sfx.MUSIC_GAME_OVER: {"file": "game_over_a.ogg", "db": -9.9, "loop": false},
	Sfx.MUSIC_GAME_OVER_LOOP: {"file": "game_over_loop_a.ogg", "db": -6.3, "loop": true},
	Sfx.MUSIC_ENDING: {"file": "ending_a.ogg", "db": -5.5, "loop": true},
	Sfx.MUSIC_CREDITS: {"file": "credits_a.ogg", "db": -1.7, "loop": true},
	# --- 2.0: every context of Sfx.EXPANSION_MUSIC (DESIGN.md F.2), "temp" as in SFX: a 1.0 track of the same mood at
	# its measured volume until the audio owner's file (batch 2, PLAN.md P2.6: loop regions) replaces it. ----------
	Sfx.MUSIC_CANYON: {"file": "level_volcano_a.ogg", "db": -6.7, "loop": true, "temp": true},
	Sfx.MUSIC_GULCH: {"file": "level_jungle_a.ogg", "db": -6.2, "loop": true, "temp": true},
	Sfx.MUSIC_FEN: {"file": "level_extra_b.ogg", "db": -8.2, "loop": true, "temp": true},
	Sfx.MUSIC_SPORE: {"file": "level_cave_a.ogg", "db": -10.9, "loop": true, "temp": true},
	Sfx.MUSIC_MANGROVE_CLIMB: {"file": "level_extra_a.ogg", "db": -11.1, "loop": true, "temp": true},
	Sfx.MUSIC_COAST: {"file": "level_jungle_a.ogg", "db": -6.2, "loop": true, "temp": true},
	Sfx.MUSIC_SEA_CAVES: {"file": "level_extra_b.ogg", "db": -8.2, "loop": true, "temp": true},
	Sfx.MUSIC_RUINS: {"file": "level_cave_a.ogg", "db": -10.9, "loop": true, "temp": true},
	Sfx.MUSIC_IDOL_HALL: {"file": "level_extra_b.ogg", "db": -8.2, "loop": true, "temp": true},
	Sfx.MUSIC_SKY_CLIMB: {"file": "level_ice_a.ogg", "db": -10.8, "loop": true, "temp": true},
	Sfx.MUSIC_STORM_GLIDE: {"file": "level_ice_a.ogg", "db": -10.8, "loop": true, "temp": true},
	Sfx.MUSIC_SPIRE: {"file": "level_volcano_a.ogg", "db": -6.7, "loop": true, "temp": true},
	Sfx.MUSIC_PYRE: {"file": "level_volcano_a.ogg", "db": -6.7, "loop": true, "temp": true},
	Sfx.MUSIC_BONUS_LAGOON: {"file": "bonus_room_a.ogg", "db": -4.7, "loop": true, "temp": true},
	Sfx.MUSIC_ENDING_RAFT: {"file": "ending_a.ogg", "db": -5.5, "loop": true, "temp": true},
	Sfx.MUSIC_BOSS_TUSKER: {"file": "boss_a.ogg", "db": -6.6, "loop": true, "temp": true},
	Sfx.MUSIC_BOSS_MANGROVE: {"file": "boss_a.ogg", "db": -6.6, "loop": true, "temp": true},
	Sfx.MUSIC_BOSS_INKJAW: {"file": "boss_a.ogg", "db": -6.6, "loop": true, "temp": true},
	Sfx.MUSIC_BOSS_IDOLS: {"file": "boss_a.ogg", "db": -6.6, "loop": true, "temp": true},
	Sfx.MUSIC_BOSS_ROC: {"file": "boss_final_a.ogg", "db": -6.9, "loop": true, "temp": true},
	Sfx.MUSIC_BOSS_CHIEFTAINS: {"file": "boss_final_a.ogg", "db": -6.9, "loop": true, "temp": true},
	Sfx.MUSIC_COOP_MENU: {"file": "password_screen_a.ogg", "db": -9.5, "loop": true, "temp": true},
	Sfx.MUSIC_VERSUS_LOBBY: {"file": "title_b.ogg", "db": -7.0, "loop": true, "temp": true},
	Sfx.MUSIC_VERSUS_BATTLE_A: {"file": "level_jungle_a.ogg", "db": -6.2, "loop": true, "temp": true},
	Sfx.MUSIC_VERSUS_BATTLE_B: {"file": "level_volcano_a.ogg", "db": -6.7, "loop": true, "temp": true},
	Sfx.MUSIC_VERSUS_BATTLE_C: {"file": "level_extra_a.ogg", "db": -11.1, "loop": true, "temp": true},
	Sfx.MUSIC_VERSUS_SUDDEN_DEATH: {"file": "boss_final_a.ogg", "db": -6.9, "loop": true, "temp": true},
	Sfx.MUSIC_ROUND_WIN: {"file": "level_complete_a.ogg", "db": -7.2, "loop": false, "temp": true},
	Sfx.MUSIC_MATCH_WIN: {"file": "level_complete_a.ogg", "db": -7.2, "loop": false, "temp": true},
	Sfx.MUSIC_VERSUS_RESULTS: {"file": "tally_loop_a.ogg", "db": -2.2, "loop": true, "temp": true},
}


## True while the row of an effect or music name still plays a stand-in 1.0 file (`"temp": true`, see SFX).
static func is_temp(name: StringName) -> bool:
	var entry: Dictionary = SFX.get(name, MUSIC.get(name, {}))
	return bool(entry.get("temp", false))


## Every effect and music name whose row is still a stand-in, sorted (the audio owner's work list).
static func temp_names() -> Array[StringName]:
	var result: Array[StringName] = []
	for table: Dictionary in [SFX, MUSIC]:
		for name: StringName in table:
			if bool(table[name].get("temp", false)):
				result.append(name)
	result.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return result
