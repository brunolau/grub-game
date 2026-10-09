class_name VersusClubball
extends RefCounted
## Clubball's referee part (docs/expansion/DESIGN.md E.4, GAMEPLAY.md 13.10.6): sides, the goal zones, the score, the
## pause and kick-off after a goal, the clock's end and the golden coconut. Owner: world-B (PLAN.md P2.4).
##
## The coconut itself is objects-B's `objects/coconut` ([Coconut], P2.7): its flight and bounces, the shots by the
## strike (drive, lob, grounder, the charged smash), the rally escalation (+16 v16 per strike within 44 ticks, up to
## 12 px/tick), the knock-downs (a coconut faster than 8 px/tick: 12 stunned ticks, no immunity) and the curled
## teammate as a missile all happen inside it; the referee never touches its velocity.
##
## Sides: team 1 and team 2 (VersusMatch seats; without teams even slots are team 1, odd slots team 2). Goals: every
## `zones/goal rect=c,r,w,h team=1|2` of the arena (that team's OWN goal: the other team scores in it) - the coconut's
## Coconut.goal_team() over the zone entities, else the file's records - and without any the two goal mouths of the
## DESIGN.md E.5 sketch (3 rows over the floor at both ends; team 1 defends the left one). A goal takes the coconut out
## of play for VersusTuning.BALL_RESET_TICKS (Coconut.reset_after), then it drops in at its drop point and every hero
## is back at his side's spawn with the spawn shield. First to VersusTuning.CLUBBALL_GOALS, or the most after
## VersusTuning.CLUBBALL_MATCH_TICKS; a tie plays on with the golden coconut (the next goal wins, the clock stops).
## A WEDGED coconut is lost (phase 4, found by the versus soak): a coconut that lies still with its centre inside a
## wall cell for [constant WEDGED_TICKS] in a row - a lob that comes down beside the block over a goal mouth can
## drift into it, where no strike reaches it, and the game (the golden coconut has no clock) never ended - is taken
## out of play and drops in again at its drop point after VersusTuning.BALL_RESET_TICKS, as a coconut lost in the
## water does; nobody scores, nobody is moved ([method _wedged_step]).
## Sides rotate per round (DESIGN.md E.5, phase 3): on an odd round every goal mouth is defended by the other team
## than its file names (team 1 defends the right mouth), so the spawns, the goals, the HUD and the bots
## (goal_rect / own_goal_x) all swap ends; [member swapped] tells which.

## Goals per team (index 1 and 2; 0 unused).
var goals: PackedInt32Array = PackedInt32Array([0, 0, 0])
## The goal zones: [{"rect": Rect2i (logical px), "team": the defending team}].
var zones: Array[Dictionary] = []
## Ticks left of the pause after a goal (0 = playing).
var pause_left: int = 0
## The golden coconut: the next goal wins.
var golden: bool = false
## The team that scored last (0 = none yet).
var last_scorer: int = 0
## True on an odd round: the sides changed ends ([method set_round]).
var swapped: bool = false
## A coconut that lies still with its centre inside a wall cell this long is lost (1 s: no bounce or roll rests there).
const WEDGED_TICKS: int = 24
## Ticks in a row the coconut has lain so ([method _wedged_step]), and how many wedged coconuts this game has freed.
var wedged_ticks: int = 0
var wedged_resets: int = 0

var _referee: VersusReferee = null


func _init(referee: VersusReferee) -> void:
	_referee = referee


## The round `index` decides the ends: on an odd round the sides swap (the zones are taken afresh).
func set_round(index: int) -> void:
	swapped = posmod(index, 2) == 1
	zones = _round_zones()


## The goal zones of the arena with this round's defenders.
func _round_zones() -> Array[Dictionary]:
	var result: Array[Dictionary] = goal_zones(_referee.level)
	if swapped:
		for zone: Dictionary in result:
			zone["team"] = 3 - int(zone["team"])
	return result


## A fresh game: no goals, the coconut dropped in at its drop point now.
func reset() -> void:
	goals = PackedInt32Array([0, 0, 0])
	pause_left = 0
	golden = false
	last_scorer = 0
	wedged_ticks = 0
	wedged_resets = 0
	zones = _round_zones()
	var coconut: Coconut = ball()
	if coconut != null:
		coconut.golden = false
		coconut.reset_after(0)


## The coconut in play (objects-B's [Coconut]; null when the arena has none).
func ball() -> Coconut:
	return Coconut.find(_referee.level)


