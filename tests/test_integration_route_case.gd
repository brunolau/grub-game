class_name RouteTestCase
extends TestCase
## Shared machinery of the 2.0 route proofs (owner: integration; docs/expansion/PLAN.md P0.9 and 8 V2 / V3). No
## tests of its own: tests/test_book2_routes.gd, tests/test_coop_routes.gd and tests/test_integration_harness.gd
## build on it.
##
## New routes describe themselves with a `# route:` header (docs/LEVEL_DESIGN.md 15.9, Autoplay.parse_route_header)
## instead of a ROUTES entry. A header route is replayed through Flow by the bench runner
## (scripts/core/dev/sim_bench_runner.gd, replay(): the very code that proves single-player identity,
## tools/sp_identity.sh): a fresh run of its difficulty (a party of its `players`, the book of its level), the level
## entered without a transition, the 1280 x 720 view, one input stream per player, its `belt` on every hero. Then the
## header is checked: how the stage ends (`ends`), what follows (`after`), every `expect` key, no engine warning or
## error. The belt-invariance proof (PLAN 8 V2.b) and the determinism checks of co-op routes (V3.b) replay a route
## several times and compare the per-tick digests.

const ROUTE_DIR: String = "res://tools/autoplay/routes/"
const BENCH_RUNNER: String = "res://scripts/core/dev/sim_bench_runner.gd"
const BEGINNER: String = "beginner"
const EXPERT: String = "expert"
const TABLET_ID: StringName = &"objects/x2_tablet"


## Counts engine warnings and errors while a route plays (any of them fails the route, PLAN.md 8 V2.a).
class ProblemCounter:
	extends Logger

	var count: int = 0
	var first: String = ""

	func _log_error(
			function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool,
			_error_type: int, _script_backtraces: Array[ScriptBacktrace]
	) -> void:
		if count == 0:
			first = "%s (%s:%d in %s)" % [rationale if not rationale.is_empty() else code, file, line, function]
		count += 1

	func _log_message(_message: String, _error: bool) -> void:
		pass


var _runner: Node = null
var _counts: Dictionary = {}
var _letters: Dictionary = {}
var _paintings: Dictionary = {}
var _jackpots: int = 0
var _words: int = 0
var _boss_hits: int = 0
var _boss_up: int = -1
var _boss_down: int = -1
var _glider_carried: bool = false
var _glider_flown: bool = false
var _exit_kinds: Array[StringName] = []
var _max_wind: int = 0
var _start_view_y: int = -1
var _deepest_view_y: int = 0
var _embers_seen: Dictionary = {}
var _embers_close: Dictionary = {}
## x2 tablets of the level being played: [gate name, far cell] (docs/LEVEL_DESIGN.md 15.7.4), and the ones whose far
## cell a hero reached.
var _tablets: Array[Array] = []
var _gates_reached: Dictionary = {}
var _connections: Array[Array] = []
var _problems: ProblemCounter = null
var _counting: bool = false


func after_each() -> void:
	clean_up_route()


# =================================================================================================================
# Tables
# =================================================================================================================

## Every header route of `dir` whose spec passes `accept` (Callable(file: String, spec: Dictionary) -> bool), by
## file name (sim_bench_runner.header_routes: the parsed header, its "errors", "dir", "chained").
func header_table(dir: String, accept: Callable) -> Dictionary:
	var table: Dictionary = {}
	var found: Dictionary = (load(BENCH_RUNNER) as GDScript).call("header_routes", dir)
	for file: String in found:
		if accept.call(file, found[file]):
			table[file] = found[file]
	return table


