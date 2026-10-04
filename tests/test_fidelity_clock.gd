extends FidelityCase
## Real time (PHYSICS.md 1.2, 15.1 #2 / #6; ARCHITECTURE.md 4.1): the simulation advances Tuning.TICK_HZ
## (24.2753) ticks per second of frame time whatever the display refresh rate, catches up at most
## Tuning.MAX_CATCHUP_TICKS ticks in one rendered frame and drops the rest, and render interpolation only places
## sprites: the same input script gives the same hero state on every tick at any frame rate.
##
## Frames are fed to the Sim autoload's real `_process(delta)` with chosen frame times (no engine frames run
## while a test method executes), with a real level and the real hero.

## An input script that walks, jumps, strikes, crouches and turns (one value per tick).
const SCRIPT: Array = [[10, "R"], [12, "RU"], [9, "F"], [6, "D"], [9, "DF"], [14, "L"], [8, "LU"], [12, ""],
		[9, "UF"], [20, "RU"], [11, ""]]

var _record: Array[Dictionary] = []


func after_each() -> void:
	if Sim.tick_finished.is_connected(_on_recorded_tick):
		Sim.tick_finished.disconnect(_on_recorded_tick)
	super.after_each()


func test_tick_rate_matches_tick_hz_at_any_refresh_rate() -> void:
	load_world(flat_rows())
	for hz: float in [24.0, 30.0, 50.0, 59.94, 60.0, 75.0, 90.0, 120.0, 144.0, 165.0, 240.0, 360.0]:
		Sim.start(1)
		var frames: int = roundi(hz * 30.0)
		var delta: float = 1.0 / hz
		_drive(PackedFloat64Array(), frames, delta)
		var expected: int = floori(float(frames) * delta / Tuning.TICK_DT)
		assert_eq(Sim.tick, expected, "%.2f Hz for 30 s: one tick per 41.194 ms of frame time" % hz)
		var rate: float = float(Sim.tick) / (float(frames) * delta)
		assert_almost_eq(rate, Tuning.TICK_HZ, 0.05, "%.2f Hz: ticks per second" % hz)
	assert_almost_eq(Tuning.TICK_HZ, 1193182.0 / 49152.0, 0.0000001, "TICK_HZ = 1193182 / 16384 / 3")
	assert_almost_eq(Tuning.TICK_HZ, 24.2753, 0.0001)


## Frame-time jitter and hitches shorter than four ticks lose no time; a longer hitch runs four ticks and drops
## the rest (PHYSICS.md 15.1 #2).
func test_hitches_up_to_the_catch_up_limit_lose_no_time() -> void:
	load_world(flat_rows())
	Sim.start(1)
	var times: PackedFloat64Array = PackedFloat64Array()
	var total: float = 0.0
	for i: int in 3000:
		var delta: float = 1.0 / 144.0 if i % 3 != 0 else 1.0 / 60.0
		if i % 97 == 0:
			delta = 0.120
		if i % 389 == 0:
			delta = 0.160
		times.append(delta)
		total += delta
	var max_steps: Array[int] = [0]
	_drive(times, times.size(), 0.0, max_steps)
	assert_eq(Sim.tick, floori(total / Tuning.TICK_DT), "jitter and hitches below 4 ticks: no tick lost")
	assert_true(max_steps[0] <= Tuning.MAX_CATCHUP_TICKS, "never more than four ticks in one frame")
	Sim.start(1)
	max_steps[0] = 0
	_drive(PackedFloat64Array([0.030, 0.160, 0.010]), 3, 0.0, max_steps)
	assert_eq(Sim.tick, 4, "30 + 160 ms owed: four ticks in the hitch frame, 25.2 ms kept, + 10 ms: no tick")
	assert_eq(max_steps[0], 4)
	_drive(PackedFloat64Array([0.006]), 1, 0.0)
	assert_eq(Sim.tick, 5, "25.2 + 10 + 6 ms kept make the next tick")
	Sim.start(1)
	_drive(PackedFloat64Array([0.030, 0.400, 0.010, 0.030]), 4, 0.0)
	# 30 ms: no tick; 430 ms owed: 4 ticks, the rest dropped; then 10 + 30 ms = 40 ms < one tick.
	assert_eq(Sim.tick, 4, "a 400 ms hitch runs four ticks and drops the rest")
	_drive(PackedFloat64Array([0.002]), 1, 0.0)
	assert_eq(Sim.tick, 5, "the clock restarts from the frame after the hitch")


## Losing the focus and covered transitions hold the clock without catching up afterwards.
func test_focus_loss_and_freeze_do_not_catch_up() -> void:
	load_world(flat_rows())
	Sim.start(1)
	_drive(PackedFloat64Array([0.030]), 1, 0.0)
	assert_eq(Sim.tick, 0)
	Sim.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	_drive(PackedFloat64Array([0.030]), 1, 0.0)
	assert_eq(Sim.tick, 0, "the accumulator was cleared when the focus went away")
	Sim.frozen = true
	_drive(PackedFloat64Array([0.5, 0.5]), 2, 0.0)
	Sim.frozen = false
	assert_eq(Sim.tick, 0, "frozen: no tick")
	_drive(PackedFloat64Array([0.030]), 1, 0.0)
	assert_eq(Sim.tick, 0, "the frozen second is not caught up, nor the 30 ms owed before it")
	_drive(PackedFloat64Array([0.015]), 1, 0.0)
	assert_eq(Sim.tick, 1)


