extends TestCase
## Weapon proofs of Canopy Village (w1_l2), Feast Land A (bonus_a), Echo Caverns (w2_l1), Feast Land B (bonus_b),
## Bone Gorge (w2_l2) and the Brute's Den (w2_l2b). Owner: level design (worlds 1-2).
##
## A run keeps its weapon from stage to stage until game over (GAMEPLAY.md 8.1), and a stage started from its code
## begins with the club, so a stage must be finishable with every weapon a player can hold when entering it, on every
## difficulty it exists in. The weapons on entry follow from the pick-ups: the axe lies in Canopy Village, the hammer
## in Echo Caverns (ENTRY_WEAPONS). A swing locks the hero for the weapon's recovery (club 2 ticks, hammer and axe 6,
## swirling axe 12); the axe and the swirling axe are thrown, club and hammer are melee.
##
## Every (stage, difficulty, weapon) cell has a route file (CELLS): `<id>[.expert].<weapon>.inputs`, the club route
## keeping its old name. Each is replayed from a fresh run that holds that weapon, tick for tick as the windowed game
## plays it (`gd.sh play --flow=...` with `start_level`, `weapon` and `play_file`), and must end the stage the
## documented way (exit totem, warp back, the Brute beaten and the den's exit lit) without losing a life and without
## an engine error. The Bone Gorge cells play on into the den with the same weapon, as a run does.
##
## Route-building aids (no tests of their own; the proofs are skipped while one runs):
##   ARMS_PROBE=<route file> [ARMS_WEAPON=club|hammer|axe|boomerang] [ARMS_DIFF=expert] [ARMS_EVERY=n]
##       [ARMS_LEVEL=<id>]   replay one route line by line and print the hero's cell, state and the events of
##       every line, e.g. ARMS_PROBE=w2_l1.axe.inputs ARMS_WEAPON=axe bash .tools/gd.sh test weapons_arms_w12
##   ARMS_SURVEY=<file prefix> [ARMS_WEAPONS=club,axe,...]   replay every route file of the folder whose name starts
##       with the prefix with each weapon on each difficulty and print one outcome line per run

const ROUTE_DIR: String = "res://tools/autoplay/routes/"
## Logical view of the 1280 x 720 game window (integer scale 2): enemies wake by the view.
const VIEW: Vector2i = Vector2i(Tuning.VIEW_W, Tuning.VIEW_H)
const BEGINNER: String = "beginner"
const EXPERT: String = "expert"
const CLUB: int = Defs.Weapon.CLUB
const HAMMER: int = Defs.Weapon.HAMMER
const AXE: int = Defs.Weapon.AXE
const BOOMERANG: int = Defs.Weapon.BOOMERANG
const WEAPON_NAMES: Array[String] = ["club", "hammer", "axe", "boomerang"]

## The weapons a player can hold when entering each stage (both difficulties): a new run and a code start with the
## club; the axe of Canopy Village is carried from there on, the hammer of Echo Caverns after that stage.
const ENTRY_WEAPONS: Dictionary = {
	"w1_l2": [CLUB],
	"bonus_a": [CLUB, AXE],
	"w2_l1": [CLUB, AXE],
	"bonus_b": [CLUB, AXE, HAMMER],
	"w2_l2": [CLUB, AXE, HAMMER],
	"w2_l2b": [CLUB, AXE, HAMMER],
}

## Bonus stages are entered through the warp of their source level (the warp back ends that level).
const BONUS_SOURCE: Dictionary = {"bonus_a": "w1_l2", "bonus_b": "w2_l1"}

## Where the weapons lie: a stage after one of these (in campaign order) can be entered with that weapon.
const PICKUPS: Dictionary = {"w1_l2": "axe", "w2_l1": "hammer"}

