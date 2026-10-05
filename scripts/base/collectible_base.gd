class_name CollectibleBase
extends SimEntity
## Anything the hero picks up by touching it (GAMEPLAY.md 4): food, treasures, letters, power-ups, bones.
##
## CONTRACT FILE (docs/ARCHITECTURE.md 3.15). Owner: objects (bodies may be replaced; public signatures frozen).
## Two motion modes: PLACED (level file; bobs in place, counts for the completion percentage) and DROPPED (thrown
## out by hidden spots, enemies, bosses; gravity, bounce, limited life, never counted).
##
## Level parameters handled here: `index`, `points`, `dropped`, and for dropped items the start velocity, either
## `fan=<n>` (item number n of a fan burst, see ObjTuning.fan_velocity) or explicit `xvel` / `yvel` in v16.
## Without both a dropped item simply falls.

## Entity id this item was spawned as (e.g. &"items/food"); reported to the tally and to Events.
var item_id: StringName = &""
## Sprite cell / variant inside the item's sheet (level parameter `index`).
var index: int = 0
## Displayed points paid on pick-up (0 for pure power-ups).
var points: int = 0
## True for map-placed bonus items: counted for the completion percentage and paid again at the tally.
var counts_for_completion: bool = false
## True for items thrown out at run time (level parameter `dropped`).
var dropped: bool = false
## Ticks left for a dropped item (Tuning.DROPPED_ITEM_LIFE at spawn; 0 = it never expires).
var life: int = 0
## Ticks since spawn.
var age: int = 0
## True once collected; the node is freed (or hidden until the level reset for respawning pick-ups).
var collected: bool = false
## Pick-ups that reappear after the hero's death: weapon items, the glider, kill-all and grenade (PHYSICS.md 10.4).
var reappears_on_respawn: bool = false
## Sound event played on pick-up.
var pickup_sfx: StringName = Sfx.PICKUP
## False for key items (fire-starter, trophy, warp, weapons ...): a dropped copy neither blinks away after
## Tuning.DROPPED_ITEM_LIFE nor counts against the limit of dropped bonus items, and it comes back when it is lost
## in a pit. Set it before the parameters are applied (in `_init`).
var expires: bool = true
## True for bonus items (food, treasures, giant bonuses): every one collected since the last death is paid again
## at the tally, dropped ones included (GAMEPLAY.md 3.4).
var counts_for_tally: bool = false
## True while a dropped item lies still on a floor.
var resting: bool = false

var _sprite: Sprite2D = null
var _sprite_rest_y: float = 0.0
var _bob_phase: int = 0
var _holds_drop_slot: bool = false
var _removing: bool = false
## Sim.get_phase_runs(ITEMS) when the item dozed off (its `age` catches up on waking).
var _doze_items_run: int = 0

## Dropped bonus items alive right now (the original has 32 slots for them).
static var _drop_slots_used: int = 0


func get_kind() -> int:
	return Defs.Kind.COLLECTIBLE


func _init() -> void:
	z_index = Defs.Z_ITEMS


func _notification(what: int) -> void:
	if what == NOTIFICATION_ENTER_TREE:
		if dropped and expires and not _holds_drop_slot:
			if _drop_slots_used >= ObjTuning.MAX_DROPPED_ITEMS:
				# No free slot: the item is never seen (GAMEPLAY.md 4.5).
				collected = true
				visible = false
				queue_free()
			else:
				_holds_drop_slot = true
				_drop_slots_used += 1
	elif what == NOTIFICATION_EXIT_TREE:
		_release_drop_slot()


func _sim_phases() -> PackedInt32Array:
	return PackedInt32Array([Defs.Phase.ITEMS, Defs.Phase.CONTACT_ITEMS])


func _apply_params(params: Dictionary) -> void:
	index = int(params.get("index", index))
	dropped = param_bool("dropped", dropped)
	if params.has("points"):
		points = int(params["points"])
	if dropped:
		counts_for_completion = false
		life = Tuning.DROPPED_ITEM_LIFE if expires else 0
		if params.has("xvel") or params.has("yvel"):
			xvel = int(params.get("xvel", 0))
			yvel = int(params.get("yvel", 0))
		elif params.has("fan"):
			var start: Vector2i = ObjTuning.fan_velocity(
				int(params["fan"]), ObjTuning.BURST_XVEL, ObjTuning.BURST_YVEL
			)
			xvel = start.x
			yvel = start.y
	# Neighbouring placed items bob one after the other.
	_bob_phase = (sim_pos.x >> 4) * 3
	_update_look()


