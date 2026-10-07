class_name VersusSuddenDeath
extends RefCounted
## The arena's themed sudden death (docs/expansion/DESIGN.md E.6, GAMEPLAY.md 13.10.9): the arena meta `sudden`
## (LevelData.SUDDEN_DEATHS), else one theme per biome, started by the referee at VersusTuning.SUDDEN_DEATH_AT_TICKS in Last Caveman
## Standing (and as an event in the other modes). Owner: world-B (PLAN.md P2.4).
##
## Ticked by the referee in its WORLD step. Every threat is telegraphed 10+ ticks ahead:
##  - Stampede: a charger runs along the floor every 73 ticks (dust 22 ticks ahead), from alternating sides.
##  - Cave-in: blocks fall from the top row inward (edge columns first), one per 11 ticks, each shadowed 11 ticks.
##  - Whiteout: the wind grows by 8 every 121 ticks, alternating sides; each change is announced 22 ticks ahead.
##  - Lava rise / Tar rise: a deadly band rises one row per 44 ticks; each step rumbles 11 ticks ahead.
##  - High tide: the band rises at 8 v16 per tick after a 22-tick rumble (the rising-tide pace of C.8).
##  - Syrup flood: a band rising one row per 44 ticks up to row 7 that only slows (the tar caps), never kills.
##  - Stalactite storm: a stalactite over a random column every 22 ticks, a 14-tick rattle.
##  - Rockslide: a rock from a mesa rim every 33 ticks (alternating rims), dust 14 ticks ahead.
##  - Lightning: a marked column every 33 ticks, 22 ticks ahead; the bolt burns 4 ticks.
## Columns and rims come from Sim.rng (the round seed), so a round replays tick for tick.

const STAMPEDE: StringName = &"stampede"
const CAVE_IN: StringName = &"cave_in"
const WHITEOUT: StringName = &"whiteout"
const LAVA_RISE: StringName = &"lava_rise"
const TAR_RISE: StringName = &"tar_rise"
const HIGH_TIDE: StringName = &"high_tide"
const SYRUP_FLOOD: StringName = &"syrup_flood"
const STALACTITE_STORM: StringName = &"stalactites"
const ROCKSLIDE: StringName = &"rockslide"
const LIGHTNING: StringName = &"lightning"
const THEMES: Array[StringName] = [
	STAMPEDE, CAVE_IN, WHITEOUT, LAVA_RISE, TAR_RISE, HIGH_TIDE, SYRUP_FLOOD, STALACTITE_STORM, ROCKSLIDE, LIGHTNING,
]
## The theme of a biome (DESIGN.md E.5 / E.6; the village plays the jungle's, the keep is the ruins biome).
const THEME_OF_BIOME: Dictionary = {
	"jungle": STAMPEDE, "village": STAMPEDE, "cave": CAVE_IN, "ice": WHITEOUT, "volcano": LAVA_RISE,
	"swamp": TAR_RISE, "coast": HIGH_TIDE, "feast": SYRUP_FLOOD, "ruins": STALACTITE_STORM, "canyon": ROCKSLIDE,
	"sky": LIGHTNING,
}
## Cadences and telegraphs (GAMEPLAY.md 13.10.9, all (tune)).
const STAMPEDE_DUST_TICKS: int = VersusTuning.STAMPEDE_DUST_TICKS
const CAVE_IN_SHADOW_TICKS: int = 11
const WHITEOUT_STEP: int = 8
const WHITEOUT_WARN_TICKS: int = 22
const BAND_ROW_TICKS: int = VersusTuning.LAVA_RISE_ROW_TICKS
const BAND_RUMBLE_TICKS: int = 11
const TIDE_RISE_V16: int = 8
const TIDE_RUMBLE_TICKS: int = 22
const SYRUP_TOP_ROW: int = 7
const SYRUP_WALK_CAP: int = 32       ## the tar caps (PHYSICS.md C.5): walking and the air 32 v16
const STALACTITE_PERIOD_TICKS: int = 22
const STALACTITE_RATTLE_TICKS: int = 14
const ROCKSLIDE_PERIOD_TICKS: int = 33
const ROCKSLIDE_DUST_TICKS: int = 14
const LIGHTNING_PERIOD_TICKS: int = 33
const LIGHTNING_MARK_TICKS: int = VersusTuning.LIGHTNING_MARK_TICKS
## A hero dies in a deadly band once his feet are this many px under its surface.
const BAND_DEPTH_PX: int = 2
## The least telegraph of any threat (PLAN.md 8 V4.a: every sudden death telegraphed >= 10 ticks).
const MIN_TELEGRAPH_TICKS: int = 10

