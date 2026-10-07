extends TestCase
## Flow 2.0 (docs/expansion/PLAN.md P1.1, GAMEPLAY.md 13.1 / 13.9.1 / 13.10.1): Solo / Co-op / Versus, the books, the
## mode-aware campaign (co-op files, save namespaces), joining and leaving (mid-stage at the checkpoint), the pad
## reconnect pause and the versus round loop. Book II and co-op metas are added in memory; the registry is rescanned
## after each test.

const B2_A: StringName = &"zz_b2_a"
const B2_A_COOP: StringName = &"zz_b2_a_coop"
const B2_B: StringName = &"zz_b2_b"
const B2_B_COOP: StringName = &"zz_b2_b_coop"
const B2_BONUS: StringName = &"zz_b2_bonus"
const B2_BONUS_COOP: StringName = &"zz_b2_bonus_coop"
const ARENA: StringName = &"zz_arena"
const PARTY_LEVEL: StringName = &"test_core_party"
# A Book II campaign with a warp out of a linked pair (5-2 -> Feast Land D, 5-2b after it), an Expert-only stop and
# the ending (PLAN.md P2.6: Book II campaign plumbing).
const W_A: StringName = &"zz_w_a"
const W_A_BOSS: StringName = &"zz_w_a_boss"
const W_BONUS: StringName = &"zz_w_bonus"
const W_B: StringName = &"zz_w_b"
const W_C: StringName = &"zz_w_c"
const W_END: StringName = &"zz_w_end"
# A book's last stop as Book I's 4-2 / 4-2b / Way Home and Book II's 9-3 / The Long Raft Home are wired: a main half
# (`tally = false`) -> the final boss (its trophy) -> the ending, each with a co-op file (the co-op endings, P2.6).
const F_MAIN: StringName = &"zz_f_main"
const F_BOSS: StringName = &"zz_f_boss"
const F_END: StringName = &"zz_f_end"

var _metas_added: bool = false
var _signals: Array = []
var _connections: Array = []


func before_each() -> void:
	Sim.manual = true
	Save.reset()
	Settings.reset()
	GameInput.reset_slots()
	GameInput.clear_scripted()
	Game.new_game(Defs.Difficulty.BEGINNER)
	Game.versus_match = null
	Flow.play_mode = Defs.GameMode.SINGLE
	Flow.play_book = 1
	_signals.clear()


## Synchronous on purpose: the runner does not await after_each (a test that changed scenes ends with _finish()).
func after_each() -> void:
	for pair: Array in _connections:
		var source: Signal = pair[0]
		if source.is_connected(pair[1]):
			source.disconnect(pair[1])
	_connections.clear()
	Sim.stop()
	get_tree().paused = false
	VersusMatch.bot_factory = Callable()
	GameInput.set_menu_clusters(false)
	GameInput.reset_slots()
	GameInput.clear_scripted()
	Game.versus_match = null
	Game.new_game(Defs.Difficulty.BEGINNER)
	for run: PlayerRun in Game.runs:
		run.palette = &""
		run.pattern = -1
	Flow.play_mode = Defs.GameMode.SINGLE
	Flow.play_book = 1
	Flow._lost_pads.clear()
	if _metas_added:
		_metas_added = false
		Levels.rescan()
	Settings.reset()
	Sim.manual = false


## The end of every test that changed scenes: the transition finishes, the scene goes, the next test starts clean.
func _finish() -> void:
	if Flow.busy:
		await Flow.transition_finished
	Sim.stop()
	get_tree().paused = false
	if get_tree().current_scene != null:
		get_tree().current_scene.queue_free()
		get_tree().current_scene = null
	Flow.current_screen = Flow.SCREEN_BOOT
	Flow.args = {}
	await get_tree().process_frame


## A two-stop Book II campaign with co-op files, a bonus stage with its co-op file and an arena, all in memory (the
## arena and the co-op files load the party test level when started).
func _add_book_two() -> void:
	_metas_added = true
	var meta: Dictionary = Levels._meta
	meta[B2_A] = {"id": String(B2_A), "kind": "main", "order": 9100, "book": 2}
	meta[B2_B] = {"id": String(B2_B), "kind": "main", "order": 9110, "book": 2}
	meta[B2_A_COOP] = {"id": String(B2_A_COOP), "kind": "coop", "coop_of": String(B2_A), "book": 2}
	meta[B2_B_COOP] = {"id": String(B2_B_COOP), "kind": "coop", "coop_of": String(B2_B), "book": 2}
	meta[B2_BONUS] = {"id": String(B2_BONUS), "kind": "bonus", "book": 2}
	meta[B2_BONUS_COOP] = {"id": String(B2_BONUS_COOP), "kind": "coop", "coop_of": String(B2_BONUS), "book": 2}
	meta[ARENA] = {"id": String(ARENA), "kind": "arena", "players": 4, "modes": "grub_stack,hot_rock"}
	for id: StringName in [B2_A, B2_B, B2_A_COOP, B2_B_COOP, B2_BONUS, B2_BONUS_COOP, ARENA]:
		Levels._paths[id] = Levels.get_level_path(PARTY_LEVEL)
	Levels._index_campaign()


