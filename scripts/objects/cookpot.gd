class_name Cookpot
extends SimEntity
## `objects/cookpot` (arenas only; optional `team=1|2`): the Grub Stack bank (DESIGN.md E.3, GAMEPLAY.md 13.10.3). A
## hero crouching inside it banks one unit of his stack per VersusTuning.COOKPOT_BANK_TICKS crouched ticks; banked
## units are safe; final score = banked + stack. A banking hero is crouched and a stomp on him steals double (the
## referee asks [method slot_banking_anywhere] for VersusTuning.stomp_steal). In the Feast Rush (the last
## VersusTuning.FEAST_RUSH_TICKS of a round) the lid closes: nothing is banked. 2v2: one shared pot per team.
##
## Owner: objects-B (docs/expansion/PLAN.md 4.1; P2.7 pulled into phase 1 for the Totem Ring slice).
##
## The ledger (stacks and banks) is the referee's (world-B: `Game.level.party_driver` in an arena), reached by duck
## typing so neither side waits for the other (build/engine_requests/wf7_objects-B_to_world-B.txt). The "keeper":
##   bank_from_stack(slot: int, units: int) -> int   required to bank: moves up to `units` from his stack to his bank
##   lids_closed() -> bool                           optional: polled every tick; true = the lid is shut (Feast Rush)
##   team_of(slot: int) -> int                       optional: a pot with `team` >= 0 banks only that team
## [member keeper] overrides the lookup (tests, a mode without a referee). Without a keeper nothing is banked; the
## lid can still be driven with [method close_lid] / [method open_lid] / [method set_all_lids].
##
## Banking rule (also for the bots, core-B): the hero is alive and hatched, grounded, in the crouch state (5, not
## crawl), his feet point inside [method bank_rect], the pot open, and his team allowed; every tick that holds counts,
## the counter restarts whenever it fails; on the COOKPOT_BANK_TICKS-th tick one unit moves. Runs in CONTACT_ITEMS
## (after every hero moved), heroes in LevelBase.contact_order().

## Half width of the banking area (px): the feet point must be within it of the pot's centre. [own]
const BANK_HALF_W: int = 12
## Height of the banking area (px) above the floor surface; the feet stand on that surface. [own]
const BANK_H: int = 16
## Drawing (art px): the pot body, rim and lid.
const POT_HALF_W_ART: float = 30.0
const POT_BODY_H_ART: float = 22.0
const POT_FRONT_H_ART: float = 14.0
const CLAY: Color = Color(0.62, 0.33, 0.18)
const CLAY_DARK: Color = Color(0.35, 0.17, 0.09)
const CLAY_LIGHT: Color = Color(0.80, 0.50, 0.28)
const BROTH: Color = Color(0.86, 0.66, 0.24)
const LID: Color = Color(0.45, 0.42, 0.38)
const LID_DARK: Color = Color(0.22, 0.20, 0.18)
const FX_PUFF: StringName = &"fx/star_puff"

## Team allowed to bank here (`team=1|2` in a 2v2 arena); -1 = anyone.
var team: int = -1
## True while the lid is shut (Feast Rush): nothing is banked. Polled from the keeper's lids_closed() when it has one.
var lid_closed: bool = false
## The ledger this pot banks into; null = `Game.level.party_driver` when that has `bank_from_stack` (test hook).
var keeper: Object = null
## Units banked through this pot since the level started (statistics, tests).
var banked_total: int = 0

## Consecutive crouched ticks inside, per player slot.
var _crouch_ticks: PackedInt32Array = PackedInt32Array()
## Bit per slot crouched inside the open pot on the last tick (banking).
var _banking_mask: int = 0
var _front: Node2D = null


func _init() -> void:
	z_index = Defs.Z_OBJECTS
	set_box(Vector3i(BANK_HALF_W * 2, BANK_H, BANK_HALF_W))
	_crouch_ticks.resize(Defs.MAX_PLAYERS)


