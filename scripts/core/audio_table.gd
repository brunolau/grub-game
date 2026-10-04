class_name AudioTable
extends RefCounted
## Event name -> audio files, from docs/ASSET_MANIFEST.md section 13 (volume_db values are the manifest's
## starting points). Owner: core. Other modules never reference audio files directly.

const SFX_DIR: String = "res://assets/audio/sfx/"
const MUSIC_DIR: String = "res://assets/audio/music/"

## event -> { "files": [variants], "db": [volume_db per variant], "bus": bus name (default "SFX") }.
## Several variants are cycled (or picked with the `variant` argument of Audio.play_sfx).
const SFX: Dictionary = {
	Sfx.CLUB_SWING: {"files": ["club_swing_a.wav"], "db": [0.0]},
	Sfx.HAMMER_SWING: {"files": ["club_swing_b.wav"], "db": [0.0]},
	Sfx.THROW: {"files": ["projectile_throw_b.wav"], "db": [0.0]},
	Sfx.CLUB_HIT: {"files": ["club_hit_a.wav"], "db": [0.3]},
	Sfx.CLUB_HIT_HEAVY: {"files": ["club_hit_b.wav"], "db": [0.0]},
	Sfx.CLUB_HIT_SCENERY: {"files": ["club_hit_wood_a.wav"], "db": [-6.0]},
	Sfx.JUMP: {"files": ["jump_a.wav"], "db": [0.0]},
	Sfx.LAND: {"files": ["land_a.wav"], "db": [7.4]},
	Sfx.FOOTSTEP: {"files": ["footstep_a.wav", "footstep_b.wav"], "db": [1.5, 0.6]},
	Sfx.SKID_ICE: {"files": ["ice_slide_a.wav"], "db": [0.0]},
	Sfx.BOUNCE: {"files": ["spring_bounce_a.wav"], "db": [8.4]},
	Sfx.PLAYER_HURT: {"files": ["player_hurt_a.wav"], "db": [0.0]},
	Sfx.PLAYER_HURT_HEAVY: {"files": ["player_hurt_b.wav"], "db": [0.1]},
	Sfx.PLAYER_DEATH: {"files": ["player_death_a.wav"], "db": [0.0]},
	Sfx.ENEMY_HURT: {"files": ["enemy_hurt_a.wav"], "db": [0.0]},
	Sfx.ENEMY_DEATH: {"files": ["enemy_death_a.wav", "enemy_death_b.wav"], "db": [0.0, 0.0]},
	Sfx.ENEMY_VOICE: {
		"files": ["dino_voice_a.wav", "dino_voice_b.wav", "dino_voice_c.wav", "dino_voice_d.wav"],
		"db": [7.7, 3.1, -4.9, -0.4],
	},
	Sfx.FEAST_CHOMP: {"files": ["food_chomp_a.ogg"], "db": [-4.2]},
	Sfx.BOSS_HIT: {"files": ["boss_hit_a.wav"], "db": [0.0]},
	Sfx.BOSS_ROAR: {"files": ["boss_roar_a.wav"], "db": [0.1]},
	Sfx.BOSS_CHEST_BEAT: {"files": ["boss_roar_b.wav"], "db": [-4.9]},
	Sfx.BOSS_SPIT: {"files": ["fireball_b.wav"], "db": [0.0]},
	Sfx.BOSS_DEFEATED: {"files": ["explosion_big_a.wav"], "db": [-3.0]},
	Sfx.EXPLOSION: {"files": ["explosion_a.wav"], "db": [-3.0]},
	Sfx.IMPACT: {"files": ["explosion_b.wav"], "db": [-3.0]},
	Sfx.QUAKE: {"files": ["quake_a.wav"], "db": [-3.0]},
	Sfx.PICKUP: {
		"files": ["food_pickup_a.wav", "food_pickup_b.wav", "food_pickup_c.wav", "food_pickup_d.wav"],
		"db": [0.0, 0.0, 0.0, 0.0],
	},
	Sfx.PICKUP_BIG: {"files": ["gem_pickup_a.wav"], "db": [0.0]},
	Sfx.PICKUP_LETTER: {"files": ["gem_pickup_b.wav"], "db": [0.0]},
	Sfx.HEART: {"files": ["energy_refill_a.wav"], "db": [0.0]},
	Sfx.ONE_UP: {"files": ["one_up_a.wav"], "db": [0.0]},
	Sfx.SPOT_OPENED: {"files": ["bonus_reveal_a.wav"], "db": [0.0]},
	Sfx.GIANT_BONUS: {"files": ["bonus_reveal_b.wav"], "db": [0.0]},
	Sfx.BLOCK_BREAK: {"files": ["breakable_smash_a.wav"], "db": [0.0]},
	Sfx.BLOCK_BREAK_ICE: {"files": ["breakable_smash_ice_a.ogg"], "db": [-4.2]},
	Sfx.CHECKPOINT: {"files": ["checkpoint_a.wav"], "db": [1.7]},
	Sfx.EXIT_OPEN: {"files": ["checkpoint_b.ogg"], "db": [4.1]},
	Sfx.SPLASH: {"files": ["splash_a.ogg"], "db": [2.9]},
	Sfx.CODE_ACCEPT: {"files": ["password_accept_a.wav"], "db": [0.0], "bus": "UI"},
	Sfx.CODE_REJECT: {"files": ["password_reject_a.wav"], "db": [-0.9], "bus": "UI"},
	Sfx.MENU_MOVE: {"files": ["menu_move_a.wav"], "db": [0.0], "bus": "UI"},
	Sfx.MENU_SELECT: {"files": ["menu_select_a.wav"], "db": [1.9], "bus": "UI"},
	Sfx.MENU_BACK: {"files": ["menu_back_a.wav"], "db": [0.0], "bus": "UI"},
	Sfx.PAUSE_IN: {"files": ["pause_in_a.wav"], "db": [0.2], "bus": "UI"},
	Sfx.PAUSE_OUT: {"files": ["pause_out_a.wav"], "db": [0.1], "bus": "UI"},
	Sfx.TALLY_TICK: {"files": ["tally_tick_a.wav"], "db": [0.0], "bus": "UI"},
	Sfx.TALLY_END: {"files": ["tally_end_a.wav"], "db": [1.5], "bus": "UI"},
	Sfx.LOOP_FIRE: {"files": ["fire_loop_a.ogg"], "db": [0.4], "loop": true},
	Sfx.LOOP_WIND: {"files": ["ice_wind_loop_a.ogg"], "db": [0.1], "loop": true},
	Sfx.LOOP_LAVA: {"files": ["lava_bubble_loop_a.ogg"], "db": [1.5], "loop": true},
}

