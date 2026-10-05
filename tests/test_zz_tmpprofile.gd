extends TestCase
## TEMPORARY (release_check): per-entity-class cost of the simulation tick on real routes. Delete after use.

const VIEW: Vector2i = Vector2i(640, 360)
const RUNS: Array = [
	["w1_l1", "w1_l1.expert.inputs"],
	["w1_l2", "w1_l2.expert.inputs"],
	["w2_l1", "w2_l1.expert.inputs"],
	["w2_l2", "w2_l2.expert.inputs"],
	["w2_l2b", "w2_l2b.expert.inputs"],
	["w3_l1", "w3_l1.expert.inputs"],
	["w3_l2", "w3_l2.expert.inputs"],
	["w4_l1", "w4_l1.inputs"],
	["w4_l2", "w4_l2.inputs"],
	["w4_l2b", "w4_l2b.inputs"],
]


func test_profile_ticks() -> void:
	var grand: Dictionary = {}
	for run: Array in RUNS:
		var level_id: StringName = StringName(str(run[0]))
		var flags: PackedInt32Array = Autoplay.parse_inputs(
				FileAccess.get_file_as_string("res://tools/autoplay/routes/" + str(run[1])))
		Game.new_game(Defs.Difficulty.EXPERT)
		Sim.manual = true
		while Flow.busy:
			await get_tree().process_frame
		var t_load: int = Time.get_ticks_usec()
		Flow.start_level(level_id, Defs.Transition.NONE)
		for i: int in 4:
			await get_tree().process_frame
		while Flow.busy:
			await get_tree().process_frame
		var level: Level = Game.level as Level
		assert_not_null(level, "level")
		if level == null:
			continue
		level.set_view_size(VIEW * Tuning.ART_SCALE)
		var index: Array[int] = [0]
		GameInput.set_scripted(func(_tick: int) -> int:
			var value: int = flags[index[0]] if index[0] < flags.size() else 0
			index[0] += 1
			return value
		)
		var costs: Dictionary = {}
		var calls: Dictionary = {}
		var total: int = 0
		var played: int = 0
		var worst: int = 0
		while played < flags.size() and Sim.running and Game.level == level:
			var t0: int = Time.get_ticks_usec()
			_tick(costs, calls)
			var dt: int = Time.get_ticks_usec() - t0
			total += dt
			worst = maxi(worst, dt)
			played += 1
		GameInput.clear_scripted()
		var keys: Array = costs.keys()
		keys.sort_custom(func(a: Variant, b: Variant) -> bool: return int(costs[a]) > int(costs[b]))
		print("PROFILE %s: %d ticks, avg %d us, max %d us, entities %d (load %d ms)" % [level_id, played,
				total / maxi(played, 1), worst, Sim.get_entity_count(), (t_load) / 1000])
		var shown: int = 0
		for key: Variant in keys:
			grand[key] = int(grand.get(key, 0)) + int(costs[key])
			if shown < 10:
				print("   %-40s %7.1f us/tick  %6.1f calls/tick" % [key, float(costs[key]) / float(maxi(played, 1)),
						float(calls[key]) / float(maxi(played, 1))])
				shown += 1
		Sim.stop()
		Flow.goto_title()
		for i: int in 4:
			await get_tree().process_frame
		while Flow.busy:
			await get_tree().process_frame
	assert_true(true)


func _tick(costs: Dictionary, calls: Dictionary) -> void:
	if not Sim._pending_add.is_empty():
		for entity: SimEntity in Sim._pending_add:
			if is_instance_valid(entity):
				Sim._add_now(entity)
		Sim._pending_add.clear()
	Sim._in_tick = true
	Sim.tick += 1
	Sim.total_ticks += 1
	GameInput.sample()
	for entity: SimEntity in Sim._entities:
		if entity != null:
			entity.sim_prev = entity.sim_pos
	var t_sig: int = Time.get_ticks_usec()
	Sim.tick_started.emit(Sim.tick)
	_add(costs, calls, "signal tick_started", Time.get_ticks_usec() - t_sig)
	for phase: int in Defs.PHASE_COUNT:
		var list: Array = Sim._phase_lists[phase]
		var count: int = list.size()
		for i: int in count:
			var entity: SimEntity = list[i]
			if entity != null and entity.sim_active:
				var t0: int = Time.get_ticks_usec()
				entity._sim_tick(phase)
				var dt: int = Time.get_ticks_usec() - t0
				var script: Script = entity.get_script()
				var asleep: String = ""
				if entity is EnemyBase and not (entity as EnemyBase).awake:
					asleep = " (asleep)"
				_add(costs, calls, "%s p%d%s" % [script.resource_path.get_file() if script != null else "?", phase,
						asleep], dt)
	Sim._in_tick = false
	if Sim._dirty:
		Sim._dirty = false
		Sim._compact(Sim._entities)
		for phase: int in Defs.PHASE_COUNT:
			Sim._compact(Sim._phase_lists[phase])
	var t_fin: int = Time.get_ticks_usec()
	Sim.tick_finished.emit(Sim.tick)
	_add(costs, calls, "signal tick_finished", Time.get_ticks_usec() - t_fin)


func _add(costs: Dictionary, calls: Dictionary, key: String, dt: int) -> void:
	costs[key] = int(costs.get(key, 0)) + dt
	calls[key] = int(calls.get(key, 0)) + 1
