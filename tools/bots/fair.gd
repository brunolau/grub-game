extends SceneTree
## Development tool (tools/bots/fair.sh runs it in parallel and sums; PLAN.md 8 V4.b, DESIGN.md G80): the spawn fairness of one (arena, mode) bot set over any seeds, through the very round loop of
## tests/test_versus_bots.gd (its _play_round), with what each round left behind.
##   bash .tools/gd.sh script res://tools/bots/fair.gd -- arena=arena_sky_picnic mode=grub_stack \
##       [seeds=11,23,37 | first=12 | from=12 count=12] [detail=1] [level=1]
## One line per set: FAIR <arena> <mode> rounds=<n> wins=<per spawn> scores=<summed per spawn> draws=<n>

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var runner: Node = (load("res://tools/bots/fair_runner.gd") as GDScript).new() as Node
	runner.name = "Fair"
	root.add_child(runner)
	await runner.call(&"run", OS.get_cmdline_user_args())
	await process_frame
	var audio: Node = root.get_node_or_null("Audio")
	if audio != null and audio.has_method("shutdown"):
		audio.call("shutdown")
	await create_timer(0.25).timeout
	quit(0)