## A Book II campaign in memory: W_A (main, `tally = false`, `bonus = W_BONUS`, `next = W_A_BOSS`) -> W_B (main) ->
## W_C (main, Expert only) and the ending W_END, with co-op files for W_A, W_BONUS and W_B.
func _add_warp_book() -> void:
	_metas_added = true
	var meta: Dictionary = Levels._meta
	meta[W_A] = {"id": String(W_A), "kind": "main", "order": 9200, "book": 2, "tally": false,
			"bonus": String(W_BONUS), "next": String(W_A_BOSS), "password_beginner": "ZQW1"}
	meta[W_A_BOSS] = {"id": String(W_A_BOSS), "kind": "sub", "book": 2}
	meta[W_BONUS] = {"id": String(W_BONUS), "kind": "bonus", "book": 2}
	meta[W_B] = {"id": String(W_B), "kind": "main", "order": 9210, "book": 2, "password_beginner": "ZQW2",
			"password_expert": "ZQW3"}
	meta[W_C] = {"id": String(W_C), "kind": "main", "order": 9220, "book": 2, "min_difficulty": "expert"}
	meta[W_END] = {"id": String(W_END), "kind": "ending", "book": 2, "min_difficulty": "expert"}
	for id: StringName in [W_A, W_BONUS, W_B]:
		var coop: StringName = StringName(String(id) + "_coop")
		meta[coop] = {"id": String(coop), "kind": "coop", "coop_of": String(id), "book": 2}
		Levels._paths[coop] = Levels.get_level_path(PARTY_LEVEL)
	for id: StringName in [W_A, W_A_BOSS, W_BONUS, W_B, W_C, W_END]:
		Levels._paths[id] = Levels.get_level_path(PARTY_LEVEL)
	Levels._index_campaign()


## The last stop of book `book` in memory (see F_MAIN): F_MAIN -> F_BOSS (trophy) -> F_END, Expert only, with co-op
## files for each (F_END's only with `coop_ending`).
func _add_final_stop(book: int, coop_ending: bool) -> void:
	_metas_added = true
	var meta: Dictionary = Levels._meta
	meta[F_MAIN] = {"id": String(F_MAIN), "kind": "main", "order": 9300 + book, "book": book, "tally": false,
			"next": String(F_BOSS), "min_difficulty": "expert"}
	meta[F_BOSS] = {"id": String(F_BOSS), "kind": "sub", "book": book, "next": String(F_END),
			"min_difficulty": "expert"}
	meta[F_END] = {"id": String(F_END), "kind": "ending", "book": book, "min_difficulty": "expert"}
	var with_coop: Array[StringName] = [F_MAIN, F_BOSS]
	if coop_ending:
		with_coop.append(F_END)
	for id: StringName in with_coop:
		var coop: StringName = StringName(String(id) + "_coop")
		meta[coop] = {"id": String(coop), "kind": "coop", "coop_of": String(id), "book": book}
		Levels._paths[coop] = Levels.get_level_path(PARTY_LEVEL)
	for id: StringName in [F_MAIN, F_BOSS, F_END]:
		Levels._paths[id] = Levels.get_level_path(PARTY_LEVEL)
	Levels._index_campaign()


## Record every emission of `source` in _signals as [signal_name, value]; disconnected after the test.
func _listen(source: Signal, signal_name: String) -> void:
	var recorder: Callable = func(value: Variant = null) -> void: _signals.append([signal_name, value])
	source.connect(recorder)
	_connections.append([source, recorder])


# =================================================================================================================
# Modes, books, save namespaces
# =================================================================================================================

func test_the_file_to_play_and_the_save_namespace_follow_the_mode() -> void:
	_add_book_two()
	assert_eq(Flow.level_to_play(B2_A), B2_A, "single-player plays the solo file")
	assert_eq(Flow.save_space(), "single/book1/beginner", "the 1.0 game's namespace")
	Game.start_run(Defs.Difficulty.EXPERT, Defs.GameMode.COOP, 2, 2)
	assert_eq(Flow.level_to_play(B2_A), B2_A_COOP, "co-op plays the stop's co-op file")
	assert_eq(Flow.level_to_play(B2_A_COOP), B2_A_COOP)
	assert_eq(Flow.level_to_play(&"test_example"), &"test_example", "no co-op file: the solo file with the party")
	assert_eq(Flow.save_space(), "coop/book2/expert")
	Game.start_run(Defs.Difficulty.BEGINNER, Defs.GameMode.VERSUS, 2, 1)
	assert_eq(Flow.level_to_play(ARENA), ARENA)
	assert_eq(Flow.save_space(), "single/book1/beginner", "versus keeps no campaign progress")
	assert_eq(Flow._campaign_kind(B2_BONUS_COOP), Levels.KIND_BONUS, "a co-op file has its solo level's kind")
	assert_eq(Flow._campaign_kind(B2_A), Levels.KIND_MAIN)
	assert_eq(Flow._map_stop(B2_B_COOP), B2_B)


func test_a_coop_tally_records_at_the_solo_stop_in_the_coop_save() -> void:
	_add_book_two()
	Game.start_run(Defs.Difficulty.EXPERT, Defs.GameMode.COOP, 2, 2)
	Game.begin_level(B2_A_COOP)
	Game.add_score(2500)
	Game.runs[1].set_weapon(Defs.Weapon.AXE)
	Game.runs[1].set_belt(Defs.Weapon.CLUB)
	Flow.finish_tally()
	var space_key: String = "coop/book2/expert"
	assert_eq(int(Save.get_level_result_in(space_key, B2_A)["score"]), 2500, "the result of the solo map stop")
	assert_eq(int(Save.get_level_result_in(space_key, B2_A_COOP)["clears"]), 0, "never under the co-op file's id")
	assert_eq(int(Save.get_level_result(B2_A, Defs.Difficulty.EXPERT)["clears"]), 0, "the solo save is untouched")
	assert_true(Save.is_level_unlocked_in(space_key, B2_B), "the next stop is unlocked in the co-op save")
	assert_false(Save.is_level_unlocked_in(space_key, B2_B_COOP))
	assert_eq(Save.get_belt_in(space_key, 1), {"hand": Defs.Weapon.AXE, "belt": Defs.Weapon.CLUB}, "P2's weapons kept")
	assert_eq(Flow.args.get("level_id"), B2_B, "the map shows the next solo stop")
	assert_eq(Flow.args.get("book"), 2)
	assert_eq(Flow.args.get("mode"), Defs.GameMode.COOP)
	await _finish()


