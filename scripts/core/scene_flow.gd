extends Node
## Autoload `Flow`: the only place that changes scenes (docs/ARCHITECTURE.md 3.10, GAMEPLAY.md 11.1).
##
## CONTRACT FILE. Owner: core. Public members are frozen.
##
## Screens are found by naming convention: screen "tally" is `res://scenes/ui/tally.tscn`. Gameplay is always
## `res://scenes/world/level.tscn` (or the collision-only debug level while that scene does not exist), which
## reads [member pending_level_id]. While a level runs, Flow owns the
## overlay CanvasLayers and fills them with `scenes/ui/hud.tscn`, `touch_controls.tscn` and `pause_menu.tscn`.
## A scene that does not exist yet is skipped (the flow continues with the next step) or replaced by the
## placeholder main scene, so the game stays runnable while modules are being built.
##
## Transitions (GAMEPLAY.md 11.1) are drawn by one [TransitionCover] on CanvasLayer Defs.LAYER_TRANSITION: FADE
## between menu screens, CURTAIN into gameplay (it opens from the centre), IRIS on the hero at the end of a level.
## While the cover hides a level the simulation clock stands still (Sim.frozen), so nothing happens unseen.
##
## Flow also reacts to the application losing focus or going to the background (every platform, most important
## on phones): gameplay is paused, all sound is suspended, and settings are written before the OS may kill the
## app. Sound resumes with the focus; gameplay stays paused until the player resumes it.
##
## 2.0 (docs/expansion/PLAN.md P1.1, GAMEPLAY.md 13.1 / 13.9.1 / 13.10.1, DESIGN.md D.1 / D.11 / E.8). The front end is
## Title > Play > Solo / Co-op / Versus ([method open_play]): Solo and Co-op go through the book select
## ([method choose_book]) and the difficulty ([method start_selected_game]); Co-op opens the join panel first
## ([method join_player], [method finish_join]); Versus opens the lobby. Every campaign call works in the mode and
## book of the run: the co-op campaign plays each stop's co-op file ([method level_to_play]: Flow.start_level maps a
## solo id to its `<id>_coop` file in co-op), results, unlocks, high scores and the expert wall go to the save
## namespace of (Game.mode, Game.book, difficulty) ([method save_space]). A single-player Book I run is exactly 1.0.
## A player may join or leave from the join panel, the world map or the pause menu; mid-stage the stage restarts at its
## checkpoint in the other layout, score kept ([method join_player], [method leave_player]). A pad that disconnects
## during play pauses the game for its player ([signal pad_lost]; the pause menu offers "Reconnect, or continue
## alone": [method continue_alone]); the next pad that connects takes the lost seat. Versus: [method start_versus]
## starts a [VersusMatch] (Game.versus_match), every round is an arena start ([method start_round]) seeded from the
## match; the referee ends a round with [method end_round]; then the scoreboard ([method next_round]) and after the
## last round the results ([method rematch], [method leave_versus]).
##
## 2.0, phase 2 (PLAN.md P2.6). Every versus round is recorded - its input log and start snapshot (VersusReplay) - and
## between the gong and the scoreboard its deciding moment plays again at half speed ([method play_deciding_moment]:
## the last 3 s, in Grub Stack the biggest steal; any Jump / Strike / accept / pause skips it, [method skip_replay];
## off in headless runs, [member deciding_moment]). A sudden death switches the round to the sudden-death music. Book
## II: a warp ends its source stop as in 1.0 (the stop after it follows, its linked sub-stage is passed over); the
## expert wall and THE END get the book and mode (and THE END of Book II the mural once every painting is found,
## UnlockTable); [method level_select] lists a book's stops with their codes for the code entry and the co-op
## continue.

## A screen or the level became active. `screen` is one of the SCREEN_* names or SCREEN_LEVEL.
signal screen_changed(screen: StringName)
## The screen is fully covered by the transition (old scene still loaded).
signal transition_covered
## The transition finished uncovering the new scene.
signal transition_finished
## 2.0: the players changed (a join or a leave): `size` players now take part (party_size()).
signal party_changed(size: int)
## 2.0: the pad of player slot `slot` disconnected. During play the game pauses with that player's focus
## (pause_slot); the pause menu offers "Reconnect, or continue alone" (lost_pad_slots(), continue_alone()).
signal pad_lost(slot: int)
## 2.0: a pad connected and took the seat of player slot `slot`, whose pad was lost.
signal pad_reconnected(slot: int)
## 2.0: the deciding moment of versus round `round_index` plays (ticks `first`..`last` of the round at half speed;
## `steal`: it shows Grub Stack's biggest steal, else the last seconds). The HUD shows its banner and the skip hint.
signal replay_started(round_index: int, first: int, last: int, steal: bool)
## 2.0: the deciding moment ended - played to its end, or skipped (`skipped`). The scoreboard (or the results) follows.
signal replay_finished(skipped: bool)

const MAIN_SCENE: String = "res://scenes/main.tscn"
const LEVEL_SCENE: String = "res://scenes/world/level.tscn"
## Collision-only stand-in used while LEVEL_SCENE does not exist (core development tool).
const DEBUG_LEVEL_SCENE: String = "res://scenes/core/debug_level.tscn"
const SCREEN_DIR: String = "res://scenes/ui/"
const HUD_SCENE: String = "res://scenes/ui/hud.tscn"
const TOUCH_SCENE: String = "res://scenes/ui/touch_controls.tscn"
const PAUSE_SCENE: String = "res://scenes/ui/pause_menu.tscn"

# Transition timing in seconds at transition_speed 1.
const FADE_SECONDS: float = 0.25        ## fade to / from black
const CURTAIN_SECONDS: float = 0.4      ## the curtain panels cross half the screen
const IRIS_SECONDS: float = 0.55        ## the iris travels between "open" and the spotlight (or "shut")
const IRIS_HOLD_SECONDS: float = 0.25   ## a closing iris rests as a spotlight on the hero
const IRIS_SHUT_SECONDS: float = 0.15   ## then the spotlight closes completely
const IRIS_HOLD_RADIUS: float = 48.0    ## radius of that spotlight in art px (the hero is about 64 x 70)

# Screen names (each is a scene in SCREEN_DIR, owned by the ui module).
const SCREEN_TITLE: StringName = &"title"              ## title picture + main menu
const SCREEN_MODE_SELECT: StringName = &"mode_select"  ## BEGINNER / EXPERT
const SCREEN_CODE_ENTRY: StringName = &"code_entry"    ## password / continue screen
const SCREEN_OPTIONS: StringName = &"options"
const SCREEN_WORLD_MAP: StringName = &"world_map"      ## args: {"level_id": StringName}
const SCREEN_TALLY: StringName = &"tally"              ## args: {"level_id": StringName, "percent": int}
const SCREEN_GAME_OVER: StringName = &"game_over"
const SCREEN_EXPERT_WALL: StringName = &"expert_wall"  ## "you must be an expert" (GAMEPLAY.md 1.3)
const SCREEN_THE_END: StringName = &"the_end"
const SCREEN_CREDITS: StringName = &"credits"
const SCREEN_LEVEL: StringName = &"level"              ## gameplay (not in SCREEN_DIR)
const SCREEN_BOOT: StringName = &"boot"                ## placeholder main scene
# 2.0 screens (ui-A, PLAN.md P1.11 / P2.8). Arguments in the comments; each screen also reads Game / Flow state.
const SCREEN_BOOK_SELECT: StringName = &"book_select"  ## Book I / Book II (play_mode tells Solo or Co-op)
const SCREEN_JOIN: StringName = &"join"                ## co-op join panel "the Tribe Gathering"
const SCREEN_UNLOCKS: StringName = &"unlocks"          ## the Cave Painting rewards
const SCREEN_VERSUS_LOBBY: StringName = &"versus_lobby" ## seats, colours, CPUs, ready (Game.versus_match)
const SCREEN_VERSUS_RULES: StringName = &"versus_rules" ## args: {"owner": slot whose Start opened it}
const SCREEN_VERSUS_ARENA: StringName = &"versus_arena" ## arena thumbnails, Random, Party Mix
const SCREEN_VERSUS_SCOREBOARD: StringName = &"versus_scoreboard" ## args: {"round_index": int, "winners": PackedInt32Array}
const SCREEN_VERSUS_RESULTS: StringName = &"versus_results" ## args: {"winners": PackedInt32Array, "awards": {slot: [id]}}
## 2.0: the Options > Co-op switch that a co-op run copies into Game.helper_mode (DESIGN.md D.3).
const HELPER_MODE_KEY: String = "coop/helper_mode"

## Active screen name.
var current_screen: StringName = SCREEN_BOOT
## Arguments of the active screen (read-only for the screen).
var args: Dictionary = {}
## Level the gameplay scene must load (set before LEVEL_SCENE is entered).
var pending_level_id: StringName = &""
## True while a transition runs; requests made meanwhile are ignored.
var busy: bool = false
## When true transitions take no time (tests, autoplay, headless smoke runs).
var instant_transitions: bool = false
## Speed factor of timed transitions: 1 = the durations above, 2 = twice as fast.
var transition_speed: float = 1.0
## When true (default) gameplay pauses and all sound is suspended while the application has no focus or is in
## the background. The autoplay harness switches it off: its windows rarely have the focus.
var pause_on_focus_loss: bool = true
## When true (default, except headless runs) the menu screens and the world map load what the next level start
## needs on worker threads (ARCHITECTURE.md 11 "Loading"); see [method warm_up].
var background_loading: bool = true
## Player slot whose device asked for the last pause (GameInput.event_slot; 0 in single-player and for a pause
## that did not come from a device, e.g. the focus loss). The pause menu gives that player the focus (2.0).
var pause_slot: int = 0
## 2.0: the game mode chosen on the front end (Defs.GameMode; open_play), and the book (choose_book). The title resets
## them to Solo / Book I. They decide what start_selected_game starts; a running game's mode and book are Game's.
var play_mode: int = Defs.GameMode.SINGLE
var play_book: int = 1
## 2.0: show the deciding moment of every versus round between the gong and the scoreboard (DESIGN.md E.8 step 5).
## Off in headless runs (tests and flow scripts drive rounds tick by tick; a test that wants it switches it on).
var deciding_moment: bool = true
var _layer: CanvasLayer = null
var _cover: TransitionCover = null
var _cover_tween: Tween = null
var _overlay_hud: CanvasLayer = null
var _overlay_touch: CanvasLayer = null
var _overlay_menu: CanvasLayer = null
var _quitting: bool = false
## Counts transitions; lets play_covered() notice that its action started a scene change.
var _transition_serial: int = 0
var _app_focused: bool = true
var _app_resumed: bool = true
var _app_active: bool = true
var _warmup: Warmup = null
# 2.0: player slots whose pad was lost, oldest first (notify_pad_connection).
var _lost_pads: PackedInt32Array = PackedInt32Array()
# 2.0: what the next level start applies once the level is loaded (before its first tick): the checkpoint of a
# party change ([has, pos]; empty = none) and the Sim.rng seed of a versus round (-1 = none).
var _entry_checkpoint: Array = []
var _pending_seed: int = -1
# 2.0: the deciding-moment replay (play_deciding_moment): on / off, the ticks to run behind the curtain before it shows,
# the window, what follows it ([round index, winners]), the match state the round left (restored afterwards) and the
# scripts of the slots it feeds (given back afterwards).
var _replaying: bool = false
var _pending_fast_forward: int = -1
var _replay_window: Vector2i = Vector2i.ZERO
var _replay_after: Array = []
var _replay_end_state: Dictionary = {}
var _replay_saved_scripts: Dictionary = {}


