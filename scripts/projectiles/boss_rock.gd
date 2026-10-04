class_name BossRock
extends ProjectileBase
## `projectiles/boss_rock` - the rock the Wall Colossus spits (GAMEPLAY.md 6.3): flies from its mouth with the
## spawn velocity, falls with the enemy gravity, bounces along the floor at half height (losing an eighth of its
## speed per bounce), turns at walls and crumbles after EnemyTuning.ROCK_LIFE ticks. A touch costs the hero a heart
## and scatters bones (Defs.HurtKind.BOSS_PROJECTILE).
##
## Parameters (set by the boss): `xvel`, `yvel` v16, `life` ticks [132].

var _sprite: Sprite2D = null


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
	sim_pos.y += Tuning.floor16(yvel)
	yvel = mini(yvel + Tuning.ENEMY_GRAVITY, Tuning.ENEMY_TERMINAL)
	_age += 1
	if level != null:
		_collide(level.grid)
	if _sprite != null:
		_sprite.frame = (_age / EnemyTuning.ROCK_ANIM_TICKS) % EnemyTuning.ROCK_FRAMES
		_sprite.flip_h = xvel > 0
	if (life > 0 and _age >= life) or (_age > 1 and not on_screen):
		consume()


func _on_hit_hero() -> void:
	Audio.play_sfx(Sfx.IMPACT)


func _collide(grid: TileGrid) -> void:
	var dir: int = signi(xvel)
	if dir != 0:
		var probe: int = sim_pos.x + dir * box_xo
		if grid.side_at(Tuning.to_cell(probe), Tuning.to_cell(sim_pos.y - 1)) == TileGrid.SIDE_WALL:
			sim_pos.x -= Tuning.floor16(xvel)
			xvel = -xvel
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
	yvel = -rebound if rebound > EnemyTuning.LANDING_BOUNCE_MIN else 0
	xvel -= Tuning.shr(xvel, EnemyTuning.ROCK_FRICTION_SHIFT)
