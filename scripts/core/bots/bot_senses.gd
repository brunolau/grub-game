class_name BotSenses
extends RefCounted
## What a bot may know about a running arena (DESIGN.md E.7: "decided from the previous tick's state ... never knows
## what a spot or crate contains"): the heroes, the items lying in view, the visible spots, the cookpots, and the
## Grub Stack ledger of the referee. Read-only; called from GameInput.sample() between ticks.
##
## Owner: core-B. The ledger and the pots belong to other modules, so they are read by duck typing (has_method) and a
## missing member reads as a neutral value - the bots keep working while the referee (world-B, VersusReferee as
## `LevelBase.party_driver`) or a cookpot (objects-B, Cookpot) is missing or changes:
##   referee: stack_of(slot), banked_of(slot), lids_closed(), ticks_left(), team_of(slot), food_value(item),
##            is_out(slot), grudge_pos(slot), grudge_ready(slot), danger_rects(lookahead), ember_holder(),
##            ember_pass_immune(slot), ember_hurry(), ball(), goal_rect(team), mode, phase
##   cookpot: bank_rect(), is_open(), is_slot_banking(slot), team
##   coconut (objects-B, objects/coconut): sim_pos, xvel, yvel, get_box()
## Requests and replies: build/engine_requests/wf8_core-B_to_world-B.txt, wf8_core-B_to_objects-B.txt.

## Stack units of the items when the referee has no food_value() (GAMEPLAY.md 13.10.3: small food 1, big food 2,
## treasure 5, giant bonus 10; the skull spills everything, a grenade makes every rival spill).
const FALLBACK_VALUES: Dictionary = {
	&"items/food": VersusTuning.FOOD_SMALL, &"items/treasure": VersusTuning.FOOD_TREASURE,
	&"items/giant_bonus": VersusTuning.FOOD_GIANT, &"items/grenade": 3, &"items/feast_piece": 3,
	&"items/weapon": 2, &"items/skull": -100,
}


## Item id of the coconut (Clubball) and of the goal zones, for the scan without a referee.
const BALL_ID_SCRIPT: String = "res://scripts/objects/coconut.gd"
const NO_POS: Vector2i = Vector2i(-1, -1)


## Tests: an object answering the referee's reading API instead of the level's referee (null = the real one).
static var test_referee: Object = null


## The referee of the level (its party driver when it keeps a Grub Stack ledger), or null.
static func referee(level: LevelBase) -> Object:
	if test_referee != null and is_instance_valid(test_referee):
		return test_referee
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


## The geysers of the level (objects-B's Geyser: is_spouting(), vent_rect()).
static func geysers(level: LevelBase) -> Array[SimEntity]:
	var result: Array[SimEntity] = []
	if level == null:
		return result
	for entity: SimEntity in level.get_kind(Defs.Kind.OTHER):
		if entity.has_method(&"vent_rect") and entity.has_method(&"is_spouting"):
			result.append(entity)
	return result


## True when the hero in `slot` is banking in any pot.
static func is_banking(level: LevelBase, slot: int) -> bool:
	var ref: Object = referee(level)
	if ref != null and ref.has_method(&"is_banking"):
		return bool(ref.call(&"is_banking", slot))
	for pot: SimEntity in cookpots(level):
		if pot.has_method(&"is_slot_banking") and bool(pot.call(&"is_slot_banking", slot)):
			return true
	return false


# =================================================================================================================
# The other launch modes (PLAN.md P2.4 names, read by duck typing; neutral without them)
# =================================================================================================================

## Defs.VersusMode of the running round (the referee's `mode`; Grub Stack without one).
static func mode(level: LevelBase) -> int:
	var ref: Object = referee(level)
	if ref != null:
		var value: Variant = ref.get(&"mode")
		if value is int:
			return int(value)
	return Defs.VersusMode.GRUB_STACK


## True while the round is being played (not the intro countdown, not after the gong; true without a referee).
static func round_live(level: LevelBase) -> bool:
	var ref: Object = referee(level)
	if ref == null:
		return true
	var value: Variant = ref.get(&"phase")
	return not (value is int) or int(value) == 1 or int(value) == 2


## True when `slot` is out of the round (Last Caveman Standing, Hot Rock).
static func is_out(level: LevelBase, slot: int) -> bool:
	var ref: Object = referee(level)
	return ref != null and ref.has_method(&"is_out") and bool(ref.call(&"is_out", slot))


## Hearts of the hero in `slot` (Last Caveman Standing; the run's hearts, which the referee keeps).
static func hearts_of(level: LevelBase, slot: int) -> int:
	if level == null:
		return 0
	var hero: PlayerBase = level.get_hero(slot)
	return hero.run.hearts if hero != null and hero.run != null else 0