## The same input script played tick by tick (Sim.step), at 60 Hz, at 144 Hz with jitter and hitches, and at
## 59.94 Hz while interpolated sprite positions are computed every frame: the hero's state is identical on every
## tick, and the sprite always sits between the previous and the current tick position.
func test_render_rate_never_changes_the_simulation() -> void:
	var reference: Array[Dictionary] = _play_steps()
	var total: int = reference.size()
	assert_true(total > 100)
	var rates: Dictionary = {}
	var jitter: PackedFloat64Array = PackedFloat64Array()
	for i: int in 2000:
		jitter.append(0.150 if i % 53 == 0 else (1.0 / 144.0 if i % 2 == 0 else 1.0 / 120.0))
	rates["144 Hz with jitter and hitches"] = jitter
	var sixty: PackedFloat64Array = PackedFloat64Array()
	sixty.resize(2000)
	sixty.fill(1.0 / 60.0)
	rates["60 Hz"] = sixty
	var ntsc: PackedFloat64Array = PackedFloat64Array()
	ntsc.resize(2000)
	ntsc.fill(1.0 / 59.94)
	rates["59.94 Hz"] = ntsc
	for scenario: String in rates:
		var got: Array[Dictionary] = _play_frames(rates[scenario], total)
		assert_true(got.size() >= total, "%s: the script was played" % scenario)
		var first_mismatch: int = -1
		for i: int in mini(total, got.size()):
			if got[i] != reference[i]:
				first_mismatch = i
				break
		assert_eq(first_mismatch, -1, "%s: hero state equals the Sim.step run on every tick" % scenario)
		if first_mismatch >= 0:
			assert_eq(got[first_mismatch], reference[first_mismatch], "%s: first differing tick" % scenario)


## Real engine frames: Sim's _process (priority -1000) runs before the entities' interpolation in every frame,
## so the sprite shows this frame's alpha, never last frame's.
func test_engine_frames_interpolate_after_the_clock() -> void:
	load_world(flat_rows())
	GameInput.set_scripted(func(_tick: int) -> int: return Defs.IN_RIGHT)
	Sim.manual = false
	var start_tick: int = Sim.tick
	var frames: int = 0
	var problem: String = ""
	while Sim.tick < start_tick + 6 and frames < 100000:
		await get_tree().process_frame
		frames += 1
		var expected: Vector2 = Vector2(
			roundf(lerpf(float(hero.sim_prev.x), float(hero.sim_pos.x), Sim.alpha) * Tuning.ART_SCALE),
			roundf(lerpf(float(hero.sim_prev.y), float(hero.sim_pos.y), Sim.alpha) * Tuning.ART_SCALE)
		)
		if problem.is_empty() and (hero.position != expected or Sim.alpha < 0.0 or Sim.alpha > 1.0):
			problem = "frame %d, tick %d: alpha %f, sprite %s, expected %s" % [
				frames, Sim.tick, Sim.alpha, hero.position, expected,
			]
	Sim.manual = true
	GameInput.clear_scripted()
	assert_true(Sim.tick >= start_tick + 6, "the clock ran on engine frames")
	assert_eq(problem, "", "the sprite follows the interpolation of the current frame")
	assert_true(hero.sim_pos.x > START_X, "the hero walked")


func _play_steps() -> Array[Dictionary]:
	_start_recorded_run()
	var flags: PackedInt32Array = flags_of(SCRIPT)
	for i: int in flags.size():
		Sim.step(1)
	GameInput.clear_scripted()
	return _record.duplicate()


func _play_frames(times: PackedFloat64Array, ticks: int) -> Array[Dictionary]:
	_start_recorded_run()
	Sim.manual = false
	var visuals_ok: bool = true
	for delta: float in times:
		if Sim.tick >= ticks:
			break
		Sim._process(delta)
		# What the engine does next in the same frame: interpolate the hero's canvas position.
		var before: Vector2i = hero.sim_pos
		hero.notification(Node.NOTIFICATION_INTERNAL_PROCESS)
		var expected: Vector2 = Vector2(
			roundf(lerpf(float(hero.sim_prev.x), float(hero.sim_pos.x), Sim.alpha) * Tuning.ART_SCALE),
			roundf(lerpf(float(hero.sim_prev.y), float(hero.sim_pos.y), Sim.alpha) * Tuning.ART_SCALE)
		)
		if Sim.alpha < 0.0 or Sim.alpha > 1.0 or hero.position != expected or hero.sim_pos != before:
			visuals_ok = false
	Sim.manual = true
	GameInput.clear_scripted()
	assert_true(visuals_ok, "alpha in 0..1, sprite at the interpolated, pixel-snapped position, sim untouched")
	return _record.duplicate()


func _start_recorded_run() -> void:
	load_world(flat_rows())
	add_dummy(Vector2i(START_X + 120, START.y), Vector2i(16, 16), 1000, false)
	_record.clear()
	if not Sim.tick_finished.is_connected(_on_recorded_tick):
		Sim.tick_finished.connect(_on_recorded_tick)
	var flags: PackedInt32Array = flags_of(SCRIPT)
	GameInput.set_scripted(func(tick: int) -> int:
		return flags[tick - 1] if tick >= 1 and tick <= flags.size() else 0
	)


## Feed frames to Sim._process: `times` (one delta per frame) or `count` frames of `delta`. `max_steps[0]`
## receives the largest number of ticks run in one frame.
func _drive(times: PackedFloat64Array, count: int, delta: float, max_steps: Array[int] = [0]) -> void:
	Sim.manual = false
	for i: int in count:
		var before: int = Sim.tick
		Sim._process(times[i] if not times.is_empty() else delta)
		max_steps[0] = maxi(max_steps[0], Sim.tick - before)
	Sim.manual = true


func _on_recorded_tick(_tick: int) -> void:
	if hero != null and is_instance_valid(hero):
		var row: Dictionary = snapshot()
		row["hit_log"] = hit_log.size()
		_record.append(row)
