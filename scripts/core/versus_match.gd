class_name VersusMatch
extends RefCounted
## One same-device versus match (docs/expansion/DESIGN.md E.3-E.8, TECH_AUDIT.md 4.9, PLAN.md P1.1): who plays in
## which seat (humans with their input, bots with their level), the rules, the arena of every round, the round wins
## and the results. Owner: core-A.
##
## Flow.start_versus(match) starts it (Game.versus_match holds it from then on); the lobby, rules and arena screens
## (ui-A) fill it before; the referee (world-B) reads the rules of the current round and calls Flow.end_round(winners)
## after the gong; the scoreboard and results screens read the wins, the history and hand_out_awards(). A seat is a
## player slot (0..Defs.MAX_PLAYERS - 1): seat n plays hero n (PlayerBase.slot), Game.runs[n] holds his statistics.
## Seats are contiguous when the match starts (compact_seats). Nothing here draws from Sim.rng: arena and Party Mix
## picks use their own SimRng seeded from the match seed, so a match is a pure function of its seed and the inputs.

## The seats changed (a player or bot took or left one).
signal seats_changed

## Rule presets (DESIGN.md E.4): Classic = club only, no crates; Feast = the default; Mayhem = crates every 8 s,
## skull spots, a random variant per round.
enum Preset { CLASSIC = 0, FEAST = 1, MAYHEM = 2 }
## Names of the presets (settings, the rules screen), by Preset value.
const PRESET_NAMES: Array[StringName] = [&"classic", &"feast", &"mayhem"]
## Seat kinds.
enum SeatKind { EMPTY = 0, HUMAN = 1, BOT = 2 }
## Arena choices besides an arena id: a random arena every round, or Party Mix (arena AND mode per round).
const ARENA_RANDOM: StringName = &"random"
const ARENA_PARTY_MIX: StringName = &"party_mix"
## The modes at launch (the second wave is not offered; DESIGN.md E.4).
const LAUNCH_MODES: Array[int] = [
	Defs.VersusMode.GRUB_STACK, Defs.VersusMode.LAST_CAVEMAN, Defs.VersusMode.HOT_ROCK, Defs.VersusMode.CLUBBALL,
]
## Arenas that a painting reward unlocks (DESIGN.md C.9): arena id -> the Save.UNLOCK_* reward (Save.is_unlocked).
const LOCKED_ARENAS: Dictionary = {
	&"arena_mesa_rodeo": &"mesa_rodeo",
	&"arena_cloud_top": &"cloud_top",
}
## Developer arenas (levels/test_world_arena_*.lvl ...) are never offered (available_arenas); chosen by id they play.
const DEVELOPER_ARENA_PREFIX: String = "test_"
## Settings key of the last rules (DESIGN.md E.8: "the last rules are remembered"); see rules_to_dict.
const RULES_KEY: String = "versus/last_rules"

## Where bots come from. Normally core-B's HeroBot (res://scripts/core/bots/hero_bot.gd, PLAN.md P1.2): Flow creates
## one per bot seat when the match starts - HeroBot.new(slot, bot_level, match_seed, round_mode), kept in [member bots]
## for the whole match - calls its reset_round(round_seed()) at every round start and feeds the slot from its
## `produce` (InputSlot.bot). Loaded by path, so a HeroBot that does not compile never breaks Flow. A tool or test can
## replace it: `bot_factory.call(slot: int, bot_level: int, seed: int) -> Callable` returns a fresh flags source per
## round. Without either a bot seat stands idle (flags 0).
static var bot_factory: Callable = Callable()
const HERO_BOT_PATH: String = "res://scripts/core/bots/hero_bot.gd"


