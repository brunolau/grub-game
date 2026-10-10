extends TestCase
## The high score on the cards of the book select (the 2.0 release round's ruling F4, found by the release verifier):
## a player who comes back from 1.0.0 read "HI 0000000" on the Book I card while the title showed his "HI 3069500".
## 1.0.0 kept one record without its difficulty, and the migration keeps it as the profile record only - no table of a
## namespace gets it - so the card, which reads the tables, showed nothing. The card of Solo, Book I now shows that
## record too (BookSelectScreen.legacy_score). The profiles are the real ones of tests/data/saves_1_0 (what the 1.0.0
## release wrote); nothing is saved here.

const DIR: String = "res://tests/data/saves_1_0/"
const WITH_SAVE: PackedStringArray = ["expert_start", "mid_beginner", "mid_expert", "finished"]
const USER_FILES: PackedStringArray = ["save.json", "save.json.bak", "save.json.tmp", "settings.cfg"]


func before_each() -> void:
	_clear_user_folder()
	Save.load_game()
	Settings.reset()
	Flow.play_mode = Defs.GameMode.SINGLE
	Flow.play_book = 1


func after_each() -> void:
	_clear_user_folder()
	Save.load_game()
	Settings.reset()
	Flow.play_mode = Defs.GameMode.SINGLE
	Flow.play_book = 1
	Flow.args = {}


func _clear_user_folder() -> void:
	var dir: DirAccess = DirAccess.open(Save.storage_dir)
	if dir == null:
		return
	for file: String in dir.get_files():
		if USER_FILES.has(file) or file.begins_with("save.v"):
			dir.remove(file)


## Put a 1.0 profile into the user folder of this test run, exactly as its files are, and load it.
func _load_profile(profile: String) -> void:
	_clear_user_folder()
	for file: String in USER_FILES:
		var source: String = DIR + profile + "/" + file
		if FileAccess.file_exists(source):
			var target: FileAccess = FileAccess.open(Save.storage_dir + file, FileAccess.WRITE)
			target.store_buffer(FileAccess.get_file_as_bytes(source))
			target.close()
	Save.load_game()


## The record 1.0.0 wrote into a profile's save.json.
func _record_of(profile: String) -> int:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DIR + profile + "/save.json"))
	return int(parsed["high_score"]) if parsed is Dictionary and parsed.has("high_score") else -1


func _open_book_select() -> BookSelectScreen:
	var scene: PackedScene = load(Flow.SCREEN_DIR + "book_select.tscn") as PackedScene
	var node: BookSelectScreen = scene.instantiate() as BookSelectScreen
	add_node(node)
	await get_tree().process_frame
	return node


func test_the_book_1_card_shows_the_high_score_a_1_0_player_brought() -> void:
	for profile: String in WITH_SAVE:
		_load_profile(profile)
		var record: int = _record_of(profile)
		# 1.0.0 wrote its record at a game over or at The End: only the profile that finished the game has one.
		assert_eq(record > 0, profile == "finished", "%s: the set-up - the high score 1.0.0 wrote (%d)" % [profile, record])
		assert_true(Save.was_migrated(), "%s: the set-up - a 1.0 profile that 2.0 took over" % profile)
		assert_eq(Save.get_high_score(), record, "%s: the profile record is the 1.0 score (the title's \"HI\")" % profile)
		for space_key: String in Save.get_spaces():
			assert_eq(Save.get_high_score_in(space_key), 0, "%s: the migration puts it into no table (%s)" % [profile, space_key])
		Flow.play_mode = Defs.GameMode.SINGLE
		assert_eq(BookSelectScreen.legacy_score(), record, "%s: the record of 1.0.0" % profile)
		assert_eq(BookSelectScreen.best_score(1), record, "%s: Solo, Book I shows it (it showed 0)" % profile)
		assert_eq(BookSelectScreen.best_score(2), 0, "%s: Book II did not exist in 1.0.0" % profile)
		Flow.play_mode = Defs.GameMode.COOP
		assert_eq(BookSelectScreen.best_score(1), 0, "%s: nor did Co-op" % profile)
		assert_eq(BookSelectScreen.best_score(2), 0)
		Flow.play_mode = Defs.GameMode.SINGLE
		print("    %s: 1.0.0 wrote %d, the Book I card of Solo reads %s" % [profile, record,
				UiKit.score_text(BookSelectScreen.best_score(1))])
	Flow.play_mode = Defs.GameMode.SINGLE


