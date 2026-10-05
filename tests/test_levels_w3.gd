extends TestCase
## World 3 level checks beyond the route proofs (owner: level design w3): Frost Summit (w3_l1), Blizzard Pass
## (w3_l1b) and Crystal Grotto (w3_l2). The routes (main routes, the valley under the icicle overhang, the Blizzard
## Pass pond, every weapon a run can bring), the links and the validity of the files are checked by the campaign
## suite, tests/test_campaign_routes.gd. The two Blizzard Pass review fixes are guarded here: a pond death restarts at
## a checkpoint on every way to the pond, and the giant bonus of the big spot by the hut cannot land past the exit.

const W3_L1: StringName = &"w3_l1"
const W3_L1B: StringName = &"w3_l1b"
const W3_L2: StringName = &"w3_l2"
## Logical view of the 1280 x 720 game window (integer scale 2).
const VIEW: Vector2i = Vector2i(Tuning.VIEW_W, Tuning.VIEW_H)
const ROUTE_DIR: String = "res://tools/autoplay/routes/"

## Events counted since the level started (only the tests that play inputs watch them).
var _counts: Dictionary = {}
var _exits: Array[StringName] = []
var _connections: Array[Array] = []


func after_each() -> void:
	for connection: Array in _connections:
		var signal_ref: Signal = connection[0]
		if signal_ref.is_connected(connection[1]):
			signal_ref.disconnect(connection[1])
	_connections.clear()
	_counts.clear()
	_exits.clear()
	GameInput.clear_scripted()
	Sim.manual = false
	Sim.stop()
	if get_tree().current_scene != null:
		get_tree().current_scene.free()
		get_tree().current_scene = null
	Flow.current_screen = Flow.SCREEN_BOOT


## A hero who touches a checkpoint while standing stores his own feet point as the respawn point. The whole range in
## which his box can overlap a checkpoint should lie over floor, so that this point is on the ground (a touch in the
## air stores the checkpoint's own point, CheckpointBase.activate).
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