## Background loading of what a level start needs (ARCHITECTURE.md 11 "Loading"). The pictures, sounds and fonts
## of the requested scenes (ResourceLoader.get_dependencies) load on worker threads (load_threaded_request) while a
## menu or the map shows; looking them up takes at most FRAME_BUDGET_USEC per frame. Scripts and the scenes
## themselves are put together on the main thread, and only while a transition covers the screen
## ([method Flow._change_scene], at most COVERED_BUDGET_USEC per transition): this engine version leaks an object
## for some scripts compiled on a worker thread, and a script compile is too long for a visible frame. Whatever is
## left then is loaded by the level start itself, as before - never inside a simulation tick. Entity scenes go into
## the Spawner cache; the level and overlay scenes and what they use are kept for the session; the rest until the
## next level start (the level holds what it uses then).
class Warmup:
	extends Node

	## Extensions of the resources that load on worker threads.
	const THREADED: PackedStringArray = ["png", "jpg", "jpeg", "webp", "svg", "ogg", "wav", "mp3", "ttf", "otf",
			"woff", "woff2", "fnt"]
	## Main-thread time per visible frame (dependency lookups, collecting finished loads).
	const FRAME_BUDGET_USEC: int = 2000
	## Main-thread time per covered transition (scripts and scenes).
	const COVERED_BUDGET_USEC: int = 400000

	## Path -> true for every threaded load still running.
	var pending: Dictionary = {}
	## Requests whose dependencies are not looked up yet, and scripts and scenes waiting for a covered moment:
	## [path, entity id, keep for the session].
	var plan: Array[Array] = []
	var queue: Array[Array] = []
	## Resources kept for the whole session (level scene, overlays) and until the next level start.
	var session: Dictionary = {}
	var next_level: Dictionary = {}
	var _known: Dictionary = {}
	var _keep_for_session: Dictionary = {}
	## Worker threads only with a real renderer: the headless one cannot create textures on another thread
	## (tests that switch background loading on get the same caches, loaded on the main thread).
	var _threads: bool = DisplayServer.get_name() != "headless"

	func _init() -> void:
		name = "Warmup"
		process_mode = Node.PROCESS_MODE_ALWAYS
		set_process(false)

	## Load `path` in the background unless it is loaded or on its way already (`entity_id` puts a scene into the
	## Spawner cache). Returns at once.
	func request(path: String, entity_id: StringName = &"", for_session: bool = false) -> void:
		if path.is_empty() or _known.has(path) or session.has(path) or next_level.has(path):
			return
		if entity_id != &"" and Spawner._cache.has(entity_id):
			return
		_known[path] = true
		if for_session:
			_keep_for_session[path] = true
		plan.append([path, entity_id, for_session])
		set_process(true)

	## True while anything requested is not loaded yet.
	func is_busy() -> bool:
		return not plan.is_empty() or not pending.is_empty() or not queue.is_empty()

	func _process(_delta: float) -> void:
		var deadline: int = Time.get_ticks_usec() + FRAME_BUDGET_USEC
		while not plan.is_empty() and Time.get_ticks_usec() < deadline:
			_expand(plan.pop_front())
		for path: String in pending.keys():
			if ResourceLoader.load_threaded_get_status(path) != ResourceLoader.THREAD_LOAD_IN_PROGRESS:
				_collect(path)
		if plan.is_empty() and pending.is_empty():
			set_process(false)

	## Put scripts and scenes together for at most `budget_usec` (the screen is covered). Threaded loads they need
	## and that are still running are waited for.
	func load_queue(budget_usec: int) -> void:
		var deadline: int = Time.get_ticks_usec() + budget_usec
		while not plan.is_empty() and Time.get_ticks_usec() < deadline:
			_expand(plan.pop_front())
		while not queue.is_empty() and Time.get_ticks_usec() < deadline:
			_load_queued(queue.pop_front())

	## Finish every request now (tests, application exit).
	func finish_all() -> void:
		while not plan.is_empty():
			_expand(plan.pop_front())
		for path: String in pending.keys():
			_collect(path)
		while not queue.is_empty():
			_load_queued(queue.pop_front())
		set_process(false)

	## Forget the scripts and scenes still waiting: a level start loads what it needs itself.
	func drop_queue() -> void:
		for entry: Array in queue:
			_known.erase(entry[0])
		queue.clear()

	## Start a threaded load, or look up the dependencies of a script or scene and queue it.
	func _expand(entry: Array) -> void:
		var path: String = entry[0]
		var for_session: bool = entry[2]
		if not ResourceLoader.exists(path):
			_known.erase(path)
			return
		if ResourceLoader.has_cached(path):
			# Loaded already (by a screen, a level): keep it. A threaded request for a resource the main thread had
			# (or was still loading) left objects behind at exit.
			_known.erase(path)
			var cached: Resource = ResourceLoader.get_cached_ref(path)
			if entry[1] != &"":
				Spawner.adopt(entry[1], cached as PackedScene)
			elif cached != null:
				_hold(path, cached)
			return
		if THREADED.has(path.get_extension().to_lower()) and _threads:
			if ResourceLoader.load_threaded_request(path, "", false) == OK:
				pending[path] = true
			else:
				_known.erase(path)
			return
		for dependency: String in ResourceLoader.get_dependencies(path):
			var dependency_path: String = dependency.get_slice("::", 2) if dependency.contains("::") else dependency
			if dependency_path.begins_with("res://"):
				request(dependency_path, &"", for_session)
		queue.append(entry)

	func _collect(path: String) -> void:
		pending.erase(path)
		_known.erase(path)
		# Always fetched, also after a failure: that releases the request.
		var resource: Resource = ResourceLoader.load_threaded_get(path)
		if resource != null:
			_hold(path, resource)

	func _load_queued(entry: Array) -> void:
		var path: String = entry[0]
		var entity_id: StringName = entry[1]
		_known.erase(path)
		if entity_id != &"" and Spawner._cache.has(entity_id):
			return
		var resource: Resource = load(path)
		if resource == null:
			return
		if entity_id != &"":
			Spawner.adopt(entity_id, resource as PackedScene)
		else:
			_hold(path, resource)

	func _hold(path: String, resource: Resource) -> void:
		if _keep_for_session.has(path):
			session[path] = resource
		else:
			next_level[path] = resource


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# _process only keeps a closing iris on the hero.
	set_process(false)
	_layer = CanvasLayer.new()
	_layer.layer = Defs.LAYER_TRANSITION
	add_child(_layer)
	_cover = TransitionCover.new()
	_layer.add_child(_cover)
	_overlay_hud = _make_overlay(Defs.LAYER_HUD)
	_overlay_touch = _make_overlay(Defs.LAYER_TOUCH)
	_overlay_menu = _make_overlay(Defs.LAYER_MENU)
	_warmup = Warmup.new()
	add_child(_warmup)
	Input.joy_connection_changed.connect(notify_pad_connection)
	Events.round_sudden_death_started.connect(_on_sudden_death_started)
	if DisplayServer.get_name() == "headless":
		instant_transitions = true
		# Tests and smoke checks load what they use themselves; nothing runs behind their back.
		background_loading = false
		deciding_moment = false


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED:
			# Mobile: the app goes to the background, where the OS may kill it without another word.
			_app_resumed = false
			_update_app_active()
			Settings.save()
		NOTIFICATION_APPLICATION_RESUMED:
			_app_resumed = true
			_update_app_active()
		NOTIFICATION_APPLICATION_FOCUS_OUT:
			_app_focused = false
			_update_app_active()
		NOTIFICATION_APPLICATION_FOCUS_IN:
			_app_focused = true
			_update_app_active()
		NOTIFICATION_WM_CLOSE_REQUEST:
			# The window was closed (auto_accept_quit is off): leave cleanly.
			shutdown_and_quit(0)
		NOTIFICATION_WM_GO_BACK_REQUEST:
			# Android back button / gesture (quit_on_go_back is off): pause running gameplay; everywhere else
			# (menus, the pause menu) it is the "cancel" action, so screens need no Android-specific code.
			if current_screen == SCREEN_LEVEL and not get_tree().paused:
				if not busy:
					set_paused(true)
			else:
				_send_cancel_action()


func _process(_delta: float) -> void:
	_cover.focus = _transition_focus(Defs.Transition.IRIS)


func _unhandled_input(event: InputEvent) -> void:
	if _replaying and current_screen == SCREEN_LEVEL and not busy and _skips_replay(event):
		# The deciding moment is skippable (DESIGN.md E.8): the pause key skips it instead of pausing.
		skip_replay()
		get_viewport().set_input_as_handled()
		return
	if current_screen == SCREEN_LEVEL and not busy and event.is_action_pressed(Defs.ACT_PAUSE):
		# A button that both pauses and confirms (gamepad Start) confirms the focused entry of the pause menu.
		if get_tree().paused and event.is_action(&"ui_accept", true) and get_viewport().gui_get_focus_owner() != null:
			return
		if not get_tree().paused:
			pause_slot = maxi(GameInput.event_slot(event), 0)
		toggle_pause()
		get_viewport().set_input_as_handled()


## True when the scene of a screen exists.
func has_screen(screen: StringName) -> bool:
	return ResourceLoader.exists(SCREEN_DIR + String(screen) + ".tscn")


## True when this build can show gameplay: the world module's level scene exists, or (development only) the
## debug level. A release export without the level scene has none.
func has_gameplay() -> bool:
	return not _level_scene_path().is_empty()


## Show a screen of SCREEN_DIR. Falls back to the placeholder main scene when it does not exist.
func goto_screen(screen: StringName, transition: int = Defs.Transition.FADE, p_args: Dictionary = {}) -> void:
	if has_screen(screen):
		_change_scene(SCREEN_DIR + String(screen) + ".tscn", screen, transition, p_args)
	else:
		var notice: Dictionary = p_args.duplicate()
		notice["missing_screen"] = String(screen)
		_change_scene(MAIN_SCENE, SCREEN_BOOT, transition, notice)


