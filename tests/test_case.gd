class_name TestCase
extends Node
## Base class of every test file (docs/ARCHITECTURE.md 9.1). Owner: core.
##
## A test file is `tests/test_<module>_<topic>.gd`, extends TestCase, and contains methods named `test_*`.
## The runner (tests/run_tests.gd) adds one instance to the scene tree, then for every test method calls
## before_each(), the method (it may `await`), and after_each(). A test fails when an assertion fails, when it
## makes no assertion at all, or when the engine logs an error while it runs (unless announced with
## expect_errors()). Nodes created through add_node() / make_level() are freed automatically after each test.

const REFERENCE_PATH: String = "res://docs/spec/PHYSICS_REFERENCE.json"

var _failures: PackedStringArray = PackedStringArray()
var _checks: int = 0
var _expected_errors: int = 0
var _owned: Array[Node] = []

static var _reference: Dictionary = {}


## Called before every test method. Override.
func before_each() -> void:
	pass


## Called after every test method. Override.
func after_each() -> void:
	pass


# --- Assertions -------------------------------------------------------------------------------------------------------

func assert_true(condition: bool, message: String = "") -> void:
	_checks += 1
	if not condition:
		_fail("expected true", message)


func assert_false(condition: bool, message: String = "") -> void:
	_checks += 1
	if condition:
		_fail("expected false", message)


func assert_eq(actual: Variant, expected: Variant, message: String = "") -> void:
	_checks += 1
	if typeof(actual) != typeof(expected) and not (_is_number(actual) and _is_number(expected)):
		_fail("expected %s (%s) but got %s (%s)" % [
			str(expected), type_string(typeof(expected)), str(actual), type_string(typeof(actual)),
		], message)
	elif actual != expected:
		_fail("expected %s but got %s" % [str(expected), str(actual)], message)


func assert_ne(actual: Variant, not_expected: Variant, message: String = "") -> void:
	_checks += 1
	if typeof(actual) == typeof(not_expected) and actual == not_expected:
		_fail("did not expect %s" % str(actual), message)


func assert_almost_eq(actual: float, expected: float, tolerance: float = 0.0001, message: String = "") -> void:
	_checks += 1
	if absf(actual - expected) > tolerance:
		_fail("expected %f +/- %f but got %f" % [expected, tolerance, actual], message)


func assert_null(value: Variant, message: String = "") -> void:
	_checks += 1
	if value != null:
		_fail("expected null but got %s" % str(value), message)


func assert_not_null(value: Variant, message: String = "") -> void:
	_checks += 1
	if value == null:
		_fail("expected a value but got null", message)


## Compare two sequences of numbers element by element as integers. Works across Array, PackedInt32Array and
## the float arrays that JSON.parse produces. `actual` may be longer than `expected` only when `prefix` is true.
func assert_ints_eq(actual: Variant, expected: Variant, message: String = "", prefix: bool = false) -> void:
	_checks += 1
	var actual_size: int = actual.size()
	var expected_size: int = expected.size()
	if actual_size < expected_size or (actual_size != expected_size and not prefix):
		_fail("expected %d values but got %d: %s" % [expected_size, actual_size, str(actual)], message)
		return
	for i: int in expected_size:
		if int(actual[i]) != int(expected[i]):
			_fail("index %d: expected %d but got %d\n      expected %s\n      actual   %s" % [
				i, int(expected[i]), int(actual[i]), str(expected), str(actual),
			], message)
			return


## Fail the test unconditionally.
func fail(message: String) -> void:
	_checks += 1
	_fail("failed", message)


## Announce that the next `count` engine errors are part of the test (e.g. testing an error path).
func expect_errors(count: int) -> void:
	_expected_errors += count


# --- Helpers ----------------------------------------------------------------------------------------------------------

## docs/spec/PHYSICS_REFERENCE.json as a Dictionary (cached). JSON numbers are floats: use assert_ints_eq / int().
static func load_reference() -> Dictionary:
	if _reference.is_empty():
		var json: JSON = JSON.new()
		if json.parse(FileAccess.get_file_as_string(REFERENCE_PATH)) == OK and json.data is Dictionary:
			_reference = json.data
		else:
			push_error("TestCase: cannot read %s" % REFERENCE_PATH)
	return _reference