func test_a_coop_bonus_stage_entered_without_its_warp_ends_at_the_title() -> void:
	_add_book_two()
	Game.start_run(Defs.Difficulty.BEGINNER, Defs.GameMode.COOP, 2, 2)
	Game.begin_level(B2_BONUS_COOP)
	Game.add_score(100)
	Flow.finish_tally()
	if Flow.busy:
		await Flow.transition_finished
	assert_eq(Flow.current_screen, Flow.SCREEN_TITLE, "the solo level's kind decides: a bonus stage")
	assert_eq(Save.get_high_score_in("coop/book2/beginner"), 100, "the co-op high-score table")
	assert_eq(Save.get_high_score(), 100, "and the profile record")
	assert_false(GameInput.is_party_input(), "the title gives every device back to P1")
	await _finish()


func test_a_book_two_solo_run_and_its_codes() -> void:
	_add_book_two()
	Flow.start_book_game(Defs.Difficulty.BEGINNER, 2)
	assert_eq(Game.book, 2)
	assert_eq(Game.mode, Defs.GameMode.SINGLE)
	assert_eq(Game.party, 1)
	assert_eq(Flow.args.get("level_id"), Levels.first_level(2), "the first stop of Book II")
	if Flow.busy:
		await Flow.transition_finished
	Flow.continue_game(B2_B, Defs.Difficulty.EXPERT)
	assert_eq(Game.book, 2, "a Book II code starts a Book II run")
	assert_eq(Game.weapon, Defs.Weapon.CLUB)
	assert_eq(Game.runs[0].belt, PlayerRun.BELT_EMPTY, "with the club and an empty belt (C.1 rule 4)")
	assert_true(Save.is_level_unlocked_in("single/book2/expert", B2_B))
	assert_false(Save.is_level_unlocked(B2_B, Defs.Difficulty.EXPERT), "not in Book I's save")
	if Flow.busy:
		await Flow.transition_finished
	Flow.start_book_game(Defs.Difficulty.EXPERT, 1)
	assert_eq(Game.book, 1, "Book I is the 1.0 game")
	assert_eq(Flow.args.get("level_id"), Levels.first_level())
	await _finish()


func test_a_coop_run_starts_with_two_inputs() -> void:
	_add_book_two()
	Flow.start_coop_game(Defs.Difficulty.BEGINNER, 2, 2)
	assert_eq(Game.mode, Defs.GameMode.COOP)
	assert_eq(Game.party, 2)
	assert_eq(Game.book, 2)
	assert_eq(GameInput.get_slot(0).kind, Defs.InputSlotKind.KEYBOARD_LEFT, "nobody joined: P1 on the left half")
	assert_eq(GameInput.get_slot(1).kind, Defs.InputSlotKind.KEYBOARD_RIGHT, "... P2 on the right half")
	assert_eq(GameInput.get_slot(2).kind, Defs.InputSlotKind.NONE)
	var campaign: Array[StringName] = Levels.get_coop_campaign(Defs.Difficulty.BEGINNER, 2)
	assert_eq(Flow.args.get("level_id"), Levels.get_coop_base(campaign[0]), "the map stop of the first co-op file")
	if Flow.busy:
		await Flow.transition_finished
	GameInput.assign_slot(1, InputSlot.pad(5))
	Flow.start_coop_game(Defs.Difficulty.EXPERT, 2, 2, B2_B_COOP)
	assert_eq(GameInput.get_slot(1).device_id, 5, "a joined input is kept")
	assert_eq(Flow.args.get("level_id"), B2_B, "the level select of the co-op save")
	assert_true(Save.is_level_unlocked_in("coop/book2/expert", B2_B))
	if Flow.busy:
		await Flow.transition_finished
	Flow.goto_title()
	if Flow.busy:
		await Flow.transition_finished
	assert_eq(GameInput.get_slot(0).kind, Defs.InputSlotKind.ALL_DEVICES, "the title is single-player again")
	assert_eq(GameInput.get_slot(1).kind, Defs.InputSlotKind.NONE)
	assert_eq(Flow.play_mode, Defs.GameMode.SINGLE)
	await _finish()


