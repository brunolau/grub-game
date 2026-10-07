class_name Shaman
extends Walker
## `enemies/shaman` - the co-op Shaman (GAMEPLAY.md 13.9.6, DESIGN.md D.7), a new patroller: he walks his platform
## between his limits at `speed` [48] (tune), turning at walls and at the edge of his platform, and flees from the
## nearer hero - he turns away when a hero comes within EnemyTuning.SHAMAN_FLEE_PX at about his height (fleeing, he may
## pass his patrol limits; the patrol brings him back). Cornered (a wall or the platform's edge right ahead while he
## flees) he hops over that hero (45 px high, 4 px per tick, landing about 72 px beyond; harmless to touch until he
## lands) and runs on - or, with no floor to land on there, cowers in place. So one hero rarely corners him: he has to
## be pinned from both sides. While he is awake and alive in a
## co-op party, every other enemy within PartyTuning.SHAMAN_SHIELD_TILES (64 px on both axes) wears his bone shield:
## all its hits glance (EnemyBase.wear_bone_shield; a bone floats over it) until he dies. He himself has no shield and
## no trait. Only in co-op files; a party of one meets a patroller without shields. Cornered without a landing he
## raises his staff (the sheet's `cast`). Doze rule (ARCHITECTURE.md 11.1): the default one.
##
## Parameters: `left` [-3] / `right` [3] tiles, `speed` v16 [48], `skin` [shaman], `hp` [25], `score` [5].

## True while he flees from a hero (his heading is away from that hero).
var _fleeing: bool = false
## True during a hop over a hero (no decision while airborne).
var _hopping: bool = false


func _default_skin() -> String:
	return "shaman"


func _apply_params(params: Dictionary) -> void:
	super._apply_params(params)
	score_index = clampi(int(params.get("score", EnemyTuning.SCORE_SHAMAN)), 0, Tuning.SCORE_LADDER.size() - 1)
	speed = absi(int(params.get("speed", EnemyTuning.SHAMAN_SPEED)))


## True while he flees from a hero (tests and tools).
func is_fleeing() -> bool:
	return _fleeing


func _on_wake() -> void:
	super._on_wake()
	_fleeing = false
	_end_hop()


func _on_reset() -> void:
	_fleeing = false
	_end_hop()


func _ai_tick() -> void:
	if _hopping:
		_ground_step(false, false)
		if _grounded:
			_end_hop()
			_step = xvel
		_play(&"air")
		_shield_neighbours()
		return
	var threat: PlayerBase = _threat()
	_fleeing = threat != null
	if _fleeing:
		var away: int = -_dir_to(threat)
		if _cornered(away):
			if _can_land_beyond(threat):
				_hop_over(threat)
			else:
				# Nowhere to land: he cowers where he stands (and can be hit).
				_step = 0
				xvel = 0
				facing = -away
				_ground_step(false, true)
				_play(&"cast")
			_shield_neighbours()
			return
		if _heading != away or signi(_step) != away:
			# He turns away at once (no patrol turn-around).
			_heading = away
			_step = speed * away
	elif _grounded and _edge_ahead_of_platform(_heading):
		# The end of his platform: he stops and walks back.
		_heading = -_heading
		_step = 0
	super._ai_tick()
	_shield_neighbours()


## The nearer hatched hero when he is within the flee distance at about his height, else null.
func _threat() -> PlayerBase:
	var level: LevelBase = Game.level
	var hero: PlayerBase = level.target_hero(self) if level != null else null
	if hero == null or (level.hero_count() > 1 and not hero.is_party_targetable()):
		return null
	if absi(hero.sim_pos.x - sim_pos.x) > EnemyTuning.SHAMAN_FLEE_PX \
			or absi(hero.sim_pos.y - sim_pos.y) > EnemyTuning.SHAMAN_FLEE_DY:
		return null
	return hero


