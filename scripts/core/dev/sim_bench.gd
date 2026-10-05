extends SceneTree
## Headless route bench of the simulation (docs/ARCHITECTURE.md 11). Owner: core. Development only (folder `dev`,
## never exported). Replays the route files of tests/test_campaign_routes.gd through Flow and the real level scene,
## exactly as that test does, and reports what every tick costs; optionally writes a digest of the simulation state
## after every tick (the proof that an optimisation changed no outcome) and a per-class profile of the tick.
##
## Usage (from the project root, through the shared runner):
##   bash .tools/gd.sh script res://scripts/core/dev/sim_bench.gd -- [options] [route files or prefixes]
##   --make-snapshot=<dir>   copy levels/*.lvl, tools/autoplay/routes/*.inputs and the route table to <dir> (under
##                           res://build) and stop: later runs replay that frozen content, unaffected by level edits
##   --snapshot=<dir>        replay the levels, routes and route table of a snapshot instead of the live files
##   --out=<dir>             where digests and bench.json go (default res://build/perf/bench)
##   --digest                write <out>/<route>.<mode>.digest: one line per tick (state hash, hero, score, RNG)
##   --profile               time every _sim_tick call (Sim._profiler) and print the cost per phase and class
##   --tight                 step the ticks in a tight loop like the headless tests (default: one rendered frame
##                           between two ticks, as the windowed game runs them)
##   --repeat=<n>            play every route n times (timing only; digests are written by the first pass)
## Route arguments: file names of the route table ("w1_l1.inputs") or prefixes ("w2_"); default: every route that
## is not only played chained behind another one. Prints one line per played stage and a summary; exit code 0.
## It is compiled before the autoloads exist, so the work happens in sim_bench_runner.gd.

const RUNNER: String = "res://scripts/core/dev/sim_bench_runner.gd"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var runner: Node = (load(RUNNER) as GDScript).new() as Node
	runner.name = "SimBench"
	root.add_child(runner)
	var code: int = await runner.call(&"run", OS.get_cmdline_user_args())
	var audio: Node = root.get_node_or_null("Audio")
	if audio != null and audio.has_method("shutdown"):
		audio.call("shutdown")
	await create_timer(0.25).timeout
	quit(code)
