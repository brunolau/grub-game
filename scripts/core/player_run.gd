class_name PlayerRun
extends RefCounted
## The run state of one hero (one player slot): energy, the two weapon places, the glider and statistics
## (docs/expansion/TECH_AUDIT.md 4.2, docs/expansion/PLAN.md P0.4).
##
## CONTRACT FILE. Owner: core. `Game` owns one per slot (`Game.runs`, Defs.MAX_PLAYERS of them, always allocated
## and never replaced, so a HUD panel may connect to a run once). The frozen `Game` fields `hearts`, `bones`,
## `weapon`, `has_glider` are properties of `Game.runs[0]`, and the frozen `Game` energy / weapon / glider methods
## call the methods below on `runs[0]`: P1 of a party is the 1.0 hero, with the same field writes and the same
## signals in the same order (Game re-emits its own `energy_changed`, `weapon_changed`, `glider_changed` for slot 0
## the moment this run emits them).
##
## Party rules (DESIGN.md D, E): in co-op every hero has his own hearts, bones, hand + belt and glider; score,
## lives, letters, feast kit, checkpoint and exit stay team state in `Game`. In versus the per-hero numbers live
## here (`score`, `stocks`); `Game.score` is not used.
## The methods keep the exact bodies of the 1.0 `Game` methods (GAMEPLAY.md 4.2, PHYSICS.md 10.2).

## Hearts (0..3) or the hidden bone fraction (0..5) changed.
signal energy_changed(hearts: int, bones: int)
## The weapon in the hand changed (Defs.Weapon).
signal weapon_changed(weapon: int)
## The weapon on the belt changed (Defs.Weapon, or BELT_EMPTY).
signal belt_changed(belt: int)
## The hero picked up or lost the hang-glider.
signal glider_changed(carrying: bool)

## `belt` value: nothing rides on the belt (the club is in the hand and no special is owned).
const BELT_EMPTY: int = -1

## Player slot of this run (0 = P1).
var slot: int = 0
## Hearts, 0..Tuning.ENERGY_START. A hit at 0 hearts kills (PHYSICS.md 10.2).
var hearts: int = Tuning.ENERGY_START
## Bones toward the next heart, 0..Tuning.BONES_PER_HEART - 1 (never shown on the HUD).
var bones: int = 0
## The weapon in the hand (Defs.Weapon); kept through deaths and levels until game over. In Book I solo (belt rule
## `carry`) it is the one weapon of 1.0.
var weapon: int = Defs.Weapon.CLUB
## The weapon on the belt (DESIGN.md C.1): Defs.Weapon.CLUB while a special is in the hand, the owned special while
## the club is in the hand, BELT_EMPTY when no special is owned. Always BELT_EMPTY in Book I solo (`carry`).
var belt: int = BELT_EMPTY
## True while the hero carries the hang-glider.
var has_glider: bool = false

# --- Statistics (co-op tally lines, versus results; nothing in the simulation reads them) -------------------------
## Points this hero earned. Co-op: his share of the team `Game.score` (tally line); versus: his match score.
var score: int = 0
## Enemies (co-op) or rivals (versus, `Events.hero_ko` credit) this hero knocked out.
var kills: int = 0
## Deaths (single-player), downs (co-op) or knock-outs taken (versus).
var deaths: int = 0
## Partners this hero hatched (co-op Egg Hatch).
var revives: int = 0
## Items this hero picked up.
var picked: int = 0
## Versus stock lives left (`Stock` option and modes with respawn); 0 elsewhere.
var stocks: int = 0

# --- Look (chosen on the join panel / in the versus lobby; nothing in the simulation reads it) -------------------
## Colour of this player (DESIGN.md D.11, F.1): a palette name of assets/sprites/player/palettes/hero_palettes.json
## (`yellow`, `blue`, `pink`, `green`, `white`, `gold`); &"" = the slot's default from that file (P1 yellow = the 1.0
## look). Written by the join panel / lobby (ui-A), read by the hero's palette (player-A, hero_palette.gd), the HUD and
## the versus screens (ui-B / ui-A). Kept by reset_run (a new run keeps the players' colours).
var palette: StringName = &""
## Loincloth pattern index of hero_palettes.json (`patterns`); -1 = the slot's default pattern. As [member palette].
var pattern: int = -1


func _init(p_slot: int = 0) -> void:
	slot = p_slot


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


## True when the hero is on full energy.
func is_full_energy() -> bool:
	return hearts >= Tuning.ENERGY_START


## Full energy (3 hearts, no bones) without a signal; the caller emits (see [method emit_energy]).
func reset_energy() -> void:
	hearts = Tuning.ENERGY_START
	bones = 0


## Put a weapon in the hand (Defs.Weapon, clamped to the known weapons). The belt is not touched: the belt rules of
## DESIGN.md C.1 (pick-up, swap) are the hero's (player module), built on [method set_belt] and
## [method swap_belt].
func set_weapon(p_weapon: int) -> void:
	weapon = clampi(p_weapon, 0, Defs.Weapon.SPEAR)
	weapon_changed.emit(weapon)


## Put a weapon on the belt (Defs.Weapon) or empty it (BELT_EMPTY; any value below 0).
func set_belt(p_belt: int) -> void:
	belt = BELT_EMPTY if p_belt < 0 else clampi(p_belt, 0, Defs.Weapon.SPEAR)
	belt_changed.emit(belt)


## Swap hand and belt (the Swap action, DESIGN.md C.1 rule 3). Returns false (nothing changed, no signal) when the
## belt is empty. The attack gate and the lock-out are the hero's.
func swap_belt() -> bool:
	if belt == BELT_EMPTY:
		return false
	var hand: int = weapon
	weapon = belt
	belt = hand
	weapon_changed.emit(weapon)
	belt_changed.emit(belt)
	return true


## The special this hero owns, in the hand or on the belt (Defs.Weapon), or BELT_EMPTY when he has only the club.
func special() -> int:
	if weapon != Defs.Weapon.CLUB:
		return weapon
	return belt if belt != Defs.Weapon.CLUB else BELT_EMPTY


## The fresh-club rule (DESIGN.md C.1 rule 4, meta `belt = fresh`): the club goes into the hand and an owned special
## onto the belt. Emits both signals.
func take_fresh_club() -> void:
	var owned: int = special()
	weapon = Defs.Weapon.CLUB
	belt = owned
	weapon_changed.emit(weapon)
	belt_changed.emit(belt)


## Give or remove the hang-glider.
func set_glider(carrying: bool) -> void:
	if has_glider == carrying:
		return
	has_glider = carrying
	glider_changed.emit(has_glider)


## Emit the current energy, for callers that changed it through [method reset_energy] or a field write.
func emit_energy() -> void:
	energy_changed.emit(hearts, bones)


## Emit the current hand weapon.
func emit_weapon() -> void:
	weapon_changed.emit(weapon)


## Emit the current belt.
func emit_belt() -> void:
	belt_changed.emit(belt)


## Emit the current glider state.
func emit_glider() -> void:
	glider_changed.emit(has_glider)


## The state of a new run without signals: full energy, the club in the hand, an empty belt, no glider, zeroed
## statistics. Game.new_game() / start_run() use it for every slot.
func reset_run() -> void:
	reset_energy()
	weapon = Defs.Weapon.CLUB
	belt = BELT_EMPTY
	has_glider = false
	reset_stats()


## Zero the statistics (a new run or a new versus match).
func reset_stats() -> void:
	score = 0
	kills = 0
	deaths = 0
	revives = 0
	picked = 0
	stocks = 0