## Title screen (also the target of "quit to title" and of the end of a run). 2.0: the front-end choice goes back
## to Solo / Book I, and a party's input slots back to single-player (every device feeds P1).
func goto_title() -> void:
	_cancel_replay()
	_record_round(false)
	Audio.stop_all_sfx()
	play_mode = Defs.GameMode.SINGLE
	play_book = 1
	_lost_pads.clear()
	GameInput.set_menu_clusters(false)
	_reset_party_input()
	goto_screen(SCREEN_TITLE)


## Start a new run at the first campaign level (GAMEPLAY.md 11.1 steps 5-7). The 1.0 game: single-player, Book I
## (see start_selected_game / start_book_game / start_coop_game for the 2.0 runs).
func start_new_game(difficulty: int) -> void:
	_reset_party_input()
	Game.new_game(difficulty)
	Settings.set_value("game/last_difficulty", difficulty)
	var first: StringName = Levels.first_level()
	if first == &"":
		push_warning("Flow: no campaign level found in %s" % Levels.LEVEL_DIR)
		goto_screen(SCREEN_TITLE)
		return
	show_world_map(first)


## Start a new run at a later level (level select / code entry). Score and lives start fresh. A level reached by
## its code counts as reached from then on, so the level select lists it (with its record once cleared).
## 2.0: a single-player run of the level's book (Book II codes start Book II; the run begins with the club and an
## empty belt, DESIGN.md C.1 rule 4). A Book I level is exactly 1.0.
func continue_game(level_id: StringName, difficulty: int) -> void:
	_reset_party_input()
	var book: int = maxi(Levels.get_book(level_id), 1)
	var space_key: String = Save.space(Defs.GameMode.SINGLE, book, difficulty)
	if not Save.is_level_unlocked_in(space_key, level_id):
		Save.unlock_level_in(space_key, level_id)
		Save.save_game()
	if book == 1:
		Game.new_game(difficulty)
	else:
		Game.start_run(difficulty, Defs.GameMode.SINGLE, 1, book)
	show_world_map(level_id)


## Show the world map with the marker on `level_id`; the map screen calls start_level(args["level_id"]) when
## it is done. Without a map screen the level starts directly.
## 2.0: args also hold "book" and "mode" (Game.book, Game.mode); in co-op the marker stands on the solo map stop of
## a co-op file (start_level plays the co-op file again).
func show_world_map(level_id: StringName) -> void:
	var stop: StringName = level_id
	if Game.mode == Defs.GameMode.COOP and Levels.is_coop_level(level_id):
		stop = Levels.get_coop_base(level_id)
	if has_screen(SCREEN_WORLD_MAP):
		goto_screen(SCREEN_WORLD_MAP, Defs.Transition.FADE, {"level_id": stop, "book": Game.book, "mode": Game.mode})
	else:
		start_level(stop)


## Load a level. `carry_progress` keeps completion counters and the tally list (linked sub-stage, bonus stage).
## 2.0: in a co-op run a solo level id starts its co-op file (level_to_play).
func start_level(level_id: StringName, transition: int = Defs.Transition.CURTAIN, carry_progress: bool = false) -> void:
	# 2.0: what this start applies after loading (a party change's checkpoint, a versus round's seed); {} in 1.0.
	var extras: Dictionary = _take_level_extras()
	if busy:
		return
	level_id = level_to_play(level_id)
	if not Levels.has_level(level_id):
		push_error("Flow.start_level: unknown level '%s'" % level_id)
		return
	var scene: String = _level_scene_path()
	if scene.is_empty():
		push_error("Flow.start_level: this build has no gameplay scene (%s)" % LEVEL_SCENE)
		return
	pending_level_id = level_id
	Game.begin_level(level_id, carry_progress)
	var level_args: Dictionary = {"level_id": level_id}
	level_args.merge(extras)
	_change_scene(scene, SCREEN_LEVEL, transition, level_args)


## Reload the current level from its start (pause menu "restart level"). The run goes back to its state at the
## level entry (Game.restore_level_entry): the restart costs nothing and earns nothing, so the level's items, which
## all reappear, cannot be collected twice. A hero whose death toss is still playing has lost that life: it is
## paid first, and on the last life the run ends (game over) instead. A party pays only for a team wipe (every hero
## dead or down at once). Ignored while a transition runs.
func restart_level() -> void:
	if Game.level_id == &"" or busy:
		return
	var level: LevelBase = Game.level
	if level != null and level.all_heroes_dead_or_down() and not level.completed:
		if not Game.lose_life():
			Sim.stop()
			game_over()
			return
	# A restored entry state already holds the counters the level started with (a linked sub-stage or bonus stage
	# carries its source level's progress): keep them.
	var restored: bool = Game.restore_level_entry()
	start_level(Game.level_id, Defs.Transition.CURTAIN, restored)


## Called by the level when the hero reaches an exit. `exit_kind`: &"exit", &"warp" or &"trophy"
## (route logic of GAMEPLAY.md 1.1).
func complete_level(exit_kind: StringName) -> void:
	if busy:
		return
	var level_id: StringName = Game.level_id
	var difficulty: int = Game.difficulty
	Events.level_completed.emit(level_id, exit_kind)
	var kind: String = _campaign_kind(level_id)
	if exit_kind == &"warp" and kind != Levels.KIND_BONUS:
		# Warp item in a main level: straight into its bonus stage, no tally, progress carried over.
		var bonus: StringName = StringName(str(Levels.get_value(level_id, "bonus", "", difficulty)))
		if bonus != &"" and Levels.has_level(bonus):
			Game.warp_return_level = level_id
			start_level(bonus, Defs.Transition.CURTAIN, true)
			return
	if exit_kind == &"exit" and not bool(Levels.get_value(level_id, "tally", true, difficulty)):
		# First half of a linked pair: continue in the sub-stage without a tally.
		var linked: StringName = Levels.next_level(level_id, difficulty)
		if linked != &"":
			start_level(linked, Defs.Transition.CURTAIN, true)
			return
	if exit_kind == &"trophy":
		var epilogue: StringName = Levels.next_level(level_id, difficulty)
		if epilogue != &"":
			# The final boss ends its map stop here (the epilogue that follows has a tally of its own): record the
			# stop's result now, as its tally would have.
			var stop: StringName = Levels.parent_level(level_id, difficulty)
			if stop != &"":
				Save.record_level_result_in(save_space(), stop, Game.score, Game.completion_percent())
				Save.save_game()
			start_level(epilogue, Defs.Transition.CURTAIN, false)
			return
	if has_screen(SCREEN_TALLY):
		goto_screen(SCREEN_TALLY, Defs.Transition.IRIS, {
			"level_id": level_id, "percent": Game.completion_percent(),
		})
	else:
		finish_tally()


## Called by the tally screen when it is done: records the result, unlocks and enters the next level.
func finish_tally() -> void:
	var finished: StringName = Game.level_id
	var difficulty: int = Game.difficulty
	var space_key: String = save_space()
	var warped: bool = false
	# A bonus stage ends its SOURCE level (GAMEPLAY.md 1.1).
	if Game.warp_return_level != &"":
		finished = Game.warp_return_level
		Game.warp_return_level = &""
		warped = true
	elif _campaign_kind(finished) == Levels.KIND_BONUS:
		# A bonus stage entered without its source level's warp (debug level select): nothing to record or unlock,
		# and it never ends the game. The run goes back to the title.
		Game.clear_tally()
		Save.submit_score_in(space_key, Game.score)
		Save.save_game()
		goto_title()
		return
	# A linked sub-stage ends the main level it belongs to: the result goes to that level's map stop (the
	# campaign then continues after it, Levels.next_level). A co-op file's map stop is its solo level's.
	var parent: StringName = Levels.parent_level(finished, difficulty)
	Save.record_level_result_in(space_key, parent if parent != &"" else finished, Game.score,
			Game.completion_percent())
	Game.clear_tally()
	_store_belts(space_key)
	var kind: String = _campaign_kind(finished)
	var next: StringName = stop_after_warp(finished, difficulty) if warped else Levels.next_level(finished, difficulty)
	if kind == Levels.KIND_ENDING or (next == &"" and not Levels.has_locked_successor(finished, difficulty)):
		Save.set_game_completed_in(space_key)
		Save.submit_score_in(space_key, Game.score)
		Save.save_game()
		goto_screen(SCREEN_THE_END, Defs.Transition.FADE, ending_args())
		return
	if next == &"":
		Save.submit_score_in(space_key, Game.score)
		Save.save_game()
		goto_screen(SCREEN_EXPERT_WALL, Defs.Transition.FADE, {"book": maxi(Game.book, 1), "mode": Game.mode})
		return
	Save.unlock_level_in(space_key, _map_stop(next))
	Save.save_game()
	show_world_map(next)


## No lives left (GAMEPLAY.md 11.1 step 9: after the death toss the curtain closes on the level).
func game_over() -> void:
	Save.submit_score_in(save_space(), Game.score)
	Save.save_game()
	Events.game_over.emit()
	goto_screen(SCREEN_GAME_OVER, Defs.Transition.CURTAIN)


## Pause or resume gameplay. Only has an effect while a level is active.
func set_paused(paused: bool) -> void:
	if current_screen != SCREEN_LEVEL or get_tree().paused == paused:
		return
	if not paused:
		pause_slot = 0
	get_tree().paused = paused
	Audio.play_sfx(Sfx.PAUSE_IN if paused else Sfx.PAUSE_OUT)
	Events.pause_changed.emit(paused)


func toggle_pause() -> void:
	set_paused(not get_tree().paused)


func is_paused() -> bool:
	return get_tree().paused


# =================================================================================================================
# 2.0: modes and books (GAMEPLAY.md 13.1)
# =================================================================================================================

## Title > Play > Solo / Co-op / Versus (Defs.GameMode). Solo: the book select (or, without it, the difficulty
## select); Co-op: the join panel (begin_party_setup; without the panel two keyboard halves join at once and the book
## select follows); Versus: the lobby (open_versus_lobby).
func open_play(mode: int) -> void:
	play_mode = mode
	match mode:
		Defs.GameMode.COOP:
			begin_party_setup()
			if has_screen(SCREEN_JOIN):
				goto_screen(SCREEN_JOIN)
			else:
				_ensure_party_inputs(PartyTuning.COOP_PLAYERS)
				_open_book_select()
		Defs.GameMode.VERSUS:
			open_versus_lobby()
		_:
			_reset_party_input()
			_open_book_select()


