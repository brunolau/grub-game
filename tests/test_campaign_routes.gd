extends TestCase
## The campaign and its route proofs (owner: integration).
##
## Data-driven: ROUTES describes every input script in tools/autoplay/routes (test_every_route_file_is_described
## fails for a file without an entry). Each route is replayed through Flow and the real level scene from a fresh
## run with the default seed, tick for tick as the windowed game plays it (`gd.sh play --flow=...` with
## `play_file`, or `--autoplay=<id> --inputs-file=...`), on every difficulty it was recorded for, and must reach
## the documented outcome: how the level ends (exit totem, warp, trophy - or nowhere for a side path), what
## follows (tally, linked stage, bonus stage, The End), and the checks of its `expect` block.
##
## The two campaign tests then play the WHOLE game in one run per difficulty, with everything a real run carries
## from level to level (score, lives, weapon, letters): every map stop in order, a bonus stage through its warp,
## both bosses, the tally after every level, the unlocks and records of the save file, the expert wall at the end
## of a Beginner run and the ending stage, The End and the completion flag of an Expert run. They are the headless
## twins of tools/autoplay/campaign.flow and campaign_beginner.flow.
##
## Route-building aids (no tests of their own; the route and campaign tests are skipped while one runs):
##   CAMPAIGN_PROBE=<route file> [CAMPAIGN_DIFF=expert] [CAMPAIGN_EVERY=n] [CAMPAIGN_WEAPON=<Defs.Weapon>]
##       [CAMPAIGN_INPUTS=<res:// path of another input file>]   replay one route line by line and print the hero's
##       cell, state and the events of every line, e.g. CAMPAIGN_PROBE=w1_l1.inputs bash .tools/gd.sh test campaign_routes
##   CAMPAIGN_ADAPT=<route file> CAMPAIGN_WEAPON=<n> [CAMPAIGN_ABSORB=1]   pad a route by another weapon's longer swing
##       recovery (made w4_l2.boomerang.inputs) -> build/adapt/<route file>
##   CAMPAIGN_REPAIR=<route file> CAMPAIGN_WEAPON=<n>   re-time a route for another weapon drift by drift against
##       the recorded weapon's replay -> build/adapt/<route file> (it gets Bone Gorge with the hammer through the cave
##       and the stepping stones, then needs a hand at the bone field)

const ROUTE_DIR: String = "res://tools/autoplay/routes/"
## Logical view of the 1280 x 720 game window (integer scale 2): enemies wake by the view.
const VIEW: Vector2i = Vector2i(Tuning.VIEW_W, Tuning.VIEW_H)
const BEGINNER: String = "beginner"
const EXPERT: String = "expert"
## Letter indices of the bonus word G-R-U-B-S.
const ALL_LETTERS: Array[int] = [0, 1, 2, 3, 4]

## Every route file. Keys of an entry:
##   level      the level the route starts in
##   modes      difficulties it is played on
##   prefix     [route file, marker]: a side path; that route (or "@route", the level's route on the mode played)
##              is played first up to its first line that starts with the marker
##   chained    true: played only after the route that leads into its level (an entry's `then`), never alone
##   weapon     weapon (Defs.Weapon) the hero carries when the route starts; default: the club of a new run
##   source     bonus stages: the main level whose warp leads in (the stage is entered as that warp enters it)
##   leaves     how the level must end: "exit", "warp", "trophy"; "" = a side path that stops anywhere
##   after      what must follow: "tally" or "level:<id>"
##   then       route file played in the stage that follows (a linked sub-stage, or the stage after a trophy)
##   tally_to   after the tally (bonus stages, ending): "map:<id>", "expert_wall" or "the_end", per mode name
##   expect     checks, see _check_expectations()
const ROUTES: Dictionary = {
	# --- World 1 ------------------------------------------------------------------------------------------------
	"w1_l1.inputs": {"level": "w1_l1", "modes": [BEGINNER], "leaves": "exit", "after": "tally",
		"expect": {"hurts": 0, "min_checkpoints": 1, "min_spots": 20, "letters": [1, 3, 4]}},
	"w1_l1.expert.inputs": {"level": "w1_l1", "modes": [EXPERT], "leaves": "exit", "after": "tally",
		"expect": {"hurts": 0, "min_checkpoints": 1, "min_spots": 17, "letters": [1, 3]}},
	"w1_l1.cliff.inputs": {"level": "w1_l1", "modes": [BEGINNER], "leaves": "",
		"expect": {"hurts": 0, "min_secrets": 1, "letters": [0]}},
	"w1_l1.highroad.inputs": {"level": "w1_l1", "modes": [BEGINNER], "leaves": "",
		"expect": {"hurts": 0, "min_secrets": 1, "letters": [2], "min_checkpoints": 1, "lives_gained": 1}},
	"w1_l2.inputs": {"level": "w1_l2", "modes": [BEGINNER], "leaves": "exit", "after": "tally",
		"expect": {"hurts": 0, "min_checkpoints": 1, "min_spots": 10, "letters": ALL_LETTERS, "words": 1,
			"weapon_end": Defs.Weapon.AXE}},
	"w1_l2.expert.inputs": {"level": "w1_l2", "modes": [EXPERT], "leaves": "exit", "after": "tally",
		"expect": {"hurts": 0, "min_checkpoints": 1, "min_spots": 10, "letters": ALL_LETTERS, "words": 1,
			"weapon_end": Defs.Weapon.AXE}},
	"w1_l2.warp.inputs": {"level": "w1_l2", "modes": [BEGINNER, EXPERT], "leaves": "warp", "after": "level:bonus_a",
		"expect": {"hurts": 0, "min_secrets": 2}},
	# --- World 2 ------------------------------------------------------------------------------------------------
	"w2_l1.inputs": {"level": "w2_l1", "modes": [BEGINNER], "leaves": "exit", "after": "tally",
		"expect": {"weapon_end": Defs.Weapon.HAMMER, "secrets": 4, "gates": 4, "letters": ALL_LETTERS, "words": 1,
			"min_checkpoints": 4, "min_spots": 25, "ticks": [2200, 4400], "min_completion": 80}},
	"w2_l1.expert.inputs": {"level": "w2_l1", "modes": [EXPERT], "leaves": "exit", "after": "tally",
		"expect": {"weapon_end": Defs.Weapon.HAMMER, "secrets": 4, "gates": 4, "letters": ALL_LETTERS, "words": 1,
			"min_checkpoints": 4, "min_spots": 25, "ticks": [2200, 4400], "min_completion": 80}},
	"w2_l2.inputs": {"level": "w2_l2", "modes": [BEGINNER], "leaves": "exit", "after": "level:w2_l2b",
		"then": "w2_l2b.inputs",
		"expect": {"glider": true, "letters": [0, 1, 2, 4], "min_secrets": 1, "gates": 2}},
	"w2_l2.expert.inputs": {"level": "w2_l2", "modes": [EXPERT], "leaves": "exit", "after": "level:w2_l2b",
		"then": "w2_l2b.expert.inputs",
		"expect": {"glider": true, "letters": [0, 1, 2, 4], "min_secrets": 1, "gates": 2}},
	"w2_l2b.inputs": {"level": "w2_l2b", "modes": [BEGINNER], "chained": true, "leaves": "exit", "after": "tally",
		"expect": {"boss_hits": 2, "unlocked": true, "pair_ticks": [2200, 4400]}},
	# The campaign hero brings the hammer of Echo Caverns into the den; the Expert fight is recorded with it.
	"w2_l2b.expert.inputs": {"level": "w2_l2b", "modes": [EXPERT], "chained": true, "weapon": Defs.Weapon.HAMMER,
		"leaves": "exit", "after": "tally", "expect": {"boss_hits": 3, "unlocked": true, "pair_ticks": [2200, 4400]}},
	# --- World 3 ------------------------------------------------------------------------------------------------
	"w3_l1.inputs": {"level": "w3_l1", "modes": [BEGINNER], "leaves": "exit", "after": "level:w3_l1b",
		"then": "w3_l1b.inputs", "expect": {"min_secrets": 3, "min_checkpoints": 4, "min_spots": 15}},
	"w3_l1.expert.inputs": {"level": "w3_l1", "modes": [EXPERT], "leaves": "exit", "after": "level:w3_l1b",
		"then": "w3_l1b.expert.inputs", "expect": {"min_secrets": 3, "min_checkpoints": 4, "min_spots": 15}},
	"w3_l1b.inputs": {"level": "w3_l1b", "modes": [BEGINNER], "chained": true, "leaves": "exit", "after": "tally",
		"expect": {"min_wind": 40, "min_secrets": 2, "lives_gained": 1, "min_completion": 70,
			"pair_ticks": [2200, 99999]}},
	"w3_l1b.expert.inputs": {"level": "w3_l1b", "modes": [EXPERT], "chained": true, "leaves": "exit",
		"after": "tally", "expect": {"min_wind": 40, "min_secrets": 1, "lives_gained": 1, "min_completion": 70,
			"pair_ticks": [2200, 99999]}},
	# The routes take the sky path over the icicle overhang; the valley under it must be passable too.
	"w3_l1.valley.inputs": {"level": "w3_l1", "modes": [BEGINNER, EXPERT], "prefix": ["@route", "# S4"],
		"leaves": "", "expect": {"hero_min_x": 169 * 16}},
	# The routes cross the Blizzard Pass pond through its secret grotto; the floes must carry a player too.
	"w3_l1b.pond.inputs": {"level": "w3_l1b", "modes": [BEGINNER], "prefix": ["w3_l1b.inputs", "# B4"],
		"leaves": "", "expect": {"hero_min_x": 88 * 16, "hero_y": 26 * 16}},
	"w3_l1b.pond.expert.inputs": {"level": "w3_l1b", "modes": [EXPERT],
		"prefix": ["w3_l1b.expert.inputs", "# B4"], "leaves": "", "expect": {"hero_min_x": 88 * 16, "hero_y": 26 * 16}},
	"w3_l2.inputs": {"level": "w3_l2", "modes": [BEGINNER], "leaves": "exit", "after": "tally",
		"expect": {"weapon_end": Defs.Weapon.BOOMERANG, "min_secrets": 3, "min_checkpoints": 2,
			"ticks": [2200, 4400], "min_completion": 80, "letters": ALL_LETTERS, "words": 1}},
	"w3_l2.expert.inputs": {"level": "w3_l2", "modes": [EXPERT], "leaves": "exit", "after": "tally",
		"expect": {"weapon_end": Defs.Weapon.BOOMERANG, "min_secrets": 3, "min_checkpoints": 2,
			"ticks": [2200, 4400], "min_completion": 80, "max_hurts": 1}},
	# --- World 4 (Expert only) ----------------------------------------------------------------------------------
	"w4_l1.inputs": {"level": "w4_l1", "modes": [EXPERT], "leaves": "exit", "after": "tally",
		"expect": {"respawns": 0, "view_sank": 2000, "min_checkpoints": 3, "min_secrets": 3, "min_spots": 15,
			"words": 1, "ticks": [2600, 4400], "min_completion": 70, "embers": [20, 1], "no_warnings": true}},
	"w4_l2.inputs": {"level": "w4_l2", "modes": [EXPERT], "leaves": "exit", "after": "level:w4_l2b",
		"then": "w4_l2b.inputs",
		"expect": {"min_checkpoints": 3, "min_secrets": 3, "min_spots": 15, "min_kills": 4, "words": 1,
			"ticks": [2200, 4400], "min_completion": 80, "no_warnings": true}},
	# The same keep with the swirling axe a campaign run brings from Crystal Grotto (the route padded by its recovery).
	"w4_l2.boomerang.inputs": {"level": "w4_l2", "modes": [EXPERT], "weapon": Defs.Weapon.BOOMERANG, "leaves": "exit",
		"after": "level:w4_l2b", "then": "w4_l2b.inputs",
		"expect": {"min_checkpoints": 3, "min_secrets": 3, "min_spots": 12, "words": 1, "ticks": [2200, 4400],
			"min_completion": 70, "no_warnings": true}},
	"w4_l2b.inputs": {"level": "w4_l2b", "modes": [EXPERT], "chained": true, "leaves": "trophy",
		"after": "level:ending", "expect": {"weapon_end": Defs.Weapon.AXE, "boss_hits": 24, "no_warnings": true}},
	# --- Feast Land bonus stages and the ending -----------------------------------------------------------------
	"bonus_a.inputs": {"level": "bonus_a", "modes": [BEGINNER, EXPERT], "source": "w1_l2", "leaves": "warp",
		"after": "tally", "tally_to": {BEGINNER: "map:w2_l1", EXPERT: "map:w2_l1"},
		"expect": {"no_enemies": true, "ticks": [1092, 2185], "min_score": 150000, "min_spots": 8,
			"no_warnings": true}},
	"bonus_b.inputs": {"level": "bonus_b", "modes": [BEGINNER, EXPERT], "source": "w2_l1", "leaves": "warp",
		"after": "tally", "tally_to": {BEGINNER: "map:w2_l2", EXPERT: "map:w2_l2"},
		"expect": {"no_enemies": true, "ticks": [1092, 2185], "min_score": 100000, "min_spots": 8,
			"no_warnings": true}},
	"bonus_c.inputs": {"level": "bonus_c", "modes": [BEGINNER, EXPERT], "source": "w3_l2", "leaves": "warp",
		"after": "tally", "tally_to": {BEGINNER: "expert_wall", EXPERT: "map:w4_l1"},
		"expect": {"no_enemies": true, "ticks": [1092, 2185], "min_score": 200000, "min_spots": 8,
			"no_warnings": true}},
	"bonus_a.secret.inputs": {"level": "bonus_a", "modes": [BEGINNER], "leaves": "",
		"expect": {"secrets": 1, "no_warnings": true}},
	"bonus_b.secret.inputs": {"level": "bonus_b", "modes": [BEGINNER], "leaves": "",
		"expect": {"secrets": 1, "no_warnings": true}},
	"bonus_c.secret.inputs": {"level": "bonus_c", "modes": [BEGINNER], "leaves": "",
		"expect": {"secrets": 1, "gates": 1, "no_warnings": true}},
	"ending.inputs": {"level": "ending", "modes": [EXPERT], "leaves": "exit", "after": "tally",
		"tally_to": {EXPERT: "the_end"},
		"expect": {"checkpoints": 4, "hurts": 0, "min_score": 100000, "no_warnings": true}},
}

