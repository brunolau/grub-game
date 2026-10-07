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
## Known limit (2026-10-07, also on the phase-0 tree, so not a 2.0 regression): campaign.flow stops after the warp of
## 1-2 Canopy Village headless (the stage stays w1_l2, bonus_a never starts; Flow.complete_level ignores a call while
## Flow.busy); campaign_beginner.flow and party.flow pass. Use the window for the warp stages until that is understood.

const MAIN_SCENE: String = "res://scenes/main.tscn"


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