## What is wrong with the headers of `table` (empty = nothing): unreadable keys, an unknown level, a `then` or a
## `prefix` route that does not exist, a party route without party starts, a weapon suffix on a club route.
func header_problems(table: Dictionary) -> PackedStringArray:
	var problems: PackedStringArray = PackedStringArray()
	for file: String in table:
		var spec: Dictionary = table[file]
		for error: String in spec.get("errors", PackedStringArray()):
			problems.append("%s: %s" % [file, error])
		var level_id: StringName = StringName(str(spec.get("level", "")))
		if not Levels.has_level(level_id):
			problems.append("%s: level %s does not exist" % [file, level_id])
		var dir: String = str(spec.get("dir", ROUTE_DIR))
		if spec.has("then") and not table.has(str(spec["then"])):
			problems.append("%s: the route that follows (%s) is not a header route of the table" % [file, spec["then"]])
		if spec.has("prefix") and str(spec["prefix"][0]) != "@route" \
				and not FileAccess.file_exists(dir + str(spec["prefix"][0])):
			problems.append("%s: the prefix route %s does not exist" % [file, spec["prefix"][0]])
		if spec.has("source") and not Levels.has_level(StringName(str(spec["source"]))):
			problems.append("%s: the source level %s does not exist" % [file, spec["source"]])
		for weapon: int in Defs.Weapon.values():
			if file.ends_with(".%s.inputs" % Defs.weapon_name(weapon)):
				problems.append("%s: a 2.0 route carries no weapon suffix (club routes, LEVEL_DESIGN.md 15.9)" % file)
	return problems


## The bench runner node (created once per test, freed by clean_up_route()).
func runner() -> Node:
	if _runner == null or not is_instance_valid(_runner):
		_runner = (load(BENCH_RUNNER) as GDScript).new() as Node
		_runner.name = "RouteRunner"
		add_child(_runner)
	return _runner


# =================================================================================================================
# Playing a header route and checking it
# =================================================================================================================

## Play header route `file` of `table` on `mode` (and the route its `then` names, in the stage that follows) and
## check its header: ends, after, tally_to, expect, no engine warning or error. Returns the replay result of the
## first stage (sim_bench_runner.replay: "lines", "screen", ...).
func play_header_route(file: String, mode: String, table: Dictionary) -> Dictionary:
	var spec: Dictionary = table[file]
	var label: String = "%s (%s)" % [file, mode]
	_watch_events()
	_reset_watch(StringName(str(spec["level"])), mode)
	_start_counting_problems()
	var result: Dictionary = await runner().replay(file, mode, {"routes": table, "on_tick": _on_tick,
			"keep": true, "chain": false})
	_stop_counting_problems()
	var played: int = stage_ticks(result.get("lines", PackedStringArray()))
	assert_true(played > 0, "%s played" % label)
	_print_outcome(label, played)
	check_expectations(label, spec, played, 0)
	_check_after(label, spec, mode)
	var chained: String = str(spec.get("then", ""))
	var last_label: String = label
	var last_spec: Dictionary = spec
	if chained != "" and table.has(chained) and Flow.current_screen == Flow.SCREEN_LEVEL:
		last_label = "%s (%s)" % [chained, mode]
		last_spec = table[chained]
		_reset_watch(StringName(str(last_spec["level"])), mode)
		_start_counting_problems()
		var next: Dictionary = await runner().replay_stage(chained, mode, {"routes": table, "on_tick": _on_tick,
				"keep": true})
		_stop_counting_problems()
		var next_played: int = stage_ticks(next.get("lines", PackedStringArray()))
		assert_true(next_played > 0, "%s played" % last_label)
		_print_outcome(last_label, next_played)
		check_expectations(last_label, last_spec, next_played, played)
		_check_after(last_label, last_spec, mode)
	await _check_tally(last_label, last_spec, mode)
	clean_up_route()
	return result


## The ticks of the stage a replay played: the `ticks` of its first "end" line (-1 when there is none).
func stage_ticks(lines: PackedStringArray) -> int:
	for line: String in lines:
		if line.begins_with("end "):
			return line.get_slice(" ", 3).to_int()
	return -1


