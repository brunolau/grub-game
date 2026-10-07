class_name Squid
extends BossBase
## `bosses/squid` - Inkjaw, the Grotto Squid (w7_l2b Squid Grotto; DESIGN.md B.3, GAMEPLAY.md 13.6). Owner: enemies-B
## (PLAN.md P2.2).
##
## A squid in a one-screen grotto whose floor is deadly water with rock islands; it surfaces in a gap between two
## islands. Place the record in a water gap at the water surface row (the cell above the surface `~`): the gaps it
## surfaces in are found in that row of its room (`zones/arena`) - every run of 1-3 `~` cells between two islands.
## Hit points (club 25, charged x4): Beginner 150, Expert 225; the co-op form 187 / 280 [R8] (`hp` overrides).
##
## A surfacing: DIVE (under water, untouchable; 66 ticks, the first 44), BUBBLES 22 ticks over the gap it picked
## (Sim.rng; the telegraph of where it comes up), RISE 6 ticks, UP 44 ticks, SINK 6 ticks. While UP:
##  - Surface and Slam: a tentacle rises over its target's spot (clamped to SQUID_SLAM_REACH px from the squid) for
##    12 ticks, its shadow marking the landing (the telegraph), then slams: a boss-body box (a bone and the
##    knock-back) for 4 ticks, shake 4.
##  - Phase 2 (60 % down to 30 %) adds the Ink spit: the jaws open 10 ticks (the telegraph), then an arcing ink blob
##    (`projectiles/boss_ink`: xvel +/-48 towards the target, yvel -96, +8 per tick); a blob costs a heart and 6 bones
##    and dims the screen to the night palette for SQUID_DIM_TICKS (the surfacing bubbles stay bright).
##  - Phase 3 (below 30 %, red), the Whirlpool: once, the middle island rumbles SQUID_RUMBLE_TICKS (the telegraph) and
##    sinks; two log rafts (`objects/raft width=3`) take its place and ride a current over the pool
##    (`zones/current`) that reverses every SQUID_CURRENT_FLIP ticks; the squid then surfaces in the free water beside
##    the raft nearest its target and slams at him there. Fight from the raft; paddle with a forward strike.
## Weak point: the top of its head while UP (a high strike from an island edge, a strike after a bounce, a throw).
## The body costs a bone; landing on its head always bounces the hero and harms nobody.
##
## Co-op form (`kind = coop` files or `form=coop`), the Tentacle Lock: while UP (phases 1 and 2) it crosses two
## tentacles over its armoured head. A strike on a tentacle from ITS side (the left one by a hero - or the thrower of
## a weapon - at least SQUID_FLANK_PX left of the squid, the right one from the right) makes it flinch for the flinch
## window, min(24 Beginner / 16 Expert, SQUID_SOLO_MIN_TICKS - 4): the head opens SQUID_OPEN_TICKS when both flinch,
## struck by the two heroes (one hero's two strikes never open it). Phase 3 keeps the solo rule: one paddles, the
## other strikes. A count-in plays while a hero stands at each side.
##
## Fairness (B.0): every attack shows itself 10+ ticks ahead (bubbles 22, tentacle 12, jaws 10, rumble 22); hits never
## stop or lengthen a state (no stun-lock); BossBase.hit_cooldown is shared. Parameters: `arena`, `hp`, `drops`
## [fire_starter], `form=coop|solo`. Numbers: SQUID_* below (EnemyTuning once enemies-A adopts them). Picture: until
## art-B's sheet lands (`sprites/bosses/squid.png`, EnemySkin `squid`) the squid draws a placeholder.

enum State { DORMANT, DIVE, BUBBLES, RISE, UP, SINK, RUMBLE, DYING }

const INK_ID: StringName = &"projectiles/boss_ink"
const RAFT_ID: StringName = &"objects/raft"
const CURRENT_ID: StringName = &"zones/current"
const SKIN_NAME: String = "squid"

