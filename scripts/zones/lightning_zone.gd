class_name LightningZone
extends ZoneBase
## `zones/lightning rect=c,r,w,h period=<ticks> [delay=<ticks>] [mark=22]` (docs/spec/PHYSICS.md C.6, DESIGN.md R5;
## 9-1b Thunderhead Glide, the Cloud Top arena, the Storm Roc's sky): while a hero is inside the rectangle, every
## `period` ticks a darkening cloud marks the column of a hero's feet; `mark` ticks later a bolt fills that 16 px column
## inside the rectangle for BOLT_TICKS (4) ticks and a hero touching it is hurt as by an enemy contact
## (PlayerBase.hurt, Defs.HurtKind.ENEMY: a glider is lost instead of a heart, PHYSICS.md 10.1). Owner: world-A.
##
## Timing (integer, deterministic, doze-safe): a strike clock counts the ticks on which some hero's feet are inside
## (it starts at -`delay` when the first hero enters an empty zone); at `period` it marks a strike and starts again.
## The column is that of the TARGET: the heroes inside take turns in slot order (GAMEPLAY.md 13.9.4: "zone spawners
## alternate between the heroes inside"; one hero: always him). A marked strike runs to its end even when everybody
## left. The zone never dozes while a hero is inside or a strike is pending. A level reset (respawn, team wipe) clears
## every strike. Eggs and dead heroes are neither targeted nor struck (C.12).
##
## The struck nest cells of the Storm Roc (`skin=nest`, burn 66 ticks) are the boss's (enemies-C), not this zone's.
## Presentation: the cloud darkens over the column through the warning (drawn at the top of the rectangle), the bolt
## is a jagged white-gold line down the column with a flash; the crack plays on the first bolt tick.

## Defaults (PHYSICS.md C.6 / C.16: mark 22, bolt 4 ticks, both *(tune)*; C.16 lists them under ObjTuning, objects-A's
## table - they move there when objects-A adds the rows, wf8_world_a_to_objects_a.txt).
const MARK_TICKS: int = 22
const BOLT_TICKS: int = 4
const DEFAULT_PERIOD: int = 66
## Colours of the warning cloud, the bolt (core and edge) and the flash over the struck column.
const CLOUD_COLOR: Color = Color(0.18, 0.17, 0.26, 0.85)
const BOLT_COLOR: Color = Color(1.0, 0.97, 0.7, 1.0)
const BOLT_EDGE_COLOR: Color = Color(1.0, 0.85, 0.35, 0.9)
const FLASH_COLOR: Color = Color(1.0, 1.0, 0.9, 0.18)
## A bolt is drawn in front of everything of the level.
const Z_LIGHTNING: int = Defs.Z_FRONT_TILES + 4

## Ticks between two strikes while a hero is inside.
var period: int = DEFAULT_PERIOD
## Ticks before the first strike after a hero enters an empty zone.
var delay: int = 0
## Ticks from the mark to the bolt.
var mark: int = MARK_TICKS
## Strikes marked so far (diagnostics, tests).
var marked: int = 0
## Pending strikes: Vector2i(column in cells, ticks since the mark - the bolt on mark .. mark + BOLT_TICKS - 1),
## oldest first.
var strikes: Array[Vector2i] = []

var _clock: int = 0
## The slot that was struck at last (the next strike looks for the next hero inside after it).
var _last_slot: int = -1
var _anim_time: float = 0.0
## True while the last frame drew something (one more redraw clears it).
var _drawn: bool = false


func _apply_params(params: Dictionary) -> void:
	super._apply_params(params)
	period = maxi(1, param_int("period", DEFAULT_PERIOD))
	delay = maxi(0, param_int("delay", 0))
	mark = maxi(1, param_int("mark", MARK_TICKS))
	z_index = Z_LIGHTNING


func _sim_tick(phase: int) -> void:
	var was_inside: bool = inside
	super._sim_tick(phase)
	var level: LevelBase = Game.level
	if level == null:
		return
	if inside and not was_inside:
		_clock = -delay
	_advance_strikes(level)
	if not inside:
		return
	_clock += 1
	if _clock < period:
		return
	_clock = 0
	var target: PlayerBase = _next_target(level)
	if target == null:
		return
	_last_slot = target.slot
	strikes.append(Vector2i(Tuning.to_cell(target.sim_pos.x), 0))
	marked += 1


