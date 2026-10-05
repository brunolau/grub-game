extends TestCase
## Dozing (ARCHITECTURE.md 11): Sim.suspend / resume keep the tick exact, the level's doze manager takes far, idle
## entities out of the tick and brings them back as if they had ticked all along, and a real route plays tick for
## tick the same with and without it. Also the desktop fullscreen shortcut and the background loading of Flow.

const ROUTE_LEVEL: StringName = &"w2_l1"
const ROUTE_FILE: String = "res://tools/autoplay/routes/w2_l1.inputs"
const ROUTE_TICKS: int = 1500
## Logical view of the 1280 x 720 game window (integer scale 2), as the route tests use it.
const VIEW: Vector2i = Vector2i(Tuning.VIEW_W, Tuning.VIEW_H)


## Records its phase calls into a shared list; can suspend / resume / free other probes while it is called.
class Probe:
	extends SimEntity

	var label: String = ""
	var phases: PackedInt32Array = PackedInt32Array()
	var calls: Array[String] = []
	var suspend_on_call: SimEntity = null
	var resume_on_call: SimEntity = null
	var free_on_call: SimEntity = null

	func _sim_phases() -> PackedInt32Array:
		return phases

	func _sim_tick(phase: int) -> void:
		calls.append("%s:%d" % [label, phase])
		if suspend_on_call != null:
			Sim.suspend(suspend_on_call)
			suspend_on_call = null
		if resume_on_call != null:
			Sim.resume(resume_on_call)
			resume_on_call = null
		if free_on_call != null and is_instance_valid(free_on_call):
			free_on_call.free()
			free_on_call = null


## A bare level whose view can be moved by the test.
class ViewLevel:
	extends LevelBase

	var view: Rect2i = Rect2i(0, 0, Tuning.VIEW_W, Tuning.VIEW_H)

	func get_view_rect() -> Rect2i:
		return view


var _route_view_ok: bool = true


func after_each() -> void:
	LevelBase.doze_enabled = true
	Flow.background_loading = false
	GameInput.clear_scripted()
	Sim.manual = false
	Sim.stop()
	if get_tree().current_scene != null and get_tree().current_scene != self:
		get_tree().current_scene.free()
		get_tree().current_scene = null
	Flow.current_screen = Flow.SCREEN_BOOT
	Flow.args = {}
	super.after_each()


func _probe(label: String, phases: Array[int], calls: Array[String]) -> Probe:
	var probe: Probe = Probe.new()
	probe.label = label
	probe.phases = PackedInt32Array(phases)
	probe.calls = calls
	return probe


func _view_level(cols: int = 400, rows: int = 24, ground_row: int = 20) -> ViewLevel:
	var lines: PackedStringArray = PackedStringArray()
	for row: int in rows:
		lines.append((TileGrid.CH_SOLID_A if row >= ground_row else TileGrid.CH_AIR).repeat(cols))
	var level: ViewLevel = ViewLevel.new()
	level.level_id = &"test"
	level.grid = TileGrid.from_rows(lines, 0, 0)
	add_node(level)
	return level


# =================================================================================================================
# Sim.suspend / Sim.resume
# =================================================================================================================

func test_a_suspended_entity_keeps_its_place_in_the_order() -> void:
	var calls: Array[String] = []
	var a: Probe = _probe("a", [Defs.Phase.ENEMIES], calls)
	var b: Probe = _probe("b", [Defs.Phase.ENEMIES, Defs.Phase.POST], calls)
	var c: Probe = _probe("c", [Defs.Phase.ENEMIES], calls)
	for probe: Probe in [a, b, c]:
		add_node(probe)
	Sim.suspend(b)
	assert_true(b.is_dozing())
	assert_eq(Sim.get_entity_count() - Sim.get_awake_count(), 1, "still registered, not ticking")
	Sim.step(1)
	assert_eq(calls, ["a:2", "c:2"] as Array[String])
	calls.clear()
	Sim.resume(b)
	Sim.step(1)
	assert_eq(calls, ["a:2", "b:2", "c:2", "b:11"] as Array[String], "back at its place, in every phase")


