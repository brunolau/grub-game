extends SceneTree
## Run a flow script without a window (owner: integration; docs/ARCHITECTURE.md 9.2, docs/expansion/PLAN.md P1.3).
## Development only (folder `dev`, excluded from exports).
##
## `gd.sh play --flow=...` plays a flow script in a window (screenshots, the real frame pacing). This tool boots the
## same main scene headless, so the Autoplay harness runs the flow the same way - menus, gameplay, checks - with the
## screenshots skipped; its exit code is the flow's (0 = every check passed, 4 = a check failed or a wait timed out):
##   bash .tools/gd.sh script res://scripts/core/dev/headless_flow.gd -- --flow=tools/autoplay/campaign_beginner.flow \
##       --fast --fresh-user --user-dir=res://build/flow_user
## (`--user-dir` keeps the run's save beside the project's build folder; without it the harness default is used.)
## The view: `root.size` does not stick on the headless display server (it keeps a 640 x 640 viewport, a 320 x 320
## logical view, and a taller view wakes enemies earlier - campaign.flow's w1_l2.warp route used to diverge at tick 937
## and never reach the warp). So every level gets the windowed view itself: on Flow.screen_changed(&"level") (emitted
## before the level's first tick) the level's view is set to VIEW_ART, the 320 x 180 logical view of a window and of
## the route tests (core-A's finding, wf8_core_a_to_integration.txt #1).

const MAIN_SCENE: String = "res://scenes/main.tscn"
## The view of a windowed level in art px (the 320 x 180 logical view at the art scale of 2).
const VIEW_ART: Vector2i = Vector2i(640, 360)


func _initialize() -> void:
	if not OS.get_cmdline_user_args().has("--fast"):
		print("headless_flow: without --fast the flow runs in real time")
	# The headless display has no window of the project's size: give the root the 1280 x 720 of the game window, so
	# every level gets the view a windowed flow plays with (enemies wake by the view, as in the route tests).
	var size: Vector2i = Vector2i(int(ProjectSettings.get_setting("display/window/size/window_width_override", 0)),
			int(ProjectSettings.get_setting("display/window/size/window_height_override", 0)))
	if size.x <= 0 or size.y <= 0:
		size = Vector2i(int(ProjectSettings.get_setting("display/window/size/viewport_width", 1280)),
				int(ProjectSettings.get_setting("display/window/size/viewport_height", 720)))
	root.size = size
	print("headless_flow: view %s" % str(root.size))
	change_scene_to_file.call_deferred(MAIN_SCENE)
	_hook_flow.call_deferred()


## Connects the level-view fix once the autoloads are in the tree.
func _hook_flow() -> void:
	var flow: Node = root.get_node_or_null("Flow")
	if flow == null:
		push_warning("headless_flow: no Flow autoload, the levels keep the headless view")
		return
	flow.connect("screen_changed", _on_screen_changed)


func _on_screen_changed(screen: StringName) -> void:
	if screen != &"level":
		return
	var level: Node = root.get_node("Game").get("level")
	if level != null and level.has_method("set_view_size"):
		level.call("set_view_size", VIEW_ART)
