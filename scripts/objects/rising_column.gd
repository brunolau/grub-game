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
##
## 2.0 drives (DESIGN.md D.5, GAMEPLAY.md 13.9.7, LEVEL_DESIGN.md 15.4 / 15.7.3; [R10] [R18]):
## - `rise_while=<plate>[,...]` / `sink_while=<plate>[,...]`: a plate door. While ALL the named `objects/plate`s are
##   pressed the block rises (sinks) one row per PartyTuning.PLATE_COLUMN_PERIOD ticks, up to `rise` rows, and returns
##   at the same rate once one is released. `shake` defaults to 0 for these. A moving block carries the heroes
##   standing on it up (as the 1.0 column) and never moves down into a hatched hero (it waits); the row it leaves
##   takes the character found under (rising) or above (sinking) the block at rest - except for a DOOR, a block
##   whose next cell in its direction of travel is solid (rising into a ceiling slot, sinking into the floor): the
##   cells a door leaves become air.
## - `trigger=keepers:<name>`: the keeper door - it rises once (the 1.0 rise) when every enemy tagged
##   `keeper=<name>` is dead (the door rule for the cells it leaves as above).
## - `trigger=drums:<bond>`: it rises once when that drum bond succeeded (objects/drum).
## - `rise=0` without a plate or group: a static block (with `expert`: the Expert-only row of a boost ledge [R18]).
##   Its block cells that are air become solid ground when it spawns.
## A team wipe (the level reset) puts every driven door back. Driven doors never doze (their drive is read every
## tick); a static block and a waiting 1.0 column doze as before.

enum Drive { TRIGGER, PLATES, KEEPERS, DRUMS, STATIC }

const ID_DUST: StringName = &"fx/dust"
const GROUP_KEEPERS: String = "keepers:"
const GROUP_DRUMS: String = "drums:"

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
## 2.0: what moves it (Drive), the plates of a plate door, true for `sink_while`, the keeper / drum group name.
var drive: int = Drive.TRIGGER
var plate_names: PackedStringArray = PackedStringArray()
var sinks: bool = false
var group: StringName = &""

var _timer: int = 0
var _below: PackedStringArray = PackedStringArray()
var _saved: PackedStringArray = PackedStringArray()
## Plate doors: the plates (resolved on the first tick), the region it moves in (cells) and its characters at rest.
var _plates: Array[Plate] = []
var _plates_resolved: bool = false
var _region: Rect2i = Rect2i()
var _rest_chars: PackedStringArray = PackedStringArray()
var _fill: PackedStringArray = PackedStringArray()
var _static_done: bool = false


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
	var shake_default: int = ObjTuning.SHAKE_COLUMN
	var trigger_text: String = str(params.get("trigger", "")) if params.has("trigger") else ""
	if params.has("rise_while") or params.has("sink_while"):
		drive = Drive.PLATES
		sinks = not params.has("rise_while")
		plate_names = LevelText.to_list(params.get("sink_while" if sinks else "rise_while", ""))
		shake_default = 0
	elif trigger_text.begins_with(GROUP_KEEPERS):
		drive = Drive.KEEPERS
		group = StringName(trigger_text.substr(GROUP_KEEPERS.length()))
	elif trigger_text.begins_with(GROUP_DRUMS):
		drive = Drive.DRUMS
		group = StringName(trigger_text.substr(GROUP_DRUMS.length()))
	elif rise == 0:
		drive = Drive.STATIC
	shake = int(params.get("shake", shake_default))
	if drive == Drive.TRIGGER and params.has("trigger"):
		trigger = LevelText.to_rect_px(params["trigger"])
	else:
		var margin: int = ObjTuning.COLUMN_TRIGGER_MARGIN
		trigger = Rect2i(
			(block.position.x - margin) * Tuning.TILE, (block.position.y - rise - margin) * Tuning.TILE,
			(w + 2 * margin) * Tuning.TILE, (h + rise + 2 * margin) * Tuning.TILE
		)


func _enter_tree() -> void:
	# A static block makes its air cells solid as soon as the level exists (the loader built the grid and its
	# visuals before it spawns entities; LevelBase.set_cell keeps the visuals in step).
	if drive == Drive.STATIC and not _static_done and Game.level != null:
		_static_done = true
		var level: LevelBase = Game.level
		for row: int in range(block.position.y, block.end.y):
			for col: int in range(block.position.x, block.end.x):
				if level.grid.in_bounds(col, row) and level.get_cell(col, row) == TileGrid.CH_AIR:
					level.set_cell(col, row, TileGrid.CH_SOLID_A)


