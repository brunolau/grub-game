class_name SpringPad
extends SimEntity
## `objects/spring` (`power` v16 [-224]): a springy flower pad (not in the original game, GAMEPLAY.md 7.2). Landing
## on its top half throws the hero up with `power`, like the big bounce on an enemy head (PHYSICS.md 9).

## Sheet animation [M 8]: idle 0, bounce 1, 2, 3, 4, 0 at 16 fps.
const BOUNCE_FRAMES: Array[int] = [1, 2, 3, 4, 0]
const BOUNCE_FPS: int = 16

## Launch speed, v16 (negative = up).
var power: int = ObjTuning.SPRING_DEFAULT_POWER
## Times it threw the hero (statistics, tests).
var launches: int = 0

var _sprite: Sprite2D = null
var _anim: int = -1


func _init() -> void:
	z_index = Defs.Z_OBJECTS
	set_box(Vector3i(28, 10, 14))


func _sim_phases() -> PackedInt32Array:
	return PackedInt32Array([Defs.Phase.CONTACT_ITEMS])


func _apply_params(params: Dictionary) -> void:
	power = int(params.get("power", power))
	_sprite = get_node_or_null(^"Sprite") as Sprite2D


func _sim_tick(_phase: int) -> void:
	if _anim >= 0:
		_anim += 1
		var frame: int = ObjTuning.anim_frame(_anim, BOUNCE_FPS)
		if frame >= BOUNCE_FRAMES.size():
			_anim = -1
			frame = BOUNCE_FRAMES.size() - 1
		if _sprite != null:
			_sprite.frame = BOUNCE_FRAMES[frame]
	var level: LevelBase = Game.level
	if level == null or level.player == null:
		return
	var hero: PlayerBase = level.player
	if hero.dead or hero.yvel < 0 or hero.is_gliding():
		return
	if Overlap.body(self, hero, hero) and Overlap.stomp:
		hero.bounce(power, Overlap.depth)
		launches += 1
		_anim = 0
		if _sprite != null:
			_sprite.frame = BOUNCE_FRAMES[0]
		Audio.play_sfx(Sfx.BOUNCE)
		level.spawn_fx(&"fx/dust", sim_pos)