## The checks of a header's `expect` (docs/LEVEL_DESIGN.md 15.9; every key of Autoplay.ROUTE_EXPECT_KEYS) for the
## stage just played: `played` ticks, `before` = ticks of the stage that led here (pair_ticks). A party route counts
## every hero (the hero_* events); a solo route the 1.0 events.
func check_expectations(label: String, spec: Dictionary, played: int, before: int) -> void:
	var expect: Dictionary = spec.get("expect", {})
	var party: bool = int(spec.get("players", 1)) > 1
	var died: int = _count(&"hero_died" if party else &"player_died")
	var hurt: int = _count(&"hero_hurt" if party else &"player_hurt")
	assert_eq(died, int(expect.get("deaths", 0)), "%s: deaths" % label)
	if expect.has("hurts"):
		assert_eq(hurt, int(expect["hurts"]), "%s: hits taken" % label)
	if expect.has("max_hurts"):
		assert_true(hurt <= int(expect["max_hurts"]), "%s: hits taken %d" % [label, hurt])
	if expect.has("respawns"):
		assert_eq(_count(&"level_respawned"), int(expect["respawns"]), "%s: respawns" % label)
	assert_true(Game.lives >= int(_counts.get(&"_lives", Game.lives)) + int(expect.get("lives_gained", 0)),
			"%s: lives %d" % [label, Game.lives])
	if expect.has("weapon_end"):
		assert_eq(Game.weapon, int(expect["weapon_end"]), "%s: P1's weapon at the end" % label)
	if expect.has("secrets"):
		assert_eq(_count(&"secret_found"), int(expect["secrets"]), "%s: secrets" % label)
	if expect.has("min_secrets"):
		assert_true(_count(&"secret_found") >= int(expect["min_secrets"]), "%s: secrets %d" % [
			label, _count(&"secret_found")])
	if expect.has("gates"):
		assert_eq(_count(&"gate_used"), int(expect["gates"]), "%s: gate uses" % label)
	if expect.has("checkpoints"):
		assert_eq(_count(&"checkpoint_activated"), int(expect["checkpoints"]), "%s: checkpoints" % label)
	if expect.has("min_checkpoints"):
		assert_true(_count(&"checkpoint_activated") >= int(expect["min_checkpoints"]), "%s: checkpoints %d" % [
			label, _count(&"checkpoint_activated")])
	if expect.has("min_spots"):
		assert_true(_count(&"hidden_spot_opened") >= int(expect["min_spots"]), "%s: spots opened %d" % [
			label, _count(&"hidden_spot_opened")])
	if expect.has("min_kills"):
		assert_true(_count(&"enemy_killed") >= int(expect["min_kills"]), "%s: kills %d" % [
			label, _count(&"enemy_killed")])
	if expect.has("letters"):
		for index: int in expect["letters"]:
			assert_true(_letters.has(index), "%s: letter %d collected (%s)" % [label, index, str(_letters.keys())])
	if expect.has("words"):
		assert_eq(_words, int(expect["words"]), "%s: completed letter words" % label)
	if expect.has("ticks"):
		assert_true(played >= int(expect["ticks"][0]) and played <= int(expect["ticks"][1]), "%s: %d ticks" % [
			label, played])
	if expect.has("pair_ticks") and before > 0:
		assert_true(before + played >= int(expect["pair_ticks"][0]) and before + played <= int(expect["pair_ticks"][1]),
				"%s: both halves take %d ticks" % [label, before + played])
	if expect.has("jackpots"):
		assert_true(_jackpots >= int(expect["jackpots"]), "%s: jackpot chests %d" % [label, _jackpots])
	if expect.has("min_hearts"):
		assert_true(Game.hearts >= int(expect["min_hearts"]), "%s: %d hearts left" % [label, Game.hearts])
	if expect.has("fight_ticks"):
		var fight: int = _boss_down - _boss_up if _boss_up >= 0 and _boss_down >= 0 else -1
		assert_true(fight >= int(expect["fight_ticks"][0]) and fight <= int(expect["fight_ticks"][1]),
				"%s: the boss fight takes %d ticks" % [label, fight])
	if expect.has("min_completion"):
		assert_true(Game.completion_percent() >= int(expect["min_completion"]), "%s: completion %d %%" % [
			label, Game.completion_percent()])
	if expect.has("min_score"):
		assert_true(Game.score >= int(expect["min_score"]), "%s: score %d" % [label, Game.score])
	if expect.has("boss_hits"):
		assert_eq(_count(&"boss_started"), 1, "%s: the boss fight started" % label)
		assert_eq(_count(&"boss_defeated"), 1, "%s: the boss was beaten" % label)
		assert_true(_boss_hits >= int(expect["boss_hits"]), "%s: boss hits %d" % [label, _boss_hits])
	if bool(expect.get("unlocked", false)):
		assert_eq(_count(&"exit_unlocked"), 1, "%s: the fire-starter unlocked the exit" % label)
	if bool(expect.get("glider", false)):
		assert_true(_glider_carried and _glider_flown, "%s: the hang-glider was taken and flown" % label)
	if expect.has("min_wind"):
		assert_true(_max_wind >= int(expect["min_wind"]), "%s: strongest wind %d" % [label, _max_wind])
	if expect.has("view_sank"):
		assert_true(_deepest_view_y - _start_view_y >= int(expect["view_sank"]), "%s: the view sank %d px" % [
			label, _deepest_view_y - _start_view_y])
	if expect.has("embers"):
		assert_true(_embers_seen.size() >= int(expect["embers"][0]), "%s: embers fell: %d" % [
			label, _embers_seen.size()])
		if (expect["embers"] as Array).size() > 1:
			assert_true(_embers_close.size() >= int(expect["embers"][1]), "%s: embers beside a hero: %d" % [
				label, _embers_close.size()])
	if bool(expect.get("no_enemies", false)):
		assert_eq(_count(&"enemy_killed") + hurt, 0, "%s: nothing to fight" % label)
	if expect.has("hero_min_x") or expect.has("hero_y"):
		var hero: PlayerBase = Game.level.player if Game.level != null else null
		assert_not_null(hero, "%s: P1 is there at the end" % label)
		if hero != null:
			assert_true(hero.sim_pos.x >= int(expect.get("hero_min_x", 0)), "%s: P1 got to x %d" % [
				label, hero.sim_pos.x])
			if expect.has("hero_y"):
				assert_eq(hero.sim_pos.y, int(expect["hero_y"]), "%s: P1 stands on the far side" % label)
	if expect.has("painting"):
		assert_true(_paintings.has(int(expect["painting"])), "%s: Cave Painting %d found (%s)" % [label,
			int(expect["painting"]), str(_paintings.keys())])
	if expect.has("wipes"):
		assert_true(_count(&"party_wiped") <= int(expect["wipes"]), "%s: team wipes %d" % [
			label, _count(&"party_wiped")])
	if expect.has("eggs"):
		assert_true(_count(&"hero_down") <= int(expect["eggs"]), "%s: eggs %d" % [label, _count(&"hero_down")])
	if expect.has("hatches"):
		assert_true(_count(&"hero_revived") >= int(expect["hatches"]), "%s: hatches %d" % [
			label, _count(&"hero_revived")])
	if expect.has("x2_gates"):
		assert_true(_gates_reached.size() >= int(expect["x2_gates"]), "%s: x2 gates crossed %d of %d (%s)" % [
			label, _gates_reached.size(), _tablets.size(), str(_gates_reached.keys())])
	if _problems != null:
		assert_eq(_problems.count, 0, "%s: no engine warning or error (first: %s)" % [label, _problems.first])


