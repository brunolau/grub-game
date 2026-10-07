extends Node
## Autoload `Autoplay`: scripted-input harness for visual QA (docs/ARCHITECTURE.md 9.2).
##
## Inactive unless the game is started with user arguments (everything after ` -- `):
##
##   --autoplay=<level_id>     load this level and play the input script in it
##   --autoplay-scene=<path>   OR: load any scene (res://...) and only take screenshots
##   --flow=<file>             OR: boot normally and play a flow script (menus, gameplay, checks, screenshots
##                             across scene changes; syntax at the top of scripts/core/dev/autoplay_flow.gd); without
##                             a window: gd.sh script res://scripts/core/dev/headless_flow.gd -- --flow=<file> --fast
##   --inputs=<runs>           run-length input script "ticks:KEYS,ticks:KEYS,..." with KEYS from
##                             L R U D F K S (left right up/jump down fire look swap); "30:" = 30 idle ticks.
##                             Several heroes: one key set per player separated by `|` ("8:R|L,4:|U"; an empty part
##                             = that player idle), see [method parse_inputs_multi]
##   --inputs-file=<path>      the same script read from a text file (commas or new lines; a `# route:` header
##                             may name the number of players)
##   --players=<n>             heroes in the level (1..4; default: as many as the script has streams). More than one
##                             starts a co-op run (a versus run in an arena), Game.start_run
##   --shots=<n>               save a screenshot every n ticks (default 24), plus the first and the last tick
##   --out=<name>              folder under build/screenshots/ (default: the level id or scene name)
##   --difficulty=<name>       beginner (default) or expert
##   --weapon=<name>[,<name>]  club (default, as a new run), hammer, axe, boomerang (the swirling axe) or spear: the
##                             weapon the hero holds when the level starts, for the per-weapon routes
##                             (tools/autoplay/routes/<id>[.expert].<weapon>.inputs); one name per player, in order
##   --record=<file>           record every player's sampled input, tick by tick, of every stage played (also in a
##                             normal game without any other switch: two people play with pads and the file is a
##                             tick-exact route) - see scripts/core/dev/input_recorder.gd
##   --seed=<n>                simulation RNG seed (default 1)
##   --fast                    run one tick per rendered frame instead of real time
##   --hold=<ticks>            idle ticks appended after the script (default 12)
##   --user-dir=<path>         where saves and settings go during the run (default res://build/autoplay_user):
##                             the harness never touches the player's real save
##   --fresh-user              start that folder empty (no save, default settings)
##   --transitions             keep the timed transitions (default: instant)
##   --smoke=<seconds>         boot check: run the game normally for that long (0.1 .. 120), then quit cleanly.
##                             Exit code 0 only when no error and no warning was logged (works with --headless)
##   --perf[=layers]           with --autoplay or --flow: sample frame time, draw calls, tick cost, entity counts,
##                             memory and level load times per screen / level against the budget of
##                             ARCHITECTURE.md 11; prints "Perf:" lines and writes <out>/perf.json
##                             (scripts/core/dev/perf_probe.gd; run windowed, best without screenshots)
##
## Example (run the windowed console binary, NOT --headless, or no image can be captured):
##   godot --path . -- --autoplay=test_example --inputs=40:R,12:RU,30:R,8:F --shots=10
##
## Output: build/screenshots/<out>/tick_00010.png ... and trace.json (hero position per tick; with a party also the
## rows of heroes 2.. under "party"). The run ends when the
## script (plus --hold) is played, or as soon as another stage takes over (a linked sub-stage after a `tally = false`
## exit, a bonus stage behind a warp, the stage after a trophy): the script belongs to the level it was written for,
## and that level's screenshots are never overwritten. A whole chain of stages is played with a flow script.
## Exit code: 0 = finished, 1 = smoke run logged errors or warnings, 2 = bad arguments / unknown level,
## 3 = scene could not be loaded, 4 = a check of a flow script failed.
##
## RELEASE BUILDS. Everything above is a development tool and works only in debug builds (the editor binary and
## debug export templates). A release build ignores those switches completely; the single switch it honours is
## `--smoke`, the boot check of the build scripts: it only shortens the session and reads nothing but the log.
## In an exported build the smoke run also verifies the package itself (no development file inside).
##   ClubAndGrub.exe --log-file smoke.log -- --smoke=3      (exit code 0 = clean boot)

## Emitted when the script has been played completely (just before the application quits).
signal finished(exit_code: int)

