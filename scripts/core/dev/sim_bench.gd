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
##   --no-doze               every entity ticks all the time (LevelBase.doze_enabled = false)
##   --repeat=<n>            play every route n times (timing only; digests are written by the first pass)
##   --alone                 also play the chained entries marked `alone` from a fresh run, as the route test does
##                           (e.g. the fixture of "w2_l2b.inputs" in tests/fixtures/sp_digest/)
##   --dump=<level>:<tick>   print the doze state around that tick (the digest hash then also covers node names,
##                           so write such a run to its own --out)
##   --route-dir=<dir>       where the 2.0 header routes are read (default res://tools/autoplay/routes/; e.g.
##                           res://tests/fixtures/routes/): every route file whose first line is a `# route:` header
##                           (docs/LEVEL_DESIGN.md 15.9) is played as its header says - a party of `players` heroes
##                           with one input stream each, its `belt` - besides the 1.0 ROUTES table
##   --belt-invariance       the belt-invariance runner (PLAN.md 8 V2.b): every selected header club route is replayed
##                           with an empty belt and with the hammer, the axe, the swirling axe and the spear on every
##                           hero's belt; the per-tick digests must not differ. Exit code 1 when one does
## Route arguments: file names of the route table ("w1_l1.inputs") or prefixes ("w2_"); default: every route that
## is not only played chained behind another one. Prints one line per played stage and a summary; exit code 0.
## Single-player identity (docs/expansion/TECH_AUDIT.md 4.12): tools/sp_identity.sh runs the digests against the
## frozen baseline in build/mp_baseline and diffs them with build/mp_digest_before*.
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