func _sim_tick(_phase: int) -> void:
	if drive == Drive.PLATES:
		_plate_tick()
		return
	if risen >= rise:
		return
	var level: LevelBase = Game.level
	if level == null:
		return
	if not triggered:
		if drive == Drive.KEEPERS:
			if keepers_dead(level):
				_start(level)
			return
		if drive == Drive.DRUMS:
			if Drum.bond_succeeded(level, group):
				_start(level)
			return
		# The cell a hero stands in: the point just above his feet (the feet of a hero on a floor are already on the
		# top edge of the floor cell below). Any living hero triggers it (2.0, TECH_AUDIT.md 3.12; an egg does not).
		for hero: PlayerBase in level.contact_order():
			if not hero.dead and not hero.down and Overlap.point_in(trigger, hero.sim_pos.x, hero.sim_pos.y - 1):
				_start(level)
				return
		return
	level.request_shake(shake)
	_timer += 1
	if _timer % Tuning.COLUMN_RISE_PERIOD == 0:
		_rise_one(level)


## Dozing (SimEntity, ARCHITECTURE.md 11): waiting, it only tests whether the hero's feet are in its trigger, which
## they cannot be while he is far; risen to the top, it does nothing. Rising, it ticks. 2.0: a plate, keeper or drum
## door reads its drive every tick and never dozes.
func _doze_area() -> Rect2i:
	return trigger.merge(_doze_box()) if trigger.has_area() else _doze_box()


func _can_doze() -> bool:
	if drive == Drive.PLATES or drive == Drive.KEEPERS or drive == Drive.DRUMS:
		return false
	return not triggered or risen >= rise


func _on_level_reset() -> void:
	var level: LevelBase = Game.level
	if drive == Drive.PLATES:
		if level != null and risen != 0:
			risen = 0
			_render(level)
		risen = 0
		_timer = 0
		return
	if triggered and level != null:
		var i: int = 0
		for row: int in range(block.position.y - rise, block.end.y):
			for col: int in range(block.position.x, block.end.x):
				level.set_cell(col, row, _saved[i])
				i += 1
	triggered = false
	risen = 0
	_timer = 0


## Keeper door: true when the group has enemies and every enemy tagged `keeper=<group>` is dead - polled every tick
## (a bonded keeper may regrow; a split keeper's half joins the group), the rule of enemies-A's
## CoopTraits.keepers_done. A group without enemies never opens its door (the validator reports it).
func keepers_dead(level: LevelBase) -> bool:
	var found: bool = false
	for entity: SimEntity in level.get_tagged(&"keeper", group):
		var enemy: EnemyBase = entity as EnemyBase
		if enemy == null or not is_instance_valid(enemy):
			continue
		found = true
		if not enemy.dead:
			return false
	return found


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
	if drive == Drive.KEEPERS or drive == Drive.DRUMS:
		for c: int in block.size.x:
			_below[c] = _door_fill(level, block.position.x + c, false, _below[c])
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
		if not hero.dead and not hero.down and (hero.sim_pos.y >> 4) == top \
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


# =================================================================================================================
# 2.0 plate doors
# =================================================================================================================

## True while every plate of a plate door is pressed (false while a named plate is missing).
func plates_pressed() -> bool:
	if _plates.is_empty() or _plates.size() != plate_names.size():
		return false
	for plate: Plate in _plates:
		if not is_instance_valid(plate) or not plate.pressed:
			return false
	return true


func _resolve_plates(level: LevelBase) -> void:
	if _plates_resolved:
		return
	_plates_resolved = true
	for plate_name: String in plate_names:
		var plate: Plate = level.find_named(StringName(plate_name)) as Plate
		if plate == null:
			push_warning("objects/column: plate '%s' not found (objects/plate name=...)" % plate_name)
			continue
		_plates.append(plate)
	# The region the block moves in and its characters at rest (read once, before it ever moved).
	if sinks:
		_region = Rect2i(block.position.x, block.position.y, block.size.x, block.size.y + rise)
	else:
		_region = Rect2i(block.position.x, block.position.y - rise, block.size.x, block.size.y + rise)
	_rest_chars.clear()
	for row: int in range(_region.position.y, _region.end.y):
		for col: int in range(_region.position.x, _region.end.x):
			_rest_chars.append(level.get_cell(col, row))
	# What fills the cells it leaves: the character under the block (rising) or above it (sinking), per column - or air
	# for a door (_door_fill).
	_fill.clear()
	var fill_row: int = block.position.y - 1 if sinks else block.end.y
	for col: int in range(block.position.x, block.end.x):
		_fill.append(_door_fill(level, col, sinks, level.get_cell(col, fill_row)))