# --- Tuning [D B.3] [G 13.6] (tune) ---------------------------------------------------------------------------------
const SQUID_HP_BEGINNER: int = 150
const SQUID_HP_EXPERT: int = 225
const SQUID_COOP_HP_BEGINNER: int = 187      ## [R8]
const SQUID_COOP_HP_EXPERT: int = 280
const SQUID_HP_PER_PIP: int = 25
const SQUID_PHASE2_PERCENT: int = 60
const SQUID_PHASE3_PERCENT: int = 30
const SQUID_FIRST_DIVE_TICKS: int = 44       ## the fight opens with this dive [own]
const SQUID_DIVE_TICKS: int = 66             ## under water between surfacings
const SQUID_BUBBLE_TICKS: int = 22           ## bubbles mark the gap it comes up in
const SQUID_RISE_TICKS: int = 6              ## coming up / going down (untouchable) [own]
const SQUID_UP_TICKS: int = 44               ## it stays up this long
const SQUID_TENTACLE_AT: int = 2             ## UP tick on which the tentacle starts to rise [own]
const SQUID_TENTACLE_RISE_TICKS: int = 12    ## the slam's telegraph (its shadow marks the landing)
const SQUID_SLAM_TICKS: int = 4              ## the slam box lives this long
const SQUID_SLAM_SHAKE: int = 4
const SQUID_SLAM_REACH: int = 72             ## the slam lands at most this far from the squid [own]
const SQUID_SLAM_BOX: Vector2i = Vector2i(24, 56)  ## width, height over the surface it lands on [own]
const SQUID_JAWS_AT: int = 22                ## phase 2: UP tick on which the jaws open [own]
const SQUID_JAWS_TICKS: int = 10             ## the spit's telegraph
const SQUID_INK_XVEL: int = 48               ## v16 towards the target
const SQUID_INK_YVEL: int = -96
const SQUID_INK_YACC: int = 8
const SQUID_DIM_TICKS: int = 66              ## an ink hit dims the screen this long
const SQUID_RUMBLE_TICKS: int = 22           ## phase 3: the middle island rumbles before it sinks
const SQUID_RAFT_WIDTH: int = 3
const SQUID_CURRENT_SPEED: int = 1           ## px per tick
const SQUID_CURRENT_FLIP: int = 132          ## the current reverses this often
const SQUID_FLANK_PX: int = 24               ## co-op: a tentacle flinches only for a hero this far out on its side
const SQUID_FLINCH_BEGINNER: int = 24        ## co-op flinch, capped like a window (GAMEPLAY.md 13.9.3)
const SQUID_FLINCH_EXPERT: int = 16
const SQUID_OPEN_TICKS: int = 33             ## co-op: the head opens this long when both tentacles flinch
## Co-op: the least ticks one hero needs from flinching one tentacle (from its side) to flinching the other (from the
## other side) on the test level, measured by tests/test_enemies_squid.gd (which pins this as a lower bound).
const SQUID_SOLO_MIN_TICKS: int = 20
const SQUID_COUNT_IN_TICKS: int = 8
const SQUID_COUNT_IN_PX: int = 72            ## a hero within this far on a side counts as standing there
const SQUID_DYING_TICKS: int = 44
const SQUID_WAKE_RANGE: int = 240
## Body box above the water (width, height, x_offset); the head is its top 14 px; the co-op tentacles cross above it.
const SQUID_BOX: Vector3i = Vector3i(36, 44, 18)
const SQUID_HEAD: Rect2i = Rect2i(-16, -44, 32, 14)
const SQUID_TENTACLE_LEFT: Rect2i = Rect2i(-30, -58, 24, 20)
const SQUID_TENTACLE_RIGHT: Rect2i = Rect2i(6, -58, 24, 20)
const SQUID_MOUTH: Vector2i = Vector2i(0, -24)

## True for the co-op form (DESIGN.md B.3).
var coop_form: bool = false
## The water surface (the feet y of the squid) and the gaps it may surface in (centre x of each).
var surface_y: int = 0
var gaps: Array[int] = []

var _state: int = State.DORMANT
var _timer: int = 0
var _up_x: int = 0
var _next_x: int = 0
var _slam_x: int = -1
var _slam_timer: int = -1
var _jaws: int = -1
var _dim: int = 0
var _was_dark: bool = false
var _whirlpool: bool = false
var _rafts: Array[SimEntity] = []
var _current: SimEntity = null
var _current_clock: int = 0
var _island: Vector2i = Vector2i(-1, -1)
var _island_rows: Array[int] = []
var _flinch: Array[int] = [0, 0]
var _flinch_slot: Array[int] = [-1, -1]
var _open: int = 0
var _count_in: int = -1
var _part_tick: Array[int] = [-1000, -1000]
## Statistics for tests and tools: surfacings, slams, spits, ink hits, tentacle flinches (tick, side, slot).
var surfacings: int = 0
var slams: int = 0
var spits: int = 0
var ink_hits: int = 0
var flinch_log: Array[Vector3i] = []


func _default_skin() -> String:
	return SKIN_NAME if EnemySkin.find(SKIN_NAME) != null else ""


func _apply_params(params: Dictionary) -> void:
	coop_form = Tusker._coop_form_of(params)
	var expert: bool = Game.difficulty == Defs.Difficulty.EXPERT
	if coop_form:
		max_hp = SQUID_COOP_HP_EXPERT if expert else SQUID_COOP_HP_BEGINNER
	else:
		max_hp = SQUID_HP_EXPERT if expert else SQUID_HP_BEGINNER
	hp_per_pip = SQUID_HP_PER_PIP
	music = Sfx.MUSIC_BOSS_INKJAW
	boss_drops = [&"fire_starter"]
	super._apply_params(params)
	surface_y = sim_pos.y
	_up_x = sim_pos.x