## The theme running ("" = none).
var theme: StringName = &""
## Ticks since it started.
var ticks: int = 0
## The deadly / slowing band's surface (logical px; -1 = no band), and its v16 remainder for the tide.
var band_top: int = -1
var band_top_v16: int = 0
## Sim.tick on which the band's next step was announced (-1 = none pending), and of the step itself.
var band_warn_tick: int = -1
var band_step_tick: int = -1
## Whiteout: the wind now, the wind announced next and when it blows.
var wind: int = 0
var wind_next: int = 0
var wind_at: int = -1
var wind_warn_tick: int = -1
## Every threat so far: {"what", "warn": Sim.tick of the telegraph, "strike": Sim.tick it turns deadly}.
var threats: Array[Dictionary] = []

var _referee: Object = null
var _level: LevelBase = null
var _count: int = 0
var _cave_cols: PackedInt32Array = PackedInt32Array()
var _band_shown: Node2D = null


## The theme of an arena: meta `sudden` when it names one, else by its biome (Stampede when unknown).
static func theme_of(meta: Dictionary) -> StringName:
	var named: StringName = StringName(str(meta.get("sudden", "")))
	if THEMES.has(named):
		return named
	return THEME_OF_BIOME.get(str(meta.get("biome", "jungle")), STAMPEDE)


## True when `p_theme` is one of the band themes (lava, tar, tide, syrup).
static func is_band(p_theme: StringName) -> bool:
	return p_theme in [LAVA_RISE, TAR_RISE, HIGH_TIDE, SYRUP_FLOOD]


func _init(referee: Object, level: LevelBase) -> void:
	_referee = referee
	_level = level


## Start `p_theme` now (Events.round_sudden_death_started is the referee's).
func start(p_theme: StringName) -> void:
	theme = p_theme
	ticks = 0
	_count = 0
	threats.clear()
	band_top = -1
	band_warn_tick = -1
	band_step_tick = -1
	wind = 0
	wind_at = -1
	if is_band(theme):
		band_top = VersusArena.view_rect().end.y
		band_top_v16 = band_top * 16
		var rumble: int = TIDE_RUMBLE_TICKS if theme == HIGH_TIDE else BAND_RUMBLE_TICKS
		band_warn_tick = Sim.tick
		band_step_tick = Sim.tick + rumble
		_note("band", band_warn_tick, band_step_tick)
		_rumble()
		_show_band()
	if theme == CAVE_IN:
		_cave_cols = _cave_order()
	if theme == WHITEOUT:
		_announce_wind()


## Stop everything (round over): the wind calms, the band stays drawn but harmless.
func stop() -> void:
	if theme == WHITEOUT and _level != null:
		_level.set_wind(0)
	theme = &""


func is_running() -> bool:
	return theme != &""


## One WORLD step.
func tick() -> void:
	if theme == &"" or _level == null:
		return
	match theme:
		STAMPEDE:
			if ticks % VersusTuning.STAMPEDE_PERIOD_TICKS == 0:
				_charger()
		CAVE_IN:
			if ticks % VersusTuning.CAVE_IN_PERIOD_TICKS == 0:
				_cave_block()
		WHITEOUT:
			if Sim.tick >= wind_at and wind_at >= 0:
				wind = wind_next
				_level.set_wind(wind)
				_announce_wind()
		LAVA_RISE, TAR_RISE, SYRUP_FLOOD:
			_band_steps()
		HIGH_TIDE:
			if Sim.tick >= band_step_tick:
				band_top_v16 -= TIDE_RISE_V16
				band_top = band_top_v16 >> 4
		STALACTITE_STORM:
			if ticks % STALACTITE_PERIOD_TICKS == 0:
				_stalactite()
		ROCKSLIDE:
			if ticks % ROCKSLIDE_PERIOD_TICKS == 0:
				_boulder()
		LIGHTNING:
			if ticks % LIGHTNING_PERIOD_TICKS == 0:
				_bolt()
	ticks += 1
	if _band_shown != null and is_instance_valid(_band_shown):
		_band_shown.queue_redraw()


