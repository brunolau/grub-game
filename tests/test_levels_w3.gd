extends TestCase
## World 3 campaign levels (owner: level design w3): Frost Summit (w3_l1) with its linked blizzard sub-stage
## Blizzard Pass (w3_l1b), and Crystal Grotto (w3_l2), the last level of a Beginner run.
##
## Each route in tools/autoplay/routes is replayed through Flow and the real level scene from a fresh run with the
## default seed, tick for tick as the windowed autoplay (a flow script with `play_file`) plays it, and must finish
## the level without losing a life. Frost Summit's exit leads straight into Blizzard Pass (no tally), exactly as in
## the game, and the second route is played there.

const W3_L1: StringName = &"w3_l1"
const W3_L1B: StringName = &"w3_l1b"
const W3_L2: StringName = &"w3_l2"
const ROUTES: String = "res://tools/autoplay/routes/"
## Logical view of the autoplay window (1280 x 720 at integer scale 2): enemies wake by the view.
const VIEW: Vector2i = Vector2i(Tuning.VIEW_W, Tuning.VIEW_H)
## Blizzard Pass pond: first column of the far shore and the row of its surface (the floes are 5 wide, the gaps 2).
const POND_FAR_SHORE_COL: int = 88
const POND_SHORE_ROW: int = 26
## Frost Summit: last column of the pond just past the icicle overhang.
const VALLEY_POND_LAST_COL: int = 168
const COUNTED: Array[StringName] = [&"exit_reached", &"player_died", &"level_respawned", &"checkpoint_activated",
		&"enemy_killed", &"hidden_spot_opened", &"secret_found", &"player_hurt", &"level_completed",
		&"item_collected"]

var _counts: Dictionary = {}
var _connections: Array[Array] = []
var _max_wind: int = 0


func after_each() -> void:
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
	for level_id: StringName in [W3_L1, W3_L1B, W3_L2]:
		var problems: Array[Dictionary] = validator.problems_of(Levels.get_level_path(level_id))
		var lines: PackedStringArray = PackedStringArray()
		for problem: Dictionary in problems:
			lines.append(LevelValidator.format_problem(problem))
		assert_eq(problems.size(), 0, "%s: no error and no warning\n%s" % [level_id, "\n".join(lines)])


func test_the_world_3_links() -> void:
	for level_id: StringName in [W3_L1, W3_L1B, W3_L2]:
		assert_true(Levels.has_level(level_id), "%s exists" % level_id)
		assert_eq(str(Levels.get_value(level_id, "biome", "")), "ice")
		assert_eq(int(Levels.get_value(level_id, "world", 0)), 3)
	assert_eq(str(Levels.get_value(W3_L1, "kind", "")), "main")
	assert_eq(int(Levels.get_value(W3_L1, "order", 0)), 50)
	assert_false(bool(Levels.get_value(W3_L1, "tally", true)), "no tally between the summit and the blizzard")
	assert_eq(str(Levels.get_value(W3_L1B, "kind", "")), "sub")
	assert_ne(str(Levels.get_value(W3_L1B, "wind", "")), "", "the blizzard half has a wind script")
	assert_eq(str(Levels.get_value(W3_L2, "kind", "")), "main")
	assert_eq(int(Levels.get_value(W3_L2, "order", 0)), 60)
	assert_eq(str(Levels.get_value(W3_L2, "bonus", "")), "bonus_c", "the warp of the grotto leads to bonus stage C")
	assert_true(Levels.has_level(&"bonus_c"), "bonus stage C exists")
	for difficulty: int in [Defs.Difficulty.BEGINNER, Defs.Difficulty.EXPERT]:
		assert_eq(Levels.next_level(W3_L1, difficulty), W3_L1B, "the summit continues in the blizzard")
		assert_eq(Levels.next_level(W3_L1B, difficulty), W3_L2, "after the blizzard the campaign goes on")
		var campaign: Array[StringName] = Levels.get_campaign(difficulty)
		assert_true(campaign.find(W3_L1) >= 0 and campaign.find(W3_L1) < campaign.find(W3_L2),
				"Frost Summit comes before Crystal Grotto")
		assert_false(campaign.has(W3_L1B), "the sub-stage has no stop of its own on the map")
	# Crystal Grotto is the last level of a Beginner run: every later campaign level is expert only.
	assert_eq(Levels.next_level(W3_L2, Defs.Difficulty.BEGINNER), &"", "no Beginner level after the grotto")
	var later: int = 0
	for level_id: StringName in Levels.get_campaign(Defs.Difficulty.EXPERT):
		if int(Levels.get_value(level_id, "order", 0)) > 60:
			later += 1
			assert_false(Levels.is_available(level_id, Defs.Difficulty.BEGINNER), "%s is expert only" % level_id)
	assert_eq(Levels.has_locked_successor(W3_L2, Defs.Difficulty.BEGINNER), later > 0,
			"a Beginner run ends at the expert wall when expert levels follow")
	assert_eq(Levels.find_by_password("sn0w"), {"level_id": W3_L1, "difficulty": Defs.Difficulty.BEGINNER})
	assert_eq(Levels.find_by_password("YET1"), {"level_id": W3_L1, "difficulty": Defs.Difficulty.EXPERT})
	assert_eq(Levels.find_by_password("GALE"), {"level_id": W3_L1B, "difficulty": Defs.Difficulty.BEGINNER})
	assert_eq(Levels.find_by_password("BL1Z"), {"level_id": W3_L1B, "difficulty": Defs.Difficulty.EXPERT})
	assert_eq(Levels.find_by_password("GR0T"), {"level_id": W3_L2, "difficulty": Defs.Difficulty.BEGINNER})
	assert_eq(Levels.find_by_password("B00M"), {"level_id": W3_L2, "difficulty": Defs.Difficulty.EXPERT})


