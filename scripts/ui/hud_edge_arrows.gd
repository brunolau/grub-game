class_name HudEdgeArrows
extends Control
## Edge arrows of a party (DESIGN.md D.2 / E.9, GAMEPLAY.md 13.9.2): a hero outside the view gets an arrow in his
## colour at the view edge nearest to him (`ui/player_arrows.png`), and while the co-op leash counts
## (`PlayerBase.leash`, PHYSICS.md C.13) a carved stone beside it counts down the seconds until he turns into an egg
## (`ui/countdown_stones.png`: 5..1 on Beginner, 3..1 on Expert). On a view wider than the authentic one a hero can be
## on the screen and still off the authentic view: then the stone hangs over his head instead.
##
## Owner: ui-B. Part of [Hud]; draws nothing for a party of one (single-player keeps the 1.0 HUD). It reads only the
## documented hero fields (`slot`, `leash`, `dead`, `down`, the canvas position, `box_h`) of `Game.level` - the
## exception ARCHITECTURE.md 3.12 names for the HUD's edge arrow.

## Distance of an arrow's centre from the view edge (art px).
const INSET: float = 22.0
## Gap between an arrow and its stone (art px), towards the middle of the view.
const STONE_GAP: float = 30.0
## Height of the stone over a visible hero's head (art px).
const HEAD_GAP: float = 18.0

## What was drawn last frame, for tests and previews: one Dictionary per marker {slot, side (UiPlayers.Side, -1 = over
## the hero), pos (Vector2, arrow centre or stone foot), digit (0 = no stone)}.
var markers: Array[Dictionary] = []

## Level to watch instead of Game.level (tests, previews).
var level_override: LevelBase = null

var _arrows: Dictionary = {}   # slot * 4 + side -> AtlasTexture (kept while drawn, UiKit.tex note)
var _stones: Array[AtlasTexture] = []


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for digit: int in range(1, UiPlayers.STONE_MAX + 1):
		_stones.append(UiPlayers.stone(digit))


func _process(_delta: float) -> void:
	update_markers()


## Recompute the markers from the heroes of the level now and redraw.
func update_markers() -> void:
	var found: Array[Dictionary] = []
	var level: LevelBase = level_override if level_override != null else Game.level
	if level != null and is_instance_valid(level) and level.hero_count() > 1:
		var view: Rect2 = get_viewport_rect()
		var limit: int = PartyTuning.leash_egg_ticks(Game.difficulty)
		for hero: PlayerBase in level.heroes:
			if hero == null or not is_instance_valid(hero) or not hero.is_inside_tree() or hero.dead or hero.down:
				continue
			var marker: Dictionary = _marker_for(hero, view, limit)
			if not marker.is_empty():
				found.append(marker)
	if found != markers:
		markers = found
		queue_redraw()


func _draw() -> void:
	for marker: Dictionary in markers:
		var slot: int = int(marker["slot"])
		var side: int = int(marker["side"])
		var pos: Vector2 = marker["pos"]
		var digit: int = int(marker["digit"])
		if side < 0:
			if digit > 0:
				var stone: Texture2D = _stones[digit - 1]
				draw_texture(stone, (pos - Vector2(16.0, 32.0)).round())
			continue
		var arrow: Texture2D = _arrow(slot, side)
		draw_texture(arrow, (pos - Vector2(16.0, 16.0)).round())
		if digit > 0:
			var stone_centre: Vector2 = pos + _inward(side) * STONE_GAP
			draw_texture(_stones[digit - 1], (stone_centre - Vector2(16.0, 16.0)).round())


## The marker of one hero, or {} when he needs none.
func _marker_for(hero: PlayerBase, view: Rect2, limit: int) -> Dictionary:
	var feet: Vector2 = hero.get_global_transform_with_canvas().origin
	var height: float = float(hero.box_h * Tuning.ART_SCALE)
	var middle: Vector2 = feet - Vector2(0.0, height * 0.5)
	var digit: int = UiPlayers.leash_digit(hero.leash, limit)
	var side: int = _side_off(middle, view)
	if side < 0:
		if digit <= 0:
			return {}
		return {"slot": hero.slot, "side": -1, "pos": feet - Vector2(0.0, height + HEAD_GAP), "digit": digit}
	var inner: Rect2 = view.grow(-INSET)
	var pos: Vector2 = Vector2(clampf(middle.x, inner.position.x, inner.end.x),
			clampf(middle.y, inner.position.y, inner.end.y))
	return {"slot": hero.slot, "side": side, "pos": pos, "digit": digit}


## The side of `view` that `point` is beyond (UiPlayers.Side), or -1 when it is inside.
static func _side_off(point: Vector2, view: Rect2) -> int:
	if point.x < view.position.x:
		return UiPlayers.Side.LEFT
	if point.x > view.end.x:
		return UiPlayers.Side.RIGHT
	if point.y < view.position.y:
		return UiPlayers.Side.UP
	if point.y > view.end.y:
		return UiPlayers.Side.DOWN
	return -1


static func _inward(side: int) -> Vector2:
	match side:
		UiPlayers.Side.LEFT:
			return Vector2.RIGHT
		UiPlayers.Side.RIGHT:
			return Vector2.LEFT
		UiPlayers.Side.UP:
			return Vector2.DOWN
	return Vector2.UP


func _arrow(slot: int, side: int) -> Texture2D:
	var key: int = slot * 4 + side
	if not _arrows.has(key):
		_arrows[key] = UiPlayers.arrow(slot, side)
	return _arrows[key]
