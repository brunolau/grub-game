class_name SpawnerEnemy
extends EnemyBase
## Base of the zone spawners of GAMEPLAY.md 5.1 / 5.2 (sky dropper, burrower, arc leaper): the record placed in the
## level never shows itself; while its trigger holds it keeps producing copies of itself, with a pause between
## two appearances and at most `max` alive at once. Killing the copies never stops the record.
##
## A copy is spawned through the level with the record's parameters plus `record=<this node>`, takes a slot at once
## and is one-shot: when it despawns or dies it is freed and the record may produce the next one.
## 2.0 co-op (GAMEPLAY.md 13.9.4, a co-op party only): the copies appear around the heroes inside the trigger in turn
## (slot order, round robin) and up to `max` x 1.5 (PartyTuning.SPAWNER_MAX_NUM / DEN, rounded down) are alive.

## Copies alive at once (level parameter `max`).
var max_alive: int = 1
## Ticks between two appearances (level parameter `pause`), counted while the trigger holds.
var pause: int = EnemyTuning.DROPPER_PAUSE

## The record that produced this copy (null for the record itself and for a copy that left).
var _record: SpawnerEnemy = null
## True for a copy, for its whole life.
var _is_copy: bool = false
## Copies alive (record only).
var _alive: int = 0
## Ticks before the next copy may appear (record only).
var _cooldown: int = 0
## Where the next copy appears, written by _pick_spawn() (record only).
var _spawn_at: Vector2i = Vector2i.ZERO
## 2.0 co-op: player slot of the hero the last copy appeared around (-1 = none yet; record only).
var _last_slot: int = -1


func _apply_params(params: Dictionary) -> void:
	super._apply_params(params)
	max_alive = maxi(int(params.get("max", max_alive)), 1)
	pause = maxi(int(params.get("pause", pause)), 0)
	var record: Variant = params.get("record")
	if record is SpawnerEnemy:
		_record = record
		_is_copy = true
		one_shot = true
	_cooldown = _first_cooldown()


## True for a copy produced by a record.
func is_copy() -> bool:
	return _is_copy


## Dozing (SimEntity, ARCHITECTURE.md 11): an untriggered record does nothing, and it cannot be triggered while the
## hero and the view are far from what its trigger looks at.
func _doze_area() -> Rect2i:
	return super._doze_area() if _is_copy else _trigger_area()


## What `_triggered()` looks at: the record's box against the view (the default, `is_in_view`), or a rectangle the
## hero's feet must enter. Override together with `_triggered()`.
func _trigger_area() -> Rect2i:
	return get_box()


## Copies alive (record only; diagnostics and tests).
func alive_copies() -> int:
	return _alive


## Copies that may be alive at once now: `max`, or in a co-op party `max` x 1.5 rounded down (GAMEPLAY.md 13.9.4).
func max_alive_now() -> int:
	if CoopTraits.party_on():
		return max_alive * PartyTuning.SPAWNER_MAX_NUM / PartyTuning.SPAWNER_MAX_DEN
	return max_alive


func _asleep_tick() -> void:
	if _is_copy:
		return
	var hero: PlayerBase = _trigger_hero()
	if hero == null:
		return
	if _cooldown > 0:
		_cooldown -= 1
		return
	if _alive >= max_alive_now() or not _slot_free() or not _pick_spawn(hero):
		return
	var params: Dictionary = spawn_params.duplicate()
	params.erase("name")
	params["record"] = self
	var copy: SpawnerEnemy = _spawn_optional(_copy_id(), _spawn_at, params) as SpawnerEnemy
	if copy == null:
		return
	_alive += 1
	_cooldown = pause
	_last_slot = hero.slot
	copy._on_spawned(self)
	copy.wake()


func _on_gone() -> void:
	if _is_copy:
		_detach()


func _on_level_reset() -> void:
	if _is_copy:
		_release_slot()
		dead = true
		visible = false
		_detach()
		return
	super._on_level_reset()
	_alive = 0
	_last_slot = -1
	_cooldown = _first_cooldown()


# =================================================================================================================
# Hooks
# =================================================================================================================

## Entity id of the copies (the scene of this enemy). Override.
func _copy_id() -> StringName:
	return &""


## True while the hero is where copies should be produced. Override.
func _triggered(_hero_node: PlayerBase) -> bool:
	return false


## Choose where the next copy appears and store it in `_spawn_at`; false when there is no valid place now.
func _pick_spawn(_hero_node: PlayerBase) -> bool:
	_spawn_at = spawn_pos
	return true


## Ticks before the very first copy appears.
func _first_cooldown() -> int:
	return pause


## Called on a fresh copy right after it was spawned, before it wakes. Override.
func _on_spawned(_by: SpawnerEnemy) -> void:
	pass


# =================================================================================================================
# Internals
# =================================================================================================================

## The hero for whom the trigger holds this tick (the next copy appears around him), or null: the target hero
## (1.0); a party (2.0, TECH_AUDIT.md 3.8): a hero in LevelBase.contact_order() that enemies may target
## (PlayerBase.is_party_targetable) and for whom `_triggered()` holds - any hero triggers; in a co-op party they take
## turns (GAMEPLAY.md 13.9.4: the first such hero after the one the last copy appeared around, in slot order).
func _trigger_hero() -> PlayerBase:
	var level: LevelBase = Game.level
	if level == null or level.hero_count() <= 1:
		var target: PlayerBase = _target_hero()
		return target if target != null and _triggered(target) else null
	if _traits != null and _traits.kind == Defs.CoopTrait.LONE and CoopTraits.party_on() \
			and PartyTuning.lone_trait_on(Game.difficulty):
		# 2.0 `lone` (Expert): nothing rises while the heroes keep together; else only around the straggler.
		var straggler: PlayerBase = _traits.lone_target()
		return straggler if straggler != null and _triggered(straggler) else null
	var first: PlayerBase = null
	var next: PlayerBase = null
	var turns: bool = CoopTraits.party_on()
	for hero: PlayerBase in level.contact_order():
		if not hero.is_party_targetable() or not _triggered(hero):
			continue
		if not turns:
			return hero
		if first == null:
			first = hero
		if next == null and hero.slot > _last_slot:
			next = hero
	return next if next != null else first


func _child_gone() -> void:
	_alive = maxi(_alive - 1, 0)
	_cooldown = maxi(_cooldown, pause)


## A copy leaves for good: tell its record, stop ticking and free the node.
func _detach() -> void:
	if is_instance_valid(_record):
		_record._child_gone()
	_record = null
	sim_active = false
	queue_free()
