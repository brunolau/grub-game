extends SceneTree
## The continuous-play tools of the co-op gate proof (docs/expansion/DESIGN.md R7 / G71+, LEVEL_DESIGN.md 15.7.6;
## adopted from the G3b verifier's build/g3bv/ in wf11). Owner: world-B (PLAN.md 4.1).
##
##   bash .tools/gd.sh script res://tools/coop_explore/main.gd -- explore <level> <gate> <0|1> [key=value ...]
##       the explorer on one gate row (explorer.gd: seconds=, seed=, whole=1, out=, cache=1 ...)
##   bash .tools/gd.sh script res://tools/coop_explore/main.gd -- replay <route file> [trace=<n>] [fine=a-b] [cache=1]
##       one route in this fresh process, with a trace (replay.gd)
##   bash .tools/gd.sh script res://tools/coop_explore/main.gd -- spring
##       what a low strike begun on a spring pad rises (spring.gd; R1: 115 px in a co-op party, not 256)
##   bash .tools/gd.sh script res://tools/coop_explore/main.gd -- exact <level> <gate> <0|1> [whole=1] [runs=<n>]
##       the exact reset's own check on one gate's world (exact.gd)
## One command each for the whole lists: `bash tools/coop_explore/replay_evidence.sh` (every route of
## tools/coop_explore/evidence, a fresh process each) and `bash tools/coop_explore/explore_gates.sh` (a gate list in
## parallel, with seed and seconds); `bash tools/world_coop_gates.sh` runs all three proofs of every gate row.
##
## Autoloads are reached through the tree and the tools are loaded by path: this script is compiled before they exist.

const TOOLS: Dictionary = {
	"explore": "res://tools/coop_explore/explorer.gd",
	"replay": "res://tools/coop_explore/replay.gd",
	"spring": "res://tools/coop_explore/spring.gd",
	"exact": "res://tools/coop_explore/exact.gd",
}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	var code: int = 2
	if arguments.is_empty() or not TOOLS.has(arguments[0]):
		print("coop_explore: want one of %s (see the header of tools/coop_explore/main.gd)" % ", ".join(
			PackedStringArray(TOOLS.keys())))
	else:
		var runner: Node = (load(str(TOOLS[arguments[0]])) as GDScript).new() as Node
		runner.name = "CoopExplore"
		root.add_child(runner)
		var result: Variant = await runner.call(&"run", arguments.slice(1))
		code = int(result) if result is int else 0
		await process_frame
	var audio: Node = root.get_node_or_null("Audio")
	if audio != null and audio.has_method("shutdown"):
		audio.call("shutdown")
	await create_timer(0.1).timeout
	quit(code)