func test_suspend_resume_and_free_inside_a_phase_are_exact() -> void:
	var calls: Array[String] = []
	var a: Probe = _probe("a", [Defs.Phase.ENEMIES], calls)
	var b: Probe = _probe("b", [Defs.Phase.ENEMIES], calls)
	var c: Probe = _probe("c", [Defs.Phase.ENEMIES, Defs.Phase.POST], calls)
	var d: Probe = _probe("d", [Defs.Phase.ENEMIES, Defs.Phase.POST], calls)
	var e: Probe = _probe("e", [Defs.Phase.ENEMIES], calls)
	for probe: Probe in [a, b, c, d, e]:
		add_node(probe)
	Sim.suspend(d)
	Sim.suspend(a)
	# b: resumes d (later in the order: it runs in this phase) and a (earlier: it does not), suspends c (later:
	# not called again); e frees nothing. Every other entity is called exactly once.
	b.resume_on_call = d
	b.suspend_on_call = c
	Sim.step(1)
	assert_eq(calls, ["b:2", "d:2", "e:2", "d:11"] as Array[String])
	calls.clear()
	b.resume_on_call = a
	Sim.step(1)
	assert_eq(calls, ["b:2", "d:2", "e:2", "d:11"] as Array[String], "a resumed behind the caller waits a tick")
	calls.clear()
	Sim.step(1)
	assert_eq(calls, ["a:2", "b:2", "d:2", "e:2", "d:11"] as Array[String])
	calls.clear()
	b.free_on_call = a
	e.free_on_call = d
	Sim.step(1)
	assert_eq(calls, ["a:2", "b:2", "d:2", "e:2"] as Array[String], "freed during the phase: gone at once")


func test_phase_runs_count_every_started_phase() -> void:
	var before: int = Sim.get_phase_runs(Defs.Phase.ITEMS)
	Sim.step(3)
	assert_eq(Sim.get_phase_runs(Defs.Phase.ITEMS), before + 3)


# =================================================================================================================
# The doze manager
# =================================================================================================================

func test_far_idle_items_doze_and_catch_up_their_age() -> void:
	Game.new_game(Defs.Difficulty.BEGINNER)
	var level: ViewLevel = _view_level()
	var hero: PlayerBase = PlayerBase.new()
	place(level, hero, Vector2i(100, 320))
	var near: CollectibleBase = CollectibleBase.new()
	var far: CollectibleBase = CollectibleBase.new()
	place(level, near, Vector2i(200, 320), {"points": 100})
	place(level, far, Vector2i(3000, 320), {"points": 100})
	Sim.step(1)
	assert_false(near.is_dozing())
	assert_true(far.is_dozing(), "far from the hero and the view")
	assert_false(far.on_screen)
	assert_true(level.get_dozing_count() >= 1)
	Sim.step(20)
	assert_eq(far.age, 0, "it dozed off before its first tick: a dozing item does not count")
	hero.teleport(Vector2i(3000, 320))
	level.view = Rect2i(2800, 160, Tuning.VIEW_W, Tuning.VIEW_H)
	Sim.step(1)
	assert_false(far.is_dozing(), "the hero came: it woke before the tick")
	assert_true(far.collected, "and was picked up in that very tick")
	assert_eq(Game.score, 100)


