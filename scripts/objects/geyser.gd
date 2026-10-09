class_name Geyser
extends SimEntity
## `objects/geyser` (`period` ticks [88, at least 34], `delay` [0], `power` v16 [-224], `skin=mud|blowhole|steam|soda`,
## `deadly`): a spring with a timer (DESIGN.md C.4, PHYSICS.md C.6, GAMEPLAY.md 13.3). Placed in the air cell above
## the vent's floor; its feet point is the floor surface (on a tar floor `:` the lowered one, 6 px down: a hero wading
## there is in the vent box). Cycle position `p = (Sim.tick - delay) mod period` (idle
## before `delay`): it **bubbles** (the telegraph, with the bubble cue) for p in [period - 34, period - 12) and
## **spouts** for p in [period - 12, period). Its state is a function of the tick, so dozing never changes it.
##
## On every spout tick each hero (slot order), ground enemy, raft and drop platform whose feet point is in the vent box
## (24 x 16 above the anchor floor: x - 12 .. x + 11, feet y - 16 .. y), with yvel >= 0 and not yet launched by this
## spout, is launched: heroes `launch(LAUNCH_KEEP, power)`, enemies `yvel = power`, rafts Raft.launch(power) (their
## riders go with them), drop platforms DropPlatform.launch(power) (they rise with `power` and their riders with them,
## then fall back with their dropper fall). -224 rises 105 px. A hero of a co-op party is launched from the vent's
## floor (his feet are put on it first) and his flight is held (PlayerBase.launch / hold_launch, wf11 R1): nothing of
## his own - a hop in the vent box, a strike's hop, a pogo - comes on top of the spout.
## Gliding heroes and eggs ignore geysers. `deadly` (a vent of tar or lava): the spout is a deadly box 24 x 64 above the
## vent (death, or an egg in co-op) instead of a launch; an `objects/boulder_heavy` resting on any geyser plugs it: no
## spout at all [R3].
##
## Owner: objects-B (docs/expansion/PLAN.md 4.1). Runs in CONTACT_ITEMS (like the spring pad), after every hero moved.
## Picture: sprites/objects/geyser.png (ASSET_MANIFEST 17.3): 8 x 6 cells of 64 x 256 art px, pivot (32, 256) = the
## vent floor point; rows mud, blowhole, steam, soda, tar, lava (a `deadly` vent: tar on `liquid = tar` levels, else
## lava); columns 0 idle, 1-3 the bubble loop, 4-7 the spout (4, 5, 6, 5, 6, 7 over its 12 ticks).

enum Cycle { IDLE = 0, BUBBLE = 1, SPOUT = 2 }

## Sheet rows by skin; DEADLY_TAR_ROW / DEADLY_LAVA_ROW for a `deadly` vent.
const SKIN_ROWS: Dictionary = {"mud": 0, "blowhole": 1, "steam": 2, "soda": 3}
const DEADLY_TAR_ROW: int = 4
const DEADLY_LAVA_ROW: int = 5
const SHEET: Texture2D = preload("res://assets/sprites/objects/geyser.png")
const SHEET_COLUMNS: int = 8
const CELL_ART: Vector2 = Vector2(64, 256)
const COL_IDLE: int = 0
const BUBBLE_COLUMNS: Array[int] = [1, 2, 3]
## The spout's columns, two ticks each.
const SPOUT_COLUMNS: Array[int] = [4, 5, 6, 5, 6, 7]
const DEFAULT_SKIN: String = "mud"

## Cycle length in ticks (at least Tuning.GEYSER_PERIOD_MIN).
var period: int = Tuning.GEYSER_PERIOD
## Ticks before the first cycle starts (idle until then).
var delay: int = 0
## Launch speed, v16 (negative = up).
var power: int = Tuning.GEYSER_POWER
## Look: mud, blowhole, steam or soda.
var skin: String = DEFAULT_SKIN
## True for a vent of tar or lava: the spout kills instead of launching.
var deadly: bool = false
## Test / editor hook: forced plug (a boulder found on the vent plugs it too, [method is_plugged]).
var plugged: bool = false
## Launches made (statistics, tests).
var launches: int = 0
## Cycle state of the last tick (Cycle).
var state: int = Cycle.IDLE