## The whole game, one map stop after the other: [level the step starts in, route file per mode name]. Linked
## stages follow inside a step (the route of the stage that follows comes from its ROUTES entry's `then`).
## Both take the warp of Canopy Village into bonus stage A (its tally ends Canopy Village). Beginner ends at the
## expert wall after Crystal Grotto; Expert goes on through world 4 and ends with the ending stage after the Wall
## Colossus.
const CAMPAIGN: Dictionary = {
	BEGINNER: [
		["w1_l1", "w1_l1.inputs"], ["w1_l2", "w1_l2.warp.inputs"], ["bonus_a", "bonus_a.inputs"],
		["w2_l1", "w2_l1.inputs"], ["w2_l2", "w2_l2.inputs"], ["w3_l1", "w3_l1.inputs"], ["w3_l2", "w3_l2.inputs"],
	],
	EXPERT: [
		["w1_l1", "w1_l1.expert.inputs"], ["w1_l2", "w1_l2.warp.inputs"], ["bonus_a", "bonus_a.inputs"],
		["w2_l1", "w2_l1.expert.inputs"],
		["w2_l2", "w2_l2.expert.inputs"], ["w3_l1", "w3_l1.expert.inputs"], ["w3_l2", "w3_l2.expert.inputs"],
		["w4_l1", "w4_l1.inputs"], ["w4_l2", "w4_l2.inputs"], ["ending", "ending.inputs"],
	],
}

## A run carries its weapon from level to level (GAMEPLAY.md 8.1): the axe of Canopy Village into Echo Caverns, its
## hammer through worlds 2 and 3, the swirling axe of Crystal Grotto into world 4. A swing locks the hero for the
## weapon's recovery (club 2 ticks, hammer and axe 6, swirling axe 12), so a route recorded with another weapon
## drifts and fails. These routes are not yet proven with the weapon a run brings: the campaign tests (and
## tools/autoplay/campaign*.flow) hand the hero the weapon the route was recorded with before playing them, and the
## run goes on with whatever that route ends with (so one hand-over can make the next level match again). The list
## is checked, so a route re-recorded for the carried weapon must leave it. (CAMPAIGN_ADAPT helps re-recording;
## w4_l2.boomerang.inputs is such a re-recording, used once w4_l1 hands on the swirling axe.)
## Without a hand-over the replays fail: Echo Caverns with the axe (Beginner stuck before the exit, Expert dies at tick
## 2235), Bone Gorge with the hammer (dies at the spike pit, tick 452), Frost Summit Expert with the hammer (dies at
## tick 683), Cinder Shaft with the swirling axe (dies at tick 674).
const WEAPON_GAPS: Dictionary = {
	BEGINNER: ["w2_l1.inputs", "w2_l2.inputs"],
	EXPERT: ["w2_l1.expert.inputs", "w2_l2.expert.inputs", "w2_l2b.expert.inputs", "w3_l1.expert.inputs",
		"w4_l1.inputs"],
}

## The map stops of each mode, in order.
const MAP: Dictionary = {
	BEGINNER: [&"w1_l1", &"w1_l2", &"w2_l1", &"w2_l2", &"w3_l1", &"w3_l2"],
	EXPERT: [&"w1_l1", &"w1_l2", &"w2_l1", &"w2_l2", &"w3_l1", &"w3_l2", &"w4_l1", &"w4_l2"],
}


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


## What happened since the last _reset_watch(): Events counts and the details some checks need.
var _counts: Dictionary = {}
var _letters: Dictionary = {}
var _words: int = 0
var _boss_hits: int = 0
var _glider_carried: bool = false
var _glider_flown: bool = false
var _exit_kinds: Array[StringName] = []
var _max_wind: int = 0
var _deepest_view_y: int = 0
var _embers_seen: Dictionary = {}
var _embers_close: Dictionary = {}
var _connections: Array[Array] = []
var _problems: ProblemCounter = null
var _counting: bool = false
## Routes of the campaign run that were played with the weapon they were recorded with (WEAPON_GAPS).
var _weapon_overrides: Array[String] = []
## Per-tick observations are only made when a route asks for them (they cost time).
var _watch_wind: bool = false
var _watch_view: bool = false
var _watch_embers: bool = false


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
# The campaign's shape
# =================================================================================================================