func test_a_dozing_item_wakes_with_the_age_it_would_have() -> void:
	Game.new_game(Defs.Difficulty.BEGINNER)
	var level: ViewLevel = _view_level()
	var hero: PlayerBase = PlayerBase.new()
	place(level, hero, Vector2i(100, 320))
	var near: CollectibleBase = CollectibleBase.new()
	var far: CollectibleBase = CollectibleBase.new()
	place(level, near, Vector2i(150, 320))
	place(level, far, Vector2i(3000, 320))
	Sim.step(15)
	assert_true(far.is_dozing())
	level.view = Rect2i(2800, 160, Tuning.VIEW_W, Tuning.VIEW_H)
	Sim.step(1)
	assert_false(far.is_dozing(), "the view came near")
	assert_eq(far.age, near.age, "it counts every tick it dozed")


func test_asleep_enemies_doze_far_away_and_wake_by_the_view() -> void:
	Game.new_game(Defs.Difficulty.BEGINNER)
	var level: ViewLevel = _view_level()
	var hero: PlayerBase = PlayerBase.new()
	place(level, hero, Vector2i(100, 320))
	var enemy: EnemyBase = EnemyBase.new()
	place(level, enemy, Vector2i(1200, 320))
	Sim.step(2)
	assert_true(enemy.is_dozing())
	assert_false(enemy.awake)
	# The view reaches the activation margin of the anchor: it wakes on the next tick, exactly as before.
	level.view = Rect2i(1200 - enemy.box_xo - Tuning.ENEMY_SPAWN_MARGIN_PX - Tuning.VIEW_W + 1, 160,
			Tuning.VIEW_W, Tuning.VIEW_H)
	Sim.step(1)
	assert_true(enemy.awake, "woke by the activation rule of GAMEPLAY.md 5.1")
	assert_false(enemy.is_dozing())


func test_no_doze_switch_keeps_every_entity_ticking() -> void:
	LevelBase.doze_enabled = false
	Game.new_game(Defs.Difficulty.BEGINNER)
	var level: ViewLevel = _view_level()
	var hero: PlayerBase = PlayerBase.new()
	place(level, hero, Vector2i(100, 320))
	var far: CollectibleBase = CollectibleBase.new()
	place(level, far, Vector2i(3000, 320))
	Sim.step(5)
	assert_false(far.is_dozing())
	assert_eq(far.age, 5)


## Every archetype that replaces the asleep / wake logic of EnemyBase must say how it dozes: otherwise the default
## rule (wakes by the view only) would let it doze while its own rule could fire.
func test_enemy_archetypes_declare_their_doze_rule() -> void:
	var hooks: PackedStringArray = ["func _asleep_tick(", "func _should_wake(", "func _sim_tick("]
	var rules: PackedStringArray = ["func _asleep_waits_for_view(", "func _can_doze(", "func _doze_area("]
	var paths: PackedStringArray = ["res://scripts/base/boss_base.gd"]
	for file: String in DirAccess.get_files_at("res://scripts/enemies"):
		if file.get_extension() == "gd":
			paths.append("res://scripts/enemies/" + file)
	for path: String in paths:
		var source: String = FileAccess.get_file_as_string(path)
		var overrides: bool = false
		for hook: String in hooks:
			overrides = overrides or source.contains(hook)
		if not overrides:
			continue
		var declares: bool = false
		for rule: String in rules:
			declares = declares or source.contains(rule)
		assert_true(declares, "%s replaces a wake hook and must declare its doze rule" % path)


## A real route with and without dozing: the same simulation, tick for tick. While it plays, every dozing entity
## is off the view and out of the hero's reach, and the hero never moves farther in one tick than the doze reach
## allows for (Tuning.DOZE_HERO_REACH_PX - Tuning.OVERLAP_MAX_DY), except through a teleport.
func test_a_route_plays_the_same_with_and_without_dozing() -> void:
	var with_doze: PackedStringArray = await _replay(true)
	var without: PackedStringArray = await _replay(false)
	assert_eq(with_doze.size(), ROUTE_TICKS, "the route played %d ticks" % with_doze.size())
	assert_eq(with_doze.size(), without.size())
	var first: int = -1
	for i: int in mini(with_doze.size(), without.size()):
		if with_doze[i] != without[i]:
			first = i
			break
	assert_eq(first, -1, "first differing tick: %d" % (first + 1))
	assert_true(_route_view_ok, "the invariants of dozing held on every tick")


