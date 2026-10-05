extends TestCase
## World 4 campaign levels (owner: level design w4), both Expert only: Cinder Shaft (w4_l1), the auto-scrolling
## descent down a volcanic chimney, and Obsidian Keep (w4_l2) with its linked boss sub-stage Colossus Hall (w4_l2b),
## where the Wall Colossus (boss 2) waits. The Colossus' trophy leads to the ending stage.
##
## Each route in tools/autoplay/routes is replayed through Flow and the real level scene from a fresh Expert run with
## the default seed, tick for tick as the windowed autoplay plays it, and must finish without losing a life and
## without a single engine warning or error. Obsidian Keep's exit leads straight into Colossus Hall (no tally), as
## in the game, and the second route is played there.
##
## Two fairness checks guard the layouts themselves (review w4): a player who rushes down the shaft without waiting
## for the view gets several seconds before the bottom edge catches him, and the column staircase of the keep
## forgives a range of jump timings instead of one exact input.

const W4_L1: StringName = &"w4_l1"
const W4_L2: StringName = &"w4_l2"
const W4_L2B: StringName = &"w4_l2b"
const ENDING: StringName = &"ending"
const ROUTES: String = "res://tools/autoplay/routes/"
## Logical view of the autoplay window (1280 x 720 at integer scale 2): enemies wake by the view.
const VIEW: Vector2i = Vector2i(Tuning.VIEW_W, Tuning.VIEW_H)
const COUNTED: Array[StringName] = [&"exit_reached", &"player_died", &"level_respawned", &"checkpoint_activated",
		&"enemy_killed", &"hidden_spot_opened", &"secret_found", &"player_hurt", &"level_completed",
		&"item_collected", &"boss_started", &"boss_defeated"]
## A player who walks every ledge of the crater throat to its end and drops at once, never waiting for the view.
const RUSH_INPUTS: String = "34:L,36:R,36:L,36:R,36:L,36:R,30:L,8:R,12:L,30:R,60:"
## The rusher must still be alive this long (about 8 seconds) and well down the throat by then.
const RUSH_SAFE_TICKS: int = 200
const RUSH_MIN_ROW: int = 20
## Column staircase of Obsidian Keep: right edges (px) of the floor and of columns 1-3, and the high ledge.
const STAIR_EDGES: Array[int] = [1472, 1568, 1648, 1728]
const STAIR_GOAL: Vector2i = Vector2i(1808, 432)
## Take-off distances from the edge (px) and Right-hold lengths (ticks, Up held for the whole jump) a player uses.
const STAIR_TAKEOFFS: Array[int] = [6, 12, 18]
const STAIR_HOLDS: Array[int] = [10, 12, 14, 16]
const STAIR_MIN_SUCCESS: int = 10


## Counts the warnings and errors the engine logs while a route plays.
class ProblemCounter:
	extends Logger

	var count: int = 0
	var first: String = ""

	func _log_error(
			function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool,
			_error_type: int, _script_backtraces: Array[ScriptBacktrace]
	) -> void:
		count += 1
		if first == "":
			first = "%s (%s:%d %s) %s" % [code, file, line, function, rationale]

	func _log_message(_message: String, _error: bool) -> void:
		pass


var _counts: Dictionary = {}
var _connections: Array[Array] = []
var _problems: ProblemCounter = null
## Lowest top edge of the view while a route played (the auto-scroll's progress).
var _deepest_view_y: int = 0
## Embers seen while a route played, and those that came down right next to the hero.
var _embers_seen: Dictionary = {}
var _embers_close: Dictionary = {}
var _letter_words: int = 0


func after_each() -> void:
	_stop_counting_problems()
	for connection: Array in _connections:
		var signal_ref: Signal = connection[0]
		if signal_ref.is_connected(connection[1]):
			signal_ref.disconnect(connection[1])
	_connections.clear()
	_counts.clear()
	GameInput.clear_scripted()
	Sim.manual = false
	Sim.stop()
	if get_tree().current_scene != null:
		get_tree().current_scene.free()
		get_tree().current_scene = null
	Flow.current_screen = Flow.SCREEN_BOOT


func test_the_levels_are_valid() -> void:
	var validator: LevelValidator = LevelValidator.new()
	assert_true(validator.add_folder(Levels.LEVEL_DIR) > 0)
	validator.run()
	for level_id: StringName in [W4_L1, W4_L2, W4_L2B]:
		var problems: Array[Dictionary] = validator.problems_of(Levels.get_level_path(level_id))
		var lines: PackedStringArray = PackedStringArray()
		for problem: Dictionary in problems:
			lines.append(LevelValidator.format_problem(problem))
		assert_eq(problems.size(), 0, "%s: no error and no warning\n%s" % [level_id, "\n".join(lines)])