## One entry per (stage, difficulty, weapon) cell. Keys:
##   file        the route file           level, mode, weapon   the cell
##   leaves      how the stage must end: "exit" or "warp" (then the tally follows), "next" (the exit of Bone Gorge,
##               the den follows without a tally)
##   then        Bone Gorge: the den route of the same weapon, played on after the exit (as a run goes on)
##   boss        true: the Brute is beaten, its fire-starter lights the locked exit totem
##   weapon_end  the weapon he holds at the end (a pick-up on the way)
##   side        true: no matrix cell, the path a campaign run takes (the warp of Canopy Village)
const CELLS: Array = [
	# --- Canopy Village: the club on entry, the axe inside ---------------------------------------------------------
	{"file": "w1_l2.inputs", "level": "w1_l2", "mode": BEGINNER, "weapon": CLUB, "leaves": "exit", "weapon_end": AXE},
	{"file": "w1_l2.expert.inputs", "level": "w1_l2", "mode": EXPERT, "weapon": CLUB, "leaves": "exit",
		"weapon_end": AXE},
	{"file": "w1_l2.warp.inputs", "level": "w1_l2", "mode": BEGINNER, "weapon": CLUB, "leaves": "warp",
		"weapon_end": AXE, "side": true},
	{"file": "w1_l2.warp.inputs", "level": "w1_l2", "mode": EXPERT, "weapon": CLUB, "leaves": "warp",
		"weapon_end": AXE, "side": true},
	# --- Feast Land A ----------------------------------------------------------------------------------------------
	{"file": "bonus_a.inputs", "level": "bonus_a", "mode": BEGINNER, "weapon": CLUB, "leaves": "warp"},
	{"file": "bonus_a.axe.inputs", "level": "bonus_a", "mode": BEGINNER, "weapon": AXE, "leaves": "warp"},
	{"file": "bonus_a.inputs", "level": "bonus_a", "mode": EXPERT, "weapon": CLUB, "leaves": "warp"},
	{"file": "bonus_a.axe.inputs", "level": "bonus_a", "mode": EXPERT, "weapon": AXE, "leaves": "warp"},
	# --- Echo Caverns: the hammer inside ---------------------------------------------------------------------------
	{"file": "w2_l1.inputs", "level": "w2_l1", "mode": BEGINNER, "weapon": CLUB, "leaves": "exit", "weapon_end": HAMMER},
	{"file": "w2_l1.axe.inputs", "level": "w2_l1", "mode": BEGINNER, "weapon": AXE, "leaves": "exit",
		"weapon_end": HAMMER},
	{"file": "w2_l1.expert.inputs", "level": "w2_l1", "mode": EXPERT, "weapon": CLUB, "leaves": "exit",
		"weapon_end": HAMMER},
	{"file": "w2_l1.expert.axe.inputs", "level": "w2_l1", "mode": EXPERT, "weapon": AXE, "leaves": "exit",
		"weapon_end": HAMMER},
	# --- Feast Land B ----------------------------------------------------------------------------------------------
	{"file": "bonus_b.inputs", "level": "bonus_b", "mode": BEGINNER, "weapon": CLUB, "leaves": "warp"},
	{"file": "bonus_b.axe.inputs", "level": "bonus_b", "mode": BEGINNER, "weapon": AXE, "leaves": "warp"},
	{"file": "bonus_b.hammer.inputs", "level": "bonus_b", "mode": BEGINNER, "weapon": HAMMER, "leaves": "warp"},
	{"file": "bonus_b.inputs", "level": "bonus_b", "mode": EXPERT, "weapon": CLUB, "leaves": "warp"},
	{"file": "bonus_b.axe.inputs", "level": "bonus_b", "mode": EXPERT, "weapon": AXE, "leaves": "warp"},
	{"file": "bonus_b.hammer.inputs", "level": "bonus_b", "mode": EXPERT, "weapon": HAMMER, "leaves": "warp"},
	# --- Bone Gorge, on into the den -------------------------------------------------------------------------------
	{"file": "w2_l2.inputs", "level": "w2_l2", "mode": BEGINNER, "weapon": CLUB, "leaves": "next",
		"then": "w2_l2b.inputs"},
	{"file": "w2_l2.axe.inputs", "level": "w2_l2", "mode": BEGINNER, "weapon": AXE, "leaves": "next",
		"then": "w2_l2b.axe.inputs"},
	{"file": "w2_l2.hammer.inputs", "level": "w2_l2", "mode": BEGINNER, "weapon": HAMMER, "leaves": "next",
		"then": "w2_l2b.hammer.inputs"},
	{"file": "w2_l2.expert.inputs", "level": "w2_l2", "mode": EXPERT, "weapon": CLUB, "leaves": "next",
		"then": "w2_l2b.expert.inputs"},
	{"file": "w2_l2.expert.axe.inputs", "level": "w2_l2", "mode": EXPERT, "weapon": AXE, "leaves": "next",
		"then": "w2_l2b.expert.axe.inputs"},
	{"file": "w2_l2.expert.hammer.inputs", "level": "w2_l2", "mode": EXPERT, "weapon": HAMMER, "leaves": "next",
		"then": "w2_l2b.expert.hammer.inputs"},
	# --- The Brute's Den (also started from its code, with the club) -----------------------------------------------
	{"file": "w2_l2b.inputs", "level": "w2_l2b", "mode": BEGINNER, "weapon": CLUB, "leaves": "exit", "boss": true},
	{"file": "w2_l2b.axe.inputs", "level": "w2_l2b", "mode": BEGINNER, "weapon": AXE, "leaves": "exit", "boss": true},
	{"file": "w2_l2b.hammer.inputs", "level": "w2_l2b", "mode": BEGINNER, "weapon": HAMMER, "leaves": "exit",
		"boss": true},
	{"file": "w2_l2b.expert.inputs", "level": "w2_l2b", "mode": EXPERT, "weapon": CLUB, "leaves": "exit", "boss": true},
	{"file": "w2_l2b.expert.axe.inputs", "level": "w2_l2b", "mode": EXPERT, "weapon": AXE, "leaves": "exit",
		"boss": true},
	{"file": "w2_l2b.expert.hammer.inputs", "level": "w2_l2b", "mode": EXPERT, "weapon": HAMMER, "leaves": "exit",
		"boss": true},
]