## The goal zones of an arena: its `zones/goal` records (cells -> px), else the two mouths of the sketch.
static func goal_zones(level: LevelBase) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if level == null:
		return result
	for record: Dictionary in VersusArena.file_records(level, &"zones/goal"):
		var params: Dictionary = record["params"]
		var rect: PackedInt32Array = LevelText.to_int_list(params.get("rect", ""))
		var team: int = int(params.get("team", 0))
		if rect.size() == 4 and (team == 1 or team == 2):
			result.append({"rect": Rect2i(rect[0] * Tuning.TILE, rect[1] * Tuning.TILE, rect[2] * Tuning.TILE,
					rect[3] * Tuning.TILE), "team": team})
	if not result.is_empty():
		return result
	var view: Rect2i = VersusArena.view_rect()
	var top: int = (VersusTuning.ARENA_FLOOR_ROW - VersusTuning.GOAL_ROWS) * Tuning.TILE
	var height: int = VersusTuning.GOAL_ROWS * Tuning.TILE
	result.append({"rect": Rect2i(view.position.x, top, Tuning.TILE, height), "team": 1})
	result.append({"rect": Rect2i(view.end.x - Tuning.TILE, top, Tuning.TILE, height), "team": 2})
	return result


## The goal mouth `team` (1 / 2) defends, logical px (an empty rect when there is none).
func goal_rect(team: int) -> Rect2i:
	if zones.is_empty():
		zones = _round_zones()
	for zone: Dictionary in zones:
		if int(zone["team"]) == team:
			return zone["rect"]
	return Rect2i()


## The side (1 / 2) of `slot`: his team, else even slots 1 and odd slots 2.
func side_of(slot: int) -> int:
	var team: int = _referee.teams[slot] if slot >= 0 and slot < Defs.MAX_PLAYERS else -1
	if team == 1 or team == 2:
		return team
	return 1 if slot % 2 == 0 else 2


## The x of the goal `team` defends (its zone's centre; the view's left edge for team 1 without zones).
func own_goal_x(team: int) -> int:
	var rect: Rect2i = goal_rect(team)
	if rect.size != Vector2i.ZERO:
		return rect.get_center().x
	var left: bool = (team == 1) != swapped
	return VersusArena.view_rect().position.x if left else VersusArena.view_rect().end.x


## The defending team of the goal the coconut's centre is in (0 = none): Coconut.goal_team() over the arena's zone
## entities first, else the referee's zones.
func goal_team_of(coconut: Coconut) -> int:
	if coconut == null or not coconut.in_play():
		return 0
	var team: int = coconut.goal_team()
	if team == 1 or team == 2:
		# The zone entity names the file's defender; on a swapped round the other team defends it.
		return 3 - team if swapped else team
	var centre: Vector2i = coconut.center()
	for zone: Dictionary in zones:
		if (zone["rect"] as Rect2i).has_point(centre):
			return int(zone["team"])
	return 0


## WORLD: the pause after a goal (then the kick-off), else goals. Returns the scoring team on a goal (0 = none).
func tick() -> int:
	if pause_left > 0:
		pause_left -= 1
		if pause_left == 0:
			_referee.kickoff()
		return 0
	var coconut: Coconut = ball()
	var defended: int = goal_team_of(coconut)
	if defended == 0:
		_wedged_step(coconut)
		return 0
	wedged_ticks = 0
	var scorer: int = 3 - defended
	goals[scorer] += 1
	last_scorer = scorer
	pause_left = VersusTuning.BALL_RESET_TICKS
	coconut.reset_after(VersusTuning.BALL_RESET_TICKS)
	if AudioTable.SFX.has(Sfx.COUNTDOWN_GO):
		Audio.play_sfx(Sfx.COUNTDOWN_GO)
	_referee.goal_scored.emit(scorer, goals[1], goals[2])
	return scorer


## The wedged coconut (see the class description): counts the ticks it lies still with its centre in a wall cell and,
## at [constant WEDGED_TICKS], sends it back to its drop point (Coconut.reset_after). A golden coconut stays golden.
func _wedged_step(coconut: Coconut) -> void:
	var level: LevelBase = _referee.level
	if coconut == null or level == null or not coconut.in_play() or coconut.xvel != 0 or coconut.yvel != 0:
		wedged_ticks = 0
		return
	var centre: Vector2i = coconut.center()
	if level.grid.side_at(centre.x >> 4, centre.y >> 4) != TileGrid.SIDE_WALL:
		wedged_ticks = 0
		return
	wedged_ticks += 1
	if wedged_ticks < WEDGED_TICKS:
		return
	wedged_ticks = 0
	wedged_resets += 1
	coconut.reset_after(VersusTuning.BALL_RESET_TICKS)


## The clock ran out on a tie: the golden coconut (the next goal wins).
func start_golden() -> void:
	golden = true
	var coconut: Coconut = ball()
	if coconut != null:
		coconut.golden = true


## True when `team` won: CLUBBALL_GOALS reached, or a goal while the golden coconut is in play.
func has_won(team: int) -> bool:
	return goals[team] >= VersusTuning.CLUBBALL_GOALS or (golden and goals[team] > goals[3 - team])


## The slots of `team` among the heroes.
func slots_of(team: int) -> PackedInt32Array:
	var result: PackedInt32Array = PackedInt32Array()
	for hero: PlayerBase in _referee.heroes_in_order():
		if side_of(hero.slot) == team:
			result.append(hero.slot)
	return result


## The leading team at the clock's end (0 = a tie).
func leader() -> int:
	if goals[1] > goals[2]:
		return 1
	if goals[2] > goals[1]:
		return 2
	return 0