func _ready() -> void:
	set_box(SQUID_BOX)
	if Game.level != null and Game.level.grid != null:
		_find_gaps()
	Spawner.preload_ids([RAFT_ID, CURRENT_ID])
	_hide()


# =================================================================================================================
# Queries (tests, tools)
# =================================================================================================================

func get_state() -> int:
	return _state


func get_state_ticks() -> int:
	return _timer


## Phase 1, 2 or 3 by the hit points left.
func get_phase() -> int:
	if hp * 100 < max_hp * SQUID_PHASE3_PERCENT:
		return 3
	if hp * 100 <= max_hp * SQUID_PHASE2_PERCENT:
		return 2
	return 1


## True while it is up (the head can be struck, the body hurts).
func is_up() -> bool:
	return _state == State.UP


## The gap (centre x) the bubbles mark, or the squid is up in.
func get_spot() -> int:
	return _next_x if _state == State.BUBBLES or _state == State.DIVE else _up_x


func get_head_rect() -> Rect2i:
	return _rel(SQUID_HEAD)


func get_tentacle_rect(side: int) -> Rect2i:
	return _rel(SQUID_TENTACLE_LEFT if side < 0 else SQUID_TENTACLE_RIGHT)


## The slam box this tick (empty unless the tentacle is down).
func get_slam_rect() -> Rect2i:
	if _slam_timer < SQUID_TENTACLE_RISE_TICKS or _slam_x < 0:
		return Rect2i()
	var bottom: int = _slam_floor(_slam_x)
	return Rect2i(_slam_x - (SQUID_SLAM_BOX.x >> 1), bottom - SQUID_SLAM_BOX.y, SQUID_SLAM_BOX.x, SQUID_SLAM_BOX.y)


## Where the rising tentacle will land (its shadow), -1 when none rises.
func get_slam_mark() -> int:
	return _slam_x if _slam_timer >= 0 and _slam_timer < SQUID_TENTACLE_RISE_TICKS else -1


## Ticks left of the jaws' telegraph (-1 = closed).
func get_jaws() -> int:
	return _jaws


func is_whirlpool() -> bool:
	return _whirlpool


func get_rafts() -> Array[SimEntity]:
	return _rafts.duplicate()


## Co-op: ticks left of each tentacle's flinch ([left, right]) and of the open head.
func get_flinch(side: int) -> int:
	return _flinch[0 if side < 0 else 1]


func get_open_ticks() -> int:
	return _open


## The co-op flinch window of this game.
func flinch_window() -> int:
	var base: int = SQUID_FLINCH_EXPERT if Game.difficulty == Defs.Difficulty.EXPERT else SQUID_FLINCH_BEGINNER
	return maxi(mini(base, SQUID_SOLO_MIN_TICKS - PartyTuning.WINDOW_SOLO_MARGIN_TICKS), 0)


## An ink blob of this squid hit a hero: the night palette for SQUID_DIM_TICKS.
func on_ink_hit() -> void:
	ink_hits += 1
	var level: LevelBase = Game.level
	if level == null:
		return
	if _dim <= 0:
		_was_dark = level.dark
	_dim = SQUID_DIM_TICKS
	level.set_darkness(true)


# =================================================================================================================
# Life cycle
# =================================================================================================================

func _on_reset() -> void:
	_state = State.DORMANT
	_timer = 0
	_up_x = spawn_pos.x
	_next_x = spawn_pos.x
	_slam_x = -1
	_slam_timer = -1
	_jaws = -1
	_end_dim()
	_undo_whirlpool()
	_flinch = [0, 0]
	_flinch_slot = [-1, -1]
	_open = 0
	_count_in = -1
	_part_tick = [-1000, -1000]
	surfacings = 0
	slams = 0
	spits = 0
	ink_hits = 0
	flinch_log.clear()
	set_box(SQUID_BOX)
	_hide()


func _on_lethal_hit() -> void:
	_state = State.DYING
	_timer = 0
	_slam_timer = -1
	_jaws = -1
	Audio.play_sfx(Sfx.BOSS_ROAR)
	queue_redraw()


func _on_defeated() -> void:
	_end_dim()
	_hide()
	_spawn_optional(FX_SPLASH, Vector2i(_up_x, surface_y), {"kind": "water"})


