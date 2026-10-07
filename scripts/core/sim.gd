extends Node
## Autoload `Sim`: the fixed-tick simulation clock (PHYSICS.md 15.1, ARCHITECTURE.md 4).
##
## One simulation tick = one original game tick (Tuning.TICK_HZ = 24.2753 Hz). The simulation is driven from
## `_process` with an accumulator; it does NOT use `_physics_process` or the physics servers. Every gameplay object
## derives from [SimEntity] and is called through `_sim_tick(phase)` in the phase order of [enum Defs.Phase], and
## inside a phase in registration (= spawn) order. Rendering interpolates between ticks with [member alpha].
##
## Lifecycle: the level calls [method start] when gameplay begins and [method stop] when it ends. Pausing the
## SceneTree pauses the simulation (this node is PROCESS_MODE_PAUSABLE); [member frozen] holds it while a
## transition covers the level. Tests and the autoplay harness drive it with [method step].

## Emitted at the start of every tick, after input was sampled and before the first phase.
signal tick_started(tick: int)
## Emitted at the end of every tick, after the last phase.
signal tick_finished(tick: int)

## Number of ticks simulated since the last [method start].
var tick: int = 0
## Number of ticks simulated since the application started (never reset; use it for "once per tick" guards).
var total_ticks: int = 0
## Interpolation factor 0..1 between the previous and the current tick, for rendering only.
var alpha: float = 1.0
## True between [method start] and [method stop].
var running: bool = false
## When true `_process` does not advance the clock; only [method step] does (tests, autoplay --fast).
var manual: bool = false
## When true the clock stands still although it is running: Flow sets it while a curtain or iris hides the level
## (level start, gates, respawn), so nothing happens that the player cannot see. [method step] still works.
var frozen: bool = false
## The single simulation RNG (PHYSICS.md 15.1 #7).
var rng: SimRng = SimRng.new(1)
## 2.0: pace of the real-time clock: 1 = Tuning.TICK_HZ ticks per second, 0.5 = half speed (the deciding-moment
## replay of a versus round, docs/expansion/DESIGN.md E.8). It changes only when ticks run, never what a tick does;
## [method step] ignores it.
var time_scale: float = 1.0

var _accumulator: float = 0.0
## Ticking entities of every phase, in registration (= spawn) order. Suspended entities are not in them.
var _phase_lists: Array[Array] = []
## Every registered entity, in registration order (suspended ones included).
var _entities: Array[SimEntity] = []
## Registered entities that are not suspended (any order): the snapshot of `sim_prev` runs over them.
var _awake: Array[SimEntity] = []
var _pending_add: Array[SimEntity] = []
var _in_tick: bool = false
## Registration counter: an entity's serial orders it in the phase lists.
var _serial: int = 0
## Phase being run (-1 between phases), the list index of the entity being called, and whether that list changed
## during the call (an entity was suspended, resumed or unregistered): the loop then continues at `_index`.
var _phase: int = -1
var _index: int = 0
var _shifted: bool = false
## How often each phase has started (never reset): lets a suspended entity restore per-tick counters.
var _phase_runs: PackedInt32Array = PackedInt32Array()
## Development profiler (scripts/core/dev/sim_bench.gd): when set, every `_sim_tick` call is timed and reported to
## `_profiler.add_call(phase, script, usec)`. Null in the game: the tick loop then has no timing in it at all.
var _profiler: Object = null


func _init() -> void:
	for i: int in Defs.PHASE_COUNT:
		var list: Array[SimEntity] = []
		_phase_lists.append(list)
	_phase_runs.resize(Defs.PHASE_COUNT)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	process_priority = -1000


func _notification(what: int) -> void:
	# Never try to catch up after the app was in the background (PHYSICS.md 15.1 #2).
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED \
			or what == NOTIFICATION_APPLICATION_RESUMED or what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_accumulator = 0.0


