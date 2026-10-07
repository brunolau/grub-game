class_name CrateLane
extends SceneryHittable
## `objects/crate_lane` (`rect=c,r,w,h`, arenas only): a marked lane of the pterodactyl crates (DESIGN.md E.2 / E.3,
## GAMEPLAY.md 13.10.3, LEVEL_DESIGN.md 15.8). Every crate period a pterodactyl carries a crate along the lane's top
## row and drops it over one of the lane's columns; the crate's **shadow** shows on its landing point
## VersusTuning.CRATE_SHADOW_TICKS before the drop; it falls (gravity 16, cap Tuning.TERMINAL) onto the first floor
## below the top row inside the rect (rows r + 1 .. r + h - 1; a column whose first non-empty cell there is deadly, or
## that has no floor in the rect, is never chosen) and lies there as a crate one hit opens (any weapon box, thrown
## weapon or batted ball: the lane is the crate's HittableBase). It bursts into its contents in a fan.
##
## **Contents** (ItemContents tokens): the referee's `crate_contents(lane) -> String` when the level's party driver has
## it (a non-empty answer), else the default table, drawn from Sim.rng (the round seed) when the crate is scheduled:
## one food item (`food:<cell>`), one special (`weapon:<hammer|axe|boomerang|spear>`, unless the match's weapons rule is
## club only), one cutlery piece (`feast_piece:<0..2>`), and with SKULL_CHANCE_NUM / SKULL_CHANCE_DEN a skull or a
## grenade; the variant Axe Rain makes every crate a single axe. Weapon tokens always spawn as **temporary** specials
## (`items/weapon temp=true`: onto the belt, PHYSICS.md C.2 rule 6 / C.14).
##
## **Timing**: the first lane of the level in spawn order whose [member auto] is on is the scheduler: when the round
## clock (the referee's `round_ticks` when the party driver has it, else this lane's own tick count) reaches
## k * period - CRATE_SHADOW_TICKS (k >= 1) it picks a free lane (Sim.rng) and a column (Sim.rng), so the crate drops at
## k * period exactly. The period: the referee's (its `crate_period_ticks()` or its round rules' `crate_period`) when
## it has one, else Game.versus_match.crate_period_ticks() (Classic or crates off: none; Feast 486; Mayhem 194),
## VersusTuning.MAYHEM_CRATE_PERIOD_TICKS with Axe Rain, VersusTuning.CRATE_PERIOD_TICKS without a match; none in
## Clubball (club only, GAMEPLAY.md 13.10.6). A lane holds one crate at a time (a busy lane is skipped,
## and a period with no free lane drops nothing). The referee may take the timing over: [member auto] = false on every
## lane ([method set_auto]) and [method drop] when it likes.
##
## A refill (the referee's spot refill, the Feast Rush) does nothing: crates come only from the sky. Owner: objects-B
## (docs/expansion/PLAN.md 4.1, P2.7). Pictures: sprites/objects/crate.png (ASSET_MANIFEST 9) under
## sprites/enemies/pterodactyl.png (fly 0-3, cosmetic flight), a drawn shadow ellipse. Marks: [own] this module.

## Lane states.
const STATE_IDLE: int = 0      ## empty
const STATE_INCOMING: int = 1  ## the pterodactyl is on its way, the shadow shows
const STATE_FALLING: int = 2   ## dropped
const STATE_LANDED: int = 3    ## lying on the floor, one hit opens it

## Contents of the default table (see the class description). (tune) [own]
const SPECIALS: Array[String] = ["hammer", "axe", "boomerang", "spear"]
const SKULL_CHANCE_NUM: int = 1
const SKULL_CHANCE_DEN: int = 4
const AXE_RAIN_CONTENTS: String = "weapon:axe"