## Every pending strike ages one tick; a bolt (ticks mark .. mark + BOLT_TICKS - 1) hurts every living, hatched hero
## whose body box touches its column inside the rectangle; spent strikes go.
func _advance_strikes(level: LevelBase) -> void:
	for i: int in range(strikes.size() - 1, -1, -1):
		var strike: Vector2i = strikes[i]
		strike.y += 1
		strikes[i] = strike
		if strike.y >= mark + BOLT_TICKS:
			strikes.remove_at(i)
			continue
		if strike.y < mark:
			continue
		if strike.y == mark:
			Audio.play_sfx(Sfx.LIGHTNING_STRIKE)
		var column: Rect2i = column_rect(strike.x)
		for hero: PlayerBase in level.contact_order():
			if hero.dead or hero.is_down():
				continue
			if Overlap.rects(column, hero.get_box()):
				hero.hurt(self, Defs.HurtKind.ENEMY)


## The column `col` inside the rectangle, in logical px (where a bolt strikes).
func column_rect(col: int) -> Rect2i:
	return Rect2i(col * Tuning.TILE, rect.position.y, Tuning.TILE, rect.size.y)


## True while some strike of the column `col` is in its bolt ticks.
func is_bolt(col: int) -> bool:
	for strike: Vector2i in strikes:
		if strike.x == col and strike.y >= mark:
			return true
	return false


## The next hero inside after the one struck last (slot order, wrapping); null when nobody living and hatched is in.
func _next_target(level: LevelBase) -> PlayerBase:
	var first: PlayerBase = null
	for hero: PlayerBase in level.contact_order():
		if hero.dead or hero.is_down() or (inside_mask & (1 << hero.slot)) == 0:
			continue
		if first == null:
			first = hero
		if hero.slot > _last_slot:
			return hero
	return first


func _can_doze() -> bool:
	return not inside and strikes.is_empty()


func _on_level_reset() -> void:
	super._on_level_reset()
	strikes.clear()
	_clock = 0
	_last_slot = -1


# =================================================================================================================
# Presentation
# =================================================================================================================

func _process(delta: float) -> void:
	_anim_time += delta
	if not strikes.is_empty() or _drawn:
		_drawn = not strikes.is_empty()
		queue_redraw()


func _draw() -> void:
	var origin: Vector2 = position
	for strike: Vector2i in strikes:
		var column: Rect2i = column_rect(strike.x)
		var top_left: Vector2 = Tuning.to_art(Vector2(column.position)) - origin
		var width: float = float(Tuning.TILE_ART)
		if strike.y < mark:
			# The warning: a cloud over the column that darkens and grows as the bolt nears.
			var t: float = float(strike.y + 1) / float(mark)
			var puff: float = width * (0.6 + 0.6 * t)
			var cloud: Color = CLOUD_COLOR * Color(1.0, 1.0, 1.0, 0.35 + 0.65 * t)
			var cx: float = top_left.x + width * 0.5
			draw_rect(Rect2(cx - puff, top_left.y, puff * 2.0, 10.0), cloud)
			draw_rect(Rect2(cx - puff * 0.6, top_left.y + 10.0, puff * 1.2, 6.0), cloud)
			if strike.y >= mark - 6 and int(_anim_time * 20.0) % 2 == 0:
				draw_rect(Rect2(cx - 1.0, top_left.y + 16.0, 2.0, 4.0), BOLT_EDGE_COLOR)
			continue
		# The bolt: a jagged line through the column, re-jagged every bolt tick, and a flash over the column.
		var height: float = float(column.size.y * Tuning.ART_SCALE)
		draw_rect(Rect2(top_left, Vector2(width, height)), FLASH_COLOR)
		var x: float = top_left.x + width * 0.5
		var y: float = top_left.y
		var k: int = strike.x * 31 + strike.y * 7
		while y < top_left.y + height:
			var step: float = 10.0 + float(k % 3) * 4.0
			var nx: float = top_left.x + width * 0.5 + float((k % 5) - 2) * 3.0
			draw_line(Vector2(x, y), Vector2(nx, y + step), BOLT_EDGE_COLOR, 4.0)
			draw_line(Vector2(x, y), Vector2(nx, y + step), BOLT_COLOR, 2.0)
			x = nx
			y += step
			k = (k * 1103515245 + 12345) & 0x7FFFFFFF