const DEFAULT_SHOT_PERIOD: int = 24
## Columns of trace.json: tick, x, y, xvel, yvel, state.
const TRACE_COLUMNS: int = 6
const DEFAULT_HOLD_TICKS: int = 12
const SETTLE_FRAMES: int = 4
## The switches a release build honours; every other one needs a debug build.
const RELEASE_SWITCHES: PackedStringArray = ["smoke"]
const SMOKE_MIN_SECONDS: float = 0.1
const SMOKE_MAX_SECONDS: float = 120.0
## Development files and folders that must never be inside an exported build (export_presets.cfg excludes them).
const DEVELOPMENT_PATHS: PackedStringArray = [
	"res://tests", "res://tools", "res://docs", "res://scenes/core/debug_level.tscn",
	"res://scripts/core/debug_level.gd", "res://levels/test_example.lvl", FLOW_RUNNER, PERF_PROBE, RECORDER,
	HEADLESS_FLOW,
]
## The flow-script runner (development only, excluded from exports with every `dev` folder).
const FLOW_RUNNER: String = "res://scripts/core/dev/autoplay_flow.gd"
## The performance probe of `--perf` (development only, like the flow runner).
const PERF_PROBE: String = "res://scripts/core/dev/perf_probe.gd"
## The input recorder of `--record` (development only, like the flow runner).
const RECORDER: String = "res://scripts/core/dev/input_recorder.gd"
## Boots the main scene without a window, so a `--flow` runs headless (development only, like the flow runner).
const HEADLESS_FLOW: String = "res://scripts/core/dev/headless_flow.gd"
## The first line of a route file that describes itself (docs/LEVEL_DESIGN.md 15.9): `# route: key=value ...`.
const ROUTE_HEADER: String = "# route:"
## The keys a route header may have.
const ROUTE_HEADER_KEYS: PackedStringArray = [
	"level", "difficulty", "players", "ends", "after", "belt", "then", "source", "prefix", "expect", "helper",
]
## The checks a route header's `expect` may name (the route tests implement every one): the 1.0 keys of
## tests/test_campaign_routes.gd ROUTES and the 2.0 keys of docs/LEVEL_DESIGN.md 15.9.
const ROUTE_EXPECT_KEYS: PackedStringArray = [
	"hurts", "max_hurts", "deaths", "respawns", "lives_gained", "weapon_end", "secrets", "min_secrets", "gates",
	"checkpoints", "min_checkpoints", "min_spots", "min_kills", "letters", "words", "ticks", "pair_ticks", "jackpots",
	"min_hearts", "fight_ticks", "min_completion", "min_score", "boss_hits", "unlocked", "glider", "min_wind",
	"view_sank", "embers", "no_enemies", "hero_min_x", "hero_y",
	"painting", "wipes", "eggs", "hatches", "x2_gates",
]
## `expect` keys whose value is a range `low..high` (a single number n means n..n).
const ROUTE_RANGE_KEYS: PackedStringArray = ["ticks", "pair_ticks", "fight_ticks"]
## `expect` keys whose value is a list `a+b+c` (a single number is a list of one).
const ROUTE_LIST_KEYS: PackedStringArray = ["letters", "embers"]
## `expect` keys whose value is `true` or `false`.
const ROUTE_BOOL_KEYS: PackedStringArray = ["unlocked", "glider", "no_enemies"]
## Key letters of an input script, in the order format_inputs() writes them (GameInput.keys_to_flags reads them).
const KEY_LETTERS: Array[Array] = [
	[Defs.IN_LEFT, "L"], [Defs.IN_RIGHT, "R"], [Defs.IN_UP, "U"], [Defs.IN_DOWN, "D"], [Defs.IN_FIRE, "F"],
	[Defs.IN_LOOK, "K"], [Defs.IN_SWAP, "S"],
]
## Saves and settings of harness runs (never the player's real ones).
const DEFAULT_USER_DIR: String = "res://build/autoplay_user"
const USER_FILES: PackedStringArray = ["save.json", "save.json.bak", "save.json.tmp", "settings.cfg"]

## Counts what the engine logs during a smoke run.
class LogCounter:
	extends Logger

	var errors: int = 0
	var warnings: int = 0

	func _log_error(
			_function: String, _file: String, _line: int, _code: String, _rationale: String, _editor_notify: bool,
			error_type: int, _script_backtraces: Array[ScriptBacktrace]
	) -> void:
		if error_type == Logger.ERROR_TYPE_WARNING:
			warnings += 1
		else:
			errors += 1

	func _log_message(_message: String, _error: bool) -> void:
		pass


## True when this run is driven by the harness.
var active: bool = false
## True when a flow script drives the run: the game boots and runs normally (title screen included); the script
## plays the input.
var flow_mode: bool = false

