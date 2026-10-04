class_name BossStalactite
extends ProjectileBase
## `projectiles/boss_stalactite` - the ceiling drop of the Wall Colossus (the original's chandelier, GAMEPLAY.md
## 6.3): appears under the ceiling with its tip at the spawn point, rattles for EnemyTuning.STALACTITE_WARN_TICKS,
## then falls with the enemy gravity and shatters on the floor. It lives EnemyTuning.STALACTITE_LIFE ticks at most.
## A touch costs the hero a heart and scatters bones (Defs.HurtKind.BOSS_PROJECTILE).
##
## Parameters (set by the boss): `life` ticks [66].

const FX_DEBRIS: StringName = &"fx/debris"

var _sprite: Sprite2D = null


func _apply_params(params: Dictionary) -> void:
	life = EnemyTuning.STALACTITE_LIFE
	super._apply_params(params)
	from_hero = false
	hurt_kind = Defs.HurtKind.BOSS_PROJECTILE
	xvel = 0
	set_box(EnemyTuning.STALACTITE_BOX)


func _ready() -> void:
	_sprite = get_node_or_null(^"Sprite") as Sprite2D


## True while it still hangs and rattles (tests and tools).
func is_warning() -> bool:
	return _age < EnemyTuning.STALACTITE_WARN_TICKS


func _move_tick() -> void:
	_age += 1
	if _sprite != null:
		var rattle: float = float(EnemyTuning.STALACTITE_SHAKE_ART_PX) if (_age & 1) == 1 else 0.0
		_sprite.position.x = rattle if is_warning() else 0.0
	if not is_warning():
		sim_pos.y += Tuning.floor16(yvel)
		yvel = mini(yvel + Tuning.ENEMY_GRAVITY, Tuning.ENEMY_TERMINAL)
		if _landed():
			_shatter()
			return
	if life > 0 and _age >= life:
		consume()
		return
	var level: LevelBase = Game.level
	if level != null and _age > 1 and not on_screen and box_top() > level.get_view_rect().end.y:
		consume()


func _on_hit_hero() -> void:
	Audio.play_sfx(Sfx.IMPACT)


func _landed() -> bool:
	var level: LevelBase = Game.level
	if level == null:
		return false
	return TileGrid.is_ground(level.grid.floor_at(Tuning.to_cell(sim_pos.x), Tuning.to_cell(sim_pos.y)))


func _shatter() -> void:
	var level: LevelBase = Game.level
	if level != null:
		sim_pos.y = Tuning.tile_top(sim_pos.y)
		if Spawner.exists(FX_DEBRIS):
			level.spawn_fx(FX_DEBRIS, sim_pos, {"kind": "rock"})
	Audio.play_sfx(Sfx.IMPACT)
	consume()