func test_frost_summit_and_blizzard_pass_beginner_route() -> void:
	await _frost_summit(Defs.Difficulty.BEGINNER, "w3_l1.inputs", "w3_l1b.inputs")


func test_frost_summit_and_blizzard_pass_expert_route() -> void:
	await _frost_summit(Defs.Difficulty.EXPERT, "w3_l1.expert.inputs", "w3_l1b.expert.inputs")


func test_crystal_grotto_beginner_route() -> void:
	await _crystal_grotto(Defs.Difficulty.BEGINNER, "w3_l2.inputs")


func test_crystal_grotto_expert_route() -> void:
	await _crystal_grotto(Defs.Difficulty.EXPERT, "w3_l2.expert.inputs")


func test_the_expert_spawn_sets_are_tougher() -> void:
	for level_id: StringName in [W3_L1, W3_L1B, W3_L2]:
		var counts: Array[int] = []
		for difficulty: int in [Defs.Difficulty.BEGINNER, Defs.Difficulty.EXPERT]:
			Game.new_game(difficulty)
			await _start(level_id)
			counts.append(Game.level.get_kind(Defs.Kind.ENEMY).size())
			after_each()
		assert_true(counts[1] > counts[0], "%s: more enemies on Expert (%d) than on Beginner (%d)" % [
			level_id, counts[1], counts[0]])


## The main routes go through the grotto under the Blizzard Pass pond (a secret); the pond itself must be crossable
## on its ice floes in a lull on both difficulties.
func test_the_blizzard_pond_can_be_crossed_on_its_floes() -> void:
	for difficulty: int in [Defs.Difficulty.BEGINNER, Defs.Difficulty.EXPERT]:
		var expert: bool = difficulty == Defs.Difficulty.EXPERT
		Game.new_game(difficulty)
		await _start(W3_L1B)
		var played: int = _replay_side("w3_l1b.expert.inputs" if expert else "w3_l1b.inputs", "# B4",
				"w3_l1b.pond.expert.inputs" if expert else "w3_l1b.pond.inputs")
		var hero: PlayerBase = Game.level.player
		var label: String = Defs.difficulty_name(difficulty)
		assert_eq(_count(&"player_died"), 0, "%s: no life lost on the floes (%d ticks)" % [label, played])
		assert_true(hero != null and hero.sim_pos.x >= POND_FAR_SHORE_COL * Tuning.TILE
				and hero.sim_pos.y == POND_SHORE_ROW * Tuning.TILE,
				"%s: the hero stands on the far shore: %s" % [label, hero.sim_pos if hero != null else null])
		after_each()


## The main routes take the sky route over the icicle overhang in Frost Summit; the valley under it (ceiling spikes,
## a walker in front of them, a pond just past them) must be passable too.
func test_the_valley_under_the_icicle_overhang() -> void:
	for difficulty: int in [Defs.Difficulty.BEGINNER, Defs.Difficulty.EXPERT]:
		var expert: bool = difficulty == Defs.Difficulty.EXPERT
		Game.new_game(difficulty)
		await _start(W3_L1)
		var played: int = _replay_side("w3_l1.expert.inputs" if expert else "w3_l1.inputs", "# S4",
				"w3_l1.valley.inputs")
		var hero: PlayerBase = Game.level.player
		var label: String = Defs.difficulty_name(difficulty)
		assert_eq(_count(&"player_died"), 0, "%s: no life lost in the valley (%d ticks)" % [label, played])
		assert_true(hero != null and hero.sim_pos.x > (VALLEY_POND_LAST_COL + 1) * Tuning.TILE,
				"%s: the hero is past the pond: %s" % [label, hero.sim_pos if hero != null else null])
		after_each()


