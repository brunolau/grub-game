extends TestCase
## AudioTable batch 1 (docs/expansion/PLAN.md P1.1): every 2.0 effect and music name of Sfx has a row that plays - a
## stand-in 1.0 file marked "temp" until the audio owner's file is imported - and the feast music shared by a party
## (Audio.hold_music) leaves the music stack cleanly.

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
	Audio.stop_music(0.0)
	Audio.stop_all_sfx()


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
	assert_eq(Sfx.EXPANSION_SFX.size() + Sfx.EXPANSION_MUSIC.size(), 63, "the 2.0 names of Sfx")


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
