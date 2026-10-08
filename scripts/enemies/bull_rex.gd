class_name BullRex
extends EnemyBase
## `enemies/bull_rex` - the co-op Bull Rex (GAMEPLAY.md 13.9.6, DESIGN.md D.7): a Charger with the `heavy` trait in the
## heavy-charger skin, built for the Brace corridor (LEVEL_DESIGN.md 15.7.3: a 4-row hall between walls). It wakes by
## the view like any enemy (not the edge rusher's one-shot run in from a screen away) and runs at its target at
## `speed` along the ground with gravity; a wall turns it round, and so does its target falling
## EnemyTuning.BULL_TURN_PX behind it. With two heroes (G57) every hit glances - front, back, from above, thrown - and
## nothing else harms it either, until a Brace Wall stops it: two active heroes crouching side by side stop it dead
## and daze it 44 ticks with its head open (CoopTraits, PHYSICS.md C.10), and only then does a hit count, from any side
## - one per strike (EnemyBase, every co-op enemy), so its `hp` counts strikes (hp 25: two club strikes, or one
## charged by the crouch). A lone croucher is trampled. Only in co-op files; a party of one meets a plain charger that
## can be hit anywhere.
## Doze rule (ARCHITECTURE.md 11.1): the default one.
##
## Parameters: `speed` v16 [64], `skin` [rex_b], `hp` [25], `score` [4]; `coop=` overrides the preset's trait.

## Running speed, v16 (level parameter `speed`).
var speed: int = EnemyTuning.CHARGER_SPEED


func _default_skin() -> String:
	return "rex_b"


func _apply_params(params: Dictionary) -> void:
	score_index = EnemyTuning.SCORE_CHARGER
	if not params.has("coop"):
		coop_trait = Defs.CoopTrait.HEAVY
	super._apply_params(params)
	speed = absi(int(params.get("speed", speed)))


func _on_wake() -> void:
	var hero: PlayerBase = _target_hero()
	facing = _dir_to(hero) if hero != null else facing
	xvel = speed * facing
	yvel = 0
	_play(&"walk")


func _ai_tick() -> void:
	var hero: PlayerBase = _target_hero()
	if hero != null and _grounded:
		var behind: int = (sim_pos.x - hero.sim_pos.x) * facing
		if xvel == 0 or behind > EnemyTuning.BULL_TURN_PX:
			facing = _dir_to(hero)
			xvel = speed * facing
	_ground_step(false, true)
	if xvel != 0:
		facing = signi(xvel)
	_play(&"walk" if _grounded or yvel == 0 else &"air")