func test_the_world_4_links() -> void:
	for level_id: StringName in [W4_L1, W4_L2, W4_L2B]:
		assert_true(Levels.has_level(level_id), "%s exists" % level_id)
		assert_eq(str(Levels.get_value(level_id, "biome", "")), "volcano")
		assert_eq(int(Levels.get_value(level_id, "world", 0)), 4)
		assert_eq(str(Levels.get_value(level_id, "min_difficulty", "")), "expert", "%s is expert only" % level_id)
		assert_true(Levels.is_available(level_id, Defs.Difficulty.EXPERT))
		assert_false(Levels.is_available(level_id, Defs.Difficulty.BEGINNER), "%s is hidden from Beginner" % level_id)
	assert_eq(str(Levels.get_value(W4_L1, "kind", "")), "main")
	assert_eq(int(Levels.get_value(W4_L1, "order", 0)), 70)
	assert_eq(str(Levels.get_value(W4_L1, "scroll", "")), "autoscroll", "Cinder Shaft scrolls by itself")
	assert_eq(str(Levels.get_value(W4_L2, "kind", "")), "main")
	assert_eq(int(Levels.get_value(W4_L2, "order", 0)), 80)
	assert_false(bool(Levels.get_value(W4_L2, "tally", true)), "no tally between the keep and the Colossus")
	assert_eq(str(Levels.get_value(W4_L2B, "kind", "")), "sub")
	var campaign: Array[StringName] = Levels.get_campaign(Defs.Difficulty.EXPERT)
	assert_true(campaign.find(W4_L1) >= 0 and campaign.find(W4_L1) < campaign.find(W4_L2),
			"Cinder Shaft comes before Obsidian Keep")
	assert_false(campaign.has(W4_L2B), "the sub-stage has no stop of its own on the map")
	assert_false(Levels.get_campaign(Defs.Difficulty.BEGINNER).has(W4_L1), "no world 4 on a Beginner map")
	assert_eq(Levels.next_level(W4_L1, Defs.Difficulty.EXPERT), W4_L2, "the shaft leads to the keep")
	assert_eq(Levels.next_level(W4_L2, Defs.Difficulty.EXPERT), W4_L2B, "the keep continues in the Colossus' hall")
	assert_eq(Levels.next_level(W4_L2B, Defs.Difficulty.EXPERT), ENDING, "the Colossus' trophy leads to the ending")
	assert_true(Levels.has_level(ENDING), "the ending stage exists")
	assert_eq(Levels.find_by_password("4CND"), {"level_id": W4_L1, "difficulty": Defs.Difficulty.BEGINNER})
	assert_eq(Levels.find_by_password("4SHF"), {"level_id": W4_L1, "difficulty": Defs.Difficulty.EXPERT})
	assert_eq(Levels.find_by_password("4KEP"), {"level_id": W4_L2, "difficulty": Defs.Difficulty.BEGINNER})
	assert_eq(Levels.find_by_password("4OBS"), {"level_id": W4_L2, "difficulty": Defs.Difficulty.EXPERT})
	assert_eq(Levels.find_by_password("4COL"), {"level_id": W4_L2B, "difficulty": Defs.Difficulty.BEGINNER})
	assert_eq(Levels.find_by_password("4WAL"), {"level_id": W4_L2B, "difficulty": Defs.Difficulty.EXPERT})


func test_cinder_shaft_expert_route() -> void:
	Game.new_game(Defs.Difficulty.EXPERT)
	await _start(W4_L1)
	var start_y: int = Game.level.get_view_rect().position.y
	_start_counting_problems()
	var played: int = _replay(Autoplay.parse_inputs(FileAccess.get_file_as_string(ROUTES + "w4_l1.inputs")))
	_stop_counting_problems()
	_log(W4_L1, played)
	assert_eq(_count(&"exit_reached"), 1, "the magma chamber exit was reached after %d ticks" % played)
	assert_eq(_count(&"player_died"), 0, "no life lost in the shaft")
	assert_eq(_count(&"level_respawned"), 0, "no respawn")
	assert_true(Game.lives >= Tuning.LIVES_START, "no life lost: %d" % Game.lives)
	assert_true(_deepest_view_y - start_y > 2000, "the view sank down the chimney (%d px)" % (_deepest_view_y - start_y))
	assert_true(_count(&"checkpoint_activated") >= 3, "checkpoints: %d" % _count(&"checkpoint_activated"))
	assert_true(_count(&"secret_found") >= 3, "secrets on the way: %d" % _count(&"secret_found"))
	assert_true(_count(&"hidden_spot_opened") >= 15, "hidden spots opened: %d" % _count(&"hidden_spot_opened"))
	assert_eq(_letter_words, 1, "G-R-U-B-S collected in the shaft")
	assert_true(played >= 2600 and played <= 4400, "the route takes %d ticks" % played)
	assert_true(Game.completion_percent() >= 70, "completion %d %%" % Game.completion_percent())
	# The ember rain is a real hazard: embers fall in the open chute and cavern and land beside the waiting hero.
	assert_true(_embers_seen.size() >= 20, "embers fell: %d" % _embers_seen.size())
	assert_true(_embers_close.size() >= 1, "embers came down next to the hero: %d" % _embers_close.size())
	_assert_no_problems(W4_L1)
	await _settle()
	assert_eq(Flow.current_screen, Flow.SCREEN_TALLY, "the exit leads to the tally")


