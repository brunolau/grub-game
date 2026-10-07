class_name VersusStackDisplay
extends Node2D
## Grub Stack's stack display (DESIGN.md E.3, GAMEPLAY.md 13.10.3): over every hero's head a wobbling tower of food
## pictures that IS his score - one picture per unit up to VersusTuning.STACK_PICTURES_MAX units, above that regrouped
## into 10s, 5s and 1s so it never leaves the screen - and the crown on the tallest stack. Owner: world-B
## (docs/expansion/PLAN.md P1.7). Presentation only: it reads the [VersusReferee] every frame and is never part of the
## simulation (the referee adds it to the level outside headless runs).
##
## Art (ASSET_MANIFEST 17.11, art-A): assets/ui/stack_food.png - 32 x 28 cells, pivot (16, 28) = the picture's foot;
## cell 0 = 1 unit, 1 = 2, 2 = 5, 3 = 10 - and assets/ui/crown.png (32 x 24 cells, pivot (16, 22)). The first
## picture's foot sits 4 art px below the head top (about 57 art px over the feet), then one every 14 art px up.

## Pictures drawn at most per tower.
const TOWER_MAX: int = 12
const STACK_SHEET: String = "res://assets/ui/stack_food.png"
const CROWN_SHEET: String = "res://assets/ui/crown.png"
const CELL: Vector2i = Vector2i(32, 28)
const PIVOT: Vector2 = Vector2(16.0, 28.0)
const CROWN_CELL: Vector2i = Vector2i(32, 24)
const CROWN_PIVOT: Vector2 = Vector2(16.0, 22.0)
## Art px from the feet up to the first picture's foot, and between two pictures.
const FIRST_FOOT_ART: float = 53.0
const STEP_ART: float = 14.0
## Wobble: art px of sideways sway per picture of height, and its speed.
const WOBBLE_ART: float = 0.6
const WOBBLE_SPEED: float = 5.0
## Sheet cell of a picture by its unit value.
const CELL_OF_VALUE: Dictionary = {1: 0, 2: 1, 5: 2, 10: 3}
const CROWN_COLOR: Color = Color(1.0, 0.82, 0.2)

## The referee whose stacks are drawn (set by the referee when it adds this node).
var referee: VersusReferee = null

var _time: float = 0.0
var _food: Texture2D = null
var _crown: Texture2D = null


## The pictures of a stack of `units`, bottom first, as unit values (1, 5 or 10): one per unit up to
## VersusTuning.STACK_PICTURES_MAX units, else the greedy split into 10s, 5s and 1s (biggest at the bottom).
static func tower_pictures(units: int) -> PackedInt32Array:
	var result: PackedInt32Array = PackedInt32Array()
	if units <= 0:
		return result
	if units <= VersusTuning.STACK_PICTURES_MAX:
		for i: int in units:
			result.append(VersusTuning.FOOD_SMALL)
		return result
	var left: int = units
	for value: int in [VersusTuning.FOOD_GIANT, VersusTuning.FOOD_TREASURE, VersusTuning.FOOD_SMALL]:
		while left >= value:
			result.append(value)
			left -= value
	return result


func _ready() -> void:
	z_index = Defs.Z_FX
	if ResourceLoader.exists(STACK_SHEET):
		_food = load(STACK_SHEET) as Texture2D
	if ResourceLoader.exists(CROWN_SHEET):
		_crown = load(CROWN_SHEET) as Texture2D


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	if referee == null or not is_instance_valid(referee) or referee.level == null \
			or referee.mode != Defs.VersusMode.GRUB_STACK:
		return
	var leader: int = referee.leader_slot()
	for hero: PlayerBase in referee.level.heroes:
		if hero == null or not is_instance_valid(hero) or hero.dead or not hero.visible:
			continue
		var foot: Vector2 = hero.position - Vector2(0.0, FIRST_FOOT_ART)
		var pictures: PackedInt32Array = tower_pictures(referee.stack_of(hero.slot))
		var count: int = mini(pictures.size(), TOWER_MAX)
		for i: int in count:
			var sway: float = sin(_time * WOBBLE_SPEED + float(hero.slot)) * WOBBLE_ART * float(i)
			_draw_picture(pictures[i], foot + Vector2(sway, -STEP_ART * float(i)))
		if hero.slot == leader:
			_draw_crown(foot + Vector2(0.0, -STEP_ART * float(count) - 10.0))


func _draw_picture(value: int, at: Vector2) -> void:
	if _food == null:
		draw_circle(at - Vector2(0.0, 8.0), 6.0, Color(0.9, 0.55, 0.2) if value == 1 else Color(1.0, 0.85, 0.3))
		return
	var cell: int = int(CELL_OF_VALUE.get(value, 0))
	var source: Rect2 = Rect2(Vector2(float(cell * CELL.x), 0.0), Vector2(CELL))
	draw_texture_rect_region(_food, Rect2(at - PIVOT, Vector2(CELL)), source)


func _draw_crown(at: Vector2) -> void:
	if _crown != null:
		draw_texture_rect_region(_crown, Rect2(at - CROWN_PIVOT, Vector2(CROWN_CELL)),
				Rect2(Vector2.ZERO, Vector2(CROWN_CELL)))
		return
	var points: PackedVector2Array = PackedVector2Array([
		at + Vector2(-9, 4), at + Vector2(-9, -4), at + Vector2(-4, 0), at + Vector2(0, -7), at + Vector2(4, 0),
		at + Vector2(9, -4), at + Vector2(9, 4),
	])
	draw_colored_polygon(points, CROWN_COLOR)