var _level_id: StringName = &""
var _scene_path: String = ""
var _flags: PackedInt32Array = PackedInt32Array()
## One input stream per player slot (`_flags` is the first); all of the same length.
var _streams: Array[PackedInt32Array] = []
## Heroes of the scripted run (--players, or the streams of the script).
var _players: int = 1
## The weapon of every slot (--weapon=<name>[,<name>...]); slot 0 is `_weapon`.
var _weapons: PackedInt32Array = PackedInt32Array()
## Rows of heroes 2.. per tick when a party plays: tick, slot, x, y, xvel, yvel, state.
var _party_trace: PackedInt32Array = PackedInt32Array()
var _shot_period: int = DEFAULT_SHOT_PERIOD
var _out_dir: String = ""
var _fast: bool = false
var _seed: int = 1
var _difficulty: int = Defs.Difficulty.BEGINNER
var _weapon: int = Defs.Weapon.CLUB
## Trace rows, TRACE_COLUMNS ints per tick (packed: no allocation inside the measured tick).
var _trace: PackedInt32Array = PackedInt32Array()
var _shots_saved: int = 0
var _done: bool = false
var _can_capture: bool = true
## Instance id of the stage the script plays in (the run ends when another one takes over; an id, because a freed
## level compares equal to null).
var _stage: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)
	var requested: Dictionary = parse_args(OS.get_cmdline_user_args())
	var options: Dictionary = allowed_options(requested, OS.is_debug_build())
	var driven: bool = requested.has("autoplay") or requested.has("autoplay-scene") or requested.has("flow")
	if requested.size() != options.size() and driven:
		print("Autoplay: development switches are ignored by release builds")
	if options.has("smoke"):
		_smoke(clampf(str(options["smoke"]).to_float(), SMOKE_MIN_SECONDS, SMOKE_MAX_SECONDS))
		return
	if options.has("record"):
		# Also without any other switch: the game runs normally and every stage played is recorded.
		_start_recorder(str(options["record"]))
	if not options.has("autoplay") and not options.has("autoplay-scene") and not options.has("flow"):
		return
	active = true
	flow_mode = options.has("flow")
	# The harness window rarely has the focus (several runs share one desktop): never pause for that.
	Flow.pause_on_focus_loss = false
	_configure(options)
	_redirect_user_data(str(options.get("user-dir", DEFAULT_USER_DIR)), options.has("fresh-user"))
	if options.has("perf"):
		_start_perf(str(options["perf"]))
	if flow_mode:
		_start_flow(str(options["flow"]))
		return
	# Start after the main scene finished its own _ready.
	_run.call_deferred()


## The options this build may act on: all of them in a debug build, only RELEASE_SWITCHES in a release build,
## so that no development switch can change what a player's copy of the game does.
func allowed_options(options: Dictionary, debug_build: bool) -> Dictionary:
	if debug_build:
		return options
	var result: Dictionary = {}
	for key: String in RELEASE_SWITCHES:
		if options.has(key):
			result[key] = options[key]
	return result


## Development files found in this build (paths of DEVELOPMENT_PATHS that exist, plus test levels). Empty for
## a correct export; meaningless in the editor, where all of them exist.
func find_development_files() -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	for path: String in DEVELOPMENT_PATHS:
		if FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(path) or ResourceLoader.exists(path):
			found.append(path)
	for id: StringName in Levels.all_ids():
		if String(id).begins_with("test_") and not found.has(Levels.get_level_path(id)):
			found.append(Levels.get_level_path(id))
	return found


## Parse "--key=value" / "--flag" arguments into a Dictionary (keys without the dashes; flags map to "").
func parse_args(arguments: PackedStringArray) -> Dictionary:
	var options: Dictionary = {}
	for argument: String in arguments:
		if not argument.begins_with("--"):
			continue
		var body: String = argument.substr(2)
		var eq: int = body.find("=")
		if eq < 0:
			options[body] = ""
		else:
			options[body.substr(0, eq)] = body.substr(eq + 1)
	return options


## Convert an input script "40:R,12:RU,8:" into one flags value (Defs.IN_*) per tick.
## Entries are separated by commas or new lines; a missing key part means "nothing held". A line whose first
## non-blank character is `#` is a comment (it may contain commas).
func parse_inputs(script: String) -> PackedInt32Array:
	var result: PackedInt32Array = PackedInt32Array()
	var entries: PackedStringArray = PackedStringArray()
	for line: String in script.split("\n"):
		if not line.strip_edges().begins_with("#"):
			entries.append_array(line.split(",", false))
	for entry: String in entries:
		var item: String = entry.strip_edges()
		if item.is_empty():
			continue
		var colon: int = item.find(":")
		var count_text: String = item if colon < 0 else item.substr(0, colon)
		var keys: String = "" if colon < 0 else item.substr(colon + 1).strip_edges().to_upper()
		if not count_text.strip_edges().is_valid_int():
			push_error("Autoplay: bad input entry '%s' (expected ticks:KEYS)" % item)
			continue
		var value: int = GameInput.keys_to_flags(keys)
		for i: int in count_text.strip_edges().to_int():
			result.append(value)
	return result


# =================================================================================================================
# 2.0: several input streams, route headers, writing scripts (docs/expansion/TECH_AUDIT.md 4.11)
# =================================================================================================================