## One seat of the lobby.
class Seat:
	extends RefCounted
	## SeatKind.
	var kind: int = SeatKind.EMPTY
	## HUMAN: where the player's input comes from (a copy; GameInput.assign_slot gets it when the match starts).
	var input: InputSlot = null
	## BOT: Defs.BotLevel (Hunter by default, DESIGN.md E.7).
	var bot_level: int = Defs.BotLevel.HUNTER
	## 0 = free-for-all, 1 / 2 = the team of a 2v2 match.
	var team: int = 0
	## Colour and loincloth pattern (PlayerRun.palette / pattern; &"" / -1 = the slot's default).
	var palette: StringName = &""
	var pattern: int = -1
	## Handicap card: Last Caveman Standing hearts (VersusTuning.HANDICAP_HEARTS_MIN..MAX; 0 = the mode's 3), Grub
	## Stack stack guard (index of VersusTuning.STACK_GUARD_PERCENT, 1 = x1), Auto (a leaf shield when two rounds
	## behind).
	var hearts: int = 0
	var stack_guard: int = 1
	var auto_handicap: bool = false
	## Held Strike long enough on the lobby (VersusTuning.READY_HOLD_TICKS); bots are always ready.
	var ready: bool = false

	func is_taken() -> bool:
		return kind != SeatKind.EMPTY

	func duplicate_seat() -> Seat:
		var copy: Seat = Seat.new()
		copy.kind = kind
		copy.input = input.duplicate_slot() if input != null else null
		copy.bot_level = bot_level
		copy.team = team
		copy.palette = palette
		copy.pattern = pattern
		copy.hearts = hearts
		copy.stack_guard = stack_guard
		copy.auto_handicap = auto_handicap
		copy.ready = ready
		return copy


# --- Seats -------------------------------------------------------------------------------------------------------
## Defs.MAX_PLAYERS seats, index = player slot.
var seats: Array[Seat] = _empty_seats()

# --- Rules (DESIGN.md E.8 step 2; remembered with rules_to_dict) ------------------------------------------------
## Defs.VersusMode of the match (Party Mix picks one per round instead).
var mode: int = Defs.VersusMode.GRUB_STACK
## Preset.
var preset: int = Preset.FEAST
## Round wins that win the match; 0 = the mode's default (round_wins_needed).
var rounds_to_win: int = 0
## Round length in seconds; 0 = the mode's default (round_ticks).
var round_seconds: int = 0
## Pterodactyl crates on (the Classic preset switches them off whatever this says).
var crates: bool = true
## Weapons rule: &"all" = specials from crates, &"club" = club only.
var weapons: StringName = &"all"
## Variant names (DESIGN.md E.4: hammer_time, axe_rain, big_bounce, one_bonk, slippery, lights_out, gusty, giant_rain,
## spear_party) switched on.
var variants: PackedStringArray = PackedStringArray()
## Themed sudden death as an event in the modes other than Last Caveman Standing (which always has it at 60 s).
var sudden_death: bool = false
## Last Caveman Standing option Stock: 3 lives with respawn.
var stock: bool = false
## An arena id, ARENA_RANDOM or ARENA_PARTY_MIX.
var arena: StringName = ARENA_RANDOM
## The slot whose Start opened the rules screen ("whoever pressed Start controls it"); -1 = anybody.
var rules_owner: int = -1

# --- The match ---------------------------------------------------------------------------------------------------
## Seed of the match: round r plays with Sim.rng seeded VersusTuning.round_seed(match_seed, r).
var match_seed: int = 1
## Index of the current round (0-based); after the last round: the number of rounds played.
var round_index: int = 0
## True between begin_round() and record_round() (the round is being played).
var round_open: bool = false
## Arena and mode of the current (or last) round.
var round_arena: StringName = &""
var round_mode: int = Defs.VersusMode.GRUB_STACK
## Round wins per slot.
var round_wins: PackedInt32Array = _zeros()
## One entry per finished round: {"arena": StringName, "mode": int, "winners": PackedInt32Array}.
var history: Array[Dictionary] = []
## The bot object of each slot (a HeroBot, created by Flow when the match starts; null for humans and empty seats).
## Untyped on purpose: core-B's class is loaded by path.
var bots: Array = [null, null, null, null]
## Per slot: the most round wins it trailed the leader by so far (for Comeback Caveman).
var _deficits: PackedInt32Array = _zeros()


# =================================================================================================================
# Seats
# =================================================================================================================

## Seat a human player at `slot` (-1 = the first free seat) with his input. Returns the slot, or -1 when the seat is
## taken or the lobby is full.
func seat_human(input: InputSlot, slot: int = -1) -> int:
	var at: int = _free_seat(slot)
	if at < 0:
		return -1
	var seat: Seat = seats[at]
	seat.kind = SeatKind.HUMAN
	seat.input = input.duplicate_slot() if input != null else InputSlot.new()
	seat.ready = false
	seats_changed.emit()
	return at