func _plate_tick() -> void:
	var level: LevelBase = Game.level
	if level == null:
		return
	_resolve_plates(level)
	var target: int = rise if plates_pressed() else 0
	if risen == target:
		_timer = 0
		return
	if shake > 0:
		level.request_shake(shake)
	_timer += 1
	if _timer < PartyTuning.PLATE_COLUMN_PERIOD:
		return
	var away: bool = target > risen
	# Moving up (a rising door opening, a sinking door closing) carries the heroes on top; moving down never enters a
	# hero's cells (it waits and tries again on the next tick).
	var up: bool = away != sinks
	if not up and _blocked_below(level, away):
		return
	_timer = 0
	if risen == 0 and away:
		ObjTuning.play_cue(Sfx.BOULDER_PUSH, Sfx.QUAKE if shake > 0 else &"")
	var carry: Array[PlayerBase] = []
	if up:
		carry = _riders(level)
	risen += 1 if away else -1
	_render(level)
	for hero: PlayerBase in carry:
		hero.teleport(Vector2i(hero.sim_pos.x, hero.sim_pos.y - Tuning.TILE))
	var top_now: int = _block_top_row()
	for c: int in block.size.x:
		level.spawn_fx(ID_DUST, Vector2i((block.position.x + c) * Tuning.TILE + Tuning.TILE / 2, top_now * Tuning.TILE))


## What the cells a 2.0 door (plate, keeper, drum) leaves become in column `col`: a block that moves INTO solid cells
## (a door rising into a ceiling slot, sinking into the floor) is a door - the cells it leaves become air; a block
## that moves into air (a pillar, a bridge) keeps the 1.0 rule: `trail`, the character behind it at rest (ground
## under a pillar stays ground).
func _door_fill(level: LevelBase, col: int, sinking: bool, trail: String) -> String:
	var ahead: int = block.end.y if sinking else block.position.y - 1
	if level.grid.in_bounds(col, ahead) and level.grid.side_at(col, ahead) == TileGrid.SIDE_WALL:
		return TileGrid.CH_AIR
	return trail


## Top row of the block now.
func _block_top_row() -> int:
	return block.position.y + (risen if sinks else -risen)


## The hatched heroes standing on the block's top now.
func _riders(level: LevelBase) -> Array[PlayerBase]:
	var riders: Array[PlayerBase] = []
	var top: int = _block_top_row()
	for hero: PlayerBase in level.contact_order():
		if hero.is_party_targetable() and (hero.sim_pos.y >> 4) == top \
				and hero.cell_col() >= block.position.x and hero.cell_col() < block.end.x:
			riders.append(hero)
	return riders


## True when the row the block would move down into holds a hatched hero.
func _blocked_below(level: LevelBase, away: bool) -> bool:
	var next: int = risen + (1 if away else -1)
	var bottom: int = block.end.y - 1 + (next if sinks else -next)
	for col: int in range(block.position.x, block.end.x):
		if ObjTuning.hero_in_cell(level, col, bottom):
			return true
	return false


## Write the region for the current position: the block's characters where it is, the fill where it left, the rest
## characters elsewhere. Only cells that change are written.
func _render(level: LevelBase) -> void:
	if _rest_chars.is_empty():
		return
	var top: int = _block_top_row()
	var i: int = 0
	for row: int in range(_region.position.y, _region.end.y):
		for c: int in _region.size.x:
			var col: int = _region.position.x + c
			var want: String
			if row >= top and row < top + block.size.y:
				var block_row: int = block.position.y + (row - top)
				want = _rest_chars[(block_row - _region.position.y) * _region.size.x + c]
			elif (sinks and row < top) or (not sinks and row >= top + block.size.y):
				want = _fill[c]
			else:
				want = _rest_chars[i]
			if level.get_cell(col, row) != want:
				level.set_cell(col, row, want)
			i += 1