## Convert an input script for several heroes into one flags array per player slot (index = slot). Entries are
## `ticks:KEYS|KEYS|...`: one key set per player separated by `|`, an empty or missing part = that player idle
## (`8:R|R,10:RU|,4:DF|DF`). The number of streams is [method input_players]. A script without `|` and without a
## players header is a single-player route: the result is [parse_inputs(script)], exactly the 1.0 parse. Every
## stream has the same length; separators and `#` comment lines as in [method parse_inputs].
func parse_inputs_multi(script: String) -> Array[PackedInt32Array]:
	var players: int = input_players(script)
	var entries: PackedStringArray = _script_entries(script)
	if players <= 1 and not "".join(entries).contains("|"):
		return [parse_inputs(script)] as Array[PackedInt32Array]
	var streams: Array[PackedInt32Array] = []
	for slot: int in players:
		streams.append(PackedInt32Array())
	for entry: String in entries:
		var item: String = entry.strip_edges()
		if item.is_empty():
			continue
		var colon: int = item.find(":")
		var count_text: String = (item if colon < 0 else item.substr(0, colon)).strip_edges()
		if not count_text.is_valid_int():
			push_error("Autoplay: bad input entry '%s' (expected ticks:KEYS|KEYS)" % item)
			continue
		var parts: PackedStringArray = PackedStringArray() if colon < 0 else item.substr(colon + 1).split("|")
		if parts.size() > players:
			push_error("Autoplay: input entry '%s' has %d parts for %d player(s)" % [item, parts.size(), players])
			continue
		var count: int = count_text.to_int()
		for slot: int in players:
			var keys: String = parts[slot].strip_edges().to_upper() if slot < parts.size() else ""
			var value: int = GameInput.keys_to_flags(keys)
			for i: int in count:
				streams[slot].append(value)
	return streams


## How many input streams (heroes) a script holds: the `players` of its `# route:` header, or of a `# players: <n>`
## comment, else the most `|`-separated parts any entry has (1 for every 1.0 script).
func input_players(script: String) -> int:
	var header: Dictionary = parse_route_header(script)
	if header.has("players") and int(header["players"]) > 0:
		return int(header["players"])
	var players: int = 0
	var most: int = 1
	for line: String in script.split("\n"):
		var text: String = line.strip_edges()
		if text.begins_with("#"):
			var body: String = text.substr(1).strip_edges()
			if players == 0 and body.begins_with("players:"):
				var value: String = body.substr(8).strip_edges().get_slice(" ", 0)
				if value.is_valid_int():
					players = clampi(value.to_int(), 1, Defs.MAX_PLAYERS)
			continue
		for entry: String in text.split(",", false):
			most = maxi(most, entry.split("|").size())
	return players if players > 0 else most


