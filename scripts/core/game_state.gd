extends Node
## Autoload `Game`: the run state that outlives a level scene (GAMEPLAY.md 2-4, PHYSICS.md 10.2).
##
## CONTRACT FILE (docs/ARCHITECTURE.md 3.5). Owner: core. Public members and signals are frozen.
##
## Everything here is plain integer state changed through methods; each change emits one signal so the HUD never
## polls. Scores are DISPLAYED points (the original's internal score x 10). The per-tick hero state (velocities,
## timers) lives in PlayerBase, not here.
##
## 2.0 (docs/expansion/PLAN.md P0.4, TECH_AUDIT.md 4.2): the per-hero state lives in `runs` (one [PlayerRun] per
## player slot). `hearts`, `bones`, `weapon` and `has_glider` are properties of `runs[0]` (P1), and the energy,
## weapon and glider methods act on `runs[0]` with the 1.0 bodies, field writes and signal order; `energy_changed`,
## `weapon_changed`, `glider_changed` keep meaning P1 and are emitted the moment `runs[0]` changes, however it was
## changed. Team state (score, lives, letters, feast kit, checkpoint, exit, completion, tally) stays here. A party
## of one (`mode` SINGLE, `party` 1, `book` 1, the defaults) is the 1.0 game.

## Displayed score changed.
signal score_changed(score: int)
## Spare-lives counter changed.
signal lives_changed(lives: int)
## Hearts (0..3) or the hidden bone fraction (0..5) changed.
signal energy_changed(hearts: int, bones: int)
## Bonus-word letters changed: bit i = letter i (G, R, U, B, S).
signal letters_changed(mask: int)
## All five letters collected: the HUD blinks them, then the mask is cleared.
signal letters_completed
## Feast-kit pieces changed: bit i = piece i (bowl, flint, log).
signal feast_kit_changed(mask: int)
## Current weapon changed (Defs.Weapon).
signal weapon_changed(weapon: int)
## The hero picked up or lost the hang-glider.
signal glider_changed(carrying: bool)
## Completion counters changed.
signal completion_changed(percent: int)
## An extra life was awarded by score.
signal extra_life_awarded(lives: int)
## The respawn point changed (has_checkpoint / checkpoint_pos).
signal checkpoint_changed(pos: Vector2i)
## A new run started (title -> new game or continue).
signal run_started(difficulty: int)
## Hearts or bones of the hero in player slot `slot` changed (every slot, P1 included, after `energy_changed`).
signal run_energy_changed(slot: int, hearts: int, bones: int)
## The hand weapon of slot `slot` changed (Defs.Weapon; P1 also emits `weapon_changed` first).
signal run_weapon_changed(slot: int, weapon: int)
## The belt of slot `slot` changed (Defs.Weapon or PlayerRun.BELT_EMPTY).
signal run_belt_changed(slot: int, belt: int)
## The hero of slot `slot` picked up or lost the hang-glider (P1 also emits `glider_changed` first).
signal run_glider_changed(slot: int, carrying: bool)

## Per-hero run state, one per player slot (Defs.MAX_PLAYERS, always allocated, never replaced); slot 0 = P1.
var runs: Array[PlayerRun] = _make_runs()
## What kind of game runs (Defs.GameMode). SINGLE is the 1.0 game.
var mode: int = Defs.GameMode.SINGLE
## Heroes in the run, 1..Defs.MAX_PLAYERS (slots 0..party - 1). 1 in single-player.
var party: int = 1
## The book of the campaign being played: 1 = the 1.0 campaign, 2 = The Far Shore (DESIGN.md A).
var book: int = 1
## The versus match being played or set up (Flow.start_versus, the lobby); null when none. Kept after the match (the
## results screen reads it; the lobby starts the next one from its rules). (`match` is a GDScript keyword.)
var versus_match: VersusMatch = null

## Difficulty of the current run (Defs.Difficulty).
var difficulty: int = Defs.Difficulty.BEGINNER
## Displayed score.
var score: int = 0
## Spare lives (starts at Tuning.LIVES_START; dying at 0 is game over).
var lives: int = Tuning.LIVES_START
## Hearts, 0..Tuning.ENERGY_START. A hit at 0 hearts kills (PHYSICS.md 10.2). Property of runs[0] (P1).
var hearts: int:
	get:
		return runs[0].hearts
	set(value):
		runs[0].hearts = value