## Touching a checkpoint stores the HERO's feet point, also in mid-air (CheckpointBase.activate). So the whole range
## in which his jump / fall box can overlap the checkpoint must lie over floor: a touch above a pit would make every
## respawn fall into it again.
func test_every_checkpoint_is_touched_over_floor() -> void:
	var hero_box: Vector3i = Tuning.HERO_BOX_JUMP_TOP
	for level_id: StringName in [W3_L1, W3_L1B, W3_L2]:
		Game.new_game(Defs.Difficulty.BEGINNER)
		await _start(level_id)
		var grid: TileGrid = Game.level.grid
		var checkpoints: Array = Game.level.get_kind(Defs.Kind.CHECKPOINT)
		assert_true(checkpoints.size() >= 2, "%s has checkpoints" % level_id)
		for entity: SimEntity in checkpoints:
			var left: int = entity.sim_pos.x - entity.box_xo
			var row: int = entity.sim_pos.y >> 4
			var bad: Array[int] = []
			for x: int in range(left - hero_box.x + hero_box.z + 1, left + entity.box_w + hero_box.z):
				if not TileGrid.is_ground(grid.floor_at(x >> 4, row)):
					bad.append(x)
			assert_true(bad.is_empty(), "%s: checkpoint at %s can be touched over a gap at x %s" % [
				level_id, entity.sim_pos, bad])
		after_each()


func test_the_blizzard_blows_harder_on_expert() -> void:
	var peaks: Array[int] = []
	for difficulty: int in [Defs.Difficulty.BEGINNER, Defs.Difficulty.EXPERT]:
		var peak: int = 0
		for entry: String in str(Levels.get_value(W3_L1B, "wind", "", difficulty)).split(","):
			peak = maxi(peak, entry.get_slice(":", 1).to_int())
		peaks.append(peak)
	assert_true(peaks[0] >= 48, "Beginner gusts are strong enough to need a crouch on ice (%d)" % peaks[0])
	assert_true(peaks[1] > peaks[0], "Expert gusts (%d) are stronger than Beginner gusts (%d)" % [peaks[1], peaks[0]])


# =================================================================================================================
# Routes
# =================================================================================================================

func _frost_summit(difficulty: int, route_summit: String, route_pass: String) -> void:
	Game.new_game(difficulty)
	await _start(W3_L1)
	var summit_items: int = Game.items_total
	var summit_spots: int = Game.spots_total
	var played: int = _replay(ROUTES + route_summit)
	_log(W3_L1, difficulty, played)
	assert_eq(_count(&"exit_reached"), 1, "the summit cave was reached after %d ticks" % played)
	assert_eq(_count(&"player_died"), 0, "no life lost on the summit")
	assert_true(_count(&"secret_found") >= 3, "secrets on the way: %d" % _count(&"secret_found"))
	assert_true(_count(&"checkpoint_activated") >= 4, "checkpoints: %d" % _count(&"checkpoint_activated"))
	assert_true(_count(&"hidden_spot_opened") >= 15, "hidden spots opened: %d" % _count(&"hidden_spot_opened"))
	await _settle()
	# tally = false: the exit leads straight into the blizzard, progress carried over.
	assert_eq(Flow.current_screen, Flow.SCREEN_LEVEL, "no tally after the first half")
	assert_eq(Game.level_id, W3_L1B, "Blizzard Pass follows")
	assert_true(Game.items_total > summit_items and Game.spots_total > summit_spots,
			"the pass adds its items and spots to the summit's completion totals")
	var level: Level = Game.level as Level
	assert_not_null(level)
	if level != null:
		level.set_view_size(VIEW * Tuning.ART_SCALE)
	_counts.clear()
	var played_pass: int = _replay(ROUTES + route_pass)
	_log(W3_L1B, difficulty, played_pass)
	assert_eq(_count(&"exit_reached"), 1, "the hut at the end of the pass was reached after %d ticks" % played_pass)
	assert_eq(_count(&"player_died"), 0, "no life lost in the blizzard")
	assert_true(_max_wind >= 40, "the blizzard blew (strongest wind %d)" % _max_wind)
	# Beginner visits the eagle ledge and the pond grotto; the Expert route (stronger gusts) only the grotto.
	assert_true(_count(&"secret_found") >= (2 if difficulty == Defs.Difficulty.BEGINNER else 1),
			"secrets in the pass: %d" % _count(&"secret_found"))
	assert_true(Game.lives >= Tuning.LIVES_START + 1, "no life lost, and the grotto under the pond gave a 1UP: %d" % Game.lives)
	assert_true(played + played_pass >= 2200, "both halves take %d ticks" % (played + played_pass))
	assert_true(Game.completion_percent() >= 70, "completion %d %%" % Game.completion_percent())
	await _settle()
	assert_eq(Flow.current_screen, Flow.SCREEN_TALLY, "the tally ends Frost Summit")