func test_the_front_end_path_through_the_books() -> void:
	_add_book_two()
	Flow.open_play(Defs.GameMode.SINGLE)
	if Flow.busy:
		await Flow.transition_finished
	var expected: StringName = Flow.SCREEN_BOOK_SELECT if Flow.has_screen(Flow.SCREEN_BOOK_SELECT) \
			else Flow.SCREEN_MODE_SELECT
	assert_eq(Flow.current_screen, expected, "Solo opens the book select")
	Flow.choose_book(2)
	if Flow.busy:
		await Flow.transition_finished
	assert_eq(Flow.play_book, 2)
	assert_eq(Flow.current_screen, Flow.SCREEN_MODE_SELECT, "then Beginner / Expert")
	Flow.start_selected_game(Defs.Difficulty.EXPERT)
	assert_eq(Game.book, 2)
	assert_eq(Game.difficulty, Defs.Difficulty.EXPERT)
	assert_eq(Game.mode, Defs.GameMode.SINGLE)
	if Flow.busy:
		await Flow.transition_finished
	Flow.open_play(Defs.GameMode.COOP)
	if Flow.busy:
		await Flow.transition_finished
	assert_eq(Flow.play_mode, Defs.GameMode.COOP)
	if Flow.has_screen(Flow.SCREEN_JOIN):
		assert_eq(Flow.current_screen, Flow.SCREEN_JOIN, "Co-op opens the join panel first")
		assert_eq(Flow.party_size(), 0, "nobody joined yet")
		Flow.join_player(InputSlot.keyboard(Defs.InputSlotKind.KEYBOARD_LEFT))
		Flow.join_player(InputSlot.pad(2))
		assert_true(Flow.finish_join())
		if Flow.busy:
			await Flow.transition_finished
	assert_eq(Flow.party_size(), 2)
	Flow.choose_book(2)
	if Flow.busy:
		await Flow.transition_finished
	Flow.start_selected_game(Defs.Difficulty.BEGINNER)
	assert_eq(Game.mode, Defs.GameMode.COOP)
	assert_eq(Game.party, 2)
	assert_eq(Game.book, 2)
	await _finish()


## GAMEPLAY.md 1.1 / 13.1: "a warp item inside a bonus stage: tally, then the level after the source level (so warping
## from 3a skips 3b)" - Book II's 5-2 has both a warp and a linked boss stage.
func test_a_warp_ends_its_stop_and_passes_over_its_linked_sub_stage() -> void:
	_add_warp_book()
	assert_eq(Levels.next_level(W_A, Defs.Difficulty.BEGINNER), W_A_BOSS, "the exit of 5-2 leads to its boss")
	assert_eq(Flow.stop_after_warp(W_A, Defs.Difficulty.BEGINNER), W_B, "a warp out of 5-2 passes 5-2b over")
	assert_eq(Flow.stop_after_warp(W_B, Defs.Difficulty.BEGINNER), &"", "Beginner: no stop after it")
	assert_eq(Flow.stop_after_warp(W_B, Defs.Difficulty.EXPERT), W_C)
	for book_one: StringName in [&"w1_l2", &"w2_l1", &"w3_l2"]:
		for difficulty: int in [Defs.Difficulty.BEGINNER, Defs.Difficulty.EXPERT]:
			assert_eq(Flow.stop_after_warp(book_one, difficulty), Levels.next_level(book_one, difficulty),
					"Book I warps continue exactly as in 1.0 (%s)" % book_one)
	Game.start_run(Defs.Difficulty.BEGINNER, Defs.GameMode.SINGLE, 1, 2)
	Game.begin_level(W_BONUS, true)
	Game.warp_return_level = W_A
	Game.add_score(4100)
	Flow.finish_tally()
	var space_key: String = "single/book2/beginner"
	assert_eq(int(Save.get_level_result_in(space_key, W_A)["score"]), 4100, "the warp ended the stop of 5-2")
	assert_eq(int(Save.get_level_result_in(space_key, W_A_BOSS)["clears"]), 0)
	assert_true(Save.is_level_unlocked_in(space_key, W_B))
	assert_false(Save.is_level_unlocked_in(space_key, W_A_BOSS), "a sub-stage is never a map stop")
	assert_eq(Flow.args.get("level_id"), W_B, "the map shows the stop after it")
	if Flow.busy:
		await Flow.transition_finished
	Game.start_run(Defs.Difficulty.BEGINNER, Defs.GameMode.COOP, 2, 2)
	Game.begin_level(StringName(String(W_BONUS) + "_coop"), true)
	Game.warp_return_level = StringName(String(W_A) + "_coop")
	Flow.finish_tally()
	assert_eq(Flow.args.get("level_id"), W_B, "co-op: the same stop")
	assert_true(Save.is_level_unlocked_in("coop/book2/beginner", W_B))
	assert_eq(Flow.stop_after_warp(StringName(String(W_A) + "_coop"), Defs.Difficulty.BEGINNER),
			StringName(String(W_B) + "_coop"), "a co-op file continues with the co-op file of the next stop")
	await _finish()


func test_book_two_ends_at_the_expert_wall_or_with_the_end() -> void:
	_add_warp_book()
	Game.start_run(Defs.Difficulty.BEGINNER, Defs.GameMode.SINGLE, 1, 2)
	Game.begin_level(W_B)
	Flow.finish_tally()
	if Flow.busy:
		await Flow.transition_finished
	assert_eq(Flow.current_screen, Flow.SCREEN_EXPERT_WALL, "Beginner: the expert wall after the last Beginner stop")
	assert_eq(Flow.args, {"book": 2, "mode": Defs.GameMode.SINGLE}, "the wall knows its book (the Roc picture)")
	assert_false(Save.is_game_completed_in("single/book2/beginner"))
	Game.start_run(Defs.Difficulty.EXPERT, Defs.GameMode.SINGLE, 1, 2)
	Game.begin_level(W_END)
	Flow.finish_tally()
	if Flow.busy:
		await Flow.transition_finished
	assert_eq(Flow.current_screen, Flow.SCREEN_THE_END)
	assert_eq(Flow.args, {"book": 2, "mode": Defs.GameMode.SINGLE, "mural": false}, "not every painting found")
	assert_true(Save.is_game_completed_in("single/book2/expert"))
	assert_false(Save.is_game_completed(Defs.Difficulty.EXPERT), "Book I is not finished by it")
	for index: int in Tuning.PAINTING_COUNT:
		Save.add_painting(index)
	assert_true(Flow.ending_args()["mural"], "all 30 paintings: the cave mural ends The Long Raft Home")
	Game.start_run(Defs.Difficulty.EXPERT, Defs.GameMode.COOP, 2, 2)
	Game.begin_level(StringName(String(W_B) + "_coop"))
	Flow.finish_tally()
	if Flow.busy:
		await Flow.transition_finished
	assert_eq(Flow.current_screen, Flow.SCREEN_THE_END, "co-op: a stop without a co-op file is passed over, the book ends")
	assert_eq(Flow.args, {"book": 2, "mode": Defs.GameMode.COOP, "mural": true}, "every painting was found by now")
	assert_true(Save.is_game_completed_in("coop/book2/expert"))
	Game.start_run(Defs.Difficulty.EXPERT, Defs.GameMode.COOP, 2, 1)
	assert_eq(Flow.ending_args(), {"book": 1, "mode": Defs.GameMode.COOP, "mural": false},
			"THE END of Book I has no mural")
	await _finish()