## Free the stage a replay left running and put Flow and the input back (every test calls it through after_each).
func clean_up_route() -> void:
	_stop_counting_problems()
	for connection: Array in _connections:
		var signal_ref: Signal = connection[0]
		if signal_ref.is_connected(connection[1]):
			signal_ref.disconnect(connection[1])
	_connections.clear()
	GameInput.clear_scripted()
	GameInput.reset_slots()
	LevelBase.doze_enabled = true
	Sim.manual = false
	Sim.stop()
	if get_tree().current_scene != null:
		get_tree().current_scene.free()
		get_tree().current_scene = null
	Flow.current_screen = Flow.SCREEN_BOOT
	Flow.args = {}
	if _runner != null and is_instance_valid(_runner):
		_runner.free()
	_runner = null


# =================================================================================================================
# Belt invariance and determinism
# =================================================================================================================

## PLAN.md 8 V2.b: replay `file` of `table` on `mode` with an empty belt and with each special on every hero's
## belt; returns the differences (empty = the per-tick digests are identical whatever the belt holds).
func belt_invariance_problems(file: String, mode: String, table: Dictionary) -> PackedStringArray:
	var result: Dictionary = await runner().belt_invariance(file, mode, table)
	clean_up_route()
	var problems: PackedStringArray = PackedStringArray()
	for difference: String in result["differences"]:
		problems.append("%s (%s): %s" % [file, mode, difference])
	return problems


