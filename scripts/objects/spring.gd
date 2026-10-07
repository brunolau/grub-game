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


## Dozing (SimEntity, ARCHITECTURE.md 11): at rest it only tests the overlap with the hero, which fails while he is
## far away.
func _doze_area() -> Rect2i:
	return _doze_box()


func _can_doze() -> bool:
	return _anim < 0


func _sim_tick(_phase: int) -> void:
	if _anim >= 0:
		_anim += 1
		var frame: int = ObjTuning.anim_frame(_anim, BOUNCE_FPS)
		if frame >= BOUNCE_FRAMES.size():
			_anim = -1
			frame = BOUNCE_FRAMES.size() - 1
			_doze_note()
		if _sprite != null:
			_sprite.frame = BOUNCE_FRAMES[frame]
	var level: LevelBase = Game.level
	if level == null:
		return
	# Every hero in contact order (2.0, TECH_AUDIT.md 3.12; 1.0: the one hero) who lands on it is launched.
	for hero: PlayerBase in level.contact_order():
		_launch_test(level, hero)


## One hero: landing on it (falling, not gliding) launches him with `power`.
func _launch_test(level: LevelBase, hero: PlayerBase) -> void:
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
