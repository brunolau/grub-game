class_name VersusHazard
extends SimEntity
## A short-lived thing the versus referee drops into an arena (docs/expansion/DESIGN.md E.4 / E.6, GAMEPLAY.md
## 13.10.4 / 13.10.9): a themed sudden-death hazard (a stampeding charger, a cave-in block, a stalactite, a rolling
## rock, a lightning bolt) or a Grudge Pterodactyl's rock. Owner: world-B (PLAN.md P2.4). (The pterodactyl crates are
## objects-B's objects/crate_lane.)
##
## Every hazard first TELEGRAPHS for [member warn_ticks] (a shadow, dust, a rattle or a mark is drawn; it touches
## nobody), then it is ARMED: it moves in PROJECTILES and touches heroes in CONTACT_ITEMS (box test, Overlap.weapon
## with this hazard's box). What a touch does is the referee's ([method VersusReferee.hazard_contact]): a kill (the
## sudden deaths; the spawn shield does not help, PHYSICS.md C.14) or a 12-tick daze (a Grudge rock; shield and
## immunity do help). [member armed_tick] / [member warn_tick] tell tests when it turned deadly; [method danger_rect]
## is what the bots may avoid (only what a player sees).

## Kinds (the look and the motion).
const CHARGER: StringName = &"charger"       ## Stampede: runs along the floor at CHARGER_XVEL (kill)
const BLOCK: StringName = &"block"           ## Cave-in: falls, then becomes a solid cell (kill; crush on settling)
const STALACTITE: StringName = &"stalactite" ## Stalactite storm: hangs (rattle), falls, shatters (kill)
const BOULDER: StringName = &"boulder"       ## Rockslide: falls from a rim and rolls (kill)
const BOLT: StringName = &"bolt"             ## Lightning: a column from the view top to the first ground (kill)
const ROCK: StringName = &"rock"             ## a Grudge Pterodactyl's rock: falls, shatters (daze)
## Effects of a touch (the referee applies them).
const EFFECT_NONE: int = 0
const EFFECT_KILL: int = 1
const EFFECT_DAZE: int = 2

const GRAVITY: int = 16
const FALL_MAX: int = 192
const CHARGER_XVEL: int = 96          ## a stampeding charger runs 6 px/tick (tune)
const BOULDER_XVEL: int = 48          ## a rockslide rock rolls 3 px/tick (tune)
const BOLT_TICKS: int = 4             ## a lightning bolt burns this long (PHYSICS.md C.16: bolt 4 ticks)
const SHATTER_TICKS: int = 0          ## a stalactite / rock is gone on the tick it lands

## What it is (the constants above).
var kind: StringName = ROCK
## EFFECT_* of a touch while armed.
var effect: int = EFFECT_KILL
## Ticks of telegraph before it is armed.
var warn_ticks: int = 0
## Death cause of a kill (PlayerBase.kill).
var cause: StringName = &"sudden_death"
## The slot whose Grudge Pterodactyl dropped it (-1 = the arena's).
var owner_slot: int = -1
## The referee to report touches to (set by whoever spawns the hazard).
var referee: Object = null
## Sim.tick on which the telegraph started / the hazard was armed (-1 = not yet).
var warn_tick: int = -1
var armed_tick: int = -1
## Ticks it has been armed (a bolt burns BOLT_TICKS, a charger leaves the view).
var armed_for: int = 0
## Where the telegraph is drawn (logical px; a shadow on the floor, dust at a rim, a mark at a cell).
var mark: Rect2i = Rect2i()
## Heroes this hazard touched already (instance id -> true): one touch each.
var _touched: Dictionary = {}
var _gone: bool = false


func _init() -> void:
	set_box(Vector3i(16, 16, 8))


func _sim_phases() -> PackedInt32Array:
	return PackedInt32Array([Defs.Phase.PROJECTILES, Defs.Phase.CONTACT_ITEMS])


