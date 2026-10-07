extends TestCase
## AudioTable batch 1 (docs/expansion/PLAN.md P1.1): every 2.0 effect and music name of Sfx has a row that plays - a
## stand-in 1.0 file marked "temp" until the audio owner's file is imported - and the feast music shared by a party
## (Audio.hold_music) leaves the music stack cleanly. Batch 2 (P2.6): loop regions ("loop_start"), the effects mute of
## the deciding-moment replay and the versus sudden-death music.

## What the G1 vertical slice plays (PLAN.md 4.2 gate G1): canyon music, the co-op join, the versus menus and battle,
## the round stingers, and the whole effect batch.
const G1_MUSIC: Array[StringName] = [
	Sfx.MUSIC_CANYON, Sfx.MUSIC_COOP_MENU, Sfx.MUSIC_VERSUS_LOBBY, Sfx.MUSIC_VERSUS_BATTLE_A, Sfx.MUSIC_VERSUS_BATTLE_B,
	Sfx.MUSIC_VERSUS_BATTLE_C, Sfx.MUSIC_VERSUS_SUDDEN_DEATH, Sfx.MUSIC_ROUND_WIN, Sfx.MUSIC_MATCH_WIN,
	Sfx.MUSIC_VERSUS_RESULTS,
]
const G1_SFX: Array[StringName] = [
	Sfx.PARTY_JOIN, Sfx.COUNTDOWN_BEEP, Sfx.COUNTDOWN_GO, Sfx.SUDDEN_DEATH, Sfx.COOKPOT_BANK, Sfx.CRATE_DROP,
	Sfx.SWAP, Sfx.EGG_DOWN, Sfx.EGG_HATCH, Sfx.DUO_HOP, Sfx.CURL, Sfx.BAT_HIT, Sfx.PLATE, Sfx.COUNT_IN,
]


func after_each() -> void:
	Audio.set_effects_muted(false)
	Audio.stop_music(0.0)
	Audio.stop_all_sfx()
	Game.new_game(Defs.Difficulty.BEGINNER)
	Flow.current_screen = Flow.SCREEN_BOOT


func test_every_expansion_name_has_a_row_with_existing_files() -> void:
	for event: StringName in Sfx.EXPANSION_SFX:
		assert_true(AudioTable.SFX.has(event), "effect %s has a row" % event)
		if not AudioTable.SFX.has(event):
			continue
		var entry: Dictionary = AudioTable.SFX[event]
		var files: Array = entry["files"]
		assert_eq(files.size(), (entry["db"] as Array).size(), "%s: one volume per file" % event)
		for file: Variant in files:
			assert_true(ResourceLoader.exists(AudioTable.SFX_DIR + str(file)), "%s: %s exists" % [event, file])
	for context: StringName in Sfx.EXPANSION_MUSIC:
		assert_true(AudioTable.MUSIC.has(context), "music %s has a row" % context)
		if not AudioTable.MUSIC.has(context):
			continue
		var file: String = str(AudioTable.MUSIC[context]["file"])
		assert_true(ResourceLoader.exists(AudioTable.MUSIC_DIR + file), "%s: %s exists" % [context, file])
	assert_eq(Sfx.EXPANSION_SFX.size() + Sfx.EXPANSION_MUSIC.size(), 65, "the 2.0 names of Sfx")


func test_effect_and_music_names_never_collide() -> void:
	for event: StringName in AudioTable.SFX:
		assert_false(AudioTable.MUSIC.has(event), "%s is an effect or a context, never both" % event)


func test_temp_rows_are_marked_and_listed() -> void:
	var temp: Array[StringName] = AudioTable.temp_names()
	for name: StringName in temp:
		assert_true(AudioTable.is_temp(name))
		assert_true(Sfx.EXPANSION_SFX.has(name) or Sfx.EXPANSION_MUSIC.has(name), "only 2.0 rows are stand-ins: %s" % name)
	for event: StringName in [Sfx.CLUB_SWING, Sfx.PICKUP, Sfx.LOOP_FIRE]:
		assert_false(AudioTable.is_temp(event), "a 1.0 row is final: %s" % event)
	assert_false(AudioTable.is_temp(Sfx.CHOMPER_BITE), "the Chomper bite's pick is a shipped file")
	assert_false(AudioTable.is_temp(&"no_such_name"))
	var sorted: Array[StringName] = temp.duplicate()
	sorted.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	assert_eq(temp, sorted, "the work list is sorted")


func test_a_file_keeps_one_loop_flag() -> void:
	# Audio caches one stream per file and sets its loop flag when it loads it: a file used as a loop and as a
	# one-shot would play wrong in one of the two places.
	var loops: Dictionary = {}
	for event: StringName in AudioTable.SFX:
		var entry: Dictionary = AudioTable.SFX[event]
		for file: Variant in entry["files"]:
			_check_loop(loops, AudioTable.SFX_DIR + str(file), bool(entry.get("loop", false)), event)
	for context: StringName in AudioTable.MUSIC:
		var entry: Dictionary = AudioTable.MUSIC[context]
		_check_loop(loops, AudioTable.MUSIC_DIR + str(entry["file"]), bool(entry["loop"]), context)


