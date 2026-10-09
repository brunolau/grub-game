extends SceneTree
## D8 development probe (not part of the game; build/ is not versioned). Bootstrap only: the work is in
## probe_work.gd, loaded after the autoloads exist.
##   bash .tools/gd.sh script res://tools/autoplay/recorders/d6/probe.gd -- --level=res://build/d6/w/levels/w6_l1.lvl \
##       [--validate] [--search[=gate]] [--route=w6_l1.inputs --dir=res://build/d6/w/routes/ --mode=beginner]
##       [--bot=res://tools/autoplay/recorders/d6/bot_w6_l1.gd --out=res://build/d6/w/routes/w6_l1.inputs --mode=beginner]

const WORK: String = "res://tools/autoplay/recorders/d8/probe_work.gd"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var work: Node = (load(WORK) as GDScript).new() as Node
	work.name = "D6Probe"
	root.add_child(work)
	var code: int = await work.call(&"run", OS.get_cmdline_user_args())
	var audio: Node = root.get_node_or_null("Audio")
	if audio != null and audio.has_method("shutdown"):
		audio.call("shutdown")
	await create_timer(0.25).timeout
	quit(code)
