extends TestCase
## World 2 campaign levels (owner: level design w2): Echo Caverns (w2_l1), Bone Gorge (w2_l2) and its linked boss
## sub-stage Brute's Den (w2_l2b).
##
## Each route in tools/autoplay/routes is replayed through Flow and the real level scene from a fresh run with the
## default seed, tick for tick as the windowed autoplay plays it, and must finish the level without losing a life.
## One process frame is awaited per tick, as the windowed autoplay renders one frame per tick (--fast), so queued
## frees and anything else that happens between frames behave exactly as in the recorded runs.
##
## The Brute's den is fought with the club on Beginner (a run started by level code) and with the HAMMER on Expert:
## the campaign hero carries the hammer of Echo Caverns into Bone Gorge, and a charged hammer strike (4 x 30) is
## the strongest hit the Brute can meet.

const W2_L1: StringName = &"w2_l1"
const W2_L2: StringName = &"w2_l2"
const W2_L2B: StringName = &"w2_l2b"
const ROUTES: String = "res://tools/autoplay/routes/"
## Logical view of the autoplay window (1280 x 720 at integer scale 2): enemies wake by the view.
const VIEW: Vector2i = Vector2i(Tuning.VIEW_W, Tuning.VIEW_H)
const COUNTED: Array[StringName] = [&"exit_reached", &"player_died", &"level_respawned", &"checkpoint_activated",
		&"enemy_killed", &"hidden_spot_opened", &"secret_found", &"boss_started", &"boss_defeated", &"exit_unlocked",
		&"player_hurt", &"gate_used", &"level_completed", &"level_started"]

var _counts: Dictionary = {}
var _connections: Array[Array] = []
## Indices of the letters G R U B S collected since the last _start(), and how often the jackpot was taken.
var _letters: Dictionary = {}
var _jackpots: int = 0
## Head hits the boss took since the last _start(), and whether the hero carried and flew the glider.
var _boss_hits: int = 0
var _glider_carried: bool = false
var _glider_flown: bool = false


func after_each() -> void:
	for connection: Array in _connections:
		var signal_ref: Signal = connection[0]
		if signal_ref.is_connected(connection[1]):
			signal_ref.disconnect(connection[1])
	_connections.clear()
	_counts.clear()
	_letters.clear()
	_jackpots = 0
	_boss_hits = 0
	_glider_carried = false
	_glider_flown = false
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
	for level_id: StringName in [W2_L1, W2_L2, W2_L2B]:
		var problems: Array[Dictionary] = validator.problems_of(Levels.get_level_path(level_id))
		var lines: PackedStringArray = PackedStringArray()
		for problem: Dictionary in problems:
			lines.append(LevelValidator.format_problem(problem))
		assert_eq(problems.size(), 0, "%s: no error and no warning\n%s" % [level_id, "\n".join(lines)])


func test_the_world_2_links() -> void:
	for level_id: StringName in [W2_L1, W2_L2, W2_L2B]:
		assert_true(Levels.has_level(level_id), "%s exists" % level_id)
	assert_eq(str(Levels.get_value(W2_L1, "kind", "")), "main")
	assert_eq(int(Levels.get_value(W2_L1, "order", 0)), 30)
	assert_eq(str(Levels.get_value(W2_L1, "bonus", "")), "bonus_b", "the warp of Echo Caverns leads to bonus stage B")
	assert_eq(str(Levels.get_value(W2_L2, "kind", "")), "main")
	assert_eq(int(Levels.get_value(W2_L2, "order", 0)), 40)
	assert_eq(Levels.next_level(W2_L2, Defs.Difficulty.BEGINNER), W2_L2B, "Bone Gorge continues in the Brute's den")
	assert_false(bool(Levels.get_value(W2_L2, "tally", true)), "no tally between the two halves")
	assert_eq(str(Levels.get_value(W2_L2B, "kind", "")), "sub")
	for difficulty: int in [Defs.Difficulty.BEGINNER, Defs.Difficulty.EXPERT]:
		var campaign: Array[StringName] = Levels.get_campaign(difficulty)
		assert_true(campaign.find(W2_L1) >= 0 and campaign.find(W2_L1) < campaign.find(W2_L2),
				"Echo Caverns comes before Bone Gorge")
		assert_false(campaign.has(W2_L2B), "the sub-stage has no stop of its own on the map")
	assert_eq(Levels.find_by_password("echo"), {"level_id": W2_L1, "difficulty": Defs.Difficulty.BEGINNER})
	assert_eq(Levels.find_by_password("B4TS"), {"level_id": W2_L1, "difficulty": Defs.Difficulty.EXPERT})
	assert_eq(Levels.find_by_password("B0NE"), {"level_id": W2_L2, "difficulty": Defs.Difficulty.BEGINNER})
	assert_eq(Levels.find_by_password("GL1D"), {"level_id": W2_L2, "difficulty": Defs.Difficulty.EXPERT})
	assert_eq(Levels.find_by_password("R0AR"), {"level_id": W2_L2B, "difficulty": Defs.Difficulty.BEGINNER})
	assert_eq(Levels.find_by_password("F1ST"), {"level_id": W2_L2B, "difficulty": Defs.Difficulty.EXPERT})


