class_name VersusSignatures
extends RefCounted
## The arena signatures the referee runs (docs/expansion/DESIGN.md E.5, LEVEL_DESIGN.md 15.8; phase 3, DA's
## wf8 / wf9 requests and the lead designer's G31 / G43). Owner: world-B (scripts/world/versus/**).
##
## Each is switched on by the arena file and runs only while a round is played (the referee calls [method begin_round]
## at every round start and [method world_step] in its WORLD phase):
##  - RING-OUTS: in a mode other than Clubball, every `zones/goal` mouth of the file is surf - a hero whose feet point
##    enters one is knocked out as by a hazard (cause `surf`: Grub Stack spills everything, Last Caveman Standing and
##    Hot Rock put him out). Coconut Cove's goal mouths (DESIGN.md E.5). Listed in the danger rects (always deadly).
##  - DARKNESS PULSE: meta `dark_pulse = <period>[:<night>]` (Echo Hollow `486`; night VersusTuning.ECHO_DARK_TICKS,
##    73): from round tick `period` on, the first `night` ticks of every period are night - the palette fades to dark
##    and every hero glows (LevelLights); the palette's DARKNESS_FADE_TICKS (22) fade is the telegraph. The Lights Out
##    variant keeps the night all round.
##  - REGROWING WALLS: meta `regrow = <ticks>` (Echo Hollow `364`, VersusTuning.ECHO_WALL_REGROW_TICKS): a `$` block
##    (objects/breakable_block) that broke grows back `ticks` after it broke - first REGROW_WARN_TICKS of a ghostly
##    block in the open cell (the telegraph; it blocks nothing), then solid again, but only on a tick on which no
##    hero's body overlaps the cell (else the ghost waits).
##  - NEUTRAL ENEMIES: every enemy record of an arena (Echo Hollow's dangler) is a neutral springboard - it never hurts
##    anyone (EnemyBase.contact_hurts off), never dies (its hp is topped up every tick: hits flash and glance), and a
##    hero landing on its head bounces as on any enemy. The hero's own enemy contact skips an enemy whose contact does
##    not hurt (Player: `not enemy.contact_hurts`), so that bounce is made here ([method springboard_step], the
##    referee's CONTACT_ENEMIES step) exactly as Player._bounce_on makes it.
##  - EMBER LANE: meta `ember_lane = <col>,<width>[,<period>]` (Cinder Pit): every `period` round ticks (EMBER_PERIOD
##    66 by default) an ember drifts down a random column of the lane from the top row, after EMBER_WARN_TICKS of a
##    glow at its start (the telegraph, in the danger rects); its touch is an arena hit (VersusReferee.arena_hit: the
##    spill of a hit / one heart / the knock-back in Hot Rock; the spawn shield and the hurt immunity help).
##  - THE NEUTRAL COLOSSUS (Colossus Hall, G43): a `bosses/colossus` record of the arena spits every
##    VersusTuning.COLOSSUS_SPIT_PERIOD_TICKS (243) round ticks at the crowned leader (Grub Stack: the tallest stack;
##    Last Caveman Standing: the most hearts; a tie or another mode: no spit, the clock waits for the next period):
##    its jaws open VersusTuning.COLOSSUS_JAWS_TICKS (10) ahead (the statue's `arena_spit` pose when enemies-C's
##    statue has it, and the rock's own glow at the jaws), then one rock flies straight at where the leader stands -
##    an arena hit, gone on the first wall or floor.
##  - ARENA WIND: an arena with meta `wind` (and `wind_loop`) has its gusts driven by the referee, synced to the round
##    (entries count from the round start; a loop restarts every `wind_loop` ticks): every tick the referee sets the
##    wind after the level's own script, so the two never fight (DA's Floe Rink, wf9 #2). While the Whiteout sudden
##    death runs it owns the wind; the Gusty variant replaces the arena's gusts.

