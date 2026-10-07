class_name BossInk
extends ProjectileBase
## `projectiles/boss_ink` - Inkjaw's ink blob (DESIGN.md B.3 phase 2, GAMEPLAY.md 13.6; owner enemies-B, PLAN.md P2.2):
## spat from the jaws in an arc (the spawn velocity: xvel +/-48 towards the target, yvel -96, `yacc` +8 per tick), it
## splashes on the first floor, water or wall it meets and is gone once it left every view. A touch costs the hero a
## heart and scatters 6 bones (Defs.HurtKind.BOSS_PROJECTILE, the boss-projectile rule of GAMEPLAY.md 13.6) and dims
## the screen to the night palette for Squid.SQUID_DIM_TICKS (its squid keeps that clock, [method Squid.on_ink_hit]).
##
## Parameters (set by the squid): `xvel`, `yvel`, `yacc` v16, `life` ticks [BOSS_INK_LIFE]. Picture: the shipped
## rock (sprites/fx/projectile_rock.png) tinted black-violet (DESIGN.md B.3) - no sheet of its own.

const FX_SPLASH: StringName = &"fx/splash"
const BOSS_INK_LIFE: int = 132              ## ticks at most in flight [own]
const BOSS_INK_BOX: Vector3i = Vector3i(10, 10, 5)
const BOSS_INK_TINT: Color = Color(0.32, 0.18, 0.42, 1.0)

var _sprite: Sprite2D = null
var _squid: Squid = null


func _apply_params(params: Dictionary) -> void:
	life = BOSS_INK_LIFE
	super._apply_params(params)
	from_hero = false
	hurt_kind = Defs.HurtKind.BOSS_PROJECTILE
	set_box(BOSS_INK_BOX)


func _ready() -> void:
	_sprite = get_node_or_null(^"Sprite") as Sprite2D
	if _sprite != null:
		_sprite.modulate = BOSS_INK_TINT


## The squid that spat it (its ink hit dims the screen).
func set_squid(squid: Squid) -> void:
	_squid = squid


func _move_tick() -> void:
	sim_pos.x += Tuning.floor16(xvel)
	sim_pos.y += Tuning.floor16(yvel)
	yvel = mini(yvel + yacc, Tuning.ENEMY_TERMINAL)
	_age += 1
	if _sprite != null:
		_sprite.frame = (_age / EnemyTuning.ROCK_ANIM_TICKS) % EnemyTuning.ROCK_FRAMES
	var level: LevelBase = Game.level
	if level != null and _age > 1 and _meets_scenery(level.grid):
		_splash(level)
		return
	if (life > 0 and _age >= life) or (_age > 1 and not on_screen):
		consume()


func _on_hit_hero() -> void:
	Audio.play_sfx(Sfx.SPLASH)
	if _squid != null and is_instance_valid(_squid):
		_squid.on_ink_hit()


## True when the blob's centre entered a floor, a wall or the water.
func _meets_scenery(grid: TileGrid) -> bool:
	var col: int = Tuning.to_cell(sim_pos.x)
	var row: int = Tuning.to_cell(sim_pos.y - (box_h >> 1))
	if grid.get_char(col, row) == TileGrid.CH_LIQUID or grid.side_at(col, row) == TileGrid.SIDE_WALL:
		return true
	return yvel > 0 and TileGrid.is_ground(grid.floor_at(col, Tuning.to_cell(sim_pos.y)))


func _splash(level: LevelBase) -> void:
	if Spawner.exists(FX_SPLASH):
		level.spawn_fx(FX_SPLASH, sim_pos, {"kind": "water"})
	Audio.play_sfx(Sfx.SPLASH)
	consume()
