class_name Painting
extends CollectibleBase
## `items/painting` (`index` 0..29): a Cave Painting fragment, the 2.0 meta-goal (DESIGN.md C.9, GAMEPLAY.md 13.7).
## Indices 0-19 are the Book II levels (one per level, the same index in its solo and co-op file), 20-29 lie behind an
## x2 secret in ten Book I co-op files. Each pays Tuning.PAINTING_POINTS and counts for completion like any placed
## bonus item; the find is recorded profile-wide across modes (Save.add_painting) and announced with
## Events.painting_found(index). A fragment found before (in any run or mode) shows as an outline and pays its points
## again without counting twice (Save.add_painting returns false for it).
##
## Owner: objects-B (docs/expansion/PLAN.md 4.1). A key item: a dropped copy (out of a big spot, content token
## `painting:<index>`) never blinks away and comes back when it falls into a pit. No sheet exists yet (art-A,
## wf7_objects-B_to_art-A.txt): the fragment is drawn in [method _draw] - a sandstone flake with an ochre figure.

## Sandstone flake (art px around the feet point, 2 art px = 1 logical px).
const FLAKE: PackedVector2Array = [
	Vector2(-13, 0), Vector2(-15, -14), Vector2(-9, -27), Vector2(3, -30), Vector2(13, -24), Vector2(15, -9),
	Vector2(10, 0),
]
const STONE_COLOR: Color = Color(0.80, 0.62, 0.43)
const STONE_DARK: Color = Color(0.47, 0.31, 0.20)
const OCHRE: Color = Color(0.66, 0.18, 0.10)
## Outline look of a fragment found before: the flake drawn as a faint rim only.
const FOUND_ALPHA: float = 0.45

## True when this fragment was already in the save when the level spawned it (drawn as an outline).
var found_before: bool = false
## True when collecting it added a new painting to the save (false for a fragment found before).
var was_new: bool = false

var _lift_art: float = 0.0


func _init() -> void:
	super()
	item_id = &"items/painting"
	expires = false
	pickup_sfx = Sfx.PICKUP_BIG
	points = Tuning.PAINTING_POINTS
	set_box(Vector3i(16, 16, 8))


func _apply_params(params: Dictionary) -> void:
	super._apply_params(params)
	if index < 0 or index >= Tuning.PAINTING_COUNT:
		push_warning("items/painting: index %d is outside 0..%d" % [index, Tuning.PAINTING_COUNT - 1])
		index = clampi(index, 0, Tuning.PAINTING_COUNT - 1)
	if not params.has("points"):
		points = Tuning.PAINTING_POINTS
	found_before = Save.has_painting(index)
	queue_redraw()


func _apply(_hero: PlayerBase) -> bool:
	was_new = Save.add_painting(index)
	Events.painting_found.emit(index)
	return true


## No sheet: [method _draw] shows the fragment; the bob only lifts the drawing.
func _update_look() -> void:
	queue_redraw()


func _bob_tick() -> void:
	var lift: float = float(ObjTuning.BOB_ART[(age + (sim_pos.x >> 4) * 3) % ObjTuning.BOB_ART.size()])
	if lift != _lift_art:
		_lift_art = lift
		queue_redraw()


func _draw() -> void:
	var lifted: PackedVector2Array = PackedVector2Array()
	for point: Vector2 in FLAKE:
		lifted.append(point + Vector2(0.0, -_lift_art))
	if found_before:
		var rim: PackedVector2Array = lifted.duplicate()
		rim.append(lifted[0])
		draw_polyline(rim, Color(STONE_COLOR, FOUND_ALPHA), 2.0)
		return
	draw_colored_polygon(lifted, STONE_COLOR)
	var rim: PackedVector2Array = lifted.duplicate()
	rim.append(lifted[0])
	draw_polyline(rim, STONE_DARK, 2.0)
	# A little running figure (head, body, legs, spear arm) in ochre.
	var o: Vector2 = Vector2(0.0, -_lift_art)
	draw_rect(Rect2(o + Vector2(-2, -24), Vector2(4, 4)), OCHRE)
	draw_line(o + Vector2(0, -20), o + Vector2(0, -12), OCHRE, 2.0)
	draw_line(o + Vector2(0, -12), o + Vector2(-5, -5), OCHRE, 2.0)
	draw_line(o + Vector2(0, -12), o + Vector2(5, -5), OCHRE, 2.0)
	draw_line(o + Vector2(-6, -19), o + Vector2(8, -17), OCHRE, 2.0)
	draw_rect(Rect2(o + Vector2(8, -19), Vector2(3, 3)), OCHRE)