## The book select chose `book` (1 / 2; Book II is open from the start): on to the difficulty select (mode_select),
## or straight into the game when that screen does not exist.
func choose_book(book: int) -> void:
	play_book = clampi(book, 1, Levels.BOOK_2)
	if has_screen(SCREEN_MODE_SELECT):
		goto_screen(SCREEN_MODE_SELECT)
	else:
		start_selected_game(Settings.get_int("game/last_difficulty"))


## The difficulty select chose `difficulty`: start the run the front end prepared (play_mode, play_book) - a solo run
## of the book (start_book_game) or a co-op run of the joined party (start_coop_game).
func start_selected_game(difficulty: int) -> void:
	if play_mode == Defs.GameMode.COOP:
		start_coop_game(difficulty, maxi(party_size(), PartyTuning.COOP_PLAYERS), play_book)
	else:
		start_book_game(difficulty, play_book)


## Start a single-player run of `book` at its first stop, or at `at_level` (the level select of that book; it counts
## as reached from then on). Book I without `at_level` is start_new_game (the 1.0 game).
func start_book_game(difficulty: int, book: int = 1, at_level: StringName = &"") -> void:
	if book <= 1 and at_level == &"":
		start_new_game(difficulty)
		return
	if at_level != &"":
		continue_game(at_level, difficulty)
		return
	_reset_party_input()
	Game.start_run(difficulty, Defs.GameMode.SINGLE, 1, book)
	Settings.set_value("game/last_difficulty", difficulty)
	var first: StringName = Levels.first_level(book)
	if first == &"":
		push_warning("Flow: book %d has no campaign level yet" % book)
		goto_title()
		return
	show_world_map(first)


## Start a co-op run (DESIGN.md D): `party` heroes (co-op is designed for PartyTuning.COOP_PLAYERS) of the players who
## joined (GameInput slots; a slot nobody joined gets a default input: P1 the left keyboard half, P2 the right one,
## further players the connected pads), `book`, at the book's first stop or at `at_level` (a solo map stop or its
## co-op file; it counts as reached in the co-op save from then on). The stops play their co-op files (level_to_play);
## a book without any co-op file yet plays its solo files with the party (development).
func start_coop_game(difficulty: int, party: int = PartyTuning.COOP_PLAYERS, book: int = 1,
		at_level: StringName = &"") -> void:
	var size: int = clampi(party, 2, Defs.MAX_PLAYERS)
	play_mode = Defs.GameMode.COOP
	play_book = clampi(book, 1, Levels.BOOK_2)
	_ensure_party_inputs(size)
	Game.start_run(difficulty, Defs.GameMode.COOP, size, play_book)
	Game.helper_mode = Settings.get_bool(HELPER_MODE_KEY)
	Settings.set_value("game/last_difficulty", difficulty)
	var first: StringName = _map_stop(at_level)
	if first != &"":
		var space_key: String = save_space()
		if not Save.is_level_unlocked_in(space_key, first):
			Save.unlock_level_in(space_key, first)
			Save.save_game()
	else:
		var campaign: Array[StringName] = Levels.get_coop_campaign(difficulty, play_book)
		first = _map_stop(campaign[0]) if not campaign.is_empty() else Levels.first_level(play_book)
		if campaign.is_empty() and first != &"":
			push_warning("Flow: book %d has no co-op file yet; the party plays the solo files" % play_book)
	if first == &"":
		push_warning("Flow: book %d has no campaign level yet" % play_book)
		goto_title()
		return
	show_world_map(first)


## The file to start for `level_id` in the running game: in co-op the co-op file of a solo level (when it has one,
## Levels.get_coop_level), otherwise `level_id` itself (single-player and versus never change it).
func level_to_play(level_id: StringName) -> StringName:
	if Game.mode == Defs.GameMode.COOP:
		var coop: StringName = Levels.get_coop_level(level_id)
		if coop != &"":
			return coop
	return level_id


## The save namespace of the running game (Save.space of Game.mode, Game.book, Game.difficulty; a versus game has
## none and answers the single-player one).
func save_space() -> String:
	var mode: int = Game.mode if Save.SPACE_MODES.has(Game.mode) else Defs.GameMode.SINGLE
	return Save.space(mode, maxi(Game.book, 1), Game.difficulty)


## 2.0: where the campaign continues when a warp ended the stop of `level_id` (a bonus stage's warp: tally, then "the
## level after the source level - so warping from 3a skips 3b", GAMEPLAY.md 1.1 / 13.1): the next stop of its book's
## campaign for `difficulty`, passing over the stop's linked sub-stages (Book II: 5-2 -> Feast Land D -> 6-1, Tusker's
## Wallow is passed over). Book I's warp stops have no sub-stage, so they continue exactly as Levels.next_level says.
## In co-op the next stop's co-op file when it has one. "" at the end of the campaign of that difficulty (the flow then
## shows the expert wall or THE END).
func stop_after_warp(level_id: StringName, difficulty: int) -> StringName:
	var stop: StringName = Levels.parent_level(level_id, difficulty)
	if stop == &"" or str(Levels.get_value(stop, "next", "", difficulty)) == "":
		return Levels.next_level(level_id, difficulty)
	var campaign: Array[StringName] = Levels.get_campaign(difficulty, maxi(Levels.get_book(stop), 1))
	var at: int = campaign.find(stop)
	if at < 0 or at + 1 >= campaign.size():
		return &""
	var following: StringName = campaign[at + 1]
	if Levels.is_coop_level(level_id):
		var coop: StringName = Levels.get_coop_level(following)
		return coop if coop != &"" else following
	return following


## 2.0: the arguments of THE END (ui-A's the_end screen): "book" (1 / 2), "mode" (Defs.GameMode) and "mural" (true at
## the end of Book II once every Cave Painting was found - The Long Raft Home ends with the cave mural, DESIGN.md C.9).
func ending_args() -> Dictionary:
	var book: int = maxi(Game.book, 1)
	return {"book": book, "mode": Game.mode, "mural": book >= Levels.BOOK_2 and UnlockTable.is_mural_open()}


## 2.0: the level select of a campaign (the code entry's list, the co-op continue): one entry per map stop of `book` for
## `difficulty` in `mode` (Defs.GameMode SINGLE or COOP), in map order - "level_id" (the solo map stop), "code" (its
## code for that difficulty; "" in co-op, whose files have none), "unlocked" (startable: the first stop always, else
## reached in that save namespace), "result" (Save.get_level_result_in: percent, score, clears). Co-op lists only the
## stops that have a co-op file. Start one with continue_game (solo, also by its code) or start_coop_game(..., at_level).
func level_select(mode: int, book: int, difficulty: int) -> Array[Dictionary]:
	var coop: bool = mode == Defs.GameMode.COOP
	var space_key: String = Save.space(Defs.GameMode.COOP if coop else Defs.GameMode.SINGLE, maxi(book, 1), difficulty)
	var stops: Array[StringName] = []
	if coop:
		for file: StringName in Levels.get_coop_campaign(difficulty, maxi(book, 1)):
			stops.append(Levels.get_coop_base(file))
	else:
		stops = Levels.get_campaign(difficulty, maxi(book, 1))
	var result: Array[Dictionary] = []
	for index: int in stops.size():
		var id: StringName = stops[index]
		result.append({
			"level_id": id, "code": "" if coop else Levels.get_password(id, difficulty),
			"unlocked": index == 0 or Save.is_level_unlocked_in(space_key, id),
			"result": Save.get_level_result_in(space_key, id),
		})
	return result


# =================================================================================================================
# 2.0: joining and leaving (DESIGN.md D.1 / D.11, GAMEPLAY.md 13.9.1)
# =================================================================================================================

## The join panel or the versus lobby opens: every player slot is free (nobody plays until he presses Jump; menus
## still answer every device through the ui_* actions). Lost pads are forgotten.
func begin_party_setup() -> void:
	_lost_pads.clear()
	for slot: int in Defs.MAX_PLAYERS:
		GameInput.assign_slot(slot, null)
	party_changed.emit(0)


## Players taking part: the seated players of the versus match on its front end (lobby), else the player slots with an
## input, counted from P1 (a party always fills slots 0..n - 1). 1 in single-player.
func party_size() -> int:
	if play_mode == Defs.GameMode.VERSUS and Game.versus_match != null and current_screen != SCREEN_LEVEL:
		return Game.versus_match.player_count()
	var count: int = 0
	for slot: int in Defs.MAX_PLAYERS:
		if GameInput.get_slot(slot).kind == Defs.InputSlotKind.NONE:
			break
		count += 1
	return count


## A player joins with `input` (GameInput.join_input_for_event: "press Jump on any device") at slot `slot` (-1 = the
## first free one). Returns the slot, or -1 when that input already plays or no seat is free (co-op takes
## PartyTuning.COOP_PLAYERS, the versus lobby Defs.MAX_PLAYERS). The single player of a running game keeps his
## device as P1 (GameInput.current_device_input). In the versus lobby the player is also seated in Game.versus_match.
## During a campaign stage the stage restarts at its checkpoint in the co-op file, score kept (on the world map the
## next start plays it).
func join_player(input: InputSlot, slot: int = -1) -> int:
	if input == null or input.kind == Defs.InputSlotKind.NONE or GameInput.find_input(input) >= 0:
		return -1
	var lobby: bool = _in_versus_lobby()
	var limit: int = Defs.MAX_PLAYERS if lobby else PartyTuning.COOP_PLAYERS
	if lobby and Game.versus_match != null and Game.versus_match.player_count() >= limit:
		return -1
	if GameInput.get_slot(0).kind == Defs.InputSlotKind.ALL_DEVICES:
		GameInput.assign_slot(0, GameInput.current_device_input(input))
		if GameInput.find_input(input) >= 0:
			return -1
	var at: int = slot if slot >= 0 else _first_free_slot(lobby)
	if at < 0 or at >= limit or GameInput.get_slot(at).kind != Defs.InputSlotKind.NONE:
		return -1
	if lobby and Game.versus_match != null:
		if Game.versus_match.seat_human(input, at) < 0:
			return -1
	GameInput.assign_slot(at, input)
	Audio.play_sfx(Sfx.PARTY_JOIN)
	party_changed.emit(party_size())
	_apply_party_change()
	return at