## Seat a bot of `level` (Defs.BotLevel) at `slot` (-1 = the first free seat) - the lobby's "Add CPU". Returns the slot
## or -1.
func seat_bot(level: int = Defs.BotLevel.HUNTER, slot: int = -1) -> int:
	var at: int = _free_seat(slot)
	if at < 0:
		return -1
	var seat: Seat = seats[at]
	seat.kind = SeatKind.BOT
	seat.input = null
	seat.bot_level = clampi(level, Defs.BotLevel.ROOKIE, Defs.BotLevel.CHIEF)
	seat.ready = true
	seats_changed.emit()
	return at


## Free a seat (its look and handicap are forgotten).
func unseat(slot: int) -> void:
	if slot < 0 or slot >= seats.size() or not seats[slot].is_taken():
		return
	seats[slot] = Seat.new()
	seats_changed.emit()


## True when a human or a bot sits at `slot`.
func is_seated(slot: int) -> bool:
	return slot >= 0 and slot < seats.size() and seats[slot].is_taken()


## True when a bot sits at `slot`.
func is_bot(slot: int) -> bool:
	return is_seated(slot) and seats[slot].kind == SeatKind.BOT


## The seat of `slot` (null for a slot that does not exist).
func get_seat(slot: int) -> Seat:
	return seats[slot] if slot >= 0 and slot < seats.size() else null


## Players in the match, humans and bots.
func player_count() -> int:
	var count: int = 0
	for seat: Seat in seats:
		if seat.is_taken():
			count += 1
	return count


## Human players in the match.
func human_count() -> int:
	var count: int = 0
	for seat: Seat in seats:
		if seat.kind == SeatKind.HUMAN:
			count += 1
	return count


## The taken seats in slot order.
func seated_slots() -> PackedInt32Array:
	var result: PackedInt32Array = PackedInt32Array()
	for slot: int in seats.size():
		if seats[slot].is_taken():
			result.append(slot)
	return result


## Move the taken seats down so that they are slots 0..player_count() - 1 (heroes are spawned for slots 0..party - 1).
## Order, inputs, looks and handicaps are kept. Returns true when a seat moved.
func compact_seats() -> bool:
	var taken: Array[Seat] = []
	for seat: Seat in seats:
		if seat.is_taken():
			taken.append(seat)
	var moved: bool = false
	for slot: int in seats.size():
		var seat: Seat = taken[slot] if slot < taken.size() else Seat.new()
		if seats[slot] != seat and (seats[slot].is_taken() or seat.is_taken()):
			moved = true
		seats[slot] = seat
	if moved:
		seats_changed.emit()
	return moved


## True when 2v2 teams are set (every taken seat has team 1 or 2).
func is_team_match() -> bool:
	var teams: Dictionary = {}
	for seat: Seat in seats:
		if seat.is_taken():
			if seat.team <= 0:
				return false
			teams[seat.team] = true
	return teams.size() == 2


## The slots of `team` (1 / 2) - or of the slot itself in a free-for-all.
func teammates(slot: int) -> PackedInt32Array:
	var result: PackedInt32Array = PackedInt32Array()
	if not is_seated(slot):
		return result
	if not is_team_match():
		result.append(slot)
		return result
	for other: int in seats.size():
		if seats[other].is_taken() and seats[other].team == seats[slot].team:
			result.append(other)
	return result


## True when the match can start: at least VersusTuning.PLAYERS_MIN players, every human ready, and teams (when set)
## of two each.
func can_start() -> bool:
	if player_count() < VersusTuning.PLAYERS_MIN:
		return false
	for seat: Seat in seats:
		if seat.kind == SeatKind.HUMAN and not seat.ready:
			return false
	if is_team_match():
		var sizes: Dictionary = {}
		for seat: Seat in seats:
			if seat.is_taken():
				sizes[seat.team] = int(sizes.get(seat.team, 0)) + 1
		for team: Variant in sizes:
			if int(sizes[team]) != 2:
				return false
	return true


## Mark every human seat ready (tests, a quick rematch).
func ready_all() -> void:
	for seat: Seat in seats:
		if seat.is_taken():
			seat.ready = true


# =================================================================================================================
# Rules
# =================================================================================================================

## Round wins that win the match: rounds_to_win, or the mode's default - Grub Stack 3, Last Caveman Standing 5, Hot
## Rock 3, Clubball 1 (one game to 5 goals), the second wave 3.
func round_wins_needed(for_mode: int = -1) -> int:
	if rounds_to_win > 0:
		return rounds_to_win
	var which: int = mode if for_mode < 0 else for_mode
	match which:
		Defs.VersusMode.GRUB_STACK:
			return VersusTuning.STACK_ROUND_WINS
		Defs.VersusMode.LAST_CAVEMAN:
			return VersusTuning.LCS_ROUND_WINS
		Defs.VersusMode.HOT_ROCK:
			return VersusTuning.HOT_ROCK_ROUND_WINS
		Defs.VersusMode.CLUBBALL:
			return 1
	return VersusTuning.STACK_ROUND_WINS