## Every way to the frozen pond passes a checkpoint: the Beginner route jumps from the eagle ledge straight to the
## shore (past pillar 4), the Expert route hops over the pillars. A fall into the pond then puts the hero back at
## the last checkpoint (the ledge's or pillar 4's), never at the level start.
func test_a_pond_death_restarts_at_a_checkpoint() -> void:
	for mode: int in [Defs.Difficulty.BEGINNER, Defs.Difficulty.EXPERT]:
		var file: String = "w3_l1b.expert.inputs" if mode == Defs.Difficulty.EXPERT else "w3_l1b.inputs"
		Game.new_game(mode)
		_watch_events()
		await _start(W3_L1B)
		var start: Vector2i = Game.level.player.sim_pos
		# The route up to the shore (its "# B4" section starts there), then straight on into the pond.
		var text: String = FileAccess.get_file_as_string(ROUTE_DIR + file)
		var head: String = text.substr(0, text.find("
# B4"))
		var played: int = _run(Autoplay.parse_inputs(head))
		assert_true(Game.has_checkpoint, "%s: a checkpoint was touched before the shore" % file)
		var checkpoint: Vector2i = Game.checkpoint_pos
		assert_true(checkpoint.x >= 59 * 16 and checkpoint.x < 65 * 16,
				"%s: the checkpoint is on pillar 4 or the ledge (%s)" % [file, checkpoint])
		# Walk on until he falls into the pond, then let go of the keys.
		while _count(&"player_died") == 0 and Game.level != null and played < 4000:
			played += _run(PackedInt32Array([Defs.IN_RIGHT]))
		played += _run(Autoplay.parse_inputs("200:"))
		assert_eq(_count(&"player_died"), 1, "%s: the hero fell into the pond" % file)
		assert_eq(_count(&"level_respawned"), 1, "%s: and came back" % file)
		var hero: PlayerBase = Game.level.player
		assert_true(absi(hero.sim_pos.x - checkpoint.x) <= 4 and hero.sim_pos.y == checkpoint.y,
				"%s: he is back at the checkpoint %s (at %s), not at the start %s" % [file, checkpoint, hero.sim_pos,
				start])
		print("    %s: checkpoint %s, respawned at %s after %d ticks" % [file, checkpoint, hero.sim_pos, played])
		after_each()


## The big spot by the hut lies far enough before the exit totem: even when its giant bonus bounces off the hero's
## head toward the exit (here it does, with the default seed), it comes down before the exit, and walking on to the
## exit collects it.
func test_the_hut_giant_lands_before_the_exit() -> void:
	Game.new_game(Defs.Difficulty.BEGINNER)
	_watch_events()
	await _start(W3_L1B)
	var text: String = FileAccess.get_file_as_string(ROUTE_DIR + "w3_l1b.inputs")
	# The route up to the big spot, then four low strikes standing right under it, and wait.
	var head: String = text.substr(0, text.rfind("
10:R,8:,10:DF"))
	var played: int = _run(Autoplay.parse_inputs(head + "
15:R,9:,10:DF,6:,10:DF,6:,10:DF,6:,10:DF,2:"))
	var level: LevelBase = Game.level
	var exit_left: int = 0
	for entity: SimEntity in level.get_kind(Defs.Kind.EXIT):
		exit_left = entity.sim_pos.x - entity.box_xo
	var giant: GiantBonus = null
	for entity: SimEntity in level.get_kind(Defs.Kind.COLLECTIBLE):
		if entity is GiantBonus and (entity as GiantBonus).dropped:
			giant = entity as GiantBonus
	assert_not_null(giant, "the big spot dropped its giant bonus")
	if giant == null:
		return
	var points: int = giant.points
	var spot_x: int = giant.sim_pos.x
	played += _run(Autoplay.parse_inputs("80:"))
	assert_true(is_instance_valid(giant) and not giant.collected, "the giant bounced off the hero's head")
	if not is_instance_valid(giant):
		return
	assert_true(giant.sim_pos.x > spot_x, "... toward the exit (x %d, spot %d)" % [giant.sim_pos.x, spot_x])
	assert_true(giant.sim_pos.x + giant.box_xo < exit_left, "it lies before the exit totem (x %d, exit from %d)" % [
		giant.sim_pos.x, exit_left])
	print("    the giant of the hut spot: dropped at x %d, lies at x %d, the exit totem starts at x %d" % [spot_x,
		giant.sim_pos.x, exit_left])
	var score: int = Game.score
	played += _run(Autoplay.parse_inputs("90:R"))
	assert_true(not is_instance_valid(giant) or giant.collected, "walking to the exit collects it")
	assert_true(Game.score >= score + points, "its points are paid")
	assert_eq(_exits, [&"exit"] as Array[StringName], "and the hero leaves through the exit (%d ticks)" % played)


## Play input flags one tick after the other until they end or the level is left; returns the ticks played.
func _run(flags: PackedInt32Array) -> int:
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
	GameInput.clear_scripted()
	return played


func _watch_events() -> void:
	if not _connections.is_empty():
		return
	for info: Dictionary in Events.get_signal_list():
		var signal_name: StringName = StringName(str(info["name"]))
		var callable: Callable = _on_event.bind(signal_name)
		var arguments: int = (info["args"] as Array).size()
		_connect(Signal(Events, signal_name), callable.unbind(arguments) if arguments > 0 else callable)
	_connect(Events.exit_reached, func(exit_kind: StringName) -> void: _exits.append(exit_kind))


func _connect(signal_ref: Signal, callable: Callable) -> void:
	signal_ref.connect(callable)
	_connections.append([signal_ref, callable])


func _count(signal_name: StringName) -> int:
	return int(_counts.get(signal_name, 0))


func _on_event(signal_name: StringName) -> void:
	_counts[signal_name] = _count(signal_name) + 1


## Enter `level_id` through Flow like the game does, with the clock under the test's control.
func _start(level_id: StringName) -> void:
	Sim.manual = true
	await get_tree().process_frame
	while Flow.busy:
		await get_tree().process_frame
	Flow.start_level(level_id, Defs.Transition.NONE)
	for i: int in 3:
		await get_tree().process_frame
	while Flow.busy:
		await get_tree().process_frame
	assert_eq(Flow.current_screen, Flow.SCREEN_LEVEL)
	assert_eq(Game.level.level_id, level_id)
	var level: Level = Game.level as Level
	if level != null:
		level.set_view_size(VIEW * Tuning.ART_SCALE)