## Player slot `slot` leaves (the join panel, the pause menu, "continue alone" after a lost pad). The players after him
## move up a slot with their input and look, so the party stays slots 0..n - 1. Back to one player the game is
## single-player again (every device feeds P1). During a campaign stage the stage restarts at its checkpoint in the
## solo file, score kept. Returns false when nobody plays at `slot`.
func leave_player(slot: int) -> bool:
	if slot < 0 or slot >= Defs.MAX_PLAYERS:
		return false
	var lobby: bool = _in_versus_lobby()
	var seated: bool = lobby and Game.versus_match != null and Game.versus_match.is_seated(slot)
	if GameInput.get_slot(slot).kind == Defs.InputSlotKind.NONE and not seated:
		return false
	var in_run: bool = current_screen == SCREEN_LEVEL or current_screen == SCREEN_WORLD_MAP
	if in_run and not lobby and (party_size() <= 1 or GameInput.get_slot(slot).kind == Defs.InputSlotKind.ALL_DEVICES):
		return false  # the last player of a running campaign quits instead
	if lobby and Game.versus_match != null:
		Game.versus_match.unseat(slot)
		GameInput.assign_slot(slot, null)
	else:
		for at: int in range(slot, Defs.MAX_PLAYERS - 1):
			GameInput.assign_slot(at, GameInput.get_slot(at + 1))
			_copy_look(at + 1, at)
		GameInput.assign_slot(Defs.MAX_PLAYERS - 1, null)
	var lost: PackedInt32Array = PackedInt32Array()
	for lost_slot: int in _lost_pads:
		if lost_slot != slot:
			lost.append(lost_slot - 1 if lost_slot > slot and not lobby else lost_slot)
	_lost_pads = lost
	party_changed.emit(party_size())
	_apply_party_change()
	return true


## The join panel is done (every joined player held Strike): on to the book select. False (nothing happens) while fewer
## than two players joined.
func finish_join() -> bool:
	if party_size() < 2:
		return false
	play_mode = Defs.GameMode.COOP
	_open_book_select()
	return true


## Player slots whose pad was lost and is not back yet (oldest first).
func lost_pad_slots() -> PackedInt32Array:
	return _lost_pads.duplicate()


## A pad connected (`connected`) or disconnected (Input.joy_connection_changed calls it; tests call it directly). A
## lost pad of a player slot pauses running gameplay for that player ([signal pad_lost]); a pad that connects while a
## seat waits takes the oldest lost seat (Android gives a reconnected pad a new id) - the game stays paused until the
## player resumes it.
func notify_pad_connection(device_id: int, connected: bool) -> void:
	if connected:
		if _lost_pads.is_empty():
			return
		var slot: int = _lost_pads[0]
		_lost_pads.remove_at(0)
		GameInput.assign_slot(slot, InputSlot.pad(device_id))
		pad_reconnected.emit(slot)
		return
	for slot: int in Defs.MAX_PLAYERS:
		var input: InputSlot = GameInput.get_slot(slot)
		if input.kind != Defs.InputSlotKind.PAD or input.device_id != device_id or _lost_pads.has(slot):
			continue
		_lost_pads.append(slot)
		pad_lost.emit(slot)
		if current_screen == SCREEN_LEVEL and not busy and not get_tree().paused:
			pause_slot = slot
			set_paused(true)


## "Continue alone" for player slot `slot` whose pad was lost: in a campaign he leaves (leave_player); in versus a bot
## takes his hero for the rest of the match (an idle hero without bots). Returns false when that seat was not lost.
func continue_alone(slot: int) -> bool:
	var at: int = _lost_pads.find(slot)
	if at < 0:
		return false
	_lost_pads.remove_at(at)
	var versus_match: VersusMatch = Game.versus_match
	if Game.mode == Defs.GameMode.VERSUS and versus_match != null and versus_match.is_seated(slot):
		var seat: VersusMatch.Seat = versus_match.get_seat(slot)
		seat.kind = VersusMatch.SeatKind.BOT
		seat.input = null
		seat.ready = true
		GameInput.assign_slot(slot, InputSlot.bot(_bot_source(versus_match, slot, seat.bot_level)))
		return true
	return leave_player(slot)


# =================================================================================================================
# 2.0: versus (DESIGN.md E.8, TECH_AUDIT.md 4.9)
# =================================================================================================================

## Title > Play > Versus: the lobby with a match of the remembered rules (Game.versus_match; a match left from before
## keeps its rules and seats). Without a lobby screen: back to the title.
func open_versus_lobby() -> void:
	play_mode = Defs.GameMode.VERSUS
	if Game.versus_match == null:
		Game.versus_match = VersusMatch.from_settings()
	if current_screen != SCREEN_VERSUS_RULES and current_screen != SCREEN_VERSUS_ARENA:
		_lost_pads.clear()
		for slot: int in Defs.MAX_PLAYERS:
			var input: InputSlot = Game.versus_match.get_seat(slot).input
			var human: bool = Game.versus_match.get_seat(slot).kind == VersusMatch.SeatKind.HUMAN and input != null
			GameInput.assign_slot(slot, input if human else null)
	if has_screen(SCREEN_VERSUS_LOBBY):
		goto_screen(SCREEN_VERSUS_LOBBY)
	else:
		push_warning("Flow: this build has no versus lobby")
		goto_title()


## Add a bot of `level` (Defs.BotLevel) to the lobby's match ("Add CPU"). Returns its slot or -1 (no match, full).
func add_bot(level: int = Defs.BotLevel.HUNTER) -> int:
	if Game.versus_match == null:
		return -1
	var slot: int = Game.versus_match.seat_bot(level)
	if slot >= 0:
		party_changed.emit(party_size())
	return slot


## Start a versus match (the arena screen's "go"; `p_match` = Game.versus_match when null): seats are compacted to
## slots 0..n - 1, the rules remembered, the run started (Game.start_run VERSUS with the seats' colours), humans read
## their inputs, bots their HeroBot sources, and round 0 starts. `seed_value` < 0 = a fresh match seed. Returns false
## (nothing happens) when the match cannot start (VersusMatch.can_start).
func start_versus(p_match: VersusMatch = null, seed_value: int = -1) -> bool:
	var versus_match: VersusMatch = p_match if p_match != null else Game.versus_match
	if versus_match == null or not versus_match.can_start():
		push_warning("Flow.start_versus: the match cannot start (two players, every human ready)")
		return false
	play_mode = Defs.GameMode.VERSUS
	Game.versus_match = versus_match
	versus_match.compact_seats()
	versus_match.remember_rules()
	versus_match.begin_match(seed_value if seed_value >= 0 else int(Time.get_ticks_usec() & 0x7FFFFFFF))
	_begin_versus_run(versus_match)
	start_round()
	return true


## Start the current round of Game.versus_match: its arena (VersusMatch.arena_for_round) behind the curtain, Sim.rng
## seeded with the round seed before the first tick, bot inputs fresh for the round. The referee (world-B) runs the
## countdown, the clock and the gong in the level and calls end_round. After the last round: the results.
func start_round() -> void:
	var versus_match: VersusMatch = Game.versus_match
	if versus_match == null or busy:
		return
	_cancel_replay()
	if versus_match.is_over():
		_show_versus_results()
		return
	var arena_id: StringName = versus_match.arena_for_round(versus_match.round_index)
	if arena_id == &"" or not Levels.has_level(arena_id):
		push_warning("Flow.start_round: no arena for %d players" % versus_match.player_count())
		leave_versus()
		return
	versus_match.begin_round(arena_id)
	_assign_bot_inputs(versus_match)
	_pending_seed = versus_match.round_seed()
	versus_match.replay = VersusReplay.begin(versus_match, arena_id, _pending_seed, Game.runs)
	_record_round(true)
	start_level(arena_id, Defs.Transition.CURTAIN)


## The referee's gong (callable inside a tick): the round is over, `winners` (one slot, both of a team, or none for a
## draw) win it. Records it (VersusMatch.record_round), emits Events.round_ended, then shows the scoreboard (whose end
## calls next_round), or the results after the last round. Ignored when no round is being played.
func end_round(winners: PackedInt32Array) -> void:
	var versus_match: VersusMatch = Game.versus_match
	if Game.mode != Defs.GameMode.VERSUS or versus_match == null or not versus_match.round_open:
		return
	var index: int = versus_match.round_index
	Audio.play_sfx(Sfx.ROUND_GONG)
	_record_round(false)
	if versus_match.replay != null:
		versus_match.replay.finish(Sim.tick, Game.runs)
	versus_match.record_round(winners)
	var recorded: PackedInt32Array = versus_match.history[-1]["winners"]
	Events.round_ended.emit(index, recorded)
	if deciding_moment and play_deciding_moment():
		return
	_after_round(index, recorded)


## 2.0: play the deciding moment of the round that just ended (DESIGN.md E.8 step 5; [member deciding_moment] makes
## end_round call it): the round's arena loads again behind the curtain with the round's seed and its start snapshot
## (VersusReplay: the match's round state and every hero's run), every hero is fed from the input log, the ticks before
## the window run at once with the effects muted, and the window (VersusReplay.window: the last 3 s, Grub Stack the
## biggest steal) plays at half speed (Sim.time_scale). Then - at the window's end or on [method skip_replay] - the
## match state and the runs the round left come back and the scoreboard (or the results) follows. Returns false (nothing
## happens) when no recorded round waits for its replay.
func play_deciding_moment() -> bool:
	var versus_match: VersusMatch = Game.versus_match
	if busy or _replaying or versus_match == null or versus_match.round_open or versus_match.history.is_empty():
		return false
	var replay: VersusReplay = versus_match.replay
	if replay == null or not replay.can_replay() or not Levels.has_level(replay.arena) or _level_scene_path().is_empty():
		return false
	var history: Dictionary = versus_match.history[-1]
	_replay_after = [replay.round_index, history["winners"]]
	_replay_end_state = {
		"round_index": versus_match.round_index, "round_mode": versus_match.round_mode,
		"round_arena": versus_match.round_arena, "round_wins": versus_match.round_wins.duplicate(),
	}
	_replaying = true
	_replay_window = replay.window()
	_pending_seed = replay.seed_value
	_pending_fast_forward = _replay_window.x - 1
	# The round's own level stops at once (its gong tick still ends): a tick more would write the runs again. The start
	# state goes back while the curtain hides it, before the level loads again (its heroes spawn from the runs).
	Sim.frozen = true
	if not transition_covered.is_connected(_prepare_replay):
		transition_covered.connect(_prepare_replay, CONNECT_ONE_SHOT)
	start_level(replay.arena, Defs.Transition.CURTAIN)
	return true


## 2.0: true while the deciding moment of a versus round plays (Flow.play_deciding_moment).
func is_replaying() -> bool:
	return _replaying


## 2.0: the ticks of the round the deciding moment shows, first and last (Vector2i.ZERO while none plays).
func replay_window() -> Vector2i:
	return _replay_window if _replaying else Vector2i.ZERO


## 2.0: skip the deciding moment (any player's Jump, Strike, accept or pause does; the HUD's touch button calls it):
## the scoreboard (or the results) follows at once. Nothing happens while none plays.
func skip_replay() -> void:
	if not _replaying:
		return
	if busy:
		# The curtain is still opening on the replay: skip the moment it is open.
		if not transition_finished.is_connected(skip_replay):
			transition_finished.connect(skip_replay, CONNECT_ONE_SHOT)
		return
	_finish_replay(true)


