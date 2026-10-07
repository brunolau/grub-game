class_name EmberRainZone
extends ZoneBase
## `zones/ember_rain` (GAMEPLAY.md 12.1, 4-1 Cinder Shaft): while the hero's feet are inside the rectangle, an
## ember (or a leaf) falls toward him every `period` ticks. The emitter only spawns `projectiles/enemy_ember` with
## the `rain` flag; the projectile places itself above the hero, sways, costs a bone on contact and keeps at most
## five alive. Owner: world.
##
## Parameters: `rect`; `period` ticks [Tuning.DESIGNER_SECOND]; `skin=ember|leaf` [ember].
##
## A party: it rains while any living hero is inside, on the first of them in contact order (the spawn parameter
## `rain_slot` names his slot for the ember); a stream per hero is world's PLAN P1 rule.

const EMBER_ID: StringName = &"projectiles/enemy_ember"
const SKINS: Array[String] = ["ember", "leaf"]

## Ticks between two embers while the hero is inside.
var period: int = Tuning.DESIGNER_SECOND
## Picture of the falling things: "ember" or "leaf".
var skin: String = SKINS[0]
## Embers released so far (diagnostics, tests).
var released: int = 0

var _timer: int = 0


func _apply_params(params: Dictionary) -> void:
	super._apply_params(params)
	period = maxi(1, param_int("period", Tuning.DESIGNER_SECOND))
	skin = param_str("skin", SKINS[0])
	if not SKINS.has(skin):
		push_warning("%s: unknown skin '%s'; using '%s'" % [name, skin, SKINS[0]])
		skin = SKINS[0]


func _sim_tick(phase: int) -> void:
	super._sim_tick(phase)
	var level: LevelBase = Game.level
	var hero: PlayerBase = _rain_target(level)
	if hero == null:
		return
	_timer += 1
	if _timer < period:
		return
	_timer = 0
	if Spawner.exists(EMBER_ID):
		level.spawn(EMBER_ID, sim_pos, {"rain": true, "skin": skin, "rain_slot": hero.slot})
		released += 1


## The hero it rains on: the first living hero inside, in contact order (one hero: him while inside and alive).
func _rain_target(level: LevelBase) -> PlayerBase:
	if not inside or level == null:
		return null
	for hero: PlayerBase in level.contact_order():
		if not hero.dead and (inside_mask & (1 << hero.slot)) != 0:
			return hero
	return null


func _on_level_reset() -> void:
	super._on_level_reset()
	_timer = 0


func _on_first_entered(_level: LevelBase, _hero: PlayerBase) -> void:
	_timer = 0
