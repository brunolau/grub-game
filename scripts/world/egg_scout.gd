class_name EggScout
extends Node2D
## The egg scouts (DESIGN.md D.3, GAMEPLAY.md 13.9.2; PartyTuning.EGG_SCOUT_RADIUS_PX): every unopened hidden spot
## (`objects/hidden_spot`) within 2 tiles of an egg glints, so a downed player who nudges his egg along the walls keeps
## helping - he finds the secrets his partner then clubs open. Owner: world-A.
##
## Presentation only: Level adds one in a co-op party; it reads the heroes and the hidden spots in `_process` and
## draws a twinkling four-point star on each spot it finds. Nothing in the simulation reads it, an egg still touches
## nothing (C.12), and the glint opens nothing.

## Star colours: a warm white core and a pale gold ray, both bright in the night palette.
const CORE_COLOR: Color = Color(1.0, 0.98, 0.86, 0.95)
const RAY_COLOR: Color = Color(1.0, 0.9, 0.55, 0.85)
## Ray length in art px at the full twinkle, and the twinkle period in seconds.
const RAY_ART: float = 7.0
const TWINKLE_SECONDS: float = 0.9
## In front of the tiles and the props, as the hidden spot itself is scenery.
const Z_GLINT: int = Defs.Z_FRONT_TILES + 3

## Cells of the hidden spots glinting now (refreshed every frame).
var glinting: Array[Vector2i] = []

var _time: float = 0.0


func _init() -> void:
	z_index = Z_GLINT
	name = "EggScout"


## The cells of the unopened hidden spots of `level` within PartyTuning.EGG_SCOUT_RADIUS_PX of an egg's box
## (PartyTuning.EGG_BOX_* at its feet point): the gap between the spot's cell and the box is at most the radius on
## both axes. Each cell once, in spawn order. Empty while no hero is an egg.
static func spots_near_eggs(level: LevelBase) -> Array[Vector2i]:
	var found: Array[Vector2i] = []
	if level == null:
		return found
	var eggs: Array[Rect2i] = []
	for hero: PlayerBase in level.contact_order():
		if hero.is_down() and not hero.dead:
			eggs.append(Rect2i(hero.sim_pos.x - PartyTuning.EGG_BOX_XO, hero.sim_pos.y - PartyTuning.EGG_BOX_H,
					PartyTuning.EGG_BOX_W, PartyTuning.EGG_BOX_H).grow(PartyTuning.EGG_SCOUT_RADIUS_PX))
	if eggs.is_empty():
		return found
	var hittables: Array[SimEntity] = level.get_kind(Defs.Kind.HITTABLE)
	for i: int in hittables.size():
		var spot: HiddenSpot = hittables[i] as HiddenSpot
		if spot == null or spot.opened:
			continue
		var cell_rect: Rect2i = Rect2i(spot.cell * Tuning.TILE, Vector2i(Tuning.TILE, Tuning.TILE))
		for area: Rect2i in eggs:
			if area.intersects(cell_rect):
				found.append(spot.cell)
				break
	return found


func _process(delta: float) -> void:
	_time += delta
	var level: LevelBase = Game.level
	var now: Array[Vector2i] = spots_near_eggs(level)
	if now.is_empty() and glinting.is_empty():
		return
	glinting = now
	queue_redraw()


func _draw() -> void:
	for cell: Vector2i in glinting:
		# Each spot twinkles on its own phase (a fixed hash of its cell), so a wall of spots sparkles.
		var phase: float = float(LevelTiles.cell_hash(cell.x, cell.y) % 997) / 997.0
		var t: float = fposmod(_time / TWINKLE_SECONDS + phase, 1.0)
		var size: float = RAY_ART * (0.35 + 0.65 * absf(sin(t * PI)))
		var centre: Vector2 = Tuning.to_art(Vector2(cell * Tuning.TILE) + Vector2(Tuning.TILE, Tuning.TILE) * 0.5)
		centre = centre.round()
		draw_rect(Rect2(centre.x - size, centre.y - 1.0, size * 2.0, 2.0), RAY_COLOR)
		draw_rect(Rect2(centre.x - 1.0, centre.y - size, 2.0, size * 2.0), RAY_COLOR)
		var diag: float = floorf(size * 0.4)
		for k: int in range(1, int(diag) + 1):
			var d: float = float(k)
			for corner: Vector2 in [Vector2(d, d), Vector2(-d, d), Vector2(d, -d), Vector2(-d, -d)]:
				draw_rect(Rect2(centre + corner - Vector2(1.0, 1.0), Vector2(2.0, 2.0)), RAY_COLOR * Color(1, 1, 1, 0.6))
		draw_rect(Rect2(centre - Vector2(2.0, 2.0), Vector2(4.0, 4.0)), CORE_COLOR)