## PLAN.md 8 V3.b (co-op routes): the route replayed twice gives identical digests, with and without dozing, and
## with the player slots assigned to other devices (devices never reach the simulation). Returns the differences.
func determinism_problems(file: String, mode: String, table: Dictionary) -> PackedStringArray:
	var problems: PackedStringArray = PackedStringArray()
	var first: Dictionary = await runner().replay(file, mode, {"routes": table})
	var reference: PackedStringArray = first.get("lines", PackedStringArray())
	if reference.is_empty():
		problems.append("%s (%s) did not play" % [file, mode])
		return problems
	var runs: Array[Array] = [["again", {"routes": table}], ["without dozing", {"routes": table, "doze": false}]]
	for run: Array in runs:
		var other: Dictionary = await runner().replay(file, mode, run[1])
		var difference: String = runner().call("first_difference", reference, other.get("lines", PackedStringArray()))
		if difference != "":
			problems.append("%s (%s) %s: %s" % [file, mode, run[0], difference])
	# Other devices: P1 on the right keyboard half, P2 on pad 1, P3 / P4 on pads 2 and 3.
	GameInput.assign_slot(0, InputSlot.keyboard(Defs.InputSlotKind.KEYBOARD_RIGHT))
	GameInput.assign_slot(1, InputSlot.pad(1))
	GameInput.assign_slot(2, InputSlot.pad(2))
	GameInput.assign_slot(3, InputSlot.pad(3))
	var moved: Dictionary = await runner().replay(file, mode, {"routes": table})
	GameInput.reset_slots()
	var device_difference: String = runner().call("first_difference", reference,
			moved.get("lines", PackedStringArray()))
	if device_difference != "":
		problems.append("%s (%s) with other devices: %s" % [file, mode, device_difference])
	clean_up_route()
	return problems


# =================================================================================================================
# Watching a stage
# =================================================================================================================

func _reset_watch(level_id: StringName, mode: String) -> void:
	_counts.clear()
	_counts[&"_lives"] = Game.lives
	_letters.clear()
	_paintings.clear()
	_jackpots = 0
	_words = 0
	_boss_hits = 0
	_boss_up = -1
	_boss_down = -1
	_glider_carried = false
	_glider_flown = false
	_exit_kinds.clear()
	_max_wind = 0
	_start_view_y = -1
	_deepest_view_y = 0
	_embers_seen.clear()
	_embers_close.clear()
	_gates_reached.clear()
	_tablets = _x2_tablets(level_id, BEGINNER if mode != EXPERT else EXPERT)


## The x2 tablets of a level on a difficulty: [gate name (or "secret@c,r"), far cell].
func _x2_tablets(level_id: StringName, mode: String) -> Array[Array]:
	var tablets: Array[Array] = []
	if not Levels.has_level(level_id):
		return tablets
	var data: LevelData = LevelData.load_file(Levels.get_level_path(level_id))
	if data == null:
		return tablets
	var difficulty: int = Defs.Difficulty.EXPERT if mode == EXPERT else Defs.Difficulty.BEGINNER
	for record: Dictionary in data.entity_records():
		if StringName(str(record["id"])) != TABLET_ID:
			continue
		var params: Dictionary = record["params"]
		if not LevelText.applies_to(params, difficulty):
			continue
		var far: PackedStringArray = str(params.get("far", "")).replace(" ", "").split(",")
		if far.size() != 2 or not far[0].is_valid_int() or not far[1].is_valid_int():
			continue
		var gate: String = str(params.get("gate", "secret@%d,%d" % [int(record["col"]), int(record["row"])]))
		tablets.append([gate, Vector2i(far[0].to_int(), far[1].to_int())])
	return tablets


## Per tick of the replay (sim_bench_runner on_tick): the watchers of the expect keys that are not events.
func _on_tick(level: LevelBase, stage_tick: int) -> void:
	_max_wind = maxi(_max_wind, level.wind)
	var view_y: int = level.get_view_rect().position.y
	if _start_view_y < 0:
		_start_view_y = view_y
	_deepest_view_y = maxi(_deepest_view_y, view_y)
	if _boss_up < 0 and _count(&"boss_started") > 0:
		_boss_up = stage_tick
	if _boss_down < 0 and _count(&"boss_defeated") > 0:
		_boss_down = stage_tick
	for hero: PlayerBase in level.contact_order():
		if hero.dead:
			continue
		var cell: Vector2i = Vector2i(hero.sim_pos.x >> 4, (hero.sim_pos.y - 1) >> 4)
		for tablet: Array in _tablets:
			if cell == tablet[1]:
				_gates_reached[tablet[0]] = true
	for entity: SimEntity in level.get_kind(Defs.Kind.ENEMY_PROJECTILE):
		if not entity is EnemyEmber:
			continue
		var id: int = entity.get_instance_id()
		_embers_seen[id] = true
		for hero: PlayerBase in level.contact_order():
			var rel: Vector2i = entity.sim_pos - hero.sim_pos
			if absi(rel.x) < 24 and rel.y > -56 and rel.y < 8:
				_embers_close[id] = true


