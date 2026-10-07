extends SceneTree
## Nav-graph baker of the bots (docs/expansion/PLAN.md P1.2, DESIGN.md E.7, LEVEL_DESIGN.md 15.8). Owner: core-B.
##
## Usage (from the project root, through the shared runner):
##   bash .tools/gd.sh script res://tools/bots/bake_nav.gd -- [options] [level ids or .lvl files]
##   (no level)        every arena: levels/arena_*.lvl and levels/test_world_arena*.lvl
##   --out=<dir>       where the graphs go (default res://resources/bots): <dir>/<level_id>.json
##   --check           bake, do not write; exit 1 when a committed graph differs from the fresh bake (stale graph)
##   --verify          do not bake: re-simulate every link of the committed graph from every x of its window
##   --difficulty=<d>  beginner (default) or expert
##   --verbose         print the baker's progress every 1000 candidate runs
## Every link of a written graph was verified by simulating the real hero (NavBaker). Prints one line per level and
## the problems found; exit code 0 = all good, 1 = a problem (a level without a graph for --verify, a stale graph for
## --check, a link that fails), 2 = bad arguments.
## It is compiled before the autoloads exist, so the work happens in bake_nav_runner.gd.

const RUNNER: String = "res://tools/bots/bake_nav_runner.gd"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var runner: Node = (load(RUNNER) as GDScript).new() as Node
	runner.name = "BakeNav"
	root.add_child(runner)
	var code: int = runner.call(&"run", OS.get_cmdline_user_args())
	runner.queue_free()
	var audio: Node = root.get_node_or_null("Audio")
	if audio != null and audio.has_method("shutdown"):
		audio.call("shutdown")
	await create_timer(0.1).timeout
	quit(code)