## True when he cannot flee farther in direction `dir`: against a wall or at his platform's edge (his patrol limits
## only shape his walk: fleeing, he may pass them, and the patrol brings him back).
func _cornered(dir: int) -> bool:
	if not _grounded or speed == 0:
		return false
	var level: LevelBase = Game.level
	if level == null:
		return false
	# One step further than the walk's own wall test (which would turn him round before he ever stood at the wall).
	var probe_x: int = sim_pos.x + dir * ((box_w >> 1) + Tuning.floor16(speed))
	if probe_x < Tuning.X_MIN or probe_x >= level.grid.x_max_excl():
		return true
	if level.grid.side_at(Tuning.to_cell(probe_x), Tuning.to_cell(sim_pos.y) - 1) == TileGrid.SIDE_WALL:
		return true
	return _edge_ahead_of_platform(dir)


## True when a hop over `hero` lands on floor at his own height (EnemyTuning.SHAMAN_HOP_*: about 72 px beyond).
func _can_land_beyond(hero: PlayerBase) -> bool:
	var level: LevelBase = Game.level
	if level == null:
		return false
	var air_ticks: int = 2 * (-EnemyTuning.SHAMAN_HOP_YVEL / Tuning.ENEMY_GRAVITY)
	var x: int = sim_pos.x + _dir_to(hero) * Tuning.floor16(EnemyTuning.SHAMAN_HOP_XVEL) * air_ticks
	if x < Tuning.X_MIN or x >= level.grid.x_max_excl():
		return false
	var col: int = Tuning.to_cell(x)
	var row: int = Tuning.to_cell(sim_pos.y)
	return TileGrid.is_ground(level.grid.floor_at(col, row)) or TileGrid.is_ground(level.grid.floor_at(col, row - 1))


## True when the floor ends half a body width ahead in direction `dir` (he never walks off his platform).
func _edge_ahead_of_platform(dir: int) -> bool:
	var level: LevelBase = Game.level
	if level == null or dir == 0:
		return false
	var probe_x: int = sim_pos.x + dir * ((box_w >> 1) + 1)
	var col: int = Tuning.to_cell(probe_x)
	var row: int = Tuning.to_cell(sim_pos.y)
	return not TileGrid.is_ground(level.grid.floor_at(col, row)) \
			and not TileGrid.is_ground(level.grid.floor_at(col, row - 1))


## The hop slips past the hero: harmless to touch until he lands (he can still be hit or bounced on).
func _hop_over(hero: PlayerBase) -> void:
	var dir: int = _dir_to(hero)
	_hopping = true
	contact_hurts = false
	_heading = dir
	facing = dir
	xvel = EnemyTuning.SHAMAN_HOP_XVEL * dir
	yvel = EnemyTuning.SHAMAN_HOP_YVEL
	_grounded = false
	Audio.play_sfx(Sfx.ENEMY_VOICE)
	_ground_step(false, false)
	_play(&"air", true)


func _end_hop() -> void:
	_hopping = false
	contact_hurts = true


## True during a hop over a hero (tests and tools).
func is_hopping() -> bool:
	return _hopping


## The bone shield: every other awake, living enemy within PartyTuning.SHAMAN_SHIELD_TILES of him (both axes), in a
## co-op party only. Bosses and other Shamans are never shielded.
func _shield_neighbours() -> void:
	if dead or not awake or not CoopTraits.party_on():
		return
	var reach: int = PartyTuning.SHAMAN_SHIELD_TILES * Tuning.TILE
	for entity: SimEntity in Game.level.get_kind(Defs.Kind.ENEMY):
		var enemy: EnemyBase = entity as EnemyBase
		if enemy == null or enemy == self or enemy.dead or not enemy.awake or enemy is Shaman or enemy is BossBase:
			continue
		if absi(enemy.sim_pos.x - sim_pos.x) <= reach and absi(enemy.sim_pos.y - sim_pos.y) <= reach:
			enemy.wear_bone_shield()
