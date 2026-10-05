extends TestCase
## World 1 (jungle) campaign levels: w1_l1 "Vine Bridges" and w1_l2 "Canopy Village" (owner: level designer w1).
##
## Every level must validate without errors and warnings, and its route proof in tools/autoplay/routes/<id>.inputs
## (and <id>.expert.inputs where the Expert spawn set differs) must finish it from a fresh start through Flow and the
## real level scene, tick for tick as `gd.sh play --autoplay=<id> --inputs-file=...` plays it in a window: the exit is
## reached, no life is lost, no hit is taken and the engine logs no error. Score and completion are logged.
##
## A third route, tools/autoplay/routes/w1_l2.warp.inputs, proves that the hidden warp of Canopy Village is reachable
## and leads to bonus stage A. Two side-path proofs, w1_l1.cliff.inputs and w1_l1.highroad.inputs, reach the optional
## secrets of Vine Bridges that the routes skip (letters G and U), so all five letters of both levels are proven.
##
## Route building aid (not a test of its own): with the environment variable W1_PROBE=<level id> (and optionally
## W1_INPUTS=<res:// path>, W1_DIFF=expert, W1_EVERY=<ticks> for a line every n ticks, W1_YIELD=<ticks> to let a
## frame pass only every n ticks for speed, W1_SHOTS=1 / W1_ITEMS=1 to list thrown axes / loose items) the probe
## test replays that route line by line and prints the hero's cell, state, nearest enemy and the events of every
## line; the route tests are skipped meanwhile, e.g.
##   W1_PROBE=w1_l1 W1_YIELD=16 bash .tools/gd.sh test levels_w1 --verbose

const LEVELS: Array[StringName] = [&"w1_l1", &"w1_l2"]
const ROUTE_DIR: String = "res://tools/autoplay/routes/"
## Letter indices (G R U B S) for Game.letters bit checks.
const LETTER_G: int = 0
const LETTER_U: int = 2
## Logical view of the autoplay window (1280 x 720 at integer scale 2): enemies wake by the view.
const VIEW: Vector2i = Vector2i(Tuning.VIEW_W, Tuning.VIEW_H)
const EVENTS: Array[StringName] = [
	&"exit_reached", &"player_died", &"player_hurt", &"level_respawned", &"checkpoint_activated", &"enemy_killed",
	&"hidden_spot_opened", &"secret_found", &"item_collected", &"player_bounced", &"level_completed",
	&"hittable_hit", &"enemy_hit",
]

var _counts: Dictionary = {}
var _log: PackedStringArray = PackedStringArray()
var _connections: Array[Array] = []
## Ticks between two frames the replay lets pass (1 = like the autoplay harness; the probe may use more).
var _yield_every: int = 1
var _steps: int = 0


func after_each() -> void:
	for connection: Array in _connections:
		var signal_ref: Signal = connection[0]
		if signal_ref.is_connected(connection[1]):
			signal_ref.disconnect(connection[1])
	_connections.clear()
	_counts.clear()
	_log.clear()
	_yield_every = 1
	GameInput.clear_scripted()
	Sim.manual = false
	Sim.stop()
	if get_tree().current_scene != null:
		get_tree().current_scene.free()
		get_tree().current_scene = null
	Flow.current_screen = Flow.SCREEN_BOOT


func test_levels_are_valid_without_warnings() -> void:
	var validator: LevelValidator = LevelValidator.new()
	assert_true(validator.add_folder(Levels.LEVEL_DIR) > 0)
	validator.run()
	for level_id: StringName in LEVELS:
		assert_true(Levels.has_level(level_id), "%s exists" % level_id)
		if not Levels.has_level(level_id):
			continue
		var problems: Array[Dictionary] = validator.problems_of(Levels.get_level_path(level_id))
		var lines: PackedStringArray = PackedStringArray()
		for problem: Dictionary in problems:
			lines.append(LevelValidator.format_problem(problem))
		assert_eq(problems.size(), 0, "%s: no error and no warning\n%s" % [level_id, "\n".join(lines)])


func test_world_one_meta() -> void:
	for level_id: StringName in LEVELS:
		assert_eq(str(Levels.get_value(level_id, "kind", "main")), "main", "%s is a main level" % level_id)
		assert_eq(int(Levels.get_value(level_id, "world", 0)), 1)
		assert_eq(str(Levels.get_value(level_id, "biome", "")), "jungle")
		for difficulty: int in [Defs.Difficulty.BEGINNER, Defs.Difficulty.EXPERT]:
			var code: String = Levels.get_password(level_id, difficulty)
			assert_eq(code.length(), 4, "%s has a password" % level_id)
			assert_eq(Levels.find_by_password(code), {"level_id": level_id, "difficulty": difficulty})
	assert_eq(int(Levels.get_value(&"w1_l1", "order", 0)), 10)
	assert_eq(int(Levels.get_value(&"w1_l2", "order", 0)), 20)
	assert_eq(str(Levels.get_value(&"w1_l2", "bonus", "")), "bonus_a", "the warp of Canopy Village leads to bonus A")