## The crate's box (the shipped crate picture, as objects/container skin=crate).
const CRATE_BOX: Vector3i = Vector3i(16, 11, 8)
const CRATE_TEXTURE: Texture2D = preload("res://assets/sprites/objects/crate.png")
const CRATE_PIVOT: Vector2 = Vector2(16, 22)
## The pterodactyl (ASSET_MANIFEST 3: 8 x 2 cells of 144 x 120 art px, pivot (72, 104), faces right; fly 0-3).
const PTERO_TEXTURE: Texture2D = preload("res://assets/sprites/enemies/pterodactyl.png")
const PTERO_PIVOT: Vector2 = Vector2(72, 104)
const PTERO_FLY_FRAMES: int = 4
const PTERO_FPS: float = 8.0
## Cosmetic flight: the pterodactyl comes FLY_IN_PX from the side over the shadow's lead and flies on for FLYOFF_TICKS.
const FLY_IN_PX: int = 160
const FLYOFF_TICKS: int = 24
## The shadow ellipse (art px) and its colour.
const SHADOW_RADIUS_ART: float = 14.0
const SHADOW_SQUASH: float = 0.3
const SHADOW_COLOR: Color = Color(0.0, 0.0, 0.0, 0.35)
const ID_DUST: StringName = &"fx/dust"

## The lane in cells (`rect=c,r,w,h`): the pterodactyl flies along row r, crates drop over columns c .. c + w - 1.
var lane: Rect2i = Rect2i()
## True: the lane (and its scheduler) runs its own clock; false: only [method drop] brings crates (the referee).
var auto: bool = true
## STATE_* of the lane.
var state: int = STATE_IDLE
## Contents tokens of the crate on its way or lying here ("" when empty).
var contents: String = ""
## Where the current crate is released (feet: the bottom of the lane's top row) and where it lands (the shadow).
var drop_point: Vector2i = Vector2i.ZERO
var land_point: Vector2i = Vector2i.ZERO
## Sim.tick on which the pterodactyl drops the crate (STATE_INCOMING): the release does not depend on the order in
## which the lanes tick.
var release_tick: int = 0
## Crates dropped and crates opened on this lane (statistics, tests).
var crates_dropped: int = 0
var crates_opened: int = 0

var _fall_yvel: int = 0
var _flyoff_left: int = 0
var _fly_dir: int = 1
var _own_clock: int = 0
var _last_schedule_clock: int = -1
var _crate: Sprite2D = null
var _ptero: Sprite2D = null
var _anim_time: float = 0.0


func _init() -> void:
	super()
	spot_kind = &"crate"
	counts_for_completion = false
	set_box(CRATE_BOX)


func _ready() -> void:
	_crate = Sprite2D.new()
	_crate.name = "Crate"
	_crate.texture = CRATE_TEXTURE
	_crate.centered = false
	_crate.offset = -CRATE_PIVOT
	add_child(_crate)
	_ptero = Sprite2D.new()
	_ptero.name = "Pterodactyl"
	_ptero.texture = PTERO_TEXTURE
	_ptero.hframes = 8
	_ptero.vframes = 2
	_ptero.centered = false
	_ptero.offset = -PTERO_PIVOT
	_ptero.z_as_relative = false
	_ptero.z_index = Defs.Z_FX
	add_child(_ptero)
	_refresh_look()


func _apply_params(params: Dictionary) -> void:
	super._apply_params(params)
	spot_kind = &"crate"
	var parts: PackedInt32Array = LevelText.to_int_list(params.get("rect", ""))
	if parts.size() == 4 and parts[2] > 0 and parts[3] > 0:
		lane = Rect2i(parts[0], parts[1], parts[2], parts[3])
	else:
		lane = Rect2i(cell.x, 0, 1, cell.y + 1)
		push_warning("objects/crate_lane at %s: missing or malformed rect=c,r,w,h; using its column" % sim_pos)
	_empty()


# =================================================================================================================
# Queries and calls (referee, bots, HUD)
# =================================================================================================================

## Every crate lane of `level` in spawn order.
static func lanes_of(level: LevelBase) -> Array[CrateLane]:
	var result: Array[CrateLane] = []
	if level == null:
		return result
	for entity: SimEntity in level.get_kind(Defs.Kind.HITTABLE):
		var crate_lane: CrateLane = entity as CrateLane
		if crate_lane != null and not crate_lane.is_queued_for_deletion():
			result.append(crate_lane)
	return result


## Switch the lanes' own clock on or off on every lane of `level` (the referee takes the timing over with false).
static func set_auto(level: LevelBase, on: bool) -> void:
	for crate_lane: CrateLane in lanes_of(level):
		crate_lane.auto = on


