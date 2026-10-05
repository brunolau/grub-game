extends Node
## Performance probe of the autoplay harness (docs/ARCHITECTURE.md 9.2 and 11). Owner: core. Development only:
## Autoplay loads it for `--perf` in debug builds (with `--autoplay` or `--flow`); exports leave it out (folder
## `dev`), so it has no class_name.
##
## Every rendered frame it samples the Performance monitors and the rendering server and files the sample under a
## segment: the screen, plus the level id while a level runs ("level:w2_l1", "world_map", "title"). Per segment:
##   cpu        frame CPU time in ms = process time of this frame (a marker node that runs first stamps the start;
##              this probe runs last; Performance.TIME_PROCESS is a once-per-second maximum and is not used) +
##              render CPU time of the root viewport + frame setup time
##   gpu        GPU time of the root viewport in ms (when the driver reports it)
##   wall       time between two frames in ms (vsync included: a hitch shows up here)
##   draws      canvas draw calls of the frame; objects / primitives drawn
##   tick       cost of one simulation tick in microseconds (Sim.tick_started .. Sim.tick_finished)
##   entities   registered SimEntity and how many of them tick (the rest doze); awake enemies; dropped (moving)
##              items; items in view; thrown hero weapons; platforms in view; enemy projectiles; fx nodes
##   memory     texture memory, video memory, static memory (MB); objects, nodes, resources, orphan nodes
## Level loads: from the covered screen (Flow.transition_covered) to Events.level_started, and from the moment the
## level node enters the tree to Events.level_started (the level's own build).
## `--perf=profile` also times every _sim_tick call of the windowed game (Sim._profiler) and prints the cost per phase
## and class at the end ("Perf profile: ...") - the windowed share of each part, which a headless run cannot show.
## Leak check: SNAPSHOT_FRAMES frames after each arrival on the title or the world map the object, node, resource and
## orphan counts and static memory are recorded; compare the first and the last.
## Frames of the first WARMUP_FRAMES after a scene change are filed under "<segment>#warmup" (loading hitches).
## At the end: one summary line per segment ("Perf: ..."), the budget comparison ("Perf budget: ..."), the list of
## orphan nodes (Node.print_orphan_nodes) and <out>/perf.json.

const SNAPSHOT_FRAMES: int = 30
const WARMUP_FRAMES: int = 10
const MB: float = 1048576.0

## Budget of docs/ARCHITECTURE.md 11 (values the desktop run can check directly).
const BUDGET_DRAWS: int = 60
const BUDGET_AWAKE: int = 12
## Dropped bonus items (ObjTuning.MAX_DROPPED_ITEMS, the original's 32 slots) plus key items (at most 4).
const BUDGET_ITEMS: int = 36
const BUDGET_THROWN: int = 4
const BUDGET_PLATFORMS: int = 7
const BUDGET_ENTITIES: int = 200
const BUDGET_TICKING: int = 48
const BUDGET_TEXTURE_MB: float = 96.0
const BUDGET_CPU_MS: float = 8.0
const BUDGET_GPU_MS: float = 8.0
const BUDGET_TICK_MS: float = 2.0
const BUDGET_LOAD_MS: float = 2000.0


## Accumulated samples of one segment.
class Segment:
	extends RefCounted

	var frames: int = 0
	var cpu: PackedFloat32Array = PackedFloat32Array()
	var gpu: PackedFloat32Array = PackedFloat32Array()
	var wall: PackedFloat32Array = PackedFloat32Array()
	var draws: PackedInt32Array = PackedInt32Array()
	var ticks: PackedInt32Array = PackedInt32Array()
	var max_objects_drawn: int = 0
	var max_primitives: int = 0
	var max_entities: int = 0
	var max_ticking: int = 0
	var max_awake: int = 0
	var max_level_awake: int = 0
	var max_dropped: int = 0
	var max_items_in_view: int = 0
	var max_items_total: int = 0
	var max_thrown: int = 0
	var max_platforms_in_view: int = 0
	var max_enemy_projectiles: int = 0
	var max_fx: int = 0
	var max_nodes: int = 0
	var max_texture_mb: float = 0.0
	var max_video_mb: float = 0.0
	var max_static_mb: float = 0.0
	var grid: String = ""
	var process: PackedFloat32Array = PackedFloat32Array()
	var render: PackedFloat32Array = PackedFloat32Array()
	## Where the most draw calls happened: [draws, tick, hero x, hero y].
	var draws_at: Array = [0, 0, 0, 0]