func _check_loop(loops: Dictionary, path: String, loop: bool, name: StringName) -> void:
	if loops.has(path):
		assert_eq(loops[path], loop, "%s: %s keeps one loop flag" % [name, path.get_file()])
	else:
		loops[path] = loop


## Batch 2 (the audio owner's suggestion, AUDIO_BATCH2.md): no 2.0 name plays a stand-in any more, and the music fits
## DESIGN.md F.2's budget - every file at most the largest 1.0 track, all 30 at most 30 x the 1.0 average.
func test_batch_2_left_no_stand_in_and_fits_the_music_budget() -> void:
	assert_eq(AudioTable.temp_names(), [] as Array[StringName], "every 2.0 name plays its own file")
	var total: int = 0
	for context: StringName in Sfx.EXPANSION_MUSIC:
		var path: String = AudioTable.MUSIC_DIR + str(AudioTable.MUSIC[context]["file"])
		var file: FileAccess = FileAccess.open(path, FileAccess.READ)
		assert_not_null(file, "%s exists" % path)
		if file == null:
			continue
		var size: int = file.get_length()
		assert_true(size <= 3553438, "%s fits the largest 1.0 track" % path)
		total += size
	assert_true(total <= 44377495, "the 2.0 music stays within 30 x the 1.0 average")
	assert_true(AudioTable.SFX.has(Sfx.ROUND_GONG), "the gong of E.8 has its row")


## Batch 2: a loop region starts inside its file, only on a loop, and a file keeps one loop start in every row.
func test_loop_regions_are_sound() -> void:
	var starts: Dictionary = {}
	for context: StringName in AudioTable.MUSIC:
		var entry: Dictionary = AudioTable.MUSIC[context]
		var start: float = AudioTable.loop_start(context)
		assert_true(start >= 0.0)
		if entry.has("loop_start"):
			var value: Variant = entry["loop_start"]
			assert_true(value is float or value is int, "%s: loop_start is a number of seconds" % context)
			assert_true(bool(entry["loop"]), "%s: only a loop has a loop region" % context)
			var stream: AudioStream = load(AudioTable.MUSIC_DIR + str(entry["file"])) as AudioStream
			if stream != null:
				assert_true(start < stream.get_length(), "%s: the loop starts inside the file" % context)
		else:
			assert_eq(start, 0.0, "%s: without a region the whole file loops" % context)
		var path: String = str(entry["file"])
		if starts.has(path):
			assert_eq(starts[path], start, "%s: %s keeps one loop start" % [context, path])
		else:
			starts[path] = start
	assert_eq(AudioTable.loop_start(Sfx.MUSIC_ROUND_WIN), 0.0, "a jingle never loops")
	assert_eq(AudioTable.loop_start(&"no_such_context"), 0.0)


func test_a_loop_region_plays_its_intro_once() -> void:
	assert_eq(Audio.loop_position(3.0, 10.0, 4.0), 3.0, "the intro, first pass")
	assert_eq(Audio.loop_position(9.5, 10.0, 4.0), 9.5)
	assert_almost_eq(Audio.loop_position(10.5, 10.0, 4.0), 4.5, 0.0001, "past the end: back to the loop start")
	assert_almost_eq(Audio.loop_position(22.0, 10.0, 4.0), 4.0, 0.0001, "two loops of 6 s later")
	assert_almost_eq(Audio.loop_position(23.0, 10.0, 0.0), 3.0, 0.0001, "no region: the whole file")
	assert_eq(Audio.loop_position(-1.0, 10.0, 4.0), 0.0)
	assert_eq(Audio.loop_position(5.0, 0.0, 0.0), 5.0, "unknown length: as it is")
	# The stream of a file gets its loop start (Ogg loop_offset); a file without a region keeps 0.
	var path: String = AudioTable.MUSIC_DIR + str(AudioTable.MUSIC[Sfx.MUSIC_CANYON]["file"])
	var cached: Variant = Audio._streams.get(path)
	Audio._streams.erase(path)
	var stream: AudioStreamOggVorbis = Audio._get_stream(path, true, 2.5) as AudioStreamOggVorbis
	assert_not_null(stream)
	if stream != null:
		assert_true(stream.loop)
		assert_almost_eq(stream.loop_offset, 2.5, 0.0001, "the loop restarts 2.5 s in")
		stream.loop_offset = 0.0
	Audio._streams.erase(path)
	if cached != null:
		Audio._streams[path] = cached


