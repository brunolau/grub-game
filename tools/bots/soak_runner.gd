extends Node
## The versus soak (docs/expansion/PLAN.md 7 P4.1): seeded headless rounds with bots through the real heroes and the
## real referee, with the rules of every mode checked on every tick. Run it through tools/bots/soak.gd (one process)
## or tools/bots/soak.sh (all shards side by side, summed). Owner: versus (phase 4). Development only.
##
## THE PLAN is a pure function of its numbers: for every launch mode, every (arena file that lists the mode in `modes`)
## x (2, 3, 4 players, up to the arena's `players`) is a CELL, and a cell plays seed k = SEED_BASE + k for k = 0, 1, ..
## as round k % players of a match with that seed - so the spawn rotation of DESIGN.md E.2 is covered and a round is
## named by five values: mode, arena, players, seed, round. A cell where the game seats no CPU (meta `bots`, DESIGN.md
## G50: Tar Pulleys' Last Caveman Standing) is played too - the soak is about the round's rules, the bots are the
## hands - and is marked "stand-in" in the cell table.
##
## A ROUND is played as Flow plays it, without the screens: a [VersusMatch] with a CPU on every seat (levels Rookie /
## Hunter / Chief by (seed + slot) % 3, HeroBot.new as Flow makes them), the game's default rules (preset Feast: crates
## every 486 ticks, specials from crates; `rules=mix` draws preset, variants, Stock, the sudden-death event and 2v2
## from the seed instead), Game.start_run VERSUS, the arena's level from its text, Sim.rng from the match's round seed,
## the intro countdown, the round, and AFTER_GONG_TICKS ticks past the gong. The match is recorded
## (VersusMatch.record_round) by this tool instead of Flow.end_round, which would open the scoreboard.
##
## CHECKED (an ANOMALY line each, with the five values that replay the round alone):
##  - engine_error   any script error or failed engine check logged while the round ran (a Logger, as the test runner);
##  - no_end         the round did not reach the gong within its limit (its clock, cap or fuses + ROUND_LIMIT_TICKS);
##  - phase / clock  the phase went backwards, the round clock skipped or ran on after the gong, a clocked round rang
##                   off its tick, a Last Caveman Standing round outlasted its hard cap (G78), a Hot Rock round ran
##                   longer than its fuses allow;
##  - score          what breaks the mode's rules: a negative stack or bank, a bank that shrinks or grows under closed
##                   lids, a winner without the best score (Grub Stack: the gong; a tie goes to the Golden Drumstick's
##                   one side); hearts outside 0..3, an out hero back in, hurts that go down, a winner who was out, a
##                   loser still standing at a last-one-standing gong, a cap winner who has not the fewest hurts (Last
##                   Caveman Standing); an ember on a hero who is out, a score other than 1 standing / 0 out (Hot Rock);
##                   goals that go down, two goals on one tick, more than CLUBBALL_GOALS, a winner side without the
##                   lead, a drawn game (Clubball); winners of two sides; the match's own record of the round;
##  - outside        a hero in play with his feet outside the arena view for more than OUTSIDE_TICKS_MAX ticks in a
##                   row, or outside at the gong; a hero who should respawn and did not; the coconut outside;
##  - setup          a round that could not start (no referee, a bot graph baked from another text).
## Not checked here (tests/test_versus_bots.gd is their proof): bot idleness (printed as a number), spawn fairness,
## replay digests.
##
## Arguments (tools/bots/soak.gd passes the user arguments):
##   rounds=<n>            rounds per mode (default ROUNDS_PER_MODE = 1 000; the cells share them evenly, rounded up)
##   mode=<name[,name]>    only these modes (grub_stack, last_caveman, hot_rock, clubball)
##   shard=<i>/<n>         every n-th round of the plan from the i-th (soak.sh runs them side by side)
##   rules=default|mix     see above
##   first=<k>             start the cells' seeds at SEED_BASE + k (a second, different thousand)
##   arena=<id> players=<n> seed=<s> round=<r>   ONE round (with mode=): the replay of an anomaly; detail=1 prints it
##   trace=<from>:<to>     with one round: a TRACE line per tick of that span (every hero's feet, speed, state, ground,
##                         platform, dead / out and the keys his CPU pressed) - what led to the anomaly's tick
##   detail=1              a ROUND line per round
##   cells=1               print the cell table and stop
## Output: `CELL` lines (the table), `ANOMALY kind=.. mode=.. arena=.. players=.. seed=.. round=.. tick=.. <what>`,
## `NET <round> squeezed_out=.. wedged_coconuts=..` for a round in which one of the referee's two nets fired (DESIGN.md
## G93: a hero knocked out outside the arena's side, a coconut freed from a wall - counted, not anomalies), one
## `SOAK mode=..` line per mode and `SOAKDONE rounds=.. anomalies=..` last (a shard without it crashed).

const LEVEL_SCENE: String = "res://scenes/world/level.tscn"
const LEVEL_DIR: String = "res://levels"
const MODES: Array[int] = [Defs.VersusMode.GRUB_STACK, Defs.VersusMode.LAST_CAVEMAN, Defs.VersusMode.HOT_ROCK,
	Defs.VersusMode.CLUBBALL]
const PLAYER_COUNTS: Array[int] = [2, 3, 4]
const ROUNDS_PER_MODE: int = 1000
const SEED_BASE: int = 4001
## Ticks played past the gong (heroes frozen, the level still ticking).
const AFTER_GONG_TICKS: int = 24
## A round that has not ended this long after its clock, cap or last fuse has no end (the bot module's limit).
const ROUND_LIMIT_TICKS: int = 5200
## A hero in play may be outside the view this many ticks in a row (a fall into a pit kills him sooner; a spring's arc
## over the top is shorter).
const OUTSIDE_TICKS_MAX: int = 48
## Feet this far over the top of the view are still inside for the span check (a bounce off a head on the top tier
## arcs higher, but for less than OUTSIDE_TICKS_MAX ticks), and this far under its bottom (the fill row of the file).
const TOP_MARGIN_PX: int = 80
const BOTTOM_MARGIN_PX: int = 16
## Slack on the respawn clock (the death animation ends, then VersusTuning.RESPAWN_TICKS run).
const RESPAWN_SLACK_TICKS: int = 96
const VARIANTS_MIX: Array[String] = ["hammer_time", "axe_rain", "big_bounce", "one_bonk", "slippery", "lights_out",
	"gusty", "giant_rain", "spear_party"]