func _replay(doze: bool) -> PackedStringArray:
	LevelBase.doze_enabled = doze
	_route_view_ok = true
	Game.new_game(Defs.Difficulty.BEGINNER)
	Sim.manual = true
	await _idle()
	Flow.start_level(ROUTE_LEVEL, Defs.Transition.NONE)
	await _settle()
	var level: Level = Game.level as Level
	assert_not_null(level)
	if level == null:
		return PackedStringArray()
	level.set_view_size(VIEW * Tuning.ART_SCALE)
	var flags: PackedInt32Array = Autoplay.parse_inputs(FileAccess.get_file_as_string(ROUTE_FILE))
	var index: Array[int] = [0]
	GameInput.set_scripted(func(_tick: int) -> int:
		var value: int = flags[index[0]] if index[0] < flags.size() else 0
		index[0] += 1
		return value
	)
	var rows: PackedStringArray = PackedStringArray()
	var teleports: Array[int] = [0]
	var on_gate: Callable = func(_from: Vector2i, _to: Vector2i) -> void: teleports[0] += 1
	var on_respawn: Callable = func() -> void: teleports[0] += 1
	Events.gate_used.connect(on_gate)
	Events.level_respawned.connect(on_respawn)
	var last_hero: Vector2i = level.player.sim_pos
	var last_teleports: int = 0
	while rows.size() < ROUTE_TICKS and Sim.running and Game.level == level:
		Sim.step(1)
		rows.append(_state_row(level))
		if doze and level.player != null:
			var hero: Vector2i = level.player.sim_pos
			var step: Vector2i = (hero - last_hero).abs()
			var reach: int = Tuning.DOZE_HERO_REACH_PX - Tuning.OVERLAP_MAX_DY
			# A gate or a respawn puts the hero elsewhere between two ticks (after the end-of-tick decision): the
			# start of the next tick decides again before any phase runs.
			var teleported: bool = teleports[0] != last_teleports
			if not teleported and (step.x > reach or step.y > reach):
				_route_view_ok = false
				fail("the hero moved %s in one tick at tick %d" % [step, rows.size()])
			last_hero = hero
			last_teleports = teleports[0]
			if not teleported:
				_check_dozers(level)
	Events.gate_used.disconnect(on_gate)
	Events.level_respawned.disconnect(on_respawn)
	GameInput.clear_scripted()
	Sim.stop()
	get_tree().current_scene.free()
	get_tree().current_scene = null
	Flow.current_screen = Flow.SCREEN_BOOT
	await _idle()
	return rows


func _check_dozers(level: LevelBase) -> void:
	var hero: Vector2i = level.player.sim_pos
	var reach: Rect2i = Rect2i(hero, Vector2i.ONE).grow(Tuning.OVERLAP_MAX_DY)
	for entity: SimEntity in level._doze:
		if not entity.is_dozing() or level._doze_screen_pending.has(entity):
			continue
		if entity.on_screen or entity._doze_area().intersects(reach):
			if _route_view_ok:
				fail("%s (%s) dozes on screen (%s) or within the hero's reach at tick %d: area %s, hero %s" % [
					entity.name, entity.get_script().resource_path.get_file(), entity.on_screen, Sim.tick,
					entity._doze_area(), hero])
			_route_view_ok = false