## context -> { "file", "db", "loop" }.
const MUSIC: Dictionary = {
	Sfx.MUSIC_TITLE: {"file": "title_a.ogg", "db": -6.8, "loop": true},
	Sfx.MUSIC_MENU: {"file": "password_screen_a.ogg", "db": -4.4, "loop": true},
	Sfx.MUSIC_MAP: {"file": "title_b.ogg", "db": -3.8, "loop": true},
	Sfx.MUSIC_JUNGLE: {"file": "level_jungle_a.ogg", "db": -2.6, "loop": true},
	Sfx.MUSIC_CAVE: {"file": "level_cave_a.ogg", "db": -7.6, "loop": true},
	Sfx.MUSIC_ICE: {"file": "level_ice_a.ogg", "db": -7.2, "loop": true},
	Sfx.MUSIC_VOLCANO: {"file": "level_volcano_a.ogg", "db": -2.8, "loop": true},
	Sfx.MUSIC_SHAFT: {"file": "level_extra_a.ogg", "db": -7.6, "loop": true},
	Sfx.MUSIC_GROTTO: {"file": "level_extra_b.ogg", "db": -4.1, "loop": true},
	Sfx.MUSIC_BONUS: {"file": "bonus_room_a.ogg", "db": 1.2, "loop": true},
	Sfx.MUSIC_SECRET: {"file": "bonus_room_b.ogg", "db": 3.4, "loop": true},
	Sfx.MUSIC_BOSS: {"file": "boss_a.ogg", "db": -2.6, "loop": true},
	Sfx.MUSIC_BOSS_FINAL: {"file": "boss_final_a.ogg", "db": -3.0, "loop": true},
	Sfx.MUSIC_FEAST: {"file": "invincible_loop_a.ogg", "db": -3.4, "loop": true},
	Sfx.MUSIC_LEVEL_COMPLETE: {"file": "level_complete_a.ogg", "db": -3.2, "loop": false},
	Sfx.MUSIC_TALLY: {"file": "tally_loop_a.ogg", "db": 2.2, "loop": true},
	Sfx.MUSIC_DEATH: {"file": "player_death_a.ogg", "db": -4.3, "loop": false},
	Sfx.MUSIC_GAME_OVER: {"file": "game_over_a.ogg", "db": -5.2, "loop": false},
	Sfx.MUSIC_GAME_OVER_LOOP: {"file": "game_over_loop_a.ogg", "db": -3.9, "loop": true},
	Sfx.MUSIC_ENDING: {"file": "ending_a.ogg", "db": -3.8, "loop": true},
	Sfx.MUSIC_CREDITS: {"file": "credits_a.ogg", "db": 1.5, "loop": true},
}
