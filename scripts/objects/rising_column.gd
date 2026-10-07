class_name RisingColumn
extends SimEntity
## `objects/column` (GAMEPLAY.md 7.4 "earthquake pillars"): when the hero enters the trigger rectangle (the cell he
## stands in, i.e. the point 1 px above his feet), a block of tiles rises one row every Tuning.COLUMN_RISE_PERIOD
## ticks for `rise` rows while the screen shakes.
##
## Parameters: `size=w,h` tiles (the block whose bottom-left cell is the anchor) [1,1]; `rise` tiles [2];
## `trigger=c,r,w,h` tiles [the block and the space it rises into, plus 4 tiles around]; `shake` [7].
## Every step shifts the block's characters up one row through `Game.level.set_cell`; the row it leaves at the
## bottom takes the character found under the block when it was triggered (ground under a pillar stays ground, air
## under a floating bridge stays air). The hero standing on the block rides up with it. A level reset (respawn)
## puts every cell back and re-arms the trigger.

const ID_DUST: StringName = &"fx/dust"

## The block in cells at rest: position = top-left cell.
var block: Rect2i = Rect2i(0, 0, 1, 1)
## Rows it rises.
var rise: int = ObjTuning.COLUMN_DEFAULT_RISE
## Trigger rectangle in logical px.
var trigger: Rect2i = Rect2i()
## Shake strength while it rises.
var shake: int = ObjTuning.SHAKE_COLUMN
## Rows risen so far.
var risen: int = 0
## True from the trigger until the reset.
var triggered: bool = false

var _timer: int = 0
var _below: PackedStringArray = PackedStringArray()
var _saved: PackedStringArray = PackedStringArray()


func _sim_phases() -> PackedInt32Array:
	return PackedInt32Array([Defs.Phase.WORLD])


func _apply_params(params: Dictionary) -> void:
	var size: PackedInt32Array = LevelText.to_int_list(params.get("size", "1,1"))
	var w: int = maxi(size[0], 1) if size.size() >= 1 else 1
	var h: int = maxi(size[1], 1) if size.size() >= 2 else 1
	var col: int = sim_pos.x >> 4
	var row: int = (sim_pos.y - 1) >> 4
	block = Rect2i(col, row - h + 1, w, h)
	rise = maxi(int(params.get("rise", ObjTuning.COLUMN_DEFAULT_RISE)), 0)
	shake = int(params.get("shake", ObjTuning.SHAKE_COLUMN))
	if params.has("trigger"):
		trigger = LevelText.to_rect_px(params["trigger"])
	else:
		var margin: int = ObjTuning.COLUMN_TRIGGER_MARGIN
		trigger = Rect2i(
			(block.position.x - margin) * Tuning.TILE, (block.position.y - rise - margin) * Tuning.TILE,
			(w + 2 * margin) * Tuning.TILE, (h + rise + 2 * margin) * Tuning.TILE
		)


func _sim_tick(_phase: int) -> void:
	if risen >= rise:
		return
	var level: LevelBase = Game.level
	if level == null:
		return
	if not triggered:
		# The cell a hero stands in: the point just above his feet (the feet of a hero on a floor are already on the
		# top edge of the floor cell below). Any living hero triggers it (2.0, TECH_AUDIT.md 3.12).
		for hero: PlayerBase in level.contact_order():
			if not hero.dead and Overlap.point_in(trigger, hero.sim_pos.x, hero.sim_pos.y - 1):
				_start(level)
				return
		return
	level.request_shake(shake)
	_timer += 1
	if _timer % Tuning.COLUMN_RISE_PERIOD == 0:
		_rise_one(level)


## Dozing (SimEntity, ARCHITECTURE.md 11): waiting, it only tests whether the hero's feet are in its trigger, which
## they cannot be while he is far; risen to the top, it does nothing. Rising, it ticks.
func _doze_area() -> Rect2i:
	return trigger.merge(_doze_box()) if trigger.has_area() else _doze_box()


func _can_doze() -> bool:
	return not triggered or risen >= rise


func _on_level_reset() -> void:
	var level: LevelBase = Game.level
	if triggered and level != null:
		var i: int = 0
		for row: int in range(block.position.y - rise, block.end.y):
			for col: int in range(block.position.x, block.end.x):
				level.set_cell(col, row, _saved[i])
				i += 1
	triggered = false
	risen = 0
	_timer = 0


func _start(level: LevelBase) -> void:
	triggered = true
	_timer = 0
	_saved.clear()
	for row: int in range(block.position.y - rise, block.end.y):
		for col: int in range(block.position.x, block.end.x):
			_saved.append(level.get_cell(col, row))
	_below.clear()
	for col: int in range(block.position.x, block.end.x):
		_below.append(level.get_cell(col, block.end.y))
	level.request_shake(shake)
	Audio.play_sfx(Sfx.QUAKE)


func _rise_one(level: LevelBase) -> void:
	var top: int = block.position.y - risen
	var bottom: int = block.end.y - 1 - risen
	# Every living hero standing on top rides up with it (2.0, TECH_AUDIT.md 3.12; 1.0: the one hero): bit k = the
	# k-th hero of the contact order.
	var heroes: Array[PlayerBase] = level.contact_order()
	var carry: int = 0
	for k: int in heroes.size():
		var hero: PlayerBase = heroes[k]
		if not hero.dead and (hero.sim_pos.y >> 4) == top \
				and hero.cell_col() >= block.position.x and hero.cell_col() < block.end.x:
			carry |= 1 << k
	for c: int in block.size.x:
		var col: int = block.position.x + c
		for row: int in range(top - 1, bottom):
			level.set_cell(col, row, level.get_cell(col, row + 1))
		level.set_cell(col, bottom, _below[c])
	risen += 1
	for k: int in heroes.size():
		if (carry & (1 << k)) != 0:
			var hero: PlayerBase = heroes[k]
			hero.teleport(Vector2i(hero.sim_pos.x, hero.sim_pos.y - Tuning.TILE))
	var surface: int = (top - 1) * Tuning.TILE
	for c: int in block.size.x:
		level.spawn_fx(ID_DUST, Vector2i((block.position.x + c) * Tuning.TILE + Tuning.TILE / 2, surface))