## Runs before every other _process and stamps the start of the frame's process step.
class FrameStart:
	extends Node

	var usec: int = 0

	func _init() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		process_priority = -100000

	func _process(_delta: float) -> void:
		usec = Time.get_ticks_usec()


const TOP_COUNT: int = 12

var _frame_start: FrameStart = null
var _tick_scenes: int = 0
var _tick_streams: int = 0
## Ticks that loaded a scene or a sound for the first time: [cost us, segment, tick, what].
var _first_loads: Array[Array] = []
## The worst ticks and frames: [value, segment, tick, hero x, hero y].
var _top_ticks: Array[Array] = []
var _top_frames: Array[Array] = []
var _out_dir: String = ""
var _segments: Dictionary = {}
var _order: PackedStringArray = PackedStringArray()
var _last_usec: int = 0
var _tick_start: int = 0
var _pending_ticks: PackedInt32Array = PackedInt32Array()
## Most entities that ticked at the end of a tick since the last frame (sampled per tick: before a level's first
## tick nothing dozes yet).
var _pending_ticking: int = 0
var _since_change: int = 0
var _snapshot_in: int = -1
var _snapshot_where: String = ""
var _snapshots: Array[Dictionary] = []
var _loads: Array[Dictionary] = []
var _covered_usec: int = 0
var _added_usec: int = 0
var _viewport_rid: RID = RID()
var _written: bool = false
var _layers_mode: bool = false
var _layers_done: Dictionary = {}
var _layers_busy: bool = false
var _last_draws: int = 0
## --perf=profile: "phase|script" -> PackedInt64Array [calls, usec], and the ticks profiled.
var _profile_calls: Dictionary = {}
var _profile_ticks: int = 0


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# After every other _process: the frame's work is done when the sample is taken.
	process_priority = 100000


## Start sampling; `out_dir` is the absolute output folder of the run. `mode` "layers" (`--perf=layers`) also
## attributes the draw calls of every level once: each layer of the level and each overlay is hidden for a few
## frames and the drop in draw calls is printed ("Perf layers: ...").
func begin(out_dir: String, mode: String = "") -> void:
	_out_dir = out_dir
	_layers_mode = mode == "layers"
	if mode == "profile":
		Sim._profiler = self
	_frame_start = FrameStart.new()
	_frame_start.name = "PerfFrameStart"
	add_child(_frame_start)
	_viewport_rid = get_tree().root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(_viewport_rid, true)
	Sim.tick_started.connect(_on_tick_started)
	Sim.tick_finished.connect(_on_tick_finished)
	Flow.transition_covered.connect(_on_covered)
	Flow.screen_changed.connect(_on_screen_changed)
	Events.level_started.connect(_on_level_started)
	Autoplay.finished.connect(_on_finished)
	_last_usec = Time.get_ticks_usec()
	print("Perf: probe on (desktop measurement; budget of docs/ARCHITECTURE.md 11)")


