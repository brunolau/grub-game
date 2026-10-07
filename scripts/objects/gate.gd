class_name Gate
extends SimEntity
## `objects/gate` (GAMEPLAY.md 7.5): a door, cave mouth or secret hole. Standing in front of it and pressing Down
## (the hero crouches, `drop_timer > 0`) starts a journey: Flow closes its curtain and stops the clock
## (Flow.play_covered, ARCHITECTURE.md 3.10), the hero is put at the destination while the screen is covered, then
## the curtain opens again. Not usable while carrying the hang-glider. Two-way travel needs two gates.
##
## Parameters: `name`; `dest=<name of a gate or marker>`; `lock=c,r` camera cell of a single-screen room (the lock
## of the DESTINATION applies on arrival; arriving somewhere without one releases the camera);
## `skin=arch|hole|none` [arch]; 2.0 `needs=<bond>`: locked (drawn dark, Down does nothing) until that drum bond
## succeeded (objects/drum, [R10]).
##
## A party (2.0, TECH_AUDIT.md 3.12): every hero may enter (the first in contact order who asks travels); his own
## glider blocks him, a mounted hero cannot enter (PHYSICS.md C.9), and every traveller waits for Down to be released
## after a journey before he may enter again.
## Co-op team gate (DESIGN.md D.1, GAMEPLAY.md 13.9.2; ObjTuning.coop_rules): Down by one hero takes the whole party.
## The hero who entered arrives at the destination and world-A's PartyDriver brings the others (`travel_party`:
## spread behind him, as eggs when they were more than one view away or eggs already); a destination with `lock=`
## also pulls the party into the locked view (LevelBase.pull_party_into). Without a PartyDriver the gate does it
## itself: every other hatched hero arrives PartyTuning.PULL_IN_BEHIND_PX behind him (the same point when that spot
## has no floor); a partner who was more than one view away when the journey began (PartyTuning.GATE_PARTNER_RANGE_PX
## across or ObjTuning.GATE_PARTNER_RANGE_Y_PX up or down) arrives as an egg, and eggs travel as eggs (placed at the
## egg drift point beside him). A hero in his death toss stays.

const SKINS: Array[String] = ["arch", "hole", "none"]
const TEXTURES: Array[Texture2D] = [
	preload("res://assets/sprites/objects/gate_arch.png"),
	preload("res://assets/sprites/objects/gate_hole.png"),
]
const PIVOTS: Array[Vector2] = [Vector2(40, 63), Vector2(22, 48)]
## A locked (`needs=`) gate is drawn this dark.
const LOCKED_TINT: Color = Color(0.45, 0.45, 0.5)

## Name of the gate or marker it leads to.
var dest: StringName = &""
## True from the hero's request until he stands at the destination (the curtain covers the screen meanwhile).
var travelling: bool = false
## 2.0: the drum bond that unlocks it (`needs`; &"" = none) and whether it is locked now.
var needs: StringName = &""
var locked: bool = false

var _cell: Vector2i = Vector2i.ZERO
var _target: SimEntity = null
var _warned: bool = false
## The hero on his way to the destination (set by _begin, used by _arrive).
var _traveller: PlayerBase = null
## 2.0 team gate: the partners travelling with him, and bit `slot` for each who was farther than one view away.
var _partners: Array[PlayerBase] = []
var _far_mask: int = 0
## True from a co-op party's entry until the arrival (the whole party travels).
var _party_travel: bool = false
var _sprite: Sprite2D = null

## Set after a journey until the hero lets go of Down, so that he does not travel straight back: bit `slot` for the
## hero of that player slot (1.0: one flag for the one hero, bit 0).
static var _wait_release: int = 0


func _init() -> void:
	z_index = Defs.Z_OBJECTS
	set_box(Vector3i(24, 32, 12))


func _sim_phases() -> PackedInt32Array:
	return PackedInt32Array([Defs.Phase.WORLD])