## What the band does to `hero` this tick: &"" nothing, &"kill" (his feet under a deadly band), &"slow" (syrup).
func band_effect(hero: PlayerBase) -> StringName:
	if band_top < 0 or hero == null:
		return &""
	if hero.sim_pos.y <= band_top + (0 if theme == SYRUP_FLOOD else BAND_DEPTH_PX):
		return &""
	return &"slow" if theme == SYRUP_FLOOD else &"kill"


# --- Threats ----------------------------------------------------------------------------------------------------

func _charger() -> void:
	var view: Rect2i = VersusArena.view_rect()
	var from_left: bool = _count % 2 == 0
	var floor_y: int = _floor_y()
	var x: int = view.position.x - 16 if from_left else view.end.x + 16
	var dust: Rect2i = Rect2i(view.position.x if from_left else view.end.x - 48, floor_y - 12, 48, 12)
	var hazard: VersusHazard = _spawn(VersusHazard.CHARGER, Vector2i(x, floor_y), STAMPEDE_DUST_TICKS, dust)
	hazard.xvel = VersusHazard.CHARGER_XVEL if from_left else -VersusHazard.CHARGER_XVEL
	hazard.facing = 1 if from_left else -1


func _cave_block() -> void:
	if _cave_cols.is_empty():
		return
	var col: int = _cave_cols[_count % _cave_cols.size()]
	var landing: int = _first_ground_y(col, 0)
	if landing <= Tuning.TILE * 2:
		_count += 1   # this column is full up to the HUD rows: the next one
		return
	var x: int = col * Tuning.TILE + Tuning.TILE / 2
	_spawn(VersusHazard.BLOCK, Vector2i(x, Tuning.TILE), CAVE_IN_SHADOW_TICKS,
			Rect2i(col * Tuning.TILE, landing - 4, Tuning.TILE, 4))


func _stalactite() -> void:
	var view: Rect2i = VersusArena.view_rect()
	var col: int = 1 + Sim.rng.next_int(view.size.x / Tuning.TILE - 2)
	var x: int = col * Tuning.TILE + Tuning.TILE / 2
	_spawn(VersusHazard.STALACTITE, Vector2i(x, Tuning.TILE + 4), STALACTITE_RATTLE_TICKS,
			Rect2i(col * Tuning.TILE, Tuning.TILE - 8, Tuning.TILE, 8))


func _boulder() -> void:
	var view: Rect2i = VersusArena.view_rect()
	var from_left: bool = Sim.rng.next_int(2) == 0
	var x: int = view.position.x + 12 if from_left else view.end.x - 12
	var y: int = Tuning.TILE * 2
	var hazard: VersusHazard = _spawn(VersusHazard.BOULDER, Vector2i(x, y), ROCKSLIDE_DUST_TICKS,
			Rect2i(x - 16, y - 24, 32, 24))
	hazard.xvel = VersusHazard.BOULDER_XVEL if from_left else -VersusHazard.BOULDER_XVEL


func _bolt() -> void:
	var view: Rect2i = VersusArena.view_rect()
	var col: int = 1 + Sim.rng.next_int(view.size.x / Tuning.TILE - 2)
	var ground: int = _first_ground_y(col, 1)
	var x: int = col * Tuning.TILE + Tuning.TILE / 2
	_spawn(VersusHazard.BOLT, Vector2i(x, ground), LIGHTNING_MARK_TICKS,
			Rect2i(col * Tuning.TILE, view.position.y, Tuning.TILE, ground - view.position.y))


func _band_steps() -> void:
	if band_step_tick >= 0 and Sim.tick >= band_step_tick:
		var top_limit: int = SYRUP_TOP_ROW * Tuning.TILE if theme == SYRUP_FLOOD else Tuning.TILE
		if band_top - Tuning.TILE >= top_limit:
			band_top -= Tuning.TILE
			band_top_v16 = band_top * 16
		band_step_tick = -1
	if band_step_tick < 0 and ticks % BAND_ROW_TICKS == BAND_ROW_TICKS - BAND_RUMBLE_TICKS:
		band_warn_tick = Sim.tick
		band_step_tick = Sim.tick + BAND_RUMBLE_TICKS
		_note("band", band_warn_tick, band_step_tick)
		_rumble()


