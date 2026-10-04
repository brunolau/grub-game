extends TestCase
## Sim + SimEntity + GameInput: phase order, registration rules, scripted input, render interpolation, RNG.


## Records every phase call into a shared calls.
class Probe:
	extends SimEntity

	var label: String = ""
	var phases: PackedInt32Array = PackedInt32Array()
	var calls: Array[String] = []
	var seen_flags: PackedInt32Array = PackedInt32Array()
	var spawn_on_tick: Probe = null
	var free_on_tick: Probe = null

	func _sim_phases() -> PackedInt32Array:
		return phases

	func _sim_tick(phase: int) -> void:
		calls.append("%s:%d" % [label, phase])
		if phase == Defs.Phase.PLAYER:
			seen_flags.append(GameInput.flags)
			sim_pos.x += 10
		if spawn_on_tick != null and spawn_on_tick.get_parent() == null:
			get_parent().add_child(spawn_on_tick)
		if free_on_tick != null and is_instance_valid(free_on_tick):
			free_on_tick.free()
			free_on_tick = null


func _probe(label: String, phases: Array[int], calls: Array[String]) -> Probe:
	var probe: Probe = Probe.new()
	probe.label = label
	probe.phases = PackedInt32Array(phases)
	probe.calls = calls
	return probe


func test_phases_run_in_order_and_entities_in_spawn_order() -> void:
	var calls: Array[String] = []
	var a: Probe = _probe("a", [Defs.Phase.POST, Defs.Phase.ENEMIES], calls)
	var b: Probe = _probe("b", [Defs.Phase.PLAYER, Defs.Phase.ENEMIES], calls)
	add_node(a)
	add_node(b)
	Sim.step(1)
	assert_eq(calls, ["a:2", "b:2", "b:6", "a:11"] as Array[String])
	assert_eq(Defs.Phase.FX, 0)
	assert_eq(Defs.Phase.WEAPONS, 1)
	assert_eq(Defs.Phase.POST, Defs.PHASE_COUNT - 1)
	assert_true(Defs.Phase.PLATFORMS < Defs.Phase.PLAYER, "platforms move before the hero (PHYSICS.md 3)")
	assert_true(Defs.Phase.PLAYER < Defs.Phase.CONTACT_ENEMIES)
	assert_true(Defs.Phase.CONTACT_ENEMIES < Defs.Phase.CONTACT_ITEMS)
	assert_true(Defs.Phase.CONTACT_ITEMS < Defs.Phase.CAMERA)


func test_tick_counter_and_signals() -> void:
	var seen: Array[int] = []
	var on_tick: Callable = func(tick: int) -> void: seen.append(tick)
	Sim.tick_finished.connect(on_tick)
	Sim.start(7)
	assert_eq(Sim.tick, 0)
	assert_true(Sim.running)
	Sim.step(3)
	Sim.stop()
	Sim.tick_finished.disconnect(on_tick)
	assert_eq(Sim.tick, 3)
	assert_eq(seen, [1, 2, 3] as Array[int])
	assert_false(Sim.running)
	assert_false(Sim.is_in_tick())


func test_entity_spawned_during_a_tick_starts_next_tick() -> void:
	var calls: Array[String] = []
	var parent: Probe = _probe("p", [Defs.Phase.ENEMIES], calls)
	var child: Probe = _probe("c", [Defs.Phase.POST], calls)
	parent.spawn_on_tick = child
	add_node(parent)
	Sim.step(1)
	assert_eq(calls, ["p:2"] as Array[String], "the new entity does not tick in the tick it was spawned in")
	Sim.step(1)
	assert_eq(calls, ["p:2", "p:2", "c:11"] as Array[String])
	child.free()


func test_entity_freed_during_a_tick_is_skipped() -> void:
	var calls: Array[String] = []
	var killer: Probe = _probe("k", [Defs.Phase.ENEMIES], calls)
	var victim: Probe = _probe("v", [Defs.Phase.ENEMIES, Defs.Phase.POST], calls)
	var bystander: Probe = _probe("b", [Defs.Phase.POST], calls)
	killer.free_on_tick = victim
	add_node(killer)
	add_child(victim)
	add_node(bystander)
	var before: int = Sim.get_entity_count()
	Sim.step(2)
	assert_eq(calls, ["k:2", "b:11", "k:2", "b:11"] as Array[String])
	assert_eq(Sim.get_entity_count(), before - 1)