## The crater throat paces a player who never waits: he sinks toward the bottom edge over several seconds (the
## lesson of the auto-scroll) instead of falling below it on his second drop.
func test_cinder_shaft_gives_a_rusher_time() -> void:
	Game.new_game(Defs.Difficulty.EXPERT)
	await _start(W4_L1)
	var flags: PackedInt32Array = Autoplay.parse_inputs(RUSH_INPUTS)
	flags.resize(RUSH_SAFE_TICKS)
	var played: int = _replay(flags)
	assert_eq(played, RUSH_SAFE_TICKS)
	assert_eq(_count(&"player_died"), 0, "the rusher is still alive after %d ticks" % RUSH_SAFE_TICKS)
	var hero: PlayerBase = Game.level.player
	assert_true(hero.sim_pos.y >= RUSH_MIN_ROW * Tuning.TILE, "the rusher went down the throat (row %d)" % (
			hero.sim_pos.y / Tuning.TILE))


func test_obsidian_keep_and_the_wall_colossus_expert_route() -> void:
	Game.new_game(Defs.Difficulty.EXPERT)
	await _start(W4_L2)
	var keep_items: int = Game.items_total
	_start_counting_problems()
	var played: int = _replay(Autoplay.parse_inputs(FileAccess.get_file_as_string(ROUTES + "w4_l2.inputs")))
	_stop_counting_problems()
	_log(W4_L2, played)
	assert_eq(_count(&"exit_reached"), 1, "the door to the Colossus was reached after %d ticks" % played)
	assert_eq(_count(&"player_died"), 0, "no life lost in the keep")
	assert_true(_count(&"checkpoint_activated") >= 3, "checkpoints: %d" % _count(&"checkpoint_activated"))
	assert_true(_count(&"secret_found") >= 3, "secrets on the way: %d" % _count(&"secret_found"))
	assert_true(_count(&"hidden_spot_opened") >= 15, "hidden spots opened: %d" % _count(&"hidden_spot_opened"))
	assert_true(_count(&"enemy_killed") >= 4, "kills: %d" % _count(&"enemy_killed"))
	assert_eq(_letter_words, 1, "G-R-U-B-S collected in the keep")
	assert_true(played >= 2200 and played <= 4400, "the keep takes %d ticks" % played)
	assert_true(Game.completion_percent() >= 80, "completion %d %%" % Game.completion_percent())
	_assert_no_problems(W4_L2)
	await _settle()
	# tally = false: the exit leads straight into the sub-stage, progress carried over.
	assert_eq(Flow.current_screen, Flow.SCREEN_LEVEL, "no tally after the keep")
	assert_eq(Game.level_id, W4_L2B, "Colossus Hall follows")
	assert_true(Game.items_total >= keep_items, "the hall keeps the keep's completion totals")
	var level: Level = Game.level as Level
	assert_not_null(level)
	if level != null:
		level.set_view_size(VIEW * Tuning.ART_SCALE)
	_counts.clear()
	_start_counting_problems()
	var played_hall: int = _replay(Autoplay.parse_inputs(FileAccess.get_file_as_string(ROUTES + "w4_l2b.inputs")))
	_stop_counting_problems()
	_log(W4_L2B, played_hall)
	assert_eq(Game.weapon, Defs.Weapon.AXE, "the axe from the antechamber was picked up")
	assert_eq(_count(&"boss_started"), 1, "the Colossus woke")
	assert_eq(_count(&"boss_defeated"), 1, "the Wall Colossus was beaten")
	assert_eq(_count(&"exit_reached"), 1, "its trophy was collected after %d ticks" % played_hall)
	assert_eq(_count(&"level_completed"), 1)
	assert_eq(_count(&"player_died"), 0, "no life lost against the Colossus")
	assert_eq(Game.lives, Tuning.LIVES_START, "no life lost in either half")
	_assert_no_problems(W4_L2B)
	await _settle()
	assert_eq(Flow.current_screen, Flow.SCREEN_LEVEL, "the trophy leads on without a tally")
	assert_eq(Game.level_id, ENDING, "the ending stage follows the Colossus")