func _apply_params(params: Dictionary) -> void:
	dest = StringName(str(params.get("dest", "")))
	needs = StringName(str(params.get("needs", "")))
	locked = needs != &""
	_cell = Vector2i(sim_pos.x >> 4, (sim_pos.y - 1) >> 4)
	var skin: int = SKINS.find(str(params.get("skin", SKINS[0])))
	if skin < 0:
		push_warning("objects/gate: unknown skin '%s'" % str(params.get("skin")))
		skin = 0
	var sprite: Sprite2D = get_node_or_null(^"Sprite") as Sprite2D
	if sprite != null:
		sprite.visible = skin < TEXTURES.size()
		if sprite.visible:
			sprite.texture = TEXTURES[skin]
			sprite.offset = -PIVOTS[skin]
		_sprite = sprite
	_show_lock()


func _enter_tree() -> void:
	# A freshly loaded level starts without a pending "let go of Down" from a previous level.
	_wait_release = 0


func _sim_tick(_phase: int) -> void:
	var level: LevelBase = Game.level
	if level == null or travelling:
		return
	if needs != &"":
		var now_locked: bool = not Drum.bond_succeeded(level, needs)
		if now_locked != locked:
			locked = now_locked
			_show_lock()
	for hero: PlayerBase in level.contact_order():
		if _wants_to_enter(hero):
			_begin(hero)
			return


func _on_level_reset() -> void:
	travelling = false
	_traveller = null
	_partners.clear()
	_far_mask = 0
	_party_travel = false
	_wait_release = 0


## Dozing (SimEntity, ARCHITECTURE.md 11): a gate that is not in use and does not wait for Down to be released only
## tests whether the hero's feet are in its cell, which they cannot be while he is far.
func _doze_area() -> Rect2i:
	return Rect2i(_cell * Tuning.TILE, Vector2i(Tuning.TILE, Tuning.TILE)).merge(_doze_box())


func _can_doze() -> bool:
	return not travelling and _wait_release == 0


## True when the hero stands in front of this gate pressing Down, on the ground, without the glider.
func _wants_to_enter(hero: PlayerBase) -> bool:
	if hero.dead or hero.down or not hero.control_enabled:
		return false
	var bit: int = 1 << hero.slot
	if hero.drop_timer == 0:
		_wait_release &= ~bit
		return false
	if (_wait_release & bit) != 0 or hero.run.has_glider or not hero.is_grounded() or hero.is_mounted():
		return false
	if hero.cell_col() != _cell.x or ((hero.sim_pos.y - 1) >> 4) != _cell.y:
		return false
	return not (needs != &"" and locked)


func _begin(hero: PlayerBase) -> void:
	var level: LevelBase = Game.level
	_target = level.find_named(dest) if level != null and dest != &"" else null
	if _target == null:
		if not _warned:
			_warned = true
			push_warning("objects/gate '%s': destination '%s' not found" % [param_str("name"), dest])
		return
	_wait_release |= 1 << hero.slot
	travelling = true
	_traveller = hero
	hero.set_control_enabled(false)
	hero.xvel = 0
	_partners.clear()
	_far_mask = 0
	_party_travel = ObjTuning.coop_rules(level)
	if _party_travel:
		for other: PlayerBase in level.contact_order():
			_wait_release |= 1 << other.slot
		if not _driver_travels(level):
			_gather_partners(level, hero)
	if Flow.busy:
		# Another transition owns the cover and cannot wait for a curtain of its own: travel at once.
		_arrive()
	else:
		Flow.play_covered(_arrive, Defs.Transition.CURTAIN)


## True when the level's PartyDriver takes the partners along (`travel_party`).
static func _driver_travels(level: LevelBase) -> bool:
	return level != null and level.party_driver != null and level.party_driver.has_method(&"travel_party")


## Team gate without a PartyDriver: every other hero not in a death toss travels too; who is farther than one view
## away arrives as an egg.
func _gather_partners(level: LevelBase, hero: PlayerBase) -> void:
	for other: PlayerBase in level.contact_order():
		if other == hero or other.dead:
			continue
		_partners.append(other)
		if not other.is_down():
			if absi(other.sim_pos.x - hero.sim_pos.x) > PartyTuning.GATE_PARTNER_RANGE_PX \
					or absi(other.sim_pos.y - hero.sim_pos.y) > ObjTuning.GATE_PARTNER_RANGE_Y_PX:
				_far_mask |= 1 << other.slot
			other.set_control_enabled(false)
			other.xvel = 0