func _watch_events() -> void:
	if not _connections.is_empty():
		return
	for info: Dictionary in Events.get_signal_list():
		var signal_name: StringName = StringName(str(info["name"]))
		var callable: Callable = _on_event.bind(signal_name)
		var arguments: int = (info["args"] as Array).size()
		_connect(Signal(Events, signal_name), callable.unbind(arguments) if arguments > 0 else callable)
	_connect(Events.item_collected, _on_item)
	_connect(Events.enemy_hit, _on_enemy_hit)
	_connect(Events.glider_state_changed, _on_glider)
	_connect(Events.exit_reached, _on_exit)
	_connect(Events.painting_found, _on_painting)
	_connect(Game.letters_completed, _on_word)


func _connect(signal_ref: Signal, callable: Callable) -> void:
	signal_ref.connect(callable)
	_connections.append([signal_ref, callable])


func _start_counting_problems() -> void:
	_stop_counting_problems()
	_problems = ProblemCounter.new()
	OS.add_logger(_problems)
	_counting = true


## Stop counting; the counts stay readable in _problems.
func _stop_counting_problems() -> void:
	if _counting:
		OS.remove_logger(_problems)
		_counting = false


func _count(signal_name: StringName) -> int:
	return int(_counts.get(signal_name, 0))


func _on_event(signal_name: StringName) -> void:
	_counts[signal_name] = _count(signal_name) + 1


func _on_item(item_id: StringName, index: int, _points: int, _pos: Vector2i) -> void:
	if item_id == &"items/letter":
		_letters[index] = true
	elif item_id == &"items/jackpot":
		_jackpots += 1


func _on_enemy_hit(enemy: EnemyBase, _power: int) -> void:
	if enemy is BossBase:
		_boss_hits += 1


func _on_glider(carrying: bool, gliding: bool) -> void:
	_glider_carried = _glider_carried or carrying
	_glider_flown = _glider_flown or gliding


func _on_exit(exit_kind: StringName) -> void:
	_exit_kinds.append(exit_kind)


func _on_painting(index: int) -> void:
	_paintings[index] = true


func _on_word() -> void:
	_words += 1


# How the stage ended and what followed (`ends`, `after`).
func _check_after(label: String, spec: Dictionary, _mode: String) -> void:
	var leaves: String = str(spec.get("leaves", ""))
	if leaves == "":
		return
	assert_eq(_exit_kinds, [StringName(leaves)] as Array[StringName], "%s leaves through its %s" % [label, leaves])
	var after: String = str(spec.get("after", ""))
	if after == "tally":
		assert_eq(Flow.current_screen, Flow.SCREEN_TALLY, "%s: the tally follows" % label)
	elif after.begins_with("level:"):
		assert_eq(Flow.current_screen, Flow.SCREEN_LEVEL, "%s: a stage follows without a tally" % label)
		assert_eq(Game.level_id, StringName(after.get_slice(":", 1)), "%s leads into %s" % [label, after])


# A tally that leads to the expert wall or The End (`after=expert_wall` / `after=the_end`).
func _check_tally(label: String, spec: Dictionary, mode: String) -> void:
	var targets: Dictionary = spec.get("tally_to", {})
	if not targets.has(mode) or Flow.current_screen != Flow.SCREEN_TALLY:
		return
	Flow.finish_tally()
	for i: int in 3:
		await get_tree().process_frame
	while Flow.busy:
		await get_tree().process_frame
	match str(targets[mode]):
		"expert_wall":
			assert_eq(Flow.current_screen, Flow.SCREEN_EXPERT_WALL, "%s: the expert wall follows" % label)
		"the_end":
			assert_eq(Flow.current_screen, Flow.SCREEN_THE_END, "%s: The End follows" % label)


func _print_outcome(label: String, played: int) -> void:
	print("    %s: %d ticks, score %d, lives %d, hurt %d, deaths %d, eggs %d, wipes %d, paintings %s, x2 gates %d" % [
		label, played, Game.score, Game.lives, _count(&"hero_hurt"), _count(&"hero_died"), _count(&"hero_down"),
		_count(&"party_wiped"), str(_paintings.keys()), _gates_reached.size()])