## Instance ids launched by the running spout ("not yet launched by this spout").
var _launched: Dictionary = {}
var _boulders: Array[SimEntity] = []
var _boulders_found: bool = false
var _sprite: Sprite2D = null
var _row: int = 0


func _init() -> void:
	z_index = Defs.Z_OBJECTS
	set_box(Vector3i(Tuning.GEYSER_VENT_W, Tuning.GEYSER_VENT_H, Tuning.GEYSER_VENT_W / 2))


func _sim_phases() -> PackedInt32Array:
	return PackedInt32Array([Defs.Phase.CONTACT_ITEMS])


func _apply_params(params: Dictionary) -> void:
	period = maxi(int(params.get("period", period)), Tuning.GEYSER_PERIOD_MIN)
	delay = maxi(int(params.get("delay", delay)), 0)
	power = int(params.get("power", power))
	skin = str(params.get("skin", skin))
	if not SKIN_ROWS.has(skin):
		skin = DEFAULT_SKIN
	deadly = param_bool("deadly", false)
	_row = int(SKIN_ROWS[skin])
	if deadly:
		var liquid: String = str(Game.level.meta.get("liquid", "")) if Game.level != null else ""
		_row = DEADLY_TAR_ROW if liquid == "tar" else DEADLY_LAVA_ROW
	_settle_on_surface()


## The vent sits on its floor's SURFACE: placed on the top edge of a floor cell whose surface lies lower (a tar floor
## `:` 6 px down, PHYSICS.md C.5; a slope by its profile), its feet point moves down onto that surface, so a hero or a
## ground enemy wading there stands in the vent box (LEVEL_DESIGN.md 15.3: "a tar pit ... is a trap unless a vine, a
## geyser or a partner gets the hero out"; Feast Land D's soda geysers on honey). A geyser placed on the surface
## itself, or over anything but ground, stays where it is.
func _settle_on_surface() -> void:
	var level: LevelBase = Game.level
	if level == null:
		return
	var col: int = sim_pos.x >> 4
	var row: int = sim_pos.y >> 4
	if sim_pos.y != row * Tuning.TILE or not TileGrid.is_ground(level.grid.floor_at(col, row)):
		return
	var drop: int = level.grid.surface_offset(col, row, sim_pos.x)
	if drop > 0:
		teleport(Vector2i(sim_pos.x, sim_pos.y + drop))


func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.texture = SHEET
	_sprite.centered = false
	_sprite.offset = Vector2(-CELL_ART.x / 2.0, -CELL_ART.y)
	_sprite.hframes = SHEET_COLUMNS
	_sprite.vframes = maxi(int(SHEET.get_height() / CELL_ART.y), 1)
	add_child(_sprite)
	_refresh_look()


# --- The cycle (a pure function of the tick) --------------------------------------------------------------------------

## Cycle state (Cycle) of a geyser with `period` and `delay` on simulation tick `tick` (PHYSICS.md C.6). Static so that
## the bot baker can time geyser links (GAMEPLAY.md 13.10.10).
static func cycle_at(tick: int, p_period: int, p_delay: int) -> int:
	if tick < p_delay:
		return Cycle.IDLE
	var p: int = posmod(tick - p_delay, maxi(p_period, Tuning.GEYSER_PERIOD_MIN))
	var spout_from: int = p_period - Tuning.GEYSER_SPOUT_TICKS
	if p >= spout_from:
		return Cycle.SPOUT
	if p >= spout_from - Tuning.GEYSER_BUBBLE_TICKS:
		return Cycle.BUBBLE
	return Cycle.IDLE


