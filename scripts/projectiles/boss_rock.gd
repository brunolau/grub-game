class_name BossRock
extends ProjectileBase
## `projectiles/boss_rock` - the rock the Wall Colossus spits (GAMEPLAY.md 6.3): flies from its mouth with the
## spawn velocity, falls with the enemy gravity, bounces along the floor at half height (losing an eighth of its
## speed per bounce), turns at walls and crumbles after EnemyTuning.ROCK_LIFE ticks. A touch costs the hero a heart
## and scatters bones (Defs.HurtKind.BOSS_PROJECTILE).
##
## wf4 fairness: walls are tested in the row the rock flies in before it drops onto the floor (a landing used to
## test the floor row and turn every rock back toward the statue), and a rock that has stopped bouncing rolls on for
## EnemyTuning.ROCK_REST_TICKS and crumbles, so no rock lies in wait on the floor or on a ledge.
##
## Parameters (set by the boss): `xvel`, `yvel` v16, `life` ticks [132].

const FX_DEBRIS: StringName = &"fx/debris"

var _sprite: Sprite2D = null
## Ticks since its bounce died out (0 = still flying or bouncing).
var _resting: int = 0


func _apply_params(params: Dictionary) -> void:
	life = EnemyTuning.ROCK_LIFE
	super._apply_params(params)
	from_hero = false
	hurt_kind = Defs.HurtKind.BOSS_PROJECTILE
	set_box(EnemyTuning.ROCK_BOX)


func _ready() -> void:
	_sprite = get_node_or_null(^"Sprite") as Sprite2D


func _move_tick() -> void:
	var level: LevelBase = Game.level
	sim_pos.x += Tuning.floor16(xvel)
	if level != null:
		_turn_at_wall(level.grid)
	sim_pos.y += Tuning.floor16(yvel)
	yvel = mini(yvel + Tuning.ENEMY_GRAVITY, Tuning.ENEMY_TERMINAL)
	_age += 1
	if level != null:
		_collide(level.grid)
	if _sprite != null:
		_sprite.frame = (_age / EnemyTuning.ROCK_ANIM_TICKS) % EnemyTuning.ROCK_FRAMES
		_sprite.flip_h = xvel > 0
	if _resting > 0:
		_resting += 1
		if _resting > EnemyTuning.ROCK_REST_TICKS:
			_crumble()
			return
	if (life > 0 and _age >= life) or (_age > 1 and not on_screen):
		consume()


## True while it rolls out after its last bounce (tests and tools).
func is_resting() -> bool:
	return _resting > 0


func _on_hit_hero() -> void:
	Audio.play_sfx(Sfx.IMPACT)


## Turn round at a wall in the row the rock flies in (tested before it moves down this tick).
func _turn_at_wall(grid: TileGrid) -> void:
	var dir: int = signi(xvel)
	if dir == 0:
		return
	var probe: int = sim_pos.x + dir * box_xo
	if grid.side_at(Tuning.to_cell(probe), Tuning.to_cell(sim_pos.y - 1)) == TileGrid.SIDE_WALL:
		sim_pos.x -= Tuning.floor16(xvel)
		xvel = -xvel


func _collide(grid: TileGrid) -> void:
	if yvel <= 0:
		return
	var col: int = Tuning.to_cell(sim_pos.x)
	var row: int = Tuning.to_cell(sim_pos.y)
	if not TileGrid.is_ground(grid.floor_at(col, row)):
		return
	var surface: int = row * Tuning.TILE + grid.surface_offset(col, row, sim_pos.x)
	if sim_pos.y < surface:
		return
	sim_pos.y = surface
	var rebound: int = Tuning.shr(yvel, 1)
	# A small rebound would hop on for ever (floor16 rounds the rise up and the fall down): it settles instead.
	yvel = -rebound if rebound > EnemyTuning.ROCK_SETTLE_REBOUND else 0
	xvel -= Tuning.shr(xvel, EnemyTuning.ROCK_FRICTION_SHIFT)
	if yvel == 0 and _resting == 0:
		_resting = 1


## It stopped rolling: crumbles into debris.
func _crumble() -> void:
	var level: LevelBase = Game.level
	if level != null and Spawner.exists(FX_DEBRIS):
		level.spawn_fx(FX_DEBRIS, sim_pos, {"kind": "rock"})
	consume()