## Bones toward the next heart, 0..Tuning.BONES_PER_HEART - 1 (never shown on the HUD). Property of runs[0].
var bones: int:
	get:
		return runs[0].bones
	set(value):
		runs[0].bones = value
## Collected letters bit mask.
var letters: int = 0
## Collected feast-kit pieces bit mask.
var feast_kit: int = 0
## Current weapon (Defs.Weapon); kept through deaths and levels until game over. Property of runs[0] (P1's hand).
var weapon: int:
	get:
		return runs[0].weapon
	set(value):
		runs[0].weapon = value
## True while the hero carries the hang-glider. Property of runs[0].
var has_glider: bool:
	get:
		return runs[0].has_glider
	set(value):
		runs[0].has_glider = value
## True once the exit of the current level is unlocked (fire-starter).
var exit_unlocked: bool = false

## Id of the level being played ("" outside gameplay).
var level_id: StringName = &""
## The active level node, set by LevelBase when it enters the tree (null outside gameplay).
var level: LevelBase = null
## Main-route level to return to after a bonus stage ("" when not in a bonus stage).
var warp_return_level: StringName = &""

## True when a restart point is active in the current level.
var has_checkpoint: bool = false
## Respawn feet point (logical px) when has_checkpoint.
var checkpoint_pos: Vector2i = Vector2i.ZERO

## Hidden spots in the level (plus linked bonus stage) / opened so far.
var spots_total: int = 0
var spots_opened: int = 0
## Map-placed bonus items in the level / collected so far.
var items_total: int = 0
var items_collected: int = 0
## Secret areas found in this level.
var secrets_found: int = 0
## Items collected since the last death, paid again at the tally: parallel arrays (GAMEPLAY.md 3.4, 3.7).
var tally_item_ids: Array[StringName] = []
var tally_item_indices: PackedInt32Array = PackedInt32Array()
var tally_item_points: PackedInt32Array = PackedInt32Array()

var _next_life_at: int = Tuning.EXTRA_LIFE_EVERY
# The run as it was when the current level was entered (begin_level), for restore_level_entry(). Empty = none.
var _entry: Dictionary = {}


func _init() -> void:
	# Every run reports through Game: P1's changes as the frozen 1.0 signals, every slot's as run_*_changed.
	for run: PlayerRun in runs:
		run.energy_changed.connect(_on_run_energy_changed.bind(run.slot))
		run.weapon_changed.connect(_on_run_weapon_changed.bind(run.slot))
		run.belt_changed.connect(_on_run_belt_changed.bind(run.slot))
		run.glider_changed.connect(_on_run_glider_changed.bind(run.slot))


## Start a fresh run: score 0, 2 spare lives, club, no letters (GAMEPLAY.md 11.1 step 9). This is the 1.0 game:
## single-player, a party of one, Book I (start_run(p_difficulty)).
func new_game(p_difficulty: int) -> void:
	start_run(p_difficulty)


## Start a fresh run of any mode (2.0): `p_mode` (Defs.GameMode), `p_party` heroes (clamped to
## 1..Defs.MAX_PLAYERS), campaign book `p_book` (1 or 2). Every run of every slot is reset (full energy, the club,
## an empty belt, no glider, zeroed statistics); the team state as in new_game(). Emits the 1.0 signals of
## new_game() in their order, then run_*_changed for slots 1..party - 1.
func start_run(p_difficulty: int, p_mode: int = Defs.GameMode.SINGLE, p_party: int = 1, p_book: int = 1) -> void:
	mode = p_mode
	party = clampi(p_party, 1, Defs.MAX_PLAYERS)
	book = maxi(p_book, 1)
	difficulty = p_difficulty
	score = 0
	lives = Tuning.LIVES_START
	letters = 0
	feast_kit = 0
	warp_return_level = &""
	level_id = &""
	_next_life_at = Tuning.EXTRA_LIFE_EVERY
	_entry = {}
	# P1 (the 1.0 weapon, glider and energy) and every other slot: club, empty belt, no glider, full energy.
	for run: PlayerRun in runs:
		run.reset_run()
	_reset_level_progress()
	run_started.emit(difficulty)
	score_changed.emit(score)
	lives_changed.emit(lives)
	letters_changed.emit(letters)
	feast_kit_changed.emit(feast_kit)
	runs[0].emit_weapon()
	runs[0].emit_glider()
	for slot: int in range(1, party):
		runs[slot].emit_energy()
		runs[slot].emit_weapon()
		runs[slot].emit_belt()
		runs[slot].emit_glider()