## True while a crate lies on the lane (one hit opens it).
func has_crate() -> bool:
	return state == STATE_LANDED


## True while the shadow shows (the crate is on its way or falling): [member land_point] is where it lands.
func shows_shadow() -> bool:
	return state == STATE_INCOMING or state == STATE_FALLING


## Ticks until the pterodactyl drops the crate (0 when none is on its way).
func ticks_to_drop() -> int:
	return maxi(release_tick - Sim.tick, 0) if state == STATE_INCOMING else 0


## The columns a crate may drop over: those of the lane whose first non-empty cell under the top row (inside the
## rect) is a floor.
func drop_columns() -> PackedInt32Array:
	var columns: PackedInt32Array = PackedInt32Array()
	for col: int in range(lane.position.x, lane.end.x):
		if landing_y(col) >= 0:
			columns.append(col)
	return columns


## The feet y a crate dropped over column `col` lands on, -1 when it would not land inside the lane.
func landing_y(col: int) -> int:
	var level: LevelBase = Game.level
	if level == null:
		return -1
	var grid: TileGrid = level.grid
	for row: int in range(lane.position.y + 1, lane.end.y):
		var floor_value: int = grid.floor_at(col, row)
		if TileGrid.is_ground(floor_value):
			return row * Tuning.TILE + grid.surface_offset(col, row, col * Tuning.TILE + Tuning.TILE / 2)
		if floor_value == TileGrid.FLOOR_DEADLY:
			return -1
	return -1


## Send a crate holding `crate_contents` (ItemContents tokens) over column `col`: the shadow shows at once, the crate
## is released `lead_ticks` later. False (nothing happens) while the lane is busy or when nothing can land there.
func drop(col: int, crate_contents: String, lead_ticks: int = VersusTuning.CRATE_SHADOW_TICKS) -> bool:
	if state != STATE_IDLE:
		return false
	var land_y: int = landing_y(col)
	if land_y < 0:
		return false
	_doze_wake_now()
	contents = crate_contents
	var x: int = col * Tuning.TILE + Tuning.TILE / 2
	drop_point = Vector2i(x, (lane.position.y + 1) * Tuning.TILE)
	land_point = Vector2i(x, land_y)
	release_tick = Sim.tick + maxi(lead_ticks, 0)
	_fly_dir = 1 if crates_dropped % 2 == 0 else -1
	state = STATE_INCOMING
	teleport(drop_point)
	if lead_ticks <= 0:
		_release()
	_refresh_look()
	return true


## Crates come only from the sky: the referee's refills (and the Feast Rush) leave a lane as it is.
func refill() -> void:
	pass


# =================================================================================================================
# Simulation
# =================================================================================================================

func _sim_tick(phase: int) -> void:
	super._sim_tick(phase)
	if phase != Defs.Phase.WORLD:
		return
	var level: LevelBase = Game.level
	if level == null:
		return
	match state:
		STATE_INCOMING:
			if Sim.tick >= release_tick:
				_release()
		STATE_FALLING:
			_fall()
	if _flyoff_left > 0:
		_flyoff_left -= 1
	if auto and _is_scheduler(level):
		_schedule(level)


## The scheduler is the first lane of the level (spawn order) whose clock is on.
func _is_scheduler(level: LevelBase) -> bool:
	for entity: SimEntity in level.get_kind(Defs.Kind.HITTABLE):
		var crate_lane: CrateLane = entity as CrateLane
		if crate_lane != null and crate_lane.auto and not crate_lane.is_queued_for_deletion():
			return crate_lane == self
	return false


func _schedule(level: LevelBase) -> void:
	_own_clock += 1
	var period: int = crate_period(level)
	if period <= 0:
		return
	var clock: int = round_clock(level)
	if clock <= 0 or clock == _last_schedule_clock:
		return
	if (clock + VersusTuning.CRATE_SHADOW_TICKS) % period != 0:
		return
	_last_schedule_clock = clock
	var free: Array[CrateLane] = []
	for crate_lane: CrateLane in lanes_of(level):
		if crate_lane.auto and crate_lane.state == STATE_IDLE and not crate_lane.drop_columns().is_empty():
			free.append(crate_lane)
	if free.is_empty():
		return
	var chosen: CrateLane = free[Sim.rng.next_int(free.size())]
	var columns: PackedInt32Array = chosen.drop_columns()
	var col: int = columns[Sim.rng.next_int(columns.size())]
	chosen.drop(col, chosen.choose_contents(level))