func _state_row(level: LevelBase) -> String:
	var state: Array = [Sim.rng.get_state(), Game.score, Game.lives, Game.hearts, Game.items_collected,
		Game.spots_opened, level.active_enemies, level.get_view_rect()]
	for kind: int in Defs.KIND_COUNT:
		if kind == Defs.Kind.FX:
			continue
		for entity: SimEntity in level.get_kind(kind):
			if not is_instance_valid(entity) or entity.is_queued_for_deletion():
				continue
			state.append_array([entity.sim_pos, entity.xvel, entity.yvel, entity.facing, entity.on_screen])
			var enemy: EnemyBase = entity as EnemyBase
			if enemy != null:
				state.append_array([enemy.awake, enemy.dead, enemy.hp])
			var item: CollectibleBase = entity as CollectibleBase
			if item != null:
				state.append(item.collected)
	return "%d %x" % [Sim.tick, hash(state)]


func _idle() -> void:
	await get_tree().process_frame
	while Flow.busy:
		await get_tree().process_frame


func _settle() -> void:
	for i: int in 3:
		await get_tree().process_frame
	while Flow.busy:
		await get_tree().process_frame


# =================================================================================================================
# Desktop fullscreen shortcut, background loading
# =================================================================================================================

func test_alt_enter_and_f11_toggle_fullscreen_and_persist() -> void:
	var f11: InputEventKey = InputEventKey.new()
	f11.keycode = KEY_F11
	f11.pressed = true
	assert_true(Settings.is_fullscreen_shortcut(f11))
	var enter: InputEventKey = InputEventKey.new()
	enter.keycode = KEY_ENTER
	enter.pressed = true
	assert_false(Settings.is_fullscreen_shortcut(enter), "plain Enter stays 'accept'")
	enter.alt_pressed = true
	assert_true(Settings.is_fullscreen_shortcut(enter))
	var keypad: InputEventKey = InputEventKey.new()
	keypad.keycode = KEY_KP_ENTER
	keypad.alt_pressed = true
	keypad.pressed = true
	assert_true(Settings.is_fullscreen_shortcut(keypad))
	f11.echo = true
	assert_false(Settings.is_fullscreen_shortcut(f11), "holding the key does not flip it again")
	f11.echo = false
	f11.pressed = false
	assert_false(Settings.is_fullscreen_shortcut(f11), "the release does nothing")
	var before: bool = Settings.get_bool("video/fullscreen")
	var seen: Array[String] = []
	var on_changed: Callable = func(key: String, _value: Variant) -> void: seen.append(key)
	Settings.changed.connect(on_changed)
	Settings.toggle_fullscreen()
	Settings.changed.disconnect(on_changed)
	assert_eq(Settings.get_bool("video/fullscreen"), not before)
	assert_true(seen.has("video/fullscreen"), "the Options row follows the change")
	Settings.load_settings()
	assert_eq(Settings.get_bool("video/fullscreen"), not before, "saved at once")
	Settings.toggle_fullscreen()
	assert_eq(Settings.get_bool("video/fullscreen"), before)


func test_background_loading_fills_the_caches_for_the_next_level() -> void:
	Spawner.clear_cache()
	Game.new_game(Defs.Difficulty.BEGINNER)
	Flow.background_loading = true
	Flow.warm_up(&"w1_l1")
	assert_true(Flow.is_warming_up(), "it returns at once and loads in the background")
	for i: int in 3:
		await get_tree().process_frame
	Flow.finish_warm_up()
	assert_false(Flow.is_warming_up())
	for id: StringName in [&"player/player", &"fx/star_puff", &"items/food", &"projectiles/hero_axe"]:
		assert_true(Spawner._cache.has(id), "%s is cached" % id)
	var data: LevelData = LevelData.load_file(Levels.get_level_path(&"w1_l1"))
	for record: Dictionary in data.entity_records():
		var id: StringName = record["id"]
		if not Spawner.is_prop(id) and LevelText.applies_to(record["params"], Game.difficulty):
			assert_true(Spawner._cache.has(id), "the level's %s is cached" % id)
	assert_true(ResourceLoader.has_cached(Flow.LEVEL_SCENE), "the level scene is kept")
	assert_true(ResourceLoader.has_cached(Flow.HUD_SCENE), "the HUD is kept")