func test_w1_l1_route_beginner() -> void:
	await _check_route(&"w1_l1", Defs.Difficulty.BEGINNER)


func test_w1_l1_route_expert() -> void:
	await _check_route(&"w1_l1", Defs.Difficulty.EXPERT)


func test_w1_l2_route_beginner() -> void:
	await _check_route(&"w1_l2", Defs.Difficulty.BEGINNER)


func test_w1_l2_route_expert() -> void:
	await _check_route(&"w1_l2", Defs.Difficulty.EXPERT)


## The warp of Canopy Village is reachable: the climb, then from the stump on the trunk top onto the bat and up to
## the crow's nest. Touching the staff leaves the level through the warp route into bonus stage A.
func test_w1_l2_warp_reaches_bonus_a() -> void:
	if not OS.get_environment("W1_PROBE").is_empty():
		assert_true(true, "route checks are skipped while probing")
		return
	Game.new_game(Defs.Difficulty.BEGINNER)
	await _start(&"w1_l2")
	var kinds: Array[StringName] = []
	var on_completed: Callable = func(_level_id: StringName, exit_kind: StringName) -> void:
		kinds.append(exit_kind)
	Events.level_completed.connect(on_completed)
	_connections.append([Events.level_completed, on_completed])
	var path: String = ROUTE_DIR + "w1_l2.warp.inputs"
	var played: int = await _play(Autoplay.parse_inputs(FileAccess.get_file_as_string(path)))
	assert_eq(kinds, [&"warp"] as Array[StringName], "the warp ended the level after %d ticks" % played)
	assert_eq(_count(&"player_died"), 0, "no death on the way to the warp")
	assert_true(Game.secrets_found >= 2, "the trunk room and the crow's nest are secrets: %d" % Game.secrets_found)
	await _settle()
	if Levels.has_level(&"bonus_a"):
		assert_eq(Flow.current_screen, Flow.SCREEN_LEVEL)
		assert_eq(Game.level.level_id, &"bonus_a", "the warp leads to bonus stage A")


## The routes skip two optional secrets of Vine Bridges; side-path proofs show they are reachable without a death:
## the branch steps above the start lead to the cliff top with the letter G.
func test_w1_l1_cliff_top_reachable() -> void:
	await _check_side_path(&"w1_l1", "w1_l1.cliff.inputs", LETTER_G)


## The branch steps behind the tunnel rock lead to the high road over the lake with the letter U and a 1-up. The
## first checkpoint stands at the foot of those steps, so a fall into the lake from up there does not send the hero
## back to the start.
func test_w1_l1_high_road_reachable() -> void:
	var lives: int = await _check_side_path(&"w1_l1", "w1_l1.highroad.inputs", LETTER_U)
	if lives >= 0:
		assert_true(_count(&"checkpoint_activated") >= 1, "the climb to the high road lights the first checkpoint")
		assert_eq(Game.lives, lives + 1, "the 1-up on the high road was collected")