func test_every_level_file_is_valid() -> void:
	var validator: LevelValidator = LevelValidator.new()
	assert_true(validator.add_folder(Levels.LEVEL_DIR) > 0)
	validator.run()
	assert_eq(validator.error_count(), 0, "no level file of the folder has an error")
	for level_id: StringName in Levels.all_ids():
		if str(Levels.get_value(level_id, "kind", Levels.KIND_MAIN)) == Levels.KIND_TEST:
			continue
		var problems: Array[Dictionary] = validator.problems_of(Levels.get_level_path(level_id))
		var lines: PackedStringArray = PackedStringArray()
		for problem: Dictionary in problems:
			lines.append(LevelValidator.format_problem(problem))
		assert_eq(problems.size(), 0, "%s: no error and no warning\n%s" % [level_id, "\n".join(lines)])


func test_the_campaign_order_and_links() -> void:
	for mode: String in [BEGINNER, EXPERT]:
		var difficulty: int = _difficulty(mode)
		assert_eq(Levels.get_campaign(difficulty), MAP[mode] as Array[StringName], "%s map stops" % mode)
		assert_eq(Levels.first_level(), &"w1_l1", "a new game starts in Vine Bridges")
		for level_id: StringName in Levels.all_ids():
			var kind: String = str(Levels.get_value(level_id, "kind", Levels.KIND_MAIN))
			if kind == Levels.KIND_TEST:
				assert_false(Levels.get_campaign(difficulty).has(level_id), "%s is no map stop" % level_id)
	# Linked stages (no tally between the halves) and where each stage leads.
	var links: Array = [
		[&"w1_l1", &"w1_l2"], [&"w1_l2", &"w2_l1"], [&"w2_l1", &"w2_l2"], [&"w2_l2", &"w2_l2b"],
		[&"w2_l2b", &"w3_l1"], [&"w3_l1", &"w3_l1b"], [&"w3_l1b", &"w3_l2"],
	]
	for mode: String in [BEGINNER, EXPERT]:
		for link: Array in links:
			assert_eq(Levels.next_level(link[0], _difficulty(mode)), link[1], "%s: %s -> %s" % [mode, link[0], link[1]])
	assert_eq(Levels.next_level(&"w3_l2", Defs.Difficulty.BEGINNER), &"", "Beginner ends after Crystal Grotto")
	assert_true(Levels.has_locked_successor(&"w3_l2", Defs.Difficulty.BEGINNER), "... at the expert wall")
	for link: Array in [[&"w3_l2", &"w4_l1"], [&"w4_l1", &"w4_l2"], [&"w4_l2", &"w4_l2b"], [&"w4_l2b", &"ending"]]:
		assert_eq(Levels.next_level(link[0], Defs.Difficulty.EXPERT), link[1], "expert: %s -> %s" % [link[0], link[1]])
	assert_eq(Levels.next_level(&"ending", Defs.Difficulty.EXPERT), &"", "the ending ends the game")
	for pair: Array in [[&"w2_l2", &"w2_l2b"], [&"w3_l1", &"w3_l1b"], [&"w4_l2", &"w4_l2b"]]:
		assert_false(bool(Levels.get_value(pair[0], "tally", true)), "%s hands over to %s without a tally" % pair)
		assert_eq(str(Levels.get_value(pair[1], "kind", "")), Levels.KIND_SUB)
		for mode: String in [BEGINNER, EXPERT]:
			if Levels.is_available(pair[1], _difficulty(mode)):
				assert_eq(Levels.parent_level(pair[1], _difficulty(mode)), pair[0], "%s belongs to %s" % [pair[1], pair[0]])
	# Bonus stages: each one has exactly one source level, whose warp leads in.
	var sources: Dictionary = {&"bonus_a": &"w1_l2", &"bonus_b": &"w2_l1", &"bonus_c": &"w3_l2"}
	for level_id: StringName in Levels.all_ids():
		for mode: String in [BEGINNER, EXPERT]:
			var bonus: StringName = StringName(str(Levels.get_value(level_id, "bonus", "", _difficulty(mode))))
			if bonus != &"":
				assert_eq(sources.get(bonus, &""), level_id, "%s leads to %s" % [level_id, bonus])
	for bonus: StringName in sources:
		assert_eq(str(Levels.get_value(bonus, "kind", "")), Levels.KIND_BONUS)
		for mode: String in [BEGINNER, EXPERT]:
			assert_eq(str(Levels.get_value(sources[bonus], "bonus", "", _difficulty(mode))), String(bonus))
	# Expert-only world 4 and ending.
	for level_id: StringName in [&"w4_l1", &"w4_l2", &"w4_l2b", &"ending"]:
		assert_false(Levels.is_available(level_id, Defs.Difficulty.BEGINNER), "%s is expert only" % level_id)
	assert_eq(str(Levels.get_value(&"ending", "kind", "")), Levels.KIND_ENDING)


## Every stage a player can be in (map stops, linked stages, the ending) has a code per mode it can be played in,
## no bonus stage has one, all codes are unique, and every code leads to its level and mode.
func test_every_stage_has_a_unique_code_per_mode() -> void:
	var seen: Dictionary = {}
	for level_id: StringName in Levels.all_ids():
		var kind: String = str(Levels.get_value(level_id, "kind", Levels.KIND_MAIN))
		if kind == Levels.KIND_TEST:
			continue
		for difficulty: int in [Defs.Difficulty.BEGINNER, Defs.Difficulty.EXPERT]:
			var code: String = Levels.get_password(level_id, difficulty)
			var playable: bool = kind != Levels.KIND_BONUS and Levels.is_available(level_id, difficulty)
			if not playable:
				assert_eq(code, "", "%s has no %s code" % [level_id, Defs.difficulty_name(difficulty)])
				continue
			assert_eq(code.length(), 4, "%s has a %s code" % [level_id, Defs.difficulty_name(difficulty)])
			assert_false(seen.has(code.to_upper()), "code %s is unique (also %s)" % [code, seen.get(code.to_upper())])
			seen[code.to_upper()] = level_id
			assert_eq(Levels.find_by_password(code), {"level_id": level_id, "difficulty": difficulty},
					"code %s starts %s" % [code, level_id])
			assert_eq(Levels.find_by_password(code.to_lower()), {"level_id": level_id, "difficulty": difficulty})
	assert_eq(seen.size(), 2 * 8 + 3 + 1, "codes: 8 stages in both modes, 3 Expert-only stages, the ending")


## Every map stop has a marker of its own on an island of the world map (never on the sea), in the order of the
## campaign from left to right; a linked sub-stage, a bonus stage and the ending stand at the stop they belong to.
func test_every_map_stop_has_a_marker_on_land() -> void:
	var picture: Image = Image.load_from_file(ProjectSettings.globalize_path(WorldMapScreen.MAP_TEXTURE))
	assert_not_null(picture)
	if picture == null:
		return
	var seen: Dictionary = {}
	var last_world: int = 0
	var world_x: Dictionary = {}
	for level_id: StringName in MAP[EXPERT]:
		var place: Vector2 = WorldMapScreen.marker_place(level_id)
		assert_ne(place, Vector2.INF, "%s has a marker" % level_id)
		if place == Vector2.INF:
			continue
		assert_false(seen.has(place), "%s has a place of its own" % level_id)
		seen[place] = level_id
		var color: Color = picture.get_pixelv(Vector2i(place))
		var sea: bool = color.b8 > color.r8 + 40 and color.b8 > color.g8 + 15
		assert_false(sea, "%s stands on land, not on the sea (%s at %s)" % [level_id, color, place])
		var world: int = int(Levels.get_value(level_id, "world", 0))
		assert_true(world >= last_world, "worlds in order")
		last_world = world
		world_x[world] = maxf(float(world_x.get(world, 0.0)), place.x)
	for world: int in [2, 3, 4]:
		assert_true(float(world_x.get(world, 0.0)) > float(world_x.get(world - 1, 0.0)) - 40.0,
				"world %d lies right of world %d" % [world, world - 1])
	Game.new_game(Defs.Difficulty.EXPERT)
	assert_eq(WorldMapScreen.map_stop(&"w2_l2b"), &"w2_l2", "the Brute's den stands at Bone Gorge")
	assert_eq(WorldMapScreen.map_stop(&"bonus_c"), &"w3_l2", "Feast Land C stands at Crystal Grotto")
	assert_eq(WorldMapScreen.map_stop(&"ending"), &"w4_l2", "the ending stands at the last stop")
	assert_eq(WorldMapScreen.map_stop(&"test_example"), &"", "a developer level has no stop")


## Every text a stage shows (sign boards, hint zones) has an English translation in locale/en.po.
func test_every_level_text_is_translated() -> void:
	var catalogue: String = FileAccess.get_file_as_string("res://locale/en.po")
	var missing: PackedStringArray = PackedStringArray()
	var regex: RegEx = RegEx.create_from_string("text=([A-Z0-9_]+)")
	for level_id: StringName in Levels.all_ids():
		if str(Levels.get_value(level_id, "kind", Levels.KIND_MAIN)) == Levels.KIND_TEST:
			continue
		for found: RegExMatch in regex.search_all(FileAccess.get_file_as_string(Levels.get_level_path(level_id))):
			var key: String = found.get_string(1)
			if not catalogue.contains("msgid \"%s\"" % key):
				missing.append("%s: %s" % [level_id, key])
	assert_eq(missing, PackedStringArray(), "level texts without a translation")