func test_the_cards_on_the_screen_read_the_same_as_the_title() -> void:
	_load_profile("finished")
	var record: int = _record_of("finished")
	var node: BookSelectScreen = await _open_book_select()
	assert_eq(node.get_card(1).get_foot_text(), "%s %s" % [tr("UI_HIGH_SCORE"), UiKit.score_text(record)],
			"the Book I card of the profile that finished 1.0.0")
	assert_eq(node.get_card(2).get_foot_text(), "%s %s" % [tr("UI_HIGH_SCORE"), UiKit.score_text(0)], "Book II: no score yet")
	assert_ne(UiKit.score_text(record), UiKit.score_text(0))
	node.queue_free()
	await get_tree().process_frame
	Flow.play_mode = Defs.GameMode.COOP
	node = await _open_book_select()
	assert_eq(node.get_card(1).get_foot_text(), "%s %s" % [tr("UI_HIGH_SCORE"), UiKit.score_text(0)],
			"Co-op, Book I: the 1.0 score was a solo score")
	node.queue_free()
	await get_tree().process_frame
	Flow.play_mode = Defs.GameMode.SINGLE


func test_scores_of_2_0_keep_their_own_tables_beside_the_1_0_record() -> void:
	_load_profile("finished")
	var record: int = _record_of("finished")
	# A lower Book I run of 2.0: the card keeps the best of Book I - the 1.0 record.
	Save.submit_score_in(Save.space(Defs.GameMode.SINGLE, 1, Defs.Difficulty.BEGINNER), 1000)
	assert_eq(BookSelectScreen.best_score(1), record, "a lower 2.0 run does not hide the 1.0 record")
	# Book II and Co-op runs below the record: their own tables, nothing of the 1.0 score on their cards.
	Save.submit_score_in(Save.space(Defs.GameMode.SINGLE, 2, Defs.Difficulty.EXPERT), 5000)
	Save.submit_score_in(Save.space(Defs.GameMode.COOP, 1, Defs.Difficulty.BEGINNER), 7000)
	assert_eq(BookSelectScreen.best_score(2), 5000)
	assert_eq(BookSelectScreen.best_score(1), record)
	Flow.play_mode = Defs.GameMode.COOP
	assert_eq(BookSelectScreen.best_score(1), 7000)
	Flow.play_mode = Defs.GameMode.SINGLE
	# A better Book I run of 2.0 takes the card.
	Save.submit_score_in(Save.space(Defs.GameMode.SINGLE, 1, Defs.Difficulty.EXPERT), record + 100)
	assert_eq(BookSelectScreen.best_score(1), record + 100)
	assert_eq(BookSelectScreen.legacy_score(), 0, "the profile record is a 2.0 score now")
	assert_eq(Save.get_high_score(), record + 100)


func test_a_profile_without_a_1_0_score_shows_its_tables_only() -> void:
	# A new player.
	assert_eq(Save.get_high_score(), 0)
	assert_eq(BookSelectScreen.legacy_score(), 0)
	assert_eq(BookSelectScreen.best_score(1), 0)
	# A 2.0 player whose best run was in Book II: the Book I card shows Book I's own best, not the profile record.
	Save.submit_score_in(Save.space(Defs.GameMode.SINGLE, 1, Defs.Difficulty.BEGINNER), 300)
	Save.submit_score_in(Save.space(Defs.GameMode.SINGLE, 2, Defs.Difficulty.BEGINNER), 900)
	assert_eq(Save.get_high_score(), 900)
	assert_eq(BookSelectScreen.legacy_score(), 0, "the record is Book II's table: no 1.0 score")
	assert_eq(BookSelectScreen.best_score(1), 300)
	assert_eq(BookSelectScreen.best_score(2), 900)
	# Co-op only.
	Save.load_game()
	Save.submit_score_in(Save.space(Defs.GameMode.COOP, 2, Defs.Difficulty.EXPERT), 4400)
	assert_eq(BookSelectScreen.best_score(1), 0, "a co-op record is no solo score")