## The natural run through these stages: the warp of Canopy Village into Feast Land A, Echo Caverns, Bone Gorge and
## the den, each played with the route of the weapon the run carries by then (no hand-over).
const RUN: Array = [["w1_l2", "w1_l2.warp.inputs"], ["bonus_a", ""], ["w2_l1", ""], ["w2_l2", ""]]


## Counts the warnings and errors the engine logs while a route plays.
class ProblemCounter:
	extends Logger

	var count: int = 0
	var first: String = ""

	func _log_error(
			function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool,
			_error_type: int, _script_backtraces: Array[ScriptBacktrace]
	) -> void:
		count += 1
		if first == "":
			first = "%s (%s:%d %s) %s" % [code, file, line, function, rationale]

	func _log_message(_message: String, _error: bool) -> void:
		pass


var _counts: Dictionary = {}
var _boss_hits: int = 0
var _exit_kinds: Array[StringName] = []
var _connections: Array[Array] = []
var _problems: ProblemCounter = null
var _counting: bool = false


func after_each() -> void:
	_stop_counting_problems()
	for connection: Array in _connections:
		var signal_ref: Signal = connection[0]
		if signal_ref.is_connected(connection[1]):
			signal_ref.disconnect(connection[1])
	_connections.clear()
	_reset_watch()
	GameInput.clear_scripted()
	Sim.manual = false
	Sim.stop()
	if get_tree().current_scene != null:
		get_tree().current_scene.free()
		get_tree().current_scene = null
	Flow.current_screen = Flow.SCREEN_BOOT
	Flow.args = {}


# =================================================================================================================
# The matrix
# =================================================================================================================

