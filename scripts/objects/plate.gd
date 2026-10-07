class_name Plate
extends SimEntity
## `objects/plate name=<name> count=1|2 mode=hold|timed:<ticks>|latch w=<cells>` (DESIGN.md D.5, GAMEPLAY.md
## 13.9.7): a pressure plate of `w` [2] floor cells. Its anchor is the LEFT cell (the air cell above the floor, as for
## every multi-cell object anchored at its bottom-left cell); it reaches `w` cells to the right.
##
## Weight (CONTACT_ITEMS phase, after every hero moved): each hatched hero (alive, not an egg) whose feet point lies
## over its cells, on its floor or at most ObjTuning.PLATE_FEET_SLACK_PX above it and not rising, weighs
## PartyTuning.PLATE_WEIGHT_HERO; a mount (Chomper, through its driver's seat) PLATE_WEIGHT_CHOMPER; an
## objects/boulder_heavy resting on it PLATE_WEIGHT_BOULDER. Enemies and eggs weigh nothing, so an egg can never solve
## a gate. It is pressed while the weight is at least `count`; `timed:T` stays pressed T ticks after the weight left
## (a stone clock: it blinks in its last second); `latch` stays pressed for good. A team wipe (the level reset)
## releases every plate.
##
## Columns read [member pressed] (`objects/column rise_while=` / `sink_while=`, rising_column.gd) in the WORLD phase
## of the same tick. A plate stands 8+ tiles from its door (validator, world-B). Pressed, it is drawn 2 px lower and
## clicks (Sfx.PLATE).

enum Mode { HOLD, TIMED, LATCH }

## Sheet [M plate]: count=1 frames 0 up / 1 pressed and lit / 2 pressed unlit; count=2 the same from frame 3.
const FRAME_UP: int = 0
const FRAME_LIT: int = 1
const FRAME_UNLIT: int = 2
const FRAMES_PER_COUNT: int = 3
## The picture is two cells wide (64 art px); wider or narrower plates are stretched.
const ART_CELLS: int = 2

## Weight needed (`count` 1 or 2).
var count: int = 1
## Mode.HOLD, TIMED or LATCH (`mode`).
var mode: int = Mode.HOLD
## Ticks a timed plate stays pressed after the weight left (`mode=timed:<ticks>`).
var timed_ticks: int = 0
## Width in cells (`w`).
var width_cells: int = ObjTuning.PLATE_DEFAULT_W
## Weight on it at its last test.
var weight: int = 0
## Bit `slot` for every hero counted on it at its last test (HUD, tally statistics).
var holder_mask: int = 0
## True while pressed (what the columns read).
var pressed: bool = false
## Timed plates: ticks it still stays pressed without weight.
var hold_left: int = 0
## Times it went from released to pressed (statistics, tests).
var presses: int = 0

var _sprite: Sprite2D = null
var _sprite_rest: Vector2 = Vector2.ZERO
var _anim: int = 0
## Performance (player-A's two-hero pass, PLAN P2.12): the cells never move, so their edges are kept once; the frame
## and the sink last written to the sprite (an engine write only when they change); the level's heave boulders,
## found once on the first tick (they are level-file entities, all spawned before it).
var _left: int = 0
var _right: int = 0
var _shown_frame: int = -1
var _shown_sunk: int = -1
var _boulders: Array[HeavyBoulder] = []
var _boulders_found: bool = false


func _init() -> void:
	z_index = Defs.Z_OBJECTS


func _sim_phases() -> PackedInt32Array:
	return PackedInt32Array([Defs.Phase.CONTACT_ITEMS])


func _apply_params(params: Dictionary) -> void:
	count = clampi(int(params.get("count", count)), 1, PartyTuning.PLATE_COUNT_MAX)
	width_cells = maxi(int(params.get("w", width_cells)), 1)
	var mode_text: String = str(params.get("mode", "hold"))
	if mode_text == "latch":
		mode = Mode.LATCH
	elif mode_text.begins_with("timed"):
		mode = Mode.TIMED
		var parts: PackedStringArray = mode_text.split(":")
		timed_ticks = maxi(parts[1].to_int(), 0) if parts.size() == 2 and parts[1].is_valid_int() else 0
		if timed_ticks == 0:
			push_warning("objects/plate '%s': mode=%s needs timed:<ticks>; holding instead" % [
				param_str("name"), mode_text])
			mode = Mode.HOLD
	else:
		if mode_text != "hold":
			push_warning("objects/plate '%s': unknown mode '%s'; holding instead" % [param_str("name"), mode_text])
		mode = Mode.HOLD
	# The box covers the cells (for on_screen and the doze area): the anchor cell's centre is 8 px from its left edge.
	set_box(Vector3i(width_cells * Tuning.TILE, ObjTuning.PLATE_SINK_PX * 3, Tuning.TILE / 2))
	_left = (sim_pos.x >> 4) * Tuning.TILE
	_right = _left + width_cells * Tuning.TILE
	_sprite = get_node_or_null(^"Sprite") as Sprite2D
	if _sprite != null:
		# The picture is centred on the cells: shift it from the anchor cell's centre and stretch it to `w` cells.
		_sprite_rest = Vector2(float((width_cells - 1) * Tuning.TILE / 2 * Tuning.ART_SCALE), 0.0)
		_sprite.position = _sprite_rest
		_sprite.scale.x = float(width_cells) / float(ART_CELLS)
	_show()