## The four rising columns over the spike carpet: a player who walks up to the edge, waits for the next column to
## stop rising and jumps with Up held and Right for most of the rise lands on every column - not only with one
## exact input. Played from the hall's entrance as the route reaches it.
func test_obsidian_keep_column_staircase_forgives_timing() -> void:
	var route: String = FileAccess.get_file_as_string(ROUTES + "w4_l2.inputs")
	var cut: int = route.find("# Column hall")
	assert_true(cut > 0, "the route has a column hall section")
	var prefix: PackedInt32Array = Autoplay.parse_inputs(route.substr(0, cut))
	var ok: int = 0
	var results: PackedStringArray = PackedStringArray()
	for takeoff: int in STAIR_TAKEOFFS:
		for hold: int in STAIR_HOLDS:
			var result: String = await _climb_staircase(prefix, takeoff, hold)
			results.append("%d/%d:%s" % [takeoff, hold, result])
			if result == "ok":
				ok += 1
			after_each()
	assert_true(ok >= STAIR_MIN_SUCCESS, "staircase climbs: %d of %d (%s)" % [
			ok, results.size(), ", ".join(results)])


# =================================================================================================================
# Helpers (pattern of tests/test_integration_levels.gd)
# =================================================================================================================

## Enter `level_id` through Flow like the game does, with the clock under the test's control.
func _start(level_id: StringName) -> void:
	for signal_name: StringName in COUNTED:
		var counter: Callable = _on_event.bind(signal_name)
		var arguments: int = 0
		for info: Dictionary in Events.get_signal_list():
			if StringName(str(info["name"])) == signal_name:
				arguments = (info["args"] as Array).size()
		var callable: Callable = counter.unbind(arguments) if arguments > 0 else counter
		var signal_ref: Signal = Signal(Events, signal_name)
		signal_ref.connect(callable)
		_connections.append([signal_ref, callable])
	var words: Callable = _on_letter_word
	Game.letters_completed.connect(words)
	_connections.append([Game.letters_completed, words])
	_letter_words = 0
	Sim.manual = true
	Flow.start_level(level_id, Defs.Transition.NONE)
	await _settle()
	assert_eq(Flow.current_screen, Flow.SCREEN_LEVEL)
	assert_eq(Game.level.level_id, level_id)
	# Headless runs have no window: give the level the view of the autoplay window before the first tick.
	var level: Level = Game.level as Level
	assert_not_null(level, "the world module's level scene")
	if level != null:
		level.set_view_size(VIEW * Tuning.ART_SCALE)


## Play input flags one tick at a time until they end or gameplay stops; returns the ticks played.
func _replay(flags: PackedInt32Array) -> int:
	assert_true(flags.size() > 100, "an input script")
	var index: Array[int] = [0]
	GameInput.set_scripted(func(_tick: int) -> int:
		var value: int = flags[index[0]] if index[0] < flags.size() else 0
		index[0] += 1
		return value
	)
	var played: int = 0
	_deepest_view_y = 0
	_embers_seen.clear()
	_embers_close.clear()
	while played < flags.size() and Sim.running:
		Sim.step(1)
		played += 1
		if Game.level != null:
			_deepest_view_y = maxi(_deepest_view_y, Game.level.get_view_rect().position.y)
			_watch_embers(Game.level)
	GameInput.clear_scripted()
	return played


## Embers that came down beside the hero: within 24 px of him and between his head and his feet.
func _watch_embers(level: LevelBase) -> void:
	if level.player == null:
		return
	var hero: Vector2i = level.player.sim_pos
	for entity: SimEntity in level.get_kind(Defs.Kind.ENEMY_PROJECTILE):
		if not entity is EnemyEmber:
			continue
		var id: int = entity.get_instance_id()
		_embers_seen[id] = true
		var rel: Vector2i = entity.sim_pos - hero
		if absi(rel.x) < 24 and rel.y > -56 and rel.y < 8:
			_embers_close[id] = true