## The co-op endings of both books (PLAN.md P2.6): the final boss's trophy in its co-op file leads to the co-op file of
## the ending (no tally between, the stop's result recorded in the co-op namespace), whose tally ends the book with THE
## END in co-op - the co-op namespace completed, the solo one untouched. A book whose ending has no co-op file yet ends
## at the boss's tally.
func test_the_coop_endings_of_both_books() -> void:
	for book: int in [1, 2]:
		Levels.rescan()
		_add_final_stop(book, true)
		var boss_coop: StringName = StringName(String(F_BOSS) + "_coop")
		var end_coop: StringName = StringName(String(F_END) + "_coop")
		var coop_space: String = "coop/book%d/expert" % book
		assert_eq(Levels.next_level(boss_coop, Defs.Difficulty.EXPERT), end_coop, "the trophy's co-op epilogue")
		Game.start_run(Defs.Difficulty.EXPERT, Defs.GameMode.COOP, 2, book)
		Game.begin_level(boss_coop, true)
		Game.add_score(7000)
		Flow.complete_level(&"trophy")
		if Flow.busy:
			await Flow.transition_finished
		assert_eq(Game.level_id, end_coop, "book %d: the boss's trophy starts the co-op epilogue" % book)
		assert_eq(int(Save.get_level_result_in(coop_space, F_MAIN)["score"]), 7000, "the stop's result, co-op space")
		assert_eq(int(Save.get_level_result_in("single/book%d/expert" % book, F_MAIN)["clears"]), 0)
		Flow.finish_tally()
		if Flow.busy:
			await Flow.transition_finished
		assert_eq(Flow.current_screen, Flow.SCREEN_THE_END, "book %d: the co-op epilogue ends with THE END" % book)
		assert_eq(Flow.args, {"book": book, "mode": Defs.GameMode.COOP, "mural": false})
		assert_true(Save.is_game_completed_in(coop_space))
		assert_false(Save.is_game_completed_in("single/book%d/expert" % book), "the solo book is not finished by it")
		await _finish()
	Levels.rescan()
	_add_final_stop(2, false)
	Save.reset()
	Game.start_run(Defs.Difficulty.EXPERT, Defs.GameMode.COOP, 2, 2)
	Game.begin_level(StringName(String(F_BOSS) + "_coop"), true)
	Flow.complete_level(&"trophy")
	if Flow.busy:
		await Flow.transition_finished
	if Flow.current_screen == Flow.SCREEN_TALLY:
		Flow.finish_tally()
		if Flow.busy:
			await Flow.transition_finished
	assert_eq(Flow.current_screen, Flow.SCREEN_THE_END, "no co-op epilogue yet: the boss's tally ends the book")
	assert_true(Save.is_game_completed_in("coop/book2/expert"))
	await _finish()


func test_the_level_select_of_a_book_with_its_codes() -> void:
	_add_warp_book()
	var stops: Array[Dictionary] = Flow.level_select(Defs.GameMode.SINGLE, 2, Defs.Difficulty.BEGINNER)
	var ids: Array = stops.map(func(entry: Dictionary) -> StringName: return entry["level_id"])
	assert_true(ids.has(W_A) and ids.has(W_B), "the map stops of Book II")
	assert_false(ids.has(W_C), "an Expert-only stop is not on the Beginner list")
	assert_false(ids.has(W_A_BOSS), "nor a sub-stage")
	var by_id: Dictionary = {}
	for entry: Dictionary in stops:
		by_id[entry["level_id"]] = entry
	assert_eq(by_id[W_A]["code"], "ZQW1")
	assert_eq(Levels.find_by_password("zqw2"), {"level_id": W_B, "difficulty": Defs.Difficulty.BEGINNER},
			"a Book II code is found like a Book I one")
	assert_true(bool(stops[0]["unlocked"]), "the first stop is always open")
	assert_false(bool(by_id[W_B]["unlocked"]))
	Save.unlock_level_in("single/book2/beginner", W_B)
	Save.record_level_result_in("single/book2/beginner", W_B, 900, 40)
	stops = Flow.level_select(Defs.GameMode.SINGLE, 2, Defs.Difficulty.BEGINNER)
	for entry: Dictionary in stops:
		if entry["level_id"] == W_B:
			assert_true(bool(entry["unlocked"]))
			assert_eq(int(entry["result"]["score"]), 900)
	var expert: Array[Dictionary] = Flow.level_select(Defs.GameMode.SINGLE, 2, Defs.Difficulty.EXPERT)
	assert_true(expert.any(func(entry: Dictionary) -> bool: return entry["level_id"] == W_C))
	var coop: Array[Dictionary] = Flow.level_select(Defs.GameMode.COOP, 2, Defs.Difficulty.BEGINNER)
	var coop_ids: Array = coop.map(func(entry: Dictionary) -> StringName: return entry["level_id"])
	assert_true(coop_ids.has(W_A) and coop_ids.has(W_B), "co-op: the stops with a co-op file, by their solo id")
	for entry: Dictionary in coop:
		assert_eq(entry["code"], "", "co-op files have no codes")
	var book_one: Array[Dictionary] = Flow.level_select(Defs.GameMode.SINGLE, 1, Defs.Difficulty.BEGINNER)
	assert_eq(book_one[0]["level_id"], &"w1_l1")
	assert_eq(book_one[0]["code"], "V1NE", "Book I keeps its 1.0 codes")
	assert_eq(book_one.size(), Levels.get_campaign(Defs.Difficulty.BEGINNER).size())