func _process(_delta: float) -> void:
	var now: int = Time.get_ticks_usec()
	var wall_ms: float = float(now - _last_usec) / 1000.0
	_last_usec = now
	_since_change += 1
	var key: String = _segment_key()
	if _since_change <= WARMUP_FRAMES:
		key += "#warmup"
	var seg: Segment = _segment(key)
	seg.frames += 1
	var process_ms: float = float(now - _frame_start.usec) / 1000.0 if _frame_start.usec > 0 else 0.0
	var render_cpu_ms: float = RenderingServer.viewport_get_measured_render_time_cpu(_viewport_rid) \
			+ RenderingServer.get_frame_setup_time_cpu()
	seg.process.append(process_ms)
	seg.render.append(render_cpu_ms)
	seg.cpu.append(process_ms + render_cpu_ms)
	seg.gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(_viewport_rid))
	seg.wall.append(wall_ms)
	var draws: int = RenderingServer.viewport_get_render_info(_viewport_rid,
			RenderingServer.VIEWPORT_RENDER_INFO_TYPE_CANVAS, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME)
	draws = maxi(draws, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
	_last_draws = draws
	if _layers_mode and not _layers_busy and key.begins_with("level:") and not key.ends_with("#warmup") \
			and not _layers_done.has(key):
		_layers_done[key] = true
		_attribute_layers(key)
	seg.draws.append(draws)
	var hero: Vector2i = _hero_pos()
	if draws > int(seg.draws_at[0]):
		seg.draws_at = [draws, Sim.tick, hero.x, hero.y]
	if not key.ends_with("#warmup"):
		_keep_top(_top_frames, [process_ms + render_cpu_ms, key, Sim.tick, hero.x, hero.y])
	for t: int in _pending_ticks:
		_keep_top(_top_ticks, [float(t), key, Sim.tick, hero.x, hero.y])
	seg.max_objects_drawn = maxi(seg.max_objects_drawn, RenderingServer.viewport_get_render_info(_viewport_rid,
			RenderingServer.VIEWPORT_RENDER_INFO_TYPE_CANVAS, RenderingServer.VIEWPORT_RENDER_INFO_OBJECTS_IN_FRAME))
	seg.max_primitives = maxi(seg.max_primitives, RenderingServer.viewport_get_render_info(_viewport_rid,
			RenderingServer.VIEWPORT_RENDER_INFO_TYPE_CANVAS, RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME))
	for t: int in _pending_ticks:
		seg.ticks.append(t)
	_pending_ticks.clear()
	seg.max_texture_mb = maxf(seg.max_texture_mb, Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / MB)
	seg.max_video_mb = maxf(seg.max_video_mb, Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / MB)
	seg.max_static_mb = maxf(seg.max_static_mb, Performance.get_monitor(Performance.MEMORY_STATIC) / MB)
	seg.max_nodes = maxi(seg.max_nodes, int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)))
	_sample_level(seg)
	if _snapshot_in > 0:
		_snapshot_in -= 1
		if _snapshot_in == 0:
			_take_snapshot()


func _sample_level(seg: Segment) -> void:
	var level: LevelBase = Game.level
	if not is_instance_valid(level) or Flow.current_screen != Flow.SCREEN_LEVEL:
		return
	if seg.grid.is_empty() and level.grid != null:
		seg.grid = "%dx%d" % [level.grid.cols, level.grid.rows]
	seg.max_entities = maxi(seg.max_entities, Sim.get_entity_count())
	seg.max_ticking = maxi(seg.max_ticking, _pending_ticking)
	_pending_ticking = 0
	seg.max_level_awake = maxi(seg.max_level_awake, level.active_enemies)
	var awake: int = 0
	for entity: SimEntity in level.get_kind(Defs.Kind.ENEMY):
		var enemy: EnemyBase = entity as EnemyBase
		if enemy != null and enemy.awake and not enemy.dead:
			awake += 1
	seg.max_awake = maxi(seg.max_awake, awake)
	var dropped: int = 0
	var in_view: int = 0
	var items: Array[SimEntity] = level.get_kind(Defs.Kind.COLLECTIBLE)
	for entity: SimEntity in items:
		var item: CollectibleBase = entity as CollectibleBase
		if item == null or item.collected:
			continue
		if item.dropped:
			dropped += 1
		if level.is_in_view(item):
			in_view += 1
	seg.max_dropped = maxi(seg.max_dropped, dropped)
	seg.max_items_in_view = maxi(seg.max_items_in_view, in_view)
	seg.max_items_total = maxi(seg.max_items_total, items.size())
	seg.max_thrown = maxi(seg.max_thrown, level.get_kind(Defs.Kind.HERO_PROJECTILE).size())
	seg.max_enemy_projectiles = maxi(seg.max_enemy_projectiles, level.get_kind(Defs.Kind.ENEMY_PROJECTILE).size())
	seg.max_fx = maxi(seg.max_fx, level.get_kind(Defs.Kind.FX).size())
	var platforms: int = 0
	for entity: SimEntity in level.get_kind(Defs.Kind.PLATFORM):
		if level.is_in_view(entity):
			platforms += 1
	seg.max_platforms_in_view = maxi(seg.max_platforms_in_view, platforms)