## Every weapon a player can bring into each of these stages has exactly one route per difficulty the stage exists
## in, and the list of weapons on entry follows from where the weapons lie.
func test_every_weapon_on_entry_has_a_route() -> void:
	# Where the weapons lie: Canopy Village holds the axe, Echo Caverns the hammer, the other stages none.
	for level_id: String in ENTRY_WEAPONS:
		var text: String = FileAccess.get_file_as_string(Levels.get_level_path(StringName(level_id)))
		for weapon: String in ["axe", "hammer", "boomerang"]:
			var lies_here: bool = RegEx.create_from_string("items/weapon\\b[^\\n]*kind=%s" % weapon).search(text) != null
			assert_eq(lies_here, PICKUPS.get(level_id, "") == weapon, "%s: the %s lies here" % [level_id, weapon])
	var seen: Dictionary = {}
	for cell: Dictionary in CELLS:
		assert_true(FileAccess.file_exists(ROUTE_DIR + str(cell["file"])), "%s exists" % cell["file"])
		if bool(cell.get("side", false)):
			continue
		var key: String = "%s/%s/%s" % [cell["level"], cell["mode"], WEAPON_NAMES[int(cell["weapon"])]]
		assert_false(seen.has(key), "one route for %s" % key)
		seen[key] = cell["file"]
		assert_true((ENTRY_WEAPONS[cell["level"]] as Array).has(int(cell["weapon"])), "%s: a weapon he can bring" % key)
	for level_id: String in ENTRY_WEAPONS:
		for mode: String in [BEGINNER, EXPERT]:
			if not Levels.is_available(StringName(level_id), _difficulty(mode)):
				continue
			for weapon: int in ENTRY_WEAPONS[level_id]:
				var key: String = "%s/%s/%s" % [level_id, mode, WEAPON_NAMES[weapon]]
				assert_true(seen.has(key), "%s has a route" % key)
	# Every route file of these stages is a cell (or the side path of a cell).
	var described: Dictionary = {}
	for cell: Dictionary in CELLS:
		described[str(cell["file"])] = true
		if cell.has("then"):
			described[str(cell["then"])] = true
	for file: String in DirAccess.get_files_at(ROUTE_DIR):
		var level_id: String = file.get_slice(".", 0)
		if file.get_extension() != "inputs" or not ENTRY_WEAPONS.has(level_id) or file.contains(".secret."):
			continue
		assert_true(described.has(file), "%s is a cell of the matrix" % file)


# =================================================================================================================
# The proofs, stage by stage
# =================================================================================================================

func test_canopy_village() -> void:
	await _play_cells("w1_l2")


func test_feast_land_a() -> void:
	await _play_cells("bonus_a")


func test_echo_caverns() -> void:
	await _play_cells("w2_l1")


func test_feast_land_b() -> void:
	await _play_cells("bonus_b")


## Bone Gorge with each weapon, played on into the den with the same weapon as a run goes on.
func test_bone_gorge_into_the_den() -> void:
	await _play_cells("w2_l2")


## The den alone, as its level code starts it (any weapon here, the club for a code).
func test_the_brute_with_every_weapon() -> void:
	await _play_cells("w2_l2b")


## A run that takes every pick-up: Canopy Village through its warp (the axe), Feast Land A and Echo Caverns with the
## axe (the hammer), Bone Gorge and the den with the hammer - every stage played with the route of the weapon the run
## really carries, with everything else it carries (score, lives, letters), and no life lost.
func test_a_run_carries_its_weapon_without_a_hand_over() -> void:
	if _dev_mode():
		assert_true(true, "skipped while a route-building aid runs")
		return
	for mode: String in [BEGINNER, EXPERT]:
		Save.reset()
		Game.new_game(_difficulty(mode))
		var total: int = 0
		for step: Array in RUN:
			var level_id: StringName = StringName(str(step[0]))
			if Game.level_id != level_id or Flow.current_screen != Flow.SCREEN_LEVEL:
				await _enter(level_id)
			assert_eq(Game.level_id, level_id, "%s: the run is in %s" % [mode, level_id])
			if Game.level_id != level_id:
				break
			var cell: Dictionary = _cell_for(String(level_id), mode, Game.weapon) if str(step[1]) == "" \
					else _cell_by_file(str(step[1]), mode)
			assert_false(cell.is_empty(), "%s: %s has a route for the carried %s" % [
				mode, level_id, WEAPON_NAMES[Game.weapon]])
			if cell.is_empty():
				break
			var lives: int = Game.lives
			var label: String = "run %s: %s" % [mode, cell["file"]]
			total += await _play_stage(cell, label, false)
			if cell.has("then") and Flow.current_screen == Flow.SCREEN_LEVEL:
				var den: Dictionary = _cell_by_file(str(cell["then"]), mode)
				total += await _play_stage(den, "run %s: %s" % [mode, den["file"]], false)
			assert_true(Game.lives >= lives, "%s: no life lost (%d -> %d)" % [label, lives, Game.lives])
			if Flow.current_screen == Flow.SCREEN_TALLY:
				Flow.finish_tally()
				await _settle()
		print("    run %s: %d ticks, score %d, lives %d, weapon %s, screen %s" % [mode, total, Game.score, Game.lives,
			WEAPON_NAMES[Game.weapon], Flow.current_screen])
		assert_eq(Game.weapon, HAMMER, "%s: the run leaves the den with the hammer" % mode)
		assert_eq(Flow.current_screen, Flow.SCREEN_WORLD_MAP, "%s: on to the map after the den's tally" % mode)
		after_each()