func test_echo_caverns_beginner_route() -> void:
	await _echo_caverns(Defs.Difficulty.BEGINNER, "w2_l1.inputs")


func test_echo_caverns_expert_route() -> void:
	await _echo_caverns(Defs.Difficulty.EXPERT, "w2_l1.expert.inputs")


func test_bone_gorge_and_the_brute_beginner_route() -> void:
	await _bone_gorge(Defs.Difficulty.BEGINNER, "w2_l2.inputs", "w2_l2b.inputs")


func test_bone_gorge_and_the_brute_expert_route() -> void:
	await _bone_gorge(Defs.Difficulty.EXPERT, "w2_l2.expert.inputs", "w2_l2b.expert.inputs")


func test_the_expert_spawn_sets_are_tougher() -> void:
	for level_id: StringName in [W2_L1, W2_L2]:
		var counts: Array[int] = []
		for difficulty: int in [Defs.Difficulty.BEGINNER, Defs.Difficulty.EXPERT]:
			Game.new_game(difficulty)
			await _start(level_id)
			counts.append(Game.level.get_kind(Defs.Kind.ENEMY).size())
			after_each()
		assert_true(counts[1] > counts[0], "%s: more enemies on Expert (%d) than on Beginner (%d)" % [
			level_id, counts[1], counts[0]])


func test_the_brute_survives_charged_strikes() -> void:
	# A charged strike does 4 x the weapon power (club 100, hammer 120). The first boss must not fall to one of them
	# on Beginner, nor to two on Expert, and its arena limits must reach the den walls (no safe corner).
	var strongest: int = Tuning.WEAPON_POWER[Defs.Weapon.HAMMER] * Tuning.CHARGE_MULTIPLIER
	for difficulty: int in [Defs.Difficulty.BEGINNER, Defs.Difficulty.EXPERT]:
		Game.new_game(difficulty)
		await _start(W2_L2B)
		var bosses: Array[SimEntity] = Game.level.get_kind(Defs.Kind.BOSS)
		assert_eq(bosses.size(), 1, "one Brute in %s" % Defs.difficulty_name(difficulty))
		var brute: Brute = bosses[0] as Brute if bosses.size() == 1 else null
		assert_not_null(brute)
		if brute != null:
			var strikes: int = 2 if difficulty == Defs.Difficulty.EXPERT else 1
			assert_true(brute.max_hp > strikes * strongest, "%s Brute hp %d survives %d charged hammer strike(s)" % [
					Defs.difficulty_name(difficulty), brute.max_hp, strikes])
			assert_eq(brute.left_x, 42 * Tuning.TILE + Tuning.TILE / 2, "left limit one column inside the den wall")
			assert_eq(brute.right_x, 59 * Tuning.TILE + Tuning.TILE / 2, "right limit one column inside the den wall")
		after_each()


# =================================================================================================================
# Routes
# =================================================================================================================

func _echo_caverns(difficulty: int, route: String) -> void:
	Game.new_game(difficulty)
	await _start(W2_L1)
	var played: int = await _replay(ROUTES + route)
	_log(W2_L1, difficulty, played)
	assert_eq(_count(&"exit_reached"), 1, "the exit was reached after %d ticks" % played)
	assert_eq(_count(&"player_died"), 0, "no life lost")
	assert_eq(Game.lives, Tuning.LIVES_START)
	assert_eq(Game.weapon, Defs.Weapon.HAMMER, "the hammer was picked up")
	assert_eq(_count(&"secret_found"), 4, "the upper vein, the crystal cache, the bone vault and the warp nook")
	assert_eq(_count(&"gate_used"), 4, "two gate round trips (crystal cache and bone vault)")
	assert_eq(_letters.keys().size(), 5, "all five letters G-R-U-B-S were collected: %s" % [_letters.keys()])
	assert_eq(_jackpots, 1, "the five letters dropped the jackpot")
	assert_eq(Game.letters, 0, "the word is cleared after the jackpot")
	assert_true(_count(&"checkpoint_activated") >= 4, "checkpoints: %d" % _count(&"checkpoint_activated"))
	assert_true(_count(&"hidden_spot_opened") >= 25, "hidden spots opened: %d" % _count(&"hidden_spot_opened"))
	assert_true(played >= 2200 and played <= 4400, "the route takes %d ticks" % played)
	assert_true(Game.completion_percent() >= 80, "completion %d %%" % Game.completion_percent())
	await _settle()
	assert_eq(Flow.current_screen, Flow.SCREEN_TALLY, "the exit leads to the tally")


