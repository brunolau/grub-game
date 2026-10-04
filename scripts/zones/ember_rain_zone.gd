class_name EmberRainZone
extends ZoneBase
## `zones/ember_rain` (GAMEPLAY.md 12.1, 4-1 Cinder Shaft): while the hero's feet are inside the rectangle, an
## ember (or a leaf) falls toward him every `period` ticks. The emitter only spawns `projectiles/enemy_ember` with
## the `rain` flag; the projectile places itself above the hero, sways, costs a bone on contact and keeps at most
## five alive. Owner: world.
##
## Parameters: `rect`; `period` ticks [Tuning.DESIGNER_SECOND]; `skin=ember|leaf` [ember].

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
	if not inside or level == null or level.player == null or level.player.dead:
		return
	_timer += 1
	if _timer < period:
		return
	_timer = 0
	if Spawner.exists(EMBER_ID):
		level.spawn(EMBER_ID, sim_pos, {"rain": true, "skin": skin})
		released += 1


func _on_level_reset() -> void:
	super._on_level_reset()
	_timer = 0


func _on_hero_entered(_level: LevelBase, _hero: PlayerBase) -> void:
	_timer = 0