# =================================================================================================================
# Route-building aids
# =================================================================================================================

## ARMS_PROBE=<route file>: replay it line by line and print what happened.
func test_probe() -> void:
	var file: String = OS.get_environment("ARMS_PROBE")
	assert_true(file.is_empty() or FileAccess.file_exists(ROUTE_DIR + file) or FileAccess.file_exists(file),
			"a route file")
	if file.is_empty():
		return
	var path: String = ROUTE_DIR + file if FileAccess.file_exists(ROUTE_DIR + file) else file
	var mode: String = EXPERT if OS.get_environment("ARMS_DIFF") == EXPERT else BEGINNER
	var weapon: int = _weapon_from_env(OS.get_environment("ARMS_WEAPON"))
	var level_id: StringName = StringName(OS.get_environment("ARMS_LEVEL"))
	if level_id == &"":
		level_id = StringName(path.get_file().get_slice(".", 0))
	var every: int = maxi(OS.get_environment("ARMS_EVERY").to_int(), 0)
	await _start(level_id, mode, weapon)
	var log_lines: PackedStringArray = PackedStringArray()
	var on_event: Callable = func(signal_name: StringName) -> void: log_lines.append(String(signal_name))
	for info: Dictionary in Events.get_signal_list():
		var name: StringName = StringName(str(info["name"]))
		if name in [&"popup_requested", &"player_landed", &"player_jumped", &"shake_requested", &"wind_changed",
				&"player_struck", &"boss_energy_changed"]:
			continue
		var callable: Callable = on_event.bind(name)
		var arguments: int = (info["args"] as Array).size()
		_connect(Signal(Events, name), callable.unbind(arguments) if arguments > 0 else callable)
	var played: int = 0
	var line_no: int = 0
	var comment: String = ""
	var level: LevelBase = Game.level
	for line: String in FileAccess.get_file_as_string(path).split("\n"):
		line_no += 1
		var stripped: String = line.strip_edges()
		if stripped.begins_with("#"):
			comment = stripped.substr(0, 60)
			continue
		var flags: PackedInt32Array = Autoplay.parse_inputs(stripped)
		for i: int in flags.size():
			if not Sim.running or Game.level != level:
				break
			played += _run(PackedInt32Array([flags[i]]))
			if every > 0 and played % every == 0:
				print("    t%5d %s" % [played, _hero_text()])
		if flags.size() > 0:
			print("L%3d t%5d %s | %s %s" % [line_no, played, _hero_text(), " ".join(log_lines), comment])
			log_lines.clear()
			comment = ""
			_print_shown_items()
		if not Sim.running or Game.level != level:
			break
	print("PROBE END %s t%d score %d lives %d hearts %d weapon %s exits %s deaths %d hurt %d boss hits %d" % [
		file, played, Game.score, Game.lives, Game.hearts, WEAPON_NAMES[Game.weapon], str(_exit_kinds),
		_count(&"player_died"), _count(&"player_hurt"), _boss_hits])


## ARMS_SHOW=<item id>,...: list where those items lie (probe aid), e.g. ARMS_SHOW=items/skull,items/fire_starter.
func _print_shown_items() -> void:
	var shown: PackedStringArray = OS.get_environment("ARMS_SHOW").split(",", false)
	if shown.is_empty() or Game.level == null:
		return
	var parts: PackedStringArray = PackedStringArray()
	for entity: SimEntity in Game.level.get_kind(Defs.Kind.COLLECTIBLE):
		var item: CollectibleBase = entity as CollectibleBase
		if item != null and not item.collected and shown.has(String(item.item_id)):
			parts.append("%s@%d,%d%s" % [String(item.item_id).get_file(), item.sim_pos.x, item.sim_pos.y,
				"" if item.resting else "~"])
	if not parts.is_empty():
		print("      items: " + " ".join(parts))