func test_inactive_entities_are_not_ticked() -> void:
	var calls: Array[String] = []
	var probe: Probe = _probe("x", [Defs.Phase.ITEMS], calls)
	add_node(probe)
	probe.sim_active = false
	Sim.step(2)
	assert_true(calls.is_empty())
	probe.sim_active = true
	Sim.step(1)
	assert_eq(calls.size(), 1)


func test_scripted_input_is_sampled_once_per_tick() -> void:
	var calls: Array[String] = []
	var probe: Probe = _probe("h", [Defs.Phase.PLAYER], calls)
	add_node(probe)
	run_inputs([[2, "R"], [1, "RU"], [1, ""], [2, "LF"]])
	assert_eq(probe.seen_flags, PackedInt32Array([
		Defs.IN_RIGHT, Defs.IN_RIGHT, Defs.IN_RIGHT | Defs.IN_UP, 0,
		Defs.IN_LEFT | Defs.IN_FIRE, Defs.IN_LEFT | Defs.IN_FIRE,
	]))
	assert_false(GameInput.is_scripted())
	assert_eq(GameInput.flags, 0)


func test_touch_presses_are_latched_for_one_tick() -> void:
	GameInput.set_touch(Defs.ACT_ATTACK, true)
	GameInput.set_touch(Defs.ACT_ATTACK, false)
	Sim.step(1)
	assert_true(GameInput.is_held(Defs.IN_FIRE), "a tap shorter than one tick still counts for one tick")
	assert_true(GameInput.just_pressed(Defs.IN_FIRE))
	Sim.step(1)
	assert_false(GameInput.is_held(Defs.IN_FIRE))
	GameInput.set_touch(Defs.ACT_JUMP, true)
	Sim.step(2)
	assert_true(GameInput.is_held(Defs.IN_UP), "held buttons stay held")
	GameInput.clear_touch()
	Sim.step(1)
	assert_eq(GameInput.flags, 0)
	GameInput.device = Defs.Device.KEYBOARD


func test_visual_position_is_interpolated_and_scaled() -> void:
	var calls: Array[String] = []
	var probe: Probe = _probe("m", [Defs.Phase.PLAYER], calls)
	probe.spawn_setup(Vector2i(100, 50), {})
	add_node(probe)
	assert_eq(probe.position, Vector2(200.0, 100.0), "canvas position = logical px x ART_SCALE")
	Sim.step(1)
	assert_eq(probe.sim_prev, Vector2i(100, 50))
	assert_eq(probe.sim_pos, Vector2i(110, 50))
	probe._update_visual(0.5)
	assert_eq(probe.position, Vector2(210.0, 100.0), "half way between two ticks")
	probe._update_visual(1.0)
	assert_eq(probe.position, Vector2(220.0, 100.0))
	probe.teleport(Vector2i(8, 16))
	assert_eq(probe.sim_prev, probe.sim_pos, "teleports are never interpolated")
	assert_eq(probe.get_box(), Rect2i(0, 0, 16, 16))
	assert_eq(probe.cell_col(), 0)
	assert_eq(probe.cell_row(), 1)


func test_spawn_parameters() -> void:
	var probe: Probe = _probe("s", [], [])
	probe.spawn_setup(Vector2i(40, 176), {"facing": "left", "speed": 16, "expert": true, "skin": "turtle_b"})
	add_node(probe)
	assert_eq(probe.facing, -1)
	assert_eq(probe.spawn_pos, Vector2i(40, 176))
	assert_eq(probe.param_int("speed"), 16)
	assert_eq(probe.param_int("missing", 5), 5)
	assert_true(probe.param_bool("expert"))
	assert_false(probe.param_bool("missing"))
	assert_eq(probe.param_str("skin"), "turtle_b")
	assert_true(probe.is_in_group(Defs.GROUP_SIM))


func test_rng_is_deterministic() -> void:
	var a: SimRng = SimRng.new(1234)
	var b: SimRng = SimRng.new(1234)
	var same: bool = true
	var in_range: bool = true
	for i: int in 200:
		var value: int = a.next_int(10)
		same = same and value == b.next_int(10)
		in_range = in_range and value >= 0 and value < 10
	assert_true(same, "same seed, same sequence")
	assert_true(in_range)
	var c: SimRng = SimRng.new(1235)
	a.reseed(1234)
	var differs: bool = false
	for i: int in 20:
		differs = differs or a.next_u32() != c.next_u32()
	assert_true(differs, "different seeds diverge")
	assert_eq(a.range_int(5, 5), 5)
	assert_eq(a.next_int(1), 0)
	var state: int = a.get_state()
	var next: int = a.next_u32()
	a.set_state(state)
	assert_eq(a.next_u32(), next, "state can be saved and restored")