## Configure before it enters the tree: `p_kind`, telegraph `p_warn` ticks, the referee, the drawn mark.
func setup(p_kind: StringName, p_warn: int, p_referee: Object, p_mark: Rect2i = Rect2i()) -> VersusHazard:
	kind = p_kind
	warn_ticks = maxi(p_warn, 0)
	referee = p_referee
	mark = p_mark
	match kind:
		CHARGER:
			set_box(Vector3i(32, 24, 16))
			effect = EFFECT_KILL
		BLOCK:
			set_box(Vector3i(16, 16, 8))
			effect = EFFECT_KILL
		STALACTITE:
			set_box(Vector3i(12, 20, 6))
			effect = EFFECT_KILL
		BOULDER:
			set_box(Vector3i(20, 20, 10))
			effect = EFFECT_KILL
		BOLT:
			set_box(Vector3i(12, 16, 6))
			effect = EFFECT_KILL
		ROCK:
			set_box(Vector3i(12, 12, 6))
			effect = EFFECT_DAZE
	return self


func _ready() -> void:
	z_index = Defs.Z_FX
	add_to_group(VersusReferee.ROUND_GROUP)
	warn_tick = Sim.tick
	if warn_ticks == 0:
		_arm()


## True while it telegraphs (touches nobody).
func is_warning() -> bool:
	return armed_tick < 0


func _arm() -> void:
	armed_tick = Sim.tick
	match kind:
		CHARGER:
			_sfx(Sfx.QUAKE)
		STALACTITE, BLOCK:
			_sfx(Sfx.IMPACT)
		BOLT:
			_sfx(Sfx.EXPLOSION)
	queue_redraw()


func _sim_tick(phase: int) -> void:
	if _gone:
		return
	if phase == Defs.Phase.PROJECTILES:
		if armed_tick < 0:
			if Sim.tick - warn_tick >= warn_ticks:
				_arm()
			else:
				return
		armed_for += 1
		_move()
		queue_redraw()
	elif phase == Defs.Phase.CONTACT_ITEMS and armed_tick >= 0 and effect != EFFECT_NONE:
		_contacts()


func _move() -> void:
	var level: LevelBase = Game.level
	if level == null:
		return
	match kind:
		CHARGER:
			sim_pos.x += Tuning.floor16(xvel)
			var view: Rect2i = VersusArena.view_rect()
			if sim_pos.x < view.position.x - box_w or sim_pos.x > view.end.x + box_w:
				_remove()
		BOLT:
			if armed_for > BOLT_TICKS:
				_remove()
		BOULDER:
			sim_pos.x += Tuning.floor16(xvel)
			var probe: int = sim_pos.x + (box_xo if xvel > 0 else -box_xo)
			if level.grid.side_at(probe >> 4, (sim_pos.y - 1) >> 4) == TileGrid.SIDE_WALL \
					or sim_pos.x < -box_w or sim_pos.x > level.grid.width_px() + box_w:
				_remove()
				return
			if _fall(level) >= 0:
				yvel = 0
		_:
			var landed: int = _fall(level)
			if landed >= 0:
				_landed(level, landed)


## One falling step with gravity: the feet point moves down by yvel; when it crosses the top of a ground cell it
## stops there. Returns that cell's row (-1 = still falling). Below the map it is gone.
func _fall(level: LevelBase) -> int:
	yvel = mini(yvel + GRAVITY, FALL_MAX)
	var next_y: int = sim_pos.y + Tuning.floor16(yvel)
	var col: int = sim_pos.x >> 4
	var row: int = (sim_pos.y + 15) >> 4
	while row * Tuning.TILE <= next_y:
		if row >= 0 and level.grid.in_bounds(col, row) and TileGrid.is_ground(level.grid.floor_at(col, row)):
			sim_pos.y = row * Tuning.TILE
			return row
		row += 1
	sim_pos.y = next_y
	if sim_pos.y > level.grid.height_px() + Tuning.TILE:
		_remove()
	return -1


func _landed(level: LevelBase, row: int) -> void:
	match kind:
		BLOCK:
			# The block settles into the cell above the ground it landed on: the arena shrinks.
			var cell: Vector2i = Vector2i(sim_pos.x >> 4, row - 1)
			if cell.y >= 1 and level.grid.in_bounds(cell.x, cell.y):
				level.set_cell(cell.x, cell.y, TileGrid.CH_SOLID_A)
				if referee != null and referee.has_method(&"crush_cell"):
					referee.call(&"crush_cell", cell)
			_sfx(Sfx.IMPACT)
			_remove()
		_:
			_fx(&"fx/poof")
			_sfx(Sfx.BLOCK_BREAK)
			_remove()