## The `# route:` header of a route file (docs/LEVEL_DESIGN.md 15.9), as an entry shaped like the ROUTES entries of
## tests/test_campaign_routes.gd: "level", "modes" (["beginner"], ["expert"] or both), "players" (1..4), "leaves"
## ("exit", "warp", "trophy"; "" for `ends=none`), "after" ("tally" or "level:<id>"; `expert_wall` and `the_end`
## become "after": "tally" plus "tally_to" {mode: value}), "belt" (Defs.Weapon on the belt at the start,
## PlayerRun.BELT_EMPTY for none), "then", "source", "prefix" ([route file, marker]), "helper" (true for `helper=1`:
## a co-op route recorded in Helper mode, DESIGN.md D.3) and "expect" (key -> int, bool,
## [low, high] for ROUTE_RANGE_KEYS, [a, b, ...] for ROUTE_LIST_KEYS, a weapon name -> Defs.Weapon). Also
## "header": true and "errors": PackedStringArray (empty for a valid header). The header is the first non-blank line
## of `text`; a text without one gives {} (a 1.0 route, described by the ROUTES table).
func parse_route_header(text: String) -> Dictionary:
	var line: String = ""
	for raw: String in text.split("\n"):
		line = raw.strip_edges()
		if not line.is_empty():
			break
	if not line.begins_with(ROUTE_HEADER):
		return {}
	var errors: PackedStringArray = PackedStringArray()
	var spec: Dictionary = {"header": true, "players": 1, "belt": PlayerRun.BELT_EMPTY, "expect": {}}
	for token: String in line.substr(ROUTE_HEADER.length()).replace("\t", " ").split(" ", false):
		var eq: int = token.find("=")
		var key: String = token if eq < 0 else token.substr(0, eq)
		var value: String = "" if eq < 0 else token.substr(eq + 1)
		if not ROUTE_HEADER_KEYS.has(key) or value.is_empty():
			errors.append("'%s' is not key=value with a key of %s" % [token, ", ".join(ROUTE_HEADER_KEYS)])
			continue
		match key:
			"level", "source":
				spec[key] = value
			"difficulty":
				match value:
					"beginner", "expert":
						spec["modes"] = [value]
					"both":
						spec["modes"] = ["beginner", "expert"]
					_:
						errors.append("difficulty=%s (beginner, expert or both)" % value)
			"players":
				if value.is_valid_int() and value.to_int() >= 1 and value.to_int() <= Defs.MAX_PLAYERS:
					spec["players"] = value.to_int()
				else:
					errors.append("players=%s (1..%d)" % [value, Defs.MAX_PLAYERS])
			"ends":
				if ["exit", "warp", "trophy", "none"].has(value):
					spec["leaves"] = "" if value == "none" else value
				else:
					errors.append("ends=%s (exit, warp, trophy or none)" % value)
			"after":
				if value == "tally" or (value.begins_with("level:") and value.length() > 6):
					spec["after"] = value
				elif value == "expert_wall" or value == "the_end":
					spec["after"] = "tally"
					spec["tally_to"] = {"beginner": value, "expert": value}
				else:
					errors.append("after=%s (tally, level:<id>, expert_wall or the_end)" % value)
			"belt":
				var weapon: int = _weapon_from_name(value)
				if value == "none":
					spec["belt"] = PlayerRun.BELT_EMPTY
				elif weapon > Defs.Weapon.CLUB:
					spec["belt"] = weapon
				else:
					errors.append("belt=%s (none, hammer, axe, boomerang or spear)" % value)
			"then":
				spec["then"] = value
			"prefix":
				var at: int = value.rfind("@")
				if at > 0 and at < value.length() - 1:
					spec["prefix"] = [value.substr(0, at), value.substr(at + 1)]
				else:
					errors.append("prefix=%s (<route file>@<marker>)" % value)
			"expect":
				spec["expect"] = _parse_expect(value, errors)
			"helper":
				# Helper mode of a co-op route (DESIGN.md D.3; Game.helper_mode after Game.start_run).
				if value == "1" or value == "0":
					spec["helper"] = value == "1"
				else:
					errors.append("helper=%s (0 or 1)" % value)
	for required: String in ["level", "modes", "leaves"]:
		if not spec.has(required):
			errors.append("no %s" % {"level": "level=", "modes": "difficulty=", "leaves": "ends="}[required])
	spec["errors"] = errors
	return spec


## Keys of a flags value (Defs.IN_*), in the order L R U D F K S: flags_to_keys(Defs.IN_RIGHT | Defs.IN_UP) == "RU".
func flags_to_keys(flags: int) -> String:
	var keys: String = ""
	for pair: Array in KEY_LETTERS:
		if flags & int(pair[0]):
			keys += str(pair[1])
	return keys


## Write input streams (one per player slot) as a run-length script that [method parse_inputs_multi] reads back
## unchanged: one stream gives the 1.0 format (`ticks:KEYS`), several give `ticks:KEYS|KEYS|...`. `header_lines`
## come first (e.g. a `# route:` header); entries are comma-separated, about 100 characters per line.
func format_inputs(streams: Array[PackedInt32Array], header_lines: PackedStringArray = PackedStringArray()) -> String:
	var lines: PackedStringArray = header_lines.duplicate()
	var length: int = streams[0].size() if not streams.is_empty() else 0
	var entries: PackedStringArray = PackedStringArray()
	var width: int = 0
	var start: int = 0
	while start < length:
		var end: int = start + 1
		while end < length and _same_tick(streams, start, end):
			end += 1
		var parts: PackedStringArray = PackedStringArray()
		for stream: PackedInt32Array in streams:
			parts.append(flags_to_keys(stream[start]))
		var entry: String = "%d:%s" % [end - start, "|".join(parts)]
		if width + entry.length() > 100 and not entries.is_empty():
			lines.append(",".join(entries))
			entries.clear()
			width = 0
		entries.append(entry)
		width += entry.length() + 1
		start = end
	if not entries.is_empty():
		lines.append(",".join(entries))
	return "\n".join(lines) + "\n"


# True when every stream holds the same flags on ticks `a` and `b`.
func _same_tick(streams: Array[PackedInt32Array], a: int, b: int) -> bool:
	for stream: PackedInt32Array in streams:
		if stream[a] != stream[b]:
			return false
	return true


# The entries of an input script: commas or new lines; `#` lines are comments.
func _script_entries(script: String) -> PackedStringArray:
	var entries: PackedStringArray = PackedStringArray()
	for line: String in script.split("\n"):
		if not line.strip_edges().begins_with("#"):
			entries.append_array(line.split(",", false))
	return entries