func test_every_route_file_is_described() -> void:
	var dir: DirAccess = DirAccess.open(ROUTE_DIR)
	assert_not_null(dir)
	var files: PackedStringArray = dir.get_files() if dir != null else PackedStringArray()
	var count: int = 0
	for file: String in files:
		if file.get_extension() != "inputs":
			continue
		count += 1
		assert_true(ROUTES.has(file), "%s has an entry in ROUTES" % file)
	for file: String in ROUTES:
		assert_true(FileAccess.file_exists(ROUTE_DIR + file), "%s exists" % file)
		var spec: Dictionary = ROUTES[file]
		assert_true(Levels.has_level(StringName(str(spec["level"]))), "%s: level %s exists" % [file, spec["level"]])
		if spec.has("then"):
			assert_true(ROUTES.has(spec["then"]) and bool(ROUTES[spec["then"]].get("chained", false)),
					"%s: the route that follows (%s) is a chained entry" % [file, spec["then"]])
	assert_eq(count, ROUTES.size(), "every route file is described once")


## More enemies on Expert than on Beginner in every stage that has both spawn sets and is not a boss stage.
func test_expert_spawn_sets_are_tougher() -> void:
	for level_id: StringName in [&"w1_l1", &"w1_l2", &"w2_l1", &"w2_l2", &"w3_l1", &"w3_l1b", &"w3_l2"]:
		var counts: Array[int] = []
		for difficulty: int in [Defs.Difficulty.BEGINNER, Defs.Difficulty.EXPERT]:
			Game.new_game(difficulty)
			await _enter(level_id)
			counts.append(Game.level.get_kind(Defs.Kind.ENEMY).size())
			after_each()
		assert_true(counts[1] > counts[0], "%s: more enemies on Expert (%d) than on Beginner (%d)" % [
			level_id, counts[1], counts[0]])


# =================================================================================================================
# Route proofs
# =================================================================================================================

func test_world_1_routes() -> void:
	await _play_routes("w1_")


func test_world_2_routes() -> void:
	await _play_routes("w2_")


func test_world_3_routes() -> void:
	await _play_routes("w3_")


func test_world_4_routes() -> void:
	await _play_routes("w4_")


func test_feast_land_and_ending_routes() -> void:
	await _play_routes("bonus_")
	await _play_routes("ending")


# =================================================================================================================
# The whole campaign in one run
# =================================================================================================================

func test_the_beginner_campaign_in_one_run() -> void:
	await _play_campaign(BEGINNER)


func test_the_expert_campaign_in_one_run() -> void:
	await _play_campaign(EXPERT)


## Route-building aid: CAMPAIGN_PROBE=<route file> replays it line by line and prints what happened.
func test_probe() -> void:
	var file: String = OS.get_environment("CAMPAIGN_PROBE")
	assert_true(file.is_empty() or ROUTES.has(file) or FileAccess.file_exists(ROUTE_DIR + file), "a route file")
	if file.is_empty():
		return
	var mode: String = EXPERT if OS.get_environment("CAMPAIGN_DIFF") == EXPERT else BEGINNER
	var spec: Dictionary = ROUTES.get(file, {"level": file.get_slice(".", 0)})
	var every: int = maxi(OS.get_environment("CAMPAIGN_EVERY").to_int(), 0)
	Game.new_game(_difficulty(mode))
	if spec.has("weapon"):
		Game.set_weapon(int(spec["weapon"]))
	if OS.get_environment("CAMPAIGN_WEAPON") != "":
		Game.set_weapon(OS.get_environment("CAMPAIGN_WEAPON").to_int())
	var level_id: StringName = StringName(str(spec.get("level", OS.get_environment("CAMPAIGN_LEVEL"))))
	await _enter(level_id)
	var log_lines: PackedStringArray = PackedStringArray()
	var on_event: Callable = func(signal_name: StringName) -> void: log_lines.append(String(signal_name))
	for info: Dictionary in Events.get_signal_list():
		var name: StringName = StringName(str(info["name"]))
		if name in [&"popup_requested", &"player_landed", &"player_jumped", &"shake_requested", &"wind_changed"]:
			continue
		var callable: Callable = on_event.bind(name)
		var arguments: int = (info["args"] as Array).size()
		_connect(Signal(Events, name), callable.unbind(arguments) if arguments > 0 else callable)
	var text: String = _route_text(spec, file, mode)
	if OS.get_environment("CAMPAIGN_INPUTS") != "":
		text = FileAccess.get_file_as_string(OS.get_environment("CAMPAIGN_INPUTS"))
	var played: int = 0
	var line_no: int = 0
	var comment: String = ""
	for line: String in text.split("\n"):
		line_no += 1
		var stripped: String = line.strip_edges()
		if stripped.begins_with("#"):
			comment = stripped
			continue
		var flags: PackedInt32Array = Autoplay.parse_inputs(stripped)
		for i: int in flags.size():
			if not Sim.running:
				break
			played += _run(PackedInt32Array([flags[i]]))
			if every > 0 and played % every == 0:
				print("    t%5d %s" % [played, _hero_text()])
		if flags.size() > 0:
			print("L%3d t%5d %s | %s %s" % [line_no, played, _hero_text(), " ".join(log_lines), comment])
			log_lines.clear()
		if not Sim.running:
			break
	print("PROBE END t%d score %d completion %d%% lives %d hearts %d weapon %d letters %d spots %d/%d items %d/%d" % [
		played, Game.score, Game.completion_percent(), Game.lives, Game.hearts, Game.weapon, Game.letters,
		Game.spots_opened, Game.spots_total, Game.items_collected, Game.items_total])


## Route-building aid: CAMPAIGN_ADAPT=<route file> CAMPAIGN_WEAPON=<Defs.Weapon> [CAMPAIGN_DIFF=expert] replays a route
## with another starting weapon. A swing locks the hero's input for the weapon's recovery (club 2 ticks, hammer
## and axe 6, swirling axe 12), so after every swing the route is padded (or trimmed) by the difference: the rest of
## the input then meets the hero in the same state, only the world has moved on a few ticks more. With
## CAMPAIGN_ABSORB=1 the padded ticks are won back where the route lets him stand still (an idle input while he is
## at rest is dropped), which puts the world back in step with him (it helps some routes and breaks others). The adapted
## input is written to build/adapt/<route file> with the outcome; whether the level still works with it is for the
## replay to show.
func test_adapt_route_to_weapon() -> void:
	var file: String = OS.get_environment("CAMPAIGN_ADAPT")
	assert_true(file.is_empty() or ROUTES.has(file), "a described route file")
	if file.is_empty():
		return
	var mode: String = EXPERT if OS.get_environment("CAMPAIGN_DIFF") == EXPERT else BEGINNER
	var spec: Dictionary = ROUTES[file]
	var weapon: int = OS.get_environment("CAMPAIGN_WEAPON").to_int()
	var source_text: String = FileAccess.get_file_as_string(ROUTE_DIR + file)
	var original: PackedInt32Array = Autoplay.parse_inputs(source_text)
	# The route's comment lines, by the index of the input they precede (kept in the adapted file).
	var comments: Dictionary = {}
	var count: int = 0
	for line: String in source_text.split("\n"):
		if line.strip_edges().begins_with("#"):
			var notes: PackedStringArray = comments.get(count, PackedStringArray())
			notes.append(line.strip_edges())
			comments[count] = notes
		else:
			count += Autoplay.parse_inputs(line).size()
	Game.new_game(_difficulty(mode))
	if spec.has("source"):
		Game.warp_return_level = StringName(str(spec["source"]))
	Game.set_weapon(weapon)
	await _enter(StringName(str(spec["level"])))
	# The weapon the route was recorded with at each point: its starting weapon, then whatever is picked up (a
	# pick-up gives the replay the same weapon).
	var recorded: Array[int] = [int(spec.get("weapon", Defs.Weapon.CLUB))]
	var state: Dictionary = {"index": 0, "fill": 0, "swings": 0, "padded": 0, "debt": 0, "absorbed": 0}
	var out: PackedInt32Array = PackedInt32Array()
	var on_strike: Callable = func(_strike: int, used: int) -> void:
		var extra: int = Tuning.WEAPON_LOCK[used] - Tuning.WEAPON_LOCK[recorded[0]]
		state["swings"] += 1
		state["padded"] += extra
		if extra > 0:
			state["fill"] += extra
			state["debt"] += extra
		elif extra < 0:
			state["index"] += -extra
	var on_weapon: Callable = func(new_weapon: int) -> void: recorded[0] = new_weapon
	_connect(Events.player_struck, on_strike)
	_connect(Game.weapon_changed, on_weapon)
	var out_index: PackedInt32Array = PackedInt32Array()
	var absorb: bool = OS.get_environment("CAMPAIGN_ABSORB") != ""
	GameInput.set_scripted(func(_tick: int) -> int:
		# Win the padded ticks back where the route lets the hero stand still: an idle input while he is at rest
		# (no velocity, no swing) changes nothing for him, so dropping it puts the world back in step.
		var hero: PlayerBase = Game.level.player if Game.level != null else null
		while absorb and int(state["debt"]) > 0 and int(state["fill"]) == 0 and hero != null and hero.xvel == 0 				and hero.yvel == 0 and hero.swing_lock == 0 and int(state["index"]) + 1 < original.size() 				and original[int(state["index"])] == 0 and original[int(state["index"]) + 1] == 0:
			state["index"] += 1
			state["debt"] -= 1
			state["absorbed"] += 1
		var i: int = state["index"]
		var value: int = original[i] if i < original.size() else 0
		if int(state["fill"]) > 0:
			state["fill"] -= 1
			out_index.append(-1)
		else:
			state["index"] = i + 1
			out_index.append(i)
		out.append(value)
		return value
	)
	var level: LevelBase = Game.level
	var played: int = 0
	var trace: bool = OS.get_environment("CAMPAIGN_TRACE") != ""
	while int(state["index"]) < original.size() and Sim.running and Game.level == level:
		var before: int = state["index"]
		Sim.step(1)
		played += 1
		if trace and int(state["index"]) != before:
			print("    t%5d %s" % [int(state["index"]), _hero_text()])
	GameInput.clear_scripted()
	var result: String = "%s with weapon %d (%s): %d ticks (route %d), %d swings, %+d ticks padded, %d won back, exits %s, deaths %d, hurt %d, lives %d" % [
		file, weapon, mode, played, original.size(), state["swings"], state["padded"], state["absorbed"],
		str(_exit_kinds), _count(&"player_died"), _count(&"player_hurt"), Game.lives]
	print("ADAPT " + result)
	var lines: PackedStringArray = PackedStringArray(["# Adapted by test_adapt_route_to_weapon: " + result])
	# Runs of equal input as "ticks:KEYS", several per line, a new line at each of the route's comments.
	var runs: PackedStringArray = PackedStringArray()
	var run_value: int = -1
	var run_length: int = 0
	var shown: Dictionary = {}
	for t: int in out.size() + 1:
		var at: int = out_index[t] if t < out.size() else -1
		var comment: bool = at >= 0 and comments.has(at) and not shown.has(at)
		if t < out.size() and out[t] == run_value and not comment:
			run_length += 1
			continue
		if run_length > 0:
			runs.append("%d:%s" % [run_length, _keys(run_value)])
		if comment or t == out.size() or ",".join(runs).length() > 100:
			if not runs.is_empty():
				lines.append(",".join(runs))
			runs.clear()
		if comment:
			shown[at] = true
			lines.append_array(comments[at] as PackedStringArray)
		if t < out.size():
			run_value = out[t]
			run_length = 1
	var dir: String = ProjectSettings.globalize_path("res://build/adapt")
	DirAccess.make_dir_recursive_absolute(dir)
	var handle: FileAccess = FileAccess.open(dir + "/" + file, FileAccess.WRITE)
	if handle != null:
		handle.store_string("\n".join(lines) + "\n")
		handle.close()