## Ember lane (tune): an ember every EMBER_PERIOD round ticks, its glow EMBER_WARN_TICKS ahead.
const EMBER_PERIOD: int = 66
const EMBER_WARN_TICKS: int = 12
## Regrowing walls: the ghost block shows this long before the block is solid again (the telegraph).
const REGROW_WARN_TICKS: int = 12
## A neutral enemy's hp (topped up every tick).
const NEUTRAL_HP: int = 1 << 20
## The rock leaves the jaws this far to the side of the statue's feet point and this high over it (logical px) when the
## statue offers no `arena_mouth()` (the visor head of the right-wall statue).
const SPIT_MOUTH_OFFSET: Vector2i = Vector2i(-24, -64)
## Death cause of a ring-out.
const CAUSE_SURF: StringName = &"surf"

var _referee: VersusReferee = null
## Ring-out rects (logical px) of the arena's `zones/goal` records.
var ring_rects: Array[Rect2i] = []
## Darkness pulse: period and night length in round ticks (0 = none).
var dark_period: int = 0
var dark_ticks: int = 0
## True while the pulse holds the night.
var pulse_dark: bool = false
## Regrowing walls: ticks after a break (0 = off); block instance id -> round tick it broke; the blocks showing their
## ghost (instance id -> true).
var regrow_ticks: int = 0
var _broken_at: Dictionary = {}
var _ghosts: Dictionary = {}
## Ember lane: first column, width (cells), period (0 = none); the round tick the next ember starts to glow.
var ember_col: int = 0
var ember_width: int = 0
var ember_period: int = 0
## The neutral enemies of the arena.
var neutrals: Array = []
## The neutral Colossus (null when the arena has none).
var colossus: SimEntity = null
## Arena wind: the script (tick, value) sorted and its loop (0 = none); empty = the referee leaves the wind alone.
var wind_script: Array[Vector2i] = []
var wind_loop: int = 0


func _init(referee: VersusReferee) -> void:
	_referee = referee


## A round starts: read the arena's signatures afresh (the file and the meta), make its enemies neutral, clear the
## clocks.
func begin_round() -> void:
	var level: LevelBase = _referee.level
	ring_rects.clear()
	_broken_at.clear()
	_ghosts.clear()
	neutrals.clear()
	colossus = null
	pulse_dark = false
	if level == null:
		return
	var meta: Dictionary = level.meta
	if _referee.mode != Defs.VersusMode.CLUBBALL:
		for record: Dictionary in VersusArena.file_records(level, &"zones/goal"):
			var rect: PackedInt32Array = LevelText.to_int_list((record["params"] as Dictionary).get("rect", ""))
			if rect.size() == 4:
				ring_rects.append(Rect2i(rect[0] * Tuning.TILE, rect[1] * Tuning.TILE, rect[2] * Tuning.TILE,
						rect[3] * Tuning.TILE))
	var pulse: PackedInt32Array = parse_pulse(str(meta.get("dark_pulse", "")))
	dark_period = pulse[0]
	dark_ticks = pulse[1]
	regrow_ticks = maxi(int(str(meta.get("regrow", "0")).to_int()), 0)
	var lane: PackedInt32Array = parse_lane(str(meta.get("ember_lane", "")))
	ember_col = lane[0]
	ember_width = lane[1]
	ember_period = lane[2]
	wind_script = parse_wind(str(meta.get("wind", "")))
	wind_loop = maxi(int(str(meta.get("wind_loop", "0")).to_int()), 0)
	for entity: SimEntity in level.get_kind(Defs.Kind.ENEMY):
		var enemy: EnemyBase = entity as EnemyBase
		if enemy != null and is_instance_valid(enemy):
			_make_neutral(enemy)
	for entity: SimEntity in level.get_kind(Defs.Kind.BOSS):
		if entity != null and is_instance_valid(entity) and entity is Colossus:
			colossus = entity
			break


