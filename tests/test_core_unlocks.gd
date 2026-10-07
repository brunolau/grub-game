extends TestCase
## The Cave Painting table (UnlockTable, docs/expansion/PLAN.md P2.6, DESIGN.md C.9, GAMEPLAY.md 13.2 / 13.7): where
## each painting hides, the reward ladder and what it opens, the "new reward" signal of Save, and VersusMatch's use of
## it (locked arenas, variants).

var _rewards: Array[StringName] = []


func before_each() -> void:
	Save.reset()
	Settings.reset()
	_rewards.clear()


func after_each() -> void:
	if Save.reward_unlocked.is_connected(_on_reward):
		Save.reward_unlocked.disconnect(_on_reward)
	Save.reset()
	Settings.reset()


func _on_reward(reward: StringName) -> void:
	_rewards.append(reward)


func _find(count: int) -> void:
	for index: int in count:
		Save.add_painting(index)


func test_the_ladder_matches_the_design_and_save() -> void:
	assert_eq(UnlockTable.REWARDS.size(), Save.UNLOCK_PAINTINGS.size(), "one entry per Save reward")
	var previous: int = 0
	for entry: Dictionary in UnlockTable.REWARDS:
		var id: StringName = entry["id"]
		assert_true(Save.UNLOCK_PAINTINGS.has(id), "%s is a Save reward" % id)
		assert_eq(int(entry["paintings"]), int(Save.UNLOCK_PAINTINGS.get(id, -1)), "%s: the same count as Save" % id)
		assert_true(int(entry["paintings"]) > previous, "the ladder climbs")
		previous = int(entry["paintings"])
		assert_true(str(entry["text"]).begins_with("UI_REWARD_"), "%s has a text key" % id)
	assert_eq(UnlockTable.paintings_needed(Save.UNLOCK_MESA_RODEO), 5, "DESIGN.md C.9: 5 = Mesa Rodeo")
	assert_eq(UnlockTable.paintings_needed(Save.UNLOCK_LOINCLOTHS), 10)
	assert_eq(UnlockTable.paintings_needed(Save.UNLOCK_VARIANTS), 15)
	assert_eq(UnlockTable.paintings_needed(Save.UNLOCK_CLOUD_TOP), 20)
	assert_eq(UnlockTable.paintings_needed(Save.UNLOCK_SPEAR_PARTY), 25)
	assert_eq(UnlockTable.paintings_needed(Save.UNLOCK_MURAL), 30)
	assert_eq(UnlockTable.paintings_needed(&"no_such_reward"), Tuning.PAINTING_COUNT + 1, "never by paintings")
	for arena: StringName in VersusMatch.LOCKED_ARENAS:
		assert_eq(UnlockTable.reward_of_arena(arena), VersusMatch.LOCKED_ARENAS[arena], "VersusMatch agrees: %s" % arena)
	assert_eq(UnlockTable.reward_of_variant(&"big_bounce"), Save.UNLOCK_VARIANTS)
	assert_eq(UnlockTable.reward_of_variant(&"lights_out"), Save.UNLOCK_VARIANTS)
	assert_eq(UnlockTable.reward_of_variant(&"giant_rain"), Save.UNLOCK_VARIANTS)
	assert_eq(UnlockTable.reward_of_variant(&"spear_party"), Save.UNLOCK_SPEAR_PARTY)
	assert_eq(UnlockTable.reward_of_variant(&"hammer_time"), &"", "open from the start")
	assert_eq(UnlockTable.reward_of_palette(&"gold"), Save.UNLOCK_SPEAR_PARTY, "the golden loincloth palette at 25")
	assert_eq(UnlockTable.reward_of_palette(&"blue"), &"")
	for variant: StringName in [&"big_bounce", &"lights_out", &"giant_rain", &"spear_party"]:
		assert_true(VersusMatch.VARIANT_NAMES.has(variant), "%s is a variant name" % variant)
	if ResourceLoader.exists("res://scripts/world/versus/rules.gd"):
		var rules: GDScript = load("res://scripts/world/versus/rules.gd") as GDScript
		var listed: Variant = rules.get_script_constant_map().get("VARIANTS") if rules != null else null
		if listed is Array:
			assert_eq(PackedStringArray(Array(VersusMatch.VARIANT_NAMES)), PackedStringArray(listed as Array),
					"the referee's variants are the match's names")