func _sim_tick(phase: int) -> void:
	if collected:
		return
	if phase == Defs.Phase.ITEMS:
		age += 1
		_move_tick()
		if dropped and life > 0:
			life -= 1
			if life == 0:
				_remove()
			elif life <= Tuning.DROPPED_ITEM_BLINK:
				visible = (life & 1) == 0
	elif phase == Defs.Phase.CONTACT_ITEMS:
		var level: LevelBase = Game.level
		if level != null and level.player != null and can_be_collected() \
				and Overlap.body(self, level.player, level.player):
			collect(level.player)


## Dozing (SimEntity, ARCHITECTURE.md 11): a placed item far from the hero and the view only counts its age (it
## bobs only on screen, and the overlap test rejects a hero farther than Tuning.OVERLAP_MAX_DX / _DY from its
## feet point), so it may doze; its age catches up when it wakes. Dropped items move and expire: never.
func _doze_area() -> Rect2i:
	return _doze_box()


func _can_doze() -> bool:
	return not dropped and not collected


func _on_doze() -> void:
	_doze_items_run = Sim.get_phase_runs(Defs.Phase.ITEMS)


func _on_doze_wake() -> void:
	age += Sim.get_phase_runs(Defs.Phase.ITEMS) - _doze_items_run


## Movement for one tick: bobbing when placed, bouncing physics when dropped. Override.
func _move_tick() -> void:
	if dropped:
		_drop_tick()
	elif on_screen:
		_bob_tick()


## True when a touch may pick it up now (dropped items: not during their first 10 ticks).
func can_be_collected() -> bool:
	if collected:
		return false
	return not dropped or age > Tuning.DROPPED_ITEM_NO_PICKUP


## The hero touched the item. Applies the effect, pays the points, feeds tally / completion / audio / events and
## removes the item. Returns false when the item stays in place (e.g. a heart at full energy).
func collect(hero: PlayerBase) -> bool:
	if collected or hero.dead:
		return false
	if not _apply(hero):
		return false
	collected = true
	var top: Vector2i = Vector2i(sim_pos.x, sim_pos.y - box_h)
	if points > 0:
		Game.add_score(points)
		Events.popup_requested.emit(&"score", points, top)
	if counts_for_completion:
		Game.count_item_collected()
	if counts_for_completion or (counts_for_tally and points > 0):
		Game.add_tally_item(item_id, index, points)
	Audio.play_sfx(pickup_sfx)
	Events.item_collected.emit(item_id, index, points, sim_pos)
	if Game.level != null:
		Game.level.spawn_fx(&"fx/star_puff", Vector2i(sim_pos.x, sim_pos.y - (box_h >> 1)))
	if reappears_on_respawn:
		visible = false
	else:
		_remove()
	return true


## Effect of the pick-up on the hero / game state. Return false to refuse the pick-up (item stays). Override.
func _apply(_hero: PlayerBase) -> bool:
	return true


## Show the right picture for `index` (and whatever else the subclass draws). Called after the parameters were
## applied; the default selects cell `index` of the node named "Sprite". Override for other sheets.
func _update_look() -> void:
	show_cell(index)


## Show cell `cell` of the sheet of the "Sprite" node (clamped to the sheet).
func show_cell(cell: int) -> void:
	var sprite: Sprite2D = get_sprite()
	if sprite != null:
		sprite.frame = clampi(cell, 0, sprite.hframes * sprite.vframes - 1)


## The child Sprite2D named "Sprite" (ARCHITECTURE.md 5.1), or null for a bare instance without a scene.
func get_sprite() -> Sprite2D:
	if _sprite == null:
		_sprite = get_node_or_null(^"Sprite") as Sprite2D
		if _sprite != null:
			_sprite_rest_y = _sprite.position.y
	return _sprite


func _on_level_reset() -> void:
	if dropped and expires:
		_remove()
	elif reappears_on_respawn and collected:
		collected = false
		visible = true


## Placed items bob up and down by Tuning.ITEM_BOB_PX (the picture only: the contact box stays put).
func _bob_tick() -> void:
	var sprite: Sprite2D = get_sprite()
	if sprite != null:
		sprite.position.y = _sprite_rest_y - float(ObjTuning.BOB_ART[(age + _bob_phase) % ObjTuning.BOB_ART.size()])


