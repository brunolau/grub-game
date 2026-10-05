extends TestCase
## World 4 level checks beyond the route proofs (owner: level design w4), both Expert only: Cinder Shaft (w4_l1), the
## auto-scrolling descent down a volcanic chimney, and Obsidian Keep (w4_l2). The routes (including the boss stage
## Colossus Hall), the links and the validity of the files are checked by the campaign suite,
## tests/test_campaign_routes.gd.
##
## Two fairness checks guard the layouts themselves (review w4): a player who rushes down the shaft without waiting
## for the view gets several seconds before the bottom edge catches him, and the column staircase of the keep
## forgives a range of jump timings instead of one exact input.

const W4_L1: StringName = &"w4_l1"
const W4_L2: StringName = &"w4_l2"
const ROUTES: String = "res://tools/autoplay/routes/"
## Logical view of the 1280 x 720 game window (integer scale 2): enemies wake by the view.
const VIEW: Vector2i = Vector2i(Tuning.VIEW_W, Tuning.VIEW_H)
## A player who walks every ledge of the crater throat to its end and drops at once, never waiting for the view.
const RUSH_INPUTS: String = "34:L,36:R,36:L,36:R,36:L,36:R,30:L,8:R,12:L,30:R,60:"
## The rusher must still be alive this long (about 8 seconds) and well down the throat by then.
const RUSH_SAFE_TICKS: int = 200
const RUSH_MIN_ROW: int = 20
## Column staircase of Obsidian Keep: right edges (px) of the floor and of columns 1-3, and the high ledge.
const STAIR_EDGES: Array[int] = [1472, 1568, 1648, 1728]
const STAIR_GOAL: Vector2i = Vector2i(1808, 432)
## Take-off distances from the edge (px) and Right-hold lengths (ticks, Up held for the whole jump) a player uses.
const STAIR_TAKEOFFS: Array[int] = [6, 12, 18]
const STAIR_HOLDS: Array[int] = [10, 12, 14, 16]
const STAIR_MIN_SUCCESS: int = 10

var _deaths: int = 0


func after_each() -> void:
	if Events.player_died.is_connected(_on_died):
		Events.player_died.disconnect(_on_died)
	GameInput.clear_scripted()
	Sim.manual = false
	Sim.stop()
	if get_tree().current_scene != null:
		get_tree().current_scene.free()
		get_tree().current_scene = null
	Flow.current_screen = Flow.SCREEN_BOOT


## The crater throat paces a player who never waits: he sinks toward the bottom edge over several seconds (the
## lesson of the auto-scroll) instead of falling below it on his second drop.
func test_cinder_shaft_gives_a_rusher_time() -> void:
	Game.new_game(Defs.Difficulty.EXPERT)
	await _start(W4_L1)
	var flags: PackedInt32Array = Autoplay.parse_inputs(RUSH_INPUTS)
	flags.resize(RUSH_SAFE_TICKS)
	var played: int = _replay(flags)
	assert_eq(played, RUSH_SAFE_TICKS)
	assert_eq(_deaths, 0, "the rusher is still alive after %d ticks" % RUSH_SAFE_TICKS)
	var hero: PlayerBase = Game.level.player
	assert_true(hero.sim_pos.y >= RUSH_MIN_ROW * Tuning.TILE, "the rusher went down the throat (row %d)" % (
			hero.sim_pos.y / Tuning.TILE))


## The shaft waits for the player (review fresh_eyes): the view does not sink before his first input, so nobody is
## carried off the top edge while reading the start sign; the start sign is up from the first tick; the deadly top
## edge is drawn as a smoke band; and once he moves, the view sinks 1 px per tick.
func test_cinder_shaft_waits_for_the_first_input() -> void:
	Game.new_game(Defs.Difficulty.EXPERT)
	await _start(W4_L1)
	var level: Level = Game.level as Level
	var top: int = level.get_view_rect().position.y
	assert_true(level.is_autoscroll_held(), "the descent waits")
	var idle: PackedInt32Array = PackedInt32Array()
	idle.resize(150)
	assert_eq(_replay(idle), 150)
	assert_eq(_deaths, 0, "idle for 6 s on the start ledge: alive")
	assert_eq(level.get_view_rect().position.y, top, "the view did not sink")
	var signs: Array[SignBoard] = []
	for entity: SimEntity in level.get_kind(Defs.Kind.OTHER):
		if entity is SignBoard:
			signs.append(entity as SignBoard)
	assert_eq(signs.size(), 1, "one sign in the shaft")
	if not signs.is_empty():
		assert_eq(signs[0].text_key, "SIGN_W4_SHAFT")
		assert_true((signs[0].get_node("Text") as Label).visible, "it shows from the start")
	assert_not_null(level.get_node_or_null(^"TopSmoke"), "the top edge is drawn as smoke")
	_replay(Autoplay.parse_inputs("1:L,9:"))
	assert_false(level.is_autoscroll_held(), "the first input starts the descent")
	assert_eq(level.get_view_rect().position.y, top + 10, "1 px per tick from the first input on")