## Hide every layer of the running level and every overlay in turn and print how many draw calls each one costs.
func _attribute_layers(key: String) -> void:
	_layers_busy = true
	var targets: Array[CanvasItem] = []
	var names: PackedStringArray = PackedStringArray()
	var level: Node = Game.level
	for child: Node in level.get_children():
		if child is CanvasItem and (child as CanvasItem).visible:
			targets.append(child as CanvasItem)
			names.append(String(child.name))
	for layer: int in [Defs.LAYER_HUD, Defs.LAYER_TOUCH, Defs.LAYER_MENU]:
		for child: Node in Flow.get_overlay(layer).get_children():
			if child is CanvasItem and (child as CanvasItem).visible:
				targets.append(child as CanvasItem)
				names.append("overlay:" + String(child.name))
	for i: int in 3:
		await get_tree().process_frame
	var base: int = _last_draws
	var parts: PackedStringArray = PackedStringArray()
	for i: int in targets.size():
		var item: CanvasItem = targets[i]
		if not is_instance_valid(item):
			continue
		item.visible = false
		for f: int in 3:
			await get_tree().process_frame
		var without: int = _last_draws
		if is_instance_valid(item):
			item.visible = true
		for f: int in 2:
			await get_tree().process_frame
		var children: int = item.get_child_count()
		parts.append("%s %d (%d children)" % [names[i], base - without, children])
	print("Perf layers %s: %d draw calls; cost per layer: %s" % [key, base, ", ".join(parts)])
	_layers_busy = false


func _hero_pos() -> Vector2i:
	var level: LevelBase = Game.level
	if is_instance_valid(level) and level.player != null:
		return level.player.sim_pos
	return Vector2i(-1, -1)


## Keep the TOP_COUNT largest entries (by entry[0]) of `list`.
func _keep_top(list: Array[Array], entry: Array) -> void:
	if list.size() >= TOP_COUNT and float(entry[0]) <= float(list[list.size() - 1][0]):
		return
	var at: int = list.size()
	for i: int in list.size():
		if float(entry[0]) > float(list[i][0]):
			at = i
			break
	list.insert(at, entry)
	if list.size() > TOP_COUNT:
		list.resize(TOP_COUNT)


func _segment_key() -> String:
	var screen: String = String(Flow.current_screen)
	if Flow.current_screen == Flow.SCREEN_LEVEL and is_instance_valid(Game.level):
		return "level:%s" % Game.level.level_id
	return screen


func _segment(key: String) -> Segment:
	if not _segments.has(key):
		_segments[key] = Segment.new()
		_order.append(key)
	return _segments[key]


func _on_tick_started(_tick: int) -> void:
	_tick_scenes = Spawner._cache.size()
	_tick_streams = Audio._streams.size()
	_tick_start = Time.get_ticks_usec()


func _on_tick_finished(tick: int) -> void:
	var cost: int = Time.get_ticks_usec() - _tick_start
	# Stay the LAST handler of tick_finished (a new level connects its own end-of-tick step after this probe), so
	# that the measured tick includes every handler (the harness's trace row too, a few microseconds). Reconnected
	# after the time is taken: the reconnection is the probe's own cost.
	Sim.tick_finished.disconnect(_on_tick_finished)
	Sim.tick_finished.connect(_on_tick_finished)
	if _tick_start <= 0:
		return
	_pending_ticks.append(cost)
	_pending_ticking = maxi(_pending_ticking, Sim.get_awake_count())
	_tick_start = 0
	# What a tick loaded for the first time (the usual cause of a slow tick): new scenes and sounds.
	var loaded: PackedStringArray = PackedStringArray()
	if Spawner._cache.size() > _tick_scenes:
		for id: Variant in Spawner._cache.keys().slice(_tick_scenes):
			loaded.append("scene " + str(id))
	if Audio._streams.size() > _tick_streams:
		for path: Variant in Audio._streams.keys().slice(_tick_streams):
			loaded.append("sound " + str(path).get_file())
	if not loaded.is_empty():
		_first_loads.append([cost, _segment_key(), tick, ", ".join(loaded)])


