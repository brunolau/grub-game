class_name HudEdgeArrows
extends Control
## Edge arrows of a party (DESIGN.md D.2 / E.9, GAMEPLAY.md 13.9.2): a hero outside the view gets an arrow in his
## colour at the view edge nearest to him (`ui/player_arrows.png`), and while the co-op leash counts
## (`PlayerBase.leash`, PHYSICS.md C.13) a carved stone beside it counts down the seconds until he turns into an egg
## (`ui/countdown_stones.png`: 5..1 on Beginner, 3..1 on Expert). On a view wider than the authentic one a hero can be
## on the screen and still off the authentic view: then the stone hangs over his head instead.
## The "P1".."P4" tags with their colour arrow (`ui/player_tags.png`, DESIGN.md D.1 / E.9) show over every hero for the
## first seconds of a stage, through a versus round's "3, 2, 1, GRUB!" and the first seconds of the round, and whenever
## two heroes overlap. In Grub Stack a tag stands on top of the hero's food tower (VersusStackDisplay), not in it.
## Tags never print into each other: tags whose cells would overlap (two heroes in one column) stand side by side,
## the heroes' order from left to right ([method spread_tags]).
## Tags and arrows wear the colour the player chose (UiPlayers.tag_cell / arrow_cell). A hero above the view without a
## countdown (versus) gets his head in a bubble under the arrow (ui/portrait_heads.png; DESIGN.md E.9 "bubbles for
## heroes above the view"). Every picture comes from [HudAtlas], the texture of the versus HUD, so the party HUD draws
## in one batch.
##
## Owner: ui-B. Part of [Hud]; draws nothing for a party of one (single-player keeps the 1.0 HUD). It reads only the
## documented hero fields (`slot`, `leash`, `dead`, `down`, the canvas position, `box_h`) of `Game.level` - the
## exception ARCHITECTURE.md 3.12 names for the HUD's edge arrow.

## Distance of an arrow's centre from the edge of the safe area (art px): half an arrow cell.
const INSET: float = 16.0
## Gap between an arrow and its stone (art px), towards the middle of the view.
const STONE_GAP: float = 30.0
## Height of the stone over a visible hero's head (art px).
const HEAD_GAP: float = 18.0
## Player tags: the sheet, its cells (32 x 48, pivot = the arrow tip at the bottom centre), how long they show when a
## stage starts, and their gap over a hero's head (art px).
const TEX_TAGS: String = "res://assets/ui/player_tags.png"
const TAG_CELL: Vector2i = Vector2i(32, 48)
const TAG_SECONDS: float = 3.0
const TAG_GAP: float = 4.0
## Two tags side by side change places only when one hero stands this far (screen px) on the other side of his
## neighbour: two heroes on one spot do not swap their tags with every pixel they shift.
const TAG_SWAP_PX: float = 12.0

## What was drawn last frame, for tests and previews: one Dictionary per marker {slot, side (UiPlayers.Side, -1 = over
## the hero), pos (Vector2, arrow centre or stone foot), digit (0 = no stone)}.
var markers: Array[Dictionary] = []
## Tags drawn last frame: one Dictionary per hero {slot, pos (Vector2, the arrow tip)}.
var tags: Array[Dictionary] = []

## Level to watch instead of Game.level (tests, previews).
var level_override: LevelBase = null

var _tags_until: int = 0
var _atlas: Texture2D = null
## The order of the tags that stood side by side last frame ([method spread_tags]).
var _tag_order: Dictionary = {}


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_atlas = HudAtlas.texture()
	show_tags(TAG_SECONDS)


func _ready() -> void:
	Events.level_started.connect(func(_level_id: StringName) -> void: show_tags(TAG_SECONDS))
	Events.level_respawned.connect(func() -> void: show_tags(TAG_SECONDS))
	Events.round_started.connect(func(_round_index: int) -> void: show_tags(TAG_SECONDS))
	# The countdown counts 1 s steps: each count keeps the tags up until the round starts and adds its own time.
	Events.round_countdown.connect(func(_round_index: int, _count: int) -> void: show_tags(TAG_SECONDS))


## Show every hero's tag for `seconds` from now (0 = only while heroes overlap).
func show_tags(seconds: float) -> void:
	_tags_until = Time.get_ticks_msec() + roundi(seconds * 1000.0)


func _process(_delta: float) -> void:
	update_markers()