func test_every_painting_has_one_home() -> void:
	assert_eq(UnlockTable.PAINTING_LEVELS.size(), Tuning.PAINTING_COUNT)
	var book2: Array[StringName] = []
	for index: int in Tuning.PAINTING_COUNT:
		var level_id: StringName = UnlockTable.painting_level(index)
		assert_ne(level_id, &"", "painting %d hides somewhere" % index)
		if index < Tuning.PAINTING_BOOK2_COUNT:
			assert_false(UnlockTable.is_coop_only(index))
			assert_false(book2.has(level_id), "one painting per Book II level (%s)" % level_id)
			book2.append(level_id)
			assert_eq(UnlockTable.painting_file(index, Defs.GameMode.SINGLE), level_id, "solo finds %d" % index)
		else:
			assert_true(UnlockTable.is_coop_only(index), "%d is a Book I co-op secret" % index)
			assert_eq(UnlockTable.painting_file(index, Defs.GameMode.SINGLE), &"", "solo never finds %d" % index)
		assert_eq(UnlockTable.painting_file(index, Defs.GameMode.COOP), StringName(String(level_id) + "_coop"))
		assert_eq(UnlockTable.painting_file(index, Defs.GameMode.VERSUS), &"")
	assert_eq(UnlockTable.painting_level(0), &"w5_l1", "GAMEPLAY.md 13.2: painting 0 in 5-1")
	assert_eq(UnlockTable.painting_level(19), &"ending_b")
	assert_eq(UnlockTable.painting_level(20), &"w1_l1", "DESIGN.md D.9: #20 High Cache in 1-1 co-op")
	assert_eq(UnlockTable.painting_level(29), &"ending", "#29 the Way Home lookout")
	assert_eq(UnlockTable.painting_level(30), &"")
	assert_eq(UnlockTable.paintings_of(&"w5_l1"), PackedInt32Array([0]))
	assert_eq(UnlockTable.paintings_of(&"w5_l1_coop"), PackedInt32Array([0]), "the same index in the co-op twin")
	assert_eq(UnlockTable.paintings_of(&"w1_l1"), PackedInt32Array(), "Book I solo holds none")
	assert_eq(UnlockTable.paintings_of(&"w1_l1_coop"), PackedInt32Array([20]))
	assert_eq(UnlockTable.paintings_of(&"w2_l2b_coop"), PackedInt32Array(), "the co-op Brute's den holds none")


## Every painting a level file places sits where the table says (the designers' check; files without one pass).
func test_the_level_files_place_their_paintings_where_the_table_says() -> void:
	for level_id: StringName in Levels.all_ids():
		if String(level_id).begins_with("test_") or Levels.is_arena(level_id):
			continue
		var data: LevelData = LevelData.load_file(Levels.get_level_path(level_id))
		if data == null:
			continue
		for record: Dictionary in data.entity_records():
			if record["id"] != &"items/painting":
				continue
			var index: int = int((record["params"] as Dictionary).get("index", -1))
			assert_true(UnlockTable.paintings_of(level_id).has(index),
					"%s places painting %d, the table puts it in %s" % [level_id, index, UnlockTable.painting_level(index)])