## Route-building aid: CAMPAIGN_REPAIR=<route file> CAMPAIGN_WEAPON=<Defs.Weapon> [CAMPAIGN_DIFF=expert] re-times a
## route for another starting weapon. It replays the route with the weapon it was recorded with (the baseline) and
## with the new one; at the first tick where the hero is not where the baseline has him, it tries a few ticks more or
## less of each movement run around that tick, paid back by the standing pause that follows (so the rest of the
## route keeps its timing), and keeps the change that puts him back on the baseline when he next stands still. It
## repeats until the route reaches its end the documented way, or no change helps. The result goes to
## build/adapt/<route file> with the outcome.
func test_repair_route_for_weapon() -> void:
	var file: String = OS.get_environment("CAMPAIGN_REPAIR")
	assert_true(file.is_empty() or ROUTES.has(file), "a described route file")
	if file.is_empty():
		return
	var mode: String = EXPERT if OS.get_environment("CAMPAIGN_DIFF") == EXPERT else BEGINNER
	var spec: Dictionary = ROUTES[file]
	var weapon: int = OS.get_environment("CAMPAIGN_WEAPON").to_int()
	var recorded: int = int(spec.get("weapon", Defs.Weapon.CLUB))
	var source_text: String = FileAccess.get_file_as_string(ROUTE_DIR + file)
	var original: PackedInt32Array = Autoplay.parse_inputs(source_text)
	var baseline: Array[PackedInt32Array] = await _record_replay(spec, mode, recorded, original, original.size())
	var leaves: StringName = StringName(str(spec.get("leaves", "")))
	var flags: PackedInt32Array = original.duplicate()
	var fixes: PackedStringArray = PackedStringArray()
	var limit: int = maxi(OS.get_environment("CAMPAIGN_REPAIR_STEPS").to_int(), 40)
	# Tick up to which the hero is back on the baseline (drifts before it were repaired).
	var synced: int = 0
	for step: int in limit:
		var run: Array[PackedInt32Array] = await _record_replay(spec, mode, weapon, flags, flags.size())
		var outcome: Dictionary = _replay_outcome(run)
		if outcome["deaths"] == 0 and (leaves == &"" or outcome["exit"]):
			print("REPAIR %s: success after %d fixes: %s" % [file, fixes.size(), ", ".join(fixes)])
			_write_route(file, flags, source_text, "repaired for weapon %d (%s) after %d fixes" % [
				weapon, mode, fixes.size()])
			assert_true(true)
			return
		var drift: int = _first_drift(baseline, run, synced)
		if drift < 0:
			print("REPAIR %s: no drift from the baseline, but it fails (%s)" % [file, str(outcome)])
			break
		var rest: int = _next_rest(baseline, drift)
		if rest < 0:
			print("REPAIR %s: drift at tick %d with no rest after it" % [file, drift])
			break
		var fixed: PackedInt32Array = PackedInt32Array()
		# Aim at the next standing point, or one of the two after it.
		for attempt: int in 3:
			fixed = await _try_fixes(spec, mode, weapon, flags, baseline, drift, rest)
			if not fixed.is_empty():
				break
			var later: int = _next_rest(baseline, rest + 1)
			if later < 0:
				break
			rest = later
		if fixed.is_empty():
			print("REPAIR %s: drift at tick %d (hero %s, baseline %s), nothing re-syncs it by tick %d" % [
				file, drift, str(run[drift]), str(baseline[drift]), rest])
			_write_route(file, flags, source_text, "PARTIAL repair for weapon %d (%s): stuck at tick %d" % [
				weapon, mode, drift])
			break
		fixes.append("t%d" % drift)
		flags = fixed
		synced = rest + 1
	assert_true(true)


## Replay `flags` from a fresh run with `weapon` up to `until` ticks; one row per tick: [x, y, xvel, yvel, dead,
## deaths so far, exit reached (0/1), facing].
func _record_replay(spec: Dictionary, mode: String, weapon: int, flags: PackedInt32Array,
		until: int) -> Array[PackedInt32Array]:
	after_each()
	Game.new_game(_difficulty(mode))
	if spec.has("source"):
		Game.warp_return_level = StringName(str(spec["source"]))
	Game.set_weapon(weapon)
	await _enter(StringName(str(spec["level"])))
	var rows: Array[PackedInt32Array] = []
	var index: Array[int] = [0]
	GameInput.set_scripted(func(_tick: int) -> int:
		var value: int = flags[index[0]] if index[0] < flags.size() else 0
		index[0] += 1
		return value
	)
	var level: LevelBase = Game.level
	while rows.size() < until and Sim.running and Game.level == level:
		Sim.step(1)
		var hero: PlayerBase = level.player if is_instance_valid(level) else null
		if hero == null:
			break
		rows.append(PackedInt32Array([hero.sim_pos.x, hero.sim_pos.y, hero.xvel, hero.yvel, int(hero.dead),
			_count(&"player_died"), int(not _exit_kinds.is_empty()), hero.facing]))
	GameInput.clear_scripted()
	return rows


func _replay_outcome(rows: Array[PackedInt32Array]) -> Dictionary:
	if rows.is_empty():
		return {"deaths": 0, "exit": false}
	var last: PackedInt32Array = rows[-1]
	return {"deaths": last[5], "exit": last[6] == 1, "ticks": rows.size()}


## First tick from `from` on where the hero is not where the baseline has him (-1 = none).
func _first_drift(baseline: Array[PackedInt32Array], run: Array[PackedInt32Array], from: int = 0) -> int:
	for t: int in range(from, mini(baseline.size(), run.size())):
		if baseline[t][0] != run[t][0] or baseline[t][1] != run[t][1]:
			return t
	return -1 if run.size() >= baseline.size() else mini(baseline.size(), run.size())


## The last tick of the first stretch after `from` + 4 in which the baseline hero stands still for at least 3
## ticks (-1 = none): the latest point to meet him again before he moves on.
func _next_rest(baseline: Array[PackedInt32Array], from: int) -> int:
	var found: int = -1
	for t: int in range(from + 4, baseline.size()):
		var still: bool = true
		for k: int in 3:
			var row: PackedInt32Array = baseline[t - k]
			if row[2] != 0 or row[3] != 0 or row[0] != baseline[t][0] or row[1] != baseline[t][1] or row[4] != 0:
				still = false
		if still:
			found = t
		elif found >= 0:
			return found
	return found