# The `expect=` value of a route header: comma-separated key:value checks.
func _parse_expect(text: String, errors: PackedStringArray) -> Dictionary:
	var expect: Dictionary = {}
	for item: String in text.split(",", false):
		var colon: int = item.find(":")
		var key: String = item if colon < 0 else item.substr(0, colon)
		var value: String = "" if colon < 0 else item.substr(colon + 1)
		if not ROUTE_EXPECT_KEYS.has(key) or value.is_empty():
			errors.append("expect '%s' is not key:value with a known key" % item)
			continue
		if ROUTE_BOOL_KEYS.has(key):
			if value == "true" or value == "false":
				expect[key] = value == "true"
			else:
				errors.append("expect %s:%s (true or false)" % [key, value])
		elif ROUTE_RANGE_KEYS.has(key):
			var bounds: PackedStringArray = value.split("..") if value.contains("..") else PackedStringArray([value, value])
			if bounds.size() == 2 and bounds[0].is_valid_int() and bounds[1].is_valid_int():
				expect[key] = [bounds[0].to_int(), bounds[1].to_int()]
			else:
				errors.append("expect %s:%s (<low>..<high>)" % [key, value])
		elif ROUTE_LIST_KEYS.has(key):
			var values: Array[int] = []
			for part: String in value.split("+"):
				if part.is_valid_int():
					values.append(part.to_int())
				else:
					errors.append("expect %s:%s (numbers joined by +)" % [key, value])
					break
			expect[key] = values
		elif key == "weapon_end" and _weapon_from_name(value) >= 0:
			expect[key] = _weapon_from_name(value)
		elif value.is_valid_int():
			expect[key] = value.to_int()
		else:
			errors.append("expect %s:%s (a number)" % [key, value])
	return expect


# Defs.Weapon of a weapon name (Defs.weapon_name), -1 for an unknown one.
func _weapon_from_name(weapon_name: String) -> int:
	for weapon: int in Defs.Weapon.values():
		if Defs.weapon_name(weapon) == weapon_name.to_lower():
			return weapon
	return -1


func _smoke(seconds: float) -> void:
	var counter: LogCounter = LogCounter.new()
	OS.add_logger(counter)
	if OS.has_feature("template"):
		for path: String in find_development_files():
			push_error("Smoke: development file %s is inside this export" % path)
	await get_tree().create_timer(seconds, true, false, true).timeout
	OS.remove_logger(counter)
	print("Smoke: %s %s (%s build), %d level(s), screen '%s'" % [
		ProjectSettings.get_setting("application/config/name"),
		ProjectSettings.get_setting("application/config/version"),
		"debug" if OS.is_debug_build() else "release", Levels.all_ids().size(), Flow.current_screen,
	])
	var ids: PackedStringArray = PackedStringArray()
	for id: StringName in Levels.all_ids():
		ids.append(String(id))
	print("Smoke: levels %s" % ",".join(ids))
	print("Smoke: campaign beginner %s; expert %s" % [
		",".join(PackedStringArray(Levels.get_campaign(Defs.Difficulty.BEGINNER))),
		",".join(PackedStringArray(Levels.get_campaign(Defs.Difficulty.EXPERT)))])
	print("Smoke: ran %.1f s, %d error(s), %d warning(s) logged" % [seconds, counter.errors, counter.warnings])
	Flow.shutdown_and_quit(0 if counter.errors + counter.warnings == 0 else 1)


func _configure(options: Dictionary) -> void:
	_level_id = StringName(str(options.get("autoplay", "")))
	_scene_path = str(options.get("autoplay-scene", ""))
	var script: String = str(options.get("inputs", ""))
	if options.has("inputs-file"):
		script = FileAccess.get_file_as_string(str(options["inputs-file"]))
	_streams = parse_inputs_multi(script)
	_players = clampi(maxi(str(options.get("players", "0")).to_int(), _streams.size()), 1, Defs.MAX_PLAYERS)
	while _streams.size() < _players:
		_streams.append(PackedInt32Array())
	var length: int = 0
	for stream: PackedInt32Array in _streams:
		length = maxi(length, stream.size())
	var hold: int = str(options.get("hold", str(DEFAULT_HOLD_TICKS))).to_int()
	for stream: PackedInt32Array in _streams:
		stream.resize(length + maxi(hold, 0))  # an added player idles; the hold ticks are idle
	_flags = _streams[0]
	_shot_period = maxi(str(options.get("shots", str(DEFAULT_SHOT_PERIOD))).to_int(), 1)
	_seed = str(options.get("seed", "1")).to_int()
	_fast = options.has("fast")
	if str(options.get("difficulty", "beginner")) == "expert":
		_difficulty = Defs.Difficulty.EXPERT
	_weapons.resize(_players)
	_weapons.fill(Defs.Weapon.CLUB)
	if options.has("weapon"):
		var names: PackedStringArray = str(options["weapon"]).split(",")
		for slot: int in mini(names.size(), _players):
			var weapon: int = _weapon_from_name(names[slot].strip_edges())
			if weapon < 0:
				push_error("Autoplay: unknown weapon '%s' (club, hammer, axe, boomerang, spear)" % names[slot])
			else:
				_weapons[slot] = weapon
		_weapon = _weapons[0]
	var out_name: String = str(options.get("out", ""))
	if out_name.is_empty() and options.has("flow"):
		out_name = str(options["flow"]).get_file().get_basename()
	if out_name.is_empty():
		out_name = String(_level_id) if _level_id != &"" else _scene_path.get_file().get_basename()
	var root: String = "res://build/screenshots/" if OS.has_feature("editor") else "user://screenshots/"
	_out_dir = ProjectSettings.globalize_path(root + out_name.validate_filename())
	_can_capture = DisplayServer.get_name() != "headless"
	Flow.instant_transitions = not options.has("transitions")


