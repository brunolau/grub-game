extends SceneTree
## The versus soak, one process (docs/expansion/PLAN.md 7 P4.1; tools/bots/soak.sh runs the shards side by side and
## sums them). Seeded headless rounds with bots over every (mode, arena that lists it, 2 / 3 / 4 players), the real
## heroes and the real referee, every rule of the mode checked on every tick: see tools/bots/soak_runner.gd for the
## plan, the checks, the arguments and the lines it prints.
##   bash .tools/gd.sh script res://tools/bots/soak.gd -- cells=1                         the cell table
##   GD_TIMEOUT=3000 bash .tools/gd.sh script res://tools/bots/soak.gd -- rounds=40       a short soak, one process
##   bash .tools/gd.sh script res://tools/bots/soak.gd -- mode=hot_rock arena=arena_echo_hollow players=3 seed=4017 \
##       round=2 detail=1                                                                 one round: an anomaly's replay
## Exit code 0 = no anomaly, 1 = anomalies (or an unknown mode). It is compiled before the autoloads exist, so the
## work happens in soak_runner.gd.

const RUNNER: String = "res://tools/bots/soak_runner.gd"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var runner: Node = (load(RUNNER) as GDScript).new() as Node
	runner.name = "Soak"
	root.add_child(runner)
	var anomalies: int = await runner.call(&"run", OS.get_cmdline_user_args())
	runner.queue_free()
	await process_frame
	var audio: Node = root.get_node_or_null("Audio")
	if audio != null and audio.has_method("shutdown"):
		audio.call("shutdown")
	await create_timer(0.25).timeout
	quit(1 if anomalies > 0 else 0)