## Length of a round in ticks for the current round's mode (0 = no clock: the round ends by its own rule - the last
## one standing in Last Caveman Standing and Hot Rock). round_seconds overrides; else Grub Stack 2 185 (1 457 with two
## players), Clubball 4 370.
func round_ticks(for_mode: int = -1) -> int:
	if round_seconds > 0:
		return Tuning.seconds_to_ticks(float(round_seconds))
	var which: int = round_mode if for_mode < 0 else for_mode
	match which:
		Defs.VersusMode.GRUB_STACK:
			return VersusTuning.stack_round_ticks(player_count())
		Defs.VersusMode.CLUBBALL:
			return VersusTuning.CLUBBALL_MATCH_TICKS
	return 0


## Ticks between pterodactyl crates (0 = no crates): Classic none, Feast 486, Mayhem 194; club only or crates off: 0.
func crate_period_ticks() -> int:
	if not crates or preset == Preset.CLASSIC:
		return 0
	return VersusTuning.MAYHEM_CRATE_PERIOD_TICKS if preset == Preset.MAYHEM else VersusTuning.CRATE_PERIOD_TICKS


## True when the variant `variant_name` is on.
func has_variant(variant_name: StringName) -> bool:
	return variants.has(String(variant_name))


## The rules as plain data (Settings RULES_KEY; the rules screen restores them with rules_from_dict).
func rules_to_dict() -> Dictionary:
	return {
		"mode": String(Defs.versus_mode_name(mode)), "preset": String(PRESET_NAMES[preset]),
		"rounds_to_win": rounds_to_win, "round_seconds": round_seconds, "crates": crates, "weapons": String(weapons),
		"variants": variants, "sudden_death": sudden_death, "stock": stock, "arena": String(arena),
	}


## Restore rules saved by rules_to_dict; unknown or damaged values keep their defaults.
func rules_from_dict(data: Dictionary) -> void:
	var mode_value: int = Defs.versus_mode_from_name(StringName(str(data.get("mode", ""))))
	if LAUNCH_MODES.has(mode_value):
		mode = mode_value
	var preset_value: int = PRESET_NAMES.find(StringName(str(data.get("preset", ""))))
	if preset_value >= 0:
		preset = preset_value
	rounds_to_win = maxi(int(data.get("rounds_to_win", 0)), 0) if _is_number(data.get("rounds_to_win")) else 0
	round_seconds = maxi(int(data.get("round_seconds", 0)), 0) if _is_number(data.get("round_seconds")) else 0
	crates = bool(data.get("crates", true)) if data.get("crates") is bool else true
	var weapons_value: String = str(data.get("weapons", "all"))
	weapons = StringName(weapons_value) if weapons_value in ["all", "club"] else &"all"
	var stored: Variant = data.get("variants", PackedStringArray())
	variants = PackedStringArray()
	if stored is PackedStringArray or stored is Array:
		for item: Variant in stored:
			if item is String or item is StringName:
				variants.append(str(item))
	sudden_death = data.get("sudden_death") is bool and bool(data["sudden_death"])
	stock = data.get("stock") is bool and bool(data["stock"])
	var arena_value: StringName = StringName(str(data.get("arena", ARENA_RANDOM)))
	arena = arena_value if arena_value == ARENA_RANDOM or arena_value == ARENA_PARTY_MIX \
			or Levels.is_arena(arena_value) else ARENA_RANDOM


## A new match with the last remembered rules (Settings RULES_KEY) and empty seats.
static func from_settings() -> VersusMatch:
	var result: VersusMatch = VersusMatch.new()
	var stored: Variant = Settings.get_value(RULES_KEY, {})
	if stored is Dictionary:
		result.rules_from_dict(stored)
	return result


## Remember the rules for the next lobby (written to disk with the next Settings.save()).
func remember_rules() -> void:
	Settings.set_value(RULES_KEY, rules_to_dict())


# =================================================================================================================
# Arenas
# =================================================================================================================

