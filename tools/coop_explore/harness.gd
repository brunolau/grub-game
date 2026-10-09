extends RefCounted
## CONTINUOUS PLAY on the solo search's own world (docs/expansion/DESIGN.md R7 / G71+, LEVEL_DESIGN.md 15.7.6; the
## G3b verifier's attack_lib.gd, adopted by world-B in wf11). Owner: world-B (PLAN.md 4.1, tools/coop_explore/).
##
## One hero in CoopSearch.Searcher's world of a co-op gate - the real hero, the file's entities, a co-op game of two
## with the partner an egg or an idle hatched hero parked where the hero stands. One run = one EXACT reset of the
## world ([method begin]: CoopSearch.Searcher.reset_world - the state a fresh process builds, the clocks at zero), then
## inputs decided tick by tick by the caller ([method step]); nothing is reset in between, everything carries
## (momentum, woken and led enemies, doors, clocks). The far cell of the gate's tablet is the goal, as in the search.
## The explorer (explorer.gd), the replay (replay.gd) and the gate test's evidence check drive it.
##
## A ROUTE FILE (tools/coop_explore/evidence/*.txt, an explorer's found_*.txt) is three lines:
##   level=<id> gate=<name> difficulty=<0|1> whole=<true|false> start=<index into the gate's starts> tick0=<n>
##       [real=true] ...     (tick0: Sim.tick at the start of the run - a route is replayed on the clock it was found
##       on; "-", as the G3b verifier's files have it, is 0: his world began on the fresh process's tick)
##   events=[[tick, "hand", weapon], [tick, "place", 0], ...]     (the special in his hand, the idle partner parked)
##   route=<ticks>:<keys>,...                                     (L R U D F S, run-length)
## `whole`: the world holds the entities of the whole level, not only of the gate's columns; `real`: the route was
## played in the real game (real_harness.gd), not in the search world.

const NOWHERE: Vector2i = Vector2i(-1, -1)
const EVIDENCE_DIR: String = "res://tools/coop_explore/evidence"
## Where the results of explorer passes and evidence replays are kept for the gate test (build/ is not versioned).
const CACHE_DIR: String = "res://build/coop_explore_cache"
## Part of every result key: raise it when a result's meaning changes without a change of these scripts.
const VERSION: String = "x1.0"
## R7 (c): two seeded passes of PASS_SECONDS per gate row over the whole level. The seed of a row in pass p is
## PASS_SEEDS[p] plus a number from the row's own name ([method row_seed]), so a row keeps its seeds when the gate
## table changes.
const PASS_SEEDS: Array[int] = [1000, 2000]
const PASS_SECONDS: int = 300
## The scripts whose text is part of a result's key (the explorer's own moves and this harness).
const KEY_SCRIPTS: Array[String] = [
	"res://tools/coop_explore/harness.gd", "res://tools/coop_explore/explorer.gd",
]

var s: CoopSearch.Searcher = null
var data: LevelData = null
var difficulty: int = 0
var gate: String = ""
var far: Vector2i = NOWHERE
var tablet: Dictionary = {}
var grid: TileGrid = null
var starts: Array[Vector2i] = []
var area: Rect2i = Rect2i()
var whole: bool = false
var t: int = 0
var hurts: int = 0
var bounces: int = 0
var min_y: int = 1 << 30
var _hurt_cb: Callable
var _bounce_cb: Callable


## Build the world of `gate_name` of `level_id`: the gate's columns as the search takes them, or the WHOLE level.
## `tick0` is Sim.tick at the start of every run (-1: the search world's own, CoopSearch.TICK_BASE; a route file
## names the base it was recorded on).
func build(level_id: StringName, gate_name: String, p_difficulty: int, p_whole: bool, tick0: int = -1) -> bool:
	return build_data(LevelData.load_file(CoopSearch.level_path(level_id)), gate_name, p_difficulty, p_whole, tick0)