## Sim._profiler callbacks (--perf=profile).
func add_call(phase: int, script: Script, usec: int) -> void:
	_profile_add("%s|%s" % [Defs.Phase.keys()[phase], script.resource_path.get_file() if script != null else "?"], usec)


func add_part(part: StringName, usec: int) -> void:
	if part == &"begin: input, snapshot":
		_profile_ticks += 1
	_profile_add("TICK|" + String(part), usec)


func _profile_add(key: String, usec: int) -> void:
	var entry: PackedInt64Array = _profile_calls.get(key, PackedInt64Array([0, 0]))
	entry[0] += 1
	entry[1] += usec
	_profile_calls[key] = entry


func _print_profile() -> void:
	var rows: Array[Array] = []
	for key: String in _profile_calls:
		var entry: PackedInt64Array = _profile_calls[key]
		rows.append([key, entry[0], entry[1]])
	rows.sort_custom(func(a: Array, b: Array) -> bool: return int(a[2]) > int(b[2]))
	var ticks: float = maxf(float(_profile_ticks), 1.0)
	print("Perf profile: %d ticks, usec per tick by phase|script (calls per tick, usec per call)" % _profile_ticks)
	for row: Array in rows.slice(0, 40):
		print("Perf profile: %-44s %7.2f us/tick  %6.2f calls/tick  %6.2f us/call" % [row[0], float(row[2]) / ticks,
				float(row[1]) / ticks, float(row[2]) / maxf(float(row[1]), 1.0)])


func _on_covered() -> void:
	_covered_usec = Time.get_ticks_usec()
	_added_usec = 0
	if not get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.connect(_on_node_added)


func _on_node_added(node: Node) -> void:
	if node is LevelBase and _added_usec == 0:
		_added_usec = Time.get_ticks_usec()


func _on_level_started(level_id: StringName) -> void:
	var now: int = Time.get_ticks_usec()
	if get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.disconnect(_on_node_added)
	if _covered_usec == 0:
		return
	var level: LevelBase = Game.level
	_loads.append({
		"level": String(level_id),
		"covered_to_started_ms": float(now - _covered_usec) / 1000.0,
		"build_ms": float(now - _added_usec) / 1000.0 if _added_usec > 0 else -1.0,
		"entities": Sim.get_entity_count(),
		"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"grid": "%dx%d" % [level.grid.cols, level.grid.rows] if is_instance_valid(level) else "",
	})
	print("Perf: load %s %.1f ms (level build %.1f ms), %d entities registered" % [level_id,
			float(now - _covered_usec) / 1000.0, float(now - _added_usec) / 1000.0 if _added_usec > 0 else -1.0,
			Sim.get_entity_count()])
	_covered_usec = 0


func _on_screen_changed(screen: StringName) -> void:
	_since_change = 0
	if screen == Flow.SCREEN_TITLE or screen == Flow.SCREEN_WORLD_MAP:
		_snapshot_in = SNAPSHOT_FRAMES
		_snapshot_where = String(screen)


func _take_snapshot() -> void:
	var snap: Dictionary = {
		"where": _snapshot_where,
		"ticks_total": Sim.total_ticks,
		"objects": int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"resources": int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)),
		"orphans": int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
		"static_mb": Performance.get_monitor(Performance.MEMORY_STATIC) / MB,
		"texture_mb": Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / MB,
		"video_mb": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / MB,
	}
	_snapshots.append(snap)
	print("Perf: snapshot %-9s objects %d nodes %d resources %d orphans %d static %.1f MB texture %.1f MB" % [
		snap["where"], snap["objects"], snap["nodes"], snap["resources"], snap["orphans"], snap["static_mb"],
		snap["texture_mb"]])