## The round clock the schedule follows: the referee's `round_ticks` (the party driver's) when it has one, else the
## scheduler lane's own tick count since the level started.
func round_clock(level: LevelBase) -> int:
	var driver: SimEntity = level.party_driver if level != null else null
	if driver != null and &"round_ticks" in driver:
		return int(driver.get(&"round_ticks"))
	return _own_clock


## Ticks between crates (0 = none): the referee's when it rules them (the party driver's `crate_period_ticks()`, else
## its round rules' `crate_period`: Mayhem may draw Axe Rain per round), else see the class description.
static func crate_period(level: LevelBase) -> int:
	var driver: SimEntity = level.party_driver if level != null else null
	if driver != null:
		if driver.has_method(&"crate_period_ticks"):
			return maxi(int(driver.call(&"crate_period_ticks")), 0)
		var round_rules: Variant = driver.get(&"rules") if &"rules" in driver else null
		if round_rules is Object and &"crate_period" in round_rules:
			return maxi(int((round_rules as Object).get(&"crate_period")), 0)
		if &"mode" in driver and int(driver.get(&"mode")) == Defs.VersusMode.CLUBBALL:
			return 0
	var match_rules: VersusMatch = Game.versus_match
	if match_rules == null:
		return VersusTuning.CRATE_PERIOD_TICKS
	var period: int = match_rules.crate_period_ticks()
	if period > 0 and match_rules.has_variant(&"axe_rain"):
		return VersusTuning.MAYHEM_CRATE_PERIOD_TICKS
	return period


## The contents of the next crate: the referee's `crate_contents(lane)` when it answers, else the default table.
func choose_contents(level: LevelBase) -> String:
	var driver: SimEntity = level.party_driver if level != null else null
	if driver != null and driver.has_method(&"crate_contents"):
		var answer: String = str(driver.call(&"crate_contents", self))
		if not answer.is_empty():
			return answer
	return default_contents()


## The default table, drawn from Sim.rng in a fixed order (food, special, cutlery, the skull / grenade chance).
static func default_contents() -> String:
	var match_rules: VersusMatch = Game.versus_match
	if match_rules != null and match_rules.has_variant(&"axe_rain"):
		return AXE_RAIN_CONTENTS
	var tokens: PackedStringArray = PackedStringArray()
	tokens.append("food:%d" % Sim.rng.next_int(ItemTable.FOOD_POINTS.size()))
	if match_rules == null or match_rules.weapons != &"club":
		tokens.append("weapon:%s" % SPECIALS[Sim.rng.next_int(SPECIALS.size())])
	tokens.append("feast_piece:%d" % Sim.rng.next_int(Tuning.FEAST_PIECES))
	if Sim.rng.chance(SKULL_CHANCE_NUM, SKULL_CHANCE_DEN):
		tokens.append("skull" if Sim.rng.next_int(2) == 0 else "grenade")
	return ",".join(tokens)


func _release() -> void:
	state = STATE_FALLING
	_fall_yvel = 0
	crates_dropped += 1
	_flyoff_left = FLYOFF_TICKS
	teleport(drop_point)
	ObjTuning.play_cue(Sfx.CRATE_DROP)
	if drop_point.y >= land_point.y:
		_land()
	_refresh_look()


func _fall() -> void:
	var y: int = sim_pos.y + Tuning.floor16(_fall_yvel)
	_fall_yvel = mini(_fall_yvel + Tuning.GRAVITY, Tuning.TERMINAL)
	if y >= land_point.y:
		sim_pos = land_point
		_land()
	else:
		sim_pos = Vector2i(land_point.x, y)


func _land() -> void:
	state = STATE_LANDED
	cell = Vector2i(sim_pos.x >> 4, (sim_pos.y - 1) >> 4)
	opened = false
	hits_left = 1
	hits_total = 1
	cooldown = 0
	if Game.level != null:
		Game.level.spawn_fx(ID_DUST, sim_pos)
	_refresh_look()