func _ai_tick() -> void:
	if dead:
		return
	_tick_dim()
	_tick_current()
	if _state == State.DYING:
		_timer += 1
		sim_pos.y = surface_y + _timer
		queue_redraw()
		if _timer >= SQUID_DYING_TICKS:
			defeat(boss_drops)
		return
	var target: PlayerBase = _target_hero()
	if not fighting:
		if _wakes_for_any(target):
			start_fight()
		if not fighting:
			return
	if _state == State.DORMANT:
		_begin_dive(SQUID_FIRST_DIVE_TICKS)
	_timer += 1
	_tick_lock()
	var power: int = _poll_hits()
	if power > 0:
		apply_boss_hit(power)
		if dead or _state == State.DYING:
			return
	match _state:
		State.DIVE:
			if _timer >= _dive_len():
				if get_phase() == 3 and not _whirlpool:
					_begin_rumble()
				else:
					_begin_bubbles(target)
		State.RUMBLE:
			if _timer % 4 == 1:
				Game.level.request_shake(EnemyTuning.BOSS_BOB_SHAKE)
			if _timer >= SQUID_RUMBLE_TICKS:
				_sink_island()
				_begin_bubbles(target)
		State.BUBBLES:
			if _timer >= SQUID_BUBBLE_TICKS:
				_up_x = _next_x
				teleport(Vector2i(_up_x, surface_y))
				_state = State.RISE
				_timer = 0
				visible = true
				Audio.play_sfx(Sfx.SPLASH_HEAVY)
				_spawn_optional(FX_SPLASH, Vector2i(_up_x, surface_y), {"kind": "water"})
		State.RISE:
			if _timer >= SQUID_RISE_TICKS:
				_state = State.UP
				_timer = 0
				surfacings += 1
				_flinch = [0, 0]
				_open = 0
		State.UP:
			_up_tick(target)
		State.SINK:
			if _timer >= SQUID_RISE_TICKS:
				_begin_dive(SQUID_DIVE_TICKS)
	_contact_every()
	queue_redraw()


func _dive_len() -> int:
	return SQUID_FIRST_DIVE_TICKS if surfacings == 0 else SQUID_DIVE_TICKS


func _begin_dive(length: int) -> void:
	_state = State.DIVE
	_timer = 0
	_slam_timer = -1
	_slam_x = -1
	_jaws = -1
	_open = 0
	_flinch = [0, 0]
	if length == SQUID_FIRST_DIVE_TICKS and surfacings == 0:
		_timer = 0
	_hide()


func _begin_bubbles(target: PlayerBase) -> void:
	_state = State.BUBBLES
	_timer = 0
	_next_x = _pick_spot(target)
	Audio.play_sfx(Sfx.GEYSER_BUBBLE)


func _begin_rumble() -> void:
	_state = State.RUMBLE
	_timer = 0
	Audio.play_sfx(Sfx.QUAKE)


func _up_tick(target: PlayerBase) -> void:
	# The slam: rises over the target's spot, then comes down.
	if _timer == SQUID_TENTACLE_AT:
		_slam_x = _slam_spot(target)
		_slam_timer = 0
	if _slam_timer >= 0:
		_slam_timer += 1
		if _slam_timer == SQUID_TENTACLE_RISE_TICKS:
			slams += 1
			Game.level.request_shake(SQUID_SLAM_SHAKE)
			Audio.play_sfx(Sfx.IMPACT)
		if _slam_timer >= SQUID_TENTACLE_RISE_TICKS:
			_slam_heroes()
		if _slam_timer >= SQUID_TENTACLE_RISE_TICKS + SQUID_SLAM_TICKS - 1:
			_slam_timer = -1
			_slam_x = -1
	# The ink (phase 2).
	if get_phase() == 2 and _timer == SQUID_JAWS_AT:
		_jaws = SQUID_JAWS_TICKS
		Audio.play_sfx(Sfx.ENEMY_VOICE)
	if _jaws > 0:
		_jaws -= 1
		if _jaws == 0:
			_spit(target)
			_jaws = -1
	if _timer >= SQUID_UP_TICKS:
		_state = State.SINK
		_timer = 0
		_slam_timer = -1
		_slam_x = -1
		_jaws = -1


func _spit(target: PlayerBase) -> void:
	spits += 1
	var dir: int = -1
	if target != null:
		dir = 1 if target.sim_pos.x >= sim_pos.x else -1
	facing = dir
	var ink: Node = _spawn_optional(INK_ID, sim_pos + SQUID_MOUTH, {"xvel": SQUID_INK_XVEL * dir,
		"yvel": SQUID_INK_YVEL, "yacc": SQUID_INK_YACC})
	if ink != null and ink.has_method(&"set_squid"):
		ink.call(&"set_squid", self)
	Audio.play_sfx(Sfx.BOSS_SPIT)


# =================================================================================================================
# Where it comes up and where it slams
# =================================================================================================================