## Route-building aid: replays W1_INPUTS (default: the level's route) line by line and prints what happened.
func test_probe() -> void:
	var level_id: String = OS.get_environment("W1_PROBE")
	assert_true(level_id.is_empty() or Levels.has_level(StringName(level_id)), "W1_PROBE names a level")
	if level_id.is_empty():
		return
	var difficulty: int = Defs.Difficulty.EXPERT if OS.get_environment("W1_DIFF") == "expert" \
			else Defs.Difficulty.BEGINNER
	var path: String = OS.get_environment("W1_INPUTS")
	if path.is_empty():
		path = _route_path(StringName(level_id), difficulty)
	var every: int = maxi(OS.get_environment("W1_EVERY").to_int(), 0)
	_yield_every = maxi(OS.get_environment("W1_YIELD").to_int(), 1)
	Game.new_game(difficulty)
	await _start(StringName(level_id))
	print("PROBE %s (%s) items %d spots %d" % [level_id, path, Game.items_total, Game.spots_total])
	var on_spot: Callable = func(pos: Vector2i, kind: StringName) -> void:
		_log.append("spot@%d,%d:%s" % [pos.x >> 4, (pos.y - 1) >> 4, kind])
	Events.hidden_spot_opened.connect(on_spot)
	_connections.append([Events.hidden_spot_opened, on_spot])
	var played: int = 0
	var comment: String = ""
	var line_no: int = 0
	for line: String in FileAccess.get_file_as_string(path).split("\n"):
		line_no += 1
		var text: String = line.strip_edges()
		if text.begins_with("#"):
			comment = text
			continue
		var flags: PackedInt32Array = Autoplay.parse_inputs(text)
		if flags.is_empty():
			continue
		for i: int in flags.size():
			if not Sim.running:
				break
			played += await _play(PackedInt32Array([flags[i]]))
			if every > 0 and played % every == 0:
				print("    t%5d %s" % [played, _hero_text()])
		print("L%3d t%5d %s | %s %s" % [line_no, played, _hero_text(), " ".join(_log), comment])
		_log.clear()
		if not Sim.running:
			break
	print("PROBE END letters %d t%d score %d completion %d%% lives %d hearts %d spots %d/%d items %d/%d secrets %d" % [
		Game.letters, played, Game.score, Game.completion_percent(), Game.lives, Game.hearts, Game.spots_opened,
		Game.spots_total, Game.items_collected, Game.items_total, Game.secrets_found])


func _check_route(level_id: StringName, difficulty: int) -> void:
	if not OS.get_environment("W1_PROBE").is_empty():
		assert_true(true, "route checks are skipped while probing")
		return
	var path: String = _route_path(level_id, difficulty)
	assert_true(FileAccess.file_exists(path), "%s has a route proof (%s)" % [level_id, path])
	if not FileAccess.file_exists(path):
		return
	Game.new_game(difficulty)
	await _start(level_id)
	var level: LevelBase = Game.level
	assert_eq(level.get_view_rect().size, VIEW, "the view of the autoplay window")
	var lives: int = Game.lives
	var flags: PackedInt32Array = Autoplay.parse_inputs(FileAccess.get_file_as_string(path))
	assert_true(flags.size() > 500, "%s is a real input script" % path)
	var played: int = await _play(flags)
	assert_eq(_count(&"exit_reached"), 1, "%s: the exit was reached after %d ticks" % [level_id, played])
	assert_eq(_count(&"player_died"), 0, "%s: no death on the way" % level_id)
	assert_eq(Game.lives, lives, "%s: no life lost" % level_id)
	assert_eq(_count(&"player_hurt"), 0, "%s: the proof takes no hit" % level_id)
	assert_true(_count(&"checkpoint_activated") >= 1, "%s: a checkpoint on the way" % level_id)
	assert_true(_count(&"hidden_spot_opened") >= 5, "%s: spots opened %d" % [level_id, _count(&"hidden_spot_opened")])
	print("    %s %s: %d ticks (%.1f s), score %d, completion %d %%, spots %d/%d, items %d/%d, enemies %d, " % [
		level_id, Defs.difficulty_name(difficulty), played, played / Tuning.TICK_HZ, Game.score,
		Game.completion_percent(), Game.spots_opened, Game.spots_total, Game.items_collected, Game.items_total,
		_count(&"enemy_killed")] + "hurt %d, secrets %d, letters %d" % [
		_count(&"player_hurt"), Game.secrets_found, Game.letters])
	await _settle()
	assert_eq(Flow.current_screen, Flow.SCREEN_TALLY, "%s: the exit leads to the tally" % level_id)


## Replays a Beginner side-path proof from a fresh start and checks that it enters a secret zone and collects the
## letter with index `letter` without a death or a hit. Returns the lives at the start (-1 when skipped).
func _check_side_path(level_id: StringName, file: String, letter: int) -> int:
	if not OS.get_environment("W1_PROBE").is_empty():
		assert_true(true, "route checks are skipped while probing")
		return -1
	var path: String = ROUTE_DIR + file
	assert_true(FileAccess.file_exists(path), "%s has a side-path proof (%s)" % [level_id, path])
	if not FileAccess.file_exists(path):
		return -1
	Game.new_game(Defs.Difficulty.BEGINNER)
	await _start(level_id)
	var lives: int = Game.lives
	var played: int = await _play(Autoplay.parse_inputs(FileAccess.get_file_as_string(path)))
	assert_eq(_count(&"player_died"), 0, "%s: no death on the way (%d ticks)" % [file, played])
	assert_eq(_count(&"player_hurt"), 0, "%s: no hit taken" % file)
	assert_true(_count(&"secret_found") >= 1, "%s: the secret zone was entered" % file)
	assert_true((Game.letters & (1 << letter)) != 0, "%s: the letter %d was collected (letters %d)" % [
		file, letter, Game.letters])
	return lives