## Saves and settings of this run go to `dir_path` (the player's real ones are never touched); `fresh` empties it.
func _redirect_user_data(dir_path: String, fresh: bool) -> void:
	var absolute: String = ProjectSettings.globalize_path(dir_path)
	DirAccess.make_dir_recursive_absolute(absolute)
	if fresh:
		for file: String in USER_FILES:
			if FileAccess.file_exists(absolute + "/" + file):
				DirAccess.remove_absolute(absolute + "/" + file)
	Settings.set_storage_dir(dir_path)
	Save.set_storage_dir(dir_path)
	print("Autoplay: user data in %s" % absolute)


## Attach the performance probe (debug builds only; it is not exported). It must connect to the simulation
## signals before the flow runner does, so that its tick timing sees the tick and nothing else.
func _start_perf(mode: String) -> void:
	DirAccess.make_dir_recursive_absolute(_out_dir)
	var probe_script: GDScript = load(PERF_PROBE) as GDScript if ResourceLoader.exists(PERF_PROBE) else null
	if probe_script == null:
		push_error("Autoplay: the performance probe %s is missing" % PERF_PROBE)
		return
	var probe: Node = probe_script.new() as Node
	probe.name = "PerfProbe"
	add_child(probe)
	probe.call("begin", _out_dir, mode)


## Attach the input recorder of `--record` (debug builds only; it is not exported).
func _start_recorder(path: String) -> void:
	var recorder_script: GDScript = load(RECORDER) as GDScript if ResourceLoader.exists(RECORDER) else null
	if recorder_script == null:
		push_error("Autoplay: the input recorder %s is missing" % RECORDER)
		return
	var recorder: Node = recorder_script.new() as Node
	recorder.name = "InputRecorder"
	add_child(recorder)
	var target: String = path if path.begins_with("res://") or path.begins_with("user://") or path.is_absolute_path() \
			else "res://" + path
	recorder.call("begin", target)


## Hand the run to the flow-script runner (debug builds only; the runner is not exported).
func _start_flow(path: String) -> void:
	DirAccess.make_dir_recursive_absolute(_out_dir)
	var script_path: String = path if path.begins_with("res://") or path.is_absolute_path() else "res://" + path
	var text: String = FileAccess.get_file_as_string(script_path)
	var runner_script: GDScript = load(FLOW_RUNNER) as GDScript if ResourceLoader.exists(FLOW_RUNNER) else null
	if text.is_empty() or runner_script == null:
		push_error("Autoplay: cannot read flow script '%s' (or the runner is missing)" % script_path)
		_finish.call_deferred(2)
		return
	print("Autoplay: output folder %s" % _out_dir)
	var runner: Node = runner_script.new() as Node
	runner.name = "FlowRunner"
	add_child(runner)
	runner.call("begin", text, _out_dir, _fast, _can_capture)


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(_out_dir)
	print("Autoplay: output folder %s" % _out_dir)
	if not _can_capture:
		print("Autoplay: headless display, screenshots are skipped (trace.json is still written)")
	if _scene_path != "":
		if not ResourceLoader.exists(_scene_path):
			push_error("Autoplay: scene '%s' does not exist" % _scene_path)
			_finish(3)
			return
		get_tree().change_scene_to_file(_scene_path)
	else:
		if not Levels.has_level(_level_id):
			push_error("Autoplay: unknown level '%s' (known: %s)" % [_level_id, str(Levels.all_ids())])
			_finish(2)
			return
		var book: int = maxi(Levels.get_book(_level_id), 1)
		if _players > 1 or book > 1:
			var mode: int = Defs.GameMode.VERSUS if Levels.is_arena(_level_id) else Defs.GameMode.COOP
			Game.start_run(_difficulty, mode if _players > 1 else Defs.GameMode.SINGLE, _players, book)
		else:
			Game.new_game(_difficulty)
		Game.set_weapon(_weapon)
		for slot: int in range(1, _players):
			Game.runs[slot].set_weapon(_weapons[slot])
		# The clock waits for the script's first tick: ticks run in real time while the level settles would put
		# the level's own clock (wind script, enemies) ahead of the script, unlike the route tests and flow scripts.
		Sim.manual = true
		Flow.start_level(_level_id, Defs.Transition.NONE)
		await Flow.transition_finished
	for i: int in SETTLE_FRAMES:
		await get_tree().process_frame
	_stage = Game.level.get_instance_id() if Game.level != null else 0
	GameInput.set_scripted(_flags_for_tick)
	for slot: int in range(1, _players):
		GameInput.set_scripted_slot(slot, _flags_for_slot.bind(slot))
	Sim.tick_finished.connect(_on_tick_finished)
	if not Sim.running:
		Sim.start(_seed)
	else:
		Sim.rng.reseed(_seed)
		Sim.tick = 0
	Sim.manual = _fast
	await _capture(0)
	set_process(true)