func _announce_wind() -> void:
	var step: int = mini(_count + 1, 16)
	var side: int = 1 if step % 2 == 1 else -1
	wind_next = WHITEOUT_STEP * step * side
	wind_warn_tick = Sim.tick
	wind_at = Sim.tick + (VersusTuning.WHITEOUT_STEP_TICKS if _count > 0 else WHITEOUT_WARN_TICKS)
	_note("wind", wind_warn_tick, wind_at)
	_count += 1


# --- Helpers -----------------------------------------------------------------------------------------------------

func _spawn(kind: StringName, pos: Vector2i, warn: int, mark: Rect2i) -> VersusHazard:
	var hazard: VersusHazard = VersusHazard.new().setup(kind, warn, _referee, mark)
	hazard.cause = &"sudden_death"
	hazard.spawn_setup(pos, {})
	_level.get_container("fx").add_child(hazard)
	_note(String(kind), Sim.tick, Sim.tick + warn)
	_count += 1
	return hazard


func _note(what: String, warn: int, strike: int) -> void:
	threats.append({"what": what, "warn": warn, "strike": strike})


## The rumble before a band step: the quake cue only - a screen shake would nudge the heroes (PHYSICS.md 13.3).
func _rumble() -> void:
	if AudioTable.SFX.has(Sfx.QUAKE):
		Audio.play_sfx(Sfx.QUAKE)


## The floor's top under the arena's middle (logical px): the first ground under row 1 at the view's centre column.
func _floor_y() -> int:
	return _first_ground_y(VersusArena.view_rect().get_center().x >> 4, 1)


## Feet y of the first ground cell in `col` at or below `from_row` (the view bottom when there is none).
func _first_ground_y(col: int, from_row: int) -> int:
	var view: Rect2i = VersusArena.view_rect()
	for row: int in range(maxi(from_row, 0), _level.grid.rows):
		if TileGrid.is_ground(_level.grid.floor_at(col, row)):
			return row * Tuning.TILE
	return view.end.y


## Cave-in columns from the edges inward: 0, 19, 1, 18, ...
func _cave_order() -> PackedInt32Array:
	var result: PackedInt32Array = PackedInt32Array()
	var cols: int = VersusArena.view_rect().size.x / Tuning.TILE
	for i: int in cols / 2:
		result.append(i)
		result.append(cols - 1 - i)
	return result


## The band is drawn by a small node of the level (presentation only).
func _show_band() -> void:
	if _level == null or DisplayServer.get_name() == "headless":
		return
	var node: VersusBandView = VersusBandView.new()
	node.sudden_death = self
	_level.add_child(node)
	_band_shown = node


## Draws the rising band (presentation only).
class VersusBandView:
	extends Node2D

	var sudden_death: VersusSuddenDeath = null

	func _ready() -> void:
		z_index = Defs.Z_FX

	func _draw() -> void:
		if sudden_death == null or sudden_death.band_top < 0:
			return
		var colors: Dictionary = {
			VersusSuddenDeath.LAVA_RISE: Color(1.0, 0.35, 0.05, 0.85),
			VersusSuddenDeath.TAR_RISE: Color(0.12, 0.1, 0.08, 0.9),
			VersusSuddenDeath.HIGH_TIDE: Color(0.2, 0.45, 0.85, 0.75),
			VersusSuddenDeath.SYRUP_FLOOD: Color(0.85, 0.5, 0.2, 0.7),
		}
		var color: Color = colors.get(sudden_death.theme, Color(1.0, 0.35, 0.05, 0.85))
		var view: Rect2i = VersusArena.view_rect()
		var top: float = float(sudden_death.band_top * Tuning.ART_SCALE)
		draw_rect(Rect2(Vector2(float(view.position.x * Tuning.ART_SCALE), top),
				Vector2(float(view.size.x * Tuning.ART_SCALE), float(view.end.y * Tuning.ART_SCALE) - top + 32.0)),
				color)