func _on_finished(_exit_code: int) -> void:
	if _written:
		return
	_written = true
	if Sim._profiler == self:
		Sim._profiler = null
		_print_profile()
	_take_snapshot()
	var report: Dictionary = {"segments": {}, "loads": _loads, "snapshots": _snapshots}
	var worst: Dictionary = {}
	for key: String in _order:
		var seg: Segment = _segments[key]
		var row: Dictionary = _summarise(seg)
		report["segments"][key] = row
		print("Perf: %-16s %5d fr  cpu avg %.2f p99 %.2f max %.2f ms (process avg %.2f p99 %.2f, render avg %.2f p99 %.2f) | gpu avg %.2f max %.2f | wall avg %.1f max %.1f | draws avg %.0f max %d at tick %d hero %d,%d | tick avg %d p99 %d max %d us | ent %d ticking %d awake %d/%d drop %d view-items %d thrown %d plat %d eproj %d fx %d | tex %.1f vid %.1f static %.1f MB | grid %s" % [
			key, seg.frames, row["cpu_avg"], row["cpu_p99"], row["cpu_max"], row["process_avg"], row["process_p99"],
			row["render_avg"], row["render_p99"], row["gpu_avg"], row["gpu_max"], row["wall_avg"],
			row["wall_max"], row["draws_avg"], row["draws_max"], seg.draws_at[1], seg.draws_at[2], seg.draws_at[3],
			row["tick_avg_us"], row["tick_p99_us"], row["tick_max_us"],
			seg.max_entities, seg.max_ticking, seg.max_awake, seg.max_level_awake, seg.max_dropped, seg.max_items_in_view,
			seg.max_thrown, seg.max_platforms_in_view, seg.max_enemy_projectiles, seg.max_fx, seg.max_texture_mb,
			seg.max_video_mb, seg.max_static_mb, seg.grid])
		if key.ends_with("#warmup"):
			continue
		_worst(worst, "cpu_p99_ms", row["cpu_p99"], key)
		_worst(worst, "cpu_max_ms", row["cpu_max"], key)
		_worst(worst, "gpu_max_ms", row["gpu_max"], key)
		_worst(worst, "draws_max", row["draws_max"], key)
		_worst(worst, "tick_max_us", row["tick_max_us"], key)
		_worst(worst, "awake_max", seg.max_awake, key)
		_worst(worst, "dropped_max", seg.max_dropped, key)
		_worst(worst, "items_in_view_max", seg.max_items_in_view, key)
		_worst(worst, "thrown_max", seg.max_thrown, key)
		_worst(worst, "platforms_in_view_max", seg.max_platforms_in_view, key)
		_worst(worst, "entities_max", seg.max_entities, key)
		_worst(worst, "ticking_max", seg.max_ticking, key)
		_worst(worst, "texture_mb_max", seg.max_texture_mb, key)
		_worst(worst, "static_mb_max", seg.max_static_mb, key)
	var load_max: float = 0.0
	var load_at: String = ""
	for entry: Dictionary in _loads:
		if float(entry["covered_to_started_ms"]) > load_max:
			load_max = float(entry["covered_to_started_ms"])
			load_at = str(entry["level"])
	worst["load_max_ms"] = [load_max, load_at]
	report["worst"] = worst
	report["top_ticks_us"] = _top_ticks
	report["top_frames_ms"] = _top_frames
	report["first_loads_in_tick"] = _first_loads
	var load_cost: int = 0
	for entry: Array in _first_loads:
		load_cost += int(entry[0])
		if int(entry[0]) >= 1000:
			print("Perf: first load in tick %6d us  %-16s tick %5d: %s" % [entry[0], entry[1], entry[2], entry[3]])
	print("Perf: %d tick(s) loaded a scene or sound for the first time (%.1f ms in total)" % [_first_loads.size(),
			float(load_cost) / 1000.0])
	for entry: Array in _top_ticks:
		print("Perf: slow tick %8.0f us  %-16s tick %5d hero %d,%d" % [entry[0], entry[1], entry[2], entry[3],
				entry[4]])
	for entry: Array in _top_frames:
		print("Perf: slow frame %7.2f ms  %-16s tick %5d hero %d,%d" % [entry[0], entry[1], entry[2], entry[3],
				entry[4]])
	_budget("draw calls", worst, "draws_max", BUDGET_DRAWS)
	_budget("frame CPU p99 ms (desktop)", worst, "cpu_p99_ms", BUDGET_CPU_MS)
	_budget("GPU max ms (desktop)", worst, "gpu_max_ms", BUDGET_GPU_MS)
	_budget("tick max ms (desktop)", worst, "tick_max_us", BUDGET_TICK_MS * 1000.0)
	_budget("awake enemies", worst, "awake_max", BUDGET_AWAKE)
	_budget("dropped items", worst, "dropped_max", BUDGET_ITEMS)
	_budget("thrown weapons", worst, "thrown_max", BUDGET_THROWN)
	_budget("platforms in view", worst, "platforms_in_view_max", BUDGET_PLATFORMS)
	_budget("registered SimEntity", worst, "entities_max", BUDGET_ENTITIES)
	_budget("ticking SimEntity", worst, "ticking_max", BUDGET_TICKING)
	_budget("texture MB", worst, "texture_mb_max", BUDGET_TEXTURE_MB)
	_budget("level load ms (desktop)", worst, "load_max_ms", BUDGET_LOAD_MS)
	if _snapshots.size() >= 2:
		var first: Dictionary = _snapshots[0]
		var last: Dictionary = _snapshots[_snapshots.size() - 1]
		print("Perf: leak check %s -> %s: objects %+d, nodes %+d, resources %+d, orphans %+d, static %+.1f MB" % [
			first["where"], last["where"], int(last["objects"]) - int(first["objects"]),
			int(last["nodes"]) - int(first["nodes"]), int(last["resources"]) - int(first["resources"]),
			int(last["orphans"]) - int(first["orphans"]), float(last["static_mb"]) - float(first["static_mb"])])
	report["textures_still_loaded"] = _loaded_textures()
	if OS.is_debug_build():
		print("Perf: orphan nodes now:")
		Node.print_orphan_nodes()
	var file: FileAccess = FileAccess.open(_out_dir + "/perf.json", FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "\t"))
		file.close()
		print("Perf: report %s/perf.json" % _out_dir)