## Try runs around `drift` a few ticks longer or shorter, paid back by a standing run before `rest` (so the rest of
## the route keeps its timing), then short taps left or right in a long pause for the last few pixels; returns the
## first input that brings the hero back onto the baseline at `rest`, facing the same way (empty when none does).
func _try_fixes(spec: Dictionary, mode: String, weapon: int, flags: PackedInt32Array,
		baseline: Array[PackedInt32Array], drift: int, rest: int) -> PackedInt32Array:
	var runs: Array[Vector3i] = _runs(flags)  # x = start, y = length, z = value
	var at: int = 0
	for i: int in runs.size():
		if runs[i].x <= drift and drift < runs[i].x + runs[i].y:
			at = i
	var deltas: Array[int] = [4, 3, 5, 2, 6, 1, 8, 10, -1, -2, -3, -4, 12, 7, 9, -5, -6, 0]
	var target: PackedInt32Array = baseline[rest]
	for k: int in range(maxi(at - 3, 0), mini(at + 4, runs.size())):
		var run: Vector3i = runs[k]
		if run.z == 0 or run.x > rest:
			continue
		# The standing runs that may pay the ticks back: idle runs of 3+ ticks after this one that start by `rest`,
		# the longest first.
		var payers: Array[int] = []
		for j: int in range(k + 1, runs.size()):
			if runs[j].x > rest:
				break
			if runs[j].z == 0 and runs[j].y >= 3:
				payers.append(j)
		payers.sort_custom(func(a: int, b: int) -> bool: return runs[a].y > runs[b].y)
		for pay: int in payers.slice(0, 3):
			var best_delta: int = 0
			var best_dx: int = 1 << 20
			for delta: int in deltas:
				if run.y + delta < 1 or runs[pay].y - delta < 1:
					continue
				var candidate: PackedInt32Array = _resize_runs(runs, k, delta, pay, -delta)
				var check: Array[PackedInt32Array] = await _record_replay(spec, mode, weapon, candidate, rest + 1)
				if OS.get_environment("CAMPAIGN_REPAIR_DEBUG") != "":
					print("      run %d %+d pay %d: %s vs %s" % [k, delta, pay,
							str(check[rest]) if check.size() > rest else "short", str(target)])
				if check.size() <= rest or check[rest][5] != 0 or check[rest][1] != target[1] or check[rest][2] != 0:
					continue
				var dx: int = check[rest][0] - target[0]
				if dx == 0 and delta != 0 and check[rest][7] == target[7]:
					print("    fix at t%d: run %d (%d x %s) %+d, pause at t%d %+d -> on the baseline at t%d" % [
						drift, k, run.y, _keys(run.z), delta, runs[pay].x, -delta, rest])
					return candidate
				if absi(dx) < absi(best_dx):
					best_dx = dx
					best_delta = delta
			if absi(best_dx) > 12:
				continue
			var fixed: PackedInt32Array = await _try_taps(spec, mode, weapon, runs, k, best_delta, pay, best_dx,
					target, rest)
			if not fixed.is_empty():
				print("    fix at t%d: run %d (%d x %s) %+d, taps in the pause at t%d -> on the baseline at t%d" % [
					drift, k, run.y, _keys(run.z), best_delta, runs[pay].x, rest])
				return fixed
	return PackedInt32Array()


## The last pixels: patterns of short taps (8 idle ticks apart) in the paying pause once the hero stands, with time
## to stop again; a final 1-tick tap turns him the way the baseline faces when the taps went the other way.
func _try_taps(spec: Dictionary, mode: String, weapon: int, runs: Array[Vector3i], k: int, delta: int, pay: int,
		dx: int, target: PackedInt32Array, rest: int) -> PackedInt32Array:
	var pause_start: int = runs[pay].x + (delta if k < pay else 0)
	var pause_end: int = mini(pause_start + runs[pay].y - delta, rest)
	if pause_end - pause_start < 30:
		return PackedInt32Array()
	var base: PackedInt32Array = _resize_runs(runs, k, delta, pay, -delta)
	var toward: int = Defs.IN_RIGHT if dx < 0 else Defs.IN_LEFT
	var away: int = Defs.IN_LEFT if dx < 0 else Defs.IN_RIGHT
	var face: int = Defs.IN_RIGHT if target[7] > 0 else Defs.IN_LEFT
	for taps: Array in [[1], [1, 1], [2], [2, 1], [1, 1, 1], [3], [2, 2], [3, 1]]:
		for side: int in [toward, away]:
			var candidate: PackedInt32Array = base.duplicate()
			var at_tick: int = pause_start + 10
			var plan: Array = taps.duplicate()
			var sides: Array[int] = []
			for i: int in plan.size():
				sides.append(side)
			if side != face:
				plan.append(1)
				sides.append(face)
			for i: int in plan.size():
				for n: int in int(plan[i]):
					candidate[at_tick + n] = sides[i]
				at_tick += int(plan[i]) + 8
			if at_tick + 10 > pause_end:
				continue
			var check: Array[PackedInt32Array] = await _record_replay(spec, mode, weapon, candidate, rest + 1)
			if check.size() > rest and check[rest][5] == 0 and check[rest][0] == target[0] 					and check[rest][1] == target[1] and check[rest][2] == 0 and check[rest][7] == target[7]:
				return candidate
	return PackedInt32Array()


func _runs(flags: PackedInt32Array) -> Array[Vector3i]:
	var runs: Array[Vector3i] = []
	for t: int in flags.size():
		if runs.is_empty() or runs[-1].z != flags[t]:
			runs.append(Vector3i(t, 1, flags[t]))
		else:
			runs[-1].y += 1
	return runs


## The runs as flags, run `a` longer by `delta_a` (its first `wait` ticks idle) and run `b` by `delta_b`.
func _resize_runs(runs: Array[Vector3i], a: int, delta_a: int, b: int, delta_b: int,
		wait: int = 0) -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	for i: int in runs.size():
		var length: int = runs[i].y + (delta_a if i == a else 0) + (delta_b if i == b else 0)
		for n: int in length:
			out.append(0 if i == a and n < wait else runs[i].z)
	return out


## Write `flags` as a route file to build/adapt/<file>, with the original's comments at the same tick indices.
func _write_route(file: String, flags: PackedInt32Array, source_text: String, note: String) -> void:
	var comments: Dictionary = {}
	var count: int = 0
	for line: String in source_text.split("\n"):
		if line.strip_edges().begins_with("#"):
			var notes: PackedStringArray = comments.get(count, PackedStringArray())
			notes.append(line.strip_edges())
			comments[count] = notes
		else:
			count += Autoplay.parse_inputs(line).size()
	var lines: PackedStringArray = PackedStringArray(["# " + note])
	var runs: PackedStringArray = PackedStringArray()
	var run_value: int = -1
	var run_length: int = 0
	for t: int in flags.size() + 1:
		var comment: bool = comments.has(t)
		if t < flags.size() and flags[t] == run_value and not comment:
			run_length += 1
			continue
		if run_length > 0:
			runs.append("%d:%s" % [run_length, _keys(run_value)])
		if comment or t == flags.size() or ",".join(runs).length() > 100:
			if not runs.is_empty():
				lines.append(",".join(runs))
			runs.clear()
		if comment:
			lines.append_array(comments[t] as PackedStringArray)
		if t < flags.size():
			run_value = flags[t]
			run_length = 1
	var dir: String = ProjectSettings.globalize_path("res://build/adapt")
	DirAccess.make_dir_recursive_absolute(dir)
	var handle: FileAccess = FileAccess.open(dir + "/" + file, FileAccess.WRITE)
	if handle != null:
		handle.store_string("\n".join(lines) + "\n")
		handle.close()


func _keys(flags: int) -> String:
	var keys: String = ""
	for pair: Array in [[Defs.IN_LEFT, "L"], [Defs.IN_RIGHT, "R"], [Defs.IN_UP, "U"], [Defs.IN_DOWN, "D"],
			[Defs.IN_FIRE, "F"], [Defs.IN_LOOK, "K"]]:
		if flags & int(pair[0]):
			keys += str(pair[1])
	return keys


# =================================================================================================================
# Playing routes
# =================================================================================================================

## Play every route whose file name starts with `prefix` on each of its modes (chained entries are played by the
## route that leads into them).
func _play_routes(prefix: String) -> void:
	var probing: bool = _dev_mode()
	for file: String in ROUTES:
		if not file.begins_with(prefix) or bool(ROUTES[file].get("chained", false)):
			continue
		for mode: String in ROUTES[file]["modes"]:
			if probing:
				assert_true(true, "route checks are skipped while probing")
				continue
			await _play_route(file, mode)
			after_each()


## One route from a fresh run (and the routes chained to it), with every check of its entry.
func _play_route(file: String, mode: String) -> void:
	var spec: Dictionary = ROUTES[file]
	var difficulty: int = _difficulty(mode)
	var label: String = "%s (%s)" % [file, mode]
	Game.new_game(difficulty)
	if spec.has("source"):
		Game.warp_return_level = StringName(str(spec["source"]))
	var level_id: StringName = StringName(str(spec["level"]))
	await _enter(level_id)
	var played: int = await _play_stage(file, mode, label)
	var chained: String = str(spec.get("then", ""))
	if chained != "" and Flow.current_screen == Flow.SCREEN_LEVEL and Game.level != null:
		var played_next: int = await _play_stage(chained, mode, "%s (%s)" % [chained, mode], played)
		played += played_next
	await _check_tally(spec, mode, label)


