extends Node
## Autoload `Game`: the run state that outlives a level scene (GAMEPLAY.md 2-4, PHYSICS.md 10.2).
##
## CONTRACT FILE (docs/ARCHITECTURE.md 3.5). Owner: core. Public members and signals are frozen.
##
## Everything here is plain integer state changed through methods; each change emits one signal so the HUD never
## polls. Scores are DISPLAYED points (the original's internal score x 10). The per-tick hero state (velocities,
## timers) lives in PlayerBase, not here.

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

## Difficulty of the current run (Defs.Difficulty).
var difficulty: int = Defs.Difficulty.BEGINNER
## Displayed score.
var score: int = 0
## Spare lives (starts at Tuning.LIVES_START; dying at 0 is game over).
var lives: int = Tuning.LIVES_START
## Hearts, 0..Tuning.ENERGY_START. A hit at 0 hearts kills (PHYSICS.md 10.2).
var hearts: int = Tuning.ENERGY_START
## Bones toward the next heart, 0..Tuning.BONES_PER_HEART - 1 (never shown on the HUD).
var bones: int = 0
## Collected letters bit mask.
var letters: int = 0
## Collected feast-kit pieces bit mask.
var feast_kit: int = 0
## Current weapon (Defs.Weapon); kept through deaths and levels until game over.
var weapon: int = Defs.Weapon.CLUB
## True while the hero carries the hang-glider.
var has_glider: bool = false
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


## Start a fresh run: score 0, 2 spare lives, club, no letters (GAMEPLAY.md 11.1 step 9).
func new_game(p_difficulty: int) -> void:
	difficulty = p_difficulty
	score = 0
	lives = Tuning.LIVES_START
	letters = 0
	feast_kit = 0
	weapon = Defs.Weapon.CLUB
	has_glider = false
	warp_return_level = &""
	level_id = &""
	_next_life_at = Tuning.EXTRA_LIFE_EVERY
	_entry = {}
	_reset_energy()
	_reset_level_progress()
	run_started.emit(difficulty)
	score_changed.emit(score)
	lives_changed.emit(lives)
	letters_changed.emit(letters)
	feast_kit_changed.emit(feast_kit)
	weapon_changed.emit(weapon)
	glider_changed.emit(has_glider)


## Prepare the state for entering `p_level_id`. With `carry_progress` the completion counters and the tally list
## are kept (entering a linked sub-stage or a bonus stage, GAMEPLAY.md 1.1); otherwise they start at zero.
func begin_level(p_level_id: StringName, carry_progress: bool = false) -> void:
	level_id = p_level_id
	has_checkpoint = false
	checkpoint_pos = Vector2i.ZERO
	exit_unlocked = false
	has_glider = false
	_reset_energy()
	if not carry_progress:
		_reset_level_progress()
	_entry = {
		"level_id": level_id, "score": score, "lives": lives, "next_life_at": _next_life_at, "letters": letters,
		"feast_kit": feast_kit, "weapon": weapon, "spots_total": spots_total, "spots_opened": spots_opened,
		"items_total": items_total, "items_collected": items_collected, "secrets_found": secrets_found,
		"tally_ids": tally_item_ids.duplicate(), "tally_indices": tally_item_indices.duplicate(),
		"tally_points": tally_item_points.duplicate(),
	}
	energy_changed.emit(hearts, bones)
	glider_changed.emit(has_glider)
	completion_changed.emit(completion_percent())


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
	score_changed.emit(score)
	lives_changed.emit(lives)
	letters_changed.emit(letters)
	feast_kit_changed.emit(feast_kit)
	weapon_changed.emit(weapon)
	completion_changed.emit(completion_percent())
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
## Returns the number of hearts restored.
func add_bones(count: int = 1) -> int:
	var restored: int = 0
	bones += count
	while bones >= Tuning.BONES_PER_HEART:
		bones -= Tuning.BONES_PER_HEART
		if hearts < Tuning.ENERGY_START:
			hearts += 1
			restored += 1
	energy_changed.emit(hearts, bones)
	return restored


## Heart item: +1 heart if below the maximum. Returns false (item stays in place) when already full.
func add_heart() -> bool:
	if hearts >= Tuning.ENERGY_START:
		return false
	hearts += 1
	energy_changed.emit(hearts, bones)
	return true


## Enemy hit: lose one heart. Returns true when the hero is DEAD (he was at 0 hearts; PHYSICS.md 10.2).
func lose_heart() -> bool:
	if hearts <= 0:
		return true
	hearts -= 1
	energy_changed.emit(hearts, bones)
	return false


## Boss body hit: lose one bone (borrowing from a heart). Returns true when the hero is DEAD.
func lose_bone() -> bool:
	if bones > 0:
		bones -= 1
	elif hearts > 0:
		hearts -= 1
		bones = Tuning.BONES_PER_HEART - 1
	else:
		return true
	energy_changed.emit(hearts, bones)
	return false


## Skull item: all energy is thrown out. Returns the number of bones to scatter (hearts x 6 + spare bones).
func scatter_energy() -> int:
	var count: int = hearts * Tuning.BONES_PER_HEART + bones
	hearts = 0
	bones = 0
	energy_changed.emit(hearts, bones)
	return count


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


## Switch weapon (Defs.Weapon).
func set_weapon(p_weapon: int) -> void:
	weapon = clampi(p_weapon, 0, Defs.Weapon.BOOMERANG)
	weapon_changed.emit(weapon)


## Give or remove the hang-glider.
func set_glider(carrying: bool) -> void:
	if has_glider == carrying:
		return
	has_glider = carrying
	glider_changed.emit(has_glider)


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
## tally list cleared. Weapon, letters, score, collected counters are kept.
func on_respawn() -> void:
	_reset_energy()
	has_glider = false
	clear_tally()
	energy_changed.emit(hearts, bones)
	glider_changed.emit(has_glider)


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


## True when the hero is on full energy.
func is_full_energy() -> bool:
	return hearts >= Tuning.ENERGY_START


func _reset_energy() -> void:
	hearts = Tuning.ENERGY_START
	bones = 0


func _reset_level_progress() -> void:
	spots_total = 0
	spots_opened = 0
	items_total = 0
	items_collected = 0
	secrets_found = 0
	clear_tally()