func _process(delta: float) -> void:
	if not running or manual:
		return
	if frozen:
		# No catching up afterwards: the time spent frozen never existed for the simulation.
		_accumulator = 0.0
		return
	_accumulator += delta * time_scale
	var steps: int = 0
	while _accumulator >= Tuning.TICK_DT:
		if steps >= Tuning.MAX_CATCHUP_TICKS or frozen:
			# Too far behind, or a tick just froze the clock (a transition begins): drop the rest.
			_accumulator = 0.0
			break
		_accumulator -= Tuning.TICK_DT
		_run_tick()
		steps += 1
	alpha = clampf(_accumulator / Tuning.TICK_DT, 0.0, 1.0)


## Begin simulating. Resets the tick counter, the accumulator and the RNG.
func start(seed_value: int = 1) -> void:
	tick = 0
	alpha = 1.0
	_accumulator = 0.0
	rng.reseed(seed_value)
	running = true


## Stop simulating. Registered entities stay registered until they leave the tree.
func stop() -> void:
	running = false
	_accumulator = 0.0
	alpha = 1.0


## Run `count` ticks immediately (works whether or not the clock is running). Used by tests and autoplay.
func step(count: int = 1) -> void:
	for i: int in count:
		_run_tick()
	alpha = 1.0


## Register `entity` so that its `_sim_tick(phase)` is called in every phase it lists in `_sim_phases()`.
## Called by SimEntity itself when it enters the tree. An entity registered during a tick starts ticking on
## the next tick.
func register(entity: SimEntity) -> void:
	if _in_tick:
		_pending_add.append(entity)
	else:
		_add_now(entity)


## Remove `entity` from all phases. Called by SimEntity itself when it leaves the tree. Safe during a tick: an
## entity removed in the middle of a phase is not called any more, and every other entity of that phase is called
## exactly once.
func unregister(entity: SimEntity) -> void:
	var pending_index: int = _pending_add.find(entity)
	if pending_index >= 0:
		_pending_add.remove_at(pending_index)
	if entity._sim_serial < 0:
		return
	var index: int = _entities.find(entity)
	if index >= 0:
		_entities.remove_at(index)
	if not entity._sim_suspended:
		_take_out(entity)
	entity._sim_serial = -1
	entity._sim_suspended = false


## Take a registered entity out of the tick (ARCHITECTURE.md 11, dozing): none of its phases runs and its
## `sim_prev` is not updated until [method resume]. It stays registered and keeps its place in the order. Safe at
## any time, also in the middle of a phase (the entity is then not called again in this tick).
func suspend(entity: SimEntity) -> void:
	if entity._sim_suspended:
		return
	entity._sim_suspended = true
	if entity._sim_serial >= 0:
		_take_out(entity)


## Put a suspended entity back into the tick at its place in the registration order. Safe at any time; in the
## middle of a phase the entity runs in this phase when its place comes after the entity being called, and in
## every later phase of the tick - as if it had never been suspended.
func resume(entity: SimEntity) -> void:
	if not entity._sim_suspended:
		return
	entity._sim_suspended = false
	if entity._sim_serial < 0:
		return
	entity._sim_awake_slot = _awake.size()
	_awake.append(entity)
	for phase: int in entity._sim_phase_list:
		var list: Array = _phase_lists[phase]
		var at: int = _slot_of(list, entity._sim_serial)
		list.insert(at, entity)
		if phase == _phase:
			if at <= _index:
				_index += 1
			_shifted = true


## Number of registered entities (diagnostics, performance budget checks). Suspended (dozing) ones included.
func get_entity_count() -> int:
	return _entities.size()


## Number of registered entities that tick (not suspended).
func get_awake_count() -> int:
	return _awake.size()


## How often `phase` has started since the application started (a suspended entity restores per-tick counters
## with the difference).
func get_phase_runs(phase: int) -> int:
	return _phase_runs[phase]


## True while a tick is being executed.
func is_in_tick() -> bool:
	return _in_tick


func _add_now(entity: SimEntity) -> void:
	if entity._sim_serial >= 0:
		return
	var phases: PackedInt32Array = PackedInt32Array()
	for phase: int in entity._sim_phases():
		if phase < 0 or phase >= Defs.PHASE_COUNT:
			push_error("Sim: %s lists an invalid phase %d" % [entity.name, phase])
		elif not phases.has(phase):
			phases.append(phase)
	entity._sim_phase_list = phases
	entity._sim_serial = _serial
	_serial += 1
	_entities.append(entity)
	if entity._sim_suspended:
		return
	entity._sim_awake_slot = _awake.size()
	_awake.append(entity)
	for phase: int in phases:
		_phase_lists[phase].append(entity)