## Counts engine errors while a round runs (tests/run_tests.gd does the same for a test).
class ErrorCounter:
	extends Logger

	var errors: int = 0
	var lines: PackedStringArray = PackedStringArray()

	func _log_error(
			function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool,
			error_type: int, _script_backtraces: Array[ScriptBacktrace]
	) -> void:
		if error_type == Logger.ERROR_TYPE_WARNING:
			return
		errors += 1
		if lines.size() < 4:
			var text: String = rationale if not rationale.is_empty() else code
			lines.append("%s (%s:%d in %s)" % [text, file, line, function])

	func _log_message(_message: String, _error: bool) -> void:
		pass

	func reset() -> void:
		errors = 0
		lines = PackedStringArray()


## What the checks remember from the tick before (index = slot).
class Watch:
	extends RefCounted
	var phase: int = VersusReferee.PHASE_INTRO
	var round_ticks: int = 0
	var went_golden: bool = false
	var golden_at: int = -1
	var banked: PackedInt32Array = PackedInt32Array([0, 0, 0, 0])
	var hurts: PackedInt32Array = PackedInt32Array([0, 0, 0, 0])
	var out: PackedByteArray = PackedByteArray([0, 0, 0, 0])
	## In play (alive and not out) and standing (not out; dead only counts where a knock-out is final) as the tick before
	## ended: on the gong's tick they still say who was there when the tick began.
	var alive: PackedByteArray = PackedByteArray([1, 1, 1, 1])
	var standing: PackedByteArray = PackedByteArray([1, 1, 1, 1])
	var outside: PackedInt32Array = PackedInt32Array([0, 0, 0, 0])
	var dead_for: PackedInt32Array = PackedInt32Array([0, 0, 0, 0])
	var holder_gone: int = 0
	var goals: PackedInt32Array = PackedInt32Array([0, 0, 0])
	var goal_tick: int = -1000
	var ball_outside: int = 0
	var lids_bank: PackedInt32Array = PackedInt32Array([-1, -1, -1, -1])
	## Kinds already reported this round (one line per kind and round keeps a broken rule from flooding the log).
	var said: Dictionary = {}


var _errors: ErrorCounter = ErrorCounter.new()
var _level: Level = null
var _texts: Dictionary = {}     # arena id -> level text
var _metas: Dictionary = {}     # arena id -> resolved meta
var _graph_ok: Dictionary = {}  # arena id -> bool (the committed graph was baked from the text)
var _logging: bool = false


# =================================================================================================================
# The plan
# =================================================================================================================

## The shipped arena files (levels/arena_*.lvl), sorted by id.
static func arena_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	var files: PackedStringArray = DirAccess.get_files_at(LEVEL_DIR)
	files.sort()
	for file: String in files:
		if file.get_extension() == "lvl" and file.begins_with("arena_"):
			result.append(StringName(file.get_basename()))
	return result