## The gaps of the water surface row in its room: runs of 1-3 `~` cells with an island on both sides.
func _find_gaps() -> void:
	gaps.clear()
	var grid: TileGrid = Game.level.grid
	var row: int = Tuning.to_cell(surface_y)
	var room: Rect2i = _room()
	var first: int = maxi(Tuning.to_cell(room.position.x), 1)
	var last: int = mini(Tuning.to_cell(room.end.x - 1), grid.cols - 2)
	var col: int = first
	while col <= last:
		if grid.get_char(col, row) != TileGrid.CH_LIQUID:
			col += 1
			continue
		var start: int = col
		while col <= last and grid.get_char(col, row) == TileGrid.CH_LIQUID:
			col += 1
		var length: int = col - start
		var land_left: bool = start - 1 >= 0 and grid.get_char(start - 1, row) != TileGrid.CH_LIQUID \
				and grid.side_at(start - 1, row) == TileGrid.SIDE_WALL
		var land_right: bool = grid.get_char(col, row) != TileGrid.CH_LIQUID \
				and grid.side_at(col, row) == TileGrid.SIDE_WALL
		var wall_left: bool = start - 1 < first
		var wall_right: bool = col > last
		if length <= 3 and land_left and land_right and not wall_left and not wall_right:
			gaps.append((start * Tuning.TILE + col * Tuning.TILE) >> 1)
	if gaps.is_empty():
		gaps.append(spawn_pos.x)
	# The middle island: the land between the first two gaps.
	if gaps.size() >= 2:
		var left_gap_end: int = Tuning.to_cell(gaps[0]) + 1
		var c: int = left_gap_end
		while c < grid.cols and grid.get_char(c, row) == TileGrid.CH_LIQUID:
			c += 1
		var island_start: int = c
		while c < grid.cols and grid.get_char(c, row) != TileGrid.CH_LIQUID:
			c += 1
		_island = Vector2i(island_start, c - 1)


## Where the next surfacing comes up: a gap (Sim.rng) before the whirlpool, then the free water beside the raft
## nearest the target.
func _pick_spot(target: PlayerBase) -> int:
	if _whirlpool:
		return _whirlpool_spot(target)
	if gaps.size() == 1:
		return gaps[0]
	return gaps[Sim.rng.range_int(0, gaps.size() - 1)]


func _slam_spot(target: PlayerBase) -> int:
	if target == null:
		return _up_x + SQUID_SLAM_REACH * facing
	return clampi(target.sim_pos.x, _up_x - SQUID_SLAM_REACH, _up_x + SQUID_SLAM_REACH)


## Top of whatever the slam lands on at x: an island's floor, a raft, or the water surface.
func _slam_floor(x: int) -> int:
	for raft: SimEntity in _rafts:
		if is_instance_valid(raft) and absi(raft.sim_pos.x - x) <= raft.box_xo:
			return raft.sim_pos.y - raft.box_h
	var grid: TileGrid = Game.level.grid
	var row: int = Tuning.to_cell(surface_y) - 3
	while row < grid.rows:
		if TileGrid.is_ground(grid.floor_at(Tuning.to_cell(x), row)):
			return row * Tuning.TILE
		row += 1
	return surface_y


func _slam_heroes() -> void:
	var box: Rect2i = get_slam_rect()
	if box.size.x == 0:
		return
	for hero: PlayerBase in Game.level.contact_order():
		if hero.dead or hero.is_down() or hero.is_immune() or hero.is_feasting():
			continue
		if Overlap.rects(hero.get_box(), box):
			touch_hero(hero)


# =================================================================================================================
# The whirlpool (phase 3)
# =================================================================================================================

func _sink_island() -> void:
	_whirlpool = true
	var level: LevelBase = Game.level
	var row: int = Tuning.to_cell(surface_y)
	if _island.x < 0:
		return
	_island_rows.clear()
	var grid: TileGrid = level.grid
	var bottom: int = row
	while bottom + 1 < grid.rows and grid.get_char(_island.x, bottom + 1) != TileGrid.CH_LIQUID \
			and grid.get_char(gaps[0] / Tuning.TILE, bottom + 1) == TileGrid.CH_LIQUID:
		bottom += 1
	for r: int in range(row, bottom + 1):
		_island_rows.append(r)
		for c: int in range(_island.x, _island.y + 1):
			level.set_cell(c, r, TileGrid.CH_LIQUID)
	Audio.play_sfx(Sfx.SPLASH_HEAVY)
	# The pool: from the left gap's first water cell to the right gap's last one.
	var pool_first: int = _island.x
	while pool_first > 0 and grid.get_char(pool_first - 1, row) == TileGrid.CH_LIQUID:
		pool_first -= 1
	var pool_last: int = _island.y
	while pool_last + 1 < grid.cols and grid.get_char(pool_last + 1, row) == TileGrid.CH_LIQUID:
		pool_last += 1
	_current = _spawn_optional(CURRENT_ID, Vector2i(pool_first * Tuning.TILE, (row + 1) * Tuning.TILE),
			{"rect": "%d,%d,%d,1" % [pool_first, row, pool_last - pool_first + 1], "dir": "r",
			"speed": SQUID_CURRENT_SPEED}) as SimEntity
	_current_clock = 0
	# Two rafts where the island was (a hero standing on it ends up on one).
	var island_mid: int = ((_island.x + _island.y + 1) * Tuning.TILE) >> 1
	var half: int = (SQUID_RAFT_WIDTH * Tuning.TILE) >> 1
	for x: int in [island_mid - half, island_mid + half]:
		var raft: SimEntity = _spawn_optional(RAFT_ID, Vector2i(x, (row + 1) * Tuning.TILE),
				{"width": SQUID_RAFT_WIDTH, "skin": "log"}) as SimEntity
		if raft != null:
			_rafts.append(raft)