## The crate burst (HittableBase.open): debris, then its contents in a fan, weapons as temporary specials.
func _on_opened() -> void:
	var level: LevelBase = Game.level
	var text: String = contents
	var at: Vector2i = Vector2i(sim_pos.x, sim_pos.y - 1)
	crates_opened += 1
	_empty()
	if level == null:
		return
	spray("wood", ObjTuning.CONTAINER_DEBRIS, get_hit_point())
	level.spawn_fx(ID_POOF, get_hit_point())
	Audio.play_sfx(Sfx.BLOCK_BREAK)
	var payload: ItemContents = ItemContents.parse(text)
	for i: int in payload.size():
		var v: Vector2i = ObjTuning.fan_velocity(i, strike_dir * ObjTuning.SPOT_THROW_XVEL, ObjTuning.SPOT_THROW_YVEL)
		var id: StringName = payload.ids[i]
		var arg: String = payload.args[i]
		var params: Dictionary = {"dropped": true, "xvel": v.x, "yvel": v.y}
		if id == ItemContents.ID_WEAPON:
			params["kind"] = arg
			params["temp"] = true
		elif not arg.is_empty():
			params["index"] = arg.to_int()
		level.spawn(id, at, params)


func _on_hit(_power: int, _source: SimEntity) -> void:
	wobble(_crate)


## The centre of the crate.
func get_hit_point() -> Vector2i:
	return Vector2i(sim_pos.x, sim_pos.y - (CRATE_BOX.y >> 1))


## Back to empty: not hittable, nothing drawn but a pterodactyl still flying off.
func _empty() -> void:
	state = STATE_IDLE
	contents = ""
	opened = true
	hits_left = 0
	cooldown = 0
	release_tick = 0
	_refresh_look()


func _on_level_reset() -> void:
	_flyoff_left = 0
	_fall_yvel = 0
	_empty()


## A lane never dozes: its clock must run (an arena is one screen anyway).
func _can_doze() -> bool:
	return false


# =================================================================================================================
# Picture (cosmetic: computed from the simulation state)
# =================================================================================================================

func _process(delta: float) -> void:
	_anim_time += delta
	_refresh_look()


func _refresh_look() -> void:
	if _crate == null:
		return
	_crate.visible = state != STATE_IDLE
	var flying: bool = state == STATE_INCOMING or _flyoff_left > 0
	_ptero.visible = flying
	var lead: int = maxi(VersusTuning.CRATE_SHADOW_TICKS, 1)
	var speed: float = float(FLY_IN_PX) / float(lead)
	var ptero_x: float = float(drop_point.x)
	if state == STATE_INCOMING:
		ptero_x -= float(_fly_dir) * speed * (float(ticks_to_drop()) - Sim.alpha)
	elif _flyoff_left > 0:
		ptero_x += float(_fly_dir) * speed * (float(FLYOFF_TICKS - _flyoff_left) + Sim.alpha)
	# The pterodactyl's feet carry the crate's top (crate 11 logical px tall), in the node's local art px.
	var origin: Vector2 = Tuning.to_art(Vector2(sim_pos))
	var crate_top: Vector2 = Tuning.to_art(Vector2(ptero_x, float(drop_point.y - CRATE_BOX.y)))
	_ptero.position = crate_top - origin
	_ptero.flip_h = _fly_dir < 0
	_ptero.frame = int(_anim_time * PTERO_FPS) % PTERO_FLY_FRAMES
	_crate.position = Vector2.ZERO
	if state == STATE_INCOMING:
		_crate.position.x = (ptero_x - float(sim_pos.x)) * Tuning.ART_SCALE
	queue_redraw()


func _draw() -> void:
	if state != STATE_INCOMING and state != STATE_FALLING:
		return
	var local: Vector2 = Tuning.to_art(Vector2(land_point - sim_pos))
	draw_set_transform(local, 0.0, Vector2(1.0, SHADOW_SQUASH))
	draw_circle(Vector2.ZERO, SHADOW_RADIUS_ART, SHADOW_COLOR)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