## ARMS_SURVEY=<prefix>: every route file starting with the prefix, with each weapon, on each difficulty.
func test_survey() -> void:
	var prefix: String = OS.get_environment("ARMS_SURVEY")
	assert_true(true)
	if prefix.is_empty():
		return
	var weapons: Array[int] = []
	for name: String in OS.get_environment("ARMS_WEAPONS").split(",", false):
		weapons.append(_weapon_from_env(name))
	if weapons.is_empty():
		weapons = [CLUB, HAMMER, AXE]
	var files: PackedStringArray = DirAccess.get_files_at(ROUTE_DIR)
	for file: String in files:
		if not file.begins_with(prefix) or file.get_extension() != "inputs":
			continue
		var level_id: StringName = StringName(file.get_slice(".", 0))
		var modes: Array[String] = [BEGINNER, EXPERT]
		if file.contains(".expert"):
			modes = [EXPERT]
		if OS.get_environment("ARMS_DIFF") != "":
			modes = [OS.get_environment("ARMS_DIFF")]
		for mode: String in modes:
			if not Levels.is_available(level_id, _difficulty(mode)):
				continue
			for weapon: int in weapons:
				after_each()
				await _start(level_id, mode, weapon)
				var flags: PackedInt32Array = Autoplay.parse_inputs(FileAccess.get_file_as_string(ROUTE_DIR + file))
				var lives: int = Game.lives
				var played: int = _run(flags)
				var hero: PlayerBase = Game.level.player if Game.level != null and Game.level.level_id == level_id \
						else null
				print("SURVEY %-28s %-8s %-9s t%5d/%5d exits %-10s deaths %d hurt %d lives %d->%d score %7d boss %d %s" % [
					file, mode, WEAPON_NAMES[weapon], played, flags.size(), str(_exit_kinds), _count(&"player_died"),
					_count(&"player_hurt"), lives, Game.lives, Game.score, _count(&"boss_defeated"),
					"x%d y%d" % [hero.sim_pos.x, hero.sim_pos.y] if hero != null else ""])
	after_each()


# =================================================================================================================
# Playing routes
# =================================================================================================================

## Every cell of `level_id`, each from a fresh run holding the cell's weapon.
func _play_cells(level_id: String) -> void:
	if _dev_mode():
		assert_true(true, "skipped while a route-building aid runs")
		return
	var played: int = 0
	for cell: Dictionary in CELLS:
		if str(cell["level"]) != level_id:
			continue
		after_each()
		await _start(StringName(level_id), str(cell["mode"]), int(cell["weapon"]))
		var label: String = "%s (%s, %s)" % [cell["file"], cell["mode"], WEAPON_NAMES[int(cell["weapon"])]]
		var lives: int = Game.lives
		var ticks: int = await _play_stage(cell, label, true)
		if cell.has("then") and Flow.current_screen == Flow.SCREEN_LEVEL:
			var den: Dictionary = _cell_by_file(str(cell["then"]), str(cell["mode"]))
			assert_eq(int(den.get("weapon", -1)), int(cell["weapon"]), "%s: the den route of the same weapon" % label)
			ticks += await _play_stage(den, "  then %s" % den["file"], true)
		assert_true(Game.lives >= lives, "%s: no life lost (%d -> %d)" % [label, lives, Game.lives])
		played += 1
	after_each()
	assert_true(played > 0, "%s has cells" % level_id)