## [method build] on a level parsed already (tests).
func build_data(level_data: LevelData, gate_name: String, p_difficulty: int, p_whole: bool, tick0: int = -1) -> bool:
	data = level_data
	if data == null:
		return false
	difficulty = p_difficulty
	gate = gate_name
	whole = p_whole
	tablet = CoopSearch.find_tablet(data, difficulty, gate)
	if tablet.is_empty():
		return false
	far = tablet["far"]
	grid = CoopSearch.grid_at_rest(data, difficulty)
	area = CoopSearch.gate_area(tablet, grid)
	starts = CoopSearch.start_points(data, difficulty, tablet, grid)
	var columns: Vector2i = Vector2i(0, grid.cols) if whole else CoopSearch.world_columns_of(area, starts, grid)
	s = CoopSearch.Searcher.new()
	if tick0 >= 0:
		s.tick_base = tick0
	if not s.build_world(data, difficulty, CoopSearch.grid_at_rest(data, difficulty), columns):
		return false
	_hurt_cb = func(hero: PlayerBase, _kind: int, _source: SimEntity) -> void:
		if s != null and hero == s.hero:
			hurts += 1
	_bounce_cb = func(hero: PlayerBase, _target: SimEntity, _multiplier: int) -> void:
		if s != null and hero == s.hero:
			bounces += 1
	Events.hero_hurt.connect(_hurt_cb)
	Events.hero_bounced.connect(_bounce_cb)
	return true


func close() -> void:
	if s != null:
		Events.hero_hurt.disconnect(_hurt_cb)
		Events.hero_bounced.disconnect(_bounce_cb)
		s.close()
		s = null


## A fresh run: the world reset exactly to the level file, the hero at `start` (feet point, px), the partner an egg
## behind him (or idle at `partner_at`), `hand` the special he holds (-1: the club).
func begin(start: Vector2i, facing: int = 1, hand: int = -1, partner_at: Vector2i = NOWHERE) -> void:
	var config: Dictionary = s._config(start, facing, hand, CoopSearch.PARTNER_EGG, partner_at)
	s._begin(config)
	s._flags = PackedInt32Array()
	t = 0
	hurts = 0
	bounces = 0
	min_y = 1 << 30


## Play one tick with `flag`. "" = on; "goal" = his feet point is in the far cell; "dead" = he died or went down.
func step(flag: int) -> String:
	s._flags.append(flag)
	Sim.step(1)
	t += 1
	s.simulated += 1
	var hero: PlayerBase = s.hero
	if hero.dead or hero.is_down():
		return "dead"
	min_y = mini(min_y, hero.sim_pos.y)
	var cell: Vector2i = Vector2i(Tuning.to_cell(hero.sim_pos.x), Tuning.to_cell(hero.sim_pos.y - 1))
	if cell == far:
		return "goal"
	return ""


## Park the idle hatched partner where the hero stands (the search's `place` event: the egg clubbed open there).
func place_partner() -> void:
	s._place_idle(s.hero.sim_pos, s.hero.facing)


## The special in his hand from now on (-1: the club), as the search's `hand` event.
func set_hand(hand: int) -> void:
	s._set_hand(hand)


func hero() -> PlayerBase:
	return s.hero


## A number that two runs of the same inputs from the same reset share on every tick: the hero (place, speed, state,
## energy) and every entity of the world (place, speed, the search's signature part) - what "a replay came back to
## its state" is checked with.
func world_hash() -> int:
	var hero: PlayerBase = s.hero
	var parts: Array = [hero.sim_pos, hero.xvel, hero.yvel, hero.state, hero.facing, hero.run.hearts, hero.run.bones,
		s.partner.sim_pos, s.partner.is_down()]
	for i: int in s._entities.size():
		var entity: SimEntity = s.entity_at(i)
		if entity == null:
			parts.append(-1)
			continue
		parts.append(entity.sim_pos)
		parts.append(entity.xvel)
		parts.append(entity.yvel)
		if entity is EnemyBase:
			parts.append((entity as EnemyBase).hp)
			parts.append((entity as EnemyBase).awake)
			parts.append((entity as EnemyBase).dead)
	parts.append(s.level.get_child_count())
	parts.append(Sim.rng.get_state())
	return parts.hash()


## The world entity of the record whose id contains `id_part` at cell (col, row); null when there is none.
func entity(id_part: String, col: int, row: int) -> SimEntity:
	for i: int in s._records.size():
		var record: Dictionary = s._records[i]
		if String(record["id"]).contains(id_part) and int(record["col"]) == col and int(record["row"]) == row:
			return s.entity_at(i)
	return null


## Every world entity whose record id contains `id_part`: [[record, entity], ...].
func entities(id_part: String) -> Array:
	var found: Array = []
	for i: int in s._records.size():
		if String(s._records[i]["id"]).contains(id_part) and s.entity_at(i) != null:
			found.append([s._records[i], s.entity_at(i)])
	return found