## The scoreboard is done: the next round (or the results when the match is over).
func next_round() -> void:
	start_round()


## The results' default button: the same players, rules and arena choice again, from round 0 with a new seed.
func rematch() -> void:
	var versus_match: VersusMatch = Game.versus_match
	if versus_match == null:
		return
	_cancel_replay()
	versus_match.rematch()
	_begin_versus_run(versus_match)
	start_round()


## Leave the match: back to the lobby (seats and rules kept) or, with `to_title` or without a lobby screen, the title.
func leave_versus(to_title: bool = false) -> void:
	_cancel_replay()
	_record_round(false)
	if Game.versus_match != null:
		Game.versus_match.round_open = false
	if to_title or not has_screen(SCREEN_VERSUS_LOBBY):
		goto_title()
	else:
		open_versus_lobby()


## Hide the screen with a transition, call `action` while nothing is visible, then uncover again - without
## changing the scene. For everything that moves the hero behind a curtain: gates, the respawn after a death,
## warps inside a level. Await it to continue after the screen is uncovered.
##
## The simulation stands still (Sim.frozen) from the end of the current tick until the screen is uncovered, and
## device input is ignored meanwhile, so the call may come from inside a tick and `action` always runs between
## two ticks. `action` may start a scene change itself (Flow.game_over(), Flow.start_level()): that transition
## then takes over the cover. The request is ignored while [member busy].
func play_covered(action: Callable, transition: int = Defs.Transition.CURTAIN) -> void:
	if busy:
		return
	busy = true
	_transition_serial += 1
	var serial: int = _transition_serial
	GameInput.enabled = false
	if Sim.is_in_tick():
		await Sim.tick_finished
	Sim.frozen = true
	await _animate_cover(1.0, transition)
	# A scene change requested by the action must not be refused as "busy".
	busy = false
	if action.is_valid():
		action.call()
	if serial != _transition_serial:
		# The action started a scene change: it owns the cover, the clock and the input from here on.
		return
	busy = true
	await _animate_cover(0.0, transition)
	Sim.frozen = false
	GameInput.enabled = true
	busy = false
	_pause_if_inactive()


## Background loading (ARCHITECTURE.md 11 "Loading"; automatic on menu screens and the world map while
## [member background_loading] is on): start loading on worker threads what a level start needs - the level scene,
## the HUD, touch and pause overlays, the hero, every effect / item / projectile scene - and, for `level_id`, the
## scenes of its entities, its terrain, liquid, backdrop and prop pictures, enemy sheets named by `skin=` and its music.
## Returns at once; a level start that comes first waits for the loads it needs in its own load() calls.
func warm_up(level_id: StringName = &"") -> void:
	_warmup.request(LEVEL_SCENE, &"", true)
	for path: String in [HUD_SCENE, TOUCH_SCENE, PAUSE_SCENE]:
		_warmup.request(path, &"", true)
	_warmup.request(Spawner.scene_path(&"player/player"), &"player/player")
	for category_name: String in Spawner.RUNTIME_CATEGORIES:
		for file: String in ResourceLoader.list_directory(Spawner.SCENE_ROOT + category_name):
			if file.get_extension() == "tscn":
				var id: StringName = StringName(category_name + "/" + file.get_basename())
				_warmup.request(Spawner.scene_path(id), id)
	level_id = level_to_play(level_id)
	if level_id == &"" or not Levels.has_level(level_id):
		return
	var data: LevelData = LevelData.load_file(Levels.get_level_path(level_id))
	if data == null:
		return
	var difficulty: int = Game.difficulty
	for record: Dictionary in data.entity_records():
		var id: StringName = record["id"]
		var params: Dictionary = record["params"]
		if not LevelText.applies_to(params, difficulty):
			continue
		if Spawner.is_prop(id):
			_warmup.request(Spawner.prop_texture_path(id))
		elif Spawner.exists(id):
			_warmup.request(Spawner.scene_path(id), id)
		if params.has("skin"):
			var skin: EnemySkin = EnemySkin.find(str(params["skin"]))
			if skin != null:
				_warmup.request(skin.texture_path)
	var meta: Dictionary = data.resolved_meta(difficulty)
	var terrain_a: String = str(meta.get("terrain_a", ""))
	for atlas: String in [terrain_a, str(meta.get("terrain_b", terrain_a))]:
		if WorldTileSet.has_terrain(atlas):
			_warmup.request(LevelData.terrain_path(atlas))
	var liquid: String = str(meta.get("liquid", "water"))
	if WorldTileSet.has_liquid(liquid):
		_warmup.request(LevelData.liquid_path(liquid))
	for layer: Dictionary in ParallaxSets.layers(str(meta.get("background", "none"))):
		_warmup.request(ParallaxSets.texture_path(layer))
	for context: StringName in [StringName(str(meta.get("music", ""))), Sfx.MUSIC_FEAST]:
		var entry: Dictionary = AudioTable.MUSIC.get(context, {})
		if not entry.is_empty():
			_warmup.request(AudioTable.MUSIC_DIR + str(entry["file"]))


## True while background loads requested by [method warm_up] are still running (tests, diagnostics).
func is_warming_up() -> bool:
	return _warmup.is_busy()


## Wait for every background load requested by [method warm_up] (tests; the application exit does it itself).
func finish_warm_up() -> void:
	_warmup.finish_all()


## The node that draws the transitions (read-only for everybody but Flow; tests and debug overlays look at it).
func get_transition_cover() -> TransitionCover:
	return _cover


## Leave the application (desktop). On mobile the OS decides; this only returns to the title.
func quit_game() -> void:
	if OS.has_feature("mobile") or OS.has_feature("web"):
		Settings.save()
		goto_title()
		return
	shutdown_and_quit(0)


## Leave the application cleanly: save settings, stop the simulation, release audio (the audio thread needs a
## moment to let go of its playbacks), then quit with `exit_code`. Every code path that quits goes through here.
func shutdown_and_quit(exit_code: int = 0) -> void:
	if _quitting:
		return
	_quitting = true
	busy = true
	Settings.save()
	# Background loads must not be cut off by the exit (worker threads holding half-loaded resources).
	_warmup.finish_all()
	Sim.stop()
	Audio.shutdown()
	await get_tree().create_timer(0.25, true, false, true).timeout
	get_tree().quit(exit_code)


## CanvasLayer for HUD (Defs.LAYER_HUD), touch controls (LAYER_TOUCH) or menus (LAYER_MENU).
func get_overlay(layer: int) -> CanvasLayer:
	match layer:
		Defs.LAYER_HUD:
			return _overlay_hud
		Defs.LAYER_TOUCH:
			return _overlay_touch
		_:
			return _overlay_menu


func _make_overlay(layer: int) -> CanvasLayer:
	var overlay: CanvasLayer = CanvasLayer.new()
	overlay.layer = layer
	add_child(overlay)
	return overlay


func _clear_overlays() -> void:
	for overlay: CanvasLayer in [_overlay_hud, _overlay_touch, _overlay_menu]:
		for child: Node in overlay.get_children():
			child.queue_free()


func _fill_overlays() -> void:
	_add_overlay_scene(HUD_SCENE, _overlay_hud)
	_add_overlay_scene(TOUCH_SCENE, _overlay_touch)
	_add_overlay_scene(PAUSE_SCENE, _overlay_menu)


func _add_overlay_scene(path: String, overlay: CanvasLayer) -> void:
	if not ResourceLoader.exists(path):
		return
	var scene: PackedScene = load(path) as PackedScene
	if scene != null:
		overlay.add_child(scene.instantiate())


func _change_scene(path: String, screen: StringName, transition: int, p_args: Dictionary) -> void:
	if busy:
		return
	busy = true
	_transition_serial += 1
	GameInput.enabled = false
	if Sim.is_in_tick():
		# Requested by the simulation (an exit, a death): the tick finishes first. With instant transitions the
		# scene change would otherwise load the next scene inside the tick.
		await Sim.tick_finished
	# The old scene stays alive while the cover closes (the exit animation plays under the iris).
	await _animate_cover(1.0, transition)
	transition_covered.emit()
	get_tree().paused = false
	Sim.stop()
	# A new level starts its clock in _ready, but its first tick waits until the player can see it.
	Sim.frozen = true
	Audio.stop_all_loops()
	_clear_overlays()
	args = p_args
	current_screen = screen
	var err: Error = get_tree().change_scene_to_file(path)
	if err != OK:
		push_error("Flow: cannot change to %s (error %d)" % [path, err])
	# The new scene is attached at the end of this frame.
	await get_tree().process_frame
	await get_tree().process_frame
	if screen == SCREEN_LEVEL:
		_fill_overlays()
		# The level loaded what it needs and holds its pictures and music itself now.
		_warmup.drop_queue()
		_warmup.next_level.clear()
		if p_args.has("seed") or p_args.has("entry_checkpoint"):
			_apply_level_extras(p_args)
	GameInput.enabled = true
	screen_changed.emit(screen)
	if background_loading and screen != SCREEN_LEVEL:
		# Menus and the map have time to spare: load what the next level start needs (the map knows the level).
		# The screen is still covered: scripts and scenes are put together now, where a long frame is never seen.
		warm_up(StringName(str(args.get("level_id", ""))) if screen == SCREEN_WORLD_MAP else &"")
		_warmup.load_queue(Warmup.COVERED_BUDGET_USEC)
	await _animate_cover(0.0, transition)
	Sim.frozen = false
	busy = false
	_pause_if_inactive()
	transition_finished.emit()


# =================================================================================================================
# 2.0 internals
# =================================================================================================================

## The `kind` a campaign rule sees for a level: a co-op file has the kind of its solo level (bonus, ending, sub ...).
func _campaign_kind(level_id: StringName) -> String:
	var source: StringName = level_id
	if Levels.is_coop_level(level_id):
		var base: StringName = Levels.get_coop_base(level_id)
		if Levels.has_level(base):
			source = base
	return str(Levels.get_value(source, "kind", Levels.KIND_MAIN))


## The map stop id of a level: a co-op file's solo level, any other level itself.
func _map_stop(level_id: StringName) -> StringName:
	if Levels.is_coop_level(level_id):
		return Levels.get_coop_base(level_id)
	return level_id


## Hand and belt of every hero are kept in the save of a Book II or co-op run (Save.set_belt_in, DESIGN.md C.1). A
## Book I solo run stores nothing (its save stays as 1.0 wrote it).
func _store_belts(space_key: String) -> void:
	if Game.mode == Defs.GameMode.SINGLE and Game.book <= 1:
		return
	for slot: int in Game.party:
		var run: PlayerRun = Game.runs[slot]
		Save.set_belt_in(space_key, slot, run.weapon, run.belt)