## Textures under res://assets that are still in the resource cache now (someone holds them), by folder, with their
## size as RGBA8 in MB (what they take as uncompressed textures).
func _loaded_textures() -> Dictionary:
	var by_folder: Dictionary = {}
	var total: float = 0.0
	var pending: PackedStringArray = PackedStringArray(["res://assets"])
	while not pending.is_empty():
		var dir: String = pending[pending.size() - 1]
		pending.remove_at(pending.size() - 1)
		for entry: String in ResourceLoader.list_directory(dir):
			var path: String = dir + "/" + entry
			if entry.ends_with("/"):
				pending.append(path.trim_suffix("/"))
				continue
			if entry.get_extension() != "png" or not ResourceLoader.has_cached(path):
				continue
			var texture: Texture2D = ResourceLoader.get_cached_ref(path) as Texture2D
			var mb: float = float(texture.get_width() * texture.get_height() * 4) / MB if texture != null else 0.0
			var folder: String = dir.trim_prefix("res://assets/")
			if not by_folder.has(folder):
				by_folder[folder] = [0.0, PackedStringArray()]
			by_folder[folder][0] = float(by_folder[folder][0]) + mb
			(by_folder[folder][1] as PackedStringArray).append(entry)
			total += mb
	print("Perf: textures still loaded at the end: %.1f MB (RGBA8)" % total)
	for folder: String in by_folder:
		print("Perf:   %-28s %6.1f MB  %s" % [folder, by_folder[folder][0], ", ".join(by_folder[folder][1])])
	return by_folder


