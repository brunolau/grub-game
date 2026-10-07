class_name BotSenses
extends RefCounted
## What a bot may know about a running arena (DESIGN.md E.7: "decided from the previous tick's state ... never knows
## what a spot or crate contains"): the heroes, the items lying in view, the visible spots, the cookpots, and the
## Grub Stack ledger of the referee. Read-only; called from GameInput.sample() between ticks.
##
## Owner: core-B. The ledger and the pots belong to other modules, so they are read by duck typing (has_method) and a
## missing member reads as a neutral value - the bots keep working while the referee (world-B, VersusReferee as
## `LevelBase.party_driver`) or a cookpot (objects-B, Cookpot) is missing or changes:
##   referee: stack_of(slot), banked_of(slot), lids_closed(), ticks_left(), team_of(slot), food_value(item)
##   cookpot: bank_rect(), is_open(), is_slot_banking(slot), team

## Stack units of the items when the referee has no food_value() (GAMEPLAY.md 13.10.3: small food 1, big food 2,
## treasure 5, giant bonus 10; the skull spills everything, a grenade makes every rival spill).
const FALLBACK_VALUES: Dictionary = {
	&"items/food": VersusTuning.FOOD_SMALL, &"items/treasure": VersusTuning.FOOD_TREASURE,
	&"items/giant_bonus": VersusTuning.FOOD_GIANT, &"items/grenade": 3, &"items/feast_piece": 3,
	&"items/weapon": 2, &"items/skull": -100,
}


## The referee of the level (its party driver when it keeps a Grub Stack ledger), or null.
static func referee(level: LevelBase) -> Object:
	if level == null or level.party_driver == null or not is_instance_valid(level.party_driver):
		return null
	return level.party_driver if level.party_driver.has_method(&"stack_of") else null


## Units on the head of the hero in `slot` (0 without a referee).
static func stack_of(level: LevelBase, slot: int) -> int:
	var ref: Object = referee(level)
	return int(ref.call(&"stack_of", slot)) if ref != null else 0


## Units the hero in `slot` has banked (0 without a referee or when it keeps no banks).
static func banked_of(level: LevelBase, slot: int) -> int:
	var ref: Object = referee(level)
	return int(ref.call(&"banked_of", slot)) if ref != null and ref.has_method(&"banked_of") else 0


## True when the pot lids are shut (Feast Rush): no banking.
static func lids_closed(level: LevelBase) -> bool:
	var ref: Object = referee(level)
	if ref != null and ref.has_method(&"lids_closed"):
		return bool(ref.call(&"lids_closed"))
	for pot: SimEntity in cookpots(level):
		if pot.has_method(&"is_open") and not bool(pot.call(&"is_open")):
			return true
	return false


## Ticks left in the round; -1 when unknown.
static func ticks_left(level: LevelBase) -> int:
	var ref: Object = referee(level)
	return int(ref.call(&"ticks_left")) if ref != null and ref.has_method(&"ticks_left") else -1


## Team of a slot (2v2); -1 = free for all.
static func team_of(level: LevelBase, slot: int) -> int:
	var ref: Object = referee(level)
	return int(ref.call(&"team_of", slot)) if ref != null and ref.has_method(&"team_of") else -1


## True when `a` and `b` are rivals (different slots, not teammates).
static func are_rivals(level: LevelBase, a: int, b: int) -> bool:
	if a == b:
		return false
	var team: int = team_of(level, a)
	return team < 0 or team != team_of(level, b)


## Stack units an item would add (negative = harmful, 0 = not worth a detour).
static func food_value(level: LevelBase, item: CollectibleBase) -> int:
	var ref: Object = referee(level)
	if ref != null and ref.has_method(&"food_value"):
		return int(ref.call(&"food_value", item))
	var value: int = int(FALLBACK_VALUES.get(item.item_id, 0))
	if item.item_id == &"items/food" and item.points >= 500:
		value = VersusTuning.FOOD_BIG
	return value


## Items in the level a hero can pick up now - and, with `pending`, the dropped ones that cannot be picked up yet
## (just thrown out of a spot or knocked off a head: worth running to).
static func items(level: LevelBase, pending: bool = true) -> Array[CollectibleBase]:
	var result: Array[CollectibleBase] = []
	if level == null:
		return result
	for entity: SimEntity in level.get_kind(Defs.Kind.COLLECTIBLE):
		var item: CollectibleBase = entity as CollectibleBase
		if item == null or item.is_queued_for_deletion() or item.collected:
			continue
		if item.can_be_collected() or (pending and item.dropped):
			result.append(item)
	return result


## Spots worth a strike: hittables that are not opened (visible arena spots; their contents stay unknown).
static func spots(level: LevelBase) -> Array[HittableBase]:
	var result: Array[HittableBase] = []
	if level == null:
		return result
	for entity: SimEntity in level.get_kind(Defs.Kind.HITTABLE):
		var spot: HittableBase = entity as HittableBase
		if spot == null or spot.opened or spot.is_queued_for_deletion():
			continue
		if spot.has_method(&"is_empty") and bool(spot.call(&"is_empty")):
			continue
		result.append(spot)
	return result


## The cookpots of the level (entities with bank_rect()), in spawn order.
static func cookpots(level: LevelBase) -> Array[SimEntity]:
	var result: Array[SimEntity] = []
	if level == null:
		return result
	for entity: SimEntity in level.get_kind(Defs.Kind.OTHER):
		if entity.has_method(&"bank_rect") and not entity.is_queued_for_deletion():
			result.append(entity)
	return result


## The area the feet of a banking hero must be in (Cookpot.bank_rect; else a 24 px wide strip on the pot's floor).
static func bank_rect(pot: SimEntity) -> Rect2i:
	if pot.has_method(&"bank_rect"):
		return pot.call(&"bank_rect")
	return Rect2i(pot.sim_pos.x - 12, pot.sim_pos.y - 15, 24, 16)


## True when `pot` banks for `slot` now (open, team allowed).
static func pot_usable(level: LevelBase, pot: SimEntity, slot: int) -> bool:
	if pot.has_method(&"is_open") and not bool(pot.call(&"is_open")):
		return false
	var team: Variant = pot.get(&"team")
	if team != null and int(team) >= 0 and team_of(level, slot) >= 0 and int(team) != team_of(level, slot):
		return false
	return not lids_closed(level)


## True when the hero in `slot` is banking in any pot.
static func is_banking(level: LevelBase, slot: int) -> bool:
	var ref: Object = referee(level)
	if ref != null and ref.has_method(&"is_banking"):
		return bool(ref.call(&"is_banking", slot))
	for pot: SimEntity in cookpots(level):
		if pot.has_method(&"is_slot_banking") and bool(pot.call(&"is_slot_banking", slot)):
			return true
	return false
