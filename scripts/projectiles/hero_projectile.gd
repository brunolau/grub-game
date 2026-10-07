class_name HeroProjectile
extends ProjectileBase
## A thrown weapon of the hero: the axe and the boomerang (PHYSICS.md 8.4, ARCHITECTURE.md 6.2).
##
## Spawned by [Player] with the parameters `from_hero`, `power`, `xvel`, `yvel`, `yacc`, `facing` and `owner` (the
## thrower's player slot, ProjectileBase.owner_slot; 2.0). It flies
## without tile collision (ProjectileBase), is hit-tested by the hero's weapon pass and by bosses, and is removed
## on a hit or when it was not drawn in the previous frame. Both scenes share this script; they differ in the
## picture and in the box, set in the scene.
## 2.0 versus (PHYSICS.md C.14 "Thrown specials", DESIGN.md E.2 [G17]): in an arena it collides with tiles like the
## spear - see [method _move_tick]. Campaign and co-op keep the 1.0 flight (no tile collision).

## The temporary versus pick-up (`items/weapon temp=true`) a thrown special becomes when it hits a tile in an arena.
const ID_TEMP_PICKUP: StringName = &"items/weapon"


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


## One tick of flight (PROJECTILES). Outside versus: ProjectileBase's (PHYSICS.md 8.4). Versus: the same integration,
## then - before it may expire - a feet point that entered a wall (SIDE 1) or a floor cell stops it, and it lies there
## as a temporary pick-up of its weapon at HeroSpear.lie_spot (on that cell's top when the cell above is open, else in
## the open cell in front of the wall's face, from where it drops to the floor; never inside a wall) - the spear's rule
## and placement (player-B, scripts/projectiles/hero_spear.gd). The pick-up's throw count is the belt's (C.14
## "Temporary specials").
func _move_tick() -> void:
	if Game.mode != Defs.GameMode.VERSUS:
		super._move_tick()
		return
	sim_pos.x += xvel >> 4  # Tuning.floor16
	sim_pos.y += yvel >> 4
	yvel += yacc
	_age += 1
	var level: LevelBase = Game.level
	if level != null and stops_in(level.grid, sim_pos):
		if Spawner.exists(ID_TEMP_PICKUP):
			level.spawn(ID_TEMP_PICKUP, HeroSpear.lie_spot(level.grid, sim_pos, xvel),
					{"kind": WeaponPickup.KINDS[weapon], "temp": true, "dropped": true})
		consume()
		return
	if (life > 0 and _age >= life) or (_age > 1 and not on_screen):
		consume()


## True when a versus thrown special whose feet point is `point` stops there (C.14): the cell is a wall (SIDE 1) or
## holds any floor - the cells HeroSpear stops in.
static func stops_in(grid: TileGrid, point: Vector2i) -> bool:
	var col: int = point.x >> 4
	var row: int = point.y >> 4
	var floor_value: int = grid.floor_at(col, row)
	return grid.side_at(col, row) == TileGrid.SIDE_WALL \
			or (floor_value != TileGrid.FLOOR_EMPTY and floor_value != TileGrid.FLOOR_NOTHING)


func _sim_tick(phase: int) -> void:
	super._sim_tick(phase)
	if phase == Defs.Phase.PROJECTILES and not spent:
		_spin_ticks += 1
		if _sprite != null and spin_frames > 0:
			_sprite.frame = (_spin_ticks * spin_fps / Tuning.ANIM_TICKS_PER_SECOND) % spin_frames