# =================================================================================================================
# Joining and leaving
# =================================================================================================================

func test_joining_and_leaving_on_the_join_panel() -> void:
	_listen(Flow.party_changed, "party")
	Flow.begin_party_setup()
	assert_eq(Flow.party_size(), 0)
	assert_eq(Flow.join_player(InputSlot.keyboard(Defs.InputSlotKind.KEYBOARD_RIGHT)), 0, "the first to press Jump is P1")
	assert_eq(Flow.join_player(InputSlot.keyboard(Defs.InputSlotKind.KEYBOARD_RIGHT)), -1, "one input, one player")
	assert_eq(Flow.join_player(InputSlot.pad(4)), 1)
	assert_eq(Flow.join_player(InputSlot.pad(5)), -1, "co-op is two players")
	assert_eq(Flow.join_player(null), -1)
	assert_eq(Flow.party_size(), 2)
	Game.runs[1].palette = &"pink"
	assert_true(Flow.leave_player(0), "P1 leaves")
	assert_eq(GameInput.get_slot(0).kind, Defs.InputSlotKind.PAD, "P2 moves up with his pad ...")
	assert_eq(GameInput.get_slot(0).device_id, 4)
	assert_eq(Game.runs[0].palette, &"pink", "... and his colour")
	assert_eq(GameInput.get_slot(1).kind, Defs.InputSlotKind.NONE)
	assert_eq(Flow.party_size(), 1)
	assert_false(Flow.leave_player(3), "nobody plays there")
	assert_eq(_signals.map(func(entry: Array) -> int: return entry[1]), [0, 1, 2, 1],
			"every change is announced with the new size (setup, two joins, a leave)")


func test_a_partner_joins_mid_stage_at_the_checkpoint() -> void:
	Game.new_game(Defs.Difficulty.BEGINNER)
	Flow.start_level(PARTY_LEVEL, Defs.Transition.NONE)
	await Flow.transition_finished
	var level: LevelBase = Game.level
	assert_not_null(level)
	if level == null:
		await _finish()
		return
	assert_eq(level.hero_count(), 1)
	var checkpoint: Vector2i = level.start_pos + Vector2i(-64, 0)
	Game.set_checkpoint(checkpoint)
	Game.add_score(700)
	GameInput.device = Defs.Device.KEYBOARD
	assert_eq(Flow.join_player(InputSlot.pad(9)), 1, "a pad joins the running game")
	assert_eq(GameInput.get_slot(0).kind, Defs.InputSlotKind.KEYBOARD_LEFT, "the single player keeps his keys")
	if Flow.busy:
		await Flow.transition_finished
	level = Game.level
	assert_not_null(level)
	if level == null:
		await _finish()
		return
	assert_eq(Game.mode, Defs.GameMode.COOP)
	assert_eq(Game.party, 2)
	assert_eq(level.hero_count(), 2, "the stage restarted with two heroes")
	assert_eq(Game.score, 700, "the score is kept")
	assert_true(Game.has_checkpoint)
	assert_eq(Game.checkpoint_pos, checkpoint, "at the checkpoint the player had reached")
	assert_eq(level.get_hero(0).sim_pos, checkpoint, "P1 stands at the checkpoint")
	assert_eq(level.get_hero(1).sim_pos, level.get_respawn_pos_for(1), "P2 beside him")
	assert_eq(Sim.tick, 0, "nothing ran before the curtain opened")
	assert_true(Flow.leave_player(1), "P2 leaves from the pause menu")
	if Flow.busy:
		await Flow.transition_finished
	level = Game.level
	assert_eq(Game.mode, Defs.GameMode.SINGLE)
	assert_eq(Game.party, 1)
	assert_eq(GameInput.get_slot(0).kind, Defs.InputSlotKind.ALL_DEVICES, "single-player input again")
	if level != null:
		assert_eq(level.hero_count(), 1)
		assert_eq(level.player.sim_pos, checkpoint)
	assert_false(Flow.leave_player(0), "the last player quits instead of leaving")
	await _finish()


