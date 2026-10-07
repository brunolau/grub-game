extends Node
## QA harness of the ui module: visits every `objects/sign` of the shipped levels and screenshots its board.
##
## Owner: ui. Development tool only (a `dev` folder: not exported). It starts each level through Flow like the game
## does, puts the hero beside each sign in turn (beside it on the floor, so the sign's own tick rule shows the
## board), waits until the board has faded in and saves `build/screenshots/<out>/<level>_<n>.png`. Usage:
##
##   bash .tools/gd.sh play --autoplay-scene=res://scenes/ui/dev/sign_preview.tscn --inputs=100000: \
##       --shots=100000 --out=ui_signs [--signs=w1_l1,w2_l1] [--ui-view=800x360]
##
##   --signs=a,b,...    levels to visit (default: every non-test level whose file places a sign)
##   --ui-view=WxH      view size in art px (the window becomes twice that size)
##
## The autoplay harness only provides the user-data redirection and the idle input; this node captures the images
## itself and quits when every sign has been shown.

const SETTLE_SECONDS: float = 0.6
const INTRO_SECONDS: float = 3.6
## How far beside the sign the hero stands (logical px): inside its reading area.
const BESIDE: Array[int] = [-20, 20, 0, -12, 12]

var _out_dir: String = ""


func _ready() -> void:
	var options: Dictionary = Autoplay.parse_args(OS.get_cmdline_user_args())
	var out_name: String = str(options.get("out", "ui_signs")).validate_filename()
	_out_dir = ProjectSettings.globalize_path("res://build/screenshots/" + out_name)
	DirAccess.make_dir_recursive_absolute(_out_dir)
	if options.has("ui-view"):
		var parts: PackedStringArray = str(options["ui-view"]).split("x")
		if parts.size() == 2:
			DisplayServer.window_set_size(Vector2i(parts[0].to_int(), parts[1].to_int()) * 2)
	var ids: Array[StringName] = []
	if options.has("signs"):
		for id: String in str(options["signs"]).split(",", false):
			ids.append(StringName(id))
	else:
		ids = levels_with_signs()
	# Survive the scene changes of Flow.start_level.
	_run.call_deferred(ids)


## Book I solo stages (2.0: not Book II, co-op or arena files, which this tool starts in no run of theirs) whose file
## places an `objects/sign`.
static func levels_with_signs() -> Array[StringName]:
	var result: Array[StringName] = []
	for id: StringName in Levels.all_ids():
		if str(Levels.get_value(id, "kind", Levels.KIND_MAIN)) == Levels.KIND_TEST \
				or Levels.get_book(id) != Levels.BOOK_1 or not Levels.is_solo_level(id):
			continue
		if FileAccess.get_file_as_string(Levels.get_level_path(id)).contains("objects/sign"):
			result.append(id)
	return result


func _run(ids: Array[StringName]) -> void:
	# Not the current scene any more: Flow's scene changes free the current scene, this node stays under the root.
	if get_tree().current_scene == self:
		get_tree().current_scene = null
	# Let the harness settle first (it remembers the level running after a few frames as "its" stage).
	await get_tree().create_timer(0.5).timeout
	var count: int = 0
	for id: StringName in ids:
		var expert_only: bool = not Levels.is_available(id, Defs.Difficulty.BEGINNER)
		Game.new_game(Defs.Difficulty.EXPERT if expert_only else Defs.Difficulty.BEGINNER)
		Game.add_lives(5)
		Flow.start_level(id, Defs.Transition.NONE)
		await get_tree().create_timer(0.2).timeout
		while Flow.busy or Game.level == null or Game.level.level_id != id:
			await get_tree().process_frame
		await get_tree().create_timer(INTRO_SECONDS).timeout
		var signs: Array[SignBoard] = []
		for node: Node in Game.level.find_children("*", "SignBoard", true, false):
			signs.append(node as SignBoard)
		signs.sort_custom(func(a: SignBoard, b: SignBoard) -> bool: return a.sim_pos.x < b.sim_pos.x)
		for i: int in signs.size():
			var sign: SignBoard = signs[i]
			await _visit(sign)
			var name: String = "%s_%d_%s" % [id, i, sign.text_key.to_lower()]
			await RenderingServer.frame_post_draw
			var image: Image = get_viewport().get_texture().get_image()
			image.save_png("%s/%s.png" % [_out_dir, name.validate_filename()])
			var rect: Rect2 = sign.get_board_rect()
			print("SignPreview: %s at %s, board %s, shown %s" % [name, sign.sim_pos, rect.size,
					(sign.get_node("Text") as Label).visible])
			count += 1
	print("SignPreview: %d sign(s) saved to %s" % [count, _out_dir])
	get_tree().quit(0)


## Stand the hero beside `sign` and wait until its board is fully shown.
func _visit(sign: SignBoard) -> void:
	var level: LevelBase = Game.level
	if level == null or level.player == null:
		return
	for attempt: int in BESIDE.size() * 3:
		# A hero hit by a nearby enemy (or fallen into water) is waited for: try again once he is back.
		while level.player.dead or Flow.busy:
			await get_tree().create_timer(0.25).timeout
		var dx: int = BESIDE[attempt % BESIDE.size()]
		level.player.teleport(sign.sim_pos + Vector2i(dx, -2))
		level.player.xvel = 0
		level.player.yvel = 0
		level.snap_camera()
		await get_tree().create_timer(SETTLE_SECONDS).timeout
		if (sign.get_node("Text") as Label).visible:
			return