## Play the route of `cell` in the running level with the weapon the hero holds (it must be the cell's) and check
## how the stage ends; returns the ticks played. `strict`: also no hit taken by surprise is checked by the caller's
## numbers only - every run must be free of deaths and engine warnings.
func _play_stage(cell: Dictionary, label: String, strict: bool) -> int:
	assert_eq(Game.level_id, StringName(str(cell["level"])), "%s starts in %s" % [label, cell["level"]])
	assert_eq(Game.weapon, int(cell["weapon"]), "%s: he holds the %s" % [label, WEAPON_NAMES[int(cell["weapon"])]])
	_reset_watch()
	var score: int = Game.score
	_start_counting_problems()
	var flags: PackedInt32Array = Autoplay.parse_inputs(FileAccess.get_file_as_string(ROUTE_DIR + str(cell["file"])))
	assert_true(flags.size() > 100, "%s is a real input script" % label)
	var played: int = _run(flags)
	_stop_counting_problems()
	print("    %s: %d ticks, hits taken %d, deaths %d, lives %d, score %d (+%d), kills %d, boss hits %d, weapon %s" % [
		label, played, _count(&"player_hurt"), _count(&"player_died"), Game.lives, Game.score, Game.score - score,
		_count(&"enemy_killed"), _boss_hits, WEAPON_NAMES[Game.weapon]])
	assert_eq(_count(&"player_died"), 0, "%s: no death" % label)
	assert_eq(_problems.count, 0, "%s: no engine warning or error (first: %s)" % [label, _problems.first])
	if cell.has("weapon_end"):
		assert_eq(Game.weapon, int(cell["weapon_end"]), "%s: the weapon at the end" % label)
	if bool(cell.get("boss", false)):
		assert_eq(_count(&"boss_started"), 1, "%s: the Brute fought" % label)
		assert_eq(_count(&"boss_defeated"), 1, "%s: the Brute was beaten (%d head hits)" % [label, _boss_hits])
		assert_eq(_count(&"exit_unlocked"), 1, "%s: the fire-starter lit the exit totem" % label)
	var leaves: String = str(cell["leaves"])
	var kind: StringName = &"exit" if leaves == "next" else StringName(leaves)
	assert_eq(_exit_kinds, [kind] as Array[StringName], "%s leaves through its %s after %d ticks" % [
		label, kind, played])
	await _settle()
	if leaves == "next":
		assert_eq(Flow.current_screen, Flow.SCREEN_LEVEL, "%s: the den follows without a tally" % label)
		assert_eq(Game.level_id, &"w2_l2b", "%s leads into the den" % label)
		assert_false(Game.has_glider, "%s: the glider stays behind" % label)
		if Game.level_id == &"w2_l2b":
			_set_view()
	else:
		assert_eq(Flow.current_screen, Flow.SCREEN_TALLY, "%s: the tally follows" % label)
	if strict and leaves == "warp":
		assert_eq(Game.level_id, StringName(str(BONUS_SOURCE[str(cell["level"])])),
				"%s: the warp back ends %s" % [label, BONUS_SOURCE[str(cell["level"])]])
	return played


func _cell_by_file(file: String, mode: String) -> Dictionary:
	for cell: Dictionary in CELLS:
		if str(cell["file"]) == file and str(cell["mode"]) == mode:
			return cell
	return {}


func _cell_for(level_id: String, mode: String, weapon: int) -> Dictionary:
	for cell: Dictionary in CELLS:
		if str(cell["level"]) == level_id and str(cell["mode"]) == mode and int(cell["weapon"]) == weapon \
				and not bool(cell.get("side", false)):
			return cell
	return {}

## A fresh run on `mode` holding `weapon`, entered into `level_id` as the world map (or a warp) enters it.
func _start(level_id: StringName, mode: String, weapon: int) -> void:
	Game.new_game(_difficulty(mode))
	if BONUS_SOURCE.has(String(level_id)):
		Game.warp_return_level = StringName(str(BONUS_SOURCE[String(level_id)]))
	Game.set_weapon(weapon)
	await _enter(level_id)


## Enter `level_id` through Flow like the world map does, with the clock under the test's control.
func _enter(level_id: StringName) -> void:
	_watch_events()
	Sim.manual = true
	await _idle()
	Flow.start_level(level_id, Defs.Transition.NONE)
	await _settle()
	assert_eq(Flow.current_screen, Flow.SCREEN_LEVEL, "%s started" % level_id)
	assert_true(Game.level != null and Game.level.level_id == level_id, "%s is the running level" % level_id)
	_set_view()