## Left edge (px) of the plate's cells.
func left_px() -> int:
	return _left


## Right edge (px, exclusive).
func right_px() -> int:
	return _right


## The floor surface y the plate lies on (its feet point).
func floor_y() -> int:
	return sim_pos.y


## True when a feet point at (x, y) stands on the plate: over its cells, on its floor or at most
## ObjTuning.PLATE_FEET_SLACK_PX above it.
func feet_on(x: int, y: int) -> bool:
	return x >= _left and x < _right and y <= sim_pos.y and y >= sim_pos.y - ObjTuning.PLATE_FEET_SLACK_PX


func _sim_tick(_phase: int) -> void:
	var level: LevelBase = Game.level
	if level == null:
		return
	weight = measure_weight(level)
	var heavy: bool = weight >= count
	var was: bool = pressed
	match mode:
		Mode.LATCH:
			pressed = pressed or heavy
		Mode.TIMED:
			if heavy:
				pressed = true
				hold_left = timed_ticks
			elif hold_left > 0:
				pressed = true
				hold_left -= 1
			else:
				pressed = false
		_:
			pressed = heavy
	_anim += 1
	if pressed != was:
		if pressed:
			presses += 1
		_anim = 0
		ObjTuning.play_cue(Sfx.PLATE, Sfx.CLUB_HIT_SCENERY)
	_show()


## The weight on the plate now (GAMEPLAY.md 13.9.7); also fills [member holder_mask].
func measure_weight(level: LevelBase) -> int:
	var total: int = 0
	holder_mask = 0
	for hero: PlayerBase in level.contact_order():
		if not hero.is_party_targetable():
			continue
		if hero.is_mounted():
			# The mount weighs for its riders (counted once, through the driver).
			var mount: SimEntity = hero.mount
			if hero.mount_seat == PlayerBase.SEAT_DRIVER and is_instance_valid(mount) \
					and feet_on(mount.sim_pos.x, mount.sim_pos.y):
				total += PartyTuning.PLATE_WEIGHT_CHOMPER
				holder_mask |= 1 << hero.slot
			continue
		if hero.yvel < 0 and not hero.is_grounded():
			continue
		if feet_on(hero.sim_pos.x, hero.sim_pos.y):
			total += PartyTuning.PLATE_WEIGHT_HERO
			holder_mask |= 1 << hero.slot
	if not _boulders_found:
		_boulders_found = true
		for entity: SimEntity in level.get_kind(Defs.Kind.OTHER):
			if entity is HeavyBoulder:
				_boulders.append(entity as HeavyBoulder)
	for boulder: HeavyBoulder in _boulders:
		if is_instance_valid(boulder) and boulder.rests_on_plate(self):
			total += PartyTuning.PLATE_WEIGHT_BOULDER
	return total


func _on_level_reset() -> void:
	weight = 0
	holder_mask = 0
	pressed = false
	hold_left = 0
	_anim = 0
	_show()


## The picture: up, pressed and lit, or a timed plate's last second blinking lit / unlit; pressed = 2 px lower.
func _show() -> void:
	if _sprite == null:
		return
	var base: int = 0 if count <= 1 else FRAMES_PER_COUNT
	var frame: int = FRAME_UP
	if pressed:
		frame = FRAME_LIT
		if mode == Mode.TIMED and weight < count and hold_left <= ObjTuning.PLATE_BLINK_TICKS:
			frame = FRAME_LIT + ObjTuning.anim_frame(_anim, ObjTuning.PLATE_BLINK_FPS) % 2
	if base + frame != _shown_frame:
		_shown_frame = base + frame
		_sprite.frame = _shown_frame
	var sunk: int = ObjTuning.PLATE_SINK_PX * Tuning.ART_SCALE if pressed else 0
	if sunk != _shown_sunk:
		_shown_sunk = sunk
		_sprite.position = _sprite_rest + Vector2(0.0, float(sunk))
