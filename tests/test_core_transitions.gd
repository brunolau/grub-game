extends TestCase
## Flow transitions: the shapes of the cover, timed curtain / iris runs, covered actions and the frozen clock.


## Calls Flow.play_covered() from inside its tick and records what the action saw.
class CoverProbe:
	extends SimEntity

	var request_on_tick: int = 1
	var ticks_seen: int = 0
	var action_log: Array[Dictionary] = []

	func _sim_phases() -> PackedInt32Array:
		return PackedInt32Array([Defs.Phase.ENEMIES])

	func _sim_tick(_phase: int) -> void:
		ticks_seen += 1
		if Sim.tick == request_on_tick:
			Flow.play_covered(_record)

	func _record() -> void:
		action_log.append({
			"in_tick": Sim.is_in_tick(), "tick": Sim.tick, "frozen": Sim.frozen,
			"amount": Flow.get_transition_cover().amount, "input": GameInput.enabled,
		})


## Freezes the clock from inside a tick, like a transition requested by gameplay.
class FreezeProbe:
	extends SimEntity

	var ticks_seen: int = 0

	func _sim_phases() -> PackedInt32Array:
		return PackedInt32Array([Defs.Phase.POST])

	func _sim_tick(_phase: int) -> void:
		ticks_seen += 1
		Sim.frozen = true


var _amounts: Array[float] = []


func after_each() -> void:
	Flow.instant_transitions = true
	Flow.transition_speed = 1.0
	Sim.frozen = false
	Sim.stop()
	GameInput.enabled = true


func _sample_cover() -> void:
	_amounts.append(Flow.get_transition_cover().amount)


func _leave_level() -> void:
	Sim.stop()
	if get_tree().current_scene != null:
		get_tree().current_scene.queue_free()
		get_tree().current_scene = null
	Flow.current_screen = Flow.SCREEN_BOOT
	await get_tree().process_frame


func test_cover_shapes_reach_every_pixel() -> void:
	var cover: TransitionCover = TransitionCover.new()
	add_node(cover)
	cover.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	cover.size = Vector2(640.0, 360.0)
	cover.center_focus()
	assert_false(cover.visible, "an open cover is hidden and costs no draw call")
	cover.shape = Defs.Transition.CURTAIN
	assert_almost_eq(cover.get_reach(), 321.0, 0.001, "the curtain meets in the middle column")
	cover.amount = 0.5
	assert_true(cover.visible)
	assert_almost_eq(cover.get_opening(), 160.5, 0.001)
	cover.shape = Defs.Transition.IRIS
	var corner: float = Vector2(320.0, 180.0).length() + TransitionCover.REACH_MARGIN
	assert_almost_eq(cover.get_reach(), corner, 0.001, "an open iris clears the farthest corner")
	cover.focus = Vector2(100.0, 300.0)
	assert_almost_eq(cover.get_reach(), Vector2(540.0, 300.0).length() + TransitionCover.REACH_MARGIN, 0.001,
		"an off-centre iris reaches the opposite corner")
	assert_almost_eq(cover.get_reach() * (1.0 - cover.amount_for_opening(44.0)), 44.0, 0.001)
	cover.amount = 2.0
	assert_eq(cover.amount, 1.0, "amount is clamped")
	assert_almost_eq(cover.get_opening(), 0.0, 0.001, "a closed cover has no opening")
	assert_eq(cover.amount_for_opening(10000.0), 0.0)


func test_curtain_into_a_level_is_timed_and_holds_the_clock() -> void:
	Flow.instant_transitions = false
	Flow.transition_speed = 1.0
	_amounts.clear()
	get_tree().process_frame.connect(_sample_cover)
	Game.new_game(Defs.Difficulty.BEGINNER)
	Flow.start_level(&"test_example")
	assert_true(Flow.busy, "the transition runs")
	assert_eq(Flow.get_transition_cover().shape, Defs.Transition.CURTAIN)
	await Flow.transition_covered
	assert_eq(Flow.get_transition_cover().amount, 1.0, "fully covered before the scene changes")
	await Flow.screen_changed
	assert_true(Sim.running, "the level started its clock")
	assert_true(Sim.frozen, "but no tick runs while the curtain hides the level")
	var tick_before: int = Sim.tick
	await Flow.transition_finished
	get_tree().process_frame.disconnect(_sample_cover)
	assert_eq(Sim.tick, tick_before, "no tick ran behind the curtain")
	assert_false(Sim.frozen)
	assert_false(Flow.busy)
	assert_eq(Flow.get_transition_cover().amount, 0.0)
	assert_false(Flow.get_transition_cover().visible)
	var partial: int = 0
	for amount: float in _amounts:
		if amount > 0.0 and amount < 1.0:
			partial += 1
	assert_true(partial >= 2, "the curtain moved through intermediate frames (%s)" % str(_amounts))
	await _leave_level()


