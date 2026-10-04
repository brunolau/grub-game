extends FidelityCase
## The five golden traces of docs/spec/PHYSICS_REFERENCE.json (reference_sim.py TRACE_DEFS) played in real levels
## built by the world loader: every field the trace records (position, velocities, state, handler, facing,
## fall_ticks, no_jump, jump_ticks, swing_lock, charge, grounded) and the club-box frame must match on every tick.

const FIELDS: Array[String] = [
	"x", "y", "xvel", "yvel", "state", "handler", "facing", "fall_ticks", "no_jump", "jump_ticks", "swing_lock",
	"charge", "grounded",
]


func test_trace_walk_jump_reverse() -> void:
	_check_trace("walk_jump_reverse")


func test_trace_strike_mix() -> void:
	_check_trace("strike_mix")


func test_trace_crawl_and_tap_jumps() -> void:
	_check_trace("crawl_and_tap_jumps")


func test_trace_ledge_drop_4_tiles() -> void:
	_check_trace("ledge_drop_4_tiles")
	assert_eq(shake_log.size(), 50)
	assert_eq(shake_log.count(0), 50, "a 4-tile drop never shakes the screen")


## The 12-tile drop lands hard with a screen shake on tick 29 (fall_ticks 22, yvel 192). reference_sim.py has no
## step 18, so the shake is taken away before step 18 applies it; its value after the timer step must be the
## reference's hero.shake (8 set, 7 after the timer step), and the nudge itself is tested in test_fidelity_more.
func test_trace_ledge_drop_12_tiles_air_control() -> void:
	cancel_shake = true
	_check_trace("ledge_drop_12_tiles_air_control")
	var expected: PackedInt32Array = PackedInt32Array()
	expected.resize(44)
	expected.fill(0)
	expected[28] = Tuning.SHAKE_LANDING - 1
	assert_eq(shake_log, expected, "shake requested on the landing tick only")
	assert_eq(landing_ticks, PackedInt32Array([29, 34]), "hard landing, then the soft touchdown after the hop")
	assert_eq(landing_hard, [true, false] as Array[bool])


func _check_trace(trace_name: String) -> void:
	var trace: Dictionary = load_reference()["traces"][trace_name]
	var world: Dictionary = trace["world"]
	if str(world["type"]) == "flat":
		load_world(flat_rows(int(world["ground_row"])))
	else:
		load_world(ledge_rows(int(world["edge_col"]), int(world["drop_tiles"]), int(world["upper_row"])))
	var start: Dictionary = trace["start"]
	assert_eq(hero.sim_pos, Vector2i(int(start["x"]), int(start["y"])), "%s: '@' gives the start" % trace_name)
	hero.facing = int(start["facing"])
	var flags: PackedInt32Array = flags_of(trace["inputs_run_length"])
	assert_eq(flags.size(), int(trace["ticks"]), "%s: input length" % trace_name)
	var rows: Array[Dictionary] = run(flags)
	for field: String in FIELDS:
		assert_ints_eq(column(rows, field), trace[field], "%s: %s on every tick" % [trace_name, field])
	var frames: Array = []
	for frame_name: Variant in trace["club_box_frame"]:
		frames.append(str(frame_name))
	assert_eq(column(rows, "club"), frames, "%s: club-box frame on every tick" % trace_name)
	assert_eq(death_ticks.size(), 0, "%s: the hero never dies" % trace_name)
