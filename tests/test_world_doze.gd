extends RouteTestCase
## The column index of LevelBase's doze manager (the multi-hero performance pass of phase 3, LevelBase.
## _doze_index_pass): a full doze pass looks only at the awake entities, the noted ones and the dozing ones filed under
## a column of a doze rectangle. That makes the same decisions as the scan of every slot only while the index holds on
## every tick: every entity the manager put to sleep is filed under exactly the grid columns of its stored doze area (or
## among the wide ones), nothing awake is filed, a dozing entity whose area is unknown has been noted, and every dozing
## entity's area lies off every doze rectangle of the last decision. Checked on every tick of a solo Book I route and of
## a co-op route; tools/sp_identity.sh proves the single-player digests (dozing on and off), the co-op route replays
## (tests/test_coop_routes.gd) the party ones.

## The co-op routes checked: [route file, mode].
const ROUTES: Array[Array] = [["w1_l1_coop.inputs", "beginner"], ["w5_l1_coop.inputs", "beginner"]]
const SOLO_ROUTE: String = "w1_l1.inputs"
const ROUTES_TEST: String = "res://tests/test_campaign_routes.gd"

var _index_problems: int = 0
var _index_first: String = ""
var _index_ticks: int = 0
var _dozing_seen: int = 0


func _check_index(level: LevelBase, stage_tick: int) -> void:
	var problems: PackedStringArray = PackedStringArray()
	var grid_cols: Dictionary = {}
	for slot: int in level._doze.size():
		var entity: SimEntity = level._doze[slot]
		if entity._doze_slot != slot:
			problems.append("slot %d holds %s with _doze_slot %d" % [slot, entity.name, entity._doze_slot])
			continue
		var first: int = level._dz_ins[slot * 2]
		var last: int = level._dz_ins[slot * 2 + 1]
		if not entity._sim_suspended:
			if first != -1:
				problems.append("%s is awake but filed (%d..%d)" % [entity.name, first, last])
			continue
		_dozing_seen += 1
		if level._doze_known[slot] == 0:
			if not level._doze_notes.has(entity) and not level._dz_scan:
				problems.append("%s dozes with an unknown area but was not noted" % entity.name)
			continue
		var k: int = slot * 4
		var left: int = level._doze_rects[k]
		var top: int = level._doze_rects[k + 1]
		var right: int = level._doze_rects[k + 2]
		var bottom: int = level._doze_rects[k + 3]
		if first == -1:
			if not level._dz_scan:
				problems.append("%s dozes but is not filed" % entity.name)
			continue
		if first == -2:
			if not level._dz_wide.has(entity):
				problems.append("%s is marked wide but not in _dz_wide" % entity.name)
		else:
			if first != left >> 6 or last != (right - 1) >> 6:
				problems.append("%s filed under %d..%d, its area %d..%d" % [entity.name, first, last, left, right])
			for col: int in range(first, last + 1):
				var bucket: Variant = level._dz_buckets.get(col)
				if bucket == null or not (bucket as Array).has(entity):
					problems.append("%s missing from column %d" % [entity.name, col])
					break
				grid_cols[col] = true
		# The invariant the index relies on: off every doze rectangle of the last decision.
		var rects: Array[Vector4i] = [
			Vector4i(level._dz_view_left, level._dz_view_top, level._dz_view_right, level._dz_view_bottom),
			Vector4i(level._dz_hero_left, level._dz_hero_top, level._dz_hero_right, level._dz_hero_bottom),
		]
		for r: int in level._dz_more_count:
			rects.append(Vector4i(level._dz_more[r * 4], level._dz_more[r * 4 + 1], level._dz_more[r * 4 + 2],
					level._dz_more[r * 4 + 3]))
		for rect: Vector4i in rects:
			if not (right <= rect.x or left >= rect.z or bottom <= rect.y or top >= rect.w):
				problems.append("%s dozes inside a doze rectangle %s" % [entity.name, str(rect)])
				break
	# Nothing stale in the buckets: every filed entity is a dozing entity of this level, filed under that column.
	for col: Variant in level._dz_buckets:
		for entity: SimEntity in level._dz_buckets[col]:
			if not is_instance_valid(entity) or entity._doze_slot < 0 or not entity._sim_suspended \
					or level._dz_ins[entity._doze_slot * 2] > int(col) or level._dz_ins[entity._doze_slot * 2 + 1] < int(col):
				problems.append("column %s holds a stale entry" % str(col))
				break
	for entity: SimEntity in level._dz_wide:
		if not is_instance_valid(entity) or entity._doze_slot < 0 or level._dz_ins[entity._doze_slot * 2] != -2:
			problems.append("a stale wide entry")
			break
	_index_ticks += 1
	if not problems.is_empty():
		_index_problems += 1
		if _index_first.is_empty():
			_index_first = "%s tick %d: %s" % [level.level_id, stage_tick, "; ".join(problems)]


func test_the_doze_index_holds_on_every_tick_of_a_solo_route() -> void:
	var routes: Dictionary = (load(ROUTES_TEST) as GDScript).get_script_constant_map()["ROUTES"]
	_index_problems = 0
	_index_first = ""
	_dozing_seen = 0
	var result: Dictionary = await runner().replay(SOLO_ROUTE, "beginner", {"routes": routes, "route_dir": ROUTE_DIR,
			"on_tick": _check_index})
	assert_true((result.get("lines", PackedStringArray()) as PackedStringArray).size() > 500, "the route played")
	assert_true(_dozing_seen > 1000, "entities dozed (%d dozing entity-ticks)" % _dozing_seen)
	assert_eq(_index_problems, 0, "the index held on every tick (first problem: %s)" % _index_first)


func test_the_doze_index_holds_on_every_tick_of_coop_routes() -> void:
	var table: Dictionary = header_table(ROUTE_DIR, func(file: String, _spec: Dictionary) -> bool:
		for entry: Array in ROUTES:
			if entry[0] == file:
				return true
		return false)
	for entry: Array in ROUTES:
		if not table.has(entry[0]):
			continue
		_index_problems = 0
		_index_first = ""
		_dozing_seen = 0
		var result: Dictionary = await runner().replay(entry[0], entry[1], {"routes": table, "on_tick": _check_index,
				"chain": false})
		assert_true((result.get("lines", PackedStringArray()) as PackedStringArray).size() > 500, "%s played" % entry[0])
		assert_true(_dozing_seen > 1000, "%s: entities dozed (%d)" % [entry[0], _dozing_seen])
		assert_eq(_index_problems, 0, "%s: the index held on every tick (first problem: %s)" % [entry[0], _index_first])
		print("    %s (%s): %d ticks checked, %d dozing entity-ticks" % [entry[0], entry[1], _index_ticks, _dozing_seen])