## Recompute the markers from the heroes of the level now and redraw.
func update_markers() -> void:
	var found: Array[Dictionary] = []
	var found_tags: Array[Dictionary] = []
	var level: LevelBase = level_override if level_override != null else Game.level
	if level != null and is_instance_valid(level) and level.hero_count() > 1:
		var view: Rect2 = get_viewport_rect()
		var margins: Vector4i = UiKit.safe_margins(get_viewport())
		var inner: Rect2 = Rect2(view.position + Vector2(float(margins.x), float(margins.y)),
				view.size - Vector2(float(margins.x + margins.z), float(margins.y + margins.w))).grow(-INSET)
		var limit: int = PartyTuning.leash_egg_ticks(Game.difficulty)
		for hero: PlayerBase in level.heroes:
			if hero == null or not is_instance_valid(hero) or not hero.is_inside_tree() or hero.dead or hero.down:
				continue
			var marker: Dictionary = _marker_for(hero, view, inner, limit)
			if not marker.is_empty():
				found.append(marker)
		found_tags = _tags_for(level, view, found)
	_tag_order = spread_tags(found_tags, _tag_order)
	if found != markers or found_tags != tags:
		markers = found
		tags = found_tags
		queue_redraw()


## The tags of the heroes on the screen: all of them while the stage-start time runs, else those overlapping another
## hero; none over a hero who shows a marker.
func _tags_for(level: LevelBase, view: Rect2, shown: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var bodies: Dictionary = {}  # hero -> screen rect of his body
	for hero: PlayerBase in level.heroes:
		if hero == null or not is_instance_valid(hero) or not hero.is_inside_tree() or hero.dead or hero.down:
			continue
		var feet: Vector2 = hero.get_global_transform_with_canvas().origin
		var box: Vector2 = Vector2(float(hero.box_w), float(hero.box_h)) * float(Tuning.ART_SCALE)
		var body: Rect2 = Rect2(feet.x - box.x * 0.5, feet.y - box.y, box.x, box.y)
		if view.intersects(body):
			bodies[hero] = body
	var all: bool = Time.get_ticks_msec() < _tags_until
	for hero: PlayerBase in bodies:
		var marked: bool = false
		for marker: Dictionary in shown:
			marked = marked or int(marker["slot"]) == hero.slot
		if marked:
			continue
		var overlap: bool = false
		for other: PlayerBase in bodies:
			if other != hero and (bodies[hero] as Rect2).intersects(bodies[other] as Rect2):
				overlap = true
		if all or overlap:
			var top: Rect2 = bodies[hero]
			var tip_y: float = top.position.y - TAG_GAP - _tower_height(level, hero)
			# A tall tower must not push the tag off the top of the view.
			tip_y = maxf(tip_y, view.position.y + float(TAG_CELL.y))
			result.append({"slot": hero.slot, "pos": Vector2(top.get_center().x, tip_y)})
	return result


## Lay tags that would print into each other side by side (the 2.0 release round's ruling F4: two heroes in one
## column wore "P1" and "P2" on one spot - "P.21" - for as long as they stood there, hundreds of ticks of a boss
## fight). Every group of tags whose cells overlap becomes a row around the group's middle, one cell apart, in the
## order of the heroes from left to right; each tag keeps its own height (the tip stays over its hero's head or
## tower). `order` is what the last call returned - for every two slots side by side (key: low slot * MAX_PLAYERS +
## high slot) true when the lower slot stood left: heroes closer than TAG_SWAP_PX keep their sides (the lower slot left
## when they meet on one spot). Changes the `pos` of the entries of `list` in place; returns the order to keep.
static func spread_tags(list: Array[Dictionary], order: Dictionary = {}) -> Dictionary:
	var kept: Dictionary = {}
	var count: int = list.size()
	if count < 2:
		return kept
	var own_x: PackedFloat32Array = PackedFloat32Array()
	var group: PackedInt32Array = PackedInt32Array()
	for i: int in count:
		own_x.append((list[i]["pos"] as Vector2).x)
		group.append(i)
	var cell: Vector2 = Vector2(TAG_CELL)
	# A row can reach a tag that stood clear of it: look again until no tag joins a group (a pass per tag at most).
	for _pass: int in count:
		var joined: bool = false
		for a: int in count:
			for b: int in range(a + 1, count):
				if group[a] == group[b]:
					continue
				var apart: Vector2 = ((list[a]["pos"] as Vector2) - (list[b]["pos"] as Vector2)).abs()
				if apart.x < cell.x and apart.y < cell.y:
					var old: int = group[b]
					for i: int in count:
						if group[i] == old:
							group[i] = group[a]
					joined = true
		if not joined:
			break
		for leader: int in count:
			var row: Array[int] = []
			var middle: float = 0.0
			for i: int in count:
				if group[i] != leader:
					continue
				# Insertion by the heroes' order (the kept order for heroes too close to tell).
				var at: int = row.size()
				while at > 0 and _tag_stands_left(list, own_x, order, i, row[at - 1]):
					at -= 1
				row.insert(at, i)
				middle += own_x[i]
			if row.size() < 2:
				continue
			middle /= float(row.size())
			for k: int in row.size():
				var pos: Vector2 = list[row[k]]["pos"]
				list[row[k]]["pos"] = Vector2(roundf(middle + (float(k) - float(row.size() - 1) * 0.5) * cell.x), pos.y)
				for later: int in range(k + 1, row.size()):
					var left_slot: int = int(list[row[k]]["slot"])
					var right_slot: int = int(list[row[later]]["slot"])
					kept[mini(left_slot, right_slot) * Defs.MAX_PLAYERS + maxi(left_slot, right_slot)] = left_slot < right_slot
	return kept


## True when the tag of entry `a` stands left of the tag of entry `b` in a row: by their heroes' places, or - heroes
## closer than TAG_SWAP_PX - as they stood before (`order`), the lower slot left when they never stood side by side.
static func _tag_stands_left(list: Array[Dictionary], own_x: PackedFloat32Array, order: Dictionary, a: int, b: int) -> bool:
	var ahead: float = own_x[b] - own_x[a]
	if absf(ahead) > TAG_SWAP_PX:
		return ahead > 0.0
	var slot_a: int = int(list[a]["slot"])
	var slot_b: int = int(list[b]["slot"])
	var low_left: bool = bool(order.get(mini(slot_a, slot_b) * Defs.MAX_PLAYERS + maxi(slot_a, slot_b), true))
	return low_left == (slot_a < slot_b)


## Height (art px) of the Grub Stack food tower over `hero`'s head (VersusStackDisplay), 0 without one: the referee
## (the level's party driver) tells his stack by `stack_of(slot)`.
static func _tower_height(level: LevelBase, hero: PlayerBase) -> float:
	var driver: Object = level.party_driver
	if driver == null or not is_instance_valid(driver) or not driver.has_method(&"stack_of"):
		return 0.0
	var pictures: int = mini(VersusStackDisplay.tower_pictures(int(driver.call(&"stack_of", hero.slot))).size(),
			VersusStackDisplay.TOWER_MAX)
	if pictures <= 0:
		return 0.0
	var head: float = float(hero.box_h * Tuning.ART_SCALE)
	var first_foot: float = VersusStackDisplay.FIRST_FOOT_ART
	var top: float = first_foot + float(pictures - 1) * VersusStackDisplay.STEP_ART + float(VersusStackDisplay.CELL.y)
	# The leader's tower wears the crown on top.
	if driver.has_method(&"leader_slot") and int(driver.call(&"leader_slot")) == hero.slot:
		top += VersusStackDisplay.CROWN_PIVOT.y
	return maxf(top - head, 0.0)


func _draw() -> void:
	for tag: Dictionary in tags:
		var slot: int = clampi(int(tag["slot"]), 0, Defs.MAX_PLAYERS - 1)
		var tip: Vector2 = tag["pos"]
		_cell(&"tag", UiPlayers.tag_cell(slot), tip - Vector2(float(TAG_CELL.x) * 0.5, float(TAG_CELL.y)))
	for marker: Dictionary in markers:
		var slot: int = clampi(int(marker["slot"]), 0, Defs.MAX_PLAYERS - 1)
		var side: int = int(marker["side"])
		var pos: Vector2 = marker["pos"]
		var digit: int = int(marker["digit"])
		if side < 0:
			if digit > 0:
				_cell(&"stone", digit - 1, pos - Vector2(16.0, 32.0))
			continue
		_cell(&"arrow", UiPlayers.arrow_cell(slot, side), pos - Vector2(16.0, 16.0))
		var inner: Vector2 = pos + _inward(side) * STONE_GAP
		if digit > 0:
			_cell(&"stone", digit - 1, inner - Vector2(16.0, 16.0))
		elif side == UiPlayers.Side.UP:
			# A hero above the view (a spring, a launch): his head in a bubble under the arrow.
			var head: Vector2 = Vector2(UiPlayers.HEAD_CELL)
			_cell(&"head", UiPlayers.head_cell(slot), inner - head * 0.5)


## One cell of the HUD atlas at its own size, top-left at `at` (rounded to whole pixels).
func _cell(group: StringName, index: int, at: Vector2) -> void:
	var source: Rect2 = HudAtlas.region(group, index)
	draw_texture_rect_region(_atlas, Rect2(at.round(), source.size), source)


## The marker of one hero, or {} when he needs none.
func _marker_for(hero: PlayerBase, view: Rect2, inner: Rect2, limit: int) -> Dictionary:
	var feet: Vector2 = hero.get_global_transform_with_canvas().origin
	var height: float = float(hero.box_h * Tuning.ART_SCALE)
	var middle: Vector2 = feet - Vector2(0.0, height * 0.5)
	var digit: int = UiPlayers.leash_digit(hero.leash, limit)
	var side: int = _side_off(middle, view)
	if side < 0:
		if digit <= 0:
			return {}
		return {"slot": hero.slot, "side": -1, "pos": feet - Vector2(0.0, height + HEAD_GAP), "digit": digit}
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