## Remove a ticking entity from the awake list and its phase lists, keeping the loop of the current phase exact.
func _take_out(entity: SimEntity) -> void:
	var slot: int = entity._sim_awake_slot
	if slot >= 0 and slot < _awake.size() and _awake[slot] == entity:
		var last: SimEntity = _awake[_awake.size() - 1]
		_awake[slot] = last
		last._sim_awake_slot = slot
		_awake.resize(_awake.size() - 1)
	entity._sim_awake_slot = -1
	for phase: int in entity._sim_phase_list:
		var list: Array = _phase_lists[phase]
		var at: int = list.find(entity)
		if at < 0:
			continue
		list.remove_at(at)
		if phase == _phase:
			if at <= _index:
				_index -= 1
			_shifted = true


## First index of `list` whose entity has a serial >= `serial` (the lists are sorted by serial).
func _slot_of(list: Array, serial: int) -> int:
	var low: int = 0
	var high: int = list.size()
	while low < high:
		var mid: int = (low + high) >> 1
		var other: SimEntity = list[mid]
		if other._sim_serial < serial:
			low = mid + 1
		else:
			high = mid
	return low


func _run_tick() -> void:
	if _profiler != null:
		_run_tick_profiled()
		return
	_begin_tick()
	tick_started.emit(tick)
	for phase: int in Defs.PHASE_COUNT:
		var list: Array = _phase_lists[phase]
		_phase_runs[phase] += 1
		_phase = phase
		var count: int = list.size()
		var i: int = 0
		while i < count:
			var entity: SimEntity = list[i]
			if entity.sim_active:
				_index = i
				entity._sim_tick(phase)
				if _shifted:
					# The call suspended, resumed or freed entities of this phase: continue behind the same entity.
					_shifted = false
					i = _index
					count = list.size()
			i += 1
	_phase = -1
	_end_tick()


## Start of a tick: entities registered meanwhile join, the counters advance, input is sampled and the previous
## feet points are kept for the render interpolation (PHYSICS.md 15.1 #6).
func _begin_tick() -> void:
	if not _pending_add.is_empty():
		for entity: SimEntity in _pending_add:
			if is_instance_valid(entity):
				_add_now(entity)
		_pending_add.clear()
	_in_tick = true
	tick += 1
	total_ticks += 1
	GameInput.sample()
	for entity: SimEntity in _awake:
		entity.sim_prev = entity.sim_pos


## End of a tick: the end-of-tick handlers run.
func _end_tick() -> void:
	_in_tick = false
	tick_finished.emit(tick)


## [method _run_tick] with every part and every entity call timed (development profiler only).
func _run_tick_profiled() -> void:
	var start: int = Time.get_ticks_usec()
	_begin_tick()
	var now: int = Time.get_ticks_usec()
	_profiler.call(&"add_part", &"begin: input, snapshot", now - start)
	start = now
	tick_started.emit(tick)
	now = Time.get_ticks_usec()
	_profiler.call(&"add_part", &"tick_started handlers", now - start)
	for phase: int in Defs.PHASE_COUNT:
		var list: Array = _phase_lists[phase]
		_phase_runs[phase] += 1
		_phase = phase
		var count: int = list.size()
		var i: int = 0
		while i < count:
			var entity: SimEntity = list[i]
			if entity.sim_active:
				_index = i
				# The script is read first: the call may free the entity.
				var script: Script = entity.get_script()
				start = Time.get_ticks_usec()
				entity._sim_tick(phase)
				_profiler.call(&"add_call", phase, script, Time.get_ticks_usec() - start)
				if _shifted:
					_shifted = false
					i = _index
					count = list.size()
			i += 1
	_phase = -1
	start = Time.get_ticks_usec()
	_end_tick()
	_profiler.call(&"add_part", &"end: tick_finished handlers", Time.get_ticks_usec() - start)
