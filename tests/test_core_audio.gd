extends TestCase
## Audio: music stack with resume positions, suspension while the application is in the background.
## Headless runs have no audio device: Audio keeps a clock for the current track, so positions behave the same.


func before_each() -> void:
	Audio.set_suspended(false)
	Audio.play_music(&"", 0.0)


func after_each() -> void:
	Audio.set_suspended(false)
	Audio.play_music(&"", 0.0)


## Wait by the wall clock, which is what Audio's stand-in clock measures (a scene timer can fire after a single long
## first frame of the run, when hardly any wall time has passed since the music started).
func _wait(seconds: float) -> void:
	var until: int = Time.get_ticks_msec() + roundi(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		await get_tree().process_frame


func test_pop_music_continues_where_the_track_was_interrupted() -> void:
	Audio.play_music(Sfx.MUSIC_JUNGLE, 0.0)
	await _wait(0.3)
	var interrupted_at: float = Audio.get_music_position()
	assert_true(interrupted_at >= 0.2, "the level track ran for a while (%f)" % interrupted_at)
	Audio.push_music(Sfx.MUSIC_FEAST, 0.0)
	assert_eq(Audio.get_music_context(), Sfx.MUSIC_FEAST)
	assert_true(Audio.get_music_position() < 0.1, "the feast track starts at its beginning")
	await _wait(0.2)
	Audio.pop_music(0.0)
	assert_eq(Audio.get_music_context(), Sfx.MUSIC_JUNGLE)
	var resumed_at: float = Audio.get_music_position()
	assert_true(resumed_at >= interrupted_at - 0.01 and resumed_at < interrupted_at + 0.1,
		"resumed at %f, interrupted at %f" % [resumed_at, interrupted_at])


func test_nested_pushes_unwind_in_order() -> void:
	Audio.play_music(Sfx.MUSIC_CAVE, 0.0)
	await _wait(0.2)
	Audio.push_music(Sfx.MUSIC_BOSS, 0.0)
	await _wait(0.3)
	var boss_at: float = Audio.get_music_position()
	Audio.push_music(Sfx.MUSIC_FEAST, 0.0)
	Audio.push_music(Sfx.MUSIC_FEAST, 0.0)
	Audio.pop_music(0.0)
	assert_eq(Audio.get_music_context(), Sfx.MUSIC_BOSS, "pushing the playing context again is ignored")
	assert_true(Audio.get_music_position() >= boss_at - 0.01, "the boss track continues")
	Audio.pop_music(0.0)
	assert_eq(Audio.get_music_context(), Sfx.MUSIC_CAVE)
	var cave_at: float = Audio.get_music_position()
	assert_true(cave_at >= 0.15 and cave_at < 0.35, "the cave track continues from about 0.2 s (%f)" % cave_at)
	Audio.pop_music(0.0)
	assert_eq(Audio.get_music_context(), Sfx.MUSIC_CAVE, "popping an empty stack changes nothing")


func test_play_music_forgets_the_stack() -> void:
	Audio.play_music(Sfx.MUSIC_ICE, 0.0)
	Audio.push_music(Sfx.MUSIC_BOSS, 0.0)
	Audio.play_music(Sfx.MUSIC_MAP, 0.0)
	Audio.pop_music(0.0)
	assert_eq(Audio.get_music_context(), Sfx.MUSIC_MAP)
	Audio.stop_music(0.0)
	assert_eq(Audio.get_music_context(), &"")
	assert_eq(Audio.get_music_position(), 0.0, "silence has no position")


func test_resume_point_stays_inside_the_track() -> void:
	var stream: AudioStream = load(AudioTable.MUSIC_DIR + str(AudioTable.MUSIC[Sfx.MUSIC_JUNGLE]["file"]))
	var length: float = stream.get_length()
	assert_true(length > 1.0)
	assert_almost_eq(Audio._resume_point(stream, true, length + 1.5), 1.5, 0.001, "a loop wraps around")
	assert_almost_eq(Audio._resume_point(stream, true, 2.0), 2.0, 0.001)
	assert_eq(Audio._resume_point(stream, false, length + 1.0), 0.0, "a finished jingle starts over")
	assert_eq(Audio._resume_point(stream, false, -3.0), 0.0)


func test_suspension_halts_music_and_drops_effects() -> void:
	Audio.play_music(Sfx.MUSIC_JUNGLE, 0.0)
	await _wait(0.15)
	Audio.set_suspended(true)
	assert_true(Audio.is_suspended())
	var held_at: float = Audio.get_music_position()
	var jump_frame: int = int(Audio._sfx_started_frame.get(Sfx.JUMP, -1))
	Audio.play_sfx(Sfx.JUMP)
	assert_eq(int(Audio._sfx_started_frame.get(Sfx.JUMP, -1)), jump_frame, "no effect starts while suspended")
	await _wait(0.2)
	assert_almost_eq(Audio.get_music_position(), held_at, 0.001, "the music stands still in the background")
	Audio.push_music(Sfx.MUSIC_BOSS, 0.0)
	assert_eq(Audio.get_music_context(), Sfx.MUSIC_BOSS, "music changes made meanwhile still count")
	assert_eq(Audio.get_music_position(), 0.0)
	Audio.set_suspended(false)
	assert_false(Audio.is_suspended())
	await _wait(0.15)
	assert_true(Audio.get_music_position() > 0.05, "the new track runs after the resume")
	Audio.pop_music(0.0)
	assert_true(Audio.get_music_position() >= held_at - 0.01, "and the level track still continues where it was")
	Audio.play_sfx(Sfx.JUMP)
	assert_eq(int(Audio._sfx_started_frame.get(Sfx.JUMP, -1)), Engine.get_process_frames())


func test_mix_levels_stay_below_full_scale() -> void:
	# Per-file volumes come from tools/audio_loudness.py (ASSET_MANIFEST 13.4); the master limiter catches overlaps.
	var master: int = AudioServer.get_bus_index(&"Master")
	var limiter: AudioEffectHardLimiter = null
	for i: int in AudioServer.get_bus_effect_count(master):
		if AudioServer.get_bus_effect(master, i) is AudioEffectHardLimiter:
			limiter = AudioServer.get_bus_effect(master, i) as AudioEffectHardLimiter
	assert_not_null(limiter, "the master bus has a hard limiter")
	if limiter != null:
		assert_true(limiter.ceiling_db < 0.0, "it limits below full scale")
	for event: StringName in AudioTable.SFX:
		var entry: Dictionary = AudioTable.SFX[event]
		assert_eq((entry["files"] as Array).size(), (entry["db"] as Array).size(), "%s: one volume per file" % event)
		for db: Variant in entry["db"]:
			assert_true(float(db) >= -24.0 and float(db) <= 12.0, "%s: a measured volume, not a typo (%s)" % [event, db])
	for context: StringName in AudioTable.MUSIC:
		var db: float = float(AudioTable.MUSIC[context]["db"])
		assert_true(db >= -24.0 and db <= 6.0, "%s: a measured volume (%s)" % [context, db])