## `dark_pulse = <period>[:<night>]` -> [period, night] ([0, 0] = none; night defaults to ECHO_DARK_TICKS and is less
## than the period).
static func parse_pulse(text: String) -> PackedInt32Array:
	var parts: PackedStringArray = text.strip_edges().split(":")
	if parts.is_empty() or not parts[0].strip_edges().is_valid_int() or parts[0].to_int() <= 0:
		return PackedInt32Array([0, 0])
	var period: int = parts[0].to_int()
	var night: int = VersusTuning.ECHO_DARK_TICKS
	if parts.size() >= 2 and parts[1].strip_edges().is_valid_int():
		night = parts[1].to_int()
	return PackedInt32Array([period, clampi(night, 1, maxi(period - 1, 1))])


## `ember_lane = <col>,<width>[,<period>]` -> [col, width, period] (width 0 = none).
static func parse_lane(text: String) -> PackedInt32Array:
	var values: PackedInt32Array = LevelText.to_int_list(text)
	if values.size() < 2 or values[1] <= 0 or values[0] < 0:
		return PackedInt32Array([0, 0, 0])
	var period: int = values[2] if values.size() >= 3 and values[2] > 0 else EMBER_PERIOD
	return PackedInt32Array([values[0], values[1], maxi(period, EMBER_WARN_TICKS + 1)])


## `wind = t:v,t:v,...` -> sorted (tick, value) pairs (bad entries skipped).
static func parse_wind(text: String) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for part: String in LevelText.to_list(text):
		var pair: PackedStringArray = part.split(":")
		if pair.size() == 2 and pair[0].strip_edges().is_valid_int() and pair[1].strip_edges().is_valid_int():
			result.append(Vector2i(pair[0].to_int(), pair[1].to_int()))
	result.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x < b.x)
	return result


## The arena wind on round tick `tick`: the value of the last entry at or before it (within its loop round); before
## the first entry of the first round 0, before the first entry of a later round the last entry's value.
static func wind_at(script: Array[Vector2i], loop: int, tick: int) -> int:
	if script.is_empty():
		return 0
	var t: int = tick
	var value: int = 0
	if loop > 0 and tick >= loop:
		t = tick % loop
		value = script[script.size() - 1].y
	for entry: Vector2i in script:
		if entry.x > t:
			break
		value = entry.y
	return value


## True when the darkness pulse holds the night on round tick `tick` ([period, night] of [method parse_pulse]).
static func night_at(period: int, night: int, tick: int) -> bool:
	return period > 0 and tick >= period and tick % period < night


func _make_neutral(enemy: EnemyBase) -> void:
	enemy.contact_hurts = false
	enemy.max_hp = NEUTRAL_HP
	enemy.hp = NEUTRAL_HP
	neutrals.append(enemy)


## Every tick of a round (WORLD, any phase but OVER): the arena wind. The rest only while the round is played.
func wind_step() -> void:
	if wind_script.is_empty() or _referee.level == null:
		return
	var desired: int = wind_at(wind_script, wind_loop, _referee.round_ticks)
	var sudden: VersusSuddenDeath = _referee.sudden_death
	if sudden != null and sudden.is_running() and sudden.theme == VersusSuddenDeath.WHITEOUT:
		desired = sudden.wind
	elif _referee.rules.has(VersusRules.GUSTY):
		desired = _referee.gust_wind
	_referee.level.set_wind(desired)


## WORLD while the round is played: ring-outs, the darkness pulse, regrowing walls, neutral enemies, embers, the
## Colossus.
func world_step() -> void:
	var level: LevelBase = _referee.level
	if level == null:
		return
	var tick: int = _referee.round_ticks
	_ring_outs()
	if dark_period > 0:
		var night: bool = night_at(dark_period, dark_ticks, tick)
		if night != pulse_dark:
			pulse_dark = night
			level.set_darkness(night or _referee.rules.has(VersusRules.LIGHTS_OUT))
	if regrow_ticks > 0:
		_regrow(tick)
	for entry: Variant in neutrals:
		if not is_instance_valid(entry):
			continue
		var enemy: EnemyBase = entry as EnemyBase
		if enemy != null and not enemy.dead:
			enemy.hp = NEUTRAL_HP
			enemy.contact_hurts = false
	if ember_width > 0 and tick % ember_period == ember_period - EMBER_WARN_TICKS:
		_ember()
	if colossus != null and is_instance_valid(colossus) \
			and tick % VersusTuning.COLOSSUS_SPIT_PERIOD_TICKS == VersusTuning.COLOSSUS_SPIT_PERIOD_TICKS - VersusTuning.COLOSSUS_JAWS_TICKS:
		_spit()