## The four rising columns over the spike carpet: a player who walks up to the edge, waits for the next column to
## stop rising and jumps with Up held and Right for most of the rise lands on every column - not only with one
## exact input. Played from the hall's entrance as the route reaches it.
func test_obsidian_keep_column_staircase_forgives_timing() -> void:
	var route: String = FileAccess.get_file_as_string(ROUTES + "w4_l2.inputs")
	var cut: int = route.find("# Column hall")
	assert_true(cut > 0, "the route has a column hall section")
	var prefix: PackedInt32Array = Autoplay.parse_inputs(route.substr(0, cut))
	var ok: int = 0
	var results: PackedStringArray = PackedStringArray()
	for takeoff: int in STAIR_TAKEOFFS:
		for hold: int in STAIR_HOLDS:
			var result: String = await _climb_staircase(prefix, takeoff, hold)
			results.append("%d/%d:%s" % [takeoff, hold, result])
			if result == "ok":
				ok += 1
			after_each()
	assert_true(ok >= STAIR_MIN_SUCCESS, "staircase climbs: %d of %d (%s)" % [
			ok, results.size(), ", ".join(results)])


# =================================================================================================================
# Helpers
# =================================================================================================================

## Enter `level_id` through Flow like the game does, with the clock under the test's control.
func _start(level_id: StringName) -> void:
	_deaths = 0
	if not Events.player_died.is_connected(_on_died):
		Events.player_died.connect(_on_died)
	Sim.manual = true
	await get_tree().process_frame
	while Flow.busy:
		await get_tree().process_frame
	Flow.start_level(level_id, Defs.Transition.NONE)
	for i: int in 3:
		await get_tree().process_frame
	while Flow.busy:
		await get_tree().process_frame
	assert_eq(Flow.current_screen, Flow.SCREEN_LEVEL)
	assert_eq(Game.level.level_id, level_id)
	var level: Level = Game.level as Level
	if level != null:
		level.set_view_size(VIEW * Tuning.ART_SCALE)


## Play input flags one tick at a time until they end or gameplay stops; returns the ticks played.
func _replay(flags: PackedInt32Array) -> int:
	var index: Array[int] = [0]
	GameInput.set_scripted(func(_tick: int) -> int:
		var value: int = flags[index[0]] if index[0] < flags.size() else 0
		index[0] += 1
		return value
	)
	var played: int = 0
	while played < flags.size() and Sim.running:
		Sim.step(1)
		played += 1
	GameInput.clear_scripted()
	return played




## One staircase climb from the hall's entrance with a simple player: walk to `takeoff` px before the edge, stand
## until the next column has risen completely, jump with Up held 24 ticks and Right for `hold` ticks, land, repeat.
## Returns "ok" when the high ledge is reached, "fell N" when the hero died at step N, "stuck N" otherwise.
func _climb_staircase(prefix: PackedInt32Array, takeoff: int, hold: int) -> String:
	Game.new_game(Defs.Difficulty.EXPERT)
	await _start(W4_L2)
	var columns: Array[RisingColumn] = []
	for entity: SimEntity in Game.level.get_kind(Defs.Kind.OTHER):
		# The hall's columns (the gatehouse has a bridge column of its own further west).
		if entity is RisingColumn and entity.sim_pos.x >= STAIR_EDGES[0]:
			columns.append(entity as RisingColumn)
	columns.sort_custom(func(a: RisingColumn, b: RisingColumn) -> bool: return a.sim_pos.x < b.sim_pos.x)
	assert_eq(columns.size(), STAIR_EDGES.size(), "four rising columns in the hall")
	# state: 0 walk, 1 stand, 2 jump, 3 in the air; step; timer; steady ticks
	var st: Array[int] = [0, 0, 0, 0]
	var index: Array[int] = [0]
	GameInput.set_scripted(func(_tick: int) -> int:
		var i: int = index[0]
		index[0] += 1
		if i < prefix.size():
			return prefix[i]
		return _staircase_input(columns, st, takeoff, hold)
	)
	var result: String = ""
	var ticks: int = 0
	while ticks < prefix.size() + 1200 and Sim.running and result == "":
		Sim.step(1)
		ticks += 1
		var hero: PlayerBase = Game.level.player
		if _deaths > 0:
			result = "fell %d" % st[1]
		elif st[1] >= STAIR_EDGES.size() and hero.sim_pos.x >= STAIR_GOAL.x and hero.sim_pos.y <= STAIR_GOAL.y \
				and hero.yvel == 0:
			result = "ok"
	GameInput.clear_scripted()
	return result if result != "" else "stuck %d" % st[1]


func _staircase_input(columns: Array[RisingColumn], st: Array[int], takeoff: int, hold: int) -> int:
	var hero: PlayerBase = Game.level.player
	var step: int = st[1]
	if step >= STAIR_EDGES.size():
		return GameInput.keys_to_flags("R") if hero.sim_pos.x < STAIR_GOAL.x + 8 else 0
	match st[0]:
		0:
			# The hero stops within about 12 px after Right is released.
			if hero.sim_pos.x < STAIR_EDGES[step] - takeoff - 12:
				return GameInput.keys_to_flags("R")
			st[0] = 1
			st[3] = 0
		1:
			var risen: bool = columns[step].risen >= columns[step].rise
			st[3] = st[3] + 1 if hero.yvel == 0 and hero.xvel == 0 and risen else 0
			if st[3] >= 8:
				st[0] = 2
				st[2] = 0
		2:
			st[2] += 1
			if st[2] <= 24:
				return GameInput.keys_to_flags("RU" if st[2] <= hold else "U")
			st[0] = 3
			st[2] = 0
		_:
			st[2] += 1
			if hero.yvel == 0 and st[2] > 4:
				st[0] = 0
				st[1] += 1
	return 0


func _on_died(_cause: StringName) -> void:
	_deaths += 1