func _tick_current() -> void:
	if _current == null or not is_instance_valid(_current):
		return
	_current_clock += 1
	if _current_clock % SQUID_CURRENT_FLIP != 0:
		return
	var dir: String = "l" if str(_current.spawn_params.get("dir", "r")) == "r" else "r"
	_current.spawn_params["dir"] = dir
	_current.set(&"dir", StringName(dir))


## Free water beside the raft nearest the target: the pool column (of the surface row) nearest that raft's edge on
## which no raft floats.
func _whirlpool_spot(target: PlayerBase) -> int:
	var grid: TileGrid = Game.level.grid
	var row: int = Tuning.to_cell(surface_y)
	var aim: int = target.sim_pos.x if target != null else _up_x
	var best: int = _up_x
	var best_distance: int = 1 << 30
	var room: Rect2i = _room()
	for col: int in range(Tuning.to_cell(room.position.x), Tuning.to_cell(room.end.x - 1) + 1):
		if grid.get_char(col, row) != TileGrid.CH_LIQUID:
			continue
		var x: int = col * Tuning.TILE + (Tuning.TILE >> 1)
		var free: bool = grid.get_char(col - 1, row) == TileGrid.CH_LIQUID \
				or grid.get_char(col + 1, row) == TileGrid.CH_LIQUID
		for raft: SimEntity in _rafts:
			if is_instance_valid(raft) and absi(raft.sim_pos.x - x) < raft.box_xo + 8:
				free = false
		if not free:
			continue
		var distance: int = absi(x - aim)
		if distance < best_distance:
			best = x
			best_distance = distance
	return best


## Back to the level file's grotto (death before the end, a team wipe): the island returns, rafts and current go.
func _undo_whirlpool() -> void:
	var level: LevelBase = Game.level
	if _whirlpool and level != null and _island.x >= 0:
		var data: LevelData = (level as Level).get_data() if level is Level else null
		var original: TileGrid = data.build_grid(Game.difficulty) if data != null else null
		for r: int in _island_rows:
			for c: int in range(_island.x, _island.y + 1):
				level.set_cell(c, r, original.get_char(c, r) if original != null else TileGrid.CH_SOLID_A)
	_whirlpool = false
	_island_rows.clear()
	for raft: SimEntity in _rafts:
		if is_instance_valid(raft):
			raft.sim_active = false
			raft.queue_free()
	_rafts.clear()
	if _current != null and is_instance_valid(_current):
		_current.sim_active = false
		_current.queue_free()
	_current = null


# =================================================================================================================
# Hits
# =================================================================================================================

## Weapons against the head (solo; co-op while open or in phase 3) and the tentacles (co-op lock): thrown weapons newest
## first, then every hero's club box. Glances clank. One call per tick: it runs the hit cooldown.
func _poll_hits() -> int:
	if hit_cooldown > 0:
		hit_cooldown -= 1
	if _glance_ticks > 0:
		_glance_ticks -= 1
	var level: LevelBase = Game.level
	if level == null or dead or not fighting or _state != State.UP:
		return 0
	var lock: bool = _locked()
	var head: Rect2i = get_head_rect()
	var head_open: bool = not lock or _open > 0
	var projectiles: Array[SimEntity] = level.get_kind(Defs.Kind.HERO_PROJECTILE)
	for i: int in range(projectiles.size() - 1, -1, -1):
		var shot: ProjectileBase = projectiles[i] as ProjectileBase
		if shot == null or shot.spent:
			continue
		var box: Rect2i = shot.get_box()
		if lock:
			var side: int = _tentacle_hit(box)
			if side != 0:
				shot.consume()
				_strike_tentacle(side, level.get_hero(shot.owner_slot), shot.owner_slot, box.get_center())
				continue
		if Overlap.rects(box, head):
			shot.consume()
			if not head_open:
				_clank(level, box.get_center())
				continue
			if hit_cooldown > 0:
				return 0
			_note_hitter(level, shot.owner_slot)
			return shot.power
	for hero: PlayerBase in level.contact_order():
		if not hero.club_box_active:
			continue
		if lock:
			var side: int = _tentacle_hit(hero.club_box)
			if side != 0:
				_strike_tentacle(side, hero, hero.slot, hero.club_box.get_center())
				continue
		if Overlap.rects(hero.club_box, head):
			if not head_open:
				_glance(level, hero, head)
				continue
			if hit_cooldown > 0:
				return 0
			hero.notify_weapon_hit()
			_note_hitter(level, hero.slot)
			return hero.club_power
	return 0