## This geyser's state on tick `tick`.
func state_at(tick: int) -> int:
	return cycle_at(tick, period, delay)


## True on the ticks it spouts (now).
func is_spouting() -> bool:
	return state_at(Sim.tick) == Cycle.SPOUT


## True on its telegraph ticks (now).
func is_bubbling() -> bool:
	return state_at(Sim.tick) == Cycle.BUBBLE


## The vent box (logical px): 24 x 16 above the anchor floor.
func vent_rect() -> Rect2i:
	return Rect2i(sim_pos.x - Tuning.GEYSER_VENT_W / 2, sim_pos.y - Tuning.GEYSER_VENT_H, Tuning.GEYSER_VENT_W,
			Tuning.GEYSER_VENT_H)


## The deadly spout box of a `deadly` vent (logical px): 24 x 64 above the anchor floor.
func deadly_rect() -> Rect2i:
	return Rect2i(sim_pos.x - Tuning.GEYSER_VENT_W / 2, sim_pos.y - Tuning.GEYSER_DEADLY_H, Tuning.GEYSER_VENT_W,
			Tuning.GEYSER_DEADLY_H)


## True while a heave boulder rests on the vent ([R3]) or [member plugged] is set.
func is_plugged() -> bool:
	if plugged:
		return true
	if not _boulders_found:
		_find_boulders()
	var probe: Vector2i = Vector2i(sim_pos.x, sim_pos.y - 1)
	for boulder: SimEntity in _boulders:
		if not is_instance_valid(boulder) or boulder.is_queued_for_deletion():
			continue
		if boulder.has_method(&"plugs_vent"):
			if bool(boulder.call(&"plugs_vent", vent_rect())):
				return true
		elif boulder.get_box().has_point(probe):
			return true
	return false


## Collects the heave boulders once; a look outside a tick (a draw before every entity spawned) is not kept.
func _find_boulders() -> void:
	_boulders_found = Sim.is_in_tick()
	_boulders.clear()
	var level: LevelBase = Game.level
	if level == null:
		return
	for kind: int in [Defs.Kind.PLATFORM, Defs.Kind.HITTABLE, Defs.Kind.OTHER]:
		for entity: SimEntity in level.get_kind(kind):
			var script: Script = entity.get_script() as Script
			var global: StringName = script.get_global_name() if script != null else &""
			if entity.has_method(&"plugs_vent") or global == &"HeavyBoulder" or global == &"BoulderHeavy":
				_boulders.append(entity)


# --- Simulation -------------------------------------------------------------------------------------------------------

## Dozing (SimEntity, ARCHITECTURE.md 11): the cycle is a function of Sim.tick, so a dozing geyser loses nothing; it can
## only touch things inside its spout area, which wake it when a hero comes near.
func _doze_area() -> Rect2i:
	return deadly_rect().merge(vent_rect())


func _can_doze() -> bool:
	return true


func _on_doze_wake() -> void:
	state = state_at(Sim.tick)
	_refresh_look()


func _sim_tick(phase: int) -> void:
	if phase != Defs.Phase.CONTACT_ITEMS:
		return
	var now: int = state_at(Sim.tick)
	var before: int = state
	state = now
	_refresh_look()
	if now != before:
		if now == Cycle.SPOUT:
			_launched.clear()
		if on_screen and not is_plugged():
			if now == Cycle.BUBBLE and AudioTable.SFX.has(Sfx.GEYSER_BUBBLE):
				Audio.play_sfx(Sfx.GEYSER_BUBBLE)
			elif now == Cycle.SPOUT:
				Audio.play_sfx(Sfx.GEYSER_SPOUT if AudioTable.SFX.has(Sfx.GEYSER_SPOUT) else Sfx.BOUNCE)
	if now != Cycle.SPOUT or is_plugged():
		return
	var level: LevelBase = Game.level
	if level == null:
		return
	if deadly:
		_deadly_spout(level)
	else:
		_spout(level)