func _summarise(seg: Segment) -> Dictionary:
	var cpu: PackedFloat32Array = seg.cpu.duplicate()
	cpu.sort()
	var ticks: PackedInt32Array = seg.ticks.duplicate()
	ticks.sort()
	var draws_sum: int = 0
	var draws_max: int = 0
	for d: int in seg.draws:
		draws_sum += d
		draws_max = maxi(draws_max, d)
	var process: PackedFloat32Array = seg.process.duplicate()
	process.sort()
	var render: PackedFloat32Array = seg.render.duplicate()
	render.sort()
	return {
		"frames": seg.frames,
		"cpu_avg": _avg(seg.cpu), "cpu_p99": _pct(cpu, 0.99), "cpu_max": _pct(cpu, 1.0),
		"process_avg": _avg(seg.process), "process_p99": _pct(process, 0.99),
		"render_avg": _avg(seg.render), "render_p99": _pct(render, 0.99),
		"gpu_avg": _avg(seg.gpu), "gpu_max": _max_f(seg.gpu), "wall_avg": _avg(seg.wall), "wall_max": _max_f(seg.wall),
		"draws_at": seg.draws_at,
		"draws_avg": float(draws_sum) / maxf(float(seg.draws.size()), 1.0), "draws_max": draws_max,
		"ticks": ticks.size(),
		"tick_avg_us": int(_avg_i(ticks)), "tick_p99_us": _pct_i(ticks, 0.99), "tick_max_us": _pct_i(ticks, 1.0),
		"entities_max": seg.max_entities, "ticking_max": seg.max_ticking, "awake_max": seg.max_awake, "level_awake_max": seg.max_level_awake,
		"dropped_max": seg.max_dropped, "items_in_view_max": seg.max_items_in_view,
		"items_registered_max": seg.max_items_total, "thrown_max": seg.max_thrown,
		"platforms_in_view_max": seg.max_platforms_in_view, "enemy_projectiles_max": seg.max_enemy_projectiles,
		"fx_max": seg.max_fx, "nodes_max": seg.max_nodes, "objects_drawn_max": seg.max_objects_drawn,
		"primitives_max": seg.max_primitives, "texture_mb_max": seg.max_texture_mb, "video_mb_max": seg.max_video_mb,
		"static_mb_max": seg.max_static_mb, "grid": seg.grid,
	}


func _worst(worst: Dictionary, name: String, value: float, key: String) -> void:
	if not worst.has(name) or float((worst[name] as Array)[0]) < value:
		worst[name] = [value, key]


func _budget(label: String, worst: Dictionary, name: String, limit: float) -> void:
	if not worst.has(name):
		return
	var entry: Array = worst[name]
	var value: float = float(entry[0])
	print("Perf budget: %-28s %10.2f (limit %.0f) at %-16s %s" % [label, value, limit, entry[1],
			"ok" if value <= limit else "OVER"])


func _avg(values: PackedFloat32Array) -> float:
	if values.is_empty():
		return 0.0
	var total: float = 0.0
	for v: float in values:
		total += v
	return total / float(values.size())


func _avg_i(values: PackedInt32Array) -> float:
	if values.is_empty():
		return 0.0
	var total: int = 0
	for v: int in values:
		total += v
	return float(total) / float(values.size())


func _max_f(values: PackedFloat32Array) -> float:
	var best: float = 0.0
	for v: float in values:
		best = maxf(best, v)
	return best


func _pct(sorted: PackedFloat32Array, fraction: float) -> float:
	if sorted.is_empty():
		return 0.0
	return sorted[clampi(int(ceil(fraction * float(sorted.size()))) - 1, 0, sorted.size() - 1)]


func _pct_i(sorted: PackedInt32Array, fraction: float) -> int:
	if sorted.is_empty():
		return 0
	return sorted[clampi(int(ceil(fraction * float(sorted.size()))) - 1, 0, sorted.size() - 1)]