## Add a node to the tree under this test; it is freed after the test.
func add_node(node: Node) -> Node:
	add_child(node)
	_owned.append(node)
	return node


## A bare, invisible level with a collision grid built from tile rows (level-file legend). It becomes
## Game.level. Freed after the test.
func make_level(tile_rows: PackedStringArray, ice_a: int = 0, ice_b: int = 0) -> LevelBase:
	var level: LevelBase = LevelBase.new()
	level.level_id = &"test"
	level.grid = TileGrid.from_rows(tile_rows, ice_a, ice_b)
	add_node(level)
	return level


## The 'flat' world of the reference traces: `cols` x `rows` tiles, solid from `ground_row` down.
func make_flat_level(cols: int = 128, rows: int = 24, ground_row: int = 20) -> LevelBase:
	var lines: PackedStringArray = PackedStringArray()
	for row: int in rows:
		lines.append((TileGrid.CH_SOLID_A if row >= ground_row else TileGrid.CH_AIR).repeat(cols))
	return make_level(lines)


## Spawn a SimEntity (or subclass instance) into a level at a feet point.
func place(level: LevelBase, entity: SimEntity, pos: Vector2i, params: Dictionary = {}) -> SimEntity:
	entity.spawn_setup(pos, params)
	level.add_child(entity)
	return entity


## Drive the simulation with a run-length input script ([[ticks, "KEYS"], ...], the format of the reference
## traces) and return after all ticks ran. Device input is restored afterwards.
func run_inputs(runs: Array) -> void:
	var flags: PackedInt32Array = GameInput.expand_runs(runs)
	var first_tick: int = Sim.tick + 1
	GameInput.set_scripted(func(tick: int) -> int:
		var index: int = tick - first_tick
		return flags[index] if index >= 0 and index < flags.size() else 0
	)
	Sim.step(flags.size())
	GameInput.clear_scripted()


## The same for several heroes (docs/expansion/TECH_AUDIT.md 4.11): [[ticks, "KEYS|KEYS"], ...] with one key set per
## player slot separated by `|` (an empty or missing part = that slot idle), e.g. [[8, "R|L"], [4, "|U"]]. Every
## slot named by some run gets its stream (GameInput.set_scripted_slot); returns after all ticks ran. Device input
## is restored afterwards (every slot). Returns the streams that were played (index = slot).
func run_party_inputs(runs: Array) -> Array[PackedInt32Array]:
	var entries: PackedStringArray = PackedStringArray()
	for run: Variant in runs:
		entries.append("%d:%s" % [int(run[0]), str(run[1])])
	var streams: Array[PackedInt32Array] = Autoplay.parse_inputs_multi(",".join(entries))
	var first_tick: int = Sim.tick + 1
	for slot: int in streams.size():
		var flags: PackedInt32Array = streams[slot]
		GameInput.set_scripted_slot(slot, func(tick: int) -> int:
			var index: int = tick - first_tick
			return flags[index] if index >= 0 and index < flags.size() else 0
		)
	Sim.step(streams[0].size())
	GameInput.clear_scripted()
	return streams


# --- Runner interface (do not call from tests) ------------------------------------------------------------------------

func _begin_test() -> void:
	_failures = PackedStringArray()
	_checks = 0
	_expected_errors = 0


func _end_test(engine_errors: int) -> PackedStringArray:
	for node: Node in _owned:
		if is_instance_valid(node):
			node.free()
	_owned.clear()
	if GameInput.is_scripted():
		GameInput.clear_scripted()
	if engine_errors != _expected_errors:
		_failures.append("engine logged %d error(s), expected %d" % [engine_errors, _expected_errors])
	if _checks == 0:
		_failures.append("test made no assertion")
	return _failures


func _fail(what: String, message: String) -> void:
	_failures.append(what if message.is_empty() else "%s - %s" % [message, what])


func _is_number(value: Variant) -> bool:
	return typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT
