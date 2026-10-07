class_name EmberRainZone
extends ZoneBase
## `zones/ember_rain` (GAMEPLAY.md 12.1, 4-1 Cinder Shaft): while the hero's feet are inside the rectangle, an
## ember (or a leaf) falls toward him every `period` ticks. The emitter only spawns `projectiles/enemy_ember` with
## the `rain` flag; the projectile places itself above the hero, sways, costs a bone on contact and keeps at most
## five alive. Owner: world.
##
## Parameters: `rect`; `period` ticks [Tuning.DESIGNER_SECOND]; `skin=ember|leaf` [ember].
##
## A party (TECH_AUDIT.md 3.13): every living hero inside gets his own stream - one timer per player slot, started
## when his feet enter, an ember every `period` ticks on him (the spawn parameter `rain_slot` names his slot). One
## hero: exactly the 1.0 stream.

const EMBER_ID: StringName = &"projectiles/enemy_ember"
const SKINS: Array[String] = ["ember", "leaf"]

## Ticks between two embers while the hero is inside.
var period: int = Tuning.DESIGNER_SECOND
## Picture of the falling things: "ember" or "leaf".
var skin: String = SKINS[0]
## Embers released so far (diagnostics, tests).
var released: int = 0

## Ticks since the last ember of each player slot's stream.
var _timers: PackedInt32Array = PackedInt32Array([0, 0, 0, 0])


func _apply_params(params: Dictionary) -> void:
	super._apply_params(params)
	period = maxi(1, param_int("period", Tuning.DESIGNER_SECOND))
	var skins: Array[String] = _skins()
	skin = param_str("skin", skins[0])
	if not skins.has(skin):
		push_warning("%s: unknown skin '%s'; using '%s'" % [name, skin, skins[0]])
		skin = skins[0]


## The skins this rain knows, the default first (`zones/food_rain` has its own).
func _skins() -> Array[String]:
	return SKINS


func _sim_tick(phase: int) -> void:
	super._sim_tick(phase)
	var level: LevelBase = Game.level
	if not inside or level == null:
		return
	for hero: PlayerBase in level.contact_order():
		var slot: int = clampi(hero.slot, 0, _timers.size() - 1)
		if hero.dead or (inside_mask & (1 << hero.slot)) == 0:
			continue
		_timers[slot] += 1
		if _timers[slot] < period:
			continue
		_timers[slot] = 0
		if _release(level, hero):
			released += 1


## One thing falls on `hero` (his stream's period is over). Returns true when something was spawned. The ember rain
## spawns `projectiles/enemy_ember` with the `rain` flag (it places itself above him); `zones/food_rain` overrides it.
func _release(level: LevelBase, hero: PlayerBase) -> bool:
	if not Spawner.exists(EMBER_ID):
		return false
	level.spawn(EMBER_ID, sim_pos, {"rain": true, "skin": skin, "rain_slot": hero.slot})
	return true


func _on_level_reset() -> void:
	super._on_level_reset()
	_timers.fill(0)


func _on_hero_entered(_level: LevelBase, hero: PlayerBase) -> void:
	_timers[clampi(hero.slot, 0, _timers.size() - 1)] = 0