func _crystal_grotto(difficulty: int, route: String) -> void:
	Game.new_game(difficulty)
	await _start(W3_L2)
	var played: int = _replay(ROUTES + route)
	_log(W3_L2, difficulty, played)
	assert_eq(_count(&"exit_reached"), 1, "the skylight exit was reached after %d ticks" % played)
	assert_eq(_count(&"player_died"), 0, "no life lost")
	assert_true(Game.lives >= Tuning.LIVES_START, "no life lost: %d" % Game.lives)
	assert_eq(Game.weapon, Defs.Weapon.BOOMERANG, "the boomerang (swirling axe) was picked up")
	assert_true(_count(&"secret_found") >= 3, "secrets on the way: %d" % _count(&"secret_found"))
	assert_true(_count(&"checkpoint_activated") >= 2, "checkpoints: %d" % _count(&"checkpoint_activated"))
	assert_true(played >= 2200 and played <= 4400, "the route takes %d ticks" % played)
	assert_true(Game.completion_percent() >= 80, "completion %d %%" % Game.completion_percent())
	await _settle()
	assert_eq(Flow.current_screen, Flow.SCREEN_TALLY, "the exit leads to the tally")


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


## Play an input file one tick at a time until it ends or gameplay stops; returns the ticks played.
func _replay(path: String) -> int:
	assert_true(FileAccess.file_exists(path), "%s exists" % path)
	return _replay_text(FileAccess.get_file_as_string(path), path)


## Play a side path: the main route `main` up to (not including) its first line that starts with `marker`, then
## the side route `side` (both file names in ROUTES). Returns the ticks played.
func _replay_side(main: String, marker: String, side: String) -> int:
	for file_name: String in [main, side]:
		assert_true(FileAccess.file_exists(ROUTES + file_name), "%s exists" % file_name)
	var text: PackedStringArray = PackedStringArray()
	var found: bool = false
	for line: String in FileAccess.get_file_as_string(ROUTES + main).split("\n"):
		if line.strip_edges().begins_with(marker):
			found = true
			break
		text.append(line)
	assert_true(found, "%s has the section '%s'" % [main, marker])
	text.append(FileAccess.get_file_as_string(ROUTES + side))
	return _replay_text("\n".join(text), "%s + %s" % [main, side])


func _replay_text(source: String, label: String) -> int:
	var flags: PackedInt32Array = Autoplay.parse_inputs(source)
	assert_true(flags.size() > 100, "%s has an input script" % label)
	var index: Array[int] = [0]
	GameInput.set_scripted(func(_tick: int) -> int:
		var value: int = flags[index[0]] if index[0] < flags.size() else 0
		index[0] += 1
		return value
	)
	var played: int = 0
	_max_wind = 0
	while played < flags.size() and Sim.running:
		Sim.step(1)
		played += 1
		if Game.level != null:
			_max_wind = maxi(_max_wind, Game.level.wind)
	GameInput.clear_scripted()
	return played


func _log(level_id: StringName, difficulty: int, played: int) -> void:
	print("  %s (%s): %d ticks, score %d, completion %d %%, %d item(s), %d spot(s) opened, %d secret(s), %d kill(s), %d hurt(s), %d death(s)" % [
		level_id, Defs.difficulty_name(difficulty), played, Game.score, Game.completion_percent(),
		_count(&"item_collected"), _count(&"hidden_spot_opened"), _count(&"secret_found"), _count(&"enemy_killed"),
		_count(&"player_hurt"), _count(&"player_died")])


func _settle() -> void:
	for i: int in 3:
		await get_tree().process_frame
	while Flow.busy:
		await get_tree().process_frame


func _count(signal_name: StringName) -> int:
	return int(_counts.get(signal_name, 0))


func _on_event(signal_name: StringName) -> void:
	_counts[signal_name] = _count(signal_name) + 1