## One tick of the dropped-item physics of GAMEPLAY.md 4.2 / 4.5: integrate, light gravity, bounce off floors
## with half the impact speed, turn around at walls, stop rising under ceilings, lie still when the bounce has
## died down. (The original turns items at walls only while they rise; falling ones could sink into a wall.)
func _drop_tick() -> void:
	var level: LevelBase = Game.level
	if level == null:
		return
	var grid: TileGrid = level.grid
	if resting:
		if TileGrid.is_ground(grid.floor_at(sim_pos.x >> 4, sim_pos.y >> 4)):
			return
		resting = false
	if xvel != 0:
		var next_x: int = sim_pos.x + Tuning.floor16(xvel)
		var next_col: int = next_x >> 4
		var outside: bool = next_x < 0 or (grid.cols > 0 and next_x >= grid.width_px())
		var wall: bool = next_col != (sim_pos.x >> 4) \
				and grid.side_at(next_col, (sim_pos.y - 1) >> 4) == TileGrid.SIDE_WALL
		if outside or wall:
			xvel = -xvel
		else:
			sim_pos.x = next_x
	sim_pos.y += Tuning.floor16(yvel)
	if yvel + ObjTuning.DROP_GRAVITY < ObjTuning.DROP_TERMINAL:
		yvel += ObjTuning.DROP_GRAVITY
	var col: int = sim_pos.x >> 4
	var row: int = sim_pos.y >> 4
	if yvel > 0:
		if TileGrid.is_ground(grid.floor_at(col, row)):
			var surface: int = row * Tuning.TILE + grid.surface_offset(col, row, sim_pos.x)
			if sim_pos.y >= surface:
				_land(surface)
		elif grid.get_char(col, row) == TileGrid.CH_LIQUID:
			_sink(level, row * Tuning.TILE)
		elif sim_pos.y > grid.height_px() + Tuning.PIT_DEPTH_PX:
			_lose()
	elif grid.ceiling_at(col, (sim_pos.y - box_h) >> 4) == TileGrid.CEILING_SOLID:
		# Stopped UNDER the ceiling, never inside it: the top of the box goes back to the bottom edge of the solid
		# cell it rose into. (Left inside, an item whose feet had entered the rock landed on that cell's top and
		# rested in the rock out of reach - a boss's fire-starter too, a softlock in a closed arena.)
		var ceiling_row: int = (sim_pos.y - box_h) >> 4
		sim_pos.y = maxi(sim_pos.y, (ceiling_row + 1) * Tuning.TILE + box_h)
		yvel = 0


## Touch-down on a floor whose surface is at `surface`: bounce, or come to rest after a slow impact.
func _land(surface: int) -> void:
	sim_pos.y = surface
	if yvel < ObjTuning.DROP_REST_MAX_YVEL:
		xvel = 0
		yvel = 0
		resting = true
		return
	yvel = Tuning.shr(-yvel, ObjTuning.DROP_BOUNCE_SHIFT)
	if xvel > 0:
		xvel = maxi(xvel - ObjTuning.DROP_GROUND_FRICTION, 0)
	elif xvel < 0:
		xvel = mini(xvel + ObjTuning.DROP_GROUND_FRICTION, 0)


## The item fell into a liquid cell whose top is at `surface`: splash, then it is gone.
func _sink(level: LevelBase, surface: int) -> void:
	var liquid: String = "lava" if str(level.meta.get("liquid", "water")) == "lava" else "water"
	level.spawn_fx(&"fx/splash", Vector2i(sim_pos.x, surface + 2), {"kind": liquid})
	Audio.play_sfx(Sfx.SPLASH)
	_lose()


## The item left the level (pit or liquid). Bonus items are gone; key items start again where they were spawned.
func _lose() -> void:
	if expires:
		collected = true
		_remove()
		return
	xvel = 0
	yvel = 0
	resting = false
	teleport(spawn_pos)


## The item is gone (collected, expired, lost, cleared by a respawn). It is freed at the end of the frame as
## before, but it leaves the simulation and gives its dropped-item slot back at the end of the current tick (at
## once between ticks), exactly when a node freed at the end of the frame disappears in the game. Replays that step
## ticks without rendering frames (headless tests) then count like the game: queue_free() alone would leave the
## item in the level and its slot taken until the next frame.
func _remove() -> void:
	queue_free()
	if _removing:
		return
	_removing = true
	if Sim.is_in_tick():
		Sim.tick_finished.connect(_on_removal_tick_finished, CONNECT_ONE_SHOT)
	else:
		_finish_removal()


func _on_removal_tick_finished(_tick: int) -> void:
	_finish_removal()


func _finish_removal() -> void:
	collected = true
	visible = false
	sim_active = false
	_release_drop_slot()


func _release_drop_slot() -> void:
	if _holds_drop_slot:
		_holds_drop_slot = false
		_drop_slots_used -= 1