func test_muted_effects_play_nothing_and_music_goes_on() -> void:
	Audio.play_music(Sfx.MUSIC_VERSUS_BATTLE_A, 0.0)
	Audio.start_loop(Sfx.LOOP_FIRE)
	Audio.set_effects_muted(true)
	assert_true(Audio.are_effects_muted())
	assert_false(Audio._loops.has(Sfx.LOOP_FIRE), "a playing loop stops")
	Audio.start_loop(Sfx.LOOP_LAVA)
	assert_false(Audio._loops.has(Sfx.LOOP_LAVA), "no loop starts")
	var frame: int = Engine.get_process_frames()
	Audio.play_sfx(Sfx.CLUB_HIT)
	assert_ne(int(Audio._sfx_started_frame.get(Sfx.CLUB_HIT, -1)), frame, "no effect starts")
	assert_eq(Audio.get_music_context(), Sfx.MUSIC_VERSUS_BATTLE_A, "the music is not touched")
	Audio.set_effects_muted(false)
	Audio.play_sfx(Sfx.CLUB_HIT)
	assert_eq(int(Audio._sfx_started_frame.get(Sfx.CLUB_HIT, -1)), frame, "unmuted: effects play again")


func test_a_sudden_death_switches_the_round_to_its_music() -> void:
	Game.start_run(Defs.Difficulty.BEGINNER, Defs.GameMode.VERSUS, 2, 1)
	Flow.current_screen = Flow.SCREEN_LEVEL
	Audio.play_music(Sfx.MUSIC_VERSUS_BATTLE_A, 0.0)
	Events.round_sudden_death_started.emit(0, &"stampede")
	assert_eq(Audio.get_music_context(), Sfx.MUSIC_VERSUS_SUDDEN_DEATH, "DESIGN.md F.2: the sudden-death music")
	Audio.pop_music(0.0)
	assert_eq(Audio.get_music_context(), Sfx.MUSIC_VERSUS_BATTLE_A)
	Game.new_game(Defs.Difficulty.BEGINNER)
	Events.round_sudden_death_started.emit(0, &"stampede")
	assert_eq(Audio.get_music_context(), Sfx.MUSIC_VERSUS_BATTLE_A, "only a versus round reacts")


func test_the_g1_slice_plays_every_name_it_needs() -> void:
	Audio.preload_sfx()
	for event: StringName in Sfx.EXPANSION_SFX:
		if bool(AudioTable.SFX[event].get("loop", false)):
			Audio.start_loop(event)
			assert_true(Audio._loops.has(event), "%s loops" % event)
			Audio.stop_loop(event)
		else:
			Audio.play_sfx(event)
	for event: StringName in G1_SFX:
		assert_true(Audio._streams.has(AudioTable.SFX_DIR + str(AudioTable.SFX[event]["files"][0])), "%s is loaded" % event)
	for context: StringName in G1_MUSIC:
		if bool(AudioTable.MUSIC[context]["loop"]):
			Audio.play_music(context, 0.0)
		else:
			Audio.play_jingle(context, Sfx.MUSIC_VERSUS_RESULTS)
		assert_eq(Audio.get_music_context(), context, "%s plays" % context)
	assert_true(AudioTable.MUSIC.has(StringName(String(Sfx.MUSIC_CANYON))), "w5_l1 names its music by the context")


func test_a_feast_released_under_a_boss_leaves_the_stack() -> void:
	var hero_a: RefCounted = RefCounted.new()
	var hero_b: RefCounted = RefCounted.new()
	Audio.play_music(Sfx.MUSIC_CANYON, 0.0)
	Audio.hold_music(Sfx.MUSIC_FEAST, hero_a)
	Audio.hold_music(Sfx.MUSIC_FEAST, hero_b)
	assert_eq(Audio.get_music_context(), Sfx.MUSIC_FEAST)
	Audio.release_music(Sfx.MUSIC_FEAST, hero_a)
	assert_eq(Audio.get_music_context(), Sfx.MUSIC_FEAST, "the feast plays while any hero feasts")
	Audio.push_music(Sfx.MUSIC_BOSS_TUSKER)
	assert_eq(Audio.get_music_context(), Sfx.MUSIC_BOSS_TUSKER)
	Audio.release_music(Sfx.MUSIC_FEAST, hero_b)
	assert_eq(Audio.get_music_context(), Sfx.MUSIC_BOSS_TUSKER, "the boss music stays")
	assert_false(Audio.is_music_held_by(Sfx.MUSIC_FEAST, hero_b))
	Audio.pop_music(0.0)
	assert_eq(Audio.get_music_context(), Sfx.MUSIC_CANYON, "after the boss the level music comes back, not the feast")
	Audio.pop_music(0.0)
	assert_eq(Audio.get_music_context(), Sfx.MUSIC_CANYON, "nothing left on the stack")


func test_a_feast_released_on_top_returns_to_the_level() -> void:
	var hero: RefCounted = RefCounted.new()
	Audio.play_music(Sfx.MUSIC_VERSUS_BATTLE_A, 0.0)
	Audio.hold_music(Sfx.MUSIC_FEAST, hero)
	Audio.hold_music(Sfx.MUSIC_FEAST, hero)
	Audio.release_music(Sfx.MUSIC_FEAST, hero)
	assert_eq(Audio.get_music_context(), Sfx.MUSIC_VERSUS_BATTLE_A, "holding twice is holding once")
	Audio.release_music(Sfx.MUSIC_FEAST, hero)
	assert_eq(Audio.get_music_context(), Sfx.MUSIC_VERSUS_BATTLE_A, "a second release does nothing")
