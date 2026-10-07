class_name EnemyEmber
extends ProjectileBase
## `projectiles/enemy_ember` - a falling ember (volcano shaft) or leaf (GAMEPLAY.md 6.2, 12.1): falls 1..4 px per
## tick while swaying from side to side and fizzles on the first floor it reaches. A touch costs the hero one bone
## (Defs.HurtKind.BOSS_BODY). At most EnemyTuning.EMBER_MAX_ALIVE fall at once; a further one vanishes at once.
##
## Parameters: `skin=ember|leaf|feather` [ember] (2.0: `feather` = the Storm Roc's falling feathers, the leaf's motion
## drawn with art-B's roc_parts `feather` frames); `yvel` v16 [random 1..4 px per tick]; `life` ticks [198];
## `rain` flag: ignore the spawn position and appear 150 px above the hero with a random x offset of up to 124 px
## (the way an emitter or a boss drops them); `rain_slot` [0]: in a party, the player slot of that hero (2.0).
## It is gone once it fell below every view (LevelBase.get_views_bounds).

const SKIN_EMBER: String = "ember"
const SKIN_LEAF: String = "leaf"
const SKIN_FEATHER: String = "feather"
## Loaded with the script: an ember spawns inside a tick, where a first load would stall it.
const LEAF_TEXTURE: Texture2D = preload("res://assets/sprites/fx/falling_leaf.png")
## roc_parts.png (EnemySkin "roc_parts": 8 cells of 160 x 88 art px, pivot (80, 72); frames 0-1 = `feather`).
const FEATHER_TEXTURE: Texture2D = preload("res://assets/sprites/bosses/roc_parts.png")
const FEATHER_CELLS: int = 8
const FEATHER_PIVOT: Vector2 = Vector2(80, 72)

## Picture: "ember", "leaf" or "feather" (level parameter `skin`).
var skin: String = SKIN_EMBER

var _sprite: Sprite2D = null
var _sway: int = 0
var _sway_dir: int = 1


func _apply_params(params: Dictionary) -> void:
	life = EnemyTuning.EMBER_LIFE
	super._apply_params(params)
	from_hero = false
	hurt_kind = Defs.HurtKind.BOSS_BODY
	xvel = 0
	var asked: String = str(params.get("skin", skin))
	skin = asked if asked == SKIN_LEAF or asked == SKIN_FEATHER else SKIN_EMBER
	if not params.has("yvel"):
		yvel = Sim.rng.range_int(EnemyTuning.EMBER_SPEED_MIN, EnemyTuning.EMBER_SPEED_MAX) * Tuning.V16_PER_PX
	_sway_dir = 1 if Sim.rng.chance(1, 2) else -1
	set_box(EnemyTuning.EMBER_BOX)
	if param_bool("rain"):
		var level: LevelBase = Game.level
		var target: PlayerBase = _rain_target(level, int(params.get("rain_slot", 0)))
		if target != null:
			var hero: Vector2i = target.sim_pos
			var dx: int = Sim.rng.range_int(-EnemyTuning.EMBER_DROP_SPREAD, EnemyTuning.EMBER_DROP_SPREAD)
			teleport(Vector2i(hero.x + dx, hero.y - EnemyTuning.EMBER_DROP_ABOVE_HERO))


## The hero a `rain` ember falls on: P1 (1.0: the hero); a party (2.0, TECH_AUDIT.md 3.10): the hero of player slot
## `rain_slot` (spawn parameter, the slot of the hero inside the rain zone), P1 when that slot has no hero.
static func _rain_target(level: LevelBase, rain_slot: int) -> PlayerBase:
	if level == null:
		return null
	if level.hero_count() > 1:
		var hero: PlayerBase = level.get_hero(rain_slot)
		if hero != null:
			return hero
	return level.player


func _ready() -> void:
	_sprite = get_node_or_null(^"Sprite") as Sprite2D
	if _sprite != null and skin == SKIN_LEAF:
		_sprite.texture = LEAF_TEXTURE
	elif _sprite != null and skin == SKIN_FEATHER:
		_sprite.texture = FEATHER_TEXTURE
		_sprite.hframes = FEATHER_CELLS
		_sprite.offset = -FEATHER_PIVOT
	if _count_falling() > EnemyTuning.EMBER_MAX_ALIVE:
		consume()


func _move_tick() -> void:
	_age += 1
	if (_age % EnemyTuning.EMBER_SWAY_STEP_TICKS) == 0:
		_sway += _sway_dir
		sim_pos.x += _sway_dir
		if absi(_sway) >= EnemyTuning.EMBER_SWAY_PX:
			_sway_dir = -_sway_dir
	sim_pos.y += Tuning.floor16(yvel)
	if _sprite != null:
		var ticks: int = EnemyTuning.EMBER_ANIM_TICKS if skin == SKIN_EMBER else EnemyTuning.LEAF_ANIM_TICKS
		_sprite.frame = (_age / ticks) & 1
		_sprite.flip_h = _sway_dir < 0
	var level: LevelBase = Game.level
	if level == null:
		return
	var on_floor: bool = TileGrid.is_ground(
		level.grid.floor_at(Tuning.to_cell(sim_pos.x), Tuning.to_cell(sim_pos.y))
	)
	if on_floor or (life > 0 and _age >= life) \
			or (_age > 1 and not on_screen and box_top() > level.get_views_bounds().end.y):
		consume()


func _count_falling() -> int:
	var level: LevelBase = Game.level
	if level == null:
		return 0
	var count: int = 0
	for entity: SimEntity in level.get_kind(Defs.Kind.ENEMY_PROJECTILE):
		var ember: EnemyEmber = entity as EnemyEmber
		if ember != null and not ember.spent:
			count += 1
	return count