## Co-op Tentacle Lock: in phases 1 and 2 of the co-op form.
func _locked() -> bool:
	return coop_form and get_phase() != 3


func _tentacle_hit(box: Rect2i) -> int:
	if Overlap.rects(box, get_tentacle_rect(-1)):
		return -1
	if Overlap.rects(box, get_tentacle_rect(1)):
		return 1
	return 0


## A strike on the tentacle of `side` by `hero` (slot `slot`): it flinches when he stands (or threw) on its side.
func _strike_tentacle(side: int, hero: PlayerBase, slot: int, at: Vector2i) -> void:
	var index: int = 0 if side < 0 else 1
	var dx: int = (hero.sim_pos.x - sim_pos.x) if hero != null and is_instance_valid(hero) else 0
	if signi(dx) != side or absi(dx) < SQUID_FLANK_PX:
		_clank(Game.level, at)
		return
	var now: int = Sim.total_ticks
	if _part_tick[index] > now - 8:
		return
	_part_tick[index] = now
	flinch_log.append(Vector3i(now, side, slot))
	_flinch[index] = flinch_window()
	_flinch_slot[index] = slot
	Audio.play_sfx(Sfx.DRUM)
	Game.level.spawn_fx(&"fx/hit_stars", at)
	if _flinch[0] > 0 and _flinch[1] > 0 and _flinch_slot[0] != _flinch_slot[1] and _open == 0:
		_open = SQUID_OPEN_TICKS
		Audio.play_sfx(Sfx.BOSS_ROAR)


## The lock's clocks: flinches and the open head run down; the count-in while a hero stands at each side.
func _tick_lock() -> void:
	for i: int in 2:
		if _flinch[i] > 0:
			_flinch[i] -= 1
	if _open > 0:
		_open -= 1
	if not _locked() or _state != State.UP or _open > 0:
		_count_in = -1
		return
	var sides: int = 0
	for hero: PlayerBase in Game.level.contact_order():
		if hero.dead or hero.is_down():
			continue
		var dx: int = hero.sim_pos.x - sim_pos.x
		if absi(dx) >= SQUID_FLANK_PX and absi(dx) <= SQUID_COUNT_IN_PX:
			sides |= 1 if dx < 0 else 2
	if sides != 3:
		_count_in = -1
		return
	_count_in += 1
	if _count_in <= PartyTuning.COUNT_IN_BEEPS * SQUID_COUNT_IN_TICKS and _count_in % SQUID_COUNT_IN_TICKS == 0:
		var go: bool = _count_in == PartyTuning.COUNT_IN_BEEPS * SQUID_COUNT_IN_TICKS
		Audio.play_sfx(Sfx.COUNTDOWN_GO if go else Sfx.COUNT_IN)


func _clank(level: LevelBase, at: Vector2i) -> void:
	if _glance_ticks > 0:
		return
	_glance_ticks = GLANCE_TICKS
	Audio.play_sfx(Sfx.CLUB_HIT_SCENERY)
	level.spawn_fx(&"fx/hit_stars", at)


# =================================================================================================================
# Contact
# =================================================================================================================

## The body while up: a landing on the head bounces the hero; otherwise a bone.
func _contact_every() -> void:
	if _state != State.UP:
		return
	for hero: PlayerBase in Game.level.contact_order():
		if hero.dead or hero.is_down():
			continue
		if not Overlap.body(hero, self, hero):
			continue
		if Overlap.stomp and hero.yvel >= 0 and not hero.is_gliding():
			var held: bool = (hero.input_flags & Defs.IN_UP) != 0
			hero.bounce(Tuning.BOSS_BOUNCE_YVEL_UP if held else Tuning.BOSS_BOUNCE_YVEL, Overlap.depth)
			Events.player_bounced.emit(self, 0)
			Events.hero_bounced.emit(hero, self, 0)
			continue
		if not hero.is_immune() and not hero.is_feasting():
			touch_hero(hero)


