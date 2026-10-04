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

var _accumulator: float = 0.0
var _phase_lists: Array[Array] = []
var _entities: Array[SimEntity] = []
var _pending_add: Array[SimEntity] = []
var _in_tick: bool = false
var _dirty: bool = false


func _init() -> void:
	for i: int in Defs.PHASE_COUNT:
		var list: Array[SimEntity] = []
		_phase_lists.append(list)


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
	_accumulator += delta
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


## Remove `entity` from all phases. Called by SimEntity itself when it leaves the tree. Safe during a tick.
func unregister(entity: SimEntity) -> void:
	var pending_index: int = _pending_add.find(entity)
	if pending_index >= 0:
		_pending_add.remove_at(pending_index)
	var index: int = _entities.find(entity)
	if index < 0:
		return
	if _in_tick:
		# Keep indices stable while phase lists are being iterated: blank the slots, compact after the tick.
		_entities[index] = null
		for list: Array in _phase_lists:
			var i: int = list.find(entity)
			if i >= 0:
				list[i] = null
		_dirty = true
	else:
		_entities.remove_at(index)
		for list: Array in _phase_lists:
			list.erase(entity)


## Number of registered entities (diagnostics, performance budget checks).
func get_entity_count() -> int:
	return _entities.size()


## True while a tick is being executed.
func is_in_tick() -> bool:
	return _in_tick


func _add_now(entity: SimEntity) -> void:
	if _entities.has(entity):
		return
	_entities.append(entity)
	for phase: int in entity._sim_phases():
		if phase >= 0 and phase < Defs.PHASE_COUNT:
			_phase_lists[phase].append(entity)
		else:
			push_error("Sim: %s lists an invalid phase %d" % [entity.name, phase])


func _run_tick() -> void:
	if not _pending_add.is_empty():
		for entity: SimEntity in _pending_add:
			if is_instance_valid(entity):
				_add_now(entity)
		_pending_add.clear()
	_in_tick = true
	tick += 1
	total_ticks += 1
	GameInput.sample()
	# Snapshot for render interpolation (PHYSICS.md 15.1 #6).
	for entity: SimEntity in _entities:
		if entity != null:
			entity.sim_prev = entity.sim_pos
	tick_started.emit(tick)
	for phase: int in Defs.PHASE_COUNT:
		var list: Array = _phase_lists[phase]
		var count: int = list.size()
		for i: int in count:
			var entity: SimEntity = list[i]
			if entity != null and entity.sim_active:
				entity._sim_tick(phase)
	_in_tick = false
	if _dirty:
		_dirty = false
		_compact(_entities)
		for phase: int in Defs.PHASE_COUNT:
			_compact(_phase_lists[phase])
	tick_finished.emit(tick)


## Remove the slots blanked by unregister() during a tick, keeping the order of the rest.
func _compact(list: Array) -> void:
	var write: int = 0
	for read: int in list.size():
		if list[read] != null:
			if write != read:
				list[write] = list[read]
			write += 1
	list.resize(write)