func _ready() -> void:
	# The front of the pot is drawn over the hero crouching inside it.
	_front = Node2D.new()
	_front.z_as_relative = false
	_front.z_index = Defs.Z_PLAYER + 1
	_front.draw.connect(_draw_front)
	add_child(_front)


func _sim_phases() -> PackedInt32Array:
	return PackedInt32Array([Defs.Phase.CONTACT_ITEMS])


func _apply_params(params: Dictionary) -> void:
	team = int(params.get("team", -1))
	if team <= 0:
		team = -1


# --- Queries (referee, bots, HUD) -------------------------------------------------------------------------------------

## True while the lid is open (outside the Feast Rush): banking is possible.
func is_open() -> bool:
	return not lid_closed


## The area (logical px) the feet point of a crouched, grounded hero must be in to bank: BANK_HALF_W either side of
## the pot's centre, BANK_H tall, its bottom row the floor surface (sim_pos.y).
func bank_rect() -> Rect2i:
	return Rect2i(sim_pos.x - BANK_HALF_W, sim_pos.y - BANK_H + 1, BANK_HALF_W * 2, BANK_H)


## True when the hero of player slot `slot` banked here on the last tick (crouched inside the open pot).
func is_slot_banking(slot: int) -> bool:
	return slot >= 0 and slot < Defs.MAX_PLAYERS and (_banking_mask & (1 << slot)) != 0


## The lowest player slot banking here now, -1 when nobody is.
func banker_slot() -> int:
	for slot: int in Defs.MAX_PLAYERS:
		if (_banking_mask & (1 << slot)) != 0:
			return slot
	return -1


## True when `hero` stands where this pot banks him (alive, hatched, grounded, crouched, feet in [method bank_rect]);
## the lid and the team are not tested.
func holds(hero: PlayerBase) -> bool:
	if hero == null or hero.dead or hero.is_down() or not hero.is_crouching() or not hero.is_grounded():
		return false
	return Overlap.point_in(bank_rect(), hero.sim_pos.x, hero.sim_pos.y)


## Shut the lid (Feast Rush): no banking until [method open_lid]. A keeper with lids_closed() overrides it per tick.
func close_lid() -> void:
	if not lid_closed:
		lid_closed = true
		_crouch_ticks.fill(0)
		_banking_mask = 0
		_doze_wake_now()
		queue_redraw()
		if _front != null:
			_front.queue_redraw()


## Open the lid again (a new round).
func open_lid() -> void:
	if lid_closed:
		lid_closed = false
		queue_redraw()
		if _front != null:
			_front.queue_redraw()


## Every cookpot of the level in spawn order.
static func pots_of(level: LevelBase) -> Array[Cookpot]:
	var pots: Array[Cookpot] = []
	if level == null:
		return pots
	for entity: SimEntity in level.get_kind(Defs.Kind.OTHER):
		var pot: Cookpot = entity as Cookpot
		if pot != null and not pot.is_queued_for_deletion():
			pots.append(pot)
	return pots


## Close (true) or open (false) the lid of every cookpot of the level (the referee's Feast Rush and round start).
static func set_all_lids(level: LevelBase, closed: bool) -> void:
	for pot: Cookpot in pots_of(level):
		if closed:
			pot.close_lid()
		else:
			pot.open_lid()


## True when the hero of player slot `slot` is banking in any cookpot of the level (the double steal of a stomp).
static func slot_banking_anywhere(level: LevelBase, slot: int) -> bool:
	if level == null:
		return false
	for entity: SimEntity in level.get_kind(Defs.Kind.OTHER):
		var pot: Cookpot = entity as Cookpot
		if pot != null and pot.is_slot_banking(slot):
			return true
	return false


# --- Simulation -------------------------------------------------------------------------------------------------------

## Dozing (SimEntity): with nobody crouching inside, a tick only re-reads the lid, which the keeper never changes while
## no hero is near (arenas are one screen: the pot is in view and never dozes there anyway).
func _doze_area() -> Rect2i:
	return _doze_box()


func _can_doze() -> bool:
	return _banking_mask == 0


