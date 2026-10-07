class_name HeroProjectile
extends ProjectileBase
## A thrown weapon of the hero: the axe and the boomerang (PHYSICS.md 8.4, ARCHITECTURE.md 6.2).
##
## Spawned by [Player] with the parameters `from_hero`, `power`, `xvel`, `yvel`, `yacc`, `facing` and `owner` (the
## thrower's player slot, ProjectileBase.owner_slot; 2.0). It flies
## without tile collision (ProjectileBase), is hit-tested by the hero's weapon pass and by bosses, and is removed
## on a hit or when it was not drawn in the previous frame. Both scenes share this script; they differ in the
## picture and in the box, set in the scene.


## Sprite box (width, height, x_offset) in logical px; the feet point is the bottom-centre of the picture.
@export var hit_box: Vector3i = Vector3i(16, 16, 8)
## The weapon thrown (Defs.Weapon: AXE or BOOMERANG), set in the scene. 2.0: the versus hurt table reads it (the
## swirling axe pops the victim up, PHYSICS.md C.14); nothing in Book I does.
@export var weapon: int = Defs.Weapon.AXE
## Frames of the spin animation in the sheet, and its speed (ASSET_MANIFEST 9, cosmetic).
@export var spin_frames: int = 4
@export var spin_fps: int = 16

var _spin_ticks: int = 0
var _sprite: Sprite2D = null


func _apply_params(params: Dictionary) -> void:
	super._apply_params(params)
	from_hero = true
	set_box(hit_box)


func _ready() -> void:
	_sprite = get_node_or_null(^"Sprite") as Sprite2D
	if _sprite != null:
		_sprite.flip_h = facing < 0
		_sprite.frame = 0


func _sim_tick(phase: int) -> void:
	super._sim_tick(phase)
	if phase == Defs.Phase.PROJECTILES and not spent:
		_spin_ticks += 1
		if _sprite != null and spin_frames > 0:
			_sprite.frame = (_spin_ticks * spin_fps / Tuning.ANIM_TICKS_PER_SECOND) % spin_frames
