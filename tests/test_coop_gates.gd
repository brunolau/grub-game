extends TestCase
## Co-op requiredness (owner: integration; docs/expansion/PLAN.md 8 V3.c, docs/LEVEL_DESIGN.md 15.7.3 - 15.7.6).
##
## The table is not written here: every `objects/x2_tablet gate=<name> far=c,r` of every co-op file (`kind = coop`)
## on every difficulty it is placed for is a co-op gate. For each one the solo-impossibility search of world-B
## (scripts/world/coop_search.gd, PLAN.md P1.7) must FAIL to bring a single reference hero - every weapon, every belt
## special, Chomper where the stage has a pen - to the tablet's `far` cell within its bound, and every twin window
## and daze value the search measures near the gate must be below the measured solo minimum minus 4 ticks
## (`window <= solo_min - 4`). The table is empty until the first co-op file lands; the test passes on an empty
## table, and a gate without the search fails (no co-op file may ship unproven).
##
## The call this test makes (the search's contract, to be confirmed by world-B with P1.7):
##   coop_search.gd: static func search_gate(level_id: StringName, difficulty: int, gate: String) -> Dictionary
##     "reached": bool     true = a single hero got to the far cell (the gate is not co-op only)
##     "bound": int        ticks the search was allowed (LEVEL_DESIGN 15.7.6: 1 457 *(tune)*)
##     "windows": Array    [{"what": String, "window": int, "solo_min": int}] for every twin window / daze record
##     "detail": String    how the hero got there (when reached), for the failure message

## Running it: `GD_TIMEOUT=3600 bash .tools/gd.sh test coop_gates` (a slow module, PLAN.md V7; about 1.5 min per gate
## and difficulty). The environment variable COOP_GATES_SHARD=<i>/<n> runs only every n-th gate starting at i
## (0-based), so n processes can share the table (`COOP_GATES_SHARD=0/3 ...`, `1/3`, `2/3`); together they check what
## one run does.
## Each search adds a world to the tree and frees it again: the test lets a frame pass after every gate, or the freed
## nodes' queued canvas callbacks pile up until Godot's message queue overflows (wf8_D5_to_integration.txt #1).

const SEARCH: String = "res://scripts/world/coop_search.gd"
const TABLET_ID: StringName = &"objects/x2_tablet"
const WINDOW_MARGIN: int = 4


## Every co-op gate: [level id, difficulty, gate name, far cell (Vector2i), tablet cell (Vector2i)].
func _gates() -> Array[Array]:
	var gates: Array[Array] = []
	for level_id: StringName in Levels.all_ids():
		if not Levels.is_coop_level(level_id):
			continue
		var data: LevelData = LevelData.load_file(Levels.get_level_path(level_id))
		if data == null:
			continue
		for difficulty: int in [Defs.Difficulty.BEGINNER, Defs.Difficulty.EXPERT]:
			if not Levels.is_available(level_id, difficulty):
				continue
			for record: Dictionary in data.entity_records():
				var params: Dictionary = record["params"]
				if StringName(str(record["id"])) != TABLET_ID or not params.has("gate") \
						or not LevelText.applies_to(params, difficulty):
					continue
				var far: PackedStringArray = str(params.get("far", "")).replace(" ", "").split(",")
				var far_cell: Vector2i = Vector2i(-1, -1)
				if far.size() == 2 and far[0].is_valid_int() and far[1].is_valid_int():
					far_cell = Vector2i(far[0].to_int(), far[1].to_int())
				gates.append([level_id, difficulty, str(params["gate"]), far_cell,
					Vector2i(int(record["col"]), int(record["row"]))])
	return gates


func test_every_coop_gate_is_refused_by_the_solo_search() -> void:
	var gates: Array[Array] = _gates()
	print("    co-op gates: %d" % gates.size())
	if gates.is_empty():
		assert_eq(gates.size(), 0, "no co-op gate yet: nothing to refuse")
		return
	assert_true(ResourceLoader.exists(SEARCH), "the solo search %s (world-B, PLAN.md P1.7) proves the gates" % SEARCH)
	if not ResourceLoader.exists(SEARCH):
		return
	var search: GDScript = load(SEARCH) as GDScript
	var shard: Vector2i = _shard()
	for index: int in gates.size():
		if index % shard.y != shard.x:
			continue
		var gate: Array = gates[index]
		var label: String = "%s (%s) gate %s" % [gate[0], Defs.difficulty_name(int(gate[1])), gate[2]]
		assert_ne(gate[3], Vector2i(-1, -1), "%s: its tablet names a far cell" % label)
		var started: int = Time.get_ticks_msec()
		var result: Dictionary = search.call("search_gate", gate[0], gate[1], gate[2])
		print("    %s: %s in %.1f s" % [label, "REACHED" if bool(result.get("reached", true)) else "refused",
				(Time.get_ticks_msec() - started) / 1000.0])
		# Let the main loop turn: the freed search world's canvas callbacks are flushed (see the header).
		await Engine.get_main_loop().process_frame
		assert_false(bool(result.get("reached", true)), "%s: a single hero must not reach %s (%s)" % [label,
				str(gate[3]), str(result.get("detail", ""))])
		for window: Dictionary in result.get("windows", []):
			assert_true(int(window["window"]) <= int(window["solo_min"]) - WINDOW_MARGIN,
					"%s: %s window %d below the solo minimum %d - %d" % [label, window.get("what", "?"),
					window["window"], window["solo_min"], WINDOW_MARGIN])


## The shard of the gate table this process runs: (index, count) from COOP_GATES_SHARD=<i>/<n>; (0, 1) = all gates.
func _shard() -> Vector2i:
	var text: String = OS.get_environment("COOP_GATES_SHARD")
	var parts: PackedStringArray = text.split("/")
	if parts.size() == 2 and parts[0].is_valid_int() and parts[1].is_valid_int():
		var count: int = maxi(1, parts[1].to_int())
		var index: int = clampi(parts[0].to_int(), 0, count - 1)
		if count > 1:
			print("    shard %d of %d" % [index, count])
		return Vector2i(index, count)
	return Vector2i(0, 1)