func _process(_delta: float) -> void:
	if _done:
		return
	if _fast:
		Sim.step(1)


func _flags_for_tick(tick: int) -> int:
	if _left_stage():
		return 0
	var index: int = tick - 1
	if index < 0 or index >= _flags.size():
		return 0
	return _flags[index]


# The script of player slot `slot` (1..), tick for tick like _flags_for_tick.
func _flags_for_slot(tick: int, slot: int) -> int:
	if _left_stage() or slot >= _streams.size():
		return 0
	var index: int = tick - 1
	if index < 0 or index >= _streams[slot].size():
		return 0
	return _streams[slot][index]


func _on_tick_finished(tick: int) -> void:
	if _done:
		return
	if _left_stage():
		# Another stage took over (its clock starts again at tick 0): stop before it plays this script again.
		_done = true
		Sim.manual = true
		print("Autoplay: %s took over after %d ticks of %s; stopping" % [Game.level.level_id, _trace_rows(),
				_level_id])
		_write_trace()
		print("Autoplay: %d ticks played, %d screenshots saved" % [_trace_rows(), _shots_saved])
		_finish(0)
		return
	var level: LevelBase = Game.level
	if level != null and level.player != null:
		var hero: PlayerBase = level.player
		_trace.append(tick)
		_trace.append(hero.sim_pos.x)
		_trace.append(hero.sim_pos.y)
		_trace.append(hero.xvel)
		_trace.append(hero.yvel)
		_trace.append(hero.state)
		for slot: int in range(1, level.hero_count()):
			var other: PlayerBase = level.get_hero(slot)
			if other != null:
				_party_trace.append_array([tick, slot, other.sim_pos.x, other.sim_pos.y, other.xvel, other.yvel,
						other.state])
	var last: bool = tick >= _flags.size()
	if last:
		_done = true
		Sim.manual = true
	if last or tick % _shot_period == 0:
		_capture_then(tick, last)


## True when a stage other than the scripted one is running (a scene-only run never leaves).
func _left_stage() -> bool:
	return _stage != 0 and is_instance_valid(Game.level) and Game.level.get_instance_id() != _stage


func _capture_then(tick: int, last: bool) -> void:
	await _capture(tick)
	if last:
		_write_trace()
		print("Autoplay: %d ticks played, %d screenshots saved" % [tick, _shots_saved])
		_finish(0)


func _capture(tick: int) -> void:
	if not _can_capture:
		return
	await RenderingServer.frame_post_draw
	var texture: ViewportTexture = get_viewport().get_texture()
	var image: Image = texture.get_image() if texture != null else null
	if image == null or image.is_empty():
		push_warning("Autoplay: could not capture tick %d" % tick)
		return
	var path: String = "%s/tick_%05d.png" % [_out_dir, tick]
	var err: Error = image.save_png(path)
	if err != OK:
		push_error("Autoplay: cannot write %s (error %d)" % [path, err])
		return
	_shots_saved += 1


func _trace_rows() -> int:
	return _trace.size() / TRACE_COLUMNS


func _write_trace() -> void:
	var file: FileAccess = FileAccess.open(_out_dir + "/trace.json", FileAccess.WRITE)
	if file == null:
		return
	var rows: Array[Array] = []
	for i: int in _trace_rows():
		rows.append(Array(_trace.slice(i * TRACE_COLUMNS, (i + 1) * TRACE_COLUMNS)))
	var trace: Dictionary = {
		"level": String(_level_id),
		"scene": _scene_path,
		"seed": _seed,
		"ticks": _flags.size(),
		"columns": ["tick", "x", "y", "xvel", "yvel", "state"],
		"rows": rows,
	}
	if _players > 1:
		var party: Array[Array] = []
		for i: int in _party_trace.size() / 7:
			party.append(Array(_party_trace.slice(i * 7, (i + 1) * 7)))
		trace["players"] = _players
		trace["party_columns"] = ["tick", "slot", "x", "y", "xvel", "yvel", "state"]
		trace["party"] = party
	file.store_string(JSON.stringify(trace))
	file.close()


func _finish(exit_code: int) -> void:
	_done = true
	GameInput.clear_scripted()
	finished.emit(exit_code)
	Flow.shutdown_and_quit(exit_code)