## Back to the single-player input (slot 0 reads every device) when a party's slots are set; nothing otherwise, so a
## single-player game's input is never touched.
func _reset_party_input() -> void:
	var party_input: bool = GameInput.is_party_input()
	for slot: int in range(1, Defs.MAX_PLAYERS):
		if GameInput.get_slot(slot).kind != Defs.InputSlotKind.NONE:
			party_input = true
	if party_input:
		GameInput.reset_slots()


## Make sure player slots 0..size - 1 have an input (a slot nobody joined: the left keyboard half, the right one,
## then the connected pads, each only when no other slot reads it) and the slots after them none.
func _ensure_party_inputs(size: int) -> void:
	if GameInput.get_slot(0).kind == Defs.InputSlotKind.ALL_DEVICES:
		GameInput.assign_slot(0, null)
	var candidates: Array[InputSlot] = [
		InputSlot.keyboard(Defs.InputSlotKind.KEYBOARD_LEFT), InputSlot.keyboard(Defs.InputSlotKind.KEYBOARD_RIGHT),
	]
	for pad_id: int in Input.get_connected_joypads():
		candidates.append(InputSlot.pad(pad_id))
	for slot: int in Defs.MAX_PLAYERS:
		if slot >= size:
			GameInput.assign_slot(slot, null)
			continue
		if GameInput.get_slot(slot).kind != Defs.InputSlotKind.NONE:
			continue
		for candidate: InputSlot in candidates:
			if GameInput.find_input(candidate) < 0:
				GameInput.assign_slot(slot, candidate)
				break


func _in_versus_lobby() -> bool:
	return play_mode == Defs.GameMode.VERSUS and Game.versus_match != null and current_screen != SCREEN_LEVEL


## The first player slot without an input (in the versus lobby: and without a seat); -1 when all are taken.
func _first_free_slot(lobby: bool) -> int:
	for slot: int in Defs.MAX_PLAYERS:
		if GameInput.get_slot(slot).kind != Defs.InputSlotKind.NONE:
			continue
		if lobby and Game.versus_match != null and Game.versus_match.is_seated(slot):
			continue
		return slot
	return -1


## The look and weapons of the hero of slot `from` move to slot `to` (a player left; the ones after him move up).
func _copy_look(from: int, to: int) -> void:
	var source: PlayerRun = Game.runs[from]
	var target: PlayerRun = Game.runs[to]
	target.palette = source.palette
	target.pattern = source.pattern
	if Game.mode != Defs.GameMode.SINGLE:
		target.set_weapon(source.weapon)
		target.set_belt(source.belt)


## A join or a leave during a campaign run: the run continues with the new party (Game.set_party); mid-stage the stage
## restarts at its checkpoint in the other layout, score kept (DESIGN.md D.1). Nothing on the front end (the run that
## starts later takes the party) and nothing in versus.
func _apply_party_change() -> void:
	if play_mode == Defs.GameMode.VERSUS or Game.mode == Defs.GameMode.VERSUS:
		return
	if current_screen != SCREEN_LEVEL and current_screen != SCREEN_WORLD_MAP:
		return
	var size: int = party_size()
	if size <= 1:
		GameInput.reset_slots()
		size = 1
	var mode: int = Defs.GameMode.COOP if size >= 2 else Defs.GameMode.SINGLE
	if mode == Game.mode and size == Game.party:
		return
	Game.set_party(mode, size)
	Game.helper_mode = mode == Defs.GameMode.COOP and Settings.get_bool(HELPER_MODE_KEY)
	play_mode = mode
	if current_screen != SCREEN_LEVEL or Game.level_id == &"":
		return
	var target: StringName = Levels.level_for_mode(Game.level_id, mode)
	if target == &"":
		target = Game.level_id
	_entry_checkpoint = [Game.has_checkpoint, Game.checkpoint_pos]
	start_level(target, Defs.Transition.CURTAIN, false)


## What a level start applies once the level is loaded, taken from the pending requests (and cleared): the checkpoint
## of a party change ("entry_checkpoint": [has, pos]) and the seed of a versus round ("seed"). Empty for every 1.0 start.
func _take_level_extras() -> Dictionary:
	var extras: Dictionary = {}
	if not _entry_checkpoint.is_empty():
		extras["entry_checkpoint"] = _entry_checkpoint
	if _pending_seed >= 0:
		extras["seed"] = _pending_seed
	if _pending_fast_forward >= 0:
		extras["fast_forward"] = _pending_fast_forward
	_entry_checkpoint = []
	_pending_seed = -1
	_pending_fast_forward = -1
	return extras


## The new level is loaded and its clock has not ticked yet: seed a versus round's Sim.rng, put the heroes of a party
## change at the checkpoint they had reached (Game.set_checkpoint; each hero at his spread respawn point). A
## deciding-moment replay ("fast_forward": ticks) runs the round up to its window here, behind the curtain, with the
## effects muted, then plays on at half speed. A versus round plays its round's music (_play_round_music).
func _apply_level_extras(level_args: Dictionary) -> void:
	if level_args.has("seed"):
		Sim.rng.reseed(int(level_args["seed"]))
		_play_round_music()
	if level_args.has("fast_forward") and _replaying:
		Audio.set_effects_muted(true)
		Sim.step(int(level_args["fast_forward"]))
		Audio.set_effects_muted(false)
		Sim.time_scale = VersusReplay.REPLAY_SPEED
		if not Sim.tick_finished.is_connected(_on_replay_tick):
			Sim.tick_finished.connect(_on_replay_tick)
		var replay: VersusReplay = Game.versus_match.replay if Game.versus_match != null else null
		replay_started.emit(_replay_after[0] if not _replay_after.is_empty() else 0, _replay_window.x,
				_replay_window.y, replay != null and replay.shows_steal())
	var entry: Array = level_args.get("entry_checkpoint", [])
	var level: LevelBase = Game.level
	if entry.size() == 2 and bool(entry[0]) and level != null:
		Game.set_checkpoint(entry[1])
		for hero: PlayerBase in level.contact_order().duplicate():
			level.respawn_hero(hero, level.get_respawn_pos_for(hero.slot))
		level.snap_camera()


## A versus round's arena is loaded (it started its own `music`): the round's track instead when the arena plays one of
## the battle tracks (VersusMatch.round_music: A, B, C in turn from round to round). The deciding moment loads the
## arena with the round's start state, so it plays the round's own track again. Sound only.
func _play_round_music() -> void:
	var versus_match: VersusMatch = Game.versus_match
	if Game.mode != Defs.GameMode.VERSUS or versus_match == null or Game.level == null:
		return
	var own: StringName = StringName(str(Levels.get_value(versus_match.round_arena, "music", "")))
	var music: StringName = VersusMatch.round_music(own, versus_match.round_index)
	if music != own and AudioTable.MUSIC.has(music):
		Audio.play_music(music)


func _open_book_select() -> void:
	if has_screen(SCREEN_BOOK_SELECT):
		goto_screen(SCREEN_BOOK_SELECT)
	elif has_screen(SCREEN_MODE_SELECT):
		goto_screen(SCREEN_MODE_SELECT)
	else:
		start_selected_game(Settings.get_int("game/last_difficulty"))


## A versus run for the match's seats: Game.start_run (VERSUS, a hero per seat, zeroed statistics), the seats'
## colours, the humans' inputs (bots get theirs per round), the rest of the slots free.
func _begin_versus_run(versus_match: VersusMatch) -> void:
	_lost_pads.clear()
	Game.start_run(Defs.Difficulty.BEGINNER, Defs.GameMode.VERSUS, versus_match.player_count(), 1)
	for slot: int in Defs.MAX_PLAYERS:
		var seat: VersusMatch.Seat = versus_match.get_seat(slot)
		if seat.is_taken():
			Game.runs[slot].palette = seat.palette
			Game.runs[slot].pattern = seat.pattern
		if seat.kind == VersusMatch.SeatKind.HUMAN and seat.input != null:
			GameInput.assign_slot(slot, seat.input)
		elif seat.kind != VersusMatch.SeatKind.BOT:
			GameInput.assign_slot(slot, null)


func _assign_bot_inputs(versus_match: VersusMatch) -> void:
	for slot: int in Defs.MAX_PLAYERS:
		var seat: VersusMatch.Seat = versus_match.get_seat(slot)
		if seat.kind == VersusMatch.SeatKind.BOT:
			GameInput.assign_slot(slot, InputSlot.bot(_bot_source(versus_match, slot, seat.bot_level)))


## The flags source of the bot of `slot` this round: VersusMatch.bot_factory (a tool's or test's source), else the
## seat's HeroBot (core-B; created once per match, its own stream restarted from the round seed), else an idle bot.
func _bot_source(versus_match: VersusMatch, slot: int, bot_level: int) -> Callable:
	if VersusMatch.bot_factory.is_valid():
		var made: Variant = VersusMatch.bot_factory.call(slot, bot_level, versus_match.bot_seed(slot))
		if made is Callable and (made as Callable).is_valid():
			return made
	var bot: Object = versus_match.bots[slot] as Object
	if bot == null and ResourceLoader.exists(VersusMatch.HERO_BOT_PATH):
		var script: GDScript = load(VersusMatch.HERO_BOT_PATH) as GDScript
		if script != null and script.can_instantiate():
			bot = script.new(slot, bot_level, versus_match.match_seed, versus_match.round_mode) as Object
			versus_match.bots[slot] = bot
	if bot != null and bot.has_method(&"produce"):
		if bot.has_method(&"reset_round"):
			bot.call(&"reset_round", versus_match.round_seed())
		return Callable(bot, &"produce")
	return _idle_bot


func _idle_bot(_tick: int) -> int:
	return 0


## What follows a recorded round (and its deciding moment): the results after the last round, else the scoreboard (whose
## end calls next_round), else at once the next round.
func _after_round(index: int, winners: PackedInt32Array) -> void:
	var versus_match: VersusMatch = Game.versus_match
	if versus_match == null:
		goto_title()
	elif versus_match.is_over():
		_show_versus_results()
	elif has_screen(SCREEN_VERSUS_SCOREBOARD):
		goto_screen(SCREEN_VERSUS_SCOREBOARD, Defs.Transition.IRIS, {"round_index": index, "winners": winners})
	else:
		next_round()


## Start (true) or stop (false) logging the round being played into Game.versus_match.replay (VersusReplay): the flags of
## every hero after each tick's sampling, the steals after each tick. Connected only while a round plays, so a
## single-player tick never runs a handler of it.
func _record_round(on: bool) -> void:
	for pair: Array in [[Sim.tick_started, _on_round_tick_started], [Sim.tick_finished, _on_round_tick_finished]]:
		var source: Signal = pair[0]
		var handler: Callable = pair[1]
		if on and not source.is_connected(handler):
			source.connect(handler)
		elif not on and source.is_connected(handler):
			source.disconnect(handler)


