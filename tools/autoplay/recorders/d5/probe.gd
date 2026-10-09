extends SceneTree
## D5 development probe (not part of the game; build/ is not versioned). Bootstrap only: the work is in
## probe_work.gd, loaded after the autoloads exist (adapted from DB1's probe).
##   bash .tools/gd.sh script res://tools/autoplay/recorders/d5/probe.gd -- --level=<draft paths> [--validate] [--search[=gate]]
##       [--signs=<po>] [--route=<file> --dir=<route dir> --mode=beginner --every=10]
##       [--rec=<macro script> --mode=beginner]

const WORK: String = "res://tools/autoplay/recorders/d5/probe_work.gd"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var script: GDScript = load(WORK) as GDScript
	if script == null or not script.can_instantiate():
		quit(2)
		return
	var work: Node = script.new() as Node
	work.name = "D5Probe"
	root.add_child(work)
	var code: int = await work.call(&"run", OS.get_cmdline_user_args())
	var audio: Node = root.get_node_or_null("Audio")
	if audio != null and audio.has_method("shutdown"):
		audio.call("shutdown")
	await create_timer(0.25).timeout
	quit(code)