func _contacts() -> void:
	var level: LevelBase = Game.level
	if level == null or referee == null:
		return
	for hero: PlayerBase in level.heroes:
		if hero == null or not is_instance_valid(hero) or hero.dead or hero.is_down():
			continue
		var id: int = hero.get_instance_id()
		if _touched.has(id) or not touches(hero):
			continue
		_touched[id] = true
		referee.call(&"hazard_contact", hero, self)
		if kind == ROCK or kind == STALACTITE:
			_fx(&"fx/poof")
			_remove()
			return


## True when this armed hazard's box overlaps `hero` (a bolt: its whole column down to the first ground).
func touches(hero: PlayerBase) -> bool:
	if kind == BOLT:
		return Overlap.rects(_bolt_column(), hero.get_box())
	return Overlap.weapon(get_box(), box_xo, hero)


## The box (logical px) a player can see this hazard threaten: armed, its box (a bolt its column); telegraphing,
## where it will strike - a charger's floor lane across the view, the column a block / stalactite falls down to its
## shadow, a rockslide rock's rim, a lightning column.
func danger_rect() -> Rect2i:
	if kind == BOLT:
		return _bolt_column()
	if not is_warning():
		return get_box()
	match kind:
		CHARGER:
			var view: Rect2i = VersusArena.view_rect()
			return Rect2i(view.position.x, sim_pos.y - box_h, view.size.x, box_h)
		BLOCK, STALACTITE:
			return Rect2i(sim_pos.x - box_xo, sim_pos.y - box_h, box_w, maxi(mark.end.y - sim_pos.y + box_h, box_h))
	return get_box().merge(mark) if mark.size != Vector2i.ZERO else get_box()


func _bolt_column() -> Rect2i:
	return Rect2i(sim_pos.x - box_xo, mark.position.y, box_w, maxi(sim_pos.y - mark.position.y, 1))


func _remove() -> void:
	if _gone:
		return
	_gone = true
	sim_active = false
	queue_free()


func _sfx(event: StringName) -> void:
	if AudioTable.SFX.has(event):
		Audio.play_sfx(event)


func _fx(id: StringName) -> void:
	var level: LevelBase = Game.level
	if level != null and Spawner.exists(id):
		level.spawn_fx(id, Vector2i(sim_pos.x, sim_pos.y - (box_h >> 1)))


# --- Presentation (art px, relative to the feet point) ------------------------------------------------------------

const SHADOW_COLOR: Color = Color(0.0, 0.0, 0.0, 0.35)
const DUST_COLOR: Color = Color(0.85, 0.72, 0.5, 0.7)
const MARK_COLOR: Color = Color(1.0, 0.95, 0.4, 0.8)
const ROCK_COLOR: Color = Color(0.45, 0.4, 0.36)
const CHARGER_COLOR: Color = Color(0.35, 0.24, 0.16)
const ICE_COLOR: Color = Color(0.75, 0.9, 1.0)
const BOLT_COLOR: Color = Color(1.0, 1.0, 0.7)


func _draw() -> void:
	var scale_px: float = float(Tuning.ART_SCALE)
	if is_warning():
		# The telegraph: a mark relative to this node (shadow, dust, rattle, cell mark), blinking.
		if mark.size != Vector2i.ZERO and (Sim.tick / 3) % 2 == 0:
			var rect: Rect2 = Rect2(Vector2(mark.position - sim_pos) * scale_px, Vector2(mark.size) * scale_px)
			var color: Color = SHADOW_COLOR
			match kind:
				CHARGER, BOULDER:
					color = DUST_COLOR
				BOLT:
					color = MARK_COLOR
			draw_rect(rect, color)
		if kind == STALACTITE:
			_draw_box(ICE_COLOR, Vector2(float((Sim.tick % 2) * 2 - 1), 0.0))
		return
	match kind:
		BOLT:
			var top: float = float(mark.position.y - sim_pos.y) * scale_px
			draw_rect(Rect2(Vector2(-float(box_xo) * scale_px, top), Vector2(float(box_w) * scale_px, -top)),
					BOLT_COLOR)
		CHARGER:
			_draw_box(CHARGER_COLOR)
		STALACTITE:
			_draw_box(ICE_COLOR)
		_:
			_draw_box(ROCK_COLOR)


func _draw_box(color: Color, shift: Vector2 = Vector2.ZERO) -> void:
	var scale_px: float = float(Tuning.ART_SCALE)
	draw_rect(Rect2(Vector2(-float(box_xo), -float(box_h)) * scale_px + shift, Vector2(float(box_w), float(box_h))
			* scale_px), color)