## The arenas a match of `players` heroes in `for_mode` (Defs.VersusMode, -1 = any) can use: Levels.get_arenas with
## the locked ones (LOCKED_ARENAS) left out until their reward is unlocked, and without the developer arenas
## (`test_*` ids: bot bakes, referee tests) - those play only when chosen by id (the `arena` rule).
static func available_arenas(players: int, for_mode: int = -1) -> Array[StringName]:
	var mode_name: StringName = Defs.versus_mode_name(for_mode) if for_mode >= 0 else &""
	var result: Array[StringName] = []
	for id: StringName in Levels.get_arenas(players, mode_name):
		if String(id).begins_with(DEVELOPER_ARENA_PREFIX):
			continue
		if LOCKED_ARENAS.has(id) and not Save.is_unlocked(LOCKED_ARENAS[id]):
			continue
		result.append(id)
	return result


## The modes an arena supports among the launch modes (its meta `modes`), in Defs.VersusMode order.
static func arena_modes(arena_id: StringName) -> Array[int]:
	var result: Array[int] = []
	var listed: PackedStringArray = LevelText.to_list(Levels.get_value(arena_id, "modes", ""))
	for launch_mode: int in LAUNCH_MODES:
		if listed.has(String(Defs.versus_mode_name(launch_mode))):
			result.append(launch_mode)
	return result


## Arena of round `index`: the chosen arena, or a pick of this match's own random sequence (ARENA_RANDOM: among the
## arenas of the mode; ARENA_PARTY_MIX: among every arena for this many players). "" when none fits.
func arena_for_round(index: int) -> StringName:
	if arena != ARENA_RANDOM and arena != ARENA_PARTY_MIX:
		return arena if Levels.is_arena(arena) else &""
	var choices: Array[StringName] = available_arenas(player_count(), -1 if arena == ARENA_PARTY_MIX else mode)
	if choices.is_empty():
		return &""
	return choices[_pick(index, 0).pick_index(choices.size())]


## Mode of round `index` on `arena_id`: the match's mode, or with Party Mix a pick among the arena's launch modes.
func mode_for_round(index: int, arena_id: StringName) -> int:
	if arena != ARENA_PARTY_MIX:
		return mode
	var modes: Array[int] = arena_modes(arena_id)
	if modes.is_empty():
		return mode
	return modes[_pick(index, 1).pick_index(modes.size())]


# =================================================================================================================
# The round loop (Flow.start_versus / start_round / end_round)
# =================================================================================================================

## Start the match afresh: round 0, no wins, no history, every taken seat's run statistics zeroed by the caller
## (Game.start_run). Keeps seats and rules.
func begin_match(seed_value: int = -1) -> void:
	if seed_value >= 0:
		match_seed = seed_value
	round_index = 0
	round_open = false
	round_arena = &""
	round_mode = mode
	round_wins = _zeros()
	_deficits = _zeros()
	history.clear()
	bots = [null, null, null, null]


## The next round starts on `arena_id` (round_index stays until record_round).
func begin_round(arena_id: StringName) -> void:
	round_arena = arena_id
	round_mode = mode_for_round(round_index, arena_id)
	round_open = true


## Sim.rng seed of the current round (VersusTuning.round_seed).
func round_seed() -> int:
	return VersusTuning.round_seed(match_seed, round_index)


## Seed of a bot's own SimRng in the current round: from the match seed (through the round seed) and the slot.
func bot_seed(slot: int) -> int:
	return round_seed() * Defs.MAX_PLAYERS + slot


## Spawn index (objects/spawn_point index, 1 = '@') of `slot` this round: spawns rotate every round (DESIGN.md E.2;
## the physics is left-right asymmetric). Round 0: slot n takes spawn n + 1.
func spawn_index(slot: int) -> int:
	var count: int = maxi(player_count(), 1)
	return posmod(slot + round_index, count) + 1


## The round is over: `winners` (one slot, both of a team, or none for a draw) get a round win each. Returns false
## (nothing recorded) when no round was open.
func record_round(winners: PackedInt32Array) -> bool:
	if not round_open:
		return false
	round_open = false
	var clean: PackedInt32Array = PackedInt32Array()
	for slot: int in winners:
		if is_seated(slot) and not clean.has(slot):
			clean.append(slot)
			round_wins[slot] += 1
	history.append({"arena": round_arena, "mode": round_mode, "winners": clean})
	round_index += 1
	var lead: int = 0
	for slot: int in seated_slots():
		lead = maxi(lead, round_wins[slot])
	for slot: int in seated_slots():
		_deficits[slot] = maxi(_deficits[slot], lead - round_wins[slot])
	return true


