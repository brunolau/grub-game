extends PlayerTestCase
## The five golden traces of docs/spec/PHYSICS_REFERENCE.json (reference_sim.py TRACE_DEFS): scripted inputs with
## the complete hero state after every tick. Position, velocities, state, handler, facing, every counter and the
## club-box frame must match on every tick.

const INT_FIELDS: Array[String] = [
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


func test_trace_ledge_drop_12_tiles_air_control() -> void:
	_check_trace("ledge_drop_12_tiles_air_control")


func _check_trace(trace_name: String) -> void:
	var trace: Dictionary = load_reference()["traces"][trace_name]
	var world: Dictionary = trace["world"]
	if str(world["type"]) == "flat":
		world_flat(int(world["ground_row"]))
	else:
		world_ledge(int(world["edge_col"]), int(world["drop_tiles"]), int(world["upper_row"]))
	var start: Dictionary = trace["start"]
	spawn_hero(Vector2i(int(start["x"]), int(start["y"])))
	hero.facing = int(start["facing"])
	var flags: PackedInt32Array = GameInput.expand_runs(trace["inputs_run_length"])
	assert_eq(flags.size(), int(trace["ticks"]), "%s: input length" % trace_name)
	var actual: Dictionary = {}
	for field: String in INT_FIELDS:
		actual[field] = PackedInt32Array()
	var frames: PackedStringArray = PackedStringArray()
	play(flags, func(_tick: int) -> void:
		var values: Dictionary = {
			"x": hero.sim_pos.x, "y": hero.sim_pos.y, "xvel": hero.xvel, "yvel": hero.yvel, "state": hero.state,
			"handler": hero.handler, "facing": hero.facing, "fall_ticks": hero.fall_ticks, "no_jump": hero.no_jump,
			"jump_ticks": hero.jump_ticks, "swing_lock": hero.swing_lock, "charge": hero.charge,
			"grounded": 1 if hero.grounded else 0,
		}
		for field: String in INT_FIELDS:
			var list: PackedInt32Array = actual[field]
			list.append(int(values[field]))
			actual[field] = list
		frames.append("" if hero.club_frame < 0 else CLUB_FRAME_NAMES[hero.club_frame])
	)
	for field: String in INT_FIELDS:
		assert_ints_eq(actual[field], trace[field], "%s: %s per tick" % [trace_name, field])
	var expected_frames: PackedStringArray = PackedStringArray()
	for frame_name: Variant in trace["club_box_frame"]:
		expected_frames.append(str(frame_name))
	assert_eq(frames, expected_frames, "%s: club box frame per tick" % trace_name)