func _bone_gorge(difficulty: int, route_gorge: String, route_den: String) -> void:
	Game.new_game(difficulty)
	await _start(W2_L2)
	var gorge_items: int = Game.items_total
	var gorge_spots: int = Game.spots_total
	var played: int = await _replay(ROUTES + route_gorge)
	_log(W2_L2, difficulty, played)
	assert_eq(_count(&"exit_reached"), 1, "the far rim of the gorge was reached after %d ticks" % played)
	assert_eq(_count(&"player_died"), 0, "no life lost in the gorge")
	assert_true(_glider_carried and _glider_flown, "the hang-glider was taken and flown over the gorge")
	for index: int in [0, 1, 2, 4]:
		assert_true(_letters.has(index), "letter %d (G R U _ S) collected in Bone Gorge: %s" % [index, _letters.keys()])
	assert_true(_count(&"secret_found") >= 1 and _count(&"gate_used") == 2, "the bone cave behind the hole gate")
	await _settle()
	# tally = false: the exit leads straight into the sub-stage, progress carried over.
	assert_eq(Flow.current_screen, Flow.SCREEN_LEVEL, "no tally after the first half")
	assert_eq(Game.level_id, W2_L2B, "the Brute's den follows")
	assert_false(Game.has_glider, "the glider is gone at the level end")
	assert_true(Game.items_total > gorge_items and Game.spots_total > gorge_spots,
			"the den's items and spots add to the gorge's completion totals")
	var level: Level = Game.level as Level
	assert_not_null(level)
	if level != null:
		level.set_view_size(VIEW * Tuning.ART_SCALE)
	_counts.clear()
	if difficulty == Defs.Difficulty.EXPERT:
		Game.set_weapon(Defs.Weapon.HAMMER)
	var played_den: int = await _replay(ROUTES + route_den)
	_log(W2_L2B, difficulty, played_den)
	assert_eq(_count(&"boss_started"), 1)
	assert_eq(_count(&"boss_defeated"), 1, "the Brute was beaten")
	var min_hits: int = 3 if difficulty == Defs.Difficulty.EXPERT else 2
	assert_true(_boss_hits >= min_hits, "the Brute took %d head hits (at least %d)" % [_boss_hits, min_hits])
	assert_eq(_count(&"exit_unlocked"), 1, "its fire-starter lit the exit totem")
	assert_eq(_count(&"exit_reached"), 1, "the exit was reached after %d ticks" % played_den)
	assert_eq(_count(&"player_died"), 0, "no life lost in the den")
	assert_eq(Game.lives, Tuning.LIVES_START)
	assert_true(played + played_den >= 2200 and played + played_den <= 4400,
			"both halves take %d ticks" % (played + played_den))
	await _settle()
	assert_eq(Flow.current_screen, Flow.SCREEN_TALLY, "the tally ends Bone Gorge")


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
	_watch(Events.item_collected, _on_item)
	_watch(Events.enemy_hit, _on_enemy_hit)
	_watch(Events.glider_state_changed, _on_glider)
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


## Play an input file one tick (and one frame) at a time until it ends or gameplay stops; returns the ticks played.
func _replay(path: String) -> int:
	assert_true(FileAccess.file_exists(path), "%s exists" % path)
	var flags: PackedInt32Array = Autoplay.parse_inputs(FileAccess.get_file_as_string(path))
	assert_true(flags.size() > 100, "%s has an input script" % path)
	var index: Array[int] = [0]
	GameInput.set_scripted(func(_tick: int) -> int:
		var value: int = flags[index[0]] if index[0] < flags.size() else 0
		index[0] += 1
		return value
	)
	var played: int = 0
	var level: LevelBase = Game.level
	while played < flags.size() and Sim.running and Game.level == level:
		Sim.step(1)
		played += 1
		await get_tree().process_frame
	GameInput.clear_scripted()
	return played


func _settle() -> void:
	for i: int in 3:
		await get_tree().process_frame
	while Flow.busy:
		await get_tree().process_frame


func _log(level_id: StringName, difficulty: int, played: int) -> void:
	print("    %s %s: %d ticks (%.1f s), score %d, completion %d %%, spots %d / %d, items %d / %d, hearts %d" % [
		level_id, Defs.difficulty_name(difficulty), played, played / 24.275, Game.score, Game.completion_percent(),
		Game.spots_opened, Game.spots_total, Game.items_collected, Game.items_total, Game.hearts])


func _count(signal_name: StringName) -> int:
	return int(_counts.get(signal_name, 0))


func _watch(signal_ref: Signal, callable: Callable) -> void:
	if not signal_ref.is_connected(callable):
		signal_ref.connect(callable)
		_connections.append([signal_ref, callable])


func _on_item(item_id: StringName, index: int, _points: int, _pos: Vector2i) -> void:
	if item_id == &"items/letter":
		_letters[index] = true
	elif item_id == &"items/jackpot":
		_jackpots += 1


func _on_enemy_hit(enemy: EnemyBase, _power: int) -> void:
	if enemy is BossBase:
		_boss_hits += 1


func _on_glider(carrying: bool, gliding: bool) -> void:
	_glider_carried = _glider_carried or carrying
	_glider_flown = _glider_flown or gliding


func _on_event(signal_name: StringName) -> void:
	_counts[signal_name] = _count(signal_name) + 1