## True when somebody reached round_wins_needed().
func is_over() -> bool:
	var needed: int = round_wins_needed()
	for slot: int in seated_slots():
		if round_wins[slot] >= needed:
			return true
	return false


## The slots with the most round wins (the match winners once is_over(); both of a team).
func leaders() -> PackedInt32Array:
	var best: int = 0
	for slot: int in seated_slots():
		best = maxi(best, round_wins[slot])
	var result: PackedInt32Array = PackedInt32Array()
	if best <= 0:
		return result
	for slot: int in seated_slots():
		if round_wins[slot] == best:
			result.append(slot)
	return result


## Rematch (the default button of the results): same seats, rules and arena choice, a new seed, rounds from 0.
func rematch() -> void:
	begin_match(match_seed + 1)


## The match ended: write the Comeback Caveman counter of every seat into `runs` (index = slot) - the deficit a
## match winner came back from (0 for everybody else).
func finish(runs: Array[PlayerRun]) -> void:
	var winners: PackedInt32Array = leaders()
	for slot: int in seated_slots():
		if slot < runs.size():
			runs[slot].comeback = _deficits[slot] if winners.has(slot) else 0


## The awards of the results screen (DESIGN.md E.8): slot -> Array[StringName] of PlayerRun.VERSUS_AWARDS ids, 1 to
## VersusTuning.AWARDS_MAX each. Awards go in table order to their winners (PlayerRun.award_winners) while a winner
## has fewer than the maximum; a player left without one gets the award he comes closest to winning.
func hand_out_awards(runs: Array[PlayerRun]) -> Dictionary:
	var seated: Array[PlayerRun] = []
	for slot: int in seated_slots():
		if slot < runs.size():
			seated.append(runs[slot])
	var result: Dictionary = {}
	for run: PlayerRun in seated:
		var empty: Array[StringName] = []
		result[run.slot] = empty
	for award: Dictionary in PlayerRun.VERSUS_AWARDS:
		for slot: int in PlayerRun.award_winners(seated, award):
			var list: Array[StringName] = result[slot]
			if list.size() < VersusTuning.AWARDS_MAX:
				list.append(award["id"])
	for run: PlayerRun in seated:
		var list: Array[StringName] = result[run.slot]
		if list.size() >= VersusTuning.AWARDS_MIN:
			continue
		var best_id: StringName = &""
		var best_score: float = -1.0
		for award: Dictionary in PlayerRun.VERSUS_AWARDS:
			var score: float = _closeness(seated, run, award)
			if score > best_score:
				best_score = score
				best_id = award["id"]
		if best_id != &"":
			list.append(best_id)
	return result


# =================================================================================================================
# Internals
# =================================================================================================================

## How close `run` comes to winning `award` among `runs`: 1 = he has the best value, 0 = the worst (and 0 when
## everybody has the same value: nobody earned it).
static func _closeness(runs: Array[PlayerRun], run: PlayerRun, award: Dictionary) -> float:
	var fewest: bool = bool(award.get("fewest", false))
	var low: int = run.award_value(award)
	var high: int = low
	for other: PlayerRun in runs:
		low = mini(low, other.award_value(award))
		high = maxi(high, other.award_value(award))
	if high == low:
		return 0.0
	var value: float = float(run.award_value(award) - low) / float(high - low)
	return 1.0 - value if fewest else value


func _free_seat(slot: int) -> int:
	if slot >= 0:
		return slot if slot < seats.size() and not seats[slot].is_taken() else -1
	for index: int in seats.size():
		if not seats[index].is_taken():
			return index
	return -1


## The match's own random sequence for round `index` (`stream` 0 = arena, 1 = mode): never Sim.rng.
func _pick(index: int, stream: int) -> SimRng:
	return SimRng.new(VersusTuning.round_seed(match_seed, index) * 2 + stream + 1)


static func _is_number(value: Variant) -> bool:
	return value is int or value is float


static func _zeros() -> PackedInt32Array:
	var result: PackedInt32Array = PackedInt32Array()
	result.resize(Defs.MAX_PLAYERS)
	result.fill(0)
	return result


static func _empty_seats() -> Array[Seat]:
	var result: Array[Seat] = []
	for slot: int in Defs.MAX_PLAYERS:
		result.append(Seat.new())
	return result