## Runs between two ticks while the curtain covers the screen: the hero who entered (1.0: the hero) arrives, and in a
## co-op party his partners with him.
func _arrive() -> void:
	travelling = false
	var level: LevelBase = Game.level
	var hero: PlayerBase = _traveller if level != null and is_instance_valid(_traveller) else null
	_traveller = null
	var partners: Array[PlayerBase] = _partners.duplicate()
	_partners.clear()
	if hero == null or hero.dead:
		for partner: PlayerBase in partners:
			if is_instance_valid(partner) and not partner.dead and not partner.is_down():
				partner.set_control_enabled(true)
		return
	hero.set_control_enabled(true)
	if not is_instance_valid(_target):
		for partner: PlayerBase in partners:
			if is_instance_valid(partner) and not partner.dead and not partner.is_down():
				partner.set_control_enabled(true)
		return
	var from: Vector2i = hero.sim_pos
	hero.xvel = 0
	hero.yvel = 0
	hero.teleport(_target.sim_pos)
	level.notify_hero_teleported(hero)
	if _party_travel and _driver_travels(level):
		level.party_driver.call(&"travel_party", hero, from, hero.sim_pos)
	for partner: PlayerBase in partners:
		if is_instance_valid(partner) and not partner.dead:
			_arrive_partner(level, hero, partner)
	if _target.spawn_params.has("lock"):
		var lock: PackedInt32Array = LevelText.to_int_list(_target.spawn_params["lock"])
		if lock.size() == 2:
			var rect: Rect2i = Rect2i(
				lock[0] * Tuning.TILE, lock[1] * Tuning.TILE,
				Tuning.VIEW_COLS * Tuning.TILE, Tuning.VIEW_ROWS * Tuning.TILE
			)
			level.lock_camera(rect)
			if _party_travel and level.has_method(&"pull_party_into"):
				level.call(&"pull_party_into", rect, hero)
	else:
		level.unlock_camera()
	level.snap_camera()
	Events.gate_used.emit(from, hero.sim_pos)


## A partner of the team gate arrives beside `hero` (who stands at the destination already).
func _arrive_partner(level: LevelBase, hero: PlayerBase, partner: PlayerBase) -> void:
	if partner.is_mounted():
		partner.leave_mount()
	var far: bool = (_far_mask & (1 << partner.slot)) != 0
	if far and not partner.is_down():
		partner.go_down(&"gate")
	partner.xvel = 0
	partner.yvel = 0
	if partner.is_down():
		partner.teleport(Vector2i(hero.sim_pos.x + PartyTuning.EGG_OFFSET_X * hero.facing,
				hero.sim_pos.y + PartyTuning.EGG_OFFSET_Y))
	else:
		partner.teleport(partner_spot(level, hero.sim_pos, hero.facing))
		partner.set_control_enabled(true)
	level.notify_hero_teleported(partner)


## Where a partner arrives behind a hero standing at `pos` facing `facing`: PartyTuning.PULL_IN_BEHIND_PX behind him
## when a floor carries that spot and no wall is in the way, else his own point.
static func partner_spot(level: LevelBase, pos: Vector2i, facing_dir: int) -> Vector2i:
	var spot: Vector2i = Vector2i(pos.x - PartyTuning.PULL_IN_BEHIND_PX * facing_dir, pos.y)
	if level == null or level.grid == null:
		return pos
	var grid: TileGrid = level.grid
	var col: int = spot.x >> 4
	if spot.x < 0 or (grid.cols > 0 and spot.x >= grid.width_px()):
		return pos
	if not TileGrid.is_ground(grid.floor_at(col, spot.y >> 4)):
		return pos
	if grid.side_at(col, (spot.y - 1) >> 4) == TileGrid.SIDE_WALL:
		return pos
	return spot


func _show_lock() -> void:
	if _sprite != null:
		_sprite.modulate = LOCKED_TINT if locked else Color.WHITE