## The run of player slot `slot` (0..Defs.MAX_PLAYERS - 1); null (and an error) for another value.
func get_run(slot: int) -> PlayerRun:
	if slot < 0 or slot >= runs.size():
		push_error("Game.get_run: no player slot %d" % slot)
		return null
	return runs[slot]


## The runs of the heroes in play: slots 0..party - 1 (a new array; the runs themselves are the shared ones).
func party_runs() -> Array[PlayerRun]:
	return runs.slice(0, party)


## A player joined or left during a run (Flow.join_player / leave_player, DESIGN.md D.1): the run continues as
## `p_mode` (Defs.GameMode) with `p_party` heroes. The score, lives, letters and every kept run stay; a slot that joins
## starts like a new run's hero (full energy, the club, an empty belt, no glider, zeroed statistics; his colour kept)
## and reports through run_*_changed. Nothing else changes (Flow restarts the stage in the other layout).
func set_party(p_mode: int, p_party: int) -> void:
	var before: int = party
	mode = p_mode
	party = clampi(p_party, 1, Defs.MAX_PLAYERS)
	for slot: int in range(maxi(before, 1), party):
		runs[slot].reset_run()
		runs[slot].emit_energy()
		runs[slot].emit_weapon()
		runs[slot].emit_belt()
		runs[slot].emit_glider()


## Prepare the state for entering `p_level_id`. With `carry_progress` the completion counters and the tally list
## are kept (entering a linked sub-stage or a bonus stage, GAMEPLAY.md 1.1); otherwise they start at zero.
## Every hero of the party starts with full energy and without the glider.
func begin_level(p_level_id: StringName, carry_progress: bool = false) -> void:
	level_id = p_level_id
	has_checkpoint = false
	checkpoint_pos = Vector2i.ZERO
	exit_unlocked = false
	has_glider = false
	_reset_energy()
	for slot: int in range(1, party):
		runs[slot].has_glider = false
		runs[slot].reset_energy()
	if not carry_progress:
		_reset_level_progress()
		if mode == Defs.GameMode.COOP:
			# The tally medals count one stage (a linked sub-stage or bonus stage carries them on, as the tally list).
			for slot: int in party:
				runs[slot].reset_stats()
	_entry = {
		"level_id": level_id, "score": score, "lives": lives, "next_life_at": _next_life_at, "letters": letters,
		"feast_kit": feast_kit, "weapon": weapon, "spots_total": spots_total, "spots_opened": spots_opened,
		"items_total": items_total, "items_collected": items_collected, "secrets_found": secrets_found,
		"tally_ids": tally_item_ids.duplicate(), "tally_indices": tally_item_indices.duplicate(),
		"tally_points": tally_item_points.duplicate(), "hands": _party_hands(), "belts": _party_belts(),
	}
	runs[0].emit_energy()
	runs[0].emit_glider()
	completion_changed.emit(completion_percent())
	for slot: int in range(1, party):
		runs[slot].emit_energy()
		runs[slot].emit_glider()