## The flags played so far as a route text (run-length, one stream).
func route_text() -> String:
	return flags_text(s._flags)


static func flags_text(flags: PackedInt32Array) -> String:
	var parts: PackedStringArray = PackedStringArray()
	var i: int = 0
	while i < flags.size():
		var j: int = i
		while j < flags.size() and flags[j] == flags[i]:
			j += 1
		parts.append("%d:%s" % [j - i, keys(flags[i])])
		i = j
	return ",".join(parts)


static func keys(flags: int) -> String:
	var text: String = ""
	if flags & Defs.IN_LEFT:
		text += "L"
	if flags & Defs.IN_RIGHT:
		text += "R"
	if flags & Defs.IN_UP:
		text += "U"
	if flags & Defs.IN_DOWN:
		text += "D"
	if flags & Defs.IN_FIRE:
		text += "F"
	if flags & Defs.IN_SWAP:
		text += "S"
	return text


static func dir_flag(dir: int) -> int:
	return Defs.IN_RIGHT if dir > 0 else (Defs.IN_LEFT if dir < 0 else 0)


# =================================================================================================================
# Route files
# =================================================================================================================

## A route file read: {"level": StringName, "gate", "difficulty": int, "whole": bool, "start": int, "tick0": int,
## "real": bool, "tickoff": int, "events": Array, "flags": PackedInt32Array, "path"}; {} when it is none.
static func read_route(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var fields: Dictionary = {}
	for line: String in FileAccess.get_file_as_string(path).split("\n"):
		line = line.strip_edges()
		if line.begins_with("events="):
			fields["events"] = line.substr(7)
		elif line.begins_with("route="):
			fields["route"] = line.substr(6)
		else:
			for token: String in line.split(" ", false):
				var eq: int = token.find("=")
				if eq > 0:
					fields[token.substr(0, eq)] = token.substr(eq + 1)
	if not fields.has("level") or not fields.has("gate") or not fields.has("route"):
		return {}
	var flags: PackedInt32Array = PackedInt32Array()
	for entry: String in str(fields["route"]).split(",", false):
		var count: int = entry.get_slice(":", 0).to_int()
		var value: int = GameInput.keys_to_flags(entry.get_slice(":", 1))
		for i: int in count:
			flags.append(value)
	var events: Variant = str_to_var(str(fields.get("events", "[]")))
	return {"level": StringName(str(fields["level"])), "gate": str(fields["gate"]),
		"tick0": str(fields["tick0"]).to_int() if str(fields.get("tick0", "-")).is_valid_int() else 0,
		"difficulty": str(fields.get("difficulty", "0")).to_int(), "whole": str(fields.get("whole", "false")) == "true",
		"start": str(fields.get("start", "0")).to_int(), "real": str(fields.get("real", "false")) == "true",
		"tickoff": str(fields.get("tickoff", "0")).to_int(), "events": events if events is Array else [],
		"flags": flags, "path": path}


## The text of a route file.
static func route_file_text(level_id: StringName, gate_name: String, p_difficulty: int, p_whole: bool, start: int,
		events: Array, route: String, real: bool = false, tickoff: int = 0, tick0: int = 0) -> String:
	return "level=%s gate=%s difficulty=%d whole=%s start=%d tick0=%d%s\nevents=%s\nroute=%s\n" % [level_id, gate_name,
		p_difficulty, str(p_whole), start, tick0, " real=true tickoff=%d" % tickoff if real else "", str(events), route]


## Play `route` ([method read_route]; a search-world one) on this harness from a fresh reset: {"end": "goal" / "dead" /
## "" (not reached), "t": ticks played, "pos": where the hero is, "min_y", "bounces", "hurts"}. `each` (optional) is
## called after every tick with (tick, flag).
func play_route(route: Dictionary, each: Callable = Callable()) -> Dictionary:
	var events: Array = route["events"]
	var flags: PackedInt32Array = route["flags"]
	var start_index: int = clampi(int(route["start"]), 0, starts.size() - 1)
	begin(starts[start_index], 1)
	var next_event: int = 0
	var end: String = ""
	for i: int in flags.size():
		while next_event < events.size() and int(events[next_event][0]) <= i:
			var event: Array = events[next_event]
			if str(event[1]) == "hand":
				set_hand(int(event[2]))
			elif str(event[1]) == "place":
				place_partner()
			next_event += 1
		end = step(flags[i])
		if each.is_valid():
			each.call(t, flags[i])
		if end != "":
			break
	return {"end": end, "t": t, "pos": s.hero.sim_pos, "min_y": min_y, "bounces": bounces, "hurts": hurts}


## The route files of the evidence set (EVIDENCE_DIR, not its sub-folders: `not_replayable` holds the explorer finds
## of G3b that no fresh process replayed), sorted; `level_id` / `gate_name` / `p_difficulty` (-1: any) narrow it.
static func evidence_files(level_id: StringName = &"", gate_name: String = "", p_difficulty: int = -1) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	var dir: DirAccess = DirAccess.open(EVIDENCE_DIR)
	if dir == null:
		return result
	var names: PackedStringArray = dir.get_files()
	names.sort()
	for name: String in names:
		if not name.ends_with(".txt"):
			continue
		var path: String = EVIDENCE_DIR.path_join(name)
		if level_id != &"" or gate_name != "" or p_difficulty >= 0:
			var route: Dictionary = read_route(path)
			if route.is_empty() or (level_id != &"" and route["level"] != level_id) \
					or (gate_name != "" and str(route["gate"]) != gate_name) \
					or (p_difficulty >= 0 and int(route["difficulty"]) != p_difficulty):
				continue
		result.append(path)
	return result


# =================================================================================================================
# Results kept for the gate test (R7: the proof of a gate is three things)
# =================================================================================================================

## The seed of gate row (`level_id`, `p_difficulty`, `gate_name`) in explorer pass `pass_index` (0 or 1).
static func row_seed(level_id: StringName, p_difficulty: int, gate_name: String, pass_index: int) -> int:
	return PASS_SEEDS[clampi(pass_index, 0, PASS_SEEDS.size() - 1)] \
			+ absi(("%s|%s|%d" % [level_id, gate_name, p_difficulty]).hash()) % 900


## What a result of this gate depends on besides the simulation's code: the level file, its solo base, these scripts.
static func _world_key_parts(level_id: StringName, p_difficulty: int, gate_name: String) -> PackedStringArray:
	var path: String = CoopSearch.level_path(level_id)
	var data_now: LevelData = LevelData.load_file(path)
	var parts: PackedStringArray = PackedStringArray([VERSION,
		CoopSearch.code_fingerprint(data_now == null or CoopSearch.world_has_boss_anywhere(data_now, p_difficulty)),
		FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""])
	if data_now != null and str(data_now.value("coop_of")) != "":
		var base_path: String = CoopSearch.level_path(StringName(str(data_now.value("coop_of"))))
		parts.append(FileAccess.get_file_as_string(base_path) if FileAccess.file_exists(base_path) else "")
	for script: String in KEY_SCRIPTS:
		parts.append(FileAccess.get_md5(script))
	parts.append("%d|%s%s" % [p_difficulty, gate_name, CoopSearch.rules_off_text()])
	return parts


## The key of an explorer pass's result: everything it depends on, its seed and its seconds.
static func explore_key(level_id: StringName, p_difficulty: int, gate_name: String, seed_value: int,
		seconds: int) -> String:
	var parts: PackedStringArray = _world_key_parts(level_id, p_difficulty, gate_name)
	parts.append("explore|%d|%d" % [seed_value, seconds])
	return "|".join(parts).md5_text()


## The key of an evidence route's replay: everything it depends on and the route file's own text.
static func replay_key(route_path: String) -> String:
	var route: Dictionary = read_route(route_path)
	if route.is_empty():
		return ""
	var parts: PackedStringArray = _world_key_parts(route["level"], int(route["difficulty"]), str(route["gate"]))
	parts.append("replay|%s" % FileAccess.get_file_as_string(route_path))
	return "|".join(parts).md5_text()


static func cache_read(key: String) -> Dictionary:
	var path: String = CACHE_DIR.path_join(key + ".json")
	if key == "" or not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


static func cache_write(key: String, result: Dictionary) -> void:
	if key == "":
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CACHE_DIR))
	var final_path: String = CACHE_DIR.path_join(key + ".json")
	var temp_path: String = "%s.%d.tmp" % [final_path, OS.get_process_id()]
	var file: FileAccess = FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(result))
	file.close()
	DirAccess.rename_absolute(ProjectSettings.globalize_path(temp_path), ProjectSettings.globalize_path(final_path))
