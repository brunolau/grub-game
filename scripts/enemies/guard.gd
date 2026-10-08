class_name Guard
extends Walker
## `enemies/guard` - 2.0 archetype 14, shield guard (GAMEPLAY.md 13.5, DESIGN.md A.5): patrols between its limits at
## EnemyTuning.GUARD_SPEED on the ground while its shield faces its target; the facing is re-decided only on its own
## clock of `turn` ticks (it may walk backwards meanwhile). A weapon hit from the side it faces - the striker's x on
## that side (or within EnemyTuning.FRONT_DX of its feet point), or a thrown weapon flying into its face - glances
## with a clank and a spark (the raised-shield pose); hits from behind count. Its contact hurts; its head is a safe
## bounce. Solo answer: bounce over it and strike before it turns. Co-op: with the `shell` trait (the Shellback) the
## shield turns to the nearer hero every tick. Halls around a Guard are 4 rows high (its art is 54 logical px tall).
## Doze rule (ARCHITECTURE.md 11.1): the default one.
##
## Parameters: `turn` ticks [33], `left` [-3] / `right` [3] tiles, `speed` v16 [24] (tune), `skin` [guard],
## `hp` [25], `score` [4].

## Ticks between two decisions of the shield's facing (level parameter `turn`).
var turn: int = EnemyTuning.GUARD_TURN_TICKS

## Side the shield faces (+1 right, -1 left) and the clock that turns it; ticks left of the raised-shield pose and of
## the swing it shows after its contact hurt a hero (cosmetic).
var _shield: int = 1
var _turn_clock: int = 0
var _pose: int = 0
var _swing: int = 0


func _default_skin() -> String:
	return "guard"


func _apply_params(params: Dictionary) -> void:
	super._apply_params(params)
	# Walker sets its own default score first: this archetype's default, unless the level gives `score`.
	score_index = clampi(int(params.get("score", EnemyTuning.SCORE_GUARD)), 0, Tuning.SCORE_LADDER.size() - 1)
	speed = absi(int(params.get("speed", EnemyTuning.GUARD_SPEED)))
	turn = maxi(int(params.get("turn", turn)), 1)


## Side the shield faces (+1 right, -1 left).
func get_shield_dir() -> int:
	return _shield


func _on_wake() -> void:
	super._on_wake()
	_turn_clock = 0
	_pose = 0
	_swing = 0
	if not _bears_shield():
		return
	var hero: PlayerBase = _target_hero()
	_shield = _dir_to(hero) if hero != null else facing
	facing = _shield


func _on_reset() -> void:
	_turn_clock = 0
	_pose = 0
	_swing = 0


## Its body hurt a hero: it holds the stolen heart (EnemyBase) and swings its club at him (the sheet's attack frames).
func on_hurt_hero(hero: PlayerBase) -> void:
	super.on_hurt_hero(hero)
	if not _bears_shield():
		return
	_swing = EnemyTuning.GUARD_SWING_TICKS
	_pose = 0
	_play(&"attack", true)


## Hits from the front glance (and whatever a co-op trait refuses).
func accepts_hit_from(source: SimEntity) -> bool:
	return super.accepts_hit_from(source) and not (_bears_shield() and _hit_from_front(source))


func _on_hit_refused(source: SimEntity) -> void:
	super._on_hit_refused(source)
	if not _bears_shield():
		return
	_pose = EnemyTuning.GUARD_SHIELD_POSE_TICKS
	_play(&"guard", true)


func _ai_tick() -> void:
	if not _bears_shield():
		super._ai_tick()
		return
	_turn_clock += 1
	if _shell_on():
		# The Shellback: the shield faces the nearer hero who counts every tick (CoopTraits post_ai does the same;
		# G33: never a dozing partner).
		var nearest: PlayerBase = Game.level.nearest_coop_hero(self)
		if nearest != null:
			_shield = _dir_to(nearest)
		_turn_clock = 0
	elif _turn_clock >= turn:
		_turn_clock = 0
		var hero: PlayerBase = _target_hero()
		if hero != null:
			_shield = _dir_to(hero)
	super._ai_tick()
	facing = _shield
	if _swing > 0:
		_swing -= 1
	elif _pose > 0:
		_pose -= 1


## The swing and the raised shield replace the walk while they last (the patrol plays this role every tick, so the
## pose runs through its frames instead of restarting).
func _move_role() -> StringName:
	if _swing > 0:
		return &"attack"
	if _pose > 0:
		return &"guard"
	return super._move_role()


## True for a shield guard (the default); false for a preset that patrols as a plain Walker (the Book I Shellback on
## a turtle sheet: its only shield is the `shell` trait). Override.
func _bears_shield() -> bool:
	return true


func _shell_on() -> bool:
	return _traits != null and _traits.kind == Defs.CoopTrait.SHELL and CoopTraits.party_on()
