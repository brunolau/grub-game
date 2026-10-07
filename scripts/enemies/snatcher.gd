class_name Snatcher
extends HangerEnemy
## `enemies/snatcher` - the co-op Snatcher (GAMEPLAY.md 13.9.6, DESIGN.md D.7): a Dangler or a Stinger with the `grab`
## trait. `kind=dangler` [default]: the yo-yo dangler of archetype 2 on its thread (`depth`, `speed` px per tick), the
## Snatcher bat of the caves; `kind=stinger`: the sentry diver of archetype 5 (`range` tiles, `speed` px per tick per
## axis), the gull of the coast and the sky. With two heroes a hero who touches it from below, or whom it dives onto,
## is seized instead of hurt: he cannot move or strike and it carries him towards its perch (`perch=c,r`, a pit-side
## cell) at 1 px per tick and drops him there; his partner frees him with any hit on it (CoopTraits, the `grab` rule).
## Then it flies back to where it seized him - a dangler takes up its thread there again, a stinger flies on to its
## anchor (EnemyTuning.SNATCHER_HOME_SPEED) and hovers. Only in co-op files; a party of one meets the plain dangler or
## stinger. Doze rule (ARCHITECTURE.md 11.1): the default one.
##
## Parameters: `kind=dangler|stinger` [dangler]; dangler: `depth` px [48], `speed` px per tick [2]; stinger: `range`
## tiles [6], `speed` px per tick [3]; `perch=c,r`; `skin` [dangler: bat_b; stinger: gull_b (pterodactyl_b recoloured)];
## `hp` [25], `score` [dangler 0, stinger 3]; `coop=` overrides the preset's trait.

enum Kind { DANGLER, STINGER }
enum State { HANG, HOVER, DIVE, LEVEL, HOME }

## Form of this Snatcher (level parameter `kind`).
var kind: int = Kind.DANGLER
## Dangler: how far below the anchor it goes, px (level parameter `depth`).
var depth: int = EnemyTuning.DANGLER_DEPTH
## Dangler: thread speed; stinger: dive speed per axis; px per tick (level parameter `speed`).
var speed: int = EnemyTuning.DANGLER_SPEED
## Stinger: trigger box half size in tiles (level parameter `range`).
var range_tiles: int = EnemyTuning.STINGER_RANGE_TILES

var _state: int = State.HANG
var _going_down: bool = true
## The grab trait's carries its AI has seen: a new one means it held a hero and flew back meanwhile (its AI did not
## run), so the AI takes up its form again.
var _carries_seen: int = 0


func _default_skin() -> String:
	if kind == Kind.STINGER:
		return "gull_b" if EnemySkin.find("gull_b") != null else "pterodactyl_b"
	return "bat_b"


func _apply_params(params: Dictionary) -> void:
	kind = Kind.STINGER if str(params.get("kind", "dangler")) == "stinger" else Kind.DANGLER
	score_index = EnemyTuning.SCORE_STINGER if kind == Kind.STINGER else EnemyTuning.SCORE_DANGLER
	if not params.has("coop"):
		coop_trait = Defs.CoopTrait.GRAB
	super._apply_params(params)
	if kind == Kind.STINGER:
		speed = maxi(absi(int(params.get("speed", EnemyTuning.STINGER_SPEED))), 1)
		range_tiles = maxi(int(params.get("range", range_tiles)), 0)
	else:
		depth = maxi(int(params.get("depth", depth)), 0)
		speed = maxi(absi(int(params.get("speed", speed))), 1)


## Current State (tests and tools).
func get_state() -> int:
	return _state


func _on_wake() -> void:
	xvel = 0
	yvel = 0
	_carries_seen = _traits.carries if _traits != null else 0
	if kind == Kind.STINGER:
		_state = State.HOVER
		_thread_on = false
		_play(&"fly")
	else:
		_state = State.HANG
		_thread_top = _find_thread_top()
		_thread_on = true
		_going_down = true
		_play(&"hang")


func _on_reset() -> void:
	_thread_on = false


func _ai_tick() -> void:
	if _traits != null and _traits.carries != _carries_seen:
		# The grab trait let a hero go and flew back to where it seized him.
		_carries_seen = _traits.carries
		xvel = 0
		yvel = 0
		if kind == Kind.STINGER:
			_state = State.HOME
	if kind == Kind.STINGER:
		_stinger_tick()
	else:
		_dangler_tick()


## Archetype 2: down to `depth` below the anchor and back up, on its thread.
func _dangler_tick() -> void:
	_thread_on = sim_pos.x == spawn_pos.x
	var bottom: int = spawn_pos.y + depth
	if _going_down:
		sim_pos.y = mini(sim_pos.y + speed, bottom)
		_going_down = sim_pos.y < bottom
	else:
		sim_pos.y = maxi(sim_pos.y - speed, spawn_pos.y)
		_going_down = sim_pos.y <= spawn_pos.y
	_play(&"hang")


## Archetype 5: hover, dive at the target in range, level out; after a carry, fly home and hover again.
func _stinger_tick() -> void:
	var hero: PlayerBase = _target_hero()
	match _state:
		State.HOVER:
			_play(&"fly")
			if hero == null:
				return
			facing = _dir_to(hero)
			if Tuning.to_cell(absi(hero.sim_pos.x - sim_pos.x)) > range_tiles \
					or Tuning.to_cell(absi(hero.sim_pos.y - sim_pos.y)) > range_tiles:
				return
			xvel = speed * Tuning.V16_PER_PX * facing
			yvel = speed * Tuning.V16_PER_PX * (1 if hero.sim_pos.y >= sim_pos.y else -1)
			_state = State.DIVE
			_play(&"dive")
		State.DIVE:
			if hero != null and absi(sim_pos.y - hero.sim_pos.y) <= EnemyTuning.STINGER_LEVEL_PX:
				yvel = 0
				_state = State.LEVEL
				_play(&"fly")
		State.HOME:
			sim_pos += CoopTraits._step_towards(sim_pos, spawn_pos, EnemyTuning.SNATCHER_HOME_SPEED)
			if sim_pos.x != spawn_pos.x:
				facing = signi(spawn_pos.x - sim_pos.x)
			_play(&"fly")
			if sim_pos == spawn_pos:
				_state = State.HOVER
			return
	sim_pos.x += Tuning.floor16(xvel)
	sim_pos.y += Tuning.floor16(yvel)


## No thread while the grab trait carries a hero or flies back (cosmetic).
func _refresh_visual() -> void:
	if _thread_on and _traits != null and (_traits.held != null or _traits._returning):
		_thread_on = false
	super._refresh_visual()