func _spout(level: LevelBase) -> void:
	var vent: Rect2i = vent_rect()
	for hero: PlayerBase in level.contact_order():
		if hero.dead or hero.is_down() or hero.is_gliding() or hero.is_mounted() or hero.yvel < 0:
			continue
		if _inside(vent, hero) and _first_time(hero):
			if hero.sim_pos.y < sim_pos.y and hero.gate_rule(PlayerBase.GATE_R1):
				# wf11 R1 (co-op): the launch starts from the vent's floor - a hop inside the vent box (16 px high) no
				# longer carries its height on top of the spout (120 px from a -224 vent; 105 from the floor).
				hero.sim_pos.y = sim_pos.y
			hero.launch(PlayerBase.LAUNCH_KEEP, power)
			launches += 1
	var enemies: Array[SimEntity] = level.get_kind(Defs.Kind.ENEMY)
	for i: int in enemies.size():
		var enemy: EnemyBase = enemies[i] as EnemyBase
		if enemy == null or enemy.dead or not enemy.awake or enemy.yvel < 0:
			continue
		if _inside(vent, enemy) and _first_time(enemy):
			enemy.yvel = power
			launches += 1
	var platforms: Array[SimEntity] = level.get_kind(Defs.Kind.PLATFORM)
	for i: int in platforms.size():
		var platform: SimEntity = platforms[i]
		if platform.yvel < 0 or not _inside(vent, platform) or _launched.has(platform.get_instance_id()):
			continue
		if platform is Raft:
			_first_time(platform)
			(platform as Raft).launch(power)
			launches += 1
		elif platform is DropPlatform:
			var dropper: DropPlatform = platform as DropPlatform
			if dropper.fall_speed < 0:
				continue
			_first_time(platform)
			# objects-A's launch: FALL with fall_speed = power, and every hero riding it launched with it (one arc).
			dropper.launch(power)
			launches += 1


func _deadly_spout(level: LevelBase) -> void:
	var box: Rect2i = deadly_rect()
	for hero: PlayerBase in level.contact_order():
		if hero.dead or hero.is_down() or hero.is_gliding():
			continue
		if Overlap.rects(hero.get_box(), box) or Overlap.point_in(box, hero.sim_pos.x, hero.sim_pos.y - 1):
			hero.kill(&"liquid")


## True when the feet point of `entity` is in the vent box `rect`: x - 12 .. x + 11 and feet y - 16 .. y, both ends
## included (a hero standing on the vent's floor has his feet on y).
static func _inside(rect: Rect2i, entity: SimEntity) -> bool:
	var feet: Vector2i = entity.sim_pos
	return feet.x >= rect.position.x and feet.x < rect.end.x and feet.y >= rect.position.y and feet.y <= rect.end.y


## Marks `entity` launched by this spout; false when it already was.
func _first_time(entity: Object) -> bool:
	var id: int = entity.get_instance_id()
	if _launched.has(id):
		return false
	_launched[id] = true
	return true


# --- Picture ----------------------------------------------------------------------------------------------------------

## The frame of the cycle position (cosmetic; a plugged vent shows its idle frame).
func _refresh_look() -> void:
	if _sprite == null:
		return
	var column: int = COL_IDLE
	if state != Cycle.IDLE and is_plugged():
		column = COL_IDLE
	elif state == Cycle.BUBBLE:
		column = BUBBLE_COLUMNS[(Sim.tick >> 2) % BUBBLE_COLUMNS.size()]
	elif state == Cycle.SPOUT:
		var p: int = posmod(Sim.tick - delay, period) - (period - Tuning.GEYSER_SPOUT_TICKS)
		column = SPOUT_COLUMNS[clampi(p >> 1, 0, SPOUT_COLUMNS.size() - 1)]
	_sprite.frame = clampi(_row, 0, _sprite.vframes - 1) * SHEET_COLUMNS + column