func test_a_lost_pad_pauses_for_its_player() -> void:
	_listen(Flow.pad_lost, "lost")
	_listen(Flow.pad_reconnected, "back")
	Game.start_run(Defs.Difficulty.BEGINNER, Defs.GameMode.COOP, 2)
	GameInput.assign_slot(0, InputSlot.keyboard(Defs.InputSlotKind.KEYBOARD_LEFT))
	GameInput.assign_slot(1, InputSlot.pad(7))
	Flow.notify_pad_connection(7, false)
	assert_eq(Flow.lost_pad_slots(), PackedInt32Array([1]), "off the level the seat is only marked")
	assert_false(Flow.is_paused())
	Flow.notify_pad_connection(7, true)
	assert_eq(Flow.lost_pad_slots().size(), 0)
	Flow.start_level(PARTY_LEVEL, Defs.Transition.NONE)
	await Flow.transition_finished
	Flow.notify_pad_connection(3, false)
	assert_eq(Flow.lost_pad_slots().size(), 0, "a pad nobody plays with")
	Flow.notify_pad_connection(7, false)
	Flow.notify_pad_connection(7, false)
	assert_eq(Flow.lost_pad_slots(), PackedInt32Array([1]), "lost once")
	assert_true(Flow.is_paused(), "the game pauses")
	assert_eq(Flow.pause_slot, 1, "with the focus on the player whose pad was lost")
	Flow.notify_pad_connection(12, true)
	assert_eq(GameInput.get_slot(1).kind, Defs.InputSlotKind.PAD)
	assert_eq(GameInput.get_slot(1).device_id, 12, "a reconnected pad with a new id takes the seat")
	assert_true(Flow.is_paused(), "the player resumes himself")
	Flow.set_paused(false)
	Flow.notify_pad_connection(12, false)
	assert_false(Flow.continue_alone(0), "P1's pad was not lost")
	assert_true(Flow.continue_alone(1), "continue alone")
	if Flow.busy:
		await Flow.transition_finished
	assert_eq(Game.mode, Defs.GameMode.SINGLE, "the partner left")
	assert_eq(Game.party, 1)
	assert_eq(_signals.map(func(entry: Array) -> String: return entry[0]),
			["lost", "back", "lost", "back", "lost"])
	await _finish()


# =================================================================================================================
# Versus
# =================================================================================================================

func test_a_versus_match_runs_its_rounds() -> void:
	_add_book_two()
	var calls: Array = []
	VersusMatch.bot_factory = func(slot: int, level: int, seed_value: int) -> Callable:
		calls.append([slot, level, seed_value])
		return func(_tick: int) -> int: return Defs.IN_RIGHT
	var ended: Array = []
	var on_round_ended: Callable = func(index: int, winners: PackedInt32Array) -> void: ended.append([index, winners])
	Events.round_ended.connect(on_round_ended)
	_connections.append([Events.round_ended, on_round_ended])
	var versus_match: VersusMatch = VersusMatch.new()
	versus_match.arena = ARENA
	versus_match.rounds_to_win = 2
	versus_match.seat_human(InputSlot.keyboard(Defs.InputSlotKind.KEYBOARD_LEFT))
	versus_match.seat_bot(Defs.BotLevel.ROOKIE)
	assert_false(Flow.start_versus(versus_match, 40), "the human is not ready")
	versus_match.ready_all()
	assert_true(Flow.start_versus(versus_match, 40))
	if Flow.busy:
		await Flow.transition_finished
	assert_eq(Game.mode, Defs.GameMode.VERSUS)
	assert_eq(Game.party, 2)
	assert_eq(Game.versus_match, versus_match)
	assert_eq(Flow.current_screen, Flow.SCREEN_LEVEL)
	assert_true(versus_match.round_open)
	assert_eq(versus_match.round_arena, ARENA)
	assert_eq(GameInput.get_slot(0).kind, Defs.InputSlotKind.KEYBOARD_LEFT)
	assert_eq(GameInput.get_slot(1).kind, Defs.InputSlotKind.BOT, "the bot reads its HeroBot source")
	assert_eq(calls, [[1, Defs.BotLevel.ROOKIE, versus_match.bot_seed(1)]])
	assert_eq(Sim.rng.get_state(), SimRng.new(versus_match.round_seed()).get_state(), "round 0's seed")
	assert_eq(VersusMatch.from_settings().arena, ARENA, "the rules are remembered")
	if Game.level != null:
		assert_eq(Game.level.hero_count(), 2)
		Sim.step(1)
		assert_eq(GameInput.get_flags(1), Defs.IN_RIGHT, "the bot drives P2")
	Flow.end_round(PackedInt32Array([1]))
	assert_eq(ended, [[0, PackedInt32Array([1])]])
	if Flow.busy:
		await Flow.transition_finished
	if Flow.current_screen == Flow.SCREEN_VERSUS_SCOREBOARD:
		Flow.next_round()
		if Flow.busy:
			await Flow.transition_finished
	assert_eq(versus_match.round_index, 1)
	assert_true(versus_match.round_open, "round 1 plays")
	assert_eq(Sim.rng.get_state(), SimRng.new(VersusTuning.round_seed(40, 1)).get_state(), "round 1's seed")
	assert_eq(calls.size(), 2, "a fresh bot every round")
	Flow.end_round(PackedInt32Array([1]))
	Flow.end_round(PackedInt32Array([0]))
	if Flow.busy:
		await Flow.transition_finished
	assert_true(versus_match.is_over(), "two round wins end it")
	assert_eq(versus_match.leaders(), PackedInt32Array([1]))
	assert_eq(ended.size(), 2, "a second gong in the same round is ignored")
	assert_false(versus_match.round_open)
	if Flow.has_screen(Flow.SCREEN_VERSUS_RESULTS):
		assert_eq(Flow.current_screen, Flow.SCREEN_VERSUS_RESULTS)
		assert_eq(Flow.args.get("winners"), PackedInt32Array([1]))
	else:
		assert_ne(Flow.current_screen, Flow.SCREEN_LEVEL, "without a results screen the match leaves the arena")
	Flow.rematch()
	if Flow.busy:
		await Flow.transition_finished
	assert_eq(versus_match.round_index, 0, "a rematch starts again")
	assert_eq(versus_match.match_seed, 41)
	assert_eq(Flow.current_screen, Flow.SCREEN_LEVEL)
	await _finish()