func test_paintings_open_the_rewards_and_announce_them() -> void:
	Save.reward_unlocked.connect(_on_reward)
	assert_false(UnlockTable.is_arena_open(&"arena_mesa_rodeo"), "a fresh profile: Mesa Rodeo is locked")
	assert_true(UnlockTable.is_arena_open(&"arena_totem_ring"), "a launch arena is open")
	assert_false(UnlockTable.is_variant_open(&"big_bounce"))
	assert_true(UnlockTable.is_variant_open(&"gusty"))
	assert_true(UnlockTable.is_pattern_open("default"))
	assert_false(UnlockTable.is_pattern_open("paintings_10"))
	assert_false(UnlockTable.is_pattern_open("no_such_tag"))
	assert_false(UnlockTable.is_palette_open(&"gold"))
	assert_true(UnlockTable.is_palette_open(&"pink"))
	assert_eq(UnlockTable.next_reward(), {"id": Save.UNLOCK_MESA_RODEO, "missing": 5})
	_find(4)
	assert_eq(_rewards, [] as Array[StringName], "four paintings open nothing")
	assert_eq(UnlockTable.next_reward()["missing"], 1)
	Save.add_painting(4)
	assert_eq(_rewards, [Save.UNLOCK_MESA_RODEO] as Array[StringName], "the fifth painting opens Mesa Rodeo")
	assert_true(UnlockTable.is_arena_open(&"arena_mesa_rodeo"))
	Save.add_painting(4)
	assert_eq(_rewards.size(), 1, "a painting found again announces nothing")
	_find(10)
	assert_eq(_rewards, [Save.UNLOCK_MESA_RODEO, Save.UNLOCK_LOINCLOTHS] as Array[StringName])
	assert_true(UnlockTable.is_pattern_open("paintings_10"), "the eight patterns")
	Save.unlock(Save.UNLOCK_VARIANTS)
	_find(15)
	assert_eq(_rewards.size(), 2, "a reward opened by hand is not announced again")
	Save.set_unlock_everything(true)
	_find(25)
	assert_eq(_rewards.size(), 2, "Unlock everything had opened Cloud Top and Spear Party already")
	assert_true(UnlockTable.is_palette_open(&"gold"))
	assert_false(UnlockTable.is_mural_open(), "the mural is the campaign's: Unlock everything never opens it")
	_find(30)
	assert_eq(_rewards.back(), Save.UNLOCK_MURAL, "the thirtieth painting: the mural")
	assert_true(UnlockTable.is_mural_open())
	assert_eq(UnlockTable.next_reward(), {})
	assert_eq(UnlockTable.open_rewards().size(), UnlockTable.REWARDS.size())
	assert_eq(UnlockTable.rewards_between(4, 15), [Save.UNLOCK_MESA_RODEO, Save.UNLOCK_LOINCLOTHS, Save.UNLOCK_VARIANTS]
			as Array[StringName])


## The loincloth patterns of hero_palettes.json (player-A's data) use only tags this table knows.
func test_the_pattern_tags_of_the_hero_palettes_are_known() -> void:
	var path: String = "res://assets/sprites/player/palettes/hero_palettes.json"
	if not FileAccess.file_exists(path):
		assert_true(true, "no palette file in this tree")
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert_true(data is Dictionary)
	if not data is Dictionary:
		return
	var locked: int = 0
	for pattern: Variant in (data as Dictionary).get("patterns", []):
		var tag: String = str((pattern as Dictionary).get("unlock", UnlockTable.PATTERN_DEFAULT))
		assert_true(tag == UnlockTable.PATTERN_DEFAULT or UnlockTable.reward_of_pattern(tag) != &"",
				"pattern tag %s has a reward" % tag)
		if tag != UnlockTable.PATTERN_DEFAULT:
			locked += 1
	assert_eq(locked, 8, "DESIGN.md C.9: eight loincloth patterns open with 10 paintings")
	var palettes: Variant = (data as Dictionary).get("palettes", {})
	assert_true(palettes is Dictionary and (palettes as Dictionary).has("gold"), "the golden palette exists")


func test_the_versus_match_offers_only_open_content() -> void:
	var choices: Array[Dictionary] = VersusMatch.variant_choices()
	assert_eq(choices.size(), VersusMatch.VARIANT_NAMES.size())
	for choice: Dictionary in choices:
		var closed: bool = [&"big_bounce", &"lights_out", &"giant_rain", &"spear_party"].has(choice["name"])
		assert_eq(bool(choice["open"]), not closed, "%s open from the start: %s" % [choice["name"], not closed])
		assert_eq(int(choice["paintings"]), 0 if not closed else (15 if choice["name"] != &"spear_party" else 25))
	assert_eq(VersusMatch.arena_paintings_needed(&"arena_cloud_top"), 20, "the arena screen's count")
	assert_eq(VersusMatch.arena_paintings_needed(&"arena_totem_ring"), 0)
	var versus_match: VersusMatch = VersusMatch.new()
	versus_match.variants = PackedStringArray(["gusty", "big_bounce", "lasers", "gusty"])
	versus_match.begin_match(3)
	assert_eq(versus_match.variants, PackedStringArray(["gusty"]), "closed, unknown and repeated variants go")
	_find(16)
	assert_eq(VersusMatch.arena_paintings_needed(&"arena_cloud_top"), 4)
	versus_match.variants = PackedStringArray(["big_bounce"])
	versus_match.begin_match(3)
	assert_eq(versus_match.variants, PackedStringArray(["big_bounce"]), "open with 15 paintings")