## Headless runs have no window: give the level the view of the 1280 x 720 game window before its first tick.
func _set_view() -> void:
	var level: Level = Game.level as Level
	assert_not_null(level, "the world module's level scene")
	if level != null:
		level.set_view_size(VIEW * Tuning.ART_SCALE)


## Play input flags one tick after the other until they end or the level is left; returns the ticks played.
func _run(flags: PackedInt32Array) -> int:
	var index: Array[int] = [0]
	GameInput.set_scripted(func(_tick: int) -> int:
		var value: int = flags[index[0]] if index[0] < flags.size() else 0
		index[0] += 1
		return value
	)
	var played: int = 0
	var level: LevelBase = Game.level
	while played < flags.size() and Sim.running and Game.level == level:
		Sim.step(1)
		played += 1
	GameInput.clear_scripted()
	return played


func _watch_events() -> void:
	if not _connections.is_empty():
		return
	for info: Dictionary in Events.get_signal_list():
		var signal_name: StringName = StringName(str(info["name"]))
		var callable: Callable = _on_event.bind(signal_name)
		var arguments: int = (info["args"] as Array).size()
		_connect(Signal(Events, signal_name), callable.unbind(arguments) if arguments > 0 else callable)
	_connect(Events.enemy_hit, _on_enemy_hit)
	_connect(Events.exit_reached, _on_exit)


func _connect(signal_ref: Signal, callable: Callable) -> void:
	signal_ref.connect(callable)
	_connections.append([signal_ref, callable])


func _reset_watch() -> void:
	_counts.clear()
	_boss_hits = 0
	_exit_kinds.clear()


func _start_counting_problems() -> void:
	_stop_counting_problems()
	_problems = ProblemCounter.new()
	OS.add_logger(_problems)
	_counting = true


func _stop_counting_problems() -> void:
	if _counting:
		OS.remove_logger(_problems)
		_counting = false


## Wait until no transition runs (a scene change left over from the previous test would swallow start_level).
func _idle() -> void:
	await get_tree().process_frame
	while Flow.busy:
		await get_tree().process_frame


func _settle() -> void:
	for i: int in 3:
		await get_tree().process_frame
	while Flow.busy:
		await get_tree().process_frame


func _dev_mode() -> bool:
	return not OS.get_environment("ARMS_PROBE").is_empty() or not OS.get_environment("ARMS_SURVEY").is_empty()


func _difficulty(mode: String) -> int:
	return Defs.Difficulty.EXPERT if mode == EXPERT else Defs.Difficulty.BEGINNER


func _weapon_from_env(text: String) -> int:
	if text.is_valid_int():
		return clampi(text.to_int(), CLUB, BOOMERANG)
	var index: int = WEAPON_NAMES.find(text.strip_edges().to_lower())
	return index if index >= 0 else CLUB


func _count(signal_name: StringName) -> int:
	return int(_counts.get(signal_name, 0))


func _on_event(signal_name: StringName) -> void:
	_counts[signal_name] = _count(signal_name) + 1


func _on_enemy_hit(enemy: EnemyBase, _power: int) -> void:
	if enemy is BossBase:
		_boss_hits += 1


func _on_exit(exit_kind: StringName) -> void:
	_exit_kinds.append(exit_kind)


func _hero_text() -> String:
	var level: LevelBase = Game.level
	if level == null or level.player == null:
		return "(no hero)"
	var hero: PlayerBase = level.player
	var text: String = "x%5d y%5d c%3d r%3d st%d v(%d,%d) h%d w%d%s" % [hero.sim_pos.x, hero.sim_pos.y,
		hero.sim_pos.x >> 4, (hero.sim_pos.y - 1) >> 4, hero.state, hero.xvel, hero.yvel, Game.hearts, Game.weapon,
		" DEAD" if hero.dead else ""]
	for entity: SimEntity in level.get_kind(Defs.Kind.BOSS):
		var boss: BossBase = entity as BossBase
		if boss != null and boss.fighting:
			text += " [boss x%d y%d hp%d st%d]" % [boss.sim_pos.x, boss.sim_pos.y, boss.hp,
				boss.call("get_state") if boss.has_method("get_state") else -1]
	return text