# =================================================================================================================
# Helpers
# =================================================================================================================

func _tick_dim() -> void:
	if _dim <= 0:
		return
	_dim -= 1
	if _dim == 0:
		_end_dim()


func _end_dim() -> void:
	if _dim > 0 or (Game.level != null and Game.level.dark and not _was_dark):
		_dim = 0
		if Game.level != null:
			Game.level.set_darkness(_was_dark)
	_dim = 0


func _hide() -> void:
	visible = false
	queue_redraw()


func _rel(rel: Rect2i) -> Rect2i:
	return Rect2i(sim_pos + rel.position, rel.size)


## The fight room in logical px: the arena zone's rectangle, else the camera lock, else one screen around it.
func _room() -> Rect2i:
	var level: LevelBase = Game.level
	if level != null and arena != &"":
		var zone: SimEntity = level.find_named(arena)
		if zone != null and zone.spawn_params.has("rect"):
			var rect: Rect2i = LevelText.to_rect_px(zone.spawn_params["rect"])
			if rect.size.x > 0:
				return rect
	if level != null and level.is_camera_locked():
		return level.get_camera_lock()
	return Rect2i(sim_pos.x - (Tuning.VIEW_W >> 1), sim_pos.y - Tuning.VIEW_H + Tuning.TILE, Tuning.VIEW_W,
			Tuning.VIEW_H)


func _burst_origin() -> Vector2i:
	return Vector2i(_up_x, surface_y - SQUID_BOX.y)


## Wake rule: a hero within SQUID_WAKE_RANGE px across and a screen up or down.
func _wakes_for(hero: PlayerBase) -> bool:
	return absi(hero.sim_pos.x - sim_pos.x) < SQUID_WAKE_RANGE and absi(hero.sim_pos.y - sim_pos.y) < Tuning.VIEW_H


# =================================================================================================================
# Placeholder picture (until art-B's sheet lands) - cosmetic
# =================================================================================================================

const INK_GREEN: Color = Color("3f7a4a")
const INK_RED: Color = Color("a3402f")
const INK_DARK: Color = Color("272018")
const BUBBLE: Color = Color(1.6, 1.8, 2.0, 0.9)


func _process(_delta: float) -> void:
	if fighting and not dead:
		queue_redraw()


func _draw() -> void:
	if not fighting or dead:
		return
	var origin: Vector2 = position
	var scale: float = Tuning.ART_SCALE
	if _state == State.BUBBLES:
		for k: int in 5:
			var p: Vector2 = Vector2(_next_x - 12 + k * 6, surface_y - 2 - ((_timer * 2 + k * 5) % 14)) * scale - origin
			draw_circle(p, 3.0, BUBBLE)
	if _slam_x >= 0 and _slam_timer >= 0 and _slam_timer < SQUID_TENTACLE_RISE_TICKS:
		var shadow: Vector2 = Vector2(_slam_x - 12, _slam_floor(_slam_x) - 3) * scale - origin
		draw_rect(Rect2(shadow, Vector2(24.0 * scale, 3.0 * scale)), Color(0.0, 0.0, 0.0, 0.45))
	var slam: Rect2i = get_slam_rect()
	if slam.size.x > 0:
		draw_rect(Rect2(Vector2(slam.position) * scale - origin, Vector2(slam.size) * scale), INK_GREEN)
	if not visible:
		return
	var body: Color = INK_RED if get_phase() == 3 else INK_GREEN
	var rise: float = 1.0
	if _state == State.RISE:
		rise = float(_timer) / float(SQUID_RISE_TICKS)
	elif _state == State.SINK:
		rise = 1.0 - float(_timer) / float(SQUID_RISE_TICKS)
	var height: float = float(SQUID_BOX.y) * rise * scale
	var width: float = float(SQUID_BOX.x) * scale
	draw_rect(Rect2(Vector2(-width * 0.5, -height), Vector2(width, height)), body)
	draw_rect(Rect2(Vector2(-width * 0.5, -height), Vector2(width, 6.0)), INK_DARK)
	if rise >= 1.0:
		draw_circle(Vector2(-10.0, -height + 24.0), 5.0, Color.WHITE)
		draw_circle(Vector2(10.0, -height + 24.0), 5.0, Color.WHITE)
		if _jaws > 0:
			draw_rect(Rect2(Vector2(-12.0, -48.0), Vector2(24.0, 12.0)), INK_DARK)
		if _locked() and _state == State.UP:
			for side: int in [-1, 1]:
				var t: Rect2i = get_tentacle_rect(side)
				var col: Color = body.lightened(0.4) if _flinch[0 if side < 0 else 1] > 0 else body.darkened(0.2)
				draw_rect(Rect2(Vector2(t.position) * scale - origin, Vector2(t.size) * scale), col)
