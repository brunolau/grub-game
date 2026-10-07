class_name RisingTide
extends Node2D
## The rising tide of `scroll = rising` (docs/spec/PHYSICS.md C.8, DESIGN.md C.6; 6-2b, the Tar Pulleys and Cinder
## Pit sudden deaths). Owner: world-A.
##
## Gameplay state in logical px, run by Level once per tick (phase WORLD, [method tick]): the deadly band's top
## [member band_top] starts PartyTuning-free at Tuning.RISE_CHECKPOINT_ROWS rows under the start point (after a
## respawn under the checkpoint used), waits for the first tick with any hero input (the 4-1 rule), then rises by
## `rise_speed` v16 per tick (`band_top = band_top0 - floor16(acc)`). A hero whose feet are below it dies (cause
## liquid; in co-op the death toss ends in an egg while the partner plays, PartyDriver), awake enemies whose feet
## pass it vanish with a splash (no points, as in a liquid), dropped items below it are removed. A
## `zones/autoscroll_stop` stops the rise for the rest of the stage ([method stop]): the band stays and stays deadly.
## The camera keeps the band in view (LevelCamera.apply_rising, Level). The node draws the band with the level's
## liquid strip from its top to the bottom of the view (presentation only; interpolated between ticks).

## The splash of something sinking into a sticky band is the water splash in the liquid's colour (6-2b's tar).
const STICKY_TINTS: Dictionary = {
	"tar": Color(0.42, 0.32, 0.55), "honey": Color(1.0, 0.72, 0.25), "syrup": Color(0.9, 0.3, 0.42),
}
## Body cells with bubbles (LevelTiles cell 7 of the strip): one body cell in this many shows them.
const BUBBLE_ONE_IN: int = 5

## The band's top (world y, logical px) at the end of this tick.
var band_top: int = 0
## Where the band started at the last (re)start: `band_top = start_top - floor16(acc)`.
var start_top: int = 0
## Accumulated rise, v16.
var acc: int = 0
## v16 per tick (meta `rise_speed`, Tuning.RISE_SPEED = 1 px/tick).
var rise_speed: int = Tuning.RISE_SPEED
## True once a hero's input started the rise (cleared by every restart).
var started: bool = false
## True once a `zones/autoscroll_stop` stopped the rise (kept through respawns: "for the rest of the stage").
var stopped: bool = false

var _prev_top: int = 0
var _texture: Texture2D = null
var _time: float = 0.0
var _view: Rect2 = Rect2()


## Arm the band for a level: its liquid strip (Texture of 8 x 1 cells of 32 art px, LevelTiles layout), the rise speed
## and the start (feet y of the start point or of the checkpoint used).
func setup(strip: Texture2D, speed: int, feet_y: int) -> void:
	_texture = strip
	rise_speed = speed
	z_index = Defs.Z_FRONT_TILES + 2
	restart(feet_y)


## Back to Tuning.RISE_CHECKPOINT_ROWS rows under `feet_y`, waiting for the first input again (a respawn).
func restart(feet_y: int) -> void:
	start_top = feet_y + Tuning.RISE_CHECKPOINT_ROWS * Tuning.TILE
	band_top = start_top
	_prev_top = band_top
	acc = 0
	started = false


## The rise stops for the rest of the stage (`zones/autoscroll_stop`); the band stays where it is.
func stop() -> void:
	stopped = true


## True while the band rises (started by an input, not stopped): the camera then keeps it in view.
func is_rising() -> bool:
	return started and not stopped


## One tick (phase WORLD). `any_input` = some hero's input of this tick is held.
func tick(level: LevelBase, any_input: bool) -> void:
	_prev_top = band_top
	if not started and any_input and not stopped:
		started = true
	if started and not stopped:
		acc += rise_speed
		band_top = start_top - Tuning.floor16(acc)
	if level == null:
		return
	for hero: PlayerBase in level.contact_order():
		if not hero.dead and not hero.is_down() and hero.sim_pos.y > band_top:
			hero.kill(&"liquid")
	var enemies: Array[SimEntity] = level.get_kind(Defs.Kind.ENEMY)
	for i: int in range(enemies.size() - 1, -1, -1):
		var enemy: EnemyBase = enemies[i] as EnemyBase
		if enemy != null and enemy.awake and not enemy.dead and enemy.sim_pos.y > band_top:
			_splash(level, Vector2i(enemy.sim_pos.x, band_top))
			enemy.sleep()
	var items: Array[SimEntity] = level.get_kind(Defs.Kind.COLLECTIBLE)
	for i: int in range(items.size() - 1, -1, -1):
		var item: CollectibleBase = items[i] as CollectibleBase
		if item != null and item.dropped and not item.collected and item.sim_pos.y > band_top \
				and not item.is_queued_for_deletion():
			item.queue_free()


## Something sank into the band at `at`: the splash of the level's liquid - lava's own, the water splash otherwise,
## tinted and with the glug for the sticky liquids (tar in 6-2b, honey, syrup). Presentation and audio only.
static func _splash(level: LevelBase, at: Vector2i) -> void:
	var liquid: String = str(level.meta.get("liquid", ""))
	if Spawner.exists(&"fx/splash"):
		var fx: Node = level.spawn_fx(&"fx/splash", at, {"kind": "lava" if liquid == "lava" else "water"})
		if fx is CanvasItem and STICKY_TINTS.has(liquid):
			(fx as CanvasItem).modulate = STICKY_TINTS[liquid]
	if STICKY_TINTS.has(liquid):
		Audio.play_sfx(Sfx.TAR_GLUG)


## Presentation: the band from its interpolated top to the bottom of `view` (logical px).
func draw_band(view: Rect2, delta: float) -> void:
	_view = view
	_time += delta
	queue_redraw()


func _draw() -> void:
	if _texture == null or _view.size.x <= 0.0:
		return
	var tile: float = float(Tuning.TILE_ART)
	var top: float = lerpf(float(_prev_top), float(band_top), Sim.alpha) * Tuning.ART_SCALE
	var bottom: float = (_view.position.y + _view.size.y) * Tuning.ART_SCALE + tile
	if top >= bottom:
		return
	var left: float = floorf(_view.position.x * Tuning.ART_SCALE / tile) * tile
	var right: float = (_view.position.x + _view.size.x) * Tuning.ART_SCALE + tile
	var frame: int = int(_time * 8.0) % LevelTiles.LIQUID_SURFACE_FRAMES
	var x: float = left
	while x < right:
		var surface: Rect2 = Rect2(float(LevelTiles.LIQUID_SURFACE + (frame + int(x / tile)) % LevelTiles.LIQUID_SURFACE_FRAMES) * tile,
				0.0, tile, tile)
		draw_texture_rect_region(_texture, Rect2(x, top, tile, tile), surface)
		var y: float = top + tile
		while y < bottom:
			# Body cells, some with bubbles (fixed by their world cell, as the tile layer does for a pool).
			var body: int = LevelTiles.LIQUID_BODY_BUBBLES \
					if LevelTiles.cell_hash(int(x / tile), int(floorf(y / tile))) % BUBBLE_ONE_IN == 0 \
					else LevelTiles.LIQUID_BODY
			draw_texture_rect_region(_texture, Rect2(x, y, tile, tile), Rect2(float(body) * tile, 0.0, tile, tile))
			y += tile
		x += tile
