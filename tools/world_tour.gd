extends SceneTree
## Camera tour of a level in the real level scene, for visual QA of the world module. Owner: world.
##
## Loads a level through Flow exactly like the game, freezes the simulation and moves the camera across the
## whole level in steps, saving a screenshot of every stop: tiles, props, parallax and entities as the player
## would see them, without needing a hero. Needs a window (not --headless):
##   bash .tools/gd.sh raw --path . -s res://tools/world_tour.gd -- --level=test_world_showcase
## Options:
##   --level=<id>        level to tour (required)
##   --size=<w>x<h>      window size in screen px (default 1280x720; 2400x1080 shows the 800 px wide phone view)
##   --step=<tiles>      camera step between shots (default: half a view)
##   --rows=<list>       camera rows to tour, comma-separated (default: top and bottom)
##   --out=<name>        folder under build/screenshots (default world_tour_<level>)
##   --frames=<n>        frames to let pass at every stop (default 3; liquids animate meanwhile)
## Output: build/screenshots/<out>/x<col>_y<row>.png (base-resolution frames). Exit code 0 = done, 2 = bad
## arguments, 3 = the level scene did not load.
##
## Autoloads are reached through the tree: this script is compiled before they exist.

const DEFAULT_SIZE: Vector2i = Vector2i(1280, 720)

var _flow: Node = null


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var options: Dictionary = {}
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--") and argument.contains("="):
			options[argument.substr(2, argument.find("=") - 2)] = argument.get_slice("=", 1)
	var level_id: String = str(options.get("level", ""))
	if level_id == "" or DisplayServer.get_name() == "headless":
		print("world_tour: --level=<id> is required and a window is needed (not --headless)")
		_finish(2)
		return
	var size: Vector2i = DEFAULT_SIZE
	if options.has("size"):
		var parts: PackedStringArray = str(options["size"]).split("x")
		if parts.size() == 2:
			size = Vector2i(parts[0].to_int(), parts[1].to_int())
	DisplayServer.window_set_size(size)
	_flow = root.get_node("Flow")
	_flow.set("instant_transitions", true)
	root.get_node("Game").call("new_game", 0)
	_flow.call("start_level", StringName(level_id), 0)
	await _flow.transition_finished
	for i: int in 4:
		await process_frame
	var level: Node = current_scene
	if level == null or not level.has_method("get_camera"):
		print("world_tour: the level scene did not load")
		_finish(3)
		return
	var sim: Node = root.get_node("Sim")
	sim.call("stop")
	sim.set("manual", true)
	var camera: RefCounted = level.call("get_camera")
	var view: Vector2i = camera.get("view")
	var low: Vector2i = camera.call("get_min")
	var high: Vector2i = camera.call("get_max")
	var step: int = maxi(str(options.get("step", "0")).to_int() * 16, 16)
	if not options.has("step"):
		step = maxi((view.x / 2) & ~15, 16)
	var ys: Array[int] = [low.y, high.y]
	if options.has("rows"):
		ys.clear()
		for row: String in str(options["rows"]).split(","):
			ys.append(clampi(row.to_int() * 16, low.y, high.y))
	var out: String = "res://build/screenshots/%s" % str(options.get("out", "world_tour_" + level_id))
	var out_dir: String = ProjectSettings.globalize_path(out)
	DirAccess.make_dir_recursive_absolute(out_dir)
	var frames: int = maxi(str(options.get("frames", "3")).to_int(), 1)
	var shots: int = 0
	var done_y: Dictionary = {}
	for y: int in ys:
		if done_y.has(y):
			continue
		done_y[y] = true
		var x: int = low.x
		while true:
			camera.set("pos", Vector2i(x, y))
			camera.set("prev", Vector2i(x, y))
			for i: int in frames:
				await process_frame
			await RenderingServer.frame_post_draw
			var image: Image = root.get_texture().get_image()
			var path: String = "%s/x%03d_y%03d.png" % [out_dir, x / 16, y / 16]
			if image != null and image.save_png(path) == OK:
				shots += 1
			if x >= high.x:
				break
			x = mini(x + step, high.x)
	print("world_tour: %d screenshot(s) of %s (view %s logical px) in %s" % [shots, level_id, view, out_dir])
	_finish(0)


func _finish(code: int) -> void:
	if _flow != null:
		_flow.call("shutdown_and_quit", code)
	else:
		quit(code)
