class_name Snapper
extends EnemyBase
## `enemies/snapper` - stationary biter (the original's "red snake" hazard role; ASSET_MANIFEST.md 2): rooted at its
## anchor, it turns to face the hero; when he comes within `range` px in front of it (and roughly at its height) it
## winds up and lunges, biting everything in a strip `range` px long in front of it, then recovers and rests.
## Its body hurts on contact like any enemy; the lunge hurts the hero directly (enemy damage, stolen heart).
##
## Parameters: `range` px [42], `skin` [plant], `hp` [25], `score` [1].
## 2.0 (DESIGN.md A.5): the rattler in a hole of world 5 is this enemy with `skin=snake` (or `snake_b`); its shorter
## bite makes EnemyTuning.RATTLER_RANGE its default `range`.

enum State { IDLE, WINDUP, BITE, RECOVER, HURT, REST }

## Reach of the bite in front of the feet point, px (level parameter `range`).
var reach: int = EnemyTuning.SNAPPER_RANGE

var _state: int = State.IDLE
var _timer: int = 0


func _default_skin() -> String:
	return "plant"


func _apply_params(params: Dictionary) -> void:
	score_index = EnemyTuning.SCORE_SNAPPER
	super._apply_params(params)
	if EnemyTuning.RATTLER_SKINS.has(skin):
		reach = EnemyTuning.RATTLER_RANGE
	reach = maxi(int(params.get("range", reach)), 0)


func _on_wake() -> void:
	_state = State.IDLE
	_timer = 0
	_play(&"idle")


## The strip the lunge reaches this tick in logical px (empty when it is not biting).
func get_bite_rect() -> Rect2i:
	if _state != State.BITE or _anim_step() < 1:
		return Rect2i()
	var left: int = sim_pos.x if facing > 0 else sim_pos.x - reach
	return Rect2i(left, sim_pos.y - EnemyTuning.SNAPPER_BITE_HEIGHT, reach, EnemyTuning.SNAPPER_BITE_HEIGHT)


func _ai_tick() -> void:
	var hero: PlayerBase = _target_hero()
	match _state:
		State.IDLE:
			if hero == null:
				return
			facing = _dir_to(hero)
			var ahead: int = (hero.sim_pos.x - sim_pos.x) * facing
			if ahead <= reach + EnemyTuning.SNAPPER_SENSE_EXTRA \
					and absi(hero.sim_pos.y - sim_pos.y) <= EnemyTuning.SNAPPER_SENSE_DY:
				_state = State.WINDUP
				_play(&"windup", true)
		State.WINDUP:
			if _anim_done():
				_state = State.BITE
				_play(&"bite", true)
				Audio.play_sfx(Sfx.ENEMY_VOICE)
		State.BITE:
			_bite()
			if _anim_done():
				_state = State.RECOVER
				_play(&"recover", true)
		State.RECOVER, State.HURT:
			if _anim_done():
				_state = State.REST
				_timer = EnemyTuning.SNAPPER_REST_TICKS
				_play(&"idle")
		State.REST:
			_timer -= 1
			if _timer <= 0:
				_state = State.IDLE


func _on_hurt(_power: int) -> void:
	_state = State.HURT
	_play(&"hurt", true)


## The lunge bites every hero in its strip (2.0, TECH_AUDIT.md 3.8: every living hero in LevelBase.contact_order();
## 1.0 tested the one hero, the target, unless he was dead). It senses only the target.
func _bite() -> void:
	var level: LevelBase = Game.level
	if level == null:
		return
	for hero: PlayerBase in level.contact_order():
		if hero.dead or hero.is_feasting() or hero.is_immune():
			continue
		var bite: Rect2i = get_bite_rect()
		if bite.size.x > 0 and Overlap.rects(bite, hero.get_box()) and hero.hurt(self, Defs.HurtKind.ENEMY):
			on_hurt_hero(hero)