## The round's own level runs tick `tick`: log the flags its heroes play (GameInput sampled them just before).
func _on_round_tick_started(tick: int) -> void:
	var replay: VersusReplay = _round_replay()
	if replay == null:
		return
	var flags: PackedInt32Array = PackedInt32Array()
	for slot: int in replay.players:
		flags.append(GameInput.get_flags(slot))
	replay.log_tick(tick, flags)


func _on_round_tick_finished(tick: int) -> void:
	var replay: VersusReplay = _round_replay()
	if replay != null:
		replay.note_tick(tick, Game.runs)


## The recording of the round being played on its own level (null otherwise: another level, no round, the replay).
func _round_replay() -> VersusReplay:
	var versus_match: VersusMatch = Game.versus_match
	if _replaying or versus_match == null or not versus_match.round_open or versus_match.replay == null:
		return null
	var level: LevelBase = Game.level
	if level == null or level.level_id != versus_match.replay.arena:
		return null
	return versus_match.replay


## The curtain hides the ended round (play_deciding_moment): the match's round state and every run go back to how the
## round started, and the log feeds every hero, before the arena loads again.
func _prepare_replay() -> void:
	var versus_match: VersusMatch = Game.versus_match
	if not _replaying or versus_match == null or versus_match.replay == null:
		return
	var replay: VersusReplay = versus_match.replay
	replay.apply_start_state(versus_match)
	# The snapshot was taken just before the round's start_level; its begin_level then reset energy and glider: again.
	VersusReplay.restore_runs(replay.start_runs, Game.runs)
	Game.begin_level(replay.arena, false)
	_replay_saved_scripts.clear()
	for slot: int in replay.players:
		_replay_saved_scripts[slot] = GameInput.get_scripted_slot(slot)
		GameInput.set_scripted_slot(slot, _replay_flags.bind(slot))


## The flags of slot `slot` on tick `tick` of the replayed round (its scripted source).
func _replay_flags(tick: int, slot: int) -> int:
	var replay: VersusReplay = Game.versus_match.replay if Game.versus_match != null else null
	return replay.flags_at(tick, slot) if replay != null else 0


## The replay's clock reached the end of its window: the round goes on to its scoreboard.
func _on_replay_tick(tick: int) -> void:
	if _replaying and tick >= _replay_window.y:
		_finish_replay(false)


## End the deciding moment: the clock stops at once (a tick after the window would write the runs again), the scripts
## and the match state the round left come back, then the scoreboard or the results.
func _finish_replay(skipped: bool) -> void:
	var after: Array = _replay_after
	_end_replay_state()
	replay_finished.emit(skipped)
	if after.size() == 2:
		_after_round(int(after[0]), after[1])


## Leave a replay without what follows it (title, lobby, rematch, a new round): only the state comes back.
func _cancel_replay() -> void:
	if _replaying:
		_end_replay_state()
		replay_finished.emit(true)


func _end_replay_state() -> void:
	_replaying = false
	Sim.frozen = true
	Sim.time_scale = 1.0
	_pending_fast_forward = -1
	if Sim.tick_finished.is_connected(_on_replay_tick):
		Sim.tick_finished.disconnect(_on_replay_tick)
	if transition_covered.is_connected(_prepare_replay):
		transition_covered.disconnect(_prepare_replay)
	if transition_finished.is_connected(skip_replay):
		transition_finished.disconnect(skip_replay)
	Audio.set_effects_muted(false)
	for slot: int in _replay_saved_scripts:
		var saved: Callable = _replay_saved_scripts[slot]
		if saved.is_valid():
			GameInput.set_scripted_slot(slot, saved)
		else:
			GameInput.clear_scripted_slot(slot)
	_replay_saved_scripts.clear()
	var versus_match: VersusMatch = Game.versus_match
	if versus_match != null and not _replay_end_state.is_empty():
		versus_match.round_index = int(_replay_end_state["round_index"])
		versus_match.round_mode = int(_replay_end_state["round_mode"])
		versus_match.round_arena = _replay_end_state["round_arena"]
		versus_match.round_wins = (_replay_end_state["round_wins"] as PackedInt32Array).duplicate()
		if versus_match.replay != null:
			VersusReplay.restore_runs(versus_match.replay.end_runs, Game.runs)
	_replay_end_state = {}
	_replay_after = []
	_replay_window = Vector2i.ZERO


## The keys that skip the deciding moment: any player's Jump or Strike (every slot's own actions too), accept, cancel,
## pause, a tap.
func _skips_replay(event: InputEvent) -> bool:
	if event.is_echo() or not event.is_pressed():
		return false
	if event is InputEventScreenTouch:
		return true
	for action: StringName in [&"ui_accept", &"ui_cancel", Defs.ACT_PAUSE, Defs.ACT_JUMP, Defs.ACT_ATTACK]:
		if InputMap.has_action(action) and event.is_action_pressed(action):
			return true
	for slot: int in Defs.MAX_PLAYERS:
		for action: StringName in [Defs.ACT_JUMP, Defs.ACT_ATTACK]:
			var generated: StringName = GameInput.slot_action(slot, action)
			if InputMap.has_action(generated) and event.is_action_pressed(generated):
				return true
	return false


## A versus round's themed sudden death began (the referee, DESIGN.md E.6): its music plays for the rest of the round.
func _on_sudden_death_started(_round_index: int, _kind: StringName) -> void:
	if Game.mode == Defs.GameMode.VERSUS and current_screen == SCREEN_LEVEL:
		Audio.push_music(Sfx.MUSIC_VERSUS_SUDDEN_DEATH)


func _show_versus_results() -> void:
	var versus_match: VersusMatch = Game.versus_match
	if versus_match == null:
		goto_title()
		return
	versus_match.finish(Game.runs)
	if has_screen(SCREEN_VERSUS_RESULTS):
		goto_screen(SCREEN_VERSUS_RESULTS, Defs.Transition.IRIS, {
			"winners": versus_match.leaders(), "awards": versus_match.hand_out_awards(Game.runs),
		})
	else:
		leave_versus()


## Gameplay scene of this build: the world module's level, else the debug level (development only: exports do
## not contain it), else "".
func _level_scene_path() -> String:
	if ResourceLoader.exists(LEVEL_SCENE):
		return LEVEL_SCENE
	if ResourceLoader.exists(DEBUG_LEVEL_SCENE):
		return DEBUG_LEVEL_SCENE
	return ""


## Move the cover to `target` (1 = everything hidden, 0 = everything visible) with the shape of `transition`.
func _animate_cover(target: float, transition: int) -> void:
	if _cover_tween != null and _cover_tween.is_valid():
		_cover_tween.kill()
	set_process(false)
	var shape: int = Defs.Transition.FADE if transition == Defs.Transition.NONE else transition
	var closing: bool = target > _cover.amount
	_cover.shape = shape
	if is_equal_approx(_cover.amount, target):
		# Already there: a covered action handed its fully covered screen over to a scene change.
		return
	_cover.focus = _transition_focus(shape)
	if instant_transitions or transition == Defs.Transition.NONE:
		_cover.amount = target
		return
	var speed: float = maxf(transition_speed, 0.01)
	_cover_tween = create_tween()
	_cover_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	match shape:
		Defs.Transition.CURTAIN:
			_cover_tween.tween_property(_cover, "amount", target, CURTAIN_SECONDS / speed)
		Defs.Transition.IRIS:
			if closing:
				# Close in on the hero, rest as a spotlight, then shut. The hero may still move: follow him.
				set_process(true)
				var spotlight: float = maxf(_cover.amount_for_opening(IRIS_HOLD_RADIUS), _cover.amount)
				_cover_tween.tween_property(_cover, "amount", spotlight, IRIS_SECONDS / speed)
				_cover_tween.tween_interval(IRIS_HOLD_SECONDS / speed)
				_cover_tween.tween_property(_cover, "amount", target, IRIS_SHUT_SECONDS / speed)
			else:
				_cover_tween.tween_property(_cover, "amount", target, IRIS_SECONDS / speed)
		_:
			_cover_tween.tween_property(_cover, "amount", target, FADE_SECONDS / speed)
	await _cover_tween.finished
	set_process(false)


## Where a transition is centred, in viewport px: the middle of the hero for the iris (when a level with a hero
## is on screen), otherwise the middle of the screen. A party: the middle of its living heroes (of all of them when
## none is alive).
func _transition_focus(shape: int) -> Vector2:
	var centre: Vector2 = _cover.size * 0.5
	if shape != Defs.Transition.IRIS:
		return centre
	var level: LevelBase = Game.level
	if level != null and level.hero_count() > 1:
		return _party_focus(level, centre)
	if level == null or level.player == null or not level.player.is_inside_tree():
		return centre
	var hero: PlayerBase = level.player
	var at: Vector2 = hero.get_global_transform_with_canvas().origin
	at.y -= float(hero.box_h * Tuning.ART_SCALE) * 0.5
	return at.clamp(Vector2.ZERO, _cover.size)


## The iris focus of a party: the mean of its heroes' middles (living heroes first), in viewport px.
func _party_focus(level: LevelBase, centre: Vector2) -> Vector2:
	var sum: Vector2 = Vector2.ZERO
	var count: int = 0
	for pass_index: int in 2:
		for hero: PlayerBase in level.contact_order():
			if not hero.is_inside_tree() or (pass_index == 0 and (hero.dead or hero.is_down())):
				continue
			var at: Vector2 = hero.get_global_transform_with_canvas().origin
			at.y -= float(hero.box_h * Tuning.ART_SCALE) * 0.5
			sum += at
			count += 1
		if count > 0:
			break
	if count == 0:
		return centre
	return (sum / float(count)).clamp(Vector2.ZERO, _cover.size)


## The application gained or lost the foreground (window focus and "resumed" state together).
func _update_app_active() -> void:
	var active: bool = _app_focused and _app_resumed
	if active == _app_active:
		return
	_app_active = active
	if not pause_on_focus_loss:
		return
	# Suspend first: the pause cue must not wait in a paused voice for the player to come back.
	Audio.set_suspended(not active)
	_pause_if_inactive()


## Gameplay never runs while the player cannot see it. Resuming is the player's decision (pause menu).
func _pause_if_inactive() -> void:
	if pause_on_focus_loss and not _app_active and not busy:
		set_paused(true)


## Deliver one press and release of `ui_cancel` to the focused screen.
func _send_cancel_action() -> void:
	for pressed: bool in [true, false]:
		var event: InputEventAction = InputEventAction.new()
		event.action = &"ui_cancel"
		event.pressed = pressed
		Input.parse_input_event(event)