## CONTACT_ENEMIES while the round is played, after the rivals' stomps: a hero who falls (or stands: yvel 0) onto a
## neutral enemy's head - the body test flags a stomp, as in the hero's own enemy contact - bounces off it
## (Tuning.BOUNCE_YVEL, with Up held Tuning.BOUNCE_YVEL_UP or Big Bounce's; a squashed hero has no Up) and the enemy
## counts the bounce (EnemyBase.on_bounced; it is never hurt). A hero who already bounced this tick (yvel < 0), a
## curled or a gliding one is left alone. Returns the heroes that bounced.
func springboard_step() -> Array[PlayerBase]:
	var bounced: Array[PlayerBase] = []
	if neutrals.is_empty():
		return bounced
	var up_yvel: int = VersusRules.BIG_BOUNCE_YVEL if _referee.rules.has(VersusRules.BIG_BOUNCE) \
			else Tuning.BOUNCE_YVEL_UP
	for hero: PlayerBase in _referee.heroes_in_order():
		if not _referee.is_in_play(hero) or hero.yvel < 0 or hero.is_curled() or hero.is_gliding():
			continue
		for entry: Variant in neutrals:
			if not is_instance_valid(entry):
				continue
			var enemy: EnemyBase = entry as EnemyBase
			if enemy == null or enemy.dead or not enemy.awake or not enemy.is_targetable():
				continue
			if not Overlap.body(hero, enemy, hero) or not Overlap.stomp:
				continue
			var up: bool = (GameInput.get_flags(hero.slot) & Defs.IN_UP) != 0 and hero.control_enabled \
					and hero.squash == 0
			hero.bounce(up_yvel if up else Tuning.BOUNCE_YVEL, Overlap.depth)
			enemy.on_bounced(hero)
			if AudioTable.SFX.has(Sfx.BOUNCE):
				Audio.play_sfx(Sfx.BOUNCE)
			bounced.append(hero)
			break
	return bounced


func _ring_outs() -> void:
	if ring_rects.is_empty():
		return
	for hero: PlayerBase in _referee.heroes_in_order():
		if not _referee.is_in_play(hero):
			continue
		var feet: Vector2i = hero.sim_pos - Vector2i(0, 1)
		for rect: Rect2i in ring_rects:
			if rect.has_point(feet):
				_referee.knock_out(hero, CAUSE_SURF)
				break


## Broken `$` blocks grow back: the ghost after `regrow_ticks - REGROW_WARN_TICKS`, the solid block once its cell is
## clear of every hero body.
func _regrow(tick: int) -> void:
	var level: LevelBase = _referee.level
	for entity: SimEntity in level.get_kind(Defs.Kind.HITTABLE):
		var block: BreakableBlock = entity as BreakableBlock
		if block == null or not is_instance_valid(block):
			continue
		var id: int = block.get_instance_id()
		if not block.opened:
			_broken_at.erase(id)
			continue
		if not _broken_at.has(id):
			_broken_at[id] = tick
			continue
		var age: int = tick - int(_broken_at[id])
		if age < regrow_ticks - REGROW_WARN_TICKS:
			continue
		if not _ghosts.has(id):
			_ghosts[id] = true
			_show_ghost(block, true)
		if age < regrow_ticks or _cell_taken(block.cell):
			continue
		_ghosts.erase(id)
		_broken_at.erase(id)
		_grow_back(block)


