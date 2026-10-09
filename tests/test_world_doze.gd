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
			if first != LevelBase.DZ_NOT_FILED:
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
		if first == LevelBase.DZ_NOT_FILED:
			if not level._dz_scan:
				problems.append("%s dozes but is not filed" % entity.name)
			continue
		if first == LevelBase.DZ_FILED_WIDE:
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
		if not is_instance_valid(entity) or entity._doze_slot < 0 or level._dz_ins[entity._doze_slot * 2] != LevelBase.DZ_FILED_WIDE:
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


# --- A freed entity must never stay filed (wf11: the stale bucket entry seen in the search world) ----------------------

## An idle entity with a doze area of its own (the test moves it); it may always doze.
class Sleeper:
	extends SimEntity

	var area: Rect2i = Rect2i()

	func _doze_area() -> Rect2i:
		return area

	func _can_doze() -> bool:
		return true


## A bare level whose view the test moves.
class ViewLevel:
	extends LevelBase

	var view: Rect2i = Rect2i(0, 0, Tuning.VIEW_W, Tuning.VIEW_H)

	func get_view_rect() -> Rect2i:
		return view


func _view_level() -> ViewLevel:
	var level: ViewLevel = ViewLevel.new()
	level.level_id = &"test"
	var rows: PackedStringArray = PackedStringArray()
	for row: int in 24:
		rows.append((TileGrid.CH_SOLID_A if row >= 20 else TileGrid.CH_AIR).repeat(256))
	level.grid = TileGrid.from_rows(rows)
	add_node(level)
	return level


func _sleeper(level: LevelBase, area: Rect2i) -> Sleeper:
	var entity: Sleeper = Sleeper.new()
	entity.area = area
	place(level, entity, Vector2i(area.position.x + area.size.x / 2, area.end.y))
	return entity


## Every entry of the column index is a live, dozing entity of `level` that the index knows it filed there.
func _stale_entries(level: LevelBase) -> PackedStringArray:
	var stale: PackedStringArray = PackedStringArray()
	for col: Variant in level._dz_buckets:
		for entry: Variant in level._dz_buckets[col]:
			if not is_instance_valid(entry):
				stale.append("column %s: a freed entity" % str(col))
				continue
			var entity: SimEntity = entry
			var slot: int = entity._doze_slot
			if slot < 0 or slot >= level._doze.size() or level._doze[slot] != entity:
				stale.append("column %s: %s is not in the doze list" % [str(col), entity.name])
			elif not level.dz_is_filed(slot) or level._dz_ins[slot * 2] > int(col) or level._dz_ins[slot * 2 + 1] < int(col):
				stale.append("column %s: %s is not filed there by the index" % [str(col), entity.name])
	for entry: Variant in level._dz_wide:
		if not is_instance_valid(entry):
			stale.append("wide: a freed entity")
	return stale


func test_an_entity_dozing_left_of_the_map_is_unfiled_when_it_is_freed() -> void:
	# The stale entry of wf10 (the search world of w4_l1_coop 'boulder': a Digger's copy that died with its box over the
	# map's left edge): an area whose first grid column is -1 or -2 was filed under the very numbers the index used for
	# "not filed" and "wide", so unregister_entity left it in its buckets - and every later pass over those columns met a
	# freed instance.
	Sim.manual = true
	Sim.start(1)
	var level: ViewLevel = _view_level()
	level.view = Rect2i(2400, 0, Tuning.VIEW_W, Tuning.VIEW_H)  # far from the left edge
	var areas: Array[Rect2i] = [
		Rect2i(-40, 300, 30, 16),    # grid columns -1 .. -1  (the old "not filed" mark)
		Rect2i(-100, 300, 30, 16),   # grid columns -2 .. -2  (the old "wide" mark)
		Rect2i(-20, 300, 40, 16),    # grid columns -1 .. 0
		Rect2i(20, 300, 30, 16),     # grid column 0 (a plain one, for comparison)
	]
	var sleepers: Array[Sleeper] = []
	for area: Rect2i in areas:
		sleepers.append(_sleeper(level, area))
	Sim.step(2)
	for entity: Sleeper in sleepers:
		assert_true(entity.is_dozing(), "the entity at %s dozes far from the view" % str(entity.area))
		assert_true(level.dz_is_filed(entity._doze_slot), "... and the index has it filed")
	assert_eq(_stale_entries(level), PackedStringArray(), "the index is sound while they doze")
	# A second decision over the same entities files nothing twice.
	level.respawn_player()
	var filed: int = 0
	for col: Variant in level._dz_buckets:
		filed += (level._dz_buckets[col] as Array).size()
	assert_eq(filed, 5, "each entity is filed once per column of its area (1 + 1 + 2 + 1)")
	# Freed while dozing (a search reset, a split copy leaving, a spawner's corpse): nothing of them stays filed.
	for entity: Sleeper in sleepers:
		level.remove_child(entity)
		entity.free()
	assert_eq(_stale_entries(level), PackedStringArray(), "no freed entity stays in the column index")
	var left_over: int = 0
	for col: Variant in level._dz_buckets:
		left_over += (level._dz_buckets[col] as Array).size()
	assert_eq(left_over, 0, "the buckets are empty again")
	# The view comes to the left edge: the passes over those columns meet no freed instance (the runner counts engine
	# errors: "Trying to assign invalid previously freed instance" was thrown on every tick).
	level.view = Rect2i(0, 200, Tuning.VIEW_W, Tuning.VIEW_H)
	var late: Sleeper = _sleeper(level, Rect2i(3000, 300, 30, 16))
	Sim.step(3)
	assert_true(late.is_dozing(), "the doze manager still decides (a far entity dozes)")
	level.view = Rect2i(2800, 200, Tuning.VIEW_W, Tuning.VIEW_H)
	Sim.step(2)
	assert_false(late.is_dozing(), "... and wakes it when the view comes")
	Sim.manual = false
	Sim.stop()


func test_a_dozing_entity_left_of_the_map_wakes_when_the_view_comes() -> void:
	# The other half of the same defect: marked "not filed" although it was, such an entity was filed again at every
	# scan and - worse - unfiled never, so a wake left its old entries behind.
	Sim.manual = true
	Sim.start(1)
	var level: ViewLevel = _view_level()
	level.view = Rect2i(2400, 0, Tuning.VIEW_W, Tuning.VIEW_H)
	var entity: Sleeper = _sleeper(level, Rect2i(-40, 300, 30, 16))
	Sim.step(2)
	assert_true(entity.is_dozing(), "it dozes far from the view")
	level.view = Rect2i(0, 200, Tuning.VIEW_W, Tuning.VIEW_H)
	Sim.step(2)
	assert_false(entity.is_dozing(), "the view at the left edge wakes it")
	assert_false(level.dz_is_filed(entity._doze_slot), "an awake entity is not filed")
	assert_eq(_stale_entries(level), PackedStringArray(), "... and left nothing behind in the buckets")
	level.view = Rect2i(2400, 0, Tuning.VIEW_W, Tuning.VIEW_H)
	Sim.step(2)
	assert_true(entity.is_dozing(), "it dozes again when the view leaves")
	assert_eq(_stale_entries(level), PackedStringArray(), "the index is sound")
	Sim.manual = false
	Sim.stop()