func _route_path(level_id: StringName, difficulty: int) -> String:
	if difficulty == Defs.Difficulty.EXPERT:
		var expert: String = ROUTE_DIR + "%s.expert.inputs" % level_id
		if FileAccess.file_exists(expert):
			return expert
	return ROUTE_DIR + "%s.inputs" % level_id


## Enter `level_id` through Flow like the game does, with the clock under the test's control.
func _start(level_id: StringName) -> void:
	for signal_name: StringName in EVENTS:
		var arguments: int = 0
		for info: Dictionary in Events.get_signal_list():
			if StringName(str(info["name"])) == signal_name:
				arguments = (info["args"] as Array).size()
		var callable: Callable = Callable(self, &"_on_event").bind(signal_name)
		callable = callable.unbind(arguments) if arguments > 0 else callable
		var signal_ref: Signal = Signal(Events, signal_name)
		signal_ref.connect(callable)
		_connections.append([signal_ref, callable])
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
	# The autoplay harness reseeds the clock like this before the first tick.
	Sim.rng.reseed(1)
	Sim.tick = 0


## Play input flags one tick at a time until they end or gameplay stops; returns the ticks played. Like the autoplay
## harness with --fast it lets one frame pass after every tick, so that nodes freed during a tick (collected or
## expired items, which hold one of the 32 slots of dropped bonus items) really leave the tree.
func _play(flags: PackedInt32Array) -> int:
	var index: Array[int] = [0]
	GameInput.set_scripted(func(_tick: int) -> int:
		var value: int = flags[index[0]] if index[0] < flags.size() else 0
		index[0] += 1
		return value
	)
	var played: int = 0
	while played < flags.size() and Sim.running:
		Sim.step(1)
		played += 1
		_steps += 1
		if _steps % _yield_every == 0:
			await get_tree().process_frame
	GameInput.clear_scripted()
	return played


func _settle() -> void:
	for i: int in 3:
		await get_tree().process_frame
	while Flow.busy:
		await get_tree().process_frame


func _hero_text() -> String:
	var level: LevelBase = Game.level
	if level == null or level.player == null:
		return "(no hero)"
	var hero: PlayerBase = level.player
	var nearest: String = ""
	var best: int = 1 << 30
	for entity: SimEntity in level.get_kind(Defs.Kind.ENEMY):
		var enemy: EnemyBase = entity as EnemyBase
		if enemy == null or enemy.dead or not enemy.awake:
			continue
		var distance: int = absi(enemy.sim_pos.x - hero.sim_pos.x) + absi(enemy.sim_pos.y - hero.sim_pos.y)
		if distance < best:
			best = distance
			nearest = " | %s dx%d dy%d" % [enemy.get_script().get_global_name(), enemy.sim_pos.x - hero.sim_pos.x,
				enemy.sim_pos.y - hero.sim_pos.y]
	if OS.get_environment("W1_SHOTS") != "":
		for entity: SimEntity in level.get_kind(Defs.Kind.HERO_PROJECTILE):
			nearest += " <axe %d,%d>" % [entity.sim_pos.x - hero.sim_pos.x, entity.sim_pos.y - hero.sim_pos.y]
	if OS.get_environment("W1_ITEMS") != "":
		for entity: SimEntity in level.get_kind(Defs.Kind.COLLECTIBLE):
			var item: CollectibleBase = entity as CollectibleBase
			if item != null and not item.collected and (item.item_id == &"items/giant_bonus" or item.dropped):
				nearest += " [%s %d,%d v%d]" % [String(item.item_id).get_file(), item.sim_pos.x, item.sim_pos.y,
					item.yvel]
	return "x%5d y%5d c%3d r%3d st%d v(%d,%d) h%d w%d%s%s" % [hero.sim_pos.x, hero.sim_pos.y, hero.sim_pos.x >> 4,
		(hero.sim_pos.y - 1) >> 4, hero.state, hero.xvel, hero.yvel, Game.hearts, Game.weapon,
		" DEAD" if hero.dead else "", nearest]


func _count(signal_name: StringName) -> int:
	return int(_counts.get(signal_name, 0))


func _on_event(signal_name: StringName) -> void:
	_counts[signal_name] = _count(signal_name) + 1
	if signal_name != &"item_collected":
		_log.append(String(signal_name).replace("player_", "").replace("hidden_spot_", "spot_"))
	else:
		_log.append("+")
