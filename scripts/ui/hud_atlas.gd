class_name HudAtlas
extends RefCounted
## One texture for every picture of the party HUD (PLAN.md P2.9, G1 follow-up: the four corner panels of a 4-player
## arena cost 31 of the 60 draw calls of ARCHITECTURE.md 11; with this atlas the whole HUD costs 3). The cells of the
## shipped HUD sheets - versus food and crown (`ui/stack_food.png`, `ui/crown.png`), belt icons (`ui/hud_belt.png`),
## hearts (`ui/hud_heart.png`), the P-tags with their colour arrow (`ui/player_tags.png`), the edge arrows
## (`ui/player_arrows.png`), the stone countdown (`ui/countdown_stones.png`), the round sundial and its Feast Rush rim
## (`ui/sundial.png`, `ui/sundial_rush.png`), the players' heads (`ui/portrait_heads.png`), the Hot Rock emblem of the
## awards sheet (`ui/medals.png` cell 14: the ember a Hot Rock player holds) and the Clubball coconut
## (`sprites/objects/coconut.png`: cell 0 the coconut, cell 4 the golden one) - are copied at run time into one image,
## together with a white block for plates and pips. Everything the versus HUD and the edge arrows draw, except text,
## then comes from this one texture, so the renderer batches it into one draw call (text adds one per font).
##
## Owner: ui-B. No asset file of its own: the image is built from the shipped sheets the first time it is asked for
## and kept for the session (about 0.8 MB). A missing sheet leaves its cells transparent - except the sundial's, which
## are then drawn here (the frames and the Feast Rush rim of [method _draw_dial]).

## Cell of ui/medals.png that shows the hot rock (the Hot Potato award, PlayerRun.VERSUS_AWARDS).
const EMBER_MEDAL: int = 14
## Cells of the `coconut` group: the coconut and the golden coconut of a tie ("next goal wins").
const COCONUT: int = 0
const COCONUT_GOLDEN: int = 4
## Cell groups: key -> [sheet path, cell size, cell count, first cell of the sheet (optional, default 0)] (cells
## row-major). `white` is a block drawn here. The tags, arrows and heads have a row per hero colour
## (UiPlayers.PALETTE_ORDER; UiPlayers.tag_cell / arrow_cell / head_cell).
const GROUPS: Array[Array] = [
	[&"white", "", Vector2i(4, 4), 1],
	[&"food", "res://assets/ui/stack_food.png", Vector2i(32, 28), 6],
	[&"crown", "res://assets/ui/crown.png", Vector2i(32, 24), 3],
	[&"belt", "res://assets/ui/hud_belt.png", Vector2i(32, 32), 5],
	[&"heart", "res://assets/ui/hud_heart.png", Vector2i(32, 32), 2],
	[&"stone", "res://assets/ui/countdown_stones.png", Vector2i(32, 32), 5],
	[&"tag", "res://assets/ui/player_tags.png", Vector2i(32, 48), 28],
	[&"arrow", "res://assets/ui/player_arrows.png", Vector2i(32, 32), 24],
	[&"dial", "res://assets/ui/sundial.png", Vector2i(28, 28), 32],
	[&"dial_rush", "res://assets/ui/sundial_rush.png", Vector2i(28, 28), 1],
	[&"head", "res://assets/ui/portrait_heads.png", Vector2i(28, 28), 18],
	[&"ember", "res://assets/ui/medals.png", Vector2i(32, 32), 1, EMBER_MEDAL],
	[&"coconut", "res://assets/sprites/objects/coconut.png", Vector2i(32, 32), 5],
]
## Width of the atlas image (px); groups are packed on shelves, 1 px apart.
const WIDTH: int = 512
## Sundial: frames from an empty face (round start) to a full shadow (the gong), and its colours.
const DIAL_FRAMES: int = 32
const COL_DIAL: Color = Color("d8c7a0")
const COL_DIAL_SHADOW: Color = Color("8f7f63")
const COL_RUSH: Color = Color("ff6b5a")

static var _texture: ImageTexture = null
## key -> [origin (Vector2i), cell size (Vector2i), columns (int), count (int), first cell of the sheet (int)]
static var _groups: Dictionary = {}


## The atlas texture (built on first use).
static func texture() -> Texture2D:
	if _texture == null:
		_build()
	return _texture


## Source rectangle of cell `index` of group `key` (row-major); an empty Rect2 for an unknown key.
static func region(key: StringName, index: int = 0) -> Rect2:
	if _texture == null:
		_build()
	if not _groups.has(key):
		return Rect2()
	var group: Array = _groups[key]
	var cell: Vector2i = group[1]
	var columns: int = group[2]
	var i: int = clampi(index, 0, int(group[3]) - 1)
	return Rect2(Vector2(group[0] + Vector2i((i % columns) * cell.x, (i / columns) * cell.y)), Vector2(cell))


## A sub-rectangle of a cell (art px inside the cell): the visible part of a picture with a wide transparent margin.
static func sub_region(key: StringName, index: int, part: Rect2) -> Rect2:
	var cell: Rect2 = region(key, index)
	return Rect2(cell.position + part.position, part.size)