## Every cell of `mode`: {"mode", "arena", "players", "bots" (false: the game seats no CPU there, G50)}.
func cells(mode: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for id: StringName in arena_ids():
		var meta: Dictionary = _meta_of(id)
		if not VersusArena.modes_of(meta).has(mode):
			continue
		var cpu: bool = true
		var listed: String = str(meta.get("bots", "")).strip_edges()
		if listed != "":
			cpu = false
			for part: String in listed.split(",", false):
				cpu = cpu or part.strip_edges() == String(Defs.versus_mode_name(mode))
		for players: int in PLAYER_COUNTS:
			if players <= VersusArena.players_of(meta):
				result.append({"mode": mode, "arena": id, "players": players, "bots": cpu})
	return result


## The rounds of `rounds` per mode over `modes`, cell by cell in turn (so a shard of every n-th round holds every cell):
## [{"mode", "arena", "players", "seed", "round", "bots"}].
func plan(modes: Array[int], rounds: int, first: int = 0) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for mode: int in modes:
		var mode_cells: Array[Dictionary] = cells(mode)
		if mode_cells.is_empty():
			continue
		var per_cell: int = ceili(float(rounds) / float(mode_cells.size()))
		for k: int in per_cell:
			for cell: Dictionary in mode_cells:
				var spec: Dictionary = cell.duplicate()
				spec["seed"] = SEED_BASE + first + k
				spec["round"] = (first + k) % int(cell["players"])
				result.append(spec)
	return result


func _text_of(id: StringName) -> String:
	if not _texts.has(id):
		_texts[id] = FileAccess.get_file_as_string("%s/%s.lvl" % [LEVEL_DIR, id])
	return _texts[id]


func _meta_of(id: StringName) -> Dictionary:
	if not _metas.has(id):
		_metas[id] = LevelData.parse(id, _text_of(id)).resolved_meta(Defs.Difficulty.BEGINNER)
	return _metas[id]


# =================================================================================================================
# Running
# =================================================================================================================

## The tool: parse `args`, play the plan (or the one round named), print the lines. Returns the number of anomalies.
func run(args: PackedStringArray) -> int:
	var rounds: int = ROUNDS_PER_MODE
	var modes: Array[int] = MODES.duplicate()
	var shard: Vector2i = Vector2i(0, 1)
	var mix: bool = false
	var detail: bool = false
	var first: int = 0
	var only_cells: bool = false
	var one: Dictionary = {}
	for arg: String in args:
		if arg.begins_with("rounds="):
			rounds = maxi(int(arg.trim_prefix("rounds=")), 1)
		elif arg.begins_with("mode="):
			modes.clear()
			for name: String in arg.trim_prefix("mode=").split(",", false):
				var mode: int = Defs.versus_mode_from_name(StringName(name))
				if MODES.has(mode):
					modes.append(mode)
		elif arg.begins_with("shard="):
			var parts: PackedStringArray = arg.trim_prefix("shard=").split("/")
			if parts.size() == 2 and int(parts[1]) >= 1:
				shard = Vector2i(clampi(int(parts[0]), 0, int(parts[1]) - 1), int(parts[1]))
		elif arg.begins_with("rules="):
			mix = arg.trim_prefix("rules=") == "mix"
		elif arg.begins_with("first="):
			first = maxi(int(arg.trim_prefix("first=")), 0)
		elif arg == "detail=1":
			detail = true
		elif arg == "cells=1":
			only_cells = true
		elif arg.begins_with("arena="):
			one["arena"] = StringName(arg.trim_prefix("arena="))
		elif arg.begins_with("players="):
			one["players"] = int(arg.trim_prefix("players="))
		elif arg.begins_with("seed="):
			one["seed"] = int(arg.trim_prefix("seed="))
		elif arg.begins_with("round="):
			one["round"] = int(arg.trim_prefix("round="))
		elif arg.begins_with("trace="):
			var span: PackedStringArray = arg.trim_prefix("trace=").split(":")
			if span.size() == 2:
				one["trace"] = Vector2i(int(span[0]), int(span[1]))
	if modes.is_empty():
		print("SOAK: no such mode")
		return 1
	var specs: Array[Dictionary] = []
	if one.has("arena"):
		one["mode"] = modes[0]
		one["players"] = int(one.get("players", 4))
		one["seed"] = int(one.get("seed", SEED_BASE))
		one["round"] = int(one.get("round", 0))
		one["bots"] = true
		specs.append(one)
	else:
		for mode: int in modes:
			var table: Dictionary = {}
			for cell: Dictionary in cells(mode):
				var key: String = "%s%s" % [cell["arena"], "" if bool(cell["bots"]) else " (stand-in: no CPU seat in the game, G50)"]
				var list: PackedStringArray = table.get(key, PackedStringArray())
				list.append(str(cell["players"]))
				table[key] = list
			for key: String in table:
				if shard.x == 0:
					print("CELL mode=%s arena=%s players=%s" % [Defs.versus_mode_name(mode), key, ",".join(table[key])])
		if only_cells:
			return 0
		var all: Array[Dictionary] = plan(modes, rounds, first)
		for index: int in all.size():
			if index % shard.y == shard.x:
				specs.append(all[index])
	var result: Dictionary = await play_all(specs, mix, detail)
	for line: String in result["lines"]:
		print(line)
	print("SOAKDONE rounds=%d ticks=%d anomalies=%d ms=%d shard=%d/%d rules=%s" % [result["rounds"], result["ticks"],
			result["anomalies"], result["ms"], shard.x, shard.y, "mix" if mix else "default"])
	return int(result["anomalies"])


## Play `specs` (see [method plan]); a frame between two rounds lets the freed level's queued calls run. Returns
## {"rounds", "ticks", "anomalies" (count), "anomaly_lines", "lines" (the SOAK line of every mode), "ms",
## "longest" (ticks of play of the longest round)}. ANOMALY lines are printed as they are found.
func play_all(specs: Array[Dictionary], mix: bool = false, detail: bool = false) -> Dictionary:
	var started: int = Time.get_ticks_msec()
	var per_mode: Dictionary = {}
	var anomaly_lines: PackedStringArray = PackedStringArray()
	var total_rounds: int = 0
	var total_ticks: int = 0
	var longest_all: int = 0
	_begin()
	for spec: Dictionary in specs:
		var result: Dictionary = play(spec, mix)
		var mode: int = int(spec["mode"])
		if not per_mode.has(mode):
			per_mode[mode] = {"rounds": 0, "ticks": 0, "play": 0, "longest": 0, "longest_at": "", "ends": {},
					"anomalies": 0, "idle": 0, "golden": 0, "squeezed": 0, "wedged": 0}
		var sum: Dictionary = per_mode[mode]
		sum["rounds"] = int(sum["rounds"]) + 1
		sum["ticks"] = int(sum["ticks"]) + int(result["ticks"])
		sum["play"] = int(sum["play"]) + int(result["round_ticks"])
		sum["idle"] = maxi(int(sum["idle"]), int(result["worst_idle"]))
		sum["golden"] = maxi(int(sum["golden"]), int(result["golden_ticks"]))
		sum["squeezed"] = int(sum["squeezed"]) + int(result["squeezed"])
		sum["wedged"] = int(sum["wedged"]) + int(result["wedged"])
		if int(result["squeezed"]) + int(result["wedged"]) > 0:
			# Not anomalies - the referee's two nets at work (DESIGN.md G93): each firing is named with its round.
			print("NET %s squeezed_out=%d wedged_coconuts=%d" % [result["tag"], result["squeezed"], result["wedged"]])
		if int(result["round_ticks"]) > int(sum["longest"]):
			sum["longest"] = int(result["round_ticks"])
			sum["longest_at"] = "%s/%dp/seed%d/r%d" % [spec["arena"], spec["players"], spec["seed"], spec["round"]]
		var ends: Dictionary = sum["ends"]
		ends[result["end"]] = int(ends.get(result["end"], 0)) + 1
		total_rounds += 1
		total_ticks += int(result["ticks"])
		longest_all = maxi(longest_all, int(result["round_ticks"]))
		for line: String in result["anomalies"]:
			sum["anomalies"] = int(sum["anomalies"]) + 1
			anomaly_lines.append(line)
			print(line)
		if detail:
			print("ROUND %s ticks=%d play=%d end=%s winners=%s scores=%s idle=%d" % [result["tag"], result["ticks"],
					result["round_ticks"], result["end"], result["winners"], result["scores"], result["worst_idle"]])
		await get_tree().process_frame
	_end()
	var lines: PackedStringArray = PackedStringArray()
	for mode: int in MODES:
		if not per_mode.has(mode):
			continue
		var sum: Dictionary = per_mode[mode]
		var ends: PackedStringArray = PackedStringArray()
		var kinds: Array = (sum["ends"] as Dictionary).keys()
		kinds.sort()
		for kind: Variant in kinds:
			ends.append("%s:%d" % [kind, sum["ends"][kind]])
		lines.append("SOAK mode=%s rounds=%d ticks=%d play=%d longest=%d at=%s ends=%s golden_max=%d idle_max=%d squeezed=%d wedged=%d anomalies=%d" % [
			Defs.versus_mode_name(mode), sum["rounds"], sum["ticks"], sum["play"], sum["longest"],
			sum["longest_at"] if str(sum["longest_at"]) != "" else "-", ",".join(ends), sum["golden"], sum["idle"],
			sum["squeezed"], sum["wedged"], sum["anomalies"]])
	return {"rounds": total_rounds, "ticks": total_ticks, "anomalies": anomaly_lines.size(),
			"anomaly_lines": anomaly_lines, "lines": lines, "ms": Time.get_ticks_msec() - started, "longest": longest_all}


func _begin() -> void:
	if not _logging:
		OS.add_logger(_errors)
		_logging = true
	Game.new_game(Defs.Difficulty.BEGINNER)


func _end() -> void:
	_free_level()
	GameInput.clear_scripted()
	GameInput.reset_slots()
	Game.versus_match = null
	Sim.stop()
	Game.new_game(Defs.Difficulty.BEGINNER)
	if _logging:
		OS.remove_logger(_errors)
		_logging = false


func _exit_tree() -> void:
	if _logging:
		OS.remove_logger(_errors)
		_logging = false


# =================================================================================================================
# One round
# =================================================================================================================

## Play the round `spec` names. Returns {"ticks" (Sim ticks with the intro and the ticks past the gong), "round_ticks"
## (ticks of play), "ended", "end" (how: clock, golden, standing, cap, draw, goals, none), "winners", "scores",
## "worst_idle", "golden_ticks", "anomalies" (ANOMALY lines)}.
func play(spec: Dictionary, mix: bool = false) -> Dictionary:
	var mode: int = int(spec["mode"])
	var id: StringName = spec["arena"]
	var players: int = clampi(int(spec["players"]), VersusTuning.PLAYERS_MIN, Defs.MAX_PLAYERS)
	var seed_value: int = int(spec["seed"])
	var round_index: int = int(spec["round"])
	var found: PackedStringArray = PackedStringArray()
	var result: Dictionary = {"ticks": 0, "round_ticks": 0, "ended": false, "end": "none",
			"winners": PackedInt32Array(), "scores": PackedInt32Array(), "worst_idle": 0, "golden_ticks": 0,
			"squeezed": 0, "wedged": 0,
			"anomalies": found}
	var tag: String = "mode=%s arena=%s players=%d seed=%d round=%d" % [Defs.versus_mode_name(mode), id, players,
			seed_value, round_index]
	result["tag"] = tag
	_errors.reset()
	_free_level()
	var text: String = _text_of(id)
	if text.is_empty():
		found.append("ANOMALY kind=setup %s tick=0 no level text" % tag)
		return result
	if not _graph_ok.has(id):
		var graph: NavGraph = NavGraph.load_for_level(id)
		_graph_ok[id] = graph != null and graph.source_sha256 == NavGraph.text_sha256(text)
	if not bool(_graph_ok[id]):
		found.append("ANOMALY kind=setup %s tick=0 the committed bot graph was not baked from this arena text" % tag)
		return result
	# The match, as the lobby and Flow.start_versus leave it.
	var versus_match: VersusMatch = VersusMatch.new()
	for slot: int in players:
		versus_match.seat_bot(posmod(seed_value + slot, 3))
	versus_match.mode = mode
	versus_match.arena = id
	versus_match.begin_match(seed_value)
	if mix:
		_mix_rules(versus_match, mode, players, seed_value)
		var sides: PackedStringArray = PackedStringArray()
		for slot: int in players:
			sides.append(str(versus_match.get_seat(slot).team))
		# An anomaly under mixed rules names them (replay it with rules=mix).
		tag += " rules=mix(preset=%s,variants=%s,stock=%s,sudden=%s,weapons=%s,teams=%s)" % [
			VersusMatch.PRESET_NAMES[versus_match.preset], "+".join(versus_match.variants) if not versus_match.variants.is_empty() else "-",
			versus_match.stock, versus_match.sudden_death, versus_match.weapons, "".join(sides)]
	versus_match.round_index = round_index
	versus_match.begin_round(id)
	Game.versus_match = versus_match
	Sim.manual = true
	Game.start_run(Defs.Difficulty.BEGINNER, Defs.GameMode.VERSUS, players, 1)
	Game.begin_level(id)
	_level = (load(LEVEL_SCENE) as PackedScene).instantiate() as Level
	_level.setup_from_text(id, text)
	add_child(_level)
	_level.set_view_size(Vector2i(Tuning.VIEW_W, Tuning.VIEW_H) * Tuning.ART_SCALE)
	Sim.start(versus_match.round_seed())
	var referee: VersusReferee = VersusReferee.find(_level)
	if referee == null or _level.hero_count() != players:
		found.append("ANOMALY kind=setup %s tick=0 no referee or %d heroes for %d seats" % [tag, _level.hero_count(),
				players])
		_cleanup_round([])
		return result
	if referee.mode != mode or referee.round_index != round_index:
		found.append("ANOMALY kind=setup %s tick=0 the referee plays mode %d round %d" % [tag, referee.mode,
				referee.round_index])
	# The gong goes to this tool, not to Flow's scoreboard: the referee emits Events.round_ended itself for a round the
	# match does not hold open.
	versus_match.round_open = false
	var bots: Array[HeroBot] = []
	for slot: int in players:
		var bot: HeroBot = HeroBot.new(slot, versus_match.get_seat(slot).bot_level, versus_match.match_seed,
				versus_match.round_mode)
		bot.reset_round(versus_match.round_seed())
		bot.install()
		bots.append(bot)
		versus_match.bots[slot] = bot
	var watch: Watch = Watch.new()
	var view: Rect2i = VersusArena.view_rect()
	var intro: int = VersusTuning.COUNTDOWN_STEPS * VersusReferee.INTRO_COUNT_TICKS
	var rule_limit: int = _rule_limit(referee, players)
	var limit: int = intro + rule_limit + ROUND_LIMIT_TICKS
	var t: int = 0
	var gong_at: int = -1
	var trace: Vector2i = spec.get("trace", Vector2i(-1, -1))
	while t < limit:
		Sim.step(1)
		t += 1
		_check_tick(referee, players, view, watch, found, tag, t)
		if t >= trace.x and t <= trace.y:
			_print_trace(referee, players, t)
		for bot: HeroBot in bots:
			var hero: PlayerBase = _level.get_hero(bot.slot)
			if hero != null and not hero.dead and referee.is_in_play(hero) and hero.control_enabled:
				result["worst_idle"] = maxi(int(result["worst_idle"]), bot.idle_ticks)
		if referee.phase == VersusReferee.PHASE_OVER:
			if gong_at < 0:
				gong_at = t
				_check_gong(referee, players, view, watch, found, tag, t, rule_limit)
			elif t - gong_at >= AFTER_GONG_TICKS:
				break
	result["ticks"] = t
	result["round_ticks"] = referee.round_ticks
	result["ended"] = gong_at >= 0
	result["winners"] = referee.winner_slots.duplicate()
	var scores: PackedInt32Array = PackedInt32Array()
	for slot: int in players:
		scores.append(referee.score_of(slot))
	result["scores"] = scores
	result["golden_ticks"] = referee.round_ticks - watch.golden_at if watch.golden_at >= 0 else 0
	result["wedged"] = referee.clubball.wedged_resets if referee.mode == Defs.VersusMode.CLUBBALL else 0
	result["squeezed"] = referee.squeezed_out
	if gong_at < 0:
		found.append("ANOMALY kind=no_end %s tick=%d the round did not end: phase %d after %d ticks of play (limit %d)" % [
			tag, t, referee.phase, referee.round_ticks, rule_limit + ROUND_LIMIT_TICKS])
	else:
		result["end"] = _end_kind(referee, watch)
		# The match's own record of the round (Flow.end_round does this in the game).
		versus_match.round_open = true
		var wins_before: PackedInt32Array = versus_match.round_wins.duplicate()
		versus_match.record_round(referee.winner_slots)
		for slot: int in Defs.MAX_PLAYERS:
			var won: bool = referee.winner_slots.has(slot)
			if versus_match.round_wins[slot] - wins_before[slot] != (1 if won else 0):
				_say(watch, found, "score", tag, t, "the match recorded %s for winners %s" % [versus_match.round_wins,
						referee.winner_slots])
	result["tag"] = tag
	if _errors.errors > 0:
		found.append("ANOMALY kind=engine_error %s tick=%d %d engine error(s): %s" % [tag, t, _errors.errors,
				" | ".join(_errors.lines)])
	_cleanup_round(bots)
	return result


## One TRACE line: the tick, then per hero his feet, speed, state, what he stands on and the keys of his CPU.
func _print_trace(referee: VersusReferee, players: int, tick: int) -> void:
	var parts: PackedStringArray = PackedStringArray()
	for slot: int in players:
		var hero: PlayerBase = _level.get_hero(slot)
		parts.append("P%d %s v(%d,%d) st%d%s%s%s%s%s keys=%s" % [slot + 1, hero.sim_pos, hero.xvel, hero.yvel, hero.state,
				" ground" if hero.is_grounded() else "", " platform" if hero.on_platform else "",
				" totem" if hero.is_riding_totem() else "", " DEAD" if hero.dead else "",
				" OUT" if referee.is_out(slot) else "", NavGraph.flags_to_keys(GameInput.get_flags(slot))])
	var ball: SimEntity = referee.ball() if referee.mode == Defs.VersusMode.CLUBBALL else null
	if ball != null and is_instance_valid(ball):
		parts.append("ball %s v(%d,%d)%s goals %d:%d" % [ball.sim_pos, ball.xvel, ball.yvel,
				"" if bool(ball.call(&"in_play")) else " out of play", referee.goals_of(1), referee.goals_of(2)])
	print("TRACE t=%d play=%d %s" % [tick, referee.round_ticks, " | ".join(parts)])


func _cleanup_round(bots: Array) -> void:
	for bot: Variant in bots:
		(bot as HeroBot).uninstall()
	_free_level()
	Game.versus_match = null


func _free_level() -> void:
	if _level != null and is_instance_valid(_level):
		if _level.get_parent() != null:
			_level.get_parent().remove_child(_level)
		_level.free()
	_level = null


## `rules=mix`: preset, a variant, Stock, the sudden-death event and 2v2 drawn from the seed (the variant is set after
## VersusMatch.begin_match, which drops the ones the profile has not opened: the soak plays them all).
func _mix_rules(versus_match: VersusMatch, mode: int, players: int, seed_value: int) -> void:
	var rng: SimRng = SimRng.new(seed_value * 31 + mode * 7 + players)
	versus_match.preset = rng.pick_index(3)
	versus_match.sudden_death = rng.pick_index(2) == 1
	versus_match.stock = mode == Defs.VersusMode.LAST_CAVEMAN and rng.pick_index(2) == 1
	versus_match.weapons = &"club" if rng.pick_index(4) == 0 else &"all"
	var variants: PackedStringArray = PackedStringArray()
	if rng.pick_index(3) != 0:
		variants.append(VARIANTS_MIX[rng.pick_index(VARIANTS_MIX.size())])
	versus_match.variants = variants
	if players == 4 and rng.pick_index(2) == 1:
		# 2v2: P1 with P2, P3 or P4.
		var mate: int = 1 + rng.pick_index(3)
		for slot: int in players:
			versus_match.get_seat(slot).team = 1 if slot == 0 or slot == mate else 2


## Ticks of play after which the mode's own rule must have ended the round (without a tie's golden item).
func _rule_limit(referee: VersusReferee, players: int) -> int:
	match referee.mode:
		Defs.VersusMode.LAST_CAVEMAN:
			return VersusTuning.SUDDEN_DEATH_AT_TICKS + VersusTuning.SUDDEN_DEATH_CAP_TICKS
		Defs.VersusMode.HOT_ROCK:
			# Every knock-out but the last takes one fuse at most (a pass does not rewind it) and the wait for the pick.
			return VersusTuning.HOT_ROCK_FIRST_PICK_TICKS + (players - 1) * (VersusTuning.HOT_ROCK_FUSE_MAX_TICKS
					+ VersusTuning.HOT_ROCK_REPICK_TICKS + 2)
	return referee.round_total


# =================================================================================================================
# The checks
# =================================================================================================================

func _say(watch: Watch, found: PackedStringArray, kind: String, tag: String, tick: int, what: String) -> void:
	var key: String = kind + ":" + what.get_slice(":", 0)
	if watch.said.has(key):
		return
	watch.said[key] = true
	found.append("ANOMALY kind=%s %s tick=%d %s" % [kind, tag, tick, what])


## After every tick.
func _check_tick(referee: VersusReferee, players: int, view: Rect2i, watch: Watch, found: PackedStringArray,
		tag: String, tick: int) -> void:
	var mode: int = referee.mode
	var phase: int = referee.phase
	var live_before: bool = watch.phase == VersusReferee.PHASE_PLAY or watch.phase == VersusReferee.PHASE_GOLDEN
	var live: bool = phase == VersusReferee.PHASE_PLAY or phase == VersusReferee.PHASE_GOLDEN
	# --- phase and clock
	if phase < watch.phase:
		_say(watch, found, "phase", tag, tick, "phase went back: %d after %d" % [phase, watch.phase])
	if live_before:
		var step: int = referee.round_ticks - watch.round_ticks
		if live and step != 1:
			_say(watch, found, "clock", tag, tick, "round clock: %d after %d while the round runs" % [referee.round_ticks,
					watch.round_ticks])
		elif not live and step != 0 and step != 1:
			_say(watch, found, "clock", tag, tick, "round clock: %d after %d at the gong" % [referee.round_ticks,
					watch.round_ticks])
	elif referee.round_ticks != watch.round_ticks:
		_say(watch, found, "clock", tag, tick, "round clock moved outside the round: %d after %d (phase %d)" % [
			referee.round_ticks, watch.round_ticks, phase])
	if phase == VersusReferee.PHASE_GOLDEN and not watch.went_golden:
		watch.went_golden = true
		watch.golden_at = referee.round_ticks
		if mode != Defs.VersusMode.GRUB_STACK and mode != Defs.VersusMode.CLUBBALL:
			_say(watch, found, "phase", tag, tick, "a golden tie-break in a mode without one")
		elif referee.round_total > 0 and referee.round_ticks != referee.round_total:
			_say(watch, found, "clock", tag, tick, "golden: the tie-break started at tick %d of a %d-tick round" % [
				referee.round_ticks, referee.round_total])
	if live and phase == VersusReferee.PHASE_PLAY and referee.round_total > 0 and referee.round_ticks >= referee.round_total:
		_say(watch, found, "clock", tag, tick, "past the clock: tick %d of a %d-tick round and still playing" % [
			referee.round_ticks, referee.round_total])
	if mode == Defs.VersusMode.LAST_CAVEMAN and live:
		var cap: int = VersusTuning.SUDDEN_DEATH_AT_TICKS + VersusTuning.SUDDEN_DEATH_CAP_TICKS
		if referee.round_ticks >= cap:
			_say(watch, found, "clock", tag, tick, "past the cap: tick %d and still playing (the cap falls at %d)" % [
				referee.round_ticks, cap])
		if referee.round_ticks > VersusTuning.SUDDEN_DEATH_AT_TICKS and referee.cap_at != cap:
			_say(watch, found, "clock", tag, tick, "cap not armed: cap_at %d after the sudden death's tick (expected %d)" % [
				referee.cap_at, cap])
	# --- the mode's currency
	var scores_ok: bool = true
	for slot: int in Defs.MAX_PLAYERS:
		var score: int = referee.score_of(slot)
		if score < 0:
			_say(watch, found, "score", tag, tick, "negative score: P%d has %d" % [slot + 1, score])
		# (Hot Rock's 1 = "not out" and Clubball's side goals are no score of an empty seat.)
		if slot >= players and (referee.stack_of(slot) != 0 or (score != 0 and mode != Defs.VersusMode.CLUBBALL \
				and mode != Defs.VersusMode.HOT_ROCK)):
			scores_ok = false
	if not scores_ok:
		_say(watch, found, "score", tag, tick, "empty seat: a slot without a hero has a score")
	match mode:
		Defs.VersusMode.GRUB_STACK:
			for slot: int in players:
				var stack: int = referee.stack_of(slot)
				var banked: int = referee.banked_of(slot)
				if stack < 0 or banked < 0:
					_say(watch, found, "score", tag, tick, "negative food: P%d stack %d bank %d" % [slot + 1, stack, banked])
				if banked < watch.banked[slot]:
					_say(watch, found, "score", tag, tick, "bank shrank: P%d %d after %d" % [slot + 1, banked,
							watch.banked[slot]])
				if referee.lids_closed():
					if watch.lids_bank[slot] < 0:
						watch.lids_bank[slot] = banked
					elif banked != watch.lids_bank[slot]:
						_say(watch, found, "score", tag, tick, "banked under closed lids: P%d %d after %d" % [slot + 1, banked,
								watch.lids_bank[slot]])
				watch.banked[slot] = banked
			if live and referee.round_total > 0:
				var rush: bool = referee.round_ticks >= referee.round_total - VersusTuning.FEAST_RUSH_TICKS
				if rush != referee.in_feast_rush() and phase == VersusReferee.PHASE_PLAY:
					_say(watch, found, "clock", tag, tick, "feast rush: %s at tick %d of %d" % [referee.in_feast_rush(),
							referee.round_ticks, referee.round_total])
		Defs.VersusMode.LAST_CAVEMAN:
			for slot: int in players:
				var hero: PlayerBase = _level.get_hero(slot)
				var most: int = maxi(referee.start_hearts[slot], Tuning.ENERGY_START)
				if hero.run.hearts < 0 or hero.run.hearts > most:
					_say(watch, found, "score", tag, tick, "hearts: P%d has %d (0..%d)" % [slot + 1, hero.run.hearts, most])
				if referee.hurts_of(slot) < watch.hurts[slot]:
					_say(watch, found, "score", tag, tick, "hurts went down: P%d %d after %d" % [slot + 1,
							referee.hurts_of(slot), watch.hurts[slot]])
				if watch.out[slot] != 0 and not referee.is_out(slot):
					_say(watch, found, "score", tag, tick, "back in: P%d was out of the round" % (slot + 1))
				if referee.is_out(slot) and referee.score_of(slot) != 0:
					_say(watch, found, "score", tag, tick, "out with a score: P%d has %d" % [slot + 1,
							referee.score_of(slot)])
				watch.hurts[slot] = referee.hurts_of(slot)
		Defs.VersusMode.HOT_ROCK:
			var holder: int = referee.ember_holder()
			if holder >= players:
				_say(watch, found, "score", tag, tick, "ember on an empty seat: slot %d" % holder)
			elif holder >= 0 and live:
				var hero: PlayerBase = _level.get_hero(holder)
				# The ember notices a holder a hazard took on its next WORLD step: one tick of grace.
				watch.holder_gone = watch.holder_gone + 1 if hero.dead or referee.is_out(holder) else 0
				if watch.holder_gone > 2:
					_say(watch, found, "score", tag, tick, "ember on a hero who is out: P%d" % (holder + 1))
			else:
				watch.holder_gone = 0
			for slot: int in players:
				if referee.score_of(slot) != (0 if referee.is_out(slot) else 1):
					_say(watch, found, "score", tag, tick, "hot rock score: P%d has %d, out %s" % [slot + 1,
							referee.score_of(slot), referee.is_out(slot)])
				if watch.out[slot] != 0 and not referee.is_out(slot):
					_say(watch, found, "score", tag, tick, "back in: P%d was out of the round" % (slot + 1))
		Defs.VersusMode.CLUBBALL:
			var scored: int = 0
			for team: int in [1, 2]:
				var goals: int = referee.goals_of(team)
				if goals < watch.goals[team]:
					_say(watch, found, "score", tag, tick, "goals went down: team %d %d after %d" % [team, goals,
							watch.goals[team]])
				if goals > VersusTuning.CLUBBALL_GOALS:
					_say(watch, found, "score", tag, tick, "too many goals: team %d has %d" % [team, goals])
				scored += goals - watch.goals[team]
				watch.goals[team] = goals
			if scored > 1:
				_say(watch, found, "score", tag, tick, "two goals on one tick")
			if scored > 0:
				if not live_before:
					_say(watch, found, "score", tag, tick, "a goal outside the game (phase %d)" % watch.phase)
				if tick - watch.goal_tick < VersusTuning.BALL_RESET_TICKS:
					_say(watch, found, "score", tag, tick, "a goal in the pause: %d ticks after the last one" % (
							tick - watch.goal_tick))
				watch.goal_tick = tick
			for slot: int in players:
				if referee.score_of(slot) != referee.goals_of(referee.team_of(slot)):
					_say(watch, found, "score", tag, tick, "clubball score: P%d has %d, his side %d" % [slot + 1,
							referee.score_of(slot), referee.goals_of(referee.team_of(slot))])
			var ball: SimEntity = referee.ball()
			if ball != null and is_instance_valid(ball) and live and bool(ball.call(&"in_play")):
				var at: Vector2i = ball.sim_pos
				var gone: bool = at.x < view.position.x - Tuning.TILE or at.x >= view.end.x + Tuning.TILE \
						or at.y >= view.end.y + BOTTOM_MARGIN_PX + Tuning.TILE or at.y < view.position.y - 4 * TOP_MARGIN_PX
				watch.ball_outside = watch.ball_outside + 1 if gone else 0
				if watch.ball_outside > OUTSIDE_TICKS_MAX:
					_say(watch, found, "outside", tag, tick, "coconut outside: at %s for %d ticks" % [at, watch.ball_outside])
	# --- heroes: inside the arena, back after a knock-out
	for slot: int in players:
		var hero: PlayerBase = _level.get_hero(slot)
		if hero == null or not is_instance_valid(hero):
			_say(watch, found, "outside", tag, tick, "hero gone: P%d is not in the level" % (slot + 1))
			continue
		var in_play: bool = not hero.dead and not referee.is_out(slot)
		if in_play and _is_outside(hero.sim_pos, view):
			watch.outside[slot] += 1
			if watch.outside[slot] > OUTSIDE_TICKS_MAX:
				_say(watch, found, "outside", tag, tick, "hero outside: P%d at %s for %d ticks" % [slot + 1, hero.sim_pos,
						watch.outside[slot]])
		else:
			watch.outside[slot] = 0
		if hero.dead and not referee.is_out(slot) and not referee.knockouts_final and phase == VersusReferee.PHASE_PLAY:
			watch.dead_for[slot] += 1
			if watch.dead_for[slot] > VersusTuning.RESPAWN_TICKS + RESPAWN_SLACK_TICKS:
				_say(watch, found, "outside", tag, tick, "no respawn: P%d dead for %d ticks at %s" % [slot + 1,
						watch.dead_for[slot], hero.sim_pos])
		else:
			watch.dead_for[slot] = 0
		watch.out[slot] = 1 if referee.is_out(slot) else 0
		if phase != VersusReferee.PHASE_OVER:
			watch.alive[slot] = 1 if in_play else 0
			watch.standing[slot] = 0 if referee.is_out(slot) or (hero.dead and referee.knockouts_final) else 1
	watch.phase = phase
	watch.round_ticks = referee.round_ticks


## Outside the arena: left or right of the view, under it, or more than `top` px over it.
static func _is_outside(pos: Vector2i, view: Rect2i, top: int = TOP_MARGIN_PX) -> bool:
	return pos.x < view.position.x or pos.x >= view.end.x or pos.y < view.position.y - top \
			or pos.y > view.end.y + BOTTOM_MARGIN_PX


## The side `slot` plays on: his team (2v2, Clubball's sides), else himself.
static func _side(referee: VersusReferee, slot: int) -> int:
	var team: int = referee.team_of(slot)
	return 100 + team if team >= 0 else slot


## On the tick of the gong: who won, by the mode's rule. `watch.alive` is still the state of the tick before (whoever
## was in play as the gong's tick began).
func _check_gong(referee: VersusReferee, players: int, view: Rect2i, watch: Watch, found: PackedStringArray,
		tag: String, tick: int, rule_limit: int) -> void:
	var mode: int = referee.mode
	var winners: PackedInt32Array = referee.winner_slots
	var sides: Dictionary = {}
	for slot: int in winners:
		if slot < 0 or slot >= players:
			_say(watch, found, "score", tag, tick, "winner without a seat: slot %d" % slot)
		else:
			sides[_side(referee, slot)] = true
	if sides.size() > 1:
		_say(watch, found, "score", tag, tick, "winners of two sides: %s" % [winners])
	# A side wins whole.
	for slot: int in players:
		if not winners.has(slot) and sides.has(_side(referee, slot)):
			_say(watch, found, "score", tag, tick, "half a side won: P%d is left out of %s" % [slot + 1, winners])
	# A hero the gong's own tick took (a hazard in POST, after the WORLD step named the winners) changes what this
	# check can read back - his stack is spilled, he no longer stands: the strict comparisons are left out then.
	var died_now: bool = false
	for slot: int in players:
		var fallen: PlayerBase = _level.get_hero(slot)
		died_now = died_now or (watch.alive[slot] != 0 and (fallen.dead or referee.is_out(slot)))
	if referee.round_ticks > rule_limit and not watch.went_golden:
		_say(watch, found, "clock", tag, tick, "too long: the gong at tick %d, the mode's rule ends it by %d" % [
			referee.round_ticks, rule_limit])
	match mode:
		Defs.VersusMode.GRUB_STACK:
			if not watch.went_golden and referee.round_ticks != referee.round_total:
				_say(watch, found, "clock", tag, tick, "gong off the clock: tick %d of %d" % [referee.round_ticks,
						referee.round_total])
			var totals: Dictionary = {}
			for slot: int in players:
				var side: int = _side(referee, slot)
				# 2v2: separate stacks, one pot.
				totals[side] = int(totals.get(side, referee.banked_of(slot) if side >= 100 else 0)) + (
						referee.stack_of(slot) if side >= 100 else referee.score_of(slot))
			var best: int = -1
			var best_sides: int = 0
			for side: int in totals:
				if int(totals[side]) > best:
					best = int(totals[side])
					best_sides = 1
				elif int(totals[side]) == best:
					best_sides += 1
			if winners.is_empty():
				_say(watch, found, "score", tag, tick, "no winner: a Grub Stack round always has one (totals %s)" % [totals])
			elif not watch.went_golden and not died_now:
				if best_sides != 1 or int(totals[_side(referee, winners[0])]) != best:
					_say(watch, found, "score", tag, tick, "winner without the best score: %s with totals %s" % [winners,
							totals])
		Defs.VersusMode.LAST_CAVEMAN, Defs.VersusMode.HOT_ROCK:
			# A side wins by a member who stood as the gong's tick began (a team mate may be out).
			var stood: Dictionary = {}
			for slot: int in players:
				if watch.standing[slot] != 0:
					stood[_side(referee, slot)] = true
			for side: int in sides:
				if not stood.has(side):
					_say(watch, found, "score", tag, tick, "winner who was out: %s" % [winners])
			var by_cap: bool = mode == Defs.VersusMode.LAST_CAVEMAN and referee.cap_at >= 0 \
					and referee.round_ticks >= referee.cap_at
			var standing_sides: Dictionary = {}
			for slot: int in players:
				var hero: PlayerBase = _level.get_hero(slot)
				if not (referee.is_out(slot) or (hero.dead and referee.knockouts_final)):
					standing_sides[_side(referee, slot)] = true
			if standing_sides.size() <= 1:
				# The last one standing: everybody else is gone, and whoever stands has won.
				for side: int in standing_sides:
					if not sides.has(side) and not died_now:
						_say(watch, found, "score", tag, tick, "the last one standing did not win: winners %s" % [winners])
			elif not by_cap:
				_say(watch, found, "score", tag, tick, "gong with %d sides standing and no cap (tick %d, cap_at %d)" % [
					standing_sides.size(), referee.round_ticks, referee.cap_at])
			elif not died_now:
				# The hard cap (G78): more heroes standing, then more lives, then the fewest hurts; level sides draw.
				var expected: PackedInt32Array = referee.cap_winners()
				var expected_sides: Dictionary = {}
				for slot: int in expected:
					expected_sides[_side(referee, slot)] = true
				if expected_sides.keys() != sides.keys():
					_say(watch, found, "score", tag, tick, "cap winners: %s, the rule says %s (hurts %s)" % [winners,
							expected, _hurts(referee, players)])
				var least: int = 1 << 30
				var least_sides: int = 0
				var hurts: Dictionary = {}
				for slot: int in players:
					hurts[_side(referee, slot)] = int(hurts.get(_side(referee, slot), 0)) + referee.hurts_of(slot)
				if not referee.rules.stock and referee.team_of(0) < 0:
					for side: int in standing_sides:
						if int(hurts[side]) < least:
							least = int(hurts[side])
							least_sides = 1
						elif int(hurts[side]) == least:
							least_sides += 1
					if least_sides == 1 and (winners.size() != 1 or int(hurts[_side(referee, winners[0])]) != least):
						_say(watch, found, "score", tag, tick, "cap: the fewest hurts did not win: %s with hurts %s" % [
							winners, _hurts(referee, players)])
					if least_sides > 1 and not winners.is_empty():
						_say(watch, found, "score", tag, tick, "cap: level hurts must draw: %s with hurts %s" % [winners,
								_hurts(referee, players)])
		Defs.VersusMode.CLUBBALL:
			var one: int = referee.goals_of(1)
			var two: int = referee.goals_of(2)
			if winners.is_empty() or one == two:
				_say(watch, found, "score", tag, tick, "drawn game: goals %d : %d, winners %s" % [one, two, winners])
			else:
				var lead: int = 1 if one > two else 2
				for slot: int in players:
					if winners.has(slot) != (referee.team_of(slot) == lead):
						_say(watch, found, "score", tag, tick, "winner side without the lead: %s at %d : %d" % [winners, one,
								two])
				var top: int = maxi(one, two)
				if watch.went_golden:
					if absi(one - two) != 1:
						_say(watch, found, "score", tag, tick, "golden goal: the game ended %d : %d" % [one, two])
				elif top < VersusTuning.CLUBBALL_GOALS and referee.round_ticks != referee.round_total:
					_say(watch, found, "clock", tag, tick, "gong off the clock: tick %d of %d at %d : %d" % [
						referee.round_ticks, referee.round_total, one, two])
	for slot: int in players:
		var hero: PlayerBase = _level.get_hero(slot)
		# One sample, not a span: a bounce off a head with Jump held (-192 v16) arcs 130 px over the top tier and is
		# back within a second, so here the top counts from a whole screen up - the line of the engine's own
		# off-screen rule.
		if hero != null and not hero.dead and not referee.is_out(slot) \
				and _is_outside(hero.sim_pos, view, view.size.y):
			_say(watch, found, "outside", tag, tick, "hero outside at the gong: P%d at %s" % [slot + 1, hero.sim_pos])


static func _hurts(referee: VersusReferee, players: int) -> PackedInt32Array:
	var result: PackedInt32Array = PackedInt32Array()
	for slot: int in players:
		result.append(referee.hurts_of(slot))
	return result


## How the round ended, for the table.
func _end_kind(referee: VersusReferee, watch: Watch) -> String:
	match referee.mode:
		Defs.VersusMode.GRUB_STACK:
			return "golden" if watch.went_golden else "clock"
		Defs.VersusMode.CLUBBALL:
			if watch.went_golden:
				return "golden"
			return "goals" if maxi(referee.goals_of(1), referee.goals_of(2)) >= VersusTuning.CLUBBALL_GOALS else "clock"
		Defs.VersusMode.LAST_CAVEMAN:
			if referee.cap_at >= 0 and referee.round_ticks >= referee.cap_at:
				return "cap" if not referee.winner_slots.is_empty() else "cap_draw"
	return "standing" if not referee.winner_slots.is_empty() else "draw"
