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
	# The audio owner's files (.tools/asset_candidates/expansion/_handover/audio/AUDIO_BATCH1.md: CC0, measured with
	# tools/audio_loudness.py and its OFFSETS / LOOPS rows; every loop is a whole-file loop). A row marked "temp": true
	# plays a stand-in 1.0 file at that file's volume until its pick is imported; callers never change. A file keeps
	# one loop flag everywhere (Audio caches one stream per file).
	Sfx.SWAP: {"files": ["swap_a.wav"], "db": [-5.0]},
	Sfx.SPEAR_STICK: {"files": ["spear_stick_a.wav"], "db": [-0.9]},
	Sfx.VINE_CLIMB: {"files": ["vine_climb_a.wav"], "db": [-4.1]},
	Sfx.RAFT_SPLASH: {"files": ["raft_splash_a.wav", "raft_splash_b.wav"], "db": [-2.9, -1.1]},
	Sfx.SPLASH_HEAVY: {"files": ["splash_heavy_a.wav"], "db": [2.6]},
	Sfx.GEYSER_BUBBLE: {"files": ["geyser_bubble_a.wav"], "db": [3.6]},
	Sfx.GEYSER_SPOUT: {"files": ["splash_heavy_a.wav"], "db": [2.6]},
	Sfx.TAR_GLUG: {"files": ["tar_glug_a.wav"], "db": [-0.3]},
	Sfx.EGG_DOWN: {"files": ["egg_down_a.wav"], "db": [-2.1]},
	Sfx.EGG_HATCH: {"files": ["egg_hatch_a.wav"], "db": [-10.2]},
	# Variant 0 = the boost (Shoulder Hop), variant 1 = a rider lands (Totem Ride): Audio.play_sfx(Sfx.DUO_HOP, 0 / 1).
	Sfx.DUO_HOP: {"files": ["duo_hop_a.wav", "duo_hop_b.wav"], "db": [-9.1, 2.7]},
	Sfx.CURL: {"files": ["curl_a.wav"], "db": [5.8]},
	Sfx.BAT_HIT: {"files": ["bat_hit_a.wav", "bat_hit_b.wav", "bat_hit_c.wav"], "db": [-2.6, -2.4, -0.3]},
	Sfx.BRACE: {"files": ["brace_a.wav"], "db": [-1.2]},
	Sfx.PLATE: {"files": ["plate_a.ogg"], "db": [-1.4]},
	Sfx.DRUM: {"files": ["drum_beat_a.wav"], "db": [-7.5]},
	Sfx.COUNT_IN: {"files": ["drum_beat_a.wav"], "db": [-7.5]},
	Sfx.SEESAW: {"files": ["seesaw_a.wav"], "db": [-2.3]},
	Sfx.BOULDER_PUSH: {"files": ["boulder_push_a.ogg"], "db": [-1.3]},
	Sfx.PULLEY: {"files": ["pulley_a.ogg"], "db": [-3.3]},
	Sfx.DAZE: {"files": ["daze_a.wav"], "db": [-5.5]},
	# The growl (the shipped dino_voice_b) and the chomp layered in one file: play it alone.
	Sfx.CHOMPER_BITE: {"files": ["chomper_bite_a.wav"], "db": [-0.8]},
	Sfx.COOKPOT_BANK: {"files": ["cookpot_bank_a.wav"], "db": [-12.2]},
	Sfx.CRATE_DROP: {"files": ["crate_drop_a.wav"], "db": [-5.8]},
	Sfx.HOT_ROCK_FUSE: {"files": ["drum_beat_a.wav"], "db": [-7.5]},
	Sfx.LOOP_HOT_ROCK_HURRY: {"files": ["alarm_loop_a.wav"], "db": [-5.4], "loop": true},
	Sfx.CROWD_APPLAUSE: {"files": ["crowd_applause_a.ogg"], "db": [-1.8]},
	Sfx.CROWD_CHEER: {"files": ["crowd_cheer_a.ogg"], "db": [-0.3]},
	Sfx.PARTY_JOIN: {"files": ["party_join_a.wav"], "db": [8.1], "bus": "UI"},
	Sfx.COUNTDOWN_BEEP: {"files": ["countdown_beep_a.wav"], "db": [-9.2]},
	Sfx.COUNTDOWN_GO: {"files": ["countdown_go_a.wav"], "db": [-0.9]},
	Sfx.SUDDEN_DEATH: {"files": ["sudden_death_a.wav"], "db": [-7.0]},
	# Versus clang (DESIGN.md E.2 "the Colossus clank"): the shipped glance-off clank of the armoured Colossus.
	Sfx.CLANG: {"files": ["club_hit_wood_a.wav"], "db": [-5.3]},
	# --- 2.0 batch 2 (PLAN.md P2.6 / P2.11; _handover/audio/AUDIO_BATCH2.md): the bolt of zones/lightning (world-A)
	# and the gong that ends a versus round (DESIGN.md E.8, Junkala fanfare1; Flow.end_round plays it). ----------------
	Sfx.LIGHTNING_STRIKE: {"files": ["lightning_strike_a.wav"], "db": [-4.6]},
	Sfx.ROUND_GONG: {"files": ["round_gong_a.wav"], "db": [-2.1]},
}