## One staircase climb from the hall's entrance with a simple player: walk to `takeoff` px before the edge, stand
## until the next column has risen completely, jump with Up held 24 ticks and Right for `hold` ticks, land, repeat.
## Returns "ok" when the high ledge is reached, "fell N" when the hero died at step N, "stuck N" otherwise.
func _climb_staircase(prefix: PackedInt32Array, takeoff: int, hold: int) -> String:
	Game.new_game(Defs.Difficulty.EXPERT)
	await _start(W4_L2)
	var columns: Array[RisingColumn] = []
	for entity: SimEntity in Game.level.get_kind(Defs.Kind.OTHER):
		# The hall's columns (the gatehouse has a bridge column of its own further west).
		if entity is RisingColumn and entity.sim_pos.x >= STAIR_EDGES[0]:
			columns.append(entity as RisingColumn)
	columns.sort_custom(func(a: RisingColumn, b: RisingColumn) -> bool: return a.sim_pos.x < b.sim_pos.x)
	assert_eq(columns.size(), STAIR_EDGES.size(), "four rising columns in the hall")
	# state: 0 walk, 1 stand, 2 jump, 3 in the air; step; timer; steady ticks
	var st: Array[int] = [0, 0, 0, 0]
	var index: Array[int] = [0]
	GameInput.set_scripted(func(_tick: int) -> int:
		var i: int = index[0]
		index[0] += 1
		if i < prefix.size():
			return prefix[i]
		return _staircase_input(columns, st, takeoff, hold)
	)
	var result: String = ""
	var ticks: int = 0
	while ticks < prefix.size() + 1200 and Sim.running and result == "":
		Sim.step(1)
		ticks += 1
		var hero: PlayerBase = Game.level.player
		if _count(&"player_died") > 0:
			result = "fell %d" % st[1]
		elif st[1] >= STAIR_EDGES.size() and hero.sim_pos.x >= STAIR_GOAL.x and hero.sim_pos.y <= STAIR_GOAL.y \
				and hero.yvel == 0:
			result = "ok"
	GameInput.clear_scripted()
	return result if result != "" else "stuck %d" % st[1]


func _staircase_input(columns: Array[RisingColumn], st: Array[int], takeoff: int, hold: int) -> int:
	var hero: PlayerBase = Game.level.player
	var step: int = st[1]
	if step >= STAIR_EDGES.size():
		return GameInput.keys_to_flags("R") if hero.sim_pos.x < STAIR_GOAL.x + 8 else 0
	match st[0]:
		0:
			# The hero stops within about 12 px after Right is released.
			if hero.sim_pos.x < STAIR_EDGES[step] - takeoff - 12:
				return GameInput.keys_to_flags("R")
			st[0] = 1
			st[3] = 0
		1:
			var risen: bool = columns[step].risen >= columns[step].rise
			st[3] = st[3] + 1 if hero.yvel == 0 and hero.xvel == 0 and risen else 0
			if st[3] >= 8:
				st[0] = 2
				st[2] = 0
		2:
			st[2] += 1
			if st[2] <= 24:
				return GameInput.keys_to_flags("RU" if st[2] <= hold else "U")
			st[0] = 3
			st[2] = 0
		_:
			st[2] += 1
			if hero.yvel == 0 and st[2] > 4:
				st[0] = 0
				st[1] += 1
	return 0


func _start_counting_problems() -> void:
	_stop_counting_problems()
	_problems = ProblemCounter.new()
	OS.add_logger(_problems)


func _stop_counting_problems() -> void:
	if _problems != null:
		OS.remove_logger(_problems)


func _assert_no_problems(level_id: StringName) -> void:
	assert_not_null(_problems)
	if _problems != null:
		assert_eq(_problems.count, 0, "%s: no engine warning or error while playing (first: %s)" % [
			level_id, _problems.first])
	_problems = null


func _log(level_id: StringName, played: int) -> void:
	print("  %s (%s): %d ticks, score %d, completion %d %%, %d item(s), %d spot(s) opened, %d secret(s), %d kill(s), %d hurt(s), %d death(s), lives %d, embers %d (%d beside the hero)" % [
		level_id, Defs.difficulty_name(Game.difficulty), played, Game.score, Game.completion_percent(),
		_count(&"item_collected"), _count(&"hidden_spot_opened"), _count(&"secret_found"), _count(&"enemy_killed"),
		_count(&"player_hurt"), _count(&"player_died"), Game.lives, _embers_seen.size(), _embers_close.size()])


func _settle() -> void:
	for i: int in 3:
		await get_tree().process_frame
	while Flow.busy:
		await get_tree().process_frame


func _count(signal_name: StringName) -> int:
	return int(_counts.get(signal_name, 0))


func _on_event(signal_name: StringName) -> void:
	_counts[signal_name] = _count(signal_name) + 1


func _on_letter_word() -> void:
	_letter_words += 1