## Put the run back to how it was when the current level was entered (pause menu "restart level", see
## Flow.restart_level): score, letters, feast kit, weapon, the completion counters and the tally list return to
## their values at begin_level(). Lives lost since then stay lost and lives won since then (by score or by a 1UP
## that will be lying in the level again) are taken back, so a restart neither costs nor earns anything - the
## level's items reappear, so keeping the score would let a player farm points and extra lives. Energy and glider
## are reset by the begin_level() of the restart itself. Returns false (nothing changed) when the current level was
## not entered through begin_level() in this run.
func restore_level_entry() -> bool:
	if _entry.is_empty() or StringName(_entry["level_id"]) != level_id:
		return false
	score = int(_entry["score"])
	_next_life_at = int(_entry["next_life_at"])
	lives = mini(lives, int(_entry["lives"]))
	letters = int(_entry["letters"])
	feast_kit = int(_entry["feast_kit"])
	weapon = int(_entry["weapon"])
	spots_total = int(_entry["spots_total"])
	spots_opened = int(_entry["spots_opened"])
	items_total = int(_entry["items_total"])
	items_collected = int(_entry["items_collected"])
	secrets_found = int(_entry["secrets_found"])
	tally_item_ids = (_entry["tally_ids"] as Array[StringName]).duplicate()
	tally_item_indices = (_entry["tally_indices"] as PackedInt32Array).duplicate()
	tally_item_points = (_entry["tally_points"] as PackedInt32Array).duplicate()
	var hands: PackedInt32Array = _entry["hands"]
	var belts: PackedInt32Array = _entry["belts"]
	runs[0].belt = belts[0]
	for slot: int in range(1, mini(party, hands.size())):
		runs[slot].weapon = hands[slot]
		runs[slot].belt = belts[slot]
	score_changed.emit(score)
	lives_changed.emit(lives)
	letters_changed.emit(letters)
	feast_kit_changed.emit(feast_kit)
	runs[0].emit_weapon()
	completion_changed.emit(completion_percent())
	runs[0].emit_belt()
	for slot: int in range(1, mini(party, hands.size())):
		runs[slot].emit_weapon()
		runs[slot].emit_belt()
	return true


## Add displayed points. Awards extra lives every Tuning.EXTRA_LIFE_EVERY points. Returns the new score.
func add_score(points: int) -> int:
	if points <= 0:
		return score
	score += points
	score_changed.emit(score)
	while score >= _next_life_at:
		_next_life_at += Tuning.EXTRA_LIFE_EVERY
		if lives < Tuning.LIVES_MAX:
			add_lives(1)
			extra_life_awarded.emit(lives)
	return score


## Add spare lives (clamped to Tuning.LIVES_MAX).
func add_lives(count: int = 1) -> void:
	lives = clampi(lives + count, 0, Tuning.LIVES_MAX)
	lives_changed.emit(lives)


## Spend one life after a death. Returns true when the run continues, false on game over (no lives were left).
func lose_life() -> bool:
	if lives <= 0:
		return false
	lives -= 1
	lives_changed.emit(lives)
	return true


## Add bones; every Tuning.BONES_PER_HEART bones restore one heart while below the maximum (GAMEPLAY.md 4.2).
## Returns the number of hearts restored. (P1: PlayerRun.add_bones of runs[0].)
func add_bones(count: int = 1) -> int:
	return runs[0].add_bones(count)


## Heart item: +1 heart if below the maximum. Returns false (item stays in place) when already full. (P1)
func add_heart() -> bool:
	return runs[0].add_heart()


## Enemy hit: lose one heart. Returns true when the hero is DEAD (he was at 0 hearts; PHYSICS.md 10.2). (P1)
func lose_heart() -> bool:
	return runs[0].lose_heart()


## Boss body hit: lose one bone (borrowing from a heart). Returns true when the hero is DEAD. (P1)
func lose_bone() -> bool:
	return runs[0].lose_bone()


## Skull item: all energy is thrown out. Returns the number of bones to scatter (hearts x 6 + spare bones). (P1)
func scatter_energy() -> int:
	return runs[0].scatter_energy()


## Collect letter `index` (0..4). Returns true when this completed the word (mask is cleared, jackpot is the
## caller's job).
func collect_letter(index: int) -> bool:
	letters |= 1 << clampi(index, 0, Tuning.LETTER_COUNT - 1)
	letters_changed.emit(letters)
	if letters == (1 << Tuning.LETTER_COUNT) - 1:
		letters_completed.emit()
		letters = 0
		letters_changed.emit(letters)
		return true
	return false


## Collect feast-kit piece `index` (0..2). Returns true when the kit is complete (mask is cleared; the caller
## starts the feast on the hero).
func collect_feast_piece(index: int) -> bool:
	feast_kit |= 1 << clampi(index, 0, Tuning.FEAST_PIECES - 1)
	feast_kit_changed.emit(feast_kit)
	if feast_kit == (1 << Tuning.FEAST_PIECES) - 1:
		feast_kit = 0
		feast_kit_changed.emit(feast_kit)
		return true
	return false


## Switch weapon (Defs.Weapon). (P1's hand: PlayerRun.set_weapon of runs[0].)
func set_weapon(p_weapon: int) -> void:
	runs[0].set_weapon(p_weapon)


## Give or remove the hang-glider. (P1)
func set_glider(carrying: bool) -> void:
	runs[0].set_glider(carrying)