## True when a hero's body overlaps the cell (the block would close on him).
func _cell_taken(cell: Vector2i) -> bool:
	var rect: Rect2i = Rect2i(cell * Tuning.TILE, Vector2i(Tuning.TILE, Tuning.TILE))
	for hero: PlayerBase in _referee.heroes_in_order():
		if hero != null and not hero.dead and Overlap.rects(rect, hero.get_box()):
			return true
	return false


## The block is back: its cell solid (the `$` cell's invisible solid), its hits and look of the level file
## (objects-A's BreakableBlock.regrow(), wf9_world_b_to_party.txt #1; the cell is written here too, on the referee's
## level, in case Game.level is another one).
func _grow_back(block: BreakableBlock) -> void:
	var level: LevelBase = _referee.level
	level.set_cell(block.cell.x, block.cell.y, TileGrid.CH_SOLID_INVISIBLE)
	block.regrow()
	if AudioTable.SFX.has(Sfx.SPOT_OPENED):
		Audio.play_sfx(Sfx.SPOT_OPENED)


## The block's picture as a ghost (`on`) or solid again.
func _show_ghost(block: BreakableBlock, on: bool) -> void:
	var sprite: Sprite2D = block.get_node_or_null(^"Sprite") as Sprite2D
	if sprite == null:
		return
	sprite.visible = true
	sprite.frame = BreakableBlock.FRAME_IDLE
	sprite.position.x = 0.0
	sprite.modulate.a = 0.45 if on else 1.0


## One ember of the lane: a random column, its glow at the top row first.
func _ember() -> void:
	var level: LevelBase = _referee.level
	var col: int = ember_col + Sim.rng.next_int(ember_width)
	var start: Vector2i = Vector2i(col * Tuning.TILE + Tuning.TILE / 2, Tuning.TILE * 2)
	var hazard: VersusHazard = VersusHazard.new().setup(VersusHazard.EMBER, EMBER_WARN_TICKS, _referee,
			Rect2i(col * Tuning.TILE, 0, Tuning.TILE, VersusArena.view_rect().size.y))
	hazard.cause = &"ember"
	hazard.spawn_setup(start, {})
	_referee.add_round_entity(hazard)


## The Colossus spits at the leader (none: the clock waits).
func _spit() -> void:
	var target: int = spit_target()
	if target < 0:
		return
	var mouth: Vector2i = colossus.sim_pos + SPIT_MOUTH_OFFSET
	if colossus.has_method(&"arena_mouth"):
		mouth = colossus.call(&"arena_mouth")
	if colossus.has_method(&"arena_spit"):
		colossus.call(&"arena_spit", VersusTuning.COLOSSUS_JAWS_TICKS)
	var hazard: VersusHazard = VersusHazard.new().setup(VersusHazard.SPIT, VersusTuning.COLOSSUS_JAWS_TICKS, _referee,
			Rect2i(mouth - Vector2i(8, 16), Vector2i(16, 16)))
	hazard.target_slot = target
	hazard.cause = &"colossus"
	hazard.spawn_setup(mouth, {})
	_referee.add_round_entity(hazard)


## The Colossus's target (G43): Grub Stack the crowned leader; Last Caveman Standing the hero with the most hearts;
## -1 on a tie, in another mode, or when nobody qualifies.
func spit_target() -> int:
	match _referee.mode:
		Defs.VersusMode.GRUB_STACK:
			return _referee.leader_slot()
		Defs.VersusMode.LAST_CAVEMAN:
			var best: int = -1
			var best_hearts: int = 0
			var tie: bool = false
			for hero: PlayerBase in _referee.heroes_in_order():
				if not _referee.is_in_play(hero):
					continue
				var hearts: int = hero.run.hearts
				if hearts > best_hearts:
					best = hero.slot
					best_hearts = hearts
					tie = false
				elif hearts == best_hearts:
					tie = true
			return -1 if tie else best
	return -1


## The ring-outs are deadly all round (bots keep out of them).
func danger_rects() -> Array[Rect2i]:
	return ring_rects.duplicate()