## Play the route `file` in the running level and check its entry; returns the ticks played. `before` is the
## tick count of the stage that led here (for the `pair_ticks` check).
func _play_stage(file: String, mode: String, label: String, before: int = 0) -> int:
	var spec: Dictionary = ROUTES[file]
	assert_eq(Game.level_id, StringName(str(spec["level"])), "%s starts in %s" % [label, spec["level"]])
	if spec.has("weapon"):
		Game.set_weapon(int(spec["weapon"]))
	var expect: Dictionary = spec.get("expect", {})
	_reset_watch()
	_watch_wind = expect.has("min_wind")
	_watch_view = expect.has("view_sank")
	_watch_embers = expect.has("embers")
	var lives: int = Game.lives
	var items_total: int = Game.items_total
	var spots_total: int = Game.spots_total
	var start_view_y: int = Game.level.get_view_rect().position.y
	_problems = null
	if bool(expect.get("no_warnings", false)):
		_start_counting_problems()
	var flags: PackedInt32Array = Autoplay.parse_inputs(_route_text(spec, file, mode))
	assert_true(flags.size() > 100, "%s is a real input script" % label)
	var played: int = _run(flags)
	_stop_counting_problems()
	print("    %s: %d ticks, score %d, completion %d %%, spots %d/%d, items %d/%d, secrets %d, kills %d, hurt %d, deaths %d, lives %d, weapon %d, letters %s" % [
		label, played, Game.score, Game.completion_percent(), Game.spots_opened, Game.spots_total,
		Game.items_collected, Game.items_total, _count(&"secret_found"), _count(&"enemy_killed"),
		_count(&"player_hurt"), _count(&"player_died"), Game.lives, Game.weapon, str(_letters.keys())])
	_check_expectations(label, expect, played, lives, start_view_y, before)
	var leaves: String = str(spec.get("leaves", ""))
	if leaves == "":
		return played
	assert_eq(_exit_kinds, [StringName(leaves)] as Array[StringName], "%s leaves through its %s after %d ticks" % [
		label, leaves, played])
	await _settle()
	var after: String = str(spec.get("after", ""))
	if after == "tally":
		assert_eq(Flow.current_screen, Flow.SCREEN_TALLY, "%s: the tally follows" % label)
	elif after.begins_with("level:"):
		var next: StringName = StringName(after.get_slice(":", 1))
		assert_eq(Flow.current_screen, Flow.SCREEN_LEVEL, "%s: a stage follows without a tally" % label)
		assert_eq(Game.level_id, next, "%s leads into %s" % [label, next])
		if Levels.parent_level(next, Game.difficulty) != &"" and Game.level_id == next:
			assert_false(Game.has_glider, "%s: the glider is gone at the end of the first half" % label)
			assert_true(Game.items_total >= items_total and Game.spots_total >= spots_total,
					"%s: the linked stage adds to the completion totals" % label)
		_set_view()
	return played


## A bonus stage's or the ending's tally: what Flow.finish_tally leads to (as the tally screen calls it).
func _check_tally(spec: Dictionary, mode: String, label: String) -> void:
	var targets: Dictionary = spec.get("tally_to", {})
	if not targets.has(mode) or Flow.current_screen != Flow.SCREEN_TALLY:
		return
	var difficulty: int = _difficulty(mode)
	var source: StringName = StringName(str(spec.get("source", "")))
	var clears: int = int(Save.get_level_result(source, difficulty)["clears"]) if source != &"" else 0
	Flow.finish_tally()
	await _settle()
	var target: String = str(targets[mode])
	if target.begins_with("map:"):
		assert_eq(Flow.current_screen, Flow.SCREEN_WORLD_MAP, "%s: the tally leads to the map" % label)
		assert_eq(StringName(str(Flow.args.get("level_id", ""))), StringName(target.get_slice(":", 1)),
				"%s: the map shows the next level" % label)
	elif target == "expert_wall":
		assert_eq(Flow.current_screen, Flow.SCREEN_EXPERT_WALL, "%s: Beginner meets the expert wall" % label)
	elif target == "the_end":
		assert_eq(Flow.current_screen, Flow.SCREEN_THE_END, "%s: The End follows" % label)
		assert_true(Save.is_game_completed(difficulty), "%s: the game is completed" % label)
	if source != &"":
		assert_eq(int(Save.get_level_result(source, difficulty)["clears"]), clears + 1,
				"%s: the bonus stage's tally ends its source level %s" % [label, source])
		assert_eq(int(Save.get_level_result(StringName(str(spec["level"])), difficulty)["clears"]), 0,
				"%s: nothing is recorded for the bonus stage itself" % label)
		assert_false(Save.is_game_completed(difficulty), "%s: a bonus stage never ends the game" % label)


func _check_expectations(label: String, expect: Dictionary, played: int, lives: int, start_view_y: int,
		before: int) -> void:
	assert_eq(_count(&"player_died"), int(expect.get("deaths", 0)), "%s: deaths" % label)
	if expect.has("hurts"):
		assert_eq(_count(&"player_hurt"), int(expect["hurts"]), "%s: hits taken" % label)
	if expect.has("max_hurts"):
		assert_true(_count(&"player_hurt") <= int(expect["max_hurts"]), "%s: hits taken %d" % [
			label, _count(&"player_hurt")])
	if expect.has("respawns"):
		assert_eq(_count(&"level_respawned"), int(expect["respawns"]), "%s: respawns" % label)
	# No life lost; a 1UP on the way (or an extra life by score) may add one.
	assert_true(Game.lives >= lives + int(expect.get("lives_gained", 0)), "%s: lives %d -> %d" % [
		label, lives, Game.lives])
	if expect.has("weapon_end"):
		assert_eq(Game.weapon, int(expect["weapon_end"]), "%s: weapon at the end" % label)
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
		assert_eq(_words, int(expect["words"]), "%s: completed letter words (jackpots)" % label)
	if expect.has("ticks"):
		assert_true(played >= int(expect["ticks"][0]) and played <= int(expect["ticks"][1]), "%s: %d ticks" % [
			label, played])
	if expect.has("pair_ticks"):
		var both: int = before + played
		assert_true(both >= int(expect["pair_ticks"][0]) and both <= int(expect["pair_ticks"][1]),
				"%s: both halves take %d ticks" % [label, both])
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
		assert_true(_deepest_view_y - start_view_y >= int(expect["view_sank"]), "%s: the view sank %d px" % [
			label, _deepest_view_y - start_view_y])
	if expect.has("embers"):
		assert_true(_embers_seen.size() >= int(expect["embers"][0]), "%s: embers fell: %d" % [
			label, _embers_seen.size()])
		assert_true(_embers_close.size() >= int(expect["embers"][1]), "%s: embers beside the hero: %d" % [
			label, _embers_close.size()])
	if bool(expect.get("no_enemies", false)):
		assert_eq(_count(&"enemy_killed") + _count(&"player_hurt"), 0, "%s: nothing to fight" % label)
	if expect.has("hero_min_x") or expect.has("hero_y"):
		var hero: PlayerBase = Game.level.player if Game.level != null else null
		assert_not_null(hero)
		if hero != null:
			assert_true(hero.sim_pos.x >= int(expect.get("hero_min_x", 0)), "%s: the hero got to x %d" % [
				label, hero.sim_pos.x])
			if expect.has("hero_y"):
				assert_eq(hero.sim_pos.y, int(expect["hero_y"]), "%s: the hero stands on the far side" % label)
	if bool(expect.get("no_warnings", false)) and _problems != null:
		assert_eq(_problems.count, 0, "%s: no engine warning or error (first: %s)" % [label, _problems.first])


# =================================================================================================================
# The campaign
# =================================================================================================================