## context -> { "file", "db", "loop" [, "loop_start"] }. "loop_start" (2.0, AudioTable batch 2): seconds into the file
## where the loop restarts - the intro before it plays once, the loop runs from there to the end of the file (the audio
## owner cuts each file at its loop end; Ogg Vorbis cannot end a loop early). Missing = the whole file loops. A file
## keeps one loop flag and one loop start in every row that names it (Audio caches one stream per file).
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
	# --- 2.0: every context of Sfx.EXPANSION_MUSIC (DESIGN.md F.2). Batch 1 delivered the G1 slice's tracks (canyon,
	# co-op menu, lobby, battle A, the round / match jingles, results), batch 2 (PLAN.md P2.6 / P2.11, the audio owner's
	# _handover/audio/AUDIO_BATCH2.md) every other one: CC0, measured with tools/audio_loudness.py, whole-file loops (the
	# loop regions are cut out of the renders, so no row needs "loop_start"). No 2.0 row is a stand-in any more. -------
	Sfx.MUSIC_CANYON: {"file": "level_canyon_a.ogg", "db": -0.1, "loop": true},
	Sfx.MUSIC_GULCH: {"file": "level_gulch_a.ogg", "db": -5.0, "loop": true},
	Sfx.MUSIC_FEN: {"file": "level_fen_a.ogg", "db": -7.6, "loop": true},
	Sfx.MUSIC_SPORE: {"file": "level_spore_a.ogg", "db": -0.1, "loop": true},
	Sfx.MUSIC_MANGROVE_CLIMB: {"file": "level_mangrove_climb_a.ogg", "db": -8.2, "loop": true},
	Sfx.MUSIC_COAST: {"file": "level_coast_a.ogg", "db": -4.4, "loop": true},
	Sfx.MUSIC_SEA_CAVES: {"file": "level_sea_caves_a.ogg", "db": -5.6, "loop": true},
	Sfx.MUSIC_RUINS: {"file": "level_ruins_a.ogg", "db": -8.0, "loop": true},
	Sfx.MUSIC_IDOL_HALL: {"file": "level_idol_hall_a.ogg", "db": -5.4, "loop": true},
	Sfx.MUSIC_SKY_CLIMB: {"file": "level_sky_climb_a.ogg", "db": -0.1, "loop": true},
	Sfx.MUSIC_STORM_GLIDE: {"file": "level_storm_glide_a.ogg", "db": -0.1, "loop": true},
	Sfx.MUSIC_SPIRE: {"file": "level_spire_a.ogg", "db": -6.6, "loop": true},
	Sfx.MUSIC_PYRE: {"file": "level_pyre_a.ogg", "db": -7.4, "loop": true},
	Sfx.MUSIC_BONUS_LAGOON: {"file": "bonus_lagoon_a.ogg", "db": -5.7, "loop": true},
	Sfx.MUSIC_ENDING_RAFT: {"file": "ending_raft_a.ogg", "db": -3.0, "loop": true},
	Sfx.MUSIC_BOSS_TUSKER: {"file": "boss_tusker_a.ogg", "db": -1.4, "loop": true},
	Sfx.MUSIC_BOSS_MANGROVE: {"file": "boss_mangrove_a.ogg", "db": -1.3, "loop": true},
	Sfx.MUSIC_BOSS_INKJAW: {"file": "boss_inkjaw_a.ogg", "db": -1.5, "loop": true},
	Sfx.MUSIC_BOSS_IDOLS: {"file": "boss_idols_a.ogg", "db": -12.0, "loop": true},
	Sfx.MUSIC_BOSS_ROC: {"file": "boss_roc_a.ogg", "db": -1.0, "loop": true},
	Sfx.MUSIC_BOSS_CHIEFTAINS: {"file": "boss_chieftains_a.ogg", "db": -2.0, "loop": true},
	Sfx.MUSIC_COOP_MENU: {"file": "coop_menu_a.ogg", "db": -5.9, "loop": true},
	Sfx.MUSIC_VERSUS_LOBBY: {"file": "versus_lobby_a.ogg", "db": -2.6, "loop": true},
	Sfx.MUSIC_VERSUS_BATTLE_A: {"file": "versus_battle_a.ogg", "db": -8.6, "loop": true},
	Sfx.MUSIC_VERSUS_BATTLE_B: {"file": "versus_battle_b.ogg", "db": -8.3, "loop": true},
	Sfx.MUSIC_VERSUS_BATTLE_C: {"file": "versus_battle_c.ogg", "db": -1.4, "loop": true},
	# Sudden death (DESIGN.md E.6): Flow pushes it on Events.round_sudden_death_started for the rest of the round. The
	# F.2 pick (Wolfgang_ "8-Bit Battle Loop") is too short to loop; F.2's runner-up ships (Junkala "dangerous encounter A
	# (faster)", a 32-beat loop).
	Sfx.MUSIC_VERSUS_SUDDEN_DEATH: {"file": "versus_sudden_death_a.ogg", "db": -4.7, "loop": true},
	Sfx.MUSIC_ROUND_WIN: {"file": "round_win_a.ogg", "db": -8.0, "loop": false},
	Sfx.MUSIC_MATCH_WIN: {"file": "match_win_a.ogg", "db": 2.8, "loop": false},
	Sfx.MUSIC_VERSUS_RESULTS: {"file": "versus_results_a.ogg", "db": -3.8, "loop": true},
}


## 2.0 (batch 2): where the loop of a music context restarts, in seconds of its file (the row's "loop_start"; 0 = the
## whole file loops, also for a jingle or an unknown context).
static func loop_start(context: StringName) -> float:
	var entry: Dictionary = MUSIC.get(context, {})
	if not bool(entry.get("loop", false)):
		return 0.0
	var value: Variant = entry.get("loop_start", 0.0)
	return maxf(float(value), 0.0) if value is float or value is int else 0.0


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