## Where the Grudge Pterodactyl of eliminated `slot` is (NO_POS = he rides none).
static func grudge_pos(level: LevelBase, slot: int) -> Vector2i:
	var ref: Object = referee(level)
	if ref != null and ref.has_method(&"grudge_pos"):
		var value: Variant = ref.call(&"grudge_pos", slot)
		if value is Vector2i:
			return value
	return NO_POS


## True when the Grudge Pterodactyl of `slot` can drop a rock now.
static func grudge_ready(level: LevelBase, slot: int) -> bool:
	var ref: Object = referee(level)
	return ref != null and ref.has_method(&"grudge_ready") and bool(ref.call(&"grudge_ready", slot))


## Boxes that are deadly now or whose visible telegraph turns deadly within `lookahead` ticks (sudden deaths, arena
## hazards); empty without the referee's danger_rects().
static func danger_rects(level: LevelBase, lookahead: int) -> Array[Rect2i]:
	var result: Array[Rect2i] = []
	var ref: Object = referee(level)
	if ref == null or not ref.has_method(&"danger_rects"):
		return result
	var value: Variant = ref.call(&"danger_rects", lookahead)
	if value is Array:
		for item: Variant in value:
			if item is Rect2i:
				result.append(item)
	return result


## The Hot Rock holder (-1 = nobody yet / not Hot Rock).
static func ember_holder(level: LevelBase) -> int:
	var ref: Object = referee(level)
	return int(ref.call(&"ember_holder")) if ref != null and ref.has_method(&"ember_holder") else -1


## Ticks in which `slot` cannot receive the ember back (0 = he can).
static func ember_pass_immune(level: LevelBase, slot: int) -> int:
	var ref: Object = referee(level)
	return int(ref.call(&"ember_pass_immune", slot)) if ref != null and ref.has_method(&"ember_pass_immune") else 0


## True while the ember bubbles fast (its last seconds; visible to everyone).
static func ember_hurry(level: LevelBase) -> bool:
	var ref: Object = referee(level)
	return ref != null and ref.has_method(&"ember_hurry") and bool(ref.call(&"ember_hurry"))


## The Clubball coconut (the referee's ball(), else the first objects/coconut of the level); null when none.
static func ball(level: LevelBase) -> SimEntity:
	if level == null:
		return null
	var ref: Object = referee(level)
	if ref != null and ref.has_method(&"ball"):
		var value: Variant = ref.call(&"ball")
		if value is SimEntity and is_instance_valid(value):
			return value
		return null
	for kind: int in [Defs.Kind.OTHER, Defs.Kind.HAZARD, Defs.Kind.HITTABLE]:
		for entity: SimEntity in level.get_kind(kind):
			var script: Script = entity.get_script() as Script
			if script != null and script.resource_path == BALL_ID_SCRIPT:
				return entity
	return null


## The goal mouth `team` defends (level px; empty without the referee's goal_rect()).
static func goal_rect(level: LevelBase, team: int) -> Rect2i:
	var ref: Object = referee(level)
	if ref != null and ref.has_method(&"goal_rect"):
		var value: Variant = ref.call(&"goal_rect", team)
		if value is Rect2i:
			return value
	return Rect2i()


## Rival projectiles in the level (thrown specials whose owner is a rival of `slot`; a deflect target).
static func rival_projectiles(level: LevelBase, slot: int) -> Array[SimEntity]:
	var result: Array[SimEntity] = []
	if level == null:
		return result
	for entity: SimEntity in level.get_kind(Defs.Kind.HERO_PROJECTILE):
		var owner: Variant = entity.get(&"owner_slot")
		if entity.is_queued_for_deletion() or bool(entity.get(&"spent")):
			continue
		if owner is int and are_rivals(level, slot, int(owner)):
			result.append(entity)
	return result


## Side (-1 left, +1 right, 0 none) of the nearest deadly floor or pit within `cells` columns of the feet point
## `pos` along its floor row - where a batted curled rival would end up badly.
static func hazard_side(level: LevelBase, pos: Vector2i, cells: int = 6) -> int:
	if level == null or level.grid == null:
		return 0
	var grid: TileGrid = level.grid
	var col: int = pos.x >> 4
	var row: int = pos.y >> 4
	for step: int in range(1, cells + 1):
		for side: int in [1, -1]:
			var c: int = col + side * step
			if not grid.in_bounds(c, row):
				continue
			var value: int = grid.floor_at(c, row)
			if value == TileGrid.FLOOR_DEADLY or grid.side_at(c, row - 1) == TileGrid.SIDE_DEADLY:
				return side
			if value == TileGrid.FLOOR_EMPTY and _pit_below(grid, c, row):
				return side
	return 0


static func _pit_below(grid: TileGrid, col: int, row: int) -> bool:
	for r: int in range(row, grid.rows):
		var value: int = grid.floor_at(col, r)
		if value == TileGrid.FLOOR_DEADLY:
			return true
		if value != TileGrid.FLOOR_EMPTY:
			return false
	return true