## One run through the whole campaign of `mode`, the way a player goes: each map stop's level is started as the
## world map starts it, its route played with the state the run carries, the tally finished as the tally screen
## finishes it. Checks the unlocks and records of the save file and how the run ends.
func _play_campaign(mode: String) -> void:
	if _dev_mode():
		assert_true(true, "campaign runs are skipped while probing")
		return
	var difficulty: int = _difficulty(mode)
	Save.reset()
	_weapon_overrides.clear()
	Game.new_game(difficulty)
	var steps: Array = CAMPAIGN[mode]
	var stops: Array = MAP[mode]
	var expected_stop: int = 0
	await _idle()
	assert_eq(Levels.first_level(), stops[0])
	var total_ticks: int = 0
	for i: int in steps.size():
		var level_id: StringName = StringName(str(steps[i][0]))
		var file: String = str(steps[i][1])
		var label: String = "campaign %s: %s" % [mode, file]
		if i == 0 or Flow.current_screen == Flow.SCREEN_WORLD_MAP:
			# The map shows the stop the run has reached; it starts that level.
			var shown: StringName = StringName(str(Flow.args.get("level_id", level_id))) if i > 0 else level_id
			assert_eq(shown, level_id, "%s: the map leads to %s" % [label, level_id])
			assert_true(i == 0 or Save.is_level_unlocked(level_id, difficulty), "%s: %s is unlocked" % [label, level_id])
			await _enter(level_id)
		assert_eq(Game.level_id, level_id, "%s: the run is in %s" % [label, level_id])
		if Game.level_id != level_id:
			return
		var lives: int = Game.lives
		var played: int = await _play_campaign_stage(file, mode, label)
		total_ticks += played
		var chained: String = str(ROUTES[file].get("then", ""))
		while chained != "" and Flow.current_screen == Flow.SCREEN_LEVEL:
			total_ticks += await _play_campaign_stage(chained, mode, "campaign %s: %s" % [mode, chained])
			chained = str(ROUTES[chained].get("then", ""))
		assert_true(Game.lives >= lives, "%s: no life lost (%d -> %d)" % [label, lives, Game.lives])
		if Flow.current_screen != Flow.SCREEN_LEVEL:
			# The tally of the stop (a warp or a trophy leads into the next stage at once: its step plays it).
			assert_eq(Flow.current_screen, Flow.SCREEN_TALLY, "%s: the tally follows" % label)
			if Flow.current_screen != Flow.SCREEN_TALLY:
				return
			Flow.finish_tally()
			await _settle()
		# The map stops cleared so far are recorded in order, each once, with the run's score.
		while expected_stop < stops.size() and int(Save.get_level_result(stops[expected_stop], difficulty)["clears"]) > 0:
			var result: Dictionary = Save.get_level_result(stops[expected_stop], difficulty)
			assert_eq(int(result["clears"]), 1, "%s: %s is recorded once" % [label, stops[expected_stop]])
			assert_true(int(result["score"]) > 0, "%s: %s keeps the score" % [label, stops[expected_stop]])
			expected_stop += 1
		for later: int in range(expected_stop, stops.size()):
			assert_eq(int(Save.get_level_result(stops[later], difficulty)["clears"]), 0,
					"%s: %s is not cleared yet" % [label, stops[later]])
		if expected_stop < stops.size() and Flow.current_screen == Flow.SCREEN_WORLD_MAP:
			assert_true(Save.is_level_unlocked(stops[expected_stop], difficulty), "%s: %s is unlocked" % [
				label, stops[expected_stop]])
	print("    campaign %s: %d ticks (%.1f min), score %d, lives %d, weapon %d, screen %s" % [
		mode, total_ticks, total_ticks / Tuning.TICK_HZ / 60.0, Game.score, Game.lives, Game.weapon,
		Flow.current_screen])
	assert_eq(expected_stop, stops.size(), "%s: every map stop was cleared" % mode)
	var gaps: Array[String] = []
	gaps.assign(WEAPON_GAPS[mode])
	assert_eq(_weapon_overrides, gaps, "%s: the routes played with their recorded weapon instead of the carried one" % mode)
	for stop: StringName in stops:
		assert_eq(int(Save.get_level_result(stop, difficulty)["clears"]), 1, "%s: %s cleared once" % [mode, stop])
	assert_true(Save.get_high_score() >= Game.score and Game.score > 0, "%s: the run's score is the high score" % mode)
	if mode == BEGINNER:
		assert_eq(Flow.current_screen, Flow.SCREEN_EXPERT_WALL, "a Beginner run ends at the expert wall")
		assert_false(Save.is_game_completed(difficulty), "a Beginner run does not complete the game")
	else:
		assert_eq(Flow.current_screen, Flow.SCREEN_THE_END, "an Expert run ends with The End")
		assert_true(Save.is_game_completed(difficulty), "an Expert run completes the game")


## Play one stage of the campaign run with the state the run carries; the checks that do not depend on a fresh
## start: the stage ends the documented way, without a death.
func _play_campaign_stage(file: String, mode: String, label: String) -> int:
	var spec: Dictionary = ROUTES[file]
	assert_eq(Game.level_id, StringName(str(spec["level"])), "%s plays in %s" % [label, spec["level"]])
	var recorded: int = int(spec.get("weapon", Defs.Weapon.CLUB))
	if Game.weapon != recorded and (WEAPON_GAPS[mode] as Array).has(file):
		_weapon_overrides.append(file)
		print("    %s: weapon %d handed over for the route (the run carries %d)" % [label, recorded, Game.weapon])
		Game.set_weapon(recorded)
	_reset_watch()
	var flags: PackedInt32Array = Autoplay.parse_inputs(_route_text(spec, file, mode))
	var played: int = _run(flags)
	print("    %s: %d ticks, score %d, lives %d, hurt %d, weapon %d, letters %d, completion %d %%" % [
		label, played, Game.score, Game.lives, _count(&"player_hurt"), Game.weapon, Game.letters,
		Game.completion_percent()])
	assert_eq(_count(&"player_died"), 0, "%s: no death" % label)
	var leaves: String = str(spec.get("leaves", ""))
	assert_eq(_exit_kinds, [StringName(leaves)] as Array[StringName], "%s leaves through its %s after %d ticks" % [
		label, leaves, played])
	await _settle()
	if Flow.current_screen == Flow.SCREEN_LEVEL:
		_set_view()
	return played


# =================================================================================================================
# Helpers
# =================================================================================================================

## The input text of a route: its file, after the prefix of a side path.
func _route_text(spec: Dictionary, file: String, mode: String) -> String:
	var text: String = ""
	if spec.has("prefix"):
		var main: String = str(spec["prefix"][0])
		if main == "@route":
			main = "%s.expert.inputs" % spec["level"] if mode == EXPERT else "%s.inputs" % spec["level"]
			if not FileAccess.file_exists(ROUTE_DIR + main):
				main = "%s.inputs" % spec["level"]
		var marker: String = str(spec["prefix"][1])
		var lines: PackedStringArray = PackedStringArray()
		var found: bool = false
		for line: String in FileAccess.get_file_as_string(ROUTE_DIR + main).split("\n"):
			if line.strip_edges().begins_with(marker):
				found = true
				break
			lines.append(line)
		assert_true(found, "%s has the section '%s'" % [main, marker])
		text = "\n".join(lines) + "\n"
	return text + FileAccess.get_file_as_string(ROUTE_DIR + file)


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


## Play input flags one tick after the other until they end or the level is left (exit, warp, trophy: the level
## hands over to Flow, which stops the clock); returns the ticks played.
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
		if Game.level != null and Game.level == level:
			if _watch_wind:
				_max_wind = maxi(_max_wind, Game.level.wind)
			if _watch_view:
				_deepest_view_y = maxi(_deepest_view_y, Game.level.get_view_rect().position.y)
			if _watch_embers:
				_note_embers(Game.level)
	GameInput.clear_scripted()
	return played


## Embers that came down beside the hero: within 24 px of him and between his head and his feet.
func _note_embers(level: LevelBase) -> void:
	if level.player == null:
		return
	var hero: Vector2i = level.player.sim_pos
	for entity: SimEntity in level.get_kind(Defs.Kind.ENEMY_PROJECTILE):
		if not entity is EnemyEmber:
			continue
		var id: int = entity.get_instance_id()
		_embers_seen[id] = true
		var rel: Vector2i = entity.sim_pos - hero
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
	_connect(Game.letters_completed, _on_word)


func _connect(signal_ref: Signal, callable: Callable) -> void:
	signal_ref.connect(callable)
	_connections.append([signal_ref, callable])


func _reset_watch() -> void:
	_counts.clear()
	_letters.clear()
	_words = 0
	_boss_hits = 0
	_glider_carried = false
	_glider_flown = false
	_exit_kinds.clear()
	_max_wind = 0
	_deepest_view_y = 0
	_embers_seen.clear()
	_embers_close.clear()
	_watch_wind = false
	_watch_view = false
	_watch_embers = false


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


## True while one of the route-building aids runs (the route and campaign tests are skipped then).
func _dev_mode() -> bool:
	return not OS.get_environment("CAMPAIGN_PROBE").is_empty() or not OS.get_environment("CAMPAIGN_ADAPT").is_empty() 			or not OS.get_environment("CAMPAIGN_REPAIR").is_empty()


func _difficulty(mode: String) -> int:
	return Defs.Difficulty.EXPERT if mode == EXPERT else Defs.Difficulty.BEGINNER


func _count(signal_name: StringName) -> int:
	return int(_counts.get(signal_name, 0))


func _on_event(signal_name: StringName) -> void:
	_counts[signal_name] = _count(signal_name) + 1


func _on_item(item_id: StringName, index: int, _points: int, _pos: Vector2i) -> void:
	if item_id == &"items/letter":
		_letters[index] = true


func _on_enemy_hit(enemy: EnemyBase, _power: int) -> void:
	if enemy is BossBase:
		_boss_hits += 1


func _on_glider(carrying: bool, gliding: bool) -> void:
	_glider_carried = _glider_carried or carrying
	_glider_flown = _glider_flown or gliding


func _on_exit(exit_kind: StringName) -> void:
	_exit_kinds.append(exit_kind)


func _on_word() -> void:
	_words += 1


func _hero_text() -> String:
	var level: LevelBase = Game.level
	if level == null or level.player == null:
		return "(no hero)"
	var hero: PlayerBase = level.player
	return "x%5d y%5d c%3d r%3d st%d v(%d,%d) h%d w%d%s" % [hero.sim_pos.x, hero.sim_pos.y, hero.sim_pos.x >> 4,
		(hero.sim_pos.y - 1) >> 4, hero.state, hero.xvel, hero.yvel, Game.hearts, Game.weapon,
		" DEAD" if hero.dead else ""]