func _sim_tick(phase: int) -> void:
	if phase != Defs.Phase.CONTACT_ITEMS:
		return
	var level: LevelBase = Game.level
	if level == null:
		return
	var ledger: Object = _keeper(level)
	if ledger != null and ledger.has_method(&"lids_closed"):
		if bool(ledger.call(&"lids_closed")):
			close_lid()
		else:
			open_lid()
	var before: int = _banking_mask
	_banking_mask = 0
	for hero: PlayerBase in level.contact_order():
		var slot: int = hero.slot
		if lid_closed or not holds(hero) or not _team_allows(ledger, slot):
			_crouch_ticks[slot] = 0
			continue
		_banking_mask |= 1 << slot
		_crouch_ticks[slot] += 1
		if _crouch_ticks[slot] >= VersusTuning.COOKPOT_BANK_TICKS:
			_crouch_ticks[slot] = 0
			_bank_one(level, ledger, hero)
	if _banking_mask != before and _banking_mask == 0:
		_doze_note()


func _bank_one(level: LevelBase, ledger: Object, hero: PlayerBase) -> void:
	if ledger == null or not ledger.has_method(&"bank_from_stack"):
		return
	var moved: int = int(ledger.call(&"bank_from_stack", hero.slot, 1))
	if moved <= 0:
		return
	banked_total += moved
	_cue(Sfx.COOKPOT_BANK, Sfx.PICKUP)
	level.spawn_fx(FX_PUFF, Vector2i(sim_pos.x, sim_pos.y - BANK_H))


func _team_allows(ledger: Object, slot: int) -> bool:
	if team < 0 or ledger == null or not ledger.has_method(&"team_of"):
		return true
	return int(ledger.call(&"team_of", slot)) == team


func _keeper(level: LevelBase) -> Object:
	if keeper != null:
		return keeper
	var driver: SimEntity = level.party_driver
	if driver != null and driver.has_method(&"bank_from_stack"):
		return driver
	return null


func _on_level_reset() -> void:
	_crouch_ticks.fill(0)
	_banking_mask = 0


## Play `event` when the audio table has it, else the 1.0 cue `fallback` (no error while core-A adds the 2.0 rows).
static func _cue(event: StringName, fallback: StringName) -> void:
	if AudioTable.SFX.has(event):
		Audio.play_sfx(event)
	elif fallback != &"":
		Audio.play_sfx(fallback)


# --- Picture (no sheet yet: art-A request) ------------------------------------------------------------------------------

## Back of the pot and the broth (behind the hero).
func _draw() -> void:
	var w: float = POT_HALF_W_ART
	draw_rect(Rect2(-w, -POT_BODY_H_ART, w * 2.0, POT_BODY_H_ART), CLAY_DARK)
	if lid_closed:
		return
	draw_rect(Rect2(-w + 4.0, -POT_BODY_H_ART - 2.0, w * 2.0 - 8.0, 4.0), BROTH)


## Front of the pot (over the hero), and the lid when it is shut.
func _draw_front() -> void:
	var w: float = POT_HALF_W_ART
	var top: float = -POT_FRONT_H_ART
	_front.draw_colored_polygon(PackedVector2Array([
		Vector2(-w, top), Vector2(w, top), Vector2(w - 4.0, 0.0), Vector2(-w + 4.0, 0.0),
	]), CLAY)
	_front.draw_rect(Rect2(-w - 2.0, top - 3.0, w * 2.0 + 4.0, 4.0), CLAY_LIGHT)
	_front.draw_rect(Rect2(-w + 6.0, top + 5.0, w * 2.0 - 12.0, 2.0), CLAY_DARK)
	if lid_closed:
		var lid_top: float = -POT_BODY_H_ART - 6.0
		_front.draw_rect(Rect2(-w - 2.0, lid_top, w * 2.0 + 4.0, 6.0), LID)
		_front.draw_rect(Rect2(-6.0, lid_top - 6.0, 12.0, 6.0), LID_DARK)
