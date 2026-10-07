class_name VersusReplay
extends RefCounted
## The deciding moment of a versus round (docs/expansion/DESIGN.md E.8 step 5, GAMEPLAY.md 13.10.1, PLAN.md P2.6):
## the input log and the start snapshot of one round, and the window of it that is shown again at half speed. Owner:
## core-A.
##
## A round is a pure function of its seed and its inputs (TECH_AUDIT.md 2; bots are input producers whose flags are
## logged like a human's), so the replay is the same arena loaded again with the same round seed and every hero fed
## from this log - tick for tick the round that was played. Flow records every round of a match ([method begin] at the
## round start, [method log_tick] after each tick's input was sampled, [method note_tick] after each tick for the
## steals, [method finish] at the gong) and plays the window back ([method window], [method flags_at]) between the gong
## and the scoreboard (Flow.play_deciding_moment). The start snapshot holds what else the round read: the match's round
## state (index, mode, arena and round wins - the spawns, the round seed, Mayhem's variant and the Auto handicap come
## from them) and every hero's run (weapons, hearts, look); the end snapshot puts the statistics of the real round back
## after the replay played them a second time.
##
## The window: the last 3 s before the gong; in Grub Stack the 3 s around the biggest steal (the stomp that moved the
## most units from one head to another; ties: the later one), ending STEAL_LEAD_OUT_TICKS after it. Nothing here
## draws from Sim.rng.

## The deciding moment lasts 3 s (73 ticks).
const DECIDING_TICKS: int = 73
## A steal is shown with 1 s (24 ticks) of its aftermath.
const STEAL_LEAD_OUT_TICKS: int = 24
## The replay plays at half speed (Sim.time_scale).
const REPLAY_SPEED: float = 0.5

## The arena, the Sim.rng seed of the round and the number of heroes (slots 0..players - 1).
var arena: StringName = &""
var seed_value: int = 0
var players: int = 0
## The match's round state at the round start (VersusMatch.round_index, round_mode, round_arena, round_wins).
var round_index: int = 0
var round_mode: int = Defs.VersusMode.GRUB_STACK
var round_wins: PackedInt32Array = PackedInt32Array()
## Every hero's run at the round start and at the gong (PlayerRun.to_dict, index = slot).
var start_runs: Array[Dictionary] = []
var end_runs: Array[Dictionary] = []
## The input log: the flags of slot s on tick t (1-based) at (t - 1) * players + s.
var inputs: PackedInt32Array = PackedInt32Array()
## Ticks logged (the gong's tick once finished; 0 = nothing logged).
var ticks: int = 0
## True once [method finish] ran.
var finished: bool = false
## The biggest steal: its tick (-1 = none) and the units it moved.
var steal_tick: int = -1
var steal_units: int = 0

var _stolen: PackedInt32Array = PackedInt32Array()


## A recording of the round `versus_match` is about to play on `p_arena` with `p_seed` (the round seed), for the heroes
## of `runs` (Game.runs; the first versus_match.player_count() of them play).
static func begin(versus_match: VersusMatch, p_arena: StringName, p_seed: int, runs: Array[PlayerRun]) -> VersusReplay:
	var replay: VersusReplay = VersusReplay.new()
	replay.arena = p_arena
	replay.seed_value = p_seed
	replay.players = clampi(versus_match.player_count(), 1, Defs.MAX_PLAYERS)
	replay.round_index = versus_match.round_index
	replay.round_mode = versus_match.round_mode
	replay.round_wins = versus_match.round_wins.duplicate()
	replay.start_runs = snapshot_runs(runs, replay.players)
	replay._stolen.resize(replay.players)
	for slot: int in replay.players:
		replay._stolen[slot] = runs[slot].stolen if slot < runs.size() else 0
	return replay


## PlayerRun.to_dict of the first `count` runs.
static func snapshot_runs(runs: Array[PlayerRun], count: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for slot: int in mini(count, runs.size()):
		result.append(runs[slot].to_dict())
	return result


## Put snapshots back into `runs` (PlayerRun.from_dict; no signal).
static func restore_runs(snapshots: Array[Dictionary], runs: Array[PlayerRun]) -> void:
	for slot: int in mini(snapshots.size(), runs.size()):
		runs[slot].from_dict(snapshots[slot])


## Log the flags every hero plays on tick `tick` (1-based, after GameInput.sample: GameInput.get_flags). A tick that
## is not the next one is ignored (the log has no holes); nothing is logged once finished.
func log_tick(tick: int, flags: PackedInt32Array) -> void:
	if finished or tick != ticks + 1:
		return
	for slot: int in players:
		inputs.append(flags[slot] if slot < flags.size() else 0)
	ticks = tick


## After tick `tick` ran: a steal shows in the runs' `stolen` counters (PlayerRun.stolen, written by the referee); the
## biggest single steal of the round is kept (ties: the later one).
func note_tick(tick: int, runs: Array[PlayerRun]) -> void:
	if finished:
		return
	for slot: int in mini(players, runs.size()):
		var gained: int = runs[slot].stolen - _stolen[slot]
		_stolen[slot] = runs[slot].stolen
		if gained > 0 and gained >= steal_units:
			steal_units = gained
			steal_tick = tick


## The gong: the round ended on tick `tick` (the last tick logged); `runs` are the heroes' runs as the round left them.
func finish(tick: int, runs: Array[PlayerRun]) -> void:
	if finished:
		return
	finished = true
	if tick > 0:
		ticks = mini(ticks, tick)
	end_runs = snapshot_runs(runs, players)


## True when there is something to show: the round was logged to its gong.
func can_replay() -> bool:
	return finished and ticks > 0


## The ticks to show, first and last (1-based, inclusive): the DECIDING_TICKS before the gong, or in Grub Stack those
## around the biggest steal (ending STEAL_LEAD_OUT_TICKS after it). Vector2i(0, 0) when nothing was logged.
func window() -> Vector2i:
	if ticks <= 0:
		return Vector2i.ZERO
	var last: int = ticks
	if round_mode == Defs.VersusMode.GRUB_STACK and steal_tick > 0:
		last = mini(steal_tick + STEAL_LEAD_OUT_TICKS, ticks)
	var first: int = maxi(last - DECIDING_TICKS + 1, 1)
	return Vector2i(first, last)


## True when the window shows Grub Stack's biggest steal (not just the last seconds).
func shows_steal() -> bool:
	return round_mode == Defs.VersusMode.GRUB_STACK and steal_tick > 0


## The flags slot `slot` played on tick `tick` (1-based); 0 outside the log.
func flags_at(tick: int, slot: int) -> int:
	if tick < 1 or tick > ticks or slot < 0 or slot >= players:
		return 0
	return inputs[(tick - 1) * players + slot]


## The match's round state as the round started (what VersusMatch must read again while the round is replayed).
func apply_start_state(versus_match: VersusMatch) -> void:
	versus_match.round_index = round_index
	versus_match.round_mode = round_mode
	versus_match.round_arena = arena
	versus_match.round_wins = round_wins.duplicate()