func test_iris_closes_on_the_hero() -> void:
	var level: LevelBase = make_level(PackedStringArray([
		"....................", "....................", "....................", "####################",
	]))
	var hero: PlayerBase = PlayerBase.new()
	place(level, hero, Vector2i(100, 48))
	assert_eq(level.player, hero)
	Flow.instant_transitions = false
	Flow.transition_speed = 6.0
	var expected: Vector2 = Vector2(200.0, 96.0 - float(hero.box_h))
	var foci: Array[Vector2] = []
	var sample: Callable = func() -> void: foci.append(Flow.get_transition_cover().focus)
	get_tree().process_frame.connect(sample)
	var seen_amount: Array[float] = []
	await Flow.play_covered(func() -> void: seen_amount.append(Flow.get_transition_cover().amount),
		Defs.Transition.IRIS)
	get_tree().process_frame.disconnect(sample)
	assert_eq(seen_amount, [1.0] as Array[float], "the action ran once, fully covered")
	assert_false(foci.is_empty())
	var on_hero: bool = true
	for focus: Vector2 in foci:
		on_hero = on_hero and focus.is_equal_approx(expected)
	assert_true(on_hero, "the iris is centred on the middle of the hero %s: %s" % [expected, str(foci)])
	assert_eq(Flow.get_transition_cover().amount, 0.0)


func test_covered_action_runs_between_ticks() -> void:
	make_flat_level(40, 12, 10)
	var probe: CoverProbe = CoverProbe.new()
	probe.request_on_tick = 2
	add_node(probe)
	Sim.start(1)
	Sim.step(4)
	assert_eq(probe.ticks_seen, 4)
	assert_eq(probe.action_log.size(), 1, "the action ran once")
	if probe.action_log.size() != 1:
		return
	var seen: Dictionary = probe.action_log[0]
	assert_false(seen["in_tick"], "never inside a tick")
	assert_eq(seen["tick"], 2, "right after the tick that asked for it")
	assert_true(seen["frozen"], "the clock stands still while covered")
	assert_eq(seen["amount"], 1.0, "the screen is fully covered")
	assert_false(seen["input"], "device input is ignored while covered")
	assert_false(Sim.frozen)
	assert_true(GameInput.enabled)
	assert_false(Flow.busy)


func test_covered_action_may_change_the_scene() -> void:
	var ran: Array[bool] = []
	Flow.play_covered(func() -> void:
		ran.append(true)
		Flow.goto_screen(&"no_such_screen"), Defs.Transition.CURTAIN)
	await Flow.transition_finished
	assert_eq(ran, [true] as Array[bool])
	assert_eq(Flow.current_screen, Flow.SCREEN_BOOT, "a missing screen falls back to the boot scene")
	assert_eq(str(Flow.args.get("missing_screen", "")), "no_such_screen")
	assert_false(Flow.busy)
	assert_false(Sim.frozen)
	assert_eq(Flow.get_transition_cover().amount, 0.0)
	await _leave_level()


func test_requests_are_ignored_while_busy() -> void:
	var calls: Array[int] = []
	Flow.busy = true
	Flow.play_covered(func() -> void: calls.append(1))
	Flow.busy = false
	assert_true(calls.is_empty(), "no covered action during another transition")
	assert_false(Sim.frozen)
	await Flow.play_covered(func() -> void: calls.append(2))
	assert_eq(calls, [2] as Array[int])


func test_frozen_clock_drops_time_and_stops_catch_up() -> void:
	Sim.start(1)
	Sim.frozen = true
	Sim._process(Tuning.TICK_DT * 3.5)
	assert_eq(Sim.tick, 0, "a frozen clock does not tick")
	Sim.frozen = false
	Sim._process(Tuning.TICK_DT * 0.5)
	assert_eq(Sim.tick, 0, "time spent frozen is not caught up")
	Sim._process(Tuning.TICK_DT * 0.6)
	assert_eq(Sim.tick, 1)
	var probe: FreezeProbe = FreezeProbe.new()
	add_node(probe)
	Sim._process(Tuning.TICK_DT * 3.2)
	assert_eq(probe.ticks_seen, 1, "a tick that freezes the clock ends the catch-up at once")
	assert_eq(Sim.tick, 2)
	Sim.frozen = false
	Sim.step(2)
	assert_eq(Sim.tick, 4, "step() works whatever the clock does")