## Unlock the exit of the current level (fire-starter collected or dropped by a boss).
func unlock_exit() -> void:
	if exit_unlocked:
		return
	exit_unlocked = true
	Events.exit_unlocked.emit()


## Store the respawn point (feet point, logical px).
func set_checkpoint(pos: Vector2i) -> void:
	has_checkpoint = true
	checkpoint_pos = pos
	checkpoint_changed.emit(pos)


## State changes of a respawn after a death (PHYSICS.md 10.4 step 3): 3 hearts, no bones, glider lost,
## tally list cleared. Weapon, letters, score, collected counters are kept. With a party (a team wipe) every hero
## of the party is refilled; the revive of one hero is that hero's run (PlayerRun.reset_energy, set_glider).
func on_respawn() -> void:
	_reset_energy()
	has_glider = false
	for slot: int in range(1, party):
		runs[slot].reset_energy()
		runs[slot].has_glider = false
	clear_tally()
	runs[0].emit_energy()
	runs[0].emit_glider()
	for slot: int in range(1, party):
		runs[slot].emit_energy()
		runs[slot].emit_glider()


## Register level totals for the completion percentage (called by the level loader; adds to the totals so a
## linked bonus stage counts with its source level, GAMEPLAY.md 12.4).
func add_completion_totals(hidden_spots: int, placed_items: int) -> void:
	spots_total += hidden_spots
	items_total += placed_items
	completion_changed.emit(completion_percent())


## One hidden spot / breakable block was used up.
func count_spot_opened() -> void:
	spots_opened += 1
	completion_changed.emit(completion_percent())


## One map-placed bonus item was collected.
func count_item_collected() -> void:
	items_collected += 1
	completion_changed.emit(completion_percent())


## Completion percentage 0..100 (GAMEPLAY.md 3.5, without the original's doubling quirk).
func completion_percent() -> int:
	var total: int = spots_total + items_total
	if total <= 0:
		return 100
	return clampi((spots_opened + items_collected) * 100 / total, 0, 100)


## Remember a collected bonus item for the end-of-level double (GAMEPLAY.md 3.4).
func add_tally_item(item_id: StringName, index: int, points: int) -> void:
	tally_item_ids.append(item_id)
	tally_item_indices.append(index)
	tally_item_points.append(points)


## Forget the tally list (death, or after the tally was paid).
func clear_tally() -> void:
	tally_item_ids.clear()
	tally_item_indices.clear()
	tally_item_points.clear()


## Number of items waiting for the tally.
func tally_count() -> int:
	return tally_item_ids.size()


## True when the hero is on full energy. (P1)
func is_full_energy() -> bool:
	return runs[0].is_full_energy()


static func _make_runs() -> Array[PlayerRun]:
	var result: Array[PlayerRun] = []
	for slot: int in Defs.MAX_PLAYERS:
		result.append(PlayerRun.new(slot))
	return result


func _reset_energy() -> void:
	runs[0].reset_energy()


func _party_hands() -> PackedInt32Array:
	var result: PackedInt32Array = PackedInt32Array()
	for run: PlayerRun in runs:
		result.append(run.weapon)
	return result


func _party_belts() -> PackedInt32Array:
	var result: PackedInt32Array = PackedInt32Array()
	for run: PlayerRun in runs:
		result.append(run.belt)
	return result


# The legacy signals mean P1 and come first, as in 1.0; then the per-slot twin.
func _on_run_energy_changed(p_hearts: int, p_bones: int, slot: int) -> void:
	if slot == 0:
		energy_changed.emit(p_hearts, p_bones)
	run_energy_changed.emit(slot, p_hearts, p_bones)


func _on_run_weapon_changed(p_weapon: int, slot: int) -> void:
	if slot == 0:
		weapon_changed.emit(p_weapon)
	run_weapon_changed.emit(slot, p_weapon)


func _on_run_belt_changed(p_belt: int, slot: int) -> void:
	run_belt_changed.emit(slot, p_belt)


func _on_run_glider_changed(carrying: bool, slot: int) -> void:
	if slot == 0:
		glider_changed.emit(carrying)
	run_glider_changed.emit(slot, carrying)


func _reset_level_progress() -> void:
	spots_total = 0
	spots_opened = 0
	items_total = 0
	items_collected = 0
	secrets_found = 0
	clear_tally()