## Round loop polish (P2.6): an arena that names a battle track starts the match with it and every later round plays
## the next of the three (DESIGN.md F.2: battle A, B, C), so a match hears them all; an arena with music of its own keeps
## it.
func test_the_rounds_of_a_match_turn_through_the_battle_music() -> void:
	_add_book_two()
	assert_eq(VersusMatch.round_music(Sfx.MUSIC_VERSUS_BATTLE_A, 0), Sfx.MUSIC_VERSUS_BATTLE_A)
	assert_eq(VersusMatch.round_music(Sfx.MUSIC_VERSUS_BATTLE_A, 1), Sfx.MUSIC_VERSUS_BATTLE_B)
	assert_eq(VersusMatch.round_music(Sfx.MUSIC_VERSUS_BATTLE_A, 2), Sfx.MUSIC_VERSUS_BATTLE_C)
	assert_eq(VersusMatch.round_music(Sfx.MUSIC_VERSUS_BATTLE_A, 3), Sfx.MUSIC_VERSUS_BATTLE_A)
	assert_eq(VersusMatch.round_music(Sfx.MUSIC_VERSUS_BATTLE_C, 1), Sfx.MUSIC_VERSUS_BATTLE_A, "it starts at the arena's")
	assert_eq(VersusMatch.round_music(Sfx.MUSIC_JUNGLE, 4), Sfx.MUSIC_JUNGLE, "music of its own stays")
	assert_eq(VersusMatch.round_music(&"", 1), &"")
	(Levels._meta[ARENA] as Dictionary)["music"] = String(Sfx.MUSIC_VERSUS_BATTLE_A)
	VersusMatch.bot_factory = func(_slot: int, _level: int, _seed: int) -> Callable:
		return func(_tick: int) -> int: return 0
	var versus_match: VersusMatch = VersusMatch.new()
	versus_match.arena = ARENA
	versus_match.rounds_to_win = 3
	versus_match.seat_bot(Defs.BotLevel.ROOKIE)
	versus_match.seat_bot(Defs.BotLevel.ROOKIE)
	assert_true(Flow.start_versus(versus_match, 3))
	if Flow.busy:
		await Flow.transition_finished
	for round_index: int in [1, 2]:
		Flow.end_round(PackedInt32Array([0]))
		if Flow.busy:
			await Flow.transition_finished
		if Flow.current_screen == Flow.SCREEN_VERSUS_SCOREBOARD:
			Flow.next_round()
			if Flow.busy:
				await Flow.transition_finished
		assert_eq(versus_match.round_index, round_index)
		assert_eq(Audio.get_music_context(), VersusMatch.BATTLE_MUSIC[round_index],
				"round %d plays battle track %d" % [round_index, round_index])
	Audio.stop_music(0.0)
	await _finish()


func test_a_bot_seat_gets_one_herobot_for_the_match() -> void:
	if not ResourceLoader.exists(VersusMatch.HERO_BOT_PATH):
		assert_true(true, "core-B's HeroBot is not in this tree yet")
		return
	var versus_match: VersusMatch = VersusMatch.new()
	versus_match.seat_human(InputSlot.pad(0))
	versus_match.seat_bot(Defs.BotLevel.CHIEF)
	versus_match.begin_match(9)
	versus_match.begin_round(&"some_arena")
	var source: Callable = Flow._bot_source(versus_match, 1, Defs.BotLevel.CHIEF)
	var bot: Object = versus_match.bots[1]
	assert_not_null(bot, "the seat's HeroBot")
	if bot == null:
		return
	assert_eq(source.get_object(), bot, "the slot reads the bot's produce")
	assert_eq(source.get_method(), &"produce")
	assert_eq(bot.get("slot"), 1)
	assert_eq(bot.get("bot_level"), Defs.BotLevel.CHIEF)
	assert_eq(bot.get("match_seed"), 9)
	versus_match.record_round(PackedInt32Array())
	versus_match.begin_round(&"some_arena")
	Flow._bot_source(versus_match, 1, Defs.BotLevel.CHIEF)
	assert_eq(versus_match.bots[1], bot, "one HeroBot serves the whole match")
	versus_match.rematch()
	assert_null(versus_match.bots[1], "a rematch makes new bots")


func test_versus_lobby_seats_join_and_bots() -> void:
	Game.versus_match = VersusMatch.new()
	Flow.play_mode = Defs.GameMode.VERSUS
	Flow.current_screen = Flow.SCREEN_VERSUS_LOBBY
	Flow.begin_party_setup()
	assert_eq(Flow.join_player(InputSlot.keyboard(Defs.InputSlotKind.KEYBOARD_LEFT)), 0)
	assert_eq(Flow.add_bot(Defs.BotLevel.CHIEF), 1, "Add CPU")
	assert_eq(Flow.join_player(InputSlot.keyboard(Defs.InputSlotKind.KEYBOARD_RIGHT)), 2, "the bot's seat is taken")
	assert_eq(Flow.join_player(InputSlot.pad(1)), 3, "four on one device")
	assert_eq(Flow.join_player(InputSlot.pad(2)), -1, "full")
	assert_eq(Flow.party_size(), 4)
	assert_true(Game.versus_match.is_bot(1))
	assert_eq(Game.versus_match.get_seat(2).input.kind, Defs.InputSlotKind.KEYBOARD_RIGHT)
	assert_true(Flow.leave_player(1), "the bot is removed")
	assert_eq(Game.versus_match.player_count(), 3)
	assert_eq(GameInput.get_slot(2).kind, Defs.InputSlotKind.KEYBOARD_RIGHT, "lobby seats do not move")
	Flow.current_screen = Flow.SCREEN_BOOT