## The middle of the white block: draw it tinted for plates, edges and pips.
static func white() -> Rect2:
	var block: Rect2 = region(&"white")
	return Rect2(block.position + Vector2.ONE, Vector2.ONE * 2.0)


## The sundial frame for a round that has run `elapsed` (0..1): its shadow sweeps clockwise from twelve o'clock.
static func dial_frame(elapsed: float) -> Rect2:
	return region(&"dial", dial_index(elapsed))


## Frame index of [method dial_frame].
static func dial_index(elapsed: float) -> int:
	return clampi(roundi(clampf(elapsed, 0.0, 1.0) * float(DIAL_FRAMES - 1)), 0, DIAL_FRAMES - 1)


static func _build() -> void:
	_groups.clear()
	var x: int = 0
	var y: int = 0
	var shelf: int = 0
	for group: Array in GROUPS:
		var cell: Vector2i = group[2]
		var count: int = group[3]
		var columns: int = mini(count, maxi(1, WIDTH / cell.x))
		var block: Vector2i = Vector2i(columns * cell.x, ceili(float(count) / float(columns)) * cell.y)
		if x + block.x > WIDTH:
			x = 0
			y += shelf + 1
			shelf = 0
		_groups[group[0]] = [Vector2i(x, y), cell, columns, count, int(group[4]) if group.size() > 4 else 0]
		x += block.x + 1
		shelf = maxi(shelf, block.y)
	var image: Image = Image.create_empty(WIDTH, y + shelf, false, Image.FORMAT_RGBA8)
	for group: Array in GROUPS:
		var key: StringName = group[0]
		var path: String = group[1]
		var origin: Vector2i = _groups[key][0]
		if key == &"white":
			image.fill_rect(Rect2i(origin, group[2]), Color.WHITE)
		elif (key == &"dial" or key == &"dial_rush") and not ResourceLoader.exists(path):
			_draw_dial(image, key)
		elif ResourceLoader.exists(path):
			var sheet: Texture2D = load(path) as Texture2D
			var source: Image = sheet.get_image() if sheet != null else null
			if source == null:
				continue
			if source.is_compressed():
				source.decompress()
			source.convert(Image.FORMAT_RGBA8)
			_copy_cells(image, source, key)
	_texture = ImageTexture.create_from_image(image)


## Copy the cells of a uniform sheet (row-major, from the group's first cell on) into the group's block.
static func _copy_cells(image: Image, source: Image, key: StringName) -> void:
	var group: Array = _groups[key]
	var cell: Vector2i = group[1]
	var columns: int = group[2]
	var first: int = group[4]
	var source_columns: int = maxi(1, source.get_width() / cell.x)
	for i: int in int(group[3]):
		var at: int = first + i
		var from: Vector2i = Vector2i((at % source_columns) * cell.x, (at / source_columns) * cell.y)
		if from.x + cell.x > source.get_width() or from.y + cell.y > source.get_height():
			continue
		var to: Vector2i = group[0] + Vector2i((i % columns) * cell.x, (i / columns) * cell.y)
		image.blit_rect(source, Rect2i(from, cell), to)


## The sundial, pixel by pixel: a stone face with a 2 px ink rim, twelve hour marks, the shadow wedge from twelve
## o'clock and the hand at its edge (one frame per DIAL_FRAMES step); `dial_rush` is the Feast Rush rim alone.
static func _draw_dial(image: Image, key: StringName) -> void:
	var group: Array = _groups[key]
	var cell: Vector2i = group[1]
	var columns: int = group[2]
	var centre: Vector2 = Vector2(cell) * 0.5
	var outer: float = centre.x - 0.5
	var rim: float = outer - 2.0
	for frame: int in int(group[3]):
		var origin: Vector2i = group[0] + Vector2i((frame % columns) * cell.x, (frame / columns) * cell.y)
		var elapsed: float = float(frame) / float(DIAL_FRAMES - 1)
		var sweep: float = elapsed * TAU
		var tip: Vector2 = Vector2(sin(sweep), -cos(sweep)) * (rim - 2.0)
		for py: int in cell.y:
			for px: int in cell.x:
				var offset: Vector2 = Vector2(float(px) + 0.5, float(py) + 0.5) - centre
				var r: float = offset.length()
				if r > outer:
					continue
				var color: Color = COL_DIAL
				if key == &"dial_rush":
					if r <= rim:
						continue
					color = COL_RUSH
				elif r > rim:
					color = UiKit.COL_INK
				else:
					var angle: float = fposmod(atan2(offset.x, -offset.y), TAU)
					if angle < sweep or elapsed >= 1.0:
						color = COL_DIAL_SHADOW
					var hour: float = fposmod(angle + PI / 12.0, PI / 6.0) - PI / 12.0
					if r > rim - 2.5 and absf(hour) * r < 0.75:
						color = UiKit.COL_INK
					if r < 1.6 or _near_segment(offset, tip) < 0.9:
						color = UiKit.COL_INK
				image.set_pixelv(origin + Vector2i(px, py), color)


## Distance of `point` from the segment from the origin to `tip`.
static func _near_segment(point: Vector2, tip: Vector2) -> float:
	var t: float = clampf(point.dot(tip) / maxf(tip.length_squared(), 0.0001), 0.0, 1.0)
	return point.distance_to(tip * t)
